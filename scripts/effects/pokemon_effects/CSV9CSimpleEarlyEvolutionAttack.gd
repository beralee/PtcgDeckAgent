class_name CSV9CSimpleEarlyEvolutionAttack
extends BaseEffect

const STEP_ID := "csv9c_early_evolution_card"

var attack_index_to_match: int = -1


func _init(match_attack_index: int = -1) -> void:
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match < 0 or attack_index_to_match == attack_index


func get_attack_interaction_steps(
	card: CardInstance,
	attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	if card == null or state == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
		return []
	var player: PlayerState = state.players[card.owner_index]
	var attacker := _find_owner_slot(card, player)
	if attacker == null:
		return []
	var candidates := _evolution_cards_for_slot(player.deck, attacker)
	if candidates.is_empty():
		return []
	return [build_full_library_search_step(
		STEP_ID,
		"Choose an Evolution card for this Pokemon",
		player.deck,
		candidates,
		VISIBLE_SCOPE_OWN_FULL_DECK,
		1,
		1,
		{"allow_cancel": true}
	)]


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	attack_index: int,
	state: GameState
) -> void:
	if attacker == null or state == null or not applies_to_attack_index(attack_index):
		return
	var top: CardInstance = attacker.get_top_card()
	if top == null:
		return
	var player: PlayerState = state.players[top.owner_index]
	var candidates := _evolution_cards_for_slot(player.deck, attacker)
	if candidates.is_empty():
		player.shuffle_deck()
		return

	var ctx := get_attack_interaction_context()
	var has_explicit_selection := ctx.has(STEP_ID)
	var selected := _selected_card(candidates, ctx.get(STEP_ID, []))
	if selected == null and not has_explicit_selection:
		selected = candidates[0]
	if selected == null:
		player.shuffle_deck()
		return

	player.deck.erase(selected)
	selected.face_up = true
	attacker.pokemon_stack.append(selected)
	attacker.turn_evolved = state.turn_number
	attacker.clear_all_status()
	player.shuffle_deck()


func _evolution_cards_for_slot(cards: Array[CardInstance], slot: PokemonSlot) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	if slot == null:
		return result
	var base_name := slot.get_pokemon_name()
	for card: CardInstance in cards:
		if card == null or card.card_data == null:
			continue
		if not card.card_data.is_pokemon():
			continue
		if card.card_data.evolves_from == base_name:
			result.append(card)
	return result


func _selected_card(candidates: Array[CardInstance], selected_raw: Array) -> CardInstance:
	for entry: Variant in selected_raw:
		var card := _resolve_card(candidates, entry)
		if card != null:
			return card
	return null


func _resolve_card(candidates: Array[CardInstance], entry: Variant) -> CardInstance:
	if entry is CardInstance and entry in candidates:
		return entry
	if entry is Dictionary:
		var entry_dict: Dictionary = entry
		var instance_id := int(entry_dict.get("instance_id", entry_dict.get("card_instance_id", -1)))
		for card: CardInstance in candidates:
			if card.instance_id == instance_id:
				return card
	return null


func _find_owner_slot(card: CardInstance, player: PlayerState) -> PokemonSlot:
	if card == null or player == null:
		return null
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot != null and slot.get_top_card() == card:
			return slot
	return null


func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
	if attack.has("_override_attack_index"):
		return int(attack.get("_override_attack_index", -1))
	if card == null or card.card_data == null:
		return -1
	for i: int in card.card_data.attacks.size():
		if card.card_data.attacks[i] == attack:
			return i
	return -1


func get_description() -> String:
	return "Search your deck for an Evolution card that evolves from this Pokemon and evolve it."
