class_name TestPolicyExecutorConformance
extends TestBase

const RuntimeScript = preload("res://scripts/ai/ptcgdap/runtime/local/PolicyExecutorConformance.gd")

var _runtime: Variant = null


func _owner() -> Variant:
	if _runtime == null:
		_runtime = RuntimeScript.load_default()
	return _runtime


func test_declared_no_model_subset_matches_parent_and_all_p6_probes() -> String:
	var owner: Variant = _owner()
	if owner == null or not owner.is_valid():
		return "conformance owner failed: %s" % (owner.error_code() if owner != null else "null")
	var report: Dictionary = owner.run_all()
	if not bool(report.get("accepted", false)):
		return "conformance report rejected: %s" % JSON.stringify(report)
	if report.get("parent_vector_case_count") != 28 or report.get("parent_vector_mismatch_count") != 0:
		return "parent corpus mismatch"
	if report.get("probe_case_count") != 8 or report.get("probe_mismatch_count") != 0 or report.get("skipped_case_count") != 0:
		return "P6 probe mismatch or skip"
	if report.get("model") != {
		"learned_model":"none", "backend":"none", "operator_case_count":0, "operator_skip_count":0,
	}:
		return "no-model scope drift"
	for row_value: Variant in report.get("cases", []):
		if not row_value is Dictionary or not bool(row_value.get("matched", false)):
			return "shared probe mismatch: %s" % JSON.stringify(row_value)
	if report.get("public_only") != true or report.get("execution_authority") != false or report.get("production_ready") != false:
		return "conformance report authority drift"
	return ""
