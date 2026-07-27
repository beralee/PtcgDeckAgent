class_name V18CPGRngIsolatedDeepSeekClient
extends "res://scripts/network/ZenMuxClient.gd"

## V18CPG official DeepSeek transport adapter.
##
## The legacy compatibility transport consumes the process-wide random-number
## stream when it creates temporary filenames. That advances the same RNG used
## by a duel and makes a rejected model response capable of changing results.
## Reuse only its provider-neutral HTTP/parser plumbing. This adapter rejects
## every non-DeepSeek endpoint, restores official DeepSeek JSON mode, sanitizes
## provider-facing diagnostics, and replaces the side-effectful filename path.

const OFFICIAL_DEEPSEEK_ENDPOINT := "https://api.deepseek.com"
const V18_FALLBACK_USER_DIR := "user://tmp/v18cpg/deepseek"

var _request_sequence: int = 0


func request_json(
	parent: Node,
	endpoint: String,
	api_key: String,
	payload: Dictionary,
	callback: Callable
) -> int:
	if not is_official_deepseek_endpoint(endpoint):
		return ERR_INVALID_PARAMETER
	return super.request_json(parent, endpoint, api_key, payload, callback)


func is_official_deepseek_endpoint(endpoint: String) -> bool:
	var normalized := endpoint.strip_edges().trim_suffix("/").to_lower()
	return normalized in [
		OFFICIAL_DEEPSEEK_ENDPOINT,
		OFFICIAL_DEEPSEEK_ENDPOINT + "/v1",
	]


func _build_request_payload_for_endpoint(
	payload: Dictionary,
	request_url: String
) -> Dictionary:
	var request_payload: Dictionary = super._build_request_payload_for_endpoint(
		payload,
		request_url
	)
	if not is_official_deepseek_endpoint(
		request_url.trim_suffix("/chat/completions")
	):
		return request_payload
	# The shared compatibility layer intentionally strips provider-specific
	# response_format values. DeepSeek's official JSON mode requires this exact
	# field in addition to a prompt that explicitly asks for JSON.
	request_payload["response_format"] = {"type": "json_object"}
	request_payload.erase("reasoning")
	request_payload.erase("enable_thinking")
	request_payload["thinking"] = {"type": "disabled"}
	return request_payload


func _parse_chat_response(response_code: int, response_text: String) -> Dictionary:
	var normalized: Dictionary = super._parse_chat_response(response_code, response_text)
	if str(normalized.get("message", "")).contains("ZenMux"):
		normalized["message"] = str(normalized.get("message", "")).replace(
			"ZenMux",
			"DeepSeek"
		)
	var completion_metadata := _completion_metadata(response_text)
	var finish_reason := str(completion_metadata.get("finish_reason", ""))
	# Preserve provider completion evidence for accepted and rejected responses.
	# Without this, production audit reports every successful graph as zero
	# completion tokens and cannot distinguish concise output from hidden bloat.
	normalized["finish_reason"] = finish_reason
	normalized["prompt_tokens"] = int(completion_metadata.get("prompt_tokens", 0))
	normalized["completion_tokens"] = int(completion_metadata.get("completion_tokens", 0))
	if str(normalized.get("status", "")) != "error":
		return normalized
	if finish_reason in ["length", "max_tokens", "max_output_tokens"]:
		# HTTP succeeded, but the provider stopped at its completion limit before
		# closing the JSON object. This is a model-output cutoff, not a network
		# transport failure. Preserve the distinction for audit and UI fallback.
		normalized["error_type"] = "response_truncated"
	return normalized


func _completion_metadata(response_text: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(response_text)
	if not (parsed is Dictionary):
		return {}
	var response := parsed as Dictionary
	var finish_reason := ""
	var choices: Variant = response.get("choices", [])
	if choices is Array and not (choices as Array).is_empty():
		var first_choice: Variant = (choices as Array)[0]
		if first_choice is Dictionary:
			finish_reason = str((first_choice as Dictionary).get("finish_reason", ""))
	if finish_reason == "" and str(response.get("status", "")) == "incomplete":
		var incomplete_details: Variant = response.get("incomplete_details", {})
		if incomplete_details is Dictionary:
			finish_reason = str((incomplete_details as Dictionary).get("reason", ""))
	var usage: Dictionary = (
		response.get("usage", {}) as Dictionary
		if response.get("usage", {}) is Dictionary
		else {}
	)
	return {
		"finish_reason": finish_reason,
		"prompt_tokens": int(usage.get("prompt_tokens", usage.get("input_tokens", 0))),
		"completion_tokens": int(usage.get("completion_tokens", usage.get("output_tokens", 0))),
	}


func _write_python_fallback_request(request_url: String, api_key: String, request_payload: Dictionary) -> Dictionary:
	var script_path := _ensure_python_fallback_script()
	if script_path == "":
		return {}
	var temp_dir := ProjectSettings.globalize_path(V18_FALLBACK_USER_DIR)
	if DirAccess.make_dir_recursive_absolute(temp_dir) != OK:
		return {}
	_request_sequence += 1
	# Process id + object id + monotonic sequence is unique for every live V18
	# client without consulting either the gameplay RNG or a local PRNG.
	var token := "%d_%d_%d" % [OS.get_process_id(), get_instance_id(), _request_sequence]
	var input_path := "%s/request_%s.json" % [temp_dir, token]
	var output_path := "%s/response_%s.json" % [temp_dir, token]
	var input := {
		"url": request_url,
		"api_key": api_key,
		"payload": request_payload,
		"timeout_seconds": _timeout_seconds,
		"allow_unsafe_tls": _allow_unsafe_tls,
	}
	var input_file := FileAccess.open(input_path, FileAccess.WRITE)
	if input_file == null:
		return {}
	input_file.store_string(JSON.stringify(input))
	input_file.close()
	return {
		"script_path": script_path,
		"input_path": input_path,
		"output_path": output_path,
	}


func _normalize_python_fallback_output(output_text: String) -> Dictionary:
	var normalized := super._normalize_python_fallback_output(output_text)
	# Export non-secret provenance so paired benchmarks can prove that the
	# isolated filename path, rather than the shared implementation, ran.
	normalized["rng_isolated_transport"] = true
	normalized["rng_isolated_request_sequence"] = _request_sequence
	return normalized
