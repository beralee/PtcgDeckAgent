extends SceneTree

const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const RouteSearchScript = preload("res://scripts/ai/v18_cpg/planning/V18CPGRouteSearch.gd")
const CapabilityRegistryScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCapabilityRegistry.gd")
const MaterialDeltaScript = preload("res://scripts/ai/v18_cpg/observation/V18CPGMaterialDelta.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")

const DECK_ID := 800019125
const MANIFEST_PATH := "res://scripts/ai/v18_cpg/profiles/generated_semantic_manifests/800019125.json"
const REPORT_PATH := "res://tmp/v18cpg/optimization21/800019125/complex_decision_scenarios.json"

const DREEPY_UID := "CSV8C_157"
const DRAKLOAK_UID := "CSV8C_158"
const DRAGAPULT_UID := "CSV8C_159"
const TORCHIC_UID := "CSV10C_036"
const COMBUSKEN_UID := "CSV10C_037"
const BLAZIKEN_UID := "CSV7C_038"
const CHI_YU_UID := "CSV5C_022"
const ARVEN_UID := "CSV1C_123"
const IONO_UID := "CSV3C_123"
const POFFIN_UID := "CSV7C_177"
const RARE_CANDY_UID := "CSVH1C_045"
const TM_EVOLUTION_UID := "CSV5C_119"
const FIRE_UID := "CSVE1C_FIR"
const PSYCHIC_UID := "CSVE1C_PSY"

var _profile: Dictionary = {}
var _manifest: Dictionary = {}
var _failures: Array[String] = []
var _rows: Array[Dictionary] = []


func _initialize() -> void:
	_profile = ProfileCatalogScript.get_profile_for_deck(DECK_ID)
	_manifest = _load_json(MANIFEST_PATH)
	_check(int(_profile.get("deck_id", 0)) == DECK_ID, "production Blaziken Dragapult profile must load")
	_check(int(_manifest.get("deck_id", 0)) == DECK_ID, "Blaziken Dragapult semantic manifest must load")
	_check(_profile.get("modules", []) == ["stage2_chain", "dragapult_spread", "energy_burst"], \
		"scenarios must use the production stage2/spread/energy module composition")

	_scenario_a_second_player_arven_poffin_tm_double_root()
	_scenario_b_rare_candy_blaziken_accelerates_phantom_dive()
	_scenario_c_drakloak_information_before_supporter()
	_scenario_d_chi_yu_minimum_fire_acceleration()
	_scenario_e_phantom_dive_four_prize_closeout()
	_write_report()

	EffectProcessor.cleanup_live_instances_for_tests()
	if _failures.is_empty() and _rows.size() == 5:
		print("optimization21 800019125 complex decision scenarios: PASS (5/5)")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("optimization21 800019125 complex decision scenarios: FAIL (%d)" % _failures.size())
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
	var torchic := _real_instance(TORCHIC_UID, 0)
	var drakloak := _real_instance(DRAKLOAK_UID, 0)
	var combusken := _real_instance(COMBUSKEN_UID, 0)
	state.players[0].hand = [arven]
	state.players[0].deck = [
		poffin, tm, dreepy, torchic, drakloak, combusken,
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
		and torchic in (poffin_step.get("items", []) as Array)
	var poffin_executed := processor.execute_card_effect(poffin, [{
		"buddy_poffin_pokemon": [dreepy, torchic],
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
		and combusken in (evolution_step.get("items", []) as Array)
	if tm_effect != null and not granted.is_empty():
		tm_effect.execute_granted_attack(chi_yu, granted[0], state, [{
			"evolution_bench": state.players[0].bench,
			"evolution_cards": [drakloak, combusken],
		}])
	var evolved_uids := _slot_uids(state.players[0].bench)

	var no_energy_state := _game_state(2, 1)
	var no_energy_carrier := _real_slot(_real_card_data(CHI_YU_UID), 0)
	no_energy_carrier.attached_tool = _real_instance(TM_EVOLUTION_UID, 0)
	no_energy_state.players[0].active_pokemon = no_energy_carrier
	no_energy_state.players[0].bench = [
		_real_slot(_real_card_data(DREEPY_UID), 0),
		_real_slot(_real_card_data(TORCHIC_UID), 0),
	]
	no_energy_state.players[0].deck = [
		_real_instance(DRAKLOAK_UID, 0),
		_real_instance(COMBUSKEN_UID, 0),
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
		and root_uids == [DREEPY_UID, TORCHIC_UID] and granted_ready and tm_public \
		and evolved_uids == [DRAKLOAK_UID, COMBUSKEN_UID] \
		and no_energy_blocked and first_player_blocked
	_check(passed, "scenario A must prove real Arven -> Poffin -> payable second-player TM double evolution")
	_rows.append(_row(
		"second_player_arven_poffin_tm_double_root",
		"二后手支援者/双进化根",
		"二后手古玉鱼已有1火能，先用派帕公开检索友好宝芬与进化TM；宝芬铺多龙梅西亚、火稚鸡，TM再分别进化为多龙奇、力壮鸡。",
		"Arven(Poffin+TM) -> Poffin(Dreepy+Torchic) -> TM Evolution(Drakloak+Combusken)",
		["TM carrier has no payable energy", "first player's first turn cannot attack"],
		passed
	))


func _scenario_b_rare_candy_blaziken_accelerates_phantom_dive() -> void:
	var processor := EffectProcessor.new()
	var state := _game_state()
	var dragapult := _real_slot(_real_card_data(DRAGAPULT_UID), 0)
	dragapult.attached_energy = [_real_instance(PSYCHIC_UID, 0)]
	var torchic := _real_slot(_real_card_data(TORCHIC_UID), 0)
	torchic.turn_played = 2
	state.players[0].active_pokemon = dragapult
	state.players[0].bench = [torchic]
	state.players[1].active_pokemon = _real_target("Public Phantom Dive target", 240, 2)
	var candy := _real_instance(RARE_CANDY_UID, 0)
	var blaziken := _real_instance(BLAZIKEN_UID, 0)
	var fire := _real_instance(FIRE_UID, 0)
	state.players[0].hand = [candy, blaziken]
	state.players[0].discard_pile = [fire]

	var validator := RuleValidator.new()
	var attack_blocked_before := not validator.can_use_attack(state, 0, 1, processor)
	var candy_effect := processor.get_effect(candy.card_data.effect_id)
	var candy_steps: Array = candy_effect.get_interaction_steps(candy, state) if candy_effect != null else []
	var stage2_step := _step(candy_steps, "stage2_card")
	var target_step := _step(candy_steps, "target_pokemon")
	var candy_exact := blaziken in (stage2_step.get("items", []) as Array) \
		and torchic in (target_step.get("items", []) as Array)
	var candy_executed := processor.execute_card_effect(candy, [{
		"stage2_card": [blaziken],
		"target_pokemon": [torchic],
	}], state)
	processor.register_pokemon_card(blaziken.card_data)

	var before := _observation(
		[_ability("ability:boiling-spirit", "slot:blaziken", BLAZIKEN_UID, true), _end_turn("end:stale")],
		_slot("slot:active", DRAGAPULT_UID, [_psychic_energy()]),
		[_slot("slot:blaziken", BLAZIKEN_UID, [])],
		18
	)
	before["observation_version"] = 1
	before["observation_hash"] = "blaziken-dragapult-before-acceleration"
	before["own"]["discard"] = [_fire_energy()]
	var facts_before := _facts(false, false, false, 1, false, false, 70)
	var frontier := _frontier(before, {
		"ability:boiling-spirit": 520.0,
		"end:stale": -900.0,
	}, facts_before, "ability:boiling-spirit")
	var ability_candidate := _candidate(frontier, "ability:boiling-spirit")

	var ability_effect := processor.get_ability_effect(torchic, 0, state)
	var ability_steps: Array = ability_effect.get_interaction_steps(blaziken, state) if ability_effect != null else []
	var assignment_step := _step(ability_steps, "attach_basic_energy_from_discard")
	var assignment_exact := str(assignment_step.get("ui_mode", "")) == "card_assignment" \
		and fire in (assignment_step.get("source_items", []) as Array) \
		and dragapult in (assignment_step.get("target_items", []) as Array)
	var accelerated := processor.execute_ability_effect(torchic, 0, [{
		"attach_basic_energy_from_discard": [{"source": fire, "target": dragapult}],
	}], state)
	var attack_ready_after := validator.can_use_attack(state, 0, 1, processor)

	var after := before.duplicate(true)
	after["observation_version"] = 2
	after["observation_hash"] = "blaziken-dragapult-after-acceleration"
	after["own"]["active"] = _slot("slot:active", DRAGAPULT_UID, [_psychic_energy(), _fire_energy()])
	after["own"]["discard"] = []
	after["legal_actions"] = [_attack("attack:phantom-dive-after-acceleration", DRAGAPULT_UID, 1, 200, false)]
	var facts_after := _facts(true, false, false, 1, false, false, 200)
	var reopened := _epoch_reopens(before, after, facts_before, facts_after, ability_candidate, frontier)

	var fresh_root_state := _game_state()
	var fresh_torchic := _real_slot(_real_card_data(TORCHIC_UID), 0)
	fresh_torchic.turn_played = fresh_root_state.turn_number
	fresh_root_state.players[0].active_pokemon = _real_slot(_real_card_data(DRAGAPULT_UID), 0)
	fresh_root_state.players[0].bench = [fresh_torchic]
	var fresh_candy := _real_instance(RARE_CANDY_UID, 0)
	fresh_root_state.players[0].hand = [fresh_candy, _real_instance(BLAZIKEN_UID, 0)]
	var fresh_root_blocked := candy_effect != null and not candy_effect.can_execute(fresh_candy, fresh_root_state)

	var no_discard_state := _game_state()
	var no_discard_blaziken := _real_slot(_real_card_data(BLAZIKEN_UID), 0)
	no_discard_state.players[0].active_pokemon = _real_slot(_real_card_data(DRAGAPULT_UID), 0)
	no_discard_state.players[0].bench = [no_discard_blaziken]
	processor.register_pokemon_card(no_discard_blaziken.get_card_data())
	var no_discard_blocked := not processor.can_use_ability(no_discard_blaziken, no_discard_state, 0)

	var passed := attack_blocked_before and candy_exact and candy_executed \
		and torchic.get_card_data().get_uid() == BLAZIKEN_UID \
		and assignment_exact and accelerated and fire in dragapult.attached_energy \
		and attack_ready_after and reopened and fresh_root_blocked and no_discard_blocked
	_check(passed, "scenario B must prove Candy Blaziken -> real discard acceleration -> RP Phantom Dive")
	_rows.append(_row(
		"rare_candy_blaziken_accelerates_phantom_dive",
		"糖果/特性/异色填能",
		"多龙巴鲁托已有超能但缺火能时，先用神奇糖果把旧火稚鸡进化成火焰鸡ex，再用沸腾斗志把弃牌火能附给多龙，立即补齐幻影潜袭的火+超费用。",
		"Rare Candy(Blaziken ex) -> Boiling Spirit(Fire to Dragapult) -> Phantom Dive",
		["Torchic entered play this turn", "no Basic Energy in own discard"],
		passed
	))


func _scenario_c_drakloak_information_before_supporter() -> void:
	var processor := EffectProcessor.new()
	var state := _game_state()
	var dragapult := _real_slot(_real_card_data(DRAGAPULT_UID), 0)
	dragapult.attached_energy = [_real_instance(PSYCHIC_UID, 0)]
	var drakloak := _real_slot(_real_card_data(DRAKLOAK_UID), 0)
	var fire := _real_instance(FIRE_UID, 0)
	var iono := _real_instance(IONO_UID, 0)
	var filler := _filler_instance("VISIBLE_AFTER_TOP_TWO", 0)
	state.players[0].active_pokemon = dragapult
	state.players[0].bench = [drakloak]
	state.players[0].deck = [fire, iono, filler]
	state.players[1].active_pokemon = _real_target("Public scout target", 220, 2)
	processor.register_pokemon_card(drakloak.get_card_data())

	var ability_effect := processor.get_ability_effect(drakloak, 0, state)
	var steps: Array = ability_effect.get_interaction_steps(drakloak.get_top_card(), state) \
		if ability_effect != null else []
	var top_step := _step(steps, "look_top_pick")
	var exact_top_scope := str(top_step.get("visible_scope", "")) == "own_top_2_cards" \
		and (top_step.get("card_items", []) as Array) == [fire, iono] \
		and not JSON.stringify(top_step).contains("FORBIDDEN_SECRET")

	var before := _observation(
		[
			_ability("ability:recon-directive", "slot:drakloak", DRAKLOAK_UID, true),
			_play_trainer("supporter:iono-before-scout", IONO_UID, false),
			_end_turn("end:before-scout"),
		],
		_slot("slot:active", DRAGAPULT_UID, [_psychic_energy()]),
		[_slot("slot:drakloak", DRAKLOAK_UID, [])],
		3
	)
	before["observation_version"] = 1
	before["observation_hash"] = "blaziken-dragapult-before-recon"
	var facts_before := _facts(false, false, true, 0, false, false, 70)
	var scout_frontier := _frontier(before, {
		"ability:recon-directive": 530.0,
		"supporter:iono-before-scout": 500.0,
		"end:before-scout": -900.0,
	}, facts_before, "ability:recon-directive")
	var scout_candidate := _candidate(scout_frontier, "ability:recon-directive")
	var scouted := processor.execute_ability_effect(drakloak, 0, [{"look_top_pick": [fire]}], state)
	var fire_in_hand := fire in state.players[0].hand
	var unchosen_bottomed := state.players[0].deck == [filler, iono]

	var after := before.duplicate(true)
	after["observation_version"] = 2
	after["observation_hash"] = "blaziken-dragapult-after-recon"
	after["own"]["hand"] = [_fire_energy()]
	after["own"]["deck_count"] = 2
	after["legal_actions"] = [
		_play_trainer("supporter:iono-after-scout", IONO_UID, false),
		_attach_energy("attach:scouted-fire-to-dragapult", FIRE_UID, "slot:active"),
	]
	var facts_after := _facts(false, false, true, 1, false, false, 70)
	var reopened := _epoch_reopens(before, after, facts_before, facts_after, scout_candidate, scout_frontier)
	var attach_frontier := _frontier(after, {
		"supporter:iono-after-scout": 600.0,
		"attach:scouted-fire-to-dragapult": 590.0,
	}, facts_after, "supporter:iono-after-scout")
	var attach_candidate := _candidate(attach_frontier, "attach:scouted-fire-to-dragapult")
	var certificate := CapabilityRegistryScript.new().verify_route_advantage(
		attach_candidate, attach_frontier[0], facts_after, _profile)
	var attach_safety := _route_safety(attach_candidate, attach_frontier, facts_after)

	state.players[0].hand.erase(fire)
	dragapult.attached_energy.append(fire)
	var attack_ready := RuleValidator.new().can_use_attack(state, 0, 1, processor)
	var empty_does_not_reopen := not _epoch_reopens(
		before, before.duplicate(true), facts_before, facts_before, scout_candidate, scout_frontier, false)

	var passed := exact_top_scope and scouted and fire_in_hand and unchosen_bottomed and reopened \
		and bool(certificate.get("verified", false)) \
		and str(certificate.get("certificate_kind", "")) == "public_typed_attack_cost_completion" \
		and bool(attach_safety.get("valid", false)) and attack_ready and empty_does_not_reopen
	_check(passed, "scenario C must use real Drakloak top-two scope and certify Fire attachment before Iono")
	_rows.append(_row(
		"drakloak_information_before_supporter",
		"侦察/支援者顺序/信息epoch",
		"多龙仅缺火能时，多龙奇先查看公开的牌库顶2张并拿火能，剩余奇树置底；成功侦察重开信息epoch，带公开费用补齐证书的手贴必须先于奇树。",
		"Recon Directive(Fire) -> information_result -> attach Fire before Iono",
		["ability failed or selected no card", "attachment does not complete both printed colors"],
		passed
	))


func _scenario_d_chi_yu_minimum_fire_acceleration() -> void:
	var positive := _chi_yu_acceleration_fixture()
	var processor: EffectProcessor = positive.get("processor")
	var state: GameState = positive.get("state")
	var chi_yu: PokemonSlot = positive.get("chi_yu")
	var dragapult: PokemonSlot = positive.get("dragapult")
	var fire_a: CardInstance = positive.get("fire_a")
	var fire_b: CardInstance = positive.get("fire_b")
	var effects := processor.get_attack_effects_for_slot(chi_yu, 0)
	var energy_step: Dictionary = {}
	var target_step: Dictionary = {}
	for effect: BaseEffect in effects:
		var steps: Array = effect.get_attack_interaction_steps(
			chi_yu.get_top_card(), chi_yu.get_card_data().attacks[0], state)
		if energy_step.is_empty():
			energy_step = _step(steps, "discard_energy")
		if target_step.is_empty():
			target_step = _step(steps, "attach_target")
	var legal := RuleValidator.new().can_use_attack(state, 0, 0, processor)
	var exact_steps := int(energy_step.get("min_select", -1)) == 0 \
		and int(energy_step.get("max_select", -1)) == 2 \
		and fire_a in (energy_step.get("items", []) as Array) \
		and fire_b in (energy_step.get("items", []) as Array) \
		and dragapult in (target_step.get("items", []) as Array)
	var executed := processor.execute_attack_effect(chi_yu, 0, state.players[1].active_pokemon, state, [{
		"discard_energy": [fire_a],
		"attach_target": [dragapult],
	}])
	var minimal_ready := _slot_has_symbols(dragapult, ["R", "P"]) \
		and fire_b in state.players[0].discard_pile \
		and fire_a in dragapult.attached_energy

	var overcommit := _chi_yu_acceleration_fixture()
	var over_processor: EffectProcessor = overcommit.get("processor")
	var over_state: GameState = overcommit.get("state")
	var over_chi_yu: PokemonSlot = overcommit.get("chi_yu")
	var over_dragapult: PokemonSlot = overcommit.get("dragapult")
	var over_fire_a: CardInstance = overcommit.get("fire_a")
	var over_fire_b: CardInstance = overcommit.get("fire_b")
	var over_executed := over_processor.execute_attack_effect(
		over_chi_yu, 0, over_state.players[1].active_pokemon, over_state, [{
			"discard_energy": [over_fire_a, over_fire_b],
			"attach_target": [over_dragapult],
		}]
	)
	var over_same_ready := _slot_has_symbols(over_dragapult, ["R", "P"])
	var over_spent_extra := over_state.players[0].discard_pile.is_empty() \
		and over_dragapult.attached_energy.size() == 3

	var passed := legal and exact_steps and executed and minimal_ready \
		and over_executed and over_same_ready and over_spent_extra
	_check(passed, "scenario D must prove one Fire is the minimal real Chi-Yu acceleration while two overcommits")
	_rows.append(_row(
		"chi_yu_minimum_fire_acceleration",
		"攻击填能/资源保留",
		"古玉鱼用闪焰生成时，多龙已有超能且只缺火能；真实交互允许从弃牌选0至2火能并指定己方目标。只附1火就补齐幻影潜袭，另一火应留给下一只攻击手或沸腾斗志。",
		"Flare Bringer: exactly 1 Fire -> Psychic-only Dragapult",
		["selecting 2 Fire reaches the same attack state but consumes one extra discard resource", "targeting another slot leaves Dragapult incomplete"],
		passed
	))


func _scenario_e_phantom_dive_four_prize_closeout() -> void:
	var processor := EffectProcessor.new()
	var state := _phantom_closeout_state()
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
			{"target": bench_a, "amount": 30},
			{"target": bench_b, "amount": 30},
		],
	}])
	var active_damage := _base_attack_damage(dragapult.get_card_data(), 1)
	var split_prizes := (2 if active_damage >= state.players[1].active_pokemon.get_remaining_hp() else 0) \
		+ (1 if bench_a.damage_counters >= bench_a.get_remaining_hp() else 0) \
		+ (1 if bench_b.damage_counters >= bench_b.get_remaining_hp() else 0)

	var negative_processor := EffectProcessor.new()
	var negative_state := _phantom_closeout_state()
	var negative_dragapult := negative_state.players[0].active_pokemon
	var negative_a := negative_state.players[1].bench[0]
	var negative_b := negative_state.players[1].bench[1]
	negative_processor.register_pokemon_card(negative_dragapult.get_card_data())
	var negative_executed := negative_processor.execute_attack_effect(
		negative_dragapult, 1, negative_state.players[1].active_pokemon, negative_state, [{
			"bench_damage_counters": [{"target": negative_a, "amount": 60}],
		}]
	)
	var stacked_prizes := 2 \
		+ (1 if negative_a.damage_counters >= negative_a.get_remaining_hp() else 0) \
		+ (1 if negative_b.damage_counters >= negative_b.get_remaining_hp() else 0)

	var attack := _attack("attack:phantom-four-prize-closeout", DRAGAPULT_UID, 1, 200, true)
	attack["requires_interaction"] = true
	var observation := _observation(
		[
			_play_trainer("supporter:iono-too-late", IONO_UID, false),
			attack,
		],
		_slot("slot:active", DRAGAPULT_UID, [_fire_energy(), _psychic_energy()]),
		[],
		6
	)
	observation["own"]["prizes_remaining"] = 4
	observation["opponent"]["active"] = _public_target("PUBLIC_200_HP_EX", 200, 2)
	observation["opponent"]["bench"] = [
		_public_target("PUBLIC_30_HP_SINGLE_A", 30, 1),
		_public_target("PUBLIC_30_HP_SINGLE_B", 30, 1),
	]
	var facts := _facts(true, true, false, 3, true, false, 200)
	facts["resources"]["prizes_remaining"] = 4
	facts["prize"] = {"current_swing": 4, "win_now": true}
	var frontier := _frontier(observation, {
		"supporter:iono-too-late": 700.0,
		"attack:phantom-four-prize-closeout": 10.0,
	}, facts, "supporter:iono-too-late")
	var attack_candidate := _candidate(frontier, "attack:phantom-four-prize-closeout")
	var safety := _route_safety(attack_candidate, frontier, facts)

	var passed := legal and exact_distribution_contract and executed \
		and bench_a.damage_counters == 30 and bench_b.damage_counters == 30 \
		and split_prizes == 4 and negative_executed and stacked_prizes == 3 \
		and bool(safety.get("valid", false)) \
		and str(safety.get("reason", "")) == "deterministic_prize_gain"
	_check(passed, "scenario E must split real Phantom Dive counters for the public four-prize terminal: %s" % JSON.stringify({
		"legal": legal,
		"exact_distribution_contract": exact_distribution_contract,
		"executed": executed,
		"bench_a_damage": bench_a.damage_counters,
		"bench_b_damage": bench_b.damage_counters,
		"split_prizes": split_prizes,
		"negative_executed": negative_executed,
		"stacked_prizes": stacked_prizes,
		"safety": safety,
	}))
	_rows.append(_row(
		"phantom_dive_four_prize_closeout",
		"铺伤/多奖终结",
		"己方剩4奖时，幻影潜袭200击倒对手200HP双奖前台，并把6个伤害指示物按3+3放到两只30HP单奖备战，形成2+1+1四奖终结。",
		"Phantom Dive 200 + counters 3/3 for a four-Prize win",
		["stacking all 6 counters on one 30 HP Bench yields only three Prizes", "either Bench target above 30 HP breaks the terminal"],
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
		"observation_hash": "blaziken-dragapult-complex-scenario",
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
	return {
		"slot_id": slot_id,
		"pokemon": _card(uid),
		"energy": energy,
		"energy_count": energy.size(),
		"remaining_hp": 320 if uid in [DRAGAPULT_UID, BLAZIKEN_UID] else 90,
		"max_hp": 320 if uid in [DRAGAPULT_UID, BLAZIKEN_UID] else 90,
		"prize_count": 2 if uid in [DRAGAPULT_UID, BLAZIKEN_UID] else 1,
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
		"card": _energy_card(uid),
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
	return _energy_card(FIRE_UID)


func _psychic_energy() -> Dictionary:
	return _energy_card(PSYCHIC_UID)


func _energy_card(uid: String) -> Dictionary:
	var card := _card(uid)
	var symbol := "R" if uid == FIRE_UID else "P"
	card["energy_type"] = symbol
	card["energy_provides"] = symbol
	var roles: Array = card.get("semantic_roles", []) if card.get("semantic_roles", []) is Array else []
	if "basic_energy" not in roles:
		roles.append("basic_energy")
	card["semantic_roles"] = roles
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


func _slot_has_symbols(slot: PokemonSlot, required: Array[String]) -> bool:
	var present: Array[String] = []
	for energy: CardInstance in slot.attached_energy:
		if energy != null and energy.card_data != null:
			present.append(str(energy.card_data.energy_provides))
	for symbol: String in required:
		if symbol not in present:
			return false
	return true


func _chi_yu_acceleration_fixture() -> Dictionary:
	var processor := EffectProcessor.new()
	var state := _game_state()
	var chi_yu := _real_slot(_real_card_data(CHI_YU_UID), 0)
	chi_yu.attached_energy = [_real_instance(FIRE_UID, 0)]
	var dragapult := _real_slot(_real_card_data(DRAGAPULT_UID), 0)
	dragapult.attached_energy = [_real_instance(PSYCHIC_UID, 0)]
	var fire_a := _real_instance(FIRE_UID, 0)
	var fire_b := _real_instance(FIRE_UID, 0)
	state.players[0].active_pokemon = chi_yu
	state.players[0].bench = [dragapult]
	state.players[0].discard_pile = [fire_a, fire_b]
	state.players[1].active_pokemon = _real_target("Public acceleration target", 200, 1)
	processor.register_pokemon_card(chi_yu.get_card_data())
	return {
		"processor": processor,
		"state": state,
		"chi_yu": chi_yu,
		"dragapult": dragapult,
		"fire_a": fire_a,
		"fire_b": fire_b,
	}


func _phantom_closeout_state() -> GameState:
	var state := _game_state()
	var dragapult := _real_slot(_real_card_data(DRAGAPULT_UID), 0)
	dragapult.attached_energy = [_real_instance(FIRE_UID, 0), _real_instance(PSYCHIC_UID, 0)]
	state.players[0].active_pokemon = dragapult
	state.players[1].active_pokemon = _real_target("Public 200 HP ex", 200, 2)
	state.players[1].bench = [
		_real_target("Public 30 HP single A", 30, 1),
		_real_target("Public 30 HP single B", 30, 1),
	]
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


func _write_report() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT_PATH.get_base_dir()))
	var report := {
		"schema_version": 1,
		"architecture": "V18CPG",
		"semantic_schema": "v18cpg-2",
		"transport_contract_version": 3,
		"deck_id": DECK_ID,
		"deck_name": "18.0 火焰鸡多龙巴鲁托",
		"strategy_id": str(_profile.get("strategy_id", "")),
		"profile_version": int(_profile.get("profile_version", 0)),
		"baseline": {
			"status": "pending_real_model_round00",
			"artifact": "res://tmp/v18cpg/optimization21/800019125/round00.json",
			"artifact_exists": FileAccess.file_exists("res://tmp/v18cpg/optimization21/800019125/round00.json"),
			"seed_base": DECK_ID,
		},
		"scope": "focused scenario preparation only; no real-model formal benchmark",
		"scenario_count": _rows.size(),
		"passed_count": _rows.filter(func(row: Dictionary) -> bool: return bool(row.get("passed", false))).size(),
		"all_passed": _failures.is_empty() and _rows.size() == 5,
		"production_status": "scenario_contract_ready_not_promoted",
		"known_production_gaps": [
			"No deck-local promotion or aggregate win-rate claim is made by these five fixtures.",
			"The one-Fire Chi-Yu choice is proved through the real effect path but still needs a production interaction certificate before a formal round.",
			"The real Phantom Dive 2+1+1 closeout is proved, but the current frontier exposes deterministic_prize_gain rather than a four-Prize win_now certificate.",
			"A real-model round00 and paired-seed comparison against the exact Rule floor remain pending.",
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
			"Rare Candy Blaziken ex into real Boiling Spirit typed-energy completion",
			"Drakloak top-two visibility and information epoch before Iono",
			"Chi-Yu minimum Fire acceleration versus two-Fire overcommit",
			"Phantom Dive 200 plus 3/3 Bench counters for a four-Prize terminal",
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
