extends SceneTree

const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const SemanticCompilerScript = preload("res://scripts/ai/v18_cpg/semantics/V18CPGDeckSemanticCompiler.gd")
const RouteSearchScript = preload("res://scripts/ai/v18_cpg/planning/V18CPGRouteSearch.gd")
const CapabilityRegistryScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCapabilityRegistry.gd")
const MaterialDeltaScript = preload("res://scripts/ai/v18_cpg/observation/V18CPGMaterialDelta.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")

const DECK_ID := 800018359
const DECK_SEED_PATH := "res://data/bundled_user/decks/800018359.json"
const MANIFEST_PATH := "res://scripts/ai/v18_cpg/profiles/generated_semantic_manifests/800018359.json"
const ROUND00_PATH := "res://tmp/v18cpg/optimization21/800018359/round00.json"
const REPORT_PATH := "res://tmp/v18cpg/optimization21/800018359/complex_decision_scenarios.json"

const PIDGEY_UID := "151C_016"
const PIDGEOT_UID := "CSV4C_101"
const GARGANACL_UID := "CSV4C_074"
const PAL_PAD_UID := "CSV1C_111"
const TEAM_STAR_GRUNT_UID := "CSV2C_125"
const BOSS_UID := "CSVH1aC_023"
const ARVEN_UID := "CSV1C_123"
const IONO_UID := "CSV3C_123"
const RARE_CANDY_UID := "CSVH1C_045"
const FIGHTING_UID := "CSVE1C_FIG"
const MIST_UID := "CSV7C_204"

var _profile: Dictionary = {}
var _manifest: Dictionary = {}
var _deck_seed: Dictionary = {}
var _round00: Dictionary = {}
var _current_fingerprint := ""
var _failures: Array[String] = []
var _rows: Array[Dictionary] = []


func _initialize() -> void:
	_profile = ProfileCatalogScript.get_profile_for_deck(DECK_ID)
	_manifest = _load_json(MANIFEST_PATH)
	_deck_seed = _load_json(DECK_SEED_PATH)
	_round00 = _load_json_if_exists(ROUND00_PATH)
	var deck := DeckData.from_dict(_deck_seed)
	_current_fingerprint = SemanticCompilerScript.deck_content_fingerprint(deck)
	_check(int(_profile.get("deck_id", 0)) == DECK_ID, "production Pidgeot control profile must load")
	_check(int(_manifest.get("deck_id", 0)) == DECK_ID, "Pidgeot control semantic manifest must load")
	_check(_profile.get("modules", []) == ["control_recycle", "stage2_chain", "cycle_pivot"],
		"scenarios must use the production recycle/stage2/pivot module composition")
	_check(int(deck.id) == DECK_ID and int(deck.total_cards) == 60,
		"current bundled AI seed must be the exact 60-card deck")
	_check(_current_fingerprint != ""
		and _current_fingerprint == str(_manifest.get("deck_content_fingerprint", "")),
		"semantic manifest fingerprint must match the current bundled AI deck")
	_check(not _round00_matches_current_bundled_ai(),
		"legacy round00 without exact bundled_ai provenance must not be reused")

	_scenario_a_candy_pidgeot_then_quick_search()
	_scenario_b_pal_pad_quick_search_control_loop()
	_scenario_c_free_retreat_preserves_garganacl_attack_energy()
	_scenario_d_iono_before_quick_search()
	_scenario_e_garganacl_one_card_deckout_lock()
	_write_report()

	EffectProcessor.cleanup_live_instances_for_tests()
	if _failures.is_empty() and _rows.size() == 5:
		print("optimization21 800018359 complex decision scenarios: PASS (5/5)")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("optimization21 800018359 complex decision scenarios: FAIL (%d)" % _failures.size())
	quit(1)


func _scenario_a_candy_pidgeot_then_quick_search() -> void:
	var processor := EffectProcessor.new()
	var state := _game_state()
	var pidgey := _real_slot(PIDGEY_UID, 0)
	pidgey.turn_played = 2
	var second_pidgeot := _real_slot(PIDGEOT_UID, 0)
	state.players[0].active_pokemon = pidgey
	state.players[0].bench = [second_pidgeot]
	state.players[1].active_pokemon = _real_target("Public evolution target", 250, 2)
	var candy := _real_instance(RARE_CANDY_UID, 0)
	var pidgeot_card := _real_instance(PIDGEOT_UID, 0)
	var pal_pad := _real_instance(PAL_PAD_UID, 0)
	state.players[0].hand = [candy, pidgeot_card]
	state.players[0].deck = [pal_pad, _filler_instance("VISIBLE_SEARCH_FILLER", 0)]

	var validator := RuleValidator.new()
	var direct_stage2_blocked := not validator.can_evolve(state, 0, pidgey, pidgeot_card, processor)
	var candy_effect := processor.get_effect(candy.card_data.effect_id)
	var steps: Array = candy_effect.get_interaction_steps(candy, state) if candy_effect != null else []
	var stage2_step := _step(steps, "stage2_card")
	var target_step := _step(steps, "target_pokemon")
	var exact_candy_scope := pidgeot_card in (stage2_step.get("items", []) as Array) \
		and pidgey in (target_step.get("items", []) as Array)
	var evolved := processor.execute_card_effect(candy, [{
		"stage2_card": [pidgeot_card],
		"target_pokemon": [pidgey],
	}], state)
	processor.register_pokemon_card(pidgey.get_card_data())
	processor.register_pokemon_card(second_pidgeot.get_card_data())
	var quick_effect := processor.get_ability_effect(pidgey, 0, state)
	var quick_steps: Array = quick_effect.get_interaction_steps(pidgey.get_top_card(), state) \
		if quick_effect != null else []
	var quick_step := _step(quick_steps, "search_cards")
	var full_deck_exact_one := str(quick_step.get("visible_scope", "")) == "own_full_deck" \
		and int(quick_step.get("max_select", -1)) == 1 \
		and pal_pad in (quick_step.get("items", []) as Array)
	var searched := processor.execute_ability_effect(
		pidgey, 0, [{"search_cards": [pal_pad]}], state)
	var shared_once := not processor.can_use_ability(second_pidgeot, state, 0)

	var fresh_state := _game_state()
	var fresh_pidgey := _real_slot(PIDGEY_UID, 0)
	fresh_pidgey.turn_played = fresh_state.turn_number
	fresh_state.players[0].active_pokemon = fresh_pidgey
	var fresh_candy := _real_instance(RARE_CANDY_UID, 0)
	fresh_state.players[0].hand = [fresh_candy, _real_instance(PIDGEOT_UID, 0)]
	var fresh_root_blocked := candy_effect != null and not candy_effect.can_execute(fresh_candy, fresh_state)

	var observation := _observation([
		_evolve("evolve:candy-pidgeot", PIDGEOT_UID, "slot:pidgey"),
		_end_turn("end:without-pidgeot"),
	], _slot("slot:pidgey", PIDGEY_UID, [], 0), [], 8, 6, 12)
	var facts := _facts(false, false, false, 2, false, false, 0, 6)
	var frontier := _frontier(observation, {
		"evolve:candy-pidgeot": 620.0,
		"end:without-pidgeot": -900.0,
	}, facts, "evolve:candy-pidgeot")
	var annotation := _module(_candidate(frontier, "evolve:candy-pidgeot"), "stage2_chain")
	var stage2_contract: bool = bool(annotation.get("evolution_progress", false)) \
		and "resolve_stage2_dependency_order" in annotation.get("decision_hints", [])

	var passed: bool = direct_stage2_blocked and exact_candy_scope and evolved \
		and pidgey.get_card_data().get_uid() == PIDGEOT_UID \
		and full_deck_exact_one and searched and pal_pad in state.players[0].hand \
		and shared_once and fresh_root_blocked and stage2_contract
	_check(passed, "scenario A must Candy an old Pidgey, then Quick Search exactly one card with shared once-per-turn: %s" % JSON.stringify({
		"direct_stage2_blocked": direct_stage2_blocked,
		"exact_candy_scope": exact_candy_scope,
		"evolved": evolved,
		"top_uid": pidgey.get_card_data().get_uid(),
		"full_deck_exact_one": full_deck_exact_one,
		"searched": searched,
		"shared_once": shared_once,
		"fresh_root_blocked": fresh_root_blocked,
		"stage2_contract": stage2_contract,
	}))
	_rows.append(_row(
		"candy_pidgeot_then_quick_search",
		"进化与大比鸟搜索",
		"旧波波先通过神奇糖果进化为大比鸟ex，再用音速搜索从完整牌库精确拿朋友手册。",
		"Rare Candy(Pidgeot ex) -> Quick Search(Pal Pad)",
		["不能普通跨阶进化", "本回合刚下场的波波不能使用糖果", "同名音速搜索全场每回合共享一次"],
		passed
	))


func _scenario_b_pal_pad_quick_search_control_loop() -> void:
	var processor := EffectProcessor.new()
	var state := _game_state()
	var pidgeot := _real_slot(PIDGEOT_UID, 0)
	state.players[0].active_pokemon = pidgeot
	state.players[1].active_pokemon = _real_target("Public control target", 220, 2)
	var pad := _real_instance(PAL_PAD_UID, 0)
	var grunt := _real_instance(TEAM_STAR_GRUNT_UID, 0)
	var boss := _real_instance(BOSS_UID, 0)
	var arven := _real_instance(ARVEN_UID, 0)
	var fighting := _real_instance(FIGHTING_UID, 0)
	state.players[0].hand = [pad]
	state.players[0].discard_pile = [grunt, boss, arven, fighting]
	state.players[0].deck = [_filler_instance("VISIBLE_CONTROL_FILLER_A", 0)]
	processor.register_pokemon_card(pidgeot.get_card_data())

	var pad_effect := processor.get_effect(pad.card_data.effect_id)
	var steps: Array = pad_effect.get_interaction_steps(pad, state) if pad_effect != null else []
	var return_step := _step(steps, "supporters_to_return")
	var supporters_only := int(return_step.get("min_select", 0)) == 1 \
		and int(return_step.get("max_select", -1)) == 2 \
		and grunt in (return_step.get("items", []) as Array) \
		and boss in (return_step.get("items", []) as Array) \
		and arven in (return_step.get("items", []) as Array) \
		and fighting not in (return_step.get("items", []) as Array)
	var returned := processor.execute_card_effect(
		pad, [{"supporters_to_return": [grunt, boss, arven]}], state)
	var exactly_two_returned := grunt in state.players[0].deck and boss in state.players[0].deck \
		and arven in state.players[0].discard_pile and fighting in state.players[0].discard_pile
	var oversized_capped := exactly_two_returned

	var quick_effect := processor.get_ability_effect(pidgeot, 0, state)
	var quick_steps: Array = quick_effect.get_interaction_steps(pidgeot.get_top_card(), state) \
		if quick_effect != null else []
	var quick_step := _step(quick_steps, "search_cards")
	var recycled_grunt_visible := grunt in (quick_step.get("items", []) as Array)
	var searched := processor.execute_ability_effect(
		pidgeot, 0, [{"search_cards": [grunt]}], state)
	var loop_restored := searched and grunt in state.players[0].hand \
		and boss in state.players[0].deck and arven in state.players[0].discard_pile

	var empty_state := _game_state()
	var empty_pad := _real_instance(PAL_PAD_UID, 0)
	empty_state.players[0].discard_pile = [_real_instance(FIGHTING_UID, 0)]
	var empty_blocked := pad_effect != null and not pad_effect.can_execute(empty_pad, empty_state)

	var observation := _observation([
		_play_trainer("item:pal-pad-loop", PAL_PAD_UID, true),
		_ability("ability:quick-search-before-recycle", "slot:pidgeot", PIDGEOT_UID, true),
	], _slot("slot:pidgeot", PIDGEOT_UID, [], 0), [], 8, 6, 6)
	observation["own"]["discard"] = [_card(TEAM_STAR_GRUNT_UID), _card(BOSS_UID), _card(ARVEN_UID)]
	var facts := _facts(true, false, false, 1, true, false, 120, 6)
	var frontier := _frontier(observation, {
		"item:pal-pad-loop": 650.0,
		"ability:quick-search-before-recycle": 610.0,
	}, facts, "item:pal-pad-loop")
	var recycle := _module(_candidate(frontier, "item:pal-pad-loop"), "control_recycle")
	var recycle_contract: bool = bool(recycle.get("non_damage_victory_live", false)) \
		and "measure_both_deck_clocks" in recycle.get("decision_hints", []) \
		and "preserve_recovery_loop" in recycle.get("decision_hints", [])

	var passed: bool = supporters_only and oversized_capped and returned and exactly_two_returned \
		and recycled_grunt_visible and loop_restored and empty_blocked and recycle_contract
	_check(passed, "scenario B must recycle exactly two Supporters and tutor the required control piece: %s" % JSON.stringify({
		"supporters_only": supporters_only,
		"oversized_capped": oversized_capped,
		"returned": returned,
		"exactly_two_returned": exactly_two_returned,
		"recycled_grunt_visible": recycled_grunt_visible,
		"loop_restored": loop_restored,
		"empty_blocked": empty_blocked,
		"recycle_contract": recycle_contract,
	}))
	_rows.append(_row(
		"pal_pad_quick_search_control_loop",
		"控制回收",
		"朋友手册只回收两张公开支援者，再由音速搜索拿回闪焰队手下，保留另一张支援者作为后续循环。",
		"Pal Pad(Team Star Grunt + Boss) -> Quick Search(Team Star Grunt)",
		["能量不能被朋友手册回收", "即使交互提交三张支援者，真实效果也只处理前两张", "弃牌区没有支援者时不能空放朋友手册"],
		passed
	))


func _scenario_c_free_retreat_preserves_garganacl_attack_energy() -> void:
	var gsm := GameStateMachine.new()
	gsm.game_state = _game_state()
	var state := gsm.game_state
	var pidgeot := _real_slot(PIDGEOT_UID, 0)
	var garganacl := _real_slot(GARGANACL_UID, 0)
	var first_fighting := _real_instance(FIGHTING_UID, 0)
	var second_fighting := _real_instance(FIGHTING_UID, 0)
	garganacl.attached_energy = [first_fighting]
	state.players[0].active_pokemon = pidgeot
	state.players[0].bench = [garganacl]
	state.players[0].hand = [second_fighting]
	state.players[1].active_pokemon = _real_target("Public retreat target", 220, 2)
	gsm.effect_processor.register_pokemon_card(garganacl.get_card_data())
	var free_retreat := gsm.retreat(0, [], garganacl)
	var no_discard := state.players[0].discard_pile.is_empty()
	var attached := gsm.attach_energy(0, second_fighting, garganacl)
	var attack_ready := RuleValidator.new().can_use_attack(state, 0, 0, gsm.effect_processor)

	var locked_gsm := GameStateMachine.new()
	locked_gsm.game_state = _game_state()
	var locked_state := locked_gsm.game_state
	var locked_garganacl := _real_slot(GARGANACL_UID, 0)
	var locked_fighting_a := _real_instance(FIGHTING_UID, 0)
	var locked_fighting_b := _real_instance(FIGHTING_UID, 0)
	locked_garganacl.attached_energy = [locked_fighting_a, locked_fighting_b]
	var locked_pidgeot := _real_slot(PIDGEOT_UID, 0)
	locked_state.players[0].active_pokemon = locked_garganacl
	locked_state.players[0].bench = [locked_pidgeot]
	locked_state.players[1].active_pokemon = _real_target("Public locked target", 220, 2)
	locked_gsm.effect_processor.register_pokemon_card(locked_garganacl.get_card_data())
	var empty_payment_blocked := not locked_gsm.retreat(0, [], locked_pidgeot)
	var two_payment_blocked := not locked_gsm.retreat(
		0, [locked_fighting_a, locked_fighting_b], locked_pidgeot)
	var attack_energy_preserved := locked_garganacl.attached_energy.size() == 2 \
		and locked_state.players[0].discard_pile.is_empty() \
		and RuleValidator.new().can_use_attack(locked_state, 0, 0, locked_gsm.effect_processor)

	var wrong_state := _game_state()
	var wrong_garganacl := _real_slot(GARGANACL_UID, 0)
	wrong_garganacl.attached_energy = [
		_real_instance(FIGHTING_UID, 0),
		_real_instance(MIST_UID, 0),
	]
	wrong_state.players[0].active_pokemon = wrong_garganacl
	wrong_state.players[1].active_pokemon = _real_target("Public typed target", 220, 2)
	var wrong_processor := EffectProcessor.new()
	wrong_processor.register_pokemon_card(wrong_garganacl.get_card_data())
	var mist_does_not_pay_ff := not RuleValidator.new().can_use_attack(
		wrong_state, 0, 0, wrong_processor)

	var active_snapshot := _slot("slot:pidgeot", PIDGEOT_UID, [], 0)
	active_snapshot["attack_ready"] = false
	active_snapshot["attack_locked"] = false
	active_snapshot["max_damage"] = 0
	var target_snapshot := _slot("slot:garganacl", GARGANACL_UID, [_fighting_energy()], 130)
	var observation := _observation([
		_retreat("retreat:pidgeot-to-garganacl", "slot:garganacl"),
		_end_turn("end:leave-pidgeot-active"),
	], active_snapshot, [target_snapshot], 8, 6, 12)
	var facts := _facts(false, false, true, 1, false, false, 0, 6)
	facts["route"]["current_valid"] = false
	var frontier := _frontier(observation, {
		"retreat:pidgeot-to-garganacl": 700.0,
		"end:leave-pidgeot-active": -500.0,
	}, facts, "retreat:pidgeot-to-garganacl")
	var pivot := _module(_candidate(frontier, "retreat:pidgeot-to-garganacl"), "cycle_pivot")
	var pivot_snapshot: Dictionary = pivot.get("pivot", {}) if pivot.get("pivot", {}) is Dictionary else {}
	var pivot_contract := str(pivot.get("route_id", "")) == "route:pivot" \
		and not bool(pivot_snapshot.get("active_attack_ready", true)) \
		and int(pivot_snapshot.get("target_damage", 0)) == 130

	var passed := free_retreat and no_discard and attached and attack_ready \
		and empty_payment_blocked and two_payment_blocked and attack_energy_preserved \
		and mist_does_not_pay_ff and pivot_contract
	_check(passed, "scenario C must exploit Pidgeot's free retreat without spending Garganacl's exact FF attack payment: %s" % JSON.stringify({
		"free_retreat": free_retreat,
		"no_discard": no_discard,
		"attached": attached,
		"attack_ready": attack_ready,
		"empty_payment_blocked": empty_payment_blocked,
		"two_payment_blocked": two_payment_blocked,
		"attack_energy_preserved": attack_energy_preserved,
		"mist_does_not_pay_ff": mist_does_not_pay_ff,
		"pivot_contract": pivot_contract,
	}))
	_rows.append(_row(
		"free_retreat_preserves_garganacl_attack_energy",
		"能量与撤退管理",
		"利用大比鸟ex零撤退把一斗能盐石巨灵推到战斗场，再手贴第二斗能形成FF攻击，不浪费已就绪攻击能量。",
		"free retreat Pidgeot ex -> attach Fighting to Garganacl -> Knocking Hammer",
		["盐石巨灵撤退费用为3，不能用0张能量撤退", "两张斗能仍不足以支付3撤退", "斗能加薄雾能量不能支付FF"],
		passed
	))


func _scenario_d_iono_before_quick_search() -> void:
	var positive := _iono_search_state()
	var processor: EffectProcessor = positive.get("processor")
	var state: GameState = positive.get("state")
	var pidgeot: PokemonSlot = positive.get("pidgeot")
	var iono: CardInstance = positive.get("iono")
	var pal_pad: CardInstance = positive.get("pal_pad")

	var before := _observation([
		_play_trainer("supporter:iono-before-search", IONO_UID, false),
		_ability("ability:quick-search-before-iono", "slot:pidgeot", PIDGEOT_UID, true),
	], _slot("slot:pidgeot", PIDGEOT_UID, [], 120), [], 8, 2, 6)
	before["observation_hash"] = "pidgeot-control-before-iono"
	before["own"]["hand"] = [_card(IONO_UID), {"uid": "VISIBLE_STALE_HAND"}]
	var facts_before := _facts(true, false, false, 2, false, false, 120, 2)
	var frontier := _frontier(before, {
		"supporter:iono-before-search": 690.0,
		"ability:quick-search-before-iono": 640.0,
	}, facts_before, "supporter:iono-before-search")
	var iono_candidate := _candidate(frontier, "supporter:iono-before-search")

	var iono_executed := processor.execute_card_effect(iono, [], state)
	var reset_drew_exactly_two := state.players[0].hand.size() == 2 \
		and pal_pad in state.players[0].deck
	var after := before.duplicate(true)
	after["observation_version"] = 2
	after["observation_hash"] = "pidgeot-control-after-iono"
	after["own"]["hand"] = [{"uid": "VISIBLE_DRAW_A"}, {"uid": "VISIBLE_DRAW_B"}]
	after["own"]["deck_count"] = state.players[0].deck.size()
	after["legal_actions"] = [
		_ability("ability:quick-search-after-iono", "slot:pidgeot", PIDGEOT_UID, true),
	]
	var facts_after := _facts(true, false, false, 2, false, false, 120, 2)
	var reopened := _epoch_reopens(before, after, facts_before, facts_after, iono_candidate, frontier)
	var quick_effect := processor.get_ability_effect(pidgeot, 0, state)
	var quick_steps: Array = quick_effect.get_interaction_steps(pidgeot.get_top_card(), state) \
		if quick_effect != null else []
	var quick_scope := str(_step(quick_steps, "search_cards").get("visible_scope", "")) == "own_full_deck" \
		and pal_pad in (_step(quick_steps, "search_cards").get("items", []) as Array)
	var quick_searched := processor.execute_ability_effect(
		pidgeot, 0, [{"search_cards": [pal_pad]}], state)
	var target_survives := pal_pad in state.players[0].hand \
		and not processor.can_use_ability(pidgeot, state, 0)

	var negative := _iono_search_state()
	var negative_processor: EffectProcessor = negative.get("processor")
	var negative_state: GameState = negative.get("state")
	var negative_pidgeot: PokemonSlot = negative.get("pidgeot")
	var negative_iono: CardInstance = negative.get("iono")
	var negative_pad: CardInstance = negative.get("pal_pad")
	var searched_before_reset := negative_processor.execute_ability_effect(
		negative_pidgeot, 0, [{"search_cards": [negative_pad]}], negative_state)
	var reset_after_search := negative_processor.execute_card_effect(negative_iono, [], negative_state)
	var premature_search_lost := negative_pad not in negative_state.players[0].hand

	var passed := iono_executed and reset_drew_exactly_two and reopened \
		and quick_scope and quick_searched and target_survives \
		and searched_before_reset and reset_after_search and premature_search_lost
	_check(passed, "scenario D must resolve Iono before Quick Search so the exact searched card survives: %s" % JSON.stringify({
		"iono_executed": iono_executed,
		"reset_drew_exactly_two": reset_drew_exactly_two,
		"reopened": reopened,
		"quick_scope": quick_scope,
		"quick_searched": quick_searched,
		"target_survives": target_survives,
		"searched_before_reset": searched_before_reset,
		"reset_after_search": reset_after_search,
		"premature_search_lost": premature_search_lost,
	}))
	_rows.append(_row(
		"iono_before_quick_search",
		"支援者与抽牌顺序",
		"需要奇树换手时先结算奇树，信息状态变化后再用音速搜索拿精确控制牌；反序会把刚搜到的牌放回牌库底。",
		"Iono -> reopen information epoch -> Quick Search(Pal Pad)",
		["不能先音速搜索再奇树", "音速搜索只从公开完整牌库选择", "一次搜索后同回合不可重复使用"],
		passed
	))


func _scenario_e_garganacl_one_card_deckout_lock() -> void:
	var gsm := GameStateMachine.new()
	gsm.game_state = _garganacl_mill_state(1)
	var state := gsm.game_state
	var garganacl: PokemonSlot = state.players[0].active_pokemon
	var defender: PokemonSlot = state.players[1].active_pokemon
	gsm.effect_processor.register_pokemon_card(garganacl.get_card_data())
	var attack_legal := RuleValidator.new().can_use_attack(state, 0, 0, gsm.effect_processor)
	var top_card: CardInstance = state.players[1].deck[0]
	var milled := gsm.effect_processor.execute_attack_effect(garganacl, 0, defender, state)
	var exact_mill := milled and state.players[1].deck.is_empty() \
		and top_card in state.players[1].discard_pile and top_card.face_up
	var no_false_immediate_win := not state.is_game_over()
	gsm.draw_card(1, 1)
	var next_draw_closes := state.is_game_over() and state.winner_index == 0

	var two_gsm := GameStateMachine.new()
	two_gsm.game_state = _garganacl_mill_state(2)
	var two_state := two_gsm.game_state
	var two_garganacl: PokemonSlot = two_state.players[0].active_pokemon
	two_gsm.effect_processor.register_pokemon_card(two_garganacl.get_card_data())
	var two_milled := two_gsm.effect_processor.execute_attack_effect(
		two_garganacl, 0, two_state.players[1].active_pokemon, two_state)
	var one_card_remains := two_milled and two_state.players[1].deck.size() == 1
	var drew_last_card: Array[CardInstance] = two_gsm.draw_card(1, 1)
	var two_card_not_closed := drew_last_card.size() == 1 and not two_state.is_game_over()

	var wrong_state := _garganacl_mill_state(1)
	var wrong_garganacl: PokemonSlot = wrong_state.players[0].active_pokemon
	wrong_garganacl.attached_energy = [
		_real_instance(FIGHTING_UID, 0),
		_real_instance(MIST_UID, 0),
	]
	var wrong_processor := EffectProcessor.new()
	wrong_processor.register_pokemon_card(wrong_garganacl.get_card_data())
	var wrong_payment_blocked := not RuleValidator.new().can_use_attack(
		wrong_state, 0, 0, wrong_processor)

	var observation := _observation([
		_attack("attack:garganacl-deckout", GARGANACL_UID, 0, 130, false),
		_play_trainer("supporter:iono-breaks-lock", IONO_UID, false),
		_ability("ability:quick-search-delays-lock", "slot:pidgeot", PIDGEOT_UID, true),
	], _slot("slot:garganacl", GARGANACL_UID, [_fighting_energy(), _fighting_energy()], 130),
		[_slot("slot:pidgeot", PIDGEOT_UID, [], 120)], 4, 6, 1)
	var facts := _facts(true, false, false, 2, true, true, 130, 6)
	var frontier := _frontier(observation, {
		"attack:garganacl-deckout": 900.0,
		"supporter:iono-breaks-lock": 300.0,
		"ability:quick-search-delays-lock": 250.0,
	}, facts, "attack:garganacl-deckout")
	var attack_candidate := _candidate(frontier, "attack:garganacl-deckout")
	var recycle := _module(attack_candidate, "control_recycle")
	var lock_contract: bool = str(attack_candidate.get("route_id", "")) == "route:attack_pressure" \
		and bool(recycle.get("non_damage_victory_live", false)) \
		and "measure_both_deck_clocks" in recycle.get("decision_hints", [])

	var passed: bool = attack_legal and exact_mill and no_false_immediate_win and next_draw_closes \
		and one_card_remains and two_card_not_closed and wrong_payment_blocked and lock_contract
	_check(passed, "scenario E must mill the public final deck card and close only on the next requested draw: %s" % JSON.stringify({
		"attack_legal": attack_legal,
		"exact_mill": exact_mill,
		"no_false_immediate_win": no_false_immediate_win,
		"next_draw_closes": next_draw_closes,
		"one_card_remains": one_card_remains,
		"two_card_not_closed": two_card_not_closed,
		"wrong_payment_blocked": wrong_payment_blocked,
		"lock_contract": lock_contract,
	}))
	_rows.append(_row(
		"garganacl_one_card_deckout_lock",
		"锁局闭环",
		"对手公开牌库只剩1张时，盐石巨灵用敲打重锤弃掉顶牌；当下不虚报胜利，但对手下一次必须抽牌时确定牌库耗尽。",
		"Knocking Hammer mills final card -> opponent next draw request loses",
		["对手牌库有2张时只弃1张，下一抽仍成功", "斗能加薄雾能量不能发动FF招式", "锁已成立时不先做奇树或音速搜索"],
		passed
	))


func _frontier(
	observation: Dictionary,
	scores: Dictionary,
	facts: Dictionary,
	rule_action_id: String
) -> Array[Dictionary]:
	var pool: Array[Dictionary] = RouteSearchScript.new().build_candidate_pool(
		observation, scores, _manifest, facts)
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


func _observation(
	actions: Array,
	active: Dictionary,
	bench: Array,
	deck_count: int,
	prizes_remaining: int,
	opponent_deck_count: int
) -> Dictionary:
	return {
		"observation_version": 1,
		"observation_hash": "pidgeot-control-complex-scenario",
		"turn": {"deterministic_attack_window_open": true},
		"own": {
			"active": active,
			"bench": bench,
			"hand": [{"uid": "VISIBLE_OWN_HAND_CARD"}],
			"discard": [],
			"deck_count": deck_count,
			"prizes_remaining": prizes_remaining,
		},
		"opponent": {
			"active": _public_target("PUBLIC_OPPONENT_ACTIVE", 220, 2),
			"bench": [],
			"deck_count": opponent_deck_count,
			"prizes_remaining": 6,
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


func _slot(slot_id: String, uid: String, energy: Array, max_damage: int) -> Dictionary:
	var hp := 280 if uid == PIDGEOT_UID else 180 if uid == GARGANACL_UID else 50
	return {
		"slot_id": slot_id,
		"pokemon": _card(uid),
		"tool": {},
		"energy": energy,
		"energy_count": energy.size(),
		"damage": 0,
		"remaining_hp": hp,
		"max_hp": hp,
		"max_damage": max_damage,
		"prize_count": 2 if uid == PIDGEOT_UID else 1,
		"ability_used": false,
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


func _evolve(action_id: String, uid: String, target: String) -> Dictionary:
	return {
		"id": action_id,
		"kind": "evolve",
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


func _retreat(action_id: String, target: String) -> Dictionary:
	return {
		"id": action_id,
		"kind": "retreat",
		"source": "slot:pidgeot",
		"target": target,
		"requires_interaction": false,
	}


func _attack(action_id: String, uid: String, attack_index: int, damage: int, knockout: bool) -> Dictionary:
	return {
		"id": action_id,
		"kind": "attack",
		"source": "slot:garganacl",
		"source_card": _card(uid),
		"attack_index": attack_index,
		"projected_damage": damage,
		"projected_knockout": knockout,
		"requires_interaction": false,
	}


func _end_turn(action_id: String) -> Dictionary:
	return {"id": action_id, "kind": "end_turn"}


func _fighting_energy() -> Dictionary:
	var card := _card(FIGHTING_UID)
	card["energy_type"] = "F"
	card["energy_provides"] = "F"
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


func _game_state(turn: int = 8) -> GameState:
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


func _real_target(name: String, hp: int, prize_count: int) -> PokemonSlot:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = "Pokemon"
	data.stage = "Basic"
	data.hp = hp
	data.mechanic = "ex" if prize_count == 2 else ""
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(data, 1))
	return slot


func _filler_instance(name: String, owner: int) -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = "Item"
	data.set_code = "FIXTURE"
	data.card_index = name
	return CardInstance.create(data, owner)


func _iono_search_state() -> Dictionary:
	var processor := EffectProcessor.new()
	var state := _game_state()
	var pidgeot := _real_slot(PIDGEOT_UID, 0)
	var iono := _real_instance(IONO_UID, 0)
	var pal_pad := _real_instance(PAL_PAD_UID, 0)
	state.players[0].active_pokemon = pidgeot
	state.players[0].hand = [iono, _filler_instance("VISIBLE_STALE_HAND", 0)]
	state.players[0].deck = [
		_filler_instance("VISIBLE_DRAW_A", 0),
		_filler_instance("VISIBLE_DRAW_B", 0),
		pal_pad,
		_filler_instance("VISIBLE_REMAINING_A", 0),
		_filler_instance("VISIBLE_REMAINING_B", 0),
	]
	_fill_prizes(state.players[0], 2, "OWN_IONO_PRIZE")
	_fill_prizes(state.players[1], 2, "OPP_IONO_PRIZE")
	state.players[1].active_pokemon = _real_target("Public Iono target", 250, 2)
	state.players[1].hand = [_filler_instance("OPP_VISIBLE_STALE_HAND", 1)]
	state.players[1].deck = [
		_filler_instance("OPP_DRAW_A", 1),
		_filler_instance("OPP_DRAW_B", 1),
	]
	processor.register_pokemon_card(pidgeot.get_card_data())
	return {
		"processor": processor,
		"state": state,
		"pidgeot": pidgeot,
		"iono": iono,
		"pal_pad": pal_pad,
	}


func _garganacl_mill_state(opponent_deck_count: int) -> GameState:
	var state := _game_state()
	var garganacl := _real_slot(GARGANACL_UID, 0)
	garganacl.attached_energy = [
		_real_instance(FIGHTING_UID, 0),
		_real_instance(FIGHTING_UID, 0),
	]
	state.players[0].active_pokemon = garganacl
	state.players[1].active_pokemon = _real_target("Public non-KO mill target", 300, 2)
	for index: int in opponent_deck_count:
		state.players[1].deck.append(_filler_instance("PUBLIC_OPP_TOP_%d" % index, 1))
	return state


func _fill_prizes(player: PlayerState, count: int, prefix: String) -> void:
	player.prizes.clear()
	for index: int in count:
		player.prizes.append(_filler_instance("%s_%d" % [prefix, index], player.player_index))


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


func _round00_matches_current_bundled_ai() -> bool:
	if _round00.is_empty():
		return false
	var raw_source: Variant = _round00.get("deck_source", {})
	if not (raw_source is Dictionary):
		return false
	var source: Dictionary = raw_source
	return str(source.get("source_kind", "")) == "bundled_ai" \
		and str(source.get("bundled_seed_path", "")) == DECK_SEED_PATH \
		and str(source.get("deck_content_fingerprint", "")) == _current_fingerprint \
		and str(source.get("semantic_manifest_fingerprint", "")) \
			== str(_manifest.get("deck_content_fingerprint", ""))


func _write_report() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT_PATH.get_base_dir()))
	var report := {
		"schema_version": 1,
		"architecture": "V18CPG",
		"semantic_schema": "v18cpg-2",
		"transport_contract_version": 3,
		"deck_id": DECK_ID,
		"deck_name": "18.0 大比鸟控制",
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
			"status": "legacy_round00_excluded_missing_or_mismatched_provenance",
			"required_deck_content_fingerprint": _current_fingerprint,
			"valid_round00_found": false,
			"inspected_artifact": ROUND00_PATH,
			"artifact_exists": FileAccess.file_exists(ROUND00_PATH),
			"accepted_artifact": "",
			"seed_base": DECK_ID,
			"strength_metrics_reused": false,
			"note": "The existing round00 has no matching bundled_ai deck_source/fingerprint/manifest provenance and is excluded from baseline evidence.",
		},
		"scope": "focused scenario preparation only; no real-model formal benchmark",
		"scenario_count": _rows.size(),
		"passed_count": _rows.filter(func(row: Dictionary) -> bool: return bool(row.get("passed", false))).size(),
		"all_passed": _failures.is_empty() and _rows.size() == 5,
		"production_status": "scenario_contract_ready_not_promoted",
		"known_production_gaps": [
			"No deck-local promotion or aggregate win-rate claim is made by these five fixtures.",
			"Rare Candy, Quick Search, Pal Pad, Iono, retreat, typed attack payment, opponent mill, and draw-request deck-out are verified through real engine paths.",
			"The generic recycle/stage2/pivot modules still need bounded production certificates for exact multi-action continuation binding.",
			"A provenance-bearing fingerprint-aligned bundled_ai formal baseline and paired Rule-floor comparison remain separate acceptance work.",
		],
		"isolation": {
			"profile_modified": false,
			"shared_strategy_modified": false,
			"shared_registry_modified": false,
			"shared_strategic_shape_modified": false,
			"rule_or_legacy_or_agent_modified": false,
			"real_model_formal_run": false,
			"hidden_sentinel_absent_from_frontiers": true,
			"invalidated_legacy_evidence_reused": false,
		},
		"coverage": [
			"old Pidgey Rare Candy evolution into Pidgeot ex followed by exact full-deck Quick Search",
			"Pal Pad recycling exactly two Supporters before Quick Search restores the control loop",
			"Pidgeot ex free retreat preserving Garganacl's exact two-Fighting attack payment",
			"Iono hand reset before Quick Search with a material information-epoch reopen",
			"Garganacl milling the public final opposing deck card before the next draw-request deck-out",
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


func _load_json_if_exists(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
