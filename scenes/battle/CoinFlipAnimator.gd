## 投币动画 - 展示硬币翻转并落定到指定结果
class_name CoinFlipAnimator
extends Control

const DEFAULT_HEADS_TEXTURE := preload("res://assets/ui/coin_heads.png")
const DEFAULT_TAILS_TEXTURE := preload("res://assets/ui/coin_tails.png")
const COIN_SKIN_VARIANTS := [
	{
		"id": "default",
		"heads": DEFAULT_HEADS_TEXTURE,
		"tails": DEFAULT_TAILS_TEXTURE,
	},
	{
		"id": "neon",
		"heads_path": "res://assets/ui/coins/coin_neon_heads.png",
		"tails_path": "res://assets/ui/coins/coin_neon_tails.png",
	},
	{
		"id": "starlight",
		"heads_path": "res://assets/ui/coins/coin_starlight_heads.png",
		"tails_path": "res://assets/ui/coins/coin_starlight_tails.png",
	},
	{
		"id": "terra",
		"heads_path": "res://assets/ui/coins/coin_terra_heads.png",
		"tails_path": "res://assets/ui/coins/coin_terra_tails.png",
	},
]
const DEFAULT_COIN_DISPLAY_SIZE := 180.0
const DEFAULT_RESULT_FONT_SIZE := 24
const DEFAULT_CONTAINER_SEPARATION := 16
const PORTRAIT_REFERENCE_LOGICAL_WIDTH := 900.0
const PORTRAIT_MAX_TOUCH_SCALE := 1.85

## 动画完成信号
signal animation_finished()

## 硬币显示尺寸
var coin_display_size: float = DEFAULT_COIN_DISPLAY_SIZE
## 翻转总次数（快速交替正反面模拟旋转）
var flip_count: int = 10
## 每次翻转时长（逐渐变慢）
var base_flip_duration: float = 0.06

var _heads_texture: Texture2D = null
var _tails_texture: Texture2D = null
var _coin_sprite: TextureRect = null
var _result_label: Label = null
var _coin_vbox: VBoxContainer = null
var _tween: Tween = null
var _has_external_metrics_override: bool = false
var _coin_skin_index: int = -1
var _coin_skin_id: String = ""


func _ready() -> void:
	_select_coin_skin_once()
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(PRESET_FULL_RECT)
	_build_ui()
	_apply_auto_metrics()
	visible = false


func set_coin_skin_index_for_tests(index: int) -> void:
	_apply_coin_skin_index(index)


func get_coin_skin_index_for_tests() -> int:
	return _coin_skin_index


func get_coin_skin_id_for_tests() -> String:
	return _coin_skin_id


func get_coin_skin_count_for_tests() -> int:
	return COIN_SKIN_VARIANTS.size()


func get_coin_skin_textures_for_tests(index: int) -> Dictionary:
	var variant_count := COIN_SKIN_VARIANTS.size()
	if variant_count <= 0:
		return {}
	var skin: Dictionary = COIN_SKIN_VARIANTS[posmod(index, variant_count)]
	return {
		"id": str(skin.get("id", "")),
		"heads": _texture_from_skin(skin, "heads", "heads_path", DEFAULT_HEADS_TEXTURE),
		"tails": _texture_from_skin(skin, "tails", "tails_path", DEFAULT_TAILS_TEXTURE),
	}


func _select_coin_skin_once() -> void:
	if _heads_texture != null and _tails_texture != null and _coin_skin_index >= 0:
		return
	var variant_count := COIN_SKIN_VARIANTS.size()
	if variant_count <= 0:
		_heads_texture = DEFAULT_HEADS_TEXTURE
		_tails_texture = DEFAULT_TAILS_TEXTURE
		_coin_skin_index = 0
		_coin_skin_id = "default"
		return
	var index := _coin_skin_index
	if index < 0:
		index = randi() % variant_count
	_apply_coin_skin_index(index)


func _apply_coin_skin_index(index: int) -> void:
	var variant_count := COIN_SKIN_VARIANTS.size()
	if variant_count <= 0:
		_heads_texture = DEFAULT_HEADS_TEXTURE
		_tails_texture = DEFAULT_TAILS_TEXTURE
		_coin_skin_index = 0
		_coin_skin_id = "default"
		return
	var resolved_index := posmod(index, variant_count)
	var skin: Dictionary = COIN_SKIN_VARIANTS[resolved_index]
	var heads_texture := _texture_from_skin(skin, "heads", "heads_path", DEFAULT_HEADS_TEXTURE)
	var tails_texture := _texture_from_skin(skin, "tails", "tails_path", DEFAULT_TAILS_TEXTURE)
	if heads_texture == null or tails_texture == null:
		resolved_index = 0
		skin = COIN_SKIN_VARIANTS[0]
		heads_texture = DEFAULT_HEADS_TEXTURE
		tails_texture = DEFAULT_TAILS_TEXTURE
	_heads_texture = heads_texture
	_tails_texture = tails_texture
	_coin_skin_index = resolved_index
	_coin_skin_id = str(skin.get("id", "default"))
	if _coin_sprite != null:
		_coin_sprite.texture = _heads_texture


func _texture_from_skin(skin: Dictionary, texture_key: String, path_key: String, fallback: Texture2D) -> Texture2D:
	var texture_variant: Variant = skin.get(texture_key, null)
	if texture_variant is Texture2D:
		return texture_variant as Texture2D
	var path := str(skin.get(path_key, ""))
	if path != "":
		var loaded: Resource = load(path)
		if loaded is Texture2D:
			return loaded as Texture2D
	return fallback


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_auto_metrics()


func _build_ui() -> void:
	# 半透明背景遮罩（铺满全屏）
	var bg := ColorRect.new()
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.6)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	# 居中容器
	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	_coin_vbox = vbox
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", DEFAULT_CONTAINER_SEPARATION)
	center.add_child(vbox)

	# 硬币图像
	_coin_sprite = TextureRect.new()
	_coin_sprite.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_coin_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_coin_sprite.custom_minimum_size = Vector2(coin_display_size, coin_display_size)
	_coin_sprite.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if _heads_texture != null:
		_coin_sprite.texture = _heads_texture
	vbox.add_child(_coin_sprite)

	# 结果文字
	_result_label = Label.new()
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.add_theme_font_size_override("font_size", DEFAULT_RESULT_FONT_SIZE)
	_result_label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.45))
	_result_label.text = ""
	vbox.add_child(_result_label)


func apply_viewport_metrics(viewport_size: Vector2, portrait_mode: bool, external_override: bool = true) -> void:
	if _coin_sprite == null or _result_label == null:
		return
	_has_external_metrics_override = external_override
	var target_coin_size := DEFAULT_COIN_DISPLAY_SIZE
	var target_font_size := DEFAULT_RESULT_FONT_SIZE
	var target_separation := DEFAULT_CONTAINER_SEPARATION
	if portrait_mode:
		var safe_size := viewport_size
		if safe_size.x <= 0.0 or safe_size.y <= 0.0:
			safe_size = size
		if (safe_size.x <= 0.0 or safe_size.y <= 0.0) and is_inside_tree():
			safe_size = get_viewport_rect().size
		var ui_scale := _portrait_touch_scale(safe_size)
		var max_coin_size := maxf(minf(560.0 * ui_scale, safe_size.x * 0.62), 1.0)
		var min_coin_size := minf(220.0 * ui_scale, max_coin_size)
		target_coin_size = clampf(roundf(safe_size.x * 0.34), min_coin_size, max_coin_size)
		target_font_size = roundi(clampf(roundf(target_coin_size * 0.16), 32.0 * ui_scale, 54.0 * ui_scale))
		target_separation = roundi(clampf(roundf(target_coin_size * 0.08), 20.0 * ui_scale, 36.0 * ui_scale))
	coin_display_size = target_coin_size
	var coin_size := Vector2(target_coin_size, target_coin_size)
	_coin_sprite.custom_minimum_size = coin_size
	_coin_sprite.size = coin_size
	_coin_sprite.pivot_offset = coin_size * 0.5
	_result_label.add_theme_font_size_override("font_size", target_font_size)
	_result_label.custom_minimum_size = Vector2(maxf(target_coin_size * 1.4, 180.0), maxf(float(target_font_size) * 1.35, 32.0))
	if _coin_vbox != null:
		_coin_vbox.add_theme_constant_override("separation", target_separation)


func _apply_auto_metrics() -> void:
	var viewport_size := size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = get_viewport_rect().size if is_inside_tree() else Vector2.ZERO
	apply_viewport_metrics(viewport_size, viewport_size.y > viewport_size.x, false)


func _portrait_touch_scale(viewport_size: Vector2) -> float:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return 1.0
	if viewport_size.x >= viewport_size.y:
		return 1.0
	return clampf(viewport_size.x / PORTRAIT_REFERENCE_LOGICAL_WIDTH, 1.0, PORTRAIT_MAX_TOUCH_SCALE)


## 播放投币动画，result=true 表示正面，false 表示反面
func play(result: bool) -> void:
	if not _has_external_metrics_override:
		_apply_auto_metrics()
	visible = true
	_result_label.text = ""

	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = create_tween()

	# 确保从正常状态开始
	_coin_sprite.texture = _heads_texture if _heads_texture != null else _tails_texture
	_coin_sprite.pivot_offset = _coin_sprite.custom_minimum_size / 2.0
	_coin_sprite.scale = Vector2.ONE

	# 硬币快速翻转：scale.x 从 1 -> 0 -> 1 模拟翻面
	var showing_heads := true
	for i: int in flip_count:
		var is_last: bool = i == flip_count - 1
		var next_heads: bool
		if is_last:
			next_heads = result
		else:
			next_heads = not showing_heads

		# 逐渐变慢
		var duration: float = base_flip_duration + float(i) * 0.02

		# 压扁到侧面
		_tween.tween_property(_coin_sprite, "scale:x", 0.05, duration * 0.5).set_trans(Tween.TRANS_SINE)
		# 在最窄时切换贴图
		var target_heads: bool = next_heads
		_tween.tween_callback(func() -> void:
			if target_heads and _heads_texture != null:
				_coin_sprite.texture = _heads_texture
			elif not target_heads and _tails_texture != null:
				_coin_sprite.texture = _tails_texture
		)
		# 展开回来
		_tween.tween_property(_coin_sprite, "scale:x", 1.0, duration * 0.5).set_trans(Tween.TRANS_SINE)

		showing_heads = next_heads

	# 落定：轻弹放大 + 显示结果文字
	_tween.tween_property(_coin_sprite, "scale", Vector2(1.15, 1.15), 0.12).set_trans(Tween.TRANS_BACK)
	_tween.tween_property(_coin_sprite, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_SINE)
	_tween.tween_callback(func() -> void:
		_result_label.text = "正面" if result else "反面"
	)
	# 让玩家看清结果
	_tween.tween_interval(0.9)
	_tween.tween_callback(func() -> void:
		visible = false
		animation_finished.emit()
	)
