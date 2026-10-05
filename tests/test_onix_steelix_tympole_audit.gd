extends TestBase

const Fixtures = preload("res://tests/test_30thdc_cards.gd")
const CoinDiscard = preload("res://scripts/effects/pokemon_effects/AttackCoinFlipDiscardOpponentActiveEnergy.gd")
const Protection = preload("res://scripts/effects/pokemon_effects/AttackCoinFlipPreventDamageAndEffectsNextTurn.gd")


func _card(uid: String) -> CardData:
	return CardData.from_api_json(JSON.parse_string(FileAccess.get_file_as_string(
		"res://tests/fixtures/card_audit_20260927/%s.api.json" % uid)))


func _slot(uid: String, seat: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(_card(uid), seat))
	return slot


func _energy(kind: String, seat: int) -> CardInstance:
	var card := CardData.new()
	card.name = "Basic " + kind
	card.card_type = "Basic Energy"
	card.energy_type = kind
	card.energy_provides = kind
	card.set_code = "AUDIT"
	card.card_index = kind
	return CardInstance.create(card, seat)


func _battle(uid: String, seat: int = 0, coin: CoinFlipper = null) -> GameStateMachine:
	var fixture := Fixtures.new()
	var gsm := fixture._battle("005", coin)
	var state := gsm.game_state
	state.current_player_index = seat
	state.players[seat].active_pokemon = _slot(uid, seat)
	var defender := fixture._slot("024", 1 - seat)
	defender.get_card_data().hp = 1000
	defender.get_card_data().weakness_energy = ""
	defender.get_card_data().resistance_energy = ""
	state.players[1 - seat].active_pokemon = defender
	for kind: String in ["M", "M", "W", "W", "C"]:
		state.players[seat].active_pokemon.attached_energy.append(_energy(kind, seat))
	gsm.effect_processor.register_pokemon_card(state.players[seat].active_pokemon.get_card_data())
	return gsm


func test_real_printing_registration_and_plain_attack_indexes() -> String:
	var checks: Array[String] = []
	CardImplementationStatus.clear_cache()
	for uid: String in ["CSV6C_097", "CSV6C_067", "CSV5C_032", "CSV5C_031"]:
		var gsm := _battle(uid)
		var slot := gsm.game_state.players[0].active_pokemon
		checks.append(assert_eq(slot.get_card_data().get_uid(), uid, "Exact printing is loaded from original API data"))
		checks.append(assert_false(CardImplementationStatus.is_unimplemented(slot.get_card_data()), "Imported printing is advertised as implemented"))
		var effects := gsm.effect_processor.get_attack_effects_for_slot(slot, 0)
		checks.append(assert_eq(effects.size(), 0 if uid == "CSV5C_032" else 1, uid + " registered attack effects"))
		if slot.get_card_data().attacks.size() > 1:
			checks.append(assert_true(gsm.effect_processor.get_attack_effects_for_slot(slot, 1).is_empty(), "Second plain attack has no inherited effect"))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_steelix_earthquake_hits_only_own_bench_and_respects_tera() -> String:
	var checks: Array[String] = []
	for seat: int in 2:
		var gsm := _battle("CSV6C_097", seat)
		var state := gsm.game_state
		var own := state.players[seat]
		var opponent := state.players[1 - seat]
		var weak := _slot("CSV5C_032", seat)
		weak.get_card_data().weakness_energy = "M"
		var resistant := _slot("CSV6C_067", seat)
		resistant.get_card_data().resistance_energy = "M"
		resistant.get_card_data().resistance_value = "-30"
		var tera := _slot("CSV5C_032", seat)
		tera.get_card_data().is_tags = PackedStringArray(["Tera"])
		own.bench.assign([weak, resistant, tera])
		opponent.bench.assign([_slot("CSV5C_032", 1 - seat)])
		checks.append(assert_true(gsm.use_attack(seat, 0)))
		checks.append(assert_eq(opponent.active_pokemon.damage_counters, 130))
		checks.append(assert_eq(weak.damage_counters, 30, "Own Bench ignores weakness"))
		checks.append(assert_eq(resistant.damage_counters, 30, "Own Bench ignores resistance"))
		checks.append(assert_eq(tera.damage_counters, 0, "Tera Bench rule blocks own attack damage"))
		checks.append(assert_eq(opponent.bench[0].damage_counters, 0))
		checks.append(assert_eq(own.active_pokemon.damage_counters, 0))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_plain_attacks_and_printed_water_cost() -> String:
	var checks: Array[String] = []
	for spec: Array in [["CSV6C_097", 1, 180], ["CSV6C_067", 1, 80], ["CSV5C_032", 0, 50]]:
		var gsm := _battle(spec[0])
		var player := gsm.game_state.players[0]
		var defender := gsm.game_state.players[1].active_pokemon
		player.bench.assign([_slot("CSV5C_032", 0)])
		if spec[0] == "CSV5C_032":
			player.active_pokemon.attached_energy.assign([_energy("W", 0), _energy("C", 0)])
			checks.append(assert_false(gsm.use_attack(0, spec[1]), "Two Water are required"))
			player.active_pokemon.attached_energy.append(_energy("W", 0))
		checks.append(assert_true(gsm.use_attack(0, spec[1])))
		checks.append(assert_eq(defender.damage_counters, spec[2], "Printed ordinary damage"))
		checks.append(assert_eq(player.bench[0].damage_counters, 0))
		checks.append(assert_true(player.active_pokemon.effects.is_empty()))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_onix_heads_protects_damage_and_effects_only_next_opponent_turn() -> String:
	var checks: Array[String] = []
	for heads: bool in [true, false]:
		var coins := Fixtures.FixedCoins.new()
		coins.results.assign([heads])
		var gsm := _battle("CSV6C_067", 0, coins)
		var state := gsm.game_state
		var onix := state.players[0].active_pokemon
		var opponent := state.players[1].active_pokemon
		AILegalActionBuilder.new().build_actions(gsm, 0)
		checks.append(assert_eq(coins.calls, 0, "Preview must not consume RNG"))
		checks.append(assert_true(gsm.use_attack(0, 0)))
		checks.append(assert_eq(opponent.damage_counters, 20))
		checks.append(assert_eq(coins.calls, 1))
		checks.append(assert_eq(Protection.prevents_attack_damage(onix, state), heads))
		onix.get_card_data().hp = 1000
		onix.get_card_data().weakness_energy = ""
		opponent.get_card_data().effect_id = "audit_poison"
		opponent.get_card_data().attacks = [{"name": "Poison test", "cost": "", "damage": "40"}]
		gsm.effect_processor.register_attack_effect("audit_poison", EffectApplyStatus.new("poisoned", false, 0))
		checks.append(assert_true(gsm.use_attack(1, 0)))
		checks.append(assert_eq(onix.damage_counters, 0 if heads else 50, "Damage and attack poison are both blocked on heads"))
		checks.append(assert_eq(onix.status_conditions.get("poisoned"), not heads))
		checks.append(assert_false(Protection.prevents_attack_damage(onix, state), "Protection has expired by next own turn"))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_tympole_coin_precedes_energy_window_and_does_not_reroll() -> String:
	var checks: Array[String] = []
	for heads: bool in [true, false]:
		var coins := Fixtures.FixedCoins.new()
		coins.results.assign([heads])
		var gsm := _battle("CSV5C_031", 0, coins)
		var state := gsm.game_state
		var attacker := state.players[0].active_pokemon
		var defender := state.players[1].active_pokemon
		var first := _energy("W", 1)
		var chosen := _energy("M", 1)
		defender.attached_energy.assign([first, chosen])
		var effects := gsm.effect_processor.get_attack_effects_for_slot(attacker, 0)
		if effects.is_empty():
			gsm.prepare_for_disposal()
			return "Tympole Spiral Tail has no registered effect"
		var effect := effects[0]
		var attack := attacker.get_card_data().attacks[0]
		effect.get_attack_preview_interaction_steps(attacker.get_top_card(), attack, state)
		checks.append(assert_eq(coins.calls, 0))
		var steps := effect.get_attack_interaction_steps(attacker.get_top_card(), attack, state)
		effect.get_attack_interaction_steps(attacker.get_top_card(), attack, state)
		checks.append(assert_eq(effect.get_ucis_last_error(), ""))
		checks.append(assert_eq(coins.calls, 1, "Repeat observation must keep the same coin"))
		checks.append(assert_eq(steps.size(), 1 if heads else 0, "Only heads requests an Energy"))
		var context := {CoinDiscard.ENERGY_STEP_ID: [chosen]} if heads else {}
		checks.append(assert_true(gsm.use_attack(0, 0, [context])))
		checks.append(assert_eq(defender.damage_counters, 10))
		checks.append(assert_eq(coins.calls, 1))
		checks.append(assert_eq(chosen in state.players[1].discard_pile, heads))
		checks.append(assert_true(first in defender.attached_energy))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_tympole_real_host_energy_choice_both_seats_reorder_and_stale() -> String:
	var checks: Array[String] = []
	var fixture := Fixtures.new()
	for seat: int in 2:
		var coins := Fixtures.FixedCoins.new()
		coins.results.assign([true])
		var gsm := _battle("CSV5C_031", seat, coins)
		var state := gsm.game_state
		var attacker := state.players[seat].active_pokemon
		var defender := state.players[1 - seat].active_pokemon
		var first := _energy("W", 1 - seat)
		var chosen := CardInstance.create(CardData.from_dict(JSON.parse_string(
			FileAccess.get_file_as_string("res://data/bundled_user/cards/CSNC_024.json")
		)), 1 - seat)
		defender.attached_energy.assign([first, chosen])
		checks.append(assert_eq(gsm.effect_processor.get_energy_colorless_count(chosen, state), 2, "Real Double Turbo printing must supply two units as one physical card"))
		state.players[1 - seat].bench.assign([_slot("CSV6C_067", 1 - seat)])
		state.players[1 - seat].bench[0].attached_energy.append(_energy("C", 1 - seat))
		var host := fixture._host(gsm, seat)
		if not bool(host.get("ok", false)):
			gsm.prepare_for_disposal()
			return "Host creation failed: %s" % host
		var effects := gsm.effect_processor.get_attack_effects_for_slot(attacker, 0)
		if effects.is_empty():
			fixture._close_host(host, gsm, 0, checks)
			return "Missing Spiral Tail registration"
		var steps := effects[0].get_attack_interaction_steps(attacker.get_top_card(), attacker.get_card_data().attacks[0], state)
		checks.append(assert_eq(steps.size(), 1))
		if not steps.is_empty():
			var step := steps[0].duplicate()
			var items: Array = step.items.duplicate()
			items.reverse()
			step["items"] = items
			step["labels"] = [chosen.card_data.name, first.card_data.name]
			var handles: Array = []
			var selected := fixture._pick(host, step, items, [0], {"pending_effect_card": attacker.get_top_card()}, checks, handles)
			checks.append(assert_eq(selected, [chosen], "Current reordered window binds the selected physical card"))
			checks.append(assert_true(gsm.use_attack(seat, 0, [{str(step.id): selected}])))
			checks.append(assert_eq(defender.attached_energy, [first], "One multi-unit Energy card is removed in full"))
			checks.append(assert_true(chosen in state.players[1 - seat].discard_pile))
			checks.append(assert_eq(state.players[1 - seat].bench[0].attached_energy.size(), 1))
			checks.append(assert_eq(coins.calls, 1))
		fixture._close_host(host, gsm, 1, checks)
	return run_checks(checks)


func test_tympole_invalid_choices_do_not_damage_or_discard_or_reroll() -> String:
	var checks: Array[String] = []
	var coins := Fixtures.FixedCoins.new()
	coins.results.assign([true])
	var gsm := _battle("CSV5C_031", 0, coins)
	var state := gsm.game_state
	var attacker := state.players[0].active_pokemon
	var defender := state.players[1].active_pokemon
	var energy := _energy("M", 1)
	defender.attached_energy.assign([energy])
	var effects := gsm.effect_processor.get_attack_effects_for_slot(attacker, 0)
	if effects.is_empty():
		gsm.prepare_for_disposal()
		return "Missing Spiral Tail registration"
	effects[0].get_attack_interaction_steps(attacker.get_top_card(), attacker.get_card_data().attacks[0], state)
	for selection: Variant in [[], [attacker.attached_energy[0]], [energy, energy], "bad"]:
		checks.append(assert_false(gsm.use_attack(0, 0, [{CoinDiscard.ENERGY_STEP_ID: selection}]), "Invalid selection is rejected before damage"))
		checks.append(assert_eq(defender.damage_counters, 0))
		checks.append(assert_eq(defender.attached_energy, [energy]))
		checks.append(assert_eq(coins.calls, 1))
	checks.append(assert_true(gsm.use_attack(0, 0, [{CoinDiscard.ENERGY_STEP_ID: [energy]}]), "Rejected selections leave the valid attack available"))
	checks.append(assert_eq(defender.damage_counters, 10))
	checks.append(assert_eq(coins.calls, 1))
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_tympole_respects_onix_protection_and_mist_energy() -> String:
	var checks: Array[String] = []
	for shield: String in ["onix", "mist"]:
		var coins := Fixtures.FixedCoins.new()
		coins.results.assign([true])
		var gsm := _battle("CSV5C_031", 0, coins)
		var state := gsm.game_state
		var attacker := state.players[0].active_pokemon
		var defender := state.players[1].active_pokemon
		var energy := _energy("M", 1)
		defender.attached_energy.assign([energy])
		if shield == "onix":
			defender.effects.append({"type": Protection.PROTECTION_EFFECT_TYPE, "turn": state.turn_number - 1})
		else:
			energy.card_data.card_type = "Special Energy"
			energy.card_data.effect_id = "fb0948c721db1f31767aa6cf0c2ea692"
		var effects := gsm.effect_processor.get_attack_effects_for_slot(attacker, 0)
		if effects.is_empty():
			gsm.prepare_for_disposal()
			return "Missing Spiral Tail registration"
		effects[0].get_attack_interaction_steps(attacker.get_top_card(), attacker.get_card_data().attacks[0], state)
		checks.append(assert_true(gsm.use_attack(0, 0, [{CoinDiscard.ENERGY_STEP_ID: [energy]}])))
		checks.append(assert_eq(defender.attached_energy, [energy], "Attack effect protection keeps Energy attached"))
		checks.append(assert_eq(defender.damage_counters, 0 if shield == "onix" else 10))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_tympole_no_energy_and_same_turn_repeated_attack_use_fresh_coins() -> String:
	var checks: Array[String] = []
	var coins := Fixtures.FixedCoins.new()
	coins.results.assign([true, false, true])
	var gsm := _battle("CSV5C_031", 0, coins)
	var state := gsm.game_state
	var attacker := state.players[0].active_pokemon
	var defender := state.players[1].active_pokemon
	var effect := gsm.effect_processor.get_attack_effects_for_slot(attacker, 0)[0]
	var attack := attacker.get_card_data().attacks[0]
	checks.append(assert_true(effect.get_attack_interaction_steps(attacker.get_top_card(), attack, state).is_empty(), "Heads with no attached Energy creates no impossible window"))
	checks.append(assert_true(gsm.use_attack(0, 0)))
	checks.append(assert_eq(coins.calls, 1))
	checks.append(assert_eq(defender.damage_counters, 10))
	# Shared effect also serves Festival Lead: a second attack in the same turn
	# must not inherit the previous result. Exercise that effect lifecycle directly.
	var energy := _energy("M", 1)
	defender.attached_energy.assign([energy])
	checks.append(assert_true(effect.get_attack_interaction_steps(attacker.get_top_card(), attack, state).is_empty()))
	effect.execute_attack(attacker, defender, 0, state)
	var next := effect.get_attack_interaction_steps(attacker.get_top_card(), attack, state)
	checks.append(assert_eq(next.size(), 1, "Consumed tails does not contaminate the next attack"))
	checks.append(assert_eq(coins.calls, 3))
	effect.set_attack_interaction_context([{CoinDiscard.ENERGY_STEP_ID: [energy]}])
	effect.execute_attack(attacker, defender, 0, state)
	effect.clear_attack_interaction_context()
	checks.append(assert_true(energy in state.players[1].discard_pile))
	checks.append(assert_eq(coins.calls, 3))
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_real_evolution_lines_and_evolved_attacks() -> String:
	var checks: Array[String] = []
	for pair: Array in [["CSV6C_067", "CSV6C_097", 130], ["CSV5C_031", "CSV5C_032", 50]]:
		var gsm := _battle(pair[0])
		var player := gsm.game_state.players[0]
		var base := player.active_pokemon
		base.turn_played = 1
		var evolution := CardInstance.create(_card(pair[1]), 0)
		player.hand.append(evolution)
		var wrong := CardInstance.create(_card("CSV5C_032" if pair[1] == "CSV6C_097" else "CSV6C_097"), 0)
		player.hand.append(wrong)
		checks.append(assert_false(gsm.evolve_pokemon(0, wrong, base), "Other evolution line is rejected"))
		checks.append(assert_true(gsm.evolve_pokemon(0, evolution, base)))
		checks.append(assert_eq(base.get_card_data().get_uid(), pair[1]))
		checks.append(assert_eq(base.pokemon_stack.size(), 2))
		checks.append(assert_true(gsm.use_attack(0, 0)))
		checks.append(assert_eq(gsm.game_state.players[1].active_pokemon.damage_counters, pair[2]))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_steelix_own_bench_knockout_awards_opponent_prize() -> String:
	var checks: Array[String] = []
	var gsm := _battle("CSV6C_097")
	var player := gsm.game_state.players[0]
	var bench := _slot("CSV5C_032", 0)
	bench.damage_counters = 70
	var top := bench.get_top_card()
	player.bench.assign([bench])
	checks.append(assert_true(gsm.use_attack(0, 0)))
	checks.append(assert_true(top in player.discard_pile, "Own damaged Bench is knocked out normally"))
	checks.append(assert_true(player.bench.is_empty()))
	var prompt := gsm.get_pending_decision_snapshot()
	checks.append(assert_eq(prompt.get("kind"), "take_prize"))
	checks.append(assert_eq(prompt.get("owner_player_index"), 1, "Opponent receives the own-Bench knockout prize"))
	checks.append(assert_eq(prompt.get("count"), 1))
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_onix_protection_clears_after_leaving_active() -> String:
	var checks: Array[String] = []
	var coins := Fixtures.FixedCoins.new()
	coins.results.assign([true])
	var gsm := _battle("CSV6C_067", 0, coins)
	var state := gsm.game_state
	var player := state.players[0]
	var onix := player.active_pokemon
	var bench := _slot("CSV5C_032", 0)
	player.bench.assign([bench])
	checks.append(assert_true(gsm.use_attack(0, 0)))
	checks.append(assert_true(Protection.prevents_attack_damage(onix, state)))
	checks.append(assert_true(BattleFieldTransitionService.switch_active_with_bench(state, 0, bench, "audit_switch")))
	checks.append(assert_true(BattleFieldTransitionService.switch_active_with_bench(state, 0, onix, "audit_return")))
	checks.append(assert_false(Protection.prevents_attack_damage(onix, state), "Returning to Active does not restore protection"))
	gsm.prepare_for_disposal()
	return run_checks(checks)
