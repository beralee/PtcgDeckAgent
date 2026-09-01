class_name TestEthansTyphlosionAuthorPackage
extends TestBase

const GateScript = preload(
	"res://scripts/ai/ptcgdap/host/godot/AuthorStrategyWindowsDevelopmentGate.gd"
)
const CatalogScript = preload(
	"res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageCatalog.gd"
)
const OwnerFactoryScript = preload(
	"res://scripts/ui/battle/ai/BattleDecisionOwnerFactory.gd"
)
const AuthorVsAuthorBenchmarkScript = preload(
	"res://scripts/tools/run_marnie_gift_box_vs_ogerpon.gd"
)
const BattleSetupScene = preload("res://scenes/battle_setup/BattleSetup.tscn")

const PACKAGE_ID := "dev.bodao-yongzhe.ethans-typhlosion"
const PACKAGE_VERSION := "0.1.0"
const ARCHIVE_SHA256 := "FDECBD7FE2C2F2DA9D890150E166498AE2F607BCDC19F393C16873DB2346B0EA"
const R10_PACKAGE_VERSION := "0.11.0"
const R10_ARCHIVE_SHA256 := "302CA76AEF1F4B918121B5CC06522B92B3A40248F06EF3890E629C27AA7C880C"
const FINAL_PACKAGE_VERSION := "0.6.0"
const FINAL_ARCHIVE_SHA256 := "26AD9CCCB2EA848AEA0D1A8D38DFDA0BE544E341D91A1E863654A4A28921F1FD"


func _selection(archive_sha256: String = ARCHIVE_SHA256) -> Dictionary:
	return {
		"package_id": PACKAGE_ID,
		"package_version": PACKAGE_VERSION,
		"archive_sha256": archive_sha256,
		"install_source": "built_in",
	}


func test_r0_exact_identity_is_the_only_admitted_development_candidate() -> String:
	var candidate: Dictionary = GateScript.candidate_for_selection(_selection())
	return run_checks([
		assert_false(candidate.is_empty(), "R0 exact package identity must be admitted"),
		assert_eq(candidate.get("source_deck_id"), 800018880),
		assert_eq(candidate.get("unique_printing_count"), 26),
		assert_eq(candidate.get("adapter_rule_count"), 82),
		assert_eq(candidate.get("runtime_kind"), "reviewed_competitive_policy_v2"),
		assert_eq(candidate.get("frame_profile_id"), "ptcgdap-competitive-public-frame-v2"),
		assert_true(
			GateScript.candidate_for_selection(_selection("%064d" % 0)).is_empty(),
			"A byte-different package must remain denied"
		),
	])


func test_r10_exact_identity_is_admitted_and_byte_drift_is_denied() -> String:
	var selection := {
		"package_id": PACKAGE_ID,
		"package_version": R10_PACKAGE_VERSION,
		"archive_sha256": R10_ARCHIVE_SHA256,
		"install_source": "built_in",
	}
	var candidate: Dictionary = GateScript.candidate_for_selection(selection)
	selection["archive_sha256"] = "%064d" % 0
	return run_checks([
		assert_false(candidate.is_empty(), "R10 exact package identity must be admitted"),
		assert_eq(candidate.get("source_deck_id"), 800018880),
		assert_eq(candidate.get("unique_printing_count"), 26),
		assert_eq(candidate.get("adapter_rule_count"), 91),
		assert_eq(
			candidate.get("strategy_id"),
			"bodao-yongzhe.ethans-typhlosion.competitive-v2-r10"
		),
		assert_true(
			GateScript.candidate_for_selection(selection).is_empty(),
			"A byte-different R10 package must remain denied"
		),
	])


func test_r0_package_materializes_the_exact_deck_and_binds_the_reviewed_owner() -> String:
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var requested: Dictionary = GateScript.request_match_handle(catalog, _selection(), "Windows")
	var handle: Variant = requested.get("handle")
	var deck: DeckData = CardDatabase.get_ai_deck(800018880)
	var opponent: DeckData = CardDatabase.get_ai_deck(800018501)
	var checks: Array[String] = []
	checks.append(assert_true(
		bool(requested.get("ok", false)),
		"R0 package must be locally discoverable: %s" % requested.get("error_code")
	))
	checks.append(assert_true(
		handle != null and handle.validate_integrity(),
		"R0 package handle must remain sealed"
	))
	var pins: Dictionary = handle.to_public_dict() if handle != null else {}
	checks.append(assert_eq(pins.get("local_deck_card_count"), 60))
	checks.append(assert_eq(pins.get("local_deck_unique_printing_count"), 26))
	checks.append(assert_not_null(deck, "Exact Typhlosion source deck must load"))
	checks.append(assert_not_null(opponent, "Binding fixture opponent deck must load"))
	if deck != null and opponent != null and handle != null:
		var gsm := GameStateMachine.new()
		gsm.start_game(deck, opponent, 0)
		var built: Dictionary = OwnerFactoryScript.build_windows_development_author_owner(
			handle, gsm, 0, "ethans-typhlosion-r0-owner"
		)
		var owner: Variant = built.get("owner")
		checks.append(assert_true(
			bool(built.get("ok", false)),
			"R0 owner bind failed: %s" % built.get("error_code")
		))
		checks.append(assert_eq(
			owner.get_script().resource_path if owner != null else "",
			"res://scripts/ai/ptcgdap/host/godot/ReviewedAuthorStrategyDevelopmentBattleOwner.gd"
		))
		checks.append(assert_true(
			owner != null and owner.validate_integrity(),
			"R0 reviewed owner must remain valid"
		))
		if owner != null:
			owner.close_match()
		gsm.prepare_for_disposal()
	catalog.free()
	return run_checks(checks)


func test_final_r5_is_visible_selectable_and_startable_in_battle_setup() -> String:
	var previous_mode: int = GameManager.current_mode
	var previous_selected_deck_ids: Array = GameManager.selected_deck_ids.duplicate()
	var previous_selection := GameManager.get_author_strategy_selection()
	var report: Dictionary = AuthorStrategyPackageCatalog.scan_startup()
	var scene := BattleSetupScene.instantiate()
	scene.call("_ready")
	scene.call("_apply_author_strategy_catalog_report", report)
	scene.call("_select_mode_option", 2)
	var reference := {
		"package_id": PACKAGE_ID,
		"package_version": FINAL_PACKAGE_VERSION,
		"archive_sha256": FINAL_ARCHIVE_SHA256,
		"install_source": "built_in",
	}
	var selected: bool = scene.call("_select_author_strategy_ref", reference)
	var start_button := scene.find_child("BtnStart", true, false) as Button
	var status_label := scene.find_child("AuthorStrategyStatusLabel", true, false) as Label
	var applied: bool = scene.call("_apply_setup_selection")
	var active_selection := GameManager.get_author_strategy_selection()
	var checks: Array[String] = [
		assert_true(selected, "BattleSetup must visibly select the exact retained R5 package"),
		assert_true(bool(scene.call("_author_strategy_start_allowed"))),
		assert_false(start_button.disabled, "The exact retained package must enable Start"),
		assert_eq(status_label.text, "已加载 · 可开战"),
		assert_true(applied, "BattleSetup must materialize the exact deck and accept Start"),
		assert_eq(active_selection.get("package_id"), PACKAGE_ID),
		assert_eq(active_selection.get("package_version"), FINAL_PACKAGE_VERSION),
		assert_eq(active_selection.get("archive_sha256"), FINAL_ARCHIVE_SHA256),
		assert_eq(GameManager.selected_deck_ids.size(), 2),
	]
	scene.free()
	GameManager.current_mode = previous_mode as GameManager.GameMode
	GameManager.selected_deck_ids = previous_selected_deck_ids
	GameManager.reset_author_strategy_selection()
	if not previous_selection.is_empty():
		GameManager.set_author_strategy_selection(previous_selection)
	return run_checks(checks)


func test_author_vs_author_cli_pins_typhlosion_and_marnie_18_exactly() -> String:
	var runner := AuthorVsAuthorBenchmarkScript.new()
	var parsed: Dictionary = runner._parse_args(PackedStringArray([
		"--candidate-deck-id=800018880",
		"--candidate-package-id=dev.bodao-yongzhe.ethans-typhlosion",
		"--package-version=0.1.0",
		"--opponent-deck-id=646600",
		"--opponent-package-id=dev.bodao-yongzhe.marnies-gift-box",
		"--opponent-package-version=1.8.0",
		"--opponent-archive-sha256=209FA7EDF7321A142F1B8A25E44667D44E49AF728E799AFF112716951E72DFD1",
	]))
	runner.free()
	return run_checks([
		assert_eq(parsed.get("candidate_deck_id"), 800018880),
		assert_eq(
			parsed.get("candidate_package_id"),
			"dev.bodao-yongzhe.ethans-typhlosion"
		),
		assert_eq(parsed.get("opponent_deck_id"), 646600),
		assert_eq(
			parsed.get("opponent_package_id"),
			"dev.bodao-yongzhe.marnies-gift-box"
		),
		assert_eq(parsed.get("opponent_package_version"), "1.8.0"),
		assert_eq(
			parsed.get("opponent_archive_sha256"),
			"209FA7EDF7321A142F1B8A25E44667D44E49AF728E799AFF112716951E72DFD1"
		),
	])
