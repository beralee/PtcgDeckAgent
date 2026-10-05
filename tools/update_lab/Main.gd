extends Control
const Dialog := preload("res://scripts/update/AppUpdateDialog.gd")
const Version := preload("res://scripts/app/AppVersion.gd")
# This directory is copied to res://lab/ in the standalone update lab.
const Server := preload("LabServer.gd")
const CASES := [
	["good", "正常更新 → 安装 B 版"], ["slow", "慢速下载 / 切后台 / 取消"],
	["drop", "下载一半断开连接"], ["stall", "连接无响应 / 系统重试"],
	["truncated", "下载到不完整的文件"], ["corrupt", "文件损坏 / 校验不匹配"],
	["invalid", "文件能下载，但不是 APK"], ["missing", "下载地址失效（404）"],
	["low_space", "存储空间不足（注入）"], ["deleted", "下载完成后文件被清理"],
	["wrong_build", "安装包版本不符合清单"],
	["fixed", "固定地址更新（无清单校验信息）"],
	["fixed_invalid", "固定地址：不是 APK"],
	["fixed_wrong_version", "固定地址：旧包 / 版本不符"],
	["fixed_corrupt", "固定地址：文件损坏"],
]
var updater: Node
var http: Node
var status: Label
var address: LineEdit
var current_case := ""
var metadata: Dictionary = {}
var last_state := ""
var last_message := ""
var popup: Control
var history := PackedStringArray()

func _ready() -> void:
	updater = get_node("/root/AppUpdater")
	http = Server.new()
	add_child(http)
	metadata = JSON.parse_string(FileAccess.get_file_as_string("res://lab/release.json"))
	if not FileAccess.file_exists("user://preserved.txt"):
		var marker := FileAccess.open("user://preserved.txt", FileAccess.WRITE)
		marker.store_string("created-in-" + Version.current_version())
		marker.close()
	_build()
	updater.changed.connect(_changed)
	_changed(updater.snapshot())
	# Deterministic emulator automation, only in this separate lab application.
	var command: String = FileAccess.get_file_as_string("user://lab-command.txt") if FileAccess.file_exists("user://lab-command.txt") else ""
	if not command.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://lab-command.txt"))
		call_deferred("_choose", command.strip_edges())
	set_process(true)

func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Color("08141e")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 12)
	scroll.add_child(stack)
	_label(stack, "游戏升级验证 · " + ("B 版 ✓" if Version.BUILD_NUMBER == 2 else "A 版"), 25)
	_label(stack, "独立测试应用，不改正式游戏或线上服务。\n下载、校验和系统安装复用正式组件。", 16)
	_label(stack, "数据保留标记：" + FileAccess.get_file_as_string("user://preserved.txt"), 16)
	status = _label(stack, "请选择场景", 17)
	var actions := HFlowContainer.new()
	stack.add_child(actions)
	_button(actions, "查看下载 / 安装", _open)
	_button(actions, "重置本次测试", _reset)
	_button(actions, "复制测试记录", func() -> void: DisplayServer.clipboard_set("\n".join(history)))
	if Version.BUILD_NUMBER == 2:
		_label(stack, "已真实升级到 B 版。若标记仍是 created-in-1.0.0，说明覆盖安装保留了应用数据。\n再次完整验证：只卸载“升级验证”，再装 A 版。", 19)
		return
	for item: Array in CASES:
		_button(stack, item[1], _choose.bind(item[0]))
	_label(stack, "本机故障服务会随本应用停止。\n验证退出应用后继续下载：在电脑启动附带服务，填入它显示的地址，再选慢速下载。通知栏显示系统下载进度。", 16)
	address = LineEdit.new()
	address.placeholder_text = "可选：http://192.168.x.x:18761"
	address.custom_minimum_size.y = 48
	address.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_URL
	stack.add_child(address)
	if FileAccess.file_exists("user://lab-server.txt"):
		address.text = FileAccess.get_file_as_string("user://lab-server.txt").strip_edges()

func _label(parent: Node, value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 48
	button.add_theme_font_size_override("font_size", 17)
	button.pressed.connect(action)
	parent.add_child(button)

func _choose(which: String) -> void:
	_reset()
	current_case = which
	updater.simulate_low_space = which == "low_space"
	var mode := "good" if which in ["low_space", "deleted", "wrong_build"] else which
	if which.begins_with("fixed"):
		mode = {"fixed_invalid": "invalid", "fixed_corrupt": "corrupt", "fixed_slow": "slow"}.get(which, "good")
	var base := "http://127.0.0.1:%d" % http.port
	if address != null and not address.text.strip_edges().is_empty():
		base = address.text.strip_edges().trim_suffix("/")
	var artifact: Dictionary = metadata.duplicate(true)
	artifact.url = base + "/" + mode
	if which == "invalid":
		artifact.size = Server.INVALID.to_utf8_buffer().size()
		artifact.sha256 = Server.INVALID.sha256_text()
	if which == "wrong_build":
		artifact.build = 3
	var release_version := "1.0.2" if which == "fixed_wrong_version" else "1.0.1"
	if which.begins_with("fixed"):
		artifact = preload("res://scripts/update/AppUpdateManifest.gd").fixed_android_download(release_version)
		artifact.url = base + "/" + mode
		artifact.arch = preload("res://scripts/update/AppUpdateManifest.gd").architecture()
		artifact.download_id = (artifact.url + "\n" + release_version).sha256_text()
	var info := {"latest_version": release_version, "display_version": "B 版 · " + release_version, "title": "验证场景：" + which,
		"summary": ["不会更新正式游戏。", "取消安装、拒绝权限后均可重试。", "重新下载与官网兜底入口始终保留。"], "artifact": artifact}
	updater.offer(info)
	_open()
	updater.start_download()

func _reset() -> void:
	if is_instance_valid(popup):
		popup.queue_free()
	popup = null
	current_case = ""
	updater.reset_case()

func _open() -> void:
	if is_instance_valid(popup):
		return
	if updater.snapshot().info.is_empty():
		return
	popup = Dialog.new()
	add_child(popup)
	popup.configure(updater, updater.snapshot().info)

func _changed(data: Dictionary) -> void:
	if status == null:
		return
	status.text = str(data.state) + " · " + str(data.message)
	if data.state in ["downloading", "verifying"]:
		status.text += "\n进度 %d%% · %s / %s" % [preload("res://scripts/update/AppUpdateProgress.gd").percent(data), Dialog._bytes(int(data.downloaded)), Dialog._bytes(int(data.total))]
	if data.state != last_state or data.message != last_message:
		last_state = data.state
		last_message = data.message
		var line := "%s | %s | %s | %s" % [current_case, data.state, data.get("issue", ""), data.message]
		history.append(line)
		print("UPDATE_LAB: " + line)
		var report := FileAccess.open("user://lab-result.json", FileAccess.WRITE)
		report.store_string(JSON.stringify({"case": current_case, "state": data.state, "issue": data.get("issue", ""), "message": data.message, "version": Version.current_version(), "preserved": FileAccess.get_file_as_string("user://preserved.txt"), "history": history}))
		report.close()
	if data.state == "ready" and current_case == "deleted":
		DirAccess.remove_absolute(ProjectSettings.globalize_path(updater._package_path()))
		status.text += "\n测试已移除缓存文件，点“安装更新”应提示重新下载。"

func _process(_delta: float) -> void:
	if FileAccess.file_exists("user://lab-action.txt"):
		var action := FileAccess.get_file_as_string("user://lab-action.txt").strip_edges()
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://lab-action.txt"))
		match action:
			"install": updater.install_ready_update()
			"cancel": updater.cancel_installation(); updater.cancel_download()
			"redownload": updater.redownload()
			"background":
				if is_instance_valid(popup): popup._dismiss()
