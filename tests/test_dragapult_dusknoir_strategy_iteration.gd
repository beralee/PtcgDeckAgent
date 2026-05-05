class_name TestDragapultDusknoirStrategyIteration
extends TestBase

const STRATEGY_PATH := "res://scripts/ai/DeckStrategyDragapultDusknoir.gd"


func test_dusclops_self_ko_stays_low_without_lethal_conversion() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyDragapultDusknoir.gd should load"
	var gs := _make_game_state(8)
	var player: PlayerState = gs.players[0]
	var opponent: PlayerState = gs.players[1]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Dreepy", "Basic", "N", 70), 0)
	_fill_prizes(player, 6)
	player.bench.clear()
	var dusclops := _make_slot(_make_pokemon_cd("Dusclops", "Stage 1", "P", 90, "Duskull", "", [{"name": "Cursed Blast"}]), 0)
	player.bench.append(dusclops)
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	opponent.active_pokemon.damage_counters = 50
	var score: float = strategy.score_action_absolute({"kind": "use_ability", "source_slot": dusclops, "ability_index": 0}, gs, 0)
	return _assert_true(score <= 0.0,
		"Dusclops should not self-KO into a 170-remaining two-prize target without a lethal conversion (got %f)" % score)


func test_self_ko_target_selection_prefers_clean_knockout() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyDragapultDusknoir.gd should load"
	var gs := _make_game_state(8)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Dreepy", "Basic", "N", 70), 0)
	_fill_prizes(player, 6)
	player.bench.clear()
	var dusclops := _make_slot(_make_pokemon_cd("Dusclops", "Stage 1", "P", 90, "Duskull", "", [{"name": "Cursed Blast"}]), 0)
	player.bench.append(dusclops)
	var bulky := _make_slot(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230, "", "ex"), 1)
	var doomed := _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200, "", "V"), 1)
	doomed.damage_counters = 150
	var context := {"game_state": gs, "player_index": 0, "source_slot": dusclops}
	var doomed_score: float = strategy.score_interaction_target(doomed, {"id": "self_ko_target"}, context)
	var bulky_score: float = strategy.score_interaction_target(bulky, {"id": "self_ko_target"}, context)
	var picked_name := ""
	if strategy.has_method("pick_interaction_items"):
		var picked: Variant = strategy.call("pick_interaction_items", [bulky, doomed], {"id": "self_ko_target", "max_select": 1}, context)
		if picked is Array and not (picked as Array).is_empty() and (picked as Array)[0] is PokemonSlot:
			picked_name = ((picked as Array)[0] as PokemonSlot).get_pokemon_name()
	return _run_checks([
		_assert_true(doomed_score >= 500.0,
			"Self-KO target scoring should strongly prefer a direct knockout target (got %f)" % doomed_score),
		_assert_true(doomed_score > bulky_score + 300.0,
			"Self-KO target scoring should not prefer bulky rule-box setup over a clean prize (doomed=%f bulky=%f)" % [doomed_score, bulky_score]),
		_assert_eq(picked_name, "Raikou V",
			"Headless self-KO target planning should pick the clean knockout target instead of the first legal target"),
	])


func test_dusknoir_self_ko_stays_low_on_even_one_prize_pickoff() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyDragapultDusknoir.gd should load"
	var gs := _make_game_state(8)
	var player: PlayerState = gs.players[0]
	_fill_prizes(player, 6)
	player.active_pokemon = _make_slot(_make_pokemon_cd("Dreepy", "Basic", "N", 70), 0)
	player.bench.clear()
	var dusknoir := _make_slot(_make_pokemon_cd("Dusknoir", "Stage 2", "P", 160, "Dusclops", "", [{"name": "Cursed Blast"}]), 0)
	player.bench.append(dusknoir)
	var greninja := _make_slot(_make_pokemon_cd("Radiant Greninja", "Basic", "W", 130), 1)
	var context := {"game_state": gs, "player_index": 0, "source_slot": dusknoir}
	var target_score: float = strategy.score_interaction_target(greninja, {"id": "self_ko_target"}, context)
	var ability_score: float = strategy.score_action_absolute({"kind": "use_ability", "source_slot": dusknoir, "ability_index": 0}, gs, 0)
	return _run_checks([
		_assert_true(target_score < 350.0,
			"Dusknoir should not treat a one-prize support KO as a premium self-KO conversion (got %f)" % target_score),
		_assert_true(ability_score <= 0.0,
			"Dusknoir should not self-KO for an even one-prize support pickoff outside the closing prize window (got %f)" % ability_score),
	])


func test_sparkling_crystal_prefers_dragapult_line_over_support() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyDragapultDusknoir.gd should load"
	var gs := _make_game_state(5)
	var player: PlayerState = gs.players[0]
	var drakloak := _make_slot(_make_pokemon_cd("Drakloak", "Stage 1", "N", 90, "Dreepy"), 0)
	var fezandipiti := _make_slot(_make_pokemon_cd("Fezandipiti ex", "Basic", "D", 210, "", "ex"), 0)
	player.active_pokemon = fezandipiti
	player.bench.clear()
	player.bench.append(drakloak)
	player.hand.append(CardInstance.create(_make_pokemon_cd("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex"), 0))
	var crystal := CardInstance.create(_make_trainer_cd("Sparkling Crystal", "Tool"), 0)
	var drakloak_score: float = strategy.score_action_absolute({"kind": "attach_tool", "card": crystal, "target_slot": drakloak}, gs, 0)
	var support_score: float = strategy.score_action_absolute({"kind": "attach_tool", "card": crystal, "target_slot": fezandipiti}, gs, 0)
	return _run_checks([
		_assert_true(drakloak_score >= 400.0,
			"Sparkling Crystal should be premium on the Drakloak line before Dragapult ex evolves (got %f)" % drakloak_score),
		_assert_true(drakloak_score > support_score + 250.0,
			"Sparkling Crystal should not tie support Pokemon while the Dragapult line can inherit it (line=%f support=%f)" % [drakloak_score, support_score]),
	])


func test_switch_promotes_ready_dragapult_from_support_active() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyDragapultDusknoir.gd should load"
	var gs := _make_game_state(7)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Tatsugiri", "Basic", "N", 70, "", "", [{"name": "Attract Customers"}]), 0)
	player.bench.clear()
	var dragapult := _make_slot(_make_pokemon_cd("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex", [], [
		{"name": "Jet Head", "cost": "C", "damage": "70"},
		{"name": "Phantom Dive", "cost": "RP", "damage": "200"},
	]), 0)
	dragapult.attached_energy.append(CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0))
	var duskull := _make_slot(_make_pokemon_cd("Duskull", "Basic", "P", 60), 0)
	player.bench.append(dragapult)
	player.bench.append(duskull)
	var switch_card := CardInstance.create(_make_trainer_cd("Switch", "Item"), 0)
	var context := {"game_state": gs, "player_index": 0}
	var switch_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": switch_card}, gs, 0)
	var dragapult_target_score: float = strategy.score_interaction_target(dragapult, {"id": "self_switch_target"}, context)
	var duskull_target_score: float = strategy.score_interaction_target(duskull, {"id": "self_switch_target"}, context)
	return _run_checks([
		_assert_true(switch_score >= 420.0,
			"Switch should be a premium conversion card when it promotes a ready Dragapult from a support active (got %f)" % switch_score),
		_assert_true(dragapult_target_score > duskull_target_score + 300.0,
			"Switch target scoring should choose ready Dragapult over setup bench targets (dragapult=%f duskull=%f)" % [dragapult_target_score, duskull_target_score]),
	])


func test_late_deck_pressure_cools_drakloak_churn_with_attacker_online() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyDragapultDusknoir.gd should load"
	var gs := _make_game_state(21)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex", [], [
		{"name": "Jet Head", "cost": "C", "damage": "70"},
		{"name": "Phantom Dive", "cost": "RP", "damage": "200"},
	]), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0))
	player.bench.clear()
	var drakloak := _make_slot(_make_pokemon_cd("Drakloak", "Stage 1", "N", 90, "Dreepy", "", [{"name": "Recon Directive"}]), 0)
	player.bench.append(drakloak)
	_fill_deck(player, 10)
	var score: float = strategy.score_action_absolute({"kind": "use_ability", "source_slot": drakloak, "ability_index": 0}, gs, 0)
	return _assert_true(score <= 40.0,
		"Drakloak should stop optional draw churn under deck-out pressure once a Dragapult attacker is online (got %f)" % score)


func test_late_deck_pressure_cools_non_conversion_arven_search() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyDragapultDusknoir.gd should load"
	var gs := _make_game_state(21)
	var player: PlayerState = gs.players[0]
	var opponent: PlayerState = gs.players[1]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex", [], [
		{"name": "Jet Head", "cost": "C", "damage": "70"},
		{"name": "Phantom Dive", "cost": "RP", "damage": "200"},
	]), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	player.bench.clear()
	player.bench.append(_make_slot(_make_pokemon_cd("Duskull", "Basic", "P", 60), 0))
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Bulky ex", "Basic", "L", 340, "", "ex"), 1)
	_fill_deck(player, 8)
	player.deck.append(CardInstance.create(_make_trainer_cd("Rare Candy"), 0))
	player.deck.append(CardInstance.create(_make_pokemon_cd("Dusknoir", "Stage 2", "P", 160, "Dusclops", "", [{"name": "Cursed Blast"}]), 0))
	var arven := CardInstance.create(_make_trainer_cd("Arven", "Supporter"), 0)
	var score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": arven}, gs, 0)
	return _assert_true(score <= 80.0,
		"Arven should not keep thinning a low deck when no Dusknoir conversion target is available and Dragapult can attack (got %f)" % score)


func _new_strategy() -> RefCounted:
	var script: Variant = load(STRATEGY_PATH)
	return script.new() if script is GDScript else null


func _make_game_state(turn: int = 2) -> GameState:
	var gs := GameState.new()
	gs.turn_number = turn
	gs.current_player_index = 0
	gs.first_player_index = 0
	gs.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		player.active_pokemon = _make_slot(_make_pokemon_cd("Active%d" % pi, "Basic", "C"), pi)
		gs.players.append(player)
	return gs


func _make_pokemon_cd(
	pname: String,
	stage: String = "Basic",
	energy_type: String = "P",
	hp: int = 100,
	evolves_from: String = "",
	mechanic: String = "",
	abilities: Array = [],
	attacks: Array = [],
	retreat_cost: int = 1
) -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.name_en = pname
	cd.card_type = "Pokemon"
	cd.stage = stage
	cd.energy_type = energy_type
	cd.hp = hp
	cd.evolves_from = evolves_from
	cd.mechanic = mechanic
	cd.retreat_cost = retreat_cost
	for ability: Dictionary in abilities:
		cd.abilities.append(ability.duplicate(true))
	for attack: Dictionary in attacks:
		cd.attacks.append(attack.duplicate(true))
	return cd


func _make_trainer_cd(pname: String, card_type: String = "Item") -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.name_en = pname
	cd.card_type = card_type
	return cd


func _make_energy_cd(pname: String, provides: String) -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.name_en = pname
	cd.card_type = "Basic Energy"
	cd.energy_provides = provides
	return cd


func _make_slot(card_data: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner))
	slot.turn_played = 0
	return slot


func _fill_prizes(player: PlayerState, count: int) -> void:
	player.prizes.clear()
	for i: int in count:
		player.prizes.append(CardInstance.create(_make_trainer_cd("Prize%d" % i), player.player_index))


func _fill_deck(player: PlayerState, count: int) -> void:
	player.deck.clear()
	for i: int in count:
		player.deck.append(CardInstance.create(_make_trainer_cd("Deck%d" % i), player.player_index))


func _run_checks(checks: Array[String]) -> String:
	for check: String in checks:
		if check != "":
			return check
	return ""


func _assert_true(value: bool, message: String) -> String:
	return "" if value else message


func _assert_eq(actual: Variant, expected: Variant, message: String) -> String:
	return "" if actual == expected else "%s (expected %s, got %s)" % [message, str(expected), str(actual)]
