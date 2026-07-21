class_name AttackOptionalReturnSelfAllCardsToHand
extends AttackReturnSelfAllCardsToHand

const CHOICE_STEP_ID := "bombirdier_shadow_wind_choice"

var attack_index_to_match: int = -1


func _init(match_attack_index: int = -1) -> void:
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match < 0 or attack_index == attack_index_to_match


func get_attack_interaction_steps(
	card: CardInstance,
	attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	if card == null or state == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
		return []
	if CSV9CEffects.player_field_return_to_hand_blocked(card.owner_index, state):
		return []
	var player := state.players[card.owner_index]
	if player.active_pokemon != null and player.active_pokemon.get_top_card() == card and player.bench.is_empty():
		return []
	return [{
		"id": CHOICE_STEP_ID,
		"title": "Return this Pokemon and all attached cards to your hand?",
		"items": ["keep", "return"],
		"labels": ["Keep in play", "Return to hand"],
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": false,
	}]


func get_followup_attack_interaction_steps(
	card: CardInstance,
	_attack: Dictionary,
	state: GameState,
	resolved_context: Dictionary
) -> Array[Dictionary]:
	if not _return_selected(resolved_context):
		return []
	var player := state.players[card.owner_index]
	if player.active_pokemon == null or player.active_pokemon.get_top_card() != card:
		return []
	return _replacement_step(player)


func execute_attack(
	attacker: PokemonSlot,
	defender: PokemonSlot,
	attack_index: int,
	state: GameState
) -> void:
	if not applies_to_attack_index(attack_index) or not _return_selected(get_attack_interaction_context()):
		return
	super.execute_attack(attacker, defender, attack_index, state)


func get_description() -> String:
	return "You may return this Pokemon and all attached cards to your hand."


func _replacement_step(player: PlayerState) -> Array[Dictionary]:
	if player == null or player.bench.is_empty():
		return []
	var items: Array = player.bench.duplicate()
	var labels: Array[String] = []
	for slot: PokemonSlot in player.bench:
		labels.append("%s (HP %d/%d)" % [slot.get_pokemon_name(), slot.get_remaining_hp(), slot.get_max_hp()])
	return [{
		"id": REPLACEMENT_STEP_ID,
		"title": "Choose a new Active Pokemon",
		"items": items,
		"labels": labels,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": false,
	}]


func _return_selected(context: Dictionary) -> bool:
	for value: Variant in context.get(CHOICE_STEP_ID, []):
		if str(value) == "return":
			return true
	return false


func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
	if attack.has("_override_attack_index"):
		return int(attack.get("_override_attack_index", -1))
	if card == null or card.card_data == null:
		return -1
	for index: int in card.card_data.attacks.size():
		if card.card_data.attacks[index] == attack:
			return index
	return -1
