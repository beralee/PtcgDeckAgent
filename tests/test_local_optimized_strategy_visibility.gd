class_name TestLocalOptimizedStrategyVisibility
extends TestBase

const BattleSetupScene = preload("res://scenes/battle_setup/BattleSetup.tscn")
const DeckStrategyRegistryScript = preload("res://scripts/ai/DeckStrategyRegistry.gd")

const TARGET_DECKS := {
	800017097: "18.0 无碟沙奈朵",
	800017280: "18.0 铝钢龙钢铁防线",
	800018499: "18.0 多龙巴鲁托",
	800018501: "18.0 玛俐的长毛巨魔",
	800018502: "18.0 N的索罗亚克",
	800018509: "18.0 猛雷鼓厄诡椪",
	800018543: "18.0 竹兰烈咬陆鲨",
}


func test_local_optimized_strategies_are_visible_and_selected_in_ai_battle_setup() -> String:
	var scene: Control = BattleSetupScene.instantiate()
	scene.call("_ready")
	var mode_option := scene.find_child("ModeOption", true, false) as OptionButton
	var deck_option := scene.find_child("Deck2Option", true, false) as OptionButton
	var strategy_option := scene.find_child("AIStrategyOption", true, false) as OptionButton
	var strategy_segment := scene.find_child("AIStrategySegment", true, false) as HBoxContainer
	var status_title := scene.find_child("AIModeStatusTitle", true, false) as Label
	var status_body := scene.find_child("AIModeStatusBody", true, false) as Label
	mode_option.select(1)
	scene.call("_on_mode_changed", 1)

	var checks: Array[String] = []
	for deck_id: int in TARGET_DECKS:
		var expected_strategy_id := DeckStrategyRegistryScript.strategy_id_for_deck_id(deck_id)
		checks.append(assert_true(CardDatabase.get_ai_deck(deck_id) != null, "%d must be present in the local AI deck catalog" % deck_id))
		checks.append(assert_true(expected_strategy_id != "", "%d must resolve a concrete strategy id" % deck_id))
		scene.call("_select_option_for_deck_id", deck_option, deck_id)
		scene.call("_refresh_ai_strategy_variant_options")
		scene.call("_refresh_llm_model_controls")
		var variants: Array = scene.call("_detect_ai_strategy_variants")
		checks.append(assert_true(not variants.is_empty(), "%d must expose its optimized strategy in BattleSetup" % deck_id))
		if variants.is_empty():
			continue
		checks.append(assert_eq(str(variants[0].get("id", "")), expected_strategy_id, "%d must select its resolved rules strategy" % deck_id))
		checks.append(assert_eq(str(variants[0].get("label", "")), "开发工具包优化版", "%d must use an explicit optimized-strategy label" % deck_id))
		checks.append(assert_true(strategy_segment.visible, "%d strategy segment must be visible" % deck_id))
		checks.append(assert_eq(str(strategy_option.get_item_metadata(0)), expected_strategy_id, "%d UI metadata must carry the strategy id into match start" % deck_id))
		checks.append(assert_str_contains(status_title.text, "开发工具包优化策略", "%d status title must confirm the toolkit strategy is loaded" % deck_id))
		checks.append(assert_str_contains(status_body.text, str(TARGET_DECKS[deck_id]), "%d status body must name the selected deck" % deck_id))
		checks.append(assert_str_contains(status_body.text, expected_strategy_id, "%d status body must expose the exact loaded strategy id" % deck_id))
		checks.append(assert_true(bool(scene.call("_apply_setup_selection")), "%d setup selection must be accepted" % deck_id))
		checks.append(assert_eq(GameManager.ai_deck_strategy, expected_strategy_id, "%d match launch must receive the exact selected strategy id" % deck_id))

	scene.free()
	return run_checks(checks)
