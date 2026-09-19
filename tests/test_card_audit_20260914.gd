extends "res://tests/helpers/BattleUIFeaturesShared.gd"

const FixtureRoot := "res://tests/fixtures/card_audit_20260914/"
const SlowkingStep := "csv9c_slowking_copied_attack"
const CounterStep := "alakazam_counter_redistribution"
const HostOwner := preload("res://scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorDevelopmentBattleOwner.gd")
const DecisionPort := preload("res://scripts/ai/ptcgdap/host/godot/A3ExternalDecisionPort.gd")


func test_alakazam_redistributes_existing_counters_and_confuses_through_player_ui() -> String:
	var previous_mode := GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER
	var scene := _make_battle_scene_stub()
	var gsm := _audit_gsm_with_card(_api_card("CSV9.5C_064.json"))
	var state := gsm.game_state
	var active := state.players[1].active_pokemon
	var bench := state.players[1].bench[0]
	active.damage_counters = 30
	bench.damage_counters = 20
	scene.set("_gsm", gsm)
	scene.set("_view_player", 0)
	scene.call("_try_use_attack_with_interaction", 0, state.players[0].active_pokemon, 0)
	scene.call("_on_counter_distribution_amount_chosen", 1)
	scene.call("_handle_counter_distribution_target", 0)
	scene.call("_on_counter_distribution_amount_chosen", 4)
	scene.call("_handle_counter_distribution_target", 1)
	var result := run_checks([
		assert_eq(active.damage_counters, 10), assert_eq(bench.damage_counters, 40),
		assert_true(active.status_conditions.confused), assert_eq(state.current_player_index, 1),
	])
	scene.free()
	GameManager.current_mode = previous_mode
	return result


func test_alakazam_zero_counters_and_declining_movement_still_confuse() -> String:
	var checks: Array[String] = []
	for count: int in [0, 30]:
		var gsm := _audit_gsm_with_card(_api_card("CSV9.5C_064.json"))
		var active := gsm.game_state.players[1].active_pokemon
		active.damage_counters = count
		checks.append(assert_true(gsm.use_attack(0, 0)))
		checks.append(assert_eq(active.damage_counters, count))
		checks.append(assert_true(active.status_conditions.confused))
	return run_checks(checks)


func test_alakazam_rejects_created_fractional_or_wrong_side_counters_before_status() -> String:
	var checks: Array[String] = []
	for kind: String in ["created", "fractional", "own", "stale", "empty"]:
		var gsm := _audit_gsm_with_card(_api_card("CSV9.5C_064.json"))
		var state := gsm.game_state
		var active := state.players[1].active_pokemon
		active.damage_counters = 20
		var target := state.players[1].bench[0]
		var amount := 20
		if kind == "created": amount = 30
		if kind == "fractional": amount = 15
		if kind == "own": target = state.players[0].active_pokemon
		if kind == "stale": state.players[1].bench.clear()
		var assignments: Array = [] if kind == "empty" else [{"target": target, "amount": amount}]
		checks.append(assert_false(gsm.use_attack(0, 0, [{CounterStep: assignments}]), kind))
		checks.append(assert_eq(active.damage_counters, 20))
		checks.append(assert_false(active.status_conditions.confused, "Invalid selection must not partly apply the attack"))
	return run_checks(checks)


func test_alakazam_effect_protection_keeps_protected_counters_and_damage_only_shields_do_not() -> String:
	var checks: Array[String] = []
	for ability: String in ["深度下潜", "毫不在意"]:
		var gsm := _audit_gsm_with_card(_api_card("CSV9.5C_064.json"))
		var state := gsm.game_state
		var active := state.players[1].active_pokemon
		var bench := state.players[1].bench[0]
		active.damage_counters = 30
		bench.damage_counters = 20
		bench.get_card_data().abilities = [{"name": ability, "text": ""}]
		var distribution: Array = [{"target": active, "amount": 30}]
		if ability == "毫不在意": distribution = [{"target": bench, "amount": 50}]
		checks.append(assert_true(gsm.use_attack(0, 0, [{CounterStep: distribution}])))
		checks.append(assert_eq(bench.damage_counters, 20 if ability == "深度下潜" else 50))
	return run_checks(checks)


func test_alakazam_psychic_counts_multi_energy_units_before_weakness_and_resistance() -> String:
	var checks: Array[String] = []
	for modifier: String in ["none", "weak", "resist"]:
		var gsm := _audit_gsm_with_card(_api_card("CSV9.5C_064.json"))
		var defender := gsm.game_state.players[1].active_pokemon
		var energy := _make_energy_cd("Double Turbo", "C")
		energy.card_type = "Special Energy"
		energy.effect_id = "9c04dd0addf56a7b2c88476bc8e45c0e"
		defender.attached_energy = [CardInstance.create(energy, 1)]
		if modifier == "weak":
			defender.get_card_data().weakness_energy = "P"
			defender.get_card_data().weakness_value = "×2"
		if modifier == "resist":
			defender.get_card_data().resistance_energy = "P"
			defender.get_card_data().resistance_value = "-30"
		checks.append(assert_true(gsm.use_attack(0, 1)))
		checks.append(assert_eq(defender.damage_counters, 220 if modifier == "weak" else (80 if modifier == "resist" else 110)))
	return run_checks(checks)


func test_wo_chien_prize_scaling_zero_through_five_and_forest_burn_is_independent() -> String:
	var checks: Array[String] = []
	for taken: int in 6:
		var gsm := _audit_gsm_with_card(_api_card("CSVL2C_013.json"))
		var opponent := gsm.game_state.players[1]
		opponent.prizes.resize(6 - taken)
		var target := opponent.bench[0]
		target.get_card_data().weakness_energy = "G"
		target.get_card_data().weakness_value = "×2"
		checks.append(assert_true(gsm.use_attack(0, 0, [{"bench_target": [target]}])))
		checks.append(assert_eq(target.damage_counters, taken * 60, "Bench damage ignores weakness"))
	var burn := _audit_gsm_with_card(_api_card("CSVL2C_013.json"))
	checks.append(assert_true(burn.use_attack(0, 1)))
	checks.append(assert_eq(burn.game_state.players[1].active_pokemon.damage_counters, 220))
	checks.append(assert_eq(burn.game_state.players[1].bench[0].damage_counters, 0))
	return run_checks(checks)


func test_wo_chien_rejects_invalid_targets_and_respects_bench_protection_and_no_bench() -> String:
	var checks: Array[String] = []
	for kind: String in ["own", "active", "stale", "protected", "none"]:
		var gsm := _audit_gsm_with_card(_api_card("CSVL2C_013.json"))
		var state := gsm.game_state
		state.players[1].prizes.resize(3)
		var target := state.players[1].bench[0]
		if kind == "own": target = state.players[0].bench[0]
		if kind == "active": target = state.players[1].active_pokemon
		if kind in ["stale", "none"]: state.players[1].bench.clear()
		if kind == "protected": target.get_card_data().abilities = [{"name": "毫不在意", "text": ""}]
		var used := gsm.use_attack(0, 0, [] if kind == "none" else [{"bench_target": [target]}])
		checks.append(assert_eq(used, kind in ["none", "protected"]))
		checks.append(assert_eq(target.damage_counters, 0))
	return run_checks(checks)


func test_wo_chien_bench_damage_applies_energy_and_target_reduction() -> String:
	var gsm := _audit_gsm_with_card(_api_card("CSVL2C_013.json"))
	var state := gsm.game_state
	state.players[1].prizes.resize(4)
	var energy := _make_energy_cd("Double Turbo", "C")
	energy.card_type = "Special Energy"
	energy.effect_id = "9c04dd0addf56a7b2c88476bc8e45c0e"
	state.players[0].active_pokemon.attached_energy.append(CardInstance.create(energy, 0))
	var target := state.players[1].bench[0]
	target.effects.append({"type": "reduce_damage_next_turn", "amount": 30, "turn": state.turn_number - 1})
	return run_checks([
		assert_true(gsm.use_attack(0, 0, [{"bench_target": [target]}])),
		assert_eq(target.damage_counters, 70, "120 minus Double Turbo 20 and defender reduction 30"),
		assert_eq(state.players[1].active_pokemon.damage_counters, 0),
	])


func test_effect_only_attacks_do_not_gain_active_damage_from_defiance_band() -> String:
	var checks: Array[String] = []
	for filename: String in ["CSV9.5C_064.json", "CSVL2C_013.json"]:
		var gsm := _audit_gsm_with_card(_api_card(filename))
		var state := gsm.game_state
		state.players[1].prizes.resize(4)
		var tool := CardData.new()
		tool.card_type = "Pokemon Tool"
		tool.effect_id = "e242d711feffd98f3fbb5c511d00d667"
		state.players[0].active_pokemon.attached_tool = CardInstance.create(tool, 0)
		checks.append(assert_true(gsm.use_attack(0, 0)))
		checks.append(assert_eq(state.players[1].active_pokemon.damage_counters, 0, "An effect-only attack cannot gain Active damage"))
	return run_checks(checks)


func test_three_real_cards_host_windows_rebind_and_finish_in_both_seats() -> String:
	var previous_mode := GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER
	var checks: Array[String] = []
	for kind: String in ["slowking", "alakazam", "wo_chien"]:
		for seat: int in 2:
			var gsm := _audit_gsm("CSV9C", "072") if kind == "slowking" else _audit_gsm_with_card(_api_card("CSV9.5C_064.json" if kind == "alakazam" else "CSVL2C_013.json"))
			var state := gsm.game_state
			if seat == 1:
				state.players.reverse()
				for pi: int in 2:
					var player := state.players[pi]
					player.player_index = pi
					for slot: PokemonSlot in player.get_all_pokemon():
						for card: CardInstance in slot.pokemon_stack + slot.attached_energy: card.owner_index = pi
					for card: CardInstance in player.deck + player.prizes: card.owner_index = pi
			state.current_player_index = seat
			state.first_player_index = 1 - seat
			var active := state.players[1 - seat].active_pokemon
			var bench := state.players[1 - seat].bench[0]
			if kind == "slowking": state.players[seat].deck.push_front(_copy_source("Host reveal", 50, seat))
			if kind == "alakazam": active.damage_counters = 20
			if kind == "wo_chien": state.players[1 - seat].prizes.resize(4)
			for player: PlayerState in state.players:
				var count := player.deck.size() + player.prizes.size()
				for slot: PokemonSlot in player.get_all_pokemon(): count += slot.pokemon_stack.size() + slot.attached_energy.size()
				for i: int in range(count, 60): player.deck.append(CardInstance.create(CardDatabase.get_card("CSVE1C", "GRA"), player.player_index))
			var port := DecisionPort.new()
			var created := HostOwner.create_external(gsm, seat, "audit-%s-%d" % [kind, seat], port)
			if not bool(created.get("ok", false)):
				GameManager.current_mode = previous_mode
				return "Host bind failed: %s" % created
			var owner: Variant = created.owner
			var scene := _make_battle_scene_stub()
			scene.set("_gsm", gsm)
			scene.set("_view_player", seat)
			scene.call("_try_use_attack_with_interaction", seat, state.players[seat].active_pokemon, 0)
			var accepted := 0
			var handles: Array[String] = []
			for attempt: int in 12:
				if str(scene.get("_pending_choice")) != "effect_interaction": break
				owner.get("_step_resolver").resolve_pending_step(scene, gsm, seat)
				var checkpoint := port.pending_checkpoint()
				if not bool(checkpoint.get("ok", false)): continue
				var handle := str(checkpoint.window_handle)
				checks.append(assert_false(handle in handles, "Every accepted selection needs a fresh window"))
				handles.append(handle)
				var pick := 1 if kind == "alakazam" else 0
				checks.append(assert_true(bool(port.submit(handle, [pick]).get("ok", false))))
				checks.append(assert_false(bool(port.submit(handle, [pick]).get("ok", false)), "Duplicate submission must fail"))
				owner.get("_step_resolver").resolve_pending_step(scene, gsm, seat)
				accepted += 1
			checks.append(assert_eq(accepted, 2 if kind == "alakazam" else 1, kind))
			checks.append(assert_eq(state.current_player_index, 1 - seat, kind))
			checks.append(assert_eq(active.damage_counters, 50 if kind == "slowking" else 0, kind))
			checks.append(assert_eq(bench.damage_counters, 20 if kind == "alakazam" else (120 if kind == "wo_chien" else 0), kind))
			var audit: Dictionary = owner.audit_snapshot()
			checks.append(assert_eq(audit.policy_successes, accepted))
			checks.append(assert_eq(audit.same_window_fallbacks, 0))
			owner.close_match()
			scene.free()
			gsm.prepare_for_disposal()
	GameManager.current_mode = previous_mode
	return run_checks(checks)


func test_slowking_player_selected_attack_completes_without_revealing_a_second_card() -> String:
	var gsm := _audit_gsm("CSV9C", "072")
	var state := gsm.game_state
	var attacker := state.players[0].active_pokemon
	var source := _copy_source("Selected source", 50, 0)
	var next := _copy_source("Must stay in deck", 90, 0)
	state.players[0].deck = [source, next]
	var option := {"source_card": source, "attack_index": 0, "attack": source.card_data.attacks[0]}
	var used := gsm.use_attack(0, 0, [{SlowkingStep: [option]}])
	return run_checks([
		assert_true(used, "Selected copied attack must finish after its source is discarded"),
		assert_eq(state.players[1].active_pokemon.damage_counters, 50),
		assert_eq(state.players[0].discard_pile, [source]),
		assert_eq(state.players[0].deck, [next], "Do not reveal another card from the same declaration"),
		assert_eq(state.current_player_index, 1, "A completed attack must end the turn"),
		assert_false(gsm.use_attack(0, 0), "The player cannot repeat the declaration in the same turn"),
		assert_false(state.shared_turn_flags.has("_csv9c_slowking_pending_copy_%d" % attacker.get_instance_id())),
	])


func test_slowking_copied_kyurem_finishes_target_selection_damage_and_energy_discard() -> String:
	var previous_mode := GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER
	var scene := _make_battle_scene_stub()
	var gsm := _audit_gsm("CSV9C", "072")
	var state := gsm.game_state
	var attacker := state.players[0].active_pokemon
	var kyurem := CardDatabase.get_card("CSV9C", "147")
	gsm.effect_processor.register_pokemon_card(kyurem)
	var source := CardInstance.create(kyurem, 0)
	var next := _copy_source("Next must remain", 200, 0)
	state.players[0].deck = [source, next]
	state.players[1].bench.append(_audit_slot(_make_pokemon_cd("Second Bench", 500, "C"), 1))
	var energies := attacker.attached_energy.duplicate()
	scene.set("_gsm", gsm)
	scene.set("_view_player", 0)
	scene.call("_try_use_attack_with_interaction", 0, attacker, 0)
	_emit_action_hud_mouse_click(_first_action_hud_option(scene))
	for index: int in 3: scene.call("_handle_field_slot_select_index", index)
	var checks: Array[String] = [
		assert_eq(state.current_player_index, 1), assert_eq(state.players[0].deck, [next]),
		assert_true(source in state.players[0].discard_pile), assert_true(attacker.attached_energy.is_empty()),
	]
	for energy: CardInstance in energies: checks.append(assert_true(energy in state.players[0].discard_pile))
	for slot: PokemonSlot in state.players[1].get_all_pokemon(): checks.append(assert_eq(slot.damage_counters, 110))
	scene.free()
	GameManager.current_mode = previous_mode
	return run_checks(checks)


func test_slowking_empty_deck_and_no_eligible_attack_whiff_without_extra_draw() -> String:
	var checks: Array[String] = []
	for kind: String in ["empty_deck", "no_attacks", "vstar_only"]:
		var gsm := _audit_gsm("CSV9C", "072")
		var state := gsm.game_state
		state.players[0].deck.clear()
		if kind != "empty_deck":
			var source := _copy_source("No eligible attack", 200, 0)
			if kind == "no_attacks": source.card_data.attacks.clear()
			else: source.card_data.attacks[0]["is_vstar_power"] = true
			state.players[0].deck = [source, _copy_source("Keep in deck", 90, 0)]
		checks.append(assert_true(gsm.use_attack(0, 0)))
		checks.append(assert_eq(state.players[1].active_pokemon.damage_counters, 0))
		checks.append(assert_eq(state.players[0].discard_pile.size(), 0 if kind == "empty_deck" else 1))
		checks.append(assert_eq(state.current_player_index, 1))
	return run_checks(checks)


func test_slowking_non_pokemon_and_rule_box_whiffs_discard_exactly_one_card() -> String:
	var checks: Array[String] = []
	for rule_box: bool in [false, true]:
		var gsm := _audit_gsm("CSV9C", "072")
		var state := gsm.game_state
		var first := _copy_source("Ineligible source", 200, 0)
		if rule_box:
			first.card_data.mechanic = "ex"
		else:
			first.card_data.card_type = "Item"
		var next := _copy_source("Do not copy this", 90, 0)
		state.players[0].deck = [first, next]
		checks.append(assert_true(gsm.use_attack(0, 0)))
		checks.append(assert_eq(state.players[0].discard_pile, [first], "Whiff must not mill twice"))
		checks.append(assert_eq(state.players[0].deck, [next]))
		checks.append(assert_eq(state.players[1].active_pokemon.damage_counters, 0))
	return run_checks(checks)


func test_slowking_stale_source_rejected_before_any_mutation() -> String:
	var gsm := _audit_gsm("CSV9C", "072")
	var state := gsm.game_state
	var stale := _copy_source("Already discarded", 50, 0)
	var top := _copy_source("Current top", 90, 0)
	state.players[0].discard_pile = [stale]
	state.players[0].deck = [top]
	var used := gsm.use_attack(0, 0, [{SlowkingStep: [{"source_card": stale, "attack_index": 0, "attack": stale.card_data.attacks[0]}]}])
	return run_checks([
		assert_false(used), assert_eq(state.players[0].deck, [top]),
		assert_eq(state.players[0].discard_pile, [stale]),
		assert_eq(state.players[1].active_pokemon.damage_counters, 0),
		assert_eq(state.current_player_index, 0),
	])


func test_slowking_real_action_hud_click_finishes_the_selected_attack() -> String:
	var previous_mode := GameManager.current_mode
	GameManager.current_mode = GameManager.GameMode.TWO_PLAYER
	var scene := _make_battle_scene_stub()
	var gsm := _audit_gsm("CSV9C", "072")
	var state := gsm.game_state
	var source := _copy_source("HUD source", 50, 0)
	var next := _copy_source("Next card", 90, 0)
	state.players[0].deck = [source, next]
	scene.set("_gsm", gsm)
	scene.set("_view_player", 0)
	scene.call("_try_use_attack_with_interaction", 0, state.players[0].active_pokemon, 0)
	var hud_option := _first_action_hud_option(scene)
	_emit_action_hud_mouse_click(hud_option)
	var result := run_checks([
		assert_not_null(hud_option),
		assert_eq(state.players[1].active_pokemon.damage_counters, 50),
		assert_eq(state.players[0].discard_pile, [source]),
		assert_eq(state.players[0].deck, [next]),
		assert_eq(state.current_player_index, 1, "One real HUD click must complete the attack"),
	])
	scene.free()
	GameManager.current_mode = previous_mode
	return result


func test_alakazam_exact_print_has_counter_movement_and_opponent_energy_scaling() -> String:
	var card := _api_card("CSV9.5C_064.json")
	var gsm := _audit_gsm_with_card(card)
	var state := gsm.game_state
	var attacker := state.players[0].active_pokemon
	state.players[1].active_pokemon.attached_energy = [CardInstance.create(_make_energy_cd("Grass", "G"), 1)]
	var first := gsm.effect_processor.get_attack_effects_for_slot(attacker, 0)
	var first_steps: Array = []
	state.players[1].active_pokemon.damage_counters = 20
	for fx: BaseEffect in first:
		first_steps.append_array(fx.get_attack_interaction_steps(attacker.get_top_card(), card.attacks[0], state))
	state.players[1].active_pokemon.damage_counters = 0
	var used := gsm.use_attack(0, 1)
	return run_checks([
		assert_eq(card.name, "胡地"),
		assert_false(first_steps.is_empty(), "Strange Hacking needs a real counter redistribution window"),
		assert_true(used),
		assert_eq(state.players[1].active_pokemon.damage_counters, 60, "Psychic must count opponent Grass Energy, not own Psychic Energy"),
	])


func test_wo_chien_exact_print_targets_bench_with_opponent_taken_prizes() -> String:
	var card := _api_card("CSVL2C_013.json")
	var gsm := _audit_gsm_with_card(card)
	var state := gsm.game_state
	state.players[1].prizes.resize(4)
	var attacker := state.players[0].active_pokemon
	var effects := gsm.effect_processor.get_attack_effects_for_slot(attacker, 0)
	var steps: Array = []
	for fx: BaseEffect in effects:
		steps.append_array(fx.get_attack_interaction_steps(attacker.get_top_card(), card.attacks[0], state))
	if steps.is_empty():
		return "Covetous Ivy has no registered Bench-target interaction"
	var target := state.players[1].bench[0]
	var step: Dictionary = steps[0]
	var used := gsm.use_attack(0, 0, [{str(step.id): [target]}])
	return run_checks([
		assert_eq(card.name, "古简蜗ex"), assert_true(used),
		assert_eq(target.damage_counters, 120),
		assert_eq(state.players[1].active_pokemon.damage_counters, 0),
	])


func _api_card(filename: String) -> CardData:
	return CardData.from_api_json(JSON.parse_string(FileAccess.get_file_as_string(FixtureRoot + filename)))


func _audit_gsm(set_code: String, index: String) -> GameStateMachine:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/%s_%s.json" % [set_code, index]))
	return _audit_gsm_with_card(CardData.from_dict(data))


func _audit_gsm_with_card(card: CardData) -> GameStateMachine:
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	var state := gsm.game_state
	state.current_player_index = 0
	state.first_player_index = 1
	state.turn_number = 2
	state.phase = GameState.GamePhase.MAIN
	for seat: int in 2:
		var player := PlayerState.new()
		player.player_index = seat
		player.active_pokemon = _audit_slot(_make_pokemon_cd("Active %d" % seat, 500, "C"), seat)
		player.active_pokemon.get_card_data().weakness_energy = ""
		player.bench = [_audit_slot(_make_pokemon_cd("Bench %d" % seat, 500, "C"), seat)]
		for i: int in 6:
			player.prizes.append(_copy_source("Prize %d" % i, 10, seat))
			player.deck.append(_copy_source("Draw %d" % i, 10, seat))
		state.players.append(player)
	state.players[0].active_pokemon = _audit_slot(card, 0)
	for type: String in ["P", "P", "G", "G", "G", "C"]:
		state.players[0].active_pokemon.attached_energy.append(CardInstance.create(_make_energy_cd("Energy", type), 0))
	gsm.effect_processor.register_pokemon_card(card)
	return gsm


func _audit_slot(card: CardData, seat: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack = [CardInstance.create(card, seat)]
	return slot


func _copy_source(label: String, damage: int, seat: int) -> CardInstance:
	var card := _make_pokemon_cd(label, 100, "C")
	card.abilities = []
	card.attacks = [{"name": "Copy hit", "cost": "CCCC", "damage": str(damage), "text": ""}]
	return CardInstance.create(card, seat)
