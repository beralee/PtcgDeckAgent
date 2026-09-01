class_name PtcgDAPAuthorLocalExecutorBattleOwner
extends "res://scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorDevelopmentBattleOwner.gd"

## Windows development/device-canary host for LocalPolicyExecutor.
## Private engine objects stay in this host.  The policy object receives only
## the inherited primitive public frame and returns current-window indexes.

const LocalPolicyExecutorScript = preload("res://scripts/ai/ptcgdap/runtime/local/LocalPolicyExecutor.gd")


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
	var bound: Dictionary = owner._bind(
		handle, gsm, seat, match_id.strip_edges(), authority_mode
	)
	if not bool(bound.get("ok", false)):
		return _error(str(bound.get("error_code", "invalid_bind")))
	var model_bound: Dictionary = owner._bind_model(handle)
	if not bool(model_bound.get("ok", false)):
		owner.close_match()
		return _error(str(model_bound.get("error_code", "package_model_relation_invalid")))
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
		var registered: Dictionary = _register_player_inventory(
			_gsm.game_state.players[inventory_seat]
		)
		if not bool(registered.get("ok", false)):
			return registered
	var sealed: Dictionary = _serial_registry.seal_card_inventory([60, 60])
	if not bool(sealed.get("ok", false)):
		return _error(str(sealed.get("code", "card_inventory_error")))
	var created: Dictionary = LocalPolicyExecutorScript.create(
		handle, match_id, _authority_mode
	)
	if not bool(created.get("ok", false)):
		return _error(str(created.get("error_code", "package_policy_unsupported")))
	_policy = created.get("policy")
	_legal_action_builder = LegalityOnlyActionBuilder.new()
	_interaction_adapter = PublicInteractionAdapter.new(self)
	_step_resolver = StepResolverScript.new()
	_step_resolver.call("set_deck_strategy", _interaction_adapter)
	_engine_executor = EngineActionExecutorScript.new()
	_bound = true
	return {"ok":true, "error_code":""}


func audit_snapshot() -> Dictionary:
	var audit: Dictionary = super.audit_snapshot()
	var policy_audit: Dictionary = _policy.audit_snapshot() if _policy != null else {}
	audit["local_policy_executor_id"] = policy_audit.get("local_policy_executor_id")
	audit["local_policy_executor_version"] = policy_audit.get("local_policy_executor_version")
	audit["local_policy_executor_manifest_canonical_sha256"] = policy_audit.get(
		"local_policy_executor_manifest_canonical_sha256"
	)
	audit["portable_baseline"] = policy_audit.get("portable_baseline")
	audit["policy_output"] = policy_audit.get("policy_output")
	audit["restricted_ir_executed"] = policy_audit.get("restricted_ir_executed", false)
	audit["local_executor_runtime_authority"] = policy_audit.get(
		"local_executor_runtime_authority", false
	)
	audit["engine_commit_authority"] = true
	audit["policy_engine_object_access"] = false
	return audit
