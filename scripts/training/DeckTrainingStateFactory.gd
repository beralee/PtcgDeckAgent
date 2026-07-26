class_name DeckTrainingStateFactory
extends RefCounted


const AutoloadResolverScript := preload("res://scripts/engine/AutoloadResolver.gd")
const ScenarioStateSnapshotScript := preload("res://scripts/engine/scenario/ScenarioStateSnapshot.gd")
const ScenarioStateRestorerScript := preload("res://scripts/engine/scenario/ScenarioStateRestorer.gd")


static func build(scenario: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var card_database: Node = AutoloadResolverScript.get_card_database()
	if card_database == null:
		return {"gsm": null, "snapshot": {}, "errors": ["CardDatabase autoload is unavailable"]}
	var player_deck_id := int(scenario.get("player_deck_id", 0))
	var opponent_deck_id := int(scenario.get("opponent_deck_id", 0))
	# Training scenarios are authored against the frozen built-in 18.0 lists.
	# Resolve those lists identically regardless of whether a deck occupies the
	# player or opponent seat; otherwise an older user-deck id collision can
	# silently change the puzzle card pool.
	var player_deck: DeckData = card_database.call("get_ai_deck", player_deck_id)
	if player_deck == null:
		player_deck = card_database.call("get_deck", player_deck_id)
	var opponent_deck: DeckData = card_database.call("get_ai_deck", opponent_deck_id)
	if opponent_deck == null:
		opponent_deck = card_database.call("get_deck", opponent_deck_id)
	if player_deck == null:
		errors.append("missing player deck %d" % player_deck_id)
	if opponent_deck == null:
		errors.append("missing opponent deck %d" % opponent_deck_id)
	if not errors.is_empty():
		return {"gsm": null, "snapshot": {}, "errors": errors}

	var state := GameState.new()
	state.turn_number = int(scenario.get("turn_number", 8))
	state.current_player_index = 0
	state.first_player_index = int(scenario.get("first_player_index", 0))
	state.phase = GameState.GamePhase.MAIN
	state.energy_attached_this_turn = bool(scenario.get("energy_attached_this_turn", false))
	state.supporter_used_this_turn = bool(scenario.get("supporter_used_this_turn", false))
	state.stadium_played_this_turn = bool(scenario.get("stadium_played_this_turn", false))
	state.retreat_used_this_turn = bool(scenario.get("retreat_used_this_turn", false))
	var knockout_turns: Variant = scenario.get("last_knockout_turn_against", null)
	if knockout_turns is Array and (knockout_turns as Array).size() >= 2:
		state.last_knockout_turn_against = [
			int((knockout_turns as Array)[0]),
			int((knockout_turns as Array)[1]),
		]
	state.players.append(_build_player(card_database, player_deck, 0, scenario.get("player", {}), state.turn_number, errors))
	state.players.append(_build_player(card_database, opponent_deck, 1, scenario.get("opponent", {}), state.turn_number, errors))
	if not errors.is_empty():
		return {"gsm": null, "snapshot": {}, "errors": errors}

	var snapshot: Dictionary = ScenarioStateSnapshotScript.capture(state)
	var restored: Dictionary = ScenarioStateRestorerScript.restore(snapshot)
	for error: Variant in restored.get("errors", []):
		errors.append(str(error))
	var gsm: GameStateMachine = restored.get("gsm", null)
	if gsm != null:
		for player_index: int in 2:
			var total := gsm.count_player_total_cards(player_index)
			if total != 60:
				errors.append("player %d restored card total is %d, expected 60" % [player_index, total])
	return {
		"gsm": gsm if errors.is_empty() else null,
		"snapshot": snapshot,
		"errors": errors,
		"player_deck": player_deck,
		"opponent_deck": opponent_deck,
	}


static func _build_player(
	card_database: Node,
	deck_data: DeckData,
	player_index: int,
	setup_variant: Variant,
	turn_number: int,
	errors: Array[String]
) -> PlayerState:
	var setup: Dictionary = setup_variant if setup_variant is Dictionary else {}
	var player := PlayerState.new()
	player.player_index = player_index
	var pool: Array[CardInstance] = card_database.call("build_deck_instances", deck_data, player_index)
	if pool.size() != 60:
		errors.append("deck %d built %d cards instead of 60" % [deck_data.id, pool.size()])

	player.active_pokemon = _build_slot(pool, setup.get("active", {}), player_index, turn_number, errors, "player%d.active" % player_index)
	for bench_index: int in range((setup.get("bench", []) as Array).size() if setup.get("bench", []) is Array else 0):
		var slot := _build_slot(pool, (setup.get("bench", []) as Array)[bench_index], player_index, turn_number, errors, "player%d.bench[%d]" % [player_index, bench_index])
		if slot != null:
			player.bench.append(slot)
	player.hand = _take_list(pool, setup.get("hand", []), player_index, errors, "player%d.hand" % player_index)
	player.discard_pile = _take_list(pool, setup.get("discard", []), player_index, errors, "player%d.discard" % player_index)
	player.lost_zone = _take_list(pool, setup.get("lost_zone", []), player_index, errors, "player%d.lost_zone" % player_index)
	for card: CardInstance in player.hand:
		card.face_up = player_index == 0
	for card: CardInstance in player.discard_pile:
		card.face_up = true
	for card: CardInstance in player.lost_zone:
		card.face_up = true

	var ordered_deck: Array[CardInstance] = _take_list(pool, setup.get("deck_top", []), player_index, errors, "player%d.deck_top" % player_index)
	var prize_count := clampi(int(setup.get("prize_count", 3)), 1, 6)
	var explicit_prizes: Array[CardInstance] = _take_list(pool, setup.get("prizes", []), player_index, errors, "player%d.prizes" % player_index)
	player.prizes.append_array(explicit_prizes)
	while player.prizes.size() < prize_count and not pool.is_empty():
		player.prizes.append(_take_implicit_prize_card(pool))
	for card: CardInstance in player.prizes:
		card.face_up = false
	player.reset_prize_layout()
	if setup.has("deck_size"):
		var requested_deck_size := maxi(0, int(setup.get("deck_size", 0)))
		if requested_deck_size < ordered_deck.size():
			errors.append("player%d.deck_size cannot be smaller than deck_top" % player_index)
		else:
			var remaining_slots := requested_deck_size - ordered_deck.size()
			while pool.size() > remaining_slots:
				var discarded := _take_implicit_prize_card(pool)
				discarded.face_up = true
				player.discard_pile.append(discarded)
	ordered_deck.append_array(pool)
	for card: CardInstance in ordered_deck:
		card.face_up = false
	player.deck = ordered_deck
	return player


static func _take_implicit_prize_card(pool: Array[CardInstance]) -> CardInstance:
	# Frozen deck JSON groups identical prints together, with Basic Energy commonly
	# occupying the tail. Taking every implicit Prize from one end can therefore
	# remove an entire searchable card or Energy type from the training deck.
	# Preserve one copy of each remaining print unless the scenario explicitly
	# authors that card in `prizes`.
	var counts_by_uid: Dictionary = {}
	for card: CardInstance in pool:
		var uid := _card_uid(card)
		counts_by_uid[uid] = int(counts_by_uid.get(uid, 0)) + 1
	for index: int in range(pool.size() - 1, -1, -1):
		var candidate: CardInstance = pool[index]
		if int(counts_by_uid.get(_card_uid(candidate), 0)) <= 1:
			continue
		pool.remove_at(index)
		return candidate
	return pool.pop_back()


static func _card_uid(card: CardInstance) -> String:
	if card == null or card.card_data == null:
		return "__missing_card_data__"
	var uid := card.card_data.get_uid().strip_edges().to_lower()
	return uid if uid != "" else "__instance_%d" % card.instance_id


static func _build_slot(
	pool: Array[CardInstance],
	spec_variant: Variant,
	player_index: int,
	turn_number: int,
	errors: Array[String],
	path: String
) -> PokemonSlot:
	if not (spec_variant is Dictionary) or (spec_variant as Dictionary).is_empty():
		errors.append("%s is required" % path)
		return null
	var spec: Dictionary = spec_variant
	var stack: Array[CardInstance] = _take_list(pool, spec.get("stack", []), player_index, errors, path + ".stack")
	if stack.is_empty():
		errors.append("%s.stack is empty" % path)
		return null
	var slot := PokemonSlot.new()
	slot.pokemon_stack = stack
	slot.attached_energy = _take_list(pool, spec.get("energy", []), player_index, errors, path + ".energy")
	var tool_ref := str(spec.get("tool", "")).strip_edges()
	if tool_ref != "":
		slot.attached_tool = _take_card(pool, tool_ref, player_index, errors, path + ".tool")
	slot.damage_counters = maxi(0, int(spec.get("damage", 0)))
	slot.turn_played = int(spec.get("turn_played", turn_number - 2))
	slot.turn_evolved = int(spec.get("turn_evolved", turn_number - 1)) if stack.size() > 1 else -1
	slot.mark_entered_play()
	for card: CardInstance in slot.collect_all_cards():
		card.face_up = true
	if slot.get_remaining_hp() <= 0:
		errors.append("%s starts knocked out (%d damage / %d HP)" % [path, slot.damage_counters, slot.get_max_hp()])
	return slot


static func _take_list(pool: Array[CardInstance], refs_variant: Variant, player_index: int, errors: Array[String], path: String) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	if not (refs_variant is Array):
		errors.append("%s must be an Array" % path)
		return result
	for index: int in range((refs_variant as Array).size()):
		var card := _take_card(pool, str((refs_variant as Array)[index]), player_index, errors, "%s[%d]" % [path, index])
		if card != null:
			result.append(card)
	return result


static func _take_card(pool: Array[CardInstance], card_ref: String, _player_index: int, errors: Array[String], path: String) -> CardInstance:
	var normalized := card_ref.strip_edges().to_lower()
	for index: int in range(pool.size()):
		var card: CardInstance = pool[index]
		if card == null or card.card_data == null:
			continue
		var uid := card.card_data.get_uid().to_lower()
		var name := card.card_data.name.strip_edges().to_lower()
		var name_en := card.card_data.name_en.strip_edges().to_lower()
		if normalized == uid or normalized == name or (name_en != "" and normalized == name_en):
			pool.remove_at(index)
			return card
	errors.append("%s cannot consume card %s from frozen deck" % [path, card_ref])
	return null
