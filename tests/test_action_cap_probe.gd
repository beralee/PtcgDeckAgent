class_name TestActionCapProbe
extends TestBase

const AIBenchmarkRunnerScript = preload("res://scripts/ai/AIBenchmarkRunner.gd")
const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")
const DeckStrategyRegistryScript = preload("res://scripts/ai/DeckStrategyRegistry.gd")


class TraceCollector extends RefCounted:
	var traces: Array = []

	func record_trace(trace) -> void:
		if trace == null:
			return
		traces.append(trace.clone())


func _make_bundled_ai(player_index: int, deck_id: int, decision_mode: String = "") -> AIOpponent:
	var ai := AIOpponentScript.new()
	ai.configure(player_index, 1)
	if decision_mode != "":
		ai.decision_runtime_mode = decision_mode
	var deck: DeckData = CardDatabase.get_deck(deck_id)
	if deck == null:
		return ai
	var registry := DeckStrategyRegistryScript.new()
	registry.apply_strategy_for_deck(ai, deck)
	return ai


func _trace_tail_summary(traces: Array, limit: int = 32) -> String:
	var start_index := maxi(0, traces.size() - limit)
	var parts: Array[String] = []
	for idx: int in range(start_index, traces.size()):
		var trace = traces[idx]
		if trace == null:
			continue
		var chosen_action: Dictionary = trace.chosen_action if trace.chosen_action is Dictionary else {}
		var card_name := str(chosen_action.get("card_name", chosen_action.get("name", "")))
		var source_name := ""
		var source_slot: Variant = chosen_action.get("source_slot", null)
		if source_slot is PokemonSlot:
			source_name = (source_slot as PokemonSlot).get_pokemon_name()
		var target_name := ""
		var target_slot: Variant = chosen_action.get("target_slot", null)
		if target_slot is PokemonSlot:
			target_name = (target_slot as PokemonSlot).get_pokemon_name()
		parts.append("t%d:p%d:%s:%s:%s:%s:a%d:u%d" % [
			int(trace.turn_number),
			int(trace.player_index),
			str(chosen_action.get("kind", "")),
			source_name,
			card_name,
			target_name,
			int(chosen_action.get("attack_index", -1)),
			int(chosen_action.get("ability_index", -1)),
		])
	return " | ".join(parts)


func _run_seed(
	deck_id: int,
	anchor_deck_id: int,
	seed_value: int,
	tracked_player_index: int,
	max_steps: int = 200,
	with_trace: bool = true,
	decision_mode: String = ""
) -> Dictionary:
	var benchmark_runner := AIBenchmarkRunnerScript.new()
	var gsm := GameStateMachine.new()
	benchmark_runner.call("_clear_forced_shuffle_seed")
	benchmark_runner.call("_apply_match_seed", gsm, seed_value)
	benchmark_runner.call("_set_forced_shuffle_seed", seed_value)
	var tracked_deck: DeckData = CardDatabase.get_deck(deck_id)
	var anchor_deck: DeckData = CardDatabase.get_deck(anchor_deck_id)
	var player_0_deck: DeckData = tracked_deck if tracked_player_index == 0 else anchor_deck
	var player_1_deck: DeckData = anchor_deck if tracked_player_index == 0 else tracked_deck
	gsm.start_game(player_0_deck, player_1_deck, 0)
	var trace_collector := TraceCollector.new() if with_trace else null
	var result: Dictionary = benchmark_runner.run_headless_duel(
		_make_bundled_ai(0, player_0_deck.id, decision_mode),
		_make_bundled_ai(1, player_1_deck.id, decision_mode),
		gsm,
		max_steps,
		Callable(),
		trace_collector
	)
	benchmark_runner.call("_clear_forced_shuffle_seed")
	print("ACTION_CAP_PROBE deck=%d seed=%d tracked=%d result=%s" % [
		deck_id,
		seed_value,
		tracked_player_index,
		JSON.stringify(result),
	])
	var trace_tail := _trace_tail_summary(trace_collector.traces) if trace_collector != null else ""
	print("ACTION_CAP_TRACE tail=%s" % trace_tail)
	return {
		"result": result,
		"trace_tail": trace_tail,
	}


func test_probe_dragapult_dusknoir_action_cap_seed() -> String:
	var probe := _run_seed(575723, 575720, 25913, 1)
	var result: Dictionary = probe.get("result", {})
	return run_checks([
		assert_true(str(result.get("failure_reason", "")) != "action_cap_reached",
			"Known dirty seed 25913 should no longer end in action_cap_reached; tail=%s" % str(probe.get("trace_tail", ""))),
	])


func test_probe_iron_thorns_miraidon_attack_loop_seed() -> String:
	var probe := _run_seed(579577, 575720, 26387, 1)
	var result: Dictionary = probe.get("result", {})
	return run_checks([
		assert_true(str(result.get("failure_reason", "")) != "action_cap_reached",
			"Known dirty seed 26387 should no longer end in action_cap_reached; tail=%s" % str(probe.get("trace_tail", ""))),
	])


func test_probe_iron_thorns_tm_turbo_energize_seed_player_zero() -> String:
	var probe := _run_seed(579577, 575720, 9210, 0)
	var result: Dictionary = probe.get("result", {})
	return run_checks([
		assert_true(str(result.get("failure_reason", "")) != "unsupported_interaction_step",
			"Seed 9210 should no longer fail on unsupported granted-attack interaction; tail=%s" % str(probe.get("trace_tail", ""))),
	])


func test_probe_iron_thorns_tm_turbo_energize_seed_player_one() -> String:
	var probe := _run_seed(579577, 575720, 9205, 1)
	var result: Dictionary = probe.get("result", {})
	return run_checks([
		assert_true(str(result.get("failure_reason", "")) != "unsupported_interaction_step",
			"Seed 9205 should no longer fail on unsupported granted-attack interaction; tail=%s" % str(probe.get("trace_tail", ""))),
	])


func test_trace_export_does_not_change_palkia_gholdengo_seed_result() -> String:
	var untraced := _run_seed(1700004, 575716, 6030, 0, 200, false, AIOpponentScript.DECISION_RUNTIME_RULES_ONLY)
	var traced := _run_seed(1700004, 575716, 6030, 0, 200, true, AIOpponentScript.DECISION_RUNTIME_RULES_ONLY)
	var untraced_result: Dictionary = untraced.get("result", {})
	var traced_result: Dictionary = traced.get("result", {})
	return run_checks([
		assert_eq(int(traced_result.get("winner_index", -99)), int(untraced_result.get("winner_index", -98)),
			"Trace collection must not change winner for seed 6030"),
		assert_eq(str(traced_result.get("failure_reason", "")), str(untraced_result.get("failure_reason", "")),
			"Trace collection must not change terminal classification for seed 6030"),
		assert_eq(int(traced_result.get("turn_count", -99)), int(untraced_result.get("turn_count", -98)),
			"Trace collection must not change game length for seed 6030"),
	])


func test_probe_palkia_gholdengo_seed_6011_terminal_on_cap_boundary_is_clean() -> String:
	var probe := _run_seed(1700004, 575716, 6011, 1, 200, false, AIOpponentScript.DECISION_RUNTIME_RULES_ONLY)
	var result: Dictionary = probe.get("result", {})
	return run_checks([
		assert_true(str(result.get("failure_reason", "")) != "action_cap_reached",
			"Seed 6011 reaches a real terminal state on the max-step boundary and should not be reported as action_cap_reached"),
		assert_eq(int(result.get("winner_index", -99)), 1, "Seed 6011 should keep the actual terminal winner when it ends on the step boundary"),
	])
