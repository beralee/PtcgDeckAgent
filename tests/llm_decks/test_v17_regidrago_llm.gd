class_name TestV17RegidragoLLM
extends TestBase

const REGIDRAGO_LLM_SCRIPT_PATH := "res://scripts/ai/DeckStrategy17RegidragoLLM.gd"


func _new_llm_strategy() -> RefCounted:
	CardInstance.reset_id_counter()
	var script: Variant = load(REGIDRAGO_LLM_SCRIPT_PATH)
	return script.new() if script is GDScript else null


func _make_pokemon_cd(
	pname: String,
	stage: String = "Basic",
	energy_type: String = "C",
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


func _make_slot(card_data: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner))
	return slot


func _make_card(card_data: CardData, owner: int = 0) -> CardInstance:
	return CardInstance.create(card_data, owner)


func _attach_energy(slot: PokemonSlot, provides: String, count: int, owner: int = 0) -> void:
	for i: int in count:
		var energy := CardData.new()
		energy.name = "%s Energy %d" % [provides, i]
		energy.name_en = energy.name
		energy.card_type = "Basic Energy"
		energy.energy_type = provides
		energy.energy_provides = provides
		slot.attached_energy.append(CardInstance.create(energy, owner))


func _make_game_state(turn: int, phase: GameState.GamePhase) -> GameState:
	var gs := GameState.new()
	gs.turn_number = turn
	gs.current_player_index = 0
	gs.first_player_index = 0
	gs.phase = phase
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		player.active_pokemon = _make_slot(_make_pokemon_cd(
			"Active%d" % player_index,
			"Basic",
			"C",
			100,
			[{"name": "Test Attack", "cost": "C", "damage": "10"}]
		), player_index)
		gs.players.append(player)
	return gs


func _attack_action(slot: PokemonSlot) -> Dictionary:
	return {
		"kind": "attack",
		"source_slot": slot,
		"attack_index": 0,
		"attack_name": "Test Attack",
	}


func _profile_has_attack(profile: Dictionary, key: String, pokemon_name: String, attack_name: String) -> bool:
	var entries: Array = profile.get(key, []) if profile.get(key, []) is Array else []
	for raw: Variant in entries:
		if not (raw is Dictionary):
			continue
		var entry: Dictionary = raw
		if str(entry.get("pokemon", "")) == pokemon_name and str(entry.get("attack", "")) == attack_name:
			return true
	return false


func _celestial_roar_action(slot: PokemonSlot) -> Dictionary:
	return {
		"kind": "attack",
		"source_slot": slot,
		"attack_index": 0,
		"attack_name": "Celestial Roar",
		"projected_damage": 0,
		"projected_knockout": false,
	}


func _regidrago_v_with_roar() -> CardData:
	return _make_pokemon_cd("Regidrago V", "Basic", "N", 220, [
		{"name": "Celestial Roar", "cost": "C", "damage": "", "text": "Discard the top 3 cards of your deck."},
		{"name": "Dragon Laser", "cost": "GGR", "damage": "130"},
	])


func _regidrago_vstar() -> CardData:
	return _make_pokemon_cd("Regidrago VSTAR", "VSTAR", "N", 280, [
		{"name": "Apex Dragon", "cost": "GGR", "damage": ""},
	])


func test_v17_regidrago_llm_non_main_prepare_does_not_burn_turn_attempt() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "Regidrago LLM strategy should instantiate"
	var gs := _make_game_state(2, GameState.GamePhase.DRAW)
	strategy.call("ensure_llm_request_fired", gs, 0, [])
	var attempt_after_draw := int(strategy.get("_llm_request_attempt_turn"))
	var stats_after_draw: Dictionary = strategy.call("get_llm_stats")
	gs.phase = GameState.GamePhase.MAIN
	strategy.call("ensure_llm_request_fired", gs, 0, [_attack_action(gs.players[0].active_pokemon)])
	var attempt_after_main := int(strategy.get("_llm_request_attempt_turn"))

	return run_checks([
		assert_true(attempt_after_draw != 2, "Non-MAIN LLM preparation should not consume the turn attempt slot"),
		assert_eq(int(stats_after_draw.get("skipped_by_local_rules", -1)), 0, "Non-MAIN preparation should not count as a local-rules skip"),
		assert_eq(attempt_after_main, 2, "MAIN-phase preparation should still reach the runtime request path"),
	])


func test_v17_regidrago_llm_marks_celestial_roar_as_setup_not_low_value() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "Regidrago LLM strategy should instantiate"
	var profile: Dictionary = strategy.call("get_intent_planner_profile")

	return run_checks([
		assert_true(_profile_has_attack(profile, "setup_draw_attacks", "Regidrago V", "Celestial Roar"), "Celestial Roar should be exposed as Regidrago's setup attack"),
		assert_false(_profile_has_attack(profile, "low_value_attacks", "Regidrago V", "Celestial Roar"), "Celestial Roar should not be exposed as a desperation redraw attack"),
	])


func test_v17_regidrago_llm_allows_celestial_roar_as_launch_attack_before_apex_online() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "Regidrago LLM strategy should instantiate"
	var gs := _make_game_state(2, GameState.GamePhase.MAIN)
	var player: PlayerState = gs.players[0]
	var active := _make_slot(_regidrago_v_with_roar(), 0)
	_attach_energy(active, "G", 1)
	player.active_pokemon = active
	for i: int in 30:
		player.deck.append(_make_card(_make_pokemon_cd("Filler %d" % i), 0))
	var action := _celestial_roar_action(active)

	return run_checks([
		assert_true(bool(strategy.call("_deck_can_replace_end_turn_with_action", action, gs, 0)), "Celestial Roar should be able to replace a passive end turn during Regidrago launch"),
		assert_false(bool(strategy.call("_is_low_value_runtime_attack_action", action, gs, 0)), "Celestial Roar should not hit the low-value runtime attack guard before Apex Dragon is online"),
	])


func test_v17_regidrago_llm_blocks_celestial_roar_when_apex_line_is_online() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "Regidrago LLM strategy should instantiate"
	var gs := _make_game_state(6, GameState.GamePhase.MAIN)
	var player: PlayerState = gs.players[0]
	var active := _make_slot(_regidrago_v_with_roar(), 0)
	_attach_energy(active, "G", 1)
	player.active_pokemon = active
	var vstar := _make_slot(_regidrago_vstar(), 0)
	_attach_energy(vstar, "G", 2)
	_attach_energy(vstar, "R", 1)
	player.bench.append(vstar)
	player.discard_pile.append(_make_card(_make_pokemon_cd("Dragapult ex", "Stage 2", "N", 320), 0))
	for i: int in 30:
		player.deck.append(_make_card(_make_pokemon_cd("Filler %d" % i), 0))
	var action := _celestial_roar_action(active)

	return run_checks([
		assert_true(bool(strategy.call("_regidrago_llm_has_dragon_fuel_in_discard", player)), "Test setup should expose discard dragon fuel"),
		assert_true(bool(strategy.call("_regidrago_llm_has_ready_apex_line", player)), "Test setup should expose a ready Apex Dragon line"),
		assert_false(bool(strategy.call("_deck_can_replace_end_turn_with_action", action, gs, 0)), "Celestial Roar should not replace end turn once a ready Apex Dragon line exists"),
		assert_true(bool(strategy.call("_is_low_value_runtime_attack_action", action, gs, 0)), "Celestial Roar should stay guarded after Apex Dragon is online"),
	])


func test_v17_regidrago_llm_blocks_basic_dragon_laser_when_vstar_apex_is_available() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "Regidrago LLM strategy should instantiate"
	var gs := _make_game_state(4, GameState.GamePhase.MAIN)
	var player: PlayerState = gs.players[0]
	var active := _make_slot(_regidrago_v_with_roar(), 0)
	_attach_energy(active, "G", 2)
	_attach_energy(active, "R", 1)
	player.active_pokemon = active
	player.hand.append(_make_card(_regidrago_vstar(), 0))
	player.discard_pile.append(_make_card(_make_pokemon_cd("Dragapult ex", "Stage 2", "N", 320), 0))
	var action := {
		"kind": "attack",
		"source_slot": active,
		"attack_index": 1,
		"attack_name": "Dragon Laser",
		"projected_damage": 130,
		"projected_knockout": false,
	}

	return run_checks([
		assert_true(bool(strategy.call("_regidrago_llm_should_block_basic_dragon_laser_for_apex", action, gs, 0)), "Ready Basic Dragon Laser should be blocked when VSTAR Apex is available"),
		assert_true(bool(strategy.call("_is_low_value_runtime_attack_action", action, gs, 0)), "Ready Basic Dragon Laser should be treated as low value in the Apex upgrade window"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", action, action, gs, 0)), "LLM exact queue should not be allowed to take Basic Dragon Laser over Apex upgrade"),
	])


func test_v17_regidrago_llm_payload_exposes_ready_bench_handoff_attack_route() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "Regidrago LLM strategy should instantiate"
	var payload := {
		"legal_actions": [
			{
				"id": "play_trainer:c30",
				"type": "play_trainer",
				"card": "Switch",
				"summary": "play Switch",
				"interaction_schema": {
					"own_bench_target": {"type": "string"},
					"switch_target": {"type": "string"},
				},
			},
			{"id": "end_turn", "type": "end_turn", "summary": "end turn"},
		],
		"future_actions": [
			{
				"id": "future:attack_after_pivot:bench_0:0:Teal Dance",
				"action_id": "future:attack_after_pivot:bench_0:0:Teal Dance",
				"type": "attack",
				"future": true,
				"position": "bench_0",
				"source_pokemon": "Teal Mask Ogerpon ex",
				"attack_name": "Teal Dance",
				"reachable_with_known_resources": true,
				"attack_quality": {
					"role": "chip_damage",
					"terminal_priority": "medium",
					"takes_prize": true,
				},
			},
		],
		"candidate_routes": [
			{
				"id": "preserve_end",
				"route_action_id": "route:preserve_end",
				"goal": "fallback",
				"actions": [{"id": "end_turn"}],
				"base_priority": 100,
			},
		],
		"turn_tactical_facts": {
			"primary_attack_ready": false,
			"ready_attack_is_low_value_redraw": true,
			"only_ready_attack_is_low_value_redraw": true,
		},
	}
	var augmented: Dictionary = strategy.call("_deck_augment_action_id_payload", payload, null, -1)
	var routes: Array = augmented.get("candidate_routes", []) if augmented.get("candidate_routes", []) is Array else []
	var route: Dictionary = {}
	for raw_route: Variant in routes:
		if raw_route is Dictionary and str((raw_route as Dictionary).get("route_action_id", "")) == "route:regidrago_ready_handoff_attack":
			route = raw_route
			break
	var actions: Array = route.get("actions", []) if route.get("actions", []) is Array else []
	var first_action: Dictionary = actions[0] if not actions.is_empty() and actions[0] is Dictionary else {}
	var last_action: Dictionary = actions[actions.size() - 1] if actions.size() > 0 and actions[actions.size() - 1] is Dictionary else {}
	var facts: Dictionary = augmented.get("turn_tactical_facts", {}) if augmented.get("turn_tactical_facts", {}) is Dictionary else {}
	var handoff: Dictionary = facts.get("regidrago_ready_handoff", {}) if facts.get("regidrago_ready_handoff", {}) is Dictionary else {}

	return run_checks([
		assert_true(not route.is_empty(), "Payload should expose route:regidrago_ready_handoff_attack for a reachable bench attack"),
		assert_eq(str(first_action.get("id", "")), "play_trainer:c30", "Handoff route should start from the legal pivot action"),
		assert_eq(str(last_action.get("id", "")), "end_turn", "Handoff route should close with end_turn so runtime can convert after pivot"),
		assert_true(bool(handoff.get("route_available", false)), "Tactical facts should explain that the ready bench handoff is available"),
	])


func test_v17_regidrago_llm_payload_prefers_evolve_apex_before_basic_attack_route() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "Regidrago LLM strategy should instantiate"
	var gs := _make_game_state(4, GameState.GamePhase.MAIN)
	var player: PlayerState = gs.players[0]
	var active := _make_slot(_regidrago_v_with_roar(), 0)
	_attach_energy(active, "G", 1)
	_attach_energy(active, "R", 1)
	player.active_pokemon = active
	player.discard_pile.append(_make_card(_make_pokemon_cd("Dragapult ex", "Stage 2", "N", 320), 0))
	var payload := {
		"legal_actions": [
			{
				"id": "evolve:c26:active",
				"type": "evolve",
				"card": "Regidrago VSTAR",
				"position": "active",
				"summary": "evolve active Regidrago V into Regidrago VSTAR",
			},
			{
				"id": "attach_energy:c20:active",
				"type": "attach_energy",
				"card": "Grass Energy",
				"energy_type": "Grass",
				"position": "active",
				"target": "Regidrago V",
				"summary": "attach Grass to active Regidrago V",
			},
			{
				"id": "attack:0:Celestial Roar",
				"type": "attack",
				"attack_name": "Celestial Roar",
				"attack_quality": {"role": "desperation_redraw", "terminal_priority": "low"},
			},
			{"id": "end_turn", "type": "end_turn", "summary": "end turn"},
		],
		"future_actions": [
			{
				"id": "future:attack_after_attach:active:1:Dragon Laser",
				"type": "attack",
				"future": true,
				"position": "active",
				"attack_name": "Dragon Laser",
				"reachable_with_known_resources": true,
				"attack_quality": {"role": "primary_damage", "terminal_priority": "high"},
			},
		],
		"candidate_routes": [
			{
				"id": "manual_attach_to_attack",
				"route_action_id": "route:manual_attach_to_attack",
				"goal": "manual_attach_to_primary_attack",
				"base_priority": 980,
				"actions": [
					{"id": "attach_energy:c20:active"},
					{"id": "future:attack_after_attach:active:1:Dragon Laser"},
				],
			},
			{
				"id": "preserve_end",
				"route_action_id": "route:preserve_end",
				"goal": "fallback",
				"actions": [{"id": "end_turn"}],
				"base_priority": 100,
			},
		],
		"turn_tactical_facts": {
			"primary_attack_ready": false,
			"primary_attack_reachable_after_visible_engine": true,
			"ready_attack_is_low_value_redraw": true,
			"only_ready_attack_is_low_value_redraw": true,
		},
	}
	var augmented: Dictionary = strategy.call("_deck_augment_action_id_payload", payload, gs, 0)
	var routes: Array = augmented.get("candidate_routes", []) if augmented.get("candidate_routes", []) is Array else []
	var evolve_route: Dictionary = {}
	var evolve_index := -1
	var manual_index := -1
	for i: int in routes.size():
		var raw_route: Variant = routes[i]
		if not (raw_route is Dictionary):
			continue
		var route: Dictionary = raw_route
		var route_id := str(route.get("route_action_id", ""))
		if route_id == "route:regidrago_evolve_apex_attack":
			evolve_route = route
			evolve_index = i
		elif route_id == "route:manual_attach_to_attack":
			manual_index = i
	var actions: Array = evolve_route.get("actions", []) if evolve_route.get("actions", []) is Array else []
	var first_action: Dictionary = actions[0] if actions.size() > 0 and actions[0] is Dictionary else {}
	var second_action: Dictionary = actions[1] if actions.size() > 1 and actions[1] is Dictionary else {}
	var last_action: Dictionary = actions[actions.size() - 1] if actions.size() > 0 and actions[actions.size() - 1] is Dictionary else {}
	var facts: Dictionary = augmented.get("turn_tactical_facts", {}) if augmented.get("turn_tactical_facts", {}) is Dictionary else {}
	var evolve_fact: Dictionary = facts.get("regidrago_evolve_apex", {}) if facts.get("regidrago_evolve_apex", {}) is Dictionary else {}

	return run_checks([
		assert_true(not evolve_route.is_empty(), "Payload should expose a Regidrago evolve-to-Apex route when VSTAR plus GGR is available"),
		assert_true(evolve_index >= 0 and (manual_index < 0 or evolve_index < manual_index), "Evolve-to-Apex route should be ordered before the generic manual-attach Basic attack route"),
		assert_eq(str(first_action.get("id", "")), "evolve:c26:active", "Evolve-to-Apex route should evolve the active Regidrago first"),
		assert_eq(str(second_action.get("id", "")), "attach_energy:c20:active", "Evolve-to-Apex route should complete GGR on the active attacker"),
		assert_eq(str(last_action.get("id", "")), "end_turn", "Evolve-to-Apex route should close with end_turn so runtime can convert into Apex Dragon"),
		assert_true(bool(evolve_fact.get("route_available", false)), "Tactical facts should explain that Regidrago can evolve into an Apex attack this turn"),
	])


func test_v17_regidrago_llm_payload_exposes_energy_switch_apex_route_without_low_level_interactions() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "Regidrago LLM strategy should instantiate"
	var gs := _make_game_state(4, GameState.GamePhase.MAIN)
	var player: PlayerState = gs.players[0]
	var active := _make_slot(_regidrago_v_with_roar(), 0)
	_attach_energy(active, "G", 1)
	_attach_energy(active, "R", 1)
	player.active_pokemon = active
	var ogerpon := _make_slot(_make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210), 0)
	_attach_energy(ogerpon, "G", 1)
	player.bench.append(ogerpon)
	player.discard_pile.append(_make_card(_make_pokemon_cd("Dragapult ex", "Stage 2", "N", 320), 0))
	var payload := {
		"legal_actions": [
			{
				"id": "evolve:c26:active",
				"type": "evolve",
				"card": "Regidrago VSTAR",
				"position": "active",
				"summary": "evolve active Regidrago V into Regidrago VSTAR",
			},
			{
				"id": "play_trainer:c7",
				"type": "play_trainer",
				"card": "Energy Switch",
				"summary": "play Energy Switch",
			},
			{"id": "end_turn", "type": "end_turn", "summary": "end turn"},
		],
		"candidate_routes": [
			{
				"id": "manual_attach_to_attack",
				"route_action_id": "route:manual_attach_to_attack",
				"goal": "manual_attach_to_primary_attack",
				"base_priority": 980,
				"actions": [{"id": "end_turn"}],
			},
			{
				"id": "preserve_end",
				"route_action_id": "route:preserve_end",
				"goal": "fallback",
				"actions": [{"id": "end_turn"}],
				"base_priority": 100,
			},
		],
		"turn_tactical_facts": {
			"primary_attack_ready": false,
			"ready_attack_is_low_value_redraw": true,
			"only_ready_attack_is_low_value_redraw": true,
		},
	}
	var augmented: Dictionary = strategy.call("_deck_augment_action_id_payload", payload, gs, 0)
	var routes: Array = augmented.get("candidate_routes", []) if augmented.get("candidate_routes", []) is Array else []
	var switch_route: Dictionary = {}
	var switch_index := -1
	var manual_index := -1
	for i: int in routes.size():
		var raw_route: Variant = routes[i]
		if not (raw_route is Dictionary):
			continue
		var route: Dictionary = raw_route
		var route_id := str(route.get("route_action_id", ""))
		if route_id == "route:regidrago_energy_switch_apex_attack":
			switch_route = route
			switch_index = i
		elif route_id == "route:manual_attach_to_attack":
			manual_index = i
	var actions: Array = switch_route.get("actions", []) if switch_route.get("actions", []) is Array else []
	var evolve_action: Dictionary = actions[0] if actions.size() > 0 and actions[0] is Dictionary else {}
	var switch_action: Dictionary = actions[1] if actions.size() > 1 and actions[1] is Dictionary else {}
	var last_action: Dictionary = actions[actions.size() - 1] if actions.size() > 0 and actions[actions.size() - 1] is Dictionary else {}
	var facts: Dictionary = augmented.get("turn_tactical_facts", {}) if augmented.get("turn_tactical_facts", {}) is Dictionary else {}
	var switch_fact: Dictionary = facts.get("regidrago_energy_switch_apex", {}) if facts.get("regidrago_energy_switch_apex", {}) is Dictionary else {}

	return run_checks([
		assert_true(not switch_route.is_empty(), "Payload should expose an Energy Switch route when Ogerpon Grass completes active Regidrago VSTAR"),
		assert_true(switch_index >= 0 and (manual_index < 0 or switch_index < manual_index), "Energy Switch Apex route should be ordered before generic fallback routes"),
		assert_eq(str(evolve_action.get("id", "")), "evolve:c26:active", "Energy Switch Apex route should evolve first"),
		assert_eq(str(switch_action.get("id", "")), "play_trainer:c7", "Energy Switch Apex route should then play the legal Energy Switch action"),
		assert_false(switch_action.has("interactions"), "Energy Switch route should omit low-level interactions and let fallback scoring choose source/target"),
		assert_eq(str(last_action.get("id", "")), "end_turn", "Energy Switch Apex route should close with end_turn so runtime can convert into Apex Dragon"),
		assert_true(bool(switch_fact.get("route_available", false)), "Tactical facts should explain that Energy Switch enables Apex Dragon this turn"),
	])


func test_v17_regidrago_llm_payload_exposes_backup_regidrago_seed_before_attack() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "Regidrago LLM strategy should instantiate"
	var gs := _make_game_state(5, GameState.GamePhase.MAIN)
	var player: PlayerState = gs.players[0]
	player.prizes.clear()
	for i: int in 6:
		player.prizes.append(_make_card(_make_pokemon_cd("Prize %d" % i), 0))
	var active := _make_slot(_regidrago_vstar(), 0)
	_attach_energy(active, "G", 2)
	_attach_energy(active, "R", 1)
	player.active_pokemon = active
	var payload := {
		"legal_actions": [
			{
				"id": "play_basic_to_bench:c42",
				"type": "play_basic_to_bench",
				"card": "Regidrago V",
				"summary": "bench Regidrago V from hand",
			},
			{
				"id": "attack:active:0:Apex Dragon",
				"type": "attack",
				"attack_name": "Apex Dragon",
				"summary": "attack with Regidrago VSTAR Apex Dragon",
			},
			{"id": "end_turn", "type": "end_turn", "summary": "end turn"},
		],
		"candidate_routes": [
			{
				"id": "preserve_end",
				"route_action_id": "route:preserve_end",
				"goal": "fallback",
				"actions": [{"id": "end_turn"}],
				"base_priority": 100,
			},
		],
		"turn_tactical_facts": {
			"primary_attack_ready": true,
		},
	}
	var augmented: Dictionary = strategy.call("_deck_augment_action_id_payload", payload, gs, 0)
	var routes: Array = augmented.get("candidate_routes", []) if augmented.get("candidate_routes", []) is Array else []
	var seed_route: Dictionary = {}
	for raw_route: Variant in routes:
		if raw_route is Dictionary and str((raw_route as Dictionary).get("route_action_id", "")) == "route:regidrago_backup_seed_before_attack":
			seed_route = raw_route
			break
	var actions: Array = seed_route.get("actions", []) if seed_route.get("actions", []) is Array else []
	var seed_action: Dictionary = actions[0] if actions.size() > 0 and actions[0] is Dictionary else {}
	var attack_action: Dictionary = actions[1] if actions.size() > 1 and actions[1] is Dictionary else {}
	var facts: Dictionary = augmented.get("turn_tactical_facts", {}) if augmented.get("turn_tactical_facts", {}) is Dictionary else {}
	var seed_fact: Dictionary = facts.get("regidrago_backup_seed", {}) if facts.get("regidrago_backup_seed", {}) is Dictionary else {}

	return run_checks([
		assert_true(not seed_route.is_empty(), "Payload should expose a backup Regidrago seed route before the active VSTAR attacks"),
		assert_eq(str(seed_action.get("id", "")), "play_basic_to_bench:c42", "Backup seed route should first bench the legal Regidrago V"),
		assert_eq(str(attack_action.get("id", "")), "attack:active:0:Apex Dragon", "Backup seed route should then preserve the immediate Apex attack"),
		assert_true(bool(seed_fact.get("route_available", false)), "Tactical facts should explain that a backup Regidrago line is needed"),
	])
