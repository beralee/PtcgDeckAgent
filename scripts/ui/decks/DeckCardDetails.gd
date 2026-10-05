extends RefCounted
## Shared card reader, readable and scrollable in either orientation.
const UI := preload("res://scripts/ui/decks/DeckCenterTheme.gd")
const CardProxy := preload("res://scripts/ui/cards/CardImageOrProxyView.gd")
const ENERGY_NAMES := {"R": "火", "W": "水", "G": "草", "L": "雷", "P": "超", "F": "斗", "D": "恶", "M": "钢", "N": "龙", "C": "无色"}

static func show_card(host: Control, card: CardData) -> void:
	if card == null:
		return
	var existing := host.get_node_or_null("DeckWorkspaceCardReader")
	if existing != null:
		existing.queue_free()
	var panel := PanelContainer.new()
	panel.name = "DeckWorkspaceCardReader"
	panel.set_meta("deck_center_modal", true)
	panel.z_index = 2900
	host.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	var title := UI.label(card.display_name())
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	heading.add_child(title)
	var close := UI.action("关闭", panel.queue_free)
	close.name = "CardReaderCloseButton"
	heading.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.name = "CardReaderScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UI.scroll(scroll)
	column.add_child(scroll)
	var body := GridContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	var art := CardProxy.new()
	art.setup_from_card(card)
	body.add_child(art)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(text)
	add_paragraph(text, "%s / %s · %s" % [card.set_code, card.card_index, card.card_type], UI.MUTED)
	if card.is_pokemon():
		add_paragraph(text, "HP %d · %s · %s" % [card.hp, ENERGY_NAMES.get(card.energy_type, card.energy_type), card.stage], UI.ACCENT)
		if card.evolves_from != "":
			add_paragraph(text, "从 %s 进化" % card.evolves_from)
		var weakness := "%s %s" % [ENERGY_NAMES.get(card.weakness_energy, card.weakness_energy), card.weakness_value] if card.weakness_energy != "" else "无"
		var resistance := "%s %s" % [ENERGY_NAMES.get(card.resistance_energy, card.resistance_energy), card.resistance_value] if card.resistance_energy != "" else "无"
		add_paragraph(text, "弱点 %s · 抗性 %s · 撤退 %d" % [weakness, resistance, card.retreat_cost], UI.MUTED)
	for ability: Dictionary in card.abilities:
		add_paragraph(text, "特性 · " + CardData.dictionary_display_name(ability), UI.ACCENT)
		add_paragraph(text, CardData.dictionary_display_text(ability))
	for attack: Dictionary in card.attacks:
		add_paragraph(text, "%s   %s" % [CardData.dictionary_display_name(attack), str(attack.get("damage", ""))], UI.ACCENT)
		var cost := str(attack.get("cost", "")).strip_edges()
		if cost != "":
			add_paragraph(text, "所需能量 · " + cost, UI.MUTED)
		add_paragraph(text, CardData.dictionary_display_text(attack))
	if card.description != "":
		add_paragraph(text, card.description)
	if card.name_en != "":
		add_paragraph(text, card.name_en, UI.MUTED)
	var apply := func():
		var profile := UI.for_control(host)
		var scale: float = profile.scale
		panel.add_theme_stylebox_override("panel", UI.box(UI.BG, UI.BG, 0, float(profile.margin)))
		column.add_theme_constant_override("separation", roundi(16 * scale))
		title.add_theme_font_size_override("font_size", roundi(22 * scale))
		UI.button(close, scale)
		body.columns = 1 if profile.portrait else 2
		body.add_theme_constant_override("h_separation", roundi(24 * scale))
		body.add_theme_constant_override("v_separation", roundi(18 * scale))
		var height := minf((250 if profile.portrait else 360) * scale, float(profile.size.y) * 0.55)
		art.custom_minimum_size = Vector2(height / 1.4 if not profile.portrait else 0, height)
		text.add_theme_constant_override("separation", roundi(16 * scale))
		for label: Label in text.get_children():
			label.add_theme_font_size_override("font_size", roundi(17 * scale))
	panel.resized.connect(apply)
	apply.call()

static func add_paragraph(parent: Node, text: String, color: Color = UI.TEXT) -> void:
	var label := UI.label(text, 17, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
