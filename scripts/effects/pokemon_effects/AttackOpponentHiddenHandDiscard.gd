class_name AttackOpponentHiddenHandDiscard
extends BaseEffect

const STEP_ID := "opponent_hidden_hand_discard"

var attack_index_to_match: int = -1


func _init(match_attack_index: int = -1) -> void:
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match < 0 or attack_index_to_match == attack_index


func build_ucis_attack_interaction_steps_spec_steps(
	card: CardInstance,
	attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	if card == null or state == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
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
		"title": "Choose 1 opponent hand card without looking",
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
	attack_index: int,
	state: GameState
) -> void:
	if attacker == null or state == null or not applies_to_attack_index(attack_index):
		return
	var top := attacker.get_top_card()
	if top == null:
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
	if opponent.remove_from_hand(chosen):
		opponent.discard_card(chosen)


func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
	if attack.has("_override_attack_index"):
		return int(attack.get("_override_attack_index", -1))
	if card == null or card.card_data == null:
		return -1
	for i: int in card.card_data.attacks.size():
		if card.card_data.attacks[i] == attack:
			return i
	return -1


func get_description() -> String:
	return "Choose one card from your opponent's hand without looking and discard it."
