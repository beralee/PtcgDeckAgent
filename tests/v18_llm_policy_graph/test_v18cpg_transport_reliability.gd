extends SceneTree

const DecisionClientScript = preload(
	"res://scripts/ai/v18_cpg/network/V18CPGDecisionClient.gd"
)
const RngIsolatedTransportScript = preload(
	"res://scripts/ai/v18_cpg/network/V18CPGRngIsolatedDeepSeekClient.gd"
)
const PolicyValidatorScript = preload(
	"res://scripts/ai/v18_cpg/policy/V18CPGPolicyValidator.gd"
)
const StrategyScript = preload(
	"res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd"
)

var _failures: Array[String] = []


func _initialize() -> void:
	_test_deepseek_length_cutoff_is_not_reported_as_transport_error()
	_test_official_deepseek_direct_contract()
	_test_delta_budget_can_finish_a_compact_policy_graph()
	_test_player_status_uses_recoverable_language()
	if _failures.is_empty():
		print("V18CPG transport reliability: PASS (4 groups)")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("V18CPG transport reliability: FAIL (%d)" % _failures.size())
	quit(1)


func _test_deepseek_length_cutoff_is_not_reported_as_transport_error() -> void:
	var raw_response := JSON.stringify({
		"id": "fixture-length-cutoff",
		"object": "chat.completion",
		"model": "deepseek-v4-pro",
		"choices": [{
			"index": 0,
			"message": {
				"role": "assistant",
				"content": "{\"policy\":{\"root_node_id\":\"node:delta_root\",\"nodes\":[",
			},
			"finish_reason": "length",
		}],
		"usage": {
			"prompt_tokens": 6532,
			"completion_tokens": 180,
		},
	})
	var transport := RngIsolatedTransportScript.new()
	var parsed: Dictionary = transport.call("_parse_chat_response", 200, raw_response)
	_check(
		str(parsed.get("status", "")) == "error"
			and str(parsed.get("error_type", "")) == "response_truncated"
			and str(parsed.get("finish_reason", "")) == "length",
		"a length-cut DeepSeek JSON response must be classified as response_truncated"
	)
	var validation := PolicyValidatorScript.new().validate_response(parsed, [], 8)
	_check(
		not bool(validation.get("valid", false))
			and str(validation.get("reason", "")) == "response_truncated",
		"policy validation must preserve the real truncation reason instead of transport_error"
	)


func _test_official_deepseek_direct_contract() -> void:
	var transport := RngIsolatedTransportScript.new()
	_check(
		transport.is_official_deepseek_endpoint("https://api.deepseek.com")
			and transport.is_official_deepseek_endpoint(
				"https://api.deepseek.com/v1"
			)
			and not transport.is_official_deepseek_endpoint(
				"https://zenmux.ai/api/v1"
			),
		"the V18 transport must accept only the official DeepSeek endpoint"
	)
	var payload: Dictionary = transport.call(
		"_build_request_payload_for_endpoint",
		{
			"model": "deepseek-v4-pro",
			"messages": [
				{"role": "system", "content": "Return JSON only."},
				{"role": "user", "content": "{}"},
			],
			"reasoning": {"enabled": false},
			"thinking": {"type": "disabled"},
			"response_format": {"type": "json_object"},
			"max_tokens": 512,
		},
		"https://api.deepseek.com/chat/completions"
	)
	_check(
		payload.get("response_format", {}) == {"type": "json_object"}
			and payload.get("thinking", {}) == {"type": "disabled"}
			and not payload.has("reasoning"),
		"the official DeepSeek payload must preserve JSON mode and omit ZenMux-only reasoning"
	)
	var client := DecisionClientScript.new()
	client.configure(root, {
		"endpoint": "https://zenmux.ai/api/v1",
		"api_key": "fixture",
		"model": "deepseek-v4-pro",
	})
	_check(
		not client.is_configured(),
		"a ZenMux endpoint must fail closed even when a DeepSeek model name is supplied"
	)
	client.configure(root, {
		"endpoint": "https://api.deepseek.com",
		"api_key": "fixture",
		"model": "deepseek-v4-pro",
	})
	_check(
		client.is_configured(),
		"the V18 decision client must accept the official DeepSeek direct config"
	)


func _test_delta_budget_can_finish_a_compact_policy_graph() -> void:
	var client := DecisionClientScript.new()
	_check(
		client.has_method("resolve_token_budget"),
		"the V18 decision client must expose its bounded effective token budget"
	)
	if not client.has_method("resolve_token_budget"):
		return
	var delta_budget := int(client.call("resolve_token_budget", 180, true))
	var initial_budget := int(client.call("resolve_token_budget", 420, false))
	_check(
		delta_budget == 512,
		"the effective delta budget must keep a 512-token completion safety margin"
	)
	_check(
		initial_budget == 512,
		"the initial graph must receive the same 512-token completion safety margin"
	)
	var payload: Dictionary = client.call("_build_payload", {
		"limits": {"max_policy_nodes": 8},
		"frontier": [],
		"allowed_follow_route_ids": [],
	}, delta_budget, true)
	var messages: Array = payload.get("messages", []) if payload.get("messages", []) is Array else []
	var system_text := str(
		(messages[0] as Dictionary).get("content", "")
		if not messages.is_empty() and messages[0] is Dictionary
		else ""
	)
	_check(
		int(payload.get("max_tokens", 0)) == delta_budget,
		"the resolved completion budget must reach the actual transport payload"
	)
	_check(
		system_text.contains("minified JSON")
			and system_text.contains("complete one-node response"),
		"the compact contract must prefer a complete minimal graph over a truncated larger graph"
	)


func _test_player_status_uses_recoverable_language() -> void:
	var strategy := StrategyScript.new()
	var player_reason := str(strategy.call(
		"_user_facing_response_reason",
		false,
		"response_truncated"
	))
	_check(
		player_reason.contains("自动切换本地策略")
			and not player_reason.contains("transport_error"),
		"the battle status must describe the safe fallback instead of showing an internal transport error"
	)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
