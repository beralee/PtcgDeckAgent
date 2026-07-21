extends SceneTree

const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const RouteSearchScript = preload("res://scripts/ai/v18_cpg/planning/V18CPGRouteSearch.gd")
const CapabilityRegistryScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCapabilityRegistry.gd")
const MaterialDeltaScript = preload("res://scripts/ai/v18_cpg/observation/V18CPGMaterialDelta.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")
const EnergyBurstScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGEnergyBurst.gd")
const TealDanceScript = preload("res://scripts/effects/pokemon_effects/AbilityAttachBasicEnergyFromHandDraw.gd")
const VesselScript = preload("res://scripts/effects/trainer_effects/EffectSearchBasicEnergy.gd")
const SadaScript = preload("res://scripts/effects/trainer_effects/EffectSadasVitality.gd")
const EnergySwitchScript = preload("res://scripts/effects/trainer_effects/EffectEnergySwitch.gd")

const DECK_ID := 800018509
const MANIFEST_PATH := "res://scripts/ai/v18_cpg/profiles/generated_semantic_manifests/800018509.json"
const REPORT_PATH := "res://tmp/v18cpg/optimization21/800018509/complex_decision_scenarios.json"
const OGERPON_UID := "CSV8C_028"
const RAGING_BOLT_UID := "CSV7C_154"
const RAGING_BOLT_EFFECT_ID := "e96bb407c5f18bb9eec55487e70395fd"
const LATIAS_UID := "CSV9C_078"

var _profile: Dictionary = {}
var _manifest: Dictionary = {}
var _energy_burst = EnergyBurstScript.new()
var _failures: Array[String] = []
var _rows: Array[Dictionary] = []


func _initialize() -> void:
	_profile = ProfileCatalogScript.get_profile_for_deck(DECK_ID)
	_manifest = _load_json(MANIFEST_PATH)
	_check(int(_profile.get("deck_id", 0)) == DECK_ID, "production Raging Bolt profile must load")
	_check(int(_manifest.get("deck_id", 0)) == DECK_ID, "Raging Bolt semantic manifest must load")
	_check(_profile.get("modules", []) == ["energy_burst", "tera_noctowl_search", "cycle_pivot"], \
		"scenarios must use the isolated production capability composition")

	_scenario_1_teal_dance_before_supporter()
	_scenario_2_vessel_makes_sada_live()
	_scenario_3_exact_burst_discard_preserves_cost()
	_scenario_4_energy_switch_and_free_pivot()
	_scenario_5_exact_two_prize_closeout()
	_write_report()

	EffectProcessor.cleanup_live_instances_for_tests()
	if _failures.is_empty() and _rows.size() == 5:
		print("optimization21 800018509 complex decision scenarios: PASS (5/5)")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("optimization21 800018509 complex decision scenarios: FAIL (%d)" % _failures.size())
	quit(1)


func _scenario_1_teal_dance_before_supporter() -> void:
	var state := _game_state()
	var ogerpon_data := _real_card_data(OGERPON_UID)
	var ogerpon := _real_slot(ogerpon_data, 0)
	state.players[0].active_pokemon = _real_slot(_real_card_data(RAGING_BOLT_UID), 0)
	state.players[0].bench = [ogerpon]
	var grass := _real_energy("CSVE1C_GRA", 0)
	var fighting := _real_energy("CSVE1C_FIG", 0)
	var revealed_lightning := _real_energy("CSVE1C_LIG", 0)
	state.players[0].hand = [grass, fighting]
	state.players[0].deck = [revealed_lightning, _filler("Public deck filler", 0)]
	var dance = TealDanceScript.new("G", 1)
	var can_dance_before := dance.can_use_ability(ogerpon, state)
	var steps: Array[Dictionary] = dance.get_interaction_steps(ogerpon.get_top_card(), state)
	dance.execute_ability(ogerpon, 0, [{"basic_energy_from_hand": [grass]}], state)
	var once_only := not dance.can_use_ability(ogerpon, state)
	var real_effect_ok := can_dance_before \
		and not steps.is_empty() \
		and str(steps[0].get("id", "")) == "basic_energy_from_hand" \
		and grass in ogerpon.attached_energy \
		and revealed_lightning in state.players[0].hand \
		and fighting in state.players[0].hand \
		and once_only
	_check(real_effect_ok, "scenario 1 real Teal Dance must attach exactly one hand Grass, draw one, and lock for the turn")

	var no_grass_state := _game_state()
	var no_grass_ogerpon := _real_slot(ogerpon_data, 0)
	no_grass_state.players[0].active_pokemon = no_grass_ogerpon
	no_grass_state.players[0].hand = [_real_energy("CSVE1C_FIG", 0)]
	_check(not dance.can_use_ability(no_grass_ogerpon, no_grass_state), \
		"scenario 1 negative: Fighting Energy cannot be supplied to Teal Dance")

	var dance_action := _ability("ability:teal-dance", "slot:ogerpon", OGERPON_UID, true)
	var sada_action := _play_trainer("supporter:sada-too-early", "CSV6C_121", true)
	var before := _observation(
		[dance_action, sada_action],
		_slot("slot:bolt", RAGING_BOLT_UID, [_energy("L"), _energy("F")]),
		[_slot("slot:ogerpon", OGERPON_UID, [])],
		18
	)
	before["observation_version"] = 1
	before["observation_hash"] = "raging-before-teal-dance"
	before["own"]["hand"] = [_energy("G"), _card("CSV6C_121")]
	var facts_before := _facts(false, false, true, 2, false, false, 0)
	var frontier := _frontier(before, {
		"ability:teal-dance": 500.0,
		"supporter:sada-too-early": 100.0,
	}, facts_before, "ability:teal-dance")
	var dance_candidate := _candidate(frontier, "ability:teal-dance")
	var dance_roles: Array = dance_candidate.get("action_semantic_roles", []) \
		if dance_candidate.get("action_semantic_roles", []) is Array else []
	var after := before.duplicate(true)
	after["observation_version"] = 2
	after["observation_hash"] = "raging-after-teal-dance"
	after["own"]["bench"][0]["energy"] = [_energy("G")]
	after["own"]["bench"][0]["energy_count"] = 1
	after["own"]["hand"] = [_card("CSV6C_121"), _energy("L")]
	after["own"]["deck_count"] = 17
	after["legal_actions"] = [sada_action]
	var facts_after := _facts(false, false, true, 2, false, false, 0)
	facts_after["resources"]["energy_on_board"] = 3
	var delta := MaterialDeltaScript.new().compare(before, after, facts_before, facts_after)
	var reopens := _epoch_reopens(before, after, facts_before, facts_after, dance_candidate, frontier)
	_check("energy_accelerator" in dance_roles and "ability_engine" in dance_roles \
		and str(dance_candidate.get("checkpoint_after", "")) == "information_result", \
		"scenario 1 Teal Dance must remain a typed attach-and-draw checkpoint")
	_check(bool(delta.get("material", false)) and reopens, \
		"scenario 1 the public attach plus revealed draw must reopen exactly once before the supporter choice")
	_rows.append(_row(
		"teal_dance_before_supporter",
		"碧草之舞/填能/支援者顺序",
		"先用真实碧草之舞把手牌草能贴给厄诡椪并抽1张；公开结果改变场上能量与合法动作后才重新决定支援者。无草能或同回合第二次使用均失败关闭。",
		"ability:teal-dance -> public information checkpoint -> supporter decision",
		"real_effect_and_material_information_epoch",
		real_effect_ok and reopens
	))


func _scenario_2_vessel_makes_sada_live() -> void:
	var state := _game_state()
	var bolt := _real_slot(_real_card_data(RAGING_BOLT_UID), 0)
	state.players[0].active_pokemon = bolt
	var vessel := CardInstance.create(_real_card_data("CSV6C_115"), 0)
	var sada := CardInstance.create(_real_card_data("CSV6C_121"), 0)
	var fighting := _real_energy("CSVE1C_FIG", 0)
	var lightning := _real_energy("CSVE1C_LIG", 0)
	var grass := _real_energy("CSVE1C_GRA", 0)
	state.players[0].hand = [vessel, sada, fighting]
	state.players[0].deck = [
		lightning, grass,
		_filler("Sada draw A", 0), _filler("Sada draw B", 0), _filler("Sada draw C", 0),
	]
	var vessel_effect = VesselScript.new(2, 1)
	var sada_effect = SadaScript.new()
	var sada_dead_before := not sada_effect.can_execute(sada, state)
	vessel_effect.execute(vessel, [{
		"discard_cards": [fighting],
		"search_energy": [lightning, grass],
	}], state)
	var sada_live_after_vessel := sada_effect.can_execute(sada, state)
	sada_effect.execute(sada, [{
		"sada_assignments": [{"source": fighting, "target": bolt}],
	}], state)
	var sequence_ok := sada_dead_before \
		and sada_live_after_vessel \
		and fighting in bolt.attached_energy \
		and lightning in state.players[0].hand \
		and grass in state.players[0].hand \
		and fighting not in state.players[0].discard_pile \
		and state.players[0].hand.size() == 7
	_check(sequence_ok, \
		"scenario 2 Vessel must discard Fighting, search Lightning+Grass, then make real Sada acceleration live and draw three")

	var public_before := _observation(
		[_play_trainer("item:earthen-vessel", "CSV6C_115", true), _end_turn("end:premature")],
		_slot("slot:bolt", RAGING_BOLT_UID, []), [], 5
	)
	public_before["own"]["hand"] = [_card("CSV6C_115"), _energy("F"), _card("CSV6C_121")]
	var facts_before := _facts(false, false, true, 3, false, false, 0)
	var vessel_frontier := _frontier(public_before, {
		"item:earthen-vessel": 500.0,
		"end:premature": -500.0,
	}, facts_before, "item:earthen-vessel")
	var vessel_candidate := _candidate(vessel_frontier, "item:earthen-vessel")
	var public_after := _observation(
		[_play_trainer("supporter:sada", "CSV6C_121", true), _end_turn("end:still-premature")],
		_slot("slot:bolt", RAGING_BOLT_UID, []), [], 3
	)
	public_after["observation_version"] = 2
	public_after["observation_hash"] = "raging-after-vessel"
	public_after["own"]["hand"] = [_card("CSV6C_121"), _energy("L"), _energy("G")]
	public_after["own"]["discard"] = [_energy("F")]
	var facts_after := _facts(false, false, true, 3, false, false, 0)
	var reopens := _epoch_reopens(
		public_before, public_after, facts_before, facts_after, vessel_candidate, vessel_frontier
	)
	var sada_frontier := _frontier(public_after, {
		"supporter:sada": 500.0,
		"end:still-premature": -500.0,
	}, facts_after, "end:still-premature")
	var sada_candidate := _candidate(sada_frontier, "supporter:sada")
	var sada_annotation := _module_annotation(sada_candidate, "energy_burst")
	_check(reopens \
		and str(sada_candidate.get("route_id", "")) == "route:accelerate" \
		and bool((sada_annotation.get("acceleration", {}) as Dictionary).get("sada_live", false)), \
		"scenario 2 the Vessel result must reopen into a publicly live Sada acceleration route")
	_rows.append(_row(
		"vessel_discard_then_sada",
		"能量检索/弃牌燃料/支援者顺序",
		"大地容器先弃斗能并找雷能+草能：斗能进入公开弃牌区后奥琳博士才合法，把斗能贴回古代猛雷鼓并抽3。倒序时奥琳博士没有合法能量来源。",
		"item:earthen-vessel(F discard; L+G search) -> supporter:sada(F attach) -> draw 3",
		"public_discard_energy_acceleration",
		sequence_ok and reopens
	))


func _scenario_3_exact_burst_discard_preserves_cost() -> void:
	var fixture := _burst_state(210, 4)
	var processor: EffectProcessor = fixture["processor"]
	var state: GameState = fixture["state"]
	var bolt: PokemonSlot = fixture["bolt"]
	var ogerpon: PokemonSlot = fixture["ogerpon"]
	var grass: Array = fixture["grass"]
	var selected := [grass[0], grass[1], grass[2]]
	var bonus := processor.get_attack_damage_bonus_by_id(
		RAGING_BOLT_EFFECT_ID, 1, bolt, state, [{"discard_basic_energy": selected}]
	)
	processor.execute_attack_effect_by_id(
		RAGING_BOLT_EFFECT_ID, 1, bolt, state.players[1].active_pokemon, state,
		[{"discard_basic_energy": selected}]
	)
	var public_after := _real_board_observation(state)
	var snapshot := _energy_burst.visible_energy_snapshot(public_after, _profile)
	var plan := _energy_burst.discard_plan(210, 6, 3, 70)
	var minimum_certificate := _energy_burst.verified_minimum_discard_choice(4, 210, 6, 3, 70)
	var exact_ok := bonus + 70 == 210 \
		and state.players[0].discard_pile.size() == 3 \
		and bolt.attached_energy.size() == 2 \
		and ogerpon.attached_energy.size() == 1 \
		and bool(snapshot.get("primary_cost_ready", false)) \
		and int(plan.get("discard_count", -1)) == 3 \
		and bool(minimum_certificate.get("verified", false)) \
		and int(minimum_certificate.get("preserved_basic_energy", 0)) == 1
	_check(exact_ok, \
		"scenario 3 must deal exactly 210 by discarding three Grass while preserving Raging Bolt's Lightning+Fighting cost")

	var bad := _burst_state(210, 4)
	var bad_processor: EffectProcessor = bad["processor"]
	var bad_state: GameState = bad["state"]
	var bad_bolt: PokemonSlot = bad["bolt"]
	var bad_grass: Array = bad["grass"]
	var bad_selection := [bad["fighting"], bad_grass[0], bad_grass[1]]
	bad_processor.execute_attack_effect_by_id(
		RAGING_BOLT_EFFECT_ID, 1, bad_bolt, bad_state.players[1].active_pokemon, bad_state,
		[{"discard_basic_energy": bad_selection}]
	)
	var bad_snapshot := _energy_burst.visible_energy_snapshot(_real_board_observation(bad_state), _profile)
	_check(not bool(bad_snapshot.get("primary_cost_ready", true)), \
		"scenario 3 negative: equal-damage selection that discards Fighting must fail the next-attack-cost reserve")
	_rows.append(_row(
		"minimum_burst_discard_preserves_lf",
		"极雷轰/最少弃能/保留攻击费用",
		"对210HP目标只从厄诡椪侧丢3草能，真实伤害为3×70；保留猛雷鼓自身雷+斗与厄诡椪1草。丢4张属于过量，丢自身斗能虽同伤害但破坏下一次攻击费用。",
		"discard 3x Grass from Ogerpon; preserve Lightning+Fighting on Raging Bolt",
		"public_minimum_resource_ko",
		exact_ok
	))


func _scenario_4_energy_switch_and_free_pivot() -> void:
	var state := _game_state()
	var processor := EffectProcessor.new()
	var ogerpon := _real_slot(_real_card_data(OGERPON_UID), 0)
	var bolt := _real_slot(_real_card_data(RAGING_BOLT_UID), 0)
	var latias_data := _real_card_data(LATIAS_UID)
	var latias := _real_slot(latias_data, 0)
	var grass := _real_energy("CSVE1C_GRA", 0)
	var fighting := _real_energy("CSVE1C_FIG", 0)
	var lightning := _real_energy("CSVE1C_LIG", 0)
	ogerpon.attached_energy = [grass, fighting]
	bolt.attached_energy = [lightning]
	state.players[0].active_pokemon = ogerpon
	state.players[0].bench = [bolt, latias]
	processor.register_pokemon_card(latias_data)
	var free_retreat_before := processor.get_effective_retreat_cost(ogerpon, state) == 0
	var switch_effect = EnergySwitchScript.new()
	var switch_card := CardInstance.create(_real_card_data("CSVH1aC_008"), 0)
	var steps := switch_effect.get_interaction_steps(switch_card, state)
	switch_effect.execute(switch_card, [{
		"energy_assignment": [{"source": fighting, "target": bolt}],
	}], state)
	var move_ok := fighting in bolt.attached_energy \
		and lightning in bolt.attached_energy \
		and fighting not in ogerpon.attached_energy
	state.players[0].active_pokemon = bolt
	state.players[0].bench.erase(bolt)
	state.players[0].bench.append(ogerpon)
	var switched_snapshot := _energy_burst.visible_energy_snapshot(_real_board_observation(state), _profile)
	_check(free_retreat_before and move_ok and not steps.is_empty() \
		and str(steps[0].get("id", "")) == "energy_assignment" \
		and bool(switched_snapshot.get("primary_cost_ready", false)), \
		"scenario 4 real Energy Switch plus Latias Skyline must convert active Ogerpon into a free Raging Bolt pivot with LF ready")

	var no_latias_state := _game_state()
	var no_latias_ogerpon := _real_slot(_real_card_data(OGERPON_UID), 0)
	no_latias_ogerpon.attached_energy = [_real_energy("CSVE1C_GRA", 0)]
	no_latias_state.players[0].active_pokemon = no_latias_ogerpon
	no_latias_state.players[0].bench = [_real_slot(_real_card_data(RAGING_BOLT_UID), 0)]
	_check(processor.get_effective_retreat_cost(no_latias_ogerpon, no_latias_state) == 1, \
		"scenario 4 negative: without public Latias, Ogerpon-to-Bolt is not a free-retreat pivot")
	_rows.append(_row(
		"energy_switch_ogerpon_to_raging_bolt",
		"厄诡椪/猛雷鼓换位",
		"前台厄诡椪持草+斗、后备猛雷鼓持雷时，能量转移把斗能移给猛雷鼓；场上拉帝亚斯ex天际线令基础宝可梦撤退费用归零，再换猛雷鼓到前台形成雷斗攻击费用。无拉帝亚斯时不得伪造免费换位。",
		"Energy Switch(F Ogerpon->Bolt) -> free retreat via Latias -> Raging Bolt active",
		"real_energy_assignment_and_public_free_retreat",
		free_retreat_before and move_ok and bool(switched_snapshot.get("primary_cost_ready", false))
	))


func _scenario_5_exact_two_prize_closeout() -> void:
	var observation := _observation(
		[
			_play_trainer("supporter:iono-too-late", "CSV3C_123", false),
			_attack("attack:bellowing-thunder", "slot:bolt", RAGING_BOLT_UID, 1, 280, true),
		],
		_slot("slot:bolt", RAGING_BOLT_UID, [_energy("L"), _energy("F")]),
		[
			_slot("slot:ogerpon", OGERPON_UID, [_energy("G"), _energy("G"), _energy("G"), _energy("G"), _energy("G")]),
		],
		9
	)
	observation["own"]["prizes_remaining"] = 2
	observation["opponent"]["active"] = _public_target("PUBLIC_TWO_PRIZE_EX", 280, 2)
	var facts := _facts(true, true, false, 2, true, false, 280)
	facts["resources"]["prizes_remaining"] = 2
	facts["resources"]["energy_on_board"] = 7
	facts["prize"] = {"current_swing": 2, "win_now": true}
	var frontier := _frontier(observation, {
		"supporter:iono-too-late": 700.0,
		"attack:bellowing-thunder": 10.0,
	}, facts, "supporter:iono-too-late")
	var attack_candidate := _candidate(frontier, "attack:bellowing-thunder")
	var safety := _route_safety(attack_candidate, frontier, facts)
	var burst_annotation := _module_annotation(attack_candidate, "energy_burst")
	var damage_resource: Dictionary = burst_annotation.get("damage_resource", {}) \
		if burst_annotation.get("damage_resource", {}) is Dictionary else {}
	var plan := _energy_burst.discard_plan(280, 7, 3, 70)
	var terminal_ok := bool((attack_candidate.get("outcome", {}) as Dictionary).get("win_now", false)) \
		and bool(safety.get("valid", false)) \
		and str(safety.get("reason", "")) == "deterministic_win_now" \
		and int(plan.get("discard_count", -1)) == 4 \
		and int(plan.get("remaining_energy", -1)) == 3 \
		and int(damage_resource.get("required_units", -1)) == 4 \
		and bool(damage_resource.get("reserve_met_after_required_units", false))
	_check(terminal_ok, \
		"scenario 5 exact four-discard 280 KO must take the last two prizes before optional Iono")

	var impossible_plan := _energy_burst.discard_plan(281, 7, 3, 70)
	var unknown_plan := _energy_burst.discard_plan(0, 7, 3, 70)
	_check(not bool(impossible_plan.get("payable", true)) \
		and not bool(unknown_plan.get("payable", true)), \
		"scenario 5 negative: 281 HP or unknown HP cannot claim a reserve-safe terminal KO")
	_rows.append(_row(
		"exact_two_prize_closeout",
		"关键奖收割/终局停止抽滤",
		"己方剩2奖、对手前台280HP双奖ex，场上7张基础能量时极雷轰只丢4张并留下3张储备，直接结束比赛；拒绝先用奇树，也拒绝把281HP或未知HP伪报为可收割。",
		"attack:bellowing-thunder(discard exactly 4) before supporter:iono",
		str(safety.get("reason", "")),
		terminal_ok
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
		"scenario frontier must not copy hidden sentinels")
	return annotated


func _route_safety(selected: Dictionary, frontier: Array[Dictionary], facts: Dictionary) -> Dictionary:
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
	_check(false, "candidate %s must exist" % action_id)
	return {}


func _module_annotation(candidate: Dictionary, module_id: String) -> Dictionary:
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	return annotations.get(module_id, {}) if annotations.get(module_id, {}) is Dictionary else {}


func _observation(actions: Array, active: Dictionary, bench: Array, deck_count: int) -> Dictionary:
	return {
		"observation_version": 1,
		"observation_hash": "raging-bolt-complex-scenario",
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
			"hand": [{"uid": "FORBIDDEN_SECRET"}],
			"deck_order": ["FORBIDDEN_SECRET"],
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
		"board": {"bench_full": false, "has_tera": true},
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
		"remaining_hp": 210 if uid == OGERPON_UID else 240,
		"max_hp": 210 if uid == OGERPON_UID else 240,
		"prize_count": 2,
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


func _ability(action_id: String, source: String, uid: String, interaction: bool) -> Dictionary:
	return {
		"id": action_id,
		"kind": "use_ability",
		"source": source,
		"source_card": _card(uid),
		"ability_index": 0,
		"requires_interaction": interaction,
	}


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


func _end_turn(action_id: String) -> Dictionary:
	return {"id": action_id, "kind": "end_turn"}


func _energy(symbol: String) -> Dictionary:
	var uids := {"G": "CSVE1C_GRA", "F": "CSVE1C_FIG", "L": "CSVE1C_LIG"}
	var energy := _card(str(uids.get(symbol, "CSVE1C_GRA")))
	energy["energy_type"] = symbol
	energy["energy_provides"] = symbol
	energy["semantic_roles"] = ["energy_source", "typed_energy", "basic_energy"]
	return energy


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


func _real_energy(uid: String, owner: int) -> CardInstance:
	return CardInstance.create(_real_card_data(uid), owner)


func _filler(name: String, owner: int) -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = "Item"
	return CardInstance.create(data, owner)


func _real_target(name: String, hp: int, mechanic: String, owner: int) -> PokemonSlot:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = "Pokemon"
	data.stage = "Basic"
	data.hp = hp
	data.mechanic = mechanic
	return _real_slot(data, owner)


func _burst_state(target_hp: int, grass_count: int) -> Dictionary:
	var state := _game_state()
	var processor := EffectProcessor.new()
	var bolt_data := _real_card_data(RAGING_BOLT_UID)
	processor.register_pokemon_card(bolt_data)
	var bolt := _real_slot(bolt_data, 0)
	var ogerpon := _real_slot(_real_card_data(OGERPON_UID), 0)
	var lightning := _real_energy("CSVE1C_LIG", 0)
	var fighting := _real_energy("CSVE1C_FIG", 0)
	bolt.attached_energy = [lightning, fighting]
	var grass: Array[CardInstance] = []
	for _index: int in grass_count:
		grass.append(_real_energy("CSVE1C_GRA", 0))
	ogerpon.attached_energy.assign(grass)
	state.players[0].active_pokemon = bolt
	state.players[0].bench = [ogerpon]
	state.players[1].active_pokemon = _real_target("Public target", target_hp, "ex", 1)
	return {
		"processor": processor,
		"state": state,
		"bolt": bolt,
		"ogerpon": ogerpon,
		"lightning": lightning,
		"fighting": fighting,
		"grass": grass,
	}


func _real_board_observation(state: GameState) -> Dictionary:
	var own := state.players[0]
	var opponent := state.players[1]
	var bench: Array = []
	for index: int in own.bench.size():
		bench.append(_slot_from_real(own.bench[index], "slot:bench-%d" % index))
	return {
		"own": {
			"active": _slot_from_real(own.active_pokemon, "slot:active"),
			"bench": bench,
			"hand": [],
			"discard": _cards_from_real(own.discard_pile),
			"deck_count": own.deck.size(),
		},
		"opponent": {
			"active": _slot_from_real(opponent.active_pokemon, "slot:opponent-active"),
			"bench": [],
		},
		"legal_actions": [],
	}


func _slot_from_real(slot: PokemonSlot, slot_id: String) -> Dictionary:
	if slot == null or slot.get_card_data() == null:
		return {}
	var energies: Array = []
	for energy_card: CardInstance in slot.attached_energy:
		energies.append(_public_card_from_real(energy_card))
	return {
		"slot_id": slot_id,
		"pokemon": _public_card_from_real(slot.get_top_card()),
		"energy": energies,
		"energy_count": energies.size(),
		"remaining_hp": maxi(0, slot.get_card_data().hp - slot.damage_counters),
	}


func _cards_from_real(cards: Array[CardInstance]) -> Array:
	var result: Array = []
	for card: CardInstance in cards:
		result.append(_public_card_from_real(card))
	return result


func _public_card_from_real(card: CardInstance) -> Dictionary:
	if card == null or card.card_data == null:
		return {}
	return {
		"uid": card.card_data.get_uid(),
		"effect_id": card.card_data.effect_id,
		"name": card.card_data.name_en if card.card_data.name_en != "" else card.card_data.name,
		"type": card.card_data.card_type,
		"energy_type": card.card_data.energy_type,
		"energy_provides": card.card_data.energy_provides,
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
		"deck_name": "18.0 猛雷鼓厄诡椪",
		"strategy_id": str(_profile.get("strategy_id", "")),
		"profile_version": int(_profile.get("profile_version", 0)),
		"latest_pilot_evidence": {
			"artifact": "res://tmp/v18cpg/raging_final_n10.json",
			"games": 10,
			"rule_wins": 6,
			"v18cpg_wins": 6,
			"paired_improvement": 0.0,
			"note": "This focused report adds deterministic scenario coverage; it does not claim a new benchmark or promotion.",
		},
		"scenario_count": _rows.size(),
		"passed_count": _rows.filter(func(row: Dictionary) -> bool: return bool(row.get("passed", false))).size(),
		"all_passed": _failures.is_empty() and _rows.size() == 5,
		"isolation": {
			"test_only": true,
			"profile_modified": false,
			"shared_runtime_modified": false,
			"rule_or_legacy_or_agent_modified": false,
			"formal_or_real_model_run": false,
		},
		"coverage": [
			"real Teal Dance hand-Grass attachment, draw, once-per-turn and no-Grass negative",
			"real Earthen Vessel discard/search followed by real Professor Sada acceleration",
			"real Bellowing Thunder exact discard identities and LF cost preservation",
			"real Energy Switch assignment plus Latias public free-retreat pivot",
			"exact reserve-safe two-prize closeout and 281/unknown-HP negatives",
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
