extends SceneTree

const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const RouteSearchScript = preload("res://scripts/ai/v18_cpg/planning/V18CPGRouteSearch.gd")
const CapabilityRegistryScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCapabilityRegistry.gd")
const MaterialDeltaScript = preload("res://scripts/ai/v18_cpg/observation/V18CPGMaterialDelta.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")

const DECK_ID := 800017407
const MANIFEST_PATH := "res://scripts/ai/v18_cpg/profiles/generated_semantic_manifests/800017407.json"
const REPORT_PATH := "res://tmp/v18cpg/optimization21/800017407/complex_decision_scenarios.json"

var _profile: Dictionary = {}
var _manifest: Dictionary = {}
var _failures: Array[String] = []
var _rows: Array[Dictionary] = []


func _initialize() -> void:
	_profile = ProfileCatalogScript.get_profile_for_deck(DECK_ID)
	_manifest = _load_json(MANIFEST_PATH)
	_check(int(_profile.get("deck_id", 0)) == DECK_ID, "the production Hop Zacian profile must load")
	_check(int(_manifest.get("deck_id", 0)) == DECK_ID, "the generated Hop Zacian semantic manifest must load")
	_check(_profile.get("modules", []) == ["partner_chain", "energy_burst", "cycle_pivot"], \
		"the five scenarios must exercise the production capability composition")

	_scenario_1_typed_energy_completion()
	_scenario_2_partner_lane_before_optional_engine()
	_scenario_3_draw_ability_information_checkpoint()
	_scenario_4_information_then_supporter_order()
	_scenario_5_public_two_prize_closeout()
	_write_report()

	if _failures.is_empty() and _rows.size() == 5:
		print("optimization21 800017407 complex decision scenarios: PASS (5/5)")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("optimization21 800017407 complex decision scenarios: FAIL (%d)" % _failures.size())
	quit(1)


func _scenario_1_typed_energy_completion() -> void:
	var observation := _observation([
		_action_attach("attach:utility", "slot:utility"),
		_action_attach("attach:cramorant", "slot:active"),
	], {
		"slot_id": "slot:active",
		"pokemon": _card("CSV10C_188"),
		"energy": [],
	}, [{
		"slot_id": "slot:utility",
		"pokemon": _card("151C_151"),
		"energy": [],
	}])
	observation["turn"] = {"deterministic_attack_window_open": true}
	var facts := _facts(false, false, true, 4)
	var frontier := _frontier(observation, {
		"attach:utility": 420.0,
		"attach:cramorant": 40.0,
	}, facts, "attach:utility")
	var selected := _candidate(frontier, "attach:cramorant")
	var safety := _route_safety(selected, frontier, facts)
	var attachment := _module_field(selected, "energy_burst", "attachment")
	_check(not selected.is_empty(), "scenario 1 must preserve the exact Cramorant attachment candidate")
	_check(bool(attachment.get("target_is_primary_attacker", false)), \
		"scenario 1 must bind the attachment to the profiled attacker")
	_check(bool(attachment.get("completes_required_types", false)), \
		"scenario 1 Darkness attachment must complete the public attack cost")
	_check(bool(safety.get("valid", false)) and str(safety.get("reason", "")) == "module_verified_advantage", \
		"scenario 1 attack-cost completion must override the bad Rule attachment only through a certificate")
	_check(str((safety.get("advantage", {}) as Dictionary).get("certificate_kind", "")) \
		== "public_typed_attack_cost_completion", \
		"scenario 1 must emit the typed attack-cost certificate")
	_rows.append(_row(
		"typed_energy_completion",
		"填能",
		"将恶能手贴给赫普的古月鸟，补齐本回合攻击费用；拒绝贴给梦幻ex的无关线路。",
		"attach:cramorant",
		str(safety.get("reason", "")),
		bool(safety.get("valid", false))
	))


func _scenario_2_partner_lane_before_optional_engine() -> void:
	var observation := _observation([
		_action_bench("bench:zacian", "CSV10C_161"),
		_action_bench("bench:fezandipiti", "CSV8C_135"),
	], {
		"slot_id": "slot:active",
		"pokemon": _card("CSV10C_188"),
		"energy": [{"type": "Basic Energy", "energy_type": "D"}],
	}, [{
		"slot_id": "slot:partner",
		"pokemon": _card("CSV10C_175"),
		"energy": [],
	}])
	var facts := _facts(true, false, false, 5)
	var frontier := _frontier(observation, {
		"bench:zacian": 320.0,
		"bench:fezandipiti": 300.0,
	}, facts, "bench:zacian")
	var partner := _candidate(frontier, "bench:zacian")
	var optional_engine := _candidate(frontier, "bench:fezandipiti")
	var safety := _route_safety(optional_engine, frontier, facts)
	var optional_cycle := _module_annotation(optional_engine, "cycle_pivot")
	_check("partner_piece" in (partner.get("action_semantic_roles", []) as Array), \
		"scenario 2 Zacian must come from the generated partner semantics")
	_check(bool(optional_cycle.get("optional_draw_engine", false)), \
		"scenario 2 Fezandipiti must be recognized as the optional draw engine")
	_check(not bool(safety.get("valid", true)) \
		and str(safety.get("reason", "")) == "flareon_ready_attack_blocks_optional_engine" \
		and str(safety.get("module", "")) == "cycle_pivot", \
		"scenario 2 must keep the partner attacker lane instead of consuming the turn on optional draw")
	_rows.append(_row(
		"partner_lane_before_optional_engine",
		"上场链",
		"现有攻击已就绪时，先铺赫普的苍响ex伙伴后续攻击线，不用吉雉鸡ex挤占计划。",
		"bench:zacian",
		str(safety.get("reason", "")),
		not bool(safety.get("valid", true))
	))


func _scenario_3_draw_ability_information_checkpoint() -> void:
	var ability := {
		"id": "ability:fezandipiti",
		"kind": "use_ability",
		"source": "slot:engine",
		"source_card": _card("CSV8C_135"),
		"ability_index": 0,
		"requires_interaction": true,
	}
	var observation := _observation([
		{"id": "end:turn", "kind": "end_turn"},
		ability,
	], {
		"slot_id": "slot:active",
		"pokemon": _card("151C_151"),
		"energy": [],
	}, [{
		"slot_id": "slot:engine",
		"pokemon": _card("CSV8C_135"),
		"energy": [],
	}])
	var facts := _facts(false, false, false, 1)
	var frontier := _frontier(observation, {
		"end:turn": 200.0,
		"ability:fezandipiti": 180.0,
	}, facts, "end:turn")
	var selected := _candidate(frontier, "ability:fezandipiti")
	var safety := _route_safety(selected, frontier, facts)
	var outcome: Dictionary = selected.get("outcome", {}) if selected.get("outcome", {}) is Dictionary else {}
	_check(str(selected.get("route_id", "")) == "route:information", \
		"scenario 3 the draw ability must be a typed information route")
	_check(str(selected.get("checkpoint_after", "")) == "information_result", \
		"scenario 3 must stop at the revealed draw result before choosing the next action")
	_check(float(outcome.get("information_gain", 0.0)) > 0.0, \
		"scenario 3 must expose positive information value at a healthy deck count")
	_check(bool(safety.get("valid", false)), \
		"scenario 3 low-hand draw ability must remain an admissible improvement over ending the turn")
	_rows.append(_row(
		"draw_ability_information_checkpoint",
		"使用特性",
		"没有现成攻击且手牌不足时使用吉雉鸡ex抽牌特性，并在新手牌公开后重新比较路线。",
		"ability:fezandipiti",
		str(safety.get("reason", "")),
		bool(safety.get("valid", false))
	))


func _scenario_4_information_then_supporter_order() -> void:
	var pokegear := {
		"id": "item:pokegear",
		"kind": "play_trainer",
		"card": _card("CSV2C_113"),
		"requires_interaction": true,
	}
	var research := {
		"id": "supporter:research",
		"kind": "play_trainer",
		"card": _card("CSV1C_121"),
		"requires_interaction": false,
	}
	var before := _observation([pokegear, research], {
		"slot_id": "slot:active",
		"pokemon": _card("CSV10C_175"),
		"energy": [],
	}, [])
	before["observation_version"] = 1
	before["observation_hash"] = "hop-order-before"
	var facts_before := _facts(false, false, false, 3)
	var frontier_before := _frontier(before, {
		"item:pokegear": 330.0,
		"supporter:research": 80.0,
	}, facts_before, "item:pokegear")
	var pokegear_candidate := _candidate(frontier_before, "item:pokegear")
	var premature_research := _candidate(frontier_before, "supporter:research")
	var premature_safety := _route_safety(premature_research, frontier_before, facts_before)
	_check(str(pokegear_candidate.get("checkpoint_after", "")) == "information_result", \
		"scenario 4 Pokegear must create an information checkpoint")
	_check(not bool(premature_safety.get("valid", true)), \
		"scenario 4 must not replace the exact Pokegear floor with premature discard-draw")

	var arven := {
		"id": "supporter:arven",
		"kind": "play_trainer",
		"card": _card("CSV1C_123"),
		"requires_interaction": true,
	}
	var after := _observation([arven, research], {
		"slot_id": "slot:active",
		"pokemon": _card("CSV10C_175"),
		"energy": [],
	}, [])
	after["observation_version"] = 2
	after["observation_hash"] = "hop-order-after"
	var facts_after := _facts(false, false, false, 4)
	var delta := MaterialDeltaScript.new().compare(before, after, facts_before, facts_after)
	var epoch_strategy = StrategyScript.new()
	epoch_strategy.configure_profile(_profile, _manifest)
	epoch_strategy.configure_verified_local_only_for_benchmark()
	var reopens: bool = epoch_strategy.call("_should_reopen_information_epoch", \
		"local_gate", {
			"owner": "local_gate",
			"success": true,
			"route_id": "route:information",
			"candidate_id": str(pokegear_candidate.get("candidate_id", "")),
		}, delta, frontier_before)
	_check(bool(delta.get("legal_actions_changed", false)) and reopens, \
		"scenario 4 the revealed supporter must reopen the local information epoch")

	var frontier_after := _frontier(after, {
		"supporter:arven": 330.0,
		"supporter:research": 80.0,
	}, facts_after, "supporter:arven")
	var arven_candidate := _candidate(frontier_after, "supporter:arven")
	var research_candidate := _candidate(frontier_after, "supporter:research")
	var research_safety := _route_safety(research_candidate, frontier_after, facts_after)
	_check(str(arven_candidate.get("route_id", "")) == "route:tutor" \
		and str(arven_candidate.get("checkpoint_after", "")) == "information_result", \
		"scenario 4 Arven must remain a tutor checkpoint after the Pokegear result")
	_check(not bool(research_safety.get("valid", true)) \
		and str(research_safety.get("reason", "")) == "model_route_below_switch_margin", \
		"scenario 4 must use the targeted Arven line before destructive Professor's Research")
	_rows.append(_row(
		"information_then_supporter_order",
		"抽牌/支援者顺序",
		"先用宝可装置3.0揭示支援者并重开信息纪元；看到阿驯后走道具+工具检索，不先用博士丢掉计划牌。",
		"item:pokegear -> supporter:arven",
		str(research_safety.get("reason", "")),
		reopens and not bool(research_safety.get("valid", true))
	))


func _scenario_5_public_two_prize_closeout() -> void:
	var judge := {
		"id": "supporter:judge",
		"kind": "play_trainer",
		"card": _card("CSV10C_206"),
		"requires_interaction": false,
	}
	var attack := {
		"id": "attack:zacian-closeout",
		"kind": "attack",
		"source": "slot:active",
		"source_card": _card("CSV10C_161"),
		"attack_index": 0,
		"projected_damage": 90,
		"projected_knockout": true,
	}
	var observation := _observation([judge, attack], {
		"slot_id": "slot:active",
		"pokemon": _card("CSV10C_161"),
		"energy": [{"type": "Basic Energy", "energy_type": "D"}],
	}, [{
		"slot_id": "slot:partner",
		"pokemon": _card("CSV10C_175"),
		"energy": [],
	}])
	observation["own"]["prizes_remaining"] = 2
	observation["opponent"]["active"] = {
		"slot_id": "slot:opponent-active",
		"pokemon": {"uid": "CSV6C_051"},
		"remaining_hp": 90,
		"prize_count": 2,
	}
	var facts := _facts(true, true, false, 5)
	facts["resources"]["prizes_remaining"] = 2
	var frontier := _frontier(observation, {
		"supporter:judge": 520.0,
		"attack:zacian-closeout": 20.0,
	}, facts, "supporter:judge")
	var selected := _candidate(frontier, "attack:zacian-closeout")
	var outcome: Dictionary = selected.get("outcome", {}) if selected.get("outcome", {}) is Dictionary else {}
	var strategy = StrategyScript.new()
	strategy.configure_profile(_profile, _manifest)
	var safety: Dictionary = strategy.call("_validate_model_route_safety", \
		str(selected.get("route_id", "")), frontier, facts, str(selected.get("candidate_id", "")))
	_check(bool(outcome.get("win_now", false)) and int(outcome.get("prizes_now", 0)) == 2, \
		"scenario 5 route search must recompute the public two-prize win")
	_check(bool(safety.get("valid", false)) and str(safety.get("reason", "")) == "deterministic_win_now", \
		"scenario 5 deterministic closeout must override any non-terminal Rule action regardless of score gap")
	var install := strategy.install_policy_response_for_test({
		"policy": {
			"root_node_id": "node:root",
			"nodes": [{
				"node_id": "node:root",
				"kind": "route",
				"route_ref": {
					"mode": "select_candidate",
					"route_id": str(selected.get("route_id", "")),
					"candidate_id": str(selected.get("candidate_id", "")),
				},
			}],
		},
	}, frontier, facts)
	_check(bool(install.get("valid", false)), \
		"scenario 5 exact closeout candidate must install through the production policy validator")
	_rows.append(_row(
		"public_two_prize_closeout",
		"关键奖卡",
		"对手战斗位公开为90HP双奖目标、己方剩2奖时，立即用苍响ex取胜，停止裁判等额外抽牌。",
		"attack:zacian-closeout",
		str(safety.get("reason", "")),
		bool(install.get("valid", false))
	))


func _frontier(
	observation: Dictionary,
	scores: Dictionary,
	facts: Dictionary,
	rule_action_id: String
) -> Array[Dictionary]:
	var route_search = RouteSearchScript.new()
	var pool: Array[Dictionary] = route_search.build_candidate_pool(
		observation, scores, _manifest, facts
	)
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


func _route_safety(selected: Dictionary, frontier: Array[Dictionary], facts: Dictionary) -> Dictionary:
	if selected.is_empty():
		return {"valid": false, "reason": "missing_selected_candidate"}
	var strategy = StrategyScript.new()
	strategy.configure_profile(_profile, _manifest)
	return strategy.call("_validate_model_route_safety", \
		str(selected.get("route_id", "")), frontier, facts, str(selected.get("candidate_id", "")))


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


func _observation(actions: Array, active: Dictionary, bench: Array) -> Dictionary:
	return {
		"observation_version": 1,
		"observation_hash": "scenario",
		"turn": {"deterministic_attack_window_open": true},
		"own": {
			"active": active,
			"bench": bench,
			"hand": [{"uid": "VISIBLE_OWN_HAND_CARD"}],
			"discard": [],
			"deck_count": 24,
			"prizes_remaining": 6,
		},
		"opponent": {
			"active": {"slot_id": "slot:opponent-active", "remaining_hp": 220, "prize_count": 2},
			"bench": [],
			"hand": [{"uid": "FORBIDDEN_SECRET_HAND_CARD"}],
			"deck_order": ["FORBIDDEN_SECRET_TOP_CARD"],
		},
		"stadium": {},
		"legal_actions": actions,
	}


func _facts(attack_ready: bool, ko_available: bool, energy_available: bool, hand_size: int) -> Dictionary:
	return {
		"attack": {"ready": attack_ready, "ko_available": ko_available, "max_damage": 90 if attack_ready else 0},
		"turn": {"energy_available": energy_available},
		"resources": {
			"deck_low": false,
			"hand_size": hand_size,
			"bench_slots_free": 3,
			"prizes_remaining": 6,
		},
		"board": {"bench_full": false, "has_tera": false},
		"information": {"material_action_available": true},
		"prize": {"current_swing": 0, "win_now": false},
		"route": {"current_valid": true},
	}


func _action_attach(action_id: String, target: String) -> Dictionary:
	var energy := {
		"uid": "CSVE1C_DAR",
		"name": "Darkness Energy",
		"type": "Basic Energy",
		"energy_type": "D",
		"energy_provides": "D",
	}
	return {"id": action_id, "kind": "attach_energy", "card": energy, "target": target}


func _action_bench(action_id: String, uid: String) -> Dictionary:
	return {"id": action_id, "kind": "play_basic_to_bench", "card": _card(uid)}


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
		}
	_check(false, "manifest card %s must exist" % uid)
	return {"uid": uid}


func _row(
	id: String,
	category: String,
	description: String,
	expected_choice: String,
	proof_reason: String,
	passed: bool
) -> Dictionary:
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
		"deck_id": DECK_ID,
		"strategy_id": str(_profile.get("strategy_id", "")),
		"profile_version": int(_profile.get("profile_version", 0)),
		"scenario_count": _rows.size(),
		"passed_count": _rows.filter(func(row: Dictionary) -> bool: return bool(row.get("passed", false))).size(),
		"all_passed": _failures.is_empty() and _rows.size() == 5,
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
