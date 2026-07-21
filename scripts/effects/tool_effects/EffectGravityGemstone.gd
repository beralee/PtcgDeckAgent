class_name EffectGravityGemstone
extends BaseEffect


func get_retreat_cost_modifier_for_slot(
	source: PokemonSlot,
	target: PokemonSlot,
	state: GameState
) -> int:
	if source == null or target == null or state == null or source.get_top_card() == null:
		return 0
	var owner := source.get_top_card().owner_index
	if state.players[owner].active_pokemon != source:
		return 0
	if target != state.players[0].active_pokemon and target != state.players[1].active_pokemon:
		return 0
	return 1


func get_description() -> String:
	return "While the holder is Active, both Active Pokemon's Retreat Costs are 1 Colorless more."
