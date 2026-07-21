## 弃置竞技场效果 - 攻击时强制弃置场上的竞技场卡（无选择）
## 适用: 小火龙151C"烧光"
class_name AttackDiscardStadium
extends BaseEffect

var attack_index_to_match: int = -1


func _init(match_attack_index: int = -1) -> void:
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match < 0 or attack_index == attack_index_to_match


func execute_attack(
	_attacker: PokemonSlot,
	_defender: PokemonSlot,
	attack_index: int,
	state: GameState
) -> void:
	if not applies_to_attack_index(attack_index):
		return
	if state.stadium_card == null:
		return

	# 将竞技场卡放入其拥有者的弃牌堆
	var owner_idx: int = state.stadium_owner_index
	if owner_idx >= 0 and owner_idx < state.players.size():
		var owner_player: PlayerState = state.players[owner_idx]
		owner_player.discard_pile.append(state.stadium_card)

	# 清除场上竞技场
	state.stadium_card = null
	state.stadium_owner_index = -1


func get_description() -> String:
	return "弃置场上的竞技场"
