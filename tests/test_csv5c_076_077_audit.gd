extends TestBase

const HostFixtures = preload("res://tests/test_30thdc_cards.gd")


func _card(index: String) -> CardData:
	return CardData.from_api_json(JSON.parse_string(FileAccess.get_file_as_string(
		"res://tests/fixtures/card_audit_20261005/CSV5C_%s.api.json" % index)))


func _bundled(uid: String) -> CardData:
	return CardData.from_dict(JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/bundled_user/cards/%s.json" % uid)))


func _slot(index: String, seat: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(_card(index), seat))
	return slot


func _energy(seat: int, symbol: String = "DAR") -> CardInstance:
	return CardInstance.create(_bundled("CSVE1C_" + symbol), seat)


func _battle(index: String, seat: int = 0, coins: CoinFlipper = null) -> GameStateMachine:
	var gsm := GameStateMachine.new()
	if coins == null:
		coins = HostFixtures.FixedCoins.new()
	gsm.effect_processor.prepare_for_disposal()
	gsm.coin_flipper = coins
	gsm.effect_processor = EffectProcessor.new(coins)
	gsm.effect_processor.bind_game_state_machine(gsm)
	var state := GameState.new()
	gsm.game_state = state
	state.turn_number = 4
	state.phase = GameState.GamePhase.MAIN
	state.current_player_index = seat
	state.first_player_index = 1 - seat
	state.players = [PlayerState.new(), PlayerState.new()]
	state.shared_turn_flags["_draw_effect_processor"] = gsm.effect_processor
	for player_seat: int in 2:
		var player := state.players[player_seat]
		player.player_index = player_seat
		player.active_pokemon = _slot(index if player_seat == seat else "077", player_seat)
		if player_seat != seat:
			player.active_pokemon.get_card_data().hp = 1000
			player.active_pokemon.get_card_data().weakness_energy = ""
			player.active_pokemon.get_card_data().resistance_energy = ""
		for _i: int in 6:
			player.prizes.append(_energy(player_seat))
		for _i: int in 12:
			player.deck.append(_energy(player_seat))
	state.players[seat].active_pokemon.attached_energy.assign([_energy(seat), _energy(seat, "PSY")])
	gsm.effect_processor.register_pokemon_card(state.players[seat].active_pokemon.get_card_data())
	return gsm


func test_exact_source_metadata_registration_and_attack_indexes() -> String:
	var checks: Array[String] = []
	CardImplementationStatus.clear_cache()
	for index: String in ["076", "077"]:
		var gsm := _battle(index)
		var slot := gsm.game_state.players[0].active_pokemon
		var card := slot.get_card_data()
		checks.append(assert_eq(card.get_uid(), "CSV5C_" + index))
		checks.append(assert_eq(card.energy_type, "D"))
		checks.append(assert_eq(card.hp, 50 if index == "076" else 80))
		checks.append(assert_eq(card.stage, "Basic" if index == "076" else "Stage 1"))
		checks.append(assert_eq(card.evolves_from, "" if index == "076" else "鬼斯"))
		checks.append(assert_eq(card.weakness_energy, "F"))
		checks.append(assert_eq(card.weakness_value, "×2"))
		checks.append(assert_eq(card.resistance_energy, ""))
		checks.append(assert_eq(card.retreat_cost, 1))
		checks.append(assert_true(card.abilities.is_empty()))
		checks.append(assert_false(CardImplementationStatus.is_unimplemented(card), "Source printing must have a registered attack effect"))
		var effects := gsm.effect_processor.get_attack_effects_for_slot(slot, 0)
		checks.append(assert_eq(effects.size(), 1, "Exactly one additional effect on attack 0"))
		if effects.size() == 1:
			checks.append(assert_true(effects[0] is AttackDrawCards if index == "076" else effects[0] is EffectApplyStatus))
			checks.append(assert_true(effects[0].get_attack_interaction_steps(slot.get_top_card(), card.attacks[0], gsm.game_state).is_empty(), "Automatic draw/status requires no choice window"))
		if index == "076":
			checks.append(assert_true(gsm.effect_processor.get_attack_effects_for_slot(slot, 1).is_empty(), "Will-O-Wisp must not inherit Allure's draw"))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_allure_draws_exactly_top_card_for_attacking_seat_and_logs_source() -> String:
	var checks: Array[String] = []
	for seat: int in 2:
		var gsm := _battle("076", seat)
		var state := gsm.game_state
		var player := state.players[seat]
		var top := _energy(seat, "PSY")
		var second := _energy(seat)
		player.deck.assign([top, second])
		player.active_pokemon.attached_energy.assign([_energy(seat, "PSY")])
		checks.append(assert_true(gsm.use_attack(seat, 0), "Any one Energy pays the Colorless cost"))
		checks.append(assert_eq(player.hand, [top]))
		checks.append(assert_eq(player.deck, [second], "Deck order remains intact"))
		checks.append(assert_eq(state.players[1 - seat].active_pokemon.damage_counters, 0))
		checks.append(assert_eq(state.players[1 - seat].hand.size(), 1, "Opponent only draws at their normal turn start"))
		var draws: Array = gsm.action_log.filter(func(action: GameAction) -> bool:
			return action.action_type == GameAction.ActionType.DRAW_CARD and action.player_index == seat)
		checks.append(assert_eq(draws.size(), 1))
		if draws.size() == 1:
			checks.append(assert_eq(draws[0].data.get("count"), 1))
			checks.append(assert_eq(draws[0].data.get("source_kind"), "attack"))
			checks.append(assert_eq(draws[0].data.get("source_card_name"), "鬼斯"))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_allure_empty_deck_and_last_card_do_not_cause_immediate_deckout() -> String:
	var checks: Array[String] = []
	for count: int in [0, 1]:
		var gsm := _battle("076")
		var player := gsm.game_state.players[0]
		player.deck.clear()
		if count == 1:
			player.deck.append(_energy(0))
		checks.append(assert_true(gsm.use_attack(0, 0)))
		checks.append(assert_eq(player.hand.size(), count))
		checks.append(assert_true(player.deck.is_empty()))
		checks.append(assert_false(gsm.game_state.is_game_over(), "Only failure to draw at turn start causes deckout"))
		checks.append(assert_eq(gsm.game_state.current_player_index, 1))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_printed_costs_reject_unpaid_attacks_without_effects() -> String:
	var checks: Array[String] = []
	for spec: Array in [["076", 0], ["076", 1], ["077", 0]]:
		var gsm := _battle(spec[0])
		var player := gsm.game_state.players[0]
		var defender := gsm.game_state.players[1].active_pokemon
		player.active_pokemon.attached_energy.clear()
		checks.append(assert_false(gsm.use_attack(0, spec[1])))
		if spec[1] == 1 or spec[0] == "077":
			player.active_pokemon.attached_energy.assign([_energy(0, "PSY"), _energy(0, "PSY")])
			checks.append(assert_false(gsm.use_attack(0, spec[1]), "Two non-Dark Energy cannot pay DC"))
			player.active_pokemon.attached_energy.assign([_energy(0)])
			checks.append(assert_false(gsm.use_attack(0, spec[1]), "One Dark Energy is insufficient"))
		checks.append(assert_eq(defender.damage_counters, 0))
		checks.append(assert_false(defender.status_conditions.asleep))
		checks.append(assert_true(player.hand.is_empty()))
		checks.append(assert_eq(player.deck.size(), 12))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_will_o_wisp_deals_twenty_without_drawing() -> String:
	var checks: Array[String] = []
	for seat: int in 2:
		var gsm := _battle("076", seat)
		var player := gsm.game_state.players[seat]
		checks.append(assert_true(gsm.use_attack(seat, 1)))
		checks.append(assert_eq(gsm.game_state.players[1 - seat].active_pokemon.damage_counters, 20))
		checks.append(assert_true(player.hand.is_empty()))
		checks.append(assert_eq(player.deck.size(), 12))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_dark_slumber_sleeps_active_without_coin_then_normal_checkup() -> String:
	var checks: Array[String] = []
	for seat: int in 2:
		for wakes: bool in [false, true]:
			var coins := HostFixtures.FixedCoins.new()
			coins.results.assign([wakes])
			var gsm := _battle("077", seat, coins)
			var state := gsm.game_state
			var defender := state.players[1 - seat].active_pokemon
			state.players[1 - seat].bench.assign([_slot("076", 1 - seat)])
			defender.set_status("confused", true)
			var status_at_attack: Array = []
			gsm.action_logged.connect(func(action: GameAction) -> void:
				if action.action_type == GameAction.ActionType.ATTACK:
					status_at_attack.assign([defender.status_conditions.asleep, defender.status_conditions.confused, coins.calls]))
			checks.append(assert_true(gsm.use_attack(seat, 0)))
			checks.append(assert_eq(status_at_attack, [true, false, 0], "Sleep is unconditional and replaces Confusion before checkup"))
			checks.append(assert_eq(defender.damage_counters, 40))
			checks.append(assert_eq(defender.status_conditions.asleep, not wakes))
			checks.append(assert_eq(coins.calls, 1, "Only the between-turns sleep check flips a coin"))
			checks.append(assert_false(state.players[seat].active_pokemon.status_conditions.asleep))
			checks.append(assert_false(state.players[1 - seat].bench[0].status_conditions.asleep))
			gsm.prepare_for_disposal()
	return run_checks(checks)


func test_dark_slumber_respects_mist_energy_and_insomnia() -> String:
	var checks: Array[String] = []
	for shield: String in ["mist", "insomnia"]:
		var coins := HostFixtures.FixedCoins.new()
		var gsm := _battle("077", 0, coins)
		var defender := gsm.game_state.players[1].active_pokemon
		if shield == "mist":
			defender.attached_energy.append(CardInstance.create(_bundled("CSV7C_204"), 1))
		else:
			defender.pokemon_stack.assign([CardInstance.create(_bundled("CSV9.5C_141"), 1)])
			gsm.effect_processor.register_pokemon_card(defender.get_card_data())
		checks.append(assert_true(gsm.use_attack(0, 0)))
		checks.append(assert_eq(defender.damage_counters, 40, "Effect protection does not prevent printed damage"))
		checks.append(assert_false(defender.status_conditions.asleep))
		checks.append(assert_eq(coins.calls, 0, "No sleep check when status was prevented"))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_gastly_evolves_into_haunter_and_uses_new_attack() -> String:
	var gsm := _battle("076")
	var player := gsm.game_state.players[0]
	var slot := player.active_pokemon
	slot.turn_played = 1
	var haunter := CardInstance.create(_card("077"), 0)
	player.hand.append(haunter)
	# Normal match startup registers every printing in the deck, including evolutions.
	gsm.effect_processor.register_pokemon_card(haunter.card_data)
	var checks: Array[String] = [assert_true(gsm.evolve_pokemon(0, haunter, slot), "Matching Stage 1 evolves successfully")]
	checks.append(assert_eq(slot.get_card_data().get_uid(), "CSV5C_077"))
	checks.append(assert_eq(slot.pokemon_stack.size(), 2))
	checks.append(assert_true(gsm.use_attack(0, 0), "Evolved attacker can use Dark Slumber immediately"))
	checks.append(assert_eq(gsm.game_state.players[1].active_pokemon.damage_counters, 40))
	checks.append(assert_true(gsm.game_state.players[1].active_pokemon.status_conditions.asleep, "Evolved attack applies Sleep"))
	checks.append(assert_true(player.hand.is_empty(), "Evolution does not retain Gastly's draw effect"))
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_real_host_main_attack_windows_execute_both_cards_and_reject_replay() -> String:
	var checks: Array[String] = []
	var fixture := HostFixtures.new()
	for seat: int in 2:
		for spec: Array in [["076", 0, 0], ["076", 1, 20], ["077", 0, 40]]:
			var gsm := _battle(spec[0], seat)
			var player := gsm.game_state.players[seat]
			var host := fixture._host(gsm, seat)
			if not bool(host.get("ok", false)):
				gsm.prepare_for_disposal()
				return "Unable to bind real Host: %s" % host
			var bridge := HeadlessMatchBridge.new()
			bridge.bind(gsm)
			host.owner.run_single_step(bridge, gsm)
			var checkpoint: Dictionary = host.port.pending_checkpoint()
			fixture._check_frame(checkpoint, checks, [])
			var selected := -1
			for option: Dictionary in checkpoint.get("frame", {}).get("options", []):
				if option.get("kind") == "attack" and option.get("attack_index") == spec[1]:
					selected = int(option.index)
			checks.append(assert_true(selected >= 0, "Printed attack appears in current public frontier"))
			if selected >= 0:
				var handle := str(checkpoint.window_handle)
				checks.append(assert_true(bool(host.port.submit(handle, [selected]).get("ok", false))))
				checks.append(assert_true(host.owner.run_single_step(bridge, gsm)))
				checks.append(assert_false(bool(host.port.submit(handle, [selected]).get("ok", false)), "Committed window cannot be replayed"))
				checks.append(assert_eq(gsm.game_state.players[1 - seat].active_pokemon.damage_counters, spec[2]))
				checks.append(assert_eq(player.hand.size(), 1 if spec[0] == "076" and spec[1] == 0 else 0))
				checks.append(assert_eq(gsm.game_state.players[1 - seat].active_pokemon.status_conditions.asleep, spec[0] == "077"))
				checks.append(assert_eq(host.owner.audit_snapshot().get("engine_commits"), 1))
			bridge.bind(null)
			bridge.free()
			fixture._close_host(host, gsm, 1, checks)
	return run_checks(checks)
