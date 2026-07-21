class_name TestBattleActionIntentLayer
extends TestBase

const IntentModelScript := preload("res://scripts/ui/battle/intent/BattleActionIntentModel.gd")
const IntentControllerScript := preload("res://scripts/ui/battle/intent/BattleActionIntentController.gd")
const SnapshotScript := preload("res://scripts/ui/battle/visuals/BattleVisualSnapshot.gd")


class IntentScene extends Control:
	var _gsm: GameStateMachine = null
	var _view_player := 0
	var _selected_hand_card: CardInstance = null
	var _pending_choice := ""
	var _draw_reveal_active := false
	var _ai_llm_waiting := false
	var review_mode := false
	var _hand_container: HBoxContainer = null
	var _slot_card_views: Dictionary = {}
	var _stadium_card_view: BattleCardView = null

	func _can_accept_live_action() -> bool:
		return true

	func _is_field_interaction_active() -> bool:
		return false

	func _is_review_mode() -> bool:
		return review_mode

	func _is_ai_action_pause_active() -> bool:
		return false


func _card(name: String, card_type: String, owner: int = 0, stage: String = "") -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.card_type = card_type
	data.stage = stage
	return CardInstance.create(data, owner)


func _pokemon(name: String, owner: int = 0, retreat_cost: int = 0) -> CardInstance:
	var card := _card(name, "Pokemon", owner, "Basic")
	card.card_data.hp = 100
	card.card_data.retreat_cost = retreat_cost
	return card


func _slot(card: CardInstance, turn_played: int = 1) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(card)
	slot.turn_played = turn_played
	return slot


func _gsm() -> GameStateMachine:
	var gsm := GameStateMachine.new()
	var state := GameState.new()
	state.turn_number = 3
	state.first_player_index = 0
	state.current_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	gsm.game_state = state
	return gsm


func test_idle_model_marks_only_currently_usable_hand_cards_and_keeps_block_reasons() -> String:
	var gsm := _gsm()
	var item := _card("可用物品", "Item")
	var supporter := _card("本回合第二张支援者", "Supporter")
	var energy := _card("基本火能量", "Basic Energy")
	energy.card_data.energy_provides = "R"
	gsm.game_state.players[0].hand = [item, supporter, energy]
	gsm.game_state.players[0].active_pokemon = _slot(_pokemon("战斗宝可梦"))
	gsm.game_state.supporter_used_this_turn = true
	gsm.game_state.energy_attached_this_turn = true

	var model: Dictionary = IntentModelScript.build(gsm, 0, null)
	var hand: Dictionary = model.get("hand_intents", {})
	var item_intent: Dictionary = hand.get(item.instance_id, {})
	var supporter_intent: Dictionary = hand.get(supporter.instance_id, {})
	var energy_intent: Dictionary = hand.get(energy.instance_id, {})

	return run_checks([
		assert_true(bool(model.get("enabled", false)), "Current MAIN player should receive an intent model"),
		assert_eq(str(item_intent.get("state", "")), "actionable", "Legal Item should pulse as usable"),
		assert_eq(str(supporter_intent.get("state", "")), "blocked", "Second Supporter should not pulse"),
		assert_str_contains(str(supporter_intent.get("reason", "")), "支援者", "Blocked Supporter should keep the rule reason"),
		assert_eq(str(energy_intent.get("state", "")), "blocked", "Second manual Energy attachment should not pulse"),
		assert_str_contains(str(energy_intent.get("reason", "")), "已经", "Blocked Energy should explain the once-per-turn limit"),
	])


func test_selected_energy_exposes_only_owned_occupied_slots_as_targets() -> String:
	var gsm := _gsm()
	var energy := _card("基本火能量", "Basic Energy")
	energy.card_data.energy_provides = "R"
	gsm.game_state.players[0].hand = [energy]
	gsm.game_state.players[0].active_pokemon = _slot(_pokemon("我方战斗"))
	gsm.game_state.players[0].bench = [_slot(_pokemon("我方备战"))]
	gsm.game_state.players[1].active_pokemon = _slot(_pokemon("对方战斗", 1))

	var model: Dictionary = IntentModelScript.build(gsm, 0, energy)
	var target_ids: Array = model.get("target_slot_ids", [])

	return run_checks([
		assert_eq(str(model.get("mode", "")), "target", "Selected Energy should enter target intent mode"),
		assert_true(target_ids.has("my_active"), "Owned active Pokemon should be a legal Energy target"),
		assert_true(target_ids.has("my_bench_0"), "Owned occupied Bench Pokemon should be a legal Energy target"),
		assert_false(target_ids.has("my_bench_1"), "Empty Bench slots are not Energy targets"),
		assert_false(target_ids.has("opp_active"), "Opponent Pokemon must never be offered as a hand attachment target"),
	])


func test_selected_evolution_and_basic_pokemon_build_exact_target_sets() -> String:
	var gsm := _gsm()
	var base := _pokemon("拉鲁拉丝")
	var other := _pokemon("波波")
	gsm.game_state.players[0].active_pokemon = _slot(base, 1)
	gsm.game_state.players[0].bench = [_slot(other, 1)]
	var evolution := _card("奇鲁莉安", "Pokemon", 0, "Stage 1")
	evolution.card_data.evolves_from = "拉鲁拉丝"
	var basic := _pokemon("新基础宝可梦")
	gsm.game_state.players[0].hand = [evolution, basic]

	var evolution_model: Dictionary = IntentModelScript.build(gsm, 0, evolution)
	var basic_model: Dictionary = IntentModelScript.build(gsm, 0, basic)
	var evolution_targets: Array = evolution_model.get("target_slot_ids", [])
	var basic_targets: Array = basic_model.get("target_slot_ids", [])

	return run_checks([
		assert_eq(evolution_targets, ["my_active"], "Evolution should highlight only a matching mature stack"),
		assert_eq(basic_targets, ["my_bench_1", "my_bench_2", "my_bench_3", "my_bench_4"], "Basic Pokemon should highlight every currently empty Bench slot"),
	])


func test_idle_model_marks_field_pokemon_only_when_a_real_action_is_available() -> String:
	var gsm := _gsm()
	var active := _slot(_pokemon("可撤退战斗宝可梦", 0, 0))
	var bench := _slot(_pokemon("无行动备战宝可梦"))
	gsm.game_state.players[0].active_pokemon = active
	gsm.game_state.players[0].bench = [bench]

	var model: Dictionary = IntentModelScript.build(gsm, 0, null)
	var slots: Dictionary = model.get("slot_intents", {})

	return run_checks([
		assert_eq(str((slots.get("my_active", {}) as Dictionary).get("state", "")), "actionable", "Active Pokemon with legal retreat should be actionable"),
		assert_false(slots.has("my_bench_0"), "Bench Pokemon with no usable Ability should not pulse"),
	])


func test_runtime_overlay_draws_actionable_and_target_paths_without_mutating_rules() -> String:
	var gsm := _gsm()
	var item := _card("可用物品", "Item")
	var energy := _card("基本火能量", "Basic Energy")
	energy.card_data.energy_provides = "R"
	gsm.game_state.players[0].hand = [item, energy]
	gsm.game_state.players[0].active_pokemon = _slot(_pokemon("我方战斗"))
	gsm.game_state.players[0].bench = [_slot(_pokemon("我方备战"))]
	var before: Dictionary = SnapshotScript.capture(gsm.game_state)

	var scene := IntentScene.new()
	scene.size = Vector2(900, 1600)
	scene._gsm = gsm
	var hand := HBoxContainer.new()
	hand.position = Vector2(60, 1400)
	hand.size = Vector2(780, 170)
	scene.add_child(hand)
	scene._hand_container = hand
	var energy_view: BattleCardView = null
	for card: CardInstance in [item, energy]:
		var view := BattleCardView.new()
		view.custom_minimum_size = Vector2(140, 190)
		view.setup_from_instance(card, BattleCardView.MODE_HAND)
		hand.add_child(view)
		if card == energy:
			energy_view = view
	var active_view := BattleCardView.new()
	active_view.position = Vector2(350, 880)
	active_view.size = Vector2(180, 250)
	active_view.setup_from_instance(gsm.game_state.players[0].active_pokemon.get_top_card(), BattleCardView.MODE_SLOT_ACTIVE)
	scene.add_child(active_view)
	var bench_view := BattleCardView.new()
	bench_view.position = Vector2(100, 1080)
	bench_view.size = Vector2(150, 210)
	bench_view.setup_from_instance(gsm.game_state.players[0].bench[0].get_top_card(), BattleCardView.MODE_SLOT_BENCH)
	scene.add_child(bench_view)
	scene._slot_card_views = {"my_active": active_view, "my_bench_0": bench_view}

	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	await tree.process_frame
	var controller: RefCounted = IntentControllerScript.new()
	controller.call("setup", scene)
	controller.call("sync")
	await tree.process_frame
	var idle_visuals: Dictionary = controller.call("visual_snapshot")

	scene._selected_hand_card = energy
	controller.call("sync")
	await tree.process_frame
	var target_visuals: Dictionary = controller.call("visual_snapshot")
	var expected_source_center := (controller.call("_hand_card_rect", energy_view) as Rect2).get_center() if energy_view != null else Vector2(-9999, -9999)
	var actual_source_center: Vector2 = target_visuals.get("source_center", Vector2.ZERO)
	var after: Dictionary = SnapshotScript.capture(gsm.game_state)
	var overlay := scene.get_node_or_null("BattleActionIntentOverlay") as Control
	var result := run_checks([
		assert_true(overlay != null and overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Intent overlay must never steal clicks"),
		assert_eq(int(idle_visuals.get("actionable_count", 0)), 0, "Idle overlay must not proactively glow legal hand cards or field actions"),
		assert_eq(int(target_visuals.get("target_count", 0)), 2, "Selected Energy should draw two owned targets"),
		assert_false(bool(target_visuals.get("source_magnet_visible", true)), "Selected Energy should not receive an extra gray source frame"),
		assert_not_null(energy_view, "Selected Energy should keep its hand-card view"),
		assert_true(actual_source_center.distance_to(expected_source_center) < 0.5, "Guide paths must start from the exact center of the visible Energy card: actual=%s expected=%s" % [actual_source_center, expected_source_center]),
		assert_eq(int(target_visuals.get("target_label_count", -1)), 0, "Energy and Bench target guides must not add Chinese labels over the board"),
		assert_eq(int(target_visuals.get("path_count", 0)), 2, "Every legal target should receive a source-to-target guide path"),
		assert_true(float(target_visuals.get("guide_line_width", 99.0)) <= 2.0, "Target guide paths should stay visually subordinate"),
		assert_eq(int(target_visuals.get("actionable_count", 0)), 0, "Target mode should hide unrelated idle entry hints"),
		assert_eq(after, before, "Building and drawing intents must not mutate GameState"),
	])
	controller.call("clear")
	scene.queue_free()
	await tree.process_frame
	return result


func test_review_mode_clears_intents_without_removing_the_noninteractive_overlay() -> String:
	var gsm := _gsm()
	var energy := _card("基本火能量", "Basic Energy")
	energy.card_data.energy_provides = "R"
	gsm.game_state.players[0].hand = [energy]
	gsm.game_state.players[0].active_pokemon = _slot(_pokemon("我方战斗"))
	var scene := IntentScene.new()
	scene.size = Vector2(1280, 720)
	scene._gsm = gsm
	scene._selected_hand_card = energy
	var hand := HBoxContainer.new()
	scene.add_child(hand)
	scene._hand_container = hand
	var view := BattleCardView.new()
	view.custom_minimum_size = Vector2(120, 168)
	view.setup_from_instance(energy, BattleCardView.MODE_HAND)
	hand.add_child(view)
	var active_view := BattleCardView.new()
	active_view.position = Vector2(540, 260)
	active_view.size = Vector2(170, 235)
	active_view.setup_from_instance(gsm.game_state.players[0].active_pokemon.get_top_card(), BattleCardView.MODE_SLOT_ACTIVE)
	scene.add_child(active_view)
	scene._slot_card_views = {"my_active": active_view}
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	await tree.process_frame
	var controller: RefCounted = IntentControllerScript.new()
	controller.call("setup", scene)
	controller.call("sync")
	var live_visuals: Dictionary = controller.call("visual_snapshot")
	scene.review_mode = true
	controller.call("sync")
	var review_visuals: Dictionary = controller.call("visual_snapshot")
	var overlay := scene.get_node_or_null("BattleActionIntentOverlay") as Control
	var result := run_checks([
		assert_eq(int(live_visuals.get("target_count", 0)), 1, "A selected card should still show its legal target"),
		assert_eq(int(review_visuals.get("target_count", 0)), 0, "Review mode should clear selected-card target guides"),
		assert_true(overlay != null and overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Lifecycle clearing must keep the overlay noninteractive"),
	])
	controller.call("release")
	scene.queue_free()
	await tree.process_frame
	return result


func test_portrait_rejection_toast_is_local_non_modal_and_clears_with_controller() -> String:
	var gsm := _gsm()
	var energy := _card("基本火能量", "Basic Energy")
	energy.card_data.energy_provides = "R"
	gsm.game_state.players[0].hand = [energy]
	gsm.game_state.players[0].active_pokemon = _slot(_pokemon("我方战斗"))
	var scene := IntentScene.new()
	scene.size = Vector2(900, 1600)
	scene._gsm = gsm
	var hand := HBoxContainer.new()
	hand.position = Vector2(50, 1400)
	hand.size = Vector2(800, 180)
	scene.add_child(hand)
	scene._hand_container = hand
	var energy_view := BattleCardView.new()
	energy_view.custom_minimum_size = Vector2(150, 200)
	energy_view.setup_from_instance(energy, BattleCardView.MODE_HAND)
	hand.add_child(energy_view)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	await tree.process_frame
	var controller: RefCounted = IntentControllerScript.new()
	controller.call("setup", scene)
	controller.call("sync")
	controller.call("show_rejection", {
		"title": "现在不能附着",
		"reason": "本回合已经从手牌附着过能量。",
		"card_instance_id": energy.instance_id,
	})
	await tree.process_frame
	var toast := scene.find_child("BattleActionIntentToast", true, false) as Control
	var toast_label := scene.find_child("BattleActionIntentToastLabel", true, false) as Label
	var scene_rect := Rect2(Vector2.ZERO, scene.size)
	var checks: Array[String] = [
		assert_true(toast != null and toast.visible, "Invalid intent should show a local toast"),
		assert_true(toast.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Local reason toast must stay non-modal"),
		assert_true(scene_rect.encloses(toast.get_global_rect()), "Portrait toast must stay inside the screen: scene=%s toast=%s" % [scene_rect, toast.get_global_rect()]),
		assert_gte(toast.size.x, 720.0, "Portrait toast should use most of the phone canvas width"),
		assert_gte(toast_label.get_theme_font_size("font_size") if toast_label != null else 0, 32, "Portrait toast text should remain readable after the phone canvas is scaled to the device"),
		assert_str_contains(toast_label.text if toast_label != null else "", "已经", "Toast should show the concrete rule reason"),
	]
	await tree.create_timer(2.7).timeout
	checks.append(assert_false(toast.visible, "Invalid-card toast should automatically close after the player has had time to read it"))
	controller.call("clear")
	checks.append(assert_false(toast.visible, "Controller clear should hide rejection toast"))
	var result := run_checks(checks)
	scene.queue_free()
	await tree.process_frame
	return result
