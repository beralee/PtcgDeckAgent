class_name AbilityLookTopToHand
extends BaseEffect

const USED_FLAG_TYPE := "ability_look_top_to_hand_used"

var look_count: int = 2
var filter_type: String = ""
var active_only: bool = false
var shuffle_remaining: bool = false
var bottom_remaining: bool = true


func _init(
	look: int = 2,
	filter: String = "",
	require_active: bool = false,
	shuffle_rest: bool = false,
	bottom_rest: bool = true
) -> void:
	look_count = look
	filter_type = filter
	active_only = require_active
	shuffle_remaining = shuffle_rest
	bottom_remaining = bottom_rest


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	if pokemon == null or state == null:
		return false
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return false
	if top.owner_index < 0 or top.owner_index >= state.players.size():
		return false
	if state.current_player_index != top.owner_index:
		return false
	if state.phase != GameState.GamePhase.MAIN:
		return false
	if active_only and state.players[top.owner_index].active_pokemon != pokemon:
		return false
	for effect_data: Dictionary in pokemon.effects:
		if effect_data.get("type", "") == USED_FLAG_TYPE and effect_data.get("turn", -1) == state.turn_number:
			return false
	return not state.players[top.owner_index].deck.is_empty()


func can_headless_execute(card: CardInstance, state: GameState) -> bool:
	if card == null or state == null:
		return false
	if card.owner_index < 0 or card.owner_index >= state.players.size():
		return false
	return not _get_matching_cards(state.players[card.owner_index]).is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	if card == null or state == null:
		return []
	if card.owner_index < 0 or card.owner_index >= state.players.size():
		return []
	var player: PlayerState = state.players[card.owner_index]
	var visible_cards := _get_looked_cards(player)
	var items := _get_matching_cards(player)
	if items.is_empty():
		return [
			build_empty_search_resolution_step_with_view_label(
				"%s：查看到的牌里没有%s。你仍可以使用这个特性。" % [card.card_data.name, _get_filter_label()],
				"查看卡牌"
			)
		]

	return [build_full_library_search_step(
		"look_top_pick",
		"从牌库上方%d张中选择最多1张%s加入手牌" % [visible_cards.size(), _get_filter_label()],
		visible_cards,
		items,
		"own_top_%d_cards" % visible_cards.size(),
		0,
		mini(1, items.size()),
		{
			"allow_cancel": true,
			"card_disabled_badge": "不可选",
			"card_selectable_hint": "可选",
			"show_selectable_hints": true,
			"force_confirm": true,
		}
	)]


func get_followup_interaction_steps(
	card: CardInstance,
	state: GameState,
	resolved_context: Dictionary
) -> Array[Dictionary]:
	if card == null or state == null:
		return []
	if card.owner_index < 0 or card.owner_index >= state.players.size():
		return []
	if not should_preview_empty_search_deck(resolved_context):
		return []
	return [
		build_readonly_card_preview_step(
			"%s：查看已查看的卡牌" % card.card_data.name,
			_get_looked_cards(state.players[card.owner_index])
		)
	]


func execute_ability(
	pokemon: PokemonSlot,
	_ability_index: int,
	targets: Array,
	state: GameState
) -> void:
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return
	var player: PlayerState = state.players[top.owner_index]
	var look_cards: Array[CardInstance] = _get_looked_cards(player)

	var ctx: Dictionary = get_interaction_context(targets)
	var selected_raw: Array = ctx.get("look_top_pick", [])
	var chosen: CardInstance = null
	if not selected_raw.is_empty() and selected_raw[0] is CardInstance and selected_raw[0] in look_cards and _matches_filter(selected_raw[0]):
		chosen = selected_raw[0]

	if chosen != null:
		player.deck.erase(chosen)
		player.hand.append(chosen)
		look_cards.erase(chosen)

	for remaining: CardInstance in look_cards:
		player.deck.erase(remaining)
	if bottom_remaining:
		for remaining: CardInstance in look_cards:
			player.deck.append(remaining)
	elif shuffle_remaining:
		for remaining: CardInstance in look_cards:
			player.deck.append(remaining)
		player.shuffle_deck()

	pokemon.effects.append({"type": USED_FLAG_TYPE, "turn": state.turn_number})


func _matches_filter(card: CardInstance) -> bool:
	if card == null or card.card_data == null:
		return false
	if filter_type == "":
		return true
	return card.card_data.card_type == filter_type


func _get_looked_cards(player: PlayerState) -> Array[CardInstance]:
	var looked_cards: Array[CardInstance] = []
	if player == null:
		return looked_cards
	for idx: int in mini(look_count, player.deck.size()):
		looked_cards.append(player.deck[idx])
	return looked_cards


func _get_matching_cards(player: PlayerState) -> Array[CardInstance]:
	var matches: Array[CardInstance] = []
	for deck_card: CardInstance in _get_looked_cards(player):
		if _matches_filter(deck_card):
			matches.append(deck_card)
	return matches


func _get_filter_label() -> String:
	match filter_type:
		"Pokemon":
			return "宝可梦"
		"Supporter":
			return "支援者"
		"Evolution":
			return "进化宝可梦"
		"Basic":
			return "基础宝可梦"
		"Item":
			return "物品"
		"Tool":
			return "宝可梦道具"
		"Energy":
			return "能量"
		_:
			return "卡牌" if filter_type == "" else filter_type


func get_description() -> String:
	return "Look at the top cards of your deck and add one to your hand."
