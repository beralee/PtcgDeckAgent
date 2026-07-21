class_name DeckSharePlatformAdapter
extends Node

signal image_saved(path: String)
signal image_save_failed(message: String)
signal image_picked(bytes: PackedByteArray, source_name: String)
signal image_pick_failed(message: String)

const EXPORT_DIR := "user://deck_share_exports"
const IMAGE_FILTER := "*.png,*.jpg,*.jpeg,*.webp;Image Files;image/png,image/jpeg,image/webp"
const PNG_FILTER := "*.png;PNG Image;image/png"

var _file_dialog: FileDialog = null
var _save_file_dialog: FileDialog = null
var _web_pick_callback = null
var _web_save_callback = null
var _pending_native_save_bytes := PackedByteArray()
var _pending_native_save_name := ""


static func save_png_to_default_path(image: Image, suggested_name: String) -> Dictionary:
	if image == null:
		return {"ok": false, "path": "", "error": "missing image"}
	var dir := DirAccess.open("user://")
	if dir == null:
		return {"ok": false, "path": "", "error": "user data directory is unavailable"}
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(EXPORT_DIR)):
		var err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EXPORT_DIR))
		if err != OK:
			return {"ok": false, "path": "", "error": "failed to create export directory: %d" % err}
	var file_name := _safe_file_name(suggested_name)
	if file_name == "":
		file_name = "deck_share_%d" % int(Time.get_unix_time_from_system())
	if not file_name.to_lower().ends_with(".png"):
		file_name += ".png"
	var path := EXPORT_DIR.path_join(file_name)
	var save_err := image.save_png(path)
	if save_err != OK:
		return {"ok": false, "path": "", "error": "failed to save image: %d" % save_err}
	return {"ok": true, "path": path, "error": ""}


func save_png(image: Image, suggested_name: String) -> void:
	if image == null:
		image_save_failed.emit("missing image")
		return
	if _is_web_runtime():
		_save_png_web(image, suggested_name)
		return
	if _should_use_native_save_dialog() and _open_native_save_dialog(image, suggested_name):
		return
	if OS.has_feature("android") or OS.has_feature("ios"):
		image_save_failed.emit("当前系统无法打开保存位置选择器，请检查系统文件权限后重试。")
		return
	if DisplayServer.get_name().to_lower() == "headless":
		var result := save_png_to_default_path(image, suggested_name)
		if bool(result.get("ok", false)):
			image_saved.emit(str(result.get("path", "")))
		else:
			image_save_failed.emit(str(result.get("error", "save failed")))
		return
	_open_desktop_save_dialog(image, suggested_name)


func pick_image() -> void:
	if _is_web_runtime():
		_pick_image_web()
		return
	if _open_native_file_dialog():
		return
	if OS.has_feature("android") or OS.has_feature("ios"):
		image_pick_failed.emit("当前平台不支持系统图片选择器。")
		return
	_open_desktop_file_dialog()


static func _build_web_download_script_for_tests(png_base64: String, file_name: String) -> String:
	return _build_web_download_script(png_base64, file_name)


static func _build_web_pick_image_script_for_tests(callback_name: String = "__ptcgDeckShareImageCallback") -> String:
	return _build_web_pick_image_script(callback_name)


static func _native_image_filters_for_tests() -> PackedStringArray:
	return _native_image_filters()


static func _native_save_filters_for_tests() -> PackedStringArray:
	return _native_save_filters()


static func _should_use_native_save_dialog_for_tests(platform_name: String, has_native_file_dialog: bool) -> bool:
	return _should_use_native_save_dialog_for_platform(platform_name, has_native_file_dialog)


func _save_png_web(image: Image, suggested_name: String) -> void:
	var file_name := _safe_file_name(suggested_name)
	if file_name == "":
		file_name = "deck_share_%d.png" % int(Time.get_unix_time_from_system())
	if not file_name.to_lower().ends_with(".png"):
		file_name += ".png"
	var bytes := image.save_png_to_buffer()
	if bytes.is_empty():
		image_save_failed.emit("无法生成 PNG 数据。")
		return
	if not _ensure_web_save_callback():
		image_save_failed.emit("浏览器保存功能不可用。")
		return
	var script := _build_web_download_script(Marshalls.raw_to_base64(bytes), file_name)
	var ok := bool(JavaScriptBridge.eval(script, true))
	if not ok:
		image_save_failed.emit("浏览器未能打开保存位置选择器。")


func _ensure_web_save_callback() -> bool:
	var window := JavaScriptBridge.get_interface("window")
	if window == null:
		return false
	if _web_save_callback == null:
		_web_save_callback = JavaScriptBridge.create_callback(_on_web_image_save_event)
	window.__ptcgDeckShareSaveCallback = _web_save_callback
	return true


func _on_web_image_save_event(args: Array) -> void:
	if args.is_empty():
		image_save_failed.emit("浏览器没有返回保存结果。")
		return
	var parsed: Variant = JSON.parse_string(str(args[0]))
	if not (parsed is Dictionary):
		image_save_failed.emit("浏览器保存结果格式异常。")
		return
	var payload := parsed as Dictionary
	if not bool(payload.get("ok", false)):
		image_save_failed.emit(str(payload.get("error", "浏览器未能保存卡组图。")))
		return
	image_saved.emit(str(payload.get("path", "browser-save")))


func _open_native_save_dialog(image: Image, suggested_name: String) -> bool:
	var file_name := _safe_file_name(suggested_name)
	if file_name == "":
		file_name = "deck_share_%d.png" % int(Time.get_unix_time_from_system())
	if not file_name.to_lower().ends_with(".png"):
		file_name += ".png"
	var bytes := image.save_png_to_buffer()
	if bytes.is_empty():
		image_save_failed.emit("无法生成 PNG 数据。")
		return true
	_pending_native_save_bytes = bytes
	_pending_native_save_name = file_name
	var err := DisplayServer.file_dialog_show(
		"保存卡组图",
		_preferred_save_directory(),
		file_name,
		false,
		DisplayServer.FILE_DIALOG_MODE_SAVE_FILE,
		_native_save_filters(),
		_on_native_save_dialog_selected
	)
	if err != OK:
		_clear_pending_native_save()
		return false
	return true


func _on_native_save_dialog_selected(status: bool, selected_paths: PackedStringArray, _selected_filter_index: int) -> void:
	if not status or selected_paths.is_empty():
		_clear_pending_native_save()
		image_save_failed.emit("已取消保存卡组图。")
		return
	_write_pending_save_to_path(selected_paths[0])


func _write_pending_save_to_path(selected_path: String) -> void:
	var path := selected_path.strip_edges()
	if path == "":
		_clear_pending_native_save()
		image_save_failed.emit("没有选择保存位置。")
		return
	if not path.begins_with("content://") and path.get_extension() == "":
		path += ".png"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		var err := FileAccess.get_open_error()
		_clear_pending_native_save()
		image_save_failed.emit("无法写入图片文件：%d" % err)
		return
	file.store_buffer(_pending_native_save_bytes)
	file.close()
	_clear_pending_native_save()
	image_saved.emit(path)


func _open_desktop_save_dialog(image: Image, suggested_name: String) -> void:
	var file_name := _safe_file_name(suggested_name)
	if file_name == "":
		file_name = "deck_share_%d.png" % int(Time.get_unix_time_from_system())
	if not file_name.to_lower().ends_with(".png"):
		file_name += ".png"
	var bytes := image.save_png_to_buffer()
	if bytes.is_empty():
		image_save_failed.emit("无法生成 PNG 数据。")
		return
	_clear_save_file_dialog()
	_pending_native_save_bytes = bytes
	_pending_native_save_name = file_name
	_save_file_dialog = FileDialog.new()
	_save_file_dialog.name = "DeckShareImageSaveFileDialog"
	_save_file_dialog.title = "保存卡组图"
	_save_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_save_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_save_file_dialog.filters = PackedStringArray(["*.png ; PNG"])
	_save_file_dialog.current_dir = _preferred_save_directory()
	_save_file_dialog.current_file = file_name
	_save_file_dialog.file_selected.connect(_on_desktop_save_file_selected)
	_save_file_dialog.canceled.connect(_on_desktop_save_file_dialog_canceled)
	add_child(_save_file_dialog)
	_save_file_dialog.popup_centered(Vector2i(900, 640))


func _on_desktop_save_file_selected(path: String) -> void:
	_write_pending_save_to_path(path)
	_clear_save_file_dialog()


func _on_desktop_save_file_dialog_canceled() -> void:
	_clear_pending_native_save()
	_clear_save_file_dialog()
	image_save_failed.emit("已取消保存卡组图。")


func _clear_save_file_dialog() -> void:
	if _save_file_dialog != null and is_instance_valid(_save_file_dialog):
		_save_file_dialog.queue_free()
	_save_file_dialog = null


func _clear_pending_native_save() -> void:
	_pending_native_save_bytes = PackedByteArray()
	_pending_native_save_name = ""


func _pick_image_web() -> void:
	if not _ensure_web_pick_callback():
		image_pick_failed.emit("浏览器文件选择器不可用。")
		return
	var ok := bool(JavaScriptBridge.eval(_build_web_pick_image_script(), true))
	if not ok:
		image_pick_failed.emit("浏览器未能打开图片选择器。")


func _ensure_web_pick_callback() -> bool:
	var window := JavaScriptBridge.get_interface("window")
	if window == null:
		return false
	if _web_pick_callback == null:
		_web_pick_callback = JavaScriptBridge.create_callback(_on_web_image_pick_event)
	window.__ptcgDeckShareImageCallback = _web_pick_callback
	return true


func _on_web_image_pick_event(args: Array) -> void:
	if args.is_empty():
		image_pick_failed.emit("浏览器没有返回图片数据。")
		return
	var parsed: Variant = JSON.parse_string(str(args[0]))
	if not (parsed is Dictionary):
		image_pick_failed.emit("浏览器图片返回格式异常。")
		return
	var payload := parsed as Dictionary
	if not bool(payload.get("ok", false)):
		image_pick_failed.emit(str(payload.get("error", "浏览器未选择图片。")))
		return
	var base64 := str(payload.get("base64", "")).strip_edges()
	if base64 == "":
		image_pick_failed.emit("浏览器返回的图片数据为空。")
		return
	var bytes := Marshalls.base64_to_raw(base64)
	if bytes.is_empty():
		image_pick_failed.emit("浏览器图片数据无法解码。")
		return
	image_picked.emit(bytes, str(payload.get("name", "web-image")))


func _open_desktop_file_dialog() -> void:
	if _file_dialog != null and is_instance_valid(_file_dialog):
		_file_dialog.queue_free()
	_file_dialog = FileDialog.new()
	_file_dialog.name = "DeckShareImageFileDialog"
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.filters = PackedStringArray(["*.png ; PNG", "*.jpg,*.jpeg ; JPEG", "*.webp ; WebP"])
	_file_dialog.file_selected.connect(_on_file_selected)
	_file_dialog.canceled.connect(_on_file_dialog_canceled)
	add_child(_file_dialog)
	_file_dialog.popup_centered(Vector2i(900, 640))


func _open_native_file_dialog() -> bool:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		return false
	var err := DisplayServer.file_dialog_show(
		"选择卡组图",
		"",
		"",
		false,
		DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,
		_native_image_filters(),
		_on_native_file_dialog_selected
	)
	return err == OK


func _on_native_file_dialog_selected(status: bool, selected_paths: PackedStringArray, _selected_filter_index: int) -> void:
	if not status or selected_paths.is_empty():
		image_pick_failed.emit("已取消选择图片。")
		return
	_read_selected_file(selected_paths[0])


func _on_file_selected(path: String) -> void:
	_read_selected_file(path)
	_clear_file_dialog()


func _read_selected_file(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		image_pick_failed.emit("无法读取图片文件。")
		return
	var bytes := file.get_buffer(file.get_length())
	file.close()
	image_picked.emit(bytes, path)


func _on_file_dialog_canceled() -> void:
	_clear_file_dialog()
	image_pick_failed.emit("已取消选择图片。")


func _clear_file_dialog() -> void:
	if _file_dialog != null and is_instance_valid(_file_dialog):
		_file_dialog.queue_free()
	_file_dialog = null


static func _safe_file_name(text: String) -> String:
	var cleaned := text.strip_edges()
	for token: String in ["\\", "/", ":", "*", "?", "\"", "<", ">", "|"]:
		cleaned = cleaned.replace(token, "_")
	while "__" in cleaned:
		cleaned = cleaned.replace("__", "_")
	return cleaned.substr(0, 80).strip_edges()


static func _native_image_filters() -> PackedStringArray:
	return PackedStringArray([IMAGE_FILTER])


static func _native_save_filters() -> PackedStringArray:
	return PackedStringArray([PNG_FILTER])


static func _should_use_native_save_dialog() -> bool:
	return _should_use_native_save_dialog_for_platform(
		DisplayServer.get_name(),
		DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE)
	)


static func _should_use_native_save_dialog_for_platform(platform_name: String, has_native_file_dialog: bool) -> bool:
	if not has_native_file_dialog:
		return false
	var normalized := platform_name.strip_edges().to_lower()
	return normalized not in ["web", "html5", "headless"]


static func _preferred_save_directory() -> String:
	if OS.has_feature("android") or OS.has_feature("ios"):
		return ""
	for system_dir: OS.SystemDir in [OS.SYSTEM_DIR_PICTURES, OS.SYSTEM_DIR_DOWNLOADS, OS.SYSTEM_DIR_DOCUMENTS]:
		var path := OS.get_system_dir(system_dir)
		if path != "" and DirAccess.dir_exists_absolute(path):
			return path
	var home := OS.get_environment("USERPROFILE")
	if home == "":
		home = OS.get_environment("HOME")
	return home if home != "" and DirAccess.dir_exists_absolute(home) else ""


static func _is_web_runtime() -> bool:
	return OS.has_feature("web") \
		or OS.has_feature("web_android") \
		or OS.has_feature("web_ios") \
		or DisplayServer.get_name().to_lower() in ["web", "html5"]


static func _build_web_download_script(png_base64: String, file_name: String) -> String:
	return """
(function() {
  var callbackName = '__ptcgDeckShareSaveCallback';
  function finish(payload) {
    try {
      var cb = window[callbackName];
      if (typeof cb === 'function') {
        cb(JSON.stringify(payload || {}));
      }
    } catch (_error) {}
  }
  function fallbackDownload(blob, fileName) {
    try {
      var url = URL.createObjectURL(blob);
      var anchor = document.createElement('a');
      anchor.href = url;
      anchor.download = fileName || 'deck_share.png';
      anchor.rel = 'noopener';
      anchor.style.display = 'none';
      document.body.appendChild(anchor);
      anchor.click();
      setTimeout(function() {
        try { URL.revokeObjectURL(url); } catch (_error) {}
        try { anchor.remove(); } catch (_error) {}
      }, 1000);
      finish({
        ok: true,
        path: 'browser-download:' + (fileName || 'deck_share.png'),
        method: 'download'
      });
    } catch (error) {
      finish({ ok: false, error: String(error && error.message ? error.message : error) });
    }
  }
  function saveWithPickerOrDownload(blob, fileName) {
    if (window.isSecureContext && typeof window.showSaveFilePicker === 'function') {
      (async function() {
        try {
          var handle = await window.showSaveFilePicker({
            suggestedName: fileName || 'deck_share.png',
            types: [{
              description: 'PNG Image',
              accept: { 'image/png': ['.png'] }
            }]
          });
          var writable = await handle.createWritable();
          await writable.write(blob);
          await writable.close();
          finish({
            ok: true,
            path: 'browser-save:' + String(handle.name || fileName || 'deck_share.png'),
            method: 'file-picker'
          });
        } catch (error) {
          if (error && error.name === 'AbortError') {
            finish({ ok: false, canceled: true, error: '已取消保存卡组图。' });
            return;
          }
          fallbackDownload(blob, fileName);
        }
      })();
    } else {
      fallbackDownload(blob, fileName);
    }
  }
  function trySystemShare(blob, fileName) {
    try {
      var userAgent = String(navigator.userAgent || '');
      var mobileHint = !!(navigator.userAgentData && navigator.userAgentData.mobile)
        || /Android|iPhone|iPad|iPod/i.test(userAgent)
        || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
      if (!mobileHint || typeof navigator.share !== 'function' || typeof navigator.canShare !== 'function') {
        return false;
      }
      var file = new File([blob], fileName || 'deck_share.png', { type: 'image/png' });
      var shareData = { files: [file], title: '保存卡组图' };
      if (!navigator.canShare(shareData)) {
        return false;
      }
      (async function() {
        try {
          await navigator.share(shareData);
          finish({
            ok: true,
            path: 'system-share:' + String(file.name || fileName || 'deck_share.png'),
            method: 'system-share'
          });
        } catch (error) {
          if (error && error.name === 'AbortError') {
            finish({ ok: false, canceled: true, error: '已取消保存卡组图。' });
            return;
          }
          saveWithPickerOrDownload(blob, fileName);
        }
      })();
      return true;
    } catch (_error) {
      return false;
    }
  }
  try {
    var base64 = __BASE64__;
    var fileName = __FILE_NAME__;
    var binary = atob(base64);
    var bytes = new Uint8Array(binary.length);
    for (var i = 0; i < binary.length; i += 1) {
      bytes[i] = binary.charCodeAt(i);
    }
    var blob = new Blob([bytes], { type: 'image/png' });
    if (!trySystemShare(blob, fileName)) {
      saveWithPickerOrDownload(blob, fileName);
    }
    return true;
  } catch (error) {
    finish({ ok: false, error: String(error && error.message ? error.message : error) });
    return false;
  }
})();
""".replace("__BASE64__", JSON.stringify(png_base64)).replace("__FILE_NAME__", JSON.stringify(file_name))


static func _build_web_pick_image_script(callback_name: String = "__ptcgDeckShareImageCallback") -> String:
	var resolved_callback := callback_name.strip_edges()
	if resolved_callback == "":
		resolved_callback = "__ptcgDeckShareImageCallback"
	return """
(function() {
  var callbackName = __CALLBACK_NAME__;
  function finish(payload) {
    try {
      var cb = window[callbackName];
      if (typeof cb === 'function') {
        cb(JSON.stringify(payload || {}));
      }
    } catch (_error) {}
  }
  try {
    var input = document.createElement('input');
    input.type = 'file';
    input.accept = 'image/png,image/jpeg,image/webp';
    input.style.position = 'fixed';
    input.style.left = '-9999px';
    input.style.top = '-9999px';
    function cleanup() {
      try { input.remove(); } catch (_error) {}
    }
    input.onchange = function() {
      var file = input.files && input.files.length > 0 ? input.files[0] : null;
      if (!file) {
        finish({ ok: false, error: '没有选择图片。' });
        cleanup();
        return;
      }
      var reader = new FileReader();
      reader.onload = function() {
        var value = String(reader.result || '');
        var comma = value.indexOf(',');
        finish({
          ok: true,
          name: String(file.name || 'web-image'),
          base64: comma >= 0 ? value.slice(comma + 1) : value
        });
        cleanup();
      };
      reader.onerror = function() {
        finish({ ok: false, error: '浏览器读取图片失败。' });
        cleanup();
      };
      reader.readAsDataURL(file);
    };
    document.body.appendChild(input);
    input.click();
    return true;
  } catch (error) {
    finish({ ok: false, error: String(error && error.message ? error.message : error) });
    return false;
  }
})();
""".replace("__CALLBACK_NAME__", JSON.stringify(resolved_callback))
