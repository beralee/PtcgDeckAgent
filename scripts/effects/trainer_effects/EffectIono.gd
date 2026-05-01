## 奇树 - 双方各将手牌放回牌库下方洗牌，然后各抽取与自己剩余奖赏卡张数相同数量的卡
class_name EffectIono
extends BaseEffect


func can_execute(_card: CardInstance, _state: GameState) -> bool:
	## 奇树无使用条件限制
	return true


func execute(card: CardInstance, _targets: Array, state: GameState) -> void:
	var pi: int = card.owner_index
	## 双方同时执行：各自洗手牌，放到牌库下方；再按奖赏卡数量抽牌
	_shuffle_hand_to_bottom_of_deck(state, pi)
	_shuffle_hand_to_bottom_of_deck(state, 1 - pi)
	_draw_by_prizes(state, pi, card)
	_draw_by_prizes(state, 1 - pi, card)


## 将指定玩家的手牌洗牌后放到牌库下方（不洗整副牌库，避免抽回刚放下去的手牌）
func _shuffle_hand_to_bottom_of_deck(state: GameState, pi: int) -> bool:
	var player: PlayerState = state.players[pi]
	var hand_copy: Array[CardInstance] = player.hand.duplicate()
	if hand_copy.is_empty():
		return false
	_shuffle_cards(hand_copy)
	for c: CardInstance in hand_copy:
		player.hand.erase(c)
		c.face_up = false
		player.deck.append(c)
	return true


## 按剩余奖赏卡数量抽牌
func _draw_by_prizes(state: GameState, pi: int, source_card: CardInstance) -> void:
	var player: PlayerState = state.players[pi]
	## 按剩余奖赏卡数量决定抽牌数
	var draw_count: int = player.prizes.size()
	_draw_cards_with_log(state, pi, draw_count, source_card, "trainer")


func _shuffle_cards(cards: Array[CardInstance]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(cards.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp: CardInstance = cards[i]
		cards[i] = cards[j]
		cards[j] = temp


func get_description() -> String:
	return "双方各将手牌洗牌放到牌库下方，然后各抽取与自己剩余奖赏卡张数相同数量的卡"
