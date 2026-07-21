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
const SQUAWKABILLY_FIRST_TURN_DRAW_USED_KEY := "ability_first_turn_draw_used"


class ReadyGeometryScene extends Control:
	var _ready_vfx_overlay: Control = null


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


func _deck_entry_count(deck: DeckData, card_ref: String) -> int:
	if deck == null:
		return 0
	var count := 0
	for entry: Dictionary in deck.cards:
		var entry_ref := "%s_%s" % [str(entry.get("set_code", "")), str(entry.get("card_index", ""))]
		if entry_ref == card_ref:
			count += int(entry.get("count", 0))
	return count


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


func _mark_squawkabilly_first_turn_draw_used(slot: PokemonSlot, turn_number: int) -> void:
	slot.effects.append({
		"type": SQUAWKABILLY_FIRST_TURN_DRAW_USED_KEY,
		"turn": turn_number,
	})


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


func _ready_sheet_pixel_metrics(image: Image) -> Dictionary:
	var metrics := {
		"opaque": 0,
		"green": 0,
		"yellow_orange": 0,
		"white": 0,
		"black": 0,
		"edge_alpha": 0,
	}
	if image == null:
		return metrics
	for y: int in image.get_height():
		for x: int in image.get_width():
			var pixel := image.get_pixel(x, y)
			if pixel.a <= 0.1:
				continue
			metrics["opaque"] = int(metrics["opaque"]) + 1
			if pixel.g > 0.42 and pixel.g > pixel.r * 1.04 and pixel.b < 0.5:
				metrics["green"] = int(metrics["green"]) + 1
			if pixel.r > 0.62 and pixel.g > 0.32 and pixel.b < 0.36:
				metrics["yellow_orange"] = int(metrics["yellow_orange"]) + 1
			if pixel.r > 0.66 and pixel.g > 0.66 and pixel.b > 0.52:
				metrics["white"] = int(metrics["white"]) + 1
			if pixel.r < 0.22 and pixel.g < 0.22 and pixel.b < 0.22:
				metrics["black"] = int(metrics["black"]) + 1
			var local_x := x % 256
			var local_y := y % 256
			if local_x < 2 or local_x > 253 or local_y < 2 or local_y > 253:
				metrics["edge_alpha"] = int(metrics["edge_alpha"]) + 1
	return metrics


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


func test_ready_vfx_registry_registers_squawkabilly_body_asset() -> String:
	var registry: RefCounted = BattleReadyVfxRegistryScript.new()
	var profile: RefCounted = registry.call("get_profile", "squawkabilly_first_turn_draw_ready")
	var asset_specs: Dictionary = profile.get("asset_specs") if profile != null else {}
	var burst: Dictionary = asset_specs.get("burst", {})
	var path := str(burst.get("path", ""))
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	var runtime_texture: Texture2D = load(path) as Texture2D
	var metrics := _ready_sheet_pixel_metrics(image)

	return run_checks([
		assert_not_null(profile, "Squawkabilly ex ready profile should be registered"),
		assert_eq(str(profile.get("profile_id")) if profile != null else "", "ready_squawkabilly_first_turn_draw", "Squawkabilly ready profile id should be stable"),
		assert_eq(path, "res://assets/textures/vfx/ready_squawkabilly_first_turn_draw/sheet-transparent.png", "Squawkabilly ready profile should point to the dedicated sheet"),
		assert_eq(int(burst.get("frames", 0)), 6, "Squawkabilly ready sheet should have 6 frames"),
		assert_eq(int(burst.get("rows", 0)), 2, "Squawkabilly ready sheet should have 2 rows"),
		assert_eq(int(burst.get("cols", 0)), 3, "Squawkabilly ready sheet should have 3 columns"),
		assert_gte(float(profile.get("duration")) if profile != null else 0.0, 1.45, "Squawkabilly ready animation should linger like a real board-state cue"),
		assert_gte(float(profile.get("hold_ratio")) if profile != null else 0.0, 0.18, "Squawkabilly ready animation should have a readable peak hold"),
		assert_not_null(image, "Squawkabilly ready sheet should load as an Image"),
		assert_eq(image.get_size() if image != null else Vector2i.ZERO, Vector2i(768, 512), "Squawkabilly ready sheet should be a 2x3 256px grid"),
		assert_not_null(runtime_texture, "Squawkabilly ready sheet should load through Godot's importer"),
		assert_eq(Vector2i(runtime_texture.get_width(), runtime_texture.get_height()) if runtime_texture != null else Vector2i.ZERO, Vector2i(768, 512), "Runtime Squawkabilly texture should use the generated sheet dimensions"),
		assert_gte(int(metrics.get("opaque", 0)), 100000, "Squawkabilly sheet should contain a large redrawn Pokemon body, not tiny symbols"),
		assert_gte(int(metrics.get("green", 0)), 30000, "Squawkabilly sheet should preserve its green body identity"),
		assert_gte(int(metrics.get("yellow_orange", 0)), 6000, "Squawkabilly sheet should preserve its yellow-orange beak/feet identity"),
		assert_gte(int(metrics.get("white", 0)), 18000, "Squawkabilly sheet should preserve its white belly identity"),
		assert_gte(int(metrics.get("black", 0)), 12000, "Squawkabilly sheet should preserve its black pompadour crest and outline identity"),
		assert_eq(int(metrics.get("edge_alpha", 0)), 0, "Squawkabilly frames should not touch cell edges or be cropped"),
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
		"squawkabilly_first_turn_draw_ready",
		"marnies_grimmsnarl_punk_up_ready",
		"ns_zoroark_night_joker_ready",
		"raging_bolt_bellowing_thunder_lethal_ready",
		"ethans_ho_oh_golden_flame_ready",
		"cynthias_garchomp_spiral_draw_ready",
		"ethans_typhlosion_partner_blast_lethal_ready",
		"blaziken_boiling_spirit_acceleration_ready",
		"pidgeot_quick_search_control_ready",
		"flareon_burning_charge_engine_ready",
		"hops_zacian_brave_blade_lethal_ready",
		"yanmega_buzzing_rush_acceleration_ready",
		"munkidori_adrena_brain_transfer_ready",
		"toedscruel_colony_rush_lethal_ready",
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
		var metrics := _ready_sheet_pixel_metrics(image)
		checks.append(assert_eq(str(burst.get("path", "")), expected_path, "%s should use its dedicated body-first ready sheet" % rule_id))
		checks.append(assert_eq(int(burst.get("frames", 0)), 6, "%s should use a six-frame body-first ready sheet" % rule_id))
		checks.append(assert_eq(int(burst.get("rows", 0)), 2, "%s should use a 2x3 body-first ready sheet" % rule_id))
		checks.append(assert_eq(int(burst.get("cols", 0)), 3, "%s should use a 2x3 body-first ready sheet" % rule_id))
		checks.append(assert_not_null(image, "%s body-first ready sheet should load as an Image" % rule_id))
		checks.append(assert_eq(image.get_size() if image != null else Vector2i.ZERO, Vector2i(768, 512), "%s body-first ready sheet should be a 2x3 256px grid" % rule_id))
		checks.append(assert_gte(float(profile.get("duration")) if profile != null else 0.0, 1.45, "%s should linger like the Charizard cinematic ready animation" % rule_id))
		checks.append(assert_gte(float(profile.get("hold_ratio")) if profile != null else 0.0, 0.18, "%s should include a cinematic hold instead of flashing past" % rule_id))
		checks.append(assert_gte(float(profile.get("portrait_effect_width_ratio")) if profile != null else 0.0, 0.85, "%s should scale up in portrait mode" % rule_id))
		checks.append(assert_gte(int(metrics.get("opaque", 0)), 30000, "%s sheet should contain substantial visible Pokemon art, not a tiny symbol" % rule_id))
		checks.append(assert_eq(int(metrics.get("edge_alpha", 0)), 0, "%s sheet should not touch cell edges or be cropped" % rule_id))
	return run_checks(checks)


func test_video18_ready_vfx_coverage_matrix_has_one_tactical_core_per_deck() -> String:
	var registry: RefCounted = BattleReadyVfxRegistryScript.new()
	var coverage := {
		800015934: {"core": "CSV9C_175", "rule": "terapagos_cavern_board_ready"},
		800018359: {"core": "CSV4C_101", "rule": "pidgeot_quick_search_control_ready"},
		800017643: {"core": "CSV9.5C_023", "rule": "flareon_burning_charge_engine_ready"},
		800017407: {"core": "CSV10C_161", "rule": "hops_zacian_brave_blade_lethal_ready"},
		800033475: {"core": "CSV10C_003", "rule": "yanmega_buzzing_rush_acceleration_ready"},
		800017631: {"core": "CSV8C_094", "rule": "munkidori_adrena_brain_transfer_ready"},
		800018543: {"core": "CSV10C_113", "rule": "cynthias_garchomp_spiral_draw_ready"},
		800018539: {"core": "CSV10C_035", "rule": "ethans_ho_oh_golden_flame_ready"},
		800018880: {"core": "CSV10C_030", "rule": "ethans_typhlosion_partner_blast_lethal_ready"},
		800018500: {"core": "CSV5C_010", "rule": "toedscruel_colony_rush_lethal_ready"},
		18000625: {"core": "CSV7C_038", "rule": "blaziken_boiling_spirit_acceleration_ready"},
		800018497: {"core": "CSV2C_055", "rule": "gardevoir_psychic_embrace_ready"},
		800018499: {"core": "CSV8C_159", "rule": "dragapult_phantom_dive_ready"},
		800018501: {"core": "CSV10C_148", "rule": "marnies_grimmsnarl_punk_up_ready"},
		800018502: {"core": "CSV10C_145", "rule": "ns_zoroark_night_joker_ready"},
		800018509: {"core": "CSV7C_154", "rule": "raging_bolt_bellowing_thunder_lethal_ready"},
		800015734: {"core": "CSV8C_159", "rule": "dragapult_phantom_dive_ready"},
		800019125: {"core": "CSV8C_159", "rule": "dragapult_phantom_dive_ready"},
		800017097: {"core": "CSV2C_055", "rule": "gardevoir_psychic_embrace_ready"},
		800018105: {"core": "CSV2C_055", "rule": "gardevoir_psychic_embrace_ready"},
		800018498: {"core": "CSV2C_055", "rule": "gardevoir_psychic_embrace_ready"},
		800016834: {"core": "CSV4C_089", "rule": "gholdengo_big_swing_ready"},
		800017047: {"core": "CSV7C_038", "rule": "blaziken_boiling_spirit_acceleration_ready"},
		18000230: {"core": "CSV5C_075", "rule": "charizard_infernal_reign_ready"},
	}
	var checks: Array[String] = [
		assert_eq(coverage.size(), 24, "All twenty-four bundled 18.0 decks should have a tactical ready-VFX core"),
	]
	for deck_id_variant: Variant in coverage:
		var deck_id := int(deck_id_variant)
		var spec: Dictionary = coverage[deck_id]
		var deck: DeckData = CardDatabase.get_deck(deck_id)
		var core_ref := str(spec.get("core", ""))
		var rule_id := str(spec.get("rule", ""))
		checks.append(assert_not_null(deck, "18.0 deck %d should load for ready-VFX coverage" % deck_id))
		checks.append(assert_true(_deck_entry_count(deck, core_ref) > 0, "18.0 deck %d should contain mapped ready core %s" % [deck_id, core_ref]))
		checks.append(assert_not_null(registry.call("get_profile", rule_id), "18.0 deck %d should map to registered ready rule %s" % [deck_id, rule_id]))
	return run_checks(checks)


func test_marnies_grimmsnarl_punk_up_ready_asset_is_body_first() -> String:
	var registry: RefCounted = BattleReadyVfxRegistryScript.new()
	var profile: RefCounted = registry.call("get_profile", "marnies_grimmsnarl_punk_up_ready")
	var asset_specs: Dictionary = profile.get("asset_specs") if profile != null else {}
	var burst: Dictionary = asset_specs.get("burst", {})
	var path := str(burst.get("path", ""))
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	var metrics := _ready_sheet_pixel_metrics(image)
	return run_checks([
		assert_not_null(profile, "Marnie's Grimmsnarl ready profile should be registered"),
		assert_eq(str(profile.get("profile_id")) if profile != null else "", "ready_marnies_grimmsnarl_punk_up", "Grimmsnarl profile id should describe Punk Up"),
		assert_eq(path, "res://assets/textures/vfx/ready_marnies_grimmsnarl_punk_up/sheet-transparent.png", "Grimmsnarl ready profile should use its generated body sheet"),
		assert_eq(image.get_size() if image != null else Vector2i.ZERO, Vector2i(768, 512), "Grimmsnarl ready sheet should be a 2x3 256px grid"),
		assert_gte(int(metrics.get("opaque", 0)), 30000, "Grimmsnarl sheet should contain substantial full-body art"),
		assert_gte(int(metrics.get("green", 0)), 250, "Grimmsnarl sheet should preserve its green body accents"),
		assert_gte(int(metrics.get("black", 0)), 1200, "Grimmsnarl sheet should preserve its dark silhouette"),
		assert_eq(int(metrics.get("edge_alpha", 0)), 0, "Grimmsnarl animation must stay inside every frame"),
	])


func test_marnies_grimmsnarl_punk_up_ready_requires_resolved_energy_board() -> String:
	var evaluator: RefCounted = BattleReadyVfxEvaluatorScript.new()
	var state := _make_state(0, 4)
	var grimmsnarl := _make_pokemon_card(
		"玛俐的长毛巨魔ex",
		"CSV10C",
		"148",
		"D",
		"Stage 2",
		320,
		"ex",
		[_attack("DD", "180", "暗影子弹")],
		"Marnie's Grimmsnarl ex"
	)
	var grimmsnarl_slot := _make_slot(grimmsnarl, 0)
	grimmsnarl_slot.turn_evolved = state.turn_number
	grimmsnarl_slot.effects.append({"type": "marnies_grimmsnarl_punk_up_used", "turn": state.turn_number})
	_attach_energy(grimmsnarl_slot, 0, "D", 2)
	state.players[0].bench.append(grimmsnarl_slot)

	var trigger := _first_rule(evaluator.call("find_ready_triggers", state), "marnies_grimmsnarl_punk_up_ready")
	var checks: Array[String] = [
		assert_false(trigger.is_empty(), "Punk Up should cue after the evolve ability resolves into an attack-ready Darkness board"),
		assert_eq(str(trigger.get("required_action_kind", "")), "use_ability", "Punk Up cue should be sourced from the resolved ability action"),
		assert_eq(str(trigger.get("slot_kind", "")), "bench", "Punk Up should cue on the Grimmsnarl that powered the board"),
	]

	grimmsnarl_slot.effects.clear()
	checks.append(assert_false(_has_rule(evaluator.call("find_ready_triggers", state), "marnies_grimmsnarl_punk_up_ready"), "Evolving without resolving Punk Up must not cue"))
	grimmsnarl_slot.effects.append({"type": "marnies_grimmsnarl_punk_up_used", "turn": state.turn_number - 1})
	checks.append(assert_false(_has_rule(evaluator.call("find_ready_triggers", state), "marnies_grimmsnarl_punk_up_ready"), "A Punk Up resolved on an earlier turn must not cue"))
	grimmsnarl_slot.effects[0]["turn"] = state.turn_number
	grimmsnarl_slot.attached_energy.resize(1)
	checks.append(assert_false(_has_rule(evaluator.call("find_ready_triggers", state), "marnies_grimmsnarl_punk_up_ready"), "Punk Up should not cue before the Marnie's board reaches two Darkness Energy"))
	return run_checks(checks)


func test_ns_zoroark_night_joker_ready_asset_is_body_first() -> String:
	var registry: RefCounted = BattleReadyVfxRegistryScript.new()
	var profile: RefCounted = registry.call("get_profile", "ns_zoroark_night_joker_ready")
	var asset_specs: Dictionary = profile.get("asset_specs") if profile != null else {}
	var burst: Dictionary = asset_specs.get("burst", {})
	var path := str(burst.get("path", ""))
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	var metrics := _ready_sheet_pixel_metrics(image)
	return run_checks([
		assert_not_null(profile, "N's Zoroark ready profile should be registered"),
		assert_eq(str(profile.get("profile_id")) if profile != null else "", "ready_ns_zoroark_night_joker", "Zoroark profile id should describe the Night Joker route"),
		assert_eq(path, "res://assets/textures/vfx/ready_ns_zoroark_night_joker/sheet-transparent.png", "Zoroark ready profile should use its generated body sheet"),
		assert_eq(image.get_size() if image != null else Vector2i.ZERO, Vector2i(768, 512), "Zoroark ready sheet should be a 2x3 256px grid"),
		assert_gte(int(metrics.get("opaque", 0)), 30000, "Zoroark sheet should contain substantial full-body art"),
		assert_gte(int(metrics.get("black", 0)), 1000, "Zoroark sheet should preserve its dark illusion silhouette"),
		assert_eq(int(metrics.get("edge_alpha", 0)), 0, "Zoroark animation must stay inside every frame"),
	])


func test_ns_zoroark_night_joker_ready_requires_paid_attack_and_copy_target() -> String:
	var evaluator: RefCounted = BattleReadyVfxEvaluatorScript.new()
	var state := _make_state(0, 5)
	var zoroark := _make_pokemon_card(
		"N的索罗亚克ex", "CSV10C", "145", "D", "Stage 1", 280, "ex",
		[_attack("DD", "", "暗夜王牌")], "N's Zoroark ex"
	)
	var zoroark_slot := _make_slot(zoroark, 0)
	_attach_energy(zoroark_slot, 0, "D", 2)
	state.players[0].active_pokemon = zoroark_slot
	var reshiram := _make_pokemon_card(
		"N的莱希拉姆", "CSV10C", "166", "R", "Basic", 130, "",
		[_attack("RRC", "170", "力量怒火")], "N's Reshiram"
	)
	state.players[0].bench.append(_make_slot(reshiram, 0))
	state.players[1].active_pokemon = _make_slot(_make_pokemon_card("Target", "TEST", "900", "C", "Basic", 220), 1)

	var trigger := _first_rule(evaluator.call("find_ready_triggers", state), "ns_zoroark_night_joker_ready")
	var checks: Array[String] = [
		assert_false(trigger.is_empty(), "Night Joker should cue when active Zoroark has DD and a Benched N attack to copy"),
		assert_eq(str(trigger.get("slot_kind", "")), "active", "Night Joker cue should belong to the active Zoroark"),
	]

	zoroark_slot.attached_energy.resize(1)
	checks.append(assert_false(_has_rule(evaluator.call("find_ready_triggers", state), "ns_zoroark_night_joker_ready"), "Night Joker should not cue before both Darkness costs are paid"))
	_attach_energy(zoroark_slot, 0, "D", 1)
	state.players[0].bench.clear()
	checks.append(assert_false(_has_rule(evaluator.call("find_ready_triggers", state), "ns_zoroark_night_joker_ready"), "Night Joker should not cue without a Benched N Pokemon attack"))
	var recursive := _make_pokemon_card(
		"N的另一只索罗亚克", "TEST", "145B", "D", "Stage 1", 140, "",
		[_attack("DD", "", "暗夜王牌")], "N's Other Zoroark"
	)
	state.players[0].bench.append(_make_slot(recursive, 0))
	checks.append(assert_false(_has_rule(evaluator.call("find_ready_triggers", state), "ns_zoroark_night_joker_ready"), "Night Joker must not treat another recursive copy attack as a tactical route"))
	return run_checks(checks)


func test_raging_bolt_bellowing_thunder_ready_asset_is_body_first() -> String:
	var registry: RefCounted = BattleReadyVfxRegistryScript.new()
	var profile: RefCounted = registry.call("get_profile", "raging_bolt_bellowing_thunder_lethal_ready")
	var asset_specs: Dictionary = profile.get("asset_specs") if profile != null else {}
	var burst: Dictionary = asset_specs.get("burst", {})
	var path := str(burst.get("path", ""))
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	var metrics := _ready_sheet_pixel_metrics(image)
	return run_checks([
		assert_not_null(profile, "Raging Bolt ready profile should be registered"),
		assert_eq(str(profile.get("profile_id")) if profile != null else "", "ready_raging_bolt_bellowing_thunder_lethal", "Raging Bolt profile id should describe the lethal Bellowing Thunder line"),
		assert_eq(path, "res://assets/textures/vfx/ready_raging_bolt_bellowing_thunder_lethal/sheet-transparent.png", "Raging Bolt ready profile should use its generated body sheet"),
		assert_eq(image.get_size() if image != null else Vector2i.ZERO, Vector2i(768, 512), "Raging Bolt ready sheet should be a 2x3 256px grid"),
		assert_gte(int(metrics.get("opaque", 0)), 30000, "Raging Bolt sheet should contain substantial full-body art"),
		assert_gte(int(metrics.get("yellow_orange", 0)), 600, "Raging Bolt sheet should preserve its yellow lightning body accents"),
		assert_gte(int(metrics.get("white", 0)), 600, "Raging Bolt sheet should preserve its bright cloud-and-neck silhouette"),
		assert_eq(int(metrics.get("edge_alpha", 0)), 0, "Raging Bolt animation must stay inside every frame"),
	])


func test_raging_bolt_bellowing_thunder_ready_requires_exact_lethal_energy_line() -> String:
	var evaluator: RefCounted = BattleReadyVfxEvaluatorScript.new()
	var state := _make_state(0, 3)
	var raging_bolt := _make_pokemon_card(
		"猛雷鼓ex", "CSV7C", "154", "N", "Basic", 240, "ex",
		[_attack("C", "", "飞溅咆哮"), _attack("LF", "70×", "极雷轰")], "Raging Bolt ex"
	)
	var bolt_slot := _make_slot(raging_bolt, 0)
	_attach_energy(bolt_slot, 0, "L", 1)
	_attach_energy(bolt_slot, 0, "F", 1)
	state.players[0].active_pokemon = bolt_slot
	var ogerpon := _make_pokemon_card("厄诡椪 碧草面具ex", "CSV8C", "028", "G", "Basic", 210, "ex", [], "Teal Mask Ogerpon ex")
	var ogerpon_slot := _make_slot(ogerpon, 0)
	_attach_energy(ogerpon_slot, 0, "G", 1)
	state.players[0].bench.append(ogerpon_slot)
	state.players[1].active_pokemon = _make_slot(_make_pokemon_card("Target 210", "TEST", "910", "C", "Basic", 210), 1)

	var trigger := _first_rule(evaluator.call("find_ready_triggers", state), "raging_bolt_bellowing_thunder_lethal_ready")
	var checks: Array[String] = [
		assert_false(trigger.is_empty(), "Bellowing Thunder should cue when LF is paid and three field Energy exactly cover 210 HP"),
		assert_eq(str(trigger.get("slot_kind", "")), "active", "Bellowing Thunder lethal cue should belong to active Raging Bolt"),
	]

	state.players[1].active_pokemon = _make_slot(_make_pokemon_card("Target 280", "TEST", "911", "C", "Basic", 280), 1)
	checks.append(assert_false(_has_rule(evaluator.call("find_ready_triggers", state), "raging_bolt_bellowing_thunder_lethal_ready"), "Three field Energy must not cue against a 280 HP target"))
	_attach_energy(ogerpon_slot, 0, "G", 1)
	checks.append(assert_true(_has_rule(evaluator.call("find_ready_triggers", state), "raging_bolt_bellowing_thunder_lethal_ready"), "A fourth field Energy should complete the 280 HP lethal line"))
	bolt_slot.attached_energy.resize(1)
	checks.append(assert_false(_has_rule(evaluator.call("find_ready_triggers", state), "raging_bolt_bellowing_thunder_lethal_ready"), "Field fuel alone must not cue before Raging Bolt pays both Lightning and Fighting"))
	return run_checks(checks)


func test_ethans_ho_oh_golden_flame_ready_asset_is_body_first() -> String:
	var registry: RefCounted = BattleReadyVfxRegistryScript.new()
	var profile: RefCounted = registry.call("get_profile", "ethans_ho_oh_golden_flame_ready")
	var asset_specs: Dictionary = profile.get("asset_specs") if profile != null else {}
	var burst: Dictionary = asset_specs.get("burst", {})
	var path := str(burst.get("path", ""))
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	var metrics := _ready_sheet_pixel_metrics(image)
	return run_checks([
		assert_not_null(profile, "Ethan's Ho-Oh ready profile should be registered"),
		assert_eq(str(profile.get("profile_id")) if profile != null else "", "ready_ethans_ho_oh_golden_flame", "Ho-Oh profile id should describe Golden Flame"),
		assert_eq(path, "res://assets/textures/vfx/ready_ethans_ho_oh_golden_flame/sheet-transparent.png", "Ho-Oh ready profile should use its generated body sheet"),
		assert_eq(image.get_size() if image != null else Vector2i.ZERO, Vector2i(768, 512), "Ho-Oh ready sheet should be a 2x3 256px grid"),
		assert_gte(int(metrics.get("opaque", 0)), 30000, "Ho-Oh sheet should contain substantial full-body art"),
		assert_gte(int(metrics.get("yellow_orange", 0)), 800, "Ho-Oh sheet should preserve its gold-and-fire plumage"),
		assert_gte(int(metrics.get("white", 0)), 500, "Ho-Oh sheet should preserve its bright chest and wing accents"),
		assert_eq(int(metrics.get("edge_alpha", 0)), 0, "Ho-Oh animation must stay inside every frame"),
	])


func test_ethans_ho_oh_golden_flame_ready_requires_resolved_double_fire_bench() -> String:
	var evaluator: RefCounted = BattleReadyVfxEvaluatorScript.new()
	var state := _make_state(0, 4)
	var ho_oh := _make_pokemon_card("阿响的凤王ex", "CSV10C", "035", "R", "Basic", 230, "ex", [_attack("RRRR", "160", "闪耀之羽")], "Ethan's Ho-Oh ex")
	var ho_oh_slot := _make_slot(ho_oh, 0)
	ho_oh_slot.mark_ability_used(state.turn_number)
	state.players[0].bench.append(ho_oh_slot)
	var cyndaquil := _make_pokemon_card("阿响的火球鼠", "CSV10C", "028", "R", "Basic", 70, "", [], "Ethan's Cyndaquil")
	var cyndaquil_slot := _make_slot(cyndaquil, 0)
	_attach_energy(cyndaquil_slot, 0, "R", 2)
	state.players[0].bench.append(cyndaquil_slot)

	var trigger := _first_rule(evaluator.call("find_ready_triggers", state), "ethans_ho_oh_golden_flame_ready")
	var checks: Array[String] = [
		assert_false(trigger.is_empty(), "Golden Flame should cue after the ability resolves into two Fire Energy on Ethan's Bench"),
		assert_eq(str(trigger.get("required_action_kind", "")), "use_ability", "Golden Flame cue should be sourced from the resolved ability action"),
		assert_eq(str(trigger.get("slot_kind", "")), "bench", "Golden Flame cue should stay anchored to Ho-Oh"),
	]

	ho_oh_slot.effects.clear()
	checks.append(assert_false(_has_rule(evaluator.call("find_ready_triggers", state), "ethans_ho_oh_golden_flame_ready"), "A charged Ethan's Bench alone must not cue before Golden Flame resolves"))
	ho_oh_slot.mark_ability_used(state.turn_number - 1)
	checks.append(assert_false(_has_rule(evaluator.call("find_ready_triggers", state), "ethans_ho_oh_golden_flame_ready"), "Golden Flame from an earlier turn must not cue"))
	ho_oh_slot.effects.clear()
	ho_oh_slot.mark_ability_used(state.turn_number)
	cyndaquil_slot.attached_energy.resize(1)
	checks.append(assert_false(_has_rule(evaluator.call("find_ready_triggers", state), "ethans_ho_oh_golden_flame_ready"), "Golden Flame should not cue before the Ethan's Bench reaches two basic Fire Energy"))
	return run_checks(checks)


func test_cynthias_garchomp_spiral_draw_ready_asset_is_body_first() -> String:
	var registry: RefCounted = BattleReadyVfxRegistryScript.new()
	var profile: RefCounted = registry.call("get_profile", "cynthias_garchomp_spiral_draw_ready")
	var asset_specs: Dictionary = profile.get("asset_specs") if profile != null else {}
	var burst: Dictionary = asset_specs.get("burst", {})
	var path := str(burst.get("path", ""))
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	var metrics := _ready_sheet_pixel_metrics(image)
	return run_checks([
		assert_not_null(profile, "Cynthia's Garchomp ready profile should be registered"),
		assert_eq(str(profile.get("profile_id")) if profile != null else "", "ready_cynthias_garchomp_spiral_draw", "Garchomp profile id should describe its Spiral Dive draw engine"),
		assert_eq(path, "res://assets/textures/vfx/ready_cynthias_garchomp_spiral_draw/sheet-transparent.png", "Garchomp ready profile should use its generated body sheet"),
		assert_eq(image.get_size() if image != null else Vector2i.ZERO, Vector2i(768, 512), "Garchomp ready sheet should be a 2x3 256px grid"),
		assert_gte(int(metrics.get("opaque", 0)), 30000, "Garchomp sheet should contain substantial full-body art"),
		assert_gte(int(metrics.get("yellow_orange", 0)), 500, "Garchomp sheet should preserve its gold star and chest accents"),
		assert_gte(int(metrics.get("white", 0)), 500, "Garchomp sheet should preserve its bright claws and spiral highlights"),
		assert_eq(int(metrics.get("edge_alpha", 0)), 0, "Garchomp animation must stay inside every frame"),
	])


func test_cynthias_garchomp_spiral_draw_ready_requires_active_refill_window() -> String:
	var evaluator: RefCounted = BattleReadyVfxEvaluatorScript.new()
	var state := _make_state(0, 4)
	var garchomp := _make_pokemon_card(
		"竹兰的烈咬陆鲨ex", "CSV10C", "113", "F", "Stage 2", 330, "ex",
		[_attack("F", "100", "螺旋俯冲"), _attack("FF", "260", "龙之爆破")], "Cynthia's Garchomp ex"
	)
	var garchomp_slot := _make_slot(garchomp, 0)
	_attach_energy(garchomp_slot, 0, "F", 1)
	state.players[0].active_pokemon = garchomp_slot
	for i: int in 4:
		_add_card_to_zone(state.players[0].hand, _make_trainer_card("Hand %d" % i), 0)
	state.players[1].active_pokemon = _make_slot(_make_pokemon_card("Target", "TEST", "920", "C", "Basic", 180), 1)

	var trigger := _first_rule(evaluator.call("find_ready_triggers", state), "cynthias_garchomp_spiral_draw_ready")
	var checks: Array[String] = [
		assert_false(trigger.is_empty(), "Spiral Dive should cue when active Garchomp can attack and refill a four-card hand to six"),
		assert_eq(str(trigger.get("slot_kind", "")), "active", "Spiral Dive draw cue should belong to active Garchomp"),
	]

	_add_card_to_zone(state.players[0].hand, _make_trainer_card("Fifth Hand"), 0)
	checks.append(assert_false(_has_rule(evaluator.call("find_ready_triggers", state), "cynthias_garchomp_spiral_draw_ready"), "A five-card hand should not spend the cinematic cue on only one draw"))
	state.players[0].hand.resize(4)
	garchomp_slot.attached_energy.clear()
	checks.append(assert_false(_has_rule(evaluator.call("find_ready_triggers", state), "cynthias_garchomp_spiral_draw_ready"), "Spiral Dive should not cue before Fighting Energy is paid"))
	_attach_energy(garchomp_slot, 0, "F", 1)
	state.players[0].active_pokemon = null
	state.players[0].bench.append(garchomp_slot)
	checks.append(assert_false(_has_rule(evaluator.call("find_ready_triggers", state), "cynthias_garchomp_spiral_draw_ready"), "Bench Garchomp should not cue until it reaches the Active Spot"))
	return run_checks(checks)


func test_ethans_typhlosion_partner_blast_ready_asset_is_body_first() -> String:
	var registry: RefCounted = BattleReadyVfxRegistryScript.new()
	var profile: RefCounted = registry.call("get_profile", "ethans_typhlosion_partner_blast_lethal_ready")
	var asset_specs: Dictionary = profile.get("asset_specs") if profile != null else {}
	var burst: Dictionary = asset_specs.get("burst", {})
	var path := str(burst.get("path", ""))
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	var metrics := _ready_sheet_pixel_metrics(image)
	return run_checks([
		assert_not_null(profile, "Ethan's Typhlosion ready profile should be registered"),
		assert_eq(str(profile.get("profile_id")) if profile != null else "", "ready_ethans_typhlosion_partner_blast_lethal", "Typhlosion profile id should describe the Partner Blast lethal line"),
		assert_eq(path, "res://assets/textures/vfx/ready_ethans_typhlosion_partner_blast_lethal/sheet-transparent.png", "Typhlosion ready profile should use its generated body sheet"),
		assert_eq(image.get_size() if image != null else Vector2i.ZERO, Vector2i(768, 512), "Typhlosion ready sheet should be a 2x3 256px grid"),
		assert_gte(int(metrics.get("opaque", 0)), 30000, "Typhlosion sheet should contain substantial full-body art"),
		assert_gte(int(metrics.get("yellow_orange", 0)), 900, "Typhlosion sheet should preserve its yellow body and flame collar"),
		assert_gte(int(metrics.get("black", 0)), 500, "Typhlosion sheet should preserve its dark back silhouette"),
		assert_eq(int(metrics.get("edge_alpha", 0)), 0, "Typhlosion animation must stay inside every frame"),
	])


func test_ethans_typhlosion_partner_blast_ready_tracks_discard_lethal_math() -> String:
	var evaluator: RefCounted = BattleReadyVfxEvaluatorScript.new()
	var state := _make_state(0, 5)
	var typhlosion := _make_pokemon_card(
		"阿响的火暴兽", "CSV10C", "030", "R", "Stage 2", 170, "",
		[_attack("R", "40+", "搭档爆破"), _attack("RRC", "160", "爆热炮")], "Ethan's Typhlosion"
	)
	var typhlosion_slot := _make_slot(typhlosion, 0)
	_attach_energy(typhlosion_slot, 0, "R", 1)
	state.players[0].active_pokemon = typhlosion_slot
	_add_card_to_zone(state.players[0].discard_pile, _make_trainer_card("阿响的冒险", "Supporter"), 0)
	_add_card_to_zone(state.players[0].discard_pile, _make_trainer_card("阿响的冒险", "Supporter"), 0)
	state.players[1].active_pokemon = _make_slot(_make_pokemon_card("Target 160", "TEST", "930", "C", "Basic", 160), 1)

	var trigger := _first_rule(evaluator.call("find_ready_triggers", state), "ethans_typhlosion_partner_blast_lethal_ready")
	var checks: Array[String] = [
		assert_false(trigger.is_empty(), "Partner Blast should cue when two discarded Adventures make 160 lethal"),
		assert_eq(str(trigger.get("slot_kind", "")), "active", "Partner Blast lethal cue should belong to active Typhlosion"),
	]

	state.players[1].active_pokemon = _make_slot(_make_pokemon_card("Target 170", "TEST", "931", "C", "Basic", 170), 1)
	checks.append(assert_false(_has_rule(evaluator.call("find_ready_triggers", state), "ethans_typhlosion_partner_blast_lethal_ready"), "Two Adventures must not cue against 170 remaining HP"))
	_add_card_to_zone(state.players[0].discard_pile, _make_trainer_card("阿响的冒险", "Supporter"), 0)
	checks.append(assert_true(_has_rule(evaluator.call("find_ready_triggers", state), "ethans_typhlosion_partner_blast_lethal_ready"), "A third Adventure should raise Partner Blast to 220 and complete the lethal line"))
	typhlosion_slot.attached_energy.clear()
	checks.append(assert_false(_has_rule(evaluator.call("find_ready_triggers", state), "ethans_typhlosion_partner_blast_lethal_ready"), "Discard math alone must not cue before Fire Energy is paid"))
	return run_checks(checks)


func test_blaziken_boiling_spirit_ready_asset_is_body_first() -> String:
	var registry: RefCounted = BattleReadyVfxRegistryScript.new()
	var profile: RefCounted = registry.call("get_profile", "blaziken_boiling_spirit_acceleration_ready")
	var asset_specs: Dictionary = profile.get("asset_specs") if profile != null else {}
	var burst: Dictionary = asset_specs.get("burst", {})
	var path := str(burst.get("path", ""))
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	var metrics := _ready_sheet_pixel_metrics(image)
	return run_checks([
		assert_not_null(profile, "Blaziken ready profile should be registered"),
		assert_eq(str(profile.get("profile_id")) if profile != null else "", "ready_blaziken_boiling_spirit_acceleration", "Blaziken profile id should describe Boiling Spirit acceleration"),
		assert_eq(path, "res://assets/textures/vfx/ready_blaziken_boiling_spirit_acceleration/sheet-transparent.png", "Blaziken ready profile should use its generated body sheet"),
		assert_eq(image.get_size() if image != null else Vector2i.ZERO, Vector2i(768, 512), "Blaziken ready sheet should be a 2x3 256px grid"),
		assert_gte(int(metrics.get("opaque", 0)), 30000, "Blaziken sheet should contain substantial full-body art"),
		assert_gte(int(metrics.get("yellow_orange", 0)), 700, "Blaziken sheet should preserve its red-and-gold fire accents"),
		assert_gte(int(metrics.get("white", 0)), 500, "Blaziken sheet should preserve its bright feather silhouette"),
		assert_eq(int(metrics.get("edge_alpha", 0)), 0, "Blaziken animation must stay inside every frame"),
	])


func test_blaziken_boiling_spirit_ready_requires_resolved_acceleration() -> String:
	var evaluator: RefCounted = BattleReadyVfxEvaluatorScript.new()
	var state := _make_state(0, 4)
	var blaziken := _make_pokemon_card(
		"火焰鸡ex", "CSV7C", "038", "R", "Stage 2", 320, "ex",
		[_attack("RC", "200", "燃烧旋踢")], "Blaziken ex"
	)
	var blaziken_slot := _make_slot(blaziken, 0)
	blaziken_slot.mark_ability_used(state.turn_number)
	state.players[0].bench.append(blaziken_slot)
	var torchic_slot := _make_slot(_make_pokemon_card("火稚鸡", "CSV10C", "036", "R", "Basic", 60, "", [], "Torchic"), 0)
	_attach_energy(torchic_slot, 0, "R", 1)
	state.players[0].bench.append(torchic_slot)

	var trigger := _first_rule(evaluator.call("find_ready_triggers", state), "blaziken_boiling_spirit_acceleration_ready")
	var checks: Array[String] = [
		assert_false(trigger.is_empty(), "Boiling Spirit should cue after the ability resolves and puts a basic Energy onto the board"),
		assert_eq(str(trigger.get("required_action_kind", "")), "use_ability", "Boiling Spirit cue should be sourced from the resolved ability action"),
		assert_eq(str(trigger.get("slot_kind", "")), "bench", "Boiling Spirit cue should stay anchored to Blaziken"),
	]

	blaziken_slot.effects.clear()
	checks.append(assert_false(_has_rule(evaluator.call("find_ready_triggers", state), "blaziken_boiling_spirit_acceleration_ready"), "A board with Energy must not cue before Boiling Spirit resolves"))
	blaziken_slot.mark_ability_used(state.turn_number - 1)
	checks.append(assert_false(_has_rule(evaluator.call("find_ready_triggers", state), "blaziken_boiling_spirit_acceleration_ready"), "Boiling Spirit from an earlier turn must not cue"))
	blaziken_slot.effects.clear()
	blaziken_slot.mark_ability_used(state.turn_number)
	torchic_slot.attached_energy.clear()
	checks.append(assert_false(_has_rule(evaluator.call("find_ready_triggers", state), "blaziken_boiling_spirit_acceleration_ready"), "Boiling Spirit should not cue unless a basic Energy is present after resolution"))
	return run_checks(checks)


func test_pidgeot_quick_search_ready_asset_is_body_first() -> String:
	var registry: RefCounted = BattleReadyVfxRegistryScript.new()
	var profile: RefCounted = registry.call("get_profile", "pidgeot_quick_search_control_ready")
	var asset_specs: Dictionary = profile.get("asset_specs") if profile != null else {}
	var burst: Dictionary = asset_specs.get("burst", {})
	var path := str(burst.get("path", ""))
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	var metrics := _ready_sheet_pixel_metrics(image)
	return run_checks([
		assert_not_null(profile, "Pidgeot ready profile should be registered"),
		assert_eq(str(profile.get("profile_id")) if profile != null else "", "ready_pidgeot_quick_search_control", "Pidgeot profile id should describe the resolved control tutor"),
		assert_eq(path, "res://assets/textures/vfx/ready_pidgeot_quick_search_control/sheet-transparent.png", "Pidgeot ready profile should use its generated body sheet"),
		assert_eq(image.get_size() if image != null else Vector2i.ZERO, Vector2i(768, 512), "Pidgeot ready sheet should be a 2x3 256px grid"),
		assert_gte(int(metrics.get("opaque", 0)), 30000, "Pidgeot sheet should contain substantial full-body art"),
		assert_gte(int(metrics.get("white", 0)), 900, "Pidgeot sheet should preserve its bright wing silhouette"),
		assert_gte(int(metrics.get("yellow_orange", 0)), 400, "Pidgeot sheet should preserve its gold crest and search cue"),
		assert_eq(int(metrics.get("edge_alpha", 0)), 0, "Pidgeot animation must stay inside every frame"),
	])


func test_pidgeot_quick_search_ready_requires_resolved_tutor() -> String:
	var evaluator: RefCounted = BattleReadyVfxEvaluatorScript.new()
	var state := _make_state(0, 5)
	var pidgeot := _make_pokemon_card(
		"大比鸟ex", "CSV4C", "101", "C", "Stage 2", 280, "ex",
		[_attack("CC", "120", "狂风呼啸")], "Pidgeot ex"
	)
	var pidgeot_slot := _make_slot(pidgeot, 0)
	pidgeot_slot.effects.append({"type": "ability_search_any_used", "turn": state.turn_number})
	state.players[0].bench.append(pidgeot_slot)

	var trigger := _first_rule(evaluator.call("find_ready_triggers", state), "pidgeot_quick_search_control_ready")
	var checks: Array[String] = [
		assert_false(trigger.is_empty(), "Quick Search should cue after Pidgeot resolves the exact-card tutor"),
		assert_eq(str(trigger.get("required_action_kind", "")), "use_ability", "Quick Search cue should be sourced from the resolved ability action"),
		assert_eq(str(trigger.get("slot_kind", "")), "bench", "Quick Search cue should stay anchored to Pidgeot"),
	]

	pidgeot_slot.effects.clear()
	checks.append(assert_false(_has_rule(evaluator.call("find_ready_triggers", state), "pidgeot_quick_search_control_ready"), "Pidgeot must not cue merely for being in play"))
	pidgeot_slot.effects.append({"type": "ability_search_any_used", "turn": state.turn_number - 1})
	checks.append(assert_false(_has_rule(evaluator.call("find_ready_triggers", state), "pidgeot_quick_search_control_ready"), "Quick Search from an earlier turn must not cue"))
	return run_checks(checks)


func test_flareon_burning_charge_ready_asset_is_body_first() -> String:
	var registry: RefCounted = BattleReadyVfxRegistryScript.new()
	var profile: RefCounted = registry.call("get_profile", "flareon_burning_charge_engine_ready")
	var asset_specs: Dictionary = profile.get("asset_specs") if profile != null else {}
	var burst: Dictionary = asset_specs.get("burst", {})
	var path := str(burst.get("path", ""))
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	var metrics := _ready_sheet_pixel_metrics(image)
	return run_checks([
		assert_not_null(profile, "Flareon ready profile should be registered"),
		assert_eq(str(profile.get("profile_id")) if profile != null else "", "ready_flareon_burning_charge_engine", "Flareon profile id should describe its Burning Charge engine"),
		assert_eq(path, "res://assets/textures/vfx/ready_flareon_burning_charge_engine/sheet-transparent.png", "Flareon ready profile should use its generated body sheet"),
		assert_eq(image.get_size() if image != null else Vector2i.ZERO, Vector2i(768, 512), "Flareon ready sheet should be a 2x3 256px grid"),
		assert_gte(int(metrics.get("opaque", 0)), 30000, "Flareon sheet should contain substantial full-body art"),
		assert_gte(int(metrics.get("yellow_orange", 0)), 1200, "Flareon sheet should preserve its orange body and charging flame"),
		assert_gte(int(metrics.get("white", 0)), 700, "Flareon sheet should preserve its pale mane and tail silhouette"),
		assert_eq(int(metrics.get("edge_alpha", 0)), 0, "Flareon animation must stay inside every frame"),
	])


func test_flareon_burning_charge_ready_requires_full_acceleration_value() -> String:
	var evaluator: RefCounted = BattleReadyVfxEvaluatorScript.new()
	var state := _make_state(0, 4)
	var flareon := _make_pokemon_card(
		"火伊布ex", "CSV9.5C", "023", "R", "Stage 1", 270, "ex",
		[_attack("RC", "130", "燃烧充能"), _attack("RWL", "280", "红玉髓")], "Flareon ex"
	)
	var flareon_slot := _make_slot(flareon, 0)
	_attach_energy(flareon_slot, 0, "R", 1)
	_attach_energy(flareon_slot, 0, "C", 1)
	state.players[0].active_pokemon = flareon_slot
	state.players[0].bench.append(_make_slot(_make_pokemon_card("伊布", "TEST", "940", "C", "Basic", 60, "", [], "Eevee"), 0))
	_add_card_to_zone(state.players[0].deck, _make_energy_card("Fire Energy", "R"), 0)
	_add_card_to_zone(state.players[0].deck, _make_energy_card("Water Energy", "W"), 0)
	state.players[1].active_pokemon = _make_slot(_make_pokemon_card("Target", "TEST", "941", "C", "Basic", 180), 1)

	var trigger := _first_rule(evaluator.call("find_ready_triggers", state), "flareon_burning_charge_engine_ready")
	var checks: Array[String] = [
		assert_false(trigger.is_empty(), "Burning Charge should cue when RC is paid and two basic Energy can accelerate to the Bench"),
		assert_eq(str(trigger.get("slot_kind", "")), "active", "Burning Charge cue should belong to active Flareon"),
	]

	state.players[0].deck.resize(1)
	checks.append(assert_false(_has_rule(evaluator.call("find_ready_triggers", state), "flareon_burning_charge_engine_ready"), "Burning Charge should not spend the cinematic cue on only one remaining basic Energy"))
	_add_card_to_zone(state.players[0].deck, _make_energy_card("Lightning Energy", "L"), 0)
	state.players[0].bench.clear()
	checks.append(assert_false(_has_rule(evaluator.call("find_ready_triggers", state), "flareon_burning_charge_engine_ready"), "Burning Charge should not cue without a Benched engine target"))
	state.players[0].bench.append(_make_slot(_make_pokemon_card("伊布", "TEST", "942", "C", "Basic", 60, "", [], "Eevee"), 0))
	flareon_slot.attached_energy.resize(1)
	checks.append(assert_false(_has_rule(evaluator.call("find_ready_triggers", state), "flareon_burning_charge_engine_ready"), "Burning Charge must not cue before both Fire and Colorless costs are paid"))
	return run_checks(checks)


func test_hops_zacian_brave_blade_ready_asset_is_body_first() -> String:
	var registry: RefCounted = BattleReadyVfxRegistryScript.new()
	var profile: RefCounted = registry.call("get_profile", "hops_zacian_brave_blade_lethal_ready")
	var asset_specs: Dictionary = profile.get("asset_specs") if profile != null else {}
	var burst: Dictionary = asset_specs.get("burst", {})
	var path := str(burst.get("path", ""))
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	var metrics := _ready_sheet_pixel_metrics(image)
	return run_checks([
		assert_not_null(profile, "Hop's Zacian ready profile should be registered"),
		assert_eq(str(profile.get("profile_id")) if profile != null else "", "ready_hops_zacian_brave_blade_lethal", "Zacian profile id should describe its Brave Blade lethal line"),
		assert_eq(path, "res://assets/textures/vfx/ready_hops_zacian_brave_blade_lethal/sheet-transparent.png", "Zacian ready profile should use its generated body sheet"),
		assert_eq(image.get_size() if image != null else Vector2i.ZERO, Vector2i(768, 512), "Zacian ready sheet should be a 2x3 256px grid"),
		assert_gte(int(metrics.get("opaque", 0)), 30000, "Zacian sheet should contain substantial full-body art"),
		assert_gte(int(metrics.get("white", 0)), 700, "Zacian sheet should preserve its bright blade and armor highlights"),
		assert_gte(int(metrics.get("yellow_orange", 0)), 500, "Zacian sheet should preserve its gold armor accents"),
		assert_eq(int(metrics.get("edge_alpha", 0)), 0, "Zacian animation must stay inside every frame"),
	])


func test_hops_zacian_brave_blade_ready_requires_legal_lethal_line() -> String:
	var evaluator: RefCounted = BattleReadyVfxEvaluatorScript.new()
	var state := _make_state(0, 5)
	var zacian := _make_pokemon_card(
		"赫普的苍响ex", "CSV10C", "161", "M", "Basic", 230, "ex",
		[_attack("C", "30", "刹那斩"), _attack("MMMC", "240", "英勇之刃")], "Hop's Zacian ex"
	)
	var zacian_slot := _make_slot(zacian, 0)
	_attach_energy(zacian_slot, 0, "M", 3)
	_attach_energy(zacian_slot, 0, "C", 1)
	state.players[0].active_pokemon = zacian_slot
	state.players[1].active_pokemon = _make_slot(_make_pokemon_card("Target 240", "TEST", "950", "C", "Basic", 240), 1)

	var trigger := _first_rule(evaluator.call("find_ready_triggers", state), "hops_zacian_brave_blade_lethal_ready")
	var checks: Array[String] = [
		assert_false(trigger.is_empty(), "Brave Blade should cue when its full cost is paid and 240 damage is lethal"),
		assert_eq(str(trigger.get("slot_kind", "")), "active", "Brave Blade lethal cue should belong to active Zacian"),
	]

	state.players[1].active_pokemon = _make_slot(_make_pokemon_card("Target 250", "TEST", "951", "C", "Basic", 250), 1)
	checks.append(assert_false(_has_rule(evaluator.call("find_ready_triggers", state), "hops_zacian_brave_blade_lethal_ready"), "Base Brave Blade must not cue above 240 remaining HP"))
	state.players[1].active_pokemon = _make_slot(_make_pokemon_card("Target 240", "TEST", "952", "C", "Basic", 240), 1)
	zacian_slot.effects.append({"type": "attack_lock", "attack_name": "英勇之刃", "attack_index": 1, "turn": state.turn_number - 2})
	checks.append(assert_false(_has_rule(evaluator.call("find_ready_triggers", state), "hops_zacian_brave_blade_lethal_ready"), "Brave Blade must not cue while its next-turn lock is active"))
	zacian_slot.effects.clear()
	zacian_slot.attached_energy.resize(3)
	checks.append(assert_false(_has_rule(evaluator.call("find_ready_triggers", state), "hops_zacian_brave_blade_lethal_ready"), "Three Metal Energy alone must not pay the printed Colorless cost"))
	var band := _make_trainer_card("赫普的讲究头带", "Tool", "CSV10C", "201", "87bf196475e64140c14197af70648893")
	zacian_slot.attached_tool = CardInstance.create(band, 0)
	checks.append(assert_true(_has_rule(evaluator.call("find_ready_triggers", state), "hops_zacian_brave_blade_lethal_ready"), "Hop's Choice Band should remove the Colorless cost and restore the legal lethal line"))
	return run_checks(checks)


func test_yanmega_buzzing_rush_ready_asset_is_body_first() -> String:
	var registry: RefCounted = BattleReadyVfxRegistryScript.new()
	var profile: RefCounted = registry.call("get_profile", "yanmega_buzzing_rush_acceleration_ready")
	var asset_specs: Dictionary = profile.get("asset_specs") if profile != null else {}
	var burst: Dictionary = asset_specs.get("burst", {})
	var path := str(burst.get("path", ""))
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	var metrics := _ready_sheet_pixel_metrics(image)
	return run_checks([
		assert_not_null(profile, "Yanmega ready profile should be registered"),
		assert_eq(str(profile.get("profile_id")) if profile != null else "", "ready_yanmega_buzzing_rush_acceleration", "Yanmega profile id should describe its Buzzing Rush acceleration"),
		assert_eq(path, "res://assets/textures/vfx/ready_yanmega_buzzing_rush_acceleration/sheet-transparent.png", "Yanmega ready profile should use its generated body sheet"),
		assert_eq(image.get_size() if image != null else Vector2i.ZERO, Vector2i(768, 512), "Yanmega ready sheet should be a 2x3 256px grid"),
		assert_gte(int(metrics.get("opaque", 0)), 30000, "Yanmega sheet should contain substantial full-body art"),
		assert_gte(int(metrics.get("green", 0)), 800, "Yanmega sheet should preserve its green body and Grass Energy cue"),
		assert_gte(int(metrics.get("yellow_orange", 0)), 300, "Yanmega sheet should preserve its warm eye and wing accents"),
		assert_eq(int(metrics.get("edge_alpha", 0)), 0, "Yanmega animation must stay inside every frame"),
	])


func test_yanmega_buzzing_rush_ready_requires_resolved_three_grass_entry() -> String:
	var evaluator: RefCounted = BattleReadyVfxEvaluatorScript.new()
	var state := _make_state(0, 4)
	var yanmega := _make_pokemon_card(
		"远古巨蜓ex", "CSV10C", "003", "G", "Stage 1", 280, "ex",
		[_attack("GGG", "210", "喷射旋风")], "Yanmega ex"
	)
	var yanmega_slot := _make_slot(yanmega, 0)
	yanmega_slot.effects.append({"type": "ability_attach_from_deck_used", "turn": state.turn_number})
	_attach_energy(yanmega_slot, 0, "G", 3)
	state.players[0].active_pokemon = yanmega_slot

	var trigger := _first_rule(evaluator.call("find_ready_triggers", state), "yanmega_buzzing_rush_acceleration_ready")
	var checks: Array[String] = [
		assert_false(trigger.is_empty(), "Buzzing Rush should cue after Active Yanmega resolves three Grass Energy from the deck"),
		assert_eq(str(trigger.get("required_action_kind", "")), "use_ability", "Buzzing Rush cue should be sourced from the resolved ability action"),
		assert_eq(str(trigger.get("slot_kind", "")), "active", "Buzzing Rush cue should belong to Active Yanmega"),
	]

	yanmega_slot.effects.clear()
	checks.append(assert_false(_has_rule(evaluator.call("find_ready_triggers", state), "yanmega_buzzing_rush_acceleration_ready"), "Three Grass Energy alone must not cue without Buzzing Rush resolving this turn"))
	yanmega_slot.effects.append({"type": "ability_attach_from_deck_used", "turn": state.turn_number})
	yanmega_slot.attached_energy.resize(2)
	checks.append(assert_false(_has_rule(evaluator.call("find_ready_triggers", state), "yanmega_buzzing_rush_acceleration_ready"), "Buzzing Rush should not cue when fewer than three basic Grass Energy were established"))
	_attach_energy(yanmega_slot, 0, "G", 1)
	state.players[0].active_pokemon = null
	state.players[0].bench.append(yanmega_slot)
	checks.append(assert_false(_has_rule(evaluator.call("find_ready_triggers", state), "yanmega_buzzing_rush_acceleration_ready"), "Buzzing Rush should not cue after Yanmega has left the Active Spot"))
	return run_checks(checks)


func test_munkidori_adrena_brain_ready_asset_is_body_first() -> String:
	var registry: RefCounted = BattleReadyVfxRegistryScript.new()
	var profile: RefCounted = registry.call("get_profile", "munkidori_adrena_brain_transfer_ready")
	var asset_specs: Dictionary = profile.get("asset_specs") if profile != null else {}
	var burst: Dictionary = asset_specs.get("burst", {})
	var path := str(burst.get("path", ""))
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	var metrics := _ready_sheet_pixel_metrics(image)
	return run_checks([
		assert_not_null(profile, "Munkidori ready profile should be registered"),
		assert_eq(str(profile.get("profile_id")) if profile != null else "", "ready_munkidori_adrena_brain_transfer", "Munkidori profile id should describe its Adrena-Brain transfer window"),
		assert_eq(path, "res://assets/textures/vfx/ready_munkidori_adrena_brain_transfer/sheet-transparent.png", "Munkidori ready profile should use its generated body sheet"),
		assert_eq(image.get_size() if image != null else Vector2i.ZERO, Vector2i(768, 512), "Munkidori ready sheet should be a 2x3 256px grid"),
		assert_gte(int(metrics.get("opaque", 0)), 30000, "Munkidori sheet should contain substantial full-body art"),
		assert_gte(int(metrics.get("green", 0)), 350, "Munkidori sheet should preserve its green head accent"),
		assert_gte(int(metrics.get("black", 0)), 700, "Munkidori sheet should preserve its dark psychic silhouette"),
		assert_eq(int(metrics.get("edge_alpha", 0)), 0, "Munkidori animation must stay inside every frame"),
	])


func test_munkidori_adrena_brain_ready_requires_live_transfer_window() -> String:
	var evaluator: RefCounted = BattleReadyVfxEvaluatorScript.new()
	var state := _make_state(0, 4)
	var munkidori := _make_pokemon_card(
		"愿增猿", "CSV8C", "094", "P", "Basic", 110, "",
		[_attack("PC", "60", "精神幻觉")], "Munkidori"
	)
	var munkidori_slot := _make_slot(munkidori, 0)
	_attach_energy(munkidori_slot, 0, "D", 1)
	state.players[0].bench.append(munkidori_slot)
	var damaged_ally := _make_slot(_make_pokemon_card("Damaged Ally", "TEST", "960", "C", "Basic", 120), 0)
	damaged_ally.damage_counters = 30
	state.players[0].active_pokemon = damaged_ally
	state.players[1].active_pokemon = _make_slot(_make_pokemon_card("Opponent", "TEST", "961", "C", "Basic", 180), 1)

	var trigger := _first_rule(evaluator.call("find_ready_triggers", state), "munkidori_adrena_brain_transfer_ready")
	var checks: Array[String] = [
		assert_false(trigger.is_empty(), "Adrena-Brain should cue when Darkness Energy, own damage, and an opponent target form a live transfer window"),
		assert_eq(str(trigger.get("slot_kind", "")), "bench", "Adrena-Brain cue should stay anchored to Munkidori"),
	]

	munkidori_slot.attached_energy.clear()
	checks.append(assert_false(_has_rule(evaluator.call("find_ready_triggers", state), "munkidori_adrena_brain_transfer_ready"), "Adrena-Brain must not cue before Munkidori has Darkness Energy"))
	_attach_energy(munkidori_slot, 0, "D", 1)
	damaged_ally.damage_counters = 0
	checks.append(assert_false(_has_rule(evaluator.call("find_ready_triggers", state), "munkidori_adrena_brain_transfer_ready"), "Adrena-Brain must not cue without own damage counters to move"))
	damaged_ally.damage_counters = 30
	munkidori_slot.effects.append({"type": "ability_move_counters_to_opp_used", "turn": state.turn_number})
	checks.append(assert_false(_has_rule(evaluator.call("find_ready_triggers", state), "munkidori_adrena_brain_transfer_ready"), "Adrena-Brain must not cue after this copy already moved counters this turn"))
	munkidori_slot.effects.clear()
	state.players[1].active_pokemon = null
	checks.append(assert_false(_has_rule(evaluator.call("find_ready_triggers", state), "munkidori_adrena_brain_transfer_ready"), "Adrena-Brain must not cue without an opponent target"))
	return run_checks(checks)


func test_toedscruel_colony_rush_ready_asset_is_body_first() -> String:
	var registry: RefCounted = BattleReadyVfxRegistryScript.new()
	var profile: RefCounted = registry.call("get_profile", "toedscruel_colony_rush_lethal_ready")
	var asset_specs: Dictionary = profile.get("asset_specs") if profile != null else {}
	var burst: Dictionary = asset_specs.get("burst", {})
	var path := str(burst.get("path", ""))
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	var metrics := _ready_sheet_pixel_metrics(image)
	return run_checks([
		assert_not_null(profile, "Toedscruel ready profile should be registered"),
		assert_eq(str(profile.get("profile_id")) if profile != null else "", "ready_toedscruel_colony_rush_lethal", "Toedscruel profile id should describe its Colony Rush lethal line"),
		assert_eq(path, "res://assets/textures/vfx/ready_toedscruel_colony_rush_lethal/sheet-transparent.png", "Toedscruel ready profile should use its generated body sheet"),
		assert_eq(image.get_size() if image != null else Vector2i.ZERO, Vector2i(768, 512), "Toedscruel ready sheet should be a 2x3 256px grid"),
		assert_gte(int(metrics.get("opaque", 0)), 30000, "Toedscruel sheet should contain substantial full-body art"),
		assert_gte(int(metrics.get("green", 0)), 900, "Toedscruel sheet should preserve its green fungal body and colony nodes"),
		assert_gte(int(metrics.get("white", 0)), 500, "Toedscruel sheet should preserve its pale tentacle and mushroom highlights"),
		assert_eq(int(metrics.get("edge_alpha", 0)), 0, "Toedscruel animation must stay inside every frame"),
	])


func test_toedscruel_colony_rush_ready_tracks_energized_bench_lethal_math() -> String:
	var evaluator: RefCounted = BattleReadyVfxEvaluatorScript.new()
	var state := _make_state(0, 4)
	var toedscruel := _make_pokemon_card(
		"陆地水母ex", "CSV5C", "010", "G", "Stage 1", 270, "ex",
		[_attack("GG", "80+", "聚落突进")], "Toedscruel ex"
	)
	var toedscruel_slot := _make_slot(toedscruel, 0)
	_attach_energy(toedscruel_slot, 0, "G", 2)
	state.players[0].active_pokemon = toedscruel_slot
	for i: int in 3:
		var bench_slot := _make_slot(_make_pokemon_card("Grass Bench %d" % i, "TEST", "97%d" % i, "G", "Basic", 120), 0)
		_attach_energy(bench_slot, 0, "G", 1)
		state.players[0].bench.append(bench_slot)
	state.players[1].active_pokemon = _make_slot(_make_pokemon_card("Target 200", "TEST", "980", "C", "Basic", 200), 1)

	var trigger := _first_rule(evaluator.call("find_ready_triggers", state), "toedscruel_colony_rush_lethal_ready")
	var checks: Array[String] = [
		assert_false(trigger.is_empty(), "Colony Rush should cue when three energized Bench Pokemon raise damage to exactly 200"),
		assert_eq(str(trigger.get("slot_kind", "")), "active", "Colony Rush lethal cue should belong to active Toedscruel"),
	]

	state.players[0].bench[2].attached_energy.clear()
	checks.append(assert_false(_has_rule(evaluator.call("find_ready_triggers", state), "toedscruel_colony_rush_lethal_ready"), "Two energized Bench Pokemon only reach 160 and must not cue against 200 HP"))
	_attach_energy(state.players[0].bench[2], 0, "G", 1)
	toedscruel_slot.attached_energy.resize(1)
	checks.append(assert_false(_has_rule(evaluator.call("find_ready_triggers", state), "toedscruel_colony_rush_lethal_ready"), "Colony size must not cue before Toedscruel pays both Grass costs"))
	_attach_energy(toedscruel_slot, 0, "G", 1)
	state.players[1].active_pokemon = _make_slot(_make_pokemon_card("Target 210", "TEST", "981", "C", "Basic", 210), 1)
	checks.append(assert_false(_has_rule(evaluator.call("find_ready_triggers", state), "toedscruel_colony_rush_lethal_ready"), "Three energized Bench Pokemon must not cue above their 200 damage line"))
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


func test_squawkabilly_first_turn_draw_ready_triggers_after_ability_used() -> String:
	var evaluator: RefCounted = BattleReadyVfxEvaluatorScript.new()

	var bench_state := _make_state(0, 4, GameState.GamePhase.MAIN)
	var bench_squawk := _make_slot(_make_pokemon_card("Squawkabilly ex", "CSV2C", "105", "C", "Basic", 160, "ex", [], "Squawkabilly ex"), 0)
	_mark_squawkabilly_first_turn_draw_used(bench_squawk, bench_state.turn_number)
	bench_state.players[0].bench.append(bench_squawk)
	var bench_triggers: Array = evaluator.call("find_ready_triggers", bench_state)
	var bench_trigger := _first_rule(bench_triggers, "squawkabilly_first_turn_draw_ready")

	var active_state := _make_state(0, 1, GameState.GamePhase.MAIN)
	var active_squawk := _make_slot(_make_pokemon_card("Squawkabilly ex", "CSV2C", "105", "C", "Basic", 160, "ex", [], "Squawkabilly ex"), 0)
	_mark_squawkabilly_first_turn_draw_used(active_squawk, active_state.turn_number)
	active_state.players[0].active_pokemon = active_squawk
	var active_triggers: Array = evaluator.call("find_ready_triggers", active_state)

	var second_player_state := _make_state(1, 2, GameState.GamePhase.MAIN)
	var second_player_squawk := _make_slot(_make_pokemon_card("Squawkabilly ex", "CSV2C", "105", "C", "Basic", 160, "ex", [], "Squawkabilly ex"), 1)
	_mark_squawkabilly_first_turn_draw_used(second_player_squawk, second_player_state.turn_number)
	second_player_state.players[1].bench.append(second_player_squawk)
	var second_player_triggers: Array = evaluator.call("find_ready_triggers", second_player_state)

	return run_checks([
		assert_eq(str(bench_trigger.get("rule_id", "")), "squawkabilly_first_turn_draw_ready", "Benched Squawkabilly ex should trigger after Squawk and Seize resolves"),
		assert_eq(str(bench_trigger.get("slot_kind", "")), "bench", "Benched Squawkabilly ready should target the Bench slot"),
		assert_eq(int(bench_trigger.get("slot_index", -99)), 0, "Benched Squawkabilly ready should report the bench index"),
		assert_eq(str(bench_trigger.get("reason", "")), "squawk_and_seize_resolved", "Squawkabilly ready trigger should document the resolved ability"),
		assert_eq(str(bench_trigger.get("required_action_kind", "")), "use_ability", "Squawkabilly ready VFX should only play for the ability action that resolved Squawk and Seize"),
		assert_true(_has_rule(active_triggers, "squawkabilly_first_turn_draw_ready"), "Active Squawkabilly ex should also trigger after the Ability resolves"),
		assert_true(_has_rule(second_player_triggers, "squawkabilly_first_turn_draw_ready"), "Second player should get Squawkabilly ready VFX after their own Ability resolves"),
	])


func test_squawkabilly_first_turn_draw_ready_negative_gates() -> String:
	var evaluator: RefCounted = BattleReadyVfxEvaluatorScript.new()

	var available_state := _make_state(0, 1, GameState.GamePhase.MAIN)
	available_state.players[0].bench.append(_make_slot(_make_pokemon_card("Squawkabilly ex", "CSV2C", "105", "C", "Basic", 160, "ex", [], "Squawkabilly ex"), 0))
	_add_card_to_zone(available_state.players[0].deck, _make_trainer_card("Draw Target", "Item"), 0)
	var available_triggers: Array = evaluator.call("find_ready_triggers", available_state)

	var wrong_effect_state := _make_state(0, 1, GameState.GamePhase.MAIN)
	var wrong_effect_squawk := _make_slot(_make_pokemon_card("Squawkabilly ex", "CSV2C", "105", "C", "Basic", 160, "ex", [], "Squawkabilly ex"), 0)
	wrong_effect_squawk.effects.append({"type": "some_other_ability_used", "turn": wrong_effect_state.turn_number})
	wrong_effect_state.players[0].bench.append(wrong_effect_squawk)
	var wrong_effect_triggers: Array = evaluator.call("find_ready_triggers", wrong_effect_state)

	var wrong_card_state := _make_state(0, 1, GameState.GamePhase.MAIN)
	var wrong_card := _make_slot(_make_pokemon_card("Wrong Pokemon ex", "TEST", "105", "C", "Basic", 160, "ex", [], "Wrong Pokemon ex"), 0)
	_mark_squawkabilly_first_turn_draw_used(wrong_card, wrong_card_state.turn_number)
	wrong_card_state.players[0].bench.append(wrong_card)
	var wrong_card_triggers: Array = evaluator.call("find_ready_triggers", wrong_card_state)

	var opponent_turn_state := _make_state(1, 1, GameState.GamePhase.MAIN)
	var opponent_squawk := _make_slot(_make_pokemon_card("Squawkabilly ex", "CSV2C", "105", "C", "Basic", 160, "ex", [], "Squawkabilly ex"), 0)
	_mark_squawkabilly_first_turn_draw_used(opponent_squawk, opponent_turn_state.turn_number)
	opponent_turn_state.players[0].bench.append(opponent_squawk)
	var opponent_turn_triggers: Array = evaluator.call("find_ready_triggers", opponent_turn_state)

	var stale_marker_state := _make_state(0, 4, GameState.GamePhase.MAIN)
	var stale_marker_squawk := _make_slot(_make_pokemon_card("Squawkabilly ex", "CSV2C", "105", "C", "Basic", 160, "ex", [], "Squawkabilly ex"), 0)
	_mark_squawkabilly_first_turn_draw_used(stale_marker_squawk, 1)
	stale_marker_state.players[0].bench.append(stale_marker_squawk)
	var stale_marker_triggers: Array = evaluator.call("find_ready_triggers", stale_marker_state)

	return run_checks([
		assert_false(_has_rule(available_triggers, "squawkabilly_first_turn_draw_ready"), "Squawkabilly ready VFX should not preview before Squawk and Seize resolves"),
		assert_false(_has_rule(wrong_effect_triggers, "squawkabilly_first_turn_draw_ready"), "Squawkabilly ready VFX should require the first-turn draw used marker"),
		assert_false(_has_rule(wrong_card_triggers, "squawkabilly_first_turn_draw_ready"), "Squawkabilly ready VFX should only target Squawkabilly ex"),
		assert_false(_has_rule(opponent_turn_triggers, "squawkabilly_first_turn_draw_ready"), "Squawkabilly ready VFX should only evaluate the current player's board"),
		assert_false(_has_rule(stale_marker_triggers, "squawkabilly_first_turn_draw_ready"), "Squawkabilly ready VFX should not replay a prior-turn Squawk and Seize marker"),
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


func test_scene_squawkabilly_ready_vfx_plays_after_redraw_resolves() -> String:
	var gs := _make_state(0, 1, GameState.GamePhase.MAIN)
	var player := gs.players[0]
	var squawk_cd := _make_pokemon_card("Squawkabilly ex", "CSV2C", "105", "C", "Basic", 160, "ex", [], "Squawkabilly ex")
	squawk_cd.effect_id = "ready_test_squawk_first_turn_draw"
	squawk_cd.abilities = [{"name": "Squawk and Seize", "text": ""}]
	var squawk := _make_slot(squawk_cd, 0)
	player.active_pokemon = squawk
	for i: int in 3:
		player.hand.append(CardInstance.create(_make_trainer_card("Old Hand %d" % i, "Item"), 0))
	for i: int in 6:
		player.deck.append(CardInstance.create(_make_trainer_card("New Hand %d" % i, "Item"), 0))
	var battle_scene := _make_scene_stub_with_state(gs)
	var gsm: GameStateMachine = battle_scene.get("_gsm")
	gsm.effect_processor.register_effect(squawk_cd.effect_id, AbilityFirstTurnDraw.new(6))

	battle_scene.call("_try_use_ability_with_interaction", 0, squawk, 0)
	var used := squawk.effects.any(func(e: Dictionary) -> bool: return e.get("type", "") == SQUAWKABILLY_FIRST_TURN_DRAW_USED_KEY)
	var overlay_after_action: Control = battle_scene.get("_ready_vfx_overlay") as Control
	var count_after_action := overlay_after_action.get_child_count() if overlay_after_action != null else 0

	battle_scene.set("_ready_vfx_trigger_source_player_index", 0)
	battle_scene.call("_check_ready_vfx_triggers")

	var overlay: Control = battle_scene.get("_ready_vfx_overlay") as Control
	var sequence_count := overlay.get_child_count() if overlay != null else 0
	var sequence: Control = overlay.get_child(0) as Control if overlay != null and overlay.get_child_count() > 0 else null
	var burst: TextureRect = sequence.get_node_or_null("ReadyVfxBurst") as TextureRect if sequence != null else null
	var burst_filter := burst.mouse_filter if burst != null else Control.MOUSE_FILTER_STOP

	var result := run_checks([
		assert_true(used, "Squawkabilly ex should resolve Squawk and Seize in the test scene"),
		assert_eq(player.hand.size(), 6, "Squawk and Seize should finish with the newly drawn six-card hand before ready VFX checks"),
		assert_true(used, "Squawk and Seize should mark the source slot as used"),
		assert_eq(count_after_action, 1, "Actual Ability UI path should play Squawkabilly ready VFX immediately after redraw"),
		assert_not_null(overlay, "Squawkabilly ready VFX overlay should be created"),
		assert_eq(overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE, "Squawkabilly ready VFX overlay must not intercept input"),
		assert_eq(sequence_count, 1, "Repeated refreshes should not replay the same Squawkabilly ready key"),
		assert_eq(str(sequence.get_meta("rule_id", "")) if sequence != null else "", "squawkabilly_first_turn_draw_ready", "Squawkabilly ready sequence should use the first-turn draw rule"),
		assert_eq(str(sequence.get_meta("profile_id", "")) if sequence != null else "", "ready_squawkabilly_first_turn_draw", "Squawkabilly ready sequence should use the dedicated profile"),
		assert_eq(burst_filter, Control.MOUSE_FILTER_IGNORE, "Squawkabilly ready burst must not block board input"),
	])
	battle_scene.free()
	return result


func test_scene_squawkabilly_ready_vfx_requires_use_ability_action_source() -> String:
	var gs := _make_state(0, 4, GameState.GamePhase.MAIN)
	var player := gs.players[0]
	var squawk := _make_slot(_make_pokemon_card("Squawkabilly ex", "CSV2C", "105", "C", "Basic", 160, "ex", [], "Squawkabilly ex"), 0)
	_mark_squawkabilly_first_turn_draw_used(squawk, 1)
	player.bench.append(squawk)
	player.bench.append(_make_slot(_make_pokemon_card("Other Basic", "TEST", "OB1", "C", "Basic", 70), 0))
	var battle_scene := _make_scene_stub_with_state(gs)

	battle_scene.set("_ready_vfx_trigger_source_player_index", 0)
	battle_scene.set("_ready_vfx_trigger_action_kind", "play_pokemon")
	battle_scene.call("_check_ready_vfx_triggers")
	var overlay_after_play: Control = battle_scene.get("_ready_vfx_overlay") as Control
	var play_count := overlay_after_play.get_child_count() if overlay_after_play != null else 0

	battle_scene.set("_ready_vfx_trigger_source_player_index", 0)
	battle_scene.call("_check_ready_vfx_triggers")
	var overlay_after_blank: Control = battle_scene.get("_ready_vfx_overlay") as Control
	var blank_count := overlay_after_blank.get_child_count() if overlay_after_blank != null else 0

	battle_scene.set("_ready_vfx_trigger_source_player_index", 0)
	battle_scene.set("_ready_vfx_trigger_action_kind", "use_ability")
	battle_scene.call("_check_ready_vfx_triggers")
	var overlay_after_stale_ability: Control = battle_scene.get("_ready_vfx_overlay") as Control
	var stale_ability_count := overlay_after_stale_ability.get_child_count() if overlay_after_stale_ability != null else 0

	var fresh_state := _make_state(0, 4, GameState.GamePhase.MAIN)
	var fresh_squawk := _make_slot(_make_pokemon_card("Squawkabilly ex", "CSV2C", "105", "C", "Basic", 160, "ex", [], "Squawkabilly ex"), 0)
	_mark_squawkabilly_first_turn_draw_used(fresh_squawk, fresh_state.turn_number)
	fresh_state.players[0].bench.append(fresh_squawk)
	var fresh_scene := _make_scene_stub_with_state(fresh_state)
	fresh_scene.set("_ready_vfx_trigger_source_player_index", 0)
	fresh_scene.set("_ready_vfx_trigger_action_kind", "use_ability")
	fresh_scene.call("_check_ready_vfx_triggers")
	var overlay_after_ability: Control = fresh_scene.get("_ready_vfx_overlay") as Control
	var sequence: Control = overlay_after_ability.get_child(0) as Control if overlay_after_ability != null and overlay_after_ability.get_child_count() > 0 else null

	var result := run_checks([
		assert_eq(play_count, 0, "Squawkabilly ready VFX should not replay when a later Pokemon placement refreshes a used marker"),
		assert_eq(blank_count, 0, "Squawkabilly ready VFX should not play when the action source has no ability kind"),
		assert_eq(stale_ability_count, 0, "Squawkabilly ready VFX should not replay an old marker after another later ability action"),
		assert_not_null(sequence, "Squawkabilly ready VFX should still play for the use_ability source"),
		assert_eq(str(sequence.get_meta("rule_id", "")) if sequence != null else "", "squawkabilly_first_turn_draw_ready", "Squawkabilly ready sequence should use its rule after an ability source"),
	])
	battle_scene.free()
	fresh_scene.free()
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


func test_ready_vfx_uses_final_screen_center_under_nested_transforms() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var controller: RefCounted = BattleReadyVfxControllerScript.new()
	var registry: RefCounted = BattleReadyVfxRegistryScript.new()
	var profile: RefCounted = registry.call("get_profile", "charizard_infernal_reign_ready")
	var battle_scene := ReadyGeometryScene.new()
	battle_scene.size = Vector2(980, 620)
	battle_scene.position = Vector2(118, 66)
	battle_scene.rotation_degrees = 6.0
	battle_scene.scale = Vector2(0.88, 1.12)
	var field := Control.new()
	field.position = Vector2(82, 44)
	field.size = Vector2(810, 520)
	field.rotation_degrees = -3.5
	field.scale = Vector2(1.06, 0.92)
	battle_scene.add_child(field)
	var my_active := Control.new()
	my_active.position = Vector2(340, 298)
	my_active.size = Vector2(132, 184)
	field.add_child(my_active)
	tree.root.add_child(battle_scene)
	await tree.process_frame
	var overlay: Control = controller.call("ensure_overlay", battle_scene) as Control
	var target_screen: Vector2 = controller.call("_target_position", battle_scene, my_active)
	controller.call("_play_sequence", battle_scene, overlay, profile, target_screen, {
		"rule_id": "charizard_infernal_reign_ready",
		"ready_key": "geometry-test",
	})
	await tree.process_frame
	var sequence: Control = overlay.get_child(0) as Control if overlay.get_child_count() > 0 else null
	var burst: TextureRect = sequence.get_node_or_null("ReadyVfxBurst") as TextureRect if sequence != null else null
	var offset: Vector2 = sequence.get_meta("ready_vfx_anchor_offset", Vector2.ZERO) if sequence != null else Vector2.ZERO
	var expected_local: Vector2 = controller.call("_overlay_local_position", overlay, target_screen) + offset
	var actual_local := burst.position + burst.size * 0.5 if burst != null else Vector2.ZERO
	var result := assert_true(actual_local.distance_to(expected_local) < 1.0, "Ready VFX must stay centered on the Pokemon under transformed battle canvases")
	battle_scene.queue_free()
	await tree.process_frame
	return result


func test_scene_pidgeot_ready_vfx_only_plays_after_quick_search_action_source() -> String:
	var gs := _make_state(0, 5, GameState.GamePhase.MAIN)
	var pidgeot := _make_slot(_make_pokemon_card(
		"大比鸟ex", "CSV4C", "101", "C", "Stage 2", 280, "ex",
		[_attack("CC", "120", "狂风呼啸")], "Pidgeot ex"
	), 0)
	pidgeot.effects.append({"type": "ability_search_any_used", "turn": gs.turn_number})
	gs.players[0].bench.append(pidgeot)
	var battle_scene := _make_scene_stub_with_state(gs)

	battle_scene.set("_ready_vfx_trigger_source_player_index", 0)
	battle_scene.set("_ready_vfx_trigger_action_kind", "play_trainer")
	battle_scene.call("_check_ready_vfx_triggers")
	var overlay_after_trainer: Control = battle_scene.get("_ready_vfx_overlay") as Control
	var trainer_count := overlay_after_trainer.get_child_count() if overlay_after_trainer != null else 0

	battle_scene.set("_ready_vfx_trigger_source_player_index", 0)
	battle_scene.set("_ready_vfx_trigger_action_kind", "use_ability")
	battle_scene.call("_check_ready_vfx_triggers")
	var overlay_after_ability: Control = battle_scene.get("_ready_vfx_overlay") as Control
	var sequence: Control = overlay_after_ability.get_child(0) as Control if overlay_after_ability != null and overlay_after_ability.get_child_count() > 0 else null

	var result := run_checks([
		assert_eq(trainer_count, 0, "Pidgeot ready VFX should not replay its used marker after a later Trainer action"),
		assert_not_null(sequence, "Pidgeot ready VFX should play for the resolved Quick Search ability source"),
		assert_eq(str(sequence.get_meta("rule_id", "")) if sequence != null else "", "pidgeot_quick_search_control_ready", "Pidgeot scene sequence should use the Quick Search rule"),
		assert_eq(str(sequence.get_meta("profile_id", "")) if sequence != null else "", "ready_pidgeot_quick_search_control", "Pidgeot scene sequence should use its dedicated body profile"),
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
