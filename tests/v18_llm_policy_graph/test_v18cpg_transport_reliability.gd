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
const ProfileCatalogScript = preload(
	"res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd"
)

var _failures: Array[String] = []


class RequestProbe:
	extends RefCounted

	var request_count := 0

	func request_policy(
		_request_id: String,
		_request_envelope: Dictionary,
		_token_budget: int = 600,
		_is_delta: bool = false
	) -> int:
		request_count += 1
		return OK


func _initialize() -> void:
	_test_deepseek_length_cutoff_is_not_reported_as_transport_error()
	_test_successful_deepseek_response_preserves_completion_metadata()
	_test_official_deepseek_direct_contract()
	_test_delta_budget_can_finish_a_compact_policy_graph()
	_test_terminal_provider_errors_are_classified()
	_test_terminal_provider_error_opens_match_circuit()
	_test_player_status_uses_recoverable_language()
	if _failures.is_empty():
		print("V18CPG transport reliability: PASS (7 groups)")
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


func _test_successful_deepseek_response_preserves_completion_metadata() -> void:
	var raw_response := JSON.stringify({
		"id": "fixture-complete",
		"object": "chat.completion",
		"model": "deepseek-v4-pro",
		"choices": [{
			"index": 0,
			"message": {
				"role": "assistant",
				"content": JSON.stringify({
					"policy": {
						"root_node_id": "node:root",
						"nodes": [{
							"node_id": "node:root",
							"kind": "route",
							"route_ref": {
								"mode": "select_candidate",
								"route_id": "route:develop",
								"candidate_id": "candidate:develop",
							},
						}],
					},
				}),
			},
			"finish_reason": "stop",
		}],
		"usage": {
			"prompt_tokens": 6410,
			"completion_tokens": 233,
		},
	})
	var transport := RngIsolatedTransportScript.new()
	var parsed: Dictionary = transport.call("_parse_chat_response", 200, raw_response)
	_check(
		str(parsed.get("finish_reason", "")) == "stop"
			and int(parsed.get("prompt_tokens", 0)) == 6410
			and int(parsed.get("completion_tokens", 0)) == 233,
		"a successful DeepSeek response must preserve finish_reason and token usage for production audit"
	)
	var client := DecisionClientScript.new()
	_check(
		client.has_method("_semantic_response_for_validation"),
		"the decision client must isolate provider metrics from the semantic response"
	)
	if not client.has_method("_semantic_response_for_validation"):
		return
	var semantic_response: Dictionary = client.call(
		"_semantic_response_for_validation",
		parsed
	)
	var validation := PolicyValidatorScript.new().validate_response(
		semantic_response,
		["route:develop"],
		8,
		["candidate:develop"],
		true
	)
	_check(
		bool(validation.get("valid", false))
			and not semantic_response.has("finish_reason")
			and not semantic_response.has("prompt_tokens")
			and not semantic_response.has("completion_tokens"),
		"provider token metadata must reach audit metrics without becoming semantic additional properties"
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
	var delta_budget := int(client.call("resolve_token_budget", 180, true, 8))
	var initial_budget := int(client.call("resolve_token_budget", 420, false, 8))
	var six_node_budget := int(client.call(
		"resolve_token_budget",
		420,
		false,
		6
	))
	var four_node_budget := int(client.call(
		"resolve_token_budget",
		420,
		false,
		4
	))
	var bounded_budget := int(client.call(
		"resolve_token_budget",
		5000,
		false,
		20
	))
	_check(
		delta_budget == 1024,
		"an eight-node delta graph must receive the doubled 1024-token completion ceiling"
	)
	_check(
		initial_budget == 1024,
		"an eight-node initial graph must receive the doubled 1024-token completion ceiling"
	)
	_check(
		six_node_budget == 768 and four_node_budget == 512,
		"smaller graphs must retain node-aware 768/512 ceilings instead of paying the full latency allowance"
	)
	_check(
		bounded_budget == 1024,
		"the completion ceiling must remain globally bounded at 1024 tokens"
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
			and system_text.contains("complete one-node response")
			and system_text.contains("Omit a redundant terminal node"),
		"the compact contract must prefer complete graphs and omit token-wasting terminal nodes"
	)


func _test_terminal_provider_errors_are_classified() -> void:
	var validator := PolicyValidatorScript.new()
	var quota := validator.validate_response({
		"status": "error",
		"error_type": "http_error",
		"http_code": 402,
	}, [], 8)
	var auth := validator.validate_response({
		"status": "error",
		"error_type": "http_error",
		"http_code": 401,
	}, [], 8)
	_check(
		str(quota.get("reason", "")) == "provider_quota_exhausted"
			and str(auth.get("reason", "")) == "provider_auth_error",
		"terminal provider quota/auth responses must not collapse into transport_error"
	)


func _test_terminal_provider_error_opens_match_circuit() -> void:
	var strategy := StrategyScript.new()
	strategy.configure_profile(
		ProfileCatalogScript.get_profile_for_deck(800018509)
	)
	strategy.configure_verified_local_only_for_benchmark()
	var probe := RequestProbe.new()
	strategy.set("_decision_client", probe)
	var state := GameState.new()
	state.turn_number = 3
	state.current_player_index = 0
	state.first_player_index = 1
	state.phase = GameState.GamePhase.MAIN
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	state.players = [player, opponent]
	var first: Dictionary = strategy.prepare_decision(
		state,
		0,
		[
			{"id": "action:develop", "kind": "play_basic_to_bench"},
			{"id": "action:end", "kind": "end_turn"},
		],
		{
			"event_type": "MAIN_ACTION_WINDOW",
			"rule_floor_action_id": "action:end",
		}
	)
	var request_id := str(first.get("request_id", ""))
	strategy.call("_on_policy_response", request_id, {
		"status": "error",
		"error_type": "http_error",
		"http_code": 402,
	}, {
		"provider_http_code": 402,
		"provider_error_type": "http_error",
	})
	state.turn_number = 5
	var result: Dictionary = strategy.prepare_decision(
		state,
		0,
		[
			{"id": "action:develop", "kind": "play_basic_to_bench"},
			{"id": "action:end", "kind": "end_turn"},
		],
		{
			"event_type": "MAIN_ACTION_WINDOW",
			"rule_floor_action_id": "action:end",
		}
	)
	_check(
		str(first.get("status", "")) == "pending"
			and str(result.get("status", "")) == "ready"
			and str(result.get("owner", "")) == "rules_fallback"
			and probe.request_count == 1
			and not bool(strategy.get("_runtime_configured"))
			and bool(strategy.get("_turn_model_judgment_resolved")),
		"a terminal provider failure must suppress later same-match requests and resolve through Rule"
	)
	strategy.configure_profile(
		ProfileCatalogScript.get_profile_for_deck(800018509)
	)
	_check(
		str(strategy.get("_provider_terminal_failure_reason")) == "",
		"a fresh match/profile configuration must close the provider circuit"
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
	var shadow_reason := str(strategy.call(
		"_user_facing_response_reason",
		true,
		"exact_rule_root_shadowed"
	))
	var takeover_reason := str(strategy.call(
		"_user_facing_response_reason",
		true,
		""
	))
	_check(
		shadow_reason.contains("当前动作沿用 Rule")
			and takeover_reason.contains("模型执行策略已校验")
			and shadow_reason != takeover_reason,
		"player status must distinguish an accepted planning shadow from a model-owned action"
	)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
