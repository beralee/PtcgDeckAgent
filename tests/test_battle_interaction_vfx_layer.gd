class_name TestBattleInteractionVfxLayer
extends TestBase

const CatalogScript := preload("res://scripts/ui/battle/intent/BattleInteractionVfxCatalog.gd")
const OverlayScript := preload("res://scripts/ui/battle/intent/BattleActionIntentOverlay.gd")
const ControllerScript := preload("res://scripts/ui/battle/intent/BattleActionIntentController.gd")
const SnapshotScript := preload("res://scripts/ui/battle/visuals/BattleVisualSnapshot.gd")


class VfxScene extends Control:
	var _gsm: GameStateMachine = null
	var _view_player := 0
	var _selected_hand_card: CardInstance = null
	var _pending_choice := ""
	var _draw_reveal_active := false
	var _ai_llm_waiting := false
	var _hand_container: HBoxContainer = null
	var _slot_card_views: Dictionary = {}
	var _stadium_card_view: BattleCardView = null

	func _can_accept_live_action() -> bool:
		return true

	func _is_field_interaction_active() -> bool:
		return false

	func _is_review_mode() -> bool:
		return false

	func _is_ai_action_pause_active() -> bool:
		return false


func _card(name: String, card_type: String, owner: int = 0) -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.card_type = card_type
	return CardInstance.create(data, owner)


func _pokemon(name: String, energy_type: String = "C", owner: int = 0) -> CardInstance:
	var card := _card(name, "Pokemon", owner)
	card.card_data.stage = "Basic"
	card.card_data.hp = 100
	card.card_data.energy_type = energy_type
	return card


func _slot(card: CardInstance, damage: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(card)
	slot.damage_counters = damage
	slot.turn_played = 1
	return slot


func _gsm() -> GameStateMachine:
	var gsm := GameStateMachine.new()
	var state := GameState.new()
	state.turn_number = 3
	state.current_player_index = 0
	state.first_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	gsm.game_state = state
	return gsm


func test_catalog_covers_every_promised_procedural_interaction_effect() -> String:
	var expected := [
		"legal_target_glow",
		"attribute_action_glow",
		"flow_path",
		"multi_target_fanout",
		"success_converge",
		"invalid_recoil",
		"touch_ripple",
		"energy_orbit",
		"tool_lock",
		"retreat_swap",
		"ability_ripple",
		"attack_ready",
		"phase_sweep",
		"low_hp_pulse",
		"combo_cadence",
	]
	var missing: Array[String] = []
	for effect_id: String in expected:
		if not CatalogScript.has_effect(effect_id):
			missing.append(effect_id)
	return run_checks([
		assert_eq(missing, [], "Every documented interaction VFX must have a registered procedural profile"),
		assert_false(CatalogScript.has_effect("source_magnet"), "Removed gray source frame must not remain registered"),
		assert_false(CatalogScript.has_effect("evolution_ladder"), "Removed purple evolution ladder must not remain registered"),
	])


func test_overlay_exposes_subtle_flow_fanout_and_low_hp_visuals_without_gray_source_frame() -> String:
	var overlay := OverlayScript.new()
	overlay.size = Vector2(1200, 800)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(overlay)
	await tree.process_frame
	overlay.call("set_visuals", [
		{
			"rect": Rect2(450, 220, 170, 235),
			"label": "招式 / 撤退",
			"attribute_color": Color(1.0, 0.38, 0.18),
			"action_kinds": ["attack", "retreat"],
		},
	], Rect2(90, 590, 130, 180), [
		{"rect": Rect2(380, 220, 150, 210), "label": "可选择", "index": 0},
		{"rect": Rect2(670, 220, 150, 210), "label": "可选择", "index": 1},
	], {"intent_kind": "energy", "attribute_color": Color(1.0, 0.35, 0.12)})
	overlay.call("set_low_hp_hazards", [{"rect": Rect2(450, 220, 170, 235), "ratio": 0.2}])
	var snapshot: Dictionary = overlay.call("visual_snapshot")
	var result := run_checks([
		assert_eq(overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE, "VFX overlay must never capture pointer input"),
		assert_false(bool(snapshot.get("source_magnet_visible", true)), "Selected source should not receive an extra gray frame"),
		assert_eq(int(snapshot.get("flow_path_count", 0)), 2, "Every legal target should receive a flowing path"),
		assert_eq(int(snapshot.get("target_label_count", -1)), 0, "Target guidance should not print 可选择 over Pokemon"),
		assert_true(float(snapshot.get("guide_line_width", 99.0)) <= 2.0, "Flowing target paths should use a restrained line width"),
		assert_eq(int(snapshot.get("fanout_count", 0)), 2, "Multi-target guides should expose staggered fanout branches"),
		assert_gte(int(snapshot.get("flow_particle_count", 0)), 4, "Guide paths should carry procedural moving particles"),
		assert_eq(int(snapshot.get("attribute_glow_count", 0)), 1, "Actionable Pokemon should keep its attribute-tinted glow"),
		assert_eq(int(snapshot.get("attack_ready_count", 0)), 1, "Attack-ready Pokemon should expose a restrained charge cue"),
		assert_eq(int(snapshot.get("low_hp_count", 0)), 1, "Low-HP Pokemon should receive a localized danger pulse"),
	])
	overlay.queue_free()
	await tree.process_frame
	return result


func test_evolution_targeting_removes_source_frame_and_target_copy() -> String:
	var overlay := OverlayScript.new()
	overlay.size = Vector2(1200, 800)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(overlay)
	await tree.process_frame
	overlay.call("set_visuals", [], Rect2(90, 590, 130, 180), [
		{"rect": Rect2(450, 220, 170, 235), "label": "", "index": 0},
	], {"intent_kind": "evolution", "attribute_color": Color(0.66, 0.38, 1.0)})
	var snapshot: Dictionary = overlay.call("visual_snapshot")
	var result := run_checks([
		assert_false(bool(snapshot.get("source_magnet_visible", true)), "Selected evolution Pokemon should not receive an attribute-colored source frame"),
		assert_eq(int(snapshot.get("target_label_count", -1)), 0, "Evolution targets should not display 可选择 copy"),
		assert_eq(int(snapshot.get("flow_path_count", 0)), 1, "Removing source decoration must keep the evolution target path"),
	])
	overlay.queue_free()
	await tree.process_frame
	return result


func test_all_transient_vfx_are_nonblocking_bounded_and_expire() -> String:
	var overlay := OverlayScript.new()
	overlay.size = Vector2(900, 1600)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(overlay)
	await tree.process_frame
	var event_kinds := [
		"success_converge",
		"invalid_recoil",
		"touch_ripple",
		"energy_orbit",
		"tool_lock",
		"retreat_swap",
		"ability_ripple",
		"phase_sweep",
		"combo_cadence",
	]
	for event_kind: String in event_kinds:
		overlay.call("play_event", event_kind, {
			"from_rect": Rect2(90, 1320, 140, 200),
			"to_rect": Rect2(340, 720, 190, 270),
			"point": Vector2(440, 780),
			"level": 3,
		})
	await tree.process_frame
	var live: Dictionary = overlay.call("visual_snapshot")
	for event_variant: Variant in overlay.get("_events"):
		if event_variant is Dictionary:
			(event_variant as Dictionary)["age"] = float((event_variant as Dictionary).get("duration", 0.5)) + 0.1
	overlay.call("_process", 0.0)
	var expired: Dictionary = overlay.call("visual_snapshot")
	var result := run_checks([
		assert_eq((live.get("event_kinds", []) as Array).size(), event_kinds.size(), "Every transient effect should be accepted by the shared renderer"),
		assert_eq(overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE, "Transient effects must remain input-transparent"),
		assert_eq(int(expired.get("active_event_count", -1)), 0, "Transient VFX should self-clean after their bounded duration"),
	])
	overlay.queue_free()
	await tree.process_frame
	return result


func test_controller_converts_transformed_card_rect_into_overlay_coordinates() -> String:
	var scene := VfxScene.new()
	scene.size = Vector2(1000, 700)
	scene.position = Vector2(130, 75)
	scene.rotation = 0.11
	scene.scale = Vector2(1.25, 0.82)
	var transformed_parent := Control.new()
	transformed_parent.position = Vector2(85, 120)
	transformed_parent.rotation = -0.17
	transformed_parent.scale = Vector2(0.88, 1.16)
	scene.add_child(transformed_parent)
	var card_control := Control.new()
	card_control.position = Vector2(210, 145)
	card_control.size = Vector2(138, 194)
	transformed_parent.add_child(card_control)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	await tree.process_frame
	var controller: RefCounted = ControllerScript.new()
	controller.call("setup", scene)
	var overlay := scene.get_node_or_null("BattleActionIntentOverlay") as Control
	var actual: Rect2 = controller.call("_control_rect", card_control)
	var expected := _rect_in_overlay_space(overlay, card_control)
	var actual_screen_center := overlay.get_screen_transform() * actual.get_center()
	var card_screen_center := card_control.get_screen_transform() * (card_control.size * 0.5)
	var result := run_checks([
		assert_true(actual.position.distance_to(expected.position) < 0.5, "Guide source must start at the transformed hand card, not below the hand area: actual=%s expected=%s" % [actual, expected]),
		assert_true(actual.size.distance_to(expected.size) < 0.5, "Guide source rect must preserve the transformed card bounds: actual=%s expected=%s" % [actual, expected]),
		assert_true(actual_screen_center.distance_to(card_screen_center) < 0.5, "Guide source center must match the card's final screen center: guide=%s card=%s" % [actual_screen_center, card_screen_center]),
	])
	controller.call("release")
	scene.queue_free()
	await tree.process_frame
	return result


func test_selected_hand_guide_starts_at_visible_card_center_not_internal_content_height() -> String:
	var gsm := _gsm()
	var energy := _card("Basic Grass Energy", "Basic Energy")
	energy.card_data.energy_provides = "G"
	gsm.game_state.players[0].hand = [energy]
	gsm.game_state.players[0].active_pokemon = _slot(_pokemon("Active Pokemon", "G"))
	var scene := VfxScene.new()
	scene.size = Vector2(800, 520)
	scene._gsm = gsm
	scene._selected_hand_card = energy
	var hand := HBoxContainer.new()
	hand.position = Vector2(210, 360)
	hand.size = Vector2(380, 145)
	scene.add_child(hand)
	scene._hand_container = hand
	var hand_view := BattleCardView.new()
	hand_view.custom_minimum_size = Vector2(95, 133)
	hand_view.setup_from_instance(energy, BattleCardView.MODE_HAND)
	hand_view.set_info("Basic Grass Energy", "Basic Energy")
	hand.add_child(hand_view)
	var active_view := BattleCardView.new()
	active_view.position = Vector2(315, 110)
	active_view.size = Vector2(130, 182)
	active_view.setup_from_instance(gsm.game_state.players[0].active_pokemon.get_top_card(), BattleCardView.MODE_SLOT_ACTIVE)
	scene.add_child(active_view)
	scene._slot_card_views = {"my_active": active_view}
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	await tree.process_frame
	await tree.process_frame
	var controller: RefCounted = ControllerScript.new()
	controller.call("setup", scene)
	controller.call("sync")
	var snapshot: Dictionary = controller.call("visual_snapshot")
	var overlay := scene.get_node_or_null("BattleActionIntentOverlay") as Control
	var root_rect: Rect2 = controller.call("_control_rect", hand_view)
	var visual := hand_view.get_visual_card_control()
	var visual_rect: Rect2 = controller.call("_control_rect", visual)
	var source_center: Vector2 = snapshot.get("source_center", Vector2.ZERO)
	var intended_screen_center := hand_view.get_screen_transform() * (hand_view.custom_minimum_size * 0.5)
	var intended_center := overlay.get_screen_transform().affine_inverse() * intended_screen_center
	var result := assert_true(
		source_center.distance_to(intended_center) < 0.5,
		"Selected-hand guide must start at the intended visible card center: source=%s intended=%s root=%s internal=%s root_size=%s min_size=%s internal_size=%s" % [source_center, intended_center, root_rect.get_center(), visual_rect.get_center(), hand_view.size, hand_view.custom_minimum_size, visual.size]
	)
	controller.call("release")
	scene.queue_free()
	await tree.process_frame
	return result


func test_controller_hides_proactive_hand_and_field_feedback_but_keeps_low_hp_without_mutating_rules() -> String:
	var gsm := _gsm()
	var energy := _card("基本雷能量", "Basic Energy")
	energy.card_data.energy_provides = "L"
	var active_card := _pokemon("雷属性战斗宝可梦", "L")
	active_card.card_data.attacks = [{"name": "电击", "cost": "", "damage": "20"}]
	gsm.game_state.players[0].hand = [energy]
	gsm.game_state.players[0].active_pokemon = _slot(active_card, 80)
	gsm.game_state.players[0].bench = [_slot(_pokemon("备战宝可梦"))]
	gsm.game_state.players[1].active_pokemon = _slot(_pokemon("对方宝可梦", "C", 1))
	var before := SnapshotScript.capture(gsm.game_state)
	var scene := VfxScene.new()
	scene.size = Vector2(1200, 800)
	scene._gsm = gsm
	var hand := HBoxContainer.new()
	hand.position = Vector2(80, 590)
	scene.add_child(hand)
	scene._hand_container = hand
	var energy_view := BattleCardView.new()
	energy_view.custom_minimum_size = Vector2(120, 170)
	energy_view.setup_from_instance(energy, BattleCardView.MODE_HAND)
	hand.add_child(energy_view)
	var active_view := BattleCardView.new()
	active_view.position = Vector2(490, 260)
	active_view.size = Vector2(170, 235)
	active_view.setup_from_instance(active_card, BattleCardView.MODE_SLOT_ACTIVE)
	scene.add_child(active_view)
	var bench_view := BattleCardView.new()
	bench_view.position = Vector2(250, 300)
	bench_view.size = Vector2(140, 195)
	bench_view.setup_from_instance(gsm.game_state.players[0].bench[0].get_top_card(), BattleCardView.MODE_SLOT_BENCH)
	scene.add_child(bench_view)
	scene._slot_card_views = {"my_active": active_view, "my_bench_0": bench_view}
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	await tree.process_frame
	var controller: RefCounted = ControllerScript.new()
	controller.call("setup", scene)
	controller.call("sync")
	var visuals: Dictionary = controller.call("visual_snapshot")
	var after := SnapshotScript.capture(gsm.game_state)
	var result := run_checks([
		assert_eq(int(visuals.get("actionable_count", 0)), 0, "Controller must not proactively glow usable hand cards or Pokemon"),
		assert_eq(int(visuals.get("attribute_glow_count", 0)), 0, "Controller must not tint actionable Pokemon while idle"),
		assert_eq(int(visuals.get("attack_ready_count", 0)), 0, "Controller must not advertise attacks, Abilities, or retreat while idle"),
		assert_eq(int(visuals.get("low_hp_count", 0)), 1, "Controller should derive low HP from the live slot"),
		assert_eq(str(visuals.get("low_hp_outline_mode", "")), "card_perimeter", "Low-HP warning should surround the card perimeter"),
		assert_eq(after, before, "VFX derivation must not mutate game rules state"),
	])
	controller.call("release")
	scene.queue_free()
	await tree.process_frame
	return result


func test_controller_maps_gameplay_successes_rejections_press_phase_and_swap_to_vfx() -> String:
	var gsm := _gsm()
	var energy := _card("基本火能量", "Basic Energy")
	energy.card_data.energy_provides = "R"
	gsm.game_state.players[0].hand = [energy]
	gsm.game_state.players[0].active_pokemon = _slot(_pokemon("战斗宝可梦", "R"))
	var scene := VfxScene.new()
	scene.size = Vector2(1000, 1200)
	scene._gsm = gsm
	var hand := HBoxContainer.new()
	hand.position = Vector2(60, 980)
	scene.add_child(hand)
	scene._hand_container = hand
	var hand_view := BattleCardView.new()
	hand_view.custom_minimum_size = Vector2(130, 185)
	hand_view.setup_from_instance(energy, BattleCardView.MODE_HAND)
	hand.add_child(hand_view)
	var active_view := BattleCardView.new()
	active_view.position = Vector2(410, 510)
	active_view.size = Vector2(180, 250)
	active_view.setup_from_instance(gsm.game_state.players[0].active_pokemon.get_top_card(), BattleCardView.MODE_SLOT_ACTIVE)
	scene.add_child(active_view)
	scene._slot_card_views = {"my_active": active_view}
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	await tree.process_frame
	var controller: RefCounted = ControllerScript.new()
	controller.call("setup", scene)
	controller.call("sync")
	controller.call("play_success", "energy", {"source_card_instance_id": energy.instance_id, "target_slot_id": "my_active"})
	controller.call("play_success", "evolution", {"target_slot_id": "my_active"})
	controller.call("play_success", "tool", {"target_slot_id": "my_active"})
	controller.call("play_success", "ability", {"target_slot_id": "my_active"})
	controller.call("play_press", {"anchor_key": "my_active"})
	controller.call("play_phase_sweep")
	controller.call("play_field_movement", {"moves": [{"from_slot_id": "my_active", "to_slot_id": "my_bench_0"}]})
	controller.call("show_rejection", {"anchor_key": "my_active", "reason": "当前目标不合法"})
	var visuals: Dictionary = controller.call("visual_snapshot")
	var kinds: Array = visuals.get("event_kinds", [])
	var result := run_checks([
		assert_true(kinds.has("energy_orbit"), "Energy success should play its orbit/attach confirmation"),
		assert_false(kinds.has("evolution_ladder"), "Evolution success must not leave purple horizontal ladder lines"),
		assert_true(kinds.has("tool_lock"), "Tool success should play the lock ring"),
		assert_true(kinds.has("ability_ripple"), "Ability success should play the ability ripple"),
		assert_true(kinds.has("touch_ripple"), "Accepted press should play localized touch feedback"),
		assert_true(kinds.has("phase_sweep"), "MAIN phase entry should play a field sweep"),
		assert_true(kinds.has("retreat_swap"), "Detected active/Bench movement should play two-way swap trajectories"),
		assert_true(kinds.has("invalid_recoil"), "Rejected action should play local recoil feedback"),
		assert_true(kinds.has("combo_cadence"), "Successful actions should feed bounded cadence feedback"),
	])
	controller.call("release")
	scene.queue_free()
	await tree.process_frame
	return result


func _rect_in_overlay_space(overlay: Control, control: Control) -> Rect2:
	var relative := overlay.get_screen_transform().affine_inverse() * control.get_screen_transform()
	var corners := [
		relative * Vector2.ZERO,
		relative * Vector2(control.size.x, 0),
		relative * control.size,
		relative * Vector2(0, control.size.y),
	]
	var min_point: Vector2 = corners[0]
	var max_point: Vector2 = corners[0]
	for point: Vector2 in corners:
		min_point = min_point.min(point)
		max_point = max_point.max(point)
	return Rect2(min_point, max_point - min_point)


func test_controller_emits_phase_sweep_only_when_entering_a_live_main_phase() -> String:
	var gsm := _gsm()
	gsm.game_state.phase = GameState.GamePhase.SETUP
	var scene := VfxScene.new()
	scene.size = Vector2(1000, 700)
	scene._gsm = gsm
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(scene)
	await tree.process_frame
	var controller: RefCounted = ControllerScript.new()
	controller.call("setup", scene)
	controller.call("sync")
	var setup_visuals: Dictionary = controller.call("visual_snapshot")
	gsm.game_state.phase = GameState.GamePhase.MAIN
	controller.call("sync")
	var main_visuals: Dictionary = controller.call("visual_snapshot")
	var result := run_checks([
		assert_false((setup_visuals.get("event_kinds", []) as Array).has("phase_sweep"), "Setup should not show a MAIN-phase sweep"),
		assert_true((main_visuals.get("event_kinds", []) as Array).has("phase_sweep"), "Transition into MAIN should show exactly the nonblocking sweep cue"),
	])
	controller.call("release")
	scene.queue_free()
	await tree.process_frame
	return result
