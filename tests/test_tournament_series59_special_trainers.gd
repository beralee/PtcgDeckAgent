extends TestBase

const Fixtures = preload("res://tests/test_30thdc_cards.gd")
const Registry = preload("res://scripts/engine/TournamentSeries59SpecialTrainerRegistry.gd")
var f := Fixtures.new()

func _card(uid: String, seat: int = 0) -> CardInstance:
	return CardInstance.create(CardData.from_dict(JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/%s.json" % uid))),seat)

func _slot(uid: String, seat: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(_card(uid, seat))
	return slot

func _battle() -> GameStateMachine:
	var gsm := f._battle("005")
	Registry.register_fixed(gsm.effect_processor)
	return gsm

func _drive(host: Dictionary, bridge: HeadlessMatchBridge, gsm: GameStateMachine, uid: String, selections: Array, checks: Array[String], kind: String = "play_trainer") -> int:
	var handles: Array = []
	var declared := false
	var choice := 0
	for tick: int in 100:
		host.owner.run_single_step(bridge,gsm)
		var checkpoint: Dictionary = host.port.pending_checkpoint()
		if bool(checkpoint.get("ok",false)):
			f._check_frame(checkpoint,checks,handles)
			var indexes: Array = []
			if not declared:
				for option: Dictionary in checkpoint.frame.options:
					if str(option.kind)==kind and (kind=="granted_attack" or str(option.get("card_uid",""))==uid):
						indexes=[option.index]
						break
				checks.append(assert_false(indexes.is_empty(),"Main action present: %s" % uid))
				if indexes.is_empty():
					break
				declared=true
			else:
				if choice>=selections.size():
					checks.append("Unexpected interaction window %s" % str(checkpoint.frame.select_semantics))
					break
				indexes=selections[choice]
				choice+=1
			checks.append(assert_true(bool(host.port.submit(str(checkpoint.window_handle), indexes).get("ok",false)),"Fresh indexes accepted %s" % [indexes]))
		elif declared and bridge._pending_choice=="":
			checks.append(assert_eq(choice,selections.size(),"All specified windows resolved"))
			return handles.size()
		elif host.owner.external_decision_failure_code()!="":
			checks.append("Host failed: %s" % host.owner.external_decision_failure_code())
			break
	checks.append("Full Host interaction did not finish for %s" % uid)
	return handles.size()

func _close(host: Dictionary, bridge: HeadlessMatchBridge, gsm: GameStateMachine, windows: int, checks: Array[String]) -> void:
	bridge.bind(null)
	bridge.free()
	f._close_host(host,gsm,windows,checks)


func test_real_special_trainer_cards_have_registered_effects() -> String:
	var processor := EffectProcessor.new()
	var checks: Array[String] = []
	for identity: Array in [["CSV1C", "119"], ["CSV8C", "174"], ["CSV9C", "197"], ["CSV4C", "120"], ["CSV3C", "120"], ["CSV9C", "179"], ["CSV1C","125"], ["CSV4C","122"]]:
		var data := CardDatabase.get_card(identity[0], identity[1])
		checks.append(assert_not_null(data, "real bundled printing %s" % str(identity)))
		if data != null:
			checks.append(assert_not_null(processor.get_effect(data.effect_id), "%s must be registered" % data.get_uid()))
	return run_checks(checks)


func test_giovanni_full_host_return_then_attach_and_partial_completion() -> String:
	# Same printing MEW161: https://asia.pokemon-card.com/hk-en/card-search/detail/10210/
	var checks: Array[String]=[]
	for attach: bool in [true,false]:
		var gsm:=_battle()
		var player:=gsm.game_state.players[0]
		var opponent:=gsm.game_state.players[1]
		var trainer:=_card("CSV1C_119")
		var returned:=f._energy("DAR",1)
		var attached:=f._energy("GRA")
		opponent.active_pokemon.attached_energy.assign([returned])
		player.hand.assign([trainer,attached] if attach else [trainer])
		var before:=player.active_pokemon.attached_energy.size()
		var host: Dictionary=f._host(gsm,0)
		var bridge:=HeadlessMatchBridge.new()
		bridge.bind(gsm)
		var windows:=_drive(host,bridge,gsm,"CSV1C_119",[[0],[0]] if attach else [[0]],checks)
		checks.append(assert_true(returned in opponent.hand))
		checks.append(assert_true(opponent.active_pokemon.attached_energy.is_empty()))
		checks.append(assert_eq(player.active_pokemon.attached_energy.size(),before+int(attach)))
		checks.append(assert_true(trainer in player.discard_pile))
		checks.append(assert_false(gsm.game_state.energy_attached_this_turn,"Effect attachment does not spend manual attachment"))
		_close(host,bridge,gsm,windows,checks)
	return run_checks(checks)


func test_giovanni_invalid_selection_and_missing_first_part_are_atomic() -> String:
	var checks: Array[String]=[]
	for mode: int in 3:
		var gsm:=_battle()
		var player:=gsm.game_state.players[0]
		var opponent:=gsm.game_state.players[1]
		var trainer:=_card("CSV1C_119")
		var returned:=f._energy("DAR",1)
		var attached:=f._energy("GRA")
		player.hand.assign([trainer,attached])
		if mode!=0: opponent.active_pokemon.attached_energy.assign([returned])
		var ctx: Dictionary={"giovanni_return_energy":[returned],"giovanni_attach_energy":[attached]}
		if mode==1: ctx.giovanni_return_energy=[attached]
		if mode==2: ctx.giovanni_attach_energy=[returned]
		checks.append(assert_false(gsm.play_trainer(0,trainer,[ctx])))
		checks.append(assert_eq(player.hand,[trainer,attached]))
		checks.append(assert_true(opponent.hand.is_empty()))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_ogre_mask_full_host_preserves_same_entity_and_all_attached_state() -> String:
	# https://asia.pokemon-card.com/sg/card-search/detail/12641/
	var gsm:=_battle()
	var state:=gsm.game_state
	var player:=state.players[0]
	var slot:=_slot("CSV8C_028")
	player.active_pokemon=slot
	var original:=slot.get_top_card()
	var replacement:=_card("CSV8C_067")
	var trainer:=_card("CSV8C_174")
	player.hand.assign([trainer])
	player.discard_pile.assign([replacement])
	slot.damage_counters=70
	slot.turn_played=1
	slot.turn_evolved=2
	slot.status_conditions.poisoned=true
	slot.mark_ability_used(state.turn_number)
	slot.effects.append({"type":"retreat_lock","expires_turn":5})
	var energy:=f._energy("GRA")
	var tool:=_card("CSV3C_120")
	slot.attached_energy.append(energy)
	slot.attached_tool=tool
	var host: Dictionary=f._host(gsm,0)
	var bridge:=HeadlessMatchBridge.new()
	bridge.bind(gsm)
	var checks: Array[String]=[]
	var windows:=_drive(host,bridge,gsm,"CSV8C_174",[[0],[0]],checks)
	checks.append(assert_eq(player.active_pokemon,slot))
	checks.append(assert_eq(slot.get_top_card(),replacement))
	checks.append(assert_true(original in player.discard_pile))
	checks.append(assert_eq(slot.damage_counters,70))
	checks.append(assert_eq(slot.turn_played,1))
	checks.append(assert_eq(slot.turn_evolved,2))
	checks.append(assert_true(slot.status_conditions.poisoned))
	checks.append(assert_true(slot.has_ability_used(state.turn_number)))
	checks.append(assert_eq(slot.attached_energy,[energy]))
	checks.append(assert_eq(slot.attached_tool,tool))
	checks.append(assert_eq(slot.effects.size(),2))
	_close(host,bridge,gsm,windows,checks)
	return run_checks(checks)


func test_drayton_full_host_two_categories_and_explicit_zero() -> String:
	# https://asia.pokemon-card.com/my/card-search/detail/17671/
	var checks: Array[String]=[]
	for choose: bool in [true,false]:
		var gsm:=_battle()
		var player:=gsm.game_state.players[0]
		var trainer:=_card("CSV9C_197")
		var pokemon:=_card("30thDC_002")
		var item:=_card("CSV8C_174")
		player.hand.assign([trainer])
		player.deck.assign([pokemon,item,f._energy(),f._energy(),f._energy(),f._energy(),f._energy(),_card("30thDC_004")])
		var host: Dictionary=f._host(gsm,0)
		var bridge:=HeadlessMatchBridge.new()
		bridge.bind(gsm)
		var windows:=_drive(host,bridge,gsm,"CSV9C_197",[[0],[0]] if choose else [[],[]],checks)
		checks.append(assert_eq(pokemon in player.hand,choose))
		checks.append(assert_eq(item in player.hand,choose))
		checks.append(assert_eq(player.hand.size(),2 if choose else 0))
		checks.append(assert_true(trainer in player.discard_pile))
		_close(host,bridge,gsm,windows,checks)
	return run_checks(checks)


func test_top_seven_rejects_eighth_and_wrong_category() -> String:
	var checks: Array[String]=[]
	for outside: bool in [true,false]:
		var gsm:=_battle()
		var player:=gsm.game_state.players[0]
		var trainer:=_card("CSV9C_197")
		player.hand.assign([trainer])
		var eighth:=_card("30thDC_002")
		player.deck.assign([f._energy(),f._energy(),f._energy(),f._energy(),f._energy(),f._energy(),f._energy(),eighth])
		var before:=player.deck.duplicate()
		checks.append(assert_false(gsm.play_trainer(0,trainer,[{"drayton_pokemon":[eighth if outside else player.deck[0]],"drayton_trainer":[]}])) )
		checks.append(assert_eq(player.deck,before))
		checks.append(assert_true(trainer in player.hand))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_deduction_full_host_orders_top_or_shuffles_only_three_to_bottom() -> String:
	var checks: Array[String]=[]
	for bottom: bool in [false,true]:
		var gsm:=_battle()
		var player:=gsm.game_state.players[0]
		var trainer:=_card("CSV9C_179")
		player.hand.assign([trainer])
		var looked: Array=[_card("30thDC_002"),_card("30thDC_004"),_card("30thDC_014")]
		player.deck.assign(looked+[f._energy("DAR"),f._energy("GRA")])
		var host: Dictionary=f._host(gsm,0)
		var remainder:=player.deck.slice(3)
		var bridge:=HeadlessMatchBridge.new()
		bridge.bind(gsm)
		var windows:=_drive(host,bridge,gsm,"CSV9C_179",[[2,0,1],[1]] if bottom else [[2,0,1],[0]],checks)
		if bottom:
			checks.append(assert_eq(player.deck.slice(0,remainder.size()),remainder,"Rest of deck unchanged"))
			for card: CardInstance in looked: checks.append(assert_true(card in player.deck.slice(-3)))
		else:
			checks.append(assert_eq(player.deck.slice(0,3),[looked[2],looked[0],looked[1]]))
			checks.append(assert_eq(player.deck.slice(3),remainder))
		checks.append(assert_true(trainer in player.discard_pile))
		_close(host,bridge,gsm,windows,checks)
	return run_checks(checks)


func test_miriam_full_host_returns_one_to_five_then_draws_and_requires_pokemon() -> String:
	# Official FAQ disallows no Pokemon, but allows an empty deck with a returnable Pokemon:
	# https://www.pokemon-card.com/rules/faq/search.php?freeword=%E3%83%9F%E3%83%A2%E3%82%B6&regulation_faq_main_item1=all
	var checks: Array[String]=[]
	var gsm:=_battle()
	var player:=gsm.game_state.players[0]
	var trainer:=_card("CSV1C_125")
	player.hand.assign([trainer])
	var returned:=_card("30thDC_002")
	player.discard_pile.assign([returned,f._energy()])
	var host: Dictionary=f._host(gsm,0)
	var bridge:=HeadlessMatchBridge.new()
	bridge.bind(gsm)
	var windows:=_drive(host,bridge,gsm,"CSV1C_125",[[0]],checks)
	checks.append(assert_eq(player.hand.size(),3))
	checks.append(assert_false(returned in player.discard_pile))
	checks.append(assert_true(trainer in player.discard_pile))
	_close(host,bridge,gsm,windows,checks)
	for mode: int in 3:
		gsm=_battle()
		player=gsm.game_state.players[0]
		trainer=_card("CSV1C_125")
		player.hand.assign([trainer])
		returned=_card("30thDC_002")
		if mode!=0: player.discard_pile.assign([returned])
		if mode==2: player.deck.clear()
		checks.append(assert_eq(gsm.play_trainer(0,trainer,[{"miriam_return":[returned] if mode!=1 else []}]),mode==2))
		if mode==2:
			checks.append(assert_eq(player.hand,[returned],"Draw as many as available after recovery"))
		else:
			checks.append(assert_eq(player.hand,[trainer]))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_rika_full_host_keeps_two_and_shuffles_only_unselected_to_bottom() -> String:
	# https://asia.pokemon-card.com/ph/card-search/detail/10849/
	var gsm:=_battle()
	var player:=gsm.game_state.players[0]
	var trainer:=_card("CSV4C_122")
	player.hand.assign([trainer])
	var looked: Array=[_card("30thDC_002"),_card("30thDC_004"),_card("30thDC_014"),_card("CSV8C_174")]
	player.deck.assign(looked+[f._energy("DAR"),f._energy("GRA")])
	var host: Dictionary=f._host(gsm,0)
	var remainder:=player.deck.slice(4)
	var bridge:=HeadlessMatchBridge.new()
	bridge.bind(gsm)
	var checks: Array[String]=[]
	var windows:=_drive(host,bridge,gsm,"CSV4C_122",[[1,3]],checks)
	checks.append(assert_eq(player.hand,[looked[1],looked[3]]))
	checks.append(assert_eq(player.deck.slice(0,remainder.size()),remainder))
	checks.append(assert_true(looked[0] in player.deck.slice(-2) and looked[2] in player.deck.slice(-2)))
	_close(host,bridge,gsm,windows,checks)
	for count: int in [1,2,3]:
		gsm=_battle()
		player=gsm.game_state.players[0]
		trainer=_card("CSV4C_122")
		player.hand.assign([trainer])
		player.deck.assign(looked.slice(0,count))
		checks.append(assert_true(gsm.play_trainer(0,trainer,[{"rika_pick":looked.slice(0,mini(count,2))}])))
		checks.append(assert_eq(player.hand.size(),mini(count,2)))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_blindside_full_host_targets_damaged_bench_and_discards_tool() -> String:
	var gsm:=_battle()
	var state:=gsm.game_state
	var attacker:=state.players[0].active_pokemon
	var tool:=_card("CSV4C_120")
	attacker.attached_tool=tool
	var target:=f._slot("024",1)
	target.get_card_data().hp=1000
	target.get_card_data().weakness_energy=attacker.get_card_data().energy_type
	target.get_card_data().weakness_value="×2"
	target.damage_counters=10
	state.players[1].bench.assign([target])
	var host: Dictionary=f._host(gsm,0)
	var bridge:=HeadlessMatchBridge.new()
	bridge.bind(gsm)
	var checks: Array[String]=[]
	var windows:=_drive(host,bridge,gsm,"CSV4C_120",[[0]],checks,"granted_attack")
	checks.append(assert_eq(target.damage_counters,110,"Bench damage ignores weakness"))
	checks.append(assert_eq(state.players[1].active_pokemon.damage_counters,0))
	checks.append(assert_true(tool in state.players[0].discard_pile,"TM discarded at own turn end"))
	checks.append(assert_eq(state.current_player_index,1))
	_close(host,bridge,gsm,windows,checks)
	return run_checks(checks)


func test_blindside_invalid_target_does_not_consume_confusion_and_active_weakness_applies() -> String:
	var checks: Array[String]=[]
	for valid: bool in [false,true]:
		var gsm:=_battle()
		var state:=gsm.game_state
		var attacker:=state.players[0].active_pokemon
		var defender:=state.players[1].active_pokemon
		attacker.attached_tool=_card("CSV4C_120")
		defender.damage_counters=10
		defender.get_card_data().weakness_energy=attacker.get_card_data().energy_type
		defender.get_card_data().weakness_value="×2"
		var coins:=Fixtures.FixedCoins.new()
		coins.results.assign([false])
		gsm.coin_flipper=coins
		attacker.status_conditions.confused=not valid
		var granted:=gsm.effect_processor.get_granted_attacks(attacker,state)[0]
		checks.append(assert_eq(gsm.use_granted_attack(0,attacker,granted,[{"tm_blindside_target":[defender if valid else attacker]}]),valid))
		checks.append(assert_eq(coins.calls,0,"Illegal targets rejected before confusion"))
		checks.append(assert_eq(attacker.damage_counters,0))
		checks.append(assert_eq(defender.damage_counters,210 if valid else 10))
		if not valid: checks.append(assert_eq(state.current_player_index,0))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_vengeful_punch_actual_attack_damage_knockout_and_suppression() -> String:
	# https://asia.pokemon-card.com/sg/card-search/detail/9138/
	var checks: Array[String]=[]
	for mode: int in 4:
		var gsm:=_battle()
		var state:=gsm.game_state
		var attacker:=state.players[0].active_pokemon
		var defender:=state.players[1].active_pokemon
		defender.get_card_data().hp=50 if mode!=1 else 1000
		defender.attached_tool=_card("CSV3C_120",1)
		state.players[1].bench.assign([f._slot("024",1)])
		if mode==2: defender.effects.append({"type":"ability_disabled","turn":state.turn_number})
		if mode==3:
			var stadium:=CardData.new()
			stadium.card_type="Stadium"
			stadium.effect_id="test_jamming"
			state.stadium_card=CardInstance.create(stadium,0)
			gsm.effect_processor.register_effect(stadium.effect_id,EffectJammingTower.new())
		checks.append(assert_true(gsm.use_attack(0,0)))
		checks.append(assert_eq(attacker.damage_counters,40 if mode in [0,2] else 0,"Only attack-damage KO and unsuppressed Tool retaliates"))
		if mode!=1: checks.append(assert_true(defender.get_top_card() in state.players[1].discard_pile))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_blindside_bench_protection_and_empty_target_attack() -> String:
	var checks: Array[String]=[]
	for mode: int in 3:
		var gsm:=_battle()
		var state:=gsm.game_state
		var attacker:=state.players[0].active_pokemon
		attacker.attached_tool=_card("CSV4C_120")
		var target:=_slot("CSV8C_028",1) if mode==0 else f._slot("024",1)
		target.get_card_data().hp=1000
		target.damage_counters=0 if mode==2 else 10
		state.players[1].bench.assign([target])
		if mode==1: state.players[1].bench.append(_slot("CS5bC_052",1))
		for pokemon: PokemonSlot in state.players[1].get_all_pokemon(): gsm.effect_processor.register_pokemon_card(pokemon.get_card_data())
		var grant:=gsm.effect_processor.get_granted_attacks(attacker,state)[0]
		checks.append(assert_true(gsm.use_granted_attack(0,attacker,grant,[] if mode==2 else [{"tm_blindside_target":[target]}])))
		checks.append(assert_eq(target.damage_counters,0 if mode==2 else 10,"Tera and Manaphy prevent bench attack damage; no target remains a legal attack"))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_vengeful_punch_does_not_react_to_damage_counter_knockout() -> String:
	var gsm:=_battle()
	var state:=gsm.game_state
	var attacker:=state.players[0].active_pokemon
	var defender:=state.players[1].active_pokemon
	defender.get_card_data().hp=50
	defender.attached_tool=_card("CSV3C_120",1)
	state.players[1].bench.assign([f._slot("024",1)])
	# A real effect-counter knockout goes through the same GSM settlement.
	attacker.get_card_data().attacks[0].damage=""
	var effect:=AttackPlaceDamageCountersOnOpponentActive.new(60)
	gsm.effect_processor.register_attack_effect(attacker.get_card_data().effect_id,effect)
	var checks: Array[String]=[assert_true(gsm.use_attack(0,0))]
	checks.append(assert_true(defender.get_top_card() in state.players[1].discard_pile))
	checks.append(assert_eq(attacker.damage_counters,0,"Counters are not attack damage"))
	gsm.prepare_for_disposal()
	return run_checks(checks)
