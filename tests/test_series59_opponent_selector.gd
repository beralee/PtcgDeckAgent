extends TestBase

const F=preload("res://tests/test_30thdc_cards.gd")
const C=preload("res://tests/test_tournament_series59_special_trainers.gd")
var f:=F.new()
var c:=C.new()

func test_banette_full_host_defending_seat_alone_sees_and_selects_own_hand() -> String:
	var checks: Array[String]=[]
	for attacking_seat: int in 2:
		var defending_seat:=1-attacking_seat
		var gsm:=f._battle("005")
		var state:=gsm.game_state
		state.current_player_index=attacking_seat
		var attacker:=state.players[attacking_seat]
		var defender:=state.players[defending_seat]
		attacker.active_pokemon=c._slot("CSVH5eC_027",attacking_seat)
		attacker.active_pokemon.attached_energy.append(f._energy("PSY",attacking_seat))
		gsm.effect_processor.register_pokemon_card(attacker.active_pokemon.get_card_data())
		attacker.hand.assign([c._card("CSV8C_174",attacking_seat)])
		defender.hand.assign([c._card("30thDC_002",defending_seat),c._card("30thDC_004",defending_seat),f._energy("DAR",defending_seat),f._energy("GRA",defending_seat)])
		var own_hand_before:=attacker.hand.duplicate()
		var defender_hand_before:=defender.hand.duplicate()
		var hosts: Array=[f._host(gsm,0),f._host(gsm,1)]
		var declaring: Dictionary=hosts[attacking_seat]
		var choosing: Dictionary=hosts[defending_seat]
		var bridge:=HeadlessMatchBridge.new()
		bridge.bind(gsm)
		declaring.owner.run_single_step(bridge,gsm)
		var main: Dictionary=declaring.port.pending_checkpoint()
		var handles: Array=[]
		f._check_frame(main,checks,handles)
		if not bool(main.get("ok",false)):
			bridge.bind(null)
			bridge.free()
			for host: Dictionary in hosts: host.owner.close_match()
			gsm.prepare_for_disposal()
			return "Banette declaration unavailable"
		checks.append(assert_false(main.frame.public_state.opponent.has("hand"),"Attacker's main view never exposes opponent hand"))
		var indexes: Array=[]
		for option: Dictionary in main.frame.options:
			if option.kind=="attack" and option.attack_index==0: indexes=[option.index]
		checks.append(assert_true(bool(declaring.port.submit(str(main.window_handle),indexes).get("ok",false))))
		declaring.owner.run_single_step(bridge,gsm)
		checks.append(assert_eq(bridge._pending_choice,"effect_interaction"))
		checks.append(assert_eq(bridge._resolve_effect_step_chooser_player(bridge._pending_effect_steps[bridge._pending_effect_step_index]),defending_seat))
		checks.append(assert_false(declaring.owner.run_single_step(bridge,gsm),"Attacker cannot run defender's private choice"))
		checks.append(assert_false(bool(declaring.port.pending_checkpoint().get("ok",false)),"No private hand window sent to attacker"))
		choosing.owner.run_single_step(bridge,gsm)
		var selection: Dictionary=choosing.port.pending_checkpoint()
		f._check_frame(selection,checks,handles)
		if bool(selection.get("ok",false)):
			checks.append(assert_eq(selection.frame.public_state.self.hand.size(),4))
			checks.append(assert_false(selection.frame.public_state.opponent.has("hand")))
			checks.append(assert_eq(selection.frame.options.size(),4))
			for option: Dictionary in selection.frame.options:
				checks.append(assert_eq(option.option_player_index,defending_seat))
			checks.append(assert_eq(selection.frame.select_semantics.min_count,3))
			checks.append(assert_eq(selection.frame.select_semantics.max_count,3))
			checks.append(assert_true(bool(choosing.port.submit(str(selection.window_handle),[0,2,3]).get("ok",false))))
			choosing.owner.run_single_step(bridge,gsm)
			checks.append(assert_eq(bridge._pending_choice,"","Selection commits actual attack"))
			checks.append(assert_eq(state.current_player_index,defending_seat))
			checks.append(assert_eq(attacker.hand,own_hand_before))
			checks.append(assert_true(defender_hand_before[1] in defender.hand,"Unchosen hand card retained"))
			checks.append(assert_eq(defender.hand.size(),2,"Keeps one then draws at new turn"))
		checks.append(assert_eq(declaring.owner.audit_snapshot().get("policy_successes"),1))
		checks.append(assert_eq(choosing.owner.audit_snapshot().get("policy_successes"),1))
		for host: Dictionary in hosts:
			for counter: String in ["policy_errors","invalid_outputs","engine_rejections"]:
				checks.append(assert_eq(host.owner.audit_snapshot().get(counter),0))
			host.owner.close_match()
		bridge.bind(null)
		bridge.free()
		gsm.prepare_for_disposal()
	return run_checks(checks)
