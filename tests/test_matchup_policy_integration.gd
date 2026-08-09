class_name TestMatchupPolicyIntegration
extends TestBase

const ResolverScript = preload("res://scripts/ai/OpponentDeckFingerprintResolver.gd")
const MarnieStrategyScript = preload("res://scripts/ai/DeckStrategyV18MarnieCynthia.gd")
const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")
const AIDecisionTraceScript = preload("res://scripts/ai/AIDecisionTrace.gd")
const AIDecisionSampleExporterScript = preload("res://scripts/ai/AIDecisionSampleExporter.gd")

const MARNIE_DECK_ID := 800018501
const GARDEVOIR_DECK_ID := 800017097
const GARDEVOIR_STRATEGY_ID := "v18_800017097_no_balloon_gardevoir"
const OVERLAY_ID := "marnie_vs_no_balloon_gardevoir_froslass_pressure_v1"


func test_unique_public_fingerprint_activates_graph_overlay_and_bc_artifacts() -> String:
	var state := _state_with_gardevoir_fingerprint(true)
	var strategy: RefCounted = _marnie_strategy()
	var matchup_context: Dictionary = strategy.build_matchup_context(state, 0)
	var contract: Dictionary = strategy.apply_matchup_overlay_to_turn_contract(
		strategy.build_turn_contract(state, 0, {}),
		state,
		0,
		matchup_context
	)
	var ai := AIOpponentScript.new()
	ai.configure(0, 1)
	ai.set_deck_strategy(strategy)
	ai.matchup_policy_artifacts = {
		GARDEVOIR_STRATEGY_ID: {
			"action_scorer_path": "user://matchups/marnie_vs_gardevoir/action.json",
			"interaction_scorer_path": "user://matchups/marnie_vs_gardevoir/interaction.json",
		},
	}
	var artifacts: Dictionary = ai.resolve_matchup_policy_artifacts(state)
	var flags: Dictionary = contract.get("flags", {})
	var priorities: Dictionary = contract.get("priorities", {})
	return run_checks([
		assert_true(bool(matchup_context.get("is_unique", false)), "The public two-card witness should resolve uniquely"),
		assert_eq(str(matchup_context.get("opponent_strategy_id", "")), GARDEVOIR_STRATEGY_ID, "The shared context should expose the exact public strategy id"),
		assert_eq(str(contract.get("matchup_overlay_id", "")), OVERLAY_ID, "The Marnie Graph overlay should be attached to the turn contract"),
		assert_true(bool(flags.get("matchup_froslass_pressure", false)), "The overlay should expose its Froslass pressure guard"),
		assert_eq(str((priorities.get("evolve", []) as Array)[0]), "雪妖女", "Matchup priorities should put Froslass before the generic evolution route"),
		assert_true(bool(artifacts.get("active", false)), "The same unique fingerprint should activate matchup BC artifacts"),
		assert_eq(str(artifacts.get("action_scorer_path", "")), "user://matchups/marnie_vs_gardevoir/action.json", "The action scorer should use the exact matchup artifact"),
		assert_eq(str(artifacts.get("interaction_scorer_path", "")), "user://matchups/marnie_vs_gardevoir/interaction.json", "The interaction scorer should use the exact matchup artifact"),
	])


func test_ambiguous_public_fingerprint_fails_closed_to_generic_policy() -> String:
	var state := _state_with_gardevoir_fingerprint(false)
	var strategy: RefCounted = _marnie_strategy()
	var matchup_context: Dictionary = strategy.build_matchup_context(state, 0)
	var contract: Dictionary = strategy.apply_matchup_overlay_to_turn_contract(
		strategy.build_turn_contract(state, 0, {}),
		state,
		0,
		matchup_context
	)
	var ai := AIOpponentScript.new()
	ai.configure(0, 1)
	ai.set_deck_strategy(strategy)
	ai.matchup_policy_artifacts = {
		GARDEVOIR_STRATEGY_ID: {
			"action_scorer_path": "user://must_not_activate.json",
		},
	}
	var artifacts: Dictionary = ai.resolve_matchup_policy_artifacts(state)
	return run_checks([
		assert_false(bool(matchup_context.get("is_unique", false)), "One ambiguous witness card must not reveal an exact deck"),
		assert_eq(str(matchup_context.get("opponent_strategy_id", "leaked")), "", "Ambiguous contexts must blank exact identity"),
		assert_eq(str(contract.get("matchup_overlay_id", "")), "", "No Graph overlay may activate while identity is ambiguous"),
		assert_false(bool(artifacts.get("active", false)), "No matchup BC model may activate while identity is ambiguous"),
		assert_eq(str(artifacts.get("action_scorer_path", "")), "", "Ambiguous identity must fall back to the generic scorer path"),
	])


func test_marnie_matchup_delta_rewards_froslass_and_gardevoir_engine_targets() -> String:
	var state := _state_with_gardevoir_fingerprint(true)
	var strategy: RefCounted = _marnie_strategy()
	var matchup_context: Dictionary = strategy.build_matchup_context(state, 0)
	var snorunt := _card("雪童子", "Snorunt", "f6baf0c4c60ff47c7f836c1271f40cb3", 0)
	var froslass := _card("雪妖女", "Froslass", "f27a2982c03f5b49a68ec0a77a2d6e48", 0)
	var snorunt_slot := _slot(snorunt, 0)
	state.players[0].bench.append(snorunt_slot)
	var evolve_delta: float = strategy.score_matchup_action(
		{"kind": "evolve", "card": CardInstance.create(froslass, 0), "target_slot": snorunt_slot},
		state,
		0,
		matchup_context,
		{}
	)
	var kirlia := _card("奇鲁莉安", "Kirlia", "773a7c5bc165bd5d75321bc7c29fdd25", 1)
	var kirlia_slot := _slot(kirlia, 1)
	state.players[1].bench.append(kirlia_slot)
	var target_delta: float = strategy.score_matchup_interaction_target(
		kirlia_slot,
		{"id": "opponent_bench_target"},
		{"game_state": state, "player_index": 0},
		matchup_context
	)
	var unresolved := matchup_context.duplicate(true)
	unresolved["status"] = "ambiguous"
	unresolved["is_unique"] = false
	unresolved["opponent_strategy_id"] = ""
	var fallback_delta: float = strategy.score_matchup_action(
		{"kind": "evolve", "card": CardInstance.create(froslass, 0), "target_slot": snorunt_slot},
		state,
		0,
		unresolved,
		{}
	)
	return run_checks([
		assert_true(evolve_delta > 0.0, "The exact Gardevoir branch should reward establishing Froslass pressure"),
		assert_true(target_delta > 0.0, "The exact Gardevoir branch should prioritize gusting the visible Kirlia engine"),
		assert_eq(fallback_delta, 0.0, "The same action must receive no matchup delta when identity is unresolved"),
	])


func test_training_export_uses_public_identity_and_keeps_oracle_separate() -> String:
	var state := _state_with_gardevoir_fingerprint(true)
	var strategy: RefCounted = _marnie_strategy()
	var trace := AIDecisionTraceScript.new()
	trace.turn_number = 2
	trace.player_index = 0
	trace.strategy_id = strategy.get_strategy_id()
	trace.matchup_context = strategy.build_matchup_context(state, 0)
	trace.state_features = [0.1]
	trace.scored_actions = [{
		"kind": "end_turn",
		"score": 0.0,
		"features": {"action_vector": [1.0]},
	}]
	trace.chosen_action = trace.scored_actions[0]
	var exporter := AIDecisionSampleExporterScript.new()
	exporter.start_game({
		"run_id": "matchup_public_identity",
		"match_id": "matchup_public_identity",
		"deck_identity": str(MARNIE_DECK_ID),
		"opponent_deck_identity": str(GARDEVOIR_DECK_ID),
	})
	exporter.record_trace(trace)
	var record: Dictionary = exporter._records[0]
	return run_checks([
		assert_eq(str(record.get("deck_identity", "")), strategy.get_strategy_id(), "The acting strategy should label BC records, independent of seat metadata"),
		assert_eq(str(record.get("opponent_deck_identity", "")), GARDEVOIR_STRATEGY_ID, "The trainable opponent identity must come from the public fingerprint"),
		assert_eq(str(record.get("oracle_opponent_deck_identity", "")), str(GARDEVOIR_DECK_ID), "The true deck id should remain evaluation-only oracle metadata"),
		assert_true(bool(record.get("opponent_fingerprint_unique", false)), "The record should make public identity confidence auditable"),
	])


func _marnie_strategy() -> RefCounted:
	var deck := DeckData.new()
	deck.id = MARNIE_DECK_ID
	var strategy := MarnieStrategyScript.new()
	strategy.configure_from_deck(deck)
	return strategy


func _state_with_gardevoir_fingerprint(complete: bool) -> GameState:
	var state := GameState.new()
	var observer := PlayerState.new()
	observer.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	state.players = [observer, opponent]
	var fingerprint: Dictionary = ResolverScript.minimal_unique_fingerprint(GARDEVOIR_DECK_ID, 2)
	var evidence: Array = fingerprint.get("evidence", [])
	if not evidence.is_empty():
		opponent.active_pokemon = _slot(_card_from_evidence(evidence[0], 1), 1)
	if complete and evidence.size() > 1:
		opponent.bench.append(_slot(_card_from_evidence(evidence[1], 1), 1))
	return state


func _slot(card_data: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	return slot


func _card(name: String, name_en: String, effect_id: String, _owner_index: int) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name_en
	card.effect_id = effect_id
	card.card_type = "Pokemon"
	card.stage = "Stage 1"
	card.hp = 100
	return card


func _card_from_evidence(evidence: Dictionary, owner_index: int) -> CardData:
	var card := _card(
		str(evidence.get("name", evidence.get("display_name", "Fingerprint Card"))),
		str(evidence.get("name_en", evidence.get("display_name", ""))),
		str(evidence.get("effect_id", "")),
		owner_index
	)
	card.card_type = str(evidence.get("card_type", "Pokemon"))
	card.stage = "Basic" if card.card_type == "Pokemon" else ""
	var uid := str(evidence.get("uid", ""))
	var separator := uid.find("_")
	if separator > 0:
		card.set_code = uid.substr(0, separator)
		card.card_index = uid.substr(separator + 1)
	return card
