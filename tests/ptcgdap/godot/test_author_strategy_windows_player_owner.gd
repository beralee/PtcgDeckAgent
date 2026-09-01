class_name TestAuthorStrategyWindowsPlayerOwner
extends TestBase

const MARNIE_DECK_ID := 800018501
const RULES_AI_DECK_ID := 575720
const PACKAGE_ID := "ptcgdap.marnie.windows-local"
const PACKAGE_VERSION := "0.1.0"
const PACKAGE_ARCHIVE_SHA256 := "32E25453431886F76CEC606089ED4815EC681FBD33073F53A335A769D293643E"
const CYNTHIA_DECK_ID := 800018543
const CYNTHIA_PACKAGE_ID := "ptcgdap.cynthia-garchomp-800018543.windows-local"
const CYNTHIA_PACKAGE_VERSION := "0.1.0"
const CYNTHIA_ARCHIVE_SHA256 := "3059C308904B323AF5CA10B1956EF8BB35F77A1174CF0AD0258F1A70A128FF06"
const GIFT_BOX_PACKAGE_ID := "dev.bodao-yongzhe.marnies-gift-box"
const GIFT_BOX_PACKAGE_VERSION := "1.9.0"
const GIFT_BOX_ARCHIVE_SHA256 := "BDC7C0969D6F4A4F5CC94C480E3CE2C19F4C2542AB1902C16DEC51AE1333DB20"
const GateScript = preload("res://scripts/ai/ptcgdap/host/godot/AuthorStrategyWindowsDevelopmentGate.gd")
const DeviceCanaryGateScript = preload("res://scripts/ai/ptcgdap/host/godot/AuthorStrategyWindowsDeviceCanaryGate.gd")
const ExecutionGateScript = preload("res://scripts/ai/ptcgdap/host/godot/AuthorStrategyWindowsExecutionGate.gd")
const OwnerScript = preload("res://scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorDevelopmentBattleOwner.gd")
const CatalogScript = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageCatalog.gd")
const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")
const HeadlessMatchBridgeScript = preload("res://scripts/ai/HeadlessMatchBridge.gd")
const DeckStrategyRegistryScript = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const BattleSceneScript = preload("res://scenes/battle/BattleScene.gd")
const BattleSceneScene = preload("res://scenes/battle/BattleScene.tscn")
const BattleSetupScene = preload("res://scenes/battle_setup/BattleSetup.tscn")
const BattleDecisionOwnerFactoryScript = preload("res://scripts/ui/battle/ai/BattleDecisionOwnerFactory.gd")
const AuthorStrategyFeatureGateScript = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyFeatureGate.gd")
const PackageLoaderScript = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageLoader.gd")
const PackageHandleScript = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageHandle.gd")
const PackageDeckGateScript = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyDeckGate.gd")
const CONTROL_PLAYER_FIXTURE := "res://data/ptcgdap/author_strategy_package_backups/reviewed-raging-bolt-ogerpon-1.0.0-round30-20ED94DE.ptcgai"
const AuthorPublicReplayCoordinatorScript = preload(
	"res://scripts/ui/battle/author_strategy/AuthorStrategyPublicReplayCoordinator.gd"
)


class StaleWindowPolicy extends RefCounted:
	var calls := 0

	func select(frame: Dictionary) -> Dictionary:
		calls += 1
		var source: Dictionary = frame.get("source", {})
		return {
			"ok": true,
			"error_code": "",
			"selected_indexes": [0],
			"selection_source": "restricted_ir_same_window",
			"public_observation_hash": "A".repeat(64) if calls == 1 else source.get("public_observation_hash"),
			"window_id": source.get("window_id") if calls == 1 else "B".repeat(64),
		}

	func audit_snapshot() -> Dictionary:
		return {}


class OptionalOutputPolicy extends RefCounted:
	var selected_output: Variant = null

	func _init(next_output: Variant) -> void:
		selected_output = next_output

	func select(frame: Dictionary) -> Dictionary:
		var source: Dictionary = frame.get("source", {})
		return {
			"ok": true,
			"error_code": "",
			"selected_indexes": selected_output,
			"selection_source": "restricted_ir_same_window",
			"public_observation_hash": source.get("public_observation_hash"),
			"window_id": source.get("window_id"),
		}

	func audit_snapshot() -> Dictionary:
		return {}


class SlowSameWindowPolicy extends RefCounted:
	var delay_msec := 160
	var calls := 0

	func select(frame: Dictionary) -> Dictionary:
		calls += 1
		OS.delay_msec(delay_msec)
		var source: Dictionary = frame.get("source", {})
		return {
			"ok": true,
			"error_code": "",
			"selected_indexes": [0],
			"selection_source": "restricted_ir_same_window",
			"public_observation_hash": source.get("public_observation_hash"),
			"window_id": source.get("window_id"),
		}

	func audit_snapshot() -> Dictionary:
		return {"selection_calls": calls}


class SlowModelActor extends RefCounted:
	var delay_msec := 160
	var calls := 0

	func decide_development_frame(
		_frame: Dictionary, rule_indexes: Array, _eligible_indexes: Array = []
	) -> Dictionary:
		calls += 1
		OS.delay_msec(delay_msec)
		return {
			"selected_indexes": rule_indexes.duplicate(),
			"model_used": true,
			"diagnostic_code": "",
			"elapsed_us": delay_msec * 1000,
			"model_manifest_sha256": "A".repeat(64),
			"model_artifact_sha256": "B".repeat(64),
		}


func _exact_selection() -> Dictionary:
	return {
		"package_id": PACKAGE_ID,
		"package_version": PACKAGE_VERSION,
		"archive_sha256": PACKAGE_ARCHIVE_SHA256,
		"install_source": "built_in",
	}


func _request_exact_handle() -> Dictionary:
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var result: Dictionary = GateScript.request_match_handle(catalog, _exact_selection(), "Windows")
	catalog.free()
	return result


func _cynthia_selection() -> Dictionary:
	return {
		"package_id": CYNTHIA_PACKAGE_ID,
		"package_version": CYNTHIA_PACKAGE_VERSION,
		"archive_sha256": CYNTHIA_ARCHIVE_SHA256,
		"install_source": "built_in",
	}


func _request_cynthia_handle() -> Dictionary:
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var result: Dictionary = GateScript.request_match_handle(
		catalog, _cynthia_selection(), "Windows"
	)
	catalog.free()
	return result


func _gift_box_selection() -> Dictionary:
	return {
		"package_id": GIFT_BOX_PACKAGE_ID,
		"package_version": GIFT_BOX_PACKAGE_VERSION,
		"archive_sha256": GIFT_BOX_ARCHIVE_SHA256,
		"install_source": "built_in",
	}


func _request_gift_box_handle() -> Dictionary:
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var result: Dictionary = GateScript.request_match_handle(
		catalog, _gift_box_selection(), "Windows"
	)
	catalog.free()
	return result


func _deck_uid_counts(deck: DeckData) -> Dictionary:
	var counts := {}
	if deck == null:
		return counts
	for row: Dictionary in deck.cards:
		counts["%s_%s" % [str(row.get("set_code", "")), str(row.get("card_index", ""))]] = int(
			row.get("count", 0)
		)
	return counts


func _handle_uid_counts(handle: Variant) -> Dictionary:
	var counts := {}
	if handle == null or not handle.has_method("local_deck_snapshot"):
		return counts
	for row_value: Variant in handle.local_deck_snapshot():
		if row_value is Dictionary:
			var row: Dictionary = row_value
			counts[str(row.get("local_card_uid", ""))] = int(row.get("count", 0))
	return counts


func _rules_ai(seat: int, deck: DeckData) -> AIOpponent:
	var ai := AIOpponentScript.new()
	ai.configure(seat, 1)
	DeckStrategyRegistryScript.new().apply_strategy_for_deck(ai, deck)
	ai.use_mcts = false
	ai.decision_runtime_mode = AIOpponentScript.DECISION_RUNTIME_RULES_ONLY
	return ai


func test_windows_development_gate_accepts_only_exact_builtin_marnie_archive() -> String:
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var exact: Dictionary = GateScript.evaluate_selection(_exact_selection(), "Windows")
	var wrong_sha := _exact_selection()
	wrong_sha["archive_sha256"] = "A".repeat(64)
	var user_copy := _exact_selection()
	user_copy["install_source"] = "user"
	var android: Dictionary = GateScript.evaluate_selection(_exact_selection(), "Android")
	var production_attempt: Dictionary = catalog.request_ready_match_handle(
		PACKAGE_ID, PACKAGE_VERSION, PACKAGE_ARCHIVE_SHA256
	)
	catalog.free()
	return run_checks([
		assert_true(bool(exact.get("ok", false))),
		assert_eq(exact.get("source_deck_id"), MARNIE_DECK_ID),
		assert_true(bool(exact.get("development_execution_only", false))),
		assert_false(bool(exact.get("production_ready", true))),
		assert_eq(GateScript.evaluate_selection(wrong_sha, "Windows").get("error_code"), "development_candidate_not_authorized"),
		assert_eq(GateScript.evaluate_selection(user_copy, "Windows").get("error_code"), "development_candidate_not_authorized"),
		assert_eq(android.get("error_code"), "development_platform_not_authorized"),
		assert_eq(production_attempt.get("error_code"), "package_release_not_approved"),
	])


func test_windows_development_gate_accepts_exact_builtin_cynthia_without_promoting_trust() -> String:
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var exact: Dictionary = GateScript.evaluate_selection(_cynthia_selection(), "Windows")
	var wrong_sha := _cynthia_selection()
	wrong_sha["archive_sha256"] = "A".repeat(64)
	var user_copy := _cynthia_selection()
	user_copy["install_source"] = "user"
	var android: Dictionary = GateScript.evaluate_selection(_cynthia_selection(), "Android")
	var production_attempt: Dictionary = catalog.request_ready_match_handle(
		CYNTHIA_PACKAGE_ID, CYNTHIA_PACKAGE_VERSION, CYNTHIA_ARCHIVE_SHA256
	)
	catalog.free()
	return run_checks([
		assert_true(bool(exact.get("ok", false))),
		assert_eq(exact.get("source_deck_id"), CYNTHIA_DECK_ID),
		assert_true(bool(exact.get("development_execution_only", false))),
		assert_false(bool(exact.get("production_ready", true))),
		assert_eq(GateScript.evaluate_selection(wrong_sha, "Windows").get("error_code"), "development_candidate_not_authorized"),
		assert_eq(GateScript.evaluate_selection(user_copy, "Windows").get("error_code"), "development_candidate_not_authorized"),
		assert_eq(android.get("error_code"), "development_platform_not_authorized"),
		assert_eq(production_attempt.get("error_code"), "package_release_not_approved"),
	])


func test_exact_cynthia_package_owner_completes_real_rules_game_without_classic_fallback() -> String:
	var cynthia: DeckData = CardDatabase.get_deck(CYNTHIA_DECK_ID)
	var rules_deck: DeckData = CardDatabase.get_deck(RULES_AI_DECK_ID)
	if cynthia == null or rules_deck == null:
		return "Cynthia development decks could not be loaded"
	var requested := _request_cynthia_handle()
	if not bool(requested.get("ok", false)):
		return "Cynthia package handle failed: %s" % str(requested)
	var seed_owner := PlayerState.new()
	seed_owner.set_forced_shuffle_seed(84590)
	var gsm := GameStateMachine.new()
	gsm.start_game(rules_deck, cynthia, 0)
	var built: Dictionary = BattleDecisionOwnerFactoryScript.build_windows_development_author_owner(
		requested.get("handle"), gsm, 1, "cynthia-windows-player-owner-e2e"
	)
	if not bool(built.get("ok", false)):
		seed_owner.clear_forced_shuffle_seed()
		gsm.prepare_for_disposal()
		return "Cynthia author owner bind failed: %s" % str(built)
	var owner: Variant = built.get("owner")
	var rules_ai := _rules_ai(0, rules_deck)
	var bridge := HeadlessMatchBridgeScript.new()
	bridge.bind(gsm)
	bridge.set_ai_controllers(rules_ai, owner)
	bridge.bootstrap_pending_setup()
	var replay_coordinator: Node = AuthorPublicReplayCoordinatorScript.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(replay_coordinator)
	var replay_started: Dictionary = replay_coordinator.start(owner, {
		"storage_namespace": "cynthia-real-owner-%d" % Time.get_ticks_usec(),
		"bearer_token": "",
	})
	var steps := 0
	var failure := ""
	var replay_failure := ""
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
			var current := gsm.game_state.current_player_index
			progressed = bool(owner.run_single_step(bridge, gsm)) if current == 1 else rules_ai.run_single_step(bridge, gsm)
		if not progressed:
			failure = "no progress at step %d prompt=%s" % [steps, bridge.get_pending_prompt_type()]
			break
		var replay_progress: Dictionary = replay_coordinator.record_progress(owner)
		if not bool(replay_progress.get("accepted", false)):
			replay_failure = str(replay_progress.get("error_code", "live_replay_progress_failed"))
			break
		steps += 1
	var replay_finished: Dictionary = replay_coordinator.finish(owner) \
		if gsm.game_state.is_game_over() and replay_failure.is_empty() else {}
	var replay_artifact: Dictionary = replay_coordinator.completed_artifact()
	var replay_frames: Array = replay_artifact.get("frames", [])
	var replay_audit: Dictionary = replay_coordinator.audit_snapshot()
	var audit: Dictionary = owner.audit_snapshot()
	print("PTCGDAP_CYNTHIA_DEVELOPMENT_EXECUTION=" + JSON.stringify({
		"seed":84590,
		"steps":steps,
		"game_over":gsm.game_state.is_game_over(),
		"winner_index":gsm.game_state.winner_index,
		"policy_calls":audit.get("policy_calls"),
		"policy_successes":audit.get("policy_successes"),
		"policy_errors":audit.get("policy_errors"),
		"last_error_code":audit.get("last_error_code"),
		"invalid_outputs":audit.get("invalid_outputs"),
		"classic_fallbacks":audit.get("classic_fallbacks"),
		"same_window_fallbacks":audit.get("same_window_fallbacks"),
		"engine_commits":audit.get("engine_commits"),
		"engine_rejections":audit.get("engine_rejections"),
		"matched_rule_counts":audit.get("matched_rule_counts"),
	}))
	var checks := run_checks([
		assert_eq(built.get("owner_kind"), "author_windows_development"),
		assert_eq(built.get("policy_executor_kind"), "restricted_policy_ir_v1"),
		assert_eq(failure, ""),
		assert_true(bool(replay_started.get("accepted", false)), str(replay_started)),
		assert_eq(replay_failure, ""),
		assert_true(bool(replay_finished.get("accepted", false)), str(replay_finished)),
		assert_true(bool(replay_audit.get("local_saved", false))),
		assert_true(replay_frames.size() > 2),
		assert_eq(replay_frames[-1].get("event_kind") if not replay_frames.is_empty() else "", "match_finished"),
		assert_false(bool(replay_audit.get("private_replay_used", true))),
		assert_true(gsm.game_state.is_game_over(), "Cynthia real rules game must terminate"),
		assert_true(steps < 700),
		assert_true(int(audit.get("policy_calls", 0)) > 0),
		assert_eq(audit.get("policy_calls"), audit.get("policy_successes")),
		assert_eq(audit.get("policy_errors"), 0),
		assert_eq(audit.get("invalid_outputs"), 0),
		assert_eq(audit.get("classic_fallbacks"), 0),
		assert_eq(audit.get("engine_rejections"), 0),
		assert_true(int(audit.get("engine_commits", 0)) > 0),
		assert_true(bool(audit.get("development_player_authority", false))),
		assert_false(bool(audit.get("production_ready", true))),
		assert_false(bool(audit.get("execution_trusted", true))),
		assert_eq(audit.get("package_id"), CYNTHIA_PACKAGE_ID),
	])
	tree.root.remove_child(replay_coordinator)
	replay_coordinator.free()
	owner.close_match()
	bridge.free()
	seed_owner.clear_forced_shuffle_seed()
	gsm.prepare_for_disposal()
	return checks


func test_production_device_canary_is_explicit_exclusive_and_unprovisioned() -> String:
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var development: Dictionary = ExecutionGateScript.evaluate_selection(
		catalog, _exact_selection(), "Windows", PackedStringArray(), true, false
	)
	var canary_args := PackedStringArray([DeviceCanaryGateScript.ACTIVATION_ARG])
	var canary: Dictionary = ExecutionGateScript.evaluate_selection(
		catalog, _exact_selection(), "Windows", canary_args, true, false
	)
	var conflict := PackedStringArray([
		DeviceCanaryGateScript.ACTIVATION_ARG,
		DeviceCanaryGateScript.DEVELOPMENT_UI_ARG,
	])
	var conflicted: Dictionary = ExecutionGateScript.evaluate_selection(
		catalog, _exact_selection(), "Windows", conflict, true, false
	)
	catalog.free()
	return run_checks([
		assert_true(bool(development.get("ok", false))),
		assert_eq(development.get("authority_mode"), ExecutionGateScript.DEVELOPMENT_MODE),
		assert_false(bool(canary.get("ok", true))),
		assert_eq(canary.get("authority_mode"), ExecutionGateScript.DEVICE_CANARY_MODE),
		assert_true(not str(canary.get("error_code", "")).is_empty()),
		assert_false(bool(canary.get("player_start_allowed", true))),
		assert_eq(conflicted.get("error_code"), "device_canary_activation_invalid"),
		assert_eq(conflicted.get("authority_mode"), ExecutionGateScript.DEVICE_CANARY_MODE),
	])


func test_control_distributed_player_package_binds_the_reviewed_local_battle_owner() -> String:
	var archive_bytes := FileAccess.get_file_as_bytes(CONTROL_PLAYER_FIXTURE)
	var hash_context := HashingContext.new()
	hash_context.start(HashingContext.HASH_SHA256)
	hash_context.update(archive_bytes)
	var archive_sha := hash_context.finish().hex_encode().to_upper()
	var loader := PackageLoaderScript.new()
	var inspected: Dictionary = loader.call(
		"inspect_control_distributed_player_match_bytes", archive_bytes, archive_sha
	)
	if not bool(inspected.get("ok", false)):
		return "Control fixture failed inspection: %s" % str(inspected)
	var deck_gate: Dictionary = PackageDeckGateScript.build(inspected.get("payloads", {}))
	if not bool(deck_gate.get("ok", false)):
		return "Control fixture failed local deck mapping: %s" % str(deck_gate)
	var created: Dictionary = PackageHandleScript.create(
		inspected.get("metadata", {}),
		inspected.get("payloads", {}),
		deck_gate.get("local_deck", [])
	)
	if not bool(created.get("ok", false)):
		return "Control fixture handle failed: %s" % str(created)
	var handle: Variant = created.get("handle")
	var materialized: Dictionary = GameManager.materialize_author_strategy_battle_deck(handle)
	var author_deck := materialized.get("deck") as DeckData
	var rules_deck: DeckData = CardDatabase.get_deck(RULES_AI_DECK_ID)
	if not bool(materialized.get("ok", false)) or author_deck == null or rules_deck == null:
		return "Control fixture deck materialization failed: %s" % str(materialized)
	var gsm := GameStateMachine.new()
	gsm.start_game(rules_deck, author_deck, 0, false, true)
	var built: Dictionary = BattleDecisionOwnerFactoryScript.build_windows_author_owner(
		handle,
		gsm,
		1,
		"control-distributed-player-owner",
		ExecutionGateScript.CONTROL_DISTRIBUTED_MODE
	)
	var owner: Variant = built.get("owner")
	var checks := run_checks([
		assert_true(bool(built.get("ok", false)), str(built)),
		assert_eq(built.get("owner_kind"), "author_control_distributed_player"),
		assert_true(owner != null and owner.validate_integrity()),
		assert_true(bool(built.get("control_distributed_player_authority", false))),
		assert_false(bool(built.get("development_execution_only", true))),
		assert_eq(
			owner.audit_snapshot().get("authority_mode") if owner != null else "",
			ExecutionGateScript.CONTROL_DISTRIBUTED_MODE
		),
	])
	if owner != null:
		owner.close_match()
	gsm.prepare_for_disposal()
	return checks


func test_author_player_owner_is_not_an_aiopponent_and_completes_real_rules_game() -> String:
	var marnie: DeckData = CardDatabase.get_deck(MARNIE_DECK_ID)
	var rules_deck: DeckData = CardDatabase.get_deck(RULES_AI_DECK_ID)
	if marnie == null or rules_deck == null:
		return "required decks could not be loaded"
	var requested := _request_exact_handle()
	if not bool(requested.get("ok", false)):
		return "exact package handle failed: %s" % str(requested)
	var seed_owner := PlayerState.new()
	seed_owner.set_forced_shuffle_seed(84801)
	var gsm := GameStateMachine.new()
	gsm.start_game(rules_deck, marnie, 0)
	var built: Dictionary = OwnerScript.create(requested.get("handle"), gsm, 1, "windows-player-owner-e2e")
	if not bool(built.get("ok", false)):
		seed_owner.clear_forced_shuffle_seed()
		gsm.prepare_for_disposal()
		return "author owner bind failed: %s" % str(built)
	var owner: Variant = built.get("owner")
	var rules_ai := _rules_ai(0, rules_deck)
	var bridge := HeadlessMatchBridgeScript.new()
	bridge.bind(gsm)
	bridge.set_ai_controllers(rules_ai, owner)
	bridge.bootstrap_pending_setup()
	var send_out_probe := {"transitions": 0, "stale": false}
	gsm.action_logged.connect(func(action: GameAction) -> void:
		if action.player_index == 1 \
			and action.action_type == GameAction.ActionType.SEND_OUT \
			and str(bridge.get("_pending_choice")) == "send_out":
			send_out_probe.transitions = int(send_out_probe.transitions) + 1
			send_out_probe.stale = true
	)
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
			var current := gsm.game_state.current_player_index
			progressed = bool(owner.run_single_step(bridge, gsm)) if current == 1 else rules_ai.run_single_step(bridge, gsm)
		if not progressed:
			failure = "no progress at step %d prompt=%s" % [steps, bridge.get_pending_prompt_type()]
			break
		steps += 1
	var audit: Dictionary = owner.audit_snapshot()
	var legal_builder: Variant = owner.get("_legal_action_builder")
	var checks := run_checks([
		assert_false(owner is AIOpponent, "author owner must not inherit the legacy AI owner"),
		assert_eq(owner.get_script(), OwnerScript),
		assert_eq(failure, ""),
		assert_true(gsm.game_state.is_game_over(), "real rules game must terminate"),
		assert_true(steps < 700),
		assert_true(int(audit.get("policy_calls", 0)) > 0),
		assert_true(int((audit.get("prompt_counts", {}) as Dictionary).get("send_out", 0)) > 0, "fixture must exercise send_out"),
		assert_eq(int(send_out_probe.transitions), 0, "send_out prompt must be invalidated before synchronous state transition"),
		assert_false(bool(send_out_probe.stale), "no state callback may observe a consumed send_out prompt"),
		assert_eq(audit.get("policy_calls"), audit.get("policy_successes")),
		assert_true(audit.get("decision_elapsed_usec") is Array),
		assert_eq((audit.get("decision_elapsed_usec", []) as Array).size(), audit.get("policy_calls")),
		assert_true((audit.get("decision_elapsed_usec", []) as Array).all(
			func(value: Variant) -> bool: return typeof(value) == TYPE_INT and int(value) >= 0
		)),
		assert_eq(audit.get("policy_errors"), 0),
		assert_eq(audit.get("invalid_outputs"), 0),
		assert_eq(audit.get("classic_fallbacks"), 0),
		assert_false(bool(audit.get("legacy_deck_strategy_preferences", true))),
		assert_true(bool(legal_builder.get("_deck_strategy_detected"))),
		assert_null(legal_builder.get("_deck_strategy")),
		assert_eq(audit.get("external_process_attempts"), 0),
		assert_true(int(audit.get("engine_commits", 0)) > 0),
		assert_true(bool(audit.get("development_player_authority", false))),
		assert_false(bool(audit.get("production_ready", true))),
	])
	owner.close_match()
	bridge.free()
	seed_owner.clear_forced_shuffle_seed()
	gsm.prepare_for_disposal()
	return checks


func test_author_owner_rejects_stale_policy_observation_and_window_hashes() -> String:
	var requested := _request_exact_handle()
	if not bool(requested.get("ok", false)):
		return "exact package handle failed: %s" % str(requested)
	var seed_owner := PlayerState.new()
	seed_owner.set_forced_shuffle_seed(84310)
	var gsm := GameStateMachine.new()
	gsm.start_game(CardDatabase.get_deck(MARNIE_DECK_ID), CardDatabase.get_deck(RULES_AI_DECK_ID), 0)
	var built: Dictionary = OwnerScript.create(
		requested.get("handle"), gsm, 0, "stale-window-policy-response"
	)
	if not bool(built.get("ok", false)):
		seed_owner.clear_forced_shuffle_seed()
		gsm.prepare_for_disposal()
		return "author owner bind failed: %s" % str(built)
	var owner: Variant = built.get("owner")
	var stale_policy := StaleWindowPolicy.new()
	owner.set("_policy", stale_policy)
	var options: Array = owner.call("_options_for_items", [
		{"kind": "play_trainer"},
		{"kind": "end_turn"},
	], "")
	var observation_drift: Array = owner.call("_select_items", "main", options, 1, 1)
	var window_drift: Array = owner.call("_select_items", "main", options, 1, 1)
	var audit: Dictionary = owner.audit_snapshot()
	var checks := run_checks([
		assert_eq(observation_drift, [1], "observation drift must use same-window end-turn fallback"),
		assert_eq(window_drift, [1], "window drift must use same-window end-turn fallback"),
		assert_eq(audit.get("policy_errors"), 2),
		assert_eq(audit.get("same_window_fallbacks"), 2),
		assert_eq(audit.get("last_error_code"), "stale_policy_response"),
		assert_eq(audit.get("engine_commits"), 0),
		assert_eq(audit.get("engine_rejections"), 0),
	])
	owner.close_match()
	seed_owner.clear_forced_shuffle_seed()
	gsm.prepare_for_disposal()
	return checks


func test_author_owner_distinguishes_valid_optional_empty_from_invalid_output() -> String:
	var requested := _request_exact_handle()
	if not bool(requested.get("ok", false)):
		return "exact package handle failed: %s" % str(requested)
	var seed_owner := PlayerState.new()
	seed_owner.set_forced_shuffle_seed(84311)
	var gsm := GameStateMachine.new()
	gsm.start_game(CardDatabase.get_deck(MARNIE_DECK_ID), CardDatabase.get_deck(RULES_AI_DECK_ID), 0)
	var built: Dictionary = OwnerScript.create(
		requested.get("handle"), gsm, 0, "optional-zero-policy-output"
	)
	if not bool(built.get("ok", false)):
		seed_owner.clear_forced_shuffle_seed()
		gsm.prepare_for_disposal()
		return "author owner bind failed: %s" % str(built)
	var owner: Variant = built.get("owner")
	var options: Array = owner.call("_options_for_items", [{"kind": "effect_target"}], "")
	owner.set("_policy", OptionalOutputPolicy.new("not-an-index-array"))
	var invalid_selection: Array = owner.call("_select_items", "effect_target", options, 0, 1)
	var invalid_audit: Dictionary = owner.audit_snapshot()
	owner.set("_policy", OptionalOutputPolicy.new([]))
	var valid_empty_selection: Array = owner.call("_select_items", "effect_target", options, 0, 1)
	var valid_audit: Dictionary = owner.audit_snapshot()
	var checks := run_checks([
		assert_eq(invalid_selection, [], "invalid optional output must use the current-window fallback"),
		assert_eq(invalid_audit.get("policy_successes"), 0),
		assert_eq(invalid_audit.get("policy_errors"), 1),
		assert_eq(invalid_audit.get("invalid_outputs"), 1),
		assert_eq(invalid_audit.get("same_window_fallbacks"), 1),
		assert_eq(invalid_audit.get("last_error_code"), "invalid_policy_output"),
		assert_eq(valid_empty_selection, [], "an explicit empty array is legal when min_count is zero"),
		assert_eq(valid_audit.get("policy_calls"), 2),
		assert_eq(valid_audit.get("policy_successes"), 1),
		assert_eq(valid_audit.get("policy_errors"), 1),
		assert_eq(valid_audit.get("invalid_outputs"), 1),
		assert_eq(valid_audit.get("same_window_fallbacks"), 1),
		assert_eq(valid_audit.get("last_error_code"), ""),
		assert_eq(valid_audit.get("engine_commits"), 0),
		assert_eq(valid_audit.get("engine_rejections"), 0),
	])
	owner.close_match()
	seed_owner.clear_forced_shuffle_seed()
	gsm.prepare_for_disposal()
	return checks


func test_live_worker_profile_returns_without_blocking_and_reuses_the_same_window() -> String:
	var requested := _request_exact_handle()
	if not bool(requested.get("ok", false)):
		return "exact package handle failed: %s" % str(requested)
	var seed_owner := PlayerState.new()
	seed_owner.set_forced_shuffle_seed(84312)
	var gsm := GameStateMachine.new()
	gsm.start_game(CardDatabase.get_deck(MARNIE_DECK_ID), CardDatabase.get_deck(RULES_AI_DECK_ID), 0)
	var built: Dictionary = OwnerScript.create(
		requested.get("handle"), gsm, 0, "live-worker-same-window"
	)
	if not bool(built.get("ok", false)):
		seed_owner.clear_forced_shuffle_seed()
		gsm.prepare_for_disposal()
		return "author owner bind failed: %s" % str(built)
	var owner: Variant = built.get("owner")
	var slow_policy := SlowSameWindowPolicy.new()
	owner.set("_policy", slow_policy)
	var configured := bool(owner.call("configure_policy_execution_profile", "worker_v1"))
	var options: Array = owner.call("_options_for_items", [{"kind": "effect_target"}], "")
	var started_usec := Time.get_ticks_usec()
	var first_selection: Array = owner.call("_select_items", "effect_target", options, 1, 1)
	var first_elapsed_usec := Time.get_ticks_usec() - started_usec
	var pending_after_first := bool(owner.call("has_pending_policy_decision"))
	var tree := Engine.get_main_loop() as SceneTree
	var rendered_frames := 0
	while not bool(owner.call("is_policy_decision_ready")) and rendered_frames < 240:
		rendered_frames += 1
		await tree.process_frame
	var second_selection: Array = owner.call("_select_items", "effect_target", options, 1, 1)
	var audit: Dictionary = owner.audit_snapshot()
	var checks := run_checks([
		assert_true(configured, "Live owner must accept the worker execution profile before its first decision"),
		assert_eq(first_selection, [], "The first call must publish pending state instead of blocking the render thread"),
		assert_true(first_elapsed_usec < 100000, "Scheduling a 160ms policy must return to Godot in under 100ms"),
		assert_true(pending_after_first, "The immutable selection window must stay pending until the worker completes"),
		assert_true(rendered_frames > 0, "Godot frames must advance while strategy calculation runs"),
		assert_eq(second_selection, [0], "The completed response must rebind to the unchanged current window"),
		assert_eq(slow_policy.calls, 1, "Polling must not execute the policy twice"),
		assert_eq(int(audit.get("policy_calls", 0)), 1, "One immutable window must count as one policy call"),
		assert_eq(int(audit.get("policy_worker_schedules", 0)), 1, "The worker schedule must be auditable"),
		assert_eq(str(audit.get("policy_execution_profile", "")), "worker_v1"),
	])
	owner.close_match()
	seed_owner.clear_forced_shuffle_seed()
	gsm.prepare_for_disposal()
	return checks


func test_live_worker_rejects_result_when_selection_constraints_change() -> String:
	var requested := _request_exact_handle()
	if not bool(requested.get("ok", false)):
		return "exact package handle failed: %s" % str(requested)
	var seed_owner := PlayerState.new()
	seed_owner.set_forced_shuffle_seed(84313)
	var gsm := GameStateMachine.new()
	gsm.start_game(CardDatabase.get_deck(MARNIE_DECK_ID), CardDatabase.get_deck(RULES_AI_DECK_ID), 0)
	var built: Dictionary = OwnerScript.create(
		requested.get("handle"), gsm, 0, "live-worker-stale-window"
	)
	if not bool(built.get("ok", false)):
		seed_owner.clear_forced_shuffle_seed()
		gsm.prepare_for_disposal()
		return "author owner bind failed: %s" % str(built)
	var owner: Variant = built.get("owner")
	var slow_policy := SlowSameWindowPolicy.new()
	owner.set("_policy", slow_policy)
	owner.call("configure_policy_execution_profile", "worker_v1")
	var options: Array = owner.call("_options_for_items", [{"kind": "effect_target"}], "")
	var first_selection: Array = owner.call("_select_items", "effect_target", options, 1, 1)
	var tree := Engine.get_main_loop() as SceneTree
	var rendered_frames := 0
	while not bool(owner.call("is_policy_decision_ready")) and rendered_frames < 240:
		rendered_frames += 1
		await tree.process_frame
	# The policy answered the old mandatory 1/1 window. Making the current
	# window optional must invalidate that answer before any index is accepted.
	var stale_selection: Array = owner.call("_select_items", "effect_target", options, 0, 1)
	var audit: Dictionary = owner.audit_snapshot()
	var checks := run_checks([
		assert_eq(first_selection, []),
		assert_true(rendered_frames > 0),
		assert_eq(stale_selection, [], "A stale mandatory answer must not execute in the new optional window"),
		assert_eq(slow_policy.calls, 1, "Rejecting a stale result must not rerun the old window"),
		assert_eq(int(audit.get("policy_successes", 0)), 0),
		assert_eq(int(audit.get("policy_errors", 0)), 1),
		assert_eq(int(audit.get("same_window_fallbacks", 0)), 1),
		assert_eq(int(audit.get("policy_worker_stale_results", 0)), 1),
		assert_eq(str(audit.get("last_error_code", "")), "stale_policy_response"),
	])
	owner.close_match()
	seed_owner.clear_forced_shuffle_seed()
	gsm.prepare_for_disposal()
	return checks


func test_live_worker_keeps_optional_model_leaf_off_the_render_thread() -> String:
	var requested := _request_exact_handle()
	if not bool(requested.get("ok", false)):
		return "exact package handle failed: %s" % str(requested)
	var seed_owner := PlayerState.new()
	seed_owner.set_forced_shuffle_seed(84314)
	var gsm := GameStateMachine.new()
	gsm.start_game(CardDatabase.get_deck(MARNIE_DECK_ID), CardDatabase.get_deck(RULES_AI_DECK_ID), 0)
	var built: Dictionary = OwnerScript.create(
		requested.get("handle"), gsm, 0, "live-worker-model-leaf"
	)
	if not bool(built.get("ok", false)):
		seed_owner.clear_forced_shuffle_seed()
		gsm.prepare_for_disposal()
		return "author owner bind failed: %s" % str(built)
	var owner: Variant = built.get("owner")
	var slow_policy := SlowSameWindowPolicy.new()
	slow_policy.delay_msec = 20
	var slow_model := SlowModelActor.new()
	owner.set("_policy", slow_policy)
	owner.set("_model_actor", slow_model)
	var pins: Dictionary = owner.get("_pins")
	pins["policy_mode"] = "rules_with_model"
	owner.set("_pins", pins)
	owner.call("configure_policy_execution_profile", "worker_v1")
	var options: Array = owner.call("_options_for_items", [{"kind": "effect_target"}], "")
	var started_usec := Time.get_ticks_usec()
	var first_selection: Array = owner.call("_select_items", "effect_target", options, 1, 1)
	var first_elapsed_usec := Time.get_ticks_usec() - started_usec
	var tree := Engine.get_main_loop() as SceneTree
	var rendered_frames := 0
	while not bool(owner.call("is_policy_decision_ready")) and rendered_frames < 240:
		rendered_frames += 1
		await tree.process_frame
	var second_selection: Array = owner.call("_select_items", "effect_target", options, 1, 1)
	var audit: Dictionary = owner.audit_snapshot()
	var checks := run_checks([
		assert_eq(first_selection, []),
		assert_true(first_elapsed_usec < 100000, "Scheduling policy plus model inference must return in under 100ms"),
		assert_true(rendered_frames > 0, "Frames must continue while the model leaf runs"),
		assert_eq(second_selection, [0]),
		assert_eq(slow_policy.calls, 1),
		assert_eq(slow_model.calls, 1, "The optional local model leaf must run exactly once on the same worker task"),
		assert_eq(int(audit.get("model_decision_windows", 0)), 1),
		assert_eq(int(audit.get("model_inference_successes", 0)), 1),
	])
	owner.close_match()
	seed_owner.clear_forced_shuffle_seed()
	gsm.prepare_for_disposal()
	return checks


func test_game_manager_and_battle_scene_route_exact_author_owner_without_classic_ai() -> String:
	AuthorStrategyPackageCatalog.scan_startup()
	var previous_mode: int = GameManager.current_mode
	var previous_selection := GameManager.get_author_strategy_selection()
	var previous_decks: Array = GameManager.selected_deck_ids.duplicate()
	var accepted := GameManager.set_author_strategy_selection(_exact_selection())
	GameManager.current_mode = GameManager.GameMode.VS_AUTHOR_STRATEGY_AI
	GameManager.selected_deck_ids = [RULES_AI_DECK_ID, -1]
	var resolved: DeckData = GameManager.resolve_selected_battle_deck(1)
	var requested := _request_exact_handle()
	var seed_owner := PlayerState.new()
	seed_owner.set_forced_shuffle_seed(84301)
	var gsm := GameStateMachine.new()
	gsm.start_game(resolved, CardDatabase.get_deck(RULES_AI_DECK_ID), 0)
	var built: Dictionary = OwnerScript.create(requested.get("handle"), gsm, 0, "battle-scene-owner-route")
	var owner: Variant = built.get("owner")
	var scene := BattleSceneScript.new()
	scene.set("_gsm", gsm)
	scene.set("_author_player_owner", owner)
	scene.set("_pending_choice", "setup_active_0")
	scene.set("_dialog_data", {"player": 0, "basics": gsm.game_state.players[0].get_basic_pokemon_in_hand()})
	var ready := bool(scene.call("_is_ai_turn_ready"))
	scene.call("_maybe_run_ai")
	var checks := run_checks([
		assert_true(accepted),
		assert_true(resolved != null),
		assert_eq(resolved.id if resolved != null else -1, 0),
		assert_eq(resolved.source_provider if resolved != null else "", "ptcgdap_author_strategy_package"),
		assert_eq(_deck_uid_counts(resolved), _handle_uid_counts(requested.get("handle"))),
		assert_true(bool(requested.get("ok", false))),
		assert_true(bool(built.get("ok", false))),
		assert_null(scene.get("_ai_opponent"), "author routing must not construct classic AI"),
		assert_eq(scene.call("_runtime_ai_owner"), owner),
		assert_true(ready, "BattleScene scheduler must recognize an author-owned prompt"),
		assert_true(bool(scene.get("_ai_step_scheduled")), "the already-published prompt must be scheduled"),
	])
	owner.close_match()
	scene.free()
	seed_owner.clear_forced_shuffle_seed()
	gsm.prepare_for_disposal()
	GameManager.current_mode = previous_mode as GameManager.GameMode
	GameManager.selected_deck_ids = previous_decks
	GameManager.reset_author_strategy_selection()
	if not previous_selection.is_empty():
		GameManager.set_author_strategy_selection(previous_selection)
	return checks


func test_gift_box_csv_materializes_without_a_numbered_deck_lookup() -> String:
	var requested := _request_gift_box_handle()
	var materialized: Dictionary = GameManager.materialize_author_strategy_battle_deck(
		requested.get("handle")
	) if bool(requested.get("ok", false)) else {}
	var deck := materialized.get("deck") as DeckData
	return run_checks([
		assert_true(bool(requested.get("ok", false))),
		assert_true(bool(materialized.get("ok", false))),
		assert_true(deck != null),
		assert_eq(deck.id if deck != null else -1, 0),
		assert_eq(deck.total_cards if deck != null else -1, 60),
		assert_eq(deck.source_provider if deck != null else "", "ptcgdap_author_strategy_package"),
		assert_eq(_deck_uid_counts(deck), _handle_uid_counts(requested.get("handle"))),
	])


func test_author_battle_presentation_uses_package_author_deck_and_compact_version() -> String:
	var requested := _request_gift_box_handle()
	var handle: Variant = requested.get("handle")
	var materializer_script: Variant = load(
		"res://scripts/ai/ptcgdap/packages/AuthorStrategyDeckMaterializer.gd"
	)
	var presentation: Dictionary = handle.call("presentation_snapshot") \
		if handle != null and handle.has_method("presentation_snapshot") else {}
	var materialized: Dictionary = GameManager.materialize_author_strategy_battle_deck(handle) \
		if bool(requested.get("ok", false)) else {}
	var deck := materialized.get("deck") as DeckData
	var latest_label := "%s%s" % [
		presentation.get("deck_name", ""),
		materializer_script._compact_player_version("5.30.0"),
	]
	var previous_mode: int = GameManager.current_mode
	var scene := BattleSceneScript.new()
	scene.set("_author_strategy_author_name", presentation.get("author_name", ""))
	scene.set("_author_strategy_deck_label", latest_label)
	GameManager.current_mode = GameManager.GameMode.VS_AUTHOR_STRATEGY_AI
	var thinking_text := str(scene.call(
		"_llm_wait_hud_text_for_model", "ptcgdap-author-local", 3, 2, 1
	))
	var pinned_deck_label := str(scene.call("_get_selected_deck_name", 1))
	var checks := run_checks([
		assert_true(bool(requested.get("ok", false)), "gift-box handle must remain valid"),
		assert_true(not presentation.is_empty(), "sealed handle must expose public presentation metadata"),
		assert_eq(str(presentation.get("author_name", "")), "波导的勇者"),
		assert_eq(str(presentation.get("deck_name", "")), "玛丽的礼盒"),
		assert_eq(str(presentation.get("package_version", "")), GIFT_BOX_PACKAGE_VERSION),
		assert_true(bool(materialized.get("ok", false))),
		assert_eq(deck.deck_name if deck != null else "", "玛丽的礼盒1.9"),
		assert_false((deck.deck_name if deck != null else "").contains(GIFT_BOX_PACKAGE_ID)),
		assert_eq(latest_label, "玛丽的礼盒5.30"),
		assert_true(thinking_text.begins_with("波导的勇者 正在计算行动.")),
		assert_eq(pinned_deck_label, "玛丽的礼盒5.30"),
	])
	scene.free()
	GameManager.current_mode = previous_mode as GameManager.GameMode
	return checks


func test_author_owner_binds_before_any_setup_prompt_is_published() -> String:
	var requested := _request_gift_box_handle()
	var materialized: Dictionary = GameManager.materialize_author_strategy_battle_deck(
		requested.get("handle")
	) if bool(requested.get("ok", false)) else {}
	var author_deck := materialized.get("deck") as DeckData
	var prompts: Array[String] = []
	var seed_owner := PlayerState.new()
	seed_owner.set_forced_shuffle_seed(84307)
	var gsm := GameStateMachine.new()
	gsm.player_choice_required.connect(func(choice_type: String, _data: Dictionary) -> void:
		prompts.append(choice_type)
	)
	if author_deck != null:
		gsm.start_game(CardDatabase.get_deck(RULES_AI_DECK_ID), author_deck, 0, false, true)
	var prompts_before_owner := prompts.duplicate()
	var totals_before_owner := [
		gsm.count_player_total_cards(0) if gsm.game_state != null else -1,
		gsm.count_player_total_cards(1) if gsm.game_state != null else -1,
	]
	var built: Dictionary = BattleDecisionOwnerFactoryScript.build_windows_author_owner(
		requested.get("handle"),
		gsm,
		1,
		"gift-box-owner-before-setup",
		ExecutionGateScript.DEVELOPMENT_MODE
	) if author_deck != null else {}
	var owner: Variant = built.get("owner")
	var setup_began := gsm.begin_deferred_setup() if bool(built.get("ok", false)) else false
	var checks := run_checks([
		assert_true(bool(requested.get("ok", false)), "request failed: %s" % str(requested)),
		assert_true(bool(materialized.get("ok", false)), "materialization failed: %s" % str(materialized)),
		assert_eq(prompts_before_owner, [], "setup prompts must stay unpublished before owner binding"),
		assert_eq(totals_before_owner, [60, 60]),
		assert_true(bool(built.get("ok", false)), "owner bind failed: %s" % str(built)),
		assert_true(owner != null and owner.validate_integrity()),
		assert_true(setup_began),
		assert_true(not prompts.is_empty(), "setup may publish only after the author owner exists"),
	])
	if owner != null:
		owner.close_match()
	seed_owner.clear_forced_shuffle_seed()
	gsm.prepare_for_disposal()
	return checks


func test_windows_ui_acceptance_routes_rules_seat_zero_and_author_seat_one() -> String:
	var previous_mode: int = GameManager.current_mode
	var previous_feature_enabled: Variant = ProjectSettings.get_setting(AuthorStrategyFeatureGateScript.PROJECT_SETTING, true)
	var requested := _request_exact_handle()
	if not bool(requested.get("ok", false)):
		return "exact package handle failed: %s" % str(requested)
	var rules_deck: DeckData = CardDatabase.get_deck(RULES_AI_DECK_ID)
	var marnie: DeckData = CardDatabase.get_deck(MARNIE_DECK_ID)
	var seed_owner := PlayerState.new()
	seed_owner.set_forced_shuffle_seed(84309)
	var gsm := GameStateMachine.new()
	gsm.start_game(rules_deck, marnie, 0)
	var author_result: Dictionary = OwnerScript.create(requested.get("handle"), gsm, 1, "windows-ui-dual-owner-route")
	var registry := DeckStrategyRegistryScript.new()
	var rules_result: Dictionary = BattleDecisionOwnerFactoryScript.build_windows_development_rules_owner(
		registry, rules_deck, 0
	)
	var author_owner: Variant = author_result.get("owner")
	var rules_owner: Variant = rules_result.get("owner")
	var scene := BattleSceneScript.new()
	scene.set("_gsm", gsm)
	scene.set("_author_player_owner", author_owner)
	scene.set("_development_player_rules_owner", rules_owner)
	scene.set("_author_development_ui_match_active", true)
	GameManager.current_mode = GameManager.GameMode.VS_AUTHOR_STRATEGY_AI
	scene.set("_pending_choice", "setup_active_0")
	var seat_zero_owner: Variant = scene.call("_runtime_ai_owner")
	scene.set("_pending_choice", "setup_active_1")
	var seat_one_owner: Variant = scene.call("_runtime_ai_owner")
	ProjectSettings.set_setting(AuthorStrategyFeatureGateScript.PROJECT_SETTING, false)
	var seat_one_owner_after_rollback_flag: Variant = scene.call("_runtime_ai_owner")
	var checks := run_checks([
		assert_true(bool(author_result.get("ok", false))),
		assert_true(bool(rules_result.get("ok", false))),
		assert_eq(seat_zero_owner, rules_owner),
		assert_eq(seat_one_owner, author_owner),
		assert_eq(seat_one_owner_after_rollback_flag, author_owner, "an active match must not hot-switch owners"),
		assert_eq(rules_owner.player_index if rules_owner != null else -1, 0),
		assert_false(bool(rules_owner.use_mcts) if rules_owner != null else true),
		assert_eq(rules_owner.decision_runtime_mode if rules_owner != null else -1, AIOpponentScript.DECISION_RUNTIME_RULES_ONLY),
		assert_false(author_owner is AIOpponent),
	])
	if author_owner != null:
		author_owner.close_match()
	scene.free()
	seed_owner.clear_forced_shuffle_seed()
	gsm.prepare_for_disposal()
	ProjectSettings.set_setting(AuthorStrategyFeatureGateScript.PROJECT_SETTING, previous_feature_enabled)
	GameManager.current_mode = previous_mode as GameManager.GameMode
	return checks


func test_author_owner_consumes_live_prize_state_without_dialog_payload() -> String:
	var requested := _request_exact_handle()
	if not bool(requested.get("ok", false)):
		return "exact package handle failed: %s" % str(requested)
	var seed_owner := PlayerState.new()
	seed_owner.set_forced_shuffle_seed(84302)
	var gsm := GameStateMachine.new()
	gsm.start_game(CardDatabase.get_deck(MARNIE_DECK_ID), CardDatabase.get_deck(RULES_AI_DECK_ID), 0)
	var built: Dictionary = OwnerScript.create(requested.get("handle"), gsm, 0, "live-prize-owner-route")
	if not bool(built.get("ok", false)):
		seed_owner.clear_forced_shuffle_seed()
		gsm.prepare_for_disposal()
		return "author owner bind failed: %s" % str(built)
	var owner: Variant = built.get("owner")
	var prize_player: PlayerState = gsm.game_state.players[0]
	if prize_player.prizes.is_empty():
		var injected_prizes: Array[CardInstance] = [
			prize_player.deck.pop_back(),
			prize_player.deck.pop_back(),
		]
		prize_player.set_prizes(injected_prizes)
	var scene := BattleSceneScript.new()
	scene.set("_gsm", gsm)
	scene.set("_author_player_owner", owner)
	scene.set("_pending_choice", "take_prize")
	scene.set("_dialog_data", {})
	scene.set("_pending_prize_player_index", 0)
	scene.set("_pending_prize_remaining", 2)
	scene.set("_pending_prize_animating", false)
	gsm.set("_pending_prize_player_index", 0)
	gsm.set("_pending_prize_remaining", 2)
	gsm.set("_pending_prize_resume_mode", "")
	gsm.set("_pending_prize_resume_player_index", -1)
	var prizes_before := prize_player.prizes.size()
	var first_progressed := bool(owner.run_single_step(scene, gsm))
	var first_choice := str(scene.get("_pending_choice"))
	var first_player := int(scene.get("_pending_prize_player_index"))
	var first_remaining := int(scene.get("_pending_prize_remaining"))
	var second_progressed := bool(owner.run_single_step(scene, gsm))
	var checks := run_checks([
		assert_true(first_progressed),
		assert_eq(first_choice, "take_prize"),
		assert_eq(first_player, 0),
		assert_eq(first_remaining, 1),
		assert_true(second_progressed),
		assert_eq(prize_player.prizes.size(), prizes_before - 2),
		assert_eq(scene.get("_pending_choice"), ""),
		assert_eq(scene.get("_pending_prize_player_index"), -1),
		assert_eq(scene.get("_pending_prize_remaining"), 0),
	])
	owner.close_match()
	scene.free()
	seed_owner.clear_forced_shuffle_seed()
	gsm.prepare_for_disposal()
	return checks


func test_real_battle_scene_starts_exact_author_player_owner() -> String:
	# Product navigation reaches BattleSetup after the deferred startup scan. This
	# focused test instantiates BattleScene directly, so make that prerequisite
	# explicit instead of racing the catalog's first-frame warm-up.
	AuthorStrategyPackageCatalog.scan_startup()
	var previous_mode: int = GameManager.current_mode
	var previous_selection := GameManager.get_author_strategy_selection()
	var previous_decks: Array = GameManager.selected_deck_ids.duplicate()
	var previous_first_player := GameManager.first_player_choice
	GameManager.reset_author_strategy_selection()
	var accepted := GameManager.set_author_strategy_selection(_exact_selection())
	GameManager.current_mode = GameManager.GameMode.VS_AUTHOR_STRATEGY_AI
	GameManager.selected_deck_ids = [RULES_AI_DECK_ID, -1]
	GameManager.first_player_choice = 0
	var resolved_rules_deck := GameManager.resolve_selected_battle_deck(0)
	var resolved_author_deck := GameManager.resolve_selected_battle_deck(1)
	var scene := BattleSceneScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	# FocusedSuiteRunner adds the scene before its root Window advances a frame.
	# Let the engine enter the node and deliver the real _ready lifecycle.
	await tree.process_frame
	var owner: Variant = scene.get("_author_player_owner")
	var match_evidence: Variant = scene.get("_author_match_evidence")
	var evidence_audit: Dictionary = match_evidence.audit_snapshot() if match_evidence != null else {}
	var evidence_path := str(evidence_audit.get("path", ""))
	var public_replay: Variant = scene.get("_author_public_replay_coordinator")
	var public_replay_audit: Dictionary = public_replay.audit_snapshot() if public_replay != null else {}
	var gsm: GameStateMachine = scene.get("_gsm") as GameStateMachine
	var checks := run_checks([
		assert_true(accepted, "exact selection should be accepted"),
		assert_true(resolved_rules_deck != null, "rules deck should resolve before BattleScene starts"),
		assert_true(resolved_author_deck != null, "author deck should resolve before BattleScene starts"),
		assert_true(gsm != null and gsm.game_state != null, "BattleScene should create a game state: %s" % str(scene.get("_author_runtime_start_error_code"))),
		assert_true(owner != null and owner.validate_integrity(), "BattleScene should create a valid author owner: %s" % str(scene.get("_author_runtime_start_error_code"))),
		assert_eq(int(owner.player_index) if owner != null else -1, 1),
		assert_null(scene.get("_ai_opponent")),
		assert_eq(scene.get("_author_runtime_start_error_code"), ""),
		assert_eq(scene.call("_runtime_ai_owner"), owner),
		assert_true(match_evidence != null, "author BattleScene must start a public-safe incremental evidence owner"),
		assert_eq(evidence_audit.get("visibility"), "public_allow_list_v1"),
		assert_false(bool(evidence_audit.get("private_replay_used", true))),
		assert_true(public_replay != null, "author BattleScene must start the public replay coordinator"),
		assert_true(bool(public_replay_audit.get("started", false))),
		assert_false(bool(public_replay_audit.get("private_replay_used", true))),
		assert_eq(public_replay_audit.get("engine_invocations"), 0),
	])
	GameManager.current_mode = previous_mode as GameManager.GameMode
	scene.set("_ai_step_scheduled", false)
	scene.set("_ai_followup_requested", false)
	scene.set("_hand_surface_integrity_serial", int(scene.get("_hand_surface_integrity_serial")) + 1)
	tree.root.remove_child(scene)
	# Keep the detached instance alive until any two-frame surface verifier has
	# observed is_inside_tree() == false and returned from its await.
	for _frame: int in 3:
		await tree.process_frame
	scene.free()
	if evidence_path != "":
		DirAccess.remove_absolute(evidence_path)
	GameManager.selected_deck_ids = previous_decks
	GameManager.first_player_choice = previous_first_player
	GameManager.reset_author_strategy_selection()
	if not previous_selection.is_empty():
		GameManager.set_author_strategy_selection(previous_selection)
	return checks


func test_real_battle_scene_starts_exact_cynthia_author_owner() -> String:
	AuthorStrategyPackageCatalog.scan_startup()
	var previous_mode: int = GameManager.current_mode
	var previous_selection := GameManager.get_author_strategy_selection()
	var previous_decks: Array = GameManager.selected_deck_ids.duplicate()
	var previous_first_player := GameManager.first_player_choice
	GameManager.reset_author_strategy_selection()
	var accepted := GameManager.set_author_strategy_selection(_cynthia_selection())
	GameManager.current_mode = GameManager.GameMode.VS_AUTHOR_STRATEGY_AI
	GameManager.selected_deck_ids = [RULES_AI_DECK_ID, -1]
	GameManager.first_player_choice = 0
	var resolved_author_deck := GameManager.resolve_selected_battle_deck(1)
	var scene := BattleSceneScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	await tree.process_frame
	var owner: Variant = scene.get("_author_player_owner")
	var checks := run_checks([
		assert_true(accepted),
		assert_true(resolved_author_deck != null),
		assert_eq(resolved_author_deck.id if resolved_author_deck != null else -1, 0),
		assert_eq(resolved_author_deck.source_provider if resolved_author_deck != null else "", "ptcgdap_author_strategy_package"),
		assert_true(owner != null and owner.validate_integrity(), "Cynthia BattleScene owner should bind: %s" % str(scene.get("_author_runtime_start_error_code"))),
		assert_eq(owner.get_script().resource_path if owner != null else "", "res://scripts/ai/ptcgdap/host/godot/CynthiaAuthorStrategyDevelopmentBattleOwner.gd"),
		assert_null(scene.get("_ai_opponent")),
		assert_eq(scene.get("_author_runtime_start_error_code"), ""),
	])
	GameManager.current_mode = previous_mode as GameManager.GameMode
	scene.set("_ai_step_scheduled", false)
	scene.set("_ai_followup_requested", false)
	scene.set("_hand_surface_integrity_serial", int(scene.get("_hand_surface_integrity_serial")) + 1)
	tree.root.remove_child(scene)
	for _frame: int in 3:
		await tree.process_frame
	scene.free()
	GameManager.selected_deck_ids = previous_decks
	GameManager.first_player_choice = previous_first_player
	GameManager.reset_author_strategy_selection()
	if not previous_selection.is_empty():
		GameManager.set_author_strategy_selection(previous_selection)
	return checks


func test_real_battle_scene_starts_gift_box_from_package_csv() -> String:
	AuthorStrategyPackageCatalog.scan_startup()
	var previous_mode: int = GameManager.current_mode
	var previous_selection := GameManager.get_author_strategy_selection()
	var previous_decks: Array = GameManager.selected_deck_ids.duplicate()
	var previous_first_player := GameManager.first_player_choice
	GameManager.reset_author_strategy_selection()
	var accepted := GameManager.set_author_strategy_selection(_gift_box_selection())
	GameManager.current_mode = GameManager.GameMode.VS_AUTHOR_STRATEGY_AI
	GameManager.selected_deck_ids = [RULES_AI_DECK_ID, 0]
	GameManager.first_player_choice = 0
	var expected_handle := _request_gift_box_handle()
	var scene := BattleSceneScene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	await tree.process_frame
	var owner: Variant = scene.get("_author_player_owner")
	var public_identity: Dictionary = owner.public_replay_identity() if owner != null else {}
	var strategy_participant: Dictionary = public_identity.get("strategy_participant", {})
	var deck_identity: Dictionary = strategy_participant.get("deck_identity", {})
	var gsm := scene.get("_gsm") as GameStateMachine
	var actual_inventory := {}
	if gsm != null and gsm.game_state != null and gsm.game_state.players.size() == 2:
		for card: CardInstance in OwnerScript._collect_player_cards(gsm.game_state.players[1]):
			var uid := card.card_data.get_uid() if card != null and card.card_data != null else ""
			actual_inventory[uid] = int(actual_inventory.get(uid, 0)) + 1
	var prompt_owner := int(scene.call("_development_ui_prompt_player_index"))
	var runtime_owner: Variant = scene.call("_runtime_ai_owner") if prompt_owner == 1 else null
	var checks := run_checks([
		assert_true(accepted),
		assert_true(bool(expected_handle.get("ok", false))),
		assert_true(owner != null and owner.validate_integrity(), "Gift Box owner should bind: %s" % str(scene.get("_author_runtime_start_error_code"))),
		assert_eq(scene.get("_author_runtime_start_error_code"), ""),
		assert_eq(deck_identity.get("deck_id"), "%s@%s" % [GIFT_BOX_PACKAGE_ID, GIFT_BOX_PACKAGE_VERSION]),
		assert_eq(actual_inventory, _handle_uid_counts(expected_handle.get("handle"))),
		assert_true(prompt_owner != 1 or runtime_owner == owner, "an author-owned setup prompt must route to the author owner"),
		assert_null(scene.get("_ai_opponent")),
	])
	GameManager.current_mode = previous_mode as GameManager.GameMode
	scene.set("_ai_step_scheduled", false)
	scene.set("_ai_followup_requested", false)
	scene.set("_hand_surface_integrity_serial", int(scene.get("_hand_surface_integrity_serial")) + 1)
	tree.root.remove_child(scene)
	for _frame: int in 3:
		await tree.process_frame
	scene.free()
	GameManager.selected_deck_ids = previous_decks
	GameManager.first_player_choice = previous_first_player
	GameManager.reset_author_strategy_selection()
	if not previous_selection.is_empty():
		GameManager.set_author_strategy_selection(previous_selection)
	return checks


func test_ai_deck_picker_open_stays_metadata_only_for_real_packages() -> String:
	AuthorStrategyPackageCatalog.scan_startup()
	var previous_mode: int = GameManager.current_mode
	var previous_selection := GameManager.get_author_strategy_selection()
	var catalog := CatalogScript.new()
	var report: Dictionary = catalog.scan_startup()
	var scene := BattleSetupScene.instantiate()
	scene.call("_ready")
	scene.call("_apply_author_strategy_catalog_report", report, _gift_box_selection())
	# Reproduce the player path: open the shared AI deck picker from classic AI
	# mode, where real author packages are rendered next to classic decks.
	scene.call("_select_mode_option", 1)
	scene.call("_on_mode_changed", 1)
	var started_at_msec := Time.get_ticks_msec()
	scene.call("_on_deck_picker_pressed", 1)
	var elapsed_msec := Time.get_ticks_msec() - started_at_msec
	var picker := scene.find_child("DeckPickerOverlay", true, false) as Control
	var author_button := scene.find_child("AuthorStrategyPickerButton", true, false) as Button
	var author_records: Array = scene.get("_author_strategy_records")
	scene.call("_select_mode_option", 2)
	var author_deck_after_open: Variant = scene.call("_selected_deck_for_slot", 1)
	var checks := run_checks([
		assert_null(author_deck_after_open, "setup rendering must not materialize an author package deck"),
		assert_true(picker != null and picker.visible, "AI deck picker should open synchronously"),
		assert_true(
			author_button != null,
			"a real package should render from %d catalog records" % author_records.size()
		),
		assert_true(
			elapsed_msec < 2000,
			"opening the metadata-only AI picker took %d ms" % elapsed_msec
		),
		assert_true(bool(scene.call("_author_strategy_start_allowed"))),
	])
	print("PTCGDAP_AUTHOR_STRATEGY_PICKER_OPEN_MSEC=%d" % elapsed_msec)
	scene.free()
	catalog.free()
	GameManager.current_mode = previous_mode as GameManager.GameMode
	GameManager.reset_author_strategy_selection()
	if not previous_selection.is_empty():
		GameManager.set_author_strategy_selection(previous_selection)
	return checks


func test_battle_setup_enables_only_the_exact_windows_development_candidate() -> String:
	AuthorStrategyPackageCatalog.scan_startup()
	var previous_mode: int = GameManager.current_mode
	var previous_selection := GameManager.get_author_strategy_selection()
	var previous_decks: Array = GameManager.selected_deck_ids.duplicate()
	var catalog := CatalogScript.new()
	var report: Dictionary = catalog.scan_startup()
	var scene := BattleSetupScene.instantiate()
	scene.call("_ready")
	scene.call("_apply_author_strategy_catalog_report", report, _exact_selection())
	scene.call("_select_mode_option", 2)
	scene.call("_on_mode_changed", 2)
	var exact_allowed := bool(scene.call("_author_strategy_start_allowed"))
	var exact_apply := bool(scene.call("_apply_setup_selection"))
	var start_button := scene.find_child("BtnStart", true, false) as Button
	var checks := run_checks([
		assert_true(exact_allowed, "exact package should materialize from its CSV"),
		assert_true(exact_apply, "BattleSetup should accept the materialized package deck"),
		assert_false(start_button.disabled if start_button != null else true),
		assert_eq(GameManager.current_mode, GameManager.GameMode.VS_AUTHOR_STRATEGY_AI),
		assert_eq(GameManager.selected_deck_ids[1], 0),
	])
	scene.free()
	catalog.free()
	GameManager.current_mode = previous_mode as GameManager.GameMode
	GameManager.selected_deck_ids = previous_decks
	GameManager.reset_author_strategy_selection()
	if not previous_selection.is_empty():
		GameManager.set_author_strategy_selection(previous_selection)
	return checks


func test_battle_setup_enables_exact_cynthia_development_candidate() -> String:
	AuthorStrategyPackageCatalog.scan_startup()
	var previous_mode: int = GameManager.current_mode
	var previous_selection := GameManager.get_author_strategy_selection()
	var previous_decks: Array = GameManager.selected_deck_ids.duplicate()
	var catalog := CatalogScript.new()
	var report: Dictionary = catalog.scan_startup()
	var scene := BattleSetupScene.instantiate()
	scene.call("_ready")
	scene.call("_apply_author_strategy_catalog_report", report, _cynthia_selection())
	scene.call("_select_mode_option", 2)
	scene.call("_on_mode_changed", 2)
	var exact_allowed := bool(scene.call("_author_strategy_start_allowed"))
	var exact_apply := bool(scene.call("_apply_setup_selection"))
	var start_button := scene.find_child("BtnStart", true, false) as Button
	var checks := run_checks([
		assert_true(exact_allowed, "exact Cynthia package should materialize from its CSV"),
		assert_true(exact_apply, "BattleSetup should accept the materialized Cynthia package deck"),
		assert_false(start_button.disabled if start_button != null else true),
		assert_eq(start_button.text if start_button != null else "", "开始 Windows 开发对战"),
		assert_eq(GameManager.current_mode, GameManager.GameMode.VS_AUTHOR_STRATEGY_AI),
		assert_eq(GameManager.selected_deck_ids[1], 0),
	])
	scene.free()
	catalog.free()
	GameManager.current_mode = previous_mode as GameManager.GameMode
	GameManager.selected_deck_ids = previous_decks
	GameManager.reset_author_strategy_selection()
	if not previous_selection.is_empty():
		GameManager.set_author_strategy_selection(previous_selection)
	return checks
