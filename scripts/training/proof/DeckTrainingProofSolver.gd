class_name DeckTrainingProofSolver
extends RefCounted


const SOLVER_VERSION := "deck-training-and-or-v2"
const STATUS_PROVEN := "PROVEN"
const STATUS_REFUTED := "REFUTED"
const STATUS_INCONCLUSIVE := "INCONCLUSIVE"

const ROLE_PLAYER := "player"
const ROLE_OPPONENT := "opponent"
const ROLE_CHANCE := "chance"
const ROLE_TERMINAL := "terminal"

const DEFAULT_MAX_DEPTH := 24
const DEFAULT_MAX_NODES := 25000
const DEFAULT_MAX_MILLISECONDS := 15000

var _provider: RefCounted = null
var _config: Dictionary = {}
var _started_msec := 0
var _nodes_visited := 0
var _cache_hits := 0
var _terminal_leaves := 0
var _inconclusive_leaves := 0
var _budget_reason := ""
var _cache: Dictionary = {}
var _active_keys: Dictionary = {}


func prove(initial_state: Variant, provider: RefCounted, config: Dictionary = {}) -> Dictionary:
	_reset(provider, config)
	var contract_error := _provider_contract_error()
	if contract_error != "":
		return _certificate(_leaf(STATUS_INCONCLUSIVE, contract_error, 0), initial_state)
	var root_state: Variant = _provider.call("clone_state", initial_state)
	var result := _solve(root_state, 0)
	return _certificate(result, root_state)


func _reset(provider: RefCounted, config: Dictionary) -> void:
	_provider = provider
	_config = {
		"max_depth": maxi(1, int(config.get("max_depth", DEFAULT_MAX_DEPTH))),
		"max_nodes": maxi(1, int(config.get("max_nodes", DEFAULT_MAX_NODES))),
		"max_milliseconds": maxi(1, int(config.get("max_milliseconds", DEFAULT_MAX_MILLISECONDS))),
		"require_unique_root": bool(config.get("require_unique_root", false)),
		"collect_all_player_branches": bool(config.get("collect_all_player_branches", true)),
	}
	_started_msec = Time.get_ticks_msec()
	_nodes_visited = 0
	_cache_hits = 0
	_terminal_leaves = 0
	_inconclusive_leaves = 0
	_budget_reason = ""
	_cache.clear()
	_active_keys.clear()


func _provider_contract_error() -> String:
	if _provider == null:
		return "missing_provider"
	for method_name: String in [
		"clone_state",
		"state_key",
		"node_role",
		"terminal_result",
		"legal_choices",
		"apply_choice",
	]:
		if not _provider.has_method(method_name):
			return "provider_missing_%s" % method_name
	return ""


func _solve(state: Variant, depth: int) -> Dictionary:
	var budget_error := _budget_error(depth)
	if budget_error != "":
		_inconclusive_leaves += 1
		return _leaf(STATUS_INCONCLUSIVE, budget_error, depth)

	var state_key := str(_provider.call("state_key", state)).strip_edges()
	if state_key == "":
		_inconclusive_leaves += 1
		return _leaf(STATUS_INCONCLUSIVE, "empty_state_key", depth)
	var cache_key := "%s|%d" % [state_key, int(_config.get("max_depth", DEFAULT_MAX_DEPTH)) - depth]
	if _cache.has(cache_key):
		_cache_hits += 1
		return (_cache[cache_key] as Dictionary).duplicate(true)
	if _active_keys.has(state_key):
		_inconclusive_leaves += 1
		return _leaf(STATUS_INCONCLUSIVE, "cycle_without_progress", depth)

	_nodes_visited += 1
	var terminal_variant: Variant = _provider.call("terminal_result", state)
	if not (terminal_variant is Dictionary):
		_inconclusive_leaves += 1
		return _leaf(STATUS_INCONCLUSIVE, "invalid_terminal_contract", depth)
	var terminal: Dictionary = terminal_variant
	if bool(terminal.get("terminal", false)):
		_terminal_leaves += 1
		var terminal_status := STATUS_PROVEN if bool(terminal.get("success", false)) else STATUS_REFUTED
		var terminal_leaf := _leaf(terminal_status, str(terminal.get("reason", "terminal")), depth)
		terminal_leaf["score"] = int(terminal.get("score", 0))
		_cache[cache_key] = terminal_leaf.duplicate(true)
		return terminal_leaf

	var role := str(_provider.call("node_role", state))
	if role not in [ROLE_PLAYER, ROLE_OPPONENT, ROLE_CHANCE]:
		_inconclusive_leaves += 1
		return _leaf(STATUS_INCONCLUSIVE, "invalid_node_role:%s" % role, depth)

	var choices_variant: Variant = _provider.call("legal_choices", state)
	if not (choices_variant is Dictionary):
		_inconclusive_leaves += 1
		return _leaf(STATUS_INCONCLUSIVE, "invalid_choice_contract", depth)
	var choice_contract: Dictionary = choices_variant
	var choices_variant_value: Variant = choice_contract.get("choices", [])
	if not (choices_variant_value is Array):
		_inconclusive_leaves += 1
		return _leaf(STATUS_INCONCLUSIVE, "choices_not_array", depth)
	var choices: Array = choices_variant_value
	var coverage_complete := bool(choice_contract.get("complete", false))
	var coverage_reason := str(choice_contract.get("reason", "choice_enumeration_incomplete"))
	var id_error := _choice_id_error(choices)
	if id_error != "":
		_inconclusive_leaves += 1
		return _leaf(STATUS_INCONCLUSIVE, id_error, depth)
	if choices.is_empty():
		if coverage_complete:
			return _leaf(STATUS_REFUTED, "no_legal_choices", depth)
		_inconclusive_leaves += 1
		return _leaf(STATUS_INCONCLUSIVE, coverage_reason, depth)

	_active_keys[state_key] = true
	var branches: Array[Dictionary] = []
	for choice_variant: Variant in choices:
		var choice: Dictionary = choice_variant
		var branch := _solve_choice(state, choice, depth)
		branches.append(branch)
		if role == ROLE_PLAYER \
				and not bool(_config.get("collect_all_player_branches", true)) \
				and not bool(_config.get("require_unique_root", false)) \
				and str(branch.get("status", "")) == STATUS_PROVEN:
			break
		if _budget_reason != "":
			break
	_active_keys.erase(state_key)

	var result := _combine(role, branches, coverage_complete, coverage_reason, depth)
	_cache[cache_key] = result.duplicate(true)
	return result


func _solve_choice(state: Variant, choice: Dictionary, depth: int) -> Dictionary:
	var choice_id := str(choice.get("id", ""))
	var choice_label := str(choice.get("label", choice_id))
	if not bool(choice.get("supported", true)):
		_inconclusive_leaves += 1
		return {
			"choice_id": choice_id,
			"choice_label": choice_label,
			"status": STATUS_INCONCLUSIVE,
			"reason": str(choice.get("unsupported_reason", "unsupported_choice")),
			"depth": depth + 1,
			"player_actions": int(choice.get("player_action_cost", 0)),
			"tree": {},
		}
	var next_state: Variant = _provider.call("clone_state", state)
	var transition_variant: Variant = _provider.call("apply_choice", next_state, choice)
	if not (transition_variant is Dictionary):
		_inconclusive_leaves += 1
		return _transition_leaf(choice_id, choice_label, STATUS_INCONCLUSIVE, "invalid_transition_contract", depth, choice)
	var transition: Dictionary = transition_variant
	if not bool(transition.get("complete", false)):
		_inconclusive_leaves += 1
		return _transition_leaf(
			choice_id,
			choice_label,
			STATUS_INCONCLUSIVE,
			str(transition.get("reason", "transition_incomplete")),
			depth,
			choice
		)
	if not bool(transition.get("ok", false)):
		return _transition_leaf(
			choice_id,
			choice_label,
			STATUS_REFUTED,
			str(transition.get("reason", "illegal_transition")),
			depth,
			choice
		)
	var child_state: Variant = transition.get("state", next_state)
	var child := _solve(child_state, depth + 1)
	return {
		"choice_id": choice_id,
		"choice_label": choice_label,
		"status": str(child.get("status", STATUS_INCONCLUSIVE)),
		"reason": str(child.get("reason", "")),
		"depth": int(child.get("depth", depth + 1)),
		"player_actions": int(child.get("player_actions", 0)) + int(choice.get("player_action_cost", 0)),
		"tree": child,
	}


func _transition_leaf(
	choice_id: String,
	choice_label: String,
	status: String,
	reason: String,
	depth: int,
	choice: Dictionary
) -> Dictionary:
	return {
		"choice_id": choice_id,
		"choice_label": choice_label,
		"status": status,
		"reason": reason,
		"depth": depth + 1,
		"player_actions": int(choice.get("player_action_cost", 0)),
		"tree": {},
	}


func _combine(
	role: String,
	branches: Array[Dictionary],
	coverage_complete: bool,
	coverage_reason: String,
	depth: int
) -> Dictionary:
	var proven: Array[Dictionary] = []
	var refuted: Array[Dictionary] = []
	var inconclusive: Array[Dictionary] = []
	for branch: Dictionary in branches:
		match str(branch.get("status", STATUS_INCONCLUSIVE)):
			STATUS_PROVEN:
				proven.append(branch)
			STATUS_REFUTED:
				refuted.append(branch)
			_:
				inconclusive.append(branch)

	var status := STATUS_INCONCLUSIVE
	var reason := ""
	var selected: Dictionary = {}
	if role == ROLE_PLAYER:
		if not proven.is_empty():
			proven.sort_custom(_shorter_player_branch)
			selected = proven[0]
			status = STATUS_PROVEN
			reason = "player_has_forcing_choice"
			if bool(_config.get("require_unique_root", false)) and depth == 0:
				if proven.size() != 1 or not inconclusive.is_empty() or not coverage_complete:
					status = STATUS_INCONCLUSIVE
					reason = "root_uniqueness_not_proven"
		elif not inconclusive.is_empty() or not coverage_complete:
			status = STATUS_INCONCLUSIVE
			reason = coverage_reason if inconclusive.is_empty() else "player_branch_inconclusive"
			selected = inconclusive[0] if not inconclusive.is_empty() else {}
		else:
			status = STATUS_REFUTED
			reason = "all_player_choices_refuted"
			selected = refuted[0] if not refuted.is_empty() else {}
	else:
		# Opponent and chance nodes are AND nodes.  A proof is sound only when
		# every legal reply/outcome still reaches the goal.
		if not refuted.is_empty():
			status = STATUS_REFUTED
			reason = "defense_refutes_goal" if role == ROLE_OPPONENT else "chance_outcome_refutes_goal"
			selected = _worst_defense_branch(refuted)
		elif not inconclusive.is_empty() or not coverage_complete:
			status = STATUS_INCONCLUSIVE
			reason = coverage_reason if inconclusive.is_empty() else "%s_branch_inconclusive" % role
			selected = inconclusive[0] if not inconclusive.is_empty() else {}
		else:
			status = STATUS_PROVEN
			reason = "all_defenses_hold" if role == ROLE_OPPONENT else "all_chance_outcomes_hold"
			selected = _worst_defense_branch(proven)

	return {
		"status": status,
		"reason": reason,
		"role": role,
		"depth": int(selected.get("depth", depth)),
		"player_actions": int(selected.get("player_actions", 0)),
		"coverage_complete": coverage_complete,
		"winning_choice_count": proven.size(),
		"selected_choice_id": str(selected.get("choice_id", "")),
		"selected_choice_label": str(selected.get("choice_label", "")),
		"branches": branches,
	}


func _certificate(result: Dictionary, initial_state: Variant) -> Dictionary:
	var root_role := ""
	if _provider != null and _provider.has_method("node_role"):
		root_role = str(_provider.call("node_role", initial_state))
	var provider_name := _provider.get_class() if _provider != null else ""
	if _provider != null and _provider.has_method("provider_name"):
		provider_name = str(_provider.call("provider_name"))
	var scenario_fingerprint := ""
	if _provider != null and _provider.has_method("scenario_fingerprint"):
		scenario_fingerprint = str(_provider.call("scenario_fingerprint"))
	var principal_variation := _principal_variation(result)
	var unsupported_reasons: Array[String] = []
	_collect_inconclusive_reasons(result, unsupported_reasons)
	return {
		"format_version": 1,
		"solver_version": SOLVER_VERSION,
		"status": str(result.get("status", STATUS_INCONCLUSIVE)),
		"reason": str(result.get("reason", "")),
		"provider": provider_name,
		"scenario_fingerprint": scenario_fingerprint,
		"root_role": root_role,
		"unique_root_solution": _root_uniqueness_proven(result),
		"shortest_player_actions": int(result.get("player_actions", 0)),
		"principal_variation": principal_variation,
		"root_branches": result.get("branches", []),
		"exhaustive_defense": _all_defense_nodes_complete(result),
		"unsupported_reasons": unsupported_reasons,
		"metrics": {
			"nodes_visited": _nodes_visited,
			"cache_hits": _cache_hits,
			"terminal_leaves": _terminal_leaves,
			"inconclusive_leaves": _inconclusive_leaves,
			"elapsed_milliseconds": Time.get_ticks_msec() - _started_msec,
			"budget_reason": _budget_reason,
		},
		"proof_tree": result,
	}


func _budget_error(depth: int) -> String:
	if depth > int(_config.get("max_depth", DEFAULT_MAX_DEPTH)):
		_budget_reason = "max_depth_exhausted"
		return _budget_reason
	if _nodes_visited >= int(_config.get("max_nodes", DEFAULT_MAX_NODES)):
		_budget_reason = "max_nodes_exhausted"
		return _budget_reason
	if Time.get_ticks_msec() - _started_msec >= int(_config.get("max_milliseconds", DEFAULT_MAX_MILLISECONDS)):
		_budget_reason = "time_budget_exhausted"
		return _budget_reason
	return ""


func _choice_id_error(choices: Array) -> String:
	var seen: Dictionary = {}
	for choice_variant: Variant in choices:
		if not (choice_variant is Dictionary):
			return "choice_not_dictionary"
		var choice: Dictionary = choice_variant
		var choice_id := str(choice.get("id", "")).strip_edges()
		if choice_id == "":
			return "choice_missing_stable_id"
		if seen.has(choice_id):
			return "duplicate_choice_id:%s" % choice_id
		seen[choice_id] = true
	return ""


func _leaf(status: String, reason: String, depth: int) -> Dictionary:
	return {
		"status": status,
		"reason": reason,
		"depth": depth,
		"player_actions": 0,
		"coverage_complete": true,
		"winning_choice_count": 0,
		"branches": [],
	}


func _shorter_player_branch(a: Dictionary, b: Dictionary) -> bool:
	var actions_a := int(a.get("player_actions", 0))
	var actions_b := int(b.get("player_actions", 0))
	if actions_a == actions_b:
		return int(a.get("depth", 0)) < int(b.get("depth", 0))
	return actions_a < actions_b


func _worst_defense_branch(branches: Array[Dictionary]) -> Dictionary:
	if branches.is_empty():
		return {}
	var selected: Dictionary = branches[0]
	for branch: Dictionary in branches:
		if int(branch.get("player_actions", 0)) > int(selected.get("player_actions", 0)):
			selected = branch
		elif int(branch.get("player_actions", 0)) == int(selected.get("player_actions", 0)) \
				and int(branch.get("depth", 0)) > int(selected.get("depth", 0)):
			selected = branch
	return selected


func _principal_variation(result: Dictionary) -> Array[Dictionary]:
	var variation: Array[Dictionary] = []
	var current: Dictionary = result
	while not current.is_empty():
		var selected_id := str(current.get("selected_choice_id", ""))
		if selected_id == "":
			break
		var selected_branch: Dictionary = {}
		for branch_variant: Variant in current.get("branches", []):
			if branch_variant is Dictionary and str((branch_variant as Dictionary).get("choice_id", "")) == selected_id:
				selected_branch = branch_variant
				break
		if selected_branch.is_empty():
			break
		variation.append({
			"role": str(current.get("role", "")),
			"choice_id": selected_id,
			"choice_label": str(selected_branch.get("choice_label", selected_id)),
			"status": str(selected_branch.get("status", "")),
		})
		current = selected_branch.get("tree", {}) if selected_branch.get("tree", {}) is Dictionary else {}
	return variation


func _all_defense_nodes_complete(node: Dictionary) -> bool:
	if str(node.get("role", "")) in [ROLE_OPPONENT, ROLE_CHANCE] and not bool(node.get("coverage_complete", false)):
		return false
	for branch_variant: Variant in node.get("branches", []):
		if not (branch_variant is Dictionary):
			return false
		var branch: Dictionary = branch_variant
		if str(branch.get("status", "")) == STATUS_INCONCLUSIVE:
			return false
		var tree_variant: Variant = branch.get("tree", {})
		if tree_variant is Dictionary and not (tree_variant as Dictionary).is_empty():
			if not _all_defense_nodes_complete(tree_variant):
				return false
	return true


func _root_uniqueness_proven(result: Dictionary) -> bool:
	if str(result.get("status", "")) != STATUS_PROVEN \
			or int(result.get("winning_choice_count", 0)) != 1 \
			or not bool(result.get("coverage_complete", false)):
		return false
	for branch_variant: Variant in result.get("branches", []):
		if not (branch_variant is Dictionary):
			return false
		if str((branch_variant as Dictionary).get("status", "")) == STATUS_INCONCLUSIVE:
			return false
	return true


func _collect_inconclusive_reasons(node: Dictionary, output: Array[String]) -> void:
	if str(node.get("status", "")) == STATUS_INCONCLUSIVE:
		var reason := str(node.get("reason", "")).strip_edges()
		if reason != "" and reason not in output:
			output.append(reason)
	for branch_variant: Variant in node.get("branches", []):
		if not (branch_variant is Dictionary):
			continue
		var branch: Dictionary = branch_variant
		if str(branch.get("status", "")) == STATUS_INCONCLUSIVE:
			var branch_reason := str(branch.get("reason", "")).strip_edges()
			if branch_reason != "" and branch_reason not in output:
				output.append(branch_reason)
		var tree_variant: Variant = branch.get("tree", {})
		if tree_variant is Dictionary and not (tree_variant as Dictionary).is_empty():
			_collect_inconclusive_reasons(tree_variant, output)
