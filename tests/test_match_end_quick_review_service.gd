class_name TestMatchEndQuickReviewService
extends TestBase

const MatchEndQuickReviewServiceScript = preload("res://scripts/engine/MatchEndQuickReviewService.gd")


class FakeQuickReviewClient:
	extends RefCounted

	var request_payload: Dictionary = {}
	var requested_endpoint := ""
	var requested_api_key := ""
	var timeout_seconds := 0.0

	func set_timeout_seconds(value: float) -> void:
		timeout_seconds = value

	func request_json(_parent: Node, endpoint: String, api_key: String, payload: Dictionary, callback: Callable) -> int:
		requested_endpoint = endpoint
		requested_api_key = api_key
		request_payload = payload.duplicate(true)
		callback.call({
			"score": 88,
			"grade": "A",
			"headline": "节奏明确",
			"praise": "关键奖赏路线处理得好。",
			"improvement": "注意保留一张换位资源。",
			"next_goal": "下一盘继续保持前两回合展开。",
		})
		return OK


class FakeTimeoutQuickReviewClient:
	extends RefCounted

	var timeout_seconds := 0.0

	func set_timeout_seconds(value: float) -> void:
		timeout_seconds = value

	func request_json(_parent: Node, _endpoint: String, _api_key: String, _payload: Dictionary, callback: Callable) -> int:
		callback.call({
			"status": "error",
			"error_type": "python_fallback_timeout",
			"message": "ZenMux Python fallback timed out",
			"request_result": HTTPRequest.RESULT_TIMEOUT,
		})
		return OK


func test_match_end_quick_review_builds_compact_llm_request() -> String:
	var client := FakeQuickReviewClient.new()
	var service := MatchEndQuickReviewServiceScript.new()
	service.configure_dependencies(client)
	var completed: Array[Dictionary] = []
	service.quick_review_completed.connect(func(result: Dictionary) -> void:
		completed.append(result)
	)
	var parent := Node.new()

	var result: Dictionary = service.generate_quick_review(parent, {
		"winner_index": 0,
		"turn_number": 7,
		"view_player": {"prizes_taken": 6},
		"opponent": {"prizes_taken": 4},
	}, {
		"endpoint": "https://example.test",
		"api_key": "secret",
		"model": "test-model",
		"timeout_seconds": 60.0,
	})
	parent.free()

	var final_result: Dictionary = completed[0] if not completed.is_empty() else {}
	var payload_summary: Dictionary = client.request_payload.get("match_summary", {})

	return run_checks([
		assert_eq(str(result.get("status", "")), "running", "Quick review should report that the request was started"),
		assert_eq(client.requested_endpoint, "https://example.test", "Quick review should use the configured endpoint"),
		assert_eq(client.requested_api_key, "secret", "Quick review should use the configured API key"),
		assert_eq(str(client.request_payload.get("model", "")), "test-model", "Quick review should use the configured model"),
		assert_eq(str(client.request_payload.get("system_prompt_version", "")), "match_end_quick_review_v1", "Quick review payload should carry a stable prompt version"),
		assert_eq(int(payload_summary.get("turn_number", 0)), 7, "Quick review payload should include match stats"),
		assert_eq(str(final_result.get("status", "")), "completed", "Quick review result should be normalized to completed"),
		assert_eq(int(final_result.get("score", 0)), 88, "Quick review should preserve the model score"),
		assert_eq(str(final_result.get("headline", "")), "节奏明确", "Quick review should preserve the model headline"),
	])


func test_match_end_quick_review_returns_failed_result_on_timeout() -> String:
	var client := FakeTimeoutQuickReviewClient.new()
	var service := MatchEndQuickReviewServiceScript.new()
	service.configure_dependencies(client)
	var completed: Array[Dictionary] = []
	service.quick_review_completed.connect(func(result: Dictionary) -> void:
		completed.append(result)
	)
	var parent := Node.new()

	var result: Dictionary = service.generate_quick_review(parent, {}, {
		"endpoint": "https://example.test",
		"api_key": "secret",
		"model": "test-model",
		"timeout_seconds": 60.0,
	})
	parent.free()

	var final_result: Dictionary = completed[0] if not completed.is_empty() else {}
	var errors: Array = final_result.get("errors", [])
	var error: Dictionary = errors[0] if not errors.is_empty() and errors[0] is Dictionary else {}

	return run_checks([
		assert_eq(str(result.get("status", "")), "running", "Quick review timeout should still start through the async request path"),
		assert_eq(str(final_result.get("status", "")), "failed", "Quick review should normalize timeout responses as failed results"),
		assert_eq(str(error.get("error_type", "")), "python_fallback_timeout", "Quick review should preserve timeout error type"),
		assert_eq(int(error.get("request_result", 0)), HTTPRequest.RESULT_TIMEOUT, "Quick review should preserve request result diagnostics"),
		assert_eq(str(final_result.get("model_id", "")), "test-model", "Failed quick review should retain model id for diagnostics"),
	])
