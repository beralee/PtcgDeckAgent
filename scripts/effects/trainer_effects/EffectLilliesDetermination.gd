## Lillie's Determination
## Shuffle your hand into your deck, then draw 6 cards. Draw 8 instead when
## exactly 6 Prize cards remain.
class_name EffectLilliesDetermination
extends BaseEffect

const NORMAL_DRAW_COUNT := 6
const OPENING_DRAW_COUNT := 8
const OPENING_PRIZE_COUNT := 6


func can_execute(_card: CardInstance, _state: GameState) -> bool:
	return true


func execute(card: CardInstance, _targets: Array, state: GameState) -> void:
	var player_index := card.owner_index
	var player: PlayerState = state.players[player_index]
	var hand_copy: Array[CardInstance] = player.hand.duplicate()
	for hand_card: CardInstance in hand_copy:
		player.hand.erase(hand_card)
		hand_card.face_up = false
		player.deck.append(hand_card)
	player.shuffle_deck()

	var draw_count := OPENING_DRAW_COUNT if player.prizes.size() == OPENING_PRIZE_COUNT else NORMAL_DRAW_COUNT
	_draw_cards_with_log(state, player_index, draw_count, card, "trainer")


func get_description() -> String:
	return "将自己的手牌洗回牌库，然后抽6张卡。若自己恰好剩余6张奖赏卡，则改为抽8张"
