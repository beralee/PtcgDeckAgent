class_name AuthorStrategyPolicyWorker
extends RefCounted

var _thread: Thread = null


func start(
	selector: Variant,
	frame: Dictionary,
	model_actor: Variant = null,
	run_model: bool = false,
) -> Dictionary:
	if has_task():
		return {"ok": false, "error_code": "policy_worker_busy"}
	if selector == null or not selector.has_method("select") or frame.is_empty():
		return {"ok": false, "error_code": "policy_worker_request_invalid"}
	_thread = Thread.new()
	var error := _thread.start(
		Callable(self, "_run_select").bind(
			selector, frame.duplicate(true), model_actor, run_model
		)
	)
	if error != OK:
		_thread = null
		return {"ok": false, "error_code": "policy_worker_start_failed"}
	return {"ok": true, "error_code": ""}


func has_task() -> bool:
	return _thread != null and _thread.is_started()


func is_ready() -> bool:
	return has_task() and not _thread.is_alive()


func take_result() -> Dictionary:
	if not is_ready():
		return {"ready": false, "response": {}}
	var raw_result: Variant = _thread.wait_to_finish()
	_thread = null
	if raw_result is Dictionary:
		var completed := (raw_result as Dictionary).duplicate(true)
		completed["ready"] = true
		return completed
	return {
		"ready": true,
		"response": {"ok": false, "error_code": "package_policy_response_invalid"},
	}


func close() -> void:
	if has_task():
		_thread.wait_to_finish()
	_thread = null


func _run_select(
	selector: Variant,
	frame: Dictionary,
	model_actor: Variant,
	run_model: bool,
) -> Dictionary:
	var raw_response: Variant = selector.call("select", frame)
	if not raw_response is Dictionary:
		return {
			"response": {"ok": false, "error_code": "package_policy_response_invalid"},
		}
	var response := (raw_response as Dictionary).duplicate(true)
	var completed := {"response": response}
	if run_model and model_actor != null and model_actor.has_method("decide_development_frame"):
		var validated: Variant = _validated_policy_indexes(selector, frame, response)
		if validated is Array:
			var indexes: Array = validated
			completed["model_decision"] = model_actor.call(
				"decide_development_frame",
				frame,
				indexes,
				_model_frontier_from_response(response, indexes, frame.get("options", []).size())
			)
	return completed


func _validated_policy_indexes(
	selector: Variant, frame: Dictionary, response: Dictionary
) -> Variant:
	if not bool(response.get("ok", false)):
		return null
	var source: Variant = frame.get("source")
	var semantics: Variant = frame.get("select_semantics")
	var options: Variant = frame.get("options")
	if not source is Dictionary or not semantics is Dictionary or not options is Array:
		return null
	var expected_source := str(selector.call("expected_selection_source")) \
		if selector.has_method("expected_selection_source") else "restricted_ir_same_window"
	if (
		response.get("public_observation_hash") != source.get("public_observation_hash")
		or response.get("window_id") != source.get("window_id")
		or response.get("selection_source") != expected_source
	):
		return null
	var raw: Variant = response.get("selected_indexes")
	var minimum := int(semantics.get("min_count", -1))
	var maximum := int(semantics.get("max_count", -1))
	if not raw is Array or raw.size() < minimum or raw.size() > maximum:
		return null
	var result: Array[int] = []
	for value: Variant in raw:
		if typeof(value) != TYPE_INT:
			return null
		var index := int(value)
		if index < 0 or index >= options.size() or index in result:
			return null
		result.append(index)
	return result


func _model_frontier_from_response(
	response: Dictionary, fallback_indexes: Array, option_count: int
) -> Array[int]:
	var decision_audit: Variant = response.get("decision_audit")
	if not decision_audit is Dictionary:
		return _typed_indexes(fallback_indexes)
	var base_result: Variant = decision_audit.get("base_result")
	if not base_result is Dictionary or not base_result.get("node_audit") is Array:
		return _typed_indexes(fallback_indexes)
	var raw_frontier: Variant = null
	for node_value: Variant in base_result.get("node_audit"):
		if node_value is Dictionary and node_value.get("operator") == "base_veto":
			raw_frontier = node_value.get("output_indexes")
	if not raw_frontier is Array or raw_frontier.is_empty():
		return _typed_indexes(fallback_indexes)
	var result: Array[int] = []
	for value: Variant in raw_frontier:
		if typeof(value) != TYPE_INT:
			return _typed_indexes(fallback_indexes)
		var index := int(value)
		if index < 0 or index >= option_count or index in result:
			return _typed_indexes(fallback_indexes)
		result.append(index)
	return result


func _typed_indexes(values: Array) -> Array[int]:
	var result: Array[int] = []
	for value: Variant in values:
		if typeof(value) == TYPE_INT:
			result.append(int(value))
	return result
