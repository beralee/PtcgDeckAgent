class_name TestScriptLoadRegressions
extends TestBase


func test_rare_candy_and_card_semantic_matrix_scripts_load() -> String:
	var rare_candy_script := load("res://scripts/effects/trainer_effects/EffectRareCandy.gd")
	var semantic_matrix_script := load("res://tests/test_card_semantic_matrix.gd")
	var rare_candy_instance = rare_candy_script.new() if rare_candy_script != null and rare_candy_script.can_instantiate() else null
	var semantic_matrix_instance = semantic_matrix_script.new() if semantic_matrix_script != null and semantic_matrix_script.can_instantiate() else null

	return run_checks([
		assert_not_null(rare_candy_script, "EffectRareCandy.gd should load without compile errors"),
		assert_not_null(semantic_matrix_script, "test_card_semantic_matrix.gd should load without compile errors"),
		assert_not_null(rare_candy_instance, "EffectRareCandy.gd should instantiate without compile errors"),
		assert_not_null(semantic_matrix_instance, "test_card_semantic_matrix.gd should instantiate without compile errors"),
	])


func test_benchmark_runner_and_game_state_machine_scripts_load() -> String:
	var benchmark_runner_script := load("res://scripts/training/run_deck_benchmark.gd")
	var gsm_script := load("res://scripts/engine/GameStateMachine.gd")
	var benchmark_runner_instance = benchmark_runner_script.new() if benchmark_runner_script != null and benchmark_runner_script.can_instantiate() else null
	var gsm_instance = gsm_script.new() if gsm_script != null and gsm_script.can_instantiate() else null

	return run_checks([
		assert_not_null(benchmark_runner_script, "run_deck_benchmark.gd should load without compile errors"),
		assert_not_null(gsm_script, "GameStateMachine.gd should load without compile errors"),
		assert_not_null(benchmark_runner_instance, "run_deck_benchmark.gd should instantiate without compile errors"),
		assert_not_null(gsm_instance, "GameStateMachine.gd should instantiate without compile errors"),
	])


func test_benchmark_runner_parses_strong_fixed_opening_options() -> String:
	var benchmark_runner_script := load("res://scripts/training/run_deck_benchmark.gd")
	var benchmark_runner_instance = benchmark_runner_script.new() if benchmark_runner_script != null and benchmark_runner_script.can_instantiate() else null
	var parsed: Dictionary = benchmark_runner_instance.call("_parse_args", PackedStringArray([
		"--deck-id=1700011",
		"--anchor-id=575720",
		"--deck-decision-mode=rules_only",
		"--anchor-decision-mode=rules_only",
		"--deck-strong-fixed-opening=true",
		"--anchor-strong-fixed-opening=false",
	])) if benchmark_runner_instance != null else {}

	return run_checks([
		assert_not_null(benchmark_runner_instance, "run_deck_benchmark.gd should instantiate for option parsing"),
		assert_eq(int(parsed.get("deck_id", -1)), 1700011, "Benchmark runner should parse the tested deck id"),
		assert_eq(int(parsed.get("anchor_id", -1)), 575720, "Benchmark runner should parse the anchor deck id"),
		assert_eq(str(parsed.get("deck_decision_mode", "")), "rules_only", "Benchmark runner should parse tracked deck runtime mode"),
		assert_eq(str(parsed.get("anchor_decision_mode", "")), "rules_only", "Benchmark runner should parse anchor runtime mode"),
		assert_true(bool(parsed.get("deck_strong_fixed_opening", false)), "Benchmark runner should enable tested-deck strong fixed opening"),
		assert_false(bool(parsed.get("anchor_strong_fixed_opening", true)), "Benchmark runner should keep anchor strong opening independently configurable"),
	])


func test_font_bootstrap_loads_bundled_chinese_font() -> String:
	var font_script := load("res://scripts/autoload/FontBootstrap.gd")
	var instance: Node = font_script.new() as Node if font_script != null and font_script.can_instantiate() else null
	var font: Font = instance.call("_load_cjk_font") as Font if instance != null else null
	var label := Label.new()
	var rich_text := RichTextLabel.new()
	var plain_node := Node.new()
	if instance != null and font != null:
		instance.set("_cjk_font", font)
		instance.call("_apply_font_to_control", label)
		instance.call("_apply_font_to_control", rich_text)
		instance.call("_apply_font_to_control", plain_node)
	var label_has_override := label.has_theme_font_override("font")
	var rich_text_has_override := rich_text.has_theme_font_override("normal_font")
	label.queue_free()
	rich_text.queue_free()
	plain_node.queue_free()
	return run_checks([
		assert_not_null(font_script, "FontBootstrap.gd should load without compile errors"),
		assert_not_null(instance, "FontBootstrap.gd should instantiate without compile errors"),
		assert_not_null(font, "Bundled CJK font should load on clean runtime startup"),
		assert_true(font.has_char("宝".unicode_at(0)) if font != null else false, "Bundled CJK font should cover Simplified Chinese glyphs"),
		assert_true(font.has_char("梦".unicode_at(0)) if font != null else false, "Bundled CJK font should cover game title glyphs"),
		assert_true(label_has_override, "FontBootstrap should force the bundled CJK font onto standard Control text"),
		assert_true(rich_text_has_override, "FontBootstrap should force the bundled CJK font onto RichTextLabel body text"),
	])


func test_battle_ui_coordinator_scripts_load() -> String:
	var stadium_hud_script := load("res://scripts/ui/battle/display/BattleStadiumHudCoordinator.gd")
	var stadium_backdrop_script := load("res://scripts/ui/battle/display/BattleStadiumBackdropCoordinator.gd")
	var surface_styler_script := load("res://scripts/ui/battle/display/BattleSurfaceStyler.gd")
	var detail_coordinator_script := load("res://scripts/ui/battle/display/BattleCardDetailCoordinator.gd")
	var deck_shuffle_animator_script := load("res://scripts/ui/battle/display/BattleDeckShuffleAnimator.gd")
	var popup_text_scaler_script := load("res://scripts/ui/battle/display/BattlePopupTextScaler.gd")
	var discussion_builder_script := load("res://scripts/ui/battle/advice/BattleDiscussionContextBuilder.gd")
	var layout_debug_reporter_script := load("res://scripts/ui/battle/layouts/BattleLayoutDebugReporter.gd")
	var drag_scroll_coordinator_script := load("res://scripts/ui/battle/interactions/BattleDragScrollCoordinator.gd")
	var stadium_hud_instance = stadium_hud_script.new() if stadium_hud_script != null and stadium_hud_script.can_instantiate() else null
	var stadium_backdrop_instance = stadium_backdrop_script.new() if stadium_backdrop_script != null and stadium_backdrop_script.can_instantiate() else null
	var surface_styler_instance = surface_styler_script.new() if surface_styler_script != null and surface_styler_script.can_instantiate() else null
	var detail_coordinator_instance = detail_coordinator_script.new() if detail_coordinator_script != null and detail_coordinator_script.can_instantiate() else null
	var deck_shuffle_animator_instance = deck_shuffle_animator_script.new() if deck_shuffle_animator_script != null and deck_shuffle_animator_script.can_instantiate() else null
	var popup_text_scaler_instance = popup_text_scaler_script.new() if popup_text_scaler_script != null and popup_text_scaler_script.can_instantiate() else null
	var discussion_builder_instance = discussion_builder_script.new() if discussion_builder_script != null and discussion_builder_script.can_instantiate() else null
	var layout_debug_reporter_instance = layout_debug_reporter_script.new() if layout_debug_reporter_script != null and layout_debug_reporter_script.can_instantiate() else null
	var drag_scroll_coordinator_instance = drag_scroll_coordinator_script.new() if drag_scroll_coordinator_script != null and drag_scroll_coordinator_script.can_instantiate() else null
	return run_checks([
		assert_not_null(stadium_hud_script, "BattleStadiumHudCoordinator.gd should load without compile errors"),
		assert_not_null(stadium_backdrop_script, "BattleStadiumBackdropCoordinator.gd should load without compile errors"),
		assert_not_null(surface_styler_script, "BattleSurfaceStyler.gd should load without compile errors"),
		assert_not_null(detail_coordinator_script, "BattleCardDetailCoordinator.gd should load without compile errors"),
		assert_not_null(deck_shuffle_animator_script, "BattleDeckShuffleAnimator.gd should load without compile errors"),
		assert_not_null(popup_text_scaler_script, "BattlePopupTextScaler.gd should load without compile errors"),
		assert_not_null(discussion_builder_script, "BattleDiscussionContextBuilder.gd should load without compile errors"),
		assert_not_null(layout_debug_reporter_script, "BattleLayoutDebugReporter.gd should load without compile errors"),
		assert_not_null(drag_scroll_coordinator_script, "BattleDragScrollCoordinator.gd should load without compile errors"),
		assert_not_null(stadium_hud_instance, "BattleStadiumHudCoordinator.gd should instantiate without compile errors"),
		assert_not_null(stadium_backdrop_instance, "BattleStadiumBackdropCoordinator.gd should instantiate without compile errors"),
		assert_not_null(surface_styler_instance, "BattleSurfaceStyler.gd should instantiate without compile errors"),
		assert_not_null(detail_coordinator_instance, "BattleCardDetailCoordinator.gd should instantiate without compile errors"),
		assert_not_null(deck_shuffle_animator_instance, "BattleDeckShuffleAnimator.gd should instantiate without compile errors"),
		assert_not_null(popup_text_scaler_instance, "BattlePopupTextScaler.gd should instantiate without compile errors"),
		assert_not_null(discussion_builder_instance, "BattleDiscussionContextBuilder.gd should instantiate without compile errors"),
		assert_not_null(layout_debug_reporter_instance, "BattleLayoutDebugReporter.gd should instantiate without compile errors"),
		assert_not_null(drag_scroll_coordinator_instance, "BattleDragScrollCoordinator.gd should instantiate without compile errors"),
	])


func test_battle_scene_runtime_script_loads() -> String:
	var scene_script := load("res://scenes/battle/BattleScene.gd")
	var runtime_script := load("res://scenes/battle/BattleSceneRuntime.gd")
	var dialog_runtime_script := load("res://scenes/battle/runtime/BattleSceneDialogInteractionReviewRuntime.gd")
	var setup_runtime_script := load("res://scenes/battle/runtime/BattleSceneSetupEffectAiRuntime.gd")
	var board_runtime_script := load("res://scenes/battle/runtime/BattleSceneBoardActionRuntime.gd")
	var shared_runtime_script := load("res://scenes/battle/runtime/BattleSceneSharedHudAiRuntime.gd")
	var scene_instance = scene_script.new() if scene_script != null and scene_script.can_instantiate() else null

	return run_checks([
		assert_not_null(shared_runtime_script, "BattleSceneSharedHudAiRuntime.gd should load without compile errors"),
		assert_not_null(board_runtime_script, "BattleSceneBoardActionRuntime.gd should load without compile errors"),
		assert_not_null(setup_runtime_script, "BattleSceneSetupEffectAiRuntime.gd should load without compile errors"),
		assert_not_null(dialog_runtime_script, "BattleSceneDialogInteractionReviewRuntime.gd should load without compile errors"),
		assert_not_null(runtime_script, "BattleSceneRuntime.gd should load without compile errors"),
		assert_not_null(scene_script, "BattleScene.gd should load without compile errors"),
		assert_not_null(scene_instance, "BattleScene.gd should instantiate without compile errors"),
		assert_true(scene_instance != null and scene_instance.has_method("_show_match_end_dialog"), "BattleScene runtime should expose match-end overlay methods"),
	])


func test_raging_bolt_llm_self_play_tool_scripts_load() -> String:
	var tool_script := load("res://scripts/tools/RagingBoltLLMSelfPlayTool.gd")
	var runner_script := load("res://scripts/tools/run_raging_bolt_llm_self_play.gd")
	var tool_instance = tool_script.new() if tool_script != null and tool_script.can_instantiate() else null
	return run_checks([
		assert_not_null(tool_script, "RagingBoltLLMSelfPlayTool.gd should load without compile errors"),
		assert_not_null(runner_script, "run_raging_bolt_llm_self_play.gd should load without compile errors"),
		assert_not_null(tool_instance, "RagingBoltLLMSelfPlayTool.gd should instantiate without compile errors"),
	])


func test_llm_runtime_base_and_raging_bolt_variant_load() -> String:
	var runtime_script := load("res://scripts/ai/DeckStrategyLLMRuntimeBase.gd")
	var raging_script := load("res://scripts/ai/DeckStrategyRagingBoltLLM.gd")
	var runtime_instance = runtime_script.new() if runtime_script != null and runtime_script.can_instantiate() else null
	var raging_instance = raging_script.new() if raging_script != null and raging_script.can_instantiate() else null
	return run_checks([
		assert_not_null(runtime_script, "DeckStrategyLLMRuntimeBase.gd should load without compile errors"),
		assert_not_null(raging_script, "DeckStrategyRagingBoltLLM.gd should load without compile errors after runtime extraction"),
		assert_not_null(runtime_instance, "DeckStrategyLLMRuntimeBase.gd should instantiate without compile errors"),
		assert_not_null(raging_instance, "DeckStrategyRagingBoltLLM.gd should instantiate without compile errors"),
		assert_eq(str(raging_instance.call("get_strategy_id")) if raging_instance != null and raging_instance.has_method("get_strategy_id") else "", "raging_bolt_ogerpon_llm", "Raging Bolt LLM strategy id should remain stable"),
	])


func test_non_raging_llm_variants_extend_generic_runtime() -> String:
	var dragapult_source := FileAccess.get_file_as_string("res://scripts/ai/DeckStrategyDragapultCharizardLLM.gd")
	var miraidon_source := FileAccess.get_file_as_string("res://scripts/ai/DeckStrategyMiraidonLLM.gd")
	var lugia_source := FileAccess.get_file_as_string("res://scripts/ai/DeckStrategyLugiaArcheopsLLM.gd")
	var charizard_source := FileAccess.get_file_as_string("res://scripts/ai/DeckStrategyCharizardExLLM.gd")
	var dragapult_dusknoir_source := FileAccess.get_file_as_string("res://scripts/ai/DeckStrategyDragapultDusknoirLLM.gd")
	var gardevoir_source := FileAccess.get_file_as_string("res://scripts/ai/DeckStrategyGardevoirLLM.gd")
	var arceus_source := FileAccess.get_file_as_string("res://scripts/ai/DeckStrategyArceusGiratinaLLM.gd")
	return run_checks([
		assert_true(dragapult_source.contains("DeckStrategyLLMRuntimeBase.gd"), "Dragapult Charizard LLM should extend the generic LLM runtime base"),
		assert_true(miraidon_source.contains("DeckStrategyLLMRuntimeBase.gd"), "Miraidon LLM should extend the generic LLM runtime base"),
		assert_true(lugia_source.contains("DeckStrategyLLMRuntimeBase.gd"), "Lugia Archeops LLM should extend the generic LLM runtime base"),
		assert_true(charizard_source.contains("DeckStrategyLLMRuntimeBase.gd"), "Charizard ex LLM should extend the generic LLM runtime base"),
		assert_true(dragapult_dusknoir_source.contains("DeckStrategyLLMRuntimeBase.gd"), "Dragapult Dusknoir LLM should extend the generic LLM runtime base"),
		assert_true(gardevoir_source.contains("DeckStrategyLLMRuntimeBase.gd"), "Gardevoir LLM should extend the generic LLM runtime base"),
		assert_true(arceus_source.contains("DeckStrategyLLMRuntimeBase.gd"), "Arceus Giratina LLM should extend the generic LLM runtime base"),
		assert_false(dragapult_source.contains("DeckStrategyRagingBoltLLM.gd"), "Dragapult Charizard LLM must not inherit the Raging Bolt variant"),
		assert_false(miraidon_source.contains("DeckStrategyRagingBoltLLM.gd"), "Miraidon LLM must not inherit the Raging Bolt variant"),
		assert_false(lugia_source.contains("DeckStrategyRagingBoltLLM.gd"), "Lugia Archeops LLM must not inherit the Raging Bolt variant"),
		assert_false(charizard_source.contains("DeckStrategyRagingBoltLLM.gd"), "Charizard ex LLM must not inherit the Raging Bolt variant"),
		assert_false(dragapult_dusknoir_source.contains("DeckStrategyRagingBoltLLM.gd"), "Dragapult Dusknoir LLM must not inherit the Raging Bolt variant"),
		assert_false(gardevoir_source.contains("DeckStrategyRagingBoltLLM.gd"), "Gardevoir LLM must not inherit the Raging Bolt variant"),
		assert_false(arceus_source.contains("DeckStrategyRagingBoltLLM.gd"), "Arceus Giratina LLM must not inherit the Raging Bolt variant"),
		assert_false(miraidon_source.to_lower().contains("raging_bolt"), "Miraidon LLM wrapper must not contain Raging Bolt-specific references"),
		assert_false(lugia_source.to_lower().contains("raging_bolt"), "Lugia Archeops LLM wrapper must not contain Raging Bolt-specific references"),
	])


func test_v17_llm_variants_extend_shared_v17_runtime() -> String:
	var v17_base_source := FileAccess.get_file_as_string("res://scripts/ai/DeckStrategy17LLMBase.gd")
	var wrapper_paths := [
		"res://scripts/ai/DeckStrategy17ArchaludonDialgaLLM.gd",
		"res://scripts/ai/DeckStrategy17WaterTurtleLLM.gd",
		"res://scripts/ai/DeckStrategy17PalkiaGholdengoLLM.gd",
		"res://scripts/ai/DeckStrategy17BombCharizardLLM.gd",
		"res://scripts/ai/DeckStrategy17MiraidonLLM.gd",
		"res://scripts/ai/DeckStrategy17DragapultDusknoirLLM.gd",
		"res://scripts/ai/DeckStrategy17RegidragoLLM.gd",
	]
	var checks: Array[String] = [
		assert_true(v17_base_source.contains("DeckStrategyLLMRuntimeBase.gd"), "Shared v17 LLM base should extend the generic LLM runtime base"),
		assert_false(v17_base_source.contains("DeckStrategyRagingBoltLLM.gd"), "Shared v17 LLM base must not inherit the Raging Bolt variant"),
	]
	for wrapper_path: String in wrapper_paths:
		var source := FileAccess.get_file_as_string(wrapper_path)
		checks.append(assert_true(source.contains("DeckStrategy17LLMBase.gd"), "%s should extend the shared v17 LLM base" % wrapper_path))
		checks.append(assert_false(source.contains("DeckStrategyRagingBoltLLM.gd"), "%s must not inherit the Raging Bolt variant" % wrapper_path))
	return run_checks(checks)


func test_llm_runtime_core_uses_deck_hooks_for_deck_specific_logic() -> String:
	var runtime_source := FileAccess.get_file_as_string("res://scripts/ai/DeckStrategyLLMRuntimeBase.gd")
	var core_end := runtime_source.find("func _is_raging_bolt_first_attack_ref")
	var core_source := runtime_source.substr(0, core_end) if core_end > 0 else runtime_source
	return run_checks([
		assert_true(core_source.contains("_deck_can_replace_end_turn_with_action"), "Runtime queue matching should use deck hook for end-turn replacement"),
		assert_true(core_source.contains("_deck_action_ref_enables_attack"), "Runtime contract repair should use deck hook for deck-specific attack setup"),
		assert_true(core_source.contains("_deck_validate_action_interactions"), "Runtime contract validation should delegate deck-specific interaction rules"),
		assert_false(core_source.contains("Raging Bolt"), "Core runtime section must not mention Raging Bolt directly"),
		assert_false(core_source.contains("Teal Mask Ogerpon"), "Core runtime section must not mention Ogerpon directly"),
		assert_false(core_source.contains("Professor Sada"), "Core runtime section must not mention Sada directly"),
		assert_false(core_source.contains("Earthen Vessel"), "Core runtime section must not mention Earthen Vessel directly"),
	])


func test_miraidon_llm_strategy_script_loads() -> String:
	var script := load("res://scripts/ai/DeckStrategyMiraidonLLM.gd")
	var instance = script.new() if script != null and script.can_instantiate() else null
	return run_checks([
		assert_not_null(script, "DeckStrategyMiraidonLLM.gd should load without compile errors"),
		assert_not_null(instance, "DeckStrategyMiraidonLLM.gd should instantiate without compile errors"),
		assert_eq(str(instance.call("get_strategy_id")) if instance != null and instance.has_method("get_strategy_id") else "", "miraidon_llm", "Miraidon LLM strategy id should be registered by the script"),
	])


func test_dragapult_charizard_llm_strategy_loads() -> String:
	var rules_script := load("res://scripts/ai/DeckStrategyDragapultCharizard.gd")
	var llm_script := load("res://scripts/ai/DeckStrategyDragapultCharizardLLM.gd")
	var registry_script := load("res://scripts/ai/DeckStrategyRegistry.gd")
	var llm_instance = llm_script.new() if llm_script != null and llm_script.can_instantiate() else null
	return run_checks([
		assert_not_null(rules_script, "DeckStrategyDragapultCharizard.gd should load without compile errors"),
		assert_not_null(llm_script, "DeckStrategyDragapultCharizardLLM.gd should load without compile errors"),
		assert_not_null(registry_script, "DeckStrategyRegistry.gd should load after registering the LLM variant"),
		assert_not_null(llm_instance, "DeckStrategyDragapultCharizardLLM.gd should instantiate without compile errors"),
	])


func test_lugia_archeops_llm_strategy_loads() -> String:
	var rules_script := load("res://scripts/ai/DeckStrategyLugiaArcheops.gd")
	var llm_script := load("res://scripts/ai/DeckStrategyLugiaArcheopsLLM.gd")
	var registry_script := load("res://scripts/ai/DeckStrategyRegistry.gd")
	var llm_instance = llm_script.new() if llm_script != null and llm_script.can_instantiate() else null
	var registry = registry_script.new() if registry_script != null and registry_script.can_instantiate() else null
	var registry_instance = registry.call("create_strategy_by_id", "lugia_archeops_llm") if registry != null else null
	return run_checks([
		assert_not_null(rules_script, "DeckStrategyLugiaArcheops.gd should load without compile errors"),
		assert_not_null(llm_script, "DeckStrategyLugiaArcheopsLLM.gd should load without compile errors"),
		assert_not_null(registry_script, "DeckStrategyRegistry.gd should load after registering the Lugia LLM variant"),
		assert_not_null(llm_instance, "DeckStrategyLugiaArcheopsLLM.gd should instantiate without compile errors"),
		assert_eq(str(llm_instance.call("get_strategy_id")) if llm_instance != null and llm_instance.has_method("get_strategy_id") else "", "lugia_archeops_llm", "Lugia LLM strategy id should be stable"),
		assert_not_null(registry_instance, "Registry should create lugia_archeops_llm"),
		assert_eq(str(registry_instance.call("get_strategy_id")) if registry_instance != null and registry_instance.has_method("get_strategy_id") else "", "lugia_archeops_llm", "Registered Lugia LLM variant should report its strategy id"),
	])


func test_dragapult_dusknoir_llm_strategy_loads() -> String:
	var rules_script := load("res://scripts/ai/DeckStrategyDragapultDusknoir.gd")
	var llm_script := load("res://scripts/ai/DeckStrategyDragapultDusknoirLLM.gd")
	var registry_script := load("res://scripts/ai/DeckStrategyRegistry.gd")
	var llm_instance = llm_script.new() if llm_script != null and llm_script.can_instantiate() else null
	var registry = registry_script.new() if registry_script != null and registry_script.can_instantiate() else null
	var registry_instance = registry.call("create_strategy_by_id", "dragapult_dusknoir_llm") if registry != null else null
	return run_checks([
		assert_not_null(rules_script, "DeckStrategyDragapultDusknoir.gd should load without compile errors"),
		assert_not_null(llm_script, "DeckStrategyDragapultDusknoirLLM.gd should load without compile errors"),
		assert_not_null(registry_script, "DeckStrategyRegistry.gd should load after registering the Dragapult Dusknoir LLM variant"),
		assert_not_null(llm_instance, "DeckStrategyDragapultDusknoirLLM.gd should instantiate without compile errors"),
		assert_eq(str(llm_instance.call("get_strategy_id")) if llm_instance != null and llm_instance.has_method("get_strategy_id") else "", "dragapult_dusknoir_llm", "Dragapult Dusknoir LLM strategy id should be stable"),
		assert_not_null(registry_instance, "Registry should create dragapult_dusknoir_llm"),
		assert_eq(str(registry_instance.call("get_strategy_id")) if registry_instance != null and registry_instance.has_method("get_strategy_id") else "", "dragapult_dusknoir_llm", "Registered Dragapult Dusknoir LLM variant should report its strategy id"),
	])


func test_charizard_ex_llm_strategy_loads() -> String:
	var rules_script := load("res://scripts/ai/DeckStrategyCharizardEx.gd")
	var llm_script := load("res://scripts/ai/DeckStrategyCharizardExLLM.gd")
	var registry_script := load("res://scripts/ai/DeckStrategyRegistry.gd")
	var llm_instance = llm_script.new() if llm_script != null and llm_script.can_instantiate() else null
	var registry = registry_script.new() if registry_script != null and registry_script.can_instantiate() else null
	var registry_instance = registry.call("create_strategy_by_id", "charizard_ex_llm") if registry != null else null
	return run_checks([
		assert_not_null(rules_script, "DeckStrategyCharizardEx.gd should load without compile errors"),
		assert_not_null(llm_script, "DeckStrategyCharizardExLLM.gd should load without compile errors"),
		assert_not_null(registry_script, "DeckStrategyRegistry.gd should load after registering the Charizard ex LLM variant"),
		assert_not_null(llm_instance, "DeckStrategyCharizardExLLM.gd should instantiate without compile errors"),
		assert_eq(str(llm_instance.call("get_strategy_id")) if llm_instance != null and llm_instance.has_method("get_strategy_id") else "", "charizard_ex_llm", "Charizard ex LLM strategy id should be stable"),
		assert_not_null(registry_instance, "Registry should create charizard_ex_llm"),
		assert_eq(str(registry_instance.call("get_strategy_id")) if registry_instance != null and registry_instance.has_method("get_strategy_id") else "", "charizard_ex_llm", "Registered Charizard ex LLM variant should report its strategy id"),
	])


func test_gardevoir_llm_strategy_loads() -> String:
	var rules_script := load("res://scripts/ai/DeckStrategyGardevoir.gd")
	var llm_script := load("res://scripts/ai/DeckStrategyGardevoirLLM.gd")
	var registry_script := load("res://scripts/ai/DeckStrategyRegistry.gd")
	var llm_instance = llm_script.new() if llm_script != null and llm_script.can_instantiate() else null
	var registry = registry_script.new() if registry_script != null and registry_script.can_instantiate() else null
	var registry_instance = registry.call("create_strategy_by_id", "gardevoir_llm") if registry != null else null
	return run_checks([
		assert_not_null(rules_script, "DeckStrategyGardevoir.gd should load without compile errors"),
		assert_not_null(llm_script, "DeckStrategyGardevoirLLM.gd should load without compile errors"),
		assert_not_null(registry_script, "DeckStrategyRegistry.gd should load after registering the Gardevoir LLM variant"),
		assert_not_null(llm_instance, "DeckStrategyGardevoirLLM.gd should instantiate without compile errors"),
		assert_eq(str(llm_instance.call("get_strategy_id")) if llm_instance != null and llm_instance.has_method("get_strategy_id") else "", "gardevoir_llm", "Gardevoir LLM strategy id should be stable"),
		assert_not_null(registry_instance, "Registry should create gardevoir_llm"),
		assert_eq(str(registry_instance.call("get_strategy_id")) if registry_instance != null and registry_instance.has_method("get_strategy_id") else "", "gardevoir_llm", "Registered Gardevoir LLM variant should report its strategy id"),
	])


func test_arceus_giratina_llm_strategy_loads() -> String:
	var rules_script := load("res://scripts/ai/DeckStrategyArceusGiratina.gd")
	var llm_script := load("res://scripts/ai/DeckStrategyArceusGiratinaLLM.gd")
	var registry_script := load("res://scripts/ai/DeckStrategyRegistry.gd")
	var llm_instance = llm_script.new() if llm_script != null and llm_script.can_instantiate() else null
	var registry = registry_script.new() if registry_script != null and registry_script.can_instantiate() else null
	var registry_instance = registry.call("create_strategy_by_id", "arceus_giratina_llm") if registry != null else null
	return run_checks([
		assert_not_null(rules_script, "DeckStrategyArceusGiratina.gd should load without compile errors"),
		assert_not_null(llm_script, "DeckStrategyArceusGiratinaLLM.gd should load without compile errors"),
		assert_not_null(registry_script, "DeckStrategyRegistry.gd should load after registering the Arceus Giratina LLM variant"),
		assert_not_null(llm_instance, "DeckStrategyArceusGiratinaLLM.gd should instantiate without compile errors"),
		assert_eq(str(llm_instance.call("get_strategy_id")) if llm_instance != null and llm_instance.has_method("get_strategy_id") else "", "arceus_giratina_llm", "Arceus Giratina LLM strategy id should be stable"),
		assert_not_null(registry_instance, "Registry should create arceus_giratina_llm"),
		assert_eq(str(registry_instance.call("get_strategy_id")) if registry_instance != null and registry_instance.has_method("get_strategy_id") else "", "arceus_giratina_llm", "Registered Arceus Giratina LLM variant should report its strategy id"),
	])


func test_v17_llm_strategy_variants_load_and_register() -> String:
	var cases := {
		"v17_archaludon_dialga_llm": ["res://scripts/ai/DeckStrategy17ArchaludonDialga.gd", "res://scripts/ai/DeckStrategy17ArchaludonDialgaLLM.gd"],
		"v17_water_turtle_llm": ["res://scripts/ai/DeckStrategy17WaterTurtle.gd", "res://scripts/ai/DeckStrategy17WaterTurtleLLM.gd"],
		"v17_palkia_gholdengo_llm": ["res://scripts/ai/DeckStrategy17PalkiaGholdengo.gd", "res://scripts/ai/DeckStrategy17PalkiaGholdengoLLM.gd"],
		"v17_bomb_charizard_llm": ["res://scripts/ai/DeckStrategy17BombCharizard.gd", "res://scripts/ai/DeckStrategy17BombCharizardLLM.gd"],
		"v17_miraidon_llm": ["res://scripts/ai/DeckStrategy17Miraidon.gd", "res://scripts/ai/DeckStrategy17MiraidonLLM.gd"],
		"v17_dragapult_dusknoir_llm": ["res://scripts/ai/DeckStrategy17DragapultDusknoir.gd", "res://scripts/ai/DeckStrategy17DragapultDusknoirLLM.gd"],
		"v17_regidrago_llm": ["res://scripts/ai/DeckStrategy17Regidrago.gd", "res://scripts/ai/DeckStrategy17RegidragoLLM.gd"],
	}
	var registry_script := load("res://scripts/ai/DeckStrategyRegistry.gd")
	var registry = registry_script.new() if registry_script != null and registry_script.can_instantiate() else null
	var checks: Array[String] = [
		assert_not_null(registry_script, "DeckStrategyRegistry.gd should load after registering v17 LLM variants"),
		assert_not_null(registry, "DeckStrategyRegistry.gd should instantiate after registering v17 LLM variants"),
	]
	for strategy_id: String in cases.keys():
		var paths: Array = cases[strategy_id]
		var rules_script := load(str(paths[0]))
		var llm_script := load(str(paths[1]))
		var llm_instance = llm_script.new() if llm_script != null and llm_script.can_instantiate() else null
		var registry_instance = registry.call("create_strategy_by_id", strategy_id) if registry != null else null
		checks.append(assert_not_null(rules_script, "%s rules script should load without compile errors" % strategy_id))
		checks.append(assert_not_null(llm_script, "%s LLM script should load without compile errors" % strategy_id))
		checks.append(assert_not_null(llm_instance, "%s LLM script should instantiate without compile errors" % strategy_id))
		checks.append(assert_eq(str(llm_instance.call("get_strategy_id")) if llm_instance != null and llm_instance.has_method("get_strategy_id") else "", strategy_id, "%s should report its strategy id" % strategy_id))
		checks.append(assert_not_null(registry_instance, "Registry should create %s" % strategy_id))
		checks.append(assert_eq(str(registry_instance.call("get_strategy_id")) if registry_instance != null and registry_instance.has_method("get_strategy_id") else "", strategy_id, "Registered %s should report its strategy id" % strategy_id))
		checks.append(assert_true(registry_instance != null and registry_instance.has_method("get_llm_stats"), "%s should expose LLM runtime stats" % strategy_id))
	return run_checks(checks)
