class_name BattleActionIntentModel
extends RefCounted

const BenchLimit := preload("res://scripts/engine/BenchLimitHelper.gd")


static func build(gsm: GameStateMachine, view_player: int, selected_card: CardInstance = null) -> Dictionary:
	var empty_model := _empty_model()
	if gsm == null or gsm.game_state == null:
		return empty_model
	var state: GameState = gsm.game_state
	if view_player < 0 or view_player >= state.players.size():
		return empty_model
	if state.current_player_index != view_player or state.phase != GameState.GamePhase.MAIN:
		return empty_model

	# Some existing legality predicates expose the EffectProcessor through a turn flag.
	# Restore the dictionary in-place so this read-only projection never changes rules state.
	var flags_before: Dictionary = state.shared_turn_flags.duplicate()
	var model := _build_enabled_model(gsm, state, view_player, selected_card)
	state.shared_turn_flags.clear()
	state.shared_turn_flags.merge(flags_before, true)
	return model


static func _empty_model() -> Dictionary:
	return {
		"enabled": false,
		"mode": "idle",
		"hand_intents": {},
		"slot_intents": {},
		"stadium_intent": {},
		"source_card_instance_id": "",
		"target_slot_ids": [],
	}


static func _build_enabled_model(
	gsm: GameStateMachine,
	state: GameState,
	player_index: int,
	selected_card: CardInstance
) -> Dictionary:
	var model := _empty_model()
	model["enabled"] = true
	var player: PlayerState = state.players[player_index]
	var hand_intents: Dictionary = {}
	for card: CardInstance in player.hand:
		if card == null or card.card_data == null:
			continue
		hand_intents[card.instance_id] = _hand_intent(gsm, state, player_index, card)
	model["hand_intents"] = hand_intents
	model["slot_intents"] = _idle_slot_intents(gsm, state, player_index)
	if state.stadium_card != null and gsm.can_use_stadium_effect(player_index):
		model["stadium_intent"] = _actionable("可使用竞技场效果")

	if selected_card != null and selected_card in player.hand and selected_card.card_data != null:
		model["mode"] = "target"
		model["source_card_instance_id"] = selected_card.instance_id
		var targets := _target_slot_ids(gsm, state, player_index, selected_card)
		model["target_slot_ids"] = targets
		var selected_intent: Dictionary = hand_intents.get(selected_card.instance_id, {})
		if not selected_intent.is_empty():
			selected_intent = selected_intent.duplicate(true)
			selected_intent["state"] = "selected"
			selected_intent["label"] = "已选择"
			hand_intents[selected_card.instance_id] = selected_intent
	return model


static func _hand_intent(
	gsm: GameStateMachine,
	state: GameState,
	player_index: int,
	card: CardInstance
) -> Dictionary:
	var data: CardData = card.card_data
	var validator: RuleValidator = gsm.rule_validator
	var processor: EffectProcessor = gsm.effect_processor
	var reason := ""
	match data.card_type:
		"Supporter":
			reason = validator.get_play_supporter_unusable_reason(state, player_index, card, processor)
			if reason != "" and gsm.has_method("_can_play_supporter_exception") and bool(gsm.call("_can_play_supporter_exception", player_index, card)):
				reason = ""
			if reason == "":
				reason = _effect_unusable_reason(processor, card, state)
		"Item":
			reason = validator.get_play_item_unusable_reason(state, player_index, card, processor)
			if reason == "":
				reason = _effect_unusable_reason(processor, card, state)
		"Stadium":
			reason = validator.get_play_stadium_unusable_reason(state, player_index, card, processor)
		"Basic Energy", "Special Energy":
			reason = validator.get_attach_energy_unusable_reason(state, player_index, card, processor)
		"Tool":
			var tool_targets := _target_slot_ids(gsm, state, player_index, card)
			if tool_targets.is_empty():
				reason = _first_target_reason(gsm, state, player_index, card)
		_:
			if data.is_pokemon():
				if data.is_basic_pokemon() or validator.can_play_basic_to_bench(state, player_index, card, processor):
					reason = validator.get_play_basic_to_bench_unusable_reason(state, player_index, card, processor)
				else:
					var evolution_targets := _target_slot_ids(gsm, state, player_index, card)
					if evolution_targets.is_empty():
						reason = _first_target_reason(gsm, state, player_index, card)
			else:
				reason = "当前没有可执行的卡牌操作。"
	if reason == "":
		return _actionable(_hand_action_label(data))
	return _blocked(reason)


static func _effect_unusable_reason(processor: EffectProcessor, card: CardInstance, state: GameState) -> String:
	if processor == null:
		return ""
	var effect: BaseEffect = processor.get_effect(card.card_data.effect_id)
	if effect == null:
		return ""
	state.shared_turn_flags["_draw_effect_processor"] = processor
	if effect.can_execute(card, state):
		return ""
	return processor.get_effect_unusable_reason(card, state)


static func _target_slot_ids(
	gsm: GameStateMachine,
	state: GameState,
	player_index: int,
	card: CardInstance
) -> Array[String]:
	var targets: Array[String] = []
	if card == null or card.card_data == null:
		return targets
	var data: CardData = card.card_data
	var player: PlayerState = state.players[player_index]
	var validator: RuleValidator = gsm.rule_validator
	var processor: EffectProcessor = gsm.effect_processor
	if data.card_type in ["Basic Energy", "Special Energy"]:
		if validator.can_attach_energy(state, player_index, card, processor):
			for entry: Dictionary in _owned_occupied_slots(player):
				targets.append(str(entry["slot_id"]))
		return targets
	if data.card_type == "Tool":
		for entry: Dictionary in _owned_occupied_slots(player):
			if validator.can_attach_tool(state, player_index, entry["slot"] as PokemonSlot, processor, card):
				targets.append(str(entry["slot_id"]))
		return targets
	if data.is_pokemon() and data.stage != "Basic" and not validator.can_play_basic_to_bench(state, player_index, card, processor):
		for entry: Dictionary in _owned_occupied_slots(player):
			if validator.can_evolve(state, player_index, entry["slot"] as PokemonSlot, card, processor):
				targets.append(str(entry["slot_id"]))
		return targets
	if data.is_pokemon() and validator.can_play_basic_to_bench(state, player_index, card, processor):
		var bench_limit := BenchLimit.get_bench_limit_for_player(state, player)
		for bench_index: int in range(player.bench.size(), bench_limit):
			targets.append("my_bench_%d" % bench_index)
	return targets


static func _first_target_reason(
	gsm: GameStateMachine,
	state: GameState,
	player_index: int,
	card: CardInstance
) -> String:
	var data: CardData = card.card_data
	var player: PlayerState = state.players[player_index]
	var validator: RuleValidator = gsm.rule_validator
	var processor: EffectProcessor = gsm.effect_processor
	if data.card_type == "Tool":
		for entry: Dictionary in _owned_occupied_slots(player):
			var reason := validator.get_attach_tool_unusable_reason(state, player_index, entry["slot"] as PokemonSlot, processor, card)
			if reason != "":
				return reason
		return "场上没有可以附着这张道具的宝可梦。"
	if data.is_pokemon() and data.stage != "Basic":
		for entry: Dictionary in _owned_occupied_slots(player):
			var reason := validator.get_evolve_unusable_reason(state, player_index, entry["slot"] as PokemonSlot, card, processor)
			if reason != "":
				return reason
		return "场上没有符合条件的进化目标。"
	return "当前没有合法目标。"


static func _owned_occupied_slots(player: PlayerState) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if player.active_pokemon != null and player.active_pokemon.get_top_card() != null:
		entries.append({"slot_id": "my_active", "slot": player.active_pokemon})
	for bench_index: int in player.bench.size():
		var slot: PokemonSlot = player.bench[bench_index]
		if slot != null and slot.get_top_card() != null:
			entries.append({"slot_id": "my_bench_%d" % bench_index, "slot": slot})
	return entries


static func _idle_slot_intents(gsm: GameStateMachine, state: GameState, player_index: int) -> Dictionary:
	var intents: Dictionary = {}
	var player: PlayerState = state.players[player_index]
	for entry: Dictionary in _owned_occupied_slots(player):
		var slot_id := str(entry["slot_id"])
		var slot := entry["slot"] as PokemonSlot
		var actions: Array[String] = []
		if _has_usable_ability(gsm.effect_processor, slot, state):
			actions.append("特性")
		if slot_id == "my_active":
			if _has_usable_attack(gsm, state, player_index, slot):
				actions.append("招式")
			if gsm.rule_validator.can_retreat(state, player_index, gsm.effect_processor):
				actions.append("撤退")
		if not actions.is_empty():
			var intent := _actionable(" / ".join(actions))
			var action_kinds: Array[String] = []
			if "特性" in actions:
				action_kinds.append("ability")
			if "招式" in actions:
				action_kinds.append("attack")
			if "撤退" in actions:
				action_kinds.append("retreat")
			intent["action_kinds"] = action_kinds
			intents[slot_id] = intent
	return intents


static func _has_usable_ability(processor: EffectProcessor, slot: PokemonSlot, state: GameState) -> bool:
	if processor == null or slot == null or slot.get_card_data() == null:
		return false
	var native_count := slot.get_card_data().abilities.size()
	for ability_index: int in native_count:
		if processor.can_use_ability(slot, state, ability_index):
			return true
	for granted: Dictionary in processor.get_granted_abilities(slot, state):
		if bool(granted.get("enabled", false)):
			return true
	return false


static func _has_usable_attack(
	gsm: GameStateMachine,
	state: GameState,
	player_index: int,
	slot: PokemonSlot
) -> bool:
	if slot == null or slot.get_card_data() == null:
		return false
	for attack_index: int in slot.get_card_data().attacks.size():
		if gsm.can_use_attack(player_index, attack_index):
			return true
	for granted_attack: Dictionary in gsm.effect_processor.get_granted_attacks(slot, state):
		if gsm.rule_validator.can_use_granted_attack(state, player_index, slot, granted_attack, gsm.effect_processor):
			return true
	return false


static func _hand_action_label(data: CardData) -> String:
	if data == null:
		return "可使用"
	if data.card_type in ["Basic Energy", "Special Energy", "Tool"]:
		return "可选择附着目标"
	if data.is_pokemon():
		return "可选择上场目标"
	return "可使用"


static func _actionable(label: String) -> Dictionary:
	return {"state": "actionable", "label": label, "reason": ""}


static func _blocked(reason: String) -> Dictionary:
	return {"state": "blocked", "label": "", "reason": reason}
