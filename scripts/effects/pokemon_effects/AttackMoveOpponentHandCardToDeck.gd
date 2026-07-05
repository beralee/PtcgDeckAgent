class_name AttackMoveOpponentHandCardToDeck
extends BaseEffect

const STEP_ID := "opponent_hand_card_to_deck"


func get_attack_interaction_steps(
	card: CardInstance,
	_attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	if card == null or state == null:
		return []
	var opponent_index := 1 - card.owner_index
	if opponent_index < 0 or opponent_index >= state.players.size():
		return []
	var opponent: PlayerState = state.players[opponent_index]
	if opponent.hand.is_empty():
		return []
	var labels: Array[String] = []
	for i: int in opponent.hand.size():
		labels.append("Opponent hand card %d" % (i + 1))
	return [{
		"id": STEP_ID,
		"title": "Choose 1 random opponent hand card to reveal and shuffle into their deck",
		"items": opponent.hand.duplicate(),
		"labels": labels,
		"presentation": "list",
		"visible_scope": "opponent_hand_hidden",
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": false,
		"force_confirm": true,
	}]


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	var top: CardInstance = attacker.get_top_card() if attacker != null else null
	if top == null or state == null:
		return
	var opponent_index := 1 - top.owner_index
	if opponent_index < 0 or opponent_index >= state.players.size():
		return
	var opponent: PlayerState = state.players[opponent_index]
	if opponent.hand.is_empty():
		return
	var chosen: CardInstance = null
	var ctx := get_attack_interaction_context()
	for entry: Variant in ctx.get(STEP_ID, []):
		if entry is CardInstance and entry in opponent.hand:
			chosen = entry
			break
	if chosen == null:
		chosen = opponent.hand[0]
	opponent.remove_from_hand(chosen)
	chosen.face_up = false
	opponent.deck.append(chosen)
	opponent.shuffle_deck()
