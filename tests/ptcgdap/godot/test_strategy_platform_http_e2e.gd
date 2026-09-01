class_name TestStrategyPlatformHttpE2E
extends TestBase

const ClientScript = preload("res://scripts/ai/ptcgdap/platform/service/StrategyPlatformClient.gd")
const BinderScript = preload("res://scripts/ai/ptcgdap/platform/service/ExactReleaseChallengeBinder.gd")
const ContractsScript = preload("res://scripts/ai/ptcgdap/platform/CompetitiveStrategyContracts.gd")
const ReaderScript = preload("res://scripts/ai/ptcgdap/platform/replay/PublicReplayRemoteReader.gd")
const PresentationScript = preload("res://scripts/ai/ptcgdap/platform/replay/PublicReplayPresentation.gd")


func test_live_platform_catalog_stats_replay_challenge_and_event_round_trip() -> String:
	var arguments := _arguments()
	var endpoint := str(arguments.get("platform-e2e-endpoint", ""))
	var release_id := str(arguments.get("platform-e2e-release", ""))
	var replay_id := str(arguments.get("platform-e2e-replay", ""))
	var token := str(arguments.get("platform-e2e-token", ""))
	var profile_id := str(arguments.get("platform-e2e-profile", ""))
	if endpoint.is_empty() and release_id.is_empty() and replay_id.is_empty() \
			and token.is_empty() and profile_id.is_empty():
		return ""
	if endpoint.is_empty() or release_id.is_empty() or replay_id.is_empty() \
			or token.is_empty() or profile_id.is_empty():
		return "missing strategy platform E2E arguments"
	var created: Dictionary = ClientScript.create(null, endpoint, true)
	if not bool(created.get("accepted", false)):
		return "client creation failed: %s" % created
	var client: Node = created.client
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(client)
	await tree.process_frame
	var results: Array[Dictionary] = []
	client.request_completed.connect(func(result: Dictionary) -> void:
		results.append(result.duplicate(true))
	)

	var catalog: Dictionary = await _request_and_wait(
		client, results, func() -> Dictionary: return client.list_strategies(24), tree
	)
	if not bool(catalog.get("accepted", false)):
		return _cleanup_failure(client, "catalog failed: %s" % catalog)
	var items: Array = catalog.get("items", [])
	if items.is_empty():
		return _cleanup_failure(client, "catalog empty")
	var strategy_id := ""
	for catalog_item: Variant in items:
		if catalog_item is Dictionary and str(catalog_item.get("featured_release", {}).get("release_id", "")) == release_id:
			strategy_id = str(catalog_item.get("strategy_id", ""))
			break
	if strategy_id.is_empty():
		return _cleanup_failure(client, "catalog did not contain requested exact release")
	var detail: Dictionary = await _request_and_wait(
		client, results, func() -> Dictionary: return client.fetch_strategy(strategy_id), tree
	)
	if not bool(detail.get("accepted", false)):
		return _cleanup_failure(client, "detail failed: %s" % detail)
	var stats: Dictionary = await _request_and_wait(
		client, results, func() -> Dictionary: return client.fetch_statistics(release_id), tree
	)
	if not bool(stats.get("accepted", false)):
		return _cleanup_failure(client, "stats failed: %s" % stats)
	var marketplace_latest: Dictionary = await _request_and_wait(
		client, results, func() -> Dictionary: return client.list_marketplace_latest(24), tree
	)
	if not bool(marketplace_latest.get("accepted", false)):
		return _cleanup_failure(client, "marketplace latest failed: %s" % marketplace_latest)
	var marketplace_ranking: Dictionary = await _request_and_wait(
		client, results,
		func() -> Dictionary: return client.list_marketplace_strategy_rankings(profile_id, 24),
		tree,
	)
	if not bool(marketplace_ranking.get("accepted", false)):
		return _cleanup_failure(client, "marketplace ranking failed: %s" % marketplace_ranking)
	var marketplace_authors: Dictionary = await _request_and_wait(
		client, results,
		func() -> Dictionary: return client.list_marketplace_author_rankings(profile_id, 24),
		tree,
	)
	if not bool(marketplace_authors.get("accepted", false)):
		return _cleanup_failure(client, "marketplace authors failed: %s" % marketplace_authors)
	var author_id := str(marketplace_authors.get("items", [])[0].get("author_id", ""))
	var marketplace_works: Dictionary = await _request_and_wait(
		client, results,
		func() -> Dictionary: return client.list_marketplace_author_strategies(author_id, 24),
		tree,
	)
	if not bool(marketplace_works.get("accepted", false)):
		return _cleanup_failure(client, "marketplace author works failed: %s" % marketplace_works)
	var installable_release: Dictionary = marketplace_ranking.get("items", [])[0].get(
		"installable_release", {}
	)
	var package_download: Dictionary = await _request_and_wait(
		client, results,
		func() -> Dictionary: return client.download_marketplace_release(installable_release),
		tree,
	)
	if not bool(package_download.get("accepted", false)):
		return _cleanup_failure(client, "marketplace package failed: %s" % package_download)
	var package_install: Dictionary = AuthorStrategyPackageCatalog.install_from_bytes(
		package_download.get("package_bytes", PackedByteArray()),
		package_download.get("expected_release", {})
	)
	if not bool(package_install.get("ok", false)):
		return _cleanup_failure(client, "marketplace install failed: %s" % package_install)
	var challenge: Dictionary = await _request_and_wait(
		client,
		results,
		func() -> Dictionary: return client.resolve_challenge(release_id, replay_id),
		tree,
	)
	if not bool(challenge.get("accepted", false)):
		return _cleanup_failure(client, "challenge failed: %s" % challenge)
	AuthorStrategyPackageCatalog.scan_startup()
	var bound: Dictionary = BinderScript.bind(challenge.get("intent", {}), AuthorStrategyPackageCatalog)
	var selection_accepted := bool(bound.get("accepted", false)) \
		and GameManager.set_author_strategy_selection(bound.get("selection", {}))
	var selected: Dictionary = GameManager.get_author_strategy_selection()
	GameManager.reset_author_strategy_selection()
	var event: Dictionary = await _request_and_wait(
		client,
		results,
		func() -> Dictionary: return client.record_event({
			"event_name": "challenge_start",
			"anonymous_session_sha256": "A".repeat(64),
			"release_id": release_id,
			"replay_id": replay_id,
		}, token),
		tree,
	)
	var client_audit: Dictionary = client.audit_snapshot()
	tree.root.remove_child(client)
	client.free()

	var contracts: Dictionary = ContractsScript.load_default()
	if not bool(contracts.get("accepted", false)):
		return "replay contract load failed: %s" % contracts
	var reader_created: Dictionary = ReaderScript.create(contracts.owner, null, endpoint, true)
	if not bool(reader_created.get("accepted", false)):
		return "reader creation failed: %s" % reader_created
	var reader: Node = reader_created.reader
	tree.root.add_child(reader)
	await tree.process_frame
	var read_results: Array[Dictionary] = []
	reader.read_completed.connect(func(result: Dictionary) -> void:
		read_results.append(result.duplicate(true))
	)
	var read_started: Dictionary = reader.fetch(replay_id)
	if not bool(read_started.get("accepted", false)):
		return _cleanup_failure(reader, "replay read start failed: %s" % read_started)
	var deadline := Time.get_ticks_msec() + 35_000
	while read_results.is_empty() and Time.get_ticks_msec() < deadline:
		await tree.process_frame
	var read: Dictionary = read_results[0] if not read_results.is_empty() else {}
	var opened: Dictionary = PresentationScript.create(
		contracts.owner,
		read.get("artifact", {}).get("manifest"),
		read.get("artifact", {}).get("frames"),
	) if bool(read.get("accepted", false)) else {}
	var reader_audit: Dictionary = reader.audit_snapshot()
	tree.root.remove_child(reader)
	reader.free()
	var catalog_contains_release := false
	for catalog_item: Variant in items:
		if catalog_item is Dictionary and str(catalog_item.get("featured_release", {}).get("release_id", "")) == release_id:
			catalog_contains_release = true
			break
	return run_checks([
		assert_true(catalog_contains_release),
		assert_eq(detail.get("detail", {}).get("representative_replays", []).size(), 1, "representative replay"),
		assert_false(bool(stats.get("statistics", {}).get("official", {}).get("available", true))),
		assert_eq(stats.get("statistics", {}).get("shadow", {}).get("status"), "shadow_test_only"),
		assert_eq(stats.get("statistics", {}).get("community", {}).get("active_replay_count"), 1, "community replay count"),
		assert_true(marketplace_latest.get("items", []).size() >= 1),
		assert_eq(marketplace_ranking.get("ranking_snapshot_id"), "marketplace-e2e-snapshot-v1"),
		assert_true(bool(marketplace_ranking.get("items", [])[0].get("download_available", false))),
		assert_eq(marketplace_authors.get("contribution_formula_id"), "competition_performance_mean_v1"),
		assert_eq(marketplace_works.get("items", []).size(), 1, "marketplace author works"),
		assert_true(bool(package_install.get("catalog_discoverable", false))),
		assert_true(selection_accepted),
		assert_eq(selected.get("archive_sha256"), bound.get("selection", {}).get("archive_sha256")),
		assert_true(bool(event.get("accepted", false))),
		assert_true(bool(read.get("accepted", false))),
		assert_true(bool(opened.get("accepted", false))),
		assert_false(bool(client_audit.get("authoritative", true))),
		assert_false(bool(client_audit.get("persists_credentials", true))),
		assert_false(bool(reader_audit.get("authoritative", true))),
		assert_eq(reader_audit.get("engine_invocations"), 0),
		assert_eq(reader_audit.get("ticket_invocations"), 0),
	])


func _request_and_wait(
	client: Node,
	results: Array[Dictionary],
	start: Callable,
	tree: SceneTree
) -> Dictionary:
	results.clear()
	var started: Dictionary = start.call()
	if not bool(started.get("accepted", false)):
		return started
	var deadline := Time.get_ticks_msec() + 35_000
	while results.is_empty() and Time.get_ticks_msec() < deadline:
		await tree.process_frame
	return results[0] if not results.is_empty() else {
		"accepted": false, "error_code": "platform_e2e_timeout"
	}


func _cleanup_failure(node: Node, message: String) -> String:
	if node != null and node.get_parent() != null:
		node.get_parent().remove_child(node)
	if node != null:
		node.free()
	return message


static func _arguments() -> Dictionary:
	var result := {}
	for argument: String in OS.get_cmdline_user_args():
		if not argument.begins_with("--"):
			continue
		var separator := argument.find("=")
		if separator > 2:
			result[argument.substr(2, separator - 2)] = argument.substr(separator + 1)
	return result
