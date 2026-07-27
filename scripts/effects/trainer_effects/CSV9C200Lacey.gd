## 紫竽（Lacey）
## 将自己的其余手牌洗回牌库。若对手剩余奖赏卡不多于 3 张，抽 8 张；
## 否则抽 4 张。
class_name CSV9C200Lacey
extends BaseEffect

const PRIZE_THRESHOLD := 3
const NORMAL_DRAW_COUNT := 4
const COMEBACK_DRAW_COUNT := 8


func can_execute(_card: CardInstance, _state: GameState) -> bool:
	return true


func execute(card: CardInstance, _targets: Array, state: GameState) -> void:
	var player_index := card.owner_index
	var player: PlayerState = state.players[player_index]
	var opponent: PlayerState = state.players[1 - player_index]

	var hand_copy: Array[CardInstance] = player.hand.duplicate()
	for hand_card: CardInstance in hand_copy:
		player.hand.erase(hand_card)
		hand_card.face_up = false
		player.deck.append(hand_card)
	player.shuffle_deck()

	var draw_count := COMEBACK_DRAW_COUNT if opponent.prizes.size() <= PRIZE_THRESHOLD else NORMAL_DRAW_COUNT
	_draw_cards_with_log(state, player_index, draw_count, card, "trainer")


func get_description() -> String:
	return "将自己的手牌洗回牌库。若对手剩余奖赏卡不多于3张，抽8张；否则抽4张"
