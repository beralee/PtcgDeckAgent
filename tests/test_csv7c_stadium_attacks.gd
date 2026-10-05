extends TestBase

const Fixtures = preload("res://tests/test_30thdc_cards.gd")


func _card(index: String) -> CardData:
	return CardData.from_api_json(JSON.parse_string(FileAccess.get_file_as_string(
		"res://tests/fixtures/card_audit_20260927/CSV7C_%s.api.json" % index)))


func _slot(index: String, seat: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(_card(index), seat))
	return slot


func _energy(kind: String, seat: int) -> CardInstance:
	var data := CardData.new()
	data.name = "Basic " + kind
	data.card_type = "Basic Energy"
	data.energy_type = kind
	data.energy_provides = kind
	data.set_code = "AUDIT"
	data.card_index = kind
	return CardInstance.create(data, seat)


func _battle(index: String, seat: int = 0) -> GameStateMachine:
	var fixture := Fixtures.new()
	var gsm := fixture._battle("005")
	var state := gsm.game_state
	state.current_player_index = seat
	state.players[seat].active_pokemon = _slot(index, seat)
	var defender := fixture._slot("024", 1 - seat)
	defender.get_card_data().hp = 1000
	defender.get_card_data().weakness_energy = ""
	defender.get_card_data().resistance_energy = ""
	state.players[1 - seat].active_pokemon = defender
	for symbol: String in ["R", "F", "F"]:
		state.players[seat].active_pokemon.attached_energy.append(_energy(symbol, seat))
	gsm.effect_processor.register_pokemon_card(state.players[seat].active_pokemon.get_card_data())
	return gsm


func _stadium(state: GameState, seat: int) -> CardInstance:
	var card := CardData.new()
	card.name = "Stadium fixture"
	card.card_type = "Stadium"
	card.set_code = "AUDIT"
	card.card_index = "STADIUM"
	card.effect_id = "audit_stadium"
	var instance := CardInstance.create(card, seat)
	state.stadium_card = instance
	state.stadium_owner_index = seat
	return instance


func test_exact_source_registration_and_automatic_interactions() -> String:
	var checks: Array[String] = []
	CardImplementationStatus.clear_cache()
	for index: String in ["050", "133"]:
		var gsm := _battle(index)
		var state := gsm.game_state
		var attacker := state.players[0].active_pokemon
		_stadium(state, 1)
		checks.append(assert_eq(attacker.get_card_data().get_uid(), "CSV7C_" + index))
		checks.append(assert_eq(attacker.get_card_data().hp, 110 if index == "050" else 140))
		checks.append(assert_false(CardImplementationStatus.is_unimplemented(attacker.get_card_data())))
		for attack_index: int in 2:
			var effects := gsm.effect_processor.get_attack_effects_for_slot(attacker, attack_index)
			checks.append(assert_eq(effects.size(), 0 if index == "133" and attack_index == 1 else 1, "Exact attack registration"))
			for effect: BaseEffect in effects:
				checks.append(assert_true(effect.get_attack_interaction_steps(attacker.get_top_card(), attacker.get_card_data().attacks[attack_index], state).is_empty(), "Printed effect is mandatory and has no choice"))
				checks.append(assert_eq(effect.get_ucis_last_error(), ""))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_chi_yu_draws_up_to_two_without_touching_stadium_or_defender() -> String:
	var checks: Array[String] = []
	for seat: int in 2:
		for deck_count: int in [0, 1, 3]:
			var gsm := _battle("050", seat)
			var state := gsm.game_state
			var player := state.players[seat]
			player.deck.resize(deck_count)
			var expected := player.deck.slice(0, mini(2, deck_count))
			var stadium := _stadium(state, 1 - seat)
			checks.append(assert_true(gsm.use_attack(seat, 0)))
			checks.append(assert_eq(player.hand, expected, "Draws physical top cards in order"))
			checks.append(assert_eq(player.deck.size(), maxi(0, deck_count - 2)))
			checks.append(assert_eq(state.stadium_card, stadium))
			checks.append(assert_eq(state.players[1 - seat].active_pokemon.damage_counters, 0))
			checks.append(assert_false(state.is_game_over(), "Empty deck during an attack draw does not lose immediately"))
			gsm.prepare_for_disposal()
	return run_checks(checks)


func test_chi_yu_stadium_bonus_preview_weakness_and_owner_discard() -> String:
	var checks: Array[String] = []
	for seat: int in 2:
		for stadium_owner: int in [-1, 0, 1]:
			var gsm := _battle("050", seat)
			var state := gsm.game_state
			var attacker := state.players[seat].active_pokemon
			var defender := state.players[1 - seat].active_pokemon
			defender.get_card_data().weakness_energy = "R"
			defender.get_card_data().weakness_value = "×2"
			var stadium := _stadium(state, stadium_owner) if stadium_owner >= 0 else null
			var expected := 240 if stadium != null else 120
			checks.append(assert_eq(gsm._calculate_attack_damage(attacker, defender, attacker.get_card_data().attacks[1], 1), expected))
			AILegalActionBuilder.new().build_actions(gsm, seat)
			checks.append(assert_eq(state.stadium_card, stadium, "Preview must not discard the Stadium"))
			checks.append(assert_true(gsm.use_attack(seat, 1)))
			checks.append(assert_eq(defender.damage_counters, expected, "Bonus is added before weakness"))
			checks.append(assert_eq(state.stadium_card, null))
			checks.append(assert_eq(state.stadium_owner_index, -1))
			if stadium != null:
				checks.append(assert_eq(state.players[stadium_owner].discard_pile.count(stadium), 1))
				checks.append(assert_false(stadium in state.players[1 - stadium_owner].discard_pile))
			gsm.prepare_for_disposal()
	return run_checks(checks)


func test_stadium_defense_remains_until_attack_damage_finishes() -> String:
	var gsm := _battle("050")
	var state := gsm.game_state
	_stadium(state, 1)
	gsm.effect_processor.register_effect("audit_stadium", EffectStadiumDamageModifier.new(-30, "defense", "M"))
	state.players[1].active_pokemon.get_card_data().energy_type = "M"
	var checks: Array[String] = [assert_true(gsm.use_attack(0, 1))]
	checks.append(assert_eq(state.players[1].active_pokemon.damage_counters, 90, "120 minus the still-active Stadium's 30"))
	checks.append(assert_eq(state.stadium_card, null))
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_ting_lu_stadium_splash_both_seats_owners_and_no_weakness_resistance() -> String:
	var checks: Array[String] = []
	for seat: int in 2:
		for stadium_owner: int in [-1, 0, 1]:
			var gsm := _battle("133", seat)
			var state := gsm.game_state
			var own := state.players[seat]
			var opponent := state.players[1 - seat]
			own.bench.assign([_slot("050", seat)])
			var weak := _slot("050", 1 - seat)
			weak.get_card_data().weakness_energy = "F"
			var resistant := _slot("133", 1 - seat)
			resistant.get_card_data().resistance_energy = "F"
			resistant.get_card_data().resistance_value = "-30"
			opponent.bench.assign([weak, resistant])
			var stadium := _stadium(state, stadium_owner) if stadium_owner >= 0 else null
			checks.append(assert_true(gsm.use_attack(seat, 0)))
			checks.append(assert_eq(opponent.active_pokemon.damage_counters, 30))
			checks.append(assert_eq(weak.damage_counters, 30 if stadium != null else 0))
			checks.append(assert_eq(resistant.damage_counters, 30 if stadium != null else 0))
			checks.append(assert_eq(own.bench[0].damage_counters, 0))
			checks.append(assert_eq(state.stadium_card, null))
			if stadium != null:
				checks.append(assert_eq(state.players[stadium_owner].discard_pile.count(stadium), 1))
			gsm.prepare_for_disposal()
	return run_checks(checks)


func test_ting_lu_bench_protection_and_empty_bench_do_not_stop_stadium_discard() -> String:
	var checks: Array[String] = []
	for mode: String in ["empty", "tera", "immune", "suppressed"]:
		var gsm := _battle("133")
		var state := gsm.game_state
		var target := _slot("050", 1)
		if mode == "tera":
			target.get_card_data().is_tags = PackedStringArray(["Tera"])
		elif mode in ["immune", "suppressed"]:
			target.get_card_data().abilities = [{"name": "毫不在意", "text": ""}]
			if mode == "suppressed":
				target.effects.append({"type": "ability_disabled", "turn": state.turn_number})
		if mode != "empty":
			state.players[1].bench.append(target)
		var stadium := _stadium(state, 0)
		checks.append(assert_true(gsm.use_attack(0, 0)))
		checks.append(assert_eq(target.damage_counters, 30 if mode == "suppressed" else 0))
		checks.append(assert_true(stadium in state.players[0].discard_pile))
		checks.append(assert_eq(state.stadium_card, null))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_plain_headbutt_and_printed_attack_costs() -> String:
	var checks: Array[String] = []
	for index: String in ["050", "133"]:
		var gsm := _battle(index)
		var state := gsm.game_state
		var player := state.players[0]
		player.active_pokemon.attached_energy.clear()
		var stadium := _stadium(state, 1)
		checks.append(assert_false(gsm.use_attack(0, 1), "Insufficient Energy is rejected without discarding"))
		checks.append(assert_eq(state.stadium_card, stadium))
		if index == "133":
			for symbol: String in ["F", "F", "P"]:
				player.active_pokemon.attached_energy.append(_energy(symbol, 0))
			state.players[1].bench.assign([_slot("050", 1)])
			checks.append(assert_true(gsm.use_attack(0, 1)))
			checks.append(assert_eq(state.players[1].active_pokemon.damage_counters, 110))
			checks.append(assert_eq(state.players[1].bench[0].damage_counters, 0))
			checks.append(assert_eq(state.stadium_card, stadium, "Headbutt does not inherit Land Crush"))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_ting_lu_bench_knockout_awards_prize_after_stadium_discard() -> String:
	var checks: Array[String] = []
	for seat: int in 2:
		var gsm := _battle("133", seat)
		var state := gsm.game_state
		var bench := _slot("050", 1 - seat)
		bench.damage_counters = 80
		var top := bench.get_top_card()
		state.players[1 - seat].bench.append(bench)
		var stadium := _stadium(state, 1 - seat)
		checks.append(assert_true(gsm.use_attack(seat, 0)))
		checks.append(assert_true(top in state.players[1 - seat].discard_pile))
		checks.append(assert_true(state.players[1 - seat].bench.is_empty()))
		checks.append(assert_true(stadium in state.players[1 - seat].discard_pile))
		var prompt := gsm.get_pending_decision_snapshot()
		checks.append(assert_eq(prompt.get("kind"), "take_prize"))
		checks.append(assert_eq(prompt.get("owner_player_index"), seat))
		checks.append(assert_eq(prompt.get("count"), 1))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_stadium_hp_penalty_ends_before_knockouts_are_checked() -> String:
	var gsm := _battle("133")
	var state := gsm.game_state
	var target := Fixtures.new()._slot("023", 1)
	target.damage_counters = 130
	state.players[1].bench.append(target)
	var stadium_data := CardData.from_dict(JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/bundled_user/cards/CSV7C_201.json")))
	state.stadium_card = CardInstance.create(stadium_data, 1)
	state.stadium_owner_index = 1
	var checks: Array[String] = []
	# Gravity Mountain reduces Stage 2 HP from 170 to 140 while in play.
	checks.append(assert_eq(gsm.effect_processor.get_effective_max_hp(target, state), 140))
	checks.append(assert_true(gsm.use_attack(0, 0)))
	checks.append(assert_eq(target.damage_counters, 160))
	checks.append(assert_true(target in state.players[1].bench, "Stadium is discarded before the KO check, restoring HP to 170"))
	checks.append(assert_eq(state.stadium_card, null))
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_real_author_main_windows_commit_automatic_attacks_and_reject_replay() -> String:
	var checks: Array[String] = []
	var fixture := Fixtures.new()
	for seat: int in 2:
		for index: String in ["050", "133"]:
			var gsm := _battle(index, seat)
			var state := gsm.game_state
			state.players[1 - seat].bench.append(_slot("050", 1 - seat))
			var stadium := _stadium(state, 1 - seat)
			# Match inventory is sealed before cards are played onto the field.
			state.stadium_card = null
			state.stadium_owner_index = -1
			state.players[1 - seat].hand.append(stadium)
			for player: PlayerState in state.players:
				var count := player.deck.size() + player.hand.size() + player.discard_pile.size() + player.prizes.size()
				for slot: PokemonSlot in player.get_all_pokemon():
					count += slot.collect_all_cards().size()
				while count < 60:
					player.deck.append(_energy("P", player.player_index))
					count += 1
			var port := Fixtures.PortScript.new()
			var host := Fixtures.OwnerScript.create_external(gsm, seat, "csv7c-stadium-%s-%d" % [index, seat], port)
			if not bool(host.get("ok", false)):
				gsm.prepare_for_disposal()
				return "Host creation failed: %s" % host
			state.current_player_index = 1 - seat
			checks.append(assert_true(gsm.play_stadium(1 - seat, stadium)))
			state.current_player_index = seat
			var bridge := HeadlessMatchBridge.new()
			bridge.bind(gsm)
			checks.append(assert_false(host.owner.run_single_step(bridge, gsm), "Wait for current MAIN indexes"))
			var checkpoint := port.pending_checkpoint()
			var handles: Array = []
			fixture._check_frame(checkpoint, checks, handles)
			var selected_index := -1
			for option: Dictionary in checkpoint.get("frame", {}).get("options", []):
				if option.get("kind", "") == "attack" and int(option.get("attack_index", -1)) == (1 if index == "050" else 0):
					selected_index = int(option.index)
			checks.append(assert_true(selected_index >= 0, "Printed attack must be exposed in the legal frontier"))
			if selected_index >= 0:
				checks.append(assert_true(bool(port.submit(str(checkpoint.window_handle), [selected_index]).get("ok", false))))
				checks.append(assert_true(host.owner.run_single_step(bridge, gsm), "Host executes the accepted attack"))
				checks.append(assert_false(bool(port.submit(str(checkpoint.window_handle), [selected_index]).get("ok", false)), "Consumed window rejects repeated indexes"))
				checks.append(assert_eq(state.players[1 - seat].active_pokemon.damage_counters, 120 if index == "050" else 30))
				checks.append(assert_eq(state.players[1 - seat].bench[0].damage_counters, 0 if index == "050" else 30))
				checks.append(assert_eq(state.stadium_card, null))
				checks.append(assert_true(stadium in state.players[1 - seat].discard_pile))
				checks.append(assert_eq(bridge.get_pending_prompt_type(), "", "No unnecessary effect choice"))
				checks.append(assert_eq(host.owner.audit_snapshot().get("engine_commits"), 1))
			bridge.bind(null)
			bridge.free()
			fixture._close_host(host, gsm, 1, checks)
	return run_checks(checks)
