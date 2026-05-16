class_name TestV17MiraidonStrategy
extends TestBase

const StrategyV17Miraidon = preload("res://scripts/ai/DeckStrategy17Miraidon.gd")


func _new_strategy() -> RefCounted:
	CardInstance.reset_id_counter()
	return StrategyV17Miraidon.new()


func _pokemon(
	pname: String,
	energy_type: String = "L",
	hp: int = 100,
	mechanic: String = "",
	abilities: Array = [],
	attacks: Array = [],
	retreat_cost: int = 1,
	stage: String = "Basic",
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
	cd.mechanic = mechanic
	cd.retreat_cost = retreat_cost
	cd.set_code = set_code
	cd.card_index = card_index
	for ability: Dictionary in abilities:
		cd.abilities.append(ability.duplicate(true))
	for attack: Dictionary in attacks:
		cd.attacks.append(attack.duplicate(true))
	return cd


func _trainer(pname: String, card_type: String = "Item") -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.name_en = pname
	cd.card_type = card_type
	return cd


func _energy(pname: String = "Basic Lightning Energy", provides: String = "L") -> CardData:
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


func _attach(slot: PokemonSlot, provides: String, count: int) -> void:
	for i: int in count:
		slot.attached_energy.append(_card(_energy("%s Energy %d" % [provides, i], provides), 0))


func _player(pi: int = 0) -> PlayerState:
	var player := PlayerState.new()
	player.player_index = pi
	return player


func _game_state(turn: int = 2) -> GameState:
	var gs := GameState.new()
	gs.turn_number = turn
	gs.current_player_index = 0
	gs.first_player_index = 0
	gs.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var player := _player(pi)
		player.active_pokemon = _slot(_pokemon("Active %d" % pi, "C", 100), pi)
		gs.players.append(player)
	return gs


func _ctx(gs: GameState, pi: int = 0) -> Dictionary:
	return {"game_state": gs, "player_index": pi}


func _miraidon() -> CardData:
	return _pokemon("Miraidon ex", "L", 220, "ex", [{"name": "Tandem Unit"}], [
		{"name": "Photon Blaster", "cost": "LLC", "damage": "220"},
	], 1, "Basic", "CSV1C", "050")


func _iron_hands() -> CardData:
	return _pokemon("Iron Hands ex", "L", 230, "ex", [], [
		{"name": "Arm Press", "cost": "LLC", "damage": "160"},
		{"name": "Amp You Very Much", "cost": "LCCC", "damage": "120"},
	], 4, "Basic", "CSV6C", "051")


func _raikou() -> CardData:
	return _pokemon("Raikou V", "L", 200, "V", [{"name": "Fleet Feet"}], [
		{"name": "Lightning Rondo", "cost": "LC", "damage": "20+"},
	], 1, "Basic", "CS4DaC", "137")


func _mew() -> CardData:
	return _pokemon("Mew ex", "P", 180, "ex", [{"name": "Restart"}], [], 0)


func _latias() -> CardData:
	return _pokemon("Latias ex", "P", 210, "ex", [{"name": "Skyline"}], [
		{"name": "Eon Blade", "cost": "PPC", "damage": "200"},
	], 2, "Basic", "CSV9C", "078")


func _pikachu() -> CardData:
	var cd := _pokemon("Pikachu ex", "L", 200, "ex", [{"name": "Resolute Heart"}], [
		{"name": "Topaz Bolt", "cost": "GLM", "damage": "300"},
	], 1, "Basic", "CSV9C", "054")
	cd.ancient_trait = "Tera"
	cd.effect_id = "cd845155473716c29f29efa29da0a869"
	return cd


func _area_zero() -> CardData:
	var cd := _trainer("Area Zero Underdepths", "Stadium")
	cd.set_code = "CSV9C"
	cd.card_index = "207"
	cd.effect_id = "701eb0ccb34fe3d319ea1307bc36c1ef"
	return cd


func _charmander() -> CardData:
	return _pokemon("Charmander", "R", 70, "", [], [], 1, "Basic", "151C", "004")


func _pidgeot() -> CardData:
	return _pokemon("Pidgeot ex", "C", 280, "ex", [], [], 0, "Stage 2", "CSV4C", "101")


func _card_name(card: CardInstance) -> String:
	if card == null or card.card_data == null:
		return ""
	return str(card.card_data.name_en) if str(card.card_data.name_en) != "" else str(card.card_data.name)


func test_opening_prefers_mew_pivot_over_engine_active_with_english_cards() -> String:
	var strategy := _new_strategy()
	var player := _player()
	player.hand.append(_card(_miraidon()))
	player.hand.append(_card(_raikou()))
	player.hand.append(_card(_mew()))

	var choice: Dictionary = strategy.plan_opening_setup(player)
	var active_index: int = int(choice.get("active_hand_index", -1))
	var active_name := _card_name(player.hand[active_index]) if active_index >= 0 else ""

	return assert_eq(active_name, "Mew ex", "Opening should use Mew ex as the pivot instead of making Miraidon/Raikou active")


func test_basic_search_builds_miraidon_before_more_attackers() -> String:
	var strategy := _new_strategy()
	var gs := _game_state(2)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _slot(_mew(), 0)
	player.bench.append(_slot(_raikou(), 0))
	var miraidon := _card(_miraidon())
	var iron_hands := _card(_iron_hands())
	var step := {"id": "basic_pokemon", "max_select": 1}

	var miraidon_score: float = strategy.score_interaction_target(miraidon, step, _ctx(gs))
	var iron_score: float = strategy.score_interaction_target(iron_hands, step, _ctx(gs))

	return assert_true(
		miraidon_score > iron_score + 200.0,
		"First basic search should establish Miraidon before adding another attacker (miraidon=%f iron=%f)" % [miraidon_score, iron_score]
	)


func test_generator_targets_empty_iron_hands_over_full_miraidon() -> String:
	var strategy := _new_strategy()
	var gs := _game_state(3)
	var player: PlayerState = gs.players[0]
	var full_miraidon := _slot(_miraidon(), 0)
	_attach(full_miraidon, "L", 3)
	var iron_hands := _slot(_iron_hands(), 0)
	player.bench.append(full_miraidon)
	player.bench.append(iron_hands)
	var step := {"id": "energy_assignments", "max_select": 1}

	var iron_score: float = strategy.score_interaction_target(iron_hands, step, _ctx(gs))
	var miraidon_score: float = strategy.score_interaction_target(full_miraidon, step, _ctx(gs))

	return run_checks([
		assert_true(iron_score >= 450.0, "Electric Generator should strongly value unfueled Iron Hands (score=%f)" % iron_score),
		assert_true(iron_score > miraidon_score + 250.0, "Generator should not overfill a ready Miraidon (iron=%f miraidon=%f)" % [iron_score, miraidon_score]),
	])


func test_retreat_from_mew_prefers_ready_raikou_over_empty_latias() -> String:
	var strategy := _new_strategy()
	var gs := _game_state(3)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _slot(_mew(), 0)
	var raikou := _slot(_raikou(), 0)
	_attach(raikou, "L", 2)
	var latias := _slot(_latias(), 0)
	player.bench.append(raikou)
	player.bench.append(latias)

	var raikou_score: float = strategy.score_action_absolute({"kind": "retreat", "bench_target": raikou}, gs, 0)
	var latias_score: float = strategy.score_action_absolute({"kind": "retreat", "bench_target": latias}, gs, 0)

	return run_checks([
		assert_true(raikou_score >= 500.0, "Ready Raikou should be a strong retreat target from Mew (score=%f)" % raikou_score),
		assert_true(raikou_score > latias_score + 300.0, "Retreat should convert to a ready attacker before an empty pivot (raikou=%f latias=%f)" % [raikou_score, latias_score]),
	])


func test_tandem_unit_recognizes_english_miraidon_when_targets_exist() -> String:
	var strategy := _new_strategy()
	var gs := _game_state(2)
	var player: PlayerState = gs.players[0]
	var miraidon := _slot(_miraidon(), 0)
	player.bench.append(miraidon)
	player.deck.append(_card(_iron_hands()))
	player.deck.append(_card(_raikou()))

	var score: float = strategy.score_action_absolute({"kind": "use_ability", "source_slot": miraidon, "ability_index": 0}, gs, 0)

	return assert_true(score >= 500.0, "Tandem Unit should remain a high-priority setup ability when deck targets exist (score=%f)" % score)


func test_opponent_bench_target_prefers_raikou_ko_over_bulky_charizard_piece() -> String:
	var strategy := _new_strategy()
	var gs := _game_state(4)
	var player: PlayerState = gs.players[0]
	var opponent: PlayerState = gs.players[1]
	var raikou := _slot(_raikou(), 0)
	_attach(raikou, "L", 2)
	player.active_pokemon = raikou
	player.bench.append(_slot(_miraidon(), 0))
	player.bench.append(_slot(_iron_hands(), 0))
	opponent.active_pokemon = _slot(_pidgeot(), 1)
	var charmander := _slot(_charmander(), 1)
	var pidgeot := _slot(_pidgeot(), 1)
	opponent.bench.append(charmander)
	opponent.bench.append(pidgeot)
	var step := {"id": "opponent_bench_target", "max_select": 1}

	var charmander_score: float = strategy.score_interaction_target(charmander, step, _ctx(gs))
	var pidgeot_score: float = strategy.score_interaction_target(pidgeot, step, _ctx(gs))

	return assert_true(
		charmander_score > pidgeot_score + 400.0,
		"Boss/Counter target selection should pull a Raikou KO target before a bulky evolution body (charmander=%f pidgeot=%f)" % [charmander_score, pidgeot_score]
	)


func test_boss_scores_high_when_raikou_can_ko_opponent_bench_basic() -> String:
	var strategy := _new_strategy()
	var gs := _game_state(4)
	var player: PlayerState = gs.players[0]
	var opponent: PlayerState = gs.players[1]
	var raikou := _slot(_raikou(), 0)
	_attach(raikou, "L", 2)
	player.active_pokemon = raikou
	player.bench.append(_slot(_miraidon(), 0))
	player.bench.append(_slot(_iron_hands(), 0))
	opponent.active_pokemon = _slot(_pidgeot(), 1)
	opponent.bench.append(_slot(_charmander(), 1))
	opponent.bench.append(_slot(_pidgeot(), 1))
	var boss := _card(_trainer("Boss's Orders", "Supporter"))

	var score: float = strategy.score_action_absolute({"kind": "play_trainer", "card": boss}, gs, 0)

	return assert_true(score >= 650.0, "Boss should be a premium action when Raikou can take a bench prize (score=%f)" % score)


func test_area_zero_tera_board_allows_benching_past_five() -> String:
	var strategy := _new_strategy()
	var gs := _game_state(2)
	gs.stadium_card = _card(_area_zero(), 0)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _slot(_mew(), 0)
	player.bench.append(_slot(_pikachu(), 0))
	player.bench.append(_slot(_miraidon(), 0))
	player.bench.append(_slot(_raikou(), 0))
	player.bench.append(_slot(_latias(), 0))
	player.bench.append(_slot(_mew(), 0))
	var iron_hands := _card(_iron_hands())

	var score: float = strategy.score_action_absolute({"kind": "play_basic_to_bench", "card": iron_hands}, gs, 0)

	return assert_true(score >= 500.0, "Area Zero plus own Tera should let Miraidon keep filling the Bench past five (score=%f)" % score)


func test_tandem_unit_uses_area_zero_extra_bench_slots() -> String:
	var strategy := _new_strategy()
	var gs := _game_state(2)
	gs.stadium_card = _card(_area_zero(), 0)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _slot(_mew(), 0)
	var miraidon := _slot(_miraidon(), 0)
	player.bench.append(_slot(_pikachu(), 0))
	player.bench.append(miraidon)
	player.bench.append(_slot(_raikou(), 0))
	player.bench.append(_slot(_latias(), 0))
	player.bench.append(_slot(_mew(), 0))
	player.deck.append(_card(_iron_hands()))

	var score: float = strategy.score_action_absolute({"kind": "use_ability", "source_slot": miraidon, "ability_index": 0}, gs, 0)

	return assert_true(score >= 400.0, "Tandem Unit should keep using Area Zero's extra bench space instead of treating five as full (score=%f)" % score)


func test_area_zero_is_premium_once_pikachu_is_on_board() -> String:
	var strategy := _new_strategy()
	var gs := _game_state(2)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _slot(_mew(), 0)
	player.bench.append(_slot(_pikachu(), 0))
	player.bench.append(_slot(_miraidon(), 0))
	var area_zero := _card(_area_zero())

	var score: float = strategy.score_action_absolute({"kind": "play_stadium", "card": area_zero}, gs, 0)

	return assert_true(score >= 650.0, "Area Zero should be a premium setup stadium after Pikachu ex unlocks the Tera bench shell (score=%f)" % score)
