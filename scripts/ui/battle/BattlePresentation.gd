extends RefCounted
## Presentation is chosen for the next battle; a running scene pins its mode.
const ThemeScript := preload("res://scenes/arena3d/ArenaTheme.gd")
const GROVE_FIELD := "res://assets/arena3d/previews/grove.png"
const ARENA_FIELDS := {
	# Legacy saved identity only; the removed preview is never loaded.
	"res://assets/arena3d/previews/league.png": "grove",
	"res://assets/arena3d/previews/grove.png": "grove",
}

static func fields_3d_available() -> bool:
	if OS.has_feature("dedicated_server"):
		return false
	var profile := GameManager.get_ui_runtime_profile()
	if profile != null:
		return profile.is_web() or profile.native_os in [UiRuntimeProfile.OS_WINDOWS,UiRuntimeProfile.OS_ANDROID,UiRuntimeProfile.OS_MACOS]
	return OS.get_name() in ["Windows","Android","macOS","Web"]

static func field_theme(path: String) -> String:
	return str(ARENA_FIELDS.get(path, ""))

static func selected_theme() -> String:
	var theme := field_theme(GameManager.selected_battle_background)
	return theme if theme != "" else ThemeScript.current()

static func requested_3d() -> bool:
	if not fields_3d_available():
		return false
	if "--battle-2d" in OS.get_cmdline_user_args():
		return false
	return GameManager.battle_3d_enabled or bool(ProjectSettings.get_setting("arena3d/enabled", false)) or "--arena-3d" in OS.get_cmdline_user_args()

static func is_3d_scene(scene: Object) -> bool:
	return is_instance_valid(scene) and bool(scene.get_meta("arena3d_active", false))

static func legacy_effects_enabled(scene: Object) -> bool:
	return bool(GameManager.battle_effects_enabled) and not is_3d_scene(scene)
