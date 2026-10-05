## 狙落 - 钥圈儿
## 在造成伤害前，将对手战斗宝可梦身上的宝可梦道具放入弃牌区。
class_name AttackDiscardDefenderTool
extends BaseEffect


func before_attack_damage(
	attacker: PokemonSlot,
	defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	if defender == null or defender.get_attached_tools().is_empty():
		return
	var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
	if processor != null and processor.is_attack_effect_prevented_by_defender_ability(attacker, defender, state):
		return
	var defender_top: CardInstance = defender.get_top_card()
	for tool_card: CardInstance in defender.get_attached_tools():
		defender.remove_attached_tool(tool_card)
		if defender_top != null:
			state.players[defender_top.owner_index].discard_card(tool_card)
		else:
			tool_card.face_up = false


func execute_attack(_attacker: PokemonSlot, _defender: PokemonSlot, _index: int, _state: GameState) -> void:
	pass


func get_description() -> String:
	return "在造成伤害前，弃掉对手战斗宝可梦的道具。"
