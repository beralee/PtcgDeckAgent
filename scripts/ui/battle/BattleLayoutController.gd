class_name BattleLayoutController
extends RefCounted


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

	return clampf(minf(height_limited, width_limited), 112.0, 192.0)


func apply_backdrop_rect(backdrop: TextureRect, viewport_size: Vector2, log_width: float) -> void:
	if backdrop == null:
		return
	backdrop.anchor_left = 0.0
	backdrop.anchor_top = 0.0
	backdrop.anchor_right = 0.0
	backdrop.anchor_bottom = 0.0
	backdrop.offset_left = 0.0
	backdrop.offset_top = 0.0
	backdrop.offset_right = viewport_size.x - log_width
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
