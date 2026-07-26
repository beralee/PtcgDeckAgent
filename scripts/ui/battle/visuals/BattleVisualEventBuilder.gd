class_name BattleVisualEventBuilder
extends RefCounted

const PrivacyPolicyScript := preload("res://scripts/ui/battle/visuals/BattleVisualPrivacyPolicy.gd")


static func build(
	before: Dictionary,
	after: Dictionary,
	action: GameAction = null,
	view_player: int = 0
) -> Array[Dictionary]:
	if before.is_empty() or after.is_empty():
		return []
	var events: Array[Dictionary] = []
	var order_ref: Array[int] = [0]
	_append_action_feedback(events, action, before, after, order_ref)

	var moved_slots: Dictionary = _detect_moved_slots(before, after)
	var consumed_card_ids: Dictionary = {}
	_append_stack_changes(events, before, after, action, view_player, moved_slots, consumed_card_ids, order_ref)
	_append_field_moves(events, before, after, moved_slots, consumed_card_ids, order_ref)
	_append_zone_transfers(events, before, after, action, view_player, consumed_card_ids, order_ref)
	_normalize_hand_reset_sequences(events)
	_append_slot_deltas(events, before, after, order_ref)
	_append_shuffle_events(events, before, after, order_ref)
	_append_phase_event(events, before, after, action, order_ref)
	_append_result_event(events, before, after, action, order_ref)
	_remove_redundant_feedback(events)
	events.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_priority := int(left.get("priority", 50))
		var right_priority := int(right.get("priority", 50))
		if left_priority != right_priority:
			return left_priority < right_priority
		return int(left.get("order", 0)) < int(right.get("order", 0))
	)
	for event: Dictionary in events:
		event["view_player"] = view_player
	return events


static func _append_action_feedback(
	events: Array[Dictionary],
	action: GameAction,
	before: Dictionary,
	after: Dictionary,
	order_ref: Array[int]
) -> void:
	if action == null:
		return
	var semantic := ""
	var label := ""
	match action.action_type:
		GameAction.ActionType.PLAY_TRAINER:
			semantic = "trainer_play"
			label = str(action.data.get("card_name", ""))
		GameAction.ActionType.USE_ABILITY:
			semantic = "ability"
			label = str(action.data.get("ability_name", ""))
		GameAction.ActionType.USE_STADIUM:
			semantic = "stadium"
			label = str(action.data.get("card_name", ""))
		GameAction.ActionType.PLAY_STADIUM:
			semantic = "stadium_play"
			label = str(action.data.get("card_name", ""))
	if semantic == "":
		return
	_append_event(events, {
		"kind": "trigger_pulse",
		"priority": 10,
		"player_index": action.player_index,
		"semantic": semantic,
		"label": label,
		"source_slot_key": _action_source_slot(action, after),
		"sequence_group": _sequence_group(action, before, after),
	}, order_ref)


static func _append_stack_changes(
	events: Array[Dictionary],
	before: Dictionary,
	after: Dictionary,
	action: GameAction,
	view_player: int,
	moved_slots: Dictionary,
	consumed_card_ids: Dictionary,
	order_ref: Array[int]
) -> void:
	var before_slots_by_id := _slots_by_runtime_id(before)
	var after_slots_by_id := _slots_by_runtime_id(after)
	var runtime_ids: Array = before_slots_by_id.keys()
	runtime_ids.sort()
	for runtime_id_variant: Variant in runtime_ids:
		var runtime_id := int(runtime_id_variant)
		if not after_slots_by_id.has(runtime_id):
			continue
		var before_slot: Dictionary = before_slots_by_id.get(runtime_id, {})
		var after_slot: Dictionary = after_slots_by_id.get(runtime_id, {})
		var before_stack: Array = before_slot.get("pokemon_stack", [])
		var after_stack: Array = after_slot.get("pokemon_stack", [])
		var added := _array_difference(after_stack, before_stack)
		var removed := _array_difference(before_stack, after_stack)
		if added.is_empty() and removed.is_empty():
			continue
		var ids: Array = added if not added.is_empty() else removed
		for card_id_variant: Variant in ids:
			consumed_card_ids[int(card_id_variant)] = true
		var slot_player_index := int(after_slot.get("player_index", before_slot.get("player_index", -1)))
		var action_target_runtime_id := _evolution_target_runtime_id(action)
		if (
			action != null
			and action.action_type == GameAction.ActionType.EVOLVE
			and (
				slot_player_index != action.player_index
				or (action_target_runtime_id != -1 and runtime_id != action_target_runtime_id)
			)
		):
			# A delayed/stale stack delta must not masquerade as part of this
			# Evolution and animate another player's Pokemon.
			continue
		var source_zone := _first_location(before, ids)
		var target_zone := _first_location(after, ids)
		var card_snapshots := _card_snapshots(after if not added.is_empty() else before, ids)
		var visibility := PrivacyPolicyScript.VISIBILITY_FACE
		var sanitized: Dictionary = PrivacyPolicyScript.sanitize_cards(card_snapshots, visibility)
		var semantic := _stack_semantic(action, before_stack, after_stack, runtime_id, slot_player_index)
		var slot_key := str(after_slot.get("slot_key", before_slot.get("slot_key", "")))
		_append_event(events, {
			"kind": "stack_change",
			"priority": 20,
			"player_index": slot_player_index,
			"owner_index": slot_player_index,
			"semantic": semantic,
			"slot_key": slot_key,
			"slot_runtime_id": runtime_id,
			"source_zone": source_zone,
			"target_zone": target_zone,
			"target_slot_key": slot_key,
			"card_instance_ids": ids.duplicate(),
			"cards": sanitized.get("cards", []),
			"card_names": sanitized.get("card_names", []),
			"visibility": visibility,
			"removed_card_instance_ids": removed.duplicate(),
			"sequence_group": _sequence_group(action, before, after),
		}, order_ref)


static func _append_field_moves(
	events: Array[Dictionary],
	before: Dictionary,
	after: Dictionary,
	moved_slots: Dictionary,
	consumed_card_ids: Dictionary,
	order_ref: Array[int]
) -> void:
	var runtime_ids: Array = moved_slots.keys()
	runtime_ids.sort()
	var before_slots := _slots_by_runtime_id(before)
	var after_slots := _slots_by_runtime_id(after)
	for runtime_id_variant: Variant in runtime_ids:
		var runtime_id := int(runtime_id_variant)
		var before_slot: Dictionary = before_slots.get(runtime_id, {})
		var after_slot: Dictionary = after_slots.get(runtime_id, {})
		var all_ids := _slot_card_ids(before_slot)
		for card_id_variant: Variant in all_ids:
			consumed_card_ids[int(card_id_variant)] = true
		for card_id_variant: Variant in _slot_card_ids(after_slot):
			consumed_card_ids[int(card_id_variant)] = true
		var source_slot_key := str(before_slot.get("slot_key", ""))
		var target_slot_key := str(after_slot.get("slot_key", ""))
		if not source_slot_key.ends_with(".active") and not target_slot_key.ends_with(".active"):
			continue
		var top_id := int((after_slot.get("pokemon_stack", []) as Array).back()) if not (after_slot.get("pokemon_stack", []) as Array).is_empty() else -1
		var card_snapshot: Dictionary = (after.get("cards_by_id", {}) as Dictionary).get(top_id, {})
		var visible_snapshots: Array[Dictionary] = []
		if not card_snapshot.is_empty():
			visible_snapshots.append(card_snapshot)
		var sanitized: Dictionary = PrivacyPolicyScript.sanitize_cards(visible_snapshots, PrivacyPolicyScript.VISIBILITY_FACE)
		_append_event(events, {
			"kind": "field_move",
			"priority": 25,
			"player_index": int(after_slot.get("player_index", -1)),
			"owner_index": int(after_slot.get("player_index", -1)),
			"slot_runtime_id": runtime_id,
			"source_slot_key": source_slot_key,
			"target_slot_key": target_slot_key,
			"card_instance_ids": [top_id] if top_id >= 0 else [],
			"cards": sanitized.get("cards", []),
			"visibility": PrivacyPolicyScript.VISIBILITY_FACE,
		}, order_ref)


static func _append_zone_transfers(
	events: Array[Dictionary],
	before: Dictionary,
	after: Dictionary,
	action: GameAction,
	view_player: int,
	consumed_card_ids: Dictionary,
	order_ref: Array[int]
) -> void:
	var before_locations: Dictionary = before.get("card_locations", {})
	var after_locations: Dictionary = after.get("card_locations", {})
	var card_ids: Array = before_locations.keys()
	card_ids.sort()
	var grouped: Dictionary = {}
	var group_order: Array[String] = []
	var direct_action_card_id := _resolve_direct_action_card_id(before, after, action)
	for card_id_variant: Variant in card_ids:
		var card_id := int(card_id_variant)
		if consumed_card_ids.has(card_id) or not after_locations.has(card_id):
			continue
		var source_zone := str(before_locations.get(card_id, ""))
		var target_zone := str(after_locations.get(card_id, ""))
		if source_zone == target_zone:
			continue
		var card_snapshot: Dictionary = (after.get("cards_by_id", {}) as Dictionary).get(card_id, (before.get("cards_by_id", {}) as Dictionary).get(card_id, {}))
		var visibility: String = PrivacyPolicyScript.resolve_visibility(card_snapshot, source_zone, target_zone, action, view_player)
		var semantic := _transfer_semantic(action, source_zone, target_zone, card_snapshot, direct_action_card_id)
		var grouped_source_zone := _transfer_group_source(source_zone, semantic)
		var owner_index := int(card_snapshot.get("owner_index", -1))
		var key := "%s>%s|%s|%s|owner:%d" % [grouped_source_zone, target_zone, visibility, semantic, owner_index]
		if not grouped.has(key):
			grouped[key] = {
				"ids": [],
				"snapshots": [],
				"source_zone": grouped_source_zone,
				"target_zone": target_zone,
				"visibility": visibility,
				"semantic": semantic,
				"owner_index": owner_index,
			}
			group_order.append(key)
		var group: Dictionary = grouped[key]
		(group["ids"] as Array).append(card_id)
		(group["snapshots"] as Array).append(card_snapshot)
	for key: String in group_order:
		var group: Dictionary = grouped.get(key, {})
		var snapshots: Array[Dictionary] = []
		for value: Variant in group.get("snapshots", []):
			if value is Dictionary:
				snapshots.append(value as Dictionary)
		var sanitized: Dictionary = PrivacyPolicyScript.sanitize_cards(snapshots, str(group.get("visibility", PrivacyPolicyScript.VISIBILITY_BACK)))
		var owner_index := int(group.get("owner_index", -1))
		var target_player_index := _player_index_from_zone(str(group.get("target_zone", "")))
		_append_event(events, {
			"kind": "zone_transfer",
			"priority": _transfer_priority(str(group.get("semantic", ""))),
			"player_index": target_player_index if target_player_index >= 0 else owner_index,
			"owner_index": owner_index,
			"source_zone": str(group.get("source_zone", "")),
			"target_zone": str(group.get("target_zone", "")),
			"visibility": str(group.get("visibility", PrivacyPolicyScript.VISIBILITY_BACK)),
			"semantic": str(group.get("semantic", "zone_transfer")),
			"card_instance_ids": (group.get("ids", []) as Array).duplicate(),
			"cards": sanitized.get("cards", []),
			"card_names": sanitized.get("card_names", []),
			"count": (group.get("ids", []) as Array).size(),
			"sequence_group": _sequence_group(action, before, after),
		}, order_ref)


static func _append_slot_deltas(events: Array[Dictionary], before: Dictionary, after: Dictionary, order_ref: Array[int]) -> void:
	var before_slots := _slots_by_runtime_id(before)
	var after_slots := _slots_by_runtime_id(after)
	var runtime_ids: Array = before_slots.keys()
	runtime_ids.sort()
	for runtime_id_variant: Variant in runtime_ids:
		var runtime_id := int(runtime_id_variant)
		if not after_slots.has(runtime_id):
			continue
		var old_slot: Dictionary = before_slots.get(runtime_id, {})
		var new_slot: Dictionary = after_slots.get(runtime_id, {})
		var old_damage := int(old_slot.get("damage_counters", 0))
		var new_damage := int(new_slot.get("damage_counters", 0))
		if new_damage != old_damage:
			_append_event(events, {
				"kind": "damage_delta" if new_damage > old_damage else "heal_delta",
				"priority": 40,
				"player_index": int(new_slot.get("player_index", -1)),
				"slot_key": str(new_slot.get("slot_key", "")),
				"amount": absi(new_damage - old_damage),
				"before_damage": old_damage,
				"after_damage": new_damage,
			}, order_ref)
		var old_statuses: Dictionary = old_slot.get("status_conditions", {})
		var new_statuses: Dictionary = new_slot.get("status_conditions", {})
		var status_keys: Array = new_statuses.keys()
		for key_variant: Variant in old_statuses.keys():
			if not status_keys.has(key_variant):
				status_keys.append(key_variant)
		status_keys.sort()
		for status_variant: Variant in status_keys:
			var status := str(status_variant)
			var was_active := bool(old_statuses.get(status, false))
			var is_active := bool(new_statuses.get(status, false))
			if was_active == is_active:
				continue
			_append_event(events, {
				"kind": "status_delta",
				"priority": 42,
				"player_index": int(new_slot.get("player_index", -1)),
				"slot_key": str(new_slot.get("slot_key", "")),
				"status": status,
				"active": is_active,
			}, order_ref)


static func _append_shuffle_events(events: Array[Dictionary], before: Dictionary, after: Dictionary, order_ref: Array[int]) -> void:
	var before_counts: Dictionary = before.get("shuffle_counts", {})
	var after_counts: Dictionary = after.get("shuffle_counts", {})
	var player_indices: Array = after_counts.keys()
	player_indices.sort()
	for player_index_variant: Variant in player_indices:
		var player_index := int(player_index_variant)
		var delta := int(after_counts.get(player_index, 0)) - int(before_counts.get(player_index, 0))
		if delta <= 0:
			continue
		_append_event(events, {
			"kind": "shuffle",
			"priority": 60,
			"player_index": player_index,
			"count": delta,
			"zone": "p%d.deck" % player_index,
		}, order_ref)


static func _append_phase_event(
	events: Array[Dictionary],
	before: Dictionary,
	after: Dictionary,
	action: GameAction,
	order_ref: Array[int]
) -> void:
	if action == null:
		return
	var phase_changed := int(before.get("phase", -1)) != int(after.get("phase", -1))
	var semantic := "phase_change"
	var priority := 70
	if action != null:
		if action.action_type == GameAction.ActionType.TURN_START:
			semantic = "turn_start"
			priority = 5
		elif action.action_type == GameAction.ActionType.TURN_END:
			semantic = "turn_end"
		elif action.action_type == GameAction.ActionType.POKEMON_CHECK:
			semantic = "pokemon_check"
	if not phase_changed and semantic == "phase_change":
		return
	_append_event(events, {
		"kind": "phase_banner",
		"priority": priority,
		"semantic": semantic,
		"player_index": action.player_index if action != null else int(after.get("current_player_index", -1)),
		"turn_number": action.turn_number if action != null else int(after.get("turn_number", 0)),
		"before_phase": int(before.get("phase", -1)),
		"after_phase": int(after.get("phase", -1)),
	}, order_ref)


static func _append_result_event(
	events: Array[Dictionary],
	before: Dictionary,
	after: Dictionary,
	action: GameAction,
	order_ref: Array[int]
) -> void:
	var became_game_over := int(after.get("winner_index", -1)) != int(before.get("winner_index", -1)) or str(after.get("win_reason", "")) != str(before.get("win_reason", ""))
	if action != null and action.action_type == GameAction.ActionType.GAME_END:
		became_game_over = true
	if not became_game_over:
		return
	_append_event(events, {
		"kind": "match_result",
		"priority": 100,
		"winner_index": int(after.get("winner_index", action.player_index if action != null else -1)),
		"reason": str(after.get("win_reason", action.data.get("reason", "") if action != null else "")),
	}, order_ref)


static func _append_event(events: Array[Dictionary], event: Dictionary, order_ref: Array[int]) -> void:
	event["order"] = order_ref[0]
	order_ref[0] += 1
	events.append(event)


static func _detect_moved_slots(before: Dictionary, after: Dictionary) -> Dictionary:
	var before_slots := _slots_by_runtime_id(before)
	var after_slots := _slots_by_runtime_id(after)
	var result: Dictionary = {}
	for runtime_id_variant: Variant in before_slots.keys():
		var runtime_id := int(runtime_id_variant)
		if not after_slots.has(runtime_id):
			continue
		var before_key := str((before_slots.get(runtime_id, {}) as Dictionary).get("slot_key", ""))
		var after_key := str((after_slots.get(runtime_id, {}) as Dictionary).get("slot_key", ""))
		if before_key != after_key:
			result[runtime_id] = {"source": before_key, "target": after_key}
	return result


static func _slots_by_runtime_id(snapshot: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var slots: Dictionary = snapshot.get("slots", {})
	for slot_variant: Variant in slots.values():
		if not slot_variant is Dictionary:
			continue
		var slot: Dictionary = slot_variant
		result[int(slot.get("slot_runtime_id", -1))] = slot
	return result


static func _slot_card_ids(slot: Dictionary) -> Array:
	var result: Array = []
	result.append_array(slot.get("pokemon_stack", []))
	result.append_array(slot.get("attached_energy", []))
	var tool_id := int(slot.get("attached_tool", -1))
	if tool_id >= 0:
		result.append(tool_id)
	return result


static func _array_difference(left: Array, right: Array) -> Array:
	var result: Array = []
	for value: Variant in left:
		if not right.has(value):
			result.append(value)
	return result


static func _card_snapshots(snapshot: Dictionary, ids: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var cards: Dictionary = snapshot.get("cards_by_id", {})
	for card_id_variant: Variant in ids:
		var captured: Dictionary = cards.get(int(card_id_variant), {})
		if not captured.is_empty():
			result.append(captured)
	return result


static func _first_location(snapshot: Dictionary, ids: Array) -> String:
	if ids.is_empty():
		return ""
	return str((snapshot.get("card_locations", {}) as Dictionary).get(int(ids[0]), ""))


static func _stack_semantic(
	action: GameAction,
	before_stack: Array,
	after_stack: Array,
	slot_runtime_id: int = -1,
	slot_player_index: int = -1
) -> String:
	if (
		action != null
		and action.action_type == GameAction.ActionType.EVOLVE
		and action.player_index == slot_player_index
		and (
			_evolution_target_runtime_id(action) == -1
			or _evolution_target_runtime_id(action) == slot_runtime_id
		)
	):
		return "evolve"
	if action != null and action.action_type == GameAction.ActionType.PLAY_TRAINER:
		var card_name := str(action.data.get("card_name", "")).to_lower()
		if card_name.contains("神奇糖果") or card_name.contains("rare candy"):
			return "rare_candy"
	return "devolve" if after_stack.size() < before_stack.size() else "stack_change"


static func _evolution_target_runtime_id(action: GameAction) -> int:
	if action == null or action.action_type != GameAction.ActionType.EVOLVE:
		return -1
	return int(action.data.get("target_slot_runtime_id", -1))


static func _transfer_semantic(
	action: GameAction,
	source_zone: String,
	target_zone: String,
	card_snapshot: Dictionary = {},
	direct_action_card_id: int = -1
) -> String:
	if action != null and action.action_type == GameAction.ActionType.KNOCKOUT:
		return "knockout"
	if target_zone.ends_with(".lost"):
		return "lost_zone"
	if source_zone.ends_with(".deck") and target_zone.ends_with(".discard"):
		return "mill"
	if target_zone.ends_with(".energy"):
		return "attach_energy" if source_zone.ends_with(".hand") or source_zone.ends_with(".deck") or source_zone.ends_with(".discard") else "move_energy"
	if source_zone.contains(".energy") and target_zone.ends_with(".discard"):
		return "discard_energy"
	if source_zone.contains(".prize.") and target_zone.ends_with(".hand"):
		return "take_prize"
	if source_zone.ends_with(".hand") and target_zone.ends_with(".deck"):
		return "hand_reset"
	if source_zone.ends_with(".deck") and target_zone.ends_with(".hand"):
		if action != null and action.action_type == GameAction.ActionType.DRAW_CARD:
			return "draw"
		return "search"
	if action != null:
		match action.action_type:
			GameAction.ActionType.PLAY_TRAINER:
				if _is_exact_direct_action_card(action, card_snapshot, source_zone, "card_name", direct_action_card_id):
					return "trainer_play"
			GameAction.ActionType.PLAY_POKEMON:
				if _is_exact_direct_action_card(action, card_snapshot, source_zone, "card_name", direct_action_card_id):
					return "play_pokemon"
			GameAction.ActionType.PLAY_TOOL:
				if _is_exact_direct_action_card(action, card_snapshot, source_zone, "tool", direct_action_card_id):
					return "attach_tool"
			GameAction.ActionType.PLAY_STADIUM:
				if _is_exact_direct_action_card(action, card_snapshot, source_zone, "card_name", direct_action_card_id):
					return "play_stadium"
			GameAction.ActionType.KNOCKOUT:
				return "knockout"
	if source_zone.ends_with(".hand") and target_zone.ends_with(".discard"):
		return "discard"
	return "zone_transfer"


static func _is_exact_direct_action_card(
	action: GameAction,
	card_snapshot: Dictionary,
	source_zone: String,
	action_name_key: String,
	direct_action_card_id: int = -1
) -> bool:
	if action == null or int(card_snapshot.get("owner_index", -1)) != action.player_index:
		return false
	if source_zone != "p%d.hand" % action.player_index:
		return false
	if direct_action_card_id >= 0:
		return int(card_snapshot.get("instance_id", -1)) == direct_action_card_id
	var expected_name := str(action.data.get(action_name_key, ""))
	return expected_name != "" and str(card_snapshot.get("card_name", "")) == expected_name


static func _resolve_direct_action_card_id(
	before: Dictionary,
	after: Dictionary,
	action: GameAction
) -> int:
	if action == null:
		return -1
	var action_name_key := ""
	match action.action_type:
		GameAction.ActionType.PLAY_TRAINER, GameAction.ActionType.PLAY_POKEMON, GameAction.ActionType.PLAY_STADIUM:
			action_name_key = "card_name"
		GameAction.ActionType.PLAY_TOOL:
			action_name_key = "tool"
	if action_name_key == "":
		return -1
	var expected_name := str(action.data.get(action_name_key, ""))
	if expected_name == "":
		return -1
	var source_zone := "p%d.hand" % action.player_index
	var before_ids: Array = (before.get("zones", {}) as Dictionary).get(source_zone, [])
	var before_cards: Dictionary = before.get("cards_by_id", {})
	var after_locations: Dictionary = after.get("card_locations", {})
	var after_zones: Dictionary = after.get("zones", {})
	var best_id := -1
	var best_score := -1
	for id_variant: Variant in before_ids:
		var card_id := int(id_variant)
		var snapshot: Dictionary = before_cards.get(card_id, {})
		if int(snapshot.get("owner_index", -1)) != action.player_index:
			continue
		if str(snapshot.get("card_name", "")) != expected_name:
			continue
		var target_zone := str(after_locations.get(card_id, ""))
		if target_zone == "" or target_zone == source_zone:
			continue
		var target_ids: Array = after_zones.get(target_zone, [])
		var target_position := target_ids.find(card_id)
		var score := maxi(0, target_position)
		if _is_expected_direct_target(action.action_type, target_zone):
			score += 10000
		if score >= best_score:
			best_score = score
			best_id = card_id
	return best_id


static func _is_expected_direct_target(action_type: GameAction.ActionType, target_zone: String) -> bool:
	match action_type:
		GameAction.ActionType.PLAY_TRAINER:
			return target_zone.ends_with(".discard") or target_zone.ends_with(".lost")
		GameAction.ActionType.PLAY_POKEMON:
			return target_zone.ends_with(".stack")
		GameAction.ActionType.PLAY_TOOL:
			return target_zone.ends_with(".tool")
		GameAction.ActionType.PLAY_STADIUM:
			return target_zone == "stadium"
	return false


static func _transfer_group_source(source_zone: String, semantic: String) -> String:
	if semantic != "knockout":
		return source_zone
	for suffix: String in [".stack", ".energy", ".tool"]:
		if source_zone.ends_with(suffix):
			return source_zone.trim_suffix(suffix)
	return source_zone


static func _remove_redundant_feedback(events: Array[Dictionary]) -> void:
	var has_trainer_transfer := false
	for event: Dictionary in events:
		if str(event.get("kind", "")) == "zone_transfer" and str(event.get("semantic", "")) == "trainer_play":
			has_trainer_transfer = true
			break
	if not has_trainer_transfer:
		return
	for index: int in range(events.size() - 1, -1, -1):
		var event: Dictionary = events[index]
		if str(event.get("kind", "")) == "trigger_pulse" and str(event.get("semantic", "")) == "trainer_play":
			events.remove_at(index)


static func _normalize_hand_reset_sequences(events: Array[Dictionary]) -> void:
	var reset_players: Dictionary = {}
	for event: Dictionary in events:
		if str(event.get("semantic", "")) == "hand_reset":
			reset_players[int(event.get("player_index", -1))] = true
	if reset_players.is_empty():
		return
	for event: Dictionary in events:
		if (
			reset_players.has(int(event.get("player_index", -1)))
			and str(event.get("source_zone", "")).ends_with(".deck")
			and str(event.get("target_zone", "")).ends_with(".hand")
		):
			event["semantic"] = "redraw"


static func _transfer_priority(semantic: String) -> int:
	if semantic in ["discard_energy", "hand_reset"]:
		return 15
	if semantic in ["knockout", "lost_zone"]:
		return 50
	if semantic == "take_prize":
		return 55
	return 30


static func _player_index_from_zone(zone: String) -> int:
	if zone.length() >= 2 and zone.begins_with("p") and zone[1].is_valid_int():
		return int(zone[1])
	return -1


static func _action_source_slot(action: GameAction, after: Dictionary) -> String:
	if action == null:
		return ""
	var source_runtime_id := int(action.data.get("source_slot_runtime_id", -1))
	if source_runtime_id >= 0:
		for slot_key_variant: Variant in (after.get("slots", {}) as Dictionary).keys():
			var exact_slot: Dictionary = (after.get("slots", {}) as Dictionary).get(slot_key_variant, {})
			if int(exact_slot.get("slot_runtime_id", -1)) == source_runtime_id:
				return str(slot_key_variant)
	var pokemon_name := str(action.data.get("pokemon_name", ""))
	if pokemon_name == "":
		return "stadium" if action.action_type in [GameAction.ActionType.USE_STADIUM, GameAction.ActionType.PLAY_STADIUM] else ""
	var slots: Dictionary = after.get("slots", {})
	var cards: Dictionary = after.get("cards_by_id", {})
	var slot_keys: Array = slots.keys()
	slot_keys.sort()
	for slot_key_variant: Variant in slot_keys:
		var slot: Dictionary = slots.get(slot_key_variant, {})
		if int(slot.get("player_index", -1)) != action.player_index:
			continue
		var stack: Array = slot.get("pokemon_stack", [])
		if stack.is_empty():
			continue
		var top: Dictionary = cards.get(int(stack.back()), {})
		if str(top.get("card_name", "")) == pokemon_name:
			return str(slot_key_variant)
	return ""


static func _sequence_group(action: GameAction, before: Dictionary, after: Dictionary) -> String:
	if action == null:
		return "refresh:%s>%s" % [str(before.get("turn_number", -1)), str(after.get("turn_number", -1))]
	return "action:%d:%d:%d" % [action.turn_number, action.player_index, int(action.action_type)]
