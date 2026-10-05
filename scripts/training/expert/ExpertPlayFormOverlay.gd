extends ColorRect

signal keyboard_layout_changed
signal persist_requested
const TouchBridge := preload("res://scripts/ui/non_battle/NonBattleTouchBridge.gd")
var _keyboard_height := 0


func _process(_delta: float) -> void:
	if visible and DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		set_keyboard_height(DisplayServer.virtual_keyboard_get_height())


func set_keyboard_height(height: int) -> void:
	if height == _keyboard_height:
		return
	_keyboard_height = maxi(0, height)
	var center := get_node_or_null("ExpertFormCenter") as CenterContainer
	if center != null:
		center.offset_bottom = -keyboard_logical_height()
	keyboard_layout_changed.emit()


func keyboard_logical_height() -> float:
	return float(_keyboard_height) / maxf(0.01, get_viewport().get_screen_transform().get_scale().y)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		persist_requested.emit()


func _input(event: InputEvent) -> void:
	# Battle's ordinary HUD router emits pressed on BaseButton. Forms also need
	# OptionButton popups, editable text and scroll ownership. Reuse the existing
	# form router only while this modal is visible; never alter board gestures.
	if visible:
		TouchBridge.handle_root_touch(self, event)
