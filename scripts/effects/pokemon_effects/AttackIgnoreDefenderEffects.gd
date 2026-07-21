## 无视防守方效果 - 在防守方身上标记本次攻击无视其防御效果
## 适用: 骑拉帝纳V"撕裂"
## 伤害计算时检查 defender.effects 中的此标记以跳过防守方的伤害修正
class_name AttackIgnoreDefenderEffects
extends BaseEffect

var attack_index_to_match: int = -1


func _init(match_attack_index: int = -1) -> void:
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match < 0 or attack_index == attack_index_to_match


func ignores_defender_effects(
	_attacker: PokemonSlot,
	_state: GameState,
	attack_index: int
) -> bool:
	return applies_to_attack_index(attack_index)


func execute_attack(
	_attacker: PokemonSlot,
	defender: PokemonSlot,
	attack_index: int,
	state: GameState
) -> void:
	if not applies_to_attack_index(attack_index):
		return
	# 在防守方效果列表中添加标记，伤害计算阶段检查此标记
	# 标记包含回合号，以便下回合自动失效
	var marker: Dictionary = {
		"type": "ignore_effects_this_attack",
		"turn": state.turn_number
	}
	defender.effects.append(marker)


func get_description() -> String:
	return "此招式无视防守方宝可梦的效果"
