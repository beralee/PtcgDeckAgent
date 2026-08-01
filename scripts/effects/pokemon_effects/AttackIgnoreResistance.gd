extends BaseEffect

var attack_index_to_match: int = -1


func _init(match_attack_index: int = -1) -> void:
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match < 0 or attack_index_to_match == attack_index


func ignores_resistance(_attacker: PokemonSlot, _state: GameState, attack_index: int = -1) -> bool:
	return applies_to_attack_index(attack_index)


func get_description() -> String:
	return "这个招式的伤害不计算抗性。"
