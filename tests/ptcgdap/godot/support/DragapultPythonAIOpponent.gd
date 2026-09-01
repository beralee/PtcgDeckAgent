class_name DragapultPythonAIOpponent
extends AIOpponent

const PROFILE_ID := "ptcgdap-dragapult-python-public-strategy-v1"
const STRATEGY_ID := "ptcgdap.dragapult.18.0.python-public-v1"
const CARD_ID_DOMAIN := "godot_local_card_uid_v1"
const BUNDLE_SHA256 := "ABB35B389AF4CC3FA5BB1415B82406400E7A14B77672614D48DCA32B2EFF5DA1"
const DRAGAPULT_UID := "CSV8C_159"
const PYTHON_SCRIPT_PATH := "res://tools/ptcgdap/run_dragapult_public_strategy.py"
const GodotSerialRegistryScript = preload("res://scripts/ai/ptcgdap/host/godot/GodotSerialRegistry.gd")
const CabtTreeHashScript = preload("res://scripts/ai/ptcgdap/cabt/CabtTreeHash.gd")
const RuleReferenceRegistryScript = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const RuleReferenceAIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")


class PublicStrategyAdapter extends RefCounted:
	var owner: DragapultPythonAIOpponent

	func _init(next_owner: DragapultPythonAIOpponent) -> void:
		owner = next_owner

	func get_strategy_id() -> String:
		return STRATEGY_ID

	func plan_opening_setup(player: PlayerState) -> Dictionary:
		return owner.plan_opening_setup_public(player) if owner != null else {}

	func consume_fast_send_out_choice(
		bench_slots: Array[PokemonSlot],
		game_state: GameState,
		seat: int
	) -> PokemonSlot:
		if owner == null or seat != owner.player_index:
			return null
		return owner.pick_send_out_public(bench_slots, game_state)

	func pick_interaction_items(
		items: Array,
		step: Dictionary,
		context: Dictionary = {}
	) -> Array:
		if owner == null or int(context.get("player_index", owner.player_index)) != owner.player_index:
			return []
		return owner.pick_interaction_items_public(items, step)


var _gsm: GameStateMachine = null
var _serial_registry: GodotSerialRegistry = null
var _match_generation: int = -1
var _python_executable := "python"
var _sequence := 0
var _bound := false
var _bind_error_code := ""
var _adapter: PublicStrategyAdapter = null
var _rule_reference_ai: AIOpponent = null
var _rule_reference_strategy: RefCounted = null
var _python_calls := 0
var _python_successes := 0
var _python_errors := 0
var _python_timeouts := 0
var _invalid_outputs := 0
var _fallbacks := 0
var _interaction_calls := 0
var _setup_calls := 0
var _send_out_calls := 0
var _ipc_elapsed_msec := 0
var _last_error_code := ""
var _first_rule_divergence: Dictionary = {}
var _rule_baseline_comparisons := 0
var _rule_baseline_unavailable := 0
var _prompt_counts: Dictionary = {}


func bind_public_match(
	next_gsm: GameStateMachine,
	next_python_executable: String = "python"
) -> Dictionary:
	if _bound or next_gsm == null or next_gsm.game_state == null:
		_bind_error_code = "invalid_bind"
		return {"ok": false, "error_code": _bind_error_code}
	if next_gsm.game_state.players.size() != 2:
		_bind_error_code = "invalid_player_count"
		return {"ok": false, "error_code": _bind_error_code}
	_gsm = next_gsm
	_python_executable = next_python_executable.strip_edges()
	if _python_executable.is_empty():
		_bind_error_code = "missing_python_executable"
		return {"ok": false, "error_code": _bind_error_code}
	_serial_registry = GodotSerialRegistryScript.new()
	_match_generation = _serial_registry.get_match_generation()
	for seat: int in 2:
		var register_result := _register_player_inventory(_gsm.game_state.players[seat])
		if not bool(register_result.get("ok", false)):
			_bind_error_code = str(register_result.get("error_code", "serial_registry_error"))
			return {"ok": false, "error_code": _bind_error_code}
	var seal_result: Dictionary = _serial_registry.seal_card_inventory([60, 60])
	if not bool(seal_result.get("ok", false)):
		_bind_error_code = str(seal_result.get("code", "card_inventory_error"))
		return {"ok": false, "error_code": _bind_error_code}
	_adapter = PublicStrategyAdapter.new(self)
	set_deck_strategy(_adapter)
	_rule_reference_ai = RuleReferenceAIOpponentScript.new()
	_rule_reference_ai.configure(player_index, 1)
	var registry := RuleReferenceRegistryScript.new()
	_rule_reference_strategy = registry.create_strategy_for_player(
		_gsm.game_state.players[player_index]
	)
	if _rule_reference_strategy != null:
		_rule_reference_ai.set_deck_strategy(_rule_reference_strategy)
		_rule_reference_ai.decision_runtime_mode = RuleReferenceAIOpponentScript.DECISION_RUNTIME_RULES_ONLY
	_bound = true
	return {
		"ok": true,
		"error_code": "",
		"match_generation": _match_generation,
		"card_inventory": _serial_registry_summary(),
	}


func close_public_match() -> void:
	if _serial_registry != null:
		_serial_registry.close_match()
	_bound = false
	_gsm = null


func get_public_strategy_audit() -> Dictionary:
	return {
		"schema_version": 1,
		"profile_id": PROFILE_ID,
		"strategy_id": STRATEGY_ID,
		"card_id_domain": CARD_ID_DOMAIN,
		"bundle_sha256": BUNDLE_SHA256,
		"development_python_only": true,
		"player_runtime_python_dependency": false,
		"cabt_exportable": false,
		"bound": _bound,
		"bind_error_code": _bind_error_code,
		"seat": player_index,
		"sequence": _sequence,
		"python_calls": _python_calls,
		"python_successes": _python_successes,
		"python_errors": _python_errors,
		"python_timeouts": _python_timeouts,
		"invalid_outputs": _invalid_outputs,
		"fallbacks": _fallbacks,
		"interaction_calls": _interaction_calls,
		"setup_calls": _setup_calls,
		"send_out_calls": _send_out_calls,
		"ipc_elapsed_msec": _ipc_elapsed_msec,
		"last_error_code": _last_error_code,
		"first_rule_divergence": _first_rule_divergence.duplicate(true),
		"rule_baseline_comparisons": _rule_baseline_comparisons,
		"rule_baseline_unavailable": _rule_baseline_unavailable,
		"prompt_counts": _prompt_counts.duplicate(true),
		"serial_registry": _serial_registry_summary(),
	}


func plan_opening_setup_public(player: PlayerState) -> Dictionary:
	if not _is_bound_to_current_match() or player == null or player.player_index != player_index:
		return {}
	var basics: Array[CardInstance] = player.get_basic_pokemon_in_hand()
	if basics.is_empty():
		return {}
	_setup_calls += 1
	var active_indexes := _select_items("setup_active", basics, 1, 1, "setup_active")
	if active_indexes.is_empty():
		active_indexes = [0]
	var active_card: CardInstance = basics[int(active_indexes[0])]
	var bench_candidates: Array = []
	for card: CardInstance in basics:
		if card != active_card:
			bench_candidates.append(card)
	var bench_cards: Array = []
	var bench_count := mini(5, bench_candidates.size())
	if bench_count > 0:
		var bench_indexes := _select_items(
			"setup_bench",
			bench_candidates,
			bench_count,
			bench_count,
			"setup_bench"
		)
		for raw_index: Variant in bench_indexes:
			var candidate_index := int(raw_index)
			if candidate_index >= 0 and candidate_index < bench_candidates.size():
				bench_cards.append(bench_candidates[candidate_index])
	var active_hand_index := player.hand.find(active_card)
	var bench_hand_indices: Array[int] = []
	for card: CardInstance in bench_cards:
		var hand_index := player.hand.find(card)
		if hand_index >= 0:
			bench_hand_indices.append(hand_index)
	return {
		"active_hand_index": active_hand_index,
		"bench_hand_indices": bench_hand_indices,
	}


func pick_send_out_public(
	bench_slots: Array[PokemonSlot],
	game_state: GameState
) -> PokemonSlot:
	if not _is_bound_to_current_match() or game_state != _gsm.game_state or bench_slots.is_empty():
		return null
	_send_out_calls += 1
	var indexes := _select_items("send_out", bench_slots, 1, 1, "send_out")
	if indexes.is_empty():
		return bench_slots[0]
	var selected := int(indexes[0])
	return bench_slots[selected] if selected >= 0 and selected < bench_slots.size() else bench_slots[0]


func pick_interaction_items_public(items: Array, step: Dictionary) -> Array:
	if not _is_bound_to_current_match() or items.is_empty():
		return []
	_interaction_calls += 1
	var minimum := clampi(int(step.get("min_select", 1)), 0, items.size())
	var maximum := clampi(int(step.get("max_select", maxi(1, minimum))), minimum, items.size())
	var prompt_kind := _prompt_kind_for_step(step)
	var indexes := _select_items(prompt_kind, items, minimum, maximum, _option_kind_for_prompt(prompt_kind))
	var selected: Array = []
	for raw_index: Variant in indexes:
		var item_index := int(raw_index)
		if item_index >= 0 and item_index < items.size() and items[item_index] not in selected:
			selected.append(items[item_index])
	return selected


func _choose_best_action(gsm: GameStateMachine) -> Dictionary:
	if not _is_bound_to(gsm):
		return super(gsm)
	var actions: Array[Dictionary] = get_legal_actions(gsm)
	if actions.is_empty():
		return {}
	var indexes := _select_items("main", actions, 1, 1, "")
	var selected_index := int(indexes[0]) if not indexes.is_empty() else _same_window_fallback_index(actions)
	if selected_index < 0 or selected_index >= actions.size():
		selected_index = _same_window_fallback_index(actions)
	var selected: Dictionary = actions[selected_index]
	_capture_rule_divergence(gsm, actions, selected)
	return selected


func _select_items(
	prompt_kind: String,
	items: Array,
	minimum: int,
	maximum: int,
	forced_option_kind: String
) -> Array[int]:
	if items.is_empty() or not _is_bound_to_current_match():
		return []
	var options: Array = []
	for index: int in items.size():
		var option := _build_option(index, items[index], forced_option_kind)
		options.append(option)
	var frame := _build_frame(prompt_kind, options, minimum, maximum)
	var response := _invoke_python(frame)
	if bool(response.get("ok", false)):
		return _validated_indexes(response.get("selected_indexes", []), items.size(), minimum, maximum)
	_fallbacks += 1
	var fallback := _same_window_fallback_indexes(items, minimum, maximum)
	return fallback


func _build_frame(
	prompt_kind: String,
	options: Array,
	minimum: int,
	maximum: int
) -> Dictionary:
	_sequence += 1
	_prompt_counts[prompt_kind] = int(_prompt_counts.get(prompt_kind, 0)) + 1
	var public_state := _build_public_state()
	var observation_source := {
		"schema_version": 1,
		"sequence": _sequence,
		"seat": player_index,
		"prompt_kind": prompt_kind,
		"public_state": public_state,
	}
	var observation_result: Dictionary = CabtTreeHashScript.public_observation_hash(observation_source)
	var observation_hash := str(observation_result.get("sha256", ""))
	var window_source := {
		"public_observation_hash": observation_hash,
		"select_semantics": {"min_count": minimum, "max_count": maximum},
		"options": options,
	}
	var window_result: Dictionary = CabtTreeHashScript.public_observation_hash(window_source)
	return {
		"schema_version": 1,
		"profile_id": PROFILE_ID,
		"strategy_id": STRATEGY_ID,
		"card_id_domain": CARD_ID_DOMAIN,
		"sequence": _sequence,
		"seat": player_index,
		"prompt_kind": prompt_kind,
		"source": {
			"public_observation_hash": observation_hash,
			"window_id": str(window_result.get("sha256", "")),
		},
		"public_state": public_state,
		"select_semantics": {"min_count": minimum, "max_count": maximum},
		"options": options,
	}


func _build_public_state() -> Dictionary:
	var state := _gsm.game_state
	var own: PlayerState = state.players[player_index]
	var opponent: PlayerState = state.players[1 - player_index]
	return {
		"turn_number": maxi(0, int(state.turn_number)),
		"phase": _phase_name(state),
		"self": {
			"hand": _public_cards(own.hand),
			"active": _public_slot_list(own.active_pokemon),
			"bench": _public_slots(own.bench),
			"discard": _public_cards(own.discard_pile),
			"deck_count": own.deck.size(),
			"prizes_remaining": own.prizes.size(),
		},
		"opponent": {
			"hand_count": opponent.hand.size(),
			"active": _public_slot_list(opponent.active_pokemon),
			"bench": _public_slots(opponent.bench),
			"discard": _public_cards(opponent.discard_pile),
			"deck_count": opponent.deck.size(),
			"prizes_remaining": opponent.prizes.size(),
		},
	}


func _public_cards(cards: Array[CardInstance]) -> Array:
	var rows: Array = []
	for card: CardInstance in cards:
		rows.append({
			"serial": _serial_for_card(card),
			"local_card_uid": _uid_for_card(card),
		})
	return rows


func _public_slots(slots: Array[PokemonSlot]) -> Array:
	var rows: Array = []
	for slot: PokemonSlot in slots:
		if slot != null and slot.get_top_card() != null:
			rows.append(_public_slot(slot))
	return rows


func _public_slot_list(slot: PokemonSlot) -> Array:
	return [] if slot == null or slot.get_top_card() == null else [_public_slot(slot)]


func _public_slot(slot: PokemonSlot) -> Dictionary:
	return {
		"serial": _serial_for_card(slot.get_top_card()),
		"local_card_uid": _uid_for_slot(slot),
		"remaining_hp": maxi(0, slot.get_remaining_hp()),
		"attached_energy_count": slot.attached_energy.size(),
	}


func _build_option(index: int, item: Variant, forced_kind: String) -> Dictionary:
	var action: Dictionary = item if item is Dictionary else {}
	var kind := forced_kind
	if kind.is_empty():
		kind = str(action.get("kind", "effect_target"))
	var card: CardInstance = action.get("card", null) as CardInstance
	var source_slot: PokemonSlot = action.get("source_slot", null) as PokemonSlot
	var target_slot: PokemonSlot = action.get("target_slot", null) as PokemonSlot
	if target_slot == null:
		target_slot = action.get("bench_target", null) as PokemonSlot
	if not (item is Dictionary):
		if item is CardInstance:
			card = item as CardInstance
		elif item is PokemonSlot:
			target_slot = item as PokemonSlot
	var card_uid: Variant = _uid_for_card(card) if card != null else null
	var source_uid: Variant = _uid_for_slot(source_slot) if source_slot != null else null
	var target_uid: Variant = _uid_for_slot(target_slot) if target_slot != null else null
	if source_uid == null and kind in ["attack", "granted_attack"]:
		source_uid = _uid_for_slot(_gsm.game_state.players[player_index].active_pokemon)
	if card_uid == null and item is CardData:
		card_uid = (item as CardData).get_uid()
	var attack_index_value: Variant = null
	var raw_attack_index := int(action.get("attack_index", -1))
	if raw_attack_index >= 0:
		attack_index_value = raw_attack_index
	var tags: Array = []
	if kind in ["attack", "granted_attack"]:
		tags.append("attack")
	if bool(action.get("projected_knockout", false)):
		tags.append("projected_knockout")
	if source_uid == DRAGAPULT_UID and raw_attack_index == 1:
		tags.append("phantom_dive")
	return {
		"index": index,
		"kind": kind,
		"card_uid": card_uid,
		"source_uid": source_uid,
		"target_uid": target_uid,
		"target_remaining_hp": maxi(0, target_slot.get_remaining_hp()) if target_slot != null else null,
		"target_prize_value": target_slot.get_prize_count() if target_slot != null else null,
		"attached_energy_count": target_slot.attached_energy.size() if target_slot != null else null,
		"attack_index": attack_index_value,
		"tags": tags,
	}


func _invoke_python(frame: Dictionary) -> Dictionary:
	_python_calls += 1
	var source: Dictionary = frame.get("source", {})
	var request_id := "godot-window-%d-%d" % [_match_generation, _sequence]
	var base_dir := ProjectSettings.globalize_path("user://ptcgdap_dragapult_python_e2e")
	if DirAccess.make_dir_recursive_absolute(base_dir) != OK:
		return _python_failure("ipc_directory_error")
	var request_path := base_dir.path_join("%s.request.json" % request_id)
	var response_path := base_dir.path_join("%s.response.json" % request_id)
	if FileAccess.file_exists(request_path) or FileAccess.file_exists(response_path):
		return _python_failure("ipc_path_collision")
	var request_file := FileAccess.open(request_path, FileAccess.WRITE)
	if request_file == null:
		return _python_failure("ipc_request_write_error")
	request_file.store_string(JSON.stringify({
		"schema_version": 1,
		"request_id": request_id,
		"frame": frame,
	}))
	request_file.close()
	var started := Time.get_ticks_msec()
	var process_id := OS.create_process(
		_python_executable,
		PackedStringArray([
			ProjectSettings.globalize_path(PYTHON_SCRIPT_PATH),
			"--request",
			request_path,
			"--response",
			response_path,
		]),
		false
	)
	if process_id <= 0:
		DirAccess.remove_absolute(request_path)
		return _python_failure("python_process_spawn_error")
	while OS.is_process_running(process_id) and Time.get_ticks_msec() - started <= 5000:
		OS.delay_msec(5)
	var timed_out := OS.is_process_running(process_id)
	if timed_out:
		OS.kill(process_id)
	var elapsed := Time.get_ticks_msec() - started
	_ipc_elapsed_msec += elapsed
	if timed_out:
		_python_timeouts += 1
	var parsed: Variant = null
	if not timed_out and FileAccess.file_exists(response_path):
		var response_file := FileAccess.open(response_path, FileAccess.READ)
		if response_file != null:
			parsed = JSON.parse_string(response_file.get_as_text())
			response_file.close()
	DirAccess.remove_absolute(request_path)
	DirAccess.remove_absolute(response_path)
	if timed_out:
		return _python_failure("python_timeout")
	if parsed == null:
		return _python_failure("python_process_error")
	if not (parsed is Dictionary):
		_invalid_outputs += 1
		return _python_failure("invalid_python_response")
	var response: Dictionary = parsed
	if not _response_is_bound(response, request_id, source):
		_invalid_outputs += 1
		return _python_failure("stale_or_invalid_python_response")
	if not bool(response.get("ok", false)):
		return _python_failure(str(response.get("error_code", "python_strategy_error")))
	_python_successes += 1
	_last_error_code = ""
	return response


func _response_is_bound(response: Dictionary, request_id: String, source: Dictionary) -> bool:
	var keys := [
		"schema_version", "request_id", "public_observation_hash", "window_id",
		"selected_indexes", "ok", "error_code",
	]
	if response.size() != keys.size():
		return false
	for key: String in keys:
		if not response.has(key):
			return false
	return response.get("schema_version") == 1 \
		and str(response.get("request_id", "")) == request_id \
		and str(response.get("public_observation_hash", "")) == str(source.get("public_observation_hash", "")) \
		and str(response.get("window_id", "")) == str(source.get("window_id", "")) \
		and response.get("selected_indexes") is Array \
		and typeof(response.get("ok")) == TYPE_BOOL \
		and typeof(response.get("error_code")) == TYPE_STRING


func _validated_indexes(
	raw_indexes: Variant,
	option_count: int,
	minimum: int,
	maximum: int
) -> Array[int]:
	var indexes: Array[int] = []
	if not (raw_indexes is Array):
		_invalid_outputs += 1
		_fallbacks += 1
		return _same_window_fallback_indexes(range(option_count), minimum, maximum)
	for raw_index: Variant in raw_indexes:
		if typeof(raw_index) not in [TYPE_INT, TYPE_FLOAT]:
			_invalid_outputs += 1
			_fallbacks += 1
			return _same_window_fallback_indexes(range(option_count), minimum, maximum)
		if typeof(raw_index) == TYPE_FLOAT and (not is_finite(float(raw_index)) or float(raw_index) != floorf(float(raw_index))):
			_invalid_outputs += 1
			_fallbacks += 1
			return _same_window_fallback_indexes(range(option_count), minimum, maximum)
		var index := int(raw_index)
		if index < 0 or index >= option_count or index in indexes:
			_invalid_outputs += 1
			_fallbacks += 1
			return _same_window_fallback_indexes(range(option_count), minimum, maximum)
		indexes.append(index)
	if indexes.size() < minimum or indexes.size() > maximum:
		_invalid_outputs += 1
		_fallbacks += 1
		return _same_window_fallback_indexes(range(option_count), minimum, maximum)
	return indexes


func _python_failure(code: String) -> Dictionary:
	_python_errors += 1
	_last_error_code = code if not code.is_empty() else "python_strategy_error"
	return {"ok": false, "error_code": _last_error_code, "selected_indexes": []}


func _same_window_fallback_index(actions: Array[Dictionary]) -> int:
	for index: int in actions.size():
		if str(actions[index].get("kind", "")) == "end_turn":
			return index
	return 0 if not actions.is_empty() else -1


func _same_window_fallback_indexes(items: Variant, minimum: int, maximum: int) -> Array[int]:
	var count := mini(maximum, maxi(0, minimum))
	var size := (items as Array).size() if items is Array else 0
	var indexes: Array[int] = []
	for index: int in mini(count, size):
		indexes.append(index)
	return indexes


func _capture_rule_divergence(
	gsm: GameStateMachine,
	actions: Array[Dictionary],
	selected: Dictionary
) -> void:
	if not _first_rule_divergence.is_empty() or _rule_reference_ai == null or _rule_reference_strategy == null:
		return
	var certificate: Dictionary = _rule_reference_ai.build_rule_floor_certificate(gsm, actions)
	var rule_action_id := str(certificate.get("action_id", ""))
	var rule_action_kind := str(certificate.get("action_kind", ""))
	var python_action_id := ""
	if not rule_action_id.is_empty() and _rule_reference_strategy.has_method("stable_action_id_for_host"):
		python_action_id = str(_rule_reference_strategy.call("stable_action_id_for_host", selected))
	else:
		var baseline_raw: Variant = _rule_reference_ai.call("_choose_best_action", gsm)
		if not (baseline_raw is Dictionary) or (baseline_raw as Dictionary).is_empty():
			_rule_baseline_unavailable += 1
			return
		var baseline: Dictionary = baseline_raw
		rule_action_id = _semantic_action_id(baseline)
		rule_action_kind = str(baseline.get("kind", ""))
		python_action_id = _semantic_action_id(selected)
	if rule_action_id.is_empty() or python_action_id.is_empty():
		_rule_baseline_unavailable += 1
		return
	_rule_baseline_comparisons += 1
	if python_action_id != rule_action_id:
		_first_rule_divergence = {
			"sequence": _sequence,
			"turn_number": int(gsm.game_state.turn_number),
			"python_action_id": python_action_id,
			"rules_action_id": rule_action_id,
			"python_action_kind": str(selected.get("kind", "")),
			"rules_action_kind": rule_action_kind,
		}


func _semantic_action_id(action: Dictionary) -> String:
	var card: CardInstance = action.get("card", null) as CardInstance
	var source_slot: PokemonSlot = action.get("source_slot", null) as PokemonSlot
	var target_slot: PokemonSlot = action.get("target_slot", null) as PokemonSlot
	if target_slot == null:
		target_slot = action.get("bench_target", null) as PokemonSlot
	return "%s|%s|%s|%s|%d" % [
		str(action.get("kind", "")),
		str(_uid_for_card(card) if card != null else ""),
		str(_uid_for_slot(source_slot) if source_slot != null else ""),
		str(_uid_for_slot(target_slot) if target_slot != null else ""),
		int(action.get("attack_index", -1)),
	]


func _register_player_inventory(player: PlayerState) -> Dictionary:
	if player == null:
		return {"ok": false, "error_code": "missing_player"}
	var cards: Array[CardInstance] = []
	cards.append_array(player.deck)
	cards.append_array(player.hand)
	cards.append_array(player.prizes)
	cards.append_array(player.discard_pile)
	cards.append_array(player.lost_zone)
	if player.active_pokemon != null:
		cards.append_array(player.active_pokemon.collect_all_cards())
	for slot: PokemonSlot in player.bench:
		cards.append_array(slot.collect_all_cards())
	if cards.size() != 60:
		return {"ok": false, "error_code": "unexpected_card_inventory_count"}
	for card: CardInstance in cards:
		var result: Dictionary = _serial_registry.register_card(card, player.player_index)
		if not bool(result.get("ok", false)):
			return {"ok": false, "error_code": str(result.get("code", "serial_registry_error"))}
	return {"ok": true, "error_code": ""}


func _serial_for_card(card: CardInstance) -> int:
	if card == null or _serial_registry == null:
		return -1
	var result: Dictionary = _serial_registry.lookup_card(card, _match_generation, card.owner_index)
	return int(result.get("serial", -1)) if bool(result.get("ok", false)) else -1


func _serial_registry_summary() -> Dictionary:
	if _serial_registry == null:
		return {}
	var audit: Dictionary = _serial_registry.audit_snapshot()
	return {
		"schema_version": int(audit.get("schema_version", 0)),
		"visibility": str(audit.get("visibility", "")),
		"runtime_policy_input": bool(audit.get("runtime_policy_input", true)),
		"public_trajectory_eligible": bool(audit.get("public_trajectory_eligible", true)),
		"registry_state": str(audit.get("registry_state", "")),
		"match_generation": int(audit.get("match_generation", -1)),
		"card_inventory_sealed": bool(audit.get("card_inventory_sealed", false)),
		"card_inventory_valid": bool(audit.get("card_inventory_valid", false)),
		"card_inventory_state": str(audit.get("card_inventory_state", "")),
		"card_inventory_error_code": str(audit.get("card_inventory_error_code", "")),
		"sealed_player_card_counts": (audit.get("sealed_player_card_counts", []) as Array).duplicate(),
		"card_count": int(audit.get("card_count", 0)),
	}


func _uid_for_card(card: CardInstance) -> Variant:
	return card.card_data.get_uid() if card != null and card.card_data != null else null


func _uid_for_slot(slot: PokemonSlot) -> Variant:
	return slot.get_card_data().get_uid() if slot != null and slot.get_card_data() != null else null


func _prompt_kind_for_step(step: Dictionary) -> String:
	var signature := (
		str(step.get("id", "")) + " " + str(step.get("type", "")) + " "
		+ str(step.get("ui_mode", "")) + " " + str(step.get("title", ""))
	).to_lower()
	if "search" in signature or "find" in signature or "deck" in signature:
		return "search"
	if "evol" in signature:
		return "evolve"
	if "attach" in signature or "energy" in signature:
		return "attach"
	if "attack" in signature or "damage" in signature or "counter" in signature:
		return "attack_target"
	return "effect_target"


func _option_kind_for_prompt(prompt_kind: String) -> String:
	match prompt_kind:
		"search":
			return "search"
		"evolve":
			return "evolve"
		"attach":
			return "attach_energy"
		"attack_target":
			return "attack_target"
		_:
			return "effect_target"


func _phase_name(state: GameState) -> String:
	match state.phase:
		GameState.GamePhase.SETUP:
			return "SETUP"
		GameState.GamePhase.MULLIGAN:
			return "MULLIGAN"
		GameState.GamePhase.SETUP_PLACE:
			return "SETUP_PLACE"
		GameState.GamePhase.DRAW:
			return "DRAW"
		GameState.GamePhase.MAIN:
			return "MAIN"
		GameState.GamePhase.ATTACK:
			return "ATTACK"
		GameState.GamePhase.POKEMON_CHECK:
			return "POKEMON_CHECK"
		GameState.GamePhase.BETWEEN_TURNS:
			return "BETWEEN_TURNS"
		GameState.GamePhase.KNOCKOUT_REPLACE:
			return "KNOCKOUT_REPLACE"
		GameState.GamePhase.GAME_OVER:
			return "GAME_OVER"
		_:
			return "UNKNOWN"


func _is_bound_to(gsm: GameStateMachine) -> bool:
	return _bound and gsm != null and gsm == _gsm and gsm.game_state != null


func _is_bound_to_current_match() -> bool:
	return _is_bound_to(_gsm) and _serial_registry != null and _serial_registry.is_open()
