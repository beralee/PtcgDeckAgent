class_name EffectNamedPokemonFreeRetreat
extends BaseEffect

var name_prefix: String = ""


func _init(prefix: String = "") -> void:
	name_prefix = prefix


func get_retreat_cost_modifier(slot: PokemonSlot, _state: GameState) -> int:
	if slot == null or slot.get_card_data() == null:
		return 0
	return -99 if _matches_named_pokemon(slot.get_card_data()) else 0


func _matches_named_pokemon(card_data: CardData) -> bool:
	if card_data == null or not card_data.is_pokemon():
		return false
	var prefix := name_prefix.strip_edges().to_lower()
	if prefix == "":
		return false
	var names: Array[String] = [card_data.name, card_data.name_en, card_data.name_zh]
	for raw_name: String in names:
		var normalized := raw_name.strip_edges().to_lower()
		if normalized.begins_with(prefix):
			return true
	return false


func get_description() -> String:
	return "Matching Pokemon have no Retreat Cost."
