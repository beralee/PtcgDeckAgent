class_name EffectSupereffectiveGlasses
extends BaseEffect


func get_weakness_value_override(attacker: PokemonSlot, defender: PokemonSlot, _state: GameState) -> String:
	if attacker == null or defender == null:
		return ""
	var defender_data := defender.get_card_data()
	if defender_data == null:
		return ""
	if defender_data.weakness_energy == "" or defender_data.weakness_energy != attacker.get_energy_type():
		return ""
	return "x3"


func get_description() -> String:
	return "Weakness is calculated as x3 for this Pokemon's attacks."

