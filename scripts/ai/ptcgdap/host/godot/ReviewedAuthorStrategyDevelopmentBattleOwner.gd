class_name ReviewedAuthorStrategyDevelopmentBattleOwner
extends "res://scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorDevelopmentBattleOwner.gd"

## Engine seam for exact reviewed Forge packages. The inherited owner keeps all
## engine objects private and exposes only primitive public frames to policy.
const ReviewedPolicyScript = preload(
	"res://scripts/ai/ptcgdap/runtime/local/ReviewedAuthorStrategyDevelopmentPolicy.gd"
)


class ReviewedPublicInteractionAdapter extends RefCounted:
	var owner: Variant = null

	func _init(next_owner: Variant) -> void:
		owner = next_owner

	func get_strategy_id() -> String:
		return owner._reviewed_strategy_id if owner != null else ""

	func pick_interaction_items(items: Array, step: Dictionary, context: Dictionary = {}) -> Array:
		return owner._pick_interaction_items(items, step, context) if owner != null else []

	func should_preserve_empty_interaction_selection(step: Dictionary, context: Dictionary = {}) -> bool:
		return owner._should_preserve_empty_interaction_selection(step, context) if owner != null else false

	func pick_interaction_target_index(
		items: Array,
		excluded_targets: Array,
		step: Dictionary,
		context: Dictionary = {}
	) -> int:
		return owner._pick_interaction_target_index(items, excluded_targets, step, context) \
			if owner != null else -1


var _reviewed_frame_profile_id := ""
var _reviewed_strategy_id := ""


static func create(
	handle: Variant,
	gsm: GameStateMachine,
	seat: int,
	match_id: String,
	authority_mode: String = ExecutionGateScript.DEVELOPMENT_MODE
) -> Dictionary:
	if not _competition_host_authorized():
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
	var pin_error := ExecutionGateScript.validate_handle_pins(
		handle.to_public_dict(), authority_mode
	)
	if not pin_error.is_empty():
		return _error(pin_error)
	var owner := new()
	var bound: Dictionary = owner._bind(
		handle, gsm, seat, match_id.strip_edges(), authority_mode
	)
	if not bool(bound.get("ok", false)):
		return _error(str(bound.get("error_code", "invalid_bind")))
	var model_bound: Dictionary = owner._bind_model(handle)
	if not bool(model_bound.get("ok", false)):
		owner.close_match()
		return _error(str(model_bound.get("error_code", "package_model_relation_invalid")))
	return {"ok": true, "error_code": "", "owner": owner}


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
	var candidate: Dictionary = _candidate_for_pins(_pins, authority_mode)
	if candidate.get("runtime_kind") not in ["reviewed_restricted_ir_v1", "reviewed_competitive_policy_v2"]:
		return _error("development_candidate_not_authorized")
	_reviewed_frame_profile_id = str(candidate.get("frame_profile_id", ""))
	_reviewed_strategy_id = str(candidate.get("strategy_id", ""))
	if _reviewed_frame_profile_id.is_empty() or _reviewed_strategy_id.is_empty():
		return _error("development_candidate_not_authorized")
	var inventory_error := _deck_inventory_error(
		_gsm.game_state.players[player_index], handle.local_deck_snapshot()
	)
	if not inventory_error.is_empty():
		return _error(inventory_error)
	_serial_registry = GodotSerialRegistryScript.new()
	_match_generation = int(_serial_registry.get_match_generation())
	for inventory_seat: int in 2:
		var registered: Dictionary = _register_player_inventory(
			_gsm.game_state.players[inventory_seat]
		)
		if not bool(registered.get("ok", false)):
			return registered
	var sealed: Dictionary = _serial_registry.seal_card_inventory([60, 60])
	if not bool(sealed.get("ok", false)):
		return _error(str(sealed.get("code", "card_inventory_error")))
	var created: Dictionary = ReviewedPolicyScript.create(handle, match_id, _authority_mode)
	if not bool(created.get("ok", false)):
		return _error(str(created.get("error_code", "package_policy_unsupported")))
	_policy = created.get("policy")
	_legal_action_builder = LegalityOnlyActionBuilder.new()
	_interaction_adapter = ReviewedPublicInteractionAdapter.new(self)
	_step_resolver = StepResolverScript.new()
	_step_resolver.call("set_deck_strategy", _interaction_adapter)
	_engine_executor = EngineActionExecutorScript.new()
	_bound = true
	return {"ok": true, "error_code": ""}


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
	if _uses_competitive_policy_v2():
		return frame
	frame["profile_id"] = _reviewed_frame_profile_id
	frame["strategy_id"] = _reviewed_strategy_id
	return frame


func audit_snapshot() -> Dictionary:
	var audit: Dictionary = super.audit_snapshot()
	audit["profile_id"] = _reviewed_frame_profile_id
	audit["strategy_id"] = _reviewed_strategy_id
	var candidate: Dictionary = _candidate_for_pins(_pins, _authority_mode)
	audit["policy_executor_kind"] = str(candidate.get("runtime_kind", "reviewed_restricted_ir_v1"))
	audit["development_execution_only"] = true
	audit["production_ready"] = false
	return audit


func public_replay_identity() -> Dictionary:
	var identity: Dictionary = super.public_replay_identity()
	if bool(identity.get("ok", false)):
		var participant: Dictionary = identity.get("strategy_participant", {})
		participant["strategy_id"] = _reviewed_strategy_id
		identity["strategy_participant"] = participant
	return identity


static func _candidate_for_pins(pins: Dictionary, authority_mode: String) -> Dictionary:
	return ExecutionGateScript.candidate_for_pins(pins, authority_mode)
