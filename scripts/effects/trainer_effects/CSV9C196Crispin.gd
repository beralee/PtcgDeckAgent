class_name CSV9C196Crispin
extends BaseEffect

const HAND_STEP_ID := "csv9c196_energy_to_hand"
const ATTACH_STEP_ID := "csv9c196_energy_attachment"
const H = preload("res://scripts/effects/CSV9CHelpers.gd")


func can_execute(card: CardInstance, state: GameState) -> bool:
	return not state.players[card.owner_index].deck.is_empty()


func can_headless_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	return not _get_unique_basic_energy(player.deck).is_empty()


func get_preview_interaction_steps(_card: CardInstance, _state: GameState) -> Array[Dictionary]:
	return []


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var energy_items := _get_unique_basic_energy(player.deck)
	if energy_items.is_empty():
		return [build_empty_search_resolution_step("牌库里没有基本能量。你仍可以使用赤松。")]
	var steps: Array[Dictionary] = [build_full_library_search_step(
		HAND_STEP_ID,
		"选择1张基本能量加入手牌",
		player.deck,
		energy_items,
		VISIBLE_SCOPE_OWN_FULL_DECK,
		0,
		1,
		{"allow_cancel": true}
	)]
	if not player.get_all_pokemon().is_empty() and energy_items.size() > 1:
		var target_items: Array = player.get_all_pokemon()
		var target_labels: Array[String] = []
		for slot: PokemonSlot in target_items:
			target_labels.append(H.slot_label(slot, state))
		var energy_labels: Array[String] = []
		for energy_card: CardInstance in energy_items:
			energy_labels.append(energy_card.card_data.name)
		steps.append(build_full_library_card_assignment_step(
			ATTACH_STEP_ID,
			"可再选择1张不同属性基本能量附着于自己的宝可梦",
			player.deck,
			energy_items,
			energy_labels,
			target_items,
			target_labels,
			0,
			1,
			VISIBLE_SCOPE_OWN_FULL_DECK,
			true
		))
	return steps


func get_followup_interaction_steps(card: CardInstance, state: GameState, resolved_context: Dictionary) -> Array[Dictionary]:
	if not should_preview_empty_search_deck(resolved_context):
		return []
	return [build_readonly_deck_preview_step("%s：查看剩余牌库" % card.card_data.name, state.players[card.owner_index].deck)]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var player: PlayerState = state.players[card.owner_index]
	var ctx := get_interaction_context(targets)
	var hand_energy: CardInstance = _resolve_hand_energy(player, ctx)
	var attachment := _resolve_attachment(player, ctx, hand_energy)
	if hand_energy == null and attachment.is_empty() and not ctx.has(HAND_STEP_ID) and not ctx.has(ATTACH_STEP_ID):
		var fallback := _build_fallback(player)
		hand_energy = fallback.get("hand")
		attachment = fallback.get("attachment", {})

	if hand_energy != null and hand_energy in player.deck:
		_move_public_cards_to_hand_with_log(state, card.owner_index, [hand_energy], card, "trainer", "search_to_hand", ["基本能量"])
	else:
		player.shuffle_deck()
		return

	var attach_energy: CardInstance = attachment.get("source", null)
	var attach_target: PokemonSlot = attachment.get("target", null)
	if attach_energy != null and attach_target != null and attach_energy in player.deck and attach_target in player.get_all_pokemon():
		player.deck.erase(attach_energy)
		attach_energy.face_up = true
		attach_target.attached_energy.append(attach_energy)

	player.shuffle_deck()


func _resolve_hand_energy(player: PlayerState, ctx: Dictionary) -> CardInstance:
	for entry: Variant in ctx.get(HAND_STEP_ID, []):
		if entry is CardInstance and entry in player.deck and _is_basic_energy(entry):
			return entry
	return null


func _resolve_attachment(player: PlayerState, ctx: Dictionary, hand_energy: CardInstance) -> Dictionary:
	var hand_type := _energy_type(hand_energy)
	for entry: Variant in ctx.get(ATTACH_STEP_ID, []):
		if not (entry is Dictionary):
			continue
		var source: Variant = (entry as Dictionary).get("source")
		var target: Variant = (entry as Dictionary).get("target")
		if not (source is CardInstance) or not (target is PokemonSlot):
			continue
		var energy_card: CardInstance = source
		if not _is_basic_energy(energy_card) or energy_card not in player.deck:
			continue
		if hand_energy != null and energy_card == hand_energy:
			continue
		if hand_type != "" and _energy_type(energy_card) == hand_type:
			continue
		if target not in player.get_all_pokemon():
			continue
		return {"source": energy_card, "target": target}
	return {}


func _build_fallback(player: PlayerState) -> Dictionary:
	var energies := _get_unique_basic_energy(player.deck)
	var result := {"hand": null, "attachment": {}}
	if energies.is_empty():
		return result
	result["hand"] = energies[0]
	if energies.size() > 1 and not player.get_all_pokemon().is_empty():
		result["attachment"] = {"source": energies[1], "target": player.get_all_pokemon()[0]}
	return result


func _get_unique_basic_energy(cards: Array[CardInstance]) -> Array:
	var result: Array = []
	var seen_types: Dictionary = {}
	for deck_card: CardInstance in cards:
		if not _is_basic_energy(deck_card):
			continue
		var energy_type := _energy_type(deck_card)
		if energy_type == "" or seen_types.has(energy_type):
			continue
		seen_types[energy_type] = true
		result.append(deck_card)
	return result


func _is_basic_energy(card: CardInstance) -> bool:
	return card != null and card.card_data != null and card.card_data.card_type == "Basic Energy"


func _energy_type(card: CardInstance) -> String:
	if card == null or card.card_data == null:
		return ""
	return card.card_data.energy_provides if card.card_data.energy_provides != "" else card.card_data.energy_type


func get_description() -> String:
	return "从牌库选择最多2张不同属性基本能量，其中1张加入手牌，其余附着给自己的宝可梦。"
