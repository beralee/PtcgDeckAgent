extends RefCounted
## One physical touch, one fresh UI intent. Uses the existing pointer normalizer.
var scene: Control
var fingers: Dictionary = {}
var target: Dictionary = {}
var origin := Vector2.ZERO
var point := Vector2.ZERO
var signature := ""
var elapsed := 0.0
var suppressed := false
var inspected := false
var emulated_mouse_owned := false

func cancel() -> void:
	_clear_prize_press()
	target.clear()
	fingers.clear()
	suppressed = false
	elapsed = 0
	emulated_mouse_owned = false

func suppress_emulated_mouse(event: InputEvent) -> bool:
	# Godot Web can emit its compatibility mouse edge BEFORE the raw touch.
	# Reserve arena gestures for raw touch so long-press/cancel/multitouch keep
	# their meaning. Existing modal/pop-up controls retain their mouse route.
	if not event is InputEventMouse or event.device != InputEvent.DEVICE_ID_EMULATION: return false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var presenter := _presenter()
			emulated_mouse_owned = presenter != null and not presenter.touch_target(event.position).is_empty()
			return emulated_mouse_owned
		var owned := emulated_mouse_owned
		emulated_mouse_owned = false
		return owned
	return emulated_mouse_owned

func _clear_prize_press() -> void:
	if not is_instance_valid(scene): return
	var contexts: Dictionary = scene.get("_prize_touch_press_contexts")
	for finger in fingers: contexts.erase(str(finger))

func _presenter() -> Control:
	return scene.get_node_or_null("Arena3DPresenter")

func _signature(presenter: Control) -> String:
	var gsm = scene.get("_gsm")
	if gsm == null or gsm.game_state == null: return ""
	return presenter._input_signature(preload("res://scenes/arena3d/ArenaFrame.gd").capture(gsm.game_state,int(scene.get("_view_player")),scene)) + str(presenter.size) + presenter.theme_id

func handle(event: InputEvent) -> bool:
	if not (event is InputEventScreenTouch or event is InputEventScreenDrag): return false
	var presenter := _presenter()
	if presenter == null: return false
	if event is InputEventScreenTouch and event.pressed:
		if not fingers.is_empty():
			_clear_prize_press()
			fingers[event.index] = true
			suppressed = true
			target.clear()
			return true
		var found: Dictionary = presenter.touch_target(event.position)
		if found.is_empty(): return false
		fingers[event.index] = true
		target = found
		origin = event.position
		point = origin
		signature = _signature(presenter)
		elapsed = 0
		suppressed = false
		inspected = false
		if found.get("kind","") == "prize":
			scene.call("_on_prize_slot_input",event,int(scene.get("_view_player")),"奖赏",int(found.index))
		return true
	if not fingers.has(event.index): return false
	if event is InputEventScreenDrag:
		point = event.position
		if point.distance_to(origin) > 14.0*float(presenter.platform_metrics.scale): suppressed = true
		return true
	_clear_prize_press_on_invalid_release(event, presenter)
	fingers.erase(event.index)
	var selected := target.duplicate()
	var fresh: bool = not event.canceled and not suppressed and not inspected and signature == _signature(presenter)
	var same: bool = presenter.touch_target(event.position) == selected
	target.clear()
	if fingers.is_empty(): suppressed = false
	if not fresh or not same: return true
	# No event replay or synthetic mouse injection. Compatibility echoes are
	# rejected by the scene's existing BattlePointerInputRouter.
	if selected.get("kind","") == "prize":
		scene.call("_on_prize_slot_input",event,int(scene.get("_view_player")),"奖赏",int(selected.index))
	else:
		presenter.activate_touch_target(selected,false)
	return true

func _clear_prize_press_on_invalid_release(event: InputEventScreenTouch, presenter: Control) -> void:
	if event.canceled or suppressed or inspected or signature != _signature(presenter) or presenter.touch_target(event.position) != target:
		var contexts: Dictionary = scene.get("_prize_touch_press_contexts")
		contexts.erase(str(event.index))

func tick(delta: float) -> void:
	if target.is_empty() or suppressed or inspected or target.get("kind","") != "slot": return
	elapsed += delta
	if elapsed < .55: return
	var presenter := _presenter()
	if presenter == null or signature != _signature(presenter):
		target.clear()
		return
	inspected = true
	presenter.activate_touch_target(target,true)
