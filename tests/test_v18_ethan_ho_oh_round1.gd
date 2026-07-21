class_name TestV18EthanHoOhRound1
extends TestBase


const STRATEGY_SCRIPT = preload("res://scripts/ai/DeckStrategyV18EthanHoOh.gd")


func test_legacy_suppresses_luminous_fire_and_does_not_make_ho_oh_ready() -> String:
	var strategy: RefCounted = STRATEGY_SCRIPT.new()
	var player := PlayerState.new()
	var ho_oh := _ho_oh_slot()
	var legacy := _real_energy("CSV8C_207")
	var luminous := _real_energy("CSV1C_127")
	ho_oh.attached_energy.assign([
		_basic_fire(),
		_basic_fire(),
		legacy,
		luminous,
	])
	player.active_pokemon = ho_oh
	return run_checks([
		assert_false(
			bool(strategy.call("_energy_pays_fire", luminous, ho_oh)),
			"Luminous Energy must stop paying Fire when Legacy Energy is attached"
		),
		assert_eq(
			int(strategy.call("_attached_fire", ho_oh)),
			3,
			"Two basic Fire plus Legacy and suppressed Luminous must count as only three Fire"
		),
		assert_null(
			strategy.call("_best_ho_oh", player, true),
			"Suppressed Luminous must not make Ho-Oh look ready for its four-Fire attack"
		),
	])


func test_real_missing_fire_prefers_legal_basic_fire_over_suppressed_luminous() -> String:
	var strategy: RefCounted = STRATEGY_SCRIPT.new()
	var player := PlayerState.new()
	var ho_oh := _ho_oh_slot()
	var legacy := _real_energy("CSV8C_207")
	var luminous := _real_energy("CSV1C_127")
	var fire := _basic_fire()
	ho_oh.attached_energy.assign([_basic_fire(), _basic_fire(), legacy])
	player.active_pokemon = ho_oh
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	var state := GameState.new()
	state.players = [player, opponent]
	var luminous_score: float = strategy.call(
		"score_action_absolute",
		{"kind": "attach_energy", "card": luminous, "target_slot": ho_oh},
		state,
		0
	)
	var fire_score: float = strategy.call(
		"score_action_absolute",
		{"kind": "attach_energy", "card": fire, "target_slot": ho_oh},
		state,
		0
	)
	return run_checks([
		assert_true(
			bool(strategy.call("_energy_pays_fire", fire, ho_oh)),
			"Basic Fire must remain a legal payment for the real missing Fire"
		),
		assert_true(
			fire_score >= luminous_score + 1800.0,
			"A legal basic Fire must outrank suppressed Luminous when Ho-Oh is one Fire short (fire=%f luminous=%f)" % [fire_score, luminous_score]
		),
	])


func _ho_oh_slot() -> PokemonSlot:
	var card := CardData.new()
	card.name_en = "Ethan's Ho-Oh ex"
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.energy_type = "R"
	card.hp = 230
	card.attacks = [{"name": "Shining Feather", "cost": "RRRR", "damage": "160"}]
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, 0))
	return slot


func _basic_fire() -> CardInstance:
	var card := CardData.new()
	card.name_en = "Fire Energy"
	card.card_type = "Basic Energy"
	card.energy_type = "R"
	card.energy_provides = "R"
	return CardInstance.create(card, 0)


func _real_energy(ref: String) -> CardInstance:
	var path := "res://data/bundled_user/cards/%s.json" % ref
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return CardInstance.create(CardData.from_dict(parsed), 0)
