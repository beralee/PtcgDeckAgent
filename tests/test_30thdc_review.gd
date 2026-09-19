extends TestBase

const Fixtures = preload("res://tests/test_30thdc_cards.gd")
var f := Fixtures.new()

class UiAttackHarness extends "res://scenes/battle/runtime/BattleSceneSetupEffectAiRuntime.gd":
	var refreshed := false
	func _refresh_ui_after_successful_action(_handover: bool = false, _player: int = -1, _kind: String = "") -> void:
		refreshed = true


func _drive(host: Dictionary, bridge: HeadlessMatchBridge, gsm: GameStateMachine, kind: String, index: String, attack_index: int, checks: Array[String], choose_empty: bool = false) -> int:
	var main_submitted := false
	var handles: Array = []
	for _tick: int in 80:
		host.owner.run_single_step(bridge, gsm)
		var checkpoint: Dictionary = host.port.pending_checkpoint()
		if bool(checkpoint.get("ok", false)):
			f._check_frame(checkpoint, checks, handles)
			var frame: Dictionary = checkpoint.frame
			var choices: Array = []
			if not main_submitted:
				for option: Dictionary in frame.options:
					if str(option.kind) == kind and ((kind == "attack" and int(option.attack_index) == attack_index) or (kind == "play_trainer" and str(option.card_uid) == "30thDC_%s" % index)):
						choices = [option.index]
						break
				checks.append(assert_false(choices.is_empty(), "Main exposes %s %s" % [kind, index]))
				if choices.is_empty():
					break
				main_submitted = true
			else:
				var minimum := int(frame.select_semantics.min_count)
				if not (choose_empty and minimum == 0):
					choices = [frame.options[0].index]
					# A single window may require two discard cards or allow two searches.
					for extra: int in range(1, minimum):
						choices.append(frame.options[extra].index)
			checks.append(assert_true(bool(host.port.submit(str(checkpoint.window_handle), choices).get("ok", false)), "Current full-flow window accepts %s" % [choices]))
		elif main_submitted and bridge._pending_choice == "":
			return handles.size()
		elif not bool(host.owner.external_decision_failure_code() == ""):
			checks.append("Host failure: %s" % host.owner.external_decision_failure_code())
			break
	checks.append("30thDC %s full main-to-resolution flow did not complete" % index)
	return handles.size()


func test_review_full_host_main_to_resolution_matrix() -> String:
	var checks: Array[String] = []
	for spec: Array in [["003",0],["006",0],["007",1],["010",0],["010",1],["016",0],["023",0],["027",0],["028",0],["029",0],["030",0],["031",0],["032",0],["033",0],["034",0],["035",0],["038",0],["039",0]]:
		var index: String = spec[0]
		var is_attack := int(index) <= 27
		var coins := Fixtures.FixedCoins.new()
		coins.results.assign([true,true,true,true])
		var gsm := f._battle(index if is_attack else "005", coins)
		var state := gsm.game_state
		var player := state.players[0]
		var opponent := state.players[1]
		player.bench.assign([f._slot("009")])
		player.bench[0].damage_counters = 100
		opponent.bench.assign([f._slot("009",1)])
		opponent.bench[0].get_card_data().hp = 1000
		opponent.active_pokemon.attached_energy.assign([f._energy("PSY",1), f._energy("DAR",1), f._energy("GRA",1)])
		player.deck.assign([CardInstance.create(f._card("002"),0),CardInstance.create(f._card("004"),0),CardInstance.create(f._card("014"),0),f._energy("GRA"),f._energy("DAR")])
		player.discard_pile.assign([f._energy("GRA"),f._energy("DAR")])
		var source: CardInstance = player.active_pokemon.get_top_card() if is_attack else CardInstance.create(f._card(index),0)
		player.hand.assign([f._energy("LIG"),f._energy("DAR"),f._energy("GRA")])
		if not is_attack:
			player.hand.append(source)
		var host: Dictionary = f._host(gsm,0)
		if not bool(host.get("ok",false)):
			gsm.prepare_for_disposal()
			return "Host creation failed for %s" % index
		var bridge := HeadlessMatchBridge.new()
		bridge.bind(gsm)
		var windows := _drive(host,bridge,gsm,"attack" if is_attack else "play_trainer",index,spec[1],checks)
		checks.append(assert_eq(bridge._pending_choice,"","Interaction completely resolved"))
		if is_attack:
			checks.append(assert_true(state.current_player_index != 0 or state.phase != GameState.GamePhase.MAIN,"Attack ended turn"))
		else:
			checks.append(assert_true(source in player.discard_pile,"Trainer executed"))
		if index == "023":
			checks.append(assert_true(opponent.active_pokemon.attached_energy.is_empty(),"Three follow-up Energy choices resolve"))
			checks.append(assert_eq(coins.calls,3))
		if index == "035":
			checks.append(assert_eq(player.active_pokemon.attached_energy.size(),9,"Waitress assignment committed"))
		print("30thDC review full flow %s attack=%d windows=%d" % [index,spec[1],windows])
		bridge.bind(null)
		bridge.free()
		f._close_host(host,gsm,windows,checks)
	return run_checks(checks)


func test_review_all_evolution_printings_real_engine_and_same_turn_rejection() -> String:
	var checks: Array[String] = []
	for pair: Array in [["002","003"],["004","005"],["008","009"],["012","013"],["025","014"],["026","017"],["019","020"],["021","022"],["022","023"]]:
		for same_turn: bool in [true,false]:
			var gsm := f._battle(pair[0])
			var state := gsm.game_state
			var slot := state.players[0].active_pokemon
			slot.turn_played = state.turn_number if same_turn else state.turn_number - 2
			slot.damage_counters = 20
			slot.status_conditions.poisoned = true
			var evolution := CardInstance.create(f._card(pair[1]),0)
			state.players[0].hand.assign([evolution])
			checks.append(assert_eq(gsm.evolve_pokemon(0,evolution,slot),not same_turn,"%s evolves only on a later turn" % pair[1]))
			checks.append(assert_eq(slot.damage_counters,20,"Evolution preserves damage"))
			checks.append(assert_eq(slot.get_top_card()==evolution,not same_turn))
			checks.append(assert_eq(slot.status_conditions.poisoned,same_turn,"Evolution clears status"))
			gsm.prepare_for_disposal()
	return run_checks(checks)


func test_review_triple_bite_confusion_fails_before_effect_coins_and_choices() -> String:
	var coins := Fixtures.FixedCoins.new()
	coins.results.assign([false,true,true,true])
	var gsm := f._battle("023",coins)
	gsm.coin_flipper = coins
	var state := gsm.game_state
	var attacker := state.players[0].active_pokemon
	attacker.status_conditions.confused = true
	var defender := state.players[1].active_pokemon
	defender.attached_energy.assign([f._energy("DAR",1)])
	var bridge := HeadlessMatchBridge.new()
	bridge.bind(gsm)
	var checks: Array[String] = [assert_true(bridge._try_use_attack_with_interaction(0,attacker,0))]
	checks.append(assert_eq(bridge._pending_choice,"","Confusion tails cannot reveal an effect choice"))
	checks.append(assert_eq(coins.calls,1,"Only the confusion coin is thrown"))
	checks.append(assert_eq(attacker.damage_counters,30))
	checks.append(assert_eq(defender.attached_energy.size(),1))
	bridge.bind(null)
	bridge.free()
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_review_confusion_ui_direct_and_successful_declaration_are_consistent() -> String:
	var checks: Array[String] = []
	for mode: String in ["ui_tails", "direct_tails", "heads"]:
		var coins := Fixtures.FixedCoins.new()
		coins.results.assign([mode == "heads",true,false,false])
		var gsm := f._battle("023",coins)
		gsm.coin_flipper = coins
		var state := gsm.game_state
		var attacker := state.players[0].active_pokemon
		attacker.status_conditions.confused = true
		var defender := state.players[1].active_pokemon
		var energy: CardInstance = f._energy("DAR",1)
		defender.attached_energy.assign([energy])
		if mode == "ui_tails":
			var ui := UiAttackHarness.new()
			ui._gsm = gsm
			ui._try_use_attack_with_interaction(0,attacker,0)
			checks.append(assert_true(ui.refreshed))
			checks.append(assert_eq(ui._pending_choice,""))
			ui._gsm = null
			ui.free()
		elif mode == "direct_tails":
			checks.append(assert_true(gsm.use_attack(0,0)))
		else:
			checks.append(assert_true(gsm.prepare_attack_interaction(0,attacker,0)))
			checks.append(assert_true(gsm.prepare_attack_interaction(0,attacker,0)))
			checks.append(assert_eq(coins.calls,1,"Declaration reconstruction does not repeat confusion"))
			var effect := gsm.effect_processor.get_attack_effects_for_slot(attacker,0)[0]
			effect.get_attack_interaction_steps(attacker.get_top_card(),attacker.get_card_data().attacks[0],state)
			checks.append(assert_eq(coins.calls,4,"Confusion followed by exactly three attack coins"))
			checks.append(assert_true(gsm.use_attack(0,0,[{"discard_opponent_active_energy":[energy]}])))
		checks.append(assert_eq(coins.calls,4 if mode == "heads" else 1))
		checks.append(assert_eq(defender.attached_energy.size(),0 if mode == "heads" else 1))
		checks.append(assert_eq(attacker.damage_counters,0 if mode == "heads" else 30))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func _double_energy(seat: int) -> CardInstance:
	return CardInstance.create(CardData.from_dict(JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/CSNC_024.json"))),seat)


func test_review_triple_bite_can_select_one_unit_from_each_multi_energy_card() -> String:
	# Official Crawdaunt Double Claws Q&A allows choosing two Double Colorless
	# cards for an effect that discards two Energy: one unit from each card.
	var checks: Array[String] = []
	for selection_count: int in [1,2,3]:
		var coins := Fixtures.FixedCoins.new()
		coins.results.assign([true,true,false])
		var gsm := f._battle("023",coins)
		var defender := gsm.game_state.players[1].active_pokemon
		defender.attached_energy.assign([_double_energy(1),_double_energy(1),f._energy("DAR",1)])
		var selected := defender.attached_energy.slice(0,selection_count)
		checks.append(assert_eq(gsm.use_attack(0,0,[{"discard_opponent_active_energy":selected}]),selection_count<=2,"Two heads allow one double or two physical cards"))
		checks.append(assert_eq(defender.attached_energy.size(),3-selection_count if selection_count<=2 else 3))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_review_triple_bite_host_can_continue_after_selecting_double_energy() -> String:
	var coins := Fixtures.FixedCoins.new()
	coins.results.assign([true,true,false])
	var gsm := f._battle("023",coins)
	var state := gsm.game_state
	var attacker := state.players[0].active_pokemon
	var defender := state.players[1].active_pokemon
	defender.attached_energy.assign([_double_energy(1),_double_energy(1)])
	var host: Dictionary = f._host(gsm,0)
	if not bool(host.get("ok",false)):
		gsm.prepare_for_disposal()
		return "Double Energy Host creation failed"
	var checks: Array[String] = []
	var handles: Array = []
	var effect := gsm.effect_processor.get_attack_effects_for_slot(attacker,0)[0]
	var attack := attacker.get_card_data().attacks[0]
	var context := {"pending_effect_card":attacker.get_top_card()}
	var step: Dictionary = effect.get_attack_interaction_steps(attacker.get_top_card(),attack,state)[0]
	var resolved := {str(step.id): f._pick(host,step,step.items,[0],context,checks,handles)}
	var followup := effect.get_followup_attack_interaction_steps(attacker.get_top_card(),attack,state,resolved)
	checks.append(assert_eq(followup.size(),1,"May choose to continue with a second physical card"))
	if followup.size()==1:
		step=followup[0]
		checks.append(assert_true(true in step.items and false in step.items,"Explicit finish/continue decision"))
		resolved[str(step.id)] = f._pick(host,step,step.items,[step.items.find(true)],context,checks,handles)
		followup=effect.get_followup_attack_interaction_steps(attacker.get_top_card(),attack,state,resolved)
		checks.append(assert_eq(followup.size(),1))
		if followup.size()==1:
			step=followup[0]
			checks.append(assert_eq(step.items.size(),1,"First physical card excluded"))
			resolved[str(step.id)] = f._pick(host,step,step.items,[0],context,checks,handles)
			checks.append(assert_true(gsm.use_attack(0,0,[resolved])))
			checks.append(assert_true(defender.attached_energy.is_empty()))
	f._close_host(host,gsm,3,checks)
	return run_checks(checks)


func test_review_invalid_target_does_not_consume_confusion_coin() -> String:
	var coins := Fixtures.FixedCoins.new()
	coins.results.assign([false])
	var gsm := f._battle("027",coins)
	gsm.coin_flipper = coins
	var attacker := gsm.game_state.players[0].active_pokemon
	attacker.status_conditions.confused = true
	var checks: Array[String] = [assert_false(gsm.use_attack(0,0,[{"any_target":[attacker]}]))]
	checks.append(assert_eq(coins.calls,0,"Invalid target rejected before declaring attack"))
	checks.append(assert_eq(attacker.damage_counters,0))
	checks.append(assert_eq(gsm.game_state.current_player_index,0))
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_review_search_without_matches_still_allows_viewing_full_deck() -> String:
	var checks: Array[String] = []
	for index: String in ["003","006"]:
		var gsm := f._battle(index)
		var state := gsm.game_state
		var player := state.players[0]
		player.deck.assign([CardInstance.create(f._card("014"),0),CardInstance.create(f._card("020"),0)])
		var attacker := player.active_pokemon
		var effect := gsm.effect_processor.get_attack_effects_for_slot(attacker,0)[0]
		var attack := attacker.get_card_data().attacks[0]
		var steps := effect.get_attack_interaction_steps(attacker.get_top_card(),attack,state)
		checks.append(assert_eq(steps.size(),1,"%s exposes empty-search confirmation" % index))
		if steps.size()==1:
			var context := {str(steps[0].id):[BaseEffect.EMPTY_SEARCH_VIEW_DECK]}
			var followup := effect.get_followup_attack_interaction_steps(attacker.get_top_card(),attack,state,context)
			checks.append(assert_eq(followup.size(),1))
			if followup.size()==1:
				checks.append(assert_eq(followup[0].get("source_card_items",followup[0].get("items",[])),player.deck,"All own deck contents visible to player"))
		checks.append(assert_true(gsm.use_attack(0,0)))
		checks.append(assert_eq(player.deck.size(),2))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_review_confusion_heads_cannot_cancel_committed_target_selection() -> String:
	var coins := Fixtures.FixedCoins.new()
	coins.results.assign([true])
	var gsm := f._battle("027",coins)
	gsm.coin_flipper=coins
	var attacker := gsm.game_state.players[0].active_pokemon
	attacker.status_conditions.confused=true
	var bridge := HeadlessMatchBridge.new()
	bridge.bind(gsm)
	var checks: Array[String]=[assert_true(bridge._try_use_attack_with_interaction(0,attacker,0))]
	checks.append(assert_eq(coins.calls,1))
	checks.append(assert_eq(bridge._pending_effect_steps.size(),1))
	if bridge._pending_effect_steps.size()==1:
		checks.append(assert_false(bool(bridge._pending_effect_steps[0].get("allow_cancel",true)),"Cannot return to main after confusion passed"))
	bridge.bind(null)
	bridge.free()
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_review_explicit_zero_search_through_full_host_never_autoselects() -> String:
	var checks: Array[String] = []
	for index: String in ["003","006"]:
		var gsm := f._battle(index)
		var player := gsm.game_state.players[0]
		player.deck.append(CardInstance.create(f._card("002"),0))
		player.bench.assign([f._slot("009")])
		var host: Dictionary=f._host(gsm,0)
		if not bool(host.get("ok",false)):
			gsm.prepare_for_disposal()
			return "Optional search Host unavailable"
		var bridge:=HeadlessMatchBridge.new()
		bridge.bind(gsm)
		var deck_count:=player.deck.size()
		var windows:=_drive(host,bridge,gsm,"attack",index,0,checks,true)
		checks.append(assert_eq(player.deck.size(),deck_count))
		checks.append(assert_eq(player.bench.size(),1))
		checks.append(assert_true(player.bench[0].attached_energy.is_empty()))
		bridge.bind(null)
		bridge.free()
		f._close_host(host,gsm,windows,checks)
	return run_checks(checks)


func test_review_coin_trainer_tails_resolve_without_target_windows() -> String:
	var checks: Array[String]=[]
	for index: String in ["029","033"]:
		var coins:=Fixtures.FixedCoins.new()
		coins.results.assign([false])
		var gsm:=f._battle("005",coins)
		var player:=gsm.game_state.players[0]
		var opponent:=gsm.game_state.players[1]
		var original:=opponent.active_pokemon
		opponent.active_pokemon.attached_energy.append(f._energy("DAR",1))
		opponent.bench.assign([f._slot("009",1)])
		var trainer:=CardInstance.create(f._card(index),0)
		player.hand.assign([trainer])
		var host: Dictionary=f._host(gsm,0)
		if not bool(host.get("ok",false)):
			gsm.prepare_for_disposal()
			return "Coin trainer Host unavailable"
		var bridge:=HeadlessMatchBridge.new()
		bridge.bind(gsm)
		var windows:=_drive(host,bridge,gsm,"play_trainer",index,0,checks)
		checks.append(assert_eq(windows,1,"Only the main declaration is selected on tails"))
		checks.append(assert_eq(coins.calls,1,"No preview/retry coin consumption"))
		checks.append(assert_true(trainer in player.discard_pile))
		checks.append(assert_eq(opponent.active_pokemon,original))
		checks.append(assert_eq(original.attached_energy.size(),1))
		bridge.bind(null)
		bridge.free()
		f._close_host(host,gsm,windows,checks)
	return run_checks(checks)


func test_review_waitress_missing_duplicate_and_wrong_owner_assignment_are_atomic() -> String:
	var checks: Array[String]=[]
	for mode: int in 3:
		var gsm:=f._battle("005")
		var state:=gsm.game_state
		var player:=state.players[0]
		var trainer:=CardInstance.create(f._card("035"),0)
		player.hand.assign([trainer])
		var assignment: Dictionary={"source":player.deck[0],"target":player.active_pokemon}
		var selected: Array=[]
		if mode==1:
			selected=[assignment,assignment]
		elif mode==2:
			assignment.target=state.players[1].active_pokemon
			selected=[assignment]
		var deck_before:=player.deck.duplicate()
		checks.append(assert_false(gsm.play_trainer(0,trainer,[{"waitress_energy_assignment":selected}])))
		checks.append(assert_true(trainer in player.hand))
		checks.append(assert_eq(player.deck,deck_before))
		checks.append(assert_true(player.discard_pile.is_empty()))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_review_zoroark_retreat_discount_reaches_actual_payment() -> String:
	var gsm:=f._battle("024")
	var state:=gsm.game_state
	var player:=state.players[0]
	var aura: PokemonSlot=f._slot("020")
	var target: PokemonSlot=f._slot("009")
	player.bench.assign([aura,target])
	player.active_pokemon.attached_energy.clear()
	gsm.effect_processor.register_pokemon_card(aura.get_card_data())
	var payment: Array[CardInstance]=[]
	var checks: Array[String]=[assert_true(gsm.retreat(0,payment,target),"Two-cost retreat becomes free through benched Night Path")]
	checks.append(assert_eq(player.active_pokemon,target))
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_review_triple_bite_and_murkrow_respect_mist_energy_protection() -> String:
	var checks: Array[String]=[]
	for index: String in ["023","018"]:
		var coins:=Fixtures.FixedCoins.new()
		coins.results.assign([true,false,false])
		var gsm:=f._battle(index,coins)
		var state:=gsm.game_state
		var defender:=state.players[1].active_pokemon
		var mist:=CardInstance.create(CardData.from_dict(JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/CSV7C_204.json"))),1)
		defender.attached_energy.assign([mist])
		var targets: Array=[{"discard_opponent_active_energy":[mist]}] if index=="023" else []
		checks.append(assert_true(gsm.use_attack(0,0,targets)))
		checks.append(assert_eq(defender.attached_energy,[mist]))
		checks.append(assert_false(defender.effects.any(func(e: Dictionary)->bool:return e.get("type")=="retreat_lock")))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_review_comeback_ignores_stale_wrong_owner_and_current_turn_knockouts() -> String:
	var checks: Array[String]=[]
	for key: String in ["attack_damage_knockout_names:0:2","attack_damage_knockout_names:1:3","attack_damage_knockout_names:0:4"]:
		var gsm:=f._battle("001")
		gsm.game_state.shared_turn_flags[key]=["Other knockout"]
		checks.append(assert_true(gsm.use_attack(0,0)))
		checks.append(assert_eq(gsm.game_state.players[1].active_pokemon.damage_counters,30))
		gsm.prepare_for_disposal()
	return run_checks(checks)
