class_name EffectScoopUpCyclone
extends BaseEffect

const CSV9CEffects = preload("res://scripts/effects/CSV9CEffects.gd")

const TARGET_STEP_ID := "scoop_up_cyclone_target"
const REPLACEMENT_STEP_ID := "scoop_up_cyclone_replacement"


func can_execute(card: CardInstance, state: GameState) -> bool:
	if card == null or state == null or card.owner_index < 0 or card.owner_index >= state.players.size():
		return false
	if CSV9CEffects.player_field_return_to_hand_blocked(card.owner_index, state):
		return false
	return not _get_valid_targets(state.players[card.owner_index]).is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	if card == null or state == null or card.owner_index < 0 or card.owner_index >= state.players.size():
		return []
	if CSV9CEffects.player_field_return_to_hand_blocked(card.owner_index, state):
		return []

	var player: PlayerState = state.players[card.owner_index]
	var targets: Array[PokemonSlot] = _get_valid_targets(player)
	if targets.is_empty():
		return []

	var target_items: Array = []
	var target_labels: Array[String] = []
	for slot: PokemonSlot in targets:
		target_items.append(slot)
		target_labels.append(_build_slot_label(slot))

	return [{
		"id": TARGET_STEP_ID,
		"title": "选择1只自己的宝可梦放回手牌",
		"items": target_items,
		"labels": target_labels,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
		"requires_followup_interaction": true,
	}]


func get_followup_interaction_steps(
	card: CardInstance,
	state: GameState,
	resolved_context: Dictionary
) -> Array[Dictionary]:
	if card == null or state == null or card.owner_index < 0 or card.owner_index >= state.players.size():
		return []
	if CSV9CEffects.player_field_return_to_hand_blocked(card.owner_index, state):
		return []
	if not resolved_context.has(TARGET_STEP_ID):
		return []

	var player: PlayerState = state.players[card.owner_index]
	var target: PokemonSlot = _get_explicit_selected_target(resolved_context, player)
	if target == null or target != player.active_pokemon:
		return []

	var step := _build_replacement_step(player)
	var items: Array = step.get("items", [])
	if items.is_empty():
		return []
	var followup: Array[Dictionary] = []
	followup.append(step)
	return followup


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	if card == null or state == null or card.owner_index < 0 or card.owner_index >= state.players.size():
		return
	if CSV9CEffects.player_field_return_to_hand_blocked(card.owner_index, state):
		return

	var player: PlayerState = state.players[card.owner_index]
	var ctx: Dictionary = get_interaction_context(targets)
	var target: PokemonSlot = _get_selected_target(ctx, player)
	if target == null:
		return

	var is_active := target == player.active_pokemon
	var replacement: PokemonSlot = null
	if is_active:
		replacement = _get_selected_replacement(ctx, player)
		if replacement == null:
			return

	_return_slot_cards_to_hand(target, player)

	if is_active:
		player.active_pokemon = replacement
		player.bench.erase(replacement)
	else:
		player.bench.erase(target)


func get_description() -> String:
	return "选择自己场上的1只宝可梦，将那只宝可梦以及附着在其身上的所有卡牌放回手牌。"


func _get_valid_targets(player: PlayerState) -> Array[PokemonSlot]:
	var targets: Array[PokemonSlot] = []
	if player == null:
		return targets
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot == null or slot.get_top_card() == null:
			continue
		if slot == player.active_pokemon and player.bench.is_empty():
			continue
		targets.append(slot)
	return targets


func _build_slot_label(slot: PokemonSlot) -> String:
	if slot == null:
		return ""
	return "%s (HP %d/%d)" % [
		slot.get_pokemon_name(),
		slot.get_remaining_hp(),
		slot.get_max_hp(),
	]


func _build_replacement_step(player: PlayerState) -> Dictionary:
	var replacement_items: Array = []
	var replacement_labels: Array[String] = []
	if player != null:
		for slot: PokemonSlot in player.bench:
			if slot == null or slot.get_top_card() == null:
				continue
			replacement_items.append(slot)
			replacement_labels.append(_build_slot_label(slot))
	return {
		"id": REPLACEMENT_STEP_ID,
		"title": "选择新的战斗宝可梦",
		"items": replacement_items,
		"labels": replacement_labels,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
	}


func _get_explicit_selected_target(ctx: Dictionary, player: PlayerState) -> PokemonSlot:
	var valid_targets: Array[PokemonSlot] = _get_valid_targets(player)
	var raw: Array = ctx.get(TARGET_STEP_ID, [])
	if not raw.is_empty() and raw[0] is PokemonSlot:
		var selected: PokemonSlot = raw[0]
		if selected in valid_targets:
			return selected
	return null


func _get_selected_target(ctx: Dictionary, player: PlayerState) -> PokemonSlot:
	var selected := _get_explicit_selected_target(ctx, player)
	if selected != null:
		return selected
	var valid_targets: Array[PokemonSlot] = _get_valid_targets(player)
	if not valid_targets.is_empty():
		return valid_targets[0]
	return null


func _get_selected_replacement(ctx: Dictionary, player: PlayerState) -> PokemonSlot:
	if player == null or player.bench.is_empty():
		return null
	var raw: Array = ctx.get(REPLACEMENT_STEP_ID, [])
	if not raw.is_empty() and raw[0] is PokemonSlot:
		var selected: PokemonSlot = raw[0]
		if selected in player.bench:
			return selected
	return player.bench[0]


func _return_slot_cards_to_hand(slot: PokemonSlot, player: PlayerState) -> void:
	if slot == null or player == null:
		return
	for slot_card: CardInstance in slot.collect_all_cards():
		if slot_card == null:
			continue
		slot_card.face_up = true
		player.hand.append(slot_card)
	slot.pokemon_stack.clear()
	slot.attached_energy.clear()
	slot.attached_tool = null
	slot.damage_counters = 0
	slot.clear_all_status()
	slot.effects.clear()
