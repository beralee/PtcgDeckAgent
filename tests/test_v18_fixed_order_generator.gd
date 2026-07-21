class_name TestV18FixedOrderGenerator
extends TestBase


const GENERATOR_SCRIPT = preload("res://scripts/tools/generate_v18_ai_fixed_orders.gd")


func test_generator_appends_the_remaining_copy_pool_after_the_controlled_prefix() -> String:
	var generator: SceneTree = GENERATOR_SCRIPT.new()
	var basic := _card("Route Basic", "Basic")
	var filler := _card("Route Filler", "")
	var controlled: Array[Dictionary] = []
	for index: int in 19:
		controlled.append(_entry("AAA", "001" if index % 2 == 0 else "002", basic if index == 0 else filler))
	var remaining: Array[Dictionary] = []
	for _index: int in 20:
		remaining.append(_entry("AAA", "001", filler))
	for _index: int in 21:
		remaining.append(_entry("AAA", "002", filler))

	var completed_raw: Variant = generator.call("_complete_order", controlled, remaining)
	var checks: Array[String] = [
		assert_true(completed_raw is Array, "The generator should expose one complete-order step"),
	]
	if not completed_raw is Array:
		generator.free()
		return run_checks(checks)
	var completed: Array = completed_raw
	var deck := DeckData.new()
	deck.cards.assign([
		{"set_code": "AAA", "card_index": "001", "count": 30},
		{"set_code": "AAA", "card_index": "002", "count": 30},
	])
	var tampered: Array[Dictionary] = []
	tampered.assign(completed)
	tampered[59] = completed[0]
	checks.append_array([
		assert_eq(completed.size(), 60, "The controlled 19-card route must be followed by all 41 remaining copies"),
		assert_eq(completed.slice(0, 19), controlled, "Completion must preserve the exact opening, prize, and bridge prefix"),
		assert_eq(str(generator.call("_validate_order", deck, completed)), "", "A complete legal order should pass production validation"),
		assert_true(str(generator.call("_validate_order", deck, controlled)) != "", "A 19-card prefix must never pass production validation"),
		assert_true(str(generator.call("_validate_order", deck, tampered)) != "", "A 60-card order with the wrong copy multiplicity must fail validation"),
	])
	generator.free()
	return run_checks(checks)


func _entry(set_code: String, card_index: String, card: CardData) -> Dictionary:
	return {
		"set_code": set_code,
		"card_index": card_index,
		"uid": "%s_%s" % [set_code, card_index],
		"card": card,
	}


func _card(card_name: String, stage: String) -> CardData:
	var card := CardData.new()
	card.name_en = card_name
	card.card_type = "Pokemon" if stage != "" else "Item"
	card.stage = stage
	return card
