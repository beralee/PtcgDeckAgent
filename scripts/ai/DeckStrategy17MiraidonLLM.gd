extends "res://scripts/ai/DeckStrategy17LLMBase.gd"

const MIRAIDON_LLM_SUPPORT_PIVOTS: Array[String] = ["Mew ex", "梦幻ex", "Latias ex", "拉帝亚斯ex", "Lumineon V", "Squawkabilly ex", "怒鹦哥ex", "Fezandipiti ex", "Iron Bundle", "铁包袱"]


func _llm_strategy_id() -> String:
	return "v17_miraidon_llm"


func _rules_strategy_path() -> String:
	return "res://scripts/ai/DeckStrategy17Miraidon.gd"


func _deck_display_name() -> String:
	return "17.0 密勒顿"


func _deck_primary_attackers() -> Array[String]:
	return ["Miraidon ex", "密勒顿ex", "Iron Hands ex", "铁臂膀ex", "Raikou V", "雷公V", "Raichu V", "雷丘V", "Pikachu ex", "皮卡丘ex", "CSV9C_054"]


func _deck_secondary_attackers() -> Array[String]:
	return ["Zapdos", "Bloodmoon Ursaluna ex"]


func _deck_support_pokemon() -> Array[String]:
	return ["Mew ex", "梦幻ex", "Latias ex", "拉帝亚斯ex", "Lumineon V", "Squawkabilly ex", "怒鹦哥ex", "Fezandipiti ex", "Iron Bundle", "铁包袱", "Magnemite", "小磁怪", "Magneton", "三合一磁怪"]


func _deck_energy_banks() -> Array[String]:
	return ["Raichu V", "Iron Hands ex"]


func _deck_primary_attacks() -> Array:
	return [
		{"pokemon": "Iron Hands ex", "attack": "Amp You Very Much"},
		{"pokemon": "铁臂膀ex", "attack": "多谢款待"},
		{"pokemon": "Raikou V", "attack": "Lightning Rondo"},
		{"pokemon": "雷公V", "attack": "闪电回旋"},
		{"pokemon": "Miraidon ex", "attack": "Photon Blaster"},
		{"pokemon": "密勒顿ex", "attack": "光子引爆"},
		{"pokemon": "Raichu V", "attack": "Dynamic Spark"},
		{"pokemon": "雷丘V", "attack": "爆能火花"},
		{"pokemon": "皮卡丘ex", "attack": "黄晶伏特"},
	]


func _deck_low_value_attacks() -> Array:
	return [{"pokemon": "Raichu V", "attack": "Fast Charge"}]


func _deck_setup_draw_attacks() -> Array:
	return [{"pokemon": "Raichu V", "attack": "Fast Charge"}]


func _deck_energy_needs() -> Dictionary:
	return {
		"Miraidon ex": {"L": 2, "C": 1},
		"Iron Hands ex": {"L": 2, "C": 1},
		"Raikou V": {"L": 1, "C": 1},
		"Raichu V": {"L": 1},
		"Pikachu ex": {"L": 2},
	}


func _deck_route_terms() -> Array[String]:
	return ["串联装置", "电气发生器", "零之大空洞", "黄晶伏特", "光子引爆", "多谢款待", "闪电回旋", "爆能火花", "基本雷能量"]


func _deck_core_plan() -> PackedStringArray:
	return PackedStringArray([
		"【核心计划】第一目标是 Miraidon ex 或检索牌启动铺场，打开 Area Zero 后把后场铺到 6 只以上，支撑 Raikou V / Miraidon ex / Pikachu ex 的高打点。",
		"【快攻路线】后手第一回合若能用 Raikou V、Miraidon ex、Iron Hands ex 或 Zapdos 直接制造有效伤害，应优先完成铺场、发电、贴能、换位后攻击。",
		"[Mirror prize race] On the first attacking turn, prioritize an executable Raikou V or Miraidon ex attack line over Mew ex draw/setup. Do not attach Lightning Energy to Mew ex unless it is the only way to pay retreat into a real attacker.",
		"【发电原则】Electric Generator 先确保后场有可接雷能的真实攻击手，再使用。雷能优先给本回合能攻击或下回合能接棒的 Iron Hands ex、Raikou V、Miraidon ex、Pikachu ex。",
		"【资源原则】Raichu V 是终结爆发，不要早期无目的上场或消耗全场雷能；Iron Hands ex 的额外奖赏路线价值很高，能拿奖时优先规划。",
	])


func _deck_augment_action_id_payload(payload: Dictionary, game_state: GameState, player_index: int) -> Dictionary:
	var result: Dictionary = super._deck_augment_action_id_payload(payload, game_state, player_index)
	var redirect := _miraidon_llm_support_attach_redirect(result, game_state, player_index)
	if not redirect.is_empty():
		_miraidon_llm_rewrite_support_attach_routes(result, redirect)
		_miraidon_llm_add_support_attach_facts(result, redirect)
	_miraidon_llm_add_ready_handoff_route(result)
	return result


func _deck_can_replace_end_turn_with_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	return _miraidon_llm_is_real_ready_attack_action(action, game_state, player_index)


func _deck_should_block_end_turn(game_state: GameState, player_index: int) -> bool:
	return _miraidon_llm_active_has_real_ready_attack(game_state, player_index)


func _deck_is_high_pressure_attack_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	return _miraidon_llm_is_real_ready_attack_action(action, game_state, player_index)


func _deck_should_block_exact_queue_match(queued_action: Dictionary, runtime_action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if _miraidon_llm_is_support_pivot_attach_action(runtime_action) \
			and _miraidon_llm_has_better_energy_target(runtime_action, game_state, player_index):
		return true
	if str(runtime_action.get("kind", runtime_action.get("type", ""))) == "retreat":
		if _miraidon_llm_should_block_unready_support_retreat(runtime_action, game_state, player_index):
			return true
	return super._deck_should_block_exact_queue_match(queued_action, runtime_action, game_state, player_index)


func _deck_queue_item_matches_action(queued_action: Dictionary, runtime_action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if _miraidon_llm_queued_support_attach_matches_attacker_attach(queued_action, runtime_action, game_state, player_index):
		return true
	return super._deck_queue_item_matches_action(queued_action, runtime_action, game_state, player_index)


func _miraidon_llm_add_ready_handoff_route(result: Dictionary) -> void:
	var facts: Dictionary = result.get("turn_tactical_facts", {}) if result.get("turn_tactical_facts", {}) is Dictionary else {}
	var route := _miraidon_llm_ready_handoff_candidate_route(result, facts)
	if route.is_empty():
		return
	var routes: Array = result.get("candidate_routes", []) if result.get("candidate_routes", []) is Array else []
	var updated_routes := routes.duplicate(true)
	if not _miraidon_llm_payload_has_route(updated_routes, "route:miraidon_ready_handoff_attack"):
		updated_routes.push_front(route)
	result["candidate_routes"] = updated_routes

	var updated_facts := facts.duplicate(true)
	var actions: Array = route.get("actions", []) if route.get("actions", []) is Array else []
	var pivot_action := _miraidon_llm_route_action_by_capability(actions, "ready_bench_handoff")
	if pivot_action.is_empty() and not actions.is_empty() and actions[0] is Dictionary:
		pivot_action = actions[0]
	var manual_attach_action_id := str(route.get("manual_attach_action_id", ""))
	updated_facts["miraidon_ready_handoff"] = {
		"route_available": true,
		"route_action_id": "route:miraidon_ready_handoff_attack",
		"pivot_action_id": str(pivot_action.get("id", "")),
		"requires_manual_attach": manual_attach_action_id != "",
		"manual_attach_action_id": manual_attach_action_id,
		"bench_position": str(route.get("bench_position", "")),
		"attack_name": str(route.get("attack_name", "")),
		"reason": "A support active can pivot to a ready Miraidon attacker; do not end after Mew/setup draw.",
	}
	result["turn_tactical_facts"] = updated_facts
	if manual_attach_action_id != "":
		_miraidon_llm_add_handoff_attach_conflicts(result, manual_attach_action_id, str(route.get("bench_position", "")))


func _miraidon_llm_route_action_by_capability(actions: Array, capability: String) -> Dictionary:
	for raw: Variant in actions:
		if raw is Dictionary and str((raw as Dictionary).get("capability", "")) == capability:
			return raw
	return {}


func _miraidon_llm_add_handoff_attach_conflicts(result: Dictionary, preferred_action_id: String, bench_position: String) -> void:
	var legal_actions: Array = result.get("legal_actions", []) if result.get("legal_actions", []) is Array else []
	var preferred_ref := _miraidon_llm_legal_ref_by_id(legal_actions, preferred_action_id)
	if preferred_ref.is_empty():
		return
	var preferred_token := _miraidon_llm_attach_card_token(preferred_ref)
	var conflict_refs: Array[Dictionary] = []
	for raw: Variant in legal_actions:
		if not (raw is Dictionary):
			continue
		var ref: Dictionary = raw
		var action_id := _miraidon_llm_ref_id(ref)
		if action_id == "" or action_id == preferred_action_id:
			continue
		if str(ref.get("type", ref.get("kind", ""))) != "attach_energy":
			continue
		if preferred_token != "" and _miraidon_llm_attach_card_token(ref) != preferred_token:
			continue
		if str(ref.get("position", "")).strip_edges() == bench_position:
			continue
		conflict_refs.append(ref)
	if conflict_refs.is_empty():
		return

	var facts: Dictionary = result.get("turn_tactical_facts", {}) if result.get("turn_tactical_facts", {}) is Dictionary else {}
	facts = facts.duplicate(true)
	var negatives: Array = facts.get("resource_negative_actions", []) if facts.get("resource_negative_actions", []) is Array else []
	var updated_negatives := negatives.duplicate(true)
	for ref: Dictionary in conflict_refs:
		var blocked_id := _miraidon_llm_ref_id(ref)
		if _miraidon_llm_action_list_has_id(updated_negatives, blocked_id):
			continue
		updated_negatives.append({
			"id": blocked_id,
			"type": "attach_energy",
			"target": _miraidon_llm_ref_target_name(ref, null, -1),
			"preferred_action_id": preferred_action_id,
			"reason": "This Energy is needed on the same benched attacker before the Miraidon handoff attack.",
			"instruction": "use the preferred attach before pivoting; attaching the same Energy elsewhere strands the handoff attacker",
		})
	facts["resource_negative_actions"] = updated_negatives
	result["turn_tactical_facts"] = facts

	var intent_facts: Dictionary = result.get("intent_facts", {}) if result.get("intent_facts", {}) is Dictionary else {}
	intent_facts = intent_facts.duplicate(true)
	var hard_blocks: Array = intent_facts.get("hard_blocks", []) if intent_facts.get("hard_blocks", []) is Array else []
	var updated_blocks := hard_blocks.duplicate(true)
	for ref: Dictionary in conflict_refs:
		var blocked_id := _miraidon_llm_ref_id(ref)
		if _miraidon_llm_action_list_has_id(updated_blocks, blocked_id):
			continue
		updated_blocks.append({
			"action_id": blocked_id,
			"replacement_action_id": preferred_action_id,
			"reason": "The same Energy must be attached to the handoff attacker to make the post-pivot attack legal.",
		})
	intent_facts["hard_blocks"] = updated_blocks
	result["intent_facts"] = intent_facts


func _miraidon_llm_legal_ref_by_id(legal_actions: Array, action_id: String) -> Dictionary:
	for raw: Variant in legal_actions:
		if raw is Dictionary and _miraidon_llm_ref_id(raw as Dictionary) == action_id:
			return raw
	return {}


func _miraidon_llm_ready_handoff_candidate_route(payload: Dictionary, facts: Dictionary) -> Dictionary:
	if bool(facts.get("primary_attack_ready", false)):
		return {}
	var future_attack := _miraidon_llm_best_ready_handoff_future(payload)
	if future_attack.is_empty():
		return {}
	var bench_position := str(future_attack.get("position", "")).strip_edges()
	if bench_position == "":
		return {}
	var legal_actions: Array = payload.get("legal_actions", []) if payload.get("legal_actions", []) is Array else []
	var pivot_ref := _miraidon_llm_best_handoff_pivot_ref(legal_actions, bench_position)
	if pivot_ref.is_empty():
		return {}
	var attach_ref := _miraidon_llm_handoff_manual_attach_ref(legal_actions, future_attack, bench_position)
	if _miraidon_llm_future_attack_requires_manual_attach(future_attack) and attach_ref.is_empty():
		return {}
	var pivot_action := _miraidon_llm_route_ref(pivot_ref)
	pivot_action["capability"] = "ready_bench_handoff"
	pivot_action["selection_policy"] = _miraidon_llm_handoff_selection_policy(bench_position)
	var future_goal := future_attack.duplicate(true)
	future_goal["type"] = "attack"
	future_goal["future"] = true
	future_goal["attack_quality"] = _miraidon_llm_handoff_attack_quality(future_attack)
	var route_actions: Array = []
	if not attach_ref.is_empty():
		var attach_action := _miraidon_llm_route_ref(attach_ref)
		attach_action["capability"] = "manual_attach_for_handoff_attack"
		attach_action["selection_policy"] = {
			"attach_target": bench_position,
			"reason": "This Energy must go to the same attacker that will receive the pivot.",
		}
		route_actions.append(attach_action)
	route_actions.append(pivot_action)
	route_actions.append({"id": "end_turn", "action_id": "end_turn", "type": "end_turn"})
	return {
		"id": "miraidon_ready_handoff_attack",
		"route_action_id": "route:miraidon_ready_handoff_attack",
		"type": "candidate_route",
		"priority": 982,
		"base_priority": 982,
		"goal": "pivot_to_attack",
		"description": "Pivot a support active into the listed ready Miraidon attacker, then let runtime convert end_turn into the attack.",
		"bench_position": bench_position,
		"attack_name": str(future_attack.get("attack_name", "")),
		"requires_manual_attach": not attach_ref.is_empty(),
		"manual_attach_action_id": _miraidon_llm_ref_id(attach_ref),
		"actions": route_actions,
		"future_goals": [future_goal],
		"contract": "Select this route when active Mew/support would otherwise draw or end while a benched Raikou, Miraidon, Iron Hands, Pikachu, or Raichu attack is already reachable.",
		"strategy_adjustable": true,
	}


func _miraidon_llm_future_attack_requires_manual_attach(ref: Dictionary) -> bool:
	if not (ref.get("missing_cost_now", []) is Array):
		return false
	var missing_now: Array = ref.get("missing_cost_now", [])
	if missing_now.is_empty():
		return false
	var missing_after: Array = ref.get("missing_cost_after_prerequisite", missing_now) if ref.get("missing_cost_after_prerequisite", missing_now) is Array else missing_now
	return missing_after.is_empty()


func _miraidon_llm_handoff_manual_attach_ref(legal_actions: Array, future_attack: Dictionary, bench_position: String) -> Dictionary:
	if not _miraidon_llm_future_attack_requires_manual_attach(future_attack):
		return {}
	var needed_energy := str(future_attack.get("best_manual_attach_energy", "")).strip_edges()
	for raw: Variant in legal_actions:
		if not (raw is Dictionary):
			continue
		var ref: Dictionary = raw
		if str(ref.get("type", ref.get("kind", ""))) != "attach_energy":
			continue
		if str(ref.get("position", "")).strip_edges() != bench_position:
			continue
		if not _miraidon_llm_handoff_attach_energy_matches(ref, needed_energy):
			continue
		return ref
	return {}


func _miraidon_llm_handoff_attach_energy_matches(ref: Dictionary, needed_energy: String) -> bool:
	if needed_energy == "":
		return true
	var normalized := needed_energy.strip_edges().to_lower()
	var text := _miraidon_llm_ref_text(ref).to_lower()
	match normalized:
		"l", "lightning", "lightning energy", "basic lightning energy":
			return text.contains("lightning") or text.contains("雷")
		_:
			return text.contains(normalized)


func _miraidon_llm_handoff_attack_quality(future_attack: Dictionary) -> Dictionary:
	var quality: Dictionary = future_attack.get("attack_quality", {}) if future_attack.get("attack_quality", {}) is Dictionary else {}
	var result := quality.duplicate(true)
	var source := str(future_attack.get("source_pokemon", future_attack.get("pokemon", "")))
	if _matches_any(source, _deck_primary_attackers()) or _matches_any(source, _deck_secondary_attackers()):
		result["role"] = "primary_damage"
		result["terminal_priority"] = "high"
		result["takes_prize"] = true
	if result.is_empty():
		result = {"role": "primary_damage", "terminal_priority": "high", "takes_prize": true}
	return result


func _miraidon_llm_best_ready_handoff_future(payload: Dictionary) -> Dictionary:
	var future_actions: Array = payload.get("future_actions", []) if payload.get("future_actions", []) is Array else []
	var best_ref: Dictionary = {}
	var best_score := -999999
	for raw: Variant in future_actions:
		if not (raw is Dictionary):
			continue
		var ref: Dictionary = raw
		if not _miraidon_llm_future_attack_is_handoff_candidate(ref):
			continue
		var score := _miraidon_llm_future_attack_score(ref)
		if score <= best_score:
			continue
		best_ref = ref
		best_score = score
	return best_ref


func _miraidon_llm_future_attack_is_handoff_candidate(ref: Dictionary) -> bool:
	var action_id := _miraidon_llm_ref_id(ref)
	if not action_id.begins_with("future:attack_after_pivot:"):
		return false
	if not bool(ref.get("reachable_with_known_resources", false)):
		return false
	if ref.get("missing_cost_after_prerequisite", []) is Array and not (ref.get("missing_cost_after_prerequisite", []) as Array).is_empty():
		return false
	var position := str(ref.get("position", "")).strip_edges()
	if not position.begins_with("bench_"):
		return false
	var source := str(ref.get("source_pokemon", ref.get("pokemon", ""))).strip_edges()
	if source == "" or not (_matches_any(source, _deck_primary_attackers()) or _matches_any(source, _deck_secondary_attackers())):
		return false
	var quality: Dictionary = ref.get("attack_quality", {}) if ref.get("attack_quality", {}) is Dictionary else {}
	var role := str(quality.get("role", ""))
	var terminal_priority := str(quality.get("terminal_priority", ""))
	if terminal_priority == "low" or role in ["setup_draw", "desperation_redraw"]:
		return false
	return true


func _miraidon_llm_future_attack_score(ref: Dictionary) -> int:
	var quality: Dictionary = ref.get("attack_quality", {}) if ref.get("attack_quality", {}) is Dictionary else {}
	var score := 0
	match str(quality.get("terminal_priority", "")):
		"high":
			score += 1000
		"medium":
			score += 760
		_:
			score += 420
	var source := str(ref.get("source_pokemon", ref.get("pokemon", "")))
	if _matches_any(source, ["Iron Hands ex", "铁臂膀ex"]):
		score += 170
	elif _matches_any(source, ["Raikou V", "雷公V"]):
		score += 150
	elif _matches_any(source, ["Miraidon ex", "密勒顿ex"]):
		score += 130
	elif _matches_any(source, ["Pikachu ex", "皮卡丘ex", "CSV9C_054"]):
		score += 110
	elif _matches_any(source, ["Raichu V", "雷丘V"]):
		score += 90
	if bool(quality.get("takes_prize", false)):
		score += 60
	return score


func _miraidon_llm_best_handoff_pivot_ref(legal_actions: Array, bench_position: String) -> Dictionary:
	var best_ref: Dictionary = {}
	var best_score := -999999
	for raw: Variant in legal_actions:
		if not (raw is Dictionary):
			continue
		var ref: Dictionary = raw
		var score := _miraidon_llm_handoff_pivot_ref_score(ref, bench_position)
		if score <= best_score:
			continue
		best_ref = ref
		best_score = score
	return best_ref


func _miraidon_llm_handoff_pivot_ref_score(ref: Dictionary, bench_position: String) -> int:
	var action_id := _miraidon_llm_ref_id(ref)
	var kind := str(ref.get("type", ref.get("kind", "")))
	var text := _miraidon_llm_ref_text(ref)
	if kind == "retreat" and action_id.contains("retreat:%s" % bench_position):
		return 1040
	if kind != "play_trainer":
		return -999999
	if _v17_name_contains(text, "Switch") and not _v17_name_contains(text, "Switching Cups"):
		return 1010
	if _v17_name_contains(text, "Prime Catcher"):
		return 980
	if _v17_name_contains(text, "Escape Rope"):
		return 720
	return -999999


func _miraidon_llm_handoff_selection_policy(bench_position: String) -> Dictionary:
	return {
		"own_bench_target": bench_position,
		"switch_target": bench_position,
		"self_pivot_target": bench_position,
		"target_position": bench_position,
	}


func _miraidon_llm_support_attach_redirect(payload: Dictionary, game_state: GameState, player_index: int) -> Dictionary:
	var legal_actions: Array = payload.get("legal_actions", []) if payload.get("legal_actions", []) is Array else []
	var best_redirect: Dictionary = {}
	var best_score := -999999.0
	for raw: Variant in legal_actions:
		if not (raw is Dictionary):
			continue
		var bad_ref: Dictionary = raw
		if str(bad_ref.get("type", bad_ref.get("kind", ""))) != "attach_energy":
			continue
		if not _miraidon_llm_ref_targets_support_pivot(bad_ref, game_state, player_index):
			continue
		var preferred := _miraidon_llm_best_redirect_attach_ref(bad_ref, legal_actions, game_state, player_index)
		if preferred.is_empty():
			continue
		var score := _miraidon_llm_attach_target_score(preferred, game_state, player_index)
		if score > best_score:
			best_score = score
			best_redirect = {
				"blocked_action_id": _miraidon_llm_ref_id(bad_ref),
				"blocked_target": _miraidon_llm_ref_target_name(bad_ref, game_state, player_index),
				"preferred_action_id": _miraidon_llm_ref_id(preferred),
				"preferred_target": _miraidon_llm_ref_target_name(preferred, game_state, player_index),
				"preferred_ref": preferred.duplicate(true),
				"reason": "Mew ex and other support pivots should not receive Lightning while a real Miraidon attacker can use it.",
			}
	return best_redirect


func _miraidon_llm_best_redirect_attach_ref(
	blocked_ref: Dictionary,
	legal_actions: Array,
	game_state: GameState,
	player_index: int
) -> Dictionary:
	var best_ref: Dictionary = {}
	var best_score := -999999.0
	for raw: Variant in legal_actions:
		if not (raw is Dictionary):
			continue
		var ref: Dictionary = raw
		if str(ref.get("type", ref.get("kind", ""))) != "attach_energy":
			continue
		if _miraidon_llm_ref_id(ref) == _miraidon_llm_ref_id(blocked_ref):
			continue
		if not _miraidon_llm_refs_use_same_energy_card(blocked_ref, ref):
			continue
		if _miraidon_llm_ref_targets_support_pivot(ref, game_state, player_index):
			continue
		var score := _miraidon_llm_attach_target_score(ref, game_state, player_index)
		if score <= 0.0:
			continue
		if score > best_score:
			best_score = score
			best_ref = ref
	return best_ref


func _miraidon_llm_rewrite_support_attach_routes(result: Dictionary, redirect: Dictionary) -> void:
	var blocked_id := str(redirect.get("blocked_action_id", ""))
	var preferred_ref: Dictionary = redirect.get("preferred_ref", {}) if redirect.get("preferred_ref", {}) is Dictionary else {}
	if blocked_id == "" or preferred_ref.is_empty():
		return
	var routes: Array = result.get("candidate_routes", []) if result.get("candidate_routes", []) is Array else []
	var updated_routes: Array = []
	for raw_route: Variant in routes:
		if not (raw_route is Dictionary):
			updated_routes.append(raw_route)
			continue
		var route: Dictionary = (raw_route as Dictionary).duplicate(true)
		var actions: Array = route.get("actions", []) if route.get("actions", []) is Array else []
		var updated_actions: Array = []
		var changed := false
		for raw_action: Variant in actions:
			if raw_action is Dictionary and _miraidon_llm_ref_id(raw_action as Dictionary) == blocked_id:
				updated_actions.append(_miraidon_llm_route_ref(preferred_ref))
				changed = true
			else:
				updated_actions.append(raw_action)
		if changed:
			route["actions"] = updated_actions
			route["miraidon_support_attach_redirect"] = {
				"from": blocked_id,
				"to": str(redirect.get("preferred_action_id", "")),
			}
		updated_routes.append(route)
	result["candidate_routes"] = updated_routes


func _miraidon_llm_add_support_attach_facts(result: Dictionary, redirect: Dictionary) -> void:
	var facts: Dictionary = result.get("turn_tactical_facts", {}) if result.get("turn_tactical_facts", {}) is Dictionary else {}
	facts = facts.duplicate(true)
	facts["miraidon_support_pivot_energy_redirect"] = {
		"blocked_action_id": str(redirect.get("blocked_action_id", "")),
		"blocked_target": str(redirect.get("blocked_target", "")),
		"preferred_action_id": str(redirect.get("preferred_action_id", "")),
		"preferred_target": str(redirect.get("preferred_target", "")),
		"reason": str(redirect.get("reason", "")),
	}
	var negatives: Array = facts.get("resource_negative_actions", []) if facts.get("resource_negative_actions", []) is Array else []
	var updated_negatives := negatives.duplicate(true)
	if not _miraidon_llm_action_list_has_id(updated_negatives, str(redirect.get("blocked_action_id", ""))):
		updated_negatives.append({
			"id": str(redirect.get("blocked_action_id", "")),
			"type": "attach_energy",
			"target": str(redirect.get("blocked_target", "")),
			"preferred_action_id": str(redirect.get("preferred_action_id", "")),
			"reason": str(redirect.get("reason", "")),
			"instruction": "redirect this Energy to the preferred real attacker unless no legal attacker target remains",
		})
	facts["resource_negative_actions"] = updated_negatives
	result["turn_tactical_facts"] = facts

	var intent_facts: Dictionary = result.get("intent_facts", {}) if result.get("intent_facts", {}) is Dictionary else {}
	intent_facts = intent_facts.duplicate(true)
	var hard_blocks: Array = intent_facts.get("hard_blocks", []) if intent_facts.get("hard_blocks", []) is Array else []
	var updated_blocks := hard_blocks.duplicate(true)
	if not _miraidon_llm_action_list_has_id(updated_blocks, str(redirect.get("blocked_action_id", ""))):
		updated_blocks.append({
			"action_id": str(redirect.get("blocked_action_id", "")),
			"replacement_action_id": str(redirect.get("preferred_action_id", "")),
			"reason": str(redirect.get("reason", "")),
		})
	intent_facts["hard_blocks"] = updated_blocks
	result["intent_facts"] = intent_facts


func _miraidon_llm_queued_support_attach_matches_attacker_attach(
	queued_action: Dictionary,
	runtime_action: Dictionary,
	game_state: GameState,
	player_index: int
) -> bool:
	if str(queued_action.get("type", queued_action.get("kind", ""))) != "attach_energy":
		return false
	if str(runtime_action.get("kind", runtime_action.get("type", ""))) != "attach_energy":
		return false
	if not _miraidon_llm_ref_targets_support_pivot(queued_action, game_state, player_index):
		return false
	if not _miraidon_llm_runtime_attach_targets_real_attacker(runtime_action):
		return false
	if not _miraidon_llm_runtime_attach_is_useful(runtime_action):
		return false
	return _miraidon_llm_queue_and_runtime_use_same_card(queued_action, runtime_action)


func _miraidon_llm_is_support_pivot_attach_action(action: Dictionary) -> bool:
	if str(action.get("kind", action.get("type", ""))) != "attach_energy":
		return false
	var target: PokemonSlot = action.get("target_slot", null)
	return _miraidon_llm_is_support_pivot_slot(target)


func _miraidon_llm_has_better_energy_target(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var excluded: PokemonSlot = action.get("target_slot", null)
	var player: PlayerState = game_state.players[player_index]
	for slot: PokemonSlot in _miraidon_llm_all_slots(player):
		if slot == excluded:
			continue
		if _miraidon_llm_is_real_energy_target_slot(slot) and _miraidon_llm_runtime_attach_is_useful({"target_slot": slot}):
			return true
	return false


func _miraidon_llm_ref_targets_support_pivot(ref: Dictionary, game_state: GameState, player_index: int) -> bool:
	var target_name := _miraidon_llm_ref_target_name(ref, game_state, player_index)
	return _matches_any(target_name, MIRAIDON_LLM_SUPPORT_PIVOTS)


func _miraidon_llm_ref_target_name(ref: Dictionary, game_state: GameState, player_index: int) -> String:
	var target_name := str(ref.get("target", ref.get("pokemon", ""))).strip_edges()
	if target_name != "":
		return target_name
	var position := str(ref.get("position", "")).strip_edges()
	var slot := _miraidon_llm_slot_by_position(game_state, player_index, position)
	return _slot_name(slot)


func _miraidon_llm_attach_target_score(ref: Dictionary, game_state: GameState, player_index: int) -> float:
	var target_name := _miraidon_llm_ref_target_name(ref, game_state, player_index)
	if _matches_any(target_name, MIRAIDON_LLM_SUPPORT_PIVOTS):
		return -1000.0
	if _matches_any(target_name, ["Iron Hands ex", "铁臂膀ex"]):
		return 1000.0
	if _matches_any(target_name, ["Raikou V", "雷公V"]):
		return 940.0
	if _matches_any(target_name, ["Raichu V", "雷丘V"]):
		return 900.0
	if _matches_any(target_name, ["Miraidon ex", "密勒顿ex"]):
		return 820.0
	if _matches_any(target_name, ["Pikachu ex", "皮卡丘ex", "CSV9C_054"]):
		return 780.0
	if _matches_any(target_name, _deck_primary_attackers()) or _matches_any(target_name, _deck_secondary_attackers()):
		return 500.0
	return 0.0


func _miraidon_llm_runtime_attach_targets_real_attacker(action: Dictionary) -> bool:
	var target: PokemonSlot = action.get("target_slot", null)
	return _miraidon_llm_is_real_energy_target_slot(target)


func _miraidon_llm_active_has_real_ready_attack(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null or player.active_pokemon.get_card_data() == null:
		return false
	var cd: CardData = player.active_pokemon.get_card_data()
	for attack_index: int in cd.attacks.size():
		var attack: Dictionary = cd.attacks[attack_index] if cd.attacks[attack_index] is Dictionary else {}
		if attack.is_empty():
			continue
		var ref := {
			"kind": "attack",
			"type": "attack",
			"attack_index": attack_index,
			"attack_name": str(attack.get("name", "")),
			"attack_rules": attack,
		}
		if _miraidon_llm_is_real_ready_attack_action(ref, game_state, player_index):
			return true
	return false


func _miraidon_llm_is_real_ready_attack_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	var action_type := str(action.get("kind", action.get("type", "")))
	if action_type != "attack" and action_type != "granted_attack":
		return false
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or player.active_pokemon == null or player.active_pokemon.get_card_data() == null:
		return false
	var active: PokemonSlot = player.active_pokemon
	if not _miraidon_llm_is_real_energy_target_slot(active):
		return false
	var attack_index := int(action.get("attack_index", -1))
	var attack_rules := _miraidon_llm_attack_rules(active, attack_index)
	var attack_name := str(action.get("attack_name", action.get("attack", ""))).strip_edges()
	if attack_name == "" and not attack_rules.is_empty():
		attack_name = str(attack_rules.get("name", "")).strip_edges()
	if _miraidon_llm_attack_name_is_low_value(attack_name):
		return false
	if not attack_rules.is_empty() and not _active_attack_cost_ready(active, str(attack_rules.get("cost", ""))):
		return false
	var quality: Dictionary = action.get("attack_quality", {}) if action.get("attack_quality", {}) is Dictionary else {}
	var role := str(quality.get("role", ""))
	var terminal_priority := str(quality.get("terminal_priority", ""))
	if terminal_priority == "low" or role in ["setup_draw", "desperation_redraw"]:
		return false
	return true


func _miraidon_llm_should_block_unready_support_retreat(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or not _miraidon_llm_is_support_pivot_slot(player.active_pokemon):
		return false
	var raw_target: Variant = action.get("bench_target", null)
	if not (raw_target is PokemonSlot):
		return false
	var target: PokemonSlot = raw_target
	if target == null or not _miraidon_llm_is_real_energy_target_slot(target):
		return false
	return not _miraidon_llm_slot_has_real_ready_attack(target)


func _miraidon_llm_slot_has_real_ready_attack(slot: PokemonSlot) -> bool:
	if slot == null or slot.get_card_data() == null or not _miraidon_llm_is_real_energy_target_slot(slot):
		return false
	var attacks: Array = slot.get_card_data().attacks
	for attack_index: int in attacks.size():
		var attack: Dictionary = attacks[attack_index] if attacks[attack_index] is Dictionary else {}
		if attack.is_empty():
			continue
		var attack_name := str(attack.get("name", "")).strip_edges()
		if _miraidon_llm_attack_name_is_low_value(attack_name):
			continue
		if _active_attack_cost_ready(slot, str(attack.get("cost", ""))):
			return true
	return false


func _miraidon_llm_attack_rules(slot: PokemonSlot, attack_index: int) -> Dictionary:
	if slot == null or slot.get_card_data() == null:
		return {}
	var attacks: Array = slot.get_card_data().attacks
	if attack_index >= 0 and attack_index < attacks.size() and attacks[attack_index] is Dictionary:
		return (attacks[attack_index] as Dictionary).duplicate(true)
	if attacks.size() == 1 and attacks[0] is Dictionary:
		return (attacks[0] as Dictionary).duplicate(true)
	return {}


func _miraidon_llm_attack_name_is_low_value(attack_name: String) -> bool:
	var text := attack_name.strip_edges()
	if text == "":
		return false
	return _v17_name_contains(text, "Fast Charge")


func _miraidon_llm_is_real_energy_target_slot(slot: PokemonSlot) -> bool:
	if slot == null:
		return false
	var name := _slot_name(slot)
	if _matches_any(name, MIRAIDON_LLM_SUPPORT_PIVOTS):
		return false
	return _matches_any(name, _deck_primary_attackers()) or _matches_any(name, _deck_secondary_attackers())


func _miraidon_llm_is_support_pivot_slot(slot: PokemonSlot) -> bool:
	return slot != null and _matches_any(_slot_name(slot), MIRAIDON_LLM_SUPPORT_PIVOTS)


func _miraidon_llm_runtime_attach_is_useful(action: Dictionary) -> bool:
	var target: PokemonSlot = action.get("target_slot", null)
	if target == null:
		return false
	var max_energy := _miraidon_llm_max_useful_energy(target)
	return max_energy <= 0 or target.attached_energy.size() < max_energy


func _miraidon_llm_max_useful_energy(slot: PokemonSlot) -> int:
	var name := _slot_name(slot)
	if _matches_any(name, ["Raichu V", "雷丘V"]):
		return 8
	if _matches_any(name, ["Iron Hands ex", "铁臂膀ex"]):
		return 4
	if _matches_any(name, ["Miraidon ex", "密勒顿ex"]):
		return 3
	if _matches_any(name, ["Raikou V", "雷公V"]):
		return 2
	if _matches_any(name, ["Pikachu ex", "皮卡丘ex", "CSV9C_054"]):
		return 3
	return 3


func _miraidon_llm_refs_use_same_energy_card(left: Dictionary, right: Dictionary) -> bool:
	var left_token := _miraidon_llm_attach_card_token(left)
	var right_token := _miraidon_llm_attach_card_token(right)
	if left_token != "" and right_token != "":
		return left_token == right_token
	var left_card := str(left.get("card", "")).strip_edges()
	var right_card := str(right.get("card", "")).strip_edges()
	return left_card == "" or right_card == "" or left_card == right_card


func _miraidon_llm_queue_and_runtime_use_same_card(queued_action: Dictionary, runtime_action: Dictionary) -> bool:
	var queued_token := _miraidon_llm_attach_card_token(queued_action)
	var runtime_card: CardInstance = runtime_action.get("card", null)
	if queued_token != "" and runtime_card != null:
		return queued_token == "c%d" % int(runtime_card.instance_id)
	var queued_card := str(queued_action.get("card", "")).strip_edges()
	if queued_card == "" or runtime_card == null or runtime_card.card_data == null:
		return true
	var runtime_name := "%s %s" % [str(runtime_card.card_data.name_en), str(runtime_card.card_data.name)]
	return _v17_name_contains(runtime_name, queued_card) or _v17_name_contains(queued_card, runtime_name)


func _miraidon_llm_attach_card_token(ref: Dictionary) -> String:
	var action_id := _miraidon_llm_ref_id(ref)
	var parts := action_id.split(":")
	if parts.size() >= 2 and parts[0] == "attach_energy":
		return str(parts[1])
	return ""


func _miraidon_llm_ref_id(ref: Dictionary) -> String:
	return str(ref.get("action_id", ref.get("id", ""))).strip_edges()


func _miraidon_llm_ref_text(ref: Dictionary) -> String:
	var parts: Array[String] = [
		str(ref.get("id", ref.get("action_id", ""))),
		str(ref.get("type", ref.get("kind", ""))),
		str(ref.get("card", "")),
		str(ref.get("summary", "")),
		str(ref.get("target", "")),
	]
	return " ".join(parts)


func _miraidon_llm_route_ref(ref: Dictionary) -> Dictionary:
	var route_ref: Dictionary = {}
	for key: String in ["id", "action_id", "type", "kind", "card", "position", "target", "requires_interaction", "interaction_schema", "resource_conflicts", "summary"]:
		if ref.has(key):
			route_ref[key] = ref[key]
	if not route_ref.has("action_id"):
		route_ref["action_id"] = _miraidon_llm_ref_id(ref)
	if not route_ref.has("id"):
		route_ref["id"] = _miraidon_llm_ref_id(ref)
	if not route_ref.has("type"):
		route_ref["type"] = str(ref.get("kind", "attach_energy"))
	return route_ref


func _miraidon_llm_action_list_has_id(actions: Array, action_id: String) -> bool:
	if action_id == "":
		return false
	for raw: Variant in actions:
		if raw is Dictionary and _miraidon_llm_ref_id(raw as Dictionary) == action_id:
			return true
	return false


func _miraidon_llm_payload_has_route(routes: Array, route_action_id: String) -> bool:
	for raw: Variant in routes:
		if raw is Dictionary and str((raw as Dictionary).get("route_action_id", "")) == route_action_id:
			return true
	return false


func _miraidon_llm_slot_by_position(game_state: GameState, player_index: int, position: String) -> PokemonSlot:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return null
	var player: PlayerState = game_state.players[player_index]
	if position == "active":
		return player.active_pokemon
	if position.begins_with("bench_"):
		var index := int(position.substr("bench_".length()))
		if index >= 0 and index < player.bench.size():
			return player.bench[index]
	return null


func _miraidon_llm_all_slots(player: PlayerState) -> Array[PokemonSlot]:
	var slots: Array[PokemonSlot] = []
	if player == null:
		return slots
	if player.active_pokemon != null:
		slots.append(player.active_pokemon)
	for slot: PokemonSlot in player.bench:
		if slot != null:
			slots.append(slot)
	return slots
