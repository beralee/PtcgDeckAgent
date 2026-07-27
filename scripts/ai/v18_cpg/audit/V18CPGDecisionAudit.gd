class_name V18CPGDecisionAudit
extends RefCounted

const ContractsScript = preload("res://scripts/ai/v18_cpg/schema/V18CPGContracts.gd")
const MODEL_ACTION_OWNERS: Array[String] = [
	"model_selected_local_route",
	"model_synthesized_route",
	"policy_graph_branch",
]

var _run_id: String = ""
var _match_id: String = ""
var _records: Array[Dictionary] = []
var _write_files: bool = false


static func should_compare_verified_local_reference(audit_summary: Dictionary) -> bool:
	# New summaries use actual runtime action ownership.  The legacy fallback
	# keeps previously generated summaries readable without pretending that
	# they contain the stronger evidence.
	if audit_summary.has("model_owned_action_results"):
		return int(audit_summary.get("model_owned_action_results", 0)) == 0
	return int(audit_summary.get("model_accepted", 0)) == 0


func configure(run_id: String, match_id: String, write_files: bool = false) -> void:
	_run_id = run_id
	_match_id = match_id
	_write_files = write_files
	_records.clear()


func record(payload: Dictionary) -> void:
	var record := payload.duplicate(true)
	record["audit_schema_version"] = ContractsScript.AUDIT_SCHEMA_VERSION
	record["run_id"] = _run_id
	record["match_id"] = _match_id
	record["timestamp_msec"] = Time.get_ticks_msec()
	_records.append(record)
	if _write_files:
		_write_record(record)


func record_payload(payload: Dictionary) -> void:
	# Exact request/response bodies are intentionally opt-in.  They are useful
	# for replay attribution, but keeping them out of normal in-memory audit
	# summaries protects latency and artifact size.
	if not _write_files:
		return
	record(payload)


func payload_capture_enabled() -> bool:
	return _write_files


func records() -> Array[Dictionary]:
	return _records.duplicate(true)


func summary() -> Dictionary:
	var owners: Dictionary = {}
	var fallbacks: Dictionary = {}
	var fallback_reasons: Dictionary = {}
	var waits: Array[float] = []
	var turn_waits: Dictionary = {}
	var branch_hits := 0
	var model_graph_branch_hits := 0
	var local_graph_branch_hits := 0
	var calls := 0
	var accepted_calls := 0
	var rejected_calls := 0
	var model_shadow_accepted := 0
	var model_shadow_information_epochs_retained := 0
	var model_root_takeovers := 0
	var model_branch_action_results := 0
	var model_owned_action_results := 0
	var request_states: Dictionary = {}
	var revision_to_request: Dictionary = {}
	var response_turns: Dictionary = {}
	var required_judgment_turns: Dictionary = {}
	var requested_judgment_turns: Dictionary = {}
	var skipped_judgment_turns: Dictionary = {}
	var resolved_judgment_turns: Dictionary = {}
	var accepted_judgment_turns: Dictionary = {}
	var routes: Dictionary = {}
	var event_types: Dictionary = {}
	var payload_sizes: Array[float] = []
	for record: Dictionary in _records:
		var owner := str(record.get("action_owner", ""))
		if owner != "":
			owners[owner] = int(owners.get(owner, 0)) + 1
		var fallback := str(record.get("fallback_layer", ""))
		if fallback != "":
			fallbacks[fallback] = int(fallbacks.get(fallback, 0)) + 1
			var reason := str(record.get("fallback_reason", ""))
			if reason != "":
				fallback_reasons[reason] = int(fallback_reasons.get(reason, 0)) + 1
		if bool(record.get("graph_branch_hit", false)):
			branch_hits += 1
			if owner == "policy_graph_branch" \
					and str(record.get("graph_origin", "")) in [
						"model_selected_local_route",
						"model_synthesized_route",
						"model_shadow_rule_root",
					]:
				model_graph_branch_hits += 1
			else:
				local_graph_branch_hits += 1
		var event_type := str(record.get("event_type", ""))
		if event_type != "":
			event_types[event_type] = int(event_types.get(event_type, 0)) + 1
		if event_type in ["model_request", "model_request_started"]:
			var started_request_id := str(record.get("request_id", ""))
			if started_request_id != "":
				request_states[started_request_id] = {
					"request_intent": str(record.get(
						"request_intent",
						"checkpoint_replan"
						if bool(record.get("is_delta", false))
						else "strategic_arbitration"
					)),
					"is_delta": bool(record.get("is_delta", false)),
					"responded": false,
					"provider_response_received": false,
					"contract_validated": false,
					"accepted": false,
					"policy_installed": false,
					"policy_graph_bearing": false,
					"shadow": false,
					"causal_execution": false,
					"response_disposition": "",
				}
		if event_type == "model_shadow_information_epoch_retained":
			model_shadow_information_epochs_retained += 1
		var record_turn_id := int(record.get("turn_id", -1))
		if event_type == "turn_model_judgment_opened" \
				and bool(record.get("turn_model_judgment_required", false)):
			required_judgment_turns[record_turn_id] = true
		elif event_type == "turn_model_judgment_requested":
			requested_judgment_turns[record_turn_id] = true
		elif event_type == "turn_model_judgment_request_failed" \
				and bool(record.get("turn_model_judgment", false)):
			resolved_judgment_turns[record_turn_id] = true
		elif event_type == "turn_model_judgment_skipped" \
				and bool(record.get("turn_model_judgment", false)):
			skipped_judgment_turns[record_turn_id] = true
			resolved_judgment_turns[record_turn_id] = true
		if event_type == "action_result":
			if owner in MODEL_ACTION_OWNERS:
				# Count attempts, not only successes. A failed model-owned attempt
				# can still alter the host loop, so it invalidates verified-local
				# equivalence just as a successful one does.
				model_owned_action_results += 1
			if owner in [
				"model_selected_local_route",
				"model_synthesized_route",
			]:
				model_root_takeovers += 1
			elif owner == "policy_graph_branch":
				model_branch_action_results += 1
			if owner in MODEL_ACTION_OWNERS:
				var action_revision_key := "%s|%s" % [
					str(record.get("policy_id", "")),
					str(record.get("revision_id", "")),
				]
				var causal_request_id := str(revision_to_request.get(
					action_revision_key,
					""
				))
				if causal_request_id != "" \
						and request_states.get(
							causal_request_id,
							{}
						) is Dictionary:
					var causal_state: Dictionary = request_states[
						causal_request_id
					]
					causal_state["causal_execution"] = true
					request_states[causal_request_id] = causal_state
		var route_id := str(record.get("route_id", ""))
		if route_id != "":
			routes[route_id] = int(routes.get(route_id, 0)) + 1
		if event_type == "policy_response":
			calls += 1
			response_turns[record_turn_id] = true
			var response_request_id := str(record.get("request_id", ""))
			if response_request_id != "":
				var response_state: Dictionary = request_states.get(
					response_request_id,
					{}
				) if request_states.get(
					response_request_id,
					{}
				) is Dictionary else {}
				if response_state.is_empty():
					response_state = {
						"request_intent": str(record.get(
							"request_intent",
							"checkpoint_replan"
							if bool(record.get("is_delta", false))
							else "strategic_arbitration"
						)),
						"is_delta": bool(record.get("is_delta", false)),
						"causal_execution": false,
					}
				var response_graph_origin := str(record.get(
					"graph_origin",
					""
				))
				var inferred_installed := bool(record.get(
					"accepted",
					false
				)) and response_graph_origin in [
					"model_selected_local_route",
					"model_synthesized_route",
					"model_shadow_rule_root",
				]
				response_state["responded"] = true
				response_state["provider_response_received"] = bool(record.get(
					"provider_response_received",
					str(record.get("fallback_layer", "")) \
						!= "deadline_fallback"
				))
				response_state["contract_validated"] = bool(record.get(
					"contract_validated",
					false
				))
				response_state["accepted"] = bool(record.get(
					"accepted",
					false
				))
				response_state["policy_installed"] = bool(record.get(
					"policy_installed",
					inferred_installed
				))
				response_state["policy_graph_bearing"] = bool(record.get(
					"policy_graph_bearing",
					int(record.get("policy_node_count", 0)) > 1
				))
				response_state["shadow"] = response_graph_origin \
					== "model_shadow_rule_root" or str(record.get(
						"fallback_reason",
						""
					)) in [
						"exact_rule_root_shadowed",
						"root_deferred_to_rule",
					]
				response_state["response_disposition"] = str(record.get(
					"response_disposition",
					""
				))
				request_states[response_request_id] = response_state
				if bool(response_state.get("policy_installed", false)):
					var response_revision_key := "%s|%s" % [
						str(record.get("policy_id", "")),
						str(record.get("revision_id", "")),
					]
					revision_to_request[response_revision_key] = \
						response_request_id
			if bool(record.get("turn_model_judgment", false)):
				resolved_judgment_turns[record_turn_id] = true
				if bool(record.get("accepted", false)):
					accepted_judgment_turns[record_turn_id] = true
			if bool(record.get("accepted", false)):
				accepted_calls += 1
				var graph_origin := str(record.get("graph_origin", ""))
				if graph_origin == "model_shadow_rule_root" \
						or str(record.get("fallback_reason", "")) in [
							"exact_rule_root_shadowed",
							"root_deferred_to_rule",
						]:
					model_shadow_accepted += 1
			else:
				rejected_calls += 1
		if record.has("visible_wait_ms"):
			var visible_wait := float(record.get("visible_wait_ms", 0.0))
			waits.append(visible_wait)
			var turn_id := int(record.get("turn_id", -1))
			turn_waits[turn_id] = float(turn_waits.get(turn_id, 0.0)) + visible_wait
		if record.has("payload_bytes"):
			payload_sizes.append(float(record.get("payload_bytes", 0.0)))
	waits.sort()
	var turn_wait_values: Array[float] = []
	var early_turn_wait_values: Array[float] = []
	var middle_turn_wait_values: Array[float] = []
	var late_turn_wait_values: Array[float] = []
	for raw_turn_id: Variant in turn_waits.keys():
		var turn_id := int(raw_turn_id)
		var value := float(turn_waits.get(raw_turn_id, 0.0))
		turn_wait_values.append(value)
		if turn_id <= 2:
			early_turn_wait_values.append(value)
		elif turn_id <= 6:
			middle_turn_wait_values.append(value)
		else:
			late_turn_wait_values.append(value)
	turn_wait_values.sort()
	early_turn_wait_values.sort()
	middle_turn_wait_values.sort()
	late_turn_wait_values.sort()
	payload_sizes.sort()
	var request_intents: Dictionary = {}
	var request_funnel_by_intent: Dictionary = {}
	var requests_started := request_states.size()
	var requests_resolved := 0
	var provider_responses := 0
	var contract_validated_responses := 0
	var policy_installed_requests := 0
	var graph_bearing_installed_requests := 0
	var graph_bearing_causal_execution_requests := 0
	var causal_execution_requests := 0
	var verified_agreement_requests := 0
	var effective_participation_requests := 0
	var accepted_unexecuted_requests := 0
	var accepted_preempted_requests := 0
	for raw_request_id: Variant in request_states.keys():
		var state: Dictionary = request_states.get(raw_request_id, {}) \
			if request_states.get(raw_request_id, {}) is Dictionary else {}
		var intent := str(state.get("request_intent", "strategic_arbitration"))
		request_intents[intent] = int(request_intents.get(intent, 0)) + 1
		var bucket: Dictionary = request_funnel_by_intent.get(intent, {}) \
			if request_funnel_by_intent.get(intent, {}) is Dictionary else {}
		for field: String in [
			"requested",
			"responded",
			"provider_response",
			"contract_validated",
			"accepted",
			"installed",
			"graph_bearing_installed",
			"graph_bearing_causal_execution",
			"causal_execution",
			"verified_agreement",
			"effective_participation",
			"rejected",
		]:
			if not bucket.has(field):
				bucket[field] = 0
		bucket["requested"] = int(bucket["requested"]) + 1
		var responded := bool(state.get("responded", false))
		var provider_response := bool(state.get(
			"provider_response_received",
			false
		))
		var contract_validated := bool(state.get(
			"contract_validated",
			false
		))
		var accepted := bool(state.get("accepted", false))
		var installed := bool(state.get("policy_installed", false))
		var graph_bearing := installed and bool(state.get(
			"policy_graph_bearing",
			false
		))
		var causal := bool(state.get("causal_execution", false))
		var agreement := accepted and installed \
			and bool(state.get("shadow", false)) and not causal
		var effective := causal or agreement
		if responded:
			requests_resolved += 1
			bucket["responded"] = int(bucket["responded"]) + 1
		if provider_response:
			provider_responses += 1
			bucket["provider_response"] = int(
				bucket["provider_response"]
			) + 1
		if contract_validated:
			contract_validated_responses += 1
			bucket["contract_validated"] = int(
				bucket["contract_validated"]
			) + 1
		if accepted:
			bucket["accepted"] = int(bucket["accepted"]) + 1
		elif responded:
			bucket["rejected"] = int(bucket["rejected"]) + 1
		if installed:
			policy_installed_requests += 1
			bucket["installed"] = int(bucket["installed"]) + 1
		elif accepted:
			accepted_preempted_requests += 1
		if causal:
			causal_execution_requests += 1
			bucket["causal_execution"] = int(
				bucket["causal_execution"]
			) + 1
		elif accepted and installed and not agreement:
			accepted_unexecuted_requests += 1
		if agreement:
			verified_agreement_requests += 1
			bucket["verified_agreement"] = int(
				bucket["verified_agreement"]
			) + 1
		if effective:
			effective_participation_requests += 1
			bucket["effective_participation"] = int(
				bucket["effective_participation"]
			) + 1
		if graph_bearing:
			graph_bearing_installed_requests += 1
			bucket["graph_bearing_installed"] = int(
				bucket["graph_bearing_installed"]
			) + 1
			if causal:
				graph_bearing_causal_execution_requests += 1
				bucket["graph_bearing_causal_execution"] = int(
					bucket["graph_bearing_causal_execution"]
				) + 1
		request_funnel_by_intent[intent] = bucket
	for raw_intent: Variant in request_funnel_by_intent.keys():
		var intent := str(raw_intent)
		var bucket: Dictionary = request_funnel_by_intent[intent]
		bucket["response_rate"] = float(bucket["responded"]) / float(
			maxi(int(bucket["requested"]), 1)
		)
		bucket["provider_response_rate"] = float(
			bucket["provider_response"]
		) / float(maxi(int(bucket["requested"]), 1))
		bucket["contract_validation_rate"] = float(
			bucket["contract_validated"]
		) / float(maxi(int(bucket["provider_response"]), 1))
		bucket["acceptance_rate"] = float(bucket["accepted"]) / float(
			maxi(int(bucket["responded"]), 1)
		)
		bucket["causal_execution_rate"] = float(
			bucket["causal_execution"]
		) / float(maxi(int(bucket["requested"]), 1))
		bucket["effective_participation_rate"] = float(
			bucket["effective_participation"]
		) / float(maxi(int(bucket["requested"]), 1))
		bucket["graph_bearing_causal_execution_rate"] = float(
			bucket["graph_bearing_causal_execution"]
		) / float(maxi(int(bucket["graph_bearing_installed"]), 1))
		request_funnel_by_intent[intent] = bucket
	var requested_or_skipped := requested_judgment_turns.duplicate()
	for raw_turn_id: Variant in skipped_judgment_turns:
		requested_or_skipped[raw_turn_id] = true
	var missing_request_turn_ids := _missing_sorted_turn_ids(
		required_judgment_turns,
		requested_or_skipped
	)
	var unresolved_turn_ids := _missing_sorted_turn_ids(
		required_judgment_turns,
		resolved_judgment_turns
	)
	return {
		"records": _records.size(),
		"action_owners": owners,
		"fallbacks": fallbacks,
		"fallback_reasons": fallback_reasons,
		"graph_branch_hits": branch_hits,
		"model_graph_branch_hits": model_graph_branch_hits,
		"local_graph_branch_hits": local_graph_branch_hits,
		"model_calls": calls,
		"model_accepted": accepted_calls,
		"model_rejected": rejected_calls,
		"model_shadow_accepted": model_shadow_accepted,
		"model_shadow_information_epochs_retained": \
			model_shadow_information_epochs_retained,
		"model_root_takeovers": model_root_takeovers,
		"model_branch_action_results": model_branch_action_results,
		"model_owned_action_results": model_owned_action_results,
		"model_requests_started": requests_started,
		"model_requests_resolved": requests_resolved,
		"model_provider_responses": provider_responses,
		"model_contract_validated_responses": contract_validated_responses,
		"model_policy_installed_requests": policy_installed_requests,
		"model_graph_bearing_installed_requests": \
			graph_bearing_installed_requests,
		"model_graph_bearing_causal_execution_requests": \
			graph_bearing_causal_execution_requests,
		"model_causal_execution_requests": causal_execution_requests,
		"model_verified_agreement_requests": verified_agreement_requests,
		"model_effective_participation_requests": \
			effective_participation_requests,
		"model_accepted_unexecuted_requests": accepted_unexecuted_requests,
		"model_accepted_preempted_requests": accepted_preempted_requests,
		"model_request_intents": request_intents,
		"model_request_funnel_by_intent": request_funnel_by_intent,
		"model_transport_completion_rate": float(provider_responses) \
			/ float(maxi(requests_started, 1)),
		"model_provider_response_rate": float(provider_responses) \
			/ float(maxi(requests_started, 1)),
		"model_contract_validation_rate": float(
			contract_validated_responses
		) / float(maxi(provider_responses, 1)),
		"model_policy_install_rate": float(policy_installed_requests) \
			/ float(maxi(calls, 1)),
		"model_request_to_causal_execution_rate": float(
			causal_execution_requests
		) / float(maxi(requests_started, 1)),
		"model_accepted_to_causal_execution_rate": float(
			causal_execution_requests
		) / float(maxi(accepted_calls, 1)),
		"model_request_to_effective_participation_rate": float(
			effective_participation_requests
		) / float(maxi(requests_started, 1)),
		"model_graph_bearing_causal_execution_rate": float(
			graph_bearing_causal_execution_requests
		) / float(maxi(graph_bearing_installed_requests, 1)),
		"model_execution_per_call": float(model_owned_action_results) \
			/ float(maxi(calls, 1)),
		"model_acceptance_rate": float(accepted_calls) / float(maxi(calls, 1)),
		"calls_per_request_turn": float(calls) / float(maxi(response_turns.size(), 1)),
		"turn_model_judgment_required_turns": required_judgment_turns.size(),
		"turn_model_judgment_requested_turns": requested_judgment_turns.size(),
		"turn_model_judgment_skipped_turns": skipped_judgment_turns.size(),
		"turn_model_judgment_resolved_turns": resolved_judgment_turns.size(),
		"turn_model_judgment_accepted_turns": accepted_judgment_turns.size(),
		"turn_model_judgment_request_coverage": float(requested_judgment_turns.size()) \
			/ float(maxi(required_judgment_turns.size(), 1)),
		"turn_model_judgment_resolution_coverage": float(resolved_judgment_turns.size()) \
			/ float(maxi(required_judgment_turns.size(), 1)),
		"turn_model_judgment_missing_request_turn_ids": missing_request_turn_ids,
		"turn_model_judgment_unresolved_turn_ids": unresolved_turn_ids,
		"routes": routes,
		"event_types": event_types,
		"visible_wait_p50_ms": _percentile(waits, 0.50),
		"visible_wait_p95_ms": _percentile(waits, 0.95),
		"visible_wait_count": waits.size(),
		"visible_wait_samples_ms": waits.duplicate(),
		"turn_visible_wait_p50_ms": _percentile(turn_wait_values, 0.50),
		"turn_visible_wait_p95_ms": _percentile(turn_wait_values, 0.95),
		"turn_visible_wait_samples_ms": turn_wait_values.duplicate(),
		"early_turn_visible_wait_p50_ms": _percentile(
			early_turn_wait_values,
			0.50
		),
		"early_turn_visible_wait_p95_ms": _percentile(
			early_turn_wait_values,
			0.95
		),
		"early_turn_visible_wait_samples_ms": \
			early_turn_wait_values.duplicate(),
		"middle_turn_visible_wait_p50_ms": _percentile(
			middle_turn_wait_values,
			0.50
		),
		"middle_turn_visible_wait_p95_ms": _percentile(
			middle_turn_wait_values,
			0.95
		),
		"middle_turn_visible_wait_samples_ms": \
			middle_turn_wait_values.duplicate(),
		"late_turn_visible_wait_p50_ms": _percentile(
			late_turn_wait_values,
			0.50
		),
		"late_turn_visible_wait_p95_ms": _percentile(
			late_turn_wait_values,
			0.95
		),
		"late_turn_visible_wait_samples_ms": \
			late_turn_wait_values.duplicate(),
		"payload_p50_bytes": _percentile(payload_sizes, 0.50),
		"payload_p95_bytes": _percentile(payload_sizes, 0.95),
		"payload_samples_bytes": payload_sizes.duplicate(),
	}


func _missing_sorted_turn_ids(required: Dictionary, covered: Dictionary) -> Array[int]:
	var missing: Array[int] = []
	for raw_turn_id: Variant in required.keys():
		var turn_id := int(raw_turn_id)
		if not covered.has(turn_id):
			missing.append(turn_id)
	missing.sort()
	return missing


func _percentile(values: Array[float], quantile: float) -> float:
	if values.is_empty():
		return 0.0
	var index := clampi(int(ceil(quantile * float(values.size()))) - 1, 0, values.size() - 1)
	return values[index]


func _write_record(record: Dictionary) -> void:
	var directory := "user://logs/v18cpg/%s/%s" % [_run_id, _match_id]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var turn := int(record.get("turn_id", 0))
	var path := "%s/%d.jsonl" % [directory, turn]
	var file := FileAccess.open(
		path,
		FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE
	)
	if file == null:
		return
	file.seek_end()
	file.store_line(JSON.stringify(record))
	file.close()
