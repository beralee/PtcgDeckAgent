class_name TestV18DragapultFamilyStrategy
extends TestBase


const STRATEGY_PATH := "res://scripts/ai/DeckStrategyV18DragapultFamily.gd"
const V18_RULES_PATH := "res://scripts/ai/DeckStrategyV18Rules.gd"
const DECK_DIR := "res://data/bundled_user/decks"
const FIXED_ORDER_DIR := "res://data/bundled_user/ai_fixed_deck_orders"
const RADIANT_ALAKAZAM_EFFECT_ID := "68244d82147e13bb7d77116ffedf6162"
const CHI_YU_EFFECT_ID := "4e1e775eaafb11028f5378ede92cb964"

const FAMILY_DECK_IDS: Array[int] = [
	18000230,
	800015734,
	800018499,
	800019125,
]

const PARTNER_OPENING_NAMES := {
	18000230: "小火龙",
	800015734: "夜巡灵",
	800018499: "愿增猿",
	800019125: "火稚鸡",
}

const STRONG_ACTIVE_NAMES := {
	18000230: "多龙梅西亚",
	800015734: "含羞苞",
	800018499: "含羞苞",
	800019125: "含羞苞",
}


func test_dragapult_family_delegate_exposes_the_v18_contract_for_all_four_decks() -> String:
	var checks: Array[String] = []
	for deck_id: int in FAMILY_DECK_IDS:
		var strategy := _new_strategy(deck_id)
		checks.append(assert_not_null(strategy, "Dragapult family delegate should instantiate for deck %d" % deck_id))
		if strategy == null:
			continue
		var state := _make_state()
		state.players[0].active_pokemon = _slot(_card("CSV9.5C", "004"))
		state.players[0].bench.append(_slot(_card("CSV8C", "157")))
		var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {"prompt_kind": "action_selection"})
		checks.append(assert_eq(
			str(strategy.call("get_strategy_id")),
			"v18_dragapult_family_%d" % deck_id,
			"Each configured family delegate should retain its exact deck identity"
		))
		checks.append(assert_eq(str(plan.get("phase", "")), "launch", "A seeded Dreepy line should be in launch phase"))
		checks.append(assert_true(plan.get("owner", {}) is Dictionary, "The plan should expose owner continuity"))
		checks.append(assert_true(plan.get("priorities", {}) is Dictionary, "The plan should expose V18 priorities"))
		checks.append(assert_true(plan.get("constraints", {}) is Dictionary, "The plan should expose V18 safety constraints"))
	return run_checks(checks)


func test_dragapult_family_strong_openings_keep_the_declared_pivot_and_both_routes() -> String:
	var checks: Array[String] = []
	for deck_id: int in FAMILY_DECK_IDS:
		var strategy := _new_strategy(deck_id)
		var player := _fixed_opening_player(deck_id)
		checks.append(assert_not_null(strategy, "Deck %d should configure the family delegate" % deck_id))
		checks.append(assert_not_null(player, "Deck %d should load its fixed opening hand" % deck_id))
		if strategy == null or player == null:
			continue
		var plan: Dictionary = strategy.call("plan_opening_setup", player)
		var active_index := int(plan.get("active_hand_index", -1))
		var bench_indices: Array = plan.get("bench_hand_indices", [])
		checks.append(assert_eq(
			_hand_name(player, active_index),
			str(STRONG_ACTIVE_NAMES[deck_id]),
			"Deck %d should preserve its declared strong-opening pivot" % deck_id
		))
		checks.append(assert_true(_bench_contains(player, bench_indices, "多龙梅西亚"), "Deck %d should Bench its Dreepy seed" % deck_id))
		checks.append(assert_true(
			_bench_contains(player, bench_indices, str(PARTNER_OPENING_NAMES[deck_id])),
			"Deck %d should Bench its partner route instead of exposing it Active" % deck_id
		))
	return run_checks(checks)


func test_dragapult_family_uses_manual_first_player_setup_and_tm_second_player_launch() -> String:
	var strategy := _new_strategy(800019125)
	if strategy == null:
		return "Blaziken/Dragapult delegate should instantiate"
	var state := _make_state()
	state.turn_number = 1
	state.first_player_index = 0
	var player := state.players[0]
	var budew := _slot(_card("CSV9.5C", "004"))
	var dreepy := _slot(_card("CSV8C", "157"))
	var torchic := _slot(_card("CSV10C", "036"))
	player.active_pokemon = budew
	player.bench.assign([dreepy, torchic])
	player.deck.append(CardInstance.create(_card("CSV8C", "158"), 0))
	player.deck.append(CardInstance.create(_card("CSV10C", "037"), 0))
	var tm := CardInstance.create(_card("CSV5C", "119"), 0)
	var fire := CardInstance.create(_energy("基本火能量", "R"), 0)
	var first_plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	var first_tm_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attach_tool", "card": tm, "target_slot": budew,
	}, state, 0, first_plan)
	var first_dreepy_energy: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attach_energy", "card": fire, "target_slot": dreepy,
	}, state, 0, first_plan)

	state.turn_number = 2
	state.first_player_index = 1
	var second_plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	var second_tm_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attach_tool", "card": tm, "target_slot": budew,
	}, state, 0, second_plan)
	budew.attached_tool = tm
	budew.attached_energy.append(fire)
	var evolution_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "granted_attack",
		"source_slot": budew,
		"granted_attack_data": {"id": "tm_evolution", "name": "进化", "cost": "C", "damage": ""},
	}, state, 0, second_plan)
	var chip_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attack", "source_slot": budew, "attack_index": 0, "projected_damage": 10,
	}, state, 0, second_plan)
	return run_checks([
		assert_eq(str(first_plan.get("flags", {}).get("opening_route", "")), "first_player_manual_chain", "Going first should preserve the manual evolution route"),
		assert_true(first_tm_score <= -1800.0, "Going first must not expose TM Evolution before attacks are legal (score=%f)" % first_tm_score),
		assert_true(first_dreepy_energy >= 1200.0, "Going first should still pre-charge Dreepy's Fire/Psychic route (score=%f)" % first_dreepy_energy),
		assert_eq(str(second_plan.get("flags", {}).get("opening_route", "")), "second_player_tm_evolution", "Going second should declare the TM Evolution route"),
		assert_true(second_tm_score >= first_tm_score + 3000.0, "Going second should attach TM to the powered Active pivot"),
		assert_true(evolution_score >= chip_score + 2500.0, "TM Evolution should replace Budew chip damage while both Stage 2 lanes are seeded"),
	])


func test_dragapult_family_without_tm_uses_manual_second_player_pressure() -> String:
	var checks: Array[String] = []
	for deck_id: int in [800015734, 800018499]:
		var strategy := _new_strategy(deck_id)
		var state := _make_state()
		state.turn_number = 2
		state.first_player_index = 1
		state.players[0].active_pokemon = _slot(_card("CSV9.5C", "004"))
		state.players[0].bench.append(_slot(_card("CSV8C", "157")))
		var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {}) if strategy != null else {}
		checks.append(assert_eq(
			str(plan.get("flags", {}).get("opening_route", "")),
			"second_player_manual_pressure",
			"Deck %d has no TM Evolution and should use manual second-player pressure" % deck_id
		))
	return run_checks(checks)


func test_dragapult_family_searches_the_playable_next_stage_and_uses_candy_only_when_live() -> String:
	var strategy := _new_strategy(800019125)
	if strategy == null:
		return "Blaziken/Dragapult delegate should instantiate"
	var state := _make_state()
	var player := state.players[0]
	var dreepy := _slot(_card("CSV8C", "157"))
	var torchic := _slot(_card("CSV10C", "036"))
	player.active_pokemon = dreepy
	player.bench.append(torchic)
	var drakloak := CardInstance.create(_card("CSV8C", "158"), 0)
	var dragapult := CardInstance.create(_card("CSV8C", "159"), 0)
	var combusken := CardInstance.create(_card("CSV10C", "037"), 0)
	var blaziken := CardInstance.create(_card("CSV7C", "038"), 0)
	var context := {"game_state": state, "player_index": 0}
	var step := {"id": "search_pokemon", "max_select": 1}
	var drakloak_without_candy: float = strategy.call("score_interaction_target", drakloak, step, context)
	var dragapult_without_candy: float = strategy.call("score_interaction_target", dragapult, step, context)
	var combusken_without_candy: float = strategy.call("score_interaction_target", combusken, step, context)
	var blaziken_without_candy: float = strategy.call("score_interaction_target", blaziken, step, context)
	player.hand.append(CardInstance.create(_card("CSVH1C", "045"), 0))
	var dragapult_with_candy: float = strategy.call("score_interaction_target", dragapult, step, context)
	return run_checks([
		assert_true(drakloak_without_candy >= dragapult_without_candy + 1000.0, "Without Rare Candy, search should fetch playable Drakloak before dead Dragapult ex"),
		assert_true(combusken_without_candy >= blaziken_without_candy + 700.0, "Without Rare Candy, the partner line should fetch Combusken before dead Blaziken ex"),
		assert_true(dragapult_with_candy >= drakloak_without_candy, "A live Rare Candy route should promote Dragapult ex to an immediate launch piece"),
	])


func test_dragapult_family_rare_candy_target_must_match_selected_stage2() -> String:
	var strategy := _new_strategy(800019125)
	if strategy == null:
		return "Blaziken/Dragapult delegate should instantiate"
	var state := _make_state()
	var player := state.players[0]
	var dreepy := _slot(_card("CSV8C", "157"))
	var torchic := _slot(_card("CSV10C", "036"))
	player.active_pokemon = dreepy
	player.bench.append(torchic)
	var dragapult := CardInstance.create(_card("CSV8C", "159"), 0)
	var blaziken := CardInstance.create(_card("CSV7C", "038"), 0)
	var step := {"id": "target_pokemon", "max_select": 1}
	var dragapult_context := {
		"game_state": state,
		"player_index": 0,
		"stage2_card": [dragapult],
	}
	var blaziken_context := {
		"game_state": state,
		"player_index": 0,
		"stage2_card": [blaziken],
	}
	var dragapult_dreepy_score: float = strategy.call("score_interaction_target", dreepy, step, dragapult_context)
	var dragapult_torchic_score: float = strategy.call("score_interaction_target", torchic, step, dragapult_context)
	var blaziken_torchic_score: float = strategy.call("score_interaction_target", torchic, step, blaziken_context)
	var blaziken_dreepy_score: float = strategy.call("score_interaction_target", dreepy, step, blaziken_context)
	return run_checks([
		assert_true(dragapult_dreepy_score >= dragapult_torchic_score + 5000.0, "Rare Candy must pair selected Dragapult ex with Dreepy"),
		assert_true(blaziken_torchic_score >= blaziken_dreepy_score + 5000.0, "Rare Candy must pair selected Blaziken ex with Torchic"),
	])


func test_dragapult_family_completes_fire_psychic_cost_without_overattaching() -> String:
	var strategy := _new_strategy(800018499)
	if strategy == null:
		return "Pure Dragapult delegate should instantiate"
	var state := _make_state()
	var dragapult := _slot(_card("CSV8C", "159"))
	state.players[0].active_pokemon = dragapult
	dragapult.attached_energy.append(CardInstance.create(_energy("基本火能量", "R"), 0))
	var fire := CardInstance.create(_energy("基本火能量", "R"), 0)
	var psychic := CardInstance.create(_energy("基本超能量", "P"), 0)
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	var psychic_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attach_energy", "card": psychic, "target_slot": dragapult,
	}, state, 0, plan)
	var duplicate_fire_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attach_energy", "card": fire, "target_slot": dragapult,
	}, state, 0, plan)
	dragapult.attached_energy.append(psychic)
	var overattach_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "attach_energy", "card": fire, "target_slot": dragapult,
	}, state, 0, plan)
	return run_checks([
		assert_true(psychic_score >= duplicate_fire_score + 1200.0, "A Fire-funded Dragapult should receive Psychic before duplicate Fire"),
		assert_true(overattach_score <= duplicate_fire_score, "A complete RP Dragapult should not absorb Energy needed by its backup"),
	])


func test_dragapult_family_real_luminous_energy_flexes_and_powers_real_munkidori() -> String:
	var strategy := _new_strategy(800018499)
	if strategy == null:
		return "Pure Dragapult delegate should instantiate"
	var state := _make_state()
	var player := state.players[0]
	var opponent := state.players[1]
	var dragapult := _slot(_card("CSV8C", "159"))
	dragapult.damage_counters = 30
	dragapult.attached_energy.append(CardInstance.create(_card("CSV1C", "127"), 0))
	var munkidori := _slot(_card("CSV8C", "094"))
	player.active_pokemon = dragapult
	player.bench.append(munkidori)
	opponent.active_pokemon = _slot(_pokemon("Counter target", 120), 1)
	var psychic := CardInstance.create(_card("CSVE1C", "PSY"), 0)
	var fire := CardInstance.create(_card("CSVE1C", "FIR"), 0)
	var luminous := CardInstance.create(_card("CSV1C", "127"), 0)
	var psychic_completion_score: float = strategy.call("score_action_absolute", {
		"kind": "attach_energy", "card": psychic, "target_slot": dragapult,
	}, state, 0)
	var luminous_munkidori_score: float = strategy.call("score_action_absolute", {
		"kind": "attach_energy", "card": luminous, "target_slot": munkidori,
	}, state, 0)
	var fire_munkidori_score: float = strategy.call("score_action_absolute", {
		"kind": "attach_energy", "card": fire, "target_slot": munkidori,
	}, state, 0)
	munkidori.attached_energy.append(luminous)
	var munkidori_ability_score: float = strategy.call("score_action_absolute", {
		"kind": "use_ability", "source_slot": munkidori, "ability_index": 0,
	}, state, 0)
	return run_checks([
		assert_true(psychic_completion_score >= 4500.0, "Real Luminous Energy should flex to Fire when real Psychic Energy completes Dragapult's RP cost"),
		assert_true(luminous_munkidori_score >= fire_munkidori_score + 3000.0, "Real Luminous Energy should provide Darkness for real Munkidori while it is the only Special Energy"),
		assert_true(munkidori_ability_score >= 2000.0, "Real Munkidori should prioritize Adrena-Brain after Luminous Energy powers its Darkness requirement"),
	])


func test_dragapult_charizard_infernal_reign_fills_one_fire_gap_then_changes_target() -> String:
	var strategy := _new_strategy(18000230)
	if strategy == null:
		return "Charizard/Dragapult delegate should instantiate"
	var state := _make_state()
	var player := state.players[0]
	var dragapult := _slot(_card("CSV8C", "159"))
	dragapult.attached_energy.append(CardInstance.create(_energy("基本超能量", "P"), 0))
	var charizard := _slot(_card("CSV5C", "075"))
	player.active_pokemon = dragapult
	player.bench.append(charizard)
	var first_fire := CardInstance.create(_energy("基本火能量", "R"), 0)
	var second_fire := CardInstance.create(_energy("基本火能量", "R"), 0)
	var step := {"id": "energy_assignments", "max_select": 3}
	var first_context := {"game_state": state, "player_index": 0, "source_card": first_fire}
	var first_dragapult_score: float = strategy.call("score_interaction_target", dragapult, step, first_context)
	var pending_context := {
		"game_state": state,
		"player_index": 0,
		"source_card": second_fire,
		"pending_assignments": [{"source": first_fire, "target": dragapult}],
	}
	var duplicate_dragapult_score: float = strategy.call("score_interaction_target", dragapult, step, pending_context)
	var charizard_score: float = strategy.call("score_interaction_target", charizard, step, pending_context)
	return run_checks([
		assert_true(first_dragapult_score >= charizard_score + 2000.0, "Infernal Reign should first fill Dragapult's missing Fire cost"),
		assert_true(charizard_score >= duplicate_dragapult_score + 2000.0, "After that Fire is pending, Infernal Reign should fund Charizard instead of overattaching Dragapult"),
	])


func test_dragapult_charizard_prioritizes_real_infernal_reign() -> String:
	var strategy := _new_strategy(18000230)
	if strategy == null:
		return "Charizard/Dragapult delegate should instantiate"
	var state := _make_state()
	var player := state.players[0]
	var opponent := state.players[1]
	var dragapult := _slot(_card("CSV8C", "159"))
	dragapult.damage_counters = 20
	dragapult.attached_energy.append(CardInstance.create(_card("CSVE1C", "PSY"), 0))
	var charizard := _slot(_card("CSV5C", "075"))
	var munkidori := _slot(_card("CSV8C", "094"))
	player.active_pokemon = dragapult
	player.bench.assign([charizard, munkidori])
	player.deck.append(CardInstance.create(_card("CSVE1C", "FIR"), 0))
	opponent.active_pokemon = _slot(_pokemon("Ability target", 220, "ex"), 1)
	var infernal_reign_score: float = strategy.call("score_action_absolute", {
		"kind": "use_ability", "source_slot": charizard, "ability_index": 0,
	}, state, 0)
	var munkidori_score: float = strategy.call("score_action_absolute", {
		"kind": "use_ability", "source_slot": munkidori, "ability_index": 0,
	}, state, 0)
	return run_checks([
		assert_true(infernal_reign_score >= 5000.0, "Infernal Reign should be a priority action while basic Fire remains in deck"),
		assert_true(infernal_reign_score >= munkidori_score + 1000.0, "Infernal Reign should establish the attack route before secondary damage movement"),
	])


func test_dragapult_dusknoir_preattaches_real_crystal_and_routes_forest_seal_to_pokemon_v() -> String:
	var strategy := _new_strategy(800015734)
	if strategy == null:
		return "Dusknoir/Dragapult delegate should instantiate"
	var state := _make_state()
	var player := state.players[0]
	var dreepy := _slot(_card("CSV8C", "157"))
	dreepy.attached_energy.append(CardInstance.create(_card("CSVE1C", "FIR"), 0))
	var rotom := _slot(_card("CS6.5C", "023"))
	player.active_pokemon = dreepy
	player.bench.append(rotom)
	player.deck.append(CardInstance.create(_card("CSVH1C", "045"), 0))
	var crystal := CardInstance.create(_card("CSV8C", "186"), 0)
	var forest_seal := CardInstance.create(_card("CS6.5C", "066"), 0)
	var crystal_dreepy_score: float = strategy.call("score_action_absolute", {
		"kind": "attach_tool", "card": crystal, "target_slot": dreepy,
	}, state, 0)
	var crystal_rotom_score: float = strategy.call("score_action_absolute", {
		"kind": "attach_tool", "card": crystal, "target_slot": rotom,
	}, state, 0)
	var forest_rotom_score: float = strategy.call("score_action_absolute", {
		"kind": "attach_tool", "card": forest_seal, "target_slot": rotom,
	}, state, 0)
	var forest_dreepy_score: float = strategy.call("score_action_absolute", {
		"kind": "attach_tool", "card": forest_seal, "target_slot": dreepy,
	}, state, 0)
	return run_checks([
		assert_true(crystal_dreepy_score >= crystal_rotom_score + 5000.0, "Sparkling Crystal should preattach to the funded Dreepy line before it evolves into Dragapult ex"),
		assert_true(forest_rotom_score >= forest_dreepy_score + 5000.0, "Forest Seal Stone should attach to real Rotom V, not a non-V Dragapult seed"),
	])


func test_dragapult_family_converts_damage_counters_into_exact_prizes() -> String:
	var strategy := _new_strategy(800015734)
	if strategy == null:
		return "Dusknoir/Dragapult delegate should instantiate"
	var state := _make_state()
	var player := state.players[0]
	var opponent := state.players[1]
	var dragapult := _slot(_card("CSV8C", "159"))
	dragapult.attached_energy.assign([
		CardInstance.create(_energy("基本火能量", "R"), 0),
		CardInstance.create(_energy("基本超能量", "P"), 0),
	])
	var dusknoir := _slot(_card("CSV8C", "083"))
	player.active_pokemon = dragapult
	player.bench.append(dusknoir)
	var exact_two_prize := _slot(_pokemon("Loaded ex", 250, "ex"), 1)
	exact_two_prize.damage_counters = 120
	var one_prize := _slot(_pokemon("Small support", 100), 1)
	one_prize.damage_counters = 40
	opponent.active_pokemon = exact_two_prize
	opponent.bench.append(one_prize)
	var context := {"game_state": state, "player_index": 0, "source_slot": dusknoir}
	var exact_score: float = strategy.call("score_interaction_target", exact_two_prize, {"id": "self_ko_target"}, context)
	var support_score: float = strategy.call("score_interaction_target", one_prize, {"id": "self_ko_target"}, context)
	var ability_score: float = strategy.call("score_action_absolute_with_plan", {
		"kind": "use_ability", "source_slot": dusknoir, "ability_index": 0,
	}, state, 0, strategy.call("build_turn_plan", state, 0, {}))
	var bench_exact_score: float = strategy.call("score_interaction_target", one_prize, {"id": "bench_damage_counters"}, context)
	var healthy_bench := _slot(_pokemon("Healthy ex", 280, "ex"), 1)
	var healthy_score: float = strategy.call("score_interaction_target", healthy_bench, {"id": "bench_damage_counters"}, context)
	return run_checks([
		assert_true(exact_score >= support_score + 500.0, "Dusknoir should self-KO for the exact two-prize conversion before a one-prize target"),
		assert_true(ability_score >= 2500.0, "Curse Blast should execute when it creates an exact two-prize knockout (score=%f)" % ability_score),
		assert_true(bench_exact_score >= healthy_score + 500.0, "Phantom Dive counters should take an exact Bench knockout before speculative spread"),
	])


func test_dragapult_family_routes_munkidori_damage_from_attacker_to_exact_target() -> String:
	var strategy := _new_strategy(800018499)
	if strategy == null:
		return "Pure Dragapult delegate should instantiate"
	var state := _make_state()
	var player := state.players[0]
	var opponent := state.players[1]
	var dragapult := _slot(_card("CSV8C", "159"))
	dragapult.damage_counters = 40
	var support := _slot(_pokemon("Support", 100))
	support.damage_counters = 30
	var munkidori := _slot(_card("CSV8C", "094"))
	player.active_pokemon = dragapult
	player.bench.assign([support, munkidori])
	var exact_target := _slot(_pokemon("Three-counter target", 120), 1)
	exact_target.damage_counters = 90
	var healthy_target := _slot(_pokemon("Healthy target", 180), 1)
	opponent.active_pokemon = healthy_target
	opponent.bench.append(exact_target)
	var context := {"game_state": state, "player_index": 0}
	var attacker_source_score: float = strategy.call("score_interaction_target", dragapult, {"id": "source_pokemon"}, context)
	var support_source_score: float = strategy.call("score_interaction_target", support, {"id": "source_pokemon"}, context)
	var exact_target_score: float = strategy.call("score_interaction_target", exact_target, {"id": "target_damage_counters"}, context)
	var healthy_target_score: float = strategy.call("score_interaction_target", healthy_target, {"id": "target_damage_counters"}, context)
	return run_checks([
		assert_true(attacker_source_score >= support_source_score + 500.0, "Adrena-Brain should heal the damaged primary attacker before a disposable support"),
		assert_true(exact_target_score >= healthy_target_score + 700.0, "Moved counters should complete an exact knockout before speculative damage"),
	])


func test_dragapult_dusknoir_uses_real_radiant_alakazam_move_steps() -> String:
	var strategy := _new_strategy(800015734)
	if strategy == null:
		return "Dragapult/Dusknoir delegate should instantiate"
	var state := _make_state()
	var alakazam_data := _card("CS6bC", "028")
	if alakazam_data == null:
		return "CS6bC_028 Radiant Alakazam should load"
	var alakazam := _slot(alakazam_data)
	state.players[0].active_pokemon = alakazam
	var donor := _slot(_pokemon("Safe donor", 300), 1)
	donor.damage_counters = 80
	var exact_target := _slot(_pokemon("Exact twenty target", 120), 1)
	exact_target.damage_counters = 100
	var healthy_target := _slot(_pokemon("Healthy target", 220), 1)
	state.players[1].active_pokemon = donor
	state.players[1].bench.assign([exact_target, healthy_target])
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(alakazam_data)
	var effect: BaseEffect = processor.get_ability_effect(alakazam, 0, state)
	if effect == null:
		return "Radiant Alakazam should register its real ability effect"
	var steps: Array[Dictionary] = effect.get_interaction_steps(alakazam.get_top_card(), state)
	if steps.size() != 3:
		return "Radiant Alakazam should expose its three real interaction steps"
	var context := {
		"game_state": state,
		"player_index": 0,
		"pending_effect_card": alakazam.get_top_card(),
	}
	var source_pick: Array = strategy.call("pick_interaction_items", steps[0].get("items", []), steps[0], context)
	var target_items: Array = steps[1].get("items", []).duplicate()
	if not source_pick.is_empty():
		target_items.erase(source_pick[0])
		context["source_pokemon"] = [source_pick[0]]
	var target_pick: Array = strategy.call("pick_interaction_items", target_items, steps[1], context)
	var count_pick: Array = strategy.call("pick_interaction_items", steps[2].get("items", []), steps[2], context)
	return run_checks([
		assert_eq(str(alakazam_data.effect_id), RADIANT_ALAKAZAM_EFFECT_ID, "The real effect ID should identify Radiant Alakazam"),
		assert_eq(str(steps[0].get("id", "")), "source_pokemon", "Painful Spoons should first choose a damaged source"),
		assert_eq(str(steps[1].get("id", "")), "target_pokemon", "Painful Spoons should then choose a distinct destination"),
		assert_eq(str(steps[2].get("id", "")), "counter_count", "Painful Spoons should choose how many counters to move"),
		assert_eq(source_pick, [donor], "Painful Spoons should preserve an exact prize and move surplus damage from the safe donor"),
		assert_eq(target_pick, [exact_target], "Painful Spoons should move damage onto the exact twenty-damage prize"),
		assert_eq(count_pick, [2], "Painful Spoons should move both counters when twenty damage converts the prize"),
	])


func test_dragapult_blaziken_uses_real_chi_yu_fire_recovery_route() -> String:
	var strategy := _new_strategy(800019125)
	if strategy == null:
		return "Blaziken/Dragapult delegate should instantiate"
	var state := _make_state()
	var chi_yu_data := _card("CSV5C", "022")
	if chi_yu_data == null:
		return "CSV5C_022 Chi-Yu should load"
	var chi_yu := _slot(chi_yu_data)
	var dragapult := _slot(_card("CSV8C", "159"))
	var support := _slot(_pokemon("Support", 100))
	state.players[0].active_pokemon = chi_yu
	state.players[0].bench.assign([support, dragapult])
	var fire_a := CardInstance.create(_energy("Fire A", "R"), 0)
	var fire_b := CardInstance.create(_energy("Fire B", "R"), 0)
	state.players[0].discard_pile.assign([fire_a, fire_b])
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(chi_yu_data)
	var effects: Array[BaseEffect] = processor.get_attack_effects_for_slot(chi_yu, 0)
	if effects.is_empty():
		return "Chi-Yu should register its real discard Fire Energy attack effect"
	var steps: Array[Dictionary] = effects[0].get_attack_interaction_steps(
		chi_yu.get_top_card(),
		chi_yu_data.attacks[0],
		state
	)
	if steps.size() != 2:
		return "Chi-Yu should expose its real Energy and target steps"
	var context := {
		"game_state": state,
		"player_index": 0,
		"pending_effect_card": chi_yu.get_top_card(),
	}
	var energy_pick: Array = strategy.call("pick_interaction_items", steps[0].get("items", []), steps[0], context)
	context["discard_energy"] = energy_pick
	var target_pick: Array = strategy.call("pick_interaction_items", steps[1].get("items", []), steps[1], context)
	var live_route_score: float = strategy.call("score_action_absolute", {
		"kind": "attack",
		"source_slot": chi_yu,
		"attack_index": 0,
	}, state, 0)
	state.players[0].discard_pile.clear()
	var dead_route_score: float = strategy.call("score_action_absolute", {
		"kind": "attack",
		"source_slot": chi_yu,
		"attack_index": 0,
	}, state, 0)
	return run_checks([
		assert_eq(str(chi_yu_data.effect_id), CHI_YU_EFFECT_ID, "The real effect ID should identify Chi-Yu, not Chi-Yu ex"),
		assert_eq(str(steps[0].get("id", "")), "discard_energy", "Flame Surge should use the real discard Energy step"),
		assert_eq(str(steps[1].get("id", "")), "attach_target", "Flame Surge should use the real single-target attachment step"),
		assert_eq(energy_pick.size(), 2, "Flame Surge should recover up to both available Basic Fire Energy"),
		assert_true(fire_a in energy_pick and fire_b in energy_pick, "Flame Surge should select both real Fire Energy cards"),
		assert_eq(target_pick, [dragapult], "Flame Surge should fund the Dragapult attack route instead of support"),
		assert_true(live_route_score >= dead_route_score + 3000.0, "Chi-Yu should attack for acceleration only while discard Fire Energy advances the route"),
	])


func test_dragapult_family_blaziken_accelerates_the_missing_dragapult_color() -> String:
	var strategy := _new_strategy(800019125)
	if strategy == null:
		return "Blaziken/Dragapult delegate should instantiate"
	var state := _make_state()
	var player := state.players[0]
	var dragapult := _slot(_card("CSV8C", "159"))
	dragapult.attached_energy.append(CardInstance.create(_energy("基本火能量", "R"), 0))
	var blaziken := _slot(_card("CSV7C", "038"))
	var support := _slot(_pokemon("Support", 100))
	player.active_pokemon = support
	player.bench.assign([dragapult, blaziken])
	var psychic := CardInstance.create(_energy("基本超能量", "P"), 0)
	var fire := CardInstance.create(_energy("基本火能量", "R"), 0)
	player.discard_pile.assign([psychic, fire])
	var context := {"game_state": state, "player_index": 0, "assignment_source": psychic}
	var step := {"id": "attach_basic_energy_from_discard", "max_select": 1}
	var psychic_score: float = strategy.call("score_interaction_target", psychic, step, {"game_state": state, "player_index": 0})
	var fire_score: float = strategy.call("score_interaction_target", fire, step, {"game_state": state, "player_index": 0})
	var dragapult_score: float = strategy.call("score_interaction_target", dragapult, step, context)
	var support_score: float = strategy.call("score_interaction_target", support, step, context)
	return run_checks([
		assert_true(psychic_score >= fire_score + 700.0, "Boiling Spirit should recover the missing Psychic color before duplicate Fire"),
		assert_true(dragapult_score >= support_score + 1200.0, "Boiling Spirit should attach the recovered Psychic to Dragapult, not support"),
	])


func test_dragapult_family_continuity_builds_a_backup_before_nonlethal_attack() -> String:
	var strategy := _new_strategy(800018499)
	var v18_strategy := _new_v18_strategy(800018499)
	if strategy == null or v18_strategy == null:
		return "Pure Dragapult delegate and V18Rules wrapper should instantiate"
	var state := _make_state()
	var player := state.players[0]
	var dragapult := _slot(_card("CSV8C", "159"))
	dragapult.attached_energy.assign([
		CardInstance.create(_card("CSVE1C", "FIR"), 0),
		CardInstance.create(_card("CSVE1C", "PSY"), 0),
	])
	var backup := _slot(_card("CSV8C", "157"))
	player.active_pokemon = dragapult
	player.bench.append(backup)
	var drakloak := CardInstance.create(_card("CSV8C", "158"), 0)
	player.hand.append(drakloak)
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	var continuity: Dictionary = strategy.call("build_continuity_contract", state, 0, plan)
	var evolve_action := {
		"kind": "evolve", "card": drakloak, "target_slot": backup,
	}
	var delegate_absolute: float = strategy.call("score_action_absolute", evolve_action, state, 0)
	var delegate_with_plan: float = strategy.call("score_action_absolute_with_plan", evolve_action, state, 0, plan)
	var delegated_from_v18: float = v18_strategy.call("_delegate_action_score", evolve_action, state, 0)
	var v18_plan: Dictionary = v18_strategy.call("build_turn_plan", state, 0, {})
	var v18_continuity: Dictionary = v18_strategy.call("build_continuity_contract", state, 0, v18_plan)
	var matching_evolve_bonus_count := 0
	var expected_evolve_bonus := 0.0
	for raw_rule: Variant in v18_continuity.get("action_bonuses", []):
		if not raw_rule is Dictionary:
			continue
		var rule := raw_rule as Dictionary
		if str(rule.get("kind", "")) != "evolve":
			continue
		var card_names: Variant = rule.get("card_names", [])
		if card_names is Array and not (card_names as Array).is_empty() \
				and "Drakloak" not in (card_names as Array) and "多龙奇" not in (card_names as Array):
			continue
		matching_evolve_bonus_count += 1
		expected_evolve_bonus += float(rule.get("bonus", 0.0))
	var v18_absolute: float = v18_strategy.call("score_action_absolute", evolve_action, state, 0)
	var evolve_score: float = v18_strategy.call("score_action_absolute_with_plan", evolve_action, state, 0, v18_plan)
	var attack_score: float = v18_strategy.call("score_action_absolute_with_plan", {
		"kind": "attack", "source_slot": dragapult, "attack_index": 1, "projected_damage": 200,
		"projected_knockout": false,
	}, state, 0, v18_plan)
	return run_checks([
		assert_true(bool(continuity.get("safe_setup_before_attack", false)), "A ready Active with an unevolved backup should retain setup debt"),
		assert_true(is_equal_approx(delegate_absolute, delegate_with_plan), "The family delegate absolute score must not apply its continuity contract"),
		assert_true(is_equal_approx(delegate_absolute, delegated_from_v18), "V18Rules must receive the delegate's absolute tactical score without hidden continuity"),
		assert_eq(matching_evolve_bonus_count, 2, "V18Rules should merge one shared and one family evolve continuity rule"),
		assert_true(is_equal_approx(evolve_score - v18_absolute, expected_evolve_bonus), "The merged continuity contract should be applied exactly once"),
		assert_true(evolve_score >= attack_score + 300.0, "The playable backup evolution should resolve before a nonlethal Phantom Dive"),
	])


func _new_strategy(deck_id: int) -> RefCounted:
	var script: Variant = load(STRATEGY_PATH)
	if not script is GDScript:
		return null
	var strategy: RefCounted = (script as GDScript).new()
	strategy.call("configure_from_deck", _load_deck(deck_id))
	return strategy


func _new_v18_strategy(deck_id: int) -> RefCounted:
	var script: Variant = load(V18_RULES_PATH)
	if not script is GDScript:
		return null
	var deck := _load_deck(deck_id)
	var strategy: RefCounted = (script as GDScript).new()
	strategy.call("configure_from_deck", deck)
	var raw_profile: Variant = strategy.call("_profile")
	if not raw_profile is Dictionary:
		return null
	var profile: Dictionary = (raw_profile as Dictionary).duplicate(true)
	profile["delegate_script_path"] = STRATEGY_PATH
	strategy.call("configure_profile", profile)
	strategy.call("configure_from_deck", deck)
	return strategy


func _load_deck(deck_id: int) -> DeckData:
	var path := "%s/%d.json" % [DECK_DIR, deck_id]
	if not FileAccess.file_exists(path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return DeckData.from_dict(parsed) if parsed is Dictionary else null


func _fixed_opening_player(deck_id: int) -> PlayerState:
	var path := "%s/%d.json" % [FIXED_ORDER_DIR, deck_id]
	if not FileAccess.file_exists(path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return null
	var order: Array = parsed.get("top_to_bottom", [])
	if order.size() < 7:
		return null
	var player := PlayerState.new()
	for index: int in 7:
		var entry: Dictionary = order[index]
		var card := _card(str(entry.get("set_code", "")), str(entry.get("card_index", "")))
		if card == null:
			return null
		player.hand.append(CardInstance.create(card, 0))
	return player


func _make_state() -> GameState:
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	state.players = [player, opponent]
	state.current_player_index = 0
	state.first_player_index = 0
	state.turn_number = 3
	state.phase = GameState.GamePhase.MAIN
	for index: int in 6:
		player.prizes.append(CardInstance.create(_trainer("Prize %d" % index), 0))
	return state


func _card(set_code: String, card_index: String) -> CardData:
	return CardDatabase.get_card(set_code, card_index)


func _slot(card_data: CardData, owner_index: int = 0) -> PokemonSlot:
	var result := PokemonSlot.new()
	result.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	return result


func _pokemon(name: String, hp: int, mechanic: String = "") -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = hp
	card.mechanic = mechanic
	card.retreat_cost = 1
	card.attacks = [{"name": "Test", "cost": "C", "damage": "10"}]
	return card


func _energy(name: String, provides: String) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Basic Energy"
	card.energy_provides = provides
	return card


func _trainer(name: String) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Item"
	return card


func _hand_name(player: PlayerState, index: int) -> String:
	if player == null or index < 0 or index >= player.hand.size():
		return ""
	var card: CardInstance = player.hand[index]
	return str(card.card_data.name) if card != null and card.card_data != null else ""


func _bench_contains(player: PlayerState, indices: Array, target_name: String) -> bool:
	for raw_index: Variant in indices:
		if _hand_name(player, int(raw_index)) == target_name:
			return true
	return false
