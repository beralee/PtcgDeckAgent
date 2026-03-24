class_name TestAIBaseline
extends TestBase

const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")
const AISetupPlannerScript = preload("res://scripts/ai/AISetupPlanner.gd")
const AIHeuristicsScript = preload("res://scripts/ai/AIHeuristics.gd")
const BattleSceneScript = preload("res://scenes/battle/BattleScene.gd")
const BattleCardViewScript = preload("res://scenes/battle/BattleCardView.gd")
const AbilityBonusDrawIfActiveScript = preload("res://scripts/effects/pokemon_effects/AbilityBonusDrawIfActive.gd")


class SpyAIOpponent extends RefCounted:
	var player_index: int = 1
	var difficulty: int = 1
	var run_count: int = 0

	func should_control_turn(game_state: GameState, ui_blocked: bool) -> bool:
		if game_state == null or ui_blocked:
			return false
		return game_state.current_player_index == player_index

	func run_single_step(_battle_scene: Control, _gsm: GameStateMachine) -> bool:
		run_count += 1
		return true


class FollowupSchedulingSpyAIOpponent extends RefCounted:
	var player_index: int = 1
	var difficulty: int = 1
	var run_count: int = 0

	func should_control_turn(game_state: GameState, ui_blocked: bool) -> bool:
		if game_state == null or ui_blocked:
			return false
		return game_state.current_player_index == player_index

	func run_single_step(battle_scene: Control, _gsm: GameStateMachine) -> bool:
		run_count += 1
		if run_count == 1:
			battle_scene._refresh_ui_after_successful_action()
		return true


class SpyGameStateMachine extends GameStateMachine:
	var retreat_calls: int = 0
	var retreat_result: bool = true
	var mulligan_resolve_calls: int = 0
	var resolved_beneficiary: int = -1
	var resolved_draw_extra: bool = false

	func retreat(_player_index: int, _energy_to_discard: Array[CardInstance], _bench_target: PokemonSlot) -> bool:
		retreat_calls += 1
		return retreat_result

	func resolve_mulligan_choice(beneficiary: int, draw_extra: bool) -> void:
		mulligan_resolve_calls += 1
		resolved_beneficiary = beneficiary
		resolved_draw_extra = draw_extra


class SpyPrizeResolveGameStateMachine extends GameStateMachine:
	var resolve_take_prize_calls: int = 0

	func resolve_take_prize(player_index: int, slot_index: int) -> bool:
		resolve_take_prize_calls += 1
		return super.resolve_take_prize(player_index, slot_index)


class DelayedPrizeAnimationScene extends Control:
	var _pending_choice: String = "take_prize"
	var _pending_prize_player_index: int = 1
	var _pending_prize_remaining: int = 1
	var _pending_prize_animating: bool = false
	var try_take_prize_calls: int = 0

	func _try_take_prize_from_slot(_player_index: int, _slot_index: int) -> void:
		try_take_prize_calls += 1
		_pending_prize_animating = true


class SpySetupBattleScene extends Control:
	var _pending_choice: String = ""
	var _dialog_data: Dictionary = {}
	var after_setup_active_calls: Array[int] = []
	var after_setup_bench_calls: Array[int] = []
	var show_setup_bench_dialog_calls: Array[int] = []
	var refresh_ui_calls: int = 0

	func _after_setup_active(pi: int) -> void:
		after_setup_active_calls.append(pi)

	func _after_setup_bench(pi: int) -> void:
		after_setup_bench_calls.append(pi)

	func _show_setup_bench_dialog(pi: int) -> void:
		show_setup_bench_dialog_calls.append(pi)

	func _refresh_ui() -> void:
		refresh_ui_calls += 1


func _make_player_state(player_index: int) -> PlayerState:
	var player := PlayerState.new()
	player.player_index = player_index
	return player


func _make_basic(name: String) -> CardInstance:
	var card := CardData.new()
	card.name = name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = 60
	return CardInstance.create(card, 1)


func _make_item(name: String) -> CardInstance:
	var card := CardData.new()
	card.name = name
	card.card_type = "Item"
	return CardInstance.create(card, 1)


func _make_ai_manual_gsm() -> GameStateMachine:
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 1
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.turn_number = 2
	CardInstance.reset_id_counter()
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	return gsm


func _new_legal_action_builder() -> Variant:
	var builder_script: Variant = load("res://scripts/ai/AILegalActionBuilder.gd")
	if builder_script == null:
		return null
	return builder_script.new()


func _make_ai_pokemon_card_data(
	name: String,
	stage: String = "Basic",
	evolves_from: String = "",
	effect_id: String = "",
	abilities: Array = [],
	attacks: Array = [],
	retreat_cost: int = 1
) -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = "Pokemon"
	card.stage = stage
	card.evolves_from = evolves_from
	card.effect_id = effect_id
	card.hp = 100
	card.retreat_cost = retreat_cost
	card.abilities.clear()
	for ability: Dictionary in abilities:
		card.abilities.append(ability.duplicate(true))
	card.attacks.clear()
	for attack: Dictionary in attacks:
		card.attacks.append(attack.duplicate(true))
	return card


func _make_ai_trainer_card_data(name: String, card_type: String, effect_id: String = "") -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = card_type
	card.effect_id = effect_id
	return card


func _make_ai_energy_card_data(name: String, energy_type: String = "L", card_type: String = "Basic Energy", effect_id: String = "") -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = card_type
	card.energy_provides = energy_type
	card.effect_id = effect_id
	return card


func _make_ai_slot(card: CardInstance, turn_played: int = 1) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(card)
	slot.turn_played = turn_played
	return slot


func _build_ai_actions(gsm: GameStateMachine, player_index: int = 0) -> Array[Dictionary]:
	var builder: Variant = _new_legal_action_builder()
	if builder == null:
		return []
	return builder.build_actions(gsm, player_index)


func _count_actions_by_kind(actions: Array[Dictionary], kind: String) -> int:
	var count: int = 0
	for action: Dictionary in actions:
		if str(action.get("kind", "")) == kind:
			count += 1
	return count


func _has_action(actions: Array[Dictionary], kind: String, expected: Dictionary = {}) -> bool:
	for action: Dictionary in actions:
		if str(action.get("kind", "")) != kind:
			continue
		var matches := true
		for key: Variant in expected.keys():
			if action.get(key) != expected[key]:
				matches = false
				break
		if matches:
			return true
	return false


func _make_battle_scene_refresh_stub() -> Control:
	var battle_scene = BattleSceneScript.new()
	battle_scene.set("_log_list", ItemList.new())
	battle_scene.set("_lbl_phase", Label.new())
	battle_scene.set("_lbl_turn", Label.new())
	battle_scene.set("_opp_prizes", Label.new())
	battle_scene.set("_opp_deck", Label.new())
	battle_scene.set("_opp_discard", Label.new())
	battle_scene.set("_opp_hand_lbl", Label.new())
	battle_scene.set("_opp_hand_bar", PanelContainer.new())
	battle_scene.set("_opp_prize_hud_count", Label.new())
	battle_scene.set("_opp_deck_hud_value", Label.new())
	battle_scene.set("_opp_discard_hud_value", Label.new())
	battle_scene.set("_my_prizes", Label.new())
	battle_scene.set("_my_deck", Label.new())
	battle_scene.set("_my_discard", Label.new())
	battle_scene.set("_my_prize_hud_count", Label.new())
	battle_scene.set("_my_deck_hud_value", Label.new())
	battle_scene.set("_my_discard_hud_value", Label.new())
	battle_scene.set("_btn_end_turn", Button.new())
	battle_scene.set("_hud_end_turn_btn", Button.new())
	battle_scene.set("_stadium_lbl", Label.new())
	battle_scene.set("_btn_stadium_action", Button.new())
	battle_scene.set("_enemy_vstar_value", Label.new())
	battle_scene.set("_my_vstar_value", Label.new())
	battle_scene.set("_enemy_lost_value", Label.new())
	battle_scene.set("_my_lost_value", Label.new())
	battle_scene.set("_hand_container", HBoxContainer.new())
	battle_scene.set("_dialog_overlay", Panel.new())
	battle_scene.set("_dialog_title", Label.new())
	battle_scene.set("_dialog_list", ItemList.new())
	battle_scene.set("_dialog_card_scroll", ScrollContainer.new())
	battle_scene.set("_dialog_card_row", HBoxContainer.new())
	battle_scene.set("_dialog_assignment_panel", VBoxContainer.new())
	battle_scene.set("_dialog_assignment_summary_lbl", Label.new())
	battle_scene.set("_dialog_assignment_source_scroll", ScrollContainer.new())
	battle_scene.set("_dialog_assignment_target_scroll", ScrollContainer.new())
	battle_scene.set("_dialog_assignment_source_row", HBoxContainer.new())
	battle_scene.set("_dialog_assignment_target_row", HBoxContainer.new())
	battle_scene.set("_dialog_status_lbl", Label.new())
	battle_scene.set("_dialog_utility_row", HBoxContainer.new())
	battle_scene.set("_dialog_confirm", Button.new())
	battle_scene.set("_dialog_cancel", Button.new())
	battle_scene.set("_handover_panel", Panel.new())
	battle_scene.set("_handover_lbl", Label.new())
	battle_scene.set("_handover_btn", Button.new())
	battle_scene.set("_coin_overlay", Panel.new())
	battle_scene.set("_detail_overlay", Panel.new())
	battle_scene.set("_discard_overlay", Panel.new())
	battle_scene.set("_field_interaction_overlay", Control.new())
	battle_scene.set("_opp_prizes_title", Label.new())
	battle_scene.set("_my_prizes_title", Label.new())
	battle_scene.set("_opp_prize_hud_title", Label.new())
	battle_scene.set("_my_prize_hud_title", Label.new())
	battle_scene.set("_slot_card_views", {})
	battle_scene.set("_opp_prize_slots", [])
	battle_scene.set("_my_prize_slots", [])
	return battle_scene


func _make_setup_ready_battle_scene() -> Control:
	var scene := _make_battle_scene_refresh_stub()
	scene._setup_ai_for_tests()
	return scene


func test_ai_opponent_instantiates() -> String:
	var ai := AIOpponentScript.new()
	var blocked_state := GameState.new()
	blocked_state.current_player_index = 0
	var mismatched_state := GameState.new()
	mismatched_state.current_player_index = 1
	var matching_state := GameState.new()
	matching_state.current_player_index = 0

	var initial_checks := run_checks([
		assert_true(ai != null, "AIOpponent should instantiate"),
		assert_true(ai.has_method("configure"), "AIOpponent should expose configure"),
		assert_true(ai.has_method("should_control_turn"), "AIOpponent should expose should_control_turn"),
		assert_true(ai.has_method("run_single_step"), "AIOpponent should expose run_single_step"),
		assert_eq(ai.player_index, 1, "AIOpponent should default to player_index 1"),
		assert_eq(ai.difficulty, 1, "AIOpponent should default to difficulty 1"),
	])
	if initial_checks != "":
		return initial_checks

	ai.configure(0, 3)

	return run_checks([
		assert_eq(ai.player_index, 0, "configure() should update player_index"),
		assert_eq(ai.difficulty, 3, "configure() should update difficulty"),
		assert_false(ai.should_control_turn(null, false), "null game_state should prevent AI turn control"),
		assert_false(ai.should_control_turn(blocked_state, true), "ui_blocked should prevent AI turn control"),
		assert_false(ai.should_control_turn(mismatched_state, false), "AI should not control the wrong player's turn"),
		assert_true(ai.should_control_turn(matching_state, false), "AI should control the configured player's turn"),
		assert_false(ai.run_single_step(null, null), "run_single_step() should remain a safe no-op"),
	])


func test_setup_planner_prefers_basic_active_and_fills_bench() -> String:
	var planner := AISetupPlannerScript.new()
	var player := PlayerState.new()
	player.hand = [_make_basic("A"), _make_basic("B"), _make_item("Ball")]
	var choice: Dictionary = planner.plan_opening_setup(player)
	return run_checks([
		assert_eq(choice.get("active_hand_index", -1), 0, "Should choose a Basic for active"),
		assert_eq(choice.get("bench_hand_indices", []).size(), 1, "Should place extra Basic to bench"),
	])


func test_setup_planner_always_accepts_mulligan_bonus_draw() -> String:
	var planner := AISetupPlannerScript.new()
	return run_checks([
		assert_true(planner.choose_mulligan_bonus_draw(), "Baseline AI should always take the draw"),
	])


func test_ai_legal_action_builder_enumerates_attach_energy_actions() -> String:
	var gsm := _make_ai_manual_gsm()
	var builder: Variant = _new_legal_action_builder()
	var player: PlayerState = gsm.game_state.players[0]
	var active_slot := _make_ai_slot(CardInstance.create(_make_ai_pokemon_card_data("Active"), 0))
	var bench_slot := _make_ai_slot(CardInstance.create(_make_ai_pokemon_card_data("Bench"), 0))
	var energy := CardInstance.create(_make_ai_energy_card_data("Lightning Energy"), 0)
	player.active_pokemon = active_slot
	player.bench = [bench_slot]
	player.hand = [energy, CardInstance.create(_make_ai_trainer_card_data("Ball", "Item"), 0)]
	var actions := _build_ai_actions(gsm)
	return run_checks([
		assert_not_null(builder, "AILegalActionBuilder should load"),
		assert_eq(_count_actions_by_kind(actions, "attach_energy"), 2, "Builder should enumerate one attach action per own Pokemon"),
		assert_true(_has_action(actions, "attach_energy", {"card": energy, "target_slot": active_slot}), "Builder should allow attaching to the active Pokemon"),
		assert_true(_has_action(actions, "attach_energy", {"card": energy, "target_slot": bench_slot}), "Builder should allow attaching to a benched Pokemon"),
	])


func test_ai_legal_action_builder_enumerates_play_basic_to_bench_actions() -> String:
	var gsm := _make_ai_manual_gsm()
	var builder: Variant = _new_legal_action_builder()
	var player: PlayerState = gsm.game_state.players[0]
	var active_slot := _make_ai_slot(CardInstance.create(_make_ai_pokemon_card_data("Lead"), 0))
	var basic := CardInstance.create(_make_ai_pokemon_card_data("Bench Basic"), 0)
	var evolution := CardInstance.create(_make_ai_pokemon_card_data("Stage 1", "Stage 1", "Bench Basic"), 0)
	player.active_pokemon = active_slot
	player.hand = [basic, evolution]
	var actions := _build_ai_actions(gsm)
	return run_checks([
		assert_not_null(builder, "AILegalActionBuilder should load"),
		assert_eq(_count_actions_by_kind(actions, "play_basic_to_bench"), 1, "Builder should only enumerate playable Basic bench actions"),
		assert_true(_has_action(actions, "play_basic_to_bench", {"card": basic}), "Builder should include the playable Basic Pokemon"),
	])


func test_ai_legal_action_builder_enumerates_evolve_actions() -> String:
	var gsm := _make_ai_manual_gsm()
	var builder: Variant = _new_legal_action_builder()
	var player: PlayerState = gsm.game_state.players[0]
	var active_slot := _make_ai_slot(CardInstance.create(_make_ai_pokemon_card_data("Mareep"), 0), 1)
	var evolution := CardInstance.create(_make_ai_pokemon_card_data("Flaaffy", "Stage 1", "Mareep"), 0)
	var wrong_evolution := CardInstance.create(_make_ai_pokemon_card_data("Charmeleon", "Stage 1", "Charmander"), 0)
	player.active_pokemon = active_slot
	player.hand = [evolution, wrong_evolution]
	var actions := _build_ai_actions(gsm)
	return run_checks([
		assert_not_null(builder, "AILegalActionBuilder should load"),
		assert_eq(_count_actions_by_kind(actions, "evolve"), 1, "Builder should enumerate only legal evolve actions"),
		assert_true(_has_action(actions, "evolve", {"card": evolution, "target_slot": active_slot}), "Builder should include the valid evolution target"),
	])


func test_ai_legal_action_builder_enumerates_play_trainer_actions() -> String:
	var gsm := _make_ai_manual_gsm()
	var builder: Variant = _new_legal_action_builder()
	var player: PlayerState = gsm.game_state.players[0]
	var active_slot := _make_ai_slot(CardInstance.create(_make_ai_pokemon_card_data("Lead"), 0))
	var item := CardInstance.create(_make_ai_trainer_card_data("Switch", "Item"), 0)
	var basic := CardInstance.create(_make_ai_pokemon_card_data("Bench Basic"), 0)
	player.active_pokemon = active_slot
	player.hand = [item, basic]
	var actions := _build_ai_actions(gsm)
	return run_checks([
		assert_not_null(builder, "AILegalActionBuilder should load"),
		assert_eq(_count_actions_by_kind(actions, "play_trainer"), 1, "Builder should enumerate trainer cards that can be played immediately"),
		assert_true(_has_action(actions, "play_trainer", {"card": item, "targets": []}), "Builder should include a trainer action with normalized empty targets"),
	])


func test_ai_legal_action_builder_enumerates_play_stadium_actions() -> String:
	var gsm := _make_ai_manual_gsm()
	var builder: Variant = _new_legal_action_builder()
	var player: PlayerState = gsm.game_state.players[0]
	player.active_pokemon = _make_ai_slot(CardInstance.create(_make_ai_pokemon_card_data("Lead"), 0))
	var stadium := CardInstance.create(_make_ai_trainer_card_data("Training Court", "Stadium"), 0)
	player.hand = [stadium]
	var actions := _build_ai_actions(gsm)
	return run_checks([
		assert_not_null(builder, "AILegalActionBuilder should load"),
		assert_eq(_count_actions_by_kind(actions, "play_stadium"), 1, "Builder should enumerate playable stadium cards"),
		assert_true(_has_action(actions, "play_stadium", {"card": stadium, "targets": []}), "Builder should include a normalized stadium action"),
	])


func test_ai_legal_action_builder_enumerates_use_ability_actions() -> String:
	var gsm := _make_ai_manual_gsm()
	var builder: Variant = _new_legal_action_builder()
	var player: PlayerState = gsm.game_state.players[0]
	var ability_cd := _make_ai_pokemon_card_data(
		"Rotom",
		"Basic",
		"",
		"test_ai_bonus_draw",
		[{"name": "Draw", "text": ""}]
	)
	gsm.effect_processor.register_effect("test_ai_bonus_draw", AbilityBonusDrawIfActiveScript.new())
	var active_slot := _make_ai_slot(CardInstance.create(ability_cd, 0))
	player.active_pokemon = active_slot
	player.deck = [CardInstance.create(_make_ai_pokemon_card_data("Drawn"), 0)]
	var actions := _build_ai_actions(gsm)
	return run_checks([
		assert_not_null(builder, "AILegalActionBuilder should load"),
		assert_eq(_count_actions_by_kind(actions, "use_ability"), 1, "Builder should enumerate immediately usable abilities"),
		assert_true(_has_action(actions, "use_ability", {"source_slot": active_slot, "ability_index": 0, "targets": []}), "Builder should include a normalized ability action"),
	])


func test_ai_legal_action_builder_enumerates_retreat_actions() -> String:
	var gsm := _make_ai_manual_gsm()
	var builder: Variant = _new_legal_action_builder()
	var player: PlayerState = gsm.game_state.players[0]
	var active_slot := _make_ai_slot(CardInstance.create(_make_ai_pokemon_card_data("Active", "Basic", "", "", [], [], 1), 0))
	var bench_slot := _make_ai_slot(CardInstance.create(_make_ai_pokemon_card_data("Bench"), 0))
	var energy := CardInstance.create(_make_ai_energy_card_data("Lightning Energy"), 0)
	active_slot.attached_energy.append(energy)
	player.active_pokemon = active_slot
	player.bench = [bench_slot]
	var actions := _build_ai_actions(gsm)
	return run_checks([
		assert_not_null(builder, "AILegalActionBuilder should load"),
		assert_eq(_count_actions_by_kind(actions, "retreat"), 1, "Builder should enumerate the legal retreat line"),
		assert_true(_has_action(actions, "retreat", {"bench_target": bench_slot, "energy_to_discard": [energy]}), "Builder should include the discard selection needed to retreat legally"),
	])


func test_ai_legal_action_builder_enumerates_attack_actions() -> String:
	var gsm := _make_ai_manual_gsm()
	var builder: Variant = _new_legal_action_builder()
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var attack_cd := _make_ai_pokemon_card_data(
		"Attacker",
		"Basic",
		"",
		"",
		[],
		[{"name": "Zap", "cost": "C", "damage": "10", "text": "", "is_vstar_power": false}]
	)
	var active_slot := _make_ai_slot(CardInstance.create(attack_cd, 0))
	active_slot.attached_energy.append(CardInstance.create(_make_ai_energy_card_data("Lightning Energy"), 0))
	player.active_pokemon = active_slot
	opponent.active_pokemon = _make_ai_slot(CardInstance.create(_make_ai_pokemon_card_data("Defender"), 1))
	var actions := _build_ai_actions(gsm)
	return run_checks([
		assert_not_null(builder, "AILegalActionBuilder should load"),
		assert_eq(_count_actions_by_kind(actions, "attack"), 1, "Builder should enumerate attacks that are currently usable"),
		assert_true(_has_action(actions, "attack", {"attack_index": 0, "targets": []}), "Builder should include a normalized attack action"),
	])


func test_ai_legal_action_builder_enumerates_end_turn_actions() -> String:
	var gsm := _make_ai_manual_gsm()
	var builder: Variant = _new_legal_action_builder()
	var player: PlayerState = gsm.game_state.players[0]
	player.active_pokemon = _make_ai_slot(CardInstance.create(_make_ai_pokemon_card_data("Lead"), 0))
	var actions := _build_ai_actions(gsm)
	return run_checks([
		assert_not_null(builder, "AILegalActionBuilder should load"),
		assert_eq(_count_actions_by_kind(actions, "end_turn"), 1, "Builder should always allow ending the turn from the main phase"),
		assert_true(_has_action(actions, "end_turn"), "Builder should include end_turn as a normalized action"),
	])


func test_ai_opponent_resolves_effect_interaction_dialog_choice() -> String:
	var previous_mode: int = GameManager.current_mode
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	var scene := _make_battle_scene_refresh_stub()
	scene._setup_ai_for_tests()
	scene.set("_field_interaction_overlay", null)
	scene.call("_setup_field_interaction_panel")
	var gsm := _make_ai_manual_gsm()
	gsm.game_state.current_player_index = 1
	scene.set("_gsm", gsm)
	var option_a := CardInstance.create(_make_ai_trainer_card_data("Option A", "Item"), 1)
	var option_b := CardInstance.create(_make_ai_trainer_card_data("Option B", "Item"), 1)
	var hold_step := {
		"id": "hold",
		"title": "Hold",
		"items": [CardInstance.create(_make_ai_trainer_card_data("Hold", "Item"), 1)],
		"labels": ["Hold"],
		"min_select": 1,
		"max_select": 1,
	}
	var steps: Array[Dictionary] = [
		{
			"id": "pick_card",
			"title": "Pick a card",
			"items": [option_a, option_b],
			"labels": ["A", "B"],
			"min_select": 1,
			"max_select": 1,
		},
		hold_step,
	]
	GameManager.current_mode = GameManager.GameMode.VS_AI
	scene.call("_start_effect_interaction", "trainer", 1, steps, CardInstance.create(_make_ai_trainer_card_data("Trainer", "Item"), 1))

	var handled := ai.run_single_step(scene, gsm)
	var context: Dictionary = scene.get("_pending_effect_context")
	var selected_cards: Array = context.get("pick_card", [])
	var first_selected_card: Variant = selected_cards[0] if not selected_cards.is_empty() else null
	GameManager.current_mode = previous_mode
	return run_checks([
		assert_true(handled, "AI should resolve simple dialog-based effect steps"),
		assert_eq(int(scene.get("_pending_effect_step_index")), 1, "AI should advance to the next effect step after resolving a dialog choice"),
		assert_eq(selected_cards.size(), 1, "AI should store exactly one selected card"),
		assert_eq(first_selected_card, option_a, "AI should pick the first legal dialog option for the baseline policy"),
		assert_eq(str(scene.get("_pending_choice")), "effect_interaction", "Effect interaction flow should continue to the next step"),
	])


func test_ai_opponent_resolves_effect_interaction_field_slot_choice() -> String:
	var previous_mode: int = GameManager.current_mode
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	var scene := _make_battle_scene_refresh_stub()
	scene._setup_ai_for_tests()
	scene.set("_field_interaction_overlay", null)
	scene.call("_setup_field_interaction_panel")
	var gsm := _make_ai_manual_gsm()
	gsm.game_state.current_player_index = 1
	scene.set("_gsm", gsm)
	var player: PlayerState = gsm.game_state.players[1]
	var bench_a := _make_ai_slot(CardInstance.create(_make_ai_pokemon_card_data("Bench A"), 1))
	var bench_b := _make_ai_slot(CardInstance.create(_make_ai_pokemon_card_data("Bench B"), 1))
	player.bench = [bench_a, bench_b]
	var hold_step := {
		"id": "hold",
		"title": "Hold",
		"items": [CardInstance.create(_make_ai_trainer_card_data("Hold", "Item"), 1)],
		"labels": ["Hold"],
		"min_select": 1,
		"max_select": 1,
	}
	var steps: Array[Dictionary] = [
		{
			"id": "pick_slot",
			"title": "Pick a Pokemon",
			"items": [bench_a, bench_b],
			"min_select": 1,
			"max_select": 1,
		},
		hold_step,
	]
	GameManager.current_mode = GameManager.GameMode.VS_AI
	scene.call("_start_effect_interaction", "trainer", 1, steps, CardInstance.create(_make_ai_trainer_card_data("Trainer", "Item"), 1))

	var handled := ai.run_single_step(scene, gsm)
	var context: Dictionary = scene.get("_pending_effect_context")
	var selected_slots: Array = context.get("pick_slot", [])
	var first_selected_slot: Variant = selected_slots[0] if not selected_slots.is_empty() else null
	GameManager.current_mode = previous_mode
	return run_checks([
		assert_true(handled, "AI should resolve PokemonSlot effect steps through the field UI path"),
		assert_eq(int(scene.get("_pending_effect_step_index")), 1, "AI should advance after selecting a field slot"),
		assert_eq(selected_slots.size(), 1, "AI should store exactly one selected PokemonSlot"),
		assert_eq(first_selected_slot, bench_a, "AI should choose the first legal PokemonSlot by default"),
		assert_eq(str(scene.get("_field_interaction_mode")), "", "Field interaction UI should close after AI finalizes the slot choice"),
	])


func test_ai_opponent_resolves_effect_interaction_assignment_step() -> String:
	var previous_mode: int = GameManager.current_mode
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	var scene := _make_battle_scene_refresh_stub()
	scene._setup_ai_for_tests()
	scene.set("_field_interaction_overlay", null)
	scene.call("_setup_field_interaction_panel")
	var gsm := _make_ai_manual_gsm()
	gsm.game_state.current_player_index = 1
	scene.set("_gsm", gsm)
	var player: PlayerState = gsm.game_state.players[1]
	var bench_a := _make_ai_slot(CardInstance.create(_make_ai_pokemon_card_data("Bench A"), 1))
	var bench_b := _make_ai_slot(CardInstance.create(_make_ai_pokemon_card_data("Bench B"), 1))
	player.bench = [bench_a, bench_b]
	var energy_a := CardInstance.create(_make_ai_energy_card_data("Energy A"), 1)
	var energy_b := CardInstance.create(_make_ai_energy_card_data("Energy B"), 1)
	var hold_step := {
		"id": "hold",
		"title": "Hold",
		"items": [CardInstance.create(_make_ai_trainer_card_data("Hold", "Item"), 1)],
		"labels": ["Hold"],
		"min_select": 1,
		"max_select": 1,
	}
	var steps: Array[Dictionary] = [
		{
			"id": "assign_energy",
			"title": "Assign energy",
			"ui_mode": "card_assignment",
			"source_items": [energy_a, energy_b],
			"target_items": [bench_a, bench_b],
			"min_select": 2,
			"max_select": 2,
			"source_exclude_targets": {
				1: [0],
			},
		},
		hold_step,
	]
	GameManager.current_mode = GameManager.GameMode.VS_AI
	scene.call("_start_effect_interaction", "trainer", 1, steps, CardInstance.create(_make_ai_trainer_card_data("Trainer", "Item"), 1))

	var handled := ai.run_single_step(scene, gsm)
	var context: Dictionary = scene.get("_pending_effect_context")
	var assignments: Array = context.get("assign_energy", [])
	var first_assignment: Dictionary = assignments[0] if not assignments.is_empty() else {}
	var second_assignment: Dictionary = assignments[1] if assignments.size() > 1 else {}
	GameManager.current_mode = previous_mode
	return run_checks([
		assert_true(handled, "AI should resolve card-assignment effect steps"),
		assert_eq(int(scene.get("_pending_effect_step_index")), 1, "AI should advance after finalizing the assignment step"),
		assert_eq(assignments.size(), 2, "AI should complete the required number of assignments"),
		assert_eq(first_assignment.get("source"), energy_a, "AI should assign the first source item first"),
		assert_eq(first_assignment.get("target"), bench_a, "AI should pick the first legal target for the first source item"),
		assert_eq(second_assignment.get("source"), energy_b, "AI should continue with the next source item"),
		assert_eq(second_assignment.get("target"), bench_b, "AI should respect source_exclude_targets when assigning later sources"),
	])


func test_battle_scene_schedules_ai_for_effect_interaction_prompt_owned_by_ai() -> String:
	var previous_mode: int = GameManager.current_mode
	var scene := _make_battle_scene_refresh_stub()
	scene._setup_ai_for_tests()
	scene.set("_field_interaction_overlay", null)
	scene.call("_setup_field_interaction_panel")
	var gsm := _make_ai_manual_gsm()
	gsm.game_state.current_player_index = 0
	scene.set("_gsm", gsm)
	var opponent: PlayerState = gsm.game_state.players[1]
	var bench_a := _make_ai_slot(CardInstance.create(_make_ai_pokemon_card_data("Bench A"), 1))
	var bench_b := _make_ai_slot(CardInstance.create(_make_ai_pokemon_card_data("Bench B"), 1))
	opponent.bench = [bench_a, bench_b]
	var hold_step := {
		"id": "hold",
		"title": "Hold",
		"items": [CardInstance.create(_make_ai_trainer_card_data("Hold", "Item"), 1)],
		"labels": ["Hold"],
		"min_select": 1,
		"max_select": 1,
	}
	GameManager.current_mode = GameManager.GameMode.VS_AI
	var steps: Array[Dictionary] = [
		{
			"id": "opponent_pick",
			"title": "Opponent chooses",
			"items": [bench_a, bench_b],
			"min_select": 1,
			"max_select": 1,
			"chooser_player_index": 1,
		},
		hold_step,
	]
	scene.call("_start_effect_interaction", "ability", 0, steps, CardInstance.create(_make_ai_pokemon_card_data("Human Card", "Basic"), 0))
	scene._maybe_run_ai()
	var scheduled := bool(scene.get("_ai_step_scheduled"))
	scene._run_ai_step()
	GameManager.current_mode = previous_mode
	var context: Dictionary = scene.get("_pending_effect_context")
	var selected_slots: Array = context.get("opponent_pick", [])
	var first_selected_slot: Variant = selected_slots[0] if not selected_slots.is_empty() else null
	return run_checks([
		assert_true(scheduled, "BattleScene should schedule AI when the pending effect step chooser is the AI player"),
		assert_eq(int(scene.get("_pending_effect_step_index")), 1, "AI should advance the human-owned interaction once it resolves the chooser step"),
		assert_eq(selected_slots.size(), 1, "AI-owned chooser steps should still record a selection"),
		assert_eq(first_selected_slot, bench_a, "Baseline AI should pick the first legal slot for chooser-owned effect prompts"),
	])


func test_ai_heuristics_prioritize_knockout_attack() -> String:
	var heuristics = AIHeuristicsScript.new()
	var attack_action := {"kind": "attack", "projected_knockout": true}
	var end_turn_action := {"kind": "end_turn"}
	return run_checks([
		assert_true(
			heuristics.score_action(attack_action, {}) > heuristics.score_action(end_turn_action, {}),
			"Knockout attacks should outrank ending the turn"
		),
	])


func test_ai_heuristics_prioritize_play_basic_to_bench_over_end_turn() -> String:
	var heuristics = AIHeuristicsScript.new()
	var bench_action := {"kind": "play_basic_to_bench"}
	var end_turn_action := {"kind": "end_turn"}
	return run_checks([
		assert_true(
			heuristics.score_action(bench_action, {}) > heuristics.score_action(end_turn_action, {}),
			"Benching a Basic should outrank ending the turn"
		),
	])


func test_ai_heuristics_prioritize_active_attach_targets() -> String:
	var heuristics = AIHeuristicsScript.new()
	var active_attach := {"kind": "attach_energy", "is_active_target": true}
	var bench_attach := {"kind": "attach_energy", "is_active_target": false}
	return run_checks([
		assert_true(
			heuristics.score_action(active_attach, {}) > heuristics.score_action(bench_attach, {}),
			"Attaching to the active Pokemon should outrank a generic bench attach in the baseline policy"
		),
	])


func test_ai_heuristics_prioritize_productive_attach_over_dead_trainer() -> String:
	var heuristics = AIHeuristicsScript.new()
	var attach_action := {"kind": "attach_energy", "is_active_target": true}
	var dead_trainer := {"kind": "play_trainer", "productive": false}
	return run_checks([
		assert_true(
			heuristics.score_action(attach_action, {}) > heuristics.score_action(dead_trainer, {}),
			"Productive attaches should outrank low-value trainer plays"
		),
	])


func test_ai_opponent_executes_attack_before_ending_turn() -> String:
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	var scene := _make_battle_scene_refresh_stub()
	scene._setup_ai_for_tests()
	var gsm := _make_ai_manual_gsm()
	gsm.game_state.current_player_index = 1
	scene.set("_gsm", gsm)
	var player: PlayerState = gsm.game_state.players[1]
	var opponent: PlayerState = gsm.game_state.players[0]
	var attacker_cd := _make_ai_pokemon_card_data(
		"Attacker",
		"Basic",
		"",
		"",
		[],
		[{"name": "Zap", "cost": "C", "damage": "50", "text": "", "is_vstar_power": false}]
	)
	var attacker_slot := _make_ai_slot(CardInstance.create(attacker_cd, 1))
	attacker_slot.attached_energy.append(CardInstance.create(_make_ai_energy_card_data("Lightning Energy"), 1))
	player.active_pokemon = attacker_slot
	opponent.active_pokemon = _make_ai_slot(CardInstance.create(_make_ai_pokemon_card_data("Defender"), 0))

	var handled := ai.run_single_step(scene, gsm)
	return run_checks([
		assert_true(handled, "AI should execute an available attack"),
		assert_eq(opponent.active_pokemon.damage_counters, 50, "AI should deal attack damage before considering end_turn"),
		assert_true(gsm.game_state.phase != GameState.GamePhase.MAIN, "Executing the attack should leave the main-phase idle state"),
	])


func test_ai_opponent_plays_basic_to_bench_when_no_attack_is_available() -> String:
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	var scene := _make_battle_scene_refresh_stub()
	scene._setup_ai_for_tests()
	var gsm := _make_ai_manual_gsm()
	gsm.game_state.current_player_index = 1
	scene.set("_gsm", gsm)
	var player: PlayerState = gsm.game_state.players[1]
	player.active_pokemon = _make_ai_slot(CardInstance.create(_make_ai_pokemon_card_data("Lead"), 1))
	var bench_basic := CardInstance.create(_make_ai_pokemon_card_data("Bench Basic"), 1)
	player.hand = [bench_basic]

	var handled := ai.run_single_step(scene, gsm)
	return run_checks([
		assert_true(handled, "AI should play a benchable Basic when it cannot attack"),
		assert_eq(player.bench.size(), 1, "AI should place the Basic onto the bench"),
		assert_eq(player.bench[0].get_pokemon_name(), "Bench Basic", "AI should bench the available Basic Pokemon"),
		assert_false(bench_basic in player.hand, "The benched Basic should leave the hand"),
	])


func test_ai_opponent_routes_setup_active_prompt_through_setup_planner() -> String:
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	var scene := SpySetupBattleScene.new()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.SETUP
	gsm.game_state.current_player_index = 1
	gsm.game_state.players = [_make_player_state(0), _make_player_state(1)]
	var player: PlayerState = gsm.game_state.players[1]
	player.hand = [_make_basic("A"), _make_basic("B"), _make_item("Ball")]
	scene.set("_gsm", gsm)
	scene.set("_setup_done", [false, false])
	scene.set("_view_player", 1)
	scene.set("_pending_choice", "setup_active_1")
	scene.set("_dialog_data", {
		"basics": [player.hand[0], player.hand[1]],
		"player": 1,
	})

	var handled := ai.run_single_step(scene, gsm)
	return run_checks([
		assert_true(handled, "AI should handle setup active prompts"),
		assert_not_null(player.active_pokemon, "AI should place an active Pokemon during setup"),
		assert_eq(player.active_pokemon.get_pokemon_name(), "A", "AI should choose the first available Basic as active"),
		assert_eq(scene.after_setup_active_calls.size(), 1, "AI should advance the setup flow after placing the active Pokemon"),
	])


func test_ai_opponent_routes_setup_bench_prompt_through_setup_planner() -> String:
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	var scene := SpySetupBattleScene.new()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.SETUP
	gsm.game_state.current_player_index = 1
	gsm.game_state.players = [_make_player_state(0), _make_player_state(1)]
	var player: PlayerState = gsm.game_state.players[1]
	player.active_pokemon = PokemonSlot.new()
	player.active_pokemon.pokemon_stack.append(_make_basic("Lead"))
	player.hand = [_make_basic("Bench A"), _make_item("Ball")]
	scene.set("_gsm", gsm)
	scene.set("_setup_done", [false, false])
	scene.set("_view_player", 1)
	scene.set("_pending_choice", "setup_bench_1")
	scene.set("_dialog_data", {
		"cards": [player.hand[0]],
		"player": 1,
	})

	var handled := ai.run_single_step(scene, gsm)
	return run_checks([
		assert_true(handled, "AI should handle setup bench prompts"),
		assert_eq(player.bench.size(), 1, "AI should bench an extra Basic during setup"),
		assert_eq(player.bench[0].get_pokemon_name(), "Bench A", "AI should choose the available Basic for bench"),
		assert_eq(scene.refresh_ui_calls, 1, "AI should request a refresh after benching a Basic"),
		assert_eq(scene.show_setup_bench_dialog_calls.size(), 1, "AI should continue the bench setup flow after a successful bench placement"),
	])


func test_ai_opponent_clears_final_setup_bench_prompt_before_advancing() -> String:
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	var scene := SpySetupBattleScene.new()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.SETUP
	gsm.game_state.current_player_index = 1
	gsm.game_state.players = [_make_player_state(0), _make_player_state(1)]
	var player: PlayerState = gsm.game_state.players[1]
	player.active_pokemon = PokemonSlot.new()
	player.active_pokemon.pokemon_stack.append(_make_basic("Lead"))
	scene.set("_gsm", gsm)
	scene.set("_setup_done", [false, false])
	scene.set("_view_player", 1)
	scene.set("_pending_choice", "setup_bench_1")
	scene.set("_dialog_data", {
		"cards": [],
		"player": 1,
	})

	var handled := ai.run_single_step(scene, gsm)
	return run_checks([
		assert_true(handled, "AI should handle a final setup bench prompt with no remaining Basics"),
		assert_eq(str(scene.get("_pending_choice")), "", "AI should clear setup_bench after finishing the setup bench step"),
		assert_eq(scene.after_setup_bench_calls.size(), 1, "AI should still advance the setup flow once"),
	])


func test_ai_opponent_accepts_mulligan_bonus_draw_prompt() -> String:
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	var scene := BattleSceneScript.new()
	var gsm := SpyGameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.SETUP
	gsm.game_state.current_player_index = 1
	gsm.game_state.players = [_make_player_state(0), _make_player_state(1)]
	scene.set("_gsm", gsm)
	scene.set("_pending_choice", "mulligan_extra_draw")
	scene.set("_dialog_data", {"beneficiary": 1})

	var handled := ai.run_single_step(scene, gsm)
	return run_checks([
		assert_true(handled, "AI should handle mulligan bonus-draw prompts"),
		assert_eq(gsm.mulligan_resolve_calls, 1, "AI should resolve mulligan choice exactly once"),
		assert_eq(gsm.resolved_beneficiary, 1, "AI should resolve the configured mulligan beneficiary"),
		assert_eq(gsm.resolved_draw_extra, true, "Baseline AI should always accept the extra draw"),
	])


func test_ai_opponent_clears_mulligan_prompt_after_resolving_it() -> String:
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	var scene := BattleSceneScript.new()
	var gsm := SpyGameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.SETUP
	gsm.game_state.current_player_index = 1
	gsm.game_state.players = [_make_player_state(0), _make_player_state(1)]
	scene.set("_gsm", gsm)
	scene.set("_pending_choice", "mulligan_extra_draw")
	scene.set("_dialog_data", {"beneficiary": 1})

	var handled := ai.run_single_step(scene, gsm)
	return run_checks([
		assert_true(handled, "AI should still resolve the mulligan prompt"),
		assert_eq(str(scene.get("_pending_choice")), "", "AI should clear mulligan_extra_draw after consuming it"),
	])


func test_ai_opponent_resolves_ai_owned_take_prize_prompt() -> String:
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	var scene := _make_battle_scene_refresh_stub()
	scene._setup_ai_for_tests()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.current_player_index = 1
	gsm.game_state.players = [_make_player_state(0), _make_player_state(1)]
	var prize_card := _make_item("Prize")
	gsm.game_state.players[1].set_prizes([prize_card])
	scene.set("_gsm", gsm)
	scene.set("_pending_choice", "take_prize")
	scene.set("_pending_prize_player_index", 1)
	scene.set("_pending_prize_remaining", 1)
	gsm.set("_pending_prize_player_index", 1)
	gsm.set("_pending_prize_remaining", 1)
	scene.set("_opp_prize_slots", [BattleCardViewScript.new()])

	var handled := ai.run_single_step(scene, gsm)
	return run_checks([
		assert_true(handled, "AI should handle its own take_prize prompt"),
		assert_eq(gsm.game_state.players[1].prizes.size(), 0, "AI should remove a prize card from its prize area"),
		assert_true(prize_card in gsm.game_state.players[1].hand, "AI should put the taken prize into hand"),
		assert_eq(str(scene.get("_pending_choice")), "", "AI should clear the take_prize prompt after resolving it"),
	])


func test_ai_opponent_waits_for_delayed_prize_animation_before_fallback_resolve() -> String:
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	var scene := DelayedPrizeAnimationScene.new()
	var gsm := SpyPrizeResolveGameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.current_player_index = 1
	gsm.game_state.players = [_make_player_state(0), _make_player_state(1)]
	gsm.game_state.players[1].set_prizes([_make_item("Prize")])
	gsm.set("_pending_prize_player_index", 1)
	gsm.set("_pending_prize_remaining", 1)

	var handled := ai.run_single_step(scene, gsm)
	return run_checks([
		assert_true(handled, "AI should treat a started prize flip animation as handled work"),
		assert_eq(scene.try_take_prize_calls, 1, "AI should still kick off the prize flip interaction"),
		assert_true(bool(scene.get("_pending_prize_animating")), "Prize prompt should remain in the animating state"),
		assert_eq(gsm.resolve_take_prize_calls, 0, "AI should not fallback to GameStateMachine.resolve_take_prize while the flip animation is running"),
		assert_eq(str(scene.get("_pending_choice")), "take_prize", "AI should leave the take_prize prompt pending until the animation callback completes"),
	])


func test_ai_opponent_ignores_human_owned_mulligan_bonus_draw_prompt() -> String:
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	var scene := BattleSceneScript.new()
	var gsm := SpyGameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.SETUP
	gsm.game_state.current_player_index = 1
	gsm.game_state.players = [_make_player_state(0), _make_player_state(1)]
	scene.set("_gsm", gsm)
	scene.set("_pending_choice", "mulligan_extra_draw")
	scene.set("_dialog_data", {"beneficiary": 0})

	var handled := ai.run_single_step(scene, gsm)
	return run_checks([
		assert_false(handled, "AI should ignore mulligan prompts owned by the human player"),
		assert_eq(gsm.mulligan_resolve_calls, 0, "AI should not resolve a human-owned mulligan prompt"),
	])


func test_battle_scene_schedules_ai_for_mulligan_setup_prompt() -> String:
	var previous_mode: int = GameManager.current_mode
	var scene := _make_setup_ready_battle_scene()
	var gsm := SpyGameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.SETUP
	gsm.game_state.current_player_index = 0
	gsm.game_state.players = [_make_player_state(0), _make_player_state(1)]
	GameManager.current_mode = GameManager.GameMode.VS_AI
	scene.set("_gsm", gsm)
	scene._on_player_choice_required("mulligan_extra_draw", {"beneficiary": 1, "mulligan_count": 1})
	var scheduled_after_prompt: bool = scene.get("_ai_step_scheduled")
	scene._run_ai_step()
	GameManager.current_mode = previous_mode
	return run_checks([
		assert_true(scene.get("_dialog_overlay").visible, "Mulligan prompt should show the dialog overlay"),
		assert_true(scheduled_after_prompt, "BattleScene should schedule AI for its mulligan setup prompt"),
		assert_eq(gsm.mulligan_resolve_calls, 1, "BattleScene should drive the AI mulligan choice through the real scheduling path"),
		assert_eq(gsm.resolved_beneficiary, 1, "BattleScene should pass the mulligan beneficiary through unchanged"),
		assert_true(gsm.resolved_draw_extra, "Baseline AI should still accept the mulligan bonus draw"),
	])


func test_battle_scene_schedules_ai_for_setup_active_prompt_target_player() -> String:
	var previous_mode: int = GameManager.current_mode
	var scene := _make_setup_ready_battle_scene()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.SETUP
	gsm.game_state.current_player_index = 0
	gsm.game_state.players = [_make_player_state(0), _make_player_state(1)]
	var player: PlayerState = gsm.game_state.players[1]
	player.hand = [_make_basic("A"), _make_basic("B"), _make_item("Ball")]
	GameManager.current_mode = GameManager.GameMode.VS_AI
	scene.set("_gsm", gsm)
	scene._show_setup_active_dialog(1)
	var scheduled_after_prompt: bool = scene.get("_ai_step_scheduled")
	scene._run_ai_step()
	GameManager.current_mode = previous_mode
	return run_checks([
		assert_true(scene.get("_dialog_overlay").visible, "Setup active prompt should show the dialog overlay"),
		assert_true(scheduled_after_prompt, "BattleScene should schedule AI for setup_active prompts owned by the AI"),
		assert_not_null(player.active_pokemon, "AI should place its active Pokemon through BattleScene scheduling"),
		assert_eq(player.active_pokemon.get_pokemon_name(), "A", "AI should still choose the first available Basic as active"),
	])


func test_battle_scene_schedules_ai_for_setup_bench_prompt_target_player() -> String:
	var previous_mode: int = GameManager.current_mode
	var scene := _make_setup_ready_battle_scene()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.SETUP
	gsm.game_state.current_player_index = 0
	gsm.game_state.players = [_make_player_state(0), _make_player_state(1)]
	var player: PlayerState = gsm.game_state.players[1]
	player.active_pokemon = PokemonSlot.new()
	player.active_pokemon.pokemon_stack.append(_make_basic("Lead"))
	player.hand = [_make_basic("Bench A"), _make_item("Ball")]
	GameManager.current_mode = GameManager.GameMode.VS_AI
	scene.set("_gsm", gsm)
	scene._show_setup_bench_dialog(1)
	var scheduled_after_prompt: bool = scene.get("_ai_step_scheduled")
	scene._run_ai_step()
	GameManager.current_mode = previous_mode
	return run_checks([
		assert_true(scene.get("_dialog_overlay").visible, "Setup bench prompt should show the dialog overlay"),
		assert_true(scheduled_after_prompt, "BattleScene should schedule AI for setup_bench prompts owned by the AI"),
		assert_eq(player.bench.size(), 1, "AI should place a bench Pokemon through BattleScene scheduling"),
		assert_eq(player.bench[0].get_pokemon_name(), "Bench A", "AI should choose the available Basic for bench"),
	])


func test_ai_opponent_reuses_planned_setup_bench_choices_across_repeated_prompts() -> String:
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	var scene := SpySetupBattleScene.new()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.phase = GameState.GamePhase.SETUP
	gsm.game_state.current_player_index = 1
	gsm.game_state.players = [_make_player_state(0), _make_player_state(1)]
	var player: PlayerState = gsm.game_state.players[1]
	player.hand = [_make_basic("Active A"), _make_basic("Bench A"), _make_basic("Bench B"), _make_item("Ball")]
	scene.set("_gsm", gsm)
	scene.set("_setup_done", [false, false])
	scene.set("_view_player", 1)
	scene.set("_pending_choice", "setup_active_1")
	scene.set("_dialog_data", {
		"basics": [player.hand[0], player.hand[1], player.hand[2]],
		"player": 1,
	})

	var handled_active := ai.run_single_step(scene, gsm)
	scene.set("_pending_choice", "setup_bench_1")
	scene.set("_dialog_data", {
		"cards": [player.hand[0], player.hand[1]],
		"player": 1,
	})
	var handled_first_bench := ai.run_single_step(scene, gsm)
	scene.set("_pending_choice", "setup_bench_1")
	scene.set("_dialog_data", {
		"cards": [player.hand[0]],
		"player": 1,
	})
	var handled_second_bench := ai.run_single_step(scene, gsm)

	return run_checks([
		assert_true(handled_active, "AI should plan setup from the active prompt"),
		assert_true(handled_first_bench, "AI should consume the first repeated bench prompt"),
		assert_true(handled_second_bench, "AI should consume the second repeated bench prompt"),
		assert_eq(player.bench.size(), 2, "AI should bench both planned Basics across repeated prompts"),
		assert_eq(player.bench[0].get_pokemon_name(), "Bench A", "AI should bench the first planned Basic first"),
		assert_eq(player.bench[1].get_pokemon_name(), "Bench B", "AI should carry the remaining planned Basic to the next prompt"),
	])


func test_battle_scene_schedules_ai_in_vs_ai_when_unblocked() -> String:
	var previous_mode: int = GameManager.current_mode
	var scene := BattleSceneScript.new()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 1
	var spy_ai := SpyAIOpponent.new()
	GameManager.current_mode = GameManager.GameMode.VS_AI
	scene.set("_gsm", gsm)
	scene.set("_dialog_overlay", Panel.new())
	scene.set("_handover_panel", Panel.new())
	scene.set("_coin_overlay", Panel.new())
	scene.set("_detail_overlay", Panel.new())
	scene.set("_discard_overlay", Panel.new())
	scene.set("_field_interaction_overlay", Control.new())
	scene._setup_ai_for_tests()
	scene.set("_ai_opponent", spy_ai)
	scene._maybe_run_ai()
	var scheduled_after_maybe_run: bool = scene.get("_ai_step_scheduled")
	scene._run_ai_step()
	var checks := run_checks([
		assert_true(scheduled_after_maybe_run, "BattleScene should request a deferred AI step in VS_AI mode on the AI turn"),
		assert_eq(spy_ai.run_count, 1, "BattleScene should execute exactly one AI step when the deferred step runs"),
		assert_false(scene.get("_ai_step_scheduled"), "BattleScene should clear the scheduled AI step flag after running"),
	])
	GameManager.current_mode = previous_mode
	return checks


func test_battle_scene_handover_confirmation_callback_schedules_ai_in_vs_ai() -> String:
	var previous_mode: int = GameManager.current_mode
	var scene := BattleSceneScript.new()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 1
	var spy_ai := SpyAIOpponent.new()
	GameManager.current_mode = GameManager.GameMode.VS_AI
	scene.set("_gsm", gsm)
	scene.set("_dialog_overlay", Panel.new())
	scene.set("_handover_panel", Panel.new())
	scene.set("_coin_overlay", Panel.new())
	scene.set("_detail_overlay", Panel.new())
	scene.set("_discard_overlay", Panel.new())
	scene.set("_field_interaction_overlay", Control.new())
	scene._setup_ai_for_tests()
	scene.set("_ai_opponent", spy_ai)
	scene.set("_pending_handover_action", func() -> void:
		pass
	)
	scene._on_handover_confirmed()
	var scheduled_after_callback: bool = scene.get("_ai_step_scheduled")
	scene._run_ai_step()
	GameManager.current_mode = previous_mode
	return run_checks([
		assert_true(scheduled_after_callback, "Handover confirmation should schedule AI on the AI turn in VS_AI mode"),
		assert_eq(spy_ai.run_count, 1, "Handover confirmation should lead to one AI step"),
	])


func test_battle_scene_handover_confirmation_does_not_schedule_ai_outside_vs_ai() -> String:
	var previous_mode: int = GameManager.current_mode
	var scene := BattleSceneScript.new()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 1
	var spy_ai := SpyAIOpponent.new()
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER
	scene.set("_gsm", gsm)
	scene.set("_dialog_overlay", Panel.new())
	scene.set("_handover_panel", Panel.new())
	scene.set("_coin_overlay", Panel.new())
	scene.set("_detail_overlay", Panel.new())
	scene.set("_discard_overlay", Panel.new())
	scene.set("_field_interaction_overlay", Control.new())
	scene._setup_ai_for_tests()
	scene.set("_ai_opponent", spy_ai)
	scene.set("_pending_handover_action", func() -> void:
		pass
	)
	scene._on_handover_confirmed()
	var scheduled_after_callback: bool = scene.get("_ai_step_scheduled")
	GameManager.current_mode = previous_mode
	return run_checks([
		assert_false(scheduled_after_callback, "Handover confirmation should not schedule AI outside VS_AI mode"),
		assert_eq(spy_ai.run_count, 0, "Blocked handover callback should not run the AI"),
	])


func test_battle_scene_retreat_action_path_schedules_ai_after_success() -> String:
	var previous_mode: int = GameManager.current_mode
	var scene := _make_battle_scene_refresh_stub()
	var gsm := SpyGameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 1
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.players = [_make_player_state(0), _make_player_state(1)]
	var bench_target := PokemonSlot.new()
	bench_target.pokemon_stack.append(CardInstance.create(CardData.new(), 1))
	var spy_ai := SpyAIOpponent.new()
	GameManager.current_mode = GameManager.GameMode.VS_AI
	scene.set("_gsm", gsm)
	scene._setup_ai_for_tests()
	scene.set("_ai_opponent", spy_ai)
	scene.set("_pending_choice", "retreat_bench")
	scene.set("_dialog_data", {
		"player": 1,
		"bench": [bench_target],
		"energy_discard": [],
	})
	scene._handle_dialog_choice(PackedInt32Array([0]))
	var scheduled_after_retreat: bool = scene.get("_ai_step_scheduled")
	GameManager.current_mode = previous_mode
	return run_checks([
		assert_eq(gsm.retreat_calls, 1, "Retreat action path should call GameStateMachine.retreat"),
		assert_true(scheduled_after_retreat, "Successful retreat action path should schedule the AI"),
	])


func test_battle_scene_running_ai_can_queue_followup_step_from_success_hook() -> String:
	var previous_mode: int = GameManager.current_mode
	var scene := _make_battle_scene_refresh_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 1
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.players = [_make_player_state(0), _make_player_state(1)]
	var spy_ai := FollowupSchedulingSpyAIOpponent.new()
	GameManager.current_mode = GameManager.GameMode.VS_AI
	scene.set("_gsm", gsm)
	scene._setup_ai_for_tests()
	scene.set("_ai_opponent", spy_ai)
	scene._maybe_run_ai()
	scene._run_ai_step()
	var scheduled_followup: bool = scene.get("_ai_step_scheduled")
	GameManager.current_mode = previous_mode
	return run_checks([
		assert_eq(spy_ai.run_count, 1, "The first AI step should run"),
		assert_true(scheduled_followup, "A success hook during AI execution should queue one follow-up step"),
	])


func test_battle_scene_failed_retreat_does_not_schedule_ai() -> String:
	var previous_mode: int = GameManager.current_mode
	var scene := _make_battle_scene_refresh_stub()
	var gsm := SpyGameStateMachine.new()
	gsm.retreat_result = false
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 1
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.players = [_make_player_state(0), _make_player_state(1)]
	var bench_target := PokemonSlot.new()
	bench_target.pokemon_stack.append(CardInstance.create(CardData.new(), 1))
	var spy_ai := SpyAIOpponent.new()
	GameManager.current_mode = GameManager.GameMode.VS_AI
	scene.set("_gsm", gsm)
	scene._setup_ai_for_tests()
	scene.set("_ai_opponent", spy_ai)
	scene.set("_pending_choice", "retreat_bench")
	scene.set("_dialog_data", {
		"player": 1,
		"bench": [bench_target],
		"energy_discard": [],
	})
	scene._handle_dialog_choice(PackedInt32Array([0]))
	var scheduled_after_retreat: bool = scene.get("_ai_step_scheduled")
	GameManager.current_mode = previous_mode
	return run_checks([
		assert_eq(gsm.retreat_calls, 1, "Failed retreat path should still call GameStateMachine.retreat"),
		assert_false(scheduled_after_retreat, "Failed retreat should not schedule the AI"),
		assert_eq(spy_ai.run_count, 0, "Failed retreat should not run the AI"),
	])


func test_battle_scene_take_prize_prompt_schedules_ai_when_ai_owns_it() -> String:
	var previous_mode: int = GameManager.current_mode
	var scene := _make_battle_scene_refresh_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 1
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.players = [_make_player_state(0), _make_player_state(1)]
	var spy_ai := SpyAIOpponent.new()
	GameManager.current_mode = GameManager.GameMode.VS_AI
	scene.set("_gsm", gsm)
	scene._setup_ai_for_tests()
	scene.set("_ai_opponent", spy_ai)
	scene._on_player_choice_required("take_prize", {"player": 1, "count": 1})
	var scheduled_during_prize_choice: bool = scene.get("_ai_step_scheduled")
	GameManager.current_mode = previous_mode
	return run_checks([
		assert_eq(str(scene.get("_pending_choice")), "take_prize", "Prize prompt should leave take_prize pending"),
		assert_true(scheduled_during_prize_choice, "AI-owned prize prompts should schedule the AI"),
		assert_eq(spy_ai.run_count, 0, "Prize prompt should not run the AI"),
	])


func test_battle_scene_take_prize_prompt_blocks_ai_when_human_owns_it() -> String:
	var previous_mode: int = GameManager.current_mode
	var scene := _make_battle_scene_refresh_stub()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 1
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.players = [_make_player_state(0), _make_player_state(1)]
	var spy_ai := SpyAIOpponent.new()
	GameManager.current_mode = GameManager.GameMode.VS_AI
	scene.set("_gsm", gsm)
	scene._setup_ai_for_tests()
	scene.set("_ai_opponent", spy_ai)
	scene._on_player_choice_required("take_prize", {"player": 0, "count": 1})
	var scheduled_during_prize_choice: bool = scene.get("_ai_step_scheduled")
	GameManager.current_mode = previous_mode
	return run_checks([
		assert_eq(str(scene.get("_pending_choice")), "take_prize", "Prize prompt should leave take_prize pending"),
		assert_false(scheduled_during_prize_choice, "Human-owned prize prompts should still block the AI"),
		assert_eq(spy_ai.run_count, 0, "Human-owned prize prompts should not run the AI"),
	])


func test_battle_scene_does_not_schedule_ai_when_mode_turn_or_ui_block_it() -> String:
	var previous_mode: int = GameManager.current_mode
	var scene := BattleSceneScript.new()
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 1
	var spy_ai := SpyAIOpponent.new()
	var dialog_overlay := Panel.new()
	var handover_panel := Panel.new()
	var field_overlay := Control.new()
	scene.set("_gsm", gsm)
	scene.set("_dialog_overlay", dialog_overlay)
	scene.set("_handover_panel", handover_panel)
	scene.set("_coin_overlay", Panel.new())
	scene.set("_detail_overlay", Panel.new())
	scene.set("_discard_overlay", Panel.new())
	scene.set("_field_interaction_overlay", field_overlay)
	scene._setup_ai_for_tests()
	scene.set("_ai_opponent", spy_ai)

	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER
	scene._maybe_run_ai()
	var scheduled_outside_vs_ai: bool = scene.get("_ai_step_scheduled")
	GameManager.current_mode = GameManager.GameMode.VS_AI
	gsm.game_state.current_player_index = 0
	scene._maybe_run_ai()
	var scheduled_on_wrong_turn: bool = scene.get("_ai_step_scheduled")
	gsm.game_state.current_player_index = 1
	dialog_overlay.visible = true
	scene._maybe_run_ai()
	var scheduled_with_dialog: bool = scene.get("_ai_step_scheduled")
	dialog_overlay.visible = false
	handover_panel.visible = true
	scene._maybe_run_ai()
	var scheduled_with_handover: bool = scene.get("_ai_step_scheduled")
	handover_panel.visible = false
	field_overlay.visible = true
	scene._maybe_run_ai()
	var scheduled_with_field_overlay: bool = scene.get("_ai_step_scheduled")
	field_overlay.visible = false
	scene.set("_pending_prize_animating", true)
	scene._maybe_run_ai()
	var scheduled_with_prize_animation: bool = scene.get("_ai_step_scheduled")
	scene.set("_pending_prize_animating", false)

	GameManager.current_mode = previous_mode
	return run_checks([
		assert_false(scheduled_outside_vs_ai, "AI should not schedule outside VS_AI mode"),
		assert_false(scheduled_on_wrong_turn, "AI should not schedule on the human turn"),
		assert_false(scheduled_with_dialog, "Dialog overlay should block AI scheduling"),
		assert_false(scheduled_with_handover, "Handover prompt should block AI scheduling"),
		assert_false(scheduled_with_field_overlay, "Field interaction overlay should block AI scheduling"),
		assert_false(scheduled_with_prize_animation, "Prize animation should block AI scheduling"),
		assert_eq(spy_ai.run_count, 0, "BattleScene should not run the AI when scheduling is blocked"),
	])
