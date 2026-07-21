extends SceneTree

const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const SemanticCompilerScript = preload("res://scripts/ai/v18_cpg/semantics/V18CPGDeckSemanticCompiler.gd")

const DECK_ID := 800018498
const DECK_SEED_PATH := "res://data/bundled_user/decks/800018498.json"
const MANIFEST_PATH := "res://scripts/ai/v18_cpg/profiles/generated_semantic_manifests/800018498.json"
const REPORT_PATH := "res://tmp/v18cpg/optimization21/800018498/complex_decision_scenarios.json"

const RALTS_UID := "CSV2C_053"
const KIRLIA_UID := "CSV2C_054"
const GARDEVOIR_UID := "CSV2C_055"
const DRIFLOON_UID := "CSV2C_060"
const SCREAM_TAIL_UID := "CSV6C_065"
const MUNKIDORI_UID := "CSV8C_094"
const SHAYMIN_UID := "CSV10C_007"
const CLEFAIRY_EX_UID := "CSV10C_082"
const VESSEL_UID := "CSV6C_115"
const RESEARCH_UID := "CSV1C_121"
const COUNTER_CATCHER_UID := "CSV6C_114"
const BRAVERY_CHARM_UID := "CSV1C_118"
const PSYCHIC_UID := "CSVE1C_PSY"

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
	_check(int(_profile.get("deck_id", 0)) == DECK_ID, "production Academy Gardevoir profile must load")
	_check(int(_manifest.get("deck_id", 0)) == DECK_ID, "Academy Gardevoir semantic manifest must load")
	_check(_profile.get("modules", []) == ["gardevoir_embrace", "damage_counter_control"], \
		"scenarios must use the production Embrace/counter-control module composition")
	_check(int(deck.id) == DECK_ID and int(deck.total_cards) == 60, \
		"current bundled AI seed must be the exact 60-card Academy Gardevoir deck")
	_check(_current_fingerprint != "" \
		and _current_fingerprint == str(_manifest.get("deck_content_fingerprint", "")), \
		"semantic manifest fingerprint must match the current bundled AI deck")

	_scenario_a_charm_before_embrace_reaches_exact_scream_tail_budget()
	_scenario_b_tm_evolution_builds_two_kirlia_lanes()
	_scenario_c_shaymin_protects_only_non_rule_box_embrace_target()
	_scenario_d_vessel_before_research_banks_embrace_fuel()
	_scenario_e_counter_catcher_then_drifloon_closes_two_prizes()
	_write_report()

	EffectProcessor.cleanup_live_instances_for_tests()
	if _failures.is_empty() and _rows.size() == 5:
		print("optimization21 800018498 complex decision scenarios: PASS (5/5)")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("optimization21 800018498 complex decision scenarios: FAIL (%d)" % _failures.size())
	quit(1)


func _scenario_a_charm_before_embrace_reaches_exact_scream_tail_budget() -> void:
	var gsm := GameStateMachine.new()
	gsm.game_state = _game_state(8)
	var state := gsm.game_state
	var scream_tail := _real_slot(_real_card_data(SCREAM_TAIL_UID), 0)
	var gardevoir := _real_slot(_real_card_data(GARDEVOIR_UID), 0)
	scream_tail.damage_counters = 80
	scream_tail.attached_energy = [_real_instance(PSYCHIC_UID, 0)]
	var psychic_a := _real_instance(PSYCHIC_UID, 0)
	var psychic_b := _real_instance(PSYCHIC_UID, 0)
	var charm := _real_instance(BRAVERY_CHARM_UID, 0)
	var target := _target("Public exact 240 HP ex", 240, 2)
	state.players[0].active_pokemon = scream_tail
	state.players[0].bench = [gardevoir]
	state.players[0].discard_pile = [psychic_a, psychic_b]
	state.players[0].hand = [charm]
	state.players[1].active_pokemon = target
	gsm.effect_processor.register_pokemon_card(scream_tail.get_card_data())
	gsm.effect_processor.register_pokemon_card(gardevoir.get_card_data())
	var embrace := gsm.effect_processor.get_ability_effect(gardevoir, 0, state)
	var blocked_without_charm := embrace != null \
		and not bool(embrace.call("can_use_embrace_on_target", scream_tail, state))
	var charm_attached := gsm.attach_tool(0, charm, scream_tail)
	var expanded_hp_exact := gsm.effect_processor.get_effective_max_hp(scream_tail, state) == 140 \
		and gsm.effect_processor.get_effective_remaining_hp(scream_tail, state) == 60
	var target_step := _step(
		embrace.get_interaction_steps(gardevoir.get_top_card(), state) if embrace != null else [],
		"embrace_target"
	)
	var target_now_legal := scream_tail in (target_step.get("items", []) as Array)
	var first_attached := gsm.effect_processor.execute_ability_effect(gardevoir, 0, [{
		"embrace_energy": [psychic_a], "embrace_target": [scream_tail],
	}], state)
	var second_attached := gsm.effect_processor.execute_ability_effect(gardevoir, 0, [{
		"embrace_energy": [psychic_b], "embrace_target": [scream_tail],
	}], state)
	var exact_budget_stop := scream_tail.damage_counters == 120 \
		and scream_tail.attached_energy.size() == 3 \
		and gsm.effect_processor.get_effective_remaining_hp(scream_tail, state) == 20 \
		and not bool(embrace.call("can_use_embrace_on_target", scream_tail, state))
	var attack_legal := gsm.rule_validator.can_use_attack(state, 0, 1, gsm.effect_processor)
	var roar: BaseEffect = null
	for effect: BaseEffect in gsm.effect_processor.get_attack_effects_for_slot(scream_tail, 1):
		if effect is AttackSelfDamageCounterTargetDamage:
			roar = effect
			break
	var preview_damage := int(roar.call("get_attack_preview_damage", scream_tail, target, state)) \
		if roar != null else 0
	if roar != null:
		roar.set_attack_interaction_context([{"target_pokemon": [target]}])
		roar.call("execute_attack", scream_tail, target, 1, state)
	var profile_budget: Dictionary = _profile.get("module_parameters", {}).get("gardevoir_embrace", {}) \
		.get("damage_scalers_by_uid", {}).get(SCREAM_TAIL_UID, {})
	var passed := blocked_without_charm and charm_attached and expanded_hp_exact \
		and target_now_legal and first_attached and second_attached and exact_budget_stop \
		and attack_legal and preview_damage == 240 and target.damage_counters == 240 \
		and target.is_knocked_out() and preview_damage < 241 \
		and int(profile_budget.get("damage_per_counter", 0)) == 20 \
		and int(profile_budget.get("embrace_damage_per_assignment", 0)) == 20
	_check(passed, "scenario A must Charm before exactly two Embraces for Scream Tail's public 240 breakpoint")
	_rows.append(_row(
		"charm_before_embrace_reaches_exact_scream_tail_budget",
		"超能填能与伤害预算",
		"吼叫尾已受80伤时无护符不能继续精神拥抱；先贴勇气护符，再精确拥抱2次，停在120伤/20HP并以凶暴吼叫造成240。",
		"Bravery Charm -> Psychic Embrace x2 -> Roaring Scream 240",
		["无护符时剩10HP不得拥抱", "120伤后不得进行第三次拥抱", "240不能击倒241HP"],
		passed
	))


func _scenario_b_tm_evolution_builds_two_kirlia_lanes() -> void:
	var state := _game_state(4)
	var active_ralts := _real_slot(_real_card_data(RALTS_UID), 0)
	var first_ralts := _real_slot(_real_card_data(RALTS_UID), 0)
	var second_ralts := _real_slot(_real_card_data(RALTS_UID), 0)
	var support := _real_slot(_real_card_data(MUNKIDORI_UID), 0)
	var first_kirlia := _real_instance(KIRLIA_UID, 0)
	var second_kirlia := _real_instance(KIRLIA_UID, 0)
	var unrelated := _unrelated_stage_one(0)
	state.players[0].active_pokemon = active_ralts
	state.players[0].bench = [first_ralts, support, second_ralts]
	state.players[0].deck = [first_kirlia, unrelated, second_kirlia]
	state.players[1].active_pokemon = _target("Public TM target", 200, 1)
	var effect := AttackTMEvolution.new(2)
	var initial_steps := effect.get_granted_attack_interaction_steps(
		active_ralts, {"id": AttackTMEvolution.GRANTED_ATTACK_ID}, state)
	var bench_step := _step(initial_steps, "evolution_bench")
	var bench_items: Array = bench_step.get("items", [])
	var bench_exact := first_ralts in bench_items and second_ralts in bench_items \
		and support not in bench_items and active_ralts not in bench_items \
		and int(bench_step.get("max_select", 0)) == 2
	var followup := effect.get_followup_granted_attack_interaction_steps(
		active_ralts,
		{"id": AttackTMEvolution.GRANTED_ATTACK_ID},
		state,
		{"evolution_bench": [first_ralts, second_ralts]}
	)
	var card_step := _step(followup, "evolution_cards")
	var card_items: Array = card_step.get("items", [])
	var cards_exact := first_kirlia in card_items and second_kirlia in card_items \
		and unrelated not in card_items \
		and str(card_step.get("visible_scope", "")) == BaseEffect.VISIBLE_SCOPE_OWN_FULL_DECK
	effect.execute_granted_attack(active_ralts, {"id": AttackTMEvolution.GRANTED_ATTACK_ID}, state, [{
		"evolution_bench": [first_ralts, second_ralts],
		"evolution_cards": [first_kirlia, second_kirlia],
	}])
	var evolved_exact := first_ralts.get_card_data().get_uid() == KIRLIA_UID \
		and second_ralts.get_card_data().get_uid() == KIRLIA_UID \
		and first_ralts.pokemon_stack.size() == 2 and second_ralts.pokemon_stack.size() == 2 \
		and active_ralts.get_card_data().get_uid() == RALTS_UID \
		and unrelated in state.players[0].deck
	var route_biases: Dictionary = _profile.get("route_preferences", {}).get("route_biases", {})
	var evolution_preferred := float(route_biases.get("route:evolve", 0.0)) \
		> float(route_biases.get("route:develop", 0.0))
	var passed := bench_exact and cards_exact and evolved_exact and evolution_preferred
	_check(passed, "scenario B must preserve both same-identity Ralts/Kirlia TM Evolution lanes")
	_rows.append(_row(
		"tm_evolution_builds_two_kirlia_lanes",
		"进化链",
		"招式学习器：进化在合法完整牌库视野中保留两只不同备战拉鲁拉丝和两张奇鲁莉安实例，一次建立双引擎线。",
		"TM Evolution: two Benched Ralts -> two distinct Kirlia instances",
		["出战拉鲁拉丝不能成为目标", "愿增猿与无关Stage 1不能进入选择", "相同身份实例不得去重为一条线"],
		passed
	))


func _scenario_c_shaymin_protects_only_non_rule_box_embrace_target() -> void:
	var processor := EffectProcessor.new()
	var state := _game_state(9)
	var gardevoir := _real_slot(_real_card_data(GARDEVOIR_UID), 0)
	var shaymin := _real_slot(_real_card_data(SHAYMIN_UID), 0)
	var scream_tail := _real_slot(_real_card_data(SCREAM_TAIL_UID), 0)
	var clefairy_ex := _real_slot(_real_card_data(CLEFAIRY_EX_UID), 0)
	var psychic := _real_instance(PSYCHIC_UID, 0)
	var attacker := _fixture_attacker("Public opponent Bench sniper", 1)
	state.players[0].active_pokemon = gardevoir
	state.players[0].bench = [shaymin, scream_tail, clefairy_ex]
	state.players[0].discard_pile = [psychic]
	state.players[1].active_pokemon = attacker
	processor.register_pokemon_card(gardevoir.get_card_data())
	processor.register_pokemon_card(shaymin.get_card_data())
	var flower_curtain := processor.get_effect(shaymin.get_card_data().effect_id)
	var embrace := processor.get_ability_effect(gardevoir, 0, state)
	var target_step := _step(
		embrace.get_interaction_steps(gardevoir.get_top_card(), state) if embrace != null else [],
		"embrace_target"
	)
	var typed_targeting := scream_tail in (target_step.get("items", []) as Array) \
		and shaymin not in (target_step.get("items", []) as Array)
	var embraced := processor.execute_ability_effect(gardevoir, 0, [{
		"embrace_energy": [psychic], "embrace_target": [scream_tail],
	}], state)
	state.current_player_index = 1
	var protected_damage := AttackAnyTargetDamage.new(40)
	protected_damage.set_attack_interaction_context([{"any_target": [scream_tail]}])
	protected_damage.execute_attack(attacker, gardevoir, 0, state)
	var rule_box_damage := AttackAnyTargetDamage.new(40)
	rule_box_damage.set_attack_interaction_context([{"any_target": [clefairy_ex]}])
	rule_box_damage.execute_attack(attacker, gardevoir, 0, state)
	var shield_exact := flower_curtain is AbilityNonRuleBoxBenchDamageShield \
		and AbilityNonRuleBoxBenchDamageShield.protects_bench_target(scream_tail, attacker, state) \
		and not AbilityNonRuleBoxBenchDamageShield.protects_bench_target(clefairy_ex, attacker, state) \
		and embraced and scream_tail.damage_counters == 20 \
		and psychic in scream_tail.attached_energy and clefairy_ex.damage_counters == 40

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
	var passed := typed_targeting and shield_exact and unshielded_target.damage_counters == 40
	_check(passed, "scenario C must apply real Flower Curtain only to the non-Rule-Box Embrace target")
	_rows.append(_row(
		"shaymin_protects_only_non_rule_box_embrace_target",
		"特性协同与备战保护",
		"沙奈朵ex以精神拥抱给备战吼叫尾贴超能并放20伤；谢米花之纱幔挡住随后40点备战伤害，但不保护拥有规则框的莉莉艾的皮皮ex。",
		"Psychic Embrace Scream Tail -> Flower Curtain blocks non-Rule-Box Bench damage",
		["谢米不是超属性，不能成为精神拥抱目标", "花之纱幔不保护规则宝可梦", "移除谢米后同一40伤必须生效"],
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
	var reversed_loses_vessel_and_two_fuel := _psychic_discard_count(wrong_gsm.game_state.players[0]) == 1 \
		and wrong_vessel not in wrong_gsm.game_state.players[0].hand \
		and wrong_vessel in wrong_gsm.game_state.players[0].discard_pile
	var route_biases: Dictionary = _profile.get("route_preferences", {}).get("route_biases", {})
	var checkpoint_contract := float(route_biases.get("route:information", 0.0)) \
		> float(route_biases.get("route:develop", 0.0)) \
		and bool(_profile.get("safety", {}).get("reject_information_churn_after_ko_secured", false))
	var passed := vessel_played and research_played and three_fuel_banked \
		and embrace != null and embraced and two_fuel_remain \
		and wrong_research_played and reversed_loses_vessel_and_two_fuel \
		and checkpoint_contract
	_check(passed, "scenario D must use Earthen Vessel before Research to bank three public Embrace fuels")
	_rows.append(_row(
		"vessel_before_research_banks_embrace_fuel",
		"抽牌与支援者顺序",
		"先用大地容器丢1张并检索2张超能，再用博士的研究把检索能量送入弃牌并抽7，形成3张精神拥抱燃料；反序只留下1张。",
		"Earthen Vessel -> Professor's Research -> Psychic Embrace",
		["博士先用会连同大地容器一起弃掉", "容器检索后形成新的公开手牌检查点", "已锁定KO后不得继续无意义抽牌"],
		passed
	))


func _scenario_e_counter_catcher_then_drifloon_closes_two_prizes() -> void:
	var gsm := GameStateMachine.new()
	gsm.game_state = _game_state(12)
	var state := gsm.game_state
	var drifloon := _real_slot(_real_card_data(DRIFLOON_UID), 0)
	drifloon.damage_counters = 100
	drifloon.attached_tool = _real_instance(BRAVERY_CHARM_UID, 0)
	for _index: int in 5:
		drifloon.attached_energy.append(_real_instance(PSYCHIC_UID, 0))
	var exposed_single := _target("Public exposed single-Prize Active", 70, 1)
	var bench_ex := _target("Public exact 300 HP Bench ex", 300, 2)
	var counter_catcher := _real_instance(COUNTER_CATCHER_UID, 0)
	state.players[0].active_pokemon = drifloon
	state.players[0].hand = [counter_catcher]
	state.players[1].active_pokemon = exposed_single
	state.players[1].bench = [bench_ex]
	_fill_prizes(state.players[0], 2, "OWN_FINAL_TWO")
	_fill_prizes(state.players[1], 1, "OPPONENT_AHEAD")
	gsm.effect_processor.register_pokemon_card(drifloon.get_card_data())
	var counter_effect: BaseEffect = gsm.effect_processor.get_effect(counter_catcher.card_data.effect_id)
	var behind_gate_open := counter_effect != null \
		and bool(counter_effect.call("can_execute", counter_catcher, state))
	var steps: Array = counter_effect.get_interaction_steps(counter_catcher, state) \
		if counter_effect != null else []
	var target_step := _step(steps, "opponent_bench_target")
	var exact_target_visible := (target_step.get("items", []) as Array) == [bench_ex]
	var catcher_played := gsm.play_trainer(0, counter_catcher, [{
		"opponent_bench_target": [bench_ex],
	}])
	var gust_resolved := state.players[1].active_pokemon == bench_ex \
		and exposed_single in state.players[1].bench \
		and counter_catcher in state.players[0].discard_pile
	var attack_legal := gsm.rule_validator.can_use_attack(state, 0, 1, gsm.effect_processor)
	var attack_damage := DamageCalculator.new().calculate_damage(
		drifloon,
		bench_ex,
		drifloon.get_card_data().attacks[1],
		state,
		_attack_bonus(gsm.effect_processor, drifloon, 1, state)
	)
	DamageCalculator.new().apply_damage_to_slot(bench_ex, attack_damage)
	var closes_game := attack_damage == 300 and bench_ex.is_knocked_out() \
		and bench_ex.get_prize_count() == 2 \
		and bench_ex.get_prize_count() >= state.players[0].prizes.size()

	var tied_state := _game_state(12)
	var tied_counter := _real_instance(COUNTER_CATCHER_UID, 0)
	tied_state.players[0].active_pokemon = _real_slot(_real_card_data(DRIFLOON_UID), 0)
	tied_state.players[1].active_pokemon = _target("Public tied Active", 100, 1)
	tied_state.players[1].bench = [_target("Public tied Bench", 100, 2)]
	_fill_prizes(tied_state.players[0], 1, "OWN_TIED")
	_fill_prizes(tied_state.players[1], 1, "OPPONENT_TIED")
	var tied_blocked := counter_effect != null \
		and not bool(counter_effect.call("can_execute", tied_counter, tied_state))
	var terminal_contract := float(_profile.get("route_preferences", {}).get("route_biases", {}) \
		.get("route:attack_ko", 0.0)) \
		> float(_profile.get("route_preferences", {}).get("route_biases", {}) \
		.get("route:information", 0.0)) \
		and bool(_profile.get("safety", {}).get("stop_optional_draw_when_attack_ready", false))
	var passed := behind_gate_open and exact_target_visible and catcher_played and gust_resolved \
		and attack_legal and closes_game and attack_damage < 301 and tied_blocked \
		and terminal_contract
	_check(passed, "scenario E must use the legal Counter Catcher window before the exact final-two-Prize attack")
	_rows.append(_row(
		"counter_catcher_then_drifloon_closes_two_prizes",
		"关键奖闭环",
		"己方剩2奖且奖赏落后时，反击捕捉器先拉出备战300HP双奖目标，再由100伤飘飘球打出气球炸弹300完成终局。",
		"Counter Catcher exact Bench ex -> Balloon Bomb 300 -> final two Prizes",
		["奖赏持平时反击捕捉器不可用", "300不能击倒301HP", "直接攻击前台单奖不能完成剩余2奖"],
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
	var report := {
		"schema_version": 1,
		"architecture": "V18CPG",
		"semantic_schema": "v18cpg-2",
		"transport_contract_version": 3,
		"deck_id": DECK_ID,
		"deck_name": "18.0 学院沙奈朵",
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
			"excluded_historical_archive": "res://tmp/v18cpg/optimization21_invalidated_user_deck_20260720/800018498",
			"interpretation": "The archived rounds are explicitly invalidated and do not bind the current bundled_ai fingerprint. These five fixtures are scenario evidence only, not a paired-strength or promotion claim.",
		},
		"scope": "focused scenario coverage only; no real-model formal benchmark",
		"scenario_count": _rows.size(),
		"passed_count": _rows.filter(func(row: Dictionary) -> bool: return bool(row.get("passed", false))).size(),
		"all_passed": _failures.is_empty() and _rows.size() == 5,
		"production_status": "scenario_contract_ready_strength_unverified",
		"known_production_gaps": [
			"These fixtures do not create a strength round or alter any optimization ledger.",
			"No current-fingerprint paired ledger is available for this deck, so no superiority or promotion claim is made.",
			"Fresh bundled_ai fingerprint-aligned paired evidence remains required before promotion.",
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
			"Bravery Charm before exact Psychic Embrace assignments for Scream Tail's bounded 240 breakpoint",
			"one TM Evolution preserving two Ralts roots and two distinct Kirlia instances through an authorized full-deck view",
			"real Psychic Embrace target typing plus Shaymin Flower Curtain's non-Rule-Box Bench boundary",
			"Earthen Vessel before Professor's Research banking three Psychic fuels across an information checkpoint",
			"legal behind-on-Prizes Counter Catcher into an exact Drifloon two-Prize closeout",
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
