class_name TestMarnieTrajectoryReplay
extends TestBase

const ReplayScript = preload("res://scripts/ai/ptcgdap/public/MarnieTrajectoryReplay.gd")
const VECTORS_PATH := "res://contracts/ptcgdap/marnie_trajectory_replay_conformance_vectors.json"

var _shared_owner: Variant = null


func _owner() -> Variant:
	if _shared_owner == null:
		_shared_owner = ReplayScript.load_default()
	return _shared_owner


func _read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return null
	return _restore_integer_tokens(parser.data)


func _restore_integer_tokens(value: Variant) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			var number := float(value)
			return int(number) if is_finite(number) and number == floorf(number) else number
		TYPE_ARRAY:
			var array: Array = []
			for child: Variant in value:
				array.append(_restore_integer_tokens(child))
			return array
		TYPE_DICTIONARY:
			var object: Dictionary = {}
			for key: Variant in value:
				object[key] = _restore_integer_tokens(value[key])
			return object
	return value


func _materialize(value: Variant) -> Variant:
	if value is Dictionary:
		if value.keys().size() == 2 and value.get("host_type") == "integer" and value.has("value"):
			return int(value.get("value"))
		var object: Dictionary = {}
		for key: Variant in value:
			object[key] = _materialize(value[key])
		return object
	if value is Array:
		var array: Array = []
		for child: Variant in value:
			array.append(_materialize(child))
		return array
	return value


func test_all_parent_frames_replay_in_order() -> String:
	var checks: Array[String] = []
	var owner: Variant = _owner()
	checks.append(assert_true(owner != null and owner.ok))
	var result: Variant = owner.replay_all()
	checks.append(assert_true(result.validate_integrity(owner)))
	var payload: Dictionary = result.to_public_dict()
	checks.append(assert_true(payload.get("accepted", false)))
	checks.append(assert_eq((payload.get("frames", []) as Array).size(), 13))
	checks.append(assert_eq(payload.get("frames", [])[0].get("frame_id"), "w0_initial"))
	checks.append(assert_eq(payload.get("frames", [])[-1].get("frame_id"), "w7_terminal"))
	for frame_value: Variant in payload.get("frames", []).slice(0, 12):
		checks.append(assert_eq(frame_value.get("firewall_status"), "accepted"))
	checks.append(assert_eq(payload.get("frames", [])[-1].get("firewall_status"), "not_applicable_terminal"))
	return run_checks(checks)


func test_w2_exact_scope_and_no_identity_reconstruction() -> String:
	var checks: Array[String] = []
	var owner: Variant = _owner()
	var result: Variant = owner.replay_frame("w2_setup_bench")
	var frame: Dictionary = result.to_public_dict().get("frames", [])[0]
	checks.append(assert_eq(frame.get("compatibility_rule"), "setup_bench_concealment_v1"))
	checks.append(assert_eq(frame.get("public_hash_authority"), "firewall_accepted"))
	checks.append(assert_eq(frame.get("own_active"), [null]))
	checks.append(assert_eq(frame.get("option_count"), 1))
	return run_checks(checks)


func test_scope_mutations_fail_closed() -> String:
	var checks: Array[String] = []
	var owner: Variant = _owner()
	for pair: Array in [["select_type", 0], ["select_context", 1], ["turn", 1], ["own_active", []]]:
		var result: Dictionary = owner.probe_w2_mutation(pair[0], pair[1])
		checks.append(assert_false(result.get("ok", true)))
		checks.append(assert_true(result.get("error_code") in ["setup_concealment_scope_mismatch", "own_active_concealed"]))
	return run_checks(checks)


func test_result_copy_and_mutation_fail_closed() -> String:
	var checks: Array[String] = []
	var owner: Variant = _owner()
	var result: Variant = owner.replay_frame("w2_setup_bench")
	var copied: Dictionary = result.to_public_dict()
	copied.get("frames", [])[0]["own_active"] = [{"private": "sentinel"}]
	checks.append(assert_true(result.validate_integrity(owner)))
	checks.append(assert_eq(result.to_public_dict().get("frames", [])[0].get("own_active"), [null]))
	result.set("_snapshot", copied)
	checks.append(assert_false(result.validate_integrity(owner)))
	checks.append(assert_eq(result.to_public_dict(), {}))
	return run_checks(checks)


func test_all_shared_vectors_match_python_result_shape() -> String:
	var checks: Array[String] = []
	var owner: Variant = _owner()
	var vectors: Variant = _read_json(VECTORS_PATH)
	checks.append(assert_true(vectors is Dictionary))
	if not vectors is Dictionary:
		return run_checks(checks)
	var cases: Array = vectors.get("cases", [])
	checks.append(assert_eq(cases.size(), 19))
	for case_value: Variant in cases:
		checks.append(assert_true(case_value is Dictionary))
		if not case_value is Dictionary:
			continue
		var operation: Variant = _materialize(case_value.get("operation"))
		var input_value: Variant = _materialize(case_value.get("input"))
		var actual: Dictionary
		if operation == "run":
			actual = owner.run(input_value.get("operation"), input_value.get("value"))
		else:
			actual = owner.run(operation, input_value)
		if case_value.has("expected_error_code"):
			checks.append(assert_eq(actual, {"ok":false,"error_code":case_value.get("expected_error_code"),"value":null}))
			continue
		var expected: Dictionary = case_value.get("expected")
		if operation == "replay_all":
			checks.append(assert_true(actual.get("ok", false)))
			checks.append(assert_eq(actual.get("value", {}).get("frame_count"), expected.get("frame_count")))
			checks.append(assert_eq(actual.get("value", {}).get("chain_head"), expected.get("chain_head")))
		elif operation == "replay_frame":
			checks.append(assert_true(actual.get("ok", false)))
			checks.append(assert_eq(actual.get("value", {}).get("frames", [])[0], expected.get("frame")))
		else:
			checks.append(assert_eq(actual, expected))
	return run_checks(checks)


func test_owner_internal_rebaseline_and_cross_owner_result_binding_fail_closed() -> String:
	var checks: Array[String] = []
	var owner: Variant = ReplayScript.load_default()
	var other: Variant = _owner()
	checks.append(assert_true(owner != null and owner.ok))
	var result: Variant = owner.replay_frame("w2_setup_bench")
	checks.append(assert_false(result.validate_integrity(other)))
	var forged: Dictionary = owner.get("_replay").duplicate(true)
	forged.get("frames", []).reverse()
	owner.set("_replay", forged)
	owner.set("_runtime_integrity_sha256", owner.call("_runtime_digest"))
	checks.append(assert_false(owner.validate_integrity()))
	checks.append(assert_false(result.validate_integrity(owner)))
	checks.append(assert_eq(result.to_public_dict(), {}))
	return run_checks(checks)
