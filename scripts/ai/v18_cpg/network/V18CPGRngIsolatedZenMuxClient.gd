class_name V18CPGRngIsolatedZenMuxClient
extends "res://scripts/network/ZenMuxClient.gd"

## V18CPG transport adapter.
##
## The shared ZenMux fallback consumes the process-wide random-number stream
## when it creates temporary filenames.  That advances the same RNG used by a
## duel and makes a rejected model response capable of changing game results.
## Keep the shared protocol/parser/process implementation, but replace the one
## side-effectful filename operation inside this isolated experimental client.

const V18_FALLBACK_USER_DIR := "user://tmp/v18cpg/zenmux"

var _request_sequence: int = 0


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
