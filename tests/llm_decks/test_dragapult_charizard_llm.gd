class_name TestDragapultCharizardLLM
extends TestBase

const LLM_SCRIPT_PATH := "res://scripts/ai/DeckStrategyDragapultCharizardLLM.gd"
const RouteBuilderScript = preload("res://scripts/ai/LLMRouteCandidateBuilder.gd")


func _load_script(script_path: String) -> GDScript:
	var script: Variant = load(script_path)
	return script if script is GDScript else null


func _new_strategy() -> RefCounted:
	CardInstance.reset_id_counter()
	var script := _load_script(LLM_SCRIPT_PATH)
	return script.new() if script != null else null


func _make_pokemon_cd(
	pname: String,
	stage: String = "Basic",
	energy_type: String = "P",
	hp: int = 100,
	evolves_from: String = "",
	mechanic: String = "",
	attacks: Array = [],
	retreat_cost: int = 1
) -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.name_en = pname
	cd.card_type = "Pokemon"
	cd.stage = stage
	cd.energy_type = energy_type
	cd.hp = hp
	cd.evolves_from = evolves_from
	cd.mechanic = mechanic
	cd.retreat_cost = retreat_cost
	cd.attacks.clear()
	for attack: Dictionary in attacks:
		cd.attacks.append(attack.duplicate(true))
	return cd


func _make_dragapult_ex_cd() -> CardData:
	return _make_pokemon_cd(
		"Dragapult ex",
		"Stage 2",
		"N",
		320,
		"Drakloak",
		"ex",
		[
			{"name": "Jet Head", "cost": "P", "damage": "70"},
			{"name": "Phantom Dive", "cost": "RP", "damage": "200", "text": "Put 6 damage counters on your opponent's Benched Pokemon in any way you like."},
		]
	)


func _make_charizard_ex_cd() -> CardData:
	var cd := _make_pokemon_cd(
		"Charizard ex",
		"Stage 2",
		"D",
		330,
		"Charmeleon",
		"ex",
		[
			{"name": "Burning Darkness", "cost": "RR", "damage": "180+", "text": "This attack does 30 more damage for each Prize card your opponent has taken."},
		]
	)
	cd.abilities.append({"name": "Infernal Reign", "text": "When you evolve this Pokemon from your hand, attach up to 3 Basic Fire Energy from your deck to your Pokemon."})
	return cd


func _make_trainer_cd(pname: String, card_type: String = "Item") -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.name_en = pname
	cd.card_type = card_type
	return cd


func _make_energy_cd(pname: String, provides: String) -> CardData:
	var cd := _make_trainer_cd(pname, "Basic Energy")
	cd.energy_provides = provides
	return cd


func _make_slot(card_data: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner))
	slot.turn_played = 0
	return slot


func _make_game_state(turn: int = 3) -> GameState:
	var gs := GameState.new()
	gs.turn_number = turn
	gs.current_player_index = 0
	gs.first_player_index = 0
	gs.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		player.active_pokemon = _make_slot(_make_pokemon_cd("Active%d" % pi, "Basic", "C", 100), pi)
		gs.players.append(player)
	return gs


func _attached_energy(name: String, provides: String) -> CardInstance:
	return CardInstance.create(_make_energy_cd(name, provides), 0)


func _activate_llm_queue(strategy: RefCounted, turn: int, queued_actions: Array) -> void:
	var catalog := {}
	for action: Dictionary in queued_actions:
		var action_id := str(action.get("id", action.get("action_id", "")))
		if action_id != "":
			catalog[action_id] = action
	strategy.set("_llm_queue_turn", turn)
	strategy.set("_llm_decision_tree", {"actions": queued_actions})
	strategy.set("_llm_action_queue", queued_actions)
	strategy.set("_llm_action_catalog", catalog)


func _attack_ref(index: int, name: String, damage: int) -> Dictionary:
	return {
		"id": "attack:%d" % index,
		"action_id": "attack:%d" % index,
		"type": "attack",
		"kind": "attack",
		"attack_index": index,
		"attack_name": name,
		"projected_damage": damage,
	}


func _tm_evolution_ref() -> Dictionary:
	return {
		"id": "granted_attack:tm_evolution",
		"action_id": "granted_attack:tm_evolution",
		"type": "granted_attack",
		"kind": "granted_attack",
		"attack_index": -1,
		"attack_name": "Evolution",
		"granted_attack_data": {"id": "tm_evolution", "name": "Evolution", "cost": "C", "damage": ""},
	}


func test_ready_dragapult_replaces_queued_jet_head_with_phantom_dive() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyDragapultCharizardLLM.gd should instantiate"
	var gs := _make_game_state(7)
	var player: PlayerState = gs.players[0]
	var dragapult := _make_slot(_make_dragapult_ex_cd(), 0)
	dragapult.attached_energy.append(_attached_energy("Fire Energy", "R"))
	dragapult.attached_energy.append(_attached_energy("Psychic Energy", "P"))
	player.active_pokemon = dragapult
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	var jet_head := _attack_ref(0, "Jet Head", 70)
	var phantom_dive := _attack_ref(1, "Phantom Dive", 200)
	_activate_llm_queue(strategy, int(gs.turn_number), [jet_head])
	strategy.set("_llm_action_catalog", {
		"attack:0": jet_head,
		"attack:1": phantom_dive,
	})
	var jet_score: float = float(strategy.call("score_action_absolute", jet_head, gs, 0))
	var phantom_score: float = float(strategy.call("score_action_absolute", phantom_dive, gs, 0))
	var preferred: Dictionary = strategy.call("_deck_preferred_terminal_attack_for", jet_head, gs, 0)
	return run_checks([
		assert_true(jet_score <= -1000.0, "Queued Jet Head should be blocked when Phantom Dive is ready"),
		assert_true(phantom_score >= 10000.0, "Ready Phantom Dive should replace a queued Jet Head plan"),
		assert_eq(int(preferred.get("attack_index", -1)), 1, "Terminal attack repair should prefer Phantom Dive"),
		assert_true(bool(strategy.call("_deck_queue_item_matches_action", jet_head, phantom_dive, gs, 0)), "Queue matching should allow Phantom Dive to satisfy the bad Jet Head queue"),
	])


func test_dragapult_phantom_dive_requires_fire_and_psychic_not_two_fire() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyDragapultCharizardLLM.gd should instantiate"
	var gs := _make_game_state(7)
	var player: PlayerState = gs.players[0]
	var dragapult := _make_slot(_make_dragapult_ex_cd(), 0)
	dragapult.attached_energy.append(_attached_energy("Fire Energy", "R"))
	dragapult.attached_energy.append(_attached_energy("Fire Energy", "R"))
	player.active_pokemon = dragapult
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	var jet_head := _attack_ref(0, "Jet Head", 70)
	var phantom_dive := _attack_ref(1, "Phantom Dive", 200)
	_activate_llm_queue(strategy, int(gs.turn_number), [jet_head])
	strategy.set("_llm_action_catalog", {
		"attack:0": jet_head,
		"attack:1": phantom_dive,
	})
	var preferred: Dictionary = strategy.call("_deck_preferred_terminal_attack_for", jet_head, gs, 0)
	return run_checks([
		assert_false(bool(strategy.call("_is_dragapult_phantom_dive_attack_action", phantom_dive, gs, 0)), "Phantom Dive must require Fire plus Psychic, not just two attached Energy"),
		assert_false(bool(strategy.call("_active_dragapult_pressure_ready", gs, 0)), "Dragapult pressure should not be ready with Fire+Fire"),
		assert_true(preferred.is_empty(), "Jet Head should not be repaired into an illegal Phantom Dive when Psychic is missing"),
	])


func test_payload_marks_jet_head_low_and_adds_phantom_route() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyDragapultCharizardLLM.gd should instantiate"
	var gs := _make_game_state(8)
	var player: PlayerState = gs.players[0]
	var dragapult := _make_slot(_make_dragapult_ex_cd(), 0)
	dragapult.attached_energy.append(_attached_energy("Fire Energy", "R"))
	dragapult.attached_energy.append(_attached_energy("Psychic Energy", "P"))
	player.active_pokemon = dragapult
	var poffin := CardInstance.create(_make_trainer_cd("Buddy-Buddy Poffin"), 0)
	player.hand.append(poffin)
	var payload: Dictionary = strategy.call("build_action_id_request_payload_for_test", gs, 0, [
		{"kind": "attack", "attack_index": 0, "attack_name": "Jet Head", "projected_damage": 70},
		{"kind": "attack", "attack_index": 1, "attack_name": "Phantom Dive", "projected_damage": 200},
		{"kind": "play_trainer", "card": poffin},
		{"kind": "end_turn"},
	])
	var facts: Dictionary = payload.get("turn_tactical_facts", {}) if payload.get("turn_tactical_facts", {}) is Dictionary else {}
	var policy: Dictionary = facts.get("dragapult_charizard_attack_policy", {}) if facts.get("dragapult_charizard_attack_policy", {}) is Dictionary else {}
	var jet_id := str(policy.get("jet_head_action_id", ""))
	var quality_by_id: Dictionary = facts.get("attack_quality_by_action_id", {}) if facts.get("attack_quality_by_action_id", {}) is Dictionary else {}
	var jet_quality: Dictionary = quality_by_id.get(jet_id, {}) if quality_by_id.get(jet_id, {}) is Dictionary else {}
	var has_phantom_route := false
	for raw_route: Variant in payload.get("candidate_routes", []):
		if raw_route is Dictionary and str((raw_route as Dictionary).get("route_action_id", "")) == "route:dragapult_charizard_phantom_dive":
			has_phantom_route = true
			break
	return run_checks([
		assert_true(bool(policy.get("phantom_dive_ready", false)), "Payload should expose ready Phantom Dive"),
		assert_true(bool(policy.get("jet_head_forbidden", false)), "Payload should mark Jet Head forbidden while Phantom Dive is ready"),
		assert_eq(str(jet_quality.get("terminal_priority", "")), "low", "Jet Head should be exposed as low-priority terminal damage"),
		assert_true(has_phantom_route, "Payload should expose a deck-local Phantom Dive candidate route"),
	])


func test_primary_engine_route_prefers_intent_best_manual_attach() -> String:
	var builder := RouteBuilderScript.new()
	var actions: Array[Dictionary] = [
		{
			"id": "play_trainer:energy_search",
			"action_id": "play_trainer:energy_search",
			"type": "play_trainer",
			"kind": "play_trainer",
			"card": "Energy Search",
			"card_rules": {"tags": ["search_deck", "energy_related"]},
		},
		{
			"id": "attach_energy:fire:active",
			"action_id": "attach_energy:fire:active",
			"type": "attach_energy",
			"kind": "attach_energy",
			"card": "Fire Energy",
			"energy_type": "R",
			"position": "active",
		},
		{
			"id": "attach_energy:psychic:active",
			"action_id": "attach_energy:psychic:active",
			"type": "attach_energy",
			"kind": "attach_energy",
			"card": "Psychic Energy",
			"energy_type": "P",
			"position": "active",
		},
		{"id": "end_turn", "action_id": "end_turn", "type": "end_turn", "kind": "end_turn"},
	]
	var future_actions: Array[Dictionary] = [{
		"id": "future:attack_after_visible_engine:active:1:Phantom_Dive",
		"action_id": "future:attack_after_visible_engine:active:1:Phantom_Dive",
		"type": "attack",
		"kind": "attack",
		"future": true,
		"attack_name": "Phantom Dive",
		"attack_quality": {"role": "primary_damage", "terminal_priority": "high"},
	}]
	var routes: Array = builder.call("build_candidate_routes", actions, future_actions, {
		"primary_attack_reachable_after_visible_engine": true,
		"primary_attack_missing_cost": ["Fire", "Psychic"],
		"best_manual_attach_energy_for_active_attack": "Fire",
		"intent_summary": {
			"best_manual_attach": {
				"action_id": "attach_energy:psychic:active",
				"target_position": "active",
				"marginal_value": "high",
			},
		},
	})
	var primary_route: Dictionary = {}
	for raw_route: Variant in routes:
		if raw_route is Dictionary and str((raw_route as Dictionary).get("route_action_id", "")) == "route:primary_visible_engine":
			primary_route = raw_route as Dictionary
			break
	var route_ids: Array[String] = []
	for raw_action: Variant in primary_route.get("actions", []):
		if raw_action is Dictionary:
			route_ids.append(str((raw_action as Dictionary).get("action_id", (raw_action as Dictionary).get("id", ""))))
	return run_checks([
		assert_false(primary_route.is_empty(), "Primary engine route should be generated"),
		assert_true(route_ids.has("attach_energy:psychic:active"), "Primary route should use the intent planner's exact best Psychic attach"),
		assert_false(route_ids.has("attach_energy:fire:active"), "Primary route should not fall back to Fire when intent marks Psychic as best"),
	])


func test_charizard_acceleration_blocks_nonfinal_attack() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyDragapultCharizardLLM.gd should instantiate"
	var gs := _make_game_state(10)
	var player: PlayerState = gs.players[0]
	var active_charizard := _make_slot(_make_charizard_ex_cd(), 0)
	active_charizard.attached_energy.append(_attached_energy("Fire Energy", "R"))
	active_charizard.attached_energy.append(_attached_energy("Fire Energy", "R"))
	player.active_pokemon = active_charizard
	var bench_charizard := _make_slot(_make_charizard_ex_cd(), 0)
	bench_charizard.turn_evolved = int(gs.turn_number)
	player.bench.append(bench_charizard)
	for i: int in 6:
		player.deck.append(_attached_energy("Fire Energy", "R"))
	for i: int in 4:
		player.prizes.append(CardInstance.create(_make_trainer_cd("Prize%d" % i), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230, "", "ex"), 1)
	var attack := _attack_ref(0, "Burning Darkness", 270)
	var ability := {
		"id": "use_ability:bench_0:0",
		"action_id": "use_ability:bench_0:0",
		"type": "use_ability",
		"kind": "use_ability",
		"source_slot": bench_charizard,
		"pokemon": "Charizard ex",
		"ability": "Infernal Reign",
		"ability_index": 0,
	}
	return run_checks([
		assert_true(bool(strategy.call("_should_block_attack_for_charizard_acceleration", attack, gs, 0)), "Non-final attack should wait for a pending Charizard ex acceleration ability"),
		assert_true(float(strategy.call("score_action_absolute", attack, gs, 0)) <= -1000.0, "Runtime scoring should block the premature attack"),
		assert_true(float(strategy.call("score_action_absolute", ability, gs, 0)) >= 80000.0, "Pending Charizard acceleration should outrank the queued attack plan"),
	])


func test_ultra_ball_policy_and_discard_fallback_preserve_key_supporters() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyDragapultCharizardLLM.gd should instantiate"
	var gs := _make_game_state(12)
	var player: PlayerState = gs.players[0]
	var ultra := CardInstance.create(_make_trainer_cd("Ultra Ball"), 0)
	var iono := CardInstance.create(_make_trainer_cd("Iono", "Supporter"), 0)
	var boss := CardInstance.create(_make_trainer_cd("Boss's Orders", "Supporter"), 0)
	var manaphy := CardInstance.create(_make_pokemon_cd("Manaphy", "Basic", "W", 70), 0)
	var temple := CardInstance.create(_make_trainer_cd("Temple of Sinnoh", "Stadium"), 0)
	player.hand.append_array([iono, boss, manaphy, temple, ultra])
	var payload: Dictionary = strategy.call("build_action_id_request_payload_for_test", gs, 0, [
		{"kind": "play_trainer", "card": ultra},
		{"kind": "end_turn"},
	])
	var ultra_policy: Dictionary = {}
	for raw_ref: Variant in payload.get("legal_actions", []):
		if raw_ref is Dictionary and str((raw_ref as Dictionary).get("id", "")).begins_with("play_trainer:"):
			ultra_policy = (raw_ref as Dictionary).get("selection_policy", {}) if (raw_ref as Dictionary).get("selection_policy", {}) is Dictionary else {}
	var iono_score := int(strategy.call("get_discard_priority_contextual", iono, gs, 0))
	var boss_score := int(strategy.call("get_discard_priority_contextual", boss, gs, 0))
	var manaphy_score := int(strategy.call("get_discard_priority_contextual", manaphy, gs, 0))
	var temple_score := int(strategy.call("get_discard_priority_contextual", temple, gs, 0))
	return run_checks([
		assert_false(ultra_policy.is_empty(), "Ultra Ball prompt refs should carry a selection_policy"),
		assert_true(ultra_policy.has("discard_cards"), "Ultra Ball policy should expose deterministic discard preferences"),
		assert_true(manaphy_score > iono_score, "Discard fallback should prefer expendable Manaphy over Iono"),
		assert_true(temple_score > boss_score, "Discard fallback should prefer expendable Stadium over Boss's Orders"),
	])


func test_spread_interaction_prefers_damaged_bench_prize_target() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyDragapultCharizardLLM.gd should instantiate"
	var gs := _make_game_state(9)
	var damaged_two_prizer := _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200, "", "V"), 1)
	damaged_two_prizer.damage_counters = 150
	var healthy_basic := _make_slot(_make_pokemon_cd("Bidoof", "Basic", "C", 70), 1)
	var context := {"game_state": gs, "player_index": 0}
	var damaged_score: float = float(strategy.call("score_interaction_target", damaged_two_prizer, {"id": "bench_damage_counters"}, context))
	var healthy_score: float = float(strategy.call("score_interaction_target", healthy_basic, {"id": "bench_damage_counters"}, context))
	var picked: Array = strategy.call("pick_interaction_items", [healthy_basic, damaged_two_prizer], {"id": "bench_damage_counters", "max_select": 1}, context)
	return run_checks([
		assert_true(damaged_score > healthy_score, "Phantom Dive counters should prefer the damaged bench prize target"),
		assert_true(not picked.is_empty() and picked[0] == damaged_two_prizer, "Interaction fallback should pick the damaged bench target"),
	])


func test_support_energy_only_allowed_for_active_retreat() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyDragapultCharizardLLM.gd should instantiate"
	var gs := _make_game_state(4)
	var player: PlayerState = gs.players[0]
	var manaphy_cd := _make_pokemon_cd("Manaphy", "Basic", "W", 70, "", "", [], 1)
	player.active_pokemon = _make_slot(manaphy_cd, 0)
	var dreepy := _make_slot(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0)
	var rotom := _make_slot(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0)
	player.bench.append(dreepy)
	player.bench.append(rotom)
	var fire := CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0)
	var active_support_attach := {"kind": "attach_energy", "card": fire, "target_slot": player.active_pokemon}
	var benched_support_attach := {"kind": "attach_energy", "card": fire, "target_slot": rotom}
	return run_checks([
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", {}, active_support_attach, gs, 0)), "Active support Energy should be allowed only to pay retreat into an attacker"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, benched_support_attach, gs, 0)), "Benched support Energy should stay blocked"),
	])


func test_active_dragapult_missing_fire_blocks_bench_fire_attach() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyDragapultCharizardLLM.gd should instantiate"
	var gs := _make_game_state(4)
	var player: PlayerState = gs.players[0]
	var active := _make_slot(_make_dragapult_ex_cd(), 0)
	active.attached_energy.append(_attached_energy("Psychic Energy", "P"))
	player.active_pokemon = active
	var charmander := _make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0)
	player.bench.append(charmander)
	var fire := CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0)
	var active_fire := {"kind": "attach_energy", "card": fire, "target_slot": active}
	var bench_fire := {"kind": "attach_energy", "card": fire, "target_slot": charmander}
	return run_checks([
		assert_false(bool(strategy.call("_deck_should_block_exact_queue_match", {}, active_fire, gs, 0)), "Fire should be allowed on active Dragapult ex when it completes Phantom Dive"),
		assert_true(bool(strategy.call("_deck_should_block_exact_queue_match", {}, bench_fire, gs, 0)), "Bench Fire should be blocked while active Dragapult ex is missing Fire"),
	])


func test_setup_repair_inserts_poffin_before_nonfinal_phantom_dive() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyDragapultCharizardLLM.gd should instantiate"
	var gs := _make_game_state(5)
	var player: PlayerState = gs.players[0]
	var dragapult := _make_slot(_make_dragapult_ex_cd(), 0)
	dragapult.attached_energy.append(_attached_energy("Fire Energy", "R"))
	dragapult.attached_energy.append(_attached_energy("Psychic Energy", "P"))
	player.active_pokemon = dragapult
	player.hand.append(CardInstance.create(_make_trainer_cd("Buddy-Buddy Poffin"), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	var poffin_ref := {
		"id": "play_trainer:poffin",
		"action_id": "play_trainer:poffin",
		"type": "play_trainer",
		"kind": "play_trainer",
		"card": "Buddy-Buddy Poffin",
	}
	var attack_ref := _attack_ref(1, "Phantom Dive", 200)
	strategy.set("_llm_action_catalog", {
		"play_trainer:poffin": poffin_ref,
		"attack:1": attack_ref,
	})
	var repair: Dictionary = strategy.call("_repair_missing_productive_engine_in_tree", {"actions": [attack_ref]}, gs, 0)
	var repaired_tree: Dictionary = repair.get("tree", {}) if repair.get("tree", {}) is Dictionary else {}
	var actions: Array = repaired_tree.get("actions", []) if repaired_tree.get("actions", []) is Array else []
	return run_checks([
		assert_true(actions.size() >= 2, "Repair should add safe setup before a non-final Phantom Dive"),
		assert_eq(str((actions[0] as Dictionary).get("action_id", "")), "play_trainer:poffin", "Poffin should be inserted before non-final Phantom Dive"),
		assert_eq(str((actions[actions.size() - 1] as Dictionary).get("action_id", "")), "attack:1", "Phantom Dive should remain terminal after setup repair"),
	])


func test_tm_evolution_granted_attack_replaces_opening_chip_attack() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyDragapultCharizardLLM.gd should instantiate"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	var active := _make_slot(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0)
	active.attached_energy.append(_attached_energy("Psychic Energy", "P"))
	player.active_pokemon = active
	player.bench.append(_make_slot(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0))
	player.bench.append(_make_slot(_make_pokemon_cd("Charmander", "Basic", "R", 70), 0))
	player.deck.append(CardInstance.create(_make_pokemon_cd("Drakloak", "Stage 1", "N", 90, "Dreepy"), 0))
	player.deck.append(CardInstance.create(_make_pokemon_cd("Charmeleon", "Stage 1", "R", 90, "Charmander"), 0))
	var chip := _attack_ref(0, "Little Grudge", 10)
	var tm := _tm_evolution_ref()
	tm["source_slot"] = active
	_activate_llm_queue(strategy, int(gs.turn_number), [chip])
	strategy.set("_llm_action_catalog", {
		"attack:0": chip,
		"granted_attack:tm_evolution": tm,
	})
	var chip_score: float = float(strategy.call("score_action_absolute", chip, gs, 0))
	var tm_score: float = float(strategy.call("score_action_absolute", tm, gs, 0))
	var preferred: Dictionary = strategy.call("_deck_preferred_terminal_attack_for", chip, gs, 0)
	return run_checks([
		assert_true(chip_score <= -1000.0, "Opening chip attack should be blocked when TM Evolution can evolve two seeds"),
		assert_true(tm_score >= 900.0, "TM Evolution granted attack should outrank fallback actions after the low-value chip attack is blocked"),
		assert_eq(str(preferred.get("action_id", preferred.get("id", ""))), "granted_attack:tm_evolution", "Terminal repair should prefer TM Evolution"),
		assert_true(bool(strategy.call("_deck_queue_item_matches_action", chip, tm, gs, 0)), "Queue matching should allow TM Evolution to replace the chip attack"),
	])
