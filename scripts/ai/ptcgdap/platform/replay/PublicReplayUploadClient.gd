class_name PtcgDAPPublicReplayUploadClient
extends Node

const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")
const ServiceContractScript = preload("res://scripts/ai/ptcgdap/platform/replay/PublicReplayServiceContract.gd")
const ARTIFACT_KEYS := ["match_envelope", "manifest", "frames"]
const COMMUNITY_LANE := "community_challenge"

signal upload_completed(result: Dictionary)

var _contract_owner: Variant = null
var _transport: Variant = null
var _owns_transport := false
var _base_url := ""
var _bearer_token := ""
var _upload_path := ""
var _max_upload_bytes := 0
var _max_response_bytes := 0
var _service_contract_sha256 := ""
var _in_flight := false
var _last_body := ""
var _last_headers := PackedStringArray()
var _last_replay_id := ""
var _last_artifact_sha256 := ""
var _last_result: Dictionary = {}
var _attempt_count := 0


static func create(
	contract_owner: Variant,
	transport: Variant,
	base_url: String,
	bearer_token: String,
	allow_insecure_loopback: bool = false
) -> Dictionary:
	if contract_owner == null \
			or not contract_owner.has_method("validate_document") \
			or not contract_owner.has_method("validate_replay"):
		return _failure("contract_owner_invalid")
	var service_contract_result := ServiceContractScript.load_fixed()
	if not bool(service_contract_result.get("accepted", false)):
		return service_contract_result
	var service_contract: Dictionary = service_contract_result.value
	var endpoint_error := ServiceContractScript.validate_endpoint(
		base_url, allow_insecure_loopback, service_contract.transport.development_insecure_hosts
	)
	if not endpoint_error.is_empty():
		return _failure(endpoint_error)
	if not ServiceContractScript.valid_temporary_token(bearer_token):
		return _failure("upload_token_invalid")
	var client := new()
	client._contract_owner = contract_owner
	client._base_url = base_url.trim_suffix("/")
	client._bearer_token = bearer_token
	client._upload_path = str(service_contract.routes.upload.path)
	client._max_upload_bytes = int(service_contract.ingest.max_upload_bytes)
	client._max_response_bytes = int(service_contract.ingest.max_response_bytes)
	client._service_contract_sha256 = str(service_contract_result.canonical_sha256)
	if transport == null:
		var request := HTTPRequest.new()
		request.timeout = 30.0
		request.use_threads = true
		client.add_child(request)
		client._transport = request
		client._owns_transport = true
	else:
		if not transport.has_method("request"):
			client.free()
			return _failure("upload_transport_invalid")
		client._transport = transport
	if not client._transport.has_signal("request_completed"):
		client.free()
		return _failure("upload_transport_invalid")
	client._transport.request_completed.connect(client._on_request_completed)
	return {"accepted": true, "error_code": "", "client": client}


func upload(artifact: Variant) -> Dictionary:
	if _in_flight:
		return _failure("upload_busy")
	var validated := _validate_artifact(artifact)
	if not bool(validated.get("accepted", false)):
		return validated
	_last_body = str(validated.get("body", ""))
	_last_replay_id = str(validated.get("replay_id", ""))
	_last_artifact_sha256 = str(validated.get("artifact_sha256", ""))
	_last_headers = PackedStringArray([
		"Content-Type: application/json; charset=utf-8",
		"Authorization: Bearer %s" % _bearer_token,
	])
	_last_result = {}
	return _send_last()


func retry_last() -> Dictionary:
	if _in_flight:
		return _failure("upload_busy")
	if _last_body.is_empty() or not bool(_last_result.get("retryable", false)):
		return _failure("upload_retry_unavailable")
	return _send_last()


func last_result() -> Dictionary:
	return _last_result.duplicate(true)


func audit_snapshot() -> Dictionary:
	return {
		"document_type": "public_replay_upload_audit_v1",
		"schema_version": 1,
		"replay_id": _last_replay_id,
		"artifact_sha256": _last_artifact_sha256,
		"service_contract_sha256": _service_contract_sha256,
		"attempt_count": _attempt_count,
		"in_flight": _in_flight,
		"authoritative": false,
		"engine_invocations": 0,
		"ticket_invocations": 0,
		"callback_invocations": 0,
		"grants": [],
	}


func _validate_artifact(artifact: Variant) -> Dictionary:
	if not artifact is Dictionary or not _has_exact_keys(artifact, ARTIFACT_KEYS):
		return _failure("replay_artifact_invalid")
	var envelope: Variant = artifact.get("match_envelope")
	if not envelope is Dictionary or envelope.get("lane") != COMMUNITY_LANE:
		return _failure("replay_lane_upload_forbidden")
	var envelope_result: Dictionary = _contract_owner.validate_document(envelope)
	if not bool(envelope_result.get("accepted", false)):
		return envelope_result
	var manifest: Variant = artifact.get("manifest")
	var replay_result: Dictionary = _contract_owner.validate_replay(manifest, artifact.get("frames"))
	if not bool(replay_result.get("accepted", false)):
		return replay_result
	if (
		not manifest is Dictionary
		or envelope.get("match_id") != manifest.get("match_id")
		or envelope_result.get("canonical_sha256") != manifest.get("match_envelope_sha256")
		or replay_result.get("replay_id") != manifest.get("replay_id")
		or replay_result.get("match_id") != envelope.get("match_id")
	):
		return _failure("replay_envelope_binding_invalid")
	var canonical: Dictionary = CabtJsonTreeScript.canonicalize_artifact(
		artifact,
		{"max_output_bytes": _max_upload_bytes}
	)
	if not bool(canonical.get("ok", false)):
		return _failure("replay_artifact_invalid")
	var body_bytes: PackedByteArray = canonical.get("bytes", PackedByteArray())
	if body_bytes.is_empty() or body_bytes.size() > _max_upload_bytes:
		return _failure("request_too_large")
	var artifact_sha256 := ServiceContractScript.sha256(body_bytes)
	if artifact_sha256.is_empty():
		return _failure("hash_unavailable")
	return {
		"accepted": true,
		"error_code": "",
		"body": body_bytes.get_string_from_utf8(),
		"replay_id": manifest.get("replay_id"),
		"artifact_sha256": artifact_sha256,
		"authoritative": false,
		"grants": [],
	}


func _send_last() -> Dictionary:
	_in_flight = true
	_attempt_count += 1
	var error: int = _transport.request(
		"%s%s" % [_base_url, _upload_path],
		_last_headers,
		HTTPClient.METHOD_POST,
		_last_body
	)
	if error != OK:
		_in_flight = false
		_last_result = {
			"accepted": false,
			"error_code": "upload_start_failed",
			"transport_error": error,
			"retryable": true,
			"authoritative": false,
			"grants": [],
		}
		return _last_result.duplicate(true)
	return {
		"accepted": true,
		"error_code": "",
		"started": true,
		"replay_id": _last_replay_id,
		"artifact_sha256": _last_artifact_sha256,
		"attempt": _attempt_count,
		"authoritative": false,
		"grants": [],
	}


func _on_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	_in_flight = false
	if result != HTTPRequest.RESULT_SUCCESS:
		_finish({
			"accepted": false,
			"error_code": "upload_transport_failed",
			"transport_result": result,
			"retryable": true,
			"authoritative": false,
			"grants": [],
		})
		return
	if body.size() > _max_response_bytes:
		_finish(_response_failure("upload_response_too_large", false, response_code))
		return
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK or not json.data is Dictionary:
		_finish(_response_failure("upload_response_invalid", response_code >= 500, response_code))
		return
	var response: Dictionary = json.data
	if response_code < 200 or response_code >= 300:
		var retryable := response_code == 408 or response_code == 425 or response_code == 429 or response_code >= 500
		var code := "upload_server_rejected"
		var returned_code: Variant = response.get("error_code")
		if typeof(returned_code) == TYPE_STRING and returned_code in [
			"replay_identity_conflict", "replay_quota_exceeded", "request_too_large",
			"replay_lane_upload_forbidden", "private_field_forbidden",
		]:
			code = str(returned_code)
		_finish(_response_failure(code, retryable, response_code))
		return
	var record: Variant = response.get("record")
	if (
		typeof(response.get("created")) != TYPE_BOOL
		or not record is Dictionary
		or record.get("replay_id") != _last_replay_id
		or record.get("artifact_sha256") != _last_artifact_sha256
		or record.get("service_contract_sha256") != _service_contract_sha256
		or record.get("authoritative") != false
		or record.get("grants") != []
	):
		_finish(_response_failure("upload_response_binding_invalid", false, response_code))
		return
	_finish({
		"accepted": true,
		"error_code": "",
		"created": response.get("created"),
		"replay_id": _last_replay_id,
		"artifact_sha256": _last_artifact_sha256,
		"http_status": response_code,
		"retryable": false,
		"authoritative": false,
		"grants": [],
	})


func _finish(result: Dictionary) -> void:
	_last_result = result.duplicate(true)
	upload_completed.emit(_last_result.duplicate(true))


static func _response_failure(code: String, retryable: bool, status: int) -> Dictionary:
	return {
		"accepted": false,
		"error_code": code,
		"http_status": status,
		"retryable": retryable,
		"authoritative": false,
		"grants": [],
	}


static func _has_exact_keys(value: Dictionary, keys: Array) -> bool:
	if value.size() != keys.size():
		return false
	for key: Variant in keys:
		if not value.has(key):
			return false
	return true


static func _failure(code: String) -> Dictionary:
	return {
		"accepted": false,
		"error_code": code,
		"authoritative": false,
		"grants": [],
	}
