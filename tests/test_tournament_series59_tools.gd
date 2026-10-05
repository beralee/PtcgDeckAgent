extends TestBase

const Trainers := preload("res://tests/test_tournament_series59_trainers.gd")
const Fixture := preload("res://tests/test_30thdc_cards.gd")

func _rev_battle() -> GameStateMachine:
	var f := Fixture.new()
	var gsm := f._battle("005")
	var slot := gsm.game_state.players[0].active_pokemon
	slot.pokemon_stack.assign([CardInstance.create(Trainers.new()._card("CSV4C_088"), 0)])
	gsm.effect_processor.register_pokemon_card(slot.get_card_data())
	return gsm

func _put_tool(gsm: GameStateMachine, uid: String) -> CardInstance:
	var tool := CardInstance.create(Trainers.new()._card(uid), 0)
	gsm.game_state.players[0].hand.append(tool)
	gsm.attach_tool(0, tool, gsm.game_state.players[0].active_pokemon)
	return tool

func test_revavroom_allows_four_tools_and_effects_stack() -> String:
	var f := Trainers.new()
	var gsm := GameStateMachine.new()
	gsm.game_state = f._state()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	var state := gsm.game_state
	var slot := state.players[0].active_pokemon
	slot.pokemon_stack.assign([CardInstance.create(f._card("CSV4C_088"), 0)])
	var checks: Array[String] = []
	for index in 5:
		var data := CardData.new()
		data.name = "HP tool %d" % index
		data.card_type = "Tool"
		data.effect_id = "series59_test_hp_tool"
		var tool := CardInstance.create(data, 0)
		state.players[0].hand.append(tool)
		gsm.effect_processor.register_effect(data.effect_id, EffectToolHPModifier.new(30))
		checks.append(assert_eq(gsm.attach_tool(0, tool, slot), index < 4, "Exactly four tools allowed"))
	checks.append(assert_eq(slot.collect_all_cards().size(), 5, "Pokemon and all four tools remain accounted for"))
	checks.append(assert_eq(gsm.effect_processor.get_effective_max_hp(slot, state), 400, "All attached tool effects stack"))
	gsm.prepare_for_disposal()
	return run_checks(checks)

func test_each_powerglass_has_its_own_optional_end_turn_window() -> String:
	var gsm := _rev_battle()
	var f := Fixture.new()
	var state := gsm.game_state
	var slot := state.players[0].active_pokemon
	for i in 4: _put_tool(gsm, "CSV8C_188")
	for i in 4: state.players[0].discard_pile.append(f._energy("PSY"))
	var before := slot.attached_energy.size()
	gsm.player_choice_required.connect(func(_kind: String, _data: Dictionary): pass)
	gsm._advance_to_next_turn()
	var seen: Array = []
	var checks: Array[String] = []
	for i in 4:
		var pending := gsm.get_pending_decision_snapshot()
		checks.append(assert_eq(str(pending.get("kind", "")), "powerglass_end_turn", "Each tool gets a distinct window"))
		if pending.get("kind") != "powerglass_end_turn": break
		checks.append(assert_false(pending.card in seen, "Never reuses a resolved tool"))
		seen.append(pending.card)
		var energy: CardInstance = state.players[0].discard_pile[0]
		var selected: Array = [] if i == 1 else [energy]
		checks.append(assert_true(gsm.resolve_powerglass_end_turn_choice(0, [{"powerglass_energy": selected}]), "Accept current choice, including skip"))
	checks.append(assert_eq(seen.size(), 4))
	checks.append(assert_eq(slot.attached_energy.size(), before + 3, "Three accepted tools, one declined"))
	checks.append(assert_eq(state.current_player_index, 1, "End turn resumes after the fourth tool"))
	gsm.prepare_for_disposal()
	return run_checks(checks)

func test_knockout_owner_preserves_every_physical_tool() -> String:
	var gsm := _rev_battle()
	var slot := gsm.game_state.players[0].active_pokemon
	var tools: Array = []
	for i in 4: tools.append(_put_tool(gsm, "CSV7C_190"))
	# Exercise the normal knockout owner with all actual attached cards.
	var player := gsm.game_state.players[0]
	gsm._move_knocked_out_cards(slot, player)
	var checks: Array[String] = []
	for tool: CardInstance in tools: checks.append(assert_true(tool in player.discard_pile))
	checks.append(assert_eq(player.discard_pile.size(), slot.collect_all_cards().size()))
	gsm.prepare_for_disposal()
	return run_checks(checks)

func test_ability_suppression_requires_current_owner_to_choose_one_tool() -> String:
	var gsm := _rev_battle()
	var state := gsm.game_state
	var slot := state.players[0].active_pokemon
	var tools: Array = []
	for i in 4: tools.append(_put_tool(gsm, "CSV7C_190"))
	slot.effects.append({"type": "ability_disabled", "turn": state.turn_number})
	gsm.enforce_current_bench_limits("test_ability_suppression", 0)
	var pending := gsm.get_pending_decision_snapshot()
	var checks: Array[String] = [assert_eq(str(pending.get("kind", "")), "tool_limit_cleanup")]
	if pending.is_empty():
		gsm.prepare_for_disposal()
		return run_checks(checks)
	var key := str(pending.steps[0].id)
	checks.append(assert_false(gsm.resolve_tool_limit_cleanup(1, [{key: [tools[3]]}]), "Opponent cannot choose"))
	checks.append(assert_false(gsm.resolve_tool_limit_cleanup(0, [{key: [tools[0], tools[1]]}]), "Cannot keep two"))
	checks.append(assert_eq(slot.attached_tools.size(), 4, "Rejected input is atomic"))
	checks.append(assert_true(gsm.resolve_tool_limit_cleanup(0, [{key: [tools[3]]}]), "Owner can keep the fourth attached tool"))
	checks.append(assert_eq(slot.attached_tool, tools[3]))
	checks.append(assert_eq(slot.attached_tools.size(), 1))
	checks.append(assert_eq(state.players[0].discard_pile.size(), 3))
	checks.append(assert_false(gsm.resolve_tool_limit_cleanup(0, [{key: [tools[3]]}]), "Cannot replay a consumed choice"))
	gsm.prepare_for_disposal()
	return run_checks(checks)

func test_tool_jamming_suppresses_effects_without_disabling_tune_up() -> String:
	var gsm := _rev_battle()
	var state := gsm.game_state
	var slot := state.players[0].active_pokemon
	_put_tool(gsm, "CSV7C_187")
	for i in 3: _put_tool(gsm, "CSV7C_190")
	var checks: Array[String] = [assert_eq(gsm.effect_processor.get_effective_max_hp(slot, state), 380)]
	state.stadium_card = CardInstance.create(Trainers.new()._card("CSV8C_203"), 0)
	checks.append(assert_eq(gsm.effect_processor.get_effective_max_hp(slot, state), 280, "Jamming Tower disables every Tool"))
	checks.append(assert_eq(gsm.effect_processor.get_tool_limit(slot, state), 4, "Tune Up is a Pokemon Ability"))
	gsm.enforce_current_bench_limits("test_jamming", 0)
	checks.append(assert_true(gsm.get_pending_decision_snapshot().is_empty()))
	checks.append(assert_eq(slot.attached_tools.size(), 4, "Suppressed Tools remain attached"))
	gsm.prepare_for_disposal()
	return run_checks(checks)

func test_second_tool_grants_its_attack_and_expired_tm_only_discards_itself() -> String:
	var gsm := _rev_battle()
	var state := gsm.game_state
	var slot := state.players[0].active_pokemon
	var cloak := _put_tool(gsm, "CSV7C_187")
	var tm := _put_tool(gsm, "CSV4C_120")
	var target := Fixture.new()._slot("024", 1)
	target.damage_counters = 10
	state.players[1].bench.append(target)
	var attacks := gsm.effect_processor.get_granted_attacks(slot, state)
	var checks: Array[String] = [assert_eq(attacks.size(), 1)]
	if not attacks.is_empty():
		checks.append(assert_eq(attacks[0].source_card_instance_id, tm.instance_id))
		checks.append(assert_true(gsm.use_granted_attack(0, slot, attacks[0], [{"tm_blindside_target": [target]}])))
		checks.append(assert_eq(target.damage_counters, 110, "Real granted attack from the second tool"))
		checks.append(assert_true(tm in state.players[0].discard_pile, "TM discards at turn end"))
		checks.append(assert_eq(slot.attached_tools, [cloak], "Other tools remain"))
	gsm.prepare_for_disposal()
	return run_checks(checks)

func test_tool_cleanup_uses_real_host_fresh_select_window() -> String:
	var gsm := _rev_battle()
	var f := Fixture.new()
	var slot := gsm.game_state.players[0].active_pokemon
	var tools: Array = []
	for i in 4: tools.append(_put_tool(gsm, "CSV7C_190"))
	var host := f._host(gsm, 0)
	if not bool(host.get("ok", false)):
		gsm.prepare_for_disposal()
		return "Host creation failed"
	var bridge := HeadlessMatchBridge.new()
	bridge.bind(gsm)
	slot.effects.append({"type": "ability_disabled", "turn": gsm.game_state.turn_number})
	gsm.enforce_current_bench_limits("test_ability_suppression", 0)
	var checks: Array[String] = []
	var handles: Array = []
	var submitted := false
	for tick in 20:
		host.owner.run_single_step(bridge, gsm)
		var checkpoint: Dictionary = host.port.pending_checkpoint()
		if bool(checkpoint.get("ok", false)):
			f._check_frame(checkpoint, checks, handles)
			checks.append(assert_eq(checkpoint.frame.options.size(), 4, "Every attached physical tool is a legal choice"))
			checks.append(assert_true(host.port.submit(checkpoint.window_handle, [checkpoint.frame.options[3].index]).ok))
			submitted = true
		elif submitted and bridge._pending_choice == "": break
	checks.append(assert_true(submitted))
	checks.append(assert_eq(slot.attached_tools, [tools[3]], "Host submitted choice reaches the real cleanup owner"))
	checks.append(assert_true(gsm.get_pending_decision_snapshot().is_empty()))
	bridge.bind(null)
	bridge.free()
	f._close_host(host, gsm, 1, checks)
	return run_checks(checks)
