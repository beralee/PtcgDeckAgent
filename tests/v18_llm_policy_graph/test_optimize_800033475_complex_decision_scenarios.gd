extends SceneTree

const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const SemanticCompilerScript = preload("res://scripts/ai/v18_cpg/semantics/V18CPGDeckSemanticCompiler.gd")

const DECK_ID := 800033475
const DECK_SEED_PATH := "res://data/bundled_user/decks/800033475.json"
const MANIFEST_PATH := "res://scripts/ai/v18_cpg/profiles/generated_semantic_manifests/800033475.json"
const HISTORICAL_ROUND_PATH := "res://tmp/v18cpg/optimization21/800033475/round00.json"
const REPORT_PATH := "res://tmp/v18cpg/optimization21/800033475/complex_decision_scenarios.json"

const YANMA_UID := "CSV10C_002"
const YANMEGA_UID := "CSV10C_003"
const DUNSPARCE_UID := "CSV7C_161"
const DUDUNSPARCE_UID := "CSV7C_162"
const BUDEW_UID := "CSV9.5C_004"
const TATSUGIRI_UID := "CSV8C_160"
const BOSS_UID := "CSVH1aC_023"
const IONO_UID := "CSV3C_123"
const TM_EVOLUTION_UID := "CSV5C_119"
const RESCUE_BOARD_UID := "CSV7C_185"
const JET_ENERGY_UID := "CSV4C_129"
const GRASS_ENERGY_UID := "CSVE1C_GRA"

var _profile: Dictionary = {}
var _manifest: Dictionary = {}
var _deck_seed: Dictionary = {}
var _historical_round: Dictionary = {}
var _current_fingerprint := ""
var _failures: Array[String] = []
var _rows: Array[Dictionary] = []


func _initialize() -> void:
	_profile = ProfileCatalogScript.get_profile_for_deck(DECK_ID)
	_manifest = _load_json(MANIFEST_PATH)
	_deck_seed = _load_json(DECK_SEED_PATH)
	_historical_round = _load_json(HISTORICAL_ROUND_PATH)
	var deck := DeckData.from_dict(_deck_seed)
	_current_fingerprint = SemanticCompilerScript.deck_content_fingerprint(deck)
	_check(int(_profile.get("deck_id", 0)) == DECK_ID, "production Yanmega profile must load")
	_check(int(_profile.get("profile_version", 0)) == 2, "focused scenarios bind production profile v2")
	_check(_profile.get("modules", []) == ["cycle_pivot", "grass_spread"], \
		"scenarios must use the production cycle-pivot/grass-spread composition")
	_check(int(_manifest.get("deck_id", 0)) == DECK_ID, "Yanmega semantic manifest must load")
	_check(int(deck.id) == DECK_ID and int(deck.total_cards) == 60, \
		"current bundled AI seed must be the exact 60-card Yanmega deck")
	_check(_current_fingerprint != "" \
		and _current_fingerprint == str(_manifest.get("deck_content_fingerprint", "")), \
		"semantic manifest fingerprint must match the current bundled AI deck")
	_check(not _historical_round.has("deck_source") \
		and not _historical_round.has("deck_content_fingerprint"), \
		"round00 must remain excluded because it has no current deck-source fingerprint binding")

	_scenario_a_jet_energy_opens_buzzing_rush_and_exact_grass_budget()
	_scenario_b_tm_evolution_builds_yanmega_and_dudunsparce_lanes()
	_scenario_c_run_away_draw_cycles_stack_and_hands_off_active()
	_scenario_d_tatsugiri_finds_iono_before_the_supporter_draw_checkpoint()
	_scenario_e_boss_then_jet_cyclone_closes_exactly_two_prizes()
	_write_report()

	EffectProcessor.cleanup_live_instances_for_tests()
	if _failures.is_empty() and _rows.size() == 5:
		print("optimization21 800033475 complex decision scenarios: PASS (5/5)")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("optimization21 800033475 complex decision scenarios: FAIL (%d)" % _failures.size())
	quit(1)


func _scenario_a_jet_energy_opens_buzzing_rush_and_exact_grass_budget() -> void:
	var gsm := GameStateMachine.new()
	gsm.game_state = _game_state(6)
	var state := gsm.game_state
	var player: PlayerState = state.players[0]
	var pivot := _real_slot(BUDEW_UID, 0)
	var yanmega := _real_slot(YANMEGA_UID, 0)
	var jet := _real_instance(JET_ENERGY_UID, 0)
	var grass_a := _real_instance(GRASS_ENERGY_UID, 0)
	var grass_b := _real_instance(GRASS_ENERGY_UID, 0)
	var grass_c := _real_instance(GRASS_ENERGY_UID, 0)
	var special_energy_in_deck := _real_instance(JET_ENERGY_UID, 0)
	player.active_pokemon = pivot
	player.bench = [yanmega]
	player.hand = [jet]
	player.deck = [grass_a, grass_b, grass_c, special_energy_in_deck]
	for index: int in 8:
		player.deck.append(_filler("BUZZING_DECK_%d" % index, 0))
	state.players[1].active_pokemon = _target("Public setup target", 230, 1)
	gsm.effect_processor.register_pokemon_card(yanmega.get_card_data())

	var blocked_while_benched := not gsm.effect_processor.can_use_ability(yanmega, state, 0)
	var attached := gsm.attach_energy(0, jet, yanmega)
	var entered_from_bench := player.active_pokemon == yanmega \
		and pivot in player.bench \
		and yanmega.entered_active_from_bench_this_turn(state.turn_number)
	var ability := gsm.effect_processor.get_ability_effect(yanmega, 0, state)
	var steps: Array = ability.get_interaction_steps(yanmega.get_top_card(), state) \
		if ability != null else []
	var assignment_step := _step(steps, "energy_assignments")
	var sources: Array = assignment_step.get("source_items", [])
	var exact_search_boundary := sources == [grass_a, grass_b, grass_c] \
		and special_energy_in_deck not in sources \
		and str(assignment_step.get("source_visible_scope", "")) == BaseEffect.VISIBLE_SCOPE_OWN_FULL_DECK \
		and int(assignment_step.get("max_select", 0)) == 3
	var ability_used := gsm.use_ability(0, yanmega, 0, [{"energy_assignments": [
		{"source": grass_a, "target": yanmega},
		{"source": grass_b, "target": yanmega},
		{"source": grass_c, "target": yanmega},
	]}])
	var exact_budget := yanmega.attached_energy.size() == 4 \
		and jet in yanmega.attached_energy \
		and grass_a in yanmega.attached_energy \
		and grass_b in yanmega.attached_energy \
		and grass_c in yanmega.attached_energy \
		and gsm.rule_validator.can_use_attack(state, 0, 0, gsm.effect_processor)
	var one_use_only := not gsm.effect_processor.can_use_ability(yanmega, state, 0)
	var grass_cost: Array = _profile.get("module_parameters", {}).get("grass_spread", {}) \
		.get("attack_cost_by_uid", {}).get(YANMEGA_UID, [])
	var passed := blocked_while_benched and attached and entered_from_bench \
		and exact_search_boundary and ability_used and exact_budget and one_use_only \
		and grass_cost == ["G", "G", "G"]
	_check(passed, "scenario A must Jet-switch Yanmega, attach only three Basic Grass, and stop the Ability")
	_rows.append(_row(
		"jet_energy_opens_buzzing_rush_and_exact_grass_budget",
		"换位/特性充能/攻击准备",
		"把喷射能量贴给备战远古巨蜓ex并切到前台，随后从完整牌库只选择3张基本草能量，使喷射旋风立即可用。",
		"Jet Energy -> Buzzing Rush: Basic Grass x3 -> Jet Cyclone ready",
		["留在备战区时特性不可用", "喷射能量等特殊能量不可进入基本草检索", "同回合不可第二次使用特性"],
		passed
	))


func _scenario_b_tm_evolution_builds_yanmega_and_dudunsparce_lanes() -> void:
	var state := _game_state(4)
	var carrier := _real_slot(BUDEW_UID, 0)
	var yanma := _real_slot(YANMA_UID, 0)
	var dunsparce := _real_slot(DUNSPARCE_UID, 0)
	var support := _real_slot(TATSUGIRI_UID, 0)
	var yanmega := _real_instance(YANMEGA_UID, 0)
	var dudunsparce := _real_instance(DUDUNSPARCE_UID, 0)
	var unrelated := _unrelated_stage_one(0)
	state.players[0].active_pokemon = carrier
	state.players[0].bench = [yanma, support, dunsparce]
	state.players[0].deck = [yanmega, unrelated, dudunsparce]
	state.players[1].active_pokemon = _target("Public TM target", 180, 1)
	var tm := _real_instance(TM_EVOLUTION_UID, 0)
	var processor := EffectProcessor.new()
	var effect := processor.get_effect(tm.card_data.effect_id)
	var initial_steps: Array = effect.get_granted_attack_interaction_steps(
		carrier, {"id": AttackTMEvolution.GRANTED_ATTACK_ID}, state) if effect != null else []
	var bench_step := _step(initial_steps, "evolution_bench")
	var bench_items: Array = bench_step.get("items", [])
	var exact_roots := yanma in bench_items and dunsparce in bench_items \
		and support not in bench_items and carrier not in bench_items \
		and int(bench_step.get("max_select", 0)) == 2
	var followup: Array = effect.get_followup_granted_attack_interaction_steps(
		carrier,
		{"id": AttackTMEvolution.GRANTED_ATTACK_ID},
		state,
		{"evolution_bench": [yanma, dunsparce]}
	) if effect != null else []
	var card_step := _step(followup, "evolution_cards")
	var card_items: Array = card_step.get("items", [])
	var exact_evolutions := yanmega in card_items and dudunsparce in card_items \
		and unrelated not in card_items \
		and str(card_step.get("visible_scope", "")) == BaseEffect.VISIBLE_SCOPE_OWN_FULL_DECK \
		and int(card_step.get("max_select", 0)) == 2
	if effect != null:
		effect.execute_granted_attack(carrier, {"id": AttackTMEvolution.GRANTED_ATTACK_ID}, state, [{
			"evolution_bench": [yanma, dunsparce],
			"evolution_cards": [yanmega, dudunsparce],
		}])
	var evolved_exact := yanma.get_card_data().get_uid() == YANMEGA_UID \
		and dunsparce.get_card_data().get_uid() == DUDUNSPARCE_UID \
		and yanma.pokemon_stack.size() == 2 and dunsparce.pokemon_stack.size() == 2 \
		and carrier.get_card_data().get_uid() == BUDEW_UID \
		and unrelated in state.players[0].deck
	var evolve_bias := float(_profile.get("route_preferences", {}).get("route_biases", {}) \
		.get("route:evolve", 0.0))
	var develop_bias := float(_profile.get("route_preferences", {}).get("route_biases", {}) \
		.get("route:develop", 0.0))
	var passed := effect is AttackTMEvolution and exact_roots and exact_evolutions \
		and evolved_exact and evolve_bias > develop_bias
	_check(passed, "scenario B must use one real TM Evolution to build Yanmega and Dudunsparce together")
	_rows.append(_row(
		"tm_evolution_builds_yanmega_and_dudunsparce_lanes",
		"进化双线/引擎展开",
		"招式学习器【进化】同时把备战蜻蜻蜓进化为远古巨蜓ex、土龙弟弟进化为土龙节节，建立主攻与循环引擎。",
		"TM Evolution: Yanma -> Yanmega ex; Dunsparce -> Dudunsparce",
		["出战载体不可成为目标", "米立龙与无关Stage 1不可进入选择", "一次最多处理2条进化线"],
		passed
	))


func _scenario_c_run_away_draw_cycles_stack_and_hands_off_active() -> void:
	var state := _game_state(9)
	var player: PlayerState = state.players[0]
	var dudunsparce := _real_slot(DUDUNSPARCE_UID, 0)
	var dudunsparce_card := dudunsparce.get_top_card()
	var yanmega := _real_slot(YANMEGA_UID, 0)
	var other_bench := _real_slot(YANMA_UID, 0)
	var attached_energy := _real_instance(GRASS_ENERGY_UID, 0)
	var attached_tool := _real_instance(RESCUE_BOARD_UID, 0)
	dudunsparce.attached_energy = [attached_energy]
	dudunsparce.attached_tool = attached_tool
	player.active_pokemon = dudunsparce
	player.bench = [yanmega, other_bench]
	var draw_a := _filler("RUN_AWAY_DRAW_A", 0)
	var draw_b := _filler("RUN_AWAY_DRAW_B", 0)
	var draw_c := _filler("RUN_AWAY_DRAW_C", 0)
	player.deck = [draw_a, draw_b, draw_c]
	for index: int in 9:
		player.deck.append(_filler("RUN_AWAY_TAIL_%d" % index, 0))
	state.players[1].active_pokemon = _target("Public cycle target", 200, 1)
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(dudunsparce.get_card_data())
	var effect := processor.get_ability_effect(dudunsparce, 0, state)
	var steps: Array = effect.get_interaction_steps(dudunsparce_card, state) if effect != null else []
	var replacement_step := _step(steps, AbilityRunAwayDraw.REPLACEMENT_STEP_ID)
	var replacement_items: Array = replacement_step.get("items", [])
	var exact_choice_surface := replacement_items == [yanmega, other_bench] \
		and int(replacement_step.get("min_select", 0)) == 1 \
		and int(replacement_step.get("max_select", 0)) == 1
	var executed := processor.execute_ability_effect(dudunsparce, 0, [{
		AbilityRunAwayDraw.REPLACEMENT_STEP_ID: [yanmega],
	}], state)
	var draw_then_cycle := executed and player.hand.size() == 3 \
		and draw_a in player.hand and draw_b in player.hand and draw_c in player.hand \
		and dudunsparce_card in player.deck \
		and attached_energy in player.deck and attached_tool in player.deck
	var exact_handoff := player.active_pokemon == yanmega \
		and yanmega not in player.bench \
		and other_bench in player.bench \
		and dudunsparce not in player.bench

	var blocked_state := _game_state(9)
	var stranded := _real_slot(DUDUNSPARCE_UID, 0)
	blocked_state.players[0].active_pokemon = stranded
	blocked_state.players[0].deck = [_filler("STRANDED_DRAW", 0)]
	blocked_state.players[1].active_pokemon = _target("Public blocked target", 100, 1)
	var blocked_processor := EffectProcessor.new()
	blocked_processor.register_pokemon_card(stranded.get_card_data())
	var blocked_effect := blocked_processor.get_ability_effect(stranded, 0, blocked_state)
	var stranded_blocked := not blocked_processor.can_use_ability(stranded, blocked_state, 0) \
		and (blocked_effect == null \
			or blocked_effect.get_interaction_steps(stranded.get_top_card(), blocked_state).is_empty())
	var cycle_config: Dictionary = _profile.get("module_parameters", {}).get("cycle_pivot", {})
	var profile_bound := DUDUNSPARCE_UID in (cycle_config.get("optional_draw_engine_uids", []) as Array) \
		and int(cycle_config.get("low_deck_floor", -1)) == 8 \
		and player.deck.size() >= int(cycle_config.get("low_deck_floor", -1))
	var passed := effect is AbilityRunAwayDraw and exact_choice_surface \
		and draw_then_cycle and exact_handoff and stranded_blocked and profile_bound
	_check(passed, "scenario C must draw three, recycle the full Dudunsparce stack, and hand off Active safely")
	_rows.append(_row(
		"run_away_draw_cycles_stack_and_hands_off_active",
		"循环抽牌/前台交接",
		"牌库高于安全线且主攻尚未就绪时，土龙节节先抽3，再把自身、能量与道具洗回，并明确交接给远古巨蜓ex。",
		"Run Away Draw -> draw 3 -> recycle full stack -> promote Yanmega ex",
		["没有备战替补时不可发动", "只能选择1个合法备战替补", "抽牌后必须回收整叠卡而非只回收进化卡"],
		passed
	))


func _scenario_d_tatsugiri_finds_iono_before_the_supporter_draw_checkpoint() -> void:
	var gsm := GameStateMachine.new()
	gsm.game_state = _game_state(10)
	var state := gsm.game_state
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	var tatsugiri := _real_slot(TATSUGIRI_UID, 0)
	var iono := _real_instance(IONO_UID, 0)
	var boss := _real_instance(BOSS_UID, 0)
	var visible_item := _filler("VISIBLE_TOP_SIX_ITEM", 0)
	var seventh_supporter := _real_instance(BOSS_UID, 0)
	player.active_pokemon = tatsugiri
	player.deck = [
		_filler("VISIBLE_TOP_SIX_A", 0), iono, visible_item,
		_filler("VISIBLE_TOP_SIX_B", 0), boss, _real_instance(GRASS_ENERGY_UID, 0),
		seventh_supporter,
	]
	for index: int in 12:
		player.deck.append(_filler("IONO_DRAW_%d" % index, 0))
	player.hand = [_filler("HAND_TO_BOTTOM", 0)]
	_fill_prizes(player, 4, "OWN_IONO_PRIZE")
	opponent.active_pokemon = _target("Public Iono opponent", 180, 1)
	opponent.hand = [_filler("OPPONENT_HAND_A", 1), _filler("OPPONENT_HAND_B", 1)]
	for index: int in 8:
		opponent.deck.append(_filler("OPPONENT_IONO_DRAW_%d" % index, 1))
	_fill_prizes(opponent, 2, "OPPONENT_IONO_PRIZE")
	gsm.effect_processor.register_pokemon_card(tatsugiri.get_card_data())
	var ability := gsm.effect_processor.get_ability_effect(tatsugiri, 0, state)
	var steps: Array = ability.get_interaction_steps(tatsugiri.get_top_card(), state) \
		if ability != null else []
	var pick_step := _step(steps, "look_top_pick")
	var supporter_items: Array = pick_step.get("items", [])
	var exact_top_six_boundary := iono in supporter_items and boss in supporter_items \
		and visible_item not in supporter_items and seventh_supporter not in supporter_items \
		and str(pick_step.get("visible_scope", "")) == "own_top_6_cards" \
		and int(pick_step.get("max_select", 0)) == 1
	var guest_call_used := gsm.use_ability(0, tatsugiri, 0, [{"look_top_pick": [iono]}])
	var iono_found := iono in player.hand and iono not in player.deck
	var iono_played := gsm.play_trainer(0, iono, [])
	var checkpoint_resolved := iono_played and state.supporter_used_this_turn \
		and player.hand.size() == 4 and opponent.hand.size() == 2 \
		and iono in player.discard_pile
	var second_supporter := _real_instance(BOSS_UID, 0)
	player.hand.append(second_supporter)
	var second_supporter_blocked := not gsm.play_trainer(0, second_supporter, [{
		"opponent_bench_target": [],
	}]) and second_supporter in player.hand
	var bench_state := _game_state(10)
	var bench_tatsugiri := _real_slot(TATSUGIRI_UID, 0)
	bench_state.players[0].active_pokemon = _real_slot(BUDEW_UID, 0)
	bench_state.players[0].bench = [bench_tatsugiri]
	bench_state.players[0].deck = [_real_instance(IONO_UID, 0)]
	bench_state.players[1].active_pokemon = _target("Public active-only target", 100, 1)
	var bench_processor := EffectProcessor.new()
	bench_processor.register_pokemon_card(bench_tatsugiri.get_card_data())
	var active_only := not bench_processor.can_use_ability(bench_tatsugiri, bench_state, 0)
	var passed := ability is AbilityLookTopToHand and exact_top_six_boundary \
		and guest_call_used and iono_found and checkpoint_resolved \
		and second_supporter_blocked and active_only \
		and not gsm.effect_processor.can_use_ability(tatsugiri, state, 0)
	_check(passed, "scenario D must use active Tatsugiri before Iono and enforce both visibility and Supporter quotas")
	_rows.append(_row(
		"tatsugiri_finds_iono_before_the_supporter_draw_checkpoint",
		"检索/支援者/信息检查点",
		"米立龙在前台先查看牌库顶6张并只拿奇树，再使用奇树按奖赏数补牌；未知的新手牌只在真实结算后成为下一决策输入。",
		"Guest Call(top 6): Iono -> resolve Iono checkpoint -> re-observe",
		["备战米立龙不可发动", "第7张牌与非支援者不可见/不可选", "奇树后不可再使用第二张支援者"],
		passed
	))


func _scenario_e_boss_then_jet_cyclone_closes_exactly_two_prizes() -> void:
	var gsm := GameStateMachine.new()
	gsm.game_state = _game_state(12)
	var state := gsm.game_state
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	var yanmega := _real_slot(YANMEGA_UID, 0)
	var backup := _real_slot(YANMA_UID, 0)
	var grass_a := _real_instance(GRASS_ENERGY_UID, 0)
	var grass_b := _real_instance(GRASS_ENERGY_UID, 0)
	var grass_c := _real_instance(GRASS_ENERGY_UID, 0)
	yanmega.attached_energy = [grass_a, grass_b, grass_c]
	player.active_pokemon = yanmega
	player.bench = [backup]
	var boss := _real_instance(BOSS_UID, 0)
	player.hand = [boss]
	_fill_prizes(player, 2, "OWN_FINAL_PRIZE")
	var old_active := _target("Public single-Prize Active", 180, 1)
	var exact_target := _target("Public exact 210 HP Bench ex", 210, 2)
	var over_breakpoint := _target("Public 211 HP Bench ex", 211, 2)
	opponent.active_pokemon = old_active
	opponent.bench = [exact_target, over_breakpoint]
	_fill_prizes(opponent, 3, "OPPONENT_PRIZE")
	gsm.effect_processor.register_pokemon_card(yanmega.get_card_data())
	var boss_effect := gsm.effect_processor.get_effect(boss.card_data.effect_id)
	var boss_steps: Array = boss_effect.get_interaction_steps(boss, state) if boss_effect != null else []
	var boss_step := _step(boss_steps, "opponent_bench_target")
	var boss_items: Array = boss_step.get("items", [])
	var exact_gust_surface := exact_target in boss_items and over_breakpoint in boss_items \
		and old_active not in boss_items and int(boss_step.get("max_select", 0)) == 1
	var boss_played := gsm.play_trainer(0, boss, [{
		"opponent_bench_target": [exact_target],
	}])
	var gust_resolved := opponent.active_pokemon == exact_target \
		and old_active in opponent.bench \
		and boss in player.discard_pile \
		and state.supporter_used_this_turn
	var preview_damage := gsm.get_attack_preview_damage(0, 0)
	var attack_steps: Array[Dictionary] = gsm.effect_processor.get_attack_interaction_steps_by_id(
		yanmega.get_card_data().effect_id,
		0,
		yanmega.get_top_card(),
		yanmega.get_card_data().attacks[0],
		state
	)
	var energy_step := _step(attack_steps, AttackMoveAttachedEnergyToOwnBench.ENERGY_STEP_ID)
	var target_step := _step(attack_steps, AttackMoveAttachedEnergyToOwnBench.TARGET_STEP_ID)
	var exact_attack_contract := preview_damage == 210 and preview_damage < 211 \
		and int(energy_step.get("min_select", 0)) == 3 \
		and int(energy_step.get("max_select", 0)) == 3 \
		and (target_step.get("items", []) as Array) == [backup]
	var attacked := gsm.use_attack(0, 0, [{
		AttackMoveAttachedEnergyToOwnBench.ENERGY_STEP_ID: [grass_a, grass_b, grass_c],
		AttackMoveAttachedEnergyToOwnBench.TARGET_STEP_ID: [backup],
	}])
	var energy_handoff := attacked and yanmega.attached_energy.is_empty() \
		and backup.attached_energy == [grass_a, grass_b, grass_c]
	var exact_ko_only := exact_target.damage_counters == 210 \
		and over_breakpoint.damage_counters == 0
	var first_prize := gsm.resolve_take_prize(0, 0)
	var second_prize := gsm.resolve_take_prize(0, 1)
	var closes_game := first_prize and second_prize \
		and player.prizes.is_empty() and state.is_game_over()
	var route_biases: Dictionary = _profile.get("route_preferences", {}).get("route_biases", {})
	var terminal_bias := float(route_biases.get("route:attack_ko", 0.0)) \
		> float(route_biases.get("route:information", 0.0)) \
		and bool(_profile.get("safety", {}).get("reject_information_churn_after_ko_secured", false))
	_check(boss_effect is EffectBossOrders, "scenario E must resolve the real Boss's Orders effect")
	_check(exact_gust_surface, "scenario E Boss target surface must contain only the two Benched targets")
	_check(boss_played and gust_resolved, "scenario E Boss must move the exact 210 HP ex Active")
	_check(exact_attack_contract, "scenario E Jet Cyclone must expose exact 210/three-Energy/one-target boundaries")
	_check(energy_handoff, "scenario E Jet Cyclone must move exactly the selected three Energy to Yanma")
	_check(exact_ko_only, "scenario E must knock out 210 HP without damaging the 211 HP boundary target")
	_check(closes_game, "scenario E must resolve both pending Prizes and finish with zero Prizes " \
		+ "(first=%s second=%s prizes=%d game_over=%s phase=%s)" % [
			str(first_prize), str(second_prize), player.prizes.size(), str(state.is_game_over()), str(state.phase),
		])
	_check(terminal_bias, "scenario E profile must rank deterministic KO above information churn")
	var passed := boss_effect is EffectBossOrders and exact_gust_surface and boss_played \
		and gust_resolved and exact_attack_contract and energy_handoff \
		and exact_ko_only and closes_game and terminal_bias
	_check(passed, "scenario E must Boss the exact 210 HP ex, move exactly three Energy, and take the final two Prizes")
	_rows.append(_row(
		"boss_then_jet_cyclone_closes_exactly_two_prizes",
		"点杀/奖赏终局/能量交接",
		"只剩2张奖赏时，老大的指令拉出恰好210HP的后排ex，喷射旋风完成击倒并把3张草能量交给下一只宝可梦，立即结束比赛。",
		"Boss's Orders exact 210 HP ex -> Jet Cyclone 210 -> move Grass x3 -> take final 2 Prizes",
		["Boss只能选择对手备战宝可梦", "210不能击倒211HP目标", "已确定终局后不得继续信息抽牌"],
		passed
	))


func _game_state(turn: int) -> GameState:
	CardInstance.reset_id_counter()
	var state := GameState.new()
	state.current_player_index = 0
	state.first_player_index = 0
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


func _real_slot(uid: String, owner: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(_real_instance(uid, owner))
	return slot


func _target(name: String, hp: int, prizes: int) -> PokemonSlot:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = "Pokemon"
	data.stage = "Basic"
	data.hp = hp
	data.mechanic = "ex" if prizes == 2 else ""
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(data, 1))
	return slot


func _unrelated_stage_one(owner: int) -> CardInstance:
	var data := CardData.new()
	data.name = "Unrelated Stage 1"
	data.name_en = data.name
	data.card_type = "Pokemon"
	data.stage = "Stage 1"
	data.evolves_from = "No matching root"
	data.hp = 100
	return CardInstance.create(data, owner)


func _filler(name: String, owner: int) -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = "Item"
	data.set_code = "FIXTURE"
	data.card_index = name
	return CardInstance.create(data, owner)


func _fill_prizes(player: PlayerState, count: int, prefix: String) -> void:
	player.prizes.clear()
	for index: int in count:
		player.prizes.append(_filler("%s_%d" % [prefix, index], player.player_index))


func _step(steps: Array, id: String) -> Dictionary:
	for raw_step: Variant in steps:
		if raw_step is Dictionary and str((raw_step as Dictionary).get("id", "")) == id:
			return raw_step as Dictionary
	return {}


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
	var fingerprint_verified := _current_fingerprint != "" \
		and _current_fingerprint == str(_manifest.get("deck_content_fingerprint", ""))
	var historical_profile_version := 0
	var historical_reports: Array = _historical_round.get("reports", [])
	if not historical_reports.is_empty() and historical_reports[0] is Dictionary:
		historical_profile_version = int((historical_reports[0] as Dictionary).get("profile_version", 0))
	var report := {
		"schema_version": 1,
		"architecture": "V18CPG",
		"semantic_schema": "v18cpg-2",
		"transport_contract_version": 3,
		"deck_id": DECK_ID,
		"deck_name": str(_deck_seed.get("deck_name", "18.0 远古巨蜓")),
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
			"fingerprint_verified": fingerprint_verified,
		},
		"strength_evidence": {
			"status": "no_current_fingerprint_aligned_paired_ledger",
			"new_round_run": false,
			"ledger_modified": false,
			"excluded_historical_round": HISTORICAL_ROUND_PATH,
			"excluded_round_profile_version": historical_profile_version,
			"current_profile_version": int(_profile.get("profile_version", 0)),
			"exclusion_reason": "round00 has no deck_source or deck_content_fingerprint binding and used an older profile version",
			"interpretation": "These five real-engine fixtures are scenario evidence only, not a paired-strength, win-rate, or promotion claim.",
		},
		"scope": "deck-scoped focused real-engine scenario coverage only; no real-model formal benchmark",
		"scenario_count": _rows.size(),
		"passed_count": _rows.filter(func(row: Dictionary) -> bool: return bool(row.get("passed", false))).size(),
		"all_passed": _failures.is_empty() and _rows.size() == 5,
		"production_status": "scenario_contract_ready_strength_unverified",
		"known_production_gaps": [
			"These fixtures do not create a strength round or alter any optimization ledger.",
			"The existing round00 lacks current bundled_ai fingerprint binding and is excluded from strength evidence.",
			"Fresh current-fingerprint paired evidence remains required before any superiority or promotion claim.",
		],
		"isolation": {
			"profile_modified": false,
			"shared_strategy_modified": false,
			"shared_registry_modified": false,
			"shared_strategic_shape_modified": false,
			"rule_or_legacy_or_agent_modified": false,
			"ledger_modified": false,
			"real_model_formal_run": false,
		},
		"coverage": [
			"real Jet Energy switch into one-use Buzzing Rush with exactly three Basic Grass and a strict Special-Energy exclusion",
			"one real TM Evolution preserving the Yanma/Yanmega and Dunsparce/Dudunsparce lanes through an authorized full-deck view",
			"real Run Away Draw drawing three, recycling the full stack, and requiring one legal Active replacement",
			"active-only Tatsugiri top-six Supporter search into a real Iono information checkpoint with Supporter quota enforcement",
			"real Boss's Orders into exact 210 damage, three-Energy handoff, knockout processing, and final two-Prize resolution",
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
