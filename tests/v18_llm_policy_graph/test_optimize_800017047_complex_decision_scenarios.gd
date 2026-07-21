extends SceneTree

const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const RouteSearchScript = preload("res://scripts/ai/v18_cpg/planning/V18CPGRouteSearch.gd")
const CapabilityRegistryScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCapabilityRegistry.gd")
const MaterialDeltaScript = preload("res://scripts/ai/v18_cpg/observation/V18CPGMaterialDelta.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")

const DECK_ID := 800017047
const MANIFEST_PATH := "res://scripts/ai/v18_cpg/profiles/generated_semantic_manifests/800017047.json"
const REPORT_PATH := "res://tmp/v18cpg/optimization21/800017047/complex_decision_scenarios.json"

const SWINUB_UID := "CSV10C_102"
const PILOSWINE_UID := "CSV10C_103"
const MAMOSWINE_UID := "CSV10C_104"
const PIDGEOT_UID := "CSV4C_101"
const TORCHIC_UID := "CSV7C_036"
const COMBUSKEN_UID := "CSV7C_037"
const BLAZIKEN_UID := "CSV7C_038"
const IONO_UID := "CSV3C_123"
const RARE_CANDY_UID := "CSVH1C_045"
const FIGHTING_UID := "CSVE1C_FIG"
const FIRE_UID := "CSVE1C_FIR"
const REVERSAL_UID := "CSV2C_128"

var _profile: Dictionary = {}
var _manifest: Dictionary = {}
var _failures: Array[String] = []
var _rows: Array[Dictionary] = []


func _initialize() -> void:
	_profile = ProfileCatalogScript.get_profile_for_deck(DECK_ID)
	_manifest = _load_json(MANIFEST_PATH)
	_check(int(_profile.get("deck_id", 0)) == DECK_ID, "production Mamoswine Blaziken profile must load")
	_check(int(_manifest.get("deck_id", 0)) == DECK_ID, "Mamoswine Blaziken semantic manifest must load")
	_check(_profile.get("modules", []) == ["stage2_chain", "energy_burst", "cycle_pivot"], \
		"scenarios must use the production stage2/energy/cycle module composition")

	_scenario_a_mamoswine_search_unlocks_second_stage2()
	_scenario_b_blaziken_accelerates_mamoswine_exactly()
	_scenario_c_mamoswine_typed_payment_and_bench_damage()
	_scenario_d_iono_before_mammoth_and_quick_search()
	_scenario_e_final_two_prizes_before_optional_churn()
	_write_report()

	EffectProcessor.cleanup_live_instances_for_tests()
	if _failures.is_empty() and _rows.size() == 5:
		print("optimization21 800017047 complex decision scenarios: PASS (5/5)")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("optimization21 800017047 complex decision scenarios: FAIL (%d)" % _failures.size())
	quit(1)


func _scenario_a_mamoswine_search_unlocks_second_stage2() -> void:
	var processor := EffectProcessor.new()
	var state := _game_state()
	var swinub := _real_slot(_real_card_data(SWINUB_UID), 0)
	var torchic := _real_slot(_real_card_data(TORCHIC_UID), 0)
	swinub.turn_played = 2
	torchic.turn_played = 2
	state.players[0].active_pokemon = swinub
	state.players[0].bench = [torchic]
	state.players[1].active_pokemon = _real_target("Public setup target", 250, 2)
	var candy_a := _real_instance(RARE_CANDY_UID, 0)
	var candy_b := _real_instance(RARE_CANDY_UID, 0)
	var mamoswine := _real_instance(MAMOSWINE_UID, 0)
	var blaziken := _real_instance(BLAZIKEN_UID, 0)
	state.players[0].hand = [candy_a, candy_b, mamoswine]
	state.players[0].deck = [
		blaziken,
		_real_instance(PILOSWINE_UID, 0),
		_real_instance(COMBUSKEN_UID, 0),
		_filler_instance("VISIBLE_STAGE2_FILLER", 0),
	]

	var validator := RuleValidator.new()
	var direct_stage2_blocked := not validator.can_evolve(state, 0, swinub, mamoswine, processor)
	var candy_effect := processor.get_effect(candy_a.card_data.effect_id)
	var first_steps: Array = candy_effect.get_interaction_steps(candy_a, state) if candy_effect != null else []
	var first_stage2 := _step(first_steps, "stage2_card")
	var first_target := _step(first_steps, "target_pokemon")
	var mamoswine_only_first := mamoswine in (first_stage2.get("items", []) as Array) \
		and blaziken not in (first_stage2.get("items", []) as Array) \
		and swinub in (first_target.get("items", []) as Array) \
		and torchic not in (first_target.get("items", []) as Array)
	processor.execute_card_effect(candy_a, [{
		"stage2_card": [mamoswine],
		"target_pokemon": [torchic],
	}], state)
	var wrong_root_rejected := torchic.get_card_data().get_uid() == TORCHIC_UID \
		and mamoswine in state.players[0].hand
	var first_candy := processor.execute_card_effect(candy_a, [{
		"stage2_card": [mamoswine],
		"target_pokemon": [swinub],
	}], state)
	state.players[0].hand.erase(candy_a)
	state.players[0].discard_pile.append(candy_a)
	processor.register_pokemon_card(mamoswine.card_data)

	var before := _observation(
		[
			_ability("ability:mammoth-hauling", "slot:mamoswine", MAMOSWINE_UID, true),
			_play_trainer("supporter:iono-too-early", IONO_UID, false),
			_end_turn("end:before-second-stage2"),
		],
		_slot("slot:mamoswine", MAMOSWINE_UID, []),
		[_slot("slot:torchic", TORCHIC_UID, [])],
		4
	)
	before["observation_version"] = 1
	before["observation_hash"] = "mamoswine-blaziken-before-mammoth-search"
	var facts_before := _facts(false, false, false, 2, false, false, 180, 6)
	var frontier := _frontier(before, {
		"ability:mammoth-hauling": 550.0,
		"supporter:iono-too-early": 510.0,
		"end:before-second-stage2": -900.0,
	}, facts_before, "ability:mammoth-hauling")
	var search_candidate := _candidate(frontier, "ability:mammoth-hauling")

	var mammoth_effect := processor.get_ability_effect(swinub, 0, state)
	var search_steps: Array = mammoth_effect.get_interaction_steps(mamoswine, state) \
		if mammoth_effect != null else []
	var search_step := _step(search_steps, "search_cards")
	var pokemon_only_search := str(search_step.get("visible_scope", "")) == "own_full_deck" \
		and blaziken in (search_step.get("items", []) as Array) \
		and (search_step.get("items", []) as Array).all(func(item: Variant) -> bool:
			return item is CardInstance and (item as CardInstance).card_data.card_type == "Pokemon")
	var searched := processor.execute_ability_effect(swinub, 0, [{"search_cards": [blaziken]}], state)
	var ability_once := not processor.can_use_ability(swinub, state, 0)
	var blaziken_searched_to_hand := blaziken in state.players[0].hand

	var after_search := before.duplicate(true)
	after_search["observation_version"] = 2
	after_search["observation_hash"] = "mamoswine-blaziken-after-mammoth-search"
	after_search["own"]["hand"] = [_card(RARE_CANDY_UID), _card(BLAZIKEN_UID)]
	after_search["own"]["deck_count"] = 3
	after_search["legal_actions"] = [
		_evolve("evolve:candy-blaziken", BLAZIKEN_UID, "slot:torchic"),
		_play_trainer("supporter:iono-after-search", IONO_UID, false),
	]
	var facts_after := _facts(false, false, false, 2, false, false, 180, 6)
	var reopened := _epoch_reopens(before, after_search, facts_before, facts_after, search_candidate, frontier)
	var evolve_frontier := _frontier(after_search, {
		"evolve:candy-blaziken": 560.0,
		"supporter:iono-after-search": 520.0,
	}, facts_after, "evolve:candy-blaziken")
	var evolve_candidate := _candidate(evolve_frontier, "evolve:candy-blaziken")
	var stage2_annotation := _module_annotation(evolve_candidate, "stage2_chain")
	var stage2_contract: bool = bool(stage2_annotation.get("evolution_progress", false)) \
		and "resolve_stage2_dependency_order" in stage2_annotation.get("decision_hints", [])

	var second_steps: Array = candy_effect.get_interaction_steps(candy_b, state) if candy_effect != null else []
	var second_exact := blaziken in (_step(second_steps, "stage2_card").get("items", []) as Array) \
		and torchic in (_step(second_steps, "target_pokemon").get("items", []) as Array)
	var second_candy := processor.execute_card_effect(candy_b, [{
		"stage2_card": [blaziken],
		"target_pokemon": [torchic],
	}], state)
	state.players[0].hand.erase(candy_b)
	state.players[0].discard_pile.append(candy_b)

	var fresh_state := _game_state()
	var fresh_root := _real_slot(_real_card_data(SWINUB_UID), 0)
	fresh_root.turn_played = fresh_state.turn_number
	fresh_state.players[0].active_pokemon = fresh_root
	var fresh_candy := _real_instance(RARE_CANDY_UID, 0)
	fresh_state.players[0].hand = [fresh_candy, _real_instance(MAMOSWINE_UID, 0)]
	fresh_state.players[0].deck = [_real_instance(PILOSWINE_UID, 0)]
	var fresh_root_blocked := candy_effect != null and not candy_effect.can_execute(fresh_candy, fresh_state)

	var passed: bool = direct_stage2_blocked and mamoswine_only_first and wrong_root_rejected \
		and first_candy and swinub.get_card_data().get_uid() == MAMOSWINE_UID \
		and pokemon_only_search and searched and blaziken_searched_to_hand and ability_once \
		and reopened and stage2_contract and second_exact and second_candy \
		and torchic.get_card_data().get_uid() == BLAZIKEN_UID and fresh_root_blocked
	_check(passed, "scenario A must Candy Mamoswine first, search Blaziken, then Candy the second old root: %s" % JSON.stringify({
		"direct_stage2_blocked": direct_stage2_blocked,
		"mamoswine_only_first": mamoswine_only_first,
		"wrong_root_rejected": wrong_root_rejected,
		"first_candy": first_candy,
		"first_uid": swinub.get_card_data().get_uid(),
		"pokemon_only_search": pokemon_only_search,
		"searched": searched,
		"blaziken_searched_to_hand": blaziken_searched_to_hand,
		"ability_once": ability_once,
		"reopened": reopened,
		"stage2_contract": stage2_contract,
		"second_exact": second_exact,
		"second_candy": second_candy,
		"second_uid": torchic.get_card_data().get_uid(),
		"fresh_root_blocked": fresh_root_blocked,
	}))
	_rows.append(_row(
		"mamoswine_search_unlocks_second_stage2",
		"双Stage2进化顺序",
		"手牌只有象牙猪ex而火焰鸡ex仍在牌库时，先用神奇糖果把旧小山猪变成象牙猪ex；猛犸搬运公开检索火焰鸡ex后，再用第二张糖果进化旧火稚鸡。",
		"Rare Candy(Mamoswine ex) -> Mammoth Hauling(Blaziken ex) -> Rare Candy(Blaziken ex)",
		["普通进化不能从小山猪直上Stage 2", "糖果不能进化错误根", "本回合刚下场的根不能糖果进化", "每张糖果只解决一条进化链"],
		passed
	))


func _scenario_b_blaziken_accelerates_mamoswine_exactly() -> void:
	var processor := EffectProcessor.new()
	var state := _game_state()
	var mamoswine := _real_slot(_real_card_data(MAMOSWINE_UID), 0)
	var blaziken := _real_slot(_real_card_data(BLAZIKEN_UID), 0)
	var fighting := _real_instance(FIGHTING_UID, 0)
	var fire := _real_instance(FIRE_UID, 0)
	var reversal := _real_instance(REVERSAL_UID, 0)
	var manual_fire := _real_instance(FIRE_UID, 0)
	mamoswine.attached_energy = [_real_instance(FIGHTING_UID, 0)]
	state.players[0].active_pokemon = mamoswine
	state.players[0].bench = [blaziken]
	state.players[0].discard_pile = [reversal, fighting, fire]
	state.players[0].hand = [manual_fire]
	state.players[1].active_pokemon = _real_target("Public acceleration target", 240, 2)
	processor.register_pokemon_card(mamoswine.get_card_data())
	processor.register_pokemon_card(blaziken.get_card_data())

	var validator := RuleValidator.new()
	var attack_blocked_before := not validator.can_use_attack(state, 0, 0, processor)
	var ability_effect := processor.get_ability_effect(blaziken, 0, state)
	var ability_steps: Array = ability_effect.get_interaction_steps(blaziken.get_top_card(), state) \
		if ability_effect != null else []
	var assignment_step := _step(ability_steps, "attach_basic_energy_from_discard")
	var source_items: Array = assignment_step.get("source_items", []) \
		if assignment_step.get("source_items", []) is Array else []
	var assignment_contract := str(assignment_step.get("ui_mode", "")) == "card_assignment" \
		and fighting in source_items and fire in source_items and reversal not in source_items \
		and mamoswine in (assignment_step.get("target_items", []) as Array) \
		and blaziken in (assignment_step.get("target_items", []) as Array)

	var before := _observation(
		[_ability("ability:boiling-spirit", "slot:blaziken", BLAZIKEN_UID, true), _end_turn("end:stale")],
		_slot("slot:mamoswine", MAMOSWINE_UID, [_fighting_energy()]),
		[_slot("slot:blaziken", BLAZIKEN_UID, [])],
		18
	)
	before["observation_version"] = 1
	before["observation_hash"] = "mamoswine-blaziken-before-boiling-spirit"
	before["own"]["discard"] = [_card(REVERSAL_UID), _fighting_energy(), _fire_energy()]
	before["own"]["hand"] = [_fire_energy()]
	var facts_before := _facts(false, false, false, 1, false, false, 180, 6)
	var frontier := _frontier(before, {
		"ability:boiling-spirit": 540.0,
		"end:stale": -900.0,
	}, facts_before, "ability:boiling-spirit")
	var ability_candidate := _candidate(frontier, "ability:boiling-spirit")

	var accelerated := processor.execute_ability_effect(blaziken, 0, [{
		"attach_basic_energy_from_discard": [{"source": fighting, "target": mamoswine}],
	}], state)
	var attack_ready_after := validator.can_use_attack(state, 0, 0, processor)
	var exact_resource_move := fighting in mamoswine.attached_energy \
		and fighting not in state.players[0].discard_pile \
		and fire in state.players[0].discard_pile \
		and reversal in state.players[0].discard_pile \
		and manual_fire in state.players[0].hand
	var once_per_turn := not processor.can_use_ability(blaziken, state, 0)

	var after := before.duplicate(true)
	after["observation_version"] = 2
	after["observation_hash"] = "mamoswine-blaziken-after-boiling-spirit"
	after["own"]["active"] = _slot("slot:mamoswine", MAMOSWINE_UID, [_fighting_energy(), _fighting_energy()])
	after["own"]["discard"] = [_card(REVERSAL_UID), _fire_energy()]
	after["legal_actions"] = [_attack("attack:rumbling-march-after-acceleration", MAMOSWINE_UID, 0, 220, false)]
	var facts_after := _facts(true, false, false, 1, false, false, 220, 6)
	var reopened := _epoch_reopens(before, after, facts_before, facts_after, ability_candidate, frontier)

	var special_only_state := _game_state()
	var special_blaziken := _real_slot(_real_card_data(BLAZIKEN_UID), 0)
	special_only_state.players[0].active_pokemon = special_blaziken
	special_only_state.players[0].discard_pile = [_real_instance(REVERSAL_UID, 0)]
	special_only_state.players[1].active_pokemon = _real_target("Public special-only target", 100, 1)
	processor.register_pokemon_card(special_blaziken.get_card_data())
	var special_energy_blocked := not processor.can_use_ability(special_blaziken, special_only_state, 0)

	var lock_state := _game_state(10)
	var attacking_blaziken := _real_slot(_real_card_data(BLAZIKEN_UID), 0)
	attacking_blaziken.attached_energy = [_real_instance(FIRE_UID, 0), _real_instance(FIGHTING_UID, 0)]
	lock_state.players[0].active_pokemon = attacking_blaziken
	lock_state.players[1].active_pokemon = _real_target("Public lock target", 300, 2)
	processor.register_pokemon_card(attacking_blaziken.get_card_data())
	var attack_legal_now := validator.can_use_attack(lock_state, 0, 0, processor)
	processor.execute_attack_effect(attacking_blaziken, 0, lock_state.players[1].active_pokemon, lock_state)
	lock_state.turn_number += 2
	var next_turn_locked := not validator.can_use_attack(lock_state, 0, 0, processor)

	var passed := attack_blocked_before and assignment_contract and accelerated \
		and attack_ready_after and exact_resource_move and once_per_turn and reopened \
		and special_energy_blocked and attack_legal_now and next_turn_locked
	_check(passed, "scenario B must bind one Basic Fighting from discard to Mamoswine and preserve all strict limits")
	_rows.append(_row(
		"blaziken_accelerates_mamoswine_exactly",
		"火焰鸡能量加速",
		"象牙猪ex已有1斗时，火焰鸡ex只把弃牌区的基本斗能量附给象牙猪，立刻补齐FF；逆转能量不是基本能量，手里的火能量保留给RC副攻线。",
		"Boiling Spirit(Fighting from discard -> Mamoswine ex) -> payable Rumbling March",
		["逆转能量不能被沸腾斗志选择", "特性每回合只能用一次", "燃烧旋踢会锁住火焰鸡下一己方回合的同名攻击"],
		passed
	))


func _scenario_c_mamoswine_typed_payment_and_bench_damage() -> void:
	var processor := EffectProcessor.new()
	var state := _mamoswine_damage_state(2, 260)
	var mamoswine: PokemonSlot = state.players[0].active_pokemon
	var validator := RuleValidator.new()
	processor.register_pokemon_card(mamoswine.get_card_data())
	var attack_blocked_before := not validator.can_use_attack(state, 0, 0, processor)

	var before := _observation(
		[
			_attach_energy("attach:wrong-fire-to-mamoswine", FIRE_UID, "slot:mamoswine"),
			_attach_energy("attach:second-fighting-to-mamoswine", FIGHTING_UID, "slot:mamoswine"),
		],
		_slot("slot:mamoswine", MAMOSWINE_UID, [_fighting_energy()]),
		[
			_slot("slot:blaziken", BLAZIKEN_UID, []),
			_slot("slot:pidgeot", PIDGEOT_UID, []),
			_slot("slot:piloswine", PILOSWINE_UID, []),
		],
		15
	)
	before["own"]["hand"] = [_fire_energy(), _fighting_energy()]
	var facts_before := _facts(false, false, true, 2, false, false, 180, 6)
	var frontier := _frontier(before, {
		"attach:wrong-fire-to-mamoswine": 600.0,
		"attach:second-fighting-to-mamoswine": 560.0,
	}, facts_before, "attach:wrong-fire-to-mamoswine")
	var fighting_candidate := _candidate(frontier, "attach:second-fighting-to-mamoswine")
	var fire_candidate := _candidate(frontier, "attach:wrong-fire-to-mamoswine")
	var certificate := CapabilityRegistryScript.new().verify_route_advantage(
		fighting_candidate, fire_candidate, facts_before, _profile)
	var fighting_safety := _route_safety(fighting_candidate, frontier, facts_before)
	var raw_stage2_typed: Variant = _module_annotation(fighting_candidate, "stage2_chain").get("typed_attachment", {})
	var stage2_typed: Dictionary = raw_stage2_typed as Dictionary if raw_stage2_typed is Dictionary else {}
	var typed_contract: bool = bool(stage2_typed.get("target_is_active", false)) \
		and stage2_typed.get("required_symbols", []) == ["F", "F"] \
		and bool(stage2_typed.get("completes_required_types", false))

	var fighting := _real_instance(FIGHTING_UID, 0)
	mamoswine.attached_energy.append(fighting)
	var attack_ready := validator.can_use_attack(state, 0, 0, processor)
	var bonus := _attack_bonus(processor, mamoswine, 0, state)
	var damage := DamageCalculator.new().calculate_damage(
		mamoswine,
		state.players[1].active_pokemon,
		mamoswine.get_card_data().attacks[0],
		state,
		bonus
	)
	var exact_damage := bonus == 80 and damage == 260
	var energy_not_consumed_as_payment := mamoswine.attached_energy.size() == 2

	var wrong_color_state := _mamoswine_damage_state(2, 260)
	var wrong_mamoswine: PokemonSlot = wrong_color_state.players[0].active_pokemon
	wrong_mamoswine.attached_energy.append(_real_instance(FIRE_UID, 0))
	var wrong_color_blocked := not validator.can_use_attack(wrong_color_state, 0, 0, processor)
	var one_stage_state := _mamoswine_damage_state(1, 230)
	var one_stage_mamoswine: PokemonSlot = one_stage_state.players[0].active_pokemon
	one_stage_mamoswine.attached_energy.append(_real_instance(FIGHTING_UID, 0))
	var one_stage_bonus := _attack_bonus(processor, one_stage_mamoswine, 0, one_stage_state)
	var one_stage_damage := DamageCalculator.new().calculate_damage(
		one_stage_mamoswine,
		one_stage_state.players[1].active_pokemon,
		one_stage_mamoswine.get_card_data().attacks[0],
		one_stage_state,
		one_stage_bonus
	)
	var stage_one_not_counted := one_stage_bonus == 40 and one_stage_damage == 220 \
		and one_stage_damage < one_stage_state.players[1].active_pokemon.get_remaining_hp()

	var passed: bool = attack_blocked_before and bool(certificate.get("verified", false)) \
		and str(certificate.get("certificate_kind", "")) == "public_typed_attack_cost_completion" \
		and str(fighting_safety.get("reason", "")) == "module_verified_advantage" \
		and typed_contract and attack_ready and exact_damage and energy_not_consumed_as_payment \
		and wrong_color_blocked and stage_one_not_counted
	_check(passed, "scenario C must certify FF payment and real 180+40-per-Bench-Stage2 damage")
	_rows.append(_row(
		"mamoswine_typed_payment_and_bench_damage",
		"象牙猪攻击支付/伤害",
		"象牙猪ex已有1斗时，第二张斗能量而非火能量补齐FF；备战区火焰鸡ex与大比鸟ex各提供40，猛犸行进从180精确到260。",
		"attach second Fighting -> Rumbling March 180 + 2x40 = 260",
		["斗+火不能支付FF", "战斗场上的Stage 2不计数", "备战区Stage 1不计数", "攻击费用是附着要求而不是弃能支付"],
		passed
	))


func _scenario_d_iono_before_mammoth_and_quick_search() -> void:
	var positive := _search_order_state()
	var processor: EffectProcessor = positive.get("processor")
	var state: GameState = positive.get("state")
	var mamoswine: PokemonSlot = positive.get("mamoswine")
	var pidgeot: PokemonSlot = positive.get("pidgeot")
	var iono: CardInstance = positive.get("iono")
	var blaziken: CardInstance = positive.get("blaziken")
	var candy: CardInstance = positive.get("candy")

	var before := _observation(
		[
			_play_trainer("supporter:iono-before-searches", IONO_UID, false),
			_ability("ability:mammoth-before-iono", "slot:mamoswine", MAMOSWINE_UID, true),
			_ability("ability:quick-search-before-iono", "slot:pidgeot", PIDGEOT_UID, true),
		],
		_slot("slot:mamoswine", MAMOSWINE_UID, [_fighting_energy(), _fighting_energy()]),
		[_slot("slot:pidgeot", PIDGEOT_UID, [])],
		8
	)
	before["observation_version"] = 1
	before["observation_hash"] = "mamoswine-blaziken-before-iono-reset"
	before["own"]["hand"] = [_card(IONO_UID), {"uid": "VISIBLE_STALE_HAND"}]
	var facts_before := _facts(true, false, false, 2, false, false, 180, 2)
	var frontier := _frontier(before, {
		"supporter:iono-before-searches": 570.0,
		"ability:mammoth-before-iono": 540.0,
		"ability:quick-search-before-iono": 530.0,
	}, facts_before, "supporter:iono-before-searches")
	var iono_candidate := _candidate(frontier, "supporter:iono-before-searches")

	var iono_executed := processor.execute_card_effect(iono, [], state)
	var reset_drew_exactly_two := state.players[0].hand.size() == 2 \
		and blaziken in state.players[0].deck and candy in state.players[0].deck
	var after_iono := before.duplicate(true)
	after_iono["observation_version"] = 2
	after_iono["observation_hash"] = "mamoswine-blaziken-after-iono-reset"
	after_iono["own"]["hand"] = [{"uid": "VISIBLE_DRAW_A"}, {"uid": "VISIBLE_DRAW_B"}]
	after_iono["own"]["deck_count"] = state.players[0].deck.size()
	after_iono["legal_actions"] = [
		_ability("ability:mammoth-after-iono", "slot:mamoswine", MAMOSWINE_UID, true),
		_ability("ability:quick-search-after-iono", "slot:pidgeot", PIDGEOT_UID, true),
	]
	var facts_after := _facts(true, false, false, 2, false, false, 180, 2)
	var reopened := _epoch_reopens(before, after_iono, facts_before, facts_after, iono_candidate, frontier)

	var mammoth_effect := processor.get_ability_effect(mamoswine, 0, state)
	var mammoth_steps: Array = mammoth_effect.get_interaction_steps(mamoswine.get_top_card(), state) \
		if mammoth_effect != null else []
	var mammoth_step := _step(mammoth_steps, "search_cards")
	var mammoth_scope := str(mammoth_step.get("visible_scope", "")) == "own_full_deck" \
		and blaziken in (mammoth_step.get("items", []) as Array) \
		and candy not in (mammoth_step.get("items", []) as Array)
	var mammoth_searched := processor.execute_ability_effect(
		mamoswine, 0, [{"search_cards": [blaziken]}], state)

	var quick_effect := processor.get_ability_effect(pidgeot, 0, state)
	var quick_steps: Array = quick_effect.get_interaction_steps(pidgeot.get_top_card(), state) \
		if quick_effect != null else []
	var quick_step := _step(quick_steps, "search_cards")
	var quick_scope := str(quick_step.get("visible_scope", "")) == "own_full_deck" \
		and candy in (quick_step.get("items", []) as Array)
	var quick_searched := processor.execute_ability_effect(
		pidgeot, 0, [{"search_cards": [candy]}], state)
	var exact_post_reset_hand := blaziken in state.players[0].hand and candy in state.players[0].hand
	var both_once := not processor.can_use_ability(mamoswine, state, 0) \
		and not processor.can_use_ability(pidgeot, state, 0)

	var negative := _search_order_state()
	var negative_processor: EffectProcessor = negative.get("processor")
	var negative_state: GameState = negative.get("state")
	var negative_mamoswine: PokemonSlot = negative.get("mamoswine")
	var negative_pidgeot: PokemonSlot = negative.get("pidgeot")
	var negative_iono: CardInstance = negative.get("iono")
	var negative_blaziken: CardInstance = negative.get("blaziken")
	var negative_candy: CardInstance = negative.get("candy")
	var searched_before_reset := negative_processor.execute_ability_effect(
		negative_mamoswine, 0, [{"search_cards": [negative_blaziken]}], negative_state) \
		and negative_processor.execute_ability_effect(
			negative_pidgeot, 0, [{"search_cards": [negative_candy]}], negative_state)
	var reset_after_search := negative_processor.execute_card_effect(negative_iono, [], negative_state)
	var premature_searches_lost := negative_blaziken not in negative_state.players[0].hand \
		and negative_candy not in negative_state.players[0].hand

	var passed := iono_executed and reset_drew_exactly_two and reopened \
		and mammoth_scope and mammoth_searched and quick_scope and quick_searched \
		and exact_post_reset_hand and both_once and searched_before_reset \
		and reset_after_search and premature_searches_lost
	_check(passed, "scenario D must reset first, then preserve exact Mammoth and Quick Search results")
	_rows.append(_row(
		"iono_before_mammoth_and_quick_search",
		"特性/支援者/抽牌顺序",
		"需要奇树换手时必须先结算奇树，再由象牙猪ex检索火焰鸡ex、由大比鸟ex检索神奇糖果；先检索再奇树会把两张确定牌一起放回牌库底。",
		"Iono -> information epoch -> Mammoth Hauling(Blaziken ex) -> Quick Search(Rare Candy)",
		["猛犸搬运只能检索宝可梦", "音速搜索每回合跨同名副本共享一次", "先检索再奇树会丢失确定手牌"],
		passed
	))


func _scenario_e_final_two_prizes_before_optional_churn() -> void:
	var processor := EffectProcessor.new()
	var state := _mamoswine_damage_state(2, 260)
	var mamoswine: PokemonSlot = state.players[0].active_pokemon
	mamoswine.attached_energy.append(_real_instance(FIGHTING_UID, 0))
	_fill_prizes(state.players[0], 2, "OWN_FINAL_PRIZE")
	processor.register_pokemon_card(mamoswine.get_card_data())
	var validator := RuleValidator.new()
	var attack_legal := validator.can_use_attack(state, 0, 0, processor)
	var bonus := _attack_bonus(processor, mamoswine, 0, state)
	var damage := DamageCalculator.new().calculate_damage(
		mamoswine,
		state.players[1].active_pokemon,
		mamoswine.get_card_data().attacks[0],
		state,
		bonus
	)
	var real_terminal := damage == 260 \
		and damage >= state.players[1].active_pokemon.get_remaining_hp() \
		and _prize_count(state.players[1].active_pokemon) >= state.players[0].prizes.size()

	var observation := _observation(
		[
			_attack("attack:final-rumbling-march", MAMOSWINE_UID, 0, 260, true),
			_ability("ability:optional-mammoth", "slot:mamoswine", MAMOSWINE_UID, true),
			_play_trainer("supporter:optional-iono", IONO_UID, false),
		],
		_slot("slot:mamoswine", MAMOSWINE_UID, [_fighting_energy(), _fighting_energy()]),
		[_slot("slot:blaziken", BLAZIKEN_UID, []), _slot("slot:pidgeot", PIDGEOT_UID, [])],
		4
	)
	observation["own"]["prizes_remaining"] = 2
	observation["opponent"]["active"] = _public_target("PUBLIC_FINAL_EX", 260, 2)
	var facts := _facts(true, true, false, 2, true, true, 260, 2)
	facts["prize"]["win_now"] = true
	var frontier := _frontier(observation, {
		"attack:final-rumbling-march": 520.0,
		"ability:optional-mammoth": 510.0,
		"supporter:optional-iono": 500.0,
	}, facts, "attack:final-rumbling-march")
	var attack_candidate := _candidate(frontier, "attack:final-rumbling-march")
	var ability_candidate := _candidate(frontier, "ability:optional-mammoth")
	var iono_candidate := _candidate(frontier, "supporter:optional-iono")
	var energy_annotation := _module_annotation(ability_candidate, "energy_burst")
	var attack_is_win_now := bool(attack_candidate.get("outcome", {}).get("win_now", false)) \
		and int(attack_candidate.get("outcome", {}).get("prizes_now", 0)) == 2
	var optional_information_unsafe := not bool(energy_annotation.get("optional_information_safe", true))
	var ability_blocked := not bool(_route_safety(ability_candidate, frontier, facts).get("valid", true))
	var iono_blocked := not bool(_route_safety(iono_candidate, frontier, facts).get("valid", true))

	var one_stage_state := _mamoswine_damage_state(1, 250)
	var one_stage_mamoswine: PokemonSlot = one_stage_state.players[0].active_pokemon
	one_stage_mamoswine.attached_energy.append(_real_instance(FIGHTING_UID, 0))
	var one_stage_damage := 180 + _attack_bonus(processor, one_stage_mamoswine, 0, one_stage_state)
	var hp_261_state := _mamoswine_damage_state(2, 261)
	var hp_261_mamoswine: PokemonSlot = hp_261_state.players[0].active_pokemon
	hp_261_mamoswine.attached_energy.append(_real_instance(FIGHTING_UID, 0))
	var hp_261_damage := 180 + _attack_bonus(processor, hp_261_mamoswine, 0, hp_261_state)
	var strict_nonterminals := one_stage_damage == 220 and one_stage_damage < 250 \
		and hp_261_damage == 260 and hp_261_damage < 261

	var passed := attack_legal and real_terminal and attack_is_win_now \
		and optional_information_unsafe and ability_blocked and iono_blocked and strict_nonterminals
	_check(passed, "scenario E must take the final two Prizes before optional search or Iono")
	_rows.append(_row(
		"final_two_prizes_before_optional_churn",
		"关键奖终局",
		"己方只剩2奖、对手260HP双奖前台时，FF象牙猪ex依靠两只备战Stage 2打出260并立即获胜；不得先开猛犸搬运或奇树。",
		"Rumbling March 260 for the final two Prizes",
		["只有1只备战Stage 2时220不能击倒250HP", "260不能击倒261HP", "已经锁定终局时禁止可选检索与换手"],
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


func _module_annotation(candidate: Dictionary, module_id: String) -> Dictionary:
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	return annotations.get(module_id, {}) if annotations.get(module_id, {}) is Dictionary else {}


func _observation(actions: Array, active: Dictionary, bench: Array, deck_count: int) -> Dictionary:
	return {
		"observation_version": 1,
		"observation_hash": "mamoswine-blaziken-complex-scenario",
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
			"active": _public_target("PUBLIC_OPPONENT_ACTIVE", 250, 2),
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
	max_damage: int,
	prizes_remaining: int
) -> Dictionary:
	return {
		"attack": {"ready": attack_ready, "ko_available": ko_available, "max_damage": max_damage},
		"turn": {"energy_available": energy_available, "supporter_available": true},
		"resources": {
			"deck_low": deck_low,
			"deck_critical": deck_critical,
			"hand_size": hand_size,
			"bench_slots_free": 3,
			"prizes_remaining": prizes_remaining,
			"energy_on_board": 0,
		},
		"board": {"bench_full": false, "has_tera": false},
		"information": {"material_action_available": true},
		"prize": {"current_swing": 0, "win_now": false},
		"route": {"current_valid": true},
	}


func _slot(slot_id: String, uid: String, energy: Array) -> Dictionary:
	var hp := 340 if uid == MAMOSWINE_UID else 320 if uid == BLAZIKEN_UID else 280 if uid == PIDGEOT_UID else 100
	return {
		"slot_id": slot_id,
		"pokemon": _card(uid),
		"energy": energy,
		"energy_count": energy.size(),
		"remaining_hp": hp,
		"max_hp": hp,
		"prize_count": 2 if uid in [MAMOSWINE_UID, BLAZIKEN_UID, PIDGEOT_UID] else 1,
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


func _evolve(action_id: String, uid: String, target: String) -> Dictionary:
	return {
		"id": action_id,
		"kind": "evolve",
		"card": _card(uid),
		"target": target,
		"requires_interaction": false,
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
		"source": "slot:mamoswine",
		"source_card": _card(uid),
		"attack_index": attack_index,
		"projected_damage": damage,
		"projected_knockout": knockout,
		"requires_interaction": false,
	}


func _end_turn(action_id: String) -> Dictionary:
	return {"id": action_id, "kind": "end_turn"}


func _fighting_energy() -> Dictionary:
	return _energy_card(FIGHTING_UID)


func _fire_energy() -> Dictionary:
	return _energy_card(FIRE_UID)


func _energy_card(uid: String) -> Dictionary:
	var card := _card(uid)
	var symbol := "F" if uid == FIGHTING_UID else "R" if uid == FIRE_UID else "C"
	card["energy_type"] = symbol
	card["energy_provides"] = symbol
	var roles: Array = card.get("semantic_roles", []) if card.get("semantic_roles", []) is Array else []
	if uid in [FIGHTING_UID, FIRE_UID] and "basic_energy" not in roles:
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


func _step(steps: Array, id: String) -> Dictionary:
	for raw_step: Variant in steps:
		if raw_step is Dictionary and str((raw_step as Dictionary).get("id", "")) == id:
			return raw_step as Dictionary
	return {}


func _attack_bonus(
	processor: EffectProcessor,
	attacker: PokemonSlot,
	attack_index: int,
	state: GameState
) -> int:
	var bonus := 0
	for effect: BaseEffect in processor.get_attack_effects_for_slot(attacker, attack_index):
		if effect.has_method("get_damage_bonus"):
			bonus += int(effect.call("get_damage_bonus", attacker, state))
	return bonus


func _mamoswine_damage_state(stage2_bench_count: int, target_hp: int) -> GameState:
	var state := _game_state()
	var mamoswine := _real_slot(_real_card_data(MAMOSWINE_UID), 0)
	mamoswine.attached_energy = [_real_instance(FIGHTING_UID, 0)]
	state.players[0].active_pokemon = mamoswine
	if stage2_bench_count >= 1:
		state.players[0].bench.append(_real_slot(_real_card_data(BLAZIKEN_UID), 0))
	if stage2_bench_count >= 2:
		state.players[0].bench.append(_real_slot(_real_card_data(PIDGEOT_UID), 0))
	state.players[0].bench.append(_real_slot(_real_card_data(PILOSWINE_UID), 0))
	state.players[1].active_pokemon = _real_target("Public damage target", target_hp, 2)
	return state


func _search_order_state() -> Dictionary:
	var processor := EffectProcessor.new()
	var state := _game_state()
	var mamoswine := _real_slot(_real_card_data(MAMOSWINE_UID), 0)
	var pidgeot := _real_slot(_real_card_data(PIDGEOT_UID), 0)
	var iono := _real_instance(IONO_UID, 0)
	var blaziken := _real_instance(BLAZIKEN_UID, 0)
	var candy := _real_instance(RARE_CANDY_UID, 0)
	state.players[0].active_pokemon = mamoswine
	state.players[0].bench = [pidgeot]
	state.players[0].hand = [iono, _filler_instance("VISIBLE_STALE_HAND", 0)]
	state.players[0].deck = [
		_filler_instance("VISIBLE_DRAW_A", 0),
		_filler_instance("VISIBLE_DRAW_B", 0),
		blaziken,
		candy,
		_filler_instance("VISIBLE_REMAINING_A", 0),
		_filler_instance("VISIBLE_REMAINING_B", 0),
	]
	_fill_prizes(state.players[0], 2, "OWN_IONO_PRIZE")
	_fill_prizes(state.players[1], 2, "OPP_IONO_PRIZE")
	state.players[1].active_pokemon = _real_target("Public Iono target", 250, 2)
	processor.register_pokemon_card(mamoswine.get_card_data())
	processor.register_pokemon_card(pidgeot.get_card_data())
	return {
		"processor": processor,
		"state": state,
		"mamoswine": mamoswine,
		"pidgeot": pidgeot,
		"iono": iono,
		"blaziken": blaziken,
		"candy": candy,
	}


func _fill_prizes(player: PlayerState, count: int, prefix: String) -> void:
	player.prizes.clear()
	for index: int in count:
		player.prizes.append(_filler_instance("%s_%d" % [prefix, index], player.player_index))


func _prize_count(slot: PokemonSlot) -> int:
	if slot == null or slot.get_card_data() == null:
		return 0
	return 2 if slot.get_card_data().mechanic == "ex" else 1


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
		"deck_name": "18.0 象牙猪火焰鸡",
		"strategy_id": str(_profile.get("strategy_id", "")),
		"profile_version": int(_profile.get("profile_version", 0)),
		"baseline": {
			"status": "pending_real_model_round00",
			"artifact": "res://tmp/v18cpg/optimization21/800017047/round00.json",
			"artifact_exists": FileAccess.file_exists("res://tmp/v18cpg/optimization21/800017047/round00.json"),
			"seed_base": DECK_ID,
		},
		"scope": "focused scenario preparation only; no real-model formal benchmark",
		"scenario_count": _rows.size(),
		"passed_count": _rows.filter(func(row: Dictionary) -> bool: return bool(row.get("passed", false))).size(),
		"all_passed": _failures.is_empty() and _rows.size() == 5,
		"production_status": "scenario_contract_ready_not_promoted",
		"known_production_gaps": [
			"No deck-local promotion or aggregate win-rate claim is made by these five fixtures.",
			"The two-Rare-Candy Stage 2 sequence and both search abilities are proved through real effects, but production still needs a bounded multi-step interaction certificate before autonomous takeover.",
			"Boiling Spirit's exact Basic Fighting assignment is proved through the real card-assignment path; the current generic energy module does not own that ability interaction.",
			"Rumbling March's real Bench Stage 2 damage and final-two-Prize terminal are proved, but the production frontier still relies on the engine-projected damage field.",
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
			"Mamoswine-first dual-Stage-2 Rare Candy dependency order",
			"Blaziken ex Basic Energy acceleration into exact Mamoswine FF payment",
			"Mamoswine ex 180 plus 40 per own Benched Stage 2 damage arithmetic",
			"Iono reset before Mammoth Hauling and Pidgeot ex Quick Search",
			"Rumbling March exact final-two-Prize closeout before optional churn",
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
