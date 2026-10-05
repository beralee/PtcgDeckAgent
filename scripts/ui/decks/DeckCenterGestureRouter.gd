extends "res://scripts/ui/non_battle/NonBattleGestureRouter.gd"
## One pointer stream owns either page scrolling, a carousel swipe, or a tap.
## Modal picking is scoped before any hit testing; releases never pick new targets.
var _carousel: Control

func cancel() -> void:
	if is_instance_valid(_carousel):
		_carousel.cancel_interaction()
	_carousel = null
	super.cancel()

func handle_center(view: RefCounted, event: InputEvent) -> bool:
	var scope: Control = view.input_scope()
	if scope != _scope:
		cancel()
		_scope = scope
	if event is InputEventScreenTouch and event.pressed and _finger == -1:
		if scope == view.host() and is_instance_valid(view._discovery) and view._discovery.can_start_gesture(event.position):
			_carousel = view._discovery
			_carousel._dragging = true
	var release: bool = event is InputEventScreenTouch and not event.pressed and event.index == _finger
	var horizontal: bool = release and _dragging and _axis == "horizontal" and is_instance_valid(_carousel)
	var delta: Vector2 = event.position - _origin if release else Vector2.ZERO
	var poster_tap: bool = release and not _dragging and delta.length() < DEADZONE and is_instance_valid(_carousel)
	var carousel := _carousel
	var consumed := super.handle(scope, event)
	if event is InputEventScreenDrag and event.index == _finger and is_instance_valid(_carousel) and _axis == "horizontal":
		_carousel.preview_swipe(event.position - _origin)
	if release and is_instance_valid(carousel):
		carousel.cancel_interaction()
		if not event.canceled and horizontal and absf(delta.x) >= 45 * float(view.layout.scale):
			view._advance(1 if delta.x < 0 else -1)
		elif not event.canceled and poster_tap and carousel.poster_contains(event.position):
			carousel._show_poster()
	return consumed
