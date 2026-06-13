class_name AbilityEeveeExRainbowFactor
extends BaseEffect

const EEVEE_NAMES := ["伊布", "Eevee"]
const EEVEE_EX_NAMES := ["伊布ex", "Eevee ex", "Eevee EX"]


func allows_evolution_from_hand_onto_self(
	pokemon: PokemonSlot,
	evolution: CardInstance,
	player_index: int,
	state: GameState
) -> bool:
	if pokemon == null or evolution == null or evolution.card_data == null or state == null:
		return false
	var top := pokemon.get_top_card()
	if top == null or top.card_data == null or top.owner_index != player_index:
		return false
	if pokemon not in state.players[player_index].get_all_pokemon():
		return false
	if not _is_eevee_ex(top.card_data):
		return false

	var evolution_data: CardData = evolution.card_data
	if not evolution_data.is_evolution_pokemon():
		return false
	if not _is_pokemon_ex(evolution_data):
		return false
	return _matches_any_name(evolution_data.evolves_from, EEVEE_NAMES)


func _is_eevee_ex(card_data: CardData) -> bool:
	if card_data == null or not card_data.is_basic_pokemon() or not _is_pokemon_ex(card_data):
		return false
	return _matches_any_name(card_data.name, EEVEE_EX_NAMES) or _matches_any_name(card_data.name_en, EEVEE_EX_NAMES)


func _is_pokemon_ex(card_data: CardData) -> bool:
	if card_data == null or not card_data.is_pokemon():
		return false
	if card_data.mechanic.to_lower() == "ex":
		return true
	for tag: String in card_data.is_tags:
		if tag.to_lower() == "ex":
			return true
	return false


func _matches_any_name(raw_name: String, accepted_names: Array) -> bool:
	var normalized := raw_name.strip_edges().to_lower()
	if normalized == "":
		return false
	for accepted: String in accepted_names:
		if normalized == accepted.strip_edges().to_lower():
			return true
	return false
