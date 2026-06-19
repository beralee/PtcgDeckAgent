class_name WebTextInputBridge
extends RefCounted

const ACTIVE_META := "_web_text_input_bridge_active"
const LAST_PROXY_REQUEST_META := "_web_text_input_last_proxy_request_msec"
const DUPLICATE_REQUEST_SUPPRESS_MSEC := 220

static var _callback_host: WebTextInputBridge = null
static var _callbacks: Array = []
static var _active_control_ref: WeakRef = null
static var _active_control_id: int = 0
static var _test_force_web := false
static var _test_request_count := 0
static var _test_last_payload: Dictionary = {}


static func set_test_force_web(enabled: bool) -> void:
	_test_force_web = enabled
	if not enabled:
		_test_request_count = 0
		_test_last_payload = {}
		_active_control_ref = null
		_active_control_id = 0


static func reset_test_state() -> void:
	_test_request_count = 0
	_test_last_payload = {}
	_active_control_ref = null
	_active_control_id = 0


static func get_test_request_count() -> int:
	return _test_request_count


static func get_test_last_payload() -> Dictionary:
	return _test_last_payload.duplicate(true)


static func is_web_runtime() -> bool:
	if _test_force_web:
		return true
	return OS.has_feature("web") or OS.has_feature("web_android") or OS.has_feature("web_ios")


static func request_focus(control: Control) -> bool:
	if control == null or not is_web_runtime():
		return false
	var target := _target_text_control(control)
	if target == null or not _target_is_editable(target):
		return false
	var now := Time.get_ticks_msec()
	var previous := int(target.get_meta(LAST_PROXY_REQUEST_META, -1000000))
	if target.get_instance_id() == _active_control_id and now - previous >= 0 and now - previous < DUPLICATE_REQUEST_SUPPRESS_MSEC:
		if target.is_inside_tree():
			target.grab_focus()
		return true
	target.set_meta(LAST_PROXY_REQUEST_META, now)
	target.set_meta(ACTIVE_META, true)
	target.focus_mode = Control.FOCUS_ALL
	if target.is_inside_tree():
		target.grab_focus()
	_active_control_ref = weakref(target)
	_active_control_id = target.get_instance_id()
	var payload := _payload_for_control(target)
	if _test_force_web:
		_test_request_count += 1
		_test_last_payload = payload.duplicate(true)
		return true
	if not _ensure_javascript_bridge():
		return false
	var json := JSON.stringify(payload)
	var script := "window.__ptcgDeckAgentTextInput && window.__ptcgDeckAgentTextInput.open(%s);" % json
	JavaScriptBridge.eval(script, true)
	return true


static func commit_active_value(value: String, finished: bool = false) -> void:
	var control := _active_control()
	if control == null:
		return
	_apply_value_to_control(control, value)
	if finished:
		control.remove_meta(ACTIVE_META)
		_active_control_ref = null
		_active_control_id = 0


static func _target_text_control(control: Control) -> Control:
	if control is SpinBox:
		var line_edit := (control as SpinBox).get_line_edit()
		return line_edit
	return control if control is LineEdit or control is TextEdit else null


static func _target_is_editable(control: Control) -> bool:
	if control == null or not control.visible:
		return false
	if control is LineEdit and not (control as LineEdit).editable:
		return false
	if control is TextEdit and not (control as TextEdit).editable:
		return false
	if control.is_inside_tree() and not control.is_visible_in_tree():
		return false
	return true


static func _payload_for_control(control: Control) -> Dictionary:
	var rect := control.get_global_rect()
	var viewport_size := Vector2(1280, 720)
	if control.is_inside_tree() and control.get_viewport() != null:
		viewport_size = control.get_viewport_rect().size
	var multiline := control is TextEdit
	var text := ""
	var placeholder := ""
	var input_type := "text"
	if control is LineEdit:
		var line_edit := control as LineEdit
		text = line_edit.text
		placeholder = line_edit.placeholder_text
		input_type = _line_edit_input_type(line_edit)
	elif control is TextEdit:
		var text_edit := control as TextEdit
		text = text_edit.text
		placeholder = text_edit.placeholder_text
		multiline = true
	return {
		"id": control.get_instance_id(),
		"x": rect.position.x,
		"y": rect.position.y,
		"width": maxf(maxf(rect.size.x, control.custom_minimum_size.x), 80.0),
		"height": maxf(maxf(rect.size.y, control.custom_minimum_size.y), 38.0),
		"viewport_width": maxf(viewport_size.x, 1.0),
		"viewport_height": maxf(viewport_size.y, 1.0),
		"text": text,
		"placeholder": placeholder,
		"input_type": input_type,
		"multiline": multiline,
	}


static func _line_edit_input_type(input: LineEdit) -> String:
	if input.secret:
		return "password"
	match input.virtual_keyboard_type:
		LineEdit.KEYBOARD_TYPE_URL:
			return "url"
		LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS:
			return "email"
		LineEdit.KEYBOARD_TYPE_PHONE:
			return "tel"
		LineEdit.KEYBOARD_TYPE_NUMBER, LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL:
			return "number"
		LineEdit.KEYBOARD_TYPE_PASSWORD:
			return "password"
		_:
			return "text"


static func _ensure_javascript_bridge() -> bool:
	var window := JavaScriptBridge.get_interface("window")
	if window == null:
		return false
	if _callback_host == null:
		var bridge_script := load("res://scripts/ui/non_battle/WebTextInputBridge.gd") as Script
		if bridge_script == null:
			return false
		_callback_host = bridge_script.new()
	var has_callback := bool(JavaScriptBridge.eval("typeof window.__ptcgDeckAgentTextInputCallback === 'function'", true))
	if not has_callback:
		var callback := JavaScriptBridge.create_callback(_callback_host._on_js_text_input_event)
		_callbacks.append(callback)
		window.__ptcgDeckAgentTextInputCallback = callback
	JavaScriptBridge.eval(_install_script(), true)
	return true


static func _install_script() -> String:
	return """
(function() {
  if (window.__ptcgDeckAgentTextInput && window.__ptcgDeckAgentTextInput.version === 1) return;
  function callback(event, value, id) {
    if (typeof window.__ptcgDeckAgentTextInputCallback === 'function') {
      window.__ptcgDeckAgentTextInputCallback(JSON.stringify({ event: event, value: value || '', id: id || 0 }));
    }
  }
  function ensureInput(config) {
    var state = window.__ptcgDeckAgentTextInput;
    if (state.input && state.input.parentNode) state.input.parentNode.removeChild(state.input);
    var input = config.multiline ? document.createElement('textarea') : document.createElement('input');
    if (!config.multiline) input.type = config.input_type || 'text';
    input.value = config.text || '';
    input.placeholder = config.placeholder || '';
    input.autocapitalize = 'none';
    input.autocomplete = 'off';
    input.autocorrect = 'off';
    input.spellcheck = false;
    input.style.position = 'fixed';
    input.style.zIndex = '2147483647';
    input.style.boxSizing = 'border-box';
    input.style.border = '2px solid rgba(74, 220, 255, 0.95)';
    input.style.borderRadius = '8px';
    input.style.background = 'rgba(4, 14, 28, 0.96)';
    input.style.color = '#f4fbff';
    input.style.outline = 'none';
    input.style.padding = '0 10px';
    input.style.font = '18px sans-serif';
    if (config.multiline) {
      input.style.paddingTop = '8px';
      input.style.resize = 'none';
      input.style.lineHeight = '1.35';
    }
    document.body.appendChild(input);
    state.input = input;
    state.id = config.id || 0;
    return input;
  }
  function placeInput(input, config) {
    var canvas = document.querySelector('canvas');
    var rect = canvas ? canvas.getBoundingClientRect() : { left: 0, top: 0, width: window.innerWidth, height: window.innerHeight };
    var scaleX = rect.width / Math.max(1, Number(config.viewport_width || rect.width || 1));
    var scaleY = rect.height / Math.max(1, Number(config.viewport_height || rect.height || 1));
    input.style.left = (rect.left + Number(config.x || 0) * scaleX) + 'px';
    input.style.top = (rect.top + Number(config.y || 0) * scaleY) + 'px';
    input.style.width = Math.max(80, Number(config.width || 80) * scaleX) + 'px';
    input.style.height = Math.max(38, Number(config.height || 38) * scaleY) + 'px';
  }
  window.__ptcgDeckAgentTextInput = {
    version: 1,
    input: null,
    id: 0,
    open: function(config) {
      config = config || {};
      var input = ensureInput(config);
      placeInput(input, config);
      var id = config.id || 0;
      input.oninput = function() { callback('input', input.value, id); };
      input.onchange = function() { callback('input', input.value, id); };
      input.onblur = function() {
        callback('commit', input.value, id);
        setTimeout(function() {
          if (window.__ptcgDeckAgentTextInput && window.__ptcgDeckAgentTextInput.input === input && input.parentNode) {
            input.parentNode.removeChild(input);
            window.__ptcgDeckAgentTextInput.input = null;
          }
        }, 0);
      };
      input.onkeydown = function(event) {
        if (!config.multiline && event.key === 'Enter') {
          event.preventDefault();
          callback('commit', input.value, id);
          input.blur();
        }
        if (event.key === 'Escape') {
          event.preventDefault();
          input.blur();
        }
      };
      input.focus({ preventScroll: true });
      try { input.setSelectionRange(input.value.length, input.value.length); } catch (_) {}
    }
  };
})();
"""


func _on_js_text_input_event(args: Array) -> void:
	if args.is_empty():
		return
	var text := str(args[0])
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return
	var payload := parsed as Dictionary
	var id := int(payload.get("id", 0))
	if id != _active_control_id:
		return
	var event := str(payload.get("event", "input"))
	var value := str(payload.get("value", ""))
	commit_active_value(value, event == "commit" or event == "blur")


static func _active_control() -> Control:
	if _active_control_ref == null:
		return null
	var value: Variant = _active_control_ref.get_ref()
	return value as Control if value is Control else null


static func _apply_value_to_control(control: Control, value: String) -> void:
	if control is LineEdit:
		var line_edit := control as LineEdit
		if line_edit.text != value:
			line_edit.text = value
			line_edit.text_changed.emit(value)
	elif control is TextEdit:
		var text_edit := control as TextEdit
		if text_edit.text != value:
			text_edit.text = value
			text_edit.text_changed.emit()
