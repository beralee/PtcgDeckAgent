class_name TestDeckCenterMetaClient
extends TestBase

const DeckCenterMetaClientScript := preload("res://scripts/network/DeckCenterMetaClient.gd")
const STATE_PATH := "user://deck_center_meta_state.json"


func _remove_state_file() -> void:
	var absolute_path := ProjectSettings.globalize_path(STATE_PATH)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)


func test_deck_center_meta_client_uses_public_endpoint() -> String:
	return assert_eq(str(DeckCenterMetaClientScript.ENDPOINT_URL), "http://fc.skillserver.cn/deckcentermeta", "Deck center metadata client should use the production cloud function endpoint")


func test_deck_center_meta_normalizes_latest_revision() -> String:
	var info: Dictionary = DeckCenterMetaClientScript.normalize_meta({
		"ok": true,
		"schema_version": 1,
		"channel": "deck_recommendations",
		"latest_revision": " rev-1 ",
		"latest_recommendation_id": " rec-1 ",
		"latest_deck_id": 609793,
		"latest_title": " title ",
		"latest_deck_name": " deck ",
		"updated_at": 1779617400000,
		"updated_at_iso": "2026-05-24T10:10:00.000Z",
		"source": "unit_test",
	})
	var rejected: Dictionary = DeckCenterMetaClientScript.normalize_meta({
		"ok": true,
		"latest_revision": "   ",
	})
	return run_checks([
		assert_eq(str(info.get("latest_revision", "")), "rev-1", "Latest revision should be trimmed"),
		assert_eq(str(info.get("latest_recommendation_id", "")), "rec-1", "Recommendation id should be preserved"),
		assert_eq(int(info.get("latest_deck_id", 0)), 609793, "Deck id should be preserved"),
		assert_true(rejected.is_empty(), "Empty latest revision should be rejected"),
	])


func test_deck_center_meta_unseen_revision_compare() -> String:
	return run_checks([
		assert_false(DeckCenterMetaClientScript.is_unseen_revision("", "seen"), "Empty latest revision should not flash"),
		assert_false(DeckCenterMetaClientScript.is_unseen_revision("same", " same "), "Matching revision should not flash"),
		assert_true(DeckCenterMetaClientScript.is_unseen_revision("new", "old"), "Different revision should flash"),
		assert_true(DeckCenterMetaClientScript.is_bootstrap_meta({"latest_revision": "bootstrap:old"}), "Bootstrap revision should be recognized"),
		assert_false(DeckCenterMetaClientScript.is_bootstrap_meta({"latest_revision": "real-new"}), "Real new revision should not be treated as bootstrap"),
	])


func test_deck_center_meta_first_check_seeds_bootstrap_revision() -> String:
	_remove_state_file()
	var client = DeckCenterMetaClientScript.new()
	var counts := {"new": 0, "same": 0}
	client.new_revision_available.connect(func(_info: Dictionary) -> void:
		counts["new"] = int(counts.get("new", 0)) + 1
	)
	client.no_new_revision.connect(func(_info: Dictionary) -> void:
		counts["same"] = int(counts.get("same", 0)) + 1
	)

	client.call("_handle_checked_meta", {"latest_revision": "bootstrap:server-bootstrap"})
	var seen := client.get_last_seen_revision()

	client.free()
	_remove_state_file()
	return run_checks([
		assert_eq(seen, "bootstrap:server-bootstrap", "First bootstrap metadata check should seed the local seen revision"),
		assert_eq(int(counts.get("new", 0)), 0, "First metadata check should not flash an old bootstrap revision"),
		assert_eq(int(counts.get("same", 0)), 1, "First metadata check should report no new content"),
	])


func test_deck_center_meta_first_real_revision_flashes() -> String:
	_remove_state_file()
	var client = DeckCenterMetaClientScript.new()
	var counts := {"new": 0, "same": 0}
	client.new_revision_available.connect(func(_info: Dictionary) -> void:
		counts["new"] = int(counts.get("new", 0)) + 1
	)
	client.no_new_revision.connect(func(_info: Dictionary) -> void:
		counts["same"] = int(counts.get("same", 0)) + 1
	)

	client.call("_handle_checked_meta", {"latest_revision": "real-new-rev"})
	var seen := client.get_last_seen_revision()

	client.free()
	_remove_state_file()
	return run_checks([
		assert_eq(seen, "", "First real new revision should remain unseen until the player opens deck center"),
		assert_eq(int(counts.get("new", 0)), 1, "First real new revision should flash"),
		assert_eq(int(counts.get("same", 0)), 0, "First real new revision should not report no-new content"),
	])


func test_deck_center_meta_later_revision_flashes_until_seen() -> String:
	_remove_state_file()
	var client = DeckCenterMetaClientScript.new()
	client.mark_revision_seen("old-rev")

	var counts := {"new": 0, "same": 0}
	client.new_revision_available.connect(func(_info: Dictionary) -> void:
		counts["new"] = int(counts.get("new", 0)) + 1
	)
	client.no_new_revision.connect(func(_info: Dictionary) -> void:
		counts["same"] = int(counts.get("same", 0)) + 1
	)

	client.call("_handle_checked_meta", {"latest_revision": "new-rev"})
	var still_seen := client.get_last_seen_revision()
	client.mark_revision_seen("new-rev")
	var after_seen := client.get_last_seen_revision()

	client.free()
	_remove_state_file()
	return run_checks([
		assert_eq(still_seen, "old-rev", "New revision should not be marked seen until the player opens the deck center"),
		assert_eq(after_seen, "new-rev", "Opening the deck center should mark the revision as seen"),
		assert_eq(int(counts.get("new", 0)), 1, "New revision should emit one flash signal"),
		assert_eq(int(counts.get("same", 0)), 0, "New revision should not emit no-new signal"),
	])


func test_deck_center_meta_marks_latest_cached_revision_seen() -> String:
	_remove_state_file()
	var file := FileAccess.open(STATE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"latest_info": {
			"latest_revision": "cached-latest-rev",
			"latest_recommendation_id": "cached-rec",
			"source": "unit_test",
		},
	}, "\t"))
	file.close()

	var client = DeckCenterMetaClientScript.new()
	var marked: bool = client.mark_latest_known_revision_seen()
	var seen := client.get_last_seen_revision()

	client.free()
	_remove_state_file()
	return run_checks([
		assert_true(marked, "Cached latest metadata should be markable as seen without an in-memory pending signal"),
		assert_eq(seen, "cached-latest-rev", "Marking cached latest metadata should persist last_seen_revision"),
	])


func test_deck_center_meta_treats_seen_recommendation_badge_as_seen_revision() -> String:
	_remove_state_file()
	var file := FileAccess.open(STATE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"last_recommendation_badge_seen_revision": "new-rev",
		"last_recommendation_badge_seen_at": 12345,
	}, "\t"))
	file.close()

	var client = DeckCenterMetaClientScript.new()
	var counts := {"new": 0, "same": 0}
	client.new_revision_available.connect(func(_info: Dictionary) -> void:
		counts["new"] = int(counts.get("new", 0)) + 1
	)
	client.no_new_revision.connect(func(_info: Dictionary) -> void:
		counts["same"] = int(counts.get("same", 0)) + 1
	)

	client.call("_handle_checked_meta", {"latest_revision": "new-rev"})
	var seen := client.get_last_seen_revision()

	client.free()
	_remove_state_file()
	return run_checks([
		assert_eq(seen, "new-rev", "Recommendation-card NEW visibility should also satisfy the main-menu seen revision"),
		assert_eq(int(counts.get("new", 0)), 0, "Already-seen recommendation revision should not flash again on startup"),
		assert_eq(int(counts.get("same", 0)), 1, "Already-seen recommendation revision should emit no-new"),
	])
