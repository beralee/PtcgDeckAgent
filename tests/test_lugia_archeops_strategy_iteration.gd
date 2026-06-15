class_name TestLugiaArcheopsStrategyIteration
extends TestBase


const LUGIA_SCRIPT_PATH := "res://scripts/ai/DeckStrategyLugiaArcheops.gd"
const LUGIA_175_SCRIPT_PATH := "res://scripts/ai/DeckStrategy175LugiaArcheops.gd"
const DOUBLE_TURBO_ENERGY := "Double Turbo Energy"
const GIFT_ENERGY := "Gift Energy"
const JET_ENERGY := "Jet Energy"
const MIST_ENERGY := "Mist Energy"
const V_GUARD_ENERGY := "V Guard Energy"
const LEGACY_ENERGY := "Legacy Energy"
const MESAGOZA := "Mesagoza"
const LUGIA_175_SPECIAL_ENERGY_CARDS := [
	{"name": "Jet Energy", "set_code": "CSV4C", "card_index": "129", "symbol": "C", "units": 1},
	{"name": "Legacy Energy", "set_code": "CSV8C", "card_index": "207", "symbol": "ANY", "units": 1},
	{"name": "V Guard Energy", "set_code": "CS6.5C", "card_index": "072", "symbol": "C", "units": 1},
	{"name": "Double Turbo Energy", "set_code": "CSNC", "card_index": "024", "symbol": "C", "units": 2},
	{"name": "Gift Energy", "set_code": "CS6aC", "card_index": "131", "symbol": "C", "units": 1},
	{"name": "Mist Energy", "set_code": "CSV7C", "card_index": "204", "symbol": "C", "units": 1},
]


func _new_strategy(script_path: String = LUGIA_SCRIPT_PATH) -> RefCounted:
	CardInstance.reset_id_counter()
	var script: Variant = load(script_path)
	return script.new() if script is GDScript else null


func _make_pokemon_cd(
	pname: String,
	stage: String = "Basic",
	energy_type: String = "C",
	hp: int = 100,
	evolves_from: String = "",
	mechanic: String = "",
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
	cd.attacks.clear()
	for attack: Dictionary in attacks:
		cd.attacks.append(attack.duplicate(true))
	return cd


func _make_energy_cd(pname: String, energy_provides: String = "C") -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.name_en = pname
	cd.card_type = "Special Energy"
	cd.energy_provides = energy_provides
	return cd


func _make_trainer_cd(pname: String, card_type: String = "Item") -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.name_en = pname
	cd.card_type = card_type
	return cd


func _make_slot(card_data: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner))
	slot.turn_played = 0
	return slot


func _make_player(pi: int = 0) -> PlayerState:
	var player := PlayerState.new()
	player.player_index = pi
	return player


func _make_game_state(turn: int = 5) -> GameState:
	var gs := GameState.new()
	gs.turn_number = turn
	gs.current_player_index = 0
	gs.first_player_index = 0
	gs.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var player := _make_player(pi)
		player.active_pokemon = _make_slot(_make_pokemon_cd("Active %d" % pi), pi)
		gs.players.append(player)
	return gs


func _energy(name: String) -> CardInstance:
	return CardInstance.create(_make_energy_cd(name), 0)


func _attach(slot: PokemonSlot, names: Array[String]) -> void:
	for name: String in names:
		slot.attached_energy.append(_energy(name))


func _lugia_vstar() -> PokemonSlot:
	return _make_slot(
		_make_pokemon_cd(
			"Lugia VSTAR",
			"VSTAR",
			"C",
			280,
			"Lugia V",
			"V",
			[{"name": "Tempest Dive", "cost": "CCCC", "damage": "220"}],
			2
		),
		0
	)


func _lugia_v() -> PokemonSlot:
	return _make_slot(
		_make_pokemon_cd(
			"Lugia V",
			"Basic",
			"C",
			220,
			"",
			"V",
			[
				{"name": "Read the Wind", "cost": "C", "damage": ""},
				{"name": "Aero Dive", "cost": "CCCC", "damage": "130"},
			],
			2
		),
		0
	)


func _archeops() -> PokemonSlot:
	return _make_slot(
		_make_pokemon_cd(
			"Archeops",
			"Stage 2",
			"C",
			150,
			"Archen",
			"",
			[{"name": "Speed Wing", "cost": "CCC", "damage": "120"}]
		),
		0
	)


func _cinccino() -> PokemonSlot:
	return _make_slot(
		_make_pokemon_cd(
			"Cinccino",
			"Stage 1",
			"C",
			110,
			"Minccino",
			"",
			[{"name": "Special Roll", "cost": "CC", "damage": "70x"}]
		),
		0
	)


func _cinccino_real() -> PokemonSlot:
	var cd := CardDatabase.get_card("CSV7C", "171")
	if cd == null:
		return null
	return _make_slot(cd, 0)


func _real_card(set_code: String, card_index: String, owner: int = 0) -> CardInstance:
	var cd := CardDatabase.get_card(set_code, card_index)
	if cd == null:
		return null
	return CardInstance.create(cd, owner)


func _iron_hands() -> PokemonSlot:
	return _make_slot(
		_make_pokemon_cd(
			"Iron Hands ex",
			"Basic",
			"L",
			230,
			"",
			"ex",
			[{"name": "Amp You Very Much", "cost": "LCCC", "damage": "120"}]
		),
		0
	)


func _wellspring() -> PokemonSlot:
	return _make_slot(
		_make_pokemon_cd(
			"Wellspring Mask Ogerpon ex",
			"Basic",
			"W",
			210,
			"",
			"ex",
			[
				{"name": "Sob", "cost": "C", "damage": "20"},
				{"name": "Torrential Pump", "cost": "WCC", "damage": "100"},
			]
		),
		0
	)


func _wyrdeer_v() -> PokemonSlot:
	return _make_slot(
		_make_pokemon_cd(
			"Wyrdeer V",
			"Basic",
			"C",
			220,
			"",
			"V",
			[{"name": "Psyshield Bash", "cost": "CCC", "damage": "40x"}]
		),
		0
	)


func _regigigas_card() -> CardInstance:
	return CardInstance.create(
		_make_pokemon_cd(
			"雷吉奇卡斯",
			"Basic",
			"C",
			160,
			"",
			"",
			[{"name": "Jewel Break", "cost": "CCCC", "damage": "100+"}]
		),
		0
	)


func _contract_has_bonus(contract: Dictionary, kind: String, card_name: String, reason_fragment: String = "") -> bool:
	var raw_bonuses: Variant = contract.get("action_bonuses", [])
	if not (raw_bonuses is Array):
		return false
	for item: Variant in raw_bonuses:
		if not (item is Dictionary):
			continue
		var bonus: Dictionary = item
		if str(bonus.get("kind", "")) != kind:
			continue
		if reason_fragment != "" and reason_fragment not in str(bonus.get("reason", "")):
			continue
		var card_names: Variant = bonus.get("card_names", [])
		if card_name == "":
			return true
		if card_names is Array and card_name in (card_names as Array):
			return true
	return false


func _contract_has_target_bonus(contract: Dictionary, kind: String, target_name: String, reason_fragment: String = "") -> bool:
	var raw_bonuses: Variant = contract.get("action_bonuses", [])
	if not (raw_bonuses is Array):
		return false
	for item: Variant in raw_bonuses:
		if not (item is Dictionary):
			continue
		var bonus: Dictionary = item
		if str(bonus.get("kind", "")) != kind:
			continue
		if reason_fragment != "" and reason_fragment not in str(bonus.get("reason", "")):
			continue
		var target_names: Variant = bonus.get("target_names", [])
		if target_names is Array and target_name in (target_names as Array):
			return true
	return false


func test_lugia_launch_shell_refuses_special_energy_on_non_owner_before_lugia_online() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyLugiaArcheops.gd should load before owner-missing energy discipline can be verified"
	var gs := _make_game_state(1)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Lumineon V", "Basic", "W", 170, "", "V"), 0)
	var fez := _make_slot(_make_pokemon_cd("Fezandipiti ex", "Basic", "D", 210, "", "ex"), 0)
	var minccino := _make_slot(_make_pokemon_cd("Minccino", "Basic", "C", 70), 0)
	player.bench.append(fez)
	player.bench.append(minccino)
	var legacy_to_lumineon: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": _energy("Legacy Energy"), "target_slot": player.active_pokemon},
		gs,
		0
	)
	var gift_to_fez: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": _energy("Gift Energy"), "target_slot": fez},
		gs,
		0
	)
	var jet_to_minccino: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": _energy("Jet Energy"), "target_slot": minccino},
		gs,
		0
	)
	return run_checks([
		assert_eq(legacy_to_lumineon, 0.0, "Missing-owner launch should not spend Legacy Energy on Lumineon V"),
		assert_eq(gift_to_fez, 0.0, "Missing-owner launch should not spend Gift Energy on Fezandipiti ex"),
		assert_eq(jet_to_minccino, 0.0, "Missing-owner launch should not spend Jet Energy on Minccino before Lugia is online"),
	])


func test_lugia_launch_shell_keeps_first_lugia_owner_attach_live() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyLugiaArcheops.gd should load before Lugia owner attachment can be verified"
	var gs := _make_game_state(2)
	var player := gs.players[0]
	var lugia := _make_slot(
		_make_pokemon_cd("Lugia V", "Basic", "C", 220, "", "V", [{"name": "Tempest Dive", "cost": "CCCC", "damage": "220"}]),
		0
	)
	player.active_pokemon = lugia
	var dte_score: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": _energy("Double Turbo Energy"), "target_slot": lugia},
		gs,
		0
	)
	return assert_true(dte_score >= 400.0, "Lugia owner attachment should stay live once the first Lugia is online (got %f)" % dte_score)


func test_lugia_midgame_owner_missing_keeps_cinccino_recovery_attach_live() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyLugiaArcheops.gd should load before midgame recovery attach can be verified"
	var gs := _make_game_state(6)
	var player := gs.players[0]
	player.active_pokemon = _cinccino()
	var gift_score: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": _energy(GIFT_ENERGY), "target_slot": player.active_pokemon},
		gs,
		0
	)
	return assert_true(gift_score >= 200.0, "After the initial launch window, owner-missing Lugia should still charge Cinccino recovery lines (got %f)" % gift_score)


func test_v175_lugia_nest_ball_launch_route_outranks_dead_supporter() -> String:
	var strategy := _new_strategy(LUGIA_175_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategy175LugiaArcheops.gd should load before 17.5 Nest Ball launch routing can be verified"
	var gs := _make_game_state(1)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Lumineon V", "Basic", "W", 170, "", "V"), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Minccino", "Basic", "C", 70), 0))
	var nest_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Nest Ball"), 0)},
		gs,
		0
	)
	var boss_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Boss's Orders", "Supporter"), 0)},
		gs,
		0
	)
	return run_checks([
		assert_true(nest_score >= 430.0, "17.5 Lugia should treat Nest Ball as a premium missing-owner launch route (got %f)" % nest_score),
		assert_true(nest_score > boss_score, "Nest Ball should outrank a dead Boss before the Lugia shell exists"),
	])


func test_v175_lugia_side_attackers_are_late_search_targets_not_opening_padding() -> String:
	var strategy := _new_strategy(LUGIA_175_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategy175LugiaArcheops.gd should load before 17.5 side-attacker search routing can be verified"
	var early_gs := _make_game_state(1)
	var early_player := early_gs.players[0]
	early_player.active_pokemon = _make_slot(_make_pokemon_cd("Lugia V", "Basic", "C", 220, "", "V"), 0)
	var late_gs := _make_game_state(8)
	var late_player := late_gs.players[0]
	var active_lugia := _lugia_vstar()
	_attach(active_lugia, [DOUBLE_TURBO_ENERGY, GIFT_ENERGY, JET_ENERGY, MIST_ENERGY])
	late_player.active_pokemon = active_lugia
	late_player.bench.append(_archeops())
	late_player.bench.append(_archeops())
	late_player.bench.append(_cinccino())
	var wyrdeer_card := CardInstance.create(_make_pokemon_cd("Wyrdeer V", "Basic", "C", 220, "", "V"), 0)
	var regigigas_card := _regigigas_card()
	var minccino_card := CardInstance.create(_make_pokemon_cd("Minccino", "Basic", "C", 70), 0)
	var early_wyrdeer_score: float = strategy.score_interaction_target(
		wyrdeer_card,
		{"id": "search_pokemon", "max_select": 1},
		{"game_state": early_gs, "player_index": 0}
	)
	var early_minccino_score: float = strategy.score_interaction_target(
		minccino_card,
		{"id": "search_pokemon", "max_select": 1},
		{"game_state": early_gs, "player_index": 0}
	)
	var late_wyrdeer_score: float = strategy.score_interaction_target(
		wyrdeer_card,
		{"id": "search_pokemon", "max_select": 1},
		{"game_state": late_gs, "player_index": 0}
	)
	var late_regigigas_score: float = strategy.score_interaction_target(
		regigigas_card,
		{"id": "search_pokemon", "max_select": 1},
		{"game_state": late_gs, "player_index": 0}
	)
	return run_checks([
		assert_true(early_wyrdeer_score < early_minccino_score, "Wyrdeer V should not steal opening search priority from the Minccino shell"),
		assert_true(late_wyrdeer_score >= 170.0, "Wyrdeer V should become a real late search target once Archeops is online (got %f)" % late_wyrdeer_score),
		assert_true(late_regigigas_score >= 150.0, "Localized-name Regigigas should become searchable after the engine is online (got %f)" % late_regigigas_score),
	])


func test_v175_lugia_pre_engine_manual_attach_does_not_feed_late_side_attackers() -> String:
	var strategy := _new_strategy(LUGIA_175_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategy175LugiaArcheops.gd should load before 17.5 pre-engine attachment routing can be verified"
	var gs := _make_game_state(2)
	var player := gs.players[0]
	var lugia_v := _lugia_v()
	var minccino := _make_slot(_make_pokemon_cd("Minccino", "Basic", "C", 70), 0)
	var wyrdeer := _wyrdeer_v()
	var regigigas := _make_slot(_regigigas_card().card_data, 0)
	player.active_pokemon = lugia_v
	player.bench.append(minccino)
	player.bench.append(wyrdeer)
	player.bench.append(regigigas)
	var lugia_score: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": _energy(GIFT_ENERGY), "target_slot": lugia_v},
		gs,
		0
	)
	var minccino_score: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": _energy(GIFT_ENERGY), "target_slot": minccino},
		gs,
		0
	)
	var wyrdeer_score: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": _energy(GIFT_ENERGY), "target_slot": wyrdeer},
		gs,
		0
	)
	var regigigas_score: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": _energy(GIFT_ENERGY), "target_slot": regigigas},
		gs,
		0
	)
	var shell_score := maxf(lugia_score, minccino_score)
	return run_checks([
		assert_true(wyrdeer_score <= 40.0, "Wyrdeer V should not take manual Energy before the Lugia shell is online (got %f)" % wyrdeer_score),
		assert_true(regigigas_score <= 40.0, "Regigigas should not take manual Energy before the Lugia shell is online (got %f)" % regigigas_score),
		assert_true(shell_score > wyrdeer_score, "Manual Energy should stay with the Lugia/Minccino shell before Wyrdeer V"),
		assert_true(shell_score > regigigas_score, "Manual Energy should stay with the Lugia/Minccino shell before Regigigas"),
	])


func test_v175_lugia_emergency_search_prefers_basic_backup_over_archeops() -> String:
	var strategy := _new_strategy(LUGIA_175_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategy175LugiaArcheops.gd should load before 17.5 emergency search routing can be verified"
	var gs := _make_game_state(2)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Lumineon V", "Basic", "W", 170, "", "V"), 0)
	player.hand.append(CardInstance.create(_lugia_vstar().get_card_data(), 0))
	var lugia_card := CardInstance.create(_lugia_v().get_card_data(), 0)
	var minccino_card := CardInstance.create(_make_pokemon_cd("Minccino", "Basic", "C", 70), 0)
	var archeops_card := CardInstance.create(_archeops().get_card_data(), 0)
	var context := {"game_state": gs, "player_index": 0}
	var lugia_score: float = strategy.score_interaction_target(lugia_card, {"id": "search_pokemon", "max_select": 1}, context)
	var minccino_score: float = strategy.score_interaction_target(minccino_card, {"id": "search_pokemon", "max_select": 1}, context)
	var archeops_score: float = strategy.score_interaction_target(archeops_card, {"id": "search_pokemon", "max_select": 1}, context)
	return run_checks([
		assert_true(lugia_score > archeops_score, "Emergency no-bench search should find Lugia V before Archeops (Lugia %f vs Archeops %f)" % [lugia_score, archeops_score]),
		assert_true(minccino_score > archeops_score, "Emergency no-bench search should find a Minccino shell piece before Archeops (Minccino %f vs Archeops %f)" % [minccino_score, archeops_score]),
	])


func test_v175_lugia_retreat_rejects_one_energy_lugia_v_draw_attack_as_ready_handoff() -> String:
	var strategy := _new_strategy(LUGIA_175_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategy175LugiaArcheops.gd should load before 17.5 Lugia handoff readiness can be verified"
	var gs := _make_game_state(8)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Minccino", "Basic", "C", 70), 0)
	var lugia_v := _lugia_v()
	_attach(lugia_v, [GIFT_ENERGY])
	player.bench.append(lugia_v)
	player.bench.append(_archeops())
	player.bench.append(_archeops())
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Charizard ex", "Stage 2", "R", 330, "", "ex"), 1)
	var turn_plan: Dictionary = strategy.build_turn_contract(gs, 0, {"prompt_kind": "action_selection"})
	var retreat_score: float = strategy.score_action_absolute_with_plan(
		{"kind": "retreat", "bench_target": lugia_v},
		gs,
		0,
		turn_plan
	)
	return assert_true(
		retreat_score <= 50.0,
		"One-energy Lugia V only has a zero-damage draw attack ready and should not be scored as a conversion handoff target (got %f)" % retreat_score
	)


func test_v175_lugia_retreat_rejects_one_energy_cinccino_chip_handoff() -> String:
	var strategy := _new_strategy(LUGIA_175_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategy175LugiaArcheops.gd should load before 17.5 Cinccino handoff readiness can be verified"
	var gs := _make_game_state(8)
	var player := gs.players[0]
	var active_lugia := _lugia_vstar()
	_attach(active_lugia, [DOUBLE_TURBO_ENERGY, GIFT_ENERGY, JET_ENERGY, MIST_ENERGY])
	player.active_pokemon = active_lugia
	player.bench.append(_archeops())
	player.bench.append(_archeops())
	var chip_cinccino := _cinccino()
	_attach(chip_cinccino, [GIFT_ENERGY])
	player.bench.append(chip_cinccino)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	var turn_plan: Dictionary = strategy.build_turn_contract(gs, 0, {"prompt_kind": "action_selection"})
	var contract_pivot := ""
	if turn_plan.get("owner", {}) is Dictionary:
		contract_pivot = str((turn_plan.get("owner", {}) as Dictionary).get("pivot_target_name", ""))
	var retreat_score: float = strategy.score_action_absolute_with_plan(
		{"kind": "retreat", "bench_target": chip_cinccino},
		gs,
		0,
		turn_plan
	)
	var active_attack_score: float = strategy.score_action_absolute_with_plan(
		{"kind": "attack", "source_slot": active_lugia, "attack_name": "Tempest Dive", "projected_damage": 220, "projected_knockout": true},
		gs,
		0,
		turn_plan
	)
	return run_checks([
		assert_true(contract_pivot != "Cinccino", "A one-energy Cinccino chip attack should not become the contract pivot"),
		assert_true(retreat_score < 100.0, "Retreating into a one-energy Cinccino chip attack should stay low-value (got %f)" % retreat_score),
		assert_true(active_attack_score > retreat_score, "A live Lugia VSTAR KO should outrank retreating into chip Cinccino (attack=%f retreat=%f)" % [active_attack_score, retreat_score]),
	])


func test_v175_lugia_deck_out_pressure_pushes_search_below_end_turn() -> String:
	var strategy := _new_strategy(LUGIA_175_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategy175LugiaArcheops.gd should load before 17.5 deck-out search discipline can be verified"
	var gs := _make_game_state(20)
	var player := gs.players[0]
	var active_lugia := _lugia_vstar()
	_attach(active_lugia, [DOUBLE_TURBO_ENERGY, GIFT_ENERGY, JET_ENERGY, MIST_ENERGY])
	player.active_pokemon = active_lugia
	player.bench.append(_archeops())
	player.deck.clear()
	for i: int in 8:
		player.deck.append(CardInstance.create(_make_trainer_cd("Deck Filler %d" % i), 0))
	var nest_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Nest Ball"), 0)},
		gs,
		0
	)
	var mesagoza_score: float = strategy.score_action_absolute(
		{"kind": "play_stadium", "card": CardInstance.create(_make_trainer_cd("Mesagoza", "Stadium"), 0)},
		gs,
		0
	)
	return run_checks([
		assert_true(nest_score < 0.0, "17.5 Lugia should not tie end-turn with Nest Ball under deck-out pressure (got %f)" % nest_score),
		assert_true(mesagoza_score < 0.0, "17.5 Lugia should not tie end-turn with Mesagoza under deck-out pressure (got %f)" % mesagoza_score),
	])


func test_v175_lugia_mesagoza_effect_cools_off_under_deck_out_pressure() -> String:
	var strategy := _new_strategy(LUGIA_175_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategy175LugiaArcheops.gd should load before Mesagoza deck-out discipline can be verified"
	var gs := _make_game_state(20)
	var player := gs.players[0]
	var active_lugia := _lugia_vstar()
	_attach(active_lugia, [GIFT_ENERGY, JET_ENERGY, MIST_ENERGY, V_GUARD_ENERGY])
	player.active_pokemon = active_lugia
	player.bench.append(_archeops())
	player.bench.append(_archeops())
	player.deck.clear()
	for i: int in 10:
		player.deck.append(CardInstance.create(_make_pokemon_cd("Late Pokemon %d" % i), 0))
	var mesagoza := CardInstance.create(_make_trainer_cd(MESAGOZA, "Stadium"), 0)
	gs.stadium_card = mesagoza
	var stadium_score: float = strategy.score_action_absolute({"kind": "use_stadium_effect", "card": mesagoza}, gs, 0)
	var end_turn_score: float = strategy.score_action_absolute({"kind": "end_turn"}, gs, 0)
	return assert_true(
		stadium_score < end_turn_score,
		"Mesagoza effect should cool off under deck-out pressure once a live attacker exists (stadium=%f end=%f)" % [stadium_score, end_turn_score]
	)


func test_v175_lugia_post_engine_low_damage_attack_does_not_block_rebuild_search() -> String:
	var strategy := _new_strategy(LUGIA_175_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategy175LugiaArcheops.gd should load before 17.5 post-engine attack discipline can be verified"
	var gs := _make_game_state(8)
	var player := gs.players[0]
	player.active_pokemon = _lugia_vstar()
	player.bench.append(_archeops())
	player.bench.append(_archeops())
	var turn_plan: Dictionary = strategy.build_turn_contract(gs, 0, {"prompt_kind": "action_selection"})
	var ultra_score: float = strategy.score_action_absolute_with_plan(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Ultra Ball"), 0)},
		gs,
		0,
		turn_plan
	)
	var zero_attack_score: float = strategy.score_action_absolute_with_plan(
		{"kind": "attack", "source_slot": player.active_pokemon, "attack_name": "Low pressure", "projected_damage": 0},
		gs,
		0,
		turn_plan
	)
	var chip_attack_score: float = strategy.score_action_absolute_with_plan(
		{"kind": "attack", "source_slot": player.active_pokemon, "attack_name": "Low pressure", "projected_damage": 10},
		gs,
		0,
		turn_plan
	)
	return run_checks([
		assert_true(ultra_score > zero_attack_score, "Post-engine zero-damage attacks should not outrank rebuild search (Ultra=%f attack=%f)" % [ultra_score, zero_attack_score]),
		assert_true(ultra_score > chip_attack_score, "Post-engine 10-damage non-KO attacks should not outrank rebuild search (Ultra=%f attack=%f)" % [ultra_score, chip_attack_score]),
	])


func test_v175_lugia_post_engine_low_damage_attack_matches_localized_runtime_owner() -> String:
	var strategy := _new_strategy(LUGIA_175_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategy175LugiaArcheops.gd should load before localized 17.5 post-engine attack discipline can be verified"
	var gs := _make_game_state(8)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("洛奇亚VSTAR", "Stage 1", "C", 280, "", "VSTAR"), 0)
	player.bench.append(_archeops())
	player.bench.append(_archeops())
	var turn_plan: Dictionary = strategy.build_turn_contract(gs, 0, {"prompt_kind": "action_selection"})
	var ultra_score: float = strategy.score_action_absolute_with_plan(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Ultra Ball"), 0)},
		gs,
		0,
		turn_plan
	)
	var runtime_shaped_attack_score: float = strategy.score_action_absolute_with_plan(
		{"kind": "attack", "attack_name": "??", "projected_damage": 0, "projected_knockout": false},
		gs,
		0,
		turn_plan
	)
	return assert_true(
		ultra_score > runtime_shaped_attack_score,
		"Localized Lugia VSTAR runtime attacks without source_slot should not keep the base 540 score (Ultra=%f attack=%f)" % [ultra_score, runtime_shaped_attack_score]
	)


func test_v175_lugia_post_engine_cinccino_low_damage_attack_yields_to_setup() -> String:
	var strategy := _new_strategy(LUGIA_175_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategy175LugiaArcheops.gd should load before post-engine Cinccino attack discipline can be verified"
	var gs := _make_game_state(8)
	var player := gs.players[0]
	player.active_pokemon = _cinccino()
	player.bench.append(_archeops())
	player.bench.append(_archeops())
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Charizard ex", "Stage 2", "R", 330, "", "ex"), 1)
	var turn_plan: Dictionary = strategy.build_turn_contract(gs, 0, {"prompt_kind": "action_selection"})
	var ultra_score: float = strategy.score_action_absolute_with_plan(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Ultra Ball"), 0)},
		gs,
		0,
		turn_plan
	)
	var lugia_seed_score: float = strategy.score_action_absolute_with_plan(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd("Lugia V", "Basic", "C", 220, "", "V"), 0)},
		gs,
		0,
		turn_plan
	)
	var zero_attack_score: float = strategy.score_action_absolute_with_plan(
		{"kind": "attack", "source_slot": player.active_pokemon, "attack_name": "Special Roll", "projected_damage": 0, "projected_knockout": false},
		gs,
		0,
		turn_plan
	)
	var chip_attack_score: float = strategy.score_action_absolute_with_plan(
		{"kind": "attack", "source_slot": player.active_pokemon, "attack_name": "Special Roll", "projected_damage": 30, "projected_knockout": false},
		gs,
		0,
		turn_plan
	)
	return run_checks([
		assert_true(lugia_seed_score > zero_attack_score, "Post-engine Cinccino zero-damage attacks should not outrank rebuilding a Lugia attacker (Lugia=%f attack=%f)" % [lugia_seed_score, zero_attack_score]),
		assert_true(ultra_score > chip_attack_score, "Post-engine Cinccino chip attacks should not outrank search when they cannot take a KO (Ultra=%f attack=%f)" % [ultra_score, chip_attack_score]),
	])


func test_v175_lugia_cinccino_special_roll_preview_matches_actual_damage() -> String:
	var cinccino := _cinccino_real()
	if cinccino == null:
		return "Missing CSV7C_171 Cinccino real card data"
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_game_state(8)
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.current_player_index = 0
	gsm.game_state.players[0].active_pokemon = cinccino
	gsm.game_state.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	_attach(cinccino, [GIFT_ENERGY, JET_ENERGY])
	gsm.effect_processor.register_pokemon_card(cinccino.get_card_data())
	var preview_damage := gsm.get_attack_preview_damage(0, 1)
	var used := gsm.use_attack(0, 1)
	var actual_damage := gsm.game_state.players[1].active_pokemon.damage_counters
	return run_checks([
		assert_eq(preview_damage, 140, "Cinccino Special Roll preview should be 70 per attached Special Energy"),
		assert_true(used, "Cinccino should be able to use Special Roll with two Special Energy"),
		assert_eq(actual_damage, 140, "Cinccino Special Roll actual damage should match preview"),
	])


func test_v175_lugia_cinccino_special_roll_with_only_double_turbo_deals_50() -> String:
	var cinccino := _cinccino_real()
	var double_turbo := _real_card("CSNC", "024", 0)
	if cinccino == null or double_turbo == null:
		return "Missing CSV7C_171 Cinccino or CSNC_024 Double Turbo real card data"
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_game_state(8)
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.current_player_index = 0
	gsm.game_state.players[0].active_pokemon = cinccino
	gsm.game_state.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	cinccino.attached_energy.append(double_turbo)
	gsm.effect_processor.register_pokemon_card(cinccino.get_card_data())
	var preview_damage := gsm.get_attack_preview_damage(0, 1)
	var used := gsm.use_attack(0, 1)
	var actual_damage := gsm.game_state.players[1].active_pokemon.damage_counters
	return run_checks([
		assert_eq(preview_damage, 50, "Cinccino with only Double Turbo should preview 70 minus the Double Turbo penalty"),
		assert_true(used, "One Double Turbo should satisfy Special Roll's CC cost"),
		assert_eq(actual_damage, 50, "Cinccino with only Double Turbo should deal 50 actual damage, not count Double Turbo as two Special Energy cards"),
	])


func test_v175_lugia_bundled_special_energies_register_and_power_cinccino() -> String:
	var cinccino := _cinccino_real()
	if cinccino == null:
		return "Missing CSV7C_171 Cinccino real card data"
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_game_state(8)
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.current_player_index = 0
	gsm.game_state.players[0].active_pokemon = cinccino
	gsm.game_state.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Neutral Defender", "Basic", "C", 500), 1)
	var checks: Array[String] = []
	for spec: Dictionary in LUGIA_175_SPECIAL_ENERGY_CARDS:
		var energy := _real_card(str(spec.get("set_code", "")), str(spec.get("card_index", "")), 0)
		if energy == null or energy.card_data == null:
			return "Missing bundled Special Energy card data: %s" % str(spec.get("name", ""))
		var cd: CardData = energy.card_data
		checks.append(assert_eq(str(cd.card_type), "Special Energy", "%s should be loaded as Special Energy" % str(spec.get("name", ""))))
		checks.append(assert_true(gsm.effect_processor.has_effect(str(cd.effect_id)), "%s effect_id should be registered" % str(spec.get("name", ""))))
		checks.append(assert_eq(gsm.effect_processor.get_energy_type(energy, gsm.game_state), str(spec.get("symbol", "")), "%s runtime energy symbol should match its effect" % str(spec.get("name", ""))))
		checks.append(assert_eq(gsm.effect_processor.get_energy_colorless_count(energy, gsm.game_state), int(spec.get("units", 1)), "%s runtime energy units should match its effect" % str(spec.get("name", ""))))
		cinccino.attached_energy.append(energy)
	gsm.effect_processor.register_pokemon_card(cinccino.get_card_data())
	var preview_damage := gsm.get_attack_preview_damage(0, 1)
	var used := gsm.use_attack(0, 1)
	var actual_damage := gsm.game_state.players[1].active_pokemon.damage_counters
	checks.append(assert_eq(preview_damage, 400, "All six 17.5 Lugia Special Energy cards should preview Cinccino as 420 minus the Double Turbo penalty"))
	checks.append(assert_true(used, "All six 17.5 Lugia Special Energy cards should satisfy Cinccino's CC attack cost"))
	checks.append(assert_eq(actual_damage, 400, "All six 17.5 Lugia Special Energy cards should deal the same damage as preview"))
	return run_checks(checks)


func test_v175_lugia_damage_model_counts_double_turbo_energy_units() -> String:
	var strategy := _new_strategy(LUGIA_175_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategy175LugiaArcheops.gd should load before Double Turbo modeling can be verified"
	var cinccino := _cinccino()
	_attach(cinccino, [DOUBLE_TURBO_ENERGY])
	var cinccino_forecast: Dictionary = strategy.predict_attacker_damage(cinccino)
	var lugia_vstar := _lugia_vstar()
	_attach(lugia_vstar, [DOUBLE_TURBO_ENERGY, GIFT_ENERGY, JET_ENERGY])
	var lugia_forecast: Dictionary = strategy.predict_attacker_damage(lugia_vstar)
	return run_checks([
		assert_true(bool(cinccino_forecast.get("can_attack", false)), "One Double Turbo Energy should satisfy Cinccino's CC attack cost"),
		assert_eq(int(cinccino_forecast.get("damage", 0)), 50, "Cinccino with only Double Turbo should model 70 damage minus the Double Turbo penalty"),
		assert_true(bool(lugia_forecast.get("can_attack", false)), "Double Turbo plus two single Special Energy should satisfy Lugia VSTAR's CCCC attack cost"),
		assert_eq(int(lugia_forecast.get("damage", 0)), 200, "Lugia VSTAR with Double Turbo attached should model Tempest Dive with the -20 penalty"),
	])


func test_v175_lugia_damage_model_applies_double_turbo_penalty_to_special_roll() -> String:
	var strategy := _new_strategy(LUGIA_175_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategy175LugiaArcheops.gd should load before Double Turbo damage penalty can be verified"
	var cinccino := _cinccino()
	_attach(cinccino, [DOUBLE_TURBO_ENERGY, GIFT_ENERGY])
	var forecast: Dictionary = strategy.predict_attacker_damage(cinccino)
	return run_checks([
		assert_true(bool(forecast.get("can_attack", false)), "Double Turbo plus Gift Energy should keep Cinccino attack-ready"),
		assert_eq(int(forecast.get("damage", 0)), 120, "Cinccino Special Roll should count two Special Energy cards then apply Double Turbo's -20 penalty"),
	])


func test_v175_lugia_damage_model_counts_each_special_energy_card_once() -> String:
	var strategy := _new_strategy(LUGIA_175_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategy175LugiaArcheops.gd should load before bundled Special Energy modeling can be verified"
	var cinccino := _cinccino()
	_attach(cinccino, [JET_ENERGY, LEGACY_ENERGY, V_GUARD_ENERGY, DOUBLE_TURBO_ENERGY, GIFT_ENERGY, MIST_ENERGY])
	var forecast: Dictionary = strategy.predict_attacker_damage(cinccino)
	return run_checks([
		assert_true(bool(forecast.get("can_attack", false)), "17.5 Lugia model should treat the six Special Energy cards as enough attack fuel"),
		assert_eq(int(forecast.get("damage", 0)), 400, "17.5 Lugia model should count six Special Energy cards once each and apply only Double Turbo's -20 penalty"),
	])


func test_v175_lugia_archeops_non_ko_attack_yields_to_primal_turbo() -> String:
	var strategy := _new_strategy(LUGIA_175_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategy175LugiaArcheops.gd should load before support-attacker discipline can be verified"
	var gs := _make_game_state(8)
	var player := gs.players[0]
	var active_archeops := _archeops()
	_attach(active_archeops, [GIFT_ENERGY, JET_ENERGY, MIST_ENERGY])
	player.active_pokemon = active_archeops
	player.bench.append(_lugia_vstar())
	var ready_cinccino := _cinccino()
	_attach(ready_cinccino, [GIFT_ENERGY, JET_ENERGY])
	player.bench.append(ready_cinccino)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Charizard ex", "Stage 2", "R", 330, "", "ex"), 1)
	var turn_plan: Dictionary = strategy.build_turn_contract(gs, 0, {"prompt_kind": "action_selection"})
	var ability_score: float = strategy.score_action_absolute_with_plan(
		{"kind": "use_ability", "source_slot": active_archeops},
		gs,
		0,
		turn_plan
	)
	var attack_score: float = strategy.score_action_absolute_with_plan(
		{"kind": "attack", "source_slot": active_archeops, "attack_name": "Speed Wing", "projected_damage": 100, "projected_knockout": false},
		gs,
		0,
		turn_plan
	)
	return assert_true(
		ability_score > attack_score,
		"Archeops should not take a non-KO support attack before Primal Turbo can rebuild a real attacker (ability=%f attack=%f)" % [ability_score, attack_score]
	)


func test_v175_lugia_wellspring_without_legacy_energy_is_only_chip_attacker() -> String:
	var strategy := _new_strategy(LUGIA_175_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategy175LugiaArcheops.gd should load before Wellspring damage modeling can be verified"
	var wellspring := _wellspring()
	_attach(wellspring, [GIFT_ENERGY, JET_ENERGY, MIST_ENERGY])
	var damage_info: Dictionary = strategy.predict_attacker_damage(wellspring)
	return assert_eq(
		int(damage_info.get("damage", 0)),
		20,
		"Wellspring Ogerpon without Legacy Energy should only be modeled as the 20-damage colorless attack"
	)


func test_v175_lugia_rejects_retreat_to_wellspring_chip_attack() -> String:
	var strategy := _new_strategy(LUGIA_175_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategy175LugiaArcheops.gd should load before Wellspring retreat discipline can be verified"
	var gs := _make_game_state(12)
	var player := gs.players[0]
	var active_archeops := _archeops()
	player.active_pokemon = active_archeops
	var wellspring := _wellspring()
	_attach(wellspring, [JET_ENERGY])
	player.bench.append(wellspring)
	player.bench.append(_lugia_vstar())
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Charizard ex", "Stage 2", "R", 330, "", "ex"), 1)
	var turn_plan: Dictionary = strategy.build_turn_contract(gs, 0, {"prompt_kind": "action_selection"})
	var retreat_score: float = strategy.score_action_absolute_with_plan(
		{"kind": "retreat", "bench_target": wellspring},
		gs,
		0,
		turn_plan
	)
	return assert_true(
		retreat_score < 100.0,
		"Retreating into a 20-damage Wellspring attack should stay below real setup actions (got %f)" % retreat_score
	)


func test_v175_lugia_energy_assignments_step_scores_real_attacker_over_archeops_padding() -> String:
	var strategy := _new_strategy(LUGIA_175_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategy175LugiaArcheops.gd should load before Primal Turbo assignment scoring can be verified"
	var gs := _make_game_state(10)
	var player := gs.players[0]
	var active_archeops := _archeops()
	player.active_pokemon = active_archeops
	var lugia_vstar := _lugia_vstar()
	player.bench.append(lugia_vstar)
	player.bench.append(_archeops())
	var context := {
		"game_state": gs,
		"player_index": 0,
		"source_card": _energy(GIFT_ENERGY),
	}
	var active_score: float = strategy.score_interaction_target(active_archeops, {"id": "energy_assignments"}, context)
	var lugia_score: float = strategy.score_interaction_target(lugia_vstar, {"id": "energy_assignments"}, context)
	return assert_true(
		lugia_score > active_score,
		"Primal Turbo energy_assignments should route special Energy to Lugia VSTAR before padding Archeops (Lugia=%f Archeops=%f)" % [lugia_score, active_score]
	)


func test_v175_lugia_send_out_contract_prefers_archeops_chargeable_wyrdeer() -> String:
	var strategy := _new_strategy(LUGIA_175_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategy175LugiaArcheops.gd should load before chargeable handoff can be verified"
	var gs := _make_game_state(7)
	var player := gs.players[0]
	player.active_pokemon = null
	var lugia_v := _lugia_v()
	var wyrdeer := _wyrdeer_v()
	player.bench.append(lugia_v)
	player.bench.append(_archeops())
	player.bench.append(_archeops())
	player.bench.append(wyrdeer)
	player.deck.append(_energy(DOUBLE_TURBO_ENERGY))
	player.deck.append(_energy(GIFT_ENERGY))
	player.deck.append(_energy(JET_ENERGY))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	var turn_plan: Dictionary = strategy.build_turn_contract(gs, 0, {"prompt_kind": "send_out"})
	var owner: Dictionary = turn_plan.get("owner", {}) if turn_plan.get("owner", {}) is Dictionary else {}
	var priorities: Dictionary = turn_plan.get("priorities", {}) if turn_plan.get("priorities", {}) is Dictionary else {}
	var handoff: Array = priorities.get("handoff", []) if priorities.get("handoff", []) is Array else []
	var context := {
		"game_state": gs,
		"player_index": 0,
		"turn_plan": turn_plan,
	}
	var wyrdeer_score: float = strategy.score_interaction_target(wyrdeer, {"id": "send_out"}, context)
	var lugia_score: float = strategy.score_interaction_target(lugia_v, {"id": "send_out"}, context)
	return run_checks([
		assert_eq(str(owner.get("pivot_target_name", "")), "Wyrdeer V", "After dual Archeops are online, knockout replacement should pivot to the attacker that can be charged this turn"),
		assert_true(not handoff.is_empty() and str(handoff[0]) == "Wyrdeer V", "Handoff priority should name chargeable Wyrdeer V before fallback Lugia V"),
		assert_true(wyrdeer_score > lugia_score, "send_out target scoring should agree with the contract (Wyrdeer=%f Lugia=%f)" % [wyrdeer_score, lugia_score]),
	])


func test_v175_lugia_send_out_ignores_knocked_out_primary_when_wyrdeer_can_be_charged() -> String:
	var strategy := _new_strategy(LUGIA_175_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategy175LugiaArcheops.gd should load before KO handoff can be verified"
	var gs := _make_game_state(7)
	var player := gs.players[0]
	var knocked_out_lugia := _lugia_vstar()
	knocked_out_lugia.damage_counters = knocked_out_lugia.get_max_hp()
	player.active_pokemon = knocked_out_lugia
	var archeops := _archeops()
	var wyrdeer := _wyrdeer_v()
	player.bench.append(archeops)
	player.bench.append(_archeops())
	player.bench.append(wyrdeer)
	player.deck.append(_energy(DOUBLE_TURBO_ENERGY))
	player.deck.append(_energy(GIFT_ENERGY))
	player.deck.append(_energy(JET_ENERGY))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	var turn_plan: Dictionary = strategy.build_turn_contract(gs, 0, {"prompt_kind": "handoff", "step_id": "send_out"})
	var owner: Dictionary = turn_plan.get("owner", {}) if turn_plan.get("owner", {}) is Dictionary else {}
	var context := {
		"game_state": gs,
		"player_index": 0,
		"turn_plan": turn_plan,
	}
	var wyrdeer_score: float = strategy.score_interaction_target(wyrdeer, {"id": "send_out"}, context)
	var archeops_score: float = strategy.score_interaction_target(archeops, {"id": "send_out"}, context)
	return run_checks([
		assert_eq(str(owner.get("pivot_target_name", "")), "Wyrdeer V", "A knocked-out Lugia VSTAR should not block the chargeable Wyrdeer send-out contract"),
		assert_true(wyrdeer_score > archeops_score, "send_out should prefer chargeable Wyrdeer over a support Archeops after the primary is knocked out (Wyrdeer=%f Archeops=%f)" % [wyrdeer_score, archeops_score]),
	])


func test_v175_lugia_primary_vstar_charge_outranks_backup_attackers() -> String:
	var strategy := _new_strategy(LUGIA_175_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategy175LugiaArcheops.gd should load before primary-charge scoring can be verified"
	var gs := _make_game_state(3)
	var player := gs.players[0]
	var lugia_vstar := _lugia_vstar()
	player.active_pokemon = lugia_vstar
	player.bench.append(_archeops())
	var cinccino := _cinccino()
	var wyrdeer := _wyrdeer_v()
	player.bench.append(cinccino)
	player.bench.append(wyrdeer)
	var context := {
		"game_state": gs,
		"player_index": 0,
		"source_card": _energy(GIFT_ENERGY),
	}
	var lugia_assignment: float = strategy.score_interaction_target(lugia_vstar, {"id": "energy_assignments"}, context)
	var cinccino_assignment: float = strategy.score_interaction_target(cinccino, {"id": "energy_assignments"}, context)
	var wyrdeer_assignment: float = strategy.score_interaction_target(wyrdeer, {"id": "energy_assignments"}, context)
	var lugia_attach: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": _energy(GIFT_ENERGY), "target_slot": lugia_vstar},
		gs,
		0
	)
	var cinccino_attach: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": _energy(GIFT_ENERGY), "target_slot": cinccino},
		gs,
		0
	)
	return run_checks([
		assert_true(lugia_assignment > cinccino_assignment, "Primary Lugia VSTAR should receive Primal Turbo before Cinccino while it still needs Energy"),
		assert_true(lugia_assignment > wyrdeer_assignment, "Primary Lugia VSTAR should receive Primal Turbo before Wyrdeer while it still needs Energy"),
		assert_true(lugia_attach > cinccino_attach, "Manual special Energy should stay on the uncharged primary Lugia VSTAR before Cinccino"),
	])


func test_v175_lugia_primal_turbo_charges_active_cinccino_before_benched_vstar() -> String:
	var strategy := _new_strategy(LUGIA_175_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategy175LugiaArcheops.gd should load before active conversion charging can be verified"
	var gs := _make_game_state(3)
	var player := gs.players[0]
	var active_cinccino := _cinccino()
	player.active_pokemon = active_cinccino
	var bench_lugia := _lugia_vstar()
	player.bench.append(bench_lugia)
	player.bench.append(_archeops())
	player.bench.append(_archeops())
	player.deck.append(_energy(GIFT_ENERGY))
	player.deck.append(_energy(JET_ENERGY))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230, "", "ex"), 1)
	var context := {
		"game_state": gs,
		"player_index": 0,
		"source_card": _energy(GIFT_ENERGY),
	}
	var cinccino_assignment: float = strategy.score_interaction_target(active_cinccino, {"id": "energy_assignments"}, context)
	var lugia_assignment: float = strategy.score_interaction_target(bench_lugia, {"id": "energy_assignments"}, context)
	return assert_true(
		cinccino_assignment > lugia_assignment,
		"If Lugia VSTAR is benched, Primal Turbo should enable the active Cinccino attack before charging the bench VSTAR (Cinccino=%f Lugia=%f)" % [cinccino_assignment, lugia_assignment]
	)


func test_v175_lugia_caps_primary_and_regigigas_energy_before_cinccino_scaling() -> String:
	var strategy := _new_strategy(LUGIA_175_SCRIPT_PATH)
	if strategy == null:
		return "DeckStrategy175LugiaArcheops.gd should load before 17.5 energy cap routing can be verified"
	var gs := _make_game_state(10)
	var player := gs.players[0]
	var lugia_vstar := _lugia_vstar()
	_attach(lugia_vstar, [DOUBLE_TURBO_ENERGY, GIFT_ENERGY, JET_ENERGY, MIST_ENERGY])
	player.active_pokemon = lugia_vstar
	player.bench.append(_archeops())
	var cinccino := _cinccino()
	_attach(cinccino, [GIFT_ENERGY, JET_ENERGY, MIST_ENERGY])
	var regigigas := _make_slot(_regigigas_card().card_data, 0)
	_attach(regigigas, [DOUBLE_TURBO_ENERGY, GIFT_ENERGY, JET_ENERGY, MIST_ENERGY])
	var charging_regigigas := _make_slot(_regigigas_card().card_data, 0)
	_attach(charging_regigigas, [DOUBLE_TURBO_ENERGY, GIFT_ENERGY, JET_ENERGY])
	player.bench.append(cinccino)
	player.bench.append(regigigas)
	player.bench.append(charging_regigigas)
	var gift_context := {
		"game_state": gs,
		"player_index": 0,
		"source_card": _energy(GIFT_ENERGY),
	}
	var pending_context := gift_context.duplicate()
	pending_context["pending_assignment_counts"] = {
		lugia_vstar.get_instance_id(): 1,
	}
	var legacy_context := {
		"game_state": gs,
		"player_index": 0,
		"source_card": _energy("Legacy Energy"),
	}
	var capped_lugia_score: float = strategy.score_interaction_target(lugia_vstar, {"id": "energy_assignments"}, gift_context)
	var pending_capped_lugia_score: float = strategy.score_interaction_target(lugia_vstar, {"id": "energy_assignments"}, pending_context)
	var capped_regigigas_score: float = strategy.score_interaction_target(regigigas, {"id": "energy_assignments"}, gift_context)
	var charging_regigigas_score: float = strategy.score_interaction_target(charging_regigigas, {"id": "energy_assignments"}, gift_context)
	var cinccino_gift_score: float = strategy.score_interaction_target(cinccino, {"id": "energy_assignments"}, gift_context)
	var cinccino_legacy_score: float = strategy.score_interaction_target(cinccino, {"id": "energy_assignments"}, legacy_context)
	var lugia_legacy_score: float = strategy.score_interaction_target(lugia_vstar, {"id": "energy_assignments"}, legacy_context)
	var manual_lugia_score: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": _energy(GIFT_ENERGY), "target_slot": lugia_vstar},
		gs,
		0
	)
	var manual_cinccino_score: float = strategy.score_action_absolute(
		{"kind": "attach_energy", "card": _energy(GIFT_ENERGY), "target_slot": cinccino},
		gs,
		0
	)
	return run_checks([
		assert_true(capped_lugia_score < 100.0, "A 4-energy Lugia VSTAR should be a low-value Primal Turbo target, not just slightly below Cinccino (got %f)" % capped_lugia_score),
		assert_true(pending_capped_lugia_score < 100.0, "Pending assignment counts should make Lugia overfill stay low-value in the same Primal Turbo burst (got %f)" % pending_capped_lugia_score),
		assert_true(capped_regigigas_score < 100.0, "A 4-energy Regigigas should be a low-value Primal Turbo target (got %f)" % capped_regigigas_score),
		assert_true(charging_regigigas_score > capped_regigigas_score, "A 3-energy Regigigas should still be allowed to receive its fourth Energy"),
		assert_true(cinccino_gift_score > capped_lugia_score, "A 4-energy Lugia VSTAR should stop taking Primal Turbo before Cinccino scaling"),
		assert_true(cinccino_gift_score > pending_capped_lugia_score, "Pending assignment counts should prevent overfilling Lugia past 4 in the same Primal Turbo burst"),
		assert_true(cinccino_gift_score > capped_regigigas_score, "A 4-energy Regigigas should stop taking Primal Turbo before Cinccino scaling"),
		assert_true(cinccino_legacy_score > lugia_legacy_score, "Legacy Energy should prefer Cinccino once Lugia has enough Energy"),
		assert_true(manual_cinccino_score > manual_lugia_score, "Manual special Energy should prefer Cinccino over a 4-energy Lugia VSTAR"),
	])


func test_lugia_setup_preserves_on_play_support_basics_when_core_shell_exists() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyLugiaArcheops.gd should load before setup bench discipline can be verified"
	var player := _make_player()
	player.hand.append(CardInstance.create(_make_pokemon_cd("Lugia V", "Basic", "C", 220, "", "V"), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Minccino", "Basic", "C", 70), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Lumineon V", "Basic", "W", 170, "", "V"), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Fezandipiti ex", "Basic", "D", 210, "", "ex"), 0))
	var choice: Dictionary = strategy.plan_opening_setup(player)
	var benched_names: Array[String] = []
	for idx: int in choice.get("bench_hand_indices", []):
		benched_names.append(str(player.hand[idx].card_data.name))
	return run_checks([
		assert_true("Minccino" in benched_names, "Lugia setup should still bench Minccino when Lugia V is active"),
		assert_true("Lumineon V" not in benched_names, "Lugia setup should preserve Lumineon V for turn-phase on-play search"),
		assert_true("Fezandipiti ex" not in benched_names, "Lugia setup should preserve Fezandipiti ex instead of exposing a setup liability"),
	])


func test_lugia_setup_keeps_one_backup_basic_when_owner_missing() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyLugiaArcheops.gd should load before missing-owner setup backup can be verified"
	var player := _make_player()
	player.hand.append(CardInstance.create(_make_pokemon_cd("Minccino", "Basic", "C", 70), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Lumineon V", "Basic", "W", 170, "", "V"), 0))
	player.hand.append(CardInstance.create(_make_pokemon_cd("Fezandipiti ex", "Basic", "D", 210, "", "ex"), 0))
	var choice: Dictionary = strategy.plan_opening_setup(player)
	var bench_indices: Array = choice.get("bench_hand_indices", [])
	var benched_names: Array[String] = []
	for idx: int in bench_indices:
		benched_names.append(str(player.hand[idx].card_data.name))
	return run_checks([
		assert_eq(bench_indices.size(), 1, "Missing-owner setup should keep exactly one backup Basic instead of dumping all support liabilities"),
		assert_true("Lumineon V" in benched_names, "Lumineon V is the safest backup Basic when no Lugia V is available"),
		assert_true("Fezandipiti ex" not in benched_names, "Missing-owner setup should not expose extra support liabilities"),
	])


func test_lugia_main_setup_preserves_bench_space_before_core_shell_complete() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyLugiaArcheops.gd should load before bench-space discipline can be verified"
	var gs := _make_game_state(2)
	var player := gs.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_cd("Lugia V", "Basic", "C", 220, "", "V"), 0)
	player.bench.append(_make_slot(_make_pokemon_cd("Minccino", "Basic", "C", 70), 0))
	var lumineon_score: float = strategy.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd("Lumineon V", "Basic", "W", 170, "", "V"), 0)},
		gs,
		0
	)
	var fez_score: float = strategy.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd("Fezandipiti ex", "Basic", "D", 210, "", "ex"), 0)},
		gs,
		0
	)
	var iron_hands_score: float = strategy.score_action_absolute(
		{"kind": "play_basic_to_bench", "card": CardInstance.create(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230, "", "ex"), 0)},
		gs,
		0
	)
	return run_checks([
		assert_eq(lumineon_score, 0.0, "Before Lugia VSTAR/Archeops shell is complete, Lumineon V should not be dumped as a bench liability"),
		assert_eq(fez_score, 0.0, "Before Lugia VSTAR/Archeops shell is complete, Fezandipiti ex should not be dumped as a bench liability"),
		assert_eq(iron_hands_score, 0.0, "Before Lugia VSTAR/Archeops shell is complete, Iron Hands ex should not take core bench space"),
	])


func test_lugia_boss_prioritizes_visible_bench_ko_conversion() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyLugiaArcheops.gd should load before gust conversion can be verified"
	var gs := _make_game_state(9)
	var player := gs.players[0]
	var active_lugia := _lugia_vstar()
	_attach(active_lugia, [GIFT_ENERGY, JET_ENERGY, MIST_ENERGY, V_GUARD_ENERGY])
	player.active_pokemon = active_lugia
	var opponent := gs.players[1]
	opponent.active_pokemon = _make_slot(_make_pokemon_cd("Iron Hands ex", "Basic", "L", 230, "", "ex"), 1)
	opponent.bench.append(_make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1))
	var boss_score: float = strategy.score_action_absolute(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Boss's Orders", "Supporter"), 0)},
		gs,
		0
	)
	var attack_score: float = strategy.score_action_absolute(
		{"kind": "attack", "source_slot": active_lugia, "attack_name": "Tempest Dive", "projected_damage": 220},
		gs,
		0
	)
	var gust_target_score: float = strategy.score_interaction_target(
		opponent.bench[0],
		{"id": "opponent_switch_target"},
		{"game_state": gs, "player_index": 0}
	)
	return run_checks([
		assert_true(boss_score > attack_score, "Boss should outrank a non-KO active attack when it creates a visible bench KO"),
		assert_true(gust_target_score > 800.0, "Visible two-prize bench KO target should receive a strong opponent-switch score"),
	])


func test_lugia_continuity_lifts_dual_archeops_search_before_nonterminal_attack() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyLugiaArcheops.gd should load before continuity setup can be verified"
	var gs := _make_game_state(6)
	var player := gs.players[0]
	var active_lugia := _lugia_vstar()
	_attach(active_lugia, [DOUBLE_TURBO_ENERGY, GIFT_ENERGY, JET_ENERGY, MIST_ENERGY])
	player.active_pokemon = active_lugia
	player.bench.append(_archeops())
	player.deck.append(CardInstance.create(_make_pokemon_cd("Archeops", "Stage 2", "C", 150, "Archen"), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 330, "", "ex"), 1)
	var turn_plan: Dictionary = strategy.build_turn_contract(gs, 0, {"prompt_kind": "action_selection"})
	var contract: Dictionary = strategy.build_continuity_contract(gs, 0, turn_plan)
	var debt: Dictionary = contract.get("setup_debt", {}) if contract.get("setup_debt", {}) is Dictionary else {}
	var ultra_score: float = strategy.score_action_absolute_with_plan(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Ultra Ball"), 0)},
		gs,
		0,
		turn_plan
	)
	var attack_score: float = strategy.score_action_absolute_with_plan(
		{"kind": "attack", "source_slot": active_lugia, "attack_name": "Tempest Dive", "projected_damage": 220},
		gs,
		0,
		turn_plan
	)
	return run_checks([
		assert_true(bool(contract.get("enabled", false)), "A lone ready Lugia should keep continuity active before a non-terminal attack"),
		assert_true(bool(contract.get("safe_setup_before_attack", false)), "Continuity should request safe setup before the attack"),
		assert_true(bool(debt.get("needs_second_archeops", false)), "Continuity debt should include the missing second Archeops"),
		assert_true(bool(debt.get("needs_backup_attacker_seed", false)), "Continuity debt should include a missing backup attacker seed"),
		assert_true(_contract_has_bonus(contract, "play_trainer", "Ultra Ball", "dual_archeops"), "Ultra Ball should be advertised as a dual-Archeops setup route"),
		assert_true(ultra_score > attack_score, "Plan-aware scoring should let safe Ultra Ball setup outrank the non-terminal Lugia attack"),
	])


func test_lugia_continuity_rewards_archeops_energy_relay_to_backup_attacker() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyLugiaArcheops.gd should load before energy-relay continuity can be verified"
	var gs := _make_game_state(7)
	var player := gs.players[0]
	var active_lugia := _lugia_vstar()
	_attach(active_lugia, [DOUBLE_TURBO_ENERGY, GIFT_ENERGY, JET_ENERGY, MIST_ENERGY])
	player.active_pokemon = active_lugia
	var archeops_a := _archeops()
	var archeops_b := _archeops()
	var cinccino := _cinccino()
	_attach(cinccino, [GIFT_ENERGY])
	player.bench.append(archeops_a)
	player.bench.append(archeops_b)
	player.bench.append(cinccino)
	player.deck.append(_energy(DOUBLE_TURBO_ENERGY))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 330, "", "ex"), 1)
	var turn_plan: Dictionary = strategy.build_turn_contract(gs, 0, {"prompt_kind": "action_selection"})
	var contract: Dictionary = strategy.build_continuity_contract(gs, 0, turn_plan)
	var debt: Dictionary = contract.get("setup_debt", {}) if contract.get("setup_debt", {}) is Dictionary else {}
	var ability_score: float = strategy.score_action_absolute_with_plan(
		{"kind": "use_ability", "source_slot": archeops_a},
		gs,
		0,
		turn_plan
	)
	var attach_score: float = strategy.score_action_absolute_with_plan(
		{"kind": "attach_energy", "card": _energy(GIFT_ENERGY), "target_slot": cinccino},
		gs,
		0,
		turn_plan
	)
	var attack_score: float = strategy.score_action_absolute_with_plan(
		{"kind": "attack", "source_slot": active_lugia, "attack_name": "Tempest Dive", "projected_damage": 220},
		gs,
		0,
		turn_plan
	)
	return run_checks([
		assert_true(bool(contract.get("enabled", false)), "Continuity should remain active while the backup attacker still needs relay energy"),
		assert_true(bool(debt.get("needs_second_attacker_energy", false)), "Continuity debt should include charging the follow-up attacker"),
		assert_true(_contract_has_target_bonus(contract, "use_ability", "Archeops", "relay_energy"), "Archeops ability should be advertised as safe pre-attack relay"),
		assert_true(_contract_has_bonus(contract, "attach_energy", "Gift Energy", "manual_relay"), "Manual special-energy relay should be advertised before attacking"),
		assert_true(ability_score > attack_score, "Primal Turbo relay should outrank a non-terminal Lugia attack"),
		assert_true(attach_score > attack_score, "Manual follow-up energy should outrank a non-terminal Lugia attack"),
	])


func test_lugia_continuity_disables_for_final_prize_ko() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyLugiaArcheops.gd should load before final-prize continuity can be verified"
	var gs := _make_game_state(9)
	var player := gs.players[0]
	var active_lugia := _lugia_vstar()
	_attach(active_lugia, [DOUBLE_TURBO_ENERGY, GIFT_ENERGY, JET_ENERGY, MIST_ENERGY])
	player.active_pokemon = active_lugia
	player.bench.append(_archeops())
	player.deck.append(CardInstance.create(_make_pokemon_cd("Archeops", "Stage 2", "C", 150, "Archen"), 0))
	player.prizes.append(CardInstance.create(_make_trainer_cd("Final Prize"), 0))
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 200, "", "ex"), 1)
	var turn_plan := {
		"intent": "close_out_prizes",
		"flags": {"final_prize_ko": true},
	}
	var contract: Dictionary = strategy.build_continuity_contract(gs, 0, turn_plan)
	var key_ko_contract: Dictionary = strategy.build_continuity_contract(gs, 0, {
		"intent": "convert_key_ko",
		"flags": {"key_ko": true},
	})
	var ultra_score: float = strategy.score_action_absolute_with_plan(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Ultra Ball"), 0)},
		gs,
		0,
		turn_plan
	)
	var attack_score: float = strategy.score_action_absolute_with_plan(
		{"kind": "attack", "source_slot": active_lugia, "attack_name": "Tempest Dive", "projected_damage": 220, "projected_knockout": true},
		gs,
		0,
		turn_plan
	)
	return run_checks([
		assert_false(bool(contract.get("enabled", false)), "Final-prize KO should disable Lugia continuity setup"),
		assert_false(bool(contract.get("safe_setup_before_attack", false)), "Final-prize KO should remain terminal"),
		assert_true(bool(contract.get("terminal_attack_locked", false)), "Contract should explain that terminal attack priority locked setup out"),
		assert_false(bool(key_ko_contract.get("enabled", false)), "Key-KO windows should also disable Lugia continuity setup"),
		assert_true(bool(key_ko_contract.get("terminal_attack_locked", false)), "Key-KO windows should be reported as terminal-attack locked"),
		assert_true(attack_score > ultra_score, "Final-prize attack should still outrank optional setup"),
	])


func test_lugia_continuity_stops_search_bonus_after_dual_engine_and_ready_backup() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyLugiaArcheops.gd should load before complete-continuity cooloff can be verified"
	var gs := _make_game_state(8)
	var player := gs.players[0]
	var active_lugia := _lugia_vstar()
	_attach(active_lugia, [DOUBLE_TURBO_ENERGY, GIFT_ENERGY, JET_ENERGY, MIST_ENERGY])
	player.active_pokemon = active_lugia
	var ready_cinccino := _cinccino()
	_attach(ready_cinccino, [GIFT_ENERGY, JET_ENERGY])
	player.bench.append(_archeops())
	player.bench.append(_archeops())
	player.bench.append(ready_cinccino)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 330, "", "ex"), 1)
	var turn_plan: Dictionary = strategy.build_turn_contract(gs, 0, {"prompt_kind": "action_selection"})
	var contract: Dictionary = strategy.build_continuity_contract(gs, 0, turn_plan)
	var debt: Dictionary = contract.get("setup_debt", {}) if contract.get("setup_debt", {}) is Dictionary else {}
	var bonuses: Array = contract.get("action_bonuses", []) if contract.get("action_bonuses", []) is Array else []
	var great_ball_score: float = strategy.score_action_absolute_with_plan(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd("Great Ball"), 0)},
		gs,
		0,
		turn_plan
	)
	var attack_score: float = strategy.score_action_absolute_with_plan(
		{"kind": "attack", "source_slot": active_lugia, "attack_name": "Tempest Dive", "projected_damage": 220},
		gs,
		0,
		turn_plan
	)
	return run_checks([
		assert_true(bool(debt.get("continuity_complete", false)), "Dual Archeops plus a ready backup attacker should count as complete continuity"),
		assert_false(bool(contract.get("enabled", false)), "Complete continuity should stop emitting setup bonuses"),
		assert_eq(bonuses.size(), 0, "Complete continuity should not inflate extra search/draw actions"),
		assert_true(attack_score > great_ball_score, "After continuity is complete, Great Ball should stay below the non-terminal attack"),
	])
