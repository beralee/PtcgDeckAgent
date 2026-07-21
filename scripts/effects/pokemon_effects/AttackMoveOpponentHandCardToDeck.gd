class_name AttackMoveOpponentHandCardToDeck
extends BaseEffect

const STEP_ID := "opponent_hand_card_to_deck"
const REVEAL_STEP_ID := "opponent_hand_card_reveal"
var attack_index_to_match: int = -1


func _init(match_attack_index: int = -1) -> void:
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match < 0 or attack_index == attack_index_to_match


func get_attack_interaction_steps(
	card: CardInstance,
	_attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	if card == null or state == null or not applies_to_attack_index(_resolve_attack_index(card, _attack)):
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


func get_followup_attack_interaction_steps(
	card: CardInstance,
	_attack: Dictionary,
	state: GameState,
	context: Dictionary
) -> Array[Dictionary]:
	if card == null or state == null or not applies_to_attack_index(_resolve_attack_index(card, _attack)):
		return []
	var opponent_index := 1 - card.owner_index
	if opponent_index < 0 or opponent_index >= state.players.size():
		return []
	var selected: Array = context.get(STEP_ID, [])
	if selected.is_empty() or not (selected[0] is CardInstance):
		return []
	var chosen: CardInstance = selected[0]
	if chosen not in state.players[opponent_index].hand:
		return []
	return [{
		"id": REVEAL_STEP_ID,
		"title": "查看所选的对手手牌",
		"items": [],
		"labels": [],
		"presentation": "cards",
		"card_items": [chosen],
		"card_indices": [-1],
		"choice_labels": [chosen.card_data.display_name() if chosen.card_data != null else "对手手牌"],
		"min_select": 0,
		"max_select": 0,
		"allow_cancel": false,
		"force_confirm": true,
		"card_click_selectable": false,
	}]


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	if not applies_to_attack_index(_attack_index):
		return
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


func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
	if attack.has("_override_attack_index"):
		return int(attack.get("_override_attack_index", -1))
	if card == null or card.card_data == null:
		return -1
	for index: int in card.card_data.attacks.size():
		if card.card_data.attacks[index] == attack:
			return index
	return -1
