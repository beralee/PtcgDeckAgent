extends TestBase

class ReviewUISurface extends RefCounted:
	var _gsm: GameStateMachine
	var refreshed := false
	var prompts := 0
	func _refresh_ui_after_successful_action(_clear: bool, _owner: int) -> void:
		refreshed = true
	func _start_effect_interaction(_kind: String, _owner: int, _steps: Array, _card: CardInstance) -> void:
		prompts += 1
	func _maybe_run_ai() -> void:
		pass

class FixedCoin extends CoinFlipper:
	var heads := true
	var calls := 0
	func flip() -> bool:
		calls += 1
		return heads
	func flip_with_metadata(_metadata: Dictionary) -> bool:
		return flip()

class SequenceCoin extends CoinFlipper:
	var results: Array[bool] = []
	var calls := 0
	func flip() -> bool:
		calls += 1
		return results.pop_front() if not results.is_empty() else false

	func flip_with_metadata(_metadata: Dictionary) -> bool:
		return flip()


func test_30thc_001_sleep_and_003_owner_selected_switch() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	state.shared_turn_flags["_draw_effect_processor"] = processor
	var attacker := _slot(_card(1), 0)
	var defender := _slot(_card(1), 1)
	state.players[0].active_pokemon = attacker
	state.players[1].active_pokemon = defender
	processor.register_pokemon_card(attacker.get_card_data())
	for effect in processor.get_attack_effects_for_slot(attacker, 0):
		effect.execute_attack(attacker, defender, 0, state)
	var checks: Array[String] = [assert_true(defender.status_conditions.asleep, "Hypnosis applies sleep")]
	attacker = _slot(_card(3), 0)
	state.players[0].active_pokemon = attacker
	state.players[1].bench.append(_slot(_card(1), 1))
	var chosen := _slot(_card(4), 1)
	state.players[1].bench.append(chosen)
	processor.register_pokemon_card(attacker.get_card_data())
	var effects := processor.get_attack_effects_for_slot(attacker, 0)
	if effects.is_empty():
		return "Volbeat effect missing"
	var steps := effects[0].get_attack_interaction_steps(attacker.get_top_card(), attacker.get_card_data().attacks[0], state)
	checks.append(assert_false(bool(steps[0].get("opponent_chooses", false)), "Volbeat owner, not opponent, selects replacement"))
	effects[0].set_attack_interaction_context([{"opponent_switch_target": [chosen]}])
	effects[0].execute_attack(attacker, defender, 0, state)
	checks.append(assert_eq(state.players[1].active_pokemon, chosen, "Selected non-first bench target moves Active"))
	checks.append(assert_true(processor.get_attack_effects_for_slot(attacker, 1).is_empty(), "Bug Buzz must not switch"))
	state.shared_turn_flags.clear()
	processor.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_005_vivillon_coin_visibility_turn_limit_and_ai_preview() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _state()
	var state := gsm.game_state
	var slot := _slot(_card(5), 0)
	state.players[0].bench.append(slot)
	state.players[0].active_pokemon = _slot(_card(1), 0)
	state.players[1].active_pokemon = _slot(_card(1), 1)
	var pokemon := CardInstance.create(_card(3), 0)
	var energy := _energy("G")
	state.players[0].deck.assign([energy, pokemon])
	gsm.effect_processor.register_pokemon_card(slot.get_card_data())
	var effect := gsm.effect_processor.get_effect(slot.get_card_data().effect_id)
	if effect == null:
		return "Vivillon ability missing"
	var coin := FixedCoin.new()
	effect.set("coin_flipper", coin)
	var checks: Array[String] = [assert_true(effect.can_use_ability(slot, state), "Ability works from Bench")]
	var actions := AILegalActionBuilder.new().build_actions(gsm, 0)
	checks.append(assert_eq(coin.calls, 0, "Legal action preview must not flip coins"))
	checks.append(assert_true(actions.any(func(action: Dictionary) -> bool: return action.get("kind") == "use_ability" and action.get("source_slot") == slot), "AI can enumerate Vivillon ability"))
	var steps := effect.get_interaction_steps(slot.get_top_card(), state)
	checks.append(assert_eq(coin.calls, 1, "Resolve one coin"))
	checks.append(assert_eq(steps[0].get("card_items", []).size(), 2, "Heads shows full own deck"))
	checks.append(assert_eq(steps[0].get("items", []), [pokemon], "Only Pokemon is selectable"))
	effect.get_interaction_steps(slot.get_top_card(), state)
	checks.append(assert_eq(coin.calls, 1, "Rebuilding same window cannot reroll"))
	checks.append(assert_true(gsm.use_ability(0, slot, 0, [{"search_cards": [pokemon]}]), "Core ability entry succeeds"))
	checks.append(assert_true(pokemon in state.players[0].hand, "Chosen Pokemon enters hand"))
	checks.append(assert_false(gsm.use_ability(0, slot), "Cannot repeat this turn"))
	state.turn_number += 2
	coin.heads = false
	steps = effect.get_interaction_steps(slot.get_top_card(), state)
	checks.append(assert_true(steps.is_empty(), "Tails reveals no deck cards"))
	checks.append(assert_true(effect.get_followup_interaction_steps(slot.get_top_card(), state, {"empty_search_resolution": ["view_deck"]}).is_empty(), "Tails cannot reveal deck through followup"))
	checks.append(assert_true(gsm.use_ability(0, slot), "Tails still uses the ability"))
	checks.append(assert_false(effect.can_use_ability(slot, state), "Tails consumes turn use"))
	state.turn_number += 1
	state.current_player_index = 1
	checks.append(assert_false(effect.can_use_ability(slot, state), "Cannot use in opponent turn"))
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_001_to_005_real_json_registration() -> String:
	return _check_registration(1, 5)


func test_30thc_006_to_010_real_json_registration() -> String:
	return _check_registration(6, 10)


func test_30thc_011_to_015_real_json_registration() -> String:
	return _check_registration(11, 15)


func test_30thc_016_to_020_real_json_registration() -> String:
	return _check_registration(16, 20)


func test_30thc_021_to_025_real_json_registration() -> String:
	return _check_registration(21, 25)


func test_30thc_026_to_030_real_json_registration() -> String:
	return _check_registration(26, 30)


func test_30thc_031_to_035_real_json_registration() -> String:
	return _check_registration(31, 35)


func test_30thc_036_to_040_real_json_registration() -> String:
	return _check_registration(36, 40)


func test_30thc_041_to_045_real_json_registration() -> String:
	return _check_registration(41, 45)


func test_30thc_046_to_050_real_json_registration() -> String:
	return _check_registration(46, 50)


func test_30thc_051_to_055_real_json_registration() -> String:
	return _check_registration(51, 55)


func _check_registration(first: int, last: int) -> String:
	var processor := EffectProcessor.new()
	var checks: Array[String] = []
	for index in range(first, last + 1):
		var card := _card(index)
		checks.append(assert_not_null(card, "Bundled printing %03d" % index))
		if card == null:
			continue
		processor.register_pokemon_card(card)
		checks.append(assert_false(CardImplementationStatus.is_unimplemented(card), "Printing %03d must register its rules" % index))
		var slot := _slot(card, 0)
		for attack_index in card.attacks.size():
			if str(card.attacks[attack_index].get("text", "")) != "":
				checks.append(assert_false(processor.get_attack_effects_for_slot(slot, attack_index).is_empty(), "Every rules-bearing attack must register"))
	processor.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_006_moltres_partners_attach_once_and_discard_two() -> String:
	var gsm := _battle(6)
	var state := gsm.game_state
	var slot := state.players[0].active_pokemon
	var fire := _energy("R")
	state.players[0].hand.append(fire)
	var effect := gsm.effect_processor.get_effect(slot.get_card_data().effect_id)
	var checks: Array[String] = [assert_false(effect.can_use_ability(slot, state), "Requires both partners")]
	for name in ["Articuno", "Zapdos"]:
		var data := _card(1)
		data.name = name
		data.name_en = name
		state.players[0].bench.append(_slot(data, 0))
	checks.append(assert_true(gsm.use_ability(0, slot, 0, [{"basic_energy_from_hand": [fire]}]), "Named birds enable attachment"))
	checks.append(assert_true(fire in slot.attached_energy, "Chosen basic Fire attached to source"))
	state.players[0].hand.append(_energy("R"))
	checks.append(assert_false(effect.can_use_ability(slot, state), "Once per turn"))
	var count := slot.attached_energy.size()
	var discarded: Array = [slot.attached_energy[0], fire]
	checks.append(assert_true(gsm.use_attack(0, 0, [{"discard_typed_attached_energy_from_self": discarded}]), "Fire Spin executes"))
	for energy: CardInstance in discarded:
		checks.append(assert_true(energy in state.players[0].discard_pile, "Exact selected Fire Spin Energy discarded"))
	checks.append(assert_eq(slot.attached_energy.size(), count - 2, "Exactly two selected Energy discarded"))
	checks.append(assert_eq(state.players[1].active_pokemon.damage_counters, 130, "Printed damage"))
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_007_hooh_heals_only_selected_bench_discards_all_energy() -> String:
	var gsm := _battle(7)
	var state := gsm.game_state
	var slot := state.players[0].active_pokemon
	var selected := _slot(_card(2), 0)
	var other := _slot(_card(2), 0)
	selected.damage_counters = 90
	other.damage_counters = 50
	state.players[0].bench.assign([other, selected])
	var used := gsm.use_attack(0, 0, [{"thirtieth_heal_bench": [selected]}])
	var checks: Array[String] = [
		assert_true(used, "Sacred Breath executes"),
		assert_eq(selected.damage_counters, 0, "Selected target fully healed"),
		assert_eq(other.damage_counters, 50, "Other target unchanged"),
		assert_true(slot.attached_energy.is_empty(), "All source energy discarded"),
	]
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_008_reshiram_lightning_bonus_actual_damage() -> String:
	var checks: Array[String] = []
	for lightning in [false, true]:
		var gsm := _battle(8)
		if lightning:
			gsm.game_state.players[0].active_pokemon.attached_energy.append(_energy("L"))
		checks.append(assert_true(gsm.use_attack(0, 1), "Laser Flame executes"))
		checks.append(assert_eq(gsm.game_state.players[1].active_pokemon.damage_counters, 160 if lightning else 80, "Lightning conditional damage"))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_009_fuecoco_uses_own_taken_prizes_zero_and_two() -> String:
	var checks: Array[String] = []
	for taken in [0, 2]:
		var gsm := _battle(9)
		for i in taken:
			gsm.game_state.players[0].prizes.pop_back()
		gsm.game_state.players[1].prizes.pop_back()
		checks.append(assert_true(gsm.use_attack(0, 1), "Happy Flame executes"))
		checks.append(assert_eq(gsm.game_state.players[1].active_pokemon.damage_counters, taken * 70, "Counts own prizes, no spurious base 70"))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_010_slowpoke_protection_coin_and_expiry() -> String:
	var gsm := _battle(10)
	var state := gsm.game_state
	var slot := state.players[0].active_pokemon
	var effect := gsm.effect_processor.get_attack_effects_for_slot(slot, 0)[0]
	var coin := FixedCoin.new()
	effect.set("coin_flipper", coin)
	coin.heads = false
	effect.execute_attack(slot, null, 0, state)
	var checks: Array[String] = [assert_true(slot.effects.is_empty(), "Tails gives no protection")]
	coin.heads = true
	effect.execute_attack(slot, null, 0, state)
	checks.append(assert_false(AttackCoinFlipPreventDamageAndEffectsNextTurn.prevents_attack_damage(slot, state), "Not active on source turn"))
	state.turn_number += 1
	checks.append(assert_true(AttackCoinFlipPreventDamageAndEffectsNextTurn.prevents_attack_damage(slot, state), "Active on next opponent turn"))
	checks.append(assert_true(AttackCoinFlipPreventDamageAndEffectsNextTurn.prevents_attack_effects(slot, state), "Prevents effects as well as damage"))
	state.turn_number += 1
	checks.append(assert_false(AttackCoinFlipPreventDamageAndEffectsNextTurn.prevents_attack_damage(slot, state), "Expires after opponent turn"))
	gsm.prepare_for_disposal()
	return run_checks(checks)


func _battle(index: int) -> GameStateMachine:
	var gsm := GameStateMachine.new()
	gsm.game_state = _state()
	gsm.game_state.turn_number = 4
	gsm.effect_processor.bind_game_state_machine(gsm)
	gsm.game_state.shared_turn_flags["_draw_effect_processor"] = gsm.effect_processor
	var source := _slot(_card(index), 0)
	gsm.game_state.players[0].active_pokemon = source
	for symbol in ["R", "R", "R", "W", "C"]:
		source.attached_energy.append(_energy(symbol))
	var dummy := CardData.new()
	dummy.name = "Target"
	dummy.hp = 1000
	dummy.card_type = "Pokemon"
	dummy.stage = "Basic"
	gsm.game_state.players[1].active_pokemon = _slot(dummy, 1)
	for owner in 2:
		gsm.game_state.players[owner].player_index = owner
		for i in 6:
			gsm.game_state.players[owner].prizes.append(_energy("C"))
		gsm.game_state.players[owner].deck.append(_energy("C"))
	gsm.effect_processor.register_pokemon_card(source.get_card_data())
	return gsm


func test_30thc_011_lapras_search_visibility_and_selected_supporter() -> String:
	var gsm := _battle(11)
	var state := gsm.game_state
	var slot := state.players[0].active_pokemon
	var supporter := CardData.new()
	supporter.card_type = "Supporter"
	supporter.name = "Chosen supporter"
	var card := CardInstance.create(supporter, 0)
	state.players[0].deck.append(card)
	var effect := gsm.effect_processor.get_attack_effects_for_slot(slot, 0)[0]
	var steps := effect.get_attack_interaction_steps(slot.get_top_card(), slot.get_card_data().attacks[0], state)
	var checks: Array[String] = [
		assert_eq(steps[0].get("items"), [card], "Only supporter selectable"),
		assert_eq(steps[0].get("card_items", []).size(), 2, "Complete own deck visible"),
		assert_true(gsm.use_attack(0, 0, [{"search_cards": [card]}]), "Hitch a Ride executes"),
		assert_true(card in state.players[0].hand, "Chosen supporter enters hand"),
		assert_true(slot.get_card_data().is_tags.has("Rapid Strike"), "Reprint retains Rapid Strike tag"),
	]
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_012_articuno_hail_active_weakness_and_bench_no_weakness() -> String:
	var gsm := _battle(12)
	var state := gsm.game_state
	state.players[0].active_pokemon.attached_energy.append(_energy("W"))
	var active := state.players[1].active_pokemon
	active.get_card_data().weakness_energy = "W"
	active.get_card_data().weakness_value = "x2"
	var bench := _slot(active.get_card_data(), 1)
	state.players[1].bench.append(bench)
	var used := gsm.use_attack(0, 0)
	var checks: Array[String] = [assert_true(used, "Hail executes"), assert_eq(active.damage_counters, 60, "Active weakness applies"), assert_eq(bench.damage_counters, 30, "Bench ignores weakness")]
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_013_kyogre_water_energy_damage_before_weakness() -> String:
	var gsm := _battle(13)
	var target := gsm.game_state.players[1].active_pokemon
	target.get_card_data().weakness_energy = "W"
	target.get_card_data().weakness_value = "x2"
	var used := gsm.use_attack(0, 0)
	var checks: Array[String] = [assert_true(used, "Hydro Pump executes"), assert_eq(target.damage_counters, 180, "(60 + one Water x 30) x weakness")]
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_014_palkia_switches_both_sides_with_distinct_choosers() -> String:
	var gsm := _battle(14)
	var state := gsm.game_state
	var source := state.players[0].active_pokemon
	source.attached_energy.append(_energy("W"))
	var target := state.players[1].active_pokemon
	var own_choice := _slot(_card(1), 0)
	var opponent_choice := _slot(_card(1), 1)
	state.players[0].bench.assign([_slot(_card(3), 0), own_choice])
	state.players[1].bench.assign([_slot(_card(3), 1), opponent_choice])
	var effect := gsm.effect_processor.get_attack_effects_for_slot(source, 0)[0]
	var steps := effect.get_attack_interaction_steps(source.get_top_card(), source.get_card_data().attacks[0], state)
	var checks: Array[String] = [assert_eq(steps.size(), 2, "Both switch choices exposed"), assert_false(steps[0].get("allow_cancel", true), "Own switch is mandatory"), assert_true(steps[1].get("opponent_chooses", false), "Opponent chooses its replacement")]
	checks.append(assert_true(gsm.use_attack(0, 0, [{"switch_target": [own_choice], "opponent_switch_target": [opponent_choice]}]), "Wormhole executes"))
	checks.append(assert_eq(target.damage_counters, 100, "Original target takes damage before switches"))
	checks.append(assert_eq(state.players[0].active_pokemon, own_choice, "Own selected replacement"))
	checks.append(assert_eq(state.players[1].active_pokemon, opponent_choice, "Opponent selected replacement"))
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_015_greninja_scales_selected_targets_existing_counters() -> String:
	var checks: Array[String] = []
	for use_bench in [false, true]:
		var gsm := _battle(15)
		var state := gsm.game_state
		var target := state.players[1].active_pokemon
		if use_bench:
			target = _slot(target.get_card_data(), 1)
			state.players[1].bench.append(target)
		target.get_card_data().weakness_energy = "W"
		target.get_card_data().weakness_value = "x2"
		target.damage_counters = 20
		checks.append(assert_true(gsm.use_attack(0, 0, [{"any_target": [target]}]), "Stealth Slash executes"))
		checks.append(assert_eq(target.damage_counters, 80 if use_bench else 140, "Two counters x 30 damage, weakness only on Active"))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_016_wishiwashi_bench_aura_stacks_only_on_named_active_damage() -> String:
	var gsm := _battle(16)
	var state := gsm.game_state
	var defender := state.players[0].active_pokemon
	var attacker := state.players[1].active_pokemon
	state.players[0].bench.append(_slot(_card(16), 0))
	gsm.effect_processor.process_after_attack_damage(defender, attacker, 20, state)
	var checks: Array[String] = [assert_eq(attacker.damage_counters, 60, "Active and Bench copies each retaliate")]
	gsm.effect_processor.process_after_attack_damage(defender, attacker, 0, state)
	checks.append(assert_eq(attacker.damage_counters, 60, "No damage, no retaliation"))
	gsm.effect_processor.process_after_attack_damage(state.players[0].bench[0], attacker, 20, state)
	checks.append(assert_eq(attacker.damage_counters, 60, "Damaged Benched Wishiwashi is not protected by this aura"))
	defender.get_card_data().name = "Wishiwashi ex"
	gsm.effect_processor.process_after_attack_damage(defender, attacker, 20, state)
	checks.append(assert_eq(attacker.damage_counters, 120, "Includes Wishiwashi ex"))
	defender.get_card_data().name = "Other Pokemon"
	gsm.effect_processor.process_after_attack_damage(defender, attacker, 20, state)
	checks.append(assert_eq(attacker.damage_counters, 120, "Does not protect unrelated Active"))
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_017_pikachu_paralysis_heads_and_tails() -> String:
	var checks: Array[String] = []
	for heads in [false, true]:
		var gsm := _battle(17)
		gsm.game_state.players[0].active_pokemon.attached_energy.append(_energy("L"))
		var coin := FixedCoin.new()
		coin.heads = heads
		gsm.effect_processor.coin_flipper = coin
		checks.append(assert_true(gsm.use_attack(0, 0), "Thunder Shock executes"))
		var target := gsm.game_state.players[1].active_pokemon
		checks.append(assert_eq(target.damage_counters, 20, "Printed damage on either result"))
		checks.append(assert_eq(target.status_conditions.paralyzed, heads, "Paralysis only on heads"))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_018_pikachu_recoil_and_019_selected_bench_damage() -> String:
	var checks: Array[String] = []
	for index in [18, 19]:
		var gsm := _battle(index)
		var state := gsm.game_state
		var source := state.players[0].active_pokemon
		source.get_card_data().hp = 100
		source.attached_energy.append(_energy("L"))
		var bench := _slot(state.players[1].active_pokemon.get_card_data(), 1)
		state.players[1].bench.append(bench)
		checks.append(assert_true(gsm.use_attack(0, 0, [{"bench_target": [bench]}]), "Pikachu attack executes"))
		checks.append(assert_eq(state.players[1].active_pokemon.damage_counters, 80 if index == 18 else 20, "Printed Active damage"))
		checks.append(assert_eq(source.damage_counters, 30 if index == 18 else 0, "Recoil only on Volt Tackle"))
		checks.append(assert_eq(bench.damage_counters, 20 if index == 19 else 0, "Bench damage only on Spark"))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_020_pikachu_peek_reveals_hand_only_after_confirmation() -> String:
	var gsm := _battle(20)
	var state := gsm.game_state
	var source := state.players[0].active_pokemon
	var hand_card := _energy("L")
	state.players[1].hand.append(hand_card)
	var effect := gsm.effect_processor.get_attack_effects_for_slot(source, 0)[0]
	var preview := effect.get_attack_preview_interaction_steps(source.get_top_card(), source.get_card_data().attacks[0], state)
	var resolved := effect.get_attack_interaction_steps(source.get_top_card(), source.get_card_data().attacks[0], state)
	var checks: Array[String] = [
		assert_false(str(preview).contains(str(hand_card)), "Preview does not contain opponent hand"),
		assert_eq(resolved[0].get("card_items"), [hand_card], "Confirmed attack can show the hand"),
		assert_eq(resolved[0].get("visible_scope"), "opponent_hand", "Does not reveal opponent deck"),
		assert_eq(resolved[0].get("max_select"), 0, "Read-only reveal"),
	]
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_021_heal_023_search_and_024_025_vanilla_damage() -> String:
	var checks: Array[String] = []
	for index in [21, 23, 24, 25]:
		var gsm := _battle(index)
		var state := gsm.game_state
		var source := state.players[0].active_pokemon
		source.attached_energy.append(_energy("L"))
		source.damage_counters = 30 if index == 21 else 0
		var pokemon := CardInstance.create(_card(1), 0)
		state.players[0].deck.append(pokemon)
		checks.append(assert_true(gsm.use_attack(0, 0, [{"search_cards": [pokemon]}]), "Printing %d can attack" % index))
		if index == 21:
			checks.append(assert_eq(source.damage_counters, 0, "Take a Break heals 30"))
		if index == 23:
			checks.append(assert_true(pokemon in state.players[0].hand, "Find a Friend searches Pokemon"))
		checks.append(assert_eq(state.players[1].active_pokemon.damage_counters, 30 if index == 24 else (10 if index == 25 else 0), "Correct printed damage without extraneous effect"))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_022_lonely_gaze_outgoing_reduction_before_weakness_and_bench() -> String:
	var gsm := _battle(12)
	var state := gsm.game_state
	var source := state.players[0].active_pokemon
	source.attached_energy.append(_energy("W"))
	var gaze := _slot(_card(22), 1)
	gaze.get_card_data().hp = 500
	gaze.get_card_data().weakness_energy = "W"
	gaze.get_card_data().weakness_value = "x2"
	state.players[1].active_pokemon = gaze
	var bench := _slot(_card(2), 1)
	state.players[1].bench.append(bench)
	var checks: Array[String] = [assert_true(gsm.use_attack(0, 0), "Hail against Lonely Gaze executes"), assert_eq(gaze.damage_counters, 20, "(30 - 20) x2, reduction before weakness"), assert_eq(bench.damage_counters, 10, "Outgoing reduction also applies to Bench damage")]
	state.players[1].active_pokemon = bench
	state.players[1].bench.assign([gaze])
	checks.append(assert_eq(gsm.effect_processor.get_attacker_modifier(source, state, bench), 0, "Lonely Gaze does not work from Bench"))
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_026_switch_029_vanilla_030_recoil() -> String:
	var checks: Array[String] = []
	for index in [26, 29, 30]:
		var gsm := _battle(index)
		var state := gsm.game_state
		var source := state.players[0].active_pokemon
		source.attached_energy.append(_energy("L"))
		var selected := _slot(_card(1), 0)
		state.players[0].bench.append(selected)
		checks.append(assert_true(gsm.use_attack(0, 0, [{"switch_target": [selected]}]), "Printing %d executes" % index))
		checks.append(assert_eq(state.players[1].active_pokemon.damage_counters, 0 if index == 26 else (30 if index == 29 else 40), "Printed damage"))
		checks.append(assert_eq(source.damage_counters, 10 if index == 30 else 0, "Recoil only on Reckless Charge"))
		if index == 26:
			checks.append(assert_eq(state.players[0].active_pokemon, selected, "Scamper switches to selected target"))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_027_hide_bench_only_damage_and_effect_protection() -> String:
	var gsm := _battle(12)
	var state := gsm.game_state
	state.players[0].active_pokemon.attached_energy.append(_energy("W"))
	var hidden := _slot(_card(27), 1)
	state.players[1].bench.append(hidden)
	var checks: Array[String] = [assert_true(AbilityBenchImmune.prevents_opponent_attack_effect(hidden, state.players[0].active_pokemon, state), "Hide prevents attack effects on Bench")]
	checks.append(assert_true(gsm.use_attack(0, 0), "Hail executes"))
	checks.append(assert_eq(hidden.damage_counters, 0, "Hide prevents Bench attack damage"))
	state.players[1].bench.clear()
	state.players[1].active_pokemon = hidden
	checks.append(assert_false(AbilityBenchImmune.prevents_opponent_attack_damage(hidden, state.players[0].active_pokemon, state), "Hide does not work in Active"))
	checks.append(assert_false(AbilityBenchImmune.prevents_opponent_attack_effect(hidden, state.players[0].active_pokemon, state), "Active remains vulnerable to attack effects"))
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_028_pikachu_chain_counts_exact_pikachu_and_ex() -> String:
	var gsm := _battle(28)
	var state := gsm.game_state
	for i in 3:
		state.players[0].active_pokemon.attached_energy.append(_energy("L"))
	for name in ["Pikachu ex", "Pikachu V", "Partner's Pikachu", "皮卡丘"]:
		var data := _card(1)
		data.name = name
		state.players[0].bench.append(_slot(data, 0))
	var checks: Array[String] = [assert_true(gsm.use_attack(0, 0), "Pika Chain executes"), assert_eq(state.players[1].active_pokemon.damage_counters, 120, "Exactly three matching Pokemon including attacker; excludes V and owner-named variant")]
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_031_search_basic_or_special_energy_and_032_035_damage() -> String:
	var checks: Array[String] = []
	for index in [31, 32, 35]:
		var gsm := _battle(index)
		var state := gsm.game_state
		var source := state.players[0].active_pokemon
		source.attached_energy.append(_energy("L"))
		var special := CardData.new()
		special.card_type = "Special Energy"
		special.name = "Special Energy"
		var energy := CardInstance.create(special, 0)
		state.players[0].deck.append(energy)
		if index == 31:
			var effect := gsm.effect_processor.get_attack_effects_for_slot(source, 0)[0]
			var steps := effect.get_attack_interaction_steps(source.get_top_card(), source.get_card_data().attacks[0], state)
			checks.append(assert_eq(steps[0].get("items", []).size(), 2, "Basic and Special Energy both selectable"))
		var attack_index := 1 if index == 35 else 0
		checks.append(assert_true(gsm.use_attack(0, attack_index, [{"search_cards": [energy], "any_target": [state.players[1].active_pokemon]}]), "Printing %d executes" % index))
		if index == 31:
			checks.append(assert_true(energy in state.players[0].hand, "Special Energy can be searched"))
		checks.append(assert_eq(state.players[1].active_pokemon.damage_counters, 0 if index == 31 else (20 if index == 32 else 40), "Correct printed or selected-target damage"))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_033_iron_tail_coin_count_before_weakness_and_preview_no_rng() -> String:
	var checks: Array[String] = []
	for heads in [0, 2]:
		var gsm := _battle(33)
		var state := gsm.game_state
		var source := state.players[0].active_pokemon
		var target := state.players[1].active_pokemon
		target.get_card_data().weakness_energy = "L"
		target.get_card_data().weakness_value = "x2"
		var coin := SequenceCoin.new()
		for i in heads:
			coin.results.append(true)
		coin.results.append(false)
		gsm.effect_processor.get_attack_effects_for_slot(source, 0)[0].set("coin_flipper", coin)
		gsm.get_attack_preview_damage(0, 0)
		checks.append(assert_eq(coin.calls, 0, "Damage preview does not consume random outcomes"))
		checks.append(assert_true(gsm.use_attack(0, 0), "Iron Tail executes"))
		checks.append(assert_eq(target.damage_counters, heads * 40, "Full coin-derived base multiplied by weakness"))
		checks.append(assert_eq(coin.calls, heads + 1, "Stop at first tails, no duplicate roll"))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_034_rewrite_weakness_expiry_evolution_and_leave_active() -> String:
	var gsm := _battle(34)
	var state := gsm.game_state
	var source := state.players[0].active_pokemon
	source.attached_energy.append(_energy("L"))
	var target := state.players[1].active_pokemon
	var checks: Array[String] = [assert_true(gsm.use_attack(0, 0), "Rewrite Volt executes")]
	state.turn_number = 6
	checks.append(assert_eq(gsm.effect_processor.get_weakness_energy_override(source, target, state), "L", "Persists through next own turn"))
	checks.append(assert_eq(gsm.effect_processor.get_weakness_value_override(source, target, state), "x2", "Weakness multiplier is two"))
	state.turn_number = 7
	checks.append(assert_eq(gsm.effect_processor.get_weakness_energy_override(source, target, state), "", "Expires afterward"))
	state.turn_number = 6
	var original_top := target.get_top_card()
	target.pokemon_stack.append(CardInstance.create(original_top.card_data, 1))
	checks.append(assert_eq(gsm.effect_processor.get_weakness_energy_override(source, target, state), "", "Evolution clears applicability"))
	target.pokemon_stack.pop_back()
	target.clear_on_leave_active()
	checks.append(assert_eq(gsm.effect_processor.get_weakness_energy_override(source, target, state), "", "Moving to Bench clears rewrite"))
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_036_charge_dash_coin_limit_zero_and_two_no_special_energy() -> String:
	var checks: Array[String] = []
	for heads in [0, 2]:
		var gsm := _battle(36)
		var state := gsm.game_state
		var source := state.players[0].active_pokemon
		var before := source.attached_energy.size()
		var energy := _energy("L")
		var second := _energy("L")
		var special := _energy("L")
		special.card_data.card_type = "Special Energy"
		state.players[0].deck.assign([energy, second, special, _energy("W")])
		var effect := gsm.effect_processor.get_attack_effects_for_slot(source, 0)[0]
		var coin := SequenceCoin.new()
		for i in heads:
			coin.results.append(true)
		coin.results.append(false)
		effect.set("coin_flipper", coin)
		effect.get_attack_preview_interaction_steps(source.get_top_card(), source.get_card_data().attacks[0], state)
		checks.append(assert_eq(coin.calls, 0, "Preview consumes no coins"))
		var steps := effect.get_attack_interaction_steps(source.get_top_card(), source.get_card_data().attacks[0], state)
		if heads == 0:
			checks.append(assert_true(steps.is_empty(), "Zero heads exposes no deck"))
		else:
			checks.append(assert_eq(steps[0].get("max_select"), 2, "Selection limit follows heads"))
			checks.append(assert_eq(steps[0].get("items"), [energy, second], "Only basic Lightning selectable"))
			checks.append(assert_eq(steps[0].get("card_items", []).size(), 4, "Full own deck visible on search"))
		checks.append(assert_true(gsm.use_attack(0, 0, [{"deck_energy": [energy, second, special]}]), "Charge Dash executes"))
		checks.append(assert_eq(source.attached_energy.size(), before + heads, "Correct energy count; zero heads never attaches one"))
		checks.append(assert_true(special in state.players[0].deck, "Special Energy is rejected"))
		checks.append(assert_eq(coin.calls, heads + 1, "No reroll on execution"))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_037_tropical_mood_sleep_then_draw_to_six_or_full_hand() -> String:
	var checks: Array[String] = []
	for size in [2, 7]:
		var gsm := _battle(37)
		var state := gsm.game_state
		var coin := FixedCoin.new()
		coin.heads = false
		gsm.effect_processor.coin_flipper = coin
		for i in size:
			state.players[0].hand.append(_energy("C"))
		for i in 10:
			state.players[0].deck.append(_energy("C"))
		checks.append(assert_true(gsm.use_attack(0, 0), "Tropical Mood executes"))
		checks.append(assert_true(state.players[0].active_pokemon.status_conditions.asleep, "Source sleeps even with full hand"))
		checks.append(assert_eq(state.players[0].hand.size(), maxi(size, 6), "Draw to six, never discard excess"))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_038_agility_039_draw_040_cure() -> String:
	var checks: Array[String] = []
	for index in [38, 39, 40]:
		var gsm := _battle(index)
		var state := gsm.game_state
		var source := state.players[0].active_pokemon
		if index == 38:
			gsm.effect_processor.get_attack_effects_for_slot(source, 0)[0].set("coin_flipper", FixedCoin.new())
		if index == 40:
			source.set_status("poisoned", true)
			source.set_status("burned", true)
		checks.append(assert_true(gsm.use_attack(0, 0), "Printing %d executes" % index))
		if index == 38:
			checks.append(assert_eq(state.players[1].active_pokemon.damage_counters, 10, "Agility printed damage"))
			checks.append(assert_true(AttackCoinFlipPreventDamageAndEffectsNextTurn.prevents_attack_effects(source, state), "Agility protects next turn"))
		if index == 39:
			checks.append(assert_eq(state.players[0].hand.size(), 1, "Night Walk draws one"))
		if index == 40:
			checks.append(assert_false(source.has_any_status(), "Headwind clears all statuses"))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_041_play_rough_bonus_before_weakness() -> String:
	var checks: Array[String] = []
	for heads in [false, true]:
		var gsm := _battle(41)
		var state := gsm.game_state
		var source := state.players[0].active_pokemon
		var target := state.players[1].active_pokemon
		target.get_card_data().weakness_energy = "L"
		target.get_card_data().weakness_value = "x2"
		var coin := FixedCoin.new()
		coin.heads = heads
		gsm.effect_processor.get_attack_effects_for_slot(source, 0)[0].set("coin_flipper", coin)
		checks.append(assert_true(gsm.use_attack(0, 0), "Play Rough executes"))
		checks.append(assert_eq(target.damage_counters, 60 if heads else 20, "Both base and bonus multiplied by weakness"))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_042_collect_recovers_up_to_two_basic_energy_not_special() -> String:
	var checks: Array[String] = []
	for count in [0, 1, 2]:
		var gsm := _battle(42)
		var state := gsm.game_state
		var first := _energy("L")
		var second := _energy("W")
		var special := _energy("L")
		special.card_data.card_type = "Special Energy"
		state.players[0].discard_pile.assign([first, second, special])
		var chosen: Array = [first, second].slice(0, count)
		checks.append(assert_true(gsm.use_attack(0, 0, [{"csv9c_recover_pokemon_from_discard": chosen}]), "Collect executes"))
		checks.append(assert_eq(state.players[0].hand.size(), count, "Explicit 0/1/2 selections respected"))
		checks.append(assert_true(special in state.players[0].discard_pile, "Special Energy not recoverable"))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_043_ex_bonus_044_printed_damage_and_045_discard_lightning_only() -> String:
	var checks: Array[String] = []
	for index in [43, 44, 45]:
		var gsm := _battle(index)
		var state := gsm.game_state
		var source := state.players[0].active_pokemon
		for i in 3:
			source.attached_energy.append(_energy("L"))
		var target := state.players[1].active_pokemon
		target.get_card_data().mechanic = "ex"
		checks.append(assert_true(gsm.use_attack(0, 0, [{"any_target": [target]}]), "Printing %d executes" % index))
		checks.append(assert_eq(target.damage_counters, 90 if index == 45 else 100, "Correct damage"))
		if index == 45:
			checks.append(assert_eq(source.attached_energy.size(), 5, "Non-Lightning Energy retained"))
			checks.append(assert_eq(state.players[0].discard_pile.size(), 3, "All three Lightning Energy discarded"))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_selected_target_damage_triggers_wishiwashi_retaliation() -> String:
	var gsm := _battle(32)
	var state := gsm.game_state
	var source := state.players[0].active_pokemon
	source.attached_energy.append(_energy("L"))
	var target := _slot(_card(16), 1)
	state.players[1].active_pokemon = target
	var checks: Array[String] = [assert_true(gsm.use_attack(0, 0, [{"any_target": [target]}]), "Targeted damage attack executes"), assert_eq(source.damage_counters, 30, "Targeted attack damage triggers reactive ability")]
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_046_damage_counters_049_recoil_050_fire_bonus() -> String:
	var checks: Array[String] = []
	for index in [46, 49, 50]:
		var gsm := _battle(index)
		var state := gsm.game_state
		var source := state.players[0].active_pokemon
		source.get_card_data().hp = 300
		for i in 3:
			source.attached_energy.append(_energy("L"))
		if index == 46:
			source.damage_counters = 30
		checks.append(assert_true(gsm.use_attack(0, 1 if index == 50 else 0), "Printing %d executes" % index))
		checks.append(assert_eq(state.players[1].active_pokemon.damage_counters, 40 if index == 46 else (210 if index == 49 else 160), "Correct conditional/printed damage"))
		if index == 49:
			checks.append(assert_eq(source.damage_counters, 60, "Zapdos recoil"))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_047_pika_parade_filters_and_fills_only_available_bench() -> String:
	var gsm := _battle(47)
	var state := gsm.game_state
	var source := state.players[0].active_pokemon
	for i in 3:
		state.players[0].bench.append(_slot(_card(1), 0))
	var basics: Array = []
	for i in 4:
		var card := CardInstance.create(_card(1), 0)
		state.players[0].deck.append(card)
		basics.append(card)
	var evolution := CardInstance.create(_card(2), 0)
	state.players[0].deck.append(evolution)
	var effect := gsm.effect_processor.get_attack_effects_for_slot(source, 0)[0]
	var steps := effect.get_attack_interaction_steps(source.get_top_card(), source.get_card_data().attacks[0], state)
	var checks: Array[String] = [assert_eq(steps[0].get("max_select"), 2, "Limited by remaining Bench space"), assert_eq(steps[0].get("card_items", []).size(), 6, "Whole own deck visible"), assert_false(evolution in steps[0].get("items", []), "Evolution is not selectable")]
	checks.append(assert_true(gsm.use_attack(0, 0, [{"search_basic_pokemon": basics}]), "Pika Parade executes"))
	checks.append(assert_eq(state.players[0].bench.size(), 5, "Cannot overflow Bench"))
	checks.append(assert_true(evolution in state.players[0].deck, "Evolution remains in deck"))
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_048_energy_fever_splits_only_basic_hand_energy_among_own_targets() -> String:
	var gsm := _battle(48)
	var state := gsm.game_state
	var source := state.players[0].active_pokemon
	source.attached_energy.append(_energy("L"))
	var before := source.attached_energy.size()
	var bench := _slot(_card(1), 0)
	state.players[0].bench.append(bench)
	var first := _energy("W")
	var second := _energy("G")
	var special := _energy("L")
	special.card_data.card_type = "Special Energy"
	state.players[0].hand.assign([first, second, special])
	var effect := gsm.effect_processor.get_attack_effects_for_slot(source, 0)[0]
	var steps := effect.get_attack_interaction_steps(source.get_top_card(), source.get_card_data().attacks[0], state)
	var assignments: Array = [{"source": first, "target": source}, {"source": second, "target": bench}, {"source": special, "target": bench}, {"source": first, "target": state.players[1].active_pokemon}]
	var checks: Array[String] = [assert_eq(steps.size(), 1, "One arbitrary assignment interaction")]
	checks.append(assert_true(gsm.use_attack(0, 0, [{"csv9c_hand_energy_assignments": assignments}]), "Energy Fever executes"))
	checks.append(assert_eq(source.attached_energy.size(), before + 1, "One selected energy attached Active"))
	checks.append(assert_eq(bench.attached_energy, [second], "Other energy attached to chosen Bench"))
	checks.append(assert_true(special in state.players[0].hand, "Special Energy remains in hand"))
	checks.append(assert_true(state.players[1].active_pokemon.attached_energy.is_empty(), "Opponent target rejected"))
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_002_exeggutor_hp_threshold_and_healing() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	state.shared_turn_flags["_draw_effect_processor"] = processor
	var slot := _slot(_card(2), 0)
	state.players[0].active_pokemon = slot
	processor.register_pokemon_card(slot.get_card_data())
	for i in 5:
		slot.attached_energy.append(_energy("G"))
	var checks: Array[String] = [assert_eq(processor.get_hp_modifier(slot, state), 0, "Five Grass Energy is insufficient")]
	slot.attached_energy.append(_energy("G"))
	checks.append(assert_eq(processor.get_hp_modifier(slot, state), 250, "Six Grass Energy grants 250 HP"))
	slot.damage_counters = 80
	for effect in processor.get_attack_effects_for_slot(slot, 0):
		effect.execute_attack(slot, null, 0, state)
	checks.append(assert_eq(slot.damage_counters, 30, "Mega Drain heals exactly 50"))
	slot.attached_energy.pop_back()
	slot.attached_energy.append(_energy("C"))
	checks.append(assert_eq(processor.get_hp_modifier(slot, state), 0, "Colorless Energy does not meet the threshold"))
	state.shared_turn_flags.clear()
	processor.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_004_illumise_weakness_both_players_not_bench() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var source := _slot(_card(4), 0)
	var partner := _slot(_card(3), 0)
	state.players[0].bench.append(source)
	state.players[0].active_pokemon = partner
	state.players[1].active_pokemon = _slot(_card(1), 1)
	processor.register_pokemon_card(source.get_card_data())
	var checks: Array[String] = []
	for owner in 2:
		checks.append(assert_eq(processor.get_weakness_value_override(state.players[owner].active_pokemon, state.players[1-owner].active_pokemon, state), "x3", "Pheromone affects either player's Active weakness"))
	checks.append(assert_eq(processor.get_weakness_value_override(partner, source, state), "", "Bench weakness is not changed"))
	state.players[0].active_pokemon = _slot(_card(1), 0)
	checks.append(assert_eq(processor.get_weakness_value_override(state.players[0].active_pokemon, state.players[1].active_pokemon, state), "", "Requires Volbeat on source owner's field"))
	processor.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_051_and_055_second_attack_locks_all_attacks() -> String:
	var checks: Array[String] = []
	for index in [51, 55]:
		var gsm := _battle(index)
		var state := gsm.game_state
		var source := state.players[0].active_pokemon
		for i in 3:
			source.attached_energy.append(_energy("L" if index == 51 else "P"))
		checks.append(assert_true(gsm.use_attack(0, 1), "Second attack executes"))
		state.turn_number = 6
		state.current_player_index = 0
		state.phase = GameState.GamePhase.MAIN
		for attack_index in 2:
			checks.append(assert_false(RuleValidator.new().get_attack_unusable_reason(state, 0, attack_index, gsm.effect_processor).is_empty(), "Both attacks locked next own turn"))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_052_snack_only_recovers_from_newly_milled_top_three() -> String:
	var gsm := _battle(52)
	var state := gsm.game_state
	var source := state.players[0].active_pokemon
	var cards: Array[CardInstance] = [_energy("G"), _energy("L"), _energy("R"), _energy("P")]
	var old := _energy("W")
	state.players[0].deck.assign(cards)
	state.players[0].discard_pile.append(old)
	var effect := gsm.effect_processor.get_attack_effects_for_slot(source, 0)[0]
	var steps := effect.get_attack_interaction_steps(source.get_top_card(), source.get_card_data().attacks[0], state)
	var checks: Array[String] = [assert_eq(steps[0].get("card_items"), cards.slice(0, 3), "Only top three visible")]
	checks.append(assert_true(gsm.use_attack(0, 0, [{"pick_snack": [cards[1]]}]), "Pick Snack executes"))
	checks.append(assert_eq(state.players[0].deck, [cards[3]], "Exactly three milled"))
	checks.append(assert_eq(state.players[0].hand, [cards[1]], "Chosen new card recovered"))
	checks.append(assert_eq(state.players[0].discard_pile, [old, cards[0], cards[2]], "Old discard not recovered"))
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_053_discards_selected_two_lightning_not_fire() -> String:
	var gsm := _battle(53)
	var state := gsm.game_state
	var source := state.players[0].active_pokemon
	var energies: Array[CardInstance] = [_energy("L"), _energy("L"), _energy("L")]
	source.attached_energy.append_array(energies)
	var checks: Array[String] = [assert_true(gsm.use_attack(0, 1, [{"discard_typed_attached_energy_from_self": [energies[1], energies[2]]}]), "Miraidon attack executes")]
	checks.append(assert_eq(state.players[0].discard_pile, [energies[1], energies[2]], "Exactly selected Lightning discarded"))
	checks.append(assert_true(energies[0] in source.attached_energy, "Unselected Lightning retained"))
	checks.append(assert_eq(state.players[1].active_pokemon.damage_counters, 140, "Printed 140 damage"))
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_054_energy_absorption_one_chosen_target() -> String:
	var gsm := _battle(54)
	var state := gsm.game_state
	var source := state.players[0].active_pokemon
	source.attached_energy.append(_energy("P"))
	var bench := _slot(_card(1), 0)
	state.players[0].bench.append(bench)
	var energies: Array[CardInstance] = [_energy("G"), _energy("W")]
	state.players[0].discard_pile.assign(energies)
	var checks: Array[String] = [assert_true(gsm.use_attack(0, 0, [{"discard_energy": energies, "attach_target": [bench]}]), "Energy absorption executes")]
	checks.append(assert_eq(bench.attached_energy, energies, "Both energies attached to chosen Bench"))
	checks.append(assert_true(state.players[0].discard_pile.is_empty(), "Recovered energies leave discard"))
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_055_photon_bullet_hits_only_ex_with_active_weakness() -> String:
	var gsm := _battle(55)
	var state := gsm.game_state
	var source := state.players[0].active_pokemon
	source.attached_energy.append(_energy("P"))
	source.attached_energy.append(_energy("P"))
	var active := state.players[1].active_pokemon
	active.get_card_data().mechanic = "ex"
	active.get_card_data().weakness_energy = "P"
	active.get_card_data().weakness_value = "x2"
	var bench := _slot(_card(9), 1)
	var ordinary := _slot(_card(1), 1)
	state.players[1].bench.assign([bench, ordinary])
	var checks: Array[String] = [assert_true(gsm.use_attack(0, 0), "Photon Bullet executes")]
	checks.append(assert_eq(active.damage_counters, 100, "Active applies weakness"))
	checks.append(assert_eq(bench.damage_counters, 50, "Bench ex takes 50 without weakness"))
	checks.append(assert_eq(ordinary.damage_counters, 0, "Non-ex is untouched"))
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_056_to_060_real_json_registration() -> String:
	return _check_registration(56, 60)


func test_30thc_056_psychic_counts_energy_and_059_counts_distinct_basic_types() -> String:
	var checks: Array[String] = []
	for index in [56, 59]:
		var gsm := _battle(index)
		var state := gsm.game_state
		var source := state.players[0].active_pokemon
		source.attached_energy.assign([_energy("P"), _energy("P"), _energy("C")])
		var target := state.players[1].active_pokemon
		target.attached_energy.assign([_energy("L"), _energy("R")])
		if index == 59:
			var bench := _slot(_card(1), 0)
			bench.attached_energy.assign([_energy("P"), _energy("G")])
			state.players[0].bench.append(bench)
			# Test helper C is not a real Basic Energy; replace it with another Psychic.
			source.attached_energy[2] = _energy("P")
			var special := _energy("W")
			special.card_data.card_type = "Special Energy"
			bench.attached_energy.append(special)
		checks.append(assert_true(gsm.use_attack(0, 0), "Attack executes"))
		checks.append(assert_eq(target.damage_counters, 90 if index == 56 else 100, "Printed arithmetic: 10+2*40 or two distinct basic types*50"))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_058_returns_one_evolution_per_opponent_stack_to_hand() -> String:
	var gsm := _battle(58)
	var state := gsm.game_state
	state.players[0].active_pokemon.attached_energy.append(_energy("P"))
	var target := state.players[1].active_pokemon
	var top := CardInstance.create(_card(2), 1)
	target.pokemon_stack.append(top)
	var bench := _slot(_card(1), 1)
	var other := CardInstance.create(_card(2), 1)
	bench.pokemon_stack.append(other)
	state.players[1].bench.append(bench)
	var checks: Array[String] = [assert_true(gsm.use_attack(0, 0), "Miracle Beam executes")]
	checks.append(assert_eq(target.pokemon_stack.size(), 1, "Active devolves once"))
	checks.append(assert_eq(bench.pokemon_stack.size(), 1, "Bench devolves once"))
	checks.append(assert_true(top in state.players[1].hand and other in state.players[1].hand, "Both evolution cards returned to opponent hand"))
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_061_to_065_real_json_registration() -> String:
	return _check_registration(61, 65)


func test_30thc_061_optional_return_preserves_decline_and_selected_replacement() -> String:
	var checks: Array[String] = []
	for take in [false, true]:
		var gsm := _battle(61)
		var state := gsm.game_state
		var source := state.players[0].active_pokemon
		source.attached_energy.append(_energy("P"))
		var cards := source.collect_all_cards()
		var replacement := _slot(_card(1), 0)
		state.players[0].bench.append(replacement)
		var selection: Array = [replacement] if take else []
		checks.append(assert_true(gsm.use_attack(0, 0, [{"csv9c_return_self_replacement": selection}]), "Drifloon attacks"))
		checks.append(assert_eq(state.players[0].active_pokemon, replacement if take else source, "Optional branch respected"))
		checks.append(assert_eq(state.players[1].active_pokemon.damage_counters, 20, "Both branches deal 20 first"))
		if take:
			for card: CardInstance in cards:
				checks.append(assert_true(card in state.players[0].deck, "Pokemon and all attached cards shuffled into deck"))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_062_two_statuses_and_063_stadium_search_scope() -> String:
	var gsm := _battle(62)
	var state := gsm.game_state
	var source := state.players[0].active_pokemon
	var target := state.players[1].active_pokemon
	for effect in gsm.effect_processor.get_attack_effects_for_slot(source, 0):
		effect.execute_attack(source, target, 0, state)
	var checks: Array[String] = [assert_true(target.status_conditions.burned and target.status_conditions.confused, "Both Burn and Confusion applied")]
	gsm.prepare_for_disposal()
	gsm = _battle(63)
	state = gsm.game_state
	source = state.players[0].active_pokemon
	var stadium := _energy("G")
	stadium.card_data.card_type = "Stadium"
	var nonmatch := _energy("R")
	state.players[0].deck.assign([nonmatch, stadium])
	var effect := gsm.effect_processor.get_attack_effects_for_slot(source, 0)[0]
	var steps := effect.get_attack_interaction_steps(source.get_top_card(), source.get_card_data().attacks[0], state)
	checks.append(assert_eq(steps[0].get("card_items").size(), 2, "Whole own deck visible"))
	checks.append(assert_eq(steps[0].get("items"), [stadium], "Only Stadium selectable"))
	checks.append(assert_true(gsm.use_attack(0, 0, [{"search_cards": [stadium, nonmatch]}]), "Geomancy search executes"))
	checks.append(assert_eq(state.players[0].hand, [stadium], "Nonmatching Energy rejected"))
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_064_plain_damage_and_065_exact_reduction() -> String:
	var gsm := _battle(64)
	var checks: Array[String] = [assert_true(gsm.use_attack(0, 0), "Cosmog attacks"), assert_eq(gsm.game_state.players[1].active_pokemon.damage_counters, 10, "Splash deals 10")]
	gsm.prepare_for_disposal()
	gsm = _battle(65)
	var state := gsm.game_state
	var source := state.players[0].active_pokemon
	checks.append(assert_true(gsm.use_attack(0, 0), "Harden executes"))
	checks.append(assert_eq(gsm.effect_processor.get_defender_modifier(source, state, state.players[1].active_pokemon), -60, "Opponent next turn takes exactly 60 less"))
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_066_to_070_real_json_registration() -> String:
	return _check_registration(66, 70)


func test_30thc_070_tails_discards_trainers_without_using_them() -> String:
	var checks: Array[String] = []
	for kind in ["Item", "Supporter", "Tool", "Stadium"]:
		var gsm := _battle(70)
		var state := gsm.game_state
		state.players[0].active_pokemon.attached_energy.append(_energy("F"))
		checks.append(assert_true(gsm.use_attack(0, 0), "Vibration Punch executes"))
		var coin := FixedCoin.new()
		coin.heads = false
		gsm.effect_processor.coin_flipper = coin
		var trainer := _energy("C")
		trainer.owner_index = 1
		trainer.card_data.card_type = kind
		trainer.card_data.name = "Disruption test " + kind
		trainer.card_data.effect_id = "disruption_draw"
		gsm.effect_processor.register_effect("disruption_draw", EffectDrawCards.new(1))
		state.players[1].hand.assign([trainer])
		state.players[1].deck.assign([_energy("R"), _energy("W")])
		var accepted := false
		match kind:
			"Tool": accepted = gsm.attach_tool(1, trainer, state.players[1].active_pokemon)
			"Stadium": accepted = gsm.play_stadium(1, trainer)
			_: accepted = gsm.play_trainer(1, trainer, [])
		checks.append(assert_true(accepted, "Tails is a resolved attempt, not invalid action"))
		checks.append(assert_true(trainer in state.players[1].discard_pile, "Trainer discarded on tails"))
		checks.append(assert_eq(state.players[1].deck.size(), 2, "Effect not executed"))
		checks.append(assert_false(state.supporter_used_this_turn or state.stadium_played_this_turn, "No per-turn Trainer use consumed"))
		checks.append(assert_eq(coin.calls, 1, "Exactly one coin per play"))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_066_discard_counts_cards_and_069_selected_bench_damage() -> String:
	var checks: Array[String] = []
	for index in [66, 69]:
		var gsm := _battle(index)
		var state := gsm.game_state
		var source := state.players[0].active_pokemon
		source.attached_energy.append_array([_energy("P"), _energy("F"), _energy("F")])
		var special := _energy("ANY")
		special.card_data.card_type = "Special Energy"
		state.players[0].discard_pile.assign([_energy("L"), special, CardInstance.create(_card(1), 0)])
		var target := _slot(_card(2), 1)
		state.players[1].bench.append(target)
		checks.append(assert_true(gsm.use_attack(0, 0, [{"bench_target": [target]}]), "Attack executes"))
		checks.append(assert_eq(state.players[1].active_pokemon.damage_counters, 60 if index == 66 else 100, "Lunala counts two Energy cards, Lucario printed damage"))
		checks.append(assert_eq(target.damage_counters, 0 if index == 66 else 60, "Lucario chosen Bench takes 60"))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_067_coin_search_heads_and_tails_visibility() -> String:
	var checks: Array[String] = []
	for heads in [false, true]:
		var gsm := _battle(67)
		var state := gsm.game_state
		var source := state.players[0].active_pokemon
		var card := _energy("W")
		state.players[0].deck.append(card)
		var effect := gsm.effect_processor.get_attack_effects_for_slot(source, 0)[0]
		var coin := FixedCoin.new()
		coin.heads = heads
		effect.set("coin_flipper", coin)
		effect.get_attack_preview_interaction_steps(source.get_top_card(), source.get_card_data().attacks[0], state)
		checks.append(assert_eq(coin.calls, 0, "Preview cannot flip"))
		var steps := effect.get_attack_interaction_steps(source.get_top_card(), source.get_card_data().attacks[0], state)
		checks.append(assert_eq(steps.is_empty(), not heads, "Only heads reveals own deck"))
		checks.append(assert_true(gsm.use_attack(0, 0, [{"search_cards": [card]}]), "Roam executes"))
		checks.append(assert_eq(card in state.players[0].hand, heads, "Search only on heads"))
		checks.append(assert_eq(coin.calls, 1, "No reroll during commit"))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_068_hits_own_bench_except_tera() -> String:
	var gsm := _battle(68)
	var state := gsm.game_state
	for i in 5:
		state.players[0].active_pokemon.attached_energy.append(_energy("F"))
	var target := _slot(_card(27), 0)
	var tera := _slot(_card(59), 0)
	state.players[0].bench.assign([target, tera])
	var checks: Array[String] = [assert_true(gsm.use_attack(0, 0), "Earth Break executes")]
	checks.append(assert_eq(state.players[1].active_pokemon.damage_counters, 250, "250 to opponent Active"))
	checks.append(assert_eq(target.damage_counters, 20, "Opponent-only Hide does not prevent own damage"))
	checks.append(assert_eq(tera.damage_counters, 0, "Tera Bench rule blocks own attack too"))
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_070_heads_cached_between_declaration_and_commit() -> String:
	var gsm := _battle(70)
	var state := gsm.game_state
	state.players[0].active_pokemon.attached_energy.append(_energy("F"))
	gsm.use_attack(0, 0)
	var coin := FixedCoin.new()
	gsm.effect_processor.coin_flipper = coin
	var trainer := _energy("C")
	trainer.owner_index = 1
	trainer.card_data.card_type = "Supporter"
	trainer.card_data.effect_id = "heads_draw"
	gsm.effect_processor.register_effect("heads_draw", EffectDrawCards.new(1))
	state.players[1].hand.assign([trainer])
	state.players[1].deck.assign([_energy("L")])
	var checks: Array[String] = [assert_false(gsm.resolve_trainer_disruption(1, trainer), "Heads permits declared play")]
	checks.append(assert_true(gsm.play_trainer(1, trainer, []), "Heads commits"))
	checks.append(assert_eq(coin.calls, 1, "Commit reuses declared heads"))
	checks.append(assert_true(state.supporter_used_this_turn, "Successful Supporter consumes turn limit"))
	checks.append(assert_eq(state.players[1].hand.size(), 1, "Successful effect draws"))
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_071_to_075_real_json_registration() -> String:
	return _check_registration(71, 75)


func test_30thc_071_counter_uses_previous_attack_damage_not_current_counters() -> String:
	var gsm := _battle(71)
	var state := gsm.game_state
	var source := state.players[0].active_pokemon
	source.attached_energy.append(_energy("F"))
	state.turn_number = 3
	gsm.effect_processor.process_after_attack_damage(source, state.players[1].active_pokemon, 80, state)
	source.damage_counters = 10
	state.turn_number = 4
	var checks: Array[String] = [assert_true(gsm.use_attack(0, 0), "Counter executes")]
	checks.append(assert_eq(state.players[1].active_pokemon.damage_counters, 90, "Recorded 80 attack damage still counts after healing"))
	state.turn_number = 6
	checks.append(assert_eq(gsm.effect_processor.get_attack_effects_for_slot(source, 0)[0].get_damage_bonus(source, state), 0, "History expires after one opponent turn"))
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_072_discards_fighting_073_growl_and_075_free_draw() -> String:
	var checks: Array[String] = []
	for index in [72, 73, 75]:
		var gsm := _battle(index)
		var state := gsm.game_state
		var source := state.players[0].active_pokemon
		var energies: Array[CardInstance] = [_energy("F"), _energy("F")]
		source.attached_energy.append_array(energies)
		if index == 75:
			source.attached_energy.clear()
		checks.append(assert_true(gsm.use_attack(0, 1 if index == 72 else 0), "Attack executes with printed cost"))
		match index:
			72: checks.append(assert_eq(state.players[0].discard_pile, energies, "Both Fighting discarded"))
			73: checks.append(assert_eq(gsm.effect_processor.get_attacker_modifier(state.players[1].active_pokemon, state, source), -30, "Growl reduces outgoing damage 30 next turn"))
			75: checks.append(assert_eq(state.players[0].hand.size(), 1, "Zero-energy Pay Day draws one"))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_074_heals_one_chosen_own_pokemon_once() -> String:
	var gsm := _battle(74)
	var state := gsm.game_state
	var source := state.players[0].active_pokemon
	source.damage_counters = 50
	var target := _slot(_card(1), 0)
	target.damage_counters = 40
	state.players[0].bench.append(target)
	var checks: Array[String] = [assert_true(gsm.use_ability(0, source, 0, [{"heal_target": [target]}]), "Happiness Share executes")]
	checks.append(assert_eq(target.damage_counters, 10, "Chosen Pokemon heals 30"))
	checks.append(assert_eq(source.damage_counters, 50, "Unselected Pokemon not healed"))
	checks.append(assert_false(gsm.use_ability(0, source, 0, [{"heal_target": [source]}]), "Cannot repeat same turn"))
	state.current_player_index = 1
	checks.append(assert_false(gsm.effect_processor.get_effect(source.get_card_data().effect_id).can_use_ability(source, state), "Opponent turn disallowed"))
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_076_to_080_real_json_registration() -> String:
	return _check_registration(76, 80)


func test_30thc_079_blocks_opponent_active_heal_not_bench_or_counter_moves() -> String:
	var gsm := _battle(79)
	var state := gsm.game_state
	var target := state.players[1].active_pokemon
	target.damage_counters = 80
	var bench := _slot(_card(1), 1)
	bench.damage_counters = 50
	state.players[1].bench.append(bench)
	var card := _energy("C")
	card.owner_index = 1
	EffectHealAllPokemon.new(30).execute(card, [], state)
	var checks: Array[String] = [assert_eq(target.damage_counters, 80, "Yveltal blocks healing of opponent Active"), assert_eq(bench.damage_counters, 20, "Opponent Bench still heals")]
	state.players[0].active_pokemon = null
	EffectHeal.new(30).execute(card, [], state)
	checks.append(assert_eq(target.damage_counters, 50, "Healing resumes when Yveltal leaves play"))
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_076_counter_placement_is_not_attack_damage_and_death_sentence_coin() -> String:
	var gsm := _battle(76)
	var state := gsm.game_state
	var source := state.players[0].active_pokemon
	source.attached_energy.append_array([_energy("D"), _energy("D")])
	var target := _slot(_card(59), 1)
	state.players[1].bench.append(target)
	var checks: Array[String] = [assert_true(gsm.use_attack(0, 0, [{"opponent_pokemon_damage_counter_target": [target]}]), "Chaos Wound executes")]
	checks.append(assert_eq(target.damage_counters, 130, "13 counters bypass Tera damage-only shield"))
	var ability := gsm.effect_processor.get_effect(source.get_card_data().effect_id)
	var coin := FixedCoin.new()
	ability.set("coin_flipper", coin)
	var attacker := state.players[1].active_pokemon
	gsm.effect_processor.apply_attack_damage_knockout_reactive_effects(attacker, source, state)
	checks.append(assert_true(gsm.effect_processor.is_effectively_knocked_out(attacker, state), "Heads KOs actual attacker"))
	checks.append(assert_eq(coin.calls, 1, "Death Sentence flips once"))
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_077_only_damage_ko_bonus_078_shuffle_four_and_080_hand_multiplier() -> String:
	var checks: Array[String] = []
	for index in [77, 78, 80]:
		var gsm := _battle(index)
		var state := gsm.game_state
		var source := state.players[0].active_pokemon
		source.attached_energy.append_array([_energy("D"), _energy("M")])
		state.players[0].hand.assign([_energy("G"), _energy("W"), _energy("R")])
		for i in 6:
			state.players[1].hand.append(_energy("G"))
		if index == 77:
			state.shared_turn_flags["attack_damage_knockout_names:0:3"] = ["Ally"]
		checks.append(assert_true(gsm.use_attack(0, 1 if index == 80 else 0), "Attack executes"))
		match index:
			77: checks.append(assert_eq(state.players[1].active_pokemon.damage_counters, 130, "Revenge adds 100 to printed 30"))
			78: checks.append(assert_eq(state.players[1].hand.size(), 5, "Four redrawn, then normal draw for next turn"))
			80: checks.append(assert_eq(state.players[1].active_pokemon.damage_counters, 30, "Three-card hand deals 30"))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_081_to_085_real_json_registration() -> String:
	return _check_registration(81, 85)


func test_30thc_081_mandatory_seven_and_swift_ignores_weakness_and_protection() -> String:
	var checks: Array[String] = []
	for index in 2:
		var gsm := _battle(81)
		var state := gsm.game_state
		for i in 10:
			state.players[0].deck.append(_energy("M"))
		var target := state.players[1].active_pokemon
		target.get_card_data().weakness_energy = "M"
		target.get_card_data().weakness_value = "x2"
		target.effects.append({"type": "reduce_damage_next_turn", "amount": 60, "turn": 3})
		checks.append(assert_true(gsm.use_attack(0, index), "Jirachi attack executes"))
		checks.append(assert_eq(state.players[0].hand.size(), 7 if index == 0 else 0, "Draw seven is mandatory and first attack only"))
		checks.append(assert_eq(target.damage_counters, 0 if index == 0 else 150, "Swift ignores weakness and reduction"))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_082_returns_only_chosen_pokemon_and_basic_energy() -> String:
	var gsm := _battle(82)
	var state := gsm.game_state
	var pokemon := CardInstance.create(_card(1), 0)
	var energy := _energy("G")
	var special := _energy("L")
	special.card_data.card_type = "Special Energy"
	state.players[0].discard_pile.assign([pokemon, energy, special])
	var checks: Array[String] = [assert_true(gsm.use_attack(0, 0, [{"cards_to_return": [pokemon, energy]}]), "Reverse Clock executes")]
	checks.append(assert_eq(state.players[0].discard_pile, [special], "Special Energy not recoverable"))
	checks.append(assert_true(pokemon in state.players[0].deck and energy in state.players[0].deck, "Both selected cards shuffled into own deck"))
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_083_spread_and_self_damage() -> String:
	var gsm := _battle(83)
	var state := gsm.game_state
	var source := state.players[0].active_pokemon
	source.attached_energy.append_array([_energy("M"), _energy("M")])
	state.players[0].bench.append(_slot(_card(2), 0))
	var bench := _slot(_card(2), 1)
	state.players[1].bench.append(bench)
	var target := state.players[1].active_pokemon
	var checks: Array[String] = [assert_true(gsm.use_attack(0, 1), "Explosive Needles executes")]
	checks.append(assert_eq(target.damage_counters, 50, "50 to opponent Active"))
	checks.append(assert_eq(bench.damage_counters, 50, "50 to opponent Bench"))
	checks.append(assert_true(source.damage_counters >= 130 or source.pokemon_stack.is_empty(), "130 self damage KOs Ferrothorn"))
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_084_sunrise_bench_only_self_basic_metal_once() -> String:
	var gsm := _battle(84)
	var state := gsm.game_state
	var source := state.players[0].active_pokemon
	var energies: Array[CardInstance] = [_energy("M"), _energy("M")]
	state.players[0].deck.append_array(energies)
	var effect := gsm.effect_processor.get_effect(source.get_card_data().effect_id)
	var checks: Array[String] = [assert_false(effect.can_use_ability(source, state), "Cannot use Sunrise Active")]
	state.players[0].active_pokemon = _slot(_card(1), 0)
	state.players[0].bench.append(source)
	checks.append(assert_true(effect.can_use_ability(source, state), "Sunrise available from Bench"))
	checks.append(assert_true(gsm.use_ability(0, source, 0, [{"energy_assignments": [{"source": energies[0], "target": source}, {"source": energies[1], "target": source}]}]), "Selected two Metal attach to self"))
	checks.append(assert_true(energies[0] in source.attached_energy and energies[1] in source.attached_energy, "Both energies attached"))
	checks.append(assert_false(effect.can_use_ability(source, state), "Once per turn"))
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_085_tool_bonus_does_not_apply_to_second_attack() -> String:
	var gsm := _battle(85)
	var state := gsm.game_state
	var source := state.players[0].active_pokemon
	source.attached_energy.append(_energy("M"))
	source.attached_tool = _energy("C")
	source.attached_tool.card_data.card_type = "Tool"
	var checks: Array[String] = [assert_true(gsm.use_attack(0, 0), "Steely Blade executes"), assert_eq(state.players[1].active_pokemon.damage_counters, 60, "20+40 with a Tool")]
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_086_to_090_real_json_registration() -> String:
	return _check_registration(86, 90)


func test_30thc_086_removes_defender_tool_before_damage() -> String:
	var gsm := _battle(86)
	var state := gsm.game_state
	state.players[0].active_pokemon.attached_energy.append(_energy("M"))
	var target := state.players[1].active_pokemon
	var tool := _energy("C")
	tool.owner_index = 1
	tool.card_data.card_type = "Tool"
	target.attached_tool = tool
	var checks: Array[String] = [assert_true(gsm.use_attack(0, 0), "Knock Off executes")]
	checks.append(assert_eq(target.attached_tool, null, "Defender Tool discarded"))
	checks.append(assert_true(tool in state.players[1].discard_pile, "Tool goes to its owner's discard"))
	checks.append(assert_eq(target.damage_counters, 20, "Printed damage still dealt"))
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_087_exact_thirty_takes_selected_hidden_prizes_then_shuffles_hand() -> String:
	var checks: Array[String] = []
	for size in [29, 30, 31]:
		var gsm := _battle(87)
		var state := gsm.game_state
		var source := state.players[0].active_pokemon
		source.attached_energy.append(_energy("M"))
		for i in size:
			state.players[0].hand.append(_energy("M"))
		var prizes := state.players[0].prizes.duplicate()
		var effect := gsm.effect_processor.get_attack_effects_for_slot(source, 0)[0]
		var steps := effect.get_attack_interaction_steps(source.get_top_card(), source.get_card_data().attacks[0], state)
		if size == 30:
			checks.append(assert_false(steps[0].has("card_items"), "Hidden prize identities never exposed"))
		checks.append(assert_true(gsm.use_attack(0, 0, [{"festivity_prizes": [2, 5]}]), "Festivity executes"))
		checks.append(assert_eq(state.players[0].prizes.size(), 4 if size == 30 else 6, "Only exactly 30 takes two prizes"))
		checks.append(assert_eq(state.players[0].hand.size(), 0, "Entire hand then shuffled"))
		if size == 30:
			checks.append(assert_true(prizes[2] in state.players[0].deck and prizes[5] in state.players[0].deck, "Selected prizes join shuffled hand"))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_087_triple_smash_three_coins_before_weakness() -> String:
	var gsm := _battle(87)
	var state := gsm.game_state
	var source := state.players[0].active_pokemon
	source.attached_energy.append(_energy("M"))
	var coin := SequenceCoin.new()
	coin.results.assign([true, false, true])
	gsm.effect_processor.get_attack_effects_for_slot(source, 1)[0].set("coin_flipper", coin)
	state.players[1].active_pokemon.get_card_data().weakness_energy = "M"
	state.players[1].active_pokemon.get_card_data().weakness_value = "x2"
	var checks: Array[String] = [assert_true(gsm.use_attack(0, 1), "Triple Smash executes"), assert_eq(state.players[1].active_pokemon.damage_counters, 200, "Two heads 100 doubled by weakness"), assert_eq(coin.calls, 3, "Exactly three coins")]
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_088_revives_evolved_dragons_and_honors_explicit_zero() -> String:
	var checks: Array[String] = []
	for choose in [false, true]:
		var gsm := _battle(88)
		var state := gsm.game_state
		var dragon := CardInstance.create(_card(90), 0)
		var ordinary := CardInstance.create(_card(1), 0)
		state.players[0].discard_pile.assign([dragon, ordinary])
		checks.append(assert_true(gsm.use_attack(0, 0, [{"revive_from_discard": [dragon, ordinary] if choose else []}]), "Roaring Call executes"))
		checks.append(assert_eq(state.players[0].bench.size(), 1 if choose else 0, "Only selected Dragon revived, no auto-fill on decline"))
		checks.append(assert_true(ordinary in state.players[0].discard_pile, "Non-Dragon remains discarded"))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_089_screech_next_own_turn_only_and_090_plain_damage() -> String:
	var gsm := _battle(89)
	var state := gsm.game_state
	var source := state.players[0].active_pokemon
	var target := state.players[1].active_pokemon
	var checks: Array[String] = [assert_true(gsm.use_attack(0, 0), "Screech executes"), assert_eq(gsm.effect_processor.get_defender_modifier(target, state, source), 0, "No bonus during opponent's turn")]
	state.turn_number = 6
	checks.append(assert_eq(gsm.effect_processor.get_defender_modifier(target, state, source), 30, "Next own turn +30"))
	gsm.prepare_for_disposal()
	gsm = _battle(90)
	checks.append(assert_true(gsm.use_attack(0, 0), "Hakamo-o first attack executes"))
	checks.append(assert_eq(gsm.game_state.players[1].active_pokemon.damage_counters, 20, "Sharp Fang deals 20"))
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_091_to_095_real_json_registration() -> String:
	return _check_registration(91, 95)


func test_30thc_091_plain_attack_and_092_pay_day() -> String:
	var checks: Array[String] = []
	for index in [91, 92]:
		var gsm := _battle(index)
		gsm.game_state.players[0].active_pokemon.attached_energy.append_array([_energy("L"), _energy("F")])
		checks.append(assert_true(gsm.use_attack(0, 0), "Attack executes"))
		checks.append(assert_eq(gsm.game_state.players[1].active_pokemon.damage_counters, 250 if index == 91 else 30, "Printed damage preserved"))
		checks.append(assert_eq(gsm.game_state.players[0].hand.size(), 0 if index == 91 else 1, "Only Pay Day draws"))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_093_transforms_into_stage_two_preserving_all_attached_state() -> String:
	var gsm := _battle(93)
	var state := gsm.game_state
	var source := state.players[0].active_pokemon
	var original := source.get_top_card()
	var energy := source.attached_energy.duplicate()
	var replacement := CardInstance.create(_card(91), 0)
	state.players[0].deck.append(replacement)
	source.damage_counters = 20
	source.status_conditions.poisoned = true
	source.effects.append({"type": "preserved_probe", "value": 12})
	var effect := gsm.effect_processor.get_attack_effects_for_slot(source, 0)[0]
	var coin := FixedCoin.new()
	effect.set("coin_flipper", coin)
	effect.get_attack_interaction_steps(original, original.card_data.attacks[0], state)
	# Execute effect directly to separate inheritance from subsequent Pokemon Check poison.
	effect.set_attack_interaction_context([{"search_cards": [replacement]}])
	effect.execute_attack(source, state.players[1].active_pokemon, 0, state)
	var checks: Array[String] = [assert_eq(source.get_top_card(), replacement, "Any Pokemon including Stage 2 may replace Ditto"), assert_eq(source.attached_energy, energy, "All Energy retained"), assert_eq(source.damage_counters, 20, "Damage retained"), assert_true(source.status_conditions.poisoned, "Status retained"), assert_eq(source.effects[0].get("value"), 12, "Effects retained"), assert_true(original in state.players[0].deck, "Only Ditto goes back to deck"), assert_eq(coin.calls, 1, "One coin across selection and commit")]
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_094_reveals_hand_but_only_item_is_selectable() -> String:
	var gsm := _battle(94)
	var state := gsm.game_state
	var source := state.players[0].active_pokemon
	var item := _energy("C")
	item.card_data.card_type = "Item"
	var supporter := _energy("C")
	supporter.card_data.card_type = "Supporter"
	state.players[1].hand.assign([supporter, item])
	var effect := gsm.effect_processor.get_attack_effects_for_slot(source, 0)[0]
	var steps := effect.get_attack_interaction_steps(source.get_top_card(), source.get_card_data().attacks[0], state)
	var checks: Array[String] = [assert_eq(steps[0].get("card_items").size(), 2, "Entire opponent hand revealed as permitted"), assert_eq(steps[0].get("items"), [item], "Only Item selectable")]
	checks.append(assert_true(gsm.use_attack(0, 0, [{"bury_item": [item]}]), "Bury executes"))
	checks.append(assert_eq(state.players[1].deck.back(), item, "Chosen Item placed bottom without shuffle"))
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_095_heals_only_when_sleep_recovery_fails() -> String:
	var checks: Array[String] = []
	for heads in [false, true]:
		var gsm := _battle(95)
		var source := gsm.game_state.players[0].active_pokemon
		source.damage_counters = 50
		var coin := FixedCoin.new()
		coin.heads = heads
		gsm.effect_processor.coin_flipper = coin
		checks.append(assert_true(gsm.use_attack(0, 0), "Snorlax's attack executes then sleeps"))
		checks.append(assert_eq(source.status_conditions.asleep, not heads, "Sleep coin outcome"))
		checks.append(assert_eq(source.damage_counters, 50 if heads else 0, "Only still sleeping heals all"))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_096_to_100_real_json_registration() -> String:
	return _check_registration(96, 100)


func test_30thc_096_counts_only_thirty_max_hp_bench() -> String:
	var gsm := _battle(96)
	var state := gsm.game_state
	state.players[0].active_pokemon.attached_energy.clear()
	state.players[0].bench.assign([_slot(_card(96), 0), _slot(_card(96), 0), _slot(_card(1), 0)])
	var checks: Array[String] = [assert_true(gsm.use_attack(0, 0), "Soft Circle needs no Energy"), assert_eq(state.players[1].active_pokemon.damage_counters, 60, "Two 30-HP Bench, excluding self and 60-HP Basic")]
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_097_discards_exact_selected_fire_water_lightning() -> String:
	var gsm := _battle(97)
	var state := gsm.game_state
	var source := state.players[0].active_pokemon
	var energies: Array[CardInstance] = [_energy("R"), _energy("W"), _energy("L")]
	source.attached_energy.append_array(energies)
	var checks: Array[String] = [assert_true(gsm.use_attack(0, 0, [{"discard_typed_attached_energy_from_self": energies}]), "Elemental Blast executes")]
	checks.append(assert_eq(state.players[0].discard_pile.size(), 3, "Three selected units discarded"))
	for energy: CardInstance in energies:
		checks.append(assert_true(energy in state.players[0].discard_pile, "Selected energy discarded"))
	checks.append(assert_eq(source.attached_energy.size(), 5, "Other attached energy retained"))
	checks.append(assert_eq(state.players[1].active_pokemon.damage_counters, 250, "250 damage"))
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_098_plain_scratch_099_counter_floor_fifty() -> String:
	var checks: Array[String] = []
	for remaining in [40, 200]:
		var gsm := _battle(99)
		var target := gsm.game_state.players[1].active_pokemon
		target.damage_counters = 1000 - remaining
		checks.append(assert_true(gsm.use_attack(0, 1), "Grudge Vortex executes"))
		checks.append(assert_eq(target.get_remaining_hp(), mini(remaining, 50), "Never heals a target below 50 HP"))
		gsm.prepare_for_disposal()
	var gsm := _battle(98)
	checks.append(assert_true(gsm.use_attack(0, 0), "Zorua Scratch executes"))
	checks.append(assert_eq(gsm.game_state.players[1].active_pokemon.damage_counters, 20, "20 damage"))
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_100_counts_own_named_maushold_and_mills_two_per_head() -> String:
	var gsm := _battle(100)
	var state := gsm.game_state
	var source := state.players[0].active_pokemon
	state.players[0].bench.assign([_slot(_card(100), 0), _slot(_card(1), 0)])
	state.players[1].bench.append(_slot(_card(100), 1))
	for i in 6:
		state.players[1].deck.append(_energy("L"))
	var coin := SequenceCoin.new()
	coin.results.assign([true, false])
	gsm.effect_processor.get_attack_effects_for_slot(source, 0)[0].set("coin_flipper", coin)
	var checks: Array[String] = [assert_true(gsm.use_attack(0, 0), "Gnaw Together executes"), assert_eq(coin.calls, 2, "Only two own Maushold produce coins"), assert_eq(state.players[1].discard_pile.size(), 2, "One head mills two cards")]
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_101_to_105_real_json_registration() -> String:
	return _check_registration(101, 105)


func test_30thc_101_ultra_ball_pays_two_and_searches_chosen_real_pokemon() -> String:
	var gsm := _battle(1)
	var state := gsm.game_state
	var trainer := CardInstance.create(_card(101), 0)
	var costs: Array[CardInstance] = [_energy("L"), _energy("R")]
	state.players[0].hand.assign([trainer, costs[0], costs[1]])
	var chosen := CardInstance.create(_card(76), 0)
	state.players[0].deck.append(chosen)
	var checks: Array[String] = [assert_true(gsm.play_trainer(0, trainer, [{"discard_cards": costs, "search_pokemon": [chosen]}]), "Ultra Ball plays through real Trainer entry")]
	checks.append(assert_eq(state.players[0].hand, [chosen], "Chosen Pokemon enters hand"))
	checks.append(assert_eq(state.players[0].discard_pile.size(), 3, "Both costs plus Ultra Ball discarded"))
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_102_poke_pad_full_deck_visible_but_rule_box_excluded() -> String:
	var gsm := _battle(1)
	var state := gsm.game_state
	var trainer := CardInstance.create(_card(102), 0)
	state.players[0].hand.append(trainer)
	var ordinary := CardInstance.create(_card(91), 0)
	var rule_box := CardInstance.create(_card(76), 0)
	state.players[0].deck.append_array([ordinary, rule_box])
	var effect := gsm.effect_processor.get_effect(trainer.card_data.effect_id)
	var steps := effect.get_interaction_steps(trainer, state)
	var checks: Array[String] = [assert_eq(steps[0].get("card_items").size(), 3, "All own deck cards visible"), assert_eq(steps[0].get("items"), [ordinary], "Only non-rule-box Pokemon selectable")]
	checks.append(assert_true(gsm.play_trainer(0, trainer, [{"search_pokemon": [ordinary]}]), "Poke Pad executes"))
	checks.append(assert_eq(state.players[0].hand, [ordinary], "Selected ordinary Stage 2 found"))
	checks.append(assert_true(rule_box in state.players[0].deck, "Rule-box Pokemon remains in deck"))
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_103_switch_selected_nonfirst_bench() -> String:
	var gsm := _battle(1)
	var state := gsm.game_state
	var trainer := CardInstance.create(_card(103), 0)
	state.players[0].hand.append(trainer)
	var target := _slot(_card(2), 0)
	state.players[0].bench.assign([_slot(_card(3), 0), target])
	var checks: Array[String] = [assert_true(gsm.play_trainer(0, trainer, [{"self_switch_target": [target]}]), "Switch executes"), assert_eq(state.players[0].active_pokemon, target, "Selected non-first target becomes Active")]
	gsm.prepare_for_disposal()
	return run_checks(checks)


func _card(index: int) -> CardData:
	if index == 57:
		return CardData.from_dict(JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/30THC_057.json")))
	return CardData.from_dict(JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/30thC_%03d.json" % index)))


func test_30thc_review_devolution_clears_status_effects_preserves_counters_and_respects_bench_protection() -> String:
	var gsm := _battle(58)
	var state := gsm.game_state
	var target := state.players[1].active_pokemon
	target.pokemon_stack.append(CardInstance.create(_card(74), 1))
	target.damage_counters = 20
	target.status_conditions.poisoned = true
	target.effects.append({"type": "attack_lock_all", "turn": state.turn_number})
	var hidden := _slot(_card(1), 1)
	hidden.pokemon_stack.append(CardInstance.create(_card(27), 1))
	state.players[1].bench.append(hidden)
	gsm.effect_processor.register_pokemon_card(hidden.get_card_data())
	var effect := gsm.effect_processor.get_attack_effects_for_slot(state.players[0].active_pokemon, 0)[0]
	effect.execute_attack(state.players[0].active_pokemon, target, 0, state)
	var checks: Array[String] = [assert_false(target.has_any_status(), "Devolution clears Special Conditions"), assert_true(target.effects.is_empty(), "Devolution clears effects"), assert_eq(target.damage_counters, 20, "Damage counters stay"), assert_eq(hidden.pokemon_stack.size(), 2, "Hide prevents devolution on Bench")]
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_review_energy_discard_headless_steps_and_multi_unit_card() -> String:
	var gsm := _battle(6)
	var state := gsm.game_state
	var source := state.players[0].active_pokemon
	var dte := CardInstance.create(CardData.from_dict(JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/CSNC_024.json"))), 0)
	source.attached_energy.assign([_energy("R"), _energy("R"), dte])
	var effect := gsm.effect_processor.get_attack_effects_for_slot(source, 0)[0]
	var steps := effect.get_attack_interaction_steps(source.get_top_card(), source.get_card_data().attacks[0], state)
	var first: CardInstance = steps[0].items[0]
	var followups := effect.get_followup_attack_interaction_steps(source.get_top_card(), source.get_card_data().attacks[0], state, {"discard_typed_attached_energy_from_self": [first]})
	var checks: Array[String] = [assert_eq(steps[0].max_select, 1, "Discard interaction selects one Energy card at a time"), assert_eq(followups.size(), 1, "One basic unit requires a second Energy choice")]
	checks.append(assert_true(gsm.use_attack(0, 0, [{"discard_typed_attached_energy_from_self": [dte]}]), "One Double Turbo pays two discarded units"))
	checks.append(assert_eq(source.attached_energy.size(), 2, "Exactly one multi-unit Energy card discarded"))
	checks.append(assert_true(dte in state.players[0].discard_pile, "Selected Double Turbo discarded"))
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_review_070_real_ui_controller_and_headless_discard_before_search() -> String:
	var checks: Array[String] = []
	for ui in [true, false]:
		var gsm := _battle(1)
		var state := gsm.game_state
		var trainer := CardInstance.create(_card(102), 0)
		state.players[0].hand.append(trainer)
		state.players[0].deck.append(CardInstance.create(_card(2), 0))
		state.shared_turn_flags["trainer_disruption:0"] = state.turn_number
		var coin := FixedCoin.new()
		coin.heads = false
		gsm.effect_processor.coin_flipper = coin
		if ui:
			var surface := ReviewUISurface.new()
			surface._gsm = gsm
			BattleActionController.new().try_play_trainer_with_interaction(surface, 0, trainer)
			checks.append(assert_true(surface.refreshed, "Real UI controller refreshes after discarded Trainer"))
			checks.append(assert_eq(surface.prompts, 0, "UI must not reveal deck on tails"))
		else:
			var bridge := HeadlessMatchBridge.new()
			bridge.bind(gsm)
			checks.append(assert_true(bridge._try_play_trainer_with_interaction(0, trainer), "Real headless Trainer entry resolves tails"))
			checks.append(assert_false(bridge.has_pending_prompt(), "Headless must not open search on tails"))
			bridge.bind(null)
			bridge.free()
		checks.append(assert_eq(coin.calls, 1, "Exactly one declaration coin"))
		checks.append(assert_true(trainer in state.players[0].discard_pile, "Trainer discarded without playing"))
		checks.append(assert_true(state.players[0].hand.is_empty(), "No search result enters hand"))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_review_energy_sequential_headless_and_duplicate_rejection() -> String:
	var gsm := _battle(97)
	var state := gsm.game_state
	var source := state.players[0].active_pokemon
	source.attached_energy.assign([_energy("R"), _energy("W"), _energy("L")])
	var effect := gsm.effect_processor.get_attack_effects_for_slot(source, 0)[0]
	var checks: Array[String] = [assert_false(bool(effect.validate_attack_interaction(source, 0, [{"discard_typed_attached_energy_from_self": [source.attached_energy[0], source.attached_energy[0], source.attached_energy[0]]}], state).valid), "Duplicate Energy cannot pay three units")]
	var bridge := HeadlessMatchBridge.new()
	bridge.bind(gsm)
	checks.append(assert_true(bridge._try_use_attack_with_interaction(0, source, 0), "Lugia creates real headless discard prompt"))
	for i in 3:
		checks.append(assert_true(bridge.has_pending_prompt(), "Required unit creates fresh window"))
		bridge._handle_effect_interaction_choice(PackedInt32Array([0]))
	checks.append(assert_eq(source.attached_energy.size(), 0, "Three sequential decisions discard R/W/L"))
	checks.append(assert_eq(state.players[1].active_pokemon.damage_counters, 250, "Headless attack commits damage"))
	bridge.bind(null)
	bridge.free()
	gsm.prepare_for_disposal()
	return run_checks(checks)


func _check_review_evolution_lines(lines: Array) -> String:
	var checks: Array[String] = []
	for line: Array in lines:
		for name: String in [str(line[1]), str(line[2])]:
			var gsm := _battle(1)
			var state := gsm.game_state
			var data := _card(1)
			data.name = name
			data.name_en = ""
			data.name_zh = ""
			var target := _slot(data, 0)
			state.players[0].bench.append(target)
			var evolution := CardInstance.create(_card(line[0]), 0)
			state.players[0].hand.append(evolution)
			var candy := EffectRareCandy.new()
			var trainer_data := CardData.new()
			trainer_data.card_type = "Item"
			trainer_data.effect_id = "30thc_review_candy"
			var trainer := CardInstance.create(trainer_data, 0)
			state.players[0].hand.append(trainer)
			gsm.effect_processor.register_effect(trainer_data.effect_id, candy)
			checks.append(assert_true(candy._matches_stage_one_basic_override(evolution.card_data.evolves_from, data), "Stable bilingual missing-Stage-1 mapping: " + name))
			var steps := candy.get_interaction_steps(trainer, state)
			checks.append(assert_eq(steps[0].items.size(), 1, "Only same-line evolution pair selectable"))
			checks.append(assert_eq(steps[0].items[0].target_slot, target, "Non-first Basic selected by evolution line"))
			target.turn_played = state.turn_number
			checks.append(assert_false(candy._can_rare_candy_evolve(evolution, target, state), "Newly played Basic cannot evolve"))
			target.turn_played = 0
			checks.append(assert_true(gsm.play_trainer(0, trainer, [{"rare_candy_evolve": [steps[0].items[0]]}]), "Rare Candy core entry executes"))
			checks.append(assert_eq(target.get_top_card(), evolution, "Stage 2 lands on same-line Basic"))
			gsm.prepare_for_disposal()
		var normal := _battle(1)
		var stage_two := CardInstance.create(_card(line[0]), 0)
		var stage_one := _card(1)
		stage_one.name = stage_two.card_data.evolves_from
		stage_one.stage = "Stage 1"
		var normal_target := _slot(stage_one, 0)
		normal.game_state.players[0].bench.append(normal_target)
		normal.game_state.players[0].hand.append(stage_two)
		checks.append(assert_false(normal.evolve_pokemon(0, stage_two, normal.game_state.players[0].active_pokemon), "Normal evolution rejects wrong Basic"))
		checks.append(assert_true(normal.evolve_pokemon(0, stage_two, normal_target), "Normal same-line Stage 1 to Stage 2 executes"))
		normal.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_review_evolution_batch_one() -> String:
	return _check_review_evolution_lines([[5, "粉蝶虫", "Scatterbug"], [15, "呱呱泡蛙", "Froakie"], [62, "烛光灵", "Litwick"], [66, "科斯莫古", "Cosmog"], [70, "圆蝌蚪", "Tympole"]])


func test_30thc_review_evolution_batch_two() -> String:
	return _check_review_evolution_lines([[76, "鬼斯", "Gastly"], [84, "科斯莫古", "Cosmog"], [88, "宝贝龙", "Bagon"], [91, "心鳞宝", "Jangmo-o"]])


func test_30thc_review_search_whiff_does_not_leak_deck_contents_to_legality() -> String:
	var gsm := _battle(1)
	var state := gsm.game_state
	var sun := _slot(_card(84), 0)
	state.players[0].bench.append(sun)
	gsm.effect_processor.register_pokemon_card(sun.get_card_data())
	var effect := gsm.effect_processor.get_effect(sun.get_card_data().effect_id)
	var checks: Array[String] = [assert_true(effect.can_use_ability(sun, state), "Sunrise can search and fail in nonempty deck with no Metal Energy")]
	var steps := effect.get_interaction_steps(sun.get_top_card(), state)
	checks.append(assert_false(steps.is_empty(), "Whiff still offers legal deck inspection"))
	checks.append(assert_true(gsm.use_ability(0, sun, 0, [{"energy_assignments": []}]), "Zero-card Sunrise resolves"))
	checks.append(assert_false(effect.can_use_ability(sun, state), "Whiff consumes once-per-turn use"))
	var pad := CardInstance.create(_card(102), 0)
	var pad_effect := gsm.effect_processor.get_effect(pad.card_data.effect_id)
	checks.append(assert_eq(pad_effect.can_headless_execute(pad, state), pad_effect.can_execute(pad, state), "Poke Pad core and headless whiff legality agree"))
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_review_target_damage_writes_public_damage_event() -> String:
	var gsm := _battle(32)
	var state := gsm.game_state
	state.players[0].active_pokemon.attached_energy.append(_energy("L"))
	var chosen := _slot(_card(2), 1)
	state.players[1].bench.append(chosen)
	var checks: Array[String] = [assert_true(gsm.use_attack(0, 0, [{"any_target": [chosen]}]), "Selected target attack executes")]
	var events: Array = state.shared_turn_flags.get("_attack_effect_damage_targets", [])
	checks.append(assert_true(events.any(func(event: Dictionary) -> bool: return event.get("slot_kind") == "bench" and int(event.get("slot_index", -1)) == 0), "Replay/VFX receives actual damaged Bench target"))
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_review_target_damage_honors_selected_handheld_fan_reaction() -> String:
	var gsm := _battle(32)
	var state := gsm.game_state
	var source := state.players[0].active_pokemon
	var energy := _energy("L")
	source.attached_energy.append(energy)
	var destination := _slot(_card(2), 0)
	state.players[0].bench.assign([_slot(_card(3), 0), destination])
	var tool := CardData.new()
	tool.card_type = "Tool"
	tool.effect_id = "1bc2bed91258ca0ecfb69e5ee8dc0c79"
	var target := state.players[1].active_pokemon
	target.attached_tool = CardInstance.create(tool, 1)
	var checks: Array[String] = [assert_true(gsm.use_attack(0, 0, [{"any_target": [target], "handheld_fan_assignment": [{"source": energy, "target": destination}]}]), "Text-based active damage executes")]
	checks.append(assert_true(energy in destination.attached_energy, "Fan honors defender-selected Energy and non-first destination"))
	checks.append(assert_false(energy in source.attached_energy, "Selected Energy leaves attacker"))
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_review_headless_target_damage_keeps_defender_reaction_choice() -> String:
	var gsm := _battle(32)
	var state := gsm.game_state
	var source := state.players[0].active_pokemon
	source.attached_energy.append(_energy("L"))
	state.players[0].bench.assign([_slot(_card(3), 0), _slot(_card(2), 0)])
	var tool := CardData.new()
	tool.card_type = "Tool"
	tool.effect_id = "1bc2bed91258ca0ecfb69e5ee8dc0c79"
	state.players[1].active_pokemon.attached_tool = CardInstance.create(tool, 1)
	var bridge := HeadlessMatchBridge.new()
	bridge.bind(gsm)
	var checks: Array[String] = [assert_true(bridge._try_use_attack_with_interaction(0, source, 0), "Target attack creates interaction")]
	bridge._handle_effect_interaction_choice(PackedInt32Array([0]))
	checks.append(assert_true(bridge.has_pending_prompt(), "Defender reaction must not silently choose first Energy/destination"))
	if bridge.has_pending_prompt():
		var step: Dictionary = bridge._pending_effect_steps[bridge._pending_effect_step_index]
		checks.append(assert_eq(step.get("id"), "handheld_fan_assignment", "Fan assignment follows attack target"))
		checks.append(assert_eq(bridge._resolve_effect_step_chooser_player(step), 1, "Defender owns reaction window"))
	bridge.bind(null)
	bridge.free()
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_review_036_heads_whiff_still_opens_deck_search() -> String:
	var gsm := _battle(36)
	var state := gsm.game_state
	var source := state.players[0].active_pokemon
	state.players[0].deck.assign([_energy("W")])
	var effect := gsm.effect_processor.get_attack_effects_for_slot(source, 0)[0]
	var coin := SequenceCoin.new()
	coin.results.assign([true, false])
	effect.set("coin_flipper", coin)
	var steps := effect.get_attack_interaction_steps(source.get_top_card(), source.get_card_data().attacks[0], state)
	var checks: Array[String] = [assert_false(steps.is_empty(), "Heads permits deck inspection even without matching Energy")]
	if not steps.is_empty():
		var followup := effect.get_followup_attack_interaction_steps(source.get_top_card(), source.get_card_data().attacks[0], state, {"empty_search_resolution": [false]})
		checks.append(assert_false(followup.is_empty(), "View-deck choice creates readonly followup"))
		if not followup.is_empty():
			checks.append(assert_eq(followup[0].get("items", []).size(), 1, "Entire deck is visible in committed search followup"))
	checks.append(assert_true(gsm.use_attack(0, 0, [{"deck_energy": []}]), "Whiff resolves without attachment"))
	checks.append(assert_eq(coin.calls, 2, "Cached coin is not rerolled"))
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_review_real_reversal_energy_counts_three_units_and_prize_condition() -> String:
	var gsm := _battle(2)
	var state := gsm.game_state
	var source := state.players[0].active_pokemon
	state.players[1].prizes.pop_back()
	var energy_data := CardData.from_dict(JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/CSV2C_128.json")))
	source.attached_energy.assign([CardInstance.create(energy_data, 0), CardInstance.create(energy_data, 0)])
	var checks: Array[String] = [assert_eq(gsm.effect_processor.get_effective_max_hp(source, state), 400, "Two actual Reversal Energy provide six Grass units for Exeggutor")]
	var effect = load("res://scripts/effects/ThirtiethCelebrationEffects.gd").AttackDiscardEnergyRequirements.new("RWL", 0)
	checks.append(assert_true(bool(effect.validate_attack_interaction(source, 0, [{"discard_typed_attached_energy_from_self": [source.attached_energy[1]]}], state).valid), "One Reversal Energy pays R/W/L simultaneously"))
	state.players[0].prizes.pop_back()
	checks.append(assert_eq(gsm.effect_processor.get_effective_max_hp(source, state), 150, "Equal prizes downgrade Reversal to Colorless"))
	checks.append(assert_false(bool(effect.validate_attack_interaction(source, 0, [{"discard_typed_attached_energy_from_self": [source.attached_energy[1]]}], state).valid), "Cannot select nonmatching Colorless Energy when zero typed units exist"))
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_review_image_candidates_cover_case_sensitive_bundle_and_database_load() -> String:
	var db = load("res://scripts/autoload/CardDatabase.gd").new()
	var checks: Array[String] = []
	for index in [1, 105, 135]:
		var card: CardData = db.get_card("30thC", "%03d" % index)
		checks.append(assert_not_null(card, "CardDatabase loads installed printing"))
		var candidates := CardData.get_image_candidate_paths("30thC", "%03d" % index)
		checks.append(assert_true("res://data/bundled_user/cards/images/30THC/%03d.png.bin" % index in candidates, "Case-sensitive bundle path is explicit"))
		checks.append(assert_false(CardData.resolve_existing_image_path(candidates).is_empty(), "Image decodes from actual installed assets"))
	db.free()
	return run_checks(checks)


func test_30thc_review_061_last_pokemon_may_decline_or_return_and_lose() -> String:
	var checks: Array[String] = []
	for should_return in [false, true]:
		var gsm := _battle(61)
		var state := gsm.game_state
		var source := state.players[0].active_pokemon
		source.attached_energy.append(_energy("P"))
		var effect := gsm.effect_processor.get_attack_effects_for_slot(source, 0)[0]
		var steps := effect.get_attack_interaction_steps(source.get_top_card(), source.get_card_data().attacks[0], state)
		checks.append(assert_eq(steps.size(), 1, "Last Pokemon retains optional return choice"))
		checks.append(assert_true(gsm.use_attack(0, 0, [{"drifloon_return_alone": [should_return]}]), "Drifting resolves optional choice"))
		checks.append(assert_eq(state.players[0].active_pokemon == null, should_return, "Only affirmative choice removes last Pokemon"))
		checks.append(assert_eq(state.is_game_over(), should_return, "Returning last Pokemon loses after attack"))
		gsm.prepare_for_disposal()
	return run_checks(checks)


func _check_printing_pairs(pairs: Array) -> String:
	var processor := EffectProcessor.new()
	var checks: Array[String] = []
	for pair: Array in pairs:
		var card := _card(pair[0])
		var base := _card(pair[1])
		var a := card.to_dict()
		var b := base.to_dict()
		for key in ["name", "effect_id", "description", "mechanic", "label", "is_tags", "attacks", "abilities", "energy_type", "stage", "evolves_from", "hp", "weakness_energy", "weakness_value", "resistance_energy", "resistance_value", "retreat_cost"]:
			checks.append(assert_eq(a.get(key), b.get(key), "%03d rules match %03d: %s" % [pair[0], pair[1], key]))
		processor.register_pokemon_card(card)
		checks.append(assert_false(CardImplementationStatus.is_unimplemented(card), "Alternate printing registers"))
		var slot := _slot(card, 0)
		for index in card.attacks.size():
			if not str(card.attacks[index].get("text", "")).is_empty():
				checks.append(assert_false(processor.get_attack_effects_for_slot(slot, index).is_empty(), "Alternate rules-bearing attack wired"))
	processor.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_printings_104_to_105() -> String:
	return _check_printing_pairs([[104, 2], [105, 6]])


func test_30thc_printings_106_to_110() -> String:
	return _check_printing_pairs([[106, 11], [107, 12], [108, 49], [109, 51], [110, 52]])


func test_30thc_printings_111_to_115() -> String:
	return _check_printing_pairs([[111, 61], [112, 62], [113, 71], [114, 74], [115, 75]])


func test_30thc_printings_116_to_121() -> String:
	return _check_printing_pairs([[116, 78], [117, 80], [118, 87], [120, 92], [121, 93]])


func test_30thc_printings_122_to_126() -> String:
	return _check_printing_pairs([[122, 98], [123, 100], [124, 9], [125, 15], [126, 47]])


func test_30thc_printings_127_to_134() -> String:
	return _check_printing_pairs([[127, 48], [130, 59], [132, 81], [133, 88], [134, 55]])


func test_30thc_printings_135_mew_copies_real_unown_and_earns_extra_prize() -> String:
	var gsm := _battle(135)
	var state := gsm.game_state
	var source := state.players[0].active_pokemon
	var unown := _slot(_card(60), 0)
	state.players[0].bench.append(unown)
	gsm.effect_processor.register_pokemon_card(unown.get_card_data())
	var grants := gsm.effect_processor.get_granted_attacks(source, state)
	var checks: Array[String] = [assert_eq(grants.size(), 1, "Chinese Mew grants real Unown attack")]
	if grants.size() == 1:
		source.attached_energy.assign([_energy("P")])
		checks.append(assert_false(gsm.rule_validator.can_use_granted_attack(state, 0, source, grants[0], gsm.effect_processor), "Copied PP cost still applies"))
		source.attached_energy.append(_energy("P"))
		state.players[1].active_pokemon.get_card_data().hp = 40
		state.players[1].bench.append(_slot(_card(1), 1))
		checks.append(assert_true(gsm.use_granted_attack(0, source, grants[0]), "Copied real attack executes"))
		checks.append(assert_eq(int(gsm.get("_pending_prize_remaining")), 2, "Real Unown damage KO earns extra prize"))
	gsm.prepare_for_disposal()
	return run_checks(checks)


func _check_basic_energy_printings(indices: Array, symbols: Array) -> String:
	var processor := EffectProcessor.new()
	var state := _state()
	var checks: Array[String] = []
	for i in indices.size():
		var card := CardData.from_dict(JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/cards/30thC_%s.json" % indices[i])))
		var energy := CardInstance.create(card, 0)
		checks.append(assert_eq(card.card_type, "Basic Energy", "Real basic energy printing"))
		checks.append(assert_eq(card.regulation_mark, "G", "Energy regulation mark G"))
		checks.append(assert_eq(card.energy_provides, symbols[i], "Correct energy type"))
		checks.append(assert_eq(processor.get_energy_colorless_count(energy, state), 1, "Provides exactly one unit"))
		checks.append(assert_true(symbols[i] in processor.get_energy_types(energy, state), "Rule consumer sees correct type"))
	processor.prepare_for_disposal()
	return run_checks(checks)


func test_30thc_printings_basic_energy_grass_fire_water_lightning() -> String:
	return _check_basic_energy_printings(["GRA", "FIR", "WAT", "LIG"], ["G", "R", "W", "L"])


func test_30thc_printings_basic_energy_psychic_fighting_darkness_metal() -> String:
	return _check_basic_energy_printings(["PSY", "FIG", "DAR", "MET"], ["P", "F", "D", "M"])


func test_30thc_005_vivillon_rare_candy_without_stage_one_reference() -> String:
	var state := _state()
	state.turn_number = 4
	var basic := CardData.new()
	basic.name = "Scatterbug"
	basic.card_type = "Pokemon"
	basic.stage = "Basic"
	basic.hp = 60
	var slot := _slot(basic, 0)
	state.players[0].active_pokemon = slot
	var evolution := CardInstance.create(_card(5), 0)
	var candy := EffectRareCandy.new()
	var checks: Array[String] = [assert_true(candy._matches_stage_one_basic_override(evolution.card_data.evolves_from, basic), "Bilingual stable mapping supports missing Spewpa")]
	checks.append(assert_true(candy._can_rare_candy_evolve(evolution, slot, state), "Rare Candy supports Vivillon without Stage 1 entity"))
	slot.turn_played = state.turn_number
	checks.append(assert_false(candy._can_rare_candy_evolve(evolution, slot, state), "Cannot evolve newly played Basic"))
	return run_checks(checks)


func _slot(card: CardData, owner: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner))
	slot.turn_played = 0
	return slot


func _energy(symbol: String) -> CardInstance:
	var card := CardData.new()
	card.card_type = "Basic Energy"
	card.energy_provides = symbol
	return CardInstance.create(card, 0)


func _state() -> GameState:
	var state := GameState.new()
	state.phase = GameState.GamePhase.MAIN
	state.turn_number = 2
	state.current_player_index = 0
	state.first_player_index = 1
	state.players = [PlayerState.new(), PlayerState.new()]
	return state
