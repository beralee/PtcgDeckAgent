class_name TestDragapultPythonPublicStrategyE2E
extends TestBase

const DRAGAPULT_DECK_ID := 800018499
const RULES_AI_DECK_ID := 575720
const PythonAIScript = preload("res://tests/ptcgdap/godot/support/DragapultPythonAIOpponent.gd")
const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")
const AIBenchmarkRunnerScript = preload("res://scripts/ai/AIBenchmarkRunner.gd")
const DeckStrategyRegistryScript = preload("res://scripts/ai/DeckStrategyRegistry.gd")


func _python_executable() -> String:
	var configured := OS.get_environment("PTCGDAP_PYTHON").strip_edges()
	return configured if not configured.is_empty() else "python"


func _rules_ai(seat: int, deck: DeckData) -> AIOpponent:
	var ai := AIOpponentScript.new()
	ai.configure(seat, 1)
	DeckStrategyRegistryScript.new().apply_strategy_for_deck(ai, deck)
	ai.use_mcts = false
	ai.decision_runtime_mode = AIOpponentScript.DECISION_RUNTIME_RULES_ONLY
	return ai


func test_public_python_strategy_completes_one_real_engine_game_without_invalid_output() -> String:
	var dragapult: DeckData = CardDatabase.get_deck(DRAGAPULT_DECK_ID)
	var rules_deck: DeckData = CardDatabase.get_deck(RULES_AI_DECK_ID)
	if dragapult == null or rules_deck == null:
		return "required decks could not be loaded"
	var seed_owner := PlayerState.new()
	seed_owner.set_forced_shuffle_seed(83100)
	var gsm := GameStateMachine.new()
	if gsm.coin_flipper != null:
		var rng: Variant = gsm.coin_flipper.get("_rng")
		if rng is RandomNumberGenerator:
			(rng as RandomNumberGenerator).seed = 83100
	gsm.start_game(dragapult, rules_deck, 0)
	var public_ai := PythonAIScript.new()
	public_ai.configure(0, 1)
	public_ai.use_mcts = false
	public_ai.decision_runtime_mode = AIOpponentScript.DECISION_RUNTIME_RULES_ONLY
	var bind: Dictionary = public_ai.bind_public_match(gsm, _python_executable())
	if not bool(bind.get("ok", false)):
		seed_owner.clear_forced_shuffle_seed()
		return "public strategy bind failed: %s" % str(bind)
	var result: Dictionary = AIBenchmarkRunnerScript.new().run_headless_duel(
		public_ai,
		_rules_ai(1, rules_deck),
		gsm,
		600
	)
	var audit: Dictionary = public_ai.get_public_strategy_audit()
	var serial_audit: Dictionary = audit.get("serial_registry", {})
	var checks := run_checks([
		assert_true(int(result.get("winner_index", -1)) in [0, 1], "real game must have a winner"),
		assert_true(str(result.get("failure_reason", "")) in ["normal_game_end", "deck_out"]),
		assert_false(bool(result.get("stalled", false))),
		assert_false(bool(result.get("terminated_by_cap", false))),
		assert_true(int(audit.get("python_calls", 0)) > 0),
		assert_eq(audit.get("python_calls"), audit.get("python_successes")),
		assert_eq(audit.get("python_errors"), 0),
		assert_eq(audit.get("python_timeouts"), 0),
		assert_eq(audit.get("invalid_outputs"), 0),
		assert_eq(audit.get("fallbacks"), 0),
		assert_true(int(audit.get("setup_calls", 0)) > 0),
		assert_true(int(audit.get("rule_baseline_comparisons", 0)) > 0),
		assert_eq(audit.get("rule_baseline_unavailable"), 0),
		assert_false((audit.get("first_rule_divergence", {}) as Dictionary).is_empty()),
		assert_eq(serial_audit.get("card_count"), 120),
		assert_eq(serial_audit.get("sealed_player_card_counts"), [60, 60]),
		assert_true(serial_audit.get("card_inventory_valid", false)),
		assert_eq(audit.get("card_id_domain"), "godot_local_card_uid_v1"),
		assert_false(audit.get("cabt_exportable", true)),
		assert_false(audit.get("player_runtime_python_dependency", true)),
	])
	public_ai.close_public_match()
	seed_owner.clear_forced_shuffle_seed()
	gsm.prepare_for_disposal()
	return checks


func test_public_projection_exposes_no_opponent_hand_identity_or_deck_order() -> String:
	var dragapult: DeckData = CardDatabase.get_deck(DRAGAPULT_DECK_ID)
	var rules_deck: DeckData = CardDatabase.get_deck(RULES_AI_DECK_ID)
	if dragapult == null or rules_deck == null:
		return "required decks could not be loaded"
	var seed_owner := PlayerState.new()
	seed_owner.set_forced_shuffle_seed(83101)
	var gsm := GameStateMachine.new()
	gsm.start_game(rules_deck, dragapult, 0)
	var public_ai := PythonAIScript.new()
	public_ai.configure(1, 1)
	var bind: Dictionary = public_ai.bind_public_match(gsm, _python_executable())
	if not bool(bind.get("ok", false)):
		seed_owner.clear_forced_shuffle_seed()
		return "public strategy bind failed: %s" % str(bind)
	var state: Dictionary = public_ai.call("_build_public_state")
	var opponent: Dictionary = state.get("opponent", {})
	var serialized := JSON.stringify(state).to_lower()
	var checks := run_checks([
		assert_true(opponent.has("hand_count")),
		assert_false(opponent.has("hand")),
		assert_false("deck_order" in serialized),
		assert_false("instance_id" in serialized),
		assert_false("object_ref" in serialized),
		assert_false("official_card_id" in serialized),
		assert_true("local_card_uid" in serialized),
	])
	public_ai.close_public_match()
	seed_owner.clear_forced_shuffle_seed()
	gsm.prepare_for_disposal()
	return checks
