extends TestBase

const Cards = preload("res://tests/test_tournament_series59_pokemon.gd")
const Fixtures = preload("res://tests/test_30thdc_cards.gd")
var cards := Cards.new()
var f := Fixtures.new()

func _attack_state(uid: String, index: int, protection: bool = false) -> GameStateMachine:
	var gsm := cards._battle(uid)
	var state := gsm.game_state
	var attacker := state.players[0].active_pokemon
	attacker.attached_energy.assign([f._energy("PSY"), f._energy("PSY"), f._energy("GRA")])
	var target := f._slot("008", 1)
	target.get_card_data().hp = 1000
	target.turn_played = 1
	target.attached_energy.assign([f._energy("PSY", 1), f._energy("PSY", 1)])
	if protection:
		var mist := cards._energy(1)
		mist.card_data.card_type = "Special Energy"
		mist.card_data.effect_id = "fb0948c721db1f31767aa6cf0c2ea692"
		target.attached_energy.append(mist)
	state.players[1].active_pokemon = target
	gsm.use_attack(0, index)
	return gsm

func test_bronzong_blocks_normal_and_rare_candy_hand_evolution_then_expires() -> String:
	var checks: Array[String] = []
	var gsm := _attack_state("CSV7C_095", 0, true)
	var state := gsm.game_state
	var player := state.players[1]
	var base := player.active_pokemon
	var evolution := CardInstance.create(f._card("009"), 1)
	player.hand.append(evolution)
	checks.append(assert_eq(base.damage_counters, 30))
	checks.append(assert_false(gsm.rule_validator.can_evolve(state, 1, base, evolution, gsm.effect_processor), "Evolution lock affects player even if defender has Mist Energy"))
	checks.append(assert_false(gsm.evolve_pokemon(1, evolution, base)))
	checks.append(assert_true(evolution in player.hand))
	# Preserve the player's restriction when the Bronzong which caused it leaves play.
	state.players[0].active_pokemon = f._slot("024")
	checks.append(assert_false(gsm.evolve_pokemon(1, evolution, base)))
	var basic := CardInstance.create(f._card("008"), 1)
	player.hand.append(basic)
	checks.append(assert_false(gsm.effect_processor.prevents_card_from_hand(1, basic, state), "Basic Pokemon are allowed"))
	var stage2 := cards._card("CSV1C_044")
	var magnet := CardData.new()
	magnet.name = "小磁怪"
	magnet.card_type = "Pokemon"
	magnet.stage = "Basic"
	magnet.hp = 60
	var target := PokemonSlot.new()
	target.pokemon_stack.append(CardInstance.create(magnet, 1))
	target.turn_played = 1
	player.bench.append(target)
	var stage2_instance := CardInstance.create(stage2, 1)
	player.hand.append(stage2_instance)
	var candy := EffectRareCandy.new()
	checks.append(assert_false(candy._can_rare_candy_evolve(stage2_instance, target, state), "Rare Candy cannot evade the hand evolution restriction"))
	state.turn_number += 2
	checks.append(assert_true(gsm.evolve_pokemon(1, evolution, base), "Restriction expires after the next opponent turn"))
	gsm.prepare_for_disposal()
	return run_checks(checks)

func test_bronzong_second_attack_does_not_apply_evolution_lock() -> String:
	var gsm := _attack_state("CSV7C_095", 1)
	var evolution := CardInstance.create(f._card("009"), 1)
	gsm.game_state.players[1].hand.append(evolution)
	var checks: Array[String] = [assert_true(gsm.evolve_pokemon(1, evolution, gsm.game_state.players[1].active_pokemon))]
	gsm.prepare_for_disposal()
	return run_checks(checks)

func test_smoliv_oil_tails_fails_without_damage_heads_attacks_and_check_is_reused() -> String:
	var checks: Array[String] = []
	for heads: bool in [false, true]:
		var gsm := _attack_state("CSV1C_015", 1)
		var state := gsm.game_state
		var coins := Fixtures.FixedCoins.new()
		coins.results.assign([heads, false])
		gsm.coin_flipper = coins
		var attacker := state.players[1].active_pokemon
		checks.append(assert_eq(attacker.damage_counters, 40))
		checks.append(assert_eq(gsm.prepare_attack_interaction(1, attacker, 0), heads))
		checks.append(assert_eq(coins.calls, 1, "Flip exactly once after legal declaration"))
		if heads:
			checks.append(assert_true(gsm.use_attack(1, 0)))
			checks.append(assert_eq(coins.calls, 1, "Final execute reuses declaration result"))
		checks.append(assert_eq(state.players[0].active_pokemon.damage_counters, 10 if heads else 0))
		checks.append(assert_eq(attacker.damage_counters, 40, "Oil failure is not confusion self damage"))
		checks.append(assert_eq(state.current_player_index, 0, "Tails also ends the turn"))
		gsm.prepare_for_disposal()
	return run_checks(checks)

func test_smoliv_oil_works_before_confusion_and_rejects_illegal_attack_without_randomness() -> String:
	var gsm := _attack_state("CSV1C_015", 1)
	var state := gsm.game_state
	var attacker := state.players[1].active_pokemon
	var coins := Fixtures.FixedCoins.new()
	coins.results.assign([false, false])
	gsm.coin_flipper = coins
	var checks: Array[String] = []
	attacker.attached_energy.clear()
	checks.append(assert_false(gsm.prepare_attack_interaction(1, attacker, 0)))
	checks.append(assert_eq(coins.calls, 0))
	attacker.attached_energy.append(f._energy("PSY", 1))
	attacker.status_conditions.confused = true
	checks.append(assert_true(gsm.use_attack(1, 0), "A legal declaration failing its coin is consumed"))
	checks.append(assert_eq(coins.calls, 1, "Oil check precedes confusion: tails prevents its coin"))
	checks.append(assert_eq(attacker.damage_counters, 40))
	checks.append(assert_eq(state.players[0].active_pokemon.damage_counters, 0))
	gsm.prepare_for_disposal()
	return run_checks(checks)

func test_smoliv_no_check_after_switch_evolve_expiry_or_mist_and_first_attack_is_plain() -> String:
	var checks: Array[String] = []
	for clearing: String in ["switch", "evolve", "expire", "mist", "first"]:
		var gsm := _attack_state("CSV1C_015", 0 if clearing == "first" else 1, clearing == "mist")
		var state := gsm.game_state
		var player := state.players[1]
		var attacker := player.active_pokemon
		match clearing:
			"switch":
				var bench := f._slot("024", 1)
				player.bench.append(bench)
				BattleFieldTransitionService.switch_active_with_bench(state, 1, bench, "test_switch")
				BattleFieldTransitionService.switch_active_with_bench(state, 1, attacker, "test_return")
			"evolve":
				var evolution := CardInstance.create(f._card("009"), 1)
				player.hand.append(evolution)
				checks.append(assert_true(gsm.evolve_pokemon(1, evolution, attacker)))
				attacker.attached_energy.append(f._energy("LIG", 1))
			"expire": state.turn_number += 2
		var coins := Fixtures.FixedCoins.new()
		coins.results.assign([false])
		gsm.coin_flipper = coins
		checks.append(assert_true(gsm.use_attack(1, 0), clearing))
		checks.append(assert_eq(coins.calls, 0, clearing + " removes or prevents the oil effect"))
		gsm.prepare_for_disposal()
	return run_checks(checks)

func test_oil_declared_tool_attack_checks_once_and_invalid_selection_cannot_flip() -> String:
	var checks: Array[String] = []
	for heads: bool in [false, true]:
		var gsm := _attack_state("CSV1C_015", 1)
		var state := gsm.game_state
		var attacker := state.players[1].active_pokemon
		var defender := state.players[0].active_pokemon
		defender.damage_counters = 10
		defender.get_card_data().hp = 1000
		attacker.attached_energy.append(f._energy("PSY", 1))
		attacker.attached_tool = CardInstance.create(cards._card("CSV4C_120"), 1)
		var granted := gsm.effect_processor.get_granted_attacks(attacker, state)[0]
		var coins := Fixtures.FixedCoins.new()
		coins.results.assign([heads, false])
		gsm.coin_flipper = coins
		checks.append(assert_false(gsm.use_granted_attack(1, attacker, granted, [{"tm_blindside_target": [attacker]}])))
		checks.append(assert_eq(coins.calls, 0, "Invalid target cannot consume the declaration coin"))
		checks.append(assert_eq(gsm.prepare_attack_interaction(1, attacker, -1, granted), heads))
		checks.append(assert_eq(coins.calls, 1))
		if heads:
			checks.append(assert_true(gsm.use_granted_attack(1, attacker, granted, [{"tm_blindside_target": [defender]}])))
			checks.append(assert_eq(coins.calls, 1))
		checks.append(assert_eq(defender.damage_counters, 110 if heads else 10))
		gsm.prepare_for_disposal()
	return run_checks(checks)

func test_oil_attack_runs_through_host_and_bronzong_hides_blocked_evolutions() -> String:
	var checks: Array[String] = []
	for uid: String in ["CSV1C_015", "CSV7C_095"]:
		var gsm := _attack_state(uid, 1 if uid == "CSV1C_015" else 0)
		var state := gsm.game_state
		var evolution := CardInstance.create(f._card("009"), 1)
		state.players[1].hand.append(evolution)
		var coins := Fixtures.FixedCoins.new()
		coins.results.assign([false])
		gsm.coin_flipper = coins
		var host: Dictionary = f._host(gsm, 1)
		if not host.get("ok", false):
			gsm.prepare_for_disposal()
			return "Temporary lock Host could not start"
		var bridge := HeadlessMatchBridge.new()
		bridge.bind(gsm)
		host.owner.run_single_step(bridge, gsm)
		var checkpoint: Dictionary = host.port.pending_checkpoint()
		var handles: Array = []
		f._check_frame(checkpoint, checks, handles)
		var pick := -1
		for option: Dictionary in checkpoint.get("frame", {}).get("options", []):
			if uid == "CSV7C_095":
				checks.append(assert_false(option.get("kind") == "evolve", "Blocked hand evolution is absent from the legal public frontier"))
			if option.get("kind") == "attack" and int(option.get("attack_index", -1)) == 0:
				pick = int(option.index)
		checks.append(assert_true(pick >= 0))
		if pick >= 0:
			checks.append(assert_true(host.port.submit(str(checkpoint.window_handle), [pick]).get("ok", false)))
			checks.append(assert_true(host.owner.run_single_step(bridge, gsm)))
			checks.append(assert_false(host.port.submit(str(checkpoint.window_handle), [pick]).get("ok", false)))
		checks.append(assert_eq(coins.calls, 1 if uid == "CSV1C_015" else 0))
		checks.append(assert_eq(state.players[0].active_pokemon.damage_counters, 0 if uid == "CSV1C_015" else 10))
		bridge.bind(null)
		bridge.free()
		f._close_host(host, gsm, 1, checks)
	return run_checks(checks)
