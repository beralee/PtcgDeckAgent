extends "res://scripts/ai/v18_cpg/network/V18CPGRngIsolatedDeepSeekClient.gd"
## Own client instance, verified TLS, no Python subprocess/temp credentials/RNG.
func _init() -> void:
	set_allow_unsafe_tls(false)
	set_allow_python_fallback(false)
	set_timeout_seconds(18.0)

func _parse_chat_response(response_code: int, response_text: String) -> Dictionary:
	# Content cannot forge provider usage/status; keep the envelopes separate.
	var result := {"ok": false, "content": {}, "tokens": -1}
	if response_code < 200 or response_code >= 300: return result
	var parser := JSON.new()
	if parser.parse(response_text) != OK: return result
	var envelope: Variant = parser.data
	if not envelope is Dictionary: return result
	var usage: Variant = envelope.get("usage", {})
	if usage is Dictionary and usage.get("prompt_tokens") is float and usage.get("completion_tokens") is float:
		if usage.prompt_tokens >= 0 and usage.completion_tokens >= 0:
			result.tokens = int(usage.prompt_tokens) + int(usage.completion_tokens)
	var choices: Variant = envelope.get("choices")
	if not choices is Array or choices.is_empty() or not choices[0] is Dictionary: return result
	var choice: Dictionary = choices[0]
	if choice.get("finish_reason") != "stop": return result
	var message: Variant = choice.get("message")
	if not message is Dictionary or not message.get("content") is String: return result
	if parser.parse(message.content) != OK: return result
	var content: Variant = parser.data
	if not content is Dictionary: return result
	result.ok = true
	result.content = content
	return result
