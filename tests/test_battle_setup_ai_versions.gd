class_name TestBattleSetupAIVersions
extends TestBase

const BattleSetupScene = preload("res://scenes/battle_setup/BattleSetup.tscn")


class FakeAIVersionRegistry extends RefCounted:
	var playable_versions: Array[Dictionary] = []

	func list_playable_versions() -> Array[Dictionary]:
		return playable_versions.duplicate(true)

	func get_latest_playable_version() -> Dictionary:
		if playable_versions.is_empty():
			return {}
		return playable_versions[playable_versions.size() - 1].duplicate(true)


func _make_scene_ready() -> Control:
	var scene: Control = BattleSetupScene.instantiate()
	scene.call("_ready")
	# AI 控件在 _ready() 中被隐藏，测试需要手动初始化
	scene.call("_setup_ai_source_options")
	scene.call("_refresh_ai_version_options")
	return scene


func _make_deck(deck_id: int, deck_name: String) -> DeckData:
	var deck := DeckData.new()
	deck.id = deck_id
	deck.deck_name = deck_name
	deck.total_cards = 60
	return deck


func _prime_deck_options(scene: Control) -> void:
	scene.set("_deck_list", [_make_deck(101, "deck-a"), _make_deck(202, "deck-b")])
	var deck1_option := scene.find_child("Deck1Option", true, false) as OptionButton
	var deck2_option := scene.find_child("Deck2Option", true, false) as OptionButton
	deck1_option.clear()
	deck2_option.clear()
	deck1_option.add_item("deck-a", 0)
	deck2_option.add_item("deck-b", 0)
	deck1_option.select(0)
	deck2_option.select(0)


func test_battle_setup_includes_ai_source_and_version_controls() -> String:
	var scene := BattleSetupScene.instantiate()
	var ai_source_label := scene.find_child("AISourceLabel", true, false)
	var ai_source_option := scene.find_child("AISourceOption", true, false)
	var ai_version_label := scene.find_child("AIVersionLabel", true, false)
	var ai_version_option := scene.find_child("AIVersionOption", true, false)

	return run_checks([
		assert_true(ai_source_label is Label, "BattleSetup should include AISourceLabel"),
		assert_true(ai_source_option is OptionButton, "BattleSetup should include AISourceOption"),
		assert_true(ai_version_label is Label, "BattleSetup should include AIVersionLabel"),
		assert_true(ai_version_option is OptionButton, "BattleSetup should include AIVersionOption"),
	])


func test_battle_setup_populates_ai_source_options() -> String:
	var scene := _make_scene_ready()
	var ai_source_option := scene.find_child("AISourceOption", true, false) as OptionButton

	return run_checks([
		assert_eq(ai_source_option.get_item_count(), 3, "AI source should have three options"),
		assert_eq(ai_source_option.get_item_text(0), "默认 AI", "Option 0 should be default AI"),
		assert_eq(ai_source_option.get_item_text(1), "最新训练版 AI", "Option 1 should be latest trained AI"),
		assert_eq(ai_source_option.get_item_text(2), "指定训练版本 AI", "Option 2 should be specific trained AI"),
	])


func test_battle_setup_refreshes_ai_version_options_from_registry() -> String:
	var scene := _make_scene_ready()
	var registry := FakeAIVersionRegistry.new()
	registry.playable_versions = [
		{
			"version_id": "AI-20260328-01",
			"display_name": "v015 + value1",
			"benchmark_summary": {"win_rate_vs_current_best": 0.57},
		},
		{
			"version_id": "AI-20260328-02",
			"display_name": "v016 + value2",
		},
	]
	scene.call("set_ai_version_registry_for_test", registry)
	scene.call("_refresh_ai_version_options")
	var ai_version_option := scene.find_child("AIVersionOption", true, false) as OptionButton

	return run_checks([
		assert_eq(ai_version_option.get_item_count(), 2, "AI version dropdown should reflect playable versions"),
		assert_str_contains(ai_version_option.get_item_text(0), "AI-20260328-01", "First option should include version_id"),
		assert_str_contains(ai_version_option.get_item_text(0), "v015 + value1", "First option should include display_name"),
		assert_str_contains(ai_version_option.get_item_text(1), "AI-20260328-02", "Second option should include version_id"),
	])


func test_apply_setup_selection_writes_default_ai_selection() -> String:
	var previous_current_mode := GameManager.current_mode
	var previous_selected_deck_ids := GameManager.selected_deck_ids.duplicate()
	var previous_first_player_choice := GameManager.first_player_choice
	var previous_background := GameManager.selected_battle_background
	var previous_ai_selection := GameManager.ai_selection.duplicate(true)

	var scene := _make_scene_ready()
	_prime_deck_options(scene)

	var ai_source_option := scene.find_child("AISourceOption", true, false) as OptionButton
	ai_source_option.select(0)

	var ok: bool = scene.call("_apply_setup_selection")
	var selection: Dictionary = GameManager.ai_selection

	GameManager.current_mode = previous_current_mode
	GameManager.selected_deck_ids = previous_selected_deck_ids
	GameManager.first_player_choice = previous_first_player_choice
	GameManager.selected_battle_background = previous_background
	GameManager.ai_selection = previous_ai_selection

	return run_checks([
		assert_true(ok, "_apply_setup_selection should succeed"),
		assert_eq(str(selection.get("source", "")), "default", "Default source should write default"),
		assert_eq(str(selection.get("version_id", "")), "", "Default source should not bind version_id"),
		assert_eq(str(selection.get("agent_config_path", "")), "", "Default source should not bind agent_config_path"),
		assert_eq(str(selection.get("value_net_path", "")), "", "Default source should not bind value_net_path"),
		assert_eq(str(selection.get("display_name", "")), "", "Default source should not bind display_name"),
	])


func test_apply_setup_selection_writes_latest_trained_ai_selection() -> String:
	var previous_current_mode := GameManager.current_mode
	var previous_selected_deck_ids := GameManager.selected_deck_ids.duplicate()
	var previous_first_player_choice := GameManager.first_player_choice
	var previous_background := GameManager.selected_battle_background
	var previous_ai_selection := GameManager.ai_selection.duplicate(true)

	var scene := _make_scene_ready()
	_prime_deck_options(scene)
	var registry := FakeAIVersionRegistry.new()
	registry.playable_versions = [{
		"version_id": "AI-20260328-03",
		"display_name": "v017 + value3",
		"agent_config_path": "user://ai_agents/agent_v017.json",
		"value_net_path": "user://ai_models/value_net_v3.json",
	}]
	scene.call("set_ai_version_registry_for_test", registry)

	var ai_source_option := scene.find_child("AISourceOption", true, false) as OptionButton
	ai_source_option.select(1)

	var ok: bool = scene.call("_apply_setup_selection")
	var selection: Dictionary = GameManager.ai_selection
	GameManager.current_mode = previous_current_mode
	GameManager.selected_deck_ids = previous_selected_deck_ids
	GameManager.first_player_choice = previous_first_player_choice
	GameManager.selected_battle_background = previous_background
	GameManager.ai_selection = previous_ai_selection

	return run_checks([
		assert_true(ok, "_apply_setup_selection should succeed"),
		assert_eq(str(selection.get("source", "")), "latest_trained", "Latest source should write latest_trained"),
		assert_eq(str(selection.get("version_id", "")), "AI-20260328-03", "Latest source should bind version_id"),
		assert_eq(str(selection.get("agent_config_path", "")), "user://ai_agents/agent_v017.json", "Latest source should bind agent_config_path"),
		assert_eq(str(selection.get("value_net_path", "")), "user://ai_models/value_net_v3.json", "Latest source should bind value_net_path"),
		assert_eq(str(selection.get("display_name", "")), "v017 + value3", "Latest source should bind display_name"),
	])


func test_apply_setup_selection_falls_back_to_default_when_specific_version_missing() -> String:
	var previous_current_mode := GameManager.current_mode
	var previous_selected_deck_ids := GameManager.selected_deck_ids.duplicate()
	var previous_first_player_choice := GameManager.first_player_choice
	var previous_background := GameManager.selected_battle_background
	var previous_ai_selection := GameManager.ai_selection.duplicate(true)

	var scene := _make_scene_ready()
	_prime_deck_options(scene)
	scene.call("set_ai_version_registry_for_test", FakeAIVersionRegistry.new())

	var ai_source_option := scene.find_child("AISourceOption", true, false) as OptionButton
	ai_source_option.select(2)

	var ok: bool = scene.call("_apply_setup_selection")
	var selection: Dictionary = GameManager.ai_selection
	GameManager.current_mode = previous_current_mode
	GameManager.selected_deck_ids = previous_selected_deck_ids
	GameManager.first_player_choice = previous_first_player_choice
	GameManager.selected_battle_background = previous_background
	GameManager.ai_selection = previous_ai_selection

	return run_checks([
		assert_true(ok, "_apply_setup_selection should succeed"),
		assert_eq(str(selection.get("source", "")), "default", "Missing specific version should fall back to default"),
		assert_eq(str(selection.get("version_id", "")), "", "Fallback should not bind version_id"),
		assert_eq(str(selection.get("agent_config_path", "")), "", "Fallback should not bind agent_config_path"),
		assert_eq(str(selection.get("value_net_path", "")), "", "Fallback should not bind value_net_path"),
		assert_eq(str(selection.get("display_name", "")), "", "Fallback should not bind display_name"),
	])
