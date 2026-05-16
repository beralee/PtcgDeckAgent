class_name AttackRecoverTrainerFromDiscard
extends BaseEffect

const STEP_ID := "recover_trainer_from_discard"

var recover_count: int = 1
var attack_index_to_match: int = -1


func _init(count: int = 1, match_attack_index: int = -1) -> void:
	recover_count = max(0, count)
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func get_attack_interaction_steps(
	card: CardInstance,
	attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	if card == null or state == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
		return []
	var player: PlayerState = state.players[card.owner_index]
	var candidates: Array[CardInstance] = _trainer_cards(player.discard_pile)
	if candidates.is_empty():
		return []
	var labels: Array[String] = []
	for trainer: CardInstance in candidates:
		labels.append(trainer.card_data.name if trainer.card_data != null else "")
	var count := mini(recover_count, candidates.size())
	return [{
		"id": STEP_ID,
		"title": "Choose a Trainer card from your discard pile",
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
	var top: CardInstance = attacker.get_top_card()
	if top == null:
		return
	var player: PlayerState = state.players[top.owner_index]
	var chosen: Array[CardInstance] = _resolve_selected(player, mini(recover_count, _trainer_cards(player.discard_pile).size()))
	for card: CardInstance in chosen:
		player.discard_pile.erase(card)
		card.face_up = true
		player.hand.append(card)


func _resolve_selected(player: PlayerState, limit: int) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	var candidates: Array[CardInstance] = _trainer_cards(player.discard_pile)
	var ctx: Dictionary = get_attack_interaction_context()
	var selected_raw: Array = ctx.get(STEP_ID, [])
	for entry: Variant in selected_raw:
		if entry is CardInstance and entry in candidates and entry not in result:
			result.append(entry)
			if result.size() >= limit:
				return result
	for card: CardInstance in candidates:
		if card not in result:
			result.append(card)
			if result.size() >= limit:
				break
	return result


func _trainer_cards(cards: Array[CardInstance]) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	for card: CardInstance in cards:
		if card != null and card.card_data != null and card.card_data.is_trainer():
			result.append(card)
	return result


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
	return "Put a Trainer card from your discard pile into your hand."
