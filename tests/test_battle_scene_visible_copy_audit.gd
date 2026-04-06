class_name TestBattleSceneVisibleCopyAudit
extends TestBase


const BATTLE_SCENE_PATH := "res://scenes/battle/BattleScene.gd"


func _u(codepoints: Array[int]) -> String:
	var text := ""
	for codepoint: int in codepoints:
		text += char(codepoint)
	return text


func _suspicious_markers() -> Array[String]:
	return [
		_u([38337, 63]),
		_u([38331, 24221, 32123, 39019, 63]),
		_u([38337, 32472, 22741, 37829, 63]),
		_u([37919, 28357, 22679, 37816, 63]),
		_u([37902, 29808, 24993, 35120, 63]),
		_u([38338, 20359, 20548, 39014, 63]),
		_u([38337, 21700, 31222, 37811, 25779, 250, 63]),
		_u([38337, 21700, 29251, 37707, 25779, 249, 63]),
		_u([38337, 21700, 26839, 37706, 63]),
		_u([38337, 25630, 20787, 37707, 63]),
		_u([32514, 63]),
	]


func test_battle_scene_visible_copy_contains_no_mojibake() -> String:
	var source := FileAccess.get_file_as_string(BATTLE_SCENE_PATH)
	var lines := source.split("\n")
	var hits: Array[String] = []
	var markers := _suspicious_markers()
	for i: int in lines.size():
		var line := lines[i]
		if char(0xFFFD) in line:
			hits.append("%d:%s" % [i + 1, line.strip_edges()])
			continue
		for marker: String in markers:
			if marker in line:
				hits.append("%d:%s" % [i + 1, line.strip_edges()])
				break
	if hits.is_empty():
		return ""
	return "BattleScene still contains mojibake lines\n%s" % "\n".join(hits)
