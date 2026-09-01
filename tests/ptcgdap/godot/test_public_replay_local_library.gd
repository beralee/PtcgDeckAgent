class_name TestPublicReplayLocalLibrary
extends TestBase

const ContractsScript = preload(
	"res://scripts/ai/ptcgdap/platform/CompetitiveStrategyContracts.gd"
)
const LocalLibraryScript = preload(
	"res://scripts/ai/ptcgdap/platform/replay/PublicReplayLocalLibrary.gd"
)
const ServiceContractScript = preload(
	"res://scripts/ai/ptcgdap/platform/replay/PublicReplayServiceContract.gd"
)
const StoreScript = preload(
	"res://scripts/ai/ptcgdap/platform/replay/PublicReplayStore.gd"
)
const ViewerScene = preload("res://scenes/ptcgdap_public_replay/PublicReplayViewer.tscn")
const FixtureFactoryScript = preload(
	"res://tests/ptcgdap/godot/support/PublicReplayFixtureFactory.gd"
)


class RejectingContractOwner extends RefCounted:
	var validation_calls := 0

	func validate_replay(_manifest: Variant, _frames: Variant) -> Dictionary:
		validation_calls += 1
		return {"accepted": false, "error_code": "unexpected_validation"}

	func validate_document(_document: Variant) -> Dictionary:
		validation_calls += 1
		return {"accepted": false, "error_code": "unexpected_validation"}


func test_local_library_discovers_and_loads_completed_community_replay() -> String:
	var owner: Variant = _contract_owner()
	var artifact := _fixture_artifact()
	if owner == null or artifact.is_empty():
		return "local replay fixture unavailable"
	var storage_namespace := "local-library-%d" % Time.get_ticks_usec()
	var store_created: Dictionary = StoreScript.create(
		owner, storage_namespace, "community_challenge"
	)
	if not bool(store_created.get("accepted", false)):
		return "store create failed: %s" % store_created
	var saved: Dictionary = store_created.store.save_completed(artifact)
	var discovery_owner := RejectingContractOwner.new()
	var discovery_library_created: Dictionary = LocalLibraryScript.create(
		discovery_owner, storage_namespace
	)
	if not bool(discovery_library_created.get("accepted", false)):
		return "discovery library create failed: %s" % discovery_library_created
	var discovered: Dictionary = discovery_library_created.library.list_replays()
	var library_created: Dictionary = LocalLibraryScript.create(owner, storage_namespace)
	if not bool(library_created.get("accepted", false)):
		return "local library create failed: %s" % library_created
	var library: Variant = library_created.library
	var listed: Dictionary = library.list_replays()
	var loaded: Dictionary = library.load_replay(str(artifact.manifest.replay_id))
	var entries: Array = listed.get("entries", [])
	var first: Dictionary = entries[0] if entries.size() == 1 else {}
	return run_checks([
		assert_true(bool(saved.get("accepted", false)), str(saved)),
		assert_true(bool(discovered.get("accepted", false)), str(discovered)),
		assert_eq(discovery_owner.validation_calls, 0),
		assert_true(bool(listed.get("accepted", false)), str(listed)),
		assert_eq(entries.size(), 1),
		assert_eq(first.get("source"), "local"),
		assert_eq(first.get("replay_id"), artifact.manifest.replay_id),
		assert_eq(first.get("frame_count"), 156),
		assert_eq(first.get("strategy_id"), ""),
		assert_true(bool(loaded.get("accepted", false)), str(loaded)),
		assert_eq(loaded.get("artifact", {}).get("manifest", {}).get("frame_count"), 156),
		assert_eq(listed.get("rejected_count"), 0),
	])


func test_local_library_isolates_bad_index_without_hiding_valid_history() -> String:
	var owner: Variant = _contract_owner()
	var artifact := _fixture_artifact()
	if owner == null or artifact.is_empty():
		return "local replay fixture unavailable"
	var storage_namespace := "local-library-invalid-%d" % Time.get_ticks_usec()
	var store_created: Dictionary = StoreScript.create(
		owner, storage_namespace, "community_challenge"
	)
	if not bool(store_created.get("accepted", false)):
		return "store create failed: %s" % store_created
	var store: Variant = store_created.store
	var saved: Dictionary = store.save_completed(artifact)
	var bad_path := "user://ptcgdap/public_replays/%s/index/broken.json" % storage_namespace
	var bad_file := FileAccess.open(bad_path, FileAccess.WRITE)
	if bad_file == null:
		return "unable to create isolated invalid-index fixture"
	bad_file.store_string("{}")
	bad_file.close()
	var library_created: Dictionary = LocalLibraryScript.create(owner, storage_namespace)
	if not bool(library_created.get("accepted", false)):
		return "local library create failed: %s" % library_created
	var listed: Dictionary = library_created.library.list_replays()
	return run_checks([
		assert_true(bool(saved.get("accepted", false)), str(saved)),
		assert_eq(store.list_index().get("error_code"), "replay_index_invalid"),
		assert_true(bool(listed.get("accepted", false)), str(listed)),
		assert_eq(listed.get("entries", []).size(), 1),
		assert_eq(listed.get("entries", [])[0].get("replay_id"), artifact.manifest.replay_id),
		assert_eq(listed.get("rejected_count"), 1),
	])


func test_installed_live_community_history_when_explicitly_requested() -> String:
	var expected_raw := OS.get_environment("PTCGDAP_EXPECT_LOCAL_REPLAY_IDS").strip_edges()
	if expected_raw.is_empty():
		return ""
	var owner: Variant = _contract_owner()
	var library_created: Dictionary = LocalLibraryScript.create(owner, "live-community")
	if not bool(library_created.get("accepted", false)):
		return "installed local library unavailable: %s" % library_created
	var listed: Dictionary = library_created.library.list_replays()
	if not bool(listed.get("accepted", false)):
		return "installed local replay listing failed: %s" % listed
	var actual_ids: Array[String] = []
	for entry: Variant in listed.get("entries", []):
		if entry is Dictionary:
			actual_ids.append(str(entry.get("replay_id", "")))
	var checks: Array[String] = [assert_eq(listed.get("rejected_count"), 0)]
	var tree := Engine.get_main_loop() as SceneTree
	for expected_id: String in expected_raw.split(",", false):
		checks.append(assert_contains(actual_ids, expected_id.strip_edges()))
		var loaded: Dictionary = library_created.library.load_replay(expected_id.strip_edges())
		checks.append(assert_true(bool(loaded.get("accepted", false)), str(loaded)))
		if not bool(loaded.get("accepted", false)):
			continue
		var artifact: Dictionary = loaded.get("artifact", {})
		var viewer: Control = ViewerScene.instantiate()
		tree.root.add_child(viewer)
		await tree.process_frame
		var opened: Dictionary = viewer.load_public_replay(
			owner, artifact.get("manifest"), artifact.get("frames"),
			artifact.get("match_envelope", {})
		)
		checks.append(assert_true(bool(opened.get("accepted", false)), str(opened)))
		if bool(opened.get("accepted", false)):
			viewer.set_playback_speed(4.0)
			viewer.play()
			viewer.advance_playback(1000.0)
			var final_view: Dictionary = viewer.current_view()
			var audit: Dictionary = viewer.presentation_audit()
			var player: Dictionary = viewer.player_snapshot()
			checks.append(assert_eq(
				player.get("autoplay_advance_count"), int(artifact.manifest.frame_count) - 1
			))
			checks.append(assert_false(bool(player.get("is_playing", true))))
			checks.append(assert_eq(final_view.get("event_kind"), "match_finished"))
			checks.append(assert_eq(audit.get("engine_invocations"), 0))
			checks.append(assert_eq(audit.get("ticket_invocations"), 0))
			checks.append(assert_eq(audit.get("callback_invocations"), 0))
		tree.root.remove_child(viewer)
		viewer.free()
	return run_checks(checks)


func _contract_owner() -> Variant:
	var loaded: Dictionary = ContractsScript.load_default()
	return loaded.get("owner") if bool(loaded.get("accepted", false)) else null


func _fixture_artifact() -> Dictionary:
	return FixtureFactoryScript.build_community_artifact(_contract_owner())
