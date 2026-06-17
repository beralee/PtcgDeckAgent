class_name TestBattleReadyVfx
extends TestBase


const BattleSceneScript = preload("res://scenes/battle/BattleScene.gd")
const BattleCardViewScript = preload("res://scenes/battle/BattleCardView.gd")
const BattleReadyVfxControllerScript = preload("res://scripts/ui/battle/BattleReadyVfxController.gd")
const BattleReadyVfxRegistryScript = preload("res://scripts/ui/battle/BattleReadyVfxRegistry.gd")
const BattleReadyVfxEvaluatorScript = preload("res://scripts/ui/battle/BattleReadyVfxEvaluator.gd")
const EffectElectricGeneratorScript = preload("res://scripts/effects/trainer_effects/EffectElectricGenerator.gd")

const TANDEM_UNIT_USED_KEY := "ability_search_pokemon_to_bench_used"
const TANDEM_UNIT_SUMMONED_KEY := "ability_search_pokemon_to_bench_summoned"


func _make_pokemon_card(
	name: String,
	set_code: String,
	card_index: String,
	energy_type: String = "G",
	stage: String = "Basic",
	hp: int = 70,
	mechanic: String = "",
	attacks: Array = [],
	name_en: String = ""
) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name_en
	card.card_type = "Pokemon"
	card.stage = stage
	card.hp = hp
	card.mechanic = mechanic
	card.energy_type = energy_type
	card.set_code = set_code
	card.card_index = card_index
	card.attacks.clear()
	for attack_variant: Variant in attacks:
		if attack_variant is Dictionary:
			card.attacks.append((attack_variant as Dictionary).duplicate(true))
	return card


func _make_energy_card(name: String = "Water Energy", energy_type: String = "W") -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = "Basic Energy"
	card.energy_type = energy_type
	card.energy_provides = energy_type
	card.set_code = "ENERGY"
	card.card_index = energy_type
	return card


func _make_trainer_card(name: String, trainer_type: String = "Item", set_code: String = "TEST", card_index: String = "T001", effect_id: String = "") -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = trainer_type
	card.set_code = set_code
	card.card_index = card_index
	card.effect_id = effect_id
	return card


func _attack(cost: String, damage: String = "0", name: String = "Ready Attack") -> Dictionary:
	return {
		"name": name,
		"text": "",
		"cost": cost,
		"damage": damage,
		"is_vstar_power": false,
	}


func _make_slot(card: CardData, owner: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	var instance := CardInstance.create(card, owner)
	instance.face_up = true
	slot.pokemon_stack.append(instance)
	return slot


func _attach_energy(slot: PokemonSlot, owner: int, energy_type: String, count: int) -> void:
	for _i: int in count:
		slot.attached_energy.append(CardInstance.create(_make_energy_card("%s Energy" % energy_type, energy_type), owner))


func _add_energy_to_zone(zone: Array, owner: int, energy_type: String, count: int) -> void:
	for _i: int in count:
		zone.append(CardInstance.create(_make_energy_card("%s Energy" % energy_type, energy_type), owner))


func _add_special_energy_to_zone(zone: Array, owner: int, energy_type: String, count: int) -> void:
	for _i: int in count:
		var card := _make_energy_card("Special %s Energy" % energy_type, energy_type)
		card.card_type = "Special Energy"
		zone.append(CardInstance.create(card, owner))


func _add_card_to_zone(zone: Array, card: CardData, owner: int) -> void:
	zone.append(CardInstance.create(card, owner))


func _mark_tandem_unit_used(slot: PokemonSlot, turn_number: int) -> void:
	var source := slot.get_top_card()
	slot.effects.append({
		"type": TANDEM_UNIT_USED_KEY,
		"turn": turn_number,
		"source_instance_id": int(source.instance_id) if source != null else -1,
	})


func _append_tandem_summoned_bench(player: PlayerState, source_slot: PokemonSlot, slot: PokemonSlot, turn_number: int) -> void:
	var source := source_slot.get_top_card() if source_slot != null else null
	slot.turn_played = turn_number
	slot.effects.append({
		"type": TANDEM_UNIT_SUMMONED_KEY,
		"turn": turn_number,
		"source_instance_id": int(source.instance_id) if source != null else -1,
	})
	player.bench.append(slot)


func _make_state(current_player: int = 0, turn_number: int = 1, phase: int = GameState.GamePhase.MAIN) -> GameState:
	var gs := GameState.new()
	gs.current_player_index = current_player
	gs.first_player_index = 0
	gs.turn_number = turn_number
	gs.phase = phase
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gs.players.append(player)
	return gs


func _has_rule(triggers: Array, rule_id: String) -> bool:
	for trigger_variant: Variant in triggers:
		if trigger_variant is Dictionary and str((trigger_variant as Dictionary).get("rule_id", "")) == rule_id:
			return true
	return false


func _first_rule(triggers: Array, rule_id: String) -> Dictionary:
	for trigger_variant: Variant in triggers:
		if trigger_variant is Dictionary:
			var trigger: Dictionary = trigger_variant
			if str(trigger.get("rule_id", "")) == rule_id:
				return trigger
	return {}


func _read_text_file(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _make_scene_stub_with_state(gs: GameState) -> Control:
	var battle_scene = BattleSceneScript.new()
	var main_area := Control.new()
	main_area.name = "MainArea"
	main_area.position = Vector2(0, 0)
	main_area.size = Vector2(1280, 720)
	battle_scene.add_child(main_area)

	var center_field := Control.new()
	center_field.name = "CenterField"
	center_field.position = Vector2(80, 20)
	center_field.size = Vector2(1120, 640)
	main_area.add_child(center_field)

	var my_active := BattleCardViewScript.new()
	my_active.custom_minimum_size = Vector2(130, 182)
	my_active.size = my_active.custom_minimum_size
	my_active.position = Vector2(520, 430)
	center_field.add_child(my_active)

	var opp_active := BattleCardViewScript.new()
	opp_active.custom_minimum_size = Vector2(130, 182)
	opp_active.size = opp_active.custom_minimum_size
	opp_active.position = Vector2(520, 80)
	center_field.add_child(opp_active)

	var gsm := GameStateMachine.new()
	gsm.game_state = gs
	battle_scene.set("_gsm", gsm)
	battle_scene.set("_view_player", 0)
	battle_scene.set("_my_active", my_active)
	battle_scene.set("_opp_active", opp_active)
	battle_scene.set("_slot_card_views", {})
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
	battle_scene.set("_hand_container", HBoxContainer.new())
	return battle_scene


func test_ready_vfx_registry_registers_budew_asset() -> String:
	var registry: RefCounted = BattleReadyVfxRegistryScript.new()
	var profile: RefCounted = registry.call("get_profile", "budew_opening_item_lock_ready")
	var asset_specs: Dictionary = profile.get("asset_specs") if profile != null else {}
	var burst: Dictionary = asset_specs.get("burst", {})
	var image := Image.load_from_file(ProjectSettings.globalize_path(str(burst.get("path", ""))))

	return run_checks([
		assert_not_null(profile, "Budew ready profile should be registered"),
		assert_eq(str(profile.get("profile_id")), "ready_budew_item_lock", "Budew ready profile id should be stable"),
		assert_eq(str(burst.get("path", "")), "res://assets/textures/vfx/ready_budew_item_lock/sheet-transparent.png", "Budew ready profile should point to the generated sheet"),
		assert_eq(int(burst.get("frames", 0)), 6, "Budew ready sheet should have 6 frames"),
		assert_eq(int(burst.get("rows", 0)), 2, "Budew ready sheet should have 2 rows"),
		assert_eq(int(burst.get("cols", 0)), 3, "Budew ready sheet should have 3 columns"),
		assert_eq(profile.get("effect_size"), Vector2(440.0, 440.0), "Budew ready animation should render at double the original size"),
		assert_eq(int(round(float(profile.get("duration")) * 1000.0)), 1014, "Budew ready animation should last 30 percent longer than the original 0.78s"),
		assert_not_null(image, "Generated Budew ready sheet should load as an Image"),
		assert_eq(image.get_size(), Vector2i(768, 512), "Generated Budew ready sheet should be a 2x3 256px grid"),
	])


func test_ready_vfx_registry_registers_charizard_body_asset() -> String:
	var registry: RefCounted = BattleReadyVfxRegistryScript.new()
	var profile: RefCounted = registry.call("get_profile", "charizard_infernal_reign_ready")
	var asset_specs: Dictionary = profile.get("asset_specs") if profile != null else {}
	var burst: Dictionary = asset_specs.get("burst", {})
	var image := Image.load_from_file(ProjectSettings.globalize_path(str(burst.get("path", ""))))
	var runtime_texture: Texture2D = load(str(burst.get("path", ""))) as Texture2D
	var opaque_pixels := 0
	var blue_wing_pixels := 0
	if image != null:
		for y: int in image.get_height():
			for x: int in image.get_width():
				var pixel := image.get_pixel(x, y)
				if pixel.a <= 0.1:
					continue
				opaque_pixels += 1
				if pixel.b > 0.22 and pixel.b > pixel.r * 0.55 and pixel.g > 0.08 and pixel.r < 0.6:
					blue_wing_pixels += 1

	return run_checks([
		assert_not_null(profile, "Charizard ready profile should be registered"),
		assert_eq(str(profile.get("profile_id")), "ready_charizard_infernal_reign", "Charizard ready profile id should be stable"),
		assert_eq(str(burst.get("path", "")), "res://assets/textures/vfx/ready_charizard_infernal_reign/sheet-transparent.png", "Charizard ready profile should point to the body-first generated sheet"),
		assert_eq(int(burst.get("frames", 0)), 6, "Charizard ready sheet should have 6 frames"),
		assert_eq(int(burst.get("rows", 0)), 2, "Charizard ready sheet should have 2 rows"),
		assert_eq(int(burst.get("cols", 0)), 3, "Charizard ready sheet should have 3 columns"),
		assert_gte(float(profile.get("duration")), 1.55, "Charizard body-first ready animation should linger instead of flashing past"),
		assert_eq(profile.get("effect_size"), Vector2(520.0, 520.0), "Charizard ready animation should render larger without adding a new asset"),
		assert_gte(float(profile.get("hold_ratio")), 0.18, "Charizard ready animation should include a visible power hold"),
		assert_gte(float(profile.get("portrait_effect_width_ratio")), 0.85, "Charizard ready animation should scale up in portrait mode"),
		assert_gte(float(profile.get("portrait_duration")), 1.65, "Charizard portrait ready animation should stay readable"),
		assert_not_null(image, "Generated Charizard ready sheet should load as an Image"),
		assert_eq(image.get_size() if image != null else Vector2i.ZERO, Vector2i(768, 512), "Generated Charizard ready sheet should be a 2x3 256px grid"),
		assert_not_null(runtime_texture, "Generated Charizard ready sheet should load through Godot's runtime resource importer"),
		assert_eq(Vector2i(runtime_texture.get_width(), runtime_texture.get_height()) if runtime_texture != null else Vector2i.ZERO, Vector2i(768, 512), "Runtime Charizard ready texture should use the generated body-first sheet dimensions"),
		assert_gte(opaque_pixels, 60000, "Charizard ready sheet should contain a full-body creature, not a tiny icon"),
		assert_gte(blue_wing_pixels, 5000, "Charizard ready sheet should contain blue wing/body pixels so pure fire-emblem sheets cannot pass"),
	])


func test_ready_vfx_registry_registers_gardevoir_psychic_embrace_asset() -> String:
	var registry: RefCounted = BattleReadyVfxRegistryScript.new()
	var profile: RefCounted = registry.call("get_profile", "gardevoir_psychic_embrace_ready")
	var asset_specs: Dictionary = profile.get("asset_specs") if profile != null else {}
	var burst: Dictionary = asset_specs.get("burst", {})
	var image := Image.load_from_file(ProjectSettings.globalize_path(str(burst.get("path", ""))))
	var runtime_texture: Texture2D = load(str(burst.get("path", ""))) as Texture2D

	return run_checks([
		assert_not_null(profile, "Gardevoir ready profile should be registered"),
		assert_eq(str(profile.get("profile_id")) if profile != null else "", "ready_gardevoir_psychic_embrace", "Gardevoir ready profile id should be stable"),
		assert_eq(str(burst.get("path", "")), "res://assets/textures/vfx/ready_gardevoir_psychic_embrace/sheet-transparent.png", "Gardevoir ready profile should point to the generated sheet"),
		assert_eq(int(burst.get("frames", 0)), 6, "Gardevoir ready sheet should have 6 frames"),
		assert_eq(int(burst.get("rows", 0)), 2, "Gardevoir ready sheet should have 2 rows"),
		assert_eq(int(burst.get("cols", 0)), 3, "Gardevoir ready sheet should have 3 columns"),
		assert_eq(profile.get("effect_size") if profile != null else Vector2.ZERO, Vector2(520.0, 520.0), "Gardevoir ready animation should use the cinematic board size"),
		assert_gte(float(profile.get("hold_ratio")) if profile != null else 0.0, 0.24, "Gardevoir ready animation should hold the Psychic Embrace peak"),
		assert_not_null(image, "Generated Gardevoir ready sheet should load as an Image"),
		assert_eq(image.get_size() if image != null else Vector2i.ZERO, Vector2i(768, 512), "Generated Gardevoir ready sheet should be a 2x3 256px grid"),
		assert_not_null(runtime_texture, "Generated Gardevoir ready sheet should load through Godot's runtime resource importer"),
		assert_eq(Vector2i(runtime_texture.get_width(), runtime_texture.get_height()) if runtime_texture != null else Vector2i.ZERO, Vector2i(768, 512), "Runtime Gardevoir ready texture should use the generated body-first sheet dimensions"),
	])


func test_charizard_ready_vfx_portrait_sequence_uses_cinematic_metrics() -> String:
	var controller: RefCounted = BattleReadyVfxControllerScript.new()
	var registry: RefCounted = BattleReadyVfxRegistryScript.new()
	var profile: RefCounted = registry.call("get_profile", "charizard_infernal_reign_ready")
	var gs := _make_state(0, 4, GameState.GamePhase.MAIN)
	var battle_scene := _make_scene_stub_with_state(gs)
	battle_scene.size = Vector2(900.0, 1600.0)
	var overlay: Control = controller.call("ensure_overlay", battle_scene) as Control
	overlay.size = Vector2(900.0, 1600.0)
	var trigger := {
		"rule_id": "charizard_infernal_reign_ready",
		"player_index": 0,
		"slot_kind": "active",
		"slot_index": 0,
		"ready_key": "test-charizard-portrait",
	}

	controller.call("_play_sequence", battle_scene, overlay, profile, Vector2(450.0, 800.0), trigger)

	var sequence: Control = overlay.get_child(0) as Control if overlay.get_child_count() > 0 else null
	var burst: TextureRect = sequence.get_node_or_null("ReadyVfxBurst") as TextureRect if sequence != null else null
	var result := run_checks([
		assert_not_null(sequence, "Charizard portrait ready sequence should be created"),
		assert_not_null(burst, "Charizard portrait ready sequence should create a burst node"),
		assert_eq(Vector2i(roundi(burst.size.x), roundi(burst.size.y)) if burst != null else Vector2i.ZERO, Vector2i(810, 810), "Charizard portrait ready VFX should fill 90 percent of a 900px-wide portrait viewport"),
		assert_eq(int(round(float(sequence.get_meta("ready_vfx_duration", 0.0)) * 1000.0)) if sequence != null else 0, 1720, "Charizard portrait ready VFX should use the slower cinematic duration"),
		assert_eq(float(sequence.get_meta("ready_vfx_hold_ratio", 0.0)) if sequence != null else 0.0, 0.24, "Charizard portrait ready VFX should hold at peak power"),
		assert_true(bool(sequence.get_meta("ready_vfx_portrait", false)) if sequence != null else false, "Charizard portrait ready VFX should record portrait layout metrics"),
		assert_eq(burst.mouse_filter if burst != null else Control.MOUSE_FILTER_STOP, Control.MOUSE_FILTER_IGNORE, "Charizard ready VFX must not block board input"),
	])
	battle_scene.free()
	return result


func test_ready_vfx_registry_registers_all_priority_profiles() -> String:
	var registry: RefCounted = BattleReadyVfxRegistryScript.new()
	var expected_rules := [
		"budew_opening_item_lock_ready",
		"dragapult_phantom_dive_ready",
		"lugia_double_archeops_ready",
		"iron_hands_amp_ready",
		"terapagos_cavern_board_ready",
		"palkia_vstar_acceleration_ready",
		"gholdengo_big_swing_ready",
		"charizard_infernal_reign_ready",
		"miraidon_generator_line_ready",
		"regigigas_ancient_wisdom_ready",
		"radiant_greninja_concealed_cards_ready",
		"ceruledge_discard_energy_ready",
		"roaring_moon_frenzied_ready",
		"gardevoir_psychic_embrace_ready",
		"archaludon_metal_bridge_ready",
	]
	var checks: Array[String] = [
		assert_eq((registry.call("list_rule_ids") as Array).size(), expected_rules.size(), "Registry should expose one profile for each designed ready scene"),
	]
	for rule_id: String in expected_rules:
		var profile: RefCounted = registry.call("get_profile", rule_id)
		var asset_specs: Dictionary = profile.get("asset_specs") if profile != null else {}
		var burst: Dictionary = asset_specs.get("burst", {})
		var image := Image.load_from_file(ProjectSettings.globalize_path(str(burst.get("path", ""))))
		checks.append(assert_not_null(profile, "Ready profile should exist for %s" % rule_id))
		checks.append(assert_true((str(profile.get("profile_id")) if profile != null else "") != "", "Ready profile id should be stable for %s" % rule_id))
		checks.append(assert_true(str(burst.get("path", "")).begins_with("res://assets/textures/vfx/"), "Ready profile should use a bundled VFX asset for %s" % rule_id))
		checks.append(assert_not_null(image, "Ready burst image should load for %s" % rule_id))
		checks.append(assert_gte(float(profile.get("duration")) if profile != null else 0.0, 0.6, "Ready profile duration should be visible for %s" % rule_id))
	return run_checks(checks)


func test_non_budew_ready_profiles_use_body_first_cinematic_sheets() -> String:
	var registry: RefCounted = BattleReadyVfxRegistryScript.new()
	var checks: Array[String] = []
	for rule_id_variant: Variant in registry.call("list_rule_ids"):
		var rule_id := str(rule_id_variant)
		var profile: RefCounted = registry.call("get_profile", rule_id)
		var profile_id := str(profile.get("profile_id")) if profile != null else ""
		if profile_id == "ready_budew_item_lock":
			continue
		var asset_specs: Dictionary = profile.get("asset_specs") if profile != null else {}
		var burst: Dictionary = asset_specs.get("burst", {})
		var expected_path := "res://assets/textures/vfx/%s/sheet-transparent.png" % profile_id
		var image := Image.load_from_file(ProjectSettings.globalize_path(expected_path))
		var prompt_path := ProjectSettings.globalize_path("res://assets/textures/vfx/%s/prompt-used.txt" % profile_id)
		var prompt_text := _read_text_file(prompt_path).to_lower()
		var banned_body_negative := (
			"no character body" in prompt_text
			or "no creature body" in prompt_text
			or "no full pokemon body" in prompt_text
			or "not a full creature" in prompt_text
			or "no pokemon body" in prompt_text
		)
		checks.append(assert_eq(str(burst.get("path", "")), expected_path, "%s should use its dedicated body-first ready sheet" % rule_id))
		checks.append(assert_eq(int(burst.get("frames", 0)), 6, "%s should use a six-frame body-first ready sheet" % rule_id))
		checks.append(assert_eq(int(burst.get("rows", 0)), 2, "%s should use a 2x3 body-first ready sheet" % rule_id))
		checks.append(assert_eq(int(burst.get("cols", 0)), 3, "%s should use a 2x3 body-first ready sheet" % rule_id))
		checks.append(assert_not_null(image, "%s body-first ready sheet should load as an Image" % rule_id))
		checks.append(assert_eq(image.get_size() if image != null else Vector2i.ZERO, Vector2i(768, 512), "%s body-first ready sheet should be a 2x3 256px grid" % rule_id))
		checks.append(assert_gte(float(profile.get("duration")) if profile != null else 0.0, 1.45, "%s should linger like the Charizard cinematic ready animation" % rule_id))
		checks.append(assert_gte(float(profile.get("hold_ratio")) if profile != null else 0.0, 0.18, "%s should include a cinematic hold instead of flashing past" % rule_id))
		checks.append(assert_gte(float(profile.get("portrait_effect_width_ratio")) if profile != null else 0.0, 0.85, "%s should scale up in portrait mode" % rule_id))
		checks.append(assert_false(banned_body_negative, "%s prompt must not describe a pure-effect or no-body sheet" % rule_id))
	return run_checks(checks)


func test_budew_active_opening_ready_trigger() -> String:
	var evaluator: RefCounted = BattleReadyVfxEvaluatorScript.new()
	var gs := _make_state(0, 1, GameState.GamePhase.MAIN)
	gs.players[0].active_pokemon = _make_slot(_make_pokemon_card("Budew", "CSV9.5C", "004"), 0)
	var triggers: Array = evaluator.call("find_ready_triggers", gs)
	var trigger := _first_rule(triggers, "budew_opening_item_lock_ready")

	var bench_state := _make_state(0, 1, GameState.GamePhase.MAIN)
	bench_state.players[0].bench.append(_make_slot(_make_pokemon_card("Budew", "CSV9.5C", "004"), 0))
	var bench_triggers: Array = evaluator.call("find_ready_triggers", bench_state)

	var setup_state := _make_state(0, 1, GameState.GamePhase.SETUP)
	setup_state.players[0].active_pokemon = _make_slot(_make_pokemon_card("Budew", "CSV9.5C", "004"), 0)
	var setup_triggers: Array = evaluator.call("find_ready_triggers", setup_state)

	return run_checks([
		assert_eq(str(trigger.get("rule_id", "")), "budew_opening_item_lock_ready", "Active opening Budew should trigger ready VFX"),
		assert_eq(str(trigger.get("slot_kind", "")), "active", "Budew opening ready should target the Active slot"),
		assert_eq(int(trigger.get("slot_index", -99)), 0, "Active slot index should be normalized to 0"),
		assert_false(_has_rule(bench_triggers, "budew_opening_item_lock_ready"), "Benched Budew should not trigger the opening Active ready rule"),
		assert_false(_has_rule(setup_triggers, "budew_opening_item_lock_ready"), "Ready VFX should not fire during setup"),
	])


func test_radiant_greninja_ready_requires_attack_energy() -> String:
	var evaluator: RefCounted = BattleReadyVfxEvaluatorScript.new()
	var gs := _make_state(0, 3, GameState.GamePhase.MAIN)
	var greninja := _make_slot(_make_pokemon_card("Radiant Greninja", "CS6.5C", "020", "W", "Basic", 130, "Radiant", [_attack("WWC", "90")], "Radiant Greninja"), 0)
	_attach_energy(greninja, 0, "W", 2)
	_attach_energy(greninja, 0, "C", 1)
	gs.players[0].bench.append(greninja)
	var triggers: Array = evaluator.call("find_ready_triggers", gs)
	var trigger := _first_rule(triggers, "radiant_greninja_concealed_cards_ready")

	var no_energy_state := _make_state(0, 3, GameState.GamePhase.MAIN)
	no_energy_state.players[0].bench.append(_make_slot(_make_pokemon_card("Radiant Greninja", "CS6.5C", "020", "W", "Basic", 130, "Radiant", [_attack("WWC", "90")], "Radiant Greninja"), 0))
	no_energy_state.players[0].hand.append(CardInstance.create(_make_energy_card(), 0))
	var no_energy_triggers: Array = evaluator.call("find_ready_triggers", no_energy_state)

	greninja.mark_ability_used(gs.turn_number)
	var used_triggers: Array = evaluator.call("find_ready_triggers", gs)

	return run_checks([
		assert_eq(str(trigger.get("rule_id", "")), "radiant_greninja_concealed_cards_ready", "Radiant Greninja should trigger when its attack cost is paid"),
		assert_eq(str(trigger.get("slot_kind", "")), "bench", "Radiant Greninja ready should target its bench slot"),
		assert_eq(int(trigger.get("slot_index", -99)), 0, "Radiant Greninja ready should report the bench index"),
		assert_false(_has_rule(no_energy_triggers, "radiant_greninja_concealed_cards_ready"), "Radiant Greninja should ignore hand Energy and require attached attack Energy"),
		assert_true(_has_rule(used_triggers, "radiant_greninja_concealed_cards_ready"), "Radiant Greninja attack-ready VFX should not depend on Concealed Cards usage"),
	])


func test_ready_vfx_evaluator_detects_attack_and_board_ready_scenes() -> String:
	var evaluator: RefCounted = BattleReadyVfxEvaluatorScript.new()

	var dragapult_state := _make_state(0, 4, GameState.GamePhase.MAIN)
	var dragapult := _make_slot(_make_pokemon_card("Dragapult ex", "CSV8C", "159", "N", "Stage 2", 320, "ex", [_attack("C", "70"), _attack("RP", "200")], "Dragapult ex"), 0)
	_attach_energy(dragapult, 0, "R", 1)
	_attach_energy(dragapult, 0, "P", 1)
	dragapult_state.players[0].active_pokemon = dragapult
	dragapult_state.players[1].bench.append(_make_slot(_make_pokemon_card("Bench Target", "TEST", "B01", "C"), 1))
	var dragapult_triggers: Array = evaluator.call("find_ready_triggers", dragapult_state)

	var iron_hands_state := _make_state(0, 4, GameState.GamePhase.MAIN)
	var iron_hands := _make_slot(_make_pokemon_card("Iron Hands ex", "CSV6C", "051", "L", "Basic", 230, "ex", [_attack("LLC", "160"), _attack("LCCC", "120")], "Iron Hands ex"), 0)
	_attach_energy(iron_hands, 0, "L", 1)
	_attach_energy(iron_hands, 0, "C", 3)
	iron_hands_state.players[0].bench.append(iron_hands)
	var iron_hands_triggers: Array = evaluator.call("find_ready_triggers", iron_hands_state)

	var terapagos_state := _make_state(0, 4, GameState.GamePhase.MAIN)
	var terapagos := _make_slot(_make_pokemon_card("Terapagos ex", "CSV9C", "175", "C", "Basic", 230, "ex", [_attack("CC", "30x")], "Terapagos ex"), 0)
	_attach_energy(terapagos, 0, "C", 2)
	terapagos_state.players[0].active_pokemon = terapagos
	terapagos_state.stadium_card = CardInstance.create(_make_trainer_card("Area Zero Underdepths", "Stadium", "CSV9C", "207", "701eb0ccb34fe3d319ea1307bc36c1ef"), 0)
	for bench_index: int in 6:
		terapagos_state.players[0].bench.append(_make_slot(_make_pokemon_card("Bench %d" % bench_index, "TEST", "T%d" % bench_index, "C"), 0))
	var terapagos_triggers: Array = evaluator.call("find_ready_triggers", terapagos_state)

	var gholdengo_state := _make_state(0, 4, GameState.GamePhase.MAIN)
	var gholdengo := _make_slot(_make_pokemon_card("Gholdengo ex", "CSV4C", "089", "M", "Stage 1", 260, "ex", [_attack("M", "50x")], "Gholdengo ex"), 0)
	_attach_energy(gholdengo, 0, "M", 1)
	gholdengo_state.players[0].active_pokemon = gholdengo
	gholdengo_state.players[1].active_pokemon = _make_slot(_make_pokemon_card("Opponent Active", "TEST", "OA", "C", "Basic", 150), 1)
	_add_energy_to_zone(gholdengo_state.players[0].hand, 0, "M", 3)
	var gholdengo_triggers: Array = evaluator.call("find_ready_triggers", gholdengo_state)

	var ceruledge_state := _make_state(0, 4, GameState.GamePhase.MAIN)
	var ceruledge := _make_slot(_make_pokemon_card("Ceruledge ex", "CSV9C", "034", "R", "Stage 1", 270, "ex", [_attack("R", "30+"), _attack("RPM", "280")], "Ceruledge ex"), 0)
	_attach_energy(ceruledge, 0, "R", 1)
	ceruledge_state.players[0].active_pokemon = ceruledge
	_add_energy_to_zone(ceruledge_state.players[0].discard_pile, 0, "R", 5)
	var ceruledge_triggers: Array = evaluator.call("find_ready_triggers", ceruledge_state)

	var roaring_state := _make_state(0, 4, GameState.GamePhase.MAIN)
	var roaring_moon := _make_slot(_make_pokemon_card("Roaring Moon ex", "CSV6C", "096", "D", "Basic", 230, "ex", [_attack("DDC", ""), _attack("DDC", "100+")], "Roaring Moon ex"), 0)
	_attach_energy(roaring_moon, 0, "D", 2)
	_attach_energy(roaring_moon, 0, "C", 1)
	roaring_state.players[0].active_pokemon = roaring_moon
	roaring_state.players[1].active_pokemon = _make_slot(_make_pokemon_card("Opponent Active", "TEST", "OD", "C", "Basic", 220), 1)
	var roaring_triggers: Array = evaluator.call("find_ready_triggers", roaring_state)

	var arch_state := _make_state(0, 4, GameState.GamePhase.MAIN)
	var archaludon := _make_slot(_make_pokemon_card("Archaludon ex", "CSV9C", "138", "M", "Stage 1", 300, "ex", [_attack("MMM", "220")], "Archaludon ex"), 0)
	archaludon.turn_evolved = arch_state.turn_number
	_attach_energy(archaludon, 0, "M", 3)
	arch_state.players[0].active_pokemon = archaludon
	var arch_triggers: Array = evaluator.call("find_ready_triggers", arch_state)

	return run_checks([
		assert_true(_has_rule(dragapult_triggers, "dragapult_phantom_dive_ready"), "Dragapult ex should trigger when Phantom Dive is paid and opponent has a Bench target"),
		assert_true(_has_rule(iron_hands_triggers, "iron_hands_amp_ready"), "Iron Hands ex should trigger when four-Energy Amp You Very Much is ready"),
		assert_true(_has_rule(terapagos_triggers, "terapagos_cavern_board_ready"), "Terapagos ex should trigger when Area Zero creates a six-plus Bench damage shell"),
		assert_true(_has_rule(gholdengo_triggers, "gholdengo_big_swing_ready"), "Gholdengo ex should trigger when hand Energy can convert the opponent Active"),
		assert_true(_has_rule(ceruledge_triggers, "ceruledge_discard_energy_ready"), "Ceruledge ex should trigger when discard Energy reaches the key damage threshold"),
		assert_true(_has_rule(roaring_triggers, "roaring_moon_frenzied_ready"), "Roaring Moon ex should trigger when Frenzied Gouging is paid"),
		assert_true(_has_rule(arch_triggers, "archaludon_metal_bridge_ready"), "Archaludon ex should trigger after evolving this turn with its 220 attack paid"),
	])


func test_ready_vfx_evaluator_detects_engine_ability_ready_scenes() -> String:
	var evaluator: RefCounted = BattleReadyVfxEvaluatorScript.new()

	var lugia_state := _make_state(0, 4, GameState.GamePhase.MAIN)
	lugia_state.players[0].active_pokemon = _make_slot(_make_pokemon_card("Lugia VSTAR", "CS6aC", "103", "C", "VSTAR", 280, "V", [_attack("CCCC", "220")], "Lugia VSTAR"), 0)
	_add_card_to_zone(lugia_state.players[0].discard_pile, _make_pokemon_card("Archeops", "CS6aC", "113", "C", "Stage 2", 150, "", [_attack("CCC", "120")], "Archeops"), 0)
	_add_card_to_zone(lugia_state.players[0].discard_pile, _make_pokemon_card("Archeops", "CS6aC", "113", "C", "Stage 2", 150, "", [_attack("CCC", "120")], "Archeops"), 0)
	var lugia_triggers: Array = evaluator.call("find_ready_triggers", lugia_state)

	var palkia_state := _make_state(0, 4, GameState.GamePhase.MAIN)
	palkia_state.players[0].active_pokemon = _make_slot(_make_pokemon_card("Origin Forme Palkia VSTAR", "CS5bC", "051", "W", "VSTAR", 280, "V", [_attack("WW", "60+")], "Origin Forme Palkia VSTAR"), 0)
	_add_energy_to_zone(palkia_state.players[0].discard_pile, 0, "W", 1)
	var palkia_triggers: Array = evaluator.call("find_ready_triggers", palkia_state)

	var charizard_state := _make_state(0, 4, GameState.GamePhase.MAIN)
	var charizard := _make_slot(_make_pokemon_card("Charizard ex", "CSV5C", "075", "D", "Stage 2", 330, "ex", [_attack("RR", "180+")], "Charizard ex"), 0)
	charizard.turn_evolved = charizard_state.turn_number
	charizard.mark_rare_candy_evolved(charizard_state.turn_number)
	_attach_energy(charizard, 0, "R", 2)
	charizard_state.players[0].active_pokemon = charizard
	var charizard_triggers: Array = evaluator.call("find_ready_triggers", charizard_state)

	var miraidon_state := _make_state(0, 4, GameState.GamePhase.MAIN)
	var miraidon := _make_slot(_make_pokemon_card("Miraidon ex", "CSV1C", "050", "L", "Basic", 220, "ex", [_attack("LLC", "220")], "Miraidon ex"), 0)
	miraidon_state.players[0].active_pokemon = miraidon
	_mark_tandem_unit_used(miraidon, miraidon_state.turn_number)
	_append_tandem_summoned_bench(miraidon_state.players[0], miraidon, _make_slot(_make_pokemon_card("Raikou V", "TEST", "L01", "L", "Basic", 200, "V", [], "Raikou V"), 0), miraidon_state.turn_number)
	_append_tandem_summoned_bench(miraidon_state.players[0], miraidon, _make_slot(_make_pokemon_card("Iron Hands ex", "CSV6C", "051", "L", "Basic", 230, "ex", [], "Iron Hands ex"), 0), miraidon_state.turn_number)
	var miraidon_triggers: Array = evaluator.call("find_ready_triggers", miraidon_state)

	var miraidon_area_zero_state := _make_state(0, 4, GameState.GamePhase.MAIN)
	var area_zero_miraidon := _make_slot(_make_pokemon_card("Miraidon ex", "CSV1C", "050", "L", "Basic", 220, "ex", [_attack("LLC", "220")], "Miraidon ex"), 0)
	miraidon_area_zero_state.players[0].active_pokemon = area_zero_miraidon
	miraidon_area_zero_state.players[0].bench.append(_make_slot(_make_pokemon_card("Terapagos ex", "CSV9C", "175", "C", "Basic", 230, "ex", [_attack("CC", "30x")], "Terapagos ex"), 0))
	for bench_index: int in 4:
		miraidon_area_zero_state.players[0].bench.append(_make_slot(_make_pokemon_card("Lightning Bench %d" % bench_index, "TEST", "MZ%d" % bench_index, "L", "Basic", 80), 0))
	miraidon_area_zero_state.stadium_card = CardInstance.create(_make_trainer_card("Area Zero Underdepths", "Stadium", "CSV9C", "207", "701eb0ccb34fe3d319ea1307bc36c1ef"), 0)
	_mark_tandem_unit_used(area_zero_miraidon, miraidon_area_zero_state.turn_number)
	_append_tandem_summoned_bench(miraidon_area_zero_state.players[0], area_zero_miraidon, _make_slot(_make_pokemon_card("Area Zero Lightning A", "TEST", "MZ4", "L", "Basic", 80), 0), miraidon_area_zero_state.turn_number)
	_append_tandem_summoned_bench(miraidon_area_zero_state.players[0], area_zero_miraidon, _make_slot(_make_pokemon_card("Area Zero Lightning B", "TEST", "MZ5", "L", "Basic", 80), 0), miraidon_area_zero_state.turn_number)
	var miraidon_area_zero_triggers: Array = evaluator.call("find_ready_triggers", miraidon_area_zero_state)

	var regigigas_state := _make_state(0, 4, GameState.GamePhase.MAIN)
	regigigas_state.players[0].active_pokemon = _make_slot(_make_pokemon_card("Regigigas", "CS5.5C", "056", "C", "Basic", 150, "", [_attack("CCCCC", "150+")], "Regigigas"), 0)
	for name: String in ["Regirock", "Regice", "Registeel", "Regieleki", "Regidrago"]:
		regigigas_state.players[0].bench.append(_make_slot(_make_pokemon_card(name, "TEST", name, "C", "Basic", 120, "", [], name), 0))
	_add_energy_to_zone(regigigas_state.players[0].discard_pile, 0, "C", 1)
	var regigigas_triggers: Array = evaluator.call("find_ready_triggers", regigigas_state)

	var gardevoir_state := _make_state(0, 4, GameState.GamePhase.MAIN)
	var gardevoir := _make_slot(_make_pokemon_card("Gardevoir ex", "CSV2C", "055", "P", "Stage 2", 310, "ex", [_attack("PPC", "190")], "Gardevoir ex"), 0)
	gardevoir.turn_evolved = gardevoir_state.turn_number
	gardevoir.damage_counters = 300
	gardevoir_state.players[0].active_pokemon = gardevoir
	gardevoir_state.players[0].bench.append(_make_slot(_make_pokemon_card("Colorless Helper", "TEST", "GC1", "C", "Basic", 100), 0))
	_add_energy_to_zone(gardevoir_state.players[0].discard_pile, 0, "P", 3)
	var gardevoir_triggers: Array = evaluator.call("find_ready_triggers", gardevoir_state)
	var gardevoir_trigger := _first_rule(gardevoir_triggers, "gardevoir_psychic_embrace_ready")

	return run_checks([
		assert_true(_has_rule(lugia_triggers, "lugia_double_archeops_ready"), "Lugia VSTAR should trigger when two Archeops are in discard and VSTAR is unused"),
		assert_true(_has_rule(palkia_triggers, "palkia_vstar_acceleration_ready"), "Palkia VSTAR should trigger when Star Portal has discard Water Energy"),
		assert_true(_has_rule(charizard_triggers, "charizard_infernal_reign_ready"), "Charizard ex should trigger after Rare Candy evolution this turn when two Energy are attached"),
		assert_true(_has_rule(miraidon_triggers, "miraidon_generator_line_ready"), "Miraidon ex should trigger after Tandem Unit summons two Lightning Basic Pokemon this turn"),
		assert_true(_has_rule(miraidon_area_zero_triggers, "miraidon_generator_line_ready"), "Miraidon ex should still trigger after a full Area Zero Tandem Unit bench expansion"),
		assert_true(_has_rule(regigigas_triggers, "regigigas_ancient_wisdom_ready"), "Regigigas should trigger when all five Regis and discard Energy are available"),
		assert_true(_has_rule(gardevoir_triggers, "gardevoir_psychic_embrace_ready"), "Gardevoir ex should trigger when it evolves with three discard Basic Psychic Energy even without a safe Psychic target"),
		assert_eq(str(gardevoir_trigger.get("required_action_kind", "")), "evolve", "Gardevoir ready trigger should only play after an evolve action source"),
	])


func test_ready_vfx_evaluator_respects_new_rule_negative_gates() -> String:
	var evaluator: RefCounted = BattleReadyVfxEvaluatorScript.new()

	var lugia_used_state := _make_state(0, 4, GameState.GamePhase.MAIN)
	lugia_used_state.vstar_power_used[0] = true
	lugia_used_state.players[0].active_pokemon = _make_slot(_make_pokemon_card("Lugia VSTAR", "CS6aC", "103", "C", "VSTAR", 280, "V", [_attack("CCCC", "220")], "Lugia VSTAR"), 0)
	_add_card_to_zone(lugia_used_state.players[0].discard_pile, _make_pokemon_card("Archeops", "CS6aC", "113", "C", "Stage 2", 150, "", [], "Archeops"), 0)
	_add_card_to_zone(lugia_used_state.players[0].discard_pile, _make_pokemon_card("Archeops", "CS6aC", "113", "C", "Stage 2", 150, "", [], "Archeops"), 0)
	var lugia_used_triggers: Array = evaluator.call("find_ready_triggers", lugia_used_state)

	var terapagos_no_zero := _make_state(0, 4, GameState.GamePhase.MAIN)
	var terapagos := _make_slot(_make_pokemon_card("Terapagos ex", "CSV9C", "175", "C", "Basic", 230, "ex", [_attack("CC", "30x")], "Terapagos ex"), 0)
	_attach_energy(terapagos, 0, "C", 2)
	terapagos_no_zero.players[0].active_pokemon = terapagos
	for bench_index: int in 6:
		terapagos_no_zero.players[0].bench.append(_make_slot(_make_pokemon_card("Bench %d" % bench_index, "TEST", "NZ%d" % bench_index, "C"), 0))
	var terapagos_no_zero_triggers: Array = evaluator.call("find_ready_triggers", terapagos_no_zero)

	var gholdengo_short := _make_state(0, 4, GameState.GamePhase.MAIN)
	var gholdengo := _make_slot(_make_pokemon_card("Gholdengo ex", "CSV4C", "089", "M", "Stage 1", 260, "ex", [_attack("M", "50x")], "Gholdengo ex"), 0)
	_attach_energy(gholdengo, 0, "M", 1)
	gholdengo_short.players[0].active_pokemon = gholdengo
	gholdengo_short.players[1].active_pokemon = _make_slot(_make_pokemon_card("Opponent Active", "TEST", "OA", "C", "Basic", 220), 1)
	_add_energy_to_zone(gholdengo_short.players[0].hand, 0, "M", 3)
	var gholdengo_short_triggers: Array = evaluator.call("find_ready_triggers", gholdengo_short)

	var arch_unpaid := _make_state(0, 4, GameState.GamePhase.MAIN)
	var unpaid_archaludon := _make_slot(_make_pokemon_card("Archaludon ex", "CSV9C", "138", "M", "Stage 1", 300, "ex", [_attack("MMM", "220")], "Archaludon ex"), 0)
	unpaid_archaludon.turn_evolved = arch_unpaid.turn_number
	_attach_energy(unpaid_archaludon, 0, "M", 2)
	arch_unpaid.players[0].active_pokemon = unpaid_archaludon
	var arch_unpaid_triggers: Array = evaluator.call("find_ready_triggers", arch_unpaid)

	var arch_old_evolution := _make_state(0, 4, GameState.GamePhase.MAIN)
	var old_archaludon := _make_slot(_make_pokemon_card("Archaludon ex", "CSV9C", "138", "M", "Stage 1", 300, "ex", [_attack("MMM", "220")], "Archaludon ex"), 0)
	old_archaludon.turn_evolved = arch_old_evolution.turn_number - 1
	_attach_energy(old_archaludon, 0, "M", 3)
	arch_old_evolution.players[0].active_pokemon = old_archaludon
	var arch_old_evolution_triggers: Array = evaluator.call("find_ready_triggers", arch_old_evolution)

	var charizard_regular_evolution_state := _make_state(0, 4, GameState.GamePhase.MAIN)
	var regular_charizard := _make_slot(_make_pokemon_card("Charizard ex", "CSV5C", "075", "D", "Stage 2", 330, "ex", [_attack("RR", "180+")], "Charizard ex"), 0)
	regular_charizard.turn_evolved = charizard_regular_evolution_state.turn_number
	_attach_energy(regular_charizard, 0, "R", 2)
	charizard_regular_evolution_state.players[0].active_pokemon = regular_charizard
	var charizard_regular_triggers: Array = evaluator.call("find_ready_triggers", charizard_regular_evolution_state)

	var charizard_underpowered_state := _make_state(0, 4, GameState.GamePhase.MAIN)
	var underpowered_charizard := _make_slot(_make_pokemon_card("Charizard ex", "CSV5C", "075", "D", "Stage 2", 330, "ex", [_attack("RR", "180+")], "Charizard ex"), 0)
	underpowered_charizard.turn_evolved = charizard_underpowered_state.turn_number
	underpowered_charizard.mark_rare_candy_evolved(charizard_underpowered_state.turn_number)
	_attach_energy(underpowered_charizard, 0, "R", 1)
	charizard_underpowered_state.players[0].active_pokemon = underpowered_charizard
	var charizard_underpowered_triggers: Array = evaluator.call("find_ready_triggers", charizard_underpowered_state)

	var miraidon_unused_state := _make_state(0, 4, GameState.GamePhase.MAIN)
	miraidon_unused_state.players[0].active_pokemon = _make_slot(_make_pokemon_card("Miraidon ex", "CSV1C", "050", "L", "Basic", 220, "ex", [_attack("LLC", "220")], "Miraidon ex"), 0)
	_add_card_to_zone(miraidon_unused_state.players[0].deck, _make_pokemon_card("Lightning Basic", "TEST", "MU1", "L", "Basic", 80), 0)
	var miraidon_unused_triggers: Array = evaluator.call("find_ready_triggers", miraidon_unused_state)

	var miraidon_one_summon_state := _make_state(0, 4, GameState.GamePhase.MAIN)
	var one_summon_miraidon := _make_slot(_make_pokemon_card("Miraidon ex", "CSV1C", "050", "L", "Basic", 220, "ex", [_attack("LLC", "220")], "Miraidon ex"), 0)
	miraidon_one_summon_state.players[0].active_pokemon = one_summon_miraidon
	_mark_tandem_unit_used(one_summon_miraidon, miraidon_one_summon_state.turn_number)
	_append_tandem_summoned_bench(miraidon_one_summon_state.players[0], one_summon_miraidon, _make_slot(_make_pokemon_card("Single Lightning", "TEST", "MO1", "L", "Basic", 80), 0), miraidon_one_summon_state.turn_number)
	var miraidon_one_summon_triggers: Array = evaluator.call("find_ready_triggers", miraidon_one_summon_state)

	var gardevoir_two_energy_state := _make_state(0, 4, GameState.GamePhase.MAIN)
	var two_energy_gardevoir := _make_slot(_make_pokemon_card("Gardevoir ex", "CSV2C", "055", "P", "Stage 2", 310, "ex", [_attack("PPC", "190")], "Gardevoir ex"), 0)
	two_energy_gardevoir.turn_evolved = gardevoir_two_energy_state.turn_number
	gardevoir_two_energy_state.players[0].active_pokemon = two_energy_gardevoir
	_add_energy_to_zone(gardevoir_two_energy_state.players[0].discard_pile, 0, "P", 2)
	var gardevoir_two_energy_triggers: Array = evaluator.call("find_ready_triggers", gardevoir_two_energy_state)

	var gardevoir_old_evolution_state := _make_state(0, 4, GameState.GamePhase.MAIN)
	var old_gardevoir := _make_slot(_make_pokemon_card("Gardevoir ex", "CSV2C", "055", "P", "Stage 2", 310, "ex", [_attack("PPC", "190")], "Gardevoir ex"), 0)
	old_gardevoir.turn_evolved = gardevoir_old_evolution_state.turn_number - 1
	gardevoir_old_evolution_state.players[0].active_pokemon = old_gardevoir
	_add_energy_to_zone(gardevoir_old_evolution_state.players[0].discard_pile, 0, "P", 3)
	var gardevoir_old_evolution_triggers: Array = evaluator.call("find_ready_triggers", gardevoir_old_evolution_state)

	var gardevoir_special_energy_state := _make_state(0, 4, GameState.GamePhase.MAIN)
	var special_energy_gardevoir := _make_slot(_make_pokemon_card("Gardevoir ex", "CSV2C", "055", "P", "Stage 2", 310, "ex", [_attack("PPC", "190")], "Gardevoir ex"), 0)
	special_energy_gardevoir.turn_evolved = gardevoir_special_energy_state.turn_number
	gardevoir_special_energy_state.players[0].active_pokemon = special_energy_gardevoir
	_add_special_energy_to_zone(gardevoir_special_energy_state.players[0].discard_pile, 0, "P", 3)
	var gardevoir_special_energy_triggers: Array = evaluator.call("find_ready_triggers", gardevoir_special_energy_state)

	return run_checks([
		assert_false(_has_rule(lugia_used_triggers, "lugia_double_archeops_ready"), "Lugia ready should not trigger after VSTAR has been spent"),
		assert_false(_has_rule(terapagos_no_zero_triggers, "terapagos_cavern_board_ready"), "Terapagos Area Zero ready should require Area Zero to be active"),
		assert_false(_has_rule(gholdengo_short_triggers, "gholdengo_big_swing_ready"), "Gholdengo should not trigger when hand Energy cannot reach the opponent Active HP threshold"),
		assert_false(_has_rule(arch_unpaid_triggers, "archaludon_metal_bridge_ready"), "Archaludon ready should require enough Energy for its 220 attack"),
		assert_false(_has_rule(arch_old_evolution_triggers, "archaludon_metal_bridge_ready"), "Archaludon ready should require evolution this turn, not only a paid attack"),
		assert_false(_has_rule(charizard_regular_triggers, "charizard_infernal_reign_ready"), "Charizard ready should require Rare Candy evolution, not regular evolution this turn"),
		assert_false(_has_rule(charizard_underpowered_triggers, "charizard_infernal_reign_ready"), "Charizard ready should require two attached Energy after Rare Candy evolution"),
		assert_false(_has_rule(miraidon_unused_triggers, "miraidon_generator_line_ready"), "Miraidon ready should not preview before Tandem Unit is used"),
		assert_false(_has_rule(miraidon_one_summon_triggers, "miraidon_generator_line_ready"), "Miraidon ready should require Tandem Unit to summon two Lightning Basic Pokemon"),
		assert_false(_has_rule(gardevoir_two_energy_triggers, "gardevoir_psychic_embrace_ready"), "Gardevoir ready should require at least three discard Basic Psychic Energy"),
		assert_false(_has_rule(gardevoir_old_evolution_triggers, "gardevoir_psychic_embrace_ready"), "Gardevoir ready should only trigger on the turn it evolves into Gardevoir ex"),
		assert_false(_has_rule(gardevoir_special_energy_triggers, "gardevoir_psychic_embrace_ready"), "Gardevoir ready should require Basic Psychic Energy, not Special Energy"),
	])


func test_scene_ready_vfx_dedupes_refreshes_and_does_not_block_input() -> String:
	var gs := _make_state(0, 1, GameState.GamePhase.MAIN)
	gs.players[0].active_pokemon = _make_slot(_make_pokemon_card("Budew", "CSV9.5C", "004"), 0)
	var battle_scene := _make_scene_stub_with_state(gs)

	battle_scene.set("_ready_vfx_trigger_source_player_index", 0)
	battle_scene.call("_check_ready_vfx_triggers")
	battle_scene.set("_ready_vfx_trigger_source_player_index", 0)
	battle_scene.call("_check_ready_vfx_triggers")

	var overlay: Control = battle_scene.get("_ready_vfx_overlay") as Control
	var sequence_count := overlay.get_child_count() if overlay != null else 0
	var sequence: Control = overlay.get_child(0) as Control if overlay != null and overlay.get_child_count() > 0 else null

	var result := run_checks([
		assert_not_null(overlay, "Ready VFX overlay should be created"),
		assert_eq(overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE, "Ready VFX overlay must not intercept field or hand input"),
		assert_eq(sequence_count, 1, "Repeated refreshes should not replay the same ready key"),
		assert_eq(str(sequence.get_meta("profile_id", "")) if sequence != null else "", "ready_budew_item_lock", "Budew ready sequence should use the generated profile"),
	])
	battle_scene.free()
	return result


func test_scene_ready_vfx_triggers_after_effect_interaction_attaches_to_iron_hands() -> String:
	var gs := _make_state(0, 4, GameState.GamePhase.MAIN)
	var player := gs.players[0]
	var iron_hands := _make_slot(_make_pokemon_card("Iron Hands ex", "CSV6C", "051", "L", "Basic", 230, "ex", [_attack("LLC", "160"), _attack("LCCC", "120")], "Iron Hands ex"), 0)
	_attach_energy(iron_hands, 0, "L", 2)
	player.bench.append(iron_hands)
	var first_lightning := CardInstance.create(_make_energy_card("Lightning A", "L"), 0)
	var second_lightning := CardInstance.create(_make_energy_card("Lightning B", "L"), 0)
	player.deck = [
		first_lightning,
		CardInstance.create(_make_pokemon_card("Reveal Basic", "TEST", "001", "C"), 0),
		second_lightning,
		CardInstance.create(_make_energy_card("Grass", "G"), 0),
		CardInstance.create(_make_pokemon_card("Reveal Basic 2", "TEST", "002", "C"), 0),
	]
	var battle_scene := _make_scene_stub_with_state(gs)
	var gsm: GameStateMachine = battle_scene.get("_gsm")
	var effect := EffectElectricGeneratorScript.new()
	var generator_cd := _make_trainer_card("Electric Generator", "Item", "TEST", "EG1", "ready_test_electric_generator")
	var generator := CardInstance.create(generator_cd, 0)
	player.hand.append(generator)
	gsm.effect_processor.register_effect(generator_cd.effect_id, effect)
	var steps: Array[Dictionary] = effect.get_interaction_steps(generator, gs)

	battle_scene.call("_start_effect_interaction", "trainer", 0, steps, generator)
	var assignments: Array[Dictionary] = [
		{"source": first_lightning, "target": iron_hands},
		{"source": second_lightning, "target": iron_hands},
	]
	battle_scene.call("_commit_effect_assignment_selection", assignments)

	var overlay: Control = battle_scene.get("_ready_vfx_overlay") as Control
	var sequence: Control = overlay.get_child(0) as Control if overlay != null and overlay.get_child_count() > 0 else null
	var result := run_checks([
		assert_eq(iron_hands.get_total_energy_count(), 4, "Electric Generator should attach both revealed Lightning Energy to Iron Hands ex"),
		assert_not_null(sequence, "Ready VFX should play after an effect interaction makes Iron Hands ex attack-ready"),
		assert_eq(str(sequence.get_meta("rule_id", "")) if sequence != null else "", "iron_hands_amp_ready", "Iron Hands effect-interaction ready sequence should use the Amp rule"),
		assert_eq(str(sequence.get_meta("profile_id", "")) if sequence != null else "", "ready_iron_hands_amp", "Iron Hands ready sequence should use the dedicated profile"),
	])
	battle_scene.free()
	return result


func test_scene_gardevoir_ready_vfx_only_plays_after_evolve_action_source() -> String:
	var gs := _make_state(0, 4, GameState.GamePhase.MAIN)
	var gardevoir := _make_slot(_make_pokemon_card("Gardevoir ex", "CSV2C", "055", "P", "Stage 2", 310, "ex", [_attack("PPC", "190")], "Gardevoir ex"), 0)
	gardevoir.turn_evolved = gs.turn_number
	gs.players[0].active_pokemon = gardevoir
	_add_energy_to_zone(gs.players[0].discard_pile, 0, "P", 3)
	var battle_scene := _make_scene_stub_with_state(gs)

	battle_scene.set("_ready_vfx_trigger_source_player_index", 0)
	battle_scene.set("_ready_vfx_trigger_action_kind", "attach_energy")
	battle_scene.call("_check_ready_vfx_triggers")
	var overlay_after_attach: Control = battle_scene.get("_ready_vfx_overlay") as Control
	var attach_count := overlay_after_attach.get_child_count() if overlay_after_attach != null else 0

	battle_scene.set("_ready_vfx_trigger_source_player_index", 0)
	battle_scene.set("_ready_vfx_trigger_action_kind", "evolve")
	battle_scene.call("_check_ready_vfx_triggers")
	var overlay_after_evolve: Control = battle_scene.get("_ready_vfx_overlay") as Control
	var sequence: Control = overlay_after_evolve.get_child(0) as Control if overlay_after_evolve != null and overlay_after_evolve.get_child_count() > 0 else null
	var result := run_checks([
		assert_eq(attach_count, 0, "Gardevoir ready VFX should not play after a later non-evolve action in the same turn"),
		assert_not_null(sequence, "Gardevoir ready VFX should play immediately after the evolve action source"),
		assert_eq(str(sequence.get_meta("rule_id", "")) if sequence != null else "", "gardevoir_psychic_embrace_ready", "Gardevoir ready sequence should use the Psychic Embrace rule"),
		assert_eq(str(sequence.get_meta("profile_id", "")) if sequence != null else "", "ready_gardevoir_psychic_embrace", "Gardevoir ready sequence should use the dedicated profile"),
	])
	battle_scene.free()
	return result


func test_scene_ready_vfx_requires_same_player_action_source() -> String:
	var gs := _make_state(1, 2, GameState.GamePhase.MAIN)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_card("Budew", "CSV9.5C", "004"), 1)
	var battle_scene := _make_scene_stub_with_state(gs)

	battle_scene.set("_ready_vfx_trigger_source_player_index", 0)
	battle_scene.call("_check_ready_vfx_triggers")

	var overlay_after_opponent_action: Control = battle_scene.get("_ready_vfx_overlay") as Control
	var blocked_count := overlay_after_opponent_action.get_child_count() if overlay_after_opponent_action != null else 0

	battle_scene.set("_ready_vfx_trigger_source_player_index", 1)
	battle_scene.call("_check_ready_vfx_triggers")

	var overlay_after_owner_action: Control = battle_scene.get("_ready_vfx_overlay") as Control
	var allowed_count := overlay_after_owner_action.get_child_count() if overlay_after_owner_action != null else 0

	var result := run_checks([
		assert_eq(blocked_count, 0, "Ready VFX should not play when the latest successful action belongs to the other player"),
		assert_eq(allowed_count, 1, "Ready VFX should play when the latest successful action belongs to the same player as the trigger"),
	])
	battle_scene.free()
	return result
