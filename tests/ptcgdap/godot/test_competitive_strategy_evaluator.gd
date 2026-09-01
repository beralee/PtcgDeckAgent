class_name TestCompetitiveStrategyEvaluator
extends TestBase

const EvaluatorScript = preload("res://scripts/ai/ptcgdap/platform/evaluation/CompetitiveStrategyEvaluator.gd")


func test_trusted_shadow_bundle_and_signed_vectors_load() -> String:
	var loaded: Dictionary = EvaluatorScript.load_default()
	if not bool(loaded.get("accepted", false)):
		return "evaluator load failed: %s" % loaded
	var owner: Variant = loaded.get("owner")
	var audit: Dictionary = owner.audit_snapshot()
	return run_checks([
		assert_eq(audit.get("authority_mode"), "shadow_test_only"),
		assert_eq(audit.get("evaluator_id"), "ptcgdap-csp-wp2-shadow-evaluator"),
		assert_eq(audit.get("key_id"), "csp-wp2-rfc8032-fixture-key"),
		assert_false(bool(audit.get("production_authority", true))),
		assert_false(bool(audit.get("authoritative", true))),
		assert_eq(audit.get("grants"), []),
	])


func test_shared_signed_records_materialize_to_exact_expected_summary() -> String:
	var loaded: Dictionary = EvaluatorScript.load_default()
	if not bool(loaded.get("accepted", false)):
		return "evaluator load failed: %s" % loaded
	var owner: Variant = loaded.get("owner")
	var vectors: Dictionary = owner.conformance_vectors()
	var materialized: Dictionary = owner.materialize(vectors.records)
	if not bool(materialized.get("accepted", false)):
		return "materialization failed: %s" % materialized
	var reversed_records: Array = vectors.records.duplicate(true)
	reversed_records.reverse()
	var reversed_result: Dictionary = owner.materialize(reversed_records)
	return run_checks([
		assert_eq(materialized.get("summary"), vectors.expected_summary),
		assert_eq(reversed_result.get("summary"), vectors.expected_summary),
		assert_eq(materialized.get("verified_record_count"), 5),
		assert_eq(materialized.get("official_record_count"), 4),
		assert_eq(materialized.get("dirty_record_count"), 1),
	])


func test_shared_signature_and_identity_rejections_fail_closed() -> String:
	var loaded: Dictionary = EvaluatorScript.load_default()
	if not bool(loaded.get("accepted", false)):
		return "evaluator load failed: %s" % loaded
	var owner: Variant = loaded.get("owner")
	var vectors: Dictionary = owner.conformance_vectors()
	var checks: Array[String] = []
	for spec: Dictionary in vectors.rejection_cases:
		var result: Dictionary = owner.verify_record(spec.record)
		checks.append(assert_eq(result.get("error_code"), spec.error_code, spec.id))
		checks.append(assert_false(bool(result.get("accepted", false)), spec.id))
		checks.append(assert_eq(result.get("grants"), [], spec.id))
	return run_checks(checks)


func test_shared_integer_confidence_intervals_match_python_vectors() -> String:
	var loaded: Dictionary = EvaluatorScript.load_default()
	if not bool(loaded.get("accepted", false)):
		return "evaluator load failed: %s" % loaded
	var owner: Variant = loaded.get("owner")
	var vectors: Dictionary = owner.conformance_vectors()
	var checks: Array[String] = []
	for spec: Dictionary in vectors.confidence_interval_cases:
		var result: Dictionary = owner.confidence_interval_audit(int(spec.wins), int(spec.valid))
		checks.append(assert_true(bool(result.get("accepted", false)), str(spec)))
		checks.append(assert_eq(result.get("interval"), spec.expected, str(spec)))
	return run_checks(checks)
