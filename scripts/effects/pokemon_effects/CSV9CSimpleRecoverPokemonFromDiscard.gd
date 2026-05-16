class_name CSV9CSimpleRecoverPokemonFromDiscard
extends BaseEffect

const STEP_ID := "csv9c_recover_pokemon_from_discard"

var recover_count: int = 1
var attack_index_to_match: int = -1


func _init(count: int = 1, match_attack_index: int = -1) -> void:
	recover_count = max(0, count)
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match < 0 or attack_index_to_match == attack_index


func get_attack_interaction_steps(
	card: CardInstance,
	attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	if card == null or state == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
		return []
	var player: PlayerState = state.players[card.owner_index]
	var candidates := _pokemon_cards(player.discard_pile)
	if candidates.is_empty():
		return []
	var labels: Array[String] = []
	for candidate: CardInstance in candidates:
		labels.append(candidate.card_data.name if candidate.card_data != null else "")
	var count := mini(recover_count, candidates.size())
	return [{
		"id": STEP_ID,
		"title": "Choose a Pokemon from your discard pile",
		"items": candidates,
		"labels": labels,
		"min_select": count,
		"max_select": count,
		"allow_cancel": true,
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
	var player: PlayerState = state.players[top.owner_index]
	var candidates := _pokemon_cards(player.discard_pile)
	var chosen := _resolve_selected(candidates, mini(recover_count, candidates.size()))
	for card: CardInstance in chosen:
		player.discard_pile.erase(card)
		card.face_up = true
		player.hand.append(card)


func _resolve_selected(candidates: Array[CardInstance], limit: int) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	var ctx := get_attack_interaction_context()
	var selected_raw: Array = ctx.get(STEP_ID, [])
	var has_explicit_selection := ctx.has(STEP_ID)
	for entry: Variant in selected_raw:
		var card := _resolve_card(candidates, entry)
		if card != null and not (card in result):
			result.append(card)
			if result.size() >= limit:
				return result
	if result.is_empty() and not has_explicit_selection:
		for candidate: CardInstance in candidates:
			result.append(candidate)
			if result.size() >= limit:
				break
	return result


func _pokemon_cards(cards: Array[CardInstance]) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	for card: CardInstance in cards:
		if card != null and card.card_data != null and card.card_data.is_pokemon():
			result.append(card)
	return result


func _resolve_card(candidates: Array[CardInstance], entry: Variant) -> CardInstance:
	if entry is CardInstance and entry in candidates:
		return entry
	if entry is Dictionary:
		var entry_dict: Dictionary = entry
		var instance_id := int(entry_dict.get("instance_id", entry_dict.get("card_instance_id", -1)))
		for card: CardInstance in candidates:
			if card.instance_id == instance_id:
				return card
	return null


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
	return "Put a Pokemon from your discard pile into your hand."
