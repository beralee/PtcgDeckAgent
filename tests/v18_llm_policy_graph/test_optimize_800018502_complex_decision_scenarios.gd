extends SceneTree

const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const RouteSearchScript = preload("res://scripts/ai/v18_cpg/planning/V18CPGRouteSearch.gd")
const CapabilityRegistryScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCapabilityRegistry.gd")
const MaterialDeltaScript = preload("res://scripts/ai/v18_cpg/observation/V18CPGMaterialDelta.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")

const DECK_ID := 800018502
const MANIFEST_PATH := "res://scripts/ai/v18_cpg/profiles/generated_semantic_manifests/800018502.json"
const REPORT_PATH := "res://tmp/v18cpg/optimization21/800018502/complex_decision_scenarios.json"
const ZOROARK_UID := "CSV10C_145"
const DARUMAKA_UID := "CSV10C_040"
const DARMANITAN_UID := "CSV10C_041"
const RESHIRAM_UID := "CSV10C_166"
const MUNKIDORI_UID := "CSV8C_094"
const BOSS_UID := "CSVH1aC_023"
const RIGID_BAND_UID := "CSV2C_114"
const ARTAZON_UID := "CSV2C_127"
const IONO_UID := "CSV3C_123"
const NIGHT_STRETCHER_UID := "CSV8C_183"
const BLOODMOON_URSALUNA_UID := "CSV8C_172"
const LUMINEON_UID := "CS5bC_049"
const RAICHU_UID := "CS5aC_019"
const MIRAIDON_UID := "CSV1C_050"
const IRON_HANDS_UID := "CSV6C_051"
const ZAPDOS_UID := "CS6aC_057"
const RAIKOU_V_UID := "CS4DaC_137"

var _profile: Dictionary = {}
var _manifest: Dictionary = {}
var _failures: Array[String] = []
var _rows: Array[Dictionary] = []


func _initialize() -> void:
	_profile = ProfileCatalogScript.get_profile_for_deck(DECK_ID)
	_manifest = _load_json(MANIFEST_PATH)
	_check(int(_profile.get("deck_id", 0)) == DECK_ID, "production N's Zoroark profile must load")
	_check(int(_manifest.get("deck_id", 0)) == DECK_ID, "N's Zoroark semantic manifest must load")
	_check(_profile.get("modules", []) == ["copy_attack_toolbox", "partner_chain", "cycle_pivot"], \
		"scenarios must exercise the production N's Zoroark capability composition")

	_scenario_1_complete_darkness_cost_before_trade()
	_scenario_2_evolve_copy_engine_before_optional_bench()
	_scenario_3_ciphermaniac_trade_ppup_order()
	_scenario_4_darmanitan_double_ko_copy_interaction()
	_scenario_5_post_ko_draw_gust_terminal()
	_scenario_6_double_ko_certificate_fail_closed()
	_scenario_7_copy_source_development_preserves_rule_attack()
	_scenario_8_attackless_unbound_gust_hold()
	_scenario_9_iono_reopens_attack_epoch_before_gust()
	_scenario_10_recover_reshiram_before_low_value_copy_attack()
	_write_report()

	EffectProcessor.cleanup_live_instances_for_tests()
	if _failures.is_empty() and _rows.size() == 10:
		print("optimization21 800018502 complex decision scenarios: PASS (10/10)")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("optimization21 800018502 complex decision scenarios: FAIL (%d)" % _failures.size())
	quit(1)


func _scenario_1_complete_darkness_cost_before_trade() -> void:
	var trade := _ability("ability:trade", "slot:active", ZOROARK_UID, true)
	var attach := _attach("attach:second-darkness", "slot:active")
	var observation := _observation(
		[trade, attach],
		_slot("slot:active", ZOROARK_UID, [_darkness_energy()]),
		[_slot("slot:darmanitan", DARMANITAN_UID, [])],
		18
	)
	var facts := _facts(false, false, true, 4, false, false, 0)
	var frontier := _frontier(observation, {
		"ability:trade": 620.0,
		"attach:second-darkness": 20.0,
	}, facts, "ability:trade")
	var attach_candidate := _candidate(frontier, "attach:second-darkness")
	var typed := _module_field(attach_candidate, "copy_attack_toolbox", "typed_attachment")
	var safety := _route_safety(attach_candidate, frontier, facts)
	_check(typed.get("required_symbols", []) == ["D", "D"] \
		and typed.get("missing_before", []) == ["D"] \
		and (typed.get("missing_after", []) as Array).is_empty() \
		and bool(typed.get("target_is_active", false)), \
		"scenario 1 must bind the second Darkness Energy to active Zoroark's exact DD cost")
	_check(bool(safety.get("valid", false)) \
		and str(safety.get("reason", "")) == "module_verified_advantage" \
		and str((safety.get("advantage", {}) as Dictionary).get("certificate_kind", "")) \
		== "public_typed_attack_cost_completion", \
		"scenario 1 cost completion must strictly replace premature Trade through a public certificate")
	_rows.append(_row(
		"complete_darkness_cost_before_trade",
		"填能/攻击闭环",
		"索罗亚克已有1恶能且本回合可攻击时，先把第2恶能贴给前台，立即补齐暗夜王牌DD，而不是先交易制造无必要的信息分支。",
		"attach:second-darkness",
		str((safety.get("advantage", {}) as Dictionary).get("certificate_kind", "")),
		bool(safety.get("valid", false))
	))


func _scenario_2_evolve_copy_engine_before_optional_bench() -> void:
	var evolve := {
		"id": "evolve:ns-zoroark",
		"kind": "evolve",
		"card": _card(ZOROARK_UID),
		"target": "slot:active",
	}
	var bench_fez := {
		"id": "bench:fezandipiti",
		"kind": "play_basic_to_bench",
		"card": _card("CSV8C_135"),
		"requires_interaction": true,
	}
	var observation := _observation(
		[evolve, bench_fez],
		_slot("slot:active", "CSV10C_144", [_darkness_energy()]),
		[
			_slot("slot:reshiram", RESHIRAM_UID, []),
			_slot("slot:darmanitan", DARMANITAN_UID, []),
		],
		22
	)
	var facts := _facts(false, false, true, 5, false, false, 0)
	var frontier := _frontier(observation, {
		"evolve:ns-zoroark": 500.0,
		"bench:fezandipiti": 460.0,
	}, facts, "evolve:ns-zoroark")
	var evolve_candidate := _candidate(frontier, "evolve:ns-zoroark")
	var roles: Array = evolve_candidate.get("action_semantic_roles", []) \
		if evolve_candidate.get("action_semantic_roles", []) is Array else []
	var copy_annotation := _module_annotation(evolve_candidate, "copy_attack_toolbox")
	_check(str(evolve_candidate.get("route_id", "")) == "route:evolve" \
		and "evolution_piece" in roles and "copy_source" in roles \
		and "ability_engine" in roles, \
		"scenario 2 evolution must establish both the copy attacker and Trade engine")
	_check("bind_copy_source" in (copy_annotation.get("decision_hints", []) as Array) \
		and "verify_copied_cost_and_effect" in (copy_annotation.get("decision_hints", []) as Array), \
		"scenario 2 copy module must keep exact source/effect binding after evolution")
	var safety := _route_safety(evolve_candidate, frontier, facts)
	_check(bool(safety.get("valid", false)) and str(safety.get("reason", "")) == "matches_rules_floor", \
		"scenario 2 exact evolution must remain the Rule-floor-safe root before optional benching")
	_rows.append(_row(
		"evolve_copy_engine_before_optional_bench",
		"进化/复制引擎",
		"场上已有N的莱希拉姆与N的达摩狒狒复制源时，优先进化索罗亚为索罗亚克ex，建立交易与暗夜王牌，再考虑吉雉鸡占用备战位。",
		"evolve:ns-zoroark",
		"exact_rule_floor_with_copy_source_binding",
		bool(safety.get("valid", false))
	))


func _scenario_3_ciphermaniac_trade_ppup_order() -> void:
	var cipher := _play_trainer("supporter:ciphermaniac", "CSV7C_191", true)
	var iono := _play_trainer("supporter:iono", "CSV3C_123", false)
	var before := _observation(
		[cipher, iono],
		_slot("slot:active", "CSV4C_044", []),
		[
			_slot("slot:zoroark", ZOROARK_UID, []),
			_slot("slot:reshiram", RESHIRAM_UID, []),
		],
		17
	)
	before["observation_version"] = 1
	before["observation_hash"] = "ns-zoroark-before-cipher"
	var facts_before := _facts(false, false, true, 4, false, false, 0)
	var frontier_before := _frontier(before, {
		"supporter:ciphermaniac": 510.0,
		"supporter:iono": 500.0,
	}, facts_before, "supporter:ciphermaniac")
	var cipher_candidate := _candidate(frontier_before, "supporter:ciphermaniac")
	var iono_candidate := _candidate(frontier_before, "supporter:iono")
	var iono_safety := _route_safety(iono_candidate, frontier_before, facts_before)
	_check(str(cipher_candidate.get("route_id", "")) == "route:information" \
		and str(cipher_candidate.get("checkpoint_after", "")) == "information_result" \
		and not bool(iono_safety.get("valid", true)), \
		"scenario 3 Ciphermaniac must resolve as the exact supporter checkpoint before Iono")

	var trade := _ability("ability:trade", "slot:zoroark", ZOROARK_UID, true)
	var after_cipher := _observation(
		[trade],
		_slot("slot:active", "CSV4C_044", []),
		[
			_slot("slot:zoroark", ZOROARK_UID, []),
			_slot("slot:reshiram", RESHIRAM_UID, []),
		],
		17
	)
	after_cipher["observation_version"] = 2
	after_cipher["observation_hash"] = "ns-zoroark-after-cipher"
	after_cipher["own"]["hand"] = [_card("CSV10C_190"), _darkness_energy(), {"uid": "VISIBLE_SAFE_TRADE_FODDER"}]
	var facts_after_cipher := _facts(false, false, true, 3, false, false, 0)
	var cipher_delta := MaterialDeltaScript.new().compare(before, after_cipher, facts_before, facts_after_cipher)
	var cipher_reopens: bool = _epoch_strategy().call("_should_reopen_information_epoch", \
		"local_gate", {
			"owner": "local_gate",
			"success": true,
			"route_id": str(cipher_candidate.get("route_id", "")),
			"candidate_id": str(cipher_candidate.get("candidate_id", "")),
		}, cipher_delta, frontier_before)
	var trade_frontier := _frontier(after_cipher, {"ability:trade": 480.0}, facts_after_cipher, "ability:trade")
	var trade_candidate := _candidate(trade_frontier, "ability:trade")
	_check(bool(cipher_reopens) and str(trade_candidate.get("checkpoint_after", "")) == "information_result", \
		"scenario 3 known top-deck result must reopen exactly once into Trade")

	var pp_up := _play_trainer("item:ns-pp-up", "CSV10C_190", true)
	var after_trade := _observation(
		[pp_up],
		_slot("slot:active", "CSV4C_044", []),
		[
			_slot("slot:zoroark", ZOROARK_UID, []),
			_slot("slot:reshiram", RESHIRAM_UID, []),
		],
		15
	)
	after_trade["observation_version"] = 3
	after_trade["observation_hash"] = "ns-zoroark-after-trade"
	after_trade["own"]["discard"] = [_darkness_energy()]
	var facts_after_trade := _facts(false, false, true, 4, false, false, 0)
	var trade_delta := MaterialDeltaScript.new().compare(after_cipher, after_trade, facts_after_cipher, facts_after_trade)
	var trade_reopens: bool = _epoch_strategy().call("_should_reopen_information_epoch", \
		"local_gate", {
			"owner": "local_gate",
			"success": true,
			"route_id": str(trade_candidate.get("route_id", "")),
			"candidate_id": str(trade_candidate.get("candidate_id", "")),
		}, trade_delta, trade_frontier)
	var pp_frontier := _frontier(after_trade, {"item:ns-pp-up": 430.0}, facts_after_trade, "item:ns-pp-up")
	var pp_candidate := _candidate(pp_frontier, "item:ns-pp-up")
	_check(bool(trade_reopens) \
		and "trainer_plan_piece" in (pp_candidate.get("action_semantic_roles", []) as Array) \
		and bool((pp_candidate.get("action_ref", {}) as Dictionary).get("requires_interaction", false)), \
		"scenario 3 Trade result must expose the real N's PP Up assignment step before hand attachment")
	_rows.append(_row(
		"ciphermaniac_trade_ppup_order",
		"支援者/抽牌/加速顺序",
		"先用暗码迷的解读把PP提升剂与恶能置顶，再以交易抽到，最后由PP提升剂把弃牌区基本能量贴给备战N的宝可梦；每次未知信息只重开一次决策。",
		"supporter:ciphermaniac -> ability:trade -> item:ns-pp-up",
		"two_material_information_epoch_reopens",
		bool(cipher_reopens) and bool(trade_reopens)
	))


func _scenario_4_darmanitan_double_ko_copy_interaction() -> void:
	var processor := EffectProcessor.new()
	var state := _game_state()
	var zoroark_data := _zoroark_data()
	var darmanitan_data := _darmanitan_data()
	processor.register_pokemon_card(zoroark_data)
	processor.register_pokemon_card(darmanitan_data)
	var zoroark := _real_slot(zoroark_data, 0)
	zoroark.attached_energy.append(_real_energy(0))
	zoroark.attached_energy.append(_real_energy(0))
	var darmanitan := _real_slot(darmanitan_data, 0)
	state.players[0].active_pokemon = zoroark
	state.players[0].bench.append(darmanitan)
	var opponent_active := _real_public_target(
		"Zapdos", 90, "", 1, "CS6aC", "057", "03bcecb40c957575e16b4af22b08b7bd"
	)
	var two_prize_bench := _real_public_target(
		"Iron Hands ex", 280, "ex", 1, "CSV6C", "051", "e9f0c124fc2e352af2408a7e61862b95"
	)
	two_prize_bench.damage_counters = 190
	state.players[1].active_pokemon = opponent_active
	state.players[1].bench = [two_prize_bench]

	var observation := _observation(
		[
			_ability("ability:trade", _real_slot_id(zoroark), ZOROARK_UID, true),
			_attack("attack:night-joker-immolating", _real_slot_id(zoroark), ZOROARK_UID, 0, 0, false),
		],
		_slot(_real_slot_id(zoroark), ZOROARK_UID, [_darkness_energy(), _darkness_energy()]),
		[_slot(_real_slot_id(darmanitan), DARMANITAN_UID, [])],
		12
	)
	observation["own"]["prizes_remaining"] = 3
	observation["opponent"]["active"] = _public_slot_ref(opponent_active)
	observation["opponent"]["bench"] = [_public_slot_ref(two_prize_bench)]
	var facts := _facts(false, false, false, 3, false, false, 0)
	facts["resources"]["prizes_remaining"] = 3
	var frontier := _frontier(observation, {
		"ability:trade": 700.0,
		"attack:night-joker-immolating": 10.0,
	}, facts, "ability:trade")
	var attack_candidate := _candidate(frontier, "attack:night-joker-immolating")
	var route_safety := _route_safety(attack_candidate, frontier, facts)
	var advantage: Dictionary = route_safety.get("advantage", {}) \
		if route_safety.get("advantage", {}) is Dictionary else {}
	_check(bool(route_safety.get("valid", false)) \
		and str(route_safety.get("reason", "")) == "module_verified_advantage" \
		and str(advantage.get("proof_kind", "")) == "public_copy_double_knockout_three_prize_closeout" \
		and int(advantage.get("prizes_floor", 0)) == 3 \
		and bool(advantage.get("win_now", false)), \
		"scenario 4 production copy module must certify the exact Rule Trade floor and complete three-prize suffix")

	var copy_steps := processor.get_attack_interaction_steps_by_id(
		zoroark_data.effect_id, 0, zoroark.get_top_card(), zoroark_data.attacks[0], state
	)
	var copy_step: Dictionary = {}
	for raw_step: Variant in copy_steps:
		if raw_step is Dictionary and str((raw_step as Dictionary).get("id", "")) == "copied_attack":
			copy_step = raw_step
			break
	var interaction_context := {
		"v18cpg_observation": observation,
		"v18cpg_facts": facts,
	}
	var registry := CapabilityRegistryScript.new()
	var copy_override := registry.pick_verified_interaction_override(
		copy_step.get("items", []), copy_step, [], interaction_context, _profile,
		str(advantage.get("certificate_kind", ""))
	)
	var immolating_option: Dictionary = (copy_override.get("items", []) as Array)[0] \
		if bool(copy_override.get("handled", false)) and (copy_override.get("items", []) as Array).size() == 1 \
		and (copy_override.get("items", []) as Array)[0] is Dictionary else {}
	_check(not immolating_option.is_empty() \
		and str(copy_step.get("id", "")) == "copied_attack" \
		and str((immolating_option.get("attack", {}) as Dictionary).get("damage", "")) == "90", \
		"scenario 4 real Night Joker interaction must expose Darmanitan's 90-damage Immolating Cannon")
	var wrong_kind_override := registry.pick_verified_interaction_override(
		copy_step.get("items", []), copy_step, [], interaction_context, _profile,
		"public_typed_attack_cost_completion"
	)
	var wrong_copy_option := immolating_option.duplicate(true)
	wrong_copy_option["attack_index"] = 0
	var wrong_copy_override := registry.pick_verified_interaction_override(
		[wrong_copy_option], copy_step, [], interaction_context, _profile,
		str(advantage.get("certificate_kind", ""))
	)
	_check(not bool(wrong_kind_override.get("handled", false)) \
		and not bool(wrong_copy_override.get("handled", false)), \
		"scenario 4 interaction owner must reject a foreign certificate and a mismatched copied attack")

	var copied_context := {"copied_attack": [immolating_option]}
	var followups := processor.get_attack_followup_interaction_steps_by_id(
		zoroark_data.effect_id, 0, zoroark.get_top_card(), zoroark_data.attacks[0], state, copied_context
	)
	var bench_step: Dictionary = {}
	for raw_step: Variant in followups:
		if raw_step is Dictionary \
				and str((raw_step as Dictionary).get("id", "")) == "opponent_bench_damage_targets":
			bench_step = raw_step
			break
	var target_override := registry.pick_verified_interaction_override(
		bench_step.get("items", []), bench_step, [], interaction_context, _profile,
		str(advantage.get("certificate_kind", ""))
	)
	var target_items: Array = target_override.get("items", []) \
		if target_override.get("items", []) is Array else []
	var picked_target: PokemonSlot = target_items[0] \
		if bool(target_override.get("handled", false)) and target_items.size() == 1 \
		and target_items[0] is PokemonSlot else null
	_check(str(bench_step.get("id", "")) == "opponent_bench_damage_targets" \
		and picked_target == two_prize_bench, \
		"scenario 4 production certificate must own and bind the exact 90-HP Iron Hands ex target")
	two_prize_bench.attached_energy.append(_real_energy(1))
	var protected_target_override := registry.pick_verified_interaction_override(
		bench_step.get("items", []), bench_step, [], interaction_context, _profile,
		str(advantage.get("certificate_kind", ""))
	)
	two_prize_bench.attached_energy.clear()
	_check(not bool(protected_target_override.get("handled", false)), \
		"scenario 4 interaction owner must revalidate the live target and fail closed after public energy changes")

	var targets := [{
		"copied_attack": [immolating_option],
		"opponent_bench_damage_targets": [picked_target],
	}]
	var active_damage := processor.get_attack_damage_modifier(
		zoroark, opponent_active, zoroark_data.attacks[0], state, targets, 0
	)
	DamageCalculator.new().apply_damage_to_slot(opponent_active, active_damage)
	processor.execute_attack_effect_by_id(
		zoroark_data.effect_id, 0, zoroark, opponent_active, state, targets
	)
	_check(active_damage == 90 \
		and opponent_active.is_knocked_out() \
		and two_prize_bench.damage_counters == 280 \
		and two_prize_bench.is_knocked_out() \
		and opponent_active.get_prize_count() + two_prize_bench.get_prize_count() == 3 \
		and zoroark.attached_energy.is_empty() \
		and state.players[0].discard_pile.size() == 2, \
		"scenario 4 real EffectProcessor suffix must KO both public targets, win three prizes, and discard both Darkness Energy")
	_rows.append(_row(
		"night_joker_immolating_cannon_double_ko",
		"复制交互/双KO关键奖",
		"暗夜王牌精确复制N的达摩狒狒【焚身加农炮】，前台90击倒单奖、后台90击倒双奖，并绑定高奖赏后台目标；真实效果结算后弃光索罗亚克能量。",
		"copy:Immolating Cannon -> target:public two-prize bench -> attack",
		str(advantage.get("proof_kind", "")),
		bool(advantage.get("win_now", false)) and bool(route_safety.get("valid", false))
	))


func _scenario_5_post_ko_draw_gust_terminal() -> void:
	var fez_draw := _ability("ability:flip-the-script", "slot:fez", "CSV8C_135", true)
	var before := _observation(
		[fez_draw],
		_slot("slot:active", "CSV4C_044", []),
		[
			_slot("slot:zoroark", ZOROARK_UID, [_darkness_energy(), _darkness_energy()]),
			_slot("slot:darmanitan", DARMANITAN_UID, []),
			_slot("slot:fez", "CSV8C_135", []),
		],
		10
	)
	before["observation_version"] = 1
	before["observation_hash"] = "ns-zoroark-post-ko-before-fez"
	var facts_before := _facts(false, false, false, 2, false, false, 0)
	var draw_frontier := _frontier(before, {"ability:flip-the-script": 520.0}, facts_before, "ability:flip-the-script")
	var draw_candidate := _candidate(draw_frontier, "ability:flip-the-script")

	var counter := _play_trainer("item:counter-catcher", "CSV6C_114", true)
	counter["target"] = "slot:opponent-bench-ex"
	var after_draw := _observation(
		[counter],
		_slot("slot:active", "CSV4C_044", []),
		[
			_slot("slot:zoroark", ZOROARK_UID, [_darkness_energy(), _darkness_energy()]),
			_slot("slot:darmanitan", DARMANITAN_UID, []),
			_slot("slot:fez", "CSV8C_135", []),
		],
		7
	)
	after_draw["observation_version"] = 2
	after_draw["observation_hash"] = "ns-zoroark-post-ko-after-fez"
	after_draw["own"]["hand"] = [_card("CSV6C_114"), {"uid": "VISIBLE_DRAW_RESULT"}]
	after_draw["own"]["prizes_remaining"] = 2
	after_draw["opponent"]["bench"] = [{
		"slot_id": "slot:opponent-bench-ex",
		"pokemon": {"uid": "PUBLIC_TWO_PRIZE_TARGET"},
		"remaining_hp": 90,
		"prize_count": 2,
	}]
	var facts_after_draw := _facts(false, false, false, 2, true, false, 0)
	facts_after_draw["resources"]["prizes_remaining"] = 2
	var draw_delta := MaterialDeltaScript.new().compare(before, after_draw, facts_before, facts_after_draw)
	var draw_reopens: bool = _epoch_strategy().call("_should_reopen_information_epoch", \
		"local_gate", {
			"owner": "local_gate",
			"success": true,
			"route_id": str(draw_candidate.get("route_id", "")),
			"candidate_id": str(draw_candidate.get("candidate_id", "")),
		}, draw_delta, draw_frontier)
	var gust_frontier := _frontier(after_draw, {"item:counter-catcher": 470.0}, facts_after_draw, "item:counter-catcher")
	var gust_candidate := _candidate(gust_frontier, "item:counter-catcher")
	_check(bool(draw_reopens) \
		and str(gust_candidate.get("route_id", "")) == "route:gust" \
		and str((gust_candidate.get("action_ref", {}) as Dictionary).get("target", "")) == "slot:opponent-bench-ex", \
		"scenario 5 post-KO draw must reopen into the exact Counter Catcher target")

	var attack := _attack("attack:night-joker-terminal", "slot:active", ZOROARK_UID, 0, 90, true)
	var after_gust := _observation(
		[
			_ability("ability:trade-too-late", "slot:active", ZOROARK_UID, true),
			attack,
		],
		_slot("slot:active", ZOROARK_UID, [_darkness_energy(), _darkness_energy()]),
		[_slot("slot:darmanitan", DARMANITAN_UID, [])],
		7
	)
	after_gust["observation_version"] = 3
	after_gust["observation_hash"] = "ns-zoroark-post-ko-after-gust"
	after_gust["own"]["prizes_remaining"] = 2
	after_gust["opponent"]["active"] = {
		"slot_id": "slot:opponent-bench-ex",
		"pokemon": {"uid": "PUBLIC_TWO_PRIZE_TARGET"},
		"remaining_hp": 90,
		"prize_count": 2,
	}
	var facts_after_gust := _facts(true, true, false, 2, true, false, 90)
	facts_after_gust["resources"]["prizes_remaining"] = 2
	facts_after_gust["prize"] = {"current_swing": 2, "win_now": true}
	var gust_delta := MaterialDeltaScript.new().compare(after_draw, after_gust, facts_after_draw, facts_after_gust)
	var gust_reopens: bool = _epoch_strategy().call("_should_reopen_information_epoch", \
		"local_gate", {
			"owner": "local_gate",
			"success": true,
			"route_id": str(gust_candidate.get("route_id", "")),
			"candidate_id": str(gust_candidate.get("candidate_id", "")),
		}, gust_delta, gust_frontier)
	var attack_frontier := _frontier(after_gust, {
		"ability:trade-too-late": 650.0,
		"attack:night-joker-terminal": 10.0,
	}, facts_after_gust, "ability:trade-too-late")
	var attack_candidate := _candidate(attack_frontier, "attack:night-joker-terminal")
	var safety := _route_safety(attack_candidate, attack_frontier, facts_after_gust)
	_check(bool(gust_reopens) \
		and bool((attack_candidate.get("outcome", {}) as Dictionary).get("win_now", false)) \
		and str(safety.get("reason", "")) == "deterministic_win_now", \
		"scenario 5 gust result must reopen into the final two-prize attack and block late Trade churn")
	_rows.append(_row(
		"post_ko_draw_gust_terminal",
		"被击倒后重建/终局",
		"上回合被击倒后先用吉雉鸡ex取得公开新信息，随后反击捕捉器拉出90HP双奖目标，换入已充能索罗亚克并立刻用暗夜王牌终结，不再交易。",
		"ability:flip-the-script -> item:counter-catcher -> attack:night-joker-terminal",
		str(safety.get("reason", "")),
		bool(draw_reopens) and bool(gust_reopens) and bool(safety.get("valid", false))
	))


func _scenario_6_double_ko_certificate_fail_closed() -> void:
	var base := _observation(
		[
			_ability("ability:trade", "slot:zoroark", ZOROARK_UID, true),
			_attack("attack:night-joker-immolating", "slot:zoroark", ZOROARK_UID, 0, 0, false),
		],
		_slot("slot:zoroark", ZOROARK_UID, [_darkness_energy(), _darkness_energy()]),
		[_slot("slot:darmanitan", DARMANITAN_UID, [])],
		12
	)
	base["own"]["prizes_remaining"] = 3
	base["opponent"]["active"] = {
		"slot_id": "slot:zapdos",
		"pokemon": {
			"uid": "CS6aC_057",
			"effect_id": "03bcecb40c957575e16b4af22b08b7bd",
		},
		"energy": [],
		"tool": {},
		"remaining_hp": 90,
		"max_hp": 90,
		"prize_count": 1,
		"tera": false,
	}
	base["opponent"]["bench"] = [{
		"slot_id": "slot:iron-hands",
		"pokemon": {
			"uid": "CSV6C_051",
			"effect_id": "e9f0c124fc2e352af2408a7e61862b95",
		},
		"energy": [],
		"tool": {},
		"remaining_hp": 90,
		"max_hp": 280,
		"prize_count": 2,
		"tera": false,
	}]
	var facts := _facts(false, false, false, 3, false, false, 0)
	facts["resources"]["prizes_remaining"] = 3
	var negative_cases := [
		"own_prizes_not_three",
		"active_outside_ninety_breakpoint",
		"bench_outside_ninety_breakpoint",
		"bench_not_two_prizes",
		"extra_opponent_bench",
		"target_has_energy",
		"target_has_tool",
		"target_is_tera",
		"copy_source_missing",
		"copy_source_effect_mismatch",
		"attack_window_closed",
		"attacker_effect_mismatch",
	]
	var all_failed_closed := true
	for case_id: String in negative_cases:
		var observation := base.duplicate(true)
		match case_id:
			"own_prizes_not_three":
				observation["own"]["prizes_remaining"] = 4
			"active_outside_ninety_breakpoint":
				observation["opponent"]["active"]["remaining_hp"] = 91
			"bench_outside_ninety_breakpoint":
				observation["opponent"]["bench"][0]["remaining_hp"] = 91
			"bench_not_two_prizes":
				observation["opponent"]["bench"][0]["prize_count"] = 1
			"extra_opponent_bench":
				observation["opponent"]["bench"].append({
					"slot_id": "slot:extra", "pokemon": {"uid": "PUBLIC_EXTRA"},
					"energy": [], "tool": {}, "remaining_hp": 50, "prize_count": 1,
				})
			"target_has_energy":
				observation["opponent"]["bench"][0]["energy"] = [_darkness_energy()]
			"target_has_tool":
				observation["opponent"]["bench"][0]["tool"] = {"uid": "PUBLIC_TOOL"}
			"target_is_tera":
				observation["opponent"]["bench"][0]["tera"] = true
			"copy_source_missing":
				observation["own"]["bench"] = []
			"copy_source_effect_mismatch":
				observation["own"]["bench"][0]["pokemon"]["effect_id"] = "WRONG_PUBLIC_EFFECT"
			"attack_window_closed":
				observation["turn"]["deterministic_attack_window_open"] = false
			"attacker_effect_mismatch":
				observation["legal_actions"][1]["source_card"]["effect_id"] = "WRONG_PUBLIC_EFFECT"
		var frontier := _frontier(observation, {
			"ability:trade": 700.0,
			"attack:night-joker-immolating": 10.0,
		}, facts, "ability:trade")
		var attack_candidate := _candidate(frontier, "attack:night-joker-immolating")
		var suffix := _module_field(attack_candidate, "copy_attack_toolbox", "strict_copy_suffix")
		var safety := _route_safety(attack_candidate, frontier, facts)
		var failed_closed := not bool(suffix.get("verified", false)) \
			and not bool(safety.get("valid", false))
		all_failed_closed = all_failed_closed and failed_closed
		_check(failed_closed, "scenario 6 negative %s must not mint or accept the strict suffix" % case_id)

	var no_exact_floor_frontier := _frontier(base.duplicate(true), {
		"ability:trade": 700.0,
		"attack:night-joker-immolating": 10.0,
	}, facts, "ability:trade")
	for candidate: Dictionary in no_exact_floor_frontier:
		candidate["engine_rule_floor_exact"] = false
	var no_floor_attack := _candidate(no_exact_floor_frontier, "attack:night-joker-immolating")
	var no_floor_safety := _route_safety(no_floor_attack, no_exact_floor_frontier, facts)
	var tampered_frontier := _frontier(base.duplicate(true), {
		"ability:trade": 700.0,
		"attack:night-joker-immolating": 10.0,
	}, facts, "ability:trade")
	var tampered_attack := _candidate(tampered_frontier, "attack:night-joker-immolating")
	var tampered_suffix := _module_field(tampered_attack, "copy_attack_toolbox", "strict_copy_suffix")
	tampered_suffix["bench_target_slot_id"] = "slot:tampered"
	var tampered_safety := _route_safety(tampered_attack, tampered_frontier, facts)
	var floor_and_tamper_failed := not bool(no_floor_safety.get("valid", false)) \
		and not bool(tampered_safety.get("valid", false))
	_check(floor_and_tamper_failed, \
		"scenario 6 must reject a non-exact Rule floor and any post-annotation suffix tampering: floor=%s tamper=%s" \
		% [JSON.stringify(no_floor_safety), JSON.stringify(tampered_safety)])
	_rows.append(_row(
		"darmanitan_double_ko_strict_negative_matrix",
		"严格优势证书/失败关闭",
		"完整复制后缀只在精确公开状态成立；奖卡、血量、卡牌身份、场面数量、防护、攻击窗口、Rule floor 或证书字段任一不符都拒绝升级。",
		"12 public-state negatives + Rule-floor negative + certificate tamper",
		"copy_attack_complete_suffix_unproven",
		all_failed_closed and floor_and_tamper_failed
	))


func _scenario_7_copy_source_development_preserves_rule_attack() -> void:
	var bench_munkidori := {
		"id": "bench:munkidori",
		"kind": "play_basic_to_bench",
		"card": _card(MUNKIDORI_UID),
	}
	var bench_darumaka := {
		"id": "bench:darumaka",
		"kind": "play_basic_to_bench",
		"card": _card(DARUMAKA_UID),
	}
	var preserved_attack := _attack(
		"attack:night-joker-preserved", "slot:zoroark", ZOROARK_UID, 0, 90, false
	)
	var base := _observation(
		[bench_munkidori, bench_darumaka, preserved_attack],
		_slot("slot:zoroark", ZOROARK_UID, [_darkness_energy(), _darkness_energy()]),
		[_slot("slot:reshiram", RESHIRAM_UID, [])],
		20
	)
	base["own"]["prizes_remaining"] = 3
	base["own"]["hand"] = [
		_card(MUNKIDORI_UID),
		_card(DARUMAKA_UID),
		_card(DARMANITAN_UID),
	]
	base["own"]["discard_counts"] = {}
	var facts := _facts(true, false, false, 3, false, false, 90)
	facts["resources"]["prizes_remaining"] = 3
	facts["resources"]["bench_slots_free"] = 4
	var scores := {
		"bench:munkidori": 700.0,
		"bench:darumaka": 20.0,
		"attack:night-joker-preserved": 500.0,
	}
	var frontier := _frontier(base, scores, facts, "bench:munkidori")
	var darumaka := _candidate(frontier, "bench:darumaka")
	var source_development := _module_field(
		darumaka, "copy_attack_toolbox", "source_development"
	)
	var safety := _route_safety(darumaka, frontier, facts)
	var pruned := RouteSearchScript.new().prune_frontier(frontier, 2)
	var rescued := not _candidate(pruned, "bench:darumaka").is_empty()

	var after := _observation(
		[preserved_attack],
		_slot("slot:zoroark", ZOROARK_UID, [_darkness_energy(), _darkness_energy()]),
		[
			_slot("slot:reshiram", RESHIRAM_UID, []),
			_slot("slot:darumaka", DARUMAKA_UID, []),
		],
		20
	)
	after["own"]["prizes_remaining"] = 3
	after["own"]["hand"] = [_card(DARMANITAN_UID)]
	after["own"]["discard_counts"] = {}
	var after_facts := _facts(true, false, false, 1, false, false, 90)
	after_facts["resources"]["prizes_remaining"] = 3
	after_facts["resources"]["bench_slots_free"] = 3
	var after_frontier := _frontier(after, {"attack:night-joker-preserved": 500.0}, after_facts, \
		"attack:night-joker-preserved")
	var after_attack := _candidate(after_frontier, "attack:night-joker-preserved")
	var suffix_preserved := str(source_development.get("preserved_attack_candidate_id", "")) \
		== str(after_attack.get("candidate_id", "")) \
		and str(source_development.get("preserved_attack_action_id", "")) \
		== str(after_attack.get("safe_prefix_action_id", "")) \
		and bool(source_development.get("attack_quota_preserved", false)) \
		and bool(source_development.get("energy_quota_preserved", false)) \
		and bool(source_development.get("supporter_quota_preserved", false)) \
		and not bool(source_development.get("information_checkpoint_crossed", true))
	_check(bool(source_development.get("verified", false)) \
		and rescued \
		and bool(safety.get("valid", false)) \
		and str(safety.get("reason", "")) == "module_verified_advantage" \
		and str((safety.get("advantage", {}) as Dictionary).get("certificate_kind", "")) \
		== "public_copy_source_development_preserved_attack" \
		and suffix_preserved, \
		"scenario 7 must rescue public Darumaka only when Darmanitan is in hand and the exact Rule attack survives: proof=%s safety=%s pruned=%s after=%s" \
		% [JSON.stringify(source_development), JSON.stringify(safety), JSON.stringify(pruned), JSON.stringify(after_attack)])

	var negative_cases := [
		"occupied_bench",
		"missing_evolution",
		"discarded_or_prized_source",
		"wrong_prize",
		"lost_attack",
		"hidden_search",
		"munkidori_urgency",
	]
	var all_failed_closed := true
	for case_id: String in negative_cases:
		var observation := base.duplicate(true)
		var case_facts := facts.duplicate(true)
		var case_scores := scores.duplicate(true)
		match case_id:
			"occupied_bench":
				observation["own"]["bench"].append(_slot("slot:occupied-1", "CSV10C_144", []))
				observation["own"]["bench"].append(_slot("slot:occupied-2", "CSV10C_166", []))
				observation["own"]["bench"].append(_slot("slot:occupied-3", "CSV8C_135", []))
				case_facts["resources"]["bench_slots_free"] = 1
			"missing_evolution":
				observation["own"]["hand"] = [_card(MUNKIDORI_UID), _card(DARUMAKA_UID)]
			"discarded_or_prized_source":
				observation["own"]["hand"] = [_card(MUNKIDORI_UID), _card(DARUMAKA_UID)]
				observation["own"]["discard_counts"] = {DARMANITAN_UID: 1}
			"wrong_prize":
				observation["own"]["prizes_remaining"] = 2
				case_facts["resources"]["prizes_remaining"] = 2
			"lost_attack":
				observation["legal_actions"] = [bench_munkidori, bench_darumaka]
				case_facts["attack"]["ready"] = false
			"hidden_search":
				observation["own"]["hand"] = [_card(MUNKIDORI_UID), _card(DARUMAKA_UID)]
				observation["legal_actions"].append(_play_trainer("search:hidden-evolution", "CSV9C_198", true))
				case_scores["search:hidden-evolution"] = 100.0
			"munkidori_urgency":
				observation["own"]["active"]["damage"] = 30
				observation["own"]["active"]["remaining_hp"] = 170
		var negative_frontier := _frontier(
			observation, case_scores, case_facts, "bench:munkidori"
		)
		var negative_candidate := _candidate(negative_frontier, "bench:darumaka")
		var negative_proof := _module_field(
			negative_candidate, "copy_attack_toolbox", "source_development"
		)
		var negative_safety := _route_safety(negative_candidate, negative_frontier, case_facts)
		var failed_closed := not bool(negative_proof.get("verified", false)) \
			and not bool(negative_safety.get("valid", false))
		all_failed_closed = all_failed_closed and failed_closed
		_check(failed_closed, "scenario 7 negative %s must fail closed" % case_id)

	var tampered := frontier.duplicate(true)
	var tampered_candidate := _candidate(tampered, "bench:darumaka")
	var tampered_proof := _module_field(tampered_candidate, "copy_attack_toolbox", "source_development")
	tampered_proof["preserved_attack_action_id"] = "attack:tampered"
	var tampered_safety := _route_safety(tampered_candidate, tampered, facts)
	var tamper_failed := not bool(tampered_safety.get("valid", false))
	_check(tamper_failed, "scenario 7 source-development binding must reject a tampered Rule attack suffix")
	var zero_wire_when_unprofiled := _source_development_zero_wire_fixture()
	_rows.append(_row(
		"copy_source_development_preserves_rule_attack",
		"复制源构建/完整后缀",
		"只有达摩狒狒已公开在手、三奖窗口、至少保留一个备战位、前台索罗亚克已满足DD且当前Rule的愿增猿没有搬伤价值时，火红不倒翁才可替代同配额愿增猿；完整暗夜王牌攻击候选、能量/支援者/攻击配额均保持。",
		"bench:darumaka -> attack:night-joker-preserved",
		"public_copy_source_development_preserved_attack",
		bool(source_development.get("verified", false)) and suffix_preserved \
			and all_failed_closed and tamper_failed and zero_wire_when_unprofiled
	))


func _source_development_zero_wire_fixture() -> bool:
	var trade := _ability("wire:trade", "slot:zoroark", ZOROARK_UID, true)
	var attach := _attach("wire:attach", "slot:zoroark")
	var observation := _observation(
		[trade, attach],
		_slot("slot:zoroark", ZOROARK_UID, [_darkness_energy()]),
		[_slot("slot:reshiram", RESHIRAM_UID, [])],
		20
	)
	var facts := _facts(false, false, true, 4, false, false, 0)
	facts["resources"]["bench_slots_free"] = 4
	var scores := {"wire:trade": 500.0, "wire:attach": 450.0}
	var pool: Array[Dictionary] = RouteSearchScript.new().build_candidate_pool(
		observation, scores, _manifest, facts
	)
	for candidate: Dictionary in pool:
		candidate["engine_rule_floor_exact"] = str(candidate.get("safe_prefix_action_id", "")) == "wire:trade"
	var profile_without_local := _profile.duplicate(true)
	var local_parameters: Dictionary = profile_without_local.get("local_action_certificate_parameters", {}) \
		if profile_without_local.get("local_action_certificate_parameters", {}) is Dictionary else {}
	local_parameters.erase("copy_attack_toolbox")
	if local_parameters.is_empty():
		profile_without_local.erase("local_action_certificate_parameters")
	else:
		profile_without_local["local_action_certificate_parameters"] = local_parameters
	var with_local: Array[Dictionary] = CapabilityRegistryScript.new().annotate_frontier(
		pool, observation, facts, _profile, _manifest
	)
	var without_local: Array[Dictionary] = CapabilityRegistryScript.new().annotate_frontier(
		pool, observation, facts, profile_without_local, _manifest
	)
	var wire_strategy = StrategyScript.new()
	var compact_with: Array[Dictionary] = wire_strategy.call("_compact_frontier_for_model", with_local)
	var compact_without: Array[Dictionary] = wire_strategy.call("_compact_frontier_for_model", without_local)
	var factored_with: Dictionary = wire_strategy.call(
		"_factor_common_capability_context", compact_with
	)
	var factored_without: Dictionary = wire_strategy.call(
		"_factor_common_capability_context", compact_without
	)
	var with_profile_strategy = StrategyScript.new()
	with_profile_strategy.configure_profile(_profile, _manifest)
	var without_profile_strategy = StrategyScript.new()
	without_profile_strategy.configure_profile(profile_without_local, _manifest)
	var wire_with := JSON.stringify({
		"profile": with_profile_strategy.call("_profile_summary_for_model", {}),
		"frontier": factored_with,
	})
	var wire_without := JSON.stringify({
		"profile": without_profile_strategy.call("_profile_summary_for_model", {}),
		"frontier": factored_without,
	})
	var passed := wire_with == wire_without \
		and not wire_with.contains("public_copy_source_development_preserved_attack") \
		and not wire_with.contains("source_development_suffix") \
		and not wire_with.contains("public_attackless_unbound_gust_hold") \
		and not wire_with.contains("attackless_unbound_gust_hold_suffix") \
		and not wire_with.contains("public_attackless_gust_to_attack_epoch") \
		and not wire_with.contains("attackless_gust_to_attack_epoch_suffix") \
		and not wire_with.contains("public_copy_source_recovery_attack_epoch") \
		and not wire_with.contains("copy_source_recovery_attack_epoch_suffix")
	_check(passed, \
		"unprofiled source-development path must be byte-identical to a profile without the local proof: with=%d without=%d" \
		% [wire_with.length(), wire_without.length()])
	return passed


func _scenario_8_attackless_unbound_gust_hold() -> void:
	var stages := [
		{
			"id": "protect_partner_before_gust",
			"selected_action_id": "turn3:rigid-reshiram",
			"observation_stage": "tool",
			"actions": [
				_play_trainer("turn3:boss", BOSS_UID, true),
				_attach_tool("turn3:rigid-reshiram", RIGID_BAND_UID, "slot:reshiram"),
				_use_stadium("turn3:artazon", ARTAZON_UID),
				_end_turn("turn3:end"),
			],
			"scores": {
				"turn3:boss": 204.8,
				"turn3:rigid-reshiram": 119.48,
				"turn3:artazon": 116.46,
				"turn3:end": -924.0,
			},
		},
		{
			"id": "develop_copy_source_before_gust",
			"selected_action_id": "turn3:artazon",
			"observation_stage": "stadium",
			"actions": [
				_play_trainer("turn3:boss", BOSS_UID, true),
				_use_stadium("turn3:artazon", ARTAZON_UID),
				_end_turn("turn3:end"),
			],
			"scores": {
				"turn3:boss": 204.8,
				"turn3:artazon": 116.46,
				"turn3:end": -924.0,
			},
		},
		{
			"id": "hold_unbound_gust_after_development",
			"selected_action_id": "turn3:end",
			"observation_stage": "hold",
			"actions": [
				_play_trainer("turn3:boss", BOSS_UID, true),
				_end_turn("turn3:end"),
			],
			"scores": {"turn3:boss": 204.8, "turn3:end": -924.0},
		},
	]
	var all_verified := true
	var terminal_proof: Dictionary = {}
	var production_suffix_trace: Array[String] = []
	for stage: Dictionary in stages:
		var facts := _seed_506_turn3_facts()
		var observation := _seed_506_turn3_observation(
			stage.get("actions", []), str(stage.get("observation_stage", ""))
		)
		var frontier := _frontier(observation, stage.get("scores", {}), facts, "turn3:boss")
		var selected := _candidate(frontier, str(stage.get("selected_action_id", "")))
		var proof := _module_field(selected, "copy_attack_toolbox", "attackless_unbound_gust_hold")
		var safety := _route_safety(selected, frontier, facts)
		var automatic := _automatic_upgrade(frontier, facts)
		var verified := bool(proof.get("verified", false)) \
			and str(proof.get("stage", "")) == str(stage.get("id", "")) \
			and str(proof.get("rule_target_uid", "")).to_upper() == RAICHU_UID.to_upper() \
			and int(proof.get("rule_target_energy_count", 0)) == 1 \
			and bool(proof.get("rule_target_immediate_attack_ready", false)) \
			and bool(proof.get("rule_floor_preserved_after_prefix", false)) \
			and bool(safety.get("valid", false)) \
			and str((safety.get("advantage", {}) as Dictionary).get("certificate_kind", "")) \
				== "public_attackless_unbound_gust_hold" \
			and str(automatic.get("safe_prefix_action_id", "")) \
				== str(stage.get("selected_action_id", ""))
		_check(verified, "scenario 8 stage %s must be the autonomous public gust-hold suffix" % stage.get("id", ""))
		all_verified = all_verified and verified
		production_suffix_trace.append(str(automatic.get("safe_prefix_action_id", "")))
		if str(stage.get("observation_stage", "")) == "hold":
			terminal_proof = proof
	_check(production_suffix_trace == [
		"turn3:rigid-reshiram",
		"turn3:artazon",
		"turn3:end",
	], "scenario 8 production suffix must continue through the post-interaction frontier and end without Boss")

	var negative_cases := [
		{"id": "attack_ready", "stage": "hold", "mutate": "attack_ready"},
		{"id": "ko_available", "stage": "hold", "mutate": "ko_available"},
		{"id": "active_can_pay_pivot", "stage": "hold", "mutate": "active_energy"},
		{"id": "rule_target_order_changed", "stage": "hold", "mutate": "bench_order"},
		{"id": "rule_target_not_powered", "stage": "hold", "mutate": "raichu_energy"},
		{"id": "development_incomplete", "stage": "hold", "mutate": "missing_munkidori"},
	]
	var negatives_failed_closed := true
	for negative: Dictionary in negative_cases:
		var actions := [
			_play_trainer("negative:boss", BOSS_UID, true),
			_end_turn("negative:end"),
		]
		var observation := _seed_506_turn3_observation(actions, str(negative.get("stage", "")))
		var facts := _seed_506_turn3_facts()
		_mutate_seed_506_negative(observation, facts, str(negative.get("mutate", "")))
		var frontier := _frontier(
			observation, {"negative:boss": 204.8, "negative:end": -924.0}, facts, "negative:boss"
		)
		var selected := _candidate(frontier, "negative:end")
		var proof := _module_field(selected, "copy_attack_toolbox", "attackless_unbound_gust_hold")
		var safety := _route_safety(selected, frontier, facts)
		var failed_closed := not bool(proof.get("verified", false)) \
			and not bool(safety.get("valid", false)) \
			and _automatic_upgrade(frontier, facts).is_empty()
		_check(failed_closed, "scenario 8 negative %s must fail closed" % negative.get("id", ""))
		negatives_failed_closed = negatives_failed_closed and failed_closed

	var tampered_actions := [
		_play_trainer("tamper:boss", BOSS_UID, true),
		_end_turn("tamper:end"),
	]
	var tampered_facts := _seed_506_turn3_facts()
	var tampered_frontier := _frontier(
		_seed_506_turn3_observation(tampered_actions, "hold"),
		{"tamper:boss": 204.8, "tamper:end": -924.0},
		tampered_facts,
		"tamper:boss"
	)
	var tampered_candidate := _candidate(tampered_frontier, "tamper:end")
	var tampered_proof := _module_field(
		tampered_candidate, "copy_attack_toolbox", "attackless_unbound_gust_hold"
	)
	tampered_proof["rule_target_slot_id"] = "slot:tampered"
	var tamper_failed := not bool(_route_safety(tampered_candidate, tampered_frontier, tampered_facts).get("valid", false))
	_check(tamper_failed, "scenario 8 gust-hold binding must reject a tampered public Rule target")
	_rows.append(_row(
		"attackless_unbound_gust_hold",
		"无攻击回合/保留对手换位成本",
		"seed 800018506 turn 3 必须先完成不消耗支援者额度的 Rigid Band 与 Artazon 开发；公开重算 Boss 会把已有1雷能且可立即使用招式的 Raichu V 拉到前台后，在自己无攻击、无击倒时结束回合，避免免费替对手完成换位。",
		"Rigid Band -> Artazon -> end_turn (hold Boss)",
		"public_attackless_unbound_gust_hold",
		all_verified and negatives_failed_closed and tamper_failed \
			and str(terminal_proof.get("terminal_status", "")) == "turn_ended_after_public_development"
	))


func _scenario_9_iono_reopens_attack_epoch_before_gust() -> void:
	var actions := [
		_play_trainer("turn5:boss", BOSS_UID, true),
		_play_trainer("turn5:iono", IONO_UID, true),
		_play_basic("turn5:bloodmoon", BLOODMOON_URSALUNA_UID),
		_use_stadium("turn5:artazon", ARTAZON_UID),
		_attach_tool("turn5:rigid-active", RIGID_BAND_UID, "slot:zoroark"),
		_end_turn("turn5:end"),
	]
	var observation := _seed_506_turn5_observation(actions)
	var facts := _seed_506_turn5_facts()
	var frontier := _frontier(observation, {
		"turn5:boss": 204.8,
		"turn5:iono": 105.6,
		"turn5:bloodmoon": 165.8,
		"turn5:artazon": 116.46,
		"turn5:rigid-active": 115.4,
		"turn5:end": -924.0,
	}, facts, "turn5:boss")
	var iono := _candidate(frontier, "turn5:iono")
	var safety := _route_safety(iono, frontier, facts)
	var automatic := _automatic_upgrade(frontier, facts)
	var proof := _module_field(
		iono, "copy_attack_toolbox", "attackless_gust_to_attack_epoch"
	)
	var positive := bool(proof.get("verified", false)) \
		and str(proof.get("stage", "")) == "reset_for_energy_before_gust" \
		and bool(proof.get("information_checkpoint_crossed", false)) \
		and bool(proof.get("attack_suffix_requires_public_replan", false)) \
		and str(proof.get("rule_target_uid", "")).to_upper() == IRON_HANDS_UID.to_upper() \
		and int(proof.get("rule_target_energy_count", 0)) == 3 \
		and bool(safety.get("valid", false)) \
		and str((safety.get("advantage", {}) as Dictionary).get("certificate_kind", "")) \
			== "public_attackless_gust_to_attack_epoch" \
		and str(automatic.get("safe_prefix_action_id", "")) == "turn5:iono"
	_check(positive,
		"scenario 9 must choose Iono over an attackless unbound Boss and reopen a public attack epoch")

	observation["observation_version"] = 1
	observation["observation_hash"] = "ns-zoroark-pre-iono-attack-epoch"
	var after_iono := _seed_506_turn5_after_iono_observation()
	var facts_after_iono := _seed_506_turn5_after_iono_facts()
	var iono_delta := MaterialDeltaScript.new().compare(
		observation, after_iono, facts, facts_after_iono
	)
	var attach_frontier := _frontier(after_iono, {
		"turn5:attach-active": 1555.28,
		"turn5:bench-munkidori": 210.8,
		"turn5:ns-pp-up": 430.0,
		"turn5:artazon-after-iono": 116.46,
		"turn5:end-after-iono": -924.0,
	}, facts_after_iono, "turn5:attach-active")
	var attach := _candidate(attach_frontier, "turn5:attach-active")
	var typed_attachment := _module_field(attach, "copy_attack_toolbox", "typed_attachment")
	var attach_safety := _route_safety(attach, attach_frontier, facts_after_iono)
	var after_attach := _seed_506_turn5_after_attach_observation()
	var facts_after_attach := _seed_506_turn5_after_attach_facts()
	var attack_frontier := _frontier(after_attach, {
		"turn5:night-joker": 1050.0,
		"turn5:bench-munkidori-after-attach": 210.8,
		"turn5:ns-pp-up-after-attach": 430.0,
		"turn5:artazon-after-attach": 116.46,
		"turn5:end-after-attach": -924.0,
	}, facts_after_attach, "turn5:night-joker")
	var attack := _candidate(attack_frontier, "turn5:night-joker")
	var attack_safety := _route_safety(attack, attack_frontier, facts_after_attach)
	var continuous_suffix := bool(iono_delta.get("legal_actions_changed", false)) \
		and int(iono_delta.get("base_observation_version", 0)) == 1 \
		and int(iono_delta.get("observation_version", 0)) == 2 \
		and str(proof.get("interaction_owner", "")) == "rules_fallback" \
		and str(attach.get("route_id", "")) == "route:energy_commit" \
		and bool(attach.get("engine_rule_floor_exact", false)) \
		and bool(typed_attachment.get("target_is_active", false)) \
		and bool(typed_attachment.get("completes_required_types", false)) \
		and (typed_attachment.get("missing_after", []) as Array).is_empty() \
		and bool(attach_safety.get("valid", false)) \
		and bool(facts_after_attach["attack"]["ready"]) \
		and str(attack.get("route_id", "")) in ["route:attack_ko", "route:attack_pressure"] \
		and bool(attack.get("engine_rule_floor_exact", false)) \
		and bool(attack_safety.get("valid", false))
	_check(continuous_suffix,
		"scenario 9 must rebuild the post-Iono frontier, attach legally to active Zoroark, and expose a payable attack")

	var negatives_failed_closed := true
	for negative: String in ["attack_ready", "energy_quota_spent", "opponent_has_hand", "boss_prebound"]:
		var negative_actions: Array = actions.duplicate(true)
		var negative_observation := _seed_506_turn5_observation(negative_actions)
		var negative_facts := _seed_506_turn5_facts()
		match negative:
			"attack_ready": negative_facts["attack"]["ready"] = true
			"energy_quota_spent":
				negative_facts["turn"]["energy_available"] = false
				negative_observation["turn"]["quotas"]["energy_available"] = false
			"opponent_has_hand": negative_observation["opponent"]["hand_count"] = 2
			"boss_prebound": negative_actions[0]["target"] = "slot:iron-hands-powered"
		var negative_frontier := _frontier(negative_observation, {
			"turn5:boss": 204.8,
			"turn5:iono": 105.6,
			"turn5:bloodmoon": 165.8,
			"turn5:artazon": 116.46,
			"turn5:rigid-active": 115.4,
			"turn5:end": -924.0,
		}, negative_facts, "turn5:boss")
		var negative_iono := _candidate(negative_frontier, "turn5:iono")
		var failed_closed := _module_field(
			negative_iono, "copy_attack_toolbox", "attackless_gust_to_attack_epoch"
		).is_empty() and _automatic_upgrade(negative_frontier, negative_facts).is_empty()
		_check(failed_closed, "scenario 9 negative %s must fail closed" % negative)
		negatives_failed_closed = negatives_failed_closed and failed_closed
	var tampered_frontier: Array[Dictionary] = frontier.duplicate(true)
	var tampered_iono := _candidate(tampered_frontier, "turn5:iono")
	var tampered_proof := _module_field(
		tampered_iono, "copy_attack_toolbox", "attackless_gust_to_attack_epoch"
	)
	tampered_proof["rule_target_slot_id"] = "slot:tampered"
	var tamper_failed := not bool(
		_route_safety(tampered_iono, tampered_frontier, facts).get("valid", false)
	)
	_check(tamper_failed, "scenario 9 attack-epoch binding must reject a tampered public Rule target")

	_rows.append(_row(
		"iono_reopens_attack_epoch_before_gust",
		"无攻击回合/信息纪元重开",
		"公开局面无可支付攻击且 Boss 会把已充能 Iron Hands 免费送到前台时，先用 Iono 打开新信息纪元；抽牌结果公开后必须重新证明贴能与攻击，不能预知隐藏牌库。",
		"Iono -> material epoch -> revalidate attach -> payable attack",
		"public_attackless_gust_to_attack_epoch",
		positive and continuous_suffix and negatives_failed_closed and tamper_failed
	))


func _scenario_10_recover_reshiram_before_low_value_copy_attack() -> void:
	var low_value_attack := _attack(
		"turn10:night-joker-zorua", "slot:zoroark", ZOROARK_UID, 0, 20, false
	)
	var night_stretcher := _play_trainer(
		"turn10:night-stretcher", NIGHT_STRETCHER_UID, true
	)
	var before := _seed_505_turn10_recovery_observation([
		low_value_attack,
		night_stretcher,
	])
	var facts := _seed_505_turn10_recovery_facts()
	var frontier := _frontier(before, {
		"turn10:night-joker-zorua": 1060.0,
		"turn10:night-stretcher": 376.4,
	}, facts, "turn10:night-joker-zorua")
	var recover := _candidate(frontier, "turn10:night-stretcher")
	var recover_proof := _module_field(
		recover, "copy_attack_toolbox", "copy_source_recovery_attack_epoch"
	)
	var recover_safety := _route_safety(recover, frontier, facts)
	var recover_upgrade := _automatic_upgrade(frontier, facts)
	var recovery_certificate := "public_copy_source_recovery_attack_epoch"
	var registry = CapabilityRegistryScript.new()
	var interaction_override := registry.pick_verified_interaction_override(
		[
			_card(RESHIRAM_UID),
			_darkness_energy(),
		],
		{"id": "night_stretcher_choice", "min_select": 1, "max_select": 1},
		[],
		{"v18cpg_observation": before, "v18cpg_facts": facts},
		_profile,
		recovery_certificate
	)
	var recover_stage_ok := bool(recover_proof.get("verified", false)) \
		and str(recover_proof.get("stage", "")) == "recover_copy_source" \
		and str(recover_proof.get("interaction_owner", "")) \
			== "module_verified_interaction_override" \
		and bool(recover_proof.get("requires_public_replan", false)) \
		and int(recover_proof.get("copy_damage_after", 0)) == 170 \
		and int(recover_proof.get("rule_copy_damage_before", 0)) == 20 \
		and int(recover_proof.get("prizes_floor", 0)) == 2 \
		and bool(recover_safety.get("valid", false)) \
		and str((recover_safety.get("advantage", {}) as Dictionary).get("certificate_kind", "")) \
			== recovery_certificate \
		and str(recover_upgrade.get("safe_prefix_action_id", "")) == "turn10:night-stretcher" \
		and bool(interaction_override.get("handled", false)) \
		and (interaction_override.get("items", []) as Array).size() == 1 \
		and str(((interaction_override.get("items", []) as Array)[0] as Dictionary).get("uid", "")) \
			== RESHIRAM_UID
	_check(recover_stage_ok,
		"scenario 10 must recover the unique public Reshiram before a 20-damage copy attack")

	before["observation_version"] = 23
	before["observation_hash"] = "seed-505-before-night-stretcher"
	var after_recover := _seed_505_turn10_after_recovery_observation([
		low_value_attack,
		_play_basic("turn10:bench-reshiram", RESHIRAM_UID),
	])
	var after_recover_facts := _seed_505_turn10_recovery_facts()
	var recover_delta := MaterialDeltaScript.new().compare(
		before, after_recover, facts, after_recover_facts
	)
	var after_recover_frontier := _frontier(after_recover, {
		"turn10:night-joker-zorua": 1060.0,
		"turn10:bench-reshiram": 375.0,
	}, after_recover_facts, "turn10:night-joker-zorua")
	var bench_reshiram := _candidate(after_recover_frontier, "turn10:bench-reshiram")
	var bench_proof := _module_field(
		bench_reshiram, "copy_attack_toolbox", "copy_source_recovery_attack_epoch"
	)
	var bench_safety := _route_safety(
		bench_reshiram, after_recover_frontier, after_recover_facts
	)
	var bench_upgrade := _automatic_upgrade(after_recover_frontier, after_recover_facts)
	var bench_stage_ok := bool(recover_delta.get("legal_actions_changed", false)) \
		and bool(bench_proof.get("verified", false)) \
		and str(bench_proof.get("stage", "")) == "bench_recovered_copy_source" \
		and str(bench_proof.get("interaction_owner", "")) == "not_required" \
		and bool(bench_proof.get("requires_public_replan", false)) \
		and bool(bench_safety.get("valid", false)) \
		and str(bench_upgrade.get("safe_prefix_action_id", "")) == "turn10:bench-reshiram"
	_check(bench_stage_ok,
		"scenario 10 must reobserve the public recovery and then bench Reshiram")

	after_recover["observation_version"] = 24
	after_recover["observation_hash"] = "seed-505-after-night-stretcher"
	var finishing_attack := _attack(
		"turn10:night-joker-reshiram", "slot:zoroark", ZOROARK_UID, 0, 170, true
	)
	var after_bench := _seed_505_turn10_after_recovery_observation([finishing_attack])
	after_bench["observation_version"] = 25
	after_bench["observation_hash"] = "seed-505-after-bench-reshiram"
	after_bench["own"]["bench"].append(_slot("slot:reshiram", RESHIRAM_UID, []))
	after_bench["own"]["hand"] = []
	after_bench["own"]["hand_count"] = 0
	var finish_facts := _seed_505_turn10_recovery_facts()
	finish_facts["attack"] = {"ready": true, "ko_available": true, "max_damage": 170}
	var bench_delta := MaterialDeltaScript.new().compare(
		after_recover, after_bench, after_recover_facts, finish_facts
	)
	var finish_frontier := _frontier(after_bench, {
		"turn10:night-joker-reshiram": 2000.0,
	}, finish_facts, "turn10:night-joker-reshiram")
	var finish := _candidate(finish_frontier, "turn10:night-joker-reshiram")
	var finish_safety := _route_safety(finish, finish_frontier, finish_facts)
	var suffix_ok := bool(bench_delta.get("legal_actions_changed", false)) \
		and str(finish.get("route_id", "")) == "route:attack_ko" \
		and bool(finish.get("engine_rule_floor_exact", false)) \
		and bool(finish_safety.get("valid", false))
	_check(suffix_ok,
		"scenario 10 must expose the exact 170-damage Rule KO after Reshiram is benched")

	var negatives_failed_closed := true
	for negative: String in [
		"wrong_energy", "bench_full", "missing_discard", "already_lethal_source",
		"wrong_opponent_hp", "protected_target", "wrong_prizes", "wrong_rule_floor",
	]:
		var negative_observation := _seed_505_turn10_recovery_observation([
			low_value_attack,
			night_stretcher,
		])
		var negative_facts := _seed_505_turn10_recovery_facts()
		var negative_rule_id := "turn10:night-joker-zorua"
		var negative_scores := {
			"turn10:night-joker-zorua": 1060.0,
			"turn10:night-stretcher": 376.4,
		}
		match negative:
			"wrong_energy":
				negative_observation["own"]["active"]["energy"].pop_back()
				negative_observation["own"]["active"]["energy_count"] = 1
			"bench_full":
				for index: int in 3:
					negative_observation["own"]["bench"].append(
						_slot("slot:occupied-%d" % index, MUNKIDORI_UID, [])
					)
				negative_facts["resources"]["bench_slots_free"] = 0
			"missing_discard": negative_observation["own"]["discard_counts"].erase(RESHIRAM_UID)
			"already_lethal_source":
				negative_observation["own"]["bench"][1] = _slot(
					"slot:reshiram", RESHIRAM_UID, []
				)
			"wrong_opponent_hp": negative_observation["opponent"]["active"]["remaining_hp"] = 180
			"protected_target": negative_observation["opponent"]["active"]["tera"] = true
			"wrong_prizes":
				negative_observation["own"]["prizes_remaining"] = 3
				negative_facts["resources"]["prizes_remaining"] = 3
			"wrong_rule_floor":
				negative_rule_id = "turn10:night-stretcher"
				negative_scores["turn10:night-stretcher"] = 1200.0
		var negative_frontier := _frontier(
			negative_observation, negative_scores, negative_facts, negative_rule_id
		)
		var negative_recover := _candidate(negative_frontier, "turn10:night-stretcher")
		var failed_closed := _module_field(
			negative_recover, "copy_attack_toolbox", "copy_source_recovery_attack_epoch"
		).is_empty() and _automatic_upgrade(negative_frontier, negative_facts).is_empty()
		_check(failed_closed, "scenario 10 negative %s must fail closed" % negative)
		negatives_failed_closed = negatives_failed_closed and failed_closed

	var tampered_frontier: Array[Dictionary] = frontier.duplicate(true)
	var tampered_recover := _candidate(tampered_frontier, "turn10:night-stretcher")
	var tampered_proof := _module_field(
		tampered_recover, "copy_attack_toolbox", "copy_source_recovery_attack_epoch"
	)
	tampered_proof["copy_damage_after"] = 180
	var tamper_failed := not bool(
		_route_safety(tampered_recover, tampered_frontier, facts).get("valid", false)
	)
	_check(tamper_failed,
		"scenario 10 recovery binding must reject a tampered copied-damage proof")

	_rows.append(_row(
		"recover_reshiram_before_low_value_copy_attack",
		"copy-source recovery / public replanning",
		"Recover the unique public Reshiram with Night Stretcher, reobserve, bench it, reobserve, then copy 170 damage instead of spending the attack on Zorua's 20 damage.",
		"Night Stretcher -> Reshiram -> bench Reshiram -> Night Joker 170 KO",
		recovery_certificate,
		recover_stage_ok and bench_stage_ok and suffix_ok \
			and negatives_failed_closed and tamper_failed
	))


func _seed_505_turn10_recovery_observation(actions: Array) -> Dictionary:
	var active := _slot(
		"slot:zoroark", ZOROARK_UID, [_darkness_energy(), _darkness_energy()]
	)
	active["remaining_hp"] = 280
	active["max_hp"] = 280
	var observation := _observation(actions, active, [
		_slot("slot:zorua-a", "CSV10C_144", []),
		_slot("slot:zorua-b", "CSV10C_144", []),
	], 35)
	observation["own"]["hand"] = [
		_card(NIGHT_STRETCHER_UID),
		_darkness_energy(),
		_card(MUNKIDORI_UID),
	]
	observation["own"]["hand_count"] = 3
	observation["own"]["discard_counts"] = {RESHIRAM_UID: 1}
	observation["own"]["prizes_remaining"] = 4
	observation["opponent"] = {
		"active": _public_opponent_slot("slot:raikou-v", RAIKOU_V_UID, 30, 2, 4),
		"bench": [],
		"hand_count": 7,
		"deck_count": 29,
		"prizes_remaining": 4,
	}
	return observation


func _seed_505_turn10_after_recovery_observation(actions: Array) -> Dictionary:
	var observation := _seed_505_turn10_recovery_observation(actions)
	observation["own"]["hand"] = [_card(RESHIRAM_UID), _darkness_energy(), _card(MUNKIDORI_UID)]
	observation["own"]["hand_count"] = 3
	observation["own"]["discard_counts"] = {}
	return observation


func _seed_505_turn10_recovery_facts() -> Dictionary:
	var facts := _facts(true, false, true, 3, false, false, 0)
	facts["resources"]["bench_slots_free"] = 3
	facts["resources"]["prizes_remaining"] = 4
	facts["board"]["own_active_remaining_hp"] = 280
	facts["board"]["opponent_active_remaining_hp"] = 30
	return facts


func _seed_506_turn5_observation(actions: Array) -> Dictionary:
	var active := _slot("slot:zoroark", ZOROARK_UID, [_darkness_energy()])
	active["remaining_hp"] = 280
	active["max_hp"] = 280
	var observation := _observation(actions, active, [
		_slot("slot:reshiram", RESHIRAM_UID, []),
		_slot("slot:zorua", "CSV10C_144", []),
		_slot("slot:munkidori", MUNKIDORI_UID, []),
	], 38)
	observation["turn"] = {
		"number": 5,
		"current_player": 0,
		"deterministic_attack_window_open": true,
		"quotas": {
			"energy_available": true,
			"supporter_available": true,
			"stadium_available": true,
			"retreat_available": true,
		},
	}
	observation["own"]["hand"] = [
		_card(BOSS_UID),
		_card(IONO_UID),
		_card(IONO_UID),
		_card(NIGHT_STRETCHER_UID),
		_card(BLOODMOON_URSALUNA_UID),
		_card(RIGID_BAND_UID),
	]
	observation["own"]["hand_count"] = 6
	observation["own"]["prizes_remaining"] = 6
	observation["opponent"] = {
		"active": _public_opponent_slot("slot:lumineon", LUMINEON_UID, 170, 2, 0),
		"bench": [
			_public_opponent_slot("slot:raichu", RAICHU_UID, 200, 2, 1),
			_public_opponent_slot("slot:miraidon", MIRAIDON_UID, 220, 2, 0),
			_public_opponent_slot("slot:iron-hands-powered", IRON_HANDS_UID, 230, 2, 3),
			_public_opponent_slot("slot:iron-hands-idle", IRON_HANDS_UID, 230, 2, 0),
			_public_opponent_slot("slot:zapdos", ZAPDOS_UID, 120, 1, 0),
		],
		"hand_count": 0,
		"hand": [{"uid": "FORBIDDEN_SECRET_HAND_CARD"}],
		"deck_count": 37,
		"prizes_remaining": 6,
	}
	observation["stadium"] = _card(ARTAZON_UID)
	return observation


func _seed_506_turn5_after_iono_observation() -> Dictionary:
	var actions := [
		_attach("turn5:attach-active", "slot:zoroark"),
		_play_basic("turn5:bench-munkidori", MUNKIDORI_UID),
		_play_trainer("turn5:ns-pp-up", "CSVH1aC_008", false),
		_use_stadium("turn5:artazon-after-iono", ARTAZON_UID),
		_end_turn("turn5:end-after-iono"),
	]
	var observation := _seed_506_turn5_observation(actions)
	observation["observation_version"] = 2
	observation["observation_hash"] = "ns-zoroark-post-iono-attack-epoch"
	observation["own"]["deck_count"] = 37
	observation["own"]["hand"] = [
		_card("CSV7C_191"),
		_card(MUNKIDORI_UID),
		_card("CSVH1aC_008"),
		_darkness_energy(),
		_darkness_energy(),
		_card("CSV6C_114"),
	]
	observation["own"]["hand_count"] = 6
	observation["opponent"]["hand_count"] = 6
	observation["turn"]["quotas"]["supporter_available"] = false
	return observation


func _seed_506_turn5_after_iono_facts() -> Dictionary:
	var facts := _facts(false, false, true, 6, false, false, 0)
	facts["turn"]["supporter_available"] = false
	facts["information"]["material_action_available"] = false
	facts["resources"]["energy_on_board"] = 1
	facts["resources"]["prizes_remaining"] = 6
	facts["board"]["own_active_remaining_hp"] = 280
	facts["board"]["opponent_active_remaining_hp"] = 170
	return facts


func _seed_506_turn5_after_attach_observation() -> Dictionary:
	var actions := [
		_attack("turn5:night-joker", "slot:zoroark", ZOROARK_UID, 0, 170, true),
		_play_basic("turn5:bench-munkidori-after-attach", MUNKIDORI_UID),
		_play_trainer("turn5:ns-pp-up-after-attach", "CSVH1aC_008", false),
		_use_stadium("turn5:artazon-after-attach", ARTAZON_UID),
		_end_turn("turn5:end-after-attach"),
	]
	var observation := _seed_506_turn5_after_iono_observation()
	observation["observation_version"] = 3
	observation["observation_hash"] = "ns-zoroark-post-iono-attach-ready"
	observation["legal_actions"] = actions
	observation["own"]["active"]["energy"] = [_darkness_energy(), _darkness_energy()]
	observation["own"]["active"]["energy_count"] = 2
	observation["own"]["hand"].remove_at(3)
	observation["own"]["hand_count"] = 5
	observation["turn"]["quotas"]["energy_available"] = false
	return observation


func _seed_506_turn5_after_attach_facts() -> Dictionary:
	var facts := _facts(true, false, false, 5, false, false, 170)
	facts["turn"]["supporter_available"] = false
	facts["information"]["material_action_available"] = false
	facts["resources"]["energy_on_board"] = 2
	facts["resources"]["prizes_remaining"] = 6
	facts["board"]["own_active_remaining_hp"] = 280
	facts["board"]["opponent_active_remaining_hp"] = 170
	return facts


func _seed_506_turn5_facts() -> Dictionary:
	var facts := _facts(false, false, true, 4, false, false, 0)
	facts["information"]["material_action_available"] = false
	facts["resources"]["energy_on_board"] = 1
	facts["resources"]["prizes_remaining"] = 6
	facts["board"]["own_active_remaining_hp"] = 280
	facts["board"]["opponent_active_remaining_hp"] = 170
	return facts


func _seed_506_turn3_observation(actions: Array, stage: String) -> Dictionary:
	var active := _slot("slot:zoroark", ZOROARK_UID, [_darkness_energy()])
	active["remaining_hp"] = 280
	active["max_hp"] = 280
	var own_bench: Array = [
		_slot("slot:reshiram", RESHIRAM_UID, []),
		_slot("slot:zorua", "CSV10C_144", []),
	]
	if stage == "hold":
		own_bench.append(_slot("slot:munkidori", MUNKIDORI_UID, []))
	var observation := _observation(actions, active, own_bench, 41 if stage == "hold" else 42)
	observation["turn"] = {
		"number": 3,
		"current_player": 0,
		"deterministic_attack_window_open": true,
		"quotas": {
			"energy_available": true,
			"supporter_available": true,
			# Production keeps this generic quota true after Artazon's once-per-turn
			# interaction; the absence of a second stadium action is expressed by the
			# legal frontier, not by this quota bit.
			"stadium_available": true,
			"retreat_available": true,
		},
	}
	observation["own"]["hand"] = [
		_card(BOSS_UID),
		_card(IONO_UID),
		_card(IONO_UID),
		_card(NIGHT_STRETCHER_UID),
	]
	if stage == "tool":
		observation["own"]["hand"].insert(3, _card(RIGID_BAND_UID))
	observation["own"]["hand_count"] = observation["own"]["hand"].size()
	observation["own"]["prizes_remaining"] = 6
	observation["opponent"] = {
		"active": _public_opponent_slot("slot:lumineon", LUMINEON_UID, 170, 2, 0),
		"bench": [
			_public_opponent_slot("slot:raichu", RAICHU_UID, 200, 2, 1),
			_public_opponent_slot("slot:miraidon", MIRAIDON_UID, 220, 2, 0),
			_public_opponent_slot("slot:iron-hands-powered", IRON_HANDS_UID, 230, 2, 1),
			_public_opponent_slot("slot:iron-hands-idle", IRON_HANDS_UID, 230, 2, 0),
			_public_opponent_slot("slot:zapdos", ZAPDOS_UID, 120, 1, 0),
		],
		"hand_count": 1,
		"hand": [{"uid": "FORBIDDEN_SECRET_HAND_CARD"}],
		"deck_count": 39,
		"prizes_remaining": 6,
	}
	observation["stadium"] = _card(ARTAZON_UID)
	return observation


func _seed_506_turn3_facts() -> Dictionary:
	var facts := _facts(false, false, true, 4, false, false, 0)
	facts["information"]["material_action_available"] = false
	facts["resources"]["energy_on_board"] = 1
	facts["resources"]["prizes_remaining"] = 6
	facts["board"]["own_active_remaining_hp"] = 280
	facts["board"]["opponent_active_remaining_hp"] = 170
	return facts


func _mutate_seed_506_negative(observation: Dictionary, facts: Dictionary, mutation: String) -> void:
	match mutation:
		"attack_ready": facts["attack"]["ready"] = true
		"ko_available": facts["attack"]["ko_available"] = true
		"active_energy":
			observation["opponent"]["active"]["energy"] = [_lightning_energy()]
			observation["opponent"]["active"]["energy_count"] = 1
		"bench_order":
			var bench: Array = observation["opponent"]["bench"]
			var first: Variant = bench[0]
			bench[0] = bench[2]
			bench[2] = first
		"raichu_energy":
			observation["opponent"]["bench"][0]["energy"] = []
			observation["opponent"]["bench"][0]["energy_count"] = 0
		"missing_munkidori": observation["own"]["bench"].pop_back()


func _public_opponent_slot(
	slot_id: String,
	uid: String,
	remaining_hp: int,
	prize_count: int,
	energy_count: int
) -> Dictionary:
	var energy: Array = []
	for _index: int in energy_count:
		energy.append(_lightning_energy())
	return {
		"slot_id": slot_id,
		"pokemon": {"uid": uid, "type": "Pokemon"},
		"energy": energy,
		"energy_count": energy_count,
		"remaining_hp": remaining_hp,
		"prize_count": prize_count,
		"tera": false,
	}


func _lightning_energy() -> Dictionary:
	return {
		"uid": "CSVE1C_LIG",
		"name": "Lightning Energy",
		"type": "Basic Energy",
		"energy_type": "L",
		"energy_provides": "L",
	}


func _attach_tool(action_id: String, uid: String, target: String) -> Dictionary:
	return {"id": action_id, "kind": "attach_tool", "card": _card(uid), "target": target}


func _play_basic(action_id: String, uid: String) -> Dictionary:
	return {"id": action_id, "kind": "play_basic_to_bench", "card": _card(uid)}


func _use_stadium(action_id: String, uid: String) -> Dictionary:
	return {"id": action_id, "kind": "use_stadium_effect", "card": _card(uid), "requires_interaction": true}


func _end_turn(action_id: String) -> Dictionary:
	return {"id": action_id, "kind": "end_turn"}


func _automatic_upgrade(frontier: Array[Dictionary], facts: Dictionary) -> Dictionary:
	var strategy = StrategyScript.new()
	strategy.configure_profile(_profile, _manifest)
	return strategy.call("_find_module_verified_upgrade", frontier, facts)


func _frontier(observation: Dictionary, scores: Dictionary, facts: Dictionary, rule_action_id: String) -> Array[Dictionary]:
	var pool: Array[Dictionary] = RouteSearchScript.new().build_candidate_pool(observation, scores, _manifest, facts)
	for candidate: Dictionary in pool:
		candidate["engine_rule_floor_exact"] = str(candidate.get("safe_prefix_action_id", "")) == rule_action_id
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


func _module_field(candidate: Dictionary, module_id: String, field: String) -> Dictionary:
	var annotation := _module_annotation(candidate, module_id)
	return annotation.get(field, {}) if annotation.get(field, {}) is Dictionary else {}


func _observation(actions: Array, active: Dictionary, bench: Array, deck_count: int) -> Dictionary:
	return {
		"observation_version": 1,
		"observation_hash": "ns-zoroark-complex-scenario",
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
			"active": {
				"slot_id": "slot:opponent-active",
				"pokemon": {"uid": "PUBLIC_OPPONENT_ACTIVE"},
				"remaining_hp": 220,
				"prize_count": 2,
			},
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
		"max_hp": 200,
		"prize_count": 2 if uid in [ZOROARK_UID, "CSV8C_135", "CSV8C_172"] else 1,
	}


func _play_trainer(action_id: String, uid: String, interaction: bool) -> Dictionary:
	return {
		"id": action_id,
		"kind": "play_trainer",
		"card": _card(uid),
		"requires_interaction": interaction,
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


func _attach(action_id: String, target: String) -> Dictionary:
	return {"id": action_id, "kind": "attach_energy", "card": _darkness_energy(), "target": target}


func _attack(action_id: String, source: String, uid: String, attack_index: int, damage: int, knockout: bool) -> Dictionary:
	return {
		"id": action_id,
		"kind": "attack",
		"source": source,
		"source_card": _card(uid),
		"attack_index": attack_index,
		"projected_damage": damage,
		"projected_knockout": knockout,
		"requires_interaction": true,
	}


func _darkness_energy() -> Dictionary:
	return {
		"uid": "CSVE1C_DAR",
		"name": "Darkness Energy",
		"type": "Basic Energy",
		"energy_type": "D",
		"energy_provides": "D",
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


func _zoroark_data() -> CardData:
	var data := CardData.new()
	data.name = "N's Zoroark ex"
	data.name_en = data.name
	data.card_type = "Pokemon"
	data.stage = "Stage 1"
	data.hp = 280
	data.mechanic = "ex"
	data.energy_type = "D"
	data.set_code = "CSV10C"
	data.card_index = "145"
	data.effect_id = "a1742becbf9fdc6a66ddfb1b306c4bc0"
	# Use the production Chinese attack name so the exact CSV10 registry owns the
	# effect once; the generic English-name importer path is a different print.
	data.attacks = [{"name": "暗夜王牌", "cost": "DD", "damage": "", "text": "Copy a Benched N's Pokemon's attack."}]
	data.abilities = [{"name": "Trade", "text": "Discard 1 card and draw 2 cards."}]
	return data


func _darmanitan_data() -> CardData:
	var data := CardData.new()
	data.name = "N's Darmanitan"
	data.name_en = data.name
	data.card_type = "Pokemon"
	data.stage = "Stage 1"
	data.hp = 140
	data.energy_type = "R"
	data.set_code = "CSV10C"
	data.card_index = "041"
	data.effect_id = "26c746f169b803e490f3d0a92ca94412"
	data.attacks = [
		{"name": "Backdraft", "cost": "CC", "damage": "30x", "text": "Damage by Basic Energy in opponent discard."},
		{"name": "Immolating Cannon", "cost": "RRC", "damage": "90", "text": "Discard all Energy; deal 90 to 1 opponent Benched Pokemon."},
	]
	return data


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


func _real_public_target(
	name: String,
	hp: int,
	mechanic: String,
	owner: int,
	set_code: String,
	card_index: String,
	effect_id: String
) -> PokemonSlot:
	var target := _real_target(name, hp, mechanic, owner)
	var data := target.get_card_data()
	data.set_code = set_code
	data.card_index = card_index
	data.effect_id = effect_id
	return target


func _real_slot_id(slot: PokemonSlot) -> String:
	if slot == null or slot.get_top_card() == null:
		return ""
	return "slot:%d" % int(slot.get_top_card().instance_id)


func _public_slot_ref(slot: PokemonSlot) -> Dictionary:
	var data := slot.get_card_data()
	return {
		"slot_id": _real_slot_id(slot),
		"pokemon": {
			"uid": data.get_uid(),
			"effect_id": str(data.effect_id),
			"mechanic": str(data.mechanic),
		},
		"energy": [],
		"energy_count": 0,
		"tool": {},
		"remaining_hp": slot.get_remaining_hp(),
		"max_hp": slot.get_max_hp(),
		"prize_count": slot.get_prize_count(),
		"tera": data.is_tera_pokemon(),
	}


func _real_energy(owner: int) -> CardInstance:
	var data := CardData.new()
	data.name = "Darkness Energy"
	data.name_en = data.name
	data.card_type = "Basic Energy"
	data.energy_type = "D"
	data.energy_provides = "D"
	data.set_code = "CSVE1C"
	data.card_index = "DAR"
	return CardInstance.create(data, owner)

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
		"deck_name": "18.0 N的索罗亚克",
		"strategy_id": str(_profile.get("strategy_id", "")),
		"profile_version": int(_profile.get("profile_version", 0)),
		"round00_baseline": {
			"seeds": [800018502, 800018503, 800018504, 800018505, 800018506],
			"rule_wins": 3,
			"v18cpg_wins": 3,
			"model_calls": 29,
			"accepted_calls": 2,
			"rule_loss_seeds": [800018505, 800018506],
		},
		"scenario_count": _rows.size(),
		"passed_count": _rows.filter(func(row: Dictionary) -> bool: return bool(row.get("passed", false))).size(),
		"all_passed": _failures.is_empty() and _rows.size() == 10,
		"isolation": {
			"profile_modified": true,
			"dedicated_copy_module_added": true,
			"capability_registry_mapping_modified": true,
			"strategic_shape_module_modified": false,
			"legacy_or_agent_modified": false,
			"hidden_sentinel_absent_from_frontiers": true,
		},
		"coverage": [
			"typed Darkness attachment",
			"Zorua evolution and copy engine establishment",
			"Ciphermaniac/Trade/N's PP Up ordering",
			"Night Joker copied-attack and Bench-target interactions",
			"Immolating Cannon 90 active + 90 Bench double KO",
			"strict public-state negative matrix and certificate integrity binding",
			"public-hand copy-source development with exact Rule attack-suffix preservation",
			"byte-identical compact/factored model wire when no profiled Darumaka candidate exists",
			"seed-506 attackless Rigid Band/Artazon development before a public unbound-gust hold",
			"seed-506 post-hold Iono information epoch before a newly public attach-and-attack suffix",
			"same-runtime public recomputation of Boss's Orders target ordering without hidden hand contents",
			"occupied Bench, missing/discarded/prized evolution, wrong prize window, lost attack, hidden search, and Munkidori-urgency negatives",
			"post-KO information checkpoint, gust, and terminal attack",
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
