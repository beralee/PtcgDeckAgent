class_name TestBattleReviewFormatter
extends TestBase

const BattleReviewFormatterScript = preload("res://scripts/ui/battle/BattleReviewFormatter.gd")


func _u(codepoints: Array[int]) -> String:
	var text := ""
	for codepoint: int in codepoints:
		text += char(codepoint)
	return text


func _new_formatter() -> RefCounted:
	return BattleReviewFormatterScript.new()


func test_formatter_renders_readable_review_sections() -> String:
	var formatter := _new_formatter()
	var formatted := str(formatter.call("format_review", {
		"status": "completed",
		"selected_turns": [
			{"side": "winner", "turn_number": 4, "reason": _u([0x6253, 0x51FA, 0x5173, 0x952E, 0x8FDB, 0x5316, 0x8282, 0x594F])},
			{"side": "loser", "turn_number": 5, "reason": _u([0x8D44, 0x6E90, 0x6295, 0x653E, 0x65F6, 0x673A, 0x5931, 0x8BEF])},
		],
		"turn_reviews": [
			{
				"turn_number": 4,
				"turn_goal": _u([0x5148, 0x7A33, 0x5B9A, 0x7AD9, 0x573A]),
				"timing_window": {"assessment": _u([0x6B64, 0x65F6, 0x8FDB, 0x5316, 0x6700, 0x5408, 0x9002])},
				"why_current_line_falls_short": [_u([0x4E0D, 0x8BE5, 0x5148, 0x4EA4, 0x6389, 0x8D44, 0x6E90])],
				"best_line": {
					"summary": _u([0x5148, 0x505A, 0x68C0, 0x7D22, 0xFF0C, 0x518D, 0x786E, 0x8BA4, 0x51FB, 0x5012]),
					"steps": [
						_u([0x68C0, 0x7D22, 0x8FDB, 0x5316, 0x4EF6]),
						_u([0x8D34, 0x4E0A, 0x80FD, 0x91CF]),
					],
				},
				"coach_takeaway": _u([0x5148, 0x786E, 0x4FDD, 0x7A33, 0x5B9A, 0x5C55, 0x5F00]),
			},
			{
				"turn_number": 5,
				"why_current_line_falls_short": [_u([0x4E0D, 0x8BE5, 0x4E3A, 0x4E86, 0x5C0F, 0x4F24, 0x5BB3, 0x800C, 0x4E71, 0x5C55, 0x5F00])],
				"best_line": {
					"summary": _u([0x6539, 0x7528, 0x7A33, 0x5B9A, 0x7EBF, 0x63A8, 0x8FDB]),
				},
				"coach_takeaway": _u([0x4E0D, 0x8981, 0x88AB, 0x77ED, 0x671F, 0x4EF7, 0x503C, 0x5E26, 0x504F]),
			},
		],
	}))

	return run_checks([
		assert_str_contains(formatted, _u([0x72B6, 0x6001]), "Review formatter should render the status label"),
		assert_str_contains(formatted, _u([0x83B7, 0x80DC, 0x65B9, 0x5173, 0x952E, 0x56DE, 0x5408]), "Review formatter should render the winner heading"),
		assert_str_contains(formatted, _u([0x5931, 0x5229, 0x65B9, 0x5173, 0x952E, 0x56DE, 0x5408]), "Review formatter should render the loser heading"),
		assert_str_contains(formatted, _u([0x56DE, 0x5408, 0x76EE, 0x6807]), "Review formatter should render the turn-goal label"),
		assert_str_contains(formatted, _u([0x65F6, 0x673A, 0x5224, 0x65AD]), "Review formatter should render the timing label"),
		assert_str_contains(formatted, _u([0x5F53, 0x524D, 0x7EBF, 0x8DEF, 0x95EE, 0x9898]), "Review formatter should render the current-line issues label"),
		assert_str_contains(formatted, _u([0x6700, 0x4F73, 0x8DEF, 0x7EBF]), "Review formatter should render the best-line label"),
		assert_str_contains(formatted, _u([0x6559, 0x7EC3, 0x603B, 0x7ED3]), "Review formatter should render the takeaway label"),
		assert_false("Winner Key Turn" in formatted, "Review formatter should not expose English section labels"),
	])


func test_formatter_renders_review_errors_and_empty_sides() -> String:
	var formatter := _new_formatter()
	var formatted := str(formatter.call("format_review", {
		"status": "failed",
		"errors": [{"message": "Stage 1 selected an unknown turn"}],
	}))

	return run_checks([
		assert_str_contains(formatted, _u([0x72B6, 0x6001]), "Failed review output should include the status label"),
		assert_str_contains(formatted, _u([0x9519, 0x8BEF]), "Failed review output should include the error label"),
		assert_str_contains(formatted, _u([0x6682, 0x65E0]), "Empty side output should use a readable empty-state label"),
		assert_false("Errors" in formatted, "Failed review output should not expose English section labels"),
	])
