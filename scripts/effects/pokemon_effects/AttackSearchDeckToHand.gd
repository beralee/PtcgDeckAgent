## Search the deck for up to N cards matching a filter and put them into the hand.
class_name AttackSearchDeckToHand
extends BaseEffect

var search_count: int = 1
var card_type_filter: String = ""


func _init(count: int = 1, filter: String = "") -> void:
	search_count = count
	card_type_filter = filter


func get_attack_interaction_steps(
	card: CardInstance,
	_attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	if card == null:
		return []
	var player: PlayerState = state.players[card.owner_index]
	var items: Array = _collect_matching_cards(player)
	if items.is_empty():
		return []
	return [build_full_library_search_step(
		"search_cards",
		"从牌库中选择最多%d张卡加入手牌" % search_count,
		player.deck,
		items,
		VISIBLE_SCOPE_OWN_FULL_DECK,
		0,
		mini(search_count, items.size()),
		{"allow_cancel": true}
	)]


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	var top: CardInstance = attacker.get_top_card()
	if top == null:
		return
	var player: PlayerState = state.players[top.owner_index]
	var found: Array[CardInstance] = []
	var ctx: Dictionary = get_attack_interaction_context()
	var selected_raw: Array = ctx.get("search_cards", [])
	var has_explicit_selection: bool = ctx.has("search_cards")
	for entry: Variant in selected_raw:
		if entry is CardInstance and entry in player.deck and _matches_filter(entry) and entry not in found:
			found.append(entry)
			if found.size() >= search_count:
				break
	if found.is_empty() and not has_explicit_selection:
		for deck_card: CardInstance in player.deck:
			if _matches_filter(deck_card):
				found.append(deck_card)
				if found.size() >= search_count:
					break
	for card: CardInstance in found:
		player.deck.erase(card)
		card.face_up = true
		player.hand.append(card)
	player.shuffle_deck()


func _matches_filter(card: CardInstance) -> bool:
	if card_type_filter == "":
		return true
	var cd: CardData = card.card_data
	if cd == null:
		return false
	return cd.card_type == card_type_filter


func _collect_matching_cards(player: PlayerState) -> Array:
	var result: Array = []
	for deck_card: CardInstance in player.deck:
		if _matches_filter(deck_card):
			result.append(deck_card)
	return result


func get_description() -> String:
	var filter_label := "卡牌" if card_type_filter == "" else card_type_filter
	return "从牌库中选择最多%d张%s加入手牌。" % [search_count, filter_label]
