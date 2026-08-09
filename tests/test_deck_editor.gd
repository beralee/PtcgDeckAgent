class_name TestDeckEditor
extends TestBase

const DeckEditorScript := preload("res://scenes/deck_editor/DeckEditor.gd")
const DeckEditorScene := preload("res://scenes/deck_editor/DeckEditor.tscn")
const NonBattleTouchBridgeScript := preload("res://scripts/ui/non_battle/NonBattleTouchBridge.gd")
const EXPECTED_TERA_EX_UIDS := [
	"CSV5C_075",
	"CSV7C_123",
	"CSV7C_141",
	"CSV8C_028",
	"CSV8C_067",
	"CSV8C_121",
	"CSV8C_159",
	"CSV9.5C_006",
	"CSV9.5C_023",
	"CSV9.5C_029",
	"CSV9.5C_036",
	"CSV9.5C_047",
	"CSV9.5C_058",
	"CSV9.5C_068",
	"CSV9.5C_104",
	"CSV9.5C_140",
	"CSV9C_034",
	"CSV9C_054",
	"CSV9C_064",
	"CSV9C_090",
	"CSV9C_119",
	"CSV9C_144",
	"CSV9C_152",
	"CSV9C_175",
]


func _set_navigation_suppressed(suppressed: bool) -> void:
	if GameManager.has_method("set_scene_navigation_suppressed_for_tests"):
		GameManager.call("set_scene_navigation_suppressed_for_tests", suppressed)


func _make_deck() -> DeckData:
	var deck := DeckData.new()
	deck.id = 999999
	deck.deck_name = "测试卡组"
	deck.import_date = "2026-01-01"
	deck.cards = [
		{"set_code": "SV1", "card_index": "001", "count": 2, "card_type": "Pokemon", "name": "皮卡丘", "effect_id": "e001", "name_en": "Pikachu"},
		{"set_code": "SV1", "card_index": "050", "count": 1, "card_type": "Supporter", "name": "博士", "effect_id": "e050", "name_en": "Professor"},
		{"set_code": "SV1", "card_index": "060", "count": 1, "card_type": "Basic Energy", "name": "雷能量", "effect_id": "", "name_en": "Lightning Energy"},
	]
	deck.total_cards = 4
	return deck


func _make_card(set_code: String, card_index: String, card_name: String, card_type: String) -> CardData:
	var card := CardData.new()
	card.set_code = set_code
	card.card_index = card_index
	card.name = card_name
	card.card_type = card_type
	card.effect_id = ""
	card.name_en = card_name
	return card


func _find_descendant_by_name(root: Node, node_name: String) -> Node:
	if root == null:
		return null
	if root.name == node_name:
		return root
	for child: Node in root.get_children():
		var found := _find_descendant_by_name(child, node_name)
		if found != null:
			return found
	return null


func _find_descendant_by_class(root: Node, class_name_text: String) -> Node:
	if root == null:
		return null
	if root.get_class() == class_name_text:
		return root
	for child: Node in root.get_children():
		var found := _find_descendant_by_class(child, class_name_text)
		if found != null:
			return found
	return null


func _count_blocking_descendant_controls(root: Control) -> int:
	var count := 0
	for child: Node in root.get_children():
		if child is Control:
			var control := child as Control
			if control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
				count += 1
			count += _count_blocking_descendant_controls(control)
	return count


func test_build_pool_includes_151c_035_036_pokemon() -> String:
	var editor: Control = DeckEditorScript.new()
	editor.call("_build_pool")
	var pool_by_category: Array = editor.get("_pool_by_category")
	var pokemon_cards: Array = pool_by_category[0] if pool_by_category.size() > 0 else []
	var found: Dictionary = {}
	for card: CardData in pokemon_cards:
		if card != null and card.get_uid() in ["151C_035", "151C_036"]:
			found[card.get_uid()] = card
	var checks: Array[String] = [
		assert_true(found.has("151C_035"), "DeckEditor Pokemon tab should include 151C_035 Clefairy"),
		assert_true(found.has("151C_036"), "DeckEditor Pokemon tab should include 151C_036 Clefable"),
	]
	if found.has("151C_035"):
		checks.append(assert_eq((found["151C_035"] as CardData).stage, "Basic", "Clefairy should remain Basic in the card pool"))
	if found.has("151C_036"):
		checks.append(assert_eq((found["151C_036"] as CardData).evolves_from, "皮皮", "Clefable should retain its evolution metadata in the card pool"))
	editor.free()
	return run_checks(checks)


func test_deck_editor_replaces_strategy_button_with_card_search() -> String:
	var editor: Control = DeckEditorScene.instantiate()
	var search_button := editor.get_node_or_null("%BtnCardSearch") as Button
	var strategy_button := editor.get_node_or_null("%BtnStrategy") as Button
	var ai_button := editor.get_node_or_null("%BtnAI") as Button
	var discuss_button := editor.get_node_or_null("%BtnDiscussAI") as Button
	editor.queue_free()

	return run_checks([
		assert_not_null(search_button, "卡组编辑页应提供搜索卡牌入口"),
		assert_eq(search_button.text if search_button != null else "", "搜索卡牌", "搜索入口应使用明确的中文标签"),
		assert_true(search_button.visible if search_button != null else false, "搜索卡牌按钮应在卡组编辑页可见"),
		assert_null(strategy_button, "打法思路按钮应由卡牌搜索入口替换"),
		assert_not_null(ai_button, "旧 AI 分析按钮节点可保留以兼容旧代码"),
		assert_not_null(discuss_button, "与 AI 探讨按钮应保留"),
		assert_false(ai_button.visible, "AI 分析按钮应从界面隐藏"),
		assert_true(discuss_button.visible, "与 AI 探讨按钮应保持可见"),
	])


func test_pool_search_fuzzy_matches_chinese_and_english_card_names() -> String:
	var editor: Control = DeckEditorScript.new()
	var pikachu := _make_card("SV1", "001", "皮卡丘ex", "Pokemon")
	pikachu.name_en = "Pikachu ex"
	var charizard := _make_card("SV1", "002", "喷火龙ex", "Pokemon")
	charizard.name_en = "Charizard ex"
	editor.set("_pool_by_category", [[pikachu, charizard], [], [], [], [], []] as Array[Array])

	editor.set("_pool_search_query", "皮丘")
	var chinese_matches: Array = editor.call("_filtered_pool_cards", 0)
	editor.set("_pool_search_query", "pka ex")
	var english_matches: Array = editor.call("_filtered_pool_cards", 0)

	return run_checks([
		assert_eq(chinese_matches.size(), 1, "中文卡名应支持非连续字符模糊搜索"),
		assert_eq((chinese_matches[0] as CardData).get_uid() if chinese_matches.size() == 1 else "", pikachu.get_uid(), "中文模糊搜索应命中皮卡丘"),
		assert_eq(english_matches.size(), 1, "英文卡名应忽略空格并支持模糊搜索"),
		assert_eq((english_matches[0] as CardData).get_uid() if english_matches.size() == 1 else "", pikachu.get_uid(), "英文模糊搜索应命中 Pikachu ex"),
	])


func test_pool_search_combines_pokemon_name_tag_and_energy_filters() -> String:
	var editor: Control = DeckEditorScript.new()
	var ancient_fire := _make_card("SV1", "010", "古代火龙", "Pokemon")
	ancient_fire.energy_type = "R"
	ancient_fire.is_tags = PackedStringArray(["Ancient"])
	var ancient_water := _make_card("SV1", "011", "古代水龙", "Pokemon")
	ancient_water.energy_type = "W"
	ancient_water.is_tags = PackedStringArray(["Ancient"])
	var future_fire := _make_card("SV1", "012", "未来火龙", "Pokemon")
	future_fire.energy_type = "R"
	future_fire.is_tags = PackedStringArray(["Future"])
	editor.set("_pool_by_category", [[ancient_fire, ancient_water, future_fire], [], [], [], [], []] as Array[Array])
	editor.set("_pool_search_query", "火龙")
	editor.set("_pool_search_tag", "Ancient")
	editor.set("_pool_search_energy_type", "R")

	var matches: Array = editor.call("_filtered_pool_cards", 0)
	return run_checks([
		assert_eq(matches.size(), 1, "名称、标签和属性应以组合条件过滤宝可梦"),
		assert_eq((matches[0] as CardData).get_uid() if matches.size() == 1 else "", ancient_fire.get_uid(), "组合筛选应只保留对应的古代火属性宝可梦"),
	])


func test_pool_search_ex_type_matches_mechanic_tag_and_card_name() -> String:
	var editor: Control = DeckEditorScript.new()
	var mechanic_ex := _make_card("SV1", "013", "梦幻", "Pokemon")
	mechanic_ex.mechanic = "ex"
	var tagged_ex := _make_card("SV1", "014", "喷火龙", "Pokemon")
	tagged_ex.is_tags = PackedStringArray(["ex"])
	var named_ex := _make_card("SV1", "015", "皮卡丘ex", "Pokemon")
	var pokemon_v := _make_card("SV1", "016", "密勒顿V", "Pokemon")
	pokemon_v.mechanic = "V"
	editor.set("_pool_by_category", [[mechanic_ex, tagged_ex, named_ex, pokemon_v], [], [], [], [], []] as Array[Array])
	editor.set("_pool_search_tag", "ex")

	var matches: Array = editor.call("_filtered_pool_cards", 0)
	var matched_uids: Array[String] = []
	for card: CardData in matches:
		matched_uids.append(card.get_uid())
	return run_checks([
		assert_eq(matches.size(), 3, "ex 类型应识别 mechanic、is_tags 和卡名后缀三种数据来源"),
		assert_true(mechanic_ex.get_uid() in matched_uids, "mechanic=ex 的宝可梦应被类型筛选命中"),
		assert_true(tagged_ex.get_uid() in matched_uids, "is_tags 包含 ex 的宝可梦应被类型筛选命中"),
		assert_true(named_ex.get_uid() in matched_uids, "旧数据只在名称带 ex 时也应被类型筛选命中"),
		assert_false(pokemon_v.get_uid() in matched_uids, "ex 类型不应误命中宝可梦 V"),
	])


func test_pool_search_category_filter_keeps_non_pokemon_categories_independent() -> String:
	var editor: Control = DeckEditorScript.new()
	var pokemon := _make_card("SV1", "020", "超级球兽", "Pokemon")
	var item := _make_card("SV1", "021", "超级球", "Item")
	var supporter := _make_card("SV1", "022", "博士的研究", "Supporter")
	editor.set("_pool_by_category", [[pokemon], [supporter], [item], [], [], []] as Array[Array])
	editor.set("_pool_search_query", "超级球")
	editor.set("_pool_search_tag", "Ancient")
	editor.set("_pool_search_energy_type", "R")

	var pokemon_matches: Array = editor.call("_filtered_pool_cards", 0)
	var item_matches: Array = editor.call("_filtered_pool_cards", 2)
	var supporter_matches: Array = editor.call("_filtered_pool_cards", 1)
	return run_checks([
		assert_eq(pokemon_matches.size(), 0, "宝可梦分类应应用标签与属性条件"),
		assert_eq(item_matches.size(), 1, "物品分类只应用卡名条件，不应被宝可梦条件误伤"),
		assert_eq(supporter_matches.size(), 0, "分类结果应来自对应候选卡池"),
	])


func test_pool_search_overlay_exposes_all_filter_controls_and_responsive_metrics() -> String:
	var editor: Control = DeckEditorScript.new()
	editor.set("_pool_by_category", [[], [], [], [], [], []] as Array[Array])
	editor.call("_ensure_pool_search_overlay")
	var overlay := editor.get("_pool_search_overlay") as Panel
	var input := editor.get("_pool_search_input") as LineEdit
	var category_grid := editor.get("_pool_search_category_grid") as GridContainer
	var tag_grid := editor.get("_pool_search_tag_grid") as GridContainer
	var energy_grid := editor.get("_pool_search_energy_grid") as GridContainer
	var category_buttons := editor.get("_pool_search_category_buttons") as Array[Button]
	var tag_buttons := editor.get("_pool_search_tag_buttons") as Array[Button]
	var energy_buttons := editor.get("_pool_search_energy_buttons") as Array[Button]
	var desktop_metrics: Dictionary = editor.call("_pool_search_layout_metrics", Vector2(1280, 720))
	var mobile_metrics: Dictionary = editor.call("_pool_search_layout_metrics", Vector2(390, 844))
	var tag_ids: Array[String] = []
	for button: Button in tag_buttons:
		tag_ids.append(str(button.get_meta("pool_search_option_id", "")))
	var first_category := category_buttons[0] if not category_buttons.is_empty() else null
	var second_category := category_buttons[1] if category_buttons.size() > 1 else null
	var ex_radio := editor.find_child("DeckPoolSearchTagRadio_ex", true, false) as Button

	return run_checks([
		assert_not_null(overlay, "搜索入口应创建同页模态筛选层"),
		assert_not_null(input, "筛选层应包含卡牌名称搜索框"),
		assert_true(bool(input.get_meta(NonBattleTouchBridgeScript.NATIVE_TEXT_INPUT_META, false)) if input != null else false, "搜索框应使用 Web/Android 原生文本输入桥接"),
		assert_not_null(category_grid, "分类筛选应使用直接可见的 HUD radio 网格"),
		assert_not_null(tag_grid, "宝可梦类型筛选应使用直接可见的 HUD radio 网格"),
		assert_not_null(energy_grid, "属性筛选应使用直接可见的 HUD radio 网格"),
		assert_eq(category_buttons.size(), 6, "分类筛选应完整提供六个 radio 选项"),
		assert_true("ex" in tag_ids and "Tera" in tag_ids and "Ancient" in tag_ids and "Future" in tag_ids, "类型筛选应显式提供 ex、太晶、古代和未来"),
		assert_not_null(ex_radio, "ex 应是固定、可直接点击的 HUD radio"),
		assert_eq(energy_buttons.size(), 11, "属性筛选应提供全部选项与十种宝可梦属性"),
		assert_true(first_category != null and first_category.toggle_mode and first_category.button_group != null, "HUD radio 应保留互斥选择语义"),
		assert_true(first_category != null and second_category != null and first_category.button_group == second_category.button_group, "同组筛选项应共享 ButtonGroup"),
		assert_true(first_category != null and first_category.text.begins_with("◉ "), "当前筛选项应显示明确的选中圆点"),
		assert_true(second_category != null and second_category.text.begins_with("○ "), "未选筛选项应显示空心圆点"),
		assert_null(_find_descendant_by_class(overlay, "OptionButton"), "搜索筛选层不应再使用难以辨认的原生下拉列表"),
		assert_eq(float(desktop_metrics.get("box_width", 0.0)), 980.0, "桌面筛选层应为 radio 网格提供足够宽度"),
		assert_eq(int(desktop_metrics.get("category_columns", 0)), 6, "桌面端六个分类应一行展示"),
		assert_true(bool(mobile_metrics.get("compact", false)), "窄屏应启用紧凑筛选布局"),
		assert_true(float(mobile_metrics.get("box_width", 999.0)) <= 366.0, "移动端筛选层应保留左右安全边距"),
		assert_eq(int(mobile_metrics.get("category_columns", 0)), 2, "移动端分类 radio 应自动换成两列"),
		assert_eq(int(mobile_metrics.get("energy_columns", 0)), 3, "移动端属性 radio 应自动换成三列"),
	])


func test_catalog_pool_preserves_tera_marker_for_every_ex_pokemon() -> String:
	var editor: Control = DeckEditorScript.new()
	var ex_count := 0
	var tera_uids := PackedStringArray()
	var ex_cards: Array[CardData] = []
	var checks: Array[String] = []
	for entry: Dictionary in CardDatabase.search_catalog_cards("", {}, 0, 0):
		if str(entry.get("card_type", "")) != "Pokemon" \
				or str(entry.get("mechanic", "")).strip_edges().to_lower() != "ex":
			continue
		ex_count += 1
		var uid := str(entry.get("uid", ""))
		var card: CardData = editor.call("_card_from_catalog_entry", entry)
		if card != null:
			ex_cards.append(card)
		if str(entry.get("ancient_trait", "")) != "Tera":
			continue
		tera_uids.append(uid)
		checks.append(assert_true(
			card != null and bool(editor.call("_pool_card_matches_pokemon_tag", card, "Tera")),
			"%s should remain selectable through the Tera HUD radio" % uid
		))
	tera_uids.sort()
	checks.append(assert_true(ex_count >= 132, "The audit must cover the complete catalog of Pokemon ex"))
	checks.append(assert_eq(
		Array(tera_uids),
		EXPECTED_TERA_EX_UIDS,
		"Every Tera Pokemon ex in the catalog must keep its search marker"
	))
	editor.set("_pool_by_category", [ex_cards, [], [], [], [], []] as Array[Array])
	editor.set("_pool_search_tag", "Tera")
	editor.set("_pool_search_energy_type", "G")
	var grass_uids := PackedStringArray()
	for card: CardData in editor.call("_filtered_pool_cards", 0):
		grass_uids.append(card.get_uid())
	grass_uids.sort()
	editor.set("_pool_search_energy_type", "R")
	var fire_uids := PackedStringArray()
	for card: CardData in editor.call("_filtered_pool_cards", 0):
		fire_uids.append(card.get_uid())
	fire_uids.sort()
	checks.append(assert_eq(
		Array(grass_uids),
		["CSV8C_028", "CSV9.5C_006"],
		"Grass + Tera must include Teal Mask Ogerpon ex and Leafeon ex"
	))
	checks.append(assert_eq(
		Array(fire_uids),
		["CSV9.5C_023", "CSV9.5C_029", "CSV9C_034"],
		"Fire + Tera must include Flareon ex, Hearthflame Mask Ogerpon ex, and Ceruledge ex"
	))
	editor.free()
	return run_checks(checks)


func test_pool_search_defers_expensive_card_grid_render_while_radio_overlay_is_open() -> String:
	var editor: Control = DeckEditorScript.new()
	var overlay := Panel.new()
	overlay.visible = true
	editor.set("_pool_search_overlay", overlay)
	editor.set("_pool_by_category", [[], [], [], [], [], []] as Array[Array])
	editor.call("_apply_pool_search_filters")
	return run_checks([
		assert_true(bool(editor.call("_should_defer_pool_search_result_render")), "radio 面板打开时应延迟昂贵的卡池网格重建"),
		assert_true(bool(editor.get("_pool_search_results_dirty")), "选择 radio 后应记录待提交的搜索结果"),
	])


func test_deck_editor_has_view_card_button_above_replace_button() -> String:
	var editor: Control = DeckEditorScene.instantiate()
	var view_button := editor.get_node_or_null("%BtnViewCard") as Button
	var replace_button := editor.get_node_or_null("%BtnReplace") as Button
	var same_parent := view_button != null and replace_button != null and view_button.get_parent() == replace_button.get_parent()
	var view_index := view_button.get_index() if view_button != null else 999
	var replace_index := replace_button.get_index() if replace_button != null else -1
	editor.queue_free()

	return run_checks([
		assert_not_null(view_button, "Deck editor right action panel should expose a View Card button"),
		assert_not_null(replace_button, "Deck editor right action panel should still expose the Replace Card button"),
		assert_eq(view_button.text if view_button != null else "", "查看卡牌", "View Card button should use the requested Chinese label"),
		assert_true(same_parent, "View Card and Replace Card buttons should share the right action stack"),
		assert_true(view_index < replace_index, "View Card button should sit directly above Replace Card"),
	])


func test_deck_editor_scroll_nodes_are_unique_for_runtime_metrics() -> String:
	var editor: Control = DeckEditorScene.instantiate()
	var deck_scroll := editor.get_node_or_null("%DeckScroll") as ScrollContainer
	var pool_scroll := editor.get_node_or_null("%PoolScroll") as ScrollContainer
	editor.queue_free()

	return run_checks([
		assert_not_null(deck_scroll, "DeckEditor runtime sizing needs %DeckScroll to resolve"),
		assert_not_null(pool_scroll, "DeckEditor runtime sizing needs %PoolScroll to resolve"),
	])


func test_category_tab_buttons_use_hud_expand_layout() -> String:
	var editor: Control = DeckEditorScript.new()
	var tab_bar := HBoxContainer.new()
	var buttons: Array[Button] = []
	var pool_categories: Array[Array] = []
	for _i: int in 6:
		pool_categories.append([])
	editor.set("_pool_by_category", pool_categories)

	editor.call("_build_tab_bar", tab_bar, buttons, false)
	var first := buttons[0] if buttons.size() > 0 else null
	var normal_style := first.get_theme_stylebox("normal") if first != null else null
	var pressed_style := first.get_theme_stylebox("pressed") if first != null else null

	var result := run_checks([
		assert_eq(buttons.size(), 6, "Deck editor should create one expanding HUD tab per category"),
		assert_eq(tab_bar.custom_minimum_size.y, 54.0, "Category tab bar should be tall enough for HUD buttons"),
		assert_eq(tab_bar.get_theme_constant("separation"), 8, "Category tabs should use the larger HUD gap"),
		assert_not_null(first, "Category tab should be created"),
		assert_eq(first.custom_minimum_size.y if first != null else 0.0, 54.0, "Category tab buttons should be taller"),
		assert_eq(first.size_flags_horizontal if first != null else 0, Control.SIZE_EXPAND_FILL, "Category tab buttons should expand to fill the row"),
		assert_eq(first.get_theme_font_size("font_size") if first != null else 0, 18, "Category tab text should be larger"),
		assert_not_null(normal_style, "Category tab should have HUD normal styling"),
		assert_not_null(pressed_style, "Category tab should have HUD active styling"),
	])
	tab_bar.free()
	editor.free()
	return result


func test_card_tile_metrics_expand_for_five_column_grid() -> String:
	var editor: Control = DeckEditorScript.new()
	var scroll := ScrollContainer.new()
	scroll.size = Vector2(633, 500)
	var tile_size: Vector2 = editor.call("_calculate_card_tile_size", scroll)
	var grid_content_width := tile_size.x * 5.0 + 6.0 * 4.0
	scroll.free()
	editor.free()

	return run_checks([
		assert_gt(tile_size.x, 110.0, "Five-column deck editor tiles should grow beyond the old fixed 100px width when the panel is wider"),
		assert_gt(grid_content_width, 570.0, "Five-column grid should use the available panel width instead of leaving a fixed-size blank strip"),
		assert_eq(roundi(tile_size.y), roundi(tile_size.x * 1.4), "Tile image height should keep the card aspect ratio after resizing"),
	])


func test_deck_editor_defers_initial_pool_grid_refresh() -> String:
	var editor: Control = DeckEditorScript.new()
	var defer_initial := bool(editor.call("_should_defer_initial_pool_grid_refresh"))
	editor.free()

	return run_checks([
		assert_true(defer_initial, "DeckEditor should show its first frame before building the full right-side card pool"),
	])


func test_pool_card_tile_queues_deferred_texture_load() -> String:
	var editor: Control = DeckEditorScript.new()
	var tile := editor.call("_create_card_tile", "Deferred Pool Card", "SV1", "001", false, Vector2(100, 140), true) as PanelContainer
	var queue: Array = editor.get("_deferred_tile_texture_queue")
	var pump_active := bool(editor.get("_deferred_tile_texture_pump_active"))
	var texture_rect := _find_descendant_by_class(tile, "TextureRect") as TextureRect
	var uses_placeholder := texture_rect != null and texture_rect.texture is PlaceholderTexture2D

	tile.free()
	editor.free()
	return run_checks([
		assert_eq(queue.size(), 1, "Pool card tiles should queue image loading instead of synchronously reading card images"),
		assert_true(pump_active, "Deferred tile image pump should start after queueing the first pool tile image"),
		assert_true(uses_placeholder, "Pool card tile should render a placeholder until the deferred image load catches up"),
	])


func test_deck_editor_portrait_hides_scrollbars_and_keeps_touch_drag() -> String:
	var previous_emulate: bool = bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true))
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", false)
	var editor: Control = DeckEditorScript.new()
	editor.size = Vector2(390, 844)
	var deck_scroll := ScrollContainer.new()
	deck_scroll.name = "DeckScroll"
	deck_scroll.size = Vector2(633, 240)
	deck_scroll.custom_minimum_size = deck_scroll.size
	var content := Control.new()
	content.custom_minimum_size = Vector2(633, 1200)
	deck_scroll.add_child(content)
	editor.add_child(deck_scroll)
	editor.call("_apply_editor_scrollbar_policy", true)
	var vbar := deck_scroll.get_v_scroll_bar()
	if vbar != null:
		vbar.min_value = 0.0
		vbar.max_value = 1200.0
		vbar.page = 240.0
	var hidden_meta := bool(deck_scroll.get_meta(NonBattleTouchBridgeScript.HIDDEN_VERTICAL_DRAG_SCROLL_META, false))
	var hidden_bar := vbar != null and not vbar.visible and vbar.mouse_filter == Control.MOUSE_FILTER_IGNORE
	var tile_size: Vector2 = editor.call("_calculate_card_tile_size", deck_scroll)
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.pressed = true
	press.position = Vector2(24, 120)
	editor.call("_handle_editor_card_scroll_input", press, deck_scroll)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(24, 20)
	var drag_consumed := bool(editor.call("_handle_editor_card_scroll_input", drag, deck_scroll))
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.pressed = false
	release.position = Vector2(24, 20)
	var release_consumed := bool(editor.call("_handle_editor_card_scroll_input", release, deck_scroll))
	var scrolled := deck_scroll.scroll_vertical
	editor.free()
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", previous_emulate)

	return run_checks([
		assert_true(hidden_meta, "Portrait deck editor scroll containers should opt into hidden drag scrolling"),
		assert_true(hidden_bar, "Portrait deck editor vertical scrollbar should be visually hidden and non-interactive"),
		assert_gt(tile_size.x, 118.0, "Hidden portrait scrollbar should not reserve the old visible scrollbar clearance"),
		assert_true(drag_consumed, "Dragging a portrait deck editor card list should be consumed as scroll"),
		assert_true(release_consumed, "Releasing after a portrait drag scroll should be consumed"),
		assert_gt(scrolled, 0, "Portrait deck editor card list drag should change scroll_vertical"),
	])


func test_card_tile_children_pass_mouse_events_to_tile() -> String:
	var editor: Control = DeckEditorScript.new()
	var tile := editor.call("_create_card_tile", "右键详情测试", "SV1", "001", false) as PanelContainer
	var blocking_descendants := _count_blocking_descendant_controls(tile)

	return run_checks([
		assert_eq(tile.mouse_filter, Control.MOUSE_FILTER_STOP, "Card tile should receive mouse input on its outer panel"),
		assert_eq(blocking_descendants, 0, "Card tile image and labels should pass mouse input through so right-click detail works anywhere on the card"),
	])


func test_card_detail_uses_preview_overlay() -> String:
	var editor: Control = DeckEditorScript.new()
	var card := _make_card("SV1", "007", "Detail Test", "Pokemon")
	card.hp = 120
	card.energy_type = "R"
	card.stage = "Basic"
	card.attacks = [{"name": "Quick Strike", "cost": "R", "damage": "30", "text": "Deal 30 damage."}]

	editor.call("_show_card_detail", card)
	var overlay := editor.get("_card_detail_overlay") as Panel
	var box := editor.get("_card_detail_box") as PanelContainer
	var body := editor.get("_card_detail_body") as GridContainer
	var preview: Control = editor.get("_card_detail_card_view") as Control
	var content := editor.get("_card_detail_content") as RichTextLabel
	var title := editor.get("_card_detail_title") as Label
	var close_button := editor.get("_card_detail_close_btn") as Button

	return run_checks([
		assert_not_null(overlay, "Card detail should create an inline overlay"),
		assert_true(overlay != null and overlay.visible, "Card detail overlay should be visible"),
		assert_not_null(box, "Card detail should create a styled box"),
		assert_not_null(body, "Card detail should use a responsive body grid"),
		assert_not_null(preview, "Card detail should include the shared card preview"),
		assert_true(content != null and content.text.contains("Quick Strike"), "Card detail should render attack text"),
		assert_eq(title.get_theme_font_size("font_size") if title != null else 0, 40, "Deck editor card detail title text should be doubled for readability"),
		assert_eq(content.get_theme_font_size("normal_font_size") if content != null else 0, 28, "Deck editor card detail body text should be doubled for readability"),
		assert_eq(close_button.get_theme_font_size("font_size") if close_button != null else 0, 28, "Deck editor card detail close button text should be doubled for readability"),
	])


func test_view_card_button_opens_last_selected_card_detail() -> String:
	var editor: Control = DeckEditorScript.new()
	var card := _make_card("SV1", "009", "View Button Test", "Pokemon")
	card.hp = 90
	editor.set("_last_selected_card_payload", {"card": card})

	editor.call("_on_view_card_pressed")
	var overlay := editor.get("_card_detail_overlay") as Panel
	var title := editor.get("_card_detail_title") as Label

	return run_checks([
		assert_true(overlay != null and overlay.visible, "View Card button should reuse the right-click card detail overlay"),
		assert_eq(title.text if title != null else "", "View Button Test", "View Card should open the last selected card detail"),
	])


func test_card_detail_preview_marks_unimplemented_effect_card() -> String:
	var editor: Control = DeckEditorScript.new()
	var card := _make_card("UTEST", "101", "Missing Detail Effect", "Item")
	card.effect_id = "missing-detail-effect"
	card.description = "Search your deck for a card."

	editor.call("_show_card_detail", card)
	var preview: Control = editor.get("_card_detail_card_view") as Control
	var badge_panel := preview.get("_implementation_badge_panel") as Control if preview != null else null
	var badge_label := preview.get("_implementation_badge_label") as Label if preview != null else null

	return run_checks([
		assert_not_null(preview, "Card detail should include the shared preview card"),
		assert_true(badge_panel != null and badge_panel.visible, "Deck editor detail preview should mark unimplemented effect cards"),
		assert_true(badge_label != null and badge_label.text == "未实现", "Deck editor detail preview badge should use the HUD text"),
	])


func test_card_tile_marks_unimplemented_effect_card() -> String:
	var editor: Control = DeckEditorScript.new()
	var card := _make_card("UTEST", "102", "Missing Tile Effect", "Item")
	card.effect_id = "missing-tile-effect"
	card.description = "Draw cards."
	var holder := Control.new()

	var badge := editor.call("_add_unimplemented_tile_badge", holder, card) as PanelContainer
	var label := _find_descendant_by_name(badge, "UnimplementedBadgeLabel") as Label

	return run_checks([
		assert_not_null(badge, "Deck editor card tiles should add a badge for unimplemented effect cards"),
		assert_eq(badge.name, "UnimplementedBadge", "Tile badge should have a stable node name for tests and future styling"),
		assert_true(label != null and label.text == "未实现", "Tile badge should render the expected HUD text"),
	])


func test_tile_long_press_opens_detail_and_suppresses_click() -> String:
	var editor: Control = DeckEditorScript.new()
	var card := _make_card("SV1", "008", "Long Press Test", "Pokemon")
	card.hp = 80

	editor.call("_start_tile_long_press", {"card": card}, Vector2(8, 8), 0)
	editor.call("_on_tile_long_press_timeout")
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(80, 8)
	var drag_consumed := bool(editor.call("_handle_tile_touch_detail_input", drag, {"card": card}))
	var overlay := editor.get("_card_detail_overlay") as Panel
	var suppress_before := bool(editor.get("_suppress_next_tile_left_click"))
	var consumed := bool(editor.call("_consume_suppressed_tile_left_click"))
	var suppress_after := bool(editor.get("_suppress_next_tile_left_click"))

	return run_checks([
		assert_true(overlay != null and overlay.visible, "Long press should open card detail"),
		assert_true(drag_consumed, "Dragging after detail opens should remain consumed"),
		assert_true(suppress_before, "Long press should suppress the synthetic click"),
		assert_true(consumed, "Suppressed click should be consumed once"),
		assert_false(suppress_after, "Suppressed click flag should clear after consumption"),
	])


func test_tile_long_press_drag_cancel_prevents_detail() -> String:
	var editor: Control = DeckEditorScript.new()
	var card := _make_card("SV1", "009", "Drag Cancel Test", "Pokemon")
	card.hp = 90
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(80, 8)

	editor.call("_start_tile_long_press", {"card": card}, Vector2(8, 8), 0)
	editor.call("_handle_tile_touch_detail_input", drag, {"card": card})
	editor.call("_on_tile_long_press_timeout")
	var overlay := editor.get("_card_detail_overlay") as Panel
	var active := bool(editor.get("_tile_long_press_active"))

	return run_checks([
		assert_false(active, "Dragging beyond tolerance should cancel long press"),
		assert_true(overlay == null or not overlay.visible, "Canceled long press should not open detail"),
	])


# -- _flat_index_to_entry_index --

func test_flat_index_maps_to_correct_entry() -> String:
	var editor: Control = DeckEditorScript.new()
	editor.set("_deck", _make_deck())

	var idx0: int = editor.call("_flat_index_to_entry_index", 0)
	var idx1: int = editor.call("_flat_index_to_entry_index", 1)
	var idx2: int = editor.call("_flat_index_to_entry_index", 2)
	var idx3: int = editor.call("_flat_index_to_entry_index", 3)
	var idx_bad: int = editor.call("_flat_index_to_entry_index", 99)

	return run_checks([
		assert_eq(idx0, 0, "flat 0 应映射到条目 0（皮卡丘第1张）"),
		assert_eq(idx1, 0, "flat 1 应映射到条目 0（皮卡丘第2张）"),
		assert_eq(idx2, 1, "flat 2 应映射到条目 1（博士）"),
		assert_eq(idx3, 2, "flat 3 应映射到条目 2（雷能量）"),
		assert_eq(idx_bad, -1, "超界索引应返回 -1"),
	])


func test_deck_editor_requeues_battle_setup_return_context_when_leaving() -> String:
	_set_navigation_suppressed(true)
	var editor: Control = DeckEditorScript.new()
	editor.set("_return_context", {
		"return_scene": "battle_setup",
		"deck1_id": 101,
		"deck2_id": 202,
	})

	editor.call("_go_back_to_return_scene")
	var context: Dictionary = GameManager.call("consume_deck_editor_return_context")

	_set_navigation_suppressed(false)
	return run_checks([
		assert_eq(str(context.get("return_scene", "")), "battle_setup", "Leaving DeckEditor toward battle_setup should restore the same return scene context"),
		assert_eq(int(context.get("deck1_id", 0)), 101, "Leaving DeckEditor toward battle_setup should preserve deck1 selection"),
		assert_eq(int(context.get("deck2_id", 0)), 202, "Leaving DeckEditor toward battle_setup should preserve deck2 selection"),
	])


# -- _do_replace --

func test_replace_decrements_old_card_count() -> String:
	var editor: Control = DeckEditorScript.new()
	var deck := _make_deck()
	editor.set("_deck", deck)

	var new_card := _make_card("SV2", "010", "喷火龙", "Pokemon")
	editor.call("_do_replace", 0, new_card)

	var pikachu_count: int = deck.cards[0].get("count", 0)
	var pikachu_name: String = deck.cards[0].get("name", "")

	return run_checks([
		assert_eq(pikachu_count, 1, "替换后皮卡丘数量应减为 1"),
		assert_eq(pikachu_name, "皮卡丘", "条目 0 仍应是皮卡丘"),
		assert_eq(deck.total_cards, 4, "总数应不变（一进一出）"),
	])


func test_replace_removes_entry_when_count_reaches_zero() -> String:
	var editor: Control = DeckEditorScript.new()
	var deck := _make_deck()
	editor.set("_deck", deck)

	var new_card := _make_card("SV2", "010", "喷火龙", "Pokemon")
	# 替换博士（count=1），应被移除
	editor.call("_do_replace", 1, new_card)

	var has_professor := false
	for entry: Dictionary in deck.cards:
		if entry.get("name", "") == "博士":
			has_professor = true
			break

	return run_checks([
		assert_false(has_professor, "博士 count=1 被替换后应从列表中移除"),
		assert_eq(deck.total_cards, 4, "总数应不变"),
	])


func test_replace_increments_existing_target() -> String:
	var editor: Control = DeckEditorScript.new()
	var deck := _make_deck()
	editor.set("_deck", deck)

	# 用已存在的皮卡丘替换博士
	var pikachu := _make_card("SV1", "001", "皮卡丘", "Pokemon")
	editor.call("_do_replace", 1, pikachu)

	var pikachu_count := 0
	for entry: Dictionary in deck.cards:
		if entry.get("name", "") == "皮卡丘":
			pikachu_count = entry.get("count", 0)
			break

	return run_checks([
		assert_eq(pikachu_count, 3, "皮卡丘替换入后应为 3 张"),
		assert_eq(deck.total_cards, 4, "总数应不变"),
	])


func test_replace_adds_new_entry_for_unknown_card() -> String:
	var editor: Control = DeckEditorScript.new()
	var deck := _make_deck()
	editor.set("_deck", deck)

	var charizard := _make_card("SV2", "010", "喷火龙ex", "Pokemon")
	editor.call("_do_replace", 0, charizard)

	var found_charizard := false
	for entry: Dictionary in deck.cards:
		if entry.get("name", "") == "喷火龙ex":
			found_charizard = true
			break

	return run_checks([
		assert_true(found_charizard, "新卡喷火龙ex 应出现在卡组中"),
		assert_eq(deck.total_cards, 4, "总数应不变"),
	])


func test_replace_sets_dirty_flag() -> String:
	var editor: Control = DeckEditorScript.new()
	var deck := _make_deck()
	editor.set("_deck", deck)

	var before: bool = editor.get("_dirty")
	var new_card := _make_card("SV2", "010", "喷火龙", "Pokemon")
	editor.call("_do_replace", 0, new_card)
	var after: bool = editor.get("_dirty")

	return run_checks([
		assert_false(before, "初始 dirty 应为 false"),
		assert_true(after, "替换后 dirty 应为 true"),
	])


# -- _category_for_type --

func test_category_for_type_maps_correctly() -> String:
	var editor: Control = DeckEditorScript.new()

	var pokemon: int = editor.call("_category_for_type", "Pokemon")
	var supporter: int = editor.call("_category_for_type", "Supporter")
	var item: int = editor.call("_category_for_type", "Item")
	var tool_cat: int = editor.call("_category_for_type", "Tool")
	var stadium: int = editor.call("_category_for_type", "Stadium")
	var basic_energy: int = editor.call("_category_for_type", "Basic Energy")
	var special_energy: int = editor.call("_category_for_type", "Special Energy")

	return run_checks([
		assert_eq(pokemon, 0, "Pokemon 应对应分类 0"),
		assert_eq(supporter, 1, "Supporter 应对应分类 1"),
		assert_eq(item, 2, "Item 应对应分类 2"),
		assert_eq(tool_cat, 3, "Tool 应对应分类 3"),
		assert_eq(stadium, 4, "Stadium 应对应分类 4"),
		assert_eq(basic_energy, 5, "Basic Energy 应对应分类 5"),
		assert_eq(special_energy, 5, "Special Energy 应对应分类 5"),
	])


# -- _build_deck_categories --

func test_build_deck_categories_groups_by_type() -> String:
	var editor: Control = DeckEditorScript.new()
	var deck := _make_deck()
	editor.set("_deck", deck)
	editor.call("_build_deck_categories")

	var deck_by_cat: Array[Array] = editor.get("_deck_by_category")
	var pokemon_count := deck_by_cat[0].size()  # 宝可梦：皮卡丘 ×2 = 2 个 flat 条目
	var supporter_count := deck_by_cat[1].size()  # 支援者：博士 ×1 = 1
	var energy_count := deck_by_cat[5].size()  # 能量：雷能量 ×1 = 1
	var item_count := deck_by_cat[2].size()  # 物品：0

	return run_checks([
		assert_eq(pokemon_count, 2, "宝可梦分类应有 2 个 flat 条目（皮卡丘 ×2）"),
		assert_eq(supporter_count, 1, "支援者分类应有 1 个 flat 条目（博士 ×1）"),
		assert_eq(energy_count, 1, "能量分类应有 1 个 flat 条目（雷能量 ×1）"),
		assert_eq(item_count, 0, "物品分类应为空"),
	])


# -- _is_excluded_card --

func test_utest_cards_are_excluded() -> String:
	var editor: Control = DeckEditorScript.new()
	var utest := _make_card("UTEST", "001", "Dynamic Registration", "Pokemon")
	var real := _make_card("CSV1C", "050", "皮卡丘", "Pokemon")

	var excluded_utest: bool = editor.call("_is_excluded_card", utest)
	var excluded_real: bool = editor.call("_is_excluded_card", real)

	return run_checks([
		assert_true(excluded_utest, "UTEST 系列卡牌应被排除"),
		assert_false(excluded_real, "正常卡牌不应被排除"),
	])


func test_build_pool_includes_bundled_powerglass_in_tool_category() -> String:
	var editor: Control = DeckEditorScript.new()
	editor.call("_build_pool")
	var pool_by_category: Array = editor.get("_pool_by_category")
	var tool_cards: Array = pool_by_category[3] if pool_by_category.size() > 3 else []
	var found: CardData = null
	for card: CardData in tool_cards:
		if card.get_uid() == "CSV8C_188":
			found = card
			break
	var checks: Array[String] = [
		assert_not_null(found, "DeckEditor Tool tab should include bundle-only CSV8C_188"),
	]
	if found != null:
		checks.append(assert_eq(str(found.name_en), "Powerglass", "DeckEditor should keep Powerglass metadata in the Tool pool"))
		checks.append(assert_eq(str(found.card_type), "Tool", "Powerglass should be listed under the Tool tab"))
	editor.free()
	return run_checks(checks)


func test_build_pool_includes_bundled_black_belts_training_in_supporter_category() -> String:
	var editor: Control = DeckEditorScript.new()
	editor.call("_build_pool")
	var pool_by_category: Array = editor.get("_pool_by_category")
	var supporter_cards: Array = pool_by_category[1] if pool_by_category.size() > 1 else []
	var found_black_belt: CardData = null
	var found_morty: CardData = null
	for card: CardData in supporter_cards:
		if card.get_uid() == "CSV9.5C_188":
			found_black_belt = card
		elif card.get_uid() == "CSV9.5C_199":
			found_morty = card
	var checks: Array[String] = [
		assert_not_null(found_black_belt, "DeckEditor Supporter tab should include bundle-only CSV9.5C_188"),
		assert_not_null(found_morty, "DeckEditor Supporter tab should include bundle-only CSV9.5C_199"),
	]
	if found_black_belt != null:
		checks.append(assert_eq(str(found_black_belt.name_en), "Black Belt's Training", "DeckEditor should keep Black Belt's Training metadata in the Supporter pool"))
		checks.append(assert_eq(str(found_black_belt.card_type), "Supporter", "Black Belt's Training should be listed under the Supporter tab"))
	if found_morty != null:
		checks.append(assert_eq(str(found_morty.name_en), "Morty's Conviction", "DeckEditor should keep Morty's Conviction metadata in the Supporter pool"))
		checks.append(assert_eq(str(found_morty.card_type), "Supporter", "Morty's Conviction should be listed under the Supporter tab"))
		checks.append(assert_eq(str(found_morty.effect_id), "0d2ca8f42fe1500644bc1bd21c89eeb1", "Morty's Conviction should keep its implemented effect id"))
	editor.free()
	return run_checks(checks)


func test_build_pool_includes_bundled_love_ball_in_item_category() -> String:
	var editor: Control = DeckEditorScript.new()
	editor.call("_build_pool")
	var pool_by_category: Array = editor.get("_pool_by_category")
	var item_cards: Array = pool_by_category[2] if pool_by_category.size() > 2 else []
	var found: CardData = null
	for card: CardData in item_cards:
		if card.get_uid() == "CSV7C_182":
			found = card
			break
	var checks: Array[String] = [
		assert_not_null(found, "DeckEditor Item tab should include bundle-only CSV7C_182"),
	]
	if found != null:
		checks.append(assert_eq(str(found.name_en), "Love Ball", "DeckEditor should keep Love Ball metadata in the Item pool"))
		checks.append(assert_eq(str(found.card_type), "Item", "Love Ball should be listed under the Item tab"))
	editor.free()
	return run_checks(checks)


func test_build_pool_includes_bundled_scramble_switch_in_item_category() -> String:
	var editor: Control = DeckEditorScript.new()
	editor.call("_build_pool")
	var pool_by_category: Array = editor.get("_pool_by_category")
	var item_cards: Array = pool_by_category[2] if pool_by_category.size() > 2 else []
	var found: CardData = null
	for card: CardData in item_cards:
		if card.get_uid() == "CSV9C_180":
			found = card
			break
	var checks: Array[String] = [
		assert_not_null(found, "DeckEditor Item tab should include bundle-only CSV9C_180"),
	]
	if found != null:
		checks.append(assert_eq(str(found.name_en), "Scramble Switch", "DeckEditor should keep Scramble Switch metadata in the Item pool"))
		checks.append(assert_eq(str(found.card_type), "Item", "Scramble Switch should be listed under the Item tab"))
		checks.append(assert_eq(str(found.effect_id), "1da701b43813d6ddb1238e54bce95811", "Scramble Switch should keep its implemented effect id"))
	editor.free()
	return run_checks(checks)


func test_build_pool_includes_bundled_lacey_in_supporter_category() -> String:
	var editor: Control = DeckEditorScript.new()
	editor.call("_build_pool")
	var pool_by_category: Array = editor.get("_pool_by_category")
	var supporter_cards: Array = pool_by_category[1] if pool_by_category.size() > 1 else []
	var found: CardData = null
	for card: CardData in supporter_cards:
		if card.get_uid() == "CSV9C_200":
			found = card
			break
	var checks: Array[String] = [
		assert_not_null(found, "DeckEditor Supporter tab should include bundle-only CSV9C_200"),
	]
	if found != null:
		checks.append(assert_eq(str(found.name), "紫竽", "DeckEditor should keep Lacey's Chinese name"))
		checks.append(assert_eq(str(found.name_en), "Lacey", "DeckEditor should keep Lacey's English name"))
		checks.append(assert_eq(str(found.card_type), "Supporter", "Lacey should be listed under the Supporter tab"))
		checks.append(assert_eq(str(found.effect_id), "a3c4d099d726c7dfa4393e7e218661db", "Lacey should keep its implemented effect id"))
	editor.free()
	return run_checks(checks)


func test_build_pool_includes_2026_08_01_tinkaton_and_sinistcha_cards() -> String:
	var editor: Control = DeckEditorScript.new()
	editor.call("_build_pool")
	var pool_by_category: Array = editor.get("_pool_by_category")
	var pokemon_cards: Array = pool_by_category[0] if pool_by_category.size() > 0 else []
	var expected_uids := [
		"CSV1C_068", "CSV1C_067", "CSV6C_063", "SVP_159",
		"CSV6C_062", "CSV9.5C_019", "CSVH5C_002", "CSVNC_008",
	]
	var found: Dictionary = {}
	for card: CardData in pokemon_cards:
		if card != null and card.get_uid() in expected_uids:
			found[card.get_uid()] = card
	var checks: Array[String] = []
	for uid: String in expected_uids:
		checks.append(assert_true(found.has(uid), "DeckEditor Pokemon tab should include %s" % uid))
	if found.has("CSV1C_068"):
		checks.append(assert_eq((found["CSV1C_068"] as CardData).mechanic, "ex", "Tinkaton ex should keep the ex mechanic in the pool"))
	if found.has("CSVNC_008"):
		checks.append(assert_eq((found["CSVNC_008"] as CardData).stage, "Stage 1", "Sinistcha ex should remain a Stage 1 Pokemon in the pool"))
	editor.free()
	return run_checks(checks)


func test_build_pool_includes_requested_bundled_pokemon_cards() -> String:
	var editor: Control = DeckEditorScript.new()
	editor.call("_build_pool")
	var pool_by_category: Array = editor.get("_pool_by_category")
	var pokemon_cards: Array = pool_by_category[0] if pool_by_category.size() > 0 else []
	var found_slowpoke: CardData = null
	var found_iron_valiant: CardData = null
	var found_umbreon: CardData = null
	var found_annihilape: CardData = null
	var found_arctibax: CardData = null
	var found_snorunt: CardData = null
	var found_froslass: CardData = null
	var found_tatsugiri_ex: CardData = null
	var found_incineroar_ex: CardData = null
	var found_zubat: CardData = null
	for card: CardData in pokemon_cards:
		if card.get_uid() == "CSV9.5C_031":
			found_slowpoke = card
		elif card.get_uid() == "CSV9.5C_081":
			found_iron_valiant = card
		elif card.get_uid() == "CSV9.5C_104":
			found_umbreon = card
		elif card.get_uid() == "CSV9C_099":
			found_annihilape = card
		elif card.get_uid() == "CSVE2C_045":
			found_arctibax = card
		elif card.get_uid() == "CSV9.5C_043":
			found_snorunt = card
		elif card.get_uid() == "CSV7C_059":
			found_froslass = card
		elif card.get_uid() == "CSV9C_152":
			found_tatsugiri_ex = card
		elif card.get_uid() == "CSV7C_047":
			found_incineroar_ex = card
		elif card.get_uid() == "CSV8C_122":
			found_zubat = card
	var checks: Array[String] = [
		assert_not_null(found_slowpoke, "DeckEditor Pokemon tab should include bundle-only CSV9.5C_031"),
		assert_not_null(found_iron_valiant, "DeckEditor Pokemon tab should include bundle-only CSV9.5C_081"),
		assert_not_null(found_umbreon, "DeckEditor Pokemon tab should include bundle-only CSV9.5C_104"),
		assert_not_null(found_annihilape, "DeckEditor Pokemon tab should include CSV9C_099"),
		assert_not_null(found_arctibax, "DeckEditor Pokemon tab should include bundle-only CSVE2C_045"),
		assert_not_null(found_snorunt, "DeckEditor Pokemon tab should include bundle-only CSV9.5C_043"),
		assert_not_null(found_froslass, "DeckEditor Pokemon tab should include bundle-only CSV7C_059"),
		assert_not_null(found_tatsugiri_ex, "DeckEditor Pokemon tab should include bundle-only CSV9C_152"),
		assert_not_null(found_incineroar_ex, "DeckEditor Pokemon tab should include bundle-only CSV7C_047"),
		assert_not_null(found_zubat, "DeckEditor Pokemon tab should include bundle-only CSV8C_122"),
	]
	if found_slowpoke != null:
		checks.append(assert_eq(str(found_slowpoke.card_type), "Pokemon", "CSV9.5C_031 should be listed under the Pokemon tab"))
		checks.append(assert_eq(str(found_slowpoke.energy_type), "W", "CSV9.5C_031 should keep Water typing in the Pokemon pool"))
		checks.append(assert_eq(str(found_slowpoke.stage), "Basic", "CSV9.5C_031 should keep Basic stage in the Pokemon pool"))
	if found_iron_valiant != null:
		checks.append(assert_eq(str(found_iron_valiant.card_type), "Pokemon", "CSV9.5C_081 should be listed under the Pokemon tab"))
		checks.append(assert_eq(str(found_iron_valiant.energy_type), "P", "CSV9.5C_081 should keep Psychic typing in the Pokemon pool"))
		checks.append(assert_eq(str(found_iron_valiant.stage), "Basic", "CSV9.5C_081 should keep Basic stage in the Pokemon pool"))
		checks.append(assert_true(found_iron_valiant.is_future_pokemon(), "CSV9.5C_081 should keep the Future tag in the Pokemon pool"))
		checks.append(assert_eq(str(found_iron_valiant.effect_id), "b417ad06ad8e4aa783b35fe1f3f27010", "CSV9.5C_081 should keep its implemented effect id"))
	if found_umbreon != null:
		checks.append(assert_eq(str(found_umbreon.card_type), "Pokemon", "CSV9.5C_104 should be listed under the Pokemon tab"))
		checks.append(assert_eq(str(found_umbreon.energy_type), "D", "CSV9.5C_104 should keep Darkness typing in the Pokemon pool"))
		checks.append(assert_eq(str(found_umbreon.stage), "Stage 1", "CSV9.5C_104 should keep Stage 1 in the Pokemon pool"))
		checks.append(assert_eq(str(found_umbreon.effect_id), "233350ffecdbfac2a8fab27e7f7da282", "CSV9.5C_104 should keep its implemented effect id"))
	if found_annihilape != null:
		checks.append(assert_eq(str(found_annihilape.card_type), "Pokemon", "CSV9C_099 should be listed under the Pokemon tab"))
		checks.append(assert_eq(str(found_annihilape.energy_type), "F", "CSV9C_099 should keep Fighting typing in the Pokemon pool"))
		checks.append(assert_eq(str(found_annihilape.stage), "Stage 2", "CSV9C_099 should keep Stage 2 in the Pokemon pool"))
	if found_arctibax != null:
		checks.append(assert_eq(str(found_arctibax.card_type), "Pokemon", "CSVE2C_045 should be listed under the Pokemon tab"))
		checks.append(assert_eq(str(found_arctibax.energy_type), "W", "CSVE2C_045 should keep Water typing in the Pokemon pool"))
		checks.append(assert_eq(str(found_arctibax.stage), "Stage 1", "CSVE2C_045 should keep Stage 1 in the Pokemon pool"))
		checks.append(assert_eq(str(found_arctibax.name_en), "Arctibax", "CSVE2C_045 should keep source English name"))
	if found_snorunt != null:
		checks.append(assert_eq(str(found_snorunt.energy_type), "W", "CSV9.5C_043 should keep Water typing in the Pokemon pool"))
		checks.append(assert_eq(str(found_snorunt.stage), "Basic", "CSV9.5C_043 should keep Basic stage in the Pokemon pool"))
		checks.append(assert_eq(str(found_snorunt.effect_id), "f6baf0c4c60ff47c7f836c1271f40cb3", "CSV9.5C_043 should keep its implemented effect id"))
	if found_froslass != null:
		checks.append(assert_eq(str(found_froslass.energy_type), "W", "CSV7C_059 should keep Water typing in the Pokemon pool"))
		checks.append(assert_eq(str(found_froslass.stage), "Stage 1", "CSV7C_059 should keep Stage 1 in the Pokemon pool"))
		checks.append(assert_eq(str(found_froslass.effect_id), "f27a2982c03f5b49a68ec0a77a2d6e48", "CSV7C_059 should keep its implemented effect id"))
	if found_tatsugiri_ex != null:
		checks.append(assert_eq(str(found_tatsugiri_ex.energy_type), "N", "CSV9C_152 should keep Dragon typing in the Pokemon pool"))
		checks.append(assert_eq(str(found_tatsugiri_ex.stage), "Basic", "CSV9C_152 should keep Basic stage in the Pokemon pool"))
		checks.append(assert_eq(str(found_tatsugiri_ex.effect_id), "b1bef15b71f5b719d49ad7376b879a60", "CSV9C_152 should keep its implemented effect id"))
	if found_incineroar_ex != null:
		checks.append(assert_eq(str(found_incineroar_ex.energy_type), "R", "CSV7C_047 should keep Fire typing in the Pokemon pool"))
		checks.append(assert_eq(str(found_incineroar_ex.stage), "Stage 2", "CSV7C_047 should keep Stage 2 in the Pokemon pool"))
		checks.append(assert_eq(str(found_incineroar_ex.effect_id), "9a665c4cff5995deffdc83139ca9b39f", "CSV7C_047 should keep its implemented effect id"))
	if found_zubat != null:
		checks.append(assert_eq(str(found_zubat.energy_type), "D", "CSV8C_122 should keep Darkness typing in the Pokemon pool"))
		checks.append(assert_eq(str(found_zubat.stage), "Basic", "CSV8C_122 should keep Basic stage in the Pokemon pool"))
		checks.append(assert_eq(str(found_zubat.effect_id), "bd712c72418b762b995cf1acd175c688", "CSV8C_122 should keep its implemented effect id"))
	editor.free()
	return run_checks(checks)


func test_build_pool_includes_csv5c_073_and_csv9c_110_pokemon() -> String:
	var editor: Control = DeckEditorScript.new()
	editor.call("_build_pool")
	var pool_by_category: Array = editor.get("_pool_by_category")
	var pokemon_cards: Array = pool_by_category[0] if pool_by_category.size() > 0 else []
	var found_glimmora: CardData = null
	var found_glimmet: CardData = null
	for card: CardData in pokemon_cards:
		if card.get_uid() == "CSV5C_073":
			found_glimmora = card
		elif card.get_uid() == "CSV9C_110":
			found_glimmet = card
	var checks: Array[String] = [
		assert_not_null(found_glimmora, "DeckEditor Pokemon tab should include bundled CSV5C_073"),
		assert_not_null(found_glimmet, "DeckEditor Pokemon tab should include bundled CSV9C_110"),
	]
	if found_glimmora != null:
		checks.append(assert_eq(found_glimmora.name_en, "Glimmora ex", "DeckEditor should keep CSV5C_073 metadata"))
	if found_glimmet != null:
		checks.append(assert_eq(found_glimmet.name_en, "Glimmet", "DeckEditor should keep CSV9C_110 metadata"))
	editor.free()
	return run_checks(checks)


func test_build_pool_includes_tcg_mik_csv8c050_csv95c034_036_205_csv6c112_batch() -> String:
	var editor: Control = DeckEditorScript.new()
	editor.call("_build_pool")
	var pool_by_category: Array = editor.get("_pool_by_category")
	var expected_categories := {
		"CSV8C_050": 0,
		"CSV9.5C_034": 0,
		"CSV9.5C_036": 0,
		"CSV6C_112": 0,
		"CSV9.5C_205": 4,
	}
	var checks: Array[String] = []
	for uid: String in expected_categories:
		var category_index := int(expected_categories[uid])
		var category_cards: Array = pool_by_category[category_index] if category_index < pool_by_category.size() else []
		var found: CardData = null
		for card: CardData in category_cards:
			if card.get_uid() == uid:
				found = card
				break
		checks.append(assert_not_null(found, "DeckEditor should expose %s in category %d" % [uid, category_index]))
	editor.free()
	return run_checks(checks)


# -- _ordered_pokemon_cards --

func test_ordered_pokemon_cards_groups_by_energy() -> String:
	var editor: Control = DeckEditorScript.new()

	var fire1 := _make_card("SV1", "001", "小火龙", "Pokemon")
	fire1.energy_type = "R"
	var water1 := _make_card("SV1", "002", "杰尼龟", "Pokemon")
	water1.energy_type = "W"
	var fire2 := _make_card("SV1", "003", "火恐龙", "Pokemon")
	fire2.energy_type = "R"

	var cards: Array = [fire1, water1, fire2]
	var ordered: Array = editor.call("_ordered_pokemon_cards", cards)

	# 火(R) 排在 水(W) 前面
	return run_checks([
		assert_eq((ordered[0] as CardData).name, "小火龙", "第一个应是火属性卡"),
		assert_eq((ordered[1] as CardData).name, "火恐龙", "第二个应是火属性卡"),
		assert_eq((ordered[2] as CardData).name, "杰尼龟", "第三个应是水属性卡"),
	])


# -- AI prompt/payload --

func test_build_ai_system_prompt_contains_key_instructions() -> String:
	var editor: Control = DeckEditorScript.new()
	var prompt: String = editor.call("_build_ai_system_prompt")

	return run_checks([
		assert_true(prompt.contains("PTCG"), "系统提示应包含 PTCG"),
		assert_true(prompt.contains("max_changes"), "系统提示应提及 max_changes 约束"),
		assert_true(prompt.contains("available_pool"), "系统提示应提及可选卡池"),
		assert_true(prompt.contains("ACE SPEC"), "系统提示应提及 ACE SPEC 规则"),
		assert_true(prompt.contains("replacements"), "系统提示应要求 JSON replacements 格式"),
	])


func test_build_ai_user_data_structure() -> String:
	var editor: Control = DeckEditorScript.new()
	var deck := _make_deck()
	editor.set("_deck", deck)
	# 需要初始化 _pool_by_category 以便构建 available_pool
	editor.set("_pool_by_category", [[], [], [], [], [], []] as Array[Array])

	var target := DeckData.new()
	target.deck_name = "对手"
	target.cards = [{"name": "X", "card_type": "Pokemon", "count": 1}]
	var targets: Array[DeckData] = [target]
	var goals: Array[String] = ["damage"]

	var data: Dictionary = editor.call("_build_ai_user_data", targets, goals)

	var current: Dictionary = data.get("current_deck", {})
	var target_arr: Array = data.get("target_decks", [])
	var goal_arr: Array = data.get("optimization_goals", [])

	return run_checks([
		assert_eq(str(current.get("deck_name", "")), "测试卡组", "应包含当前卡组名"),
		assert_eq(int(current.get("total_cards", 0)), 4, "应包含正确总数"),
		assert_eq(target_arr.size(), 1, "应有 1 个针对卡组"),
		assert_eq(str(target_arr[0].get("deck_name", "")), "对手", "针对卡组名正确"),
		assert_eq(goal_arr.size(), 1, "应有 1 个优化方向"),
		assert_eq(int(data.get("max_changes", 0)), 8, "应包含 max_changes"),
		assert_true(data.has("available_pool"), "应包含可选卡池"),
	])


# -- GameManager deck editor navigation --

func test_deck_editor_id_is_one_shot() -> String:
	var gm_script: GDScript = load("res://scripts/autoload/GameManager.gd")
	var manager: Node = gm_script.new()

	manager.set("_deck_editor_deck_id", 42)
	var first: int = manager.call("consume_deck_editor_id")
	var second: int = manager.call("consume_deck_editor_id")

	return run_checks([
		assert_eq(first, 42, "首次 consume 应返回设置的 ID"),
		assert_eq(second, -1, "二次 consume 应返回 -1（已消费）"),
	])
