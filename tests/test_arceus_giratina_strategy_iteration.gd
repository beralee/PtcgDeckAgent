class_name TestArceusGiratinaStrategyIteration
extends TestBase

const STRATEGY_PATH := "res://scripts/ai/DeckStrategyArceusGiratina.gd"
const ARCEUS_V := "Arceus V"
const ARCEUS_VSTAR := "Arceus VSTAR"
const GIRATINA_V := "Giratina V"
const GIRATINA_VSTAR := "Giratina VSTAR"
const BIDOOF := "Bidoof"
const BIBAREL := "Bibarel"
const SKWOVET := "Skwovet"
const DOUBLE_TURBO_ENERGY := "Double Turbo Energy"
const GRASS_ENERGY := "Grass Energy"
const PSYCHIC_ENERGY := "Psychic Energy"
const ULTRA_BALL := "Ultra Ball"
const NEST_BALL := "Nest Ball"


func test_ready_arceus_continuity_benches_giratina_before_nonterminal_trinity() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should load"
	var gs := _make_game_state(5)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _arceus_vstar()
	_attach(player.active_pokemon, [DOUBLE_TURBO_ENERGY, PSYCHIC_ENERGY])
	_fill_prizes(player, 4)
	_fill_deck(player, 18)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 220, "", "ex"), 1)
	var giratina_card := CardInstance.create(_make_giratina_v_cd(), 0)
	var turn_contract: Dictionary = strategy.build_turn_contract(gs, 0, {"prompt_kind": "action_selection"})
	var continuity: Dictionary = strategy.build_continuity_contract(gs, 0, turn_contract)
	var debt: Dictionary = continuity.get("setup_debt", {}) if continuity.get("setup_debt", {}) is Dictionary else {}
	var bench_score: float = strategy.score_action_absolute_with_plan(
		{"kind": "play_basic_to_bench", "card": giratina_card},
		gs,
		0,
		turn_contract
	)
	var attack_score: float = strategy.score_action_absolute_with_plan(
		{"kind": "attack", "source_slot": player.active_pokemon, "attack_name": "Trinity Nova", "projected_damage": 180, "projected_knockout": false},
		gs,
		0,
		turn_contract
	)
	return run_checks([
		assert_true(bool(continuity.get("enabled", false)), "Continuity should be enabled when ready Arceus is alone before a non-terminal Trinity Nova"),
		assert_true(bool(continuity.get("safe_setup_before_attack", false)), "Continuity should request safe setup before attacking"),
		assert_true(bool(debt.get("need_second_attacker_seed", false)), "Continuity debt should include missing backup attacker seed"),
		assert_true(bool(debt.get("need_trinity_nova_route", false)), "Continuity debt should include the Trinity Nova follow-up route"),
		assert_true(_contract_has_bonus(continuity, "play_basic_to_bench", GIRATINA_V), "Continuity should reward benching Giratina V"),
		assert_true(_contract_has_bonus(continuity, "play_trainer", NEST_BALL), "Continuity should advertise search that finds a backup attacker"),
		assert_gt(bench_score, attack_score, "Safe Giratina bench should outrank a non-terminal Trinity Nova (bench=%f attack=%f)" % [bench_score, attack_score]),
	])


func test_ready_arceus_continuity_benches_engine_seed_before_nonterminal_trinity() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should load"
	var gs := _make_game_state(5)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _arceus_vstar()
	_attach(player.active_pokemon, [DOUBLE_TURBO_ENERGY, PSYCHIC_ENERGY])
	var backup_arceus := _arceus_vstar()
	_attach(backup_arceus, [DOUBLE_TURBO_ENERGY, GRASS_ENERGY])
	player.bench.append(backup_arceus)
	var giratina := _giratina_vstar()
	_attach(giratina, [GRASS_ENERGY, PSYCHIC_ENERGY, GRASS_ENERGY])
	player.bench.append(giratina)
	_fill_prizes(player, 4)
	_fill_deck(player, 18)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 330, "", "ex"), 1)
	var skwovet_card := CardInstance.create(_make_skwovet_cd(), 0)
	var turn_contract: Dictionary = strategy.build_turn_contract(gs, 0, {"prompt_kind": "action_selection"})
	var continuity: Dictionary = strategy.build_continuity_contract(gs, 0, turn_contract)
	var debt: Dictionary = continuity.get("setup_debt", {}) if continuity.get("setup_debt", {}) is Dictionary else {}
	var bench_score: float = strategy.score_action_absolute_with_plan(
		{"kind": "play_basic_to_bench", "card": skwovet_card},
		gs,
		0,
		turn_contract
	)
	var attack_score: float = strategy.score_action_absolute_with_plan(
		{"kind": "attack", "source_slot": player.active_pokemon, "attack_name": "Trinity Nova", "projected_damage": 180, "projected_knockout": false},
		gs,
		0,
		turn_contract
	)
	return run_checks([
		assert_true(bool(continuity.get("enabled", false)), "Continuity should stay enabled until the Bibarel/Skwovet engine loop is seeded"),
		assert_true(bool(debt.get("need_engine_online", false)), "Continuity debt should include the missing engine loop"),
		assert_true(_contract_has_bonus(continuity, "play_basic_to_bench", SKWOVET), "Continuity should reward benching Skwovet before Trinity Nova"),
		assert_gt(bench_score, attack_score, "Safe Skwovet bench should outrank a non-terminal Trinity Nova while engine debt remains (bench=%f attack=%f)" % [bench_score, attack_score]),
	])


func test_ready_arceus_continuity_evolves_giratina_vstar_before_nonfinal_ko() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should load"
	var gs := _make_game_state(7)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _arceus_vstar()
	_attach(player.active_pokemon, [DOUBLE_TURBO_ENERGY, PSYCHIC_ENERGY])
	var giratina := _make_slot(_make_giratina_v_cd(), 0)
	_attach(giratina, [GRASS_ENERGY, PSYCHIC_ENERGY])
	player.bench.append(giratina)
	_fill_prizes(player, 3)
	_fill_deck(player, 18)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 180, "", "ex"), 1)
	var vstar_card := CardInstance.create(_make_giratina_vstar_cd(), 0)
	var turn_contract: Dictionary = strategy.build_turn_contract(gs, 0, {"prompt_kind": "action_selection"})
	var continuity: Dictionary = strategy.build_continuity_contract(gs, 0, turn_contract)
	var debt: Dictionary = continuity.get("setup_debt", {}) if continuity.get("setup_debt", {}) is Dictionary else {}
	var evolve_score: float = strategy.score_action_absolute_with_plan(
		{"kind": "evolve", "card": vstar_card, "target_slot": giratina},
		gs,
		0,
		turn_contract
	)
	var attack_score: float = strategy.score_action_absolute_with_plan(
		{"kind": "attack", "source_slot": player.active_pokemon, "attack_name": "Trinity Nova", "projected_damage": 180, "projected_knockout": true},
		gs,
		0,
		turn_contract
	)
	return run_checks([
		assert_true(bool(continuity.get("enabled", false)), "Continuity should stay enabled before a non-final KO"),
		assert_true(bool(debt.get("need_giratina_vstar_conversion", false)), "Continuity debt should include Giratina VSTAR conversion"),
		assert_true(_contract_has_bonus(continuity, "evolve", GIRATINA_VSTAR), "Continuity should reward evolving Giratina VSTAR"),
		assert_gt(evolve_score, attack_score, "Giratina VSTAR conversion should outrank non-final Trinity KO (evolve=%f attack=%f)" % [evolve_score, attack_score]),
	])


func test_final_prize_trinity_ko_stays_terminal() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should load"
	var gs := _make_game_state(9)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _arceus_vstar()
	_attach(player.active_pokemon, [DOUBLE_TURBO_ENERGY, PSYCHIC_ENERGY])
	var giratina := _make_slot(_make_giratina_v_cd(), 0)
	_attach(giratina, [GRASS_ENERGY, PSYCHIC_ENERGY])
	player.bench.append(giratina)
	_fill_prizes(player, 1)
	_fill_deck(player, 18)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 180, "", "ex"), 1)
	var turn_contract := {
		"intent": "close_out_prizes",
		"flags": {"final_prize_ko": true},
	}
	var continuity: Dictionary = strategy.build_continuity_contract(gs, 0, turn_contract)
	var evolve_score: float = strategy.score_action_absolute_with_plan(
		{"kind": "evolve", "card": CardInstance.create(_make_giratina_vstar_cd(), 0), "target_slot": giratina},
		gs,
		0,
		turn_contract
	)
	var attack_score: float = strategy.score_action_absolute_with_plan(
		{"kind": "attack", "source_slot": player.active_pokemon, "attack_name": "Trinity Nova", "projected_damage": 180, "projected_knockout": true},
		gs,
		0,
		turn_contract
	)
	return run_checks([
		assert_false(bool(continuity.get("enabled", false)), "Final-prize KO should disable Arceus continuity setup"),
		assert_true(bool(continuity.get("terminal_attack_locked", false)), "Final-prize KO should mark terminal attack as locked"),
		assert_gt(attack_score, evolve_score, "Final-prize Trinity Nova should not be delayed by optional setup (attack=%f evolve=%f)" % [attack_score, evolve_score]),
	])


func test_complete_arceus_continuity_stops_search_inflation() -> String:
	var strategy := _new_strategy()
	if strategy == null:
		return "DeckStrategyArceusGiratina.gd should load"
	var gs := _make_game_state(8)
	var player: PlayerState = gs.players[0]
	player.active_pokemon = _arceus_vstar()
	_attach(player.active_pokemon, [DOUBLE_TURBO_ENERGY, PSYCHIC_ENERGY])
	var backup := _arceus_vstar()
	_attach(backup, [DOUBLE_TURBO_ENERGY, GRASS_ENERGY])
	var giratina := _giratina_vstar()
	_attach(giratina, [GRASS_ENERGY, PSYCHIC_ENERGY, GRASS_ENERGY])
	player.bench.append(backup)
	player.bench.append(giratina)
	player.bench.append(_make_slot(_make_bibarel_cd(), 0))
	player.bench.append(_make_slot(_make_skwovet_cd(), 0))
	_fill_prizes(player, 4)
	_fill_deck(player, 18)
	gs.players[1].active_pokemon = _make_slot(_make_pokemon_cd("Miraidon ex", "Basic", "L", 330, "", "ex"), 1)
	var turn_contract: Dictionary = strategy.build_turn_contract(gs, 0, {"prompt_kind": "action_selection"})
	var continuity: Dictionary = strategy.build_continuity_contract(gs, 0, turn_contract)
	var debt: Dictionary = continuity.get("setup_debt", {}) if continuity.get("setup_debt", {}) is Dictionary else {}
	var bonuses: Array = continuity.get("action_bonuses", []) if continuity.get("action_bonuses", []) is Array else []
	var ultra_score: float = strategy.score_action_absolute_with_plan(
		{"kind": "play_trainer", "card": CardInstance.create(_make_trainer_cd(ULTRA_BALL), 0)},
		gs,
		0,
		turn_contract
	)
	var attack_score: float = strategy.score_action_absolute_with_plan(
		{"kind": "attack", "source_slot": player.active_pokemon, "attack_name": "Trinity Nova", "projected_damage": 180, "projected_knockout": false},
		gs,
		0,
		turn_contract
	)
	return run_checks([
		assert_true(bool(debt.get("continuity_complete", false)), "Ready backup Arceus, ready Giratina VSTAR, and engine seed should complete continuity"),
		assert_false(bool(continuity.get("enabled", false)), "Complete continuity should stop emitting setup bonuses"),
		assert_eq(bonuses.size(), 0, "Complete continuity should not inflate extra search/churn actions"),
		assert_gt(attack_score, ultra_score, "After continuity is complete, generic Ultra Ball should stay below attack (attack=%f ultra=%f)" % [attack_score, ultra_score]),
	])


func _new_strategy() -> RefCounted:
	CardInstance.reset_id_counter()
	var script: Variant = load(STRATEGY_PATH)
	return script.new() if script is GDScript else null


func _make_game_state(turn: int = 5) -> GameState:
	var gs := GameState.new()
	gs.turn_number = turn
	gs.current_player_index = 0
	gs.first_player_index = 0
	gs.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gs.players.append(player)
	return gs


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


func _make_arceus_vstar_cd() -> CardData:
	return _make_pokemon_cd(
		ARCEUS_VSTAR,
		"VSTAR",
		"C",
		280,
		ARCEUS_V,
		"V",
		[{"name": "Trinity Nova", "cost": "CCC", "damage": "200"}],
		2
	)


func _make_arceus_v_cd() -> CardData:
	return _make_pokemon_cd(
		ARCEUS_V,
		"Basic",
		"C",
		220,
		"",
		"V",
		[
			{"name": "Trinity Charge", "cost": "CC", "damage": ""},
			{"name": "Power Edge", "cost": "CCC", "damage": "130"},
		],
		2
	)


func _make_giratina_v_cd() -> CardData:
	return _make_pokemon_cd(
		GIRATINA_V,
		"Basic",
		"N",
		220,
		"",
		"V",
		[
			{"name": "Abyss Seeking", "cost": "C", "damage": ""},
			{"name": "Shred", "cost": "GPC", "damage": "160"},
		],
		2
	)


func _make_giratina_vstar_cd() -> CardData:
	return _make_pokemon_cd(
		GIRATINA_VSTAR,
		"VSTAR",
		"N",
		280,
		GIRATINA_V,
		"V",
		[{"name": "Lost Impact", "cost": "GPC", "damage": "280"}],
		2
	)


func _make_bibarel_cd() -> CardData:
	return _make_pokemon_cd(BIBAREL, "Stage 1", "C", 120, BIDOOF, "", [{"name": "Tail Smash", "cost": "CCC", "damage": "100"}])


func _make_skwovet_cd() -> CardData:
	return _make_pokemon_cd(SKWOVET, "Basic", "C", 60, "", "", [{"name": "Tackle", "cost": "C", "damage": "10"}])


func _make_slot(card_data: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner))
	slot.turn_played = 0
	return slot


func _arceus_vstar() -> PokemonSlot:
	return _make_slot(_make_arceus_vstar_cd(), 0)


func _giratina_vstar() -> PokemonSlot:
	return _make_slot(_make_giratina_vstar_cd(), 0)


func _make_energy_cd(pname: String, card_type: String, provides: String = "") -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.name_en = pname
	cd.card_type = card_type
	cd.energy_provides = provides
	return cd


func _make_trainer_cd(pname: String, card_type: String = "Item") -> CardData:
	var cd := CardData.new()
	cd.name = pname
	cd.name_en = pname
	cd.card_type = card_type
	return cd


func _energy(name: String) -> CardInstance:
	if name == DOUBLE_TURBO_ENERGY:
		return CardInstance.create(_make_energy_cd(name, "Special Energy"), 0)
	if name == GRASS_ENERGY:
		return CardInstance.create(_make_energy_cd(name, "Basic Energy", "G"), 0)
	if name == PSYCHIC_ENERGY:
		return CardInstance.create(_make_energy_cd(name, "Basic Energy", "P"), 0)
	return CardInstance.create(_make_energy_cd(name, "Basic Energy", "C"), 0)


func _attach(slot: PokemonSlot, names: Array[String]) -> void:
	for name: String in names:
		slot.attached_energy.append(_energy(name))


func _fill_prizes(player: PlayerState, count: int) -> void:
	player.prizes.clear()
	for i: int in count:
		player.prizes.append(CardInstance.create(_make_trainer_cd("Prize%d" % i), player.player_index))


func _fill_deck(player: PlayerState, count: int) -> void:
	player.deck.clear()
	for i: int in count:
		player.deck.append(CardInstance.create(_make_trainer_cd("Deck%d" % i), player.player_index))


func _contract_has_bonus(contract: Dictionary, kind: String, card_name: String) -> bool:
	var raw_bonuses: Variant = contract.get("action_bonuses", [])
	if not (raw_bonuses is Array):
		return false
	for item: Variant in raw_bonuses:
		if not (item is Dictionary):
			continue
		var bonus: Dictionary = item
		if str(bonus.get("kind", "")) != kind:
			continue
		var card_names: Variant = bonus.get("card_names", [])
		if card_names is Array and card_name in (card_names as Array):
			return true
	return false
