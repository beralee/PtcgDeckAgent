class_name TestDeckTrainingPresentation
extends TestBase


const CatalogScript := preload("res://scripts/training/DeckTrainingCatalog.gd")
const PresentationScript := preload("res://scripts/training/DeckTrainingPresentation.gd")
const ControllerScript := preload("res://scripts/training/DeckTrainingBattleController.gd")
const NonBattleLayoutControllerScript := preload("res://scripts/ui/non_battle/NonBattleLayoutController.gd")


class TrainingSceneStub:
	extends Control

	var _btn_zeus_help := Button.new()
	var _btn_battle_discuss_ai := Button.new()
	var maybe_run_ai_calls := 0

	func _init() -> void:
		_btn_zeus_help.name = "BtnZeusHelp"
		_btn_zeus_help.text = "宙斯帮我"
		add_child(_btn_zeus_help)
		_btn_battle_discuss_ai.name = "BtnBattleDiscussAI"
		_btn_battle_discuss_ai.text = "AI探讨"
		add_child(_btn_battle_discuss_ai)

	func _maybe_run_ai() -> void:
		maybe_run_ai_calls += 1


func test_goal_summary_is_one_clear_sentence_instead_of_the_full_solution() -> String:
	var prize_scenario := {
		"turn_limit": 2,
		"goal": {"type": "prizes", "count": 4},
		"objective": "这段原始文案故意很长，而且包含完整解法，不应出现在训练列表。",
	}
	var knockout_scenario := {
		"turn_limit": 2,
		"goal": {
			"type": "target_knockouts",
			"required": 2,
			"targets": [{}, {}],
		},
	}
	return run_checks([
		assert_eq(PresentationScript.goal_summary(prize_scenario), "2回合拿4奖", "Prize goal should be short and result-oriented"),
		assert_eq(PresentationScript.goal_summary(knockout_scenario), "2回合击倒2个指定目标", "Target goal should name the exact knockout count"),
		assert_false(PresentationScript.goal_summary(prize_scenario).contains("完整解法"), "List goal must not leak the solution"),
	])


func test_all_training_scenarios_have_actionable_interpretations() -> String:
	var checks: Array[String] = []
	for scenario: Dictionary in CatalogScript.list_scenarios():
		var scenario_id := str(scenario.get("id", ""))
		var guide := PresentationScript.guide_text(scenario)
		var issues := PresentationScript.instruction_issues(scenario)
		var focus := str(scenario.get("focus", ""))
		var steps: Array = scenario.get("design_contract", {}).get("combo_contract", {}).get("ordered_steps", [])
		var baits: Array = scenario.get("design_contract", {}).get("bait_lines", [])
		checks.append(assert_true(issues.is_empty(), "%s should have a complete player guide: %s" % [scenario_id, "; ".join(PackedStringArray(issues))]))
		checks.append(assert_true(guide.contains(focus), "%s guide should retain the existing detailed explanation" % scenario_id))
		checks.append(assert_true(guide.contains("操作步骤"), "%s guide should expose numbered actions" % scenario_id))
		checks.append(assert_true(guide.contains("容易踩坑"), "%s guide should explain tempting losing lines" % scenario_id))
		for index: int in steps.size():
			checks.append(assert_true(guide.contains("%d. %s" % [index + 1, str(steps[index])]), "%s should expose operation step %d" % [scenario_id, index + 1]))
		for bait_variant: Variant in baits:
			if bait_variant is Dictionary:
				checks.append(assert_true(guide.contains(str((bait_variant as Dictionary).get("fails_because", ""))), "%s should explain why each lure fails" % scenario_id))
	return run_checks(checks)


func test_training_browser_uses_only_the_short_goal_on_scenario_cards() -> String:
	var browser_source := FileAccess.get_file_as_string("res://scenes/deck_training/DeckTrainingBrowser.gd")
	return run_checks([
		assert_true(browser_source.contains("PresentationScript.goal_summary(scenario)"), "Training list should use the shared short-goal formatter"),
		assert_false(browser_source.contains("focus.text = str(scenario.get(\"focus\""), "Training list should no longer render the detailed focus"),
		assert_true(browser_source.contains("本局目标："), "Training cards should explicitly label the one-line goal"),
	])


func test_training_browser_actually_renders_the_short_goal_without_the_solution_paragraph() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var previous_key := GameManager.get_deck_training_selected_deck_key()
	GameManager.set_deck_training_selected_deck_key("raging_bolt")
	var scene := (load("res://scenes/deck_training/DeckTrainingBrowser.tscn") as PackedScene).instantiate()
	tree.root.add_child(scene)
	await tree.process_frame
	await tree.process_frame
	var labels: Array[String] = []
	for node: Node in scene.find_children("*", "Label", true, false):
		var label := node as Label
		if label != null:
			labels.append(label.text)
	var scenario := CatalogScript.get_scenario("raging_bolt_01")
	var short_row := "本局目标：%s" % PresentationScript.goal_summary(scenario)
	var focus := str(scenario.get("focus", ""))
	var checks := run_checks([
		assert_true(labels.has(short_row), "The rendered list should contain the short target"),
		assert_false(labels.has(focus), "The rendered list should not expose the solution paragraph"),
	])
	scene.queue_free()
	await tree.process_frame
	GameManager.set_deck_training_selected_deck_key(previous_key)
	return checks


func test_training_browser_places_replay_mode_at_the_header_right_and_navigates() -> String:
	var previous_suppression := GameManager.suppress_scene_navigation_for_tests
	var previous_requested_path := GameManager.last_requested_scene_path
	GameManager.suppress_scene_navigation_for_tests = true
	GameManager.last_requested_scene_path = ""
	var scene := (load("res://scenes/deck_training/DeckTrainingBrowser.tscn") as PackedScene).instantiate()
	var header := scene.get_node("RootMargin/VBox/Header") as HBoxContainer
	var replay_button := scene.find_child("ReplayButton", true, false) as Button
	scene.call("_on_replay_pressed")
	var checks := run_checks([
		assert_not_null(replay_button, "Training header should expose the original replay mode"),
		assert_eq(replay_button.text if replay_button != null else "", "复盘模式", "Replay entry should use clear player-facing copy"),
		assert_eq(header.get_child(header.get_child_count() - 1), replay_button, "Replay entry should sit at the far right of the training header"),
		assert_eq(GameManager.last_requested_scene_path, GameManager.SCENE_REPLAY_BROWSER, "Replay entry should reuse the existing replay browser route"),
	])
	scene.free()
	GameManager.suppress_scene_navigation_for_tests = previous_suppression
	GameManager.last_requested_scene_path = previous_requested_path
	return checks


func test_training_browser_portrait_matches_deck_center_metrics() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var scene := (load("res://scenes/deck_training/DeckTrainingBrowser.tscn") as PackedScene).instantiate()
	tree.root.add_child(scene)
	await tree.process_frame
	await tree.process_frame
	var viewport_size := Vector2(430, 932)
	scene.call("_apply_layout_for_tests", viewport_size, "portrait")
	var context := NonBattleLayoutControllerScript.new().build_context(viewport_size, "portrait", true)

	var root_margin := scene.find_child("RootMargin", true, false) as MarginContainer
	var root_vbox := scene.get_node("RootMargin/VBox") as VBoxContainer
	var title := scene.find_child("Title", true, false) as Label
	var prompt := scene.find_child("DeckPrompt", true, false) as Label
	var status := scene.find_child("StatusLabel", true, false) as Label
	var back := scene.find_child("BackButton", true, false) as Button
	var replay := scene.find_child("ReplayButton", true, false) as Button
	var selector := scene.find_child("DeckSelector", true, false) as HFlowContainer
	var deck_button := selector.get_child(0) as CheckBox if selector != null and selector.get_child_count() > 0 else null
	var scenario_list := scene.find_child("ScenarioList", true, false) as VBoxContainer
	var card := scenario_list.get_child(0) as PanelContainer if scenario_list != null and scenario_list.get_child_count() > 0 else null
	var scenario_title := card.find_child("DeckTrainingScenarioTitle", true, false) as Label if card != null else null
	var scenario_detail := card.find_child("DeckTrainingScenarioDetail", true, false) as Label if card != null else null
	var start_button := card.get_meta("start_button", null) as Button if card != null else null
	var scroll := scene.find_child("Scroll", true, false) as ScrollContainer

	var checks := run_checks([
		assert_eq(root_margin.get_theme_constant("margin_left"), int(context.get("page_margin", 0)), "Training portrait should use the deck-center page margin"),
		assert_eq(root_vbox.get_theme_constant("separation"), int(context.get("section_gap", 0)), "Training portrait sections should use the deck-center gap"),
		assert_eq(title.get_theme_font_size("font_size"), int(context.get("title_font_size", 0)), "Training title should match the deck-center portrait title"),
		assert_eq(prompt.get_theme_font_size("font_size"), int(context.get("section_font_size", 0)), "Training deck prompt should match deck-center section text"),
		assert_eq(status.get_theme_font_size("font_size"), int(context.get("body_font_size", 0)), "Training status should match deck-center body text"),
		assert_true(back.custom_minimum_size.y >= float(context.get("secondary_button_height", 0.0)), "Training Back should meet the deck-center portrait touch height"),
		assert_true(replay.custom_minimum_size.y >= float(context.get("secondary_button_height", 0.0)), "Training Replay should meet the deck-center portrait touch height"),
		assert_true(deck_button != null and deck_button.custom_minimum_size.y >= float(context.get("secondary_button_height", 0.0)), "Training deck choices should use deck-center portrait touch height"),
		assert_eq(deck_button.get_theme_font_size("font_size") if deck_button != null else 0, int(context.get("button_font_size", 0)), "Training deck choices should match deck-center button text"),
		assert_eq(scenario_title.get_theme_font_size("font_size") if scenario_title != null else 0, int(context.get("section_font_size", 0)), "Scenario titles should match deck-center section text"),
		assert_eq(scenario_detail.get_theme_font_size("font_size") if scenario_detail != null else 0, int(context.get("body_font_size", 0)), "Scenario goals should match deck-center body text"),
		assert_true(start_button != null and start_button.custom_minimum_size.y >= float(context.get("primary_button_height", 0.0)), "Start Training should use the deck-center primary button height"),
		assert_eq(start_button.get_theme_font_size("font_size") if start_button != null else 0, int(context.get("button_font_size", 0)), "Start Training should match deck-center button text"),
		assert_eq(scenario_list.get_theme_constant("separation"), int(context.get("section_gap", 0)), "Scenario cards should use the deck-center portrait spacing"),
		assert_true(scroll != null and bool(scroll.get_meta("_non_battle_hidden_vertical_drag_scroll", false)), "Training portrait should use the same hidden drag scrollbar behavior"),
	])
	scene.queue_free()
	await tree.process_frame
	return checks


func test_training_browser_returns_to_compact_landscape_metrics_after_rotation() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var scene := (load("res://scenes/deck_training/DeckTrainingBrowser.tscn") as PackedScene).instantiate()
	tree.root.add_child(scene)
	await tree.process_frame
	await tree.process_frame
	scene.call("_apply_layout_for_tests", Vector2(430, 932), "portrait")
	scene.call("_apply_layout_for_tests", Vector2(1600, 900), "landscape")

	var root_vbox := scene.get_node("RootMargin/VBox") as VBoxContainer
	var title := scene.find_child("Title", true, false) as Label
	var back := scene.find_child("BackButton", true, false) as Button
	var replay := scene.find_child("ReplayButton", true, false) as Button
	var selector := scene.find_child("DeckSelector", true, false) as HFlowContainer
	var deck_button := selector.get_child(0) as CheckBox if selector != null and selector.get_child_count() > 0 else null
	var scenario_list := scene.find_child("ScenarioList", true, false) as VBoxContainer
	var card := scenario_list.get_child(0) as PanelContainer if scenario_list != null and scenario_list.get_child_count() > 0 else null
	var start_button := card.get_meta("start_button", null) as Button if card != null else null
	var scroll := scene.find_child("Scroll", true, false) as ScrollContainer
	var checks := run_checks([
		assert_eq(root_vbox.get_theme_constant("separation"), 12, "Landscape should restore the original compact section gap"),
		assert_eq(title.get_theme_font_size("font_size"), 30, "Landscape should restore the original title size"),
		assert_eq(back.custom_minimum_size, Vector2(92, 48), "Landscape should restore the compact Back button"),
		assert_eq(replay.custom_minimum_size, Vector2(116, 48), "Landscape should restore the compact Replay button"),
		assert_eq(deck_button.custom_minimum_size if deck_button != null else Vector2.ZERO, Vector2(172, 50), "Landscape should restore compact deck choices"),
		assert_eq(start_button.custom_minimum_size.y if start_button != null else 0.0, 58.0, "Landscape should restore the compact Start Training button"),
		assert_false(scroll != null and bool(scroll.get_meta("_non_battle_hidden_vertical_drag_scroll", false)), "Landscape should restore a visible vertical scrollbar"),
	])
	scene.queue_free()
	await tree.process_frame
	return checks


func test_training_controller_rebrands_zeus_and_reuses_one_goal_and_guide_overlay() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var scene := TrainingSceneStub.new()
	tree.root.add_child(scene)
	await tree.process_frame
	var scenario := CatalogScript.get_scenario("raging_bolt_02")
	var controller := ControllerScript.new()
	controller.setup(scene, null, scenario, {})
	var zeus_button := scene.get("_btn_zeus_help") as Button
	var intro_goal := scene.find_child("StageGoalLabel", true, false) as Label
	var intro_guide_button := scene.find_child("StageGuideButton", true, false) as Button
	var checks: Array[String] = [
		assert_eq(zeus_button.text, "关卡说明", "Training should replace the landscape Zeus label"),
		assert_eq(str(zeus_button.get_meta("portrait_compact_text_override", "")), "关卡", "Training should provide the portrait compact label"),
		assert_eq(intro_goal.text if intro_goal != null else "", PresentationScript.goal_summary(scenario), "Intro should default to the same short goal"),
		assert_not_null(intro_guide_button, "Intro should provide an interpretation button"),
	]
	controller.show_stage_goal()
	var help_goal := scene.find_child("StageHelpGoalLabel", true, false) as Label
	var help_guide_button := scene.find_child("StageHelpGuideButton", true, false) as Button
	checks.append(assert_eq(help_goal.text if help_goal != null else "", PresentationScript.goal_summary(scenario), "Top action should first show the goal"))
	checks.append(assert_not_null(help_guide_button, "Goal overlay should let the player request the interpretation"))
	controller.show_stage_guide()
	var guide_text := scene.find_child("StageGuideText", true, false) as RichTextLabel
	checks.append(assert_true(guide_text != null and guide_text.text.contains("容器先弃斗能"), "Interpretation overlay should expose the actionable route"))
	controller.call("_close_help_overlay")
	await tree.process_frame
	checks.append(assert_eq(scene.maybe_run_ai_calls, 1, "Closing stage help should resume a paused AI turn"))
	controller.call("_build_result_overlay", "C")
	var result_guide_button := scene.find_child("ResultGuideButton", true, false) as Button
	checks.append(assert_not_null(result_guide_button, "A C result should offer the same interpretation"))
	controller.release()
	checks.append(assert_eq(zeus_button.text, "宙斯帮我", "Leaving training should restore the normal battle label"))
	scene.queue_free()
	await tree.process_frame
	return run_checks(checks)


func test_training_battle_overlays_match_deck_center_portrait_metrics() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var scene := TrainingSceneStub.new()
	tree.root.add_child(scene)
	await tree.process_frame
	var scenario := CatalogScript.get_scenario("raging_bolt_02")
	var controller := ControllerScript.new()
	controller.setup(scene, null, scenario, {})
	controller.apply_layout(Vector2(430, 932))
	var context: Dictionary = NonBattleLayoutControllerScript.new().build_context(Vector2(430, 932), "portrait", true)
	var intro_panel := scene.find_child("DeckTrainingIntroPanel", true, false) as PanelContainer
	var intro_title := scene.find_child("StageIntroTitle", true, false) as Label
	var intro_goal := scene.find_child("StageGoalLabel", true, false) as Label
	var intro_limit := scene.find_child("StageIntroLimit", true, false) as Label
	var intro_guide := scene.find_child("StageGuideButton", true, false) as Button
	var intro_confirm := scene.find_child("StageIntroConfirmButton", true, false) as Button
	var checks: Array[String] = [
		assert_true(intro_panel != null and intro_panel.custom_minimum_size.x >= float(context.get("content_width", 0.0)), "Portrait intro should use the deck-center content width"),
		assert_eq(intro_title.get_theme_font_size("font_size") if intro_title != null else 0, int(context.get("title_font_size", 0)), "Portrait intro title should match the deck-center title size"),
		assert_eq(intro_goal.get_theme_font_size("font_size") if intro_goal != null else 0, int(context.get("section_font_size", 0)), "Portrait intro goal should match the deck-center section size"),
		assert_eq(intro_limit.get_theme_font_size("font_size") if intro_limit != null else 0, int(context.get("body_font_size", 0)), "Portrait intro limit should match the deck-center body size"),
		assert_eq(intro_guide.get_theme_font_size("font_size") if intro_guide != null else 0, int(context.get("button_font_size", 0)), "Portrait intro actions should match the deck-center button size"),
		assert_true(intro_guide != null and intro_guide.custom_minimum_size.y >= float(context.get("secondary_button_height", 0.0)), "Portrait guide action should be touch-sized"),
		assert_true(intro_confirm != null and intro_confirm.custom_minimum_size.y >= float(context.get("primary_button_height", 0.0)), "Portrait start action should use the primary touch height"),
	]
	controller.show_stage_goal()
	controller.apply_layout(Vector2(430, 932))
	var help_title := scene.find_child("StageHelpTitle", true, false) as Label
	var help_goal := scene.find_child("StageHelpGoalLabel", true, false) as Label
	var help_guide := scene.find_child("StageHelpGuideButton", true, false) as Button
	checks.append(assert_eq(help_title.get_theme_font_size("font_size") if help_title != null else 0, int(context.get("title_font_size", 0)), "Portrait stage-help title should match the shared title size"))
	checks.append(assert_eq(help_goal.get_theme_font_size("font_size") if help_goal != null else 0, int(context.get("section_font_size", 0)), "Portrait stage goal should match the shared section size"))
	checks.append(assert_true(help_guide != null and help_guide.custom_minimum_size.y >= float(context.get("secondary_button_height", 0.0)), "Portrait stage-help actions should be touch-sized"))
	controller.show_stage_guide()
	controller.apply_layout(Vector2(430, 932))
	var guide_panel := controller.get("_help_panel") as PanelContainer
	var guide_text := controller.get("_help_guide_text") as RichTextLabel
	checks.append(assert_true(guide_panel != null and guide_panel.custom_minimum_size.y >= 780.0, "Portrait interpretation should use most of the phone height"))
	checks.append(assert_eq(guide_text.get_theme_font_size("normal_font_size") if guide_text != null else 0, int(context.get("body_font_size", 0)), "Portrait interpretation body should match the shared body size"))
	controller.release()
	scene.queue_free()
	await tree.process_frame
	return run_checks(checks)


func test_training_battle_overlays_restore_compact_landscape_metrics() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var scene := TrainingSceneStub.new()
	tree.root.add_child(scene)
	await tree.process_frame
	var controller := ControllerScript.new()
	controller.setup(scene, null, CatalogScript.get_scenario("raging_bolt_02"), {})
	controller.apply_layout(Vector2(430, 932))
	controller.apply_layout(Vector2(1600, 900))
	var intro_panel := scene.find_child("DeckTrainingIntroPanel", true, false) as PanelContainer
	var intro_title := scene.find_child("StageIntroTitle", true, false) as Label
	var intro_goal := scene.find_child("StageGoalLabel", true, false) as Label
	var intro_limit := scene.find_child("StageIntroLimit", true, false) as Label
	var intro_guide := scene.find_child("StageGuideButton", true, false) as Button
	var intro_confirm := scene.find_child("StageIntroConfirmButton", true, false) as Button
	var checks: Array[String] = [
		assert_eq(intro_panel.custom_minimum_size.x if intro_panel != null else 0.0, 620.0, "Landscape intro should restore its compact width"),
		assert_eq(intro_title.get_theme_font_size("font_size") if intro_title != null else 0, 30, "Landscape intro should restore its title size"),
		assert_eq(intro_goal.get_theme_font_size("font_size") if intro_goal != null else 0, 26, "Landscape intro should restore its goal size"),
		assert_eq(intro_limit.get_theme_font_size("font_size") if intro_limit != null else 0, 18, "Landscape intro should restore its detail size"),
		assert_eq(intro_guide.custom_minimum_size.y if intro_guide != null else 0.0, 52.0, "Landscape secondary action should restore its compact height"),
		assert_eq(intro_confirm.custom_minimum_size.y if intro_confirm != null else 0.0, 58.0, "Landscape primary action should restore its compact height"),
	]
	controller.release()
	scene.queue_free()
	await tree.process_frame
	return run_checks(checks)


func test_battle_runtime_routes_training_stage_help_before_zeus_cheat() -> String:
	var runtime_source := FileAccess.get_file_as_string("res://scenes/battle/BattleSceneRuntime.gd")
	var compact_source := FileAccess.get_file_as_string("res://scenes/battle/BattleSceneRuntime.gd")
	return run_checks([
		assert_true(runtime_source.contains("_deck_training_controller.show_stage_goal()"), "Training should route the former Zeus action to stage help"),
		assert_true(compact_source.contains("portrait_compact_text_override"), "Portrait labels should honor the training-specific compact text"),
	])


func test_training_stage_help_uses_the_compact_portrait_label_without_changing_normal_battle_copy() -> String:
	var scene := (load("res://scenes/battle/BattleScene.tscn") as PackedScene).instantiate()
	var button := scene.find_child("BtnZeusHelp", true, false) as Button
	var original_text := button.text
	button.text = "关卡说明"
	button.set_meta("portrait_compact_text_override", "关卡")
	scene.call("_apply_portrait_top_action_compact_label", button)
	var compact_text := button.text
	scene.call("_restore_portrait_top_action_label", button)
	var restored_training_text := button.text
	button.remove_meta("portrait_compact_text_override")
	button.text = original_text
	scene.call("_apply_portrait_top_action_compact_label", button)
	var normal_compact_text := button.text
	scene.free()
	return run_checks([
		assert_eq(compact_text, "关卡", "Training portrait should use the requested compact label"),
		assert_eq(restored_training_text, "关卡说明", "Returning to landscape should restore the training label"),
		assert_eq(normal_compact_text, "宙斯", "Normal battles should keep their existing compact label"),
	])
