class_name EffectBugCatchingSet
extends BaseEffect

const STEP_ID := "bug_catching_set_cards"

var look_count: int = 7
var pick_count: int = 2


func _init(look: int = 7, pick: int = 2) -> void:
	look_count = look
	pick_count = pick


func can_execute(card: CardInstance, state: GameState) -> bool:
	return not state.players[card.owner_index].deck.is_empty()


func can_headless_execute(card: CardInstance, state: GameState) -> bool:
	return not _get_matching_cards(state.players[card.owner_index]).is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var visible_cards := _get_looked_cards(player)
	var items := _get_matching_cards(player)
	if items.is_empty():
		return [
			build_empty_search_resolution_step_with_view_label(
				"%s: no Grass Pokemon or Basic Grass Energy found in the top %d cards." % [card.card_data.name, look_count],
				"View cards"
			)
		]
	var max_select := mini(pick_count, items.size())
	return [build_full_library_search_step(
		STEP_ID,
		"Choose up to %d Grass Pokemon or Basic Grass Energy" % pick_count,
		visible_cards,
		items,
		"own_top_%d_cards" % mini(look_count, player.deck.size()),
		0,
		max_select,
		{
			"allow_cancel": true,
			"card_disabled_badge": "Not selectable",
			"card_selectable_hint": "Selectable",
			"show_selectable_hints": true,
		}
	)]


func get_followup_interaction_steps(card: CardInstance, state: GameState, resolved_context: Dictionary) -> Array[Dictionary]:
	if not should_preview_empty_search_deck(resolved_context):
		return []
	return [build_readonly_card_preview_step("%s: viewed cards" % card.card_data.name, _get_looked_cards(state.players[card.owner_index]))]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	var player: PlayerState = state.players[card.owner_index]
	var ctx: Dictionary = get_interaction_context(targets)
	var selected: Array[CardInstance] = []
	var selected_raw: Array = ctx.get(STEP_ID, [])
	var visible_cards := _get_looked_cards(player)
	var has_explicit_selection := ctx.has(STEP_ID)
	for entry: Variant in selected_raw:
		if entry is CardInstance and entry in visible_cards and _matches_card(entry) and entry not in selected:
			selected.append(entry)
			if selected.size() >= pick_count:
				break

	if selected.is_empty() and not has_explicit_selection:
		for deck_card: CardInstance in visible_cards:
			if _matches_card(deck_card):
				selected.append(deck_card)
				if selected.size() >= pick_count:
					break

	_move_public_cards_to_hand_with_log(
		state,
		card.owner_index,
		selected,
		card,
		"trainer",
		"toplook_to_hand",
		["Grass Pokemon", "Basic Grass Energy"]
	)
	player.shuffle_deck()


func _get_looked_cards(player: PlayerState) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	for i: int in mini(look_count, player.deck.size()):
		result.append(player.deck[i])
	return result


func _get_matching_cards(player: PlayerState) -> Array:
	var result: Array = []
	for deck_card: CardInstance in _get_looked_cards(player):
		if _matches_card(deck_card):
			result.append(deck_card)
	return result


func _matches_card(card: CardInstance) -> bool:
	if card == null or card.card_data == null:
		return false
	var cd: CardData = card.card_data
	if cd.is_pokemon() and cd.energy_type == "G":
		return true
	return cd.card_type == "Basic Energy" and (cd.energy_provides == "G" or cd.energy_type == "G")


func get_description() -> String:
	return "Look at the top 7 cards. Put up to 2 Grass Pokemon and Basic Grass Energy cards into your hand, then shuffle."
