class_name UserVisitClient
extends Node

const AppVersionScript := preload("res://scripts/app/AppVersion.gd")

const ENDPOINT_URL := "http://fc.skillserver.cn/userptcg"
const REQUEST_TIMEOUT_SECONDS := 6.0
const STATE_PATH := "user://ptcg_user_state.json"

signal visit_recorded(response: Dictionary)
signal visit_failed(message: String)

var _http_request: HTTPRequest = null
var _is_reporting := false


static func build_payload(metadata: Dictionary = {}) -> Dictionary:
	var payload := {
		"visit_id": str(metadata.get("visit_id", _make_event_id("visit"))),
		"client_id": str(metadata.get("client_id", _load_or_create_client_id())),
		"source": str(metadata.get("source", "startup")),
		"app_version": str(metadata.get("app_version", AppVersionScript.DISPLAY_VERSION)),
		"version": str(metadata.get("version", AppVersionScript.VERSION)),
		"build_number": int(metadata.get("build_number", AppVersionScript.BUILD_NUMBER)),
		"channel": str(metadata.get("channel", AppVersionScript.CHANNEL)),
		"platform": str(metadata.get("platform", OS.get_name())),
		"locale": str(metadata.get("locale", TranslationServer.get_locale())),
		"engine_version": str(metadata.get("engine_version", Engine.get_version_info().get("string", ""))),
		"reported_at": int(metadata.get("reported_at", Time.get_unix_time_from_system())),
	}
	_append_display_payload(payload, metadata)
	return payload


func report_startup_visit(metadata: Dictionary = {}) -> int:
	if _is_reporting:
		return ERR_BUSY

	_ensure_http_request()
	if _http_request == null:
		visit_failed.emit("cannot create visit request")
		return ERR_CANT_CREATE

	var body := JSON.stringify(build_payload(_with_runtime_display_metadata(metadata)))
	var headers := PackedStringArray([
		"Content-Type: application/json; charset=utf-8",
		"User-Agent: PTCGDeckAgent/%s" % AppVersionScript.VERSION,
	])

	_is_reporting = true
	var err := _http_request.request(ENDPOINT_URL, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		_is_reporting = false
		visit_failed.emit("visit report start failed: %d" % err)
	return err


func _ready() -> void:
	_ensure_http_request()


func _ensure_http_request() -> void:
	if _http_request != null:
		return
	_http_request = HTTPRequest.new()
	_http_request.timeout = REQUEST_TIMEOUT_SECONDS
	_http_request.use_threads = true
	_http_request.request_completed.connect(_on_visit_response)
	add_child(_http_request)


func _on_visit_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_is_reporting = false
	if result != HTTPRequest.RESULT_SUCCESS:
		visit_failed.emit("visit report failed: result=%d" % result)
		return
	if response_code < 200 or response_code >= 300:
		visit_failed.emit("visit server returned HTTP %d" % response_code)
		return

	var response_text := body.get_string_from_utf8()
	if response_text.strip_edges() == "":
		visit_recorded.emit({"ok": true})
		return

	var json := JSON.new()
	var parse_err := json.parse(response_text)
	if parse_err != OK or not (json.data is Dictionary):
		visit_recorded.emit({"ok": true, "raw": response_text.left(200)})
		return

	var response := json.data as Dictionary
	if response.has("ok") and not bool(response.get("ok", false)):
		visit_failed.emit(str(response.get("message", "visit server rejected request")))
		return

	visit_recorded.emit(response)


static func _load_or_create_client_id() -> String:
	var existing := _load_client_id()
	if existing != "":
		return existing
	var next_id := _make_event_id("client")
	_save_client_id(next_id)
	return next_id


static func _load_client_id() -> String:
	if not FileAccess.file_exists(STATE_PATH):
		return ""
	var file := FileAccess.open(STATE_PATH, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return ""
	return str((json.data as Dictionary).get("client_id", "")).strip_edges()


static func _save_client_id(client_id: String) -> void:
	var file := FileAccess.open(STATE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"client_id": client_id,
		"created_at": int(Time.get_unix_time_from_system()),
	}, "\t"))
	file.close()


static func _append_display_payload(payload: Dictionary, metadata: Dictionary) -> void:
	var screen_size := _current_screen_size()
	var usable_size := _current_screen_usable_size()
	var window_size := _current_window_size()
	payload["display_server"] = str(metadata.get("display_server", DisplayServer.get_name()))
	payload["screen_width"] = _metadata_dimension(metadata, "screen_width", screen_size.x)
	payload["screen_height"] = _metadata_dimension(metadata, "screen_height", screen_size.y)
	payload["screen_usable_width"] = _metadata_dimension(metadata, "screen_usable_width", usable_size.x)
	payload["screen_usable_height"] = _metadata_dimension(metadata, "screen_usable_height", usable_size.y)
	payload["window_width"] = _metadata_dimension(metadata, "window_width", window_size.x)
	payload["window_height"] = _metadata_dimension(metadata, "window_height", window_size.y)
	payload["viewport_width"] = _metadata_dimension(metadata, "viewport_width", 0)
	payload["viewport_height"] = _metadata_dimension(metadata, "viewport_height", 0)
	payload["screen_orientation"] = str(metadata.get("screen_orientation", _orientation_from_size(Vector2i(
		int(payload.get("screen_width", 0)),
		int(payload.get("screen_height", 0))
	))))
	payload["is_mobile_runtime"] = bool(metadata.get("is_mobile_runtime", OS.get_name() in ["Android", "iOS"]))


func _with_runtime_display_metadata(metadata: Dictionary) -> Dictionary:
	var enriched := metadata.duplicate(true)
	if not enriched.has("viewport_width") or not enriched.has("viewport_height"):
		var viewport := get_viewport()
		if viewport != null:
			var viewport_size := viewport.get_visible_rect().size
			if not enriched.has("viewport_width"):
				enriched["viewport_width"] = int(roundf(viewport_size.x))
			if not enriched.has("viewport_height"):
				enriched["viewport_height"] = int(roundf(viewport_size.y))
	if not enriched.has("screen_orientation"):
		var size := Vector2i(
			int(enriched.get("screen_width", 0)),
			int(enriched.get("screen_height", 0))
		)
		if size.x <= 0 or size.y <= 0:
			size = _current_screen_size()
		enriched["screen_orientation"] = _orientation_from_size(size)
	return enriched


static func _metadata_dimension(metadata: Dictionary, key: String, fallback: int) -> int:
	return maxi(0, int(metadata.get(key, fallback)))


static func _current_screen_size() -> Vector2i:
	if DisplayServer.get_name() == "headless":
		return Vector2i.ZERO
	return DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())


static func _current_screen_usable_size() -> Vector2i:
	if DisplayServer.get_name() == "headless":
		return Vector2i.ZERO
	return DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen()).size


static func _current_window_size() -> Vector2i:
	if DisplayServer.get_name() == "headless":
		return Vector2i.ZERO
	return DisplayServer.window_get_size()


static func _orientation_from_size(size: Vector2i) -> String:
	if size.x <= 0 or size.y <= 0:
		return "unknown"
	if size.y > size.x:
		return "portrait"
	if size.x > size.y:
		return "landscape"
	return "square"


static func _make_event_id(prefix: String) -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return "%s-%d-%d-%d" % [
		prefix,
		int(Time.get_unix_time_from_system()),
		int(Time.get_ticks_usec()),
		int(rng.randi()),
	]
