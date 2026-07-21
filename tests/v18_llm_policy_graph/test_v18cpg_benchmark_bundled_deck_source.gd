extends SceneTree

const BenchmarkDeckSourceScript = preload("res://scripts/ai/v18_cpg/benchmark/V18CPGBenchmarkDeckSource.gd")
const CompilerScript = preload("res://scripts/ai/v18_cpg/semantics/V18CPGDeckSemanticCompiler.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	var card_database := root.get_node_or_null("CardDatabase")
	var deck: DeckData = BenchmarkDeckSourceScript.load_deck(card_database, 800018105)
	_check(deck != null, "built-in benchmark deck must load")
	_check(BenchmarkDeckSourceScript.source_kind(card_database, 800018105) == "bundled_ai", "supported V18 deck must use bundled AI source")
	_check(_entry_count(deck, "CSV2C", "054") == 2, "benchmark must use the bundled regulation-G Kirlia")
	_check(_entry_count(deck, "CS6.5C", "030") == 0, "benchmark must not inherit the stale player-deck Kirlia")
	var fingerprint := CompilerScript.deck_content_fingerprint(deck)
	_check(fingerprint != "", "bundled benchmark deck fingerprint must be stable and non-empty")
	if _failures.is_empty():
		print("V18CPG bundled benchmark deck source: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _entry_count(deck: DeckData, set_code: String, card_index: String) -> int:
	if deck == null:
		return 0
	for entry: Dictionary in deck.cards:
		if str(entry.get("set_code", "")) == set_code and str(entry.get("card_index", "")) == card_index:
			return int(entry.get("count", 0))
	return 0


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
