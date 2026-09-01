class_name TestMarnieStateValueV2Package
extends TestBase

const PACKAGE_ID := "dev.bodao-yongzhe.marnies-gift-box"
const PACKAGE_VERSION := "5.37.1"
const PACKAGE_SHA256 := "83F9E82671927B5E37A895CCB6B5A46D1C294D88BE343B0B7EF81C5EACB98079"
const MODEL_SHA256 := "D0D9DBCF348FE70A6ACDBD62CDF6AA10AC86831748FBECC11FB39B51D19B29D5"
const MODEL_PROFILE_ID := "ptcgdap-state-conditioned-transaction-value-v2"
const GateScript = preload(
	"res://scripts/ai/ptcgdap/host/godot/AuthorStrategyWindowsDevelopmentGate.gd"
)
const CatalogScript = preload(
	"res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageCatalog.gd"
)
const ReviewedPolicyScript = preload(
	"res://scripts/ai/ptcgdap/runtime/local/ReviewedAuthorStrategyDevelopmentPolicy.gd"
)
const ReplayHarnessScript = preload(
	"res://tests/ptcgdap/godot/support/MarnieGiftBoxReplayExamHarness.gd"
)
const REPLAY_CORPUS_PATH := (
	"res://tests/ptcgdap/exams/marnie_gift_box_match_20260829_165713_715386_r54.json"
)
const STATE_CONDITIONED_CORPUS_PATH := (
	"res://tests/ptcgdap/exams/marnie_state_conditioned_transaction_windows_20260831.json"
)
const TRANSACTION_MIGRATED_EXPECTATIONS := {
	"t26_end_turn_after_munkidori_and_attachment_into_late_wall": [2],
	"tm_live_target_selects_two_distinct_snorunt_entities": [0, 2],
	"t9_skip_energy_search_when_munkidori_already_has_dark": [1],
}
const RECALIBRATED_EXAM_IDS := [
	"t31_do_not_add_second_froslass_after_damage_engine_expiry",
	"t13_use_tm_devolution_granted_attack_after_attaching_into_damage_wall",
]


func _selection() -> Dictionary:
	return {
		"package_id": PACKAGE_ID,
		"package_version": PACKAGE_VERSION,
		"archive_sha256": PACKAGE_SHA256,
		"install_source": "built_in",
	}


func test_state_conditioned_model_is_hash_bound_and_loaded_device_locally() -> String:
	var candidate: Dictionary = GateScript.candidate_for_package_identity(
		PACKAGE_ID, PACKAGE_VERSION
	)
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var requested: Dictionary = GateScript.request_match_handle(catalog, _selection(), "Windows")
	var handle: Variant = requested.get("handle")
	var presentation: Dictionary = handle.presentation_snapshot() if handle != null else {}
	var documents: Dictionary = handle.policy_documents() if handle != null else {}
	var values: Variant = documents.get("documents", {}).get("policy/config.json", {}).get(
		"values", {}
	)
	var created: Dictionary = ReviewedPolicyScript.create(
		handle, "marnie-state-conditioned-value-v2-focused"
	) if handle != null else {"ok": false, "error_code": "missing_handle"}
	var policy: Variant = created.get("policy")
	var audit: Dictionary = policy.audit_snapshot() if policy != null else {}
	var checks: Array[String] = [
		assert_eq(candidate.get("archive_sha256"), PACKAGE_SHA256),
		assert_true(bool(requested.get("ok", false)), "exact package must bind: %s" % requested),
		assert_true(handle != null and handle.validate_integrity(), "package handle must remain sealed"),
		assert_eq(presentation.get("author_name"), "波导的勇者"),
		assert_eq(presentation.get("strategy_name"), "玛俐的礼盒 v5.37.1"),
		assert_eq(presentation.get("package_version"), PACKAGE_VERSION),
		assert_eq(values.get("turn_program_conditioned_value_sha256"), MODEL_SHA256),
		assert_false(values.has("turn_program_conditioned_value_model"), "config must not inline a nested model"),
		assert_true(bool(created.get("ok", false)), "conditioned policy must create: %s" % created),
		assert_eq(audit.get("weights_sha256"), MODEL_SHA256),
		assert_eq(audit.get("learned_model"), MODEL_PROFILE_ID),
		assert_eq(audit.get("model_backend"), "gdscript_sparse_integer_v2"),
		assert_eq(audit.get("turn_program_value_model_version"), 2),
		assert_eq(audit.get("turn_program_minimum_utility_margin"), 200000),
		assert_false(bool(audit.get("learned_model_invoked", true)), "load alone is not invocation"),
	]
	catalog.free()
	return run_checks(checks)


func test_state_conditioned_candidate_preserves_all_replay_locked_decisions() -> String:
	var corpus: Dictionary = ReplayHarnessScript.load_corpus(REPLAY_CORPUS_PATH)
	corpus["strategy_package"] = _selection()
	for exam: Dictionary in corpus.get("exams", []):
		var migrated: Variant = TRANSACTION_MIGRATED_EXPECTATIONS.get(exam.get("exam_id"))
		if migrated is Array:
			exam["target_selected_indexes"] = migrated.duplicate()
	var report: Dictionary = ReplayHarnessScript.run_corpus(
		corpus, "target_selected_indexes", 1
	)
	var total: int = corpus.get("exams", []).size()
	var failures: Array = report.get("results", []).filter(
		func(result: Variant) -> bool: return not bool(result.get("passed", false))
	)
	return run_checks([
		assert_true(bool(report.get("ok", false)), "conditioned exam runner failed: %s" % report),
		assert_eq(report.get("total_exams"), total),
		assert_eq(
			report.get("passed_exams"), total,
			"conditioned replay regression: %s" % [failures]
		),
		assert_true(bool(report.get("all_passed", false))),
	])


func test_recalibrated_regression_windows_choose_preservation_over_redundant_development() -> String:
	var corpus: Dictionary = ReplayHarnessScript.load_corpus(REPLAY_CORPUS_PATH)
	corpus["strategy_package"] = _selection()
	var focused: Array = []
	for exam: Dictionary in corpus.get("exams", []):
		if exam.get("exam_id") in RECALIBRATED_EXAM_IDS:
			focused.append(exam)
	corpus["exams"] = focused
	var report: Dictionary = ReplayHarnessScript.run_corpus(
		corpus, "target_selected_indexes", 1
	)
	var failures: Array = report.get("results", []).filter(
		func(result: Variant) -> bool: return not bool(result.get("passed", false))
	)
	return run_checks([
		assert_eq(report.get("total_exams"), RECALIBRATED_EXAM_IDS.size()),
		assert_eq(
			report.get("passed_exams"), RECALIBRATED_EXAM_IDS.size(),
			"recalibration regression: %s" % [failures]
		),
		assert_true(bool(report.get("all_passed", false))),
	])


func test_exact_state_conditioned_transaction_windows_are_locked() -> String:
	var corpus: Dictionary = ReplayHarnessScript.load_corpus(STATE_CONDITIONED_CORPUS_PATH)
	corpus["strategy_package"] = _selection()
	var report: Dictionary = ReplayHarnessScript.run_corpus(
		corpus, "target_selected_indexes", 1
	)
	return run_checks([
		assert_eq(report.get("total_exams"), 2),
		assert_eq(
			report.get("passed_exams"), 2,
			"exact state-conditioned window regression: %s" % [report.get("results", [])]
		),
		assert_true(bool(report.get("all_passed", false))),
	])
