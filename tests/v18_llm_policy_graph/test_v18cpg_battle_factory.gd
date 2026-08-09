class_name TestV18CPGBattleFactory
extends TestBase

const BattleSceneScript = preload("res://scenes/battle/BattleScene.gd")

const RAGING_BOLT_DECK_ID := 800018509
const RAGING_BOLT_CPG_STRATEGY_ID := "v18cpg_800018509_raging_bolt_ogerpon"


func _snapshot_api_config() -> Dictionary:
	var path := GameManager.get_battle_review_api_config_path()
	var existed := FileAccess.file_exists(path)
	return {
		"path": path,
		"existed": existed,
		"bytes": FileAccess.get_file_as_bytes(path) if existed else PackedByteArray(),
	}


func _install_deepseek_transport_fixture() -> void:
	var file := FileAccess.open(GameManager.get_battle_review_api_config_path(), FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"provider": "deepseek",
		"endpoint": "https://api.deepseek.com",
		"api_key": "test-key",
		"model": "deepseek-v4-flash",
		"provider_configs": {
			"deepseek": {
				"endpoint": "https://api.deepseek.com",
				"api_key": "test-key",
				"model": "deepseek-v4-flash",
			},
		},
	}, "\t"))
	file.close()


func _restore_api_config(snapshot: Dictionary) -> void:
	var path := str(snapshot.get("path", GameManager.get_battle_review_api_config_path()))
	if not bool(snapshot.get("existed", false)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_buffer(snapshot.get("bytes", PackedByteArray()))
	file.close()


class BattleSceneStub extends BattleSceneScript:
	func _runtime_log(_event: String, _detail: String = "") -> void:
		pass


func test_strong_opening_preserves_raging_bolt_conditional_policy_runtime() -> String:
	var previous_mode := GameManager.current_mode
	var previous_selected_deck_ids := GameManager.selected_deck_ids.duplicate()
	var previous_ai_selection := GameManager.ai_selection.duplicate(true)
	var previous_ai_deck_strategy := GameManager.ai_deck_strategy
	var previous_api_config := _snapshot_api_config()
	_install_deepseek_transport_fixture()

	GameManager.current_mode = GameManager.GameMode.VS_AI
	GameManager.selected_deck_ids = [575720, RAGING_BOLT_DECK_ID]
	GameManager.ai_deck_strategy = RAGING_BOLT_CPG_STRATEGY_ID
	GameManager.ai_selection = {
		"source": "default",
		"version_id": "",
		"agent_config_path": "",
		"value_net_path": "",
		"action_scorer_path": "",
		"interaction_scorer_path": "",
		"display_name": "",
		"opening_mode": "fixed_order",
		"fixed_deck_order_path": "res://data/bundled_user/ai_fixed_deck_orders/800018509.json",
	}

	var scene := BattleSceneStub.new()
	var ai: AIOpponent = scene.call("_build_selected_ai_opponent")
	var strategy: RefCounted = ai.get("_deck_strategy") if ai != null else null

	GameManager.current_mode = previous_mode
	GameManager.selected_deck_ids = previous_selected_deck_ids
	GameManager.ai_selection = previous_ai_selection
	GameManager.ai_deck_strategy = previous_ai_deck_strategy
	_restore_api_config(previous_api_config)

	var result := run_checks([
		assert_not_null(ai, "Strong opening must still construct the selected V18CPG opponent"),
		assert_eq(
			str(strategy.call("get_strategy_id"))
				if strategy != null and strategy.has_method("get_strategy_id") else "",
			RAGING_BOLT_CPG_STRATEGY_ID,
			"Strong opening must preserve the selected Raging Bolt V18CPG strategy identity"
		),
		assert_eq(
			str(ai.decision_runtime_mode) if ai != null else "",
			"conditional_policy",
			"V18CPG must not be reported or executed as the rules_only outer runtime"
		),
		assert_true(
			bool(strategy.get("_runtime_configured")) if strategy != null else false,
			"Strong opening must keep the V18CPG model transport configured"
		),
		assert_true(
			bool((strategy.get("_audit") as RefCounted).get("_write_files"))
				if strategy != null and strategy.get("_audit") is RefCounted else false,
			"Live V18CPG battles must persist replay-attributable decision audit"
		),
	])
	scene.free()
	return result
