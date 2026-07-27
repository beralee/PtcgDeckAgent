extends SceneTree

const RouteValueGraphScript = preload(
	"res://scripts/ai/v18_cpg/planning/route_value/V18CPGRouteValueGraph.gd"
)
const ProfileCatalogScript = preload(
	"res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd"
)
const StrategyScript = preload(
	"res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd"
)
const DecisionClientScript = preload(
	"res://scripts/ai/v18_cpg/network/V18CPGDecisionClient.gd"
)

var _failures: Array[String] = []


func _initialize() -> void:
	var samples: Array[float] = []
	var graph = RouteValueGraphScript.new()
	var profile := ProfileCatalogScript.get_profile_for_deck(800018509)
	var observation := _observation()
	var candidates := _candidates()
	var last_annotated: Array[Dictionary] = []
	for iteration: int in 240:
		var started := Time.get_ticks_usec()
		var annotated: Array[Dictionary] = graph.annotate_candidate_pool(
			candidates,
			observation,
			_facts(),
			_ledger(),
			profile
		)
		last_annotated = annotated
		var elapsed := float(Time.get_ticks_usec() - started) / 1000.0
		if iteration >= 20:
			samples.append(elapsed)
		if annotated.size() != candidates.size():
			_failures.append("annotation must preserve the complete candidate pool")
			break
	samples.sort()
	var p95 := samples[clampi(
		int(ceil(float(samples.size()) * 0.95)) - 1,
		0,
		samples.size() - 1
	)] if not samples.is_empty() else INF
	if p95 > 10.0:
		_failures.append("Route Value Graph local p95 %.3fms exceeds 10ms" % p95)
	var strategy = StrategyScript.new()
	var model_candidates := graph.prune_model_candidates(
		last_annotated,
		10
	)
	var compact_v3: Array = strategy.call(
		"_compact_frontier_for_model",
		model_candidates
	)
	var legacy_candidates := model_candidates.duplicate(true)
	for candidate: Dictionary in legacy_candidates:
		candidate.erase("route_value_graph_v3")
	var compact_v2: Array = strategy.call(
		"_compact_frontier_for_model",
		legacy_candidates
	)
	var base_envelope := {
		"limits": {"max_policy_nodes": 8},
		"lifecycle": {"turn_id": 7, "request_id": "latency"},
		"profile": {
			"deck_id": 800018509,
			"modules": profile.get("modules", []),
			"protected_roles": profile.get("protected_roles", []),
			"strategic_priorities": profile.get("strategic_priorities", []),
			"route_preferences": profile.get("route_preferences", {}),
			"safety": profile.get("safety", {}),
		},
		"observation": observation,
		"facts": _facts(),
		"resource_ledger": _ledger(),
		"prize_graph": {"routes": []},
		"threat_response": {},
		"turn_completion_contract": {},
		"capability_context": {},
		"allowed_follow_route_ids": [],
	}
	var v3_envelope := base_envelope.duplicate(true)
	v3_envelope["frontier"] = compact_v3
	var v2_envelope := base_envelope.duplicate(true)
	v2_envelope["frontier"] = compact_v2
	var client = DecisionClientScript.new()
	var v3_payload: Dictionary = client.call(
		"_build_payload",
		v3_envelope,
		512,
		false
	)
	var v2_payload: Dictionary = client.call(
		"_build_payload",
		v2_envelope,
		512,
		false
	)
	var v3_bytes := JSON.stringify(v3_payload).to_utf8_buffer().size()
	var v2_bytes := maxi(1, JSON.stringify(v2_payload).to_utf8_buffer().size())
	var payload_growth := 100.0 * float(v3_bytes - v2_bytes) / float(v2_bytes)
	if payload_growth > 15.0:
		_failures.append(
			"compact frontier growth %.2f%% exceeds 15%%" % payload_growth
		)
	if _failures.is_empty():
		print(
			"V18CPG route-value latency: PASS (p95 %.3fms, frontier +%.2f%%)"
				% [p95, payload_growth]
		)
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _observation() -> Dictionary:
	return {
		"schema_version": 1,
		"observation_hash": "latency",
		"turn": {
			"number": 7,
			"current_player": 0,
			"viewer": 0,
			"phase": 2,
			"quotas": {
				"energy_available": true,
				"supporter_available": true,
				"stadium_available": true,
				"retreat_available": true,
			},
		},
		"own": {
			"hand": [],
			"hand_count": 7,
			"deck_count": 25,
			"prizes_remaining": 4,
			"discard": [],
			"lost_zone": [],
			"active": _slot("own:a", "CSV7C_154", 240, 2),
			"bench": [
				_slot("own:b1", "CSV8C_028", 210, 1),
				_slot("own:b2", "CSV9C_154", 70, 0),
				_slot("own:b3", "CSV8C_028", 210, 1),
			],
		},
		"opponent": {
			"hand_count": 5,
			"deck_count": 25,
			"prizes_remaining": 4,
			"discard": [],
			"lost_zone": [],
			"active": _slot("opp:a", "TARGET", 230, 2),
			"bench": [
				_slot("opp:b1", "ENGINE", 280, 2),
				_slot("opp:b2", "BRIDGE", 130, 1),
			],
		},
		"stadium": {},
		"legal_actions": [],
		"interaction": {},
	}


func _slot(slot_id: String, uid: String, hp: int, energy_count: int) -> Dictionary:
	var energy: Array[Dictionary] = []
	for index: int in energy_count:
		energy.append({
			"instance_id": slot_id.hash() + index,
			"uid": "CSVE1C_GRA",
			"type": "Basic Energy",
			"energy_provides": "G",
		})
	return {
		"slot_id": slot_id,
		"pokemon": {"uid": uid, "instance_id": slot_id.hash()},
		"energy": energy,
		"energy_count": energy_count,
		"remaining_hp": hp,
		"max_hp": hp,
		"prize_count": 2,
		"retreat_cost": 1,
		"ability_used": false,
		"tera": uid == "CSV8C_028",
	}


func _candidates() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var routes := [
		"route:attack_ko", "route:attack_pressure", "route:stadium",
		"route:evolve", "route:noctowl_search", "route:develop",
		"route:information", "route:accelerate", "route:energy_commit",
		"route:pivot", "route:gust", "route:end_turn",
	]
	for index: int in routes.size():
		var route_id: String = routes[index]
		var kind := _kind_for_route(route_id)
		var candidate := {
			"candidate_id": "candidate:%d" % index,
			"route_id": route_id,
			"action_kind": kind,
			"safe_prefix_action_id": "action:%d" % index,
			"action_ref": {
				"id": "action:%d" % index,
				"kind": kind,
				"source": "own:a",
				"target": "own:a",
				"card": {
					"instance_id": 500 + index,
					"uid": "CSV9C_207" if route_id == "route:stadium" else "CARD:%d" % index,
					"type": "Stadium" if route_id == "route:stadium" else "Trainer",
				},
			},
			"checkpoint_after": (
				"information_result"
				if route_id in ["route:information", "route:noctowl_search"]
				else "terminal"
				if route_id in ["route:attack_ko", "route:attack_pressure", "route:end_turn"]
				else "action_resolved"
			),
			"base_score": 1000.0 - float(index),
			"local_score": 1000.0 - float(index),
			"rule_order": index,
			"outcome": {
				"win_now": false,
				"prizes_now": 2 if route_id == "route:attack_ko" else 0,
				"continuity_debt_reduction": 1 if route_id == "route:develop" else 0,
				"uncertainty": 0.5 if route_id == "route:information" else 0.1,
			},
		}
		if index == 0:
			candidate["engine_rule_floor_exact"] = true
		if route_id == "route:stadium":
			candidate["conditional_suffix"] = {
				"guarded_followups": [
					{"route_id": "route:evolve"},
					{"route_id": "route:noctowl_search"},
					{"route_id": "route:energy_commit"},
				],
			}
		result.append(candidate)
	return result


func _kind_for_route(route_id: String) -> String:
	match route_id:
		"route:attack_ko", "route:attack_pressure":
			return "attack"
		"route:stadium":
			return "play_stadium"
		"route:evolve":
			return "evolve"
		"route:noctowl_search", "route:information":
			return "use_ability"
		"route:develop":
			return "play_basic_to_bench"
		"route:energy_commit":
			return "attach_energy"
		"route:pivot":
			return "retreat"
		"route:end_turn":
			return "end_turn"
	return "play_trainer"


func _facts() -> Dictionary:
	return {
		"attack": {
			"ready": true,
			"ko_available": true,
			"max_damage": 280,
			"energy_deficit": 0,
		},
		"prize": {"win_now": false, "current_swing": 2},
		"resources": {"prizes_remaining": 4, "bench_slots_free": 2},
		"continuity": {
			"banked_damage_units": 3,
			"debt_count": 2,
			"floor_met": false,
		},
	}


func _ledger() -> Dictionary:
	return {
		"schema_version": 3,
		"exclusive_quota": {
			"energy_attachment": true,
			"supporter": true,
			"retreat": true,
			"stadium": true,
		},
		"reserved_by_window": {},
	}
