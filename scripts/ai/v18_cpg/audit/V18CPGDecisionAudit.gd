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
	var calls := 0
	var accepted_calls := 0
	var rejected_calls := 0
	var model_owned_action_results := 0
	var response_turns: Dictionary = {}
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
		var event_type := str(record.get("event_type", ""))
		if event_type != "":
			event_types[event_type] = int(event_types.get(event_type, 0)) + 1
		if event_type == "action_result" and owner in MODEL_ACTION_OWNERS:
			# Count attempts, not only successes.  A failed model-owned attempt can
			# still alter the host loop (including causing an implicit turn end), so
			# it invalidates verified-local equivalence just as a successful one does.
			model_owned_action_results += 1
		var route_id := str(record.get("route_id", ""))
		if route_id != "":
			routes[route_id] = int(routes.get(route_id, 0)) + 1
		if event_type == "policy_response":
			calls += 1
			response_turns[int(record.get("turn_id", -1))] = true
			if bool(record.get("accepted", false)):
				accepted_calls += 1
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
	for value: Variant in turn_waits.values():
		turn_wait_values.append(float(value))
	turn_wait_values.sort()
	payload_sizes.sort()
	return {
		"records": _records.size(),
		"action_owners": owners,
		"fallbacks": fallbacks,
		"fallback_reasons": fallback_reasons,
		"graph_branch_hits": branch_hits,
		"model_calls": calls,
		"model_accepted": accepted_calls,
		"model_rejected": rejected_calls,
		"model_owned_action_results": model_owned_action_results,
		"model_acceptance_rate": float(accepted_calls) / float(maxi(calls, 1)),
		"calls_per_request_turn": float(calls) / float(maxi(response_turns.size(), 1)),
		"routes": routes,
		"event_types": event_types,
		"visible_wait_p50_ms": _percentile(waits, 0.50),
		"visible_wait_p95_ms": _percentile(waits, 0.95),
		"visible_wait_count": waits.size(),
		"visible_wait_samples_ms": waits.duplicate(),
		"turn_visible_wait_p50_ms": _percentile(turn_wait_values, 0.50),
		"turn_visible_wait_p95_ms": _percentile(turn_wait_values, 0.95),
		"turn_visible_wait_samples_ms": turn_wait_values.duplicate(),
		"payload_p50_bytes": _percentile(payload_sizes, 0.50),
		"payload_p95_bytes": _percentile(payload_sizes, 0.95),
		"payload_samples_bytes": payload_sizes.duplicate(),
	}


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
