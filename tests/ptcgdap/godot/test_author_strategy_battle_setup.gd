class_name TestAuthorStrategyBattleSetup
extends TestBase

const SetupModelScript = preload("res://scripts/ui/battle/author_strategy/AuthorStrategySetupModel.gd")
const BattleSetupScene = preload("res://scenes/battle_setup/BattleSetup.tscn")
const FeatureGateScript = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyFeatureGate.gd")
const CatalogScript = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageCatalog.gd")

const HASH_A := "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
const HASH_B := "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"
const MARNIE_PACKAGE_ID := "ptcgdap.marnie.windows-local"
const MARNIE_ARCHIVE_SHA256 := "32E25453431886F76CEC606089ED4815EC681FBD33073F53A335A769D293643E"


func _record(package_id: String, archive_sha256: String, status: String, display_name: String = "同名策略") -> Dictionary:
	return {
		"package_id": package_id,
		"package_version": "1.2.3",
		"archive_sha256": archive_sha256,
		"install_source": "user",
		"author": {"author_id": "author.%s" % package_id, "display_name": "作者\n名称"},
		"strategy": {"display_name": display_name, "summary": "只读\t元数据"},
		"deck": {"display_name": "测试卡组"},
		"status": status,
		"metadata_only": status == "metadata_only",
		"execution_authority": false,
		"live_consumer": false,
	}


func _report(records: Array[Dictionary], diagnostics: Array[Dictionary] = []) -> Dictionary:
	return {
		"schema_version": 1,
		"metadata_records": records,
		"ready_records": [],
		"diagnostics": diagnostics,
		"metadata_only": true,
		"match_authority": false,
	}


func _snapshot_settings_file() -> Dictionary:
	const PATH := "user://battle_setup.json"
	if not FileAccess.file_exists(PATH):
		return {"exists": false, "text": ""}
	var file := FileAccess.open(PATH, FileAccess.READ)
	return {"exists": file != null, "text": file.get_as_text() if file != null else ""}


func _restore_settings_file(snapshot: Dictionary) -> void:
	const PATH := "user://battle_setup.json"
	if bool(snapshot.get("exists", false)):
		var file := FileAccess.open(PATH, FileAccess.WRITE)
		if file != null:
			file.store_string(str(snapshot.get("text", "")))
		return
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_setup_model_uses_exact_identity_not_display_name_and_is_copy_safe() -> String:
	var source: Array[Dictionary] = [_record("pkg.alpha", HASH_A, "metadata_only"), _record("pkg.beta", HASH_B, "untrusted")]
	var preferred := SetupModelScript.stable_ref(source[1])
	var view: Dictionary = SetupModelScript.normalize_catalog_report(_report(source), preferred)
	var records: Array = view.get("records", [])
	var selected_index := int(view.get("selected_index", -1))
	if records.size() > 0:
		records[0]["display_name"] = "已修改"
	return run_checks([
		assert_eq(records.size(), 2),
		assert_eq(selected_index, 1, "Stable package identity should restore the exact package"),
		assert_eq(source[0].get("strategy", {}).get("display_name"), "同名策略", "Normalized UI records must not alias catalog metadata"),
		assert_false(bool(view.get("start_allowed", true)), "AS-WP3 must never grant start authority"),
		assert_eq(records[1].get("stable_ref"), preferred),
	])


func test_setup_model_builds_one_compact_author_package_label_without_changing_identity() -> String:
	var source := _record(
		"pkg.compact",
		HASH_A,
		"metadata_only",
		"18.0 玛俐长毛巨魔完整作者策略"
	)
	var view: Dictionary = SetupModelScript.normalize_catalog_report(_report([source]))
	var record: Dictionary = view.get("records", [])[0]
	var selection: Dictionary = SetupModelScript.setup_selection_record(record)
	var windows_candidate := _record(
		"pkg.windows-candidate",
		HASH_B,
		"metadata_only",
		"竹兰烈咬陆鲨 Windows 本地候选 v1"
	)
	windows_candidate["package_version"] = "v0.1.0"
	var candidate_view: Dictionary = SetupModelScript.normalize_catalog_report(
		_report([windows_candidate])
	)
	var candidate: Dictionary = candidate_view.get("records", [])[0]
	return run_checks([
		assert_eq(record.get("display_name"), "18.0 玛俐长毛巨魔完整作者策略", "Full authored metadata must remain available"),
		assert_eq(record.get("short_display_name"), "18.0 玛俐长毛巨魔"),
		assert_eq(record.get("display_label"), "18.0 玛俐长毛巨魔 · 作者 名称 · v1.2.3"),
		assert_eq(selection.get("display_name_snapshot"), "18.0 玛俐长毛巨魔完整作者策略", "UI compaction must not rewrite the stored package snapshot"),
		assert_eq(candidate.get("display_label"), "竹兰烈咬陆鲨 · 作者 名称 · v0.1.0", "A pre-prefixed version must not render as vv0.1.0"),
		assert_eq(candidate.get("stable_ref"), SetupModelScript.stable_ref(windows_candidate), "Compact copy must not participate in identity"),
	])


func test_setup_model_covers_all_declared_statuses_and_sanitizes_display_text() -> String:
	var statuses := ["ready", "metadata_only", "incompatible", "untrusted", "invalid", "disabled"]
	var records: Array[Dictionary] = []
	for index: int in statuses.size():
		records.append(_record("pkg.%d" % index, HASH_A if index == 0 else HASH_B.left(63) + str(index), statuses[index]))
	var view: Dictionary = SetupModelScript.normalize_catalog_report(_report(records))
	var normalized: Array = view.get("records", [])
	var actual_statuses: Array[String] = []
	for item: Dictionary in normalized:
		actual_statuses.append(str(item.get("status", "")))
	return run_checks([
		assert_eq(actual_statuses, statuses),
		assert_false("\n" in str(normalized[0].get("author_name", ""))),
		assert_false("\t" in str(normalized[0].get("summary", ""))),
		assert_false(bool(normalized[0].get("start_allowed", true)), "Even synthetic ready metadata is setup-only in AS-WP3"),
	])


func test_setup_model_does_not_treat_release_metadata_as_live_authority() -> String:
	var authorized := _record("pkg.ready", HASH_A, "ready")
	authorized["match_authority"] = true
	authorized["execution_authority"] = true
	authorized["live_consumer"] = true
	var display_only := authorized.duplicate(true)
	display_only["package_id"] = "pkg.display-only"
	display_only["archive_sha256"] = HASH_B
	display_only["execution_authority"] = false
	var view: Dictionary = SetupModelScript.normalize_catalog_report(_report([authorized, display_only]))
	var records: Array = view.get("records", [])
	return run_checks([
		assert_false(bool(records[0].get("start_allowed", true)), "Package-level release metadata must not enable an incomplete W0-W7 live owner"),
		assert_false(bool(records[1].get("start_allowed", true)), "Ready display copy without execution authority must remain disabled"),
		assert_false(bool(view.get("start_allowed", true)), "The selected record must remain setup-only throughout AS-WP6"),
	])


func test_setup_model_missing_identity_restores_no_selection() -> String:
	var missing := {"package_id": "missing", "package_version": "1.2.3", "archive_sha256": HASH_B}
	var view: Dictionary = SetupModelScript.normalize_catalog_report(_report([_record("pkg.alpha", HASH_A, "metadata_only")]), missing)
	var empty: Dictionary = SetupModelScript.normalize_catalog_report(_report([], [{"error_code": "package_archive_invalid"}]))
	return run_checks([
		assert_eq(view.get("selected_index"), -1),
		assert_eq(view.get("selected_ref"), {}),
		assert_eq(empty.get("empty_reason"), "catalog_invalid"),
	])


func test_game_manager_author_selection_is_strict_copy_in_copy_out() -> String:
	var previous_mode: int = GameManager.current_mode
	var previous: Dictionary = GameManager.get_author_strategy_selection()
	var input := {
		"package_id": "pkg.alpha",
		"package_version": "1.2.3",
		"archive_sha256": HASH_A,
		"display_name_snapshot": "策略 A",
		"install_source": "user",
		"ignored_payload": {"private": true},
	}
	var accepted: bool = GameManager.set_author_strategy_selection(input)
	input["package_id"] = "mutated"
	var first: Dictionary = GameManager.get_author_strategy_selection()
	first["package_id"] = "mutated-again"
	var second: Dictionary = GameManager.get_author_strategy_selection()
	GameManager.current_mode = GameManager.GameMode.VS_AUTHOR_STRATEGY_AI
	GameManager.selected_deck_ids = [11, 22]
	var opponent_deck := GameManager.resolve_selected_battle_deck(1)
	GameManager.reset_author_strategy_selection()
	if not previous.is_empty():
		GameManager.set_author_strategy_selection(previous)
	GameManager.current_mode = previous_mode as GameManager.GameMode
	return run_checks([
		assert_true(accepted),
		assert_eq(second.get("package_id"), "pkg.alpha"),
		assert_false(second.has("ignored_payload"), "GameManager must retain only the setup record allow-list"),
		assert_null(opponent_deck, "Author opponent deck has no authority before AS-WP4 match handle"),
	])


func test_scene_unifies_author_packages_into_the_ai_opponent_surface() -> String:
	var scene := BattleSetupScene.instantiate()
	scene.call("_ready")
	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	var mode_segment := scene.find_child("ModeSegment", true, false) as HBoxContainer
	var author_button := scene.find_child("ModeAuthorStrategyButton", true, false) as Button
	var author_panel := scene.find_child("AuthorStrategyPanel", true, false) as Control
	var package_option := scene.find_child("AuthorStrategyPackageOption", true, false) as OptionButton
	var status_label := scene.find_child("AuthorStrategyStatusLabel", true, false) as Label
	var details_label := scene.find_child("AuthorStrategyDetailsLabel", true, false) as Label
	var result := run_checks([
		assert_eq(mode_option.item_count, 3),
		assert_eq(mode_segment.get_child_count() if mode_segment != null else 0, 3),
		assert_true(author_button is Button),
		assert_false(author_button.visible, "The separate author-package mode must not remain a competing user-facing mode"),
		assert_true(author_panel is Control),
		assert_true(package_option is OptionButton),
		assert_true(status_label is Label),
		assert_true(details_label is Label),
	])
	scene.free()
	return result


func test_ai_deck_picker_lists_author_packages_and_keeps_the_independent_owner() -> String:
	var previous_mode: int = GameManager.current_mode
	var previous_selected_deck_ids: Array = GameManager.selected_deck_ids.duplicate()
	var previous_selection := GameManager.get_author_strategy_selection()
	var scene := BattleSetupScene.instantiate()
	scene.call("_ready")
	var classic_strategy := GameManager.ai_deck_strategy
	scene.call("_apply_author_strategy_catalog_report", _report([_record("pkg.alpha", HASH_A, "ready", "本地作者 AI")]))
	var classic_button := scene.find_child("ModeAIButton", true, false) as Button
	classic_button.pressed.emit()
	if not scene.has_method("_on_deck_picker_author_strategy_selected"):
		scene.free()
		return "AI deck picker does not support author strategy package entries"
	scene.call("_on_deck_picker_pressed", 1)
	var picker_author := scene.find_child("AuthorStrategyPickerButton", true, false) as Button
	if picker_author == null:
		scene.free()
		return "AI deck picker did not render the loaded author strategy package"
	var picker_text := picker_author.text
	picker_author.pressed.emit()
	var package_option := scene.find_child("AuthorStrategyPackageOption", true, false) as OptionButton
	var panel := scene.find_child("AuthorStrategyPanel", true, false) as Control
	var deck2_row := scene.find_child("Deck2Row", true, false) as Control
	var deck2_button := scene.find_child("Deck2PickerButton", true, false) as Button
	var strategy_segment := scene.find_child("AIStrategySegment", true, false) as Control
	var llm_row := scene.find_child("LLMModelRow", true, false) as Control
	var start_button := scene.find_child("BtnStart", true, false) as Button
	var apply_result: bool = scene.call("_apply_setup_selection")
	var author_checks: Array[String] = [
		assert_true(panel.visible),
		assert_true(deck2_row.visible, "AI opponent selection must stay visible for author packages"),
		assert_eq(picker_text, "本地作者 AI · 作者 名称 · v1.2.3"),
		assert_eq(package_option.get_item_text(0), "本地作者 AI · 作者 名称 · v1.2.3"),
		assert_eq(deck2_button.text, "本地作者 AI · 作者 名称 · v1.2.3"),
		assert_false(strategy_segment.visible),
		assert_false(llm_row.visible),
		assert_true(start_button.disabled),
		assert_false(apply_result, "AS-WP3 author mode must refuse live battle setup"),
		assert_eq(GameManager.ai_deck_strategy, classic_strategy, "Author metadata must not pollute classic AI strategy"),
	]
	var classic_decks: Array = scene.get("_ai_deck_list")
	if not classic_decks.is_empty():
		var first_classic: DeckData = classic_decks[0]
		scene.call("_on_deck_picker_deck_selected", 1, first_classic.id)
	author_checks.append(assert_false(panel.visible, "Classic AI mode should hide the author package panel"))
	author_checks.append(assert_true(deck2_row.visible, "Classic AI deck controls should be restored"))
	author_checks.append(assert_eq(GameManager.get_author_strategy_selection(), {}, "Returning to a classic deck must clear package ownership"))
	scene.free()
	GameManager.current_mode = previous_mode as GameManager.GameMode
	GameManager.selected_deck_ids = previous_selected_deck_ids
	GameManager.reset_author_strategy_selection()
	if not previous_selection.is_empty():
		GameManager.set_author_strategy_selection(previous_selection)
	return run_checks(author_checks)


func test_ai_picker_distinguishes_loaded_from_currently_executable() -> String:
	var scene := BattleSetupScene.instantiate()
	scene.call("_ready")
	var executable := _record(MARNIE_PACKAGE_ID, MARNIE_ARCHIVE_SHA256, "metadata_only", "玛俐开发策略")
	executable["package_version"] = "0.1.0"
	executable["install_source"] = "built_in"
	var selectable_only := _record("pkg.selectable-only", HASH_A, "metadata_only", "普通本地策略")
	var result := run_checks([
		assert_eq(scene.call("_author_strategy_display_status_label", executable), "已加载 · 可开战"),
		assert_str_contains(str(scene.call("_author_strategy_display_status_detail", executable)), "重新验证"),
		assert_eq(scene.call("_author_strategy_display_status_label", selectable_only), "已加载 · 暂不可开战"),
		assert_str_contains(str(scene.call("_author_strategy_display_status_detail", selectable_only)), "当前执行门未放行"),
	])
	scene.free()
	return result


func test_settings_persist_only_exact_stable_ref_and_missing_identity_selects_none() -> String:
	var settings_snapshot := _snapshot_settings_file()
	var previous_selection := GameManager.get_author_strategy_selection()
	var previous_mode: int = GameManager.current_mode
	var alpha := _record("pkg.alpha", HASH_A, "metadata_only")
	var beta := _record("pkg.beta", HASH_B, "untrusted")
	var beta_ref := SetupModelScript.stable_ref(beta)
	var scene := BattleSetupScene.instantiate()
	scene.call("_ready")
	scene.call("_apply_author_strategy_catalog_report", _report([alpha, beta]))
	scene.call("_select_mode_option", 2)
	var selected: bool = scene.call("_select_author_strategy_ref", beta_ref)
	scene.call("_save_settings")
	var saved_file := FileAccess.open("user://battle_setup.json", FileAccess.READ)
	var saved_text := saved_file.get_as_text() if saved_file != null else ""
	saved_file = null
	var saved: Variant = JSON.parse_string(saved_text)
	var saved_ref: Dictionary = saved.get("author_strategy_ref", {}) if saved is Dictionary else {}
	var exact_keys := saved_ref.keys()
	exact_keys.sort()

	var restored_scene := BattleSetupScene.instantiate()
	restored_scene.call("_ready")
	restored_scene.call("_apply_author_strategy_catalog_report", _report([alpha, beta]))
	restored_scene.call("_load_settings")
	var restored_ref: Dictionary = restored_scene.get("_author_strategy_selected_ref")
	var missing_ref := {"package_id": "pkg.missing", "package_version": "1.2.3", "archive_sha256": HASH_A}
	var missing_selected: bool = restored_scene.call("_select_author_strategy_ref", missing_ref)
	var missing_actual: Dictionary = restored_scene.get("_author_strategy_selected_ref")

	var result := run_checks([
		assert_true(selected),
		assert_eq(saved_ref, beta_ref),
		assert_eq(exact_keys, ["archive_sha256", "package_id", "package_version"]),
		assert_false("同名策略" in saved_text, "Display names must not become persisted identity"),
		assert_eq(restored_ref, beta_ref),
		assert_false(missing_selected),
		assert_eq(missing_actual, {}, "Missing exact package identity must restore no selection"),
	])
	scene.free()
	restored_scene.free()
	_restore_settings_file(settings_snapshot)
	GameManager.reset_author_strategy_selection()
	if not previous_selection.is_empty():
		GameManager.set_author_strategy_selection(previous_selection)
	GameManager.current_mode = previous_mode as GameManager.GameMode
	return result


func test_feature_flag_rollback_hides_ui_stops_catalog_and_preserves_user_package() -> String:
	var previous_enabled: Variant = ProjectSettings.get_setting(FeatureGateScript.PROJECT_SETTING, true)
	const USER_ROOT := "user://ptcgdap/author_strategy_packages"
	const PROBE_PATH := USER_ROOT + "/rollback-preserve-test.ptcgai"
	var previous_probe_exists := FileAccess.file_exists(PROBE_PATH)
	var previous_probe_bytes := PackedByteArray()
	if previous_probe_exists:
		var previous_file := FileAccess.open(PROBE_PATH, FileAccess.READ)
		if previous_file != null:
			previous_probe_bytes = previous_file.get_buffer(previous_file.get_length())
	var user_dir := DirAccess.open("user://")
	if user_dir != null:
		user_dir.make_dir_recursive("ptcgdap/author_strategy_packages")
	var probe_file := FileAccess.open(PROBE_PATH, FileAccess.WRITE)
	if probe_file != null:
		probe_file.store_buffer("preserve-user-package".to_utf8_buffer())
	probe_file = null
	ProjectSettings.set_setting(FeatureGateScript.PROJECT_SETTING, false)
	var catalog := CatalogScript.new()
	var report: Dictionary = catalog.scan_startup()
	var request: Dictionary = catalog.request_match_handle("pkg", "1.0.0", "A".repeat(64))
	var scene := BattleSetupScene.instantiate()
	scene.call("_ready")
	scene.call("_select_mode_option", 2)
	var author_button := scene.find_child("ModeAuthorStrategyButton", true, false) as Button
	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	var checks := run_checks([
		assert_false(FeatureGateScript.is_enabled()),
		assert_false(author_button.visible if author_button != null else true),
		assert_true(author_button.disabled if author_button != null else false),
		assert_eq(mode_option.selected if mode_option != null else -1, 0),
		assert_eq(report.get("metadata_records", []).size(), 0),
		assert_eq(report.get("diagnostics", [])[0].get("error_code"), "author_strategy_feature_disabled"),
		assert_eq(request.get("error_code"), "author_strategy_feature_disabled"),
		assert_true(FileAccess.file_exists(PROBE_PATH), "rollback must not delete user-owned packages"),
	])
	scene.free()
	catalog.free()
	ProjectSettings.set_setting(FeatureGateScript.PROJECT_SETTING, previous_enabled)
	if previous_probe_exists:
		var restore_file := FileAccess.open(PROBE_PATH, FileAccess.WRITE)
		if restore_file != null:
			restore_file.store_buffer(previous_probe_bytes)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROBE_PATH))
	AuthorStrategyPackageCatalog.scan_startup()
	return checks
