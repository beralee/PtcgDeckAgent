extends SceneTree

const Parser := preload("res://scripts/network/LimitlessCardParser.gd")
const Resolver := preload("res://scripts/network/LimitlessCardResolver.gd")

const LIMITLESS_IDS := [18497, 18499, 18501, 18502, 18509]
const DECK_TRAINING_LIMITLESS_IDS := [18506]
const VIDEO18_LIMITLESS_IDS := [15934, 18359, 17643, 17407, 18543, 33475, 18539, 18880, 17631, 18500]
const VIDEO18_EXPANSION_IDS := [15734, 19125, 17097, 18105, 18498, 16834, 17047]
const VIDEO18_REMAINING_IDS := [15927, 17070, 17098, 17280, 17405, 17413, 18334, 18714, 18817, 21836, 25404, 26575]
const DECK_NAME_PREFIX := "18.0"
const DECK_DISPLAY_NAMES := {
	15734: "18.0 自爆多龙巴鲁托",
	15934: "18.0 Tord太晶盒",
	16834: "18.0 纯赛富豪",
	17047: "18.0 象牙猪火焰鸡",
	17097: "18.0 无碟沙奈朵",
	18359: "18.0 大比鸟控制",
	18105: "18.0 虫甲圣沙奈朵",
	17643: "18.0 火伊布猫头夜鹰",
	17407: "18.0 赫普苍响",
	33475: "18.0 远古巨蜓",
	17631: "18.0 雪妖女愿增猿",
	18500: "18.0 陆地水母厄诡椪",
	18539: "18.0 阿响凤王",
	18543: "18.0 竹兰烈咬陆鲨",
	18880: "18.0 阿响火暴兽",
	18497: "18.0 沙奈朵",
	18498: "18.0 学院沙奈朵",
	18499: "18.0 多龙巴鲁托",
	18501: "18.0 玛俐的长毛巨魔",
	18502: "18.0 N的索罗亚克",
	18509: "18.0 猛雷鼓厄诡椪",
	18506: "18.0 自爆多龙巴鲁托（卡组训练）",
	19125: "18.0 火焰鸡多龙巴鲁托",
	15927: "18.0 回血药免疫盒",
	17070: "18.0 土龙赛富豪",
	17098: "18.0 纯幸福蛋",
	17280: "18.0 毒桥龙",
	17405: "18.0 多龙赛富豪",
	17413: "18.0 普隆隆姆苍炎刃鬼",
	18334: "18.0 毒轰",
	18714: "18.0 螃蟹铁荆棘",
	18817: "18.0 电电虫盒",
	21836: "18.0 螃蟹N的索罗亚克",
	25404: "18.0 自爆恶喷",
	26575: "18.0 火箭队超梦爆阵蛛",
}
const SIMPLIFIED_CHINESE_CARD_OVERRIDES := {
	"DRI_2": {"set_code": "CSV10C", "card_index": "002"},
	"DRI_3": {"set_code": "CSV10C", "card_index": "003"},
	"DRI_7": {"set_code": "CSV10C", "card_index": "004"},
	"DRI_8": {"set_code": "CSV10C", "card_index": "005"},
	"DRI_10": {"set_code": "CSV10C", "card_index": "007"},
	"DRI_11": {"set_code": "CSV10C", "card_index": "009"},
	"DRI_12": {"set_code": "CSV10C", "card_index": "010"},
	"DRI_32": {"set_code": "CSV10C", "card_index": "028"},
	"DRI_33": {"set_code": "CSV10C", "card_index": "029"},
	"DRI_34": {"set_code": "CSV10C", "card_index": "030"},
	"DRI_39": {"set_code": "CSV10C", "card_index": "035"},
	"DRI_40": {"set_code": "CSV10C", "card_index": "036"},
	"DRI_41": {"set_code": "CSV10C", "card_index": "037"},
	"DRI_42": {"set_code": "CSV10C", "card_index": "038"},
	"DRI_102": {"set_code": "CSV10C", "card_index": "111"},
	"DRI_103": {"set_code": "CSV10C", "card_index": "112"},
	"DRI_104": {"set_code": "CSV10C", "card_index": "113"},
	"DRI_129": {"set_code": "CSV10C", "card_index": "138"},
	"DRI_134": {"set_code": "CSV10C", "card_index": "146"},
	"DRI_135": {"set_code": "CSV10C", "card_index": "147"},
	"DRI_136": {"set_code": "CSV10C", "card_index": "148"},
	"DRI_162": {"set_code": "CSV10C", "card_index": "200"},
	"DRI_165": {"set_code": "CSV10C", "card_index": "208"},
	"DRI_169": {"set_code": "CSV10C", "card_index": "216"},
	"DRI_176": {"set_code": "CSV10C", "card_index": "212"},
	"DRI_180": {"set_code": "CSV10C", "card_index": "219"},
	"JTG_8": {"set_code": "CSV10C", "card_index": "008"},
	"JTG_26": {"set_code": "CSV10C", "card_index": "040"},
	"JTG_27": {"set_code": "CSV10C", "card_index": "041"},
	"JTG_56": {"set_code": "CSV10C", "card_index": "082"},
	"JTG_77": {"set_code": "CSV10C", "card_index": "102"},
	"JTG_78": {"set_code": "CSV10C", "card_index": "103"},
	"JTG_79": {"set_code": "CSV10C", "card_index": "104"},
	"JTG_97": {"set_code": "CSV10C", "card_index": "144"},
	"JTG_98": {"set_code": "CSV10C", "card_index": "145"},
	"JTG_116": {"set_code": "CSV10C", "card_index": "166"},
	"JTG_117": {"set_code": "CSV10C", "card_index": "175"},
	"JTG_121": {"set_code": "CSV10C", "card_index": "179"},
	"JTG_138": {"set_code": "CSV10C", "card_index": "188"},
	"JTG_146": {"set_code": "CSV10C", "card_index": "207"},
	"JTG_147": {"set_code": "CSV10C", "card_index": "195"},
	"JTG_148": {"set_code": "CSV10C", "card_index": "201"},
	"JTG_152": {"set_code": "CSV10C", "card_index": "215"},
	"JTG_153": {"set_code": "CSV10C", "card_index": "190"},
	"JTG_154": {"set_code": "CSV10C", "card_index": "218"},
	"JTG_156": {"set_code": "CSV10C", "card_index": "193"},
	"JTG_157": {"set_code": "CSV10C", "card_index": "205"},
	"PRE_6": {"set_code": "CSV9.5C", "card_index": "006"},
	"PRE_14": {"set_code": "CSV9.5C", "card_index": "023"},
	"PRE_4": {"set_code": "CSV9.5C", "card_index": "004"},
	"PRE_75": {"set_code": "CSV9.5C", "card_index": "140"},
	"PRE_77": {"set_code": "CSV9.5C", "card_index": "141"},
	"PRE_86": {"set_code": "CSV9.5C", "card_index": "149"},
	"PAR_29": {"set_code": "CSV5C", "card_index": "022"},
	"PAR_102": {"set_code": "SVP", "card_index": "080"},
	"PAL_71": {"set_code": "CSV2C", "card_index": "041"},
	"PAL_123": {"set_code": "CSV4C", "card_index": "074"},
	"SSP_97": {"set_code": "CSV9C", "card_index": "096"},
	"SSP_131": {"set_code": "CSV9C", "card_index": "142"},
	"SSP_176": {"set_code": "CSV9C", "card_index": "176"},
	"SSP_41": {"set_code": "CSV8C", "card_index": "056"},
	"SSP_137": {"set_code": "CSV8C", "card_index": "154"},
	"OBF_195": {"set_code": "CSV2C", "card_index": "125"},
	"MEW_133": {"set_code": "151C", "card_index": "133"},
	"JTG_111": {"set_code": "CSV10C", "card_index": "161"},
	"SSP_187": {"set_code": "CSV8C", "card_index": "196"},
	"PAL_174": {"set_code": "CSV3C", "card_index": "129"},
	"PAL_156": {"set_code": "CSVH3aC", "card_index": "002"},
	# PAR 016 and SCR 017 are different Toedscool prints. The user explicitly
	# chose the available Simplified-Chinese CSVSC 005 print for both slots so
	# the reconstructed list keeps the original four-copy Toedscool line.
	"PAR_16": {"set_code": "CSVSC", "card_index": "005", "deck_rebuild": true},
	"SCR_17": {"set_code": "CSVSC", "card_index": "005"},
	"OBF_22": {"set_code": "CSV5C", "card_index": "010"},
	"SCR_137": {"set_code": "CSV9C", "card_index": "192"},
	"TWM_158": {"set_code": "CSV7C", "card_index": "190"},
	"SCR_114": {"set_code": "CSV9C", "card_index": "154"},
	"SCR_115": {"set_code": "CSV9C", "card_index": "155"},
	"SCR_118": {"set_code": "CSV9C", "card_index": "161"},
	"SCR_128": {"set_code": "CSV9C", "card_index": "175"},
	"SCR_131": {"set_code": "CSV9C", "card_index": "207"},
	"SCR_132": {"set_code": "CSV9C", "card_index": "202"},
	"SCR_133": {"set_code": "CSV9C", "card_index": "196"},
	"SFA_40": {"set_code": "CSV9C", "card_index": "133"},
	"SSP_4": {"set_code": "CSV9C", "card_index": "006"},
	"SSP_21": {"set_code": "CSV9C", "card_index": "023"},
	"SSP_32": {"set_code": "CSV9C", "card_index": "033"},
	"SSP_57": {"set_code": "CSV9C", "card_index": "054"},
	"SSP_76": {"set_code": "CSV9C", "card_index": "078"},
	"SSP_86": {"set_code": "CSV9C", "card_index": "090"},
	"SSP_143": {"set_code": "CSV9C", "card_index": "153"},
	"SSP_170": {"set_code": "CSV9C", "card_index": "198"},
	"SSP_185": {"set_code": "CSV9C", "card_index": "186"},
	"SSP_189": {"set_code": "CSV9C", "card_index": "181"},
	"TWM_50": {"set_code": "CSV9C", "card_index": "039"},
	"ASC_39": {"set_code": "CSV10C", "card_index": "043"},
	"SVP_149": {"set_code": "CSV9C", "card_index": "127"},
	# Black Bolt's Elgyem print has not been released in Simplified Chinese.
	# Keep the original Pokemon name with the available Simplified-Chinese print.
	"BLK_40": {"set_code": "CS6bC", "card_index": "047", "deck_rebuild": true},
	"BLK_79": {"set_code": "CS1bC", "card_index": "128"},
	# Video 18.0 rebuilds. These cards either have an equivalent Simplified-
	# Chinese print whose English metadata is blank, or are unreleased utility
	# cards replaced by the closest legal card with the same deck-building role.
	"TEF_66": {"set_code": "CSV8C", "card_index": "078", "deck_rebuild": true},
	"SFA_62": {"set_code": "CSV8C", "card_index": "176", "deck_rebuild": true},
	"OBF_197": {"set_code": "CSV1C", "card_index": "118", "deck_rebuild": true},
	"SCR_106": {"set_code": "CSV9C", "card_index": "136"},
	"SSP_130": {"set_code": "CSV9C", "card_index": "138"},
	"SSP_36": {"set_code": "CSV9C", "card_index": "034"},
	"SSP_164": {"set_code": "CSV9C", "card_index": "183"},
	"SSP_116": {"set_code": "CSV9C", "card_index": "112"},
	"JTG_158": {"set_code": "CSV10C", "card_index": "189"},
	"PAR_182": {"set_code": "CSV3C", "card_index": "130"},
	"SCR_50": {"set_code": "CSV9C", "card_index": "063"},
	"ASC_40": {"set_code": "CSV10C", "card_index": "044", "deck_rebuild": true},
	"PFL_11": {"set_code": "151C", "card_index": "004", "deck_rebuild": true},
	"PFL_12": {"set_code": "CSV5C", "card_index": "015", "deck_rebuild": true},
	"OBF_163": {"set_code": "151C", "card_index": "017"},
	"DRI_19": {"set_code": "CSV10C", "card_index": "018"},
	"DRI_20": {"set_code": "CSV10C", "card_index": "019"},
	"DRI_51": {"set_code": "CSV10C", "card_index": "052"},
	"DRI_81": {"set_code": "CSV10C", "card_index": "085"},
	"DRI_87": {"set_code": "CSV10C", "card_index": "095"},
	"DRI_168": {"set_code": "CSV10C", "card_index": "192"},
	"DRI_170": {"set_code": "CSV10C", "card_index": "210"},
	"DRI_171": {"set_code": "CSV10C", "card_index": "209"},
	"DRI_173": {"set_code": "CSV10C", "card_index": "220"},
	"DRI_174": {"set_code": "CSV10C", "card_index": "211"},
	"DRI_177": {"set_code": "CSV10C", "card_index": "213"},
	"DRI_178": {"set_code": "CSV10C", "card_index": "199"},
	"DRI_182": {"set_code": "CSV10C", "card_index": "222"},
	"WHT_80": {"set_code": "CSV1C", "card_index": "117", "deck_rebuild": true},
	# No matching SVI 085 print exists in the Simplified-Chinese pool. The 18.0
	# Gardevoir rebuild intentionally uses the available Refinement Kirlia.
	"SVI_85": {"set_code": "CS6.5C", "card_index": "030", "deck_rebuild": true},
}
const CACHE_ROOT := "res://tmp/limitless_naic2025_import"
const BUNDLED_USER_DIR := "res://data/bundled_user/"
const BUNDLED_CARDS_DIR := BUNDLED_USER_DIR + "cards/"
const BUNDLED_DECKS_DIR := BUNDLED_USER_DIR + "decks/"
const BUNDLED_IMAGES_DIR := BUNDLED_CARDS_DIR + "images/"
const BUNDLED_MANIFEST := BUNDLED_USER_DIR + "_manifest.txt"

var _card_db: Node = null
var _summary: Dictionary = {
	"decks": [],
	"errors": [],
	"generated_cards": {},
	"new_bundled_cards": {},
	"new_manifest_entries": [],
}
var _manifest_entries: Array[String] = []
var _manifest_seen: Dictionary = {}
var _strict_mode := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_card_db = root.get_node_or_null("/root/CardDatabase")
	if _card_db == null:
		_add_error("CardDatabase autoload is unavailable")
		_finish()
		return
	_load_manifest()
	var args := OS.get_cmdline_user_args()
	var selected_ids: Array = LIMITLESS_IDS
	if args.has("--video18-expansion"):
		selected_ids = VIDEO18_EXPANSION_IDS
	elif args.has("--video18-remaining"):
		selected_ids = VIDEO18_REMAINING_IDS
	elif args.has("--video18"):
		selected_ids = VIDEO18_LIMITLESS_IDS
	elif args.has("--deck-training"):
		selected_ids = DECK_TRAINING_LIMITLESS_IDS
	_strict_mode = args.has("--strict") or args.has("--video18") or args.has("--video18-expansion") or args.has("--video18-remaining") or args.has("--deck-training")

	for raw_id: Variant in selected_ids:
		_import_and_bundle_deck(int(raw_id))

	_write_manifest()
	_finish()


func _finish() -> void:
	print("IMPORT_LIMITLESS_BUNDLE_SUMMARY " + JSON.stringify(_summary, "\t"))
	quit(1 if not (_summary.get("errors", []) as Array).is_empty() else 0)


func _import_and_bundle_deck(limitless_id: int) -> void:
	var source_url := "https://limitlesstcg.com/decks/list/%d" % limitless_id
	var deck_html_path := "%s/%d.html" % [CACHE_ROOT, limitless_id]
	if not FileAccess.file_exists(deck_html_path):
		_add_error("missing cached deck HTML %s" % deck_html_path)
		return
	var parsed := Parser.parse_deck_html(FileAccess.get_file_as_string(deck_html_path), source_url)
	var deck := _deck_from_limitless_parse(parsed, limitless_id, source_url)
	var errors := deck.validate()
	var entries := deck.cards.duplicate(true)
	for entry_raw: Variant in entries:
		if entry_raw is Dictionary:
			_resolve_limitless_entry(deck, entry_raw as Dictionary, errors)
	_normalize_deck_name(deck, limitless_id)
	_validate_resolved_deck_construction(deck, errors)
	if _strict_mode and not errors.is_empty():
		_summary["decks"].append({
			"id": deck.id,
			"name": deck.deck_name,
			"source_url": deck.source_url,
			"total_cards": deck.total_cards,
			"skipped": true,
			"errors": Array(errors),
		})
		for err: String in errors:
			_add_error("deck %d skipped: %s" % [limitless_id, err])
		return
	for err: String in errors:
		_add_error("deck %d import warning: %s" % [limitless_id, err])

	_bundle_deck(deck)


func _validate_resolved_deck_construction(deck: DeckData, errors: PackedStringArray) -> void:
	var name_counts := {}
	var ace_spec_count := 0
	var radiant_count := 0
	var basic_pokemon_count := 0
	for entry: Dictionary in deck.cards:
		var set_code := str(entry.get("set_code", "")).strip_edges()
		var card_index := str(entry.get("card_index", "")).strip_edges()
		var card: CardData = _card_db.call("get_card", set_code, card_index)
		if card == null:
			continue
		var count := int(entry.get("count", 0))
		if card.card_type != "Basic Energy":
			var card_name := card.display_name()
			name_counts[card_name] = int(name_counts.get(card_name, 0)) + count
		if card.is_ace_spec():
			ace_spec_count += count
		if card.is_radiant():
			radiant_count += count
		if card.card_type == "Pokemon" and (card.stage == "Basic" or card.has_tag("Basic")):
			basic_pokemon_count += count
	for card_name: Variant in name_counts:
		var count := int(name_counts[card_name])
		if count > 4:
			errors.append("Resolved card '%s' has %d copies; non-Basic-Energy cards are capped at 4" % [str(card_name), count])
	if ace_spec_count > 1:
		errors.append("Resolved deck has %d ACE SPEC cards; the limit is 1" % ace_spec_count)
	if radiant_count > 1:
		errors.append("Resolved deck has %d Radiant Pokemon; the limit is 1" % radiant_count)
	if basic_pokemon_count == 0:
		errors.append("Resolved deck must contain at least one Basic Pokemon")


func _deck_from_limitless_parse(parsed: Dictionary, limitless_id: int, source_url: String) -> DeckData:
	var deck := DeckData.new()
	deck.id = int(parsed.get("id", Parser.limitless_deck_local_id(limitless_id)))
	deck.deck_name = str(parsed.get("deck_name", "Limitless %d" % limitless_id)).strip_edges()
	if deck.deck_name == "":
		deck.deck_name = "Limitless %d" % limitless_id
	deck.source_url = str(parsed.get("source_url", source_url))
	deck.source_provider = "limitless"
	deck.source_id = str(parsed.get("source_id", limitless_id))
	deck.import_date = Time.get_datetime_string_from_system()
	deck.updated_at = int(Time.get_unix_time_from_system() * 1000.0)
	var cards_raw: Variant = parsed.get("cards", [])
	var cards_array: Array = cards_raw if cards_raw is Array else []
	deck.cards.clear()
	for entry: Variant in cards_array:
		if entry is Dictionary:
			deck.cards.append((entry as Dictionary).duplicate(true))
	deck.total_cards = int(parsed.get("total_cards", 0))
	return deck


func _resolve_limitless_entry(deck: DeckData, entry: Dictionary, errors: PackedStringArray) -> void:
	var source_set := Parser.normalize_set_code(entry.get("source_set_code", ""))
	var source_index := Parser.normalize_card_number(entry.get("source_card_index", ""))
	if source_set == "" or source_index == "":
		errors.append("Limitless card entry is missing set or number")
		return
	var card_html_path := "%s/cards/%s_%s.html" % [CACHE_ROOT, source_set, source_index]
	var parsed_card := entry.duplicate(true)
	if FileAccess.file_exists(card_html_path):
		parsed_card = Parser.parse_card_html(FileAccess.get_file_as_string(card_html_path), Parser.card_url(source_set, source_index))
	else:
		errors.append("Limitless card %s/%s missing cached card HTML" % [source_set, source_index])
	var candidates: Array = _card_db.call("get_all_cards")
	var resolved := Resolver.resolve_card(parsed_card, candidates)
	var resolver_errors: Array = resolved.get("errors", [])
	if not resolver_errors.is_empty():
		for resolver_error: Variant in resolver_errors:
			errors.append("Limitless card %s/%s resolver failed: %s" % [source_set, source_index, str(resolver_error)])
		return
	var card: CardData = resolved.get("card", null)
	if card == null:
		errors.append("Limitless card %s/%s could not be resolved" % [source_set, source_index])
		return
	var resolved_via := str(resolved.get("resolved_via", ""))
	var chinese_override: Dictionary = SIMPLIFIED_CHINESE_CARD_OVERRIDES.get("%s_%s" % [source_set, source_index], {})
	if not chinese_override.is_empty():
		var chinese_card: CardData = _card_db.call(
			"get_card",
			str(chinese_override.get("set_code", "")),
			str(chinese_override.get("card_index", ""))
		)
		if chinese_card == null:
			errors.append("Simplified-Chinese override %s/%s is unavailable" % [
				str(chinese_override.get("set_code", "")),
				str(chinese_override.get("card_index", "")),
			])
			return
		card = chinese_card
		resolved_via = "simplified_chinese_deck_rebuild" if bool(chinese_override.get("deck_rebuild", false)) else "simplified_chinese_reprint"
		_card_db.call("try_register_duplicate_effect_alias", card)
	elif _strict_mode and (bool(resolved.get("generated", false)) or str(card.set_code).begins_with("LEN_")):
		errors.append("Limitless card %s/%s has no Simplified-Chinese implementation" % [source_set, source_index])
		return
	elif str(card.set_code).begins_with("LEN_") and str(card.source_provider).strip_edges().to_lower() == "limitless":
		card = Resolver.build_generated_card(parsed_card)
		_card_db.call("cache_card", card)
		resolved_via = "generated_limitless_card"
	elif bool(resolved.get("generated", false)):
		var existing: CardData = _card_db.call("get_card", card.set_code, card.card_index)
		if _generated_limitless_card_has_source_collision(existing, card):
			errors.append("Limitless generated card %s/%s conflicts with existing source metadata" % [card.set_code, card.card_index])
			return
		_card_db.call("cache_card", card)
	else:
		_card_db.call("try_register_duplicate_effect_alias", card)
	_update_deck_entry(deck, entry, card, resolved_via)
	if CardImplementationStatus.is_unimplemented(card):
		errors.append("Limitless card %s/%s is not rule-runnable: %s" % [
			source_set,
			source_index,
			CardImplementationStatus.get_reason(card),
		])


func _generated_limitless_card_has_source_collision(existing: CardData, generated: CardData) -> bool:
	if existing == null or generated == null:
		return false
	if str(generated.source_provider).strip_edges().to_lower() != "limitless":
		return false
	if existing.get_uid() != generated.get_uid():
		return false
	if str(existing.source_provider).strip_edges().to_lower() != "limitless":
		return true
	return (
		str(existing.source_set_code).strip_edges().to_upper() != str(generated.source_set_code).strip_edges().to_upper()
		or str(existing.source_card_index).strip_edges().to_upper() != str(generated.source_card_index).strip_edges().to_upper()
		or str(existing.source_language).strip_edges().to_lower() != str(generated.source_language).strip_edges().to_lower()
	)


func _update_deck_entry(deck: DeckData, source_entry: Dictionary, card: CardData, resolved_via: String) -> void:
	for i: int in deck.cards.size():
		var entry: Dictionary = deck.cards[i]
		if str(entry.get("source_set_code", "")) != str(source_entry.get("source_set_code", "")):
			continue
		if str(entry.get("source_card_index", "")) != str(source_entry.get("source_card_index", "")):
			continue
		entry["set_code"] = card.set_code
		entry["card_index"] = card.card_index
		entry["card_type"] = card.card_type
		entry["name"] = card.display_name()
		entry["name_en"] = card.name_en
		entry["effect_id"] = card.effect_id
		entry["resolved_via"] = resolved_via
		entry["source_provider"] = str(source_entry.get("source_provider", "limitless"))
		entry["source_set_code"] = str(source_entry.get("source_set_code", entry.get("source_set_code", "")))
		entry["source_card_index"] = str(source_entry.get("source_card_index", entry.get("source_card_index", "")))
		entry["source_language"] = str(source_entry.get("source_language", entry.get("source_language", "en")))
		entry["source_url"] = str(source_entry.get("source_url", entry.get("source_url", "")))
		entry["source_name"] = str(source_entry.get("source_name", source_entry.get("name", entry.get("source_name", ""))))
		deck.cards[i] = entry
		return


func _normalize_deck_name(deck: DeckData, limitless_id: int) -> void:
	if DECK_DISPLAY_NAMES.has(limitless_id):
		deck.deck_name = str(DECK_DISPLAY_NAMES[limitless_id])
		deck.variant_name = deck.deck_name
		return
	var base_name := deck.deck_name.strip_edges()
	if base_name == "":
		base_name = "Limitless %d" % limitless_id
	if not base_name.begins_with(DECK_NAME_PREFIX):
		base_name = "%s %s %d" % [DECK_NAME_PREFIX, base_name, limitless_id]
	deck.deck_name = base_name
	deck.variant_name = base_name


func _bundle_deck(deck: DeckData) -> void:
	var deck_errors: Array[String] = []
	var generated_refs: Array[String] = []
	var new_refs: Array[String] = []

	for entry: Dictionary in deck.cards:
		var set_code := str(entry.get("set_code", "")).strip_edges()
		var card_index := str(entry.get("card_index", "")).strip_edges()
		if set_code == "" or card_index == "":
			deck_errors.append("unresolved deck entry %s/%s" % [
				str(entry.get("source_set_code", "")),
				str(entry.get("source_card_index", "")),
			])
			continue
		var card: CardData = _card_db.call("get_card", set_code, card_index)
		if card == null:
			deck_errors.append("missing resolved card %s/%s" % [set_code, card_index])
			continue
		if str(entry.get("resolved_via", "")) == "generated_limitless_card":
			generated_refs.append(card.get_uid())
		var card_result := _bundle_card(card, entry)
		if bool(card_result.get("new_card", false)):
			new_refs.append(card.get_uid())
		var card_errors: Array = card_result.get("errors", [])
		for err: Variant in card_errors:
			deck_errors.append(str(err))

	var deck_path := BUNDLED_DECKS_DIR + "%d.json" % deck.id
	_write_json(deck_path, deck.to_dict())
	_add_manifest_entry(deck_path)

	_summary["decks"].append({
		"id": deck.id,
		"name": deck.deck_name,
		"source_url": deck.source_url,
		"total_cards": deck.total_cards,
		"generated_cards": generated_refs,
		"new_bundled_cards": new_refs,
		"errors": deck_errors,
	})
	_summary["generated_cards"][str(deck.id)] = generated_refs
	_summary["new_bundled_cards"][str(deck.id)] = new_refs
	for err: String in deck_errors:
		_add_error("deck %d bundle warning: %s" % [deck.id, err])


func _bundle_card(card: CardData, source_entry: Dictionary) -> Dictionary:
	card.ensure_image_metadata()
	var uid := card.get_uid()
	var errors: Array[String] = []
	var card_path := BUNDLED_CARDS_DIR + "%s.json" % uid
	var was_new_card := not FileAccess.file_exists(card_path)
	if was_new_card or _should_refresh_limitless_card_json(card_path, card):
		_write_json(card_path, card.to_dict())
	_add_manifest_entry(card_path)

	var image_path := BUNDLED_IMAGES_DIR + "%s/%s.png.bin" % [card.set_code, card.card_index]
	if not CardData.is_valid_card_image_file(image_path):
		var copied := _copy_existing_image(card, source_entry, image_path)
		if not copied:
			errors.append("missing valid image for %s" % uid)
	if CardData.is_valid_card_image_file(image_path):
		_add_manifest_entry(image_path)
	else:
		errors.append("missing valid bundled image for %s" % uid)

	return {
		"new_card": was_new_card,
		"errors": errors,
	}


func _copy_existing_image(card: CardData, source_entry: Dictionary, target_path: String) -> bool:
	var candidates := PackedStringArray()
	if card.image_local_path != "":
		candidates.append(card.image_local_path)
	candidates.append(CardData.build_local_image_path(card.set_code, card.card_index))
	var source_set := Parser.normalize_set_code(source_entry.get("source_set_code", card.source_set_code))
	var source_index := Parser.normalize_card_number(source_entry.get("source_card_index", card.source_card_index))
	if source_set != "" and source_index != "":
		candidates.append("%s/images/%s_%s.png" % [CACHE_ROOT, source_set, source_index])
	for candidate: String in candidates:
		if candidate == "":
			continue
		if CardData.is_valid_card_image_file(candidate):
			return _copy_bytes(candidate, target_path)
	return false


func _should_refresh_limitless_card_json(path: String, card: CardData) -> bool:
	if str(card.source_provider).strip_edges().to_lower() != "limitless":
		return false
	var existing_raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (existing_raw is Dictionary):
		return true
	var existing := existing_raw as Dictionary
	return str(existing.get("source_provider", "")).strip_edges().to_lower() == "limitless"


func _load_manifest() -> void:
	_manifest_entries.clear()
	_manifest_seen.clear()
	if not FileAccess.file_exists(BUNDLED_MANIFEST):
		return
	var text := FileAccess.get_file_as_string(BUNDLED_MANIFEST)
	for line: String in text.split("\n"):
		var trimmed := line.strip_edges()
		if trimmed == "":
			continue
		_add_manifest_entry(trimmed, false)


func _add_manifest_entry(path: String, track_new: bool = true) -> void:
	if path == "" or _manifest_seen.has(path):
		return
	_manifest_seen[path] = true
	_manifest_entries.append(path)
	if track_new:
		(_summary["new_manifest_entries"] as Array).append(path)


func _write_manifest() -> bool:
	_manifest_entries.sort()
	return _write_text(BUNDLED_MANIFEST, "\n".join(_manifest_entries) + "\n")


func _write_json(path: String, data: Dictionary) -> bool:
	return _write_text(path, JSON.stringify(data, "\t"))


func _write_text(path: String, content: String) -> bool:
	_ensure_res_dir(path.get_base_dir())
	var file := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.WRITE)
	if file == null:
		_add_error("unable to write %s" % path)
		return false
	file.store_string(content)
	file.close()
	return true


func _copy_bytes(source_path: String, target_path: String) -> bool:
	var bytes := FileAccess.get_file_as_bytes(source_path)
	if bytes.is_empty():
		_add_error("unable to read image %s" % source_path)
		return false
	_ensure_res_dir(target_path.get_base_dir())
	var file := FileAccess.open(ProjectSettings.globalize_path(target_path), FileAccess.WRITE)
	if file == null:
		_add_error("unable to write image %s" % target_path)
		return false
	file.store_buffer(bytes)
	file.close()
	return true


func _ensure_res_dir(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute):
		DirAccess.make_dir_recursive_absolute(absolute)


func _add_error(message: String) -> void:
	push_warning(message)
	(_summary["errors"] as Array).append(message)
