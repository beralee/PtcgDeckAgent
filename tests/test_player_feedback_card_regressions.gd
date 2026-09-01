class_name TestPlayerFeedbackCardRegressions
extends TestBase

const WELLS_PRING_EFFECT_ID := "14cf8080c35f652fe13a579f1b50542a"
const NOIVERN_EX_EFFECT_ID := "7f21a88085207d28e38ca3593994edc2"
const REGIDRAGO_VSTAR_EFFECT_ID := "749d2f12d33057c8cc20e52c1b11bcbf"
const GENOME_HACKING_MEW_EFFECT_ID := "49669fcf461deacebeb5755c11ec51f1"
const ARVENS_GREEDENT_EFFECT_ID := "bd60c6a39ca30046d3e3610e1bbf7595"
const HOPS_CRAMORANT_EFFECT_ID := "a250d62a3355b00d48f2eaa8be6a5dfb"
const ZAMAZENTA_POWER_SLAM_EFFECT_ID := "08e4abe39ce058b6724cf68c1e9828e4"
const ANNIHILAPE_SELF_LOCK_EFFECT_ID := "69ce58aa80cbc0551b2764da9c3b5735"
const YANMEGA_EFFECT_ID := "88367894eb8e5dc6ae6b2b8350eb75f9"
const FEZANDIPITI_EFFECT_ID := "ab6c3357e2b8a8385a68da738f41e0c1"
const FESTIVAL_GROUNDS_EFFECT_ID := "357d55b54ded5db071b55ebe165749fc"
const RESCUE_BOARD_EFFECT_ID := "0b4cc131a19862f92acf71494f29a0ed"
const GameStateClonerScript = preload("res://scripts/ai/GameStateCloner.gd")
const ScenarioStateSnapshotScript = preload("res://scripts/engine/scenario/ScenarioStateSnapshot.gd")
const ScenarioStateRestorerScript = preload("res://scripts/engine/scenario/ScenarioStateRestorer.gd")
const BattleReplayStateRestorerScript = preload("res://scripts/engine/BattleReplayStateRestorer.gd")
const CardDatabaseScript = preload("res://scripts/autoload/CardDatabase.gd")
const HeadlessMatchBridgeScript = preload("res://scripts/ai/HeadlessMatchBridge.gd")


func test_wellspring_attacks_keep_retreat_lock_scoped_to_sob_defender() -> String:
	var card := _load_card("res://data/bundled_user/cards/CSV8C_067.json")
	if card == null:
		return "CSV8C_067 should load"
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(card)
	var state := _make_state()
	var attacker := _slot(card, 0)
	var defender := state.players[1].active_pokemon
	state.players[0].active_pokemon = attacker

	var first_effects := processor.get_attack_effects_for_slot(attacker, 0)
	var second_effects := processor.get_attack_effects_for_slot(attacker, 1)
	processor.execute_attack_effect(attacker, 0, defender, state)
	var first_locked_defender := _has_retreat_lock(defender)
	var first_locked_attacker := _has_retreat_lock(attacker)
	defender.effects.clear()
	attacker.effects.clear()
	processor.execute_attack_effect(attacker, 1, defender, state)

	return run_checks([
		assert_eq(card.effect_id, WELLS_PRING_EFFECT_ID, "CSV8C_067 should retain the audited effect identity"),
		assert_eq(first_effects.size(), 1, "Sob should own exactly one attack effect"),
		assert_eq(second_effects.size(), 1, "Torrential Pump should own exactly one independent attack effect"),
		assert_true(first_locked_defender, "Sob should lock only the Defending Pokemon"),
		assert_false(first_locked_attacker, "Sob must never bind the retreat lock to Wellspring Ogerpon itself"),
		assert_false(_has_retreat_lock(defender), "Torrential Pump must not inherit Sob's retreat lock"),
		assert_false(_has_retreat_lock(attacker), "Torrential Pump must not place a retreat lock on its user"),
	])


func test_regidrago_copied_hidden_flight_protects_the_actual_copying_pokemon() -> String:
	var regidrago := _load_card("res://data/bundled_user/cards/CS6.5C_055.json")
	var noivern := _load_card("res://data/bundled_user/cards/CSVL1C_045.json")
	if regidrago == null or noivern == null:
		return "Regidrago VSTAR and Noivern ex bundled cards should load"
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	_add_dummy_prizes(state)
	var regidrago_slot := _slot(regidrago, 0)
	state.players[0].active_pokemon = regidrago_slot
	state.players[0].discard_pile = [CardInstance.create(noivern, 0)]
	state.players[0].deck = [_dummy_card("Own next draw", 0)]
	state.players[1].deck = [_dummy_card("Opponent next draw", 1)]
	regidrago_slot.attached_energy = [
		_energy("Grass A", "G", 0),
		_energy("Grass B", "G", 0),
		_energy("Fire", "R", 0),
	]
	gsm.effect_processor.register_pokemon_card(regidrago)
	gsm.effect_processor.register_pokemon_card(noivern)

	var effects := gsm.effect_processor.get_attack_effects_for_slot(regidrago_slot, 0)
	var steps: Array[Dictionary] = effects[0].get_attack_interaction_steps(
		regidrago_slot.get_top_card(),
		regidrago.attacks[0],
		state
	) if not effects.is_empty() else []
	var hidden_flight_option: Dictionary = {}
	if not steps.is_empty():
		for option: Variant in steps[0].get("items", []):
			if option is Dictionary and int(option.get("attack_index", -1)) == 0:
				var source_card: Variant = option.get("source_card", null)
				if source_card is CardInstance and source_card.card_data != null and source_card.card_data.effect_id == NOIVERN_EX_EFFECT_ID:
					hidden_flight_option = option
					break
	var copied_attack_used := gsm.use_attack(0, 0, [{"copied_attack": [hidden_flight_option]}])

	var basic_attacker := _slot(_pokemon("Basic attacker", 200), 1)
	state.players[1].active_pokemon = basic_attacker
	var basic_attack_reason := gsm.get_attack_unusable_reason(1, 0)
	var basic_attack_used := gsm.use_attack(1, 0)

	return run_checks([
		assert_eq(regidrago.effect_id, REGIDRAGO_VSTAR_EFFECT_ID, "Regidrago VSTAR should retain its copied-attack effect identity"),
		assert_false(hidden_flight_option.is_empty(), "Apex Dragon should expose Noivern ex's first attack as a copy option"),
		assert_true(copied_attack_used, "Regidrago VSTAR should copy Hidden Flight through the real attack path"),
		assert_true(basic_attack_used, "The opposing Basic Pokemon should still be allowed to attack (reason=%s)" % basic_attack_reason),
		assert_eq(regidrago_slot.damage_counters, 0, "Copied Hidden Flight should prevent Basic Pokemon attack damage to Regidrago VSTAR"),
	])


func test_old_mew_ex_genome_hacking_copies_torrential_pump_bench_damage_end_to_end() -> String:
	var mew := _load_card("res://data/bundled_user/cards/151C_151.json")
	var wellspring := _load_card("res://data/bundled_user/cards/CSV8C_067.json")
	if mew == null or wellspring == null:
		return "151C_151 Mew ex and Wellspring Mask Ogerpon ex bundled cards should load"
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	_add_dummy_prizes(state)
	var mew_slot := _slot(mew, 0)
	var wellspring_slot := _slot(wellspring, 0)
	var bench_target := _slot(_pokemon("Bench target", 200), 1)
	state.players[0].active_pokemon = mew_slot
	state.players[0].bench = []
	state.players[1].active_pokemon = wellspring_slot
	state.players[1].bench = [bench_target]
	state.players[0].deck = [_dummy_card("Own next draw", 0)]
	state.players[1].deck = [_dummy_card("Opponent next draw", 1)]
	var water := _energy("Water", "W", 0)
	var colorless_a := _energy("Colorless A", "C", 0)
	var colorless_b := _energy("Colorless B", "C", 0)
	mew_slot.attached_energy = [water, colorless_a, colorless_b]
	gsm.effect_processor.register_pokemon_card(mew)
	gsm.effect_processor.register_pokemon_card(wellspring)

	var bridge := HeadlessMatchBridgeScript.new()
	bridge.bind(gsm)
	var interaction_started := bridge._try_use_attack_with_interaction(0, mew_slot, 0)
	var initial_steps: Array = bridge.get("_pending_effect_steps")
	var initial_step: Dictionary = initial_steps[0] if not initial_steps.is_empty() else {}
	var torrential_pump_option_index := -1
	var copied_attack_items: Array = initial_step.get("items", [])
	for option_index: int in copied_attack_items.size():
		var option: Variant = copied_attack_items[option_index]
		if (
			option is Dictionary
			and str(option.get("source_effect_id", "")) == WELLS_PRING_EFFECT_ID
			and int(option.get("attack_index", -1)) == 1
		):
			torrential_pump_option_index = option_index
			break
	if torrential_pump_option_index >= 0:
		bridge._handle_effect_interaction_choice(PackedInt32Array([torrential_pump_option_index]))
	var energy_steps: Array = bridge.get("_pending_effect_steps")
	var energy_step_index := int(bridge.get("_pending_effect_step_index"))
	var energy_step: Dictionary = energy_steps[energy_step_index] if energy_step_index >= 0 and energy_step_index < energy_steps.size() else {}
	bridge._handle_effect_interaction_choice(PackedInt32Array([0, 1, 2]))
	var current_steps: Array = bridge.get("_pending_effect_steps")
	var step_index := int(bridge.get("_pending_effect_step_index"))
	var followup_step: Dictionary = current_steps[step_index] if step_index >= 0 and step_index < current_steps.size() else {}
	if str(followup_step.get("id", "")) == "bench_target":
		bridge._handle_effect_interaction_choice(PackedInt32Array([0]))
	var interaction_finished := str(bridge.get("_pending_effect_kind")) == ""

	return run_checks([
		assert_eq(mew.effect_id, GENOME_HACKING_MEW_EFFECT_ID, "151C_151 Mew ex should retain its Genome Hacking effect identity"),
		assert_true(interaction_started, "The real Headless/UI interaction path should start Genome Hacking"),
		assert_eq(str(initial_step.get("id", "")), "copied_attack", "Genome Hacking should first ask which opposing Active attack to copy"),
		assert_true(torrential_pump_option_index >= 0, "Genome Hacking should expose Wellspring Mask Ogerpon ex's second attack"),
		assert_eq(str(energy_step.get("id", "")), "return_energy_to_deck", "Copied Torrential Pump should ask Mew to return Energy"),
		assert_eq(str(followup_step.get("id", "")), "bench_target", "Copied Torrential Pump should dynamically expose its follow-up Bench target"),
		assert_true(interaction_finished, "The copied attack interaction should finish after selecting the Bench target"),
		assert_eq(wellspring_slot.damage_counters, 100, "Copied Torrential Pump should deal 100 damage to Wellspring Mask Ogerpon ex"),
		assert_eq(bench_target.damage_counters, 120, "Copied Torrential Pump should deal 120 damage to the chosen Benched Pokemon"),
		assert_eq(mew_slot.attached_energy.size(), 0, "Copied Torrential Pump should return the three selected Energy"),
	])


func test_old_mew_ex_copy_forwards_before_damage_tool_discard() -> String:
	var mew := _load_card("res://data/bundled_user/cards/151C_151.json")
	var greedent := _load_card("res://data/bundled_user/cards/CSV10C_182.json")
	if mew == null or greedent == null:
		return "151C_151 Mew ex and CSV10C_182 Arven's Greedent should load"
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	_add_dummy_prizes(state)
	var mew_slot := _slot(mew, 0)
	var greedent_slot := _slot(greedent, 1)
	state.players[0].active_pokemon = mew_slot
	state.players[1].active_pokemon = greedent_slot
	state.players[0].deck = [_dummy_card("Own draw", 0)]
	state.players[1].deck = [_dummy_card("Opponent draw", 1)]
	mew_slot.attached_energy = [_energy("C1", "C", 0), _energy("C2", "C", 0), _energy("C3", "C", 0)]
	var tool_data := CardData.new()
	tool_data.name = "Defender Tool"
	tool_data.card_type = "Tool"
	var defender_tool := CardInstance.create(tool_data, 1)
	greedent_slot.attached_tool = defender_tool
	gsm.effect_processor.register_pokemon_card(mew)
	gsm.effect_processor.register_pokemon_card(greedent)

	var used := gsm.use_attack(0, 0, [_copied_attack_context(greedent, 0)])

	return run_checks([
		assert_eq(greedent.effect_id, ARVENS_GREEDENT_EFFECT_ID, "Greedent should retain the audited before-damage effect identity"),
		assert_true(used, "Genome Hacking should resolve the copied Greedent attack"),
		assert_eq(greedent_slot.attached_tool, null, "The copied attack must discard the Defending Pokemon's Tool before damage"),
		assert_true(defender_tool in state.players[1].discard_pile, "The discarded Tool should enter its owner's discard pile"),
		assert_eq(greedent_slot.damage_counters, 10, "The copied attack should still deal its printed damage"),
	])


func test_old_mew_ex_copy_forwards_damage_cancellation() -> String:
	var mew := _load_card("res://data/bundled_user/cards/151C_151.json")
	var cramorant := _load_card("res://data/bundled_user/cards/CSV10C_188.json")
	if mew == null or cramorant == null:
		return "151C_151 Mew ex and CSV10C_188 Hop's Cramorant should load"
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	_add_dummy_prizes(state, 6)
	var mew_slot := _slot(mew, 0)
	var defender := _slot(cramorant, 1)
	state.players[0].active_pokemon = mew_slot
	state.players[1].active_pokemon = defender
	state.players[0].deck = [_dummy_card("Own draw", 0)]
	state.players[1].deck = [_dummy_card("Opponent draw", 1)]
	mew_slot.attached_energy = [_energy("C1", "C", 0), _energy("C2", "C", 0), _energy("C3", "C", 0)]
	gsm.effect_processor.register_pokemon_card(mew)
	gsm.effect_processor.register_pokemon_card(cramorant)

	var used := gsm.use_attack(0, 0, [_copied_attack_context(cramorant, 0)])

	return run_checks([
		assert_eq(cramorant.effect_id, HOPS_CRAMORANT_EFFECT_ID, "Cramorant should retain the audited attack-failure effect identity"),
		assert_true(used, "A legally declared copied attack still resolves even when its damage is cancelled"),
		assert_eq(defender.damage_counters, 0, "Genome Hacking must inherit the copied attack's prize-count failure condition"),
	])


func test_old_mew_ex_copy_forwards_source_validation_before_mutation() -> String:
	var mew := _load_card("res://data/bundled_user/cards/151C_151.json")
	var source := _load_card("res://data/bundled_user/cards/CSV10C_099.json")
	if mew == null or source == null:
		return "151C_151 Mew ex and CSV10C_099 should load"
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	_add_dummy_prizes(state)
	var mew_slot := _slot(mew, 0)
	var source_slot := _slot(source, 1)
	var original_bench := state.players[1].bench.duplicate()
	state.players[0].active_pokemon = mew_slot
	state.players[1].active_pokemon = source_slot
	mew_slot.attached_energy = [_energy("C1", "C", 0), _energy("C2", "C", 0), _energy("C3", "C", 0)]
	gsm.effect_processor.register_pokemon_card(mew)
	gsm.effect_processor.register_pokemon_card(source)

	var used := gsm.use_attack(0, 0, [_copied_attack_context(source, 0)])

	return run_checks([
		assert_false(used, "A copied attack with a mandatory target must reject a missing delegated interaction"),
		assert_eq(state.players[1].active_pokemon, source_slot, "Validation must fail before the copied switch effect mutates the board"),
		assert_eq(state.players[1].bench, original_bench, "Validation failure must preserve the opponent Bench"),
		assert_true(gsm.effect_processor.get_last_interaction_validation_error(state).contains("force_out_target"), "The source validation error should identify the missing copied step"),
	])


func test_old_mew_ex_rejects_forged_copy_source_context() -> String:
	var mew := _load_card("res://data/bundled_user/cards/151C_151.json")
	var forged_source := _load_card("res://data/bundled_user/cards/CSV10C_182.json")
	if mew == null or forged_source == null:
		return "151C_151 Mew ex and CSV10C_182 should load"
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	_add_dummy_prizes(state)
	var mew_slot := _slot(mew, 0)
	var actual_defender := _slot(_pokemon("Actual opposing Active", 200), 1)
	state.players[0].active_pokemon = mew_slot
	state.players[1].active_pokemon = actual_defender
	mew_slot.attached_energy = [_energy("C1", "C", 0), _energy("C2", "C", 0), _energy("C3", "C", 0)]
	gsm.effect_processor.register_pokemon_card(mew)
	gsm.effect_processor.register_pokemon_card(forged_source)

	var used := gsm.use_attack(0, 0, [_copied_attack_context(forged_source, 0)])

	return run_checks([
		assert_false(used, "Genome Hacking must reject a source that is not the opposing Active Pokemon"),
		assert_eq(actual_defender.damage_counters, 0, "A forged copied-attack context must not deal damage"),
		assert_eq(gsm.effect_processor.get_last_interaction_validation_error(state), "copied attack source is invalid", "The validation error should identify invalid source provenance"),
	])


func test_old_mew_ex_copied_delayed_reactive_attack_keeps_source_identity() -> String:
	var mew := _load_card("res://data/bundled_user/cards/151C_151.json")
	var zamazenta := _load_card("res://data/bundled_user/cards/CSV10C_162.json")
	if mew == null or zamazenta == null:
		return "151C_151 Mew ex and CSV10C_162 Zamazenta should load"
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	_add_dummy_prizes(state)
	var mew_slot := _slot(mew, 0)
	var zamazenta_slot := _slot(zamazenta, 1)
	state.players[0].active_pokemon = mew_slot
	state.players[1].active_pokemon = zamazenta_slot
	state.players[0].deck = [_dummy_card("Own draw", 0)]
	state.players[1].deck = [_dummy_card("Opponent draw", 1)]
	mew_slot.attached_energy = [_energy("C1", "C", 0), _energy("C2", "C", 0), _energy("C3", "C", 0)]
	zamazenta_slot.attached_energy = [_energy("Metal 1", "M", 1), _energy("Metal 2", "M", 1), _energy("Colorless", "C", 1)]
	gsm.effect_processor.register_pokemon_card(mew)
	gsm.effect_processor.register_pokemon_card(zamazenta)

	var copied_used := gsm.use_attack(0, 0, [_copied_attack_context(zamazenta, 0)])
	var marker_kept_source := mew_slot.effects.any(func(entry: Dictionary) -> bool:
		return str(entry.get("attack_reactive_effect_id", "")) == ZAMAZENTA_POWER_SLAM_EFFECT_ID
	)
	var counterattack_used := gsm.use_attack(1, 0)

	return run_checks([
		assert_true(copied_used, "Mew should use the copied delayed reactive attack"),
		assert_true(marker_kept_source, "The delayed marker must retain Zamazenta's source effect identity on Mew"),
		assert_true(counterattack_used, "Zamazenta should attack on the following turn"),
		assert_eq(mew_slot.damage_counters, 70, "The counterattack should damage Mew"),
		assert_eq(zamazenta_slot.damage_counters, 140, "Mew's copied Power Slam should reflect the 70 damage back to the attacker"),
	])


func test_pre_evolution_granted_attack_forwards_damage_cancellation() -> String:
	var relicanth := _load_card("res://data/bundled_user/cards/CSV7C_118.json")
	var cramorant := _load_card("res://data/bundled_user/cards/CSV10C_188.json")
	if relicanth == null or cramorant == null:
		return "CSV7C_118 Relicanth and CSV10C_188 Hop's Cramorant should load"
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	_add_dummy_prizes(state, 6)
	var evolved_data := _pokemon("Evolved borrower", 200, "Stage 1")
	evolved_data.evolves_from = cramorant.name
	var borrower := PokemonSlot.new()
	borrower.pokemon_stack = [CardInstance.create(cramorant, 0), CardInstance.create(evolved_data, 0)]
	borrower.attached_energy = [_energy("Colorless", "C", 0)]
	state.players[0].active_pokemon = borrower
	state.players[0].bench = [_slot(relicanth, 0)]
	state.players[0].deck = [_dummy_card("Own draw", 0)]
	state.players[1].deck = [_dummy_card("Opponent draw", 1)]
	gsm.effect_processor.register_pokemon_card(relicanth)
	gsm.effect_processor.register_pokemon_card(cramorant)
	var granted_attacks := gsm.effect_processor.get_granted_attacks(borrower, state)
	var granted: Dictionary = {}
	for candidate: Dictionary in granted_attacks:
		if str(candidate.get("original_effect_id", "")) == HOPS_CRAMORANT_EFFECT_ID:
			granted = candidate
			break

	var used := gsm.use_granted_attack(0, borrower, granted) if not granted.is_empty() else false

	return run_checks([
		assert_false(granted.is_empty(), "Memory Dive should expose the pre-evolution Cramorant attack"),
		assert_true(used, "The granted attack declaration should resolve"),
		assert_eq(state.players[1].active_pokemon.damage_counters, 0, "Granted attacks must inherit source damage-cancellation rules"),
	])


func test_copied_named_self_lock_does_not_block_the_outer_copy_attack() -> String:
	var mew := _load_card("res://data/bundled_user/cards/151C_151.json")
	var annihilape := _load_card("res://data/bundled_user/cards/CSV10C_100.json")
	if mew == null or annihilape == null:
		return "151C_151 Mew ex and CSV10C_100 Annihilape should load"
	annihilape.hp = 400
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	_add_dummy_prizes(state)
	var mew_slot := _slot(mew, 0)
	var defender := _slot(annihilape, 1)
	state.players[0].active_pokemon = mew_slot
	state.players[1].active_pokemon = defender
	state.players[0].deck = [_dummy_card("Own draw", 0)]
	state.players[1].deck = [_dummy_card("Opponent draw", 1)]
	mew_slot.attached_energy = [_energy("C1", "C", 0), _energy("C2", "C", 0), _energy("C3", "C", 0)]
	gsm.effect_processor.register_pokemon_card(mew)
	gsm.effect_processor.register_pokemon_card(annihilape)

	var used := gsm.use_attack(0, 0, [_copied_attack_context(annihilape, 0)])
	var copied_named_lock := mew_slot.effects.any(func(entry: Dictionary) -> bool:
		return str(entry.get("type", "")) == "attack_lock"
	)
	state.turn_number = 4
	state.current_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	var next_turn_reason := gsm.get_attack_unusable_reason(0, 0)

	return run_checks([
		assert_eq(annihilape.effect_id, ANNIHILAPE_SELF_LOCK_EFFECT_ID, "Annihilape should retain the named self-lock effect identity"),
		assert_true(used, "Genome Hacking should copy Impact Blow"),
		assert_false(copied_named_lock, "Copying a named self-lock attack must not attach that name lock to Genome Hacking"),
		assert_eq(next_turn_reason, "", "Mew should still be able to use Genome Hacking during its next turn"),
	])


func test_granted_named_self_lock_uses_the_original_attack_name() -> String:
	var relicanth := _load_card("res://data/bundled_user/cards/CSV7C_118.json")
	var annihilape := _load_card("res://data/bundled_user/cards/CSV10C_100.json")
	if relicanth == null or annihilape == null:
		return "CSV7C_118 Relicanth and CSV10C_100 Annihilape should load"
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	_add_dummy_prizes(state)
	var evolved_data := _pokemon("Evolved borrower", 250, "Stage 1")
	var borrower := PokemonSlot.new()
	borrower.pokemon_stack = [CardInstance.create(annihilape, 0), CardInstance.create(evolved_data, 0)]
	borrower.attached_energy = [_energy("Fighting 1", "F", 0), _energy("Fighting 2", "F", 0)]
	state.players[0].active_pokemon = borrower
	state.players[0].bench = [_slot(relicanth, 0)]
	state.players[1].active_pokemon = _slot(_pokemon("Durable defender", 400), 1)
	state.players[0].deck = [_dummy_card("Own draw", 0)]
	state.players[1].deck = [_dummy_card("Opponent draw", 1)]
	gsm.effect_processor.register_pokemon_card(relicanth)
	gsm.effect_processor.register_pokemon_card(annihilape)
	var granted: Dictionary = {}
	for candidate: Dictionary in gsm.effect_processor.get_granted_attacks(borrower, state):
		if str(candidate.get("original_effect_id", "")) == ANNIHILAPE_SELF_LOCK_EFFECT_ID:
			granted = candidate
			break

	var used := gsm.use_granted_attack(0, borrower, granted) if not granted.is_empty() else false
	var lock_name := ""
	for entry: Dictionary in borrower.effects:
		if str(entry.get("type", "")) == "attack_lock":
			lock_name = str(entry.get("attack_name", ""))
			break
	state.turn_number = 4
	state.current_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	var next_turn_reason := gsm.rule_validator.get_granted_attack_unusable_reason(state, 0, borrower, granted, gsm.effect_processor) if not granted.is_empty() else "missing"

	return run_checks([
		assert_false(granted.is_empty(), "Memory Dive should expose Annihilape's previous-evolution attack"),
		assert_true(used, "The granted Impact Blow should resolve"),
		assert_eq(lock_name, str(annihilape.attacks[0].get("name", "")), "A granted attack lock should store the original attack name"),
		assert_true(next_turn_reason.contains("下回合"), "The same granted attack should be unavailable during the user's next turn"),
	])


func test_slowking_routes_before_damage_and_cancellation_through_native_lifecycle() -> String:
	var slowking := _load_card("res://data/bundled_user/cards/CSV9C_072.json")
	var greedent := _load_card("res://data/bundled_user/cards/CSV10C_182.json")
	var cramorant := _load_card("res://data/bundled_user/cards/CSV10C_188.json")
	if slowking == null or greedent == null or cramorant == null:
		return "Slowking, Arven's Greedent, and Hop's Cramorant should load"

	var before_gsm := GameStateMachine.new()
	before_gsm.game_state = _make_state()
	var before_state := before_gsm.game_state
	_add_dummy_prizes(before_state)
	var before_attacker := _slot(slowking, 0)
	var before_defender := _slot(_pokemon("Tool defender", 300), 1)
	var tool_data := CardData.new()
	tool_data.name = "Tool to discard"
	tool_data.card_type = "Tool"
	var tool := CardInstance.create(tool_data, 1)
	before_defender.attached_tool = tool
	before_state.players[0].active_pokemon = before_attacker
	before_state.players[1].active_pokemon = before_defender
	var greedent_source := CardInstance.create(greedent, 0)
	before_state.players[0].deck = [greedent_source, _dummy_card("Own draw", 0)]
	before_state.players[1].deck = [_dummy_card("Opponent draw", 1)]
	before_attacker.attached_energy = [_energy("Psychic", "P", 0), _energy("Colorless", "C", 0)]
	before_gsm.effect_processor.register_pokemon_card(slowking)
	before_gsm.effect_processor.register_pokemon_card(greedent)
	var before_used := before_gsm.use_attack(0, 0)

	var cancel_gsm := GameStateMachine.new()
	cancel_gsm.game_state = _make_state()
	var cancel_state := cancel_gsm.game_state
	_add_dummy_prizes(cancel_state, 6)
	var cancel_attacker := _slot(slowking, 0)
	var cancel_defender := _slot(_pokemon("Cancel defender", 300), 1)
	cancel_state.players[0].active_pokemon = cancel_attacker
	cancel_state.players[1].active_pokemon = cancel_defender
	var cramorant_source := CardInstance.create(cramorant, 0)
	cancel_state.players[0].deck = [cramorant_source, _dummy_card("Own draw", 0)]
	cancel_state.players[1].deck = [_dummy_card("Opponent draw", 1)]
	cancel_attacker.attached_energy = [_energy("Psychic", "P", 0), _energy("Colorless", "C", 0)]
	cancel_gsm.effect_processor.register_pokemon_card(slowking)
	cancel_gsm.effect_processor.register_pokemon_card(cramorant)
	var cancel_used := cancel_gsm.use_attack(0, 0)

	return run_checks([
		assert_true(before_used, "Slowking should copy Greedent through the authoritative attack path"),
		assert_true(greedent_source in before_state.players[0].discard_pile, "Slowking should reveal and discard the source before copied damage"),
		assert_eq(before_defender.attached_tool, null, "Slowking must forward the copied before-damage Tool discard"),
		assert_true(tool in before_state.players[1].discard_pile, "The discarded Tool should enter its owner's discard pile"),
		assert_eq(before_defender.damage_counters, 10, "Slowking should deal the copied Greedent damage through native damage calculation"),
		assert_true(cancel_used, "Slowking should legally declare the copied Cramorant attack"),
		assert_true(cramorant_source in cancel_state.players[0].discard_pile, "The cancelled copied attack should still discard Slowking's revealed source"),
		assert_eq(cancel_defender.damage_counters, 0, "Slowking must inherit the copied attack's damage-cancellation condition"),
	])


func test_yanmega_jet_cyclone_requires_three_grass_and_one_colorless_for_every_print() -> String:
	var checks: Array[String] = []
	var bundled_payload: Dictionary = {}
	for card_index: String in ["003", "229", "262"]:
		var card_path := "res://data/bundled_user/cards/CSV10C_%s.json" % card_index
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(card_path))
		if card_index == "003" and parsed is Dictionary:
			bundled_payload = (parsed as Dictionary).duplicate(true)
		var card := CardData.from_dict(parsed) if parsed is Dictionary else null
		checks.append(assert_not_null(card, "CSV10C_%s should load" % card_index))
		if card == null:
			continue
		checks.append(assert_eq(card.effect_id, YANMEGA_EFFECT_ID, "Every Yanmega print should share one effect identity"))
		checks.append(assert_eq(str(card.attacks[0].get("cost", "")), "GGGC", "Jet Cyclone should cost Grass, Grass, Grass, Colorless"))

	var battle_card := _load_card("res://data/bundled_user/cards/CSV10C_003.json")
	if battle_card == null:
		return run_checks(checks)
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	gsm.effect_processor.register_pokemon_card(battle_card)
	var yanmega := _slot(battle_card, 0)
	gsm.game_state.players[0].active_pokemon = yanmega
	yanmega.attached_energy = [
		_energy("Grass A", "G", 0),
		_energy("Grass B", "G", 0),
		_energy("Grass C", "G", 0),
	]
	var usable_with_three_grass := gsm.can_use_attack(0, 0)
	yanmega.attached_energy.append(_energy("Colorless", "C", 0))
	var usable_with_full_cost := gsm.can_use_attack(0, 0)
	checks.append(assert_false(usable_with_three_grass, "Three Grass Energy alone must not pay Jet Cyclone"))
	checks.append(assert_true(usable_with_full_cost, "Three Grass plus one Colorless should pay Jet Cyclone"))
	var cached_payload := bundled_payload.duplicate(true)
	cached_payload["bundled_implementation_revision"] = 1
	if cached_payload.get("attacks", []) is Array and not (cached_payload.get("attacks", []) as Array).is_empty():
		(cached_payload["attacks"] as Array)[0]["cost"] = "GGG"
	var db := CardDatabaseScript.new()
	var should_upgrade_cache := bool(db.call("_bundled_card_json_has_missing_implementation_data", bundled_payload, cached_payload))
	db.free()
	checks.append(assert_eq(int(bundled_payload.get("bundled_implementation_revision", 0)), 2, "Yanmega bundled data should carry a migration revision"))
	checks.append(assert_true(should_upgrade_cache, "Existing revision-1 Yanmega caches must be replaced by the corrected bundled data"))
	return run_checks(checks)


func test_yanmega_retreat_modifiers_follow_stage_and_tool_rules() -> String:
	var yanmega_card := _load_card("res://data/bundled_user/cards/CSV10C_003.json")
	var latias_card := _load_card("res://data/bundled_user/cards/CSV9C_078.json")
	if yanmega_card == null or latias_card == null:
		return "Yanmega ex and Latias ex bundled cards should load"
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(yanmega_card)
	processor.register_pokemon_card(latias_card)
	var state := _make_state()
	var yanmega := _slot(yanmega_card, 0)
	state.players[0].active_pokemon = yanmega
	state.players[0].bench.append(_slot(latias_card, 0))
	var with_skyliner := processor.get_effective_retreat_cost(yanmega, state)

	var rescue_board_data := CardData.new()
	rescue_board_data.name = "Rescue Board"
	rescue_board_data.card_type = "Tool"
	rescue_board_data.effect_id = RESCUE_BOARD_EFFECT_ID
	yanmega.attached_tool = CardInstance.create(rescue_board_data, 0)
	var with_rescue_board := processor.get_effective_retreat_cost(yanmega, state)

	return run_checks([
		assert_eq(with_skyliner, 1, "Latias ex affects Basic Pokemon only; Stage 1 Yanmega must still pay one retreat"),
		assert_eq(with_rescue_board, 0, "Rescue Board should reduce Yanmega's printed one retreat to zero"),
	])


func test_festival_lead_runs_one_pokemon_check_after_the_second_attack_only() -> String:
	var dipplin_card := _load_card("res://data/bundled_user/cards/CSV8C_024.json")
	var froslass_card := _load_card("res://data/bundled_user/cards/CSV7C_059.json")
	if dipplin_card == null or froslass_card == null:
		return "Dipplin and Froslass bundled cards should load"
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	_add_dummy_prizes(gsm.game_state)
	var state := gsm.game_state
	var attacker := _slot(dipplin_card, 0)
	var froslass := _slot(froslass_card, 0)
	var checked_target_data := _pokemon("Ability Target", 200, "Basic", "ability_target")
	checked_target_data.abilities = [{"name": "Visible Ability", "text": ""}]
	var checked_target := _slot(checked_target_data, 1)
	state.players[0].active_pokemon = attacker
	state.players[0].bench = [froslass]
	state.players[1].active_pokemon = _slot(_pokemon("Festival Defender", 300), 1)
	state.players[1].bench = [checked_target]
	state.players[0].deck = [_dummy_card("Own draw", 0)]
	state.players[1].deck = [_dummy_card("Opponent draw", 1)]
	attacker.attached_energy = [_energy("Grass", "G", 0)]
	var stadium_data := CardData.new()
	stadium_data.name = "Festival Grounds"
	stadium_data.card_type = "Stadium"
	stadium_data.effect_id = FESTIVAL_GROUNDS_EFFECT_ID
	state.stadium_card = CardInstance.create(stadium_data, 0)
	state.stadium_owner_index = 0
	gsm.effect_processor.register_pokemon_card(dipplin_card)
	gsm.effect_processor.register_pokemon_card(froslass_card)

	var first_attack := gsm.use_attack(0, 0)
	var damage_after_first := checked_target.damage_counters
	var second_attack := gsm.use_attack(0, 0)
	var check_actions := gsm.action_log.filter(func(action: GameAction) -> bool:
		return action.action_type == GameAction.ActionType.POKEMON_CHECK
	)

	return run_checks([
		assert_true(first_attack, "Festival Lead's first attack should resolve"),
		assert_eq(damage_after_first, 0, "The first Festival Lead attack must not end the turn or run Pokemon Check"),
		assert_true(second_attack, "Festival Lead's second attack should resolve"),
		assert_eq(checked_target.damage_counters, 10, "Froslass should place one damage counter in the single end-of-turn Pokemon Check"),
		assert_eq(check_actions.size(), 1, "The two-attack turn must emit exactly one Pokemon Check"),
	])


func test_poison_check_knockout_does_not_unlock_fezandipiti_flip_the_script() -> String:
	var fezandipiti_card := _load_card("res://data/bundled_user/cards/CSV8C_135.json")
	if fezandipiti_card == null:
		return "CSV8C_135 should load"
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	_add_dummy_prizes(gsm.game_state)
	var state := gsm.game_state
	state.turn_number = 3
	state.current_player_index = 1
	state.phase = GameState.GamePhase.MAIN
	var victim := _slot(_pokemon("Poisoned victim", 10), 0)
	victim.status_conditions["poisoned"] = true
	var replacement := _slot(_pokemon("Replacement", 100), 0)
	var fezandipiti := _slot(fezandipiti_card, 0)
	state.players[0].active_pokemon = victim
	state.players[0].bench = [replacement, fezandipiti]
	state.players[1].active_pokemon = _slot(_pokemon("Opponent Active", 100), 1)
	state.players[0].deck = [
		_dummy_card("Draw 0", 0),
		_dummy_card("Draw 1", 0),
		_dummy_card("Draw 2", 0),
		_dummy_card("Draw 3", 0),
	]
	state.players[1].deck = [_dummy_card("Opponent draw", 1)]
	gsm.effect_processor.register_pokemon_card(fezandipiti_card)

	gsm.end_turn(1)
	var prize_taken := gsm.resolve_take_prize(1, 0)
	var replacement_sent := gsm.send_out_pokemon(0, replacement)
	var ability_used := gsm.use_ability(0, fezandipiti, 0)

	return run_checks([
		assert_true(prize_taken, "Poison knockout should still award the opponent a Prize"),
		assert_true(replacement_sent, "Poison knockout should complete the replacement flow"),
		assert_eq(state.current_player_index, 0, "The poisoned player's next turn should begin"),
		assert_false(ability_used, "A knockout during Pokemon Check is between turns, not during the opponent's previous turn"),
	])


func test_opponent_attack_knockout_unlocks_fezandipiti_and_survives_state_boundaries() -> String:
	var fezandipiti_card := _load_card("res://data/bundled_user/cards/CSV8C_135.json")
	if fezandipiti_card == null:
		return "CSV8C_135 should load"
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	state.turn_number = 2
	state.current_player_index = 1
	state.phase = GameState.GamePhase.ATTACK
	state.record_knockout_against(0)
	state.turn_number = 3
	state.current_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	var fezandipiti := _slot(fezandipiti_card, 0)
	state.players[0].bench.append(fezandipiti)
	state.players[0].deck = [
		_dummy_card("Draw A", 0),
		_dummy_card("Draw B", 0),
		_dummy_card("Draw C", 0),
	]
	gsm.effect_processor.register_pokemon_card(fezandipiti_card)

	var clone := GameStateClonerScript.new().clone_gsm(gsm)
	var snapshot: Dictionary = ScenarioStateSnapshotScript.capture(state)
	var scenario_restore: Dictionary = ScenarioStateRestorerScript.restore(snapshot)
	var restored_gsm: GameStateMachine = scenario_restore.get("gsm")
	var replay_state: GameState = BattleReplayStateRestorerScript.new().restore({"state": snapshot})
	var ability_used := gsm.use_ability(0, fezandipiti, 0)

	return run_checks([
		assert_true(clone.game_state.was_knocked_out_during_opponents_previous_turn(0), "AI clones must preserve qualifying knockout provenance"),
		assert_not_null(restored_gsm, "Scenario snapshot should restore after adding knockout provenance"),
		assert_true(restored_gsm != null and restored_gsm.game_state.was_knocked_out_during_opponents_previous_turn(0), "Scenario restore must preserve qualifying knockout provenance"),
		assert_true(replay_state.was_knocked_out_during_opponents_previous_turn(0), "Replay restore must preserve qualifying knockout provenance"),
		assert_true(ability_used, "An attack knockout during the opponent's turn should unlock Flip the Script"),
		assert_eq(state.players[0].hand.size(), 3, "A legally unlocked Flip the Script should draw exactly three cards"),
	])


func _load_card(path: String) -> CardData:
	if not FileAccess.file_exists(path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return null
	return CardData.from_dict(parsed)


func _make_state() -> GameState:
	CardInstance.reset_id_counter()
	var state := GameState.new()
	state.phase = GameState.GamePhase.MAIN
	state.turn_number = 2
	state.current_player_index = 0
	state.first_player_index = 0
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		player.active_pokemon = _slot(_pokemon("Active %d" % player_index, 200), player_index)
		player.bench = [_slot(_pokemon("Bench %d" % player_index, 100), player_index)]
		state.players.append(player)
	return state


func _pokemon(
	name: String,
	hp: int,
	stage: String = "Basic",
	effect_id: String = ""
) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Pokemon"
	card.stage = stage
	card.hp = hp
	card.effect_id = effect_id
	card.retreat_cost = 1
	card.attacks = [{"name": "Strike", "cost": "", "damage": "10", "text": "", "is_vstar_power": false}]
	return card


func _slot(card: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner_index))
	slot.turn_played = 0
	return slot


func _energy(name: String, energy_type: String, owner_index: int) -> CardInstance:
	var card := CardData.new()
	card.name = name
	card.card_type = "Basic Energy"
	card.energy_type = energy_type
	card.energy_provides = energy_type
	return CardInstance.create(card, owner_index)


func _dummy_card(name: String, owner_index: int) -> CardInstance:
	var card := CardData.new()
	card.name = name
	card.card_type = "Item"
	return CardInstance.create(card, owner_index)


func _copied_attack_context(source: CardData, attack_index: int, nested_context: Dictionary = {}) -> Dictionary:
	var context := nested_context.duplicate(false)
	context[AttackCopyAttack.STEP_ID] = [{
		"source_effect_id": source.effect_id,
		"attack_index": attack_index,
		"attack": source.attacks[attack_index],
	}]
	return context


func _add_dummy_prizes(state: GameState, count: int = 6) -> void:
	for player_index: int in state.players.size():
		state.players[player_index].prizes.clear()
		for prize_index: int in count:
			state.players[player_index].prizes.append(_dummy_card("Prize %d-%d" % [player_index, prize_index], player_index))


func _has_retreat_lock(slot: PokemonSlot) -> bool:
	return slot.effects.any(func(effect_data: Dictionary) -> bool:
		return str(effect_data.get("type", "")) == "retreat_lock"
	)
