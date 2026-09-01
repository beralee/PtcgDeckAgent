class_name TestMarnieGiftBox190
extends TestBase

const PACKAGE_ID := "dev.bodao-yongzhe.marnies-gift-box"
const PACKAGE_VERSION := "1.9.0"
const PACKAGE_SHA256 := "BDC7C0969D6F4A4F5CC94C480E3CE2C19F4C2542AB1902C16DEC51AE1333DB20"
const GateScript = preload(
	"res://scripts/ai/ptcgdap/host/godot/AuthorStrategyWindowsDevelopmentGate.gd"
)
const CatalogScript = preload(
	"res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageCatalog.gd"
)
const ReviewedPolicyScript = preload(
	"res://scripts/ai/ptcgdap/runtime/local/ReviewedAuthorStrategyDevelopmentPolicy.gd"
)


func _selection() -> Dictionary:
	return {
		"package_id": PACKAGE_ID,
		"package_version": PACKAGE_VERSION,
		"archive_sha256": PACKAGE_SHA256,
		"install_source": "built_in",
	}


func test_exact_1_9_0_package_binds_and_materializes_the_60_card_deck() -> String:
	var candidate: Dictionary = GateScript.candidate_for_package_identity(
		PACKAGE_ID, PACKAGE_VERSION
	)
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var requested: Dictionary = GateScript.request_match_handle(catalog, _selection(), "Windows")
	var handle: Variant = requested.get("handle")
	var created: Dictionary = ReviewedPolicyScript.create(handle, "marnie-1.9.0-focused") \
		if handle != null else {"ok": false, "error_code": "missing_handle"}
	var card_count := 0
	if handle != null:
		for row_value: Variant in handle.local_deck_snapshot():
			if row_value is Dictionary:
				card_count += int((row_value as Dictionary).get("count", 0))
	var checks: Array[String] = [
		assert_eq(candidate.get("archive_sha256"), PACKAGE_SHA256),
		assert_eq(candidate.get("adapter_rule_count"), 95),
		assert_true(bool(requested.get("ok", false)), "exact package must bind: %s" % requested),
		assert_true(handle != null and handle.validate_integrity(), "package handle must remain sealed"),
		assert_true(bool(created.get("ok", false)), "reviewed policy must create: %s" % created),
		assert_eq(card_count, 60, "exact package deck must contain 60 cards"),
	]
	catalog.free()
	return run_checks(checks)


func test_1_9_0_gate_rejects_wrong_hash_user_copy_and_non_windows_execution() -> String:
	var wrong_hash := _selection()
	wrong_hash["archive_sha256"] = "A".repeat(64)
	var user_copy := _selection()
	user_copy["install_source"] = "user"
	var checks: Array[String] = [
		assert_false(bool(GateScript.evaluate_selection(wrong_hash, "Windows").get("accepted", false))),
		assert_false(bool(GateScript.evaluate_selection(user_copy, "Windows").get("accepted", false))),
		assert_false(bool(GateScript.evaluate_selection(_selection(), "Android").get("accepted", false))),
	]
	return run_checks(checks)
