extends SceneTree

const Parser := preload("res://scripts/network/LimitlessCardParser.gd")
const Resolver := preload("res://scripts/network/LimitlessCardResolver.gd")

const LIMITLESS_IDS := [18497, 18499, 18501, 18502, 18509]
const DECK_NAME_PREFIX := "NAIC2025"
const DECK_DISPLAY_NAMES := {
	18497: "NAIC2025 沙奈朵",
	18499: "NAIC2025 多龙巴鲁托",
	18501: "NCIC2025 玛俐的长矛巨魔",
	18502: "NAIC2025 N的索罗亚克",
	18509: "NAIC2025 猛雷鼓厄诡椪",
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


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_card_db = root.get_node_or_null("/root/CardDatabase")
	if _card_db == null:
		_add_error("CardDatabase autoload is unavailable")
		_finish()
		return
	_load_manifest()

	for raw_id: Variant in LIMITLESS_IDS:
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
	for err: String in errors:
		_add_error("deck %d import warning: %s" % [limitless_id, err])

	_normalize_deck_name(deck, limitless_id)
	_bundle_deck(deck)


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
	if str(card.set_code).begins_with("LEN_") and str(card.source_provider).strip_edges().to_lower() == "limitless":
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
