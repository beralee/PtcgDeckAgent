extends TestBase

const Owner = preload("res://scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorDevelopmentBattleOwner.gd")
const Actor = preload("res://scripts/ai/ptcgdap/host/godot/PtcgDAPModelActor.gd")

func test_projector_fingerprint_resolves_compiled_export_remap() -> String:
	var source := "user://parity-projector-fixture.gd"
	var artifact := source + "c"
	var file := FileAccess.open(artifact, FileAccess.WRITE)
	file.store_buffer(PackedByteArray([71, 68, 83, 67, 0, 1, 2, 3]))
	file.close()
	var remap := ConfigFile.new()
	remap.set_value("remap", "path", artifact)
	remap.save(source + ".remap")
	var actual: String = Owner._script_artifact_sha256(source)
	var expected := FileAccess.get_sha256(artifact)
	DirAccess.remove_absolute(artifact)
	DirAccess.remove_absolute(source + ".remap")
	return run_checks([assert_eq(actual, expected), assert_eq(actual.length(), 64)])

func _frame() -> Dictionary:
	return {"sequence": 7, "public_state": {"turn_number": 3, "self": {}, "opponent": {}},
		"select_semantics": {"min_count": 1, "max_count": 1},
		"options": [{"index": 0, "option_type_raw": 0, "option_number": 20},
			{"index": 1, "option_type_raw": 0, "option_number": 3}]}

func test_trace_records_exact_runtime_projection_and_rebinds_reordered_frontier() -> String:
	var owner = Owner.new()
	owner._model_actor = Actor.new()
	if not owner.has_method("_developer_model_evidence"):
		return "missing runtime model evidence capture"
	var frame := _frame()
	var evidence: Dictionary = owner.call("_developer_model_evidence", frame, {"selected_indexes": [1]})
	var runtime: Dictionary = owner._model_actor.call("_tensorize_development_frame", frame)
	var reordered := frame.duplicate(true)
	reordered.options.reverse()
	for i: int in reordered.options.size():
		reordered.options[i].index = i
	var rebound: Dictionary = owner.call("_developer_model_evidence", reordered, {"selected_indexes": [0]})
	return run_checks([
		assert_eq(evidence.get("status"), "captured"),
		assert_eq(evidence.get("frame_i32"), Array(runtime.frame_i32)),
		assert_eq(evidence.get("option_i32"), Array(runtime.option_i32.slice(0, 32))),
		assert_eq(evidence.get("frontier_indexes"), [1]),
		assert_eq(evidence.get("option_i32"), rebound.get("option_i32")),
		assert_eq(evidence.get("frontier_rows"), rebound.get("frontier_rows")),
		assert_eq(str(evidence.get("projector_sha256", "")).length(), 64),
	])

func test_trace_capture_rejects_hidden_unknown_uid_and_bad_indexes() -> String:
	var owner = Owner.new()
	owner._model_actor = Actor.new()
	if not owner.has_method("_developer_model_evidence"):
		return "missing runtime model evidence capture"
	var hidden := _frame()
	hidden.public_state.private_state = {"secret": 1}
	var unknown := _frame()
	unknown.options[0].card_uid = "UNKNOWN_001"
	return run_checks([
		assert_eq(owner.call("_developer_model_evidence", hidden, {"selected_indexes": [0]}).get("error_code"), "model_hidden_field"),
		assert_eq(owner.call("_developer_model_evidence", unknown, {"selected_indexes": [0]}).get("error_code"), "model_unknown_uid"),
		assert_eq(owner.call("_developer_model_evidence", _frame(), {"selected_indexes": [false]}).get("error_code"), "model_trace_rule_indexes_invalid"),
		assert_eq(owner.call("_developer_model_evidence", _frame(), {"selected_indexes": [2]}).get("error_code"), "model_trace_rule_indexes_invalid"),
	])

func test_trace_queue_keeps_capture_diagnostic_and_rejected_window_unavailable() -> String:
	var owner = Owner.new()
	owner._model_actor = Actor.new()
	owner.enable_developer_decision_trace(true)
	var frame := _frame()
	frame.source = {"public_observation_hash": "A".repeat(64), "window_id": "B".repeat(64)}
	var response := {"selected_indexes": [1], "decision_audit": {"base_result": {
		"node_audit": [{"operator": "base_veto", "output_indexes": [1]}]}}}
	owner.call("_queue_developer_decision", frame, response, [1], "accepted", false, "", 10)
	owner.call("_queue_developer_decision", frame, response, [0], "rejected", true, "fixture_rejected", 10)
	var records: Array = owner.drain_developer_decision_records()
	return run_checks([
		assert_eq(records.size(), 2),
		assert_eq(records[0].host.model_input_evidence.authority, "diagnostic_only"),
		assert_eq(records[0].host.model_input_evidence.frontier_indexes, [1]),
		assert_eq(records[0].host.accepted_indexes, [1]),
		assert_eq(records[1].host.model_input_evidence.error_code, "model_trace_host_not_accepted"),
		assert_false(frame.options[0].has("option_fingerprint")),
		assert_eq(response.selected_indexes, [1]),
	])

func test_trace_preserves_model_adjudication_without_timing_or_extra_fields() -> String:
	var owner = Owner.new()
	owner.enable_developer_decision_trace(true)
	var frame := _frame()
	frame.source = {"public_observation_hash": "A".repeat(64), "window_id": "B".repeat(64)}
	var response := {"selected_indexes": [1], "decision_audit": {"model": {
		"invoked": true, "diagnostic_code": "", "fallback_indexes": [1],
		"selected_indexes": [0], "elapsed_us": 999, "unapproved_extra": "excluded",
		"model_manifest_sha256": "C".repeat(64), "model_artifact_sha256": "D".repeat(64)}}}
	owner.call("_queue_developer_decision", frame, response, [0], "accepted", false, "", 10)
	var record: Dictionary = owner.drain_developer_decision_records()[0]
	var model: Dictionary = record.host.get("model_decision", {})
	return run_checks([
		assert_eq(record.policy.reported_indexes, [1]),
		assert_eq(record.host.accepted_indexes, [0]),
		assert_eq(model.get("selected_indexes"), [0]),
		assert_eq(model.get("fallback_indexes"), [1]),
		assert_eq(model.get("model_artifact_sha256"), "D".repeat(64)),
		assert_false(model.has("elapsed_us")),
		assert_false(model.has("unapproved_extra")),
	])
