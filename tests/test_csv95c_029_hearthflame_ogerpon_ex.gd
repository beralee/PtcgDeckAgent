class_name TestCSV95C029HearthflameOgerponEx
extends TestBase

const EFFECT_ID := "afe6e5fb7931c8c529e43134ef264885"
const CardDatabaseScript := preload("res://scripts/autoload/CardDatabase.gd")


func test_csv95c_029_registry_maps_both_attacks() -> String:
	var db := CardDatabaseScript.new()
	var card: CardData = db.get_card("CSV9.5C", "029")
	var checks: Array[String] = [
		assert_not_null(card, "CSV9.5C_029 should load from the bundled/user card cache"),
	]
	if card == null:
		return run_checks(checks)

	var gsm := _make_gsm_for_attack_card(card, _pokemon("Defender", "Stage 1", "Basic Defender", "C", 400))
	var attacker: PokemonSlot = gsm.game_state.players[0].active_pokemon
	gsm.effect_processor.register_pokemon_card(card)
	var first_attack_effects := gsm.effect_processor.get_attack_effects_for_slot(attacker, 0)
	var second_attack_effects := gsm.effect_processor.get_attack_effects_for_slot(attacker, 1)

	checks.append_array([
		assert_eq(str(card.effect_id), EFFECT_ID, "CSV9.5C_029 should keep the API effect id"),
		assert_true(gsm.effect_processor.has_attack_effect(EFFECT_ID), "CSV9.5C_029 should register attack effects by API effect_id"),
		assert_eq(first_attack_effects.size(), 1, "Wrathful Hearth should have one self-damage multiplier effect"),
		assert_eq(second_attack_effects.size(), 1, "Dynamic Blaze should have one evolved-defender conditional effect"),
	])
	return run_checks(checks)


func test_csv95c_029_wrathful_hearth_counts_self_damage_counters() -> String:
	var db := CardDatabaseScript.new()
	var card: CardData = db.get_card("CSV9.5C", "029")
	var checks: Array[String] = [
		assert_not_null(card, "CSV9.5C_029 should load before testing attack damage"),
	]
	if card == null:
		return run_checks(checks)

	var gsm := _make_gsm_for_attack_card(card, _pokemon("Defender", "Basic", "", "C", 400))
	var attacker: PokemonSlot = gsm.game_state.players[0].active_pokemon
	var defender: PokemonSlot = gsm.game_state.players[1].active_pokemon
	attacker.damage_counters = 50
	gsm.effect_processor.register_pokemon_card(card)

	var bonus := gsm.effect_processor.get_attack_damage_modifier(attacker, defender, card.attacks[0], gsm.game_state, [], 0)
	var resolved_damage := gsm._calculate_attack_damage(attacker, defender, card.attacks[0], 0)

	checks.append_array([
		assert_eq(bonus, 80, "Wrathful Hearth should add the remaining delta for five 20-damage counters"),
		assert_eq(resolved_damage, 100, "Wrathful Hearth should deal 20 damage for each self damage counter"),
	])
	return run_checks(checks)


func test_csv95c_029_dynamic_blaze_does_not_discard_energy_against_basic_defender() -> String:
	var db := CardDatabaseScript.new()
	var card: CardData = db.get_card("CSV9.5C", "029")
	var checks: Array[String] = [
		assert_not_null(card, "CSV9.5C_029 should load before testing Dynamic Blaze"),
	]
	if card == null:
		return run_checks(checks)

	var gsm := _make_gsm_for_attack_card(card, _pokemon("Basic Defender", "Basic", "", "C", 400))
	var attacker: PokemonSlot = gsm.game_state.players[0].active_pokemon
	var defender: PokemonSlot = gsm.game_state.players[1].active_pokemon
	_attach_energy(attacker, 0, "R", 3)
	gsm.effect_processor.register_pokemon_card(card)

	var used := gsm.use_attack(0, 1)

	checks.append_array([
		assert_true(used, "Dynamic Blaze should be usable with three Fire Energy attached"),
		assert_eq(defender.damage_counters, 140, "Dynamic Blaze should deal only printed damage to a Basic Pokemon"),
		assert_eq(attacker.attached_energy.size(), 3, "Dynamic Blaze should keep Energy when the defender is not evolved"),
		assert_eq(gsm.game_state.players[0].discard_pile.size(), 0, "Dynamic Blaze should not discard Energy against Basic Pokemon"),
	])
	return run_checks(checks)


func test_csv95c_029_dynamic_blaze_adds_damage_and_discards_energy_against_evolved_defender() -> String:
	var db := CardDatabaseScript.new()
	var card: CardData = db.get_card("CSV9.5C", "029")
	var checks: Array[String] = [
		assert_not_null(card, "CSV9.5C_029 should load before testing Dynamic Blaze against evolution"),
	]
	if card == null:
		return run_checks(checks)

	var gsm := _make_gsm_for_attack_card(card, _pokemon("Evolution Defender", "Stage 1", "Basic Defender", "C", 400))
	var attacker: PokemonSlot = gsm.game_state.players[0].active_pokemon
	var defender: PokemonSlot = gsm.game_state.players[1].active_pokemon
	var attached := _attach_energy(attacker, 0, "R", 3)
	gsm.effect_processor.register_pokemon_card(card)

	var used := gsm.use_attack(0, 1)

	checks.append_array([
		assert_true(used, "Dynamic Blaze should be usable with three Fire Energy attached"),
		assert_eq(defender.damage_counters, 280, "Dynamic Blaze should add 140 damage against an evolved Active Pokemon"),
		assert_eq(attacker.attached_energy.size(), 0, "Dynamic Blaze should discard all self Energy after adding damage"),
		assert_true(attached[0] in gsm.game_state.players[0].discard_pile, "Dynamic Blaze should discard the first attached Energy"),
		assert_true(attached[1] in gsm.game_state.players[0].discard_pile, "Dynamic Blaze should discard the second attached Energy"),
		assert_true(attached[2] in gsm.game_state.players[0].discard_pile, "Dynamic Blaze should discard the third attached Energy"),
	])
	return run_checks(checks)


func _pokemon(
	name: String,
	stage: String,
	evolves_from: String,
	energy_type: String,
	hp: int
) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Pokemon"
	card.stage = stage
	card.evolves_from = evolves_from
	card.energy_type = energy_type
	card.hp = hp
	return card


func _energy(name: String, energy_type: String) -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = "Basic Energy"
	card.energy_type = energy_type
	card.energy_provides = energy_type
	return card


func _make_slot(card: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner_index))
	return slot


func _make_gsm_for_attack_card(attacker_card: CardData, defender_card: CardData) -> GameStateMachine:
	CardInstance.reset_id_counter()
	var gsm := GameStateMachine.new()
	gsm.game_state.players.clear()
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.current_player_index = 0
	gsm.game_state.turn_number = 3
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	gsm.game_state.players[0].active_pokemon = _make_slot(attacker_card, 0)
	gsm.game_state.players[1].active_pokemon = _make_slot(defender_card, 1)
	return gsm


func _attach_energy(slot: PokemonSlot, owner_index: int, energy_type: String, count: int) -> Array[CardInstance]:
	var attached: Array[CardInstance] = []
	for i: int in count:
		var energy := CardInstance.create(_energy("%s Energy %d" % [energy_type, i], energy_type), owner_index)
		slot.attached_energy.append(energy)
		attached.append(energy)
	return attached
