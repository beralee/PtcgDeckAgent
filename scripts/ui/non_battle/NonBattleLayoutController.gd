class_name NonBattleLayoutController
extends RefCounted

const LAYOUT_LANDSCAPE := "landscape"
const LAYOUT_PORTRAIT := "portrait"
const PORTRAIT_PHONE_WIDTH_THRESHOLD := 760.0
const PORTRAIT_MAX_CONTENT_WIDTH := 1040.0
const LANDSCAPE_MAX_CONTENT_WIDTH := 1180.0


func sanitize_layout_mode(mode: String) -> String:
	match mode:
		LAYOUT_PORTRAIT:
			return LAYOUT_PORTRAIT
		_:
			return LAYOUT_LANDSCAPE


func resolve_layout_mode(viewport_size: Vector2, preferred_mode: String, is_mobile_like: bool = false) -> String:
	var sanitized := sanitize_layout_mode(preferred_mode)
	if sanitized == LAYOUT_PORTRAIT:
		return LAYOUT_PORTRAIT
	if sanitized == LAYOUT_LANDSCAPE:
		return LAYOUT_LANDSCAPE
	if viewport_size.y > viewport_size.x:
		return LAYOUT_PORTRAIT
	if is_mobile_like and viewport_size.x <= PORTRAIT_PHONE_WIDTH_THRESHOLD:
		return LAYOUT_PORTRAIT
	return LAYOUT_LANDSCAPE


func build_context(viewport_size: Vector2, preferred_mode: String, is_mobile_like: bool = false) -> Dictionary:
	var size := viewport_size
	if size.x <= 0.0 or size.y <= 0.0:
		size = Vector2(1600, 900)
	var resolved := resolve_layout_mode(size, preferred_mode, is_mobile_like)
	var portrait := resolved == LAYOUT_PORTRAIT
	var portrait_scale := clampf(size.x / 430.0, 1.0, 1.62) if portrait else 1.0
	var portrait_horizontal_clearance := clampf(size.x * 0.052, 28.0, 40.0)
	var content_width := minf(size.x - portrait_horizontal_clearance, PORTRAIT_MAX_CONTENT_WIDTH) if portrait else minf(size.x - 72.0, LANDSCAPE_MAX_CONTENT_WIDTH)
	content_width = maxf(content_width, 320.0 if portrait else 640.0)
	var margin := clampf(size.x * (0.038 if portrait else 0.025), 22.0 if portrait else 24.0, 42.0 if portrait else 44.0)
	var title_font := roundi(44.0 * portrait_scale) if portrait else 32
	var section_font := roundi(33.0 * portrait_scale) if portrait else 18
	var body_font := roundi(27.0 * portrait_scale) if portrait else 15
	var meta_font := roundi(22.0 * portrait_scale) if portrait else 13
	var button_font := roundi(33.0 * portrait_scale) if portrait else 18
	var input_font := roundi(29.0 * portrait_scale) if portrait else 15
	var primary_height := 116.0 * portrait_scale if portrait else 52.0
	var secondary_height := 104.0 * portrait_scale if portrait else 44.0
	var input_height := 98.0 * portrait_scale if portrait else 38.0
	var list_height := 174.0 * portrait_scale if portrait else 76.0
	var section_gap := roundi(22.0 * portrait_scale) if portrait else 10
	return {
		"viewport_size": size,
		"resolved_mode": resolved,
		"is_portrait": portrait,
		"is_mobile_like": is_mobile_like,
		"portrait_scale": portrait_scale,
		"safe_rect": Rect2(Vector2.ZERO, size),
		"content_width": content_width,
		"page_margin": margin,
		"section_gap": section_gap,
		"title_font_size": title_font,
		"section_font_size": section_font,
		"body_font_size": body_font,
		"meta_font_size": meta_font,
		"button_font_size": button_font,
		"input_font_size": input_font,
		"primary_button_height": primary_height,
		"secondary_button_height": secondary_height,
		"input_height": input_height,
		"list_item_min_height": list_height,
	}


func default_layout_mode_for_runtime(
	os_name: String = "",
	feature_flags: Dictionary = {},
	display_server_name: String = "",
	viewport_size: Vector2 = Vector2.ZERO,
	user_agent: String = ""
) -> String:
	return LAYOUT_PORTRAIT if is_mobile_browser_or_device(os_name, feature_flags, display_server_name, viewport_size, user_agent) else LAYOUT_LANDSCAPE


func is_mobile_browser_or_device(
	os_name: String = "",
	feature_flags: Dictionary = {},
	display_server_name: String = "",
	viewport_size: Vector2 = Vector2.ZERO,
	user_agent: String = ""
) -> bool:
	var resolved_os := os_name.strip_edges().to_lower()
	if resolved_os in ["android", "ios"]:
		return true
	for feature: String in ["mobile", "android", "ios", "web_android", "web_ios"]:
		if bool(feature_flags.get(feature, false)):
			return true

	var ua := user_agent.strip_edges().to_lower()
	if ua != "":
		for token: String in ["android", "iphone", "ipad", "ipod", "mobile safari", "mobile"]:
			if token in ua:
				return true

	var resolved_display := display_server_name.strip_edges().to_lower()
	var web_like := resolved_os in ["web", "html5"] or resolved_display in ["web", "html5"] or bool(feature_flags.get("web", false))
	if not web_like:
		return false
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return false
	if viewport_size.y > viewport_size.x:
		return true
	return viewport_size.x <= PORTRAIT_PHONE_WIDTH_THRESHOLD and viewport_size.y <= 1200.0
