extends SceneTree

const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const RouteSearchScript = preload("res://scripts/ai/v18_cpg/planning/V18CPGRouteSearch.gd")
const CapabilityRegistryScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCapabilityRegistry.gd")
const MaterialDeltaScript = preload("res://scripts/ai/v18_cpg/observation/V18CPGMaterialDelta.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")

const DECK_ID := 18000230
const MANIFEST_PATH := "res://scripts/ai/v18_cpg/profiles/generated_semantic_manifests/18000230.json"
const BASELINE_PATH := "res://tmp/v18cpg/optimization21/18000230/round00.json"
const REPORT_PATH := "res://tmp/v18cpg/optimization21/18000230/complex_decision_scenarios.json"

const DREEPY_UID := "CSV8C_157"
const DRAKLOAK_UID := "CSV8C_158"
const DRAGAPULT_UID := "CSV8C_159"
const CHARMANDER_UID := "151C_004"
const CHARMELEON_UID := "CSV5C_015"
const CHARIZARD_UID := "CSV5C_075"
const CHI_YU_UID := "CSV5C_022"
const ARVEN_UID := "CSV1C_123"
const IONO_UID := "CSV3C_123"
const POFFIN_UID := "CSV7C_177"
const RARE_CANDY_UID := "CSVH1C_045"
const TM_EVOLUTION_UID := "CSV5C_119"
const FIRE_UID := "CSVE1C_FIR"
const LUMINOUS_UID := "CSV1C_127"

var _profile: Dictionary = {}
var _manifest: Dictionary = {}
var _failures: Array[String] = []
var _rows: Array[Dictionary] = []


func _initialize() -> void:
	_profile = ProfileCatalogScript.get_profile_for_deck(DECK_ID)
	_manifest = _load_json(MANIFEST_PATH)
	_check(int(_profile.get("deck_id", 0)) == DECK_ID, "production Dragapult Charizard profile must load")
	_check(int(_manifest.get("deck_id", 0)) == DECK_ID, "Dragapult Charizard semantic manifest must load")
	_check(_profile.get("modules", []) == ["stage2_chain", "dragapult_spread", "energy_burst"], \
		"scenarios must use the production stage2/spread/energy module composition")

	_scenario_a_second_player_arven_poffin_tm_double_root()
	_scenario_b_candy_charizard_infernal_reign_dual_attacker()
	_scenario_c_drakloak_luminous_before_iono()
	_scenario_d_phantom_dive_public_prize_map()
	_scenario_e_burning_darkness_last_prize_terminal()
	_write_report()

	EffectProcessor.cleanup_live_instances_for_tests()
	if _failures.is_empty() and _rows.size() == 5:
		print("optimization21 18000230 complex decision scenarios: PASS (5/5)")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("optimization21 18000230 complex decision scenarios: FAIL (%d)" % _failures.size())
	quit(1)


func _scenario_a_second_player_arven_poffin_tm_double_root() -> void:
	var processor := EffectProcessor.new()
	var state := _game_state(2, 1)
	var chi_yu := _real_slot(_real_card_data(CHI_YU_UID), 0)
	chi_yu.attached_energy = [_real_instance(FIRE_UID, 0)]
	state.players[0].active_pokemon = chi_yu
	state.players[1].active_pokemon = _real_target("Public opening target", 200, 1)
	var arven := _real_instance(ARVEN_UID, 0)
	var poffin := _real_instance(POFFIN_UID, 0)
	var tm := _real_instance(TM_EVOLUTION_UID, 0)
	var dreepy := _real_instance(DREEPY_UID, 0)
	var charmander := _real_instance(CHARMANDER_UID, 0)
	var drakloak := _real_instance(DRAKLOAK_UID, 0)
	var charmeleon := _real_instance(CHARMELEON_UID, 0)
	state.players[0].hand = [arven]
	state.players[0].deck = [
		poffin, tm, dreepy, charmander, drakloak, charmeleon,
		_filler_instance("VISIBLE_OPENING_FILLER", 0),
	]

	var arven_effect := processor.get_effect(arven.card_data.effect_id)
	var arven_steps: Array = arven_effect.get_interaction_steps(arven, state) if arven_effect != null else []
	var item_step := _step(arven_steps, "search_item")
	var tool_step := _step(arven_steps, "search_tool")
	var arven_public := str(item_step.get("visible_scope", "")) == "own_full_deck" \
		and str(tool_step.get("visible_scope", "")) == "own_full_deck" \
		and poffin in (item_step.get("items", []) as Array) \
		and tm in (tool_step.get("items", []) as Array)
	var arven_executed := processor.execute_card_effect(arven, [{
		"search_item": [poffin],
		"search_tool": [tm],
	}], state)
	state.players[0].hand.erase(arven)
	state.players[0].discard_pile.append(arven)

	var poffin_effect := processor.get_effect(poffin.card_data.effect_id)
	var poffin_steps: Array = poffin_effect.get_interaction_steps(poffin, state) if poffin_effect != null else []
	var poffin_step := _step(poffin_steps, "buddy_poffin_pokemon")
	var poffin_public := str(poffin_step.get("visible_scope", "")) == "own_full_deck" \
		and dreepy in (poffin_step.get("items", []) as Array) \
		and charmander in (poffin_step.get("items", []) as Array)
	var poffin_executed := processor.execute_card_effect(poffin, [{
		"buddy_poffin_pokemon": [dreepy, charmander],
	}], state)
	var root_uids := _slot_uids(state.players[0].bench)

	state.players[0].hand.erase(tm)
	chi_yu.attached_tool = tm
	var tm_effect := processor.get_effect(tm.card_data.effect_id)
	var granted: Array = processor.get_granted_attacks(chi_yu, state)
	var granted_ready := not granted.is_empty() \
		and RuleValidator.new().can_use_granted_attack(state, 0, chi_yu, granted[0], processor)
	var first_steps: Array = tm_effect.get_granted_attack_interaction_steps(chi_yu, granted[0], state) \
		if tm_effect != null and not granted.is_empty() else []
	var followup: Array = tm_effect.get_followup_granted_attack_interaction_steps(
		chi_yu, granted[0], state, {"evolution_bench": state.players[0].bench}
	) if tm_effect != null and not granted.is_empty() else []
	var evolution_step := _step(followup, "evolution_cards")
	var tm_public := not first_steps.is_empty() \
		and str(evolution_step.get("visible_scope", "")) == "own_full_deck" \
		and drakloak in (evolution_step.get("items", []) as Array) \
		and charmeleon in (evolution_step.get("items", []) as Array)
	if tm_effect != null and not granted.is_empty():
		tm_effect.execute_granted_attack(chi_yu, granted[0], state, [{
			"evolution_bench": state.players[0].bench,
			"evolution_cards": [drakloak, charmeleon],
		}])
	var evolved_uids := _slot_uids(state.players[0].bench)

	var no_energy_state := _game_state(2, 1)
	var no_energy_carrier := _real_slot(_real_card_data(CHI_YU_UID), 0)
	no_energy_carrier.attached_tool = _real_instance(TM_EVOLUTION_UID, 0)
	no_energy_state.players[0].active_pokemon = no_energy_carrier
	no_energy_state.players[0].bench = [
		_real_slot(_real_card_data(DREEPY_UID), 0),
		_real_slot(_real_card_data(CHARMANDER_UID), 0),
	]
	no_energy_state.players[0].deck = [
		_real_instance(DRAKLOAK_UID, 0),
		_real_instance(CHARMELEON_UID, 0),
	]
	no_energy_state.players[1].active_pokemon = _real_target("Public no-energy target", 200, 1)
	var no_energy_granted := processor.get_granted_attacks(no_energy_carrier, no_energy_state)
	var no_energy_blocked := not no_energy_granted.is_empty() \
		and not RuleValidator.new().can_use_granted_attack(
			no_energy_state, 0, no_energy_carrier, no_energy_granted[0], processor)

	var first_player_state := _game_state(1, 0)
	var first_player_carrier := _real_slot(_real_card_data(CHI_YU_UID), 0)
	first_player_carrier.attached_tool = _real_instance(TM_EVOLUTION_UID, 0)
	first_player_carrier.attached_energy = [_real_instance(FIRE_UID, 0)]
	first_player_state.players[0].active_pokemon = first_player_carrier
	first_player_state.players[0].bench = [_real_slot(_real_card_data(DREEPY_UID), 0)]
	first_player_state.players[0].deck = [_real_instance(DRAKLOAK_UID, 0)]
	first_player_state.players[1].active_pokemon = _real_target("Public first-player target", 200, 1)
	var first_player_granted := processor.get_granted_attacks(first_player_carrier, first_player_state)
	var first_player_blocked := not first_player_granted.is_empty() \
		and not RuleValidator.new().can_use_granted_attack(
			first_player_state, 0, first_player_carrier, first_player_granted[0], processor)

	var passed := arven_public and arven_executed and poffin_public and poffin_executed \
		and root_uids == [DREEPY_UID, CHARMANDER_UID] and granted_ready and tm_public \
		and evolved_uids == [DRAKLOAK_UID, CHARMELEON_UID] \
		and no_energy_blocked and first_player_blocked
	_check(passed, "scenario A must prove real Arven -> Poffin -> payable second-player TM dual Stage-1")
	_rows.append(_row(
		"second_player_arven_poffin_tm_double_root",
		"双Stage2根/检索顺序",
		"后攻古玉鱼带一火，派帕先取宝芬和进化TM；宝芬同时铺多龙梅西亚与小火龙，TM再同时进化为多龙奇和火恐龙。",
		"Arven(Poffin+TM) -> Poffin(Dreepy+Charmander) -> TM Evolution(Drakloak+Charmeleon)",
		["TM载体没有可支付能量", "先攻玩家首回合不能攻击"],
		passed
	))


func _scenario_b_candy_charizard_infernal_reign_dual_attacker() -> void:
	var processor := EffectProcessor.new()
	var state := _game_state()
	var dragapult := _real_slot(_real_card_data(DRAGAPULT_UID), 0)
	dragapult.attached_energy = [_real_instance(LUMINOUS_UID, 0)]
	var charmander := _real_slot(_real_card_data(CHARMANDER_UID), 0)
	charmander.turn_played = 2
	state.players[0].active_pokemon = dragapult
	state.players[0].bench = [charmander]
	state.players[1].active_pokemon = _real_target("Public dual-attacker target", 300, 1)
	var candy := _real_instance(RARE_CANDY_UID, 0)
	var charizard := _real_instance(CHARIZARD_UID, 0)
	var fire_a := _real_instance(FIRE_UID, 0)
	var fire_b := _real_instance(FIRE_UID, 0)
	var fire_c := _real_instance(FIRE_UID, 0)
	state.players[0].hand = [candy, charizard]
	state.players[0].deck = [fire_a, fire_b, fire_c, _filler_instance("VISIBLE_DECK_FILLER", 0)]

	var validator := RuleValidator.new()
	var dragapult_blocked_before := not validator.can_use_attack(state, 0, 1, processor)
	var candy_effect := processor.get_effect(candy.card_data.effect_id)
	var candy_steps: Array = candy_effect.get_interaction_steps(candy, state) if candy_effect != null else []
	var stage2_step := _step(candy_steps, "stage2_card")
	var target_step := _step(candy_steps, "target_pokemon")
	var candy_exact := charizard in (stage2_step.get("items", []) as Array) \
		and charmander in (target_step.get("items", []) as Array)
	var candy_executed := processor.execute_card_effect(candy, [{
		"stage2_card": [charizard],
		"target_pokemon": [charmander],
	}], state)
	processor.register_pokemon_card(charmander.get_card_data())

	var ability_effect := processor.get_ability_effect(charmander, 0, state)
	var ability_ready := processor.can_use_ability(charmander, state, 0)
	var ability_steps: Array = ability_effect.get_interaction_steps(charmander.get_top_card(), state) \
		if ability_effect != null else []
	var assignment_step := _step(ability_steps, "energy_assignments")
	var source_items: Array = assignment_step.get("source_items", []) \
		if assignment_step.get("source_items", []) is Array else []
	var target_items: Array = assignment_step.get("target_items", []) \
		if assignment_step.get("target_items", []) is Array else []
	var assignment_exact := str(assignment_step.get("visible_scope", "")) == "own_full_deck" \
		and str(assignment_step.get("ui_mode", "")) == "card_assignment" \
		and int(assignment_step.get("max_select", 0)) == 3 \
		and source_items == [fire_a, fire_b, fire_c] \
		and dragapult in target_items and charmander in target_items
	var accelerated := processor.execute_ability_effect(charmander, 0, [{
		"energy_assignments": [
			{"source": fire_a, "target": dragapult},
			{"source": fire_b, "target": charmander},
			{"source": fire_c, "target": charmander},
		],
	}], state)
	var dragapult_ready_after := validator.can_use_attack(state, 0, 1, processor)
	var charizard_ready_after := validator.has_enough_energy(charmander, "RR", processor, state)
	var ability_consumed := not processor.can_use_ability(charmander, state, 0)

	var fresh_state := _game_state()
	var fresh_charmander := _real_slot(_real_card_data(CHARMANDER_UID), 0)
	fresh_charmander.turn_played = fresh_state.turn_number
	fresh_state.players[0].active_pokemon = _real_slot(_real_card_data(CHI_YU_UID), 0)
	fresh_state.players[0].bench = [fresh_charmander]
	var fresh_candy := _real_instance(RARE_CANDY_UID, 0)
	fresh_state.players[0].hand = [fresh_candy, _real_instance(CHARIZARD_UID, 0)]
	fresh_state.players[1].active_pokemon = _real_target("Public fresh-root target", 200, 1)
	var fresh_root_blocked := candy_effect != null and not candy_effect.can_execute(fresh_candy, fresh_state)

	var downgrade_state := _game_state()
	var downgraded_dragapult := _real_slot(_real_card_data(DRAGAPULT_UID), 0)
	var downgrade_luminous_a := _real_instance(LUMINOUS_UID, 0)
	var downgrade_luminous_b := _real_instance(LUMINOUS_UID, 0)
	downgraded_dragapult.attached_energy = [
		_real_instance(FIRE_UID, 0), downgrade_luminous_a, downgrade_luminous_b,
	]
	downgrade_state.players[0].active_pokemon = downgraded_dragapult
	downgrade_state.players[1].active_pokemon = _real_target("Public downgrade target", 200, 1)
	var luminous_downgraded := processor.get_energy_type(downgrade_luminous_a, downgrade_state) == "C" \
		and not validator.can_use_attack(downgrade_state, 0, 1, processor)

	var passed := dragapult_blocked_before and candy_exact and candy_executed \
		and charmander.get_card_data().get_uid() == CHARIZARD_UID \
		and ability_effect != null and ability_ready and assignment_exact and accelerated \
		and fire_a in dragapult.attached_energy and dragapult_ready_after \
		and charizard_ready_after and ability_consumed and fresh_root_blocked and luminous_downgraded
	_check(passed, "scenario B must prove Candy Charizard -> exact Infernal Reign split -> two ready Stage-2 attackers")
	_rows.append(_row(
		"candy_charizard_infernal_reign_dual_attacker",
		"进化/烈焰支配/异色补费",
		"夜光单能多龙缺火，小火龙糖果进化喷火龙后，烈焰支配把一火给多龙、两火给喷火龙，同一效果同时补齐RP与RR。",
		"Rare Candy(Charizard ex) -> Infernal Reign(1 Fire to Dragapult, 2 Fire to Charizard)",
		["本回合刚下场的小火龙不能糖果进化", "第二张特殊能量会让夜光退化为无色", "烈焰支配进化触发只可结算一次"],
		passed
	))


func _scenario_c_drakloak_luminous_before_iono() -> void:
	var processor := EffectProcessor.new()
	var state := _game_state()
	var dragapult := _real_slot(_real_card_data(DRAGAPULT_UID), 0)
	dragapult.attached_energy = [_real_instance(FIRE_UID, 0)]
	var drakloak := _real_slot(_real_card_data(DRAKLOAK_UID), 0)
	var luminous := _real_instance(LUMINOUS_UID, 0)
	var iono := _real_instance(IONO_UID, 0)
	var filler := _filler_instance("VISIBLE_AFTER_TOP_TWO", 0)
	state.players[0].active_pokemon = dragapult
	state.players[0].bench = [drakloak]
	state.players[0].deck = [luminous, iono, filler]
	state.players[1].active_pokemon = _real_target("Public scout target", 220, 2)
	processor.register_pokemon_card(drakloak.get_card_data())

	var ability_effect := processor.get_ability_effect(drakloak, 0, state)
	var steps: Array = ability_effect.get_interaction_steps(drakloak.get_top_card(), state) \
		if ability_effect != null else []
	var top_step := _step(steps, "look_top_pick")
	var exact_top_scope := str(top_step.get("visible_scope", "")) == "own_top_2_cards" \
		and (top_step.get("card_items", []) as Array) == [luminous, iono] \
		and not JSON.stringify(top_step).contains("FORBIDDEN_SECRET")

	var before := _observation(
		[
			_ability("ability:recon-directive", "slot:drakloak", DRAKLOAK_UID, true),
			_play_trainer("supporter:iono-before-scout", IONO_UID, false),
			_end_turn("end:before-scout"),
		],
		_slot("slot:active", DRAGAPULT_UID, [_fire_energy()]),
		[_slot("slot:drakloak", DRAKLOAK_UID, [])],
		3
	)
	before["observation_version"] = 1
	before["observation_hash"] = "dragapult-charizard-before-recon"
	var facts_before := _facts(false, false, true, 0, false, false, 70)
	var scout_frontier := _frontier(before, {
		"ability:recon-directive": 530.0,
		"supporter:iono-before-scout": 500.0,
		"end:before-scout": -900.0,
	}, facts_before, "ability:recon-directive")
	var scout_candidate := _candidate(scout_frontier, "ability:recon-directive")
	var scouted := processor.execute_ability_effect(drakloak, 0, [{"look_top_pick": [luminous]}], state)
	var luminous_in_hand := luminous in state.players[0].hand
	var unchosen_bottomed := state.players[0].deck == [filler, iono]

	var after := before.duplicate(true)
	after["observation_version"] = 2
	after["observation_hash"] = "dragapult-charizard-after-recon"
	after["own"]["hand"] = [_luminous_energy()]
	after["own"]["deck_count"] = 2
	after["legal_actions"] = [
		_play_trainer("supporter:iono-after-scout", IONO_UID, false),
		_attach_energy("attach:luminous-to-dragapult", LUMINOUS_UID, "slot:active"),
	]
	var facts_after := _facts(false, false, true, 1, false, false, 70)
	var reopened := _epoch_reopens(before, after, facts_before, facts_after, scout_candidate, scout_frontier)
	var attach_frontier := _frontier(after, {
		"supporter:iono-after-scout": 600.0,
		"attach:luminous-to-dragapult": 590.0,
	}, facts_after, "supporter:iono-after-scout")
	var attach_candidate := _candidate(attach_frontier, "attach:luminous-to-dragapult")
	var certificate := CapabilityRegistryScript.new().verify_route_advantage(
		attach_candidate, attach_frontier[0], facts_after, _profile)

	state.players[0].hand.erase(luminous)
	dragapult.attached_energy.append(luminous)
	var actual_luminous_type := processor.get_energy_type(luminous, state)
	var attack_ready := RuleValidator.new().can_use_attack(state, 0, 1, processor)
	var empty_does_not_reopen := not _epoch_reopens(
		before, before.duplicate(true), facts_before, facts_before, scout_candidate, scout_frontier, false)

	var passed := exact_top_scope and scouted and luminous_in_hand and unchosen_bottomed and reopened \
		and actual_luminous_type == "ANY" and attack_ready and empty_does_not_reopen \
		and not bool(certificate.get("verified", false))
	_check(passed, "scenario C must scout real Luminous before Iono and expose the current wildcard-certificate gap")
	_rows.append(_row(
		"drakloak_luminous_before_iono",
		"侦察/支援者顺序/信息epoch",
		"多龙已有火能时，多龙奇先看牌库顶2并拿夜光；信息结果重开epoch，真实引擎把夜光视为ANY并补齐超能，不能先奇树洗掉这张公开答案。",
		"Recon Directive(Luminous) -> information_result -> attach Luminous before Iono",
		["侦察失败或未拿牌不应重开epoch", "夜光通配目前没有typed-attachment生产证书"],
		passed
	))


func _scenario_d_phantom_dive_public_prize_map() -> void:
	var processor := EffectProcessor.new()
	var state := _phantom_prize_map_state()
	var dragapult := state.players[0].active_pokemon
	var bench_a := state.players[1].bench[0]
	var bench_b := state.players[1].bench[1]
	processor.register_pokemon_card(dragapult.get_card_data())
	var legal := RuleValidator.new().can_use_attack(state, 0, 1, processor)
	var spread_step: Dictionary = {}
	for effect: BaseEffect in processor.get_attack_effects_for_slot(dragapult, 1):
		var steps: Array = effect.get_attack_interaction_steps(
			dragapult.get_top_card(), dragapult.get_card_data().attacks[1], state)
		if spread_step.is_empty():
			spread_step = _step(steps, "bench_damage_counters")
	var exact_distribution_contract := str(spread_step.get("ui_mode", "")) == "counter_distribution" \
		and int(spread_step.get("total_counters", 0)) == 6 \
		and int(spread_step.get("min_select", 0)) == 6 \
		and int(spread_step.get("max_select", 0)) == 6 \
		and (spread_step.get("target_items", []) as Array) == [bench_a, bench_b]
	var executed := processor.execute_attack_effect(dragapult, 1, state.players[1].active_pokemon, state, [{
		"bench_damage_counters": [
			{"target": bench_a, "amount": 40},
			{"target": bench_b, "amount": 20},
		],
	}])
	var split_prizes := (1 if bench_a.get_remaining_hp() <= 0 else 0) \
		+ (1 if bench_b.get_remaining_hp() <= 0 else 0)

	var negative_processor := EffectProcessor.new()
	var negative_state := _phantom_prize_map_state()
	var negative_dragapult := negative_state.players[0].active_pokemon
	var negative_a := negative_state.players[1].bench[0]
	var negative_b := negative_state.players[1].bench[1]
	negative_processor.register_pokemon_card(negative_dragapult.get_card_data())
	var negative_executed := negative_processor.execute_attack_effect(
		negative_dragapult, 1, negative_state.players[1].active_pokemon, negative_state, [{
			"bench_damage_counters": [{"target": negative_a, "amount": 60}],
		}]
	)
	var stacked_prizes := (1 if negative_a.get_remaining_hp() <= 0 else 0) \
		+ (1 if negative_b.get_remaining_hp() <= 0 else 0)

	var attack := _attack("attack:phantom-prize-map", DRAGAPULT_UID, 1, 200, false)
	attack["requires_interaction"] = true
	var observation := _observation(
		[attack, _end_turn("end:waste-spread")],
		_slot("slot:active", DRAGAPULT_UID, [_fire_energy(), _luminous_energy()]),
		[],
		8
	)
	observation["opponent"]["active"] = _public_target("PUBLIC_320_HP_ACTIVE", 320, 2)
	observation["opponent"]["bench"] = [
		_public_target("PUBLIC_40_HP_SINGLE", 40, 1),
		_public_target("PUBLIC_20_HP_SINGLE", 20, 1),
	]
	var facts := _facts(true, false, false, 2, false, false, 200)
	var frontier := _frontier(observation, {
		"attack:phantom-prize-map": 800.0,
		"end:waste-spread": -900.0,
	}, facts, "attack:phantom-prize-map")
	var attack_candidate := _candidate(frontier, "attack:phantom-prize-map")
	var spread_annotation: Dictionary = {}
	var annotations: Dictionary = attack_candidate.get("module_annotations", {}) \
		if attack_candidate.get("module_annotations", {}) is Dictionary else {}
	if annotations.get("dragapult_spread", {}) is Dictionary:
		spread_annotation = annotations.get("dragapult_spread", {})
	var spread_shape_visible := int(spread_annotation.get("spread_target_count", 0)) == 2 \
		and "solve_two_turn_prize_map" in (spread_annotation.get("decision_hints", []) as Array)
	var safety := _route_safety(attack_candidate, frontier, facts)

	var passed := legal and exact_distribution_contract and executed \
		and bench_a.damage_counters == 40 and bench_b.damage_counters == 20 \
		and split_prizes == 2 and negative_executed and stacked_prizes == 1 \
		and spread_shape_visible and bool(safety.get("valid", false)) \
		and str(safety.get("reason", "")) == "matches_rules_floor"
	_check(passed, "scenario D must split real Phantom Dive counters 4/2 instead of wasting 6 on one target")
	_rows.append(_row(
		"phantom_dive_public_prize_map",
		"铺伤/公开奖赏图",
		"对方前台320HP时本次200不击倒；两只备战剩40与20HP，应把6个伤害指示物按4+2分开拿两奖，而不是6个堆一只只拿一奖。",
		"Phantom Dive counters 4/2 across public 40 HP and 20 HP Bench targets",
		["6个全堆40HP目标只产生一奖", "当前spread模块只有形状提示，尚未绑定逐目标分配证书"],
		passed
	))


func _scenario_e_burning_darkness_last_prize_terminal() -> void:
	var processor := EffectProcessor.new()
	var state := _charizard_closeout_state(2)
	var charizard := state.players[0].active_pokemon
	var defender := state.players[1].active_pokemon
	processor.register_pokemon_card(charizard.get_card_data())
	var attack_data: Dictionary = charizard.get_card_data().attacks[0]
	var base_damage := _base_attack_damage(charizard.get_card_data(), 0)
	var bonus := processor.get_attack_damage_modifier(charizard, defender, attack_data, state, [], 0)
	var total_damage := base_damage + bonus
	var legal := RuleValidator.new().can_use_attack(state, 0, 0, processor)

	var negative_processor := EffectProcessor.new()
	var negative_state := _charizard_closeout_state(3)
	var negative_charizard := negative_state.players[0].active_pokemon
	negative_processor.register_pokemon_card(negative_charizard.get_card_data())
	var negative_attack: Dictionary = negative_charizard.get_card_data().attacks[0]
	var negative_damage := _base_attack_damage(negative_charizard.get_card_data(), 0) \
		+ negative_processor.get_attack_damage_modifier(
			negative_charizard, negative_state.players[1].active_pokemon,
			negative_attack, negative_state, [], 0)

	var observation := _observation(
		[
			_play_trainer("supporter:iono-too-late", IONO_UID, false),
			_attack("attack:burning-darkness-terminal", CHARIZARD_UID, 0, total_damage, true),
		],
		_slot("slot:active", CHARIZARD_UID, [_fire_energy(), _fire_energy()]),
		[],
		5
	)
	observation["own"]["prizes_remaining"] = 1
	observation["opponent"]["prizes_remaining"] = 2
	observation["opponent"]["active"] = _public_target("PUBLIC_300_HP_SINGLE", 300, 1)
	var facts := _facts(true, true, false, 2, false, false, total_damage)
	facts["resources"]["prizes_remaining"] = 1
	facts["prize"] = {"current_swing": 1, "win_now": true}
	var frontier := _frontier(observation, {
		"supporter:iono-too-late": 700.0,
		"attack:burning-darkness-terminal": 10.0,
	}, facts, "supporter:iono-too-late")
	var attack_candidate := _candidate(frontier, "attack:burning-darkness-terminal")
	var safety := _route_safety(attack_candidate, frontier, facts)

	var passed := legal and base_damage == 180 and bonus == 120 and total_damage == 300 \
		and negative_damage == 270 and negative_damage < defender.get_remaining_hp() \
		and bool(safety.get("valid", false)) \
		and str(safety.get("reason", "")) == "deterministic_win_now"
	_check(passed, "scenario E must use real opponent-prize scaling to take the last Prize before Iono: %s" % JSON.stringify({
		"legal": legal,
		"base_damage": base_damage,
		"bonus": bonus,
		"total_damage": total_damage,
		"negative_damage": negative_damage,
		"defender_remaining_hp": defender.get_remaining_hp(),
		"safety": safety,
	}))
	_rows.append(_row(
		"burning_darkness_last_prize_terminal",
		"末奖/动态伤害终结",
		"己方只剩1奖、对手已拿4奖时，燃烧黑暗为180+120=300，正好击倒公开300HP单奖前台；应立即攻击，不能先用奇树增加不必要风险。",
		"Burning Darkness 300 for the exact last-Prize knockout",
		["对手只拿3奖时伤害仅270", "300HP以上目标不构成确定终结", "终结前不应先洗手牌"],
		passed
	))


func _frontier(observation: Dictionary, scores: Dictionary, facts: Dictionary, rule_action_id: String) -> Array[Dictionary]:
	var pool: Array[Dictionary] = RouteSearchScript.new().build_candidate_pool(observation, scores, _manifest, facts)
	var annotated: Array[Dictionary] = CapabilityRegistryScript.new().annotate_frontier(
		pool, observation, facts, _profile, _manifest)
	for candidate: Dictionary in annotated:
		candidate["engine_rule_floor_exact"] = str(candidate.get("safe_prefix_action_id", "")) == rule_action_id
	_check(not annotated.is_empty() \
		and str(annotated[0].get("safe_prefix_action_id", "")) == rule_action_id, \
		"fixture Rule floor %s must remain exact and first" % rule_action_id)
	_check(not JSON.stringify(annotated).contains("FORBIDDEN_SECRET"), \
		"public scenario frontier must exclude hidden sentinels")
	return annotated


func _route_safety(selected: Dictionary, frontier: Array[Dictionary], facts: Dictionary) -> Dictionary:
	if selected.is_empty():
		return {"valid": false, "reason": "missing_selected_candidate"}
	var strategy = StrategyScript.new()
	strategy.configure_profile(_profile, _manifest)
	return strategy.call("_validate_model_route_safety", \
		str(selected.get("route_id", "")), frontier, facts, str(selected.get("candidate_id", "")))


func _epoch_reopens(
	before: Dictionary,
	after: Dictionary,
	facts_before: Dictionary,
	facts_after: Dictionary,
	candidate: Dictionary,
	frontier: Array[Dictionary],
	success: bool = true
) -> bool:
	var delta := MaterialDeltaScript.new().compare(before, after, facts_before, facts_after)
	var strategy = StrategyScript.new()
	strategy.configure_profile(_profile, _manifest)
	strategy.configure_verified_local_only_for_benchmark()
	return bool(strategy.call("_should_reopen_information_epoch", \
		"local_gate", {
			"owner": "local_gate",
			"success": success,
			"route_id": str(candidate.get("route_id", "")),
			"candidate_id": str(candidate.get("candidate_id", "")),
		}, delta, frontier))


func _candidate(frontier: Array[Dictionary], action_id: String) -> Dictionary:
	for candidate: Dictionary in frontier:
		if str(candidate.get("safe_prefix_action_id", "")) == action_id:
			return candidate
	_check(false, "candidate for %s must exist" % action_id)
	return {}


func _observation(actions: Array, active: Dictionary, bench: Array, deck_count: int) -> Dictionary:
	return {
		"observation_version": 1,
		"observation_hash": "dragapult-charizard-complex-scenario",
		"turn": {"deterministic_attack_window_open": true},
		"own": {
			"active": active,
			"bench": bench,
			"hand": [{"uid": "VISIBLE_OWN_HAND_CARD"}],
			"discard": [],
			"deck_count": deck_count,
			"prizes_remaining": 6,
		},
		"opponent": {
			"active": _public_target("PUBLIC_OPPONENT_ACTIVE", 230, 2),
			"bench": [],
			"hand": [{"uid": "FORBIDDEN_SECRET_HAND_CARD"}],
			"deck_order": ["FORBIDDEN_SECRET_TOP_CARD"],
		},
		"stadium": {},
		"legal_actions": actions,
	}


func _facts(
	attack_ready: bool,
	ko_available: bool,
	energy_available: bool,
	hand_size: int,
	deck_low: bool,
	deck_critical: bool,
	max_damage: int
) -> Dictionary:
	return {
		"attack": {"ready": attack_ready, "ko_available": ko_available, "max_damage": max_damage},
		"turn": {"energy_available": energy_available, "supporter_available": true},
		"resources": {
			"deck_low": deck_low,
			"deck_critical": deck_critical,
			"hand_size": hand_size,
			"bench_slots_free": 3,
			"prizes_remaining": 6,
			"energy_on_board": 0,
		},
		"board": {"bench_full": false, "has_tera": false},
		"information": {"material_action_available": true},
		"prize": {"current_swing": 0, "win_now": false},
		"route": {"current_valid": true},
	}


func _slot(slot_id: String, uid: String, energy: Array) -> Dictionary:
	var hp := 90
	if uid == DRAGAPULT_UID:
		hp = 320
	elif uid == CHARIZARD_UID:
		hp = 330
	return {
		"slot_id": slot_id,
		"pokemon": _card(uid),
		"energy": energy,
		"energy_count": energy.size(),
		"remaining_hp": hp,
		"max_hp": hp,
		"prize_count": 2 if uid in [DRAGAPULT_UID, CHARIZARD_UID] else 1,
	}


func _public_target(uid: String, remaining_hp: int, prize_count: int) -> Dictionary:
	return {
		"slot_id": "slot:%s" % uid.to_lower(),
		"pokemon": {"uid": uid},
		"remaining_hp": remaining_hp,
		"prize_count": prize_count,
	}


func _play_trainer(action_id: String, uid: String, interaction: bool) -> Dictionary:
	return {
		"id": action_id,
		"kind": "play_trainer",
		"card": _card(uid),
		"requires_interaction": interaction,
	}


func _attach_energy(action_id: String, uid: String, target: String) -> Dictionary:
	return {
		"id": action_id,
		"kind": "attach_energy",
		"card": _luminous_energy() if uid == LUMINOUS_UID else _fire_energy(),
		"target": target,
	}


func _ability(action_id: String, source: String, uid: String, interaction: bool) -> Dictionary:
	return {
		"id": action_id,
		"kind": "use_ability",
		"source": source,
		"source_card": _card(uid),
		"ability_index": 0,
		"requires_interaction": interaction,
	}


func _attack(action_id: String, uid: String, attack_index: int, damage: int, knockout: bool) -> Dictionary:
	return {
		"id": action_id,
		"kind": "attack",
		"source": "slot:active",
		"source_card": _card(uid),
		"attack_index": attack_index,
		"projected_damage": damage,
		"projected_knockout": knockout,
		"requires_interaction": false,
	}


func _end_turn(action_id: String) -> Dictionary:
	return {"id": action_id, "kind": "end_turn"}


func _fire_energy() -> Dictionary:
	var card := _card(FIRE_UID)
	card["energy_type"] = "R"
	card["energy_provides"] = "R"
	var roles: Array = card.get("semantic_roles", []) if card.get("semantic_roles", []) is Array else []
	if "basic_energy" not in roles:
		roles.append("basic_energy")
	card["semantic_roles"] = roles
	return card


func _luminous_energy() -> Dictionary:
	var card := _card(LUMINOUS_UID)
	card["energy_type"] = ""
	card["energy_provides"] = ""
	return card


func _card(uid: String) -> Dictionary:
	for raw_card: Variant in _manifest.get("cards", []):
		if not (raw_card is Dictionary) or str((raw_card as Dictionary).get("uid", "")) != uid:
			continue
		var source: Dictionary = raw_card
		return {
			"uid": uid,
			"effect_id": str(source.get("effect_id", "")),
			"name": str(source.get("name", "")),
			"type": str(source.get("type", "")),
			"semantic_roles": (source.get("roles", []) as Array).duplicate() \
				if source.get("roles", []) is Array else [],
		}
	_check(false, "manifest card %s must exist" % uid)
	return {"uid": uid}


func _game_state(turn: int = 8, first_player: int = 0) -> GameState:
	var state := GameState.new()
	state.current_player_index = 0
	state.first_player_index = first_player
	state.turn_number = turn
	state.phase = GameState.GamePhase.MAIN
	for index: int in 2:
		var player := PlayerState.new()
		player.player_index = index
		state.players.append(player)
	return state


func _real_card_data(uid: String) -> CardData:
	var path := "res://data/bundled_user/cards/%s.json" % uid
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(parsed is Dictionary, "real card %s must load" % uid)
	return CardData.from_dict(parsed as Dictionary) if parsed is Dictionary else CardData.new()


func _real_instance(uid: String, owner: int) -> CardInstance:
	return CardInstance.create(_real_card_data(uid), owner)


func _real_slot(data: CardData, owner: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(data, owner))
	return slot


func _real_target(name: String, hp: int, prize_count: int) -> PokemonSlot:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = "Pokemon"
	data.stage = "Basic"
	data.hp = hp
	data.mechanic = "ex" if prize_count == 2 else ""
	return _real_slot(data, 1)


func _filler_instance(name: String, owner: int) -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = "Item"
	return CardInstance.create(data, owner)


func _slot_uids(slots: Array) -> Array[String]:
	var result: Array[String] = []
	for raw_slot: Variant in slots:
		if raw_slot is PokemonSlot and (raw_slot as PokemonSlot).get_card_data() != null:
			result.append((raw_slot as PokemonSlot).get_card_data().get_uid())
	return result


func _step(steps: Array, id: String) -> Dictionary:
	for raw_step: Variant in steps:
		if raw_step is Dictionary and str((raw_step as Dictionary).get("id", "")) == id:
			return raw_step as Dictionary
	return {}


func _phantom_prize_map_state() -> GameState:
	var state := _game_state()
	var dragapult := _real_slot(_real_card_data(DRAGAPULT_UID), 0)
	dragapult.attached_energy = [_real_instance(FIRE_UID, 0), _real_instance(LUMINOUS_UID, 0)]
	state.players[0].active_pokemon = dragapult
	state.players[1].active_pokemon = _real_target("Public 320 HP active", 320, 2)
	state.players[1].bench = [
		_real_target("Public 40 HP single", 40, 1),
		_real_target("Public 20 HP single", 20, 1),
	]
	return state


func _charizard_closeout_state(opponent_prizes_remaining: int) -> GameState:
	var state := _game_state()
	var charizard := _real_slot(_real_card_data(CHARIZARD_UID), 0)
	charizard.attached_energy = [_real_instance(FIRE_UID, 0), _real_instance(FIRE_UID, 0)]
	state.players[0].active_pokemon = charizard
	state.players[1].active_pokemon = _real_target("Public 300 HP single", 300, 1)
	state.players[0].prizes = [_filler_instance("OWN_LAST_PRIZE", 0)]
	state.players[1].prizes = []
	for index: int in opponent_prizes_remaining:
		state.players[1].prizes.append(_filler_instance("OPPONENT_PRIZE_%d" % index, 1))
	return state


func _base_attack_damage(card: CardData, attack_index: int) -> int:
	if card == null or attack_index < 0 or attack_index >= card.attacks.size():
		return 0
	var text := str(card.attacks[attack_index].get("damage", ""))
	var digits := ""
	for character: String in text:
		if character >= "0" and character <= "9":
			digits += character
		elif digits != "":
			break
	return int(digits) if digits != "" else 0


func _row(
	id: String,
	category: String,
	description: String,
	expected_choice: String,
	negative_boundaries: Array,
	passed: bool
) -> Dictionary:
	return {
		"id": id,
		"category": category,
		"description": description,
		"expected_choice": expected_choice,
		"negative_boundaries": negative_boundaries.duplicate(),
		"passed": passed,
	}


func _baseline_summary() -> Dictionary:
	var baseline := _load_json(BASELINE_PATH)
	var reports: Array = baseline.get("reports", []) if baseline.get("reports", []) is Array else []
	var report: Dictionary = reports[0] if not reports.is_empty() and reports[0] is Dictionary else {}
	return {
		"status": "complete" if not report.is_empty() else "missing_or_invalid",
		"artifact": BASELINE_PATH,
		"artifact_exists": FileAccess.file_exists(BASELINE_PATH),
		"run_id": str(baseline.get("run_id", "")),
		"clean_games": int(report.get("v18cpg_clean_games", 0)),
		"rule_wins": int(report.get("rule_wins", 0)),
		"rule_win_rate": float(report.get("rule_win_rate", 0.0)),
		"v18cpg_wins": int(report.get("v18cpg_wins", 0)),
		"v18cpg_win_rate": float(report.get("v18cpg_win_rate", 0.0)),
		"paired_improvement": float(report.get("paired_improvement", 0.0)),
		"model_calls": int(report.get("model_calls", 0)),
		"model_accepted": int(report.get("model_accepted", 0)),
		"model_rejected": int(report.get("model_rejected", 0)),
		"visible_wait_p95_ms": float(report.get("visible_wait_p95_ms", 0.0)),
		"strength_conclusion": "no improvement demonstrated; Rule and V18CPG both won 3/5 and the model accepted 0/28 calls",
	}


func _write_report() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT_PATH.get_base_dir()))
	var report := {
		"schema_version": 1,
		"architecture": "V18CPG",
		"semantic_schema": "v18cpg-2",
		"transport_contract_version": 3,
		"deck_id": DECK_ID,
		"deck_name": "18.0 喷火龙多龙巴鲁托",
		"strategy_id": str(_profile.get("strategy_id", "")),
		"profile_version": int(_profile.get("profile_version", 0)),
		"baseline": _baseline_summary(),
		"scope": "focused scenario validation only; no real-model formal benchmark",
		"scenario_count": _rows.size(),
		"passed_count": _rows.filter(func(row: Dictionary) -> bool: return bool(row.get("passed", false))).size(),
		"all_passed": _failures.is_empty() and _rows.size() == 5,
		"production_status": "scenario_contract_ready_not_promoted",
		"known_production_gaps": [
			"The existing five-game round00 is a 3-3 tie with 0/28 model acceptances, so it demonstrates neither takeover nor strength improvement over Rule.",
			"Infernal Reign's real three-source/multi-target energy_assignments interaction is executable, but no production certificate binds the exact 1-Fire/2-Fire split to both post-action attack costs.",
			"The engine resolves a lone Luminous Energy as ANY, but the V18 semantic energy alphabet currently sees its blank printed energy fields as other; typed-attachment completion and downgrade boundaries therefore have no production certificate.",
			"Phantom Dive exposes the real six-counter interaction and a dragapult_spread shape hint, but the frontier does not yet bind an exact per-target counter allocation or resulting multi-Prize map.",
			"Burning Darkness can receive deterministic_win_now when observation supplies public projected damage, but production still needs provenance that binds the 180 + opponent-prizes-taken * 30 effect calculation to that projection.",
			"A deterministic Burning Darkness win-now route is safety-valid, but the current autonomous deterministic upgrade guard does not replace a Supporter Rule root; model selection or a narrower terminal certificate still owns that switch.",
			"No real-model formal paired-seed rerun, aggregate promotion gate, latency gate, or deck-level strength promotion has been completed after these focused fixtures.",
		],
		"isolation": {
			"profile_modified": false,
			"shared_strategy_modified": false,
			"shared_registry_modified": false,
			"shared_strategic_shape_modified": false,
			"rule_or_legacy_or_agent_modified": false,
			"real_model_formal_run": false,
			"hidden_sentinel_absent_from_frontiers": true,
		},
		"coverage": [
			"second-player Arven into Buddy-Buddy Poffin and two-root TM Evolution",
			"Rare Candy Charizard ex into exact Infernal Reign dual-attacker energy assignment",
			"Drakloak top-two Luminous result before Iono and material information epoch",
			"Phantom Dive 4/2 Bench counter allocation versus 6-counter overkill",
			"Burning Darkness opponent-Prize scaling for the exact last-Prize terminal",
		],
		"scenarios": _rows.duplicate(true),
		"failures": _failures.duplicate(),
	}
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	_check(file != null, "complex scenario report must be writable")
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()


func _load_json(path: String) -> Dictionary:
	_check(FileAccess.file_exists(path), "%s must exist" % path)
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(parsed is Dictionary, "%s must contain valid JSON" % path)
	return parsed as Dictionary if parsed is Dictionary else {}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
