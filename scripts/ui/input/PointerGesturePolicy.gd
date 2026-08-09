extends RefCounted

## Shared movement and compatibility-event policy for tappable horizontal rows.
##
## Horizontal rows use a movement slop before committing to scrolling. Once a
## horizontal overflow gesture crosses that boundary it remains a scroll and
## keeps its final position; movement below the boundary remains a tap.

const MOUSE_HORIZONTAL_TAP_TOLERANCE := 12.0
const TOUCH_HORIZONTAL_TAP_TOLERANCE := 28.0
const TOUCH_VERTICAL_TAP_TOLERANCE := 36.0
const BROWSER_TOUCH_HORIZONTAL_TAP_TOLERANCE := 36.0
const BROWSER_TOUCH_VERTICAL_TAP_TOLERANCE := 48.0
const HORIZONTAL_DRAG_SLOP := 12.0

## Native touch events are reported in screen pixels on high-density Android
## devices. Scale the tap envelope in physical-pixel space so the same finger
## movement is interpreted consistently across phones, while capping the
## envelope so an intentional horizontal swipe still starts promptly.
const TOUCH_REFERENCE_DPI := 160.0
const TOUCH_DENSITY_SCALE_MIN := 1.0
const TOUCH_DENSITY_SCALE_MAX := 2.0

const TOUCH_MOUSE_ECHO_WINDOW_MSEC := 220
const TOUCH_MOUSE_ECHO_POSITION_TOLERANCE := 28.0

static var _touch_dpi_override_for_tests := -1.0


static func touch_density_scale(dpi: float = -1.0) -> float:
	var resolved_dpi := dpi
	if resolved_dpi <= 0.0:
		resolved_dpi = _touch_dpi_override_for_tests
	if resolved_dpi <= 0.0:
		resolved_dpi = float(DisplayServer.screen_get_dpi())
	if resolved_dpi <= 0.0:
		return TOUCH_DENSITY_SCALE_MIN
	return clampf(
		resolved_dpi / TOUCH_REFERENCE_DPI,
		TOUCH_DENSITY_SCALE_MIN,
		TOUCH_DENSITY_SCALE_MAX
	)


static func touch_horizontal_tap_tolerance(dpi: float = -1.0) -> float:
	return TOUCH_HORIZONTAL_TAP_TOLERANCE * touch_density_scale(dpi)


static func touch_vertical_tap_tolerance(dpi: float = -1.0) -> float:
	return TOUCH_VERTICAL_TAP_TOLERANCE * touch_density_scale(dpi)


static func set_touch_dpi_override_for_tests(dpi: float = -1.0) -> void:
	_touch_dpi_override_for_tests = dpi


static func normalize_horizontal_surface_config(config: Dictionary) -> Dictionary:
	var normalized := config.duplicate(false)
	var tap_tolerance := maxf(
		0.0,
		float(normalized.get(
			"horizontal_tap_tolerance",
			BROWSER_TOUCH_HORIZONTAL_TAP_TOLERANCE
		))
	)
	var requested_drag_threshold := maxf(
		0.0,
		float(normalized.get("horizontal_drag_threshold", tap_tolerance))
	)
	normalized["horizontal_tap_tolerance"] = tap_tolerance
	normalized["horizontal_drag_threshold"] = minf(
		requested_drag_threshold,
		tap_tolerance
	)
	return normalized


static func is_touch_mouse_echo(
	event: InputEvent,
	last_touch_release_msec: int,
	last_touch_release_position: Vector2,
	now_msec: int = -1
) -> bool:
	if not (event is InputEventMouseButton):
		return false
	var mouse_button := event as InputEventMouseButton
	if mouse_button.button_index != MOUSE_BUTTON_LEFT or mouse_button.pressed:
		return false
	if last_touch_release_msec < 0 or last_touch_release_position.x < 0.0:
		return false
	var current_msec := Time.get_ticks_msec() if now_msec < 0 else now_msec
	if current_msec - last_touch_release_msec > TOUCH_MOUSE_ECHO_WINDOW_MSEC:
		return false
	var position := (
		mouse_button.global_position
		if mouse_button.global_position != Vector2.ZERO
		else mouse_button.position
	)
	return position.distance_to(last_touch_release_position) <= TOUCH_MOUSE_ECHO_POSITION_TOLERANCE
