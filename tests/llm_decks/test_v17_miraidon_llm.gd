class_name TestV17MiraidonLLM
extends TestBase

const MIRAIDON_LLM_SCRIPT_PATH := "res://scripts/ai/DeckStrategy17MiraidonLLM.gd"


func _new_llm_strategy() -> RefCounted:
	CardInstance.reset_id_counter()
	var script: Variant = load(MIRAIDON_LLM_SCRIPT_PATH)
	return script.new() if script is GDScript else null


func _make_pokemon_cd(
	pname: String,
	stage: String = "Basic",
	energy_type: String = "L",
	hp: int = 100,
	attacks: Array = []
) -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.name_en = pname
	cd.card_type = "Pokemon"
	cd.stage = stage
	cd.energy_type = energy_type
	cd.hp = hp
	cd.attacks.clear()
	for attack: Dictionary in attacks:
		cd.attacks.append(attack.duplicate(true))
	return cd


func _make_energy(name: String = "Lightning Energy", provides: String = "L") -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = "Basic Energy"
	cd.energy_type = provides
	cd.energy_provides = provides
	return cd


func _make_slot(card_data: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner))
	return slot


func _make_card(card_data: CardData, owner: int = 0) -> CardInstance:
	return CardInstance.create(card_data, owner)


func _attach_energy(slot: PokemonSlot, provides: String, count: int, owner: int = 0) -> void:
	for i: int in count:
		slot.attached_energy.append(_make_card(_make_energy("%s Energy %d" % [provides, i], provides), owner))


func _make_game_state() -> GameState:
	var gs := GameState.new()
	gs.turn_number = 4
	gs.current_player_index = 0
	gs.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		player.active_pokemon = _make_slot(_make_pokemon_cd(
			"Mew ex",
			"Basic",
			"P",
			180,
			[{"name": "Genome Hacking", "cost": "CCC", "damage": ""}]
		), player_index)
		gs.players.append(player)
	return gs


func _profile_has_name(profile: Dictionary, key: String, name: String) -> bool:
	var entries: Array = profile.get(key, []) if profile.get(key, []) is Array else []
	for raw: Variant in entries:
		if str(raw) == name:
			return true
	return false


func _route_action_ids(routes: Array, route_action_id: String) -> Array[String]:
	for raw_route: Variant in routes:
		if not (raw_route is Dictionary):
			continue
		var route: Dictionary = raw_route
		if str(route.get("route_action_id", "")) != route_action_id:
			continue
		var ids: Array[String] = []
		var actions: Array = route.get("actions", []) if route.get("actions", []) is Array else []
		for raw_action: Variant in actions:
			if raw_action is Dictionary:
				ids.append(str((raw_action as Dictionary).get("id", (raw_action as Dictionary).get("action_id", ""))))
		return ids
	return []


func _route_by_id(routes: Array, route_action_id: String) -> Dictionary:
	for raw_route: Variant in routes:
		if raw_route is Dictionary and str((raw_route as Dictionary).get("route_action_id", "")) == route_action_id:
			return raw_route
	return {}


func test_v17_miraidon_llm_marks_mew_as_support_not_attacker() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "Miraidon LLM strategy should instantiate"
	var profile: Dictionary = strategy.call("get_intent_planner_profile")

	return run_checks([
		assert_true(_profile_has_name(profile, "support_only", "Mew ex"), "Mew ex should be exposed as a support pivot"),
		assert_false(_profile_has_name(profile, "secondary_attackers", "Mew ex"), "Mew ex should not be exposed as a secondary attacker"),
	])


func test_v17_miraidon_llm_payload_redirects_mew_attach_to_real_attacker() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "Miraidon LLM strategy should instantiate"
	var payload := {
		"legal_actions": [
			{"id": "attach_energy:c12:active", "type": "attach_energy", "card": "Lightning Energy", "position": "active", "target": "Mew ex"},
			{"id": "attach_energy:c12:bench_0", "type": "attach_energy", "card": "Lightning Energy", "position": "bench_0", "target": "Raikou V"},
			{"id": "end_turn", "type": "end_turn"},
		],
		"candidate_routes": [
			{
				"id": "manual_attach_setup",
				"route_action_id": "route:manual_attach_setup",
				"actions": [
					{"id": "attach_energy:c12:active", "type": "attach_energy", "card": "Lightning Energy", "position": "active", "target": "Mew ex"},
					{"id": "end_turn", "type": "end_turn"},
				],
			},
		],
		"turn_tactical_facts": {"resource_negative_actions": []},
		"intent_facts": {"hard_blocks": []},
	}
	var augmented: Dictionary = strategy.call("_deck_augment_action_id_payload", payload, null, -1)
	var facts: Dictionary = augmented.get("turn_tactical_facts", {}) if augmented.get("turn_tactical_facts", {}) is Dictionary else {}
	var redirect: Dictionary = facts.get("miraidon_support_pivot_energy_redirect", {}) if facts.get("miraidon_support_pivot_energy_redirect", {}) is Dictionary else {}
	var ids := _route_action_ids(augmented.get("candidate_routes", []), "route:manual_attach_setup")
	var intent_facts: Dictionary = augmented.get("intent_facts", {}) if augmented.get("intent_facts", {}) is Dictionary else {}
	var hard_blocks: Array = intent_facts.get("hard_blocks", []) if intent_facts.get("hard_blocks", []) is Array else []

	return run_checks([
		assert_eq(str(redirect.get("blocked_action_id", "")), "attach_energy:c12:active", "Payload should explain the blocked Mew attach"),
		assert_eq(str(redirect.get("preferred_action_id", "")), "attach_energy:c12:bench_0", "Payload should prefer attaching the same Energy to Raikou"),
		assert_true(ids.has("attach_energy:c12:bench_0"), "Candidate route should be rewritten to the real attacker attach"),
		assert_false(ids.has("attach_energy:c12:active"), "Candidate route should no longer recommend the Mew attach"),
		assert_true(not hard_blocks.is_empty(), "Intent facts should hard-block the Mew attach"),
	])


func test_v17_miraidon_llm_queue_redirects_mew_attach_to_attacker() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "Miraidon LLM strategy should instantiate"
	var gs := _make_game_state()
	var player: PlayerState = gs.players[0]
	var raikou := _make_slot(_make_pokemon_cd(
		"Raikou V",
		"Basic",
		"L",
		200,
		[{"name": "Lightning Rondo", "cost": "LC", "damage": "20+"}]
	), 0)
	_attach_energy(raikou, "L", 1)
	player.bench.append(raikou)
	var energy := _make_card(_make_energy(), 0)
	var token := "c%d" % int(energy.instance_id)
	var queued := {
		"id": "attach_energy:%s:active" % token,
		"action_id": "attach_energy:%s:active" % token,
		"type": "attach_energy",
		"card": "Lightning Energy",
		"position": "active",
		"target": "Mew ex",
	}
	var mew_attach := {"kind": "attach_energy", "card": energy, "target_slot": player.active_pokemon}
	var raikou_attach := {"kind": "attach_energy", "card": energy, "target_slot": raikou}

	return run_checks([
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", queued, mew_attach, gs, 0)), "Exact queued Mew attach should be blocked while Raikou can use the Energy"),
		assert_true(bool(strategy.call("_deck_queue_item_matches_action", queued, raikou_attach, gs, 0)), "Queued Mew attach should match a same-card redirect to Raikou"),
	])


func test_v17_miraidon_llm_blocks_support_retreat_to_unready_attacker() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "Miraidon LLM strategy should instantiate"
	var gs := _make_game_state()
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Mew ex", "Basic", "P", 180), 0)
	var iron_hands := _make_slot(_make_pokemon_cd(
		"Iron Hands ex",
		"Basic",
		"L",
		230,
		[
			{"name": "Arm Press", "cost": "LLC", "damage": "160"},
			{"name": "Amp You Very Much", "cost": "LCCC", "damage": "120"},
		]
	), 0)
	player.bench.append(iron_hands)
	var queued := {"id": "retreat:bench_0:none", "action_id": "retreat:bench_0:none", "type": "retreat", "position": "bench_0"}
	var runtime_retreat := {"kind": "retreat", "bench_target": iron_hands}
	var string_target_retreat := {"kind": "retreat", "bench_target": "bench_0"}
	var string_target_blocked := bool(strategy.call("_deck_should_block_exact_queue_match", queued, string_target_retreat, gs, 0))
	var blocked_before_ready := bool(strategy.call("_deck_should_block_exact_queue_match", queued, runtime_retreat, gs, 0))
	_attach_energy(iron_hands, "L", 3)
	var blocked_after_ready := bool(strategy.call("_deck_should_block_exact_queue_match", queued, runtime_retreat, gs, 0))

	return run_checks([
		assert_false(string_target_blocked, "String-only retreat refs should be ignored without runtime type errors"),
		assert_true(blocked_before_ready, "Miraidon LLM should not retreat a support pivot into an unready Iron Hands"),
		assert_false(blocked_after_ready, "Ready Iron Hands should still be a legal support handoff target"),
	])


func test_v17_miraidon_llm_ready_active_attack_replaces_end_turn() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "Miraidon LLM strategy should instantiate"
	var gs := _make_game_state()
	var player: PlayerState = gs.players[0]
	var raikou := _make_slot(_make_pokemon_cd(
		"Raikou V",
		"Basic",
		"L",
		200,
		[{"name": "Lightning Rondo", "cost": "LC", "damage": "20+"}]
	), 0)
	_attach_energy(raikou, "L", 2)
	player.active_pokemon = raikou
	var attack := {"kind": "attack", "attack_index": 0, "attack_name": "Lightning Rondo"}

	return run_checks([
		assert_true(bool(strategy.call("_deck_can_replace_end_turn_with_action", attack, gs, 0)), "Ready Raikou attack should replace a queued end_turn"),
		assert_true(bool(strategy.call("_deck_should_block_end_turn", gs, 0)), "Ready Raikou attack should block premature end_turn"),
	])


func test_v17_miraidon_llm_payload_exposes_ready_handoff_route() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "Miraidon LLM strategy should instantiate"
	var payload := {
		"legal_actions": [
			{"id": "retreat:bench_0:none", "type": "retreat", "summary": "retreat to bench_0 Raikou V"},
			{"id": "end_turn", "type": "end_turn", "summary": "end turn"},
		],
		"future_actions": [
			{
				"id": "future:attack_after_pivot:bench_0:0:Lightning Rondo",
				"action_id": "future:attack_after_pivot:bench_0:0:Lightning Rondo",
				"type": "attack",
				"future": true,
				"position": "bench_0",
				"source_pokemon": "Raikou V",
				"attack_name": "Lightning Rondo",
				"reachable_with_known_resources": true,
				"attack_quality": {"role": "chip_damage", "terminal_priority": "medium", "takes_prize": true},
			},
		],
		"candidate_routes": [
			{"route_action_id": "route:preserve_end", "goal": "fallback", "actions": [{"id": "end_turn"}]},
		],
		"turn_tactical_facts": {
			"primary_attack_ready": false,
			"ready_attack_is_low_value_redraw": false,
		},
	}
	var augmented: Dictionary = strategy.call("_deck_augment_action_id_payload", payload, null, -1)
	var routes: Array = augmented.get("candidate_routes", []) if augmented.get("candidate_routes", []) is Array else []
	var route := _route_by_id(routes, "route:miraidon_ready_handoff_attack")
	var actions: Array = route.get("actions", []) if route.get("actions", []) is Array else []
	var first_action: Dictionary = actions[0] if not actions.is_empty() and actions[0] is Dictionary else {}
	var last_action: Dictionary = actions[actions.size() - 1] if actions.size() > 0 and actions[actions.size() - 1] is Dictionary else {}
	var future_goals: Array = route.get("future_goals", []) if route.get("future_goals", []) is Array else []
	var first_goal: Dictionary = future_goals[0] if not future_goals.is_empty() and future_goals[0] is Dictionary else {}
	var quality: Dictionary = first_goal.get("attack_quality", {}) if first_goal.get("attack_quality", {}) is Dictionary else {}
	var facts: Dictionary = augmented.get("turn_tactical_facts", {}) if augmented.get("turn_tactical_facts", {}) is Dictionary else {}
	var handoff: Dictionary = facts.get("miraidon_ready_handoff", {}) if facts.get("miraidon_ready_handoff", {}) is Dictionary else {}

	return run_checks([
		assert_true(not route.is_empty(), "Payload should expose route:miraidon_ready_handoff_attack for reachable bench Raikou"),
		assert_eq(str(route.get("goal", "")), "pivot_to_attack", "Handoff route should use the shared attack-conversion goal for priority repair"),
		assert_eq(int(route.get("base_priority", 0)), 982, "Handoff route should be eligible for hard route preference"),
		assert_eq(str(first_action.get("id", "")), "retreat:bench_0:none", "Handoff route should start from the legal pivot action"),
		assert_eq(str(last_action.get("id", "")), "end_turn", "Handoff route should close with end_turn so runtime can convert after pivot"),
		assert_eq(str(quality.get("terminal_priority", "")), "high", "Ready handoff attack should be promoted to high priority for Miraidon mirror racing"),
		assert_true(bool(handoff.get("route_available", false)), "Tactical facts should explain that the Miraidon ready handoff is available"),
	])


func test_v17_miraidon_llm_handoff_route_attaches_to_the_pivot_attacker() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "Miraidon LLM strategy should instantiate"
	var payload := {
		"legal_actions": [
			{"id": "attach_energy:c12:bench_0", "type": "attach_energy", "card": "Lightning Energy", "position": "bench_0", "target": "Raikou V"},
			{"id": "attach_energy:c12:bench_1", "type": "attach_energy", "card": "Lightning Energy", "position": "bench_1", "target": "Iron Hands ex"},
			{"id": "retreat:bench_0:none", "type": "retreat", "summary": "retreat to bench_0 Raikou V"},
			{"id": "end_turn", "type": "end_turn", "summary": "end turn"},
		],
		"future_actions": [
			{
				"id": "future:attack_after_pivot:bench_0:0:Lightning Rondo",
				"action_id": "future:attack_after_pivot:bench_0:0:Lightning Rondo",
				"type": "attack",
				"future": true,
				"position": "bench_0",
				"source_pokemon": "Raikou V",
				"attack_name": "Lightning Rondo",
				"reachable_with_known_resources": true,
				"best_manual_attach_energy": "Lightning",
				"missing_cost_now": ["Colorless"],
				"missing_cost_after_prerequisite": [],
				"attack_quality": {"role": "chip_damage", "terminal_priority": "medium", "takes_prize": true},
			},
		],
		"candidate_routes": [
			{"route_action_id": "route:preserve_end", "goal": "fallback", "actions": [{"id": "end_turn"}]},
		],
		"turn_tactical_facts": {
			"primary_attack_ready": false,
			"ready_attack_is_low_value_redraw": false,
		},
		"intent_facts": {"hard_blocks": []},
	}
	var augmented: Dictionary = strategy.call("_deck_augment_action_id_payload", payload, null, -1)
	var routes: Array = augmented.get("candidate_routes", []) if augmented.get("candidate_routes", []) is Array else []
	var route := _route_by_id(routes, "route:miraidon_ready_handoff_attack")
	var ids := _route_action_ids(routes, "route:miraidon_ready_handoff_attack")
	var facts: Dictionary = augmented.get("turn_tactical_facts", {}) if augmented.get("turn_tactical_facts", {}) is Dictionary else {}
	var handoff: Dictionary = facts.get("miraidon_ready_handoff", {}) if facts.get("miraidon_ready_handoff", {}) is Dictionary else {}
	var negatives: Array = facts.get("resource_negative_actions", []) if facts.get("resource_negative_actions", []) is Array else []
	var intent_facts: Dictionary = augmented.get("intent_facts", {}) if augmented.get("intent_facts", {}) is Dictionary else {}
	var hard_blocks: Array = intent_facts.get("hard_blocks", []) if intent_facts.get("hard_blocks", []) is Array else []

	return run_checks([
		assert_eq(str(route.get("manual_attach_action_id", "")), "attach_energy:c12:bench_0", "Handoff route should spend the manual attach on the future attacker"),
		assert_eq(str(handoff.get("manual_attach_action_id", "")), "attach_energy:c12:bench_0", "Tactical facts should expose the exact handoff attach"),
		assert_eq(str(handoff.get("pivot_action_id", "")), "retreat:bench_0:none", "Pivot fact should still point to the retreat action, not the attach"),
		assert_eq(ids, ["attach_energy:c12:bench_0", "retreat:bench_0:none", "end_turn"], "Handoff route should attach to Raikou before pivoting"),
		assert_true(_action_list_has_id(negatives, "attach_energy:c12:bench_1"), "The same Energy attached elsewhere should be marked resource-negative"),
		assert_true(_action_list_has_id(hard_blocks, "attach_energy:c12:bench_1"), "The same Energy attached elsewhere should be hard-blocked"),
	])


func _action_list_has_id(actions: Array, action_id: String) -> bool:
	for raw: Variant in actions:
		if raw is Dictionary:
			var item: Dictionary = raw
			if str(item.get("id", item.get("action_id", ""))) == action_id:
				return true
	return false
