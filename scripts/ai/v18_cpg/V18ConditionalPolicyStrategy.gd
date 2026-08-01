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
const TurnCompletionSolverScript = preload("res://scripts/ai/v18_cpg/planning/V18CPGTurnCompletionSolver.gd")
const HardGuardScript = preload("res://scripts/ai/v18_cpg/planning/V18CPGHardGuard.gd")
const RouteValueGraphScript = preload(
	"res://scripts/ai/v18_cpg/planning/route_value/V18CPGRouteValueGraph.gd"
)
const OpponentResponseEnvelopeV2Script = preload(
	"res://scripts/ai/v18_cpg/planning/route_value/V18CPGOpponentResponseEnvelopeV2.gd"
)
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
const EventBridgeScript = preload("res://scripts/ai/v18_cpg/runtime/V18CPGEventBridge.gd")

const ROUTE_SELECTION_BONUS := 20000.0
const MAX_ROUTE_SELECTION_BONUS := 250000.0
const ROUTE_MISMATCH_PENALTY := 350.0
const HARD_BLOCK_SCORE := -1000000000000.0
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
var _turn_completion_solver = TurnCompletionSolverScript.new()
var _hard_guard = HardGuardScript.new()
var _route_value_graph = RouteValueGraphScript.new()
var _opponent_response_v2 = OpponentResponseEnvelopeV2Script.new()
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
var _event_bridge = EventBridgeScript.new()

var _runtime_configured: bool = false
var _last_observation: Dictionary = {}
var _last_facts: Dictionary = {}
var _last_frontier: Array[Dictionary] = []
var _hard_blocked_action_ids: Dictionary = {}
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
var _last_route_value_metrics: Dictionary = {}
var _branch_hits: int = 0
var _uncovered_events: int = 0
var _turn_visible_wait_ms: int = 0
var _turn_model_requests: int = 0
var _turn_model_judgment_attempted: bool = false
var _turn_model_judgment_requested: bool = false
var _turn_model_judgment_resolved: bool = false
var _request_wait_samples_ms: Array[float] = []
var _unconsumed_action_result: Dictionary = {}
var _pending_action_ownership_ticket: Dictionary = {}
var _route_selection_bonus: float = ROUTE_SELECTION_BONUS
var _pending_request_started_msec: int = 0
var _pending_request_visible_budget_ms: int = 0
var _active_module_certificate_kind: String = ""
var _profiled_gardevoir_interaction_ticket: Dictionary = {}
var _profiled_gardevoir_suffix_ticket: Dictionary = {}
var _runtime_host: Node = null
var _provider_terminal_failure_reason: String = ""


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
	# Reconfiguration is an explicit recovery boundary: the player may have
	# repaired credentials or replenished provider balance.
	_provider_terminal_failure_reason = ""
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


func configure_live_audit() -> void:
	# Live audit is V18-only and uses wall-clock/object identity rather than
	# gameplay RNG. This keeps production matches replay-attributable without
	# perturbing shuffles, coin flips, or action selection.
	var timestamp := Time.get_datetime_string_from_system(false, false) \
		.replace("-", "").replace(":", "")
	var day := timestamp.substr(0, 8)
	_audit.configure(
		"live_%s" % day,
		"match_%s_%d" % [timestamp, get_instance_id()],
		true
	)


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
		"route_value_graph_version": ContractsScript.ROUTE_VALUE_GRAPH_VERSION,
		"route_value_graph_feature_flag": (
			ContractsScript.ROUTE_VALUE_GRAPH_FEATURE_FLAG
		),
		"route_value_graph_mode": (
			"live" if RouteValueGraphScript.is_enabled(_profile)
			else "shadow" if RouteValueGraphScript.should_compute(_profile)
			else "off"
		),
		"experimental": bool(_profile.get("experimental", true)),
		"battle_setup_available": bool(_profile.get("battle_setup_available", false)),
		"promotion_status": str(_profile.get("promotion_status", "experimental")),
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
	candidate_pool = _turn_completion_solver.annotate_frontier(
		candidate_pool,
		observation,
		facts,
		_profile
	)
	var completion_facts := _with_turn_completion_facts(
		facts,
		observation,
		candidate_pool
	)
	candidate_pool = _capability_registry.annotate_frontier_post_completion(
		candidate_pool,
		observation,
		completion_facts,
		_profile,
		_semantic_manifest
	)
	facts = _with_prize_clock_facts(
		completion_facts,
		observation,
		candidate_pool
	)
	if _runtime_configured:
		var hard_guard_result := _apply_runtime_hard_guards(
			candidate_pool,
			observation,
			facts
		)
		candidate_pool = _typed_candidate_array(
			hard_guard_result.get("candidates", [])
		)
		facts = (
			hard_guard_result.get("facts", {}) as Dictionary
		).duplicate(true) if hard_guard_result.get(
			"facts",
			{}
		) is Dictionary else facts
		_hard_blocked_action_ids = (
			hard_guard_result.get("blocked_action_ids", {}) as Dictionary
		).duplicate(true) if hard_guard_result.get(
			"blocked_action_ids",
			{}
		) is Dictionary else {}
		facts["hard_guard"] = {
			"blocked": (
				hard_guard_result.get("blocked", []) as Array
			).duplicate(true) if hard_guard_result.get(
				"blocked",
				[]
			) is Array else [],
			"blocked_count": _hard_blocked_action_ids.size(),
		}
	else:
		_hard_blocked_action_ids.clear()
	if RouteValueGraphScript.should_compute(_profile):
		var route_value_candidate_pool := _route_value_graph.annotate_candidate_pool(
			candidate_pool,
			observation,
			facts,
			_resource_ledger.build(
				observation,
				_semantic_manifest,
				_profile,
				_belief.snapshot()
			),
			_profile
		)
		_last_route_value_metrics = _route_value_graph.last_metrics()
		# Shadow mode measures the complete v3 graph but keeps Graph v2
		# candidates, transport, verified-local ownership, and Rule fallback
		# unchanged until the real-model promotion gate is satisfied.
		if RouteValueGraphScript.is_enabled(_profile):
			candidate_pool = route_value_candidate_pool
	else:
		_last_route_value_metrics.clear()
	# The terminal
	# skip proof must compare every legal candidate against that same Rule floor,
	# including candidates that do not fit into the ten-item model frontier.
	var model_candidate_pool := _route_value_graph.prune_model_candidates(
		candidate_pool,
		10
	) if RouteValueGraphScript.is_enabled(_profile) else candidate_pool
	var frontier := _route_search.prune_frontier(model_candidate_pool, 10)
	frontier = _bind_engine_rule_floor(frontier, rule_floor_action_id)
	facts = _with_route_availability_facts(facts, frontier)
	facts = _with_turn_completion_facts(facts, observation, frontier)
	facts = _with_prize_clock_facts(facts, observation, frontier)
	facts = _with_route_decision_right_facts(facts, frontier)
	_refresh_match_agenda_from_prize_clock(facts)
	var force_turn_model_judgment := _should_force_turn_model_judgment(event_context)
	_trace_filtered_state(observation, facts, frontier)
	# The match's first observation has no material delta, so the normal post-action
	# certificate hook below cannot run yet.  The allowlist remains deliberately
	# narrow: a paired opening-counter proof, or an exact same-quota attachment
	# that immediately completes the current Active's public attack cost.
	if _runtime_configured and _last_observation.is_empty():
		var initial_upgrade := _find_module_verified_upgrade(frontier, facts)
		if _can_apply_initial_module_upgrade(initial_upgrade) \
				and (
					not force_turn_model_judgment \
					or _verified_upgrade_preempts_model_judgment(
						initial_upgrade
					)
				):
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
	var deferred_verified_upgrade: Dictionary = {}
	if not _last_observation.is_empty() and str(observation.get("observation_hash", "")) != str(_last_observation.get("observation_hash", "")):
		var delta: Dictionary = _material_delta.compare(
			_last_observation,
			observation,
			_last_facts,
			facts
		)
		var completed_action := _unconsumed_action_result.duplicate(true)
		_unconsumed_action_result.clear()
		delta = _enrich_material_delta_with_information_event(delta, completed_action)
		var delta_hash := str(delta.get("material_delta_hash", ""))
		# Once the turn's required model judgment has been accepted, the shared
		# completion solver owns the exact ordering of its public, monotonic
		# engine prefixes. This is what lets Area Zero -> Hoothoot -> Noctowl ->
		# Ogerpon continue across fresh observations without another model call or
		# a stale graph branch jumping straight back to attack.
		if _runtime_configured \
				and _turn_model_judgment_resolved \
				and not force_turn_model_judgment:
			var completion_continuation := _completion_override_for_rule_root(
				frontier,
				facts,
				observation
			)
			if bool(completion_continuation.get("handled", false)):
				_install_turn_completion_override(
					completion_continuation,
					frontier
				)
				_update_last_state(observation, facts, frontier)
				_record_planning(
					"turn_completion_prefix_continue",
					started_msec,
					false,
					delta,
					{
						"candidate_id": _preferred_candidate_id,
						"action_id": _preferred_action_id,
						"completion_reason": str(
							completion_continuation.get("reason", "")
						),
					}
				)
				return {
					"status": "ready",
					"owner": _current_action_owner,
					"route_id": _current_route_id,
					"candidate_id": _preferred_candidate_id,
				}
		if _runtime_configured:
			var verified_upgrade := _find_module_verified_upgrade(frontier, facts)
			if not verified_upgrade.is_empty() \
					and _model_checkpoint_precedes_verified_upgrade():
				# Do not silently erase an accepted model graph before its typed
				# checkpoint is even evaluated. The graph branch is resolved
				# below, then arbitrated against this deterministic certificate.
				deferred_verified_upgrade = verified_upgrade.duplicate(true)
			elif not verified_upgrade.is_empty() \
					and (
						not force_turn_model_judgment \
						or _verified_upgrade_preempts_model_judgment(
							verified_upgrade
						)
					):
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
		if not reopen_information_epoch \
				and _policy_graph.origin() == "model_shadow_rule_root" \
				and bool(completed_action.get("success", false)) \
				and bool(completed_action.get("information_event", false)):
			_record_planning(
				"model_shadow_information_epoch_retained",
				started_msec,
				false,
				delta,
				{
					"completed_route_id": str(
						completed_action.get("route_id", "")
					),
					"completed_candidate_id": str(
						completed_action.get("candidate_id", "")
					),
				}
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
				if not deferred_verified_upgrade.is_empty() \
						and branch_candidate_id != str(
							deferred_verified_upgrade.get("candidate_id", "")
						):
					_install_post_judgment_verified_upgrade(
						deferred_verified_upgrade,
						frontier
					)
					_update_last_state(observation, facts, frontier)
					_record_planning(
						"model_graph_preempted_by_verified_upgrade",
						started_msec,
						false,
						delta,
						{
							"model_branch_candidate_id": branch_candidate_id,
							"verified_candidate_id": _preferred_candidate_id,
							"fallback_reason": "stronger_public_certificate",
						}
					)
					return {
						"status": "ready",
						"owner": _current_action_owner,
						"route_id": _current_route_id,
						"candidate_id": _preferred_candidate_id,
					}
				var branch_safety := _validate_model_route_safety(
					str(transition.get("route_id", "")),
					frontier,
					facts,
					branch_candidate_id
				) if branch_owner == "policy_graph_branch" else {"valid": true}
				if not bool(branch_safety.get("valid", false)):
					if not deferred_verified_upgrade.is_empty():
						_install_post_judgment_verified_upgrade(
							deferred_verified_upgrade,
							frontier
						)
					else:
						_install_local_policy(frontier, "local_gate")
					_update_last_state(observation, facts, frontier)
					_record_planning("unsafe_graph_branch_fallback", started_msec, false, delta, {
						"fallback_reason": str(branch_safety.get("reason", "graph_branch_validation_failed")),
						"verified_candidate_id": (
							_preferred_candidate_id
							if not deferred_verified_upgrade.is_empty()
							else ""
						),
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
				if not deferred_verified_upgrade.is_empty():
					# The model chose the same exact action as the independent
					# public-state certificate. Keep model graph ownership while
					# carrying the certificate into nested interaction handling.
					_activate_verified_upgrade_certificate(
						deferred_verified_upgrade
					)
				_update_last_state(observation, facts, frontier)
				_record_planning("graph_branch", started_msec, true, delta, {})
				return {"status": "ready", "owner": _current_action_owner, "route_id": _current_route_id, "candidate_id": _preferred_candidate_id}
			if str(transition.get("status", "")) == "local_best":
				if not deferred_verified_upgrade.is_empty():
					_install_post_judgment_verified_upgrade(
						deferred_verified_upgrade,
						frontier
					)
				else:
					_install_local_policy(frontier, "local_gate")
				_update_last_state(observation, facts, frontier)
				_record_planning("local_branch", started_msec, false, delta, {})
				return {"status": "ready", "owner": _current_action_owner, "route_id": _current_route_id}
			if str(transition.get("status", "")) == "rules_fallback":
				if not deferred_verified_upgrade.is_empty():
					_install_post_judgment_verified_upgrade(
						deferred_verified_upgrade,
						frontier
					)
					_update_last_state(observation, facts, frontier)
					_record_planning(
						"model_graph_rules_fallback_verified_upgrade",
						started_msec,
						false,
						delta,
						{"candidate_id": _preferred_candidate_id}
					)
					return {
						"status": "ready",
						"owner": _current_action_owner,
						"route_id": _current_route_id,
						"candidate_id": _preferred_candidate_id,
					}
				_clear_route("rules_fallback")
				_update_last_state(observation, facts, frontier)
				return {"status": "rules_fallback", "reason": "policy_otherwise"}
			if not _information_event_requires_delta_replan(completed_action, delta):
				_install_local_policy(frontier, "local_gate")
				_update_last_state(observation, facts, frontier)
				_record_planning("non_material_local_continue", started_msec, false, delta, {})
				return {"status": "ready", "owner": _current_action_owner, "route_id": _current_route_id}
			_uncovered_events += 1
			delta_for_request = delta.duplicate(true)
			request_is_delta = true
		if not deferred_verified_upgrade.is_empty():
			_install_post_judgment_verified_upgrade(
				deferred_verified_upgrade,
				frontier
			)
			_update_last_state(observation, facts, frontier)
			_record_planning(
				"model_graph_replan_verified_upgrade",
				started_msec,
				false,
				delta,
				{"candidate_id": _preferred_candidate_id}
			)
			return {
				"status": "ready",
				"owner": _current_action_owner,
				"route_id": _current_route_id,
				"candidate_id": _preferred_candidate_id,
			}
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
			_graph_reentry_action_owner(),
			_policy_graph.current_candidate_id()
		)
		_update_last_state(observation, facts, frontier)
		return {"status": "ready", "owner": _current_action_owner, "route_id": _current_route_id, "candidate_id": _preferred_candidate_id}
	var pre_judgment_prefix := _pre_judgment_completion_override(
		frontier,
		facts,
		observation,
		force_turn_model_judgment
	)
	if bool(pre_judgment_prefix.get("handled", false)):
		# This prefix is a deterministic public-state obligation, not a model
		# choice. Execute it first and keep the required judgment unopened so the
		# model sees the state in which it can actually own a decision.
		_install_turn_completion_override(pre_judgment_prefix, frontier)
		_update_last_state(observation, facts, frontier)
		_record_planning(
			"pre_judgment_turn_completion_prefix",
			started_msec,
			false,
			delta_for_request,
			{
				"candidate_id": _preferred_candidate_id,
				"action_id": _preferred_action_id,
				"completion_reason": str(
					pre_judgment_prefix.get("reason", "")
				),
				"turn_model_judgment_required": true,
			}
		)
		return {
			"status": "ready",
			"owner": _current_action_owner,
			"route_id": _current_route_id,
			"candidate_id": _preferred_candidate_id,
		}
	var terminal_skip := _should_skip_terminal_without_admissible_switch(candidate_pool, facts)
	if bool(terminal_skip.get("skip", false)):
		# This is not a local strategic rewrite. Production safety checked the full
		# annotated legal pool and found no admissible non-Rule root switch. Keep a
		# one-shot Rule selection: a later observation must be evaluated afresh and
		# must not advance through a reusable fallback graph.
		if force_turn_model_judgment:
			_resolve_turn_model_judgment_without_request(
				"provably_terminal_no_admissible_switch"
			)
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
	if _provider_terminal_failure_reason != "":
		# Quota/auth failures cannot recover through another same-match request.
		# Runtime-local certificates and hard guards must also switch off: outage
		# behavior is the exact Rule strategy, not a verified-local variant.
		if _requires_turn_model_judgment():
			_resolve_turn_model_judgment_without_request(
				_provider_terminal_failure_reason
			)
		_install_one_shot_rules_floor(frontier)
		_update_last_state(observation, facts, frontier)
		_record_planning(
			"provider_terminal_circuit_open",
			started_msec,
			false,
			delta_for_request,
			{"fallback_reason": _provider_terminal_failure_reason}
		)
		return {
			"status": "ready",
			"owner": _current_action_owner,
			"route_id": _current_route_id,
			"candidate_id": _preferred_candidate_id,
		}
	var local_decision := _should_use_local(frontier, facts)
	if bool(local_decision.get("use_local", false)) and not force_turn_model_judgment \
			or not _runtime_configured:
		var fallback_owner := "local_gate" if _runtime_configured else "rules_fallback"
		_install_local_policy(frontier, fallback_owner)
		_update_last_state(observation, facts, frontier)
		_record_planning("local_policy", started_msec, false, {}, {"fallback_reason": str(local_decision.get("reason", "runtime_unconfigured"))})
		return {"status": "ready", "owner": _current_action_owner, "route_id": _current_route_id}
	var effective_wait_budget_ms := _effective_turn_visible_wait_budget_ms()
	var wait_gate := _visible_wait_budget.may_request(
		_turn_visible_wait_ms,
		_request_wait_samples_ms,
		_turn_model_requests,
		effective_wait_budget_ms,
		int(_profile.get("cold_request_estimate_ms", 6500))
	)
	if not bool(wait_gate.get("allowed", false)):
		_install_wait_budget_fallback(frontier)
		_update_last_state(observation, facts, frontier)
		_record_planning("visible_wait_budget_fallback", started_msec, false, delta_for_request, {
			"fallback_reason": str(wait_gate.get("reason", "visible_wait_budget_exhausted")),
			"expected_request_ms": int(wait_gate.get("expected_request_ms", 0)),
			"remaining_visible_wait_ms": int(wait_gate.get("remaining_ms", 0)),
			"effective_turn_visible_wait_budget_ms": effective_wait_budget_ms,
		})
		return {"status": "ready", "owner": _current_action_owner, "route_id": _current_route_id}
	_request_serial += 1
	_lifecycle["decision_window_id"] = "%s:w%d" % [str(_lifecycle.get("policy_id", "policy")), _request_serial]
	_lifecycle["request_id"] = "%s:q%d" % [str(_lifecycle.get("policy_id", "policy")), _request_serial]
	var request_envelope := _build_request_envelope(
		observation,
		facts,
		frontier,
		delta_for_request,
		force_turn_model_judgment
	)
	var request_id := str(_lifecycle.get("request_id", ""))
	var request_intent := _request_intent(
		request_is_delta,
		force_turn_model_judgment
	)
	request_envelope["request_intent"] = request_intent
	var configured_token_budget := (
		int(_profile.get("delta_response_token_budget", 220))
		if request_is_delta
		else int(_profile.get("initial_response_token_budget", 600))
	)
	var effective_token_budget := DecisionClientScript.new().resolve_token_budget(
		configured_token_budget,
		request_is_delta,
		int(request_envelope.get("limits", {}).get(
			"max_policy_nodes",
			4
		))
	)
	var request_error := _decision_client.request_policy(
		request_id,
		request_envelope,
		configured_token_budget,
		request_is_delta
	)
	if request_error != OK:
		if force_turn_model_judgment:
			_turn_model_judgment_attempted = true
			# A request that cannot start is a resolved failed judgment, just like
			# a live timeout/rejection. This keeps the deterministic continuation
			# state identical in verified-local and real-transport fallback arms.
			_turn_model_judgment_resolved = true
			_audit.record({
				"turn_id": _current_turn,
				"policy_id": str(_lifecycle.get("policy_id", "")),
				"request_id": request_id,
				"deck_id": int(_profile.get("deck_id", 0)),
				"strategy_id": get_strategy_id(),
				"event_type": "turn_model_judgment_request_failed",
				"turn_model_judgment_required": true,
				"turn_model_judgment": true,
				"fallback_reason": "request_error_%d" % request_error,
			})
		_install_verified_reference_fallback(
			frontier,
			facts,
			observation,
			"deadline_fallback"
		)
		_update_last_state(observation, facts, frontier)
		_record_planning("request_start_failed", started_msec, false, {}, {"fallback_reason": "request_error_%d" % request_error})
		return {"status": "ready", "owner": _current_action_owner, "route_id": _current_route_id}
	_audit.record({
		"turn_id": _current_turn,
		"policy_id": str(_lifecycle.get("policy_id", "")),
		"decision_window_id": str(_lifecycle.get("decision_window_id", "")),
		"request_id": request_id,
		"deck_id": int(_profile.get("deck_id", 0)),
		"strategy_id": get_strategy_id(),
		"event_type": "model_request_started",
		"is_delta": request_is_delta,
		"request_intent": request_intent,
		"configured_token_budget": configured_token_budget,
		"token_budget": effective_token_budget,
		"effective_turn_visible_wait_budget_ms": effective_wait_budget_ms,
		"turn_visible_wait_spent_ms": _turn_visible_wait_ms,
	})
	_audit.record_payload({
		"turn_id": _current_turn,
		"policy_id": str(_lifecycle.get("policy_id", "")),
		"decision_window_id": str(_lifecycle.get("decision_window_id", "")),
		"request_id": request_id,
		"deck_id": int(_profile.get("deck_id", 0)),
		"strategy_id": get_strategy_id(),
		"event_type": "model_request",
		"is_delta": request_is_delta,
		"request_intent": request_intent,
		"request_envelope": request_envelope,
	})
	if force_turn_model_judgment:
		_turn_model_judgment_attempted = true
		_turn_model_judgment_requested = true
		_audit.record({
			"turn_id": _current_turn,
			"policy_id": str(_lifecycle.get("policy_id", "")),
			"decision_window_id": str(_lifecycle.get("decision_window_id", "")),
			"request_id": request_id,
			"deck_id": int(_profile.get("deck_id", 0)),
			"strategy_id": get_strategy_id(),
			"event_type": "turn_model_judgment_requested",
			"turn_model_judgment_required": true,
		})
	_turn_model_requests += 1
	_pending_request_id = request_id
	_pending_request_started_msec = Time.get_ticks_msec()
	var visible_budget_remaining := maxi(
		1,
		effective_wait_budget_ms - _turn_visible_wait_ms
	)
	_pending_request_visible_budget_ms = maxi(
		1,
		visible_budget_remaining - int(_profile.get("visible_wait_deadline_headroom_ms", 250))
	)
	_pending_context = {
		"observation_version": int(observation.get("observation_version", 0)),
		"observation_hash": str(observation.get("observation_hash", "")),
		"allowed_route_ids": REGISTERED_ROUTE_IDS.duplicate(),
		"allowed_candidate_ids": (
			request_envelope.get("allowed_candidate_ids", []) as Array
		).duplicate(),
		"allowed_fact_paths": request_envelope.get(
			"allowed_fact_paths",
			[]
		).duplicate(),
		"available_route_ids": available_route_ids,
		"frontier": frontier.duplicate(true),
		"facts": facts.duplicate(true),
		"lifecycle": _lifecycle.duplicate(true),
		"is_delta": request_is_delta,
		"material_delta": delta_for_request.duplicate(true),
		"turn_model_judgment": force_turn_model_judgment,
		"request_intent": request_intent,
		"effective_turn_visible_wait_budget_ms": effective_wait_budget_ms,
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
	return float(_effective_turn_visible_wait_budget_ms()) / 1000.0


func _effective_turn_visible_wait_budget_ms(turn_number: int = -1) -> int:
	var checked_turn := _current_turn if turn_number < 0 else turn_number
	return _visible_wait_budget.budget_for_turn(
		int(_profile.get("turn_visible_wait_budget_ms", 6500)),
		maxi(1, checked_turn),
		int(_profile.get("turn_visible_wait_growth_ms", 1500)),
		int(_profile.get("turn_visible_wait_growth_every_turns", 2)),
		int(_profile.get("turn_visible_wait_budget_cap_ms", 18000))
	)


func _request_intent(
	is_delta: bool,
	required_turn_judgment: bool
) -> String:
	if is_delta:
		return "checkpoint_replan"
	if required_turn_judgment:
		return "turn_opening_graph"
	return "strategic_arbitration"


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
	var resolves_turn_model_judgment := _turn_model_judgment_requested \
		and not _turn_model_judgment_resolved
	var request_intent := str(_pending_context.get(
		"request_intent",
		"strategic_arbitration"
	))
	var request_is_delta := bool(_pending_context.get("is_delta", false))
	_pending_request_id = ""
	_pending_context.clear()
	if visible_wait_ms >= 0:
		_turn_visible_wait_ms += visible_wait_ms
		_request_wait_samples_ms.append(float(visible_wait_ms))
	_pending_request_started_msec = 0
	_pending_request_visible_budget_ms = 0
	_install_completion_aware_fallback(
		_last_frontier,
		"deadline_fallback",
		_last_facts,
		_last_observation
	)
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
		"request_intent": request_intent,
		"is_delta": request_is_delta,
		"policy_installed": false,
		"response_disposition": "deadline_fallback",
		"provider_response_received": false,
		"contract_validated": false,
		"request_wall_ms": maxi(0, visible_wait_ms),
		"visible_wait_ms": maxi(0, visible_wait_ms),
		"effective_turn_visible_wait_budget_ms": \
			_effective_turn_visible_wait_budget_ms(),
		"turn_model_judgment": resolves_turn_model_judgment,
	})
	if resolves_turn_model_judgment:
		_turn_model_judgment_resolved = true
	v18cpg_decision_ready.emit(
		_current_turn,
		false,
		_user_facing_response_reason(false, reason)
	)


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
	var action_id := _observation_gateway.stable_action_id(action)
	if _runtime_configured and _hard_blocked_action_ids.has(action_id):
		return HARD_BLOCK_SCORE
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
	typed_context["v18cpg_preferred_action_ref"] = _preferred_action_ref()
	typed_context["v18cpg_live_interaction_ref"] = \
		_live_public_interaction_ref(context)
	typed_context["turn_completion_contract"] = _turn_completion_solver.build(
		_last_observation,
		_last_facts,
		_last_frontier,
		_profile
	)
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
	# A public minimum-resource KO is an attack-effect invariant, not a route
	# ownership preference. Production intentionally installs terminal Rule
	# roots as one-shot `rules_fallback` actions, and deadline fallback may own
	# the same legal attack. Once the live attack source/index, public target HP,
	# and legal discard pool prove the payment, every configured V18CPG owner
	# must obey it. The runtime gate preserves exact Rule behavior in no-model
	# mode.
	if _runtime_configured:
		var minimum_lethal_override := \
			_capability_registry.pick_verified_interaction_override(
				items,
				step,
				rule_picks,
				typed_context,
				_profile,
				"public_minimum_resource_ko"
			)
		if bool(minimum_lethal_override.get("handled", false)):
			_audit.record({
				"turn_id": _current_turn,
				"policy_id": str(_lifecycle.get("policy_id", "")),
				"revision_id": str(_lifecycle.get("revision_id", "")),
				"node_id": _policy_graph.current_node_id(),
				"route_id": interaction_route_id,
				"candidate_id": _preferred_candidate_id,
				"deck_id": int(_profile.get("deck_id", 0)),
				"strategy_id": get_strategy_id(),
				"event_type": "minimum_lethal_interaction_override",
				"action_owner": _current_action_owner,
				"fallback_reason": "",
				"certificate_kind": str(
					minimum_lethal_override.get("certificate_kind", "")
				),
				"selected_count": (
					minimum_lethal_override.get("items", []) as Array
				).size(),
				"rule_count": rule_picks.size(),
				"target_hp": int(minimum_lethal_override.get("target_hp", 0)),
				"projected_damage": int(
					minimum_lethal_override.get("projected_damage", 0)
				),
				"live_interaction_verified": bool(
					minimum_lethal_override.get(
						"live_interaction_verified",
						false
					)
				),
			})
			return minimum_lethal_override.get("items", []) as Array
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
	if _runtime_configured and module_owned \
			and _active_module_certificate_kind in [
				"bloodmoon_closeout_recover_energy",
				"profiled_bloodmoon_closeout_recover_energy",
			]:
		var bloodmoon_recovery_override := \
			_noctowl_search.pick_verified_bloodmoon_closeout_override(
				items,
				step,
				rule_picks,
				_last_observation,
				_profile,
				_active_module_certificate_kind
			)
		if bool(bloodmoon_recovery_override.get("handled", false)):
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
				"certificate_kind": str(
					bloodmoon_recovery_override.get("certificate_kind", "")
				),
			})
			return bloodmoon_recovery_override.get("items", []) as Array
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
	if _runtime_configured and _current_route_id == "route:gust":
		var hard_guard_score: Variant = _hard_guard_gust_target_score(item)
		if hard_guard_score != null:
			return float(hard_guard_score)
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
			and _current_route_id == "route:gust" \
			and _active_module_certificate_kind in [
				"fan_rotom_gust_closeout",
				"public_fan_rotom_gust_attach_attack_closeout",
			]:
		var gust_score: Variant = _noctowl_search.verified_fan_rotom_gust_target_score(
			item,
			step,
			_last_observation,
			_profile,
			_active_module_certificate_kind
		)
		if gust_score != null:
			return float(gust_score)
	if _runtime_configured \
			and _current_route_id == "route:accelerate" \
			and _active_module_certificate_kind in [
				"banked_energy_handoff",
			]:
		var verified_score: Variant = _noctowl_search.verified_energy_handoff_target_score(
			item,
			step,
			_profile,
			_last_observation,
			_active_module_certificate_kind
		)
		if verified_score != null:
			return float(verified_score)
	return _rules_fallback.score_interaction_target(item, step, context)


func _hard_guard_gust_target_score(item: Variant) -> Variant:
	var constraint: Dictionary = {}
	for candidate: Dictionary in _last_frontier:
		if str(candidate.get("candidate_id", "")) != _preferred_candidate_id \
				and str(candidate.get(
					"safe_prefix_action_id",
					""
				)) != _preferred_action_id:
			continue
		var raw_constraint: Variant = candidate.get(
			"hard_guard_target_constraint",
			{}
		)
		if raw_constraint is Dictionary:
			constraint = (raw_constraint as Dictionary).duplicate(true)
		break
	if constraint.is_empty() \
			or str(constraint.get("kind", "")) != "public_lethal_only":
		return null
	if not (item is PokemonSlot):
		return HARD_BLOCK_SCORE
	var slot := item as PokemonSlot
	var top := slot.get_top_card()
	if top == null:
		return HARD_BLOCK_SCORE
	var instance_id := int(top.instance_id)
	var eligible_instance_ids: Array = constraint.get(
		"eligible_instance_ids",
		[]
	) if constraint.get("eligible_instance_ids", []) is Array else []
	var eligible_slot_ids: Array = constraint.get(
		"eligible_slot_ids",
		[]
	) if constraint.get("eligible_slot_ids", []) is Array else []
	var slot_id := "slot:%d" % instance_id
	if instance_id not in eligible_instance_ids and slot_id not in eligible_slot_ids:
		return HARD_BLOCK_SCORE
	# The hard guard already proves lethality. Within the admissible target set,
	# prefer the larger Prize swing, then the lower-HP target as the most robust
	# public execution of that proof.
	return 1000000000.0 \
		+ float(slot.get_prize_count()) * 10000.0 \
		- float(slot.get_remaining_hp())


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


func capture_runtime_action_ownership(action: Dictionary) -> void:
	# AIOpponent executes actions synchronously. During that call an interaction,
	# KO replacement, or policy checkpoint may clear/change the live route before
	# log_runtime_action_result runs. Freeze the selected action's provenance at
	# the only authoritative boundary: after host selection, before execution.
	var stable_action_id := _observation_gateway.stable_action_id(action)
	var selected_owner := _current_action_owner
	var selected_route_id := _current_route_id
	var selected_candidate_id := _preferred_candidate_id
	var selected_node_id := _policy_graph.current_node_id()
	var selected_graph_origin := _policy_graph.origin()
	var selected_certificate := _active_module_certificate_kind
	var binding_mismatch := false
	if selected_owner in [
		"model_selected_local_route",
		"model_synthesized_route",
		"policy_graph_branch",
		"module_verified_upgrade",
	]:
		binding_mismatch = _preferred_action_id == "" \
			or stable_action_id != _preferred_action_id
		if binding_mismatch:
			# A model/verified route owns only its exact selected action. If the
			# host chose anything else, keep a single conservative Rule owner.
			selected_owner = "rules_fallback"
			selected_route_id = ""
			selected_candidate_id = ""
			selected_node_id = ""
			selected_graph_origin = "rules_fallback"
			selected_certificate = ""
	_pending_action_ownership_ticket = {
		"action_id": stable_action_id,
		"turn_id": _current_turn,
		"policy_id": str(_lifecycle.get("policy_id", "")),
		"revision_id": str(_lifecycle.get("revision_id", "")),
		"node_id": selected_node_id,
		"route_id": selected_route_id,
		"candidate_id": selected_candidate_id,
		"owner": selected_owner,
		"graph_origin": selected_graph_origin,
		"owner_at_capture": _current_action_owner,
		"module_certificate_kind": selected_certificate,
		"observation_hash": str(_last_observation.get(
			"observation_hash",
			""
		)),
		"observation_version": int(_last_observation.get(
			"observation_version",
			0
		)),
		"binding_mismatch": binding_mismatch,
	}


func log_runtime_action_result(
	action: Dictionary,
	success: bool,
	_game_state: GameState,
	_player_index: int,
	audit_turn: int
) -> void:
	_profiled_gardevoir_interaction_ticket.clear()
	var stable_action_id := _observation_gateway.stable_action_id(action)
	var owner_at_result := _current_action_owner
	var ownership: Dictionary = {}
	var ticket_status := "missing"
	if not _pending_action_ownership_ticket.is_empty():
		var ticket_action_id := str(_pending_action_ownership_ticket.get(
			"action_id",
			""
		))
		var ticket_turn := int(_pending_action_ownership_ticket.get(
			"turn_id",
			-1
		))
		if ticket_action_id == stable_action_id \
				and (ticket_turn < 0 or ticket_turn == audit_turn):
			ownership = _pending_action_ownership_ticket.duplicate(true)
			ticket_status = (
				"binding_mismatch"
				if bool(ownership.get("binding_mismatch", false))
				else "captured"
			)
		else:
			ticket_status = "action_or_turn_mismatch"
	_pending_action_ownership_ticket.clear()
	if ownership.is_empty():
		# Compatibility for direct strategy tests and any non-host caller. The
		# production AIOpponent seam always supplies a capture ticket.
		ownership = {
			"policy_id": str(_lifecycle.get("policy_id", "")),
			"revision_id": str(_lifecycle.get("revision_id", "")),
			"node_id": _policy_graph.current_node_id(),
			"route_id": _current_route_id,
			"candidate_id": _preferred_candidate_id,
			"owner": _current_action_owner,
			"graph_origin": _policy_graph.origin(),
			"owner_at_capture": _current_action_owner,
			"module_certificate_kind": _active_module_certificate_kind,
		}
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
		"route_id": str(ownership.get("route_id", "")),
		"candidate_id": str(ownership.get("candidate_id", "")),
		"owner": str(ownership.get("owner", "rules_fallback")),
		"target_slot_id": str(public_action_ref.get("target", "")),
	}
	_audit.record({
		"turn_id": audit_turn,
		"policy_id": str(ownership.get("policy_id", "")),
		"revision_id": str(ownership.get("revision_id", "")),
		"node_id": str(ownership.get("node_id", "")),
		"route_id": str(ownership.get("route_id", "")),
		"candidate_id": str(ownership.get("candidate_id", "")),
		"deck_id": int(_profile.get("deck_id", 0)),
		"strategy_id": get_strategy_id(),
		"event_type": "action_result",
		"action_id": stable_action_id,
		"action_kind": str(action.get("kind", "")),
		"action_card_uid": action_card_uid,
		"target_slot_id": str(public_action_ref.get("target", "")),
		"action_owner": str(ownership.get("owner", "rules_fallback")),
		"graph_origin": str(ownership.get("graph_origin", "local_gate")),
		"owner_at_capture": str(ownership.get(
			"owner_at_capture",
			""
		)),
		"owner_at_result": owner_at_result,
		"ownership_ticket_status": ticket_status,
		"module_certificate_kind": str(ownership.get(
			"module_certificate_kind",
			""
		)),
		"success": success,
	})


func get_audit_summary() -> Dictionary:
	var summary := _audit.summary()
	summary["branch_hits"] = _branch_hits
	summary["uncovered_events"] = _uncovered_events
	summary["last_request_metrics"] = _last_request_metrics.duplicate(true)
	summary["last_route_value_metrics"] = _last_route_value_metrics.duplicate(true)
	return summary


func get_policy_snapshot() -> Dictionary:
	return _policy_graph.snapshot()


func stable_action_id_for_host(action: Dictionary) -> String:
	return _observation_gateway.stable_action_id(action)


func make_v18cpg_runtime_snapshot(
	game_state: GameState,
	player_index: int
) -> Dictionary:
	return _observation_gateway.snapshot_public_state(game_state, player_index)


func observe_v18cpg_runtime_state_change(
	before_snapshot: Dictionary,
	after_snapshot: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	var event: Dictionary = _event_bridge.observe_transition(
		before_snapshot,
		after_snapshot,
		context
	)
	if bool(event.get("information_material", false)):
		# Main-action ownership was recorded before the interaction resolved. Keep
		# that owner and attach the public information result to it, even when the
		# selected root was named evolve/accelerate rather than information.
		if _unconsumed_action_result.is_empty():
			_unconsumed_action_result = {
				"action_id": str(context.get("action_id", "")),
				"action_kind": str(context.get("action_kind", "")),
				"success": bool(event.get("success", false)),
				"route_id": _current_route_id,
				"candidate_id": _preferred_candidate_id,
				"owner": _current_action_owner,
			}
		_unconsumed_action_result["information_event"] = true
		_unconsumed_action_result["information_event_type"] = str(event.get("event_type", ""))
		_unconsumed_action_result["resolution_id"] = str(event.get("resolution_id", ""))
		_unconsumed_action_result["public_delta"] = event.get("public_delta", {}).duplicate(true) \
			if event.get("public_delta", {}) is Dictionary else {}
		_unconsumed_action_result["acquired_own_hand_cards"] = event.get(
			"acquired_own_hand_cards", []
		).duplicate(true)
		_audit.record({
			"turn_id": _current_turn,
			"policy_id": str(_lifecycle.get("policy_id", "")),
			"revision_id": str(_lifecycle.get("revision_id", "")),
			"deck_id": int(_profile.get("deck_id", 0)),
			"strategy_id": get_strategy_id(),
			"event_type": "information_epoch_observed",
			"resolution_id": str(event.get("resolution_id", "")),
			"action_owner": str(_unconsumed_action_result.get("owner", "")),
			"route_id": str(_unconsumed_action_result.get("route_id", "")),
			"candidate_id": str(_unconsumed_action_result.get("candidate_id", "")),
			"step_kind": str(event.get("step_kind", "")),
			"public_delta": event.get("public_delta", {}),
		})
	return event


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


func _terminal_completion_override(
	root_ref: Dictionary,
	frontier: Array[Dictionary],
	facts: Dictionary,
	observation: Dictionary
) -> Dictionary:
	var selected_id := str(root_ref.get(
		"candidate_id",
		root_ref.get("first_candidate_id", "")
	))
	var selected := _route_search.find_candidate(frontier, selected_id)
	if selected.is_empty():
		return {"handled": false}
	var contract: Dictionary = _turn_completion_solver.build(
		observation,
		facts,
		frontier,
		_profile
	)
	if not bool(contract.get("must_review_before_terminal", false)):
		return {"handled": false}
	var recommended_id := str(contract.get("recommended_candidate_id", ""))
	var recommended_action_id := str(contract.get("recommended_action_id", ""))
	var recommended := _route_search.find_candidate(frontier, recommended_id)
	if recommended.is_empty() \
			or recommended_id == selected_id \
			or recommended_action_id == "" \
			or str(recommended.get("safe_prefix_action_id", "")) \
				!= recommended_action_id:
		return {"handled": false}
	var recommended_route := str(recommended.get("route_id", ""))
	var recommended_kind := str(recommended.get("action_kind", ""))
	if recommended_route in [
		"route:attack_ko",
		"route:attack_pressure",
		"route:end_turn",
	] or recommended_kind in ["attack", "granted_attack", "end_turn"]:
		return {"handled": false}
	if not _completion_prefix_can_cross_rule_root(recommended, selected):
		return {"handled": false}
	var selected_effect: Dictionary = selected.get(
		"post_attack_continuity",
		{}
	) if selected.get("post_attack_continuity", {}) is Dictionary else {}
	var recommended_effect: Dictionary = recommended.get(
		"post_attack_continuity",
		{}
	) if recommended.get("post_attack_continuity", {}) is Dictionary else {}
	if bool(selected_effect.get("force_before_terminal", false)) \
			and int(selected_effect.get("priority", 1000)) \
				<= int(recommended_effect.get("priority", 1000)):
		return {"handled": false}
	return {
		"handled": true,
		"candidate_id": recommended_id,
		"action_id": recommended_action_id,
		"route_id": recommended_route,
		"reason": str(contract.get("recommended_reason", "")),
		"model_candidate_id": selected_id,
		"model_route_id": str(selected.get("route_id", "")),
	}


func _completion_prefix_can_cross_rule_root(
	recommended: Dictionary,
	rule_root: Dictionary
) -> bool:
	# Information-producing actions are observation barriers.  A completion
	# prefix derived from the pre-search hand/deck state is stale by definition
	# once the search resolves, so the graph must execute the checkpoint and
	# rebuild instead of replacing it.
	if str(rule_root.get("checkpoint_after", "")) == "information_result" \
			or str(rule_root.get("route_id", "")) in [
				"route:information",
				"route:noctowl_search",
				"route:opening_search",
			]:
		return false
	# A Supporter acceleration/search action can alter both the visible hand and
	# the deck RNG epoch.  Public continuity arithmetic may prove that it adds
	# Energy, but it cannot prove that moving it ahead of the engine's exact
	# manual attachment preserves the rest of the turn.  Execute the Rule
	# attachment first and reobserve; deterministic engine prefixes such as
	# Hoothoot/Noctowl, Area Zero, and Teal Dance remain eligible here.
	if not bool(rule_root.get("engine_rule_floor_exact", false)) \
			or str(rule_root.get("action_kind", "")) != "attach_energy":
		return true
	var recommended_roles: Array = recommended.get(
		"action_semantic_roles",
		[]
	) if recommended.get("action_semantic_roles", []) is Array else []
	return not (
		str(recommended.get("route_id", "")) == "route:accelerate" \
			and (
				str(recommended.get("action_kind", "")) == "play_trainer" \
					or "supporter_acceleration" in recommended_roles
			)
	)


func _completion_override_for_rule_root(
	frontier: Array[Dictionary],
	facts: Dictionary,
	observation: Dictionary
) -> Dictionary:
	if frontier.is_empty():
		return {"handled": false}
	var rule_root: Dictionary = frontier[0]
	return _terminal_completion_override(
		{
			"candidate_id": str(rule_root.get("candidate_id", "")),
			"route_id": str(rule_root.get("route_id", "")),
		},
		frontier,
		facts,
		observation
	)


func _pre_judgment_completion_override(
	frontier: Array[Dictionary],
	facts: Dictionary,
	observation: Dictionary,
	required_turn_judgment: bool
) -> Dictionary:
	if not required_turn_judgment \
			or _turn_model_judgment_attempted \
			or _turn_model_judgment_resolved:
		return {"handled": false}
	return _completion_override_for_rule_root(frontier, facts, observation)


func _install_turn_completion_override(
	completion_override: Dictionary,
	frontier: Array[Dictionary]
) -> void:
	var candidate_id := str(completion_override.get("candidate_id", ""))
	var candidate := _route_search.find_candidate(frontier, candidate_id)
	if candidate.is_empty():
		_install_rejected_model_fallback(frontier)
		return
	_policy_graph.clear()
	_execution_cursor.clear()
	_revision_serial += 1
	_lifecycle["revision_id"] = "%s:r%d" % [
		str(_lifecycle.get("policy_id", "policy")),
		_revision_serial,
	]
	# The completion solver is a deterministic public-state safety barrier. Its
	# exact candidate gets execution authority for one action, after which the
	# information-event bridge rebuilds the frontier from the new observation.
	_select_route(
		str(candidate.get("route_id", "")),
		frontier,
		"module_verified_upgrade",
		candidate_id
	)


func install_policy_response_for_test(
	response: Dictionary,
	frontier: Array[Dictionary],
	facts: Dictionary = {}
) -> Dictionary:
	var request_fact_paths: Variant = (
		ContractsScript.branchable_fact_paths(facts)
		if not facts.is_empty()
		else null
	)
	var validation := _policy_validator.validate_response(
		response,
		REGISTERED_ROUTE_IDS,
		int(_profile.get("max_policy_nodes", 8)),
		_candidate_ids(frontier),
		false,
		request_fact_paths
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
	var completion_override := _terminal_completion_override(
		root_ref,
		frontier,
		facts,
		_last_observation
	)
	if bool(completion_override.get("handled", false)):
		_install_turn_completion_override(completion_override, frontier)
		return {
			"valid": true,
			"turn_completion_override": true,
			"candidate_id": str(completion_override.get("candidate_id", "")),
			"action_id": str(completion_override.get("action_id", "")),
		}
	var origin := "model_synthesized_route" if str(root_ref.get("mode", "")) == "propose_typed_route" else "model_selected_local_route"
	_policy_graph.install(policy, origin)
	_execution_cursor.install(root_ref, _lifecycle, int(_last_observation.get("observation_version", 0)), origin)
	_select_route(root_route, frontier, origin, str(root_ref.get("candidate_id", root_ref.get("first_candidate_id", ""))))
	return {"valid": true}


func _on_policy_response(request_id: String, response: Dictionary, metrics: Dictionary) -> void:
	if request_id == "" or request_id != _pending_request_id:
		return
	var context := _pending_context.duplicate(true)
	metrics["request_intent"] = str(context.get(
		"request_intent",
		"strategic_arbitration"
	))
	metrics["is_delta"] = bool(context.get("is_delta", false))
	# A resolved request is not necessarily a provider response: deadline
	# fallback records use the same policy_response event so every request has
	# one terminal audit record. Keep transport and schema stages explicit.
	metrics["provider_response_received"] = true
	metrics["contract_validated"] = false
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
		_install_verified_reference_fallback(
			_last_frontier,
			_last_facts,
			_last_observation,
			"deadline_fallback"
		)
		_record_policy_response(false, "stale_response", metrics)
		return
	var validation := _policy_validator.validate_response(
		response,
		REGISTERED_ROUTE_IDS,
		int(_profile.get("max_policy_nodes", 8)),
		context.get("allowed_candidate_ids", []) if context.get("allowed_candidate_ids", []) is Array else [],
		true,
		context.get("allowed_fact_paths", []) \
			if context.get("allowed_fact_paths", []) is Array else []
	)
	if not bool(validation.get("valid", false)):
		var validation_reason := str(
			validation.get("reason", "schema_error")
		)
		if _is_terminal_provider_failure(validation_reason):
			_provider_terminal_failure_reason = validation_reason
			_runtime_configured = false
			_hard_blocked_action_ids.clear()
			_clear_route("rules_fallback")
		else:
			_install_rejected_model_fallback(frontier)
		_record_policy_response(false, validation_reason, metrics)
		return
	metrics["contract_validated"] = true
	var policy: Dictionary = validation.get("policy", {})
	var binding := _policy_validator.bind_root_to_frontier(policy, frontier)
	if not bool(binding.get("valid", false)):
		_install_rejected_model_fallback(frontier)
		_record_policy_response(false, str(binding.get("reason", "candidate_binding_failed")), metrics)
		return
	policy = binding.get("policy", {})
	var root_ref: Dictionary = binding.get("root_ref", {})
	var root_route := str(root_ref.get("route_id", ""))
	var root_candidate := str(root_ref.get("candidate_id", root_ref.get("first_candidate_id", "")))
	if root_route not in context.get("available_route_ids", []):
		_install_rejected_model_fallback(frontier)
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
	var completion_override := _terminal_completion_override(
		root_ref,
		frontier,
		context.get("facts", {}) if context.get("facts", {}) is Dictionary else {},
		_last_observation
	)
	if bool(completion_override.get("handled", false)):
		_install_turn_completion_override(completion_override, frontier)
		_record_policy_response(
			true,
			"turn_completion_barrier_override",
			metrics,
			"",
			{
				"model_candidate_id": str(root_ref.get(
					"candidate_id",
					root_ref.get("first_candidate_id", "")
				)),
				"model_route_id": str(root_ref.get("route_id", "")),
				"completion_candidate_id": str(
					completion_override.get("candidate_id", "")
				),
				"completion_action_id": str(
					completion_override.get("action_id", "")
				),
				"completion_reason": str(
					completion_override.get("reason", "")
				),
			}
		)
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
	var defer_root_to_rule := _can_defer_model_root_to_rule(
		shadow_exact_rule_root,
		selected_candidate,
		frontier,
		route_safety
	)
	var post_judgment_upgrade: Dictionary = {}
	if _should_review_deferred_rule_root_for_verified_upgrade(
		shadow_exact_rule_root,
		selected_candidate,
		frontier,
		route_safety,
		bool(context.get("turn_model_judgment", false))
	):
		post_judgment_upgrade = _find_module_verified_upgrade(
			frontier,
			context.get("facts", {}) if context.get("facts", {}) is Dictionary else {}
		)
		var upgrade_reviews: Array[Dictionary] = []
		for review_candidate: Dictionary in frontier:
			if not _candidate_has_verified_module_annotation(review_candidate):
				continue
			var review_safety := _validate_model_route_safety(
				str(review_candidate.get("route_id", "")),
				frontier,
				context.get("facts", {}) if context.get("facts", {}) is Dictionary else {},
				str(review_candidate.get("candidate_id", ""))
			)
			upgrade_reviews.append({
				"candidate_id": str(review_candidate.get("candidate_id", "")),
				"route_id": str(review_candidate.get("route_id", "")),
				"action_kind": str(review_candidate.get("action_kind", "")),
				"engine_rule_floor_exact": bool(
					review_candidate.get("engine_rule_floor_exact", false)
				),
				"valid": bool(review_safety.get("valid", false)),
				"reason": str(review_safety.get("reason", "")),
				"certificate_kind": str(
					review_safety.get("advantage", {}).get("certificate_kind", "")
				),
			})
		_audit.record({
			"turn_id": _current_turn,
			"policy_id": str(_lifecycle.get("policy_id", "")),
			"request_id": request_id,
			"deck_id": int(_profile.get("deck_id", 0)),
			"strategy_id": get_strategy_id(),
			"event_type": "post_judgment_verified_upgrade_review",
			"accepted": not post_judgment_upgrade.is_empty(),
			"candidate_id": str(post_judgment_upgrade.get("candidate_id", "")),
			"route_id": str(post_judgment_upgrade.get("route_id", "")),
			"certificate_kind": str(
				post_judgment_upgrade.get("verified_advantage", {}).get(
					"certificate_kind",
					""
				)
			),
			"candidate_reviews": upgrade_reviews,
		})
	if not post_judgment_upgrade.is_empty():
		_install_post_judgment_verified_upgrade(post_judgment_upgrade, frontier)
		_record_policy_response(
			true,
			"exact_rule_root_reviewed_then_module_verified_upgrade" \
				if shadow_exact_rule_root \
				else "deferred_rule_root_reviewed_then_module_verified_upgrade",
			metrics,
			"",
			{
				"canonicalized_unreachable_nodes": int(
					validation.get("canonicalized_unreachable_nodes", 0)
				),
				"canonicalized_overflow_nodes": int(
					validation.get("canonicalized_overflow_nodes", 0)
				),
			}
		)
		return
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
		# A shadow graph owns only future declared branches. Its current root must
		# be transactionally identical to the no-response verified reference,
		# including nested search targets and other interaction choices. `local_gate`
		# is intentionally stronger than that reference (it enables autonomous
		# basic-search certificates), so using it here could change gameplay while
		# audit still reported zero model-owned actions.
		_select_route(
			str(frontier[0].get("route_id", "")),
			frontier,
			"deadline_fallback",
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
			"canonicalized_overflow_nodes": int(
				validation.get("canonicalized_overflow_nodes", 0)
			),
		}
	)


func _should_shadow_exact_rule_root(route_safety: Dictionary) -> bool:
	return bool(route_safety.get("valid", false)) \
		and str(route_safety.get("reason", "")) == "matches_rules_floor"


func _can_defer_model_root_to_rule(
	shadow_exact_rule_root: bool,
	selected_candidate: Dictionary,
	frontier: Array[Dictionary],
	route_safety: Dictionary
) -> bool:
	if shadow_exact_rule_root:
		return true
	return not bool(route_safety.get("valid", false)) \
		and str(route_safety.get("reason", "")) in [
			"ambiguous_rule_tie_without_verified_advantage",
			"same_route_switch_without_verified_advantage",
		] \
		and _can_defer_ambiguous_root_to_rule(selected_candidate, frontier)


func _should_review_deferred_rule_root_for_verified_upgrade(
	shadow_exact_rule_root: bool,
	selected_candidate: Dictionary,
	frontier: Array[Dictionary],
	route_safety: Dictionary,
	_turn_model_judgment: bool
) -> bool:
	# Accepting a no-op Rule-root shadow must never suppress a deterministic
	# public-state upgrade that the verified-local arm would execute on the same
	# observation. This applies to optional and delta requests as well as the
	# required first-main-window judgment.
	return _can_defer_model_root_to_rule(
		shadow_exact_rule_root,
		selected_candidate,
		frontier,
		route_safety
	)


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
	_turn_model_judgment_attempted = false
	_turn_model_judgment_requested = false
	_turn_model_judgment_resolved = false
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
	_hard_blocked_action_ids.clear()
	_unconsumed_action_result.clear()
	_pending_action_ownership_ticket.clear()
	_match_agenda = {
		"victory_mode": str(_profile.get("victory_mode", "prize_race")),
		"prize_path": [],
		"attacker_chain": [],
		"protected_resources": (_profile.get("protected_roles", []) as Array).duplicate(true) if _profile.get("protected_roles", []) is Array else [],
		"opponent_threat_posture": [],
		"risk_posture": str(_profile.get("risk_posture", "balanced")),
		"expires_when": ["turn_end", "major_ko", "engine_lost"],
	}
	if _requires_turn_model_judgment():
		_audit.record({
			"turn_id": _current_turn,
			"policy_id": str(_lifecycle.get("policy_id", "")),
			"deck_id": int(_profile.get("deck_id", 0)),
			"strategy_id": get_strategy_id(),
			"event_type": "turn_model_judgment_opened",
			"turn_model_judgment_required": true,
		})


func _requires_turn_model_judgment() -> bool:
	return str(_profile.get("turn_model_judgment_mode", "")) \
		== "required_first_main_window"


func _should_force_turn_model_judgment(event_context: Dictionary) -> bool:
	return _requires_turn_model_judgment() \
		and _runtime_configured \
		and str(event_context.get("event_type", "MAIN_ACTION_WINDOW")) == "MAIN_ACTION_WINDOW" \
		and not _turn_model_judgment_attempted


func _resolve_turn_model_judgment_without_request(reason: String) -> void:
	if not _requires_turn_model_judgment() \
			or _turn_model_judgment_attempted \
			or _turn_model_judgment_resolved:
		return
	_turn_model_judgment_attempted = true
	_turn_model_judgment_resolved = true
	_audit.record({
		"turn_id": _current_turn,
		"policy_id": str(_lifecycle.get("policy_id", "")),
		"deck_id": int(_profile.get("deck_id", 0)),
		"strategy_id": get_strategy_id(),
		"event_type": "turn_model_judgment_skipped",
		"turn_model_judgment_required": true,
		"turn_model_judgment": true,
		"fallback_reason": reason,
	})


func _build_request_envelope(
	observation: Dictionary,
	facts: Dictionary,
	frontier: Array[Dictionary],
	material_delta: Dictionary = {},
	required_turn_judgment: bool = false
) -> Dictionary:
	var typed_policy := _profile_policy.sanitize(_profile, REGISTERED_ROUTE_IDS)
	var profile_summary := _profile_summary_for_model(typed_policy)
	var request_facts := _with_turn_completion_facts(
		facts,
		observation,
		frontier
	)
	request_facts = _with_prize_clock_facts(
		request_facts,
		observation,
		frontier
	)
	request_facts = _with_route_decision_right_facts(
		request_facts,
		frontier
	)
	# Root selection is an exact-candidate decision, while checkpoint branches
	# are route decisions after reobservation. Do not show the model exact roots
	# that the runtime safety gate is guaranteed to reject. This also avoids
	# wasting prompt tokens on choices the model cannot own.
	var root_frontier := _model_root_frontier(frontier, request_facts)
	var compact_frontier := _compact_frontier_for_model(root_frontier)
	var factored_frontier := _factor_common_capability_context(compact_frontier)
	var turn_completion_contract := _turn_completion_solver.build(
		observation,
		request_facts,
		frontier,
		_profile
	)
	turn_completion_contract = _model_turn_completion_contract(
		turn_completion_contract,
		root_frontier
	)
	var allowed_fact_paths := ContractsScript.branchable_fact_paths(
		request_facts
	)
	return {
		"schema_version": ContractsScript.SCHEMA_VERSION,
		"limits": {
			# A required first-main-window judgment is still a conditional-policy
			# request. Preserve the profile's graph budget so predictable action
			# prefixes and information checkpoints can avoid unnecessary future
			# calls; the validator and token budget continue to reject verbosity.
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
		"facts": request_facts,
		"resource_ledger": _compact_resource_ledger_for_model(
			_resource_ledger.build(observation, _semantic_manifest, _profile, _belief.snapshot())
		),
		"prize_graph": _compact_prize_graph_for_model(
			_prize_graph.solve(observation, request_facts)
		),
		"threat_response": (
			_opponent_response_v2.solve(observation, _profile)
			if RouteValueGraphScript.is_enabled(_profile)
			else _threat_response.solve(observation)
		),
		"turn_completion_contract": turn_completion_contract,
		"capability_context": factored_frontier.get("capability_context", {}),
		"frontier": factored_frontier.get("frontier", []),
		"current_root_route_ids": _route_ids(root_frontier),
		"current_root_candidate_bindings": _candidate_bindings(root_frontier),
		"allowed_follow_route_ids": REGISTERED_ROUTE_IDS.duplicate(),
		"allowed_candidate_ids": _candidate_ids(root_frontier),
		"allowed_fact_paths": allowed_fact_paths,
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
		var conditional_suffix: Variant = candidate.get(
			"conditional_suffix",
			{}
		)
		if conditional_suffix is Dictionary \
				and not (conditional_suffix as Dictionary).is_empty():
			compact_candidate["conditional_suffix"] = (
				conditional_suffix as Dictionary
			).duplicate(true)
		var route_value: Variant = candidate.get("route_value_graph_v3", {})
		if route_value is Dictionary and not (route_value as Dictionary).is_empty():
			var compact_route_value := _compact_route_value_for_model(
				route_value as Dictionary
			)
			if not compact_route_value.is_empty():
				compact_candidate["route_value_graph_v3"] = compact_route_value
		if (compact_candidate.get("module_annotations", {}) as Dictionary).is_empty():
			compact_candidate.erase("module_annotations")
		result.append(compact_candidate)
	return result


func _compact_action_ref_for_model(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return {}
	var source: Dictionary = value
	var result: Dictionary = {}
	for key: String in [
		"attack_index", "ability_index", "projected_damage",
		"projected_knockout", "source", "target",
		"retreat_payment_energy_count", "zero_energy_retreat",
		"engine_legal_retreat_proof",
	]:
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
	for key: String in [
		"uid", "name", "type", "stage", "energy_type", "energy_provides",
	]:
		var text := str(source.get(key, ""))
		if text != "":
			result[key] = text
	return result


func _compact_outcome_for_model(value: Variant) -> Dictionary:
	var source: Dictionary = value if value is Dictionary else {}
	var result: Dictionary = {}
	for key: String in [
		"win_now",
		"attack_ready",
		"attack_uptime_next_turn",
		"terminal",
		"zero_energy_retreat",
		"preserves_attached_energy",
		"consumes_last_bench_slot",
		"uses_expanded_bench_capacity",
		"bench_capacity_drop_risk",
	]:
		if bool(source.get(key, false)):
			result[key] = true
	for key: String in [
		"prizes_now",
		"estimated_damage",
		"continuity_debt_reduction",
		"retreat_payment_energy_count",
		"bench_capacity",
		"bench_slots_before",
		"bench_slots_after",
		"own_bench_overflow_if_default",
		"opponent_bench_overflow_if_default",
	]:
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
		"own_fastest_finish_tick", "own_robust_finish_tick",
		"opponent_fastest_finish_tick", "opponent_robust_finish_tick",
		"race_margin", "opponent_wins_next_window",
		"continuity_debt_cost_ticks", "credible_gust",
		"public_gust_exhausted", "own_robust_prize_sequence",
		"opponent_robust_prize_sequence",
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
			"bench_count": int(own.get("bench_count", 0)),
			"bench_capacity": int(own.get("bench_capacity", 5)),
			"bench_slots_free": int(own.get("bench_slots_free", 0)),
			"bench_full": bool(own.get("bench_full", false)),
			"bench_overflow_count": int(
				own.get("bench_overflow_count", 0)
			),
			"default_bench_capacity": int(
				own.get("default_bench_capacity", 5)
			),
			"overflow_if_default_capacity": int(
				own.get("overflow_if_default_capacity", 0)
			),
			"capacity_above_default": bool(
				own.get("capacity_above_default", false)
			),
			"capacity_below_default": bool(
				own.get("capacity_below_default", false)
			),
			"discard_counts": _card_name_counts(own.get("discard", [])),
			"active": _compact_slot(own.get("active", {})),
			"bench": _compact_slots(own.get("bench", [])),
		},
		"opponent": {
			"hand_count": int(opponent.get("hand_count", 0)),
			"deck_count": int(opponent.get("deck_count", 0)),
			"prizes_remaining": int(opponent.get("prizes_remaining", 0)),
			"bench_count": int(opponent.get("bench_count", 0)),
			"bench_capacity": int(
				opponent.get("bench_capacity", 5)
			),
			"bench_slots_free": int(
				opponent.get("bench_slots_free", 0)
			),
			"bench_full": bool(opponent.get("bench_full", false)),
			"bench_overflow_count": int(
				opponent.get("bench_overflow_count", 0)
			),
			"default_bench_capacity": int(
				opponent.get("default_bench_capacity", 5)
			),
			"overflow_if_default_capacity": int(
				opponent.get("overflow_if_default_capacity", 0)
			),
			"capacity_above_default": bool(
				opponent.get("capacity_above_default", false)
			),
			"capacity_below_default": bool(
				opponent.get("capacity_below_default", false)
			),
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
	for key: String in ["uid", "name", "type", "stage", "energy_type", "energy_provides"]:
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
		"max_hp": int(slot.get(
			"max_hp",
			int(slot.get("remaining_hp", 0)) + int(slot.get("damage", 0))
		)),
		"prize_count": int(slot.get("prize_count", 1)),
		"retreat_cost": int(slot.get("retreat_cost", 0)),
		"printed_retreat_cost": int(
			slot.get("printed_retreat_cost", slot.get("retreat_cost", 0))
		),
		"stage": str(slot.get(
			"stage",
			(slot.get("pokemon", {}) as Dictionary).get("stage", "")
				if slot.get("pokemon", {}) is Dictionary else ""
		)),
		"tool": _compact_card(slot.get("tool", {})),
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


func _install_completion_aware_fallback(
	frontier: Array[Dictionary],
	owner: String,
	facts: Dictionary = {},
	observation: Dictionary = {}
) -> bool:
	var effective_facts := facts if not facts.is_empty() else _last_facts
	var effective_observation := observation \
		if not observation.is_empty() else _last_observation
	var completion_override := _completion_override_for_rule_root(
		frontier,
		effective_facts,
		effective_observation
	)
	if bool(completion_override.get("handled", false)):
		_install_turn_completion_override(completion_override, frontier)
		return true
	_install_local_policy(frontier, owner)
	return false


func _install_verified_reference_fallback(
	frontier: Array[Dictionary],
	facts: Dictionary = {},
	observation: Dictionary = {},
	fallback_owner: String = "deadline_fallback"
) -> bool:
	# Accepted shadow Rule roots run the deterministic post-judgment certificate
	# review. A missing/rejected response and the verified-local reference must
	# run that exact same public-state review, or "zero model-owned actions" can
	# still produce a different same-seed decision log.
	var effective_facts := facts if not facts.is_empty() else _last_facts
	var verified_upgrade := _find_module_verified_upgrade(
		frontier,
		effective_facts
	)
	if not verified_upgrade.is_empty():
		_install_post_judgment_verified_upgrade(verified_upgrade, frontier)
		return true
	return _install_completion_aware_fallback(
		frontier,
		fallback_owner,
		effective_facts,
		observation if not observation.is_empty() else _last_observation
	)


func _install_rejected_model_fallback(frontier: Array[Dictionary]) -> void:
	# A rejected response must be observationally equivalent to a request that
	# never arrived.  In particular, it must not relabel the Rule root as
	# `local_gate`, because that owner is allowed to activate additional local
	# interaction certificates and can therefore change a same-seed duel even
	# when audit reports model_accepted=0.
	_install_verified_reference_fallback(
		frontier,
		_last_facts,
		_last_observation,
		"deadline_fallback"
	)


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
	var completed_owner := str(completed_action.get("owner", policy_origin))
	if completed_owner in [
		"model_selected_local_route",
		"model_synthesized_route",
		"policy_graph_branch",
	]:
		return false
	# Root action ownership and graph provenance are deliberately separate.
	# `model_shadow_rule_root` executes the exact Rule root, but the accepted
	# model graph owns a declared successor. A one-node shadow owns nothing after
	# its Rule root and must reopen the exact verified-local information epoch.
	if policy_origin == "model_shadow_rule_root" \
			and _policy_graph.current_route_has_declared_successor():
		return false
	if completed_owner not in ["local_gate", "deadline_fallback", "schema_fallback"]:
		return false
	if not bool(completed_action.get("success", false)):
		return false
	# An engine interaction can turn any root action into an information action:
	# Noctowl is selected as an evolve route, for example, but its triggered
	# search changes the next decision's visible hand identities. The event bridge
	# is the proof, so route naming must not suppress the new information epoch.
	if bool(completed_action.get("information_event", false)):
		return true
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


func _information_event_requires_delta_replan(
	completed_action: Dictionary,
	delta: Dictionary
) -> bool:
	# A model graph is allowed to keep ownership only when one of its typed
	# checkpoints actually resolves. If the graph returns `replan`, the engine's
	# information event is authoritative even when coarse material-delta fields
	# miss a same-size hand identity replacement.
	return bool(completed_action.get("information_event", false)) \
		or bool(delta.get("material", false)) \
		or bool(delta.get("legal_actions_changed", false))


func _enrich_material_delta_with_information_event(
	delta: Dictionary,
	completed_action: Dictionary
) -> Dictionary:
	if not bool(completed_action.get("information_event", false)):
		return delta
	var enriched := delta.duplicate(true)
	enriched["material"] = true
	enriched["information_event"] = true
	enriched["information_event_type"] = str(completed_action.get("information_event_type", ""))
	enriched["resolution_id"] = str(completed_action.get("resolution_id", ""))
	enriched["public_delta"] = completed_action.get("public_delta", {}).duplicate(true) \
		if completed_action.get("public_delta", {}) is Dictionary else {}
	enriched["acquired_own_hand_cards"] = completed_action.get(
		"acquired_own_hand_cards", []
	).duplicate(true)
	enriched.erase("material_delta_hash")
	enriched["material_delta_hash"] = ContractsScript.stable_hash(enriched)
	return enriched


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
		"public_active_ko_cost_before_independent_bench_evolve",
		"public_dragon_weakness_field_immediate_ko",
		"public_active_gardevoir_attack_completion",
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
		"profiled_bloodmoon_closeout_bench",
		"profiled_bloodmoon_closeout_recover_energy",
		"profiled_bloodmoon_closeout_attach_pivot",
		"profiled_bloodmoon_closeout_retreat_finisher",
		"public_dynamic_cost_ready_attack_over_redundant_attachment",
		"public_prize_denial_pivot",
		"public_same_window_pivot_ko_loss_prevention",
	]:
		return true
	# A non-terminal local certificate must never postpone an executable Rule
	# attack.  Such sequencing is a policy-graph decision for the model, not a
	# monotonic local rewrite.
	if bool(facts.get("attack", {}).get("ready", false)) \
			or bool(facts.get("attack", {}).get("ko_available", false)) \
			or str(local_top.get("route_id", "")) in ["route:attack_ko", "route:attack_pressure"]:
		return false
	if certificate_kind == "public_distinct_energy_coverage":
		# Coverage arithmetic proves only that a type is new, not that it is more
		# valuable than Rule's exact attachment. Seed 800015946 demonstrates that
		# replacing Grass with Psychic inside the same quota can lose the future
		# Ogerpon line. Keep this evidence model-visible but never autonomous.
		return false
	if certificate_kind == "public_stadium_immediate_capacity":
		# Bench capacity is future flexibility, not a monotonic action-level
		# advantage. Spending a Basic from hand can lose both tempo and a future
		# search target even when Rule would otherwise end the turn.
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
	# A Raging Bolt supporter may publicly complete an attack-cost route while
	# still being a non-monotonic ordering choice. Seed 182600 proves that using
	# this certificate to move Crispin ahead of Rule's exact manual attachment
	# changes the information/RNG epoch and can turn a win into a deck-out loss.
	# Keep the certificate model-visible, but only the exact attachment candidate
	# may take autonomous ownership at the first decision window.
	if int(_profile.get("deck_id", 0)) == 800018509 \
			and certificate_kind == "public_typed_attack_cost_completion" \
			and (
				str(upgrade.get("route_id", "")) != "route:energy_commit" \
				or str(upgrade.get("action_kind", "")) != "attach_energy"
			):
		return false
	return certificate_kind in [
		"public_active_ko_cost_before_independent_bench_evolve",
		"profiled_counter_activation",
		"public_typed_attack_cost_completion",
		"public_same_ko_preserve_attached_energy",
		"profiled_stage2_search_before_pivot",
		"public_dynamic_cost_ready_attack_over_redundant_attachment",
		"public_prize_denial_pivot",
		"public_same_window_pivot_ko_loss_prevention",
	]


func _verified_upgrade_preempts_model_judgment(upgrade: Dictionary) -> bool:
	if str(upgrade.get("verified_reason", "")) in [
		"deterministic_win_now",
		"deterministic_prize_gain",
	]:
		return str(upgrade.get("action_kind", "")) in [
			"attack",
			"granted_attack",
		]
	var certificate_kind := str(
		upgrade.get("verified_advantage", {}).get("certificate_kind", "")
	)
	# Required model judgment is a quality gate, not permission to ignore an
	# exact public rescue. These proofs are already stronger than a model
	# preference and close a current attack window that cannot be recovered.
	return certificate_kind in [
		"public_same_window_pivot_ko_loss_prevention",
		"public_dynamic_cost_ready_attack_over_redundant_attachment",
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


func _graph_reentry_action_owner() -> String:
	var graph_origin := _policy_graph.origin()
	if graph_origin not in [
		"model_selected_local_route",
		"model_synthesized_route",
		"model_shadow_rule_root",
	]:
		return graph_origin
	var snapshot := _policy_graph.snapshot()
	var policy: Dictionary = snapshot.get("policy", {}) \
		if snapshot.get("policy", {}) is Dictionary else {}
	var root_node_id := str(policy.get("root_node_id", ""))
	var current_node_id := str(snapshot.get("current_node_id", ""))
	# A model-shadow root is still Rule-owned. Once the accepted graph advances
	# beyond that root, however, duplicate prepare calls on the unchanged public
	# observation must preserve policy_graph_branch until the host captures and
	# executes the selected exact action.
	if root_node_id != "" \
			and current_node_id != "" \
			and current_node_id != root_node_id:
		return "policy_graph_branch"
	if graph_origin == "model_shadow_rule_root":
		# Root action + all nested interactions are one atomic Rule transaction.
		# Keep the verified-reference owner across duplicate host prepare calls;
		# graph provenance remains available separately for a later branch.
		return "deadline_fallback"
	return graph_origin


func _model_checkpoint_precedes_verified_upgrade() -> bool:
	return _policy_graph.is_active() \
		and _policy_graph.origin() in [
			"model_selected_local_route",
			"model_synthesized_route",
			"model_shadow_rule_root",
		] \
		and _policy_graph.current_route_has_declared_successor()


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


func _install_post_judgment_verified_upgrade(
	upgrade: Dictionary,
	frontier: Array[Dictionary]
) -> void:
	_policy_graph.clear()
	_execution_cursor.clear()
	_revision_serial += 1
	_lifecycle["revision_id"] = "%s:r%d" % [
		str(_lifecycle.get("policy_id", "policy")),
		_revision_serial,
	]
	# Reuse the existing closed action-owner contract. A novel owner string is
	# normalized to local_gate by _select_route(), which drops the route bonus
	# and makes the host reopen the same observation before executing the
	# verified candidate.
	_select_route(
		str(upgrade.get("route_id", "")),
		frontier,
		"module_verified_upgrade",
		str(upgrade.get("candidate_id", ""))
	)
	_activate_verified_upgrade_certificate(upgrade)


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


func _compact_route_value_for_model(value: Dictionary) -> Dictionary:
	# The audit snapshot keeps the full typed Bundle.  The model needs only the
	# non-default comparison deltas and projected route intents; repeating hashes,
	# root identity, transition class, and legacy outcome fields per candidate
	# would erase the latency advantage of local planning.
	var pareto_selected := bool(value.get("pareto_selected", false))
	var steps: Array = value.get("steps", []) \
		if value.get("steps", []) is Array else []
	var follow_routes: Array[String] = []
	for index: int in range(1, steps.size()):
		if not (steps[index] is Dictionary):
			continue
		var route_id := str((steps[index] as Dictionary).get("route_id", ""))
		if route_id != "" and route_id not in follow_routes:
			follow_routes.append(route_id)
	var outcome: Dictionary = value.get("outcome_vector", {}) \
		if value.get("outcome_vector", {}) is Dictionary else {}
	var result: Dictionary = {}
	if pareto_selected:
		result["pareto"] = true
	if not follow_routes.is_empty():
		result["follow_routes"] = follow_routes
	if bool(value.get("requires_reobservation", false)) and not follow_routes.is_empty():
		result["reobserve"] = true
	var race_margin := int(outcome.get("race_margin", 0))
	if race_margin != 0:
		result["race_margin"] = race_margin
	var continuity_debt := int(outcome.get("continuity_debt", 0))
	if continuity_debt > 0:
		result["continuity_debt"] = continuity_debt
	if outcome.has("next_attack_window_uptime") \
			and not bool(outcome.get("next_attack_window_uptime", true)):
		result["next_uptime"] = false
	var liability := float(outcome.get("liability", 0.0))
	if liability > 0.0:
		result["liability"] = snappedf(liability, 0.01)
	var extension: Dictionary = value.get("deck_extension", {}) \
		if value.get("deck_extension", {}) is Dictionary else {}
	var raging := _compact_raging_route_value(extension)
	if not raging.is_empty():
		result["raging"] = raging
	return result


func _compact_raging_route_value(extension: Dictionary) -> Dictionary:
	if str(extension.get("extension", "")) != "raging_bolt":
		return {}
	var result: Dictionary = {}
	var mappings := {
		"dynamic_damage_units_required": "damage_units",
		"noctowl_current_lane": "noctowl_lane",
		"hoothoot_future_lane": "hoothoot_lane",
		"teal_dance_current_value": "teal_value",
		"banked_damage_units_before": "bank_before",
		"banked_damage_units_after": "bank_after",
	}
	for raw_source: Variant in mappings.keys():
		var source := str(raw_source)
		if extension.has(source) and float(extension.get(source, 0.0)) != 0.0:
			result[str(mappings[source])] = extension.get(source)
	for source: String in [
		"area_zero_bound_followup",
		"premature_attack_prevented",
		"optional_churn_stopped",
	]:
		if bool(extension.get(source, false)):
			result[source] = true
	var pair: Dictionary = extension.get("trainer_pair_contract", {}) \
		if extension.get("trainer_pair_contract", {}) is Dictionary else {}
	if not pair.is_empty():
		var required: Variant = pair.get("required_roles", [])
		if required is Array and not (required as Array).is_empty():
			result["pair_roles"] = (required as Array).duplicate()
	return result


func _typed_candidate_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (value is Array):
		return result
	for raw_candidate: Variant in value:
		if raw_candidate is Dictionary:
			result.append(raw_candidate as Dictionary)
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


func _apply_runtime_hard_guards(
	candidate_pool: Array[Dictionary],
	observation: Dictionary,
	facts: Dictionary
) -> Dictionary:
	# Intrinsic candidate guards must run before the terminal continuity guard.
	# Otherwise a Rule-vetoed pseudo-prefix can make the stale continuity snapshot
	# block attack/end_turn, leaving every legal action hard-blocked and allowing
	# the host's "pick one" fallback to execute the first vetoed action anyway.
	var intrinsic := _hard_guard.filter_intrinsic_candidates(
		candidate_pool,
		observation,
		facts,
		_profile
	)
	var intrinsically_allowed := _typed_candidate_array(
		intrinsic.get("candidates", [])
	)
	var rebuilt_facts := _with_turn_completion_facts(
		facts,
		observation,
		intrinsically_allowed
	)
	rebuilt_facts = _with_prize_clock_facts(
		rebuilt_facts,
		observation,
		intrinsically_allowed
	)
	var terminal := _hard_guard.filter_candidates(
		intrinsically_allowed,
		observation,
		rebuilt_facts,
		_profile
	)
	var blocked_action_ids: Dictionary = {}
	for raw_ids: Variant in [
		intrinsic.get("blocked_action_ids", {}),
		terminal.get("blocked_action_ids", {}),
	]:
		if not (raw_ids is Dictionary):
			continue
		for action_id: Variant in (raw_ids as Dictionary):
			blocked_action_ids[str(action_id)] = str(
				(raw_ids as Dictionary).get(action_id, "hard_guard_blocked")
			)
	var blocked: Array = []
	for raw_entries: Variant in [
		intrinsic.get("blocked", []),
		terminal.get("blocked", []),
	]:
		if raw_entries is Array:
			blocked.append_array((raw_entries as Array).duplicate(true))
	return {
		"candidates": _typed_candidate_array(
			terminal.get("candidates", [])
		),
		"facts": rebuilt_facts,
		"blocked": blocked,
		"blocked_action_ids": blocked_action_ids,
	}


func _with_turn_completion_facts(
	facts: Dictionary,
	observation: Dictionary,
	frontier: Array[Dictionary]
) -> Dictionary:
	var result := facts.duplicate(true)
	var contract := _turn_completion_solver.build(
		observation,
		result,
		frontier,
		_profile
	)
	var continuity: Dictionary = contract.get(
		"post_attack_continuity",
		{}
	) if contract.get("post_attack_continuity", {}) is Dictionary else {}
	result["continuity"] = {
		"enabled": bool(continuity.get("enabled", false)),
		"floor_met": bool(continuity.get("floor_met", true)),
		"review_before_terminal": bool(
			continuity.get("review_before_terminal", false)
		),
		"debt_count": int(continuity.get("debt_count", 0)),
		"banked_damage_units": int(
			continuity.get("post_payment_banked_units", 0)
		),
		"required_banked_damage_units": int(
			continuity.get("minimum_banked_damage_units", 0)
		),
		"live_engine_count": int(continuity.get("live_engine_count", 0)),
		"current_live_engine_count": int(
			continuity.get("current_live_engine_count", 0)
		),
		"current_energized_engine_count": int(
			continuity.get("current_energized_engine_count", 0)
		),
		"search_engine_roots": int(
			continuity.get("search_engine_roots", 0)
		),
		"live_search_engines": int(
			continuity.get("live_search_engines", 0)
		),
		"bench_capacity": int(continuity.get("bench_capacity", 5)),
		"bench_slots_free": int(
			continuity.get("bench_slots_free", 0)
		),
		"expansion_active": bool(
			continuity.get("expansion_active", false)
		),
		"next_attacker_roots": int(
			continuity.get("next_attacker_roots", 0)
		),
		"safe_prefix_available": bool(
			continuity.get("safe_prefix_available", false)
		),
	}
	return result


func _with_route_availability_facts(
	facts: Dictionary,
	frontier: Array[Dictionary]
) -> Dictionary:
	var result := facts.duplicate(true)
	var route_facts: Dictionary = result.get("route", {}) \
		if result.get("route", {}) is Dictionary else {}
	route_facts = route_facts.duplicate(true)
	var availability: Dictionary = {}
	var available_route_ids := _route_ids(frontier)
	for route_id: String in REGISTERED_ROUTE_IDS:
		availability[route_id.trim_prefix("route:")] = (
			route_id in available_route_ids
		)
	route_facts["available"] = availability
	result["route"] = route_facts
	return result


func _with_route_decision_right_facts(
	facts: Dictionary,
	frontier: Array[Dictionary]
) -> Dictionary:
	var result := facts.duplicate(true)
	var route_facts: Dictionary = result.get("route", {}) \
		if result.get("route", {}) is Dictionary else {}
	route_facts = route_facts.duplicate(true)
	var switch_allowed: Dictionary = {}
	for route_id: String in REGISTERED_ROUTE_IDS:
		var candidate := _route_search.find_route(frontier, route_id)
		if candidate.is_empty():
			switch_allowed[route_id.trim_prefix("route:")] = false
			continue
		var safety := _validate_model_route_safety(
			route_id,
			frontier,
			result,
			str(candidate.get("candidate_id", ""))
		)
		switch_allowed[route_id.trim_prefix("route:")] = bool(
			safety.get("valid", false)
		)
	route_facts["model_switch_allowed"] = switch_allowed
	result["route"] = route_facts
	return result


func _model_root_frontier(
	frontier: Array[Dictionary],
	facts: Dictionary
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if frontier.is_empty():
		return result
	var rule_floor_candidate_id := str(frontier[0].get("candidate_id", ""))
	for candidate: Dictionary in frontier:
		if bool(candidate.get("engine_rule_floor_exact", false)):
			rule_floor_candidate_id = str(candidate.get("candidate_id", ""))
			break
	for candidate: Dictionary in frontier:
		var candidate_id := str(candidate.get("candidate_id", ""))
		if candidate_id == "":
			continue
		if candidate_id == rule_floor_candidate_id:
			result.append(candidate)
			continue
		var safety := _validate_model_route_safety(
			str(candidate.get("route_id", "")),
			frontier,
			facts,
			candidate_id
		)
		if bool(safety.get("valid", false)):
			result.append(candidate)
	return result


func _model_turn_completion_contract(
	contract: Dictionary,
	root_frontier: Array[Dictionary]
) -> Dictionary:
	var result := contract.duplicate(true)
	if root_frontier.is_empty():
		return result
	var allowed_candidate_ids := _candidate_ids(root_frontier)
	var declared_productive_action_ids: Array[String] = []
	for raw_action_id: Variant in result.get("productive_action_ids", []):
		var action_id := str(raw_action_id)
		if action_id != "" and action_id not in declared_productive_action_ids:
			declared_productive_action_ids.append(action_id)
	var productive_actions: Array[Dictionary] = []
	for raw_action: Variant in result.get("productive_actions", []):
		if not (raw_action is Dictionary):
			continue
		var action := raw_action as Dictionary
		if str(action.get("candidate_id", "")) in allowed_candidate_ids:
			productive_actions.append(action.duplicate(true))
	var continuity: Dictionary = result.get("post_attack_continuity", {}) \
		if result.get("post_attack_continuity", {}) is Dictionary else {}
	continuity = continuity.duplicate(true)
	var candidate_effects: Array[Dictionary] = []
	for raw_effect: Variant in continuity.get("candidate_effects", []):
		if raw_effect is Dictionary \
				and str((raw_effect as Dictionary).get(
					"candidate_id",
					""
				)) in allowed_candidate_ids:
			candidate_effects.append((raw_effect as Dictionary).duplicate(true))
	continuity["candidate_effects"] = candidate_effects
	result["post_attack_continuity"] = continuity
	var recommended_candidate_id := str(result.get(
		"recommended_candidate_id",
		""
	))
	if recommended_candidate_id not in allowed_candidate_ids:
		var root := root_frontier[0]
		recommended_candidate_id = str(root.get("candidate_id", ""))
		var root_action_id := str(root.get("safe_prefix_action_id", ""))
		var root_action := {
			"candidate_id": recommended_candidate_id,
			"action_id": root_action_id,
			"action_kind": str(root.get("action_kind", "")),
			"route_id": str(root.get("route_id", "")),
			"priority": 0,
			"reason": "current_model_selectable_information_barrier",
			"information_checkpoint": str(root.get(
				"checkpoint_after",
				""
			)) == "information_result",
		}
		productive_actions.push_front(root_action)
		result["recommended_candidate_id"] = recommended_candidate_id
		result["recommended_action_id"] = root_action_id
		result["recommended_route_id"] = str(root.get("route_id", ""))
		result["recommended_reason"] = \
			"current_model_selectable_information_barrier"
		result["instruction"] = \
			"execute_model_selectable_root_then_reobserve"
	var productive_candidate_ids: Array[String] = []
	var productive_action_ids: Array[String] = []
	for action: Dictionary in productive_actions:
		var candidate_id := str(action.get("candidate_id", ""))
		var action_id := str(action.get("action_id", ""))
		if candidate_id != "" and candidate_id not in productive_candidate_ids:
			productive_candidate_ids.append(candidate_id)
		if action_id != "" and action_id not in productive_action_ids:
			productive_action_ids.append(action_id)
	for action_id: String in declared_productive_action_ids:
		if action_id not in productive_action_ids:
			productive_action_ids.append(action_id)
	result["productive_actions"] = productive_actions
	result["productive_candidate_ids"] = productive_candidate_ids
	result["productive_action_ids"] = productive_action_ids
	result["productive_action_count"] = productive_action_ids.size()
	return result


func _with_prize_clock_facts(
	facts: Dictionary,
	observation: Dictionary,
	frontier: Array[Dictionary]
) -> Dictionary:
	var result := facts.duplicate(true)
	var baseline: Dictionary = {}
	for candidate: Dictionary in frontier:
		var annotations: Dictionary = candidate.get("module_annotations", {}) \
			if candidate.get("module_annotations", {}) is Dictionary else {}
		var clock: Dictionary = annotations.get("prize_clock_pivot", {}) \
			if annotations.get("prize_clock_pivot", {}) is Dictionary else {}
		if clock.get("baseline_clock", {}) is Dictionary \
				and not (clock.get("baseline_clock", {}) as Dictionary).is_empty():
			baseline = (clock.get("baseline_clock", {}) as Dictionary).duplicate(
				true
			)
			break
	if baseline.is_empty():
		var prize_graph := _prize_graph.solve(observation, result)
		baseline = {
			"current_attack_window_open": bool(prize_graph.get(
				"current_attack_window_open",
				false
			)),
			"own_fastest_finish_tick": int(prize_graph.get(
				"own_fastest_finish_tick",
				0
			)),
			"own_robust_finish_tick": int(prize_graph.get(
				"own_robust_finish_tick",
				0
			)),
			"opponent_fastest_finish_tick": int(prize_graph.get(
				"opponent_fastest_finish_tick",
				0
			)),
			"opponent_robust_finish_tick": int(prize_graph.get(
				"opponent_robust_finish_tick",
				0
			)),
			"race_margin": int(prize_graph.get("race_margin", 0)),
			"opponent_wins_next_window": bool(prize_graph.get(
				"opponent_wins_next_window",
				false
			)),
			"continuity_debt_cost_ticks": int(prize_graph.get(
				"continuity_debt_cost_ticks",
				0
			)),
			"credible_gust": bool(prize_graph.get("credible_gust", false)),
			"public_gust_exhausted": bool(prize_graph.get(
				"public_gust_exhausted",
				false
			)),
			"own_robust_prize_sequence": prize_graph.get(
				"own_robust_prize_sequence",
				[]
			),
			"opponent_robust_prize_sequence": prize_graph.get(
				"opponent_robust_prize_sequence",
				[]
			),
		}
	result["prize_clock"] = {
		"current_attack_window_open": bool(baseline.get(
			"current_attack_window_open",
			false
		)),
		"own_fastest_finish_tick": int(baseline.get(
			"own_fastest_finish_tick",
			0
		)),
		"own_robust_finish_tick": int(baseline.get(
			"own_robust_finish_tick",
			0
		)),
		"opponent_fastest_finish_tick": int(baseline.get(
			"opponent_fastest_finish_tick",
			0
		)),
		"opponent_robust_finish_tick": int(baseline.get(
			"opponent_robust_finish_tick",
			0
		)),
		"race_margin": int(baseline.get("race_margin", 0)),
		"opponent_wins_next_window": bool(baseline.get(
			"opponent_wins_next_window",
			false
		)),
		"continuity_debt_cost_ticks": int(baseline.get(
			"continuity_debt_cost_ticks",
			0
		)),
		"credible_gust": bool(baseline.get("credible_gust", false)),
		"public_gust_exhausted": bool(baseline.get(
			"public_gust_exhausted",
			false
		)),
		"own_robust_prize_sequence": baseline.get(
			"own_robust_prize_sequence",
			[]
		),
		"opponent_robust_prize_sequence": baseline.get(
			"opponent_robust_prize_sequence",
			[]
		),
	}
	return result


func _refresh_match_agenda_from_prize_clock(facts: Dictionary) -> void:
	var clock: Dictionary = facts.get("prize_clock", {}) \
		if facts.get("prize_clock", {}) is Dictionary else {}
	if clock.is_empty():
		return
	_match_agenda["prize_path"] = (
		clock.get("own_robust_prize_sequence", []) as Array
	).duplicate(true) if clock.get("own_robust_prize_sequence", []) is Array \
		else []
	var posture: Array[String] = []
	if bool(clock.get("opponent_wins_next_window", false)):
		posture.append("prevent_next_attack_window_win")
	if bool(clock.get("credible_gust", false)):
		posture.append("credible_gust")
	if int(clock.get("race_margin", 0)) < 0:
		posture.append("behind_on_robust_prize_clock")
	_match_agenda["opponent_threat_posture"] = posture


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
		"route_value_graph": _last_route_value_metrics.duplicate(true),
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
		"graph_origin": _policy_graph.origin(),
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
	var resolves_turn_model_judgment := _turn_model_judgment_requested \
		and not _turn_model_judgment_resolved
	var graph_origin := _policy_graph.origin()
	var policy_installed := accepted and graph_origin in [
		"model_selected_local_route",
		"model_synthesized_route",
		"model_shadow_rule_root",
	]
	var installed_policy: Dictionary = _policy_graph.snapshot().get(
		"policy",
		{}
	) if _policy_graph.snapshot().get("policy", {}) is Dictionary else {}
	var installed_nodes: Array = installed_policy.get("nodes", []) \
		if installed_policy.get("nodes", []) is Array else []
	var policy_graph_bearing := policy_installed and installed_nodes.size() > 1
	if policy_installed and not policy_graph_bearing \
			and not installed_nodes.is_empty() \
			and installed_nodes[0] is Dictionary:
		var root_ref: Dictionary = (installed_nodes[0] as Dictionary).get(
			"route_ref",
			{}
		) if (installed_nodes[0] as Dictionary).get(
			"route_ref",
			{}
		) is Dictionary else {}
		policy_graph_bearing = root_ref.get("macro_actions", []) is Array \
			and (root_ref.get("macro_actions", []) as Array).size() > 1
	var response_disposition := (
		"policy_installed"
		if policy_installed
		else "deterministic_preempted"
		if accepted
		else "rejected"
	)
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
		"graph_origin": graph_origin,
		"action_owner": _current_action_owner,
		"fallback_layer": fallback_layer,
		"fallback_reason": reason,
		"request_intent": str(metrics.get(
			"request_intent",
			"strategic_arbitration"
		)),
		"is_delta": bool(metrics.get("is_delta", false)),
		"policy_installed": policy_installed,
		"policy_node_count": installed_nodes.size() if policy_installed else 0,
		"policy_graph_bearing": policy_graph_bearing,
		"response_disposition": response_disposition,
		"provider_response_received": bool(metrics.get(
			"provider_response_received",
			true
		)),
		"contract_validated": bool(metrics.get("contract_validated", false)),
		"request_wall_ms": int(metrics.get("request_wall_ms", 0)),
		"visible_wait_ms": int(metrics.get("visible_wait_ms", 0)),
		"payload_bytes": int(metrics.get("payload_bytes", 0)),
		"response_bytes": int(metrics.get("response_bytes", 0)),
		"configured_token_budget": int(metrics.get("configured_token_budget", 0)),
		"effective_token_budget": int(metrics.get("effective_token_budget", 0)),
		"finish_reason": str(metrics.get("finish_reason", "")),
		"prompt_tokens": int(metrics.get("prompt_tokens", 0)),
		"completion_tokens": int(metrics.get("completion_tokens", 0)),
		"provider_http_code": int(metrics.get("provider_http_code", 0)),
		"provider_error_type": str(metrics.get("provider_error_type", "")),
		"turn_model_judgment": resolves_turn_model_judgment,
	}
	for raw_key: Variant in extra.keys():
		record[str(raw_key)] = extra.get(raw_key)
	_audit.record(record)
	if resolves_turn_model_judgment:
		_turn_model_judgment_resolved = true
	v18cpg_decision_ready.emit(
		_current_turn,
		accepted,
		_user_facing_response_reason(accepted, reason)
	)


func _preferred_action_ref() -> Dictionary:
	for candidate: Dictionary in _last_frontier:
		if str(candidate.get("candidate_id", "")) == _preferred_candidate_id \
				or str(candidate.get("safe_prefix_action_id", "")) == _preferred_action_id:
			return (candidate.get("action_ref", {}) as Dictionary).duplicate(true) \
				if candidate.get("action_ref", {}) is Dictionary else {}
	return {}


func _live_public_interaction_ref(context: Dictionary) -> Dictionary:
	var kind := str(context.get("pending_effect_kind", "")).strip_edges().to_lower()
	if kind == "":
		return {}
	var result := {
		"kind": kind,
		"proof_complete": false,
	}
	if kind != "attack":
		return result
	var attack_index := int(context.get("pending_effect_ability_index", -1))
	var source_slot: Variant = context.get("pending_effect_slot", null)
	var pending_card: Variant = context.get("pending_effect_card", null)
	if not (source_slot is PokemonSlot) \
			or not (pending_card is CardInstance) \
			or attack_index < 0:
		return result
	var slot := source_slot as PokemonSlot
	var top_card := slot.get_top_card()
	if top_card == null \
			or top_card.card_data == null \
			or (pending_card as CardInstance).card_data == null \
			or top_card.instance_id != (pending_card as CardInstance).instance_id:
		return result
	var live_ref := _observation_gateway.action_ref({
		"kind": "attack",
		"source_slot": slot,
		"attack_index": attack_index,
		"requires_interaction": true,
	})
	live_ref["proof_complete"] = true
	return live_ref


func _user_facing_response_reason(accepted: bool, reason: String) -> String:
	if accepted:
		if reason == "exact_rule_root_shadowed":
			return "模型后续规划已校验，当前动作沿用 Rule"
		if reason == "root_deferred_to_rule":
			return "模型条件图已保留，当前动作沿用 Rule"
		return "模型执行策略已校验" if reason == "" else reason
	match reason:
		"response_truncated":
			return "模型回复不完整，已自动切换本地策略"
		"invalid_model_response":
			return "模型回复格式无效，已自动切换本地策略"
		"transport_error":
			return "模型连接暂时不可用，已自动切换本地策略"
		"provider_quota_exhausted":
			return "DeepSeek 余额不足，本局已自动切换 Rule 策略"
		"provider_auth_error":
			return "DeepSeek 认证失败，本局已自动切换 Rule 策略"
		"turn_visible_wait_budget_exhausted", "external_wait_budget_exhausted":
			return "模型响应超时，已自动切换本地策略"
		_:
			return reason


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
	_hard_blocked_action_ids.clear()
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
	_turn_model_judgment_attempted = false
	_turn_model_judgment_requested = false
	_turn_model_judgment_resolved = false
	_request_wait_samples_ms.clear()
	_last_route_value_metrics.clear()
	_provider_terminal_failure_reason = ""
	_unconsumed_action_result.clear()
	_pending_action_ownership_ticket.clear()
	_event_bridge.reset()


func _is_terminal_provider_failure(reason: String) -> bool:
	return reason in [
		"provider_quota_exhausted",
		"provider_auth_error",
	]
