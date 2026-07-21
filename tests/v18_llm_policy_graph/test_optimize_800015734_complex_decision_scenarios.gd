extends SceneTree

const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const SemanticCompilerScript = preload("res://scripts/ai/v18_cpg/semantics/V18CPGDeckSemanticCompiler.gd")
const RouteSearchScript = preload("res://scripts/ai/v18_cpg/planning/V18CPGRouteSearch.gd")
const CapabilityRegistryScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCapabilityRegistry.gd")
const MaterialDeltaScript = preload("res://scripts/ai/v18_cpg/observation/V18CPGMaterialDelta.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")

const DECK_ID := 800015734
const DECK_SEED_PATH := "res://data/bundled_user/decks/800015734.json"
const MANIFEST_PATH := "res://scripts/ai/v18_cpg/profiles/generated_semantic_manifests/800015734.json"
const ROUND00_PATH := "res://tmp/v18cpg/optimization21/800015734/round00.json"
const REPORT_PATH := "res://tmp/v18cpg/optimization21/800015734/complex_decision_scenarios.json"

const DREEPY_UID := "CSV8C_157"
const DRAKLOAK_UID := "CSV8C_158"
const DRAGAPULT_UID := "CSV8C_159"
const DUSKULL_UID := "CS5.5C_032"
const DUSCLOPS_UID := "CSV8C_082"
const DUSKNOIR_UID := "CSV8C_083"
const POFFIN_UID := "CSV7C_177"
const IONO_UID := "CSV3C_123"
const RARE_CANDY_UID := "CSVH1C_045"
const FIRE_UID := "CSVE1C_FIR"
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
	_check(int(_profile.get("deck_id", 0)) == DECK_ID, "production self-KO Dragapult profile must load")
	_check(int(_manifest.get("deck_id", 0)) == DECK_ID, "self-KO Dragapult semantic manifest must load")
	_check(int(_deck_seed.get("id", 0)) == DECK_ID and deck.total_cards == 60,
		"current bundled AI seed must be the exact 60-card deck")
	_check(_profile.get("modules", []) == ["dragapult_spread", "damage_counter_control", "stage2_chain"],
		"scenarios must use the production spread/counter-control/stage2 composition")
	_check(_current_fingerprint != ""
		and _current_fingerprint == str(_manifest.get("deck_content_fingerprint", "")),
		"semantic manifest fingerprint must match the current bundled AI deck")

	_scenario_a_dusknoir_exact_public_conversion()
	_scenario_b_rare_candy_dragapult_chain()
	_scenario_c_recon_then_typed_attachment()
	_scenario_d_poffin_before_iono()
	_scenario_e_blast_then_phantom_four_prize_closeout()
	_write_report()

	EffectProcessor.cleanup_live_instances_for_tests()
	if _failures.is_empty() and _rows.size() == 5:
		print("optimization21 800015734 complex decision scenarios: PASS (5/5)")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("optimization21 800015734 complex decision scenarios: FAIL (%d)" % _failures.size())
	quit(1)


func _scenario_a_dusknoir_exact_public_conversion() -> void:
	var processor := EffectProcessor.new()
	var state := _game_state()
	var dragapult := _real_slot(DRAGAPULT_UID, 0)
	var dusknoir := _real_slot(DUSKNOIR_UID, 0)
	var exact_target := _public_slot("Public 130 HP ex", 130, 2, 1)
	var healthy_target := _public_slot("Public 140 HP ex", 140, 2, 1)
	state.players[0].active_pokemon = dragapult
	state.players[0].bench = [dusknoir]
	state.players[1].active_pokemon = exact_target
	state.players[1].bench = [healthy_target]
	processor.register_pokemon_card(dusknoir.get_card_data())
	var ability_ready := processor.can_use_ability(dusknoir, state, 0)
	var effect := processor.get_ability_effect(dusknoir, 0, state)
	var steps: Array = effect.get_interaction_steps(dusknoir.get_top_card(), state) if effect != null else []
	var target_step := _step(steps, "self_ko_target")
	var exact_contract := int(target_step.get("min_select", 0)) == 1 \
		and int(target_step.get("max_select", 0)) == 1 \
		and (target_step.get("items", []) as Array) == [exact_target, healthy_target]
	var executed := processor.execute_ability_effect(dusknoir, 0, [{"self_ko_target": [exact_target]}], state)
	var exact_conversion := exact_target.damage_counters == 130 \
		and _is_knocked_out(exact_target) and _is_knocked_out(dusknoir)
	var consumed := not processor.can_use_ability(dusknoir, state, 0)

	var negative_processor := EffectProcessor.new()
	var negative_state := _game_state()
	var negative_source := _real_slot(DUSKNOIR_UID, 0)
	var negative_target := _public_slot("Public 140 HP ex", 140, 2, 1)
	negative_state.players[0].active_pokemon = _real_slot(DRAGAPULT_UID, 0)
	negative_state.players[0].bench = [negative_source]
	negative_state.players[1].active_pokemon = negative_target
	negative_processor.register_pokemon_card(negative_source.get_card_data())
	var negative_executed := negative_processor.execute_ability_effect(
		negative_source, 0, [{"self_ko_target": [negative_target]}], negative_state)
	var no_prize_conversion := negative_target.get_remaining_hp() == 10 \
		and not _is_knocked_out(negative_target) and _is_knocked_out(negative_source)

	var invalid_processor := EffectProcessor.new()
	var invalid_state := _game_state()
	var invalid_source := _real_slot(DUSKNOIR_UID, 0)
	var own_target := _real_slot(DREEPY_UID, 0)
	invalid_state.players[0].active_pokemon = own_target
	invalid_state.players[0].bench = [invalid_source]
	invalid_state.players[1].active_pokemon = _public_slot("Opponent", 130, 2, 1)
	invalid_processor.register_pokemon_card(invalid_source.get_card_data())
	var invalid_executed := invalid_processor.execute_ability_effect(
		invalid_source, 0, [{"self_ko_target": [own_target]}], invalid_state)
	var own_target_rejected := own_target.damage_counters == 0 and invalid_source.damage_counters == 0
	var control_params: Dictionary = (_profile.get("module_parameters", {}) as Dictionary).get(
		"damage_counter_control", {})
	var profile_bound := bool(control_params.get("require_public_prize_gain_for_self_ko", false)) \
		and int((control_params.get("self_ko_counter_by_uid", {}) as Dictionary).get(DUSKNOIR_UID, 0)) == 13 \
		and int((control_params.get("self_ko_counter_by_uid", {}) as Dictionary).get(DUSCLOPS_UID, 0)) == 5
	var passed: bool = ability_ready and effect != null and exact_contract and executed and exact_conversion \
		and consumed and negative_executed and no_prize_conversion and invalid_executed \
		and own_target_rejected and profile_bound
	_check(passed, "scenario A must bind Dusknoir's real 13-counter self-KO to an exact public prize conversion")
	_rows.append(_row(
		"dusknoir_exact_public_conversion",
		"自爆与伤害资源转换",
		"黑夜魔灵只在公开的130HP目标上把13个指示物直接换成奖赏；140HP目标会剩10HP，却仍付出己方单奖，不能冒充等价路线。",
		"黑夜魔灵咒怨炸弹 -> 130HP双奖目标 -> 立即换奖",
		["140HP目标不会被13个指示物击倒", "己方宝可梦不是合法目标", "使用后黑夜魔灵自身昏厥且同回合不能重复使用"],
		passed
	))


func _scenario_b_rare_candy_dragapult_chain() -> void:
	var processor := EffectProcessor.new()
	var state := _game_state()
	var old_dreepy := _real_slot(DREEPY_UID, 0)
	old_dreepy.turn_played = 1
	var fresh_dreepy := _real_slot(DREEPY_UID, 0)
	fresh_dreepy.turn_played = state.turn_number
	var candy := _real_instance(RARE_CANDY_UID, 0)
	var dragapult_card := _real_instance(DRAGAPULT_UID, 0)
	state.players[0].active_pokemon = old_dreepy
	state.players[0].bench = [fresh_dreepy]
	state.players[0].hand = [candy, dragapult_card, _real_instance(DRAKLOAK_UID, 0)]
	state.players[1].active_pokemon = _public_slot("Public evolution target", 220, 2, 1)
	var effect := processor.get_effect(candy.card_data.effect_id)
	var steps: Array = effect.get_interaction_steps(candy, state) if effect != null else []
	var stage2_step := _step(steps, "stage2_card")
	var target_step := _step(steps, "target_pokemon")
	var exact_options := dragapult_card in (stage2_step.get("items", []) as Array) \
		and old_dreepy in (target_step.get("items", []) as Array) \
		and fresh_dreepy not in (target_step.get("items", []) as Array)
	var executed := processor.execute_card_effect(candy, [{
		"stage2_card": [dragapult_card],
		"target_pokemon": [old_dreepy],
	}], state)
	var evolved := old_dreepy.get_card_data().get_uid() == DRAGAPULT_UID \
		and old_dreepy.pokemon_stack.size() == 2 and dragapult_card not in state.players[0].hand

	var observation := _observation(
		[_evolve("evolve:candy-dragapult", DRAGAPULT_UID, "slot:active"), _end_turn("end:skip-evolve")],
		_slot("slot:active", DREEPY_UID, []), [], 18)
	var facts := _facts(false, false, false, 3, false, false, 40)
	var frontier := _frontier(observation, {
		"evolve:candy-dragapult": 520.0,
		"end:skip-evolve": -900.0,
	}, facts, "evolve:candy-dragapult")
	var stage2_annotation := _module(_candidate(frontier, "evolve:candy-dragapult"), "stage2_chain")

	var negative_state := _game_state()
	var negative_fresh := _real_slot(DREEPY_UID, 0)
	negative_fresh.turn_played = negative_state.turn_number
	var negative_candy := _real_instance(RARE_CANDY_UID, 0)
	var negative_dragapult := _real_instance(DRAGAPULT_UID, 0)
	negative_state.players[0].active_pokemon = negative_fresh
	negative_state.players[0].hand = [negative_candy, negative_dragapult, _real_instance(DRAKLOAK_UID, 0)]
	negative_state.players[1].active_pokemon = _public_slot("Opponent", 100, 1, 1)
	var fresh_blocked := not processor.execute_card_effect(negative_candy, [{
		"stage2_card": [negative_dragapult],
		"target_pokemon": [negative_fresh],
	}], negative_state) or negative_fresh.get_card_data().get_uid() == DREEPY_UID
	var direct_blocked := not RuleValidator.new().can_evolve(
		negative_state, 0, negative_fresh, negative_dragapult, processor)
	var passed: bool = effect != null and exact_options and executed and evolved and fresh_blocked \
		and direct_blocked and bool(stage2_annotation.get("evolution_progress", false)) \
		and "resolve_stage2_dependency_order" in (stage2_annotation.get("decision_hints", []) as Array)
	_check(passed, "scenario B must Candy only the old Dreepy into the real Dragapult Stage-2 line")
	_rows.append(_row(
		"rare_candy_dragapult_chain",
		"多龙进化",
		"用神奇糖果把已留场一回合的多龙梅西亚直接进化为多龙巴鲁托ex，保留本回合刚落场的另一根；普通进化不能跳过多龙奇。",
		"旧多龙梅西亚 + 神奇糖果 + 多龙巴鲁托ex",
		["本回合刚落场的多龙梅西亚不能吃糖", "普通进化不能由基础直接到二阶", "一阶多龙奇不是神奇糖果的目标"],
		passed
	))


func _scenario_c_recon_then_typed_attachment() -> void:
	var processor := EffectProcessor.new()
	var state := _game_state()
	var dragapult := _real_slot(DRAGAPULT_UID, 0)
	dragapult.attached_energy = [_real_instance(PSYCHIC_UID, 0)]
	var drakloak := _real_slot(DRAKLOAK_UID, 0)
	var fire := _real_instance(FIRE_UID, 0)
	var iono := _real_instance(IONO_UID, 0)
	var filler := _filler_instance("VISIBLE_AFTER_TOP_TWO", 0)
	state.players[0].active_pokemon = dragapult
	state.players[0].bench = [drakloak]
	state.players[0].deck = [fire, iono, filler]
	state.players[1].active_pokemon = _public_slot("Public attack target", 220, 2, 1)
	processor.register_pokemon_card(drakloak.get_card_data())
	processor.register_pokemon_card(dragapult.get_card_data())
	var ready := processor.can_use_ability(drakloak, state, 0)
	var effect := processor.get_ability_effect(drakloak, 0, state)
	var steps: Array = effect.get_interaction_steps(drakloak.get_top_card(), state) if effect != null else []
	var top_step := _step(steps, "look_top_pick")
	var exact_public_top := str(top_step.get("visible_scope", "")) == "own_top_2_cards" \
		and (top_step.get("card_items", []) as Array) == [fire, iono]
	var before := _observation([
		_ability("ability:recon-fire", "slot:drakloak", DRAKLOAK_UID, true),
		_attach_energy("attach:duplicate-psychic", PSYCHIC_UID, "slot:active"),
	], _slot("slot:active", DRAGAPULT_UID, [_psychic_energy()]), [
		_slot("slot:drakloak", DRAKLOAK_UID, []),
	], 3)
	before["observation_hash"] = "self-ko-dragapult-before-recon"
	var facts_before := _facts(false, false, true, 1, false, false, 70)
	var scout_frontier := _frontier(before, {
		"ability:recon-fire": 520.0,
		"attach:duplicate-psychic": 500.0,
	}, facts_before, "ability:recon-fire")
	var scout_candidate := _candidate(scout_frontier, "ability:recon-fire")
	var scouted := processor.execute_ability_effect(drakloak, 0, [{"look_top_pick": [fire]}], state)
	var exact_resolution := fire in state.players[0].hand and state.players[0].deck == [filler, iono]
	var consumed := not processor.can_use_ability(drakloak, state, 0)
	var after := before.duplicate(true)
	after["observation_version"] = 2
	after["observation_hash"] = "self-ko-dragapult-after-recon"
	after["own"]["hand"] = [_fire_energy()]
	after["own"]["deck_count"] = 2
	after["legal_actions"] = [
		_attach_energy("attach:fire-completes-rp", FIRE_UID, "slot:active"),
		_attach_energy("attach:psychic-still-missing-fire", PSYCHIC_UID, "slot:active"),
	]
	var facts_after := _facts(false, false, true, 1, false, false, 70)
	var reopened := _epoch_reopens(before, after, facts_before, facts_after, scout_candidate, scout_frontier)
	var attach_frontier := _frontier(after, {
		"attach:fire-completes-rp": 520.0,
		"attach:psychic-still-missing-fire": 500.0,
	}, facts_after, "attach:fire-completes-rp")
	var fire_candidate := _candidate(attach_frontier, "attach:fire-completes-rp")
	var psychic_candidate := _candidate(attach_frontier, "attach:psychic-still-missing-fire")
	var typed: Dictionary = _module(fire_candidate, "stage2_chain").get("typed_attachment", {})
	var wrong_typed: Dictionary = _module(psychic_candidate, "stage2_chain").get("typed_attachment", {})
	var certificate := CapabilityRegistryScript.new().verify_route_advantage(
		fire_candidate, psychic_candidate, facts_after, _profile)
	state.players[0].hand.erase(fire)
	dragapult.attached_energy.append(fire)
	var attack_ready := RuleValidator.new().can_use_attack(state, 0, 1, processor)
	var passed: bool = ready and effect != null and exact_public_top and scouted and exact_resolution \
		and consumed and reopened and attack_ready \
		and bool(typed.get("completes_required_types", false)) \
		and typed.get("required_symbols", []) == ["R", "P"] \
		and not bool(wrong_typed.get("completes_required_types", false)) \
		and bool(certificate.get("verified", false)) \
		and str(certificate.get("certificate_kind", "")) == "public_typed_attack_cost_completion"
	_check(passed, "scenario C must Recon the public Fire card before attaching it to complete Dragapult's RP cost")
	_rows.append(_row(
		"recon_then_typed_attachment",
		"能量与特性顺序",
		"多龙巴鲁托已有超能且只缺火能时，先用多龙奇侦察牌库顶2拿到火能，信息epoch重开后再贴火，精确补齐幻影潜袭费用。",
		"侦察指令(火能) -> 信息结果 -> 火能贴多龙巴鲁托 -> 幻影潜袭",
		["再贴超能仍缺火能", "同一只多龙奇同回合不能重复使用", "未完成火/超费用不得声称幻影潜袭可用"],
		passed
	))


func _scenario_d_poffin_before_iono() -> void:
	var processor := EffectProcessor.new()
	var state := _poffin_iono_state()
	var poffin: CardInstance = state.players[0].hand[0]
	var iono: CardInstance = state.players[0].hand[1]
	var dreepy_a: CardInstance = state.players[0].deck[0]
	var dreepy_b: CardInstance = state.players[0].deck[1]
	var drakloak: CardInstance = state.players[0].deck[2]
	var poffin_effect := processor.get_effect(poffin.card_data.effect_id)
	var poffin_steps: Array = poffin_effect.get_interaction_steps(poffin, state) if poffin_effect != null else []
	var poffin_step := _step(poffin_steps, "buddy_poffin_pokemon")
	var exact_search := str(poffin_step.get("visible_scope", "")) == "own_full_deck" \
		and dreepy_a in (poffin_step.get("items", []) as Array) \
		and dreepy_b in (poffin_step.get("items", []) as Array) \
		and drakloak not in (poffin_step.get("items", []) as Array)
	var before := _observation([
		_play_trainer("item:poffin-before-iono", POFFIN_UID, true),
		_play_trainer("supporter:iono-before-poffin", IONO_UID, false),
	], _slot("slot:active", DUSKULL_UID, []), [], state.players[0].deck.size())
	before["observation_hash"] = "self-ko-dragapult-before-poffin"
	var facts_before := _facts(false, false, false, state.players[0].hand.size(), false, false, 40)
	var frontier := _frontier(before, {
		"item:poffin-before-iono": 520.0,
		"supporter:iono-before-poffin": 500.0,
	}, facts_before, "item:poffin-before-iono")
	var poffin_candidate := _candidate(frontier, "item:poffin-before-iono")
	var poffin_executed := processor.execute_card_effect(poffin, [{
		"buddy_poffin_pokemon": [dreepy_a, dreepy_b],
	}], state)
	state.players[0].hand.erase(poffin)
	state.players[0].discard_pile.append(poffin)
	var roots_survive := _slot_uids(state.players[0].bench) == [DREEPY_UID, DREEPY_UID]
	var after := before.duplicate(true)
	after["observation_version"] = 2
	after["observation_hash"] = "self-ko-dragapult-after-poffin"
	after["own"]["bench"] = [
		_slot("slot:dreepy-a", DREEPY_UID, []),
		_slot("slot:dreepy-b", DREEPY_UID, []),
	]
	after["own"]["deck_count"] = state.players[0].deck.size()
	after["legal_actions"] = [_play_trainer("supporter:iono-after-poffin", IONO_UID, false)]
	var facts_after := _facts(false, false, false, state.players[0].hand.size(), false, false, 40)
	var reopened := _epoch_reopens(before, after, facts_before, facts_after, poffin_candidate, frontier)
	state.players[0].hand.erase(iono)
	state.players[0].discard_pile.append(iono)
	var iono_executed := processor.execute_card_effect(iono, [], state)
	var roots_after_reset := roots_survive and _slot_uids(state.players[0].bench) == [DREEPY_UID, DREEPY_UID]

	var wrong_processor := EffectProcessor.new()
	var wrong_state := _poffin_iono_state()
	var wrong_poffin: CardInstance = wrong_state.players[0].hand[0]
	var wrong_iono: CardInstance = wrong_state.players[0].hand[1]
	wrong_state.players[0].hand.erase(wrong_iono)
	wrong_state.players[0].discard_pile.append(wrong_iono)
	var wrong_iono_executed := wrong_processor.execute_card_effect(wrong_iono, [], wrong_state)
	var reset_loses_roots := wrong_state.players[0].bench.is_empty() \
		and wrong_poffin not in wrong_state.players[0].hand \
		and wrong_poffin in wrong_state.players[0].deck
	var passed: bool = poffin_effect != null and exact_search and poffin_executed and roots_survive \
		and reopened and iono_executed and roots_after_reset and wrong_iono_executed and reset_loses_roots
	_check(passed, "scenario D must establish both Dreepy roots before Iono puts Poffin on the deck bottom")
	_rows.append(_row(
		"poffin_before_iono",
		"抽牌与支援者顺序",
		"手里同时有友好宝芬和奇树时，先公开检索两只70HP多龙梅西亚落场，再用奇树重置手牌；反序会把宝芬送到牌库底且本回合没有进化根。",
		"友好宝芬(两只多龙梅西亚) -> 信息结果 -> 奇树",
		["友好宝芬不能检索一阶多龙奇", "先奇树会把宝芬放到牌库底", "满备战区时不能声称建立新根"],
		passed
	))


func _scenario_e_blast_then_phantom_four_prize_closeout() -> void:
	var processor := EffectProcessor.new()
	var state := _closeout_state(130)
	var dragapult := state.players[0].active_pokemon
	var dusknoir := state.players[0].bench[0]
	var active_target := state.players[1].active_pokemon
	var bomb_target := state.players[1].bench[0]
	var spread_target := state.players[1].bench[1]
	processor.register_pokemon_card(dusknoir.get_card_data())
	processor.register_pokemon_card(dragapult.get_card_data())
	var blast_executed := processor.execute_ability_effect(
		dusknoir, 0, [{"self_ko_target": [bomb_target]}], state)
	var bomb_prizes := 2 if _is_knocked_out(bomb_target) else 0
	state.players[1].bench.erase(bomb_target)
	var spread_step := _spread_step(processor, dragapult, state)
	var split := [{"target": spread_target, "amount": 60}]
	var split_valid := _distribution_is_valid(spread_step, split)
	var attack_legal := RuleValidator.new().can_use_attack(state, 0, 1, processor)
	var attack_executed := processor.execute_attack_effect(
		dragapult, 1, active_target, state, [{"bench_damage_counters": split}])
	var active_prizes := 1 if _base_attack_damage(dragapult.get_card_data(), 1) >= active_target.get_remaining_hp() else 0
	var spread_prizes := 1 if _is_knocked_out(spread_target) else 0
	var total_prizes := bomb_prizes + active_prizes + spread_prizes

	var negative_processor := EffectProcessor.new()
	var negative_state := _closeout_state(140)
	var negative_dragapult := negative_state.players[0].active_pokemon
	var negative_dusknoir := negative_state.players[0].bench[0]
	var negative_active := negative_state.players[1].active_pokemon
	var negative_bomb_target := negative_state.players[1].bench[0]
	var negative_spread := negative_state.players[1].bench[1]
	negative_processor.register_pokemon_card(negative_dusknoir.get_card_data())
	negative_processor.register_pokemon_card(negative_dragapult.get_card_data())
	var negative_blast := negative_processor.execute_ability_effect(
		negative_dusknoir, 0, [{"self_ko_target": [negative_bomb_target]}], negative_state)
	var negative_step := _spread_step(negative_processor, negative_dragapult, negative_state)
	var negative_split := [{"target": negative_spread, "amount": 60}]
	var negative_attack := negative_processor.execute_attack_effect(
		negative_dragapult, 1, negative_active, negative_state, [{"bench_damage_counters": negative_split}])
	var negative_total := (2 if _is_knocked_out(negative_bomb_target) else 0) \
		+ (1 if _base_attack_damage(negative_dragapult.get_card_data(), 1) >= negative_active.get_remaining_hp() else 0) \
		+ (1 if _is_knocked_out(negative_spread) else 0)
	var attack := _attack("attack:phantom-after-blast-win", DRAGAPULT_UID, 1, 200, true)
	attack["requires_interaction"] = true
	var observation := _observation([
		_play_trainer("supporter:iono-too-late", IONO_UID, false),
		attack,
	], _slot("slot:active", DRAGAPULT_UID, [_fire_energy(), _psychic_energy()]), [], 8)
	observation["own"]["prizes_remaining"] = 2
	observation["opponent"]["active"] = _public_target("PUBLIC_200_HP_SINGLE", 200, 1)
	observation["opponent"]["bench"] = [_public_target("PUBLIC_60_HP_SINGLE", 60, 1)]
	var facts := _facts(true, true, false, 2, false, false, 200)
	facts["resources"]["prizes_remaining"] = 2
	facts["prize"] = {"current_swing": 2, "win_now": true}
	var frontier := _frontier(observation, {
		"supporter:iono-too-late": 700.0,
		"attack:phantom-after-blast-win": 10.0,
	}, facts, "supporter:iono-too-late")
	var terminal := _candidate(frontier, "attack:phantom-after-blast-win")
	var safety := _route_safety(terminal, frontier, facts)
	var passed: bool = blast_executed and bomb_prizes == 2 and attack_legal and split_valid \
		and attack_executed and total_prizes == 4 and negative_blast and negative_attack \
		and negative_total == 2 and not _is_knocked_out(negative_bomb_target) \
		and bool(safety.get("valid", false)) \
		and str(safety.get("reason", "")) == "deterministic_prize_gain"
	_check(passed, "scenario E must prove the public 2+1+1 Blast-to-Phantom four-prize terminal")
	_rows.append(_row(
		"blast_then_phantom_four_prize_closeout",
		"关键奖路线",
		"己方剩4奖时，黑夜魔灵先用13个指示物击倒130HP双奖备战；替换结算后，多龙巴鲁托幻影潜袭击倒200HP单奖前台并把6个指示物放到60HP单奖备战，形成2+1+1终结。",
		"咒怨炸弹130(双奖) -> 幻影潜袭200前台 + 60后场 = 四奖终结",
		["自爆目标140HP会剩10HP，总路线只有两奖", "自爆后必须先完成昏厥与替换结算", "终局证书只使用公开HP、奖数与合法交互目标"],
		passed
	))


func _frontier(observation: Dictionary, scores: Dictionary, facts: Dictionary, rule_action_id: String) -> Array[Dictionary]:
	var pool: Array[Dictionary] = RouteSearchScript.new().build_candidate_pool(observation, scores, _manifest, facts)
	var annotated: Array[Dictionary] = CapabilityRegistryScript.new().annotate_frontier(
		pool, observation, facts, _profile, _manifest)
	for candidate: Dictionary in annotated:
		candidate["engine_rule_floor_exact"] = str(candidate.get("safe_prefix_action_id", "")) == rule_action_id
	_check(not annotated.is_empty()
		and str(annotated[0].get("safe_prefix_action_id", "")) == rule_action_id,
		"fixture Rule floor %s must remain exact and first" % rule_action_id)
	_check(not JSON.stringify(annotated).contains("FORBIDDEN_SECRET"),
		"public scenario frontier must exclude hidden sentinels")
	return annotated


func _route_safety(selected: Dictionary, frontier: Array[Dictionary], facts: Dictionary) -> Dictionary:
	if selected.is_empty():
		return {"valid": false, "reason": "missing_selected_candidate"}
	var strategy = StrategyScript.new()
	strategy.configure_profile(_profile, _manifest)
	return strategy.call("_validate_model_route_safety",
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
	return bool(strategy.call("_should_reopen_information_epoch", "local_gate", {
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


func _module(candidate: Dictionary, module_id: String) -> Dictionary:
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	return annotations.get(module_id, {}) if annotations.get(module_id, {}) is Dictionary else {}


func _observation(actions: Array, active: Dictionary, bench: Array, deck_count: int) -> Dictionary:
	return {
		"observation_version": 1,
		"observation_hash": "self-ko-dragapult-complex-scenario",
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
	var hp := 320 if uid == DRAGAPULT_UID else 160 if uid == DUSKNOIR_UID else 100 if uid == DRAKLOAK_UID else 70
	return {
		"slot_id": slot_id,
		"pokemon": _card(uid),
		"energy": energy,
		"energy_count": energy.size(),
		"remaining_hp": hp,
		"max_hp": hp,
		"prize_count": 2 if uid == DRAGAPULT_UID else 1,
	}


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


func _evolve(action_id: String, uid: String, target: String) -> Dictionary:
	return {
		"id": action_id,
		"kind": "evolve",
		"card": _card(uid),
		"target": target,
		"requires_interaction": true,
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


func _game_state() -> GameState:
	var state := GameState.new()
	state.current_player_index = 0
	state.first_player_index = 0
	state.turn_number = 8
	state.phase = GameState.GamePhase.MAIN
	for index: int in 2:
		var player := PlayerState.new()
		player.player_index = index
		state.players.append(player)
	return state


func _real_card(uid: String) -> CardData:
	var path := "res://data/bundled_user/cards/%s.json" % uid
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(parsed is Dictionary, "real card %s must load" % uid)
	return CardData.from_dict(parsed as Dictionary) if parsed is Dictionary else CardData.new()


func _real_instance(uid: String, owner: int) -> CardInstance:
	return CardInstance.create(_real_card(uid), owner)


func _real_slot(uid: String, owner: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(_real_instance(uid, owner))
	return slot


func _public_slot(name: String, hp: int, prize_count: int, owner: int) -> PokemonSlot:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = "Pokemon"
	data.stage = "Basic"
	data.hp = hp
	data.mechanic = "ex" if prize_count == 2 else ""
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(data, owner))
	return slot


func _filler_instance(name: String, owner: int) -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = "Item"
	return CardInstance.create(data, owner)


func _poffin_iono_state() -> GameState:
	var state := _game_state()
	state.players[0].active_pokemon = _real_slot(DUSKULL_UID, 0)
	state.players[1].active_pokemon = _public_slot("Public search target", 100, 1, 1)
	state.players[0].hand = [
		_real_instance(POFFIN_UID, 0),
		_real_instance(IONO_UID, 0),
		_real_instance(DRAGAPULT_UID, 0),
	]
	state.players[0].deck = [
		_real_instance(DREEPY_UID, 0),
		_real_instance(DREEPY_UID, 0),
		_real_instance(DRAKLOAK_UID, 0),
	]
	for index: int in 10:
		state.players[0].deck.append(_filler_instance("VISIBLE_DRAW_%d" % index, 0))
	for player: PlayerState in state.players:
		_fill_prizes(player, 3)
	return state


func _closeout_state(bomb_target_hp: int) -> GameState:
	var state := _game_state()
	var dragapult := _real_slot(DRAGAPULT_UID, 0)
	dragapult.attached_energy = [_real_instance(FIRE_UID, 0), _real_instance(PSYCHIC_UID, 0)]
	var dusknoir := _real_slot(DUSKNOIR_UID, 0)
	state.players[0].active_pokemon = dragapult
	state.players[0].bench = [dusknoir]
	state.players[1].active_pokemon = _public_slot("Public 200 HP single", 200, 1, 1)
	state.players[1].bench = [
		_public_slot("Public bomb target", bomb_target_hp, 2, 1),
		_public_slot("Public 60 HP single", 60, 1, 1),
	]
	_fill_prizes(state.players[0], 4)
	_fill_prizes(state.players[1], 3)
	return state


func _fill_prizes(player: PlayerState, count: int) -> void:
	player.prizes.clear()
	for index: int in count:
		player.prizes.append(_filler_instance("Prize %d" % index, player.player_index))


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


func _spread_step(processor: EffectProcessor, dragapult: PokemonSlot, state: GameState) -> Dictionary:
	for effect: BaseEffect in processor.get_attack_effects_for_slot(dragapult, 1):
		var steps: Array = effect.get_attack_interaction_steps(
			dragapult.get_top_card(), dragapult.get_card_data().attacks[1], state)
		var spread := _step(steps, "bench_damage_counters")
		if not spread.is_empty():
			return spread
	return {}


func _distribution_is_valid(step: Dictionary, assignments: Array) -> bool:
	var legal_targets: Array = step.get("target_items", []) if step.get("target_items", []) is Array else []
	var total_damage := 0
	for raw_assignment: Variant in assignments:
		if not (raw_assignment is Dictionary):
			return false
		var assignment: Dictionary = raw_assignment
		var amount := int(assignment.get("amount", 0))
		if assignment.get("target") not in legal_targets or amount <= 0 or amount % 10 != 0:
			return false
		total_damage += amount
	return total_damage == int(step.get("total_counters", 0)) * 10


func _is_knocked_out(slot: PokemonSlot) -> bool:
	return slot != null and slot.get_card_data() != null \
		and slot.damage_counters >= int(slot.get_card_data().hp)


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


func _round00_summary() -> Dictionary:
	var base := {
		"required_source_kind": "bundled_ai",
		"required_deck_content_fingerprint": _current_fingerprint,
	}
	if not FileAccess.file_exists(ROUND00_PATH):
		base["artifact_exists"] = false
		base["status"] = "missing_current_bundled_ai_round00"
		return base
	var round00 := _load_json(ROUND00_PATH)
	var source: Dictionary = round00.get("deck_source", {}) \
		if round00.get("deck_source", {}) is Dictionary else {}
	var aligned := str(source.get("source_kind", "")) == "bundled_ai" \
		and str(source.get("deck_content_fingerprint", "")) == _current_fingerprint \
		and bool(source.get("fingerprint_verified", false))
	base["artifact_exists"] = true
	base["artifact"] = ROUND00_PATH
	base["provenance_aligned"] = aligned
	base["status"] = "current_bundled_ai_round00_available" if aligned \
		else "legacy_round00_excluded_missing_or_mismatched_provenance"
	base["strength_metrics_reused"] = aligned
	return base


func _write_report() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT_PATH.get_base_dir()))
	var report := {
		"schema_version": 1,
		"architecture": "V18CPG",
		"semantic_schema": "v18cpg-2",
		"transport_contract_version": 3,
		"deck_id": DECK_ID,
		"deck_name": str(_deck_seed.get("deck_name", "18.0 自爆多龙巴鲁托")),
		"strategy_id": str(_profile.get("strategy_id", "")),
		"profile_version": int(_profile.get("profile_version", 0)),
		"deck_source": {
			"source_kind": "bundled_ai",
			"seed_path": DECK_SEED_PATH,
			"source_provider": str(_deck_seed.get("source_provider", "")),
			"source_url": str(_deck_seed.get("source_url", "")),
			"total_cards": int(_deck_seed.get("total_cards", 0)),
			"deck_content_fingerprint": _current_fingerprint,
			"semantic_manifest_fingerprint": str(_manifest.get("deck_content_fingerprint", "")),
			"fingerprint_verified": _current_fingerprint != "" \
				and _current_fingerprint == str(_manifest.get("deck_content_fingerprint", "")),
		},
		"baseline": _round00_summary(),
		"scope": "focused scenario preparation only; no real-model formal benchmark",
		"scenario_count": _rows.size(),
		"passed_count": _rows.filter(func(row: Dictionary) -> bool: return bool(row.get("passed", false))).size(),
		"all_passed": _failures.is_empty() and _rows.size() == 5,
		"production_status": "scenario_contract_ready_not_promoted",
		"scenarios": _rows.duplicate(true),
		"known_production_gaps": [
			"The existing round00 has no bundled_ai deck_source/fingerprint provenance, so none of its win-rate or latency metrics are reused.",
			"These fixtures prove public-state decision boundaries; they do not claim a Rule-beating paired benchmark result.",
			"A production self-KO route still needs its exact target/prize certificate bound through the interaction bridge before promotion.",
			"No deck-local profile, shared runtime, Rule strategy, legacy LLM strategy, Agent strategy, or registry was modified.",
		],
		"isolation": {
			"focused_test_added": true,
			"tmp_report_generated": true,
			"profile_modified": false,
			"shared_runtime_modified": false,
			"rule_modified": false,
			"legacy_modified": false,
			"agent_modified": false,
			"formal_run_started": false,
		},
		"test_only": true,
	}
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	_check(file != null, "complex scenario report must be writable")
	if file != null:
		file.store_string(JSON.stringify(report, "  "))


func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(parsed is Dictionary, "%s must contain a JSON object" % path)
	return parsed as Dictionary if parsed is Dictionary else {}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
