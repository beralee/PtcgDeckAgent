class_name TestAuthorLivePublicReplay
extends TestBase

const CoordinatorScript = preload(
	"res://scripts/ui/battle/author_strategy/AuthorStrategyPublicReplayCoordinator.gd"
)
const ContractScript = preload(
	"res://scripts/ai/ptcgdap/platform/CompetitiveStrategyContracts.gd"
)
const RemoteReaderScript = preload(
	"res://scripts/ai/ptcgdap/platform/replay/PublicReplayRemoteReader.gd"
)
const CaptureScript = preload(
	"res://scripts/ai/ptcgdap/platform/replay/PublicReplayCapture.gd"
)
const LiveEnvelopeScript = preload(
	"res://scripts/ai/ptcgdap/platform/replay/PublicReplayLiveEnvelope.gd"
)
const BattleSceneScript = preload("res://scenes/battle/BattleScene.gd")

const SHA_A := "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
const SHA_B := "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"
const SHA_C := "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"
const SHA_D := "DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD"


class FakeOwner extends RefCounted:
	var match_id := "windows-player-live-replay-fixture"
	var turn_number := 0
	var phase := "setup"
	var include_private_field := false

	func public_replay_identity() -> Dictionary:
		return {
			"ok": true,
			"error_code": "",
			"match_id": match_id,
			"source_authority": "ptcgdap_author_public_owner_v1",
			"strategy_participant": {
				"participant_kind": "strategy_release",
				"strategy_id": "ptcgdap.cynthia-garchomp.18.0.package-local-v1",
				"release_version": "0.1.0",
				"package_id": "ptcgdap.cynthia-garchomp-800018543.windows-local",
				"archive_sha256": SHA_A,
				"manifest_canonical_sha256": SHA_B,
				"deck_identity": {
					"domain": "godot_local_card_uid_v1",
					"deck_id": "800018543",
					"deck_sha256": SHA_C,
				},
				"policy_package_sha256": SHA_D,
			},
			"card_catalog_sha256": SHA_C,
		}

	func public_replay_source_snapshot() -> Dictionary:
		var public_state := {
			"zone_counts": [
				{"seat": 0, "hand_count": 6, "deck_count": 46, "prize_count": 6},
				{"seat": 1, "hand_count": 5, "deck_count": 45, "prize_count": 4},
			],
			"board": [],
			"public_cards": [],
		}
		if include_private_field:
			public_state["private_rng_state"] = "must-not-leak"
		return {
			"ok": true,
			"error_code": "",
			"source": {
				"source_authority": "ptcgdap_author_public_owner_v1",
				"match_id": match_id,
				"turn_number": turn_number,
				"phase": phase,
				"acting_seat": 1,
				"public_state": public_state,
			},
		}


func test_completed_author_match_is_saved_as_community_replay_without_upload_token() -> String:
	var storage_namespace := "author-live-%d" % Time.get_ticks_usec()
	var owner := FakeOwner.new()
	var coordinator: Node = CoordinatorScript.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(coordinator)
	var started: Dictionary = coordinator.start(owner, {
		"storage_namespace": storage_namespace,
		"base_url": "http://127.0.0.1:8765",
		"bearer_token": "",
		"allow_insecure_loopback": true,
	})
	if not bool(started.get("accepted", false)):
		tree.root.remove_child(coordinator)
		coordinator.free()
		return "live replay start failed: %s" % str(started)
	owner.turn_number = 1
	owner.phase = "main"
	var progressed: Dictionary = coordinator.record_progress(owner)
	owner.phase = "terminal"
	var finished: Dictionary = coordinator.finish(owner)
	var artifact: Dictionary = coordinator.completed_artifact()
	var audit: Dictionary = coordinator.audit_snapshot()
	var loaded_contract: Dictionary = ContractScript.load_default()
	var contract_owner: Variant = loaded_contract.get("owner")
	var replay_validation: Dictionary = contract_owner.validate_replay(
		artifact.get("manifest", {}), artifact.get("frames", [])
	) if contract_owner != null else {}
	var path := str(finished.get("artifact_path", ""))
	var raw := FileAccess.get_file_as_string(path) if path != "" else ""
	tree.root.remove_child(coordinator)
	coordinator.free()
	return run_checks([
		assert_true(bool(started.get("accepted", false)), str(started)),
		assert_true(bool(progressed.get("accepted", false)), str(progressed)),
		assert_true(bool(finished.get("accepted", false)), str(finished)),
		assert_true(FileAccess.file_exists(path), path),
		assert_true(bool(replay_validation.get("accepted", false)), str(replay_validation)),
		assert_eq(artifact.get("match_envelope", {}).get("lane"), "community_challenge"),
		assert_eq(
			artifact.get("match_envelope", {}).get("participants", [])[0].get("strategy_id"),
			"ptcgdap.cynthia-garchomp.18.0.package-local-v1"
		),
		assert_eq(artifact.get("frames", []).size(), 3),
		assert_eq(artifact.get("frames", [])[-1].get("event_kind"), "match_finished"),
		assert_eq(raw.find("private_rng_state"), -1),
		assert_eq(audit.get("upload_status"), "not_configured"),
		assert_true(bool(audit.get("local_saved", false))),
		assert_false(bool(audit.get("authoritative", true))),
		assert_eq(audit.get("engine_invocations"), 0),
		assert_eq(audit.get("grants"), []),
	])


func test_live_replay_binds_the_exact_heterogeneous_rule_opponent_identity() -> String:
	var storage_namespace := "author-live-marnie-rule-%d" % Time.get_ticks_usec()
	var owner := FakeOwner.new()
	owner.match_id = "ogerpon-vs-marnie-rule-live-replay"
	var coordinator: Node = CoordinatorScript.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(coordinator)
	var started: Dictionary = coordinator.start(owner, {
		"storage_namespace": storage_namespace,
		"opponent_deck_id": 800018501,
		"strategy_seat": 1,
		"bearer_token": "",
	})
	owner.turn_number = 1
	owner.phase = "terminal"
	var finished: Dictionary = coordinator.finish(owner) \
		if bool(started.get("accepted", false)) else {}
	var artifact: Dictionary = coordinator.completed_artifact()
	var envelope: Dictionary = artifact.get("match_envelope", {})
	var participants: Array = envelope.get("participants", [])
	var baseline: Dictionary = participants[1] if participants.size() == 2 else {}
	var captured_by_scope: bool = false
	if not envelope.is_empty():
		captured_by_scope = bool(CaptureScript.is_supported_envelope(envelope))
	tree.root.remove_child(coordinator)
	coordinator.free()
	return run_checks([
		assert_true(bool(started.get("accepted", false)), str(started)),
		assert_true(bool(finished.get("accepted", false)), str(finished)),
		assert_eq(baseline.get("participant_kind"), "platform_baseline"),
		assert_eq(baseline.get("baseline_id"), "rules-only-800018501"),
		assert_eq(baseline.get("baseline_version"), "1.0.0"),
		assert_true(_is_sha256(str(baseline.get("baseline_sha256", "")))),
		assert_eq(envelope.get("seat_assignment"), [1, 0]),
		assert_true(captured_by_scope),
		assert_false(JSON.stringify(artifact).contains("rules-only-575720")),
	])


func test_rule_baseline_builder_covers_all_five_matchups_and_fails_closed() -> String:
	var source_baseline := {
		"participant_kind": "platform_baseline",
		"baseline_id": "rules-only-575720",
		"baseline_version": "1.0.0",
		"baseline_sha256": SHA_A,
	}
	var ids := [800018501, 800017097, 800018499, 800018509, 800018502]
	var baseline_ids: Array[String] = []
	var baseline_hashes: Array[String] = []
	var checks: Array[String] = []
	for deck_id: int in ids:
		var built: Dictionary = LiveEnvelopeScript._build_rule_baseline_participant(
			deck_id, source_baseline
		)
		checks.append(assert_true(bool(built.get("accepted", false)), str(built)))
		var participant: Dictionary = built.get("participant", {})
		baseline_ids.append(str(participant.get("baseline_id", "")))
		baseline_hashes.append(str(participant.get("baseline_sha256", "")))
	checks.append(assert_eq(baseline_ids, [
		"rules-only-800018501", "rules-only-800017097", "rules-only-800018499",
		"rules-only-800018509", "rules-only-800018502",
	]))
	checks.append(assert_eq(_unique_count(baseline_hashes), 5))
	checks.append(assert_eq(
		LiveEnvelopeScript._build_rule_baseline_participant(999999999, source_baseline).get("error_code"),
		"rule_baseline_deck_unavailable"
	))
	return run_checks(checks)


func test_live_envelope_binds_two_exact_author_package_identities() -> String:
	var loaded: Dictionary = ContractScript.load_default()
	var contract_owner: Variant = loaded.get("owner")
	var candidate := FakeOwner.new()
	candidate.match_id = "author-vs-author-replay"
	var opponent := FakeOwner.new()
	opponent.match_id = candidate.match_id
	var opponent_identity := opponent.public_replay_identity()
	opponent_identity["strategy_participant"]["package_id"] = "dev.beralee.v18.ogerpon-crustle-v523a"
	opponent_identity["strategy_participant"]["release_version"] = "1.0.0"
	opponent_identity["strategy_participant"]["archive_sha256"] = SHA_B
	var built: Dictionary = LiveEnvelopeScript.build(
		contract_owner, candidate.public_replay_identity(), candidate.match_id,
		800052301, 0, opponent_identity
	)
	var participants: Array = built.get("envelope", {}).get("participants", [])
	return run_checks([
		assert_true(bool(built.get("accepted", false)), str(built)),
		assert_eq(participants.size(), 2),
		assert_eq(participants[0].get("package_id"), "ptcgdap.cynthia-garchomp-800018543.windows-local"),
		assert_eq(participants[1].get("package_id"), "dev.beralee.v18.ogerpon-crustle-v523a"),
		assert_eq(participants[1].get("archive_sha256"), SHA_B),
		assert_eq(built.get("envelope", {}).get("seat_assignment"), [0, 1]),
		assert_true(CaptureScript.is_supported_envelope(built.get("envelope", {}))),
	])


func test_private_source_fails_closed_before_local_save_or_upload() -> String:
	var owner := FakeOwner.new()
	owner.include_private_field = true
	var coordinator: Node = CoordinatorScript.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(coordinator)
	var started: Dictionary = coordinator.start(owner, {
		"storage_namespace": "author-private-%d" % Time.get_ticks_usec(),
		"bearer_token": "development-replay-upload-token-0001",
		"base_url": "http://127.0.0.1:8765",
		"allow_insecure_loopback": true,
	})
	var audit: Dictionary = coordinator.audit_snapshot()
	tree.root.remove_child(coordinator)
	coordinator.free()
	return run_checks([
		assert_eq(started.get("error_code"), "private_field_forbidden"),
		assert_false(bool(audit.get("local_saved", false))),
		assert_eq(audit.get("upload_attempt_count"), 0),
		assert_false(JSON.stringify(started).contains("must-not-leak")),
	])


func test_live_replay_real_http_round_trip_when_e2e_environment_is_configured() -> String:
	var base_url := OS.get_environment("PTCGDAP_REPLAY_E2E_BASE_URL").strip_edges()
	var bearer_token := OS.get_environment("PTCGDAP_REPLAY_E2E_TOKEN")
	if base_url.is_empty() or bearer_token.is_empty():
		return ""
	var owner := FakeOwner.new()
	owner.match_id = "windows-player-http-%d" % Time.get_ticks_usec()
	var coordinator: Node = CoordinatorScript.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(coordinator)
	var started: Dictionary = coordinator.start(owner, {
		"storage_namespace": "author-http-%d" % Time.get_ticks_usec(),
		"base_url": base_url,
		"bearer_token": bearer_token,
		"allow_insecure_loopback": true,
	})
	if not bool(started.get("accepted", false)):
		tree.root.remove_child(coordinator)
		coordinator.free()
		return "HTTP replay start failed: %s" % str(started)
	owner.turn_number = 1
	owner.phase = "main"
	coordinator.record_progress(owner)
	owner.phase = "terminal"
	var finished: Dictionary = coordinator.finish(owner)
	var deadline := Time.get_ticks_msec() + 10_000
	while (
		str(coordinator.audit_snapshot().get("upload_status", "")) in ["scheduled", "uploading"]
		and Time.get_ticks_msec() < deadline
	):
		await tree.process_frame
	var upload_audit: Dictionary = coordinator.audit_snapshot()
	var loaded: Dictionary = ContractScript.load_default()
	var contract_owner: Variant = loaded.get("owner")
	var reader_created: Dictionary = RemoteReaderScript.create(
		contract_owner, null, base_url, true
	)
	if not bool(reader_created.get("accepted", false)):
		tree.root.remove_child(coordinator)
		coordinator.free()
		return "HTTP reader creation failed: %s" % str(reader_created)
	var reader: Node = reader_created.get("reader")
	tree.root.add_child(reader)
	await tree.process_frame
	var read_results: Array[Dictionary] = []
	reader.read_completed.connect(func(result: Dictionary) -> void:
		read_results.append(result.duplicate(true))
	)
	var fetch_started: Dictionary = reader.fetch(str(started.get("replay_id", "")))
	deadline = Time.get_ticks_msec() + 10_000
	while read_results.is_empty() and Time.get_ticks_msec() < deadline:
		await tree.process_frame
	var fetched: Dictionary = read_results[0] if not read_results.is_empty() else {}
	var remote_artifact: Dictionary = fetched.get("artifact", {})
	tree.root.remove_child(reader)
	reader.free()
	tree.root.remove_child(coordinator)
	coordinator.free()
	return run_checks([
		assert_true(bool(finished.get("accepted", false)), str(finished)),
		assert_eq(upload_audit.get("upload_status"), "uploaded", str(upload_audit)),
		assert_true(bool(fetch_started.get("accepted", false)), str(fetch_started)),
		assert_true(bool(fetched.get("accepted", false)), str(fetched)),
		assert_eq(remote_artifact.get("match_envelope", {}).get("lane"), "community_challenge"),
		assert_eq(remote_artifact.get("manifest", {}).get("replay_id"), started.get("replay_id")),
		assert_false(JSON.stringify(upload_audit).contains(bearer_token)),
		assert_false(bool(upload_audit.get("authoritative", true))),
		assert_eq(upload_audit.get("engine_invocations"), 0),
	])


func test_match_end_status_distinguishes_local_only_uploading_and_uploaded() -> String:
	var scene := BattleSceneScript.new()
	scene.set("_author_public_replay_audit", {
		"local_saved": true,
		"upload_status": "not_configured",
	})
	var local_only := str(scene.call("_author_public_replay_status_text"))
	scene.set("_author_public_replay_audit", {
		"local_saved": true,
		"upload_status": "uploading",
	})
	var uploading := str(scene.call("_author_public_replay_status_text"))
	scene.set("_author_public_replay_audit", {
		"local_saved": true,
		"upload_status": "uploaded",
	})
	var uploaded := str(scene.call("_author_public_replay_status_text"))
	scene.free()
	return run_checks([
		assert_true(local_only.contains("已保存到本地")),
		assert_true(local_only.contains("未配置上传")),
		assert_true(uploading.contains("正在上传")),
		assert_true(uploaded.contains("已保存并上传")),
	])


static func _is_sha256(value: String) -> bool:
	if value.length() != 64 or value != value.to_upper():
		return false
	for character: String in value:
		if character not in "0123456789ABCDEF":
			return false
	return true


static func _unique_count(values: Array[String]) -> int:
	var seen := {}
	for value: String in values:
		seen[value] = true
	return seen.size()
