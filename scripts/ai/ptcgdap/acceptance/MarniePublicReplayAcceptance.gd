class_name MarniePublicReplayAcceptance
extends RefCounted

const MARNIE_DECK_ID := 800018501
const RULES_AI_DECK_ID := 575720
const PACKAGE_ID := "ptcgdap.marnie.windows-local"
const PACKAGE_VERSION := "0.1.0"
const PACKAGE_ARCHIVE_SHA256 := "32E25453431886F76CEC606089ED4815EC681FBD33073F53A335A769D293643E"
const DEFAULT_SEED := 84590
const DEFAULT_MAX_STEPS := 700

const GateScript = preload("res://scripts/ai/ptcgdap/host/godot/AuthorStrategyWindowsDevelopmentGate.gd")
const OwnerScript = preload("res://scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorDevelopmentBattleOwner.gd")
const CatalogScript = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageCatalog.gd")
const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")
const HeadlessMatchBridgeScript = preload("res://scripts/ai/HeadlessMatchBridge.gd")
const DeckStrategyRegistryScript = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const ContractScript = preload("res://scripts/ai/ptcgdap/platform/CompetitiveStrategyContracts.gd")
const EnvelopeScript = preload("res://scripts/ai/ptcgdap/platform/replay/PublicReplayDevelopmentEnvelope.gd")
const CaptureScript = preload("res://scripts/ai/ptcgdap/platform/replay/PublicReplayCapture.gd")
const PresentationScript = preload("res://scripts/ai/ptcgdap/platform/replay/PublicReplayPresentation.gd")


func run(card_database: Node, options: Dictionary = {}) -> Dictionary:
	var seed := int(options.get("seed", DEFAULT_SEED))
	var max_steps := clampi(int(options.get("max_steps", DEFAULT_MAX_STEPS)), 1, 2000)
	var marnie: DeckData = card_database.call("get_deck", MARNIE_DECK_ID) if card_database != null else null
	var rules_deck: DeckData = card_database.call("get_deck", RULES_AI_DECK_ID) if card_database != null else null
	if marnie == null or rules_deck == null:
		return _failed(seed, "deck_load_failed")
	var contract_loaded: Dictionary = ContractScript.load_default()
	if not bool(contract_loaded.get("accepted", false)):
		return _failed(seed, str(contract_loaded.get("error_code", "contract_load_failed")))
	var contract_owner: Variant = contract_loaded.get("owner")
	var catalog := CatalogScript.new()
	catalog.scan_startup()
	var requested: Dictionary = GateScript.request_match_handle(catalog, _exact_selection(), "Windows")
	var seed_owner := PlayerState.new()
	seed_owner.set_forced_shuffle_seed(seed)
	var gsm := GameStateMachine.new()
	if gsm.coin_flipper != null:
		var rng: Variant = gsm.coin_flipper.get("_rng")
		if rng is RandomNumberGenerator:
			(rng as RandomNumberGenerator).seed = seed
	gsm.start_game(rules_deck, marnie, 0)
	var match_id := "csp-wp1-marnie-%d" % seed
	var built: Dictionary = OwnerScript.create(
		requested.get("handle"), gsm, 1, match_id
	) if bool(requested.get("ok", false)) else requested
	var owner: Variant = built.get("owner")
	var rules_ai := _rules_ai(0, rules_deck)
	var bridge := HeadlessMatchBridgeScript.new()
	bridge.bind(gsm)
	if owner != null:
		bridge.set_ai_controllers(rules_ai, owner)
	bridge.bootstrap_pending_setup()
	if owner == null:
		var owner_error := str(built.get("error_code", "owner_bind_failed"))
		_cleanup(catalog, bridge, gsm, seed_owner, owner)
		return _failed(seed, owner_error)
	var identity: Dictionary = owner.public_replay_identity()
	var envelope_result: Dictionary = EnvelopeScript.build(
		contract_owner, identity, seed, match_id
	)
	if not bool(envelope_result.get("accepted", false)):
		var envelope_error := str(envelope_result.get("error_code", "envelope_failed"))
		_cleanup(catalog, bridge, gsm, seed_owner, owner)
		return _failed(seed, envelope_error)
	var capture_result: Dictionary = CaptureScript.create(
		contract_owner,
		envelope_result.envelope,
		"csp-wp1-replay-%d" % seed,
		envelope_result.card_asset_catalog_sha256,
		envelope_result.event_dictionary_sha256
	)
	if not bool(capture_result.get("accepted", false)):
		var capture_error := str(capture_result.get("error_code", "capture_create_failed"))
		_cleanup(catalog, bridge, gsm, seed_owner, owner)
		return _failed(seed, capture_error)
	var capture: Variant = capture_result.get("capture")
	var initial_source: Dictionary = owner.public_replay_source_snapshot()
	var appended: Dictionary = capture.append_public_source(
		initial_source.get("source"), "match_started"
	) if bool(initial_source.get("ok", false)) else initial_source
	if not bool(appended.get("accepted", false)):
		var initial_error := str(appended.get("error_code", "initial_capture_failed"))
		_cleanup(catalog, bridge, gsm, seed_owner, owner)
		return _failed(seed, initial_error)
	var steps := 0
	var failure := ""
	while not gsm.game_state.is_game_over() and steps < max_steps:
		var progressed := false
		if bridge.has_pending_prompt():
			var prompt_owner := bridge.get_pending_prompt_owner()
			if prompt_owner == 1:
				progressed = bool(owner.run_single_step(bridge, gsm))
			elif bridge.can_resolve_pending_prompt():
				progressed = bridge.resolve_pending_prompt()
			else:
				progressed = rules_ai.run_single_step(bridge, gsm)
		elif gsm.game_state.current_player_index == 1:
			progressed = bool(owner.run_single_step(bridge, gsm))
		else:
			progressed = rules_ai.run_single_step(bridge, gsm)
		if not progressed:
			failure = "no_progress:%s" % bridge.get_pending_prompt_type()
			break
		steps += 1
		if not gsm.game_state.is_game_over():
			var source_result: Dictionary = owner.public_replay_source_snapshot()
			var frame_result: Dictionary = capture.append_public_source(
				source_result.get("source"), "state_progressed"
			) if bool(source_result.get("ok", false)) else source_result
			if not bool(frame_result.get("accepted", false)):
				failure = str(frame_result.get("error_code", "capture_failed"))
				break
	if steps >= max_steps and not gsm.game_state.is_game_over() and failure.is_empty():
		failure = "step_cap"
	var completed: Dictionary = {}
	if failure.is_empty() and gsm.game_state.is_game_over():
		var terminal_source: Dictionary = owner.public_replay_source_snapshot()
		completed = capture.finish(terminal_source.get("source")) \
			if bool(terminal_source.get("ok", false)) else terminal_source
		if not bool(completed.get("accepted", false)):
			failure = str(completed.get("error_code", "capture_finish_failed"))
	var artifact: Dictionary = completed.get("artifact", {})
	var presentation_audit: Dictionary = {}
	if failure.is_empty():
		var opened: Dictionary = PresentationScript.create(
			contract_owner, artifact.manifest, artifact.frames
		)
		if not bool(opened.get("accepted", false)):
			failure = str(opened.get("error_code", "presentation_failed"))
		else:
			var presentation: Variant = opened.get("presentation")
			presentation.last()
			presentation_audit = presentation.audit_snapshot()
	var terminal := gsm.game_state.is_game_over()
	var winner_index := int(gsm.game_state.winner_index)
	var win_reason := str(gsm.game_state.win_reason)
	var owner_audit: Dictionary = owner.audit_snapshot()
	var capture_audit: Dictionary = capture.audit_snapshot()
	_cleanup(catalog, bridge, gsm, seed_owner, owner)
	var clean := failure.is_empty() and terminal and bool(completed.get("accepted", false))
	return {
		"document_type": "marnie_public_replay_acceptance_v1",
		"schema_version": 1,
		"is_clean": clean,
		"complete_match_finished": clean,
		"terminal": terminal,
		"failure": failure,
		"seed": seed,
		"steps": steps,
		"winner_index": winner_index,
		"win_reason": win_reason,
		"strategy_id": "ptcgdap.marnie.18.0.package-local-v1",
		"package_id": PACKAGE_ID,
		"candidate_deck_id": MARNIE_DECK_ID,
		"baseline_deck_id": RULES_AI_DECK_ID,
		"source_authority": "ptcgdap_author_public_owner_v1",
		"artifact": artifact,
		"provenance": envelope_result.get("provenance", {}).duplicate(true),
		"owner_audit": owner_audit,
		"capture_audit": capture_audit,
		"presentation_audit": presentation_audit,
		"production_ready": false,
		"official_verified": false,
		"online_published": false,
		"limitations": [
			"Developer-local source-tree provenance is not a signed production runtime identity.",
			"The public display frame does not yet preserve attachment or evolution-stack relationships.",
			"No online upload, evaluator verdict, statistics, challenge, takeover, branching, or engine restore is present.",
		],
	}


func _rules_ai(seat: int, deck: DeckData) -> AIOpponent:
	var ai := AIOpponentScript.new()
	ai.configure(seat, 1)
	DeckStrategyRegistryScript.new().apply_strategy_for_deck(ai, deck)
	ai.use_mcts = false
	ai.decision_runtime_mode = AIOpponentScript.DECISION_RUNTIME_RULES_ONLY
	return ai


func _exact_selection() -> Dictionary:
	return {
		"package_id": PACKAGE_ID,
		"package_version": PACKAGE_VERSION,
		"archive_sha256": PACKAGE_ARCHIVE_SHA256,
		"install_source": "built_in",
	}


func _cleanup(
	catalog: Variant,
	bridge: Variant,
	gsm: GameStateMachine,
	seed_owner: PlayerState,
	owner: Variant
) -> void:
	if owner != null:
		owner.close_match()
	if bridge != null:
		bridge.free()
	if catalog != null:
		catalog.free()
	seed_owner.clear_forced_shuffle_seed()
	gsm.prepare_for_disposal()


func _failed(seed: int, code: String) -> Dictionary:
	return {
		"document_type": "marnie_public_replay_acceptance_v1",
		"schema_version": 1,
		"is_clean": false,
		"complete_match_finished": false,
		"terminal": false,
		"failure": code,
		"seed": seed,
		"steps": 0,
		"artifact": {},
		"production_ready": false,
		"official_verified": false,
		"online_published": false,
	}
