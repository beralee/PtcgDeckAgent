extends RefCounted
## A visual source/field-target projection of one canonical EVOLVE window.
## Card names, artwork and display order never become selection authority.

const ATTRIBUTE_NAMES := {"R": "火", "W": "水", "G": "草", "L": "雷", "P": "超", "F": "斗", "D": "恶", "M": "钢", "N": "龙", "C": "无"}


static func is_evolution_choice(item: Variant) -> bool:
	if not item is Dictionary or str(item.get("kind", "")) != "evolve":
		return false
	var card: Variant = item.get("card")
	var slot: Variant = item.get("target_slot")
	return card is CardInstance and card.card_data != null and slot is PokemonSlot and slot.get_card_data() != null


static func all_evolution_choices(items: Array) -> bool:
	if items.is_empty():
		return false
	for item: Variant in items:
		if not is_evolution_choice(item):
			return false
	return true


static func target_location(scene: Object, slot: PokemonSlot) -> String:
	var gsm: GameStateMachine = scene.get("_gsm")
	if gsm != null and gsm.game_state != null:
		for player: PlayerState in gsm.game_state.players:
			if player.active_pokemon == slot:
				return "战斗场"
			var index := player.bench.find(slot)
			if index >= 0:
				return "备战区 %d" % (index + 1)
	return "场上目标"


static func printing(data: CardData) -> String:
	var set_code := data.source_set_code if data.source_set_code != "" else data.set_code
	var card_index := data.source_card_index if data.source_card_index != "" else data.card_index
	return "%s / %s" % [set_code, card_index] if set_code != "" and card_index != "" else data.get_uid()


static func attribute(data: CardData) -> String:
	return str(ATTRIBUTE_NAMES.get(data.energy_type, data.energy_type))


static func field_step(scene: Object, step: Dictionary) -> Dictionary:
	var sources: Array = []
	var targets: Array = []
	var labels: Array[String] = []
	var target_labels: Array[String] = []
	var items: Array = step.get("items", [])
	for item: Dictionary in items:
		if item.card not in sources:
			sources.append(item.card)
			var data: CardData = item.card.card_data
			labels.append("%s · %s" % [data.display_name(), attribute(data)])
		if item.target_slot not in targets:
			targets.append(item.target_slot)
			target_labels.append(target_location(scene, item.target_slot))
	var excluded: Dictionary = {}
	for source_index: int in sources.size():
		var excluded_targets: Array = []
		for target_index: int in targets.size():
			if option_index(items, sources[source_index], targets[target_index]) < 0:
				excluded_targets.append(target_index)
		excluded[source_index] = excluded_targets
	return {
		"id": step.get("id", ""),
		"title": "选择进化卡",
		"ui_mode": "card_assignment",
		"evolution_frontier": true,
		"source_items": sources,
		"source_labels": labels,
		"target_items": targets,
		"target_labels": target_labels,
		"source_exclude_targets": excluded,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": step.get("allow_cancel", true),
		"compact_field_assignment_after_source": true,
		"field_assignment_require_confirm": true,
		"compact_field_assignment_title": "选择进化目标",
		"interaction_generation": int(scene.get_meta("pending_effect_interaction_generation", 0)),
		"interaction_step_index": int(scene.get("_pending_effect_step_index")),
		"interaction_step_id": str(step.get("id", "step_%d" % int(scene.get("_pending_effect_step_index")))),
	}


static func option_index(items: Array, source: Variant, target: Variant) -> int:
	for index: int in items.size():
		var item: Variant = items[index]
		if is_evolution_choice(item) and item.card == source and item.target_slot == target:
			return index
	return -1


static func configure_source(view: BattleCardView, card: CardInstance) -> void:
	view.set_badges()
	view.set_selectable_hint_text("%s系" % attribute(card.card_data))
	view.set_info(card.card_data.display_name(), printing(card.card_data))
	view.resized.connect(resize_source.bind(view))
	resize_source(view)


static func resize_source(view: BattleCardView) -> void:
	# Portrait uses a large logical canvas scaled down to the phone. Scale these
	# three short captions with card width, not the shared 9/11/12 px defaults.
	for spec: Array in [["_selection_badge", 0.15, 16], ["_title_label", 0.105, 11], ["_subtitle_label", 0.085, 9]]:
		var label := view.get(str(spec[0])) as Label
		label.add_theme_font_size_override("font_size", clampi(roundi(view.size.x * float(spec[1])), int(spec[2]), 52))


static func refresh_field_state(scene: Object, data: Dictionary) -> void:
	var selected_source := int(scene.get("_field_interaction_assignment_selected_source_index"))
	var entries: Array = scene.get("_field_interaction_assignment_entries")
	var targets: Array = data.get("target_items", [])
	var index_by_id: Dictionary = {}
	if selected_source >= 0:
		var exclusions: Dictionary = data.get("source_exclude_targets", {})
		var excluded: Array = exclusions.get(selected_source, [])
		for index: int in targets.size():
			if index not in excluded:
				var slot_id := str(scene.call("_slot_id_from_slot", targets[index]))
				if slot_id != "":
					index_by_id[slot_id] = index
	elif not entries.is_empty():
		var entry: Dictionary = entries[0]
		index_by_id[str(scene.call("_slot_id_from_slot", entry.target))] = int(entry.target_index)
	scene.set("_field_interaction_slot_index_by_id", index_by_id)
	var title: Label = scene.get("_field_interaction_title_lbl")
	var status: Label = scene.get("_field_interaction_status_lbl")
	var confirm: Button = scene.get("_field_interaction_confirm_btn")
	var clear: Button = scene.get("_field_interaction_clear_btn")
	clear.text = "重选"
	confirm.text = "确认进化"
	confirm.visible = not entries.is_empty()
	status.text = "点击卡牌选择 · 长按查看详情"
	if selected_source >= 0:
		title.text = "选择进化目标"
		status.text = "%s → 点击高亮宝可梦" % data.source_labels[selected_source]
	elif not entries.is_empty():
		title.text = "确认进化"
		var entry: Dictionary = entries[0]
		status.text = "%s → %s" % [data.source_labels[int(entry.source_index)], data.target_labels[int(entry.target_index)]]
