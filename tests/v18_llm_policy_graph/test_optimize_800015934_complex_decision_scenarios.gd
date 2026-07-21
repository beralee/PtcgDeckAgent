extends SceneTree

const NoctowlSearchScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGTeraNoctowlSearch.gd")
const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")

const DECK_ID := 800015934
const REPORT_PATH := "res://tmp/v18cpg/optimization21/800015934/complex_decision_scenarios.json"

var _module = NoctowlSearchScript.new()
var _profile: Dictionary = {}
var _failures: Array[String] = []
var _scenarios: Array[Dictionary] = []


func _initialize() -> void:
	_profile = ProfileCatalogScript.get_profile_for_deck(DECK_ID)
	_check(int(_profile.get("deck_id", 0)) == DECK_ID, "production Tord profile must load")
	_check(_profile.get("modules", []) == ["tera_noctowl_search", "energy_burst", "cycle_pivot"], \
		"Tord must use its production Noctowl, energy-burst, and pivot composition")
	_scenario_tera_then_fan_call()
	_scenario_route_bound_pair_order()
	_scenario_live_energy_mover_only()
	_scenario_secured_ko_stops_churn()
	_scenario_critical_deck_explicit_whiff()
	_write_report()
	if _failures.is_empty() and _scenarios.size() == 5:
		print("optimization21 800015934 complex decision scenarios: PASS (5/5)")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("optimization21 800015934 complex decision scenarios: FAIL (%d)" % _failures.size())
	quit(1)


func _scenario_tera_then_fan_call() -> void:
	var frontier: Array[Dictionary] = [{"route_id": "route:noctowl_search"}]
	var observation := {
		"own": {"deck_count": 30, "active": {}, "bench": []},
		"turn": {"quotas": {"supporter_available": true, "energy_available": true}},
	}
	var missing := _annotation(frontier, observation, false, true)
	var ready := _annotation(frontier, observation, true, true)
	var passed := not bool(missing.get("executable", true)) \
		and str(missing.get("warning", "")) == "tera_condition_missing" \
		and bool(ready.get("executable", false))
	_record(
		"tera_before_fan_call",
		"进化/特性启动",
		"先让太晶宝可梦进入公开场面，再进化猫头夜鹰并使用宝石探寻；缺少太晶条件时不得伪造特性可用。",
		"bench Tera -> evolve Noctowl -> Fan Call",
		"public_tera_gate_before_registered_ability",
		passed
	)


func _scenario_route_bound_pair_order() -> void:
	var vessel := _trainer("Earthen Vessel", "Item", "Search your deck for up to 2 Basic Energy cards.")
	var mover := _trainer("Energy Switch", "Item", "Move a basic Energy from 1 of your Pokemon to another.")
	var nest := _trainer("Nest Ball", "Item", "Search your deck for a Basic Pokemon and put it onto your Bench.")
	var stadium := _trainer("Area Zero Underdepths", "Stadium", "Your Bench can have up to 8 Pokemon if you have a Tera Pokemon in play.")
	var step := {"id": "csv9c_noctowl_trainers", "min_select": 2, "max_select": 2}
	var live_context := {
		"v18cpg_facts": {"turn": {"supporter_available": true}},
		"v18cpg_observation": {"own": {"active": {"energy_count": 1}, "bench": []}},
	}
	var energy_pair := _module.pick_pair(
		[vessel, mover, nest, stadium], step, live_context, _profile, {}, "route:energy_commit"
	)
	var develop_pair := _module.pick_pair(
		[vessel, mover, nest, stadium], step, live_context, _profile, {}, "route:develop"
	)
	var passed := vessel in energy_pair and mover in energy_pair \
		and nest in develop_pair and stadium in develop_pair
	_record(
		"fan_call_route_bound_pairs",
		"特性/检索/填能顺序",
		"宝石探寻不能逐卡贪分：缺攻击费用时成对找大地容器与能量转移；需要展开时成对找零之大空洞与巢穴球。",
		"Fan Call -> route-completing pair -> information checkpoint",
		"public_complementary_search_pair",
		passed
	)


func _scenario_live_energy_mover_only() -> void:
	var vessel := _trainer("Earthen Vessel", "Item", "Search your deck for up to 2 Basic Energy cards.")
	var mover := _trainer("Energy Switch", "Item", "Move a basic Energy from 1 of your Pokemon to another.")
	var crispin := _trainer("Crispin", "Supporter", "Search your deck for 2 Basic Energy cards. Attach 1 to your Pokemon.")
	var picked := _module.pick_pair(
		[vessel, mover, crispin],
		{"id": "csv9c_noctowl_trainers", "min_select": 2, "max_select": 2},
		{
			"v18cpg_facts": {"turn": {"supporter_available": true}},
			"v18cpg_observation": {"own": {"active": {"energy_count": 0}, "bench": []}},
		},
		_profile,
		{},
		"route:accelerate"
	)
	var passed := crispin in picked and vessel in picked and mover not in picked
	_record(
		"supporter_acceleration_before_dead_mover",
		"支援者/填能顺序",
		"场上没有可移动能量时，猫头夜鹰应找出古俐斯与大地容器完成属性填能，而不是找一张当前必定空放的能量转移。",
		"Fan Call(Crispin + Vessel) -> supporter acceleration -> attach",
		"dead_energy_mover_rejected",
		passed
	)


func _scenario_secured_ko_stops_churn() -> void:
	var vessel := _trainer("Earthen Vessel", "Item", "Search your deck for up to 2 Basic Energy cards.")
	var mover := _trainer("Energy Switch", "Item", "Move a basic Energy from 1 of your Pokemon to another.")
	var boss := _trainer("Boss's Orders", "Supporter", "Switch in 1 of your opponent's Benched Pokemon.")
	var stretcher := _trainer("Night Stretcher", "Item", "Put a Pokemon or Basic Energy from your discard pile into your hand.")
	var picked := _module.pick_pair(
		[vessel, mover, boss, stretcher],
		{"id": "csv9c_noctowl_trainers", "min_select": 2, "max_select": 2},
		{"v18cpg_facts": {"attack": {"ready": true, "ko_available": true}}},
		_profile,
		{},
		"route:attack_ko"
	)
	var passed := boss in picked and stretcher in picked and vessel not in picked and mover not in picked
	_record(
		"minimum_resource_key_prize_closeout",
		"支援者/关键奖/停止抽滤",
		"公开攻击已经能击倒拿到关键奖时，保留老大的指令与夜间担架，停止额外找能量和搬能量，直接走最短取奖路线。",
		"preserve gust + recovery -> attack KO -> take key prizes",
		"public_minimum_resource_ko",
		passed
	)


func _scenario_critical_deck_explicit_whiff() -> void:
	var search := _trainer("Generic Search Item", "Item", "Search your deck for a card.")
	var picked := _module.pick_pair(
		[search],
		{"id": "csv9c_noctowl_trainers", "min_select": 0, "max_select": 2},
		{"v18cpg_facts": {"resources": {"deck_low": true, "deck_critical": true}}},
		_profile,
		{},
		"route:noctowl_search"
	)
	var passed := picked.is_empty()
	_record(
		"critical_deck_explicit_empty",
		"抽牌/牌库耗尽控制",
		"牌库进入临界区且搜索允许空选时，明确放弃猫头夜鹰检索，不为无收益抽滤增加牌库耗尽风险。",
		"Fan Call explicit empty -> preserve deck margin",
		"critical_deck_search_whiff",
		passed
	)


func _annotation(
	frontier: Array[Dictionary],
	observation: Dictionary,
	has_tera: bool,
	fan_call_available: bool
) -> Dictionary:
	var annotated := _module.annotate_frontier(frontier, observation, {
		"board": {"has_tera": has_tera},
		"fan_call": {"available": fan_call_available},
		"attack": {"ready": false, "ko_available": false},
	}, _profile)
	return (annotated[0] as Dictionary).get("module_annotations", {}).get("tera_noctowl_search", {})


func _trainer(name_en: String, card_type: String, description: String) -> CardData:
	var data := CardData.new()
	data.name_en = name_en
	data.card_type = card_type
	data.description = description
	return data


func _record(
	id: String,
	category: String,
	description: String,
	expected_choice: String,
	proof_reason: String,
	passed: bool
) -> void:
	_check(passed, "%s must pass" % id)
	_scenarios.append({
		"id": id,
		"category": category,
		"description": description,
		"expected_choice": expected_choice,
		"proof_reason": proof_reason,
		"passed": passed,
	})


func _write_report() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT_PATH.get_base_dir()))
	var report := {
		"schema_version": 1,
		"architecture": "V18CPG",
		"semantic_schema": "v18cpg-2",
		"transport_contract_version": 3,
		"deck_id": DECK_ID,
		"deck_name": "18.0 Tord太晶盒",
		"strategy_id": str(_profile.get("strategy_id", "")),
		"profile_version": int(_profile.get("profile_version", 0)),
		"scenario_count": _scenarios.size(),
		"passed_count": _scenarios.filter(func(row: Dictionary) -> bool: return bool(row.get("passed", false))).size(),
		"all_passed": _failures.is_empty(),
		"scenarios": _scenarios.duplicate(true),
		"failures": _failures.duplicate(),
		"isolation": {
			"rule_or_legacy_or_agent_modified": false,
			"shared_runtime_modified": false,
			"test_only": true,
		},
	}
	var output := FileAccess.open(ProjectSettings.globalize_path(REPORT_PATH), FileAccess.WRITE)
	if output == null:
		_failures.append("unable to write Tord complex scenario artifact")
		return
	output.store_string(JSON.stringify(report, "  "))
	output.close()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
