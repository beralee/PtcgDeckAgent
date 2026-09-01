class_name TestAuthorStrategyPackageRulesE2E
extends TestBase

const MARNIE_DECK_ID := 800018501
const RULES_AI_DECK_ID := 575720
const PACKAGE_ID := "ptcgdap.marnie.windows-local"
const PACKAGE_VERSION := "0.1.0"
const PACKAGE_ARCHIVE_SHA256 := "32E25453431886F76CEC606089ED4815EC681FBD33073F53A335A769D293643E"
const PackageAIScript = preload("res://tests/ptcgdap/godot/support/MarniePackageDevelopmentAIOpponent.gd")
const CatalogScript = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageCatalog.gd")
const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")
const AIBenchmarkRunnerScript = preload("res://scripts/ai/AIBenchmarkRunner.gd")
const DeckStrategyRegistryScript = preload("res://scripts/ai/DeckStrategyRegistry.gd")


func _rules_ai(seat: int, deck: DeckData) -> AIOpponent:
	var ai := AIOpponentScript.new()
	ai.configure(seat, 1)
	DeckStrategyRegistryScript.new().apply_strategy_for_deck(ai, deck)
	ai.use_mcts = false
	ai.decision_runtime_mode = AIOpponentScript.DECISION_RUNTIME_RULES_ONLY
	return ai


func _request_exact_handle() -> Dictionary:
	var catalog := CatalogScript.new()
	var report: Dictionary = catalog.scan_startup()
	var exact_record := {}
	for value: Variant in report.get("metadata_records", []):
		if (
			value is Dictionary
			and value.get("package_id") == PACKAGE_ID
			and value.get("package_version") == PACKAGE_VERSION
			and value.get("archive_sha256") == PACKAGE_ARCHIVE_SHA256
			and value.get("install_source") == "built_in"
		):
			exact_record = value
			break
	if exact_record.is_empty():
		catalog.free()
		return {"ok": false, "error_code": "exact_builtin_candidate_missing", "handle": null}
	var result: Dictionary = catalog.request_match_handle(
		PACKAGE_ID, PACKAGE_VERSION, PACKAGE_ARCHIVE_SHA256
	)
	catalog.free()
	return result


func test_exact_builtin_marnie_package_completes_real_rules_engine_game() -> String:
	var marnie: DeckData = CardDatabase.get_deck(MARNIE_DECK_ID)
	var rules_deck: DeckData = CardDatabase.get_deck(RULES_AI_DECK_ID)
	if marnie == null or rules_deck == null:
		return "required decks could not be loaded"
	var requested := _request_exact_handle()
	if not bool(requested.get("ok", false)):
		return "exact package handle failed: %s" % str(requested)
	var seed_owner := PlayerState.new()
	seed_owner.set_forced_shuffle_seed(84100)
	var gsm := GameStateMachine.new()
	if gsm.coin_flipper != null:
		var rng: Variant = gsm.coin_flipper.get("_rng")
		if rng is RandomNumberGenerator:
			(rng as RandomNumberGenerator).seed = 84100
	gsm.start_game(marnie, rules_deck, 0)
	var package_ai := PackageAIScript.new()
	package_ai.configure(0, 1)
	package_ai.use_mcts = false
	package_ai.decision_runtime_mode = AIOpponentScript.DECISION_RUNTIME_RULES_ONLY
	var bind: Dictionary = package_ai.bind_package_match(gsm, requested.get("handle"))
	if not bool(bind.get("ok", false)):
		seed_owner.clear_forced_shuffle_seed()
		gsm.prepare_for_disposal()
		return "package strategy bind failed: %s" % str(bind)
	var result: Dictionary = AIBenchmarkRunnerScript.new().run_headless_duel(
		package_ai,
		_rules_ai(1, rules_deck),
		gsm,
		600
	)
	var audit: Dictionary = package_ai.get_package_execution_audit()
	var serial_audit: Dictionary = audit.get("serial_registry", {})
	var checks := run_checks([
		assert_true(int(result.get("winner_index", -1)) in [0, 1], "real game must have a winner"),
		assert_true(str(result.get("failure_reason", "")) in ["normal_game_end", "deck_out"]),
		assert_false(bool(result.get("stalled", false))),
		assert_false(bool(result.get("terminated_by_cap", false))),
		assert_true(int(audit.get("policy_calls", 0)) > 0),
		assert_eq(audit.get("policy_calls"), audit.get("policy_successes")),
		assert_eq(audit.get("policy_calls"), audit.get("ir_execution_calls")),
		assert_eq(audit.get("policy_errors"), 0),
		assert_eq(audit.get("invalid_outputs"), 0),
		assert_eq(audit.get("fallbacks"), 0),
		assert_eq(audit.get("external_process_attempts"), 0),
		assert_true(int(audit.get("setup_calls", 0)) > 0),
		assert_true(int(audit.get("rule_baseline_comparisons", 0)) > 0),
		assert_true(int(audit.get("matched_rule_evaluations", 0)) > 0),
		assert_true(int(audit.get("macro_preferred_selections", 0)) > 0),
		assert_eq(audit.get("package_id"), PACKAGE_ID),
		assert_eq(audit.get("package_version"), PACKAGE_VERSION),
		assert_eq(audit.get("archive_sha256"), PACKAGE_ARCHIVE_SHA256),
		assert_true(audit.get("exact_builtin_sha_gate", false)),
		assert_eq(audit.get("card_id_domain"), "godot_local_card_uid_v1"),
		assert_eq(serial_audit.get("card_count"), 120),
		assert_eq(serial_audit.get("sealed_player_card_counts"), [60, 60]),
		assert_true(serial_audit.get("card_inventory_valid", false)),
		assert_false(audit.get("cabt_exportable", true)),
		assert_false(audit.get("execution_trusted", true)),
		assert_true(audit.get("development_execution_only", false)),
		assert_false(audit.get("player_runtime_authority", true)),
		assert_false(audit.get("classic_fallback_used", true)),
	])
	package_ai.close_package_match()
	seed_owner.clear_forced_shuffle_seed()
	gsm.prepare_for_disposal()
	return checks


func test_package_execution_projection_keeps_opponent_private_zones_out() -> String:
	var marnie: DeckData = CardDatabase.get_deck(MARNIE_DECK_ID)
	var rules_deck: DeckData = CardDatabase.get_deck(RULES_AI_DECK_ID)
	if marnie == null or rules_deck == null:
		return "required decks could not be loaded"
	var requested := _request_exact_handle()
	if not bool(requested.get("ok", false)):
		return "exact package handle failed: %s" % str(requested)
	var seed_owner := PlayerState.new()
	seed_owner.set_forced_shuffle_seed(84101)
	var gsm := GameStateMachine.new()
	gsm.start_game(rules_deck, marnie, 0)
	var package_ai := PackageAIScript.new()
	package_ai.configure(1, 1)
	var bind: Dictionary = package_ai.bind_package_match(gsm, requested.get("handle"))
	if not bool(bind.get("ok", false)):
		seed_owner.clear_forced_shuffle_seed()
		gsm.prepare_for_disposal()
		return "package strategy bind failed: %s" % str(bind)
	var state: Dictionary = package_ai.call("_build_public_state")
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
	package_ai.close_package_match()
	seed_owner.clear_forced_shuffle_seed()
	gsm.prepare_for_disposal()
	return checks


func test_package_development_gate_rejects_a_different_runtime_deck() -> String:
	var marnie: DeckData = CardDatabase.get_deck(MARNIE_DECK_ID)
	var rules_deck: DeckData = CardDatabase.get_deck(RULES_AI_DECK_ID)
	if marnie == null or rules_deck == null:
		return "required decks could not be loaded"
	var requested := _request_exact_handle()
	if not bool(requested.get("ok", false)):
		return "exact package handle failed: %s" % str(requested)
	var seed_owner := PlayerState.new()
	seed_owner.set_forced_shuffle_seed(84102)
	var gsm := GameStateMachine.new()
	gsm.start_game(rules_deck, marnie, 0)
	var package_ai := PackageAIScript.new()
	package_ai.configure(0, 1)
	var bind: Dictionary = package_ai.bind_package_match(gsm, requested.get("handle"))
	seed_owner.clear_forced_shuffle_seed()
	gsm.prepare_for_disposal()
	return run_checks([
		assert_false(bool(bind.get("ok", true))),
		assert_eq(bind.get("error_code"), "package_deck_inventory_mismatch"),
	])


func test_package_policy_rejects_a_stale_window_before_engine_execution() -> String:
	var marnie: DeckData = CardDatabase.get_deck(MARNIE_DECK_ID)
	var rules_deck: DeckData = CardDatabase.get_deck(RULES_AI_DECK_ID)
	if marnie == null or rules_deck == null:
		return "required decks could not be loaded"
	var requested := _request_exact_handle()
	if not bool(requested.get("ok", false)):
		return "exact package handle failed: %s" % str(requested)
	var seed_owner := PlayerState.new()
	seed_owner.set_forced_shuffle_seed(84103)
	var gsm := GameStateMachine.new()
	gsm.start_game(marnie, rules_deck, 0)
	var package_ai := PackageAIScript.new()
	package_ai.configure(0, 1)
	var bind: Dictionary = package_ai.bind_package_match(gsm, requested.get("handle"))
	if not bool(bind.get("ok", false)):
		seed_owner.clear_forced_shuffle_seed()
		gsm.prepare_for_disposal()
		return "package strategy bind failed: %s" % str(bind)
	var player: PlayerState = gsm.game_state.players[0]
	var option: Dictionary = package_ai.call("_build_option", 0, player.hand[0], "setup_active")
	var frame: Dictionary = package_ai.call("_build_frame", "setup_active", [option], 1, 1)
	frame["source"]["window_id"] = "A".repeat(64)
	var response: Dictionary = package_ai.call("_invoke_python", frame)
	var checks := run_checks([
		assert_false(bool(response.get("ok", true))),
		assert_eq(response.get("error_code"), "stale_development_frame"),
	])
	package_ai.close_package_match()
	seed_owner.clear_forced_shuffle_seed()
	gsm.prepare_for_disposal()
	return checks
