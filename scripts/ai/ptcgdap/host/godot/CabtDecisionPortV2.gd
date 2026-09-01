class_name CabtDecisionPortV2
extends RefCounted

const ContractSetScript = preload("res://scripts/ai/ptcgdap/cabt/CabtContractSet.gd")
const JsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")
const WindowScript = preload("res://scripts/ai/ptcgdap/cabt/CabtSelectionWindow.gd")
const SanitizerScript = preload("res://scripts/ai/ptcgdap/cabt/CabtSelectionSanitizer.gd")
const CONTRACT_GENERATION := 2

var public_window: Dictionary = {}
var state := "uninitialized"
var _shared_window: Variant = null
var _private_options: Array = []
var _accepted: Variant = null
var _bound: Dictionary = {}
var _commit_result: Variant = null
var _callback_binding_hash := ""


static func issue(
	raw_callback: Variant,
	session_id: Variant,
	match_generation: Variant,
	seat: Variant,
	window_generation: Variant,
	private_options: Variant,
	log_cursor: Variant,
	capability_profile_hash: Variant,
) -> Dictionary:
	if (
		not raw_callback is Dictionary
		or typeof(session_id) != TYPE_STRING
		or str(session_id).is_empty()
		or typeof(match_generation) != TYPE_INT
		or int(match_generation) < 1
		or typeof(seat) != TYPE_INT
		or int(seat) not in [0, 1]
		or typeof(window_generation) != TYPE_INT
		or int(window_generation) < 1
		or not private_options is Array
		or typeof(log_cursor) != TYPE_INT
		or int(log_cursor) < 0
		or not _upper_sha(capability_profile_hash)
	):
		return _error("cabt_window_configuration_invalid")
	var raw: Dictionary = raw_callback
	# Godot's published capability is Search=none.  It must not accept or
	# manufacture an official Search token.
	if raw.get("search_begin_input") != null:
		return _error("cabt_search_capability_unsupported")
	var select_value: Variant = raw.get("select")
	if not select_value is Dictionary or not select_value.get("option") is Array:
		return _error("cabt_selection_window_required")
	if private_options.size() != select_value.get("option").size():
		return _error("cabt_private_binding_cardinality_mismatch")
	if not raw.get("logs") is Array:
		return _error("cabt_logs_invalid")
	var semantic := {
		"select": raw.get("select"),
		"current": raw.get("current"),
		"logs": raw.get("logs"),
	}
	var engine_hash := _hash("engine_semantic", semantic)
	var policy_hash := _hash("policy_input", raw)
	if engine_hash.is_empty() or policy_hash.is_empty():
		return _error("cabt_window_hash_invalid")
	var contracts: Variant = ContractSetScript.load_default()
	if contracts == null or not contracts.ok:
		return _error("cabt_contract_unavailable")
	var built: Variant = WindowScript.build({
		"select": (select_value as Dictionary).duplicate(true),
		"public_observation_hash": engine_hash,
		"public_hash_authority": "firewall_accepted",
		"chooser_player_index": int(seat),
	}, contracts)
	if built == null or built.get("decision_state") != "policy_allowed" or built.get("window") == null:
		return _error("cabt_window_invalid")
	var shared: Variant = built.get("window")
	var callback_hash := _hash("callback_binding", {
		"session_id": session_id,
		"match_generation": match_generation,
		"seat": seat,
		"window_generation": window_generation,
		"step_presence": raw.has("step"),
		"step": raw.get("step"),
		"remaining_time_presence": raw.has("remainingOverageTime"),
		"remainingOverageTime": raw.get("remainingOverageTime"),
		"engine_semantic_hash": engine_hash,
		"option_fingerprints": shared.get("option_fingerprints"),
		"search_capability_present": false,
		"search_binding_hmac": null,
	})
	var window_id := _hash("window_id", {
		"callback_binding_hash": callback_hash,
		"generation": window_generation,
	})
	var value := new()
	value._shared_window = shared
	value._private_options = private_options.duplicate()
	value._callback_binding_hash = callback_hash
	value.public_window = {
		"contract_generation": CONTRACT_GENERATION,
		"canonicalizer_id": "cabt_jcs_tree_hash_v1",
		"engine_semantic_hash": engine_hash,
		"policy_input_hash": policy_hash,
		"window_id": window_id,
		"window_generation": window_generation,
		"seat": seat,
		"select_type_raw": shared.get("select_type_raw"),
		"context_raw": shared.get("select_context_raw"),
		"min_count": shared.get("min_count"),
		"max_count": shared.get("max_count"),
		"remain_damage_counter": shared.get("remain_damage_counter"),
		"remain_energy_cost": shared.get("remain_energy_cost"),
		"options": shared.get("options"),
		"option_fingerprints": shared.get("option_fingerprints"),
		"authorized_deck": shared.get("public_deck_candidates"),
		"context_card": shared.get("context_card"),
		"effect": shared.get("effect"),
		"incremental_log_cursor": log_cursor,
		"incremental_log_hash": _hash("incremental_logs", raw.get("logs")),
		"time_budget": {
			"step_presence": raw.has("step"),
			"step": raw.get("step"),
			"remaining_overage_time_presence": raw.has("remainingOverageTime"),
			"remaining_overage_time": raw.get("remainingOverageTime"),
		},
		"capability_profile_hash": capability_profile_hash,
	}
	value.state = "issued"
	return {"ok": true, "error_code": "", "binding": value}


func accept(proposal: Variant) -> Dictionary:
	if state != "issued":
		return _error("cabt_window_stale")
	var validated: Variant = SanitizerScript.validate(_shared_window, proposal)
	if validated == null or not bool(validated.get("accepted")):
		return _error("invalid_agent_output")
	_accepted = validated
	state = "accepted"
	return {
		"ok": true,
		"error_code": "",
		"accepted": {
			"window_id": public_window.get("window_id"),
			"window_generation": public_window.get("window_generation"),
			"indexes": validated.get("selected_indexes"),
		},
	}


func bind(accepted: Variant) -> Dictionary:
	if state != "accepted" or not accepted is Dictionary:
		return _error("cabt_acceptance_binding_invalid")
	if (
		accepted.get("window_id") != public_window.get("window_id")
		or accepted.get("window_generation") != public_window.get("window_generation")
		or accepted.get("indexes") != _accepted.get("selected_indexes")
	):
		return _error("cabt_acceptance_binding_invalid")
	var targets: Array = []
	for index_value: Variant in accepted.get("indexes"):
		targets.append(_private_options[int(index_value)])
	_bound = {"accepted": accepted.duplicate(true), "private_targets": targets}
	state = "bound"
	return {"ok": true, "error_code": "", "bound": _bound.duplicate()}


func commit(bound: Variant, executor: Variant) -> Dictionary:
	if state != "bound" or not bound is Dictionary or bound != _bound:
		return _error("cabt_bound_selection_stale")
	if (
		executor == null
		or not executor.has_method("prepare")
		or not executor.has_method("commit")
		or not executor.has_method("rollback")
	):
		return _error("cabt_executor_invalid")
	var prepared: Variant = executor.call("prepare", _bound.get("private_targets"))
	if prepared == null:
		state = "invalidated"
		return _error("cabt_executor_atomic_failure")
	var result: Variant = executor.call("commit", prepared)
	if result == null:
		executor.call("rollback", prepared)
		state = "invalidated"
		return _error("cabt_executor_atomic_failure")
	_commit_result = result
	_private_options.clear()
	state = "committed"
	return {"ok": true, "error_code": "", "result": result}


func witness(next_callback: Variant) -> Dictionary:
	if state != "committed" or not next_callback is Dictionary:
		return _error("cabt_commit_witness_invalid")
	if not next_callback.get("logs") is Array:
		return _error("cabt_logs_invalid")
	var next_semantic := _hash("engine_semantic", {
		"select": next_callback.get("select"),
		"current": next_callback.get("current"),
		"logs": next_callback.get("logs"),
	})
	var next_logs := _hash("incremental_logs", next_callback.get("logs"))
	if (
		next_semantic == public_window.get("engine_semantic_hash")
		and next_logs == public_window.get("incremental_log_hash")
	):
		return _error("cabt_public_witness_missing")
	state = "public-witness"
	return {
		"ok": true,
		"error_code": "",
		"witness": {
			"window_id": public_window.get("window_id"),
			"window_generation": public_window.get("window_generation"),
			"committed_result": _commit_result,
			"post_engine_semantic_hash": next_semantic,
			"post_log_hash": next_logs,
			"public_witness": true,
		},
	}


func invalidate() -> void:
	_private_options.clear()
	state = "invalidated"


static func _hash(domain: String, value: Variant) -> String:
	var canonical: Dictionary = JsonTreeScript.canonicalize(value)
	if not bool(canonical.get("ok", false)):
		return ""
	var bytes := PackedByteArray()
	bytes.append_array("PTCGDAP".to_utf8_buffer())
	bytes.append(0)
	bytes.append_array("CABT_WINDOW_V2".to_utf8_buffer())
	bytes.append(0)
	bytes.append_array(domain.to_utf8_buffer())
	bytes.append(0)
	bytes.append_array(canonical.get("bytes", PackedByteArray()))
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(bytes) != OK:
		return ""
	return context.finish().hex_encode().to_upper()


static func _upper_sha(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or str(value).length() != 64 or str(value) != str(value).to_upper():
		return false
	for character: String in str(value):
		if character not in "0123456789ABCDEF":
			return false
	return true


static func _error(code: String) -> Dictionary:
	return {"ok": false, "error_code": code}
