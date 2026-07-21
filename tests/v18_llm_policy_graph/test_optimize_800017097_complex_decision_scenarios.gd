extends SceneTree

const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const SemanticCompilerScript = preload("res://scripts/ai/v18_cpg/semantics/V18CPGDeckSemanticCompiler.gd")
const RouteSearchScript = preload("res://scripts/ai/v18_cpg/planning/V18CPGRouteSearch.gd")
const CapabilityRegistryScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCapabilityRegistry.gd")
const MaterialDeltaScript = preload("res://scripts/ai/v18_cpg/observation/V18CPGMaterialDelta.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")

const DECK_ID := 800017097
const DECK_SEED_PATH := "res://data/bundled_user/decks/800017097.json"
const MANIFEST_PATH := "res://scripts/ai/v18_cpg/profiles/generated_semantic_manifests/800017097.json"
const REPORT_PATH := "res://tmp/v18cpg/optimization21/800017097/complex_decision_scenarios.json"

const RALTS_UID := "CSV2C_053"
const KIRLIA_UID := "CSV2C_054"
const GARDEVOIR_UID := "CSV2C_055"
const DRIFLOON_UID := "CSV2C_060"
const SCREAM_TAIL_UID := "CSV6C_065"
const MUNKIDORI_UID := "CSV8C_094"
const FEZANDIPITI_UID := "CSV8C_135"
const IONO_UID := "CSV3C_123"
const RARE_CANDY_UID := "CSVH1C_045"
const BRAVERY_CHARM_UID := "CSV1C_118"
const PSYCHIC_UID := "CSVE1C_PSY"
const DARKNESS_UID := "CSVE1C_DAR"

var _profile: Dictionary = {}
var _manifest: Dictionary = {}
var _deck_seed: Dictionary = {}
var _current_fingerprint := ""
var _failures: Array[String] = []
var _rows: Array[Dictionary] = []


func _initialize() -> void:
	_profile = ProfileCatalogScript.get_profile_for_deck(DECK_ID)
	_manifest = _load_json(MANIFEST_PATH)
	_deck_seed = _load_json(DECK_SEED_PATH)
	var deck := DeckData.from_dict(_deck_seed)
	_current_fingerprint = SemanticCompilerScript.deck_content_fingerprint(deck)
	_check(int(_profile.get("deck_id", 0)) == DECK_ID, "production no-balloon Gardevoir profile must load")
	_check(int(_manifest.get("deck_id", 0)) == DECK_ID, "no-balloon Gardevoir semantic manifest must load")
	_check(_profile.get("modules", []) == ["gardevoir_embrace", "damage_counter_control"], \
		"scenarios must use the production Gardevoir/counter-control module composition")
	_check(int(deck.id) == DECK_ID and int(deck.total_cards) == 60, \
		"current bundled AI seed must be the exact 60-card deck")
	_check(_current_fingerprint != "" \
		and _current_fingerprint == str(_manifest.get("deck_content_fingerprint", "")), \
		"semantic manifest fingerprint must match the current bundled AI deck")

	_scenario_a_charm_before_embrace_unlocks_balloon_bomb()
	_scenario_b_rare_candy_resolves_the_old_ralts_chain()
	_scenario_c_iono_before_fezandipiti_preserves_both_draws()
	_scenario_d_adrena_brain_moves_only_the_lethal_counters()
	_scenario_e_scream_tail_takes_the_last_bench_prize()
	_write_report()

	EffectProcessor.cleanup_live_instances_for_tests()
	if _failures.is_empty() and _rows.size() == 5:
		print("optimization21 800017097 complex decision scenarios: PASS (5/5)")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("optimization21 800017097 complex decision scenarios: FAIL (%d)" % _failures.size())
	quit(1)


func _scenario_a_charm_before_embrace_unlocks_balloon_bomb() -> void:
	var processor := EffectProcessor.new()
	var state := _game_state()
	var drifloon := _real_slot(_real_card_data(DRIFLOON_UID), 0)
	var gardevoir := _real_slot(_real_card_data(GARDEVOIR_UID), 0)
	drifloon.damage_counters = 60
	drifloon.attached_energy = [
		_real_instance(PSYCHIC_UID, 0),
		_real_instance(PSYCHIC_UID, 0),
		_real_instance(PSYCHIC_UID, 0),
	]
	var psychic_a := _real_instance(PSYCHIC_UID, 0)
	var psychic_b := _real_instance(PSYCHIC_UID, 0)
	state.players[0].active_pokemon = drifloon
	state.players[0].bench = [gardevoir]
	state.players[0].discard_pile = [psychic_a, psychic_b]
	_fill_prizes(state.players[0], 2, "OWN_CHARM_PRIZE")
	state.players[1].active_pokemon = _real_target("Public 300 HP target", 300, 2)
	processor.register_pokemon_card(drifloon.get_card_data())
	processor.register_pokemon_card(gardevoir.get_card_data())

	var embrace_effect := processor.get_ability_effect(gardevoir, 0, state)
	var blocked_without_tool := embrace_effect != null \
		and not bool(embrace_effect.call("can_use_embrace_on_target", drifloon, state))
	var observation := _observation(
		[
			_ability("ability:premature-embrace", "slot:gardevoir", GARDEVOIR_UID, true),
			_attach_tool("tool:charm-drifloon", BRAVERY_CHARM_UID, "slot:drifloon"),
			_end_turn("end:missed-balloon-line"),
		],
		_slot("slot:drifloon", DRIFLOON_UID, [_psychic_energy(), _psychic_energy(), _psychic_energy()], 60, 10, 70, 1),
		[_slot("slot:gardevoir", GARDEVOIR_UID, [], 0, 310, 310, 2)],
		_public_target("PUBLIC_300_HP_EX", 300, 2),
		[],
		20,
		2
	)
	observation["own"]["discard"] = [_psychic_energy(), _psychic_energy()]
	observation["own"]["hand"] = [_card(BRAVERY_CHARM_UID)]
	var facts := _facts(true, false, false, 1, false, false, 180, 2)
	var frontier := _frontier(observation, {
		"ability:premature-embrace": 700.0,
		"tool:charm-drifloon": 620.0,
		"end:missed-balloon-line": -900.0,
	}, facts, "ability:premature-embrace")
	var tool_candidate := _candidate(frontier, "tool:charm-drifloon")
	var tool_annotation: Dictionary = _module_annotation(tool_candidate, "gardevoir_embrace").get("prize_scaler_tool", {})
	var certificate_exact := tool_annotation is Dictionary \
		and bool((tool_annotation as Dictionary).get("crosses_public_ko_threshold", false)) \
		and bool((tool_annotation as Dictionary).get("wins_now_after_public_embrace_sequence", false)) \
		and int((tool_annotation as Dictionary).get("required_assignments", 0)) == 2 \
		and int((tool_annotation as Dictionary).get("projected_damage", 0)) == 300 \
		and str(_route_safety(tool_candidate, frontier, facts).get("reason", "")) == "module_verified_advantage"

	var charm := _real_instance(BRAVERY_CHARM_UID, 0)
	drifloon.attached_tool = charm
	var effective_hp_exact := processor.get_effective_max_hp(drifloon, state) == 120 \
		and processor.get_effective_remaining_hp(drifloon, state) == 60
	var first_steps: Array = embrace_effect.get_interaction_steps(gardevoir.get_top_card(), state) \
		if embrace_effect != null else []
	var target_step := _step(first_steps, "embrace_target")
	var target_now_legal := drifloon in (target_step.get("items", []) as Array)
	var first_attached := processor.execute_ability_effect(gardevoir, 0, [{
		"embrace_energy": [psychic_a],
		"embrace_target": [drifloon],
	}], state)
	var second_attached := processor.execute_ability_effect(gardevoir, 0, [{
		"embrace_energy": [psychic_b],
		"embrace_target": [drifloon],
	}], state)
	var stopped_at_exact_budget := drifloon.damage_counters == 100 \
		and drifloon.attached_energy.size() == 5 \
		and processor.get_effective_remaining_hp(drifloon, state) == 20 \
		and not bool(embrace_effect.call("can_use_embrace_on_target", drifloon, state))
	var validator := RuleValidator.new()
	var attack_legal := validator.can_use_attack(state, 0, 1, processor)
	var attack_damage := DamageCalculator.new().calculate_damage(
		drifloon,
		state.players[1].active_pokemon,
		drifloon.get_card_data().attacks[1],
		state,
		_attack_bonus(processor, drifloon, 1, state)
	)
	var strict_hp_boundary := attack_damage == 300 and attack_damage < 301

	var passed := blocked_without_tool and certificate_exact and effective_hp_exact \
		and target_now_legal and first_attached and second_attached \
		and stopped_at_exact_budget and attack_legal and strict_hp_boundary
	_check(passed, "scenario A must attach Bravery Charm before exactly two more Embraces for Balloon Bomb 300: %s" % JSON.stringify({
		"blocked_without_tool": blocked_without_tool,
		"certificate_exact": certificate_exact,
		"tool_annotation": tool_annotation,
		"route_safety": _route_safety(tool_candidate, frontier, facts),
		"effective_hp_exact": effective_hp_exact,
		"target_now_legal": target_now_legal,
		"first_attached": first_attached,
		"second_attached": second_attached,
		"damage": drifloon.damage_counters,
		"energy_count": drifloon.attached_energy.size(),
		"remaining_hp": processor.get_effective_remaining_hp(drifloon, state),
		"stopped_at_exact_budget": stopped_at_exact_budget,
		"attack_legal": attack_legal,
		"attack_damage": attack_damage,
		"strict_hp_boundary": strict_hp_boundary,
	}))
	_rows.append(_row(
		"charm_before_embrace_unlocks_balloon_bomb",
		"精神拥抱伤害/填能",
		"飘飘球已有60伤害和3超能量、剩余10HP时不能继续精神拥抱；先贴勇气护符把有效上限提高到120，再精确拥抱2次，停在100伤害/20HP并打出气球炸弹300。",
		"Bravery Charm -> Psychic Embrace x2 -> Balloon Bomb 300",
		["无护符时剩余10HP不得继续拥抱", "第五次拥抱后剩余20HP不得第六次拥抱", "300不能击倒301HP"],
		passed
	))


func _scenario_b_rare_candy_resolves_the_old_ralts_chain() -> void:
	var processor := EffectProcessor.new()
	var state := _game_state(6)
	var old_ralts := _real_slot(_real_card_data(RALTS_UID), 0)
	var fresh_ralts := _real_slot(_real_card_data(RALTS_UID), 0)
	old_ralts.turn_played = 2
	fresh_ralts.turn_played = state.turn_number
	state.players[0].active_pokemon = old_ralts
	state.players[0].bench = [fresh_ralts]
	state.players[1].active_pokemon = _real_target("Public evolution target", 220, 2)
	var candy := _real_instance(RARE_CANDY_UID, 0)
	var kirlia := _real_instance(KIRLIA_UID, 0)
	var gardevoir := _real_instance(GARDEVOIR_UID, 0)
	state.players[0].hand = [candy, kirlia, gardevoir]
	var validator := RuleValidator.new()
	var kirlia_direct_legal := validator.can_evolve(state, 0, old_ralts, kirlia, processor)
	var gardevoir_direct_blocked := not validator.can_evolve(state, 0, old_ralts, gardevoir, processor)
	var candy_effect := processor.get_effect(candy.card_data.effect_id)
	var steps: Array = candy_effect.get_interaction_steps(candy, state) if candy_effect != null else []
	var stage2_step := _step(steps, "stage2_card")
	var target_step := _step(steps, "target_pokemon")
	var interaction_exact := gardevoir in (stage2_step.get("items", []) as Array) \
		and kirlia not in (stage2_step.get("items", []) as Array) \
		and old_ralts in (target_step.get("items", []) as Array) \
		and fresh_ralts not in (target_step.get("items", []) as Array)
	var wrong_fresh_rejected := not processor.execute_card_effect(candy, [{
		"stage2_card": [gardevoir],
		"target_pokemon": [fresh_ralts],
	}], state) or fresh_ralts.get_card_data().get_uid() == RALTS_UID

	var before := _observation(
		[
			_evolve("evolve:kirlia-first", KIRLIA_UID, "slot:old-ralts"),
			_play_trainer("trainer:candy-gardevoir", RARE_CANDY_UID, true),
		],
		_slot("slot:old-ralts", RALTS_UID, [], 0, 70, 70, 1),
		[_slot("slot:fresh-ralts", RALTS_UID, [], 0, 70, 70, 1)],
		_public_target("PUBLIC_EVOLUTION_TARGET", 220, 2),
		[],
		24
	)
	before["observation_version"] = 1
	before["observation_hash"] = "no-balloon-before-candy"
	before["own"]["hand"] = [_card(KIRLIA_UID), _card(GARDEVOIR_UID), _card(RARE_CANDY_UID)]
	var facts_before := _facts(false, false, false, 3, false, false, 0, 6)
	var frontier := _frontier(before, {
		"evolve:kirlia-first": 560.0,
		"trainer:candy-gardevoir": 550.0,
	}, facts_before, "evolve:kirlia-first")
	var candy_candidate := _candidate(frontier, "trainer:candy-gardevoir")

	var evolved := processor.execute_card_effect(candy, [{
		"stage2_card": [gardevoir],
		"target_pokemon": [old_ralts],
	}], state)
	state.players[0].hand.erase(candy)
	state.players[0].discard_pile.append(candy)
	var old_chain_exact := old_ralts.get_card_data().get_uid() == GARDEVOIR_UID \
		and old_ralts.pokemon_stack.size() == 2 \
		and fresh_ralts.get_card_data().get_uid() == RALTS_UID
	var after := before.duplicate(true)
	after["observation_version"] = 2
	after["observation_hash"] = "no-balloon-after-candy"
	after["own"]["active"] = _slot("slot:old-ralts", GARDEVOIR_UID, [], 0, 310, 310, 2)
	after["own"]["hand"] = [_card(KIRLIA_UID)]
	after["legal_actions"] = [_end_turn("end:after-candy")]
	var reopened := _epoch_reopens(before, after, facts_before, facts_before, candy_candidate, frontier)

	var first_turn_state := _game_state(1, 0)
	var first_turn_ralts := _real_slot(_real_card_data(RALTS_UID), 0)
	first_turn_ralts.turn_played = 0
	var first_turn_candy := _real_instance(RARE_CANDY_UID, 0)
	first_turn_state.players[0].active_pokemon = first_turn_ralts
	first_turn_state.players[0].hand = [first_turn_candy, _real_instance(GARDEVOIR_UID, 0)]
	first_turn_state.players[1].active_pokemon = _real_target("Public first-turn target", 100, 1)
	var first_turn_blocked := candy_effect != null and not candy_effect.can_execute(first_turn_candy, first_turn_state)

	var passed := kirlia_direct_legal and gardevoir_direct_blocked and interaction_exact \
		and wrong_fresh_rejected and evolved and old_chain_exact and reopened and first_turn_blocked
	_check(passed, "scenario B must Candy only the old Ralts and reject direct Stage-2/fresh-root shortcuts")
	_rows.append(_row(
		"rare_candy_resolves_the_old_ralts_chain",
		"进化链",
		"同场一只旧拉鲁拉丝与一只本回合新下拉鲁拉丝时，神奇糖果只能把旧根跳阶进化成沙奈朵ex；普通进化只能先到奇鲁莉安，不能从基础直接放Stage 2。",
		"Rare Candy(Gardevoir ex -> old Ralts)",
		["普通进化不能从拉鲁拉丝直上沙奈朵ex", "本回合刚下场的拉鲁拉丝不能糖果进化", "己方首回合不能使用神奇糖果"],
		passed
	))


func _scenario_c_iono_before_fezandipiti_preserves_both_draws() -> void:
	var correct := _draw_order_state()
	var correct_processor: EffectProcessor = correct.get("processor")
	var correct_state: GameState = correct.get("state")
	var correct_fez: PokemonSlot = correct.get("fez")
	var correct_iono: CardInstance = correct.get("iono")
	var before := _draw_order_observation(correct_state, [
		_play_trainer("supporter:iono-first", IONO_UID, false),
		_ability("ability:fez-first-wrong", "slot:fez", FEZANDIPITI_UID, false),
	])
	before["observation_version"] = 1
	before["observation_hash"] = "no-balloon-before-iono"
	var facts_before := _facts(false, false, false, 2, false, false, 0, 2)
	var frontier := _frontier(before, {
		"supporter:iono-first": 600.0,
		"ability:fez-first-wrong": 580.0,
	}, facts_before, "supporter:iono-first")
	var iono_candidate := _candidate(frontier, "supporter:iono-first")
	correct_state.players[0].hand.erase(correct_iono)
	var iono_executed := correct_processor.execute_card_effect(correct_iono, [], correct_state)
	correct_state.players[0].discard_pile.append(correct_iono)
	var fez_executed := correct_processor.execute_ability_effect(correct_fez, 0, [], correct_state)
	var correct_names := _instance_names(correct_state.players[0].hand)
	var correct_kept_all_five := correct_names == [
		"VISIBLE_DRAW_A", "VISIBLE_DRAW_B", "VISIBLE_DRAW_C", "VISIBLE_DRAW_D", "VISIBLE_DRAW_E",
	]
	var shared_once := not correct_processor.can_use_ability(correct_fez, correct_state, 0)
	var after := _draw_order_observation(correct_state, [])
	after["observation_version"] = 2
	after["observation_hash"] = "no-balloon-after-iono"
	var facts_after := _facts(false, false, false, 5, false, false, 0, 2)
	var reopened := _epoch_reopens(before, after, facts_before, facts_after, iono_candidate, frontier)

	var wrong := _draw_order_state()
	var wrong_processor: EffectProcessor = wrong.get("processor")
	var wrong_state: GameState = wrong.get("state")
	var wrong_fez: PokemonSlot = wrong.get("fez")
	var wrong_iono: CardInstance = wrong.get("iono")
	var wrong_fez_executed := wrong_processor.execute_ability_effect(wrong_fez, 0, [], wrong_state)
	wrong_state.players[0].hand.erase(wrong_iono)
	var wrong_iono_executed := wrong_processor.execute_card_effect(wrong_iono, [], wrong_state)
	wrong_state.players[0].discard_pile.append(wrong_iono)
	var wrong_names := _instance_names(wrong_state.players[0].hand)
	var premature_draw_lost := wrong_names == ["VISIBLE_DRAW_D", "VISIBLE_DRAW_E"] \
		and "VISIBLE_DRAW_A" not in wrong_names \
		and "VISIBLE_DRAW_B" not in wrong_names \
		and "VISIBLE_DRAW_C" not in wrong_names

	var passed := iono_executed and fez_executed and correct_kept_all_five and shared_once \
		and reopened and wrong_fez_executed and wrong_iono_executed and premature_draw_lost
	_check(passed, "scenario C must resolve Iono before Flip the Script so the three ability draws survive")
	_rows.append(_row(
		"iono_before_fezandipiti_preserves_both_draws",
		"特性与支援者/抽牌顺序",
		"上回合己方被击倒且己方剩2奖时，先用奇树抽2，再用吉雉鸡ex的化危为吉抽3，保留连续5张公开抽牌；若先开特性，之后奇树会把前3张送到牌库底，只留下新抽2张。",
		"Iono draw 2 -> information epoch -> Flip the Script draw 3",
		["化危为吉要求上个对手回合发生己方昏厥", "同回合共享的化危为吉只能用一次", "先特性后奇树会失去前3张确定抽牌"],
		passed
	))


func _scenario_d_adrena_brain_moves_only_the_lethal_counters() -> void:
	var processor := EffectProcessor.new()
	var state := _game_state()
	var drifloon := _real_slot(_real_card_data(DRIFLOON_UID), 0)
	drifloon.damage_counters = 60
	drifloon.attached_energy = [_real_instance(PSYCHIC_UID, 0), _real_instance(PSYCHIC_UID, 0)]
	var munkidori := _real_slot(_real_card_data(MUNKIDORI_UID), 0)
	munkidori.attached_energy = [_real_instance(DARKNESS_UID, 0)]
	state.players[0].active_pokemon = drifloon
	state.players[0].bench = [munkidori]
	state.players[1].active_pokemon = _real_target("Public high-HP Active", 300, 2)
	var bench_target := _real_target("Public 20 HP Bench target", 20, 1)
	state.players[1].bench = [bench_target]
	processor.register_pokemon_card(drifloon.get_card_data())
	processor.register_pokemon_card(munkidori.get_card_data())

	var ability_effect := processor.get_ability_effect(munkidori, 0, state)
	var source_steps: Array = ability_effect.get_interaction_steps(munkidori.get_top_card(), state) \
		if ability_effect != null else []
	var source_step := _step(source_steps, "source_pokemon")
	var followup: Array = ability_effect.get_followup_interaction_steps(
		munkidori.get_top_card(), state, {"source_pokemon": [drifloon]}
	) if ability_effect != null else []
	var counter_step := _step(followup, "target_damage_counters")
	var interaction_exact := drifloon in (source_step.get("items", []) as Array) \
		and str(counter_step.get("ui_mode", "")) == "counter_distribution" \
		and int(counter_step.get("total_counters", 0)) == 3 \
		and bench_target in (counter_step.get("target_items", []) as Array)
	var too_many_rejected := not processor.execute_ability_effect(munkidori, 0, [{
		"source_pokemon": [drifloon],
		"target_damage_counters": [{"target": bench_target, "amount": 40}],
	}], state)
	var unchanged_after_rejection := drifloon.damage_counters == 60 and bench_target.damage_counters == 0
	var moved := processor.execute_ability_effect(munkidori, 0, [{
		"source_pokemon": [drifloon],
		"target_damage_counters": [{"target": bench_target, "amount": 20}],
	}], state)
	var exact_lethal_transfer := drifloon.damage_counters == 40 \
		and bench_target.damage_counters == 20 \
		and bench_target.get_remaining_hp() == 0
	var once_per_turn := not processor.can_use_ability(munkidori, state, 0)

	var observation := _observation(
		[
			_ability("ability:adrena-bench-lethal", "slot:munkidori", MUNKIDORI_UID, true),
			_attack("attack:balloon-into-active", DRIFLOON_UID, "slot:drifloon", 1, 180, false),
		],
		_slot("slot:drifloon", DRIFLOON_UID, [_psychic_energy(), _psychic_energy()], 60, 10, 70, 1),
		[_slot("slot:munkidori", MUNKIDORI_UID, [_darkness_energy()], 0, 110, 110, 1)],
		_public_target("PUBLIC_HIGH_HP_ACTIVE", 300, 2),
		[_public_target("PUBLIC_20_HP_BENCH", 20, 1)],
		18
	)
	var facts := _facts(true, false, false, 0, false, false, 180, 3)
	var frontier := _frontier(observation, {
		"ability:adrena-bench-lethal": 610.0,
		"attack:balloon-into-active": 590.0,
	}, facts, "ability:adrena-bench-lethal")
	var ability_candidate := _candidate(frontier, "ability:adrena-bench-lethal")
	var counter_annotation := _module_annotation(ability_candidate, "damage_counter_control")
	var public_budget_visible: bool = int(counter_annotation.get("movable_counter_budget", 0)) == 6 \
		and "bind_counter_source_and_target" in counter_annotation.get("decision_hints", [])

	var no_dark_state := _game_state()
	var no_dark_source := _real_slot(_real_card_data(DRIFLOON_UID), 0)
	no_dark_source.damage_counters = 30
	var no_dark_munkidori := _real_slot(_real_card_data(MUNKIDORI_UID), 0)
	no_dark_state.players[0].active_pokemon = no_dark_source
	no_dark_state.players[0].bench = [no_dark_munkidori]
	no_dark_state.players[1].active_pokemon = _real_target("Public no-dark target", 100, 1)
	var no_dark_processor := EffectProcessor.new()
	no_dark_processor.register_pokemon_card(no_dark_munkidori.get_card_data())
	var no_dark_blocked := not no_dark_processor.can_use_ability(no_dark_munkidori, no_dark_state, 0)

	var passed: bool = interaction_exact and too_many_rejected and unchanged_after_rejection \
		and moved and exact_lethal_transfer and once_per_turn and public_budget_visible and no_dark_blocked
	_check(passed, "scenario D must move exactly two lethal counters to the public Bench target")
	_rows.append(_row(
		"adrena_brain_moves_only_the_lethal_counters",
		"伤害搬运",
		"飘飘球有6个伤害指示物、对手公开备战目标只剩20HP时，有恶能量的愿增猿只搬2个指示物完成击倒，保留飘飘球其余40伤害；不能把超过特性上限的4个指示物一次搬走。",
		"Adrena Brain move exactly 2 counters from Drifloon to the 20 HP Bench target",
		["愿增猿没有恶能量时不能使用特性", "单次最多搬3个伤害指示物", "同一愿增猿每回合只能使用一次"],
		passed
	))


func _scenario_e_scream_tail_takes_the_last_bench_prize() -> void:
	var processor := EffectProcessor.new()
	var state := _game_state()
	var scream_tail := _real_slot(_real_card_data(SCREAM_TAIL_UID), 0)
	scream_tail.damage_counters = 80
	scream_tail.attached_energy = [_real_instance(PSYCHIC_UID, 0), _real_instance(PSYCHIC_UID, 0)]
	scream_tail.attached_tool = _real_instance(BRAVERY_CHARM_UID, 0)
	state.players[0].active_pokemon = scream_tail
	_fill_prizes(state.players[0], 1, "OWN_FINAL_PRIZE")
	var opponent_active := _real_target("Public 330 HP Active", 330, 1)
	var bench_target := _real_target("Public 160 HP Bench target", 160, 1)
	state.players[1].active_pokemon = opponent_active
	state.players[1].bench = [bench_target]
	processor.register_pokemon_card(scream_tail.get_card_data())
	var validator := RuleValidator.new()
	var attack_legal := validator.can_use_attack(state, 0, 1, processor)
	var effects := processor.get_attack_effects_for_slot(scream_tail, 1)
	var target_effect: BaseEffect = null
	for effect: BaseEffect in effects:
		if effect.has_method("get_attack_preview_damage"):
			target_effect = effect
			break
	var steps: Array = target_effect.get_attack_interaction_steps(
		scream_tail.get_top_card(), scream_tail.get_card_data().attacks[1], state
	) if target_effect != null else []
	var target_step := _step(steps, "target_pokemon")
	var both_public_targets := opponent_active in (target_step.get("items", []) as Array) \
		and bench_target in (target_step.get("items", []) as Array)
	var preview := int(target_effect.call("get_attack_preview_damage", scream_tail, bench_target, state)) \
		if target_effect != null else 0
	var executed := processor.execute_attack_effect(
		scream_tail, 1, opponent_active, state, [{"target_pokemon": [bench_target]}]
	)
	var real_terminal := preview == 160 and bench_target.damage_counters == 160 \
		and bench_target.get_remaining_hp() == 0 and opponent_active.damage_counters == 0 \
		and _prize_count(bench_target) >= state.players[0].prizes.size()

	var observation := _observation(
		[
			_attack("attack:final-roaring-scream", SCREAM_TAIL_UID, "slot:scream-tail", 1, 160, true),
			_play_trainer("supporter:optional-iono", IONO_UID, false),
			_ability("ability:optional-munkidori", "slot:munkidori", MUNKIDORI_UID, true),
		],
		_slot_with_tool("slot:scream-tail", SCREAM_TAIL_UID, [_psychic_energy(), _psychic_energy()], 80, 60, 140, 1, BRAVERY_CHARM_UID),
		[_slot("slot:munkidori", MUNKIDORI_UID, [_darkness_energy()], 0, 110, 110, 1)],
		_public_target("PUBLIC_330_HP_ACTIVE", 330, 1),
		[_public_target("PUBLIC_160_HP_BENCH", 160, 1)],
		6,
		1
	)
	var facts := _facts(true, true, false, 1, true, false, 160, 1)
	facts["prize"]["win_now"] = true
	var frontier := _frontier(observation, {
		"attack:final-roaring-scream": 620.0,
		"supporter:optional-iono": 600.0,
		"ability:optional-munkidori": 590.0,
	}, facts, "attack:final-roaring-scream")
	var attack_candidate := _candidate(frontier, "attack:final-roaring-scream")
	var iono_candidate := _candidate(frontier, "supporter:optional-iono")
	var terminal_exact := bool(attack_candidate.get("outcome", {}).get("win_now", false)) \
		and int(attack_candidate.get("outcome", {}).get("prizes_now", 0)) == 1 \
		and not bool(_route_safety(iono_candidate, frontier, facts).get("valid", true))

	var lower_damage_state := _game_state()
	var lower_tail := _real_slot(_real_card_data(SCREAM_TAIL_UID), 0)
	lower_tail.damage_counters = 70
	var lower_target := _real_target("Public 160 HP strict target", 160, 1)
	lower_damage_state.players[0].active_pokemon = lower_tail
	lower_damage_state.players[1].active_pokemon = lower_target
	var lower_preview := int(target_effect.call("get_attack_preview_damage", lower_tail, lower_target, lower_damage_state)) \
		if target_effect != null else 0
	var hp_161 := _real_target("Public 161 HP strict target", 161, 1)
	var strict_nonterminals := lower_preview == 140 and lower_preview < 160 and preview < hp_161.get_remaining_hp()

	var passed := attack_legal and both_public_targets and executed and real_terminal \
		and terminal_exact and strict_nonterminals
	_check(passed, "scenario E must snipe the exact 160 HP Bench target for the final Prize before optional churn")
	_rows.append(_row(
		"scream_tail_takes_the_last_bench_prize",
		"关键奖终局",
		"己方只剩1奖时，勇气护符吼叫尾带80伤害，用凶暴吼叫绕过330HP前台，精确狙击160HP备战单奖并立即结束对局；不得先用奇树或可选特性。",
		"Roaring Scream 160 to the public Bench target for the final Prize",
		["70伤害只能打140，不能击倒160HP", "160不能击倒161HP", "锁定终局后禁止可选换手与特性周转"],
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
	frontier: Array[Dictionary]
) -> bool:
	var delta := MaterialDeltaScript.new().compare(before, after, facts_before, facts_after)
	var strategy = StrategyScript.new()
	strategy.configure_profile(_profile, _manifest)
	strategy.configure_verified_local_only_for_benchmark()
	return bool(strategy.call("_should_reopen_information_epoch", \
		"local_gate", {
			"owner": "local_gate",
			"success": true,
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


func _observation(
	actions: Array,
	active: Dictionary,
	bench: Array,
	opponent_active: Dictionary,
	opponent_bench: Array,
	deck_count: int,
	own_prizes: int = 6
) -> Dictionary:
	return {
		"observation_version": 1,
		"observation_hash": "no-balloon-gardevoir-complex-scenario",
		"turn": {"deterministic_attack_window_open": true},
		"own": {
			"active": active,
			"bench": bench,
			"hand": [{"uid": "VISIBLE_OWN_HAND_CARD"}],
			"discard": [],
			"deck_count": deck_count,
			"prizes_remaining": own_prizes,
		},
		"opponent": {
			"active": opponent_active,
			"bench": opponent_bench,
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


func _slot(
	slot_id: String,
	uid: String,
	energy: Array,
	damage: int,
	remaining_hp: int,
	max_hp: int,
	prize_count: int
) -> Dictionary:
	return {
		"slot_id": slot_id,
		"pokemon": _card(uid),
		"tool": {},
		"energy": energy,
		"energy_count": energy.size(),
		"damage": damage,
		"remaining_hp": remaining_hp,
		"max_hp": max_hp,
		"prize_count": prize_count,
		"ability_used": false,
	}


func _slot_with_tool(
	slot_id: String,
	uid: String,
	energy: Array,
	damage: int,
	remaining_hp: int,
	max_hp: int,
	prize_count: int,
	tool_uid: String
) -> Dictionary:
	var result := _slot(slot_id, uid, energy, damage, remaining_hp, max_hp, prize_count)
	result["tool"] = _card(tool_uid)
	return result


func _public_target(uid: String, remaining_hp: int, prize_count: int) -> Dictionary:
	return {
		"slot_id": "slot:%s" % uid.to_lower(),
		"pokemon": {"uid": uid},
		"remaining_hp": remaining_hp,
		"max_hp": remaining_hp,
		"damage": 0,
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


func _attach_tool(action_id: String, uid: String, target: String) -> Dictionary:
	return {
		"id": action_id,
		"kind": "attach_tool",
		"card": _card(uid),
		"target": target,
		"requires_interaction": false,
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


func _attack(
	action_id: String,
	uid: String,
	source: String,
	attack_index: int,
	damage: int,
	knockout: bool
) -> Dictionary:
	return {
		"id": action_id,
		"kind": "attack",
		"source": source,
		"source_card": _card(uid),
		"attack_index": attack_index,
		"projected_damage": damage,
		"projected_knockout": knockout,
		"requires_interaction": uid == SCREAM_TAIL_UID,
	}


func _end_turn(action_id: String) -> Dictionary:
	return {"id": action_id, "kind": "end_turn"}


func _psychic_energy() -> Dictionary:
	return _energy_card(PSYCHIC_UID, "P")


func _darkness_energy() -> Dictionary:
	return _energy_card(DARKNESS_UID, "D")


func _energy_card(uid: String, symbol: String) -> Dictionary:
	var card := _card(uid)
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
	data.set_code = "FIXTURE"
	data.card_index = name
	return CardInstance.create(data, owner)


func _draw_order_state() -> Dictionary:
	var processor := EffectProcessor.new()
	var state := _game_state(10)
	var fez := _real_slot(_real_card_data(FEZANDIPITI_UID), 0)
	var iono := _real_instance(IONO_UID, 0)
	state.players[0].active_pokemon = fez
	state.players[0].hand = [iono, _filler_instance("VISIBLE_STALE_HAND", 0)]
	state.players[0].deck = [
		_filler_instance("VISIBLE_DRAW_A", 0),
		_filler_instance("VISIBLE_DRAW_B", 0),
		_filler_instance("VISIBLE_DRAW_C", 0),
		_filler_instance("VISIBLE_DRAW_D", 0),
		_filler_instance("VISIBLE_DRAW_E", 0),
		_filler_instance("VISIBLE_DRAW_F", 0),
	]
	_fill_prizes(state.players[0], 2, "OWN_DRAW_PRIZE")
	_fill_prizes(state.players[1], 4, "OPP_DRAW_PRIZE")
	state.players[1].active_pokemon = _real_target("Public draw-order target", 200, 1)
	state.last_knockout_turn_against[0] = state.turn_number - 1
	processor.register_pokemon_card(fez.get_card_data())
	return {"processor": processor, "state": state, "fez": fez, "iono": iono}


func _draw_order_observation(state: GameState, actions: Array) -> Dictionary:
	var hand: Array[Dictionary] = []
	for instance: CardInstance in state.players[0].hand:
		hand.append({"uid": instance.card_data.get_uid(), "name": instance.card_data.name_en})
	var result := _observation(
		actions,
		_slot("slot:fez", FEZANDIPITI_UID, [], 0, 210, 210, 2),
		[],
		_public_target("PUBLIC_DRAW_ORDER_TARGET", 200, 1),
		[],
		state.players[0].deck.size(),
		state.players[0].prizes.size()
	)
	result["own"]["hand"] = hand
	return result


func _instance_names(cards: Array[CardInstance]) -> Array[String]:
	var names: Array[String] = []
	for card: CardInstance in cards:
		names.append(card.card_data.name_en if card.card_data.name_en != "" else card.card_data.name)
	return names


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
		"deck_name": "18.0 无碟沙奈朵",
		"strategy_id": str(_profile.get("strategy_id", "")),
		"profile_version": int(_profile.get("profile_version", 0)),
		"deck_source": {
			"source_kind": "bundled_ai",
			"bundled_seed_path": DECK_SEED_PATH,
			"source_provider": str(_deck_seed.get("source_provider", "")),
			"source_url": str(_deck_seed.get("source_url", "")),
			"total_cards": int(_deck_seed.get("total_cards", 0)),
			"deck_content_fingerprint": _current_fingerprint,
			"semantic_manifest_fingerprint": str(_manifest.get("deck_content_fingerprint", "")),
			"fingerprint_verified": _current_fingerprint != "" \
				and _current_fingerprint == str(_manifest.get("deck_content_fingerprint", "")),
		},
		"baseline": {
			"status": "pending_current_bundled_ai_round00",
			"required_deck_content_fingerprint": _current_fingerprint,
			"valid_round00_found": false,
			"accepted_artifact": "",
			"seed_base": DECK_ID,
			"legacy_user_deck_evidence_reused": false,
			"note": "No fingerprint-aligned current bundled_ai round00 exists; prior user-deck evidence is excluded and no strength result is carried forward.",
		},
		"scope": "focused scenario preparation only; no real-model formal benchmark",
		"scenario_count": _rows.size(),
		"passed_count": _rows.filter(func(row: Dictionary) -> bool: return bool(row.get("passed", false))).size(),
		"all_passed": _failures.is_empty() and _rows.size() == 5,
		"production_status": "scenario_contract_ready_not_promoted",
		"known_production_gaps": [
			"No deck-local promotion or aggregate win-rate claim is made by these five fixtures.",
			"The Bravery Charm plus two-Embrace Balloon Bomb suffix is real-effect verified and locally certified, but each post-interaction information epoch still has to bind the exact target in a live run.",
			"Rare Candy legality, Iono/Flip-the-Script ordering, Adrena Brain assignment, and the Scream Tail Bench target are proved through real engine paths; generic modules do not claim unbounded ownership of those multi-action continuations.",
			"A new fingerprint-aligned bundled_ai round00 and paired-seed comparison against the exact Rule floor remain pending.",
		],
		"isolation": {
			"profile_modified": false,
			"shared_strategy_modified": false,
			"shared_registry_modified": false,
			"shared_strategic_shape_modified": false,
			"rule_or_legacy_or_agent_modified": false,
			"real_model_formal_run": false,
			"hidden_sentinel_absent_from_frontiers": true,
			"invalidated_user_deck_evidence_reused": false,
		},
		"coverage": [
			"Bravery Charm before two safe Psychic Embrace assignments for Balloon Bomb 300",
			"Rare Candy only on an old Ralts with direct-Stage-2 and fresh-root negatives",
			"Iono before Fezandipiti ex so both public draw windows survive",
			"Munkidori exact two-counter lethal transfer with Darkness and once-per-turn guards",
			"Scream Tail exact 160 Bench snipe for the final Prize before optional churn",
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
