class_name CSV9CSimplePreventDamageFromBasicAfterAttack
extends BaseEffect

const EFFECT_TYPE := "csv9c_prevent_basic_pokemon_attack_damage"

var attack_index_to_match: int = -1


func _init(match_attack_index: int = -1) -> void:
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match < 0 or attack_index_to_match == attack_index


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	attack_index: int,
	state: GameState
) -> void:
	if attacker == null or state == null or not applies_to_attack_index(attack_index):
		return
	attacker.effects.append({
		"type": EFFECT_TYPE,
		"turn": state.turn_number,
	})


func prevents_damage_from(attacker: PokemonSlot, defender: PokemonSlot, state: GameState) -> bool:
	if attacker == null or defender == null or state == null:
		return false
	var attacker_data := attacker.get_card_data()
	if attacker_data == null or not attacker_data.is_basic_pokemon():
		return false
	var attacker_top := attacker.get_top_card()
	var defender_top := defender.get_top_card()
	if attacker_top == null or defender_top == null or attacker_top.owner_index == defender_top.owner_index:
		return false
	for effect_data: Dictionary in defender.effects:
		if str(effect_data.get("type", "")) != EFFECT_TYPE:
			continue
		if int(effect_data.get("turn", -999)) == state.turn_number - 1:
			return true
	return false


func get_description() -> String:
	return "During the opponent's next turn, prevent damage from Basic Pokemon attacks."
