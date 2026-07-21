class_name V18ConditionalPolicyStrategy
extends DeckStrategyBase

signal v18cpg_decision_ready(turn_number: int, accepted: bool, reason: String)

const ContractsScript = preload("res://scripts/ai/v18_cpg/schema/V18CPGContracts.gd")
const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const ObservationGatewayScript = preload("res://scripts/ai/v18_cpg/observation/V18CPGObservationGateway.gd")
const BeliefStateScript = preload("res://scripts/ai/v18_cpg/observation/V18CPGBeliefState.gd")
const MaterialDeltaScript = preload("res://scripts/ai/v18_cpg/observation/V18CPGMaterialDelta.gd")
const SemanticCompilerScript = preload("res://scripts/ai/v18_cpg/semantics/V18CPGDeckSemanticCompiler.gd")
const FactBuilderScript = preload("res://scripts/ai/v18_cpg/planning/V18CPGFactBuilder.gd")
const ResourceLedgerScript = preload("res://scripts/ai/v18_cpg/planning/V18CPGResourceLedger.gd")
const PrizeGraphScript = preload("res://scripts/ai/v18_cpg/planning/V18CPGPrizeGraphSolver.gd")
const ThreatResponseScript = preload("res://scripts/ai/v18_cpg/planning/V18CPGThreatResponseSolver.gd")
const RouteSearchScript = preload("res://scripts/ai/v18_cpg/planning/V18CPGRouteSearch.gd")
const PolicyGraphScript = preload("res://scripts/ai/v18_cpg/policy/V18CPGPolicyGraph.gd")
const PolicyValidatorScript = preload("res://scripts/ai/v18_cpg/policy/V18CPGPolicyValidator.gd")
const DecisionClientScript = preload("res://scripts/ai/v18_cpg/network/V18CPGDecisionClient.gd")
const RulesFallbackScript = preload("res://scripts/ai/v18_cpg/runtime/V18CPGRulesFallbackAdapter.gd")
const NoctowlSearchScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGTeraNoctowlSearch.gd")
const CapabilityRegistryScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCapabilityRegistry.gd")
const AuditScript = preload("res://scripts/ai/v18_cpg/audit/V18CPGDecisionAudit.gd")
const ProfilePolicyScript = preload("res://scripts/ai/v18_cpg/policy/V18CPGProfilePolicy.gd")
const ExecutionCursorScript = preload("res://scripts/ai/v18_cpg/runtime/V18CPGExecutionCursor.gd")
const InteractionPolicyScript = preload("res://scripts/ai/v18_cpg/execution/V18CPGInteractionPolicy.gd")
const VisibleWaitBudgetScript = preload("res://scripts/ai/v18_cpg/runtime/V18CPGVisibleWaitBudget.gd")

const ROUTE_SELECTION_BONUS := 20000.0
const MAX_ROUTE_SELECTION_BONUS := 250000.0
const ROUTE_MISMATCH_PENALTY := 350.0
const REGISTERED_ROUTE_IDS: Array[String] = [
	"route:attack_ko",
	"route:attack_pressure",
	"route:noctowl_search",
	"route:opening_search",
	"route:information",
	"route:tutor",
	"route:recover",
	"route:accelerate",
	"route:energy_commit",
	"route:evolve",
	"route:develop",
	"route:stadium",
	"route:gust",
	"route:pivot",
	"route:end_turn",
]

var _profile: Dictionary = {}
var _semantic_manifest: Dictionary = {}
var _configured_deck: DeckData = null
var _observation_gateway = ObservationGatewayScript.new()
var _belief = BeliefStateScript.new()
var _material_delta = MaterialDeltaScript.new()
var _semantic_compiler = SemanticCompilerScript.new()
var _fact_builder = FactBuilderScript.new()
var _resource_ledger = ResourceLedgerScript.new()
var _prize_graph = PrizeGraphScript.new()
var _threat_response = ThreatResponseScript.new()
var _route_search = RouteSearchScript.new()
var _policy_graph = PolicyGraphScript.new()
var _policy_validator = PolicyValidatorScript.new()
var _decision_client = DecisionClientScript.new()
var _rules_fallback = RulesFallbackScript.new()
var _noctowl_search = NoctowlSearchScript.new()
var _capability_registry = CapabilityRegistryScript.new()
var _audit = AuditScript.new()
var _profile_policy = ProfilePolicyScript.new()
var _execution_cursor = ExecutionCursorScript.new()
var _interaction_policy = InteractionPolicyScript.new()
var _visible_wait_budget = VisibleWaitBudgetScript.new()

var _runtime_configured: bool = false
var _last_observation: Dictionary = {}
var _last_facts: Dictionary = {}
var _last_frontier: Array[Dictionary] = []
var _preferred_action_id: String = ""
var _preferred_candidate_id: String = ""
var _current_route_id: String = ""
var _current_action_owner: String = "rules_fallback"
var _match_agenda: Dictionary = {}
var _current_turn: int = -1
var _revision_serial: int = 0
var _request_serial: int = 0
var _lifecycle: Dictionary = {}
var _pending_request_id: String = ""
var _pending_context: Dictionary = {}
var _handled_delta_hashes: Dictionary = {}
var _last_request_metrics: Dictionary = {}
var _branch_hits: int = 0
var _uncovered_events: int = 0
var _turn_visible_wait_ms: int = 0
var _turn_model_requests: int = 0
var _request_wait_samples_ms: Array[float] = []
var _unconsumed_action_result: Dictionary = {}
var _route_selection_bonus: float = ROUTE_SELECTION_BONUS
var _pending_request_started_msec: int = 0
var _pending_request_visible_budget_ms: int = 0
var _active_module_certificate_kind: String = ""
var _profiled_gardevoir_interaction_ticket: Dictionary = {}
var _profiled_gardevoir_suffix_ticket: Dictionary = {}
var _runtime_host: Node = null


func configure_profile(profile: Dictionary, semantic_manifest: Dictionary = {}) -> void:
	_profile = profile.duplicate(true)
	_semantic_manifest = semantic_manifest.duplicate(true)
	_rules_fallback.configure(_profile.get("rule_profile", {}))
	_reset_match_state()


func configure_from_deck(deck: DeckData) -> void:
	_configured_deck = deck
	if deck != null and _profile.is_empty():
		configure_profile(ProfileCatalogScript.get_profile_for_deck(int(deck.id)))
	if not _profile.is_empty():
		_semantic_manifest = _semantic_compiler.compile(deck, _profile)
		_rules_fallback.configure(_profile.get("rule_profile", {}), deck)


func configure_runtime(host: Node, api_config: Dictionary) -> void:
	_runtime_host = host
	_decision_client.configure(host, api_config)
	_runtime_configured = _decision_client.is_configured()
	if not _decision_client.response_ready.is_connected(_on_policy_response):
		_decision_client.response_ready.connect(_on_policy_response)


func configure_verified_local_only_for_benchmark() -> void:
	# Benchmark-only diagnostic: activate deterministic capability certificates
	# without a network client. Request attempts fail closed immediately to the
	# Rule floor, while verified local upgrades remain measurable in isolation.
	_runtime_configured = true


func configure_audit(run_id: String, match_id: String, write_files: bool = false) -> void:
	_audit.configure(run_id, match_id, write_files)


func get_strategy_id() -> String:
	return str(_profile.get("strategy_id", ""))


func get_runtime_kind() -> String:
	return ContractsScript.RUNTIME_KIND


func get_runtime_metadata() -> Dictionary:
	return {
		"strategy_id": get_strategy_id(),
		"base_strategy_id": str(_profile.get("base_strategy_id", "")),
		"runtime_kind": ContractsScript.RUNTIME_KIND,
		"feature_flag": ContractsScript.FEATURE_FLAG,
		"experimental": true,
		"requires_model": true,
	}


func get_v18cpg_action_certificate_parameters() -> Dictionary:
	var local_parameters: Variant = _profile.get("local_action_certificate_parameters", {})
	if not (local_parameters is Dictionary):
		return {}
	var partner_parameters: Variant = (local_parameters as Dictionary).get("partner_chain", {})
	return (partner_parameters as Dictionary).duplicate(true) \
		if partner_parameters is Dictionary else {}


func prepare_decision(
	game_state: GameState,
	player_index: int,
	legal_actions: Array,
	event_context: Dictionary = {}
) -> Dictionary:
	var started_msec := Time.get_ticks_msec()
	if game_state == null or _profile.is_empty():
		return {"status": "rules_fallback", "reason": "not_configured"}
	var turn_number := int(game_state.turn_number)
	if turn_number != _current_turn:
		_begin_turn(turn_number, event_context)
	var observation := _observation_gateway.build(game_state, player_index, legal_actions)
	var facts := _fact_builder.build(observation, _current_route_id, _profile)
	facts = _with_public_flow_facts(facts, observation)
	var turn_plan := _rules_fallback.build_turn_plan(game_state, player_index, {"prompt_kind": "v18cpg_route_search"})
	var base_scores := _base_action_scores(legal_actions, game_state, player_index, turn_plan)
	var host_certificate: Dictionary = event_context.get("rule_floor_certificate", {}) \
		if event_context.get("rule_floor_certificate", {}) is Dictionary else {}
	if host_certificate.get("scores", {}) is Dictionary and not (host_certificate.get("scores", {}) as Dictionary).is_empty():
		base_scores = (host_certificate.get("scores", {}) as Dictionary).duplicate(true)
	var rule_floor_action_id := str(event_context.get("rule_floor_action_id", ""))
	if rule_floor_action_id == "":
		rule_floor_action_id = str(host_certificate.get("action_id", ""))
	var candidate_pool := _route_search.build_candidate_pool(
		observation,
		base_scores,
		_semantic_manifest,
		facts
	)
	# The exact engine Rule root is an input to several fail-closed public suffix
	# certificates. Bind it before capability annotation so production receives
	# the same proof context as the focused fixtures. Binding only after annotation
	# silently made those certificates impossible to mint in real matches.
	candidate_pool = _annotate_candidate_pool_with_engine_rule_floor(
		candidate_pool,
		rule_floor_action_id,
		observation,
		facts
	)
	# The terminal
	# skip proof must compare every legal candidate against that same Rule floor,
	# including candidates that do not fit into the ten-item model frontier.
	var frontier := _route_search.prune_frontier(candidate_pool, 10)
	frontier = _bind_engine_rule_floor(frontier, rule_floor_action_id)
	_trace_filtered_state(observation, facts, frontier)
	# The match's first observation has no material delta, so the normal post-action
	# certificate hook below cannot run yet.  The allowlist remains deliberately
	# narrow: a paired opening-counter proof, or an exact same-quota attachment
	# that immediately completes the current Active's public attack cost.
	if _runtime_configured and _last_observation.is_empty():
		var initial_upgrade := _find_module_verified_upgrade(frontier, facts)
		if _can_apply_initial_module_upgrade(initial_upgrade):
			_select_route(
				str(initial_upgrade.get("route_id", "")),
				frontier,
				"module_verified_upgrade",
				str(initial_upgrade.get("candidate_id", ""))
			)
			_activate_verified_upgrade_certificate(initial_upgrade)
			_update_last_state(observation, facts, frontier)
			_record_planning("module_verified_initial_upgrade", started_msec, false, {}, {
				"candidate_id": _preferred_candidate_id,
				"fallback_reason": "",
			})
			return {
				"status": "ready",
				"owner": _current_action_owner,
				"route_id": _current_route_id,
				"candidate_id": _preferred_candidate_id,
			}
	var available_route_ids := _route_ids(frontier)
	var available_candidate_ids := _candidate_ids(frontier)
	var delta_for_request: Dictionary = {}
	var request_is_delta := false
	if not _last_observation.is_empty() and str(observation.get("observation_hash", "")) != str(_last_observation.get("observation_hash", "")):
		var delta := _material_delta.compare(_last_observation, observation, _last_facts, facts)
		var delta_hash := str(delta.get("material_delta_hash", ""))
		var completed_action := _unconsumed_action_result.duplicate(true)
		_unconsumed_action_result.clear()
		if _runtime_configured:
			var verified_upgrade := _find_module_verified_upgrade(frontier, facts)
			if not verified_upgrade.is_empty():
				_select_route(
					str(verified_upgrade.get("route_id", "")),
					frontier,
					"module_verified_upgrade",
					str(verified_upgrade.get("candidate_id", ""))
				)
				_activate_verified_upgrade_certificate(verified_upgrade)
				_update_last_state(observation, facts, frontier)
				_record_planning("module_verified_route_upgrade", started_msec, false, delta, {
					"candidate_id": _preferred_candidate_id,
					"fallback_reason": "",
				})
				return {
					"status": "ready",
					"owner": _current_action_owner,
					"route_id": _current_route_id,
					"candidate_id": _preferred_candidate_id,
				}
		var reopen_information_epoch := _should_reopen_information_epoch(
			_policy_graph.origin(),
			completed_action,
			delta,
			_last_frontier
		)
		if reopen_information_epoch:
			var completed_route_id := str(completed_action.get("route_id", ""))
			var completed_candidate_id := str(completed_action.get("candidate_id", ""))
			_policy_graph.clear()
			_execution_cursor.clear()
			_preferred_action_id = ""
			_preferred_candidate_id = ""
			_current_route_id = ""
			_current_action_owner = "local_gate"
			_uncovered_events += 1
			delta_for_request = delta.duplicate(true)
			request_is_delta = true
			_record_planning("information_epoch_reopened", started_msec, false, delta, {
				"completed_route_id": completed_route_id,
				"completed_candidate_id": completed_candidate_id,
			})
		if not reopen_information_epoch and _execution_cursor.is_active():
			var continuation: Dictionary = _execution_cursor.resolve(
				frontier,
				int(observation.get("observation_version", 0))
			)
			if not continuation.is_empty():
				var continuation_owner := "policy_graph_branch" if _execution_cursor.origin() in ["model_selected_local_route", "model_synthesized_route"] else _execution_cursor.origin()
				var continuation_safety := _validate_model_route_safety(
					str(continuation.get("route_id", "")),
					frontier,
					facts,
					str(continuation.get("candidate_id", ""))
				) if continuation_owner == "policy_graph_branch" else {"valid": true}
				if not bool(continuation_safety.get("valid", false)):
					_install_local_policy(frontier, "local_gate")
					_update_last_state(observation, facts, frontier)
					_record_planning("unsafe_typed_route_fallback", started_msec, false, delta, {
						"fallback_reason": str(continuation_safety.get("reason", "typed_route_validation_failed")),
					})
					return {"status": "ready", "owner": _current_action_owner, "route_id": _current_route_id, "candidate_id": _preferred_candidate_id}
				if continuation_owner == "policy_graph_branch":
					_branch_hits += 1
				_select_route(
					str(continuation.get("route_id", "")),
					frontier,
					continuation_owner,
					str(continuation.get("candidate_id", ""))
				)
				_update_last_state(observation, facts, frontier)
				_record_planning("typed_route_continue", started_msec, true, delta, {
					"candidate_id": _preferred_candidate_id,
					"route_step_index": int(continuation.get("step_index", 0)),
				})
				return {"status": "ready", "owner": _current_action_owner, "route_id": _current_route_id, "candidate_id": _preferred_candidate_id}
		if not reopen_information_epoch and _policy_graph.is_active():
			var transition := _policy_graph.advance_after_observation(facts, available_route_ids, available_candidate_ids)
			if str(transition.get("status", "")) == "route":
				var graph_origin := _policy_graph.origin()
				var branch_owner := "policy_graph_branch" if graph_origin in ["model_selected_local_route", "model_synthesized_route", "model_shadow_rule_root"] else graph_origin
				var branch_candidate_id := str(transition.get("candidate_id", ""))
				if branch_candidate_id == "":
					branch_candidate_id = str(_route_search.find_route(frontier, str(transition.get("route_id", ""))).get("candidate_id", ""))
				var branch_safety := _validate_model_route_safety(
					str(transition.get("route_id", "")),
					frontier,
					facts,
					branch_candidate_id
				) if branch_owner == "policy_graph_branch" else {"valid": true}
				if not bool(branch_safety.get("valid", false)):
					_install_local_policy(frontier, "local_gate")
					_update_last_state(observation, facts, frontier)
					_record_planning("unsafe_graph_branch_fallback", started_msec, false, delta, {
						"fallback_reason": str(branch_safety.get("reason", "graph_branch_validation_failed")),
					})
					return {"status": "ready", "owner": _current_action_owner, "route_id": _current_route_id, "candidate_id": _preferred_candidate_id}
				if branch_owner == "policy_graph_branch":
					_branch_hits += 1
				_select_route(
					str(transition.get("route_id", "")),
					frontier,
					branch_owner,
					branch_candidate_id
				)
				_update_last_state(observation, facts, frontier)
				_record_planning("graph_branch", started_msec, true, delta, {})
				return {"status": "ready", "owner": _current_action_owner, "route_id": _current_route_id, "candidate_id": _preferred_candidate_id}
			if str(transition.get("status", "")) == "local_best":
				_install_local_policy(frontier, "local_gate")
				_update_last_state(observation, facts, frontier)
				_record_planning("local_branch", started_msec, false, delta, {})
				return {"status": "ready", "owner": _current_action_owner, "route_id": _current_route_id}
			if str(transition.get("status", "")) == "rules_fallback":
				_clear_route("rules_fallback")
				_update_last_state(observation, facts, frontier)
				return {"status": "rules_fallback", "reason": "policy_otherwise"}
			if not bool(delta.get("material", false)):
				_install_local_policy(frontier, "local_gate")
				_update_last_state(observation, facts, frontier)
				_record_planning("non_material_local_continue", started_msec, false, delta, {})
				return {"status": "ready", "owner": _current_action_owner, "route_id": _current_route_id}
			_uncovered_events += 1
			delta_for_request = delta.duplicate(true)
			request_is_delta = true
		if delta_hash != "" and _handled_delta_hashes.has(delta_hash):
			_install_local_policy(frontier, "local_gate")
			_update_last_state(observation, facts, frontier)
			return {"status": "ready", "owner": _current_action_owner, "route_id": _current_route_id}
		if delta_hash != "":
			_handled_delta_hashes[delta_hash] = true
	if frontier.is_empty():
		_clear_route("rules_fallback")
		_update_last_state(observation, facts, frontier)
		return {"status": "rules_fallback", "reason": "empty_frontier"}
	if _pending_request_id != "":
		_update_last_state(observation, facts, frontier)
		return {"status": "pending", "request_id": _pending_request_id}
	if _can_reuse_direct_verified_selection(frontier, str(observation.get("observation_hash", ""))):
		_select_route(_current_route_id, frontier, _current_action_owner, _preferred_candidate_id)
		_update_last_state(observation, facts, frontier)
		return {
			"status": "ready",
			"owner": _current_action_owner,
			"route_id": _current_route_id,
			"candidate_id": _preferred_candidate_id,
		}
	if _policy_graph.is_active() and str(observation.get("observation_hash", "")) == str(_last_observation.get("observation_hash", "")):
		_select_route(
			_policy_graph.current_route_id(),
			frontier,
			_policy_graph.origin(),
			_policy_graph.current_candidate_id()
		)
		_update_last_state(observation, facts, frontier)
		return {"status": "ready", "owner": _current_action_owner, "route_id": _current_route_id, "candidate_id": _preferred_candidate_id}
	var terminal_skip := _should_skip_terminal_without_admissible_switch(candidate_pool, facts)
	if bool(terminal_skip.get("skip", false)):
		# This is not a local strategic rewrite. Production safety checked the full
		# annotated legal pool and found no admissible non-Rule root switch. Keep a
		# one-shot Rule selection: a later observation must be evaluated afresh and
		# must not advance through a reusable fallback graph.
		_install_one_shot_rules_floor(frontier)
		_update_last_state(observation, facts, frontier)
		_record_planning("provably_terminal_no_admissible_switch", started_msec, false, delta_for_request, {
			"fallback_reason": "provably_terminal_no_admissible_switch",
			"checked_alternatives": int(terminal_skip.get("checked_alternatives", 0)),
			"checked_candidate_pool_size": candidate_pool.size(),
		})
		return {
			"status": "ready",
			"owner": _current_action_owner,
			"route_id": _current_route_id,
			"candidate_id": _preferred_candidate_id,
		}
	var local_decision := _should_use_local(frontier, facts)
	if bool(local_decision.get("use_local", false)) or not _runtime_configured:
		var fallback_owner := "local_gate" if _runtime_configured else "rules_fallback"
		_install_local_policy(frontier, fallback_owner)
		_update_last_state(observation, facts, frontier)
		_record_planning("local_policy", started_msec, false, {}, {"fallback_reason": str(local_decision.get("reason", "runtime_unconfigured"))})
		return {"status": "ready", "owner": _current_action_owner, "route_id": _current_route_id}
	var wait_gate := _visible_wait_budget.may_request(
		_turn_visible_wait_ms,
		_request_wait_samples_ms,
		_turn_model_requests,
		int(_profile.get("turn_visible_wait_budget_ms", 12000)),
		int(_profile.get("cold_request_estimate_ms", 6500))
	)
	if not bool(wait_gate.get("allowed", false)):
		_install_wait_budget_fallback(frontier)
		_update_last_state(observation, facts, frontier)
		_record_planning("visible_wait_budget_fallback", started_msec, false, delta_for_request, {
			"fallback_reason": str(wait_gate.get("reason", "visible_wait_budget_exhausted")),
			"expected_request_ms": int(wait_gate.get("expected_request_ms", 0)),
			"remaining_visible_wait_ms": int(wait_gate.get("remaining_ms", 0)),
		})
		return {"status": "ready", "owner": _current_action_owner, "route_id": _current_route_id}
	_request_serial += 1
	_lifecycle["decision_window_id"] = "%s:w%d" % [str(_lifecycle.get("policy_id", "policy")), _request_serial]
	_lifecycle["request_id"] = "%s:q%d" % [str(_lifecycle.get("policy_id", "policy")), _request_serial]
	var request_envelope := _build_request_envelope(observation, facts, frontier, delta_for_request)
	var request_id := str(_lifecycle.get("request_id", ""))
	var request_error := _decision_client.request_policy(
		request_id,
		request_envelope,
		int(_profile.get("delta_response_token_budget", 220)) if request_is_delta else int(_profile.get("initial_response_token_budget", 600)),
		request_is_delta
	)
	if request_error != OK:
		_install_local_policy(frontier, "deadline_fallback")
		_update_last_state(observation, facts, frontier)
		_record_planning("request_start_failed", started_msec, false, {}, {"fallback_reason": "request_error_%d" % request_error})
		return {"status": "ready", "owner": _current_action_owner, "route_id": _current_route_id}
	_audit.record_payload({
		"turn_id": _current_turn,
		"policy_id": str(_lifecycle.get("policy_id", "")),
		"decision_window_id": str(_lifecycle.get("decision_window_id", "")),
		"request_id": request_id,
		"deck_id": int(_profile.get("deck_id", 0)),
		"strategy_id": get_strategy_id(),
		"event_type": "model_request",
		"is_delta": request_is_delta,
		"token_budget": int(_profile.get("delta_response_token_budget", 220)) if request_is_delta else int(_profile.get("initial_response_token_budget", 600)),
		"request_envelope": request_envelope,
	})
	_turn_model_requests += 1
	_pending_request_id = request_id
	_pending_request_started_msec = Time.get_ticks_msec()
	var visible_budget_remaining := maxi(
		1,
		int(_profile.get("turn_visible_wait_budget_ms", 12000)) - _turn_visible_wait_ms
	)
	_pending_request_visible_budget_ms = maxi(
		1,
		visible_budget_remaining - int(_profile.get("visible_wait_deadline_headroom_ms", 250))
	)
	_pending_context = {
		"observation_version": int(observation.get("observation_version", 0)),
		"observation_hash": str(observation.get("observation_hash", "")),
		"allowed_route_ids": REGISTERED_ROUTE_IDS.duplicate(),
		"allowed_candidate_ids": available_candidate_ids.duplicate(),
		"available_route_ids": available_route_ids,
		"frontier": frontier.duplicate(true),
		"facts": facts.duplicate(true),
		"lifecycle": _lifecycle.duplicate(true),
		"is_delta": request_is_delta,
		"material_delta": delta_for_request.duplicate(true),
	}
	_update_last_state(observation, facts, frontier)
	return {"status": "pending", "request_id": request_id}


func has_pending_request() -> bool:
	return _pending_request_id != ""


func is_llm_pending() -> bool:
	return has_pending_request()


func ensure_llm_request_fired(
	game_state: GameState,
	player_index: int,
	legal_actions: Array,
	event_context: Dictionary = {}
) -> void:
	var context := event_context.duplicate(true)
	context["event_type"] = str(context.get("event_type", "MAIN_ACTION_WINDOW"))
	prepare_decision(game_state, player_index, legal_actions, context)


func has_llm_plan_for_turn(turn_number: int) -> bool:
	return turn_number == _current_turn and not has_pending_request() and _current_route_id != ""


func is_llm_disabled_for_turn(_turn_number: int) -> bool:
	return false


func get_llm_soft_timeout_seconds() -> float:
	return float(_profile.get("turn_visible_wait_budget_ms", 6500)) / 1000.0


func is_llm_soft_timed_out_for_turn(turn_number: int) -> bool:
	return turn_number == _current_turn and enforce_visible_wait_deadline()


func force_rules_for_turn(turn_number: int, reason: String = "external_rules_fallback") -> void:
	if turn_number == _current_turn and has_pending_request():
		force_deadline_fallback(reason, maxi(0, Time.get_ticks_msec() - _pending_request_started_msec))


func enforce_visible_wait_deadline(now_msec: int = -1) -> bool:
	var checked_msec := Time.get_ticks_msec() if now_msec < 0 else now_msec
	if not _request_deadline_due(checked_msec):
		return false
	var visible_wait_ms := maxi(0, checked_msec - _pending_request_started_msec)
	force_deadline_fallback("turn_visible_wait_budget_exhausted", visible_wait_ms)
	return true


func _request_deadline_due(now_msec: int) -> bool:
	return _pending_request_id != "" \
		and _pending_request_started_msec > 0 \
		and _pending_request_visible_budget_ms > 0 \
		and now_msec - _pending_request_started_msec >= _pending_request_visible_budget_ms


func force_deadline_fallback(
	reason: String = "external_wait_budget_exhausted",
	visible_wait_ms: int = -1
) -> void:
	if _pending_request_id == "":
		return
	_pending_request_id = ""
	_pending_context.clear()
	if visible_wait_ms >= 0:
		_turn_visible_wait_ms += visible_wait_ms
		_request_wait_samples_ms.append(float(visible_wait_ms))
	_pending_request_started_msec = 0
	_pending_request_visible_budget_ms = 0
	_install_local_policy(_last_frontier, "deadline_fallback")
	_audit.record({
		"turn_id": _current_turn,
		"policy_id": str(_lifecycle.get("policy_id", "")),
		"request_id": str(_lifecycle.get("request_id", "")),
		"deck_id": int(_profile.get("deck_id", 0)),
		"strategy_id": get_strategy_id(),
		"event_type": "policy_response",
		"accepted": false,
		"action_owner": "deadline_fallback",
		"fallback_layer": "deadline_fallback",
		"fallback_reason": reason,
		"request_wall_ms": maxi(0, visible_wait_ms),
		"visible_wait_ms": maxi(0, visible_wait_ms),
	})
	v18cpg_decision_ready.emit(_current_turn, false, reason)


func has_active_policy(turn_id: int, observation_version: int = -1) -> bool:
	if turn_id != _current_turn or not _policy_graph.is_active():
		return false
	return observation_version < 0 or observation_version == int(_last_observation.get("observation_version", -1))


func score_action_absolute(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var turn_plan := _rules_fallback.build_turn_plan(game_state, player_index, {"prompt_kind": "action_selection"})
	return _score_action_with_rule_floor_plan(action, game_state, player_index, turn_plan)


func score_action_absolute_with_plan(
	action: Dictionary,
	game_state: GameState,
	player_index: int,
	turn_plan: Dictionary = {}
) -> float:
	# AIOpponent calls this inherited contract whenever it is present.  Letting
	# DeckStrategyBase handle it would call score_action_absolute() first (whose
	# Rule adapter already applies continuity and retreat guards) and then apply
	# the base continuity/retreat bonuses a second time.  That double application
	# can invert a negative but Rule-preferred retreat beneath end_turn.  Delegate
	# the host's exact turn contract to the frozen Rule floor exactly once.
	return _score_action_with_rule_floor_plan(action, game_state, player_index, turn_plan)


func _score_action_with_rule_floor_plan(
	action: Dictionary,
	game_state: GameState,
	player_index: int,
	turn_plan: Dictionary
) -> float:
	var base_score := _rules_fallback.score_action(action, game_state, player_index, turn_plan)
	# Local/deadline/schema fallbacks are metadata-only policies: the host AI
	# must retain the exact rule score on its fully augmented action.  The
	# planning frontier sees a visibility-safe action projection and therefore
	# is not precise enough to replace the rule scorer as the fallback floor.
	var route_owned := _current_action_owner in [
		"model_selected_local_route",
		"model_synthesized_route",
		"policy_graph_branch",
		"module_verified_upgrade",
	]
	if _preferred_action_id == "" or not route_owned:
		return base_score
	var action_id := _observation_gateway.stable_action_id(action)
	if action_id == _preferred_action_id:
		return base_score + _route_selection_bonus
	if str(action.get("kind", "")) == "end_turn" and _current_route_id != "route:end_turn":
		return base_score - _route_selection_bonus
	return base_score - ROUTE_MISMATCH_PENALTY


func build_rule_floor_turn_plan(
	game_state: GameState,
	player_index: int,
	context: Dictionary = {}
) -> Dictionary:
	return _rules_fallback.build_turn_plan(game_state, player_index, context)


func score_rule_floor_action(
	action: Dictionary,
	game_state: GameState,
	player_index: int,
	turn_plan: Dictionary = {}
) -> float:
	return _rules_fallback.score_action(action, game_state, player_index, turn_plan)


func build_turn_plan(game_state: GameState, player_index: int, context: Dictionary = {}) -> Dictionary:
	var plan := _rules_fallback.build_turn_plan(game_state, player_index, context)
	plan["v18cpg"] = {
		"runtime_kind": ContractsScript.RUNTIME_KIND,
		"policy_id": str(_lifecycle.get("policy_id", "")),
		"revision_id": str(_lifecycle.get("revision_id", "")),
		"node_id": _policy_graph.current_node_id(),
		"route_id": _current_route_id,
		"candidate_id": _preferred_candidate_id,
		"action_owner": _current_action_owner,
		"module_certificate_kind": _active_module_certificate_kind,
		"match_agenda": _match_agenda.duplicate(true),
		"execution_cursor": _execution_cursor.snapshot(),
	}
	return plan


func pick_interaction_items(items: Array, step: Dictionary, context: Dictionary = {}) -> Array:
	var typed_context := context.duplicate(true)
	# Interaction modules receive only the already-filtered observation/facts.
	# They never receive raw GameState, PlayerState, deck arrays, or hidden zones.
	typed_context["v18cpg_facts"] = _last_facts.duplicate(true)
	typed_context["v18cpg_observation"] = _last_observation.duplicate(true)
	typed_context["v18cpg_semantic_manifest"] = _semantic_manifest.duplicate(true)
	var interaction_route_id := _interaction_route_context()
	var rule_picks := _rules_fallback.pick_interaction_items(items, step, context)
	var exact_gardevoir_stage := _active_profiled_gardevoir_ko_interaction_stage(step)
	if exact_gardevoir_stage == "":
		exact_gardevoir_stage = _cached_profiled_gardevoir_interaction_stage(step)
	if exact_gardevoir_stage != "":
		typed_context["v18cpg_profiled_gardevoir_stage"] = exact_gardevoir_stage
	if OS.has_environment("V18CPG_INTERACTION_DIAGNOSTICS"):
		print("V18CPG_INTERACTION_DIAGNOSTIC " + JSON.stringify({
			"turn": _current_turn,
			"action_owner": _current_action_owner,
			"route_id": interaction_route_id,
			"certificate_kind": _active_module_certificate_kind,
			"profiled_gardevoir_stage": exact_gardevoir_stage,
			"preferred_action_id": _preferred_action_id,
			"preferred_candidate_id": _preferred_candidate_id,
			"step": step.duplicate(true),
			"context_keys": context.keys(),
			"items": _compact_interaction_debug_items(items),
			"rule_picks": _compact_interaction_debug_items(rule_picks),
		}))
	var module_owned := _current_action_owner in [
		"model_selected_local_route",
		"model_synthesized_route",
		"policy_graph_branch",
		"module_verified_upgrade",
	]
	if _runtime_configured and (module_owned or _current_action_owner == "local_gate"):
		var basic_search_override := _noctowl_search.pick_verified_basic_search_override(
			items,
			step,
			rule_picks,
			typed_context,
			_profile
		)
		if bool(basic_search_override.get("handled", false)):
			_audit.record({
				"turn_id": _current_turn,
				"policy_id": str(_lifecycle.get("policy_id", "")),
				"revision_id": str(_lifecycle.get("revision_id", "")),
				"node_id": _policy_graph.current_node_id(),
				"route_id": interaction_route_id,
				"candidate_id": _preferred_candidate_id,
				"deck_id": int(_profile.get("deck_id", 0)),
				"strategy_id": get_strategy_id(),
				"event_type": "module_verified_interaction_override",
				"action_owner": "module_verified_upgrade",
				"fallback_reason": "",
				"certificate_kind": str(basic_search_override.get("certificate_kind", "")),
			})
			return basic_search_override.get("items", []) as Array
	if _runtime_configured and exact_gardevoir_stage != "":
		# The route certificate intentionally expires after every engine action.
		# The current frontier annotation and the capability registry both
		# revalidate the exact public checkpoint, so the interaction target does
		# not depend on carrying a stale certificate across reobservation.
		var exact_gardevoir_certificate := "profiled_visible_engine_hold"
		var exact_gardevoir_override := _capability_registry.pick_verified_interaction_override(
			items,
			step,
			rule_picks,
			typed_context,
			_profile,
			exact_gardevoir_certificate
		)
		if bool(exact_gardevoir_override.get("handled", false)) \
				and str(exact_gardevoir_override.get("stage", "")) == exact_gardevoir_stage:
			_profiled_gardevoir_interaction_ticket = {
				"turn": _current_turn,
				"action_id": _preferred_action_id,
				"candidate_id": _preferred_candidate_id,
				"stage": exact_gardevoir_stage,
			}
			_audit.record({
				"turn_id": _current_turn,
				"policy_id": str(_lifecycle.get("policy_id", "")),
				"revision_id": str(_lifecycle.get("revision_id", "")),
				"node_id": _policy_graph.current_node_id(),
				"route_id": interaction_route_id,
				"candidate_id": _preferred_candidate_id,
				"deck_id": int(_profile.get("deck_id", 0)),
				"strategy_id": get_strategy_id(),
				"event_type": "module_verified_interaction_override",
				"action_owner": "module_verified_upgrade",
				"fallback_reason": "",
				"certificate_kind": str(exact_gardevoir_override.get("certificate_kind", "")),
			})
			return exact_gardevoir_override.get("items", []) as Array
	if _runtime_configured and module_owned \
			and _active_module_certificate_kind != "" \
			and _active_module_certificate_kind != "profiled_visible_engine_hold":
		# The selected public certificate, not the model response, owns this
		# interaction. The module must revalidate the current filtered observation
		# and return exactly one legal item; otherwise Rule keeps full ownership.
		var exact_module_override := _capability_registry.pick_verified_interaction_override(
			items,
			step,
			rule_picks,
			typed_context,
			_profile,
			_active_module_certificate_kind
		)
		if bool(exact_module_override.get("handled", false)):
			_audit.record({
				"turn_id": _current_turn,
				"policy_id": str(_lifecycle.get("policy_id", "")),
				"revision_id": str(_lifecycle.get("revision_id", "")),
				"node_id": _policy_graph.current_node_id(),
				"route_id": interaction_route_id,
				"candidate_id": _preferred_candidate_id,
				"deck_id": int(_profile.get("deck_id", 0)),
				"strategy_id": get_strategy_id(),
				"event_type": "module_verified_interaction_override",
				"action_owner": "module_verified_upgrade",
				"fallback_reason": "",
				"certificate_kind": str(exact_module_override.get("certificate_kind", "")),
			})
			return exact_module_override.get("items", []) as Array
	if _runtime_configured and module_owned and _noctowl_search.handles_step(step, typed_context):
		var picked := _noctowl_search.pick_pair(
			items,
			step,
			typed_context,
			_profile,
			_semantic_manifest,
			interaction_route_id
		)
		if _noctowl_search.verify_pair_override(
			picked,
			rule_picks,
			step,
			typed_context,
			_profile,
			_semantic_manifest,
			interaction_route_id
		):
			return picked
	# Generic model policies remain proposals until a capability module can
	# independently prove their advantage over the Rule selection.  Scoring a
	# proposal with its own model-authored rank keys is not a safety certificate.
	return rule_picks


func _active_profiled_gardevoir_ko_interaction_stage(step: Dictionary) -> String:
	if str(step.get("id", "")).strip_edges().to_lower() != "embrace_target" \
			or int(step.get("min_select", 1)) != 1 \
			or int(step.get("max_select", 0)) != 1:
		return ""
	for candidate: Dictionary in _last_frontier:
		if str(candidate.get("candidate_id", "")) != _preferred_candidate_id \
				and str(candidate.get("safe_prefix_action_id", "")) != _preferred_action_id:
			continue
		var annotations: Dictionary = candidate.get("module_annotations", {}) \
			if candidate.get("module_annotations", {}) is Dictionary else {}
		var gardevoir: Dictionary = annotations.get("gardevoir_embrace", {}) \
			if annotations.get("gardevoir_embrace", {}) is Dictionary else {}
		var suffix: Dictionary = gardevoir.get("profiled_active_gardevoir_ko_suffix", {}) \
			if gardevoir.get("profiled_active_gardevoir_ko_suffix", {}) is Dictionary else {}
		var stage := str(suffix.get("stage", ""))
		if bool(suffix.get("advances_profiled_active_gardevoir_ko_suffix", false)) \
				and str(suffix.get("certificate_kind", "")) == "profiled_visible_engine_hold" \
				and str(suffix.get("interaction_certificate_kind", "")) \
					== "public_profiled_active_gardevoir_ko_suffix_target" \
				and str(suffix.get("observation_hash_provenance", "")) != "" \
				and str(suffix.get("observation_hash_provenance", "")) \
					== str(_last_observation.get("observation_hash", "")) \
				and stage in ["first_embrace_to_active", "second_embrace_to_active"]:
			return stage
	return ""


func _cached_profiled_gardevoir_interaction_stage(step: Dictionary) -> String:
	if str(step.get("id", "")).strip_edges().to_lower() != "embrace_target" \
			or int(step.get("min_select", 1)) != 1 \
			or int(step.get("max_select", 0)) != 1 \
			or int(_profiled_gardevoir_interaction_ticket.get("turn", -2)) != _current_turn \
			or str(_profiled_gardevoir_interaction_ticket.get("action_id", "")) != _preferred_action_id \
			or str(_profiled_gardevoir_interaction_ticket.get("candidate_id", "")) != _preferred_candidate_id:
		return ""
	var stage := str(_profiled_gardevoir_interaction_ticket.get("stage", ""))
	return stage if stage in ["first_embrace_to_active", "second_embrace_to_active"] else ""


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	if _runtime_configured:
		var exact_gardevoir_stage := _active_profiled_gardevoir_ko_interaction_stage(step)
		if exact_gardevoir_stage == "":
			exact_gardevoir_stage = _cached_profiled_gardevoir_interaction_stage(step)
		if exact_gardevoir_stage != "":
			var exact_context := {
				"v18cpg_observation": _last_observation.duplicate(true),
				"v18cpg_facts": _last_facts.duplicate(true),
				"v18cpg_semantic_manifest": _semantic_manifest.duplicate(true),
				"v18cpg_profiled_gardevoir_stage": exact_gardevoir_stage,
			}
			var exact_score: Variant = _capability_registry.verified_interaction_target_score(
				item,
				step,
				exact_context,
				_profile,
				"profiled_visible_engine_hold"
			)
			if exact_score != null:
				return float(exact_score)
	if _runtime_configured and _active_module_certificate_kind != "":
		var typed_context := {
			"v18cpg_observation": _last_observation.duplicate(true),
			"v18cpg_facts": _last_facts.duplicate(true),
		}
		var module_score: Variant = _capability_registry.verified_interaction_target_score(
			item,
			step,
			typed_context,
			_profile,
			_active_module_certificate_kind
		)
		if module_score != null:
			return float(module_score)
	if _runtime_configured \
			and _current_route_id == "route:accelerate" \
			and _active_module_certificate_kind == "banked_energy_handoff":
		var verified_score: Variant = _noctowl_search.verified_energy_handoff_target_score(
			item,
			step,
			_profile
		)
		if verified_score != null:
			return float(verified_score)
	return _rules_fallback.score_interaction_target(item, step, context)


func score_handoff_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	# A forced replacement is an unconditional public-state boundary.  The
	# previous Active's route, cursor, and interaction certificate cannot remain
	# authoritative while the host asks Rule AI which Bench Pokemon to promote.
	# Keep the target score byte-for-byte Rule-owned, but invalidate volatile CPG
	# execution state on the first send-out score in the window.  This is
	# deliberately narrower than retreat/self-switch target scoring, whose route
	# may still have a verified same-turn continuation.
	if str(step.get("id", "")) == "send_out":
		var had_stale_policy := _policy_graph.is_active() \
			or _execution_cursor.is_active() \
			or _preferred_action_id != "" \
			or _preferred_candidate_id != "" \
			or _active_module_certificate_kind != ""
		_clear_route("rules_fallback")
		_unconsumed_action_result.clear()
		if had_stale_policy:
			_audit.record({
				"turn_id": _current_turn,
				"policy_id": str(_lifecycle.get("policy_id", "")),
				"revision_id": str(_lifecycle.get("revision_id", "")),
				"node_id": "",
				"route_id": "",
				"candidate_id": "",
				"deck_id": int(_profile.get("deck_id", 0)),
				"strategy_id": get_strategy_id(),
				"event_type": "forced_sendout_policy_invalidated",
				"action_owner": "rules_fallback",
				"fallback_reason": "public_active_changed",
			})
	return _rules_fallback.score_handoff_target(item, step, context)


func should_preserve_empty_interaction_selection(step: Dictionary, _context: Dictionary = {}) -> bool:
	return false


func plan_opening_setup(player: PlayerState) -> Dictionary:
	return _rules_fallback.plan_opening_setup(player)


func get_intent_planner_profile() -> Dictionary:
	return _rules_fallback.get_intent_planner_profile()


func log_runtime_action_result(
	action: Dictionary,
	success: bool,
	_game_state: GameState,
	_player_index: int,
	audit_turn: int
) -> void:
	_profiled_gardevoir_interaction_ticket.clear()
	var stable_action_id := _observation_gateway.stable_action_id(action)
	if not _profiled_gardevoir_suffix_ticket.is_empty():
		var expected_action_id := str(_profiled_gardevoir_suffix_ticket.get("action_id", ""))
		var current_stage := str(_profiled_gardevoir_suffix_ticket.get("stage", ""))
		if not success or stable_action_id != expected_action_id \
				or current_stage == "active_gardevoir_190_ko":
			_profiled_gardevoir_suffix_ticket.clear()
	var action_card_uid := ""
	var action_card: Variant = action.get("card", null)
	if action_card is CardInstance and (action_card as CardInstance).card_data != null:
		action_card_uid = (action_card as CardInstance).card_data.get_uid().strip_edges().to_upper()
	var public_action_ref := _observation_gateway.action_ref(action)
	_execution_cursor.on_action_result(stable_action_id, success)
	_unconsumed_action_result = {
		"action_id": stable_action_id,
		"action_kind": str(action.get("kind", "")),
		"action_card_uid": action_card_uid,
		"success": success,
		"route_id": _current_route_id,
		"candidate_id": _preferred_candidate_id,
		"owner": _current_action_owner,
		"target_slot_id": str(public_action_ref.get("target", "")),
	}
	_audit.record({
		"turn_id": audit_turn,
		"policy_id": str(_lifecycle.get("policy_id", "")),
		"revision_id": str(_lifecycle.get("revision_id", "")),
		"node_id": _policy_graph.current_node_id(),
		"route_id": _current_route_id,
		"candidate_id": _preferred_candidate_id,
		"deck_id": int(_profile.get("deck_id", 0)),
		"strategy_id": get_strategy_id(),
		"event_type": "action_result",
		"action_id": stable_action_id,
		"action_kind": str(action.get("kind", "")),
		"action_card_uid": action_card_uid,
		"target_slot_id": str(public_action_ref.get("target", "")),
		"action_owner": _current_action_owner,
		"module_certificate_kind": _active_module_certificate_kind,
		"success": success,
	})


func get_audit_summary() -> Dictionary:
	var summary := _audit.summary()
	summary["branch_hits"] = _branch_hits
	summary["uncovered_events"] = _uncovered_events
	summary["last_request_metrics"] = _last_request_metrics.duplicate(true)
	return summary


func get_policy_snapshot() -> Dictionary:
	return _policy_graph.snapshot()


func stable_action_id_for_host(action: Dictionary) -> String:
	return _observation_gateway.stable_action_id(action)


func _annotate_candidate_pool_with_engine_rule_floor(
	candidate_pool: Array[Dictionary],
	action_id: String,
	observation: Dictionary,
	facts: Dictionary
) -> Array[Dictionary]:
	var bound := _bind_engine_rule_floor(candidate_pool, action_id)
	# Capability modules annotate the next public state before the material-delta
	# path consumes `_unconsumed_action_result`.  Give them a private observation
	# copy carrying that already-audited result, so a one-action certificate can
	# bind its reobserve checkpoint without mutating the model observation or
	# collapsing the completed action and its suffix into one atomic decision.
	var capability_observation := observation.duplicate(true)
	if not _unconsumed_action_result.is_empty():
		capability_observation["event"] = {
			"kind": "action_resolved",
			"success": bool(_unconsumed_action_result.get("success", false)),
			"action_id": str(_unconsumed_action_result.get("action_id", "")),
			"action_kind": str(_unconsumed_action_result.get("action_kind", "")),
			"route_id": str(_unconsumed_action_result.get("route_id", "")),
			"candidate_id": str(_unconsumed_action_result.get("candidate_id", "")),
			"owner": str(_unconsumed_action_result.get("owner", "")),
			"target_slot_id": str(_unconsumed_action_result.get("target_slot_id", "")),
		}
	return _capability_registry.annotate_frontier(
		bound,
		capability_observation,
		facts,
		_profile,
		_semantic_manifest
	)


func _bind_engine_rule_floor(frontier: Array[Dictionary], action_id: String) -> Array[Dictionary]:
	var result := frontier.duplicate(true)
	if action_id == "":
		return result
	var certified_index := -1
	for index: int in result.size():
		result[index]["engine_rule_floor_exact"] = false
		if str(result[index].get("safe_prefix_action_id", "")) == action_id:
			certified_index = index
	if certified_index < 0:
		return result
	var certified: Dictionary = result[certified_index]
	certified["engine_rule_floor_exact"] = true
	result.remove_at(certified_index)
	result.insert(0, certified)
	return result


func install_policy_response_for_test(
	response: Dictionary,
	frontier: Array[Dictionary],
	facts: Dictionary = {}
) -> Dictionary:
	var validation := _policy_validator.validate_response(
		response,
		REGISTERED_ROUTE_IDS,
		int(_profile.get("max_policy_nodes", 8)),
		_candidate_ids(frontier),
		false
	)
	if not bool(validation.get("valid", false)):
		return validation
	var policy: Dictionary = validation.get("policy", {})
	var binding := _policy_validator.bind_root_to_frontier(policy, frontier)
	if not bool(binding.get("valid", false)):
		return binding
	policy = binding.get("policy", {})
	var root_ref: Dictionary = binding.get("root_ref", {})
	var root_route := str(root_ref.get("route_id", ""))
	if root_route not in _route_ids(frontier):
		return {"valid": false, "reason": "root_route_unavailable"}
	var binding_validation := _validate_root_route_ref(root_ref, frontier)
	if not bool(binding_validation.get("valid", false)):
		return binding_validation
	var progress_validation := _validate_candidate_bound_policy_progress(policy, root_ref, frontier, facts)
	if not bool(progress_validation.get("valid", false)):
		return progress_validation
	var origin := "model_synthesized_route" if str(root_ref.get("mode", "")) == "propose_typed_route" else "model_selected_local_route"
	_policy_graph.install(policy, origin)
	_execution_cursor.install(root_ref, _lifecycle, int(_last_observation.get("observation_version", 0)), origin)
	_select_route(root_route, frontier, origin, str(root_ref.get("candidate_id", root_ref.get("first_candidate_id", ""))))
	return {"valid": true}


func _on_policy_response(request_id: String, response: Dictionary, metrics: Dictionary) -> void:
	if request_id == "" or request_id != _pending_request_id:
		return
	var context := _pending_context.duplicate(true)
	_audit.record_payload({
		"turn_id": _current_turn,
		"policy_id": str(_lifecycle.get("policy_id", "")),
		"decision_window_id": str(_lifecycle.get("decision_window_id", "")),
		"request_id": request_id,
		"deck_id": int(_profile.get("deck_id", 0)),
		"strategy_id": get_strategy_id(),
		"event_type": "model_response_payload",
		"response": response,
		"metrics": metrics,
	})
	_pending_request_id = ""
	_pending_context.clear()
	_pending_request_started_msec = 0
	_pending_request_visible_budget_ms = 0
	_last_request_metrics = metrics.duplicate(true)
	var visible_wait := maxf(0.0, float(metrics.get("visible_wait_ms", 0.0)))
	_turn_visible_wait_ms += int(ceil(visible_wait))
	_request_wait_samples_ms.append(visible_wait)
	var stale := int(context.get("observation_version", -1)) != int(_last_observation.get("observation_version", -2)) \
		or str(context.get("observation_hash", "")) != str(_last_observation.get("observation_hash", ""))
	var frontier: Array[Dictionary] = []
	for raw_route: Variant in context.get("frontier", []):
		if raw_route is Dictionary:
			frontier.append(raw_route as Dictionary)
	if stale:
		_install_local_policy(frontier, "deadline_fallback")
		_record_policy_response(false, "stale_response", metrics)
		return
	var validation := _policy_validator.validate_response(
		response,
		REGISTERED_ROUTE_IDS,
		int(_profile.get("max_policy_nodes", 8)),
		context.get("allowed_candidate_ids", []) if context.get("allowed_candidate_ids", []) is Array else [],
		true
	)
	if not bool(validation.get("valid", false)):
		_install_local_policy(frontier, "schema_fallback")
		_record_policy_response(false, str(validation.get("reason", "schema_error")), metrics)
		return
	var policy: Dictionary = validation.get("policy", {})
	var binding := _policy_validator.bind_root_to_frontier(policy, frontier)
	if not bool(binding.get("valid", false)):
		_install_local_policy(frontier, "schema_fallback")
		_record_policy_response(false, str(binding.get("reason", "candidate_binding_failed")), metrics)
		return
	policy = binding.get("policy", {})
	var root_ref: Dictionary = binding.get("root_ref", {})
	var root_route := str(root_ref.get("route_id", ""))
	var root_candidate := str(root_ref.get("candidate_id", root_ref.get("first_candidate_id", "")))
	if root_route not in context.get("available_route_ids", []):
		_install_local_policy(frontier, "schema_fallback")
		_record_policy_response(false, "root_route_unavailable", metrics)
		return
	var binding_validation := _validate_root_route_ref(root_ref, frontier)
	if not bool(binding_validation.get("valid", false)):
		_install_rejected_model_fallback(frontier)
		_record_policy_response(false, str(binding_validation.get("reason", "candidate_binding_failed")), metrics, "route_validation")
		return
	var progress_validation := _validate_candidate_bound_policy_progress(
		policy,
		root_ref,
		frontier,
		context.get("facts", {}) if context.get("facts", {}) is Dictionary else {}
	)
	if not bool(progress_validation.get("valid", false)):
		_install_rejected_model_fallback(frontier)
		_record_policy_response(false, str(progress_validation.get("reason", "policy_progress_unproven")), metrics, "route_validation")
		return
	var route_safety := _validate_model_route_safety(
		root_route,
		frontier,
		context.get("facts", {}) if context.get("facts", {}) is Dictionary else {},
		root_candidate
	)
	var graph_only_policy := _validate_graph_only_certificate_policy(
		policy, root_ref, route_safety
	)
	if not bool(graph_only_policy.get("valid", false)):
		_install_rejected_model_fallback(frontier)
		_record_policy_response(
			false,
			str(graph_only_policy.get("reason", "graph_only_policy_invalid")),
			metrics,
			"route_validation"
		)
		return
	var selected_candidate := _route_search.find_candidate(frontier, root_candidate)
	var shadow_exact_rule_root := _should_shadow_exact_rule_root(route_safety)
	var defer_root_to_rule := shadow_exact_rule_root or not bool(route_safety.get("valid", false)) \
		and str(route_safety.get("reason", "")) in [
			"ambiguous_rule_tie_without_verified_advantage",
			"same_route_switch_without_verified_advantage",
		] \
		and _can_defer_ambiguous_root_to_rule(selected_candidate, frontier)
	if not bool(route_safety.get("valid", false)) and not defer_root_to_rule:
		_install_rejected_model_fallback(frontier)
		_record_policy_response(false, str(route_safety.get("reason", "route_validation_failed")), metrics, "route_validation")
		return
	if _strict_certificate_blocks_route(route_safety, defer_root_to_rule):
		_install_rejected_model_fallback(frontier)
		_record_policy_response(false, "model_shadow_only_without_execution_certificate", metrics, "route_validation")
		return
	var origin := "model_shadow_rule_root" if defer_root_to_rule \
		else "model_synthesized_route" if str(root_ref.get("mode", "")) == "propose_typed_route" \
		else "model_selected_local_route"
	_policy_graph.install(policy, origin)
	_revision_serial += 1
	_lifecycle["revision_id"] = "%s:r%d" % [str(_lifecycle.get("policy_id", "policy")), _revision_serial]
	if defer_root_to_rule:
		_execution_cursor.clear()
		_select_route(
			str(frontier[0].get("route_id", "")),
			frontier,
			origin,
			str(frontier[0].get("candidate_id", ""))
		)
	else:
		_execution_cursor.install(
			root_ref,
			_lifecycle,
			int(_last_observation.get("observation_version", 0)),
			origin
		)
		_select_route(root_route, frontier, origin, root_candidate)
	var agenda_patch: Variant = response.get("agenda_patch", {})
	if agenda_patch is Dictionary:
		_apply_agenda_patch(agenda_patch as Dictionary)
	_record_policy_response(
		true,
		"exact_rule_root_shadowed" if shadow_exact_rule_root \
			else "root_deferred_to_rule" if defer_root_to_rule else "",
		metrics,
		"",
		{
			"canonicalized_unreachable_nodes": int(
				validation.get("canonicalized_unreachable_nodes", 0)
			),
		}
	)


func _should_shadow_exact_rule_root(route_safety: Dictionary) -> bool:
	return bool(route_safety.get("valid", false)) \
		and str(route_safety.get("reason", "")) == "matches_rules_floor"


func _has_model_execution_certificate(route_safety: Dictionary) -> bool:
	return bool(route_safety.get("valid", false)) \
		and str(route_safety.get("reason", "")) in [
			"module_verified_advantage",
			"deterministic_win_now",
			"deterministic_prize_gain",
		]


func _strict_certificate_blocks_route(route_safety: Dictionary, defer_root_to_rule: bool) -> bool:
	var profile_safety: Dictionary = _profile.get("safety", {}) \
		if _profile.get("safety", {}) is Dictionary else {}
	return bool(profile_safety.get("require_model_execution_certificate", false)) \
		and not defer_root_to_rule \
		and not _has_model_execution_certificate(route_safety)


func _validate_graph_only_certificate_policy(
	policy: Dictionary,
	root_ref: Dictionary,
	route_safety: Dictionary
) -> Dictionary:
	var advantage: Dictionary = route_safety.get("advantage", {}) \
		if route_safety.get("advantage", {}) is Dictionary else {}
	if str(advantage.get("certificate_kind", "")) != "public_attackless_duplicate_gust_hold":
		return {"valid": true, "reason": ""}
	if not bool(route_safety.get("valid", false)) \
			or not bool(advantage.get("requires_model_graph", false)) \
			or not bool(advantage.get("graph_only", false)):
		return {"valid": false, "reason": "duplicate_gust_graph_certificate_invalid"}
	var held_instance_id := int(advantage.get("held_card_instance_id", -1))
	if held_instance_id < 0 \
			or str(root_ref.get("mode", "")) != "select_candidate" \
			or str(root_ref.get("route_id", "")) != "route:develop" \
			or str(root_ref.get("candidate_id", "")) \
				!= str(advantage.get("selected_candidate_id", "")):
		return {"valid": false, "reason": "duplicate_gust_graph_root_mismatch"}

	var reservations: Array = policy.get("reservations", []) \
		if policy.get("reservations", []) is Array else []
	if reservations.size() != 1 or not (reservations[0] is Dictionary):
		return {"valid": false, "reason": "duplicate_gust_reservation_missing"}
	var reservation: Dictionary = reservations[0] as Dictionary
	if reservation.size() != 3 \
			or str(reservation.get("resource", "")) != "card_instance:%d" % held_instance_id \
			or int(reservation.get("count", 0)) != 1 \
			or str(reservation.get("until", "")) != "turn_end":
		return {"valid": false, "reason": "duplicate_gust_reservation_mismatch"}
	if not (policy.get("interaction_policy_refs", {}) is Dictionary) \
			or not (policy.get("interaction_policy_refs", {}) as Dictionary).is_empty() \
			or not (policy.get("interaction_policies", []) is Array) \
			or not (policy.get("interaction_policies", []) as Array).is_empty():
		return {"valid": false, "reason": "duplicate_gust_interaction_owner_mismatch"}

	var nodes: Array = policy.get("nodes", []) if policy.get("nodes", []) is Array else []
	if nodes.size() != 3:
		return {"valid": false, "reason": "duplicate_gust_graph_node_count"}
	var node_by_id: Dictionary = {}
	for raw_node: Variant in nodes:
		if not (raw_node is Dictionary):
			return {"valid": false, "reason": "duplicate_gust_graph_node_shape"}
		var node: Dictionary = raw_node as Dictionary
		var node_id := str(node.get("node_id", ""))
		if node_id == "" or node_by_id.has(node_id):
			return {"valid": false, "reason": "duplicate_gust_graph_node_identity"}
		var route_ref: Dictionary = node.get("route_ref", {}) \
			if node.get("route_ref", {}) is Dictionary else {}
		if str(route_ref.get("route_id", "")) == "route:gust":
			return {"valid": false, "reason": "duplicate_gust_reserved_card_reused"}
		node_by_id[node_id] = node

	var root_id := str(policy.get("root_node_id", ""))
	var root: Dictionary = node_by_id.get(root_id, {}) \
		if node_by_id.get(root_id, {}) is Dictionary else {}
	var canonical_root_ref: Dictionary = root.get("route_ref", {}) \
		if root.get("route_ref", {}) is Dictionary else {}
	var checkpoint_id := str(root.get("next_node_id", ""))
	var checkpoint: Dictionary = node_by_id.get(checkpoint_id, {}) \
		if node_by_id.get(checkpoint_id, {}) is Dictionary else {}
	if str(root.get("kind", "")) != "route" \
			or canonical_root_ref != root_ref \
			or str(checkpoint.get("kind", "")) != "checkpoint":
		return {"valid": false, "reason": "duplicate_gust_graph_root_shape"}
	var branches: Array = checkpoint.get("branches", []) \
		if checkpoint.get("branches", []) is Array else []
	if branches.size() != 1 or not (branches[0] is Dictionary) \
			or str(checkpoint.get("otherwise", "")) != "replan":
		return {"valid": false, "reason": "duplicate_gust_graph_checkpoint_shape"}
	var branch: Dictionary = branches[0] as Dictionary
	var guards: Array = branch.get("when_all", []) if branch.get("when_all", []) is Array else []
	if guards != [{"fact": "attack.ready", "op": "==", "value": false}]:
		return {"valid": false, "reason": "duplicate_gust_graph_guard_mismatch"}
	var end_node_id := str(branch.get("next_node_id", ""))
	var end_node: Dictionary = node_by_id.get(end_node_id, {}) \
		if node_by_id.get(end_node_id, {}) is Dictionary else {}
	var end_ref: Dictionary = end_node.get("route_ref", {}) \
		if end_node.get("route_ref", {}) is Dictionary else {}
	if str(end_node.get("kind", "")) != "route" \
			or end_node.has("next_node_id") \
			or end_ref != {"mode": "follow_route", "route_id": "route:end_turn"}:
		return {"valid": false, "reason": "duplicate_gust_graph_terminal_route_mismatch"}
	return {"valid": true, "reason": ""}


func _begin_turn(turn_number: int, event_context: Dictionary) -> void:
	_current_turn = turn_number
	_revision_serial = 1
	_request_serial = 0
	_turn_visible_wait_ms = 0
	_turn_model_requests = 0
	var run_id := str(event_context.get("run_id", "v18cpg"))
	var match_id := str(event_context.get("match_id", "match"))
	_lifecycle = ContractsScript.make_lifecycle(run_id, match_id, turn_number, _revision_serial)
	_policy_graph.clear()
	_execution_cursor.clear()
	_preferred_action_id = ""
	_preferred_candidate_id = ""
	_current_route_id = ""
	_current_action_owner = "rules_fallback"
	_route_selection_bonus = ROUTE_SELECTION_BONUS
	_active_module_certificate_kind = ""
	_profiled_gardevoir_interaction_ticket.clear()
	_profiled_gardevoir_suffix_ticket.clear()
	_pending_request_id = ""
	_pending_context.clear()
	_pending_request_started_msec = 0
	_pending_request_visible_budget_ms = 0
	_handled_delta_hashes.clear()
	_unconsumed_action_result.clear()
	_match_agenda = {
		"victory_mode": str(_profile.get("victory_mode", "prize_race")),
		"prize_path": [],
		"attacker_chain": [],
		"protected_resources": (_profile.get("protected_roles", []) as Array).duplicate(true) if _profile.get("protected_roles", []) is Array else [],
		"opponent_threat_posture": [],
		"risk_posture": str(_profile.get("risk_posture", "balanced")),
		"expires_when": ["turn_end", "major_ko", "engine_lost"],
	}


func _build_request_envelope(
	observation: Dictionary,
	facts: Dictionary,
	frontier: Array[Dictionary],
	material_delta: Dictionary = {}
) -> Dictionary:
	var typed_policy := _profile_policy.sanitize(_profile, REGISTERED_ROUTE_IDS)
	var compact_frontier := _compact_frontier_for_model(frontier)
	var factored_frontier := _factor_common_capability_context(compact_frontier)
	var profile_summary := _profile_summary_for_model(typed_policy)
	return {
		"schema_version": ContractsScript.SCHEMA_VERSION,
		"limits": {
			"max_policy_nodes": mini(
				maxi(int(_profile.get("max_policy_nodes", 8)), 1),
				ContractsScript.HARD_MAX_POLICY_NODES
			),
		},
		"lifecycle": _lifecycle.duplicate(true),
		"profile": profile_summary,
		"observation": _compact_observation_for_model(observation),
		"belief": _belief.snapshot(),
		"match_agenda": _match_agenda.duplicate(true),
		"facts": facts.duplicate(true),
		"resource_ledger": _compact_resource_ledger_for_model(
			_resource_ledger.build(observation, _semantic_manifest, _profile, _belief.snapshot())
		),
		"prize_graph": _compact_prize_graph_for_model(_prize_graph.solve(observation, facts)),
		"threat_response": _threat_response.solve(observation),
		"capability_context": factored_frontier.get("capability_context", {}),
		"frontier": factored_frontier.get("frontier", []),
		"current_root_route_ids": _route_ids(frontier),
		"current_root_candidate_bindings": _candidate_bindings(frontier),
		"allowed_follow_route_ids": REGISTERED_ROUTE_IDS.duplicate(),
		"allowed_candidate_ids": _candidate_ids(frontier),
		"allowed_fact_paths": ContractsScript.REGISTERED_FACT_PATHS.duplicate(),
		"allowed_guard_operators": ContractsScript.GUARD_OPERATORS.duplicate(),
		"current_policy_cursor": {
			"graph": _policy_graph.snapshot(),
			"execution": _execution_cursor.snapshot(),
		},
		"material_delta": material_delta.duplicate(true),
	}


func _profile_summary_for_model(typed_policy: Dictionary) -> Dictionary:
	# Local engine proof parameters deliberately stay outside the model-facing
	# profile.  Adding a deterministic certificate must not perturb an otherwise
	# identical prompt or change early-turn model choices.
	return {
		"deck_id": int(_profile.get("deck_id", 0)),
		"display_name": str(_profile.get("display_name", "")),
		"primary_module": str(_profile.get("primary_module", "")),
		"modules": _profile.get("modules", []),
		"risk_posture": str(_profile.get("risk_posture", "balanced")),
		"switch_margin": float(_profile.get("switch_margin", 0.0)),
		"protected_roles": _profile.get("protected_roles", []),
		"strategic_priorities": typed_policy.get("strategic_priorities", []),
		"route_preferences": typed_policy.get("route_preferences", {}),
		"safety": typed_policy.get("safety", {}),
		"module_parameters": _profile.get("module_parameters", {}),
	}


func _compact_frontier_for_model(frontier: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var certified_floor_id := ""
	for candidate: Dictionary in frontier:
		if bool(candidate.get("engine_rule_floor_exact", false)):
			certified_floor_id = str(candidate.get("candidate_id", ""))
			break
	var rule_floor_candidate_id := certified_floor_id \
		if certified_floor_id != "" else str(frontier[0].get("candidate_id", "")) if not frontier.is_empty() else ""
	var rule_floor_score := float(frontier[0].get("base_score", 0.0)) if not frontier.is_empty() else 0.0
	var ambiguous_floor_tie := false
	if certified_floor_id == "":
		for candidate: Dictionary in frontier:
			if str(candidate.get("candidate_id", "")) != rule_floor_candidate_id \
					and is_equal_approx(float(candidate.get("base_score", 0.0)), rule_floor_score):
				ambiguous_floor_tie = true
				break
	for candidate: Dictionary in frontier:
		var compact_candidate := {
			"candidate_id": str(candidate.get("candidate_id", "")),
			"route_id": str(candidate.get("route_id", "")),
			"action_kind": str(candidate.get("action_kind", "")),
			"action_ref": _compact_action_ref_for_model(candidate.get("action_ref", {})),
			"checkpoint_after": str(candidate.get("checkpoint_after", "")),
			"base_score": float(candidate.get("base_score", 0.0)),
			"outcome": _compact_outcome_for_model(candidate.get("outcome", {})),
			"module_annotations": _compact_module_annotations(candidate.get("module_annotations", {})),
		}
		if str(candidate.get("candidate_id", "")) == rule_floor_candidate_id and not ambiguous_floor_tie:
			compact_candidate["rule_floor_exact"] = true
		if ambiguous_floor_tie and is_equal_approx(float(candidate.get("base_score", 0.0)), rule_floor_score):
			compact_candidate["rule_tie_ambiguous"] = true
		var roles: Variant = candidate.get("action_semantic_roles", [])
		if roles is Array and not (roles as Array).is_empty():
			compact_candidate["action_semantic_roles"] = (roles as Array).duplicate()
		for optional_key: String in ["dependencies", "reservations"]:
			var optional_value: Variant = candidate.get(optional_key, [])
			if optional_value is Array and not (optional_value as Array).is_empty():
				compact_candidate[optional_key] = (optional_value as Array).duplicate(true)
		if (compact_candidate.get("module_annotations", {}) as Dictionary).is_empty():
			compact_candidate.erase("module_annotations")
		result.append(compact_candidate)
	return result


func _compact_action_ref_for_model(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return {}
	var source: Dictionary = value
	var result: Dictionary = {}
	for key: String in ["attack_index", "ability_index", "projected_damage", "projected_knockout", "source", "target"]:
		if source.has(key):
			result[key] = source.get(key)
	if bool(source.get("requires_interaction", false)):
		result["requires_interaction"] = true
	for key: String in ["card", "source_card"]:
		var card := _compact_action_card_ref(source.get(key, {}))
		if not card.is_empty():
			result[key] = card
	return result


func _compact_action_card_ref(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return {}
	var source: Dictionary = value
	var result: Dictionary = {}
	for key: String in ["uid", "name", "type", "energy_type", "energy_provides"]:
		var text := str(source.get(key, ""))
		if text != "":
			result[key] = text
	return result


func _compact_outcome_for_model(value: Variant) -> Dictionary:
	var source: Dictionary = value if value is Dictionary else {}
	var result: Dictionary = {}
	for key: String in ["win_now", "attack_ready", "terminal"]:
		if bool(source.get(key, false)):
			result[key] = true
	for key: String in ["prizes_now", "estimated_damage"]:
		var amount := int(source.get(key, 0))
		if amount != 0:
			result[key] = amount
	for key: String in [
		"information_gain", "expected_route_improvement", "resource_commitment",
		"board_commitment", "board_development", "future_flexibility", "uncertainty",
	]:
		var number := float(source.get(key, 0.0))
		if not is_zero_approx(number):
			result[key] = number
	return result


func _compact_module_annotations(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return {}
	# Preserve every non-default public module fact.  An allowlist silently turns
	# newly added candidate-specific semantics into an apparent false/zero on the
	# model wire.  Only remove fields that are provably duplicated by the outer
	# module/candidate envelope; common remaining values are hoisted afterward.
	var duplicated_keys: Array[String] = ["module", "route_id", "category", "public_snapshot"]
	var result: Dictionary = {}
	for raw_module_id: Variant in (value as Dictionary).keys():
		var raw_module: Variant = (value as Dictionary).get(raw_module_id, {})
		if not (raw_module is Dictionary):
			continue
		var compact: Dictionary = {}
		for raw_key: Variant in (raw_module as Dictionary).keys():
			var key := str(raw_key)
			if key in duplicated_keys:
				continue
			var kept_value: Variant = _compact_sparse_model_value((raw_module as Dictionary).get(key))
			if _is_sparse_model_default(kept_value):
				continue
			compact[key] = kept_value
		if not compact.is_empty():
			result[str(raw_module_id)] = compact
	return result


func _compact_sparse_model_value(value: Variant) -> Variant:
	if value is Dictionary:
		var compact: Dictionary = {}
		for raw_key: Variant in (value as Dictionary).keys():
			var nested: Variant = _compact_sparse_model_value((value as Dictionary).get(raw_key))
			if not _is_sparse_model_default(nested):
				compact[str(raw_key)] = nested
		return compact
	if value is Array:
		var compact: Array = []
		for raw_item: Variant in value as Array:
			var item: Variant = _compact_sparse_model_value(raw_item)
			# Array position can carry meaning (for example typed attack costs), so
			# retain scalar defaults inside a non-empty ordered collection.
			if raw_item is Dictionary or raw_item is Array:
				if not _is_sparse_model_default(item):
					compact.append(item)
			else:
				compact.append(item)
		return compact
	return value


func _is_sparse_model_default(value: Variant) -> bool:
	if value == null:
		return true
	if value is bool:
		return not bool(value)
	if value is int or value is float:
		return is_zero_approx(float(value))
	if value is String:
		return str(value) == ""
	if value is Dictionary:
		return (value as Dictionary).is_empty()
	if value is Array:
		return (value as Array).is_empty()
	return false


func _factor_common_capability_context(frontier: Array[Dictionary]) -> Dictionary:
	var compacted: Array[Dictionary] = []
	for candidate: Dictionary in frontier:
		compacted.append(candidate.duplicate(true))
	var context: Dictionary = {}
	if compacted.is_empty():
		return {"frontier": compacted, "capability_context": context}
	var first_annotations: Dictionary = compacted[0].get("module_annotations", {}) \
		if compacted[0].get("module_annotations", {}) is Dictionary else {}
	for raw_module_id: Variant in first_annotations.keys():
		var module_id := str(raw_module_id)
		var first_module: Dictionary = first_annotations.get(module_id, {}) \
			if first_annotations.get(module_id, {}) is Dictionary else {}
		var common := first_module.duplicate(true)
		for candidate_index: int in range(1, compacted.size()):
			var annotations: Dictionary = compacted[candidate_index].get("module_annotations", {}) \
				if compacted[candidate_index].get("module_annotations", {}) is Dictionary else {}
			if not annotations.has(module_id) or not (annotations.get(module_id) is Dictionary):
				common.clear()
				break
			var module_annotation: Dictionary = annotations.get(module_id, {})
			for raw_key: Variant in common.keys():
				var key := str(raw_key)
				if not module_annotation.has(key) or module_annotation.get(key) != common.get(key):
					common.erase(key)
		if common.is_empty():
			continue
		context[module_id] = common.duplicate(true)
		for candidate_index: int in compacted.size():
			var annotations: Dictionary = compacted[candidate_index].get("module_annotations", {}) \
				if compacted[candidate_index].get("module_annotations", {}) is Dictionary else {}
			var module_annotation: Dictionary = annotations.get(module_id, {}) \
				if annotations.get(module_id, {}) is Dictionary else {}
			for raw_key: Variant in common.keys():
				module_annotation.erase(str(raw_key))
			if module_annotation.is_empty():
				annotations.erase(module_id)
			else:
				annotations[module_id] = module_annotation
			if annotations.is_empty():
				compacted[candidate_index].erase("module_annotations")
			else:
				compacted[candidate_index]["module_annotations"] = annotations
	return {"frontier": compacted, "capability_context": context}


func _compact_resource_ledger_for_model(value: Variant) -> Dictionary:
	var source: Dictionary = value if value is Dictionary else {}
	var result := {"schema_version": int(source.get("schema_version", 2))}
	for key: String in [
		"reserved_current_route", "reserved_next_turn", "recoverable",
		"possibly_prized", "safe_to_discard",
	]:
		var kept: Variant = source.get(key)
		if not _is_sparse_model_default(kept):
			result[key] = kept
	return result


func _compact_prize_graph_for_model(value: Variant) -> Dictionary:
	var source: Dictionary = value if value is Dictionary else {}
	var result: Dictionary = {}
	for key: String in [
		"schema_version", "own_prizes_remaining", "opponent_prizes_remaining",
		"shortest_path_turns", "opponent_shortest_path_turns", "current_prize_swing",
		"two_turn_prize_swing", "win_now", "credible_counter_ko",
	]:
		if source.has(key):
			result[key] = source.get(key)
	var lanes: Array[Dictionary] = []
	var raw_lanes: Variant = source.get("target_lanes", [])
	if raw_lanes is Array:
		for raw_lane: Variant in raw_lanes as Array:
			if not (raw_lane is Dictionary):
				continue
			var lane: Dictionary = raw_lane
			lanes.append({
				"slot_id": str(lane.get("slot_id", "")),
				"position": str(lane.get("position", "")),
				"requires_gust": bool(lane.get("requires_gust", false)),
				"ko_with_current_damage": bool(lane.get("ko_with_current_damage", false)),
			})
	if not lanes.is_empty():
		result["target_lanes"] = lanes
	return result


func _candidate_bindings(frontier: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for candidate: Dictionary in frontier:
		result.append({
			"candidate_id": str(candidate.get("candidate_id", "")),
			"route_id": str(candidate.get("route_id", "")),
		})
	return result


func _compact_observation_for_model(observation: Dictionary) -> Dictionary:
	var own: Dictionary = observation.get("own", {}) if observation.get("own", {}) is Dictionary else {}
	var opponent: Dictionary = observation.get("opponent", {}) if observation.get("opponent", {}) is Dictionary else {}
	return {
		"observation_version": int(observation.get("observation_version", 0)),
		"observation_hash": str(observation.get("observation_hash", "")),
		"turn": (observation.get("turn", {}) as Dictionary).duplicate(true) if observation.get("turn", {}) is Dictionary else {},
		"own": {
			"hand": _compact_cards(own.get("hand", [])),
			"hand_count": int(own.get("hand_count", 0)),
			"deck_count": int(own.get("deck_count", 0)),
			"prizes_remaining": int(own.get("prizes_remaining", 0)),
			"discard_counts": _card_name_counts(own.get("discard", [])),
			"active": _compact_slot(own.get("active", {})),
			"bench": _compact_slots(own.get("bench", [])),
		},
		"opponent": {
			"hand_count": int(opponent.get("hand_count", 0)),
			"deck_count": int(opponent.get("deck_count", 0)),
			"prizes_remaining": int(opponent.get("prizes_remaining", 0)),
			"discard_counts": _card_name_counts(opponent.get("discard", [])),
			"active": _compact_slot(opponent.get("active", {})),
			"bench": _compact_slots(opponent.get("bench", [])),
		},
		"stadium": _compact_card(observation.get("stadium", {})),
		"visibility": (observation.get("visibility", {}) as Dictionary).duplicate(true) if observation.get("visibility", {}) is Dictionary else {},
	}


func _compact_cards(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for raw_card: Variant in value as Array:
			if raw_card is Dictionary:
				result.append(_compact_card(raw_card))
	return result


func _compact_card(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return {}
	var card: Dictionary = value
	var result: Dictionary = {}
	for key: String in ["uid", "name", "type", "energy_type", "energy_provides"]:
		var text := str(card.get(key, ""))
		if text != "":
			result[key] = text
	return result


func _compact_slots(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for raw_slot: Variant in value as Array:
			result.append(_compact_slot(raw_slot))
	return result


func _compact_slot(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return {}
	var slot: Dictionary = value
	return {
		"slot_id": str(slot.get("slot_id", "")),
		"pokemon": _compact_card(slot.get("pokemon", {})),
		"energy_count": int(slot.get("energy_count", 0)),
		"energy": _compact_cards(slot.get("energy", [])),
		"damage": int(slot.get("damage", 0)),
		"remaining_hp": int(slot.get("remaining_hp", 0)),
		"prize_count": int(slot.get("prize_count", 1)),
		"ability_used": bool(slot.get("ability_used", false)),
		"tera": bool(slot.get("tera", false)),
	}


func _card_name_counts(value: Variant) -> Dictionary:
	var counts: Dictionary = {}
	if value is Array:
		for raw_card: Variant in value as Array:
			if not (raw_card is Dictionary):
				continue
			var identity := str((raw_card as Dictionary).get("uid", (raw_card as Dictionary).get("name", "")))
			if identity != "":
				counts[identity] = int(counts.get(identity, 0)) + 1
	return counts


func _base_action_scores(
	legal_actions: Array,
	game_state: GameState,
	player_index: int,
	turn_plan: Dictionary
) -> Dictionary:
	var scores: Dictionary = {}
	for raw_action: Variant in legal_actions:
		if not (raw_action is Dictionary):
			continue
		var action: Dictionary = raw_action
		scores[_observation_gateway.stable_action_id(action)] = _rules_fallback.score_action(
			action,
			game_state,
			player_index,
			turn_plan
		)
	return scores


func _should_use_local(frontier: Array[Dictionary], facts: Dictionary) -> Dictionary:
	if frontier.size() <= 1:
		return {"use_local": true, "reason": "single_route"}
	var top: Dictionary = frontier[0]
	if str(top.get("route_id", "")) == "route:attack_ko" and bool(top.get("outcome", {}).get("win_now", false)):
		return {"use_local": true, "reason": "forced_win"}
	var graph_only_review := _graph_only_model_review(frontier, facts)
	if not graph_only_review.is_empty():
		return {
			"use_local": false,
			"reason": "graph_only_certificate_requires_model_review",
			"candidate_id": str(graph_only_review.get("candidate_id", "")),
			"certificate_kind": str(graph_only_review.get("certificate_kind", "")),
		}
	var top_route_id := str(top.get("route_id", ""))
	var information_routes: Array[String] = [
		"route:information",
		"route:noctowl_search",
		"route:opening_search",
		"route:tutor",
	]
	var switch_margin := float(_profile.get("switch_margin", 0.0))
	var route_preferences: Dictionary = _profile.get("route_preferences", {}) if _profile.get("route_preferences", {}) is Dictionary else {}
	var consideration_margin := float(route_preferences.get("model_consideration_margin", switch_margin))
	var switchable_alternatives := 0
	for route_index: int in range(1, frontier.size()):
		var alternative: Dictionary = frontier[route_index]
		var outcome: Dictionary = alternative.get("outcome", {}) if alternative.get("outcome", {}) is Dictionary else {}
		var score_gap := float(top.get("base_score", top.get("local_score", 0.0))) \
			- float(alternative.get("base_score", alternative.get("local_score", 0.0)))
		if score_gap <= consideration_margin \
				or bool(outcome.get("win_now", false)) \
				or int(outcome.get("prizes_now", 0)) > int(top.get("outcome", {}).get("prizes_now", 0)):
			switchable_alternatives += 1
	if switchable_alternatives == 0 and top_route_id not in information_routes:
		return {"use_local": true, "reason": "no_switchable_alternative"}
	var score_gap := float(top.get("local_score", 0.0)) - float(frontier[1].get("local_score", 0.0))
	var has_noctowl := false
	for route: Dictionary in frontier:
		if str(route.get("route_id", "")) == "route:noctowl_search":
			has_noctowl = true
			break
	var expected_regret := maxf(0.0, consideration_margin - score_gap) \
		+ float(switchable_alternatives) * 45.0 \
		+ (110.0 if has_noctowl or top_route_id in information_routes else 0.0)
	var threshold := float(_profile.get("expected_regret_threshold", 80.0))
	var route_thresholds: Dictionary = route_preferences.get(
		"model_review_regret_threshold_by_route",
		{}
	) if route_preferences.get("model_review_regret_threshold_by_route", {}) is Dictionary else {}
	if route_thresholds.has(top_route_id):
		# A deck may close low-value deterministic roots more aggressively while
		# keeping its information-rich routes on the previously audited model gate.
		# Profiles without this opt-in remain byte-for-byte decision equivalent.
		threshold = float(route_thresholds.get(top_route_id, threshold))
	return {
		"use_local": expected_regret < threshold or bool(facts.get("resources", {}).get("deck_low", false)) and str(top.get("route_id", "")) == "route:information",
		"reason": "low_expected_regret" if expected_regret < threshold else "",
		"expected_regret": expected_regret,
		"switchable_alternatives": switchable_alternatives,
	}


func _graph_only_model_review(
	frontier: Array[Dictionary],
	facts: Dictionary
) -> Dictionary:
	if frontier.size() <= 1:
		return {}
	var local_top: Dictionary = frontier[0]
	for index: int in range(1, frontier.size()):
		var candidate: Dictionary = frontier[index]
		var advantage := _capability_registry.verify_route_advantage(
			candidate, local_top, facts, _profile
		)
		if bool(advantage.get("verified", false)) \
				and bool(advantage.get("requires_model_graph", false)) \
				and bool(advantage.get("graph_only", false)):
			return {
				"candidate_id": str(candidate.get("candidate_id", "")),
				"certificate_kind": str(advantage.get("certificate_kind", "")),
			}
	return {}


func _should_skip_terminal_without_admissible_switch(
	candidate_pool: Array[Dictionary],
	facts: Dictionary
) -> Dictionary:
	if candidate_pool.is_empty():
		return {"skip": false, "reason": "empty_candidate_pool", "checked_alternatives": 0}
	var top_route_id := str(candidate_pool[0].get("route_id", ""))
	if top_route_id not in ["route:attack_ko", "route:attack_pressure", "route:end_turn"]:
		return {"skip": false, "reason": "non_terminal_root", "checked_alternatives": 0}
	var checked := 0
	for index: int in range(1, candidate_pool.size()):
		var candidate: Dictionary = candidate_pool[index]
		checked += 1
		var safety := _validate_model_route_safety(
			str(candidate.get("route_id", "")),
			candidate_pool,
			facts,
			str(candidate.get("candidate_id", ""))
		)
		if bool(safety.get("valid", false)):
			return {
				"skip": false,
				"reason": "safe_non_rule_alternative",
				"checked_alternatives": checked,
				"candidate_id": str(candidate.get("candidate_id", "")),
			}
	return {
		"skip": true,
		"reason": "provably_terminal_no_admissible_switch",
		"checked_alternatives": checked,
	}


func _install_one_shot_rules_floor(frontier: Array[Dictionary]) -> void:
	if frontier.is_empty():
		_clear_route("rules_fallback")
		return
	_policy_graph.clear()
	_execution_cursor.clear()
	_select_route(
		str(frontier[0].get("route_id", "")),
		frontier,
		"rules_fallback",
		str(frontier[0].get("candidate_id", ""))
	)


func _install_local_policy(frontier: Array[Dictionary], owner: String) -> void:
	if frontier.is_empty():
		_clear_route("rules_fallback")
		return
	var policy := PolicyGraphScript.build_local(frontier)
	_policy_graph.install(policy, owner)
	_execution_cursor.clear()
	_select_route(
		str(frontier[0].get("route_id", "")),
		frontier,
		owner,
		str(frontier[0].get("candidate_id", ""))
	)


func _install_rejected_model_fallback(frontier: Array[Dictionary]) -> void:
	# A rejected response must be observationally equivalent to a request that
	# never arrived.  In particular, it must not relabel the Rule root as
	# `local_gate`, because that owner is allowed to activate additional local
	# interaction certificates and can therefore change a same-seed duel even
	# when audit reports model_accepted=0.
	_install_local_policy(frontier, "deadline_fallback")


func _install_wait_budget_fallback(frontier: Array[Dictionary]) -> void:
	# Exhausting the visible-wait budget after an earlier rejected/deadline
	# request is part of that same atomic rejection path.  Relabelling the Rule
	# root as `local_gate` here would activate interaction-only certificates that
	# are absent from the verified-local no-response reference.
	_install_rejected_model_fallback(frontier)


func _should_reopen_information_epoch(
	policy_origin: String,
	completed_action: Dictionary,
	delta: Dictionary,
	previous_frontier: Array[Dictionary]
) -> bool:
	# A local policy is only a decision for the information available when it was
	# installed. Once a successful search/draw action changes that information,
	# its old `local_best` checkpoint must not silently decide the rest of turn.
	# Model graphs retain their own typed checkpoints and are advanced normally.
	if not _runtime_configured:
		return false
	# `model_shadow_rule_root` deliberately executes the exact Rule root through
	# `local_gate`.  The graph origin describes where the rejected/no-op model
	# proposal came from; the completed action owner describes who actually made
	# the decision.  Information-epoch ownership must follow the latter or a
	# same-size tutor such as Earthen Vessel can silently reuse the stale local
	# root after replacing the visible hand identities.
	var completed_owner := str(completed_action.get("owner", policy_origin))
	if completed_owner not in ["local_gate", "deadline_fallback", "schema_fallback"]:
		return false
	if not bool(completed_action.get("success", false)):
		return false
	var route_id := str(completed_action.get("route_id", ""))
	var candidate_id := str(completed_action.get("candidate_id", ""))
	var checkpoint_after := ""
	var verified_module_checkpoint := false
	if candidate_id != "":
		for candidate: Dictionary in previous_frontier:
			if str(candidate.get("candidate_id", "")) == candidate_id:
				checkpoint_after = str(candidate.get("checkpoint_after", ""))
				var annotations: Dictionary = candidate.get("module_annotations", {}) \
					if candidate.get("module_annotations", {}) is Dictionary else {}
				for raw_annotation: Variant in annotations.values():
					if raw_annotation is Dictionary \
							and bool((raw_annotation as Dictionary).get("verified_advantage", false)) \
							and str((raw_annotation as Dictionary).get("verified_advantage_kind", "")) == "profiled_visible_engine_hold":
						verified_module_checkpoint = true
						break
				break
	var information_routes: Array[String] = [
		"route:information",
		"route:noctowl_search",
		"route:opening_search",
		"route:tutor",
		# Gust changes the public attacker/retreat clock.  A local single-action
		# root must expose that material board delta before it can continue with
		# an unrelated draw or development action.
		"route:gust",
	]
	var information_checkpoint := route_id in information_routes \
		or checkpoint_after == "information_result"
	if not information_checkpoint and not verified_module_checkpoint:
		return false
	# Hidden-deck search can replace its paid card/cost with the same number of
	# visible cards.  Hand size and legal-action count may therefore be unchanged
	# even though the identities that the next decision depends on are new.  The
	# typed information checkpoint itself is the proof that the old local root is
	# stale; the per-turn wait budget still bounds repeated model calls.
	if information_checkpoint:
		return true
	if bool(delta.get("material", false)) or bool(delta.get("legal_actions_changed", false)):
		return true
	var changed_facts: Array = delta.get("changed_facts", []) if delta.get("changed_facts", []) is Array else []
	return "resources.hand_size" in changed_facts


func _validate_model_route_safety(
	root_route_id: String,
	frontier: Array[Dictionary],
	facts: Dictionary,
	candidate_id: String = ""
) -> Dictionary:
	if frontier.is_empty():
		return {"valid": false, "reason": "empty_frontier"}
	var selected := _route_search.find_candidate(frontier, candidate_id) if candidate_id != "" else _route_search.find_route(frontier, root_route_id)
	if selected.is_empty():
		return {"valid": false, "reason": "root_route_unavailable"}
	var local_top: Dictionary = frontier[0]
	if str(selected.get("candidate_id", "")) != "" \
			and str(selected.get("candidate_id", "")) == str(local_top.get("candidate_id", "")):
		var tied_candidates: Array[Dictionary] = []
		if not bool(local_top.get("engine_rule_floor_exact", false)):
			tied_candidates = _rule_score_ties(local_top, frontier)
		if not tied_candidates.is_empty():
			var dominates_all := true
			for tied_candidate: Dictionary in tied_candidates:
				if not _has_verified_same_route_advantage(selected, tied_candidate):
					dominates_all = false
					break
			if not dominates_all:
				return {
					"valid": false,
					"reason": "ambiguous_rule_tie_without_verified_advantage",
				}
		return {"valid": true, "reason": "matches_rules_floor"}
	var module_validation := _capability_registry.validate_route_switch(selected, local_top, facts, _profile)
	if not bool(module_validation.get("valid", false)):
		return module_validation
	var module_advantage := _capability_registry.verify_route_advantage(
		selected,
		local_top,
		facts,
		_profile
	)
	var has_module_advantage := bool(module_advantage.get("verified", false))
	var selected_outcome: Dictionary = selected.get("outcome", {}) if selected.get("outcome", {}) is Dictionary else {}
	var top_outcome: Dictionary = local_top.get("outcome", {}) if local_top.get("outcome", {}) is Dictionary else {}
	var improves_terminal := bool(selected_outcome.get("win_now", false)) and not bool(top_outcome.get("win_now", false))
	var improves_prizes := int(selected_outcome.get("prizes_now", 0)) > int(top_outcome.get("prizes_now", 0))
	# Compare the alternative against the proved Rule suffix floor, rather than
	# against the Rule root's single-action outcome. This removes the false
	# immediate-prize advantage without blocking a real win-now, higher-prize, or
	# independently certified alternative.
	var rule_suffix_advantage := _capability_registry.verify_route_advantage(
		local_top,
		selected,
		facts,
		_profile
	)
	var selected_is_terminal := bool(selected_outcome.get("terminal", false)) \
		or str(selected.get("action_kind", "")) in ["attack", "granted_attack"] \
		or str(selected.get("route_id", "")) in ["route:attack_ko", "route:attack_pressure"]
	var suffix_prizes_floor := int(rule_suffix_advantage.get("prizes_floor", 0))
	var selected_prizes_floor := int(selected_outcome.get("prizes_now", 0))
	var selected_wins_now := bool(selected_outcome.get("win_now", false))
	var suffix_wins_now := bool(rule_suffix_advantage.get("win_now", false))
	if selected_is_terminal \
			and not has_module_advantage \
			and bool(rule_suffix_advantage.get("verified", false)) \
			and str(rule_suffix_advantage.get("certificate_kind", "")) in [
				"public_counter_mover_before_secured_ko",
				"public_grass_draw_acceleration_before_secured_ko",
				"public_grass_redistribution_before_secured_ko",
			] \
			and suffix_prizes_floor >= selected_prizes_floor \
			and (not selected_wins_now or suffix_wins_now):
		return {
			"valid": false,
			"reason": "verified_rule_suffix_dominates_terminal_switch",
			"advantage": rule_suffix_advantage,
		}
	if root_route_id == str(local_top.get("route_id", "")) \
			and not _has_verified_same_route_advantage(selected, local_top) \
			and not has_module_advantage:
		return {
			"valid": false,
			"reason": "same_route_switch_without_verified_advantage",
		}
	var search_routes: Array[String] = ["route:information", "route:noctowl_search", "route:opening_search", "route:tutor"]
	var safety: Dictionary = _profile.get("safety", {}) if _profile.get("safety", {}) is Dictionary else {}
	if bool(safety.get("block_search_when_deck_low", true)) \
			and bool(facts.get("resources", {}).get("deck_low", false)) \
			and root_route_id in search_routes \
			and str(local_top.get("route_id", "")) not in search_routes \
			and not improves_terminal:
		return {"valid": false, "reason": "deckout_margin_blocks_search"}
	var switch_margin := float(safety.get("max_switch_gap", _profile.get("switch_margin", 0.0)))
	var route_preferences: Dictionary = _profile.get("route_preferences", {}) if _profile.get("route_preferences", {}) is Dictionary else {}
	var route_biases: Dictionary = route_preferences.get("route_biases", {}) if route_preferences.get("route_biases", {}) is Dictionary else {}
	var top_route_id := str(local_top.get("route_id", ""))
	var top_effective_score := float(local_top.get("base_score", local_top.get("local_score", 0.0))) + float(route_biases.get(top_route_id, 0.0))
	var selected_effective_score := float(selected.get("base_score", selected.get("local_score", 0.0))) + float(route_biases.get(root_route_id, 0.0))
	var score_gap := top_effective_score - selected_effective_score
	if score_gap > switch_margin \
			and not improves_terminal \
			and not improves_prizes \
			and not has_module_advantage:
		return {
			"valid": false,
			"reason": "model_route_below_switch_margin",
			"score_gap": score_gap,
			"switch_margin": switch_margin,
		}
	if has_module_advantage:
		return {
			"valid": true,
			"reason": "module_verified_advantage",
			"score_gap": score_gap,
			"advantage": module_advantage,
		}
	if improves_terminal:
		return {"valid": true, "reason": "deterministic_win_now", "score_gap": score_gap}
	if improves_prizes:
		return {"valid": true, "reason": "deterministic_prize_gain", "score_gap": score_gap}
	return {"valid": true, "reason": "validated_switch", "score_gap": score_gap}


func _find_module_verified_upgrade(
	frontier: Array[Dictionary],
	facts: Dictionary
) -> Dictionary:
	var certified_continuation := _find_profiled_gardevoir_suffix_continuation(frontier)
	if not certified_continuation.is_empty():
		return certified_continuation
	if frontier.size() <= 1:
		return {}
	var best: Dictionary = {}
	var best_rank := -1
	for candidate: Dictionary in frontier:
		if str(candidate.get("candidate_id", "")) == str(frontier[0].get("candidate_id", "")):
			continue
		var safety := _validate_model_route_safety(
			str(candidate.get("route_id", "")),
			frontier,
			facts,
			str(candidate.get("candidate_id", ""))
		)
		var reason := str(safety.get("reason", ""))
		# Deterministic terminal outcomes and independent module certificates may
		# take ownership locally. Repeated host prepare calls reuse this exact
		# selection instead of opening a second request and skipping the action.
		var autonomous_module_upgrade := reason == "module_verified_advantage" \
			and _can_apply_autonomous_module_upgrade(candidate, frontier[0], facts, safety)
		var autonomous_deterministic_upgrade := reason in [
			"deterministic_win_now",
			"deterministic_prize_gain",
		] and _can_apply_autonomous_deterministic_upgrade(candidate, frontier[0])
		var rank := 3 if reason == "deterministic_win_now" and autonomous_deterministic_upgrade \
			else 2 if reason == "deterministic_prize_gain" and autonomous_deterministic_upgrade \
			else 1 if autonomous_module_upgrade else -1
		if bool(safety.get("valid", false)) and rank > best_rank:
			var result := candidate.duplicate(true)
			result["verified_advantage"] = safety.get("advantage", {})
			result["verified_reason"] = reason
			best = result
			best_rank = rank
	return best


func _find_profiled_gardevoir_suffix_continuation(
	frontier: Array[Dictionary]
) -> Dictionary:
	if _profiled_gardevoir_suffix_ticket.is_empty() \
			or int(_profiled_gardevoir_suffix_ticket.get("turn", -2)) != _current_turn \
			or int(_profiled_gardevoir_suffix_ticket.get("deck_id", -1)) \
				!= int(_profile.get("deck_id", -2)):
		return {}
	var current_stage := str(_profiled_gardevoir_suffix_ticket.get("stage", ""))
	var next_stage_by_stage := {
		"manual_psychic_to_active": "first_embrace_to_active",
		"first_embrace_to_active": "second_embrace_to_active",
		"second_embrace_to_active": "active_gardevoir_190_ko",
	}
	var expected_stage := str(next_stage_by_stage.get(current_stage, ""))
	var continuation_key := str(_profiled_gardevoir_suffix_ticket.get("continuation_key", ""))
	var prior_observation_hash := str(_profiled_gardevoir_suffix_ticket.get(
		"observation_hash_provenance", ""
	))
	if expected_stage == "" or continuation_key == "" or prior_observation_hash == "":
		return {}
	var matched_candidate: Dictionary = {}
	for candidate: Dictionary in frontier:
		var annotations: Dictionary = candidate.get("module_annotations", {}) \
			if candidate.get("module_annotations", {}) is Dictionary else {}
		var module_annotation: Dictionary = annotations.get("gardevoir_embrace", {}) \
			if annotations.get("gardevoir_embrace", {}) is Dictionary else {}
		var suffix: Dictionary = module_annotation.get("profiled_active_gardevoir_ko_suffix", {}) \
			if module_annotation.get("profiled_active_gardevoir_ko_suffix", {}) is Dictionary else {}
		var observation_hash := str(suffix.get("observation_hash_provenance", ""))
		if not bool(suffix.get("advances_profiled_active_gardevoir_ko_suffix", false)) \
				or str(suffix.get("certificate_kind", "")) != "profiled_visible_engine_hold" \
				or str(suffix.get("continuation_key", "")) != continuation_key \
				or str(suffix.get("stage", "")) != expected_stage \
				or observation_hash == "" \
				or observation_hash == prior_observation_hash:
			continue
		# More than one exact continuation is ambiguous and must fail closed.
		if not matched_candidate.is_empty():
			return {}
		matched_candidate = candidate.duplicate(true)
		matched_candidate["verified_advantage"] = {
			"verified": true,
			"reason": "public_exact_active_gardevoir_suffix_continuation",
			"certificate_kind": "profiled_visible_engine_hold",
			"evidence_kind": "public_action_bound_reobserved_continuation",
			"interaction_owner": "profiled_active_gardevoir_ko_suffix_target",
			"stage": expected_stage,
			"context_key": str(suffix.get("context_key", "")),
			"continuation_key": continuation_key,
			"observation_hash_provenance": observation_hash,
		}
		matched_candidate["verified_reason"] = "module_verified_advantage"
	return matched_candidate


func _can_apply_autonomous_deterministic_upgrade(
	selected: Dictionary,
	local_top: Dictionary
) -> bool:
	var selected_is_attack := str(selected.get("action_kind", "")) in ["attack", "granted_attack"] \
		or str(selected.get("route_id", "")) in ["route:attack_ko", "route:attack_pressure"]
	if not selected_is_attack:
		return true
	var local_top_is_attack := str(local_top.get("action_kind", "")) in ["attack", "granted_attack"] \
		or str(local_top.get("route_id", "")) in ["route:attack_ko", "route:attack_pressure"]
	return local_top_is_attack or str(local_top.get("route_id", "")) == "route:end_turn"


func _can_apply_autonomous_module_upgrade(
	selected: Dictionary,
	local_top: Dictionary,
	facts: Dictionary,
	safety: Dictionary
) -> bool:
	var advantage: Dictionary = safety.get("advantage", {}) \
		if safety.get("advantage", {}) is Dictionary else {}
	var certificate_kind := str(advantage.get("certificate_kind", ""))
	# This proof only authorizes a model-owned bounded graph that explicitly
	# reserves the duplicate gust.  It must never become an autonomous local
	# rewrite, at either the root or the post-tool observation.
	if certificate_kind == "public_attackless_duplicate_gust_hold" \
			or bool(advantage.get("requires_model_graph", false)):
		return false
	# Only independently bound public certificates may postpone the Rule floor.
	# The former repeated-Embrace projection is intentionally absent: one current
	# ability cannot own an unbound multi-interaction future sequence.
	if certificate_kind in [
		"public_second_counter_mover_final_prize_closeout",
		"public_profiled_low_pressure_counter_engine_setup",
		"profiled_double_counter_engine_hand_reset",
		"profiled_counter_activation",
		"profiled_search_before_attachment_sequence",
		"profiled_engine_search_before_attack_completion",
		"profiled_same_turn_retreat_bridge",
		"profiled_visible_engine_hold",
		"public_same_attacker_damage_dominance",
		"public_partner_same_turn_prize_breakpoint",
		"public_partner_same_turn_damage_upgrade",
		"public_same_ko_preserve_attached_energy",
		"profiled_stage2_search_before_pivot",
		"public_copy_source_recovery_attack_epoch",
	]:
		return true
	# A non-terminal local certificate must never postpone an executable Rule
	# attack.  Such sequencing is a policy-graph decision for the model, not a
	# monotonic local rewrite.
	if bool(facts.get("attack", {}).get("ready", false)) \
			or bool(facts.get("attack", {}).get("ko_available", false)) \
			or str(local_top.get("route_id", "")) in ["route:attack_ko", "route:attack_pressure"]:
		return false
	if certificate_kind != "public_typed_attack_cost_completion":
		return certificate_kind != ""
	# Completing a Bench attacker's cost, or attaching before a Rule search, is
	# not monotonic: either can destroy a stronger information/development
	# sequence even though the public cost arithmetic is exact.  Autonomous
	# ownership is therefore limited to ending the turn, or replacing Rule's
	# competing use of the same once-per-turn attachment quota.  The latter also
	# stays inside the normal switch margin and must be bound to the exact Rule
	# floor; this is the narrow seed-109 failure shape, not a general rewrite.
	if not _candidate_completes_active_public_attack_cost(selected) \
			or _candidate_completes_public_attack_cost(local_top) \
			or not _candidate_has_open_deterministic_attack_window(selected):
		return false
	if str(local_top.get("route_id", "")) == "route:end_turn":
		return true
	var selected_outcome: Dictionary = selected.get("outcome", {}) \
		if selected.get("outcome", {}) is Dictionary else {}
	var top_outcome: Dictionary = local_top.get("outcome", {}) \
		if local_top.get("outcome", {}) is Dictionary else {}
	if bool(top_outcome.get("win_now", false)) \
			or int(top_outcome.get("prizes_now", 0)) > int(selected_outcome.get("prizes_now", 0)):
		return false
	if _candidate_has_verified_module_annotation(local_top):
		return false
	var profile_safety: Dictionary = _profile.get("safety", {}) \
		if _profile.get("safety", {}) is Dictionary else {}
	var switch_margin := float(profile_safety.get("max_switch_gap", _profile.get("switch_margin", 0.0)))
	return str(selected.get("route_id", "")) == "route:energy_commit" \
		and str(selected.get("action_kind", "")) == "attach_energy" \
		and _candidate_allows_autonomous_same_quota_completion(selected) \
		and str(local_top.get("route_id", "")) == "route:energy_commit" \
		and str(local_top.get("action_kind", "")) == "attach_energy" \
		and bool(local_top.get("engine_rule_floor_exact", false)) \
		and float(safety.get("score_gap", INF)) <= switch_margin


func _can_apply_initial_module_upgrade(upgrade: Dictionary) -> bool:
	var certificate_kind := str(
		upgrade.get("verified_advantage", {}).get("certificate_kind", "")
	)
	return certificate_kind in [
		"profiled_counter_activation",
		"public_typed_attack_cost_completion",
		"public_same_ko_preserve_attached_energy",
		"profiled_stage2_search_before_pivot",
	]


func _candidate_completes_public_attack_cost(candidate: Dictionary) -> bool:
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	for raw_annotation: Variant in annotations.values():
		if not (raw_annotation is Dictionary):
			continue
		for key: String in ["attachment", "typed_attachment"]:
			var attachment: Variant = (raw_annotation as Dictionary).get(key, {})
			if attachment is Dictionary and bool((attachment as Dictionary).get("completes_required_types", false)):
				return true
	return false


func _candidate_completes_active_public_attack_cost(candidate: Dictionary) -> bool:
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	for raw_annotation: Variant in annotations.values():
		if not (raw_annotation is Dictionary):
			continue
		for key: String in ["attachment", "typed_attachment"]:
			var attachment: Variant = (raw_annotation as Dictionary).get(key, {})
			if attachment is Dictionary \
					and bool((attachment as Dictionary).get("target_is_active", false)) \
					and bool((attachment as Dictionary).get("completes_required_types", false)):
				return true
	return false


func _candidate_has_open_deterministic_attack_window(candidate: Dictionary) -> bool:
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	for raw_annotation: Variant in annotations.values():
		if not (raw_annotation is Dictionary):
			continue
		for key: String in ["attachment", "typed_attachment"]:
			var attachment: Variant = (raw_annotation as Dictionary).get(key, {})
			if attachment is Dictionary \
					and bool((attachment as Dictionary).get("target_is_active", false)) \
					and bool((attachment as Dictionary).get("completes_required_types", false)) \
					and bool((attachment as Dictionary).get("deterministic_attack_window_open", false)):
				return true
	return false


func _candidate_allows_autonomous_same_quota_completion(candidate: Dictionary) -> bool:
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	for raw_annotation: Variant in annotations.values():
		if not (raw_annotation is Dictionary):
			continue
		for key: String in ["attachment", "typed_attachment"]:
			var attachment: Variant = (raw_annotation as Dictionary).get(key, {})
			if attachment is Dictionary \
					and bool((attachment as Dictionary).get("autonomous_same_quota_completion", false)):
				return true
	return false


func _candidate_has_verified_module_annotation(candidate: Dictionary) -> bool:
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	for raw_annotation: Variant in annotations.values():
		if raw_annotation is Dictionary \
				and bool((raw_annotation as Dictionary).get("verified_advantage", false)):
			return true
	return false


func _can_reuse_direct_verified_selection(frontier: Array[Dictionary], observation_hash: String) -> bool:
	if _current_action_owner != "module_verified_upgrade" \
			or _preferred_candidate_id == "" \
			or observation_hash == "" \
			or observation_hash != str(_last_observation.get("observation_hash", "")):
		return false
	return not _route_search.find_candidate(frontier, _preferred_candidate_id).is_empty()


func _rule_score_ties(selected: Dictionary, frontier: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var selected_id := str(selected.get("candidate_id", ""))
	var selected_score := float(selected.get("base_score", selected.get("local_score", 0.0)))
	for candidate: Dictionary in frontier:
		if str(candidate.get("candidate_id", "")) == selected_id:
			continue
		if is_equal_approx(float(candidate.get("base_score", candidate.get("local_score", 0.0))), selected_score):
			result.append(candidate)
	return result


func _can_defer_ambiguous_root_to_rule(selected: Dictionary, frontier: Array[Dictionary]) -> bool:
	if selected.is_empty() or frontier.is_empty():
		return false
	var local_top: Dictionary = frontier[0]
	var selected_route := str(selected.get("route_id", ""))
	var allowed_information_routes: Array[String] = [
		"route:information",
		"route:noctowl_search",
		"route:opening_search",
	]
	if selected_route not in allowed_information_routes \
			or selected_route != str(local_top.get("route_id", "")) \
			or str(selected.get("checkpoint_after", "")) != "information_result" \
			or str(local_top.get("checkpoint_after", "")) != "information_result":
		return false
	var top_score := float(local_top.get("base_score", local_top.get("local_score", 0.0)))
	for candidate: Dictionary in frontier:
		if not is_equal_approx(float(candidate.get("base_score", candidate.get("local_score", 0.0))), top_score):
			continue
		if str(candidate.get("route_id", "")) != selected_route \
				or str(candidate.get("checkpoint_after", "")) != "information_result":
			return false
	return true


func _has_verified_same_route_advantage(selected: Dictionary, local_top: Dictionary) -> bool:
	var selected_outcome: Dictionary = selected.get("outcome", {}) if selected.get("outcome", {}) is Dictionary else {}
	var top_outcome: Dictionary = local_top.get("outcome", {}) if local_top.get("outcome", {}) is Dictionary else {}
	if bool(selected_outcome.get("win_now", false)) and not bool(top_outcome.get("win_now", false)):
		return true
	if int(selected_outcome.get("prizes_now", 0)) > int(top_outcome.get("prizes_now", 0)):
		return true
	if float(selected_outcome.get("estimated_damage", 0.0)) > float(top_outcome.get("estimated_damage", 0.0)) + 0.5:
		return true
	var selected_improvement := float(selected_outcome.get("expected_route_improvement", 0.0))
	var top_improvement := float(top_outcome.get("expected_route_improvement", 0.0))
	if selected_improvement >= top_improvement + 0.15:
		return true
	var selected_information := float(selected_outcome.get("information_gain", 0.0))
	var top_information := float(top_outcome.get("information_gain", 0.0))
	var selected_commitment := float(selected_outcome.get("resource_commitment", 0.0)) \
		+ float(selected_outcome.get("board_commitment", 0.0))
	var top_commitment := float(top_outcome.get("resource_commitment", 0.0)) \
		+ float(top_outcome.get("board_commitment", 0.0))
	if selected_information >= top_information + 0.2 and selected_commitment <= top_commitment:
		return true
	if selected_commitment + 0.25 <= top_commitment and selected_improvement >= top_improvement:
		return true
	return _module_annotation_dominates(
		selected.get("module_annotations", {}),
		local_top.get("module_annotations", {})
	)


func _module_annotation_dominates(selected_value: Variant, top_value: Variant) -> bool:
	if not (selected_value is Dictionary) or not (top_value is Dictionary):
		return false
	var selected: Dictionary = selected_value
	var top: Dictionary = top_value
	for raw_module_id: Variant in selected.keys():
		var module_id := str(raw_module_id)
		var selected_module: Variant = selected.get(raw_module_id, {})
		var top_module: Variant = top.get(module_id, {})
		if not (selected_module is Dictionary) or not (top_module is Dictionary):
			continue
		var selected_warning := str((selected_module as Dictionary).get("route_warning", (selected_module as Dictionary).get("warning", "")))
		var top_warning := str((top_module as Dictionary).get("route_warning", (top_module as Dictionary).get("warning", "")))
		if selected_warning == "" and top_warning != "":
			return true
		for key: String in ["ko_payable_with_reserve", "next_turn_reserve_met", "typed_attack_cost_ready", "adds_distinct_energy_symbol", "functional_bench_reserve_met"]:
			if bool((selected_module as Dictionary).get(key, false)) and not bool((top_module as Dictionary).get(key, false)):
				return true
	return false


func _validate_root_route_ref(route_ref: Dictionary, frontier: Array[Dictionary]) -> Dictionary:
	var mode := str(route_ref.get("mode", ""))
	var route_id := str(route_ref.get("route_id", ""))
	var candidate_id := str(route_ref.get("candidate_id", route_ref.get("first_candidate_id", "")))
	var candidate := _route_search.find_candidate(frontier, candidate_id)
	if candidate.is_empty():
		return {"valid": false, "reason": "candidate_unavailable"}
	if str(candidate.get("route_id", "")) != route_id:
		return {"valid": false, "reason": "candidate_route_mismatch"}
	if mode != "propose_typed_route":
		return {"valid": true}
	var macros: Array = route_ref.get("macro_actions", []) if route_ref.get("macro_actions", []) is Array else []
	if macros.is_empty() or str(macros[0]) != route_id:
		return {"valid": false, "reason": "typed_route_first_step_mismatch"}
	var exclusive_seen: Dictionary = {}
	for index: int in macros.size():
		var macro := str(macros[index])
		if macro in ["route:attack_ko", "route:attack_pressure", "route:end_turn"] and index != macros.size() - 1:
			return {"valid": false, "reason": "typed_route_terminal_not_last"}
		if macro in ["route:energy_commit", "route:pivot", "route:stadium"]:
			if exclusive_seen.has(macro):
				return {"valid": false, "reason": "typed_route_double_spends_quota"}
			exclusive_seen[macro] = true
	var attack_dependency := _validate_typed_route_attack_dependency(candidate, macros)
	if not bool(attack_dependency.get("valid", false)):
		return attack_dependency
	return {"valid": true}


func _validate_typed_route_attack_dependency(
	candidate: Dictionary,
	macros: Array
) -> Dictionary:
	if macros.is_empty() or str(macros[0]) != "route:energy_commit":
		return {"valid": true}
	var terminal_route := str(macros[-1])
	if terminal_route not in ["route:attack_ko", "route:attack_pressure"]:
		return {"valid": true}
	# A typed cursor has no candidate binding for intermediate macros. Therefore
	# an attachment may lead directly to an attack only when its own public
	# postcondition proves Active cost completion and an open attack window.
	if macros.size() != 2 or not _candidate_has_open_deterministic_attack_window(candidate):
		return {"valid": false, "reason": "typed_route_attack_dependency_unproven"}
	if terminal_route == "route:attack_pressure":
		return {"valid": true}
	# Cost completion proves attack availability, not a knockout. Keep KO routes
	# closed until a candidate-specific postcondition binds source, attack index,
	# defender, effective HP, projected damage, and prizes after the attachment.
	var attachment := _candidate_typed_attachment(candidate)
	if not bool(attachment.get("immediate_attack_ko_after_attachment", false)):
		return {"valid": false, "reason": "typed_route_attack_dependency_unproven"}
	return {"valid": true}


func _validate_candidate_bound_policy_progress(
	policy: Dictionary,
	root_ref: Dictionary,
	frontier: Array[Dictionary],
	facts: Dictionary
) -> Dictionary:
	# Reject only a publicly impossible no-progress graph. A non-completing Active
	# attachment cannot make attack.ready/ko true by itself. If every branch at
	# the immediately following checkpoint requires one of those facts and the
	# otherwise edge is a terminal node, the installed graph is known to discard
	# its own continuation before the root action executes.
	var candidate_id := str(root_ref.get("candidate_id", root_ref.get("first_candidate_id", "")))
	var candidate := _route_search.find_candidate(frontier, candidate_id)
	if candidate.is_empty() \
			or str(candidate.get("route_id", "")) != "route:energy_commit" \
			or str(candidate.get("action_kind", "")) != "attach_energy":
		return {"valid": true}
	var attachment := _candidate_typed_attachment(candidate)
	var missing_after: Array = attachment.get("missing_after", []) \
		if attachment.get("missing_after", []) is Array else []
	if missing_after.is_empty() or not bool(attachment.get("target_is_active", false)):
		return {"valid": true}
	var attack_facts: Dictionary = facts.get("attack", {}) \
		if facts.get("attack", {}) is Dictionary else {}
	if bool(attack_facts.get("ready", true)) or bool(attack_facts.get("ko_available", true)):
		return {"valid": true}
	var guarded_uids: Array[String] = []
	var module_parameters: Dictionary = _profile.get("module_parameters", {}) \
		if _profile.get("module_parameters", {}) is Dictionary else {}
	for raw_parameters: Variant in module_parameters.values():
		if not (raw_parameters is Dictionary):
			continue
		for raw_uid: Variant in (raw_parameters as Dictionary).get(
			"checkpoint_missing_cost_all_attacks_blocked_uids", []
		):
			var guarded_uid := str(raw_uid).strip_edges().to_upper()
			if guarded_uid != "" and guarded_uid not in guarded_uids:
				guarded_uids.append(guarded_uid)
	if str(attachment.get("target_uid", "")).strip_edges().to_upper() not in guarded_uids:
		return {"valid": true}
	var nodes: Array = policy.get("nodes", []) if policy.get("nodes", []) is Array else []
	var node_by_id: Dictionary = {}
	for raw_node: Variant in nodes:
		if raw_node is Dictionary:
			node_by_id[str((raw_node as Dictionary).get("node_id", ""))] = raw_node
	var root_id := str(policy.get("root_node_id", ""))
	var root_node: Dictionary = node_by_id.get(root_id, {}) \
		if node_by_id.get(root_id, {}) is Dictionary else {}
	var next_id := str(root_node.get("next_node_id", ""))
	var checkpoint: Dictionary = node_by_id.get(next_id, {}) \
		if node_by_id.get(next_id, {}) is Dictionary else {}
	if str(checkpoint.get("kind", "")) != "checkpoint":
		return {"valid": true}
	if _checkpoint_has_public_progress(checkpoint, node_by_id, {}):
		return {"valid": true}
	return {
		"valid": false,
		"reason": "candidate_checkpoint_dependency_unreachable",
		"candidate_id": candidate_id,
		"missing_after": missing_after.duplicate(),
	}


func _checkpoint_has_public_progress(
	checkpoint: Dictionary,
	node_by_id: Dictionary,
	visited: Dictionary
) -> bool:
	var checkpoint_id := str(checkpoint.get("node_id", ""))
	if checkpoint_id == "" or visited.has(checkpoint_id):
		return true
	var next_visited := visited.duplicate()
	next_visited[checkpoint_id] = true
	var branches: Array = checkpoint.get("branches", []) \
		if checkpoint.get("branches", []) is Array else []
	if branches.is_empty():
		return true
	for raw_branch: Variant in branches:
		if not (raw_branch is Dictionary):
			return true
		var guards: Array = (raw_branch as Dictionary).get("when_all", []) \
			if (raw_branch as Dictionary).get("when_all", []) is Array else []
		if not _typed_missing_cost_proves_guards_false(guards):
			return true
	var otherwise := str(checkpoint.get("otherwise", ""))
	if otherwise in ["replan", "local_best", "rules_fallback"]:
		return true
	var otherwise_node: Dictionary = node_by_id.get(otherwise, {}) \
		if node_by_id.get(otherwise, {}) is Dictionary else {}
	var otherwise_kind := str(otherwise_node.get("kind", ""))
	if otherwise_kind == "terminal":
		return false
	if otherwise_kind == "checkpoint":
		return _checkpoint_has_public_progress(otherwise_node, node_by_id, next_visited)
	# A route successor is progress; unknown shapes fail open and remain under the
	# schema validator's authority.
	return true


func _typed_missing_cost_proves_guards_false(guards: Array) -> bool:
	for raw_guard: Variant in guards:
		if not (raw_guard is Dictionary):
			continue
		var guard: Dictionary = raw_guard
		if str(guard.get("fact", "")) in ["attack.ready", "attack.ko_available"] \
				and str(guard.get("op", "")) == "==" \
				and bool(guard.get("value", false)):
			return true
	return false


func _candidate_typed_attachment(candidate: Dictionary) -> Dictionary:
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	var canonical: Dictionary = {}
	for raw_annotation: Variant in annotations.values():
		if not (raw_annotation is Dictionary):
			continue
		for key: String in ["attachment", "typed_attachment"]:
			var attachment: Variant = (raw_annotation as Dictionary).get(key, {})
			if not (attachment is Dictionary) or (attachment as Dictionary).is_empty():
				continue
			var current: Dictionary = (attachment as Dictionary).duplicate(true)
			if canonical.is_empty():
				canonical = current
				continue
			for proof_key: String in [
				"target_slot_id", "target_uid", "target_is_active",
				"completes_required_types", "missing_after",
			]:
				if canonical.get(proof_key) != current.get(proof_key):
					return {}
	return canonical


func _select_route(
	route_id: String,
	frontier: Array[Dictionary],
	owner: String,
	candidate_id: String = ""
) -> void:
	var route := _route_search.find_candidate(frontier, candidate_id) if candidate_id != "" else _route_search.find_route(frontier, route_id)
	if route.is_empty() and not frontier.is_empty():
		route = frontier[0]
		owner = "local_gate" if owner != "rules_fallback" else owner
	_current_route_id = str(route.get("route_id", ""))
	_preferred_candidate_id = str(route.get("candidate_id", ""))
	_preferred_action_id = str(route.get("safe_prefix_action_id", ""))
	_current_action_owner = owner if owner in ContractsScript.ACTION_OWNERS else "local_gate"
	_route_selection_bonus = _required_selection_bonus(route, frontier)
	_active_module_certificate_kind = _verified_module_certificate_kind(route)


func _verified_module_certificate_kind(candidate: Dictionary) -> String:
	var annotations: Dictionary = candidate.get("module_annotations", {}) \
		if candidate.get("module_annotations", {}) is Dictionary else {}
	for raw_annotation: Variant in annotations.values():
		if not (raw_annotation is Dictionary):
			continue
		if bool((raw_annotation as Dictionary).get("verified_advantage", false)):
			return str((raw_annotation as Dictionary).get("verified_advantage_kind", ""))
	return ""


func _activate_verified_upgrade_certificate(upgrade: Dictionary) -> void:
	var advantage: Dictionary = upgrade.get("verified_advantage", {}) \
		if upgrade.get("verified_advantage", {}) is Dictionary else {}
	var certificate_kind := str(advantage.get("certificate_kind", ""))
	if certificate_kind != "":
		_active_module_certificate_kind = certificate_kind
	var continuation_key := str(advantage.get("continuation_key", ""))
	var stage := str(advantage.get("stage", ""))
	var observation_hash := str(advantage.get("observation_hash_provenance", ""))
	if certificate_kind == "profiled_visible_engine_hold" \
			and continuation_key != "" \
			and stage in [
				"manual_psychic_to_active", "first_embrace_to_active",
				"second_embrace_to_active", "active_gardevoir_190_ko",
			] \
			and observation_hash != "":
		_profiled_gardevoir_suffix_ticket = {
			"turn": _current_turn,
			"deck_id": int(_profile.get("deck_id", 0)),
			"certificate_kind": certificate_kind,
			"continuation_key": continuation_key,
			"stage": stage,
			"action_id": str(upgrade.get("safe_prefix_action_id", "")),
			"candidate_id": str(upgrade.get("candidate_id", "")),
			"observation_hash_provenance": observation_hash,
		}


func _required_selection_bonus(selected: Dictionary, frontier: Array[Dictionary]) -> float:
	# Route validation decides whether a switch is safe. Once approved, scoring
	# must faithfully execute its exact candidate even when the Rule strategy
	# uses a large negative sentinel for actions it normally suppresses.
	var selected_score := float(selected.get("base_score", selected.get("local_score", 0.0)))
	var rule_top_score := selected_score
	for candidate: Dictionary in frontier:
		rule_top_score = maxf(
			rule_top_score,
			float(candidate.get("base_score", candidate.get("local_score", 0.0)))
		)
	var required := rule_top_score - selected_score + 1000.0
	return clampf(maxf(ROUTE_SELECTION_BONUS, required), ROUTE_SELECTION_BONUS, MAX_ROUTE_SELECTION_BONUS)


func _clear_route(owner: String) -> void:
	_policy_graph.clear()
	_execution_cursor.clear()
	_current_route_id = ""
	_preferred_candidate_id = ""
	_preferred_action_id = ""
	_current_action_owner = owner
	_route_selection_bonus = ROUTE_SELECTION_BONUS
	_active_module_certificate_kind = ""
	_profiled_gardevoir_interaction_ticket.clear()
	_profiled_gardevoir_suffix_ticket.clear()


func _route_ids(frontier: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for route: Dictionary in frontier:
		var route_id := str(route.get("route_id", ""))
		if route_id != "" and not result.has(route_id):
			result.append(route_id)
	return result


func _candidate_ids(frontier: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for candidate: Dictionary in frontier:
		var candidate_id := str(candidate.get("candidate_id", ""))
		if candidate_id != "" and not result.has(candidate_id):
			result.append(candidate_id)
	return result


func _root_route_ref(policy: Dictionary) -> Dictionary:
	var root_id := str(policy.get("root_node_id", ""))
	for raw_node: Variant in policy.get("nodes", []):
		if raw_node is Dictionary and str((raw_node as Dictionary).get("node_id", "")) == root_id:
			var route_ref: Variant = (raw_node as Dictionary).get("route_ref", {})
			if route_ref is Dictionary:
				return (route_ref as Dictionary).duplicate(true)
	return {}


func _root_route_id(policy: Dictionary) -> String:
	return str(_root_route_ref(policy).get("route_id", ""))


func _model_owns_current_route() -> bool:
	return _current_action_owner in [
		"model_selected_local_route",
		"model_synthesized_route",
		"policy_graph_branch",
	]


func _interaction_route_context() -> String:
	var cursor_route := _execution_cursor.current_route_id()
	return cursor_route if cursor_route != "" else _current_route_id


func _apply_agenda_patch(patch: Dictionary) -> void:
	for key: String in ["victory_mode", "prize_path", "attacker_chain", "protected_resources", "opponent_threat_posture", "risk_posture", "expires_when"]:
		if patch.has(key):
			_match_agenda[key] = patch.get(key)


func _update_last_state(observation: Dictionary, facts: Dictionary, frontier: Array[Dictionary]) -> void:
	_last_observation = observation.duplicate(true)
	_last_facts = facts.duplicate(true)
	_last_frontier = frontier.duplicate(true)


func _with_public_flow_facts(facts: Dictionary, observation: Dictionary) -> Dictionary:
	var result := facts.duplicate(true)
	var flow: Dictionary = _profile.get("public_flow", {}) \
		if _profile.get("public_flow", {}) is Dictionary else {}
	var reset_uids: Array[String] = []
	for raw_uid: Variant in flow.get("hand_reset_to_deck_uids", []):
		reset_uids.append(str(raw_uid).strip_edges().to_upper())
	var completed_uid := str(_unconsumed_action_result.get("action_card_uid", "")).strip_edges().to_upper()
	if reset_uids.is_empty() \
			or completed_uid not in reset_uids \
			or not bool(_unconsumed_action_result.get("success", false)) \
			or _last_observation.is_empty():
		return result
	var previous_own: Dictionary = _last_observation.get("own", {}) \
		if _last_observation.get("own", {}) is Dictionary else {}
	var current_own: Dictionary = observation.get("own", {}) \
		if observation.get("own", {}) is Dictionary else {}
	var previous_counts := _visible_hand_uid_counts(previous_own)
	var current_counts := _visible_hand_uid_counts(current_own)
	var known_in_deck: Dictionary = {}
	for raw_uid: Variant in previous_counts.keys():
		var uid := str(raw_uid)
		var guaranteed := maxi(0, int(previous_counts.get(uid, 0)) - int(current_counts.get(uid, 0)))
		if guaranteed > 0:
			known_in_deck[uid] = guaranteed
	if known_in_deck.is_empty():
		return result
	var belief: Dictionary = result.get("belief", {}) \
		if result.get("belief", {}) is Dictionary else {}
	belief["known_in_deck_uid_counts"] = known_in_deck
	belief["evidence_kind"] = "public_hand_reset_transition"
	belief["source_action_uid"] = completed_uid
	result["belief"] = belief
	return result


func _visible_hand_uid_counts(side: Dictionary) -> Dictionary:
	var counts: Dictionary = {}
	for raw_card: Variant in side.get("hand", []):
		if not (raw_card is Dictionary):
			continue
		var uid := str((raw_card as Dictionary).get("uid", "")).strip_edges().to_upper()
		if uid != "":
			counts[uid] = int(counts.get(uid, 0)) + 1
	return counts


func _trace_filtered_state(
	observation: Dictionary,
	facts: Dictionary,
	frontier: Array[Dictionary]
) -> void:
	var trace_root := OS.get_environment("V18CPG_TRACE_STATE_DIR").strip_edges()
	if trace_root == "":
		return
	var absolute_root := trace_root
	if not absolute_root.is_absolute_path():
		absolute_root = ProjectSettings.globalize_path("res://").path_join(absolute_root)
	DirAccess.make_dir_recursive_absolute(absolute_root)
	var match_id := str(_lifecycle.get("match_id", "match")).validate_filename()
	var turn_id := int(observation.get("turn", {}).get("number", _current_turn))
	var observation_version := int(observation.get("observation_version", 0))
	var path := absolute_root.path_join(
		"%s_t%d_o%d.json" % [match_id, turn_id, observation_version]
	)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"schema_version": ContractsScript.SCHEMA_VERSION,
		"match_id": str(_lifecycle.get("match_id", "")),
		"turn_id": turn_id,
		"observation": _compact_observation_for_model(observation),
		"facts": facts.duplicate(true),
		"frontier": _compact_frontier_for_model(frontier),
		"active_graph_origin": _policy_graph.origin(),
		"current_route_id": _current_route_id,
	}, "\t"))
	file.close()


func _compact_interaction_debug_items(items: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item: Variant in items:
		if item is CardInstance:
			var card := item as CardInstance
			var data := card.card_data
			result.append({
				"kind": "card",
				"instance_id": int(card.instance_id),
				"uid": data.get_uid().strip_edges().to_upper() if data != null else "",
				"name": str(data.name) if data != null else "",
				"card_type": str(data.card_type) if data != null else "",
			})
		elif item is PokemonSlot:
			var slot := item as PokemonSlot
			var top := slot.get_top_card()
			var top_data := top.card_data if top != null else null
			result.append({
				"kind": "pokemon_slot",
				"slot_id": "slot:%d" % (int(top.instance_id) if top != null else -1),
				"uid": top_data.get_uid().strip_edges().to_upper() if top_data != null else "",
				"name": str(top_data.name) if top_data != null else "",
			})
		else:
			result.append({"kind": typeof(item), "value": str(item)})
	return result


func _record_planning(
	event_type: String,
	started_msec: int,
	branch_hit: bool,
	delta: Dictionary,
	extra: Dictionary
) -> void:
	var record := {
		"turn_id": _current_turn,
		"policy_id": str(_lifecycle.get("policy_id", "")),
		"revision_id": str(_lifecycle.get("revision_id", "")),
		"node_id": _policy_graph.current_node_id(),
		"route_id": _current_route_id,
		"candidate_id": _preferred_candidate_id,
		"deck_id": int(_profile.get("deck_id", 0)),
		"strategy_id": get_strategy_id(),
		"profile_version": int(_profile.get("profile_version", 1)),
		"semantic_version": int(_profile.get("semantic_version", 1)),
		"schema_version": str(_profile.get("schema_version", "")),
		"observation_version": int(_last_observation.get("observation_version", 0)),
		"observation_hash": str(_last_observation.get("observation_hash", "")),
		"frontier_hash": ContractsScript.stable_hash(_last_frontier),
		"material_delta_hash": str(delta.get("material_delta_hash", "")),
		"event_type": event_type,
		"graph_branch_hit": branch_hit,
		"action_owner": _current_action_owner,
		"local_planning_ms": maxi(0, Time.get_ticks_msec() - started_msec),
	}
	for key: Variant in extra.keys():
		record[key] = extra[key]
	_audit.record(record)


func _record_policy_response(
	accepted: bool,
	reason: String,
	metrics: Dictionary,
	fallback_override: String = "",
	extra: Dictionary = {}
) -> void:
	var fallback_layer := "" if accepted else (fallback_override if fallback_override != "" else _current_action_owner)
	var record := {
		"turn_id": _current_turn,
		"policy_id": str(_lifecycle.get("policy_id", "")),
		"revision_id": str(_lifecycle.get("revision_id", "")),
		"node_id": _policy_graph.current_node_id(),
		"route_id": _current_route_id,
		"candidate_id": _preferred_candidate_id,
		"decision_window_id": str(_lifecycle.get("decision_window_id", "")),
		"request_id": str(_lifecycle.get("request_id", "")),
		"deck_id": int(_profile.get("deck_id", 0)),
		"strategy_id": get_strategy_id(),
		"event_type": "policy_response",
		"accepted": accepted,
		"action_owner": _current_action_owner,
		"fallback_layer": fallback_layer,
		"fallback_reason": reason,
		"request_wall_ms": int(metrics.get("request_wall_ms", 0)),
		"visible_wait_ms": int(metrics.get("visible_wait_ms", 0)),
		"payload_bytes": int(metrics.get("payload_bytes", 0)),
		"response_bytes": int(metrics.get("response_bytes", 0)),
	}
	for raw_key: Variant in extra.keys():
		record[str(raw_key)] = extra.get(raw_key)
	_audit.record(record)
	v18cpg_decision_ready.emit(_current_turn, accepted, reason)


func _reset_match_state() -> void:
	_belief.reset()
	_last_observation.clear()
	_last_facts.clear()
	_last_frontier.clear()
	_match_agenda.clear()
	_current_turn = -1
	_revision_serial = 0
	_request_serial = 0
	_lifecycle.clear()
	_pending_request_id = ""
	_pending_context.clear()
	_pending_request_started_msec = 0
	_pending_request_visible_budget_ms = 0
	_handled_delta_hashes.clear()
	_policy_graph.clear()
	_execution_cursor.clear()
	_preferred_action_id = ""
	_preferred_candidate_id = ""
	_current_route_id = ""
	_current_action_owner = "rules_fallback"
	_route_selection_bonus = ROUTE_SELECTION_BONUS
	_active_module_certificate_kind = ""
	_branch_hits = 0
	_uncovered_events = 0
	_turn_visible_wait_ms = 0
	_turn_model_requests = 0
	_request_wait_samples_ms.clear()
	_unconsumed_action_result.clear()
