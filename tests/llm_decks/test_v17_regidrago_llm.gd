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


func _make_energy_card(pname: String, provides: String) -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.name_en = pname
	cd.card_type = "Basic Energy"
	cd.energy_type = provides
	cd.energy_provides = provides
	return cd


func _make_trainer_cd(pname: String, card_type: String = "Item") -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.name_en = pname
	cd.card_type = card_type
	return cd


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


func test_v17_regidrago_llm_payload_exposes_ogerpon_buffer_handoff_route() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "Regidrago LLM strategy should instantiate"
	var gs := _make_game_state(4, GameState.GamePhase.MAIN)
	var player: PlayerState = gs.players[0]
	var ogerpon := _make_slot(_make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210), 0)
	ogerpon.get_card_data().retreat_cost = 1
	_attach_energy(ogerpon, "G", 2)
	player.active_pokemon = ogerpon
	var regidrago := _make_slot(_regidrago_v_with_roar(), 0)
	_attach_energy(regidrago, "R", 1)
	player.bench.append(regidrago)
	player.discard_pile.append(_make_card(_make_pokemon_cd("Dragapult ex", "Stage 2", "N", 320), 0))
	var payload := {
		"legal_actions": [
			{
				"id": "evolve:c26:bench_0",
				"type": "evolve",
				"card": "Regidrago VSTAR",
				"position": "bench_0",
				"summary": "evolve bench_0 Regidrago V into Regidrago VSTAR",
			},
			{
				"id": "attach_energy:c20:bench_0",
				"type": "attach_energy",
				"card": "Grass Energy",
				"energy_symbol": "G",
				"position": "bench_0",
				"summary": "attach Grass Energy to bench_0 Regidrago V",
			},
			{
				"id": "play_trainer:c7",
				"type": "play_trainer",
				"card": "Energy Switch",
				"summary": "play Energy Switch",
			},
			{
				"id": "retreat:bench_0",
				"type": "retreat",
				"position": "bench_0",
				"summary": "retreat active Teal Mask Ogerpon ex into bench_0 Regidrago VSTAR",
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
		"turn_tactical_facts": {"primary_attack_ready": false},
	}
	var augmented: Dictionary = strategy.call("_deck_augment_action_id_payload", payload, gs, 0)
	var routes: Array = augmented.get("candidate_routes", []) if augmented.get("candidate_routes", []) is Array else []
	var buffer_route: Dictionary = {}
	var route_index := -1
	for i: int in routes.size():
		var raw_route: Variant = routes[i]
		if raw_route is Dictionary and str((raw_route as Dictionary).get("route_action_id", "")) == "route:regidrago_ogerpon_buffer_apex_attack":
			buffer_route = raw_route
			route_index = i
			break
	var actions: Array = buffer_route.get("actions", []) if buffer_route.get("actions", []) is Array else []
	var evolve_action: Dictionary = actions[0] if actions.size() > 0 and actions[0] is Dictionary else {}
	var attach_action: Dictionary = actions[1] if actions.size() > 1 and actions[1] is Dictionary else {}
	var switch_action: Dictionary = actions[2] if actions.size() > 2 and actions[2] is Dictionary else {}
	var pivot_action: Dictionary = actions[3] if actions.size() > 3 and actions[3] is Dictionary else {}
	var last_action: Dictionary = actions[actions.size() - 1] if actions.size() > 0 and actions[actions.size() - 1] is Dictionary else {}
	var facts: Dictionary = augmented.get("turn_tactical_facts", {}) if augmented.get("turn_tactical_facts", {}) is Dictionary else {}
	var buffer_fact: Dictionary = facts.get("regidrago_ogerpon_buffer_apex", {}) if facts.get("regidrago_ogerpon_buffer_apex", {}) is Dictionary else {}

	return run_checks([
		assert_true(route_index == 0, "Ogerpon-buffer Apex route should be the highest-priority route when it can protect the first Regidrago"),
		assert_eq(str(evolve_action.get("id", "")), "evolve:c26:bench_0", "Buffered route should evolve the protected bench Regidrago first"),
		assert_eq(str(attach_action.get("id", "")), "attach_energy:c20:bench_0", "Buffered route should manually attach Grass to the bench Regidrago"),
		assert_eq(str(switch_action.get("id", "")), "play_trainer:c7", "Buffered route should then use Energy Switch for the second Grass"),
		assert_eq(str(pivot_action.get("id", "")), "retreat:bench_0", "Buffered route should pivot Ogerpon into the ready Regidrago"),
		assert_eq(str(last_action.get("id", "")), "end_turn", "Buffered route should close with end_turn so runtime can convert into Apex Dragon"),
		assert_true(bool(buffer_fact.get("route_available", false)), "Tactical facts should expose the Ogerpon buffer handoff route"),
	])


func test_v17_regidrago_llm_payload_hides_basic_handoff_while_ogerpon_buffer_is_not_ready() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "Regidrago LLM strategy should instantiate"
	var gs := _make_game_state(2, GameState.GamePhase.MAIN)
	var player: PlayerState = gs.players[0]
	var ogerpon := _make_slot(_make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210), 0)
	ogerpon.get_card_data().retreat_cost = 1
	_attach_energy(ogerpon, "G", 1)
	player.active_pokemon = ogerpon
	var regidrago := _make_slot(_regidrago_v_with_roar(), 0)
	_attach_energy(regidrago, "R", 1)
	player.bench.append(regidrago)
	var payload := {
		"legal_actions": [
			{
				"id": "attach_energy:c5:bench_0",
				"type": "attach_energy",
				"card": "Fire Energy",
				"energy_symbol": "R",
				"position": "bench_0",
				"summary": "attach Fire Energy to bench_0 Regidrago V",
			},
			{
				"id": "play_trainer:c7",
				"type": "play_trainer",
				"card": "Energy Switch",
				"summary": "play Energy Switch",
			},
			{
				"id": "retreat:bench_0:c19",
				"type": "retreat",
				"position": "bench_0",
				"summary": "retreat active Ogerpon into bench_0 Regidrago V",
			},
			{"id": "end_turn", "type": "end_turn", "summary": "end turn"},
		],
		"future_actions": [
			{"id": "future:retreat_to:bench_0", "type": "retreat", "position": "bench_0"},
			{
				"id": "future:attack_after_pivot:bench_0:0:Celestial Roar",
				"type": "attack",
				"position": "bench_0",
				"source_pokemon": "Regidrago V",
				"attack_name": "Celestial Roar",
				"reachable_with_known_resources": true,
			},
		],
		"candidate_routes": [
			{
				"id": "bad_basic_handoff",
				"route_action_id": "route:bad_basic_handoff",
				"actions": [
					{"id": "play_trainer:c7", "type": "play_trainer", "card": "Energy Switch"},
					{"id": "retreat:bench_0:c19", "type": "retreat", "position": "bench_0"},
				],
				"future_goals": [
					{
						"id": "future:attack_after_pivot:bench_0:0:Celestial Roar",
						"type": "attack",
						"position": "bench_0",
						"source_pokemon": "Regidrago V",
						"attack_name": "Celestial Roar",
					},
				],
			},
			{
				"id": "preserve_end",
				"route_action_id": "route:preserve_end",
				"actions": [{"id": "end_turn"}],
				"base_priority": 100,
			},
		],
		"turn_tactical_facts": {"primary_attack_ready": false},
	}
	var augmented: Dictionary = strategy.call("_deck_augment_action_id_payload", payload, gs, 0)
	var legal_ids: Array = []
	for raw_action: Variant in augmented.get("legal_actions", []):
		if raw_action is Dictionary:
			legal_ids.append(str((raw_action as Dictionary).get("id", "")))
	var future_ids: Array = []
	for raw_future: Variant in augmented.get("future_actions", []):
		if raw_future is Dictionary:
			future_ids.append(str((raw_future as Dictionary).get("id", "")))
	var route_ids: Array = []
	for raw_route: Variant in augmented.get("candidate_routes", []):
		if raw_route is Dictionary:
			route_ids.append(str((raw_route as Dictionary).get("route_action_id", "")))
	var facts: Dictionary = augmented.get("turn_tactical_facts", {}) if augmented.get("turn_tactical_facts", {}) is Dictionary else {}
	var lock_fact: Dictionary = facts.get("regidrago_active_ogerpon_buffer_lock", {}) if facts.get("regidrago_active_ogerpon_buffer_lock", {}) is Dictionary else {}

	return run_checks([
		assert_true(legal_ids.has("attach_energy:c5:bench_0"), "Manual attach to the protected bench Regidrago should remain visible"),
		assert_true(legal_ids.has("end_turn"), "End turn should remain visible while Ogerpon keeps buffering the active slot"),
		assert_false(legal_ids.has("play_trainer:c7"), "Energy Switch should be hidden while active Ogerpon has only its retreat Energy"),
		assert_false(legal_ids.has("retreat:bench_0:c19"), "Retreat into basic Regidrago should be hidden before VSTAR Apex is ready"),
		assert_false(future_ids.has("future:retreat_to:bench_0"), "Future retreat into basic Regidrago should be hidden"),
		assert_false(future_ids.has("future:attack_after_pivot:bench_0:0:Celestial Roar"), "Future basic-Regidrago setup attack should be hidden"),
		assert_false(route_ids.has("route:bad_basic_handoff"), "Candidate route that spends the buffer into a basic Regidrago should be removed"),
		assert_true(route_ids.has("route:preserve_end"), "Neutral preserve route should remain"),
		assert_true(bool(lock_fact.get("active", false)), "Tactical facts should explain that the active Ogerpon buffer lock is active"),
	])


func test_v17_regidrago_llm_runtime_blocks_basic_handoff_from_active_ogerpon_buffer() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "Regidrago LLM strategy should instantiate"
	var gs := _make_game_state(2, GameState.GamePhase.MAIN)
	var player: PlayerState = gs.players[0]
	var ogerpon := _make_slot(_make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210), 0)
	ogerpon.get_card_data().retreat_cost = 1
	_attach_energy(ogerpon, "G", 1)
	player.active_pokemon = ogerpon
	var regidrago := _make_slot(_regidrago_v_with_roar(), 0)
	_attach_energy(regidrago, "R", 1)
	player.bench.append(regidrago)
	var retreat_action := {
		"kind": "retreat",
		"type": "retreat",
		"bench_target": regidrago,
		"energy_to_discard": ogerpon.attached_energy.duplicate(),
		"summary": "retreat active Ogerpon into basic Regidrago V",
	}
	var energy_switch_action := {
		"kind": "play_trainer",
		"type": "play_trainer",
		"card": "Energy Switch",
		"summary": "play Energy Switch from active Ogerpon to bench Regidrago V",
	}

	return run_checks([
		assert_true(float(strategy.score_action_absolute(retreat_action, gs, 0)) < -9000.0, "Runtime scoring should hard-block retreat into basic Regidrago while Ogerpon is the active buffer"),
		assert_true(float(strategy.score_action_absolute(energy_switch_action, gs, 0)) < -9000.0, "Runtime scoring should hard-block spending Ogerpon's only retreat Energy through Energy Switch"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", retreat_action, retreat_action, gs, 0)), "Exact queue matching should also block the basic-Regidrago handoff"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", energy_switch_action, energy_switch_action, gs, 0)), "Exact queue matching should also block the unsafe Energy Switch"),
	])


func test_v17_regidrago_llm_payload_exposes_vstar_reload_route_with_energy_switch() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "Regidrago LLM strategy should instantiate"
	var gs := _make_game_state(10, GameState.GamePhase.MAIN)
	var player: PlayerState = gs.players[0]
	var active := _make_slot(_regidrago_vstar(), 0)
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
				"id": "play_trainer:c7",
				"type": "play_trainer",
				"card": "Energy Switch",
				"summary": "play Energy Switch",
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
		"turn_tactical_facts": {"primary_attack_ready": false},
	}
	var augmented: Dictionary = strategy.call("_deck_augment_action_id_payload", payload, gs, 0)
	var routes: Array = augmented.get("candidate_routes", []) if augmented.get("candidate_routes", []) is Array else []
	var charge_route: Dictionary = {}
	for raw_route: Variant in routes:
		if raw_route is Dictionary and str((raw_route as Dictionary).get("route_action_id", "")) == "route:regidrago_charge_apex_attack":
			charge_route = raw_route
			break
	var actions: Array = charge_route.get("actions", []) if charge_route.get("actions", []) is Array else []
	var switch_action: Dictionary = actions[0] if actions.size() > 0 and actions[0] is Dictionary else {}
	var last_action: Dictionary = actions[actions.size() - 1] if actions.size() > 0 and actions[actions.size() - 1] is Dictionary else {}
	var facts: Dictionary = augmented.get("turn_tactical_facts", {}) if augmented.get("turn_tactical_facts", {}) is Dictionary else {}
	var charge_fact: Dictionary = facts.get("regidrago_charge_apex", {}) if facts.get("regidrago_charge_apex", {}) is Dictionary else {}

	return run_checks([
		assert_true(not charge_route.is_empty(), "Payload should expose a VSTAR reload route when Energy Switch completes active Apex Dragon"),
		assert_eq(str(switch_action.get("id", "")), "play_trainer:c7", "VSTAR reload route should use the legal Energy Switch action"),
		assert_eq(str(last_action.get("id", "")), "end_turn", "VSTAR reload route should close with end_turn so runtime can convert into Apex Dragon"),
		assert_true(bool(charge_fact.get("route_available", false)), "Tactical facts should explain that active VSTAR can be reloaded into Apex Dragon"),
	])


func test_v17_regidrago_llm_payload_exposes_vstar_reload_route_with_switch_and_attach() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "Regidrago LLM strategy should instantiate"
	var gs := _make_game_state(10, GameState.GamePhase.MAIN)
	var player: PlayerState = gs.players[0]
	var active := _make_slot(_regidrago_vstar(), 0)
	_attach_energy(active, "R", 1)
	player.active_pokemon = active
	var ogerpon := _make_slot(_make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210), 0)
	_attach_energy(ogerpon, "G", 1)
	player.bench.append(ogerpon)
	player.discard_pile.append(_make_card(_make_pokemon_cd("Dragapult ex", "Stage 2", "N", 320), 0))
	var payload := {
		"legal_actions": [
			{
				"id": "play_trainer:c7",
				"type": "play_trainer",
				"card": "Energy Switch",
				"summary": "play Energy Switch",
			},
			{
				"id": "attach_energy:c20:active",
				"type": "attach_energy",
				"card": "Grass Energy",
				"energy_type": "Grass",
				"position": "active",
				"target": "Regidrago VSTAR",
				"summary": "attach Grass to active Regidrago VSTAR",
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
		"turn_tactical_facts": {"primary_attack_ready": false},
	}
	var augmented: Dictionary = strategy.call("_deck_augment_action_id_payload", payload, gs, 0)
	var routes: Array = augmented.get("candidate_routes", []) if augmented.get("candidate_routes", []) is Array else []
	var charge_route: Dictionary = {}
	for raw_route: Variant in routes:
		if raw_route is Dictionary and str((raw_route as Dictionary).get("route_action_id", "")) == "route:regidrago_charge_apex_attack":
			charge_route = raw_route
			break
	var actions: Array = charge_route.get("actions", []) if charge_route.get("actions", []) is Array else []
	var first_action: Dictionary = actions[0] if actions.size() > 0 and actions[0] is Dictionary else {}
	var second_action: Dictionary = actions[1] if actions.size() > 1 and actions[1] is Dictionary else {}
	var last_action: Dictionary = actions[actions.size() - 1] if actions.size() > 0 and actions[actions.size() - 1] is Dictionary else {}

	return run_checks([
		assert_true(not charge_route.is_empty(), "Payload should expose a VSTAR reload route when switch plus manual attach completes GGR"),
		assert_eq(str(first_action.get("id", "")), "play_trainer:c7", "Reload route should move Ogerpon Grass first"),
		assert_eq(str(second_action.get("id", "")), "attach_energy:c20:active", "Reload route should then manually attach the remaining Grass"),
		assert_eq(str(last_action.get("id", "")), "end_turn", "Reload route should close with end_turn so runtime can convert into Apex Dragon"),
	])


func test_v17_regidrago_llm_blocks_switching_active_vstar_off_attack_line() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "Regidrago LLM strategy should instantiate"
	var gs := _make_game_state(6, GameState.GamePhase.MAIN)
	var player: PlayerState = gs.players[0]
	var active := _make_slot(_regidrago_vstar(), 0)
	_attach_energy(active, "R", 1)
	_attach_energy(active, "G", 1)
	player.active_pokemon = active
	var ogerpon := _make_slot(_make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210), 0)
	_attach_energy(ogerpon, "G", 1)
	player.bench.append(ogerpon)
	player.discard_pile.append(_make_card(_make_pokemon_cd("Dragapult ex", "Stage 2", "N", 320), 0))
	var switch_action := {"kind": "play_trainer", "type": "play_trainer", "card": "Switch", "summary": "play Switch"}
	var energy_switch_action := {"kind": "play_trainer", "type": "play_trainer", "card": "Energy Switch", "summary": "play Energy Switch"}

	return run_checks([
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", switch_action, switch_action, gs, 0)), "LLM queue must not switch active Regidrago VSTAR away from the Apex line"),
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", energy_switch_action, energy_switch_action, gs, 0)), "Energy Switch should remain legal because it reloads active Regidrago VSTAR"),
	])


func test_v17_regidrago_llm_blocks_prime_catcher_pivoting_energy_regidrago_into_ogerpon() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "Regidrago LLM strategy should instantiate"
	var gs := _make_game_state(2, GameState.GamePhase.MAIN)
	var player: PlayerState = gs.players[0]
	var active := _make_slot(_regidrago_v_with_roar(), 0)
	_attach_energy(active, "R", 1)
	_attach_energy(active, "G", 1)
	player.active_pokemon = active
	var ogerpon := _make_slot(_make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210), 0)
	player.bench.append(ogerpon)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 1)
	var catcher_action := {
		"kind": "play_trainer",
		"type": "play_trainer",
		"card": "Prime Catcher",
		"summary": "play Prime Catcher",
		"targets": [{"own_bench_target": [ogerpon]}],
	}
	return assert_true(
		bool(strategy.call("_deck_should_block_exact_queue_match", catcher_action, catcher_action, gs, 0)),
		"Under Charizard-line pressure, Prime Catcher must not pivot an energy-bearing Regidrago V into Ogerpon"
	)


func test_v17_regidrago_llm_allows_switch_from_support_active_to_attacker() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "Regidrago LLM strategy should instantiate"
	var gs := _make_game_state(6, GameState.GamePhase.MAIN)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210), 0)
	var vstar := _make_slot(_regidrago_vstar(), 0)
	_attach_energy(vstar, "R", 1)
	_attach_energy(vstar, "G", 2)
	player.bench.append(vstar)
	player.discard_pile.append(_make_card(_make_pokemon_cd("Dragapult ex", "Stage 2", "N", 320), 0))
	var switch_action := {"kind": "play_trainer", "type": "play_trainer", "card": "Switch", "summary": "play Switch"}

	return assert_false(
		bool(strategy.call("_deck_should_block_exact_queue_match", switch_action, switch_action, gs, 0)),
		"Switch should still be allowed when the active Pokemon is support and a ready attacker is on the bench"
	)


func test_v17_regidrago_llm_blocks_support_pivot_to_mew_against_charizard() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "Regidrago LLM strategy should instantiate"
	var gs := _make_game_state(8, GameState.GamePhase.MAIN)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210), 0)
	_attach_energy(player.active_pokemon, "G", 1)
	var mew := _make_slot(_make_pokemon_cd("Mew ex", "Basic", "P", 180), 0)
	player.bench.append(mew)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Charizard ex", "Stage 2", "D", 330), 1)
	var retreat_action := {
		"kind": "retreat",
		"type": "retreat",
		"bench_target": mew,
		"summary": "retreat Ogerpon into Mew ex",
	}
	return assert_true(
		bool(strategy.call("_deck_should_block_exact_queue_match", retreat_action, retreat_action, gs, 0)),
		"Under Charizard pressure, LLM should not pivot an Ogerpon buffer into Mew ex"
	)


func test_v17_regidrago_llm_hard_blocks_late_ogerpon_retreat_to_squawk() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "Regidrago LLM strategy should instantiate"
	var gs := _make_game_state(6, GameState.GamePhase.MAIN)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210), 0)
	_attach_energy(player.active_pokemon, "G", 1)
	player.bench.append(_make_slot(_regidrago_vstar(), 0))
	var squawk := _make_slot(_make_pokemon_cd("Squawkabilly ex", "Basic", "C", 160), 0)
	player.bench.append(squawk)
	var retreat_action := {
		"kind": "retreat",
		"type": "retreat",
		"bench_target": squawk,
		"summary": "retreat Ogerpon into Squawkabilly ex",
	}
	var end_action := {"kind": "end_turn", "type": "end_turn"}

	return run_checks([
		assert_true(float(strategy.score_action_absolute(retreat_action, gs, 0)) < -11000.0, "Late Ogerpon retreat into Squawkabilly should be harder-blocked than a blocked end_turn"),
		assert_true(float(strategy.score_action_absolute(end_action, gs, 0)) > float(strategy.score_action_absolute(retreat_action, gs, 0)), "Blocked end_turn should still beat the support-liability retreat"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", retreat_action, retreat_action, gs, 0)), "Exact queue should reject late Ogerpon-to-Squawk retreat"),
	])


func test_v17_regidrago_llm_allows_support_pivot_to_ready_vstar_against_charizard() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "Regidrago LLM strategy should instantiate"
	var gs := _make_game_state(8, GameState.GamePhase.MAIN)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210), 0)
	_attach_energy(player.active_pokemon, "G", 1)
	var vstar := _make_slot(_regidrago_vstar(), 0)
	_attach_energy(vstar, "R", 1)
	_attach_energy(vstar, "G", 2)
	player.bench.append(vstar)
	player.discard_pile.append(_make_card(_make_pokemon_cd("Dragapult ex", "Stage 2", "N", 320), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Charizard ex", "Stage 2", "D", 330), 1)
	var retreat_action := {
		"kind": "retreat",
		"type": "retreat",
		"bench_target": vstar,
		"summary": "retreat Ogerpon into ready Regidrago VSTAR",
	}
	return assert_false(
		bool(strategy.call("_deck_should_block_exact_queue_match", retreat_action, retreat_action, gs, 0)),
		"Charizard liability guard must still allow a ready Regidrago VSTAR handoff"
	)


func test_v17_regidrago_llm_blocks_damaged_ready_vstar_handoff_against_charizard() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "Regidrago LLM strategy should instantiate"
	var gs := _make_game_state(10, GameState.GamePhase.MAIN)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210), 0)
	_attach_energy(player.active_pokemon, "G", 1)
	var vstar := _make_slot(_regidrago_vstar(), 0)
	vstar.damage_counters = 190
	_attach_energy(vstar, "R", 1)
	_attach_energy(vstar, "G", 2)
	player.bench.append(vstar)
	player.discard_pile.append(_make_card(_make_pokemon_cd("Dragapult ex", "Stage 2", "N", 320), 0))
	player.discard_pile.append(_make_card(_make_pokemon_cd("Hisuian Goodra VSTAR", "VSTAR", "N", 270), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Charizard ex", "Stage 2", "D", 330), 1)
	var retreat_action := {
		"kind": "retreat",
		"type": "retreat",
		"bench_target": vstar,
		"summary": "retreat Ogerpon into damaged ready Regidrago VSTAR",
	}
	return assert_true(
		bool(strategy.call("_deck_should_block_exact_queue_match", retreat_action, retreat_action, gs, 0)),
		"Under Charizard pressure, LLM should not expose a damaged ready VSTAR that cannot survive even with Goodra"
	)


func test_v17_regidrago_llm_replaces_end_with_energy_switch_setup() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "Regidrago LLM strategy should instantiate"
	var gs := _make_game_state(2, GameState.GamePhase.MAIN)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_regidrago_v_with_roar(), 0)
	_attach_energy(player.active_pokemon, "R", 1)
	var ogerpon := _make_slot(_make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210), 0)
	_attach_energy(ogerpon, "G", 1)
	player.bench.append(ogerpon)
	var switch_cd := CardData.new()
	switch_cd.name = "Energy Switch"
	switch_cd.name_en = "Energy Switch"
	switch_cd.card_type = "Item"
	var energy_switch := _make_card(switch_cd, 0)
	player.hand.append(energy_switch)
	var action := {
		"kind": "play_trainer",
		"type": "play_trainer",
		"card": energy_switch,
		"summary": "play Energy Switch from Ogerpon to Regidrago",
	}

	return run_checks([
		assert_true(bool(strategy.call("_deck_should_block_end_turn", gs, 0)), "End turn should be blocked while Energy Switch can move Ogerpon Grass to Regidrago"),
		assert_true(bool(strategy.call("_deck_can_replace_end_turn_with_action", action, gs, 0)), "Runtime should allow Energy Switch to replace a premature end_turn"),
	])


func test_v17_regidrago_llm_replaces_end_with_ready_active_apex() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "Regidrago LLM strategy should instantiate"
	var gs := _make_game_state(6, GameState.GamePhase.MAIN)
	var player: PlayerState = gs.players[0]
	var active := _make_slot(_regidrago_vstar(), 0)
	_attach_energy(active, "R", 1)
	_attach_energy(active, "G", 2)
	player.active_pokemon = active
	player.discard_pile.append(_make_card(_make_pokemon_cd("Dragapult ex", "Stage 2", "N", 320), 0))
	var action := {
		"kind": "attack",
		"type": "attack",
		"source_slot": active,
		"attack_index": 0,
		"attack_name": "Apex Dragon",
		"projected_damage": 200,
		"projected_knockout": false,
	}
	var end_action := {"kind": "end_turn", "type": "end_turn"}

	return run_checks([
		assert_true(bool(strategy.call("_deck_should_block_end_turn", gs, 0)), "Ready active Regidrago VSTAR with Dragon fuel should not be allowed to end before attacking"),
		assert_true(bool(strategy.call("_deck_can_replace_end_turn_with_action", action, gs, 0)), "Runtime should replace premature end_turn with Apex Dragon when the active VSTAR is ready"),
		assert_true(float(strategy.score_action_absolute(end_action, gs, 0)) < -11000.0, "Scoring should make ready-Apex end_turn worse than other blocked fallback actions"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", end_action, end_action, gs, 0)), "Exact queue should reject end_turn after a gust/setup action leaves active Apex ready"),
	])


func test_v17_regidrago_llm_blocks_ready_apex_retreat_to_unready_vstar_harder_than_end() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "Regidrago LLM strategy should instantiate"
	var gs := _make_game_state(8, GameState.GamePhase.MAIN)
	var player: PlayerState = gs.players[0]
	var active := _make_slot(_regidrago_vstar(), 0)
	var bench_vstar := _make_slot(_regidrago_vstar(), 0)
	_attach_energy(active, "R", 1)
	_attach_energy(active, "G", 2)
	player.active_pokemon = active
	player.bench.append(bench_vstar)
	player.discard_pile.append(_make_card(_make_pokemon_cd("Dragapult ex", "Stage 2", "N", 320), 0))
	var retreat_action := {
		"kind": "retreat",
		"type": "retreat",
		"bench_target": bench_vstar,
		"energy_to_discard": active.attached_energy.duplicate(),
		"summary": "retreat ready Regidrago VSTAR into unready Regidrago VSTAR",
	}
	var end_action := {"kind": "end_turn", "type": "end_turn"}

	return run_checks([
		assert_true(float(strategy.score_action_absolute(retreat_action, gs, 0)) < float(strategy.score_action_absolute(end_action, gs, 0)), "Ready Apex should attack, not spend its attack Energy to pivot into an unready VSTAR"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", retreat_action, retreat_action, gs, 0)), "Exact queue should reject ready-Apex retreat into an unready VSTAR"),
	])


func test_v17_regidrago_llm_blocks_radiant_charizard_resource_sink_while_regidrago_exists() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "Regidrago LLM strategy should instantiate"
	var gs := _make_game_state(10, GameState.GamePhase.MAIN)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_regidrago_v_with_roar(), 0)
	var radiant := _make_slot(_make_pokemon_cd("Radiant Charizard", "Basic", "R", 160), 0)
	player.bench.append(radiant)
	var radiant_card := _make_card(_make_pokemon_cd("Radiant Charizard", "Basic", "R", 160), 0)
	var grass := _make_card(_make_energy_card("Grass Energy", "G"), 0)
	var bench_action := {"kind": "play_basic_to_bench", "type": "play_basic_to_bench", "card": radiant_card}
	var attach_action := {"kind": "attach_energy", "type": "attach_energy", "card": grass, "target_slot": radiant}

	return run_checks([
		assert_true(float(strategy.score_action_absolute(bench_action, gs, 0)) < -9000.0, "LLM runtime should hard-block benching Radiant Charizard while Regidrago exists"),
		assert_true(float(strategy.score_action_absolute(attach_action, gs, 0)) < -9000.0, "LLM runtime should hard-block attaching Grass to Radiant Charizard while Regidrago exists"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", bench_action, bench_action, gs, 0)), "Exact queue should block Radiant Charizard bench resource sink"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", attach_action, attach_action, gs, 0)), "Exact queue should block Radiant Charizard attach resource sink"),
	])


func test_v17_regidrago_llm_blocks_mew_discard_when_backup_needs_vstar_draw() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "Regidrago LLM strategy should instantiate"
	var gs := _make_game_state(20, GameState.GamePhase.MAIN)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210), 0)
	player.bench.append(_make_slot(_regidrago_v_with_roar(), 0))
	player.deck.append(_make_card(_regidrago_vstar(), 0))
	var mew := _make_card(_make_pokemon_cd("Mew ex", "Basic", "P", 180, [
		{"name": "Restart", "cost": "", "damage": "", "text": "Draw until you have 3 cards in hand."},
	]), 0)
	var vessel := _make_card(_make_trainer_cd("Earthen Vessel"), 0)
	var grass := _make_card(_make_energy_card("Grass Energy", "G"), 0)
	var action := {
		"kind": "play_trainer",
		"type": "play_trainer",
		"card": vessel,
		"targets": [{"discard_cards": [mew], "search_energy": [grass]}],
		"summary": "Earthen Vessel discarding Mew ex",
	}

	return run_checks([
		assert_true(float(strategy.score_action_absolute(action, gs, 0)) < -9000.0, "LLM runtime should hard-block discarding Mew ex when it is the needed backup VSTAR draw engine"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", action, action, gs, 0)), "Exact queue should also reject the protected Mew discard"),
	])


func test_v17_regidrago_llm_blocks_prime_catcher_stranding_ready_basic_drago() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "Regidrago LLM strategy should instantiate"
	var gs := _make_game_state(10, GameState.GamePhase.MAIN)
	var player: PlayerState = gs.players[0]
	var active := _make_slot(_regidrago_v_with_roar(), 0)
	_attach_energy(active, "R", 1)
	_attach_energy(active, "G", 2)
	player.active_pokemon = active
	var ogerpon := _make_slot(_make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210), 0)
	_attach_energy(ogerpon, "G", 2)
	player.bench.append(ogerpon)
	var prime_catcher_action := {
		"kind": "play_trainer",
		"type": "play_trainer",
		"card": "Prime Catcher",
		"targets": [{"own_bench_target": [ogerpon]}],
		"summary": "Prime Catcher Rotom and pivot into Ogerpon",
	}
	return assert_true(
		bool(strategy.call("_deck_should_block_exact_queue_match", prime_catcher_action, prime_catcher_action, gs, 0)),
		"Prime Catcher should be blocked when it pivots a ready active Regidrago V into a non-attacking support Pokemon"
	)


func test_v17_regidrago_llm_allows_prime_catcher_from_support_to_ready_vstar() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "Regidrago LLM strategy should instantiate"
	var gs := _make_game_state(10, GameState.GamePhase.MAIN)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Teal Mask Ogerpon ex", "Basic", "G", 210), 0)
	var vstar := _make_slot(_regidrago_vstar(), 0)
	_attach_energy(vstar, "R", 1)
	_attach_energy(vstar, "G", 2)
	player.bench.append(vstar)
	player.discard_pile.append(_make_card(_make_pokemon_cd("Dragapult ex", "Stage 2", "N", 320), 0))
	var prime_catcher_action := {
		"kind": "play_trainer",
		"type": "play_trainer",
		"card": "Prime Catcher",
		"targets": [{"own_bench_target": [vstar]}],
		"summary": "Prime Catcher and pivot into ready Regidrago VSTAR",
	}
	return assert_false(
		bool(strategy.call("_deck_should_block_exact_queue_match", prime_catcher_action, prime_catcher_action, gs, 0)),
		"Prime Catcher should remain legal when it moves support active into a ready Regidrago VSTAR"
	)


func test_v17_regidrago_llm_blocks_apex_until_backup_vstar_evolves() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "Regidrago LLM strategy should instantiate"
	var gs := _make_game_state(6, GameState.GamePhase.MAIN)
	var player: PlayerState = gs.players[0]
	for i: int in 6:
		player.prizes.append(_make_card(_make_pokemon_cd("Prize %d" % i), 0))
	var active := _make_slot(_regidrago_vstar(), 0)
	_attach_energy(active, "R", 1)
	_attach_energy(active, "G", 2)
	player.active_pokemon = active
	player.bench.append(_make_slot(_regidrago_v_with_roar(), 0))
	player.hand.append(_make_card(_regidrago_vstar(), 0))
	player.discard_pile.append(_make_card(_make_pokemon_cd("Dragapult ex", "Stage 2", "N", 320), 0))
	var attack_action := {
		"kind": "attack",
		"type": "attack",
		"source_slot": active,
		"attack_index": 0,
		"attack_name": "Apex Dragon",
		"projected_damage": 200,
		"projected_knockout": false,
	}
	return assert_true(
		bool(strategy.call("_deck_should_block_exact_queue_match", attack_action, attack_action, gs, 0)),
		"Non-final Apex Dragon should be blocked for one action when a live backup Regidrago V can be evolved from hand"
	)


func test_v17_regidrago_llm_blocks_attack_until_backup_basic_is_benched() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "Regidrago LLM strategy should instantiate"
	var gs := _make_game_state(4, GameState.GamePhase.MAIN)
	var player: PlayerState = gs.players[0]
	for i: int in 6:
		player.prizes.append(_make_card(_make_pokemon_cd("Prize %d" % i), 0))
	var active := _make_slot(_regidrago_vstar(), 0)
	_attach_energy(active, "R", 1)
	_attach_energy(active, "G", 2)
	player.active_pokemon = active
	player.hand.append(_make_card(_regidrago_v_with_roar(), 0))
	player.discard_pile.append(_make_card(_make_pokemon_cd("Dragapult ex", "Stage 2", "N", 320), 0))
	var attack_action := {
		"kind": "attack",
		"type": "attack",
		"source_slot": active,
		"attack_index": 0,
		"attack_name": "Apex Dragon",
		"projected_damage": 200,
		"projected_knockout": false,
	}
	return assert_true(
		bool(strategy.call("_deck_should_block_exact_queue_match", attack_action, attack_action, gs, 0)),
		"Non-final attack should pause for one action when a backup Regidrago V is in hand and bench space is open"
	)


func test_v17_regidrago_llm_runtime_scores_backup_seed_over_attack() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "Regidrago LLM strategy should instantiate"
	var gs := _make_game_state(4, GameState.GamePhase.MAIN)
	var player: PlayerState = gs.players[0]
	for i: int in 6:
		player.prizes.append(_make_card(_make_pokemon_cd("Prize %d" % i), 0))
	var active := _make_slot(_regidrago_vstar(), 0)
	_attach_energy(active, "R", 1)
	_attach_energy(active, "G", 2)
	player.active_pokemon = active
	var backup_v := _make_card(_regidrago_v_with_roar(), 0)
	player.hand.append(backup_v)
	player.discard_pile.append(_make_card(_make_pokemon_cd("Dragapult ex", "Stage 2", "N", 320), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Charizard ex", "Stage 2", "D", 330), 1)
	var bench_action := {
		"kind": "play_basic_to_bench",
		"type": "play_basic_to_bench",
		"card": backup_v,
	}
	var attack_action := {
		"kind": "attack",
		"type": "attack",
		"source_slot": active,
		"attack_index": 0,
		"attack_name": "巨龙无双",
		"projected_damage": 200,
		"projected_knockout": false,
	}
	var bench_score: float = strategy.score_action_absolute(bench_action, gs, 0)
	var attack_score: float = strategy.score_action_absolute(attack_action, gs, 0)

	return run_checks([
		assert_true(attack_score <= -10000.0, "Runtime scorer should hard-block non-final Apex before a hand backup Regidrago V is benched (attack=%f)" % attack_score),
		assert_true(bench_score > attack_score, "Benching backup Regidrago V should beat the blocked attack (bench=%f attack=%f)" % [bench_score, attack_score]),
	])


func test_v17_regidrago_llm_runtime_blocks_basic_dragon_laser_when_vstar_conversion_is_ready() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "Regidrago LLM strategy should instantiate"
	var gs := _make_game_state(4, GameState.GamePhase.MAIN)
	var player: PlayerState = gs.players[0]
	for i: int in 6:
		player.prizes.append(_make_card(_make_pokemon_cd("Prize %d" % i), 0))
	var active := _make_slot(_regidrago_v_with_roar(), 0)
	_attach_energy(active, "R", 1)
	_attach_energy(active, "G", 2)
	player.active_pokemon = active
	var vstar := _make_card(_regidrago_vstar(), 0)
	player.hand.append(vstar)
	player.discard_pile.append(_make_card(_make_pokemon_cd("Dragapult ex", "Stage 2", "N", 320), 0))
	var evolve_action := {
		"kind": "evolve",
		"type": "evolve",
		"card": vstar,
		"target_slot": active,
	}
	var laser_action := {
		"kind": "attack",
		"type": "attack",
		"source_slot": active,
		"attack_index": 1,
		"attack_name": "Dragon Laser",
		"projected_damage": 130,
		"projected_knockout": true,
	}
	var evolve_score: float = strategy.score_action_absolute(evolve_action, gs, 0)
	var laser_score: float = strategy.score_action_absolute(laser_action, gs, 0)

	return run_checks([
		assert_true(laser_score <= -10000.0, "Runtime scorer should hard-block basic Dragon Laser while VSTAR plus Apex fuel is already available (laser=%f)" % laser_score),
		assert_true(evolve_score > laser_score, "VSTAR conversion should beat the blocked basic Dragon Laser line (evolve=%f laser=%f)" % [evolve_score, laser_score]),
	])


func test_v17_regidrago_llm_blocks_basic_dragon_laser_into_charizard_line_without_fuel() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "Regidrago LLM strategy should instantiate"
	var gs := _make_game_state(4, GameState.GamePhase.MAIN)
	var player: PlayerState = gs.players[0]
	player.prizes.clear()
	for i: int in 6:
		player.prizes.append(_make_card(_make_pokemon_cd("Prize %d" % i), 0))
	var active := _make_slot(_regidrago_v_with_roar(), 0)
	_attach_energy(active, "G", 2)
	_attach_energy(active, "R", 1)
	player.active_pokemon = active
	player.hand.append(_make_card(_regidrago_vstar(), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 1)
	var laser_action := {
		"kind": "attack",
		"source_slot": active,
		"attack_index": 1,
		"attack_name": "Dragon Laser",
		"projected_damage": 130,
		"projected_knockout": true,
	}
	var laser_score: float = strategy.score_action_absolute(laser_action, gs, 0)
	return assert_true(laser_score <= -10000.0, "Into Charizard line, Basic Dragon Laser should be blocked even before copied-attack fuel is in discard (laser=%f)" % laser_score)


func test_v17_regidrago_llm_blocks_basic_dragon_laser_into_chinese_charmeleon_line() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "Regidrago LLM strategy should instantiate"
	var gs := _make_game_state(4, GameState.GamePhase.MAIN)
	var player: PlayerState = gs.players[0]
	player.prizes.clear()
	for i: int in 6:
		player.prizes.append(_make_card(_make_pokemon_cd("Prize %d" % i), 0))
	var active := _make_slot(_regidrago_v_with_roar(), 0)
	_attach_energy(active, "G", 2)
	_attach_energy(active, "R", 1)
	player.active_pokemon = active
	player.hand.append(_make_card(_regidrago_vstar(), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("火恐龙", "Stage 1", "R", 100), 1)
	var laser_action := {
		"kind": "attack",
		"source_slot": active,
		"attack_index": 1,
		"attack_name": "Dragon Laser",
		"projected_damage": 130,
		"projected_knockout": true,
	}
	var laser_score: float = strategy.score_action_absolute(laser_action, gs, 0)
	return assert_true(laser_score <= -10000.0, "Chinese Charmeleon line should still block basic Dragon Laser before VSTAR conversion (laser=%f)" % laser_score)


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


func test_v17_regidrago_llm_payload_rewrites_chinese_apex_as_copied_attack() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "Regidrago LLM strategy should instantiate"
	var gs := _make_game_state(5, GameState.GamePhase.MAIN)
	var player: PlayerState = gs.players[0]
	player.prizes.clear()
	for i: int in 6:
		player.prizes.append(_make_card(_make_pokemon_cd("Prize %d" % i), 0))
	var active := _make_slot(_make_pokemon_cd("Regidrago VSTAR", "VSTAR", "N", 280, [
		{"name": "巨龙无双", "cost": "GGR", "damage": "", "text": "选择自己弃牌区中的【龙】宝可梦所拥有的1个招式，作为这个招式使用。"},
	]), 0)
	active.damage_counters = 180
	_attach_energy(active, "G", 2)
	_attach_energy(active, "R", 1)
	player.active_pokemon = active
	player.discard_pile.append(_make_card(_make_pokemon_cd("Dragapult ex", "Stage 2", "N", 320), 0))
	player.discard_pile.append(_make_card(_make_pokemon_cd("Hisuian Goodra VSTAR", "VSTAR", "N", 270), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Charizard ex", "Stage 2", "D", 330), 1)
	var payload := {
		"legal_actions": [
			{
				"id": "attack:0:巨龙无双",
				"type": "attack",
				"attack_name": "巨龙无双",
				"summary": "attack with 巨龙无双",
				"requires_interaction": true,
				"interaction_schema": {"discard_cards": {"type": "array"}},
				"attack_quality": {"role": "desperation_redraw", "terminal_priority": "low"},
			},
		],
		"candidate_routes": [
			{
				"id": "attack_now",
				"route_action_id": "route:attack_now",
				"goal": "attack",
				"actions": [{"id": "attack:0:巨龙无双", "type": "attack"}],
			},
		],
		"turn_tactical_facts": {
			"active_attack_options": [{
				"attack_name": "巨龙无双",
				"legal_action_id": "attack:0:巨龙无双",
				"attack_quality": {"role": "desperation_redraw", "terminal_priority": "low"},
			}],
			"attack_quality_by_action_id": {
				"attack:0:巨龙无双": {"role": "desperation_redraw", "terminal_priority": "low"},
			},
		},
	}
	var augmented: Dictionary = strategy.call("_deck_augment_action_id_payload", payload, gs, 0)
	var legal_actions: Array = augmented.get("legal_actions", []) if augmented.get("legal_actions", []) is Array else []
	var action: Dictionary = legal_actions[0] if not legal_actions.is_empty() and legal_actions[0] is Dictionary else {}
	var schema: Dictionary = action.get("interaction_schema", {}) if action.get("interaction_schema", {}) is Dictionary else {}
	var policy: Dictionary = action.get("selection_policy", {}) if action.get("selection_policy", {}) is Dictionary else {}
	var facts: Dictionary = augmented.get("turn_tactical_facts", {}) if augmented.get("turn_tactical_facts", {}) is Dictionary else {}
	var recommended: Dictionary = facts.get("regidrago_recommended_copied_attack", {}) if facts.get("regidrago_recommended_copied_attack", {}) is Dictionary else {}
	var quality_by_id: Dictionary = facts.get("attack_quality_by_action_id", {}) if facts.get("attack_quality_by_action_id", {}) is Dictionary else {}
	var apex_quality: Dictionary = quality_by_id.get("attack:0:巨龙无双", {}) if quality_by_id.get("attack:0:巨龙无双", {}) is Dictionary else {}
	var routes: Array = augmented.get("candidate_routes", []) if augmented.get("candidate_routes", []) is Array else []
	var route_policy: Dictionary = {}
	if not routes.is_empty() and routes[0] is Dictionary:
		var actions: Array = (routes[0] as Dictionary).get("actions", []) if (routes[0] as Dictionary).get("actions", []) is Array else []
		if not actions.is_empty() and actions[0] is Dictionary:
			route_policy = (actions[0] as Dictionary).get("selection_policy", {}) if (actions[0] as Dictionary).get("selection_policy", {}) is Dictionary else {}

	return run_checks([
		assert_true(schema.has("copied_attack"), "Augmented Chinese Apex action should expose copied_attack"),
		assert_false(schema.has("discard_cards"), "Augmented Chinese Apex action must not keep discard_cards"),
		assert_eq(str(recommended.get("attack_name", "")), "Phantom Dive", "Damaged Regidrago should prefer Dragapult when Goodra reduction cannot save it"),
		assert_eq(str(policy.get("attack_name", "")), "Phantom Dive", "Legal action should carry copied attack selection_policy"),
		assert_eq(str(route_policy.get("attack_name", "")), "Phantom Dive", "Candidate route should preserve copied attack selection_policy"),
		assert_eq(str(apex_quality.get("terminal_priority", "")), "high", "Apex should be a high-priority copied damage attack, not a redraw attack"),
	])


func test_v17_regidrago_llm_recommends_goodra_for_same_prize_under_charizard_pressure() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "Regidrago LLM strategy should instantiate"
	var gs := _make_game_state(5, GameState.GamePhase.MAIN)
	var player: PlayerState = gs.players[0]
	var active := _make_slot(_regidrago_vstar(), 0)
	active.damage_counters = 190
	_attach_energy(active, "G", 2)
	_attach_energy(active, "R", 1)
	player.active_pokemon = active
	player.discard_pile.append(_make_card(_make_pokemon_cd("Dragapult ex", "Stage 2", "N", 320), 0))
	player.discard_pile.append(_make_card(_make_pokemon_cd("Hisuian Goodra VSTAR", "VSTAR", "N", 270), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Pidgey", "Basic", "C", 60), 1)
	gs.players[1].bench.append(_make_slot(_make_pokemon_cd("Charizard ex", "Stage 2", "D", 330), 1))
	var payload := {
		"legal_actions": [{
			"id": "attack:active:0:Apex Dragon",
			"type": "attack",
			"attack_name": "Apex Dragon",
			"summary": "attack with Apex Dragon",
			"requires_interaction": true,
			"interaction_schema": {"discard_cards": {"type": "array"}},
		}],
		"candidate_routes": [],
		"turn_tactical_facts": {},
	}
	var augmented: Dictionary = strategy.call("_deck_augment_action_id_payload", payload, gs, 0)
	var facts: Dictionary = augmented.get("turn_tactical_facts", {}) if augmented.get("turn_tactical_facts", {}) is Dictionary else {}
	var recommended: Dictionary = facts.get("regidrago_recommended_copied_attack", {}) if facts.get("regidrago_recommended_copied_attack", {}) is Dictionary else {}
	var legal_actions: Array = augmented.get("legal_actions", []) if augmented.get("legal_actions", []) is Array else []
	var action: Dictionary = legal_actions[0] if not legal_actions.is_empty() and legal_actions[0] is Dictionary else {}
	var policy: Dictionary = action.get("selection_policy", {}) if action.get("selection_policy", {}) is Dictionary else {}

	return run_checks([
		assert_eq(str(recommended.get("source_card", "")), "Hisuian Goodra VSTAR", "Low-HP active prizes under Charizard pressure should recommend Goodra protection over Dragapult spread"),
		assert_eq(str(recommended.get("attack_name", "")), "Rolling Iron", "Goodra should be the copied attack when it takes the same active prize"),
		assert_eq(str(policy.get("source_card", "")), "Hisuian Goodra VSTAR", "Legal Apex action should carry the Goodra copied-attack policy"),
	])


func test_v17_regidrago_llm_recommends_giratina_pressure_into_full_charizard() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "Regidrago LLM strategy should instantiate"
	var gs := _make_game_state(5, GameState.GamePhase.MAIN)
	var player: PlayerState = gs.players[0]
	player.prizes.clear()
	for i: int in 6:
		player.prizes.append(_make_card(_make_pokemon_cd("Prize %d" % i), 0))
	var active := _make_slot(_regidrago_vstar(), 0)
	active.damage_counters = 190
	_attach_energy(active, "G", 2)
	_attach_energy(active, "R", 1)
	player.active_pokemon = active
	player.discard_pile.append(_make_card(_make_pokemon_cd("Dragapult ex", "Stage 2", "N", 320), 0))
	player.discard_pile.append(_make_card(_make_pokemon_cd("Hisuian Goodra VSTAR", "VSTAR", "N", 270), 0))
	player.discard_pile.append(_make_card(_make_pokemon_cd("Giratina VSTAR", "VSTAR", "N", 280), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("喷火龙ex", "Stage 2", "D", 330), 1)
	var payload := {
		"legal_actions": [{
			"id": "attack:active:0:Apex Dragon",
			"type": "attack",
			"attack_name": "Apex Dragon",
			"summary": "attack with Apex Dragon",
			"requires_interaction": true,
			"interaction_schema": {"discard_cards": {"type": "array"}},
		}],
		"candidate_routes": [],
		"turn_tactical_facts": {},
	}
	var augmented: Dictionary = strategy.call("_deck_augment_action_id_payload", payload, gs, 0)
	var facts: Dictionary = augmented.get("turn_tactical_facts", {}) if augmented.get("turn_tactical_facts", {}) is Dictionary else {}
	var recommended: Dictionary = facts.get("regidrago_recommended_copied_attack", {}) if facts.get("regidrago_recommended_copied_attack", {}) is Dictionary else {}
	var legal_actions: Array = augmented.get("legal_actions", []) if augmented.get("legal_actions", []) is Array else []
	var action: Dictionary = legal_actions[0] if not legal_actions.is_empty() and legal_actions[0] is Dictionary else {}
	var policy: Dictionary = action.get("selection_policy", {}) if action.get("selection_policy", {}) is Dictionary else {}

	return run_checks([
		assert_eq(str(recommended.get("source_card", "")), "Giratina VSTAR", "Full Chinese Charizard should recommend Giratina pressure when Goodra cannot save the active"),
		assert_eq(str(recommended.get("attack_name", "")), "Lost Impact", "Full Chinese Charizard should recommend Lost Impact over a 200 hit"),
		assert_eq(str(policy.get("source_card", "")), "Giratina VSTAR", "Legal Apex action should carry the Giratina copied-attack policy"),
	])
