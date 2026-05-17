class_name AbilityToedscruelSlimeMoldColony
extends BaseEffect


func can_use_ability(_pokemon: PokemonSlot, _state: GameState) -> bool:
	return false


func blocks_opponent_discard_to_hand(
	source: PokemonSlot,
	acting_player_index: int,
	source_kind: String,
	state: GameState
) -> bool:
	if source == null or source.get_top_card() == null or state == null:
		return false
	if source_kind not in ["ability", "trainer"]:
		return false
	var owner_index := source.get_top_card().owner_index
	return acting_player_index == 1 - owner_index


func get_description() -> String:
	return "While this Pokemon is in play, opponent Trainer and Ability effects cannot put cards from their discard pile into their hand."
