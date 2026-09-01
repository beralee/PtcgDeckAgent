class_name AuthorStrategySourceDocuments
extends RefCounted

const CatalogScript = preload("res://scripts/ai/ptcgdap/host/godot/CardIdCatalog.gd")
const CardInstanceScript = preload("res://scripts/data/CardInstance.gd")
const MAX_DOCUMENTS := 128
const EXPECTED_CATALOG_HASH := "AB8CF10465F492A98DA8247A84572AECEE281D0726F7BB7B8E5DBC03A6AC70D4"
static var _FACTORY_TOKEN: RefCounted = RefCounted.new()

var _catalog: Variant = null
var _documents: Dictionary = {}
var _raw_hashes: Dictionary = {}
var _identities: Array = []
var _factory_token: Variant = null


static func load_for_cards(cards: Variant) -> Dictionary:
	if not cards is Array or cards.is_empty():
		return _error("invalid_source_cards")
	var catalog: Variant = CatalogScript.load_default()
	if catalog == null or not catalog.validate_integrity():
		return _error("catalog_unavailable")
	var documents := {}
	var raw_hashes := {}
	var identities := []
	for value: Variant in cards:
		if not _exact_script(value, CardInstanceScript) or value.card_data == null:
			return _error("invalid_source_cards")
		var set_code: String = str(value.card_data.set_code)
		var card_index: String = str(value.card_data.card_index)
		if not _identity_component(set_code) or not _identity_component(card_index):
			return _error("invalid_source_cards")
		var key := "%s/%s" % [set_code, card_index]
		if documents.has(key):
			continue
		if documents.size() >= MAX_DOCUMENTS:
			return _error("resource_limit_exceeded")
		var path := "res://data/bundled_user/cards/%s_%s.json" % [set_code, card_index]
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			return _error("source_document_missing")
		var bytes: PackedByteArray = file.get_buffer(file.get_length())
		file.close()
		var checked: Dictionary = catalog.validate_local_source(set_code, card_index, bytes)
		if not bool(checked.get("ok", false)):
			return _error("source_document_untrusted")
		documents[key] = bytes
		raw_hashes[key] = _raw_hash(bytes)
		identities.append({"set_code": set_code, "card_index": card_index})
	var script: GDScript = load("res://scripts/ai/ptcgdap/host/godot/AuthorStrategySourceDocuments.gd")
	var owner: Variant = script.new(catalog, documents, raw_hashes, identities, _FACTORY_TOKEN)
	if not owner.validate_integrity():
		return _error("source_document_untrusted")
	return {"ok": true, "error_code": "", "source_documents": owner}


func _init(catalog: Variant = null, documents: Dictionary = {}, raw_hashes: Dictionary = {}, identities: Array = [], token: Variant = null) -> void:
	if token != _FACTORY_TOKEN:
		return
	_catalog = catalog
	_documents = documents.duplicate(true)
	_raw_hashes = raw_hashes.duplicate(true)
	_identities = identities.duplicate(true)
	_factory_token = token


func validate_integrity() -> bool:
	if _factory_token != _FACTORY_TOKEN or not _exact_script(_catalog, CatalogScript) or _catalog.source_contract_hash != EXPECTED_CATALOG_HASH:
		return false
	if not _documents is Dictionary or _documents.is_empty() or _documents.size() > MAX_DOCUMENTS:
		return false
	if not _raw_hashes is Dictionary or _raw_hashes.size() != _documents.size():
		return false
	if not _identities is Array or _identities.size() != _documents.size():
		return false
	var seen := {}
	for identity_value: Variant in _identities:
		if not identity_value is Dictionary or identity_value.keys().size() != 2:
			return false
		var set_code: Variant = identity_value.get("set_code")
		var card_index: Variant = identity_value.get("card_index")
		if not _identity_component(set_code) or not _identity_component(card_index):
			return false
		var key := "%s/%s" % [set_code, card_index]
		if seen.has(key) or not _documents.has(key) or not _documents.get(key) is PackedByteArray:
			return false
		seen[key] = true
		if _raw_hashes.get(key) != _raw_hash(_documents.get(key)):
			return false
	return seen.size() == _documents.size()


func documents() -> Dictionary:
	return _documents.duplicate(true) if validate_integrity() else {}


static func _identity_component(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or str(value).is_empty() or str(value).length() > 32:
		return false
	for character: String in str(value):
		var code := character.unicode_at(0)
		var alphanumeric := (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122)
		if not alphanumeric and character not in ["_", "-"]:
			return false
	return not str(value).contains("/") and not str(value).contains("\\")


static func _exact_script(value: Variant, expected: GDScript) -> bool:
	return value != null and typeof(value) == TYPE_OBJECT and value.get_script() == expected


static func _raw_hash(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode().to_upper()


static func _error(code: String) -> Dictionary:
	return {"ok": false, "error_code": code, "source_documents": null}
