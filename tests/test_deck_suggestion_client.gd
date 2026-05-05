class_name TestDeckSuggestionClient
extends TestBase

const DeckSuggestionClientScript := preload("res://scripts/network/DeckSuggestionClient.gd")


func test_deck_suggestion_client_builds_cloud_payload() -> String:
	var payload: Dictionary = DeckSuggestionClientScript.build_payload("current-rec", PackedStringArray(["seen-a", "seen-b"]), {
		"app_version": "v0.2.1",
		"platform": "Windows",
		"source": "test",
		"requested_at": 123,
	})
	var exclude_ids: Array = payload.get("exclude_ids", [])

	return run_checks([
		assert_eq(str(payload.get("current_id", "")), "current-rec", "Payload should include current recommendation id"),
		assert_eq(exclude_ids.size(), 2, "Payload should include cached recommendation ids"),
		assert_contains(exclude_ids, "seen-a", "Payload should preserve excluded ids"),
		assert_eq(str(payload.get("app_version", "")), "v0.2.1", "Payload should include app version"),
		assert_eq(str(payload.get("platform", "")), "Windows", "Payload should include platform"),
		assert_eq(str(payload.get("source", "")), "test", "Payload should include request source"),
		assert_eq(int(payload.get("requested_at", 0)), 123, "Payload should include request timestamp"),
	])


func test_deck_suggestion_client_extracts_recommendation_response() -> String:
	var recommendation := {
		"id": "2026-05-04-raging-bolt",
		"deck_id": 599382,
		"deck_name": "猛雷鼓 Ogerpon",
	}
	var ok_response := {
		"ok": true,
		"recommendation": recommendation,
	}
	var failed_response := {
		"ok": false,
		"recommendation": recommendation,
	}

	var extracted: Dictionary = DeckSuggestionClientScript.extract_recommendation(ok_response)
	var rejected: Dictionary = DeckSuggestionClientScript.extract_recommendation(failed_response)

	return run_checks([
		assert_eq(str(extracted.get("id", "")), "2026-05-04-raging-bolt", "Client should extract successful recommendation payload"),
		assert_true(rejected.is_empty(), "Client should reject unsuccessful recommendation responses"),
	])


func test_deck_suggestion_client_uses_production_endpoint() -> String:
	return assert_eq(str(DeckSuggestionClientScript.ENDPOINT_URL), "http://fc.skillserver.cn/decksuggest", "Deck suggestion client should use the production cloud function endpoint")
