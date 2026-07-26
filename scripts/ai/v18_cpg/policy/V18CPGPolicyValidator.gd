class_name V18CPGPolicyValidator
extends RefCounted

const ContractsScript = preload("res://scripts/ai/v18_cpg/schema/V18CPGContracts.gd")

const RESPONSE_KEYS: Array[String] = [
	"agenda_patch", "policy",
	# Transport metadata is attached after the model JSON has been parsed.  It is
	# not part of the semantic response, but must survive both HTTP and the
	# RNG-isolated Python fallback without making a valid policy fail closed.
	"transport", "http_code", "request_result",
	"rng_isolated_transport", "rng_isolated_request_sequence",
]
const AGENDA_KEYS: Array[String] = [
	"victory_mode", "risk_posture", "attacker_chain", "protected_resources",
]
const POLICY_KEYS: Array[String] = [
	"root_node_id", "nodes", "reservations", "interaction_policy_refs",
	"interaction_policies", "replan_if",
]
const ROUTE_NODE_KEYS: Array[String] = ["node_id", "kind", "route_ref", "next_node_id"]
const CHECKPOINT_NODE_KEYS: Array[String] = ["node_id", "kind", "branches", "otherwise"]
const TERMINAL_NODE_KEYS: Array[String] = ["node_id", "kind"]
const BRANCH_KEYS: Array[String] = ["when_all", "next_node_id"]
const GUARD_KEYS: Array[String] = ["fact", "op", "value"]
const INFORMATION_CHECKPOINT_ROUTE_IDS: Array[String] = [
	"route:information",
	"route:noctowl_search",
	"route:opening_search",
	"route:tutor",
]
const SELECT_CANDIDATE_REF_KEYS: Array[String] = ["mode", "route_id", "candidate_id"]
const FOLLOW_ROUTE_REF_KEYS: Array[String] = ["mode", "route_id"]
const TYPED_ROUTE_REF_KEYS: Array[String] = ["mode", "route_id", "first_candidate_id", "macro_actions"]
const INTERACTION_POLICY_KEYS: Array[String] = [
	"policy_id", "rank_by", "desired_roles", "must_preserve", "target_position",
	"energy_symbols", "prize_goal", "min_select", "max_select",
	"allow_explicit_empty", "tie_breakers",
]
const INTERACTION_POLICY_REQUIRED_KEYS: Array[String] = [
	"policy_id", "rank_by", "desired_roles", "must_preserve", "energy_symbols",
	"min_select", "max_select", "allow_explicit_empty", "tie_breakers",
]
const VICTORY_MODES: Array[String] = ["prize_race", "spread_closeout", "resource_lock", "deckout", "rebuild"]
const RISK_POSTURES: Array[String] = ["safe", "balanced", "forced"]
const DESIRED_ROLES: Array[String] = [
	"attacker", "alternate_attacker", "finisher", "next_attacker", "draw_engine",
	"search_engine", "recovery", "evolution_piece", "energy_source", "energy_access",
	"typed_energy_access", "energy_accelerator", "supporter_acceleration", "energy_mover",
	"pivot", "gust", "hand_disruption", "lock", "stadium", "pokemon_search",
	"bench_protection", "resource_recycler",
]
const TARGET_POSITIONS: Array[String] = ["any", "own_active", "own_bench", "opponent_active", "opponent_bench"]
const ENERGY_SYMBOLS: Array[String] = ["G", "W", "L", "P", "F", "D", "M", "C"]
const PRIZE_GOALS: Array[String] = ["none", "shortest_safe_path", "highest_prize", "engine_ko", "spread_closeout"]
const TIE_BREAKERS: Array[String] = ["stable_id", "lower_resource_cost", "higher_survival", "higher_prize"]
const REPLAN_REASONS: Array[String] = [
	"no_branch_matches", "current_route_invalid", "new_prize_tier_available",
	"protected_resource_changed", "typed_route_step_unavailable",
]


func validate_response(
	response: Dictionary,
	allowed_route_ids: Array[String],
	max_nodes: int = 8,
	allowed_candidate_ids: Array[String] = [],
	require_exact_root: bool = false
) -> Dictionary:
	if str(response.get("status", "")) == "error":
		return _invalid(_model_response_error_reason(response))
	if not _has_only_keys(response, RESPONSE_KEYS):
		return _invalid("response_additional_property")
	var agenda_result := _validate_agenda_patch(response.get("agenda_patch", {}), response.has("agenda_patch"))
	if not bool(agenda_result.get("valid", false)):
		return agenda_result
	var policy_variant: Variant = response.get("policy", {})
	if not (policy_variant is Dictionary):
		return _invalid("missing_policy")
	var policy: Dictionary = (policy_variant as Dictionary).duplicate(true)
	if not _has_only_keys(policy, POLICY_KEYS):
		return _invalid("policy_additional_property")
	if not _has_required_keys(policy, ["root_node_id", "nodes"]):
		return _invalid("missing_policy_field")
	# Compact wire responses may omit fields whose only semantic value is an
	# empty/default collection.  Canonicalize them before every validation and
	# execution path so compact and legacy-full responses install identically.
	if not policy.has("reservations"):
		policy["reservations"] = []
	if not policy.has("interaction_policy_refs"):
		policy["interaction_policy_refs"] = {}
	if not policy.has("interaction_policies"):
		policy["interaction_policies"] = []
	if not policy.has("replan_if"):
		policy["replan_if"] = []
	var collection_result := _validate_policy_collections(policy)
	if not bool(collection_result.get("valid", false)):
		return collection_result
	var nodes_variant: Variant = policy.get("nodes", [])
	if not (nodes_variant is Array):
		return _invalid("nodes_not_array")
	var nodes: Array = nodes_variant
	var node_limit := mini(maxi(max_nodes, 1), ContractsScript.HARD_MAX_POLICY_NODES)
	if nodes.is_empty() or nodes.size() > node_limit:
		return _invalid("node_count")
	var node_by_id: Dictionary = {}
	for raw_node: Variant in nodes:
		if not (raw_node is Dictionary):
			return _invalid("node_not_object")
		var node: Dictionary = raw_node
		if not node.has("node_id") or not (node.get("node_id") is String):
			return _invalid("node_id")
		var node_id := str(node.get("node_id", ""))
		if node_id == "" or node_by_id.has(node_id):
			return _invalid("node_id")
		node_by_id[node_id] = node
	if not (policy.get("root_node_id") is String):
		return _invalid("missing_root")
	var root := str(policy.get("root_node_id", ""))
	if root == "" or not node_by_id.has(root):
		return _invalid("missing_root")
	if require_exact_root and str((node_by_id.get(root, {}) as Dictionary).get("kind", "")) != "route":
		return _invalid("root_requires_exact_candidate")
	for node_id: String in node_by_id:
		var node: Dictionary = node_by_id[node_id]
		if not node.has("kind") or not (node.get("kind") is String):
			return _invalid("unknown_node_kind")
		var kind := str(node.get("kind", ""))
		if kind == "route":
			var raw_route_ref: Variant = node.get("route_ref", {})
			if node_id != root and raw_route_ref is Dictionary \
					and str((raw_route_ref as Dictionary).get("mode", "")) == "propose_typed_route":
				# A typed macro installs one execution cursor from the exact root.
				# A second typed macro behind a checkpoint cannot be installed and
				# executed atomically by PolicyGraph, so reject the graph as declared.
				return _invalid("typed_route_non_root")
			var route_result := _validate_route_node(
				node,
				allowed_route_ids,
				allowed_candidate_ids,
				node_by_id,
				node_id == root and require_exact_root
			)
			if not bool(route_result.get("valid", false)):
				return route_result
		elif kind == "checkpoint":
			var checkpoint_result := _validate_checkpoint(node, node_by_id)
			if not bool(checkpoint_result.get("valid", false)):
				return checkpoint_result
		elif kind == "terminal":
			if not _has_only_keys(node, TERMINAL_NODE_KEYS) or not _has_required_keys(node, TERMINAL_NODE_KEYS):
				return _invalid("terminal_node_shape")
		else:
			return _invalid("unknown_node_kind")
	var cycle_result := _validate_acyclic(node_by_id)
	if not bool(cycle_result.get("valid", false)):
		return cycle_result
	# Unreachable nodes have no executable semantics.  Validate their complete
	# shape above, then remove them deterministically instead of rejecting an
	# otherwise safe root or inventing edges that the model did not declare.
	var reachability_result := _canonicalize_reachable_policy(root, node_by_id, policy)
	policy = reachability_result.get("policy", policy)
	var canonicalized_unreachable_nodes := int(
		reachability_result.get("canonicalized_unreachable_nodes", 0)
	)
	var interaction_result := _validate_interaction_policies(policy)
	if not bool(interaction_result.get("valid", false)):
		return interaction_result
	return {
		"valid": true,
		"reason": "",
		"policy": policy.duplicate(true),
		"agenda_patch": agenda_result.get("agenda_patch", {}).duplicate(true),
		"canonicalized_unreachable_nodes": canonicalized_unreachable_nodes,
	}


func bind_root_to_frontier(policy: Dictionary, frontier: Array[Dictionary]) -> Dictionary:
	# Bind every exact-candidate node, not only the root.  Otherwise a later graph
	# branch can present candidate B with route A, pass route-based safety checks
	# as A, and still execute B because candidate_id is the engine authority.
	var normalized := policy.duplicate(true)
	var root_id := str(normalized.get("root_node_id", ""))
	var nodes: Variant = normalized.get("nodes", [])
	if root_id == "" or not (nodes is Array):
		return _invalid("missing_root")
	var root_ref: Dictionary = {}
	var root_candidate: Dictionary = {}
	var root_original_route_id := ""
	for index: int in (nodes as Array).size():
		var raw_node: Variant = (nodes as Array)[index]
		if not (raw_node is Dictionary):
			continue
		var node: Dictionary = raw_node as Dictionary
		if str(node.get("kind", "")) != "route":
			continue
		var raw_ref: Variant = node.get("route_ref", {})
		if not (raw_ref is Dictionary):
			return _invalid("missing_route_ref")
		var route_ref: Dictionary = (raw_ref as Dictionary).duplicate(true)
		var mode := str(route_ref.get("mode", ""))
		var is_root := str(node.get("node_id", "")) == root_id
		if mode not in ["select_candidate", "propose_typed_route"]:
			if is_root:
				return _invalid("root_requires_exact_candidate")
			continue
		var candidate_id := str(route_ref.get(
			"candidate_id" if mode == "select_candidate" else "first_candidate_id",
			""
		))
		var candidate := _frontier_candidate(frontier, candidate_id)
		if candidate.is_empty():
			return _invalid("unknown_candidate")
		var canonical_route_id := str(candidate.get("route_id", ""))
		if canonical_route_id == "":
			return _invalid("candidate_route_missing")
		if mode == "propose_typed_route":
			var macro_actions: Variant = route_ref.get("macro_actions", [])
			if not (macro_actions is Array) or (macro_actions as Array).is_empty() \
					or str((macro_actions as Array)[0]) != canonical_route_id:
				return _invalid("typed_route_first_step_mismatch")
		var original_route_id := str(route_ref.get("route_id", ""))
		route_ref["route_id"] = canonical_route_id
		node["route_ref"] = route_ref
		(nodes as Array)[index] = node
		if is_root:
			root_ref = route_ref.duplicate(true)
			root_candidate = candidate.duplicate(true)
			root_original_route_id = original_route_id
	if root_ref.is_empty():
		return _invalid("root_requires_exact_candidate")
	normalized["nodes"] = nodes
	return {
		"valid": true,
		"reason": "",
		"policy": normalized,
		"root_ref": root_ref,
		"candidate": root_candidate,
		"canonicalized_route": root_original_route_id != str(root_ref.get("route_id", "")),
	}


func _frontier_candidate(frontier: Array[Dictionary], candidate_id: String) -> Dictionary:
	for candidate: Dictionary in frontier:
		if str(candidate.get("candidate_id", "")) == candidate_id:
			return candidate
	return {}


func _validate_agenda_patch(value: Variant, present: bool) -> Dictionary:
	if not present:
		return {"valid": true, "agenda_patch": {}}
	if not (value is Dictionary):
		return _invalid("agenda_patch_not_object")
	var patch: Dictionary = value
	if not _has_only_keys(patch, AGENDA_KEYS):
		return _invalid("agenda_additional_property")
	if patch.has("victory_mode") and (not (patch.get("victory_mode") is String) or str(patch.get("victory_mode")) not in VICTORY_MODES):
		return _invalid("agenda_victory_mode")
	if patch.has("risk_posture") and (not (patch.get("risk_posture") is String) or str(patch.get("risk_posture")) not in RISK_POSTURES):
		return _invalid("agenda_risk_posture")
	if patch.has("attacker_chain") and not _valid_token_array(patch.get("attacker_chain"), 3, true):
		return _invalid("agenda_attacker_chain")
	if patch.has("protected_resources") and not _valid_token_array(patch.get("protected_resources"), 8, true):
		return _invalid("agenda_protected_resources")
	return {"valid": true, "agenda_patch": patch.duplicate(true)}


func _validate_policy_collections(policy: Dictionary) -> Dictionary:
	var reservations: Variant = policy.get("reservations", [])
	if not (reservations is Array):
		return _invalid("reservations_not_array")
	if (reservations as Array).size() > 6:
		return _invalid("reservations_count")
	for reservation: Variant in reservations as Array:
		if not (reservation is Dictionary):
			return _invalid("reservation_not_object")
	var refs: Variant = policy.get("interaction_policy_refs", {})
	if not (refs is Dictionary):
		return _invalid("interaction_policy_refs_not_object")
	for ref_value: Variant in (refs as Dictionary).values():
		if not (ref_value is String):
			return _invalid("interaction_policy_ref_not_string")
	var definitions: Variant = policy.get("interaction_policies", [])
	if not (definitions is Array):
		return _invalid("interaction_policies_not_array")
	if (definitions as Array).size() > 6:
		return _invalid("interaction_policies_count")
	var replan_if: Variant = policy.get("replan_if", [])
	if not _valid_string_array(replan_if, 5, REPLAN_REASONS):
		return _invalid("replan_if")
	return {"valid": true}


func _validate_route_node(
	node: Dictionary,
	allowed_route_ids: Array[String],
	allowed_candidate_ids: Array[String],
	node_by_id: Dictionary,
	require_exact: bool
) -> Dictionary:
	if not _has_only_keys(node, ROUTE_NODE_KEYS) or not _has_required_keys(node, ["node_id", "kind", "route_ref"]):
		return _invalid("route_node_shape")
	var route_ref: Variant = node.get("route_ref", {})
	if not (route_ref is Dictionary):
		return _invalid("missing_route_ref")
	var ref_result := _validate_route_ref(route_ref as Dictionary, allowed_route_ids, allowed_candidate_ids, require_exact)
	if not bool(ref_result.get("valid", false)):
		return ref_result
	if ref_result.has("route_ref"):
		node["route_ref"] = ref_result.get("route_ref", {})
	if node.has("next_node_id"):
		if not (node.get("next_node_id") is String) or str(node.get("next_node_id", "")) == "":
			return _invalid("missing_route_next")
		if not node_by_id.has(str(node.get("next_node_id", ""))):
			return _invalid("missing_route_next")
	return {"valid": true}


func _validate_route_ref(
	route_ref: Dictionary,
	allowed_route_ids: Array[String],
	allowed_candidate_ids: Array[String],
	require_exact: bool
) -> Dictionary:
	if not route_ref.has("mode") or not (route_ref.get("mode") is String):
		return _invalid("route_mode")
	var mode := str(route_ref.get("mode", ""))
	if mode == "select_candidate":
		if not _has_only_keys(route_ref, SELECT_CANDIDATE_REF_KEYS) \
				or not _has_required_keys(route_ref, SELECT_CANDIDATE_REF_KEYS):
			return _invalid("candidate_ref_shape")
		if not _is_prefixed_string(route_ref.get("candidate_id"), "candidate:") \
				or str(route_ref.get("candidate_id", "")) not in allowed_candidate_ids:
			return _invalid("unknown_candidate")
		if not _is_prefixed_string(route_ref.get("route_id"), "route:") \
				or str(route_ref.get("route_id", "")) not in allowed_route_ids:
			return _invalid("unknown_route")
	elif mode == "follow_route":
		if require_exact:
			return _invalid("root_requires_exact_candidate")
		if not _has_only_keys(route_ref, FOLLOW_ROUTE_REF_KEYS) \
				or not _has_required_keys(route_ref, FOLLOW_ROUTE_REF_KEYS):
			return _invalid("follow_ref_shape")
		if not _is_prefixed_string(route_ref.get("route_id"), "route:") \
				or str(route_ref.get("route_id", "")) not in allowed_route_ids:
			return _invalid("unknown_route")
	elif mode == "select_existing":
		# Read-only compatibility for pre-v2 fixtures. The compact model prompt
		# never emits this mode, and production roots require an exact candidate.
		if require_exact:
			return _invalid("root_requires_exact_candidate")
		if not _has_only_keys(route_ref, FOLLOW_ROUTE_REF_KEYS) \
				or not _has_required_keys(route_ref, FOLLOW_ROUTE_REF_KEYS):
			return _invalid("existing_ref_shape")
		if not _is_prefixed_string(route_ref.get("route_id"), "route:") \
				or str(route_ref.get("route_id", "")) not in allowed_route_ids:
			return _invalid("unknown_route")
	elif mode == "propose_typed_route":
		if not _has_only_keys(route_ref, TYPED_ROUTE_REF_KEYS) \
				or not _has_required_keys(route_ref, TYPED_ROUTE_REF_KEYS):
			return _invalid("typed_route_ref_shape")
		if not _is_prefixed_string(route_ref.get("first_candidate_id"), "candidate:") \
				or str(route_ref.get("first_candidate_id", "")) not in allowed_candidate_ids:
			return _invalid("unknown_candidate")
		if not _is_prefixed_string(route_ref.get("route_id"), "route:"):
			return _invalid("unknown_route")
		var macro_actions: Variant = route_ref.get("macro_actions", [])
		if not (macro_actions is Array) or (macro_actions as Array).size() < 2 or (macro_actions as Array).size() > 4:
			return _invalid("typed_route_macro_count")
		for macro_index: int in (macro_actions as Array).size():
			var raw_macro: Variant = (macro_actions as Array)[macro_index]
			if not _is_prefixed_string(raw_macro, "route:") or str(raw_macro) not in allowed_route_ids:
				return _invalid("unknown_macro_action")
			if macro_index < (macro_actions as Array).size() - 1 \
					and str(raw_macro) in INFORMATION_CHECKPOINT_ROUTE_IDS:
				# The observation after search/draw is not predictable. A typed cursor
				# may end at that boundary, but only a graph checkpoint may decide what
				# follows from the newly visible cards and legal actions.
				return _invalid("typed_route_crosses_information_checkpoint")
		# route_id labels the executable first macro, not a free-form chain name.
		var normalized_ref: Dictionary = route_ref.duplicate(true)
		normalized_ref["route_id"] = str((macro_actions as Array)[0])
		return {"valid": true, "route_ref": normalized_ref}
	else:
		return _invalid("route_mode")
	return {"valid": true, "route_ref": route_ref.duplicate(true)}


func _validate_interaction_policies(policy: Dictionary) -> Dictionary:
	var definitions: Array = policy.get("interaction_policies", [])
	var policy_ids: Dictionary = {}
	for raw_definition: Variant in definitions:
		if not (raw_definition is Dictionary):
			return _invalid("interaction_policy_not_object")
		var definition: Dictionary = raw_definition
		if not _has_only_keys(definition, INTERACTION_POLICY_KEYS):
			return _invalid("interaction_policy_additional_property")
		if not _has_required_keys(definition, INTERACTION_POLICY_REQUIRED_KEYS):
			return _invalid("interaction_policy_missing_field")
		if not (definition.get("policy_id") is String):
			return _invalid("interaction_policy_id")
		var policy_id := str(definition.get("policy_id", ""))
		if policy_id == "" or policy_ids.has(policy_id):
			return _invalid("interaction_policy_id")
		policy_ids[policy_id] = true
		if not _valid_string_array(definition.get("rank_by"), 5, ContractsScript.INTERACTION_RANK_KEYS):
			return _invalid("interaction_rank_key")
		if not _valid_string_array(definition.get("desired_roles"), 6, DESIRED_ROLES):
			return _invalid("interaction_desired_roles")
		if not _valid_token_array(definition.get("must_preserve"), 8, false):
			return _invalid("interaction_must_preserve")
		if definition.has("target_position") \
				and (not (definition.get("target_position") is String) or str(definition.get("target_position")) not in TARGET_POSITIONS):
			return _invalid("interaction_target_position")
		if not _valid_string_array(definition.get("energy_symbols"), 8, ENERGY_SYMBOLS):
			return _invalid("interaction_energy_symbols")
		if definition.has("prize_goal") \
				and (not (definition.get("prize_goal") is String) or str(definition.get("prize_goal")) not in PRIZE_GOALS):
			return _invalid("interaction_prize_goal")
		if not (definition.get("min_select") is int) or not (definition.get("max_select") is int):
			return _invalid("interaction_select_bounds")
		var min_select := int(definition.get("min_select", 0))
		var max_select := int(definition.get("max_select", 0))
		if min_select < 0 or max_select < 0 or min_select > 8 or max_select > 8 or min_select > max_select:
			return _invalid("interaction_select_bounds")
		if not (definition.get("allow_explicit_empty") is bool):
			return _invalid("interaction_allow_explicit_empty")
		if not _valid_string_array(definition.get("tie_breakers"), 3, TIE_BREAKERS):
			return _invalid("interaction_tie_breakers")
	var refs: Dictionary = policy.get("interaction_policy_refs", {})
	for raw_ref: Variant in refs.values():
		if str(raw_ref) != "" and not policy_ids.has(str(raw_ref)):
			return _invalid("unknown_interaction_policy_ref")
	return {"valid": true}


func _validate_checkpoint(node: Dictionary, node_by_id: Dictionary) -> Dictionary:
	if not _has_only_keys(node, CHECKPOINT_NODE_KEYS) \
			or not _has_required_keys(node, CHECKPOINT_NODE_KEYS):
		return _invalid("checkpoint_node_shape")
	var branches: Variant = node.get("branches", [])
	if not (branches is Array):
		return _invalid("branches_not_array")
	if (branches as Array).size() > 3:
		return _invalid("branch_count")
	for raw_branch: Variant in branches as Array:
		if not (raw_branch is Dictionary):
			return _invalid("branch_not_object")
		var branch: Dictionary = raw_branch
		if not _has_only_keys(branch, BRANCH_KEYS) or not _has_required_keys(branch, BRANCH_KEYS):
			return _invalid("branch_shape")
		if not (branch.get("next_node_id") is String):
			return _invalid("missing_branch_target")
		var next_node := str(branch.get("next_node_id", ""))
		if next_node == "" or not node_by_id.has(next_node):
			return _invalid("missing_branch_target")
		var clauses: Variant = branch.get("when_all", [])
		if not (clauses is Array) or (clauses as Array).is_empty():
			return _invalid("empty_guard")
		if (clauses as Array).size() > 3:
			return _invalid("guard_count")
		for raw_clause: Variant in clauses as Array:
			if not (raw_clause is Dictionary):
				return _invalid("guard_not_object")
			var clause: Dictionary = raw_clause
			if not _has_only_keys(clause, GUARD_KEYS) or not _has_required_keys(clause, GUARD_KEYS):
				return _invalid("guard_shape")
			if not (clause.get("fact") is String) \
					or str(clause.get("fact", "")) not in ContractsScript.REGISTERED_FACT_PATHS:
				return _invalid("unknown_fact")
			if not (clause.get("op") is String) \
					or str(clause.get("op", "")) not in ContractsScript.GUARD_OPERATORS:
				return _invalid("unknown_guard_operator")
	if not (node.get("otherwise") is String):
		return _invalid("missing_otherwise")
	var otherwise := str(node.get("otherwise", ""))
	if otherwise == "":
		return _invalid("missing_otherwise")
	if otherwise not in ["local_best", "replan", "rules_fallback"] and not node_by_id.has(otherwise):
		return _invalid("unknown_otherwise")
	return {"valid": true}


func _validate_acyclic(node_by_id: Dictionary) -> Dictionary:
	var visiting: Dictionary = {}
	var visited: Dictionary = {}
	for raw_node_id: Variant in node_by_id.keys():
		var node_id := str(raw_node_id)
		if not bool(visited.get(node_id, false)) and _has_cycle(node_id, node_by_id, visiting, visited):
			return _invalid("cycle")
	return {"valid": true}


func _canonicalize_reachable_policy(
	root: String,
	node_by_id: Dictionary,
	policy: Dictionary
) -> Dictionary:
	var reachable: Dictionary = {}
	var pending: Array[String] = [root]
	while not pending.is_empty():
		var node_id: String = pending.pop_back()
		if bool(reachable.get(node_id, false)):
			continue
		reachable[node_id] = true
		var node: Dictionary = node_by_id.get(node_id, {})
		var next_node := str(node.get("next_node_id", ""))
		if node_by_id.has(next_node) and not bool(reachable.get(next_node, false)):
			pending.append(next_node)
		var branches: Variant = node.get("branches", [])
		if branches is Array:
			for raw_branch: Variant in branches as Array:
				if not (raw_branch is Dictionary):
					continue
				var branch_target := str((raw_branch as Dictionary).get("next_node_id", ""))
				if node_by_id.has(branch_target) and not bool(reachable.get(branch_target, false)):
					pending.append(branch_target)
		var otherwise := str(node.get("otherwise", ""))
		if node_by_id.has(otherwise) and not bool(reachable.get(otherwise, false)):
			pending.append(otherwise)
	var nodes: Array = policy.get("nodes", []) if policy.get("nodes", []) is Array else []
	var filtered: Array = []
	for raw_node: Variant in nodes:
		if raw_node is Dictionary and bool(reachable.get(str((raw_node as Dictionary).get("node_id", "")), false)):
			filtered.append(raw_node)
	var normalized := policy.duplicate(true)
	normalized["nodes"] = filtered
	return {
		"policy": normalized,
		"canonicalized_unreachable_nodes": nodes.size() - filtered.size(),
	}


func _has_cycle(node_id: String, node_by_id: Dictionary, visiting: Dictionary, visited: Dictionary) -> bool:
	if bool(visiting.get(node_id, false)):
		return true
	if bool(visited.get(node_id, false)):
		return false
	visiting[node_id] = true
	var node: Dictionary = node_by_id[node_id]
	var targets: Array[String] = []
	var next_node := str(node.get("next_node_id", ""))
	if next_node != "":
		targets.append(next_node)
	var branches: Variant = node.get("branches", [])
	if branches is Array:
		for raw_branch: Variant in branches as Array:
			if raw_branch is Dictionary:
				targets.append(str((raw_branch as Dictionary).get("next_node_id", "")))
	var otherwise := str(node.get("otherwise", ""))
	if node_by_id.has(otherwise):
		targets.append(otherwise)
	for target: String in targets:
		if target != "" and _has_cycle(target, node_by_id, visiting, visited):
			return true
	visiting.erase(node_id)
	visited[node_id] = true
	return false


func _has_only_keys(value: Dictionary, allowed: Array[String]) -> bool:
	for raw_key: Variant in value.keys():
		if str(raw_key) not in allowed:
			return false
	return true


func _has_required_keys(value: Dictionary, required: Array[String]) -> bool:
	for key: String in required:
		if not value.has(key):
			return false
	return true


func _valid_string_array(value: Variant, max_items: int, allowed_values: Array[String]) -> bool:
	if not (value is Array) or (value as Array).size() > max_items:
		return false
	for item: Variant in value as Array:
		if not (item is String) or str(item) not in allowed_values:
			return false
	return true


func _valid_token_array(value: Variant, max_items: int, allow_colon_dash: bool) -> bool:
	if not (value is Array) or (value as Array).size() > max_items:
		return false
	for item: Variant in value as Array:
		if not (item is String) or not _valid_token(str(item), allow_colon_dash):
			return false
	return true


func _valid_token(value: String, allow_colon_dash: bool) -> bool:
	if value == "":
		return false
	for index: int in value.length():
		var code := value.unicode_at(index)
		var lowercase := code >= 97 and code <= 122
		var digit := code >= 48 and code <= 57
		var separator := code == 95 or allow_colon_dash and code in [45, 58]
		if not lowercase and not digit and not separator:
			return false
	return true


func _is_prefixed_string(value: Variant, prefix: String) -> bool:
	return value is String and str(value).begins_with(prefix) and str(value).length() > prefix.length()


func _model_response_error_reason(response: Dictionary) -> String:
	var error_type := str(response.get("error_type", "")).strip_edges()
	if error_type == "response_truncated":
		return "response_truncated"
	if error_type in [
		"invalid_response_json",
		"missing_choices",
		"invalid_choice",
		"missing_content",
		"invalid_content_json",
	]:
		return "invalid_model_response"
	return "transport_error"


func _invalid(reason: String) -> Dictionary:
	return {"valid": false, "reason": reason}
