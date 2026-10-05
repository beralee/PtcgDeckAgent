extends TestBase

const ToolsFixture := preload("res://tests/test_tournament_series59_tools.gd")
const Fixture := preload("res://tests/test_30thdc_cards.gd")
const Cards := preload("res://tests/test_tournament_series59_trainers.gd")

func _real_slot(uid: String, owner: int, gsm: GameStateMachine) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(Cards.new()._card(uid), owner))
	gsm.effect_processor.register_pokemon_card(slot.get_card_data())
	return slot

func test_retreat_into_iron_thorns_immediately_requests_cleanup() -> String:
	var tf := ToolsFixture.new()
	var gsm := tf._rev_battle()
	var state := gsm.game_state
	var rev := state.players[0].active_pokemon
	var keep: CardInstance
	for i in 4: keep = tf._put_tool(gsm, "CSV7C_190")
	var thorns := _real_slot("CSV7C_091", 0, gsm)
	state.players[0].bench.append(thorns)
	gsm.player_choice_required.connect(func(_kind: String, _data: Dictionary): pass)
	var paid: Array[CardInstance] = [rev.attached_energy[0]]
	var checks: Array[String] = [assert_true(gsm.retreat(0, paid, thorns))]
	var pending := gsm.get_pending_decision_snapshot()
	checks.append(assert_eq(str(pending.get("kind", "")), "tool_limit_cleanup", "Manual retreat must settle newly suppressed Tune Up"))
	if pending.get("kind") == "tool_limit_cleanup":
		checks.append(assert_true(gsm.resolve_tool_limit_cleanup(0, [{str(pending.steps[0].id): [keep]}])))
	checks.append(assert_eq(rev.attached_tools, [keep]))
	checks.append(assert_eq(state.current_player_index, 0))
	checks.append(assert_eq(state.phase, GameState.GamePhase.MAIN))
	gsm.prepare_for_disposal()
	return run_checks(checks)

func test_real_ability_and_attack_switching_wait_for_tool_cleanup() -> String:
	var checks: Array[String] = []
	for use_ability: bool in [true, false]:
		var tf := ToolsFixture.new()
		var gsm := tf._rev_battle()
		var state := gsm.game_state
		var rev := state.players[0].active_pokemon
		var keep: CardInstance
		for i in 4: keep = tf._put_tool(gsm, "CSV7C_190")
		var thorns := _real_slot("CSV7C_091", 1, gsm)
		state.players[1].bench.append(thorns)
		gsm.player_choice_required.connect(func(_kind: String, _data: Dictionary): pass)
		if use_ability:
			var gust := _real_slot("CSV6C_042", 0, gsm)
			state.players[0].bench.append(gust)
			checks.append(assert_true(gsm.use_ability(0, gust, 0, [{"opponent_bench_target": [thorns]}])))
		else:
			state.players[0].bench.append(rev)
			var attacker := _real_slot("CSV2C_011", 0, gsm)
			attacker.attached_energy.assign([Fixture.new()._energy(), Fixture.new()._energy()])
			state.players[0].active_pokemon = attacker
			checks.append(assert_true(gsm.use_attack(0, 1, [{"opponent_switch_target": [thorns]}])))
		checks.append(assert_eq(state.players[1].active_pokemon, thorns))
		var pending := gsm.get_pending_decision_snapshot()
		checks.append(assert_eq(str(pending.get("kind", "")), "tool_limit_cleanup"))
		checks.append(assert_eq(state.current_player_index, 0, "The action waits for Tune Up cleanup"))
		if pending.get("kind") == "tool_limit_cleanup":
			checks.append(assert_true(gsm.resolve_tool_limit_cleanup(0, [{str(pending.steps[0].id): [keep]}])))
		checks.append(assert_eq(rev.attached_tools, [keep]))
		checks.append(assert_eq(state.current_player_index, 0 if use_ability else 1, "Resume the original ability/attack continuation"))
		gsm.prepare_for_disposal()
	return run_checks(checks)

func test_tool_cleanup_defers_continuation_until_existing_bench_overflow_resolves() -> String:
	# Owner-state fixture at a mandatory dual-cleanup boundary. No policy may
	# advance the stored attack continuation between these two decisions.
	var tf := ToolsFixture.new()
	var gsm := tf._rev_battle()
	var state := gsm.game_state
	var rev := state.players[0].active_pokemon
	var keep: CardInstance
	for i in 4: keep = tf._put_tool(gsm, "CSV7C_190")
	for i in 6: state.players[0].bench.append(Fixture.new()._slot("005"))
	rev.effects.append({"type": "ability_disabled", "turn": state.turn_number})
	var bench_prompts: Array[Dictionary] = []
	gsm.player_choice_required.connect(func(kind: String, data: Dictionary):
		if kind == "bench_limit_cleanup": bench_prompts.append(data))
	gsm._after_attack(0)
	var pending := gsm.get_pending_decision_snapshot()
	var checks: Array[String] = [assert_eq(str(pending.get("kind", "")), "tool_limit_cleanup")]
	if pending.get("kind") == "tool_limit_cleanup":
		checks.append(assert_true(gsm.resolve_tool_limit_cleanup(0, [{str(pending.steps[0].id): [keep]}])))
	checks.append(assert_eq(state.current_player_index, 0, "Bench decision cannot be overtaken by next turn"))
	checks.append(assert_eq(bench_prompts.size(), 1))
	if not bench_prompts.is_empty():
		var step: Dictionary = bench_prompts[0].steps[0]
		checks.append(assert_true(gsm.enforce_current_bench_limits("bench_limit_cleanup", 0, "", -1, [{str(step.id): [step.items[0]]}])) )
	checks.append(assert_eq(state.players[0].bench.size(), 5))
	checks.append(assert_eq(state.current_player_index, 1))
	checks.append(assert_eq(state.turn_number, 5, "Attack resumes exactly once"))
	gsm.prepare_for_disposal()
	return run_checks(checks)

func test_powerglass_invalid_energy_does_not_consume_tool_or_window() -> String:
	var tf := ToolsFixture.new()
	var gsm := tf._rev_battle()
	var state := gsm.game_state
	var tool := tf._put_tool(gsm, "CSV8C_188")
	var energy := Fixture.new()._energy()
	state.players[0].discard_pile.append(energy)
	gsm.player_choice_required.connect(func(_kind: String, _data: Dictionary): pass)
	gsm._advance_to_next_turn()
	var checks: Array[String] = []
	checks.append(assert_false(gsm.resolve_powerglass_end_turn_choice(0, [{"powerglass_energy": [Fixture.new()._energy()]}]), "Stale energy cannot consume an optional effect"))
	checks.append(assert_eq(gsm.get_pending_decision_snapshot().get("card"), tool))
	checks.append(assert_eq(state.current_player_index, 0))
	checks.append(assert_true(gsm.resolve_powerglass_end_turn_choice(0, [{"powerglass_energy": [energy]}])))
	checks.append(assert_true(energy in state.players[0].active_pokemon.attached_energy))
	checks.append(assert_eq(state.current_player_index, 1))
	gsm.prepare_for_disposal()
	return run_checks(checks)

func test_replacement_suppression_waits_for_tools_before_next_turn() -> String:
	var tf := ToolsFixture.new()
	var gsm := tf._rev_battle()
	var state := gsm.game_state
	var slot := state.players[0].active_pokemon
	var attached: Array = []
	for i in 4: attached.append(tf._put_tool(gsm, "CSV7C_190"))
	var replacement := _real_slot("CSV7C_091", 1, gsm)
	state.players[1].active_pokemon = null
	state.players[1].bench.append(replacement)
	state.phase = GameState.GamePhase.KNOCKOUT_REPLACE
	gsm.player_choice_required.connect(func(_kind: String, _data: Dictionary): pass)
	var checks: Array[String] = [assert_true(gsm.send_out_pokemon(1, replacement))]
	var pending := gsm.get_pending_decision_snapshot()
	checks.append(assert_eq(str(pending.get("kind", "")), "tool_limit_cleanup"))
	checks.append(assert_eq(state.current_player_index, 0, "Promotion's suppression must resolve before turn advances"))
	checks.append(assert_eq(state.turn_number, 4, "No start-turn draw before mandatory cleanup"))
	if pending.get("kind") == "tool_limit_cleanup":
		checks.append(assert_true(gsm.resolve_tool_limit_cleanup(0, [{str(pending.steps[0].id): [attached[2]]}])))
	checks.append(assert_eq(slot.attached_tools, [attached[2]]))
	checks.append(assert_eq(state.current_player_index, 1, "Resume replacement exactly once after cleanup"))
	checks.append(assert_eq(state.turn_number, 5))
	gsm.prepare_for_disposal()
	return run_checks(checks)

func test_powerglass_real_host_preserves_every_successive_prompt() -> String:
	var tf := ToolsFixture.new()
	var f := Fixture.new()
	var gsm := tf._rev_battle()
	var state := gsm.game_state
	var slot := state.players[0].active_pokemon
	for i in 4: tf._put_tool(gsm, "CSV8C_188")
	for i in 4: state.players[0].discard_pile.append(f._energy())
	var before := slot.attached_energy.size()
	var host := f._host(gsm, 0)
	if not bool(host.get("ok", false)):
		gsm.prepare_for_disposal()
		return "Host creation failed"
	var bridge := HeadlessMatchBridge.new()
	bridge.bind(gsm)
	gsm._advance_to_next_turn()
	var checks: Array[String] = []
	var handles: Array = []
	var choices := 0
	for tick in 40:
		host.owner.run_single_step(bridge, gsm)
		var checkpoint: Dictionary = host.port.pending_checkpoint()
		if bool(checkpoint.get("ok", false)):
			f._check_frame(checkpoint, checks, handles)
			var selected: Array = [] if choices == 1 else [checkpoint.frame.options[0].index]
			checks.append(assert_true(host.port.submit(checkpoint.window_handle, selected).ok))
			choices += 1
		elif state.current_player_index == 1: break
	checks.append(assert_eq(choices, 4, "Reobserve a fresh optional window for each physical Powerglass"))
	checks.append(assert_eq(slot.attached_energy.size(), before + 3))
	checks.append(assert_eq(state.current_player_index, 1))
	checks.append(assert_eq(bridge._pending_choice, ""))
	bridge.bind(null)
	bridge.free()
	f._close_host(host, gsm, 4, checks)
	return run_checks(checks)

func test_real_cologne_cleanup_then_hp_knockout_keeps_prize_prompt() -> String:
	var tf := ToolsFixture.new()
	var f := Fixture.new()
	var gsm := tf._rev_battle()
	var state := gsm.game_state
	var slot := state.players[0].active_pokemon
	tf._put_tool(gsm, "CSV7C_187")
	for i in 3: tf._put_tool(gsm, "CSV7C_190")
	slot.damage_counters = 300
	state.players[0].bench.append(f._slot("005", 0))
	state.current_player_index = 1
	var cologne := CardInstance.create(Cards.new()._card("CS5aC_113"), 1)
	state.players[1].hand.append(cologne)
	var host := f._host(gsm, 0)
	if not bool(host.get("ok", false)):
		gsm.prepare_for_disposal()
		return "Host creation failed"
	var bridge := HeadlessMatchBridge.new()
	bridge.bind(gsm)
	var checks: Array[String] = [assert_true(gsm.play_trainer(1, cologne, []))]
	checks.append(assert_eq(state.players[0].active_pokemon, slot, "No KO before owner chooses which Tool to keep"))
	checks.append(assert_eq(state.players[1].prizes.size(), 6))
	var handles: Array = []
	var choices := 0
	for tick in 15:
		host.owner.run_single_step(bridge, gsm)
		var checkpoint: Dictionary = host.port.pending_checkpoint()
		if bool(checkpoint.get("ok", false)):
			f._check_frame(checkpoint, checks, handles)
			checks.append(assert_true(host.port.submit(checkpoint.window_handle, [checkpoint.frame.options[3].index]).ok))
			choices += 1
		elif choices > 0: break
	checks.append(assert_eq(choices, 1))
	checks.append(assert_eq(state.players[0].active_pokemon, null, "Discarding the HP Tool now causes KO"))
	checks.append(assert_eq(bridge._pending_choice, "take_prize", "Synchronous KO/prize prompt survives cleanup commit"))
	checks.append(assert_eq(int(bridge._dialog_data.get("player", -1)), 1))
	checks.append(assert_eq(state.current_player_index, 1, "Trainer's turn remains current"))
	bridge.bind(null)
	bridge.free()
	f._close_host(host, gsm, 1, checks)
	return run_checks(checks)
