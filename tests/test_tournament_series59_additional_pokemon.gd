extends TestBase

const Fixtures = preload("res://tests/test_30thdc_cards.gd")

func _card(uid: String) -> CardData:
	var parts := uid.split("_")
	return CardData.from_dict(CardDatabase.get_card(parts[0], parts[1]).to_dict())

func _slot(uid: String, seat: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(_card(uid), seat))
	return slot

func _energy(kind: String, seat: int = 0, special: bool = false) -> CardInstance:
	var data := CardData.new()
	data.card_type = "Special Energy" if special else "Basic Energy"
	data.name = "Energy " + kind
	data.set_code = "TEST"
	data.card_index = kind + ("S" if special else "B")
	data.energy_type = kind
	data.energy_provides = kind
	return CardInstance.create(data, seat)

func _battle(uid: String, seat: int = 0, coins: CoinFlipper = null) -> GameStateMachine:
	var gsm: GameStateMachine = Fixtures.new()._battle("008", coins)
	var state := gsm.game_state
	state.current_player_index = seat
	for owner: int in 2:
		state.players[owner].active_pokemon = Fixtures.new()._slot("024", owner)
		state.players[owner].active_pokemon.get_card_data().hp = 1000
		state.players[owner].active_pokemon.get_card_data().weakness_energy = ""
		state.players[owner].active_pokemon.get_card_data().resistance_energy = ""
	state.players[seat].active_pokemon = _slot(uid, seat)
	var attacker := state.players[seat].active_pokemon
	for kind: String in ["G", "R", "W", "L", "P", "F", "D", "M", "C", "R", "W", "P", "F", "G", "M", "P"]:
		attacker.attached_energy.append(_energy(kind, seat))
	gsm.effect_processor.register_pokemon_card(attacker.get_card_data())
	return gsm

const UIDS := ["151C_084", "30thP_002", "CSV1C_017", "CSV1C_029", "CSV2C_061", "CSV2C_099", "CSV3C_082", "CSV3C_089", "CSV4C_001", "CSV4C_045", "CSV4C_046", "CSV4C_073", "CSV4C_076", "CSV4C_085", "CSV4C_103", "CSV5C_008", "CSV5C_011", "CSV5C_012", "CSV5C_020", "CSV5C_029", "CSV6C_030", "CSV6C_043", "CSV6C_083", "CSV7C_071", "CSV7C_094", "CSV7C_157", "CSV8C_039", "CSV8C_092", "CSV8C_155", "CSV8C_166", "CSV9C_091", "CSV9C_137", "CSVH5eC_027", "CSVL2C_007", "SVP_047", "SVP_100"]

func test_all_exact_printings_have_their_required_rule_handlers() -> String:
	var processor := EffectProcessor.new()
	var checks: Array[String] = []
	for uid: String in UIDS:
		var parts := uid.split("_")
		var card := CardDatabase.get_card(parts[0], parts[1])
		checks.append(assert_not_null(card, uid))
		if card != null:
			processor.register_pokemon_card(card)
			var status := CardImplementationStatus.get_status(card)
			checks.append(assert_false(bool(status.get("unimplemented", true)), uid + " " + str(status)))
			var slot := _slot(uid)
			for index: int in card.attacks.size():
				var effects := processor.get_attack_effects_for_slot(slot, index)
				checks.append(assert_eq(not effects.is_empty(), not str(card.attacks[index].get("text", "")).is_empty(), uid + " attack " + str(index)))
	processor.prepare_for_disposal()
	return run_checks(checks)

func test_coin_damage_is_resolved_before_weakness_and_only_once() -> String:
	var checks: Array[String] = []
	for spec: Array in [["CSV4C_073", 0, 3, 60, 0], ["CSV7C_071", 1, 2, 90, 0], ["CSVL2C_007", 0, 3, 10, 0], ["CSV7C_157", 1, 1, 20, 20], ["SVP_047", 0, 1, 90, 90]]:
		for heads: bool in [false, true]:
			var coins := Fixtures.FixedCoins.new()
			for _i: int in int(spec[2]):
				coins.results.append(heads)
			var gsm := _battle(spec[0], 0, coins)
			var attacker := gsm.game_state.players[0].active_pokemon
			var defender := gsm.game_state.players[1].active_pokemon
			defender.get_card_data().weakness_energy = attacker.get_card_data().energy_type
			defender.get_card_data().weakness_value = "×2"
			AILegalActionBuilder.new().build_actions(gsm, 0)
			checks.append(assert_eq(coins.calls, 0, "Preview consumes no RNG"))
			checks.append(assert_true(gsm.use_attack(0, int(spec[1])), str(spec)))
			checks.append(assert_eq(defender.damage_counters, (int(spec[4]) + (int(spec[2]) * int(spec[3]) if heads else 0)) * 2, str(spec)))
			checks.append(assert_eq(coins.calls, int(spec[2])))
			gsm.prepare_for_disposal()
	return run_checks(checks)

func test_recoil_and_psychic_bonus_use_the_printed_attack() -> String:
	var checks: Array[String] = []
	for spec: Array in [["151C_084", 0, 0, 10, 30], ["SVP_100", 0, 0, 20, 70], ["CSV7C_071", 0, 30, 60, 130], ["CSV7C_094", 0, 0, 0, 40]]:
		var gsm := _battle(spec[0])
		var attacker := gsm.game_state.players[0].active_pokemon
		var defender := gsm.game_state.players[1].active_pokemon
		attacker.damage_counters = spec[2]
		defender.get_card_data().energy_type = "P"
		checks.append(assert_true(gsm.use_attack(0, spec[1])))
		checks.append(assert_eq(attacker.damage_counters, spec[3]))
		checks.append(assert_eq(defender.damage_counters, spec[4]))
		gsm.prepare_for_disposal()
	return run_checks(checks)

func test_zero_head_multipliers_cannot_gain_external_damage_but_fixed_base_can() -> String:
	var checks: Array[String] = []
	for spec: Array in [["CSV4C_073", 0, 3, 0], ["CSV7C_071", 1, 2, 0], ["CSVL2C_007", 0, 3, 0], ["CSV7C_157", 1, 1, 50], ["SVP_047", 0, 1, 120]]:
		var coins := Fixtures.FixedCoins.new()
		for _i: int in int(spec[2]):
			coins.results.append(false)
		var gsm := _battle(spec[0], 0, coins)
		var attacker := gsm.game_state.players[0].active_pokemon
		var defender := gsm.game_state.players[1].active_pokemon
		defender.get_card_data().mechanic = "V"
		attacker.attached_tools.append(CardInstance.create(_card("CSV1C_116"), 0))
		checks.append(assert_eq(gsm.effect_processor.get_attacker_modifier(attacker, gsm.game_state, defender), 30, "Real Choice Belt applies"))
		checks.append(assert_true(gsm.use_attack(0, spec[1])))
		checks.append(assert_eq(defender.damage_counters, spec[3], str(spec)))
		checks.append(assert_eq(coins.calls, spec[2]))
		gsm.prepare_for_disposal()
	return run_checks(checks)

func test_draw_attacks_respect_both_hands_and_deck_size() -> String:
	var checks: Array[String] = []
	for uid: String in ["CSV3C_089", "CSV4C_046"]:
		var gsm := _battle(uid)
		var player := gsm.game_state.players[0]
		var opponent := gsm.game_state.players[1]
		player.hand.append(_energy("R"))
		for _i: int in 5:
			opponent.hand.append(_energy("W", 1))
		checks.append(assert_true(gsm.use_attack(0, 0)))
		checks.append(assert_eq(player.hand.size(), 5 if uid == "CSV3C_089" else 4))
		checks.append(assert_eq(opponent.hand.size(), 6 if uid == "CSV3C_089" else 9, "Includes the opponent's next turn draw"))
		gsm.prepare_for_disposal()
	return run_checks(checks)

func test_single_bench_heal_rejects_active_and_leaves_other_bench_unchanged() -> String:
	var gsm := _battle("CSV5C_029")
	var player := gsm.game_state.players[0]
	var first := _slot("CSV4C_073")
	var second := _slot("CSV4C_073")
	first.damage_counters = 80
	second.damage_counters = 40
	player.bench.assign([first, second])
	var checks: Array[String] = [assert_false(gsm.use_attack(0, 0, [{"csv9c_heal_own_pokemon": [player.active_pokemon]}]))]
	checks.append(assert_true(gsm.use_attack(0, 0, [{"csv9c_heal_own_pokemon": [first]}])))
	checks.append(assert_eq(first.damage_counters, 0))
	checks.append(assert_eq(second.damage_counters, 40))
	gsm.prepare_for_disposal()
	return run_checks(checks)

func test_discard_energy_attacks_preserve_unselected_energy() -> String:
	var checks: Array[String] = []
	for spec: Array in [["30thP_002", 0, 1], ["CSV8C_039", 1, 1], ["CSV6C_043", 1, 2]]:
		var gsm := _battle(spec[0])
		var player := gsm.game_state.players[0]
		var attacker := player.active_pokemon
		var selected: Array = []
		for i: int in int(spec[2]):
			selected.append(attacker.attached_energy[i])
		var before := attacker.attached_energy.size()
		checks.append(assert_true(gsm.use_attack(0, int(spec[1]), [{"discard_attached_energy_from_self": selected}]), str(spec)))
		checks.append(assert_eq(attacker.attached_energy.size(), before-int(spec[2])))
		for energy: CardInstance in selected:
			checks.append(assert_true(energy in player.discard_pile))
		gsm.prepare_for_disposal()
	return run_checks(checks)

func test_hand_attachments_cover_special_energy_and_bench_only_grass() -> String:
	var checks: Array[String] = []
	for seat: int in 2:
		for bench_only: bool in [false, true]:
			var gsm := _battle("CSV5C_008" if bench_only else "CSV4C_103", seat)
			var player := gsm.game_state.players[seat]
			var target := _slot("151C_084", seat)
			player.bench.append(target)
			var energy := _energy("G" if bench_only else "C", seat, not bench_only)
			player.hand.append(energy)
			if bench_only:
				checks.append(assert_false(gsm.use_attack(seat, 0, [{"hand_basic_energy": [energy], "attach_target": [player.active_pokemon]}])))
			checks.append(assert_true(gsm.use_attack(seat, 0, [{"hand_basic_energy": [energy], "attach_target": [target]}])))
			checks.append(assert_true(energy in target.attached_energy))
			checks.append(assert_false(energy in player.hand))
			gsm.prepare_for_disposal()
	return run_checks(checks)

func test_searches_find_exact_types_and_preserve_explicit_zero() -> String:
	var checks: Array[String] = []
	for uid: String in ["CSV5C_011", "CSV5C_020", "CSV6C_030", "CSV8C_155", "CSV8C_166"]:
		for decline: bool in [true, false]:
			var gsm := _battle(uid)
			var player := gsm.game_state.players[0]
			var wanted: CardInstance = _slot("151C_084").get_top_card() if uid == "CSV8C_155" else _energy("R", 0, uid == "CSV6C_030")
			player.deck.append(wanted)
			var step := "deck_energy" if uid in ["CSV5C_011", "CSV5C_020"] else ("colorful_friends" if uid == "CSV8C_166" else "search_cards")
			checks.append(assert_true(gsm.use_attack(0, 0, [{step: [] if decline else [wanted]}]), uid))
			checks.append(assert_eq(wanted in player.deck, decline))
			if not decline:
				checks.append(assert_true(wanted in player.active_pokemon.attached_energy if step == "deck_energy" else wanted in player.hand))
			gsm.prepare_for_disposal()
	return run_checks(checks)

func test_colorful_catch_rejects_duplicate_types_without_shuffling() -> String:
	var gsm := _battle("CSV8C_166")
	var player := gsm.game_state.players[0]
	var first := _energy("R")
	var second := _energy("R")
	player.deck.assign([first, second, _energy("W")])
	var checks: Array[String] = [assert_false(gsm.use_attack(0, 0, [{"colorful_friends": [first, second]}]))]
	checks.append(assert_eq(player.deck[0], first))
	checks.append(assert_true(gsm.use_attack(0, 0, [{"colorful_friends": [first, player.deck[2]]}])) )
	checks.append(assert_eq(player.hand.size(), 2))
	gsm.prepare_for_disposal()
	return run_checks(checks)

func test_discard_water_attach_both_to_one_bench_and_zero() -> String:
	var checks: Array[String] = []
	for decline: bool in [false, true]:
		var gsm := _battle("CSV6C_043")
		var player := gsm.game_state.players[0]
		var target := _slot("151C_084")
		player.bench.append(target)
		var energies := [_energy("W"), _energy("W")]
		player.discard_pile.assign(energies)
		checks.append(assert_true(gsm.use_attack(0, 0, [{"discard_energy": [] if decline else energies, "attach_target": [target]}])))
		checks.append(assert_eq(target.attached_energy.size(), 0 if decline else 2))
		gsm.prepare_for_disposal()
	return run_checks(checks)

func test_magnetic_absorption_prize_threshold_and_suppression() -> String:
	var checks: Array[String] = []
	for seat: int in 2:
		var gsm := _battle("CSV6C_083", seat)
		var state := gsm.game_state
		var pokemon := state.players[seat].active_pokemon
		var energy := _energy("F", seat)
		state.players[seat].discard_pile.append(energy)
		checks.append(assert_false(gsm.use_ability(seat, pokemon, 0, [{"magnetic_absorption": [energy]}])))
		state.players[1-seat].prizes.resize(4)
		pokemon.effects.append({"type": "ability_disabled", "turn": state.turn_number})
		checks.append(assert_false(gsm.use_ability(seat, pokemon, 0, [{"magnetic_absorption": [energy]}])))
		pokemon.effects.clear()
		checks.append(assert_true(gsm.use_ability(seat, pokemon, 0, [{"magnetic_absorption": [energy]}])))
		checks.append(assert_true(energy in pokemon.attached_energy))
		checks.append(assert_false(gsm.use_ability(seat, pokemon, 0, [{"magnetic_absorption": [energy]}])))
		gsm.prepare_for_disposal()
	return run_checks(checks)

func test_weavile_requires_active_entry_and_gusts_only_basic() -> String:
	var gsm := _battle("CSV3C_082")
	var state := gsm.game_state
	var pokemon := state.players[0].active_pokemon
	var basic := _slot("151C_084", 1)
	var evolved := _slot("CSV4C_073", 1)
	state.players[1].bench.assign([basic, evolved])
	var checks: Array[String] = [assert_false(gsm.use_ability(0, pokemon, 0, [{"assaulting_hunt": [basic]}]))]
	pokemon.mark_entered_active_from_bench(state.turn_number)
	checks.append(assert_false(gsm.use_ability(0, pokemon, 0, [{"assaulting_hunt": [evolved]}])))
	checks.append(assert_true(gsm.use_ability(0, pokemon, 0, [{"assaulting_hunt": [basic]}])))
	checks.append(assert_eq(state.players[1].active_pokemon, basic))
	checks.append(assert_false(gsm.use_ability(0, pokemon, 0, [{"assaulting_hunt": [basic]}])))
	gsm.prepare_for_disposal()
	return run_checks(checks)

func test_metal_bridge_and_bronze_body_are_suppressed_normally() -> String:
	var checks: Array[String] = []
	for uid: String in ["CSV9C_137", "CSV2C_099"]:
		var gsm := _battle(uid)
		var state := gsm.game_state
		var pokemon := state.players[0].active_pokemon
		if uid == "CSV9C_137":
			checks.append(assert_eq(gsm.effect_processor.get_retreat_cost_modifier(pokemon, state), -99))
		else:
			checks.append(assert_eq(gsm.effect_processor.get_defender_modifier(pokemon, state), -30))
		pokemon.effects.append({"type": "ability_disabled", "turn": state.turn_number})
		if uid == "CSV9C_137":
			checks.append(assert_eq(gsm.effect_processor.get_retreat_cost_modifier(pokemon, state), 0))
		else:
			checks.append(assert_eq(gsm.effect_processor.get_defender_modifier(pokemon, state), 0))
		gsm.prepare_for_disposal()
	return run_checks(checks)

func test_weavile_can_use_once_on_each_bench_to_active_entry() -> String:
	var gsm := _battle("CSV3C_082")
	var state := gsm.game_state
	var player := state.players[0]
	var pokemon := player.active_pokemon
	var own_basic := _slot("151C_084")
	var first := _slot("151C_084", 1)
	var second := _slot("151C_084", 1)
	player.bench.append(own_basic)
	state.players[1].bench.assign([first, second])
	pokemon.mark_entered_active_from_bench(state.turn_number)
	var checks: Array[String] = [assert_true(gsm.use_ability(0, pokemon, 0, [{"assaulting_hunt": [first]}]))]
	checks.append(assert_false(gsm.use_ability(0, pokemon, 0, [{"assaulting_hunt": [second]}]), "Same entry cannot be used twice"))
	checks.append(assert_true(BattleFieldTransitionService.switch_active_with_bench(state, 0, own_basic, "test_switch_out")))
	checks.append(assert_false(gsm.use_ability(0, pokemon, 0, [{"assaulting_hunt": [second]}]), "Benched Pokemon cannot use the ability"))
	checks.append(assert_true(BattleFieldTransitionService.switch_active_with_bench(state, 0, pokemon, "test_switch_back")))
	checks.append(assert_true(gsm.use_ability(0, pokemon, 0, [{"assaulting_hunt": [second]}]), "New entry in the same turn grants another use"))
	checks.append(assert_eq(state.players[1].active_pokemon, second))
	checks.append(assert_false(gsm.use_ability(0, pokemon, 0, [{"assaulting_hunt": [first]}]), "New entry also grants only one use"))
	gsm.prepare_for_disposal()
	return run_checks(checks)

func test_umbreon_feint_ignores_target_effects_and_weakness() -> String:
	var gsm := _battle("CSV4C_076")
	var state := gsm.game_state
	var target := _slot("CSV4C_085", 1)
	target.get_card_data().weakness_energy = "D"
	target.get_card_data().weakness_value = "×2"
	target.effects.append({"type": "prevent_attack_damage_and_effects", "turn": state.turn_number-1})
	state.players[1].bench.append(target)
	gsm.effect_processor.register_pokemon_card(target.get_card_data())
	var checks: Array[String] = [assert_true(gsm.use_attack(0, 0, [{"any_target": [target]}]))]
	checks.append(assert_eq(target.damage_counters, 50))
	checks.append(assert_eq(state.players[1].active_pokemon.damage_counters, 0))
	gsm.prepare_for_disposal()
	return run_checks(checks)

func test_umbreon_feint_keeps_the_attackers_double_turbo_penalty() -> String:
	var gsm := _battle("CSV4C_076")
	var state := gsm.game_state
	var attacker := state.players[0].active_pokemon
	var target := _slot("CSV4C_073", 1)
	state.players[1].bench.append(target)
	var energy := _energy("C", 0, true)
	energy.card_data.effect_id = "9c04dd0addf56a7b2c88476bc8e45c0e"
	attacker.attached_energy.append(energy)
	var checks: Array[String] = [assert_true(gsm.use_attack(0, 0, [{"any_target": [target]}]))]
	checks.append(assert_eq(target.damage_counters, 30, "Defender effects are ignored but own Double Turbo still reduces damage"))
	gsm.prepare_for_disposal()
	return run_checks(checks)

func test_umbreon_feint_stadium_bonus_does_not_create_a_second_active_hit() -> String:
	var gsm := _battle("CSV4C_076")
	var state := gsm.game_state
	state.stadium_card = CardInstance.create(_card("CSV4C_128"), 0)
	state.stadium_owner_index = 0
	var target := _slot("CSV4C_073", 1)
	state.players[1].bench.append(target)
	var checks: Array[String] = [assert_true(gsm.use_attack(0, 0, [{"any_target": [target]}]))]
	checks.append(assert_eq(target.damage_counters, 60))
	checks.append(assert_eq(state.players[1].active_pokemon.damage_counters, 0))
	gsm.prepare_for_disposal()
	return run_checks(checks)

func test_banette_opponent_chooses_exact_three_compiler_and_engine() -> String:
	var checks: Array[String] = []
	for seat: int in 2:
		var gsm := _battle("CSVH5eC_027", seat)
		var state := gsm.game_state
		var attacker := state.players[seat].active_pokemon
		var opponent := state.players[1-seat]
		for i: int in 4:
			opponent.hand.append(_energy("R" if i == 0 else "W", 1-seat))
		var effect := gsm.effect_processor.get_attack_effects_for_slot(attacker, 0)[0]
		var steps := effect.get_attack_interaction_steps(attacker.get_top_card(), attacker.get_card_data().attacks[0], state)
		checks.append(assert_eq(steps.size(), 1))
		if not steps.is_empty():
			checks.append(assert_true(bool(steps[0].opponent_chooses)))
			checks.append(assert_eq(steps[0].min_select, 3))
		var selected: Array = opponent.hand.slice(1, 4)
		checks.append(assert_false(gsm.use_attack(seat, 0, [{"cursed_words": selected.slice(0, 2)}])))
		checks.append(assert_true(gsm.use_attack(seat, 0, [{"cursed_words": selected}])))
		checks.append(assert_eq(opponent.hand.size(), 2, "Three returned, then one drawn at the next turn start"))
		checks.append(assert_eq(opponent.hand[0].card_data.energy_type, "R"))
		gsm.prepare_for_disposal()
	return run_checks(checks)

func test_real_host_rebinds_hand_energy_and_target_choices_for_both_seats() -> String:
	var checks: Array[String] = []
	var fixture := Fixtures.new()
	for seat: int in 2:
		var gsm := _battle("CSV5C_008", seat)
		var state := gsm.game_state
		var player := state.players[seat]
		var attacker := player.active_pokemon
		var energy := _energy("G", seat)
		player.hand.append(energy)
		player.bench.assign([_slot("151C_084", seat), _slot("SVP_100", seat)])
		var host := fixture._host(gsm, seat)
		if not bool(host.get("ok", false)):
			gsm.prepare_for_disposal()
			return "Host creation failed: %s" % host
		var effect := gsm.effect_processor.get_attack_effects_for_slot(attacker, 0)[0]
		var steps := effect.get_attack_interaction_steps(attacker.get_top_card(), attacker.get_card_data().attacks[0], state)
		checks.append(assert_eq(effect.get_ucis_last_error(), ""))
		var handles: Array = []
		var resolved: Dictionary = {}
		for step: Dictionary in steps:
			var items: Array = step.items
			resolved[str(step.id)] = fixture._pick(host, step, items, [items.size()-1], {"pending_effect_card": attacker.get_top_card()}, checks, handles)
		checks.append(assert_true(gsm.use_attack(seat, 0, [resolved])))
		checks.append(assert_true(energy in player.bench[1].attached_energy))
		fixture._close_host(host, gsm, handles.size(), checks)
	return run_checks(checks)

func test_status_protection_and_attacks_lock_only_correct_turn() -> String:
	var checks: Array[String] = []
	for uid: String in ["CSV4C_001", "CSV8C_092"]:
		var coins := Fixtures.FixedCoins.new()
		coins.results.assign([true])
		var gsm := _battle(uid, 0, coins)
		var attacker := gsm.game_state.players[0].active_pokemon
		checks.append(assert_true(gsm.use_attack(0, 0)))
		checks.append(assert_true(AttackCoinFlipPreventDamageAndEffectsNextTurn.prevents_attack_damage(attacker, gsm.game_state)))
		gsm.prepare_for_disposal()
	for spec: Array in [["CSV4C_076", 1], ["CSV6C_083", 0], ["CSV9C_137", 0]]:
		var gsm := _battle(spec[0])
		var state := gsm.game_state
		checks.append(assert_true(gsm.use_attack(0, spec[1])))
		state.turn_number += 1
		state.current_player_index = 0
		state.phase = GameState.GamePhase.MAIN
		checks.append(assert_false(gsm.rule_validator.can_use_attack(state, 0, 0, gsm.effect_processor), str(spec)))
		gsm.prepare_for_disposal()
	return run_checks(checks)

func test_distributed_counters_and_copperajah_bench_recoil() -> String:
	var checks: Array[String] = []
	var gsm := _battle("CSV2C_061")
	var state := gsm.game_state
	var defender := state.players[1].active_pokemon
	var bench := _slot("CSV4C_073", 1)
	state.players[1].bench.append(bench)
	checks.append(assert_false(gsm.use_attack(0, 1, [{"sinistcha_curse_droplets_counters": [{"target": bench, "amount": 70}]}])))
	checks.append(assert_true(gsm.use_attack(0, 1, [{"sinistcha_curse_droplets_counters": [{"target": bench, "amount": 50}, {"target": defender, "amount": 30}]}])))
	checks.append(assert_eq(bench.damage_counters, 50))
	checks.append(assert_eq(defender.damage_counters, 30))
	gsm.prepare_for_disposal()
	gsm = _battle("CSV2C_099")
	state = gsm.game_state
	state.players[0].bench.assign([_slot("CSV4C_073"), _slot("CSV4C_073")])
	checks.append(assert_true(gsm.use_attack(0, 0)))
	for own: PokemonSlot in state.players[0].bench:
		checks.append(assert_eq(own.damage_counters, 30))
	checks.append(assert_eq(state.players[1].active_pokemon.damage_counters, 260))
	gsm.prepare_for_disposal()
	return run_checks(checks)

func test_revavroom_promo_ability_discards_one_energy_and_draws_to_six() -> String:
	var gsm := _battle("SVP_047")
	var player := gsm.game_state.players[0]
	var energy := _energy("C", 0, true)
	player.hand.assign([energy, _energy("G")])
	var checks: Array[String] = [assert_true(gsm.use_ability(0, player.active_pokemon, 0, [{"discard_energy": [energy]}]))]
	checks.append(assert_eq(player.hand.size(), 6))
	checks.append(assert_true(energy in player.discard_pile))
	checks.append(assert_false(gsm.use_ability(0, player.active_pokemon, 0, [])))
	gsm.prepare_for_disposal()
	return run_checks(checks)
