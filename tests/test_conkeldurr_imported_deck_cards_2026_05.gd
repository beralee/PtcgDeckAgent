class_name TestConkeldurrImportedDeckCards202605
extends TestBase

const TIMBURR_EFFECT_ID := "0a2064b80b0edf2b2ec683210e77e1f2"
const GURDURR_EFFECT_ID := "99041ad1ee1b4ff984b57638cae3caf9"
const CONKELDURR_EFFECT_ID := "898ff379e73790978b8bdf6dfafc511f"
const FROGADIER_EFFECT_ID := "ea2b685fc75e11c65704bc2709c9af96"
const OPTIONAL_STEP_ID := "optional_bonus_self_damage"


class RiggedCoinFlipper extends CoinFlipper:
	var _results: Array[bool] = []

	func _init(results: Array[bool]) -> void:
		_results = results.duplicate()

	func flip() -> bool:
		if _results.is_empty():
			return false
		var result: bool = _results.pop_front()
		coin_flipped.emit(result)
		return result


func test_csv8c_conkeldurr_line_is_marked_implemented() -> String:
	var cards := [_timburr(), _gurdurr(), _conkeldurr(), _frogadier()]
	var processor := EffectProcessor.new()
	var checks: Array[String] = []
	CardImplementationStatus.clear_cache()
	for card: CardData in cards:
		processor.register_pokemon_card(card)
		checks.append(assert_false(
			CardImplementationStatus.is_unimplemented(card),
			"%s should not show an unimplemented badge: %s" % [card.name_en, CardImplementationStatus.get_reason(card)]
		))
	checks.append(assert_true(processor.has_attack_effect(TIMBURR_EFFECT_ID), "Timburr should register its fail-on-tails attack effect"))
	checks.append(assert_true(processor.has_attack_effect(GURDURR_EFFECT_ID), "Gurdurr should register its optional bonus attack effect"))
	checks.append(assert_not_null(processor.get_effect(CONKELDURR_EFFECT_ID), "Conkeldurr should register its native cost/status effect"))
	checks.append(assert_true(processor.has_attack_effect(CONKELDURR_EFFECT_ID), "Conkeldurr should register its scripted attack effect"))
	checks.append(assert_true(processor.has_attack_effect(FROGADIER_EFFECT_ID), "Frogadier should register its coin-flip Paralysis attack effect"))
	processor.prepare_for_disposal()
	return run_checks(checks)


func test_csv8c_112_conkeldurr_attack_effect_is_scoped_to_rampage() -> String:
	var processor := EffectProcessor.new()
	var attacker := _slot(_conkeldurr(), 0)
	processor.register_pokemon_card(attacker.get_card_data())

	var rampage_effects := processor.get_attack_effects_for_slot(attacker, 0)
	var gritty_swing_effects := processor.get_attack_effects_for_slot(attacker, 1)

	var checks: Array[String] = [
		assert_eq(rampage_effects.size(), 1, "Rampage should expose the self-confusion attack effect"),
		assert_eq(gritty_swing_effects.size(), 0, "Gritty Swing should not inherit Rampage's execute_attack effect"),
		assert_not_null(processor.get_effect(CONKELDURR_EFFECT_ID), "Gritty Swing's cost override should stay registered as the card effect"),
	]
	processor.prepare_for_disposal()
	return run_checks(checks)


func test_csv8c_110_timburr_full_power_punch_fails_on_tails() -> String:
	var gsm := _make_gsm(RiggedCoinFlipper.new([false]))
	var attacker := _slot(_timburr(), 0)
	var defender := _slot(_defender(), 1)
	_attach_energy(attacker, 0, "F", 1)
	_set_actives(gsm.game_state, attacker, defender)
	gsm.effect_processor.register_pokemon_card(attacker.get_card_data())

	var used := gsm.use_attack(0, 0)

	return run_checks([
		assert_true(used, "Timburr should be able to use Full Power Punch with one Fighting Energy"),
		assert_eq(defender.damage_counters, 0, "Full Power Punch should deal no damage on tails"),
	])


func test_csv8c_110_timburr_full_power_punch_tails_cancels_weakness_damage() -> String:
	var gsm := _make_gsm(RiggedCoinFlipper.new([false]))
	var attacker := _slot(_timburr(), 0)
	var weak_defender_data := _defender()
	weak_defender_data.weakness_energy = "F"
	weak_defender_data.weakness_value = "x2"
	var defender := _slot(weak_defender_data, 1)
	_attach_energy(attacker, 0, "F", 1)
	_set_actives(gsm.game_state, attacker, defender)
	gsm.effect_processor.register_pokemon_card(attacker.get_card_data())

	var used := gsm.use_attack(0, 0)

	return run_checks([
		assert_true(used, "Timburr should still resolve the attack action on tails"),
		assert_eq(defender.damage_counters, 0, "Fail-on-tails attacks must cancel damage before weakness is applied"),
	])


func test_csv8c_111_gurdurr_brute_force_optional_bonus_and_self_damage() -> String:
	var gsm := _make_gsm()
	var attacker := _slot(_gurdurr(), 0)
	var defender := _slot(_defender(), 1)
	_attach_energy(attacker, 0, "F", 1)
	_attach_energy(attacker, 0, "C", 2)
	_set_actives(gsm.game_state, attacker, defender)
	gsm.effect_processor.register_pokemon_card(attacker.get_card_data())

	var steps := gsm.effect_processor.get_attack_interaction_steps_by_id(
		GURDURR_EFFECT_ID,
		1,
		CardInstance.create(attacker.get_card_data(), 0),
		attacker.get_card_data().attacks[1],
		gsm.game_state
	)
	var used := gsm.use_attack(0, 1, [{OPTIONAL_STEP_ID: ["yes"]}])

	return run_checks([
		assert_eq(steps.size(), 1, "Gurdurr's Brute Force should ask whether to take the optional bonus"),
		assert_true(used, "Gurdurr should use Brute Force with the required Energy"),
		assert_eq(defender.damage_counters, 80, "Brute Force should deal 80 damage when the bonus is chosen"),
		assert_eq(attacker.damage_counters, 30, "Brute Force should deal 30 damage to Gurdurr when the bonus is chosen"),
	])


func test_csv8c_112_conkeldurr_rampage_confuses_self() -> String:
	var gsm := _make_gsm()
	var attacker := _slot(_conkeldurr(), 0)
	var defender := _slot(_defender(), 1)
	_attach_energy(attacker, 0, "F", 1)
	_set_actives(gsm.game_state, attacker, defender)
	gsm.effect_processor.register_pokemon_card(attacker.get_card_data())

	var used := gsm.use_attack(0, 0)

	return run_checks([
		assert_true(used, "Conkeldurr should be able to use Rampage with one Fighting Energy"),
		assert_eq(defender.damage_counters, 80, "Rampage should deal its printed 80 damage"),
		assert_true(attacker.status_conditions.get("confused", false), "Rampage should confuse Conkeldurr"),
	])


func test_csv8c_112_conkeldurr_gritty_swing_is_free_while_special_conditioned() -> String:
	var gsm := _make_gsm()
	var attacker := _slot(_conkeldurr(), 0)
	var defender := _slot(_defender(), 1)
	_set_actives(gsm.game_state, attacker, defender)
	gsm.effect_processor.register_pokemon_card(attacker.get_card_data())

	var blocked_without_status := gsm.get_attack_unusable_reason(0, 1) != ""
	attacker.status_conditions["poisoned"] = true
	var usable_with_status := gsm.can_use_attack(0, 1)

	return run_checks([
		assert_true(blocked_without_status, "Gritty Swing should still require Energy when Conkeldurr has no Special Condition"),
		assert_true(usable_with_status, "Gritty Swing should ignore its Energy cost while Conkeldurr has a Special Condition"),
	])


func test_csv7c_065_frogadier_bubble_drip_paralyzes_on_heads() -> String:
	var gsm := _make_gsm(RiggedCoinFlipper.new([true]))
	var attacker := _slot(_frogadier(), 0)
	var defender := _slot(_defender(), 1)
	_attach_energy(attacker, 0, "W", 1)
	_set_actives(gsm.game_state, attacker, defender)
	gsm.effect_processor.register_pokemon_card(attacker.get_card_data())

	var used := gsm.use_attack(0, 0)

	return run_checks([
		assert_true(used, "Frogadier should be able to use Bubble Drip with one Water Energy"),
		assert_eq(defender.damage_counters, 20, "Bubble Drip should deal its printed 20 damage"),
		assert_true(defender.status_conditions.get("paralyzed", false), "Bubble Drip should Paralyze the opponent's Active Pokemon on heads"),
	])


func _make_gsm(flipper: CoinFlipper = null) -> GameStateMachine:
	var gsm := GameStateMachine.new()
	if flipper != null:
		gsm.coin_flipper = flipper
		gsm.effect_processor = EffectProcessor.new(flipper)
		gsm.effect_processor.bind_game_state_machine(gsm)
	gsm.game_state = _make_state()
	return gsm


func _make_state() -> GameState:
	var state := GameState.new()
	state.turn_number = 2
	state.current_player_index = 0
	state.first_player_index = 1
	state.phase = GameState.GamePhase.MAIN
	CardInstance.reset_id_counter()
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		state.players.append(player)
	return state


func _set_actives(state: GameState, own_active: PokemonSlot, opp_active: PokemonSlot) -> void:
	state.players[0].active_pokemon = own_active
	state.players[1].active_pokemon = opp_active


func _slot(card_data: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	slot.turn_played = 0
	return slot


func _attach_energy(slot: PokemonSlot, owner_index: int, energy_type: String, count: int) -> void:
	for i: int in count:
		slot.attached_energy.append(CardInstance.create(_energy("%s Energy %d" % [energy_type, i], energy_type), owner_index))


func _energy(name: String, energy_type: String) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = "Basic Energy"
	cd.energy_type = energy_type
	cd.energy_provides = energy_type
	return cd


func _defender() -> CardData:
	return _pokemon(
		"Defender",
		"",
		"Basic",
		"C",
		300,
		[{"name": "Tackle", "cost": "C", "damage": "10", "text": "", "is_vstar_power": false}]
	)


func _timburr() -> CardData:
	return _pokemon(
		"Timburr",
		TIMBURR_EFFECT_ID,
		"Basic",
		"F",
		80,
		[{"name": "Full Power Punch", "cost": "F", "damage": "40", "text": "Flip a coin. If tails, this attack does nothing.", "is_vstar_power": false}]
	)


func _gurdurr() -> CardData:
	var cd := _pokemon(
		"Gurdurr",
		GURDURR_EFFECT_ID,
		"Stage 1",
		"F",
		100,
		[
			{"name": "Knuckle Punch", "cost": "F", "damage": "20", "text": "", "is_vstar_power": false},
			{"name": "Brute Force", "cost": "FCC", "damage": "50+", "text": "You may do 30 more damage. If you do, this Pokemon also does 30 damage to itself.", "is_vstar_power": false},
		]
	)
	cd.evolves_from = "Timburr"
	return cd


func _conkeldurr() -> CardData:
	var cd := _pokemon(
		"Conkeldurr",
		CONKELDURR_EFFECT_ID,
		"Stage 2",
		"F",
		180,
		[
			{"name": "Rampage", "cost": "F", "damage": "80", "text": "This Pokemon is now Confused.", "is_vstar_power": false},
			{"name": "Gritty Swing", "cost": "FCCC", "damage": "250", "text": "If this Pokemon is affected by a Special Condition, this attack can be used even if this Pokemon has no Energy attached.", "is_vstar_power": false},
		]
	)
	cd.evolves_from = "Gurdurr"
	return cd


func _frogadier() -> CardData:
	var cd := _pokemon(
		"Frogadier",
		FROGADIER_EFFECT_ID,
		"Stage 1",
		"W",
		90,
		[{"name": "Bubble Drip", "cost": "W", "damage": "20", "text": "Flip a coin. If heads, your opponent's Active Pokemon is now Paralyzed.", "is_vstar_power": false}]
	)
	cd.evolves_from = "Froakie"
	return cd


func _pokemon(
	name: String,
	effect_id: String,
	stage: String,
	energy_type: String,
	hp: int,
	attacks: Array[Dictionary]
) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = "Pokemon"
	cd.effect_id = effect_id
	cd.stage = stage
	cd.energy_type = energy_type
	cd.hp = hp
	cd.attacks = attacks
	return cd
