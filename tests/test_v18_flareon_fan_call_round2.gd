class_name TestV18FlareonFanCallRound2
extends TestBase


const STRATEGY_SCRIPT = preload("res://scripts/ai/DeckStrategyV18TeraNoctowl.gd")
const DECK_PATH := "res://data/bundled_user/decks/800017643.json"
const FAN_CALL_STEP := {"id": "csv9c_fan_call_cards", "max_select": 3}


func test_empty_board_fan_call_builds_three_distinct_route_identities() -> String:
	var strategy := _strategy()
	var hoothoot_a := _card("CSV9C", "154")
	var hoothoot_b := _card("CSV9C", "154")
	var noctowl_a := _card("CSV9C", "155")
	var noctowl_b := _card("CSV9C", "155")
	var eevee := _card("CSV9C", "153")
	if strategy == null or hoothoot_a == null or hoothoot_b == null or noctowl_a == null \
			or noctowl_b == null or eevee == null:
		return assert_true(false, "Fan Call route fixtures should load")
	var state := _state()
	var picked: Array = strategy.call("pick_interaction_items", [
		hoothoot_a, hoothoot_b, noctowl_a, noctowl_b, eevee,
	], FAN_CALL_STEP, {"game_state": state, "player_index": 0})
	return run_checks([
		assert_eq(picked.size(), 3, "Fan Call should take three targets when all route identities are available"),
		assert_eq(_count_uid(picked, "CSV9C_153"), 1, "Fan Call should take one Eevee on an empty board"),
		assert_eq(_count_uid(picked, "CSV9C_154"), 1, "Fan Call should avoid taking a duplicate Hoothoot before the route is complete"),
		assert_eq(_count_uid(picked, "CSV9C_155"), 1, "Fan Call should take one Noctowl on an empty board"),
	])


func test_two_hoothoot_strong_opening_keeps_two_noctowl_and_backup_eevee() -> String:
	var strategy := _strategy()
	var hoothoot := _card("CSV9C", "154")
	var noctowl_a := _card("CSV9C", "155")
	var noctowl_b := _card("CSV9C", "155")
	var eevee := _card("CSV9C", "153")
	var field_hoothoot_a := _slot("CSV9C", "154")
	var field_hoothoot_b := _slot("CSV9.5C", "141")
	if strategy == null or hoothoot == null or noctowl_a == null or noctowl_b == null \
			or eevee == null or field_hoothoot_a == null or field_hoothoot_b == null:
		return assert_true(false, "Strong Fan Call fixtures should load")
	var state := _state()
	state.players[0].active_pokemon = field_hoothoot_a
	state.players[0].bench = [field_hoothoot_b]
	var picked: Array = strategy.call("pick_interaction_items", [
		hoothoot, noctowl_a, noctowl_b, eevee,
	], FAN_CALL_STEP, {"game_state": state, "player_index": 0})
	return run_checks([
		assert_eq(picked.size(), 3, "The two-Hoothoot opening should keep a full Fan Call selection"),
		assert_eq(_count_uid(picked, "CSV9C_155"), 2, "Two established Hoothoot should reserve two Fan Call slots for Noctowl"),
		assert_eq(_count_uid(picked, "CSV9C_153"), 1, "The remaining Fan Call slot should preserve a backup Eevee"),
		assert_eq(_count_uid(picked, "CSV9C_154"), 0, "The two-Hoothoot opening should not search an unnecessary third Hoothoot"),
	])


func test_missing_route_target_uses_distinct_fallback_before_duplicates() -> String:
	var strategy := _strategy()
	var hoothoot_a := _card("CSV9C", "154")
	var hoothoot_b := _card("CSV9C", "154")
	var eevee := _card("CSV9C", "153")
	var fan_rotom := _card("CSV9C", "161")
	if strategy == null or hoothoot_a == null or hoothoot_b == null or eevee == null or fan_rotom == null:
		return assert_true(false, "Fan Call fallback fixtures should load")
	var state := _state()
	var context := {"game_state": state, "player_index": 0}
	var fallback_picks: Array = strategy.call("pick_interaction_items", [
		hoothoot_a, hoothoot_b, eevee, fan_rotom,
	], FAN_CALL_STEP, context)
	var short_picks: Array = strategy.call("pick_interaction_items", [
		hoothoot_a, hoothoot_b,
	], FAN_CALL_STEP, context)
	return run_checks([
		assert_eq(fallback_picks.size(), 3, "Fan Call should fill the missing Noctowl slot from legal fallback targets"),
		assert_true(eevee in fallback_picks, "The partial route should retain Eevee"),
		assert_true(fan_rotom in fallback_picks, "A distinct Fan Rotom fallback should be used before duplicate Hoothoot"),
		assert_eq(_count_uid(fallback_picks, "CSV9C_154"), 1, "Fan Call should avoid an unnecessary duplicate identity"),
		assert_eq(short_picks.size(), 2, "Fan Call should return all available targets when fewer than three exist"),
		assert_true(hoothoot_a in short_picks and hoothoot_b in short_picks, "Duplicate identity fallback is valid when no distinct target remains"),
	])


func test_fan_call_identity_accepts_english_chinese_and_known_uid_cards() -> String:
	var strategy := _strategy()
	var eevee_en := _synthetic_card("", "Eevee", "", "TEST", "EN")
	var hoothoot_zh := _synthetic_card("咕咕", "", "", "TEST", "ZH")
	var noctowl_uid_a := _synthetic_card("UID-only A", "", "", "CSV9C", "155")
	var noctowl_uid_b := _synthetic_card("UID-only B", "", "", "CSV9C", "155")
	if strategy == null:
		return assert_true(false, "Flareon strategy should load for mixed-identity Fan Call")
	var state := _state()
	var picked: Array = strategy.call("pick_interaction_items", [
		noctowl_uid_a, noctowl_uid_b, eevee_en, hoothoot_zh,
	], FAN_CALL_STEP, {"game_state": state, "player_index": 0})
	return run_checks([
		assert_eq(picked.size(), 3, "Mixed-language and UID identities should still complete the Fan Call route"),
		assert_true(eevee_en in picked, "English Eevee identity should be recognized without a production UID"),
		assert_true(hoothoot_zh in picked, "Chinese Hoothoot identity should be recognized without a production UID"),
		assert_eq(_count_uid(picked, "CSV9C_155"), 1, "Known Noctowl UID should be recognized without relying on its display name"),
	])


func _strategy() -> RefCounted:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DECK_PATH))
	if not parsed is Dictionary:
		return null
	var strategy: RefCounted = STRATEGY_SCRIPT.new()
	strategy.call("configure_from_deck", DeckData.from_dict(parsed))
	return strategy


func _state() -> GameState:
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	state.players = [player, opponent]
	state.current_player_index = 0
	state.turn_number = 1
	state.phase = GameState.GamePhase.MAIN
	return state


func _card(set_code: String, card_index: String) -> CardInstance:
	var data := CardDatabase.get_card(set_code, card_index)
	return CardInstance.create(data, 0) if data != null else null


func _slot(set_code: String, card_index: String) -> PokemonSlot:
	var card := _card(set_code, card_index)
	if card == null:
		return null
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(card)
	return slot


func _synthetic_card(
	name: String,
	name_en: String,
	name_zh: String,
	set_code: String,
	card_index: String
) -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.name_en = name_en
	data.name_zh = name_zh
	data.set_code = set_code
	data.card_index = card_index
	data.card_type = "Pokemon"
	data.stage = "Basic"
	data.energy_type = "C"
	data.hp = 70
	return CardInstance.create(data, 0)


func _count_uid(items: Array, uid: String) -> int:
	var count := 0
	for item: Variant in items:
		if item is CardInstance and (item as CardInstance).card_data != null \
				and str((item as CardInstance).card_data.get_uid()).to_lower() == uid.to_lower():
			count += 1
	return count
