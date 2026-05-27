class_name TestCSV8CGalvantulaEffects
extends TestBase

const CSV8CGalvantulaEffectsScript = preload("res://scripts/effects/pokemon_effects/CSV8CGalvantulaEffects.gd")
const GALVANTULA_EFFECT_ID := "4aa937bbc437cbfd7b64597b7bcee0d2"


func test_csv8c_010_galvantula_registers_by_effect_id_and_is_implemented() -> String:
	var processor := EffectProcessor.new()
	var card := _galvantula()
	CardImplementationStatus.clear_cache()
	processor.register_pokemon_card(card)
	var checks: Array[String] = [
		assert_true(processor.get_effect(GALVANTULA_EFFECT_ID) is CSV8CGalvantulaEffectsScript, "Galvantula should register its Ability by effect_id"),
		assert_true(processor.has_attack_effect(GALVANTULA_EFFECT_ID), "Galvantula should register its attack bonus by effect_id"),
		assert_false(CardImplementationStatus.is_unimplemented(card), "Galvantula should not show an unimplemented badge: %s" % CardImplementationStatus.get_reason(card)),
	]
	processor.prepare_for_disposal()
	return run_checks(checks)


func test_csv8c_010_galvantula_does_100_to_active_with_ability_without_lightning() -> String:
	var result := _use_galvantula_attack(true, false, false)
	return run_checks([
		assert_true(bool(result["used"]), "Galvantula should be able to use Mamama Net with Grass plus Colorless Energy"),
		assert_eq(int(result["damage"]), 100, "Mamama Net should deal 50 base + 50 Compound Eyes to an Active Pokemon with an Ability"),
	])


func test_csv8c_010_galvantula_does_180_to_active_with_ability_and_lightning() -> String:
	var result := _use_galvantula_attack(true, true, false)
	return run_checks([
		assert_true(bool(result["used"]), "Galvantula should be able to use Mamama Net with Grass plus Lightning Energy"),
		assert_eq(int(result["damage"]), 180, "Mamama Net should deal 50 base + 80 Lightning bonus + 50 Compound Eyes"),
	])


func test_csv8c_010_galvantula_lightning_bonus_does_not_require_defender_ability() -> String:
	var result := _use_galvantula_attack(false, true, false)
	return run_checks([
		assert_true(bool(result["used"]), "Galvantula should still attack a Pokemon without an Ability"),
		assert_eq(int(result["damage"]), 130, "Mamama Net should deal 50 base + 80 Lightning bonus when the defender has no Ability"),
	])


func test_csv8c_010_galvantula_compound_eyes_stops_while_ability_disabled() -> String:
	var result := _use_galvantula_attack(true, true, true)
	return run_checks([
		assert_true(bool(result["used"]), "Ability-disabled Galvantula should still be able to attack"),
		assert_eq(int(result["damage"]), 130, "Cancel-Cologne style Ability disable should suppress only the +50 Compound Eyes bonus"),
	])


func _use_galvantula_attack(
	defender_has_ability: bool,
	attach_lightning: bool,
	disable_attacker_ability: bool
) -> Dictionary:
	var gsm := _make_gsm()
	var attacker := _slot(_galvantula(), 0)
	var defender := _slot(_defender(defender_has_ability), 1)
	_attach_energy(attacker, 0, "G")
	_attach_energy(attacker, 0, "L" if attach_lightning else "C")
	if disable_attacker_ability:
		attacker.effects.append({"type": "ability_disabled", "turn": gsm.game_state.turn_number})
	_set_actives(gsm.game_state, attacker, defender)
	gsm.effect_processor.register_pokemon_card(attacker.get_card_data())
	var used := gsm.use_attack(0, 0)
	var result := {
		"used": used,
		"damage": defender.damage_counters,
	}
	gsm.prepare_for_disposal()
	return result


func _make_gsm() -> GameStateMachine:
	var gsm := GameStateMachine.new()
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


func _attach_energy(slot: PokemonSlot, owner_index: int, energy_type: String) -> void:
	slot.attached_energy.append(CardInstance.create(_energy("%s Energy" % energy_type, energy_type), owner_index))


func _energy(name: String, energy_type: String) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = "Basic Energy"
	cd.energy_type = energy_type
	cd.energy_provides = energy_type
	return cd


func _galvantula() -> CardData:
	var cd := _pokemon(
		"Galvantula",
		GALVANTULA_EFFECT_ID,
		"Stage 1",
		"G",
		100,
		[{"name": "Mamama Net", "cost": "GC", "damage": "50+", "text": "If this Pokemon has Lightning Energy attached, this attack does 80 more damage.", "is_vstar_power": false}],
		[{"name": "Compound Eyes", "text": "Attacks used by this Pokemon do 50 more damage to your opponent's Active Pokemon that has an Ability."}]
	)
	cd.set_code = "CSV8C"
	cd.card_index = "010"
	cd.name_en = "Galvantula"
	cd.evolves_from = "Joltik"
	return cd


func _defender(has_ability: bool) -> CardData:
	var abilities: Array[Dictionary] = []
	if has_ability:
		abilities.append({"name": "Test Ability", "text": "Printed Ability text."})
	return _pokemon(
		"Defender",
		"defender_effect",
		"Basic",
		"C",
		300,
		[{"name": "Tackle", "cost": "C", "damage": "10", "text": "", "is_vstar_power": false}],
		abilities
	)


func _pokemon(
	name: String,
	effect_id: String,
	stage: String,
	energy_type: String,
	hp: int,
	attacks: Array[Dictionary],
	abilities: Array[Dictionary] = []
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
	cd.abilities = abilities
	return cd
