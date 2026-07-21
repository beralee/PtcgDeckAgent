class_name TestV18YanmegaRound1
extends TestBase


const STRATEGY_SCRIPT = preload("res://scripts/ai/DeckStrategyV18Yanmega.gd")


func test_four_opposing_ex_converts_one_energy_dudunsparce_into_the_handoff() -> String:
	var strategy: RefCounted = STRATEGY_SCRIPT.new()
	var state := _state_with_opposing_ex(4, 270)
	var dudunsparce := _real_slot("CSV10C_179", 0)
	var yanmega := _real_slot("CSV10C_003", 0)
	state.players[0].bench.assign([dudunsparce, yanmega])
	var grass := _basic_grass()
	var dudunsparce_attach: float = strategy.call(
		"score_action_absolute",
		{"kind": "attach_energy", "card": grass, "target_slot": dudunsparce},
		state,
		0
	)
	var yanmega_attach: float = strategy.call(
		"score_action_absolute",
		{"kind": "attach_energy", "card": grass, "target_slot": yanmega},
		state,
		0
	)
	dudunsparce.attached_energy.append(grass)
	for _index: int in 3:
		yanmega.attached_energy.append(_basic_grass())
	strategy.call("build_turn_plan", state, 0)
	var prediction: Dictionary = strategy.call("predict_attacker_damage", dudunsparce)
	var dudunsparce_handoff: float = strategy.call(
		"score_handoff_target",
		dudunsparce,
		{"id": "self_switch_target"},
		{"game_state": state, "player_index": 0}
	)
	var yanmega_handoff: float = strategy.call(
		"score_handoff_target",
		yanmega,
		{"id": "self_switch_target"},
		{"game_state": state, "player_index": 0}
	)
	return run_checks([
		assert_true(
			dudunsparce_attach >= yanmega_attach + 800.0,
			"Against four Pokemon ex, the one-Energy Dudunsparce route must outrank another Yanmega attachment (dudunsparce=%f yanmega=%f)" % [dudunsparce_attach, yanmega_attach]
		),
		assert_true(bool(prediction.get("can_attack", false)), "One attached Energy must ready Adversity Tail"),
		assert_eq(int(prediction.get("damage", 0)), 240, "Adversity Tail must predict 60 damage for each of four opposing Pokemon ex"),
		assert_true(
			dudunsparce_handoff >= yanmega_handoff + 1000.0,
			"The 240-damage Dudunsparce conversion must outrank a 210-damage Yanmega handoff (dudunsparce=%f yanmega=%f)" % [dudunsparce_handoff, yanmega_handoff]
		),
	])


func test_ready_crustle_walls_active_ex_before_non_ko_yanmega() -> String:
	var strategy: RefCounted = STRATEGY_SCRIPT.new()
	var state := _state_with_opposing_ex(1, 230)
	var crustle := _real_slot("CSV10C_010", 0)
	var yanmega := _real_slot("CSV10C_003", 0)
	for _index: int in 3:
		crustle.attached_energy.append(_basic_grass())
		yanmega.attached_energy.append(_basic_grass())
	state.players[0].bench.assign([crustle, yanmega])
	strategy.call("build_turn_plan", state, 0)
	var crustle_prediction: Dictionary = strategy.call("predict_attacker_damage", crustle)
	var yanmega_prediction: Dictionary = strategy.call("predict_attacker_damage", yanmega)
	var crustle_handoff: float = strategy.call(
		"score_handoff_target",
		crustle,
		{"id": "self_switch_target"},
		{"game_state": state, "player_index": 0}
	)
	var yanmega_handoff: float = strategy.call(
		"score_handoff_target",
		yanmega,
		{"id": "self_switch_target"},
		{"game_state": state, "player_index": 0}
	)
	return run_checks([
		assert_true(bool(crustle_prediction.get("can_attack", false)), "Three Energy must ready Crustle's printed GCC attack"),
		assert_eq(int(crustle_prediction.get("damage", 0)), 120, "Crustle must retain its printed 120-damage prediction"),
		assert_eq(int(yanmega_prediction.get("damage", 0)), 210, "Yanmega must retain its printed 210-damage prediction"),
		assert_true(int(yanmega_prediction.get("damage", 0)) < 230, "Yanmega must be outside the knockout window in this regression state"),
		assert_true(
			crustle_handoff >= yanmega_handoff + 1000.0,
			"Ready Crustle's immunity wall must outrank Yanmega when the opposing Active ex survives 210 (crustle=%f yanmega=%f)" % [crustle_handoff, yanmega_handoff]
		),
	])


func _state_with_opposing_ex(count: int, active_hp: int) -> GameState:
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	player.active_pokemon = _plain_slot("Pivot", 0, 80, "")
	var opponent := PlayerState.new()
	opponent.player_index = 1
	opponent.active_pokemon = _plain_slot("Opponent Active ex", 1, active_hp, "ex")
	for index: int in maxi(0, count - 1):
		opponent.bench.append(_plain_slot("Opponent Bench ex %d" % index, 1, 200, "ex"))
	state.players = [player, opponent]
	return state


func _real_slot(ref: String, owner_index: int) -> PokemonSlot:
	var path := "res://data/bundled_user/cards/%s.json" % ref
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(CardData.from_dict(parsed), owner_index))
	return slot


func _plain_slot(name: String, owner_index: int, hp: int, mechanic: String) -> PokemonSlot:
	var card := CardData.new()
	card.name_en = name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = hp
	card.mechanic = mechanic
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner_index))
	return slot


func _basic_grass() -> CardInstance:
	var card := CardData.new()
	card.name_en = "Grass Energy"
	card.card_type = "Basic Energy"
	card.energy_type = "G"
	card.energy_provides = "G"
	return CardInstance.create(card, 0)
