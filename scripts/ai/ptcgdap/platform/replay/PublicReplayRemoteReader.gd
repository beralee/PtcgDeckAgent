class_name PtcgDAPPublicReplayRemoteReader
extends Node

const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")
const ServiceContractScript = preload("res://scripts/ai/ptcgdap/platform/replay/PublicReplayServiceContract.gd")

const ARTIFACT_KEYS := ["match_envelope", "manifest", "frames"]
const LIST_KEYS := ["document_type", "schema_version", "items", "next_cursor", "authoritative", "grants"]
const RECORD_KEYS := [
	"document_type", "schema_version", "replay_id", "match_id", "lane",
	"artifact_sha256", "artifact_bytes", "artifact_status", "manifest_sha256",
	"match_envelope_sha256", "frame_count", "frame_chain_root_sha256",
	"visibility_profile", "service_contract_sha256", "strategy_release_refs",
	"created_at_utc", "expires_at_utc", "expired_at_utc", "retention_days",
	"metadata_policy", "authoritative", "grants",
]
const COMMUNITY_LANE := "community_challenge"

signal read_completed(result: Dictionary)

var _contract_owner: Variant = null
var _transport: Variant = null
var _base_url := ""
var _artifact_path_template := ""
var _list_path := ""
var _max_artifact_bytes := 0
var _max_response_bytes := 0
var _maximum_list_limit := 0
var _retention_days := 0
var _service_contract_sha256 := ""
var _in_flight := false
var _last_url := ""
var _last_operation := ""
var _last_requested_replay_id := ""
var _last_list_limit := 0
var _last_artifact_sha256 := ""
var _last_result: Dictionary = {}
var _attempt_count := 0


static func create(
	contract_owner: Variant,
	transport: Variant,
	base_url: String,
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
		return _failure(endpoint_error.replace("upload_", "read_"))
	var reader := new()
	reader._contract_owner = contract_owner
	reader._base_url = base_url.trim_suffix("/")
	reader._artifact_path_template = str(service_contract.routes.artifact.path_template)
	reader._list_path = str(service_contract.routes.list.path)
	reader._max_artifact_bytes = int(service_contract.ingest.max_upload_bytes)
	reader._max_response_bytes = int(service_contract.ingest.max_response_bytes)
	reader._maximum_list_limit = int(service_contract.listing.maximum_limit)
	reader._retention_days = int(service_contract.storage.community_public_replay_days)
	reader._service_contract_sha256 = str(service_contract_result.canonical_sha256)
	if transport == null:
		var request := HTTPRequest.new()
		request.timeout = 30.0
		request.use_threads = true
		reader.add_child(request)
		reader._transport = request
	else:
		if not transport.has_method("request"):
			reader.free()
			return _failure("read_transport_invalid")
		reader._transport = transport
	if not reader._transport.has_signal("request_completed"):
		reader.free()
		return _failure("read_transport_invalid")
	reader._transport.request_completed.connect(reader._on_request_completed)
	return {"accepted": true, "error_code": "", "reader": reader}


func fetch(replay_id: String) -> Dictionary:
	if _in_flight:
		return _failure("read_busy")
	if not ServiceContractScript.safe_replay_id(replay_id):
		return _failure("replay_id_invalid")
	_last_operation = "fetch"
	_last_requested_replay_id = replay_id
	_last_list_limit = 0
	_last_artifact_sha256 = ""
	_last_url = "%s%s" % [_base_url, _artifact_path_template.replace("{replay_id}", replay_id)]
	_last_result = {}
	return _send_last()


func list(limit: int, cursor: String = "") -> Dictionary:
	if _in_flight:
		return _failure("read_busy")
	if limit < 1 or limit > _maximum_list_limit:
		return _failure("list_limit_invalid")
	if not cursor.is_empty() and not ServiceContractScript.safe_replay_id(cursor):
		return _failure("list_cursor_invalid")
	_last_operation = "list"
	_last_requested_replay_id = ""
	_last_list_limit = limit
	_last_artifact_sha256 = ""
	_last_url = "%s%s?limit=%d" % [_base_url, _list_path, limit]
	if not cursor.is_empty():
		_last_url += "&cursor=%s" % cursor
	_last_result = {}
	return _send_last()


func retry_last() -> Dictionary:
	if _in_flight:
		return _failure("read_busy")
	if _last_url.is_empty() or not bool(_last_result.get("retryable", false)):
		return _failure("read_retry_unavailable")
	return _send_last()


func last_result() -> Dictionary:
	return _last_result.duplicate(true)


func audit_snapshot() -> Dictionary:
	return {
		"document_type": "public_replay_remote_read_audit_v1",
		"schema_version": 1,
		"operation": _last_operation,
		"replay_id": _last_requested_replay_id,
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


func _send_last() -> Dictionary:
	_in_flight = true
	_attempt_count += 1
	var error: int = _transport.request(
		_last_url, PackedStringArray(["Accept: application/json"]), HTTPClient.METHOD_GET, ""
	)
	if error != OK:
		_in_flight = false
		_last_result = _response_failure("read_start_failed", true, 0)
		_last_result["transport_error"] = error
		return _last_result.duplicate(true)
	return {
		"accepted": true,
		"error_code": "",
		"started": true,
		"operation": _last_operation,
		"replay_id": _last_requested_replay_id,
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
		var failure := _response_failure("read_transport_failed", true, response_code)
		failure["transport_result"] = result
		_finish(failure)
		return
	var maximum := _max_artifact_bytes if _last_operation == "fetch" else _max_response_bytes
	if body.is_empty() or body.size() > maximum:
		_finish(_response_failure(
			"replay_response_too_large" if body.size() > maximum else "read_response_invalid",
			false,
			response_code
		))
		return
	if response_code < 200 or response_code >= 300:
		var retryable := response_code == 408 or response_code == 425 or response_code == 429 \
				or response_code >= 500
		var code := _error_code_from_body(body)
		_finish(_response_failure(code, retryable, response_code))
		return
	var validated := _validate_artifact_response(body) if _last_operation == "fetch" \
			else _validate_list_response(body)
	if not bool(validated.get("accepted", false)):
		validated["http_status"] = response_code
		validated["retryable"] = false
		_finish(validated)
		return
	validated["http_status"] = response_code
	validated["retryable"] = false
	_finish(validated)


func _validate_artifact_response(body: PackedByteArray) -> Dictionary:
	var parsed_result := _parse_canonical(body, _max_artifact_bytes)
	if not bool(parsed_result.get("accepted", false)):
		return parsed_result
	var artifact: Variant = parsed_result.value
	if not artifact is Dictionary or not _has_exact_keys(artifact, ARTIFACT_KEYS):
		return _failure("replay_response_invalid")
	var envelope: Variant = artifact.get("match_envelope")
	var manifest: Variant = artifact.get("manifest")
	if not envelope is Dictionary or envelope.get("lane") != COMMUNITY_LANE:
		return _failure("replay_lane_read_forbidden")
	if not manifest is Dictionary:
		return _failure("replay_response_invalid")
	var envelope_result: Dictionary = _contract_owner.validate_document(envelope)
	if not bool(envelope_result.get("accepted", false)):
		return envelope_result
	var replay_result: Dictionary = _contract_owner.validate_replay(manifest, artifact.get("frames"))
	if not bool(replay_result.get("accepted", false)):
		return replay_result
	if (
		manifest.get("replay_id") != _last_requested_replay_id
		or envelope.get("match_id") != manifest.get("match_id")
		or envelope_result.get("canonical_sha256") != manifest.get("match_envelope_sha256")
		or replay_result.get("replay_id") != manifest.get("replay_id")
		or replay_result.get("match_id") != envelope.get("match_id")
	):
		return _failure("replay_response_binding_invalid")
	_last_artifact_sha256 = ServiceContractScript.sha256(body)
	if _last_artifact_sha256.is_empty():
		return _failure("hash_unavailable")
	return {
		"accepted": true,
		"error_code": "",
		"artifact": artifact.duplicate(true),
		"replay_id": _last_requested_replay_id,
		"artifact_sha256": _last_artifact_sha256,
		"authoritative": false,
		"grants": [],
	}


func _validate_list_response(body: PackedByteArray) -> Dictionary:
	var parsed_result := _parse_canonical(body, _max_response_bytes)
	if not bool(parsed_result.get("accepted", false)):
		return parsed_result
	var value: Variant = parsed_result.value
	if not value is Dictionary or not _has_exact_keys(value, LIST_KEYS) \
			or value.get("document_type") != "public_replay_list_v1" \
			or value.get("schema_version") != 1 \
			or not value.get("items") is Array \
			or value.get("authoritative") != false \
			or value.get("grants") != []:
		return _failure("list_response_invalid")
	var next_cursor: Variant = value.get("next_cursor")
	if next_cursor != null and (not next_cursor is String or not ServiceContractScript.safe_replay_id(next_cursor)):
		return _failure("list_response_invalid")
	var items: Array = value.get("items")
	if items.size() > _last_list_limit:
		return _failure("list_response_invalid")
	var previous_id := ""
	for record: Variant in items:
		if not _valid_record(record) or (not previous_id.is_empty() and str(record.replay_id) <= previous_id):
			return _failure("list_response_invalid")
		previous_id = str(record.replay_id)
	return {
		"accepted": true,
		"error_code": "",
		"items": items.duplicate(true),
		"next_cursor": next_cursor,
		"authoritative": false,
		"grants": [],
	}


func _valid_record(record: Variant) -> bool:
	if not record is Dictionary or not _has_exact_keys(record, RECORD_KEYS):
		return false
	if (
		record.get("document_type") != "public_replay_record_v1"
		or record.get("schema_version") != 1
		or not ServiceContractScript.safe_replay_id(str(record.get("replay_id", "")))
		or typeof(record.get("match_id")) != TYPE_STRING
		or str(record.get("match_id")).is_empty()
		or record.get("lane") != COMMUNITY_LANE
		or not _valid_sha256(record.get("artifact_sha256"))
		or typeof(record.get("artifact_bytes")) != TYPE_INT
		or int(record.get("artifact_bytes")) < 1
		or record.get("artifact_status") != "available"
		or not _valid_sha256(record.get("manifest_sha256"))
		or not _valid_sha256(record.get("match_envelope_sha256"))
		or typeof(record.get("frame_count")) != TYPE_INT
		or int(record.get("frame_count")) < 1
		or not _valid_sha256(record.get("frame_chain_root_sha256"))
		or record.get("visibility_profile") != "public_at_event_time_v1"
		or record.get("service_contract_sha256") != _service_contract_sha256
		or not _valid_strategy_release_refs(record.get("strategy_release_refs"))
		or typeof(record.get("created_at_utc")) != TYPE_STRING
		or typeof(record.get("expires_at_utc")) != TYPE_STRING
		or record.get("expired_at_utc") != null
		or record.get("retention_days") != _retention_days
		or record.get("metadata_policy") != "hash_and_summary_after_expiry"
		or record.get("authoritative") != false
		or record.get("grants") != []
	):
		return false
	return true


static func _valid_strategy_release_refs(value: Variant) -> bool:
	if not value is Array or value.size() > 2:
		return false
	for reference: Variant in value:
		if not reference is Dictionary or not _has_exact_keys(reference, [
			"seat", "strategy_id", "package_id", "release_version", "archive_sha256",
			"manifest_canonical_sha256",
		]):
			return false
		if (
			typeof(reference.get("seat")) != TYPE_INT
			or int(reference.get("seat")) < 0
			or int(reference.get("seat")) > 1
			or typeof(reference.get("strategy_id")) != TYPE_STRING
			or str(reference.get("strategy_id")).is_empty()
			or typeof(reference.get("package_id")) != TYPE_STRING
			or str(reference.get("package_id")).is_empty()
			or typeof(reference.get("release_version")) != TYPE_STRING
			or str(reference.get("release_version")).is_empty()
			or not _valid_sha256(reference.get("archive_sha256"))
			or not _valid_sha256(reference.get("manifest_canonical_sha256"))
		):
			return false
	return true


func _parse_canonical(body: PackedByteArray, maximum: int) -> Dictionary:
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		return _failure("read_response_invalid")
	var value: Variant = ServiceContractScript.coerce_integral_numbers(json.data)
	var canonical: Dictionary = CabtJsonTreeScript.canonicalize_artifact(
		value, {"max_output_bytes": maximum}
	)
	if not bool(canonical.get("ok", false)):
		return _failure("read_response_invalid")
	if canonical.get("bytes", PackedByteArray()) != body:
		return _failure("replay_response_noncanonical")
	return {"accepted": true, "error_code": "", "value": value}


func _error_code_from_body(body: PackedByteArray) -> String:
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK or not json.data is Dictionary:
		return "read_server_rejected"
	var value: Dictionary = json.data
	if value.get("authoritative") != false or value.get("grants") != []:
		return "read_server_rejected"
	var code: Variant = value.get("error_code")
	if typeof(code) == TYPE_STRING and code in [
		"replay_not_found", "replay_artifact_expired", "replay_id_invalid",
		"list_query_invalid", "list_limit_invalid", "list_cursor_invalid",
	]:
		return str(code)
	return "read_server_rejected"


func _finish(result: Dictionary) -> void:
	_last_result = result.duplicate(true)
	read_completed.emit(_last_result.duplicate(true))


static func _valid_sha256(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or str(value).length() != 64:
		return false
	for index: int in str(value).length():
		var code := str(value).unicode_at(index)
		if not ((code >= 48 and code <= 57) or (code >= 65 and code <= 70)):
			return false
	return true


static func _has_exact_keys(value: Dictionary, keys: Array) -> bool:
	if value.size() != keys.size():
		return false
	for key: Variant in keys:
		if not value.has(key):
			return false
	return true


static func _response_failure(code: String, retryable: bool, status: int) -> Dictionary:
	return {
		"accepted": false,
		"error_code": code,
		"http_status": status,
		"retryable": retryable,
		"authoritative": false,
		"grants": [],
	}


static func _failure(code: String) -> Dictionary:
	return {"accepted": false, "error_code": code, "authoritative": false, "grants": []}
