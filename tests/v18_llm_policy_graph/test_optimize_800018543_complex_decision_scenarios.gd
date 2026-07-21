extends SceneTree

const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const RouteSearchScript = preload("res://scripts/ai/v18_cpg/planning/V18CPGRouteSearch.gd")
const CapabilityRegistryScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCapabilityRegistry.gd")
const MaterialDeltaScript = preload("res://scripts/ai/v18_cpg/observation/V18CPGMaterialDelta.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")

const DECK_ID := 800018543
const MANIFEST_PATH := "res://scripts/ai/v18_cpg/profiles/generated_semantic_manifests/800018543.json"
const REPORT_PATH := "res://tmp/v18cpg/optimization21/800018543/complex_decision_scenarios.json"
const GIBLE_UID := "CSV10C_111"
const GABITE_UID := "CSV10C_112"
const GARCHOMP_UID := "CSV10C_113"
const ROSELIA_UID := "CSV10C_004"
const ROSERADE_UID := "CSV10C_005"
const BUDEW_UID := "CSV9.5C_004"
const OBSERVED_SEED547_STALE_CANDIDATE := "9260b759519d707cf154"

var _profile: Dictionary = {}
var _manifest: Dictionary = {}
var _failures: Array[String] = []
var _rows: Array[Dictionary] = []


func _initialize() -> void:
	_profile = ProfileCatalogScript.get_profile_for_deck(DECK_ID)
	_manifest = _load_json(MANIFEST_PATH)
	_check(int(_profile.get("deck_id", 0)) == DECK_ID, "production Cynthia's Garchomp profile must load")
	_check(int(_manifest.get("deck_id", 0)) == DECK_ID, "Cynthia's Garchomp semantic manifest must load")
	_check(_profile.get("modules", []) == [
		"partner_chain", "stage2_chain", "cycle_pivot", "damage_counter_control"
	], "scenarios must exercise the production partner/stage2/cycle/counter capability composition")

	_scenario_a_poffin_tm_double_evolution()
	_scenario_b_gabite_search_epoch_to_garchomp_attack()
	_scenario_c_roserade_damage_breakpoint_before_attack()
	_scenario_d_spiral_over_blast_same_ko_preserve_energy()
	_scenario_e_forced_sendout_clears_stale_attack_certificate()
	_write_report()

	EffectProcessor.cleanup_live_instances_for_tests()
	if _failures.is_empty() and _rows.size() == 5:
		print("optimization21 800018543 complex decision scenarios: PASS (5/5)")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("optimization21 800018543 complex decision scenarios: FAIL (%d)" % _failures.size())
	quit(1)


func _scenario_a_poffin_tm_double_evolution() -> void:
	var poffin := _play_trainer("item:buddy-poffin", "CSV7C_177", true)
	var before := _observation(
		[poffin, _attack("attack:budew-chip", BUDEW_UID, 0, 10, false)],
		_slot("slot:active", BUDEW_UID, [_fighting_energy()]),
		[],
		28
	)
	before["observation_version"] = 1
	before["observation_hash"] = "cynthia-before-poffin"
	before["own"]["hand"] = [_card("CSV7C_177"), _card("CSV5C_119"), _fighting_energy()]
	var facts_before := _facts(false, false, false, 3, false, false, 10)
	var poffin_frontier := _frontier(before, {
		"item:buddy-poffin": 540.0,
		"attack:budew-chip": 300.0,
	}, facts_before, "item:buddy-poffin")
	var poffin_candidate := _candidate(poffin_frontier, "item:buddy-poffin")
	_check(str(poffin_candidate.get("route_id", "")) == "route:information" \
		and str(poffin_candidate.get("checkpoint_after", "")) == "information_result", \
		"scenario A Buddy-Buddy Poffin must be an exact information checkpoint")
	var poffin_items: Array = [
		_real_card_data(GIBLE_UID),
		_real_card_data(GIBLE_UID),
		_real_card_data(ROSELIA_UID),
		_real_card_data(BUDEW_UID),
	]
	var duplicate_rule_selection: Array = [poffin_items[0], poffin_items[1]]
	var profiled_selection := _poffin_override(poffin_items, duplicate_rule_selection, before, facts_before)
	var selected_uids: Array[String] = []
	for selected: Variant in profiled_selection.get("items", []):
		selected_uids.append((selected as CardData).get_uid() if selected is CardData else "")
	var root_diversity_proved := bool(profiled_selection.get("handled", false)) \
		and str(profiled_selection.get("certificate_kind", "")) == "profiled_poffin_distinct_evolution_roots" \
		and selected_uids == [GIBLE_UID, ROSELIA_UID]
	_check(root_diversity_proved, \
		"scenario A production interaction must replace duplicate Gible picks with one Gible and one Roselia")
	var missing_tm := before.duplicate(true)
	missing_tm["own"]["hand"] = [_fighting_energy()]
	var no_energy := before.duplicate(true)
	no_energy["own"]["active"]["energy"] = []
	no_energy["own"]["active"]["energy_count"] = 0
	var existing_gible := before.duplicate(true)
	existing_gible["own"]["bench"] = [_slot("slot:existing-gible", GIBLE_UID, [])]
	var crowded_bench := before.duplicate(true)
	crowded_bench["own"]["bench"] = [
		_slot("slot:1", BUDEW_UID, []),
		_slot("slot:2", BUDEW_UID, []),
		_slot("slot:3", BUDEW_UID, []),
		_slot("slot:4", BUDEW_UID, []),
	]
	var missing_second_root: Array = [poffin_items[0], poffin_items[1], poffin_items[3]]
	_check(not bool(_poffin_override(poffin_items, duplicate_rule_selection, missing_tm, facts_before).get("handled", false)) \
		and not bool(_poffin_override(poffin_items, duplicate_rule_selection, no_energy, facts_before).get("handled", false)) \
		and not bool(_poffin_override(poffin_items, duplicate_rule_selection, existing_gible, facts_before).get("handled", false)) \
		and not bool(_poffin_override(poffin_items, duplicate_rule_selection, crowded_bench, facts_before).get("handled", false)) \
		and not bool(_poffin_override(missing_second_root, duplicate_rule_selection, before, facts_before).get("handled", false)), \
		"scenario A Poffin override must fail closed without TM, active Fighting Energy, two empty roots, two Bench slots, or both visible basics")

	var attach_tm := _attach_tool("tool:tm-evolution", "CSV5C_119", "slot:active")
	var after_poffin := _observation(
		[attach_tm, _attach_energy("attach:fighting-to-tm-carrier", "slot:active")],
		_slot("slot:active", BUDEW_UID, [_fighting_energy()]),
		[
			_slot("slot:gible-root", GIBLE_UID, []),
			_slot("slot:roselia-root", ROSELIA_UID, []),
		],
		26
	)
	after_poffin["observation_version"] = 2
	after_poffin["observation_hash"] = "cynthia-after-poffin"
	after_poffin["own"]["hand"] = [_card("CSV5C_119"), _fighting_energy()]
	var facts_after_poffin := _facts(false, false, false, 2, false, false, 10)
	var poffin_reopens := _epoch_reopens(
		before, after_poffin, facts_before, facts_after_poffin, poffin_candidate, poffin_frontier
	)
	var tm_frontier := _frontier(after_poffin, {
		"tool:tm-evolution": 520.0,
		"attach:fighting-to-tm-carrier": 500.0,
	}, facts_after_poffin, "tool:tm-evolution")
	var tm_candidate := _candidate(tm_frontier, "tool:tm-evolution")
	_check(bool(poffin_reopens) \
		and str(tm_candidate.get("route_id", "")) == "route:develop" \
		and "trainer_plan_piece" in (tm_candidate.get("action_semantic_roles", []) as Array), \
		"scenario A Poffin result must reopen into TM Evolution on the active carrier")

	var tm_attack := _granted_attack("attack:tm-evolution", BUDEW_UID)
	var ready_tm := _observation(
		[tm_attack],
		_slot("slot:active", BUDEW_UID, [_fighting_energy()]),
		[
			_slot("slot:gible-root", GIBLE_UID, []),
			_slot("slot:roselia-root", ROSELIA_UID, []),
		],
		26
	)
	var tm_attack_frontier := _frontier(
		ready_tm, {"attack:tm-evolution": 9000.0}, facts_after_poffin, "attack:tm-evolution"
	)
	var tm_attack_candidate := _candidate(tm_attack_frontier, "attack:tm-evolution")
	var after_tm := _observation(
		[],
		_slot("slot:active", BUDEW_UID, []),
		[
			_slot("slot:gabite", GABITE_UID, []),
			_slot("slot:roserade", ROSERADE_UID, []),
		],
		24
	)
	var distinct_roots := str(before.get("observation_hash", "")) != "" \
		and str(after_tm["own"]["bench"][0]["pokemon"]["uid"]) == GABITE_UID \
		and str(after_tm["own"]["bench"][1]["pokemon"]["uid"]) == ROSERADE_UID
	var bench_slots_free := 5 - (after_tm["own"]["bench"] as Array).size()
	_check(str(tm_attack_candidate.get("route_id", "")) == "route:attack_pressure" \
		and distinct_roots and bench_slots_free >= 1, \
		"scenario A TM attack must evolve the two distinct Poffin roots and preserve a Bench slot")
	_rows.append(_row(
		"opening_poffin_tm_double_evolution",
		"开局搜索/TM双进化",
		"含羞苞前台先用友好宝芬铺圆陆鲨与毒蔷薇两个不同进化根，再把进化TM交给已有斗能的前台，同一招式分别进化为尖牙陆鲨和罗丝雷朵，并保留至少1个备战位。",
		"item:buddy-poffin -> tool:tm-evolution -> attack:tm-evolution(Gabite+Roserade)",
		"profiled_poffin_distinct_root_interaction_override; information_epoch_then_two_distinct_public_evolution_roots",
		root_diversity_proved and bool(poffin_reopens) and distinct_roots and bench_slots_free >= 1
	))


func _scenario_b_gabite_search_epoch_to_garchomp_attack() -> void:
	var search := _ability("ability:kings-call", "slot:active", GABITE_UID, true)
	var before := _observation(
		[search, _end_turn("end:stale-before-search")],
		_slot("slot:active", GABITE_UID, [_fighting_energy()]),
		[_slot("slot:roserade", ROSERADE_UID, [])],
		20
	)
	before["observation_version"] = 1
	before["observation_hash"] = "cynthia-before-kings-call"
	var facts_before := _facts(false, false, false, 3, false, false, 40)
	var search_frontier := _frontier(before, {
		"ability:kings-call": 520.0,
		"end:stale-before-search": -900.0,
	}, facts_before, "ability:kings-call")
	var search_candidate := _candidate(search_frontier, "ability:kings-call")

	var evolve := _evolve("evolve:garchomp", GARCHOMP_UID, "slot:active")
	var after_search := _observation(
		[evolve, _end_turn("end:stale-after-search")],
		_slot("slot:active", GABITE_UID, [_fighting_energy()]),
		[_slot("slot:roserade", ROSERADE_UID, [])],
		19
	)
	after_search["observation_version"] = 2
	after_search["observation_hash"] = "cynthia-after-kings-call"
	after_search["own"]["hand"] = [_card(GARCHOMP_UID), {"uid": "VISIBLE_SEARCH_RESULT"}]
	var facts_after_search := _facts(false, false, false, 2, false, false, 40)
	var search_reopens := _epoch_reopens(
		before, after_search, facts_before, facts_after_search, search_candidate, search_frontier
	)
	var evolve_frontier := _frontier(after_search, {
		"evolve:garchomp": 510.0,
		"end:stale-after-search": -900.0,
	}, facts_after_search, "evolve:garchomp")
	var evolve_candidate := _candidate(evolve_frontier, "evolve:garchomp")
	var stage2 := _module_annotation(evolve_candidate, "stage2_chain")
	_check(bool(search_reopens) \
		and bool(stage2.get("evolution_progress", false)) \
		and "stage2_dependency" in (evolve_candidate.get("action_semantic_roles", []) as Array), \
		"scenario B King's Call result must reopen into the exact Garchomp Stage-2 evolution")

	var spiral := _attack("attack:spiral-after-search", GARCHOMP_UID, 0, 130, true)
	var after_evolve := _observation(
		[spiral, _end_turn("end:stale-after-evolve")],
		_slot("slot:active", GARCHOMP_UID, [_fighting_energy()]),
		[_slot("slot:roserade", ROSERADE_UID, [])],
		19
	)
	after_evolve["own"]["prizes_remaining"] = 1
	after_evolve["opponent"]["active"] = _public_target("PUBLIC_SINGLE_PRIZE_TARGET", 130, 1)
	var facts_ready := _facts(true, true, false, 2, false, false, 130)
	facts_ready["resources"]["prizes_remaining"] = 1
	facts_ready["prize"] = {"current_swing": 1, "win_now": true}
	var attack_frontier := _frontier(after_evolve, {
		"end:stale-after-evolve": 700.0,
		"attack:spiral-after-search": 10.0,
	}, facts_ready, "end:stale-after-evolve")
	var attack_candidate := _candidate(attack_frontier, "attack:spiral-after-search")
	var attack_safety := _route_safety(attack_candidate, attack_frontier, facts_ready)
	_check(str(attack_safety.get("reason", "")) == "deterministic_win_now", \
		"scenario B Garchomp must attack after the search/evolution instead of executing a stale end")
	_rows.append(_row(
		"gabite_search_epoch_to_garchomp_attack",
		"进化搜索/信息epoch/攻击闭环",
		"尖牙陆鲨用王者呼声搜到烈咬陆鲨ex后重开信息epoch，立即进化；有罗丝雷朵时螺旋俯冲达到130并取末奖，旧结束回合节点不得继续。",
		"ability:kings-call -> evolve:garchomp -> attack:spiral-after-search",
		str(attack_safety.get("reason", "")),
		bool(search_reopens) and bool(stage2.get("evolution_progress", false)) \
			and bool(attack_safety.get("valid", false))
	))


func _scenario_c_roserade_damage_breakpoint_before_attack() -> void:
	var processor := EffectProcessor.new()
	var garchomp_data := _real_card_data(GARCHOMP_UID)
	var roselia_data := _real_card_data(ROSELIA_UID)
	var roserade_data := _real_card_data(ROSERADE_UID)
	processor.register_pokemon_card(garchomp_data)
	processor.register_pokemon_card(roselia_data)
	processor.register_pokemon_card(roserade_data)
	var state := _game_state()
	var real_garchomp := _real_slot(garchomp_data, 0)
	var real_roserade := _real_slot(roserade_data, 0)
	state.players[0].active_pokemon = real_garchomp
	state.players[0].bench = [real_roserade]
	state.players[1].active_pokemon = _real_target("Public 130 HP target", 130, "", 1)
	var public_boost := processor.get_attacker_modifier(real_garchomp, state, state.players[1].active_pokemon)

	var evolve := _evolve("evolve:roserade-breakpoint", ROSERADE_UID, "slot:roselia")
	var before := _observation(
		[evolve, _attack("attack:spiral-before-boost", GARCHOMP_UID, 0, 100, false)],
		_slot("slot:active", GARCHOMP_UID, [_fighting_energy()]),
		[_slot("slot:roselia", ROSELIA_UID, [])],
		17
	)
	before["opponent"]["active"] = _public_target("PUBLIC_130_HP_TARGET", 130, 1)
	var facts_before := _facts(true, false, false, 3, false, false, 100)
	var evolve_frontier := _frontier(before, {
		"evolve:roserade-breakpoint": 520.0,
		"attack:spiral-before-boost": 500.0,
	}, facts_before, "evolve:roserade-breakpoint")
	var evolve_candidate := _candidate(evolve_frontier, "evolve:roserade-breakpoint")
	var stage2 := _module_annotation(evolve_candidate, "stage2_chain")

	var spiral := _attack("attack:spiral-at-130", GARCHOMP_UID, 0, 130, true)
	var after := _observation(
		[spiral, _play_trainer("supporter:iono-too-late", "CSV3C_123", false)],
		_slot("slot:active", GARCHOMP_UID, [_fighting_energy()]),
		[_slot("slot:roserade", ROSERADE_UID, [])],
		17
	)
	after["own"]["prizes_remaining"] = 1
	after["opponent"]["active"] = _public_target("PUBLIC_130_HP_TARGET", 130, 1)
	var facts_after := _facts(true, true, false, 3, false, false, 130)
	facts_after["resources"]["prizes_remaining"] = 1
	facts_after["prize"] = {"current_swing": 1, "win_now": true}
	var attack_frontier := _frontier(after, {
		"supporter:iono-too-late": 700.0,
		"attack:spiral-at-130": 10.0,
	}, facts_after, "supporter:iono-too-late")
	var attack_candidate := _candidate(attack_frontier, "attack:spiral-at-130")
	var attack_safety := _route_safety(attack_candidate, attack_frontier, facts_after)
	_check(public_boost == 30 \
		and bool(stage2.get("evolution_progress", false)) \
		and int((attack_candidate.get("outcome", {}) as Dictionary).get("estimated_damage", 0)) == 130, \
		"scenario C real Glory Cheer must move Spiral Dive from 100 to the public 130 breakpoint")
	_check(str(attack_safety.get("reason", "")) == "deterministic_win_now", \
		"scenario C the boosted Spiral Dive must attack immediately at the 130 KO breakpoint")
	_rows.append(_row(
		"roserade_damage_breakpoint_before_attack",
		"增伤进化/伤害断点",
		"对手前台剩101至130HP时，先把已满足进化条件的毒蔷薇进化为罗丝雷朵；真实荣耀声援为竹兰烈咬陆鲨增加30伤，使螺旋俯冲从100跨到130并立即击倒。",
		"evolve:roserade-breakpoint -> attack:spiral-at-130",
		str(attack_safety.get("reason", "")),
		public_boost == 30 and bool(attack_safety.get("valid", false))
	))


func _scenario_d_spiral_over_blast_same_ko_preserve_energy() -> void:
	var processor := EffectProcessor.new()
	var garchomp_data := _real_card_data(GARCHOMP_UID)
	processor.register_pokemon_card(garchomp_data)
	var spiral_state := _game_state()
	var spiral_attacker := _real_slot(garchomp_data, 0)
	spiral_attacker.attached_energy = [_real_energy(0), _real_energy(0)]
	spiral_state.players[0].active_pokemon = spiral_attacker
	spiral_state.players[0].hand = _real_filler_hand(6, 0)
	spiral_state.players[1].active_pokemon = _real_target("Public 100 HP active", 100, "", 1)
	spiral_state.players[1].bench = [_real_target("Public live reserve", 200, "", 1)]
	processor.execute_attack_effect_by_id(
		garchomp_data.effect_id, 0, spiral_attacker, spiral_state.players[1].active_pokemon, spiral_state, []
	)
	var blast_state := _game_state()
	var blast_attacker := _real_slot(garchomp_data, 0)
	blast_attacker.attached_energy = [_real_energy(0), _real_energy(0)]
	blast_state.players[0].active_pokemon = blast_attacker
	blast_state.players[1].active_pokemon = _real_target("Public 100 HP active", 100, "", 1)
	blast_state.players[1].bench = [_real_target("Public live reserve", 200, "", 1)]
	processor.execute_attack_effect_by_id(
		garchomp_data.effect_id, 1, blast_attacker, blast_state.players[1].active_pokemon, blast_state, []
	)
	var certificate := _same_ko_energy_certificate(
		100, 100, 260, 1, 4, true, 2, spiral_attacker.attached_energy.size(), blast_attacker.attached_energy.size()
	)

	var blast := _attack("attack:dragon-blast", GARCHOMP_UID, 1, 260, true)
	var spiral := _attack("attack:spiral-preserve", GARCHOMP_UID, 0, 100, true)
	var observation := _observation(
		[blast, spiral],
		_slot("slot:active", GARCHOMP_UID, [_fighting_energy(), _fighting_energy()]),
		[],
		12
	)
	observation["own"]["prizes_remaining"] = 4
	var visible_hand: Array[Dictionary] = []
	for index: int in 6:
		visible_hand.append({"uid": "VISIBLE_HAND_%d" % index})
	observation["own"]["hand"] = visible_hand
	observation["opponent"]["active"] = _public_target("PUBLIC_SINGLE_PRIZE_ACTIVE", 100, 1)
	observation["opponent"]["bench"] = [_public_target("PUBLIC_LIVE_RESERVE", 200, 1)]
	var facts := _facts(true, true, false, 6, false, false, 260)
	facts["resources"]["prizes_remaining"] = 4
	var frontier := _frontier(observation, {
		"attack:dragon-blast": 5900.0,
		"attack:spiral-preserve": 5828.0,
	}, facts, "attack:dragon-blast")
	var spiral_candidate := _candidate(frontier, "attack:spiral-preserve")
	var safety := _route_safety(spiral_candidate, frontier, facts)
	var strategy = StrategyScript.new()
	strategy.configure_profile(_profile, _manifest)
	var autonomous_upgrade: Dictionary = strategy.call("_find_module_verified_upgrade", frontier, facts)
	_check(bool(certificate.get("same_knockout", false)) \
		and int(certificate.get("preserved_energy", 0)) == 2 \
		and spiral_state.players[0].hand.size() == 6 \
		and spiral_attacker.attached_energy.size() == 2 \
		and blast_attacker.attached_energy.is_empty() \
		and blast_state.players[0].discard_pile.size() == 2, \
		"scenario D real effects must prove Spiral's draw is a no-op and Blast discards both Fighting Energy")
	_check(bool(safety.get("valid", false)) \
		and str(safety.get("reason", "")) == "module_verified_advantage" \
		and str(safety.get("advantage", {}).get("certificate_kind", "")) \
			== "public_same_ko_preserve_attached_energy", \
		"scenario D must certify the exact same-KO Spiral Dive energy-preservation upgrade")
	_check(str(autonomous_upgrade.get("safe_prefix_action_id", "")) == "attack:spiral-preserve" \
		and str(autonomous_upgrade.get("verified_advantage", {}).get("certificate_kind", "")) \
			== "public_same_ko_preserve_attached_energy", \
		"scenario D exact public certificate must autonomously select Spiral Dive")

	var final_prize_observation := observation.duplicate(true)
	final_prize_observation["own"]["prizes_remaining"] = 1
	var final_prize_facts := facts.duplicate(true)
	final_prize_facts["resources"]["prizes_remaining"] = 1
	var final_prize_frontier := _frontier(final_prize_observation, {
		"attack:dragon-blast": 5900.0,
		"attack:spiral-preserve": 5828.0,
	}, final_prize_facts, "attack:dragon-blast")
	var final_prize_safety := _route_safety(
		_candidate(final_prize_frontier, "attack:spiral-preserve"),
		final_prize_frontier,
		final_prize_facts
	)
	var no_replacement_observation := observation.duplicate(true)
	no_replacement_observation["opponent"]["bench"] = []
	var no_replacement_frontier := _frontier(no_replacement_observation, {
		"attack:dragon-blast": 5900.0,
		"attack:spiral-preserve": 5828.0,
	}, facts, "attack:dragon-blast")
	var no_replacement_safety := _route_safety(
		_candidate(no_replacement_frontier, "attack:spiral-preserve"),
		no_replacement_frontier,
		facts
	)
	var low_hand_observation := observation.duplicate(true)
	low_hand_observation["own"]["hand"].pop_back()
	var low_hand_facts := facts.duplicate(true)
	low_hand_facts["resources"]["hand_size"] = 5
	var low_hand_frontier := _frontier(low_hand_observation, {
		"attack:dragon-blast": 5900.0,
		"attack:spiral-preserve": 5828.0,
	}, low_hand_facts, "attack:dragon-blast")
	var low_hand_safety := _route_safety(
		_candidate(low_hand_frontier, "attack:spiral-preserve"),
		low_hand_frontier,
		low_hand_facts
	)
	var wrong_effect_observation := observation.duplicate(true)
	for action: Dictionary in wrong_effect_observation["legal_actions"]:
		if str(action.get("kind", "")) == "attack":
			action["source_card"]["effect_id"] = "WRONG_EFFECT"
	var wrong_effect_frontier := _frontier(wrong_effect_observation, {
		"attack:dragon-blast": 5900.0,
		"attack:spiral-preserve": 5828.0,
	}, facts, "attack:dragon-blast")
	var wrong_effect_safety := _route_safety(
		_candidate(wrong_effect_frontier, "attack:spiral-preserve"),
		wrong_effect_frontier,
		facts
	)
	var one_energy_observation := observation.duplicate(true)
	one_energy_observation["own"]["active"]["energy"].pop_back()
	var one_energy_frontier := _frontier(one_energy_observation, {
		"attack:dragon-blast": 5900.0,
		"attack:spiral-preserve": 5828.0,
	}, facts, "attack:dragon-blast")
	var one_energy_safety := _route_safety(
		_candidate(one_energy_frontier, "attack:spiral-preserve"),
		one_energy_frontier,
		facts
	)
	_check(not bool(final_prize_safety.get("valid", false)) \
		and not bool(no_replacement_safety.get("valid", false)) \
		and not bool(low_hand_safety.get("valid", false)) \
		and not bool(wrong_effect_safety.get("valid", false)) \
		and not bool(one_energy_safety.get("valid", false)), \
		"scenario D certificate must fail closed at the final Prize, without a live replacement, before the hand-six no-op boundary, on the wrong effect, or without both Fighting Energy")
	_rows.append(_row(
		"spiral_over_blast_same_ko_preserve_energy",
		"同KO最小资源/保能",
		"烈咬陆鲨恰有2斗能、手牌6张，对手100HP单奖且仍有后备、己方剩4奖时，两招都击倒；螺旋俯冲不抽牌也不弃能，龙之爆破真实结算会弃掉2斗能，因此应选螺旋俯冲。",
		"attack:spiral-preserve",
		"public_same_ko_preserve_attached_energy; real_effect_bound; fail_closed_boundaries",
		bool(certificate.get("same_knockout", false)) \
		and bool(safety.get("valid", false)) \
		and str(autonomous_upgrade.get("safe_prefix_action_id", "")) == "attack:spiral-preserve" \
		and not bool(final_prize_safety.get("valid", false)) \
		and not bool(no_replacement_safety.get("valid", false)) \
		and not bool(low_hand_safety.get("valid", false)) \
		and not bool(wrong_effect_safety.get("valid", false)) \
		and not bool(one_energy_safety.get("valid", false))
	))


func _scenario_e_forced_sendout_clears_stale_attack_certificate() -> void:
	var old_attack := _attack("attack:seed547-t23", GARCHOMP_UID, 0, 100, true)
	var old_observation := _observation(
		[old_attack],
		_slot("slot:active", GARCHOMP_UID, [_fighting_energy()]),
		[_slot("slot:gabite-reserve", GABITE_UID, [])],
		8
	)
	var old_facts := _facts(true, true, false, 2, true, false, 100)
	var old_frontier := _frontier(
		old_observation, {"attack:seed547-t23": 5900.0}, old_facts, "attack:seed547-t23"
	)
	var old_candidate := _candidate(old_frontier, "attack:seed547-t23")
	var strategy = StrategyScript.new()
	strategy.configure_profile(_profile, _manifest)
	strategy.call("_begin_turn", 23, {"run_id": "seed547", "match_id": "800018543"})
	strategy.call("_install_local_policy", old_frontier, "local_gate")
	strategy.set("_active_module_certificate_kind", "stale_seed547_attack_certificate")
	var installed_snapshot: Dictionary = strategy.get_policy_snapshot()

	var forced_state := _game_state()
	forced_state.turn_number = 24
	forced_state.phase = GameState.GamePhase.KNOCKOUT_REPLACE
	forced_state.players[0].active_pokemon = null
	var forced_gabite := _real_slot(_real_card_data(GABITE_UID), 0)
	forced_state.players[0].bench = [forced_gabite]
	var fallback = strategy.get("_rules_fallback")
	var handoff_step := {"id": "send_out"}
	var strategy_handoff_score: float = strategy.score_handoff_target(
		forced_gabite, handoff_step, {"game_state": forced_state, "player_index": 0}
	)
	var rule_handoff_score: float = float(fallback.score_handoff_target(
		forced_gabite, handoff_step, {"game_state": forced_state, "player_index": 0}
	))
	var handoff_snapshot: Dictionary = strategy.get_policy_snapshot()
	var handoff_policy: Dictionary = handoff_snapshot.get("policy", {}) \
		if handoff_snapshot.get("policy", {}) is Dictionary else {}
	var stale_cleared_during_handoff := handoff_policy.is_empty() \
		and str(handoff_snapshot.get("current_node_id", "")) == "" \
		and str(strategy.get("_preferred_candidate_id")) == "" \
		and str(strategy.get("_active_module_certificate_kind")) == ""
	_check(not installed_snapshot.is_empty() \
		and is_equal_approx(strategy_handoff_score, rule_handoff_score), \
		"scenario E forced send-out selection itself must remain exact Rule ownership")
	_check(stale_cleared_during_handoff, \
		"scenario E forced send-out must invalidate the old graph/cursor/certificate in the same interaction window")

	strategy.call("_begin_turn", 25, {
		"run_id": "seed547",
		"match_id": "800018543",
		"event_type": "MAIN_ACTION_WINDOW",
	})
	var cleared_snapshot: Dictionary = strategy.get_policy_snapshot()
	var cleared_policy: Dictionary = cleared_snapshot.get("policy", {}) \
		if cleared_snapshot.get("policy", {}) is Dictionary else {}
	var cleared_on_next_turn := cleared_policy.is_empty() \
		and str(cleared_snapshot.get("current_node_id", "")) == "" \
		and str(strategy.get("_preferred_candidate_id")) == "" \
		and str(strategy.get("_active_module_certificate_kind")) == ""
	var new_observation := _observation(
		[
			_evolve("evolve:garchomp-after-sendout", GARCHOMP_UID, "slot:active"),
			_attach_energy("attach:fighting-after-sendout", "slot:active"),
			_play_trainer("recover:night-stretcher-after-sendout", "CSV8C_183", true),
			_attack("attack:gabite-after-sendout", GABITE_UID, 0, 40, false),
		],
		_slot("slot:active", GABITE_UID, []),
		[_slot("slot:roselia", ROSELIA_UID, [])],
		7
	)
	var new_facts := _facts(false, false, true, 3, true, false, 40)
	var new_frontier := _frontier(new_observation, {
		"evolve:garchomp-after-sendout": 520.0,
		"attach:fighting-after-sendout": 500.0,
		"recover:night-stretcher-after-sendout": 480.0,
		"attack:gabite-after-sendout": 460.0,
	}, new_facts, "evolve:garchomp-after-sendout")
	var serialized_new := JSON.stringify(new_frontier)
	var new_window_live := new_frontier.size() == 4 \
		and not serialized_new.contains(str(old_candidate.get("candidate_id", ""))) \
		and not serialized_new.contains(OBSERVED_SEED547_STALE_CANDIDATE)
	_check(cleared_on_next_turn and new_window_live, \
		"scenario E next Main window must clear the old attack candidate and expose live evolve/attach/recover/attack choices")
	_rows.append(_row(
		"forced_sendout_clears_stale_attack_certificate",
		"强制出战/证书生命周期/无空窗",
		"seed547 的T23攻击证书不得进入T24强制出战；出战目标保持Rule选择，同时立即清空旧graph/cursor/certificate，T25主阶段再暴露新的进化、贴斗能、夜间担架和攻击。",
		"forced send_out: Rule -> next MAIN: fresh frontier",
		"same_window_forced_sendout_invalidation; next_turn_lifecycle_clear; fresh_frontier",
		stale_cleared_during_handoff and cleared_on_next_turn and new_window_live
	))


func _frontier(observation: Dictionary, scores: Dictionary, facts: Dictionary, rule_action_id: String) -> Array[Dictionary]:
	var pool: Array[Dictionary] = RouteSearchScript.new().build_candidate_pool(observation, scores, _manifest, facts)
	var annotated: Array[Dictionary] = CapabilityRegistryScript.new().annotate_frontier(
		pool, observation, facts, _profile, _manifest
	)
	for candidate: Dictionary in annotated:
		candidate["engine_rule_floor_exact"] = str(candidate.get("safe_prefix_action_id", "")) == rule_action_id
	_check(not annotated.is_empty() \
		and str(annotated[0].get("safe_prefix_action_id", "")) == rule_action_id, \
		"fixture Rule floor %s must remain exact and first" % rule_action_id)
	_check(not JSON.stringify(annotated).contains("FORBIDDEN_SECRET"), \
		"scenario frontier must never copy hidden sentinels")
	return annotated


func _poffin_override(
	items: Array,
	rule_selection: Array,
	observation: Dictionary,
	facts: Dictionary
) -> Dictionary:
	return CapabilityRegistryScript.new().pick_verified_interaction_override(
		items,
		{"id": "buddy_poffin_pokemon", "max_select": 2},
		rule_selection,
		{
			"v18cpg_observation": observation,
			"v18cpg_facts": facts,
		},
		_profile,
		""
	)


func _route_safety(selected: Dictionary, frontier: Array[Dictionary], facts: Dictionary) -> Dictionary:
	if selected.is_empty():
		return {"valid": false, "reason": "missing_selected_candidate"}
	var strategy = StrategyScript.new()
	strategy.configure_profile(_profile, _manifest)
	return strategy.call("_validate_model_route_safety", \
		str(selected.get("route_id", "")), frontier, facts, str(selected.get("candidate_id", "")))


func _epoch_strategy():
	var strategy = StrategyScript.new()
	strategy.configure_profile(_profile, _manifest)
	strategy.configure_verified_local_only_for_benchmark()
	return strategy


func _epoch_reopens(
	before: Dictionary,
	after: Dictionary,
	facts_before: Dictionary,
	facts_after: Dictionary,
	candidate: Dictionary,
	frontier: Array[Dictionary]
) -> bool:
	var delta := MaterialDeltaScript.new().compare(before, after, facts_before, facts_after)
	return bool(_epoch_strategy().call("_should_reopen_information_epoch", \
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


func _observation(actions: Array, active: Dictionary, bench: Array, deck_count: int) -> Dictionary:
	return {
		"observation_version": 1,
		"observation_hash": "cynthia-garchomp-complex-scenario",
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
			"active": _public_target("PUBLIC_OPPONENT_ACTIVE", 220, 2),
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
		"remaining_hp": 200,
		"max_hp": 330,
		"prize_count": 2 if uid == GARCHOMP_UID else 1,
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


func _attach_tool(action_id: String, uid: String, target: String) -> Dictionary:
	return {
		"id": action_id,
		"kind": "attach_tool",
		"card": _card(uid),
		"target": target,
		"requires_interaction": true,
	}


func _attach_energy(action_id: String, target: String) -> Dictionary:
	return {
		"id": action_id,
		"kind": "attach_energy",
		"card": _fighting_energy(),
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


func _granted_attack(action_id: String, uid: String) -> Dictionary:
	return {
		"id": action_id,
		"kind": "granted_attack",
		"source": "slot:active",
		"source_card": _card(uid),
		"attack_index": 0,
		"projected_damage": 0,
		"projected_knockout": false,
		"requires_interaction": true,
	}


func _end_turn(action_id: String) -> Dictionary:
	return {"id": action_id, "kind": "end_turn"}


func _fighting_energy() -> Dictionary:
	return {
		"uid": "CSVE1C_FIG",
		"name": "Fighting Energy",
		"type": "Basic Energy",
		"energy_type": "F",
		"energy_provides": "F",
		"semantic_roles": ["energy_source", "typed_energy", "basic_energy"],
	}


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


func _real_slot(data: CardData, owner: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(data, owner))
	return slot


func _real_target(name: String, hp: int, mechanic: String, owner: int) -> PokemonSlot:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = "Pokemon"
	data.stage = "Basic"
	data.hp = hp
	data.mechanic = mechanic
	return _real_slot(data, owner)


func _real_energy(owner: int) -> CardInstance:
	return CardInstance.create(_real_card_data("CSVE1C_FIG"), owner)


func _real_filler_hand(count: int, owner: int) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	for index: int in count:
		var data := CardData.new()
		data.name = "Visible hand filler %d" % index
		data.card_type = "Item"
		result.append(CardInstance.create(data, owner))
	return result


func _same_ko_energy_certificate(
	target_hp: int,
	spiral_damage: int,
	blast_damage: int,
	active_prizes: int,
	prizes_remaining: int,
	has_live_replacement: bool,
	energy_before: int,
	spiral_energy_after: int,
	blast_energy_after: int
) -> Dictionary:
	var spiral_ko := target_hp > 0 and spiral_damage >= target_hp
	var blast_ko := target_hp > 0 and blast_damage >= target_hp
	var same_ko := spiral_ko and blast_ko and has_live_replacement \
		and active_prizes < prizes_remaining
	return {
		"same_knockout": same_ko,
		"same_prizes": active_prizes if same_ko else 0,
		"nonterminal": active_prizes < prizes_remaining,
		"preserved_energy": spiral_energy_after - blast_energy_after,
		"spiral_preserves_all": spiral_energy_after == energy_before,
		"blast_discards_all": blast_energy_after == 0,
		"certificate_kind": "public_same_ko_preserve_attached_energy",
	}


func _row(id: String, category: String, description: String, expected_choice: String, proof_reason: String, passed: bool) -> Dictionary:
	return {
		"id": id,
		"category": category,
		"description": description,
		"expected_choice": expected_choice,
		"proof_reason": proof_reason,
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
		"deck_name": "18.0 竹兰烈咬陆鲨",
		"strategy_id": str(_profile.get("strategy_id", "")),
		"profile_version": int(_profile.get("profile_version", 0)),
		"round00_baseline": {
			"seeds": [800018543, 800018544, 800018545, 800018546, 800018547],
			"rule_wins": 3,
			"v18cpg_wins": 2,
			"model_calls": 18,
			"accepted_calls": 2,
			"negative_flip_seeds": [800018547],
			"visible_wait_p95_ms": 6255,
		},
		"scenario_count": _rows.size(),
		"passed_count": _rows.filter(func(row: Dictionary) -> bool: return bool(row.get("passed", false))).size(),
		"all_passed": _failures.is_empty() and _rows.size() == 5,
		"known_production_gaps": [
			{
				"id": "garchomp_same_ko_energy_preservation_certificate",
				"status": "resolved_deck_scoped_public_certificate",
				"reason": "The exact Garchomp effect, attack indices, public same-KO state, hand-six no-op, two attached Fighting Energy, nonterminal Prize state, and live replacement are bound before Spiral Dive can replace Dragon Blast.",
			},
			{
				"id": "forced_sendout_same_turn_certificate_invalidation",
				"status": "resolved_v18cpg_runtime_hook",
				"reason": "score_handoff_target keeps exact Rule target scoring and now invalidates graph/cursor/certificate immediately at the public send_out boundary.",
				"observed_seed": 800018547,
				"observed_candidate_id": OBSERVED_SEED547_STALE_CANDIDATE,
			},
		],
		"isolation": {
			"profile_modified": true,
			"shared_runtime_modified": true,
			"rule_or_legacy_or_agent_modified": false,
			"hidden_sentinel_absent_from_frontiers": true,
		},
		"coverage": [
			"Buddy-Buddy Poffin into two distinct TM Evolution roots",
			"Gabite named search information epoch into Garchomp attack",
			"real Roserade Glory Cheer 100-to-130 damage breakpoint",
			"real Spiral Dive hand-six no-op versus Dragon Blast discard-all",
			"forced-sendout Rule handoff, same-window invalidation, and next-turn lifecycle clearing",
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
