extends TestBase

const F = preload("res://tests/test_tournament_series59_additional_pokemon.gd")
const HostFixtures = preload("res://tests/test_30thdc_cards.gd")

func _card(uid: String, seat: int = 0) -> CardInstance:
	return CardInstance.create(F.new()._card(uid), seat)

func test_bianca_preview_uses_effective_hp_without_prior_shared_binding() -> String:
	var gsm := F.new()._battle("151C_084")
	var state := gsm.game_state
	var active := state.players[0].active_pokemon
	active.damage_counters = 50 # 20 printed HP, 70 HP with Charm.
	active.attached_tools.append(_card("CSV1C_118"))
	state.shared_turn_flags.erase("_draw_effect_processor")
	var card := _card("CSV7C_198")
	var effect := gsm.effect_processor.get_effect(card.card_data.effect_id)
	var checks: Array[String] = [assert_false(effect.can_execute(card, state), "70 effective remaining HP must not pass the 30 HP threshold")]
	active.damage_counters = 90
	checks.append(assert_true(effect.can_execute(card, state), "Exactly 30 effective HP qualifies"))
	active.damage_counters = 120
	checks.append(assert_false(effect.can_execute(card, state), "A knocked-out target does not qualify"))
	gsm.prepare_for_disposal()
	return run_checks(checks)

func test_medical_energy_heals_manual_and_attack_hand_attachment_only() -> String:
	var checks: Array[String] = []
	for mode: int in 3:
		var gsm := F.new()._battle("CSV4C_103")
		var state := gsm.game_state
		var player := state.players[0]
		var target := F.new()._slot("CSV4C_073")
		target.damage_counters = 60
		player.bench.append(target)
		var energy := _card("CSV5C_129")
		if mode == 2:
			target = player.active_pokemon
			target.damage_counters = 60
			player.deck.assign([energy])
			gsm.effect_processor.replace_attack_effects(target.get_card_data().effect_id, [AttackMillAndAttachAllEnergy.new(1, 0)])
			checks.append(assert_true(gsm.use_attack(0, 0), "Real attack resolution attaches from deck"))
		else:
			player.hand.append(energy)
			checks.append(assert_true(gsm.attach_energy(0, energy, target) if mode == 0 else gsm.use_attack(0, 0, [{"hand_basic_energy": [energy], "attach_target": [target]}])))
		checks.append(assert_eq(target.damage_counters, 60 if mode == 2 else 30, "Medical Energy mode %d" % mode))
		checks.append(assert_true(energy in target.attached_energy))
		gsm.prepare_for_disposal()
	return run_checks(checks)

func test_community_center_uses_real_supporter_ledger_and_each_players_turn() -> String:
	var gsm := F.new()._battle("151C_084")
	var state := gsm.game_state
	var stadium := _card("CSV8C_202")
	state.players[0].hand.append(stadium)
	var checks: Array[String] = [assert_true(gsm.play_stadium(0, stadium))]
	for seat: int in 2:
		state.players[seat].active_pokemon.damage_counters = 40
		checks.append(assert_false(gsm.use_stadium_effect(seat), "Supporter must have been played this turn"))
		var supporter := _card("CSV2C_122", seat)
		state.players[seat].hand.append(supporter)
		checks.append(assert_true(gsm.play_trainer(seat, supporter, [{"series59_heal_targets": []}])))
		checks.append(assert_true(gsm.use_stadium_effect(seat)))
		checks.append(assert_eq(state.players[seat].active_pokemon.damage_counters, 30))
		checks.append(assert_false(gsm.use_stadium_effect(seat), "Once per player's turn"))
		if seat == 0:
			gsm.end_turn(0)
	checks.append(assert_eq(state.players[0].active_pokemon.damage_counters, 30, "Other player's use does not heal this side"))
	gsm.prepare_for_disposal()
	return run_checks(checks)

func test_meddling_memo_preserves_existing_deck_top_and_draws_exact_hand_size() -> String:
	var gsm := F.new()._battle("151C_084")
	var state := gsm.game_state
	var opponent := state.players[1]
	var old_top: Array = [F.new()._energy("R", 1), F.new()._energy("W", 1), F.new()._energy("P", 1), F.new()._energy("F", 1)]
	var old_hand: Array = [F.new()._energy("L", 1), F.new()._energy("M", 1)]
	opponent.deck.assign(old_top)
	opponent.hand.assign(old_hand)
	var trainer := _card("CSV8C_179")
	state.players[0].hand.append(trainer)
	var checks: Array[String] = [assert_true(gsm.play_trainer(0, trainer, []))]
	checks.append(assert_eq(opponent.hand, old_top.slice(0, 2)))
	checks.append(assert_eq(opponent.deck.slice(0, 2), old_top.slice(2)))
	checks.append(assert_true(old_hand[0] in opponent.deck.slice(2) and old_hand[1] in opponent.deck.slice(2)))
	gsm.prepare_for_disposal()
	return run_checks(checks)

func test_saguaro_zero_two_and_invalid_three_through_real_trainer_entry() -> String:
	var checks: Array[String] = []
	for count: int in [0, 2, 3]:
		var gsm := F.new()._battle("151C_084")
		var player := gsm.game_state.players[0]
		for _i: int in 3:
			var bench := F.new()._slot("CSV4C_073")
			bench.damage_counters = 80
			player.bench.append(bench)
		var trainer := _card("CSV2C_122")
		player.hand.append(trainer)
		checks.append(assert_eq(gsm.play_trainer(0, trainer, [{"series59_heal_targets": player.bench.slice(0, count)}]), count <= 2))
		for i: int in 3:
			checks.append(assert_eq(player.bench[i].damage_counters, 30 if count == 2 and i < 2 else 80))
		checks.append(assert_eq(trainer in player.hand, count == 3))
		gsm.prepare_for_disposal()
	return run_checks(checks)

func test_four_healers_complete_real_host_main_to_target_to_execution() -> String:
	var checks: Array[String] = []
	var fixtures := HostFixtures.new()
	for uid: String in ["CSV2C_122", "CSV7C_198", "CSV8C_180", "SVP_341"]:
		for seat: int in 2:
			var gsm := F.new()._battle("151C_084", seat)
			var player := gsm.game_state.players[seat]
			var target := F.new()._slot("CSV4C_073", seat)
			target.get_card_data().hp = 200
			target.damage_counters = 180
			player.bench.append(target)
			var trainer := _card(uid, seat)
			player.hand.append(trainer)
			var host := fixtures._host(gsm, seat)
			if not bool(host.get("ok", false)):
				gsm.prepare_for_disposal()
				return "Host creation failed: %s" % host
			var bridge := HeadlessMatchBridge.new()
			bridge.bind(gsm)
			var main_submitted := false
			var handles: Array = []
			var completed := false
			for _tick: int in 40:
				host.owner.run_single_step(bridge, gsm)
				var checkpoint: Dictionary = host.port.pending_checkpoint()
				if bool(checkpoint.get("ok", false)):
					fixtures._check_frame(checkpoint, checks, handles)
					var choices: Array = []
					if not main_submitted:
						for option: Dictionary in checkpoint.frame.options:
							if str(option.kind) == "play_trainer" and str(option.card_uid) == uid:
								choices = [option.index]
								break
						checks.append(assert_false(choices.is_empty(), uid + " is legal in the actual main window"))
						if choices.is_empty(): break
						main_submitted = true
					else:
						choices = [checkpoint.frame.options[0].index]
					checks.append(assert_true(bool(host.port.submit(str(checkpoint.window_handle), choices).get("ok", false))))
				elif main_submitted and bridge._pending_choice == "":
					completed = true
					break
			checks.append(assert_true(completed, uid + " full Host flow completes"))
			var amount := {"CSV2C_122": 50, "CSV7C_198": 180, "CSV8C_180": 150, "SVP_341": 60}
			checks.append(assert_eq(target.damage_counters, maxi(0, 180-int(amount[uid])), uid))
			checks.append(assert_true(trainer in player.discard_pile))
			bridge.bind(null)
			bridge.free()
			fixtures._close_host(host, gsm, handles.size(), checks)
	return run_checks(checks)
