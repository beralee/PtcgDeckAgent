class_name TestV17DragapultDusknoirStrategy
extends TestBase


const STRATEGY_PATH := "res://scripts/ai/DeckStrategy17DragapultDusknoir.gd"


func test_opening_poffin_outranks_rotom_before_shell_exists() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy17DragapultDusknoir.gd should load"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V", [{"name": "Instant Charge"}]), 0)
	player.deck.append(CardInstance.create(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0))
	player.deck.append(CardInstance.create(_make_pokemon_cd("Duskull", "Basic", "P", 60), 0))
	var poffin := CardInstance.create(_make_trainer_cd("Buddy-Buddy Poffin"), 0)
	var poffin_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": poffin}, gs, 0)
	var rotom_score: float = strategy.score_action_absolute({"kind": "use_ability", "source_slot": player.active_pokemon, "ability_index": 0}, gs, 0)
	return assert_true(
		poffin_score > rotom_score + 80.0,
		"Opening Poffin should build Dreepy/Duskull before Rotom ends the turn (Poffin=%f Rotom=%f)" % [poffin_score, rotom_score]
	)


func test_opening_poffin_targets_first_dreepy_and_first_duskull() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy17DragapultDusknoir.gd should load"
	var gs := _make_game_state(2)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Rotom V", "Basic", "L", 190, "", "V"), 0)
	var dreepy_a := CardInstance.create(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0)
	var dreepy_b := CardInstance.create(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0)
	var duskull := CardInstance.create(_make_pokemon_cd("Duskull", "Basic", "P", 60), 0)
	var picked: Array = strategy.pick_interaction_items(
		[dreepy_a, dreepy_b, duskull],
		{"id": "buddy_poffin_pokemon", "max_select": 2},
		{"game_state": gs, "player_index": 0}
	)
	var names: Array[String] = []
	for item: Variant in picked:
		if item is CardInstance:
			names.append(_card_name(item as CardInstance))
	names.sort()
	return run_checks([
		assert_eq(names.size(), 2, "Poffin should pick two targets"),
		assert_true("Dreepy" in names, "Poffin should pick the first Dreepy line"),
		assert_true("Duskull" in names, "Poffin should pick the first Duskull line instead of a second Dreepy"),
	])


func test_v17_energy_routing_prefers_missing_dragapult_type() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy17DragapultDusknoir.gd should load"
	var gs := _make_game_state(3)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	var fire := CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0)
	var psychic := CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0)
	var fire_score: float = strategy.score_action_absolute({"kind": "attach_energy", "card": fire, "target_slot": player.active_pokemon}, gs, 0)
	var psychic_score: float = strategy.score_action_absolute({"kind": "attach_energy", "card": psychic, "target_slot": player.active_pokemon}, gs, 0)
	return assert_true(
		fire_score > psychic_score + 400.0,
		"Once a Dragapult line already has Psychic, Fire should be routed before duplicate Psychic (fire=%f psychic=%f)" % [fire_score, psychic_score]
	)


func test_v17_crispin_picks_hand_energy_and_attaches_missing_type_to_dragapult_line() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy17DragapultDusknoir.gd should load"
	var gs := _make_game_state(3)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	var support := _make_slot(_make_pokemon_cd("Radiant Alakazam", "Basic", "P", 130), 0)
	player.bench.append(support)
	var fire := CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0)
	var psychic := CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0)
	player.deck.append(fire)
	player.deck.append(psychic)
	var crispin := CardInstance.create(_make_trainer_cd("Crispin", "Supporter", "136fdb6578daa3b81aef369495de4c3d"), 0)
	var crispin_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": crispin}, gs, 0)
	var hand_pick: Array = strategy.pick_interaction_items(
		[fire, psychic],
		{"id": "csv9c196_energy_to_hand", "max_select": 1},
		{"game_state": gs, "player_index": 0}
	)
	var attach_pick: Array = strategy.pick_interaction_items(
		[fire, psychic],
		{"id": "csv9c196_energy_attachment", "max_select": 1},
		{"game_state": gs, "player_index": 0}
	)
	var dreepy_target_score: float = strategy.score_interaction_target(
		player.active_pokemon,
		{"id": "csv9c196_energy_attachment"},
		{"game_state": gs, "player_index": 0, "source_card": fire}
	)
	var support_target_score: float = strategy.score_interaction_target(
		support,
		{"id": "csv9c196_energy_attachment"},
		{"game_state": gs, "player_index": 0, "source_card": fire}
	)
	return run_checks([
		assert_true(crispin_score >= 700.0, "Crispin should be a premium support when it fixes Dragapult's missing Fire/Psychic pair (got %f)" % crispin_score),
		assert_eq(_picked_card_name(hand_pick), "Psychic Energy", "Crispin should put the duplicate/less urgent Energy into hand"),
		assert_eq(_picked_card_name(attach_pick), "Fire Energy", "Crispin should attach the missing attack type from deck"),
		assert_true(dreepy_target_score > support_target_score + 400.0, "Crispin attachment should target the Dragapult line, not support Pokemon (line=%f support=%f)" % [dreepy_target_score, support_target_score]),
	])


func test_v17_handoff_scoring_promotes_ready_dragapult_from_support_active() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy17DragapultDusknoir.gd should load"
	var gs := _make_game_state(7)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Tatsugiri", "Basic", "N", 70, "", "", [{"name": "Attract Customers"}]), 0)
	player.bench.clear()
	var dragapult := _make_slot(_make_pokemon_cd("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex", [], [
		{"name": "Jet Head", "cost": "C", "damage": "70"},
		{"name": "Phantom Dive", "cost": "RP", "damage": "200"},
	]), 0)
	dragapult.attached_energy.append(CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0))
	dragapult.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	var duskull := _make_slot(_make_pokemon_cd("Duskull", "Basic", "P", 60), 0)
	player.bench.append(dragapult)
	player.bench.append(duskull)
	var context := {"game_state": gs, "player_index": 0}
	var dragapult_score: float = strategy.score_handoff_target(dragapult, {"id": "self_switch_target"}, context)
	var duskull_score: float = strategy.score_handoff_target(duskull, {"id": "self_switch_target"}, context)
	return assert_true(
		dragapult_score > duskull_score + 300.0,
		"Shared handoff scoring should choose ready Dragapult over a setup Duskull (dragapult=%f duskull=%f)" % [dragapult_score, duskull_score]
	)


func test_v17_gust_target_prefers_bench_prize_conversion() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy17DragapultDusknoir.gd should load"
	var gs := _make_game_state(8)
	var player: PlayerState = gs.players[0]
	var opponent: PlayerState = gs.players[1]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex", [], [
		{"name": "Jet Head", "cost": "C", "damage": "70"},
		{"name": "Phantom Dive", "cost": "RP", "damage": "200"},
	]), 0)
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Fire Energy", "R"), 0))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Psychic Energy", "P"), 0))
	opponent.bench.clear()
	var damaged_raikou := _make_slot(_make_pokemon_cd("Raikou V", "Basic", "L", 200, "", "V"), 1)
	damaged_raikou.damage_counters = 20
	var support := _make_slot(_make_pokemon_cd("Magnemite", "Basic", "L", 70), 1)
	opponent.bench.append(support)
	opponent.bench.append(damaged_raikou)
	var context := {"game_state": gs, "player_index": 0}
	var raikou_score: float = strategy.score_handoff_target(damaged_raikou, {"id": "opponent_switch_target"}, context)
	var support_score: float = strategy.score_handoff_target(support, {"id": "opponent_switch_target"}, context)
	return assert_true(
		raikou_score > support_score + 500.0,
		"Boss/Counter target scoring should gust a benched two-prize KO over a low-value support target (raikou=%f support=%f)" % [raikou_score, support_score]
	)


func test_v17_drakloak_look_top_pick_prioritizes_evolution_route_over_boss() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategy17DragapultDusknoir.gd should load"
	var gs := _make_game_state(7)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Dreepy", "Basic", "P", 70), 0)
	player.deck.append(CardInstance.create(_make_pokemon_cd("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex"), 0))
	var boss := CardInstance.create(_make_trainer_cd("Boss's Orders", "Supporter"), 0)
	var candy := CardInstance.create(_make_trainer_cd("Rare Candy"), 0)
	var picked: Array = strategy.pick_interaction_items(
		[boss, candy],
		{"id": "look_top_pick", "max_select": 1},
		{"game_state": gs, "player_index": 0}
	)
	return assert_eq(
		_picked_card_name(picked),
		"Rare Candy",
		"Drakloak top-card selection should finish the first Dragapult route before holding a generic Boss"
	)


func _new_strategy() -> RefCounted:
	CardInstance.reset_id_counter()
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


func _make_trainer_cd(pname: String, card_type: String = "Item", effect_id: String = "") -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.name_en = pname
	cd.card_type = card_type
	cd.effect_id = effect_id
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


func _card_name(card: CardInstance) -> String:
	if card == null or card.card_data == null:
		return ""
	return str(card.card_data.name_en) if str(card.card_data.name_en) != "" else str(card.card_data.name)


func _picked_card_name(items: Array) -> String:
	if items.is_empty() or not (items[0] is CardInstance):
		return ""
	return _card_name(items[0] as CardInstance)
