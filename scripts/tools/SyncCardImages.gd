extends SceneTree

const CardImageCacheServiceScript := preload("res://scripts/card_images/CardImageCacheService.gd")

var _syncer = null
var _job_id := ""


func _initialize() -> void:
	print("Starting saved deck card image sync...")
	_syncer = CardImageCacheServiceScript.new()
	root.add_child(_syncer)
	_syncer.set_card_database(CardDatabase)
	_syncer.image_progress.connect(_on_progress)
	_syncer.job_completed.connect(_on_completed)
	call_deferred("_start")


func _start() -> void:
	var cards := _saved_deck_unique_cards()
	if cards.is_empty():
		print("No saved deck card images to sync.")
		quit(0)
		return
	_job_id = _syncer.ensure_cards(cards, {"priority": 2, "reason": "saved_decks_cli"})
	_finish_if_already_done()


func _saved_deck_unique_cards() -> Array[CardData]:
	var result: Array[CardData] = []
	var seen := {}
	for deck: DeckData in CardDatabase.get_all_decks():
		if deck == null:
			continue
		for key: Dictionary in deck.get_card_keys():
			var set_code := str(key.get("set_code", "")).strip_edges()
			var card_index := str(key.get("card_index", "")).strip_edges()
			var uid := "%s_%s" % [set_code, card_index]
			if uid == "_" or seen.has(uid):
				continue
			seen[uid] = true
			var card := CardDatabase.get_card(set_code, card_index)
			if card != null:
				result.append(card)
	return result


func _finish_if_already_done() -> void:
	if _job_id == "":
		return
	var stats: Dictionary = _syncer.get_job_stats(_job_id)
	if int(stats.get("completed", 0)) >= int(stats.get("total", 0)):
		_on_completed(_job_id, stats, _syncer.get_job_errors(_job_id))


func _on_progress(job_id: String, current: int, total: int) -> void:
	if job_id != _job_id:
		return
	print("[%d/%d] saved deck card images" % [current, total])


func _on_completed(job_id: String, stats: Dictionary, errors: PackedStringArray) -> void:
	if job_id != _job_id:
		return
	print(
		"Image sync finished. total=%d downloaded=%d skipped=%d failed=%d" % [
			int(stats.get("total", 0)),
			int(stats.get("downloaded", 0)),
			int(stats.get("skipped", 0)),
			int(stats.get("failed", 0)),
		]
	)
	for err: String in errors:
		print("WARN: %s" % err)
	quit(0 if errors.is_empty() else 1)
