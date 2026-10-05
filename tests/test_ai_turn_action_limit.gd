extends "res://tests/helpers/BattleUIFeaturesShared.gd"

const AuthorOwnerScript = preload("res://scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorDevelopmentBattleOwner.gd")


class PrizeAuthorOwner extends AuthorOwnerScript:
	# Package loading is outside this scheduler regression. Prize selection and
	# execution still use the production public-position Base and engine path.
	func validate_integrity() -> bool:
		return true

	func _uses_competitive_policy_v2() -> bool:
		return true


class StepOwner extends RefCounted:
	var player_index := 1
	var calls := 0
	var status := "progressed"

	func validate_integrity() -> bool:
		return true

	func should_control_turn(state: GameState, blocked: bool) -> bool:
		return not blocked and state.current_player_index == player_index

	func run_single_step_result(_scene: Control, _gsm: GameStateMachine) -> Dictionary:
		calls += 1
		return {"status": status}


func _fixture(author: bool = true) -> Dictionary:
	var scene := _make_battle_scene_stub()
	scene._setup_ai_for_tests()
	var gsm := GameStateMachine.new()
	var state := GameState.new()
	state.current_player_index = 1
	state.first_player_index = 1
	state.turn_number = 19
	state.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		player.active_pokemon = _slot(pi, "Active", 300)
		player.set_prizes(_make_named_deck_cards(pi, ["Prize A", "Prize B", "Prize C"]))
		player.deck = _make_named_deck_cards(pi, ["Draw A", "Draw B"])
		state.players.append(player)
	gsm.game_state = state
	scene.set("_gsm", gsm)
	scene.set("_view_player", 0)
	gsm.player_choice_required.connect(scene._on_player_choice_required)
	var my_slots: Array[BattleCardView] = []
	var opp_slots: Array[BattleCardView] = []
	for i: int in 6:
		my_slots.append(BattleCardViewScript.new())
		opp_slots.append(BattleCardViewScript.new())
	scene.set("_my_prize_slots", my_slots)
	scene.set("_opp_prize_slots", opp_slots)
	GameManager.current_mode = GameManager.GameMode.VS_AUTHOR_STRATEGY_AI if author else GameManager.GameMode.VS_AI
	var owner: RefCounted
	if author:
		owner = PrizeAuthorOwner.new()
		owner.set("_gsm", gsm)
		owner.set("player_index", 1)
		scene.set("_author_player_owner", owner)
	else:
		owner = AIOpponentScript.new()
		owner.configure(1, 1)
		scene.set("_ai_opponent", owner)
	scene.set("_ai_turn_marker", "19:1")
	scene.set("_ai_actions_this_turn", 20)
	return {"scene": scene, "gsm": gsm, "state": state, "owner": owner}


func _slot(pi: int, label: String, hp: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(_make_pokemon_cd(label, hp, "C"), pi))
	return slot


func _knock_out_bench(f: Dictionary, victim: int, ex: bool = false) -> void:
	var slot := _slot(victim, "Bench victim", 110)
	if ex:
		slot.get_card_data().mechanic = "ex"
	slot.damage_counters = 110
	f.state.players[victim].bench.append(slot)
	f.state.phase = GameState.GamePhase.POKEMON_CHECK
	f.gsm._check_all_knockouts()


func _check_prize_at_limit(author: bool, ex: bool = false) -> String:
	var previous_mode := GameManager.current_mode
	var f := _fixture(author)
	_knock_out_bench(f, 0, ex)
	assert_eq(f.scene.get("_pending_choice"), "take_prize", "Real bench KO must open the prize prompt")
	assert_true(f.scene._is_ai_turn_ready(), "The prompt must pass actual readiness checks")
	var expected_count := 2 if ex else 1
	for i: int in expected_count:
		f.scene._run_ai_step()
		assert_eq(f.state.players[1].prizes.size(), 2 - i, "The action cap must never interrupt prize settlement")
	assert_eq(f.state.players[1].hand.size(), expected_count, "Every earned prize reaches the AI hand exactly once")
	assert_eq(f.gsm.get_pending_decision_snapshot(), {}, "Engine must finish its mandatory choice")
	assert_eq(f.state.turn_number, 20, "Knockout settlement must advance to the human turn")
	assert_eq(f.state.current_player_index, 0)
	assert_eq(f.state.phase, GameState.GamePhase.MAIN)
	GameManager.current_mode = previous_mode
	return ""


func test_author_prize_at_action_limit_resumes_turn_20() -> String:
	return _check_prize_at_limit(true)


func test_classic_prize_at_action_limit_resumes_turn_20() -> String:
	return _check_prize_at_limit(false)


func test_two_prizes_at_action_limit_finish_before_next_turn() -> String:
	return _check_prize_at_limit(true, true)


func test_human_prize_at_action_limit_still_waits_for_human() -> String:
	var previous_mode := GameManager.current_mode
	var f := _fixture()
	_knock_out_bench(f, 1)
	f.scene._run_ai_step()
	assert_eq(f.state.players[0].prizes.size(), 3, "AI cannot take the human player's prize")
	assert_eq(f.gsm.get_pending_decision_snapshot().owner_player_index, 0)
	assert_eq(f.scene.get("_pending_choice"), "take_prize")
	GameManager.current_mode = previous_mode
	return ""


func test_effect_substeps_do_not_spend_main_action_budget() -> String:
	var previous_mode := GameManager.current_mode
	var f := _fixture()
	var owner := StepOwner.new()
	f.scene.set("_author_player_owner", owner)
	f.scene.set("_pending_choice", "effect_interaction")
	f.scene.set("_pending_effect_player_index", 1)
	var steps: Array[Dictionary] = [{"id": "bench_damage_counters", "chooser_player_index": 1}]
	f.scene.set("_pending_effect_steps", steps)
	f.scene.set("_pending_effect_step_index", 0)
	assert_true(f.scene._is_ai_turn_ready(), "Fixture must expose an AI-owned effect window")
	for counter: int in 6:
		f.scene._run_ai_step()
	assert_eq(owner.calls, 6, "All six counter windows remain runnable at the cap")
	assert_eq(f.scene.get("_ai_actions_this_turn"), 20, "Substeps do not consume six more main actions")
	GameManager.current_mode = previous_mode
	return ""


func test_send_out_at_action_limit_executes_real_replacement() -> String:
	var previous_mode := GameManager.current_mode
	var f := _fixture(false)
	var replacement := _slot(1, "Replacement", 120)
	f.state.players[1].active_pokemon = null
	f.state.players[1].bench.append(replacement)
	f.state.phase = GameState.GamePhase.KNOCKOUT_REPLACE
	f.scene._on_player_choice_required("send_out_pokemon", {"player": 1})
	f.scene._run_ai_step()
	assert_eq(f.state.players[1].active_pokemon, replacement, "Forced replacement must execute after the cap")
	assert_false(f.scene.get("_pending_choice") == "send_out")
	GameManager.current_mode = previous_mode
	return ""


func test_main_action_limit_still_ends_turn_without_another_action() -> String:
	var previous_mode := GameManager.current_mode
	var f := _fixture()
	var owner := StepOwner.new()
	f.scene.set("_author_player_owner", owner)
	f.scene._run_ai_step()
	assert_eq(owner.calls, 0, "Loop protection still blocks a new main action")
	assert_eq(f.state.turn_number, 20)
	assert_eq(f.state.current_player_index, 0)
	GameManager.current_mode = previous_mode
	return ""


func test_main_action_counts_once_and_new_turn_resets_budget() -> String:
	var previous_mode := GameManager.current_mode
	var f := _fixture()
	var owner := StepOwner.new()
	f.scene.set("_author_player_owner", owner)
	f.scene.set("_ai_actions_this_turn", 19)
	f.scene._run_ai_step()
	assert_eq(owner.calls, 1)
	assert_eq(f.scene.get("_ai_actions_this_turn"), 20)
	f.state.turn_number = 21
	f.scene._run_ai_step()
	assert_eq(owner.calls, 2)
	assert_eq(f.scene.get("_ai_actions_this_turn"), 1, "New turn gets a fresh main-action budget")
	GameManager.current_mode = previous_mode
	return ""
