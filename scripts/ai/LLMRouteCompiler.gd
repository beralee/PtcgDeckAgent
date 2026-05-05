class_name LLMRouteCompiler
extends RefCounted

const MAX_INSERTED_ACTIONS := 4
const ROUTE_ACTION_METADATA_KEYS: Array[String] = [
	"allow_deck_draw_lock",
	"deck_draw_lock_exception",
]


func compile_queue(
	raw_queue: Array,
	catalog: Dictionary,
	_game_state: Variant = null,
	_player_index: int = -1
) -> Dictionary:
	var deck_count := _player_deck_count(_game_state, _player_index)
	var no_deck_draw_lock := deck_count >= 0 and deck_count <= 12
	var low_value_redraw_lock := _low_value_redraw_locked(_game_state, _player_index, deck_count)
	var original_queue: Array[Dictionary] = _copy_action_array(raw_queue)
	var queue: Array[Dictionary] = _dedupe_route(original_queue)
	var future_goals: Array[Dictionary] = []
	var notes: Array[String] = []
	var executable_result: Dictionary = _to_executable_route(queue, catalog)
	queue = executable_result.get("queue", queue)
	future_goals = executable_result.get("future_goals", [])
	notes.append_array(executable_result.get("notes", []))
	queue = _inherit_candidate_route_action_metadata(queue, catalog)
	if not (_queue_has_non_low_value_attack(queue) \
			or _future_goals_have_attack(future_goals) \
			or _queue_has_capability(queue, "defensive_gust") \
			or _future_goals_allow_defensive_gust(future_goals)):
		var gust_result: Dictionary = _remove_gust_without_attack_goal(queue)
		queue = gust_result.get("queue", queue)
		if int(gust_result.get("removed_count", 0)) > 0:
			notes.append("removed_gust_without_attack_goal")
	var hand_reset_result: Dictionary = _remove_hand_reset_before_visible_setup(queue, catalog, _game_state, _player_index)
	queue = hand_reset_result.get("queue", queue)
	if int(hand_reset_result.get("removed_count", 0)) > 0:
		notes.append("removed_hand_reset_before_visible_setup")
	if no_deck_draw_lock:
		var draw_lock_result: Dictionary = _remove_deck_draw_risk_actions(queue)
		queue = draw_lock_result.get("queue", queue)
		if int(draw_lock_result.get("removed_count", 0)) > 0:
			notes.append("removed_deck_draw_risk_actions")
	var inserted_actions: Array[Dictionary] = []
	var missed_actions: Array[Dictionary] = _missed_high_value_actions(queue, catalog, no_deck_draw_lock)
	var terminal_index := _first_terminal_index(queue)
	if terminal_index < 0:
		queue.append({"type": "end_turn", "id": "end_turn", "action_id": "end_turn", "capability": "end_turn"})
		notes.append("added_missing_terminal_end_turn")
		terminal_index = _first_terminal_index(queue)
	if terminal_index >= 0 and low_value_redraw_lock and _is_low_value_attack(queue[terminal_index]):
		queue.remove_at(terminal_index)
		notes.append("removed_low_value_attack_for_deck_or_hand_risk")
		terminal_index = _first_terminal_index(queue)
		if terminal_index < 0:
			queue.append({"type": "end_turn", "id": "end_turn", "action_id": "end_turn", "capability": "end_turn"})
			terminal_index = _first_terminal_index(queue)
	var terminal_is_end_turn := terminal_index >= 0 and _is_end_turn_ref(queue[terminal_index])
	var has_future_attack_goal := _future_goals_have_attack(future_goals)
	var terminal_is_attack := (terminal_index >= 0 and _is_attack_ref(queue[terminal_index])) or has_future_attack_goal
	var has_attack := _queue_has_attack(queue) or has_future_attack_goal
	var route_has_manual_attach := _queue_has_capability(queue, "manual_attach")
	if terminal_index >= 0:
		var candidates: Array[Dictionary] = _candidate_insertions(queue, catalog, terminal_is_attack, has_attack, has_future_attack_goal, no_deck_draw_lock)
		for candidate: Dictionary in candidates:
			if inserted_actions.size() >= MAX_INSERTED_ACTIONS:
				break
			var capability := _capability_for_ref(candidate)
			if capability == "manual_attach" and route_has_manual_attach:
				continue
			if _route_contains_action_id(queue, _action_id(candidate)):
				continue
			if _candidate_conflicts_with_route(candidate, queue):
				continue
			queue.insert(terminal_index, candidate)
			terminal_index += 1
			inserted_actions.append(candidate)
			if capability == "manual_attach":
				route_has_manual_attach = true
		if not inserted_actions.is_empty():
			notes.append("inserted_high_value_actions_before_terminal")
	for i: int in queue.size():
		var action: Dictionary = queue[i]
		action["capability"] = _capability_for_ref(action)
		queue[i] = action
	var blocked_end_turn := false
	if terminal_is_end_turn and inserted_actions.is_empty() and not missed_actions.is_empty():
		blocked_end_turn = true
		notes.append("premature_end_turn_with_missed_high_value_actions")
	return {
		"queue": queue,
		"original_queue": original_queue,
		"future_goals": future_goals,
		"inserted_actions": inserted_actions,
		"missed_actions": missed_actions,
		"blocked_end_turn": blocked_end_turn,
		"notes": notes,
	}


func compact_route_goal(queue: Array) -> Dictionary:
	var goal := {
		"terminal_type": "",
		"action_id": "",
		"attack_name": "",
		"card": "",
		"capability": "",
	}
	for i: int in range(queue.size() - 1, -1, -1):
		var raw: Variant = queue[i]
		if not (raw is Dictionary):
			continue
		var action: Dictionary = raw
		if _is_attack_ref(action):
			goal["terminal_type"] = "attack"
			goal["action_id"] = _action_id(action)
			goal["attack_name"] = str(action.get("attack_name", ""))
			goal["card"] = str(action.get("card", action.get("pokemon", "")))
			goal["capability"] = _capability_for_ref(action)
			return goal
		if _is_end_turn_ref(action) and str(goal.get("terminal_type", "")) == "":
			goal["terminal_type"] = "end_turn"
			goal["action_id"] = _action_id(action)
			goal["capability"] = "end_turn"
	for raw_action: Variant in queue:
		if not (raw_action is Dictionary):
			continue
		var action_ref: Dictionary = raw_action
		var capability := _capability_for_ref(action_ref)
		if capability != "end_turn" and capability != "":
			goal["action_id"] = _action_id(action_ref)
			goal["card"] = str(action_ref.get("card", action_ref.get("pokemon", "")))
			goal["capability"] = capability
			if str(goal.get("terminal_type", "")) == "":
				goal["terminal_type"] = "setup"
			return goal
	return goal


func compact_actions(actions: Array, limit: int = 12) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw: Variant in actions:
		if result.size() >= limit:
			break
		if not (raw is Dictionary):
			continue
		var action: Dictionary = raw
		var compact := {
			"id": _action_id(action),
			"type": str(action.get("type", action.get("kind", ""))),
			"capability": _capability_for_ref(action),
		}
		for key: String in [
			"card", "pokemon", "target", "position", "attack_name", "ability",
			"bench_target", "bench_position",
		]:
			if action.has(key):
				compact[key] = action.get(key)
		if action.has("selection_policy"):
			compact["selection_policy"] = action.get("selection_policy")
		if action.has("interactions"):
			compact["interactions"] = action.get("interactions")
		result.append(compact)
	return result


func _copy_action_array(raw_actions: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw: Variant in raw_actions:
		if raw is Dictionary:
			var action: Dictionary = (raw as Dictionary).duplicate(true)
			if not action.has("action_id") and action.has("id"):
				action["action_id"] = str(action.get("id", ""))
			if not action.has("id") and action.has("action_id"):
				action["id"] = str(action.get("action_id", ""))
			action["capability"] = _capability_for_ref(action)
			result.append(action)
	return result


func _dedupe_route(actions: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	for action: Dictionary in actions:
		var action_id := _action_id(action)
		if action_id != "" and action_id != "end_turn":
			if bool(seen.get(action_id, false)):
				continue
			seen[action_id] = true
		result.append(action)
	return result


func _inherit_candidate_route_action_metadata(queue: Array[Dictionary], catalog: Dictionary) -> Array[Dictionary]:
	if queue.is_empty() or catalog.is_empty():
		return queue
	var metadata_by_action_id := _candidate_route_metadata_by_action_id(catalog)
	if metadata_by_action_id.is_empty():
		return queue
	var result: Array[Dictionary] = []
	for action: Dictionary in queue:
		var action_id := _action_id(action)
		if action_id == "" or not metadata_by_action_id.has(action_id):
			result.append(action)
			continue
		var enriched := action.duplicate(true)
		var metadata: Dictionary = metadata_by_action_id.get(action_id, {})
		for key: String in ROUTE_ACTION_METADATA_KEYS:
			if metadata.has(key) and not enriched.has(key):
				enriched[key] = metadata.get(key)
		result.append(enriched)
	return result


func _candidate_route_metadata_by_action_id(catalog: Dictionary) -> Dictionary:
	var metadata_by_action_id: Dictionary = {}
	for raw_key: Variant in catalog.keys():
		var route: Dictionary = catalog.get(raw_key, {}) if catalog.get(raw_key, {}) is Dictionary else {}
		if route.is_empty() or str(route.get("type", "")) != "route":
			continue
		var raw_actions: Variant = route.get("actions", [])
		if not (raw_actions is Array):
			continue
		for raw_action: Variant in raw_actions:
			if not (raw_action is Dictionary):
				continue
			var action: Dictionary = raw_action
			var action_id := _action_id(action)
			if action_id == "" or action_id == "end_turn":
				continue
			var metadata: Dictionary = metadata_by_action_id.get(action_id, {})
			for key: String in ROUTE_ACTION_METADATA_KEYS:
				if action.has(key):
					metadata[key] = action.get(key)
			if not metadata.is_empty():
				metadata_by_action_id[action_id] = metadata
	return metadata_by_action_id


func _to_executable_route(queue: Array[Dictionary], catalog: Dictionary) -> Dictionary:
	var result: Array[Dictionary] = []
	var future_goals: Array[Dictionary] = []
	var notes: Array[String] = []
	for action: Dictionary in queue:
		var action_id := _action_id(action)
		if _is_future_or_virtual_ref(action) and action_id.begins_with("future:"):
			future_goals.append(action.duplicate(true))
			notes.append("removed_future_action_from_executable_queue")
			continue
		if _is_future_or_virtual_ref(action) and action_id.begins_with("virtual:"):
			var resolved: Dictionary = _resolve_virtual_action(action, catalog)
			if resolved.is_empty():
				notes.append("removed_unresolved_virtual_action")
				continue
			result.append(resolved)
			notes.append("resolved_virtual_action_to_legal_action")
			continue
		result.append(action)
	return {
		"queue": result,
		"future_goals": future_goals,
		"notes": notes,
	}


func _resolve_virtual_action(action: Dictionary, catalog: Dictionary) -> Dictionary:
	var action_type := str(action.get("type", action.get("kind", "")))
	var card_query := str(action.get("card", ""))
	var pokemon_query := str(action.get("pokemon", ""))
	for raw_key: Variant in catalog.keys():
		var action_id := str(raw_key)
		var ref: Dictionary = catalog.get(raw_key, {}) if catalog.get(raw_key, {}) is Dictionary else {}
		if ref.is_empty() or _is_future_or_virtual_ref(ref):
			continue
		if action_type != "" and str(ref.get("type", ref.get("kind", ""))) != action_type:
			continue
		if card_query != "" and not _ref_matches_query(ref, card_query):
			continue
		if pokemon_query != "" and not _ref_matches_query(ref, pokemon_query):
			continue
		var resolved: Dictionary = ref.duplicate(true)
		resolved["id"] = action_id
		resolved["action_id"] = action_id
		if action.has("interactions"):
			resolved["interactions"] = action.get("interactions")
		if action.has("selection_policy"):
			resolved["selection_policy"] = action.get("selection_policy")
		resolved["capability"] = _capability_for_ref(resolved)
		return resolved
	return {}


func _ref_matches_query(ref: Dictionary, query: String) -> bool:
	var search_text := _ref_search_text(ref)
	return _name_matches(search_text, query)


func _ref_search_text(ref: Dictionary) -> String:
	var parts: Array[String] = [
		str(ref.get("id", ref.get("action_id", ""))),
		str(ref.get("card", "")),
		str(ref.get("pokemon", "")),
		str(ref.get("target", "")),
		str(ref.get("ability", "")),
		str(ref.get("summary", "")),
	]
	for key: String in ["card_rules", "ability_rules", "attack_rules"]:
		var raw_rules: Variant = ref.get(key, {})
		if raw_rules is Dictionary:
			var rules: Dictionary = raw_rules
			for rule_key: String in ["name", "name_en", "text", "description", "effect_id"]:
				parts.append(str(rules.get(rule_key, "")))
	return " ".join(parts)


func _missed_high_value_actions(queue: Array[Dictionary], catalog: Dictionary, no_deck_draw_lock: bool = false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var route_ids := _route_action_ids(queue)
	var route_has_manual_attach := _queue_has_capability(queue, "manual_attach")
	for raw_key: Variant in catalog.keys():
		if result.size() >= 12:
			break
		var action_id := str(raw_key)
		if action_id == "" or bool(route_ids.get(action_id, false)):
			continue
		var ref: Dictionary = catalog.get(raw_key, {}) if catalog.get(raw_key, {}) is Dictionary else {}
		if ref.is_empty() or _is_future_or_virtual_ref(ref) or _is_end_turn_ref(ref):
			continue
		var capability := _capability_for_ref(ref)
		if capability == "manual_attach" and route_has_manual_attach:
			continue
		if no_deck_draw_lock and _is_draw_or_churn_ref(ref):
			continue
		if _is_hand_reset_draw_ref(ref):
			continue
		var priority := _insertion_priority(ref, false, false, false, no_deck_draw_lock)
		if priority >= 300:
			var copy: Dictionary = ref.duplicate(true)
			copy["id"] = action_id
			copy["action_id"] = action_id
			copy["capability"] = _capability_for_ref(copy)
			result.append(copy)
	return result


func _candidate_insertions(
	queue: Array[Dictionary],
	catalog: Dictionary,
	terminal_is_attack: bool,
	has_attack: bool,
	has_future_attack_goal: bool = false,
	no_deck_draw_lock: bool = false
) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var route_ids := _route_action_ids(queue)
	var route_has_manual_attach := _queue_has_capability(queue, "manual_attach")
	for raw_key: Variant in catalog.keys():
		var action_id := str(raw_key)
		if action_id == "" or bool(route_ids.get(action_id, false)):
			continue
		var ref: Dictionary = catalog.get(raw_key, {}) if catalog.get(raw_key, {}) is Dictionary else {}
		if ref.is_empty() or _is_future_or_virtual_ref(ref) or _is_end_turn_ref(ref):
			continue
		var capability := _capability_for_ref(ref)
		if capability == "manual_attach" and route_has_manual_attach:
			continue
		if no_deck_draw_lock and _is_draw_or_churn_ref(ref):
			continue
		if _is_hand_reset_draw_ref(ref):
			continue
		var priority := _insertion_priority(ref, terminal_is_attack, has_attack, has_future_attack_goal, no_deck_draw_lock)
		if priority <= 0:
			continue
		var copy: Dictionary = ref.duplicate(true)
		copy["id"] = action_id
		copy["action_id"] = action_id
		copy["capability"] = _capability_for_ref(copy)
		copy["_route_priority"] = priority
		candidates.append(copy)
	candidates.sort_custom(Callable(self, "_sort_candidates_desc"))
	for i: int in candidates.size():
		candidates[i].erase("_route_priority")
	return candidates


func _sort_candidates_desc(a: Dictionary, b: Dictionary) -> bool:
	var left := int(a.get("_route_priority", 0))
	var right := int(b.get("_route_priority", 0))
	if left == right:
		return _action_id(a) < _action_id(b)
	return left > right


func _insertion_priority(
	ref: Dictionary,
	terminal_is_attack: bool,
	has_attack: bool,
	has_future_attack_goal: bool = false,
	no_deck_draw_lock: bool = false
) -> int:
	var capability := _capability_for_ref(ref)
	if capability == "attack":
		return 950 if not has_attack else 0
	if capability == "terminal_draw_ability":
		return 0
	if no_deck_draw_lock and _is_draw_or_churn_ref(ref):
		return 0
	if has_future_attack_goal:
		match capability:
			"attach_tool":
				return 760
			"manual_attach":
				return 720 if not has_attack else 0
			_:
				return 0
	if terminal_is_attack:
		match capability:
			"attach_tool":
				return 760
			"charge_and_draw":
				return 730
			"draw_ability":
				return 710
			_:
				return 0
	match capability:
		"attach_tool":
			return 800
		"charge_and_draw":
			return 780
		"draw_ability":
			return 760
		"energy_search":
			return 740
		"discard_to_draw":
			return 720
		"draw_filter":
			return 680
		"resource_recovery":
			return 660
		"supporter_acceleration":
			return 650
		"bench_search":
			return 610
		"bench_basic":
			return 560
		"manual_attach":
			return 520
		"search":
			return 500
	return 0


func _future_goals_have_attack(future_goals: Array[Dictionary]) -> bool:
	for goal: Dictionary in future_goals:
		if _is_attack_ref(goal):
			return true
	return false


func _is_draw_or_deck_access_capability(capability: String) -> bool:
	return capability in [
		"charge_and_draw",
		"draw_ability",
		"terminal_draw_ability",
		"energy_search",
		"discard_to_draw",
		"draw_filter",
		"resource_recovery",
		"supporter_acceleration",
		"bench_search",
		"search",
	]


func _is_draw_or_churn_capability(capability: String) -> bool:
	return capability in [
		"charge_and_draw",
		"draw_ability",
		"terminal_draw_ability",
		"discard_to_draw",
		"draw_filter",
		"supporter_acceleration",
	]


func _is_draw_or_churn_ref(ref: Dictionary) -> bool:
	if _is_draw_or_churn_capability(_capability_for_ref(ref)):
		return true
	var action_type := str(ref.get("type", ref.get("kind", "")))
	if action_type == "use_ability":
		var schema_text := _schema_or_interaction_search_text(ref)
		if schema_text.contains("draw"):
			return true
		var schema: Dictionary = _schema_or_interactions(ref)
		if schema.has("basic_energy_from_hand") or schema.has("energy_card_id"):
			return true
		if schema.has("discard_card") or schema.has("discard_cards"):
			return true
	var combined := _combined_ref_name(ref)
	return _name_has_any(combined, [
		"trekking shoes",
		"concealed cards",
		"teal dance",
		"flip the script",
		"碧草之舞",
		"隐藏牌",
		"隱藏牌",
		"化危为吉",
		"化危為吉",
		"吉雉鸡",
		"吉雉雞",
		"光辉甲贺忍蛙",
		"光輝甲賀忍蛙",
		"厄诡椪",
		"厄鬼椪",
	])


func _schema_or_interaction_search_text(ref: Dictionary) -> String:
	var schema: Dictionary = _schema_or_interactions(ref)
	if schema.is_empty():
		return ""
	return JSON.stringify(schema).to_lower()


func _schema_or_interactions(ref: Dictionary) -> Dictionary:
	var schema: Dictionary = ref.get("interaction_schema", {}) if ref.get("interaction_schema", {}) is Dictionary else {}
	if not schema.is_empty():
		return schema
	return ref.get("interactions", {}) if ref.get("interactions", {}) is Dictionary else {}


func _remove_deck_draw_risk_actions(queue: Array[Dictionary]) -> Dictionary:
	var result: Array[Dictionary] = []
	var removed: Array[Dictionary] = []
	for action: Dictionary in queue:
		if _is_end_turn_ref(action) \
				or _is_attack_ref(action) \
				or _is_deck_draw_lock_exception(action) \
				or not _is_draw_or_churn_ref(action):
			result.append(action)
		else:
			removed.append(action)
	return {
		"queue": result,
		"removed_count": removed.size(),
		"removed_actions": removed,
	}


func _is_deck_draw_lock_exception(ref: Dictionary) -> bool:
	return bool(ref.get("allow_deck_draw_lock", false)) \
		or str(ref.get("deck_draw_lock_exception", "")) != ""


func _remove_gust_without_attack_goal(queue: Array[Dictionary]) -> Dictionary:
	var result: Array[Dictionary] = []
	var removed: Array[Dictionary] = []
	for action: Dictionary in queue:
		if _capability_for_ref(action) == "gust":
			removed.append(action)
			continue
		result.append(action)
	return {
		"queue": result,
		"removed_count": removed.size(),
		"removed_actions": removed,
	}


func _future_goals_allow_defensive_gust(future_goals: Array[Dictionary]) -> bool:
	for goal: Dictionary in future_goals:
		var goal_id := str(goal.get("id", ""))
		var goal_type := str(goal.get("type", ""))
		if goal_id.contains("defensive_gust") or goal_type == "defensive_gust":
			return true
	return false


func _remove_hand_reset_before_visible_setup(
	queue: Array[Dictionary],
	catalog: Dictionary,
	game_state: Variant,
	player_index: int
) -> Dictionary:
	if _hand_reset_route_allowed(queue, catalog, game_state, player_index):
		return {"queue": queue, "removed_count": 0, "removed_actions": []}
	var result: Array[Dictionary] = []
	var removed: Array[Dictionary] = []
	for action: Dictionary in queue:
		if _is_hand_reset_draw_ref(action):
			removed.append(action)
			continue
		result.append(action)
	return {
		"queue": result,
		"removed_count": removed.size(),
		"removed_actions": removed,
	}


func _hand_reset_route_allowed(
	queue: Array[Dictionary],
	catalog: Dictionary,
	game_state: Variant,
	player_index: int
) -> bool:
	if not _queue_has_hand_reset_draw(queue):
		return true
	if not _catalog_has_deterministic_setup(catalog):
		return true
	var hand_count := _player_hand_count(game_state, player_index)
	if hand_count >= 0 and hand_count <= 3:
		return true
	return false


func _queue_has_hand_reset_draw(queue: Array[Dictionary]) -> bool:
	for action: Dictionary in queue:
		if _is_hand_reset_draw_ref(action):
			return true
	return false


func _catalog_has_deterministic_setup(catalog: Dictionary) -> bool:
	for raw_key: Variant in catalog.keys():
		var ref: Dictionary = catalog.get(raw_key, {}) if catalog.get(raw_key, {}) is Dictionary else {}
		if ref.is_empty() or _is_end_turn_ref(ref) or _is_future_or_virtual_ref(ref):
			continue
		var capability := _capability_for_ref(ref)
		if capability in [
			"attach_tool",
			"charge_and_draw",
			"energy_search",
			"resource_recovery",
			"supporter_acceleration",
			"bench_search",
			"bench_basic",
			"manual_attach",
			"search",
		]:
			return true
	return false


func _player_deck_count(game_state: Variant, player_index: int) -> int:
	if game_state == null or player_index < 0:
		return -1
	var players: Variant = game_state.get("players") if game_state is Object else null
	if not (players is Array) or player_index >= (players as Array).size():
		return -1
	var player: Variant = (players as Array)[player_index]
	if player == null:
		return -1
	var deck: Variant = player.get("deck") if player is Object else null
	return (deck as Array).size() if deck is Array else -1


func _player_hand_count(game_state: Variant, player_index: int) -> int:
	if game_state == null or player_index < 0:
		return -1
	var players: Variant = game_state.get("players") if game_state is Object else null
	if not (players is Array) or player_index >= (players as Array).size():
		return -1
	var player: Variant = (players as Array)[player_index]
	if player == null:
		return -1
	var hand: Variant = player.get("hand") if player is Object else null
	return (hand as Array).size() if hand is Array else -1


func _low_value_redraw_locked(game_state: Variant, player_index: int, deck_count: int = -1) -> bool:
	var known_deck_count := deck_count
	if known_deck_count < 0:
		known_deck_count = _player_deck_count(game_state, player_index)
	if known_deck_count >= 0 and known_deck_count <= 12:
		return true
	var hand_count := _player_hand_count(game_state, player_index)
	return known_deck_count >= 0 and known_deck_count <= 24 and hand_count >= 4


func _capability_for_ref(ref: Dictionary) -> String:
	var explicit_capability := str(ref.get("capability", "")).strip_edges()
	if explicit_capability != "":
		return explicit_capability
	var action_type := str(ref.get("type", ref.get("kind", "")))
	if action_type == "end_turn" or _action_id(ref) == "end_turn":
		return "end_turn"
	if action_type in ["attack", "granted_attack"]:
		if _is_low_value_attack(ref):
			return "low_value_attack"
		return "attack"
	if action_type == "attach_energy":
		return "manual_attach"
	if action_type == "attach_tool":
		return "attach_tool"
	if action_type == "play_basic_to_bench":
		return "bench_basic"
	if action_type == "retreat":
		return "pivot"
	var tags: Array[String] = _ref_tags(ref)
	var card_name := str(ref.get("card", ""))
	var pokemon_name := str(ref.get("pokemon", ""))
	var combined_name := _combined_ref_name(ref)
	if action_type == "use_ability":
		if tags.has("ends_turn") and tags.has("draw"):
			return "terminal_draw_ability"
		if _is_fezandipiti_ref(ref, combined_name):
			return "draw_ability"
		if tags.has("charge_engine") and tags.has("draw"):
			return "charge_and_draw"
		if tags.has("discard") and tags.has("draw"):
			return "discard_to_draw"
		if tags.has("draw"):
			return "draw_ability"
		return "ability"
	if action_type == "play_trainer" or action_type == "play_stadium":
		if tags.has("gust") or _name_has_any(combined_name, ["boss", "catcher", "prime catcher"]):
			return "gust"
		if _name_has_any(combined_name, ["professor sada"]):
			return "supporter_acceleration"
		if tags.has("recover_to_hand") or _name_has_any(combined_name, ["night stretcher", "energy retrieval"]):
			return "resource_recovery"
		if tags.has("search_deck") and tags.has("energy_related"):
			return "energy_search"
		if _name_has_any(combined_name, ["earthen vessel"]):
			return "energy_search"
		if _name_has_any(combined_name, ["nest ball", "buddy-buddy poffin", "ultra ball"]):
			return "bench_search"
		if tags.has("draw") and tags.has("discard"):
			return "discard_to_draw"
		if tags.has("draw") or _name_has_any(combined_name, ["trekking shoes", "iono", "research", "gear"]):
			return "draw_filter"
		if tags.has("search_deck"):
			return "search"
	return action_type


func _combined_ref_name(ref: Dictionary) -> String:
	var parts: Array[String] = [
		str(ref.get("card", "")),
		str(ref.get("pokemon", "")),
		str(ref.get("ability", "")),
	]
	var card_rules: Variant = ref.get("card_rules", {})
	if card_rules is Dictionary:
		var rules: Dictionary = card_rules
		parts.append(str(rules.get("name", "")))
		parts.append(str(rules.get("name_en", "")))
		parts.append(str(rules.get("effect_id", "")))
	var ability_rules: Variant = ref.get("ability_rules", {})
	if ability_rules is Dictionary:
		var rules: Dictionary = ability_rules
		parts.append(str(rules.get("name", "")))
		parts.append(str(rules.get("text", "")))
	return " ".join(parts).to_lower()


func _is_hand_reset_draw_ref(ref: Dictionary) -> bool:
	if _capability_for_ref(ref) != "draw_filter":
		return false
	var combined := _combined_ref_name(ref)
	return _name_has_any(combined, [
		"iono",
		"professor's research",
		"professors research",
		"professor research",
		"research",
	])


func _is_fezandipiti_ref(ref: Dictionary, combined_name: String = "") -> bool:
	var text := combined_name if combined_name != "" else _combined_ref_name(ref)
	if text.contains("fezandipiti"):
		return true
	var card_rules: Variant = ref.get("card_rules", {})
	if card_rules is Dictionary:
		return str((card_rules as Dictionary).get("effect_id", "")) == "ab6c3357e2b8a8385a68da738f41e0c1"
	return false


func _ref_tags(ref: Dictionary) -> Array[String]:
	var result: Array[String] = []
	_append_tags(result, ref.get("tags", []))
	_append_tags(result, ref.get("rule_tags", []))
	var card_rules: Variant = ref.get("card_rules", {})
	if card_rules is Dictionary:
		_append_tags(result, (card_rules as Dictionary).get("tags", []))
	var ability_rules: Variant = ref.get("ability_rules", {})
	if ability_rules is Dictionary:
		_append_tags(result, (ability_rules as Dictionary).get("tags", []))
	var attack_rules: Variant = ref.get("attack_rules", {})
	if attack_rules is Dictionary:
		_append_tags(result, (attack_rules as Dictionary).get("tags", []))
	return result


func _append_tags(target: Array[String], raw_tags: Variant) -> void:
	if not (raw_tags is Array):
		return
	for raw_tag: Variant in raw_tags:
		var tag := str(raw_tag)
		if tag != "" and not target.has(tag):
			target.append(tag)


func _is_low_value_attack(ref: Dictionary) -> bool:
	var quality: Dictionary = ref.get("attack_quality", {}) if ref.get("attack_quality", {}) is Dictionary else {}
	if str(quality.get("terminal_priority", "")) == "low":
		return true
	var role := str(quality.get("role", ""))
	if role in ["desperation_redraw", "setup_draw"]:
		return true
	var attack_rules: Dictionary = ref.get("attack_rules", {}) if ref.get("attack_rules", {}) is Dictionary else {}
	var text := "%s %s %s".to_lower() % [
		str(ref.get("attack_name", "")),
		str(attack_rules.get("name", "")),
		str(attack_rules.get("text", "")),
	]
	return text.contains("discard your hand") or text.contains("hand") and text.contains("draw")


func _candidate_conflicts_with_route(candidate: Dictionary, route: Array[Dictionary]) -> bool:
	var candidate_id := _action_id(candidate)
	var candidate_conflicts := _resource_conflict_ids(candidate)
	for action: Dictionary in route:
		var action_id := _action_id(action)
		if action_id != "" and candidate_conflicts.has(action_id):
			return true
		var action_conflicts := _resource_conflict_ids(action)
		if candidate_id != "" and action_conflicts.has(candidate_id):
			return true
	return false


func _resource_conflict_ids(action: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var raw: Variant = action.get("resource_conflicts", [])
	if not (raw is Array):
		return result
	for raw_conflict: Variant in raw:
		var conflict := str(raw_conflict)
		if conflict != "" and not result.has(conflict):
			result.append(conflict)
	return result


func _first_terminal_index(queue: Array[Dictionary]) -> int:
	for i: int in queue.size():
		if _is_attack_ref(queue[i]) or _is_end_turn_ref(queue[i]):
			return i
	return -1


func _queue_has_attack(queue: Array[Dictionary]) -> bool:
	for action: Dictionary in queue:
		if _is_attack_ref(action):
			return true
	return false


func _queue_has_non_low_value_attack(queue: Array[Dictionary]) -> bool:
	for action: Dictionary in queue:
		if _is_attack_ref(action) and not _is_low_value_attack(action):
			return true
	return false


func _queue_has_capability(queue: Array[Dictionary], capability: String) -> bool:
	for action: Dictionary in queue:
		if _capability_for_ref(action) == capability:
			return true
	return false


func _route_contains_action_id(queue: Array[Dictionary], action_id: String) -> bool:
	if action_id == "":
		return false
	for action: Dictionary in queue:
		if _action_id(action) == action_id:
			return true
	return false


func _route_action_ids(queue: Array[Dictionary]) -> Dictionary:
	var result := {}
	for action: Dictionary in queue:
		var action_id := _action_id(action)
		if action_id != "":
			result[action_id] = true
	return result


func _is_attack_ref(ref: Dictionary) -> bool:
	var action_type := str(ref.get("type", ref.get("kind", "")))
	return action_type in ["attack", "granted_attack"]


func _is_end_turn_ref(ref: Dictionary) -> bool:
	var action_type := str(ref.get("type", ref.get("kind", "")))
	return action_type == "end_turn" or _action_id(ref) == "end_turn"


func _is_future_or_virtual_ref(ref: Dictionary) -> bool:
	var action_id := _action_id(ref)
	return bool(ref.get("future", false)) or action_id.begins_with("future:") or action_id.begins_with("virtual:")


func _action_id(ref: Dictionary) -> String:
	return str(ref.get("action_id", ref.get("id", "")))


func _name_has_any(text: String, needles: Array[String]) -> bool:
	for needle: String in needles:
		if text.contains(needle.to_lower()):
			return true
	return false


func _name_matches(actual: String, query: String) -> bool:
	var actual_lower := actual.strip_edges().to_lower()
	var query_lower := query.strip_edges().to_lower()
	if actual_lower == "" or query_lower == "":
		return false
	return actual_lower.contains(query_lower) or query_lower.contains(actual_lower)
