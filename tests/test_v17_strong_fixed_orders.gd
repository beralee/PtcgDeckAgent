class_name TestV17StrongFixedOrders
extends TestBase

const AIFixedDeckOrderRegistryScript = preload("res://scripts/ai/AIFixedDeckOrderRegistry.gd")
const CardDatabaseScript = preload("res://scripts/autoload/CardDatabase.gd")

const V17_STRONG_DECK_IDS := [
	1700002,
	1700003,
	1700004,
	1700005,
	1700007,
	1700008,
	1700011,
]

const EXPECTED_FIXED_ORDER_SIZES := {
	1700011: 19,
}


func test_v17_strong_fixed_order_files_are_registered_and_usable() -> String:
	var registry := AIFixedDeckOrderRegistryScript.new()
	var card_database := _card_database()
	var checks: Array[String] = []
	for deck_id: int in V17_STRONG_DECK_IDS:
		var expected_path := "res://data/bundled_user/ai_fixed_deck_orders/%d.json" % deck_id
		var actual_path := registry.get_fixed_order_path(deck_id)
		checks.append(assert_eq(
			actual_path,
			expected_path,
			"V17 strong deck %d should bind a fixed order file" % deck_id
		))
		var fixed_order: Array[Dictionary] = registry.load_fixed_order(deck_id)
		var expected_size: int = int(EXPECTED_FIXED_ORDER_SIZES.get(deck_id, 15))
		checks.append(assert_eq(
			fixed_order.size(),
			expected_size,
			"V17 strong deck %d should fix exactly the expected opening cards" % deck_id
		))
		if deck_id == 1700011 and fixed_order.size() >= 19:
			checks.append_array(_regidrago_bridge_checks(fixed_order))
		if deck_id == 1700003 and fixed_order.size() >= 7:
			checks.append_array(_water_turtle_bridge_checks(fixed_order))
		var deck_counts := _bundled_deck_card_counts(deck_id)
		checks.append(assert_false(
			deck_counts.is_empty(),
			"V17 strong deck %d bundled deck list should be readable for fixed-order validation" % deck_id
		))
		var used_counts := {}
		for entry: Dictionary in fixed_order:
			var set_code := str(entry.get("set_code", ""))
			var card_index := str(entry.get("card_index", ""))
			var key := _card_key(set_code, card_index)
			checks.append(assert_true(
				card_database.get_card(set_code, card_index) != null,
				"V17 strong deck %d fixed card %s should exist in CardDatabase" % [deck_id, key]
			))
			used_counts[key] = int(used_counts.get(key, 0)) + 1
			checks.append(assert_true(
				deck_counts.has(key),
				"V17 strong deck %d fixed card %s should exist in its bundled deck" % [deck_id, key]
			))
			checks.append(assert_true(
				int(used_counts.get(key, 0)) <= int(deck_counts.get(key, 0)),
				"V17 strong deck %d fixed card %s should not exceed deck copy count" % [deck_id, key]
			))
	return run_checks(checks)


func _regidrago_bridge_checks(fixed_order: Array[Dictionary]) -> Array[String]:
	var checks: Array[String] = [
		assert_eq(_entry_key(fixed_order[2]), "CSV1C_112", "Regidrago strong hand should open Ultra Ball for VSTAR access"),
		assert_eq(_entry_key(fixed_order[3]), "CSV8C_159", "Regidrago strong hand should open Dragapult ex as Apex Dragon discard fuel"),
		assert_eq(_entry_key(fixed_order[5]), "CSVE1C_GRA", "Regidrago strong hand should open Grass for Teal Mask Ogerpon's first charge"),
		assert_eq(_entry_key(fixed_order[6]), "CSVH1aC_008", "Regidrago strong hand should keep Energy Switch in hand so opponent mulligan draws cannot prize it"),
		assert_eq(_entry_key(fixed_order[12]), "CSVH1aC_023", "Regidrago card 13 should move Boss's Orders into the controlled prize block instead of the escape slot"),
		assert_eq(_entry_key(fixed_order[13]), "CSVE1C_GRA", "Regidrago card 14 should be the no-mulligan first-turn draw Grass kept for T2 manual attach"),
		assert_eq(_entry_key(fixed_order[14]), "CS5.5C_053", "Regidrago card 15 should be the 0/1-mulligan Dragon discard fuel drawn before Ultra Ball"),
		assert_eq(_entry_key(fixed_order[15]), "CSVE1C_GRA", "Regidrago card 16 should be the one-mulligan Ogerpon draw Grass kept for T2 manual attach"),
		assert_eq(_entry_key(fixed_order[16]), "CS6.5C_055", "Regidrago card 17 should keep Regidrago VSTAR searchable and unprized"),
		assert_eq(_entry_key(fixed_order[17]), "CSV1C_113", "Regidrago card 18 should keep the real Switch unprized for anti-Boss Star Legacy recovery"),
		assert_eq(_entry_key(fixed_order[18]), "CS5aC_113", "Regidrago card 19 should use Canceling Cologne as final non-route padding"),
	]
	for opponent_mulligan_draws: int in 3:
		checks.append_array(_regidrago_prize_window_checks(fixed_order, opponent_mulligan_draws))
	return checks


func _regidrago_prize_window_checks(fixed_order: Array[Dictionary], opponent_mulligan_draws: int) -> Array[String]:
	var hand: Array[String] = []
	var cursor := 0
	for i: int in 7:
		hand.append(_entry_key(fixed_order[cursor]))
		cursor += 1
	for i: int in opponent_mulligan_draws:
		hand.append(_entry_key(fixed_order[cursor]))
		cursor += 1
	var prizes: Array[String] = []
	for i: int in 6:
		prizes.append(_entry_key(fixed_order[cursor]))
		cursor += 1
	var first_turn_draw := _entry_key(fixed_order[cursor]) if cursor < fixed_order.size() else ""
	var ogerpon_draw := _entry_key(fixed_order[cursor + 1]) if cursor + 1 < fixed_order.size() else ""
	var checks: Array[String] = [
		assert_true("CSVH1aC_008" in hand, "Regidrago Energy Switch must stay in hand with %d opponent mulligan draw(s)" % opponent_mulligan_draws),
		assert_false("CSVH1aC_008" in prizes, "Regidrago Energy Switch must not be in the prize block with %d opponent mulligan draw(s)" % opponent_mulligan_draws),
	]
	if opponent_mulligan_draws <= 1:
		checks.append(assert_true(
			first_turn_draw == "CSVE1C_GRA" or ogerpon_draw == "CSVE1C_GRA",
			"Regidrago should draw a spare Grass before Ultra Ball with %d opponent mulligan draw(s)" % opponent_mulligan_draws
		))
		checks.append(assert_true(
			first_turn_draw == "CS5.5C_053" or ogerpon_draw == "CS5.5C_053",
			"Regidrago should draw Hisuian Goodra VSTAR as second Ultra Ball discard fuel with %d opponent mulligan draw(s)" % opponent_mulligan_draws
		))
	return checks


func _water_turtle_bridge_checks(fixed_order: Array[Dictionary]) -> Array[String]:
	return [
		assert_eq(_entry_key(fixed_order[0]), "CSV9C_175", "Water Turtle strong hand should open Terapagos ex"),
		assert_eq(_entry_key(fixed_order[1]), "CSV9C_154", "Water Turtle strong hand should open Hoothoot"),
		assert_eq(_entry_key(fixed_order[2]), "CSV9C_161", "Water Turtle strong hand should open Fan Rotom"),
		assert_eq(_entry_key(fixed_order[3]), "CS5DC_138", "Water Turtle card 4 should be Irida instead of Bidoof"),
		assert_eq(_entry_key(fixed_order[4]), "CSV9C_207", "Water Turtle strong hand should keep Area Zero available"),
		assert_eq(_entry_key(fixed_order[5]), "CSVE1C_WAT", "Water Turtle strong hand should include the manual Water attach"),
		assert_eq(_entry_key(fixed_order[6]), "CSV9C_155", "Water Turtle strong hand should keep Noctowl available for T2"),
	]


func _card_database() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		var autoload: Node = tree.root.get_node_or_null("CardDatabase")
		if autoload != null:
			return autoload
	var fallback: Node = CardDatabaseScript.new()
	fallback._ready()
	return fallback


func _bundled_deck_card_counts(deck_id: int) -> Dictionary:
	var path := "res://data/bundled_user/decks/%d.json" % deck_id
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var counts := {}
	var current := {}
	for raw_line: String in text.split("\n"):
		var line := raw_line.strip_edges()
		if line.begins_with("\"card_index\""):
			current["card_index"] = _quoted_json_value(line)
		elif line.begins_with("\"count\""):
			current["count"] = _integer_json_value(line)
		elif line.begins_with("\"set_code\""):
			current["set_code"] = _quoted_json_value(line)
			var set_code := str(current.get("set_code", ""))
			var card_index := str(current.get("card_index", ""))
			var count := int(current.get("count", 0))
			if set_code != "" and card_index != "":
				var key := _card_key(set_code, card_index)
				counts[key] = int(counts.get(key, 0)) + count
			current.clear()
	return counts


func _quoted_json_value(line: String) -> String:
	var colon := line.find(":")
	if colon < 0:
		return ""
	var first_quote := line.find("\"", colon)
	if first_quote < 0:
		return ""
	var second_quote := line.find("\"", first_quote + 1)
	if second_quote < 0:
		return ""
	return line.substr(first_quote + 1, second_quote - first_quote - 1)


func _integer_json_value(line: String) -> int:
	var colon := line.find(":")
	if colon < 0:
		return 0
	var value := line.substr(colon + 1).strip_edges().trim_suffix(",")
	return int(value)


func _card_key(set_code: String, card_index: String) -> String:
	return "%s_%s" % [set_code, card_index]


func _entry_key(entry: Dictionary) -> String:
	return _card_key(str(entry.get("set_code", "")), str(entry.get("card_index", "")))
