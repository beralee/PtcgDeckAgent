class_name TestCSV8C088XerneasEx
extends TestBase

const AttackBonusIfDefenderMechanicScript = preload("res://scripts/effects/pokemon_effects/AttackBonusIfDefenderMechanic.gd")

const XERNEAS_EFFECT_ID := "f9f3064af6f889b03d08d69feb7a4419"


func test_csv8c_088_registers_brilliant_horn_only_on_second_attack() -> String:
	CardImplementationStatus.clear_cache()
	var processor := EffectProcessor.new()
	var xerneas_cd := _make_xerneas_data()
	var xerneas := _make_slot(xerneas_cd, 0)

	processor.register_pokemon_card(xerneas_cd)
	var first_attack_effects := processor.get_attack_effects_for_slot(xerneas, 0)
	var second_attack_effects := processor.get_attack_effects_for_slot(xerneas, 1)
	var second_attack_is_bonus := false
	if not second_attack_effects.is_empty():
		second_attack_is_bonus = is_instance_of(second_attack_effects[0], AttackBonusIfDefenderMechanicScript)

	return run_checks([
		assert_true(processor.has_attack_effect(XERNEAS_EFFECT_ID), "CSV8C_088 should register Brilliant Horn by effect_id"),
		assert_eq(first_attack_effects.size(), 0, "CSV8C_088 Aurora Beam should remain numeric-only"),
		assert_eq(second_attack_effects.size(), 1, "CSV8C_088 Brilliant Horn should have one conditional damage effect"),
		assert_true(second_attack_is_bonus, "CSV8C_088 should use the defender mechanic bonus effect"),
		assert_false(CardImplementationStatus.is_unimplemented(xerneas_cd), "CSV8C_088 should not be marked unimplemented once registered"),
	])


func test_csv8c_088_brilliant_horn_deals_220_to_ex_active() -> String:
	var gsm := _make_xerneas_game(_make_pokemon_data("Opponent ex", "C", 330, "Basic", "ex"))
	var defender := gsm.game_state.players[1].active_pokemon

	var attack_ok := gsm.use_attack(0, 1)

	return run_checks([
		assert_true(attack_ok, "CSV8C_088 should be able to use Brilliant Horn with PPC attached"),
		assert_eq(defender.damage_counters, 220, "CSV8C_088 Brilliant Horn should deal 120 + 100 to an opponent Active Pokemon ex"),
	])


func test_csv8c_088_brilliant_horn_deals_120_to_non_ex_active() -> String:
	var gsm := _make_xerneas_game(_make_pokemon_data("Regular Defender", "C", 330, "Basic"))
	var defender := gsm.game_state.players[1].active_pokemon

	var attack_ok := gsm.use_attack(0, 1)

	return run_checks([
		assert_true(attack_ok, "CSV8C_088 should be able to use Brilliant Horn against a non-ex defender"),
		assert_eq(defender.damage_counters, 120, "CSV8C_088 Brilliant Horn should not add 100 against non-ex Pokemon"),
	])


func test_csv8c_088_aurora_beam_does_not_receive_ex_bonus() -> String:
	var gsm := _make_xerneas_game(_make_pokemon_data("Opponent ex", "C", 330, "Basic", "ex"))
	var defender := gsm.game_state.players[1].active_pokemon

	var attack_ok := gsm.use_attack(0, 0)

	return run_checks([
		assert_true(attack_ok, "CSV8C_088 should be able to use Aurora Beam with PPC attached"),
		assert_eq(defender.damage_counters, 50, "CSV8C_088 Aurora Beam should stay at printed 50 even against Pokemon ex"),
	])


func _make_xerneas_game(defender_cd: CardData) -> GameStateMachine:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var xerneas_cd := _make_xerneas_data()
	var xerneas := _make_slot(xerneas_cd, 0)
	_attach_energy(xerneas, "Psychic Energy A", "P", 0)
	_attach_energy(xerneas, "Psychic Energy B", "P", 0)
	_attach_energy(xerneas, "Psychic Energy C", "P", 0)
	gsm.game_state.players[0].active_pokemon = xerneas
	gsm.game_state.players[1].active_pokemon = _make_slot(defender_cd, 1)
	gsm.effect_processor.register_pokemon_card(xerneas_cd)
	return gsm


func _make_state() -> GameState:
	CardInstance.reset_id_counter()
	var state := GameState.new()
	state.turn_number = 2
	state.current_player_index = 0
	state.first_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		player.active_pokemon = _make_slot(_make_pokemon_data("Active%d" % pi, "C"), pi)
		state.players.append(player)
	return state


func _make_xerneas_data() -> CardData:
	var cd := _make_pokemon_data("哲尔尼亚斯ex", "P", 210, "Basic", "ex", XERNEAS_EFFECT_ID)
	cd.name_en = "Xerneas ex"
	cd.set_code = "CSV8C"
	cd.card_index = "088"
	cd.retreat_cost = 1
	cd.weakness_energy = "M"
	cd.weakness_value = "x2"
	cd.attacks = [
		{"name": "极光束", "cost": "PC", "damage": "50", "text": "", "is_vstar_power": false},
		{"name": "璀璨角击", "cost": "PPC", "damage": "120+", "text": "如果对手的战斗宝可梦是「宝可梦【ex】」的话，则追加造成100伤害。", "is_vstar_power": false},
	]
	return cd


func _make_pokemon_data(
	name: String,
	energy_type: String,
	hp: int = 100,
	stage: String = "Basic",
	mechanic: String = "",
	effect_id: String = ""
) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = "Pokemon"
	cd.energy_type = energy_type
	cd.stage = stage
	cd.hp = hp
	cd.mechanic = mechanic
	cd.effect_id = effect_id
	cd.attacks = [{"name": "Strike", "cost": "", "damage": "10", "text": "", "is_vstar_power": false}]
	return cd


func _make_energy_data(name: String, energy_type: String) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = "Basic Energy"
	cd.energy_provides = energy_type
	return cd


func _make_slot(card_data: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	slot.turn_played = 0
	return slot


func _attach_energy(slot: PokemonSlot, name: String, energy_type: String, owner_index: int) -> CardInstance:
	var energy := CardInstance.create(_make_energy_data(name, energy_type), owner_index)
	slot.attached_energy.append(energy)
	return energy
