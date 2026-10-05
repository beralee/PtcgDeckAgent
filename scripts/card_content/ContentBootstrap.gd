extends Node
## MUST remain the first autoload; no game scripts may be preloaded here.
const Store := preload("res://scripts/card_content/ContentStore.gd")
const Manifest := preload("res://scripts/card_content/ContentManifest.gd")
var store: RefCounted
var _fatal := false

static func is_enabled() -> bool:
	# Release-owned gate; player preferences and downloaded packs cannot enable it.
	return bool(ProjectSettings.get_setting("ptcgdap/card_content/enabled", false))

func _init() -> void:
	Engine.set_meta("ptcg_card_content_snapshot", {})
	if not is_enabled(): return
	var trust: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/card_content/trust.json"))
	if not trust is Dictionary: trust = {}
	store = Store.new("user://card_content", trust, str(ProjectSettings.get_setting("application/config/version", "0.0.0")), platform())
	var checked: Dictionary = store.prepare_boot()
	if not checked.get("ok", false):
		Engine.set_meta("ptcg_card_content_error", checked.get("error_code", "storage_failed"))
		return
	if not checked.get("manifest", {}).is_empty():
		var engine_version := Engine.get_version_info()
		if engine_version.major != 4 or engine_version.minor != 6:
			_fatal = true
			return
		for pack: Dictionary in checked.manifest.packs:
			if not ProjectSettings.load_resource_pack(store.object_path(pack.sha256), true):
				_fatal = true
				return
	Engine.set_meta("ptcg_card_content_snapshot", checked)

func _enter_tree() -> void:
	if _fatal:
		push_error("Card content could not mount; next launch restores the previous snapshot.")
		get_tree().quit(78)

func confirm_boot() -> void:
	if is_enabled() and not _fatal and store != null: store.confirm_boot()

static func platform() -> String:
	if OS.has_feature("web"): return "web"
	return {"Windows": "windows", "Android": "android", "Linux": "linux", "macOS": "macos"}.get(OS.get_name(), "unsupported")
