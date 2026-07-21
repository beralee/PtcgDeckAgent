class_name DeckShareImporter
extends RefCounted

const DeckSharePayloadCodecScript := preload("res://scripts/deck_share/DeckSharePayloadCodec.gd")
const LOCAL_ID_BASE := 900000000
const LOCAL_ID_RANGE := 999999
const SOURCE_PROVIDER := "ptcg_share_image"


static func preview_payload(payload: Dictionary, card_database: Object = null) -> Dictionary:
	var blocking_errors := PackedStringArray()
	var warnings := PackedStringArray()
	var missing_cards: Array[Dictionary] = []
	var unimplemented_cards: Array[Dictionary] = []

	var payload_errors := DeckSharePayloadCodecScript.validate_payload(payload)
	for err: String in payload_errors:
		blocking_errors.append(err)
	if not blocking_errors.is_empty():
		return _result(false, null, {}, blocking_errors, warnings, missing_cards, unimplemented_cards)

	var db := card_database if card_database != null else CardDatabase
	var deck_payload: Dictionary = payload.get("deck", {})
	var deck := DeckData.new()
	var checksum := str(payload.get("checksum", "")).strip_edges()
	if checksum == "":
		checksum = _fallback_payload_id(payload)
	deck.id = _local_deck_id(checksum, db)
	deck.deck_name = str(deck_payload.get("name", "")).strip_edges()
	deck.variant_name = deck.deck_name
	deck.source_provider = SOURCE_PROVIDER
	deck.source_id = checksum
	deck.source_url = "ptcg-share://deck/%s" % checksum
	deck.import_date = Time.get_datetime_string_from_system()
	deck.updated_at = int(Time.get_unix_time_from_system() * 1000.0)
	deck.strategy = str(deck_payload.get("note", "")).strip_edges()
	deck.cards.clear()

	var total := 0
	var rows: Array = deck_payload.get("cards", [])
	for row_raw: Variant in rows:
		var row: Array = row_raw if row_raw is Array else []
		if row.size() < 3:
			continue
		var set_code := str(row[0]).strip_edges()
		var card_index := str(row[1]).strip_edges()
		var count := int(row[2])
		var hint: Dictionary = row[3] if row.size() >= 4 and row[3] is Dictionary else {}
		var resolved := _resolve_card(db, set_code, card_index, hint)
		var card: CardData = resolved.get("card", null)
		if card == null:
			var missing := _card_issue(set_code, card_index, count, hint, "missing card data")
			missing_cards.append(missing)
			blocking_errors.append("missing card data: %s/%s" % [set_code, card_index])
			total += count
			continue

		var entry := {
			"set_code": card.set_code,
			"card_index": card.card_index,
			"count": count,
			"card_type": card.card_type,
			"name": card.display_name(),
			"effect_id": card.effect_id,
			"name_en": card.name_en,
		}
		_apply_source_hint(entry, hint)
		if str(resolved.get("resolved_via", "")) != "":
			entry["resolved_via"] = str(resolved.get("resolved_via", ""))
		deck.cards.append(entry)
		total += count

		if CardImplementationStatus.is_unimplemented(card):
			var reason := CardImplementationStatus.get_reason(card)
			unimplemented_cards.append(_card_issue(card.set_code, card.card_index, count, hint, reason))
			warnings.append("unimplemented card: %s/%s (%s)" % [card.set_code, card.card_index, reason])

	deck.total_cards = total
	if total != 60:
		blocking_errors.append("deck total must be 60, got %d" % total)

	var metadata := {
		"author": str(deck_payload.get("author", "")).strip_edges(),
		"note": str(deck_payload.get("note", "")).strip_edges(),
		"game_version": str(payload.get("game_version", "")).strip_edges(),
		"card_db_version": str(payload.get("card_db_version", "")).strip_edges(),
		"checksum": checksum,
		"source": deck_payload.get("source", {}),
		"card_count": total,
	}
	return _result(blocking_errors.is_empty(), deck, metadata, blocking_errors, warnings, missing_cards, unimplemented_cards)


static func preview_encoded_text(encoded_text: String, card_database: Object = null) -> Dictionary:
	var decoded := DeckSharePayloadCodecScript.decode_text(encoded_text)
	if not bool(decoded.get("ok", false)):
		var errors: PackedStringArray = decoded.get("errors", PackedStringArray())
		return _result(false, null, {}, errors, PackedStringArray(), [], [])
	return preview_payload(decoded.get("payload", {}), card_database)


static func _resolve_card(db: Object, set_code: String, card_index: String, hint: Dictionary) -> Dictionary:
	if db != null and db.has_method("get_card"):
		var direct: CardData = db.call("get_card", set_code, card_index)
		if direct != null:
			return {"card": direct, "resolved_via": "direct"}

	var hinted := _resolve_card_by_source_hint(db, hint)
	if hinted != null:
		return {"card": hinted, "resolved_via": "source_hint"}
	return {"card": null, "resolved_via": ""}


static func _resolve_card_by_source_hint(db: Object, hint: Dictionary) -> CardData:
	if db == null or not db.has_method("get_all_cards"):
		return null
	var provider := str(hint.get("p", "")).strip_edges().to_lower()
	var source_set := str(hint.get("s", "")).strip_edges().to_upper()
	var source_number := str(hint.get("n", "")).strip_edges().to_upper()
	var source_language := str(hint.get("l", "")).strip_edges().to_lower()
	if provider == "" and source_set == "" and source_number == "":
		return null
	var cards: Array = db.call("get_all_cards")
	for card_raw: Variant in cards:
		var card: CardData = card_raw
		if card == null:
			continue
		if provider != "" and card.source_provider.strip_edges().to_lower() != provider:
			continue
		if source_set != "" and card.source_set_code.strip_edges().to_upper() != source_set:
			continue
		if source_number != "" and card.source_card_index.strip_edges().to_upper() != source_number:
			continue
		if source_language != "" and card.source_language.strip_edges().to_lower() != source_language:
			continue
		return card
	return null


static func _apply_source_hint(entry: Dictionary, hint: Dictionary) -> void:
	if hint.is_empty():
		return
	if str(hint.get("p", "")) != "":
		entry["source_provider"] = str(hint.get("p", ""))
	if str(hint.get("s", "")) != "":
		entry["source_set_code"] = str(hint.get("s", ""))
	if str(hint.get("n", "")) != "":
		entry["source_card_index"] = str(hint.get("n", ""))
	if str(hint.get("l", "")) != "":
		entry["source_language"] = str(hint.get("l", ""))


static func _local_deck_id(checksum: String, db: Object) -> int:
	var seed: int = int(abs(checksum.hash()) % LOCAL_ID_RANGE)
	var deck_id: int = LOCAL_ID_BASE + seed
	for _i: int in LOCAL_ID_RANGE:
		if db == null or not db.has_method("has_deck") or not bool(db.call("has_deck", deck_id)):
			return deck_id
		deck_id += 1
		if deck_id >= LOCAL_ID_BASE + LOCAL_ID_RANGE:
			deck_id = LOCAL_ID_BASE
	return int(Time.get_unix_time_from_system()) + LOCAL_ID_BASE


static func _fallback_payload_id(payload: Dictionary) -> String:
	return "%08X" % abs(JSON.stringify(payload).hash())


static func _card_issue(set_code: String, card_index: String, count: int, hint: Dictionary, reason: String) -> Dictionary:
	return {
		"set_code": set_code,
		"card_index": card_index,
		"count": count,
		"source_hint": hint.duplicate(true),
		"reason": reason,
	}


static func _result(
	ok: bool,
	deck: DeckData,
	metadata: Dictionary,
	blocking_errors: PackedStringArray,
	warnings: PackedStringArray,
	missing_cards: Array[Dictionary],
	unimplemented_cards: Array[Dictionary]
) -> Dictionary:
	return {
		"ok": ok and blocking_errors.is_empty(),
		"deck": deck,
		"metadata": metadata,
		"blocking_errors": blocking_errors,
		"warnings": warnings,
		"missing_cards": missing_cards,
		"unimplemented_cards": unimplemented_cards,
	}
