class_name BattleLayoutController
extends RefCounted

const LAYOUT_AUTO := "auto"
const LAYOUT_LANDSCAPE := "landscape"
const LAYOUT_PORTRAIT := "portrait"
const PORTRAIT_PHONE_WIDTH_THRESHOLD := 720.0
const PORTRAIT_REFERENCE_LOGICAL_WIDTH := 900.0
const PORTRAIT_CONTENT_ASPECT := 9.0 / 16.0
const PORTRAIT_EXPANDED_HAND_VISIBLE_CARDS := 6
const PORTRAIT_EXPANDED_ACTIVE_HEIGHT_SCALE := 1.10
const PORTRAIT_TOP_BAR_HEIGHT := 104.0
const PORTRAIT_TOP_BAR_GAP := 4.0
const PORTRAIT_TOP_BAR_TOP_PADDING := 4.0
const PORTRAIT_STADIUM_HEIGHT := 64.0


func resolve_layout_mode(viewport_size: Vector2, preferred_mode: String, is_mobile: bool = false) -> String:
	match preferred_mode:
		LAYOUT_LANDSCAPE, LAYOUT_PORTRAIT:
			return preferred_mode
	if viewport_size.y > viewport_size.x:
		return LAYOUT_PORTRAIT
	if is_mobile and viewport_size.x < PORTRAIT_PHONE_WIDTH_THRESHOLD:
		return LAYOUT_PORTRAIT
	return LAYOUT_LANDSCAPE


func measure_card_layout(
	viewport_size: Vector2,
	center_width: float,
	bench_spacing: float,
	bench_size: int,
	card_aspect: float
) -> Dictionary:
	var play_h := compute_play_card_height(viewport_size, center_width, bench_spacing, bench_size, card_aspect)
	var dialog_h: float = clampf(viewport_size.y * 0.24, 148.0, 220.0)
	var detail_h: float = clampf(viewport_size.y * 0.5, 260.0, 460.0)
	var play_card_size := Vector2(round(play_h * card_aspect), round(play_h))
	var dialog_card_size := Vector2(round(dialog_h * card_aspect), round(dialog_h))
	var detail_card_size := Vector2(round(detail_h * card_aspect), round(detail_h))
	var preview_card_size := Vector2(roundf(play_card_size.x * 0.9), roundf(play_card_size.y * 0.9))
	var stadium_height: float = roundf(clampf(viewport_size.y * 0.082, 54.0, 72.0) * (4.0 / 9.0))
	return {
		"play_card_size": play_card_size,
		"dialog_card_size": dialog_card_size,
		"detail_card_size": detail_card_size,
		"preview_card_size": preview_card_size,
		"prize_slot_size": preview_card_size,
		"stadium_height": stadium_height,
		"stadium_inner_vpad": clampi(int(stadium_height * 0.08), 1, 3),
		"vstar_stack_gap": clampi(int(stadium_height * 0.08), 1, 2),
		"vstar_panel_vpad": clampi(int(stadium_height * 0.06), 1, 2),
		"prize_panel_height": roundf((preview_card_size.y * 2.0 + 24.0) * 0.95),
	}


func compute_play_card_height(
	viewport_size: Vector2,
	center_width: float,
	bench_spacing: float,
	bench_size: int,
	card_aspect: float
) -> float:
	var reserved_vertical := \
		clampf(viewport_size.y * 0.042, 26.0, 38.0) + \
		clampf(viewport_size.y * 0.032, 24.0, 34.0) + \
		92.0
	var height_limited := (viewport_size.y - reserved_vertical) / 5.0

	var bench_row_padding := 40.0
	var usable_center_width := maxf(center_width - bench_row_padding, 0.0)
	var width_limited := (usable_center_width - float(bench_size - 1) * bench_spacing) / maxf(float(bench_size) * card_aspect, 1.0)

	var min_card_height := 82.0 if bench_size > 5 else 112.0
	var max_card_height := 176.0 if bench_size > 5 else 192.0
	var hud_width_limited := compute_landscape_hud_safe_card_height(center_width, card_aspect)
	if hud_width_limited > 0.0 and hud_width_limited < min_card_height:
		min_card_height = maxf(82.0, hud_width_limited)
	var total_width_limited := width_limited
	if hud_width_limited > 0.0:
		total_width_limited = minf(total_width_limited, hud_width_limited)
	return clampf(minf(height_limited, total_width_limited), min_card_height, max_card_height)


func compute_landscape_hud_safe_card_height(center_width: float, card_aspect: float) -> float:
	if center_width <= 0.0 or card_aspect <= 0.0:
		return 0.0
	# Horizontal field rows contain prize HUD, active/bench axis, pile HUDs, and shell gaps.
	# The bench row width alone does not protect low-height 20:9 phones or narrow 4:3
	# tablet canvases from pushing the prize HUD outside the touchable viewport.
	var prize_factor := 3.0 * 0.9 * card_aspect
	var field_axis_factor := 6.2 * card_aspect
	var pile_factor := 2.0 * 0.9 * card_aspect
	var fixed_chrome := 78.0
	var total_factor := maxf(prize_factor + field_axis_factor + pile_factor, 1.0)
	return maxf((center_width - fixed_chrome) / total_factor, 0.0)


func measure_portrait_card_layout(
	viewport_size: Vector2,
	bench_capacity: int,
	card_aspect: float
) -> Dictionary:
	var ui_scale := portrait_layout_scale(viewport_size)
	var expanded_bench := bench_capacity > 5
	var columns := 4 if expanded_bench else mini(maxi(bench_capacity, 1), 5)
	var rows := ceili(float(maxi(bench_capacity, 1)) / float(columns))
	var horizontal_padding := clampf(viewport_size.x * 0.024, 8.0 * ui_scale, 16.0 * ui_scale)
	var bench_gap := clampf(viewport_size.x * (0.006 if expanded_bench else 0.008), 2.0 * ui_scale, 6.0 * ui_scale)
	var usable_bench_width := maxf(viewport_size.x - horizontal_padding - float(columns - 1) * bench_gap, 0.0)
	var bench_width := floorf(usable_bench_width / float(columns))
	var width_limited_bench_height := floorf(bench_width / maxf(card_aspect, 0.1))
	var base_target_bench_height := clampf(roundf(viewport_size.y * 0.155), 104.0 * ui_scale, 290.0 * ui_scale)
	var base_active_height := clampf(roundf(viewport_size.y * 0.17), 170.0 * ui_scale, 300.0 * ui_scale)
	var base_hand_height := clampf(roundf(viewport_size.y * 0.142), 150.0 * ui_scale, 240.0 * ui_scale)
	var hand_height := base_hand_height
	var hand_visible_cards := PORTRAIT_EXPANDED_HAND_VISIBLE_CARDS if expanded_bench else 5
	var hand_gap_budget := 12.0
	var hand_outer_padding_budget := maxf(24.0 * ui_scale, viewport_size.x * 0.028)
	var hand_width_limited_height := floorf(
		maxf(viewport_size.x - hand_outer_padding_budget - float(hand_visible_cards - 1) * hand_gap_budget, 0.0)
		/ maxf(float(hand_visible_cards) * card_aspect, 1.0)
	)
	if expanded_bench:
		hand_height = minf(base_hand_height * 0.70, hand_width_limited_height)
		hand_height = clampf(hand_height, 48.0 * ui_scale, base_hand_height * 0.70)
	elif viewport_size.x >= 780.0:
		# Wide portrait phones/tablets should show five hand cards without forcing
		# the hand rail or bottom controls outside the visible safe width.
		hand_height = minf(base_hand_height, hand_width_limited_height)
	var field_scale := 1.0
	if expanded_bench:
		var default_field_height := base_active_height * 2.0 + base_target_bench_height * 2.0
		var expanded_field_height := base_active_height * 2.0 + base_target_bench_height * float(rows * 2)
		var default_hand_area_height := base_hand_height + 23.0 * ui_scale
		var expanded_hand_area_height := hand_height
		var reclaimed_hand_height := maxf(default_hand_area_height - expanded_hand_area_height, 0.0)
		field_scale = clampf((default_field_height + reclaimed_hand_height) / maxf(expanded_field_height, 1.0), 0.62, 1.0)
		var top_reserved := (PORTRAIT_TOP_BAR_TOP_PADDING + PORTRAIT_TOP_BAR_HEIGHT + PORTRAIT_TOP_BAR_GAP) * ui_scale
		var stadium_reserved := maxf(PORTRAIT_STADIUM_HEIGHT * ui_scale, 56.0)
		var center_separation_reserved := maxf(3.0 * ui_scale, 3.0)
		var field_budget := maxf(viewport_size.y - top_reserved - expanded_hand_area_height - center_separation_reserved, 1.0)
		var unscaled_pair_height := base_active_height * PORTRAIT_EXPANDED_ACTIVE_HEIGHT_SCALE + base_target_bench_height * float(rows)
		var vertical_scale := (field_budget - stadium_reserved - bench_gap * float(maxi(rows - 1, 0)) * 2.0) / maxf(unscaled_pair_height * 2.0, 1.0)
		field_scale = minf(field_scale, clampf(vertical_scale, 0.58, 1.0))
	var target_bench_height := base_target_bench_height * field_scale
	var bench_height := clampf(minf(width_limited_bench_height, target_bench_height), 58.0 * ui_scale if expanded_bench else 80.0 * ui_scale, 270.0 * ui_scale)
	bench_width = roundf(bench_height * card_aspect)

	var active_height := base_active_height * field_scale
	if expanded_bench:
		active_height *= PORTRAIT_EXPANDED_ACTIVE_HEIGHT_SCALE
	var dialog_height := clampf(roundf(viewport_size.y * 0.20), 170.0 * ui_scale, 300.0 * ui_scale)
	var detail_height := clampf(roundf(viewport_size.y * 0.42), 300.0 * ui_scale, 420.0 * ui_scale)
	var hand_area_height := hand_height if expanded_bench else -1.0
	var hand_scroll_height := hand_height if expanded_bench else -1.0

	return {
		"active_card_size": Vector2(roundf(active_height * card_aspect), active_height),
		"bench_card_size": Vector2(bench_width, bench_height),
		"hand_card_size": Vector2(roundf(hand_height * card_aspect), hand_height),
		"hand_visible_cards": hand_visible_cards,
		"hand_area_height": hand_area_height,
		"hand_scroll_height": hand_scroll_height,
		"dialog_card_size": Vector2(roundf(dialog_height * card_aspect), dialog_height),
		"detail_card_size": Vector2(roundf(detail_height * card_aspect), detail_height),
		"bench_columns": columns,
		"bench_rows": rows,
		"bench_gap": bench_gap,
		"horizontal_padding": horizontal_padding,
		"ui_scale": ui_scale,
	}


func portrait_layout_scale(viewport_size: Vector2) -> float:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return 1.0
	if viewport_size.x >= viewport_size.y:
		return 1.0
	# Android canvas_items+expand can keep a 1600px logical width in portrait.
	# Scale controls back up so their physical touch size matches the phone UI.
	return clampf(viewport_size.x / PORTRAIT_REFERENCE_LOGICAL_WIDTH, 1.0, 1.85)


func portrait_content_rect(viewport_size: Vector2) -> Rect2:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Rect2(Vector2.ZERO, viewport_size)
	var content_width := minf(viewport_size.x, roundf(viewport_size.y * PORTRAIT_CONTENT_ASPECT))
	var content_x := roundf((viewport_size.x - content_width) * 0.5)
	return Rect2(Vector2(content_x, 0.0), Vector2(content_width, viewport_size.y))


func apply_backdrop_rect(backdrop: TextureRect, viewport_size: Vector2, log_width: float) -> void:
	if backdrop == null:
		return
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.anchor_left = 0.0
	backdrop.anchor_top = 0.0
	backdrop.anchor_right = 0.0
	backdrop.anchor_bottom = 0.0
	backdrop.offset_left = 0.0
	backdrop.offset_top = 0.0
	backdrop.offset_right = viewport_size.x - log_width
	backdrop.offset_bottom = viewport_size.y


func apply_portrait_backdrop_rect(backdrop: TextureRect, viewport_size: Vector2) -> void:
	if backdrop == null:
		return
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.anchor_left = 0.0
	backdrop.anchor_top = 0.0
	backdrop.anchor_right = 0.0
	backdrop.anchor_bottom = 0.0
	backdrop.offset_left = 0.0
	backdrop.offset_top = 0.0
	backdrop.offset_right = viewport_size.x
	backdrop.offset_bottom = viewport_size.y


func load_battle_backdrop_texture(selected_backdrop_path: String, default_backdrop_path: String) -> Texture2D:
	var backdrop_path := resolve_backdrop_path(selected_backdrop_path, default_backdrop_path)
	if ResourceLoader.exists(backdrop_path):
		var backdrop_res := load(backdrop_path)
		if backdrop_res is Texture2D:
			return backdrop_res as Texture2D
	if FileAccess.file_exists(backdrop_path):
		var image := Image.load_from_file(ProjectSettings.globalize_path(backdrop_path))
		if image != null and not image.is_empty():
			return ImageTexture.create_from_image(image)

	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color("07131d"),
		Color("102634"),
		Color("16394a"),
		Color("0b1825"),
	])
	gradient.offsets = PackedFloat32Array([0.0, 0.35, 0.7, 1.0])

	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 32
	texture.height = 640
	texture.fill = GradientTexture2D.FILL_LINEAR
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(1.0, 1.0)
	return texture


func resolve_backdrop_path(selected_backdrop_path: String, default_backdrop_path: String) -> String:
	if selected_backdrop_path != "" and (ResourceLoader.exists(selected_backdrop_path) or FileAccess.file_exists(selected_backdrop_path)):
		return selected_backdrop_path
	return default_backdrop_path


func load_card_back_texture(resource_path: String, is_player_side: bool) -> Texture2D:
	if ResourceLoader.exists(resource_path):
		var texture_res := load(resource_path)
		if texture_res is Texture2D:
			return texture_res as Texture2D

	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color("0a1d30") if is_player_side else Color("1b0714"),
		Color("174d7a") if is_player_side else Color("4d1540"),
		Color("f3d86b") if is_player_side else Color("ff93c9"),
		Color("07111d") if is_player_side else Color("10060f"),
	])
	gradient.offsets = PackedFloat32Array([0.0, 0.42, 0.78, 1.0])

	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 356
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.35)
	texture.fill_to = Vector2(1.0, 1.0)
	return texture
