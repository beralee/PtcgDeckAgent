class_name TestLugiaArcheopsStrategyIteration
extends TestBase


const LUGIA_SCRIPT_PATH := "res://scripts/ai/DeckStrategyLugiaArcheops.gd"
const DOUBLE_TURBO_ENERGY := "Double Turbo Energy"
const GIFT_ENERGY := "Gift Energy"
const JET_ENERGY := "Jet Energy"
const MIST_ENERGY := "Mist Energy"


func _new_strategy() -> RefCounted:
	CardInstance.reset_id_counter()
	var script: Variant = load(LUGIA_SCRIPT_PATH)
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
			[{"name": "Myriad Leaf Shower", "cost": "WCC", "damage": "140"}]
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
	_attach(active_lugia, [DOUBLE_TURBO_ENERGY, GIFT_ENERGY, JET_ENERGY, MIST_ENERGY])
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
