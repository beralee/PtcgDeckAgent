class_name V18CPGBenchmarkDeckSource
extends RefCounted

const SemanticCompilerScript = preload("res://scripts/ai/v18_cpg/semantics/V18CPGDeckSemanticCompiler.gd")


static func load_deck(card_database: Node, deck_id: int) -> DeckData:
	if card_database == null or deck_id <= 0:
		return null
	var ai_deck: DeckData = card_database.call("get_ai_deck", deck_id) as DeckData
	if ai_deck != null:
		return ai_deck
	return card_database.call("get_deck", deck_id) as DeckData


static func source_kind(card_database: Node, deck_id: int) -> String:
	if card_database == null or deck_id <= 0:
		return "missing"
	var supported: Array = card_database.call("get_supported_ai_deck_ids") as Array
	if supported.has(deck_id) and card_database.call("get_ai_deck", deck_id) != null:
		return "bundled_ai"
	return "player_deck_fallback" if card_database.call("get_deck", deck_id) != null else "missing"


static func content_fingerprint(deck: DeckData) -> String:
	return SemanticCompilerScript.deck_content_fingerprint(deck)
