class_name TestBattleAdviceFormatter
extends TestBase

const BattleAdviceFormatterScript = preload("res://scripts/ui/battle/BattleAdviceFormatter.gd")


func _u(codepoints: Array[int]) -> String:
	var text := ""
	for codepoint: int in codepoints:
		text += char(codepoint)
	return text


func _new_formatter() -> RefCounted:
	return BattleAdviceFormatterScript.new()


func test_formatter_renders_layered_chinese_sections() -> String:
	var formatter := _new_formatter()
	var formatted := str(formatter.call("format_advice", {
		"status": "completed",
		"strategic_thesis": _u([0x8FD9, 0x56DE, 0x5408, 0x5148, 0x5C55, 0x5F00, 0xFF0C, 0x518D, 0x5904, 0x7406, 0x6253, 0x70B9, 0x3002]),
		"current_turn_main_line": [
			{"step": 1, "action": "Search Charizard", "why": "Unlock the cleanest attacker first."},
		],
		"conditional_branches": [
			{"if": "Opponent benches a two-prizer", "then": ["Hold gust for the follow-up knockout."]},
		],
		"prize_plan": [
			{"horizon": "next_two_turns", "goal": "Map out the two-prize turn sequence."},
		],
		"why_this_line": ["You preserve resources while keeping the same prize pressure."],
		"risk_watchouts": [
			{"risk": "Over-benching support Pokemon.", "mitigation": "Bench only the irreplaceable piece."},
		],
		"confidence": "high",
	}))

	return run_checks([
		assert_str_contains(formatted, _u([0x6838, 0x5FC3, 0x5224, 0x65AD]), "Advice formatter should render the thesis section"),
		assert_str_contains(formatted, _u([0x672C, 0x56DE, 0x5408, 0x4E3B, 0x7EBF]), "Advice formatter should render the main-line section"),
		assert_str_contains(formatted, _u([0x6761, 0x4EF6, 0x5206, 0x652F]), "Advice formatter should render the branch section"),
		assert_str_contains(formatted, _u([0x62FF, 0x5956, 0x8282, 0x594F]), "Advice formatter should render the prize-plan section"),
		assert_str_contains(formatted, _u([0x4E3A, 0x4EC0, 0x4E48, 0x8FD9, 0x6837, 0x6253]), "Advice formatter should render the rationale section"),
		assert_str_contains(formatted, _u([0x98CE, 0x9669, 0x63D0, 0x9192]), "Advice formatter should render the risk section"),
		assert_str_contains(formatted, _u([0x7F6E, 0x4FE1, 0x5EA6]), "Advice formatter should render the confidence section"),
		assert_false("Status" in formatted, "Advice formatter should not expose English section labels"),
	])


func test_formatter_renders_running_and_failed_states() -> String:
	var formatter := _new_formatter()
	var running := str(formatter.call("format_advice", {"status": "running"}, _u([0x6B63, 0x5728, 0x5206, 0x6790, 0x2026])))
	var failed := str(formatter.call("format_advice", {
		"status": "failed",
		"errors": [{"message": "network timeout"}],
	}))

	return run_checks([
		assert_str_contains(running, _u([0x41, 0x49, 0x5EFA, 0x8BAE]), "Running state should preserve the AI advice title"),
		assert_str_contains(running, _u([0x6B63, 0x5728, 0x5206, 0x6790]), "Running state should include the progress text"),
		assert_str_contains(failed, _u([0x72B6, 0x6001]), "Failed state should include a readable status label"),
		assert_str_contains(failed, _u([0x9519, 0x8BEF]), "Failed state should include a readable error label"),
		assert_str_contains(failed, "network timeout", "Failed state should keep the underlying error message"),
	])
