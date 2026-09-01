class_name BattleDecisionOwnerFactory
extends RefCounted

const ClassicFactoryScript = preload("res://scripts/ui/battle/ai/BattleAiOpponentFactory.gd")
const AuthorHostScript = preload("res://scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorMatchHost.gd")
const AuthorLocalExecutorOwnerScript = preload("res://scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorLocalExecutorBattleOwner.gd")
const CynthiaAuthorOwnerScript = preload("res://scripts/ai/ptcgdap/host/godot/CynthiaAuthorStrategyDevelopmentBattleOwner.gd")
const ReviewedAuthorOwnerScript = preload("res://scripts/ai/ptcgdap/host/godot/ReviewedAuthorStrategyDevelopmentBattleOwner.gd")
const DevelopmentGateScript = preload("res://scripts/ai/ptcgdap/host/godot/AuthorStrategyWindowsDevelopmentGate.gd")
const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")
const CYNTHIA_PACKAGE_ID := "ptcgdap.cynthia-garchomp-800018543.windows-local"
const REVIEWED_RUNTIME_KINDS := [
	"reviewed_restricted_ir_v1",
	"reviewed_competitive_policy_v2",
]


static func build_for_mode(
	mode: int,
	author_handle: Variant,
	match_id: String,
	deck_strategy_registry: Variant,
	host_scene: Variant,
) -> Dictionary:
	if mode == GameManager.GameMode.TWO_PLAYER:
		return _success(null, "none", false, false)
	if mode == GameManager.GameMode.VS_AUTHOR_STRATEGY_AI:
		var built: Dictionary = AuthorHostScript.create(author_handle, match_id)
		if not bool(built.get("ok", false)):
			return _failure(str(built.get("error_code", "package_integrity_invalid")))
		return _success(built.get("host"), "author_shadow", false, false)
	if mode == GameManager.GameMode.VS_AI:
		if host_scene == null:
			return _failure("classic_host_missing")
		var classic_factory := ClassicFactoryScript.new()
		var version_registry: Variant = host_scene.get("_ai_version_registry")
		var version_store: Variant = host_scene.get("_agent_version_store")
		var owner: Variant = classic_factory.build_selected_ai_opponent(
			deck_strategy_registry,
			version_registry,
			version_store,
			host_scene,
		)
		return _success(owner, "classic_ai", true, true)
	return _failure("unsupported_game_mode")


static func build_windows_development_author_owner(
	author_handle: Variant,
	gsm: GameStateMachine,
	player_index: int,
	match_id: String
) -> Dictionary:
	return build_windows_author_owner(
		author_handle, gsm, player_index, match_id, "development_exact_fixture"
	)


static func build_windows_author_owner(
	author_handle: Variant,
	gsm: GameStateMachine,
	player_index: int,
	match_id: String,
	authority_mode: String
) -> Dictionary:
	var pins: Dictionary = author_handle.to_public_dict() if author_handle != null and author_handle.has_method("to_public_dict") else {}
	var candidate: Dictionary = DevelopmentGateScript.candidate_for_pins(pins)
	var owner_script: GDScript = AuthorLocalExecutorOwnerScript
	if pins.get("package_id") == CYNTHIA_PACKAGE_ID:
		owner_script = CynthiaAuthorOwnerScript
	elif candidate.get("runtime_kind") in REVIEWED_RUNTIME_KINDS:
		owner_script = ReviewedAuthorOwnerScript
	var built: Dictionary = owner_script.create(
		author_handle, gsm, player_index, match_id, authority_mode
	)
	if not bool(built.get("ok", false)):
		return _failure(str(built.get("error_code", "invalid_bind")))
	var is_canary := authority_mode == "production_device_canary"
	var result := _success(
		built.get("owner"),
		"author_windows_device_canary" if is_canary else "author_windows_development",
		true,
		true
	)
	result["authority_mode"] = authority_mode
	result["development_execution_only"] = not is_canary
	result["device_canary_authority"] = is_canary
	result["production_ready"] = false
	result["policy_executor_kind"] = (
		"restricted_policy_ir_v1"
		if pins.get("package_id") == CYNTHIA_PACKAGE_ID or candidate.get("runtime_kind") in REVIEWED_RUNTIME_KINDS
		else "local_policy_executor_v1"
	)
	return result


static func build_windows_development_rules_owner(
	deck_strategy_registry: Variant,
	deck: DeckData,
	player_index: int = 0
) -> Dictionary:
	if OS.get_name() != "Windows":
		return _failure("development_platform_not_authorized")
	if deck == null or player_index not in [0, 1]:
		return _failure("invalid_bind")
	var owner: AIOpponent = AIOpponentScript.new()
	owner.configure(player_index, GameManager.ai_difficulty)
	if deck_strategy_registry != null and deck_strategy_registry.has_method("apply_strategy_for_deck"):
		deck_strategy_registry.call("apply_strategy_for_deck", owner, deck)
	owner.use_mcts = false
	owner.decision_runtime_mode = AIOpponentScript.DECISION_RUNTIME_RULES_ONLY
	owner.set_meta("ai_source", "windows_ui_acceptance_rules")
	owner.set_meta("ai_version_id", "")
	owner.set_meta("ai_display_name", "Windows UI acceptance rules AI")
	var result := _success(owner, "windows_ui_acceptance_rules", true, true)
	result["development_execution_only"] = true
	result["production_ready"] = false
	return result


static func _success(owner: Variant, owner_kind: String, execution_authority: bool, engine_command_authority: bool) -> Dictionary:
	return {
		"ok": true,
		"error_code": "",
		"owner": owner,
		"owner_kind": owner_kind,
		"execution_authority": execution_authority,
		"engine_command_authority": engine_command_authority,
	}


static func _failure(code: String) -> Dictionary:
	return {
		"ok": false,
		"error_code": code,
		"owner": null,
		"owner_kind": "none",
		"execution_authority": false,
		"engine_command_authority": false,
	}
