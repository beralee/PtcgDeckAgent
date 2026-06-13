class_name TestCSV95C149RegigigasEffect
extends TestBase

const RegigigasEffect := preload("res://scripts/effects/pokemon_effects/AttackBonusIfOpponentActiveTera.gd")
const CardDatabaseScript := preload("res://scripts/autoload/CardDatabase.gd")


func test_csv95c_149_registry_and_damage_chain_check_only_opponent_active() -> String:
	var db := CardDatabaseScript.new()
	var card: CardData = db.get_card("CSV9.5C", "149")
	var checks: Array[String] = [
		assert_not_null(card, "CSV9.5C_149 should load from the bundled/user card cache"),
	]
	if card == null:
		return run_checks(checks)
	var gsm := _make_gsm_for_attack_card(card)
	var attacker: PokemonSlot = gsm.game_state.players[0].active_pokemon
	var opponent_active: PokemonSlot = gsm.game_state.players[1].active_pokemon
	opponent_active.get_card_data().ancient_trait = "Tera"
	gsm.effect_processor.register_pokemon_card(card)

	var tera_bonus := gsm.effect_processor.get_attack_damage_modifier(attacker, opponent_active, card.attacks[0], gsm.game_state, [], 0)
	var tera_damage := gsm._calculate_attack_damage(attacker, opponent_active, card.attacks[0], 0)
	opponent_active.get_card_data().ancient_trait = ""
	var own_bench_tera := _make_slot(_pokemon("Own Bench Tera", "Basic", "", "C", 100), 0)
	own_bench_tera.get_card_data().ancient_trait = "Tera"
	var opponent_bench_tera := _make_slot(_pokemon("Opponent Bench Tera", "Basic", "", "C", 100), 1)
	opponent_bench_tera.get_card_data().ancient_trait = "Tera"
	gsm.game_state.players[0].bench.append(own_bench_tera)
	gsm.game_state.players[1].bench.append(opponent_bench_tera)
	var non_active_bonus := gsm.effect_processor.get_attack_damage_modifier(attacker, opponent_active, card.attacks[0], gsm.game_state, [], 0)
	var non_active_damage := gsm._calculate_attack_damage(attacker, opponent_active, card.attacks[0], 0)

	checks.append_array([
		assert_true(gsm.effect_processor.has_attack_effect(card.effect_id), "CSV9.5C_149 should register an attack effect directly by effect_id"),
		assert_eq(tera_bonus, 230, "Jewel Break should add 230 only when the opponent Active Pokemon is Tera"),
		assert_eq(tera_damage, 330, "The battle damage chain should resolve 100 + 230 against opponent Active Tera"),
		assert_eq(non_active_bonus, 0, "Own Tera Pokemon and opponent Benched Tera Pokemon should not satisfy Jewel Break"),
		assert_eq(non_active_damage, 100, "Jewel Break should stay at printed 100 without opponent Active Tera"),
	])
	return run_checks(checks)


func test_csv95c_149_jewel_break_adds_230_against_opponent_active_tera() -> String:
	var state := _make_state()
	var attacker := _make_slot(_pokemon("Regigigas", "Basic", "", "C", 160, [
		_attack("Jewel Break", "CCCC", "100+"),
	]), 0)
	state.players[0].active_pokemon = attacker
	state.players[1].active_pokemon.get_card_data().ancient_trait = "Tera"

	var effect := RegigigasEffect.new(230, 0)
	var bonus := effect.get_damage_bonus(attacker, state)
	var damage := DamageCalculator.new().calculate_damage(
		attacker,
		state.players[1].active_pokemon,
		attacker.get_attacks()[0],
		state,
		bonus
	)

	return run_checks([
		assert_eq(bonus, 230, "CSV9.5C_149 Jewel Break should add 230 against opponent Active Tera Pokemon"),
		assert_eq(damage, 330, "CSV9.5C_149 Jewel Break should deal 100 + 230 total damage against Tera"),
	])


func test_csv95c_149_jewel_break_does_not_count_benched_tera() -> String:
	var state := _make_state()
	var attacker := _make_slot(_pokemon("Regigigas", "Basic", "", "C", 160, [
		_attack("Jewel Break", "CCCC", "100+"),
	]), 0)
	state.players[0].active_pokemon = attacker
	var tera_bench := _make_slot(_pokemon("Opponent Bench Tera", "Basic", "", "C", 100), 1)
	tera_bench.get_card_data().ancient_trait = "Tera"
	state.players[1].bench.append(tera_bench)

	var bonus := RegigigasEffect.new(230, 0).get_damage_bonus(attacker, state)

	return run_checks([
		assert_eq(bonus, 0, "CSV9.5C_149 Jewel Break should only check the opponent Active Pokemon"),
	])


func test_csv95c_149_jewel_break_reuses_shared_tera_detection() -> String:
	var state := _make_state()
	var attacker := _make_slot(_pokemon("Regigigas", "Basic", "", "C", 160, [
		_attack("Jewel Break", "CCCC", "100+"),
	]), 0)
	state.players[0].active_pokemon = attacker
	state.players[1].active_pokemon = _make_slot(_pokemon("Three-Type Tera", "Basic", "", "C", 120, [
		_attack("Terastal Attack", "GRW", "180"),
	]), 1)

	var bonus := RegigigasEffect.new(230, 0).get_damage_bonus(attacker, state)

	return run_checks([
		assert_eq(bonus, 230, "CSV9.5C_149 should use the shared Tera detector, including three non-Colorless attack costs"),
	])


func _make_state() -> GameState:
	CardInstance.reset_id_counter()
	var state := GameState.new()
	state.phase = GameState.GamePhase.MAIN
	state.turn_number = 2
	state.current_player_index = 0
	state.first_player_index = 0
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		player.active_pokemon = _make_slot(_pokemon("Active %d" % pi, "Basic", "", "C"), pi)
		state.players.append(player)
	return state


func _pokemon(
	name: String,
	stage: String = "Basic",
	evolves_from: String = "",
	energy_type: String = "C",
	hp: int = 100,
	attacks: Array[Dictionary] = []
) -> CardData:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = "Pokemon"
	data.stage = stage
	data.evolves_from = evolves_from
	data.energy_type = energy_type
	data.hp = hp
	data.attacks = attacks
	return data


func _attack(name: String, cost: String = "", damage: String = "", text: String = "") -> Dictionary:
	return {"name": name, "cost": cost, "damage": damage, "text": text, "is_vstar_power": false}


func _make_slot(card_data: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	slot.turn_played = 0
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
