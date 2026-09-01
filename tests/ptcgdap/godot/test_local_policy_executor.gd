class_name TestLocalPolicyExecutor
extends TestBase

const MARNIE_DECK_ID := 800018501
const RULES_AI_DECK_ID := 575720
const PACKAGE_ID := "ptcgdap.marnie.windows-local"
const PACKAGE_VERSION := "0.1.0"
const PACKAGE_ARCHIVE_SHA256 := "32E25453431886F76CEC606089ED4815EC681FBD33073F53A335A769D293643E"
const EXPECTED_PARENT_MANIFEST_SHA256 := "3243ABD7937B3F53D8E5D7A887FC90BFBDF9A4D94E4030A3A9BE194C82370FFC"

const GateScript = preload("res://scripts/ai/ptcgdap/host/godot/AuthorStrategyWindowsDevelopmentGate.gd")
const CatalogScript = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageCatalog.gd")
const LocalExecutorScript = preload("res://scripts/ai/ptcgdap/runtime/local/LocalPolicyExecutor.gd")
const LocalManifestScript = preload("res://scripts/ai/ptcgdap/runtime/local/LocalPolicyExecutorManifest.gd")
const LocalOwnerScript = preload("res://scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorLocalExecutorBattleOwner.gd")
const LegacyOwnerScript = preload("res://scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorDevelopmentBattleOwner.gd")
const FactoryScript = preload("res://scripts/ui/battle/ai/BattleDecisionOwnerFactory.gd")
const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")
const HeadlessMatchBridgeScript = preload("res://scripts/ai/HeadlessMatchBridge.gd")
const DeckStrategyRegistryScript = preload("res://scripts/ai/DeckStrategyRegistry.gd")


func _selection() -> Dictionary:
	return {
		"package_id":PACKAGE_ID,
		"package_version":PACKAGE_VERSION,
		"archive_sha256":PACKAGE_ARCHIVE_SHA256,
		"install_source":"built_in",
	}


func _handle() -> Dictionary:
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var result: Dictionary = GateScript.request_match_handle(catalog, _selection(), "Windows")
	catalog.free()
	return result


func _rules_ai(seat: int, deck: DeckData) -> AIOpponent:
	var ai := AIOpponentScript.new()
	ai.configure(seat, 1)
	DeckStrategyRegistryScript.new().apply_strategy_for_deck(ai, deck)
	ai.use_mcts = false
	ai.decision_runtime_mode = AIOpponentScript.DECISION_RUNTIME_RULES_ONLY
	return ai


func test_manifest_is_fail_closed_and_d051_parent_is_unchanged() -> String:
	var requested := _handle()
	if not bool(requested.get("ok", false)):
		return "exact package handle failed: %s" % str(requested)
	var handle: Variant = requested.get("handle")
	var verified: Dictionary = LocalManifestScript.load_and_verify(handle)
	var document: Variant = JSON.parse_string(
		FileAccess.get_file_as_bytes(
			"res://data/ptcgdap/marnie_windows_local_policy_executor_v1.json"
		).get_string_from_utf8()
	)
	var tampered: Dictionary = document.duplicate(true)
	tampered["fallback"]["remote"] = true
	var rejected: Dictionary = LocalManifestScript.verify_document(tampered, handle)
	var near_integral: Variant = LocalManifestScript._coerce_integral_numbers(1.0000001)
	return run_checks([
		assert_true(bool(verified.get("accepted", false))),
		assert_eq(verified.get("executor_id"), "ptcgdap-local-policy-executor-v1"),
		assert_eq(
			verified.get("parent_policy_package", {}).get("manifest_canonical_sha256"),
			EXPECTED_PARENT_MANIFEST_SHA256
		),
		assert_eq(verified.get("learned_model"), "none"),
		assert_eq(verified.get("model_backend"), "none"),
		assert_false(bool(verified.get("production_ready", true))),
		assert_false(bool(rejected.get("accepted", true))),
		assert_eq(rejected.get("error_code"), "local_policy_executor_fallback_mismatch"),
		assert_eq(typeof(near_integral), TYPE_FLOAT),
		assert_eq(near_integral, 1.0000001),
	])


func test_factory_local_executor_completes_real_rules_game_and_legacy_owner_remains() -> String:
	var marnie: DeckData = CardDatabase.get_deck(MARNIE_DECK_ID)
	var rules_deck: DeckData = CardDatabase.get_deck(RULES_AI_DECK_ID)
	if marnie == null or rules_deck == null:
		return "required decks could not be loaded"
	var requested := _handle()
	if not bool(requested.get("ok", false)):
		return "exact package handle failed: %s" % str(requested)
	var seed_owner := PlayerState.new()
	seed_owner.set_forced_shuffle_seed(84800)
	var gsm := GameStateMachine.new()
	gsm.start_game(rules_deck, marnie, 0)
	var built: Dictionary = FactoryScript.build_windows_development_author_owner(
		requested.get("handle"), gsm, 1, "local-policy-executor-real-rules"
	)
	if not bool(built.get("ok", false)):
		seed_owner.clear_forced_shuffle_seed()
		gsm.prepare_for_disposal()
		return "local executor owner bind failed: %s" % str(built)
	var owner: Variant = built.get("owner")
	var policy: Variant = owner.get("_policy")
	var frame: Dictionary = owner.call(
		"_build_frame",
		"mulligan",
		[owner.call("_make_option", 0, null, "mulligan_extra_draw")],
		1,
		1
	)
	var valid_response: Dictionary = policy.select(frame)
	var private_frame: Dictionary = frame.duplicate(true)
	private_frame["callback"] = "forbidden"
	var private_response: Dictionary = policy.select(private_frame)
	var stale_frame: Dictionary = frame.duplicate(true)
	stale_frame["source"]["window_id"] = "A".repeat(64)
	var stale_response: Dictionary = policy.select(stale_frame)
	var rules_ai := _rules_ai(0, rules_deck)
	var bridge := HeadlessMatchBridgeScript.new()
	bridge.bind(gsm)
	bridge.set_ai_controllers(rules_ai, owner)
	bridge.bootstrap_pending_setup()
	var steps := 0
	var failure := ""
	while not gsm.game_state.is_game_over() and steps < 700:
		var progressed := false
		if bridge.has_pending_prompt():
			var prompt_owner := bridge.get_pending_prompt_owner()
			if prompt_owner == 1:
				progressed = bool(owner.run_single_step(bridge, gsm))
			elif bridge.can_resolve_pending_prompt():
				progressed = bridge.resolve_pending_prompt()
			else:
				progressed = rules_ai.run_single_step(bridge, gsm)
		else:
			progressed = bool(owner.run_single_step(bridge, gsm)) \
				if gsm.game_state.current_player_index == 1 else rules_ai.run_single_step(bridge, gsm)
		if not progressed:
			failure = "no_progress:%s" % bridge.get_pending_prompt_type()
			break
		steps += 1
	var audit: Dictionary = owner.audit_snapshot()
	var checks := run_checks([
		assert_eq(owner.get_script(), LocalOwnerScript),
		assert_true(owner is PtcgDAPAuthorDevelopmentBattleOwner),
		assert_eq(policy.get_script(), LocalExecutorScript),
		assert_true(bool(valid_response.get("ok", false))),
		assert_eq(valid_response.get("selected_indexes"), [0]),
		assert_eq(private_response.get("error_code"), "private_or_runtime_frame"),
		assert_eq(stale_response.get("error_code"), "stale_development_frame"),
		assert_eq(failure, ""),
		assert_true(gsm.game_state.is_game_over()),
		assert_true(steps < 700),
		assert_true(int(audit.get("policy_calls", 0)) > 0),
		assert_eq(audit.get("policy_calls"), audit.get("policy_successes")),
		assert_eq(audit.get("policy_errors"), 0),
		assert_eq(audit.get("invalid_outputs"), 0),
		assert_eq(audit.get("same_window_fallbacks"), 0),
		assert_eq(audit.get("classic_fallbacks"), 0),
		assert_true(int(audit.get("engine_commits", 0)) > 0),
		assert_eq(audit.get("local_policy_executor_id"), "ptcgdap-local-policy-executor-v1"),
		assert_eq(audit.get("portable_baseline"), "gdscript"),
		assert_eq(audit.get("policy_output"), "current_window_indexes_only"),
		assert_true(bool(audit.get("restricted_ir_executed", false))),
		assert_true(bool(audit.get("local_executor_runtime_authority", false))),
		assert_true(bool(audit.get("engine_commit_authority", false))),
		assert_false(bool(audit.get("policy_engine_object_access", true))),
		assert_false(bool(audit.get("production_ready", true))),
		assert_eq(built.get("policy_executor_kind"), "local_policy_executor_v1"),
	])
	owner.close_match()
	bridge.free()
	seed_owner.clear_forced_shuffle_seed()
	gsm.prepare_for_disposal()
	return checks
