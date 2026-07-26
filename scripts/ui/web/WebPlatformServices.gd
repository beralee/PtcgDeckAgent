class_name WebPlatformServices
extends RefCounted

const UiRuntimeProfileResolverScript := preload("res://scripts/ui/runtime/UiRuntimeProfileResolver.gd")

var _clipboard_callback: Variant = null
var _clipboard_callback_name: String = ""
var _clipboard_generation: int = 0
var _pending_clipboard_requests: Dictionary = {}
var _test_force_web: bool = false


func set_test_force_web(enabled: bool) -> void:
	_test_force_web = enabled


func request_clipboard_text(result_callback: Callable) -> bool:
	if not result_callback.is_valid() or not is_web_runtime():
		return false
	_clipboard_generation += 1
	var request_id := _clipboard_generation
	_pending_clipboard_requests[request_id] = result_callback
	if _test_force_web:
		return true
	if not _ensure_clipboard_callback():
		_pending_clipboard_requests.erase(request_id)
		return false
	var result: Variant = JavaScriptBridge.eval(
		build_clipboard_read_script(_clipboard_callback_name, request_id),
		true
	)
	if not bool(result):
		_pending_clipboard_requests.erase(request_id)
	return bool(result)


func deliver_clipboard_result_for_tests(request_id: int, payload: Dictionary) -> bool:
	return _deliver_clipboard_result(request_id, payload)


func latest_clipboard_request_id_for_tests() -> int:
	return _clipboard_generation


func shutdown() -> void:
	_clipboard_generation += 1
	_pending_clipboard_requests.clear()
	if _clipboard_callback_name != "" and not _test_force_web and is_web_runtime():
		JavaScriptBridge.eval(build_callback_cleanup_script(_clipboard_callback_name), true)
	_clipboard_callback = null
	_clipboard_callback_name = ""


func is_web_runtime(os_name: String = "", feature_flags: Dictionary = {}, display_server_name: String = "") -> bool:
	if _test_force_web and os_name == "" and feature_flags.is_empty() and display_server_name == "":
		return true
	var flags := feature_flags
	var resolved_os := os_name
	var resolved_display := display_server_name
	if flags.is_empty() and os_name == "" and display_server_name == "":
		flags = UiRuntimeProfileResolverScript.runtime_feature_flags()
		resolved_os = OS.get_name()
		resolved_display = DisplayServer.get_name()
	var profile: UiRuntimeProfile = UiRuntimeProfileResolverScript.resolve(
		resolved_os, flags, resolved_display, Vector2.ZERO
	)
	return profile.is_web()


static func build_clipboard_read_script(callback_name: String, request_id: int) -> String:
	var callback_json := JSON.stringify(callback_name)
	return """
(function() {
  var callbackName = __CALLBACK_NAME__;
  var requestId = __REQUEST_ID__;
  function finish(payload) {
    try {
      var callback = window[callbackName];
      if (typeof callback === 'function') {
        callback(JSON.stringify({ request_id: requestId, payload: payload || {} }));
      }
    } catch (_error) {}
  }
  try {
    if (!navigator.clipboard || typeof navigator.clipboard.readText !== 'function') {
      finish({ ok: false, error: 'clipboard API unavailable' });
      return false;
    }
    navigator.clipboard.readText().then(function(text) {
      finish({ ok: true, text: String(text || '') });
    }).catch(function(error) {
      finish({ ok: false, error: String(error && error.message ? error.message : error) });
    });
    return true;
  } catch (error) {
    finish({ ok: false, error: String(error && error.message ? error.message : error) });
    return false;
  }
})();
""".replace("__CALLBACK_NAME__", callback_json).replace("__REQUEST_ID__", str(request_id))


static func build_callback_cleanup_script(callback_name: String) -> String:
	return """
(function() {
  try { delete window[__CALLBACK_NAME__]; } catch (_error) { window[__CALLBACK_NAME__] = null; }
  return true;
})();
""".replace("__CALLBACK_NAME__", JSON.stringify(callback_name))


func _ensure_clipboard_callback() -> bool:
	var window := JavaScriptBridge.get_interface("window")
	if window == null:
		return false
	if _clipboard_callback == null:
		_clipboard_callback_name = "__ptcgDeckAgentClipboardCallback_%d" % get_instance_id()
		_clipboard_callback = JavaScriptBridge.create_callback(_on_clipboard_javascript_result)
	window.set(_clipboard_callback_name, _clipboard_callback)
	return true


func _on_clipboard_javascript_result(args: Array) -> void:
	if args.is_empty():
		return
	var parsed: Variant = JSON.parse_string(str(args[0]))
	if not (parsed is Dictionary):
		return
	var message := parsed as Dictionary
	var payload_variant: Variant = message.get("payload", {})
	var payload: Dictionary = payload_variant as Dictionary if payload_variant is Dictionary else {}
	_deliver_clipboard_result(int(message.get("request_id", -1)), payload)


func _deliver_clipboard_result(request_id: int, payload: Dictionary) -> bool:
	if not _pending_clipboard_requests.has(request_id):
		return false
	var callback: Callable = _pending_clipboard_requests[request_id] as Callable
	_pending_clipboard_requests.erase(request_id)
	if not callback.is_valid():
		return false
	callback.call(payload.duplicate(true))
	return true
