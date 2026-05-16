class_name CSV9C190CounterGain
extends BaseEffect


func get_attack_colorless_cost_modifier(attacker: PokemonSlot, _attack: Dictionary, state: GameState) -> int:
	if attacker == null or attacker.get_top_card() == null or state == null:
		return 0
	var owner_index: int = attacker.get_top_card().owner_index
	var opponent_index := 1 - owner_index
	if owner_index < 0 or owner_index >= state.players.size() or opponent_index < 0 or opponent_index >= state.players.size():
		return 0
	var my_prizes: int = state.players[owner_index].prizes.size()
	var opponent_prizes: int = state.players[opponent_index].prizes.size()
	return -1 if my_prizes > opponent_prizes else 0


func get_description() -> String:
	return "自己的剩余奖赏卡多于对手时，附着宝可梦招式所需无色能量减少1个。"
