class_name EffectMesagoza
extends BaseEffect

const STEP_ID := "mesagoza_pokemon"

var _coin_flipper: CoinFlipper = null
var _pending_heads: bool = false
var _has_pending_flip: bool = false


func _init(flipper: CoinFlipper = null) -> void:
	_coin_flipper = flipper


func can_use_as_stadium_action(_card: CardInstance, _state: GameState) -> bool:
	return true


func can_execute(_card: CardInstance, state: GameState) -> bool:
	return not state.players[state.current_player_index].deck.is_empty()


func can_headless_execute(_card: CardInstance, state: GameState) -> bool:
	return not _matching_pokemon(state.players[state.current_player_index]).is_empty()


func get_preview_interaction_steps(_card: CardInstance, _state: GameState) -> Array[Dictionary]:
	return [{
		"id": "coin_flip_preview",
		"title": "投掷1枚硬币",
		"wait_for_coin_animation": true,
		"preview_only": true,
	}]


func get_interaction_steps(_card: CardInstance, state: GameState) -> Array[Dictionary]:
	var flipper: CoinFlipper = _coin_flipper if _coin_flipper != null else CoinFlipper.new()
	_pending_heads = flipper.flip()
	_has_pending_flip = true
	if not _pending_heads:
		return []
	var player: PlayerState = state.players[state.current_player_index]
	var items: Array = _matching_pokemon(player)
	var labels: Array[String] = []
	for deck_card: CardInstance in items:
		labels.append(deck_card.card_data.name)
	if items.is_empty():
		return [build_empty_search_resolution_step("牌库里没有宝可梦。")]
	var step := build_full_library_search_step(
		STEP_ID,
		"从牌库中选择1张宝可梦加入手牌",
		player.deck,
		items,
		VISIBLE_SCOPE_OWN_FULL_DECK,
		1,
		1,
		{"allow_cancel": true}
	)
	step["wait_for_coin_animation"] = true
	return [step]


func execute(_card: CardInstance, targets: Array, state: GameState) -> void:
	if not _has_pending_flip:
		var flipper: CoinFlipper = _coin_flipper if _coin_flipper != null else CoinFlipper.new()
		_pending_heads = flipper.flip()
		_has_pending_flip = true
	if not _pending_heads:
		_has_pending_flip = false
		return
	var player: PlayerState = state.players[state.current_player_index]
	var ctx: Dictionary = get_interaction_context(targets)
	var chosen: CardInstance = null
	var raw: Array = ctx.get(STEP_ID, [])
	var matches: Array = _matching_pokemon(player)
	for entry: Variant in raw:
		if entry is CardInstance and entry in matches:
			chosen = entry
			break
	if chosen == null and not ctx.has(STEP_ID):
		chosen = matches[0] if not matches.is_empty() else null
	if chosen != null:
		_move_public_cards_to_hand_with_log(state, state.current_player_index, [chosen], _card, "stadium", "search_to_hand", ["宝可梦"])
	player.shuffle_deck()
	_has_pending_flip = false


func _matching_pokemon(player: PlayerState) -> Array:
	var result: Array = []
	for deck_card: CardInstance in player.deck:
		if deck_card.card_data != null and deck_card.card_data.is_pokemon():
			result.append(deck_card)
	return result
