class_name TestMiraidon165CardEffects
extends TestBase


func _make_state() -> GameState:
	var state := GameState.new()
	state.turn_number = 2
	state.current_player_index = 0
	state.first_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	CardInstance.reset_id_counter()
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		state.players.append(player)
	return state


func _make_slot(card_data: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	return slot


func _make_basic_lightning_attacker() -> CardData:
	var cd := CardData.new()
	cd.name = "Basic Lightning Attacker"
	cd.name_en = "Basic Lightning Attacker"
	cd.card_type = "Pokemon"
	cd.stage = "Basic"
	cd.hp = 120
	cd.energy_type = "L"
	cd.attacks = [{"name": "Strike", "cost": "L", "damage": "50", "text": "", "is_vstar_power": false}]
	return cd


func _make_basic_pokemon_data(name: String, energy_type: String, hp: int = 120) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = "Pokemon"
	cd.stage = "Basic"
	cd.hp = hp
	cd.energy_type = energy_type
	cd.attacks = [{"name": "Strike", "cost": "C", "damage": "10", "text": "", "is_vstar_power": false}]
	return cd


func _make_energy_data(name: String, energy_type: String, card_type: String = "Basic Energy") -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = card_type
	cd.energy_provides = energy_type
	cd.energy_type = energy_type
	return cd


func _has_attack_effect_script(
	processor: EffectProcessor,
	slot: PokemonSlot,
	attack_index: int,
	script_file_name: String
) -> bool:
	for effect: BaseEffect in processor.get_attack_effects_for_slot(slot, attack_index):
		var script: Script = effect.get_script()
		if script != null and str(script.resource_path).get_file() == script_file_name:
			return true
	return false


func test_miraidon_165_new_cards_register_native_effects() -> String:
	var magneton := CardDatabase.get_card("CBB5C", "0301")
	var magnemite := CardDatabase.get_card("CSV1C", "042")
	var zapdos := CardDatabase.get_card("CS6aC", "057")
	if magneton == null or magnemite == null or zapdos == null:
		return "Miraidon 16.5 cached card fixtures are missing"

	var processor := EffectProcessor.new()
	processor.register_pokemon_card(magneton)
	processor.register_pokemon_card(magnemite)
	processor.register_pokemon_card(zapdos)

	var magnemite_slot := _make_slot(magnemite, 0)
	var zapdos_slot := _make_slot(zapdos, 0)

	return run_checks([
		assert_true(processor.get_effect(magneton.effect_id) is AbilityOvervoltDischarge, "CBB5C_0301 Magneton should register Overvolt Discharge"),
		assert_true(_has_attack_effect_script(processor, magnemite_slot, 0, "AttackSwitchSelfToBench.gd"), "CSV1C_042 Magnemite should register the first attack self-switch"),
		assert_false(_has_attack_effect_script(processor, magnemite_slot, 1, "AttackSwitchSelfToBench.gd"), "CSV1C_042 Magnemite second attack should not inherit the switch effect"),
		assert_true(processor.get_effect(zapdos.effect_id) is AbilityLightningBoost, "CS6aC_057 Zapdos should register Electric Symbol"),
		assert_eq(magneton.name, "三合一磁怪", "CBB5C_0301 bundled card fixture should load the imported card name"),
		assert_eq(magnemite_slot.get_pokemon_name(), "小磁怪", "CSV1C_042 bundled card fixture should load the imported card name"),
		assert_eq(zapdos_slot.get_pokemon_name(), "闪电鸟", "CS6aC_057 Zapdos fixture should load the bundled card name"),
	])


func test_cbb5c_0301_overvolt_discharge_self_kos_and_attaches_basic_energy() -> String:
	var magneton := CardDatabase.get_card("CBB5C", "0301")
	if magneton == null:
		return "CBB5C_0301 Magneton cached fixture is missing"

	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	player.active_pokemon = _make_slot(_make_basic_lightning_attacker(), 0)
	var magneton_slot := _make_slot(magneton, 0)
	var magneton_card := magneton_slot.get_top_card()
	player.bench.append(magneton_slot)
	player.bench.append(_make_slot(_make_basic_pokemon_data("Colorless Bench", "C"), 0))
	opponent.active_pokemon = _make_slot(_make_basic_pokemon_data("Opponent Active", "C"), 1)
	for i: int in 2:
		player.prizes.append(CardInstance.create(_make_basic_pokemon_data("Player Prize %d" % i, "C"), 0))
		opponent.prizes.append(CardInstance.create(_make_basic_pokemon_data("Opponent Prize %d" % i, "C"), 1))

	var lightning := CardInstance.create(_make_energy_data("Lightning Energy", "L"), 0)
	var fighting := CardInstance.create(_make_energy_data("Fighting Energy", "F"), 0)
	var special := CardInstance.create(_make_energy_data("Double Turbo Energy", "C", "Special Energy"), 0)
	player.discard_pile.append_array([lightning, fighting, special])
	gsm.effect_processor.register_pokemon_card(magneton)

	var effect: BaseEffect = gsm.effect_processor.get_effect(magneton.effect_id)
	var steps: Array[Dictionary] = effect.get_interaction_steps(magneton_card, state)
	var used := gsm.use_ability(0, magneton_slot, 0, [{
		AbilityOvervoltDischarge.SELECT_ASSIGNMENTS_ID: [
			{"source": lightning, "target": player.active_pokemon},
			{"source": fighting, "target": player.active_pokemon},
		],
	}])
	var prize_resolved := gsm.resolve_take_prize(1, 0)

	return run_checks([
		assert_eq(steps.size(), 1, "Overvolt Discharge should expose one card-assignment step"),
		assert_eq(str(steps[0].get("ui_mode", "")), "card_assignment", "Overvolt Discharge should use assignment UI"),
		assert_true(used, "Overvolt Discharge should be usable with Basic Energy in discard and Lightning targets"),
		assert_true(prize_resolved, "Magneton's self-KO should require the opponent to take one prize"),
		assert_contains(player.active_pokemon.attached_energy, lightning, "Overvolt Discharge should attach selected Lightning Energy from discard"),
		assert_contains(player.active_pokemon.attached_energy, fighting, "Overvolt Discharge should attach selected off-type Basic Energy from discard"),
		assert_contains(player.discard_pile, special, "Overvolt Discharge should not attach Special Energy"),
		assert_false(magneton_slot in player.bench, "Overvolt Discharge should Knock Out and remove Magneton from the Bench"),
		assert_contains(player.discard_pile, magneton_card, "Knocked Out Magneton should move to its owner's discard pile"),
		assert_eq(state.phase, GameState.GamePhase.MAIN, "After self-KO prize resolution, the same turn should resume in MAIN"),
	])


func test_csv1c_042_magnemite_first_attack_switches_with_bench() -> String:
	var magnemite := CardDatabase.get_card("CSV1C", "042")
	if magnemite == null:
		return "CSV1C_042 Magnemite cached fixture is missing"

	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	var active := _make_slot(magnemite, 0)
	var pivot := _make_slot(_make_basic_lightning_attacker(), 0)
	active.attached_energy.append(CardInstance.create(_make_energy_data("Lightning Energy", "L"), 0))
	player.active_pokemon = active
	player.bench.append(pivot)
	opponent.active_pokemon = _make_slot(_make_basic_pokemon_data("Opponent Active", "C"), 1)
	gsm.effect_processor.register_pokemon_card(magnemite)

	var attacked := gsm.use_attack(0, 0, [{"switch_target": [pivot]}])

	return run_checks([
		assert_true(attacked, "Magnemite should be able to use the Colorless-cost switch attack"),
		assert_eq(player.active_pokemon, pivot, "Magnemite's first attack should promote the selected Bench Pokemon"),
		assert_contains(player.bench, active, "Magnemite should move to the Bench after the attack"),
	])


func test_zapdos_electric_symbol_does_not_boost_zapdos_attacker() -> String:
	var zapdos := CardDatabase.get_card("CS6aC", "057")
	if zapdos == null:
		return "CS6aC_057 Zapdos cached fixture is missing"

	var processor := EffectProcessor.new()
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.active_pokemon = _make_slot(zapdos, 0)
	player.bench.append(_make_slot(zapdos, 0))
	var zapdos_self_bonus: int = processor.get_attacker_modifier(player.active_pokemon, state)

	player.active_pokemon = _make_slot(_make_basic_lightning_attacker(), 0)
	player.bench.clear()
	player.bench.append(_make_slot(zapdos, 0))
	var other_basic_lightning_bonus: int = processor.get_attacker_modifier(player.active_pokemon, state)

	return run_checks([
		assert_eq(zapdos_self_bonus, 0, "Electric Symbol should not boost Zapdos attacks"),
		assert_eq(other_basic_lightning_bonus, 10, "Electric Symbol should still boost other Basic Lightning attackers"),
	])
