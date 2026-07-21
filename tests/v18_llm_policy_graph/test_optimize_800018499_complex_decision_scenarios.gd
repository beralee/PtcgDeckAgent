extends SceneTree

const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const RouteSearchScript = preload("res://scripts/ai/v18_cpg/planning/V18CPGRouteSearch.gd")
const CapabilityRegistryScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCapabilityRegistry.gd")
const MaterialDeltaScript = preload("res://scripts/ai/v18_cpg/observation/V18CPGMaterialDelta.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")

const DECK_ID := 800018499
const MANIFEST_PATH := "res://scripts/ai/v18_cpg/profiles/generated_semantic_manifests/800018499.json"
const ROUND00_PATH := "res://tmp/v18cpg/optimization21/800018499/round00.json"
const REPORT_PATH := "res://tmp/v18cpg/optimization21/800018499/complex_decision_scenarios.json"

const DREEPY_UID := "CSV8C_157"
const DRAKLOAK_UID := "CSV8C_158"
const DRAGAPULT_UID := "CSV8C_159"
const RESEARCH_UID := "CSV1C_121"
const IONO_UID := "CSV3C_123"
const POFFIN_UID := "CSV7C_177"
const FIRE_UID := "CSVE1C_FIR"
const PSYCHIC_UID := "CSVE1C_PSY"
const LUMINOUS_UID := "CSV1C_127"
const NEO_UPPER_UID := "CSV7C_203"

var _profile: Dictionary = {}
var _manifest: Dictionary = {}
var _failures: Array[String] = []
var _rows: Array[Dictionary] = []


func _initialize() -> void:
	_profile = ProfileCatalogScript.get_profile_for_deck(DECK_ID)
	_manifest = _load_json(MANIFEST_PATH)
	_check(int(_profile.get("deck_id", 0)) == DECK_ID, "production pure Dragapult profile must load")
	_check(int(_manifest.get("deck_id", 0)) == DECK_ID, "pure Dragapult semantic manifest must load")
	_check(_profile.get("modules", []) == ["dragapult_spread", "stage2_chain", "damage_counter_control"], \
		"scenarios must use the production spread/stage2/counter-control composition")

	_scenario_a_drakloak_information_before_reset()
	_scenario_b_evolve_then_complete_typed_cost()
	_scenario_c_phantom_dive_allocation_efficiency()
	_scenario_d_poffin_before_research()
	_scenario_e_three_prize_phantom_closeout()
	_write_report()

	EffectProcessor.cleanup_live_instances_for_tests()
	if _failures.is_empty() and _rows.size() == 5:
		print("optimization21 800018499 complex decision scenarios: PASS (5/5)")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("optimization21 800018499 complex decision scenarios: FAIL (%d)" % _failures.size())
	quit(1)


func _scenario_a_drakloak_information_before_reset() -> void:
	var processor := EffectProcessor.new()
	var state := _game_state()
	var dragapult := _real_slot(_real_card_data(DRAGAPULT_UID), 0)
	dragapult.attached_energy = [_real_instance(PSYCHIC_UID, 0)]
	var drakloak := _real_slot(_real_card_data(DRAKLOAK_UID), 0)
	var fire := _real_instance(FIRE_UID, 0)
	var research := _real_instance(RESEARCH_UID, 0)
	var filler := _filler_instance("VISIBLE_AFTER_TOP_TWO", 0)
	state.players[0].active_pokemon = dragapult
	state.players[0].bench = [drakloak]
	state.players[0].deck = [fire, research, filler]
	state.players[1].active_pokemon = _real_target("Public scout target", 220, 2)
	processor.register_pokemon_card(drakloak.get_card_data())

	var ability_ready := processor.can_use_ability(drakloak, state, 0)
	var ability_effect := processor.get_ability_effect(drakloak, 0, state)
	var steps: Array = ability_effect.get_interaction_steps(drakloak.get_top_card(), state) \
		if ability_effect != null else []
	var top_step := _step(steps, "look_top_pick")
	var public_top_two := str(top_step.get("visible_scope", "")) == "own_top_2_cards" \
		and (top_step.get("card_items", []) as Array) == [fire, research] \
		and not JSON.stringify(top_step).contains("FORBIDDEN_SECRET")

	var before := _observation(
		[
			_ability("ability:recon-before-reset", "slot:drakloak", DRAKLOAK_UID, true),
			_play_trainer("supporter:research-before-recon", RESEARCH_UID, false),
			_end_turn("end:before-recon"),
		],
		_slot("slot:active", DRAGAPULT_UID, [_psychic_energy()]),
		[_slot("slot:drakloak", DRAKLOAK_UID, [])],
		3
	)
	before["observation_version"] = 1
	before["observation_hash"] = "pure-dragapult-before-recon"
	var facts_before := _facts(false, false, true, 2, false, false, 70)
	var scout_frontier := _frontier(before, {
		"ability:recon-before-reset": 530.0,
		"supporter:research-before-recon": 500.0,
		"end:before-recon": -900.0,
	}, facts_before, "ability:recon-before-reset")
	var scout_candidate := _candidate(scout_frontier, "ability:recon-before-reset")

	var scouted := processor.execute_ability_effect(drakloak, 0, [{"look_top_pick": [fire]}], state)
	var ability_consumed := not processor.can_use_ability(drakloak, state, 0)
	var exact_resolution := fire in state.players[0].hand and state.players[0].deck == [filler, research]

	var after := before.duplicate(true)
	after["observation_version"] = 2
	after["observation_hash"] = "pure-dragapult-after-recon"
	after["own"]["hand"] = [_fire_energy()]
	after["own"]["deck_count"] = 2
	after["legal_actions"] = [
		_play_trainer("supporter:research-after-recon", RESEARCH_UID, false),
		_attach_energy("attach:scouted-fire", FIRE_UID, "slot:active"),
	]
	var facts_after := _facts(false, false, true, 1, false, false, 70)
	var reopened := _epoch_reopens(before, after, facts_before, facts_after, scout_candidate, scout_frontier)
	var attach_frontier := _frontier(after, {
		"supporter:research-after-recon": 600.0,
		"attach:scouted-fire": 590.0,
	}, facts_after, "supporter:research-after-recon")
	var attach_candidate := _candidate(attach_frontier, "attach:scouted-fire")
	var certificate := CapabilityRegistryScript.new().verify_route_advantage(
		attach_candidate, attach_frontier[0], facts_after, _profile)
	var safety := _route_safety(attach_candidate, attach_frontier, facts_after)
	state.players[0].hand.erase(fire)
	dragapult.attached_energy.append(fire)
	var attack_ready := RuleValidator.new().can_use_attack(state, 0, 1, processor)

	var empty_state := _game_state()
	var empty_drakloak := _real_slot(_real_card_data(DRAKLOAK_UID), 0)
	empty_state.players[0].active_pokemon = empty_drakloak
	empty_state.players[1].active_pokemon = _real_target("Public empty-deck target", 100, 1)
	processor.register_pokemon_card(empty_drakloak.get_card_data())
	var empty_blocked := not processor.can_use_ability(empty_drakloak, empty_state, 0)

	var passed := ability_ready and public_top_two and scouted and exact_resolution \
		and ability_consumed and reopened and empty_blocked and attack_ready \
		and bool(certificate.get("verified", false)) \
		and str(certificate.get("certificate_kind", "")) == "public_typed_attack_cost_completion" \
		and bool(safety.get("valid", false))
	_check(passed, "scenario A must scout the exact public top two, bottom the unchosen card, and attach before reset")
	_rows.append(_row(
		"drakloak_information_before_reset",
		"多龙奇信息顺序",
		"多龙巴鲁托只缺火能时，先用多龙奇查看牌库顶2并拿火能；未选的博士研究置于牌库底，信息epoch重开后先完成火/超费用，再考虑手牌重置。",
		"侦察指令(火能) -> information_result -> 火能贴给多龙巴鲁托 -> 幻影潜袭",
		["同一只多龙奇本回合不能重复使用", "空牌库不能发动", "未完成火/超费用时不得声称攻击已就绪"],
		passed
	))


func _scenario_b_evolve_then_complete_typed_cost() -> void:
	var processor := EffectProcessor.new()
	var validator := RuleValidator.new()
	var state := _game_state()
	var chain := _real_slot(_real_card_data(DREEPY_UID), 0)
	chain.pokemon_stack.append(_real_instance(DRAKLOAK_UID, 0))
	chain.turn_played = 1
	chain.turn_evolved = 3
	var dragapult_card := _real_instance(DRAGAPULT_UID, 0)
	state.players[0].active_pokemon = chain
	state.players[0].hand = [dragapult_card]
	state.players[1].active_pokemon = _real_target("Public evolution target", 220, 2)
	var legal_evolution := validator.can_evolve(state, 0, chain, dragapult_card, processor)
	if legal_evolution:
		state.players[0].hand.erase(dragapult_card)
		chain.pokemon_stack.append(dragapult_card)
		chain.turn_evolved = state.turn_number
	chain.attached_energy = [_real_instance(FIRE_UID, 0)]
	processor.register_pokemon_card(chain.get_card_data())
	var blocked_before := not validator.can_use_attack(state, 0, 1, processor)
	var psychic := _real_instance(PSYCHIC_UID, 0)
	chain.attached_energy.append(psychic)
	var ready_after := validator.can_use_attack(state, 0, 1, processor)

	var direct_state := _game_state()
	var direct_dreepy := _real_slot(_real_card_data(DREEPY_UID), 0)
	direct_dreepy.turn_played = 1
	direct_state.players[0].active_pokemon = direct_dreepy
	direct_state.players[1].active_pokemon = _real_target("Public direct-stage2 target", 100, 1)
	var direct_stage2_blocked := not validator.can_evolve(
		direct_state, 0, direct_dreepy, _real_instance(DRAGAPULT_UID, 0), processor)

	var luminous_state := _game_state()
	var luminous_dragapult := _real_slot(_real_card_data(DRAGAPULT_UID), 0)
	luminous_dragapult.attached_energy = [
		_real_instance(LUMINOUS_UID, 0),
		_real_instance(LUMINOUS_UID, 0),
	]
	luminous_state.players[0].active_pokemon = luminous_dragapult
	luminous_state.players[1].active_pokemon = _real_target("Public Luminous target", 220, 2)
	processor.register_pokemon_card(luminous_dragapult.get_card_data())
	var double_luminous_blocked := not validator.can_use_attack(luminous_state, 0, 1, processor)

	var neo_state := _game_state()
	var neo_dragapult := _real_slot(_real_card_data(DRAGAPULT_UID), 0)
	neo_dragapult.attached_energy = [_real_instance(NEO_UPPER_UID, 0)]
	neo_state.players[0].active_pokemon = neo_dragapult
	neo_state.players[1].active_pokemon = _real_target("Public Neo Upper target", 220, 2)
	processor.register_pokemon_card(neo_dragapult.get_card_data())
	var neo_stage2_ready := validator.can_use_attack(neo_state, 0, 1, processor)
	var neo_basic_state := _game_state()
	var neo_dreepy := _real_slot(_real_card_data(DREEPY_UID), 0)
	neo_dreepy.attached_energy = [_real_instance(NEO_UPPER_UID, 0)]
	neo_basic_state.players[0].active_pokemon = neo_dreepy
	neo_basic_state.players[1].active_pokemon = _real_target("Public Basic Neo target", 100, 1)
	processor.register_pokemon_card(neo_dreepy.get_card_data())
	var neo_basic_blocked := not validator.can_use_attack(neo_basic_state, 0, 1, processor)

	var evolve_observation := _observation(
		[_evolve("evolve:dragapult", DRAGAPULT_UID, "slot:active"), _end_turn("end:skip-evolve")],
		_slot("slot:active", DRAKLOAK_UID, []), [], 18)
	var evolve_facts := _facts(false, false, true, 3, false, false, 40)
	var evolve_frontier := _frontier(evolve_observation, {
		"evolve:dragapult": 520.0,
		"end:skip-evolve": -900.0,
	}, evolve_facts, "evolve:dragapult")
	var evolve_annotation := _module(_candidate(evolve_frontier, "evolve:dragapult"), "stage2_chain")

	var attach_observation := _observation(
		[
			_play_basic("bench:dreepy-before-ready", DREEPY_UID),
			_attach_energy("attach:psychic-completes-rp", PSYCHIC_UID, "slot:active"),
			_attach_energy("attach:fire-does-not-complete", FIRE_UID, "slot:active"),
		],
		_slot("slot:active", DRAGAPULT_UID, [_fire_energy()]), [], 18)
	var attach_facts := _facts(false, false, true, 3, false, false, 70)
	var attach_frontier := _frontier(attach_observation, {
		"bench:dreepy-before-ready": 600.0,
		"attach:psychic-completes-rp": 590.0,
		"attach:fire-does-not-complete": 580.0,
	}, attach_facts, "bench:dreepy-before-ready")
	var psychic_candidate := _candidate(attach_frontier, "attach:psychic-completes-rp")
	var fire_candidate := _candidate(attach_frontier, "attach:fire-does-not-complete")
	var typed: Dictionary = _module(psychic_candidate, "stage2_chain").get("typed_attachment", {})
	var wrong_typed: Dictionary = _module(fire_candidate, "stage2_chain").get("typed_attachment", {})
	var certificate := CapabilityRegistryScript.new().verify_route_advantage(
		psychic_candidate, attach_frontier[0], attach_facts, _profile)
	var safety := _route_safety(psychic_candidate, attach_frontier, attach_facts)

	var passed: bool = legal_evolution and chain.get_card_data().get_uid() == DRAGAPULT_UID \
		and blocked_before and ready_after and direct_stage2_blocked \
		and double_luminous_blocked and neo_stage2_ready and neo_basic_blocked \
		and bool(evolve_annotation.get("evolution_progress", false)) \
		and bool(typed.get("completes_required_types", false)) \
		and typed.get("required_symbols", []) == ["R", "P"] \
		and not bool(wrong_typed.get("completes_required_types", false)) \
		and bool(certificate.get("verified", false)) and bool(safety.get("valid", false))
	_check(passed, "scenario B must evolve the real line and distinguish legal RP completion from special-Energy traps")
	_rows.append(_row(
		"evolve_then_complete_typed_cost",
		"进化与填能",
		"先把已留场一回合的多龙奇进化为多龙巴鲁托，再用超能补齐已有火能的幻影潜袭费用；新上能量在二阶宝可梦上可独立提供两份任意属性。",
		"多龙奇 -> 多龙巴鲁托 -> 超能贴附（已有火能） -> 幻影潜袭",
		["多龙梅西亚不能直接进化为二阶多龙巴鲁托", "两张光亮能量会互相降级，不能冒充火/超", "新上能量在基础多龙梅西亚上只提供1无色"],
		passed
	))


func _scenario_c_phantom_dive_allocation_efficiency() -> void:
	var processor := EffectProcessor.new()
	var state := _spread_state(20, 50)
	var dragapult := state.players[0].active_pokemon
	var bench_a := state.players[1].bench[0]
	var bench_b := state.players[1].bench[1]
	processor.register_pokemon_card(dragapult.get_card_data())
	var legal := RuleValidator.new().can_use_attack(state, 0, 1, processor)
	var spread_step := _spread_step(processor, dragapult, state)
	var exact_contract := str(spread_step.get("ui_mode", "")) == "counter_distribution" \
		and int(spread_step.get("total_counters", 0)) == 6 \
		and int(spread_step.get("min_select", 0)) == 6 \
		and int(spread_step.get("max_select", 0)) == 6 \
		and (spread_step.get("target_items", []) as Array) == [bench_a, bench_b]
	var optimized_assignment := [
		{"target": bench_a, "amount": 20},
		{"target": bench_b, "amount": 40},
	]
	var assignment_valid := _distribution_is_valid(spread_step, optimized_assignment)
	var executed := processor.execute_attack_effect(dragapult, 1, state.players[1].active_pokemon, state, [{
		"bench_damage_counters": optimized_assignment,
	}])
	var optimized_outcome := _is_knocked_out(bench_a) and bench_b.get_remaining_hp() == 10

	var stacked_processor := EffectProcessor.new()
	var stacked_state := _spread_state(20, 50)
	var stacked_dragapult := stacked_state.players[0].active_pokemon
	var stacked_a := stacked_state.players[1].bench[0]
	var stacked_b := stacked_state.players[1].bench[1]
	stacked_processor.register_pokemon_card(stacked_dragapult.get_card_data())
	var stacked_executed := stacked_processor.execute_attack_effect(
		stacked_dragapult, 1, stacked_state.players[1].active_pokemon, stacked_state, [{
			"bench_damage_counters": [{"target": stacked_a, "amount": 60}],
		}])
	var stacked_waste := _is_knocked_out(stacked_a) and stacked_b.get_remaining_hp() == 50
	var wrong_total_rejected := not _distribution_is_valid(spread_step, [
		{"target": bench_a, "amount": 20},
		{"target": bench_b, "amount": 30},
	])
	var active_target_rejected := not _distribution_is_valid(spread_step, [
		{"target": state.players[1].active_pokemon, "amount": 60},
	])

	var attack := _attack("attack:phantom-efficient-spread", DRAGAPULT_UID, 1, 200, false)
	attack["requires_interaction"] = true
	var observation := _observation(
		[attack, _end_turn("end:waste-spread")],
		_slot("slot:active", DRAGAPULT_UID, [_fire_energy(), _psychic_energy()]), [], 14)
	observation["opponent"]["active"] = _public_target("PUBLIC_ACTIVE_250", 250, 2)
	observation["opponent"]["bench"] = [
		_public_target("PUBLIC_20_HP_SINGLE", 20, 1),
		_public_target("PUBLIC_50_HP_TWO_PRIZE", 50, 2),
	]
	var facts := _facts(true, false, false, 3, false, false, 200)
	var frontier := _frontier(observation, {
		"attack:phantom-efficient-spread": 520.0,
		"end:waste-spread": -900.0,
	}, facts, "attack:phantom-efficient-spread")
	var spread_annotation := _module(_candidate(frontier, "attack:phantom-efficient-spread"), "dragapult_spread")
	var public_shape := int(spread_annotation.get("spread_target_count", 0)) == 2 \
		and "solve_two_turn_prize_map" in (spread_annotation.get("decision_hints", []) as Array)

	var passed := legal and exact_contract and assignment_valid and executed and optimized_outcome \
		and stacked_executed and stacked_waste and wrong_total_rejected \
		and active_target_rejected and public_shape
	_check(passed, "scenario C must spend exactly six public Bench counters without overkilling the 20-HP target")
	_rows.append(_row(
		"phantom_dive_allocation_efficiency",
		"幻影潜袭铺伤分配",
		"对手备战分别剩20与50HP时，把6个指示物按2/4分配：先收掉20HP单奖，同时把50HP双奖压到10HP；全堆前者会浪费40伤害并丢失后续奖图。",
		"幻影潜袭：2个指示物 -> 20HP目标，4个 -> 50HP目标",
		["总数不是6个时交互契约拒绝", "对手前台不是铺伤合法目标", "6个全堆20HP目标只收一奖且浪费4个"],
		passed
	))


func _scenario_d_poffin_before_research() -> void:
	var processor := EffectProcessor.new()
	var state := _search_reset_state()
	var poffin: CardInstance = state.players[0].hand[0]
	var research: CardInstance = state.players[0].hand[1]
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

	var before := _observation(
		[
			_play_trainer("item:poffin-before-research", POFFIN_UID, true),
			_play_trainer("supporter:research-before-poffin", RESEARCH_UID, false),
		],
		_slot("slot:active", DREEPY_UID, []), [], state.players[0].deck.size())
	before["observation_version"] = 1
	before["observation_hash"] = "pure-dragapult-before-poffin"
	var facts_before := _facts(false, false, false, state.players[0].hand.size(), false, false, 40)
	var poffin_frontier := _frontier(before, {
		"item:poffin-before-research": 520.0,
		"supporter:research-before-poffin": 500.0,
	}, facts_before, "item:poffin-before-research")
	var poffin_candidate := _candidate(poffin_frontier, "item:poffin-before-research")

	var poffin_executed := processor.execute_card_effect(poffin, [{
		"buddy_poffin_pokemon": [dreepy_a, dreepy_b],
	}], state)
	state.players[0].hand.erase(poffin)
	state.players[0].discard_pile.append(poffin)
	var roots_survive := _slot_uids(state.players[0].bench) == [DREEPY_UID, DREEPY_UID]
	var after := before.duplicate(true)
	after["observation_version"] = 2
	after["observation_hash"] = "pure-dragapult-after-poffin"
	after["own"]["bench"] = [
		_slot("slot:dreepy-a", DREEPY_UID, []),
		_slot("slot:dreepy-b", DREEPY_UID, []),
	]
	after["own"]["deck_count"] = state.players[0].deck.size()
	after["own"]["hand"] = [_card(RESEARCH_UID)]
	after["legal_actions"] = [_play_trainer("supporter:research-after-poffin", RESEARCH_UID, false)]
	var facts_after := _facts(false, false, false, state.players[0].hand.size(), false, false, 40)
	var reopened := _epoch_reopens(before, after, facts_before, facts_after, poffin_candidate, poffin_frontier)

	state.players[0].hand.erase(research)
	state.players[0].discard_pile.append(research)
	var research_executed := processor.execute_card_effect(research, [], state)
	var seven_after_reset := state.players[0].hand.size() == 7 and roots_survive

	var wrong_processor := EffectProcessor.new()
	var wrong_state := _search_reset_state()
	var wrong_poffin: CardInstance = wrong_state.players[0].hand[0]
	var wrong_research: CardInstance = wrong_state.players[0].hand[1]
	wrong_state.players[0].hand.erase(wrong_research)
	wrong_state.players[0].discard_pile.append(wrong_research)
	var wrong_research_executed := wrong_processor.execute_card_effect(wrong_research, [], wrong_state)
	var search_lost := wrong_poffin in wrong_state.players[0].discard_pile \
		and wrong_state.players[0].bench.is_empty() \
		and wrong_state.players[0].hand.size() == 7

	var passed := exact_search and poffin_executed and roots_survive and reopened \
		and research_executed and seven_after_reset and wrong_research_executed and search_lost
	_check(passed, "scenario D must establish two real Dreepy roots before Professor's Research discards the search item")
	_rows.append(_row(
		"poffin_before_research",
		"支援者与检索顺序",
		"手里同时有好友宝芬和博士研究时，先公开检索两只70HP多龙梅西亚落场，再使用博士研究；反过来会把宝芬直接弃掉，两个进化根均未建立。",
		"好友宝芬(两只多龙梅西亚) -> information_result -> 博士研究",
		["好友宝芬不能检索一阶多龙奇", "先博士研究会丢失手中的宝芬且备战仍为空", "满备战区时不得声称建立了新进化根"],
		passed
	))


func _scenario_e_three_prize_phantom_closeout() -> void:
	var processor := EffectProcessor.new()
	var state := _terminal_state()
	var dragapult := state.players[0].active_pokemon
	var bench_a := state.players[1].bench[0]
	var bench_b := state.players[1].bench[1]
	processor.register_pokemon_card(dragapult.get_card_data())
	var legal := RuleValidator.new().can_use_attack(state, 0, 1, processor)
	var spread_step := _spread_step(processor, dragapult, state)
	var split := [
		{"target": bench_a, "amount": 30},
		{"target": bench_b, "amount": 30},
	]
	var split_valid := _distribution_is_valid(spread_step, split)
	var executed := processor.execute_attack_effect(dragapult, 1, state.players[1].active_pokemon, state, [{
		"bench_damage_counters": split,
	}])
	var active_damage := _base_attack_damage(dragapult.get_card_data(), 1)
	var split_prizes := (1 if active_damage >= 200 else 0) \
		+ (1 if _is_knocked_out(bench_a) else 0) \
		+ (1 if _is_knocked_out(bench_b) else 0)

	var negative_processor := EffectProcessor.new()
	var negative_state := _terminal_state()
	var negative_dragapult := negative_state.players[0].active_pokemon
	var negative_a := negative_state.players[1].bench[0]
	var negative_b := negative_state.players[1].bench[1]
	negative_processor.register_pokemon_card(negative_dragapult.get_card_data())
	var negative_executed := negative_processor.execute_attack_effect(
		negative_dragapult, 1, negative_state.players[1].active_pokemon, negative_state, [{
			"bench_damage_counters": [{"target": negative_a, "amount": 60}],
		}])
	var stacked_prizes := 1 + (1 if _is_knocked_out(negative_a) else 0) \
		+ (1 if _is_knocked_out(negative_b) else 0)

	var attack := _attack("attack:phantom-three-prize-win", DRAGAPULT_UID, 1, 200, true)
	attack["requires_interaction"] = true
	var observation := _observation(
		[
			_play_trainer("supporter:iono-too-late", IONO_UID, false),
			attack,
		],
		_slot("slot:active", DRAGAPULT_UID, [_fire_energy(), _psychic_energy()]), [], 8)
	observation["own"]["prizes_remaining"] = 3
	observation["opponent"]["active"] = _public_target("PUBLIC_200_HP_SINGLE", 200, 1)
	observation["opponent"]["bench"] = [
		_public_target("PUBLIC_30_HP_SINGLE_A", 30, 1),
		_public_target("PUBLIC_30_HP_SINGLE_B", 30, 1),
	]
	var facts := _facts(true, true, false, 3, false, false, 200)
	facts["resources"]["prizes_remaining"] = 3
	facts["prize"] = {"current_swing": 3, "win_now": true}
	var frontier := _frontier(observation, {
		"supporter:iono-too-late": 700.0,
		"attack:phantom-three-prize-win": 10.0,
	}, facts, "supporter:iono-too-late")
	var attack_candidate := _candidate(frontier, "attack:phantom-three-prize-win")
	var safety := _route_safety(attack_candidate, frontier, facts)

	var passed := legal and split_valid and executed and split_prizes == 3 \
		and negative_executed and stacked_prizes == 2 \
		and bool(safety.get("valid", false)) \
		and str(safety.get("reason", "")) == "deterministic_prize_gain"
	_check(passed, "scenario E must bind the real 1+1+1 Phantom Dive split to a public three-Prize win: %s" % JSON.stringify({
		"legal": legal,
		"split_valid": split_valid,
		"executed": executed,
		"split_prizes": split_prizes,
		"negative_executed": negative_executed,
		"stacked_prizes": stacked_prizes,
		"safety": safety,
	}))
	_rows.append(_row(
		"three_prize_phantom_closeout",
		"关键奖收割",
		"己方剩3奖时，幻影潜袭击倒200HP单奖前台，并把6个指示物3/3分给两只各剩30HP的单奖备战，形成1+1+1当回合终结。",
		"幻影潜袭200 + 3/3铺伤 = 三奖终结",
		["6个全堆一个30HP目标只有两奖，不能宣称终结", "任一备战剩余HP高于30都会破坏三奖证书", "win_now必须只来自公开HP与奖数"],
		passed
	))


func _frontier(observation: Dictionary, scores: Dictionary, facts: Dictionary, rule_action_id: String) -> Array[Dictionary]:
	var pool: Array[Dictionary] = RouteSearchScript.new().build_candidate_pool(observation, scores, _manifest, facts)
	for candidate: Dictionary in pool:
		candidate["engine_rule_floor_exact"] = \
			str(candidate.get("safe_prefix_action_id", "")) == rule_action_id
	var annotated: Array[Dictionary] = CapabilityRegistryScript.new().annotate_frontier(
		pool, observation, facts, _profile, _manifest)
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


func _module(candidate: Dictionary, module_id: String) -> Dictionary:
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	return annotations.get(module_id, {}) if annotations.get(module_id, {}) is Dictionary else {}


func _observation(actions: Array, active: Dictionary, bench: Array, deck_count: int) -> Dictionary:
	return {
		"observation_version": 1,
		"observation_hash": "pure-dragapult-complex-scenario",
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
	var hp_by_uid := {
		DRAGAPULT_UID: 320,
		DRAKLOAK_UID: 90,
		DREEPY_UID: 70,
	}
	var hp := int(hp_by_uid.get(uid, 90))
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
		"prize_count": prize_count,
	}


func _play_trainer(action_id: String, uid: String, interaction: bool) -> Dictionary:
	return {
		"id": action_id,
		"kind": "play_trainer",
		"card": _card(uid),
		"requires_interaction": interaction,
	}


func _play_basic(action_id: String, uid: String) -> Dictionary:
	return {
		"id": action_id,
		"kind": "play_basic_to_bench",
		"card": _card(uid),
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
	var symbol := "R" if uid == FIRE_UID else "P" if uid == PSYCHIC_UID else "C"
	card["energy_type"] = symbol
	card["energy_provides"] = symbol
	var roles: Array = card.get("semantic_roles", []) if card.get("semantic_roles", []) is Array else []
	if "basic_energy" not in roles and uid in [FIRE_UID, PSYCHIC_UID]:
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


func _spread_state(first_remaining: int, second_remaining: int) -> GameState:
	var state := _game_state()
	var dragapult := _real_slot(_real_card_data(DRAGAPULT_UID), 0)
	dragapult.attached_energy = [_real_instance(FIRE_UID, 0), _real_instance(PSYCHIC_UID, 0)]
	var bench_a := _real_target("Public first Bench", 70, 1)
	var bench_b := _real_target("Public second Bench", 120, 2)
	bench_a.damage_counters = 70 - first_remaining
	bench_b.damage_counters = 120 - second_remaining
	state.players[0].active_pokemon = dragapult
	state.players[1].active_pokemon = _real_target("Public active", 250, 2)
	state.players[1].bench = [bench_a, bench_b]
	return state


func _terminal_state() -> GameState:
	var state := _game_state()
	var dragapult := _real_slot(_real_card_data(DRAGAPULT_UID), 0)
	dragapult.attached_energy = [_real_instance(FIRE_UID, 0), _real_instance(PSYCHIC_UID, 0)]
	var bench_a := _real_target("Public 30 HP single A", 70, 1)
	var bench_b := _real_target("Public 30 HP single B", 70, 1)
	bench_a.damage_counters = 40
	bench_b.damage_counters = 40
	state.players[0].active_pokemon = dragapult
	state.players[1].active_pokemon = _real_target("Public 200 HP single", 200, 1)
	state.players[1].bench = [bench_a, bench_b]
	return state


func _search_reset_state() -> GameState:
	var state := _game_state()
	state.players[0].active_pokemon = _real_slot(_real_card_data(DREEPY_UID), 0)
	state.players[1].active_pokemon = _real_target("Public search target", 100, 1)
	state.players[0].hand = [
		_real_instance(POFFIN_UID, 0),
		_real_instance(RESEARCH_UID, 0),
		_real_instance(DRAGAPULT_UID, 0),
	]
	state.players[0].deck = [
		_real_instance(DREEPY_UID, 0),
		_real_instance(DREEPY_UID, 0),
		_real_instance(DRAKLOAK_UID, 0),
	]
	for index: int in 10:
		state.players[0].deck.append(_filler_instance("VISIBLE_DRAW_%d" % index, 0))
	return state


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
		"proof_reason": "focused_public_state_fixture_with_fail_closed_boundaries",
		"negative_boundaries": negative_boundaries.duplicate(),
		"passed": passed,
	}


func _round00_summary() -> Dictionary:
	if not FileAccess.file_exists(ROUND00_PATH):
		return {"artifact_exists": false, "status": "missing"}
	var round00 := _load_json(ROUND00_PATH)
	var reports: Array = round00.get("reports", []) if round00.get("reports", []) is Array else []
	if reports.is_empty() or not (reports[0] is Dictionary):
		return {"artifact_exists": true, "status": "unreadable_report"}
	var report: Dictionary = reports[0]
	return {
		"artifact_exists": true,
		"artifact": ROUND00_PATH,
		"status": "existing_exploratory_round00_not_formal",
		"games": int(report.get("games", 0)),
		"rule_win_rate": float(report.get("rule_win_rate", 0.0)),
		"v18cpg_win_rate": float(report.get("v18cpg_win_rate", 0.0)),
		"paired_improvement": float(report.get("paired_improvement", 0.0)),
		"model_calls": int(report.get("model_calls", 0)),
		"model_accepted": int(report.get("model_accepted", 0)),
		"model_acceptance_rate": float(report.get("model_acceptance_rate", 0.0)),
		"turn_visible_wait_p95_ms": float(report.get("turn_visible_wait_p95_ms", 0.0)),
		"uncovered_events": int(report.get("uncovered_events", 0)),
	}


func _write_report() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT_PATH.get_base_dir()))
	var report := {
		"schema_version": 1,
		"architecture": "V18CPG",
		"semantic_schema": "v18cpg-2",
		"transport_contract_version": 3,
		"deck_id": DECK_ID,
		"deck_name": "18.0 多龙巴鲁托",
		"strategy_id": str(_profile.get("strategy_id", "")),
		"profile_version": int(_profile.get("profile_version", 0)),
		"baseline": _round00_summary(),
		"scope": "focused scenario proof only; no formal or real-model run was started",
		"scenario_count": _rows.size(),
		"passed_count": _rows.filter(func(row: Dictionary) -> bool: return bool(row.get("passed", false))).size(),
		"all_passed": _failures.is_empty() and _rows.size() == 5,
		"production_status": "scenario_contract_ready_not_promoted",
		"scenarios": _rows,
		"known_production_gaps": [
			"The existing five-game round00 tied Rule at 20% and is retained only as exploratory baseline evidence.",
			"The current model acceptance was 1/32; these fixtures do not claim that transport or latency has been repaired.",
			"Phantom Dive's real interaction exposes exactly six Bench counters, but a production per-target prize-map certificate remains a separate implementation task.",
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
