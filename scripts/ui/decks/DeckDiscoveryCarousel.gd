extends PanelContainer
## Persistent viewport: only the slides move, so controls and library never jump.
const UI := preload("res://scripts/ui/decks/DeckCenterTheme.gd")
const DURATION := 0.46
var _view: WeakRef
var _layout: Dictionary
var _stage: Control
var _current: Control
var _outgoing: Control
var _recommendation: Dictionary = {}
var _counter: Label
var _pause: Button
var _progress: ProgressBar
var _animation: Tween
var _progress_animation: Tween
var _dragging := false
var _touch_id := -1
var _start := Vector2.ZERO
var _last := Vector2.ZERO
var _poster_viewer: Control

func setup(view: RefCounted, profile: Dictionary, recommendation: Dictionary) -> void:
	_view = weakref(view)
	_layout = profile.duplicate()
	name = "DiscoveryCarousel"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scale: float = profile.scale
	var shell := UI.box(UI.DISCOVERY, UI.DISCOVERY_LINE, roundi(16 * scale), (8 if profile.compact else 12) * scale)
	shell.border_width_top = maxi(1, roundi(2 * scale))
	shell.shadow_color = Color(UI.BLUE, 0.13)
	shell.shadow_size = roundi(10 * scale)
	add_theme_stylebox_override("panel", shell)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", roundi(8 * scale))
	add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", roundi(6 * scale))
	column.add_child(header)
	header.visible = not profile.compact
	var title := UI.label("发现" if profile.portrait else "发现 · 精选卡组", (20 if profile.portrait else 19) * scale, UI.ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var previous := UI.action("‹", view._advance.bind(-1), scale)
	previous.name = "RecommendationPreviousButton"
	previous.tooltip_text = "上一套"
	previous.custom_minimum_size.x = 48 * scale
	header.add_child(previous)
	_counter = UI.label("", 12 * scale, UI.MUTED)
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(_counter)
	var next := UI.action("›", view._advance.bind(1), scale)
	next.name = "RecommendationNextButton"
	next.tooltip_text = "下一套"
	next.custom_minimum_size.x = 48 * scale
	header.add_child(next)
	_pause = UI.action("暂停", view._toggle_pause, scale)
	_pause.name = "DiscoveryPauseButton"
	header.add_child(_pause)
	_stage = Control.new()
	_stage.name = "DiscoverySlideStage"
	_stage.clip_contents = true
	_stage.custom_minimum_size.y = (100 if profile.compact else (280 if profile.portrait else 210)) * scale
	_stage.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(_stage)
	_stage.resized.connect(_settle_after_resize)
	_progress = ProgressBar.new()
	_progress.name = "DiscoveryAutoProgress"
	_progress.custom_minimum_size.y = 3 * scale
	_progress.show_percentage = false
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress.add_theme_stylebox_override("background", UI.box(UI.LINE, Color.TRANSPARENT, 2, 0))
	_progress.add_theme_stylebox_override("fill", UI.box(UI.ACCENT, Color.TRANSPARENT, 2, 0))
	column.add_child(_progress)
	show_recommendation(recommendation, 0)

func _host() -> Control:
	var view: RefCounted = _view.get_ref()
	return view.host() if view != null else null

func is_transitioning() -> bool:
	return _animation != null and _animation.is_running()

func is_interacting() -> bool:
	return _dragging or is_instance_valid(_poster_viewer) or (not DisplayServer.is_touchscreen_available() and is_inside_tree() and get_global_rect().has_point(get_global_mouse_position()))

func cancel_interaction() -> void:
	_dragging = false
	if is_instance_valid(_current) and not is_transitioning():
		_current.position = Vector2.ZERO

func show_recommendation(recommendation: Dictionary, direction: int = 0) -> void:
	var same := str(_recommendation.get("id", "")) == str(recommendation.get("id", ""))
	_recommendation = recommendation.duplicate(true)
	var view: RefCounted = _view.get_ref()
	_pause.text = "播放" if bool(view._paused) else "暂停"
	for button: Node in find_children("DiscoveryPauseButton", "Button", true, false):
		button.text = _pause.text
	var pool: Array = _host().call("_combined_recommendation_pool")
	var index := 0
	for i: int in pool.size():
		if str(pool[i].get("id", "")) == str(recommendation.get("id", "")):
			index = i
	_counter.text = "%02d / %02d" % [index + 1, maxi(1, pool.size())]
	set_meta("recommendation_key", _host().call("_recommendation_poster_key", recommendation))
	if same and is_instance_valid(_current):
		return
	_finish_animation()
	var previous := _current
	_current = _build_slide(recommendation)
	_stage.add_child(_current)
	_current.size = _stage.size
	_current.minimum_size_changed.connect(func(): call_deferred("_fit_slide"))
	call_deferred("_fit_slide")
	set_progress(0)
	if previous == null or direction == 0 or not is_inside_tree():
		if is_instance_valid(previous):
			_stage.remove_child(previous)
			previous.queue_free()
	else:
		_outgoing = previous
		for button: Node in _outgoing.find_children("*", "BaseButton", true, false):
			button.disabled = true
		_current.position.x = direction * _stage.size.x
		_current.modulate.a = 0.5
		_animation = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		_animation.tween_property(previous, "position:x", -direction * _stage.size.x, DURATION)
		_animation.tween_property(previous, "modulate:a", 0.35, DURATION)
		_animation.tween_property(_current, "position:x", 0.0, DURATION)
		_animation.tween_property(_current, "modulate:a", 1.0, DURATION * 0.7)
		_animation.finished.connect(_finish_animation)
	# Reuse the original cache/import/compositor; no speculative parallel downloads.
	if is_inside_tree() and DisplayServer.get_name() != "headless":
		_host().call_deferred("_request_recommendation_poster", recommendation.duplicate(true))

func _finish_animation() -> void:
	if _animation != null:
		_animation.kill()
		_animation = null
	if is_instance_valid(_outgoing):
		_stage.remove_child(_outgoing)
		_outgoing.queue_free()
	_outgoing = null
	if is_instance_valid(_current):
		_current.position = Vector2.ZERO
		_current.modulate = Color.WHITE
		_fit_slide()

func _settle_after_resize() -> void:
	_finish_animation()
	_dragging = false
	if is_instance_valid(_current):
		_current.size = _stage.size

func _fit_slide() -> void:
	# Wrapping and font metrics settle after the slide enters the tree. Keep its
	# height fitted during movement too: the tween only owns the x position.
	if is_instance_valid(_current):
		_current.size = _stage.size

func set_progress(fraction: float) -> void:
	if _progress_animation != null:
		_progress_animation.kill()
	if fraction == 0 or not is_inside_tree():
		_progress.value = fraction * 100
	else:
		_progress_animation = create_tween()
		_progress_animation.tween_property(_progress, "value", fraction * 100, 0.7)

func _build_slide(recommendation: Dictionary) -> Control:
	var scale: float = _layout.scale
	var portrait: bool = _layout.portrait
	var compact: bool = _layout.compact
	var slide := PanelContainer.new()
	slide.name = "DiscoverySlide"
	slide.set_meta("recommendation_key", _host().call("_recommendation_poster_key", recommendation))
	slide.add_theme_stylebox_override("panel", UI.box(UI.DISCOVERY, Color.TRANSPARENT, roundi(10 * scale), (8 if compact else 10) * scale))
	var tint: Color = UI.SLIDE_TINTS[posmod(str(recommendation.get("id", "")).hash(), UI.SLIDE_TINTS.size())]
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([tint, UI.DISCOVERY, UI.SURFACE])
	gradient.offsets = PackedFloat32Array([0, 0.6, 1])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2.ZERO
	texture.fill_to = Vector2(1, 0.7)
	var backdrop := TextureRect.new()
	backdrop.texture = texture
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slide.add_child(backdrop)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", roundi(8 * scale))
	slide.add_child(content)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", roundi((10 if portrait else 22) * scale))
	content.add_child(body)
	var frame := PanelContainer.new()
	frame.name = "RecommendationPosterFrame"
	var poster_width := (132 if portrait else (150 if compact else 292)) * scale
	frame.custom_minimum_size.x = poster_width
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var frame_style := UI.box(UI.POSTER_BG, UI.LINE_STRONG, roundi(8 * scale), 5 * scale)
	frame_style.shadow_color = Color(UI.BLUE, 0.2)
	frame_style.shadow_size = roundi(8 * scale)
	frame_style.shadow_offset = Vector2(3, 3) * scale
	frame.add_theme_stylebox_override("panel", frame_style)
	body.add_child(frame)
	var stack := Control.new()
	stack.clip_contents = true
	frame.add_child(stack)
	var poster := TextureRect.new()
	poster.name = "RecommendationPosterPreview"
	poster.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	poster.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	poster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	poster.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	poster.set_meta("recommendation_key", slide.get_meta("recommendation_key"))
	stack.add_child(poster)
	poster.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cached: Dictionary = _host().get("_recommendation_poster_cache").get(slide.get_meta("recommendation_key"), {})
	poster.texture = cached.get("texture") as Texture2D
	var placeholder := UI.label("正在加载卡组图", 13 * scale, UI.MUTED)
	placeholder.name = "RecommendationPosterPlaceholder"
	placeholder.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	placeholder.visible = poster.texture == null
	stack.add_child(placeholder)
	placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", roundi(7 * scale))
	body.add_child(copy)
	if not compact:
		copy.add_child(UI.label("DECK SPOTLIGHT", (10 if portrait else 12) * scale, UI.ACCENT))
	var title := UI.label(("发现 · " if compact else "") + str(recommendation.get("deck_name", "精选卡组")), (18 if portrait or compact else 28) * scale)
	title.name = "RecommendationDeckName"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.max_lines_visible = 1 if compact else 2
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	copy.add_child(title)
	var summary := UI.label(str(recommendation.get("style_summary", recommendation.get("title", ""))), (12 if portrait else 15) * scale, UI.MUTED)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.max_lines_visible = 2 if portrait else 3
	summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	summary.visible = not compact
	copy.add_child(summary)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	copy.add_child(spacer)
	var hint := UI.label("左右滑动切换 · 点图放大" if portrait else "点击卡组图查看完整牌表", (10 if portrait else 12) * scale, UI.ACCENT)
	hint.visible = not compact
	copy.add_child(hint)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", roundi(8 * scale))
	(content if portrait else copy).add_child(actions)
	var read := UI.action("查看解读", Callable(_host(), "_on_recommendation_read_pressed").bind(recommendation), scale)
	read.name = "RecommendationDetailButton"
	read.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(read)
	var import_button := UI.action("导入这套", Callable(_host(), "_on_recommendation_import_pressed").bind(recommendation), scale, true)
	import_button.name = "RecommendationImportButton"
	import_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(import_button)
	if compact:
		var view: RefCounted = _view.get_ref()
		for spec: Array in [["‹", "RecommendationPreviousButton", view._advance.bind(-1)], ["›", "RecommendationNextButton", view._advance.bind(1)], ["播放" if view._paused else "暂停", "DiscoveryPauseButton", view._toggle_pause]]:
			var button := UI.action(spec[0], spec[2], scale)
			button.name = spec[1]
			button.custom_minimum_size.x = 48 * scale
			actions.add_child(button)
	return slide

func apply_poster(key: String) -> void:
	for preview: Node in find_children("RecommendationPosterPreview", "TextureRect", true, false):
		if str(preview.get_meta("recommendation_key", "")) != key:
			continue
		var cached: Dictionary = _host().get("_recommendation_poster_cache").get(key, {})
		preview.texture = cached.get("texture") as Texture2D
		var placeholder := preview.get_parent().get_node("RecommendationPosterPlaceholder") as Label
		placeholder.visible = preview.texture == null
		placeholder.text = "卡组图暂不可用\n点击重试" if str(_host().get("_recommendation_poster_states").get(key, "")) == "error" else "正在加载卡组图"

func handle_input(event: InputEvent) -> bool:
	var point := Vector2.ZERO
	var pressed := false
	var released := false
	if event is InputEventScreenTouch:
		point = event.position
		pressed = event.pressed
		released = not event.pressed
		if _dragging and _touch_id != event.index:
			return false
	elif event is InputEventScreenDrag:
		if not _dragging or _touch_id != event.index:
			return false
		point = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if _dragging and _touch_id != -1:
			return false
		point = event.position
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventMouseMotion:
		if not _dragging or _touch_id != -1:
			return false
		point = event.position
	else:
		return false
	if pressed:
		if not can_start_gesture(point):
			return false
		_dragging = true
		_touch_id = event.index if event is InputEventScreenTouch else -1
		_start = point
		_last = point
	elif not _dragging:
		return false
	_last = point
	var distance := _last - _start
	if released:
		_dragging = false
		_current.position.x = 0
		var view: RefCounted = _view.get_ref()
		view._elapsed = 0.0
		if absf(distance.x) >= 45 * float(_layout.scale) and absf(distance.x) > absf(distance.y) * 1.3:
			view._advance(1 if distance.x < 0 else -1)
		elif distance.length() < 12 * float(_layout.scale):
			var poster := _current.find_child("RecommendationPosterFrame", true, false) as Control
			if poster.get_global_rect().has_point(point):
				_show_poster()
	elif absf(distance.x) > absf(distance.y):
		_current.position.x = clampf(distance.x * 0.22, -40 * float(_layout.scale), 40 * float(_layout.scale))
	return true

func can_start_gesture(point: Vector2) -> bool:
	if is_transitioning() or not is_instance_valid(_current) or not UI.Touch._control_has_point(_stage, point):
		return false
	for button: Node in _current.find_children("*", "BaseButton", true, false):
		if UI.Touch._control_has_point(button, point):
			return false
	return true

func poster_contains(point: Vector2) -> bool:
	var poster := _current.find_child("RecommendationPosterFrame", true, false) as Control
	return UI.Touch._control_has_point(poster, point)

func preview_swipe(distance: Vector2) -> void:
	if is_instance_valid(_current):
		_current.position.x = clampf(distance.x * 0.22, -40 * float(_layout.scale), 40 * float(_layout.scale))

func _show_poster() -> void:
	var poster := _current.find_child("RecommendationPosterPreview", true, false) as TextureRect
	if poster.texture == null:
		_host().call("_request_recommendation_poster", _recommendation)
		return
	var panel := PanelContainer.new()
	panel.name = "DiscoveryPosterViewer"
	panel.set_meta("deck_center_modal", true)
	panel.z_index = 2750
	panel.add_theme_stylebox_override("panel", UI.box(UI.BG, UI.LINE, 0, 14 * float(_layout.scale)))
	_host().add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_poster_viewer = panel
	var column := VBoxContainer.new()
	panel.add_child(column)
	var close := UI.action("关闭卡组图", func(): panel.hide(); panel.queue_free(), float(_layout.scale))
	close.name = "DiscoveryPosterCloseButton"
	column.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.name = "DiscoveryPosterScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UI.scroll(scroll)
	column.add_child(scroll)
	var image := TextureRect.new()
	image.name = "DiscoveryPosterImage"
	image.texture = poster.texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(image)
	var fit_image := func():
		# Use the screen width, then scroll a tall poster instead of shrinking its text.
		var bar := scroll.get_v_scroll_bar()
		var width := maxf(1, scroll.size.x - (bar.get_combined_minimum_size().x if bar.visible else 0.0))
		image.custom_minimum_size.y = width * image.texture.get_height() / image.texture.get_width()
	scroll.resized.connect(fit_image)
	fit_image.call_deferred()
	var host_ref: WeakRef = weakref(_host())
	panel.resized.connect(func():
		var scene := host_ref.get_ref() as Control
		if scene != null:
			UI.button(close, float(UI.for_control(scene).scale)))
