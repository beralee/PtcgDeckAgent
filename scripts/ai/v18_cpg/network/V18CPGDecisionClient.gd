class_name V18CPGDecisionClient
extends RefCounted

signal response_ready(request_id: String, response: Dictionary, metrics: Dictionary)

## The semantic policy graph remains response schema v2 and is still checked by
## V18CPGPolicyValidator.  This version only identifies the compact model wire
## contract: do not resend the full JSON Schema or duplicate frontier indexes.
const COMPACT_WIRE_CONTRACT_VERSION := 3

const RngIsolatedZenMuxClientScript = preload(
	"res://scripts/ai/v18_cpg/network/V18CPGRngIsolatedZenMuxClient.gd"
)

var _client = RngIsolatedZenMuxClientScript.new()
var _host: Node = null
var _config: Dictionary = {}
var _pending: Dictionary = {}


func configure(host: Node, api_config: Dictionary) -> void:
	_host = host
	_config = api_config.duplicate(true)
	_client.set_timeout_seconds(float(_config.get("timeout_seconds", 30.0)))
	_client.set_allow_python_fallback(bool(_config.get("allow_python_fallback", true)))
	_client.set_allow_unsafe_tls(bool(_config.get("allow_unsafe_tls", true)))


func is_configured() -> bool:
	return _host != null \
		and is_instance_valid(_host) \
		and str(_config.get("endpoint", "")).strip_edges() != "" \
		and str(_config.get("api_key", "")).strip_edges() != "" \
		and str(_config.get("model", "")).strip_edges() != ""


func request_policy(request_id: String, request_envelope: Dictionary, token_budget: int = 600, is_delta: bool = false) -> int:
	if not is_configured() or request_id == "" or _pending.has(request_id):
		return ERR_UNCONFIGURED
	var payload := _build_payload(request_envelope, token_budget, is_delta)
	var started := Time.get_ticks_msec()
	var request_error := _client.request_json(
		_host,
		str(_config.get("endpoint", "")),
		str(_config.get("api_key", "")),
		payload,
		_on_response.bind(request_id)
	)
	if request_error == OK:
		var messages: Array = payload.get("messages", []) if payload.get("messages", []) is Array else []
		_pending[request_id] = {
			"started_msec": started,
			"payload_bytes": JSON.stringify(payload).to_utf8_buffer().size(),
			"system_prompt_bytes": _message_content_bytes(messages, "system"),
			"user_prompt_bytes": _message_content_bytes(messages, "user"),
			"transport_contract_version": COMPACT_WIRE_CONTRACT_VERSION,
			"is_delta": is_delta,
		}
	return request_error


func has_pending(request_id: String = "") -> bool:
	return not _pending.is_empty() if request_id == "" else _pending.has(request_id)


func _on_response(response: Dictionary, request_id: String) -> void:
	var request_meta: Dictionary = _pending.get(request_id, {}) if _pending.get(request_id, {}) is Dictionary else {}
	_pending.erase(request_id)
	var wall_ms := maxi(0, Time.get_ticks_msec() - int(request_meta.get("started_msec", Time.get_ticks_msec())))
	var metrics := {
		"request_wall_ms": wall_ms,
		"visible_wait_ms": wall_ms,
		"payload_bytes": int(request_meta.get("payload_bytes", 0)),
		"system_prompt_bytes": int(request_meta.get("system_prompt_bytes", 0)),
		"user_prompt_bytes": int(request_meta.get("user_prompt_bytes", 0)),
		"response_bytes": JSON.stringify(response).to_utf8_buffer().size(),
		"transport_contract_version": int(request_meta.get("transport_contract_version", 0)),
		"is_delta": bool(request_meta.get("is_delta", false)),
		"transport": str(response.get("transport", "http_request")),
		"rng_isolated_transport": bool(response.get("rng_isolated_transport", false)),
		"rng_isolated_request_sequence": int(response.get("rng_isolated_request_sequence", 0)),
	}
	response_ready.emit(request_id, response.duplicate(true), metrics)


func _message_content_bytes(messages: Array, role: String) -> int:
	for raw_message: Variant in messages:
		if raw_message is Dictionary and str((raw_message as Dictionary).get("role", "")) == role:
			return str((raw_message as Dictionary).get("content", "")).to_utf8_buffer().size()
	return 0


func _build_payload(request_envelope: Dictionary, token_budget: int, is_delta: bool) -> Dictionary:
	var request_kind := "compact remaining-policy revision" if is_delta else "turn conditional policy graph"
	var system := """You are the strategic planner for a Pokemon TCG engine. Return one compact, acyclic conditional policy graph as JSON.
Use only candidate_id, route_id, interaction role, and fact values supplied by the request. Never invent cards, actions, IDs, facts, or hidden information.
The outermost JSON object must contain policy. Put root_node_id and nodes inside policy, never at the outermost level. agenda_patch is the only other semantic outer key.
Prefer the shortest safe prize path, but preserve the next attacker and typed energy when a current KO is not decisive.
Honor the request's typed strategic_priorities, route_preferences, protected_roles, and safety fields. They are deck-profile constraints, not suggestions to invent new actions.
The frontier contains multiple exact candidates, including alternatives inside one macro route. Compare exact targets and costs, not only action categories.
The candidate marked rule_floor_exact is the exact Rule choice. When candidates are marked rule_tie_ambiguous, host-only Rule intent scoring may still break that tie: do not force one of them unless the supplied outcome contains a concrete, verifier-checkable advantage. Select a different candidate only when its supplied outcome, information value, target quality, or next-turn continuity contains such an advantage; never replace a Rule tie by guesswork.
When a capability module marks verified_advantage=true, that exact candidate has a deterministic public-state certificate and may replace end_turn even across a large score gap. Prefer it when its verified_advantage_kind preserves or completes the next attack route.
Information actions are checkpoints. In a typed macro, route:information, route:noctowl_search, route:opening_search, or route:tutor may appear only as the final macro action, never before another macro. To plan beyond one of them, use select_candidate at the root, then a checkpoint and follow_route branches. Delay irreversible supporter, attachment, retreat, and terminal commitments until useful information is collected.
Public-discard recovery is deterministic and may remain inside the current graph as route:recover. Hidden-deck trainer tutoring is route:tutor and is an information checkpoint. When the supplied Gardevoir capability context shows that an HP-expansion tool is the missing public final-prize scaler, preserve recover -> evolve the Embrace engine -> tutor -> tool -> repeated Embrace -> KO, rather than collapsing directly into a low-damage attack.
For Noctowl/Jewel Seeker routes, plan trainer pairs that jointly complete the attack route; do not rank each trainer independently.
The root must bind an exact current action with mode select_candidate and a supplied candidate_id, or use propose_typed_route with a supplied first_candidate_id plus 2-4 supplied macro route IDs. Never use follow_route at the root. propose_typed_route is root-only: every later route node must use follow_route or select_candidate, never propose_typed_route.
For the root, copy candidate_id and route_id from the same frontier entry as one indivisible pair. Do not use a future macro route as the root route_id.
Use only allowed_follow_route_ids for later macro_actions and follow_route nodes. Use follow_route only after checkpoints, where the engine will bind the best legal exact candidate of that macro intent after new information.
When a current line needs two or more predictable main actions, prefer propose_typed_route so the local execution cursor can continue it without another model call.
Define compact typed interaction policies for route-critical searches, energy choices, gust/pivot targets, or assignments. Reference them by stable step id, ui:<ui_mode>, or default.
Every node_id must be non-empty and unique. Use node:root for an initial graph and node:delta_root for a compact revision. Use distinct branch node IDs. The current request's limits.max_policy_nodes is the absolute node maximum, not a target; never exceed it. This value is always at most 8.
If you emit more than the root, connect the root to the next checkpoint or route with next_node_id. Connect every emitted node from the root through next_node_id, checkpoint branches, or otherwise. A route followed by a checkpoint must name that checkpoint in next_node_id. Never emit disconnected planning nodes.
Checkpoint branches use when_all with fact leaf paths present in facts and operators ==, !=, >, >=, <, <=, in, not_in, or exists; every checkpoint must include otherwise. No cycles: every next_node_id and checkpoint branch must point only to a node listed later in nodes. Stay within limits.max_policy_nodes. Do not emit placeholder or duplicate nodes.
The required JSON shape is {"policy":{"root_node_id":"...","nodes":[...]}}. A route node has node_id, kind=route, and route_ref. A checkpoint node has node_id, kind=checkpoint, branches of {when_all:[{fact,op,value}],next_node_id}, and otherwise. A terminal node has node_id and kind=terminal.
For select_candidate, route_ref has mode, route_id, and candidate_id. For propose_typed_route it has mode, route_id, first_candidate_id, and macro_actions. Later nodes may use follow_route with mode and route_id.
For propose_typed_route, route_id and macro_actions[0] must both exactly equal the frontier route_id owned by first_candidate_id. macro_actions must contain exactly 2, 3, or 4 items; if the plan is longer, express later choices with checkpoint and follow_route nodes. Every macro_actions item is a plain JSON route-id string, never an object.
Omit agenda_patch and omit empty policy fields. The client deterministically defaults reservations=[], interaction_policy_refs={}, interaction_policies=[], and replan_if=[] before validation. If an interaction policy is needed, include policy_id, rank_by, desired_roles, must_preserve, energy_symbols, min_select, max_select, allow_explicit_empty, and tie_breakers.
Interaction rank_by values: route_completion, energy_fit, prize_value, knockout_efficiency, attacker_readiness, survival, resource_preservation, stable_id. desired_roles values: attacker, alternate_attacker, finisher, next_attacker, draw_engine, search_engine, recovery, evolution_piece, energy_source, energy_access, typed_energy_access, energy_accelerator, supporter_acceleration, energy_mover, pivot, gust, hand_disruption, lock, stadium, pokemon_search, bench_protection, resource_recycler. Energy symbols: G,W,L,P,F,D,M,C. Tie breakers: stable_id, lower_resource_cost, higher_survival, higher_prize. Optional target_position: any, own_active, own_bench, opponent_active, opponent_bench; optional prize_goal: none, shortest_safe_path, highest_prize, engine_ko, spread_closeout. Checkpoint otherwise is a node_id, local_best, replan, or rules_fallback.
In sparse frontier outcomes and capability annotations, an omitted scalar means false, 0, or empty. capability_context applies to every frontier candidate; a candidate's module_annotations are only its exact overrides.
Keep the answer short. Do not explain the choice and do not repeat request data.
Return JSON only."""
	var full_payload := {
		"transport_contract_version": COMPACT_WIRE_CONTRACT_VERSION,
		"request_kind": request_kind,
		"limits": request_envelope.get("limits", {}),
		"lifecycle": request_envelope.get("lifecycle", {}),
		"profile": request_envelope.get("profile", {}),
		"observation": request_envelope.get("observation", {}),
		"belief": request_envelope.get("belief", {}),
		"match_agenda": request_envelope.get("match_agenda", {}),
		"facts": request_envelope.get("facts", {}),
		"resource_ledger": request_envelope.get("resource_ledger", {}),
		"prize_graph": request_envelope.get("prize_graph", {}),
		"threat_response": request_envelope.get("threat_response", {}),
		"capability_context": request_envelope.get("capability_context", {}),
		"frontier": request_envelope.get("frontier", []),
		"allowed_follow_route_ids": request_envelope.get("allowed_follow_route_ids", []),
	}
	var delta_payload := {
		"transport_contract_version": COMPACT_WIRE_CONTRACT_VERSION,
		"request_kind": request_kind,
		"limits": request_envelope.get("limits", {}),
		"lifecycle": request_envelope.get("lifecycle", {}),
		"profile": request_envelope.get("profile", {}),
		"observation": request_envelope.get("observation", {}),
		"belief": request_envelope.get("belief", {}),
		"match_agenda": request_envelope.get("match_agenda", {}),
		"current_policy_cursor": request_envelope.get("current_policy_cursor", {}),
		"material_delta": request_envelope.get("material_delta", {}),
		"facts": request_envelope.get("facts", {}),
		"resource_ledger": request_envelope.get("resource_ledger", {}),
		"prize_graph": request_envelope.get("prize_graph", {}),
		"threat_response": request_envelope.get("threat_response", {}),
		"capability_context": request_envelope.get("capability_context", {}),
		"frontier": request_envelope.get("frontier", []),
		"allowed_follow_route_ids": request_envelope.get("allowed_follow_route_ids", []),
	}
	var user_payload: Dictionary = delta_payload if is_delta else full_payload
	return {
		"model": str(_config.get("model", "")),
		"messages": [
			{"role": "system", "content": system},
			{"role": "user", "content": JSON.stringify(user_payload)},
		],
		"temperature": 0,
		"max_tokens": token_budget,
		"reasoning": {"enabled": false},
		"thinking": {"type": "disabled"},
	}
