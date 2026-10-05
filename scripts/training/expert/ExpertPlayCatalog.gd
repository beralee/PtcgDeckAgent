extends RefCounted

const PATH := "res://data/deck_training/dragapult185_expert.json"
const DECK_PATH := "res://data/deck_training/decks/675701.json"
const BROWSER := "res://scenes/deck_training/ExpertPlayBrowser.tscn"
const MODE := "expert_play_v1"
static var _cache: Dictionary = {}
static var _signature := ""


static func load_catalog() -> Dictionary:
	var signature := FileAccess.get_sha256(PATH) + FileAccess.get_sha256(DECK_PATH)
	if signature == _signature and not _cache.is_empty():
		return _cache.duplicate(true)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not parsed is Dictionary:
		return {"scenarios": [], "errors": ["expert_catalog_invalid"]}
	var result: Dictionary = parsed
	var errors: Array[String] = []
	if str(result.get("deck_sha256", "")) != FileAccess.get_sha256(DECK_PATH):
		errors.append("expert_deck_identity_changed")
	if int(result.get("deck_id", 0)) != 675701 or int(result.get("schema_version", 0)) != 1:
		errors.append("expert_catalog_identity_invalid")
	var seen: Dictionary = {}
	for scenario: Dictionary in result.get("scenarios", []):
		var id := str(scenario.get("id", ""))
		if not id.begins_with("expert-dragapult185-") or seen.has(id):
			errors.append("expert_scenario_identity_invalid")
		seen[id] = true
		if int(scenario.get("player_deck_id", 0)) != 675701 or int(scenario.get("opponent_deck_id", 0)) != 675701:
			errors.append("expert_scenario_deck_mismatch")
		if str(scenario.get("training_mode", "")) != MODE or int(scenario.get("turn_limit", 0)) not in [1, 2]:
			errors.append("expert_scenario_mode_invalid")
		if scenario.has("validation_operations") or scenario.has("deck_top") or scenario.get("player", {}).has("deck_top"):
			errors.append("expert_scenario_answer_or_order_forbidden")
	result["errors"] = errors
	result["catalog_sha256"] = FileAccess.get_sha256(PATH)
	_cache = result.duplicate(true)
	_signature = signature
	return result


static func get_scenario(id: String) -> Dictionary:
	var catalog := load_catalog()
	if not (catalog.errors as Array).is_empty():
		return {}
	for scenario: Dictionary in catalog.scenarios:
		if str(scenario.id) == id:
			return scenario.duplicate(true)
	return {}


static func verify_scenario(scenario: Dictionary) -> Dictionary:
	var original := get_scenario(str(scenario.get("id", "")))
	var ok := not original.is_empty() and original == scenario
	return {"ok": ok, "errors": [] if ok else ["expert_scenario_not_in_frozen_catalog"], "authored_operation_count": 0}
