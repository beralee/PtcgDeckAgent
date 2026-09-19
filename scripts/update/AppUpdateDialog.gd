extends Control

const Hud := preload("res://scripts/ui/HudTheme.gd")
const Version := preload("res://scripts/app/AppVersion.gd")
const Manifest := preload("res://scripts/update/AppUpdateManifest.gd")

signal dismissed()
signal ignore_requested()

var _updater: Node
var _info: Dictionary = {}
var _panel: PanelContainer
var _body: Label
var _status: Label
var _progress: ProgressBar
var _detail: Label
var _primary: Button
var _cancel: Button
var _later: Button
var _ignore: Button
var _close: Button
var _actions: HFlowContainer


func configure(updater: Node, info: Dictionary) -> void:
	_updater = updater
	_info = info.duplicate(true)
	_build()
	if _updater != null:
		_updater.changed.connect(refresh)
		_updater.offer(info)
		refresh(_updater.snapshot())
	else:
		refresh({"state": "available", "info": info, "install_reason": ""})


func _build() -> void:
	name = "HudModalOverlay"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.012, 0.024, 0.82)
	add_child(shade)
	_panel = PanelContainer.new()
	_panel.name = "UpdatePanel"
	add_child(_panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("102331")
	style.border_color = Color("2b6578")
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.set_content_margin_all(24)
	_panel.add_theme_stylebox_override("panel", style)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	_panel.add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	var title := Label.new()
	title.text = "游戏更新"
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_close = _button("×", _dismiss)
	_close.custom_minimum_size = Vector2(48, 48)
	header.add_child(_close)
	var version := Label.new()
	version.text = "%s  →  %s" % [Version.current_display_version(), str(_info.get("display_version", "新版本"))]
	version.add_theme_font_size_override("font_size", 22)
	version.add_theme_color_override("font_color", Hud.ACCENT)
	root.add_child(version)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_body = Label.new()
	_body.name = "UpdateReleaseNotes"
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("font_size", 18)
	_body.add_theme_constant_override("line_spacing", 5)
	var lines := PackedStringArray([str(_info.get("title", "发现新版本")), ""])
	for item: Variant in _info.get("summary", []):
		lines.append("• " + str(item))
	_body.text = "\n".join(lines)
	scroll.add_child(_body)
	Hud.style_scroll_container(scroll)
	_status = Label.new()
	_status.name = "UpdateStatus"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 18)
	root.add_child(_status)
	_progress = ProgressBar.new()
	_progress.name = "UpdateProgress"
	_progress.custom_minimum_size.y = 14
	_progress.show_percentage = false
	root.add_child(_progress)
	_detail = Label.new()
	_detail.add_theme_font_size_override("font_size", 16)
	_detail.add_theme_color_override("font_color", Hud.TEXT_MUTED)
	root.add_child(_detail)
	_actions = HFlowContainer.new()
	_actions.add_theme_constant_override("h_separation", 10)
	_actions.add_theme_constant_override("v_separation", 10)
	root.add_child(_actions)
	_primary = _button("下载更新", _primary_pressed)
	_primary.name = "DownloadOrInstallUpdate"
	Hud._style_button(_primary, Hud.ACCENT_WARM)
	_actions.add_child(_primary)
	_later = _button("稍后", _dismiss)
	_actions.add_child(_later)
	_cancel = _button("取消下载", func() -> void: _updater.cancel_download())
	_actions.add_child(_cancel)
	_ignore = _button("忽略此版本", func() -> void: ignore_requested.emit(); _dismiss())
	_actions.add_child(_ignore)
	var fallback := _button("重新下载安装 ↗", _reinstall)
	fallback.name = "ReinstallFallback"
	fallback.flat = true
	fallback.custom_minimum_size.y = 44
	fallback.tooltip_text = "打开官方下载页，手动下载安装完整版本"
	root.add_child(fallback)
	resized.connect(_layout)
	_layout()


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(132, 50)
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(action)
	Hud._style_button(button, Hud.ACCENT)
	return button


func _layout() -> void:
	if _panel == null:
		return
	var width := minf(660, maxf(280, size.x - 32))
	var height := minf(610, maxf(260, size.y - 32))
	_panel.size = Vector2(width, height)
	_panel.position = (size - _panel.size) / 2.0


func refresh(data: Dictionary) -> void:
	if _status == null:
		return
	var state := str(data.get("state", "available"))
	var busy := state in ["downloading", "verifying"]
	var installing := state in ["installing", "permission_required", "awaiting_install"]
	var artifact: Dictionary = _info.get("artifact", {})
	var reason := str(data.get("install_reason", ""))
	_status.text = str(data.get("message", ""))
	if _status.text.is_empty():
		_status.text = str(_info.get("native_update_reason", "下载完成后，由你决定何时安装。"))
	if artifact.is_empty() and not busy and not installing:
		_status.text = str(_info.get("native_update_reason", "此版本暂未提供游戏内更新包，可以重新下载安装。"))
	elif not reason.is_empty() and not busy and not installing:
		_status.text += "\n" + reason
	_progress.visible = busy
	var total := int(data.get("total", 0))
	var completed := int(data.get("verified", 0)) if state == "verifying" else int(data.get("downloaded", 0))
	_progress.value = 100.0 * completed / maxi(1, total)
	_detail.text = ""
	if state == "downloading":
		_detail.text = "%s / %s · %.0f%%" % [_bytes(completed), _bytes(total), _progress.value]
		var speed := float(data.get("speed", 0))
		if speed > 0:
			_detail.text += " · %s/s · 约 %d 秒" % [_bytes(int(speed)), ceili(maxi(0, total - completed) / speed)]
	elif state == "verifying":
		_detail.text = "校验 %.0f%%" % _progress.value
	elif not artifact.is_empty():
		_detail.text = "更新大小 %s · 保留本地牌组、策略与录像" % _bytes(int(artifact.get("size", 0)))
	_primary.visible = not busy and not installing and state != "updated" and not artifact.is_empty()
	_primary.disabled = _updater == null or (state == "ready" and not reason.is_empty())
	_primary.text = ("安装更新" if Manifest.platform_key() == "android" else "安装并重启") if state == "ready" else ("重新下载" if state in ["failed", "cancelled"] else "下载更新")
	_cancel.visible = state == "downloading"
	_ignore.visible = state in ["idle", "available", "cancelled", "failed"]
	_later.text = "后台下载" if busy else "稍后"
	_later.visible = not installing
	_close.disabled = installing


func _primary_pressed() -> void:
	if _updater == null:
		return
	if _updater.snapshot().state == "ready":
		_updater.install_ready_update()
	else:
		_updater.start_download()


func _reinstall() -> void:
	var error := OS.shell_open(Manifest.safe_page(_info.get("download_page_url", Manifest.DOWNLOAD_PAGE)))
	if error != OK:
		DisplayServer.clipboard_set(Manifest.DOWNLOAD_PAGE)
		_status.text = "无法打开浏览器，官方下载地址已复制到剪贴板。"


func _dismiss() -> void:
	if _close != null and _close.disabled:
		return
	dismissed.emit()
	queue_free()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_dismiss()
		get_viewport().set_input_as_handled()


static func _bytes(value: int) -> String:
	return "%.1f MB" % (value / 1048576.0) if value >= 1048576 else "%.0f KB" % (value / 1024.0)
