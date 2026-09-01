class_name TestMarnieCapabilityPolicy
extends TestBase

const PolicyScript = preload("res://scripts/ai/ptcgdap/public/MarnieCapabilityPolicy.gd")
const VECTORS_PATH := "res://contracts/ptcgdap/marnie_capability_policy_conformance_vectors.json"

var _shared_owner: Variant = null


func _owner() -> Variant:
	if _shared_owner == null:
		_shared_owner = PolicyScript.load_default()
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


func _write_policy_bundle(root: String, value: Dictionary) -> bool:
	var directory := ProjectSettings.globalize_path("%s/contracts/ptcgdap" % root)
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		return false
	var file := FileAccess.open("%s/contracts/ptcgdap/marnie_capability_policy_bundle.json" % root, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value))
	return true


func _remove_policy_bundle(root: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/contracts/ptcgdap/marnie_capability_policy_bundle.json" % root))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/contracts/ptcgdap" % root))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/contracts" % root))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(root))


func _clone_validated_owner(source: Variant) -> Variant:
	if source == null or not bool(source.get("ok")):
		return null
	var clone: Variant = PolicyScript.new()
	for field: String in ["_bundle", "_schema", "_profile", "_policy", "_vectors", "_expected_frames"]:
		clone.set(field, source.get(field).duplicate(true))
	clone.set("_parent_owner", source.get("_parent_owner"))
	clone.set("_replay_owner", source.get("_replay_owner"))
	clone.set("_runtime_integrity_sha256", source.get("_runtime_integrity_sha256"))
	clone.set("_load_attempted", true)
	clone.set("_ok", true)
	clone.set("_error_code", "")
	return clone if clone.validate_integrity() else null


func test_all_shared_vectors_match_without_skip() -> String:
	var checks: Array[String] = []
	var owner: Variant = _owner()
	checks.append(assert_true(owner != null and owner.ok))
	var vectors: Variant = _read_json(VECTORS_PATH)
	checks.append(assert_true(vectors is Dictionary))
	if not vectors is Dictionary:
		return run_checks(checks)
	var cases: Array = vectors.get("cases", [])
	checks.append(assert_eq(cases.size(), 23))
	var seen := {}
	for case_value: Variant in cases:
		checks.append(assert_true(case_value is Dictionary))
		if not case_value is Dictionary:
			continue
		var case_id: Variant = case_value.get("case_id")
		checks.append(assert_true(typeof(case_id) == TYPE_STRING and not seen.has(case_id)))
		seen[case_id] = true
		var actual: Dictionary = owner.run(
			_materialize(case_value.get("operation")),
			_materialize(case_value.get("input")),
		)
		checks.append(assert_eq(actual, case_value.get("expected")))
	return run_checks(checks)


func test_all_results_bind_exact_public_windows_and_never_execute() -> String:
	var checks: Array[String] = []
	var owner: Variant = _owner()
	var result: Variant = owner.evaluate_all()
	checks.append(assert_true(result != null and result.validate_integrity(owner)))
	var payload: Dictionary = result.to_public_dict()
	checks.append(assert_eq(payload.get("frame_count"), 13))
	checks.append(assert_false(payload.get("production_actions_used", true)))
	checks.append(assert_false(payload.get("execution_authority", true)))
	var previous: Variant = null
	for decision_value: Variant in payload.get("frames", []):
		checks.append(assert_true(decision_value is Dictionary))
		if not decision_value is Dictionary:
			continue
		var decision: Dictionary = decision_value
		checks.append(assert_eq(decision.get("previous_decision_hash"), previous))
		previous = decision.get("decision_hash")
		checks.append(assert_false(decision.get("production_action_used", true)))
		checks.append(assert_false(decision.get("execution_authority", true)))
		var indexes: Variant = decision.get("selected_indexes")
		if indexes == null:
			continue
		var frame: Dictionary = owner.get("_parent_owner").frame(decision.get("frame_id"))
		var window: Dictionary = frame.get("window")
		checks.append(assert_eq(decision.get("public_observation_hash"), frame.get("public_observation_hash")))
		checks.append(assert_eq(decision.get("window_id"), window.get("window_id")))
		checks.append(assert_eq(decision.get("option_fingerprints"), window.get("option_fingerprints")))
		checks.append(assert_true(indexes.size() >= window.get("min_count") and indexes.size() <= window.get("max_count")))
		var unique := {}
		for index_value: Variant in indexes:
			checks.append(assert_true(typeof(index_value) == TYPE_INT and index_value >= 0 and index_value < window.get("options", []).size()))
			checks.append(assert_false(unique.has(index_value)))
			unique[index_value] = true
	return run_checks(checks)


func test_result_copy_mutation_cross_owner_and_internal_rebaseline_fail_closed() -> String:
	var checks: Array[String] = []
	var owner: Variant = _owner()
	var other: Variant = _clone_validated_owner(owner)
	checks.append(assert_true(owner != null and owner.ok))
	checks.append(assert_true(other != null and other.ok))
	var result: Variant = owner.evaluate_frame("w6_shadow_bullet_attack")
	checks.append(assert_true(result.validate_integrity(owner)))
	checks.append(assert_false(result.validate_integrity(other)))
	var changed: Dictionary = result.to_public_dict()
	changed.get("frames", [])[0]["selected_indexes"] = [999]
	checks.append(assert_eq(result.to_public_dict().get("frames", [])[0].get("selected_indexes"), [1]))
	result.set("_snapshot", changed)
	checks.append(assert_false(result.validate_integrity(owner)))
	checks.append(assert_eq(result.to_public_dict(), {}))
	var forged: Variant = _clone_validated_owner(owner)
	checks.append(assert_true(forged != null and forged.ok))
	var forged_frames: Array = forged.get("_expected_frames").duplicate(true)
	forged_frames[4]["selected_indexes"] = [999]
	forged.set("_expected_frames", forged_frames)
	forged.set("_runtime_integrity_sha256", forged.call("_runtime_digest"))
	checks.append(assert_false(forged.validate_integrity()))
	checks.append(assert_eq(forged.run("evaluate_all", {}), {"ok":false,"error_code":"policy_integrity_invalid","value":null}))
	return run_checks(checks)


func test_wrong_type_private_and_stale_mutations_fail_closed() -> String:
	var checks: Array[String] = []
	var owner: Variant = _owner()
	checks.append(assert_eq(owner.run("evaluate_frame", {"frame_id":1}), {"ok":false,"error_code":"input_type_invalid","value":null}))
	checks.append(assert_eq(owner.run("evaluate_frame", {"frame_id":"private_sentinel"}), {"ok":false,"error_code":"frame_unknown","value":null}))
	checks.append(assert_eq(owner.run("private_sentinel", {}), {"ok":false,"error_code":"operation_unknown","value":null}))
	for field: String in ["public_observation_hash", "window_id", "option_fingerprints", "options", "min_count"]:
		var value: Variant = "reverse" if field == "options" else [] if field == "option_fingerprints" else 2 if field == "min_count" else "0000000000000000000000000000000000000000000000000000000000000000"
		checks.append(assert_eq(owner.probe_frame_mutation("w4_spikemuth_deck", field, value), {"ok":false,"error_code":"frame_binding_mismatch","value":null}))
	var private: Dictionary = owner.probe_frame_mutation("w4_spikemuth_deck", "private_sentinel", "private_sentinel")
	checks.append(assert_eq(private, {"ok":false,"error_code":"input_type_invalid","value":null}))
	checks.append(assert_false(str(private).contains("private_sentinel")))
	return run_checks(checks)


func test_loader_trust_anchor_and_direct_constructor_fail_closed() -> String:
	var checks: Array[String] = []
	var direct: Variant = PolicyScript.new()
	checks.append(assert_false(direct.ok))
	var missing: Variant = PolicyScript.load_from_root("user://missing-marnie-policy-root")
	checks.append(assert_false(missing.ok))
	checks.append(assert_true(missing.error_code in ["policy_file_missing", "policy_path_invalid"]))
	var root := "user://marnie-policy-tamper"
	_remove_policy_bundle(root)
	var bundle: Dictionary = _read_json("res://contracts/ptcgdap/marnie_capability_policy_bundle.json")
	var drift: Dictionary = bundle.duplicate(true)
	drift["status"] = "private_sentinel"
	checks.append(assert_true(_write_policy_bundle(root, drift)))
	var changed: Variant = PolicyScript.load_from_root(root)
	checks.append(assert_false(changed.ok))
	checks.append(assert_eq(changed.error_code, "policy_bundle_trust_anchor_mismatch"))
	var resigned: Dictionary = bundle.duplicate(true)
	resigned.get("artifacts", [])[0]["canonical_sha256"] = "0000000000000000000000000000000000000000000000000000000000000000"
	checks.append(assert_true(_write_policy_bundle(root, resigned)))
	var self_signed: Variant = PolicyScript.load_from_root(root)
	checks.append(assert_false(self_signed.ok))
	checks.append(assert_eq(self_signed.error_code, "policy_bundle_trust_anchor_mismatch"))
	_remove_policy_bundle(root)
	var owner: Variant = _owner()
	checks.append(assert_eq(owner.bundle_hash(), "F4E88E5DB4E480BA8441BE7B3A7C81CE3DB40ED1917EB37BCDCAC1C32B1ABD6C"))
	checks.append(assert_eq(owner.audit_snapshot().get("runtime_integrity_sha256"), "4CE8CE339F1C147C2E8A8CC44E70FB38B33551C2B1AF6C3E406C675F7BBEFACE"))
	return run_checks(checks)
