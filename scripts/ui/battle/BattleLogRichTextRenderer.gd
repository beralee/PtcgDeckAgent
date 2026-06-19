class_name BattleLogRichTextRenderer
extends RefCounted

const DEFAULT_COLOR := "#dceff8"


func render_entry(entry: Dictionary) -> String:
	var tokens: Array = entry.get("tokens", [])
	if tokens.is_empty():
		return _wrap_color(DEFAULT_COLOR, escape_bbcode(str(entry.get("raw_text", ""))))

	var rendered := ""
	for token_variant: Variant in tokens:
		var token: Dictionary = token_variant if token_variant is Dictionary else {}
		var token_text := escape_bbcode(str(token.get("text", "")))
		if token_text == "":
			continue
		var color := str(token.get("color", DEFAULT_COLOR)).strip_edges()
		rendered += _wrap_color(color, token_text) if color != "" else token_text
	return rendered


func escape_bbcode(text: String) -> String:
	return text.replace("[", "\uE000").replace("]", "\uE001").replace("\uE000", "[lb]").replace("\uE001", "[rb]")


func _wrap_color(color: String, text: String) -> String:
	if color == "":
		return text
	return "[color=%s]%s[/color]" % [color, text]
