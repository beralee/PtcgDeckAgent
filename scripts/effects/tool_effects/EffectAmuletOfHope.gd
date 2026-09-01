class_name EffectAmuletOfHope
extends BaseEffect

const STEP_ID := "cards_to_hand"


func build_ucis_knockout_interaction_steps_spec_steps(holder: PokemonSlot, state: GameState) -> Array[Dictionary]:
	if holder == null or holder.get_top_card() == null or state == null:
		return []
	var player := state.players[holder.get_top_card().owner_index]
	return [build_full_library_search_step(
		STEP_ID,
		"Choose up to 3 cards to put into your hand",
		player.deck,
		player.deck,
		VISIBLE_SCOPE_OWN_FULL_DECK,
		0,
		mini(3, player.deck.size()),
		{"allow_cancel": true}
	)]


func resolve_attack_damage_knockout(holder: PokemonSlot, state: GameState, context: Dictionary = {}) -> void:
	if holder == null or holder.get_top_card() == null or state == null:
		return
	var player := state.players[holder.get_top_card().owner_index]
	var selected: Array[CardInstance] = []
	for entry: Variant in context.get(STEP_ID, []):
		if entry is CardInstance and entry in player.deck and entry not in selected:
			selected.append(entry)
			if selected.size() >= 3:
				break
	for chosen: CardInstance in selected:
		player.deck.erase(chosen)
		chosen.face_up = true
		player.hand.append(chosen)
	player.shuffle_deck()


func on_knocked_out_by_attack_damage(holder: PokemonSlot, _attacker: PokemonSlot, state: GameState) -> void:
	var context: Dictionary = state.shared_turn_flags.get("amulet_of_hope_knockout_context", {})
	resolve_attack_damage_knockout(holder, state, context)


func get_description() -> String:
	return "When the attached Pokemon is Knocked Out by damage from an opponent's attack, search your deck for up to 3 cards and put them into your hand. Then, shuffle your deck."
