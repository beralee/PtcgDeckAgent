class_name CSV9C206VibrantPalace
extends BaseEffect


func get_hp_modifier(slot: PokemonSlot, _state: GameState) -> int:
	if slot == null or slot.get_card_data() == null:
		return 0
	return 30 if slot.get_card_data().is_basic_pokemon() else 0


func get_description() -> String:
	return "双方场上所有基础宝可梦最大HP +30。"
