class_name LLMRouteCandidateBuilder
extends RefCounted

const MAX_ROUTES := 6
const MAX_ROUTE_ACTIONS := 8


func build_candidate_routes(
	current_actions: Array,
	future_actions: Array,
	tactical_facts: Dictionary = {}
) -> Array[Dictionary]:
	var current_refs: Array[Dictionary] = _dictionary_array(current_actions)
	var future_refs: Array[Dictionary] = _dictionary_array(future_actions)
	var routes: Array[Dictionary] = []
	var end_turn: Dictionary = _find_action_by_id(current_refs, "end_turn")
	var context := {
		"end_turn": end_turn,
		"future_actions": future_refs,
		"primary_attack_route": tactical_facts.get("primary_attack_route", []),
		"primary_attack_reachable": bool(tactical_facts.get("primary_attack_reachable_after_visible_engine", false)),
		"primary_attack_missing_cost": tactical_facts.get("primary_attack_missing_cost", []),
		"primary_attack_reachable_after_manual_attach": bool(tactical_facts.get("primary_attack_reachable_after_manual_attach", false)),
		"best_manual_attach_to_primary_attack_action_id": str(tactical_facts.get("best_manual_attach_to_primary_attack_action_id", "")),
		"best_manual_attach_energy_for_active_attack": str(tactical_facts.get("best_manual_attach_energy_for_active_attack", "")),
		"manual_attach_enables_best_active_attack": bool(tactical_facts.get("manual_attach_enables_best_active_attack", false)),
		"best_manual_attach_to_best_active_attack_action_id": str(tactical_facts.get("best_manual_attach_to_best_active_attack_action_id", "")),
		"best_active_attack_after_manual_attach": tactical_facts.get("best_active_attack_after_manual_attach", {}),
		"only_low_ready_attack": bool(tactical_facts.get("only_ready_attack_is_low_value_redraw", false)),
		"redraw_attack_forbidden": bool(tactical_facts.get("redraw_attack_forbidden", false)),
		"redraw_attack_recommended": bool(tactical_facts.get("redraw_attack_recommended", false)),
		"deck_draw_risk": bool(tactical_facts.get("deck_draw_risk", false)),
		"gust_ko_opportunities": tactical_facts.get("gust_ko_opportunities", []),
		"defensive_gust_opportunities": tactical_facts.get("defensive_gust_opportunities", []),
		"no_deck_draw_lock": bool(tactical_facts.get("no_deck_draw_lock", false)),
		"own_bench_count": int(tactical_facts.get("own_bench_count", -1)),
		"safe_pre_primary_actions": tactical_facts.get("safe_pre_primary_actions", []),
	}
	_append_route(routes, _build_gust_ko_route(current_refs, context))
	_append_route(routes, _build_defensive_gust_route(current_refs, context))
	_append_route(routes, _build_manual_attach_attack_route(current_refs, context))
	_append_route(routes, _build_manual_attach_active_attack_route(current_refs, context))
	_append_route(routes, _build_pivot_attack_route(current_refs, future_refs, context))
	_append_route(routes, _build_attack_now_route(current_refs, context))
	_append_route(routes, _build_primary_engine_route(current_refs, future_refs, context))
	_append_route(routes, _build_engine_before_end_route(current_refs, context))
	_append_route(routes, _build_manual_attach_setup_route(current_refs, context))
	_append_route(routes, _build_basic_setup_route(current_refs, context))
	_append_route(routes, _build_terminal_draw_fallback_route(current_refs))
	_append_route(routes, _build_preserve_route(end_turn))
	return _sorted_limited_routes(routes)


func _build_gust_ko_route(actions: Array[Dictionary], context: Dictionary) -> Dictionary:
	var opportunities: Array = context.get("gust_ko_opportunities", []) if context.get("gust_ko_opportunities", []) is Array else []
	if opportunities.is_empty():
		return {}
	var sorted_opportunities := _sorted_gust_ko_opportunities(opportunities, actions)
	var opportunity: Dictionary = sorted_opportunities[0] if not sorted_opportunities.is_empty() else {}
	if opportunity.is_empty():
		return {}
	var gust: Dictionary = _find_action_by_id(actions, str(opportunity.get("gust_action_id", "")))
	var attack: Dictionary = _find_action_by_id(actions, str(opportunity.get("attack_action_id", "")))
	if gust.is_empty() or attack.is_empty():
		return {}
	var gust_ref: Dictionary = gust.duplicate(true)
	var gust_deterministic := bool(opportunity.get("gust_deterministic", _gust_reliability_for_ref(gust_ref) == "deterministic"))
	gust_ref["gust_reliability"] = str(opportunity.get("gust_reliability", _gust_reliability_for_ref(gust_ref)))
	gust_ref["gust_deterministic"] = gust_deterministic
	var selection_policy: Dictionary = gust_ref.get("selection_policy", {}) if gust_ref.get("selection_policy", {}) is Dictionary else {}
	var policy_from_opportunity: Dictionary = opportunity.get("selection_policy", {}) if opportunity.get("selection_policy", {}) is Dictionary else {}
	for key: String in policy_from_opportunity.keys():
		selection_policy[key] = policy_from_opportunity.get(key)
	gust_ref["selection_policy"] = selection_policy
	return _route(
		"gust_ko",
		"Gust a damaged bench Pokemon that the listed attack can KO now; prioritize game-winning prize routes.",
		[_action_ref(gust_ref), _action_ref(attack)],
		990 if gust_deterministic else 850,
		"gust_ko",
		[{
			"id": "goal:gust_ko_target",
			"type": "goal",
			"target_position": str(opportunity.get("target_position", "")),
			"target_name": str(opportunity.get("target_name", "")),
			"game_winning": bool(opportunity.get("game_winning", false)),
			"gust_reliability": str(opportunity.get("gust_reliability", "")),
			"gust_deterministic": gust_deterministic,
		}]
	)


func _build_defensive_gust_route(actions: Array[Dictionary], context: Dictionary) -> Dictionary:
	var opportunities: Array = context.get("defensive_gust_opportunities", []) if context.get("defensive_gust_opportunities", []) is Array else []
	if opportunities.is_empty():
		return {}
	var opportunity: Dictionary = opportunities[0] if opportunities[0] is Dictionary else {}
	if opportunity.is_empty():
		return {}
	var gust: Dictionary = _find_action_by_id(actions, str(opportunity.get("gust_action_id", "")))
	if gust.is_empty():
		return {}
	var gust_ref: Dictionary = gust.duplicate(true)
	gust_ref["gust_reliability"] = "deterministic"
	gust_ref["gust_deterministic"] = true
	gust_ref["capability"] = "defensive_gust"
	var selection_policy: Dictionary = gust_ref.get("selection_policy", {}) if gust_ref.get("selection_policy", {}) is Dictionary else {}
	var policy_from_opportunity: Dictionary = opportunity.get("selection_policy", {}) if opportunity.get("selection_policy", {}) is Dictionary else {}
	for key: String in policy_from_opportunity.keys():
		selection_policy[key] = policy_from_opportunity.get(key)
	gust_ref["selection_policy"] = selection_policy
	var route_actions: Array[Dictionary] = [_action_ref(gust_ref)]
	_append_end_turn(route_actions, context)
	return _route(
		"defensive_gust_stall",
		"No attack route is available; gust a low-energy/high-retreat bench target to break the opponent active attack threat.",
		route_actions,
		975,
		"defensive_gust",
		[{
			"id": "goal:defensive_gust_target",
			"type": "goal",
			"target_position": str(opportunity.get("target_position", "")),
			"target_name": str(opportunity.get("target_name", "")),
			"opponent_active_name": str(opportunity.get("opponent_active_name", "")),
		}]
	)


func _build_pivot_attack_route(
	actions: Array[Dictionary],
	future_actions: Array[Dictionary],
	context: Dictionary
) -> Dictionary:
	var future_attack: Dictionary = _best_reachable_pivot_attack(future_actions)
	if future_attack.is_empty():
		return {}
	var bench_position := str(future_attack.get("position", ""))
	if bench_position == "":
		return {}
	var route_actions: Array[Dictionary] = []
	_append_action_refs(route_actions, _safe_pre_primary_action_refs(actions, context))
	var attach_energy := str(future_attack.get("best_manual_attach_energy", ""))
	if attach_energy != "":
		var attach: Dictionary = _find_manual_attach_to_position(actions, bench_position, attach_energy)
		if attach.is_empty():
			return {}
		_append_action_ref(route_actions, attach)
	var pivot: Dictionary = _find_pivot_to_position(actions, bench_position)
	if pivot.is_empty():
		return {}
	_append_action_ref(route_actions, pivot)
	_append_end_turn(route_actions, context)
	var future_goals: Array[Dictionary] = _context_future_goals(context)
	future_goals.push_front(_action_ref(future_attack))
	return _route(
		"pivot_to_primary_attack",
		"Charge or pivot to the reachable bench attacker, then let the runtime convert end_turn into the now-legal attack.",
		route_actions,
		970 if _future_attack_is_primary(future_attack) else 880,
		"pivot_to_attack",
		future_goals
	)


func _build_attack_now_route(actions: Array[Dictionary], context: Dictionary) -> Dictionary:
	var attack: Dictionary = _best_attack(actions)
	if attack.is_empty():
		return {}
	if _is_low_value_attack(attack) and _should_suppress_low_value_attack_route(actions, context):
		return {}
	if bool(context.get("only_low_ready_attack", false)) \
			and (bool(context.get("primary_attack_reachable", false)) \
			or bool(context.get("primary_attack_reachable_after_manual_attach", false)) \
			or bool(context.get("manual_attach_enables_best_active_attack", false))):
		return {}
	var route_actions: Array[Dictionary] = []
	if _is_low_value_attack(attack) and bool(context.get("redraw_attack_recommended", false)):
		_append_action_refs(route_actions, _safe_pre_low_value_redraw_actions(actions, bool(context.get("no_deck_draw_lock", false))))
	else:
		_append_action_refs(route_actions, _safe_pre_attack_actions(
			actions,
			bool(context.get("no_deck_draw_lock", false)),
			int(context.get("own_bench_count", -1))
		))
	_append_action_ref(route_actions, attack)
	return _route(
		"attack_now",
		"Use non-blocking setup, then take the best legal attack now.",
		route_actions,
		950,
		"attack",
		_context_future_goals(context)
	)


func _should_suppress_low_value_attack_route(actions: Array[Dictionary], context: Dictionary) -> bool:
	if bool(context.get("redraw_attack_forbidden", false)):
		return true
	if bool(context.get("deck_draw_risk", false)):
		return true
	if bool(context.get("primary_attack_reachable", false)) \
			or bool(context.get("primary_attack_reachable_after_manual_attach", false)) \
			or bool(context.get("manual_attach_enables_best_active_attack", false)):
		return true
	if bool(context.get("redraw_attack_recommended", false)):
		return false
	return _has_productive_non_terminal_action(actions)


func _has_productive_non_terminal_action(actions: Array[Dictionary]) -> bool:
	for ref: Dictionary in actions:
		if bool(ref.get("future", false)):
			continue
		var capability := _capability_for_ref(ref)
		if capability in ["end_turn", "attack", "low_value_attack", "terminal_draw_ability"]:
			continue
		if capability != "":
			return true
	return false


func _build_manual_attach_attack_route(actions: Array[Dictionary], context: Dictionary) -> Dictionary:
	if not bool(context.get("primary_attack_reachable_after_manual_attach", false)):
		return {}
	var attach_id := str(context.get("best_manual_attach_to_primary_attack_action_id", ""))
	if attach_id == "":
		return {}
	var attach: Dictionary = _find_action_by_id(actions, attach_id)
	if attach.is_empty():
		return {}
	var route_actions: Array[Dictionary] = [_action_ref(attach)]
	_append_end_turn(route_actions, context)
	return _route(
		"manual_attach_to_attack",
		"Manually attach the exact missing Energy that makes the primary attack live, then convert to the attack.",
		route_actions,
		980,
		"manual_attach_to_primary_attack",
		_context_future_goals(context)
	)


func _build_manual_attach_active_attack_route(actions: Array[Dictionary], context: Dictionary) -> Dictionary:
	if not bool(context.get("manual_attach_enables_best_active_attack", false)):
		return {}
	var attach_id := str(context.get("best_manual_attach_to_best_active_attack_action_id", ""))
	if attach_id == "" or attach_id == str(context.get("best_manual_attach_to_primary_attack_action_id", "")):
		return {}
	var attach: Dictionary = _find_action_by_id(actions, attach_id)
	if attach.is_empty():
		return {}
	var best_attack: Dictionary = context.get("best_active_attack_after_manual_attach", {}) if context.get("best_active_attack_after_manual_attach", {}) is Dictionary else {}
	if best_attack.is_empty() or _is_low_value_attack(best_attack):
		return {}
	var route_actions: Array[Dictionary] = [_action_ref(attach)]
	_append_end_turn(route_actions, context)
	var future_goals: Array[Dictionary] = _context_future_goals(context)
	future_goals.push_front({
		"id": "goal:manual_attach_best_active_attack",
		"type": "goal",
		"attack_name": str(best_attack.get("attack_name", "")),
		"attack_index": int(best_attack.get("attack_index", -1)),
		"attack_quality": best_attack.get("attack_quality", {}),
		"estimated_damage": int(best_attack.get("estimated_damage_after_best_manual_attach", 0)),
		"kos_opponent_active": bool(best_attack.get("kos_opponent_active_after_best_manual_attach", false)),
	})
	return _route(
		"manual_attach_to_active_attack",
		"Manually attach the exact Energy that makes the best active attack live, then convert to that attack.",
		route_actions,
		975 if not bool(best_attack.get("kos_opponent_active_after_best_manual_attach", false)) else 985,
		"manual_attach_to_active_attack",
		future_goals
	)


func _build_primary_engine_route(
	actions: Array[Dictionary],
	future_actions: Array[Dictionary],
	context: Dictionary
) -> Dictionary:
	var primary_future_attack: Dictionary = _best_future_primary_attack(future_actions)
	if primary_future_attack.is_empty() and not bool(context.get("primary_attack_reachable", false)):
		return {}
	var route_actions: Array[Dictionary] = []
	_append_action_refs(route_actions, _engine_actions(actions, true, bool(context.get("no_deck_draw_lock", false))))
	_append_best_manual_attach(route_actions, actions, context)
	_append_end_turn(route_actions, context)
	if route_actions.size() <= 1:
		return {}
	var future_goals: Array[Dictionary] = _context_future_goals(context)
	if not primary_future_attack.is_empty():
		future_goals.append(_action_ref(primary_future_attack))
	return _route(
		"primary_visible_engine",
		"Build the visible primary attack route with search, draw, acceleration, and attach before ending.",
		route_actions,
		980,
		"setup_to_primary_attack",
		future_goals
	)


func _build_engine_before_end_route(actions: Array[Dictionary], context: Dictionary) -> Dictionary:
	var route_actions: Array[Dictionary] = []
	_append_action_refs(route_actions, _engine_actions(actions, false, bool(context.get("no_deck_draw_lock", false))))
	_append_end_turn(route_actions, context)
	if route_actions.size() <= 1:
		return {}
	return _route(
		"engine_before_end",
		"Use productive engine actions before ending when no stronger attack route is executable.",
		route_actions,
		760,
		"engine_setup",
		_context_future_goals(context)
	)


func _build_manual_attach_setup_route(actions: Array[Dictionary], context: Dictionary) -> Dictionary:
	var route_actions: Array[Dictionary] = []
	_append_best_manual_attach(route_actions, actions, context)
	_append_action_refs(route_actions, _safe_non_attach_setup_actions(actions, bool(context.get("no_deck_draw_lock", false))))
	_append_end_turn(route_actions, context)
	if route_actions.size() <= 1:
		return {}
	return _route(
		"manual_attach_setup",
		"Attach the best visible Energy and add safe setup before ending.",
		route_actions,
		620,
		"manual_attach_setup",
		_context_future_goals(context)
	)


func _build_basic_setup_route(actions: Array[Dictionary], context: Dictionary) -> Dictionary:
	var route_actions: Array[Dictionary] = []
	for ref: Dictionary in _sort_by_priority(actions):
		if route_actions.size() >= 4:
			break
		if bool(context.get("no_deck_draw_lock", false)) and _is_draw_or_churn_ref(ref):
			continue
		if _capability_for_ref(ref) not in ["bench_basic", "bench_search", "attach_tool"]:
			continue
		_append_action_ref(route_actions, ref)
	_append_end_turn(route_actions, context)
	if route_actions.size() <= 1:
		return {}
	return _route(
		"basic_setup",
		"Develop bench or survival pieces when attack construction is not available.",
		route_actions,
		520,
		"board_setup",
		_context_future_goals(context)
	)


func _build_terminal_draw_fallback_route(actions: Array[Dictionary]) -> Dictionary:
	for ref: Dictionary in _sort_by_priority(actions):
		if _capability_for_ref(ref) != "terminal_draw_ability":
			continue
		return _route(
			"terminal_draw_fallback",
			"Use a draw ability that ends the turn only after no bench, evolution, search, attach, tool, gust, or attack route remains.",
			[_action_ref(ref)],
			160,
			"fallback_terminal_draw",
			[]
		)
	return {}


func _build_preserve_route(end_turn: Dictionary) -> Dictionary:
	if end_turn.is_empty():
		return {}
	return _route(
		"preserve_end",
		"End only when no productive legal route is safe.",
		[_action_ref(end_turn)],
		100,
		"fallback",
		[]
	)


func _append_route(routes: Array[Dictionary], route: Dictionary) -> void:
	if route.is_empty():
		return
	var ids := _route_action_ids(route.get("actions", []))
	if ids.is_empty():
		return
	for existing: Dictionary in routes:
		if _same_string_array(_route_action_ids(existing.get("actions", [])), ids):
			return
	routes.append(route)


func _sorted_limited_routes(routes: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = routes.duplicate(true)
	result.sort_custom(Callable(self, "_sort_route_priority_desc"))
	if result.size() > MAX_ROUTES:
		result.resize(MAX_ROUTES)
	return result


func _sort_route_priority_desc(a: Dictionary, b: Dictionary) -> bool:
	var left := int(a.get("priority", 0))
	var right := int(b.get("priority", 0))
	if left != right:
		return left > right
	return str(a.get("id", "")) < str(b.get("id", ""))


func _route(
	route_id: String,
	description: String,
	actions: Array[Dictionary],
	priority: int,
	goal: String,
	future_goals: Array[Dictionary]
) -> Dictionary:
	var clean_actions: Array[Dictionary] = _clean_route_actions(actions)
	if clean_actions.is_empty():
		return {}
	return {
		"id": route_id,
		"route_action_id": "route:%s" % route_id,
		"type": "candidate_route",
		"priority": priority,
		"goal": goal,
		"description": description,
		"actions": clean_actions,
		"future_goals": future_goals,
		"contract": "LLM may choose route_action_id as a single action; runtime expands it into these exact action refs.",
	}


func _clean_route_actions(actions: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	var has_manual_attach := false
	for action: Dictionary in actions:
		if result.size() >= MAX_ROUTE_ACTIONS:
			break
		var action_id := _action_id(action)
		if action_id == "":
			continue
		if action_id != "end_turn" and bool(seen.get(action_id, false)):
			continue
		var capability := _capability_for_ref(action)
		if capability == "manual_attach":
			if has_manual_attach:
				continue
			has_manual_attach = true
		if _conflicts_with_route(action, result):
			continue
		seen[action_id] = true
		result.append(_action_ref(action))
	return result


func _safe_pre_attack_actions(
	actions: Array[Dictionary],
	no_deck_draw_lock: bool = false,
	own_bench_count: int = -1
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for ref: Dictionary in _sort_by_priority(actions):
		if result.size() >= 3:
			break
		var capability := _capability_for_ref(ref)
		if no_deck_draw_lock and _is_draw_or_churn_ref(ref):
			continue
		if capability in ["attach_tool", "charge_and_draw", "draw_ability"] \
				or (own_bench_count == 0 and capability == "bench_basic"):
			result.append(ref)
	return result


func _safe_pre_low_value_redraw_actions(actions: Array[Dictionary], no_deck_draw_lock: bool = false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for ref: Dictionary in _sort_by_priority(actions):
		if result.size() >= 3:
			break
		var capability := _capability_for_ref(ref)
		if no_deck_draw_lock and _is_draw_or_churn_ref(ref):
			continue
		if capability in ["bench_basic", "bench_search", "attach_tool", "charge_and_draw"]:
			result.append(ref)
	return result


func _engine_actions(actions: Array[Dictionary], include_manual_support: bool, no_deck_draw_lock: bool = false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var allowed := [
		"attach_tool",
		"charge_and_draw",
		"draw_ability",
		"energy_search",
		"discard_to_draw",
		"draw_filter",
		"supporter_acceleration",
		"resource_recovery",
		"bench_search",
		"bench_basic",
		"search",
	]
	if include_manual_support:
		allowed.append("manual_attach")
	for ref: Dictionary in _sort_by_priority(actions):
		if result.size() >= 6:
			break
		var capability := _capability_for_ref(ref)
		if no_deck_draw_lock and _is_draw_or_churn_ref(ref):
			continue
		if include_manual_support and _is_hand_reset_draw_ref(ref):
			continue
		if capability in allowed:
			result.append(ref)
	return result


func _safe_non_attach_setup_actions(actions: Array[Dictionary], no_deck_draw_lock: bool = false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for ref: Dictionary in _sort_by_priority(actions):
		if result.size() >= 3:
			break
		var capability := _capability_for_ref(ref)
		if no_deck_draw_lock and _is_draw_or_churn_ref(ref):
			continue
		if capability in ["attach_tool", "charge_and_draw", "draw_ability", "bench_basic", "bench_search"]:
			result.append(ref)
	return result


func _safe_pre_primary_action_refs(actions: Array[Dictionary], context: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var raw_safe: Variant = context.get("safe_pre_primary_actions", [])
	if not (raw_safe is Array):
		return result
	for raw: Variant in raw_safe:
		if result.size() >= 2:
			break
		if not (raw is Dictionary):
			continue
		var safe_ref: Dictionary = raw
		var action_id := str(safe_ref.get("id", ""))
		if action_id == "":
			continue
		var action: Dictionary = _find_action_by_id(actions, action_id)
		if action.is_empty():
			continue
		if bool(context.get("no_deck_draw_lock", false)) and _is_draw_or_churn_ref(action):
			continue
		_append_action_ref(result, action)
	return result


func _is_draw_or_deck_access_capability(capability: String) -> bool:
	return capability in [
		"charge_and_draw",
		"draw_ability",
		"terminal_draw_ability",
		"energy_search",
		"discard_to_draw",
		"draw_filter",
		"resource_recovery",
		"bench_search",
		"search",
		"supporter_acceleration",
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


func _append_best_manual_attach(route_actions: Array[Dictionary], actions: Array[Dictionary], context: Dictionary = {}) -> void:
	var attack_cost_attach: Dictionary = _best_manual_attach_for_primary_cost(actions, context)
	if not attack_cost_attach.is_empty():
		_append_action_ref(route_actions, attack_cost_attach)
		return
	if _primary_attach_requires_specific_energy(context):
		return
	for ref: Dictionary in _sort_by_priority(actions):
		if _capability_for_ref(ref) == "manual_attach":
			_append_action_ref(route_actions, ref)
			return


func _best_manual_attach_for_primary_cost(actions: Array[Dictionary], context: Dictionary) -> Dictionary:
	var desired_symbols := _desired_primary_attach_symbols(context)
	if desired_symbols.is_empty():
		return {}
	for ref: Dictionary in _sort_by_priority(actions):
		if _capability_for_ref(ref) != "manual_attach":
			continue
		if str(ref.get("position", "")) != "active":
			continue
		var ref_symbol := _energy_symbol_from_word(str(ref.get("energy_type", "")))
		if ref_symbol == "":
			ref_symbol = _energy_symbol_from_word(str(ref.get("card", "")))
		if desired_symbols.has(ref_symbol):
			return ref
	return {}


func _desired_primary_attach_symbols(context: Dictionary) -> Array[String]:
	var desired_symbols: Array[String] = []
	var best_energy := _energy_symbol_from_word(str(context.get("best_manual_attach_energy_for_active_attack", "")))
	if best_energy != "":
		_append_unique_symbol(desired_symbols, best_energy)
	var raw_missing: Variant = context.get("primary_attack_missing_cost", [])
	if raw_missing is Array:
		for raw: Variant in raw_missing:
			_append_unique_symbol(desired_symbols, _energy_symbol_from_word(str(raw)))
	elif raw_missing is PackedStringArray:
		for raw_string: String in raw_missing:
			_append_unique_symbol(desired_symbols, _energy_symbol_from_word(raw_string))
	return desired_symbols


func _primary_attach_requires_specific_energy(context: Dictionary) -> bool:
	for symbol: String in _desired_primary_attach_symbols(context):
		if symbol != "" and symbol != "C":
			return true
	return false


func _append_unique_symbol(target: Array[String], symbol: String) -> void:
	if symbol != "" and not target.has(symbol):
		target.append(symbol)


func _append_end_turn(route_actions: Array[Dictionary], context: Dictionary) -> void:
	var end_turn: Dictionary = context.get("end_turn", {}) if context.get("end_turn", {}) is Dictionary else {}
	if not end_turn.is_empty():
		_append_action_ref(route_actions, end_turn)


func _append_action_refs(result: Array[Dictionary], refs: Array[Dictionary]) -> void:
	for ref: Dictionary in refs:
		_append_action_ref(result, ref)


func _append_action_ref(result: Array[Dictionary], ref: Dictionary) -> void:
	if ref.is_empty():
		return
	result.append(ref)


func _best_attack(actions: Array[Dictionary]) -> Dictionary:
	var best: Dictionary = {}
	var best_score := -999999
	for ref: Dictionary in actions:
		if str(ref.get("type", "")) not in ["attack", "granted_attack"]:
			continue
		var score := _action_priority(ref)
		if _is_low_value_attack(ref):
			score -= 500
		if score > best_score:
			best_score = score
			best = ref
	return best


func _best_reachable_pivot_attack(future_actions: Array[Dictionary]) -> Dictionary:
	var best: Dictionary = {}
	var best_score := -999999
	for ref: Dictionary in future_actions:
		if str(ref.get("type", "")) != "attack":
			continue
		if str(ref.get("prerequisite", "")) != "pivot_to_bench_attacker":
			continue
		if not bool(ref.get("reachable_with_known_resources", false)):
			continue
		if _is_low_value_attack(ref):
			continue
		var score := _action_priority(ref)
		if _future_attack_is_primary(ref):
			score += 250
		if score > best_score:
			best_score = score
			best = ref
	return best


func _future_attack_is_primary(ref: Dictionary) -> bool:
	var quality: Dictionary = ref.get("attack_quality", {}) if ref.get("attack_quality", {}) is Dictionary else {}
	return str(quality.get("role", "")) == "primary_damage" or str(quality.get("terminal_priority", "")) == "high"


func _find_manual_attach_to_position(actions: Array[Dictionary], position: String, energy_word: String) -> Dictionary:
	var requested_symbol := _energy_symbol_from_word(energy_word)
	if requested_symbol == "":
		return {}
	for ref: Dictionary in _sort_by_priority(actions):
		if str(ref.get("type", "")) != "attach_energy":
			continue
		if str(ref.get("position", "")) != position:
			continue
		var ref_symbol := _energy_symbol_from_word(str(ref.get("energy_type", "")))
		if ref_symbol == "":
			ref_symbol = _energy_symbol_from_word(str(ref.get("card", "")))
		if ref_symbol == requested_symbol:
			return ref
	return {}


func _find_pivot_to_position(actions: Array[Dictionary], position: String) -> Dictionary:
	for ref: Dictionary in _sort_by_priority(actions):
		if str(ref.get("type", "")) == "retreat" and str(ref.get("bench_position", "")) == position:
			return ref
	for ref: Dictionary in _sort_by_priority(actions):
		if str(ref.get("type", "")) == "retreat" and _action_id(ref).contains(":%s:" % position):
			return ref
	return {}


func _energy_symbol_from_word(energy_word: String) -> String:
	var lower := energy_word.strip_edges().to_lower()
	if lower == "":
		return ""
	if lower in ["l", "lightning"]:
		return "L"
	if lower in ["f", "fighting"]:
		return "F"
	if lower in ["g", "grass"]:
		return "G"
	if lower in ["r", "fire"]:
		return "R"
	if lower in ["p", "psychic"]:
		return "P"
	if lower in ["w", "water"]:
		return "W"
	if lower in ["d", "dark", "darkness"]:
		return "D"
	if lower in ["m", "metal"]:
		return "M"
	if lower in ["c", "colorless"]:
		return "C"
	if lower.contains("lightning"):
		return "L"
	if lower.contains("fighting"):
		return "F"
	if lower.contains("grass"):
		return "G"
	if lower.contains("fire"):
		return "R"
	if lower.contains("psychic"):
		return "P"
	if lower.contains("water"):
		return "W"
	if lower.contains("dark"):
		return "D"
	if lower.contains("metal"):
		return "M"
	if lower.contains("colorless"):
		return "C"
	return ""


func _best_future_primary_attack(future_actions: Array[Dictionary]) -> Dictionary:
	var best: Dictionary = {}
	var best_score := -999999
	for ref: Dictionary in future_actions:
		if str(ref.get("type", "")) != "attack":
			continue
		var quality: Dictionary = ref.get("attack_quality", {}) if ref.get("attack_quality", {}) is Dictionary else {}
		if str(quality.get("terminal_priority", "")) != "high" and str(quality.get("role", "")) != "primary_damage":
			continue
		if not bool(ref.get("reachable_with_known_resources", true)):
			continue
		var score := _action_priority(ref)
		if score > best_score:
			best_score = score
			best = ref
	return best


func _sort_by_priority(actions: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for ref: Dictionary in actions:
		if ref.is_empty():
			continue
		var copy := ref.duplicate(true)
		copy["_route_priority"] = _action_priority(copy)
		result.append(copy)
	result.sort_custom(Callable(self, "_sort_priority_desc"))
	for i: int in result.size():
		result[i].erase("_route_priority")
	return result


func _sort_priority_desc(a: Dictionary, b: Dictionary) -> bool:
	var left := int(a.get("_route_priority", 0))
	var right := int(b.get("_route_priority", 0))
	if left == right:
		return _action_id(a) < _action_id(b)
	return left > right


func _action_priority(ref: Dictionary) -> int:
	var capability := _capability_for_ref(ref)
	match capability:
		"attack":
			return 950
		"gust":
			return 900
		"attach_tool":
			return 820
		"charge_and_draw":
			return 800
		"draw_ability":
			return 780
		"terminal_draw_ability":
			return 160
		"energy_search":
			return 760
		"discard_to_draw":
			return 730
		"draw_filter":
			return 700
		"supporter_acceleration":
			return 690
		"resource_recovery":
			return 670
		"bench_search":
			return 620
		"bench_basic":
			return 580
		"manual_attach":
			return 540
		"search":
			return 500
		"low_value_attack":
			return 220
		"end_turn":
			return 10
	return 100


func _capability_for_ref(ref: Dictionary) -> String:
	var action_type := str(ref.get("type", ref.get("kind", "")))
	if action_type == "end_turn" or _action_id(ref) == "end_turn":
		return "end_turn"
	if action_type in ["attack", "granted_attack"]:
		return "low_value_attack" if _is_low_value_attack(ref) else "attack"
	if action_type == "attach_energy":
		return "manual_attach"
	if action_type == "attach_tool":
		return "attach_tool"
	if action_type == "play_basic_to_bench":
		return "bench_basic"
	if action_type == "retreat":
		return "pivot"
	var tags: Array[String] = _ref_tags(ref)
	var combined := _combined_ref_name(ref)
	if action_type == "use_ability":
		if tags.has("ends_turn") and tags.has("draw"):
			return "terminal_draw_ability"
		if tags.has("search_deck") and tags.has("pokemon_related"):
			return "bench_search"
		if tags.has("search_deck") and tags.has("bench_related"):
			return "bench_search"
		if tags.has("search_deck") and tags.has("energy_related"):
			return "energy_search"
		if tags.has("search_deck"):
			return "search"
		if _name_has_any(combined, ["fezandipiti"]):
			return "draw_ability"
		if tags.has("charge_engine") and tags.has("draw"):
			return "charge_and_draw"
		if tags.has("discard") and tags.has("draw"):
			return "discard_to_draw"
		if tags.has("draw"):
			return "draw_ability"
		return "ability"
	if action_type == "play_trainer" or action_type == "play_stadium":
		if tags.has("gust") or _name_has_any(combined, ["boss", "catcher"]):
			return "gust"
		if _name_has_any(combined, ["professor sada"]):
			return "supporter_acceleration"
		if tags.has("recover_to_hand") or _name_has_any(combined, ["night stretcher", "energy retrieval"]):
			return "resource_recovery"
		if tags.has("search_deck") and tags.has("energy_related"):
			return "energy_search"
		if _name_has_any(combined, ["earthen vessel"]):
			return "energy_search"
		if _name_has_any(combined, ["nest ball", "buddy-buddy poffin", "ultra ball"]):
			return "bench_search"
		if tags.has("draw") and tags.has("discard"):
			return "discard_to_draw"
		if tags.has("draw") or _name_has_any(combined, ["trekking shoes", "iono", "research", "gear"]):
			return "draw_filter"
		if tags.has("search_deck"):
			return "search"
	return action_type


func _is_low_value_attack(ref: Dictionary) -> bool:
	var quality: Dictionary = ref.get("attack_quality", {}) if ref.get("attack_quality", {}) is Dictionary else {}
	if str(quality.get("terminal_priority", "")) == "low":
		return true
	var text := _combined_ref_name(ref)
	return _name_has_any(text, ["discard your hand", "put your hand", "draw 6", "bursting roar", "飞溅咆哮"])


func _ref_tags(ref: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for raw: Variant in ref.get("tags", []):
		result.append(str(raw))
	var rules: Variant = ref.get("card_rules", {})
	if rules is Dictionary:
		for raw: Variant in (rules as Dictionary).get("tags", []):
			var tag := str(raw)
			if not result.has(tag):
				result.append(tag)
	var ability_rules: Variant = ref.get("ability_rules", {})
	if ability_rules is Dictionary:
		for raw: Variant in (ability_rules as Dictionary).get("tags", []):
			var tag := str(raw)
			if not result.has(tag):
				result.append(tag)
	return result


func _combined_ref_name(ref: Dictionary) -> String:
	var parts: Array[String] = [
		str(ref.get("id", "")),
		str(ref.get("card", "")),
		str(ref.get("pokemon", "")),
		str(ref.get("ability", "")),
		str(ref.get("attack_name", "")),
		str(ref.get("summary", "")),
	]
	for key: String in ["card_rules", "ability_rules", "attack_rules"]:
		var raw: Variant = ref.get(key, {})
		if raw is Dictionary:
			var rules: Dictionary = raw
			parts.append(str(rules.get("name", "")))
			parts.append(str(rules.get("name_en", "")))
			parts.append(str(rules.get("text", "")))
			parts.append(str(rules.get("description", "")))
			parts.append(str(rules.get("effect_id", "")))
	return " ".join(parts).to_lower()


func _context_future_goals(context: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var future_actions: Variant = context.get("future_actions", [])
	if future_actions is Array:
		for raw: Variant in future_actions:
			if result.size() >= 3:
				break
			if raw is Dictionary and str((raw as Dictionary).get("type", "")) == "attack":
				result.append(_action_ref(raw as Dictionary))
	var primary_route: Variant = context.get("primary_attack_route", [])
	if primary_route is Array and not (primary_route as Array).is_empty():
		result.append({
			"id": "goal:primary_attack_route",
			"type": "goal",
			"summary": " -> ".join(_string_array(primary_route)),
		})
	return result


func _sorted_gust_ko_opportunities(opportunities: Array, actions: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw: Variant in opportunities:
		if not (raw is Dictionary):
			continue
		var opportunity: Dictionary = (raw as Dictionary).duplicate(true)
		var gust: Dictionary = _find_action_by_id(actions, str(opportunity.get("gust_action_id", "")))
		var reliability := str(opportunity.get("gust_reliability", ""))
		if reliability == "" and not gust.is_empty():
			reliability = _gust_reliability_for_ref(gust)
		if reliability == "":
			reliability = "deterministic"
		opportunity["gust_reliability"] = reliability
		opportunity["gust_deterministic"] = reliability == "deterministic"
		result.append(opportunity)
	result.sort_custom(Callable(self, "_sort_gust_ko_opportunity_desc"))
	return result


func _sort_gust_ko_opportunity_desc(a: Dictionary, b: Dictionary) -> bool:
	var a_win := bool(a.get("game_winning", false))
	var b_win := bool(b.get("game_winning", false))
	if a_win != b_win:
		return a_win
	var a_det := bool(a.get("gust_deterministic", true))
	var b_det := bool(b.get("gust_deterministic", true))
	if a_det != b_det:
		return a_det
	var a_prizes := int(a.get("target_prize_count", 0))
	var b_prizes := int(b.get("target_prize_count", 0))
	if a_prizes != b_prizes:
		return a_prizes > b_prizes
	var a_hp := int(a.get("target_hp_remaining", 9999))
	var b_hp := int(b.get("target_hp_remaining", 9999))
	if a_hp != b_hp:
		return a_hp < b_hp
	return str(a.get("target_position", "")) < str(b.get("target_position", ""))


func _gust_reliability_for_ref(ref: Dictionary) -> String:
	var rules: Dictionary = ref.get("card_rules", {}) if ref.get("card_rules", {}) is Dictionary else {}
	var effect_id := str(rules.get("effect_id", ref.get("effect_id", "")))
	if effect_id == "3a6d419769778b40091e69fbd76737ec":
		return "coin_flip"
	var combined := _combined_ref_name(ref)
	if _name_has_any(combined, ["pokemon catcher"]):
		return "coin_flip"
	return "deterministic"


func _find_action_by_id(actions: Array[Dictionary], action_id: String) -> Dictionary:
	for ref: Dictionary in actions:
		if _action_id(ref) == action_id:
			return ref
	return {}


func _action_ref(ref: Dictionary) -> Dictionary:
	var action_id := _action_id(ref)
	var result := {
		"id": action_id,
		"type": str(ref.get("type", ref.get("kind", ""))),
		"capability": str(ref.get("capability", _capability_for_ref(ref))),
	}
	for key: String in [
		"card", "pokemon", "target", "position", "attack_name", "ability",
		"bench_target", "bench_position", "interaction_schema", "selection_policy",
		"interactions", "resource_conflicts", "consumes_hand_card_ids",
		"may_consume_hand_energy_symbols", "consumes_hand_energy_symbol",
		"future", "prerequisite", "reachable_with_known_resources",
		"gust_reliability", "gust_deterministic",
	]:
		if ref.has(key):
			result[key] = ref.get(key)
	return result


func _route_action_ids(raw_actions: Variant) -> Array[String]:
	var result: Array[String] = []
	if not (raw_actions is Array):
		return result
	for raw: Variant in raw_actions:
		if raw is Dictionary:
			var action_id := _action_id(raw as Dictionary)
			if action_id != "":
				result.append(action_id)
	return result


func _conflicts_with_route(action: Dictionary, route_actions: Array[Dictionary]) -> bool:
	var action_id := _action_id(action)
	var conflicts: Array[String] = _string_array(action.get("resource_conflicts", []))
	for existing: Dictionary in route_actions:
		var existing_id := _action_id(existing)
		if conflicts.has(existing_id):
			return true
		var existing_conflicts: Array[String] = _string_array(existing.get("resource_conflicts", []))
		if existing_conflicts.has(action_id):
			return true
	return false


func _same_string_array(left: Array[String], right: Array[String]) -> bool:
	if left.size() != right.size():
		return false
	for i: int in left.size():
		if left[i] != right[i]:
			return false
	return true


func _dictionary_array(raw_values: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw: Variant in raw_values:
		if raw is Dictionary:
			result.append(raw as Dictionary)
	return result


func _string_array(raw_values: Variant) -> Array[String]:
	var result: Array[String] = []
	if raw_values is Array:
		for raw: Variant in raw_values:
			result.append(str(raw))
	return result


func _action_id(ref: Dictionary) -> String:
	return str(ref.get("id", ref.get("action_id", ""))).strip_edges()


func _name_has_any(text: String, needles: Array[String]) -> bool:
	var lower := text.to_lower()
	for needle: String in needles:
		if lower.contains(needle.to_lower()):
			return true
	return false
