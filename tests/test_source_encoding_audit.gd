class_name TestSourceEncodingAudit
extends TestBase


const ROOT_TARGETS := [
	"res://scripts",
	"res://scenes",
	"res://data",
	"res://tests",
	"res://docs",
	"res://project.godot",
	"res://README.md",
	"res://CONTRIBUTING.md",
	"res://SECURITY.md",
	"res://CLAUDE.md",
	"res://DEVELOPMENT_SPEC.md",
	"res://.editorconfig",
]

const ALLOWED_EXTENSIONS := {
	"gd": true,
	"tscn": true,
	"md": true,
	"json": true,
	"txt": true,
	"cfg": true,
}

const IGNORED_DIRECTORY_NAMES := {
	"node_modules": true,
	"playwright-report": true,
	"test-results": true,
}

const KNOWN_MOJIBAKE_CODEPOINTS := {
	0x95B8: true,
	0x940E: true,
	0x9368: true,
	0x7F01: true,
	0x8930: true,
	0x7035: true,
	0x6960: true,
	0x93CD: true,
	0x951F: true,
}

const BATTLE_SCENE_FORBIDDEN_UI_PHRASES := [
	"Cannot retreat right now",
	"Opponent Hand:",
	"Your Hand:",
	"Opponent Discard",
	"Your Discard",
	"Select action",
	"Waiting for opponent",
	"Missing selected deck data",
]

const EFFECT_UI_FORBIDDEN_PHRASES := [
	"Choose cards from your deck to put into your hand",
	"Choose up to 2 Basic Energy cards from your deck and assign them to your Benched Pokemon",
	"Devolve each of your opponent's evolved Pokemon",
	"Grants a temporary attack that devolves",
	"Basic Pokemon, selectable",
	"not a Basic Pokemon, view only",
	"card_selectable_hint\": \"Choose",
	"card_disabled_badge\": \"View",
	"Unknown Card",
	"Discard Stadium",
	"Keep Stadium",
]


func test_no_suspicious_source_characters() -> String:
	var targets: Array[String] = []
	for root: String in ROOT_TARGETS:
		_collect_targets(root, targets)

	for path: String in targets:
		var error := _audit_file(path)
		if error != "":
			return error

	return ""


func test_text_diagram_box_drawing_codepoints_are_allowed() -> String:
	return run_checks([
		assert_true(_is_allowed_codepoint(0x2500), "Horizontal box-drawing lines should be valid in architecture documents"),
		assert_true(_is_allowed_codepoint(0x2514), "Tree elbows should be valid in architecture documents"),
		assert_true(_is_allowed_codepoint(0x257F), "The complete box-drawing block should be accepted"),
	])


func test_card_rarity_stars_are_text_not_encoding_damage() -> String:
	return run_checks([
		assert_eq(_check_line_codepoints("res://tests/fixtures/card.json", 1, '"rarity": "★★☆"'), "", "Card rarity stars are valid Unicode text"),
		assert_eq(_check_line_codepoints("res://docs/validation.md", 1, "✓ ✅ café 中文"), "", "Documentation symbols and multilingual text are not encoding damage"),
		assert_false(_is_allowed_codepoint(0xFFFD), "Replacement characters must still fail the encoding audit"),
		assert_false(_is_allowed_codepoint(0), "NUL characters must still fail the encoding audit"),
		assert_false(_is_allowed_codepoint(0xD800), "Unpaired surrogates are not Unicode scalar values"),
		assert_false(_is_allowed_codepoint(0xFFFF), "Noncharacters are not source text"),
	])


func _collect_targets(path: String, out: Array[String]) -> void:
	if FileAccess.file_exists(path):
		if _is_allowed_target(path):
			out.append(path)
		return

	if not DirAccess.dir_exists_absolute(path):
		return

	var dir := DirAccess.open(path)
	if dir == null:
		return

	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name == "":
			break
		if name.begins_with("."):
			continue

		var child_path := path.path_join(name)
		if dir.current_is_dir():
			if not IGNORED_DIRECTORY_NAMES.has(name):
				_collect_targets(child_path, out)
		elif _is_allowed_target(child_path):
			out.append(child_path)
	dir.list_dir_end()


func _is_allowed_target(path: String) -> bool:
	var ext := path.get_extension().to_lower()
	return ALLOWED_EXTENSIONS.has(ext)


func _audit_file(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return "Unable to open source file: %s" % path

	var text := file.get_as_text()
	var lines := text.split("\n")
	for i: int in lines.size():
		var line: String = lines[i]
		var forbidden_phrase_error := _check_forbidden_ui_phrases(path, i + 1, line)
		if forbidden_phrase_error != "":
			return forbidden_phrase_error

		var forbidden_effect_copy_error := _check_forbidden_effect_ui_phrases(path, i + 1, line)
		if forbidden_effect_copy_error != "":
			return forbidden_effect_copy_error

		var placeholder_error := _check_placeholder_question_marks(path, i + 1, line)
		if placeholder_error != "":
			return placeholder_error

		var marker_error := _check_known_mojibake(path, i + 1, line)
		if marker_error != "":
			return marker_error

		var char_error := _check_line_codepoints(path, i + 1, line)
		if char_error != "":
			return char_error

	return ""


func _check_placeholder_question_marks(path: String, line_number: int, line: String) -> String:
	var marker := "?" + "?" + "?"
	if marker in line:
		return "Detected placeholder mojibake %s at %s:%d" % [marker, path, line_number]
	return ""


func _check_forbidden_ui_phrases(path: String, line_number: int, line: String) -> String:
	if not (
		path.ends_with("scenes/battle/BattleScene.gd")
		or path.ends_with("scenes/battle/BattleSceneRuntime.gd")
		or path.begins_with("res://scenes/battle/runtime/")
	):
		return ""
	for phrase: String in BATTLE_SCENE_FORBIDDEN_UI_PHRASES:
		if phrase in line:
			return "Detected forbidden BattleScene fallback copy \"%s\" at %s:%d" % [phrase, path, line_number]
	return ""


func _check_forbidden_effect_ui_phrases(path: String, line_number: int, line: String) -> String:
	if not path.begins_with("res://scripts/effects"):
		return ""
	for phrase: String in EFFECT_UI_FORBIDDEN_PHRASES:
		if phrase in line:
			return "Detected forbidden effect UI copy \"%s\" at %s:%d" % [phrase, path, line_number]
	return ""


func _check_known_mojibake(path: String, line_number: int, line: String) -> String:
	for i: int in line.length():
		var cp := line.unicode_at(i)
		if KNOWN_MOJIBAKE_CODEPOINTS.has(cp):
			return "Detected mojibake marker U+%04X at %s:%d" % [cp, path, line_number]
	return ""


func _check_line_codepoints(path: String, line_number: int, line: String) -> String:
	for j: int in line.length():
		var cp := line.unicode_at(j)
		if _is_allowed_codepoint(cp):
			continue
		return "Detected unsupported codepoint U+%04X at %s:%d" % [cp, path, line_number]
	return ""


func _is_allowed_codepoint(codepoint: int) -> bool:
	# Audit damaged text, not a handpicked font repertoire. Card rarity and
	# documentation legitimately contain symbols outside the old block list.
	if codepoint in [9, 13]:
		return true
	if codepoint < 32 or codepoint > 0x10FFFF or (codepoint >= 0x7F and codepoint <= 0x9F):
		return false
	if codepoint == 0xFFFD or (codepoint >= 0xD800 and codepoint <= 0xDFFF):
		return false
	if (codepoint >= 0xFDD0 and codepoint <= 0xFDEF) or (codepoint & 0xFFFF) >= 0xFFFE:
		return false
	return true
