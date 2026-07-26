extends SceneTree

const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")
const EventBridgeScript = preload("res://scripts/ai/v18_cpg/runtime/V18CPGEventBridge.gd")
const ObservationGatewayScript = preload("res://scripts/ai/v18_cpg/observation/V18CPGObservationGateway.gd")
const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")

var _failures: Array[String] = []


class FakeV18Strategy:
	extends RefCounted

	var pending: bool = true
	var request_count: int = 1
	var executed_count: int = 0

	func get_runtime_metadata() -> Dictionary:
		return {"runtime_kind": "v18_conditional_policy"}

	func is_llm_pending() -> bool:
		return pending

	func prepare_decision(
		_game_state: GameState,
		_player_index: int,
		_legal_actions: Array,
		_event_context: Dictionary = {}
	) -> Dictionary:
		return {"status": "pending"} if pending else {
			"status": "ready",
			"owner": "policy_graph_branch",
			"route_id": "route:information",
		}

	func has_llm_plan_for_turn(_turn_number: int) -> bool:
		return not pending

	func score_action_absolute(action: Dictionary, _state: GameState, _player_index: int) -> float:
		return 100.0 if str(action.get("kind", "")) == "play_trainer" else 0.0

	func log_runtime_action_result(
		_action: Dictionary,
		success: bool,
		_game_state: GameState,
		_player_index: int,
		_turn: int
	) -> void:
		if success:
			executed_count += 1
			pending = true
			request_count += 1

	func resolve_policy() -> void:
		pending = false


class FakeLegalActionBuilder:
	extends RefCounted

	var actions: Array[Dictionary] = []
	var action_index: int = 0

	func set_deck_strategy(_strategy: RefCounted) -> void:
		pass

	func build_actions(_gsm: GameStateMachine, _player_index: int) -> Array[Dictionary]:
		if actions.is_empty():
			return []
		return [actions[mini(action_index, actions.size() - 1)].duplicate(true)]

	func advance() -> void:
		action_index = mini(action_index + 1, maxi(actions.size() - 1, 0))


class FakeBattleScene:
	extends Control

	var _pending_choice: String = ""
	var _dialog_data: Dictionary = {}
	var executed_count: int = 0
	var executed_card_uids: Array[String] = []

	func _try_play_trainer_with_interaction(_player_index: int, card: CardInstance) -> bool:
		executed_count += 1
		executed_card_uids.append(card.card_data.get_uid() if card != null and card.card_data != null else "")
		return true


func _initialize() -> void:
	_test_waiting_is_not_no_progress_and_resumes_three_times()
	_test_three_public_information_transitions_are_consumable()
	_test_real_v18_base_attaches_each_engine_event_to_action_ownership()
	_test_public_snapshot_does_not_expose_hidden_identities()
	_test_all_24_profiles_inherit_information_epoch_reopen()
	if _failures.is_empty():
		print("V18CPG multi-information execution: PASS (5 groups)")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _test_waiting_is_not_no_progress_and_resumes_three_times() -> void:
	var state := _minimal_main_state(5)
	var gsm := GameStateMachine.new()
	gsm.game_state = state
	var strategy := FakeV18Strategy.new()
	var ai := AIOpponentScript.new()
	ai.configure(0, 1)
	ai.set_deck_strategy(strategy)
	var builder := FakeLegalActionBuilder.new()
	builder.actions = [
		_filter_action("ROOT", "001", 0),
		_filter_action("CSV6C", "124", 0),
		_filter_action("CSV8C", "200", 0),
	]
	ai.set("_legal_action_builder", builder)
	var scene := FakeBattleScene.new()
	for epoch: int in 3:
		var waiting: Dictionary = ai.run_single_step_result(scene, gsm)
		_check(
			str(waiting.get("status", "")) == "waiting_policy" \
				and not bool(waiting.get("progressed", true)),
			"epoch %d must expose model waiting as a typed non-terminal state" % epoch
		)
		strategy.resolve_policy()
		var resumed: Dictionary = ai.run_single_step_result(scene, gsm)
		_check(
			str(resumed.get("status", "")) == "progressed" \
				and bool(resumed.get("progressed", false)),
			"epoch %d must resume and execute after the policy becomes ready" % epoch
		)
		builder.advance()
	_check(
		scene.executed_count == 3 and strategy.executed_count == 3,
		"three information epochs must produce three decision-to-execution completions"
	)
	_check(
		scene.executed_card_uids == ["ROOT_001", "CSV6C_124", "CSV8C_200"],
		"the two cards acquired after the root information action must be executed later in the same turn"
	)
	scene.queue_free()


func _test_three_public_information_transitions_are_consumable() -> void:
	var bridge := EventBridgeScript.new()
	var state_0 := _public_snapshot([], 20, "s0")
	var state_1 := _public_snapshot(
		[_card_ref("CSV6C_124"), _card_ref("CSV8C_200")],
		18,
		"s1"
	)
	var state_2 := _public_snapshot(
		[_card_ref("CSV6C_124"), _card_ref("CSV8C_200"), _card_ref("ENERGY_F")],
		16,
		"s2"
	)
	var state_3 := _public_snapshot(
		[
			_card_ref("CSV6C_124"),
			_card_ref("CSV8C_200"),
			_card_ref("ENERGY_F"),
			_card_ref("DRAW_A"),
			_card_ref("DRAW_B"),
		],
		13,
		"s3"
	)
	var events: Array[Dictionary] = [
		bridge.observe_transition(state_0, state_1, {
			"success": true,
			"step_kind": "effect_interaction",
			"interaction_complete": true,
			"step_id": "noctowl:jewel-seeker",
		}),
		bridge.observe_transition(state_1, state_2, {
			"success": true,
			"step_kind": "effect_interaction",
			"interaction_complete": true,
			"step_id": "earthen-vessel:search",
		}),
		bridge.observe_transition(state_2, state_3, {
			"success": true,
			"step_kind": "main_action",
			"interaction_complete": true,
			"action_kind": "play_trainer",
		}),
	]
	var resolution_ids: Dictionary = {}
	for index: int in events.size():
		var event: Dictionary = events[index]
		_check(bool(event.get("information_material", false)), "filter step %d must open a new information epoch" % index)
		var resolution_id := str(event.get("resolution_id", ""))
		_check(resolution_id != "" and not resolution_ids.has(resolution_id), "filter step %d needs a unique resolution id" % index)
		resolution_ids[resolution_id] = true
		_check(
			not (event.get("acquired_own_hand_cards", []) as Array).is_empty(),
			"filter step %d must expose newly acquired public hand identities" % index
		)
	var unchanged := bridge.observe_transition(state_3, state_3, {
		"success": false,
		"step_kind": "effect_interaction",
		"interaction_complete": true,
	})
	_check(not bool(unchanged.get("information_material", true)), "failed unchanged interaction must not invent an information epoch")
	var visible_whiff := bridge.observe_transition(state_3, state_3, {
		"success": true,
		"step_kind": "effect_interaction",
		"interaction_complete": true,
		"visible_scope": "own_full_deck",
	})
	_check(
		bool(visible_whiff.get("information_material", false)) \
			and (visible_whiff.get("acquired_own_hand_cards", []) as Array).is_empty(),
		"a completed full-deck whiff must still create an information epoch without leaking deck identities"
	)


func _test_real_v18_base_attaches_each_engine_event_to_action_ownership() -> void:
	var strategy := StrategyScript.new()
	strategy.configure_profile(ProfileCatalogScript.get_profile_for_deck(800015934))
	strategy.configure_verified_local_only_for_benchmark()
	strategy.configure_audit("multi-information-execution", "real-base", false)
	strategy.set("_current_action_owner", "local_gate")
	strategy.set("_current_route_id", "route:evolve")
	strategy.set("_preferred_candidate_id", "candidate:noctowl")
	var states: Array[Dictionary] = [
		_public_snapshot([], 20, "real-s0"),
		_public_snapshot([_card_ref("NOCTOWL_PICK")], 18, "real-s1"),
		_public_snapshot([_card_ref("NOCTOWL_PICK"), _card_ref("VESSEL_PICK")], 16, "real-s2"),
		_public_snapshot([_card_ref("NOCTOWL_PICK"), _card_ref("VESSEL_PICK"), _card_ref("DRAW_PICK")], 13, "real-s3"),
	]
	var previous_frontier: Array[Dictionary] = []
	var seen_resolution_ids: Dictionary = {}
	for index: int in 3:
		strategy.log_runtime_action_result(
			{"kind": "evolve"},
			true,
			_minimal_main_state(5),
			0,
			5
		)
		var event: Dictionary = strategy.observe_v18cpg_runtime_state_change(
			states[index],
			states[index + 1],
			{
				"success": true,
				"step_kind": "effect_interaction",
				"interaction_complete": true,
				"step_id": "filter:%d" % index,
			}
		)
		var completed: Dictionary = strategy.get("_unconsumed_action_result")
		var resolution_id := str(completed.get("resolution_id", ""))
		_check(
			bool(completed.get("information_event", false)) \
				and resolution_id == str(event.get("resolution_id", "")),
			"real V18 base must attach information event %d to the completed action" % index
		)
		_check(
			not seen_resolution_ids.has(resolution_id),
			"real V18 base must not reuse a resolution id across filter steps"
		)
		seen_resolution_ids[resolution_id] = true
		var enriched_delta: Dictionary = strategy.call(
			"_enrich_material_delta_with_information_event",
			{"material": false, "legal_actions_changed": false},
			completed
		)
		_check(
			bool(enriched_delta.get("material", false)) \
				and bool(enriched_delta.get("information_event", false)) \
				and not (enriched_delta.get("acquired_own_hand_cards", []) as Array).is_empty(),
			"real V18 base must send compact acquired-card evidence in delta request %d" % index
		)
		_check(
			bool(strategy.call(
				"_should_reopen_information_epoch",
				"local_gate",
				completed,
				enriched_delta,
				previous_frontier
			)),
			"real V18 base must consume filter event %d as a new decision epoch" % index
		)


func _test_public_snapshot_does_not_expose_hidden_identities() -> void:
	var state := _minimal_main_state(5)
	state.players[0].hand = [_instance("VISIBLE", "HAND", 0)]
	state.players[0].deck = [_instance("HIDDEN_OWN_DECK", "001", 0)]
	state.players[0].prizes = [_instance("HIDDEN_OWN_PRIZE", "001", 0)]
	state.players[1].hand = [_instance("HIDDEN_OPP_HAND", "001", 1)]
	var gateway := ObservationGatewayScript.new()
	var snapshot: Dictionary = gateway.snapshot_public_state(state, 0)
	var encoded := JSON.stringify(snapshot)
	_check(encoded.contains("VISIBLE_HAND"), "public snapshot must retain own visible hand identities")
	_check(not encoded.contains("HIDDEN_OWN_DECK"), "public snapshot leaked own deck identity")
	_check(not encoded.contains("HIDDEN_OWN_PRIZE"), "public snapshot leaked own Prize identity")
	_check(not encoded.contains("HIDDEN_OPP_HAND"), "public snapshot leaked opponent hand identity")


func _test_all_24_profiles_inherit_information_epoch_reopen() -> void:
	for deck_id: int in ProfileCatalogScript.ALL_DECK_IDS:
		var strategy := StrategyScript.new()
		strategy.configure_profile(ProfileCatalogScript.get_profile_for_deck(deck_id))
		strategy.configure_verified_local_only_for_benchmark()
		var previous_frontier: Array[Dictionary] = []
		var information_result := {
			"owner": "local_gate",
			"success": true,
			"route_id": "route:evolve",
			"candidate_id": "candidate:noctowl",
			"information_event": true,
			"resolution_id": "resolution:%d" % deck_id,
		}
		_check(
			bool(strategy.call(
				"_should_reopen_information_epoch",
				"local_gate",
				information_result,
				{"material": false, "legal_actions_changed": false, "changed_facts": []},
				previous_frontier
			)),
			"%d must inherit information-event reopening even when the root route is not named information" % deck_id
		)
		information_result["owner"] = "policy_graph_branch"
		_check(
			not bool(strategy.call(
				"_should_reopen_information_epoch",
				"model_selected_local_route",
				information_result,
				{"material": true},
				previous_frontier
			)),
			"%d must preserve a model graph's typed checkpoint ownership" % deck_id
		)
		_check(
			bool(strategy.call(
				"_information_event_requires_delta_replan",
				information_result,
				{"material": false, "legal_actions_changed": false}
			)),
			"%d must replan when a model graph does not cover a same-size information replacement" % deck_id
		)


func _minimal_main_state(turn: int) -> GameState:
	var state := GameState.new()
	state.current_player_index = 0
	state.first_player_index = 0
	state.turn_number = turn
	state.phase = GameState.GamePhase.MAIN
	for index: int in 2:
		var player := PlayerState.new()
		player.player_index = index
		state.players.append(player)
	return state


func _public_snapshot(hand: Array, deck_count: int, hash_value: String) -> Dictionary:
	return {
		"turn": {"number": 5, "current_player": 0, "phase": int(GameState.GamePhase.MAIN)},
		"own": {
			"hand": hand.duplicate(true),
			"hand_count": hand.size(),
			"deck_count": deck_count,
			"prizes_remaining": 6,
			"discard": [],
			"lost_zone": [],
			"active": {},
			"bench": [],
		},
		"opponent": {
			"hand_count": 5,
			"deck_count": 20,
			"prizes_remaining": 6,
			"discard": [],
			"lost_zone": [],
			"active": {},
			"bench": [],
		},
		"stadium": {},
		"public_state_hash": hash_value,
	}


func _card_ref(uid: String) -> Dictionary:
	return {"instance_id": uid.hash(), "uid": uid, "name": uid, "type": "Item"}


func _instance(set_code: String, card_index: String, owner: int) -> CardInstance:
	var data := CardData.new()
	data.set_code = set_code
	data.card_index = card_index
	data.name = "%s_%s" % [set_code, card_index]
	data.name_en = data.name
	data.card_type = "Item"
	return CardInstance.create(data, owner)


func _filter_action(set_code: String, card_index: String, owner: int) -> Dictionary:
	return {
		"id": "action:%s_%s" % [set_code, card_index],
		"kind": "play_trainer",
		"requires_interaction": true,
		"card": _instance(set_code, card_index, owner),
	}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
