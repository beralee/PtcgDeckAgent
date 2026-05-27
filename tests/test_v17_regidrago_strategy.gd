class_name TestV17RegidragoStrategy
extends TestBase

const StrategyRegidrago = preload("res://scripts/ai/DeckStrategy17Regidrago.gd")


func _pokemon(
	pname: String,
	stage: String = "Basic",
	energy_type: String = "N",
	hp: int = 100,
	evolves_from: String = "",
	mechanic: String = "",
	attacks: Array = [],
	retreat_cost: int = 1,
	set_code: String = "",
	card_index: String = ""
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
	cd.set_code = set_code
	cd.card_index = card_index
	cd.attacks.clear()
	for attack: Dictionary in attacks:
		cd.attacks.append(attack.duplicate(true))
	return cd


func _trainer(pname: String, card_type: String = "Item") -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.name_en = pname
	cd.card_type = card_type
	return cd


func _energy(pname: String, provides: String) -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.name_en = pname
	cd.card_type = "Basic Energy"
	cd.energy_type = provides
	cd.energy_provides = provides
	return cd


func _slot(cd: CardData, owner_index: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(cd, owner_index))
	return slot


func _attach(slot: PokemonSlot, provides: String, count: int) -> void:
	for i: int in count:
		slot.attached_energy.append(CardInstance.create(_energy("%s Energy %d" % [provides, i], provides), 0))


func _player(pi: int = 0) -> PlayerState:
	var player := PlayerState.new()
	player.player_index = pi
	return player


func _game_state(turn: int = 3) -> GameState:
	var gs := GameState.new()
	gs.turn_number = turn
	gs.current_player_index = 0
	gs.first_player_index = 0
	gs.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var player := _player(pi)
		player.active_pokemon = _slot(_pokemon("Active %d" % pi), pi)
		gs.players.append(player)
	return gs


func _card(cd: CardData, owner_index: int = 0) -> CardInstance:
	return CardInstance.create(cd, owner_index)


func _names(cards: Array) -> Array[String]:
	var result: Array[String] = []
	for item: Variant in cards:
		if item is CardInstance and (item as CardInstance).card_data != null:
			result.append(str((item as CardInstance).card_data.name_en))
	return result


func _slot_names(slots: Array) -> Array[String]:
	var result: Array[String] = []
	for item: Variant in slots:
		if item is PokemonSlot and (item as PokemonSlot).get_card_data() != null:
			result.append(str((item as PokemonSlot).get_card_data().name_en))
	return result


func test_v17_regidrago_opening_uses_ogerpon_as_active_buffer() -> String:
	var strategy := StrategyRegidrago.new()
	var player := _player()
	var regidrago := _card(_pokemon("Regidrago V", "Basic", "N", 220, "", "V"), 0)
	var ogerpon := _card(_pokemon("Teal Mask Ogerpon ex", "Basic", "G", 210, "", "ex"), 0)
	player.hand.append_array([
		regidrago,
		ogerpon,
		_card(_pokemon("Mew ex", "Basic", "P", 180, "", "ex"), 0),
	])

	var plan: Dictionary = strategy.plan_opening_setup(player)
	var bench_indices: Array = plan.get("bench_hand_indices", []) as Array

	return run_checks([
		assert_eq(int(plan.get("active_hand_index", -1)), 1, "Regidrago strong opening should let Ogerpon absorb the first Charizard hit when both basics are available"),
		assert_true(0 in bench_indices, "Opening setup should still bench Regidrago V behind the Ogerpon buffer"),
	])


func test_v17_regidrago_contract_exposes_launch_owner_and_fuel_search() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(2)
	var player := gs.players[0]
	player.active_pokemon = _slot(_pokemon("Regidrago V", "Basic", "N", 220, "", "V", [
		{"name": "Celestial Roar", "cost": "C", "damage": ""},
		{"name": "Dragon Laser", "cost": "GGR", "damage": "130"},
	], 3), 0)
	player.bench.append(_slot(_pokemon("Teal Mask Ogerpon ex", "Basic", "G", 210, "", "ex"), 0))
	player.hand.append(_card(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V", [
		{"name": "Apex Dragon", "cost": "GGR", "damage": ""},
	], 3), 0))
	player.deck.append(_card(_pokemon("Giratina VSTAR", "VSTAR", "N", 280, "Giratina V", "V"), 0))
	player.deck.append(_card(_pokemon("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex"), 0))

	var contract: Dictionary = strategy.build_turn_contract(gs, 0, {"prompt_kind": "action_selection"})
	var owner: Dictionary = contract.get("owner", {}) as Dictionary
	var priorities: Dictionary = contract.get("priorities", {}) as Dictionary
	var search_priorities: Array = priorities.get("search", []) as Array

	return run_checks([
		assert_eq(str(contract.get("intent", "")), "launch_shell", "Before the first VSTAR attack, Regidrago should publish a launch-shell turn contract"),
		assert_eq(str(owner.get("bridge_target_name", "")), "Regidrago VSTAR", "Launch shell should bridge all search/evolve/attach choices into Regidrago VSTAR"),
		assert_true("Regidrago VSTAR" in search_priorities, "Search priorities should include Regidrago VSTAR while the active V has not evolved"),
		assert_true("Giratina VSTAR" in search_priorities, "Search priorities should include Giratina VSTAR as discard attack fuel"),
		assert_true("Dragapult ex" in search_priorities, "Search priorities should include Dragapult ex as spread attack fuel"),
	])


func test_v17_regidrago_evolve_outranks_celestial_roar_churn() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(3)
	var player := gs.players[0]
	var active := _slot(_pokemon("Regidrago V", "Basic", "N", 220, "", "V", [
		{"name": "Celestial Roar", "cost": "C", "damage": ""},
		{"name": "Dragon Laser", "cost": "GGR", "damage": "130"},
	], 3), 0)
	_attach(active, "G", 1)
	player.active_pokemon = active
	var vstar := _card(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V", [
		{"name": "Apex Dragon", "cost": "GGR", "damage": ""},
	], 3), 0)

	var evolve_score: float = strategy.score_action_absolute({"kind": "evolve", "card": vstar, "target_slot": active}, gs, 0)
	var roar_score: float = strategy.score_action_absolute({
		"kind": "attack",
		"source_slot": active,
		"attack_index": 0,
		"attack_name": "Celestial Roar",
		"projected_damage": 0,
		"projected_knockout": false,
	}, gs, 0)

	return assert_true(evolve_score > roar_score, "Regidrago VSTAR evolution should outrank repeated Celestial Roar deck churn (evolve=%f roar=%f)" % [evolve_score, roar_score])


func test_v17_regidrago_defers_basic_dragon_laser_when_vstar_conversion_is_ready() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(4)
	var player := gs.players[0]
	for i: int in 6:
		player.prizes.append(_card(_trainer("Prize %d" % i), 0))
	var active := _slot(_pokemon("Regidrago V", "Basic", "N", 220, "", "V", [
		{"name": "Celestial Roar", "cost": "C", "damage": ""},
		{"name": "Dragon Laser", "cost": "GGR", "damage": "130"},
	], 3), 0)
	_attach(active, "G", 2)
	_attach(active, "R", 1)
	player.active_pokemon = active
	var vstar := _card(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V", [
		{"name": "Apex Dragon", "cost": "GGR", "damage": ""},
	], 3), 0)
	player.hand.append(vstar)
	player.discard_pile.append(_card(_pokemon("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex"), 0))

	var evolve_score: float = strategy.score_action_absolute({"kind": "evolve", "card": vstar, "target_slot": active}, gs, 0)
	var laser_score: float = strategy.score_action_absolute({
		"kind": "attack",
		"source_slot": active,
		"attack_index": 1,
		"attack_name": "Dragon Laser",
		"projected_damage": 130,
		"projected_knockout": true,
	}, gs, 0)

	return run_checks([
		assert_true(laser_score < 0.0, "A ready Regidrago V should not keep taking small prizes with Dragon Laser while VSTAR plus Apex fuel is available (laser=%f)" % laser_score),
		assert_true(evolve_score > laser_score, "VSTAR conversion should outrank basic Dragon Laser once Apex fuel is online (evolve=%f laser=%f)" % [evolve_score, laser_score]),
	])


func test_v17_regidrago_defers_basic_dragon_laser_into_chinese_charmeleon_line() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(4)
	var player := gs.players[0]
	for i: int in 6:
		player.prizes.append(_card(_trainer("Prize %d" % i), 0))
	var active := _slot(_pokemon("Regidrago V", "Basic", "N", 220, "", "V", [
		{"name": "Celestial Roar", "cost": "C", "damage": ""},
		{"name": "Dragon Laser", "cost": "GGR", "damage": "130"},
	], 3), 0)
	_attach(active, "G", 2)
	_attach(active, "R", 1)
	player.active_pokemon = active
	player.hand.append(_card(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V", [
		{"name": "Apex Dragon", "cost": "GGR", "damage": ""},
	], 3), 0))
	gs.players[1].active_pokemon = _slot(_pokemon("火恐龙", "Stage 1", "R", 100, "小火龙"), 1)

	var laser_score: float = strategy.score_action_absolute({
		"kind": "attack",
		"source_slot": active,
		"attack_index": 1,
		"attack_name": "Dragon Laser",
		"projected_damage": 130,
		"projected_knockout": true,
	}, gs, 0)

	return assert_true(laser_score < 0.0, "Chinese Charmeleon line should still block basic Dragon Laser before VSTAR conversion (laser=%f)" % laser_score)


func test_v17_regidrago_uses_celestial_roar_as_early_fallback_before_vstar() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(2)
	var player := gs.players[0]
	var active := _slot(_pokemon("Regidrago V", "Basic", "N", 220, "", "V", [
		{"name": "Celestial Roar", "cost": "C", "damage": ""},
		{"name": "Dragon Laser", "cost": "GGR", "damage": "130"},
	], 3), 0)
	_attach(active, "G", 1)
	player.active_pokemon = active
	for i: int in 30:
		player.deck.append(_card(_trainer("Filler %d" % i), 0))

	var roar_score: float = strategy.score_action_absolute({
		"kind": "attack",
		"source_slot": active,
		"attack_index": 0,
		"attack_name": "Celestial Roar",
		"projected_damage": 0,
		"projected_knockout": false,
	}, gs, 0)
	var research_score: float = strategy.score_action_absolute({
		"kind": "play_trainer",
		"card": _card(_trainer("Professor's Research", "Supporter"), 0),
	}, gs, 0)

	return assert_true(roar_score > research_score, "Before VSTAR/fuel are online, Celestial Roar should be a real fallback engine action (roar=%f research=%f)" % [roar_score, research_score])


func test_v17_regidrago_ultra_ball_discards_dragon_fuel_before_generic_resources() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(3)
	gs.players[0].active_pokemon = _slot(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V"), 0)
	var giratina := _card(_pokemon("Giratina VSTAR", "VSTAR", "N", 280, "Giratina V", "V"), 0)
	var dragapult := _card(_pokemon("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex"), 0)
	var fire := _card(_energy("Fire Energy", "R"), 0)
	var nest := _card(_trainer("Nest Ball"), 0)

	var selected: Array = strategy.pick_interaction_items(
		[giratina, dragapult, fire, nest],
		{"id": "discard_cards", "max_select": 2},
		{"game_state": gs, "player_index": 0}
	)
	var selected_names := _names(selected)

	return run_checks([
		assert_true("Giratina VSTAR" in selected_names, "Ultra Ball discard should pick Giratina VSTAR as real copied-attack fuel"),
		assert_true("Dragapult ex" in selected_names, "Ultra Ball discard should pick Dragapult ex before generic Energy or search cards"),
	])


func test_v17_regidrago_searches_vstar_before_extra_fuel_when_v_is_online() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(3)
	var player := gs.players[0]
	player.active_pokemon = _slot(_pokemon("Regidrago V", "Basic", "N", 220, "", "V"), 0)
	var vstar := _card(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V"), 0)
	var giratina := _card(_pokemon("Giratina VSTAR", "VSTAR", "N", 280, "Giratina V", "V"), 0)

	var selected: Array = strategy.pick_interaction_items(
		[vstar, giratina],
		{"id": "search_pokemon", "max_select": 1},
		{"game_state": gs, "player_index": 0}
	)
	var selected_names := _names(selected)

	return assert_eq(selected_names, ["Regidrago VSTAR"], "When Regidrago V is already online, search should complete VSTAR before taking another discard-fuel Pokemon")


func test_v17_regidrago_searches_backup_line_after_first_vstar_online() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(5)
	var player := gs.players[0]
	player.active_pokemon = _slot(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V"), 0)
	player.discard_pile.append(_card(_pokemon("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex"), 0))
	var backup_v := _card(_pokemon("Regidrago V", "Basic", "N", 220, "", "V"), 0)
	var kyurem := _card(_pokemon("CSV9C_147", "Basic", "N", 130, "", "", [], 1, "CSV9C", "147"), 0)

	var selected: Array = strategy.pick_interaction_items(
		[backup_v, kyurem],
		{"id": "search_pokemon", "max_select": 1},
		{"game_state": gs, "player_index": 0}
	)

	return assert_eq(_names(selected), ["Regidrago V"], "After the first VSTAR is online, search should still build a backup Regidrago line before low-priority fuel")


func test_v17_regidrago_searches_backup_v_before_premium_fuel_when_primary_online() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(5)
	var player := gs.players[0]
	var active := _slot(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V"), 0)
	_attach(active, "G", 2)
	_attach(active, "R", 1)
	player.active_pokemon = active
	player.discard_pile.append(_card(_pokemon("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex"), 0))
	var backup_v := _card(_pokemon("Regidrago V", "Basic", "N", 220, "", "V"), 0)
	var exeggutor := _card(_pokemon("CSV9C_144", "Stage 1", "N", 300, "Exeggcute", "ex", [], 3, "CSV9C", "144"), 0)

	var selected: Array = strategy.pick_interaction_items(
		[exeggutor, backup_v],
		{"id": "search_pokemon", "max_select": 1},
		{"game_state": gs, "player_index": 0}
	)

	return assert_eq(_names(selected), ["Regidrago V"], "A ready primary Regidrago still needs a backup V before premium extra fuel")


func test_v17_regidrago_rebuild_searches_regidrago_v_before_extra_fuel_when_primary_is_gone() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(6)
	var player := gs.players[0]
	player.active_pokemon = _slot(_pokemon("Teal Mask Ogerpon ex", "Basic", "G", 210, "", "ex"), 0)
	player.discard_pile.append(_card(_pokemon("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex"), 0))
	player.discard_pile.append(_card(_pokemon("Hisuian Goodra VSTAR", "VSTAR", "N", 270, "Hisuian Goodra V", "V"), 0))
	var backup_v := _card(_pokemon("Regidrago V", "Basic", "N", 220, "", "V"), 0)
	var exeggutor := _card(_pokemon("CSV9C_144", "Stage 1", "N", 300, "Exeggcute", "ex", [], 3, "CSV9C", "144"), 0)

	var selected: Array = strategy.pick_interaction_items(
		[exeggutor, backup_v],
		{"id": "search_pokemon", "max_select": 1},
		{"game_state": gs, "player_index": 0}
	)

	return assert_eq(_names(selected), ["Regidrago V"], "After the only Regidrago is gone, rebuild search must pick Regidrago V before another copied-attack fuel card")


func test_v17_regidrago_searches_backup_vstar_before_extra_fuel_after_backup_v_is_live() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(7)
	var player := gs.players[0]
	player.active_pokemon = _slot(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V"), 0)
	player.bench.append(_slot(_pokemon("Regidrago V", "Basic", "N", 220, "", "V"), 0))
	player.discard_pile.append(_card(_pokemon("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex"), 0))
	gs.players[1].active_pokemon = _slot(_pokemon("Charizard ex", "Stage 2", "R", 330, "Charmeleon", "ex"), 1)
	var vstar := _card(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V"), 0)
	var exeggutor := _card(_pokemon("CSV9C_144", "Stage 1", "N", 300, "Exeggcute", "ex", [], 3, "CSV9C", "144"), 0)

	var selected: Array = strategy.pick_interaction_items(
		[vstar, exeggutor],
		{"id": "search_pokemon", "max_select": 1},
		{"game_state": gs, "player_index": 0}
	)

	return assert_eq(_names(selected), ["Regidrago VSTAR"], "Once a backup Regidrago V is live into Charizard pressure, search should complete the backup VSTAR before taking another fuel card")


func test_v17_regidrago_searches_dragapult_before_giratina_as_first_spread_fuel() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(5)
	var player := gs.players[0]
	player.active_pokemon = _slot(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V"), 0)
	var giratina := _card(_pokemon("Giratina VSTAR", "VSTAR", "N", 280, "Giratina V", "V"), 0)
	var dragapult := _card(_pokemon("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex"), 0)

	var selected: Array = strategy.pick_interaction_items(
		[dragapult, giratina],
		{"id": "search_pokemon", "max_select": 1},
		{"game_state": gs, "player_index": 0}
	)

	return assert_eq(_names(selected), ["Dragapult ex"], "V17 Regidrago should search Dragapult ex before Giratina VSTAR when choosing first copied-attack spread fuel")


func test_v17_regidrago_copied_attack_prefers_dragapult_into_developed_bench() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(5)
	gs.players[0].active_pokemon = _slot(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V"), 0)
	gs.players[1].active_pokemon = _slot(_pokemon("Miraidon ex", "Basic", "L", 330, "", "ex"), 1)
	gs.players[1].bench.append(_slot(_pokemon("Iron Hands ex", "Basic", "L", 230, "", "ex"), 1))
	gs.players[1].bench.append(_slot(_pokemon("Raikou V", "Basic", "L", 200, "", "V"), 1))
	var options: Array = [
		{
			"source_card": _card(_pokemon("Giratina VSTAR", "VSTAR", "N", 280, "Giratina V", "V"), 0),
			"attack_index": 0,
			"attack": {"name": "Lost Impact", "cost": "GPC", "damage": "280", "is_vstar_power": false},
		},
		{
			"source_card": _card(_pokemon("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex"), 0),
			"attack_index": 1,
			"attack": {"name": "Phantom Dive", "cost": "RP", "damage": "200", "is_vstar_power": false},
		},
	]

	var selected: Array = strategy.pick_interaction_items(
		options,
		{"id": "copied_attack", "max_select": 1},
		{"game_state": gs, "player_index": 0}
	)
	var picked := ""
	if not selected.is_empty() and selected[0] is Dictionary:
		var source_card: CardInstance = (selected[0] as Dictionary).get("source_card", null)
		var attack: Dictionary = (selected[0] as Dictionary).get("attack", {})
		if source_card != null and source_card.card_data != null:
			picked = "%s:%s" % [str(source_card.card_data.name_en), str(attack.get("name", ""))]

	return assert_eq(picked, "Dragapult ex:Phantom Dive", "Regidrago should choose Dragapult's spread copy when Miraidon has a developed bench")


func test_v17_regidrago_dragapult_spread_targets_iron_hands_pressure() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(5)
	gs.players[0].active_pokemon = _slot(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V"), 0)
	var iron_hands := _slot(_pokemon("Iron Hands ex", "Basic", "L", 230, "", "ex"), 1)
	var latias := _slot(_pokemon("Latias ex", "Basic", "P", 210, "", "ex"), 1)
	gs.players[1].bench.append(iron_hands)
	gs.players[1].bench.append(latias)

	var selected: Array = strategy.pick_interaction_items(
		[latias, iron_hands],
		{"id": "bench_damage_counters", "max_select": 1},
		{"game_state": gs, "player_index": 0}
	)

	return assert_true(not selected.is_empty() and selected[0] == iron_hands, "Dragapult copied spread should pressure Iron Hands before generic support ex targets")


func test_v17_regidrago_copied_attack_keeps_dragapult_for_200hp_prize_plus_spread() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(5)
	gs.players[0].active_pokemon = _slot(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V"), 0)
	gs.players[1].active_pokemon = _slot(_pokemon("Raikou V", "Basic", "L", 200, "", "V"), 1)
	gs.players[1].bench.append(_slot(_pokemon("Iron Hands ex", "Basic", "L", 230, "", "ex"), 1))
	var options: Array = [
		{
			"source_card": _card(_pokemon("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex"), 0),
			"attack_index": 1,
			"attack": {"name": "Phantom Dive", "cost": "RP", "damage": "200", "is_vstar_power": false},
		},
		{
			"source_card": _card(_pokemon("Hisuian Goodra VSTAR", "VSTAR", "N", 270, "Hisuian Goodra V", "V"), 0),
			"attack_index": 0,
			"attack": {"name": "Rolling Iron", "cost": "GMW", "damage": "200", "is_vstar_power": false},
		},
	]

	var selected: Array = strategy.pick_interaction_items(
		options,
		{"id": "copied_attack", "max_select": 1},
		{"game_state": gs, "player_index": 0}
	)
	var picked := ""
	if not selected.is_empty() and selected[0] is Dictionary:
		var source_card: CardInstance = (selected[0] as Dictionary).get("source_card", null)
		var attack: Dictionary = (selected[0] as Dictionary).get("attack", {})
		if source_card != null and source_card.card_data != null:
			picked = "%s:%s" % [str(source_card.card_data.name_en), str(attack.get("name", ""))]

	return assert_eq(picked, "Dragapult ex:Phantom Dive", "Regidrago should keep the user-target Dragapult 200+spread line when it already takes the active prize")


func test_v17_regidrago_copied_attack_prefers_goodra_prize_into_charizard_pressure() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(5)
	gs.players[0].active_pokemon = _slot(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V"), 0)
	gs.players[1].active_pokemon = _slot(_pokemon("Rotom V", "Basic", "L", 190, "", "V"), 1)
	gs.players[1].bench.append(_slot(_pokemon("Charmander", "Basic", "R", 70), 1))
	var options: Array = [
		{
			"source_card": _card(_pokemon("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex"), 0),
			"attack_index": 1,
			"attack": {"name": "Phantom Dive", "cost": "RP", "damage": "200", "is_vstar_power": false},
		},
		{
			"source_card": _card(_pokemon("Hisuian Goodra VSTAR", "VSTAR", "N", 270, "Hisuian Goodra V", "V"), 0),
			"attack_index": 0,
			"attack": {"name": "Rolling Iron", "cost": "GMW", "damage": "200", "is_vstar_power": false},
		},
	]

	var selected: Array = strategy.pick_interaction_items(
		options,
		{"id": "copied_attack", "max_select": 1},
		{"game_state": gs, "player_index": 0}
	)
	var picked := ""
	if not selected.is_empty() and selected[0] is Dictionary:
		var source_card: CardInstance = (selected[0] as Dictionary).get("source_card", null)
		var attack: Dictionary = (selected[0] as Dictionary).get("attack", {})
		if source_card != null and source_card.card_data != null:
			picked = "%s:%s" % [str(source_card.card_data.name_en), str(attack.get("name", ""))]

	return assert_eq(picked, "Hisuian Goodra VSTAR:Rolling Iron", "Into Charizard pressure, Regidrago should take the same 200 HP prize with Goodra protection instead of Dragapult spread")


func test_v17_regidrago_damaged_vstar_still_uses_goodra_for_same_prize_under_charizard_pressure() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(5)
	var vstar := _slot(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V"), 0)
	vstar.damage_counters = 190
	gs.players[0].active_pokemon = vstar
	gs.players[1].active_pokemon = _slot(_pokemon("Charmander", "Basic", "R", 70), 1)
	gs.players[1].bench.append(_slot(_pokemon("Charizard ex", "Stage 2", "D", 330, "Charmeleon", "ex"), 1))
	var options: Array = [
		{
			"source_card": _card(_pokemon("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex"), 0),
			"attack_index": 1,
			"attack": {"name": "Phantom Dive", "cost": "RP", "damage": "200", "is_vstar_power": false},
		},
		{
			"source_card": _card(_pokemon("Hisuian Goodra VSTAR", "VSTAR", "N", 270, "Hisuian Goodra V", "V"), 0),
			"attack_index": 0,
			"attack": {"name": "Rolling Iron", "cost": "GMW", "damage": "200", "is_vstar_power": false},
		},
	]

	var selected: Array = strategy.pick_interaction_items(
		options,
		{"id": "copied_attack", "max_select": 1},
		{"game_state": gs, "player_index": 0}
	)
	var picked := ""
	if not selected.is_empty() and selected[0] is Dictionary:
		var source_card: CardInstance = (selected[0] as Dictionary).get("source_card", null)
		var attack: Dictionary = (selected[0] as Dictionary).get("attack", {})
		if source_card != null and source_card.card_data != null:
			picked = "%s:%s" % [str(source_card.card_data.name_en), str(attack.get("name", ""))]

	return assert_eq(picked, "Hisuian Goodra VSTAR:Rolling Iron", "A damaged Regidrago should still take a same-prize low-HP KO with Goodra protection under Charizard pressure")


func test_v17_regidrago_copied_attack_uses_giratina_to_ko_bulky_active() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(5)
	gs.players[0].active_pokemon = _slot(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V"), 0)
	gs.players[1].active_pokemon = _slot(_pokemon("Iron Hands ex", "Basic", "L", 230, "", "ex"), 1)
	gs.players[1].bench.append(_slot(_pokemon("Miraidon ex", "Basic", "L", 220, "", "ex"), 1))
	gs.players[1].bench.append(_slot(_pokemon("Latias ex", "Basic", "P", 210, "", "ex"), 1))
	var options: Array = [
		{
			"source_card": _card(_pokemon("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex"), 0),
			"attack_index": 1,
			"attack": {"name": "Phantom Dive", "cost": "RP", "damage": "200", "is_vstar_power": false},
		},
		{
			"source_card": _card(_pokemon("Giratina VSTAR", "VSTAR", "N", 280, "Giratina V", "V"), 0),
			"attack_index": 0,
			"attack": {"name": "Lost Impact", "cost": "GPC", "damage": "280", "is_vstar_power": false},
		},
	]

	var selected: Array = strategy.pick_interaction_items(
		options,
		{"id": "copied_attack", "max_select": 1},
		{"game_state": gs, "player_index": 0}
	)
	var picked := ""
	if not selected.is_empty() and selected[0] is Dictionary:
		var source_card: CardInstance = (selected[0] as Dictionary).get("source_card", null)
		var attack: Dictionary = (selected[0] as Dictionary).get("attack", {})
		if source_card != null and source_card.card_data != null:
			picked = "%s:%s" % [str(source_card.card_data.name_en), str(attack.get("name", ""))]

	return assert_eq(picked, "Giratina VSTAR:Lost Impact", "Regidrago should copy Giratina for a 280 KO when Dragapult's 200 would leave a bulky active alive")


func test_v17_regidrago_damaged_vstar_uses_giratina_to_trade_charizard() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(5)
	var vstar := _slot(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V"), 0)
	vstar.damage_counters = 180
	gs.players[0].active_pokemon = vstar
	var charizard := _slot(_pokemon("Charizard ex", "Stage 2", "D", 330, "Charmeleon", "ex"), 1)
	charizard.damage_counters = 60
	gs.players[1].active_pokemon = charizard
	var options: Array = [
		{
			"source_card": _card(_pokemon("Hisuian Goodra VSTAR", "VSTAR", "N", 270, "Hisuian Goodra V", "V"), 0),
			"attack_index": 0,
			"attack": {"name": "Rolling Iron", "cost": "GMW", "damage": "200", "is_vstar_power": false},
		},
		{
			"source_card": _card(_pokemon("Giratina VSTAR", "VSTAR", "N", 280, "Giratina V", "V"), 0),
			"attack_index": 0,
			"attack": {"name": "Lost Impact", "cost": "GPC", "damage": "280", "is_vstar_power": false},
		},
	]

	var selected: Array = strategy.pick_interaction_items(
		options,
		{"id": "copied_attack", "max_select": 1},
		{"game_state": gs, "player_index": 0}
	)
	var picked := ""
	if not selected.is_empty() and selected[0] is Dictionary:
		var source_card: CardInstance = (selected[0] as Dictionary).get("source_card", null)
		var attack: Dictionary = (selected[0] as Dictionary).get("attack", {})
		if source_card != null and source_card.card_data != null:
			picked = "%s:%s" % [str(source_card.card_data.name_en), str(attack.get("name", ""))]

	return assert_eq(picked, "Giratina VSTAR:Lost Impact", "A badly damaged Regidrago VSTAR should trade with Charizard ex via Giratina 280 instead of taking a low-value Goodra 200 hit")


func test_v17_regidrago_uses_giratina_to_pressure_full_charizard_when_goodra_cannot_save() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(5)
	var vstar := _slot(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V"), 0)
	vstar.damage_counters = 190
	gs.players[0].active_pokemon = vstar
	gs.players[1].active_pokemon = _slot(_pokemon("喷火龙ex", "Stage 2", "D", 330, "火恐龙", "ex"), 1)
	var options: Array = [
		{
			"source_card": _card(_pokemon("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex"), 0),
			"attack_index": 1,
			"attack": {"name": "Phantom Dive", "cost": "RP", "damage": "200", "is_vstar_power": false},
		},
		{
			"source_card": _card(_pokemon("Hisuian Goodra VSTAR", "VSTAR", "N", 270, "Hisuian Goodra V", "V"), 0),
			"attack_index": 0,
			"attack": {"name": "Rolling Iron", "cost": "GMW", "damage": "200", "is_vstar_power": false},
		},
		{
			"source_card": _card(_pokemon("Giratina VSTAR", "VSTAR", "N", 280, "Giratina V", "V"), 0),
			"attack_index": 0,
			"attack": {"name": "Lost Impact", "cost": "GPC", "damage": "280", "is_vstar_power": false},
		},
	]

	var selected: Array = strategy.pick_interaction_items(
		options,
		{"id": "copied_attack", "max_select": 1},
		{"game_state": gs, "player_index": 0}
	)
	var picked := ""
	if not selected.is_empty() and selected[0] is Dictionary:
		var source_card: CardInstance = (selected[0] as Dictionary).get("source_card", null)
		var attack: Dictionary = (selected[0] as Dictionary).get("attack", {})
		if source_card != null and source_card.card_data != null:
			picked = "%s:%s" % [str(source_card.card_data.name_en), str(attack.get("name", ""))]

	return assert_eq(picked, "Giratina VSTAR:Lost Impact", "When Goodra cannot save the active, full Charizard should take Giratina's 280 pressure over another 200 hit")


func test_v17_regidrago_boss_converts_dragapult_prize_behind_bulky_active() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(3)
	var player := gs.players[0]
	var vstar := _slot(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V", [
		{"name": "Apex Dragon", "cost": "GGR", "damage": ""},
	], 3), 0)
	_attach(vstar, "G", 2)
	_attach(vstar, "R", 1)
	player.active_pokemon = vstar
	player.discard_pile.append(_card(_pokemon("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex"), 0))
	var boss := _card(_trainer("Boss's Orders", "Supporter"), 0)
	player.hand.append(boss)
	gs.players[1].active_pokemon = _slot(_pokemon("Iron Hands ex", "Basic", "L", 230, "", "ex"), 1)
	var raikou := _slot(_pokemon("Raikou V", "Basic", "L", 200, "", "V"), 1)
	var latias := _slot(_pokemon("Latias ex", "Basic", "P", 210, "", "ex"), 1)
	gs.players[1].bench.append(raikou)
	gs.players[1].bench.append(latias)

	var boss_score: float = strategy.score_action_absolute({
		"kind": "play_trainer",
		"card": boss,
		"targets": [{"opponent_bench_target": [raikou]}],
	}, gs, 0)
	var attack_score: float = strategy.score_action_absolute({
		"kind": "attack",
		"source_slot": vstar,
		"attack_index": 0,
		"attack_name": "Apex Dragon",
	}, gs, 0)
	var raikou_score: float = strategy.score_interaction_target(raikou, {"id": "opponent_bench_target"}, {"game_state": gs, "player_index": 0})
	var latias_score: float = strategy.score_interaction_target(latias, {"id": "opponent_bench_target"}, {"game_state": gs, "player_index": 0})

	return run_checks([
		assert_true(boss_score > attack_score, "Boss should happen before Apex Dragon when it creates a Dragapult KO behind bulky Iron Hands (boss=%f attack=%f)" % [boss_score, attack_score]),
		assert_true(raikou_score > latias_score, "Boss target selection should pull the 200 HP Raikou prize target before a 210 HP support ex (raikou=%f latias=%f)" % [raikou_score, latias_score]),
	])


func test_v17_regidrago_gust_avoids_single_prize_chaff_under_charizard_active() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(8)
	var player := gs.players[0]
	player.prizes.clear()
	for i: int in 3:
		player.prizes.append(_card(_pokemon("Prize %d" % i), 0))
	player.active_pokemon = _slot(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V", [
		{"name": "Apex Dragon", "cost": "GGR", "damage": ""},
	]), 0)
	gs.players[1].active_pokemon = _slot(_pokemon("Charizard ex", "Stage 2", "D", 330, "Charmeleon", "ex"), 1)
	var pidgey := _slot(_pokemon("Pidgey", "Basic", "C", 60), 1)
	var pidgeot := _slot(_pokemon("Pidgeot ex", "Stage 2", "C", 280, "Pidgey", "ex"), 1)
	var pidgey_score: float = strategy.score_interaction_target(pidgey, {"id": "opponent_bench_target"}, {"game_state": gs, "player_index": 0})
	var pidgeot_score: float = strategy.score_interaction_target(pidgeot, {"id": "opponent_bench_target"}, {"game_state": gs, "player_index": 0})
	return run_checks([
		assert_true(pidgey_score < 0.0, "With Charizard active, Boss should not spend the attack on a non-final one-prize Pidgey (score=%f)" % pidgey_score),
		assert_true(pidgeot_score > pidgey_score, "Multi-prize engine targets should remain better than one-prize chaff under Charizard pressure (pidgeot=%f pidgey=%f)" % [pidgeot_score, pidgey_score]),
	])


func test_v17_regidrago_copied_attack_uses_goodra_into_bulky_survival_window() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(7)
	gs.players[0].active_pokemon = _slot(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V"), 0)
	gs.players[1].active_pokemon = _slot(_pokemon("Iron Hands ex", "Basic", "L", 230, "", "ex"), 1)
	var options: Array = [
		{
			"source_card": _card(_pokemon("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex"), 0),
			"attack_index": 1,
			"attack": {"name": "Phantom Dive", "cost": "RP", "damage": "200", "is_vstar_power": false},
		},
		{
			"source_card": _card(_pokemon("Hisuian Goodra VSTAR", "VSTAR", "N", 270, "Hisuian Goodra V", "V"), 0),
			"attack_index": 0,
			"attack": {"name": "Rolling Iron", "cost": "GMW", "damage": "200", "is_vstar_power": false},
		},
	]

	var selected: Array = strategy.pick_interaction_items(
		options,
		{"id": "copied_attack", "max_select": 1},
		{"game_state": gs, "player_index": 0}
	)
	var picked := ""
	if not selected.is_empty() and selected[0] is Dictionary:
		var source_card: CardInstance = (selected[0] as Dictionary).get("source_card", null)
		var attack: Dictionary = (selected[0] as Dictionary).get("attack", {})
		if source_card != null and source_card.card_data != null:
			picked = "%s:%s" % [str(source_card.card_data.name_en), str(attack.get("name", ""))]

	return assert_eq(picked, "Hisuian Goodra VSTAR:Rolling Iron", "Against a 230 HP pressure target, Regidrago should prefer Goodra's Rolling Iron survival line over leaving the active alive with Dragapult")


func test_v17_regidrago_damaged_vstar_refreshes_goodra_protection_when_taking_prize() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(7)
	var vstar := _slot(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V"), 0)
	vstar.damage_counters = 160
	gs.players[0].active_pokemon = vstar
	gs.players[1].active_pokemon = _slot(_pokemon("Iron Hands ex", "Basic", "L", 230, "", "ex"), 1)
	gs.players[1].active_pokemon.damage_counters = 30
	var options: Array = [
		{
			"source_card": _card(_pokemon("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex"), 0),
			"attack_index": 1,
			"attack": {"name": "Phantom Dive", "cost": "RP", "damage": "200", "is_vstar_power": false},
		},
		{
			"source_card": _card(_pokemon("Hisuian Goodra VSTAR", "VSTAR", "N", 270, "Hisuian Goodra V", "V"), 0),
			"attack_index": 0,
			"attack": {"name": "Rolling Iron", "cost": "GMW", "damage": "200", "is_vstar_power": false},
		},
	]

	var selected: Array = strategy.pick_interaction_items(
		options,
		{"id": "copied_attack", "max_select": 1},
		{"game_state": gs, "player_index": 0}
	)
	var picked := ""
	if not selected.is_empty() and selected[0] is Dictionary:
		var source_card: CardInstance = (selected[0] as Dictionary).get("source_card", null)
		var attack: Dictionary = (selected[0] as Dictionary).get("attack", {})
		if source_card != null and source_card.card_data != null:
			picked = "%s:%s" % [str(source_card.card_data.name_en), str(attack.get("name", ""))]

	return assert_eq(picked, "Hisuian Goodra VSTAR:Rolling Iron", "A damaged Regidrago VSTAR that can still take the prize should refresh Goodra protection instead of choosing extra Dragapult spread")


func test_v17_regidrago_scores_alolan_exeggutor_ko_attack_over_setup_attack() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(5)
	gs.players[0].active_pokemon = _slot(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V"), 0)
	gs.players[1].active_pokemon = _slot(_pokemon("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	var alolan := _card(_pokemon("CSV9C_144", "Stage 1", "N", 300, "Exeggcute", "ex", [
		{"name": "Tropical Frenzy", "cost": "GW", "damage": "150"},
		{"name": "Swinging Sphene", "cost": "GWF", "damage": ""},
	], 3, "CSV9C", "144"), 0)
	var selected: Array = strategy.pick_interaction_items(
		[
			{"source_card": alolan, "attack_index": 0, "attack": {"name": "Tropical Frenzy", "cost": "GW", "damage": "150"}},
			{"source_card": alolan, "attack_index": 1, "attack": {"name": "Swinging Sphene", "cost": "GWF", "damage": ""}},
		],
		{"id": "copied_attack", "max_select": 1},
		{"game_state": gs, "player_index": 0}
	)
	var picked_index := -1
	if not selected.is_empty() and selected[0] is Dictionary:
		picked_index = int((selected[0] as Dictionary).get("attack_index", -1))

	return assert_eq(picked_index, 1, "Against Miraidon-style Basic attackers, copied Alolan Exeggutor should choose the KO attack instead of the setup attack")


func test_v17_regidrago_ready_apex_attack_beats_more_search_churn() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(7)
	var player := gs.players[0]
	var active := _slot(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V", [
		{"name": "Apex Dragon", "cost": "GGR", "damage": ""},
	], 3), 0)
	_attach(active, "G", 2)
	_attach(active, "R", 1)
	player.active_pokemon = active
	player.discard_pile.append(_card(_pokemon("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex"), 0))
	var ultra := _card(_trainer("Ultra Ball"), 0)

	var attack_score: float = strategy.score_action_absolute({
		"kind": "attack",
		"attack_index": 0,
		"attack_name": "Apex Dragon",
		"projected_damage": 0,
		"projected_knockout": false,
		"requires_interaction": true,
	}, gs, 0)
	var ultra_score: float = strategy.score_action_absolute({
		"kind": "play_trainer",
		"card": ultra,
		"targets": [{"discard_cards": [], "search_pokemon": []}],
	}, gs, 0)

	return assert_true(attack_score > ultra_score, "A ready Regidrago VSTAR with copied-attack fuel should attack before more search churn (attack=%f ultra=%f)" % [attack_score, ultra_score])


func test_v17_regidrago_continuity_seeds_backup_before_nonfinal_apex() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(5)
	var player := gs.players[0]
	var active := _slot(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V", [
		{"name": "Apex Dragon", "cost": "GGR", "damage": ""},
	], 3), 0)
	_attach(active, "G", 2)
	_attach(active, "R", 1)
	player.active_pokemon = active
	player.bench.append(_slot(_pokemon("Teal Mask Ogerpon ex", "Basic", "G", 210, "", "ex"), 0))
	player.discard_pile.append(_card(_pokemon("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex"), 0))
	for i: int in 4:
		player.prizes.append(_card(_trainer("Prize %d" % i), 0))
	for i: int in 24:
		player.deck.append(_card(_trainer("Deck %d" % i), 0))
	var backup := _card(_pokemon("Regidrago V", "Basic", "N", 220, "", "V"), 0)
	player.hand.append(backup)
	gs.players[1].active_pokemon = _slot(_pokemon("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)

	var turn_contract: Dictionary = strategy.build_turn_contract(gs, 0, {"prompt_kind": "action_selection"})
	var continuity: Dictionary = strategy.build_continuity_contract(gs, 0, turn_contract)
	var setup_debt: Dictionary = continuity.get("setup_debt", {}) as Dictionary
	var bench_score: float = strategy.score_action_absolute_with_plan({
		"kind": "play_basic_to_bench",
		"card": backup,
	}, gs, 0, turn_contract)
	var attack_score: float = strategy.score_action_absolute_with_plan({
		"kind": "attack",
		"source_slot": active,
		"attack_index": 0,
		"attack_name": "Apex Dragon",
		"projected_damage": 200,
		"projected_knockout": false,
	}, gs, 0, turn_contract)

	return run_checks([
		assert_true(bool(continuity.get("enabled", false)), "A ready non-final VSTAR should publish continuity setup before attacking again"),
		assert_true(bool(setup_debt.get("need_backup_regidrago_seed", false)), "Continuity debt should record the missing backup Regidrago line"),
		assert_true(bench_score > attack_score, "Non-final Apex Dragon should pause for a backup Regidrago line when the active VSTAR is already online (bench=%f attack=%f)" % [bench_score, attack_score]),
	])


func test_v17_regidrago_continuity_completes_backup_vstar_before_nonfinal_apex() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(7)
	var player := gs.players[0]
	var active := _slot(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V", [
		{"name": "Apex Dragon", "cost": "GGR", "damage": ""},
	], 3), 0)
	_attach(active, "G", 2)
	_attach(active, "R", 1)
	player.active_pokemon = active
	var backup := _slot(_pokemon("Regidrago V", "Basic", "N", 220, "", "V"), 0)
	player.bench.append(backup)
	player.discard_pile.append(_card(_pokemon("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex"), 0))
	for i: int in 4:
		player.prizes.append(_card(_trainer("Prize %d" % i), 0))
	for i: int in 20:
		player.deck.append(_card(_trainer("Deck %d" % i), 0))
	var vstar := _card(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V", [
		{"name": "Apex Dragon", "cost": "GGR", "damage": ""},
	], 3), 0)
	player.hand.append(vstar)
	gs.players[1].active_pokemon = _slot(_pokemon("Charizard ex", "Stage 2", "R", 330, "Charmeleon", "ex"), 1)

	var turn_contract: Dictionary = strategy.build_turn_contract(gs, 0, {"prompt_kind": "action_selection"})
	var continuity: Dictionary = strategy.build_continuity_contract(gs, 0, turn_contract)
	var setup_debt: Dictionary = continuity.get("setup_debt", {}) as Dictionary
	var evolve_score: float = strategy.score_action_absolute_with_plan({
		"kind": "evolve",
		"card": vstar,
		"target_slot": backup,
	}, gs, 0, turn_contract)
	var attack_score: float = strategy.score_action_absolute_with_plan({
		"kind": "attack",
		"source_slot": active,
		"attack_index": 0,
		"attack_name": "Apex Dragon",
		"projected_damage": 200,
		"projected_knockout": false,
	}, gs, 0, turn_contract)

	return run_checks([
		assert_true(bool(setup_debt.get("need_backup_regidrago_vstar", false)), "Continuity debt should record that the live backup Regidrago V still needs VSTAR"),
		assert_true(evolve_score > attack_score, "Non-final Apex Dragon should complete the backup VSTAR before attacking into Charizard pressure (evolve=%f attack=%f)" % [evolve_score, attack_score]),
	])


func test_v17_regidrago_send_out_buffers_uncharged_drago_into_charizard_pressure() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(8)
	var player := gs.players[0]
	gs.players[1].active_pokemon = _slot(_pokemon("Charizard ex", "Stage 2", "R", 330, "Charmeleon", "ex"), 1)
	var backup_drago := _slot(_pokemon("Regidrago V", "Basic", "N", 220, "", "V", [
		{"name": "Dragon Laser", "cost": "GGR", "damage": "130"},
	], 3), 0)
	_attach(backup_drago, "G", 1)
	var ogerpon := _slot(_pokemon("Teal Mask Ogerpon ex", "Basic", "G", 210, "", "ex", [
		{"name": "Myriad Leaf Shower", "cost": "GCC", "damage": "30"},
	], 1), 0)
	_attach(ogerpon, "G", 1)
	player.bench.clear()
	player.bench.append(backup_drago)
	player.bench.append(ogerpon)
	var context := {"game_state": gs, "player_index": 0, "all_items": player.bench}
	var drago_score: float = strategy.score_handoff_target(backup_drago, {"id": "send_out"}, context)
	var ogerpon_score: float = strategy.score_handoff_target(ogerpon, {"id": "send_out"}, context)
	return assert_true(ogerpon_score > drago_score, "Into Charizard pressure, send-out should buffer with Ogerpon before exposing an uncharged two-prize Regidrago (Ogerpon=%f Regidrago=%f)" % [ogerpon_score, drago_score])


func test_v17_regidrago_send_out_keeps_ready_vstar_into_charizard_pressure() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(8)
	var player := gs.players[0]
	gs.players[1].active_pokemon = _slot(_pokemon("Charizard ex", "Stage 2", "R", 330, "Charmeleon", "ex"), 1)
	var ready_vstar := _slot(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V", [
		{"name": "Apex Dragon", "cost": "GGR", "damage": ""},
	], 3), 0)
	_attach(ready_vstar, "G", 2)
	_attach(ready_vstar, "R", 1)
	var ogerpon := _slot(_pokemon("Teal Mask Ogerpon ex", "Basic", "G", 210, "", "ex", [
		{"name": "Myriad Leaf Shower", "cost": "GCC", "damage": "30"},
	], 1), 0)
	_attach(ogerpon, "G", 1)
	player.bench.clear()
	player.bench.append(ready_vstar)
	player.bench.append(ogerpon)
	player.discard_pile.append(_card(_pokemon("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex"), 0))
	var context := {"game_state": gs, "player_index": 0, "all_items": player.bench}
	var vstar_score: float = strategy.score_handoff_target(ready_vstar, {"id": "send_out"}, context)
	var ogerpon_score: float = strategy.score_handoff_target(ogerpon, {"id": "send_out"}, context)
	return assert_true(vstar_score > ogerpon_score, "A ready fueled Regidrago VSTAR should still be sent out before Ogerpon (VSTAR=%f Ogerpon=%f)" % [vstar_score, ogerpon_score])


func test_v17_regidrago_continuity_keeps_final_prize_apex_first() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(9)
	var player := gs.players[0]
	var active := _slot(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V", [
		{"name": "Apex Dragon", "cost": "GGR", "damage": ""},
	], 3), 0)
	_attach(active, "G", 2)
	_attach(active, "R", 1)
	player.active_pokemon = active
	player.bench.append(_slot(_pokemon("Teal Mask Ogerpon ex", "Basic", "G", 210, "", "ex"), 0))
	player.discard_pile.append(_card(_pokemon("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex"), 0))
	player.prizes.append(_card(_trainer("Last Prize"), 0))
	for i: int in 18:
		player.deck.append(_card(_trainer("Deck %d" % i), 0))
	var backup := _card(_pokemon("Regidrago V", "Basic", "N", 220, "", "V"), 0)
	player.hand.append(backup)
	gs.players[1].active_pokemon = _slot(_pokemon("Miraidon ex", "Basic", "L", 200, "", "ex"), 1)

	var turn_contract: Dictionary = strategy.build_turn_contract(gs, 0, {"prompt_kind": "action_selection"})
	var continuity: Dictionary = strategy.build_continuity_contract(gs, 0, turn_contract)
	var bench_score: float = strategy.score_action_absolute_with_plan({
		"kind": "play_basic_to_bench",
		"card": backup,
	}, gs, 0, turn_contract)
	var attack_score: float = strategy.score_action_absolute_with_plan({
		"kind": "attack",
		"source_slot": active,
		"attack_index": 0,
		"attack_name": "Apex Dragon",
		"projected_damage": 200,
		"projected_knockout": true,
	}, gs, 0, turn_contract)

	return run_checks([
		assert_false(bool(continuity.get("enabled", false)), "Continuity setup should not delay a final-prize Apex Dragon"),
		assert_true(attack_score > bench_score, "Final-prize Apex Dragon must stay ahead of backup setup (attack=%f bench=%f)" % [attack_score, bench_score]),
	])


func test_v17_regidrago_super_rod_keeps_dragon_fuel_in_discard() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(7)
	var player := gs.players[0]
	player.active_pokemon = _slot(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V"), 0)
	var grass := _card(_energy("Grass Energy", "G"), 0)
	var fire := _card(_energy("Fire Energy", "R"), 0)
	var dragapult := _card(_pokemon("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex"), 0)
	player.discard_pile.append_array([grass, fire, dragapult])

	var selected: Array = strategy.pick_interaction_items(
		[grass, fire, dragapult],
		{"id": "cards_to_return", "max_select": 2},
		{"game_state": gs, "player_index": 0}
	)
	var selected_names := _names(selected)

	return run_checks([
		assert_true("Grass Energy" in selected_names, "Super Rod should recover useful energy before dragon attack fuel"),
		assert_true("Fire Energy" in selected_names, "Super Rod should recover missing Regidrago energy before dragon attack fuel"),
		assert_false("Dragapult ex" in selected_names, "Super Rod should leave Dragapult ex in discard for Apex Dragon"),
	])


func test_v17_regidrago_star_legacy_recovers_energy_switch_bridge_before_backup_seed_when_new_vstar_needs_energy() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(7)
	var player := gs.players[0]
	var vstar := _slot(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V", [
		{"name": "Apex Dragon", "cost": "GGR", "damage": ""},
	], 3), 0)
	var ogerpon := _slot(_pokemon("Teal Mask Ogerpon ex", "Basic", "G", 210, "", "ex"), 0)
	var ogerpon_grass := _card(_energy("Ogerpon Grass", "G"), 0)
	ogerpon.attached_energy.append(ogerpon_grass)
	player.active_pokemon = vstar
	player.bench.append(ogerpon)
	player.discard_pile.append(_card(_pokemon("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex"), 0))
	var backup_v := _card(_pokemon("Regidrago V", "Basic", "N", 220, "", "V"), 0)
	var fire := _card(_energy("Fire Energy", "R"), 0)
	var energy_switch := _card(_trainer("Energy Switch"), 0)

	var selected: Array = strategy.pick_interaction_items(
		[backup_v, fire, energy_switch],
		{"id": "recover_cards", "max_select": 2},
		{"game_state": gs, "player_index": 0}
	)
	var selected_names := _names(selected)

	return run_checks([
		assert_true("Energy Switch" in selected_names, "Star Legacy should recover Energy Switch when it bridges Ogerpon Grass into the new VSTAR"),
		assert_true("Fire Energy" in selected_names, "Star Legacy should recover the missing Fire before a backup seed when the active VSTAR is not attacking yet"),
		assert_false("Regidrago V" in selected_names, "Backup seed should wait until the active VSTAR can attack again"),
	])


func test_v17_regidrago_star_legacy_recovers_backup_vstar_when_backup_v_is_benched() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(8)
	var player := gs.players[0]
	var active := _slot(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V", [
		{"name": "Apex Dragon", "cost": "GGR", "damage": ""},
	], 3), 0)
	_attach(active, "G", 2)
	_attach(active, "R", 1)
	player.active_pokemon = active
	player.bench.append(_slot(_pokemon("Regidrago V", "Basic", "N", 220, "", "V"), 0))
	player.discard_pile.append(_card(_pokemon("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex"), 0))
	var backup_vstar := _card(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V"), 0)
	var grass := _card(_energy("Grass Energy", "G"), 0)
	var goodra := _card(_pokemon("Hisuian Goodra VSTAR", "VSTAR", "N", 270, "Hisuian Goodra V", "V"), 0)

	var selected: Array = strategy.pick_interaction_items(
		[grass, goodra, backup_vstar],
		{"id": "recover_cards", "max_select": 2},
		{"game_state": gs, "player_index": 0}
	)
	var selected_names := _names(selected)

	return run_checks([
		assert_true("Regidrago VSTAR" in selected_names, "Star Legacy should recover backup VSTAR when a backup Regidrago V is already benched"),
		assert_false("Hisuian Goodra VSTAR" in selected_names, "Star Legacy should not recover Dragon fuel over a live backup evolution"),
	])


func test_v17_regidrago_blocks_recovering_only_dragon_fuel() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(3)
	var player := gs.players[0]
	player.active_pokemon = _slot(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V"), 0)
	var stretcher := _card(_trainer("Night Stretcher"), 0)
	var goodra := _card(_pokemon("Hisuian Goodra VSTAR", "VSTAR", "N", 270, "Hisuian Goodra V", "V"), 0)

	var bad_recover_score: float = strategy.score_action_absolute({
		"kind": "play_trainer",
		"card": stretcher,
		"targets": [{"night_stretcher_choice": [goodra]}],
	}, gs, 0)
	var end_score: float = strategy.score_action_absolute({"kind": "end_turn"}, gs, 0)

	return assert_true(bad_recover_score < end_score, "Night Stretcher should not recover the only selected Dragon fuel out of discard (recover=%f end=%f)" % [bad_recover_score, end_score])


func test_v17_regidrago_uses_opening_squawk_after_search_before_bad_recover() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(1)
	var player := gs.players[0]
	player.active_pokemon = _slot(_pokemon("Squawkabilly ex", "Basic", "N", 160, "", "ex"), 0)
	player.bench.append(_slot(_pokemon("Regidrago V", "Basic", "N", 220, "", "V"), 0))
	for i: int in 30:
		player.deck.append(_card(_trainer("Filler %d" % i), 0))
	var squawk_score: float = strategy.score_action_absolute({
		"kind": "use_ability",
		"source_slot": player.active_pokemon,
		"ability_index": 0,
	}, gs, 0)
	var stretcher_score: float = strategy.score_action_absolute({
		"kind": "play_trainer",
		"card": _card(_trainer("Night Stretcher"), 0),
		"targets": [{"night_stretcher_choice": [_card(_pokemon("Hisuian Goodra VSTAR", "VSTAR", "N", 270, "Hisuian Goodra V", "V"), 0)]}],
	}, gs, 0)

	return assert_true(squawk_score > stretcher_score, "Opening Squawkabilly should rebuild the hand before bad Dragon-fuel recovery (squawk=%f recover=%f)" % [squawk_score, stretcher_score])


func test_v17_regidrago_nest_ball_rejects_benched_dragon_fuel() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(5)
	var player := gs.players[0]
	player.active_pokemon = _slot(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V"), 0)
	player.bench.append(_slot(_pokemon("Regidrago V", "Basic", "N", 220, "", "V"), 0))
	player.bench.append(_slot(_pokemon("Teal Mask Ogerpon ex", "Basic", "G", 210, "", "ex"), 0))
	var kyurem := _card(_pokemon("CSV9C_147", "Basic", "N", 130, "", "", [], 1, "CSV9C", "147"), 0)
	var ogerpon := _card(_pokemon("Teal Mask Ogerpon ex", "Basic", "G", 210, "", "ex"), 0)
	var nest := _card(_trainer("Nest Ball"), 0)

	var selected: Array = strategy.pick_interaction_items(
		[kyurem, ogerpon],
		{"id": "basic_pokemon", "max_select": 1},
		{"game_state": gs, "player_index": 0}
	)
	var selected_names := _names(selected)
	var bad_nest_score: float = strategy.score_action_absolute({
		"kind": "play_trainer",
		"card": nest,
		"targets": [{"basic_pokemon": [kyurem]}],
	}, gs, 0)

	return run_checks([
		assert_eq(selected_names, ["Teal Mask Ogerpon ex"], "Nest Ball target scoring should prefer Ogerpon over benching a dragon fuel card"),
		assert_true(bad_nest_score < -100.0, "A Nest Ball line with only dragon fuel targets should lose to ending the turn (score=%f)" % bad_nest_score),
	])


func test_v17_regidrago_does_not_bench_hawlucha_as_setup_padding() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(5)
	var hawlucha := _card(_pokemon("Hawlucha", "Basic", "F", 70), 0)

	var bench_score: float = strategy.score_action_absolute({"kind": "play_basic_to_bench", "card": hawlucha}, gs, 0)
	var end_score: float = strategy.score_action_absolute({"kind": "end_turn"}, gs, 0)

	return assert_true(bench_score < end_score, "Hawlucha should not take a bench slot as generic setup padding (bench=%f end=%f)" % [bench_score, end_score])


func test_v17_regidrago_does_not_pivot_resources_into_radiant_charizard_while_regidrago_line_exists() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(10)
	var player := gs.players[0]
	player.active_pokemon = _slot(_pokemon("Regidrago V", "Basic", "N", 220, "", "V"), 0)
	var radiant := _slot(_pokemon("Radiant Charizard", "Basic", "R", 160, "", "Radiant"), 0)
	player.bench.append(radiant)
	var radiant_card := _card(_pokemon("Radiant Charizard", "Basic", "R", 160, "", "Radiant"), 0)
	var grass := _card(_energy("Grass Energy", "G"), 0)

	var bench_score: float = strategy.score_action_absolute({"kind": "play_basic_to_bench", "card": radiant_card}, gs, 0)
	var attach_score: float = strategy.score_action_absolute({"kind": "attach_energy", "card": grass, "target_slot": radiant}, gs, 0)
	var end_score: float = strategy.score_action_absolute({"kind": "end_turn"}, gs, 0)

	return run_checks([
		assert_true(bench_score < end_score, "Radiant Charizard should not take setup space while a Regidrago line exists (bench=%f end=%f)" % [bench_score, end_score]),
		assert_true(attach_score < end_score, "Grass Energy should not be attached to Radiant Charizard while a Regidrago line exists (attach=%f end=%f)" % [attach_score, end_score]),
	])


func test_v17_regidrago_energy_switch_does_not_drain_regidrago() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(3)
	var player := gs.players[0]
	var drago := _slot(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V"), 0)
	var ogerpon := _slot(_pokemon("Teal Mask Ogerpon ex", "Basic", "G", 210, "", "ex"), 0)
	var drago_grass := _card(_energy("Drago Grass", "G"), 0)
	var ogerpon_grass := _card(_energy("Ogerpon Grass", "G"), 0)
	drago.attached_energy.append(drago_grass)
	ogerpon.attached_energy.append(ogerpon_grass)
	player.active_pokemon = drago
	player.bench.append(ogerpon)
	player.hand.append(_card(_trainer("Energy Switch"), 0))

	var selected: Array = strategy.pick_interaction_items(
		[drago_grass, ogerpon_grass],
		{"id": "energy_assignment", "max_select": 1},
		{"game_state": gs, "player_index": 0}
	)
	var selected_names := _names(selected)

	return run_checks([
		assert_eq(selected_names, ["Ogerpon Grass"], "Energy Switch should use Ogerpon's Grass before draining Regidrago's required energy"),
	])


func test_v17_regidrago_energy_switch_completes_t2_apex_before_churn() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(3)
	var player := gs.players[0]
	var vstar := _slot(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V", [
		{"name": "Apex Dragon", "cost": "GGR", "damage": ""},
	], 3), 0)
	var ogerpon := _slot(_pokemon("Teal Mask Ogerpon ex", "Basic", "G", 210, "", "ex"), 0)
	var drago_fire := _card(_energy("Drago Fire", "R"), 0)
	var drago_grass := _card(_energy("Drago Grass", "G"), 0)
	var ogerpon_grass := _card(_energy("Ogerpon Grass", "G"), 0)
	vstar.attached_energy.append_array([drago_fire, drago_grass])
	ogerpon.attached_energy.append(ogerpon_grass)
	player.active_pokemon = vstar
	player.bench.append(ogerpon)
	player.discard_pile.append(_card(_pokemon("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex"), 0))
	var energy_switch := _card(_trainer("Energy Switch"), 0)
	var iono := _card(_trainer("Iono", "Supporter"), 0)
	player.hand.append_array([energy_switch, iono])

	var switch_score: float = strategy.score_action_absolute({
		"kind": "play_trainer",
		"card": energy_switch,
		"targets": [{"energy_assignment": [{"source": ogerpon_grass, "target": vstar}]}],
	}, gs, 0)
	var iono_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": iono}, gs, 0)
	var end_score: float = strategy.score_action_absolute({"kind": "end_turn"}, gs, 0)
	var source_pick: Array = strategy.pick_interaction_items(
		[drago_fire, drago_grass, ogerpon_grass],
		{"id": "energy_assignment", "max_select": 1},
		{"game_state": gs, "player_index": 0}
	)
	var target_pick: Array = strategy.pick_interaction_items(
		[ogerpon, vstar],
		{"id": "energy_assignment", "max_select": 1},
		{"game_state": gs, "player_index": 0, "source_card": ogerpon_grass}
	)

	return run_checks([
		assert_true(switch_score > iono_score, "T2 Energy Switch completing Apex Dragon should beat Iono churn (switch=%f iono=%f)" % [switch_score, iono_score]),
		assert_true(switch_score > end_score, "T2 Energy Switch completing Apex Dragon should not lose to ending the turn (switch=%f end=%f)" % [switch_score, end_score]),
		assert_eq(_names(source_pick), ["Ogerpon Grass"], "Energy Switch should move the Ogerpon Grass that completes GGR"),
		assert_eq(_slot_names(target_pick), ["Regidrago VSTAR"], "Energy Switch should target the active Regidrago VSTAR when that completes GGR"),
	])


func test_v17_regidrago_launch_bridge_scores_energy_before_bad_ultra_ball() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(1)
	var player := gs.players[0]
	var drago := _slot(_pokemon("Regidrago V", "Basic", "N", 220, "", "V", [
		{"name": "Celestial Roar", "cost": "C", "damage": ""},
		{"name": "Dragon Laser", "cost": "GGR", "damage": "130"},
	], 3), 0)
	var ogerpon := _slot(_pokemon("Teal Mask Ogerpon ex", "Basic", "G", 210, "", "ex"), 0)
	var ogerpon_grass := _card(_energy("Ogerpon Grass", "G"), 0)
	ogerpon.attached_energy.append(ogerpon_grass)
	player.active_pokemon = drago
	player.bench.append(ogerpon)
	var fire := _card(_energy("Fire Energy", "R"), 0)
	var energy_switch := _card(_trainer("Energy Switch"), 0)
	var ultra := _card(_trainer("Ultra Ball"), 0)
	var dragapult := _card(_pokemon("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex"), 0)
	var vstar := _card(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V"), 0)
	player.hand.append_array([fire, energy_switch, ultra, dragapult, _card(_trainer("Professor's Research", "Supporter"), 0)])

	var switch_score: float = strategy.score_action_absolute({
		"kind": "play_trainer",
		"card": energy_switch,
		"targets": [{"energy_assignment": [{"source": ogerpon_grass, "target": drago}]}],
	}, gs, 0)
	var fire_score: float = strategy.score_action_absolute({"kind": "attach_energy", "card": fire, "target_slot": drago}, gs, 0)
	var bad_ultra_score: float = strategy.score_action_absolute({
		"kind": "play_trainer",
		"card": ultra,
		"targets": [{"discard_cards": [energy_switch, fire], "search_pokemon": [vstar]}],
	}, gs, 0)

	return run_checks([
		assert_true(switch_score > bad_ultra_score, "T1 Energy Switch bridge should beat Ultra Ball lines that discard the bridge (switch=%f ultra=%f)" % [switch_score, bad_ultra_score]),
		assert_true(fire_score > bad_ultra_score, "T1 Fire attach should beat Ultra Ball lines that discard required Fire (fire=%f ultra=%f)" % [fire_score, bad_ultra_score]),
	])


func test_v17_regidrago_active_ogerpon_keeps_last_retreat_energy_before_handoff() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(2)
	var player := gs.players[0]
	var ogerpon := _slot(_pokemon("Teal Mask Ogerpon ex", "Basic", "G", 210, "", "ex", [
		{"name": "Myriad Leaf Shower", "cost": "GGG", "damage": "30+"},
	], 1), 0)
	var ogerpon_grass := _card(_energy("Ogerpon Grass", "G"), 0)
	ogerpon.attached_energy.append(ogerpon_grass)
	var drago := _slot(_pokemon("Regidrago V", "Basic", "N", 220, "", "V", [
		{"name": "Celestial Roar", "cost": "C", "damage": ""},
		{"name": "Dragon Laser", "cost": "GGR", "damage": "130"},
	], 3), 0)
	_attach(drago, "R", 1)
	player.active_pokemon = ogerpon
	player.bench.append(drago)
	var energy_switch := _card(_trainer("Energy Switch"), 0)

	var switch_score: float = strategy.score_action_absolute({
		"kind": "play_trainer",
		"card": energy_switch,
		"targets": [{"energy_assignment": [{"source": ogerpon_grass, "target": drago}]}],
	}, gs, 0)
	var end_score: float = strategy.score_action_absolute({"kind": "end_turn"}, gs, 0)

	return assert_true(switch_score < end_score, "Active Ogerpon should not donate its only retreat Energy before the Regidrago handoff turn (switch=%f end=%f)" % [switch_score, end_score])


func test_v17_regidrago_active_ogerpon_can_spare_extra_grass_for_ready_handoff() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(4)
	var player := gs.players[0]
	var ogerpon := _slot(_pokemon("Teal Mask Ogerpon ex", "Basic", "G", 210, "", "ex", [
		{"name": "Myriad Leaf Shower", "cost": "GGG", "damage": "30+"},
	], 1), 0)
	var first_grass := _card(_energy("Ogerpon Grass 1", "G"), 0)
	var second_grass := _card(_energy("Ogerpon Grass 2", "G"), 0)
	ogerpon.attached_energy.append_array([first_grass, second_grass])
	var vstar := _slot(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V", [
		{"name": "Apex Dragon", "cost": "GGR", "damage": ""},
	], 3), 0)
	_attach(vstar, "R", 1)
	_attach(vstar, "G", 1)
	player.active_pokemon = ogerpon
	player.bench.append(vstar)
	player.discard_pile.append(_card(_pokemon("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex"), 0))
	var energy_switch := _card(_trainer("Energy Switch"), 0)

	var switch_score: float = strategy.score_action_absolute({
		"kind": "play_trainer",
		"card": energy_switch,
		"targets": [{"energy_assignment": [{"source": first_grass, "target": vstar}]}],
	}, gs, 0)
	ogerpon.attached_energy.erase(first_grass)
	vstar.attached_energy.append(first_grass)
	var retreat_score: float = strategy.score_action_absolute({
		"kind": "retreat",
		"bench_target": vstar,
		"energy_to_discard": [second_grass],
	}, gs, 0)
	var end_score: float = strategy.score_action_absolute({"kind": "end_turn"}, gs, 0)

	return run_checks([
		assert_true(switch_score > end_score, "Once active Ogerpon has spare Energy, Energy Switch should complete GGR for Regidrago (switch=%f end=%f)" % [switch_score, end_score]),
		assert_true(retreat_score > end_score, "After preserving a retreat Energy, Ogerpon should hand off to ready Regidrago VSTAR (retreat=%f end=%f)" % [retreat_score, end_score]),
	])


func test_v17_regidrago_preserves_ready_ultra_ball_line_over_squawk() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(1)
	var player := gs.players[0]
	player.active_pokemon = _slot(_pokemon("Regidrago V", "Basic", "N", 220, "", "V"), 0)
	var squawk_slot := _slot(_pokemon("Squawkabilly ex", "Basic", "C", 160, "", "ex"), 0)
	player.bench.append(squawk_slot)
	var ultra := _card(_trainer("Ultra Ball"), 0)
	var dragapult := _card(_pokemon("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex"), 0)
	var research := _card(_trainer("Professor's Research", "Supporter"), 0)
	var vstar := _card(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V"), 0)
	player.hand.append_array([ultra, dragapult, research])

	var squawk_score: float = strategy.score_action_absolute({"kind": "use_ability", "source_slot": squawk_slot, "ability_index": 0}, gs, 0)
	var ultra_score: float = strategy.score_action_absolute({
		"kind": "play_trainer",
		"card": ultra,
		"targets": [{"discard_cards": [dragapult, research], "search_pokemon": [vstar]}],
	}, gs, 0)

	return assert_true(ultra_score > squawk_score, "When Ultra Ball can discard Dragapult and fetch VSTAR, Squawk should not wipe the route (ultra=%f squawk=%f)" % [ultra_score, squawk_score])


func test_v17_regidrago_ends_instead_of_squawk_when_launch_bridge_is_ready() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(1)
	var player := gs.players[0]
	var drago := _slot(_pokemon("Regidrago V", "Basic", "N", 220, "", "V"), 0)
	_attach(drago, "G", 1)
	_attach(drago, "R", 1)
	player.active_pokemon = drago
	var squawk_slot := _slot(_pokemon("Squawkabilly ex", "Basic", "C", 160, "", "ex"), 0)
	player.bench.append(squawk_slot)
	player.discard_pile.append(_card(_pokemon("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex"), 0))
	player.hand.append_array([
		_card(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V"), 0),
		_card(_energy("Grass Energy", "G"), 0),
	])

	var squawk_score: float = strategy.score_action_absolute({"kind": "use_ability", "source_slot": squawk_slot, "ability_index": 0}, gs, 0)
	var end_score: float = strategy.score_action_absolute({"kind": "end_turn"}, gs, 0)

	return assert_true(end_score > squawk_score, "Once VSTAR plus T2 Grass are preserved, Squawk must not discard the launch bridge (end=%f squawk=%f)" % [end_score, squawk_score])


func test_v17_regidrago_star_legacy_yields_to_t2_manual_attack_completion() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(3)
	gs.energy_attached_this_turn = false
	var player := gs.players[0]
	var vstar := _slot(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V", [
		{"name": "Apex Dragon", "cost": "GGR", "damage": ""},
	], 3), 0)
	_attach(vstar, "G", 1)
	_attach(vstar, "R", 1)
	player.active_pokemon = vstar
	player.discard_pile.append(_card(_pokemon("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex"), 0))
	var grass := _card(_energy("Grass Energy", "G"), 0)
	player.hand.append(grass)
	for i: int in 25:
		player.deck.append(_card(_trainer("Filler %d" % i), 0))

	var star_score: float = strategy.score_action_absolute({"kind": "use_ability", "source_slot": vstar, "ability_index": 0}, gs, 0)
	var attach_score: float = strategy.score_action_absolute({"kind": "attach_energy", "card": grass, "target_slot": vstar}, gs, 0)

	return assert_true(attach_score > star_score, "With Dragapult already in discard, T2 manual Grass should complete Apex Dragon before Star Legacy churn (attach=%f star=%f)" % [attach_score, star_score])


func test_v17_regidrago_blocks_energy_switch_that_strands_ready_bench_vstar() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(3)
	var player := gs.players[0]
	var ogerpon := _slot(_pokemon("Teal Mask Ogerpon ex", "Basic", "G", 210, "", "ex"), 0)
	var vstar := _slot(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V", [
		{"name": "Apex Dragon", "cost": "GGR", "damage": ""},
	], 3), 0)
	_attach(vstar, "G", 2)
	_attach(vstar, "R", 1)
	player.active_pokemon = ogerpon
	player.bench.append(vstar)
	player.discard_pile.append(_card(_pokemon("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex"), 0))
	var switch_card := _card(_trainer("Energy Switch"), 0)
	var fire_energy: CardInstance = vstar.attached_energy[2]
	var bad_switch_score: float = strategy.score_action_absolute({
		"kind": "play_trainer",
		"card": switch_card,
		"targets": [{"energy_assignment": [{"source": fire_energy, "target": ogerpon}]}],
	}, gs, 0)
	var end_score: float = strategy.score_action_absolute({"kind": "end_turn"}, gs, 0)

	return assert_true(bad_switch_score < end_score, "Energy Switch must not move required Regidrago attack Energy onto the trapped support active (switch=%f end=%f)" % [bad_switch_score, end_score])


func test_v17_regidrago_uses_switch_to_escape_bossed_ogerpon_for_ready_vstar() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(3)
	var player := gs.players[0]
	var ogerpon := _slot(_pokemon("Teal Mask Ogerpon ex", "Basic", "G", 210, "", "ex"), 0)
	var vstar := _slot(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V", [
		{"name": "Apex Dragon", "cost": "GGR", "damage": ""},
	], 3), 0)
	_attach(vstar, "G", 2)
	_attach(vstar, "R", 1)
	player.active_pokemon = ogerpon
	player.bench.append(vstar)
	player.discard_pile.append(_card(_pokemon("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex"), 0))
	var switch_card := _card(_trainer("Switch"), 0)
	var ultra := _card(_trainer("Ultra Ball"), 0)

	var switch_score: float = strategy.score_action_absolute({
		"kind": "play_trainer",
		"card": switch_card,
		"targets": [{"self_switch_target": [vstar]}],
	}, gs, 0)
	var ultra_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": ultra}, gs, 0)
	var picked: Array = strategy.pick_interaction_items(
		[ogerpon, vstar],
		{"id": "self_switch_target", "max_select": 1},
		{"game_state": gs, "player_index": 0}
	)

	return run_checks([
		assert_true(switch_score > ultra_score, "Switch should be the conversion action when Boss leaves Ogerpon active and ready Regidrago VSTAR on bench (switch=%f ultra=%f)" % [switch_score, ultra_score]),
		assert_eq(picked, [vstar], "Switch target selection should promote the ready Regidrago VSTAR, not leave the support Pokemon active"),
	])


func test_v17_regidrago_star_legacy_recovers_switch_when_boss_traps_support_active() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(3)
	var player := gs.players[0]
	var ogerpon := _slot(_pokemon("Teal Mask Ogerpon ex", "Basic", "G", 210, "", "ex"), 0)
	var vstar := _slot(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V", [
		{"name": "Apex Dragon", "cost": "GGR", "damage": ""},
	], 3), 0)
	_attach(vstar, "G", 2)
	_attach(vstar, "R", 1)
	player.active_pokemon = ogerpon
	player.bench.append(vstar)
	player.discard_pile.append(_card(_pokemon("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex"), 0))
	var switch_card := _card(_trainer("Switch"), 0)
	var energy_switch := _card(_trainer("Energy Switch"), 0)
	var ultra := _card(_trainer("Ultra Ball"), 0)

	var star_score: float = strategy.score_action_absolute({"kind": "use_ability", "source_slot": vstar, "ability_index": 0}, gs, 0)
	var end_score: float = strategy.score_action_absolute({"kind": "end_turn"}, gs, 0)
	var picked: Array = strategy.pick_interaction_items(
		[switch_card, energy_switch, ultra],
		{"id": "recover_cards", "max_select": 1},
		{"game_state": gs, "player_index": 0}
	)

	return run_checks([
		assert_true(star_score > end_score, "When Ogerpon is trapped in front of a ready bench VSTAR, Star Legacy should dig for an escape card instead of ending (star=%f end=%f)" % [star_score, end_score]),
		assert_eq(_names(picked), ["Switch"], "Star Legacy recovery should prefer Switch over more Energy Switch/Ultra Ball churn in the Boss-trap conversion window"),
	])


func test_v17_regidrago_retreats_support_into_ready_vstar_before_churn() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(13)
	var player := gs.players[0]
	var active := _slot(_pokemon("CSV9C_147", "Basic", "N", 130, "", "", [], 2, "CSV9C", "147"), 0)
	var vstar := _slot(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V", [
		{"name": "Apex Dragon", "cost": "GGR", "damage": ""},
	], 3), 0)
	_attach(active, "G", 2)
	_attach(vstar, "G", 2)
	_attach(vstar, "R", 1)
	player.active_pokemon = active
	player.bench.append(vstar)
	var ultra := _card(_trainer("Ultra Ball"), 0)
	var research := _card(_trainer("Professor's Research", "Supporter"), 0)
	var dragapult := _card(_pokemon("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex"), 0)
	player.hand.append_array([ultra, research, dragapult])
	player.discard_pile.append(_card(_pokemon("Giratina VSTAR", "VSTAR", "N", 280, "Giratina V", "V"), 0))
	for i: int in 18:
		player.deck.append(_card(_trainer("Filler %d" % i), 0))

	var retreat_score: float = strategy.score_action_absolute({
		"kind": "retreat",
		"bench_target": vstar,
		"energy_to_discard": active.attached_energy.duplicate(),
	}, gs, 0)
	var ultra_score: float = strategy.score_action_absolute({
		"kind": "play_trainer",
		"card": ultra,
		"targets": [{"discard_cards": [dragapult, research], "search_pokemon": []}],
	}, gs, 0)
	var end_score: float = strategy.score_action_absolute({"kind": "end_turn"}, gs, 0)

	return run_checks([
		assert_true(retreat_score > ultra_score, "Once a ready Regidrago VSTAR is on the bench, retreating into it should beat more Ultra Ball churn (retreat=%f ultra=%f)" % [retreat_score, ultra_score]),
		assert_true(retreat_score > end_score, "Ready Regidrago VSTAR handoff should not lose to ending the turn (retreat=%f end=%f)" % [retreat_score, end_score]),
	])


func test_v17_regidrago_second_player_also_retreats_support_into_ready_vstar() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(13)
	gs.current_player_index = 1
	gs.first_player_index = 0
	var player := gs.players[1]
	var active := _slot(_pokemon("CSV9C_147", "Basic", "N", 130, "", "", [], 2, "CSV9C", "147"), 1)
	var vstar := _slot(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V", [
		{"name": "Apex Dragon", "cost": "GGR", "damage": ""},
	], 3), 1)
	_attach(active, "G", 2)
	_attach(vstar, "G", 2)
	_attach(vstar, "R", 1)
	player.active_pokemon = active
	player.bench.append(vstar)
	var ultra := _card(_trainer("Ultra Ball"), 1)
	var research := _card(_trainer("Professor's Research", "Supporter"), 1)
	var dragapult := _card(_pokemon("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex"), 1)
	player.hand.append_array([ultra, research, dragapult])
	player.discard_pile.append(_card(_pokemon("Giratina VSTAR", "VSTAR", "N", 280, "Giratina V", "V"), 1))
	for i: int in 18:
		player.deck.append(_card(_trainer("Filler %d" % i), 1))

	var retreat_score: float = strategy.score_action_absolute({
		"kind": "retreat",
		"bench_target": vstar,
		"energy_to_discard": active.attached_energy.duplicate(),
	}, gs, 1)
	var ultra_score: float = strategy.score_action_absolute({
		"kind": "play_trainer",
		"card": ultra,
		"targets": [{"discard_cards": [dragapult, research], "search_pokemon": []}],
	}, gs, 1)

	return assert_true(retreat_score > ultra_score, "Second-player support actives should also retreat into ready Regidrago VSTAR once conversion is available (retreat=%f ultra=%f)" % [retreat_score, ultra_score])


func test_v17_regidrago_charizard_pressure_blocks_ogerpon_retreat_to_mew() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(8)
	var player := gs.players[0]
	var active := _slot(_pokemon("Teal Mask Ogerpon ex", "Basic", "G", 210, "", "ex", [
		{"name": "Myriad Leaf Shower", "cost": "GGG", "damage": "30+"},
	], 1), 0)
	var mew := _slot(_pokemon("Mew ex", "Basic", "P", 180, "", "ex", [
		{"name": "Genome Hacking", "cost": "CCC", "damage": ""},
	], 1), 0)
	var unready_vstar := _slot(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V", [
		{"name": "Apex Dragon", "cost": "GGR", "damage": ""},
	], 3), 0)
	_attach(active, "G", 1)
	player.active_pokemon = active
	player.bench.append(mew)
	player.bench.append(unready_vstar)
	gs.players[1].active_pokemon = _slot(_pokemon("Charizard ex", "Stage 2", "D", 330, "Charmeleon", "ex", [
		{"name": "Burning Darkness", "cost": "RR", "damage": "180+"},
	]), 1)

	var retreat_score: float = strategy.score_action_absolute({
		"kind": "retreat",
		"bench_target": mew,
		"energy_to_discard": active.attached_energy.duplicate(),
	}, gs, 0)
	var unready_vstar_score: float = strategy.score_action_absolute({
		"kind": "retreat",
		"bench_target": unready_vstar,
		"energy_to_discard": active.attached_energy.duplicate(),
	}, gs, 0)
	var end_score: float = strategy.score_action_absolute({"kind": "end_turn"}, gs, 0)

	return run_checks([
		assert_true(retreat_score < end_score, "Ogerpon should not burn energy to promote Mew ex into Charizard (retreat=%f end=%f)" % [retreat_score, end_score]),
		assert_true(unready_vstar_score < end_score, "Ogerpon should not retreat into an unready Regidrago VSTAR under Charizard pressure (retreat=%f end=%f)" % [unready_vstar_score, end_score]),
	])


func test_v17_regidrago_late_ogerpon_retreat_to_squawk_is_harder_blocked_than_end() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(6)
	var player := gs.players[0]
	var active := _slot(_pokemon("Teal Mask Ogerpon ex", "Basic", "G", 210, "", "ex"), 0)
	_attach(active, "G", 1)
	player.active_pokemon = active
	player.bench.append(_slot(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V"), 0))
	var squawk := _slot(_pokemon("Squawkabilly ex", "Basic", "C", 160, "", "ex"), 0)
	player.bench.append(squawk)

	var retreat_score: float = strategy.score_action_absolute({
		"kind": "retreat",
		"bench_target": squawk,
		"energy_to_discard": active.attached_energy.duplicate(),
	}, gs, 0)
	var end_score: float = strategy.score_action_absolute({"kind": "end_turn"}, gs, 0)

	return assert_true(retreat_score < end_score - 10000.0, "Late Ogerpon should not burn retreat Energy to promote Squawkabilly over ending (retreat=%f end=%f)" % [retreat_score, end_score])


func test_v17_regidrago_charizard_pressure_allows_ogerpon_retreat_to_ready_vstar() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(8)
	var player := gs.players[0]
	var active := _slot(_pokemon("Teal Mask Ogerpon ex", "Basic", "G", 210, "", "ex", [
		{"name": "Myriad Leaf Shower", "cost": "GGG", "damage": "30+"},
	], 1), 0)
	var vstar := _slot(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V", [
		{"name": "Apex Dragon", "cost": "GGR", "damage": ""},
	], 3), 0)
	_attach(active, "G", 1)
	_attach(vstar, "G", 2)
	_attach(vstar, "R", 1)
	player.active_pokemon = active
	player.bench.append(vstar)
	player.discard_pile.append(_card(_pokemon("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex"), 0))
	gs.players[1].active_pokemon = _slot(_pokemon("Charizard ex", "Stage 2", "D", 330, "Charmeleon", "ex", [
		{"name": "Burning Darkness", "cost": "RR", "damage": "180+"},
	]), 1)

	var retreat_score: float = strategy.score_action_absolute({
		"kind": "retreat",
		"bench_target": vstar,
		"energy_to_discard": active.attached_energy.duplicate(),
	}, gs, 0)
	var end_score: float = strategy.score_action_absolute({"kind": "end_turn"}, gs, 0)

	return assert_true(retreat_score > end_score, "Ready Regidrago VSTAR handoff should remain legal under Charizard pressure (retreat=%f end=%f)" % [retreat_score, end_score])


func test_v17_regidrago_charizard_pressure_blocks_damaged_ready_vstar_handoff() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(10)
	var player := gs.players[0]
	var active := _slot(_pokemon("Teal Mask Ogerpon ex", "Basic", "G", 210, "", "ex", [
		{"name": "Myriad Leaf Shower", "cost": "GGG", "damage": "30+"},
	], 1), 0)
	var vstar := _slot(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V", [
		{"name": "Apex Dragon", "cost": "GGR", "damage": ""},
	], 3), 0)
	vstar.damage_counters = 190
	_attach(active, "G", 1)
	_attach(vstar, "G", 2)
	_attach(vstar, "R", 1)
	player.active_pokemon = active
	player.bench.append(vstar)
	player.discard_pile.append(_card(_pokemon("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex"), 0))
	player.discard_pile.append(_card(_pokemon("Hisuian Goodra VSTAR", "VSTAR", "N", 270, "Hisuian Goodra V", "V"), 0))
	gs.players[1].active_pokemon = _slot(_pokemon("Charizard ex", "Stage 2", "D", 330, "Charmeleon", "ex", [
		{"name": "Burning Darkness", "cost": "RR", "damage": "180+"},
	]), 1)

	var retreat_score: float = strategy.score_action_absolute({
		"kind": "retreat",
		"bench_target": vstar,
		"energy_to_discard": active.attached_energy.duplicate(),
	}, gs, 0)
	var end_score: float = strategy.score_action_absolute({"kind": "end_turn"}, gs, 0)

	return assert_true(retreat_score < end_score, "A damaged ready VSTAR that cannot survive Charizard should stay benched unless it is ending the game (retreat=%f end=%f)" % [retreat_score, end_score])


func test_v17_regidrago_plan_blocks_energy_paid_retreat_from_ready_drago_owner_to_ogerpon() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(1)
	var player := gs.players[0]
	var active := _slot(_pokemon("Regidrago V", "Basic", "N", 220, "", "V", [
		{"name": "Celestial Roar", "cost": "C", "damage": ""},
		{"name": "Dragon Laser", "cost": "GGR", "damage": "130"},
	], 3), 0)
	var ogerpon := _slot(_pokemon("Teal Mask Ogerpon ex", "Basic", "G", 210, "", "ex", [
		{"name": "Myriad Leaf Shower", "cost": "G", "damage": "30"},
	], 1), 0)
	_attach(active, "G", 2)
	_attach(active, "R", 1)
	_attach(ogerpon, "G", 1)
	player.active_pokemon = active
	player.bench.append(ogerpon)

	var turn_contract: Dictionary = strategy.build_turn_contract(gs, 0, {"prompt_kind": "action_selection"})
	var retreat_score: float = strategy.score_action_absolute_with_plan({
		"kind": "retreat",
		"bench_target": ogerpon,
		"energy_to_discard": active.attached_energy.slice(0, 3),
	}, gs, 0, turn_contract)
	var end_score: float = strategy.score_action_absolute_with_plan({"kind": "end_turn"}, gs, 0, turn_contract)

	return assert_true(retreat_score < end_score, "A ready Regidrago owner should not pay three Energy to retreat into Ogerpon during the launch contract (retreat=%f end=%f)" % [retreat_score, end_score])


func test_v17_regidrago_plan_blocks_energy_paid_retreat_from_ready_vstar_to_unready_vstar() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(9)
	var player := gs.players[0]
	var active := _slot(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V", [
		{"name": "Apex Dragon", "cost": "GGR", "damage": ""},
	], 3), 0)
	var bench_vstar := _slot(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V", [
		{"name": "Apex Dragon", "cost": "GGR", "damage": ""},
	], 3), 0)
	_attach(active, "G", 2)
	_attach(active, "R", 1)
	player.active_pokemon = active
	player.bench.append(bench_vstar)
	player.discard_pile.append(_card(_pokemon("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex"), 0))

	var turn_contract: Dictionary = strategy.build_turn_contract(gs, 0, {"prompt_kind": "action_selection"})
	var retreat_score: float = strategy.score_action_absolute_with_plan({
		"kind": "retreat",
		"bench_target": bench_vstar,
		"energy_to_discard": active.attached_energy.slice(0, 3),
	}, gs, 0, turn_contract)
	var end_score: float = strategy.score_action_absolute_with_plan({"kind": "end_turn"}, gs, 0, turn_contract)

	return assert_true(retreat_score < end_score, "A ready Regidrago VSTAR should not dump its attack Energy to promote an unready backup VSTAR (retreat=%f end=%f)" % [retreat_score, end_score])


func test_v17_regidrago_hand_energy_assignment_targets_missing_vstar_type() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(5)
	var player := gs.players[0]
	var vstar := _slot(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V", [
		{"name": "Apex Dragon", "cost": "GGR", "damage": ""},
	], 3), 0)
	var ogerpon := _slot(_pokemon("Teal Mask Ogerpon ex", "Basic", "G", 210, "", "ex"), 0)
	_attach(vstar, "G", 2)
	player.active_pokemon = ogerpon
	player.bench.append(vstar)
	var fire := _card(_energy("Fire Energy", "R"), 0)

	var regidrago_score: float = strategy.score_interaction_target(
		vstar,
		{"id": "csv9c_hand_energy_assignments"},
		{"game_state": gs, "player_index": 0, "source_card": fire}
	)
	var ogerpon_score: float = strategy.score_interaction_target(
		ogerpon,
		{"id": "csv9c_hand_energy_assignments"},
		{"game_state": gs, "player_index": 0, "source_card": fire}
	)

	return assert_true(regidrago_score > ogerpon_score, "Hand-energy assignment effects should put missing Fire on Regidrago VSTAR before padding Ogerpon (drago=%f ogerpon=%f)" % [regidrago_score, ogerpon_score])


func test_v17_regidrago_manual_grass_goes_to_vstar_when_ogerpon_switch_completes_apex() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(4)
	var player := gs.players[0]
	var ogerpon := _slot(_pokemon("Teal Mask Ogerpon ex", "Basic", "G", 210, "", "ex"), 0)
	_attach(ogerpon, "G", 1)
	player.active_pokemon = ogerpon
	var vstar := _slot(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V", [
		{"name": "Apex Dragon", "cost": "GGR", "damage": ""},
	], 3), 0)
	_attach(vstar, "R", 1)
	player.bench.append(vstar)
	var grass := _card(_energy("Grass Energy", "G"), 0)

	var vstar_score: float = strategy.score_action_absolute({"kind": "attach_energy", "card": grass, "target_slot": vstar}, gs, 0)
	var ogerpon_score: float = strategy.score_action_absolute({"kind": "attach_energy", "card": grass, "target_slot": ogerpon}, gs, 0)

	return assert_true(vstar_score > ogerpon_score, "When Ogerpon can donate the second Grass by Energy Switch, manual Grass should go to Regidrago VSTAR (vstar=%f ogerpon=%f)" % [vstar_score, ogerpon_score])


func test_v17_regidrago_energy_assignment_rejects_knocked_out_targets() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(17)
	var player := gs.players[0]
	var active := _slot(_pokemon("Teal Mask Ogerpon ex", "Basic", "G", 210, "", "ex"), 0)
	var knocked_vstar := _slot(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V", [
		{"name": "Apex Dragon", "cost": "GGR", "damage": ""},
	], 3), 0)
	var live_vstar := _slot(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V", [
		{"name": "Apex Dragon", "cost": "GGR", "damage": ""},
	], 3), 0)
	knocked_vstar.damage_counters = 280
	_attach(knocked_vstar, "G", 2)
	_attach(live_vstar, "G", 2)
	player.active_pokemon = active
	player.bench.append(knocked_vstar)
	player.bench.append(live_vstar)
	var fire := _card(_energy("Fire Energy", "R"), 0)

	var knocked_score: float = strategy.score_interaction_target(
		knocked_vstar,
		{"id": "csv9c_hand_energy_assignments"},
		{"game_state": gs, "player_index": 0, "source_card": fire}
	)
	var live_score: float = strategy.score_interaction_target(
		live_vstar,
		{"id": "csv9c_hand_energy_assignments"},
		{"game_state": gs, "player_index": 0, "source_card": fire}
	)

	return run_checks([
		assert_true(knocked_score < 0.0, "Energy assignment must reject knocked-out Regidrago targets (score=%f)" % knocked_score),
		assert_true(live_score > knocked_score, "Energy assignment should choose the live Regidrago target over an HP=0 slot (live=%f knocked=%f)" % [live_score, knocked_score]),
	])


func test_v17_regidrago_superior_energy_retrieval_scores_reload_when_attacker_missing_energy() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(9)
	var player := gs.players[0]
	var vstar := _slot(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V", [
		{"name": "Apex Dragon", "cost": "GGR", "damage": ""},
	], 3), 0)
	_attach(vstar, "G", 1)
	player.active_pokemon = vstar
	player.discard_pile.append_array([
		_card(_energy("Grass Energy", "G"), 0),
		_card(_energy("Fire Energy", "R"), 0),
	])
	for i: int in 24:
		player.deck.append(_card(_trainer("Filler %d" % i), 0))
	var superior := _card(_trainer("Superior Energy Retrieval"), 0)
	var iono := _card(_trainer("Iono", "Supporter"), 0)

	var superior_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": superior}, gs, 0)
	var iono_score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": iono}, gs, 0)

	return assert_true(superior_score > iono_score, "When Regidrago VSTAR is missing GGR pieces, Superior Energy Retrieval should be a real reload line (superior=%f iono=%f)" % [superior_score, iono_score])


func test_v17_regidrago_prioritizes_missing_fire_for_ggr() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(5)
	var player := gs.players[0]
	var drago := _slot(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V"), 0)
	_attach(drago, "G", 2)
	player.active_pokemon = drago
	var fire := _card(_energy("Fire Energy", "R"), 0)
	var grass := _card(_energy("Grass Energy", "G"), 0)
	player.hand.append_array([fire, grass])

	var searched: Array = strategy.pick_interaction_items(
		[grass, fire],
		{"id": "search_energy", "max_select": 1},
		{"game_state": gs, "player_index": 0}
	)
	var discarded: Array = strategy.pick_interaction_items(
		[grass, fire],
		{"id": "discard_cards", "max_select": 1},
		{"game_state": gs, "player_index": 0}
	)
	var fire_attach_score: float = strategy.score_action_absolute({"kind": "attach_energy", "card": fire, "target_slot": drago}, gs, 0)
	var grass_attach_score: float = strategy.score_action_absolute({"kind": "attach_energy", "card": grass, "target_slot": drago}, gs, 0)

	return run_checks([
		assert_eq(_names(searched), ["Fire Energy"], "Earthen Vessel should search Fire when Regidrago has GG but lacks R"),
		assert_eq(_names(discarded), ["Grass Energy"], "Discard costs should protect the missing Fire Energy for GGR"),
		assert_true(fire_attach_score > grass_attach_score, "Manual attach should prefer the missing Fire over redundant Grass (fire=%f grass=%f)" % [fire_attach_score, grass_attach_score]),
	])


func test_v17_regidrago_preserves_mew_draw_when_backup_needs_vstar() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(20)
	var player := gs.players[0]
	player.active_pokemon = _slot(_pokemon("Teal Mask Ogerpon ex", "Basic", "G", 210, "", "ex"), 0)
	player.bench.append(_slot(_pokemon("Regidrago V", "Basic", "N", 220, "", "V"), 0))
	player.deck.append(_card(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V"), 0))
	var mew := _card(_pokemon("Mew ex", "Basic", "P", 180, "", "ex", [
		{"name": "Restart", "cost": "", "damage": "", "text": "Draw until you have 3 cards in hand."},
	]), 0)
	var vessel := _card(_trainer("Earthen Vessel"), 0)
	var grass := _card(_energy("Grass Energy", "G"), 0)
	var vessel_action := {
		"kind": "play_trainer",
		"card": vessel,
		"targets": [{"discard_cards": [mew], "search_energy": [grass]}],
	}
	player.hand.append_array([mew, vessel])

	var vessel_score: float = strategy.score_action_absolute(vessel_action, gs, 0)
	var mew_discard_score: float = strategy.score_interaction_target(
		mew,
		{"id": "discard_cards", "max_select": 1},
		{"game_state": gs, "player_index": 0}
	)
	var bench_mew_score: float = strategy.score_action_absolute({"kind": "play_basic_to_bench", "card": mew}, gs, 0)

	return run_checks([
		assert_true(vessel_score < -100.0, "Earthen Vessel should not discard the only Mew draw engine while backup Regidrago still needs VSTAR (score=%f)" % vessel_score),
		assert_true(mew_discard_score < 20.0, "Discard selection should protect Mew ex in the backup-VSTAR recovery window (score=%f)" % mew_discard_score),
		assert_true(bench_mew_score > 600.0, "The rules fallback should bench Mew ex as a recovery draw engine before sacrificing it (score=%f)" % bench_mew_score),
	])


func test_v17_regidrago_blocks_end_when_active_apex_is_ready() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(4)
	var player := gs.players[0]
	var vstar := _slot(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V", [
		{"name": "Apex Dragon", "cost": "GGR", "damage": ""},
	], 3), 0)
	_attach(vstar, "G", 2)
	_attach(vstar, "R", 1)
	player.active_pokemon = vstar
	player.discard_pile.append(_card(_pokemon("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex"), 0))

	var end_score: float = strategy.score_action_absolute({"kind": "end_turn"}, gs, 0)

	return assert_true(end_score < -10000.0, "Rules fallback should not end the turn while active Regidrago VSTAR has GGR and copied-attack fuel (score=%f)" % end_score)


func test_v17_regidrago_blocks_celestial_roar_after_vstar_online() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(9)
	var player := gs.players[0]
	var active_v := _slot(_pokemon("Regidrago V", "Basic", "N", 220, "", "V", [
		{"name": "Celestial Roar", "cost": "C", "damage": ""},
		{"name": "Dragon Laser", "cost": "GGR", "damage": "130"},
	], 3), 0)
	_attach(active_v, "G", 1)
	player.active_pokemon = active_v
	player.bench.append(_slot(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V"), 0))
	player.discard_pile.append(_card(_pokemon("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex"), 0))

	var roar_score: float = strategy.score_action_absolute({
		"kind": "attack",
		"source_slot": active_v,
		"attack_index": 0,
		"attack_name": "Celestial Roar",
		"projected_damage": 0,
		"projected_knockout": false,
	}, gs, 0)

	return assert_true(roar_score < -100.0, "Celestial Roar should be below ending the turn after VSTAR/fuel are online (score=%f)" % roar_score)


func test_v17_regidrago_uses_star_legacy_early_but_not_with_thin_deck() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(5)
	var player := gs.players[0]
	var vstar := _slot(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V"), 0)
	player.active_pokemon = vstar
	for i: int in 20:
		player.deck.append(_card(_trainer("Filler %d" % i), 0))
	var early_score: float = strategy.score_action_absolute({"kind": "use_ability", "source_slot": vstar, "ability_index": 0}, gs, 0)
	player.deck.clear()
	for i: int in 8:
		player.deck.append(_card(_trainer("Thin %d" % i), 0))
	var late_score: float = strategy.score_action_absolute({"kind": "use_ability", "source_slot": vstar, "ability_index": 0}, gs, 0)

	return run_checks([
		assert_true(early_score >= 700.0, "Star Legacy should be a strong early setup action while dragon fuel is missing (score=%f)" % early_score),
		assert_true(late_score < -100.0, "Star Legacy should be blocked once the deck is too thin to mill seven safely (score=%f)" % late_score),
	])


func test_v17_regidrago_blocks_star_legacy_when_fuel_exists_and_deck_is_low() -> String:
	var strategy := StrategyRegidrago.new()
	var gs := _game_state(21)
	var player := gs.players[0]
	var vstar := _slot(_pokemon("Regidrago VSTAR", "VSTAR", "N", 280, "Regidrago V", "V"), 0)
	player.active_pokemon = vstar
	player.discard_pile.append(_card(_pokemon("Giratina VSTAR", "VSTAR", "N", 280, "Giratina V", "V"), 0))
	player.discard_pile.append(_card(_pokemon("Dragapult ex", "Stage 2", "N", 320, "Drakloak", "ex"), 0))
	for i: int in 18:
		player.deck.append(_card(_trainer("Low Deck %d" % i), 0))

	var score: float = strategy.score_action_absolute({"kind": "use_ability", "source_slot": vstar, "ability_index": 0}, gs, 0)

	return assert_true(score < -100.0, "Once two copied-attack fuels are already in discard, Star Legacy should stop before a low deck-out window (score=%f)" % score)
