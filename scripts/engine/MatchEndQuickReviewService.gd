class_name MatchEndQuickReviewService
extends RefCounted

signal status_changed(status: String, context: Dictionary)
signal quick_review_completed(result: Dictionary)

const ZenMuxClientScript := preload("res://scripts/network/ZenMuxClient.gd")

const PROMPT_VERSION := "match_end_quick_review_v1"

var _client = ZenMuxClientScript.new()
var _busy := false


func configure_dependencies(client: Variant) -> void:
	if client != null:
		_client = client


func generate_quick_review(parent: Node, match_summary: Dictionary, api_config: Dictionary) -> Dictionary:
	if _busy:
		return {"status": "ignored"}
	_busy = true
	_set_status("running", {})
	if _client == null or not _client.has_method("request_json"):
		var missing_client := _failed_result(api_config, {
			"message": "ZenMux client is unavailable",
			"error_type": "client_unavailable",
		})
		_finish(missing_client)
		return missing_client
	if _client != null and _client.has_method("set_timeout_seconds"):
		_client.call("set_timeout_seconds", minf(float(api_config.get("timeout_seconds", 30.0)), 24.0))

	var payload := _build_payload(str(api_config.get("model", "")), match_summary)
	var request_error: int = _client.request_json(
		parent,
		str(api_config.get("endpoint", "")),
		str(api_config.get("api_key", "")),
		payload,
		_on_response.bind(api_config)
	)
	if request_error != OK:
		var failed := _failed_result(api_config, {
			"message": "ZenMux request could not be started",
			"request_error": request_error,
		})
		_finish(failed)
		return failed
	return {"status": "running"}


func _on_response(response: Dictionary, api_config: Dictionary) -> void:
	if str(response.get("status", "")) == "error":
		_finish(_failed_result(api_config, response))
		return
	var result := response.duplicate(true)
	result["status"] = "completed"
	result["generated_at"] = Time.get_datetime_string_from_system()
	result["model_id"] = str(api_config.get("model", ""))
	result["score"] = clampi(int(result.get("score", 70)), 0, 100)
	for key: String in ["grade", "headline", "praise", "improvement", "next_goal"]:
		result[key] = str(result.get(key, "")).strip_edges()
	_finish(result)


func _finish(result: Dictionary) -> void:
	_busy = false
	_set_status(str(result.get("status", "completed")), {})
	quick_review_completed.emit(result)


func _failed_result(api_config: Dictionary, response: Dictionary) -> Dictionary:
	return {
		"status": "failed",
		"generated_at": Time.get_datetime_string_from_system(),
		"model_id": str(api_config.get("model", "")),
		"errors": [{
			"message": str(response.get("message", "Unknown error")),
			"error_type": str(response.get("error_type", "")),
			"http_code": int(response.get("http_code", 0)),
			"request_error": int(response.get("request_error", 0)),
			"request_result": int(response.get("request_result", 0)),
		}],
		"raw_provider_response": response.duplicate(true),
	}


func _set_status(status: String, context: Dictionary) -> void:
	status_changed.emit(status, context)


func _build_payload(model: String, match_summary: Dictionary) -> Dictionary:
	return {
		"model": model,
		"system_prompt_version": PROMPT_VERSION,
		"response_format": _response_schema(),
		"instructions": PackedStringArray([
			"你是PTCG赛后教练，用中文回答。",
			"只使用提供的赛后统计与行动摘要，不要假装知道没有给出的隐藏信息。",
			"给出一个粗略分数即可，不需要精确判定每一步。",
			"胜利时强调成就感和可复用的成功点；失败时强调可执行的下一盘目标。",
			"保持非常简短：一句标题、一条亮点、一条改进点、一条下一盘目标。",
			"只返回符合 schema 的 JSON。",
		]),
		"match_summary": match_summary,
	}


func _response_schema() -> Dictionary:
	return {
		"type": "object",
		"additionalProperties": false,
		"required": ["score", "grade", "headline", "praise", "improvement", "next_goal"],
		"properties": {
			"score": {"type": "integer", "minimum": 0, "maximum": 100},
			"grade": {"type": "string", "maxLength": 8},
			"headline": {"type": "string", "maxLength": 80},
			"praise": {"type": "string", "maxLength": 120},
			"improvement": {"type": "string", "maxLength": 120},
			"next_goal": {"type": "string", "maxLength": 120},
		},
	}
