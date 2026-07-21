class_name TestTCGMikCSV7C102CSV7C103CSV8C156
extends TestBase

const CARD_UIDS := ["CSV7C_102", "CSV7C_103", "CSV8C_156"]


func test_imported_cards_are_bundled_with_valid_images_and_source_data() -> String:
	var checks: Array[String] = []
	var manifest := FileAccess.get_file_as_string("res://data/bundled_user/_manifest.txt")
	for uid: String in CARD_UIDS:
		var parts := uid.split("_")
		var set_code := parts[0]
		var index := parts[1]
		var json_path := "res://data/bundled_user/cards/%s.json" % uid
		var image_path := "res://data/bundled_user/cards/images/%s/%s.png.bin" % [set_code, index]
		checks.append(assert_true(json_path in manifest, "%s JSON should be in the bundled manifest" % uid))
		checks.append(assert_true(image_path in manifest, "%s image should be in the bundled manifest" % uid))
		checks.append(assert_true(CardData.is_valid_card_image_file(image_path), "%s should have a valid bundled image" % uid))
		checks.append(assert_not_null(_load_card(uid), "%s JSON should parse into CardData" % uid))

	var cutiefly := _load_card("CSV7C_102")
	var ribombee := _load_card("CSV7C_103")
	var dipplin := _load_card("CSV8C_156")
	checks.append(assert_eq(cutiefly.name, "萌虻", "CSV7C_102 should preserve the source name"))
	checks.append(assert_eq(cutiefly.attacks[0].get("damage", ""), "10", "CSV7C_102 should preserve printed damage"))
	checks.append(assert_eq(ribombee.evolves_from, "萌虻", "CSV7C_103 should evolve from Cutiefly"))
	checks.append(assert_str_contains(str(ribombee.attacks[0].get("text", "")), "2张奖赏卡", "CSV7C_103 should preserve the delayed Prize text"))
	checks.append(assert_eq(dipplin.evolves_from, "啃果虫", "CSV8C_156 should evolve from Applin"))
	checks.append(assert_str_contains(str(dipplin.attacks[0].get("text", "")), "70伤害", "CSV8C_156 should preserve the force-out damage text"))
	return run_checks(checks)


func test_csv7c_102_heals_exactly_10_hp() -> String:
	var card := _load_card("CSV7C_102")
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(card)
	var attacker := _slot(card, 0)
	var defender := _slot(_pokemon("Defender", 100), 1)
	attacker.damage_counters = 20
	var effects := processor.get_attack_effects_for_slot(attacker, 0)
	if effects.is_empty():
		return "CSV7C_102 微微吸取 should register an attack effect"
	effects[0].call("execute_attack", attacker, defender, 0, _state(attacker, defender))
	return run_checks([
		assert_eq(attacker.damage_counters, 10, "CSV7C_102 should heal exactly 10 HP"),
	])


func test_csv7c_103_bonus_is_only_active_during_attackers_next_turn() -> String:
	var card := _load_card("CSV7C_103")
	var attacker := _slot(card, 0)
	var defender := _slot(_pokemon("Affected Defender", 100), 1)
	var state := _state(attacker, defender)
	state.turn_number = 2
	state.current_player_index = 0
	var gsm := GameStateMachine.new()
	gsm.game_state = state
	gsm.effect_processor.register_pokemon_card(card)
	gsm.effect_processor.execute_attack_effect(attacker, 0, defender, state)

	var marker_count := defender.effects.filter(func(effect: Dictionary) -> bool:
		return effect.get("type", "") == PokemonSlot.DELAYED_EXTRA_PRIZE_EFFECT_TYPE
	).size()
	var same_turn_prizes := gsm._get_knockout_prize_count(defender)
	state.turn_number = 3
	state.current_player_index = 1
	gsm._refresh_delayed_extra_prize_markers(1)
	var opponent_turn_prizes := gsm._get_knockout_prize_count(defender)
	state.turn_number = 4
	state.current_player_index = 0
	gsm._refresh_delayed_extra_prize_markers(0)
	var next_own_turn_prizes := gsm._get_knockout_prize_count(defender)

	return run_checks([
		assert_eq(marker_count, 1, "CSV7C_103 should add one non-stacking delayed marker"),
		assert_eq(same_turn_prizes, 1, "CSV7C_103 must not award extra Prizes on the application turn"),
		assert_eq(opponent_turn_prizes, 1, "CSV7C_103 must not award extra Prizes during the opponent's turn"),
		assert_eq(next_own_turn_prizes, 3, "CSV7C_103 should award two additional Prizes during the attacker's next turn"),
	])


func test_csv7c_103_marker_clears_on_switch_and_does_not_follow_evolution() -> String:
	var card := _load_card("CSV7C_103")
	var attacker := _slot(card, 0)
	var switched_defender := _slot(_pokemon("Switch Target", 100), 1)
	var state := _state(attacker, switched_defender)
	state.turn_number = 2
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(card)
	processor.execute_attack_effect(attacker, 0, switched_defender, state)
	switched_defender.clear_on_leave_active()
	var switch_marker_count := switched_defender.effects.filter(func(effect: Dictionary) -> bool:
		return effect.get("type", "") == PokemonSlot.DELAYED_EXTRA_PRIZE_EFFECT_TYPE
	).size()

	var evolved_defender := _slot(_pokemon("Evolution Base", 100), 1)
	state.players[1].active_pokemon = evolved_defender
	processor.execute_attack_effect(attacker, 0, evolved_defender, state)
	var evolution := CardInstance.create(_pokemon("Evolution", 140, "Stage 1"), 1)
	evolved_defender.pokemon_stack.append(evolution)
	evolved_defender.mark_top_card_changed()
	state.turn_number = 4
	state.current_player_index = 0
	var gsm := GameStateMachine.new()
	gsm.game_state = state
	gsm._refresh_delayed_extra_prize_markers(0)

	return run_checks([
		assert_eq(switch_marker_count, 0, "CSV7C_103's attack effect should clear when the affected Pokemon leaves Active"),
		assert_eq(gsm._get_knockout_prize_count(evolved_defender), 1, "CSV7C_103's marker must not follow a changed top-card instance through evolution"),
	])


func test_csv8c_156_requires_attacker_choice_then_switches_and_deals_70() -> String:
	var card := _load_card("CSV8C_156")
	var attacker := _slot(card, 0)
	var old_active := _slot(_pokemon("Old Active", 150), 1)
	var chosen_bench := _slot(_pokemon("Chosen Bench", 150), 1)
	var other_bench := _slot(_pokemon("Other Bench", 150), 1)
	var state := _state(attacker, old_active)
	state.players[1].bench = [chosen_bench, other_bench]
	var processor := EffectProcessor.new()
	processor.register_pokemon_card(card)

	var effects := processor.get_attack_effects_for_slot(attacker, 0)
	if effects.is_empty():
		return "CSV8C_156 蜜糖捕捉 should register an attack effect"
	var steps: Array[Dictionary] = effects[0].call("get_attack_interaction_steps", attacker.get_top_card(), card.attacks[0], state)
	var missing_choice_valid := processor.validate_attack_effect_context(attacker, 0, old_active, state, [])
	var selected_choice_valid := processor.validate_attack_effect_context(attacker, 0, old_active, state, [{"force_out_target": [chosen_bench]}])
	processor.execute_attack_effect(attacker, 0, old_active, state, [{"force_out_target": [chosen_bench]}])

	return run_checks([
		assert_eq(steps.size(), 1, "CSV8C_156 should expose one target-selection step"),
		assert_false(bool(steps[0].get("opponent_chooses", true)) if not steps.is_empty() else true, "CSV8C_156's attacking player should choose the target"),
		assert_false(missing_choice_valid, "CSV8C_156 should reject a missing mandatory target"),
		assert_true(selected_choice_valid, "CSV8C_156 should accept one legal opposing Bench target"),
		assert_eq(state.players[1].active_pokemon, chosen_bench, "CSV8C_156 should switch the selected Pokemon into the Active Spot"),
		assert_eq(chosen_bench.damage_counters, 70, "CSV8C_156 should deal 70 damage to the newly Active Pokemon"),
		assert_true(old_active in state.players[1].bench, "CSV8C_156 should move the former Active Pokemon to the Bench"),
	])


func _load_card(uid: String) -> CardData:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/%s.json" % uid))
	return CardData.from_dict(parsed) if parsed is Dictionary else null


func _state(attacker: PokemonSlot, defender: PokemonSlot) -> GameState:
	var state := GameState.new()
	state.turn_number = 2
	state.current_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		state.players.append(player)
	state.players[0].active_pokemon = attacker
	state.players[1].active_pokemon = defender
	return state


func _slot(card: CardData, owner: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner))
	return slot


func _pokemon(name: String, hp: int, stage: String = "Basic") -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = "Pokemon"
	card.stage = stage
	card.hp = hp
	card.energy_type = "C"
	card.attacks = [{"name": "Strike", "cost": "C", "damage": "10", "text": "", "is_vstar_power": false}]
	return card
