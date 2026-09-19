extends "res://tests/helpers/BattleUIFeaturesShared.gd"

const AuditFixture = preload("res://tests/test_card_audit_20260914.gd")
const HostOwner = preload("res://scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorDevelopmentBattleOwner.gd")
const DecisionPort = preload("res://scripts/ai/ptcgdap/host/godot/A3ExternalDecisionPort.gd")

func _gsm(tool: String = "gain", count: int = 2) -> GameStateMachine:
	var gsm: GameStateMachine = AuditFixture.new()._audit_gsm("CSV8C", "067")
	var state := gsm.game_state
	state.players[1].prizes.resize(5)
	var attacker := state.players[0].active_pokemon
	attacker.attached_energy.clear()
	for i: int in count:
		attacker.attached_energy.append(CardInstance.create(CardDatabase.get_card("CSVE1C", "WAT" if i == 0 else "GRA"), 0))
	if tool == "gain": attacker.attached_tool = CardInstance.create(CardDatabase.get_card("CSV9C", "190"), 0)
	if tool == "crystal": attacker.attached_tool = CardInstance.create(CardDatabase.get_card("CSV8C", "186"), 0)
	return gsm

func _pump(gsm: GameStateMachine) -> BaseEffect:
	return gsm.effect_processor.get_attack_effects_for_slot(gsm.game_state.players[0].active_pokemon, 1)[0]

func test_counter_gain_two_energy_finishes_return_and_bench_hit() -> String:
	var gsm := _gsm()
	var state := gsm.game_state
	var attacker := state.players[0].active_pokemon
	var energy := attacker.attached_energy.duplicate()
	var steps := _pump(gsm).get_attack_interaction_steps(attacker.get_top_card(), attacker.get_attacks()[1], state)
	var target := state.players[1].bench[0]
	var used := gsm.use_attack(0, 1, [{"return_energy_to_deck": energy, "bench_target": [target]}])
	return run_checks([assert_false(steps.is_empty()), assert_true(used),
		assert_eq(target.damage_counters, 120), assert_eq(state.players[1].active_pokemon.damage_counters, 100),
		assert_true(attacker.attached_energy.is_empty()), assert_eq(state.current_player_index, 1)])

func test_crystal_with_three_energy_cannot_return_only_two() -> String:
	var gsm := _gsm("crystal", 3)
	var state := gsm.game_state
	var attacker := state.players[0].active_pokemon
	var steps := _pump(gsm).get_attack_interaction_steps(attacker.get_top_card(), attacker.get_attacks()[1], state)
	var used := gsm.use_attack(0, 1, [{"return_energy_to_deck": attacker.attached_energy.slice(0, 2), "bench_target": [state.players[1].bench[0]]}])
	return run_checks([assert_eq(steps[0].min_select, 3), assert_false(used),
		assert_eq(attacker.attached_energy.size(), 3), assert_eq(state.players[1].active_pokemon.damage_counters, 0)])

func test_crystal_single_double_turbo_returns_one_card_and_preserves_damage_penalty() -> String:
	var gsm := _gsm("crystal", 0)
	var state := gsm.game_state
	var attacker := state.players[0].active_pokemon
	var cd := _make_energy_cd("Double Turbo", "C")
	cd.card_type = "Special Energy"
	cd.effect_id = "9c04dd0addf56a7b2c88476bc8e45c0e"
	var energy := CardInstance.create(cd, 0)
	attacker.attached_energy = [energy]
	var used := gsm.use_attack(0, 1, [{"return_energy_to_deck": [energy], "bench_target": [state.players[1].bench[0]]}])
	return run_checks([assert_true(used), assert_eq(state.players[1].active_pokemon.damage_counters, 80),
		assert_eq(state.players[1].bench[0].damage_counters, 100), assert_true(attacker.attached_energy.is_empty())])

func test_invalid_duplicate_and_stale_returns_do_not_partly_execute_attack() -> String:
	var checks: Array[String] = []
	for kind: String in ["duplicate", "stale", "short", "target"]:
		var gsm := _gsm()
		var state := gsm.game_state
		var attacker := state.players[0].active_pokemon
		var selected: Array = attacker.attached_energy.duplicate()
		var target := state.players[1].bench[0]
		if kind == "duplicate": selected = [selected[0], selected[0]]
		if kind == "stale": selected[1] = CardInstance.create(CardDatabase.get_card("CSVE1C", "GRA"), 0)
		if kind == "short": selected.resize(1)
		if kind == "target": target = state.players[0].bench[0]
		checks.append(assert_false(gsm.use_attack(0, 1, [{"return_energy_to_deck": selected, "bench_target": [target]}]), kind))
		checks.append(assert_eq(state.players[1].active_pokemon.damage_counters, 0))
		checks.append(assert_eq(attacker.attached_energy.size(), 2))
	return run_checks(checks)

func test_return_can_be_declined_but_attack_legality_still_applies() -> String:
	var checks: Array[String] = []
	for kind: String in ["decline", "tied", "tower", "no_water"]:
		var gsm := _gsm()
		var state := gsm.game_state
		if kind == "tied": state.players[0].prizes.resize(5)
		if kind == "tower":
			var tower := CardData.new()
			tower.effect_id = "4e16157bfa88a41e823d058a732df8e0"
			state.stadium_card = CardInstance.create(tower, 0)
		if kind == "no_water": state.players[0].active_pokemon.attached_energy[0] = CardInstance.create(CardDatabase.get_card("CSVE1C", "GRA"), 0)
		checks.append(assert_eq(gsm.use_attack(0, 1, [{"return_energy_to_deck": []}]), kind == "decline"))
		checks.append(assert_eq(state.players[1].bench[0].damage_counters, 0))
		checks.append(assert_eq(state.players[0].active_pokemon.attached_energy.size(), 2))
	return run_checks(checks)

func test_player_ui_resolves_return_then_bench_for_counter_gain() -> String:
	var previous := GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER
	var scene := _make_battle_scene_stub()
	var gsm := _gsm()
	scene.set("_gsm", gsm)
	scene.set("_view_player", 0)
	scene.call("_try_use_attack_with_interaction", 0, gsm.game_state.players[0].active_pokemon, 1)
	scene.call("_handle_effect_interaction_choice", PackedInt32Array([0, 1]))
	var field_mode := str(scene.get("_field_interaction_mode"))
	scene.call("_handle_field_slot_select_index", 0)
	var result := run_checks([assert_eq(field_mode, "slot_select"),
		assert_eq(gsm.game_state.players[1].bench[0].damage_counters, 120),
		assert_eq(gsm.game_state.current_player_index, 1),
		assert_true(gsm.game_state.players[0].active_pokemon.attached_energy.is_empty())])
	scene.free()
	gsm.prepare_for_disposal()
	GameManager.current_mode = previous
	return result

func test_three_of_four_basic_energy_return_and_protected_bench() -> String:
	var checks: Array[String] = []
	for protect: bool in [false, true]:
		var gsm := _gsm("crystal", 4)
		var state := gsm.game_state
		var attacker := state.players[0].active_pokemon
		var selected := attacker.attached_energy.slice(0, 3)
		var kept := attacker.attached_energy[3]
		var bench := state.players[1].bench[0]
		if protect: bench.get_card_data().abilities = [{"name": "毫不在意", "text": ""}]
		checks.append(assert_true(gsm.use_attack(0, 1, [{"return_energy_to_deck": selected, "bench_target": [bench]}])))
		checks.append(assert_eq(bench.damage_counters, 0 if protect else 120))
		checks.append(assert_eq(attacker.attached_energy, [kept]))
		for energy: CardInstance in selected: checks.append(assert_true(energy in state.players[0].deck))
	return run_checks(checks)

func test_no_attached_energy_cannot_trigger_bench_damage_when_attack_is_copied() -> String:
	var gsm := _gsm("none", 0)
	var state := gsm.game_state
	var attacker := state.players[0].active_pokemon
	var pump := _pump(gsm)
	var steps := pump.get_attack_interaction_steps(attacker.get_top_card(), attacker.get_attacks()[1], state)
	pump.set_attack_interaction_context([{"return_energy_to_deck": [], "bench_target": [state.players[1].bench[0]]}])
	pump.execute_attack(attacker, state.players[1].active_pokemon, 1, state)
	return run_checks([assert_true(steps.is_empty()), assert_eq(state.players[1].bench[0].damage_counters, 0)])

func test_current_host_energy_and_bench_windows_complete_in_both_seats() -> String:
	var previous := GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER
	var checks: Array[String] = []
	for kind: String in ["gain", "crystal", "multi"]:
		for seat: int in 2:
			var gsm := _gsm("none" if kind == "multi" else kind)
			var state := gsm.game_state
			if kind == "multi":
				var cd := _make_energy_cd("Double Turbo", "C")
				cd.card_type = "Special Energy"
				cd.effect_id = "9c04dd0addf56a7b2c88476bc8e45c0e"
				state.players[0].active_pokemon.attached_energy[1] = CardInstance.create(cd, 0)
			if seat == 1: state.players.reverse()
			state.current_player_index = seat
			state.first_player_index = 1 - seat
			for pi: int in 2:
				var player := state.players[pi]
				player.player_index = pi
				var count := player.deck.size() + player.prizes.size()
				for card: CardInstance in player.deck + player.prizes: card.owner_index = pi
				for slot: PokemonSlot in player.get_all_pokemon():
					count += slot.pokemon_stack.size() + slot.attached_energy.size()
					for card: CardInstance in slot.pokemon_stack + slot.attached_energy: card.owner_index = pi
					if slot.attached_tool != null:
						count += 1
						slot.attached_tool.owner_index = pi
				for i: int in range(count, 60): player.deck.append(CardInstance.create(CardDatabase.get_card("CSVE1C", "GRA"), pi))
			var port := DecisionPort.new()
			var created := HostOwner.create_external(gsm, seat, "wellspring-%s-%d" % [kind, seat], port)
			if not bool(created.get("ok", false)):
				GameManager.current_mode = previous
				return "Host bind failed: %s" % created
			var owner: Variant = created.owner
			var scene := _make_battle_scene_stub()
			scene.set("_gsm", gsm)
			scene.set("_view_player", seat)
			scene.call("_try_use_attack_with_interaction", seat, state.players[seat].active_pokemon, 1)
			var accepted := 0
			var handles: Array[String] = []
			for attempt: int in 10:
				if str(scene.get("_pending_choice")) != "effect_interaction": break
				owner.get("_step_resolver").resolve_pending_step(scene, gsm, seat)
				var checkpoint := port.pending_checkpoint()
				if not bool(checkpoint.get("ok", false)): continue
				var handle := str(checkpoint.window_handle)
				checks.append(assert_false(handle in handles))
				handles.append(handle)
				var minimum := int(checkpoint.frame.select_semantics.min_count)
				var selected: Array[int] = []
				for i: int in maxi(1, minimum): selected.append(i)
				checks.append(assert_true(bool(port.submit(handle, selected).get("ok", false))))
				checks.append(assert_false(bool(port.submit(handle, selected).get("ok", false))))
				owner.get("_step_resolver").resolve_pending_step(scene, gsm, seat)
				accepted += 1
			checks.append(assert_eq(accepted, 3 if kind == "multi" else 2, kind))
			checks.append(assert_eq(state.current_player_index, 1 - seat, kind))
			checks.append(assert_eq(state.players[1 - seat].bench[0].damage_counters, 100 if kind == "multi" else 120, kind))
			checks.append(assert_true(state.players[seat].active_pokemon.attached_energy.is_empty()))
			var audit: Dictionary = owner.audit_snapshot()
			checks.append(assert_eq(audit.policy_successes, accepted))
			checks.append(assert_eq(audit.same_window_fallbacks, 0))
			owner.close_match()
			scene.free()
			gsm.prepare_for_disposal()
	GameManager.current_mode = previous
	return run_checks(checks)
