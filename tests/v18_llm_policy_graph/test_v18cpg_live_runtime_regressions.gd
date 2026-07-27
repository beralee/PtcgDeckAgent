extends SceneTree

const ObservationGatewayScript = preload(
	"res://scripts/ai/v18_cpg/observation/V18CPGObservationGateway.gd"
)
const FactBuilderScript = preload(
	"res://scripts/ai/v18_cpg/planning/V18CPGFactBuilder.gd"
)
const HardGuardScript = preload(
	"res://scripts/ai/v18_cpg/planning/V18CPGHardGuard.gd"
)
const ProfileCatalogScript = preload(
	"res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd"
)
const DecisionClientScript = preload(
	"res://scripts/ai/v18_cpg/network/V18CPGDecisionClient.gd"
)
const StrategyScript = preload(
	"res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd"
)

const RAGING_BOLT_DECK_ID := 800018509
const RAGING_BOLT_UID := "CSV7C_154"

var _failures: Array[String] = []


class RuleScoreProbe:
	extends RefCounted

	func score_action(
		_action: Dictionary,
		_game_state: GameState,
		_player_index: int,
		_turn_plan: Dictionary = {}
	) -> float:
		return 999.0

	func build_turn_plan(
		_game_state: GameState,
		_player_index: int,
		_context: Dictionary = {}
	) -> Dictionary:
		return {}


func _initialize() -> void:
	_test_identical_public_state_keeps_one_observation_epoch()
	_test_raging_bolt_variable_damage_reaches_base_facts()
	_test_payable_ko_gust_guard_applies_before_owner_selection()
	_test_hard_block_survives_every_runtime_owner()
	_test_stadium_quota_is_engine_legality()
	_test_prompt_keeps_bounded_productive_graphs()
	_test_action_owner_is_frozen_before_synchronous_execution()
	_test_model_branch_owner_survives_same_observation_reentry()
	if _failures.is_empty():
		print("V18CPG live runtime regressions: PASS (8/8)")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("V18CPG live runtime regressions: FAIL (%d)" % _failures.size())
	quit(1)


func _test_identical_public_state_keeps_one_observation_epoch() -> void:
	var state := _state()
	var gateway := ObservationGatewayScript.new()
	var first: Dictionary = gateway.build(
		state,
		0,
		[{"kind": "end_turn"}]
	)
	var repeated: Dictionary = gateway.build(
		state,
		0,
		[{"kind": "end_turn"}]
	)
	_check(
		str(first.get("observation_hash", "")) \
				== str(repeated.get("observation_hash", ""))
			and int(first.get("observation_version", -1)) \
				== int(repeated.get("observation_version", -2)),
		"recapturing an identical public state must not mint a new response epoch"
	)
	state.energy_attached_this_turn = true
	var changed: Dictionary = gateway.build(
		state,
		0,
		[{"kind": "end_turn"}]
	)
	_check(
		str(changed.get("observation_hash", "")) \
				!= str(repeated.get("observation_hash", ""))
			and int(changed.get("observation_version", 0)) \
				== int(repeated.get("observation_version", 0)) + 1,
		"a material public-state change must advance the observation epoch exactly once"
	)


func _test_raging_bolt_variable_damage_reaches_base_facts() -> void:
	var profile := ProfileCatalogScript.get_profile_for_deck(
		RAGING_BOLT_DECK_ID
	)
	var observation := {
		"turn": {
			"deterministic_attack_window_open": true,
			"quotas": {
				"energy_available": true,
				"supporter_available": true,
			},
		},
		"own": {
			"active": _slot(
				"slot:bolt",
				RAGING_BOLT_UID,
				[_energy("L"), _energy("F")]
			),
			"bench": [
				_slot("slot:bank", "ENERGY_BANK", [_energy("G")]),
			],
			"hand": [],
			"hand_count": 0,
			"deck_count": 20,
			"prizes_remaining": 6,
		},
		"opponent": {
			"active": _slot("slot:target", "TARGET", [], 210, 2),
			"bench": [],
		},
		"legal_actions": [{
			"id": "attack:raging-bolt-variable",
			"kind": "attack",
			"source": "slot:bolt",
			"source_card": {"uid": RAGING_BOLT_UID},
			"attack_index": 1,
			# The production engine action intentionally omits projected_damage
			# for discard-scaled attacks. The base fact layer must recover it.
			"requires_interaction": true,
		}],
	}
	var facts: Dictionary = FactBuilderScript.new().build(
		observation,
		"",
		profile
	)
	_check(
		bool(facts.get("attack", {}).get("ready", false))
			and int(facts.get("attack", {}).get("max_damage", 0)) == 210
			and bool(facts.get("attack", {}).get("ko_available", false))
			and int(facts.get("resources", {}).get("energy_on_board", 0)) == 3,
		"Raging Bolt's public 70-per-Energy damage must populate max_damage and KO facts even when the legal action omits projected_damage"
	)


func _test_payable_ko_gust_guard_applies_before_owner_selection() -> void:
	var profile := ProfileCatalogScript.get_profile_for_deck(
		RAGING_BOLT_DECK_ID
	)
	var gust := {
		"candidate_id": "candidate:gust",
		"route_id": "route:gust",
		"action_kind": "play_trainer",
		"safe_prefix_action_id": "action:gust",
		"action_ref": {
			"id": "action:gust",
			"kind": "play_trainer",
			"requires_interaction": true,
		},
		"module_annotations": {
			"energy_burst": {
				"ko_payable_with_reserve": false,
				"route_warning": "gust_target_unresolved",
			},
		},
	}
	var end_turn := {
		"candidate_id": "candidate:end",
		"route_id": "route:end_turn",
		"action_kind": "end_turn",
		"safe_prefix_action_id": "action:end",
		"action_ref": {"id": "action:end", "kind": "end_turn"},
	}
	var observation := {
		"turn": {"quotas": {"stadium_available": true}},
		"opponent": {
			"active": _slot("slot:active", "ACTIVE", [], 220, 2),
			"bench": [_slot("slot:bench", "BENCH", [], 30, 1)],
		},
	}
	var blocked: Dictionary = HardGuardScript.new().filter_candidates(
		[gust, end_turn],
		observation,
		{
			"attack": {"ready": false, "max_damage": 0},
			"prize": {"win_now": false},
		},
		profile
	)
	_check(
		(blocked.get("candidates", []) as Array).size() == 1
			and str((blocked.get("candidates", []) as Array)[0].get(
				"candidate_id",
				""
			)) == "candidate:end"
			and blocked.get("blocked_action_ids", {}).has("action:gust"),
		"all V18 owners must lose access to a gust root when no same-window KO is publicly payable"
	)
	var allowed: Dictionary = HardGuardScript.new().filter_candidates(
		[gust, end_turn],
		observation,
		{
			"attack": {"ready": true, "max_damage": 210},
			"prize": {"win_now": false},
		},
		profile
	)
	_check(
		(allowed.get("candidates", []) as Array).size() == 2,
		"the gust guard must keep a publicly payable same-window KO target legal"
	)


func _test_hard_block_survives_every_runtime_owner() -> void:
	var action := {"kind": "play_trainer", "requires_interaction": true}
	var action_id := ObservationGatewayScript.new().stable_action_id(action)
	var strategy = StrategyScript.new()
	strategy.configure_profile(
		ProfileCatalogScript.get_profile_for_deck(RAGING_BOLT_DECK_ID),
		{}
	)
	strategy.configure_verified_local_only_for_benchmark()
	strategy.set("_rules_fallback", RuleScoreProbe.new())
	strategy.set(
		"_hard_blocked_action_ids",
		{action_id: "gust_without_publicly_payable_ko"}
	)
	for owner: String in [
		"local_gate",
		"deadline_fallback",
		"schema_fallback",
		"rules_fallback",
		"model_selected_local_route",
		"policy_graph_branch",
	]:
		strategy.set("_current_action_owner", owner)
		_check(
			strategy.score_action_absolute_with_plan(
				action,
				_state(),
				0,
				{}
			) < -100000000000.0,
			"hard-blocked actions must remain unavailable for owner=%s" % owner
		)
	var no_model = StrategyScript.new()
	no_model.configure_profile(
		ProfileCatalogScript.get_profile_for_deck(RAGING_BOLT_DECK_ID),
		{}
	)
	no_model.set("_rules_fallback", RuleScoreProbe.new())
	no_model.set(
		"_hard_blocked_action_ids",
		{action_id: "gust_without_publicly_payable_ko"}
	)
	_check(
		is_equal_approx(
			no_model.score_action_absolute_with_plan(action, _state(), 0, {}),
			999.0
		),
		"no-model V18 mode must retain exact Rule-floor scoring"
	)


func _test_stadium_quota_is_engine_legality() -> void:
	var state := _state()
	state.stadium_played_this_turn = true
	state.stadium_card = _stadium("Cycling Road", 0)
	var replacement := _stadium("Collapsed Stadium", 0)
	var reason := RuleValidator.new().get_play_stadium_unusable_reason(
		state,
		0,
		replacement
	)
	_check(
		reason != "",
		"the engine must reject a second Stadium in the same turn even when its name differs"
	)


func _test_prompt_keeps_bounded_productive_graphs() -> void:
	var payload: Dictionary = DecisionClientScript.new().call(
		"_build_payload",
		{},
		600,
		false
	)
	var messages: Array = payload.get("messages", []) \
		if payload.get("messages", []) is Array else []
	var system_prompt := str(
		(messages[0] as Dictionary).get("content", "")
	) if not messages.is_empty() and messages[0] is Dictionary else ""
	_check(
		not system_prompt.contains("Default to exactly one select_candidate")
			and system_prompt.contains("Use a one-node policy only when")
			and system_prompt.contains("bounded 2-4")
			and system_prompt.contains(
				"Reserved otherwise values are never branch next_node_id values"
			)
			and system_prompt.contains(
				"do not reference node:terminal unless that terminal node is present"
			),
		"the planner prompt must request a bounded productive graph and forbid dangling checkpoint targets"
	)


func _test_action_owner_is_frozen_before_synchronous_execution() -> void:
	var action := {"kind": "end_turn"}
	var strategy = StrategyScript.new()
	strategy.configure_profile(
		ProfileCatalogScript.get_profile_for_deck(RAGING_BOLT_DECK_ID),
		{}
	)
	_check(
		strategy.has_method("capture_runtime_action_ownership"),
		"the V18 host seam must capture immutable action ownership before synchronous execution"
	)
	if not strategy.has_method("capture_runtime_action_ownership"):
		return
	var stable_action_id := strategy.stable_action_id_for_host(action)
	strategy.set("_current_action_owner", "policy_graph_branch")
	strategy.set("_current_route_id", "route:develop")
	strategy.set("_preferred_candidate_id", "candidate:develop")
	strategy.set("_preferred_action_id", stable_action_id)
	strategy.set("_active_module_certificate_kind", "fixture_certificate")
	strategy.call("capture_runtime_action_ownership", action)

	# Synchronous execution may resolve an interaction, invalidate a graph, or
	# force a replacement before AIOpponent can log the selected action.
	strategy.set("_current_action_owner", "local_gate")
	strategy.set("_current_route_id", "route:end_turn")
	strategy.set("_preferred_candidate_id", "candidate:end")
	strategy.set("_active_module_certificate_kind", "")
	strategy.log_runtime_action_result(action, true, _state(), 0, 7)
	var summary: Dictionary = strategy.get_audit_summary()
	var result: Dictionary = strategy.get("_unconsumed_action_result")
	_check(
		int(summary.get("model_owned_action_results", 0)) == 1
			and int(summary.get("action_owners", {}).get(
				"policy_graph_branch",
				0
			)) == 1,
		"an accepted graph action must remain model-owned after execution mutates live route state"
	)
	_check(
		str(result.get("owner", "")) == "policy_graph_branch"
			and str(result.get("route_id", "")) == "route:develop"
			and str(result.get("candidate_id", "")) == "candidate:develop",
		"delta replanning must consume the route/candidate/owner selected before execution"
	)
	_check(
		(strategy.get("_pending_action_ownership_ticket") as Dictionary).is_empty(),
		"the immutable ownership ticket must be consumed exactly once"
	)

	var mismatch_strategy = StrategyScript.new()
	mismatch_strategy.configure_profile(
		ProfileCatalogScript.get_profile_for_deck(RAGING_BOLT_DECK_ID),
		{}
	)
	mismatch_strategy.set("_current_action_owner", "policy_graph_branch")
	mismatch_strategy.set("_current_route_id", "route:develop")
	mismatch_strategy.set("_preferred_candidate_id", "candidate:develop")
	mismatch_strategy.set(
		"_preferred_action_id",
		mismatch_strategy.stable_action_id_for_host({"kind": "attack"})
	)
	mismatch_strategy.call("capture_runtime_action_ownership", action)
	mismatch_strategy.log_runtime_action_result(action, true, _state(), 0, 7)
	var mismatch_summary: Dictionary = mismatch_strategy.get_audit_summary()
	_check(
		int(mismatch_summary.get("model_owned_action_results", 0)) == 0
			and int(mismatch_summary.get("action_owners", {}).get(
				"rules_fallback",
				0
			)) == 1,
		"a different host-selected action must never be falsely attributed to the model graph"
	)


func _test_model_branch_owner_survives_same_observation_reentry() -> void:
	var strategy = StrategyScript.new()
	strategy.configure_profile(
		ProfileCatalogScript.get_profile_for_deck(RAGING_BOLT_DECK_ID),
		{}
	)
	var graph: Variant = strategy.get("_policy_graph")
	graph.install({
		"root_node_id": "node:root",
		"nodes": [
			{
				"node_id": "node:root",
				"kind": "route",
				"route_ref": {
					"mode": "select_candidate",
					"route_id": "route:information",
					"candidate_id": "candidate:information",
				},
				"next_node_id": "node:checkpoint",
			},
			{
				"node_id": "node:checkpoint",
				"kind": "checkpoint",
				"branches": [{
					"when_all": [{
						"fact": "continuity.search_engine_roots",
						"op": ">=",
						"value": 1,
					}],
					"next_node_id": "node:develop",
				}],
				"otherwise": "replan",
			},
			{
				"node_id": "node:develop",
				"kind": "route",
				"route_ref": {
					"mode": "follow_route",
					"route_id": "route:develop",
				},
			},
		],
	}, "model_shadow_rule_root")
	_check(
		str(strategy.call("_graph_reentry_action_owner")) \
			== "deadline_fallback",
		"an accepted shadow root must keep the exact verified-reference interaction owner until its Rule action executes"
	)
	_check(
		bool(strategy.call("_model_checkpoint_precedes_verified_upgrade")),
		"a validated model successor must be resolved before a local verified upgrade arbitrates the same post-action observation"
	)
	var available_routes: Array[String] = ["route:develop"]
	var available_candidates: Array[String] = []
	var transition: Dictionary = graph.advance_after_observation(
		{"continuity": {"search_engine_roots": 1}},
		available_routes,
		available_candidates
	)
	_check(
		str(transition.get("status", "")) == "route",
		"fixture must advance the accepted shadow onto its model branch"
	)
	strategy.set("_current_action_owner", "policy_graph_branch")
	strategy.set("_current_route_id", "route:develop")
	strategy.set("_preferred_candidate_id", "candidate:develop")
	_check(
		str(strategy.call("_graph_reentry_action_owner")) \
			== "policy_graph_branch",
		"a repeated prepare on the same observation must not downgrade a selected model branch to local_gate"
	)


func _state() -> GameState:
	var state := GameState.new()
	state.current_player_index = 0
	state.first_player_index = 1
	state.turn_number = 2
	state.phase = GameState.GamePhase.MAIN
	for index: int in 2:
		var player := PlayerState.new()
		player.player_index = index
		state.players.append(player)
	return state


func _slot(
	slot_id: String,
	uid: String,
	energy: Array,
	remaining_hp: int = 240,
	prize_count: int = 2
) -> Dictionary:
	return {
		"slot_id": slot_id,
		"pokemon": {"uid": uid},
		"energy": energy,
		"energy_count": energy.size(),
		"remaining_hp": remaining_hp,
		"max_hp": remaining_hp,
		"prize_count": prize_count,
	}


func _energy(symbol: String) -> Dictionary:
	return {
		"uid": "ENERGY_%s" % symbol,
		"type": "Basic Energy",
		"energy_type": symbol,
		"energy_provides": symbol,
	}


func _stadium(name: String, owner: int) -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = "Stadium"
	return CardInstance.create(data, owner)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
