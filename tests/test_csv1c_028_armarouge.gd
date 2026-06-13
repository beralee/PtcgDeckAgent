class_name TestCsv1c028Armarouge
extends TestBase

const CardDatabaseScript = preload("res://scripts/autoload/CardDatabase.gd")
const AbilityMoveFireEnergyFromBenchToActiveScript = preload("res://scripts/effects/pokemon_effects/AbilityMoveFireEnergyFromBenchToActive.gd")


func _make_basic_pokemon_data(name: String, energy_type: String = "C", hp: int = 100) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = "Pokemon"
	cd.stage = "Basic"
	cd.energy_type = energy_type
	cd.hp = hp
	return cd


func _make_energy_data(name: String, energy_type: String, card_type: String = "Basic Energy") -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = card_type
	cd.energy_type = energy_type
	cd.energy_provides = energy_type
	return cd


func _make_slot(card_data: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	slot.turn_played = 0
	return slot


func _make_state(active_card: CardData) -> GameState:
	var state := GameState.new()
	state.turn_number = 2
	state.current_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	CardInstance.reset_id_counter()

	var player := PlayerState.new()
	player.player_index = 0
	player.active_pokemon = _make_slot(active_card, 0)
	player.bench.append(_make_slot(_make_basic_pokemon_data("Bench source A", "R"), 0))
	player.bench.append(_make_slot(_make_basic_pokemon_data("Bench source B", "W"), 0))
	state.players.append(player)

	var opponent := PlayerState.new()
	opponent.player_index = 1
	opponent.active_pokemon = _make_slot(_make_basic_pokemon_data("Opponent active", "W"), 1)
	state.players.append(opponent)

	return state


func _load_armarouge() -> CardData:
	return CardDatabaseScript.new().get_card("CSV1C", "028")


func test_csv1c_028_registers_send_off_fire_and_burn_attack() -> String:
	var card := _load_armarouge()
	var state := _make_state(card)
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(card)
	var attacker := state.players[0].active_pokemon
	var ability := processor.get_ability_effect(attacker, 0, state)
	var attack_effects := processor.get_attack_effects_for_slot(attacker, 0)
	var has_burn_effect := false
	for effect: BaseEffect in attack_effects:
		if effect is EffectApplyStatus and (effect as EffectApplyStatus).status_name == "burned":
			has_burn_effect = true
			break
	return run_checks([
		assert_not_null(card, "CSV1C_028 should load from bundled cards"),
		assert_true(ability != null and ability.get_script() == AbilityMoveFireEnergyFromBenchToActiveScript, "CSV1C_028 should register Send Off Fire as the dedicated Ability effect"),
		assert_true(has_burn_effect, "CSV1C_028 should register burn on Flame Cannon"),
	])


func test_send_off_fire_moves_selected_bench_fire_energy_to_active_repeatedly() -> String:
	var card := _load_armarouge()
	var state := _make_state(card)
	var player: PlayerState = state.players[0]
	var active := player.active_pokemon
	var bench_a := player.bench[0]
	var bench_b := player.bench[1]
	var first_fire := CardInstance.create(_make_energy_data("Basic Fire A", "R"), 0)
	var second_fire := CardInstance.create(_make_energy_data("Basic Fire B", "R"), 0)
	var water := CardInstance.create(_make_energy_data("Basic Water", "W"), 0)
	var active_fire := CardInstance.create(_make_energy_data("Active Fire", "R"), 0)
	bench_a.attached_energy.append(first_fire)
	bench_a.attached_energy.append(second_fire)
	bench_b.attached_energy.append(water)
	active.attached_energy.append(active_fire)

	var processor := EffectProcessor.new()
	processor.register_pokemon_card(card)
	var effect := processor.get_ability_effect(active, 0, state)
	var steps: Array[Dictionary] = effect.get_interaction_steps(active.get_top_card(), state)
	var step_items: Array = steps[0].get("items", []) if not steps.is_empty() else []
	var first_ok := processor.execute_ability_effect(active, 0, [{
		"move_fire_energy_from_bench_to_active": [first_fire],
	}], state)
	var reusable_after_first := processor.can_use_ability(active, state, 0)
	var second_ok := processor.execute_ability_effect(active, 0, [{
		"move_fire_energy_from_bench_to_active": [second_fire],
	}], state)

	return run_checks([
		assert_eq(steps.size(), 1, "Send Off Fire should ask for one attached Fire Energy"),
		assert_true(first_fire in step_items, "Bench Fire Energy should be selectable"),
		assert_true(second_fire in step_items, "A second Bench Fire Energy should also be selectable"),
		assert_false(water in step_items, "Non-Fire Energy should not be selectable"),
		assert_false(active_fire in step_items, "Active Pokemon Energy should not be selectable as a source"),
		assert_true(first_ok, "First Send Off Fire activation should execute"),
		assert_true(reusable_after_first, "Send Off Fire should remain usable when another Bench Fire Energy exists"),
		assert_true(second_ok, "Second Send Off Fire activation in the same turn should execute"),
		assert_true(first_fire in active.attached_energy, "Selected first Fire Energy should move to Active"),
		assert_true(second_fire in active.attached_energy, "Selected second Fire Energy should move to Active"),
		assert_false(first_fire in bench_a.attached_energy, "Moved first Fire Energy should leave the source Bench Pokemon"),
		assert_false(second_fire in bench_a.attached_energy, "Moved second Fire Energy should leave the source Bench Pokemon"),
		assert_true(water in bench_b.attached_energy, "Other Energy should stay attached"),
	])


func test_flame_cannon_burns_opponent_active() -> String:
	var card := _load_armarouge()
	var state := _make_state(card)
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(card)
	var attacker := state.players[0].active_pokemon
	var defender := state.players[1].active_pokemon
	processor.execute_attack_effect(attacker, 0, defender, state, [])
	return run_checks([
		assert_true(defender.status_conditions.get("burned", false), "Flame Cannon should burn the opponent's Active Pokemon"),
	])
