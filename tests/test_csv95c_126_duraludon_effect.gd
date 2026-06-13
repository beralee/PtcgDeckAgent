class_name TestCSV95C126DuraludonEffect
extends TestBase

const AttackSelfDamageCounterBonusScript := preload("res://scripts/effects/pokemon_effects/AttackSelfDamageCounterBonus.gd")
const CardDatabaseScript := preload("res://scripts/autoload/CardDatabase.gd")


func test_csv95c_126_registry_and_damage_chain_use_second_attack_only() -> String:
	var db := CardDatabaseScript.new()
	var card: CardData = db.get_card("CSV9.5C", "126")
	var checks: Array[String] = [
		assert_not_null(card, "CSV9.5C_126 should load from the bundled/user card cache"),
	]
	if card == null:
		return run_checks(checks)
	var gsm := _make_gsm_for_attack_card(card)
	var attacker: PokemonSlot = gsm.game_state.players[0].active_pokemon
	var defender: PokemonSlot = gsm.game_state.players[1].active_pokemon
	attacker.damage_counters = 40
	gsm.effect_processor.register_pokemon_card(card)

	var first_bonus := gsm.effect_processor.get_attack_damage_modifier(attacker, defender, card.attacks[0], gsm.game_state, [], 0)
	var second_bonus := gsm.effect_processor.get_attack_damage_modifier(attacker, defender, card.attacks[1], gsm.game_state, [], 1)
	var second_damage := gsm._calculate_attack_damage(attacker, defender, card.attacks[1], 1)

	checks.append_array([
		assert_true(gsm.effect_processor.has_attack_effect(card.effect_id), "CSV9.5C_126 should register an attack effect directly by effect_id"),
		assert_eq(first_bonus, 0, "Headbutt should not receive the Raging Hammer self-damage bonus"),
		assert_eq(second_bonus, 40, "Raging Hammer should add 10 damage for each damage counter on Duraludon"),
		assert_eq(second_damage, 120, "The battle damage chain should resolve 80 + 40 for Raging Hammer"),
	])
	return run_checks(checks)

func test_csv95c_126_raging_hammer_adds_self_damage_counter_bonus() -> String:
	var state := _make_state()
	var duraludon := _make_slot(_pokemon("Duraludon", "Basic", "", "M", 130, [
		_attack("Headbutt", "M", "30"),
		_attack("Raging Hammer", "MMC", "80+"),
	]), 0)
	var defender := state.players[1].active_pokemon
	state.players[0].active_pokemon = duraludon

	var effect := AttackSelfDamageCounterBonusScript.new(10, 1)
	var zero_bonus := effect.get_damage_bonus(duraludon, state)
	duraludon.damage_counters = 30
	var bonus := effect.get_damage_bonus(duraludon, state)
	var resolved_damage := DamageCalculator.new().calculate_damage(
		duraludon,
		defender,
		duraludon.get_attacks()[1],
		state,
		bonus
	)

	return run_checks([
		assert_eq(zero_bonus, 0, "CSV9.5C_126 should add no damage when it has no damage counters"),
		assert_eq(bonus, 30, "CSV9.5C_126 should add 10 damage per damage counter on itself"),
		assert_eq(resolved_damage, 110, "CSV9.5C_126 Raging Hammer should deal printed 80 plus the self-counter bonus"),
	])


func test_csv95c_126_raging_hammer_bonus_binds_only_second_attack() -> String:
	var effect := AttackSelfDamageCounterBonusScript.new(10, 1)

	return run_checks([
		assert_false(effect.applies_to_attack_index(0), "CSV9.5C_126 Headbutt should not receive the Raging Hammer bonus"),
		assert_true(effect.applies_to_attack_index(1), "CSV9.5C_126 Raging Hammer should receive the self-counter bonus"),
	])


func _make_state() -> GameState:
	var state := GameState.new()
	var player := PlayerState.new()
	var opponent := PlayerState.new()
	player.player_index = 0
	opponent.player_index = 1
	state.players = [player, opponent]
	state.current_player_index = 0
	state.turn_number = 1
	player.active_pokemon = _make_slot(_pokemon("Attacker", "Basic", "", "M", 100), 0)
	opponent.active_pokemon = _make_slot(_pokemon("Defender", "Basic", "", "C", 200), 1)
	return state


func _pokemon(
	name: String,
	stage: String,
	evolves_from: String,
	energy_type: String,
	hp: int,
	attacks: Array[Dictionary] = []
) -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = "Pokemon"
	card.stage = stage
	card.evolves_from = evolves_from
	card.energy_type = energy_type
	card.hp = hp
	card.attacks = attacks
	return card


func _attack(name: String, cost: String, damage: String, text: String = "") -> Dictionary:
	return {
		"name": name,
		"cost": cost,
		"damage": damage,
		"text": text,
		"is_vstar_power": false,
	}


func _make_slot(card: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner_index))
	return slot


func _make_gsm_for_attack_card(attacker_card: CardData) -> GameStateMachine:
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
	gsm.game_state.players[1].active_pokemon = _make_slot(_pokemon("Defender", "Basic", "", "C", 300), 1)
	return gsm
