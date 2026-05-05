## Lost Vacuum - discard 1 card, then remove a Tool or Stadium
class_name EffectLostVacuum
extends BaseEffect

const DISCARD_STEP_ID := "discard_cards"
const TARGET_STEP_ID := "lost_vacuum_target"


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var pi: int = card.owner_index
	var player: PlayerState = state.players[pi]
	var hand_items: Array = []
	var hand_labels: Array[String] = []
	for hand_card: CardInstance in player.hand:
		if hand_card == card:
			continue
		hand_items.append(hand_card)
		hand_labels.append(hand_card.card_data.name)

	var target_items: Array = []
	var target_labels: Array[String] = []
	if state.stadium_card != null:
		target_items.append(state.stadium_card)
		target_labels.append("竞技场：%s" % state.stadium_card.card_data.name)
	for slot_pi: int in 2:
		for slot: PokemonSlot in state.players[slot_pi].get_all_pokemon():
			if slot.attached_tool == null:
				continue
			target_items.append(slot.attached_tool)
			target_labels.append("玩家%d %s上的道具：%s" % [slot_pi, slot.get_pokemon_name(), slot.attached_tool.card_data.name])
	var target_groups: Array[Dictionary] = []
	for slot_pi: int in 2:
		target_groups.append_array(build_attached_card_groups(state.players[slot_pi], target_items))

	return [
		{
			"id": DISCARD_STEP_ID,
			"title": "选择1张手牌放入放逐区",
			"items": hand_items,
			"labels": hand_labels,
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": true,
		},
		{
			"id": TARGET_STEP_ID,
			"title": "选择1张场上的宝可梦道具或竞技场放入放逐区",
			"items": target_items,
			"labels": target_labels,
			"card_groups": target_groups,
			"transparent_battlefield_dialog": true,
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": true,
		},
	]


func can_execute(card: CardInstance, state: GameState) -> bool:
	var pi: int = card.owner_index
	var player: PlayerState = state.players[pi]
	var other_hand_cards: int = 0
	for hand_card: CardInstance in player.hand:
		if hand_card != card:
			other_hand_cards += 1
	if other_hand_cards < 1:
		return false
	if state.stadium_card != null:
		return true
	for slot_pi: int in 2:
		for slot: PokemonSlot in state.players[slot_pi].get_all_pokemon():
			if slot.attached_tool != null:
				return true
	return false


func execute(card: CardInstance, _targets: Array, state: GameState) -> void:
	var pi: int = card.owner_index
	var player: PlayerState = state.players[pi]
	var ctx: Dictionary = get_interaction_context(_targets)

	var discarded: CardInstance = _resolve_discard_card(card, player, ctx)
	if discarded != null:
		player.hand.erase(discarded)
		player.lost_zone.append(discarded)

	var target_card: CardInstance = _resolve_target_card(state, ctx)
	if target_card == null:
		return
	if target_card == state.stadium_card:
		var stadium_owner: PlayerState = state.players[state.stadium_owner_index]
		stadium_owner.lost_zone.append(state.stadium_card)
		state.stadium_card = null
		state.stadium_owner_index = -1
		return

	for slot_pi: int in 2:
		var owner: PlayerState = state.players[slot_pi]
		for slot: PokemonSlot in owner.get_all_pokemon():
			if slot.attached_tool == target_card:
				owner.lost_zone.append(slot.attached_tool)
				slot.attached_tool = null
				return


func _resolve_discard_card(card: CardInstance, player: PlayerState, ctx: Dictionary) -> CardInstance:
	var selected_raw: Array = ctx.get(DISCARD_STEP_ID, [])
	if not selected_raw.is_empty() and selected_raw[0] is CardInstance:
		var selected: CardInstance = selected_raw[0]
		if selected in player.hand and selected != card:
			return selected
	for hand_card: CardInstance in player.hand:
		if hand_card != card:
			return hand_card
	return null


func _resolve_target_card(state: GameState, ctx: Dictionary) -> CardInstance:
	var selected_raw: Array = ctx.get(TARGET_STEP_ID, [])
	if not selected_raw.is_empty() and selected_raw[0] is CardInstance:
		var selected: CardInstance = selected_raw[0]
		if selected == state.stadium_card:
			return selected
		for player: PlayerState in state.players:
			for slot: PokemonSlot in player.get_all_pokemon():
				if slot.attached_tool == selected:
					return selected
	if state.stadium_card != null:
		return state.stadium_card
	for player: PlayerState in state.players:
		for slot: PokemonSlot in player.get_all_pokemon():
			if slot.attached_tool != null:
				return slot.attached_tool
	return null


func get_description() -> String:
	return "将1张手牌放入放逐区，然后选择场上的1张宝可梦道具或竞技场放入放逐区。"
