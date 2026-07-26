class_name BrowserLifecycleBridge
extends Node

signal event_received(event_name: String, payload: Dictionary)
signal transient_input_cancel_requested(reason: String)
signal viewport_change_requested(payload: Dictionary)
signal runtime_error_received(error_kind: String, payload: Dictionary)

const CALLBACK_NAME := "__ptcgDeckAgentLifecycleCallback"
const BRIDGE_NAME := "__ptcgDeckAgentLifecycleBridge"

var _installed: bool = false
var _generation: int = 0
var _callback: Variant = null
var _test_force_web: bool = false
var _last_event: Dictionary = {}


func _exit_tree() -> void:
	uninstall()


func set_test_force_web(enabled: bool) -> void:
	_test_force_web = enabled


func install() -> bool:
	if _installed:
		return true
	if not _is_web_runtime():
		return false
	_generation += 1
	if _test_force_web:
		_installed = true
		return true
	var window := JavaScriptBridge.get_interface("window")
	if window == null:
		return false
	_callback = JavaScriptBridge.create_callback(_on_javascript_event)
	window.set(CALLBACK_NAME, _callback)
	var result: Variant = JavaScriptBridge.eval(build_install_script(CALLBACK_NAME, _generation), true)
	_installed = bool(result)
	if not _installed:
		_callback = null
	return _installed


func uninstall() -> void:
	_generation += 1
	if not _installed:
		_callback = null
		return
	if not _test_force_web and _is_web_runtime():
		JavaScriptBridge.eval(build_uninstall_script(CALLBACK_NAME), true)
	_installed = false
	_callback = null


func is_installed() -> bool:
	return _installed


func generation() -> int:
	return _generation


func last_event() -> Dictionary:
	return _last_event.duplicate(true)


func dispatch_event_for_tests(event_name: String, payload: Dictionary = {}, callback_generation: int = -1) -> bool:
	var resolved_generation := _generation if callback_generation < 0 else callback_generation
	return _dispatch_event(event_name, payload, resolved_generation)


static func build_install_script(callback_name: String = CALLBACK_NAME, generation: int = 1) -> String:
	var callback_json := JSON.stringify(callback_name)
	return """
(function() {
  var callbackName = __CALLBACK_NAME__;
  var generation = __GENERATION__;
  var oldBridge = window.__ptcgDeckAgentLifecycleBridge;
  if (oldBridge && typeof oldBridge.uninstall === 'function') oldBridge.uninstall();
  var earlyBridge = window.__ptcgEarlyLifecycleBridge;
  if (earlyBridge && typeof earlyBridge.uninstall === 'function') earlyBridge.uninstall();
  function send(name, payload) {
    try {
      var callback = window[callbackName];
      if (typeof callback === 'function') {
        callback(JSON.stringify({ event: name, payload: payload || {}, generation: generation }));
      }
    } catch (_error) {}
  }
  function viewportPayload() {
    var vv = window.visualViewport;
    return {
      width: window.innerWidth || 0,
      height: window.innerHeight || 0,
      device_pixel_ratio: window.devicePixelRatio || 1,
      visual_width: vv ? vv.width : 0,
      visual_height: vv ? vv.height : 0,
      visual_offset_left: vv ? vv.offsetLeft : 0,
      visual_offset_top: vv ? vv.offsetTop : 0
    };
  }
  var listeners = [];
  function listen(target, name, handler, options) {
    if (!target || typeof target.addEventListener !== 'function') return;
    target.addEventListener(name, handler, options);
    listeners.push([target, name, handler, options]);
  }
  listen(document, 'visibilitychange', function() {
    send(document.hidden ? 'visibility_hidden' : 'visibility_visible', { hidden: !!document.hidden });
  }, true);
  listen(window, 'pagehide', function(event) {
    send('pagehide', { persisted: !!event.persisted });
  }, true);
  listen(window, 'pageshow', function(event) {
    send('pageshow', { persisted: !!event.persisted });
  }, true);
  listen(window, 'blur', function() { send('blur', {}); }, true);
  listen(window, 'focus', function() { send('focus', {}); }, true);
  listen(window, 'pointercancel', function(event) {
    send('pointercancel', { pointer_id: event.pointerId || 0, pointer_type: event.pointerType || '' });
  }, true);
  listen(window, 'touchcancel', function(event) {
    send('touchcancel', { touch_count: event.changedTouches ? event.changedTouches.length : 0 });
  }, true);
  listen(window, 'resize', function() { send('viewport_changed', viewportPayload()); }, true);
  listen(window, 'orientationchange', function() { send('viewport_changed', viewportPayload()); }, true);
  if (window.visualViewport) {
    listen(window.visualViewport, 'resize', function() { send('viewport_changed', viewportPayload()); }, true);
    listen(window.visualViewport, 'scroll', function() { send('viewport_changed', viewportPayload()); }, true);
  }
  listen(window, 'error', function(event) {
    send('runtime_error', {
      kind: 'error',
      message: String(event.message || ''),
      source: String(event.filename || ''),
      line: Number(event.lineno || 0),
      column: Number(event.colno || 0),
      stack: event.error && event.error.stack ? String(event.error.stack) : ''
    });
  }, true);
  listen(window, 'unhandledrejection', function(event) {
    var reason = event.reason;
    send('runtime_error', {
      kind: 'unhandledrejection',
      message: String(reason && reason.message ? reason.message : reason || ''),
      stack: reason && reason.stack ? String(reason.stack) : ''
    });
  }, true);
  var bridge = {
    version: 1,
    generation: generation,
    uninstall: function() {
      listeners.forEach(function(item) {
        try { item[0].removeEventListener(item[1], item[2], item[3]); } catch (_error) {}
      });
      listeners = [];
    },
    emitForTests: function(name, payload) { send(String(name || ''), payload || {}); }
  };
  window.__ptcgDeckAgentLifecycleBridge = bridge;
  var queued = Array.isArray(window.__ptcgLifecycleQueue) ? window.__ptcgLifecycleQueue.splice(0) : [];
  queued.forEach(function(item) {
    if (item && item.event) send(String(item.event), item.payload || {});
  });
  send('bridge_installed', viewportPayload());
  return true;
})();
""".replace("__CALLBACK_NAME__", callback_json).replace("__GENERATION__", str(generation))


static func build_uninstall_script(callback_name: String = CALLBACK_NAME) -> String:
	var callback_json := JSON.stringify(callback_name)
	return """
(function() {
  var bridge = window.__ptcgDeckAgentLifecycleBridge;
  if (bridge && typeof bridge.uninstall === 'function') bridge.uninstall();
  try { delete window.__ptcgDeckAgentLifecycleBridge; } catch (_error) { window.__ptcgDeckAgentLifecycleBridge = null; }
  try { delete window[__CALLBACK_NAME__]; } catch (_error) { window[__CALLBACK_NAME__] = null; }
  return true;
})();
""".replace("__CALLBACK_NAME__", callback_json)


func _on_javascript_event(args: Array) -> void:
	if args.is_empty():
		return
	var parsed: Variant = JSON.parse_string(str(args[0]))
	if not (parsed is Dictionary):
		return
	var message := parsed as Dictionary
	_dispatch_event(
		str(message.get("event", "")),
		(message.get("payload", {}) as Dictionary),
		int(message.get("generation", -1))
	)


func _dispatch_event(event_name: String, payload: Dictionary, callback_generation: int) -> bool:
	if not _installed or callback_generation != _generation or event_name.strip_edges() == "":
		return false
	_last_event = {
		"event": event_name,
		"payload": payload.duplicate(true),
		"generation": callback_generation,
		"received_at_msec": Time.get_ticks_msec(),
	}
	event_received.emit(event_name, payload.duplicate(true))
	if event_name in ["visibility_hidden", "pagehide", "blur", "pointercancel", "touchcancel"]:
		transient_input_cancel_requested.emit(event_name)
	elif event_name == "viewport_changed" or event_name in ["bridge_installed", "pageshow", "visibility_visible", "focus"]:
		viewport_change_requested.emit(payload.duplicate(true))
	if event_name == "runtime_error":
		runtime_error_received.emit(str(payload.get("kind", "error")), payload.duplicate(true))
	return true


func _is_web_runtime() -> bool:
	return _test_force_web or OS.has_feature("web") or OS.has_feature("web_android") or OS.has_feature("web_ios") or DisplayServer.get_name().to_lower() in ["web", "html5"]
