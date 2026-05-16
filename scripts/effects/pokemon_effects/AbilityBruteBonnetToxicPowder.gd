class_name AbilityBruteBonnetToxicPowder
extends BaseEffect

const USED_KEY := "brute_bonnet_toxic_powder_used"
const ANCIENT_CAPSULE_EFFECT_ID := "8da8631aa1827b122ec65b712939ad48"


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	if pokemon == null or pokemon.get_top_card() == null or state == null:
		return false
	var owner_index := pokemon.get_top_card().owner_index
	if state.current_player_index != owner_index:
		return false
	if pokemon.attached_tool == null or pokemon.attached_tool.card_data == null:
		return false
	if pokemon.attached_tool.card_data.effect_id != ANCIENT_CAPSULE_EFFECT_ID:
		return false
	if _tool_suppressed(pokemon, state):
		return false
	for effect_data: Dictionary in pokemon.effects:
		if effect_data.get("type", "") == USED_KEY and int(effect_data.get("turn", -1)) == state.turn_number:
			return false
	return state.players[owner_index].active_pokemon != null and state.players[1 - owner_index].active_pokemon != null


func execute_ability(pokemon: PokemonSlot, _ability_index: int, _targets: Array, state: GameState) -> void:
	if not can_use_ability(pokemon, state):
		return
	var owner_index := pokemon.get_top_card().owner_index
	_poison_if_allowed(state.players[owner_index].active_pokemon, state)
	_poison_if_allowed(state.players[1 - owner_index].active_pokemon, state)
	pokemon.effects.append({"type": USED_KEY, "turn": state.turn_number})


func _poison_if_allowed(slot: PokemonSlot, state: GameState) -> void:
	_apply_special_status(slot, "poisoned", state)


func _tool_suppressed(pokemon: PokemonSlot, state: GameState) -> bool:
	var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
	return processor != null and processor.has_method("is_tool_effect_suppressed") and bool(processor.call("is_tool_effect_suppressed", pokemon, state))


func get_description() -> String:
	return "If this Pokemon has Ancient Booster Energy Capsule attached, both Active Pokemon are now Poisoned."
