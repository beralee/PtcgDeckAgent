class_name BattleRecordingController
extends RefCounted

const BattleRecorderScript := preload("res://scripts/engine/BattleRecorder.gd")


func set_battle_recording_output_root(scene: Object, root_path: String) -> void:
	scene.set("_battle_recording_output_root", root_path)
	var battle_recorder: RefCounted = scene.get("_battle_recorder")
	if battle_recorder != null and battle_recorder.has_method("set_output_root"):
		battle_recorder.call("set_output_root", root_path)


func should_record_local_battle(_scene: Object) -> bool:
	return GameManager.current_mode == GameManager.GameMode.TWO_PLAYER


func can_capture_battle_recording_context(scene: Object) -> bool:
	var gsm: Variant = scene.get("_gsm")
	return gsm != null and gsm.game_state != null and gsm.game_state.players.size() >= 2


func capture_battle_recording_context_if_ready(scene: Object) -> void:
	if not bool(scene.get("_battle_recording_started")):
		return
	var battle_recorder: RefCounted = scene.get("_battle_recorder")
	if battle_recorder == null or not can_capture_battle_recording_context(scene):
		return
	if battle_recorder.has_method("update_match_context"):
		battle_recorder.call("update_match_context", build_battle_record_meta(scene), build_battle_initial_state(scene))
	if bool(scene.get("_battle_recording_context_captured")):
		return
	scene.set("_battle_recording_context_captured", true)
	var gsm: Variant = scene.get("_gsm")
	record_battle_event(scene, {
		"event_type": "match_started",
		"player_index": -1,
		"turn_number": gsm.game_state.turn_number,
		"phase": recording_phase_name(scene),
		"mode": "two_player",
		"view_player": int(scene.get("_view_player")),
	})
	record_battle_state_snapshot(scene, "match_start")


func ensure_battle_recording_started(scene: Object) -> void:
	if bool(scene.get("_battle_recording_started")) or not should_record_local_battle(scene):
		return
	var gsm: Variant = scene.get("_gsm")
	if gsm == null or gsm.game_state == null:
		return
	var battle_recorder: RefCounted = BattleRecorderScript.new()
	scene.set("_battle_recorder", battle_recorder)
	if battle_recorder == null:
		return
	var output_root := str(scene.get("_battle_recording_output_root"))
	if output_root != "":
		battle_recorder.call("set_output_root", output_root)
	battle_recorder.call("start_match", build_battle_record_meta(scene), build_battle_initial_state(scene))
	scene.set("_battle_recording_started", true)
	scene.set("_battle_advice_initial_snapshot", scene.call("_build_battle_advice_initial_snapshot"))
	if battle_recorder.has_method("get_match_dir"):
		scene.set("_battle_review_match_dir", str(battle_recorder.call("get_match_dir")))
	capture_battle_recording_context_if_ready(scene)


func record_battle_event(scene: Object, event_data: Dictionary) -> void:
	if not bool(scene.get("_battle_recording_started")):
		return
	var battle_recorder: RefCounted = scene.get("_battle_recorder")
	if battle_recorder == null:
		return
	var sanitized: Variant = sanitize_recording_value(scene, event_data)
	battle_recorder.call("record_event", sanitized if sanitized is Dictionary else {})


func finalize_battle_recording(scene: Object, result_data: Dictionary) -> void:
	if not bool(scene.get("_battle_recording_started")):
		return
	var battle_recorder: RefCounted = scene.get("_battle_recorder")
	if battle_recorder == null:
		return
	battle_recorder.call("finalize_match", result_data)
	if battle_recorder.has_method("get_match_dir"):
		scene.set("_battle_review_match_dir", str(battle_recorder.call("get_match_dir")))
	scene.set("_battle_recording_started", false)
	scene.set("_battle_recording_context_captured", false)


func build_battle_record_meta(scene: Object) -> Dictionary:
	var player_labels: Array[String] = []
	for deck_id_variant: Variant in GameManager.selected_deck_ids:
		var deck_id: int = int(deck_id_variant)
		var deck: DeckData = CardDatabase.get_deck(deck_id)
		if deck != null and deck.deck_name.strip_edges() != "":
			player_labels.append(deck.deck_name)
		else:
			player_labels.append("player_%d" % player_labels.size())
	var gsm: Variant = scene.get("_gsm")
	return {
		"mode": "two_player",
		"player_types": ["human", "human"],
		"selected_deck_ids": GameManager.selected_deck_ids.duplicate(),
		"player_labels": player_labels,
		"first_player_index": gsm.game_state.first_player_index if gsm != null and gsm.game_state != null else GameManager.first_player_choice,
	}


func build_battle_initial_state(scene: Object) -> Dictionary:
	return build_battle_state_snapshot(scene)


func build_battle_state_snapshot(scene: Object) -> Dictionary:
	var gsm: Variant = scene.get("_gsm")
	if gsm == null or gsm.game_state == null:
		return {}
	var state: GameState = gsm.game_state
	return {
		"turn_number": state.turn_number,
		"phase": recording_phase_name(scene),
		"current_player_index": state.current_player_index,
		"first_player_index": state.first_player_index,
		"winner_index": state.winner_index,
		"win_reason": state.win_reason,
		"energy_attached_this_turn": state.energy_attached_this_turn,
		"supporter_used_this_turn": state.supporter_used_this_turn,
		"stadium_played_this_turn": state.stadium_played_this_turn,
		"retreat_used_this_turn": state.retreat_used_this_turn,
		"stadium_card": serialize_card_instance(state.stadium_card),
		"stadium_owner_index": state.stadium_owner_index,
		"stadium_effect_used_turn": state.stadium_effect_used_turn,
		"stadium_effect_used_player": state.stadium_effect_used_player,
		"stadium_effect_used_effect_id": state.stadium_effect_used_effect_id,
		"vstar_power_used": [state.vstar_power_used[0], state.vstar_power_used[1]] if state.vstar_power_used.size() >= 2 else [false, false],
		"last_knockout_turn_against": [state.last_knockout_turn_against[0], state.last_knockout_turn_against[1]] if state.last_knockout_turn_against.size() >= 2 else [-999, -999],
		"shared_turn_flags": state.shared_turn_flags.duplicate(true),
		"players": [
			build_battle_initial_player_state(state.players[0]) if state.players.size() > 0 else {},
			build_battle_initial_player_state(state.players[1]) if state.players.size() > 1 else {},
		],
	}


func build_battle_initial_player_state(player: PlayerState) -> Dictionary:
	if player == null:
		return {}
	return {
		"player_index": player.player_index,
		"hand_count": player.hand.size(),
		"deck_count": player.deck.size(),
		"discard_count": player.discard_pile.size(),
		"prize_count": player.prizes.size(),
		"hand": serialize_card_list(player.hand),
		"deck": serialize_card_list(player.deck),
		"prizes": serialize_card_list(player.prizes),
		"discard_pile": serialize_card_list(player.discard_pile),
		"lost_zone": serialize_card_list(player.lost_zone),
		"active": serialize_pokemon_slot(player.active_pokemon),
		"bench": serialize_slot_list(player.bench),
	}


func slot_record_names(slots: Array) -> Array[String]:
	var names: Array[String] = []
	for slot_variant: Variant in slots:
		names.append(slot_record_name(slot_variant as PokemonSlot if slot_variant is PokemonSlot else null))
	return names


func slot_record_name(slot: PokemonSlot) -> String:
	return slot.get_pokemon_name() if slot != null else ""


func recording_phase_name(scene: Object) -> String:
	var gsm: Variant = scene.get("_gsm")
	if gsm == null or gsm.game_state == null:
		return ""
	return str(gsm.game_state.phase)


func record_battle_state_snapshot(scene: Object, snapshot_reason: String, extra_data: Dictionary = {}) -> void:
	if not bool(scene.get("_battle_recording_started")):
		return
	var gsm: Variant = scene.get("_gsm")
	var event := {
		"event_type": "state_snapshot",
		"snapshot_reason": snapshot_reason,
		"player_index": gsm.game_state.current_player_index if gsm != null and gsm.game_state != null else -1,
		"turn_number": gsm.game_state.turn_number if gsm != null and gsm.game_state != null else 0,
		"phase": recording_phase_name(scene),
		"state": build_battle_state_snapshot(scene),
	}
	for key: Variant in extra_data.keys():
		event[str(key)] = extra_data.get(key)
	record_battle_event(scene, event)


func serialize_slot_list(slots: Array) -> Array[Dictionary]:
	var serialized: Array[Dictionary] = []
	for slot_variant: Variant in slots:
		serialized.append(serialize_pokemon_slot(slot_variant as PokemonSlot if slot_variant is PokemonSlot else null))
	return serialized


func serialize_card_list(cards: Array) -> Array[Dictionary]:
	var serialized: Array[Dictionary] = []
	for card_variant: Variant in cards:
		serialized.append(serialize_card_instance(card_variant as CardInstance if card_variant is CardInstance else null))
	return serialized


func serialize_pokemon_slot(slot: PokemonSlot) -> Dictionary:
	if slot == null:
		return {}
	return {
		"pokemon_name": slot.get_pokemon_name(),
		"prize_count": slot.get_prize_count(),
		"damage_counters": slot.damage_counters,
		"remaining_hp": slot.get_remaining_hp(),
		"max_hp": slot.get_max_hp(),
		"retreat_cost": slot.get_retreat_cost(),
		"attached_energy": serialize_card_list(slot.attached_energy),
		"attached_tool": serialize_card_instance(slot.attached_tool),
		"status_conditions": slot.status_conditions.duplicate(true),
		"effects": slot.effects.duplicate(true),
		"turn_played": slot.turn_played,
		"turn_evolved": slot.turn_evolved,
		"pokemon_stack": serialize_card_list(slot.pokemon_stack),
	}


func serialize_card_instance(card: CardInstance) -> Dictionary:
	if card == null:
		return {}
	var card_data := card.card_data
	return {
		"card_name": card_data.name if card_data != null else "",
		"instance_id": card.instance_id,
		"owner_index": card.owner_index,
		"face_up": card.face_up,
		"card_type": card_data.card_type if card_data != null else "",
		"mechanic": card_data.mechanic if card_data != null else "",
		"description": card_data.description if card_data != null else "",
		"stage": card_data.stage if card_data != null else "",
		"hp": card_data.hp if card_data != null else 0,
		"energy_type": card_data.energy_type if card_data != null else "",
		"effect_id": card_data.effect_id if card_data != null else "",
		"energy_provides": card_data.energy_provides if card_data != null else "",
		"set_code": card_data.set_code if card_data != null else "",
		"card_index": card_data.card_index if card_data != null else "",
		"evolves_from": card_data.evolves_from if card_data != null else "",
		"weakness_energy": card_data.weakness_energy if card_data != null else "",
		"weakness_value": card_data.weakness_value if card_data != null else "",
		"resistance_energy": card_data.resistance_energy if card_data != null else "",
		"resistance_value": card_data.resistance_value if card_data != null else "",
		"retreat_cost": card_data.retreat_cost if card_data != null else 0,
		"attacks": card_data.attacks.duplicate(true) if card_data != null else [],
		"abilities": card_data.abilities.duplicate(true) if card_data != null else [],
	}


func sanitize_recording_value(scene: Object, value: Variant) -> Variant:
	if value is Dictionary:
		var sanitized_dict := {}
		for key: Variant in (value as Dictionary).keys():
			sanitized_dict[str(key)] = sanitize_recording_value(scene, (value as Dictionary).get(key))
		return sanitized_dict
	if value is Array:
		var sanitized_array: Array = []
		for entry: Variant in value:
			sanitized_array.append(sanitize_recording_value(scene, entry))
		return sanitized_array
	if value is PokemonSlot:
		return serialize_pokemon_slot(value)
	if value is CardInstance:
		return serialize_card_instance(value)
	if value is CardData:
		var card_data: CardData = value
		return {
			"card_name": card_data.name,
			"card_type": card_data.card_type,
			"mechanic": card_data.mechanic,
			"description": card_data.description,
			"stage": card_data.stage,
			"hp": card_data.hp,
			"energy_type": card_data.energy_type,
			"effect_id": card_data.effect_id,
			"energy_provides": card_data.energy_provides,
			"attacks": card_data.attacks.duplicate(true),
			"abilities": card_data.abilities.duplicate(true),
		}
	return value
