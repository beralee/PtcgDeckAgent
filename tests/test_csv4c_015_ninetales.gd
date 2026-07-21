class_name TestCSV4C015Ninetales
extends TestBase

const CardDatabaseScript := preload("res://scripts/autoload/CardDatabase.gd")
const AttackSelfAllAttacksLockNextTurnScript := preload("res://scripts/effects/pokemon_effects/AttackSelfAllAttacksLockNextTurn.gd")

const EFFECT_ID := "b540fb36a187e1d05008e3be61084e81"
const TARGET_STEP_ID := "opponent_pokemon_damage_counter_target"


func test_csv4c_015_registers_nine_damage_counters_and_next_turn_attack_lock() -> String:
	var card := _ninetales()
	if card == null:
		return assert_not_null(card, "CSV4C_015 should load from the catalog")
	var processor := EffectProcessor.new()
	var slot := _make_slot(card, 0)
	processor.register_pokemon_card(card)
	var effects := processor.get_attack_effects_for_slot(slot, 1)
	var has_counter_effect := false
	var has_lock_effect := false
	for effect: BaseEffect in effects:
		var script_path := str(effect.get_script().resource_path) if effect.get_script() != null else ""
		if script_path.ends_with("AttackChooseOpponentPokemonDamageCounters.gd"):
			has_counter_effect = true
		if is_instance_of(effect, AttackSelfAllAttacksLockNextTurnScript):
			has_lock_effect = true

	return run_checks([
		assert_eq(card.name, "九尾", "CSV4C_015 should load the expected card"),
		assert_eq(card.evolves_from, "六尾", "CSV4C_015 should preserve its evolution source"),
		assert_eq(card.attacks.size(), 2, "CSV4C_015 should expose both printed attacks"),
		assert_eq(effects.size(), 2, "Ninetales Dance should register both printed effects"),
		assert_true(has_counter_effect, "Ninetales Dance should register arbitrary-opponent-Pokemon damage counters"),
		assert_true(has_lock_effect, "Ninetales Dance should register the next-own-turn whole-Pokemon attack lock"),
		assert_false(CardImplementationStatus.is_unimplemented(card), "CSV4C_015 should be marked implemented"),
	])


func test_csv4c_015_ninetales_dance_targets_active_or_bench_and_places_exactly_nine_counters() -> String:
	var card := _ninetales()
	if card == null:
		return assert_not_null(card, "CSV4C_015 should load from the catalog")
	var gsm := _make_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	var opponent: PlayerState = gsm.game_state.players[1]
	var attacker := _make_slot(card, 0)
	var opponent_active := _make_slot(_pokemon("Opponent Active", 300), 1)
	var opponent_bench := _make_slot(_pokemon("Opponent Bench", 200), 1)
	player.active_pokemon = attacker
	opponent.active_pokemon = opponent_active
	opponent.bench.append(opponent_bench)
	_attach_energy(attacker, "R", 2)
	gsm.effect_processor.register_pokemon_card(card)
	var effects := gsm.effect_processor.get_attack_effects_for_slot(attacker, 1)
	var counter_effect: BaseEffect = null
	for effect: BaseEffect in effects:
		if effect.has_method("get_attack_interaction_steps"):
			var candidate_steps: Array[Dictionary] = effect.get_attack_interaction_steps(attacker.get_top_card(), card.attacks[1], gsm.game_state)
			if not candidate_steps.is_empty():
				counter_effect = effect
				break
	var steps: Array[Dictionary] = counter_effect.get_attack_interaction_steps(attacker.get_top_card(), card.attacks[1], gsm.game_state) if counter_effect != null else []
	var items: Array = steps[0].get("items", []) if not steps.is_empty() else []
	var used := gsm.use_attack(0, 1, [{TARGET_STEP_ID: [opponent_bench]}])
	gsm.game_state.current_player_index = 0
	gsm.game_state.turn_number = 4
	gsm.game_state.phase = GameState.GamePhase.MAIN
	var locked_next_turn := not gsm.can_use_attack(0, 0) and not gsm.can_use_attack(0, 1)

	return run_checks([
		assert_eq(steps.size(), 1, "Ninetales Dance should expose one target-selection step"),
		assert_eq(int(steps[0].get("min_select", 0)) if not steps.is_empty() else 0, 1, "Ninetales Dance target is mandatory"),
		assert_eq(int(steps[0].get("max_select", 0)) if not steps.is_empty() else 0, 1, "Ninetales Dance selects exactly one target"),
		assert_true(opponent_active in items, "Ninetales Dance should allow the opponent Active Pokemon"),
		assert_true(opponent_bench in items, "Ninetales Dance should allow an opponent Benched Pokemon"),
		assert_true(used, "Ninetales Dance should resolve through GameStateMachine"),
		assert_eq(opponent_active.damage_counters, 0, "The unselected Active Pokemon should not receive counters"),
		assert_eq(opponent_bench.damage_counters, 90, "The selected Pokemon should receive exactly 9 damage counters"),
		assert_true(locked_next_turn, "Ninetales should be unable to use either attack during its next turn"),
	])


func _ninetales() -> CardData:
	var db := CardDatabaseScript.new()
	var card: CardData = db.get_card("CSV4C", "015")
	db.free()
	return card


func _make_state() -> GameState:
	var state := GameState.new()
	state.turn_number = 2
	state.current_player_index = 0
	state.first_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	CardInstance.reset_id_counter()
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	return state


func _make_gsm() -> GameStateMachine:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	return gsm


func _make_slot(card_data: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	slot.turn_played = 0
	return slot


func _pokemon(name: String, hp: int) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.energy_type = "C"
	card.hp = hp
	card.attacks = [{"name": "Tackle", "cost": "C", "damage": "10", "text": "", "is_vstar_power": false}]
	return card


func _energy(energy_type: String, index: int) -> CardData:
	var card := CardData.new()
	card.name = "%s Energy %d" % [energy_type, index]
	card.name_en = card.name
	card.card_type = "Basic Energy"
	card.energy_type = energy_type
	card.energy_provides = energy_type
	return card


func _attach_energy(slot: PokemonSlot, energy_type: String, count: int) -> void:
	for index: int in count:
		slot.attached_energy.append(CardInstance.create(_energy(energy_type, index), 0))
