extends SceneTree

const CardDatabaseScript := preload("res://scripts/autoload/CardDatabase.gd")
const CardImageCacheServiceScript := preload("res://scripts/card_images/CardImageCacheService.gd")

var _service: Node = null
var _card: CardData = null
var _job_id := ""
var _manifest_path := ""


func _initialize() -> void:
	print("CSV4C_015 download probe: initialize")
	_service = CardImageCacheServiceScript.new()
	root.add_child(_service)
	call_deferred("_run")


func _run() -> void:
	print("CSV4C_015 download probe: run")
	var db := CardDatabaseScript.new()
	var card: CardData = db.get_card("CSV4C", "015")
	db.free()
	if card == null:
		push_error("CSV4C_015 is missing from the catalog")
		quit(1)
		return
	_remove_file(card.image_local_path)
	_card = card
	_manifest_path = "res://.godot_test_user/catalog_image_download_manifest.json"
	_remove_file(_manifest_path)
	_service.call("set_manifest_path_for_tests", _manifest_path)
	_service.connect("job_completed", Callable(self, "_on_job_completed"))
	print("CSV4C_015 download probe: starting request %s" % card.image_url)
	_job_id = str(_service.call("ensure_image_with_options", card, {
		"priority": 10,
		"reason": "catalog_download_probe",
		"allow_remote": true,
	}))
	print("CSV4C_015 download probe: job=%s" % _job_id)
	await create_timer(35.0).timeout
	push_error("CSV4C_015 image download timed out")
	_cleanup()
	quit(1)


func _on_job_completed(job_id: String, stats: Dictionary, errors: PackedStringArray) -> void:
	if job_id != _job_id or _card == null:
		return
	var ready := CardData.is_valid_card_image_file(_card.image_local_path)
	print("CSV4C_015 download probe: ready=%s stats=%s errors=%s" % [ready, stats, errors])
	_cleanup()
	quit(0 if ready and int(stats.get("downloaded", 0)) == 1 else 1)


func _cleanup() -> void:
	if _card != null:
		_remove_file(_card.image_local_path)
	_remove_file(_manifest_path)


func _remove_file(path: String) -> void:
	if path == "":
		return
	var absolute := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path) or FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)
