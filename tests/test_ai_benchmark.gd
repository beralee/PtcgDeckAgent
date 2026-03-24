class_name TestAIBenchmark
extends TestBase

const AIBenchmarkRunnerScript = preload("res://scripts/ai/AIBenchmarkRunner.gd")
const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")


class StepRunnerSpy extends RefCounted:
	var calls: int = 0
	var winner_after_calls: int = -1

	func run(_passed_agent: Variant, _state: Dictionary) -> Dictionary:
		calls += 1
		if winner_after_calls > 0 and calls >= winner_after_calls:
			return {"winner_index": 1}
		return {}


func _make_benchmark_basic(name: String, hp: int = 60, attacks: Array = []) -> CardInstance:
	var card := CardData.new()
	card.name = name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = hp
	card.attacks.clear()
	for attack: Dictionary in attacks:
		card.attacks.append(attack.duplicate(true))
	return CardInstance.create(card, 0)


func _make_benchmark_filler(name: String) -> CardInstance:
	var card := CardData.new()
	card.name = name
	card.card_type = "Item"
	return CardInstance.create(card, 0)


func _make_benchmark_slot(card: CardInstance) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(card)
	return slot


func _make_headless_smoke_gsm() -> GameStateMachine:
	CardInstance.reset_id_counter()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.players = [PlayerState.new(), PlayerState.new()]
	gsm.game_state.players[0].player_index = 0
	gsm.game_state.players[1].player_index = 1
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 1
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
	var attack := {"name": "Bench Breaker", "cost": "", "damage": "120", "text": "", "is_vstar_power": false}
	gsm.game_state.players[0].active_pokemon = _make_benchmark_slot(_make_benchmark_basic("P0 Active", 70, [attack]))
	gsm.game_state.players[0].bench = [_make_benchmark_slot(_make_benchmark_basic("P0 Bench", 70, [attack]))]
	gsm.game_state.players[1].active_pokemon = _make_benchmark_slot(_make_benchmark_basic("P1 Active", 70, [attack]))
	gsm.game_state.players[1].bench = [_make_benchmark_slot(_make_benchmark_basic("P1 Bench", 70, [attack]))]
	gsm.game_state.players[0].set_prizes([
		_make_benchmark_filler("P0 Prize 1"),
		_make_benchmark_filler("P0 Prize 2"),
	])
	gsm.game_state.players[1].set_prizes([
		_make_benchmark_filler("P1 Prize 1"),
		_make_benchmark_filler("P1 Prize 2"),
	])
	gsm.game_state.players[0].deck = [
		_make_benchmark_filler("P0 Deck 1"),
		_make_benchmark_filler("P0 Deck 2"),
	]
	gsm.game_state.players[1].deck = [
		_make_benchmark_filler("P1 Deck 1"),
		_make_benchmark_filler("P1 Deck 2"),
	]
	return gsm


func test_benchmark_runner_aggregates_match_results() -> String:
	var runner = AIBenchmarkRunnerScript.new()
	var agent = AIOpponentScript.new()
	var summary: Dictionary = runner.run_fixed_match_set(agent, [
		{"tracked_player_index": 1, "result": {"winner_index": 1}},
		{"tracked_player_index": 1, "result": {"winner_index": 0}},
		{"tracked_player_index": 1, "result": {"winner_index": 1}},
	])
	return run_checks([
		assert_eq(summary.get("total_matches", -1), 3, "Benchmark runner should report the total number of matchups"),
		assert_eq(summary.get("wins", -1), 2, "Benchmark runner should count wins for the tracked player"),
		assert_eq(summary.get("win_rate", -1.0), 2.0 / 3.0, "Benchmark runner should derive a deterministic win_rate"),
	])


func test_benchmark_runner_accepts_callable_match_executors() -> String:
	var runner = AIBenchmarkRunnerScript.new()
	var agent = AIOpponentScript.new()
	var fixed_runner := func(_passed_agent: Variant, matchup: Dictionary) -> Dictionary:
		return matchup.get("result", {})
	var summary: Dictionary = runner.run_fixed_match_set(agent, [
		{
			"tracked_player_index": 1,
			"runner": fixed_runner,
			"result": {"winner_index": 1},
		},
		{
			"tracked_player_index": 1,
			"runner": fixed_runner,
			"result": {"winner_index": 1},
		},
	])
	return run_checks([
		assert_eq(summary.get("total_matches", -1), 2, "Callable-driven matchups should still contribute to total_matches"),
		assert_eq(summary.get("wins", -1), 2, "Callable-driven matchups should be aggregated the same way as fixed results"),
		assert_eq(summary.get("win_rate", -1.0), 1.0, "All-win callable matchups should yield a 1.0 win rate"),
	])


func test_benchmark_runner_smoke_match_stops_on_terminal_result() -> String:
	var runner = AIBenchmarkRunnerScript.new()
	var agent = AIOpponentScript.new()
	var spy := StepRunnerSpy.new()
	spy.winner_after_calls = 3
	var result: Dictionary = runner.run_smoke_match(agent, spy.run, 6)
	return run_checks([
		assert_eq(spy.calls, 3, "Smoke match should keep stepping until the runner returns a terminal result"),
		assert_eq(result.get("winner_index", -1), 1, "Terminal smoke-match results should be returned unchanged"),
		assert_eq(result.get("steps", -1), 3, "Smoke match should report how many step iterations were consumed"),
		assert_false(bool(result.get("terminated_by_cap", true)), "A naturally completed smoke match should not report an action-cap termination"),
	])


func test_benchmark_runner_smoke_match_reports_action_cap_termination() -> String:
	var runner = AIBenchmarkRunnerScript.new()
	var agent = AIOpponentScript.new()
	var spy := StepRunnerSpy.new()
	var result: Dictionary = runner.run_smoke_match(agent, spy.run, 4)
	return run_checks([
		assert_eq(spy.calls, 4, "Smoke match should stop once it hits the configured action cap"),
		assert_eq(result.get("winner_index", 99), -1, "Action-cap termination should return a sentinel non-terminal winner index"),
		assert_eq(result.get("steps", -1), 4, "Action-cap termination should report the consumed step count"),
		assert_true(bool(result.get("terminated_by_cap", false)), "Action-cap termination should be marked explicitly"),
	])


func test_benchmark_runner_can_finish_real_headless_ai_duel() -> String:
	var runner = AIBenchmarkRunnerScript.new()
	var player_0_ai = AIOpponentScript.new()
	player_0_ai.configure(0, 1)
	var player_1_ai = AIOpponentScript.new()
	player_1_ai.configure(1, 1)
	var gsm := _make_headless_smoke_gsm()
	var result: Dictionary = runner.run_headless_duel(player_0_ai, player_1_ai, gsm, 20)
	var send_out_count: int = 0
	var prize_count: int = 0
	for action: GameAction in gsm.action_log:
		if action.action_type == GameAction.ActionType.SEND_OUT:
			send_out_count += 1
		if action.action_type == GameAction.ActionType.TAKE_PRIZE:
			prize_count += 1
	return run_checks([
		assert_eq(result.get("winner_index", -1), 0, "The first attacking AI should win the mirrored smoke duel"),
		assert_false(bool(result.get("terminated_by_cap", true)), "A real headless duel should terminate naturally instead of hitting the action cap"),
		assert_gte(send_out_count, 1, "The smoke duel should exercise the send_out_pokemon prompt path"),
		assert_gte(prize_count, 2, "The smoke duel should exercise prize taking before the winner is declared"),
	])
