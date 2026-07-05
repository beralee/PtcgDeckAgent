extends "res://tests/helpers/MissingCardBatch202603Shared.gd"

func test_csv6c_116_techno_radar_can_play_with_one_other_hand_card() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.deck.clear()
	player.discard_pile.clear()

	var radar_cd: CardData = CardDatabase.get_card("CSV6C", "116")
	var radar := CardInstance.create(radar_cd, 0)
	var discard_card := CardInstance.create(_make_basic_pokemon_data("Radar Fodder", "C"), 0)
	player.hand.append_array([radar, discard_card])

	var future_a := CardInstance.create(_make_basic_pokemon_data("Future A", "L"), 0)
	future_a.card_data.is_tags = PackedStringArray([CardData.FUTURE_TAG])
	var future_b := CardInstance.create(_make_basic_pokemon_data("Future B", "P"), 0)
	future_b.card_data.is_tags = PackedStringArray([CardData.FUTURE_TAG])
	var normal := CardInstance.create(_make_basic_pokemon_data("Normal C", "W"), 0)
	player.deck.append_array([future_a, future_b, normal])

	var played := gsm.play_trainer(0, radar, [{
		"discard_cards": [discard_card],
		"search_future_pokemon": [future_a, future_b],
	}])

	return run_checks([
		assert_not_null(radar_cd, "CSV6C_116 should exist in the card database"),
		assert_true(played, "CSV6C_116 should be playable when the hand only has one other card"),
		assert_true(discard_card in player.discard_pile, "CSV6C_116 should discard exactly the selected card"),
		assert_true(radar in player.discard_pile, "CSV6C_116 itself should go to the discard pile after use"),
		assert_true(future_a in player.hand and future_b in player.hand, "CSV6C_116 should add up to two Future Pokemon to hand"),
		assert_false(normal in player.hand, "CSV6C_116 should not add non-Future Pokemon"),
	])


func test_cs6_5c_070_lance_searches_selected_dragon_pokemon() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.deck.clear()
	player.discard_pile.clear()

	var lance_cd: CardData = CardDatabase.get_card("CS6.5C", "070")
	var lance := CardInstance.create(lance_cd, 0)
	player.hand.append(lance)

	var dreepy_cd: CardData = CardDatabase.get_card("CSV8C", "157")
	var drakloak_cd: CardData = CardDatabase.get_card("CSV8C", "158")
	var dragapult_cd: CardData = CardDatabase.get_card("CSV8C", "159")
	var manaphy_cd: CardData = CardDatabase.get_card("CS5bC", "052")
	var dreepy := CardInstance.create(dreepy_cd, 0)
	var drakloak := CardInstance.create(drakloak_cd, 0)
	var dragapult := CardInstance.create(dragapult_cd, 0)
	var manaphy := CardInstance.create(manaphy_cd, 0)
	player.deck.append_array([manaphy, dreepy, drakloak, dragapult])

	var played := gsm.play_trainer(0, lance, [{
		"dragon_pokemon": [dragapult, dreepy],
	}])

	return run_checks([
		assert_not_null(lance_cd, "CS6.5C_070 should exist in the card database"),
		assert_true(played, "CS6.5C_070 should be playable when the deck contains Dragon Pokemon"),
		assert_true(lance in player.discard_pile, "CS6.5C_070 itself should go to the discard pile after use"),
		assert_true(dreepy in player.hand and dragapult in player.hand, "CS6.5C_070 should add the selected Dragon Pokemon to hand"),
		assert_true(drakloak in player.deck, "CS6.5C_070 should leave unselected Dragon Pokemon in the deck"),
		assert_true(manaphy in player.deck, "CS6.5C_070 should not add non-Dragon Pokemon"),
	])


func test_csvh1c_035_energy_search_adds_one_basic_energy_to_hand() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.deck.clear()
	player.discard_pile.clear()

	var energy_search_cd: CardData = CardDatabase.get_card("CSVH1C", "035")
	var energy_search := CardInstance.create(energy_search_cd, 0)
	player.hand.append(energy_search)

	var basic_fire := CardInstance.create(_make_energy_data("Fire Energy", "R"), 0)
	var basic_psychic := CardInstance.create(_make_energy_data("Psychic Energy", "P"), 0)
	var special_energy := CardInstance.create(_make_energy_data("Jet Energy", "C", "Special Energy"), 0)
	player.deck.append_array([special_energy, basic_fire, basic_psychic])

	var played := gsm.play_trainer(0, energy_search, [{
		"search_energy": [basic_fire],
	}])

	return run_checks([
		assert_not_null(energy_search_cd, "CSVH1C_035 should exist in the card database"),
		assert_true(played, "CSVH1C_035 should be playable when the deck contains Basic Energy"),
		assert_true(energy_search in player.discard_pile, "CSVH1C_035 itself should go to the discard pile after use"),
		assert_true(basic_fire in player.hand, "CSVH1C_035 should add the selected Basic Energy to hand"),
		assert_true(basic_psychic in player.deck, "CSVH1C_035 should leave unselected Basic Energy in the deck"),
		assert_false(special_energy in player.hand, "CSVH1C_035 should not add Special Energy"),
	])


func test_cs4dac_056_entei_v_fleet_footed_and_burning_rondo() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	player.hand.clear()
	player.deck.clear()

	var entei_cd: CardData = CardDatabase.get_card("CS4DaC", "056")
	gsm.effect_processor.register_pokemon_card(entei_cd)
	var attacker := _make_slot(entei_cd, 0)
	attacker.attached_energy.append(CardInstance.create(_make_energy_data("Fire A", "R"), 0))
	attacker.attached_energy.append(CardInstance.create(_make_energy_data("Fire B", "R"), 0))
	player.active_pokemon = attacker
	player.deck.append(CardInstance.create(_make_trainer_data("Drawn Card", "Item"), 0))

	var can_use_ability := gsm.effect_processor.can_use_ability(attacker, state, 0)
	var used_ability := gsm.use_ability(0, attacker, 0)
	var attacked := gsm.use_attack(0, 0)
	var expected_damage := 20 + 20 * (player.bench.size() + opponent.bench.size())

	return run_checks([
		assert_not_null(entei_cd, "CS4DaC_056 should exist in the card database"),
		assert_true(can_use_ability, "CS4DaC_056 should be able to use Fleet-Footed while Active"),
		assert_true(used_ability, "CS4DaC_056 should draw 1 card with Fleet-Footed"),
		assert_eq(player.hand.size(), 1, "CS4DaC_056 Fleet-Footed should draw exactly 1 card"),
		assert_true(attacked, "CS4DaC_056 should use Burning Rondo successfully"),
		assert_eq(opponent.active_pokemon.damage_counters, expected_damage, "CS4DaC_056 Burning Rondo should add 20 for each Benched Pokemon in play"),
	])


func test_cs5dc_126_dark_patch_attaches_to_benched_dark_pokemon() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.discard_pile.clear()

	var dark_patch_cd: CardData = CardDatabase.get_card("CS5DC", "126")
	var dark_patch := CardInstance.create(dark_patch_cd, 0)
	player.hand.append(dark_patch)

	var dark_target := player.bench[0]
	dark_target.pokemon_stack.clear()
	dark_target.pokemon_stack.append(CardInstance.create(_make_basic_pokemon_data("Dark Bench", "D", 120), 0))
	var non_dark_target := player.bench[1]
	non_dark_target.pokemon_stack.clear()
	non_dark_target.pokemon_stack.append(CardInstance.create(_make_basic_pokemon_data("Fire Bench", "R", 120), 0))

	var dark_energy := CardInstance.create(_make_energy_data("Darkness Energy", "D"), 0)
	var fire_energy := CardInstance.create(_make_energy_data("Fire Energy", "R"), 0)
	player.discard_pile.append_array([dark_energy, fire_energy])

	var played := gsm.play_trainer(0, dark_patch, [{
		"dark_patch_assignment": [{
			"source": dark_energy,
			"target": dark_target,
		}],
	}])

	return run_checks([
		assert_not_null(dark_patch_cd, "CS5DC_126 should exist in the card database"),
		assert_true(played, "CS5DC_126 should be playable with a Basic Darkness Energy in discard and a Benched Darkness Pokemon"),
		assert_true(dark_patch in player.discard_pile, "CS5DC_126 itself should go to the discard pile after use"),
		assert_true(dark_energy in dark_target.attached_energy, "CS5DC_126 should attach the selected Basic Darkness Energy to the chosen Benched Darkness Pokemon"),
		assert_true(fire_energy in player.discard_pile, "CS5DC_126 should leave non-Dark Energy in the discard pile"),
		assert_true(non_dark_target.attached_energy.is_empty(), "CS5DC_126 should not attach Energy to non-Dark Benched Pokemon"),
	])


func test_cs6_5c_012_delphox_v_strange_flames_applies_burned_and_confused() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	gsm.effect_processor.coin_flipper = RiggedCoinFlipper.new([false])
	var state := gsm.game_state
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]

	var delphox_cd: CardData = CardDatabase.get_card("CS6.5C", "012")
	gsm.effect_processor.register_pokemon_card(delphox_cd)
	var attacker := _make_slot(delphox_cd, 0)
	attacker.attached_energy.append(CardInstance.create(_make_energy_data("Fire Energy", "R"), 0))
	player.active_pokemon = attacker

	var attacked := gsm.use_attack(0, 0)

	return run_checks([
		assert_not_null(delphox_cd, "CS6.5C_012 should exist in the card database"),
		assert_true(attacked, "CS6.5C_012 should use Strange Flames successfully"),
		assert_true(opponent.active_pokemon.status_conditions.get("burned", false), "CS6.5C_012 should Burn the opponent Active Pokemon"),
		assert_true(opponent.active_pokemon.status_conditions.get("confused", false), "CS6.5C_012 should Confuse the opponent Active Pokemon"),
	])


func test_cs6_5c_012_delphox_v_magical_fire_lost_zones_two_energy_and_hits_selected_bench() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	player.lost_zone.clear()

	var delphox_cd: CardData = CardDatabase.get_card("CS6.5C", "012")
	gsm.effect_processor.register_pokemon_card(delphox_cd)
	var attacker := _make_slot(delphox_cd, 0)
	var energy_a := CardInstance.create(_make_energy_data("Fire A", "R"), 0)
	var energy_b := CardInstance.create(_make_energy_data("Fire B", "R"), 0)
	var energy_c := CardInstance.create(_make_energy_data("Fire C", "R"), 0)
	attacker.attached_energy.append_array([energy_a, energy_b, energy_c])
	player.active_pokemon = attacker

	var attack_effects: Array[BaseEffect] = gsm.effect_processor.get_attack_effects_for_slot(attacker, 1)
	var steps: Array[Dictionary] = []
	for effect: BaseEffect in attack_effects:
		steps.append_array(effect.get_attack_interaction_steps(attacker.get_top_card(), delphox_cd.attacks[1], state))

	var chosen_bench := opponent.bench[1]
	var untouched_bench := opponent.bench[0]
	var attacked := gsm.use_attack(0, 1, [{
		"delphox_v_lost_zone_energy": [energy_a, energy_b],
		"delphox_v_bench_target": [chosen_bench],
	}])

	return run_checks([
		assert_true(attacked, "CS6.5C_012 should use Magical Fire successfully"),
		assert_eq(steps.size(), 2, "CS6.5C_012 Magical Fire should ask for Energy and a Benched target"),
		assert_eq(int(steps[0].get("min_select", -1)), 2, "CS6.5C_012 Magical Fire should require selecting exactly 2 attached Energy"),
		assert_eq(int(steps[1].get("max_select", -1)), 1, "CS6.5C_012 Magical Fire should only allow 1 Benched target"),
		assert_true(energy_a in player.lost_zone and energy_b in player.lost_zone, "CS6.5C_012 Magical Fire should put 2 chosen Energy into the Lost Zone"),
		assert_true(energy_c in attacker.attached_energy, "CS6.5C_012 Magical Fire should leave unchosen attached Energy in place"),
		assert_eq(opponent.active_pokemon.damage_counters, 120, "CS6.5C_012 Magical Fire should still deal its printed 120 to the opponent Active Pokemon"),
		assert_eq(chosen_bench.damage_counters, 120, "CS6.5C_012 Magical Fire should deal 120 to the selected Benched Pokemon"),
		assert_eq(untouched_bench.damage_counters, 0, "CS6.5C_012 Magical Fire should not damage unselected Benched Pokemon"),
	])


func test_csv7c_051_gouging_fire_ex_blazing_charge_locks_until_it_leaves_active() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	var player: PlayerState = state.players[0]

	var gouging_cd: CardData = CardDatabase.get_card("CSV7C", "051")
	gsm.effect_processor.register_pokemon_card(gouging_cd)
	var attacker := _make_slot(gouging_cd, 0)
	var energy_a := CardInstance.create(_make_energy_data("Fire A", "R"), 0)
	var energy_b := CardInstance.create(_make_energy_data("Fire B", "R"), 0)
	var energy_c := CardInstance.create(_make_energy_data("Fire C", "R"), 0)
	attacker.attached_energy.append_array([energy_a, energy_b, energy_c])
	player.active_pokemon = attacker
	state.players[1].active_pokemon.damage_counters = 0
	state.players[1].active_pokemon.pokemon_stack[0].card_data.hp = 400

	var first_attack := gsm.use_attack(0, 1)
	state.current_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	var locked_reason := gsm.get_attack_unusable_reason(0, 1)

	var retreat_target: PokemonSlot = player.bench[0]
	var retreated := gsm.retreat(0, [energy_a, energy_b], retreat_target)
	var benched_attacker: PokemonSlot = player.bench.back()
	EffectSwitchPokemon.new("self").execute(
		CardInstance.create(_make_trainer_data("Switch", "Item"), 0),
		[{"self_switch_target": [benched_attacker]}],
		state
	)
	benched_attacker.attached_energy.append(CardInstance.create(_make_energy_data("Refill A", "R"), 0))
	benched_attacker.attached_energy.append(CardInstance.create(_make_energy_data("Refill B", "R"), 0))
	state.current_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	var unlocked_reason := gsm.get_attack_unusable_reason(0, 1)

	return run_checks([
		assert_not_null(gouging_cd, "CSV7C_051 should exist in the card database"),
		assert_true(first_attack, "CSV7C_051 should use Blazing Charge successfully the first time"),
		assert_str_contains(locked_reason, "离开战斗场前", "CSV7C_051 should block Blazing Charge while it remains Active"),
		assert_true(retreated, "CSV7C_051 should be able to retreat and leave the Active Spot"),
		assert_eq(unlocked_reason, "", "CSV7C_051 should be able to use Blazing Charge again after leaving the Active Spot"),
	])


func test_cs5dc_152_magma_basin_attaches_fire_from_discard_once_per_turn() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state: GameState = gsm.game_state
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.discard_pile.clear()

	var magma_cd: CardData = CardDatabase.get_card("CS5DC", "152")
	var magma_basin := CardInstance.create(magma_cd, 0)
	player.hand.append(magma_basin)

	var fire_target := player.bench[0]
	fire_target.pokemon_stack.clear()
	fire_target.pokemon_stack.append(CardInstance.create(_make_basic_pokemon_data("Fire Bench", "R", 130), 0))
	var fire_energy := CardInstance.create(_make_energy_data("Fire Energy", "R"), 0)
	player.discard_pile.append(fire_energy)

	var played := gsm.play_stadium(0, magma_basin)
	var first_use := gsm.use_stadium_effect(0, [{
		"magma_basin_assignment": [{
			"source": fire_energy,
			"target": fire_target,
		}],
	}])
	var second_use_same_turn := gsm.use_stadium_effect(0)

	return run_checks([
		assert_not_null(magma_cd, "CS5DC_152 should exist in the card database"),
		assert_true(played, "CS5DC_152 should be playable as a Stadium"),
		assert_true(first_use, "CS5DC_152 should let the current player use the Stadium effect once"),
		assert_true(fire_energy in fire_target.attached_energy, "CS5DC_152 should attach the selected Basic Fire Energy from discard"),
		assert_eq(fire_target.damage_counters, 20, "CS5DC_152 should place 2 damage counters on the chosen Pokemon"),
		assert_false(second_use_same_turn, "CS5DC_152 should not be reusable by the same player in the same turn"),
	])


func test_cs5dc_152_magma_basin_remains_usable_after_a_different_stadium_effect_same_turn() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state: GameState = gsm.game_state
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.deck.clear()
	player.discard_pile.clear()
	player.bench.clear()

	var tool_card := CardInstance.create(_make_trainer_data("Tool A", "Tool"), 0)
	player.deck.append(tool_card)

	var town_store := CardInstance.create(_make_trainer_data("Town Store", "Stadium", "13b3caaa408a85dfd1e2a5ad797e8b8a"), 0)
	state.stadium_card = town_store
	state.stadium_owner_index = 0
	var used_town_store := gsm.use_stadium_effect(0, [{
		"town_store_tool": [tool_card],
	}])

	var magma_cd: CardData = CardDatabase.get_card("CS5DC", "152")
	var magma_basin := CardInstance.create(magma_cd, 0)
	player.hand.append(magma_basin)

	var fire_target := _make_slot(_make_basic_pokemon_data("Fire Bench", "R", 130), 0)
	player.bench.append(fire_target)
	var fire_energy := CardInstance.create(_make_energy_data("Fire Energy", "R"), 0)
	player.discard_pile.append(fire_energy)

	var played_magma_basin := gsm.play_stadium(0, magma_basin)
	var used_magma_basin := gsm.use_stadium_effect(0, [{
		"magma_basin_assignment": [{
			"source": fire_energy,
			"target": fire_target,
		}],
	}])

	return run_checks([
		assert_not_null(magma_cd, "CS5DC_152 should exist in the card database"),
		assert_true(used_town_store, "A different Stadium effect should still be usable earlier in the turn"),
		assert_true(played_magma_basin, "CS5DC_152 should be playable after another Stadium was already in play"),
		assert_true(used_magma_basin, "CS5DC_152 should remain usable after a different Stadium effect was used this turn"),
		assert_true(fire_energy in fire_target.attached_energy, "CS5DC_152 should still attach the selected Basic Fire Energy after switching from another Stadium"),
		assert_eq(fire_target.damage_counters, 20, "CS5DC_152 should still place 2 damage counters after another Stadium effect"),
	])


func test_cs55c_007_radiant_charizard_reduces_cost_without_discarding_energy() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state: GameState = gsm.game_state
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]

	var radiant_charizard_cd: CardData = CardDatabase.get_card("CS5.5C", "007")
	if radiant_charizard_cd == null:
		return "未找到缓存卡 CS5.5C/007"
	gsm.effect_processor.register_pokemon_card(radiant_charizard_cd)

	var attacker := PokemonSlot.new()
	attacker.pokemon_stack.append(CardInstance.create(radiant_charizard_cd, 0))
	attacker.attached_energy.append(CardInstance.create(_make_energy_data("Fire Energy", "R"), 0))
	player.active_pokemon = attacker

	var bulky_target_cd := _make_basic_pokemon_data("Bulky Target", "G", 330)
	var bulky_target := PokemonSlot.new()
	bulky_target.pokemon_stack.append(CardInstance.create(bulky_target_cd, 1))
	opponent.active_pokemon = bulky_target

	opponent.prizes.clear()
	for i: int in 3:
		opponent.prizes.append(CardInstance.create(_make_basic_pokemon_data("Prize %d" % i, "C"), 1))
	var insufficient_reason: String = gsm.get_attack_unusable_reason(0, 0)

	opponent.prizes.pop_back()
	var usable_reason: String = gsm.get_attack_unusable_reason(0, 0)
	var first_attack: bool = gsm.use_attack(0, 0)
	var energy_after_attack: int = attacker.attached_energy.size()
	var target_damage_after_attack: int = opponent.active_pokemon.damage_counters

	gsm.end_turn(1)
	var locked_reason: String = gsm.get_attack_unusable_reason(0, 0)

	gsm.end_turn(0)
	gsm.end_turn(1)
	var unlocked_reason: String = gsm.get_attack_unusable_reason(0, 0)

	return run_checks([
		assert_not_null(radiant_charizard_cd, "CS5.5C_007 should exist in the card database"),
		assert_str_contains(insufficient_reason, "能量不足", "CS5.5C_007 should still require more than 1 Fire Energy before the opponent has taken 4 prizes"),
		assert_eq(usable_reason, "", "CS5.5C_007 should become usable with only 1 Fire Energy after the opponent has taken 4 prizes"),
		assert_true(first_attack, "CS5.5C_007 should use Combustion Blast successfully once Excited Heart reduces the cost"),
		assert_eq(energy_after_attack, 1, "CS5.5C_007 Combustion Blast should not discard the remaining Fire Energy"),
		assert_eq(target_damage_after_attack, 250, "CS5.5C_007 Combustion Blast should still deal its printed 250 damage"),
		assert_str_contains(locked_reason, "下回合", "CS5.5C_007 should lock Combustion Blast during the next turn"),
		assert_eq(unlocked_reason, "", "CS5.5C_007 should be able to use Combustion Blast again after waiting out the lock"),
	])


func test_cs55c_007_radiant_charizard_excited_heart_is_suppressed_by_iron_thorns() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state: GameState = gsm.game_state
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]

	var radiant_charizard_cd: CardData = CardDatabase.get_card("CS5.5C", "007")
	if radiant_charizard_cd == null:
		return "Missing cached card CS5.5C/007"
	gsm.effect_processor.register_pokemon_card(radiant_charizard_cd)

	var attacker := PokemonSlot.new()
	attacker.pokemon_stack.append(CardInstance.create(radiant_charizard_cd, 0))
	attacker.attached_energy.append(CardInstance.create(_make_energy_data("Fire Energy", "R"), 0))
	player.active_pokemon = attacker
	opponent.active_pokemon = _make_slot(_make_basic_pokemon_data("Normal Defender", "G", 330), 1)
	opponent.prizes.clear()
	for i: int in 2:
		opponent.prizes.append(CardInstance.create(_make_basic_pokemon_data("Prize %d" % i, "C"), 1))

	var usable_before_lock := gsm.can_use_attack(0, 0)

	var iron_thorns_cd := _make_basic_pokemon_data("Iron Thorns ex", "L", 230, "Basic", "ex")
	iron_thorns_cd.abilities = [{"name": "初始化"}]
	iron_thorns_cd.is_tags = ["Future"]
	opponent.active_pokemon = _make_slot(iron_thorns_cd, 1)
	var usable_under_lock := gsm.can_use_attack(0, 0)

	return run_checks([
		assert_true(usable_before_lock, "Radiant Charizard should attack with 1 Fire once Excited Heart is active"),
		assert_false(usable_under_lock, "Iron Thorns should suppress Radiant Charizard's Excited Heart cost reduction"),
	])


func test_cs5ac_006_moltres_fiery_wrath_scales_if_damaged_and_ignores_weakness() -> String:
	var moltres_cd: CardData = CardDatabase.get_card("CS5aC", "006")

	var baseline_gsm := GameStateMachine.new()
	baseline_gsm.game_state = _make_state()
	var baseline_state: GameState = baseline_gsm.game_state
	var baseline_player: PlayerState = baseline_state.players[0]
	var baseline_opponent: PlayerState = baseline_state.players[1]
	var weak_target_cd := _make_basic_pokemon_data("Weak Target", "G", 130)
	weak_target_cd.weakness_energy = "R"
	weak_target_cd.weakness_value = "2"
	var baseline_attacker := _make_slot(moltres_cd, 0)
	baseline_attacker.attached_energy.append(CardInstance.create(_make_energy_data("Fire Energy", "R"), 0))
	baseline_player.active_pokemon = baseline_attacker
	baseline_opponent.active_pokemon = _make_slot(weak_target_cd, 1)
	baseline_gsm.effect_processor.register_pokemon_card(moltres_cd)
	var baseline_attack := baseline_gsm.use_attack(0, 0)

	var boosted_gsm := GameStateMachine.new()
	boosted_gsm.game_state = _make_state()
	var boosted_state: GameState = boosted_gsm.game_state
	var boosted_player: PlayerState = boosted_state.players[0]
	var boosted_opponent: PlayerState = boosted_state.players[1]
	var boosted_target_cd := _make_basic_pokemon_data("Boosted Weak Target", "G", 130)
	boosted_target_cd.weakness_energy = "R"
	boosted_target_cd.weakness_value = "2"
	var boosted_attacker := _make_slot(moltres_cd, 0)
	boosted_attacker.attached_energy.append(CardInstance.create(_make_energy_data("Fire Energy", "R"), 0))
	boosted_attacker.damage_counters = 10
	boosted_player.active_pokemon = boosted_attacker
	boosted_opponent.active_pokemon = _make_slot(boosted_target_cd, 1)
	boosted_gsm.effect_processor.register_pokemon_card(moltres_cd)
	var boosted_attack := boosted_gsm.use_attack(0, 0)

	return run_checks([
		assert_not_null(moltres_cd, "CS5aC_006 should exist in the card database"),
		assert_true(baseline_gsm.effect_processor.has_attack_effect(moltres_cd.effect_id), "CS5aC_006 should register its scripted attack"),
		assert_true(baseline_attack, "CS5aC_006 should use Fiery Wrath successfully without self damage"),
		assert_eq(baseline_opponent.active_pokemon.damage_counters, 20, "CS5aC_006 should deal its printed 20 damage without applying Weakness"),
		assert_true(boosted_attack, "CS5aC_006 should use Fiery Wrath successfully with self damage"),
		assert_eq(boosted_opponent.active_pokemon.damage_counters, 90, "CS5aC_006 should add 70 damage when it already has damage counters and still ignore Weakness"),
	])


func test_csv2c_028_froakie_hop_step_maps_to_fail_on_tails() -> String:
	var processor := EffectProcessor.new()
	var froakie_cd: CardData = CardDatabase.get_card("CSV2C", "028")
	processor.register_pokemon_card(froakie_cd)
	var froakie_slot := _make_slot(froakie_cd, 0)
	var froakie_effects: Array[BaseEffect] = processor.get_attack_effects_for_slot(froakie_slot, 0)
	var froakie_effect: BaseEffect = froakie_effects[0] if not froakie_effects.is_empty() else null

	return run_checks([
		assert_not_null(froakie_cd, "CSV2C_028 should exist in the card database"),
		assert_true(froakie_effects.size() >= 1, "CSV2C_028 should register an attack effect for Hop Step"),
		assert_true(froakie_effect is AttackCoinFlipOrFail, "CSV2C_028 should fail on tails instead of always dealing damage"),
		assert_eq((froakie_effect as AttackCoinFlipOrFail).base_damage if froakie_effect is AttackCoinFlipOrFail else -1, 30, "CSV2C_028 should only cancel its printed 30 damage on tails"),
	])


func test_csv7c_123_greninja_ex_shinobi_blade_searches_selected_card_to_hand() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.deck.clear()

	var greninja_cd: CardData = CardDatabase.get_card("CSV7C", "123")
	var attacker := _make_slot(greninja_cd, 0)
	player.active_pokemon = attacker
	var chosen := CardInstance.create(_make_trainer_data("Chosen Card", "Item"), 0)
	var other := CardInstance.create(_make_energy_data("Water Energy", "W"), 0)
	player.deck.append(other)
	player.deck.append(chosen)

	var processor := EffectProcessor.new()
	processor.register_pokemon_card(greninja_cd)
	var attack_effects: Array[BaseEffect] = processor.get_attack_effects_for_slot(attacker, 0)
	var steps: Array[Dictionary] = []
	for effect: BaseEffect in attack_effects:
		steps.append_array(effect.get_attack_interaction_steps(attacker.get_top_card(), greninja_cd.attacks[0], state))
	processor.execute_attack_effect(attacker, 0, state.players[1].active_pokemon, state, [{
		"greninja_ex_search_card": [chosen],
	}])

	return run_checks([
		assert_not_null(greninja_cd, "CSV7C_123 should exist in the card database"),
		assert_true(attack_effects.size() >= 1, "CSV7C_123 attack 0 should register an effect"),
		assert_eq(steps.size(), 1, "CSV7C_123 Shinobi Blade should present one optional search step"),
		assert_eq(int(steps[0].get("min_select", -1)), 0, "CSV7C_123 Shinobi Blade should allow skipping the deck search"),
		assert_eq(int(steps[0].get("max_select", -1)), 1, "CSV7C_123 Shinobi Blade should only allow choosing 1 card"),
		assert_contains(player.hand, chosen, "CSV7C_123 Shinobi Blade should put the chosen card into hand"),
		assert_contains(player.deck, other, "CSV7C_123 Shinobi Blade should leave unchosen cards in the deck"),
		assert_false(chosen in player.deck, "CSV7C_123 Shinobi Blade should remove the chosen card from the deck"),
	])


func test_csv7c_123_greninja_ex_mirage_barrage_discards_two_energy_and_hits_two_selected_targets() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	player.discard_pile.clear()

	var greninja_cd: CardData = CardDatabase.get_card("CSV7C", "123")
	var attacker := _make_slot(greninja_cd, 0)
	player.active_pokemon = attacker
	var energy_a := CardInstance.create(_make_energy_data("Water A", "W"), 0)
	var energy_b := CardInstance.create(_make_energy_data("Water B", "W"), 0)
	var energy_c := CardInstance.create(_make_energy_data("Psychic C", "P"), 0)
	attacker.attached_energy.append_array([energy_a, energy_b, energy_c])
	var chosen_active := opponent.active_pokemon
	var chosen_bench := opponent.bench[1]
	var untouched_bench := opponent.bench[0]

	var processor := EffectProcessor.new()
	processor.register_pokemon_card(greninja_cd)
	var attack_effects: Array[BaseEffect] = processor.get_attack_effects_for_slot(attacker, 1)
	var steps: Array[Dictionary] = []
	for effect: BaseEffect in attack_effects:
		steps.append_array(effect.get_attack_interaction_steps(attacker.get_top_card(), greninja_cd.attacks[1], state))
	var discard_step: Dictionary = steps[0] if not steps.is_empty() else {}
	var target_step: Dictionary = steps[1] if steps.size() > 1 else {}
	processor.execute_attack_effect(attacker, 1, chosen_active, state, [{
		"greninja_ex_discard_energy": [energy_a, energy_b],
		"greninja_ex_targets": [chosen_active, chosen_bench],
	}])

	return run_checks([
		assert_not_null(greninja_cd, "CSV7C_123 should exist in the card database"),
		assert_true(attack_effects.size() >= 1, "CSV7C_123 attack 1 should register an effect"),
		assert_eq(steps.size(), 2, "CSV7C_123 Mirage Barrage should ask for discarded Energy and damaged targets"),
		assert_eq(int(discard_step.get("min_select", -1)), 2, "CSV7C_123 Mirage Barrage should require discarding exactly 2 Energy"),
		assert_eq(int(target_step.get("min_select", -1)), 2, "CSV7C_123 Mirage Barrage should require choosing exactly 2 targets"),
		assert_contains(player.discard_pile, energy_a, "CSV7C_123 Mirage Barrage should discard the first chosen Energy"),
		assert_contains(player.discard_pile, energy_b, "CSV7C_123 Mirage Barrage should discard the second chosen Energy"),
		assert_contains(attacker.attached_energy, energy_c, "CSV7C_123 Mirage Barrage should leave unchosen attached Energy in place"),
		assert_eq(chosen_active.damage_counters, 120, "CSV7C_123 Mirage Barrage should deal 120 to the selected Active target"),
		assert_eq(chosen_bench.damage_counters, 120, "CSV7C_123 Mirage Barrage should deal 120 to the selected Benched target"),
		assert_eq(untouched_bench.damage_counters, 0, "CSV7C_123 Mirage Barrage should not damage unselected Pokemon"),
	])


func test_csv2c_118_erikas_invitation_brings_out_basic_from_opponent_hand() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	player.hand.clear()
	opponent.hand.clear()

	var erika_cd: CardData = CardDatabase.get_card("CSV2C", "118")
	var erika := CardInstance.create(erika_cd, 0)
	player.hand.append(erika)

	var invited_basic := CardInstance.create(_make_basic_pokemon_data("Invited Basic", "C", 70), 1)
	var non_basic_cd := _make_basic_pokemon_data("Bench Evolution", "C", 100, "Stage1")
	var non_basic := CardInstance.create(non_basic_cd, 1)
	opponent.hand.append_array([invited_basic, non_basic])
	var original_active := opponent.active_pokemon

	var played := gsm.play_trainer(0, erika, [{
		"opponent_basic_in_hand": [invited_basic],
	}])

	return run_checks([
		assert_not_null(erika_cd, "CSV2C_118 should exist in the card database"),
		assert_true(played, "CSV2C_118 should be playable when the opponent has a Basic Pokemon in hand"),
		assert_true(erika in player.discard_pile, "CSV2C_118 itself should go to the discard pile after use"),
		assert_eq(opponent.active_pokemon.get_top_card(), invited_basic, "CSV2C_118 should bring the selected Basic Pokemon to the opponent Active Spot"),
		assert_contains(opponent.bench, original_active, "CSV2C_118 should move the old opponent Active Pokemon to the Bench"),
		assert_false(invited_basic in opponent.hand, "CSV2C_118 should remove the selected Basic Pokemon from the opponent hand"),
		assert_contains(opponent.hand, non_basic, "CSV2C_118 should leave non-Basic Pokemon in the opponent hand"),
	])


func test_csv8c_195_xerosics_machinations_makes_opponent_discard_to_three() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	player.hand.clear()
	opponent.hand.clear()

	var xerosic_cd: CardData = CardDatabase.get_card("CSV8C", "195")
	var xerosic := CardInstance.create(xerosic_cd, 0)
	player.hand.append(xerosic)

	var keep_a := CardInstance.create(_make_trainer_data("Keep A", "Item"), 1)
	var keep_b := CardInstance.create(_make_trainer_data("Keep B", "Item"), 1)
	var keep_c := CardInstance.create(_make_trainer_data("Keep C", "Supporter"), 1)
	var discard_a := CardInstance.create(_make_trainer_data("Discard A", "Item"), 1)
	var discard_b := CardInstance.create(_make_trainer_data("Discard B", "Supporter"), 1)
	opponent.hand.append_array([keep_a, keep_b, keep_c, discard_a, discard_b])

	var effect: BaseEffect = gsm.effect_processor.get_effect(xerosic_cd.effect_id)
	var steps: Array[Dictionary] = effect.get_interaction_steps(xerosic, state)
	var played := gsm.play_trainer(0, xerosic, [{
		"opponent_discards_to_three": [discard_a, discard_b],
	}])

	return run_checks([
		assert_not_null(xerosic_cd, "CSV8C_195 should exist in the card database"),
		assert_eq(int(steps[0].get("chooser_player_index", -1)), 1, "CSV8C_195 should let the opponent choose which cards to discard"),
		assert_true(played, "CSV8C_195 should be playable when the opponent has more than 3 cards in hand"),
		assert_eq(opponent.hand.size(), 3, "CSV8C_195 should leave the opponent with exactly 3 cards in hand"),
		assert_contains(opponent.discard_pile, discard_a, "CSV8C_195 should discard the first chosen card"),
		assert_contains(opponent.discard_pile, discard_b, "CSV8C_195 should discard the second chosen card"),
		assert_true(xerosic in player.discard_pile, "CSV8C_195 itself should go to the discard pile after use"),
	])


func test_csv3c_125_giacomo_discards_one_special_energy_from_each_opponent_pokemon() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	player.hand.clear()
	opponent.discard_pile.clear()

	var giacomo_cd: CardData = CardDatabase.get_card("CSV3C", "125")
	var giacomo := CardInstance.create(giacomo_cd, 0)
	player.hand.append(giacomo)

	var active_special := CardInstance.create(_make_energy_data("Mist", "C", "Special Energy"), 1)
	var active_basic := CardInstance.create(_make_energy_data("Water", "W"), 1)
	var bench_special := CardInstance.create(_make_energy_data("Jet", "C", "Special Energy"), 1)
	opponent.active_pokemon.attached_energy.clear()
	opponent.active_pokemon.attached_energy.append_array([active_special, active_basic])
	opponent.bench[0].attached_energy.clear()
	opponent.bench[0].attached_energy.append(bench_special)

	var played := gsm.play_trainer(0, giacomo, [{
		"discard_special_energy": [
			{"source": opponent.active_pokemon, "target": active_special},
			{"source": opponent.bench[0], "target": bench_special},
		],
	}])

	return run_checks([
		assert_not_null(giacomo_cd, "CSV3C_125 should exist in the card database"),
		assert_true(played, "CSV3C_125 should be playable when the opponent has attached Special Energy"),
		assert_contains(opponent.discard_pile, active_special, "CSV3C_125 should discard the chosen Special Energy from the opponent Active Pokemon"),
		assert_contains(opponent.discard_pile, bench_special, "CSV3C_125 should discard the chosen Special Energy from the opponent Benched Pokemon"),
		assert_contains(opponent.active_pokemon.attached_energy, active_basic, "CSV3C_125 should leave Basic Energy attached"),
		assert_true(giacomo in player.discard_pile, "CSV3C_125 itself should go to the discard pile after use"),
	])


func test_csv3c_125_giacomo_flat_selection_still_discards_each_source() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	player.hand.clear()
	opponent.discard_pile.clear()

	var giacomo_cd: CardData = CardDatabase.get_card("CSV3C", "125")
	var giacomo := CardInstance.create(giacomo_cd, 0)
	player.hand.append(giacomo)

	var active_special_a := CardInstance.create(_make_energy_data("Mist A", "C", "Special Energy"), 1)
	var active_special_b := CardInstance.create(_make_energy_data("Mist B", "C", "Special Energy"), 1)
	var bench_special := CardInstance.create(_make_energy_data("Jet", "C", "Special Energy"), 1)
	opponent.active_pokemon.attached_energy.clear()
	opponent.active_pokemon.attached_energy.append_array([active_special_a, active_special_b])
	opponent.bench[0].attached_energy.clear()
	opponent.bench[0].attached_energy.append(bench_special)

	var played := gsm.play_trainer(0, giacomo, [{
		"discard_special_energy": [active_special_a, active_special_b],
	}])

	return run_checks([
		assert_true(played, "CSV3C_125 should resolve from flat energy selection UI"),
		assert_contains(opponent.discard_pile, active_special_a, "CSV3C_125 should discard one selected Special Energy from the active source"),
		assert_contains(opponent.discard_pile, bench_special, "CSV3C_125 should fill a missing source and discard one Special Energy from the bench"),
		assert_contains(opponent.active_pokemon.attached_energy, active_special_b, "CSV3C_125 should not discard two Special Energy from the same Pokemon"),
	])


func test_cs6ac_129_miss_fortune_sisters_discards_selected_items_from_opponent_top_five() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	player.hand.clear()
	opponent.deck.clear()
	opponent.discard_pile.clear()

	var sisters_cd: CardData = CardDatabase.get_card("CS6aC", "129")
	var sisters := CardInstance.create(sisters_cd, 0)
	player.hand.append(sisters)

	var top_item_a := CardInstance.create(_make_trainer_data("Top Item A", "Item"), 1)
	var top_supporter := CardInstance.create(_make_trainer_data("Top Supporter", "Supporter"), 1)
	var top_item_b := CardInstance.create(_make_trainer_data("Top Item B", "Item"), 1)
	var top_pokemon := CardInstance.create(_make_basic_pokemon_data("Top Pokemon", "C"), 1)
	var top_energy := CardInstance.create(_make_energy_data("Top Energy", "W"), 1)
	var deep_item := CardInstance.create(_make_trainer_data("Deep Item", "Item"), 1)
	opponent.deck.append_array([top_item_a, top_supporter, top_item_b, top_pokemon, top_energy, deep_item])

	var played := gsm.play_trainer(0, sisters, [{
		"discard_item_cards": [top_item_a, top_item_b],
	}])

	return run_checks([
		assert_not_null(sisters_cd, "CS6aC_129 should exist in the card database"),
		assert_true(played, "CS6aC_129 should be playable when the opponent deck is not empty"),
		assert_contains(opponent.discard_pile, top_item_a, "CS6aC_129 should discard selected Item cards from the revealed top five"),
		assert_contains(opponent.discard_pile, top_item_b, "CS6aC_129 should discard all selected Item cards from the revealed top five"),
		assert_true(deep_item in opponent.deck, "CS6aC_129 should not touch Item cards outside the revealed top five"),
		assert_eq(opponent.deck.size(), 4, "CS6aC_129 should only remove the discarded Item cards from the opponent deck"),
		assert_true(sisters in player.discard_pile, "CS6aC_129 itself should go to the discard pile after use"),
	])


func test_csv8c_190_handheld_fan_moves_attacker_energy_to_attackers_bench_after_damage() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]

	var handheld_fan_cd: CardData = CardDatabase.get_card("CSV8C", "190")
	var attacker_cd := _make_basic_pokemon_data("Attacker", "C", 130)
	var defender_cd := _make_basic_pokemon_data("Defender", "C", 130)
	player.active_pokemon = _make_slot(attacker_cd, 0)
	opponent.active_pokemon = _make_slot(defender_cd, 1)
	player.active_pokemon.attached_energy.clear()
	player.bench[0].attached_energy.clear()
	player.bench[1].attached_energy.clear()
	var energy_a := CardInstance.create(_make_energy_data("Colorless A", "C"), 0)
	var energy_b := CardInstance.create(_make_energy_data("Colorless B", "C"), 0)
	var energy_c := CardInstance.create(_make_energy_data("Colorless C", "C"), 0)
	player.active_pokemon.attached_energy.append_array([energy_a, energy_b, energy_c])
	opponent.active_pokemon.attached_tool = CardInstance.create(handheld_fan_cd, 1)

	var attacked := gsm.use_attack(0, 0)

	return run_checks([
		assert_not_null(handheld_fan_cd, "CSV8C_190 should exist in the card database"),
		assert_true(attacked, "CSV8C_190 scenario should still resolve the attack successfully"),
		assert_false(energy_a in player.active_pokemon.attached_energy, "CSV8C_190 should move an Energy off the attacker after damage"),
		assert_contains(player.bench[0].attached_energy, energy_a, "CSV8C_190 should move that Energy onto one of the attacker's Benched Pokemon"),
	])


func test_csv8c_190_handheld_fan_exposes_trigger_assignment_ui_and_honors_selected_target() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]

	var handheld_fan_cd: CardData = CardDatabase.get_card("CSV8C", "190")
	var attacker_cd := _make_basic_pokemon_data("Attacker", "C", 130)
	var defender_cd := _make_basic_pokemon_data("Defender", "C", 130)
	player.active_pokemon = _make_slot(attacker_cd, 0)
	opponent.active_pokemon = _make_slot(defender_cd, 1)
	player.active_pokemon.attached_energy.clear()
	player.bench[0].attached_energy.clear()
	player.bench[1].attached_energy.clear()
	var energy_a := CardInstance.create(_make_energy_data("Colorless A", "C"), 0)
	var energy_b := CardInstance.create(_make_energy_data("Colorless B", "C"), 0)
	var energy_c := CardInstance.create(_make_energy_data("Colorless C", "C"), 0)
	player.active_pokemon.attached_energy.append_array([energy_a, energy_b, energy_c])
	opponent.active_pokemon.attached_tool = CardInstance.create(handheld_fan_cd, 1)

	var effect: BaseEffect = gsm.effect_processor.get_effect(handheld_fan_cd.effect_id)
	var steps: Array[Dictionary] = gsm.get_post_damage_defender_interaction_steps(player.active_pokemon, opponent.active_pokemon)
	var attacked := gsm.use_attack(0, 0, [{
		EffectHandheldFan.STEP_ID: [{
			"source": energy_b,
			"target": player.bench[1],
		}],
	}])

	return run_checks([
		assert_not_null(handheld_fan_cd, "CSV8C_190 should exist in the card database"),
		assert_true(effect is EffectHandheldFan, "CSV8C_190 should resolve to EffectHandheldFan"),
		assert_eq(steps.size(), 1, "CSV8C_190 should expose exactly one triggered interaction step"),
		assert_eq(str(steps[0].get("ui_mode", "")), "card_assignment", "CSV8C_190 should request assignment UI instead of auto-picking"),
		assert_eq(int(steps[0].get("chooser_player_index", -1)), 1, "CSV8C_190 should let the Tool owner choose the moved Energy and destination"),
		assert_true(attacked, "CSV8C_190 should still resolve the attack when a specific assignment is supplied"),
		assert_true(energy_a in player.active_pokemon.attached_energy, "CSV8C_190 should leave unselected Energy attached to the attacker"),
		assert_false(energy_b in player.active_pokemon.attached_energy, "CSV8C_190 should move the selected Energy off the attacker"),
		assert_contains(player.bench[1].attached_energy, energy_b, "CSV8C_190 should honor the selected bench destination"),
		assert_false(player.bench[0].attached_energy.has(energy_b), "CSV8C_190 should not keep forcing the first bench target"),
	])


func test_cs4dac_388_team_yells_cheer_returns_selected_pokemon_and_supporters() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.discard_pile.clear()
	player.deck.clear()

	var cheer_cd: CardData = CardDatabase.get_card("CS4DaC", "388")
	var cheer := CardInstance.create(cheer_cd, 0)
	player.hand.append(cheer)

	var pokemon_a := CardInstance.create(_make_basic_pokemon_data("Discard Pokemon A", "C"), 0)
	var pokemon_b := CardInstance.create(_make_basic_pokemon_data("Discard Pokemon B", "C"), 0)
	var supporter := CardInstance.create(_make_trainer_data("Discard Supporter", "Supporter"), 0)
	var other_cheer := CardInstance.create(cheer_cd, 0)
	player.discard_pile.append_array([pokemon_a, pokemon_b, supporter, other_cheer])

	var played := gsm.play_trainer(0, cheer, [{
		"return_cards": [pokemon_a, pokemon_b, supporter],
	}])

	return run_checks([
		assert_not_null(cheer_cd, "CS4DaC_388 should exist in the card database"),
		assert_true(played, "CS4DaC_388 should be playable when the discard pile has Pokemon or valid Supporters"),
		assert_true(pokemon_a in player.deck and pokemon_b in player.deck and supporter in player.deck, "CS4DaC_388 should return the selected Pokemon and Supporter cards to the deck"),
		assert_true(other_cheer in player.discard_pile, "CS4DaC_388 should not return copies of Team Yell's Cheer from the discard pile"),
		assert_true(cheer in player.discard_pile, "CS4DaC_388 itself should go to the discard pile after use"),
	])


func test_csv8c_175_accompanying_flute_benches_selected_basic_pokemon_from_opponent_top_five() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	player.hand.clear()
	opponent.deck.clear()

	var flute_cd: CardData = CardDatabase.get_card("CSV8C", "175")
	var flute := CardInstance.create(flute_cd, 0)
	player.hand.append(flute)

	var basic_a := CardInstance.create(_make_basic_pokemon_data("Top Basic A", "C"), 1)
	var support := CardInstance.create(_make_trainer_data("Top Support", "Supporter"), 1)
	var basic_b := CardInstance.create(_make_basic_pokemon_data("Top Basic B", "C"), 1)
	var stage_one := CardInstance.create(_make_basic_pokemon_data("Top Stage1", "C", 90, "Stage1"), 1)
	var energy := CardInstance.create(_make_energy_data("Top Energy", "W"), 1)
	var deep_basic := CardInstance.create(_make_basic_pokemon_data("Deep Basic", "C"), 1)
	opponent.deck.append_array([basic_a, support, basic_b, stage_one, energy, deep_basic])
	var original_bench_size := opponent.bench.size()

	var played := gsm.play_trainer(0, flute, [{
		"bench_basic_pokemon": [basic_a, basic_b],
	}])

	return run_checks([
		assert_not_null(flute_cd, "CSV8C_175 should exist in the card database"),
		assert_true(played, "CSV8C_175 should be playable when the opponent deck is not empty"),
		assert_eq(opponent.bench.size(), original_bench_size + 2, "CSV8C_175 should put the selected revealed Basic Pokemon onto the opponent Bench"),
		assert_false(basic_a in opponent.deck or basic_b in opponent.deck, "CSV8C_175 should remove benched Basic Pokemon from the opponent deck"),
		assert_true(deep_basic in opponent.deck, "CSV8C_175 should not bench Basic Pokemon outside the revealed top five"),
		assert_true(flute in player.discard_pile, "CSV8C_175 itself should go to the discard pile after use"),
	])


func test_csv3c_062_mimikyu_mysterious_guard_blocks_damage_from_ex_and_ghost_eye_places_counters() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]

	var mimikyu_cd: CardData = CardDatabase.get_card("CSV3C", "062")
	var attacker_ex_cd := _make_basic_pokemon_data("Basic ex", "C", 220, "Basic", "ex")
	gsm.effect_processor.register_pokemon_card(mimikyu_cd)

	opponent.active_pokemon = _make_slot(mimikyu_cd, 1)
	player.active_pokemon = _make_slot(attacker_ex_cd, 0)
	player.active_pokemon.attached_energy.clear()
	player.active_pokemon.attached_energy.append_array([
		CardInstance.create(_make_energy_data("A", "C"), 0),
		CardInstance.create(_make_energy_data("B", "C"), 0),
		CardInstance.create(_make_energy_data("C", "C"), 0),
	])

	var blocked := gsm.use_attack(0, 0)
	var blocked_damage := opponent.active_pokemon.damage_counters

	state.current_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	player.active_pokemon = _make_slot(mimikyu_cd, 0)
	player.active_pokemon.attached_energy.clear()
	player.active_pokemon.attached_energy.append_array([
		CardInstance.create(_make_energy_data("Psychic", "P"), 0),
		CardInstance.create(_make_energy_data("Colorless", "C"), 0),
	])
	opponent.active_pokemon = _make_slot(_make_basic_pokemon_data("Defender", "C", 130), 1)

	var placed := gsm.use_attack(0, 0)

	return run_checks([
		assert_not_null(mimikyu_cd, "CSV3C_062 should exist in the card database"),
		assert_true(blocked, "CSV3C_062 immunity scenario should still resolve the attack flow"),
		assert_eq(blocked_damage, 0, "CSV3C_062 Mysterious Guard should block damage from Pokemon ex and Pokemon V"),
		assert_true(placed, "CSV3C_062 should use Ghost Eye successfully"),
		assert_eq(opponent.active_pokemon.damage_counters, 70, "CSV3C_062 Ghost Eye should place 7 damage counters on the opponent Active Pokemon"),
	])


func test_cs6bc_112_pidgeot_v_vanishing_wings_and_attack_bonus_with_own_stadium() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]

	var pidgeot_cd: CardData = CardDatabase.get_card("CS6bC", "112")
	var artazon_cd: CardData = CardDatabase.get_card("CSV2C", "127")
	gsm.effect_processor.register_pokemon_card(pidgeot_cd)

	var pidgeot_slot := _make_slot(pidgeot_cd, 0)
	var attached_energy := CardInstance.create(_make_energy_data("Colorless Bench", "C"), 0)
	pidgeot_slot.attached_energy.append(attached_energy)
	player.bench.clear()
	player.bench.append(pidgeot_slot)
	player.deck.clear()
	var can_use_ability := gsm.effect_processor.can_use_ability(pidgeot_slot, state, 0)
	var used_ability := gsm.use_ability(0, pidgeot_slot, 0)

	player.active_pokemon = _make_slot(pidgeot_cd, 0)
	player.active_pokemon.attached_energy.clear()
	player.active_pokemon.attached_energy.append_array([
		CardInstance.create(_make_energy_data("A", "C"), 0),
		CardInstance.create(_make_energy_data("B", "C"), 0),
		CardInstance.create(_make_energy_data("C", "C"), 0),
	])
	state.stadium_card = CardInstance.create(artazon_cd, 0)
	state.stadium_owner_index = 0
	opponent.active_pokemon = _make_slot(_make_basic_pokemon_data("Target", "C", 200), 1)
	var attacked := gsm.use_attack(0, 0)

	return run_checks([
		assert_not_null(pidgeot_cd, "CS6bC_112 should exist in the card database"),
		assert_true(can_use_ability, "CS6bC_112 Vanishing Wings should be usable from the Bench during your turn"),
		assert_true(used_ability, "CS6bC_112 Vanishing Wings should shuffle Pidgeot V and attached cards into the deck"),
		assert_true(pidgeot_slot not in player.bench, "CS6bC_112 Vanishing Wings should remove Pidgeot V from the Bench"),
		assert_true(attached_energy in player.deck, "CS6bC_112 Vanishing Wings should return attached cards to the deck"),
		assert_true(attacked, "CS6bC_112 should attack successfully"),
		assert_eq(opponent.active_pokemon.damage_counters, 160, "CS6bC_112 should gain +80 damage when its owner has a Stadium in play"),
	])


func test_cs5bc_045_mantine_attack_puts_basic_from_any_discard_onto_owners_bench() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]

	var mantine_cd: CardData = CardDatabase.get_card("CS5bC", "045")
	gsm.effect_processor.register_pokemon_card(mantine_cd)
	player.active_pokemon = _make_slot(mantine_cd, 0)
	player.active_pokemon.attached_energy.clear()
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_energy_data("Colorless", "C"), 0))
	opponent.discard_pile.clear()
	var revived := CardInstance.create(_make_basic_pokemon_data("Opponent Basic", "W"), 1)
	opponent.discard_pile.append(revived)
	var original_bench_size := opponent.bench.size()

	var attacked := gsm.use_attack(0, 0, [{
		"revive_basic_from_any_discard": [revived],
	}])

	return run_checks([
		assert_not_null(mantine_cd, "CS5bC_045 should exist in the card database"),
		assert_true(attacked, "CS5bC_045 should use Mantine Wave successfully"),
		assert_eq(opponent.bench.size(), original_bench_size + 1, "CS5bC_045 should place the chosen Basic Pokemon onto its owner's Bench"),
		assert_false(revived in opponent.discard_pile, "CS5bC_045 should remove the chosen Basic Pokemon from the discard pile"),
		assert_eq(opponent.bench.back().get_top_card(), revived, "CS5bC_045 should bench the selected Basic Pokemon card"),
	])


func test_cs5ac_093_snorlax_blocks_opponent_retreat_and_self_sleep_attack() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	gsm.coin_flipper = RiggedCoinFlipper.new([false])
	gsm.effect_processor.coin_flipper = gsm.coin_flipper
	var state := gsm.game_state
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]

	var snorlax_cd: CardData = CardDatabase.get_card("CS5aC", "093")
	gsm.effect_processor.register_pokemon_card(snorlax_cd)
	var snorlax_effect := gsm.effect_processor.get_effect(snorlax_cd.effect_id)
	player.active_pokemon = _make_slot(snorlax_cd, 0)
	state.current_player_index = 1
	state.phase = GameState.GamePhase.MAIN
	var retreat_blocked := gsm.rule_validator.can_retreat(state, 1, gsm.effect_processor)

	player.active_pokemon = _make_slot(_make_basic_pokemon_data("Other Active", "C", 130), 0)
	player.bench.clear()
	player.bench.append(_make_slot(snorlax_cd, 0))
	var retreat_unblocked := gsm.rule_validator.can_retreat(state, 1, gsm.effect_processor)

	state.current_player_index = 0
	player.active_pokemon = _make_slot(snorlax_cd, 0)
	player.active_pokemon.attached_energy.clear()
	player.active_pokemon.attached_energy.append_array([
		CardInstance.create(_make_energy_data("A", "C"), 0),
		CardInstance.create(_make_energy_data("B", "C"), 0),
		CardInstance.create(_make_energy_data("C", "C"), 0),
		CardInstance.create(_make_energy_data("D", "C"), 0),
	])
	var attacked := gsm.use_attack(0, 0)

	return run_checks([
		assert_not_null(snorlax_cd, "CS5aC_093 should exist in the card database"),
		assert_true(snorlax_effect is AbilityActiveRetreatLock, "CS5aC_093 should register 挡道 from its effect_id even when cached names are malformed"),
		assert_false(retreat_blocked, "CS5aC_093 挡道 should stop the opponent Active Pokemon from retreating"),
		assert_true(retreat_unblocked, "CS5aC_093 should stop applying the retreat lock once it is no longer Active"),
		assert_true(attacked, "CS5aC_093 should use Collapse successfully"),
		assert_true(player.active_pokemon.status_conditions.get("asleep", false), "CS5aC_093 should put itself to Sleep after using Collapse"),
	])
