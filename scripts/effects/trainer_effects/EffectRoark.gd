## 瓢太（CSV6C 124）
## 从牌库上方抽取2张卡牌，然后选择弃牌区中的1张基本能量加入手牌。
class_name EffectRoark
extends BaseEffect

const STEP_ID := "roark_basic_energy"
const DRAW_COUNT := 2


func can_execute(card: CardInstance, state: GameState) -> bool:
	if not _has_valid_owner(card, state):
		return false
	var player: PlayerState = state.players[card.owner_index]
	return not player.deck.is_empty() or not _basic_energies(player).is_empty()


func can_headless_execute(card: CardInstance, state: GameState) -> bool:
	return can_execute(card, state)


func get_unusable_reason(card: CardInstance, state: GameState) -> String:
	if not _has_valid_owner(card, state):
		return "卡牌或游戏状态无效。"
	return "牌库为空，弃牌区也没有可回收的基本能量。"


func get_empty_interaction_message(card: CardInstance, state: GameState) -> String:
	return get_unusable_reason(card, state)


func build_ucis_interaction_steps_spec_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	if not _has_valid_owner(card, state):
		return []
	var energies: Array[CardInstance] = _basic_energies(state.players[card.owner_index])
	if energies.is_empty():
		return []
	var labels: Array[String] = []
	for energy: CardInstance in energies:
		labels.append(energy.card_data.name)
	return [{
		"id": STEP_ID,
		"title": "选择弃牌区中的1张基本能量，展示后加入手牌",
		"items": energies,
		"labels": labels,
		"presentation": "cards",
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
	}]


func validate_card_interaction(card: CardInstance, targets: Array, state: GameState) -> Dictionary:
	if not _has_valid_owner(card, state):
		return interaction_validation_error("invalid Roark owner or game state")
	var energies: Array[CardInstance] = _basic_energies(state.players[card.owner_index])
	if energies.is_empty():
		return interaction_validation_ok()
	return validate_context_selection(
		get_interaction_context(targets),
		STEP_ID,
		energies,
		1,
		1
	)


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	if not _has_valid_owner(card, state):
		return
	var player: PlayerState = state.players[card.owner_index]
	var selected_energy: Array[CardInstance] = []
	var selected_raw: Array = get_interaction_context(targets).get(STEP_ID, [])
	for entry: Variant in selected_raw:
		if entry is CardInstance and entry in player.discard_pile and _is_basic_energy(entry):
			selected_energy.append(entry)
			break

	_draw_cards_with_log(state, card.owner_index, DRAW_COUNT, card, "trainer")
	_move_discard_cards_to_hand_with_log(
		state,
		card.owner_index,
		selected_energy,
		card,
		"trainer"
	)


func _basic_energies(player: PlayerState) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	if player == null:
		return result
	for discard_card: CardInstance in player.discard_pile:
		if _is_basic_energy(discard_card):
			result.append(discard_card)
	return result


func _is_basic_energy(card: CardInstance) -> bool:
	return (
		card != null
		and card.card_data != null
		and card.card_data.card_type == "Basic Energy"
	)


func _has_valid_owner(card: CardInstance, state: GameState) -> bool:
	return (
		card != null
		and state != null
		and card.owner_index >= 0
		and card.owner_index < state.players.size()
	)


func get_description() -> String:
	return "从自己牌库上方抽取2张卡牌。选择自己弃牌区中的1张基本能量，在给对手看过之后，加入手牌。"
