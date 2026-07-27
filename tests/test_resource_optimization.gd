class_name TestResourceOptimization
extends TestBase


const RUNTIME_UI_IMAGE_PROFILES := {
	"res://assets/ui/vstar.png": Vector2i(768, 256),
	"res://assets/ui/vstar1.png": Vector2i(768, 256),
	"res://assets/ui/vstar2.png": Vector2i(768, 256),
	"res://assets/ui/coin_heads.png": Vector2i(512, 512),
	"res://assets/ui/coin_tails.png": Vector2i(512, 512),
	"res://assets/ui/e-cao.png": Vector2i(256, 256),
	"res://assets/ui/e-chao.png": Vector2i(256, 256),
	"res://assets/ui/e-dou.png": Vector2i(256, 256),
	"res://assets/ui/e-e.png": Vector2i(256, 256),
	"res://assets/ui/e-gang.png": Vector2i(256, 256),
	"res://assets/ui/e-huo.png": Vector2i(256, 256),
	"res://assets/ui/e-lei.png": Vector2i(256, 256),
	"res://assets/ui/e-long.png": Vector2i(256, 256),
	"res://assets/ui/e-shui.png": Vector2i(256, 256),
	"res://assets/ui/e-wu.png": Vector2i(256, 256),
}
const RUNTIME_UI_IMAGE_SOURCE_BUDGET_BYTES := 3 * 1024 * 1024
const LOSSY_FULL_SCREEN_TEXTURES := [
	"res://assets/ui/title.png",
	"res://assets/ui/title_portrait.png",
	"res://assets/ui/gamesbackground.png",
	"res://assets/ui/background.png",
	"res://assets/ui/background1.png",
	"res://assets/ui/background2.png",
	"res://assets/ui/background3.png",
	"res://assets/ui/background4.png",
]


func test_runtime_ui_images_stay_display_sized_and_loadable() -> String:
	var checks: Array[String] = []
	var total_source_bytes := 0
	for path: String in RUNTIME_UI_IMAGE_PROFILES:
		var expected_size: Vector2i = RUNTIME_UI_IMAGE_PROFILES[path]
		var texture := load(path) as Texture2D
		checks.append(assert_not_null(texture, "%s should load as a Godot texture" % path))
		if texture != null:
			checks.append(assert_eq(Vector2i(texture.get_size()), expected_size, "%s should stay within its runtime display-size profile" % path))
		var file := FileAccess.open(path, FileAccess.READ)
		checks.append(assert_not_null(file, "%s source image should exist" % path))
		if file != null:
			total_source_bytes += file.get_length()
			file.close()
	checks.append(assert_true(
		total_source_bytes <= RUNTIME_UI_IMAGE_SOURCE_BUDGET_BYTES,
		"Display-sized VSTAR, Energy, and coin images should stay within the 3 MiB source budget"
	))
	return run_checks(checks)


func test_full_screen_art_uses_high_quality_lossy_import_compression() -> String:
	var checks: Array[String] = []
	for texture_path: String in LOSSY_FULL_SCREEN_TEXTURES:
		var import_text := FileAccess.get_file_as_string("%s.import" % texture_path)
		checks.append(assert_true(import_text.contains("compress/mode=1"), "%s should use lossy texture import compression" % texture_path))
		var quality := _import_float_value(import_text, "compress/lossy_quality", 0.0)
		checks.append(assert_true(quality >= 0.85, "%s should preserve high-quality full-screen art" % texture_path))
	return run_checks(checks)


func _import_float_value(import_text: String, key: String, fallback: float) -> float:
	for line: String in import_text.split("\n"):
		if line.begins_with("%s=" % key):
			return line.trim_prefix("%s=" % key).strip_edges().to_float()
	return fallback
