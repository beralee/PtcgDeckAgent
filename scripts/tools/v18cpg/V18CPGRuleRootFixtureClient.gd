class_name V18CPGRuleRootFixtureClient
extends RefCounted

## Deterministic test transport for feature-enabled end-to-end smoke. It
## returns the request's exact Rule-floor root on the next frame, exercising
## the real request/response/schema/binding/safety/audit path without network
## variance or changing gameplay RNG.

signal response_ready(request_id: String, response: Dictionary, metrics: Dictionary)

var _host: Node = null
var _request_count := 0


func configure(host: Node, _api_config: Dictionary) -> void:
	_host = host


func is_configured() -> bool:
	return _host != null and is_instance_valid(_host)


func request_policy(
	request_id: String,
	request_envelope: Dictionary,
	_token_budget: int = 600,
	is_delta: bool = false
) -> int:
	if not is_configured() or request_id == "":
		return ERR_UNCONFIGURED
	var bindings: Array = request_envelope.get("current_root_candidate_bindings", []) \
		if request_envelope.get("current_root_candidate_bindings", []) is Array else []
	if bindings.is_empty() or not (bindings[0] is Dictionary):
		return ERR_INVALID_DATA
	var binding: Dictionary = bindings[0]
	var candidate_id := str(binding.get("candidate_id", ""))
	var route_id := str(binding.get("route_id", ""))
	if candidate_id == "" or route_id == "":
		return ERR_INVALID_DATA
	_request_count += 1
	var response := {
		"agenda_patch": {},
		"policy": {
			"root_node_id": "node:delta_root" if is_delta else "node:root",
			"nodes": [{
				"node_id": "node:delta_root" if is_delta else "node:root",
				"kind": "route",
				"route_ref": {
					"mode": "select_candidate",
					"route_id": route_id,
					"candidate_id": candidate_id,
				},
			}],
			"reservations": [],
			"interaction_policy_refs": {},
			"interaction_policies": [],
			"replan_if": [],
		},
	}
	var metrics := {
		"request_wall_ms": 0,
		"visible_wait_ms": 0,
		"payload_bytes": JSON.stringify(request_envelope).to_utf8_buffer().size(),
		"response_bytes": JSON.stringify(response).to_utf8_buffer().size(),
		"is_delta": is_delta,
		"transport": "deterministic_rule_root_fixture",
		"rng_isolated_transport": true,
		"rng_isolated_request_sequence": _request_count,
	}
	call_deferred("_emit_response", request_id, response, metrics)
	return OK


func has_pending(_request_id: String = "") -> bool:
	return false


func _emit_response(request_id: String, response: Dictionary, metrics: Dictionary) -> void:
	response_ready.emit(request_id, response, metrics)
