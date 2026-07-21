class_name TestBattleEffectsSetting
extends TestBase

const AttackVfxControllerScript := preload("res://scripts/ui/battle/BattleAttackVfxController.gd")
const ReadyVfxControllerScript := preload("res://scripts/ui/battle/BattleReadyVfxController.gd")
const FieldSwapAnimatorScript := preload("res://scripts/ui/battle/BattleFieldSwapAnimator.gd")
const DrawRevealControllerScript := preload("res://scripts/ui/battle/BattleDrawRevealController.gd")
const VisualSequenceControllerScript := preload("res://scripts/ui/battle/visuals/BattleVisualSequenceController.gd")
const ActionIntentControllerScript := preload("res://scripts/ui/battle/intent/BattleActionIntentController.gd")
const StadiumBackdropCoordinatorScript := preload("res://scripts/ui/battle/display/BattleStadiumBackdropCoordinator.gd")


class EffectsScene extends Control:
	var _attack_vfx_overlay: Control = null
	var _battle_attack_vfx_registry: RefCounted = null
	var _ready_vfx_overlay: Control = null
	var _battle_ready_vfx_registry: RefCounted = null
	var _field_swap_overlay: Control = null
	var _draw_reveal_overlay: Control = null
	var _gsm: GameStateMachine = null
	var _view_player: int = 0
	var hand_refresh_count: int = 0
	var visual_gate_changes: Array[bool] = []

	func _refresh_hand() -> void:
		hand_refresh_count += 1

	func _set_battle_visual_input_blocked(blocked: bool) -> void:
		visual_gate_changes.append(blocked)


class BackdropScene extends Control:
	func _init() -> void:
		var backdrop := TextureRect.new()
		backdrop.name = "BattleBackdrop"
		add_child(backdrop)

	func _resolve_battle_backdrop_path() -> String:
		return "res://assets/ui/background.png"


func test_disabling_battle_effects_suppresses_all_cosmetic_runtime_entrypoints() -> String:
	var previous_effects := bool(GameManager.battle_effects_enabled)
	GameManager.battle_effects_enabled = false
	var scene := EffectsScene.new()

	var attack_controller: RefCounted = AttackVfxControllerScript.new()
	attack_controller.call(
		"play_attack_vfx",
		scene,
		GameAction.create(GameAction.ActionType.ATTACK, 0, {"attack_name": "Probe"}, 2, "probe")
	)
	var ready_controller: RefCounted = ReadyVfxControllerScript.new()
	ready_controller.call("play_ready_vfx", scene, {"ready_key": "probe", "rule_id": "probe"})
	var field_animator: RefCounted = FieldSwapAnimatorScript.new()
	field_animator.call("play_swap", scene, {"moves": [{"card_instance_id": 1}]})
	var draw_controller: RefCounted = DrawRevealControllerScript.new()
	draw_controller.call(
		"enqueue_reveal",
		scene,
		GameAction.create(GameAction.ActionType.DRAW_CARD, 0, {"count": 1}, 2, "probe draw")
	)
	var visual_controller: RefCounted = VisualSequenceControllerScript.new()
	visual_controller.call("setup", scene)
	visual_controller.call("enqueue_events", [{"kind": "zone_transfer"}])
	var intent_controller: RefCounted = ActionIntentControllerScript.new()
	intent_controller.call("setup", scene)
	intent_controller.call("sync")
	intent_controller.call("play_success", "energy", {})

	var result := run_checks([
		assert_null(scene._attack_vfx_overlay, "Disabled effects should not allocate an attack VFX overlay"),
		assert_null(scene._ready_vfx_overlay, "Disabled effects should not allocate a Pokemon ready animation overlay"),
		assert_null(scene._field_swap_overlay, "Disabled effects should not allocate a flying field-swap overlay"),
		assert_null(scene._draw_reveal_overlay, "Disabled effects should not allocate a draw/discard flight overlay"),
		assert_eq(scene.hand_refresh_count, 1, "Disabled draw animation should immediately render the committed hand state"),
		assert_eq(int(visual_controller.call("pending_count")), 0, "Disabled effects should not queue zone-transfer animations"),
		assert_null(scene.get_node_or_null("BattleActionIntentOverlay"), "Disabled effects should not allocate particle feedback"),
	])
	visual_controller.call("clear", "test_end")
	intent_controller.call("release")
	scene.free()
	GameManager.battle_effects_enabled = previous_effects
	return result


func test_dynamic_stadium_background_ignores_legacy_disabled_preference() -> String:
	var previous_dynamic := bool(GameManager.dynamic_stadium_background_enabled)
	var previous_effects := bool(GameManager.battle_effects_enabled)
	GameManager.dynamic_stadium_background_enabled = false
	GameManager.battle_effects_enabled = false

	var scene := BackdropScene.new()
	var coordinator: RefCounted = StadiumBackdropCoordinatorScript.new()
	coordinator.call("setup", scene)
	var card_data := CardData.new()
	card_data.name = "零区深处"
	card_data.card_type = "Stadium"
	card_data.set_code = "CSV9.5C"
	card_data.card_index = "205"
	var game_state := GameState.new()
	game_state.stadium_card = CardInstance.create(card_data, 0)
	coordinator.call("sync_stadium_backdrop", game_state, true)
	var backdrop := scene.get_node("BattleBackdrop") as TextureRect
	var applied_path := backdrop.texture.resource_path if backdrop != null and backdrop.texture != null else ""

	var result := run_checks([
		assert_eq(applied_path, "res://assets/ui/stadium_backgrounds/area_zero_underdepths.webp", "A Stadium should always replace the selected backdrop even when legacy data says dynamic backgrounds are off"),
	])
	scene.free()
	GameManager.dynamic_stadium_background_enabled = previous_dynamic
	GameManager.battle_effects_enabled = previous_effects
	return result
