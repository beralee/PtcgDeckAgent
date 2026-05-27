## 清除古龙水 - 在回合结束前，对手战斗宝可梦的特性全部消除
## 简化实现：设置标记，由 EffectProcessor 查询时检查
class_name EffectCancelCologne
extends BaseEffect

const ABILITY_DISABLED_EFFECT_TYPE := "ability_disabled"
const SOURCE_CANCEL_COLOGNE := "cancel_cologne"
const ACTIVE_DISABLED_FLAG_PREFIX := "cancel_cologne_active_disabled_player_"


func execute(card: CardInstance, _targets: Array, state: GameState) -> void:
	var pi: int = card.owner_index
	var target_player_index := 1 - pi
	var opp: PlayerState = state.players[target_player_index]
	state.shared_turn_flags[_active_disabled_flag_key(target_player_index)] = state.turn_number
	# 在对手战斗宝可梦上添加「特性消除」效果标记
	if opp.active_pokemon != null:
		# 使用 effects 数组存储临时效果标记
		# 这个效果在回合结束时应该被清除
		opp.active_pokemon.effects.append({
			"type": ABILITY_DISABLED_EFFECT_TYPE,
			"source": SOURCE_CANCEL_COLOGNE,
			"turn": state.turn_number,
		})


static func is_slot_directly_ability_disabled(slot: PokemonSlot, state: GameState) -> bool:
	return has_current_turn_ability_disabled_marker(slot, state) or is_active_slot_disabled_by_cologne(slot, state)


static func has_current_turn_ability_disabled_marker(slot: PokemonSlot, state: GameState) -> bool:
	if slot == null or state == null:
		return false
	for eff: Dictionary in slot.effects:
		if eff.get("type", "") == ABILITY_DISABLED_EFFECT_TYPE and int(eff.get("turn", -999)) == state.turn_number:
			return true
	return false


static func is_active_slot_disabled_by_cologne(slot: PokemonSlot, state: GameState) -> bool:
	if slot == null or state == null:
		return false
	var owner_index := _slot_owner_index(slot)
	if owner_index < 0 or owner_index >= state.players.size():
		return false
	if state.players[owner_index].active_pokemon != slot:
		return false
	return int(state.shared_turn_flags.get(_active_disabled_flag_key(owner_index), -999)) == state.turn_number


static func _active_disabled_flag_key(player_index: int) -> String:
	return "%s%d" % [ACTIVE_DISABLED_FLAG_PREFIX, player_index]


static func _slot_owner_index(slot: PokemonSlot) -> int:
	if slot == null or slot.get_top_card() == null:
		return -1
	return slot.get_top_card().owner_index


func get_description() -> String:
	return "在回合结束前，对手战斗宝可梦的特性全部消除"
