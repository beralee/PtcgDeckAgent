class_name EffectCherensCare
extends BaseEffect

const TARGET_STEP_ID := "cheren_target"
const REPLACEMENT_STEP_ID := "cheren_replacement"


func can_execute(card: CardInstance, state: GameState) -> bool:
	return not _get_valid_targets(state.players[card.owner_index]).is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var targets: Array[PokemonSlot] = _get_valid_targets(player)
	if targets.is_empty():
		return []

	var target_items: Array = []
	var target_labels: Array[String] = []
	for slot: PokemonSlot in targets:
		target_items.append(slot)
		target_labels.append(_build_slot_label(slot))

	var steps: Array[Dictionary] = [{
		"id": TARGET_STEP_ID,
		"title": "选择1只受伤的无色宝可梦放回手牌",
		"items": target_items,
		"labels": target_labels,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
	}]

	if player.active_pokemon != null and player.active_pokemon in targets and not player.bench.is_empty():
		var replacement_items: Array = []
		var replacement_labels: Array[String] = []
		for slot: PokemonSlot in player.bench:
			replacement_items.append(slot)
			replacement_labels.append(_build_slot_label(slot))
		steps.append({
			"id": REPLACEMENT_STEP_ID,
		"title": "选择新的战斗宝可梦",
			"items": replacement_items,
			"labels": replacement_labels,
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": true,
		})

	return steps


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var player: PlayerState = state.players[card.owner_index]
	var ctx: Dictionary = get_interaction_context(targets)
	var target_slot: PokemonSlot = _get_selected_target(ctx, player)
	if target_slot == null:
		return

	var is_active: bool = target_slot == player.active_pokemon
	var replacement: PokemonSlot = null
	if is_active:
		replacement = _get_selected_replacement(ctx, player)
		if replacement == null:
			return

	_return_slot_cards_to_hand(target_slot, player)

	if is_active:
		player.active_pokemon = replacement
		player.bench.erase(replacement)
	else:
		player.bench.erase(target_slot)


func _return_slot_cards_to_hand(slot: PokemonSlot, player: PlayerState) -> void:
	for pokemon_card: CardInstance in slot.pokemon_stack:
		pokemon_card.face_up = true
		player.hand.append(pokemon_card)
	for energy_card: CardInstance in slot.attached_energy:
		energy_card.face_up = true
		player.hand.append(energy_card)
	if slot.attached_tool != null:
		slot.attached_tool.face_up = true
		player.hand.append(slot.attached_tool)


func _get_valid_targets(player: PlayerState) -> Array[PokemonSlot]:
	var targets: Array[PokemonSlot] = []
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot == null or slot.pokemon_stack.is_empty() or slot.damage_counters <= 0:
			continue
		var card_data: CardData = slot.get_card_data()
		if card_data == null or card_data.energy_type != "C":
			continue
		if slot == player.active_pokemon and player.bench.is_empty():
			continue
		targets.append(slot)
	return targets


func _build_slot_label(slot: PokemonSlot) -> String:
	return "%s (HP %d/%d)" % [
		slot.get_pokemon_name(),
		slot.get_remaining_hp(),
		slot.get_max_hp(),
	]


func _get_selected_target(ctx: Dictionary, player: PlayerState) -> PokemonSlot:
	var valid_targets: Array[PokemonSlot] = _get_valid_targets(player)
	var selected_raw: Array = ctx.get(TARGET_STEP_ID, [])
	if not selected_raw.is_empty() and selected_raw[0] is PokemonSlot:
		var candidate: PokemonSlot = selected_raw[0]
		if candidate in valid_targets:
			return candidate
	if not valid_targets.is_empty():
		return valid_targets[0]
	return null


func _get_selected_replacement(ctx: Dictionary, player: PlayerState) -> PokemonSlot:
	if player.bench.is_empty():
		return null
	var selected_raw: Array = ctx.get(REPLACEMENT_STEP_ID, [])
	if not selected_raw.is_empty() and selected_raw[0] is PokemonSlot:
		var candidate: PokemonSlot = selected_raw[0]
		if candidate in player.bench:
			return candidate
	return player.bench[0]
