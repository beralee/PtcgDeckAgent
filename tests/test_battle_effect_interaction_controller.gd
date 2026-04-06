class_name TestBattleEffectInteractionController
extends TestBase

const BattleEffectInteractionControllerScript = preload("res://scripts/ui/battle/BattleEffectInteractionController.gd")
const BattleSceneScript = preload("res://scenes/battle/BattleScene.gd")


func test_resolve_effect_step_chooser_player_prefers_explicit_index() -> String:
	var controller := BattleEffectInteractionControllerScript.new()
	var scene = BattleSceneScript.new()
	scene.set("_pending_effect_player_index", 0)
	var chooser := int(controller.call("resolve_effect_step_chooser_player", scene, {
		"chooser_player_index": 1,
		"opponent_chooses": false,
	}))

	return run_checks([
		assert_eq(chooser, 1, "Explicit chooser_player_index should override the pending effect player"),
	])


func test_effect_step_uses_field_slot_ui_requires_only_pokemon_slots() -> String:
	var controller := BattleEffectInteractionControllerScript.new()
	var scene = BattleSceneScript.new()
	var slot := PokemonSlot.new()
	var slot_result := bool(controller.call("effect_step_uses_field_slot_ui", scene, {"items": [slot]}))
	var mixed_result := bool(controller.call("effect_step_uses_field_slot_ui", scene, {"items": [slot, "bad"]}))

	return run_checks([
		assert_true(slot_result, "Pure PokemonSlot item lists should use field slot UI"),
		assert_false(mixed_result, "Mixed item lists should stay on dialog UI"),
	])
