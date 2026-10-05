extends TestBase

const Fixtures = preload("res://tests/test_tournament_series59_additional_pokemon.gd")
const CSV10 = preload("res://scripts/effects/CSV10CEffects.gd")

func _tool(effect_id: String, owner: int = 0) -> CardInstance:
	var data := CardData.new()
	data.card_type = "Tool"
	data.name = "Tool " + effect_id
	data.effect_id = effect_id
	return CardInstance.create(data, owner)

func test_lost_vacuum_selects_fourth_tool_and_preserves_three_others() -> String:
	var gsm := Fixtures.new()._battle("CSV4C_088")
	var player := gsm.game_state.players[0]
	var slot := player.active_pokemon
	for i: int in 4:
		slot.attached_tools.append(_tool(str(i)))
	var selected := slot.get_attached_tools()[3]
	var cost := Fixtures.new()._energy("R")
	var vacuum := _tool("vacuum")
	player.hand.assign([vacuum, cost])
	var effect := EffectLostVacuum.new()
	var steps := effect.get_interaction_steps(vacuum, gsm.game_state)
	var checks: Array[String] = [assert_eq(steps[1].items.size(), 4)]
	effect.execute(vacuum, [{"discard_cards": [cost], "lost_vacuum_target": [selected]}], gsm.game_state)
	checks.append(assert_eq(slot.get_attached_tools().size(), 3))
	checks.append(assert_true(selected in player.lost_zone))
	gsm.prepare_for_disposal()
	return run_checks(checks)

func test_return_and_discard_effects_move_every_tool_once() -> String:
	var checks: Array[String] = []
	for mode: int in 2:
		var gsm := Fixtures.new()._battle("CSV4C_088")
		var player := gsm.game_state.players[0]
		var slot := player.active_pokemon
		player.active_pokemon = Fixtures.new()._slot("151C_084")
		player.bench.append(slot)
		var tools: Array = [_tool("one"), _tool("two"), _tool("three")]
		slot.attached_tools.assign(tools)
		if mode == 0:
			EffectProfTuro.new().execute(_tool("turo"), [{"prof_turo_target": [slot]}], gsm.game_state)
		else:
			AbilityBenchShuffleIntoDeck.new().execute_ability(slot, 0, [], gsm.game_state)
		for tool: CardInstance in tools:
			var destination := player.discard_pile if mode == 0 else player.deck
			checks.append(assert_eq(destination.count(tool), 1))
		checks.append(assert_true(slot.get_attached_tools().is_empty()))
		gsm.prepare_for_disposal()
	return run_checks(checks)

func test_scary_big_brother_discards_selected_one_of_four_tools() -> String:
	var gsm := Fixtures.new()._battle("151C_084")
	var state := gsm.game_state
	var defender := state.players[1].active_pokemon
	var tools: Array = [_tool("one", 1), _tool("two", 1), _tool("three", 1), _tool("four", 1)]
	defender.attached_tools.assign(tools)
	var trainer := _tool("trainer")
	var effect := CSV10.ScaryBigBrother.new()
	var followup := effect.get_followup_interaction_steps(trainer, state, {"opponent_pokemon": [defender]})
	var checks: Array[String] = [assert_eq(followup.size(), 1)]
	checks.append(assert_eq(followup[0].items.size(), 4))
	effect.execute(trainer, [{"opponent_pokemon": [defender], "opponent_tool": [tools[2]]}], state)
	checks.append(assert_eq(defender.get_attached_tools(), [tools[0], tools[1], tools[3]]))
	checks.append(assert_true(tools[2] in state.players[1].discard_pile))
	gsm.prepare_for_disposal()
	return run_checks(checks)

func test_survival_brace_discards_itself_when_it_is_not_first() -> String:
	var gsm := Fixtures.new()._battle("CSV4C_088")
	var state := gsm.game_state
	var defender := state.players[0].active_pokemon
	var first := _tool("other")
	var brace := _tool("1201698f44df09377c26288931d18b36")
	defender.attached_tools.assign([first, brace])
	defender.damage_counters = defender.get_max_hp()
	var checks: Array[String] = [assert_true(EffectSurvivalBrace.new().try_prevent_attack_knockout(defender, state.players[1].active_pokemon, state, 0, gsm.effect_processor))]
	checks.append(assert_eq(defender.get_attached_tools(), [first]))
	checks.append(assert_true(brace in state.players[0].discard_pile))
	gsm.prepare_for_disposal()
	return run_checks(checks)
