class_name CSV8CConkeldurrEffects
extends BaseEffect

const RAMPAGE_ATTACK_INDEX := 0
const GRITTY_SWING_ATTACK_INDEX := 1


func get_attack_any_cost_modifier(attacker: PokemonSlot, attack: Dictionary, _state: GameState) -> int:
	if attacker == null or not attacker.has_any_status():
		return 0
	var attack_index := _resolve_attack_index(attacker, attack)
	if attack_index != GRITTY_SWING_ATTACK_INDEX:
		return 0
	var cost := CardData.normalize_attack_cost(attack.get("cost", ""))
	return -cost.length()


func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
	if attacker == null or attack_index != RAMPAGE_ATTACK_INDEX:
		return
	_apply_special_status(attacker, "confused", state)


func get_description() -> String:
	return "Rampage confuses this Pokemon. Gritty Swing can be used for no Energy while this Pokemon is affected by a Special Condition."


func _resolve_attack_index(attacker: PokemonSlot, attack: Dictionary) -> int:
	var card_data := attacker.get_card_data()
	if card_data == null:
		return -1
	for i: int in card_data.attacks.size():
		if card_data.attacks[i] == attack:
			return i
	return int(attack.get("_override_attack_index", attack.get("index", -1)))
