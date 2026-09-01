class_name TestPublicReplayRemoteReader
extends TestBase

const ReaderScript = preload("res://scripts/ai/ptcgdap/platform/replay/PublicReplayRemoteReader.gd")
const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")

const SHA_A := "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
const SHA_B := "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"


class FakeOwner extends RefCounted:
	func validate_document(value: Variant) -> Dictionary:
		if not value is Dictionary or value.get("match_id") != "remote-unit-match":
			return {"accepted": false, "error_code": "document_invalid"}
		return {"accepted": true, "canonical_sha256": SHA_A}

	func validate_replay(manifest: Variant, frames: Variant) -> Dictionary:
		if not manifest is Dictionary or not frames is Array or frames.size() != 1:
			return {"accepted": false, "error_code": "replay_invalid"}
		return {
			"accepted": true,
			"replay_id": manifest.get("replay_id"),
			"match_id": manifest.get("match_id"),
		}


class FakeTransport extends Node:
	signal request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray)

	var calls: Array[Dictionary] = []
	var next_error := OK

	func request(url: String, headers: PackedStringArray, method: int, body: String = "") -> Error:
		calls.append({"url": url, "headers": headers, "method": method, "body": body})
		return next_error as Error

	func complete(result: int, response_code: int, body: Variant) -> void:
		var canonical: Dictionary = CabtJsonTreeScript.canonicalize_artifact(body)
		var bytes: PackedByteArray = canonical.get("bytes", PackedByteArray()) if body != null \
				else PackedByteArray()
		request_completed.emit(result, response_code, PackedStringArray(), bytes)

	func complete_raw(result: int, response_code: int, body: PackedByteArray) -> void:
		request_completed.emit(result, response_code, PackedStringArray(), body)


func _artifact() -> Dictionary:
	return {
		"match_envelope": {
			"match_id": "remote-unit-match",
			"lane": "community_challenge",
		},
		"manifest": {
			"replay_id": "remote-unit-replay",
			"match_id": "remote-unit-match",
			"match_envelope_sha256": SHA_A,
		},
		"frames": [{"ordinal": 0}],
	}


func _record(replay_id: String = "remote-unit-replay") -> Dictionary:
	return {
		"document_type": "public_replay_record_v1",
		"schema_version": 1,
		"replay_id": replay_id,
		"match_id": "remote-unit-match",
		"lane": "community_challenge",
		"artifact_sha256": SHA_A,
		"artifact_bytes": 123,
		"artifact_status": "available",
		"manifest_sha256": SHA_B,
		"match_envelope_sha256": SHA_A,
		"frame_count": 1,
		"frame_chain_root_sha256": SHA_B,
		"visibility_profile": "public_at_event_time_v1",
		"service_contract_sha256": "9558738C24FFF4D9D4C80D7BFC0FFD68A1536666E0696BCFD1193CC18A2066C4",
		"strategy_release_refs": [],
		"created_at_utc": "2026-08-19T00:00:00Z",
		"expires_at_utc": "2026-11-17T00:00:00Z",
		"expired_at_utc": null,
		"retention_days": 90,
		"metadata_policy": "hash_and_summary_after_expiry",
		"authoritative": false,
		"grants": [],
	}


func _create_reader(transport: FakeTransport) -> Dictionary:
	return ReaderScript.create(FakeOwner.new(), transport, "http://127.0.0.1:8765", true)


func test_fetch_accepts_only_canonical_fully_revalidated_community_artifact() -> String:
	var transport := FakeTransport.new()
	var created := _create_reader(transport)
	if not bool(created.get("accepted", false)):
		transport.free()
		return "reader creation failed: %s" % created
	var reader: Node = created.reader
	var started: Dictionary = reader.fetch("remote-unit-replay")
	var body: PackedByteArray = CabtJsonTreeScript.canonicalize_artifact(_artifact()).bytes
	transport.complete_raw(HTTPRequest.RESULT_SUCCESS, 200, body)
	var result: Dictionary = reader.last_result()
	var audit: Dictionary = reader.audit_snapshot()
	var call: Dictionary = transport.calls[0] if transport.calls.size() == 1 else {}
	reader.free()
	transport.free()
	return run_checks([
		assert_true(bool(started.get("accepted", false))),
		assert_true(bool(result.get("accepted", false))),
		assert_eq(result.get("artifact", {}).get("manifest", {}).get("replay_id"), "remote-unit-replay"),
		assert_eq(call.get("url"), "http://127.0.0.1:8765/v1/public-replays/remote-unit-replay"),
		assert_eq(call.get("method"), HTTPClient.METHOD_GET),
		assert_eq(call.get("body"), ""),
		assert_false(bool(audit.get("authoritative", true))),
		assert_eq(audit.get("engine_invocations"), 0),
		assert_eq(audit.get("ticket_invocations"), 0),
	])


func test_fetch_rejects_wrong_lane_binding_noncanonical_and_oversized_responses() -> String:
	var transport := FakeTransport.new()
	var created := _create_reader(transport)
	if not bool(created.get("accepted", false)):
		transport.free()
		return "reader creation failed: %s" % created
	var reader: Node = created.reader
	reader.fetch("remote-unit-replay")
	var wrong_lane := _artifact()
	wrong_lane.match_envelope.lane = "developer_local"
	transport.complete_raw(HTTPRequest.RESULT_SUCCESS, 200, CabtJsonTreeScript.canonicalize_artifact(wrong_lane).bytes)
	var lane_result: Dictionary = reader.last_result()
	reader.fetch("remote-unit-replay")
	var wrong_id := _artifact()
	wrong_id.manifest.replay_id = "other-replay"
	transport.complete_raw(HTTPRequest.RESULT_SUCCESS, 200, CabtJsonTreeScript.canonicalize_artifact(wrong_id).bytes)
	var binding_result: Dictionary = reader.last_result()
	reader.fetch("remote-unit-replay")
	transport.complete_raw(HTTPRequest.RESULT_SUCCESS, 200, (" " + JSON.stringify(_artifact())).to_utf8_buffer())
	var canonical_result: Dictionary = reader.last_result()
	reader.fetch("remote-unit-replay")
	var oversized := PackedByteArray()
	oversized.resize(16 * 1024 * 1024 + 1)
	transport.complete_raw(HTTPRequest.RESULT_SUCCESS, 200, oversized)
	var size_result: Dictionary = reader.last_result()
	reader.free()
	transport.free()
	return run_checks([
		assert_eq(lane_result.get("error_code"), "replay_lane_read_forbidden"),
		assert_eq(binding_result.get("error_code"), "replay_response_binding_invalid"),
		assert_eq(canonical_result.get("error_code"), "replay_response_noncanonical"),
		assert_eq(size_result.get("error_code"), "replay_response_too_large"),
	])


func test_list_validates_non_authoritative_records_and_query_bounds() -> String:
	var transport := FakeTransport.new()
	var created := _create_reader(transport)
	if not bool(created.get("accepted", false)):
		transport.free()
		return "reader creation failed: %s" % created
	var reader: Node = created.reader
	var invalid_limit: Dictionary = reader.list(101)
	var started: Dictionary = reader.list(1, "remote-unit-replay")
	transport.complete(HTTPRequest.RESULT_SUCCESS, 200, {
		"document_type": "public_replay_list_v1",
		"schema_version": 1,
		"items": [_record()],
		"next_cursor": null,
		"authoritative": false,
		"grants": [],
	})
	var result: Dictionary = reader.last_result()
	var url := str(transport.calls[0].url) if transport.calls.size() == 1 else ""
	reader.list(1)
	var forged := _record()
	forged.authoritative = true
	transport.complete(HTTPRequest.RESULT_SUCCESS, 200, {
		"document_type": "public_replay_list_v1",
		"schema_version": 1,
		"items": [forged],
		"next_cursor": null,
		"authoritative": false,
		"grants": [],
	})
	var forged_result: Dictionary = reader.last_result()
	reader.free()
	transport.free()
	return run_checks([
		assert_eq(invalid_limit.get("error_code"), "list_limit_invalid"),
		assert_true(bool(started.get("accepted", false))),
		assert_true(bool(result.get("accepted", false))),
		assert_eq(result.get("items", []).size(), 1),
		assert_true(url.ends_with("?limit=1&cursor=remote-unit-replay")),
		assert_eq(forged_result.get("error_code"), "list_response_invalid"),
	])


func test_retry_repeats_same_get_only_after_retryable_failure() -> String:
	var transport := FakeTransport.new()
	var created := _create_reader(transport)
	if not bool(created.get("accepted", false)):
		transport.free()
		return "reader creation failed: %s" % created
	var reader: Node = created.reader
	reader.fetch("remote-unit-replay")
	transport.complete(HTTPRequest.RESULT_CANT_CONNECT, 0, {})
	var first: Dictionary = reader.last_result()
	var retried: Dictionary = reader.retry_last()
	var same_url: bool = transport.calls.size() == 2 \
			and str(transport.calls[0].url) == str(transport.calls[1].url)
	var call_count := transport.calls.size()
	reader.free()
	transport.free()
	return run_checks([
		assert_true(bool(first.get("retryable", false))),
		assert_true(bool(retried.get("accepted", false))),
		assert_true(same_url),
		assert_eq(call_count, 2),
	])
