extends SceneTree

const PortScript = preload("res://scripts/ai/ptcgdap/host/godot/A3ExternalDecisionPort.gd")
const OwnerScript = preload("res://scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorDevelopmentBattleOwner.gd")
const BridgeScript = preload("res://scripts/ai/HeadlessMatchBridge.gd")
const JsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")

const MAX_AUTOMATIC_STEPS := 4096

var _gsm: GameStateMachine = null
var _bridge: HeadlessMatchBridge = null
var _ports: Array = []
var _owners: Array = []
var _started := false
var _disposed := false
var _transition_ordinal := 0
var _callback_ordinal := 0
var _window_generation := 0
var _log_cursors := [0, 0]
var _current_checkpoint: Dictionary = {}
var _pending_checkpoint: Dictionary = {}
var _terminal: Dictionary = {}
var _server := TCPServer.new()
var _peer: StreamPeerTCP = null
var _receive_buffer := ""
var _bridge_token := ""


func _initialize() -> void:
	var port := -1
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--bridge-port="):
			port = argument.trim_prefix("--bridge-port=").to_int()
		elif argument.begins_with("--bridge-token="):
			_bridge_token = argument.trim_prefix("--bridge-token=")
	if port <= 0 or port > 65535 or _bridge_token.length() < 32:
		quit(2)
		return
	var listen_error := _server.listen(port, "127.0.0.1")
	if listen_error != OK:
		quit(2)


func _process(_delta: float) -> bool:
	if _peer == null and _server.is_connection_available():
		_peer = _server.take_connection()
	if _peer == null:
		return false
	_peer.poll()
	if _peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		if _disposed:
			quit(0)
		return false
	var available := _peer.get_available_bytes()
	if available > 0:
		var received: Array = _peer.get_data(available)
		if int(received[0]) != OK:
			quit(2)
			return true
		_receive_buffer += (received[1] as PackedByteArray).get_string_from_utf8()
	while _receive_buffer.contains("\n"):
		var boundary := _receive_buffer.find("\n")
		var line := _receive_buffer.substr(0, boundary).strip_edges()
		_receive_buffer = _receive_buffer.substr(boundary + 1)
		if line.is_empty():
			continue
		var parsed: Variant = JSON.parse_string(line)
		var response: Dictionary
		if (
			not parsed is Dictionary
			or not _exact_keys(parsed, ["bridge_token", "method", "payload"])
			or parsed.get("bridge_token") != _bridge_token
			or typeof(parsed.get("method")) != TYPE_STRING
			or not parsed.get("payload") is Dictionary
		):
			response = _error("godot_a3_bridge_request_invalid")
		else:
			response = _dispatch(str(parsed.get("method")), parsed.get("payload"))
		_write(response)
	return false


func _dispatch(method: String, payload: Dictionary) -> Dictionary:
	match method:
		"start":
			var result := _start(payload)
			return result if result.get("ok") == false else _ok(result)
		"commit":
			var result := _commit(payload)
			return _ok(result) if bool(result.get("accepted", false)) else result
		"next_checkpoint":
			if not payload.is_empty() or _pending_checkpoint.is_empty():
				return _error("godot_a3_bridge_next_checkpoint_invalid")
			_current_checkpoint = _pending_checkpoint.duplicate(true)
			_pending_checkpoint.clear()
			return _ok(_current_checkpoint)
		"semantic_snapshot":
			if not _exact_keys(payload, ["view", "capability"]):
				return _error("godot_a3_bridge_request_invalid")
			if payload.get("view") != "actor_public" or payload.get("capability") not in ["R0", "R2A"]:
				return _error("godot_a3_bridge_snapshot_capability_unsupported")
			var checkpoint := _pending_checkpoint if not _pending_checkpoint.is_empty() else _current_checkpoint
			return _ok((checkpoint.get("public_snapshot", {}) as Dictionary).duplicate(true))
		"random_events_since":
			if not _exact_keys(payload, ["cursor"]) or _gsm == null:
				return _error("godot_a3_bridge_request_invalid")
			var cursor: Variant = _json_integer(payload.get("cursor"))
			if cursor == null or int(cursor) < 0:
				return _error("godot_a3_bridge_rng_cursor_invalid")
			return _ok(_gsm.random_event_port.call("events_since", int(cursor)))
		"terminal_result":
			if not payload.is_empty():
				return _error("godot_a3_bridge_request_invalid")
			return _ok(null if _terminal.is_empty() else _terminal.duplicate(true))
		"dispose":
			if not payload.is_empty():
				return _error("godot_a3_bridge_request_invalid")
			_dispose()
			return _ok({"disposed": true})
		_:
			return _error("godot_a3_bridge_method_unknown")


func _start(spec: Dictionary) -> Dictionary:
	if _started or _disposed:
		return _error("godot_a3_bridge_start_invalid")
	var allowed := {
		"private_deck0_id": true, "private_deck1_id": true,
		"private_deck0_entries": true, "private_deck1_entries": true,
		"deck0": true, "deck1": true,
		"seed": true, "force_first": true,
	}
	for key: Variant in spec.keys():
		if not allowed.has(key):
			return _error("godot_a3_bridge_start_invalid")
	var seed_value: Variant = _json_integer(spec.get("seed", 1))
	var force_first: Variant = _json_integer(spec.get("force_first", -1))
	if (
		seed_value == null
		or force_first == null or int(force_first) not in [-1, 0, 1]
	):
		return _error("godot_a3_bridge_start_invalid")
	var card_database: Node = root.get_node_or_null("CardDatabase")
	if card_database == null or not card_database.has_method("get_deck"):
		return _error("godot_a3_bridge_card_database_unavailable")
	var deck0_result := _resolve_deck(
		card_database,
		spec.get("private_deck0_id", spec.get("deck0")),
		spec.get("private_deck0_entries"),
		0
	)
	var deck1_result := _resolve_deck(
		card_database,
		spec.get("private_deck1_id", spec.get("deck1")),
		spec.get("private_deck1_entries"),
		1
	)
	if not bool(deck0_result.get("ok", false)) or not bool(deck1_result.get("ok", false)):
		return _error("godot_a3_bridge_deck_unavailable")
	var deck0: DeckData = deck0_result.get("deck") as DeckData
	var deck1: DeckData = deck1_result.get("deck") as DeckData
	_gsm = GameStateMachine.new()
	_gsm.random_event_port.call("configure_seed", int(seed_value), 1)
	_bridge = BridgeScript.new()
	root.add_child(_bridge)
	_bridge.bind(_gsm)
	# In the research adapter force_first pins the coin-winning chooser, not the
	# final first player. The returned YES/NO index remains the sole authority.
	_gsm.start_game(deck0, deck1, int(force_first), true)
	_ports = [PortScript.new(), PortScript.new()]
	_owners = []
	for seat: int in 2:
		var created: Dictionary = OwnerScript.create_external(
			_gsm, seat, "a3-godot-jsonline", _ports[seat]
		)
		if not bool(created.get("ok", false)):
			_dispose()
			return _error(str(created.get("error_code", "godot_a3_bridge_owner_bind_failed")))
		_owners.append(created.get("owner"))
	_bridge.set_ai_controllers(_owners[0], _owners[1])
	_bridge.bootstrap_pending_setup()
	_started = true
	var checkpoint := _drive_to_checkpoint()
	if checkpoint.get("ok") == false:
		return checkpoint
	_current_checkpoint = checkpoint.duplicate(true)
	return checkpoint


func _resolve_deck(
	card_database: Node,
	deck_id_raw: Variant,
	entries_raw: Variant,
	seat: int
) -> Dictionary:
	if deck_id_raw != null and entries_raw != null:
		return _error("godot_a3_bridge_deck_unavailable")
	if deck_id_raw != null:
		var deck_id: Variant = _json_integer(deck_id_raw)
		if deck_id == null or int(deck_id) <= 0:
			return _error("godot_a3_bridge_deck_unavailable")
		var stored: DeckData = card_database.call("get_deck", int(deck_id))
		return {"ok": stored != null, "deck": stored}
	if not entries_raw is Array:
		return _error("godot_a3_bridge_deck_unavailable")
	var entries: Array = entries_raw
	if entries.is_empty() or entries.size() > 60:
		return _error("godot_a3_bridge_deck_unavailable")
	var normalized: Array[Dictionary] = []
	var seen: Dictionary = {}
	var total := 0
	for raw_entry: Variant in entries:
		if not raw_entry is Dictionary or not _exact_keys(
			raw_entry, ["set_code", "card_index", "count"]
		):
			return _error("godot_a3_bridge_deck_unavailable")
		var set_code: Variant = raw_entry.get("set_code")
		var card_index: Variant = raw_entry.get("card_index")
		var count: Variant = _json_integer(raw_entry.get("count"))
		if (
			typeof(set_code) != TYPE_STRING or str(set_code).is_empty()
			or typeof(card_index) != TYPE_STRING or str(card_index).is_empty()
			or count == null or int(count) <= 0 or int(count) > 60
		):
			return _error("godot_a3_bridge_deck_unavailable")
		var uid := "%s_%s" % [str(set_code), str(card_index)]
		if seen.has(uid) or card_database.call("get_card", str(set_code), str(card_index)) == null:
			return _error("godot_a3_bridge_deck_unavailable")
		seen[uid] = true
		total += int(count)
		normalized.append({
			"set_code": str(set_code),
			"card_index": str(card_index),
			"count": int(count),
		})
	if total != 60:
		return _error("godot_a3_bridge_deck_unavailable")
	var deck := DeckData.new()
	deck.id = -1000 - seat
	deck.deck_name = "A3 private-ID research deck seat %d" % seat
	deck.cards = normalized
	deck.total_cards = total
	return {"ok": true, "deck": deck}


func _commit(payload: Dictionary) -> Dictionary:
	if not _started or _disposed or not _pending_checkpoint.is_empty():
		return _error("godot_a3_bridge_commit_invalid")
	if not _exact_keys(payload, ["window_handle", "indexes"]):
		return _error("godot_a3_bridge_commit_shape_invalid")
	if _current_checkpoint.get("kind") != "SELECTION":
		return _error("godot_a3_bridge_commit_lifecycle_invalid")
	if payload.get("window_handle") != _current_checkpoint.get("window_handle"):
		return _error("godot_a3_bridge_commit_handle_invalid")
	var seat := int(_current_checkpoint.get("acting_seat", -1))
	if seat not in [0, 1]:
		return _error("godot_a3_bridge_commit_invalid")
	var indexes: Variant = _json_integer_array(payload.get("indexes"))
	if indexes == null:
		return _error("godot_a3_bridge_commit_indexes_invalid")
	var submitted: Dictionary = _ports[seat].submit(
		str(payload.get("window_handle", "")), indexes
	)
	if not bool(submitted.get("ok", false)):
		return _error(str(submitted.get("error_code", "godot_a3_bridge_commit_invalid")))
	_transition_ordinal += 1
	var checkpoint := _drive_to_checkpoint()
	if checkpoint.get("ok") == false:
		return checkpoint
	_pending_checkpoint = checkpoint.duplicate(true)
	return {
		"accepted": true,
		"indexes": indexes,
		"selection_count": indexes.size(),
	}


func _drive_to_checkpoint() -> Dictionary:
	for _step: int in MAX_AUTOMATIC_STEPS:
		if _gsm.game_state.is_game_over():
			return _build_terminal_checkpoint()
		for seat: int in 2:
			var pending: Dictionary = _ports[seat].pending_checkpoint()
			if bool(pending.get("ok", false)):
				return _build_selection_checkpoint(seat, pending)
		var progressed := false
		if _bridge.has_pending_prompt():
			var owner_seat := _bridge.get_pending_prompt_owner()
			if owner_seat in [0, 1]:
				progressed = bool(_owners[owner_seat].run_single_step(_bridge, _gsm))
			elif _bridge.can_resolve_pending_prompt():
				progressed = _bridge.resolve_pending_prompt()
			else:
				return _error("godot_a3_bridge_prompt_owner_unavailable")
		else:
			var current_seat := int(_gsm.game_state.current_player_index)
			if current_seat not in [0, 1]:
				return _error("godot_a3_bridge_acting_seat_invalid")
			progressed = bool(_owners[current_seat].run_single_step(_bridge, _gsm))
		for seat: int in 2:
			var opened: Dictionary = _ports[seat].pending_checkpoint()
			if bool(opened.get("ok", false)):
				return _build_selection_checkpoint(seat, opened)
		var decision_failure := _external_decision_failure_code()
		if not decision_failure.is_empty():
			return _error("godot_a3_bridge_external_decision_%s" % decision_failure)
		if not progressed:
			return _error("godot_a3_bridge_no_progress")
	return _error("godot_a3_bridge_step_limit")


func _external_decision_failure_code() -> String:
	for owner: Variant in _owners:
		if owner != null and owner.has_method("external_decision_failure_code"):
			var code := str(owner.call("external_decision_failure_code"))
			if not code.is_empty():
				if owner.has_method("external_decision_failure_detail"):
					var detail: Dictionary = owner.call("external_decision_failure_detail")
					if detail.get("surface") == "option_shape":
						return "%s_option_%d_type_%s_kind_%s" % [
							code,
							int(detail.get("option_index", -1)),
							str(detail.get("option_type_raw", "missing")),
							str(detail.get("option_kind", "missing")),
						]
				return code
	return ""


func _build_selection_checkpoint(seat: int, pending: Dictionary) -> Dictionary:
	var frame: Dictionary = pending.get("frame", {})
	var semantics: Dictionary = frame.get("select_semantics", {})
	var options: Array = frame.get("options", []).duplicate(true)
	var select := {
		"type": int(semantics.get("select_type_raw", -1)),
		"context": int(semantics.get("select_context_raw", -1)),
		"minCount": int(semantics.get("min_count", -1)),
		"maxCount": int(semantics.get("max_count", -1)),
		"remainDamageCounter": int(semantics.get("remain_damage_counter", 0)),
		"remainEnergyCost": int(semantics.get("remain_energy_cost", 0)),
		"option": options.duplicate(true),
		"deck": null,
		"contextCard": null,
		"effect": null,
	}
	var logs := _incremental_public_logs(seat)
	var raw := {
		"profile": "ptcgdap_private_current_window_v1",
		"current": frame.get("public_state", {}).duplicate(true),
		"select": select.duplicate(true),
		"logs": logs.duplicate(true),
		"search_begin_input": null,
	}
	_window_generation += 1
	var snapshot := {
		"lifecycle": "selection",
		"current": frame.get("public_state", {}).duplicate(true),
		"select": select.duplicate(true),
		"ordered_options": options.duplicate(true),
		"incremental_logs": logs.duplicate(true),
		"result": -1,
	}
	var checkpoint := {
		"source_lane": "godot_private",
		"kind": "SELECTION",
		"transition_ordinal": _transition_ordinal,
		"callback_ordinal": _callback_ordinal,
		"acting_seat": seat,
		"raw_actor_observation": raw,
		"raw_observation_hash": _hash(raw),
		"window_handle": pending.get("window_handle"),
		"window_generation": _window_generation,
		"select": select,
		"ordered_options": options,
		"option_fingerprints": _fingerprints(options),
		"incremental_logs": logs,
		"public_snapshot": snapshot,
		"random_event_cursor": int(_gsm.random_event_port.call("event_cursor")),
		"diagnostic_capability_mask": [
			"private_card_id_domain",
			"research_corresponding_card_projection",
			"rng_r0_or_conditioned_r2a",
		],
	}
	_callback_ordinal += 1
	return checkpoint


func _build_terminal_checkpoint() -> Dictionary:
	# A terminal checkpoint has no acting seat.  Each seat receives its own
	# incremental slice at its last actor checkpoint, so never merge them here.
	var logs: Array = []
	var result := int(_gsm.game_state.winner_index)
	var raw := {
		"profile": "ptcgdap_private_current_window_v1",
		"current": {"result": result},
		"select": null,
		"logs": logs.duplicate(true),
		"search_begin_input": null,
	}
	var snapshot := {
		"lifecycle": "terminal",
		"current": {"result": result},
		"select": null,
		"ordered_options": [],
		"incremental_logs": logs.duplicate(true),
		"result": result,
	}
	var checkpoint := {
		"source_lane": "godot_private",
		"kind": "TERMINAL",
		"transition_ordinal": _transition_ordinal,
		"callback_ordinal": _callback_ordinal,
		"acting_seat": null,
		"raw_actor_observation": raw,
		"raw_observation_hash": _hash(raw),
		"window_handle": null,
		"window_generation": null,
		"select": null,
		"ordered_options": [],
		"option_fingerprints": [],
		"incremental_logs": logs,
		"public_snapshot": snapshot,
		"random_event_cursor": int(_gsm.random_event_port.call("event_cursor")),
		"diagnostic_capability_mask": [
			"private_card_id_domain",
			"research_corresponding_card_projection",
			"rng_r0_or_conditioned_r2a",
		],
	}
	_callback_ordinal += 1
	_terminal = snapshot.duplicate(true)
	return checkpoint


func _incremental_public_logs(seat: int) -> Array:
	if seat not in [0, 1]:
		return []
	var result: Array = []
	var actions: Array[GameAction] = _gsm.get_action_log()
	for index: int in range(int(_log_cursors[seat]), actions.size()):
		var action: GameAction = actions[index]
		var projected := _public_action(action)
		if not projected.is_empty():
			result.append(projected)
	_log_cursors[seat] = actions.size()
	return result


func _public_action(action: GameAction) -> Dictionary:
	if action == null or int(action.action_type) < 0:
		return {}
	var kind := _public_action_kind(action.action_type)
	if kind.is_empty():
		return {}
	var facts := {}
	# Only scalar facts whose public meaning does not depend on a hidden card
	# identity are allowed.  Unknown fields are ignored, never recursively
	# serialized. Drawn cards, deck order and face-down prize identities cannot
	# cross this projector.
	for key: String in ["count", "damage", "amount", "prize_count"]:
		if typeof(action.data.get(key)) == TYPE_INT:
			facts[key] = int(action.data.get(key))
	for key: String in ["result", "heads"]:
		if typeof(action.data.get(key)) == TYPE_BOOL:
			facts[key] = bool(action.data.get(key))
	return {
		"event": kind,
		"player_index": int(action.player_index) if action.player_index in [0, 1] else -1,
		"turn_number": maxi(0, int(action.turn_number)),
		"facts": facts,
	}


static func _public_action_kind(action_type: GameAction.ActionType) -> String:
	match action_type:
		GameAction.ActionType.GAME_START: return "game_start"
		GameAction.ActionType.GAME_END: return "game_end"
		GameAction.ActionType.TURN_START: return "turn_start"
		GameAction.ActionType.TURN_END: return "turn_end"
		GameAction.ActionType.DRAW_CARD: return "draw_card"
		GameAction.ActionType.MULLIGAN: return "mulligan"
		GameAction.ActionType.SETUP_PLACE_ACTIVE: return "setup_place_active"
		GameAction.ActionType.SETUP_PLACE_BENCH: return "setup_place_bench"
		GameAction.ActionType.SETUP_SET_PRIZES: return "setup_set_prizes"
		GameAction.ActionType.PLAY_POKEMON: return "play_pokemon"
		GameAction.ActionType.EVOLVE: return "evolve"
		GameAction.ActionType.ATTACH_ENERGY: return "attach_energy"
		GameAction.ActionType.PLAY_TRAINER: return "play_trainer"
		GameAction.ActionType.PLAY_TOOL: return "play_tool"
		GameAction.ActionType.PLAY_STADIUM: return "play_stadium"
		GameAction.ActionType.USE_STADIUM: return "use_stadium"
		GameAction.ActionType.USE_ABILITY: return "use_ability"
		GameAction.ActionType.RETREAT: return "retreat"
		GameAction.ActionType.ATTACK: return "attack"
		GameAction.ActionType.COIN_FLIP: return "coin_flip"
		GameAction.ActionType.KNOCKOUT: return "knockout"
		GameAction.ActionType.TAKE_PRIZE: return "take_prize"
		GameAction.ActionType.SEND_OUT: return "send_out"
		GameAction.ActionType.STATUS_APPLIED: return "status_applied"
		GameAction.ActionType.STATUS_REMOVED: return "status_removed"
		GameAction.ActionType.DAMAGE_DEALT: return "damage_dealt"
		GameAction.ActionType.HEAL: return "heal"
		GameAction.ActionType.POKEMON_CHECK: return "pokemon_check"
		GameAction.ActionType.DISCARD: return "discard"
		GameAction.ActionType.SHUFFLE_DECK: return "shuffle_deck"
		GameAction.ActionType.PUBLIC_REVEAL: return "public_reveal"
		_: return ""


func _dispose() -> void:
	if _disposed:
		return
	for owner: Variant in _owners:
		if owner != null and owner.has_method("close_match"):
			owner.close_match()
	_owners.clear()
	_ports.clear()
	if _bridge != null:
		_bridge.bind(null)
		if is_instance_valid(_bridge):
			_bridge.queue_free()
	_bridge = null
	if _gsm != null:
		_gsm.prepare_for_disposal()
	_gsm = null
	_disposed = true


static func _fingerprints(options: Array) -> Array:
	var result: Array = []
	for option: Variant in options:
		result.append(_hash(option))
	return result


static func _hash(value: Variant) -> String:
	var canonical: Dictionary = JsonTreeScript.canonicalize(value)
	if not bool(canonical.get("ok", false)):
		return ""
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(canonical.get("bytes", PackedByteArray()))
	return context.finish().hex_encode().to_upper()


func _write(value: Dictionary) -> void:
	if _peer == null:
		return
	_peer.put_data((JSON.stringify(value, "", false, true) + "\n").to_utf8_buffer())


static func _ok(result: Variant) -> Dictionary:
	return {"ok": true, "result": result}


static func _error(code: String) -> Dictionary:
	return {"ok": false, "error_code": code}


static func _exact_keys(value: Dictionary, expected: Array[String]) -> bool:
	if value.size() != expected.size():
		return false
	for key: String in expected:
		if not value.has(key):
			return false
	return true


static func _json_integer(value: Variant) -> Variant:
	if typeof(value) == TYPE_INT:
		return int(value)
	# Godot's JSON parser materializes wire numbers as FLOAT. The Python
	# transport validates JSON list[int] before serialization; this conversion
	# accepts only exact safe integer values at the engine boundary.
	if typeof(value) == TYPE_FLOAT:
		var float_value := float(value)
		if is_finite(float_value) and float_value == floor(float_value) \
			and abs(float_value) <= 9_007_199_254_740_991.0:
			return int(float_value)
	return null


static func _json_integer_array(value: Variant) -> Variant:
	if not value is Array:
		return null
	var result: Array[int] = []
	for raw: Variant in value:
		var integer: Variant = _json_integer(raw)
		if integer == null:
			return null
		result.append(int(integer))
	return result
