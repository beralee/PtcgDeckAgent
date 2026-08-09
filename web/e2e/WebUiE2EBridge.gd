class_name WebUiE2EBridge
extends Node

const NonBattleTouchBridgeScript := preload("res://scripts/ui/non_battle/NonBattleTouchBridge.gd")
const WebTextInputBridgeScript := preload("res://scripts/ui/non_battle/WebTextInputBridge.gd")
const WebUiFeatureGateScript := preload("res://scripts/ui/web/WebUiFeatureGate.gd")

const CALLBACK_NAME := "__ptcgDeckAgentE2ECallback"
const BRIDGE_NAME := "__PTCG_TEST__"

var _callback: Variant = null
var _installed: bool = false
var _last_touch_event: Dictionary = {}


func _ready() -> void:
	if not OS.has_feature("web_ui_e2e"):
		queue_free()
		return
	_install()


func _exit_tree() -> void:
	_uninstall()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		_last_touch_event = {
			"kind": "touch",
			"pressed": touch.pressed,
			"index": touch.index,
			"position": {"x": touch.position.x, "y": touch.position.y},
		}
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_last_touch_event = {
			"kind": "drag",
			"index": drag.index,
			"position": {"x": drag.position.x, "y": drag.position.y},
		}


func _install() -> void:
	if _installed or not (OS.has_feature("web") or OS.has_feature("web_android") or OS.has_feature("web_ios")):
		return
	var window := JavaScriptBridge.get_interface("window")
	if window == null:
		return
	_callback = JavaScriptBridge.create_callback(_on_command)
	window.set(CALLBACK_NAME, _callback)
	_installed = bool(JavaScriptBridge.eval(build_install_script(), true))


func _uninstall() -> void:
	if _installed and (OS.has_feature("web") or OS.has_feature("web_android") or OS.has_feature("web_ios")):
		JavaScriptBridge.eval(build_uninstall_script(), true)
	_installed = false
	_callback = null


static func build_install_script() -> String:
	return """
(function() {
  var nextId = 1;
  var results = Object.create(null);
  window.__PTCG_TEST__ = {
    version: 1,
    request: function(command, payload) {
      var id = nextId++;
      results[id] = { done: false };
      var callback = window.__ptcgDeckAgentE2ECallback;
      if (typeof callback !== 'function') {
        results[id] = { done: true, ok: false, error: 'Godot E2E callback unavailable' };
        return id;
      }
      callback(JSON.stringify({ request_id: id, command: String(command || ''), payload: payload || {} }));
      return id;
    },
    result: function(id) { return results[id] || null; },
    consume: function(id) { var value = results[id] || null; delete results[id]; return value; },
    _resolve: function(id, value) { results[id] = value; }
  };
  return true;
})();
"""


static func build_uninstall_script() -> String:
	return """
(function() {
  try { delete window.__PTCG_TEST__; } catch (_error) { window.__PTCG_TEST__ = null; }
  try { delete window.__ptcgDeckAgentE2ECallback; } catch (_error) { window.__ptcgDeckAgentE2ECallback = null; }
  return true;
})();
"""


func _on_command(args: Array) -> void:
	if args.is_empty():
		return
	var parsed: Variant = JSON.parse_string(str(args[0]))
	if not (parsed is Dictionary):
		return
	var request := parsed as Dictionary
	var request_id := int(request.get("request_id", -1))
	var payload_variant: Variant = request.get("payload", {})
	var payload: Dictionary = payload_variant as Dictionary if payload_variant is Dictionary else {}
	var result := _execute_command(str(request.get("command", "")), payload)
	_resolve_javascript_request(request_id, result)


func _execute_command(command: String, payload: Dictionary) -> Dictionary:
	match command:
		"snapshot":
			return {"done": true, "ok": true, "value": _snapshot()}
		"find_control":
			var control := _find_control(str(payload.get("id", "")))
			return {
				"done": true,
				"ok": control != null,
				"value": _control_snapshot(control) if control != null else {},
				"error": "" if control != null else "control not found",
			}
		"list_controls":
			return {"done": true, "ok": true, "value": _visible_control_snapshots()}
		"launch_deck_training":
			var scenario_id := str(payload.get("scenario_id", "")).strip_edges()
			var started := scenario_id != "" and GameManager.start_deck_training(scenario_id)
			return {
				"done": true,
				"ok": started,
				"value": {"scenario_id": scenario_id},
				"error": "" if started else "deck training scenario could not start",
			}
		"prepare_battle_hud_fixture":
			return _prepare_battle_hud_fixture(str(payload.get("kind", "")))
		"prepare_battle_hand_fixture":
			return _prepare_battle_hand_fixture()
		"cycle_battle_hand_fixture_turn":
			return _cycle_battle_hand_fixture_turn()
		"battle_hud_probe":
			return {"done": true, "ok": true, "value": _battle_hud_probe()}
		"input_probe":
			return {"done": true, "ok": true, "value": _last_touch_event.duplicate(true)}
		"text_input_diagnostics":
			return {"done": true, "ok": true, "value": _text_input_diagnostics(str(payload.get("id", "")))}
		"settings_api_key_probe":
			return {"done": true, "ok": true, "value": _settings_api_key_probe(str(payload.get("expected", "")))}
		_:
			return {"done": true, "ok": false, "error": "unsupported command: %s" % command}


func _snapshot() -> Dictionary:
	var tree := get_tree()
	var scene := tree.current_scene if tree != null else null
	var session: Dictionary = {}
	var pointers: Array = []
	if scene != null:
		var registry_variant: Variant = _property_or(scene, "_ui_interaction_sessions", null)
		if registry_variant is UiInteractionSessionRegistry:
			session = (registry_variant as UiInteractionSessionRegistry).current_snapshot()
		var router_variant: Variant = _property_or(scene, "_battle_pointer_input_router", null)
		if router_variant is BattlePointerInputRouter:
			pointers = (router_variant as BattlePointerInputRouter).active_snapshots()
		else:
			var non_battle_adapter := _find_non_battle_input_adapter(scene)
			if non_battle_adapter != null:
				pointers = non_battle_adapter.active_snapshots()
	var profile: Dictionary = {}
	if GameManager != null and GameManager.has_method("get_ui_runtime_profile"):
		var runtime_profile: UiRuntimeProfile = GameManager.get_ui_runtime_profile()
		if runtime_profile != null:
			profile = runtime_profile.to_dictionary()
			profile["viewport_size"] = {
				"x": runtime_profile.viewport_size.x,
				"y": runtime_profile.viewport_size.y,
			}
	return {
		"scene": scene.name if scene != null else "",
		"scene_path": scene.scene_file_path if scene != null else "",
		"runtime_profile": profile,
		"interaction_session": session,
		"active_pointers": pointers,
		"pending_choice": str(_property_or(scene, "_pending_choice", "")) if scene != null else "",
		"draw_reveal_active": bool(_property_or(scene, "_draw_reveal_active", false)) if scene != null else false,
	}


func _property_or(object: Object, property_name: String, fallback: Variant) -> Variant:
	if object == null:
		return fallback
	for property: Dictionary in object.get_property_list():
		if str(property.get("name", "")) == property_name:
			return object.get(property_name)
	return fallback


func _prepare_battle_hud_fixture(kind: String) -> Dictionary:
	var tree := get_tree()
	var scene := tree.current_scene if tree != null else null
	if scene == null or scene.name != "BattleScene":
		return {"done": true, "ok": false, "error": "BattleScene is not active"}
	_hide_battle_fixture_overlays(scene)
	match kind:
		"pokemon_action":
			var gsm: Variant = _property_or(scene, "_gsm", null)
			if gsm == null or gsm.game_state == null:
				return {"done": true, "ok": false, "error": "battle state is unavailable"}
			var state: GameState = gsm.game_state
			var player_index := int(_property_or(scene, "_view_player", state.current_player_index))
			if player_index < 0 or player_index >= state.players.size():
				return {"done": true, "ok": false, "error": "view player is unavailable"}
			var slot: PokemonSlot = state.players[player_index].active_pokemon
			if slot == null or slot.get_top_card() == null:
				return {"done": true, "ok": false, "error": "view player has no Active Pokemon"}
			scene.call("_show_pokemon_action_dialog", player_index, slot, true)
		"card_detail":
			var card := _battle_fixture_card(scene)
			if card == null:
				return {"done": true, "ok": false, "error": "card detail fixture is unavailable"}
			var coordinator: Variant = _property_or(scene, "_battle_card_detail_coordinator", null)
			if coordinator == null:
				return {"done": true, "ok": false, "error": "card detail coordinator is unavailable"}
			scene.set("_selected_hand_card", card)
			coordinator.call("show_card_instance_detail", card)
			coordinator.call("set_detail_action_mode", "selected_pokemon", card)
		_:
			return {"done": true, "ok": false, "error": "unsupported HUD fixture: %s" % kind}
	return {"done": true, "ok": true, "value": _battle_hud_probe()}


func _prepare_battle_hand_fixture() -> Dictionary:
	var tree := get_tree()
	var scene := tree.current_scene if tree != null else null
	if scene == null or scene.name != "BattleScene":
		return {"done": true, "ok": false, "error": "BattleScene is not active"}
	_hide_battle_fixture_overlays(scene)
	var gsm: Variant = _property_or(scene, "_gsm", null)
	if gsm == null or gsm.game_state == null:
		gsm = _install_minimal_battle_hand_fixture_state(scene)
	if gsm == null or gsm.game_state == null:
		return {"done": true, "ok": false, "error": "battle state is unavailable"}
	var state: GameState = gsm.game_state
	var player_index := int(_property_or(scene, "_view_player", state.current_player_index))
	if player_index < 0 or player_index >= state.players.size():
		return {"done": true, "ok": false, "error": "view player is unavailable"}
	state.current_player_index = player_index
	var card_data: CardData = CardDatabase.get_card("CSV1C", "112")
	if card_data == null:
		return {"done": true, "ok": false, "error": "Ultra Ball card data is unavailable"}
	var card := CardInstance.create(card_data, player_index)
	state.players[player_index].hand.append(card)
	scene.call("_refresh_hand")
	var hand_container := _property_or(scene, "_hand_container", null) as Control
	if hand_container == null:
		return {"done": true, "ok": false, "error": "hand container is unavailable"}
	var card_view: BattleCardView = null
	for child: Node in hand_container.get_children():
		if child is BattleCardView and (child as BattleCardView).card_instance == card:
			card_view = child as BattleCardView
			break
	if card_view == null:
		return {"done": true, "ok": false, "error": "Ultra Ball hand view was not rendered"}
	card_view.set_meta("ui_test_id", "E2EHandUltraBall")
	return {
		"done": true,
		"ok": true,
		"value": {
			"control": _control_snapshot(card_view),
			"card_name": card_data.display_name(),
			"ios_web_touch_profile": bool(card_view.get_meta("_ios_web_hand_touch_profile", false)),
			"pointer_surface_enabled": _battle_pointer_surface_enabled(scene),
			"hand_generation": int(_property_or(scene, "_hand_pointer_surface_generation", 0)),
		},
	}


func _install_minimal_battle_hand_fixture_state(scene: Node) -> GameStateMachine:
	if scene == null:
		return null
	var gsm := GameStateMachine.new()
	var state := GameState.new()
	state.current_player_index = 0
	state.first_player_index = 0
	state.turn_number = 2
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	gsm.game_state = state
	scene.set("_gsm", gsm)
	scene.set("_view_player", 0)
	if scene.has_method("_sync_battle_scene_context_runtime"):
		scene.call("_sync_battle_scene_context_runtime")
	return gsm


func _cycle_battle_hand_fixture_turn() -> Dictionary:
	var tree := get_tree()
	var scene := tree.current_scene if tree != null else null
	if scene == null or scene.name != "BattleScene":
		return {"done": true, "ok": false, "error": "BattleScene is not active"}
	_hide_battle_fixture_overlays(scene)
	scene.set("_selected_hand_card", null)
	var gsm: Variant = _property_or(scene, "_gsm", null)
	if gsm == null or gsm.game_state == null:
		return {"done": true, "ok": false, "error": "battle state is unavailable"}
	var state: GameState = gsm.game_state
	var player_index := int(_property_or(scene, "_view_player", state.current_player_index))
	if player_index < 0 or player_index >= state.players.size():
		return {"done": true, "ok": false, "error": "view player is unavailable"}
	state.current_player_index = 1 - player_index
	scene.call("_refresh_hand")
	call_deferred("_finish_battle_hand_fixture_turn_cycle", scene, player_index)
	return {
		"done": true,
		"ok": true,
		"value": {
			"scheduled": true,
			"player_index": player_index,
		},
	}


func _finish_battle_hand_fixture_turn_cycle(scene: Node, player_index: int) -> void:
	if scene == null or not is_instance_valid(scene):
		return
	var gsm: Variant = _property_or(scene, "_gsm", null)
	if gsm == null or gsm.game_state == null:
		return
	var state: GameState = gsm.game_state
	state.current_player_index = player_index
	scene.call("_refresh_hand")


func _hide_battle_fixture_overlays(scene: Node) -> void:
	var dialog_overlay := _property_or(scene, "_dialog_overlay", null) as Control
	if dialog_overlay != null:
		dialog_overlay.visible = false
	scene.set("_pending_choice", "")
	var detail_overlay := _property_or(scene, "_detail_overlay", null) as Control
	if detail_overlay != null:
		detail_overlay.visible = false


func _battle_fixture_card(scene: Node) -> CardInstance:
	var gsm: Variant = _property_or(scene, "_gsm", null)
	if gsm != null and gsm.game_state != null:
		var state: GameState = gsm.game_state
		var player_index := int(_property_or(scene, "_view_player", state.current_player_index))
		if player_index >= 0 and player_index < state.players.size():
			for card: CardInstance in state.players[player_index].hand:
				if card != null and card.card_data != null and card.card_data.is_pokemon():
					return card
	var card_data := CardData.new()
	card_data.name = "Web E2E Pokemon"
	card_data.name_zh = "Web E2E Pokemon"
	card_data.card_type = "Pokemon"
	card_data.stage = "Basic"
	card_data.hp = 70
	card_data.energy_type = "C"
	return CardInstance.create(card_data, int(_property_or(scene, "_view_player", 0)))


func _battle_hud_probe() -> Dictionary:
	var tree := get_tree()
	var scene := tree.current_scene if tree != null else null
	if scene == null:
		return {}
	var dialog_overlay := _property_or(scene, "_dialog_overlay", null) as Control
	var detail_overlay := _property_or(scene, "_detail_overlay", null) as Control
	var detail_action_bar := _property_or(scene, "_detail_action_bar", null) as Control
	var current_player_index := -1
	var gsm_variant: Variant = _property_or(scene, "_gsm", null)
	if gsm_variant is GameStateMachine and (gsm_variant as GameStateMachine).game_state != null:
		current_player_index = int((gsm_variant as GameStateMachine).game_state.current_player_index)
	return {
		"pending_choice": str(_property_or(scene, "_pending_choice", "")),
		"current_player_index": current_player_index,
		"dialog_visible": dialog_overlay != null and dialog_overlay.visible,
		"detail_visible": detail_overlay != null and detail_overlay.visible,
		"detail_action_bar_visible": detail_action_bar != null and detail_action_bar.visible,
		"detail_mode": str(_property_or(scene, "_detail_mode", "")),
		"selected_hand_card": _property_or(scene, "_selected_hand_card", null) != null,
		"pointer_surface_enabled": _battle_pointer_surface_enabled(scene),
		"hand_generation": int(_property_or(scene, "_hand_pointer_surface_generation", 0)),
		"active_surface_gestures": _active_battle_pointer_surface_gestures(scene),
		"modal_pointer_drain_visible": _battle_modal_pointer_drain_visible(scene),
	}


func _battle_pointer_surface_enabled(scene: Node) -> bool:
	var controller: Variant = _property_or(
		scene,
		"_battle_pointer_surface_controller",
		null
	)
	return (
		controller != null
		and controller.has_method("is_enabled")
		and bool(controller.call("is_enabled"))
	)


func _active_battle_pointer_surface_gestures(scene: Node) -> int:
	var controller: Variant = _property_or(
		scene,
		"_battle_pointer_surface_controller",
		null
	)
	if controller == null or not controller.has_method("active_gesture_count"):
		return 0
	return int(controller.call("active_gesture_count"))


func _battle_modal_pointer_drain_visible(scene: Node) -> bool:
	var shield := _property_or(
		scene,
		"_modal_pointer_drain_shield",
		null
	) as Control
	return shield != null and shield.visible


func _find_non_battle_input_adapter(node: Node) -> WebInputAdapter:
	if node == null:
		return null
	if node.has_meta("_non_battle_web_input_adapter"):
		var adapter := node.get_meta("_non_battle_web_input_adapter") as WebInputAdapter
		if adapter != null:
			return adapter
	for child: Node in node.get_children():
		var nested := _find_non_battle_input_adapter(child)
		if nested != null:
			return nested
	return null


func _text_input_diagnostics(identifier: String) -> Dictionary:
	var tree := get_tree()
	var scene := tree.current_scene if tree != null else null
	var control := _find_control(identifier)
	var touch_position := Vector2(INF, INF)
	var position_variant: Variant = _last_touch_event.get("position", {})
	if position_variant is Dictionary:
		var position := position_variant as Dictionary
		touch_position = Vector2(float(position.get("x", INF)), float(position.get("y", INF)))
	var hit: Control = null
	if scene is Control and touch_position.x != INF and touch_position.y != INF:
		hit = NonBattleTouchBridgeScript.native_text_input_at_position(scene as Control, touch_position)
	return {
		"scene": scene.name if scene != null else "",
		"scene_processing_input": scene != null and scene.is_processing_input(),
		"last_touch": _last_touch_event.duplicate(true),
		"control_found": control != null,
		"control_has_focus": control != null and control.has_focus(),
		"native_meta": control != null and bool(control.get_meta(NonBattleTouchBridgeScript.NATIVE_TEXT_INPUT_META, false)),
		"web_bound_meta": control != null and bool(control.get_meta(NonBattleTouchBridgeScript.WEB_TEXT_INPUT_BOUND_META, false)),
		"hit_control": hit.name if hit != null else "",
		"root_native_candidate": scene != null and scene.has_meta(NonBattleTouchBridgeScript.NATIVE_TEXT_INPUT_CANDIDATE_META),
		"web_v2": WebUiFeatureGateScript.web_input_adapter_v2_enabled(),
		"dom_bridge_installed": bool(JavaScriptBridge.eval("!!window.__ptcgDeckAgentTextInput", true)),
		"godot_bridge_state": WebTextInputBridgeScript.debug_state_for_tests(),
	}


func _settings_api_key_probe(expected: String) -> Dictionary:
	var input := _find_control("ApiKeyInput") as LineEdit
	var config := GameManager.get_battle_review_api_config()
	var saved_key := str(config.get("api_key", ""))
	return {
		"input_matches": input != null and input.text == expected,
		"saved_matches": saved_key == expected,
		"input_length": input.text.length() if input != null else -1,
		"saved_length": saved_key.length(),
	}


func _find_control(identifier: String) -> Control:
	if identifier.strip_edges() == "":
		return null
	var tree := get_tree()
	var scene := tree.current_scene if tree != null else null
	if scene == null:
		return null
	if identifier == "E2EHandUltraBall":
		var hand_card := _find_battle_hand_card_view(scene, "CSV1C_112")
		if hand_card != null:
			hand_card.set_meta("ui_test_id", identifier)
			return hand_card
	return _find_control_recursive(scene, identifier)


func _find_battle_hand_card_view(scene: Node, card_uid: String) -> BattleCardView:
	var hand_container := _property_or(scene, "_hand_container", null) as Control
	if hand_container == null:
		return null
	for child: Node in hand_container.get_children():
		if not (child is BattleCardView):
			continue
		var card_view := child as BattleCardView
		if card_view.card_data != null and card_view.card_data.get_uid() == card_uid:
			return card_view
	return null


func _find_control_recursive(node: Node, identifier: String) -> Control:
	for child_index: int in range(node.get_child_count() - 1, -1, -1):
		var found := _find_control_recursive(node.get_child(child_index), identifier)
		if found != null:
			return found
	if not (node is Control):
		return null
	var control := node as Control
	if not control.visible or (control.is_inside_tree() and not control.is_visible_in_tree()):
		return null
	if control.name == identifier or str(control.get_meta("ui_test_id", "")) == identifier or str(control.get_path()) == identifier:
		return control
	return null


func _visible_control_snapshots() -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	var tree := get_tree()
	var scene := tree.current_scene if tree != null else null
	if scene != null:
		_collect_controls(scene, snapshots)
	return snapshots


func _collect_controls(node: Node, snapshots: Array[Dictionary]) -> void:
	if node is Control:
		var control := node as Control
		if control.visible and (not control.is_inside_tree() or control.is_visible_in_tree()) and (control is BaseButton or control.has_meta("ui_test_id")):
			snapshots.append(_control_snapshot(control))
	for child: Node in node.get_children():
		_collect_controls(child, snapshots)


func _control_snapshot(control: Control) -> Dictionary:
	var rect := control.get_global_rect()
	var snapshot := {
		"id": str(control.get_meta("ui_test_id", control.name)),
		"name": str(control.name),
		"path": str(control.get_path()),
		"visible": control.visible and (not control.is_inside_tree() or control.is_visible_in_tree()),
		"disabled": bool(control.disabled) if control is BaseButton else false,
		"rect": {"x": rect.position.x, "y": rect.position.y, "width": rect.size.x, "height": rect.size.y},
	}
	if control is LineEdit:
		snapshot["text"] = (control as LineEdit).text
		snapshot["secret"] = (control as LineEdit).secret
	elif control is Label:
		snapshot["text"] = (control as Label).text
	elif control is BaseButton:
		snapshot["text"] = (control as BaseButton).text
	return snapshot


func _resolve_javascript_request(request_id: int, result: Dictionary) -> void:
	if request_id < 0:
		return
	var encoded_result := JSON.stringify(result)
	JavaScriptBridge.eval(
		"(function(){var b=window.__PTCG_TEST__;if(b&&typeof b._resolve==='function')b._resolve(%d,%s);})();" % [request_id, encoded_result],
		true
	)
