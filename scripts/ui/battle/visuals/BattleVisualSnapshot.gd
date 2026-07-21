class_name BattleVisualSnapshot
extends RefCounted


static func capture(game_state: GameState) -> Dictionary:
	if game_state == null:
		return {}
	var snapshot: Dictionary = {
		"turn_number": int(game_state.turn_number),
		"phase": int(game_state.phase),
		"current_player_index": int(game_state.current_player_index),
		"winner_index": int(game_state.winner_index),
		"win_reason": str(game_state.win_reason),
		"cards_by_id": {},
		"card_locations": {},
		"zones": {},
		"slots": {},
		"shuffle_counts": {},
		"stadium_owner_index": int(game_state.stadium_owner_index),
	}
	for player_index: int in range(game_state.players.size()):
		var player: PlayerState = game_state.players[player_index]
		if player == null:
			continue
		_capture_player(snapshot, player_index, player)
	if game_state.stadium_card != null:
		_capture_zone_cards(snapshot, "stadium", [game_state.stadium_card])
	else:
		(snapshot["zones"] as Dictionary)["stadium"] = []
	return snapshot


static func signature(snapshot: Dictionary) -> String:
	if snapshot.is_empty():
		return ""
	var parts: Array[String] = [
		str(snapshot.get("turn_number", -1)),
		str(snapshot.get("phase", -1)),
		str(snapshot.get("current_player_index", -1)),
		str(snapshot.get("winner_index", -1)),
		str(snapshot.get("win_reason", "")),
	]
	var zones: Dictionary = snapshot.get("zones", {})
	var zone_keys: Array = zones.keys()
	zone_keys.sort()
	for zone_key_variant: Variant in zone_keys:
		var zone_key := str(zone_key_variant)
		parts.append("%s=%s" % [zone_key, _join_ints(zones.get(zone_key, []))])
	var slots: Dictionary = snapshot.get("slots", {})
	var slot_keys: Array = slots.keys()
	slot_keys.sort()
	for slot_key_variant: Variant in slot_keys:
		var slot: Dictionary = slots.get(slot_key_variant, {})
		parts.append("%s:%s:%s:%s" % [
			str(slot_key_variant),
			str(slot.get("slot_runtime_id", -1)),
			str(slot.get("damage_counters", 0)),
			JSON.stringify(slot.get("status_conditions", {})),
		])
	return "|".join(parts)


static func retain_temporarily_missing_cards(previous: Dictionary, current: Dictionary) -> Dictionary:
	if previous.is_empty() or current.is_empty():
		return current
	var merged: Dictionary = current.duplicate(true)
	var previous_cards: Dictionary = previous.get("cards_by_id", {})
	var current_cards: Dictionary = merged.get("cards_by_id", {})
	var previous_locations: Dictionary = previous.get("card_locations", {})
	var current_locations: Dictionary = merged.get("card_locations", {})
	var zones: Dictionary = merged.get("zones", {})
	for card_id_variant: Variant in previous_cards.keys():
		var card_id := int(card_id_variant)
		if current_cards.has(card_id):
			continue
		var old_location := str(previous_locations.get(card_id, ""))
		if old_location == "":
			continue
		current_cards[card_id] = previous_cards.get(card_id, {})
		current_locations[card_id] = old_location
		var zone_ids_variant: Variant = zones.get(old_location, [])
		var zone_ids: Array = zone_ids_variant if zone_ids_variant is Array else []
		if not zone_ids.has(card_id):
			zone_ids.append(card_id)
		zones[old_location] = zone_ids
	merged["cards_by_id"] = current_cards
	merged["card_locations"] = current_locations
	merged["zones"] = zones
	return merged


static func _capture_player(snapshot: Dictionary, player_index: int, player: PlayerState) -> void:
	_capture_zone_cards(snapshot, "p%d.deck" % player_index, player.deck)
	_capture_zone_cards(snapshot, "p%d.hand" % player_index, player.hand)
	_capture_zone_cards(snapshot, "p%d.discard" % player_index, player.discard_pile)
	_capture_zone_cards(snapshot, "p%d.lost" % player_index, player.lost_zone)
	var prize_layout: Array = player.get_prize_layout()
	for prize_index: int in range(prize_layout.size()):
		var prize_card: CardInstance = prize_layout[prize_index] as CardInstance
		_capture_zone_cards(
			snapshot,
			"p%d.prize.%d" % [player_index, prize_index],
			[prize_card] if prize_card != null else []
		)
	_capture_slot(snapshot, player_index, "active", -1, player.active_pokemon)
	for bench_index: int in range(player.bench.size()):
		_capture_slot(snapshot, player_index, "bench", bench_index, player.bench[bench_index])
	(snapshot["shuffle_counts"] as Dictionary)[player_index] = int(player.shuffle_count)


static func _capture_slot(
	snapshot: Dictionary,
	player_index: int,
	slot_kind: String,
	slot_index: int,
	slot: PokemonSlot
) -> void:
	if slot == null:
		return
	var slot_key := "p%d.active" % player_index if slot_kind == "active" else "p%d.bench.%d" % [player_index, slot_index]
	var stack_zone := "%s.stack" % slot_key
	var energy_zone := "%s.energy" % slot_key
	var tool_zone := "%s.tool" % slot_key
	_capture_zone_cards(snapshot, stack_zone, slot.pokemon_stack)
	_capture_zone_cards(snapshot, energy_zone, slot.attached_energy)
	_capture_zone_cards(snapshot, tool_zone, [slot.attached_tool] if slot.attached_tool != null else [])
	var stack_ids: Array = (snapshot["zones"] as Dictionary).get(stack_zone, [])
	var energy_ids: Array = (snapshot["zones"] as Dictionary).get(energy_zone, [])
	var tool_ids: Array = (snapshot["zones"] as Dictionary).get(tool_zone, [])
	(snapshot["slots"] as Dictionary)[slot_key] = {
		"slot_key": slot_key,
		"slot_runtime_id": int(slot.get_instance_id()),
		"player_index": player_index,
		"slot_kind": slot_kind,
		"slot_index": slot_index,
		"pokemon_stack": stack_ids.duplicate(),
		"attached_energy": energy_ids.duplicate(),
		"attached_tool": int(tool_ids[0]) if not tool_ids.is_empty() else -1,
		"damage_counters": int(slot.damage_counters),
		"remaining_hp": int(slot.get_remaining_hp()),
		"max_hp": int(slot.get_max_hp()),
		"status_conditions": slot.status_conditions.duplicate(true),
	}


static func _capture_zone_cards(snapshot: Dictionary, zone_key: String, cards: Array) -> void:
	var ids: Array[int] = []
	for card_variant: Variant in cards:
		var card: CardInstance = card_variant as CardInstance
		if card == null:
			continue
		ids.append(int(card.instance_id))
		(snapshot["cards_by_id"] as Dictionary)[card.instance_id] = _capture_card(card)
		(snapshot["card_locations"] as Dictionary)[card.instance_id] = zone_key
	(snapshot["zones"] as Dictionary)[zone_key] = ids


static func _capture_card(card: CardInstance) -> Dictionary:
	return {
		"instance_id": int(card.instance_id),
		"owner_index": int(card.owner_index),
		"face_up": bool(card.face_up),
		"card_name": card.card_data.name if card.card_data != null else "",
		"card_type": card.card_data.card_type if card.card_data != null else "",
		"card": card,
	}


static func _join_ints(values: Variant) -> String:
	if not values is Array:
		return ""
	var strings: Array[String] = []
	for value: Variant in values as Array:
		strings.append(str(int(value)))
	return ",".join(strings)
