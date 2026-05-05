## 赛吉 - 从牌库搜索1张进化卡（无特性），放在场上宝可梦上进化（无视回合限制）
class_name EffectSalvatore
extends BaseEffect


func can_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	for evo_card: CardInstance in player.deck:
		if not _is_valid_evolution(evo_card):
			continue
		for slot: PokemonSlot in player.get_all_pokemon():
			if _can_evolve_onto(evo_card, slot):
				return true
	return false


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]

	var evo_items: Array = []
	var evo_labels: Array[String] = []
	var valid_target_map: Dictionary = {}

	for c: CardInstance in player.deck:
		if not _is_valid_evolution(c):
			continue
		var has_target := false
		for slot: PokemonSlot in player.get_all_pokemon():
			if _can_evolve_onto(c, slot):
				has_target = true
				valid_target_map[slot] = true
		if has_target:
			evo_items.append(c)
			evo_labels.append("%s (%s)" % [c.card_data.name, c.card_data.stage])

	var target_items: Array = []
	var target_labels: Array[String] = []
	for slot: PokemonSlot in player.get_all_pokemon():
		if valid_target_map.has(slot):
			target_items.append(slot)
			target_labels.append(slot.get_pokemon_name())

	if evo_items.is_empty() or target_items.is_empty():
		return []

	var evo_step := build_full_library_search_step(
		"evolution_card",
		"选择要进化的卡牌（无特性）",
		player.deck,
		evo_items,
		VISIBLE_SCOPE_OWN_FULL_DECK,
		1,
		1,
		{"allow_cancel": true}
	)
	evo_step["labels"] = evo_labels

	return [
		evo_step,
		{
			"id": "target_pokemon",
			"title": "选择要进化的宝可梦",
			"items": target_items,
			"labels": target_labels,
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": true,
		},
	]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var pi: int = card.owner_index
	var player: PlayerState = state.players[pi]
	var ctx: Dictionary = get_interaction_context(targets)

	var evo_card: CardInstance = null
	var target_slot: PokemonSlot = null

	var evo_raw: Array = ctx.get("evolution_card", [])
	if not evo_raw.is_empty() and evo_raw[0] is CardInstance:
		var selected: CardInstance = evo_raw[0]
		if selected in player.deck and _is_valid_evolution(selected):
			evo_card = selected

	var target_raw: Array = ctx.get("target_pokemon", [])
	if not target_raw.is_empty() and target_raw[0] is PokemonSlot:
		var selected: PokemonSlot = target_raw[0]
		if selected in player.get_all_pokemon():
			target_slot = selected

	# 自动回退
	if evo_card == null or target_slot == null or not _can_evolve_onto(evo_card, target_slot):
		evo_card = null
		target_slot = null
		for c: CardInstance in player.deck:
			if not _is_valid_evolution(c):
				continue
			for slot: PokemonSlot in player.get_all_pokemon():
				if _can_evolve_onto(c, slot):
					evo_card = c
					target_slot = slot
					break
			if evo_card != null:
				break

	if evo_card == null or target_slot == null:
		return

	player.deck.erase(evo_card)
	target_slot.pokemon_stack.append(evo_card)
	target_slot.turn_evolved = state.turn_number
	target_slot.clear_all_status()
	player.shuffle_deck()


## 检查卡牌是否为无特性的进化宝可梦
func _is_valid_evolution(c: CardInstance) -> bool:
	if c == null or c.card_data == null:
		return false
	var cd: CardData = c.card_data
	if not cd.is_pokemon():
		return false
	if cd.stage != "Stage 1" and cd.stage != "Stage 2":
		return false
	if not cd.abilities.is_empty():
		return false
	return true


## 检查进化卡能否放到目标宝可梦上
func _can_evolve_onto(evo_card: CardInstance, slot: PokemonSlot) -> bool:
	if slot == null or evo_card == null:
		return false
	var top: CardInstance = slot.get_top_card()
	if top == null:
		return false
	return evo_card.card_data.evolves_from == top.card_data.name


func get_description() -> String:
	return "从牌库搜索1张无特性进化卡，放在场上宝可梦上进化（无视回合限制）"
