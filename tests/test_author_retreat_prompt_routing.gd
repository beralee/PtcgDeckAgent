extends "res://tests/helpers/BattleUIFeaturesShared.gd"

const OwnerFixtureScript = preload("res://tests/ptcgdap/godot/test_author_strategy_windows_player_owner.gd")
const ExecutorScript = preload("res://scripts/ai/ptcgdap/host/godot/AuthorStrategyEngineActionExecutor.gd")


class RoutingOwner extends RefCounted:
	var player_index := 1

	func validate_integrity() -> bool:
		return true

	func should_control_turn(state: GameState, blocked: bool) -> bool:
		return not blocked and state.current_player_index == player_index


func _retreat_scene(cost: int, energy_count: int, seat: int = 1) -> Control:
	var scene := _make_portrait_retreat_action_hud_scene()
	var gsm: GameStateMachine = scene.get("_gsm")
	if seat == 1:
		var original := gsm.game_state.players[0]
		gsm.game_state.players[0] = gsm.game_state.players[1]
		gsm.game_state.players[1] = original
		for pi: int in 2:
			var player := gsm.game_state.players[pi]
			player.player_index = pi
			for slot: PokemonSlot in player.get_all_pokemon():
				for card: CardInstance in slot.pokemon_stack:
					card.owner_index = pi
	gsm.game_state.current_player_index = seat
	gsm.game_state.turn_number = 3
	var active := gsm.game_state.players[seat].active_pokemon
	active.get_card_data().retreat_cost = cost
	for i: int in energy_count:
		active.attached_energy.append(CardInstance.create(_make_energy_cd("Energy %d" % i, "R"), seat))
	var owner := RoutingOwner.new()
	scene.set("_author_player_owner", owner)
	return scene


func _dispose_retreat_scene(scene: Control) -> void:
	# The shared UI fixture holds detached controls in scene properties.
	# Adopt them only at teardown so the scene frees every test-owned control.
	for property: Dictionary in scene.get_property_list():
		var value: Variant = scene.get(property.name)
		if value is Node and value != scene and is_instance_valid(value) and value.get_parent() == null:
			scene.add_child(value)
	var gsm: GameStateMachine = scene.get("_gsm")
	scene.free()
	if gsm != null:
		gsm.prepare_for_disposal()


func test_author_retreat_bench_never_opens_human_field_choice() -> String:
	var previous := GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.VS_AUTHOR_STRATEGY_AI
	var scene := _retreat_scene(0, 0)
	scene.call("_show_retreat_dialog", 1)
	var checks := run_checks([
		assert_eq(scene.get("_pending_choice"), "retreat_bench"),
		assert_eq((scene.get("_dialog_data") as Dictionary).get("player"), 1),
		assert_eq(scene.get("_field_interaction_mode"), "", "AI retreat must not enable human field clicks"),
		assert_false(bool((scene.get("_dialog_overlay") as Control).visible)),
		assert_true(bool(scene.call("_is_ai_turn_ready")), "Replacement selection must remain schedulable"),
		assert_true(bool(scene.get("_ai_step_scheduled"))),
	])
	_dispose_retreat_scene(scene)
	GameManager.current_mode = previous
	return checks


func test_author_retreat_energy_never_opens_human_dialog() -> String:
	var previous := GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.VS_AUTHOR_STRATEGY_AI
	var scene := _retreat_scene(1, 2)
	scene.call("_show_retreat_dialog", 1)
	var checks := run_checks([
		assert_eq(scene.get("_pending_choice"), "retreat_energy"),
		assert_eq(((scene.get("_dialog_data") as Dictionary).get("energy_options") as Array).size(), 2),
		assert_false(bool((scene.get("_dialog_overlay") as Control).visible), "AI payment must not ask the human"),
		assert_true(bool(scene.call("_is_ai_turn_ready"))),
		assert_true(bool(scene.get("_ai_step_scheduled"))),
	])
	_dispose_retreat_scene(scene)
	GameManager.current_mode = previous
	return checks


func test_human_retreat_stays_interactive_and_cannot_be_claimed_by_author() -> String:
	var previous := GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.VS_AUTHOR_STRATEGY_AI
	var scene := _retreat_scene(0, 0, 0)
	scene.call("_show_retreat_dialog", 0)
	var checks := run_checks([
		assert_eq(scene.get("_field_interaction_mode"), "slot_select"),
		assert_false(bool(scene.call("_is_ai_turn_ready"))),
	])
	# Even if a modal disappears while a human-owned retreat is pending, turn
	# ownership alone must never grant the other seat this selection.
	scene.call("_hide_field_interaction")
	(scene.get("_gsm") as GameStateMachine).game_state.current_player_index = 1
	checks = run_checks([checks, assert_false(bool(scene.call("_is_ai_turn_ready")), "Use prompt player, not current turn")])
	_dispose_retreat_scene(scene)
	GameManager.current_mode = previous
	return checks


func test_author_retreat_existing_overlays_do_not_deadlock_scheduler() -> String:
	var previous := GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.VS_AUTHOR_STRATEGY_AI
	var scene := _retreat_scene(0, 0)
	var checks: Array[String] = []
	for kind: String in ["retreat_energy", "retreat_bench"]:
		scene.set("_pending_choice", kind)
		scene.set("_dialog_data", {"player": 1})
		(scene.get("_dialog_overlay") as Control).visible = true
		checks.append(assert_true(bool(scene.call("_is_ai_turn_ready")), "%s overlay must not block its owner" % kind))
		scene.set("_battle_visual_input_blocked", true)
		checks.append(assert_false(bool(scene.call("_is_ai_turn_ready")), "Animation block still applies"))
		scene.set("_battle_visual_input_blocked", false)
	_dispose_retreat_scene(scene)
	GameManager.current_mode = previous
	return run_checks(checks)


func test_real_author_policy_completes_payment_and_switch_through_battle_scheduler() -> String:
	return _real_author_retreat(false)


func test_worker_author_policy_completes_fresh_retreat_windows() -> String:
	return _real_author_retreat(true)


func _real_author_retreat(worker: bool) -> String:
	var fixture := OwnerFixtureScript.new()
	var bytes := FileAccess.get_file_as_bytes(fixture.CONTROL_PLAYER_FIXTURE)
	var inspected: Dictionary = fixture.PackageLoaderScript.new().inspect_control_distributed_player_match_bytes(
		bytes, FileAccess.get_sha256(fixture.CONTROL_PLAYER_FIXTURE).to_upper()
	)
	if not bool(inspected.get("ok", false)):
		return "Fixture inspection failed: %s" % str(inspected)
	var deck_gate: Dictionary = fixture.PackageDeckGateScript.build(inspected.payloads)
	var created: Dictionary = fixture.PackageHandleScript.create(inspected.metadata, inspected.payloads, deck_gate.get("local_deck", []))
	if not bool(created.get("ok", false)):
		return "Fixture handle failed: %s" % str(created)
	var materialized: Dictionary = GameManager.materialize_author_strategy_battle_deck(created.handle)
	var gsm := GameStateMachine.new()
	var seed_owner := PlayerState.new()
	seed_owner.set_forced_shuffle_seed(9142327)
	gsm.start_game(CardDatabase.get_deck(fixture.RULES_AI_DECK_ID), materialized.deck, 0, false, true)
	seed_owner.clear_forced_shuffle_seed()
	# Put actual, registered package cards in a deterministic retreat position.
	for pi: int in 2:
		var player := gsm.game_state.players[pi]
		player.deck.append_array(player.hand)
		player.hand.clear()
		var basics: Array[CardInstance] = []
		for card: CardInstance in player.deck:
			if card.card_data.card_type == "Pokemon" and card.card_data.stage == "Basic":
				basics.append(card)
		for i: int in (3 if pi == 1 else 1):
			var card := basics[i]
			player.deck.erase(card)
			var slot := PokemonSlot.new()
			slot.pokemon_stack.append(card)
			if i == 0:
				player.active_pokemon = slot
			else:
				player.bench.append(slot)
	var player := gsm.game_state.players[1]
	var old_active := player.active_pokemon
	var cost := gsm.effect_processor.get_effective_retreat_cost(old_active, gsm.game_state)
	if cost <= 0:
		gsm.prepare_for_disposal()
		return "Fixture must have a nonzero retreat cost"
	for card: CardInstance in player.deck.duplicate():
		if card.card_data.card_type == "Basic Energy" and old_active.attached_energy.size() < cost + 1:
			player.deck.erase(card)
			old_active.attached_energy.append(card)
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.current_player_index = 1
	gsm.game_state.turn_number = 3
	var built: Dictionary = fixture.BattleDecisionOwnerFactoryScript.build_windows_author_owner(
		created.handle, gsm, 1, "retreat-ui-regression", fixture.ExecutionGateScript.CONTROL_DISTRIBUTED_MODE
	)
	if not bool(built.get("ok", false)):
		gsm.prepare_for_disposal()
		return "Owner bind failed: %s" % str(built)
	var owner: Variant = built.owner
	owner.configure_policy_execution_profile("worker_v1" if worker else "main_thread_v1")
	owner.enable_developer_decision_trace()
	var previous := GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.VS_AUTHOR_STRATEGY_AI
	var scene := _make_battle_scene_stub()
	scene.set("_gsm", gsm)
	scene.set("_author_player_owner", owner)
	var declared := ExecutorScript.new().execute(1, scene, gsm, {"kind": "retreat"})
	var checks: Array[String] = [assert_true(declared), assert_eq(scene.get("_pending_choice"), "retreat_energy")]
	if worker:
		checks.append(_prepare_worker_selection(owner, scene, gsm))
	scene.call("_run_ai_step")
	checks.append(assert_eq(scene.get("_pending_choice"), "retreat_bench", "Policy payment must publish a fresh replacement window"))
	checks.append(assert_eq(scene.get("_field_interaction_mode"), ""))
	if worker:
		checks.append(_prepare_worker_selection(owner, scene, gsm))
	scene.call("_run_ai_step")
	checks.append(assert_eq(scene.get("_pending_choice"), ""))
	checks.append(assert_true(player.active_pokemon != old_active, "Real engine must complete the selected switch"))
	checks.append(assert_eq(old_active.attached_energy.size(), 1, "Only the retreat cost is paid"))
	checks.append(assert_true(gsm.game_state.retreat_used_this_turn))
	var audit: Dictionary = owner.audit_snapshot()
	checks.append(assert_eq(int(audit.get("policy_calls", 0)), 2, "Both windows must reach the package policy"))
	checks.append(assert_eq(int(audit.get("engine_rejections", 0)), 0))
	checks.append(assert_eq(int(audit.get("policy_errors", 0)), 0))
	checks.append(assert_eq(int(audit.get("same_window_fallbacks", 0)), 0))
	var records: Array = owner.drain_developer_decision_records()
	checks.append(assert_eq(records.size(), 2))
	if records.size() == 2:
		checks.append(assert_eq(records[0].frame.prompt_kind, "energy_payment"))
		checks.append(assert_eq(records[1].frame.prompt_kind, "self_switch"))
		checks.append(assert_true(records[0].frame.source.window_id != records[1].frame.source.window_id, "Payment and replacement cannot reuse a window"))
		checks.append(assert_eq(records[0].host.status, "accepted"))
		checks.append(assert_eq(records[1].host.status, "accepted"))
	owner.close_match()
	_dispose_retreat_scene(scene)
	GameManager.current_mode = previous
	return run_checks(checks)


func _prepare_worker_selection(owner: Variant, scene: Control, gsm: GameStateMachine) -> String:
	var result: Dictionary = owner.run_single_step_result(scene, gsm)
	var deadline := Time.get_ticks_msec() + 5000
	while owner.has_pending_policy_decision() and not owner.is_policy_decision_ready() and Time.get_ticks_msec() < deadline:
		OS.delay_msec(1)
	return run_checks([
		assert_eq(result.status, "waiting_policy"),
		assert_true(owner.is_policy_decision_ready()),
		assert_true(bool(scene.call("_is_ai_turn_ready"))),
		assert_eq(scene.get("_field_interaction_mode"), ""),
		assert_false(bool((scene.get("_dialog_overlay") as Control).visible)),
	])
