extends SceneTree

const Parser := preload("res://scripts/network/LimitlessCardParser.gd")
const Resolver := preload("res://scripts/network/LimitlessCardResolver.gd")
const BundleImporter := preload("res://scripts/tools/import_limitless_decks_to_bundle.gd")

const CACHE_ROOT := "res://tmp/limitless_naic2025_import"
const LIMITLESS_IDS := [
	18359, # Pidgeot control
	15934, # Tord Reklev's Tera box
	17643, # Eevee box
	17407, # Hop's Zacian
	18543, # Cynthia's Garchomp
	33475, # Yanmega ex
	18539, # Ethan's Ho-Oh
	18880, # Ethan's Typhlosion
	18500, # Toedscruel
	17631, # Froslass/Munkidori control
	38600, # Blaziken ex/Munkidori
	15734, # Dragapult/Dusknoir
	19125, # Dragapult/Blaziken ex
	17097, # Brent Tonisson no-TM Gardevoir
	18105, # Rabsca Gardevoir
	18498, # Riley McKay Gardevoir
	16834, # Gholdengo
	17047, # Mamoswine/Blaziken ex/Pidgeot ex
	15927, # Milotic/Farigiraf immunity box
	17070, # Gholdengo/Dudunsparce
	17098, # Blissey ex
	17280, # Poison Archaludon
	17405, # Gholdengo/Dragapult
	17413, # Revavroom/Ceruledge
	18334, # Poison Roaring Moon
	18714, # Iron Thorns/Crustle
	18817, # Joltik box
	21836, # N's Zoroark/Crustle
	25404, # Dusknoir Charizard
	26575, # Team Rocket's Mewtwo/Spidops
]

var _card_db: Node = null


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_card_db = root.get_node_or_null("/root/CardDatabase")
	if _card_db == null:
		push_error("CardDatabase autoload is unavailable")
		quit(1)
		return
	CardImplementationStatus.clear_cache()
	var reports: Array[Dictionary] = []
	for raw_id: Variant in LIMITLESS_IDS:
		reports.append(_audit_deck(int(raw_id)))
	print("VIDEO18_LIMITLESS_AUDIT " + JSON.stringify(reports, "\t"))
	quit(0)


func _audit_deck(limitless_id: int) -> Dictionary:
	var source_url := "https://limitlesstcg.com/decks/list/%d" % limitless_id
	var deck_path := "%s/%d.html" % [CACHE_ROOT, limitless_id]
	var report := {
		"limitless_id": limitless_id,
		"source_url": source_url,
		"name": "",
		"total_cards": 0,
		"entry_count": 0,
		"resolved": [],
		"missing": [],
		"unimplemented": [],
		"invalid_images": [],
		"passes": false,
	}
	if not FileAccess.file_exists(deck_path):
		(report["missing"] as Array).append("deck_html")
		return report
	var parsed := Parser.parse_deck_html(FileAccess.get_file_as_string(deck_path), source_url)
	report["name"] = str(parsed.get("deck_name", ""))
	report["total_cards"] = int(parsed.get("total_cards", 0))
	var entries: Array = parsed.get("cards", [])
	report["entry_count"] = entries.size()
	var candidates: Array = _card_db.call("get_all_cards")
	for raw_entry: Variant in entries:
		if raw_entry is Dictionary:
			_audit_entry(raw_entry as Dictionary, candidates, report)
	report["passes"] = (
		int(report["total_cards"]) == 60
		and (report["missing"] as Array).is_empty()
		and (report["unimplemented"] as Array).is_empty()
		and (report["invalid_images"] as Array).is_empty()
	)
	return report


func _audit_entry(entry: Dictionary, candidates: Array, report: Dictionary) -> void:
	var source_set := Parser.normalize_set_code(entry.get("source_set_code", ""))
	var source_index := Parser.normalize_card_number(entry.get("source_card_index", ""))
	var source_ref := "%s_%s" % [source_set, source_index]
	var count := int(entry.get("count", 0))
	var card_html_path := "%s/cards/%s.html" % [CACHE_ROOT, source_ref]
	if not FileAccess.file_exists(card_html_path):
		(report["missing"] as Array).append({"source": source_ref, "count": count, "reason": "card_html"})
		return
	var parsed_card := Parser.parse_card_html(
		FileAccess.get_file_as_string(card_html_path),
		Parser.card_url(source_set, source_index)
	)
	var card: CardData = null
	var resolved_via := ""
	var override: Dictionary = BundleImporter.SIMPLIFIED_CHINESE_CARD_OVERRIDES.get(source_ref, {})
	if not override.is_empty():
		card = _card_db.call("get_card", str(override.get("set_code", "")), str(override.get("card_index", "")))
		resolved_via = "simplified_chinese_override"
	else:
		var resolution := Resolver.resolve_card(parsed_card, candidates)
		var resolution_errors: Array = resolution.get("errors", [])
		if not resolution_errors.is_empty():
			(report["missing"] as Array).append({
				"source": source_ref,
				"count": count,
				"name": str(parsed_card.get("name_en", "")),
				"reason": "resolver_error",
				"details": resolution_errors,
			})
			return
		card = resolution.get("card", null)
		resolved_via = str(resolution.get("resolved_via", ""))
		if bool(resolution.get("generated", false)):
			card = null
	if card == null or str(card.set_code).begins_with("LEN_"):
		(report["missing"] as Array).append({
			"source": source_ref,
			"count": count,
			"name": str(parsed_card.get("name_en", "")),
			"reason": "no_simplified_chinese_card",
			"profile": _parsed_card_profile(parsed_card),
		})
		return
	_card_db.call("try_register_duplicate_effect_alias", card)
	var mapping := {
		"source": source_ref,
		"count": count,
		"source_name": str(parsed_card.get("name_en", "")),
		"local": card.get_uid(),
		"local_name": card.display_name(),
		"via": resolved_via,
	}
	(report["resolved"] as Array).append(mapping)
	if CardImplementationStatus.is_unimplemented(card):
		(report["unimplemented"] as Array).append({
			"source": source_ref,
			"local": card.get_uid(),
			"name": card.display_name(),
			"reason": CardImplementationStatus.get_reason(card),
		})
	var image_path := "res://data/bundled_user/cards/images/%s/%s.png.bin" % [card.set_code, card.card_index]
	if not CardData.is_valid_card_image_file(image_path) and not CardData.is_valid_card_image_file(card.image_local_path):
		(report["invalid_images"] as Array).append({"source": source_ref, "local": card.get_uid()})


func _parsed_card_profile(card: Dictionary) -> Dictionary:
	var attacks: Array[Dictionary] = []
	for raw_attack: Variant in card.get("attacks", []):
		if raw_attack is Dictionary:
			var attack := raw_attack as Dictionary
			attacks.append({
				"name": str(attack.get("name", "")),
				"cost": str(attack.get("cost", "")),
				"damage": str(attack.get("damage", "")),
				"text": str(attack.get("text", "")),
			})
	var abilities: Array[Dictionary] = []
	for raw_ability: Variant in card.get("abilities", []):
		if raw_ability is Dictionary:
			var ability := raw_ability as Dictionary
			abilities.append({
				"name": str(ability.get("name", "")),
				"text": str(ability.get("text", "")),
			})
	return {
		"card_type": str(card.get("card_type", "")),
		"mechanic": str(card.get("mechanic", "")),
		"description": str(card.get("description", "")),
		"stage": str(card.get("stage", "")),
		"hp": int(card.get("hp", 0)),
		"energy_type": str(card.get("energy_type", "")),
		"retreat_cost": int(card.get("retreat_cost", 0)),
		"weakness_energy": str(card.get("weakness_energy", "")),
		"attacks": attacks,
		"abilities": abilities,
	}
