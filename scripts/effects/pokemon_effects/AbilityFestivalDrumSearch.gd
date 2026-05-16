class_name AbilityFestivalDrumSearch
extends AbilitySearchAny


func _init() -> void:
	super(1, true, false)


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	if not super.can_use_ability(pokemon, state):
		return false
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return false
	var active: PokemonSlot = state.players[top.owner_index].active_pokemon
	return AbilityFestivalLead.has_festival_lead(active)


func get_description() -> String:
	return "If your Active Pokemon has Festival Lead, search your deck for a card."
