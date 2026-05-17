class_name TestV17PalkiaGholdengoLLM
extends TestBase

const LLM_SCRIPT_PATH := "res://scripts/ai/DeckStrategy17PalkiaGholdengoLLM.gd"


func _new_llm_strategy() -> RefCounted:
	CardInstance.reset_id_counter()
	var script: Variant = load(LLM_SCRIPT_PATH)
	return script.new() if script is GDScript else null


func _pokemon(
	pname: String,
	energy_type: String = "C",
	hp: int = 100,
	stage: String = "Basic",
	mechanic: String = "",
	retreat_cost: int = 1
) -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.name_en = pname
	cd.card_type = "Pokemon"
	cd.energy_type = energy_type
	cd.hp = hp
	cd.stage = stage
	cd.mechanic = mechanic
	cd.retreat_cost = retreat_cost
	return cd


func _energy(pname: String, provides: String) -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.name_en = pname
	cd.card_type = "Basic Energy"
	cd.energy_type = provides
	cd.energy_provides = provides
	return cd


func _card(cd: CardData, owner_index: int = 0) -> CardInstance:
	return CardInstance.create(cd, owner_index)


func _slot(cd: CardData, owner_index: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(_card(cd, owner_index))
	return slot


func _game_state(turn: int = 2) -> GameState:
	var gs := GameState.new()
	gs.turn_number = turn
	gs.current_player_index = 0
	gs.first_player_index = 0
	gs.phase = GameState.GamePhase.MAIN
	var player := PlayerState.new()
	player.player_index = 0
	player.active_pokemon = _slot(_pokemon("Gimmighoul", "M", 70), 0)
	var opponent := PlayerState.new()
	opponent.player_index = 1
	opponent.active_pokemon = _slot(_pokemon("Miraidon ex", "L", 220, "Basic", "ex"), 1)
	opponent.active_pokemon.attached_energy.append(_card(_energy("Lightning Energy", "L"), 1))
	gs.players.append(player)
	gs.players.append(opponent)
	return gs


func test_v17_palkia_gholdengo_llm_opening_holds_palkia_v_liability() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "Palkia/Gholdengo LLM strategy should instantiate"
	var player := PlayerState.new()
	player.player_index = 0
	player.hand.append(_card(_pokemon("Origin Forme Palkia V", "W", 220, "Basic", "V", 2), 0))
	player.hand.append(_card(_pokemon("Gimmighoul", "M", 70), 0))
	player.hand.append(_card(_pokemon("Manaphy", "W", 70), 0))

	var plan: Dictionary = strategy.call("plan_opening_setup", player)
	var active_idx := int(plan.get("active_hand_index", -1))
	var bench_indices: Array = plan.get("bench_hand_indices", [])

	return run_checks([
		assert_eq(active_idx, 1, "LLM opening should still lead Gimmighoul over lightning-weak Palkia V"),
		assert_false(bench_indices.has(0), "LLM opening should hold Palkia V instead of exposing an early two-prize liability"),
	])


func test_v17_palkia_gholdengo_llm_blocks_early_palkia_v_bench_into_lightning_pressure() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "Palkia/Gholdengo LLM strategy should instantiate"
	var gs := _game_state(2)
	var palkia := _card(_pokemon("Origin Forme Palkia V", "W", 220, "Basic", "V", 2), 0)
	var manaphy := _card(_pokemon("Manaphy", "W", 70), 0)

	var palkia_score: float = strategy.call("score_action_absolute", {
		"kind": "play_basic_to_bench",
		"card": palkia,
	}, gs, 0)
	var manaphy_score: float = strategy.call("score_action_absolute", {
		"kind": "play_basic_to_bench",
		"card": manaphy,
	}, gs, 0)

	return run_checks([
		assert_true(palkia_score <= -9000.0, "Early Palkia V bench should be blocked against Lightning pressure (score=%f)" % palkia_score),
		assert_true(manaphy_score > palkia_score, "The liability block should target Palkia V, not every basic bench action"),
	])


func test_v17_palkia_gholdengo_llm_blocks_late_palkia_v_bench_into_lightning_pressure() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "Palkia/Gholdengo LLM strategy should instantiate"
	var gs := _game_state(8)
	var palkia := _card(_pokemon("Origin Forme Palkia V", "W", 220, "Basic", "V", 2), 0)

	var score: float = strategy.call("score_action_absolute", {
		"kind": "play_basic_to_bench",
		"card": palkia,
	}, gs, 0)

	return assert_true(score <= -9000.0, "Late Palkia V bench should stay blocked against Lightning prize pressure (score=%f)" % score)


func test_v17_palkia_gholdengo_llm_allows_palkia_v_bench_without_lightning_pressure() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "Palkia/Gholdengo LLM strategy should instantiate"
	var gs := _game_state(8)
	gs.players[1].active_pokemon = _slot(_pokemon("Charizard ex", "R", 330, "Stage 2", "ex"), 1)
	var palkia := _card(_pokemon("Origin Forme Palkia V", "W", 220, "Basic", "V", 2), 0)

	var score: float = strategy.call("score_action_absolute", {
		"kind": "play_basic_to_bench",
		"card": palkia,
	}, gs, 0)

	return assert_true(score > -9000.0, "Palkia V bench should remain available when the opponent is not presenting Lightning pressure (score=%f)" % score)


func test_v17_palkia_gholdengo_llm_marks_gimmighoul_tackle_as_low_value() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "Palkia/Gholdengo LLM strategy should instantiate"
	var gs := _game_state(8)
	var low_value_attack := {
		"kind": "attack",
		"source_slot": gs.players[0].active_pokemon,
		"attack_index": 1,
		"attack_name": "Tackle",
		"projected_damage": 50,
		"projected_knockout": false,
	}
	var knockout_attack := low_value_attack.duplicate(true)
	knockout_attack["projected_knockout"] = true

	return run_checks([
		assert_true(strategy.call("_is_low_value_runtime_attack_action", low_value_attack, gs, 0), "Gimmighoul's non-KO 50 damage attack should be treated as low-value tempo loss"),
		assert_false(strategy.call("_is_low_value_runtime_attack_action", knockout_attack, gs, 0), "A Gimmighoul attack that takes a KO should stay available"),
	])


func test_v17_palkia_gholdengo_llm_blocks_gimmighoul_tackle_when_routes_remain() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "Palkia/Gholdengo LLM strategy should instantiate"
	var gs := _game_state(8)
	gs.players[0].hand.append(_card(_pokemon("Gholdengo ex", "M", 260, "Stage 1", "ex"), 0))
	gs.players[0].hand.append(_card(_pokemon("Nest Ball"), 0))
	gs.players[0].hand.append(_card(_pokemon("Superior Energy Retrieval"), 0))
	gs.players[0].hand.append(_card(_pokemon("Earthen Vessel"), 0))

	var tackle_score: float = strategy.call("score_action_absolute", {
		"kind": "attack",
		"source_slot": gs.players[0].active_pokemon,
		"attack_index": 1,
		"attack_name": "Tackle",
		"projected_damage": 50,
		"projected_knockout": false,
	}, gs, 0)
	var ko_score: float = strategy.call("score_action_absolute", {
		"kind": "attack",
		"source_slot": gs.players[0].active_pokemon,
		"attack_index": 1,
		"attack_name": "Tackle",
		"projected_damage": 50,
		"projected_knockout": true,
	}, gs, 0)

	return run_checks([
		assert_true(tackle_score <= -9000.0, "Non-KO Gimmighoul Tackle should be blocked while productive routes remain (score=%f)" % tackle_score),
		assert_true(ko_score > tackle_score, "The low-value block should not suppress a prize-taking Gimmighoul attack"),
	])


func test_v17_palkia_gholdengo_llm_blocks_gimmighoul_setup_attack_when_evolution_ready() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "Palkia/Gholdengo LLM strategy should instantiate"
	var gs := _game_state(4)
	gs.players[0].active_pokemon.turn_played = 0
	gs.players[0].hand.append(_card(_pokemon("Gholdengo ex", "M", 260, "Stage 1", "ex"), 0))

	var setup_score: float = strategy.call("score_action_absolute", {
		"kind": "attack",
		"source_slot": gs.players[0].active_pokemon,
		"attack_index": 0,
		"attack_name": "Little Messenger",
		"projected_damage": 0,
		"projected_knockout": false,
	}, gs, 0)

	return assert_true(setup_score <= -9000.0, "Gimmighoul setup attack should be blocked when Gholdengo evolution is ready into Lightning pressure (score=%f)" % setup_score)


func test_v17_palkia_gholdengo_llm_make_it_rain_picks_ko_energy_count() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "Palkia/Gholdengo LLM strategy should instantiate"
	var gs := _game_state(8)
	gs.players[1].active_pokemon.damage_counters = 20
	var items: Array = [
		_card(_energy("Metal Energy", "M"), 0),
		_card(_energy("Water Energy", "W"), 0),
		_card(_energy("Grass Energy", "G"), 0),
		_card(_energy("Fire Energy", "R"), 0),
		_card(_energy("Lightning Energy", "L"), 0),
	]

	var picked: Array = strategy.call("pick_interaction_items", items, {
		"id": "discard_basic_energy",
		"max_select": 10,
	}, {
		"game_state": gs,
		"player_index": 0,
	})

	return assert_eq(picked.size(), 4, "Make It Rain should discard exactly enough energy to KO a 200 HP active")
