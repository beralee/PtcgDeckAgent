extends TestBase

const Fixtures = preload("res://tests/test_30thdc_cards.gd")
const UIDS := ["151C_085", "CSV6C_015", "CSV6C_060"]

func _source_card(uid: String) -> CardData:
	var response: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/tournament_series59_sources/%s.json" % uid))
	return CardData.from_api_json(response.data)

func _card(uid: String) -> CardData:
	var parts := uid.split("_")
	var card := CardDatabase.get_card(parts[0], parts[1])
	return card if card != null else _source_card(uid)

func _slot(uid: String, seat: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(_card(uid), seat))
	return slot

func _energy(seat: int, double_energy: bool = false) -> CardInstance:
	var data := CardData.new()
	data.name = "Double Turbo Energy" if double_energy else "Basic Psychic Energy"
	data.card_type = "Special Energy" if double_energy else "Basic Energy"
	data.energy_type = "C" if double_energy else "P"
	data.energy_provides = data.energy_type
	if double_energy:
		data.effect_id = "9c04dd0addf56a7b2c88476bc8e45c0e"
	return CardInstance.create(data, seat)

func _battle(uid: String, seat: int = 0) -> GameStateMachine:
	var gsm: GameStateMachine = Fixtures.new()._battle("008")
	var state := gsm.game_state
	state.current_player_index = seat
	for owner: int in 2:
		state.players[owner].active_pokemon = Fixtures.new()._slot("024", owner)
		var neutral := state.players[owner].active_pokemon.get_card_data()
		neutral.hp = 1000
		neutral.weakness_energy = ""
		neutral.resistance_energy = ""
		state.players[owner].active_pokemon.attached_energy.clear()
	state.players[seat].active_pokemon = _slot(uid, seat)
	gsm.effect_processor.register_pokemon_card(state.players[seat].active_pokemon.get_card_data())
	return gsm

func test_exact_tournament_printings_are_database_visible_and_match_source() -> String:
	var checks: Array[String] = []
	for uid: String in UIDS:
		var parts := uid.split("_")
		var card := CardDatabase.get_card(parts[0], parts[1])
		checks.append(assert_not_null(card, "%s must load from the actual database" % uid))
		if card != null:
			var source := _source_card(uid)
			checks.append(assert_eq(card.effect_id, source.effect_id, "Exact source effect identity"))
			checks.append(assert_eq(card.attacks, source.attacks, "Exact printed attacks"))
			checks.append(assert_eq(card.abilities, source.abilities, "Exact printed abilities"))
	return run_checks(checks)

func test_dodrio_draw_damages_once_per_turn_on_active_or_bench_for_each_seat() -> String:
	var checks: Array[String] = []
	for seat: int in 2:
		for on_bench: bool in [false, true]:
			var gsm := _battle("151C_085", seat)
			var state := gsm.game_state
			var player := state.players[seat]
			var dodrio := player.active_pokemon
			if on_bench:
				player.active_pokemon = Fixtures.new()._slot("024", seat)
				player.bench.append(dodrio)
			var previous_hand := player.hand.size()
			var previous_deck := player.deck.size()
			checks.append(assert_true(gsm.use_ability(seat, dodrio), "Raging Draw works in either in-play zone"))
			checks.append(assert_eq(dodrio.damage_counters, 10, "Place exactly one counter"))
			checks.append(assert_eq(player.hand.size(), previous_hand + 1, "Then draw one"))
			checks.append(assert_eq(player.deck.size(), previous_deck - 1))
			checks.append(assert_false(gsm.use_ability(seat, dodrio), "Once per this Pokemon per turn"))
			checks.append(assert_eq(dodrio.damage_counters, 10, "Rejected reuse makes no mutation"))
			state.turn_number += 2
			checks.append(assert_true(gsm.use_ability(seat, dodrio), "Refresh on the next own turn"))
			checks.append(assert_eq(dodrio.damage_counters, 20))
			gsm.prepare_for_disposal()
	return run_checks(checks)

func test_dodrio_suppression_opponent_turn_and_self_knockout_order() -> String:
	var gsm := _battle("151C_085")
	var state := gsm.game_state
	var player := state.players[0]
	var dodrio := player.active_pokemon
	var checks: Array[String] = []
	dodrio.effects.append({"type": "ability_disabled", "turn": state.turn_number})
	checks.append(assert_false(gsm.use_ability(0, dodrio), "Suppressed Raging Draw is unusable"))
	dodrio.effects.clear()
	state.current_player_index = 1
	checks.append(assert_false(gsm.use_ability(0, dodrio), "Only its owner's turn"))
	state.current_player_index = 0
	player.active_pokemon = Fixtures.new()._slot("024", 0)
	player.bench.append(dodrio)
	dodrio.damage_counters = 90
	var top := dodrio.get_top_card()
	var hand_size := player.hand.size()
	checks.append(assert_true(gsm.use_ability(0, dodrio), "May place the lethal tenth counter"))
	checks.append(assert_eq(player.hand.size(), hand_size + 1, "Draw resolves before knockout processing"))
	checks.append(assert_true(top in player.discard_pile, "Real engine resolves the self knockout"))
	checks.append(assert_false(dodrio in player.bench))
	gsm.prepare_for_disposal()
	return run_checks(checks)

func test_dodrio_attack_uses_own_damage_counters() -> String:
	var checks: Array[String] = []
	for amount: int in [0, 30, 90]:
		var gsm := _battle("151C_085")
		var attacker := gsm.game_state.players[0].active_pokemon
		var defender := gsm.game_state.players[1].active_pokemon
		attacker.damage_counters = amount
		attacker.attached_energy.append(_energy(0))
		checks.append(assert_true(gsm.use_attack(0, 0)))
		checks.append(assert_eq(defender.damage_counters, 10 + amount * 3, "10 plus 30 per damage counter"))
		gsm.prepare_for_disposal()
	return run_checks(checks)

func test_espathra_tax_applies_only_from_unsuppressed_opponent_active() -> String:
	var checks: Array[String] = []
	for seat: int in 2:
		var gsm := _battle("CSV6C_015", 1 - seat)
		var state := gsm.game_state
		state.current_player_index = seat
		var attacker := state.players[seat].active_pokemon
		# Neutral fixture attack has a one-Colorless cost.
		attacker.get_card_data().attacks = [{"name": "Tax probe", "cost": "C", "damage": "10", "text": ""}]
		attacker.attached_energy.append(_energy(seat))
		var espathra := state.players[1 - seat].active_pokemon
		var attack: Dictionary = attacker.get_card_data().attacks[0]
		checks.append(assert_eq(gsm.effect_processor.get_attack_colorless_cost_modifier(attacker, attack, state), 1))
		checks.append(assert_false(gsm.rule_validator.can_use_attack(state, seat, 0, gsm.effect_processor), "One Energy cannot cover the increased cost"))
		espathra.effects.append({"type": "ability_disabled", "turn": state.turn_number})
		checks.append(assert_true(gsm.rule_validator.can_use_attack(state, seat, 0, gsm.effect_processor), "Suppression removes the tax"))
		espathra.effects.clear()
		state.players[1 - seat].bench.append(espathra)
		state.players[1 - seat].active_pokemon = Fixtures.new()._slot("024", 1 - seat)
		checks.append(assert_eq(gsm.effect_processor.get_attack_colorless_cost_modifier(attacker, attack, state), 0, "Bench Espathra imposes no tax"))
		state.players[1 - seat].bench.clear()
		state.players[1 - seat].active_pokemon = espathra
		attacker.attached_energy.append(_energy(seat))
		checks.append(assert_true(gsm.use_attack(seat, 0), "Actual attack entry accepts the full increased payment"))
		gsm.prepare_for_disposal()
	return run_checks(checks)

func test_espathra_psy_ball_counts_both_active_energy_units_and_ignores_bench() -> String:
	var checks: Array[String] = []
	for seat: int in 2:
		var gsm := _battle("CSV6C_015", seat)
		var state := gsm.game_state
		var attacker := state.players[seat].active_pokemon
		var defender := state.players[1 - seat].active_pokemon
		attacker.attached_energy.append(_energy(seat))
		defender.attached_energy.append(_energy(1 - seat, true))
		var bench := Fixtures.new()._slot("024", 1 - seat)
		for _i: int in 5:
			bench.attached_energy.append(_energy(1 - seat))
		state.players[1 - seat].bench.append(bench)
		checks.append(assert_true(gsm.use_attack(seat, 0)))
		checks.append(assert_eq(defender.damage_counters, 120, "30 plus 30 for one Psychic and two Double Turbo energy units"))
		checks.append(assert_eq(bench.damage_counters, 0))
		gsm.prepare_for_disposal()
	return run_checks(checks)

func test_flittle_psychic_uses_ten_per_opponent_energy_and_not_generic_thirty() -> String:
	var checks: Array[String] = []
	for opponent_double: bool in [false, true]:
		var gsm := _battle("CSV6C_060")
		var state := gsm.game_state
		var attacker := state.players[0].active_pokemon
		var defender := state.players[1].active_pokemon
		attacker.attached_energy.assign([_energy(0), _energy(0)])
		defender.attached_energy.append(_energy(1, opponent_double))
		checks.append(assert_true(gsm.use_attack(0, 0)))
		checks.append(assert_eq(defender.damage_counters, 30 if opponent_double else 20, "Printed Psychic multiplier is 10 per opponent Energy unit"))
		gsm.prepare_for_disposal()
	return run_checks(checks)

func test_real_host_main_windows_execute_three_printings_for_both_seats() -> String:
	var checks: Array[String] = []
	var f := Fixtures.new()
	for seat: int in 2:
		for uid: String in UIDS:
			var gsm := _battle(uid, seat)
			var state := gsm.game_state
			var player := state.players[seat]
			var attacker := player.active_pokemon
			var defender := state.players[1-seat].active_pokemon
			attacker.attached_energy.assign([f._energy("PSY", seat), f._energy("PSY", seat)])
			defender.attached_energy.assign([f._energy("PSY", 1-seat)])
			var host: Dictionary = f._host(gsm, seat)
			if not host.get("ok", false):
				gsm.prepare_for_disposal()
				return "Host failed for " + uid
			var bridge := HeadlessMatchBridge.new()
			bridge.bind(gsm)
			var handles: Array = []
			var actions: Array = ["use_ability", "attack"] if uid == "151C_085" else ["attack"]
			for kind: String in actions:
				checks.append(assert_false(host.owner.run_single_step(bridge, gsm)))
				var checkpoint: Dictionary = host.port.pending_checkpoint()
				f._check_frame(checkpoint, checks, handles)
				var pick := -1
				for option: Dictionary in checkpoint.get("frame", {}).get("options", []):
					if str(option.get("kind", "")) == kind and (kind != "attack" or int(option.get("attack_index", -1)) == 0):
						pick = int(option.index)
				checks.append(assert_true(pick >= 0, "%s current frontier exposes %s" % [uid, kind]))
				if pick < 0:
					break
				checks.append(assert_true(host.port.submit(str(checkpoint.window_handle), [pick]).get("ok", false)))
				checks.append(assert_true(host.owner.run_single_step(bridge, gsm), "Accepted legal main action executes"))
				checks.append(assert_false(host.port.submit(str(checkpoint.window_handle), [pick]).get("ok", false), "Stale handle is rejected"))
			checks.append(assert_eq(defender.damage_counters, 40 if uid == "151C_085" else (120 if uid == "CSV6C_015" else 20)))
			checks.append(assert_eq(bridge._pending_choice, ""))
			bridge.bind(null)
			bridge.free()
			f._close_host(host, gsm, actions.size(), checks)
	return run_checks(checks)
