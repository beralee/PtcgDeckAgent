class_name TestV17BombCharizardStrategy
extends TestBase

const StrategyBombCharizard = preload("res://scripts/ai/DeckStrategy17BombCharizard.gd")


func _pokemon(
	name: String,
	energy_type: String = "C",
	hp: int = 100,
	stage: String = "Basic",
	mechanic: String = "",
	evolves_from: String = ""
) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = "Pokemon"
	cd.energy_type = energy_type
	cd.hp = hp
	cd.stage = stage
	cd.mechanic = mechanic
	cd.evolves_from = evolves_from
	return cd


func _trainer(name: String) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = "Trainer"
	return cd


func _slot(cd: CardData, owner_index: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(cd, owner_index))
	return slot


func _fill_prizes(player: PlayerState, count: int) -> void:
	player.prizes.clear()
	for i: int in count:
		player.prizes.append(CardInstance.create(_trainer("Prize %d" % i), player.player_index))


func _make_state() -> GameState:
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	player.active_pokemon = _slot(_pokemon("Pidgey", "C", 60), 0)
	opponent.active_pokemon = _slot(_pokemon("Miraidon ex", "L", 220, "Basic", "ex"), 1)
	_fill_prizes(player, 6)
	_fill_prizes(opponent, 6)
	state.players.append(player)
	state.players.append(opponent)
	return state


func test_v17_bomb_charizard_dusknoir_scores_130_counter_conversion() -> String:
	var strategy := StrategyBombCharizard.new()
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	var dusknoir := _slot(_pokemon("Dusknoir", "P", 160, "Stage 2", "", "Dusclops"), 0)
	player.bench.append(dusknoir)
	var bulky := _slot(_pokemon("Iron Hands ex", "L", 230, "Basic", "ex"), 1)
	var doomed := _slot(_pokemon("Raikou V", "L", 200, "Basic", "V"), 1)
	doomed.damage_counters = 80
	opponent.bench.append(bulky)
	opponent.bench.append(doomed)
	var context := {"game_state": state, "player_index": 0, "source_slot": dusknoir}

	var doomed_score: float = strategy.score_interaction_target(doomed, {"id": "self_ko_target"}, context)
	var bulky_score: float = strategy.score_interaction_target(bulky, {"id": "self_ko_target"}, context)
	var ability_score: float = strategy.score_action_absolute({"kind": "use_ability", "source_slot": dusknoir, "ability_index": 0}, state, 0)
	var picked: Array = strategy.pick_interaction_items([bulky, doomed], {"id": "self_ko_target", "max_select": 1}, context)
	var picked_name := ""
	if not picked.is_empty() and picked[0] is PokemonSlot:
		picked_name = (picked[0] as PokemonSlot).get_pokemon_name()

	return run_checks([
		assert_true(doomed_score >= 650.0, "Dusknoir should score 130-damage direct self-KO conversion highly (got %f)" % doomed_score),
		assert_true(doomed_score > bulky_score + 300.0, "Dusknoir should prefer clean two-prize conversion over bulky non-lethal target (doomed=%f bulky=%f)" % [doomed_score, bulky_score]),
		assert_true(ability_score >= 350.0, "Dusknoir ability should be enabled when 130 damage converts a two-prize target (got %f)" % ability_score),
		assert_true(picked_name == "Raikou V", "Dusknoir target picker should select the 130-damage knockout target (picked=%s)" % picked_name),
	])


func test_v17_bomb_charizard_dusclops_keeps_50_counter_conversion() -> String:
	var strategy := StrategyBombCharizard.new()
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	var dusclops := _slot(_pokemon("Dusclops", "P", 90, "Stage 1", "", "Duskull"), 0)
	player.bench.append(dusclops)
	var target := _slot(_pokemon("Raikou V", "L", 200, "Basic", "V"), 1)
	target.damage_counters = 80
	opponent.bench.append(target)
	var context := {"game_state": state, "player_index": 0, "source_slot": dusclops}

	var target_score: float = strategy.score_interaction_target(target, {"id": "self_ko_target"}, context)
	var ability_score: float = strategy.score_action_absolute({"kind": "use_ability", "source_slot": dusclops, "ability_index": 0}, state, 0)

	return run_checks([
		assert_true(target_score < 350.0, "Dusclops should not treat a 120-remaining target as a 50-damage conversion (got %f)" % target_score),
		assert_true(ability_score <= 0.0, "Dusclops ability should stay low without a 50-damage conversion (got %f)" % ability_score),
	])
