extends Control

const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")
const HeadlessMatchBridgeScript = preload("res://scripts/ai/HeadlessMatchBridge.gd")
const DeckStrategyRegistryScript = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")
const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const ContractsScript = preload("res://scripts/ai/v18_cpg/schema/V18CPGContracts.gd")
const AuditScript = preload("res://scripts/ai/v18_cpg/audit/V18CPGDecisionAudit.gd")
const BenchmarkDeckSourceScript = preload("res://scripts/ai/v18_cpg/benchmark/V18CPGBenchmarkDeckSource.gd")
const RuleRootFixtureClientScript = preload("res://scripts/tools/v18cpg/V18CPGRuleRootFixtureClient.gd")

const DEFAULT_ANCHOR_ID := 575720
const DEFAULT_SEED_BASE := 181800
const DEFAULT_MAX_STEPS := 220
const DEEPSEEK_DIRECT_ENDPOINT := "https://api.deepseek.com"
const DEEPSEEK_DEFAULT_MODEL := "deepseek-v4-pro"


func _ready() -> void:
	await _run()


func _run() -> void:
	await get_tree().process_frame
	var options := _parse_args(OS.get_cmdline_user_args())
	var deck_ids: Array[int] = []
	var requested_deck := int(options.get("deck_id", 0))
	if requested_deck > 0:
		deck_ids.append(requested_deck)
	else:
		deck_ids = ProfileCatalogScript.PILOT_DECK_IDS.duplicate()
	var api_key := str(options.get("api_key", ""))
	var fake_model_rule_root := bool(options.get("fake_model_rule_root", false))
	var model_enabled := fake_model_rule_root or not bool(options.get("no_model", false)) and api_key != ""
	print("===== V18CPG pilot paired benchmark =====")
	print("decks=%s games_per_deck=%d seed_base=%d model_enabled=%s provider=%s model=%s" % [
		deck_ids,
		int(options.get("games", 1)),
		int(options.get("seed_base", DEFAULT_SEED_BASE)),
		model_enabled,
		str(options.get("provider", "deepseek")),
		str(options.get("model", "")),
	])
	var reports: Array[Dictionary] = []
	for deck_id: int in deck_ids:
		var report := await _run_deck_pair(deck_id, options, model_enabled)
		reports.append(report)
		_print_deck_report(report)
	var combined := {
		"schema_version": 1,
		"architecture": "V18CPG",
		"comparison": "paired_same_seed_vs_rules_only_anchor",
		"anchor_id": int(options.get("anchor_id", DEFAULT_ANCHOR_ID)),
		"games_per_deck": int(options.get("games", 1)),
		"seed_base": int(options.get("seed_base", DEFAULT_SEED_BASE)),
		"provider": "fixture" if fake_model_rule_root else str(options.get("provider", "deepseek")),
		"model": "deterministic_rule_root_fixture" if fake_model_rule_root else str(options.get("model", "")) if model_enabled else "disabled",
		"model_enabled": model_enabled,
		"fake_model_rule_root": fake_model_rule_root,
		"verified_local_only": bool(options.get("verified_local_only", false)),
		"compare_verified_reference": bool(options.get("compare_verified_reference", false)),
		"profile_overrides_enabled": not bool(options.get("ignore_profile_overrides", false)),
		"run_id": str(options.get("run_id", "")),
		"reports": reports,
		"timestamp": Time.get_datetime_string_from_system(),
	}
	var output_path := str(options.get("json_output", ""))
	if output_path != "":
		DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(output_path.get_base_dir())
		)
		var file := FileAccess.open(output_path, FileAccess.WRITE)
		if file != null:
			# Keep benchmark artifacts parseable by Windows tooling regardless of
			# console/code-page handling of localized deck names.
			file.store_string(JSON.stringify(_json_ascii_safe(combined), "\t"))
			file.close()
			print("report=%s" % output_path)
		else:
			push_error("unable to write report: %s" % output_path)
	print("===== benchmark complete =====")
	get_tree().quit(0)


func _run_deck_pair(deck_id: int, options: Dictionary, model_enabled: bool) -> Dictionary:
	var anchor_id := int(options.get("anchor_id", DEFAULT_ANCHOR_ID))
	var deck: DeckData = _load_benchmark_deck(deck_id)
	var anchor: DeckData = _load_benchmark_deck(anchor_id)
	if deck == null or anchor == null:
		return {"deck_id": deck_id, "error": "deck_not_found"}
	var games := int(options.get("games", 1))
	var seed_base := int(options.get("seed_base", DEFAULT_SEED_BASE))
	var rule_wins := 0
	var cpg_wins := 0
	var rule_clean := 0
	var cpg_clean := 0
	var paired_deltas: Array[float] = []
	var per_game: Array[Dictionary] = []
	var aggregate_calls := 0
	var aggregate_accepted := 0
	var aggregate_rejected := 0
	var aggregate_model_owned_action_results := 0
	var aggregate_branch_hits := 0
	var aggregate_uncovered := 0
	var wait_values: Array[float] = []
	var turn_wait_values: Array[float] = []
	var payload_values: Array[float] = []
	var fallback_counts: Dictionary = {}
	var fallback_reason_counts: Dictionary = {}
	var zero_acceptance_reference_checks := 0
	var zero_acceptance_reference_mismatches := 0
	var zero_model_action_reference_checks := 0
	var zero_model_action_reference_mismatches := 0
	for game_index: int in games:
		var seed_value := seed_base + game_index
		var tracked_player := game_index % 2
		var rule_result := await _run_rule_duel(deck, anchor, seed_value, tracked_player, int(options.get("max_steps", DEFAULT_MAX_STEPS)))
		var verified_reference_result: Dictionary = {}
		if model_enabled and bool(options.get("compare_verified_reference", false)):
			var reference_options := options.duplicate(true)
			reference_options["verified_local_only"] = true
			reference_options["run_id"] = "%s_verified_reference" % str(options.get("run_id", "benchmark"))
			var reference_bundle := await _run_cpg_duel(
				deck,
				anchor,
				seed_value,
				tracked_player,
				reference_options,
				false,
				game_index
			)
			verified_reference_result = reference_bundle.get("result", {}) \
				if reference_bundle.get("result", {}) is Dictionary else {}
		var cpg_bundle := await _run_cpg_duel(deck, anchor, seed_value, tracked_player, options, model_enabled, game_index)
		var cpg_result: Dictionary = cpg_bundle.get("result", {})
		var audit: Dictionary = cpg_bundle.get("audit", {})
		var rule_win := int(rule_result.get("winner_index", -1)) == tracked_player
		var cpg_win := int(cpg_result.get("winner_index", -1)) == tracked_player
		if rule_win:
			rule_wins += 1
		if cpg_win:
			cpg_wins += 1
		if _is_clean_result(rule_result):
			rule_clean += 1
		if _is_clean_result(cpg_result):
			cpg_clean += 1
		paired_deltas.append(float(int(cpg_win) - int(rule_win)))
		aggregate_calls += int(audit.get("model_calls", 0))
		aggregate_accepted += int(audit.get("model_accepted", 0))
		aggregate_rejected += int(audit.get("model_rejected", 0))
		aggregate_model_owned_action_results += int(audit.get("model_owned_action_results", 0))
		aggregate_branch_hits += int(audit.get("graph_branch_hits", audit.get("branch_hits", 0)))
		aggregate_uncovered += int(audit.get("uncovered_events", 0))
		_append_float_samples(wait_values, audit.get("visible_wait_samples_ms", []))
		_append_float_samples(turn_wait_values, audit.get("turn_visible_wait_samples_ms", []))
		_append_float_samples(payload_values, audit.get("payload_samples_bytes", []))
		var fallbacks: Variant = audit.get("fallbacks", {})
		if fallbacks is Dictionary:
			for raw_key: Variant in (fallbacks as Dictionary).keys():
				var key := str(raw_key)
				fallback_counts[key] = int(fallback_counts.get(key, 0)) + int((fallbacks as Dictionary).get(raw_key, 0))
		var fallback_reasons: Variant = audit.get("fallback_reasons", {})
		if fallback_reasons is Dictionary:
			for raw_key: Variant in (fallback_reasons as Dictionary).keys():
				var key := str(raw_key)
				fallback_reason_counts[key] = int(fallback_reason_counts.get(key, 0)) + int((fallback_reasons as Dictionary).get(raw_key, 0))
		var zero_acceptance_reference_equal: Variant = null
		var zero_model_action_reference_equal: Variant = null
		if not verified_reference_result.is_empty():
			var check_zero_acceptance := int(audit.get("model_accepted", 0)) == 0
			var check_zero_model_action := AuditScript.should_compare_verified_local_reference(audit)
			if check_zero_acceptance or check_zero_model_action:
				var reference_equal := _decision_logs_equal(cpg_result, verified_reference_result)
				if check_zero_acceptance:
					zero_acceptance_reference_checks += 1
					zero_acceptance_reference_equal = reference_equal
					if not reference_equal:
						zero_acceptance_reference_mismatches += 1
				if check_zero_model_action:
					zero_model_action_reference_checks += 1
					zero_model_action_reference_equal = reference_equal
					if not reference_equal:
						zero_model_action_reference_mismatches += 1
		var game_record := {
			"game": game_index + 1,
			"seed": seed_value,
			"tracked_player": tracked_player,
			"rule": _compact_result(rule_result, tracked_player),
			"v18cpg": _compact_result(cpg_result, tracked_player),
			"paired_delta": int(cpg_win) - int(rule_win),
			"audit": audit,
		}
		if not verified_reference_result.is_empty():
			game_record["verified_local_reference"] = _compact_result(verified_reference_result, tracked_player)
			game_record["zero_acceptance_reference_equal"] = zero_acceptance_reference_equal
			game_record["zero_model_action_reference_equal"] = zero_model_action_reference_equal
		per_game.append(game_record)
		print("  deck=%d game=%d/%d seed=%d rule=%s cpg=%s calls=%d" % [
			deck_id,
			game_index + 1,
			games,
			seed_value,
			"W" if rule_win else "L/D",
			"W" if cpg_win else "L/D",
			int(audit.get("model_calls", 0)),
		])
	var interval := _paired_bootstrap_interval(paired_deltas, seed_base + deck_id)
	var benchmark_profile := ProfileCatalogScript.get_profile_for_deck(
		deck_id,
		not bool(options.get("ignore_profile_overrides", false))
	)
	return {
		"deck_id": deck_id,
		"deck_name": str(benchmark_profile.get("display_name", deck.deck_name)),
		"deck_source": _benchmark_deck_source(deck_id),
		"deck_content_fingerprint": BenchmarkDeckSourceScript.content_fingerprint(deck),
		"anchor_source": _benchmark_deck_source(anchor_id),
		"anchor_content_fingerprint": BenchmarkDeckSourceScript.content_fingerprint(anchor),
		"strategy_id": str(benchmark_profile.get("strategy_id", "")),
		"profile_version": int(benchmark_profile.get("profile_version", 1)),
		"semantic_version": int(benchmark_profile.get("semantic_version", 1)),
		"profile_fingerprint": ContractsScript.stable_hash(benchmark_profile),
		"games": games,
		"rule_wins": rule_wins,
		"rule_win_rate": float(rule_wins) / float(maxi(games, 1)),
		"v18cpg_wins": cpg_wins,
		"v18cpg_win_rate": float(cpg_wins) / float(maxi(games, 1)),
		"paired_improvement": float(cpg_wins - rule_wins) / float(maxi(games, 1)),
		"paired_bootstrap_95": interval,
		"rule_clean_games": rule_clean,
		"v18cpg_clean_games": cpg_clean,
		"model_calls": aggregate_calls,
		"model_accepted": aggregate_accepted,
		"model_rejected": aggregate_rejected,
		"model_owned_action_results": aggregate_model_owned_action_results,
		"model_acceptance_rate": float(aggregate_accepted) / float(maxi(aggregate_calls, 1)),
		"calls_per_game": float(aggregate_calls) / float(maxi(games, 1)),
		"graph_branch_hits": aggregate_branch_hits,
		"uncovered_events": aggregate_uncovered,
		"visible_wait_count": wait_values.size(),
		"visible_wait_p50_ms": _percentile(wait_values, 0.50),
		"visible_wait_p95_ms": _percentile(wait_values, 0.95),
		"turn_visible_wait_p50_ms": _percentile(turn_wait_values, 0.50),
		"turn_visible_wait_p95_ms": _percentile(turn_wait_values, 0.95),
		"payload_p50_bytes": _percentile(payload_values, 0.50),
		"payload_p95_bytes": _percentile(payload_values, 0.95),
		"fallbacks": fallback_counts,
		"fallback_reasons": fallback_reason_counts,
		"zero_acceptance_reference_checks": zero_acceptance_reference_checks,
		"zero_acceptance_reference_mismatches": zero_acceptance_reference_mismatches,
		"zero_model_action_reference_checks": zero_model_action_reference_checks,
		"zero_model_action_reference_mismatches": zero_model_action_reference_mismatches,
		"per_game": per_game,
	}


func _load_benchmark_deck(deck_id: int) -> DeckData:
	var card_database := get_tree().root.get_node_or_null("CardDatabase")
	if card_database == null:
		push_error("V18CPG benchmark: CardDatabase autoload unavailable")
		return null
	return BenchmarkDeckSourceScript.load_deck(card_database, deck_id)


func _benchmark_deck_source(deck_id: int) -> String:
	var card_database := get_tree().root.get_node_or_null("CardDatabase")
	if card_database == null:
		return "unavailable"
	return BenchmarkDeckSourceScript.source_kind(card_database, deck_id)


func _run_rule_duel(deck: DeckData, anchor: DeckData, seed_value: int, tracked_player: int, max_steps: int) -> Dictionary:
	var gsm := _start_game(deck, anchor, seed_value, tracked_player)
	var p0_deck := deck if tracked_player == 0 else anchor
	var p1_deck := anchor if tracked_player == 0 else deck
	var p0_ai := _make_rule_ai(0, p0_deck)
	var p1_ai := _make_rule_ai(1, p1_deck)
	# Use the identical event loop for both arms.  Comparing the synchronous
	# benchmark runner against the model-aware loop changes interaction timing
	# and is not a valid paired A/B even when the model is disabled.
	var result := await _run_async_duel(
		p0_ai,
		p1_ai,
		gsm,
		max_steps,
		0.0,
		"rule_floor_%d" % seed_value,
		"%d" % int(deck.id)
	)
	PlayerState.new().clear_forced_shuffle_seed()
	return result


func _run_cpg_duel(
	deck: DeckData,
	anchor: DeckData,
	seed_value: int,
	tracked_player: int,
	options: Dictionary,
	model_enabled: bool,
	game_index: int
) -> Dictionary:
	var gsm := _start_game(deck, anchor, seed_value, tracked_player)
	var p0_deck := deck if tracked_player == 0 else anchor
	var p1_deck := anchor if tracked_player == 0 else deck
	var p0_ai := _make_rule_ai(0, p0_deck)
	var p1_ai := _make_rule_ai(1, p1_deck)
	var cpg_strategy := StrategyScript.new()
	var profile := ProfileCatalogScript.get_profile_for_deck(
		int(deck.id),
		not bool(options.get("ignore_profile_overrides", false))
	)
	if bool(options.get("fake_model_rule_root", false)):
		profile = profile.duplicate(true)
		profile["expected_regret_threshold"] = -1.0
		var route_preferences: Dictionary = profile.get("route_preferences", {}) \
			if profile.get("route_preferences", {}) is Dictionary else {}
		route_preferences = route_preferences.duplicate(true)
		route_preferences["model_consideration_margin"] = 1000000.0
		profile["route_preferences"] = route_preferences
	cpg_strategy.configure_profile(profile)
	cpg_strategy.configure_from_deck(deck)
	var run_id := str(options.get("run_id", "")).strip_edges()
	if run_id == "":
		run_id = "benchmark_%d" % int(options.get("seed_base", DEFAULT_SEED_BASE))
	var match_id := "%d_%d" % [int(deck.id), game_index + 1]
	cpg_strategy.configure_audit(run_id, match_id, bool(options.get("write_audit", false)))
	if model_enabled:
		if bool(options.get("fake_model_rule_root", false)):
			cpg_strategy.set("_decision_client", RuleRootFixtureClientScript.new())
		cpg_strategy.configure_runtime(self, {
			"endpoint": "fixture://rule-root" if bool(options.get("fake_model_rule_root", false)) else str(options.get("endpoint", "")),
			"api_key": "fixture" if bool(options.get("fake_model_rule_root", false)) else str(options.get("api_key", "")),
			"model": "deterministic-rule-root" if bool(options.get("fake_model_rule_root", false)) else str(options.get("model", "")),
			"timeout_seconds": float(options.get("timeout_seconds", 30.0)),
			# The V18-only transport overrides the fallback filename generator so
			# proxy support cannot consume the process-wide gameplay RNG.
			"allow_python_fallback": true,
			"allow_unsafe_tls": true,
		})
	elif bool(options.get("verified_local_only", false)):
		cpg_strategy.configure_verified_local_only_for_benchmark()
	var tested_ai: AIOpponent = p0_ai if tracked_player == 0 else p1_ai
	tested_ai.set_deck_strategy(cpg_strategy)
	tested_ai.decision_runtime_mode = AIOpponentScript.DECISION_RUNTIME_RULES_ONLY
	var result := await _run_async_duel(
		p0_ai,
		p1_ai,
		gsm,
		int(options.get("max_steps", DEFAULT_MAX_STEPS)),
		float(options.get("wait_budget_seconds", 35.0)),
		run_id,
		match_id
	)
	PlayerState.new().clear_forced_shuffle_seed()
	return {"result": result, "audit": cpg_strategy.get_audit_summary()}


func _run_async_duel(
	player_0_ai: AIOpponent,
	player_1_ai: AIOpponent,
	gsm: GameStateMachine,
	max_steps: int,
	wait_budget_seconds: float,
	run_id: String,
	match_id: String
) -> Dictionary:
	var bridge := HeadlessMatchBridgeScript.new()
	bridge.bind(gsm)
	bridge.set_ai_controllers(player_0_ai, player_1_ai)
	bridge.bootstrap_pending_setup()
	var steps := 0
	var failure_reason := ""
	var stalled := false
	var decision_log: Array[Dictionary] = []
	while steps < max_steps:
		if gsm.game_state.is_game_over():
			break
		var progressed := false
		if bridge.has_pending_prompt():
			if bridge.can_resolve_pending_prompt():
				progressed = bridge.resolve_pending_prompt()
				if not progressed:
					failure_reason = "invalid_state_transition"
					break
			else:
				var pending_choice := bridge.get_pending_prompt_type()
				if pending_choice not in ["effect_interaction", "heavy_baton_target", "exp_share_target", "send_out"]:
					failure_reason = "unsupported_prompt"
					break
				var owner := bridge.get_pending_prompt_owner()
				var prompt_ai := player_0_ai if owner == 0 else player_1_ai if owner == 1 else null
				if prompt_ai == null:
					failure_reason = "unsupported_prompt"
					break
				if pending_choice == "send_out":
					progressed = bool(prompt_ai.call("_run_send_out_step", bridge, gsm))
				else:
					progressed = prompt_ai.run_single_step(bridge, gsm)
				_append_decision_trace(decision_log, prompt_ai)
				if not progressed:
					failure_reason = "unsupported_interaction_step" if pending_choice == "effect_interaction" else "unsupported_prompt"
					break
		else:
			if gsm.game_state.phase == GameState.GamePhase.MAIN and gsm.has_method("_resolve_mid_turn_knockouts") and bool(gsm.call("_resolve_mid_turn_knockouts")):
				progressed = true
			else:
				var current_player := int(gsm.game_state.current_player_index)
				var current_ai := player_0_ai if current_player == 0 else player_1_ai if current_player == 1 else null
				if current_ai == null:
					failure_reason = "invalid_state_transition"
					break
				var strategy: Variant = current_ai.get("_deck_strategy")
				if strategy is RefCounted and (strategy as RefCounted).has_method("prepare_decision"):
					var legal_actions := current_ai.get_legal_actions(gsm)
					var rule_floor_certificate: Dictionary = current_ai.build_rule_floor_certificate(gsm, legal_actions) \
						if current_ai.has_method("build_rule_floor_certificate") else {}
					var planning_context := {
						"run_id": run_id,
						"match_id": match_id,
						"rule_floor_action_id": str(rule_floor_certificate.get("action_id", "")),
						"rule_floor_certificate": rule_floor_certificate,
					}
					var preparation: Dictionary = (strategy as RefCounted).call("prepare_decision", gsm.game_state, current_player, legal_actions, planning_context)
					if str(preparation.get("status", "")) == "pending":
						await _wait_for_strategy(strategy as RefCounted, wait_budget_seconds)
						legal_actions = current_ai.get_legal_actions(gsm)
						(strategy as RefCounted).call("prepare_decision", gsm.game_state, current_player, legal_actions, planning_context)
				progressed = current_ai.run_single_step(bridge, gsm)
				_append_decision_trace(decision_log, current_ai)
				if not progressed \
						and strategy is RefCounted \
						and (strategy as RefCounted).has_method("has_pending_request") \
						and bool((strategy as RefCounted).call("has_pending_request")):
					await _wait_for_strategy(strategy as RefCounted, wait_budget_seconds)
					# Pending is a wait state, never an implicit end-turn action. The
					# next loop iteration rebuilds the exact legal action certificate.
					progressed = true
				if not progressed and gsm.game_state != null and gsm.game_state.phase == GameState.GamePhase.MAIN:
					gsm.end_turn(current_player)
					progressed = true
				if not progressed:
					failure_reason = "stalled_no_progress"
					stalled = true
					break
		steps += 1
	var terminated_by_cap := steps >= max_steps and not gsm.game_state.is_game_over()
	if terminated_by_cap and failure_reason == "":
		failure_reason = "action_cap_reached"
	if gsm.game_state.is_game_over() and failure_reason == "":
		failure_reason = "normal_game_end" if str(gsm.game_state.win_reason) != "deck_out" else "deck_out"
	var result := {
		"winner_index": int(gsm.game_state.winner_index),
		"turn_count": int(gsm.game_state.turn_number),
		"steps": steps,
		"failure_reason": failure_reason,
		"stalled": stalled,
		"terminated_by_cap": terminated_by_cap,
		"decision_log": decision_log,
	}
	# A paired benchmark may run hundreds of duels in one process. Break the
	# signal/reference chain explicitly after snapshotting the result; otherwise
	# old GameState/EffectProcessor graphs accumulate and the process can be
	# terminated before it writes an acceptance artifact.
	bridge.bind(null)
	bridge.set_ai_controllers(null, null)
	bridge.free()
	gsm.prepare_for_disposal()
	return result


func _append_decision_trace(log: Array[Dictionary], ai: AIOpponent) -> void:
	if ai == null or not ai.has_method("consume_last_decision_trace"):
		return
	var trace: Variant = ai.call("consume_last_decision_trace")
	if trace == null or not trace.has_method("to_dictionary"):
		return
	var snapshot: Dictionary = trace.call("to_dictionary")
	var chosen: Dictionary = snapshot.get("chosen_action", {}) if snapshot.get("chosen_action", {}) is Dictionary else {}
	var card: Dictionary = chosen.get("card", {}) if chosen.get("card", {}) is Dictionary else {}
	var source: Dictionary = chosen.get("source_slot", {}) if chosen.get("source_slot", {}) is Dictionary else {}
	var target: Dictionary = chosen.get("target_slot", chosen.get("bench_target", {})) if chosen.get("target_slot", chosen.get("bench_target", {})) is Dictionary else {}
	log.append({
		"turn": int(snapshot.get("turn_number", -1)),
		"player": int(snapshot.get("player_index", -1)),
		"kind": str(chosen.get("kind", "")),
		"card": str(card.get("name_en", card.get("name", ""))),
		"source": str(source.get("name_en", source.get("name", ""))),
		"target": str(target.get("name_en", target.get("name", ""))),
		"attack_index": int(chosen.get("attack_index", -1)),
		"ability_index": int(chosen.get("ability_index", -1)),
		"score": float(chosen.get("score", 0.0)),
	})


func _wait_for_strategy(strategy: RefCounted, budget_seconds: float) -> void:
	var started := Time.get_ticks_msec()
	while bool(strategy.call("has_pending_request")):
		if strategy.has_method("enforce_visible_wait_deadline") \
				and bool(strategy.call("enforce_visible_wait_deadline")):
			break
		if float(Time.get_ticks_msec() - started) / 1000.0 >= budget_seconds:
			strategy.call("force_deadline_fallback")
			break
		await get_tree().process_frame


func _start_game(deck: DeckData, anchor: DeckData, seed_value: int, tracked_player: int) -> GameStateMachine:
	var gsm := GameStateMachine.new()
	if gsm.coin_flipper != null:
		var rng: Variant = gsm.coin_flipper.get("_rng")
		if rng is RandomNumberGenerator:
			(rng as RandomNumberGenerator).seed = seed_value
	PlayerState.new().set_forced_shuffle_seed(seed_value)
	var p0_deck := deck if tracked_player == 0 else anchor
	var p1_deck := anchor if tracked_player == 0 else deck
	gsm.start_game(p0_deck, p1_deck, 0)
	return gsm


func _make_rule_ai(player_index: int, deck: DeckData) -> AIOpponent:
	var ai := AIOpponentScript.new()
	ai.configure(player_index, 1)
	ai.decision_runtime_mode = AIOpponentScript.DECISION_RUNTIME_RULES_ONLY
	var registry := DeckStrategyRegistryScript.new()
	registry.apply_strategy_for_deck(ai, deck)
	return ai


func _is_clean_result(result: Dictionary) -> bool:
	return str(result.get("failure_reason", "")) in ["normal_game_end", "deck_out"] \
		and not bool(result.get("stalled", false)) \
		and not bool(result.get("terminated_by_cap", false))


func _compact_result(result: Dictionary, tracked_player: int) -> Dictionary:
	var winner := int(result.get("winner_index", -1))
	return {
		"outcome": "win" if winner == tracked_player else "loss" if winner >= 0 else "draw",
		"winner_index": winner,
		"turns": int(result.get("turn_count", 0)),
		"steps": int(result.get("steps", 0)),
		"failure_reason": str(result.get("failure_reason", "")),
		"stalled": bool(result.get("stalled", false)),
		"terminated_by_cap": bool(result.get("terminated_by_cap", false)),
		"decision_log": result.get("decision_log", []),
	}


func _paired_bootstrap_interval(values: Array[float], seed_value: int) -> Array[float]:
	if values.is_empty():
		return [0.0, 0.0]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var samples: Array[float] = []
	for _iteration: int in 2000:
		var total := 0.0
		for _index: int in values.size():
			total += values[rng.randi_range(0, values.size() - 1)]
		samples.append(total / float(values.size()))
	samples.sort()
	return [samples[int(0.025 * float(samples.size() - 1))], samples[int(0.975 * float(samples.size() - 1))]]


func _median(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[sorted.size() / 2]


func _percentile(values: Array[float], quantile: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	var index := clampi(int(ceil(quantile * float(sorted.size()))) - 1, 0, sorted.size() - 1)
	return sorted[index]


func _append_float_samples(target: Array[float], samples: Variant) -> void:
	if not (samples is Array):
		return
	for sample: Variant in samples as Array:
		target.append(float(sample))


func _json_ascii_safe(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		for raw_key: Variant in (value as Dictionary).keys():
			result[_ascii_safe_string(str(raw_key))] = _json_ascii_safe((value as Dictionary).get(raw_key))
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value as Array:
			result.append(_json_ascii_safe(item))
		return result
	if value is String:
		return _ascii_safe_string(value as String)
	return value


func _ascii_safe_string(value: String) -> String:
	var result := ""
	for index: int in value.length():
		var codepoint := value.unicode_at(index)
		result += String.chr(codepoint) if codepoint >= 32 and codepoint <= 126 else "?"
	return result


func _print_deck_report(report: Dictionary) -> void:
	if report.has("error"):
		print("deck %d ERROR %s" % [int(report.get("deck_id", 0)), str(report.get("error", ""))])
		return
	print("deck=%s rule=%.1f%% v18cpg=%.1f%% delta=%+.1fpp clean=%d/%d calls=%d wait_p95=%.0fms" % [
		str(report.get("deck_name", report.get("deck_id", 0))),
		float(report.get("rule_win_rate", 0.0)) * 100.0,
		float(report.get("v18cpg_win_rate", 0.0)) * 100.0,
		float(report.get("paired_improvement", 0.0)) * 100.0,
		int(report.get("v18cpg_clean_games", 0)),
		int(report.get("games", 0)),
		int(report.get("model_calls", 0)),
		float(report.get("visible_wait_p95_ms", 0.0)),
	])


func _parse_args(args: PackedStringArray) -> Dictionary:
	var saved_config := _saved_battle_review_api_config()
	var direct_config := _resolve_deepseek_direct_config(saved_config, {
		"DEEPSEEK_API_KEY": OS.get_environment("DEEPSEEK_API_KEY"),
		"V18CPG_MODEL": OS.get_environment("V18CPG_MODEL"),
	})
	var options := {
		"deck_id": 0,
		"anchor_id": DEFAULT_ANCHOR_ID,
		"games": 1,
		"seed_base": DEFAULT_SEED_BASE,
		"max_steps": DEFAULT_MAX_STEPS,
		"json_output": "",
		"provider": "deepseek",
		"endpoint": str(direct_config.get("endpoint", DEEPSEEK_DIRECT_ENDPOINT)),
		"api_key": str(direct_config.get("api_key", "")),
		"model": str(direct_config.get("model", DEEPSEEK_DEFAULT_MODEL)),
		"timeout_seconds": float(direct_config.get("timeout_seconds", 60.0)),
		"wait_budget_seconds": 35.0,
		"no_model": false,
		"write_audit": false,
		"verified_local_only": false,
		"compare_verified_reference": false,
		"fake_model_rule_root": false,
		"ignore_profile_overrides": false,
		"run_id": "",
	}
	for arg: String in args:
		if arg.begins_with("--deck-id="):
			options["deck_id"] = int(arg.get_slice("=", 1))
		elif arg.begins_with("--anchor-id="):
			options["anchor_id"] = int(arg.get_slice("=", 1))
		elif arg.begins_with("--games="):
			options["games"] = maxi(1, int(arg.get_slice("=", 1)))
		elif arg.begins_with("--seed-base="):
			options["seed_base"] = int(arg.get_slice("=", 1))
		elif arg.begins_with("--max-steps="):
			options["max_steps"] = maxi(1, int(arg.get_slice("=", 1)))
		elif arg.begins_with("--json-output="):
			options["json_output"] = arg.get_slice("=", 1)
		elif arg.begins_with("--run-id="):
			options["run_id"] = arg.get_slice("=", 1)
		elif arg.begins_with("--endpoint="):
			options["endpoint"] = arg.get_slice("=", 1)
		elif arg.begins_with("--model="):
			options["model"] = arg.get_slice("=", 1)
		elif arg.begins_with("--timeout-seconds="):
			options["timeout_seconds"] = maxf(1.0, float(arg.get_slice("=", 1)))
		elif arg.begins_with("--wait-budget-seconds="):
			options["wait_budget_seconds"] = maxf(1.0, float(arg.get_slice("=", 1)))
		elif arg == "--no-model":
			options["no_model"] = true
		elif arg == "--verified-local-only":
			options["no_model"] = true
			options["verified_local_only"] = true
		elif arg == "--write-audit":
			options["write_audit"] = true
		elif arg == "--compare-verified-reference":
			options["compare_verified_reference"] = true
		elif arg == "--fake-model-rule-root":
			options["fake_model_rule_root"] = true
		elif arg == "--ignore-profile-overrides":
			options["ignore_profile_overrides"] = true
	return options


func _saved_battle_review_api_config() -> Dictionary:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return {}
	var manager := tree.root.get_node_or_null("GameManager")
	if manager == null or not manager.has_method("get_battle_review_api_config"):
		return {}
	var config: Variant = manager.call("get_battle_review_api_config")
	return (config as Dictionary).duplicate(true) if config is Dictionary else {}


func _resolve_deepseek_direct_config(
	saved_config: Dictionary,
	environment: Dictionary
) -> Dictionary:
	var provider := str(saved_config.get("provider", "")).strip_edges().to_lower()
	var provider_configs: Dictionary = saved_config.get("provider_configs", {}) \
		if saved_config.get("provider_configs", {}) is Dictionary else {}
	var saved_deepseek: Dictionary = provider_configs.get("deepseek", {}) \
		if provider_configs.get("deepseek", {}) is Dictionary else {}
	var saved_key := str(saved_deepseek.get("api_key", "")).strip_edges()
	var saved_model := str(saved_deepseek.get("model", "")).strip_edges()
	if provider == "deepseek":
		var active_key := str(saved_config.get("api_key", "")).strip_edges()
		var active_model := str(saved_config.get("model", "")).strip_edges()
		if active_key != "":
			saved_key = active_key
		if active_model != "":
			saved_model = active_model
	var environment_key := str(environment.get("DEEPSEEK_API_KEY", "")).strip_edges()
	var environment_model := str(environment.get("V18CPG_MODEL", "")).strip_edges()
	return {
		# The pilot is a DeepSeek benchmark. Never inherit a ZenMux endpoint or
		# credential merely because another provider is active in shared settings.
		"provider": "deepseek",
		"endpoint": DEEPSEEK_DIRECT_ENDPOINT,
		"api_key": environment_key if environment_key != "" else saved_key,
		"model": environment_model if environment_model != "" \
			else saved_model if saved_model in ["deepseek-v4-flash", "deepseek-v4-pro"] \
			else DEEPSEEK_DEFAULT_MODEL,
		"timeout_seconds": maxf(1.0, float(saved_config.get("timeout_seconds", 60.0))),
	}


func _decision_logs_equal(left: Dictionary, right: Dictionary) -> bool:
	var left_log: Variant = left.get("decision_log", [])
	var right_log: Variant = right.get("decision_log", [])
	return JSON.stringify(left_log) == JSON.stringify(right_log)
