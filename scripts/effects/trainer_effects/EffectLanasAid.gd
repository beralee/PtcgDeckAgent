class_name EffectLanasAid
extends BaseEffect

const STEP_ID := "lanas_aid_cards"

var recover_count: int = 3
var include_rule_box_pokemon: bool = false


func _init(count: int = 3, allow_rule_box_pokemon: bool = false) -> void:
	recover_count = count
	include_rule_box_pokemon = allow_rule_box_pokemon


func can_execute(card: CardInstance, state: GameState) -> bool:
	return not _recoverable_discard_cards(card, state).is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var items: Array[CardInstance] = _recoverable_discard_cards(card, state)
	if items.is_empty():
		return []
	var labels: Array[String] = []
	for discard_card: CardInstance in items:
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
		"force_confirm": true,
		"requires_explicit_empty_selection": true,
	}]


func get_unusable_reason(card: CardInstance, state: GameState) -> String:
	if card != null and DiscardToHandBlockHelper.is_discard_to_hand_blocked(card.owner_index, state, "trainer"):
		return "受对手场上效果影响，当前不能通过训练家效果将弃牌区的卡加入手牌。"
	return super.get_unusable_reason(card, state)


func validate_card_interaction(card: CardInstance, targets: Array, state: GameState) -> Dictionary:
	if card == null or state == null or card.owner_index < 0 or card.owner_index >= state.players.size():
		return interaction_validation_error("Discard recovery source card is invalid")
	var legal_items: Array = _recoverable_discard_cards(card, state)
	return validate_context_selection(
		get_interaction_context(targets),
		STEP_ID,
		legal_items,
		0,
		mini(recover_count, legal_items.size()),
		true,
		true
	)


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	if not bool(validate_card_interaction(card, targets, state).get("valid", false)):
		return
	var player: PlayerState = state.players[card.owner_index]
	var ctx: Dictionary = get_interaction_context(targets)
	var selected: Array[CardInstance] = []
	var selected_raw: Array = ctx.get(STEP_ID, [])
	for entry: Variant in selected_raw:
		if entry is CardInstance and entry in player.discard_pile and _matches_card(entry) and entry not in selected:
			selected.append(entry)
			if selected.size() >= recover_count:
				break

	_move_discard_cards_to_hand_with_log(state, card.owner_index, selected, card, "trainer")


func _recoverable_discard_cards(card: CardInstance, state: GameState) -> Array[CardInstance]:
	var cards: Array[CardInstance] = []
	if card == null or state == null:
		return cards
	if card.owner_index < 0 or card.owner_index >= state.players.size():
		return cards
	var player: PlayerState = state.players[card.owner_index]
	for discard_card: CardInstance in player.discard_pile:
		if _matches_card(discard_card) and DiscardPileRestriction.can_move_to_hand_or_deck(discard_card):
			cards.append(discard_card)
	return DiscardToHandBlockHelper.filter_recoverable_discard_cards(card.owner_index, state, cards, "trainer")


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
