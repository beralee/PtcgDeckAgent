class_name TestPublicReplayUploadClient
extends TestBase

const ContractScript = preload("res://scripts/ai/ptcgdap/platform/CompetitiveStrategyContracts.gd")
const UploadClientScript = preload("res://scripts/ai/ptcgdap/platform/replay/PublicReplayUploadClient.gd")

const SHA_A := "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
const SHA_B := "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"
const SHA_C := "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"
const SHA_D := "DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD"
const TOKEN := "development-replay-upload-token-0001"


class FakeTransport extends Node:
	signal request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray)

	var calls: Array[Dictionary] = []
	var next_error := OK

	func request(url: String, headers: PackedStringArray, method: int, body: String) -> Error:
		calls.append({"url": url, "headers": headers, "method": method, "body": body})
		return next_error as Error

	func complete(result: int, response_code: int, body: Dictionary) -> void:
		request_completed.emit(
			result,
			response_code,
			PackedStringArray(),
			JSON.stringify(body).to_utf8_buffer()
		)


func _owner() -> Variant:
	var loaded: Dictionary = ContractScript.load_default()
	return loaded.get("owner") if bool(loaded.get("accepted", false)) else null


func _developer_envelope(match_id: String) -> Dictionary:
	return {
		"document_type": "match_envelope_v1",
		"schema_version": 1,
		"match_id": match_id,
		"lane": "developer_local",
		"evaluator_id": "ptcgdap-csp-wp1-local-capture",
		"participants": [
			{
				"participant_kind": "strategy_release",
				"strategy_id": "ptcgdap.marnie.18.0.package-local-v1",
				"release_version": "0.1.0",
				"package_id": "ptcgdap.marnie.windows-local",
				"archive_sha256": "32E25453431886F76CEC606089ED4815EC681FBD33073F53A335A769D293643E",
				"manifest_canonical_sha256": SHA_A,
				"deck_identity": {"domain": "godot_local_card_uid_v1", "deck_id": "800018501", "deck_sha256": SHA_B},
				"policy_package_sha256": SHA_C,
			},
			{
				"participant_kind": "platform_baseline",
				"baseline_id": "rules-only-575720",
				"baseline_version": "1.0.0",
				"baseline_sha256": SHA_D,
			},
		],
		"engine_sha256": SHA_A,
		"rules_sha256": SHA_B,
		"card_catalog_sha256": SHA_C,
		"host_contract_sha256": SHA_D,
		"runtime_manifest_sha256": SHA_A,
		"evaluation_profile_id": "csp-wp1-marnie-development-v1",
		"evaluation_profile_sha256": SHA_B,
		"seat_assignment": [1, 0],
		"seed_commitment": {"capability": "deterministic_seed_v1", "commitment_sha256": SHA_C, "disclosure": "withheld"},
		"replay_visibility_profile": "public_at_event_time_v1",
		"started_at_utc": "2026-08-19T00:00:00Z",
	}


func _source(match_id: String, turn: int, phase: String) -> Dictionary:
	return {
		"source_authority": "ptcgdap_author_public_owner_v1",
		"match_id": match_id,
		"turn_number": turn,
		"phase": phase,
		"acting_seat": 1,
		"public_state": {
			"zone_counts": [
				{"seat": 0, "hand_count": 7, "deck_count": 47, "prize_count": 6},
				{"seat": 1, "hand_count": 7, "deck_count": 47, "prize_count": 6},
			],
			"board": [],
			"public_cards": [],
		},
	}


func _community_artifact() -> Dictionary:
	var owner: Variant = _owner()
	var match_id := "csp-wp3a-upload-unit"
	var envelope := _developer_envelope(match_id)
	envelope.lane = "community_challenge"
	var envelope_validation: Dictionary = owner.validate_document(envelope)
	if not bool(envelope_validation.get("accepted", false)):
		return {"fixture_error": envelope_validation}
	var first := {
		"document_type": "replay_frame_v1",
		"schema_version": 1,
		"match_id": match_id,
		"ordinal": 0,
		"turn_number": 0,
		"phase": "setup",
		"acting_seat": 1,
		"event_kind": "match_started",
		"public_state": _source(match_id, 0, "setup").public_state,
		"decision_trace_sha256": null,
		"previous_frame_sha256": null,
	}
	var second := {
		"document_type": "replay_frame_v1",
		"schema_version": 1,
		"match_id": match_id,
		"ordinal": 1,
		"turn_number": 0,
		"phase": "terminal",
		"acting_seat": 1,
		"event_kind": "match_finished",
		"public_state": _source(match_id, 0, "terminal").public_state,
		"decision_trace_sha256": null,
		"previous_frame_sha256": ContractScript.frame_hash(first),
	}
	var frames := [first, second]
	var manifest := {
		"document_type": "replay_manifest_v1",
		"schema_version": 1,
		"replay_id": "community-upload-unit",
		"match_id": match_id,
		"match_envelope_sha256": envelope_validation.canonical_sha256,
		"visibility_profile": "public_at_event_time_v1",
		"frame_count": 2,
		"first_frame_sha256": ContractScript.frame_hash(first),
		"frame_chain_root_sha256": ContractScript.frame_hash(second),
		"card_asset_catalog_sha256": SHA_B,
		"event_dictionary_sha256": SHA_C,
		"complete": true,
	}
	return {"match_envelope": envelope, "manifest": manifest, "frames": frames}


func _create_client(transport: FakeTransport) -> Dictionary:
	return UploadClientScript.create(
		_owner(), transport, "http://127.0.0.1:8765", TOKEN, true
	)


func test_valid_community_artifact_starts_exact_authenticated_request_without_authority() -> String:
	var transport := FakeTransport.new()
	var created := _create_client(transport)
	if not bool(created.get("accepted", false)):
		return "client creation failed: %s" % created
	var client: Node = created.client
	var artifact := _community_artifact()
	if artifact.has("fixture_error"):
		client.free()
		transport.free()
		return "community fixture failed: %s" % artifact.fixture_error
	var started: Dictionary = client.upload(artifact)
	var audit: Dictionary = client.audit_snapshot()
	var call: Dictionary = transport.calls[0] if transport.calls.size() == 1 else {}
	var call_count := transport.calls.size()
	client.free()
	transport.free()
	return run_checks([
		assert_true(bool(started.get("accepted", false))),
		assert_eq(call_count, 1),
		assert_eq(call.get("url"), "http://127.0.0.1:8765/v1/public-replays"),
		assert_eq(call.get("method"), HTTPClient.METHOD_POST),
		assert_true(call.get("headers", PackedStringArray()).has("Authorization: Bearer %s" % TOKEN)),
		assert_true(str(call.get("body", "")).contains("community_challenge")),
		assert_false(JSON.stringify(audit).contains(TOKEN)),
		assert_eq(
			audit.get("service_contract_sha256"),
			"9558738C24FFF4D9D4C80D7BFC0FFD68A1536666E0696BCFD1193CC18A2066C4"
		),
		assert_false(bool(audit.get("authoritative", true))),
		assert_eq(audit.get("engine_invocations"), 0),
		assert_eq(audit.get("ticket_invocations"), 0),
	])


func test_developer_private_and_busy_requests_fail_before_second_network_call() -> String:
	var transport := FakeTransport.new()
	var client: Node = _create_client(transport).client
	var developer := _community_artifact()
	developer.match_envelope.lane = "developer_local"
	var developer_result: Dictionary = client.upload(developer)
	var private := _community_artifact()
	private.frames[0]["search_begin_input"] = "PRIVATE_SENTINEL"
	var private_result: Dictionary = client.upload(private)
	var started: Dictionary = client.upload(_community_artifact())
	var busy: Dictionary = client.upload(_community_artifact())
	var call_count := transport.calls.size()
	client.free()
	transport.free()
	return run_checks([
		assert_eq(developer_result.get("error_code"), "replay_lane_upload_forbidden"),
		assert_eq(private_result.get("error_code"), "private_field_forbidden"),
		assert_true(bool(started.get("accepted", false))),
		assert_eq(busy.get("error_code"), "upload_busy"),
		assert_eq(call_count, 1),
	])


func test_retry_resends_identical_bytes_only_after_retryable_failure() -> String:
	var transport := FakeTransport.new()
	var client: Node = _create_client(transport).client
	var started: Dictionary = client.upload(_community_artifact())
	var first_body := str(transport.calls[0].body)
	transport.complete(HTTPRequest.RESULT_CANT_CONNECT, 0, {})
	var first_result: Dictionary = client.last_result()
	var retried: Dictionary = client.retry_last()
	var second_body := str(transport.calls[1].body) if transport.calls.size() == 2 else ""
	var call_count := transport.calls.size()
	client.free()
	transport.free()
	return run_checks([
		assert_true(bool(started.get("accepted", false))),
		assert_true(bool(first_result.get("retryable", false))),
		assert_true(bool(retried.get("accepted", false))),
		assert_eq(first_body, second_body),
		assert_eq(call_count, 2),
	])


func test_success_response_must_bind_exact_replay_and_artifact_hash() -> String:
	var transport := FakeTransport.new()
	var client: Node = _create_client(transport).client
	var started: Dictionary = client.upload(_community_artifact())
	transport.complete(HTTPRequest.RESULT_SUCCESS, 201, {
		"created": true,
		"record": {
			"replay_id": started.get("replay_id"),
			"artifact_sha256": started.get("artifact_sha256"),
			"service_contract_sha256": "9558738C24FFF4D9D4C80D7BFC0FFD68A1536666E0696BCFD1193CC18A2066C4",
			"authoritative": false,
			"grants": [],
		},
	})
	var success: Dictionary = client.last_result()
	var again: Dictionary = client.upload(_community_artifact())
	transport.complete(HTTPRequest.RESULT_SUCCESS, 201, {
		"created": true,
		"record": {
			"replay_id": again.get("replay_id"),
			"artifact_sha256": SHA_A,
			"service_contract_sha256": "9558738C24FFF4D9D4C80D7BFC0FFD68A1536666E0696BCFD1193CC18A2066C4",
			"authoritative": false,
			"grants": [],
		},
	})
	var mismatch: Dictionary = client.last_result()
	client.free()
	transport.free()
	return run_checks([
		assert_true(bool(success.get("accepted", false))),
		assert_false(bool(success.get("authoritative", true))),
		assert_eq(success.get("grants"), []),
		assert_eq(mismatch.get("error_code"), "upload_response_binding_invalid"),
		assert_false(bool(mismatch.get("retryable", true))),
	])


func test_endpoint_and_temporary_token_configuration_fail_closed() -> String:
	var transport := FakeTransport.new()
	var http_public: Dictionary = UploadClientScript.create(_owner(), transport, "http://example.com", TOKEN, true)
	var short_token: Dictionary = UploadClientScript.create(_owner(), transport, "https://replay.example.com", "short", false)
	var injected_token: Dictionary = UploadClientScript.create(
		_owner(), transport, "https://replay.example.com", TOKEN + "\nInjected: true", false
	)
	var invalid_port: Dictionary = UploadClientScript.create(
		_owner(), transport, "https://replay.example.com:not-a-port", TOKEN, false
	)
	var https_ok: Dictionary = UploadClientScript.create(_owner(), transport, "https://replay.example.com", TOKEN, false)
	if bool(https_ok.get("accepted", false)):
		(https_ok.client as Node).free()
	transport.free()
	return run_checks([
		assert_eq(http_public.get("error_code"), "upload_endpoint_insecure"),
		assert_eq(short_token.get("error_code"), "upload_token_invalid"),
		assert_eq(injected_token.get("error_code"), "upload_token_invalid"),
		assert_eq(invalid_port.get("error_code"), "upload_endpoint_invalid"),
		assert_true(bool(https_ok.get("accepted", false))),
	])
