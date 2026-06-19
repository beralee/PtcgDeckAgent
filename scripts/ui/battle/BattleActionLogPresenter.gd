class_name BattleActionLogPresenter
extends RefCounted

const COLOR_TEXT := "#dceff8"
const COLOR_PLAYER_0 := "#61d8ff"
const COLOR_PLAYER_1 := "#ffcf70"
const COLOR_DAMAGE := "#ff7666"
const COLOR_HP := "#6ff0a0"
const COLOR_PRIZE := "#ffe36a"
const COLOR_ZONE := "#9cb8ff"
const COLOR_CARD := "#ffffff"
const COLOR_ACTION := "#9dffda"
const COLOR_COUNT := "#b9f4ff"

const ZONE_KEYWORDS := [
	"LOST区",
	"放逐区",
	"弃牌区",
	"备战区",
	"战斗区",
	"牌库",
	"手牌",
	"弃牌",
	"放逐",
	"场上",
]
const PRIZE_KEYWORDS := ["奖赏卡", "奖赏"]
const ACTION_DATA_TEXT_KEYS := [
	"attack_name",
	"ability_name",
	"card_name",
	"card",
	"target",
	"target_pokemon_name",
	"pokemon_name",
	"source",
	"tool",
]


func format_action(action: GameAction, display_text: String = "", player_names: Array = []) -> Dictionary:
	var text := display_text
	if text == "" and action != null:
		text = action.description
	var entry := _base_entry(text)
	if action != null:
		entry["action_type"] = int(action.action_type)
		entry["player_index"] = action.player_index
		entry["turn_number"] = action.turn_number
		entry["tags"] = _tags_for_action(action)
		entry["importance"] = _importance_for_action(action)
	entry["tokens"] = build_tokens(text, action, player_names)
	return entry


func format_plain_message(text: String, player_names: Array = []) -> Dictionary:
	var entry := _base_entry(text)
	entry["tags"] = ["plain"]
	entry["tokens"] = build_tokens(text, null, player_names)
	return entry


func build_tokens(text: String, action: GameAction = null, player_names: Array = []) -> Array:
	if text == "":
		return []
	var ranges: Array[Dictionary] = []
	_add_player_ranges(ranges, text, player_names)
	_add_action_ranges(ranges, text, action)
	_add_keyword_ranges(ranges, text, PRIZE_KEYWORDS, "prize", COLOR_PRIZE, 66)
	_add_keyword_ranges(ranges, text, ZONE_KEYWORDS, "zone", COLOR_ZONE, 52)
	_add_regex_ranges(ranges, text, "HP\\s*\\d+(/\\d+)?", "hp", COLOR_HP, 82)
	_add_regex_ranges(ranges, text, "\\d+\\s*点?伤害", "damage", COLOR_DAMAGE, 62)
	_add_regex_ranges(ranges, text, "\\d+\\s*张", "count", COLOR_COUNT, 44)
	return _tokens_from_ranges(text, ranges)


func _base_entry(text: String) -> Dictionary:
	return {
		"raw_text": text,
		"action_type": -1,
		"player_index": -1,
		"turn_number": 0,
		"tokens": [],
		"tags": [],
		"importance": 0,
	}


func _add_player_ranges(ranges: Array[Dictionary], text: String, player_names: Array) -> void:
	for player_index: int in 2:
		var color := COLOR_PLAYER_0 if player_index == 0 else COLOR_PLAYER_1
		var candidates := _player_name_candidates(player_names, player_index)
		for candidate: String in candidates:
			_add_literal_range(ranges, text, candidate, "player_%d" % player_index, color, 100)


func _player_name_candidates(player_names: Array, player_index: int) -> Array[String]:
	var candidates: Array[String] = []
	if player_index < player_names.size():
		var explicit_name := str(player_names[player_index]).strip_edges()
		if explicit_name != "":
			candidates.append(explicit_name)
	candidates.append("玩家%d" % (player_index + 1))
	candidates.append("玩家 %d" % (player_index + 1))
	return _unique_strings(candidates)


func _add_action_ranges(ranges: Array[Dictionary], text: String, action: GameAction) -> void:
	if action == null:
		return
	var data := action.data
	var damage := int(data.get("damage", 0))
	if damage > 0:
		_add_literal_range(ranges, text, str(damage), "damage", COLOR_DAMAGE, 104)
	for key: String in ACTION_DATA_TEXT_KEYS:
		var value := str(data.get(key, "")).strip_edges()
		if value == "":
			continue
		var kind := "action" if key in ["attack_name", "ability_name"] else "card"
		var color := COLOR_ACTION if kind == "action" else COLOR_CARD
		_add_literal_range(ranges, text, value, kind, color, 76)


func _add_keyword_ranges(
	ranges: Array[Dictionary],
	text: String,
	keywords: Array,
	kind: String,
	color: String,
	priority: int
) -> void:
	for keyword_variant: Variant in keywords:
		_add_literal_range(ranges, text, str(keyword_variant), kind, color, priority)


func _add_literal_range(
	ranges: Array[Dictionary],
	text: String,
	literal: String,
	kind: String,
	color: String,
	priority: int
) -> void:
	var needle := literal.strip_edges()
	if needle == "":
		return
	var start := text.find(needle)
	while start >= 0:
		_add_range(ranges, start, start + needle.length(), kind, color, priority)
		start = text.find(needle, start + maxi(needle.length(), 1))


func _add_regex_ranges(
	ranges: Array[Dictionary],
	text: String,
	pattern: String,
	kind: String,
	color: String,
	priority: int
) -> void:
	var regex := RegEx.new()
	if regex.compile(pattern) != OK:
		return
	for match_result: RegExMatch in regex.search_all(text):
		_add_range(ranges, match_result.get_start(), match_result.get_end(), kind, color, priority)


func _add_range(
	ranges: Array[Dictionary],
	start: int,
	end: int,
	kind: String,
	color: String,
	priority: int
) -> void:
	if start < 0 or end <= start:
		return
	ranges.append({
		"start": start,
		"end": end,
		"kind": kind,
		"color": color,
		"priority": priority,
	})


func _tokens_from_ranges(text: String, raw_ranges: Array[Dictionary]) -> Array:
	var selected := _select_non_overlapping_ranges(raw_ranges)
	var tokens: Array[Dictionary] = []
	var cursor := 0
	for range_data: Dictionary in selected:
		var start := int(range_data.get("start", 0))
		var end := int(range_data.get("end", 0))
		if start > cursor:
			tokens.append(_token(text.substr(cursor, start - cursor), "normal", COLOR_TEXT))
		tokens.append(_token(text.substr(start, end - start), str(range_data.get("kind", "normal")), str(range_data.get("color", COLOR_TEXT))))
		cursor = end
	if cursor < text.length():
		tokens.append(_token(text.substr(cursor), "normal", COLOR_TEXT))
	return tokens


func _select_non_overlapping_ranges(ranges: Array[Dictionary]) -> Array[Dictionary]:
	var sorted: Array[Dictionary] = ranges.duplicate(true)
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_start := int(a.get("start", 0))
		var b_start := int(b.get("start", 0))
		if a_start != b_start:
			return a_start < b_start
		var a_priority := int(a.get("priority", 0))
		var b_priority := int(b.get("priority", 0))
		if a_priority != b_priority:
			return a_priority > b_priority
		return int(a.get("end", 0)) - a_start > int(b.get("end", 0)) - b_start
	)
	var selected: Array[Dictionary] = []
	for range_data: Dictionary in sorted:
		if not _range_overlaps_any(range_data, selected):
			selected.append(range_data)
	selected.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("start", 0)) < int(b.get("start", 0))
	)
	return selected


func _range_overlaps_any(range_data: Dictionary, selected: Array[Dictionary]) -> bool:
	var start := int(range_data.get("start", 0))
	var end := int(range_data.get("end", 0))
	for existing: Dictionary in selected:
		var existing_start := int(existing.get("start", 0))
		var existing_end := int(existing.get("end", 0))
		if start < existing_end and end > existing_start:
			return true
	return false


func _token(text: String, kind: String, color: String) -> Dictionary:
	return {
		"text": text,
		"kind": kind,
		"color": color,
	}


func _tags_for_action(action: GameAction) -> Array[String]:
	match action.action_type:
		GameAction.ActionType.DAMAGE_DEALT:
			return ["damage"]
		GameAction.ActionType.KNOCKOUT:
			return ["knockout", "prize"]
		GameAction.ActionType.TAKE_PRIZE:
			return ["prize"]
		GameAction.ActionType.DRAW_CARD:
			return ["draw"]
		GameAction.ActionType.DISCARD:
			return ["discard"]
		GameAction.ActionType.ATTACK:
			return ["attack"]
		GameAction.ActionType.USE_ABILITY:
			return ["ability"]
		_:
			return []


func _importance_for_action(action: GameAction) -> int:
	match action.action_type:
		GameAction.ActionType.KNOCKOUT, GameAction.ActionType.TAKE_PRIZE:
			return 90
		GameAction.ActionType.DAMAGE_DEALT:
			return 70 if int(action.data.get("damage", 0)) >= 100 else 50
		GameAction.ActionType.ATTACK, GameAction.ActionType.USE_ABILITY:
			return 45
		_:
			return 10


func _unique_strings(values: Array[String]) -> Array[String]:
	var seen := {}
	var result: Array[String] = []
	for value: String in values:
		if value == "" or seen.has(value):
			continue
		seen[value] = true
		result.append(value)
	return result
