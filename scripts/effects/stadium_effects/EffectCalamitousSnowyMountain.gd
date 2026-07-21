class_name EffectCalamitousSnowyMountain
extends BaseEffect


func on_any_player_energy_attached_from_hand(
	player_index: int,
	target: PokemonSlot,
	state: GameState
) -> void:
	if state == null or target == null or player_index < 0 or player_index >= state.players.size():
		return
	if target not in state.players[player_index].get_all_pokemon():
		return
	var card_data := target.get_card_data()
	if card_data == null or not card_data.is_basic_pokemon() or card_data.energy_type == "W":
		return
	target.damage_counters += 20


func get_description() -> String:
	return "Whenever either player attaches an Energy from hand to a Basic non-Water Pokemon, put 2 damage counters on it."
