class_name V18CPGPolicyGraph
extends RefCounted

const GuardEvaluatorScript = preload("res://scripts/ai/v18_cpg/policy/V18CPGGuardEvaluator.gd")

var _policy: Dictionary = {}
var _node_by_id: Dictionary = {}
var _current_node_id: String = ""
var _executed_nodes: Array[String] = []
var _guard_evaluator = GuardEvaluatorScript.new()
var _origin: String = "local_gate"


func install(policy: Dictionary, origin: String) -> void:
	_policy = policy.duplicate(true)
	_node_by_id.clear()
	for raw_node: Variant in _policy.get("nodes", []):
		if raw_node is Dictionary:
			_node_by_id[str((raw_node as Dictionary).get("node_id", ""))] = raw_node
	_current_node_id = str(_policy.get("root_node_id", ""))
	_executed_nodes.clear()
	_origin = origin


func clear() -> void:
	_policy.clear()
	_node_by_id.clear()
	_current_node_id = ""
	_executed_nodes.clear()
	_origin = "local_gate"


func is_active() -> bool:
	return _current_node_id != "" and _node_by_id.has(_current_node_id)


func current_route_id() -> String:
	return str(current_route_ref().get("route_id", ""))


func current_candidate_id() -> String:
	var route_ref := current_route_ref()
	return str(route_ref.get("candidate_id", route_ref.get("first_candidate_id", "")))


func current_route_ref() -> Dictionary:
	if not is_active():
		return {}
	var node: Dictionary = _node_by_id[_current_node_id]
	if str(node.get("kind", "")) != "route":
		return {}
	var route_ref: Variant = node.get("route_ref", {})
	return (route_ref as Dictionary).duplicate(true) if route_ref is Dictionary else {}


func current_node_id() -> String:
	return _current_node_id


func origin() -> String:
	return _origin


func current_route_has_declared_successor() -> bool:
	if not is_active():
		return false
	var node: Dictionary = _node_by_id[_current_node_id]
	if str(node.get("kind", "")) != "route":
		return false
	var next_node_id := str(node.get("next_node_id", ""))
	return next_node_id != "" and _node_by_id.has(next_node_id)


func advance_after_observation(
	facts: Dictionary,
	available_route_ids: Array[String],
	available_candidate_ids: Array[String] = []
) -> Dictionary:
	if not is_active():
		return {"status": "replan", "branch_hit": false}
	var node: Dictionary = _node_by_id[_current_node_id]
	if str(node.get("kind", "")) == "route":
		if not _executed_nodes.has(_current_node_id):
			_executed_nodes.append(_current_node_id)
		var next_node := str(node.get("next_node_id", ""))
		if next_node == "":
			return {"status": "replan", "branch_hit": false}
		_current_node_id = next_node
	return _resolve_non_route_nodes(facts, available_route_ids, available_candidate_ids)


func _resolve_non_route_nodes(
	facts: Dictionary,
	available_route_ids: Array[String],
	available_candidate_ids: Array[String]
) -> Dictionary:
	var hop_count := 0
	while is_active() and hop_count < 12:
		hop_count += 1
		var node: Dictionary = _node_by_id[_current_node_id]
		var kind := str(node.get("kind", ""))
		if kind == "route":
			var route_ref := current_route_ref()
			var route_id := str(route_ref.get("route_id", ""))
			var mode := str(route_ref.get("mode", ""))
			var candidate_id := str(route_ref.get("candidate_id", route_ref.get("first_candidate_id", "")))
			if mode in ["select_candidate", "propose_typed_route"] and candidate_id in available_candidate_ids:
				return {
					"status": "route",
					"route_id": route_id,
					"candidate_id": candidate_id,
					"route_ref": route_ref,
					"branch_hit": true,
				}
			if mode in ["follow_route", "select_existing"] and route_id in available_route_ids:
				return {"status": "route", "route_id": route_id, "route_ref": route_ref, "branch_hit": true}
			return {"status": "replan", "branch_hit": false, "reason": "branch_route_unavailable"}
		if kind == "terminal":
			return {"status": "terminal", "branch_hit": true}
		if kind != "checkpoint":
			return {"status": "replan", "branch_hit": false, "reason": "invalid_node_kind"}
		var matched := false
		for raw_branch: Variant in node.get("branches", []):
			if not (raw_branch is Dictionary):
				continue
			var branch: Dictionary = raw_branch
			if _guard_evaluator.evaluate_all(branch.get("when_all", []), facts):
				_current_node_id = str(branch.get("next_node_id", ""))
				matched = true
				break
		if matched:
			continue
		var otherwise := str(node.get("otherwise", "replan"))
		if _node_by_id.has(otherwise):
			_current_node_id = otherwise
			continue
		return {"status": otherwise, "branch_hit": otherwise != "replan"}
	return {"status": "replan", "branch_hit": false, "reason": "graph_hop_limit"}


func snapshot() -> Dictionary:
	return {
		"policy": _policy.duplicate(true),
		"current_node_id": _current_node_id,
		"executed_nodes": _executed_nodes.duplicate(),
		"origin": _origin,
	}


func interaction_policy_for(step: Dictionary) -> Dictionary:
	if _policy.is_empty():
		return {}
	var refs: Variant = _policy.get("interaction_policy_refs", {})
	if not (refs is Dictionary):
		return {}
	var step_id := str(step.get("id", ""))
	var ui_mode := str(step.get("ui_mode", ""))
	var policy_id := ""
	for key: String in [step_id, "interaction:%s" % step_id, "ui:%s" % ui_mode, "default"]:
		if key != "" and (refs as Dictionary).has(key):
			policy_id = str((refs as Dictionary).get(key, ""))
			break
	if policy_id == "":
		return {}
	for raw_policy: Variant in _policy.get("interaction_policies", []):
		if raw_policy is Dictionary and str((raw_policy as Dictionary).get("policy_id", "")) == policy_id:
			return (raw_policy as Dictionary).duplicate(true)
	return {}


static func build_local(frontier: Array[Dictionary]) -> Dictionary:
	if frontier.is_empty():
		return {}
	var root_route := str(frontier[0].get("route_id", ""))
	var root_candidate := str(frontier[0].get("candidate_id", ""))
	var root_ref := {
		"mode": "select_candidate",
		"route_id": root_route,
		"candidate_id": root_candidate,
	} if root_candidate != "" else {
		"mode": "select_existing",
		"route_id": root_route,
	}
	var nodes: Array[Dictionary] = [{
		"node_id": "node:root",
		"kind": "route",
		"route_ref": root_ref,
		"next_node_id": "node:checkpoint",
	}]
	var branches: Array[Dictionary] = []
	var preferred: Array[Dictionary] = [
		{"route": "route:attack_ko", "fact": "attack.ko_available", "value": true},
		{"route": "route:noctowl_search", "fact": "fan_call.available", "value": true},
		{"route": "route:attack_pressure", "fact": "attack.ready", "value": true},
	]
	for entry: Dictionary in preferred:
		var route_id := str(entry.get("route", ""))
		var has_route := false
		for route: Dictionary in frontier:
			if str(route.get("route_id", "")) == route_id:
				has_route = true
				break
		if not has_route:
			continue
		var node_id := "node:%s" % route_id.trim_prefix("route:")
		branches.append({
			"when_all": [{"fact": str(entry.get("fact", "")), "op": "==", "value": entry.get("value")}],
			"next_node_id": node_id,
		})
		nodes.append({
			"node_id": node_id,
			"kind": "route",
			"route_ref": {"mode": "follow_route", "route_id": route_id},
		})
	nodes.append({
		"node_id": "node:checkpoint",
		"kind": "checkpoint",
		"branches": branches,
		"otherwise": "local_best",
	})
	return {
		"root_node_id": "node:root",
		"nodes": nodes,
		"reservations": [],
		# Local policies deliberately own no typed interactions.  Referencing a
		# policy that is not present makes the audit imply model-like ownership
		# even though all local interaction choices remain on the Rule floor.
		"interaction_policy_refs": {},
		"interaction_policies": [],
		"replan_if": ["no_branch_matches", "current_route_invalid", "new_prize_tier_available"],
	}
