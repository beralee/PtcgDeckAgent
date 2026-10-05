extends RefCounted
## Presentation-only sizing and GPU budgets. Input stays in logical UI coordinates.
const LOW_RENDER_EDGE := 832

static func metrics(size: Vector2, profile: UiRuntimeProfile = null) -> Dictionary:
	var touch := profile != null and profile.prefers_touch()
	var web := profile != null and profile.is_web()
	var portrait := size.y > size.x
	var compact := portrait or size.x < 1000 or touch
	var scale := 1.0
	if touch:
		scale = clampf(minf(size.x / (420.0 if portrait else 860.0), size.y / (780.0 if portrait else 420.0)), 1.0, 2.4)
	var low := web or OS.has_feature("web") or OS.get_name() in ["Android","macOS"] or (profile != null and (profile.native_os in ["android","macos"] or profile.mobile_like or profile.performance_tier in ["low", "medium"]))
	return {"portrait":portrait,"compact":compact,"touch":touch,"scale":scale,"low":low,
		"target":44.0*scale,"font":roundi(14*scale),"max_render_edge":LOW_RENDER_EDGE if low else 2560}

static func render_size(size: Vector2, budget: int) -> Vector2i:
	var ratio := minf(1.0, float(budget)/maxf(1.0,maxf(size.x,size.y)))
	return Vector2i(maxi(1,roundi(size.x*ratio)),maxi(1,roundi(size.y*ratio)))

static func msaa(high: bool) -> Viewport.MSAA:
	# WebGL framebuffer resolves vary across mobile browsers. Keep every 3D
	# surface on the same single-sample path, including transparent overlays.
	return Viewport.MSAA_4X if high and not OS.has_feature("web") else Viewport.MSAA_DISABLED

static func canvas_size(physical: Vector2i) -> Vector2i:
	# Existing battle dialogs use a 900-unit short edge. Keep their touch and
	# accessibility sizing while independently capping the expensive 3D surface.
	var ratio := maxf(1.0,900.0/maxi(1,mini(physical.x,physical.y)))
	return Vector2i(Vector2(physical)*ratio)

static func safe_rect(scene: Control) -> Rect2:
	var size := scene.get_viewport_rect().size
	var result := Rect2(Vector2.ZERO,size)
	if OS.get_name() in ["Android","iOS"]:
		var safe := Rect2(DisplayServer.get_display_safe_area())
		if safe.has_area():
			var transform := scene.get_viewport().get_stretch_transform()*scene.get_screen_transform()
			var clipped := (transform.affine_inverse()*safe).intersection(result)
			if clipped.has_area(): result = clipped
	# The Web shell already removes CSS safe-area insets from the canvas.
	return result
