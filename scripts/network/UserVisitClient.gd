class_name UserVisitClient
extends Node

const AppVersionScript := preload("res://scripts/app/AppVersion.gd")

const ENDPOINT_URL := "http://fc.skillserver.cn/userptcg"
const WEB_BRIDGE_PAGE := "userptcg_bridge.html"
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


static func endpoint_url_for_runtime(os_name: String = "", feature_flags: Dictionary = {}, display_server_name: String = "") -> String:
	if _is_web_runtime_for_context(os_name, feature_flags, display_server_name):
		return WEB_BRIDGE_PAGE
	return ENDPOINT_URL


static func request_headers_for_runtime(os_name: String = "", feature_flags: Dictionary = {}, display_server_name: String = "") -> PackedStringArray:
	var headers := PackedStringArray(["Content-Type: application/json; charset=utf-8"])
	if not _is_web_runtime_for_context(os_name, feature_flags, display_server_name):
		headers.append("User-Agent: PTCGDeckAgent/%s" % AppVersionScript.VERSION)
	return headers


static func should_use_threaded_request_for_runtime(os_name: String = "", feature_flags: Dictionary = {}, display_server_name: String = "") -> bool:
	return not _is_web_runtime_for_context(os_name, feature_flags, display_server_name)


func report_startup_visit(metadata: Dictionary = {}) -> int:
	if _is_reporting:
		return ERR_BUSY
	if _is_web_runtime_for_context():
		return _report_startup_visit_via_web_bridge(metadata)

	_ensure_http_request()
	if _http_request == null:
		visit_failed.emit("cannot create visit request")
		return ERR_CANT_CREATE

	var body := JSON.stringify(build_payload(_with_runtime_display_metadata(metadata)))
	var headers := request_headers_for_runtime()
	var endpoint_url := endpoint_url_for_runtime()

	_is_reporting = true
	var err := _http_request.request(endpoint_url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		_is_reporting = false
		visit_failed.emit("visit report start failed: %d" % err)
	return err


func _report_startup_visit_via_web_bridge(metadata: Dictionary = {}) -> int:
	var payload := build_payload(_with_runtime_display_metadata(metadata))
	var payload_text := JSON.stringify(payload)
	var script := """
(function(payloadText) {
	try {
		if (typeof window === 'undefined' || typeof document === 'undefined') {
			return false;
		}
		var payload = JSON.parse(payloadText);
		var bridgeUrl = new URL('%s', window.location.href);
		bridgeUrl.hash = 'payload=' + encodeURIComponent(JSON.stringify(payload));
		var iframe = document.createElement('iframe');
		iframe.setAttribute('title', 'ptcg-user-visit-bridge');
		iframe.setAttribute('aria-hidden', 'true');
		iframe.style.position = 'fixed';
		iframe.style.left = '-1px';
		iframe.style.top = '-1px';
		iframe.style.width = '1px';
		iframe.style.height = '1px';
		iframe.style.opacity = '0';
		iframe.style.pointerEvents = 'none';
		iframe.style.border = '0';
		iframe.src = bridgeUrl.href;
		document.body.appendChild(iframe);
		window.setTimeout(function() {
			try {
				if (iframe.parentNode) {
					iframe.parentNode.removeChild(iframe);
				}
			} catch (_error) {}
		}, 15000);
		return true;
	} catch (error) {
		if (typeof console !== 'undefined' && console.warn) {
			console.warn('[UserVisit] static bridge failed', error);
		}
		return false;
	}
})(%s);
""" % [WEB_BRIDGE_PAGE, JSON.stringify(payload_text)]
	var result: Variant = JavaScriptBridge.eval(script, true)
	if bool(result):
		visit_recorded.emit({"ok": true, "transport": "web_static_html_bridge"})
		return OK
	visit_failed.emit("visit report web bridge failed")
	return ERR_CANT_CREATE


func _ready() -> void:
	_ensure_http_request()


func _ensure_http_request() -> void:
	if _http_request != null:
		return
	_http_request = HTTPRequest.new()
	_http_request.timeout = REQUEST_TIMEOUT_SECONDS
	_http_request.use_threads = should_use_threaded_request_for_runtime()
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
	payload["is_web_runtime"] = bool(metadata.get("is_web_runtime", _is_web_runtime_for_context()))
	payload["is_mobile_runtime"] = bool(metadata.get("is_mobile_runtime", _is_mobile_runtime_for_context()))


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


static func _is_web_runtime_for_context(os_name: String = "", feature_flags: Dictionary = {}, display_server_name: String = "") -> bool:
	var resolved_os := os_name.strip_edges().to_lower()
	var resolved_display := display_server_name.strip_edges().to_lower()
	var flags := feature_flags
	if flags.is_empty() and os_name == "" and display_server_name == "":
		flags = _runtime_feature_flags()
		resolved_os = OS.get_name().strip_edges().to_lower()
		resolved_display = DisplayServer.get_name().strip_edges().to_lower()
	if resolved_os in ["web", "html5"] or resolved_display in ["web", "html5"]:
		return true
	for feature: String in ["web", "web_android", "web_ios"]:
		if bool(flags.get(feature, false)):
			return true
	return false


static func _is_mobile_runtime_for_context(os_name: String = "", feature_flags: Dictionary = {}) -> bool:
	var resolved_os := os_name.strip_edges().to_lower()
	if resolved_os in ["android", "ios"]:
		return true
	var flags := feature_flags
	if flags.is_empty() and os_name == "":
		flags = _runtime_feature_flags()
	for feature: String in ["mobile", "android", "ios", "web_android", "web_ios"]:
		if bool(flags.get(feature, false)):
			return true
	return false


static func _runtime_feature_flags() -> Dictionary:
	return {
		"mobile": OS.has_feature("mobile"),
		"android": OS.has_feature("android"),
		"ios": OS.has_feature("ios"),
		"web": OS.has_feature("web"),
		"web_android": OS.has_feature("web_android"),
		"web_ios": OS.has_feature("web_ios"),
	}


static func _make_event_id(prefix: String) -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return "%s-%d-%d-%d" % [
		prefix,
		int(Time.get_unix_time_from_system()),
		int(Time.get_ticks_usec()),
		int(rng.randi()),
	]
