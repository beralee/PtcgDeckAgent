## Cycling Road - once per turn, discard 1 Basic Energy from hand to draw 1 card.
class_name EffectCyclingRoad
extends BaseEffect

const DISCARD_ID := "cycling_road_discard"


func can_use_as_stadium_action(_card: CardInstance, _state: GameState) -> bool:
	return true


func can_execute(_card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[state.current_player_index]
	return not _get_basic_energy_in_hand(player).is_empty() and not player.deck.is_empty()


func get_interaction_steps(_card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[state.current_player_index]
	var items: Array = _get_basic_energy_in_hand(player)
	var labels: Array[String] = []
	for energy_card: CardInstance in items:
		labels.append(energy_card.card_data.name)
	if items.is_empty():
		return []
	return [{
		"id": DISCARD_ID,
		"title": "选择1张手牌中的基本能量放入弃牌区，抽1张卡",
		"items": items,
		"labels": labels,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
	}]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var player_index: int = state.current_player_index
	var player: PlayerState = state.players[player_index]
	var selected: CardInstance = _resolve_selected_energy(player, get_interaction_context(targets))
	if selected == null:
		return
	_discard_cards_from_hand_with_log(state, player_index, [selected], card, "stadium")
	_draw_cards_with_log(state, player_index, 1, card, "stadium")


func _resolve_selected_energy(player: PlayerState, ctx: Dictionary) -> CardInstance:
	var selected_raw: Array = ctx.get(DISCARD_ID, [])
	if not selected_raw.is_empty() and selected_raw[0] is CardInstance:
		var candidate: CardInstance = selected_raw[0]
		if candidate in _get_basic_energy_in_hand(player):
			return candidate
	var energies: Array = _get_basic_energy_in_hand(player)
	return null if energies.is_empty() else energies[0]


func _get_basic_energy_in_hand(player: PlayerState) -> Array:
	var result: Array = []
	for hand_card: CardInstance in player.hand:
		if hand_card.card_data == null:
			continue
		if hand_card.card_data.card_type == "Basic Energy":
			result.append(hand_card)
	return result


func get_description() -> String:
	return "Once during each player's turn, that player may discard 1 Basic Energy from their hand to draw 1 card."
