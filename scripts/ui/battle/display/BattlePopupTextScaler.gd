class_name BattlePopupTextScaler
extends RefCounted

const PORTRAIT_POPUP_MIN_BUTTON_WIDTH := 112.0
const PORTRAIT_POPUP_MIN_BUTTON_HEIGHT := 112.0
const PORTRAIT_POPUP_BUTTON_HEIGHT_PER_FONT := 1.8


func apply_popup_text_scale(node: Node, scale_factor: float) -> void:
	if node == null:
		return
	if node is BattleCardView:
		return
	if node is Control:
		_apply_popup_control_font_scale(node as Control, scale_factor)
	for child: Node in node.get_children():
		apply_popup_text_scale(child, scale_factor)


func _apply_popup_control_font_scale(control: Control, scale_factor: float) -> void:
	var font_names := _popup_font_theme_names(control)
	for font_name: String in font_names:
		_apply_popup_font_size(control, font_name, scale_factor)
	if control is Button:
		_apply_popup_button_minimum_size(control as Button, scale_factor)


func _popup_font_theme_names(control: Control) -> Array[String]:
	if control is RichTextLabel:
		return [
			"normal_font_size",
			"bold_font_size",
			"italics_font_size",
			"bold_italics_font_size",
			"mono_font_size",
		]
	if control is Label or control is Button or control is ItemList or control is LineEdit or control is TextEdit or control is OptionButton or control is SpinBox:
		return ["font_size"]
	return []


func _apply_popup_font_size(control: Control, font_name: String, scale_factor: float) -> void:
	var meta_key := "_portrait_popup_base_font_%s" % font_name
	if scale_factor > 1.0:
		var base_size := 0
		if control.has_meta(meta_key):
			base_size = int(control.get_meta(meta_key))
			var current_size := control.get_theme_font_size(font_name)
			var expected_scaled_size := maxi(base_size, roundi(float(base_size) * scale_factor))
			if current_size > 0 and current_size != base_size and current_size != expected_scaled_size:
				base_size = current_size
				control.set_meta(meta_key, base_size)
		else:
			base_size = control.get_theme_font_size(font_name)
			if base_size <= 0:
				return
			control.set_meta(meta_key, base_size)
		control.add_theme_font_size_override(font_name, maxi(base_size, roundi(float(base_size) * scale_factor)))
		return
	if control.has_meta(meta_key):
		control.add_theme_font_size_override(font_name, int(control.get_meta(meta_key)))
		control.remove_meta(meta_key)


func _apply_popup_button_minimum_size(button: Button, scale_factor: float) -> void:
	var meta_key := "_portrait_popup_base_minimum_size"
	if scale_factor > 1.0:
		var base_size := Vector2.ZERO
		if button.has_meta(meta_key):
			var stored_size: Variant = button.get_meta(meta_key)
			if stored_size is Vector2:
				base_size = stored_size
		else:
			base_size = button.custom_minimum_size
			button.set_meta(meta_key, base_size)
		var font_size := button.get_theme_font_size("font_size")
		var target_height := maxf(maxf(base_size.y, PORTRAIT_POPUP_MIN_BUTTON_HEIGHT), float(font_size) * PORTRAIT_POPUP_BUTTON_HEIGHT_PER_FONT)
		var target_width := base_size.x
		if target_width <= 0.0 and button.size_flags_horizontal != Control.SIZE_EXPAND_FILL:
			target_width = PORTRAIT_POPUP_MIN_BUTTON_WIDTH
		elif target_width > 0.0 and target_width < PORTRAIT_POPUP_MIN_BUTTON_WIDTH:
			target_width = PORTRAIT_POPUP_MIN_BUTTON_WIDTH
		button.custom_minimum_size = Vector2(target_width, target_height)
		return
	if button.has_meta(meta_key):
		var stored_size: Variant = button.get_meta(meta_key)
		if stored_size is Vector2:
			button.custom_minimum_size = stored_size
		button.remove_meta(meta_key)
