class_name AttackDrawToHandSize
extends BaseEffect

const STEP_ID := "draw_to_hand_size_choice"

var target_hand_size: int = 6
var attack_index_to_match: int = -1


func _init(hand_size: int = 6, match_attack_index: int = -1) -> void:
	target_hand_size = hand_size
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func get_attack_interaction_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
	if card == null or state == null:
		return []
	var attack_index := int(attack.get("_override_attack_index", attack.get("index", attack_index_to_match)))
	if not applies_to_attack_index(attack_index):
		return []
	if card.owner_index < 0 or card.owner_index >= state.players.size():
		return []
	var player: PlayerState = state.players[card.owner_index]
	if player.hand.size() >= target_hand_size or player.deck.is_empty():
		return []
	return [{
		"id": STEP_ID,
		"title": "Draw cards until you have %d cards in hand?" % target_hand_size,
		"items": ["skip", "draw"],
		"labels": ["Do not draw", "Draw"],
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
	}]


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	attack_index: int,
	state: GameState
) -> void:
	if not applies_to_attack_index(attack_index):
		return
	var top: CardInstance = attacker.get_top_card()
	if top == null:
		return
	var player: PlayerState = state.players[top.owner_index]
	if player.hand.size() >= target_hand_size:
		return
	var ctx := get_attack_interaction_context()
	if ctx.has(STEP_ID):
		var selected_raw: Array = ctx.get(STEP_ID, [])
		if selected_raw.is_empty() or str(selected_raw[0]) != "draw":
			return
	_draw_cards_with_log(state, top.owner_index, target_hand_size - player.hand.size(), top, "attack")


func get_description() -> String:
	return "Draw cards until you have %d cards in your hand." % target_hand_size
