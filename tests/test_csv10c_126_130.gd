class_name TestCSV10C126To130
extends TestBase

const H = preload("res://scripts/effects/CSV9CHelpers.gd")


func _load_card(index: String) -> CardData:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/CSV10C_%s.json" % index))
	return CardData.from_dict(parsed) if parsed is Dictionary else null


func _pokemon(name: String, stage: String = "Basic", energy_type: String = "C") -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Pokemon"
	card.stage = stage
	card.energy_type = energy_type
	card.hp = 300
	card.attacks = [{"name": "Fixture Attack", "cost": "C", "damage": "20", "text": "", "is_vstar_power": false}]
	return card


func _non_pokemon(name: String, card_type: String, energy_provides: String = "") -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = card_type
	card.energy_provides = energy_provides
	return card


func _slot(card: CardData, owner: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner))
	slot.turn_played = 0
	return slot


func _state() -> GameState:
	var state := GameState.new()
	state.turn_number = 8
	state.current_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	for owner: int in 2:
		var player := PlayerState.new()
		player.player_index = owner
		player.active_pokemon = _slot(_pokemon("Active %d" % owner), owner)
		state.players.append(player)
	return state


func test_csv10c_126_to_130_registry_contract() -> String:
	var processor := EffectProcessor.new()
	var cards: Dictionary = {}
	for number: int in range(126, 131):
		var index := "%03d" % number
		cards[index] = _load_card(index)
		processor.register_pokemon_card(cards[index])
	return run_checks([
		assert_true(processor.has_attack_effect(cards["126"].effect_id), "CSV10C_126 should register the damaged-defender bonus"),
		assert_true(processor.has_attack_effect(cards["127"].effect_id), "CSV10C_127 should register severe Poison"),
		assert_true(processor.has_attack_effect(cards["128"].effect_id), "CSV10C_128 should register Poison"),
		assert_true(processor.has_effect(cards["129"].effect_id), "CSV10C_129 should register its evolve-triggered Ability"),
		assert_true(processor.has_attack_effect(cards["129"].effect_id), "CSV10C_129 should register Confusion"),
		assert_true(processor.has_effect(cards["130"].effect_id), "CSV10C_130 should register its evolve-triggered Ability"),
		assert_true(processor.has_attack_effect(cards["130"].effect_id), "CSV10C_130 should register its optional return effect"),
	])


func test_csv10c_126_bonus_requires_damage_on_defender() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var attacker := _slot(_load_card("126"))
	state.players[0].active_pokemon = attacker
	processor.register_pokemon_card(attacker.get_card_data())
	var bonus_clean := 0
	for effect: BaseEffect in processor.get_attack_effects_for_slot(attacker, 1):
		if effect.has_method("get_damage_bonus"):
			bonus_clean += int(effect.call("get_damage_bonus", attacker, state))
	state.players[1].active_pokemon.damage_counters = 10
	var bonus_damaged := 0
	for effect: BaseEffect in processor.get_attack_effects_for_slot(attacker, 1):
		if effect.has_method("get_damage_bonus"):
			bonus_damaged += int(effect.call("get_damage_bonus", attacker, state))
	return run_checks([
		assert_eq(bonus_clean, 0, "CSV10C_126 should not add damage against an undamaged defender"),
		assert_eq(bonus_damaged, 60, "CSV10C_126 should add 60 against a damaged defender"),
	])


func test_csv10c_127_severe_poison_places_eight_counters_and_128_poison_is_normal() -> String:
	var severe_state := _state()
	var severe_processor := EffectProcessor.new()
	var nidoking := _slot(_load_card("127"))
	severe_state.players[0].active_pokemon = nidoking
	severe_processor.register_pokemon_card(nidoking.get_card_data())
	severe_processor.execute_attack_effect(nidoking, 0, severe_state.players[1].active_pokemon, severe_state)
	severe_processor.process_pokemon_check(severe_state)

	var normal_state := _state()
	var normal_processor := EffectProcessor.new()
	var zubat := _slot(_load_card("128"))
	normal_state.players[0].active_pokemon = zubat
	normal_processor.register_pokemon_card(zubat.get_card_data())
	normal_processor.execute_attack_effect(zubat, 0, normal_state.players[1].active_pokemon, normal_state)
	normal_processor.process_pokemon_check(normal_state)
	return run_checks([
		assert_true(severe_state.players[1].active_pokemon.status_conditions.get("poisoned", false), "CSV10C_127 should Poison the defender"),
		assert_eq(severe_state.players[1].active_pokemon.damage_counters, 80, "CSV10C_127 Poison should place 8 damage counters at Pokemon Check"),
		assert_true(normal_state.players[1].active_pokemon.status_conditions.get("poisoned", false), "CSV10C_128 should Poison the defender"),
		assert_eq(normal_state.players[1].active_pokemon.damage_counters, 10, "CSV10C_128 Poison should place the normal 1 damage counter"),
	])


func test_csv10c_129_evolve_bite_targets_one_and_attack_confuses() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var golbat := _slot(_load_card("129"))
	golbat.turn_evolved = state.turn_number
	H.mark_evolved_from_hand(golbat, state)
	state.players[0].active_pokemon = golbat
	var bench_target := _slot(_pokemon("Opponent Bench"), 1)
	state.players[1].bench = [bench_target]
	processor.register_pokemon_card(golbat.get_card_data())
	var used := processor.execute_ability_effect(golbat, 0, [{"csv10c_evolve_damage_targets": [bench_target]}], state)
	processor.execute_attack_effect(golbat, 0, state.players[1].active_pokemon, state)
	var declined_golbat := _slot(_load_card("129"))
	declined_golbat.turn_evolved = state.turn_number
	H.mark_evolved_from_hand(declined_golbat, state)
	state.players[0].active_pokemon = declined_golbat
	processor.execute_ability_effect(declined_golbat, 0, [{"csv10c_evolve_damage_targets": []}], state)
	return run_checks([
		assert_true(used, "CSV10C_129 evolve-triggered Ability should be usable after evolving from hand"),
		assert_eq(bench_target.damage_counters, 20, "CSV10C_129 should place 2 counters on the selected opposing Pokemon"),
		assert_eq(state.players[1].active_pokemon.damage_counters, 0, "CSV10C_129 should honor the explicit target"),
		assert_true(state.players[1].active_pokemon.status_conditions.get("confused", false), "CSV10C_129 attack should Confuse the defender"),
		assert_false(processor.can_use_ability(declined_golbat, state, 0), "CSV10C_129 should consume its evolution trigger even when the player declines to place counters"),
	])


func test_csv10c_130_bites_two_then_optionally_returns_only_pokemon_cards_to_hand() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var crobat := _slot(_load_card("130"))
	var base := CardInstance.create(_pokemon("火箭队的大嘴蝠", "Stage 1", "D"), 0)
	crobat.pokemon_stack.push_front(base)
	crobat.turn_evolved = state.turn_number
	H.mark_evolved_from_hand(crobat, state)
	state.players[0].active_pokemon = crobat
	var replacement := _slot(_pokemon("Replacement"))
	state.players[0].bench = [replacement]
	var target_active := state.players[1].active_pokemon
	var target_bench := _slot(_pokemon("Opponent Bench"), 1)
	state.players[1].bench = [target_bench]
	var energy := CardInstance.create(_non_pokemon("Darkness Energy", "Basic Energy", "D"), 0)
	var tool := CardInstance.create(_non_pokemon("Fixture Tool", "Tool"), 0)
	crobat.attached_energy = [energy]
	crobat.attached_tool = tool
	processor.register_pokemon_card(crobat.get_card_data())
	var used := processor.execute_ability_effect(crobat, 0, [{"csv10c_evolve_damage_targets": [target_active, target_bench]}], state)
	processor.execute_attack_effect(crobat, 0, target_active, state, [{"csv10c_crobat_return_choice": [replacement]}])
	return run_checks([
		assert_true(used, "CSV10C_130 evolve-triggered Ability should resolve"),
		assert_eq(target_active.damage_counters, 20, "CSV10C_130 should place 2 counters on the first selected target"),
		assert_eq(target_bench.damage_counters, 20, "CSV10C_130 should place 2 counters on the second selected target"),
		assert_eq(state.players[0].active_pokemon, replacement, "CSV10C_130 should promote the selected replacement when returned from Active"),
		assert_true(base in state.players[0].hand and crobat.get_top_card() == null, "CSV10C_130 should return every Pokemon card in its stack to hand"),
		assert_true(energy in state.players[0].discard_pile and tool in state.players[0].discard_pile, "CSV10C_130 should discard attached non-Pokemon cards"),
	])
