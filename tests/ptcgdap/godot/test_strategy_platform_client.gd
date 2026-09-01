class_name TestStrategyPlatformClient
extends TestBase

const ClientScript = preload("res://scripts/ai/ptcgdap/platform/service/StrategyPlatformClient.gd")
const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")

const SHA_A := "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"


class FakeTransport extends Node:
	signal request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray)
	var calls: Array[Dictionary] = []
	var last_canonical: Dictionary = {}

	func request(url: String, headers: PackedStringArray, method: int, body: String = "") -> Error:
		calls.append({"url": url, "headers": headers, "method": method, "body": body})
		return OK

	func complete(value: Variant, status: int = 200) -> void:
		var canonical: Dictionary = CabtJsonTreeScript.canonicalize_artifact(value)
		last_canonical = canonical.duplicate(true)
		request_completed.emit(
			HTTPRequest.RESULT_SUCCESS,
			status,
			PackedStringArray(["Content-Type: application/json"]),
			canonical.get("bytes", PackedByteArray()),
		)

	func complete_bytes(
		body: PackedByteArray,
		status: int,
		headers: PackedStringArray
	) -> void:
		request_completed.emit(HTTPRequest.RESULT_SUCCESS, status, headers, body)


func _release() -> Dictionary:
	return {
		"document_type": "strategy_release_record_v1",
		"schema_version": 1,
		"release_id": "release-unit",
		"strategy_id": "strategy.unit",
		"package_id": "package.unit",
		"package_version": "1.0.0",
		"archive_sha256": SHA_A,
		"manifest_canonical_sha256": SHA_A,
		"release_state": "curated",
		"revocation_state": "active",
		"compatibility_state": "compatible",
		"challenge_available": true,
		"player_start_allowed": true,
		"authoritative": false,
		"grants": [],
	}


func _marketplace_release(archive_sha: String = SHA_A) -> Dictionary:
	var release := _release()
	release["archive_sha256"] = archive_sha
	release["author"] = {"author_id": "author.unit", "display_name": "Unit Author"}
	release["strategy_display_name"] = "Unit Strategy"
	release["strategy_summary"] = "Summary"
	release["deck_display_name"] = "Unit Deck"
	release["download_available"] = true
	release["published_at_utc"] = "2026-08-24T12:00:00Z"
	release["artifact_domain"] = "device_ptcgai"
	release["distribution"] = {
		"available": true,
		"reason": "",
		"href": "/v1/strategy-releases/release-unit/package",
		"media_type": "application/vnd.ptcgdap.strategy-package",
		"archive_bytes": 7,
		"etag": archive_sha,
	}
	return release


func test_catalog_and_stats_remain_separate_non_authoritative_lanes() -> String:
	var transport := FakeTransport.new()
	var created: Dictionary = ClientScript.create(transport, "http://127.0.0.1:8765", true)
	if not bool(created.get("accepted", false)):
		transport.free()
		return "client creation failed: %s" % created
	var client: Node = created.client
	client.list_strategies(10)
	transport.complete({
		"document_type": "strategy_catalog_v1",
		"schema_version": 1,
		"items": [{
			"strategy_id": "strategy.unit",
			"display_name": "Unit",
			"summary": "Summary",
			"author_display_name": "Author",
			"deck_display_name": "Deck",
			"featured_release": _release(),
		}],
		"next_cursor": null,
		"service_contract_sha256": "3C9910759750649CD446BD9491E1427AB42762EA348E77354A66E54F0959B9A0",
		"authoritative": false,
		"grants": [],
	})
	var catalog: Dictionary = client.last_result()
	client.fetch_statistics("release-unit")
	transport.complete({
		"document_type": "strategy_release_statistics_v1",
		"schema_version": 1,
		"release_id": "release-unit",
		"release_identity": {},
		"official": {"available": false, "status": "data_unavailable", "summary": null, "official": true},
		"shadow": {"available": true, "status": "shadow_test_only", "summary": {"counts": {"valid": 4}}, "official": false},
		"community": {"active_replay_count": 2, "enters_official_statistics": false},
		"authoritative": false,
		"grants": [],
	})
	var stats: Dictionary = client.last_result()
	var call_count := transport.calls.size()
	client.free()
	transport.free()
	return run_checks([
		assert_true(bool(catalog.get("accepted", false))),
		assert_eq(catalog.get("items", []).size(), 1),
		assert_true(bool(stats.get("accepted", false))),
		assert_false(bool(stats.get("statistics", {}).get("official", {}).get("available", true))),
		assert_eq(stats.get("statistics", {}).get("shadow", {}).get("status"), "shadow_test_only"),
		assert_eq(call_count, 2),
	])


func test_competition_profile_discovery_and_unbound_latest_are_strictly_read_only() -> String:
	var transport := FakeTransport.new()
	var client: Node = ClientScript.create(transport, "http://127.0.0.1:8876", true).client
	client.list_competition_profiles(100)
	transport.complete({
		"document_type": "competition_profile_list_v1",
		"schema_version": 1,
		"items": [{
			"profile_id": "profile.local",
			"display_name": "Local profile",
			"engine_family": "official_cabt",
			"engine_build_sha256": SHA_A,
			"observation_contract_sha256": SHA_A,
			"games_per_seat": 1,
			"episode_steps": 10000,
			"match_timeout_seconds": 600,
			"minimum_publish_games": 2,
			"score_formula": "kaggle_reward_mean_v1",
			"replay_policy": "all_public_projected",
			"state": "active",
			"created_at_utc": "2026-08-27T00:00:00Z",
			"updated_at_utc": "2026-08-27T00:00:00Z",
		}],
		"next_cursor": null,
		"platform_competition_authority": true,
		"player_runtime_authority": false,
		"kaggle_official_authority": false,
		"grants": [
			"developer_registry", "submission_registry", "match_orchestration",
			"platform_scoring", "public_replay_distribution",
		],
	})
	var profiles: Dictionary = client.last_result()
	client.list_marketplace_latest(10)
	transport.complete({
		"document_type": "strategy_marketplace_latest_v1",
		"schema_version": 1,
		"items": [{
			"competition_release_id": "competition.release.local",
			"competition_release_version": "1.0.0",
			"strategy_id": "strategy.local",
			"display_name": "Local strategy",
			"summary": "Server strategy",
			"author": {"author_id": "author.local", "display_name": "Local author"},
			"deck_display_name": "Local deck",
			"published_at_utc": "2026-08-27T00:00:00Z",
			"artifact_domain": "competition_ptcgbot",
			"installable_release": null,
			"download_available": false,
			"download_unavailable_reason": "device_release_binding_missing",
			"distribution_binding": null,
		}],
		"next_cursor": null,
		"order": "published_at_desc",
		"artifact_domain": "competition_ptcgbot",
		"download_artifact_domain": "device_ptcgai",
		"player_runtime_authority": false,
		"authoritative": false,
		"grants": [],
	})
	var latest: Dictionary = client.last_result()
	var urls: Array[String] = []
	for call: Dictionary in transport.calls:
		urls.append(str(call.get("url", "")))
	client.free()
	transport.free()
	return run_checks([
		assert_true(bool(profiles.get("accepted", false))),
		assert_eq(profiles.get("items", []).size(), 1),
		assert_true(bool(latest.get("accepted", false))),
		assert_eq(latest.get("items", []).size(), 1),
		assert_false(bool(latest.get("items", [])[0].get("download_available", true))),
		assert_eq(urls, [
			"http://127.0.0.1:8876/v1/competition-profiles?limit=100",
			"http://127.0.0.1:8876/v1/strategy-marketplace/strategies?limit=10",
		]),
	])


func test_continuous_ladder_gaussian_boards_are_strictly_validated() -> String:
	var transport := FakeTransport.new()
	var client: Node = ClientScript.create(
		transport, "http://127.0.0.1:8877", true
	).client
	if not client.has_method("list_continuous_ladder_leaderboard") \
			or not client.has_method("list_continuous_ladder_authors"):
		client.free()
		transport.free()
		return "continuous ladder client routes are missing"
	client.list_continuous_ladder_leaderboard()
	transport.complete({
		"document_type": "godot_v18_release_leaderboard_v1",
		"profile_id": "godot_v18_ladder_v1",
		"items": [{
			"profile_id": "godot_v18_ladder_v1",
			"release_id": "windows-trial-ogerpon-unit",
			"developer_id": "beralee.ogerpon",
			"owner_kind": "developer",
			"owner_id": "beralee.ogerpon",
			"competition_conflict_group": "developer:beralee.ogerpon",
			"release_source_kind": "developer_ptcgai",
			"runtime_kind": "godot_restricted_ptcgai_v1",
			"state": "active",
			"uploaded_at_epoch": 1787837481,
			"next_due_at_epoch": 1787838439,
			"last_series_at_epoch": 1787837919,
			"mu": "710.111902",
			"sigma": "166.971162",
			"rated_series_count": 1,
			"actual_game_count": 2,
			"provisional": true,
			"rank": 1,
			"display_name": "开发者·厄诡椪/岩殿居蟹 1.4.0",
			"author_display_name": "Beralee",
		}],
	})
	var releases: Dictionary = client.last_result()
	client.list_continuous_ladder_authors()
	transport.complete({
		"document_type": "godot_v18_author_leaderboard_v1",
		"profile_id": "godot_v18_ladder_v1",
		"items": [{
			"developer_id": "beralee.ogerpon",
			"release_id": "windows-trial-ogerpon-unit",
			"mu": "710.111902",
			"sigma": "166.971162",
			"provisional": true,
			"rank": 1,
			"author_display_name": "Beralee",
			"display_name": "开发者·厄诡椪/岩殿居蟹 1.4.0",
		}],
	})
	var authors: Dictionary = client.last_result()
	var urls: Array[String] = []
	for call: Dictionary in transport.calls:
		urls.append(str(call.get("url", "")))
	var release_items: Array = releases.get("items", [])
	var author_items: Array = authors.get("items", [])
	var last_canonical := transport.last_canonical.duplicate(true)
	client.free()
	transport.free()
	if not bool(releases.get("accepted", false)) or not bool(authors.get("accepted", false)):
		return "continuous ladder validation failed: releases=%s authors=%s canonical=%s" % [
			releases, authors, last_canonical
		]
	var checks := run_checks([
		assert_true(bool(releases.get("accepted", false))),
		assert_eq(releases.get("profile_id"), "godot_v18_ladder_v1"),
		assert_eq(release_items.size(), 1),
		assert_true(bool(authors.get("accepted", false))),
		assert_eq(author_items.size(), 1),
		assert_eq(urls, [
			"http://127.0.0.1:8877/v1/ladder/leaderboard",
			"http://127.0.0.1:8877/v1/ladder/authors",
		]),
	])
	if not release_items.is_empty():
		checks += run_checks([
			assert_eq(release_items[0].get("mu"), 710.111902),
			assert_eq(release_items[0].get("actual_game_count"), 2),
		])
	if not author_items.is_empty():
		checks += run_checks([
			assert_eq(author_items[0].get("developer_id"), "beralee.ogerpon"),
		])
	return checks


func test_continuous_ladder_profiles_and_package_download_are_strictly_validated() -> String:
	var transport := FakeTransport.new()
	var client: Node = ClientScript.create(
		transport, "http://127.0.0.1:8877", true
	).client
	for method_name: String in [
		"fetch_continuous_ladder_release_profile",
		"fetch_continuous_ladder_author_profile",
		"fetch_continuous_ladder_series_replay",
		"download_continuous_ladder_release",
	]:
		if not client.has_method(method_name):
			client.free()
			transport.free()
			return "continuous ladder profile method missing: %s" % method_name
	var package_bytes := "package".to_utf8_buffer()
	var package_sha: String = "BC4A71180870F7945155FBB02F4B0A2E3FAA2A62D6D31B7039013055ED19869A"
	var installable := {
		"release_id": "windows-trial-ogerpon-unit",
		"package_id": "dev.beralee.ogerpon",
		"package_version": "1.4.0",
		"archive_sha256": package_sha,
		"manifest_canonical_sha256": SHA_A,
		"archive_bytes": 7,
		"distribution": {
			"href": "/v1/ladder/releases/windows-trial-ogerpon-unit/package",
			"media_type": "application/vnd.ptcgdap.strategy-package",
			"etag": package_sha,
		},
	}
	var release := {
		"profile_id": "godot_v18_ladder_v1",
		"release_id": "windows-trial-ogerpon-unit",
		"developer_id": "beralee.ogerpon",
		"owner_kind": "developer",
		"owner_id": "beralee.ogerpon",
		"competition_conflict_group": "developer:beralee.ogerpon",
		"release_source_kind": "developer_ptcgai",
		"runtime_kind": "godot_restricted_ptcgai_v1",
		"state": "active",
		"uploaded_at_epoch": 1787837481,
		"next_due_at_epoch": 1787838439,
		"last_series_at_epoch": 1787837919,
		"mu": "710.111902", "sigma": "166.971162",
		"rated_series_count": 1, "actual_game_count": 2,
		"provisional": true, "rank": 1,
		"display_name": "开发者·厄诡椪/岩殿居蟹 1.4.0",
		"author_display_name": "Beralee",
		"summary": "阶段化支援者策略",
		"download_available": true,
		"installable_release": installable,
	}
	var performance := {
		"series": {"games": 1, "wins": 1, "losses": 0, "draws": 0, "win_rate_micros": 1000000},
		"individual_games": {"games": 2, "wins": 2, "losses": 0, "draws": 0, "win_rate_micros": 1000000},
	}
	var release_profile_payload := {
		"document_type": "godot_v18_release_profile_v1", "schema_version": 1,
		"profile_id": "godot_v18_ladder_v1", "release": release,
		"performance": performance,
		"rating_history": [{
			"event_id": "rating-event-unit", "sequence_no": 14,
			"series_id": "series-unit", "opponent_release_id": "builtin-v18-unit",
			"subject_outcome": "win", "prior_mu": "600.000000", "prior_sigma": "200.000000",
			"after_mu": "710.111902", "after_sigma": "166.971162", "created_at_epoch": 1787837919,
		}],
		"recent_matches": [{
			"series_id": "series-unit", "state": "rated", "completed_at_epoch": 1787837919,
			"opponent": {"release_id": "builtin-v18-unit", "display_name": "平台NPC·测试", "owner_kind": "platform_npc"},
			"subject_result": "win", "games": [
				{"job_id": "series-unit-seat-0", "seat_variant": 0, "subject_seat": 0, "subject_result": "win"},
				{"job_id": "series-unit-seat-1", "seat_variant": 1, "subject_seat": 1, "subject_result": "win"},
			], "wins": 2, "losses": 0, "draws": 0,
			"win_rate_micros": 1000000,
			"replay_available": true,
			"replay_path": "/v1/ladder/matches/series-unit/replay",
		}],
	}
	client.fetch_continuous_ladder_release_profile("windows-trial-ogerpon-unit")
	transport.complete(release_profile_payload)
	var profile_result: Dictionary = client.last_result()
	var mismatched_profile: Dictionary = release_profile_payload.duplicate(true)
	mismatched_profile["recent_matches"][0]["wins"] = 1
	client.fetch_continuous_ladder_release_profile("windows-trial-ogerpon-unit")
	transport.complete(mismatched_profile)
	var mismatched_profile_result: Dictionary = client.last_result()
	var wrong_replay_path_profile: Dictionary = release_profile_payload.duplicate(true)
	wrong_replay_path_profile["recent_matches"][0]["replay_path"] = (
		"/v1/ladder/matches/another-series/replay"
	)
	client.fetch_continuous_ladder_release_profile("windows-trial-ogerpon-unit")
	transport.complete(wrong_replay_path_profile)
	var wrong_replay_path_result: Dictionary = client.last_result()
	client.fetch_continuous_ladder_author_profile("beralee.ogerpon")
	transport.complete({
		"document_type": "godot_v18_author_profile_v1", "schema_version": 1,
		"profile_id": "godot_v18_ladder_v1",
		"author": {"developer_id": "beralee.ogerpon", "display_name": "Beralee", "rank": 1, "release_count": 1, "active_release_count": 1, "best_release_id": "windows-trial-ogerpon-unit", "mu": "710.111902", "sigma": "166.971162", "provisional": true},
		"releases": [{"release": release, "performance": performance}],
	})
	var author_result: Dictionary = client.last_result()
	client.fetch_continuous_ladder_series_replay("series-unit")
	transport.complete({
		"document_type": "godot_v18_public_series_replay_v1", "schema_version": 1,
		"profile_id": "godot_v18_ladder_v1", "series_id": "series-unit",
		"release_a_id": "windows-trial-ogerpon-unit", "release_b_id": "builtin-v18-unit",
		"created_at_epoch": 1787837800, "completed_at_epoch": 1787837919,
		"games": [
			{
				"job_id": "series-unit-seat-0", "seat_variant": 0,
				"seat0_release_id": "windows-trial-ogerpon-unit",
				"seat1_release_id": "builtin-v18-unit", "outcome": "seat0_win",
				"decision_counts": [1, 0],
				"public_replay": {
					"document_type": "godot_v18_public_replay_v1", "schema_version": 1,
					"complete": true,
					"frames": [{
						"seat": 0, "sequence": 1, "latency_usec": 123,
						"prompt_kind": "main", "selection_source": "author_package",
						"accepted_indexes": [0], "accepted_option_fingerprints": [SHA_A],
						"source": {"public_observation_hash": SHA_A, "window_id": "window-0"},
					}],
					"terminal": {"winner_index": 0, "steps": 1, "turn_number": 1, "win_reason": "prizes"},
				},
				"execution_proof": {"document_type": "godot_v18_execution_proof_v1"},
			},
			{
				"job_id": "series-unit-seat-1", "seat_variant": 1,
				"seat0_release_id": "builtin-v18-unit",
				"seat1_release_id": "windows-trial-ogerpon-unit", "outcome": "seat1_win",
				"decision_counts": [0, 1],
				"public_replay": {
					"document_type": "godot_v18_public_replay_v1", "schema_version": 1,
					"complete": true,
					"frames": [{
						"seat": 1, "sequence": 1, "latency_usec": 321,
						"prompt_kind": "attack", "selection_source": "author_package",
						"accepted_indexes": [1], "accepted_option_fingerprints": [SHA_A],
						"source": {"public_observation_hash": SHA_A, "window_id": "window-1"},
					}],
					"terminal": {"winner_index": 1, "steps": 1, "turn_number": 2, "win_reason": "knockout"},
				},
				"execution_proof": {"document_type": "godot_v18_execution_proof_v1"},
			},
		],
	})
	var replay_result: Dictionary = client.last_result()
	var forged_replay: Dictionary = replay_result.get("replay", {}).duplicate(true)
	forged_replay["private_state"] = {"opponent_hand": ["secret"]}
	client.fetch_continuous_ladder_series_replay("series-unit")
	transport.complete(forged_replay)
	var forged_replay_result: Dictionary = client.last_result()
	client.download_continuous_ladder_release(installable)
	transport.complete_bytes(
		package_bytes, 200,
		PackedStringArray([
			"Content-Type: application/vnd.ptcgdap.strategy-package",
			"Content-Length: 7", "ETag: \"%s\"" % package_sha,
		])
	)
	var download_result: Dictionary = client.last_result()
	var urls: Array[String] = []
	for call: Dictionary in transport.calls:
		urls.append(str(call.get("url", "")))
	if not bool(profile_result.get("accepted", false)) \
			or not bool(author_result.get("accepted", false)) \
			or not bool(replay_result.get("accepted", false)) \
			or not bool(download_result.get("accepted", false)):
		var diagnostic := "profile=%s author=%s replay=%s download=%s urls=%s" % [
			profile_result, author_result, replay_result, download_result, urls,
		]
		client.free()
		transport.free()
		return diagnostic
	client.free()
	transport.free()
	return run_checks([
		assert_true(bool(profile_result.get("accepted", false))),
		assert_eq(profile_result.get("profile", {}).get("performance", {}).get("series", {}).get("wins"), 1),
		assert_false(bool(mismatched_profile_result.get("accepted", false))),
		assert_eq(
			mismatched_profile_result.get("error_code"),
			"continuous_ladder_release_profile_invalid",
		),
		assert_eq(
			wrong_replay_path_result.get("error_code"),
			"continuous_ladder_release_profile_invalid",
		),
		assert_true(bool(author_result.get("accepted", false))),
		assert_eq(author_result.get("profile", {}).get("releases", []).size(), 1),
		assert_true(bool(replay_result.get("accepted", false))),
		assert_eq(replay_result.get("replay", {}).get("series_id"), "series-unit"),
		assert_eq(
			forged_replay_result.get("error_code"),
			"continuous_ladder_series_replay_invalid",
		),
		assert_true(bool(download_result.get("accepted", false))),
		assert_eq(download_result.get("package_bytes"), package_bytes),
		assert_eq(urls, [
			"http://127.0.0.1:8877/v1/ladder/releases/windows-trial-ogerpon-unit/profile",
			"http://127.0.0.1:8877/v1/ladder/releases/windows-trial-ogerpon-unit/profile",
			"http://127.0.0.1:8877/v1/ladder/releases/windows-trial-ogerpon-unit/profile",
			"http://127.0.0.1:8877/v1/ladder/authors/beralee.ogerpon/profile",
			"http://127.0.0.1:8877/v1/ladder/matches/series-unit/replay",
			"http://127.0.0.1:8877/v1/ladder/matches/series-unit/replay",
			"http://127.0.0.1:8877/v1/ladder/releases/windows-trial-ogerpon-unit/package",
		]),
	])


func test_challenge_request_is_canonical_intent_and_forged_authority_is_rejected() -> String:
	var transport := FakeTransport.new()
	var client: Node = ClientScript.create(transport, "http://127.0.0.1:8765", true).client
	var started: Dictionary = client.resolve_challenge("release-unit", "replay-unit")
	var call: Dictionary = transport.calls[0]
	transport.complete({
		"document_type": "exact_release_challenge_intent_v1",
		"schema_version": 1,
		"challenge_id": "challenge-unit",
		"replay_id": "replay-unit",
		"release_id": "release-unit",
		"release_identity": {},
		"start_mode": "development_built_in",
		"player_start_allowed": true,
		"local_selection": {},
		"package_path": "/v1/strategy-releases/release-unit/package",
		"runtime_authority": true,
		"authoritative": false,
		"grants": [],
	})
	var result: Dictionary = client.last_result()
	client.free()
	transport.free()
	return run_checks([
		assert_true(bool(started.get("accepted", false))),
		assert_eq(call.get("method"), HTTPClient.METHOD_POST),
		assert_eq(call.get("url"), "http://127.0.0.1:8765/v1/challenges/resolve"),
		assert_str_contains(str(call.get("body")), "\"release_id\":\"release-unit\""),
		assert_eq(result.get("error_code"), "challenge_response_invalid"),
	])


func test_marketplace_three_boards_and_author_works_validate_frozen_snapshot_contract() -> String:
	var transport := FakeTransport.new()
	var client: Node = ClientScript.create(transport, "http://127.0.0.1:8765", true).client
	client.list_marketplace_latest(10)
	transport.complete({
		"document_type": "strategy_marketplace_latest_v1",
		"schema_version": 1,
		"items": [{
			"strategy_id": "strategy.unit",
			"display_name": "Unit Strategy",
			"summary": "Summary",
			"author": {"author_id": "author.unit", "display_name": "Unit Author"},
			"deck_display_name": "Unit Deck",
			"published_at_utc": "2026-08-24T12:00:00Z",
			"installable_release": _marketplace_release(),
			"download_available": true,
			"artifact_domain": "device_ptcgai",
		}],
		"next_cursor": null,
		"order": "published_at_desc",
		"artifact_domain": "device_ptcgai",
		"player_runtime_authority": false,
		"authoritative": false,
		"grants": [],
	})
	var latest: Dictionary = client.last_result()
	client.list_marketplace_strategy_rankings("profile.unit", 10)
	transport.complete({
		"document_type": "strategy_marketplace_strategy_ranking_v1",
		"schema_version": 1,
		"profile_id": "profile.unit",
		"score_formula": "kaggle_mean_reward_v1",
		"minimum_publish_games": 10,
		"ranking_snapshot_id": "snapshot.unit",
		"snapshot_created_at_utc": "2026-08-24T12:00:00Z",
		"snapshot_consistent": true,
		"ranking_artifact_domain": "competition_ptcgbot",
		"download_artifact_domain": "device_ptcgai",
		"items": [{
			"rank": 1, "games": 12, "wins": 8, "losses": 3, "draws": 1,
			"kaggle_score_micros": 416667, "win_rate_micros": 666667,
			"points_rate_micros": 708333, "provisional": false,
			"competition_release_id": "competition.release.unit",
			"strategy_id": "strategy.unit", "author_id": "author.competition",
			"display_name": "Unit Strategy", "author_display_name": "Unit Author",
			"artifact_domain": "device_ptcgai",
			"installable_release": _marketplace_release(),
			"download_available": true, "download_unavailable_reason": "",
			"distribution_binding": {
				"binding_state": "verified",
				"association_kind": "exact_behavior_conformant",
				"conformance_evidence_sha256": SHA_A,
				"rank_transfer_allowed": true,
				"competition_release_id": "competition.release.unit",
				"device_release_id": "release-unit",
			},
		}],
		"next_cursor": null,
		"player_runtime_authority": false,
		"authoritative": false,
		"grants": [],
	})
	var ranking: Dictionary = client.last_result()
	client.list_marketplace_author_rankings("profile.unit", 10)
	transport.complete({
		"document_type": "strategy_marketplace_author_ranking_v1",
		"schema_version": 1,
		"profile_id": "profile.unit",
		"score_formula": "kaggle_mean_reward_v1",
		"minimum_publish_games": 10,
		"ranking_snapshot_id": "snapshot.unit",
		"snapshot_created_at_utc": "2026-08-24T12:00:00Z",
		"snapshot_consistent": true,
		"ranking_artifact_domain": "competition_ptcgbot",
		"download_artifact_domain": "device_ptcgai",
		"contribution_formula_id": "competition_performance_mean_v1",
		"contribution_explanation": "Mean competition reward.",
		"items": [{
			"rank": 1, "games": 12, "wins": 8, "losses": 3, "draws": 1,
			"kaggle_score_micros": 416667, "win_rate_micros": 666667,
			"points_rate_micros": 708333, "provisional": false,
			"author_id": "author.competition", "author_display_name": "Unit Author",
			"published_strategy_count": 1, "works_available": true,
			"contribution_formula_id": "competition_performance_mean_v1",
		}],
		"next_cursor": null,
		"player_runtime_authority": false,
		"authoritative": false,
		"grants": [],
	})
	var authors: Dictionary = client.last_result()
	client.list_marketplace_author_strategies("author.competition", 10)
	transport.complete({
		"document_type": "strategy_marketplace_author_strategies_v1",
		"schema_version": 1,
		"author": {"author_id": "author.competition", "display_name": "Unit Author", "device_author_id": "author.unit"},
		"items": [{
			"strategy_id": "strategy.unit", "display_name": "Unit Strategy",
			"summary": "Summary", "author": {"author_id": "author.unit", "display_name": "Unit Author"},
			"deck_display_name": "Unit Deck", "published_at_utc": "2026-08-24T12:00:00Z",
			"installable_release": _marketplace_release(), "download_available": true,
			"artifact_domain": "device_ptcgai",
		}],
		"next_cursor": null, "order": "published_at_desc", "artifact_domain": "device_ptcgai",
		"player_runtime_authority": false, "authoritative": false, "grants": [],
	})
	var works: Dictionary = client.last_result()
	var urls: Array[String] = []
	for call: Dictionary in transport.calls:
		urls.append(str(call.get("url", "")))
	client.free()
	transport.free()
	return run_checks([
		assert_true(bool(latest.get("accepted", false))),
		assert_true(bool(ranking.get("accepted", false))),
		assert_eq(ranking.get("ranking_snapshot_id"), "snapshot.unit"),
		assert_eq(ranking.get("ranking_artifact_domain"), "competition_ptcgbot"),
		assert_eq(ranking.get("download_artifact_domain"), "device_ptcgai"),
		assert_true(bool(authors.get("accepted", false))),
		assert_eq(authors.get("contribution_formula_id"), "competition_performance_mean_v1"),
		assert_true(bool(works.get("accepted", false))),
		assert_eq(urls, [
			"http://127.0.0.1:8765/v1/strategy-marketplace/strategies?limit=10",
			"http://127.0.0.1:8765/v1/strategy-marketplace/rankings?profile_id=profile.unit&limit=10",
			"http://127.0.0.1:8765/v1/strategy-marketplace/authors?profile_id=profile.unit&limit=10",
			"http://127.0.0.1:8765/v1/strategy-marketplace/authors/author.competition/strategies?limit=10",
		]),
	])


func test_strategy_archive_and_author_top_five_validate_subject_results_and_routes() -> String:
	var transport := FakeTransport.new()
	var client: Node = ClientScript.create(
		transport, "http://127.0.0.1:8876", true
	).client
	var competition_item := {
		"competition_release_id": "competition.release.unit",
		"competition_release_version": "1.0.0",
		"strategy_id": "strategy.unit",
		"display_name": "Unit Strategy",
		"summary": "Summary",
		"author": {"author_id": "author.unit", "display_name": "Unit Author"},
		"deck_display_name": "Unit Deck",
		"published_at_utc": "2026-08-24T12:00:00Z",
		"artifact_domain": "competition_ptcgbot",
		"installable_release": null,
		"download_available": false,
		"download_unavailable_reason": "device_release_binding_missing",
		"distribution_binding": null,
	}
	client.fetch_marketplace_strategy_archive(
		"profile.unit", "competition.release.unit", 20
	)
	transport.complete({
		"document_type": "strategy_marketplace_strategy_archive_v1",
		"schema_version": 1,
		"profile_id": "profile.unit",
		"strategy": competition_item,
		"recent_matches": [{
			"match_id": "match.unit.latest",
			"completed_at_utc": "2026-08-24T12:00:01Z",
			"subject_seat": 1,
			"subject_result": "win",
			"subject_reward": 1,
			"result_outcome": "seat1_win",
			"clean": true,
			"participants": [
				{
					"seat": 0, "release_id": "competition.release.other",
					"strategy_id": "strategy.other", "author_id": "author.other",
					"display_name": "Other", "deck_display_name": "Other Deck",
				},
				{
					"seat": 1, "release_id": "competition.release.unit",
					"strategy_id": "strategy.unit", "author_id": "author.unit",
					"display_name": "Unit Strategy", "deck_display_name": "Unit Deck",
				},
			],
			"replay_available": true,
			"replay_path": "/v1/competition-matches/match.unit.latest/replay",
		}],
		"recent_match_limit": 20,
		"order": "completed_at_desc_match_id_desc",
		"ranking_artifact_domain": "competition_ptcgbot",
		"download_artifact_domain": "device_ptcgai",
		"player_runtime_authority": false,
		"authoritative": false,
		"grants": [],
	})
	var archive: Dictionary = client.last_result()
	client.list_marketplace_author_top_strategies("profile.unit", "author.unit", 5)
	transport.complete({
		"document_type": "strategy_marketplace_author_top_strategies_v1",
		"schema_version": 1,
		"profile_id": "profile.unit",
		"author": {"author_id": "author.unit", "display_name": "Unit Author"},
		"score_formula": "kaggle_mean_reward_v1",
		"minimum_publish_games": 10,
		"ranking_snapshot_id": "snapshot.unit",
		"snapshot_created_at_utc": "2026-08-24T12:00:00Z",
		"snapshot_consistent": true,
		"order": "score_desc_global_rank_asc",
		"ranking_artifact_domain": "competition_ptcgbot",
		"download_artifact_domain": "device_ptcgai",
		"items": [{
			"author_strategy_rank": 1,
			"rank": 2, "games": 12, "wins": 8, "losses": 3, "draws": 1,
			"kaggle_score_micros": 416667, "win_rate_micros": 666667,
			"points_rate_micros": 708333, "provisional": false,
			"competition_release_id": "competition.release.unit",
			"strategy_id": "strategy.unit", "author_id": "author.unit",
			"display_name": "Unit Strategy", "author_display_name": "Unit Author",
			"artifact_domain": "device_ptcgai", "installable_release": null,
			"download_available": false,
			"download_unavailable_reason": "device_release_binding_missing",
			"distribution_binding": null,
		}],
		"maximum_items": 5,
		"player_runtime_authority": false,
		"authoritative": false,
		"grants": [],
	})
	var top: Dictionary = client.last_result()
	var urls: Array[String] = []
	for call: Dictionary in transport.calls:
		urls.append(str(call.get("url", "")))
	client.free()
	transport.free()
	return run_checks([
		assert_true(bool(archive.get("accepted", false))),
		assert_eq(archive.get("recent_matches", [])[0].get("subject_result"), "win"),
		assert_true(bool(top.get("accepted", false))),
		assert_eq(top.get("items", [])[0].get("author_strategy_rank"), 1),
		assert_eq(urls, [
			"http://127.0.0.1:8876/v1/strategy-marketplace/strategies/competition.release.unit?profile_id=profile.unit&match_limit=20",
			"http://127.0.0.1:8876/v1/strategy-marketplace/authors/author.unit/top-strategies?profile_id=profile.unit&limit=5",
		]),
	])


func test_marketplace_package_download_rejects_wrong_mime_and_accepts_exact_hash() -> String:
	var body := "package".to_utf8_buffer()
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(body)
	var archive_sha := context.finish().hex_encode().to_upper()
	var release := _marketplace_release(archive_sha)
	var wrong_transport := FakeTransport.new()
	var wrong_client: Node = ClientScript.create(wrong_transport, "http://127.0.0.1:8765", true).client
	wrong_client.download_marketplace_release(release)
	wrong_transport.complete_bytes(body, 200, PackedStringArray([
		"Content-Type: application/octet-stream", "ETag: \"%s\"" % archive_sha,
		"Content-Length: %d" % body.size(),
	]))
	var rejected: Dictionary = wrong_client.last_result()
	wrong_client.free()
	wrong_transport.free()
	var weak_transport := FakeTransport.new()
	var weak_client: Node = ClientScript.create(
		weak_transport, "http://127.0.0.1:8765", true
	).client
	weak_client.download_marketplace_release(release)
	weak_transport.complete_bytes(body, 200, PackedStringArray([
		"Content-Type: application/vnd.ptcgdap.strategy-package",
		"ETag: W/\"%s\"" % archive_sha, "Content-Length: %d" % body.size(),
	]))
	var weak_rejected: Dictionary = weak_client.last_result()
	weak_client.free()
	weak_transport.free()
	var transport := FakeTransport.new()
	var client: Node = ClientScript.create(transport, "http://127.0.0.1:8765", true).client
	client.download_marketplace_release(release)
	transport.complete_bytes(body, 200, PackedStringArray([
		"Content-Type: application/vnd.ptcgdap.strategy-package",
		"ETag: \"%s\"" % archive_sha, "Content-Length: %d" % body.size(),
	]))
	var accepted: Dictionary = client.last_result()
	client.free()
	transport.free()
	return run_checks([
		assert_eq(rejected.get("error_code"), "marketplace_package_content_type_invalid"),
		assert_eq(weak_rejected.get("error_code"), "marketplace_package_etag_invalid"),
		assert_true(bool(accepted.get("accepted", false))),
		assert_eq(accepted.get("package_bytes"), body),
		assert_eq(accepted.get("expected_release", {}).get("archive_sha256"), archive_sha),
	])
