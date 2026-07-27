class_name DeckTrainingCatalog
extends RefCounted


const PresentationScript := preload("res://scripts/training/DeckTrainingPresentation.gd")
const CATALOG_PATH := "res://data/deck_training/scenarios.json"
const PROVEN_DRAGAPULT_OVERLAY_PATH := "res://data/deck_training/proven_dragapult_puzzles.json"
const GHOLDENGO_CURRICULUM_OVERLAY_PATH := "res://data/deck_training/gholdengo_curriculum_puzzles.json"
const HIGH_DIFFICULTY_OVERLAY_PATH := "res://data/deck_training/high_difficulty_puzzles.json"
const GARDEVOIR_GRAPH_OVERLAY_PATH := "res://data/deck_training/gardevoir_graph_puzzles.json"
const N_ZOROARK_HIGH_DIFFICULTY_OVERLAY_PATH := "res://data/deck_training/n_zoroark_high_difficulty_puzzles.json"
const CHARIZARD_DRAGAPULT_HIGH_DIFFICULTY_OVERLAY_PATH := "res://data/deck_training/charizard_dragapult_high_difficulty_puzzles.json"
const SCENARIOS_PER_DECK := 10
const EXTRA_FROZEN_OPPONENT_DECK_IDS: Array[int] = [
	18000230, # 18.0 恶喷
	800015934, # 18.0 Tord太晶盒（皮卡丘ex针对课）
	800018497, # 18.0 标准沙奈朵（仍作为其他课程的冻结对手）
]
const DECKS := {
	"dragapult": {"id": 800018506, "name": "自爆多龙"},
	"gardevoir": {"id": 800018498, "name": "学院沙奈朵"},
	"gholdengo": {"id": 800016834, "name": "赛富豪"},
	"raging_bolt": {"id": 800018509, "name": "猛雷鼓"},
	"marnie": {"id": 800018501, "name": "玛毛"},
	"n_zoroark": {"id": 800018502, "name": "N索"},
	"charizard_dragapult": {"id": 800025404, "name": "自爆恶喷"},
}


static func load_catalog(path: String = CATALOG_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"scenarios": [], "errors": ["missing catalog: %s" % path]}
	var json := JSON.new()
	var parse_error := json.parse(FileAccess.get_file_as_string(path))
	if parse_error != OK or not (json.data is Dictionary):
		return {"scenarios": [], "errors": ["invalid catalog JSON: %s" % json.get_error_message()]}
	var catalog: Dictionary = (json.data as Dictionary).duplicate(true)
	_apply_scenario_overlay(catalog, PROVEN_DRAGAPULT_OVERLAY_PATH)
	_apply_scenario_overlay(catalog, GHOLDENGO_CURRICULUM_OVERLAY_PATH)
	_apply_scenario_overlay(catalog, HIGH_DIFFICULTY_OVERLAY_PATH)
	_apply_scenario_overlay(catalog, GARDEVOIR_GRAPH_OVERLAY_PATH)
	_apply_scenario_overlay(catalog, N_ZOROARK_HIGH_DIFFICULTY_OVERLAY_PATH)
	_apply_scenario_overlay(catalog, CHARIZARD_DRAGAPULT_HIGH_DIFFICULTY_OVERLAY_PATH)
	catalog["errors"] = validate_catalog(catalog)
	return catalog


static func _apply_scenario_overlay(catalog: Dictionary, overlay_path: String) -> void:
	if not FileAccess.file_exists(overlay_path):
		return
	var overlay_json := JSON.new()
	if overlay_json.parse(FileAccess.get_file_as_string(overlay_path)) != OK \
			or not (overlay_json.data is Dictionary):
		return
	var overlay_data: Dictionary = overlay_json.data as Dictionary
	var overlay_revision := int(overlay_data.get("scenario_revision", 1))
	var replacements: Dictionary = {}
	for scenario_variant: Variant in overlay_data.get("scenarios", []):
		if scenario_variant is Dictionary:
			var scenario: Dictionary = (scenario_variant as Dictionary).duplicate(true)
			if overlay_data.has("scenario_revision") and not scenario.has("revision"):
				scenario["revision"] = overlay_revision
			replacements[str(scenario.get("id", ""))] = scenario.duplicate(true)
	var scenarios_variant: Variant = catalog.get("scenarios", [])
	if not (scenarios_variant is Array):
		return
	var scenarios: Array = scenarios_variant
	for index: int in scenarios.size():
		if not (scenarios[index] is Dictionary):
			continue
		var scenario_id := str((scenarios[index] as Dictionary).get("id", ""))
		if replacements.has(scenario_id):
			scenarios[index] = (replacements[scenario_id] as Dictionary).duplicate(true)


static func list_scenarios(path: String = CATALOG_PATH, deck_key: String = "") -> Array[Dictionary]:
	var catalog := load_catalog(path)
	var result: Array[Dictionary] = []
	for value: Variant in catalog.get("scenarios", []):
		if value is Dictionary and (deck_key == "" or str((value as Dictionary).get("deck_key", "")) == deck_key):
			result.append((value as Dictionary).duplicate(true))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var deck_compare := str(a.get("deck_key", "")).naturalnocasecmp_to(str(b.get("deck_key", "")))
		return int(a.get("order", 0)) < int(b.get("order", 0)) if deck_compare == 0 else deck_compare < 0
	)
	return result


static func get_scenario(scenario_id: String, path: String = CATALOG_PATH) -> Dictionary:
	for scenario: Dictionary in list_scenarios(path):
		if str(scenario.get("id", "")) == scenario_id:
			return scenario
	return {}


static func deck_options() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key: String in DECKS:
		var item: Dictionary = DECKS[key]
		result.append({"key": key, "id": int(item.get("id", 0)), "name": str(item.get("name", key))})
	return result


static func validate_catalog(catalog: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var scenarios_variant: Variant = catalog.get("scenarios", [])
	if not (scenarios_variant is Array):
		return ["scenarios must be an Array"]
	var scenarios: Array = scenarios_variant
	if scenarios.size() != DECKS.size() * SCENARIOS_PER_DECK:
		errors.append("catalog must contain exactly %d scenarios" % (DECKS.size() * SCENARIOS_PER_DECK))
	var seen: Dictionary = {}
	var counts: Dictionary = {}
	for index: int in range(scenarios.size()):
		if not (scenarios[index] is Dictionary):
			errors.append("scenarios[%d] must be a Dictionary" % index)
			continue
		var scenario: Dictionary = scenarios[index]
		var scenario_id := str(scenario.get("id", "")).strip_edges()
		var deck_key := str(scenario.get("deck_key", ""))
		if scenario_id == "":
			errors.append("scenarios[%d].id is required" % index)
		elif seen.has(scenario_id):
			errors.append("duplicate scenario id: %s" % scenario_id)
		seen[scenario_id] = true
		if not DECKS.has(deck_key):
			errors.append("%s has unsupported deck_key %s" % [scenario_id, deck_key])
			continue
		counts[deck_key] = int(counts.get(deck_key, 0)) + 1
		if int(scenario.get("player_deck_id", 0)) != int((DECKS[deck_key] as Dictionary).get("id", 0)):
			errors.append("%s player_deck_id does not match %s" % [scenario_id, deck_key])
		if int(scenario.get("opponent_deck_id", 0)) not in _allowed_deck_ids():
			errors.append("%s opponent is not a supported 18.0 rules deck" % scenario_id)
		if int(scenario.get("turn_limit", 0)) not in [1, 2]:
			errors.append("%s turn_limit must be 1 or 2" % scenario_id)
		var goal: Variant = scenario.get("goal", null)
		if not (goal is Dictionary) or str((goal as Dictionary).get("type", "")) not in ["prizes", "target_knockouts", "compound"]:
			errors.append("%s goal must be prizes, target_knockouts, or compound" % scenario_id)
		if not (scenario.get("player", null) is Dictionary) or not (scenario.get("opponent", null) is Dictionary):
			errors.append("%s must define both player setups" % scenario_id)
		for presentation_issue: String in PresentationScript.instruction_issues(scenario):
			errors.append(presentation_issue)
	for deck_key: String in DECKS:
		if int(counts.get(deck_key, 0)) != SCENARIOS_PER_DECK:
			errors.append("%s must contain exactly %d scenarios" % [deck_key, SCENARIOS_PER_DECK])
	return errors


static func _allowed_deck_ids() -> Array[int]:
	# Opponents may use another frozen 18.0 production deck that is not one of
	# the seven player-facing training themes.
	var result: Array[int] = EXTRA_FROZEN_OPPONENT_DECK_IDS.duplicate()
	for item: Dictionary in DECKS.values():
		var deck_id := int(item.get("id", 0))
		if deck_id not in result:
			result.append(deck_id)
	return result
