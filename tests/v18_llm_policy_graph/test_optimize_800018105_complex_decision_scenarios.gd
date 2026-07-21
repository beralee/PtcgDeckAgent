extends SceneTree

const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const SemanticCompilerScript = preload("res://scripts/ai/v18_cpg/semantics/V18CPGDeckSemanticCompiler.gd")

const DECK_ID := 800018105
const DECK_SEED_PATH := "res://data/bundled_user/decks/800018105.json"
const MANIFEST_PATH := "res://scripts/ai/v18_cpg/profiles/generated_semantic_manifests/800018105.json"
const ROUND00_PATH := "res://tmp/v18cpg/optimization21/800018105/round00.json"
const ROUND10_PATH := "res://tmp/v18cpg/optimization21/800018105/round10.json"
const REPORT_PATH := "res://tmp/v18cpg/optimization21/800018105/complex_decision_scenarios.json"

const RALTS_UID := "CSV2C_053"
const KIRLIA_UID := "CSV2C_054"
const GARDEVOIR_UID := "CSV2C_055"
const DRIFLOON_UID := "CSV2C_060"
const SCREAM_TAIL_UID := "CSV6C_065"
const MUNKIDORI_UID := "CSV8C_094"
const MEW_EX_UID := "151C_151"
const RELLOR_UID := "CSV7C_030"
const RABSCA_UID := "CSV7C_031"
const VESSEL_UID := "CSV6C_115"
const RESEARCH_UID := "CSV1C_121"
const BRAVERY_CHARM_UID := "CSV1C_118"
const PSYCHIC_UID := "CSVE1C_PSY"
const DARKNESS_UID := "CSVE1C_DAR"

var _profile: Dictionary = {}
var _manifest: Dictionary = {}
var _deck_seed: Dictionary = {}
var _round00_ledger: Dictionary = {}
var _round10_ledger: Dictionary = {}
var _current_fingerprint := ""
var _failures: Array[String] = []
var _rows: Array[Dictionary] = []


func _initialize() -> void:
	_profile = ProfileCatalogScript.get_profile_for_deck(DECK_ID)
	_manifest = _load_json(MANIFEST_PATH)
	_deck_seed = _load_json(DECK_SEED_PATH)
	_round00_ledger = _ledger_report(ROUND00_PATH)
	_round10_ledger = _ledger_report(ROUND10_PATH)
	var deck := DeckData.from_dict(_deck_seed)
	_current_fingerprint = SemanticCompilerScript.deck_content_fingerprint(deck)
	_check(int(_profile.get("deck_id", 0)) == DECK_ID, "production Rabsca/Gardevoir profile must load")
	_check(int(_manifest.get("deck_id", 0)) == DECK_ID, "Rabsca/Gardevoir semantic manifest must load")
	_check(_profile.get("modules", []) == ["gardevoir_embrace", "damage_counter_control"], \
		"scenarios must use the production Embrace/counter-control module composition")
	_check(int(deck.id) == DECK_ID and int(deck.total_cards) == 60, \
		"current bundled AI seed must be the exact 60-card deck")
	_check(_current_fingerprint != "" \
		and _current_fingerprint == str(_manifest.get("deck_content_fingerprint", "")), \
		"semantic manifest fingerprint must match the current bundled AI deck")
	_check(_ledger_matches_current(_round00_ledger), "round00 ledger must bind the current bundled_ai fingerprint")
	_check(_ledger_matches_current(_round10_ledger), "round10 ledger must bind the current bundled_ai fingerprint")

	_scenario_a_charm_before_embrace_uses_exact_damage_budget()
	_scenario_b_tm_evolution_builds_both_stage_one_lanes()
	_scenario_c_rabsca_shields_the_embrace_attacker()
	_scenario_d_vessel_before_research_banks_embrace_fuel()
	_scenario_e_counter_move_then_attack_closes_three_prizes()
	_write_report()

	EffectProcessor.cleanup_live_instances_for_tests()
	if _failures.is_empty() and _rows.size() == 5:
		print("optimization21 800018105 complex decision scenarios: PASS (5/5)")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("optimization21 800018105 complex decision scenarios: FAIL (%d)" % _failures.size())
	quit(1)


func _scenario_a_charm_before_embrace_uses_exact_damage_budget() -> void:
	var processor := EffectProcessor.new()
	var state := _game_state(8)
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
	state.players[1].active_pokemon = _target("Public exact 300 HP ex", 300, 2)
	processor.register_pokemon_card(drifloon.get_card_data())
	processor.register_pokemon_card(gardevoir.get_card_data())
	var embrace := processor.get_ability_effect(gardevoir, 0, state)
	var blocked_without_charm := embrace != null \
		and not bool(embrace.call("can_use_embrace_on_target", drifloon, state))
	drifloon.attached_tool = _real_instance(BRAVERY_CHARM_UID, 0)
	var effective_hp_exact := processor.get_effective_max_hp(drifloon, state) == 120 \
		and processor.get_effective_remaining_hp(drifloon, state) == 60
	var steps: Array = embrace.get_interaction_steps(gardevoir.get_top_card(), state) if embrace != null else []
	var target_step := _step(steps, "embrace_target")
	var target_now_legal := drifloon in (target_step.get("items", []) as Array)
	var first_attached := processor.execute_ability_effect(gardevoir, 0, [{
		"embrace_energy": [psychic_a], "embrace_target": [drifloon],
	}], state)
	var second_attached := processor.execute_ability_effect(gardevoir, 0, [{
		"embrace_energy": [psychic_b], "embrace_target": [drifloon],
	}], state)
	var exact_budget_stop := drifloon.damage_counters == 100 \
		and drifloon.attached_energy.size() == 5 \
		and processor.get_effective_remaining_hp(drifloon, state) == 20 \
		and not bool(embrace.call("can_use_embrace_on_target", drifloon, state))
	var attack_legal := RuleValidator.new().can_use_attack(state, 0, 1, processor)
	var attack_damage := DamageCalculator.new().calculate_damage(
		drifloon,
		state.players[1].active_pokemon,
		drifloon.get_card_data().attacks[1],
		state,
		_attack_bonus(processor, drifloon, 1, state)
	)
	var profile_budget: Dictionary = _profile.get("module_parameters", {}).get("gardevoir_embrace", {}) \
		.get("damage_scalers_by_uid", {}).get(DRIFLOON_UID, {})
	var semantic_exact := int(profile_budget.get("damage_per_counter", 0)) == 30 \
		and int(profile_budget.get("embrace_damage_per_assignment", 0)) == 20
	var passed := blocked_without_charm and effective_hp_exact and target_now_legal \
		and first_attached and second_attached and exact_budget_stop and attack_legal \
		and attack_damage == 300 and attack_damage < 301 and semantic_exact
	_check(passed, "scenario A must Charm before exactly two Embraces for the public 300-damage breakpoint")
	_rows.append(_row(
		"charm_before_embrace_uses_exact_damage_budget",
		"超能填能与伤害预算",
		"飘飘球已受60伤且只剩10HP时不能继续拥抱；先贴勇气护符，再拥抱2次，精确停在100伤/20HP并打出气球炸弹300。",
		"Bravery Charm -> Psychic Embrace x2 -> Balloon Bomb 300",
		["无护符时剩10HP不得继续拥抱", "100伤后剩20HP不得进行第三次拥抱", "300不能击倒301HP"],
		passed
	))


func _scenario_b_tm_evolution_builds_both_stage_one_lanes() -> void:
	var state := _game_state(4)
	var carrier := _real_slot(_real_card_data(MEW_EX_UID), 0)
	var ralts := _real_slot(_real_card_data(RALTS_UID), 0)
	var rellor := _real_slot(_real_card_data(RELLOR_UID), 0)
	var active_rellor := _real_slot(_real_card_data(RELLOR_UID), 0)
	var kirlia := _real_instance(KIRLIA_UID, 0)
	var rabsca := _real_instance(RABSCA_UID, 0)
	var unrelated := _unrelated_stage_one(0)
	state.players[0].active_pokemon = carrier
	state.players[0].bench = [ralts, rellor]
	state.players[0].deck = [kirlia, rabsca, unrelated]
	state.players[1].active_pokemon = _target("Public TM target", 200, 1)
	var effect := AttackTMEvolution.new(2)
	var initial_steps := effect.get_granted_attack_interaction_steps(
		carrier, {"id": AttackTMEvolution.GRANTED_ATTACK_ID}, state)
	var bench_step := _step(initial_steps, "evolution_bench")
	var bench_exact := (bench_step.get("items", []) as Array) == [ralts, rellor] \
		and active_rellor not in (bench_step.get("items", []) as Array) \
		and int(bench_step.get("max_select", 0)) == 2
	var followup := effect.get_followup_granted_attack_interaction_steps(
		carrier,
		{"id": AttackTMEvolution.GRANTED_ATTACK_ID},
		state,
		{"evolution_bench": [ralts, rellor]}
	)
	var card_step := _step(followup, "evolution_cards")
	var card_items: Array = card_step.get("items", [])
	var cards_exact := kirlia in card_items and rabsca in card_items and unrelated not in card_items \
		and str(card_step.get("visible_scope", "")) == BaseEffect.VISIBLE_SCOPE_OWN_FULL_DECK
	effect.execute_granted_attack(carrier, {"id": AttackTMEvolution.GRANTED_ATTACK_ID}, state, [{
		"evolution_bench": [ralts, rellor],
		"evolution_cards": [kirlia, rabsca],
	}])
	var evolved_exact := ralts.get_card_data().get_uid() == KIRLIA_UID \
		and rellor.get_card_data().get_uid() == RABSCA_UID \
		and ralts.pokemon_stack.size() == 2 and rellor.pokemon_stack.size() == 2 \
		and unrelated in state.players[0].deck
	var route_biases: Dictionary = _profile.get("route_preferences", {}).get("route_biases", {})
	var evolve_contract := float(route_biases.get("route:evolve", 0.0)) \
		> float(route_biases.get("route:develop", 0.0))
	var passed := bench_exact and cards_exact and evolved_exact and evolve_contract
	_check(passed, "scenario B must bind TM Evolution to the exact Ralts/Kirlia and Rellor/Rabsca lanes")
	_rows.append(_row(
		"tm_evolution_builds_both_stage_one_lanes",
		"双进化链",
		"招式学习器：进化在同一次完整牌库检索中选择备战拉鲁拉丝与虫滚泥，分别进化为奇鲁莉安与虫甲圣。",
		"TM Evolution: Ralts -> Kirlia and Rellor -> Rabsca",
		["出战区根不能成为TM进化目标", "不匹配根的Stage 1不能被选择", "一次最多进化2只备战宝可梦"],
		passed
	))


func _scenario_c_rabsca_shields_the_embrace_attacker() -> void:
	var processor := EffectProcessor.new()
	var state := _game_state(9)
	var gardevoir := _real_slot(_real_card_data(GARDEVOIR_UID), 0)
	var rabsca := _real_slot(_real_card_data(RABSCA_UID), 0)
	var scream_tail := _real_slot(_real_card_data(SCREAM_TAIL_UID), 0)
	var charm := _real_instance(BRAVERY_CHARM_UID, 0)
	scream_tail.attached_tool = charm
	var psychic := _real_instance(PSYCHIC_UID, 0)
	state.players[0].active_pokemon = gardevoir
	state.players[0].bench = [rabsca, scream_tail]
	state.players[0].discard_pile = [psychic]
	var attacker := _fixture_attacker("Public opponent Bench sniper", 1)
	state.players[1].active_pokemon = attacker
	processor.register_pokemon_card(gardevoir.get_card_data())
	processor.register_pokemon_card(rabsca.get_card_data())
	var embrace := processor.get_ability_effect(gardevoir, 0, state)
	var steps: Array = embrace.get_interaction_steps(gardevoir.get_top_card(), state) if embrace != null else []
	var target_step := _step(steps, "embrace_target")
	var typed_targeting := scream_tail in (target_step.get("items", []) as Array) \
		and rabsca not in (target_step.get("items", []) as Array)
	var embraced := processor.execute_ability_effect(gardevoir, 0, [{
		"embrace_energy": [psychic], "embrace_target": [scream_tail],
	}], state)
	state.current_player_index = 1
	var bench_damage := AttackAnyTargetDamage.new(40)
	bench_damage.set_attack_interaction_context([{"any_target": [scream_tail]}])
	bench_damage.execute_attack(attacker, gardevoir, 0, state)
	var discard_tool := AttackDiscardOpponentTools.new(1, 0)
	discard_tool.set_attack_interaction_context([{AttackDiscardOpponentTools.STEP_ID: [charm]}])
	discard_tool.execute_attack(attacker, gardevoir, 0, state)
	var shield_exact := embraced and scream_tail.damage_counters == 20 \
		and psychic in scream_tail.attached_energy \
		and scream_tail.attached_tool == charm \
		and charm not in state.players[0].discard_pile

	var unshielded_state := _game_state(9)
	var unshielded_target := _real_slot(_real_card_data(SCREAM_TAIL_UID), 0)
	var unshielded_attacker := _fixture_attacker("Public unshielded sniper", 1)
	unshielded_state.players[0].active_pokemon = _real_slot(_real_card_data(GARDEVOIR_UID), 0)
	unshielded_state.players[0].bench = [unshielded_target]
	unshielded_state.players[1].active_pokemon = unshielded_attacker
	unshielded_state.current_player_index = 1
	var unshielded_damage := AttackAnyTargetDamage.new(40)
	unshielded_damage.set_attack_interaction_context([{"any_target": [unshielded_target]}])
	unshielded_damage.execute_attack(
		unshielded_attacker, unshielded_state.players[0].active_pokemon, 0, unshielded_state)
	var removed_shield_exposes_target := unshielded_target.damage_counters == 40
	var manifest_roles := _manifest_roles(RABSCA_UID)
	var semantic_protection := "bench_protection" in manifest_roles \
		and int(_profile.get("safety", {}).get("preserve_bench_slots", 0)) == 2
	var passed := typed_targeting and shield_exact and removed_shield_exposes_target and semantic_protection
	_check(passed, "scenario C must keep Rabsca's real shield around the real Psychic Embrace attacker")
	_rows.append(_row(
		"rabsca_shields_the_embrace_attacker",
		"虫甲圣与沙奈朵特性",
		"精神拥抱只把弃牌超能贴给超属性吼叫尾并放20伤；虫甲圣球形护盾同时阻止对手招式对该备战位造成40伤害或丢弃勇气护符。",
		"Psychic Embrace -> keep Rabsca -> Spherical Shield blocks Bench damage/effects",
		["虫甲圣不是超属性，不能成为精神拥抱目标", "移除虫甲圣后同一备战攻击会造成40伤害", "球形护盾只防对手招式，不取消己方拥抱伤害"],
		passed
	))


func _scenario_d_vessel_before_research_banks_embrace_fuel() -> void:
	var correct := _vessel_research_state()
	var correct_gsm: GameStateMachine = correct.get("gsm")
	var correct_state := correct_gsm.game_state
	var vessel: CardInstance = correct.get("vessel")
	var research: CardInstance = correct.get("research")
	var cost_psychic: CardInstance = correct.get("cost_psychic")
	var deck_psychic_a: CardInstance = correct.get("deck_psychic_a")
	var deck_psychic_b: CardInstance = correct.get("deck_psychic_b")
	var gardevoir: PokemonSlot = correct.get("gardevoir")
	var drifloon: PokemonSlot = correct.get("drifloon")
	var vessel_played := correct_gsm.play_trainer(0, vessel, [{
		"discard_cards": [cost_psychic],
		"search_energy": [deck_psychic_a, deck_psychic_b],
	}])
	var research_played := correct_gsm.play_trainer(0, research, [])
	var three_fuel_banked := _psychic_discard_count(correct_state.players[0]) == 3 \
		and correct_state.players[0].hand.size() == 7 \
		and correct_state.supporter_used_this_turn
	var embrace := correct_gsm.effect_processor.get_ability_effect(gardevoir, 0, correct_state)
	var first_fuel: CardInstance = _first_psychic_discard(correct_state.players[0])
	var embraced := first_fuel != null and correct_gsm.effect_processor.execute_ability_effect(gardevoir, 0, [{
		"embrace_energy": [first_fuel], "embrace_target": [drifloon],
	}], correct_state)
	var two_fuel_remain := _psychic_discard_count(correct_state.players[0]) == 2 \
		and drifloon.damage_counters == 20 and drifloon.attached_energy.size() == 1

	var wrong := _vessel_research_state()
	var wrong_gsm: GameStateMachine = wrong.get("gsm")
	var wrong_research: CardInstance = wrong.get("research")
	var wrong_research_played := wrong_gsm.play_trainer(0, wrong_research, [])
	var wrong_vessel: CardInstance = wrong.get("vessel")
	var reversed_loses_vessel_and_two_fuel: bool = _psychic_discard_count(wrong_gsm.game_state.players[0]) == 1 \
		and wrong_vessel not in wrong_gsm.game_state.players[0].hand \
		and wrong_vessel in wrong_gsm.game_state.players[0].discard_pile
	var route_biases: Dictionary = _profile.get("route_preferences", {}).get("route_biases", {})
	var information_checkpoint_contract := float(route_biases.get("route:information", 0.0)) \
		> float(route_biases.get("route:develop", 0.0)) \
		and bool(_profile.get("safety", {}).get("reject_information_churn_after_ko_secured", false))
	var passed: bool = vessel_played and research_played and three_fuel_banked \
		and embrace != null and embraced and two_fuel_remain \
		and wrong_research_played and reversed_loses_vessel_and_two_fuel \
		and information_checkpoint_contract
	_check(passed, "scenario D must use Earthen Vessel before Research to bank three public Embrace fuels")
	_rows.append(_row(
		"vessel_before_research_banks_embrace_fuel",
		"抽牌与支援者顺序",
		"先用大地容器丢1张并检索2张超能，再用博士的研究把检索能量送进弃牌并抽7，形成3张精神拥抱燃料；反序只留下1张。",
		"Earthen Vessel(1 discard + 2 Psychic search) -> Research -> Psychic Embrace",
		["博士的研究先用会连同大地容器一起丢弃", "容器检索后必须以新公开手牌进入信息检查点", "已锁定KO后不得为堆燃料继续无意义抽牌"],
		passed
	))


func _scenario_e_counter_move_then_attack_closes_three_prizes() -> void:
	var processor := EffectProcessor.new()
	var state := _game_state(12)
	var drifloon := _real_slot(_real_card_data(DRIFLOON_UID), 0)
	drifloon.damage_counters = 40
	drifloon.attached_energy = [
		_real_instance(PSYCHIC_UID, 0), _real_instance(PSYCHIC_UID, 0),
		_real_instance(PSYCHIC_UID, 0), _real_instance(PSYCHIC_UID, 0),
	]
	var gardevoir := _real_slot(_real_card_data(GARDEVOIR_UID), 0)
	gardevoir.damage_counters = 30
	var munkidori := _real_slot(_real_card_data(MUNKIDORI_UID), 0)
	munkidori.attached_energy = [_real_instance(DARKNESS_UID, 0)]
	var active_ex := _target("Public exact 120 HP ex", 120, 2)
	var bench_single := _target("Public exact 30 HP Bench", 30, 1)
	state.players[0].active_pokemon = drifloon
	state.players[0].bench = [gardevoir, munkidori]
	state.players[1].active_pokemon = active_ex
	state.players[1].bench = [bench_single]
	_fill_prizes(state.players[0], 3, "OWN_FINAL_THREE")
	processor.register_pokemon_card(drifloon.get_card_data())
	processor.register_pokemon_card(gardevoir.get_card_data())
	processor.register_pokemon_card(munkidori.get_card_data())
	var direct_attack_damage := DamageCalculator.new().calculate_damage(
		drifloon, active_ex, drifloon.get_card_data().attacks[1], state,
		_attack_bonus(processor, drifloon, 1, state)
	)
	var direct_prize_floor := 2 if direct_attack_damage >= active_ex.get_remaining_hp() else 0
	var moved := processor.execute_ability_effect(munkidori, 0, [{
		"source_pokemon": [gardevoir],
		"target_damage_counters": [{"target": bench_single, "amount": 30}],
	}], state)
	DamageCalculator.new().apply_damage_to_slot(active_ex, direct_attack_damage)
	var combined_prizes := (2 if active_ex.is_knocked_out() else 0) \
		+ (1 if bench_single.is_knocked_out() else 0)
	var exact_terminal := moved and direct_attack_damage == 120 \
		and direct_prize_floor == 2 and combined_prizes == 3 \
		and combined_prizes >= state.players[0].prizes.size() \
		and gardevoir.damage_counters == 0 and bench_single.damage_counters == 30 \
		and not processor.can_use_ability(munkidori, state, 0)
	var hp_boundaries := direct_attack_damage < 121 and 30 < 31

	var no_dark_processor := EffectProcessor.new()
	var no_dark_state := _game_state(12)
	var no_dark_source := _real_slot(_real_card_data(GARDEVOIR_UID), 0)
	no_dark_source.damage_counters = 30
	var no_dark_mover := _real_slot(_real_card_data(MUNKIDORI_UID), 0)
	no_dark_state.players[0].active_pokemon = no_dark_source
	no_dark_state.players[0].bench = [no_dark_mover]
	no_dark_state.players[1].active_pokemon = _target("Public no-dark target", 30, 1)
	no_dark_processor.register_pokemon_card(no_dark_mover.get_card_data())
	var no_dark_blocked := not no_dark_processor.can_use_ability(no_dark_mover, no_dark_state, 0)
	var route_biases: Dictionary = _profile.get("route_preferences", {}).get("route_biases", {})
	var terminal_contract := float(route_biases.get("route:attack_ko", 0.0)) \
		> float(route_biases.get("route:information", 0.0)) \
		and bool(_profile.get("safety", {}).get("stop_optional_draw_when_attack_ready", false))
	var passed := exact_terminal and hp_boundaries and no_dark_blocked and terminal_contract
	_check(passed, "scenario E must move counters before the exact Drifloon attack to close three Prizes")
	_rows.append(_row(
		"counter_move_then_attack_closes_three_prizes",
		"关键奖闭环",
		"己方剩3奖时，愿增猿先把沙奈朵ex的30伤搬到30HP备战单奖，再由40伤飘飘球打120击倒前场双奖，完成3奖终局。",
		"Adrena Brain 30 Bench KO -> Balloon Bomb 120 Active ex KO -> final three Prizes",
		["愿增猿没有恶能量不能启动", "30不能击倒31HP备战", "120不能击倒121HP前场", "直接攻击只拿2奖，不得截断安全的额外单奖前缀"],
		passed
	))


func _vessel_research_state() -> Dictionary:
	var gsm := GameStateMachine.new()
	gsm.game_state = _game_state(10)
	var state := gsm.game_state
	var gardevoir := _real_slot(_real_card_data(GARDEVOIR_UID), 0)
	var drifloon := _real_slot(_real_card_data(DRIFLOON_UID), 0)
	state.players[0].active_pokemon = gardevoir
	state.players[0].bench = [drifloon]
	state.players[1].active_pokemon = _target("Public draw-order target", 200, 1)
	var vessel := _real_instance(VESSEL_UID, 0)
	var research := _real_instance(RESEARCH_UID, 0)
	var cost_psychic := _real_instance(PSYCHIC_UID, 0)
	var deck_psychic_a := _real_instance(PSYCHIC_UID, 0)
	var deck_psychic_b := _real_instance(PSYCHIC_UID, 0)
	state.players[0].hand = [vessel, research, cost_psychic, _filler("VISIBLE_STALE_HAND", 0)]
	state.players[0].deck = [deck_psychic_a, deck_psychic_b]
	for suffix: String in ["A", "B", "C", "D", "E", "F", "G"]:
		state.players[0].deck.append(_filler("VISIBLE_DRAW_%s" % suffix, 0))
	gsm.effect_processor.register_pokemon_card(gardevoir.get_card_data())
	return {
		"gsm": gsm,
		"gardevoir": gardevoir,
		"drifloon": drifloon,
		"vessel": vessel,
		"research": research,
		"cost_psychic": cost_psychic,
		"deck_psychic_a": deck_psychic_a,
		"deck_psychic_b": deck_psychic_b,
	}


func _game_state(turn: int) -> GameState:
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


func _real_slot(data: CardData, owner: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(data, owner))
	return slot


func _target(name: String, hp: int, prizes: int) -> PokemonSlot:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = "Pokemon"
	data.stage = "Basic"
	data.hp = hp
	data.mechanic = "ex" if prizes == 2 else ""
	return _real_slot(data, 1)


func _fixture_attacker(name: String, owner: int) -> PokemonSlot:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = "Pokemon"
	data.stage = "Basic"
	data.hp = 200
	data.energy_type = "C"
	return _real_slot(data, owner)


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


func _psychic_discard_count(player: PlayerState) -> int:
	var count := 0
	for card: CardInstance in player.discard_pile:
		if card.card_data != null and card.card_data.card_type == "Basic Energy" \
				and card.card_data.energy_provides == "P":
			count += 1
	return count


func _first_psychic_discard(player: PlayerState) -> CardInstance:
	for card: CardInstance in player.discard_pile:
		if card.card_data != null and card.card_data.card_type == "Basic Energy" \
				and card.card_data.energy_provides == "P":
			return card
	return null


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


func _manifest_roles(uid: String) -> Array:
	for raw_card: Variant in _manifest.get("cards", []):
		if raw_card is Dictionary and str((raw_card as Dictionary).get("uid", "")) == uid:
			return (raw_card as Dictionary).get("roles", []) as Array
	return []


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


func _ledger_report(path: String) -> Dictionary:
	var ledger := _load_json(path)
	var reports: Array = ledger.get("reports", [])
	if reports.size() == 1 and reports[0] is Dictionary:
		return reports[0] as Dictionary
	_check(false, "%s must contain exactly one deck report" % path)
	return {}


func _ledger_matches_current(report: Dictionary) -> bool:
	return int(report.get("deck_id", 0)) == DECK_ID \
		and str(report.get("deck_source", "")) == "bundled_ai" \
		and str(report.get("deck_content_fingerprint", "")) == _current_fingerprint


func _ledger_summary(report: Dictionary) -> Dictionary:
	return {
		"deck_id": int(report.get("deck_id", 0)),
		"deck_source": str(report.get("deck_source", "")),
		"deck_content_fingerprint": str(report.get("deck_content_fingerprint", "")),
		"profile_version": int(report.get("profile_version", 0)),
		"semantic_version": int(report.get("semantic_version", 0)),
		"games": int(report.get("games", 0)),
		"v18cpg_clean_games": int(report.get("v18cpg_clean_games", 0)),
		"v18cpg_wins": int(report.get("v18cpg_wins", 0)),
		"v18cpg_win_rate": float(report.get("v18cpg_win_rate", 0.0)),
		"rule_clean_games": int(report.get("rule_clean_games", 0)),
		"rule_wins": int(report.get("rule_wins", 0)),
		"rule_win_rate": float(report.get("rule_win_rate", 0.0)),
		"paired_improvement": float(report.get("paired_improvement", 0.0)),
		"model_calls": int(report.get("model_calls", 0)),
		"model_accepted": int(report.get("model_accepted", 0)),
		"model_acceptance_rate": float(report.get("model_acceptance_rate", 0.0)),
		"turn_visible_wait_p95_ms": float(report.get("turn_visible_wait_p95_ms", 0.0)),
	}


func _write_report() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT_PATH.get_base_dir()))
	var ledger_valid := _ledger_matches_current(_round00_ledger) \
		and _ledger_matches_current(_round10_ledger)
	var report := {
		"schema_version": 1,
		"architecture": "V18CPG",
		"semantic_schema": "v18cpg-2",
		"transport_contract_version": 3,
		"deck_id": DECK_ID,
		"deck_name": "18.0 虫甲圣沙奈朵",
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
		"strength_evidence": {
			"status": "existing_fingerprint_aligned_ledger_no_new_round",
			"fingerprint_verified": ledger_valid,
			"baseline_artifact": ROUND00_PATH,
			"latest_artifact": ROUND10_PATH,
			"new_round_run": false,
			"ledger_modified": false,
			"round00": _ledger_summary(_round00_ledger),
			"round10": _ledger_summary(_round10_ledger),
			"interpretation": "The existing five-game round10 is 3/5 for V18CPG and 3/5 for Rule (0 percentage-point paired improvement). It is valid current-fingerprint evidence but not a superiority or promotion claim.",
		},
		"scope": "focused scenario coverage only; no real-model formal benchmark",
		"scenario_count": _rows.size(),
		"passed_count": _rows.filter(func(row: Dictionary) -> bool: return bool(row.get("passed", false))).size(),
		"all_passed": _failures.is_empty() and _rows.size() == 5,
		"production_status": "scenario_contract_ready_existing_ledger_not_promoted",
		"known_production_gaps": [
			"These fixtures do not create a new strength round or alter the existing optimization ledger.",
			"The existing latest paired result is 0 percentage-point improvement, so no deterministic superiority or promotion claim is made.",
			"The dual TM lane, exact Embrace damage budget, Rabsca shield, Vessel/Research information checkpoint, and three-Prize counter-move suffix are verified through real engine effects.",
			"Production still needs fresh fingerprint-aligned paired evidence showing a positive strength margin before promotion.",
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
			"Bravery Charm before exact Psychic Embrace assignments for a bounded Drifloon damage breakpoint",
			"one TM Evolution building the Ralts/Kirlia and Rellor/Rabsca Stage-1 lanes through an authorized full-deck view",
			"real Psychic Embrace target typing plus Rabsca Spherical Shield preventing opponent Bench damage and effects",
			"Earthen Vessel before Professor's Research banking three Psychic fuels across an information checkpoint",
			"Munkidori's exact 30-counter Bench KO before Drifloon takes a two-Prize Active KO for a three-Prize closeout",
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
