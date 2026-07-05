class_name AbilityDiscardEnergyDrawToHandSize
extends BaseEffect

var draw_to_count: int = 6
var once_per_turn: bool = true

const USED_KEY: String = "ability_discard_energy_draw_to_hand_size_used"


func _init(target_hand_size: int = 6, once: bool = true) -> void:
	draw_to_count = target_hand_size
	once_per_turn = once


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	if pokemon == null or state == null:
		return false
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return false
	if top.owner_index < 0 or top.owner_index >= state.players.size():
		return false
	if state.current_player_index != top.owner_index:
		return false
	if once_per_turn and _was_used_this_turn(pokemon, state.turn_number):
		return false

	var player: PlayerState = state.players[top.owner_index]
	return _has_energy_in_hand(player.hand)


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	if card == null or state == null:
		return []
	if card.owner_index < 0 or card.owner_index >= state.players.size():
		return []
	var player: PlayerState = state.players[card.owner_index]

	var energy_items: Array = []
	var energy_labels: Array[String] = []
	for hand_card: CardInstance in player.hand:
		if hand_card.card_data != null and hand_card.card_data.is_energy():
			energy_items.append(hand_card)
			energy_labels.append(hand_card.card_data.name)
	if energy_items.is_empty():
		return []

	return [{
		"id": "discard_energy",
		"title": "选择1张要弃置的能量卡",
		"items": energy_items,
		"labels": energy_labels,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
	}]


func execute_ability(
	pokemon: PokemonSlot,
	_ability_index: int,
	targets: Array,
	state: GameState
) -> void:
	if not can_use_ability(pokemon, state):
		return
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return
	var player: PlayerState = state.players[top.owner_index]
	var energy_to_discard := _selected_energy_from_hand(player, targets)
	if energy_to_discard == null:
		return

	var discarded_cards: Array[CardInstance] = _discard_cards_from_hand_with_log(
		state,
		top.owner_index,
		[energy_to_discard],
		top,
		"ability"
	)
	if discarded_cards.is_empty():
		return

	var cards_needed: int = max(0, draw_to_count - player.hand.size())
	if cards_needed > 0:
		_draw_cards_with_log(state, top.owner_index, cards_needed, top, "ability")

	if once_per_turn:
		pokemon.effects.append({
			"type": USED_KEY,
			"turn": state.turn_number,
		})


func _selected_energy_from_hand(player: PlayerState, targets: Array) -> CardInstance:
	var ctx: Dictionary = get_interaction_context(targets)
	var selected_raw: Array = ctx.get("discard_energy", [])
	if not selected_raw.is_empty() and selected_raw[0] is CardInstance:
		var selected_card: CardInstance = selected_raw[0] as CardInstance
		if _is_energy_in_hand(player, selected_card):
			return selected_card
	elif not targets.is_empty() and targets[0] is CardInstance:
		var candidate: CardInstance = targets[0] as CardInstance
		if _is_energy_in_hand(player, candidate):
			return candidate

	for card: CardInstance in player.hand:
		if _is_energy_in_hand(player, card):
			return card
	return null


func _was_used_this_turn(pokemon: PokemonSlot, turn_number: int) -> bool:
	for eff: Dictionary in pokemon.effects:
		if eff.get("type") == USED_KEY and int(eff.get("turn", -1)) == turn_number:
			return true
	return false


func _has_energy_in_hand(hand: Array[CardInstance]) -> bool:
	for card: CardInstance in hand:
		if card.card_data != null and card.card_data.is_energy():
			return true
	return false


func _is_energy_in_hand(player: PlayerState, card: CardInstance) -> bool:
	return card != null and card in player.hand and card.card_data != null and card.card_data.is_energy()


func get_description() -> String:
	return "Ability: discard 1 Energy from hand, then draw until hand has %d cards." % draw_to_count
