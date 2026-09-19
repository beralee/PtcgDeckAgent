extends TestBase

const Swiss = preload("res://scripts/tournament/SwissTournament.gd")

func _entry(id: String) -> Dictionary:
	return {"selection": {"package_id": id, "package_version": "1.0.0", "archive_sha256": "A".repeat(64), "install_source": "user", "display_name_snapshot": id}, "deck_name": id + "卡组"}

func test_author_roster_preserves_exact_packages_and_distinct_decks() -> String:
	var tournament = Swiss.new()
	var pool: Array[Dictionary] = [_entry("alpha"), _entry("beta")]
	tournament.callv("setup", ["玩家", 575720, 16, 345, false, "open", pool, "author"])
	var authors := 0
	for participant: Dictionary in tournament.participants:
		if participant.ai_mode == "author": authors += 1
	var restored = Swiss.new()
	restored.restore_state(JSON.parse_string(JSON.stringify(tournament.serialize_state())))
	var snapshots_match: bool = restored.participants.size() == tournament.participants.size()
	for participant_id: int in range(1, tournament.participants.size()):
		if restored.participant_author_selection(participant_id) != tournament.participant_author_selection(participant_id) or restored.participant_deck_name(participant_id) != tournament.participant_deck_name(participant_id): snapshots_match = false
	return run_checks([
		assert_eq(authors, 15, "Developer-only tournament must fill every opponent slot"),
		assert_eq(tournament.get_deck_distribution().size(), 3, "Author decks with id 0 must remain distinct"),
		assert_true(snapshots_match, "Save/reload must preserve exact package references and labels"),
	])

func test_mixed_field_and_all_rounds_preserve_author_identity() -> String:
	var errors: Array[String] = []
	for size: int in [16, 32, 64, 128, 256, 512, 1024, 2048]:
		print("TOURNAMENT_SCHEDULE_PROGRESS: %d participants start" % size)
		var tournament = Swiss.new()
		tournament.callv("setup", ["玩家", 575720, size, 345, false, "standard", [_entry("alpha"), _entry("beta")], "mixed"])
		var authors := 0
		for participant: Dictionary in tournament.participants:
			if participant.ai_mode == "author": authors += 1
		if authors <= 0 or authors >= size - 1: errors.append("Mixed roster missing one opponent type: %d" % size)
		while not tournament.finished:
			if size >= 512:
				print("TOURNAMENT_SCHEDULE_PROGRESS: %d participants round %d/%d" % [size, tournament.current_round + 1, tournament.total_rounds])
			tournament.prepare_next_round()
			tournament.record_player_match(tournament.current_round % 2 == 0, "测试")
			var restored = Swiss.new()
			restored.restore_state(tournament.serialize_state())
			tournament = restored
		for participant: Dictionary in tournament.participants:
			if participant.wins + participant.losses != tournament.total_rounds: errors.append("Missing round result")
			if participant.ai_mode == "author" and participant.get("author_strategy_selection", {}).is_empty(): errors.append("Lost author identity")
		print("TOURNAMENT_SCHEDULE_PROGRESS: %d participants complete" % size)
	return "\n".join(errors)


func test_author_mixed_roster_retains_enabled_llm_opponents() -> String:
	for match_seed: int in range(1, 65):
		var tournament = Swiss.new()
		tournament.setup("玩家", 575720, 16, match_seed, true, "open", [_entry("alpha")], "mixed")
		var llm_count := 0
		for participant: Dictionary in tournament.participants:
			if participant.ai_mode == "llm": llm_count += 1
		if llm_count == 0: return "Mixed field lost enabled LLM opponent at seed %d" % match_seed
	return ""
