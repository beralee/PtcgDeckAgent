extends SceneTree

const AuditScript = preload("res://scripts/ai/v18_cpg/audit/V18CPGDecisionAudit.gd")
const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")

var _failures: Array[String] = []


class DecisionProbe:
	extends RefCounted

	var request_count := 0
	var request_turns: Array[int] = []
	var max_policy_nodes: Array[int] = []

	func request_policy(
		_request_id: String,
		request_envelope: Dictionary,
		_token_budget: int = 600,
		_is_delta: bool = false
	) -> int:
		request_count += 1
		request_turns.append(int(request_envelope.get("lifecycle", {}).get("turn_id", -1)))
		max_policy_nodes.append(int(request_envelope.get("limits", {}).get("max_policy_nodes", -1)))
		return OK


class FailingDecisionProbe:
	extends RefCounted

	func request_policy(
		_request_id: String,
		_request_envelope: Dictionary,
		_token_budget: int = 600,
		_is_delta: bool = false
	) -> int:
		return ERR_UNCONFIGURED


func _initialize() -> void:
	_test_only_released_decks_require_turn_judgment()
	_test_proven_terminal_skips_zero_value_request_but_resolves_judgment()
	_test_request_start_failure_resolves_required_judgment()
	_test_audit_reports_exact_turn_judgment_coverage()
	if _failures.is_empty():
		print("V18CPG released turn judgment contract: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _test_only_released_decks_require_turn_judgment() -> void:
	for deck_id: int in ProfileCatalogScript.ALL_DECK_IDS:
		var profile := ProfileCatalogScript.get_profile_for_deck(deck_id)
		var required := str(profile.get("turn_model_judgment_mode", "")) == "required_first_main_window"
		_check(
			required,
			"%d must inherit the batch V18CPG per-turn judgment contract" % deck_id
		)


func _test_proven_terminal_skips_zero_value_request_but_resolves_judgment() -> void:
	for deck_id: int in ProfileCatalogScript.ALL_DECK_IDS:
		var state := _minimal_main_state(5)
		var strategy := StrategyScript.new()
		var profile := ProfileCatalogScript.get_profile_for_deck(deck_id)
		var expected_max_nodes := int(profile.get("max_policy_nodes", 8))
		strategy.configure_profile(profile)
		strategy.configure_verified_local_only_for_benchmark()
		strategy.configure_audit("released-turn-judgment", "deck-%d" % deck_id, false)
		var probe := DecisionProbe.new()
		strategy.set("_decision_client", probe)
		var end_turn := {"id": "action:end", "kind": "end_turn"}
		var first: Dictionary = strategy.prepare_decision(
			state,
			0,
			[end_turn],
			{"event_type": "MAIN_ACTION_WINDOW", "rule_floor_action_id": "action:end"}
		)
		_check(
			str(first.get("status", "")) == "ready"
				and probe.request_count == 0
				and bool(strategy.get("_turn_model_judgment_attempted"))
				and bool(strategy.get("_turn_model_judgment_resolved")),
			"%d must skip a zero-value request when the full legal pool proves one terminal Rule action"
				% deck_id
		)
		var repeated: Dictionary = strategy.prepare_decision(
			state,
			0,
			[end_turn],
			{"event_type": "MAIN_ACTION_WINDOW", "rule_floor_action_id": "action:end"}
		)
		_check(
			str(repeated.get("status", "")) == "ready" and probe.request_count == 0,
			"%d must not reconsider a deterministically resolved skip in the same turn"
				% deck_id
		)
		_check(expected_max_nodes > 0, "%d must expose a positive graph node budget" % deck_id)
	_test_shared_runtime_requests_after_a_strategic_alternative()


func _test_shared_runtime_requests_after_a_strategic_alternative() -> void:
	var state := _minimal_main_state(7)
	var strategy := StrategyScript.new()
	var profile := ProfileCatalogScript.get_profile_for_deck(800018509)
	strategy.configure_profile(profile)
	strategy.configure_verified_local_only_for_benchmark()
	var probe := DecisionProbe.new()
	strategy.set("_decision_client", probe)
	var result: Dictionary = strategy.prepare_decision(
		state,
		0,
		[
			{"id": "action:develop", "kind": "play_basic_to_bench"},
			{"id": "action:end", "kind": "end_turn"},
		],
		{"event_type": "MAIN_ACTION_WINDOW", "rule_floor_action_id": "action:end"}
	)
	_check(
		str(result.get("status", "")) == "pending" \
			and probe.request_count == 1 \
			and probe.request_turns == [7] \
			and probe.max_policy_nodes == [int(profile.get("max_policy_nodes", 8))],
		"the shared batch runtime must request exactly one judgment for a strategic alternative"
	)


func _test_audit_reports_exact_turn_judgment_coverage() -> void:
	var audit := AuditScript.new()
	audit.configure("released-turn-judgment", "coverage", false)
	for turn_id: int in [3, 5, 7]:
		audit.record({
			"event_type": "turn_model_judgment_opened",
			"turn_id": turn_id,
			"turn_model_judgment_required": true,
		})
	for turn_id: int in [3]:
		audit.record({
			"event_type": "turn_model_judgment_requested",
			"turn_id": turn_id,
			"turn_model_judgment_required": true,
		})
	audit.record({
		"event_type": "policy_response",
		"turn_id": 3,
		"accepted": false,
		"turn_model_judgment": true,
	})
	audit.record({
		"event_type": "turn_model_judgment_skipped",
		"turn_id": 5,
		"turn_model_judgment": true,
		"fallback_reason": "provably_terminal_no_admissible_switch",
	})
	var summary := audit.summary()
	_check(
		int(summary.get("turn_model_judgment_required_turns", 0)) == 3,
		"audit must expose the exact required-turn denominator"
	)
	_check(
		int(summary.get("turn_model_judgment_requested_turns", 0)) == 1,
		"audit must distinguish requested judgments from required turns"
	)
	_check(
		int(summary.get("turn_model_judgment_resolved_turns", 0)) == 2,
		"audit must count rejected responses and proven zero-value skips as resolved judgments"
	)
	_check(
		summary.get("turn_model_judgment_missing_request_turn_ids", []) == [7] \
			and summary.get("turn_model_judgment_unresolved_turn_ids", []) == [7],
		"audit must identify missing and unresolved turns without hiding failures in a rate"
	)


func _test_request_start_failure_resolves_required_judgment() -> void:
	var state := _minimal_main_state(5)
	var strategy := StrategyScript.new()
	strategy.configure_profile(
		ProfileCatalogScript.get_profile_for_deck(800018509)
	)
	strategy.configure_verified_local_only_for_benchmark()
	strategy.set("_decision_client", FailingDecisionProbe.new())
	var result: Dictionary = strategy.prepare_decision(
		state,
		0,
		[{"id": "action:end", "kind": "end_turn"}],
		{
			"event_type": "MAIN_ACTION_WINDOW",
			"rule_floor_action_id": "action:end",
		}
	)
	_check(
		str(result.get("status", "")) == "ready"
			and bool(strategy.get("_turn_model_judgment_attempted"))
			and bool(strategy.get("_turn_model_judgment_resolved")),
		"a required judgment whose request cannot start must resolve as a failed judgment so deterministic continuation matches a rejected live response"
	)


func _minimal_main_state(turn_number: int) -> GameState:
	var state := GameState.new()
	state.turn_number = turn_number
	state.current_player_index = 0
	state.first_player_index = 1
	state.phase = GameState.GamePhase.MAIN
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	state.players = [player, opponent]
	return state


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
