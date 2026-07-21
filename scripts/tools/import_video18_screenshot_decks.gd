extends SceneTree

const BUNDLED_USER_DIR := "res://data/bundled_user/"
const BUNDLED_DECKS_DIR := BUNDLED_USER_DIR + "decks/"
const BUNDLED_MANIFEST := BUNDLED_USER_DIR + "_manifest.txt"
const VIDEO_URL := "https://www.bilibili.com/video/BV1qpN26rErY/"

const SCREENSHOT_DECKS := [
	{
		"id": 18000072,
		"name": "18.0 下石鸟N的索罗亚克",
		"source_id": "BV1qpN26rErY@01:12",
		"source_url": VIDEO_URL + "?t=72",
		"clone_deck_id": 800018502,
		"adjustments": [
			{"ref": "CSV10C_041", "delta": -1},
			{"ref": "CSV10C_040", "delta": -1},
			{"ref": "CSV6C_112", "delta": 2},
		],
	},
	{
		"id": 18000081,
		"name": "18.0 控制N的索罗亚克",
		"source_id": "BV1qpN26rErY@01:21",
		"source_url": VIDEO_URL + "?t=81",
		"clone_deck_id": 800018502,
		"adjustments": [
			{"ref": "CSV10C_041", "delta": -1},
			{"ref": "CSV10C_040", "delta": -1},
			{"ref": "CSV4C_044", "delta": -1},
			{"ref": "CSV8C_172", "delta": -1},
			{"ref": "CSV10C_166", "delta": -1},
			{"ref": "CSV4C_099", "delta": 2},
			{"ref": "151C_017", "delta": 1},
			{"ref": "CSV4C_101", "delta": 2},
		],
	},
	{
		"id": 18000098,
		"name": "18.0 原野水母N的索罗亚克",
		"source_id": "BV1qpN26rErY@01:38",
		"source_url": VIDEO_URL + "?t=98",
		"clone_deck_id": 800018502,
		"adjustments": [
			{"ref": "CSV10C_041", "delta": -1},
			{"ref": "CSV10C_040", "delta": -1},
			{"ref": "CSV4C_044", "delta": -1},
			{"ref": "CSV8C_172", "delta": -1},
			{"ref": "CSVSC_005", "delta": 2},
			{"ref": "CSV5C_009", "delta": 2},
		],
	},
	{
		"id": 18000320,
		"name": "18.0 猴神恶喷",
		"source_id": "BV1qpN26rErY@05:20",
		"source_url": VIDEO_URL + "?t=320",
		"clone_deck_id": 1700005,
		"adjustments": [
			{"ref": "CS5.5C_032", "delta": -2},
			{"ref": "CSV8C_082", "delta": -1},
			{"ref": "CSV8C_083", "delta": -1},
			{"ref": "CSV8C_094", "delta": 3},
			{"ref": "CSVE1C_DAR", "delta": 3},
			{"ref": "CSVE1C_FIR", "delta": -2},
		],
	},
	{
		"id": 18000393,
		"name": "18.0 比雕火焰鸡",
		"source_id": "BV1qpN26rErY@06:33",
		"source_url": VIDEO_URL + "?t=393",
		"cards": [
			{"ref": "CSV7C_038", "count": 3},
			{"ref": "CSV10C_038", "count": 1},
			{"ref": "CSV7C_037", "count": 2},
			{"ref": "CSV7C_036", "count": 4},
			{"ref": "CSV4C_099", "count": 2},
			{"ref": "151C_017", "count": 1},
			{"ref": "CSV4C_101", "count": 2},
			{"ref": "CSV8C_094", "count": 2},
			{"ref": "CSV8C_135", "count": 1},
			{"ref": "CSV7C_141", "count": 1},
			{"ref": "CSV10C_007", "count": 1},
			{"ref": "CSV10C_043", "count": 1},
			{"ref": "CSV4C_044", "count": 1},
			{"ref": "CSV9C_127", "count": 1},
			{"ref": "CSV6C_115", "count": 1},
			{"ref": "CSV1C_112", "count": 3},
			{"ref": "CSV7C_177", "count": 3},
			{"ref": "CSV8C_183", "count": 1},
			{"ref": "CSV6C_114", "count": 1},
			{"ref": "CSV6C_119", "count": 2},
			{"ref": "CSV7C_185", "count": 3},
			{"ref": "CSV8C_176", "count": 1},
			{"ref": "CSV5C_119", "count": 1},
			{"ref": "CSV1C_123", "count": 4},
			{"ref": "CSV3C_123", "count": 3},
			{"ref": "CSV1C_121", "count": 2},
			{"ref": "CSVH1aC_023", "count": 1},
			{"ref": "CSV2C_127", "count": 2},
			{"ref": "CSVE1C_FIR", "count": 4},
			{"ref": "CSVE1C_PSY", "count": 1},
			{"ref": "CSVE1C_DAR", "count": 2},
			{"ref": "CSV2C_128", "count": 2},
		],
	},
	{
		"id": 18000405,
		"name": "18.0 祭典乐舞",
		"source_id": "BV1qpN26rErY@06:45",
		"source_url": VIDEO_URL + "?t=405",
		"clone_deck_id": 602769,
	},
	{
		"id": 18000519,
		"name": "18.0 螃蟹免疫盒",
		"source_id": "BV1qpN26rErY@08:39",
		"source_url": VIDEO_URL + "?t=519",
		"clone_deck_id": 800015927,
		"adjustments": [
			{"ref": "CSV8C_056", "delta": -3},
			{"ref": "CSV8C_057", "delta": -3},
			{"ref": "CSVE1C_WAT", "delta": -3},
			{"ref": "CSV10C_009", "delta": 3},
			{"ref": "CSV10C_010", "delta": 3},
			{"ref": "CSVE1C_GRA", "delta": 3},
		],
	},
	{
		"id": 18000612,
		"name": "18.0 赤松水牛龟",
		"source_id": "BV1qpN26rErY@10:12",
		"source_url": VIDEO_URL + "?t=612",
		"clone_deck_id": 800015934,
		"adjustments": [
			{"ref": "CSV8C_028", "delta": -2},
			{"ref": "CSV8C_067", "delta": -2},
			{"ref": "CSV9C_054", "delta": -1},
			{"ref": "CSV8C_172", "delta": -1},
			{"ref": "CSV9C_162", "delta": 3},
			{"ref": "CSV9C_175", "delta": 2},
			{"ref": "CSV9C_161", "delta": 1},
		],
	},
	{
		"id": 18000663,
		"name": "18.0 比雕火伊布",
		"source_id": "BV1qpN26rErY@11:03",
		"source_url": VIDEO_URL + "?t=663",
		"clone_deck_id": 800017643,
		"adjustments": [
			{"ref": "CSV9C_090", "delta": -2},
			{"ref": "CSV10C_082", "delta": -1},
			{"ref": "151C_151", "delta": -1},
			{"ref": "CSV9.5C_006", "delta": -1},
			{"ref": "CSV8C_067", "delta": -1},
			{"ref": "CSV4C_099", "delta": 2},
			{"ref": "151C_017", "delta": 1},
			{"ref": "CSV4C_101", "delta": 2},
			{"ref": "CSVH1C_045", "delta": 1},
		],
	},
	{
		"id": 18000625,
		"name": "18.0 愿增猿火焰鸡",
		"source_id": "BV1qpN26rErY@06:25",
		"source_url": VIDEO_URL + "?t=385",
		"cards": [
			{"ref": "CSV10C_036", "count": 4, "source": "DRI_40"},
			{"ref": "CSV10C_037", "count": 3, "source": "DRI_41"},
			{"ref": "CSV7C_038", "count": 3, "source": "JTG_24"},
			{"ref": "CSV10C_038", "count": 1, "source": "DRI_42"},
			{"ref": "CSV9C_127", "count": 2, "source": "SVP_149"},
			{"ref": "CSV8C_094", "count": 3, "source": "TWM_95"},
			{"ref": "CSV8C_135", "count": 1, "source": "SFA_38"},
			{"ref": "CSV3C_062", "count": 1, "source": "PAL_97"},
			{"ref": "CSV10C_007", "count": 1, "source": "DRI_10"},
			{"ref": "CSV7C_177", "count": 1, "source": "TEF_144"},
			{"ref": "CSVH1C_043", "count": 2, "source": "SVI_181"},
			{"ref": "CSV1C_112", "count": 3, "source": "SVI_196"},
			{"ref": "CSV6C_115", "count": 2, "source": "PAR_163"},
			{"ref": "CSV6C_114", "count": 2, "source": "PAR_160"},
			{"ref": "CSV8C_183", "count": 2, "source": "SFA_61"},
			{"ref": "CSV5C_119", "count": 3, "source": "PAR_178"},
			{"ref": "CSVH1C_045", "count": 1, "source": "SVI_191"},
			{"ref": "CSV8C_176", "count": 1, "source": "TWM_163"},
			{"ref": "CSV1C_109", "count": 2, "source": "PAL_188"},
			{"ref": "CSV1C_118", "count": 1, "source": "PAL_173"},
			{"ref": "CSV1C_123", "count": 4, "source": "OBF_186"},
			{"ref": "CSV3C_123", "count": 4, "source": "PAL_185"},
			{"ref": "CSV1C_121", "count": 2, "source": "JTG_155"},
			{"ref": "CSVH1aC_023", "count": 1, "source": "PAL_172"},
			{"ref": "CSV2C_127", "count": 2, "source": "PAL_171"},
			{"ref": "CSVE1C_DAR", "count": 4, "source": "SVE_7"},
			{"ref": "CSVE1C_FIR", "count": 3, "source": "SVE_2"},
			{"ref": "CSVE1C_PSY", "count": 1, "source": "SVE_5"},
		],
	},
	{
		"id": 18000230,
		"name": "18.0 喷火龙多龙巴鲁托",
		"source_id": "BV1qpN26rErY@03:50",
		"source_url": VIDEO_URL + "?t=230",
		"cards": [
			{"ref": "CSV8C_157", "count": 4, "source": "TWM_128"},
			{"ref": "CSV8C_158", "count": 4, "source": "TWM_129"},
			{"ref": "CSV8C_159", "count": 2, "source": "TWM_130"},
			{"ref": "151C_004", "count": 2, "source": "OBF_26"},
			{"ref": "CSV5C_015", "count": 1, "source": "OBF_27"},
			{"ref": "CSV5C_075", "count": 2, "source": "OBF_125"},
			{"ref": "CSV9.5C_004", "count": 1, "source": "PRE_4"},
			{"ref": "CSV5C_022", "count": 1, "source": "PAR_29"},
			{"ref": "CSV8C_135", "count": 1, "source": "SFA_38"},
			{"ref": "CSV1C_079", "count": 1, "source": "SVI_118"},
			{"ref": "CSV8C_094", "count": 1, "source": "TWM_95"},
			{"ref": "CSV1C_123", "count": 4, "source": "OBF_186"},
			{"ref": "CSV3C_123", "count": 4, "source": "PAL_185"},
			{"ref": "CSVH1aC_023", "count": 3, "source": "PAL_172"},
			{"ref": "CSV10C_207", "count": 1, "source": "JTG_146"},
			{"ref": "CSV1C_121", "count": 1, "source": "JTG_155"},
			{"ref": "CSV7C_177", "count": 4, "source": "TEF_144"},
			{"ref": "CSV1C_112", "count": 3, "source": "SVI_196"},
			{"ref": "CSVH1C_045", "count": 2, "source": "SVI_191"},
			{"ref": "CSV6C_114", "count": 1, "source": "PAR_160"},
			{"ref": "CSVH1C_043", "count": 1, "source": "SVI_181"},
			{"ref": "CSV8C_183", "count": 1, "source": "SFA_61"},
			{"ref": "CSV1C_109", "count": 1, "source": "PAL_188"},
			{"ref": "CSV8C_173", "count": 1, "source": "TWM_165"},
			{"ref": "CSV7C_185", "count": 1, "source": "TEF_159"},
			{"ref": "CSV5C_119", "count": 1, "source": "PAR_178"},
			{"ref": "CSV8C_203", "count": 1, "source": "TWM_153"},
			{"ref": "CSV10C_219", "count": 1, "source": "DRI_180"},
			{"ref": "CSVE1C_FIR", "count": 5, "source": "SVE_2"},
			{"ref": "CSV1C_127", "count": 4, "source": "PAL_191"},
		],
	},
]

var _card_db: Node = null
var _summary: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_card_db = root.get_node_or_null("/root/CardDatabase")
	if _card_db == null:
		push_error("CardDatabase autoload is unavailable")
		quit(1)
		return
	CardImplementationStatus.clear_cache()
	var manifest := _read_manifest()
	var failed := false
	for raw_recipe: Variant in SCREENSHOT_DECKS:
		if not (raw_recipe is Dictionary):
			continue
		var result := _build_deck(raw_recipe as Dictionary)
		_summary.append(result)
		if not bool(result.get("passes", false)):
			failed = true
			continue
		var deck_path := BUNDLED_DECKS_DIR + "%d.json" % int(result.get("id", 0))
		_write_json(deck_path, result.get("deck", {}))
		manifest[deck_path] = true
	_write_manifest(manifest)
	print("VIDEO18_SCREENSHOT_IMPORT " + JSON.stringify(_summary, "\t"))
	quit(1 if failed else 0)


func _build_deck(recipe: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var cards: Array[Dictionary] = []
	var total := 0
	var ace_spec_count := 0
	var radiant_count := 0
	var basic_pokemon_count := 0
	var recipe_entries := _recipe_entries(recipe, errors)
	for raw_entry: Variant in recipe_entries:
		if not (raw_entry is Dictionary):
			continue
		var entry := raw_entry as Dictionary
		var ref := str(entry.get("ref", ""))
		var separator := ref.rfind("_")
		if separator <= 0:
			errors.append("invalid local card ref %s" % ref)
			continue
		var set_code := ref.substr(0, separator)
		var card_index := ref.substr(separator + 1)
		var count := int(entry.get("count", 0))
		var card: CardData = _card_db.call("get_card", set_code, card_index)
		if card == null:
			errors.append("missing local card %s" % ref)
			continue
		if card.is_ace_spec():
			ace_spec_count += count
		if card.is_radiant():
			radiant_count += count
		if card.card_type == "Pokemon" and (card.stage == "Basic" or card.has_tag("Basic")):
			basic_pokemon_count += count
		if card.set_code.begins_with("LEN_"):
			errors.append("English placeholder is forbidden: %s" % ref)
			continue
		_card_db.call("try_register_duplicate_effect_alias", card)
		if CardImplementationStatus.is_unimplemented(card):
			errors.append("unimplemented %s: %s" % [ref, CardImplementationStatus.get_reason(card)])
		var image_path := "res://data/bundled_user/cards/images/%s/%s.png.bin" % [card.set_code, card.card_index]
		if not CardData.is_valid_card_image_file(image_path) and not CardData.is_valid_card_image_file(card.image_local_path):
			errors.append("missing image %s" % ref)
		var source_ref := str(entry.get("source", ""))
		var source_separator := source_ref.rfind("_")
		var source_set := source_ref.substr(0, source_separator) if source_separator > 0 else ""
		var source_index := source_ref.substr(source_separator + 1) if source_separator > 0 else ""
		cards.append({
			"set_code": card.set_code,
			"card_index": card.card_index,
			"count": count,
			"card_type": card.card_type,
			"name": card.display_name(),
			"name_en": card.name_en,
			"effect_id": card.effect_id,
			"resolved_via": "video_screenshot_simplified_chinese",
			"source_provider": "bilibili_screenshot",
			"source_set_code": source_set,
			"source_card_index": source_index,
			"source_language": "ja",
			"source_name": "",
			"source_url": str(recipe.get("source_url", VIDEO_URL)),
		})
		total += count
	if total != 60:
		errors.append("deck has %d cards instead of 60" % total)
	var name_counts := {}
	for entry: Dictionary in cards:
		if str(entry.get("card_type", "")) == "Basic Energy":
			continue
		var card_name := str(entry.get("name", ""))
		name_counts[card_name] = int(name_counts.get(card_name, 0)) + int(entry.get("count", 0))
		if int(name_counts[card_name]) > 4:
			errors.append("too many copies of %s" % card_name)
	if ace_spec_count > 1:
		errors.append("deck has %d ACE SPEC cards; the limit is 1" % ace_spec_count)
	if radiant_count > 1:
		errors.append("deck has %d Radiant Pokemon; the limit is 1" % radiant_count)
	if basic_pokemon_count == 0:
		errors.append("deck must contain at least one Basic Pokemon")
	var now := int(Time.get_unix_time_from_system() * 1000.0)
	var deck := {
		"id": int(recipe.get("id", 0)),
		"deck_name": str(recipe.get("name", "")),
		"variant_name": str(recipe.get("name", "")),
		"source_url": str(recipe.get("source_url", VIDEO_URL)),
		"source_provider": "bilibili_screenshot",
		"source_id": str(recipe.get("source_id", "")),
		"import_date": Time.get_datetime_string_from_system(),
		"updated_at": now,
		"deck_code": "",
		"cards": cards,
		"total_cards": total,
		"strategy": "",
	}
	return {
		"id": int(recipe.get("id", 0)),
		"name": str(recipe.get("name", "")),
		"total_cards": total,
		"passes": errors.is_empty(),
		"errors": errors,
		"deck": deck,
	}


func _recipe_entries(recipe: Dictionary, errors: Array[String]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var clone_deck_id := int(recipe.get("clone_deck_id", 0))
	if clone_deck_id > 0:
		var source_deck: DeckData = _card_db.call("get_deck", clone_deck_id)
		if source_deck == null:
			errors.append("missing clone source deck %d" % clone_deck_id)
			return result
		for source_entry: Dictionary in source_deck.cards:
			var set_code := str(source_entry.get("set_code", ""))
			var card_index := str(source_entry.get("card_index", ""))
			result.append({
				"ref": "%s_%s" % [set_code, card_index],
				"count": int(source_entry.get("count", 0)),
				"source": "%s_%s" % [set_code, card_index],
			})
	else:
		for raw_entry: Variant in recipe.get("cards", []):
			if raw_entry is Dictionary:
				result.append((raw_entry as Dictionary).duplicate(true))
	for raw_adjustment: Variant in recipe.get("adjustments", []):
		if not (raw_adjustment is Dictionary):
			continue
		var adjustment := raw_adjustment as Dictionary
		var ref := str(adjustment.get("ref", ""))
		var delta := int(adjustment.get("delta", 0))
		var matched := false
		for i: int in result.size():
			if str(result[i].get("ref", "")) != ref:
				continue
			result[i]["count"] = int(result[i].get("count", 0)) + delta
			matched = true
			if int(result[i].get("count", 0)) <= 0:
				result.remove_at(i)
			break
		if not matched and delta > 0:
			result.append({"ref": ref, "count": delta, "source": str(adjustment.get("source", ref))})
		elif not matched and delta < 0:
			errors.append("clone adjustment cannot remove missing card %s" % ref)
	return result


func _read_manifest() -> Dictionary:
	var result := {}
	if not FileAccess.file_exists(BUNDLED_MANIFEST):
		return result
	for line: String in FileAccess.get_file_as_string(BUNDLED_MANIFEST).split("\n"):
		var trimmed := line.strip_edges()
		if trimmed != "":
			result[trimmed] = true
	return result


func _write_manifest(entries: Dictionary) -> void:
	var lines: Array[String] = []
	for key: Variant in entries.keys():
		lines.append(str(key))
	lines.sort()
	_write_text(BUNDLED_MANIFEST, "\n".join(lines) + "\n")


func _write_json(path: String, value: Dictionary) -> void:
	_write_text(path, JSON.stringify(value, "\t"))


func _write_text(path: String, value: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute.get_base_dir()):
		DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	if file == null:
		push_error("unable to write %s" % path)
		return
	file.store_string(value)
	file.close()
