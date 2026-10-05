extends RefCounted
## Local presentation preferences. No match or selection state is stored here.
const THEMES := {
	"grove": {"title": "林间道馆", "accent": "e2c879", "ink": "f3efdc", "muted": "adbea4", "panel": "182c25", "hp": "9adf93", "light": "ffe4b5", "trim":"738466"}
}
static func current() -> String:
	# Old saved themes and diagnostic arguments resolve to the retained field.
	return "grove"

static func palette(_id: String) -> Dictionary:
	return THEMES.grove.duplicate(true)

static func option(key: String, fallback: bool = true) -> bool:
	var config := ConfigFile.new()
	config.load("user://arena_visuals.cfg")
	return bool(config.get_value("visuals",key,fallback))

static func save_option(key: String, value: bool) -> void:
	var config := ConfigFile.new()
	config.load("user://arena_visuals.cfg")
	config.set_value("visuals",key,value)
	config.save("user://arena_visuals.cfg")

static func panel(id: String, emphasized: bool = false) -> StyleBoxFlat:
	var colors := palette(id)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(colors.panel)
	style.border_color = Color(colors.accent) if emphasized else Color(colors.muted, .28)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.shadow_color = Color(0,0,0,.35)
	style.shadow_size = 5
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style
