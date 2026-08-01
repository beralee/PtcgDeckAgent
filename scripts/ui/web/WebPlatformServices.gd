class_name WebPlatformServices
extends RefCounted

const UiRuntimeProfileResolverScript := preload("res://scripts/ui/runtime/UiRuntimeProfileResolver.gd")

var _secret_entry_callback: Variant = null
var _secret_entry_callback_name: String = ""
var _secret_entry_generation: int = 0
var _pending_secret_entry_requests: Dictionary = {}
var _test_force_web: bool = false


func set_test_force_web(enabled: bool) -> void:
	_test_force_web = enabled


func request_secret_text(initial_value: String, result_callback: Callable) -> bool:
	if not result_callback.is_valid() or not is_web_runtime():
		return false
	# Only one native secret-entry overlay can exist at a time. Invalidate any
	# previous request before replacing its DOM node so a late callback cannot
	# write an obsolete secret into the current Settings scene.
	_pending_secret_entry_requests.clear()
	_secret_entry_generation += 1
	var request_id := _secret_entry_generation
	_pending_secret_entry_requests[request_id] = result_callback
	if _test_force_web:
		return true
	if not _ensure_secret_entry_callback():
		_pending_secret_entry_requests.erase(request_id)
		return false
	var result: Variant = JavaScriptBridge.eval(
		build_secret_entry_script(
			_secret_entry_callback_name,
			request_id,
			initial_value
		),
		true
	)
	if not bool(result):
		_pending_secret_entry_requests.erase(request_id)
	return bool(result)


func deliver_secret_entry_result_for_tests(request_id: int, payload: Dictionary) -> bool:
	return _deliver_secret_entry_result(request_id, payload)


func latest_secret_entry_request_id_for_tests() -> int:
	return _secret_entry_generation


func shutdown() -> void:
	_secret_entry_generation += 1
	_pending_secret_entry_requests.clear()
	if not _test_force_web and is_web_runtime():
		JavaScriptBridge.eval(build_secret_entry_cleanup_script(_secret_entry_callback_name), true)
	_secret_entry_callback = null
	_secret_entry_callback_name = ""


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


static func build_secret_entry_script(
	callback_name: String,
	request_id: int,
	initial_value: String = ""
) -> String:
	return """
(function() {
  var callbackName = __CALLBACK_NAME__;
  var requestId = __REQUEST_ID__;
  var initialValue = __INITIAL_VALUE__;
  var previous = document.getElementById('ptcg-native-secret-entry');
  if (previous && previous.parentNode) previous.parentNode.removeChild(previous);

  function callback(payload) {
    try {
      var receiver = window[callbackName];
      if (typeof receiver === 'function') {
        receiver(JSON.stringify({ request_id: requestId, payload: payload || {} }));
      }
    } catch (_callbackError) {}
  }

  var overlay = document.createElement('div');
  overlay.id = 'ptcg-native-secret-entry';
  overlay.setAttribute('role', 'dialog');
  overlay.setAttribute('aria-modal', 'true');
  overlay.setAttribute('aria-label', '粘贴 API 密钥');
  overlay.style.position = 'fixed';
  overlay.style.inset = '0';
  overlay.style.zIndex = '2147483647';
  overlay.style.display = 'flex';
  overlay.style.alignItems = 'center';
  overlay.style.justifyContent = 'center';
  overlay.style.padding = '20px';
  overlay.style.boxSizing = 'border-box';
  overlay.style.background = 'rgba(2, 8, 18, 0.88)';
  overlay.style.touchAction = 'auto';
  overlay.style.userSelect = 'none';
  overlay.style.webkitUserSelect = 'none';

  var panel = document.createElement('div');
  panel.style.width = 'min(560px, 100%)';
  panel.style.boxSizing = 'border-box';
  panel.style.padding = '22px';
  panel.style.border = '2px solid rgba(74, 220, 255, 0.95)';
  panel.style.borderRadius = '16px';
  panel.style.background = '#071427';
  panel.style.boxShadow = '0 18px 48px rgba(0, 0, 0, 0.55)';

  var title = document.createElement('div');
  title.textContent = '粘贴 API 密钥';
  title.style.color = '#f4fbff';
  title.style.font = '700 20px sans-serif';
  title.style.marginBottom = '10px';

  var hint = document.createElement('div');
  hint.id = 'ptcg-native-secret-hint';
  hint.textContent = '先点“直接读取剪贴板”；若浏览器拒绝，再在输入框中长按粘贴。';
  hint.style.color = '#a9c9dc';
  hint.style.font = '15px/1.45 sans-serif';
  hint.style.marginBottom = '14px';

  var input = document.createElement('input');
  input.id = 'ptcg-native-secret-input';
  input.type = 'text';
  input.value = String(initialValue || '');
  input.placeholder = '也可以在这里长按粘贴 API Key';
  input.autocapitalize = 'none';
  input.autocomplete = 'off';
  input.autocorrect = 'off';
  input.spellcheck = false;
  input.inputMode = 'text';
  input.style.width = '100%';
  input.style.height = '68px';
  input.style.boxSizing = 'border-box';
  input.style.padding = '0 14px';
  input.style.border = '2px solid rgba(74, 220, 255, 0.9)';
  input.style.borderRadius = '10px';
  input.style.background = '#020914';
  input.style.color = '#f4fbff';
  input.style.caretColor = '#f4fbff';
  input.style.font = '16px sans-serif';
  input.style.fontSize = '16px';
  input.style.outline = 'none';
  input.style.webkitAppearance = 'none';
  input.style.webkitTextSecurity = 'disc';
  input.style.userSelect = 'text';
  input.style.webkitUserSelect = 'text';
  input.style.webkitTouchCallout = 'default';
  input.style.touchAction = 'auto';
  input.style.setProperty('user-select', 'text', 'important');
  input.style.setProperty('-webkit-user-select', 'text', 'important');
  input.style.setProperty('-webkit-touch-callout', 'default', 'important');
  input.style.setProperty('touch-action', 'auto', 'important');

  var actions = document.createElement('div');
  actions.style.display = 'flex';
  actions.style.gap = '12px';
  actions.style.marginTop = '18px';

  function makeButton(id, text, primary) {
    var button = document.createElement('button');
    button.id = id;
    button.type = 'button';
    button.textContent = text;
    button.style.flex = '1';
    button.style.minHeight = '50px';
    button.style.borderRadius = '10px';
    button.style.border = primary ? '1px solid #49dcff' : '1px solid #52687a';
    button.style.background = primary ? '#167eaa' : '#172536';
    button.style.color = '#f4fbff';
    button.style.font = '700 17px sans-serif';
    button.style.touchAction = 'manipulation';
    return button;
  }

  var readClipboardButton = makeButton('ptcg-native-secret-read-clipboard', '直接读取剪贴板', true);
  readClipboardButton.style.width = '100%';
  readClipboardButton.style.marginTop = '14px';
  var cancelButton = makeButton('ptcg-native-secret-cancel', '取消', false);
  var confirmButton = makeButton('ptcg-native-secret-confirm', '确认', true);
  actions.appendChild(cancelButton);
  actions.appendChild(confirmButton);
  panel.appendChild(title);
  panel.appendChild(hint);
  panel.appendChild(input);
  panel.appendChild(readClipboardButton);
  panel.appendChild(actions);
  overlay.appendChild(panel);

  var finished = false;
  function cleanup() {
    window.removeEventListener('pagehide', onPageHide);
    if (overlay.parentNode) overlay.parentNode.removeChild(overlay);
    if (window.__ptcgNativeSecretEntry && window.__ptcgNativeSecretEntry.requestId === requestId) {
      window.__ptcgNativeSecretEntry = null;
    }
  }
  function finish(payload) {
    if (finished) return;
    finished = true;
    cleanup();
    callback(payload);
  }
  function confirm() {
    var value = String(input.value || '').trim();
    if (!value) {
      hint.textContent = '密钥为空，请先长按输入框并选择系统“粘贴”。';
      hint.style.color = '#ff9b8f';
      input.focus();
      return;
    }
    finish({ ok: true, text: value });
  }
  function cancel() {
    finish({ ok: false, cancelled: true });
  }
  function onPageHide() {
    cancel();
  }
  function focusNativeFallback(message) {
    hint.textContent = message || '无法直接读取剪贴板，请在输入框中长按并选择系统“粘贴”。';
    hint.style.color = '#ffcf70';
    try {
      input.focus({ preventScroll: true });
    } catch (_focusFallbackOptionsError) {
      input.focus();
    }
    try { input.setSelectionRange(0, input.value.length); } catch (_fallbackSelectionError) {}
  }
  function applyClipboardText(value) {
    var text = String(value || '').trim();
    if (!text) {
      focusNativeFallback('剪贴板为空，请先复制 API Key；也可以在输入框中长按粘贴。');
      return;
    }
    input.value = text;
    input.dispatchEvent(new Event('input', { bubbles: true }));
    try { input.setSelectionRange(text.length, text.length); } catch (_pasteSelectionError) {}
    hint.textContent = '已读取密钥，请点“确认”。';
    hint.style.color = '#7ff0ae';
  }
  function readClipboard() {
    if (!navigator.clipboard || typeof navigator.clipboard.readText !== 'function') {
      focusNativeFallback('无法直接读取剪贴板，请在输入框中长按并选择系统“粘贴”。');
      return;
    }
    hint.textContent = '正在读取剪贴板…';
    hint.style.color = '#a9c9dc';
    navigator.clipboard.readText().then(applyClipboardText).catch(function() {
      focusNativeFallback('无法直接读取剪贴板，请在输入框中长按并选择系统“粘贴”。');
    });
  }

  input.addEventListener('paste', function(event) {
    var clipboard = event && (event.clipboardData || window.clipboardData);
    var pasted = '';
    try {
      pasted = clipboard && typeof clipboard.getData === 'function'
        ? String(clipboard.getData('text/plain') || '')
        : '';
    } catch (_clipboardError) {}
    if (!pasted) return;
    event.preventDefault();
    var start = typeof input.selectionStart === 'number' ? input.selectionStart : input.value.length;
    var end = typeof input.selectionEnd === 'number' ? input.selectionEnd : start;
    input.setRangeText(pasted, start, end, 'end');
  });
  input.addEventListener('keydown', function(event) {
    if (event.key === 'Enter') {
      event.preventDefault();
      confirm();
    } else if (event.key === 'Escape') {
      event.preventDefault();
      cancel();
    }
  });
  confirmButton.addEventListener('click', confirm);
  cancelButton.addEventListener('click', cancel);
  readClipboardButton.addEventListener('click', readClipboard);
  ['touchstart', 'touchmove', 'touchend', 'pointerdown', 'pointerup', 'mousedown', 'mouseup', 'click', 'contextmenu'].forEach(function(name) {
    overlay.addEventListener(name, function(event) {
      event.stopPropagation();
    }, { passive: true });
  });

  document.body.appendChild(overlay);
  window.addEventListener('pagehide', onPageHide, { once: true });
  window.__ptcgNativeSecretEntry = {
    requestId: requestId,
    overlay: overlay,
    input: input,
    cancel: cancel,
    readClipboard: readClipboard
  };
  try {
    input.focus({ preventScroll: true });
  } catch (_focusOptionsError) {
    input.focus();
  }
  try { input.setSelectionRange(0, input.value.length); } catch (_selectionError) {}
  return true;
})()
""".replace("__CALLBACK_NAME__", JSON.stringify(callback_name)) \
	.replace("__REQUEST_ID__", str(request_id)) \
	.replace("__INITIAL_VALUE__", JSON.stringify(initial_value))


static func build_secret_entry_cleanup_script(callback_name: String) -> String:
	var cleanup_callback := ""
	if callback_name != "":
		cleanup_callback = """
  try { delete window[__CALLBACK_NAME__]; } catch (_callbackError) { window[__CALLBACK_NAME__] = null; }
""".replace("__CALLBACK_NAME__", JSON.stringify(callback_name))
	return """
(function() {
  var overlay = document.getElementById('ptcg-native-secret-entry');
  if (overlay && overlay.parentNode) overlay.parentNode.removeChild(overlay);
  window.__ptcgNativeSecretEntry = null;
__CLEANUP_CALLBACK__
  return true;
})()
""".replace("__CLEANUP_CALLBACK__", cleanup_callback)


func _ensure_secret_entry_callback() -> bool:
	var window := JavaScriptBridge.get_interface("window")
	if window == null:
		return false
	if _secret_entry_callback == null:
		_secret_entry_callback_name = "__ptcgDeckAgentSecretEntryCallback_%d" % get_instance_id()
		_secret_entry_callback = JavaScriptBridge.create_callback(_on_secret_entry_javascript_result)
	window.set(_secret_entry_callback_name, _secret_entry_callback)
	return true


func _on_secret_entry_javascript_result(args: Array) -> void:
	if args.is_empty():
		return
	var parsed: Variant = JSON.parse_string(str(args[0]))
	if not (parsed is Dictionary):
		return
	var message := parsed as Dictionary
	var payload_variant: Variant = message.get("payload", {})
	var payload: Dictionary = payload_variant as Dictionary if payload_variant is Dictionary else {}
	_deliver_secret_entry_result(int(message.get("request_id", -1)), payload)


func _deliver_secret_entry_result(request_id: int, payload: Dictionary) -> bool:
	if not _pending_secret_entry_requests.has(request_id):
		return false
	var callback: Callable = _pending_secret_entry_requests[request_id] as Callable
	_pending_secret_entry_requests.erase(request_id)
	if not callback.is_valid():
		return false
	callback.call(payload.duplicate(true))
	return true
