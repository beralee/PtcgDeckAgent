extends RefCounted
## Small, synchronous recovery journal for user deck edits. Godot's whole userfs
## may still be syncing the bundled catalog when a player imports their first deck.
const PREFIX := "ptcgdap.deck.v1."

static func available() -> bool:
	return OS.has_feature("web")

static func store(deck: Dictionary, cards: Dictionary = {}) -> bool:
	return _write(int(deck.get("id", 0)), {"deck": deck, "cards": cards})

static func erase(deck_id: int) -> bool:
	return _write(deck_id, {"deleted": true})

static func _write(deck_id: int, record: Dictionary) -> bool:
	var key := JSON.stringify(PREFIX + str(deck_id))
	var value := JSON.stringify(JSON.stringify(record))
	return bool(JavaScriptBridge.eval("""
(function() {
  const result = window.__ptcgImportStorage = {done: true, ok: false, error: ''};
  try { localStorage.setItem(%s, %s); result.ok = true; }
  catch (_) { result.error = 'Browser storage unavailable'; }
  return result.ok;
})();
""" % [key, value], true))

static func valid_card_filename(filename: String) -> bool:
	var pattern := RegEx.new()
	pattern.compile("^[A-Za-z0-9_-]+\\.json$")
	return pattern.search(filename) != null

static func restore() -> void:
	var raw: Variant = JavaScriptBridge.eval("""
(function() {
  const records = {};
  try {
    for (let i = 0; i < localStorage.length; i++) {
      const key = localStorage.key(i);
      if (!key.startsWith('ptcgdap.deck.v1.')) continue;
      try { records[key.slice('ptcgdap.deck.v1.'.length)] = JSON.parse(localStorage.getItem(key)); } catch (_) {}
    }
  } catch (_) {}
  return JSON.stringify(records);
})();
""", true)
	var records: Variant = JSON.parse_string(str(raw))
	if not records is Dictionary:
		return
	for id_text: String in records:
		if not id_text.is_valid_int() or not records[id_text] is Dictionary:
			continue
		var record: Dictionary = records[id_text]
		var path := "user://decks/%d.json" % int(id_text)
		if record.get("deleted", false) == true:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
			continue
		var deck: Variant = record.get("deck")
		if not deck is Dictionary or int(deck.get("id", 0)) != int(id_text) or not deck.get("cards") is Array:
			continue
		var existing: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else {}
		if existing is Dictionary and float(existing.get("updated_at", 0)) > float(deck.get("updated_at", 0)):
			continue
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(deck))
			file.close()
		var cards: Variant = record.get("cards", {})
		if not cards is Dictionary:
			continue
		for filename: String in cards:
			if not valid_card_filename(filename) or not cards[filename] is Dictionary:
				continue
			var card_path := "user://cards/" + filename
			if FileAccess.file_exists(card_path):
				continue
			file = FileAccess.open(card_path, FileAccess.WRITE)
			if file != null:
				file.store_string(JSON.stringify(cards[filename]))
				file.close()
