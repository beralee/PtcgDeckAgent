class_name TestAuthorStrategyExportMatchAcceptance
extends TestBase

const AcceptanceScript = preload("res://scripts/ai/ptcgdap/acceptance/AuthorStrategyWindowsExportMatchAcceptance.gd")
const RUNNER_PATH := "res://scripts/tools/run_ptcgdap_windows_export_match.gd"
const UI_ACCEPTANCE_PATH := "res://scripts/ai/ptcgdap/acceptance/AuthorStrategyWindowsUiMatchAcceptance.gd"
const UI_ENTRYPOINT_PATH := "res://scripts/tools/run_ptcgdap_windows_ui_match.gd"
const UI_WRAPPER_PATH := "res://scripts/tools/run_ptcgdap_windows_ui_match.ps1"


func test_export_match_acceptance_runs_exact_package_against_rules_ai_to_terminal() -> String:
	var report: Dictionary = AcceptanceScript.new().run(CardDatabase, {
		"games": 1,
		"seed_base": 84590,
		"max_steps": 700,
	})
	var totals: Dictionary = report.get("totals", {})
	return run_checks([
		assert_true(bool(report.get("is_clean", false))),
		assert_true(bool(report.get("complete_match_finished", false))),
		assert_eq(report.get("document_type"), "author_strategy_windows_export_match_report_v1"),
		assert_eq(report.get("card_id_domain"), "godot_local_card_uid_v1"),
		assert_true(bool(report.get("development_only", false))),
		assert_false(bool(report.get("production_ready", true))),
		assert_false(bool(report.get("a5_claimed", true))),
		assert_false(bool(report.get("ui_driven", true))),
		assert_false(bool(report.get("network_blocked", true))),
		assert_true(int(totals.get("policy_calls", 0)) > 0),
		assert_eq(totals.get("policy_calls"), totals.get("policy_successes")),
		assert_eq(totals.get("classic_fallbacks"), 0),
		assert_eq(totals.get("external_process_attempts"), 0),
		assert_true(int(totals.get("engine_commits", 0)) > 0),
		assert_true(int(report.get("decision_timing", {}).get("sample_count", 0)) > 0),
	])


func test_export_match_runner_is_explicitly_included_only_in_windows_preset() -> String:
	var runner: GDScript = load(RUNNER_PATH)
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	var project := FileAccess.get_file_as_string("res://project.godot")
	var wrapper := FileAccess.get_file_as_string("res://scripts/tools/run_ptcgdap_exported_windows_match.ps1")
	var runner_source := FileAccess.get_file_as_string(RUNNER_PATH)
	var main_menu_source := FileAccess.get_file_as_string("res://scenes/main_menu/MainMenu.gd")
	var first_preset_end := presets.find("[preset.1]")
	var windows_preset := presets.substr(0, first_preset_end) if first_preset_end >= 0 else presets
	return run_checks([
		assert_true(runner != null and runner.can_instantiate()),
		assert_true("scripts/tools/run_ptcgdap_windows_export_match.gd" in windows_preset),
		assert_true("PtcgDAPWindowsExportMatchEntrypoint=\"*res://scripts/tools/run_ptcgdap_windows_export_match.gd\"" in project),
		assert_false("const AcceptanceScript = preload" in runner_source, "Ordinary startup must not eagerly load the export acceptance dependency graph"),
		assert_true("load(ACCEPTANCE_SCRIPT_PATH)" in runner_source, "The export acceptance graph should load only after its activation argument is present"),
		assert_true("--headless -- --ptcgdap-development-export-match" in wrapper),
		assert_false("--script res://scripts/tools/run_ptcgdap_windows_export_match.gd" in wrapper),
		assert_true("OS.has_feature(\"template\")" in runner_source),
		assert_true("--ptcgdap-development-export-match" in main_menu_source),
		assert_true("network_isolation_proven = $false" in wrapper),
	])


func test_windows_ui_acceptance_has_fail_closed_dual_owner_contract() -> String:
	var ui_acceptance_script := load(UI_ACCEPTANCE_PATH) as GDScript
	var ui_entrypoint_script := load(UI_ENTRYPOINT_PATH) as GDScript
	var project := FileAccess.get_file_as_string("res://project.godot")
	var headless_runner := FileAccess.get_file_as_string(RUNNER_PATH)
	var battle_foundation := FileAccess.get_file_as_string("res://scenes/battle/runtime/BattleSceneRuntimeFoundation.gd")
	var battle_scheduler := FileAccess.get_file_as_string("res://scenes/battle/runtime/BattleSceneSharedHudAiRuntime.gd")
	var battle_start := FileAccess.get_file_as_string("res://scenes/battle/runtime/BattleSceneSetupEffectAiRuntime.gd")
	var ui_acceptance := FileAccess.get_file_as_string(UI_ACCEPTANCE_PATH)
	var ui_entrypoint := FileAccess.get_file_as_string(UI_ENTRYPOINT_PATH)
	var ui_wrapper := FileAccess.get_file_as_string(UI_WRAPPER_PATH)
	var main_menu_source := FileAccess.get_file_as_string("res://scenes/main_menu/MainMenu.gd")
	return run_checks([
		assert_true(ui_acceptance_script != null and ui_acceptance_script.can_instantiate()),
		assert_true(ui_entrypoint_script != null and ui_entrypoint_script.can_instantiate()),
		assert_true("OS.get_name() != \"Windows\"" in headless_runner, "development export entry must reject non-Windows runtimes"),
		assert_true("PtcgDAPWindowsUiMatchEntrypoint=\"*res://scripts/tools/run_ptcgdap_windows_ui_match.gd\"" in project),
		assert_false("const AcceptanceScript = preload" in ui_entrypoint, "Ordinary startup must not eagerly load the UI acceptance dependency graph"),
		assert_true("load(ACCEPTANCE_SCRIPT_PATH)" in ui_entrypoint, "The UI acceptance graph should load only after its activation argument is present"),
		assert_true("--ptcgdap-development-ui-match" in ui_entrypoint),
		assert_true("OS.get_name() != \"Windows\"" in ui_entrypoint),
		assert_true("OS.has_feature(\"template\")" in ui_entrypoint),
		assert_true("author_strategy_windows_ui_match_report_v1" in ui_acceptance),
		assert_true("catalog_scan_elapsed_usec" in ui_entrypoint),
		assert_true("decision_elapsed_usec" in ui_wrapper),
		assert_true("peak_working_set_mib" in ui_wrapper),
		assert_true("_development_player_rules_owner" in battle_foundation),
		assert_true("_development_ui_prompt_player_index" in battle_scheduler),
		assert_true("build_windows_development_rules_owner" in battle_start),
		assert_true("complete_match" in battle_start),
		assert_true("Invoke-RealMouseClick" in ui_wrapper),
		assert_true("network_isolation_proven = $false" in ui_wrapper),
		assert_true("PTCGDAP_WINDOWS_UI_NETWORK=application_disabled" in main_menu_source),
		assert_true("application_network_disabled" in ui_wrapper),
		assert_false("netsh advfirewall" in ui_wrapper.to_lower(), "the test must not mutate the user's firewall"),
	])
