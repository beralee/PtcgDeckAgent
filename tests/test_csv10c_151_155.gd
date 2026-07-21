class_name TestCSV10C151To155
extends TestBase


func _load_card(index: String) -> CardData:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/CSV10C_%s.json" % index))
	return CardData.from_dict(parsed) if parsed is Dictionary else null


func _pokemon(name: String, energy_type: String = "C", owner: int = 0) -> PokemonSlot:
	var data := CardData.new()
	data.name = name
	data.card_type = "Pokemon"
	data.stage = "Basic"
	data.energy_type = energy_type
	data.hp = 300
	data.attacks.append({"name": "Fixture Attack", "cost": "", "damage": "20", "text": "", "is_vstar_power": false})
	return _slot(data, owner)


func _energy(name: String, energy_type: String, owner: int = 0) -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.card_type = "Basic Energy"
	data.energy_type = energy_type
	data.energy_provides = energy_type
	return CardInstance.create(data, owner)


func _card(name: String, owner: int = 0) -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.card_type = "Item"
	return CardInstance.create(data, owner)


func _slot(card: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner))
	return slot


func _state() -> GameState:
	var state := GameState.new()
	state.turn_number = 18
	state.current_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	for owner: int in 2:
		var player := PlayerState.new()
		player.player_index = owner
		player.active_pokemon = _pokemon("Active %d" % owner, "C", owner)
		state.players.append(player)
	return state


func test_csv10c_151_to_155_registry_contract() -> String:
	var processor := EffectProcessor.new()
	var cards: Dictionary = {}
	for number: int in range(151, 156):
		var index := "%03d" % number
		cards[index] = _load_card(index)
		processor.register_pokemon_card(cards[index])
	return run_checks([
		assert_true(processor.has_attack_effect(cards["151"].effect_id), "CSV10C_151 should register undamaged bonus and attack lock"),
		assert_true(processor.has_attack_effect(cards["152"].effect_id), "CSV10C_152 should register two opposing Pokemon targets"),
		assert_false(processor.has_attack_effect(cards["153"].effect_id), "CSV10C_153 is numeric-only"),
		assert_true(processor.has_attack_effect(cards["154"].effect_id), "CSV10C_154 should register all-attacks lock"),
		assert_true(processor.has_effect(cards["155"].effect_id), "CSV10C_155 should register X Boot"),
	])


func test_csv10c_151_bonus_requires_self_undamaged_and_second_attack_locks_itself() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var mabosstiff := _slot(_load_card("151"))
	state.players[0].active_pokemon = mabosstiff
	processor.register_pokemon_card(mabosstiff.get_card_data())
	var clean_bonus := _damage_bonus(processor, mabosstiff, 0, state)
	mabosstiff.damage_counters = 10
	var damaged_bonus := _damage_bonus(processor, mabosstiff, 0, state)
	processor.execute_attack_effect(mabosstiff, 1, state.players[1].active_pokemon, state)
	var lock: Dictionary = {}
	for entry: Dictionary in mabosstiff.effects:
		if entry.get("type", "") == "attack_lock":
			lock = entry
	return run_checks([
		assert_eq(clean_bonus, 120, "CSV10C_151 should add 120 while undamaged"),
		assert_eq(damaged_bonus, 0, "CSV10C_151 should lose the bonus after taking damage"),
		assert_eq(lock.get("attack_index", -1), 1, "CSV10C_151 should lock only its second attack next own turn"),
	])


func test_csv10c_152_deals_50_to_two_explicitly_selected_opposing_pokemon() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var skarmory := _slot(_load_card("152"))
	state.players[0].active_pokemon = skarmory
	var target_active := state.players[1].active_pokemon
	var first_bench := _pokemon("First Bench", "C", 1)
	var second_bench := _pokemon("Second Bench", "C", 1)
	state.players[1].bench = [first_bench, second_bench]
	processor.register_pokemon_card(skarmory.get_card_data())
	var effect: BaseEffect = processor.get_attack_effects_for_slot(skarmory, 1)[0]
	var steps := effect.get_attack_interaction_steps(skarmory.get_top_card(), skarmory.get_card_data().attacks[1], state)
	processor.execute_attack_effect(skarmory, 1, target_active, state, [{"csv10c_two_opponent_targets": [target_active, second_bench]}])
	var active_after_selected_attack := target_active.damage_counters
	var protected := _slot(_load_card("048"), 1)
	state.players[1].bench = [protected]
	processor.register_pokemon_card(protected.get_card_data())
	processor.execute_attack_effect(skarmory, 1, target_active, state, [{"csv10c_two_opponent_targets": [target_active, protected]}])
	return run_checks([
		assert_eq(steps[0].get("items", []) if not steps.is_empty() else [], [target_active, first_bench, second_bench], "CSV10C_152 should offer opponent Active and Bench"),
		assert_false(bool(steps[0].get("allow_cancel", true)) if not steps.is_empty() else true, "CSV10C_152 UI should require every printed target"),
		assert_eq(active_after_selected_attack, 50, "CSV10C_152 should deal 50 to the selected Active"),
		assert_eq(first_bench.damage_counters, 0, "CSV10C_152 should leave an unselected Bench Pokemon undamaged"),
		assert_eq(second_bench.damage_counters, 50, "CSV10C_152 should deal 50 to the selected Bench Pokemon"),
		assert_eq(protected.damage_counters, 0, "CSV10C_152 should respect opposing Bench damage immunity"),
	])


func test_csv10c_154_locks_all_attacks_during_next_own_turn() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var metang := _slot(_load_card("154"))
	state.players[0].active_pokemon = metang
	processor.register_pokemon_card(metang.get_card_data())
	processor.execute_attack_effect(metang, 0, state.players[1].active_pokemon, state)
	return assert_true(metang.effects.any(func(entry: Dictionary) -> bool: return entry.get("type", "") == "attack_lock_all" and int(entry.get("source_attack_index", -1)) == 0), "CSV10C_154 should record an all-attacks lock from attack 0")


func test_csv10c_155_searches_one_psychic_and_one_metal_energy_and_assigns_only_to_matching_types() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var metagross := _slot(_load_card("155"))
	state.players[0].active_pokemon = metagross
	var psychic_target := _pokemon("Psychic Target", "P")
	var metal_target := _pokemon("Metal Target", "M")
	var dark_target := _pokemon("Dark Target", "D")
	state.players[0].bench = [psychic_target, metal_target, dark_target]
	var psychic := _energy("Psychic Energy", "P")
	var item := _card("Unrelated")
	var metal := _energy("Metal Energy", "M")
	var extra_psychic := _energy("Extra Psychic", "P")
	state.players[0].deck = [psychic, item, metal, extra_psychic]
	processor.register_pokemon_card(metagross.get_card_data())
	var ability := processor.get_effect(metagross.get_card_data().effect_id)
	var steps: Array[Dictionary] = []
	if ability != null:
		steps.assign(ability.get_interaction_steps(metagross.get_top_card(), state))
	var used := processor.execute_ability_effect(metagross, 0, [{"csv10c_x_boot_assignments": [
		{"source": psychic, "target": psychic_target},
		{"source": metal, "target": metal_target},
	]}], state)
	return run_checks([
		assert_true(used, "CSV10C_155 X Boot should be usable with legal Energy and targets"),
		assert_eq(steps[0].get("source_card_indices", []) if not steps.is_empty() else [], [0, -1, 1, 2], "CSV10C_155 should expose the full deck and enable only Basic Psychic/Metal Energy"),
		assert_eq(steps[0].get("target_items", []) if not steps.is_empty() else [], [metagross, psychic_target, metal_target], "CSV10C_155 should enable only own Psychic or Metal Pokemon"),
		assert_eq(steps[0].get("source_bucket_keys", []) if not steps.is_empty() else [], ["P", "M", "P"], "CSV10C_155 UI should group selectable Energy by type"),
		assert_eq(steps[0].get("max_assignments_per_source_bucket", {}) if not steps.is_empty() else {}, {"P": 1, "M": 1}, "CSV10C_155 UI should enforce at most one Energy of each printed type"),
		assert_eq(psychic_target.attached_energy, [psychic], "CSV10C_155 should attach the selected Psychic Energy"),
		assert_eq(metal_target.attached_energy, [metal], "CSV10C_155 should attach the selected Metal Energy"),
		assert_true(item in state.players[0].deck and extra_psychic in state.players[0].deck, "CSV10C_155 should respect the one-per-type quota"),
	])


func _damage_bonus(processor: EffectProcessor, attacker: PokemonSlot, attack_index: int, state: GameState) -> int:
	var total := 0
	for effect: BaseEffect in processor.get_attack_effects_for_slot(attacker, attack_index):
		if effect.has_method("get_damage_bonus"):
			total += int(effect.call("get_damage_bonus", attacker, state))
	return total
