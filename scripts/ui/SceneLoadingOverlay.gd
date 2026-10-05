extends CanvasLayer

## Survives scene replacement, and records actual rendered feedback separately
## from completion. Bench estimates never release the input shield.
const Baseline = preload("res://scripts/ui/SceneLoadingBaseline.gd")
var started_usec := 0
var feedback_usec := 0
var _message := ""
var _event_id := ""
var _expected_ms := 0.0
var _completed_events: Dictionary = {}
var _failed := false
var _title: Label
var _detail: Label
var _progress: ProgressBar
var _column: VBoxContainer
var _surface: Control
var _back: Button

func _ready() -> void:
	layer = 100
	_surface = ColorRect.new()
	_surface.color = Color(0.025, 0.045, 0.07, 0.94)
	_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_surface)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_surface.add_child(center)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 20)
	center.add_child(_column)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.add_theme_font_size_override("font_size", 26)
	_column.add_child(_title)
	_progress = ProgressBar.new()
	_progress.name = "LoadingProgress"
	_progress.custom_minimum_size = Vector2(0, 12)
	_progress.max_value = 1.0
	_progress.step = 0.0
	_progress.show_percentage = false
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for part: String in ["background", "fill"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("253449") if part == "background" else Color("69d4ef")
		style.set_corner_radius_all(6)
		_progress.add_theme_stylebox_override(part, style)
	_column.add_child(_progress)
	_detail = Label.new()
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_theme_font_size_override("font_size", 18)
	_detail.add_theme_color_override("font_color", Color("afbdd0"))
	_column.add_child(_detail)
	_back = Button.new()
	_back.text = "返回设置"
	_back.custom_minimum_size = Vector2(240, 52)
	_back.pressed.connect(func(): finish(); GameManager.goto_battle_setup())
	_column.add_child(_back)
	_surface.resized.connect(_update_layout)
	_update_layout()
	RenderingServer.frame_post_draw.connect(_on_draw)
	finish()

func begin(message: String, event_id: String = "") -> void:
	var replacing := not event_id.is_empty() and event_id != _event_id
	if not visible or _failed or replacing:
		started_usec = Time.get_ticks_usec()
		feedback_usec = 0
		_event_id = event_id
		_progress.value = 0.0
		_expected_ms = Baseline.expected_ms(_event_id, _completed_events.has(_event_id))
	_message = message
	_failed = false
	_back.hide()
	_progress.show()
	_progress.indeterminate = _expected_ms <= 0.0
	visible = true
	set_process(true)
	_process(0)

func fail(message: String) -> void:
	begin(message)
	_failed = true
	_title.text = message
	_progress.indeterminate = false
	_progress.hide()
	_back.show()
	_detail.text = "准备未完成，可以返回重试。"
	set_process(false)

func finish() -> void:
	if visible and started_usec > 0 and not _failed:
		_progress.indeterminate = false
		_progress.value = 1.0
		if not _event_id.is_empty():
			_completed_events[_event_id] = true
	visible = false
	set_process(false)

func _process(_delta: float) -> void:
	var elapsed := float(Time.get_ticks_usec() - started_usec) / 1000000.0
	_title.text = _message + ".".repeat(int(elapsed * 3.0) % 4)
	if not _progress.indeterminate:
		_progress.value = maxf(_progress.value, Baseline.estimated_fraction(elapsed * 1000.0, _expected_ms))
	_detail.text = "准备完成后会自动进入"
	if elapsed >= 3:
		_detail.text = "仍在本机准备，请稍候"

func _update_layout() -> void:
	_column.custom_minimum_size.x = clampf(_surface.size.x - 48.0, 240.0, 420.0)

func _on_draw() -> void:
	if visible and feedback_usec == 0:
		feedback_usec = Time.get_ticks_usec()
