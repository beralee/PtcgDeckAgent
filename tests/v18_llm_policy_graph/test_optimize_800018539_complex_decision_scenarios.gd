extends SceneTree

const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const RouteSearchScript = preload("res://scripts/ai/v18_cpg/planning/V18CPGRouteSearch.gd")
const CapabilityRegistryScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCapabilityRegistry.gd")
const MaterialDeltaScript = preload("res://scripts/ai/v18_cpg/observation/V18CPGMaterialDelta.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")

const DECK_ID := 800018539
const MANIFEST_PATH := "res://scripts/ai/v18_cpg/profiles/generated_semantic_manifests/800018539.json"
const REPORT_PATH := "res://tmp/v18cpg/optimization21/800018539/complex_decision_scenarios.json"
const HO_OH_UID := "CSV10C_035"
const CHARCADET_UID := "CSV9C_033"
const ARMAROUGE_UID := "CSV1C_028"
const IRON_HANDS_UID := "CSV6C_051"
const FEZANDIPITI_UID := "CSV8C_135"
const MEW_UID := "151C_151"

var _profile: Dictionary = {}
var _manifest: Dictionary = {}
var _failures: Array[String] = []
var _rows: Array[Dictionary] = []


func _initialize() -> void:
	_profile = ProfileCatalogScript.get_profile_for_deck(DECK_ID)
	_manifest = _load_json(MANIFEST_PATH)
	_check(int(_profile.get("deck_id", 0)) == DECK_ID, "production Ethan's Ho-Oh profile must load")
	_check(int(_manifest.get("deck_id", 0)) == DECK_ID, "Ethan's Ho-Oh semantic manifest must load")
	_check(_profile.get("modules", []) == ["fire_toolbox", "partner_chain", "energy_burst"], \
		"scenarios must exercise the production fire/partner/energy capability composition")

	_scenario_a_double_ho_oh_and_charcadet_opening()
	_scenario_b_vessel_golden_flame_switch_attack()
	_scenario_c_minimum_fire_off_then_stop_churn()
	_scenario_d_amp_you_very_much_extra_prize_terminal()
	_scenario_e_low_deck_recover_accelerate_attack()
	_write_report()

	EffectProcessor.cleanup_live_instances_for_tests()
	if _failures.is_empty() and _rows.size() == 5:
		print("optimization21 800018539 complex decision scenarios: PASS (5/5)")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("optimization21 800018539 complex decision scenarios: FAIL (%d)" % _failures.size())
	quit(1)


func _scenario_a_double_ho_oh_and_charcadet_opening() -> void:
	var first := _observation(
		[
			_bench("bench:ho-oh-1", HO_OH_UID),
			_bench("bench:charcadet-too-early", CHARCADET_UID),
		],
		_slot("slot:active", MEW_UID, []),
		[],
		28
	)
	var facts := _facts(false, false, false, 5, false, false, 0)
	var first_frontier := _frontier(first, {
		"bench:ho-oh-1": 620.0,
		"bench:charcadet-too-early": 300.0,
	}, facts, "bench:ho-oh-1")
	var first_ho_oh := _candidate(first_frontier, "bench:ho-oh-1")
	_check("partner_piece" in (first_ho_oh.get("action_semantic_roles", []) as Array) \
		and "energy_target" in (first_ho_oh.get("action_semantic_roles", []) as Array), \
		"scenario A first Ho-Oh must establish both the named partner and acceleration target")

	var second := _observation(
		[
			_bench("bench:ho-oh-2", HO_OH_UID),
			_bench("bench:charcadet-too-early", CHARCADET_UID),
		],
		_slot("slot:active", MEW_UID, []),
		[_slot("slot:ho-oh-1", HO_OH_UID, [])],
		28
	)
	var second_frontier := _frontier(second, {
		"bench:ho-oh-2": 610.0,
		"bench:charcadet-too-early": 300.0,
	}, facts, "bench:ho-oh-2")
	var second_ho_oh := _candidate(second_frontier, "bench:ho-oh-2")
	var second_partner := _module_annotation(second_ho_oh, "partner_chain")
	_check(int(second_partner.get("partner_piece_count", -1)) == 1 \
		and "preserve_named_partner_chain" in (second_partner.get("decision_hints", []) as Array), \
		"scenario A the second Ho-Oh must extend an already visible named-partner chain")

	var third := _observation(
		[
			_bench("bench:charcadet", CHARCADET_UID),
			_bench("bench:fezandipiti", FEZANDIPITI_UID),
		],
		_slot("slot:active", MEW_UID, []),
		[
			_slot("slot:ho-oh-1", HO_OH_UID, []),
			_slot("slot:ho-oh-2", HO_OH_UID, []),
		],
		28
	)
	var third_frontier := _frontier(third, {
		"bench:charcadet": 560.0,
		"bench:fezandipiti": 240.0,
	}, facts, "bench:charcadet")
	var charcadet := _candidate(third_frontier, "bench:charcadet")
	var final_partner := _module_annotation(charcadet, "partner_chain")
	_check(str(charcadet.get("route_id", "")) == "route:develop" \
		and "development_piece" in (charcadet.get("action_semantic_roles", []) as Array) \
		and int(final_partner.get("partner_piece_count", -1)) == 2, \
		"scenario A Charcadet must complete the double-Ho-Oh opening without displacing either partner")
	_rows.append(_row(
		"double_ho_oh_charcadet_opening",
		"开局展开/备战结构",
		"以梦幻承担前台，依次铺下两只阿响的凤王ex，再铺炭小侍作为红莲铠骑进化根；保留双金色火焰目标和后续送火轴。",
		"bench:ho-oh-1 -> bench:ho-oh-2 -> bench:charcadet",
		"exact_rule_floor_with_two_partner_pieces",
		str(charcadet.get("route_id", "")) == "route:develop" \
			and int(final_partner.get("partner_piece_count", -1)) == 2
	))


func _scenario_b_vessel_golden_flame_switch_attack() -> void:
	var vessel := _play_trainer("item:earthen-vessel", "CSV6C_115", true)
	var before := _observation(
		[vessel, _end_turn("end:premature")],
		_slot("slot:active", MEW_UID, []),
		[
			_slot("slot:ho-oh-source", HO_OH_UID, []),
			_slot("slot:ho-oh-target", HO_OH_UID, [_fire_energy(), _fire_energy()]),
		],
		22
	)
	before["observation_version"] = 1
	before["observation_hash"] = "ethan-ho-oh-before-vessel"
	before["own"]["hand"] = [_card("CSV6C_115"), {"uid": "VISIBLE_VESSEL_FODDER"}]
	var facts_before := _facts(false, false, false, 2, false, false, 0)
	var vessel_frontier := _frontier(before, {
		"item:earthen-vessel": 540.0,
		"end:premature": -900.0,
	}, facts_before, "item:earthen-vessel")
	var vessel_candidate := _candidate(vessel_frontier, "item:earthen-vessel")
	_check(str(vessel_candidate.get("route_id", "")) == "route:information" \
		and str(vessel_candidate.get("checkpoint_after", "")) == "information_result", \
		"scenario B Earthen Vessel must be a typed information checkpoint")

	var golden_flame := _ability(
		"ability:golden-flame", "slot:ho-oh-source", HO_OH_UID, true, "slot:ho-oh-target"
	)
	var after_vessel := _observation(
		[golden_flame, _end_turn("end:after-vessel")],
		_slot("slot:active", MEW_UID, []),
		[
			_slot("slot:ho-oh-source", HO_OH_UID, []),
			_slot("slot:ho-oh-target", HO_OH_UID, [_fire_energy(), _fire_energy()]),
		],
		20
	)
	after_vessel["observation_version"] = 2
	after_vessel["observation_hash"] = "ethan-ho-oh-after-vessel"
	after_vessel["own"]["hand"] = [_fire_energy(), _fire_energy()]
	var facts_after_vessel := _facts(false, false, false, 2, false, false, 0)
	var vessel_reopens := _epoch_reopens(
		before, after_vessel, facts_before, facts_after_vessel, vessel_candidate, vessel_frontier
	)
	var flame_frontier := _frontier(after_vessel, {
		"ability:golden-flame": 520.0,
		"end:after-vessel": -900.0,
	}, facts_after_vessel, "ability:golden-flame")
	var flame_candidate := _candidate(flame_frontier, "ability:golden-flame")
	var flame_partner := _module_annotation(flame_candidate, "partner_chain")
	_check(bool(vessel_reopens) \
		and "ability_engine" in (flame_candidate.get("action_semantic_roles", []) as Array) \
		and int(flame_partner.get("partner_piece_count", -1)) == 2, \
		"scenario B Vessel result must reopen into Golden Flame with both Ho-Oh partners bound")

	var switch := _play_trainer("item:switch-to-ho-oh", "CSV1C_113", true)
	switch["target"] = "slot:ho-oh-target"
	var after_flame := _observation(
		[switch, _play_trainer("supporter:research-too-early", "CSV1C_121", false)],
		_slot("slot:active", MEW_UID, []),
		[
			_slot("slot:ho-oh-source", HO_OH_UID, []),
			_slot("slot:ho-oh-target", HO_OH_UID, [_fire_energy(), _fire_energy(), _fire_energy(), _fire_energy()]),
		],
		20
	)
	after_flame["observation_version"] = 3
	after_flame["observation_hash"] = "ethan-ho-oh-after-golden-flame"
	after_flame["own"]["hand"] = [_card("CSV1C_113")]
	var facts_after_flame := _facts(false, false, false, 1, false, false, 0)
	var flame_reopens := _epoch_reopens(
		after_vessel, after_flame, facts_after_vessel, facts_after_flame, flame_candidate, flame_frontier
	)
	var switch_frontier := _frontier(after_flame, {
		"item:switch-to-ho-oh": 510.0,
		"supporter:research-too-early": 260.0,
	}, facts_after_flame, "item:switch-to-ho-oh")
	var switch_candidate := _candidate(switch_frontier, "item:switch-to-ho-oh")
	_check(bool(flame_reopens) \
		and str(switch_candidate.get("route_id", "")) == "route:pivot" \
		and str((switch_candidate.get("action_ref", {}) as Dictionary).get("target", "")) == "slot:ho-oh-target", \
		"scenario B Golden Flame result must reopen into the exact powered Ho-Oh pivot")

	var attack := _attack("attack:shining-wings", "slot:active", HO_OH_UID, 0, 160, true)
	var ready := _observation(
		[
			_ability("ability:flip-the-script-too-late", "slot:fez", FEZANDIPITI_UID, true),
			attack,
		],
		_slot("slot:active", HO_OH_UID, [_fire_energy(), _fire_energy(), _fire_energy(), _fire_energy()]),
		[
			_slot("slot:mew", MEW_UID, []),
			_slot("slot:ho-oh-source", HO_OH_UID, []),
			_slot("slot:fez", FEZANDIPITI_UID, []),
		],
		20
	)
	ready["own"]["prizes_remaining"] = 2
	ready["opponent"]["active"] = _public_target("PUBLIC_TWO_PRIZE_TARGET", 150, 2)
	var facts_ready := _facts(true, true, false, 2, false, false, 160)
	facts_ready["resources"]["prizes_remaining"] = 2
	facts_ready["prize"] = {"current_swing": 2, "win_now": true}
	var attack_frontier := _frontier(ready, {
		"ability:flip-the-script-too-late": 680.0,
		"attack:shining-wings": 10.0,
	}, facts_ready, "ability:flip-the-script-too-late")
	var attack_candidate := _candidate(attack_frontier, "attack:shining-wings")
	var attack_safety := _route_safety(attack_candidate, attack_frontier, facts_ready)
	_check(bool((attack_candidate.get("outcome", {}) as Dictionary).get("win_now", false)) \
		and str(attack_safety.get("reason", "")) == "deterministic_win_now", \
		"scenario B powered Ho-Oh must attack for the final two prizes instead of drawing again")
	_rows.append(_row(
		"vessel_golden_flame_switch_attack",
		"找能/特性加速/换位攻击",
		"大地容器拿到2火能后，只在公开结果处重开；金色火焰把2火能贴给已有2火能的后备凤王，随后交换到前台，以闪耀之翼直接取最后2奖。",
		"item:earthen-vessel -> ability:golden-flame -> item:switch-to-ho-oh -> attack:shining-wings",
		str(attack_safety.get("reason", "")),
		bool(vessel_reopens) and bool(flame_reopens) and bool(attack_safety.get("valid", false))
	))


func _scenario_c_minimum_fire_off_then_stop_churn() -> void:
	var fire_off_1 := _ability("ability:fire-off-1", "slot:armarouge", ARMAROUGE_UID, true, "slot:active")
	var before := _observation(
		[fire_off_1, _play_trainer("supporter:research-before-ready", "CSV1C_121", false)],
		_slot("slot:active", HO_OH_UID, [_fire_energy(), _fire_energy()]),
		[
			_slot("slot:fire-bank", CHARCADET_UID, [_fire_energy(), _fire_energy(), _fire_energy()]),
			_slot("slot:armarouge", ARMAROUGE_UID, []),
			_slot("slot:fez", FEZANDIPITI_UID, []),
		],
		13
	)
	before["observation_version"] = 1
	before["observation_hash"] = "ethan-ho-oh-before-first-fire-off"
	var facts_before := _facts(false, false, false, 3, false, false, 0)
	var before_frontier := _frontier(before, {
		"ability:fire-off-1": 520.0,
		"supporter:research-before-ready": 320.0,
	}, facts_before, "ability:fire-off-1")
	var fire_off_1_candidate := _candidate(before_frontier, "ability:fire-off-1")

	var fire_off_2 := _ability(
		"ability:fire-off-2", "slot:armarouge", ARMAROUGE_UID, true, "slot:active"
	)
	var after_first := _observation(
		[fire_off_2, _play_trainer("supporter:research-still-early", "CSV1C_121", false)],
		_slot("slot:active", HO_OH_UID, [_fire_energy(), _fire_energy(), _fire_energy()]),
		[
			_slot("slot:fire-bank", CHARCADET_UID, [_fire_energy(), _fire_energy()]),
			_slot("slot:armarouge", ARMAROUGE_UID, []),
			_slot("slot:fez", FEZANDIPITI_UID, []),
		],
		13
	)
	after_first["observation_version"] = 2
	after_first["observation_hash"] = "ethan-ho-oh-after-first-fire-off"
	var facts_after_first := _facts(false, false, false, 3, false, false, 0)
	var first_reopens := _epoch_reopens(
		before, after_first, facts_before, facts_after_first, fire_off_1_candidate, before_frontier
	)
	var second_frontier := _frontier(after_first, {
		"ability:fire-off-2": 520.0,
		"supporter:research-still-early": 320.0,
	}, facts_after_first, "ability:fire-off-2")
	var fire_off_2_candidate := _candidate(second_frontier, "ability:fire-off-2")

	var extra_fire_off_action := _ability(
		"ability:fire-off-extra", "slot:armarouge", ARMAROUGE_UID, true, "slot:active"
	)
	var attack := _attack("attack:shining-wings-after-fire-off", "slot:active", HO_OH_UID, 0, 160, true)
	var after_second := _observation(
		[
			extra_fire_off_action,
			_ability("ability:flip-the-script", "slot:fez", FEZANDIPITI_UID, true),
			_play_trainer("supporter:research-too-late", "CSV1C_121", false),
			attack,
		],
		_slot("slot:active", HO_OH_UID, [_fire_energy(), _fire_energy(), _fire_energy(), _fire_energy()]),
		[
			_slot("slot:fire-bank", CHARCADET_UID, [_fire_energy()]),
			_slot("slot:armarouge", ARMAROUGE_UID, []),
			_slot("slot:fez", FEZANDIPITI_UID, []),
		],
		13
	)
	after_second["observation_version"] = 3
	after_second["observation_hash"] = "ethan-ho-oh-after-second-fire-off"
	after_second["own"]["prizes_remaining"] = 1
	after_second["opponent"]["active"] = _public_target("PUBLIC_SINGLE_PRIZE_TARGET", 160, 1)
	var facts_after_second := _facts(true, true, false, 3, false, false, 160)
	facts_after_second["resources"]["prizes_remaining"] = 1
	facts_after_second["prize"] = {"current_swing": 1, "win_now": true}
	var second_reopens := _epoch_reopens(
		after_first, after_second, facts_after_first, facts_after_second, fire_off_2_candidate, second_frontier
	)
	var ready_frontier := _frontier(after_second, {
		"ability:fire-off-extra": 720.0,
		"ability:flip-the-script": 690.0,
		"supporter:research-too-late": 660.0,
		"attack:shining-wings-after-fire-off": 10.0,
	}, facts_after_second, "ability:fire-off-extra")
	var attack_candidate := _candidate(ready_frontier, "attack:shining-wings-after-fire-off")
	var extra_fire_off := _candidate(ready_frontier, "ability:fire-off-extra")
	var fez_draw := _candidate(ready_frontier, "ability:flip-the-script")
	var research := _candidate(ready_frontier, "supporter:research-too-late")
	var attack_safety := _route_safety(attack_candidate, ready_frontier, facts_after_second)
	var extra_warning := _module_annotation(extra_fire_off, "energy_burst")
	var fez_warning := _module_annotation(fez_draw, "energy_burst")
	var research_warning := _module_annotation(research, "energy_burst")
	var moved_exactly_two := _count_energy(before["own"]["active"], "R") == 2 \
		and _count_energy(after_first["own"]["active"], "R") == 3 \
		and _count_energy(after_second["own"]["active"], "R") == 4 \
		and _count_energy(before["own"]["bench"][0], "R") \
			- _count_energy(after_second["own"]["bench"][0], "R") == 2
	_check(bool(first_reopens) and bool(second_reopens) and moved_exactly_two, \
		"scenario C Fire Off must move exactly two Fire one at a time to complete Ho-Oh's RRRR cost")
	_check(str(extra_warning.get("route_warning", "")) == "optional_churn_after_ko_secured" \
		and str(fez_warning.get("decision_hint", "")) == "skip_optional_information" \
		and str(research_warning.get("decision_hint", "")) == "skip_optional_information", \
		"scenario C every extra Fire Off/draw/filter branch must be marked as optional churn")
	_check(str(attack_safety.get("reason", "")) == "deterministic_win_now", \
		"scenario C the minimum Fire Off must hand control directly to the terminal Flame Cannon")
	_rows.append(_row(
		"minimum_fire_off_then_stop_churn",
		"送火最小化/停止抽滤",
		"前台凤王已有2火能时，红莲铠骑只从后备能源库连续搬2火能，精确补齐RRRR；160HP末奖目标已可击倒后，拒绝第3次送火、吉雉鸡抽牌和博士研究。",
		"ability:fire-off-1 -> ability:fire-off-2 -> attack:shining-wings-after-fire-off",
		str(attack_safety.get("reason", "")),
		bool(first_reopens) and bool(second_reopens) and moved_exactly_two \
			and bool(attack_safety.get("valid", false))
	))


func _scenario_d_amp_you_very_much_extra_prize_terminal() -> void:
	var processor := EffectProcessor.new()
	var iron_hands_data := _real_card_data(IRON_HANDS_UID)
	processor.register_pokemon_card(iron_hands_data)
	var state := _game_state()
	var attacker := _real_slot(iron_hands_data, 0)
	var defender := _real_target("Public one-prize active", 120, "", 1)
	var arm_press_defender := _real_target("Arm Press comparison", 120, "", 1)
	state.players[0].active_pokemon = attacker
	state.players[1].active_pokemon = defender
	state.players[1].bench.append(_real_target("Public reserve", 200, "", 1))
	processor.execute_attack_effect_by_id(
		iron_hands_data.effect_id, 1, attacker, defender, state, []
	)
	processor.execute_attack_effect_by_id(
		iron_hands_data.effect_id, 0, attacker, arm_press_defender, state, []
	)
	var amp_effect_extra_prizes := _extra_prize_count(defender)
	var arm_press_effect_extra_prizes := _extra_prize_count(arm_press_defender)

	var arm_press := _attack("attack:arm-press", "slot:active", IRON_HANDS_UID, 0, 160, true)
	var amp := _attack("attack:amp-you-very-much", "slot:active", IRON_HANDS_UID, 1, 120, true)
	var observation := _observation(
		[arm_press, amp],
		_slot("slot:active", IRON_HANDS_UID, [
			_luminous_energy(), _fire_energy(), _fire_energy(), _fire_energy()
		]),
		[],
		9
	)
	observation["own"]["prizes_remaining"] = 2
	observation["opponent"]["active"] = _public_target("PUBLIC_SINGLE_PRIZE_TARGET", 120, 1)
	observation["opponent"]["bench"] = [_public_target("PUBLIC_RESERVE", 200, 1)]
	var facts := _facts(true, true, false, 2, false, false, 160)
	facts["resources"]["prizes_remaining"] = 2
	var frontier := _frontier(observation, {
		"attack:arm-press": 700.0,
		"attack:amp-you-very-much": 10.0,
	}, facts, "attack:arm-press")
	var amp_candidate := _candidate(frontier, "attack:amp-you-very-much")
	var arm_press_candidate := _candidate(frontier, "attack:arm-press")
	var certificate := _extra_prize_certificate(amp_candidate)
	var safety := _route_safety(amp_candidate, frontier, facts)
	var strategy = StrategyScript.new()
	strategy.configure_profile(_profile, _manifest)
	var automatic_upgrade: Dictionary = strategy.call("_find_module_verified_upgrade", frontier, facts)
	_check(amp_effect_extra_prizes == 1 and arm_press_effect_extra_prizes == 0, \
		"scenario D real EffectProcessor must bind extra Prize to attack1 and not attack0")
	_check(bool(certificate.get("verified", false)) \
		and str(certificate.get("certificate_kind", "")) == "public_extra_prize_attack_terminal" \
		and bool(certificate.get("same_source", false)) \
		and bool(certificate.get("same_target", false)) \
		and int(certificate.get("selected_attack_index", -1)) == 1 \
		and int(certificate.get("rule_attack_index", -1)) == 0 \
		and int(certificate.get("selected_damage", 0)) == 120 \
		and int(certificate.get("rule_damage", 0)) == 160 \
		and int(certificate.get("prizes_now", 0)) == 2 \
		and bool(certificate.get("win_now", false)), \
		"scenario D certificate must exactly bind same-source/same-target attack1 over Rule attack0")
	var energy_proof: Dictionary = certificate.get("energy_proof", {}) \
		if certificate.get("energy_proof", {}) is Dictionary else {}
	_check(bool(energy_proof.get("verified", false)) \
		and int(energy_proof.get("wildcard_energy_count", 0)) == 1 \
		and int(energy_proof.get("basic_energy_count", 0)) == 3 \
		and bool(energy_proof.get("no_additional_special_energy", false)), \
		"scenario D Luminous plus three basic Fire must be an exact public LCCC legality proof")
	_check(not bool((arm_press_candidate.get("outcome", {}) as Dictionary).get("win_now", false)) \
		and bool((amp_candidate.get("outcome", {}) as Dictionary).get("win_now", false)) \
		and int((amp_candidate.get("outcome", {}) as Dictionary).get("prizes_now", 0)) == 2 \
		and bool(safety.get("valid", false)) \
		and str(safety.get("reason", "")) == "deterministic_win_now" \
		and str(automatic_upgrade.get("safe_prefix_action_id", "")) == "attack:amp-you-very-much", \
		"scenario D production selection must autonomously replace Rule attack0 with terminal attack1")

	var negative_cases: Array[Dictionary] = []
	var protected := observation.duplicate(true)
	protected["opponent"]["active"]["pokemon"]["effect_id"] = "fd252ce877c709e9e3161c56ef98aff8"
	negative_cases.append({"id": "public_protection", "observation": protected, "reason": "public_damage_protection_present"})
	var reactive := observation.duplicate(true)
	reactive["opponent"]["active"]["tool"] = {"uid": "PUBLIC_LUCKY_HELMET", "effect_id": "76ed73e869ac742e97ea521f200a360e"}
	negative_cases.append({"id": "public_reaction", "observation": reactive, "reason": "public_knockout_reaction_present"})
	var nonterminal := observation.duplicate(true)
	nonterminal["own"]["prizes_remaining"] = 3
	negative_cases.append({"id": "three_prizes_remaining", "observation": nonterminal, "reason": "not_exact_two_prize_closeout"})
	var hp_too_high := observation.duplicate(true)
	hp_too_high["opponent"]["active"]["remaining_hp"] = 121
	negative_cases.append({"id": "hp_above_120", "observation": hp_too_high, "reason": "target_hp_outside_bonus_attack_ko_range"})
	var multi_prize := observation.duplicate(true)
	multi_prize["opponent"]["active"]["prize_count"] = 2
	negative_cases.append({"id": "multi_prize_target", "observation": multi_prize, \
		"reason": "target_not_exact_single_prize", "base_win": true})
	var no_reserve := observation.duplicate(true)
	no_reserve["opponent"]["bench"] = []
	negative_cases.append({"id": "no_live_bench", "observation": no_reserve, "reason": "opponent_has_no_live_bench"})
	var illegal_energy := observation.duplicate(true)
	illegal_energy["own"]["active"]["energy"][3] = _lightning_energy()
	negative_cases.append({"id": "illegal_energy_mix", "observation": illegal_energy, "reason": "active_energy_identity_not_exact"})
	var source_mismatch := observation.duplicate(true)
	source_mismatch["legal_actions"][1]["source"] = "slot:not-active"
	negative_cases.append({"id": "source_mismatch", "observation": source_mismatch, "reason": "same_active_source_not_bound"})
	var target_mismatch := observation.duplicate(true)
	target_mismatch["legal_actions"][1]["target"] = "slot:not-opponent-active"
	negative_cases.append({"id": "target_mismatch", "observation": target_mismatch, "reason": "same_opponent_active_target_not_bound"})
	for negative: Dictionary in negative_cases:
		var negative_frontier := _frontier(
			negative.get("observation", {}),
			{"attack:arm-press": 700.0, "attack:amp-you-very-much": 10.0},
			facts,
			"attack:arm-press"
		)
		var negative_amp := _candidate(negative_frontier, "attack:amp-you-very-much")
		var negative_certificate := _extra_prize_certificate(negative_amp)
		_check(not bool(negative_certificate.get("verified", false)) \
			and str(negative_certificate.get("reason", "")) == str(negative.get("reason", "")) \
			and bool((negative_amp.get("outcome", {}) as Dictionary).get("win_now", false)) \
				== bool(negative.get("base_win", false)), \
			"scenario D negative %s must fail closed with its exact public reason" % str(negative.get("id", "")))

	var swapped_indices := observation.duplicate(true)
	swapped_indices["legal_actions"][0]["attack_index"] = 1
	swapped_indices["legal_actions"][1]["attack_index"] = 0
	var swapped_frontier := _frontier(swapped_indices, {
		"attack:arm-press": 700.0,
		"attack:amp-you-very-much": 10.0,
	}, facts, "attack:arm-press")
	var swapped_amp := _candidate(swapped_frontier, "attack:amp-you-very-much")
	_check(_extra_prize_certificate(swapped_amp).is_empty() \
		and not bool((swapped_amp.get("outcome", {}) as Dictionary).get("win_now", false)), \
		"scenario D swapped attack0/1 indices must not produce any certificate")
	_rows.append(_row(
		"amp_you_very_much_extra_prize_terminal",
		"额外奖赏/终局识别",
		"对手前台120HP单奖、己方剩2奖且对手仍有后备时，多谢款待造成击倒并由真实效果追加1奖，合计拿2奖直接获胜；臂膀压制只拿1奖。",
		"attack:amp-you-very-much",
		"public_extra_prize_attack_terminal; deterministic_win_now",
		bool(certificate.get("win_now", false)) \
			and str(safety.get("reason", "")) == "deterministic_win_now" \
			and str(automatic_upgrade.get("safe_prefix_action_id", "")) == "attack:amp-you-very-much"
	))


func _scenario_e_low_deck_recover_accelerate_attack() -> void:
	var stretcher := _play_trainer("item:night-stretcher", "CSV8C_183", true)
	var research := _play_trainer("supporter:research-deckout", "CSV1C_121", false)
	var before := _observation(
		[stretcher, research],
		_slot("slot:active", MEW_UID, []),
		[
			_slot("slot:ho-oh-source", HO_OH_UID, []),
			_slot("slot:ho-oh-target", HO_OH_UID, [_fire_energy(), _fire_energy(), _fire_energy()]),
		],
		5
	)
	before["observation_version"] = 1
	before["observation_hash"] = "ethan-ho-oh-low-deck-before-recovery"
	before["own"]["hand"] = [_card("CSV8C_183")]
	before["own"]["discard"] = [_fire_energy(), _card(CHARCADET_UID)]
	var facts_before := _facts(false, false, false, 1, true, true, 0)
	var recovery_frontier := _frontier(before, {
		"item:night-stretcher": 510.0,
		"supporter:research-deckout": 500.0,
	}, facts_before, "item:night-stretcher")
	var recovery_candidate := _candidate(recovery_frontier, "item:night-stretcher")
	var research_candidate := _candidate(recovery_frontier, "supporter:research-deckout")
	var research_safety := _route_safety(research_candidate, recovery_frontier, facts_before)
	var research_warning := _module_annotation(research_candidate, "energy_burst")
	_check(str(recovery_candidate.get("route_id", "")) == "route:recover" \
		and str(research_safety.get("reason", "")) == "deckout_margin_blocks_search" \
		and str(research_warning.get("route_warning", "")) == "low_deck_information_risk", \
		"scenario E low deck must recover public discard energy and reject Research deck-out risk")

	var golden_flame := _ability(
		"ability:golden-flame-recovered", "slot:ho-oh-source", HO_OH_UID, true, "slot:ho-oh-target"
	)
	var after_recovery := _observation(
		[golden_flame, _play_trainer("supporter:research-still-unsafe", "CSV1C_121", false)],
		_slot("slot:active", MEW_UID, []),
		[
			_slot("slot:ho-oh-source", HO_OH_UID, []),
			_slot("slot:ho-oh-target", HO_OH_UID, [_fire_energy(), _fire_energy(), _fire_energy()]),
		],
		5
	)
	after_recovery["observation_version"] = 2
	after_recovery["observation_hash"] = "ethan-ho-oh-low-deck-after-recovery"
	after_recovery["own"]["hand"] = [_fire_energy()]
	after_recovery["own"]["discard"] = [_card(CHARCADET_UID)]
	var facts_after_recovery := _facts(false, false, false, 1, true, true, 0)
	var recover_reopens := _epoch_reopens(
		before, after_recovery, facts_before, facts_after_recovery, recovery_candidate, recovery_frontier
	)
	var flame_frontier := _frontier(after_recovery, {
		"ability:golden-flame-recovered": 520.0,
		"supporter:research-still-unsafe": 180.0,
	}, facts_after_recovery, "ability:golden-flame-recovered")
	var flame_candidate := _candidate(flame_frontier, "ability:golden-flame-recovered")
	_check(not bool(recover_reopens) \
		and str(flame_candidate.get("checkpoint_after", "")) == "information_result", \
		"scenario E deterministic discard recovery must stay in-graph, then Golden Flame owns the next checkpoint")

	var switch := _play_trainer("item:switch-recovered-ho-oh", "CSV1C_113", true)
	switch["target"] = "slot:ho-oh-target"
	var after_flame := _observation(
		[switch],
		_slot("slot:active", MEW_UID, []),
		[
			_slot("slot:ho-oh-source", HO_OH_UID, []),
			_slot("slot:ho-oh-target", HO_OH_UID, [_fire_energy(), _fire_energy(), _fire_energy(), _fire_energy()]),
		],
		5
	)
	after_flame["observation_version"] = 3
	after_flame["observation_hash"] = "ethan-ho-oh-low-deck-after-flame"
	var facts_after_flame := _facts(false, false, false, 0, true, true, 0)
	var flame_reopens := _epoch_reopens(
		after_recovery, after_flame, facts_after_recovery, facts_after_flame, flame_candidate, flame_frontier
	)
	var switch_frontier := _frontier(after_flame, {
		"item:switch-recovered-ho-oh": 500.0,
	}, facts_after_flame, "item:switch-recovered-ho-oh")
	var switch_candidate := _candidate(switch_frontier, "item:switch-recovered-ho-oh")

	var attack := _attack("attack:recovered-shining-wings", "slot:active", HO_OH_UID, 0, 160, true)
	var ready := _observation(
		[
			_play_trainer("supporter:research-after-ready", "CSV1C_121", false),
			attack,
		],
		_slot("slot:active", HO_OH_UID, [_fire_energy(), _fire_energy(), _fire_energy(), _fire_energy()]),
		[
			_slot("slot:mew", MEW_UID, []),
			_slot("slot:ho-oh-source", HO_OH_UID, []),
		],
		5
	)
	ready["own"]["prizes_remaining"] = 2
	ready["opponent"]["active"] = _public_target("PUBLIC_TWO_PRIZE_TARGET", 160, 2)
	var facts_ready := _facts(true, true, false, 0, true, true, 160)
	facts_ready["resources"]["prizes_remaining"] = 2
	facts_ready["prize"] = {"current_swing": 2, "win_now": true}
	var attack_frontier := _frontier(ready, {
		"supporter:research-after-ready": 700.0,
		"attack:recovered-shining-wings": 10.0,
	}, facts_ready, "supporter:research-after-ready")
	var attack_candidate := _candidate(attack_frontier, "attack:recovered-shining-wings")
	var attack_safety := _route_safety(attack_candidate, attack_frontier, facts_ready)
	_check(bool(flame_reopens) \
		and str(switch_candidate.get("route_id", "")) == "route:pivot" \
		and str(attack_safety.get("reason", "")) == "deterministic_win_now", \
		"scenario E recovered Fire must flow through Golden Flame and pivot into the terminal attack")
	_rows.append(_row(
		"low_deck_recover_accelerate_attack",
		"低牌库回收/加速/攻击",
		"牌库仅5张时拒绝博士研究，夜间担架从公开弃牌区拿回基本火能；回收不重开模型，金色火焰补齐第4火能后换位，以闪耀之翼取最后2奖。",
		"item:night-stretcher -> ability:golden-flame-recovered -> item:switch-recovered-ho-oh -> attack:recovered-shining-wings",
		str(attack_safety.get("reason", "")),
		not bool(recover_reopens) and bool(flame_reopens) and bool(attack_safety.get("valid", false))
	))


func _frontier(observation: Dictionary, scores: Dictionary, facts: Dictionary, rule_action_id: String) -> Array[Dictionary]:
	var pool: Array[Dictionary] = RouteSearchScript.new().build_candidate_pool(observation, scores, _manifest, facts)
	var rule_index := -1
	for index: int in pool.size():
		pool[index]["engine_rule_floor_exact"] = false
		if str(pool[index].get("safe_prefix_action_id", "")) == rule_action_id:
			rule_index = index
	if rule_index >= 0:
		var rule_floor: Dictionary = pool[rule_index]
		rule_floor["engine_rule_floor_exact"] = true
		pool.remove_at(rule_index)
		pool.insert(0, rule_floor)
	var annotated: Array[Dictionary] = CapabilityRegistryScript.new().annotate_frontier(
		pool, observation, facts, _profile, _manifest
	)
	_check(not annotated.is_empty() \
		and str(annotated[0].get("safe_prefix_action_id", "")) == rule_action_id, \
		"fixture Rule floor %s must remain exact and first" % rule_action_id)
	_check(not JSON.stringify(annotated).contains("FORBIDDEN_SECRET"), \
		"scenario frontier must never copy hidden sentinels")
	return annotated


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
		"observation_hash": "ethan-ho-oh-complex-scenario",
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
			"bench_slots_free": 2,
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
		"max_hp": 230,
		"prize_count": 2 if uid in [HO_OH_UID, IRON_HANDS_UID, FEZANDIPITI_UID, MEW_UID] else 1,
	}


func _public_target(uid: String, remaining_hp: int, prize_count: int) -> Dictionary:
	return {
		"slot_id": "slot:%s" % uid.to_lower(),
		"pokemon": {"uid": uid},
		"remaining_hp": remaining_hp,
		"prize_count": prize_count,
	}


func _bench(action_id: String, uid: String) -> Dictionary:
	return {
		"id": action_id,
		"kind": "play_basic_to_bench",
		"card": _card(uid),
		"requires_interaction": true,
	}


func _play_trainer(action_id: String, uid: String, interaction: bool) -> Dictionary:
	return {
		"id": action_id,
		"kind": "play_trainer",
		"card": _card(uid),
		"requires_interaction": interaction,
	}


func _ability(action_id: String, source: String, uid: String, interaction: bool, target: String = "") -> Dictionary:
	var action := {
		"id": action_id,
		"kind": "use_ability",
		"source": source,
		"source_card": _card(uid),
		"ability_index": 0,
		"requires_interaction": interaction,
	}
	if target != "":
		action["target"] = target
	return action


func _attack(action_id: String, source: String, uid: String, attack_index: int, damage: int, knockout: bool) -> Dictionary:
	return {
		"id": action_id,
		"kind": "attack",
		"source": source,
		"source_card": _card(uid),
		"attack_index": attack_index,
		"projected_damage": damage,
		"projected_knockout": knockout,
		"requires_interaction": false,
	}


func _end_turn(action_id: String) -> Dictionary:
	return {"id": action_id, "kind": "end_turn"}


func _fire_energy() -> Dictionary:
	return {
		"uid": "CSVE1C_FIR",
		"effect_id": "22db5405bf0cce61a00aa8082cdd1e65",
		"name": "Fire Energy",
		"type": "Basic Energy",
		"energy_type": "R",
		"energy_provides": "R",
		"semantic_roles": ["energy_source", "typed_energy", "basic_energy"],
	}


func _luminous_energy() -> Dictionary:
	return {
		"uid": "CSV1C_127",
		"effect_id": "540ee48bb93584e4bfe3d7f5d0ee0efc",
		"name": "Luminous Energy",
		"type": "Special Energy",
		"energy_type": "",
		"energy_provides": "",
		"semantic_roles": ["energy_source", "typed_energy"],
	}


func _lightning_energy() -> Dictionary:
	return {
		"uid": "PUBLIC_LIGHTNING_ENERGY",
		"name": "Lightning Energy",
		"type": "Basic Energy",
		"energy_type": "L",
		"energy_provides": "L",
		"semantic_roles": ["energy_source", "typed_energy", "basic_energy"],
	}


func _count_energy(slot: Dictionary, symbol: String) -> int:
	var count := 0
	for raw_energy: Variant in slot.get("energy", []):
		if raw_energy is Dictionary \
				and str((raw_energy as Dictionary).get("energy_provides", \
				(raw_energy as Dictionary).get("energy_type", ""))) == symbol:
			count += 1
	return count


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


func _extra_prize_count(slot: PokemonSlot) -> int:
	var result := 0
	for raw_effect: Variant in slot.effects:
		if raw_effect is Dictionary \
				and str((raw_effect as Dictionary).get("type", "")) == "extra_prize":
			result += int((raw_effect as Dictionary).get("count", 0))
	return result


func _extra_prize_certificate(candidate: Dictionary) -> Dictionary:
	var annotation := _module_annotation(candidate, "energy_burst")
	return annotation.get("extra_prize_closeout", {}) \
		if annotation.get("extra_prize_closeout", {}) is Dictionary else {}


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
		"deck_name": "18.0 阿响凤王",
		"strategy_id": str(_profile.get("strategy_id", "")),
		"profile_version": int(_profile.get("profile_version", 0)),
		"round00_baseline": {
			"seeds": [800018539, 800018540, 800018541, 800018542, 800018543],
			"rule_wins": 2,
			"v18cpg_wins": 2,
			"model_calls": 36,
			"accepted_calls": 1,
			"rule_loss_seeds": [800018540, 800018542, 800018543],
		},
		"scenario_count": _rows.size(),
		"passed_count": _rows.filter(func(row: Dictionary) -> bool: return bool(row.get("passed", false))).size(),
		"all_passed": _failures.is_empty() and _rows.size() == 5,
		"production_certificate": {
			"id": "iron_hands_same_route_extra_prize_certificate",
			"status": "resolved_public_deterministic_terminal",
			"reason": "PrizeGraph and EnergyBurst bind the real attack1 extra Prize to an exact public win-now outcome while attack0 remains the Rule floor.",
		},
		"isolation": {
			"profile_modified": true,
			"shared_runtime_modified": true,
			"rule_or_legacy_or_agent_modified": false,
			"hidden_sentinel_absent_from_frontiers": true,
		},
		"coverage": [
			"double Ethan's Ho-Oh plus Charcadet opening",
			"Earthen Vessel information epoch and Golden Flame acceleration",
			"powered Ho-Oh pivot and terminal Shining Wings",
			"minimum two-step Armarouge Fire Off transfer to complete Ho-Oh RRRR",
			"stop optional Fire Off/draw/filter after KO is ready",
			"real Iron Hands Amp You Very Much extra-prize effect",
			"low-deck Night Stretcher recovery without a redundant replan",
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
