class_name TestCSV95C096BloodmoonUrsaluna
extends TestBase

const BenchEnterAttachScript = preload("res://scripts/effects/pokemon_effects/AbilityAttachBasicEnergyFromHandToSelfOnBenchEnter.gd")
const DamageCounterBonusScript = preload("res://scripts/effects/pokemon_effects/AttackBruteBonnetDamageCounterBonus.gd")
const AILegalActionBuilderScript = preload("res://scripts/ai/AILegalActionBuilder.gd")

const BLOODMOON_EFFECT_ID := "05cf94e1eca743a6f460bb6632cd18e8"


func test_csv95c_096_registers_ability_and_attack_by_effect_id() -> String:
	CardImplementationStatus.clear_cache()
	var processor := EffectProcessor.new()
	var card := _bloodmoon_ursaluna_data()
	var slot := _make_slot(card, 0)

	processor.register_pokemon_card(card)
	var ability_effect := processor.get_effect(BLOODMOON_EFFECT_ID)
	var attack_effects := processor.get_attack_effects_for_slot(slot, 0)
	var ability_is_attach := ability_effect != null and is_instance_of(ability_effect, BenchEnterAttachScript)
	var attack_is_bonus := not attack_effects.is_empty() and is_instance_of(attack_effects[0], DamageCounterBonusScript)

	return run_checks([
		assert_true(ability_is_attach, "CSV9.5C_096 should register Experience Rule by effect_id"),
		assert_true(processor.has_attack_effect(BLOODMOON_EFFECT_ID), "CSV9.5C_096 should register Mad Bite by effect_id"),
		assert_eq(attack_effects.size(), 1, "CSV9.5C_096 Mad Bite should have one damage modifier"),
		assert_true(attack_is_bonus, "CSV9.5C_096 Mad Bite should use the opponent Active damage-counter bonus"),
		assert_false(CardImplementationStatus.is_unimplemented(card), "CSV9.5C_096 should not be marked unimplemented after registration"),
	])


func test_csv95c_096_experience_rule_attaches_up_to_two_basic_fighting_energy_to_self() -> String:
	var gsm := _make_gsm()
	var player := gsm.game_state.players[0]
	var bloodmoon_card := CardInstance.create(_bloodmoon_ursaluna_data(), 0)
	var fighting_a := CardInstance.create(_energy("Fighting A", "F"), 0)
	var fighting_b := CardInstance.create(_energy("Fighting B", "F"), 0)
	var fighting_c := CardInstance.create(_energy("Fighting C", "F"), 0)
	var water := CardInstance.create(_energy("Water", "W"), 0)
	player.hand.append_array([bloodmoon_card, fighting_a, fighting_b, fighting_c, water])
	gsm.effect_processor.register_pokemon_card(bloodmoon_card.card_data)

	var ability_effect := gsm.effect_processor.get_effect(BLOODMOON_EFFECT_ID)
	var preview_steps := ability_effect.get_interaction_steps(bloodmoon_card, gsm.game_state) if ability_effect != null else []
	var played := gsm.play_basic_to_bench(0, bloodmoon_card, false)
	var bloodmoon_slot: PokemonSlot = player.bench.back() if not player.bench.is_empty() else null
	var executed := gsm.effect_processor.execute_ability_effect(bloodmoon_slot, 0, [{
		BenchEnterAttachScript.STEP_ID: [fighting_a, fighting_b, fighting_c, water],
	}], gsm.game_state)

	return run_checks([
		assert_true(played, "CSV9.5C_096 should be playable to the Bench"),
		assert_true(executed, "Experience Rule should execute after this Pokemon enters the Bench from hand"),
		assert_eq(preview_steps.size(), 1, "Experience Rule should ask for hand Energy before bench placement resolves"),
		assert_eq(int(preview_steps[0].get("max_select", 0)), 2, "Experience Rule should select at most 2 Basic Fighting Energy"),
		assert_eq(bloodmoon_slot.attached_energy.size(), 2, "Experience Rule should attach only up to 2 selected Fighting Energy"),
		assert_true(fighting_a in bloodmoon_slot.attached_energy, "Experience Rule should attach the first selected Fighting Energy"),
		assert_true(fighting_b in bloodmoon_slot.attached_energy, "Experience Rule should attach the second selected Fighting Energy"),
		assert_true(fighting_c in player.hand, "Experience Rule should ignore selected Energy beyond the limit"),
		assert_true(water in player.hand, "Experience Rule should ignore non-Fighting Energy"),
	])


func test_csv95c_096_experience_rule_requires_own_turn_bench_enter_from_hand() -> String:
	var effect := BenchEnterAttachScript.new("F", 2)
	var state := _make_state()
	var player := state.players[0]
	var hand_energy := CardInstance.create(_energy("Fighting", "F"), 0)
	player.hand.append(hand_energy)

	var fresh_bench := _make_slot(_bloodmoon_ursaluna_data(), 0)
	fresh_bench.turn_played = state.turn_number
	fresh_bench.mark_entered_bench_from_hand(state.turn_number)
	player.bench.append(fresh_bench)
	var usable_on_own_turn := effect.can_use_ability(fresh_bench, state)

	state.current_player_index = 1
	var usable_on_opponent_turn := effect.can_use_ability(fresh_bench, state)
	state.current_player_index = 0

	var old_bench := _make_slot(_bloodmoon_ursaluna_data(), 0)
	old_bench.turn_played = state.turn_number - 1
	player.bench.append(old_bench)
	var usable_without_entry_marker := effect.can_use_ability(old_bench, state)

	var active_entry := _make_slot(_bloodmoon_ursaluna_data(), 0)
	active_entry.turn_played = state.turn_number
	active_entry.mark_entered_bench_from_hand(state.turn_number)
	player.active_pokemon = active_entry
	var usable_while_active := effect.can_use_ability(active_entry, state)

	return run_checks([
		assert_true(usable_on_own_turn, "Experience Rule should be usable after this Pokemon enters the Bench from hand on its owner's turn"),
		assert_false(usable_on_opponent_turn, "Experience Rule should not be usable on the opponent's turn"),
		assert_false(usable_without_entry_marker, "Experience Rule should require the entered-from-hand marker"),
		assert_false(usable_while_active, "Experience Rule should require the Pokemon to be on the Bench"),
	])


func test_csv95c_096_headless_bench_enter_targets_basic_fighting_energy() -> String:
	var gsm := _make_gsm()
	var player := gsm.game_state.players[0]
	var bloodmoon_card := CardInstance.create(_bloodmoon_ursaluna_data(), 0)
	var fighting_a := CardInstance.create(_energy("Fighting A", "F"), 0)
	var fighting_b := CardInstance.create(_energy("Fighting B", "F"), 0)
	var fighting_c := CardInstance.create(_energy("Fighting C", "F"), 0)
	var water := CardInstance.create(_energy("Water", "W"), 0)
	player.hand.append_array([bloodmoon_card, fighting_a, fighting_b, fighting_c, water])
	gsm.effect_processor.register_pokemon_card(bloodmoon_card.card_data)
	var builder = AILegalActionBuilderScript.new()
	var play_actions := builder.build_actions(gsm, 0, true)
	var play_action_found := false
	for action: Dictionary in play_actions:
		if str(action.get("kind", "")) == "play_basic_to_bench" and action.get("card", null) == bloodmoon_card:
			play_action_found = true
			break
	var effect := gsm.effect_processor.get_effect(BLOODMOON_EFFECT_ID)
	var steps: Array[Dictionary] = effect.get_interaction_steps(bloodmoon_card, gsm.game_state) if effect != null else []
	var targets: Variant = builder._build_headless_targets_from_steps(gsm, 0, 0, steps)
	var context: Dictionary = (targets as Array)[0] if targets is Array and not (targets as Array).is_empty() and (targets as Array)[0] is Dictionary else {}
	var selected: Array = context.get(BenchEnterAttachScript.STEP_ID, [])

	return run_checks([
		assert_true(play_action_found, "AI/headless should enumerate playing CSV9.5C_096 to the Bench"),
		assert_eq(steps.size(), 1, "Experience Rule should expose a bench-enter interaction for headless resolution"),
		assert_eq(selected.size(), 2, "Headless bench-enter selection should choose at most two Energy cards"),
		assert_true(fighting_a in selected, "Headless selection should include the first Basic Fighting Energy"),
		assert_true(fighting_b in selected, "Headless selection should include the second Basic Fighting Energy"),
		assert_false(fighting_c in selected, "Headless selection should not exceed the max Energy count"),
		assert_false(water in selected, "Headless selection should not include non-Fighting Energy"),
	])


func test_csv95c_096_mad_bite_adds_30_per_opponent_active_damage_counter() -> String:
	var gsm := _make_gsm()
	var bloodmoon := _make_slot(_bloodmoon_ursaluna_data(), 0)
	var defender := _make_slot(_pokemon("Damaged Defender", "C", 300), 1)
	defender.damage_counters = 40
	gsm.game_state.players[0].active_pokemon = bloodmoon
	gsm.game_state.players[1].active_pokemon = defender
	_attach_energy(bloodmoon, 0, "F", 2)
	_attach_energy(bloodmoon, 0, "C", 1)
	gsm.effect_processor.register_pokemon_card(bloodmoon.get_card_data())

	var attack := bloodmoon.get_card_data().attacks[0]
	var bonus := gsm.effect_processor.get_attack_damage_modifier(bloodmoon, defender, attack, gsm.game_state, [], 0)
	var used := gsm.use_attack(0, 0)

	return run_checks([
		assert_eq(bonus, 120, "Mad Bite should add 30 damage per damage counter on the opponent Active Pokemon"),
		assert_true(used, "CSV9.5C_096 should be able to use Mad Bite with FFC attached"),
		assert_eq(defender.damage_counters, 260, "Mad Bite should deal 100 + 120, added to the defender's existing 40 damage"),
	])


func _make_gsm() -> GameStateMachine:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
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
		player.active_pokemon = _make_slot(_pokemon("Active%d" % pi, "C", 200), pi)
		state.players.append(player)
	return state


func _bloodmoon_ursaluna_data() -> CardData:
	var cd := _pokemon("Bloodmoon Ursaluna", "F", 150)
	cd.name_en = "Bloodmoon Ursaluna"
	cd.set_code = "CSV9.5C"
	cd.card_index = "096"
	cd.effect_id = BLOODMOON_EFFECT_ID
	cd.retreat_cost = 4
	cd.weakness_energy = "G"
	cd.weakness_value = "x2"
	cd.abilities = [{
		"name": "Experience Rule",
		"text": "When you play this Pokemon from your hand onto your Bench during your turn, you may attach up to 2 Basic Fighting Energy cards from your hand to this Pokemon.",
	}]
	cd.attacks = [{
		"name": "Mad Bite",
		"cost": "FFC",
		"damage": "100+",
		"text": "This attack does 30 more damage for each damage counter on your opponent's Active Pokemon.",
		"is_vstar_power": false,
	}]
	return cd


func _pokemon(name: String, energy_type: String, hp: int) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = "Pokemon"
	cd.stage = "Basic"
	cd.energy_type = energy_type
	cd.hp = hp
	cd.retreat_cost = 1
	cd.attacks = [{"name": "Strike", "cost": "", "damage": "10", "text": "", "is_vstar_power": false}]
	return cd


func _energy(name: String, energy_type: String) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = "Basic Energy"
	cd.energy_type = energy_type
	cd.energy_provides = energy_type
	return cd


func _make_slot(card_data: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	slot.turn_played = 0
	return slot


func _attach_energy(slot: PokemonSlot, owner_index: int, energy_type: String, count: int) -> void:
	for i: int in count:
		slot.attached_energy.append(CardInstance.create(_energy("%s Energy %d" % [energy_type, i], energy_type), owner_index))
