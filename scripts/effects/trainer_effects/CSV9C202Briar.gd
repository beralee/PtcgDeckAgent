class_name CSV9C202Briar
extends BaseEffect

const FLAG_PREFIX := "csv9c202_briar_active_"


func can_execute(card: CardInstance, state: GameState) -> bool:
	var opponent_index := 1 - card.owner_index
	return opponent_index >= 0 and opponent_index < state.players.size() and state.players[opponent_index].prizes.size() == 2


func execute(card: CardInstance, _targets: Array, state: GameState) -> void:
	if not can_execute(card, state):
		return
	state.shared_turn_flags[_flag_key(card.owner_index)] = state.turn_number


static func is_active_for_player(state: GameState, player_index: int) -> bool:
	if state == null:
		return false
	return int(state.shared_turn_flags.get(_flag_key(player_index), -999)) == state.turn_number


static func should_apply_extra_prize(state: GameState, attacker: PokemonSlot, defender: PokemonSlot) -> bool:
	if state == null or attacker == null or defender == null:
		return false
	var top: CardInstance = attacker.get_top_card()
	if top == null or top.owner_index < 0:
		return false
	if not is_active_for_player(state, top.owner_index):
		return false
	var attacker_data := attacker.get_card_data()
	return attacker_data != null and _is_tera_pokemon(attacker_data) and defender == state.players[1 - top.owner_index].active_pokemon


static func _flag_key(player_index: int) -> String:
	return "%s%d" % [FLAG_PREFIX, player_index]


static func _is_tera_pokemon(cd: CardData) -> bool:
	if cd == null or not cd.is_pokemon():
		return false
	return cd.is_tera_pokemon()


func get_description() -> String:
	return "对手剩余2张奖赏卡时可用；本回合太晶宝可梦招式伤害击倒对手战斗宝可梦时应多拿1张奖赏卡。"
