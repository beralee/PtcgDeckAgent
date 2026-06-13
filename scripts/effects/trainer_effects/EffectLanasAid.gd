class_name EffectLanasAid
extends BaseEffect

const STEP_ID := "lanas_aid_cards"

var recover_count: int = 3
var include_rule_box_pokemon: bool = false


func _init(count: int = 3, allow_rule_box_pokemon: bool = false) -> void:
	recover_count = count
	include_rule_box_pokemon = allow_rule_box_pokemon


func can_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	for discard_card: CardInstance in player.discard_pile:
		if _matches_card(discard_card):
			return true
	return false


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var items: Array = []
	var labels: Array[String] = []
	for discard_card: CardInstance in player.discard_pile:
		if not _matches_card(discard_card):
			continue
		items.append(discard_card)
		labels.append(discard_card.card_data.name)
	var title := "Choose up to %d Pokemon and Basic Energy from discard" % recover_count
	if not include_rule_box_pokemon:
		title = "Choose up to %d non-rule-box Pokemon and Basic Energy from discard" % recover_count
	return [{
		"id": STEP_ID,
		"title": title,
		"items": items,
		"labels": labels,
		"min_select": 0,
		"max_select": mini(recover_count, items.size()),
		"allow_cancel": true,
	}]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var player: PlayerState = state.players[card.owner_index]
	var ctx: Dictionary = get_interaction_context(targets)
	var selected: Array[CardInstance] = []
	var selected_raw: Array = ctx.get(STEP_ID, [])
	var has_explicit_selection := ctx.has(STEP_ID)
	for entry: Variant in selected_raw:
		if entry is CardInstance and entry in player.discard_pile and _matches_card(entry) and entry not in selected:
			selected.append(entry)
			if selected.size() >= recover_count:
				break

	if selected.is_empty() and not has_explicit_selection:
		for discard_card: CardInstance in player.discard_pile:
			if not _matches_card(discard_card):
				continue
			selected.append(discard_card)
			if selected.size() >= recover_count:
				break

	_move_discard_cards_to_hand_with_log(state, card.owner_index, selected, card, "trainer")


func _matches_card(card: CardInstance) -> bool:
	if card == null or card.card_data == null:
		return false
	var cd: CardData = card.card_data
	if cd.card_type == "Basic Energy":
		return true
	if not cd.is_pokemon():
		return false
	return include_rule_box_pokemon or not cd.is_rule_box_pokemon()


func get_description() -> String:
	if include_rule_box_pokemon:
		return "Recover up to %d Pokemon and Basic Energy cards from discard to hand." % recover_count
	return "Recover up to %d non-rule-box Pokemon and Basic Energy cards from discard to hand." % recover_count
