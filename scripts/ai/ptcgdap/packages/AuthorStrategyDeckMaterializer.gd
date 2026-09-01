class_name AuthorStrategyDeckMaterializer
extends RefCounted

const LOCAL_CARD_ID_DOMAIN := "godot_local_card_uid_v1"
const PACKAGE_DECK_ID := 0


static func build(handle: Variant) -> Dictionary:
	if (
		handle == null
		or not handle.has_method("validate_integrity")
		or not handle.validate_integrity()
		or not handle.has_method("to_public_dict")
		or not handle.has_method("local_deck_snapshot")
		or not handle.has_method("presentation_snapshot")
	):
		return _error("package_integrity_invalid")
	var pins: Dictionary = handle.to_public_dict()
	var presentation: Dictionary = handle.presentation_snapshot()
	if (
		pins.get("deck_card_id_domain") != LOCAL_CARD_ID_DOMAIN
		or pins.get("cabt_exportable") != false
		or int(pins.get("local_deck_card_count", 0)) != 60
		or presentation.is_empty()
		or presentation.get("package_version") != pins.get("package_version")
	):
		return _error("package_deck_materialization_failed")
	var rows: Array = handle.local_deck_snapshot()
	if rows.is_empty() or rows.size() != int(pins.get("local_deck_unique_printing_count", 0)):
		return _error("package_deck_materialization_failed")

	var deck := DeckData.new()
	deck.id = PACKAGE_DECK_ID
	deck.deck_name = "%s%s" % [
		str(presentation.get("deck_name", "")),
		_compact_player_version(str(presentation.get("package_version", ""))),
	]
	deck.source_provider = "ptcgdap_author_strategy_package"
	deck.source_id = "%s@%s#%s" % [
		str(pins.get("package_id", "")),
		str(pins.get("package_version", "")),
		str(pins.get("archive_sha256", "")),
	]
	var total := 0
	var basic_pokemon := 0
	for row_value: Variant in rows:
		if not row_value is Dictionary:
			return _error("package_deck_materialization_failed")
		var row: Dictionary = row_value
		var uid := str(row.get("local_card_uid", ""))
		var set_code := str(row.get("set_code", ""))
		var card_index := str(row.get("card_index", ""))
		var count := int(row.get("count", 0))
		if uid != "%s_%s" % [set_code, card_index] or count < 1 or count > 60:
			return _error("package_deck_materialization_failed")
		var card: CardData = CardDatabase.get_card(set_code, card_index)
		if (
			card == null
			or card.set_code != set_code
			or card.card_index != card_index
			or card.card_type != str(row.get("card_type", ""))
			or card.stage != str(row.get("stage", ""))
			or card.effect_id != str(row.get("effect_id", ""))
			or (count > 4 and card.card_type != "Basic Energy")
		):
			return _error("package_deck_materialization_failed")
		deck.cards.append({
			"set_code": set_code,
			"card_index": card_index,
			"count": count,
			"card_type": card.card_type,
			"name": card.name,
			"effect_id": card.effect_id,
			"name_en": card.name_en,
		})
		if card.card_type == "Pokemon" and card.stage == "Basic":
			basic_pokemon += count
		total += count
	if total != 60 or basic_pokemon < 1:
		return _error("package_deck_materialization_failed")
	deck.total_cards = total
	return {
		"ok": true,
		"error_code": "",
		"deck": deck,
		"deck_authority": "package_csv_manifest",
	}


static func _compact_player_version(value: String) -> String:
	var parts := value.strip_edges().split(".")
	while parts.size() > 2 and parts[parts.size() - 1] == "0":
		parts.remove_at(parts.size() - 1)
	return ".".join(parts)


static func _error(code: String) -> Dictionary:
	return {
		"ok": false,
		"error_code": code,
		"deck": null,
		"deck_authority": "package_csv_manifest",
	}
