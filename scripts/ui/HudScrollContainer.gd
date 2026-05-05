class_name HudScrollContainer
extends ScrollContainer

const HudThemeScript := preload("res://scripts/ui/HudTheme.gd")

@export_enum("auto", "default", "touch", "compact") var hud_scroll_profile := "auto":
	set(value):
		hud_scroll_profile = value
		_apply_hud_scroll_style()


func _init() -> void:
	_apply_hud_scroll_style()


func _ready() -> void:
	_apply_hud_scroll_style()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_apply_hud_scroll_style.call_deferred()


func _apply_hud_scroll_style() -> void:
	HudThemeScript.style_scroll_container(self, hud_scroll_profile)
