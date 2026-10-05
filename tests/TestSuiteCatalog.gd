class_name TestSuiteCatalog
extends RefCounted

const TestSuiteFilterScript = preload("res://scripts/tools/TestSuiteFilter.gd")

const TEST_DIR := "res://tests"
const GROUP_FUNCTIONAL := "functional"
const GROUP_UI := "ui"
const GROUP_AI := "ai"
# Compatibility with existing callers and --group=ai_training.
const GROUP_AI_TRAINING := GROUP_AI
const GROUPS := [GROUP_UI, GROUP_FUNCTIONAL, GROUP_AI]

# Names without an explicit UI token whose primary owner is a scene/input
# controller. Keep domain-only battle rules in functional.
const UI_OWNER_FILES := [
	"test_battle_action_controller.gd", "test_battle_action_controller_invalid_hints.gd",
	"test_battle_action_intent_layer.gd", "test_battle_effect_interaction_controller.gd",
	"test_battle_effects_setting.gd", "test_battle_i18n.gd",
	"test_battle_interaction_coordinator.gd", "test_battle_invalid_action_hint_controller.gd",
	"test_battle_mulligan_notice.gd", "test_battle_prompt_router.gd",
	"test_battle_ai_advice_copy.gd", "test_battle_runtime_log_controller.gd",
	"test_card_proxy_renderer.gd", "test_deck_editor.gd", "test_deck_manager.gd",
	"test_deck_center_redesign.gd",
	"test_deck_center_android_interaction.gd",
	"test_deck_delete_feedback_regressions.gd", "test_deck_training_home_notice.gd",
]

const AI_TRAINING_FILES := {
	"test_agent_version_store.gd": true,
	"test_ai_action_feature_encoder.gd": true,
	"test_ai_action_scorer_artifacts.gd": true,
	"test_ai_action_scorer_runtime.gd": true,
	"test_ai_baseline.gd": true,
	"test_ai_benchmark.gd": true,
	"test_ai_benchmark_action_scorer_paths.gd": true,
	"test_ai_decision_sample_exporter.gd": true,
	"test_ai_decision_trace.gd": true,
	"test_ai_feature_extractor.gd": true,
	"test_ai_headless_action_builder.gd": true,
	"test_ai_interaction_planner.gd": true,
	"test_ai_phase2_benchmark.gd": true,
	"test_ai_phase3_regression.gd": true,
	"test_ai_training_test_runner.gd": true,
	"test_action_cap_probe.gd": true,
	"test_ai_strategy_wiring.gd": true,
	"test_ai_strong_fixed_openings.gd": true,
	"test_deck_strategy_contract.gd": true,
	"test_deck_strategy_registry_expansion.gd": true,
	"test_palkia_gholdengo_author_candidate.gd": true,
	"test_ai_tool_actions.gd": true,
	"test_ai_version_registry.gd": true,
	"test_benchmark_evaluator.gd": true,
	"test_deck_identity_tracker.gd": true,
	"test_opponent_deck_fingerprint_resolver.gd": true,
	"test_matchup_policy_integration.gd": true,
	"test_evolution_engine.gd": true,
	"test_gardevoir_value_net.gd": true,
	"test_gardevoir_miraidon_trace_regressions.gd": true,
	"test_gardevoir_shell_lock.gd": true,
	"test_gardevoir_strategy_churn.gd": true,
	"test_gardevoir_tm_setup_priority.gd": true,
	"test_gardevoir_fast_evolution_t1.gd": true,
	"test_miraidon_fast_setup_t1.gd": true,
	"test_arceus_fast_setup_t1.gd": true,
	"test_raging_bolt_strong_opening.gd": true,
	"test_charizard_strategy.gd": true,
	"test_charizard_ultra_ball_search_pick.gd": true,
	"test_dragapult_strategy.gd": true,
	"test_dragapult_python_public_strategy_e2e.gd": true,
	"test_author_strategy_export_match_acceptance.gd": true,
	"test_author_strategy_package_rules_e2e.gd": true,
	"test_author_strategy_windows_player_owner.gd": true,
	"test_local_policy_executor.gd": true,
	"test_marnie_public_replay_acceptance.gd": true,
	"test_reviewed_author_vs_classic_benchmark.gd": true,
	"test_miraidon_strategy.gd": true,
	"test_water_lost_strategies.gd": true,
	"test_future_ancient_strategies.gd": true,
	"test_llm_interaction_bridge.gd": true,
	"test_llm_interaction_bridge_part2.gd": true,
	"test_llm_interaction_bridge_part3.gd": true,
	"test_llm_raging_bolt_duel_tool.gd": true,
	"test_blissey_tank_strategy.gd": true,
	"test_vstar_engine_strategies.gd": true,
	"test_game_state_cloner.gd": true,
	"test_headless_match_bridge.gd": true,
	"test_headless_heavy_baton_prompt.gd": true,
	"test_mcts_action_resolution.gd": true,
	"test_mcts_action_scorer_runtime.gd": true,
	"test_mcts_failure_diagnostics.gd": true,
	"test_mcts_planner.gd": true,
	"test_neural_net_inference.gd": true,
	"test_rollout_simulator.gd": true,
	"test_self_play_data_exporter.gd": true,
	"test_self_play_runner.gd": true,
	"test_state_encoder.gd": true,
	"test_training_anomaly_archive.gd": true,
	"test_training_pipeline_modes.gd": true,
	"test_training_run_registry.gd": true,
	"test_tuner_runner_args.gd": true,
}

const TOKEN_OVERRIDES := {
	"ai": "AI",
	"ui": "UI",
	"mcts": "MCTS",
	"zenmux": "ZenMux",
}


static func all_suites() -> Array[Dictionary]:
	var suites: Array[Dictionary] = []
	for file_name: String in _discover_test_files():
		suites.append(_build_suite_entry(file_name))
	return suites


static func get_suites(selected_groups: Dictionary = {}) -> Array[Dictionary]:
	if selected_groups.is_empty():
		return all_suites()
	for group: String in selected_groups:
		if TestSuiteFilterScript.normalize_group_name(group) not in GROUPS:
			return []

	var filtered: Array[Dictionary] = []
	for suite: Dictionary in all_suites():
		if TestSuiteFilterScript.should_run_any_group(selected_groups, suite.get("groups", [])):
			filtered.append(suite)
	return filtered


static func get_suites_for_group(group_name: String) -> Array[Dictionary]:
	var selected := {TestSuiteFilterScript.normalize_group_name(group_name): true}
	return get_suites(selected)


static func get_suite_names_for_group(group_name: String) -> Array[String]:
	var names: Array[String] = []
	for suite: Dictionary in get_suites_for_group(group_name):
		names.append(str(suite.get("name", "")))
	return names


static func has_suite_path(script_path: String) -> bool:
	for suite: Dictionary in all_suites():
		if str(suite.get("path", "")) == script_path:
			return true
	return false


static func _discover_test_files() -> Array[String]:
	var files: Array[String] = []
	_collect_test_files(TEST_DIR, "", files)
	files.sort()
	return files


static func _build_suite_entry(relative_path: String) -> Dictionary:
	var groups := _groups_for_file(relative_path)
	return {
		"name": _suite_name_for_file(relative_path),
		"path": "%s/%s" % [TEST_DIR, relative_path],
		"groups": groups,
		"category": groups[0],
		"ai_versions": _ai_versions_for_file(relative_path),
		"profiles": _profiles_for_file(relative_path),
	}


static func _groups_for_file(relative_path: String) -> Array[String]:
	var file_name := relative_path.get_file()
	# "layout" here means release files/URLs, not screen geometry.
	if file_name == "test_web_release_layout.gd":
		return [GROUP_FUNCTIONAL]
	if file_name.begins_with("test_arena") or file_name in UI_OWNER_FILES:
		return [GROUP_UI]
	# Presentation and interaction own UI, even when presenting AI.
	if relative_path.begins_with("ui/") or file_name.begins_with("test_strategy_hub_") or file_name == "test_author_strategy_battle_setup.gd":
		return [GROUP_UI]
	# An owning AI directory outranks ambiguous tokens such as model "input".
	if relative_path.begins_with("ai/") or relative_path.begins_with("ptcgdap/godot/") or relative_path.begins_with("llm_decks/") or relative_path.begins_with("v18_llm_policy_graph/"):
		return [GROUP_AI]
	if _matches(file_name, "(?:^|_)(?:ui|layout|dialog|panel|popup|modal|portrait|vfx|animation|animator|visual|pointer|scroll|menu|input|touch|hud|display|overlay|presenter|presentation)(?:_|\\.)") or file_name.begins_with("test_battle_setup_") or file_name.begins_with("test_battle_scene_"):
		return [GROUP_UI]
	if file_name in ["test_local_optimized_strategy_visibility.gd", "test_battle_hand_surface_reconciliation.gd"]:
		return [GROUP_UI]
	if bool(AI_TRAINING_FILES.get(file_name, false)):
		return [GROUP_AI_TRAINING]
	if _matches(file_name, "^test_(?:ai_|llm_|mcts_|v17|v18|author_|tournament_author_|local_author_)|(?:_strategy|_strategies)(?:_|\\.)"):
		return [GROUP_AI]
	return [GROUP_FUNCTIONAL]


static func _matches(value: String, pattern: String) -> bool:
	var regex := RegEx.new()
	return regex.compile(pattern) == OK and regex.search(value) != null


static func _ai_versions_for_file(path: String) -> Array[String]:
	# Tags describe evidence, not an emulated runtime.
	if path.get_file() == "test_battle_setup_ai_versions.gd":
		return ["legacy", "v17", "v17.5", "v18", "v18.5", "author"]
	if path.get_file() == "test_deck_strategy_registry_expansion.gd":
		return ["legacy", "v17", "v17.5", "v18"]
	if path.get_file() in ["test_bundled_deck_catalog.gd", "test_card_database_seed.gd"]:
		return ["v18.5"]
	if path.contains("v175"):
		return ["v17.5"]
	if path.contains("v17"):
		return ["v17"]
	if path.contains("v18"):
		return ["v18"]
	if path.begins_with("ai/") or path.begins_with("ptcgdap/") or path.contains("author"):
		return ["author"]
	if _groups_for_file(path) == [GROUP_AI]:
		return ["legacy"]
	return []


static func _profiles_for_file(path: String) -> Array[String]:
	if path in ["ui/test_strategy_hub_input_compatibility.gd", "test_non_battle_portrait_layout.gd", "test_non_battle_web_input_v2.gd", "test_web_input_adapter.gd", "test_web_ui_e2e_bridge.gd", "ptcgdap/godot/test_strategy_hub_responsive.gd"]:
		return ["desktop-layout", "touch-layout", "web-contract"]
	if path.begins_with("ai/ptcgdap/"):
		return ["native-model"]
	return ["host"]


static func _suite_name_for_file(relative_path: String) -> String:
	var stem := relative_path.get_file().trim_prefix("test_").trim_suffix(".gd")
	var parts: Array[String] = []
	for token: String in stem.split("_", false):
		var lower := token.to_lower()
		if TOKEN_OVERRIDES.has(lower):
			parts.append(TOKEN_OVERRIDES[lower])
		elif token.is_valid_int():
			parts.append(token)
		elif token.length() > 0:
			parts.append(token.substr(0, 1).to_upper() + token.substr(1))
	return "".join(parts)


static func _collect_test_files(root_dir: String, relative_dir: String, files: Array[String]) -> void:
	var dir_path := root_dir if relative_dir == "" else "%s/%s" % [root_dir, relative_dir]
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry in [".", ".."]:
			entry = dir.get_next()
			continue
		var child_relative := entry if relative_dir == "" else "%s/%s" % [relative_dir, entry]
		if dir.current_is_dir():
			_collect_test_files(root_dir, child_relative, files)
		elif entry.begins_with("test_") and entry.ends_with(".gd"):
			var script_path := "%s/%s" % [root_dir, child_relative]
			if _script_declares_suite_test_method(script_path):
				files.append(child_relative)
		entry = dir.get_next()
	dir.list_dir_end()


static func _script_declares_suite_test_method(script_path: String) -> bool:
	var file := FileAccess.open(script_path, FileAccess.READ)
	if file == null:
		return false
	var source := file.get_as_text()
	var method_pattern := RegEx.new()
	if method_pattern.compile("(?m)^[\\t ]*(?:static[\\t ]+)?func[\\t ]+test_[A-Za-z0-9_]*[\\t ]*\\(") != OK:
		return false
	return method_pattern.search(source) != null
