class_name AttackGreninjaExShinobiBlade
extends BaseEffect

var attack_index_to_match: int = -1


func _init(match_attack_index: int = -1) -> void:
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func get_attack_interaction_steps(
	card: CardInstance,
	attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	if card == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
		return []
	var player: PlayerState = state.players[card.owner_index]
	if player.deck.is_empty():
		return []

	var items: Array = []
	var labels: Array[String] = []
	for deck_card: CardInstance in player.deck:
		items.append(deck_card)
		labels.append("%s [%s]" % [deck_card.card_data.name, deck_card.card_data.card_type])

	return [{
		"id": "greninja_ex_search_card",
		"title": "Choose up to 1 card from your deck",
		"items": items,
		"labels": labels,
		"min_select": 0,
		"max_select": 1,
		"allow_cancel": true,
	}]


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	if attacker == null or not applies_to_attack_index(_attack_index):
		return
	var top: CardInstance = attacker.get_top_card()
	if top == null:
		return
	var player: PlayerState = state.players[top.owner_index]
	if player.deck.is_empty():
		return

	var ctx: Dictionary = get_attack_interaction_context()
	var selected_raw: Array = ctx.get("greninja_ex_search_card", [])
	for entry: Variant in selected_raw:
		if not (entry is CardInstance):
			continue
		var chosen := entry as CardInstance
		if chosen not in player.deck:
			continue
		player.deck.erase(chosen)
		chosen.face_up = true
		player.hand.append(chosen)
		break

	player.shuffle_deck()


func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
	if card == null or card.card_data == null:
		return -1
	for i: int in card.card_data.attacks.size():
		if card.card_data.attacks[i] == attack:
			return i
	return int(attack.get("_override_attack_index", -1))


func get_description() -> String:
	return "You may search your deck for a card and put it into your hand."
