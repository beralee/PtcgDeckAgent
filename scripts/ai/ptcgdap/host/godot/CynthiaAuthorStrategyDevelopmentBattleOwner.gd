class_name CynthiaAuthorStrategyDevelopmentBattleOwner
extends "res://scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorDevelopmentBattleOwner.gd"

const CynthiaPolicyScript = preload("res://scripts/ai/ptcgdap/runtime/local/CynthiaAuthorStrategyDevelopmentPolicy.gd")
const CYNTHIA_PROFILE_ID := "ptcgdap-cynthia-garchomp-package-development-frame-v1"
const CYNTHIA_STRATEGY_ID := "ptcgdap.cynthia-garchomp.18.0.package-local-v1"


class CynthiaPublicInteractionAdapter extends RefCounted:
	var owner: Variant = null

	func _init(next_owner: Variant) -> void:
		owner = next_owner

	func get_strategy_id() -> String:
		return CYNTHIA_STRATEGY_ID

	func pick_interaction_items(items: Array, step: Dictionary, _context: Dictionary = {}) -> Array:
		return owner._pick_interaction_items(items, step) if owner != null else []


static func create(
	handle: Variant,
	gsm: GameStateMachine,
	seat: int,
	match_id: String,
	authority_mode: String = ExecutionGateScript.DEVELOPMENT_MODE
) -> Dictionary:
	if OS.get_name() != "Windows":
		return _error("development_platform_not_authorized")
	if (
		handle == null
		or not handle.has_method("validate_integrity")
		or not handle.validate_integrity()
		or gsm == null
		or gsm.game_state == null
		or gsm.game_state.players.size() != 2
		or seat not in [0, 1]
		or match_id.strip_edges().is_empty()
	):
		return _error("invalid_bind")
	var pin_error := ExecutionGateScript.validate_handle_pins(handle.to_public_dict(), authority_mode)
	if not pin_error.is_empty():
		return _error(pin_error)
	var owner := new()
	var bound: Dictionary = owner._bind(handle, gsm, seat, match_id.strip_edges(), authority_mode)
	if not bool(bound.get("ok", false)):
		return _error(str(bound.get("error_code", "invalid_bind")))
	return {"ok":true, "error_code":"", "owner":owner}


func _bind(
	handle: Variant,
	next_gsm: GameStateMachine,
	seat: int,
	match_id: String,
	authority_mode: String
) -> Dictionary:
	player_index = seat
	_gsm = next_gsm
	_match_id = match_id
	_authority_mode = authority_mode
	_pins = handle.to_public_dict().duplicate(true)
	var inventory_error := _deck_inventory_error(
		_gsm.game_state.players[player_index], handle.local_deck_snapshot()
	)
	if not inventory_error.is_empty():
		return _error(inventory_error)
	_serial_registry = GodotSerialRegistryScript.new()
	_match_generation = int(_serial_registry.get_match_generation())
	for inventory_seat: int in 2:
		var registered: Dictionary = _register_player_inventory(_gsm.game_state.players[inventory_seat])
		if not bool(registered.get("ok", false)):
			return registered
	var sealed: Dictionary = _serial_registry.seal_card_inventory([60, 60])
	if not bool(sealed.get("ok", false)):
		return _error(str(sealed.get("code", "card_inventory_error")))
	var created: Dictionary = CynthiaPolicyScript.create(handle, match_id, _authority_mode)
	if not bool(created.get("ok", false)):
		return _error(str(created.get("error_code", "package_policy_unsupported")))
	_policy = created.get("policy")
	_legal_action_builder = LegalityOnlyActionBuilder.new()
	_interaction_adapter = CynthiaPublicInteractionAdapter.new(self)
	_step_resolver = StepResolverScript.new()
	_step_resolver.call("set_deck_strategy", _interaction_adapter)
	_engine_executor = EngineActionExecutorScript.new()
	_bound = true
	return {"ok":true, "error_code":""}


func _build_frame(
	prompt_kind: String,
	options: Array,
	minimum: int,
	maximum: int,
	raw_semantics_override: Dictionary = {}
) -> Dictionary:
	var frame: Dictionary = super._build_frame(
		prompt_kind, options, minimum, maximum, raw_semantics_override
	)
	frame["profile_id"] = CYNTHIA_PROFILE_ID
	frame["strategy_id"] = CYNTHIA_STRATEGY_ID
	return frame


func audit_snapshot() -> Dictionary:
	var audit: Dictionary = super.audit_snapshot()
	audit["profile_id"] = CYNTHIA_PROFILE_ID
	audit["strategy_id"] = CYNTHIA_STRATEGY_ID
	audit["policy_executor_kind"] = "restricted_policy_ir_v1"
	return audit


func public_replay_identity() -> Dictionary:
	var identity: Dictionary = super.public_replay_identity()
	if bool(identity.get("ok", false)):
		var participant: Dictionary = identity.get("strategy_participant", {})
		participant["strategy_id"] = CYNTHIA_STRATEGY_ID
		identity["strategy_participant"] = participant
	return identity
