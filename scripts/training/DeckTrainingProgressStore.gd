class_name DeckTrainingProgressStore
extends RefCounted


const SAVE_PATH := "user://deck_training_progress.json"
const GRADE_ORDER := {"": 0, "C": 1, "B": 2, "A": 3, "S": 4}


static func load_progress() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {"format_version": 2, "scenarios": {}}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(SAVE_PATH)) != OK or not (json.data is Dictionary):
		return {"format_version": 2, "scenarios": {}}
	return (json.data as Dictionary).duplicate(true)


static func scenario_progress(progress: Dictionary, scenario: Dictionary) -> Dictionary:
	var scenarios: Dictionary = progress.get("scenarios", {})
	var stored: Dictionary = scenarios.get(str(scenario.get("id", "")), {})
	var current_revision := int(scenario.get("revision", 1))
	var stored_revision := int(stored.get("revision", 1))
	return stored.duplicate(true) if stored_revision == current_revision else {}


static func record_result(scenario_id: String, result: Dictionary, scenario_revision: int = 1) -> bool:
	var progress := load_progress()
	var scenarios: Dictionary = progress.get("scenarios", {})
	var previous: Dictionary = scenarios.get(scenario_id, {})
	if int(previous.get("revision", 1)) != scenario_revision:
		previous = {}
	var new_grade := str(result.get("grade", "C"))
	var previous_grade := str(previous.get("best_grade", ""))
	var best_grade := new_grade if int(GRADE_ORDER.get(new_grade, 0)) >= int(GRADE_ORDER.get(previous_grade, 0)) else previous_grade
	scenarios[scenario_id] = {
		"completed": bool(previous.get("completed", false)) or bool(result.get("completed", false)),
		"best_grade": best_grade,
		"attempts": int(previous.get("attempts", 0)) + 1,
		"updated_at": int(Time.get_unix_time_from_system()),
		"revision": scenario_revision,
	}
	progress["format_version"] = 2
	progress["scenarios"] = scenarios
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(progress, "\t"))
	file.close()
	return true
