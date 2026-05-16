class_name CSV9CAdvancedHelpers
extends RefCounted


static func resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
	if attack.has("_override_attack_index"):
		return int(attack.get("_override_attack_index", -1))
	if card == null or card.card_data == null:
		return -1
	for i: int in card.card_data.attacks.size():
		if card.card_data.attacks[i] == attack:
			return i
	return -1


static func card_name(card: CardInstance) -> String:
	return card.card_data.name if card != null and card.card_data != null else ""


static func slot_label(slot: PokemonSlot) -> String:
	if slot == null:
		return ""
	return "%s (HP %d/%d)" % [slot.get_pokemon_name(), slot.get_remaining_hp(), slot.get_max_hp()]


static func is_basic_energy(card: CardInstance, energy_type: String = "") -> bool:
	if card == null or card.card_data == null:
		return false
	var cd := card.card_data
	if cd.card_type != "Basic Energy":
		return false
	return energy_type == "" or cd.energy_provides == energy_type or cd.energy_type == energy_type


static func is_basic_pokemon_slot(slot: PokemonSlot) -> bool:
	return slot != null and slot.get_card_data() != null and slot.get_card_data().stage == "Basic"


static func knock_out_slot(slot: PokemonSlot, state: GameState, processor = null) -> void:
	if slot == null:
		return
	slot.damage_counters = effective_max_hp(slot, state, processor)


static func effective_max_hp(slot: PokemonSlot, state: GameState, processor = null) -> int:
	if slot == null:
		return 0
	if processor != null:
		return processor.get_effective_max_hp(slot, state)
	var shared: Variant = state.shared_turn_flags.get("_draw_effect_processor", null) if state != null else null
	if shared != null and shared.has_method("get_effective_max_hp"):
		return int(shared.call("get_effective_max_hp", slot, state))
	return slot.get_max_hp()


static func return_slot_to_deck(slot: PokemonSlot, player: PlayerState) -> void:
	if slot == null or player == null:
		return
	for card: CardInstance in slot.collect_all_cards():
		card.face_up = false
		player.deck.append(card)
	slot.pokemon_stack.clear()
	slot.attached_energy.clear()
	slot.attached_tool = null
	slot.damage_counters = 0
	slot.clear_all_status()
	if player.active_pokemon == slot:
		player.active_pokemon = null
	else:
		player.bench.erase(slot)


static func selected_cards(deck: Array[CardInstance], legal: Array, selected_raw: Array, limit: int) -> Array:
	var result: Array = []
	for entry: Variant in selected_raw:
		if entry is CardInstance and entry in legal and entry in deck and entry not in result:
			result.append(entry)
			if result.size() >= limit:
				return result
	return result
