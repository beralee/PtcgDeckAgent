class_name TestCSV5C053054CSV9C072Cards
extends TestBase


class RiggedCoinFlipper extends CoinFlipper:
	var _results: Array[bool] = []
	var flip_count: int = 0

	func _init(results: Array[bool]) -> void:
		_results = results.duplicate()

	func flip() -> bool:
		flip_count += 1
		var result := false
		if not _results.is_empty():
			result = _results.pop_front()
		coin_flipped.emit(result)
		return result


func test_csv5c_053_natu_three_coin_damage_uses_shared_flipper() -> String:
	var flipper := RiggedCoinFlipper.new([true, false, true])
	var gsm := _make_gsm(flipper)
	var natu := _pokemon(
		"CSV5C_053 Natu",
		"2317be04afe1bd94899a29fe09b84d96",
		[_attack("Triple Stab", "P", "10×", "Flip 3 coins. This attack does 10 damage for each heads.")],
		[],
		"P",
		50
	)
	var slots := _setup_battle(gsm, natu, _basic_target())
	_attach_energy(slots[0], 0, "P", 1)
	var used := gsm.use_attack(0, 0)

	var zero_flipper := RiggedCoinFlipper.new([false, false, false])
	var zero_gsm := _make_gsm(zero_flipper)
	var zero_slots := _setup_battle(zero_gsm, natu, _basic_target())
	_attach_energy(zero_slots[0], 0, "P", 1)
	var zero_used := zero_gsm.use_attack(0, 0)

	return run_checks([
		assert_true(used, "CSV5C_053 should be able to attack with one Psychic Energy"),
		assert_eq(flipper.flip_count, 3, "CSV5C_053 Triple Stab should flip exactly three coins"),
		assert_eq(slots[1].damage_counters, 20, "CSV5C_053 should deal 20 damage for two heads"),
		assert_true(zero_used, "CSV5C_053 should still resolve on zero heads"),
		assert_eq(zero_flipper.flip_count, 3, "CSV5C_053 zero-heads path should still flip three coins"),
		assert_eq(zero_slots[1].damage_counters, 0, "CSV5C_053 should deal 0 damage for zero heads despite printed 10x text"),
	])


func test_csv5c_054_xatu_clairvoyant_sense_attaches_to_own_bench_and_draws_two() -> String:
	var state := _make_state()
	var processor := EffectProcessor.new()
	var xatu_cd := _pokemon(
		"CSV5C_054 Xatu",
		"bcd9644ea935ce567829f4a76756059b",
		[_attack("Super Psy Bolt", "PCC", "80")],
		[{"name": "Clairvoyant Sense", "text": "Attach a Basic Psychic Energy from hand to a Benched Pokemon. Draw 2 cards."}],
		"P",
		100,
		"Stage 1"
	)
	processor.register_pokemon_card(xatu_cd)
	var player := state.players[0]
	var xatu := _make_slot(xatu_cd, 0)
	player.active_pokemon = xatu
	var bench := _make_slot(_basic_target("Own Bench"), 0)
	player.bench.append(bench)
	var psychic := CardInstance.create(_energy("Basic Psychic Energy", "P"), 0)
	var water := CardInstance.create(_energy("Basic Water Energy", "W"), 0)
	var special_psychic := CardInstance.create(_energy("Special Psychic Energy", "P", "Special Energy"), 0)
	var draw_a := CardInstance.create(_trainer("Draw A", "Item", ""), 0)
	var draw_b := CardInstance.create(_trainer("Draw B", "Item", ""), 0)
	player.hand.append_array([psychic, water, special_psychic])
	player.deck.append_array([draw_a, draw_b])

	var effect := processor.get_effect("bcd9644ea935ce567829f4a76756059b")
	var steps: Array[Dictionary] = effect.get_interaction_steps(xatu.get_top_card(), state) if effect != null else []
	var step: Dictionary = steps[0] if not steps.is_empty() else {}
	var source_items: Array = step.get("source_items", [])
	var target_items: Array = step.get("target_items", [])
	var executed := processor.execute_ability_effect(xatu, 0, [{
		"attach_basic_energy_from_hand_to_bench": [{"source": psychic, "target": bench}]
	}], state)
	var can_use_again := processor.can_use_ability(xatu, state, 0)

	return run_checks([
		assert_true(processor.has_effect("bcd9644ea935ce567829f4a76756059b"), "CSV5C_054 should register a native Ability effect"),
		assert_eq(steps.size(), 1, "CSV5C_054 should expose one assignment interaction"),
		assert_eq(str(step.get("ui_mode", "")), "card_assignment", "CSV5C_054 should use the shared assignment UI"),
		assert_true(psychic in source_items, "CSV5C_054 source list should include Basic Psychic Energy"),
		assert_false(water in source_items, "CSV5C_054 source list should exclude non-Psychic Basic Energy"),
		assert_false(special_psychic in source_items, "CSV5C_054 source list should exclude Special Energy"),
		assert_true(bench in target_items, "CSV5C_054 target list should include own Bench Pokemon"),
		assert_false(xatu in target_items, "CSV5C_054 target list should not include the Active Pokemon"),
		assert_true(executed, "CSV5C_054 Ability should execute through EffectProcessor"),
		assert_false(psychic in player.hand, "CSV5C_054 should remove the selected Psychic Energy from hand"),
		assert_true(psychic in bench.attached_energy, "CSV5C_054 should attach the selected Psychic Energy to the chosen Bench Pokemon"),
		assert_true(draw_a in player.hand and draw_b in player.hand, "CSV5C_054 should draw two cards after attaching"),
		assert_false(can_use_again, "CSV5C_054 should be once during your turn"),
	])


func test_csv5c_054_xatu_rejects_invalid_explicit_assignment_without_side_effects() -> String:
	var state := _make_state()
	var processor := EffectProcessor.new()
	var xatu_cd := _pokemon(
		"CSV5C_054 Xatu",
		"bcd9644ea935ce567829f4a76756059b",
		[_attack("Super Psy Bolt", "PCC", "80")],
		[{"name": "Clairvoyant Sense", "text": ""}],
		"P",
		100,
		"Stage 1"
	)
	processor.register_pokemon_card(xatu_cd)
	var player := state.players[0]
	var xatu := _make_slot(xatu_cd, 0)
	player.active_pokemon = xatu
	player.bench.append(_make_slot(_basic_target("Own Bench"), 0))
	var psychic := CardInstance.create(_energy("Basic Psychic Energy", "P"), 0)
	var draw_a := CardInstance.create(_trainer("Draw A", "Item", ""), 0)
	var draw_b := CardInstance.create(_trainer("Draw B", "Item", ""), 0)
	player.hand.append(psychic)
	player.deck.append_array([draw_a, draw_b])

	processor.execute_ability_effect(xatu, 0, [{
		"attach_basic_energy_from_hand_to_bench": [{"source": psychic, "target": xatu}]
	}], state)

	return run_checks([
		assert_true(psychic in player.hand, "CSV5C_054 should reject Active Pokemon as an explicit attachment target"),
		assert_false(psychic in xatu.attached_energy, "CSV5C_054 should not attach to Active Pokemon"),
		assert_false(draw_a in player.hand or draw_b in player.hand, "CSV5C_054 should not draw when explicit assignment is invalid"),
		assert_false(xatu.has_ability_used(state.turn_number), "CSV5C_054 should not mark the Ability used on invalid explicit assignment"),
	])


func test_csv9c_072_slowking_source_effect_id_alias_copies_top_deck_attack() -> String:
	var state := _make_state()
	var processor := EffectProcessor.new()
	var slowking_cd := _pokemon(
		"CSV9C_072 Slowking",
		"59d3af627f14b4a65ab4d589f6cb52db",
		[_attack("Inspiration Challenge", "PC", ""), _attack("Super Psy Bolt", "PPC", "120")],
		[],
		"P",
		120,
		"Stage 1"
	)
	processor.register_pokemon_card(slowking_cd)
	var slowking := _make_slot(slowking_cd, 0)
	state.players[0].active_pokemon = slowking
	var copied_cd := _pokemon("Copied Basic", "copy_target", [_attack("Copied Hit", "C", "50")], [], "C", 80)
	var top_card := CardInstance.create(copied_cd, 0)
	state.players[0].deck.append(top_card)

	processor.execute_attack_effect(slowking, 0, state.players[1].active_pokemon, state)

	return run_checks([
		assert_true(processor.has_attack_effect("59d3af627f14b4a65ab4d589f6cb52db"), "CSV9C_072 source effect id should register an attack effect"),
		assert_true(top_card in state.players[0].discard_pile, "CSV9C_072 should discard the top deck Pokemon before copying"),
		assert_eq(state.players[1].active_pokemon.damage_counters, 50, "CSV9C_072 should copy and deal the top Pokemon attack damage"),
	])


func test_csv9c_072_slowking_reveals_single_attack_top_pokemon_in_action_hud() -> String:
	var state := _make_state()
	var processor := EffectProcessor.new()
	var slowking_cd := _pokemon(
		"CSV9C_072 Slowking",
		"79cbb7699c0e663c135524afe4e1cb14",
		[_attack("Inspiration Challenge", "PC", ""), _attack("Super Psy Bolt", "PPC", "120")],
		[],
		"P",
		120,
		"Stage 1"
	)
	processor.register_pokemon_card(slowking_cd)
	var slowking := _make_slot(slowking_cd, 0)
	state.players[0].active_pokemon = slowking
	var kyurem_cd := _pokemon(
		"Kyurem",
		"5ed7ff97aa96afb6a023ad8ce6636eba",
		[_attack("Trifrost", "WWMMC", "", "Discard all Energy from this Pokemon. This attack does 110 damage to 3 of your opponent's Pokemon.")],
		[],
		"N",
		130
	)
	var kyurem_card := CardInstance.create(kyurem_cd, 0)
	state.players[0].deck.append(kyurem_card)

	var steps: Array[Dictionary] = []
	for effect: BaseEffect in processor.get_attack_effects_for_slot(slowking, 0):
		steps.append_array(effect.get_attack_interaction_steps(slowking.get_top_card(), slowking_cd.attacks[0], state))
	var step: Dictionary = steps[0] if not steps.is_empty() else {}
	var items: Array = step.get("items", [])
	var first_item: Dictionary = items[0] if not items.is_empty() and items[0] is Dictionary else {}
	var card_items: Array = step.get("card_items", [])
	var action_items: Array = step.get("action_items", [])
	var first_action: Dictionary = action_items[0] if not action_items.is_empty() and action_items[0] is Dictionary else {}

	return run_checks([
		assert_eq(steps.size(), 1, "Slowking should prompt even when the revealed Pokemon has only one attack"),
		assert_eq(str(step.get("id", "")), "csv9c_slowking_copied_attack", "Slowking should use its copied attack interaction step"),
		assert_eq(str(step.get("presentation", "")), "action_hud", "Slowking copied attack should use the Regidrago-style action HUD"),
		assert_true(kyurem_card in card_items, "Slowking prompt should expose the revealed top-deck Pokemon card to the UI"),
		assert_eq(first_item.get("source_card", null), kyurem_card, "Slowking copied attack option should keep the revealed source card"),
		assert_eq(int(first_item.get("attack_index", -1)), 0, "Slowking copied attack option should point at Kyurem's attack"),
		assert_eq(str((first_item.get("attack", {}) as Dictionary).get("name", "")), "Trifrost", "Slowking prompt should name the copied attack"),
		assert_eq(str(first_action.get("title", "")), "Trifrost", "Slowking action HUD should show the copied attack name"),
		assert_true(str(first_action.get("meta", "")).contains("Kyurem"), "Slowking action HUD should show the revealed Pokemon name"),
	])


func test_csv9c_072_slowking_injects_copied_kyurem_target_followup() -> String:
	var state := _make_state()
	var processor := EffectProcessor.new()
	var slowking_cd := _pokemon(
		"CSV9C_072 Slowking",
		"79cbb7699c0e663c135524afe4e1cb14",
		[_attack("Inspiration Challenge", "PC", ""), _attack("Super Psy Bolt", "PPC", "120")],
		[],
		"P",
		120,
		"Stage 1"
	)
	var kyurem_cd := _pokemon(
		"Kyurem",
		"5ed7ff97aa96afb6a023ad8ce6636eba",
		[_attack("Trifrost", "WWMMC", "", "Discard all Energy from this Pokemon. This attack does 110 damage to 3 of your opponent's Pokemon.")],
		[],
		"N",
		130
	)
	processor.register_pokemon_card(slowking_cd)
	processor.register_pokemon_card(kyurem_cd)
	var slowking := _make_slot(slowking_cd, 0)
	state.players[0].active_pokemon = slowking
	var kyurem_card := CardInstance.create(kyurem_cd, 0)
	state.players[0].deck.append(kyurem_card)
	state.players[1].bench.append(_make_slot(_basic_target("Bench A"), 1))
	state.players[1].bench.append(_make_slot(_basic_target("Bench B"), 1))

	var slowking_effect: BaseEffect = null
	for effect: BaseEffect in processor.get_attack_effects_for_slot(slowking, 0):
		if effect.has_method("get_followup_attack_interaction_steps"):
			slowking_effect = effect
			break
	var initial_steps := slowking_effect.get_attack_interaction_steps(slowking.get_top_card(), slowking_cd.attacks[0], state) if slowking_effect != null else []
	var copied_option: Dictionary = initial_steps[0].get("items", [])[0] if not initial_steps.is_empty() and not (initial_steps[0].get("items", []) as Array).is_empty() else {}
	var followup_steps: Array[Dictionary] = slowking_effect.get_followup_attack_interaction_steps(
		slowking.get_top_card(),
		slowking_cd.attacks[0],
		state,
		{"csv9c_slowking_copied_attack": [copied_option]}
	) if slowking_effect != null else []
	var followup: Dictionary = followup_steps[0] if not followup_steps.is_empty() else {}

	return run_checks([
		assert_eq(followup_steps.size(), 1, "Slowking should inject the copied attack's follow-up target selection"),
		assert_eq(str(followup.get("id", "")), "csv9c_tri_frost_targets", "Slowking should reuse Kyurem Trifrost's target step"),
		assert_eq((followup.get("items", []) as Array).size(), 3, "Slowking copied Kyurem should let the player choose three opposing Pokemon"),
	])


func test_csv9c_072_slowking_copied_kyurem_uses_selected_targets() -> String:
	var state := _make_state()
	var processor := EffectProcessor.new()
	var slowking_cd := _pokemon(
		"CSV9C_072 Slowking",
		"79cbb7699c0e663c135524afe4e1cb14",
		[_attack("Inspiration Challenge", "PC", ""), _attack("Super Psy Bolt", "PPC", "120")],
		[],
		"P",
		120,
		"Stage 1"
	)
	var kyurem_cd := _pokemon(
		"Kyurem",
		"5ed7ff97aa96afb6a023ad8ce6636eba",
		[_attack("Trifrost", "WWMMC", "", "Discard all Energy from this Pokemon. This attack does 110 damage to 3 of your opponent's Pokemon.")],
		[],
		"N",
		130
	)
	processor.register_pokemon_card(slowking_cd)
	processor.register_pokemon_card(kyurem_cd)
	var slowking := _make_slot(slowking_cd, 0)
	state.players[0].active_pokemon = slowking
	var slowking_energy := _attach_energy(slowking, 0, "P", 2)
	var kyurem_card := CardInstance.create(kyurem_cd, 0)
	state.players[0].deck.append(kyurem_card)
	var bench_a := _make_slot(_basic_target("Bench A"), 1)
	var bench_b := _make_slot(_basic_target("Bench B"), 1)
	state.players[1].bench.append_array([bench_a, bench_b])

	processor.execute_attack_effect(slowking, 0, state.players[1].active_pokemon, state, [{
		"csv9c_slowking_copied_attack": [{
			"source_card": kyurem_card,
			"attack_index": 0,
			"attack": kyurem_cd.attacks[0],
		}],
		"csv9c_tri_frost_targets": [state.players[1].active_pokemon, bench_a, bench_b],
	}])

	return run_checks([
		assert_true(kyurem_card in state.players[0].discard_pile, "Slowking should discard the revealed Kyurem"),
		assert_eq(slowking.attached_energy.size(), 0, "Copied Kyurem Trifrost should discard all Energy from Slowking"),
		assert_true(slowking_energy[0] in state.players[0].discard_pile and slowking_energy[1] in state.players[0].discard_pile, "Slowking's discarded Energy should enter discard"),
		assert_eq(state.players[1].active_pokemon.damage_counters, 110, "Copied Kyurem should damage the selected Active Pokemon"),
		assert_eq(bench_a.damage_counters, 110, "Copied Kyurem should damage the first selected Bench Pokemon"),
		assert_eq(bench_b.damage_counters, 110, "Copied Kyurem should damage the second selected Bench Pokemon"),
	])


func test_csv9c_072_slowking_copied_attack_preserves_weakness_resistance_flags() -> String:
	var state := _make_state()
	var processor := EffectProcessor.new()
	var slowking_cd := _pokemon(
		"CSV9C_072 Slowking",
		"59d3af627f14b4a65ab4d589f6cb52db",
		[_attack("Inspiration Challenge", "PC", ""), _attack("Super Psy Bolt", "PPC", "120")],
		[],
		"P",
		120,
		"Stage 1"
	)
	processor.register_pokemon_card(slowking_cd)
	var slowking := _make_slot(slowking_cd, 0)
	state.players[0].active_pokemon = slowking
	var defender_cd := _basic_target("Psychic Weak Target")
	defender_cd.weakness_energy = "P"
	defender_cd.weakness_value = "x2"
	state.players[1].active_pokemon = _make_slot(defender_cd, 1)
	var copied_effect_id := "slowking_ignore_wr_copy"
	processor.register_attack_effect(copied_effect_id, AttackIgnoreWeaknessResistanceAndEffects.new(0))
	var copied_cd := _pokemon("Ignore WR Basic", copied_effect_id, [_attack("Piercing Hit", "C", "50")], [], "C", 80)
	var top_card := CardInstance.create(copied_cd, 0)
	state.players[0].deck.append(top_card)

	processor.execute_attack_effect(slowking, 0, state.players[1].active_pokemon, state)

	return run_checks([
		assert_eq(state.players[1].active_pokemon.damage_counters, 50, "CSV9C_072 copied attack should preserve copied attack Weakness/Resistance ignore flags"),
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
		player.active_pokemon = _make_slot(_basic_target("Active %d" % pi), pi)
		state.players.append(player)
	return state


func _make_gsm(flipper: CoinFlipper = null) -> GameStateMachine:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	if flipper != null:
		gsm.coin_flipper = flipper
		gsm.effect_processor = EffectProcessor.new(flipper)
		gsm.effect_processor.bind_game_state_machine(gsm)
	return gsm


func _setup_battle(gsm: GameStateMachine, attacker_cd: CardData, defender_cd: CardData) -> Array[PokemonSlot]:
	var attacker := _make_slot(attacker_cd, 0)
	var defender := _make_slot(defender_cd, 1)
	gsm.game_state.players[0].active_pokemon = attacker
	gsm.game_state.players[1].active_pokemon = defender
	_add_dummy_prizes(gsm.game_state)
	gsm.effect_processor.register_pokemon_card(attacker_cd)
	return [attacker, defender]


func _add_dummy_prizes(state: GameState) -> void:
	for pi: int in state.players.size():
		for i: int in 6:
			state.players[pi].prizes.append(CardInstance.create(_trainer("Prize %d-%d" % [pi, i], "Item", ""), pi))


func _attach_energy(slot: PokemonSlot, owner_index: int, energy_type: String, count: int) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	for i: int in count:
		var energy := CardInstance.create(_energy("%s Energy %d" % [energy_type, i], energy_type), owner_index)
		slot.attached_energy.append(energy)
		result.append(energy)
	return result


func _make_slot(card_data: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	slot.turn_played = 0
	return slot


func _pokemon(
	name: String,
	effect_id: String = "",
	attacks: Array[Dictionary] = [],
	abilities: Array[Dictionary] = [],
	energy_type: String = "C",
	hp: int = 100,
	stage: String = "Basic",
	mechanic: String = ""
) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = "Pokemon"
	cd.effect_id = effect_id
	cd.energy_type = energy_type
	cd.hp = hp
	cd.stage = stage
	cd.mechanic = mechanic
	cd.attacks = attacks
	cd.abilities = abilities
	return cd


func _basic_target(name: String = "Target") -> CardData:
	return _pokemon(name, "", [_attack("Hit", "C", "10")], [], "C", 300)


func _trainer(name: String, card_type: String, effect_id: String) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = card_type
	cd.effect_id = effect_id
	return cd


func _energy(name: String, energy_type: String, card_type: String = "Basic Energy") -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = card_type
	cd.energy_type = energy_type
	cd.energy_provides = energy_type
	return cd


func _attack(name: String, cost: String = "", damage: String = "", text: String = "") -> Dictionary:
	return {"name": name, "cost": cost, "damage": damage, "text": text, "is_vstar_power": false}
