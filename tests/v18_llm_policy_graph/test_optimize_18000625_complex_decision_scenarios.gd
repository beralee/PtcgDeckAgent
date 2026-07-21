extends SceneTree

const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const SemanticCompilerScript = preload("res://scripts/ai/v18_cpg/semantics/V18CPGDeckSemanticCompiler.gd")

const DECK_ID := 18000625
const DECK_SEED_PATH := "res://data/bundled_user/decks/18000625.json"
const MANIFEST_PATH := "res://scripts/ai/v18_cpg/profiles/generated_semantic_manifests/18000625.json"
const ROUND00_PATH := "res://tmp/v18cpg/optimization21/18000625/round00.json"
const REPORT_PATH := "res://tmp/v18cpg/optimization21/18000625/complex_decision_scenarios.json"

const TORCHIC_UID := "CSV10C_036"
const COMBUSKEN_UID := "CSV10C_037"
const BLAZIKEN_EX_UID := "CSV7C_038"
const BLAZIKEN_UID := "CSV10C_038"
const PECHARUNT_UID := "CSV9C_127"
const MUNKIDORI_UID := "CSV8C_094"
const FEZANDIPITI_UID := "CSV8C_135"
const IONO_UID := "CSV3C_123"
const RARE_CANDY_UID := "CSVH1C_045"
const FIRE_UID := "CSVE1C_FIR"
const DARKNESS_UID := "CSVE1C_DAR"
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
	_check(int(_profile.get("deck_id", 0)) == DECK_ID, "production Munkidori/Blaziken profile must load")
	_check(int(_manifest.get("deck_id", 0)) == DECK_ID, "Munkidori/Blaziken semantic manifest must load")
	_check(_profile.get("modules", []) == ["damage_counter_control", "stage2_chain", "energy_burst"], \
		"scenarios must use the production counter-control/stage2/energy module composition")
	_check(int(deck.id) == DECK_ID and int(deck.total_cards) == 60, \
		"current bundled AI seed must be the exact 60-card deck")
	_check(_current_fingerprint != "" \
		and _current_fingerprint == str(_manifest.get("deck_content_fingerprint", "")), \
		"semantic manifest fingerprint must match the current bundled AI deck")

	_scenario_a_split_fire_and_dark_to_online_both_engines()
	_scenario_b_rare_candy_only_the_old_torchic()
	_scenario_c_adrena_brain_moves_exact_lethal_counters()
	_scenario_d_iono_before_fezandipiti_preserves_both_draws()
	_scenario_e_single_prize_blaziken_takes_two_prizes()
	_write_report()

	EffectProcessor.cleanup_live_instances_for_tests()
	if _failures.is_empty() and _rows.size() == 5:
		print("optimization21 18000625 complex decision scenarios: PASS (5/5)")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("optimization21 18000625 complex decision scenarios: FAIL (%d)" % _failures.size())
	quit(1)


func _scenario_a_split_fire_and_dark_to_online_both_engines() -> void:
	var gsm := GameStateMachine.new()
	gsm.game_state = _game_state(7)
	var state := gsm.game_state
	var blaziken := _real_slot(_real_card_data(BLAZIKEN_EX_UID), 0)
	var munkidori := _real_slot(_real_card_data(MUNKIDORI_UID), 0)
	var wounded := _real_slot(_real_card_data(PECHARUNT_UID), 0)
	wounded.damage_counters = 30
	blaziken.attached_energy = [_real_instance(PSYCHIC_UID, 0)]
	state.players[0].active_pokemon = blaziken
	state.players[0].bench = [munkidori, wounded]
	state.players[1].active_pokemon = _target("Public 200 HP target", 200, 2)
	var discard_dark := _real_instance(DARKNESS_UID, 0)
	var discard_fire := _real_instance(FIRE_UID, 0)
	var hand_fire := _real_instance(FIRE_UID, 0)
	state.players[0].discard_pile = [discard_dark, discard_fire]
	state.players[0].hand = [hand_fire]
	gsm.effect_processor.register_pokemon_card(blaziken.get_card_data())
	gsm.effect_processor.register_pokemon_card(munkidori.get_card_data())

	var ability := gsm.effect_processor.get_ability_effect(blaziken, 0, state)
	var steps: Array = ability.get_interaction_steps(blaziken.get_top_card(), state) if ability != null else []
	var assignment_step := _step(steps, "attach_basic_energy_from_discard")
	var sources: Array = assignment_step.get("source_items", assignment_step.get("items", []))
	var targets: Array = assignment_step.get("target_items", [])
	var public_assignment_exact := discard_dark in sources and discard_fire in sources \
		and munkidori in targets and blaziken in targets
	var accelerated := gsm.effect_processor.execute_ability_effect(blaziken, 0, [{
		"attach_basic_energy_from_discard": [{"source": discard_dark, "target": munkidori}],
	}], state)
	var manually_attached := gsm.attach_energy(0, hand_fire, blaziken)
	var attack_online := gsm.rule_validator.can_use_attack(state, 0, 0, gsm.effect_processor)
	var counter_online := gsm.effect_processor.can_use_ability(munkidori, state, 0)
	var once_guard := not gsm.effect_processor.can_use_ability(blaziken, state, 0)

	var wrong_gsm := GameStateMachine.new()
	wrong_gsm.game_state = _game_state(7)
	var wrong_state := wrong_gsm.game_state
	var wrong_blaziken := _real_slot(_real_card_data(BLAZIKEN_EX_UID), 0)
	var wrong_munkidori := _real_slot(_real_card_data(MUNKIDORI_UID), 0)
	var wrong_wounded := _real_slot(_real_card_data(PECHARUNT_UID), 0)
	wrong_wounded.damage_counters = 30
	wrong_blaziken.attached_energy = [_real_instance(PSYCHIC_UID, 0)]
	wrong_state.players[0].active_pokemon = wrong_blaziken
	wrong_state.players[0].bench = [wrong_munkidori, wrong_wounded]
	wrong_state.players[1].active_pokemon = _target("Public wrong-energy target", 200, 2)
	var wrong_dark := _real_instance(DARKNESS_UID, 0)
	var wrong_fire := _real_instance(FIRE_UID, 0)
	wrong_state.players[0].discard_pile = [wrong_dark, wrong_fire]
	wrong_state.players[0].hand = [wrong_dark]
	wrong_gsm.effect_processor.register_pokemon_card(wrong_blaziken.get_card_data())
	wrong_gsm.effect_processor.register_pokemon_card(wrong_munkidori.get_card_data())
	var wrong_acceleration := wrong_gsm.effect_processor.execute_ability_effect(wrong_blaziken, 0, [{
		"attach_basic_energy_from_discard": [{"source": wrong_fire, "target": wrong_munkidori}],
	}], wrong_state)
	var wrong_manual := wrong_gsm.attach_energy(0, wrong_dark, wrong_blaziken)
	var wrong_attack_blocked := not wrong_gsm.rule_validator.can_use_attack(
		wrong_state, 0, 0, wrong_gsm.effect_processor)
	var wrong_counter_blocked := not wrong_gsm.effect_processor.can_use_ability(
		wrong_munkidori, wrong_state, 0)

	var route_biases: Dictionary = _profile.get("route_preferences", {}).get("route_biases", {})
	var route_contract := float(route_biases.get("route:energy_commit", 0.0)) > 0.0 \
		and float(route_biases.get("route:accelerate", 0.0)) > 0.0 \
		and float(route_biases.get("route:end_turn", 0.0)) < 0.0
	var passed := public_assignment_exact and accelerated and manually_attached and attack_online \
		and counter_online and once_guard and wrong_acceleration and wrong_manual \
		and wrong_attack_blocked and wrong_counter_blocked and route_contract
	_check(passed, "scenario A must split visible Fire/Dark resources so Blaziken and Munkidori are both online")
	_rows.append(_row(
		"split_fire_and_dark_to_online_both_engines",
		"填能与能量分工",
		"沸腾斗志把弃牌区恶能量贴给愿增猿，手贴火能量给已有无色费用的火焰鸡ex，同回合同时接通攻击与亢奋脑力。",
		"Boiling Spirit(Darkness -> Munkidori) -> manual Fire -> Burning Spin ready",
		["沸腾斗志每回合只能用一次", "火能量贴愿增猿且恶能量贴火焰鸡会让两个引擎同时断线", "燃烧旋踢必须满足火+无色费用"],
		passed
	))


func _scenario_b_rare_candy_only_the_old_torchic() -> void:
	var processor := EffectProcessor.new()
	var state := _game_state(6)
	var old_torchic := _real_slot(_real_card_data(TORCHIC_UID), 0)
	var fresh_torchic := _real_slot(_real_card_data(TORCHIC_UID), 0)
	old_torchic.turn_played = 2
	fresh_torchic.turn_played = state.turn_number
	state.players[0].active_pokemon = old_torchic
	state.players[0].bench = [fresh_torchic]
	state.players[1].active_pokemon = _target("Public evolution target", 220, 2)
	var candy := _real_instance(RARE_CANDY_UID, 0)
	var combusken := _real_instance(COMBUSKEN_UID, 0)
	var blaziken := _real_instance(BLAZIKEN_EX_UID, 0)
	state.players[0].hand = [candy, combusken, blaziken]
	var validator := RuleValidator.new()
	var stage1_legal := validator.can_evolve(state, 0, old_torchic, combusken, processor)
	var direct_stage2_blocked := not validator.can_evolve(state, 0, old_torchic, blaziken, processor)
	var candy_effect := processor.get_effect(candy.card_data.effect_id)
	var steps: Array = candy_effect.get_interaction_steps(candy, state) if candy_effect != null else []
	var stage2_step := _step(steps, "stage2_card")
	var target_step := _step(steps, "target_pokemon")
	var interaction_exact := blaziken in (stage2_step.get("items", []) as Array) \
		and combusken not in (stage2_step.get("items", []) as Array) \
		and old_torchic in (target_step.get("items", []) as Array) \
		and fresh_torchic not in (target_step.get("items", []) as Array)
	var wrong_fresh_rejected := not processor.execute_card_effect(candy, [{
		"stage2_card": [blaziken], "target_pokemon": [fresh_torchic],
	}], state) or fresh_torchic.get_card_data().get_uid() == TORCHIC_UID
	var evolved := processor.execute_card_effect(candy, [{
		"stage2_card": [blaziken], "target_pokemon": [old_torchic],
	}], state)
	var old_chain_exact := old_torchic.get_card_data().get_uid() == BLAZIKEN_EX_UID \
		and old_torchic.pokemon_stack.size() == 2 \
		and fresh_torchic.get_card_data().get_uid() == TORCHIC_UID

	var first_turn_state := _game_state(1)
	var first_turn_torchic := _real_slot(_real_card_data(TORCHIC_UID), 0)
	first_turn_torchic.turn_played = 0
	var first_turn_candy := _real_instance(RARE_CANDY_UID, 0)
	first_turn_state.players[0].active_pokemon = first_turn_torchic
	first_turn_state.players[0].hand = [first_turn_candy, _real_instance(BLAZIKEN_EX_UID, 0)]
	first_turn_state.players[1].active_pokemon = _target("Public first-turn target", 100, 1)
	var first_turn_blocked := candy_effect != null and not candy_effect.can_execute(first_turn_candy, first_turn_state)
	var route_biases: Dictionary = _profile.get("route_preferences", {}).get("route_biases", {})
	var evolve_contract := float(route_biases.get("route:evolve", 0.0)) \
		> float(route_biases.get("route:develop", 0.0))

	var passed := stage1_legal and direct_stage2_blocked and interaction_exact \
		and wrong_fresh_rejected and evolved and old_chain_exact and first_turn_blocked and evolve_contract
	_check(passed, "scenario B must Rare Candy only the old Torchic and reject fresh/direct Stage-2 shortcuts")
	_rows.append(_row(
		"rare_candy_only_the_old_torchic",
		"进化路线",
		"同场旧火稚鸡与本回合新下火稚鸡时，神奇糖果只把旧根跳阶成火焰鸡ex；普通进化仍只能先到力壮鸡。",
		"Rare Candy(Blaziken ex -> old Torchic)",
		["普通进化不能从火稚鸡直上Stage 2", "本回合刚下场的火稚鸡不能糖果进化", "己方首回合不能使用神奇糖果"],
		passed
	))


func _scenario_c_adrena_brain_moves_exact_lethal_counters() -> void:
	var processor := EffectProcessor.new()
	var state := _game_state(8)
	var wounded := _real_slot(_real_card_data(PECHARUNT_UID), 0)
	wounded.damage_counters = 40
	var munkidori := _real_slot(_real_card_data(MUNKIDORI_UID), 0)
	munkidori.attached_energy = [_real_instance(DARKNESS_UID, 0)]
	var exact_target := _target("Public exact 30 HP target", 30, 1)
	state.players[0].active_pokemon = wounded
	state.players[0].bench = [munkidori]
	state.players[1].active_pokemon = exact_target
	processor.register_pokemon_card(munkidori.get_card_data())
	var effect := processor.get_ability_effect(munkidori, 0, state)
	var first_steps: Array = effect.get_interaction_steps(munkidori.get_top_card(), state) if effect != null else []
	var source_step := _step(first_steps, "source_pokemon")
	var followup: Array = effect.get_followup_interaction_steps(
		munkidori.get_top_card(), state, {"source_pokemon": [wounded]}
	) if effect != null else []
	var counter_step := _step(followup, "target_damage_counters")
	var interaction_exact := wounded in (source_step.get("items", []) as Array) \
		and int(counter_step.get("total_counters", 0)) == 3 \
		and exact_target in (counter_step.get("target_items", []) as Array)
	var over_cap_rejected := not processor.execute_ability_effect(munkidori, 0, [{
		"source_pokemon": [wounded],
		"target_damage_counters": [{"target": exact_target, "amount": 40}],
	}], state)
	var unchanged_after_rejection := wounded.damage_counters == 40 and exact_target.damage_counters == 0
	var moved := processor.execute_ability_effect(munkidori, 0, [{
		"source_pokemon": [wounded],
		"target_damage_counters": [{"target": exact_target, "amount": 30}],
	}], state)
	var exact_lethal := wounded.damage_counters == 10 and exact_target.damage_counters == 30 \
		and exact_target.is_knocked_out()
	var once_guard := not processor.can_use_ability(munkidori, state, 0)

	var no_dark_processor := EffectProcessor.new()
	var no_dark_state := _game_state(8)
	var no_dark_source := _real_slot(_real_card_data(PECHARUNT_UID), 0)
	no_dark_source.damage_counters = 30
	var no_dark_munkidori := _real_slot(_real_card_data(MUNKIDORI_UID), 0)
	no_dark_state.players[0].active_pokemon = no_dark_source
	no_dark_state.players[0].bench = [no_dark_munkidori]
	no_dark_state.players[1].active_pokemon = _target("Public no-dark target", 100, 1)
	no_dark_processor.register_pokemon_card(no_dark_munkidori.get_card_data())
	var no_dark_blocked := not no_dark_processor.can_use_ability(no_dark_munkidori, no_dark_state, 0)
	var required_by_profile: Array = _profile.get("module_parameters", {}) \
		.get("damage_counter_control", {}).get("counter_mover_required_energy_by_uid", {}) \
		.get(MUNKIDORI_UID, [])
	var profile_requires_dark := required_by_profile == ["D"]

	var passed := interaction_exact and over_cap_rejected and unchanged_after_rejection \
		and moved and exact_lethal and once_guard and no_dark_blocked and profile_requires_dark
	_check(passed, "scenario C must move exactly three lethal counters with strict Darkness/cap/once guards")
	_rows.append(_row(
		"adrena_brain_moves_exact_lethal_counters",
		"愿增猿特性",
		"有恶能量的愿增猿从受伤桃歹郎搬3个指示物到公开30HP目标，刚好拿奖并保留自身10伤害。",
		"Adrena Brain: move exactly 3 counters to the 30 HP target",
		["没有恶能量不能使用亢奋脑力", "一次最多搬3个伤害指示物", "同一愿增猿每回合只能使用一次"],
		passed
	))


func _scenario_d_iono_before_fezandipiti_preserves_both_draws() -> void:
	var correct := _draw_order_state()
	var correct_processor: EffectProcessor = correct.get("processor")
	var correct_state: GameState = correct.get("state")
	var correct_fez: PokemonSlot = correct.get("fez")
	var correct_iono: CardInstance = correct.get("iono")
	correct_state.players[0].hand.erase(correct_iono)
	var iono_executed := correct_processor.execute_card_effect(correct_iono, [], correct_state)
	correct_state.players[0].discard_pile.append(correct_iono)
	var fez_executed := correct_processor.execute_ability_effect(correct_fez, 0, [], correct_state)
	var correct_names := _instance_names(correct_state.players[0].hand)
	var correct_kept_five := correct_names == [
		"VISIBLE_DRAW_A", "VISIBLE_DRAW_B", "VISIBLE_DRAW_C", "VISIBLE_DRAW_D", "VISIBLE_DRAW_E",
	]
	var shared_once := not correct_processor.can_use_ability(correct_fez, correct_state, 0)

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
		and "VISIBLE_DRAW_A" not in wrong_names and "VISIBLE_DRAW_B" not in wrong_names \
		and "VISIBLE_DRAW_C" not in wrong_names
	var information_not_preferred_after_ko := float(_profile.get("route_preferences", {}) \
		.get("route_biases", {}).get("route:information", 0.0)) \
		< float(_profile.get("route_preferences", {}).get("route_biases", {}).get("route:attack_ko", 0.0))

	var passed := iono_executed and fez_executed and correct_kept_five and shared_once \
		and wrong_fez_executed and wrong_iono_executed and premature_draw_lost \
		and information_not_preferred_after_ko
	_check(passed, "scenario D must resolve Iono before Flip the Script so all five visible draws survive")
	_rows.append(_row(
		"iono_before_fezandipiti_preserves_both_draws",
		"抽牌与支援者顺序",
		"上回合己方被击倒且己方剩2奖时，先用奇树抽2，再用吉雉鸡ex抽3，保留连续5张公开抽牌；反序会丢掉前3张。",
		"Iono draw 2 -> information checkpoint -> Flip the Script draw 3",
		["化危为吉要求上个对手回合发生己方昏厥", "同回合共享的化危为吉只能用一次", "先特性后奇树会失去前3张确定抽牌"],
		passed
	))


func _scenario_e_single_prize_blaziken_takes_two_prizes() -> void:
	var processor := EffectProcessor.new()
	var state := _game_state(10)
	var blaziken := _real_slot(_real_card_data(BLAZIKEN_UID), 0)
	var fire_a := _real_instance(FIRE_UID, 0)
	var fire_b := _real_instance(FIRE_UID, 0)
	var psychic := _real_instance(PSYCHIC_UID, 0)
	blaziken.attached_energy = [fire_a, fire_b, psychic]
	var active_target := _target("Public exact 120 HP Active", 120, 1)
	var bench_target := _target("Public exact 120 HP Bench", 120, 1)
	var tank_target := _target("Public 121 HP Bench", 121, 1)
	state.players[0].active_pokemon = blaziken
	state.players[1].active_pokemon = active_target
	state.players[1].bench = [bench_target, tank_target]
	_fill_prizes(state.players[0], 2, "OWN_FINAL_PRIZE")
	processor.register_pokemon_card(blaziken.get_card_data())
	var attack_legal := RuleValidator.new().can_use_attack(state, 0, 1, processor)
	var effects := processor.get_attack_effects_for_slot(blaziken, 1)
	var steps: Array = effects[0].get_attack_interaction_steps(
		blaziken.get_top_card(), blaziken.get_card_data().attacks[1], state
	) if not effects.is_empty() else []
	var energy_step := _step(steps, "discard_two_energy_for_bench_damage")
	var target_step := _step(steps, "bench_damage_target")
	var interaction_exact := int(energy_step.get("min_select", 0)) == 2 \
		and int(energy_step.get("max_select", 0)) == 2 \
		and int(target_step.get("min_select", 0)) == 1 \
		and bench_target in (target_step.get("items", []) as Array) \
		and tank_target in (target_step.get("items", []) as Array)
	var base_damage := int(blaziken.get_card_data().attacks[1].get("damage", "0"))
	DamageCalculator.new().apply_damage_to_slot(active_target, base_damage)
	var effect_executed := processor.execute_attack_effect(blaziken, 1, active_target, state, [{
		"discard_two_energy_for_bench_damage": [fire_a, fire_b],
		"bench_damage_target": [bench_target],
	}])
	var two_exact_prizes := active_target.is_knocked_out() and bench_target.is_knocked_out() \
		and not tank_target.is_knocked_out() and base_damage == 120
	var discarded_exact_two := fire_a in state.players[0].discard_pile \
		and fire_b in state.players[0].discard_pile \
		and blaziken.attached_energy == [psychic]

	var short_processor := EffectProcessor.new()
	var short_state := _game_state(10)
	var short_blaziken := _real_slot(_real_card_data(BLAZIKEN_UID), 0)
	short_blaziken.attached_energy = [_real_instance(FIRE_UID, 0), _real_instance(PSYCHIC_UID, 0)]
	short_state.players[0].active_pokemon = short_blaziken
	short_state.players[1].active_pokemon = _target("Public short-cost target", 120, 1)
	short_processor.register_pokemon_card(short_blaziken.get_card_data())
	var short_cost_blocked := not RuleValidator.new().can_use_attack(short_state, 0, 1, short_processor)
	var strict_121_boundary := base_damage < tank_target.get_card_data().hp
	var route_biases: Dictionary = _profile.get("route_preferences", {}).get("route_biases", {})
	var terminal_contract := float(route_biases.get("route:attack_ko", 0.0)) \
		> float(route_biases.get("route:information", 0.0)) \
		and bool(_profile.get("safety", {}).get("reject_information_churn_after_ko_secured", false))

	var passed := attack_legal and interaction_exact and effect_executed and two_exact_prizes \
		and discarded_exact_two and short_cost_blocked and strict_121_boundary and terminal_contract
	_check(passed, "scenario E must use single-prize Blaziken to take the exact final two Prizes")
	_rows.append(_row(
		"single_prize_blaziken_takes_two_prizes",
		"关键奖路线",
		"己方剩2奖时，单奖火焰鸡用第二招同时击倒120HP前场与120HP备战，弃掉精确2能量并立即结束，而不是继续抽牌。",
		"Blaziken attack 2: 120 Active + 120 exact Bench = final two Prizes",
		["第二招必须支付火火无色", "只弃2张选定能量", "121HP备战目标不会被120伤害击倒", "已锁定终局时拒绝可选抽牌"],
		passed
	))


func _draw_order_state() -> Dictionary:
	var processor := EffectProcessor.new()
	var state := _game_state(10)
	var fez := _real_slot(_real_card_data(FEZANDIPITI_UID), 0)
	var iono := _real_instance(IONO_UID, 0)
	state.players[0].active_pokemon = fez
	state.players[0].hand = [iono, _filler("VISIBLE_STALE_HAND", 0)]
	state.players[0].deck = [
		_filler("VISIBLE_DRAW_A", 0), _filler("VISIBLE_DRAW_B", 0),
		_filler("VISIBLE_DRAW_C", 0), _filler("VISIBLE_DRAW_D", 0),
		_filler("VISIBLE_DRAW_E", 0), _filler("VISIBLE_DRAW_F", 0),
	]
	_fill_prizes(state.players[0], 2, "OWN_DRAW_PRIZE")
	_fill_prizes(state.players[1], 4, "OPP_DRAW_PRIZE")
	state.players[1].active_pokemon = _target("Public draw-order target", 200, 1)
	state.last_knockout_turn_against[0] = state.turn_number - 1
	processor.register_pokemon_card(fez.get_card_data())
	return {"processor": processor, "state": state, "fez": fez, "iono": iono}


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
		"deck_name": "18.0 愿增猿火焰鸡",
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
			"inspected_artifact": ROUND00_PATH,
			"artifact_exists": FileAccess.file_exists(ROUND00_PATH),
			"accepted_artifact": "",
			"seed_base": DECK_ID,
			"legacy_user_deck_evidence_reused": false,
			"note": "No provenance-bearing round00 matched to the current bundled_ai fingerprint exists, so no old or user-deck evidence is accepted as baseline evidence.",
		},
		"scope": "focused scenario preparation only; no real-model formal benchmark",
		"scenario_count": _rows.size(),
		"passed_count": _rows.filter(func(row: Dictionary) -> bool: return bool(row.get("passed", false))).size(),
		"all_passed": _failures.is_empty() and _rows.size() == 5,
		"production_status": "scenario_contract_ready_not_promoted",
		"known_production_gaps": [
			"No deck-local promotion or aggregate win-rate claim is made by these five fixtures.",
			"The exact split-energy, Rare Candy, Boiling Spirit, Adrena Brain, Iono, Flip the Script, and single-prize Blaziken attack paths are verified through real engine effects.",
			"The V18CPG runtime still needs live bounded certificates for multi-action continuation ownership and post-interaction target binding for this deck.",
			"A new provenance-bearing, fingerprint-aligned bundled_ai round00 and paired-seed comparison against the exact Rule floor remain pending.",
		],
		"isolation": {
			"profile_modified": false,
			"shared_strategy_modified": false,
			"shared_registry_modified": false,
			"shared_strategic_shape_modified": false,
			"rule_or_legacy_or_agent_modified": false,
			"real_model_formal_run": false,
			"invalidated_user_deck_evidence_reused": false,
		},
		"coverage": [
			"Boiling Spirit and the manual attachment splitting visible Darkness/Fire to online Munkidori and Blaziken together",
			"Rare Candy binding only the old Torchic while rejecting fresh-root and direct Stage-2 shortcuts",
			"Darkness-powered Adrena Brain moving exactly three lethal counters with cap and once-per-turn guards",
			"Iono before Flip the Script preserving both public draw windows and exposing the reversed-order loss",
			"single-prize Blaziken taking the exact final two Prizes across Active and Bench with cost, discard, and 121-HP boundaries",
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
