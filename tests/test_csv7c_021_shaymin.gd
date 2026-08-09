class_name TestCSV7C021Shaymin
extends TestBase

const AILegalActionBuilderScript = preload("res://scripts/ai/AILegalActionBuilder.gd")
const EFFECT_ID := "9e3be3fe406be3516aec15ec6898711a"
const TARGET_STEP_ID := "opponent_bench_ex_v_target"


func test_csv7c_021_precision_dive_registers_only_for_first_attack_and_filters_targets() -> String:
	var state := _make_state()
	var processor := EffectProcessor.new()
	var shaymin_data := _shaymin()
	var shaymin := _make_slot(shaymin_data, 0)
	state.players[0].active_pokemon = shaymin
	var ordinary := _make_slot(_pokemon("Ordinary Pokemon", "", 100), 1)
	var pokemon_ex := _make_slot(_pokemon("Pokemon ex", "ex", 220), 1)
	var pokemon_v := _make_slot(_pokemon("Pokemon V", "V", 210), 1)
	var pokemon_vstar := _make_slot(_pokemon("Pokemon VSTAR", "VSTAR", 280), 1)
	var pokemon_vmax := _make_slot(_pokemon("Pokemon VMAX", "VMAX", 320), 1)
	var radiant := _make_slot(_pokemon("Radiant Pokemon", "Radiant", 130), 1)
	state.players[1].bench = [ordinary, pokemon_ex, pokemon_v, pokemon_vstar, pokemon_vmax, radiant]
	processor.register_pokemon_card(shaymin_data)

	var first_effects := processor.get_attack_effects_for_slot(shaymin, 0)
	var second_effects := processor.get_attack_effects_for_slot(shaymin, 1)
	var steps := processor.get_attack_interaction_steps_by_id(
		EFFECT_ID,
		0,
		shaymin.get_top_card(),
		shaymin_data.attacks[0],
		state
	)
	var step: Dictionary = steps[0] if not steps.is_empty() else {}
	var items: Array = step.get("items", [])

	return run_checks([
		assert_eq(first_effects.size(), 1, "Precision Dive should register exactly one effect on attack 0"),
		assert_eq(second_effects.size(), 0, "Rear Kick should remain a plain printed-damage attack"),
		assert_eq(steps.size(), 1, "Precision Dive should expose one mandatory target step when legal targets exist"),
		assert_eq(str(step.get("id", "")), TARGET_STEP_ID, "Precision Dive should use a stable interaction id"),
		assert_eq(int(step.get("min_select", 0)), 1, "Precision Dive should require one legal target"),
		assert_eq(int(step.get("max_select", 0)), 1, "Precision Dive should select exactly one legal target"),
		assert_true(pokemon_ex in items, "Precision Dive should allow a Benched Pokemon ex"),
		assert_true(pokemon_v in items, "Precision Dive should allow a Benched Pokemon V"),
		assert_true(pokemon_vstar in items, "Pokemon VSTAR should count as Pokemon V"),
		assert_true(pokemon_vmax in items, "Pokemon VMAX should count as Pokemon V"),
		assert_false(ordinary in items, "Precision Dive should reject an ordinary Benched Pokemon"),
		assert_false(radiant in items, "Precision Dive should reject non-ex/V rule-box Pokemon"),
	])


func test_csv7c_021_precision_dive_deals_fixed_bench_damage_without_weakness_or_resistance() -> String:
	var gsm := _make_gsm()
	var shaymin_data := _shaymin()
	var shaymin := _make_slot(shaymin_data, 0)
	var active_defender := _make_slot(_pokemon("Active Defender", "ex", 220), 1)
	var pokemon_ex := _make_slot(_pokemon("Weak Pokemon ex", "ex", 220), 1)
	pokemon_ex.get_card_data().weakness_energy = "G"
	pokemon_ex.get_card_data().weakness_value = "×2"
	var pokemon_v := _make_slot(_pokemon("Resistant Pokemon V", "V", 210), 1)
	pokemon_v.get_card_data().resistance_energy = "G"
	pokemon_v.get_card_data().resistance_value = "-30"
	gsm.game_state.players[0].active_pokemon = shaymin
	gsm.game_state.players[1].active_pokemon = active_defender
	gsm.game_state.players[1].bench = [pokemon_ex, pokemon_v]
	_attach_energy(shaymin, 0, "G")
	gsm.effect_processor.register_pokemon_card(shaymin_data)

	var used := gsm.use_attack(0, 0, [{TARGET_STEP_ID: [pokemon_v]}])

	return run_checks([
		assert_true(used, "Precision Dive should be usable with one Grass Energy"),
		assert_eq(pokemon_v.damage_counters, 60, "Precision Dive should deal exactly 60 to the selected resistant Bench target"),
		assert_eq(pokemon_ex.damage_counters, 0, "Precision Dive should not damage an unselected legal target"),
		assert_eq(active_defender.damage_counters, 0, "Precision Dive should not damage the opponent Active Pokemon"),
	])


func test_csv7c_021_precision_dive_ignores_bench_weakness() -> String:
	var gsm := _make_gsm()
	var shaymin_data := _shaymin()
	var shaymin := _make_slot(shaymin_data, 0)
	var active_defender := _make_slot(_pokemon("Active Defender", "", 120), 1)
	var weak_ex := _make_slot(_pokemon("Weak Pokemon ex", "ex", 220), 1)
	weak_ex.get_card_data().weakness_energy = "G"
	weak_ex.get_card_data().weakness_value = "×2"
	gsm.game_state.players[0].active_pokemon = shaymin
	gsm.game_state.players[1].active_pokemon = active_defender
	gsm.game_state.players[1].bench = [weak_ex]
	_attach_energy(shaymin, 0, "G")
	gsm.effect_processor.register_pokemon_card(shaymin_data)

	var used := gsm.use_attack(0, 0, [{TARGET_STEP_ID: [weak_ex]}])

	return run_checks([
		assert_true(used, "Precision Dive should resolve against a Weak Benched Pokemon ex"),
		assert_eq(weak_ex.damage_counters, 60, "Precision Dive should not double damage for Bench Weakness"),
	])


func test_csv7c_021_ai_action_marks_precision_dive_as_interactive() -> String:
	var gsm := _make_gsm()
	var shaymin_data := _shaymin()
	var shaymin := _make_slot(shaymin_data, 0)
	gsm.game_state.players[0].active_pokemon = shaymin
	gsm.game_state.players[1].active_pokemon = _make_slot(_pokemon("Active Defender", "", 120), 1)
	gsm.game_state.players[1].bench = [_make_slot(_pokemon("Pokemon ex", "ex", 220), 1)]
	_attach_energy(shaymin, 0, "G")
	gsm.effect_processor.register_pokemon_card(shaymin_data)

	var action: Dictionary = {}
	for candidate: Dictionary in AILegalActionBuilderScript.new().build_actions(gsm, 0):
		if str(candidate.get("kind", "")) == "attack" and int(candidate.get("attack_index", -1)) == 0:
			action = candidate
			break

	return run_checks([
		assert_false(action.is_empty(), "Headless action builder should enumerate Precision Dive"),
		assert_true(bool(action.get("requires_interaction", false)), "Headless action builder should preserve the ex/V Bench target choice"),
	])


func test_csv7c_021_precision_dive_has_no_interaction_when_no_legal_bench_target_exists() -> String:
	var state := _make_state()
	var processor := EffectProcessor.new()
	var shaymin_data := _shaymin()
	var shaymin := _make_slot(shaymin_data, 0)
	state.players[0].active_pokemon = shaymin
	state.players[1].bench = [_make_slot(_pokemon("Ordinary Bench", "", 100), 1)]
	processor.register_pokemon_card(shaymin_data)

	var steps := processor.get_attack_interaction_steps_by_id(
		EFFECT_ID,
		0,
		shaymin.get_top_card(),
		shaymin_data.attacks[0],
		state
	)

	return assert_true(steps.is_empty(), "Precision Dive should not open an empty target dialog without ex/V Bench targets")


func _make_gsm() -> GameStateMachine:
	CardInstance.reset_id_counter()
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	gsm.effect_processor.bind_game_state_machine(gsm)
	return gsm


func _make_state() -> GameState:
	var state := GameState.new()
	state.phase = GameState.GamePhase.MAIN
	state.turn_number = 2
	state.current_player_index = 0
	state.first_player_index = 0
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		player.active_pokemon = _make_slot(_pokemon("Active %d" % player_index, "", 120), player_index)
		state.players.append(player)
	return state


func _shaymin() -> CardData:
	var card := _pokemon("谢米", "", 70)
	card.name_en = "Shaymin"
	card.set_code = "CSV7C"
	card.card_index = "021"
	card.effect_id = EFFECT_ID
	card.energy_type = "G"
	card.attacks = [
		{"name": "精准俯冲", "cost": "G", "damage": "", "text": "给对手备战区中的1只「宝可梦【ex】・V」，造成60伤害。", "is_vstar_power": false},
		{"name": "后踢", "cost": "CC", "damage": "50", "text": "", "is_vstar_power": false},
	]
	return card


func _pokemon(name: String, mechanic: String, hp: int) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.energy_type = "C"
	card.hp = hp
	card.mechanic = mechanic
	return card


func _make_slot(card_data: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	slot.turn_played = 0
	return slot


func _attach_energy(slot: PokemonSlot, owner_index: int, energy_type: String) -> void:
	var energy := CardData.new()
	energy.name = "%s Energy" % energy_type
	energy.card_type = "Basic Energy"
	energy.energy_type = energy_type
	energy.energy_provides = energy_type
	slot.attached_energy.append(CardInstance.create(energy, owner_index))
