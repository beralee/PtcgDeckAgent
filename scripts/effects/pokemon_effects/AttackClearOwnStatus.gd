## 奇迹之力 - 沙奈朵ex
## 攻击后清除自身所有特殊状态
class_name AttackClearOwnStatus
extends BaseEffect

var attack_index_to_match: int = -1


func _init(match_attack_index: int = -1) -> void:
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match < 0 or attack_index == attack_index_to_match


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	attack_index: int,
	_state: GameState
) -> void:
	if not applies_to_attack_index(attack_index):
		return
	for status_name: String in attacker.status_conditions.keys():
		attacker.set_status(status_name, false)


func get_description() -> String:
	return "将自身的特殊状态全部恢复。"
