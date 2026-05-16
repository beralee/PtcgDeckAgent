class_name TestCSV9CPokemonAdvancedEffects
extends TestBase

const AdvancedEffects := preload("res://scripts/effects/pokemon_effects/CSV9CAdvancedEffects.gd")
const CSV9CEffects := preload("res://scripts/effects/CSV9CEffects.gd")


class RiggedCoinFlipper extends CoinFlipper:
	var _results: Array[bool] = []

	func _init(results: Array[bool]) -> void:
		_results = results.duplicate()

	func flip() -> bool:
		var result := false
		if not _results.is_empty():
			result = _results.pop_front()
		coin_flipped.emit(result)
		return result


func test_csv9c_006_iron_ant_ex_mills_opponent_top_on_bench_entry() -> String:
	var state := _make_state()
	var player := state.players[0]
	var opponent := state.players[1]
	var iron_ant := _make_slot(_pokemon("Iron Ant ex", "Basic", "", "G", 210), 0, state.turn_number)
	player.bench.append(iron_ant)
	var top := CardInstance.create(_trainer("Top card"), 1)
	var second := CardInstance.create(_trainer("Second card"), 1)
	opponent.deck.append_array([top, second])

	var effect := AdvancedEffects.IronAntExSuddenShear.new()
	var usable := effect.can_use_ability(iron_ant, state)
	effect.execute_ability(iron_ant, 0, [], state)
	var usable_after := effect.can_use_ability(iron_ant, state)

	return run_checks([
		assert_true(effect is AbilityOnBenchEnter, "CSV9C_006 should use the bench-enter ability path"),
		assert_true(usable, "CSV9C_006 should be usable when just benched from hand"),
		assert_eq(opponent.discard_pile, [top], "CSV9C_006 should mill the opponent's deck top"),
		assert_eq(opponent.deck, [second], "CSV9C_006 should leave the rest of the opponent deck in order"),
		assert_false(usable_after, "CSV9C_006 should not trigger twice from the same bench entry"),
	])


func test_csv9c_013_hydrapple_ex_attaches_grass_from_hand_and_heals_target() -> String:
	var state := _make_state()
	var player := state.players[0]
	var hydrapple := _make_slot(_pokemon("Hydrapple ex", "Stage 2", "Dipplin", "G", 330), 0)
	player.active_pokemon = hydrapple
	var damaged := _make_slot(_pokemon("Damaged target", "Basic", "", "G", 100), 0)
	damaged.damage_counters = 50
	player.bench.append(damaged)
	var grass := CardInstance.create(_energy("Grass Energy", "G"), 0)
	var fire := CardInstance.create(_energy("Fire Energy", "R"), 0)
	player.hand.append_array([grass, fire])

	var effect := AdvancedEffects.HydrappleExRipeningCharge.new()
	var steps: Array[Dictionary] = effect.get_interaction_steps(hydrapple.get_top_card(), state)
	effect.execute_ability(hydrapple, 0, [{
		"ripening_charge_assignments": [{"source": grass, "target": damaged}],
	}], state)

	var step: Dictionary = steps[0] if not steps.is_empty() else {}
	return run_checks([
		assert_eq(steps.size(), 1, "CSV9C_013 should request one hand-energy assignment"),
		assert_eq(step.get("source_items", []), [grass], "CSV9C_013 should only offer basic Grass Energy from hand"),
		assert_true(grass in damaged.attached_energy, "CSV9C_013 should attach the selected Grass Energy"),
		assert_false(grass in player.hand, "CSV9C_013 should remove the attached Energy from hand"),
		assert_true(fire in player.hand, "CSV9C_013 should ignore non-Grass Energy"),
		assert_eq(damaged.damage_counters, 20, "CSV9C_013 should heal 30 damage from the selected Pokemon"),
	])


func test_csv9c_053_chien_pao_discards_stadium_and_returns_attached_energy_to_hand() -> String:
	var state := _make_state()
	var player := state.players[0]
	var chien_pao := _make_slot(_pokemon("Chien-Pao", "Basic", "", "W", 120, [_attack("Icicle Loop", "WW", "120")]), 0, state.turn_number)
	player.bench.append(chien_pao)
	var stadium := CardInstance.create(_trainer("Test Stadium", "Stadium"), 1)
	state.stadium_card = stadium
	state.stadium_owner_index = 1

	var bury := AdvancedEffects.ChienPaoBuryInSnow.new()
	bury.execute_ability(chien_pao, 0, [], state)

	player.active_pokemon = chien_pao
	player.bench.erase(chien_pao)
	var water := CardInstance.create(_energy("Water Energy", "W"), 0)
	var metal := CardInstance.create(_energy("Metal Energy", "M"), 0)
	chien_pao.attached_energy.append_array([water, metal])
	var loop := AdvancedEffects.ChienPaoIcicleLoop.new()
	var steps: Array[Dictionary] = loop.get_attack_interaction_steps(chien_pao.get_top_card(), chien_pao.get_attacks()[0], state)
	loop.set_attack_interaction_context([{
		"icicle_loop_attached_energy": [metal],
	}])
	loop.execute_attack(chien_pao, state.players[1].active_pokemon, 0, state)
	loop.clear_attack_interaction_context()

	return run_checks([
		assert_null(state.stadium_card, "CSV9C_053 should discard the current Stadium on bench entry"),
		assert_true(stadium in state.players[1].discard_pile, "CSV9C_053 should put the Stadium in its owner's discard"),
		assert_eq(steps.size(), 1, "CSV9C_053 attack should request one attached Energy choice"),
		assert_eq(chien_pao.attached_energy, [water], "CSV9C_053 attack should remove only the selected Energy"),
		assert_true(metal in player.hand, "CSV9C_053 attack should return the selected Energy to hand"),
	])


func test_csv9c_090_sylveon_ex_angelite_shuffles_selected_bench_to_deck() -> String:
	var state := _make_state()
	var attacker := _make_slot(_pokemon("Sylveon ex", "Stage 1", "Eevee", "P", 270, [_attack("Magical Charm", "PCC", "160"), _attack("Angelite", "PWC", "")]), 0)
	state.players[0].active_pokemon = attacker
	var opponent := state.players[1]
	var bench_a := _make_slot(_pokemon("Bench A", "Basic", "", "L", 80), 1)
	var bench_b := _make_slot(_pokemon("Bench B", "Basic", "", "R", 90), 1)
	var energy := CardInstance.create(_energy("Attached Energy", "L"), 1)
	var tool := CardInstance.create(_trainer("Attached Tool", "Tool"), 1)
	bench_a.attached_energy.append(energy)
	bench_b.attached_tool = tool
	opponent.bench.append_array([bench_a, bench_b])

	var effect := AdvancedEffects.SylveonExAngelite.new()
	var steps: Array[Dictionary] = effect.get_attack_interaction_steps(attacker.get_top_card(), attacker.get_attacks()[1], state)
	effect.set_attack_interaction_context([{
		"angelite_bench_targets": [bench_b, bench_a],
	}])
	effect.execute_attack(attacker, opponent.active_pokemon, 1, state)
	effect.clear_attack_interaction_context()

	return run_checks([
		assert_eq(steps.size(), 1, "CSV9C_090 Angelite should request opponent Bench targets"),
		assert_false(bench_a in opponent.bench, "CSV9C_090 should remove the first selected Bench Pokemon"),
		assert_false(bench_b in opponent.bench, "CSV9C_090 should remove the second selected Bench Pokemon"),
		assert_true(energy in opponent.deck, "CSV9C_090 should shuffle attached Energy into the deck"),
		assert_true(tool in opponent.deck, "CSV9C_090 should shuffle attached Tool into the deck"),
		assert_eq(opponent.shuffle_count, 1, "CSV9C_090 should shuffle after returning cards to deck"),
	])


func test_csv9c_138_archaludon_ex_assigns_two_metal_energy_from_discard() -> String:
	var state := _make_state()
	var player := state.players[0]
	var archaludon := _make_slot(_pokemon("Archaludon ex", "Stage 1", "Duraludon", "M", 300), 0)
	archaludon.turn_evolved = state.turn_number
	player.active_pokemon = archaludon
	var bench_metal := _make_slot(_pokemon("Metal target", "Basic", "", "M", 100), 0)
	var bench_fire := _make_slot(_pokemon("Fire target", "Basic", "", "R", 100), 0)
	player.bench.append_array([bench_metal, bench_fire])
	var metal_a := CardInstance.create(_energy("Metal A", "M"), 0)
	var metal_b := CardInstance.create(_energy("Metal B", "M"), 0)
	var grass := CardInstance.create(_energy("Grass", "G"), 0)
	player.discard_pile.append_array([metal_a, grass, metal_b])

	var effect := AdvancedEffects.ArchaludonExAlloyBuild.new()
	var steps: Array[Dictionary] = effect.get_interaction_steps(archaludon.get_top_card(), state)
	effect.execute_ability(archaludon, 0, [{
		"alloy_build_assignments": [
			{"source": metal_a, "target": archaludon},
			{"source": metal_b, "target": bench_metal},
			{"source": grass, "target": bench_fire},
		],
	}], state)

	var step: Dictionary = steps[0] if not steps.is_empty() else {}
	return run_checks([
		assert_eq(steps.size(), 1, "CSV9C_138 should request discard-to-field assignments"),
		assert_eq(step.get("source_items", []), [metal_a, metal_b], "CSV9C_138 should offer only basic Metal Energy from discard"),
		assert_eq(step.get("target_items", []), [archaludon, bench_metal], "CSV9C_138 should offer only own Metal Pokemon as targets"),
		assert_true(metal_a in archaludon.attached_energy, "CSV9C_138 should attach the first selected Metal Energy"),
		assert_true(metal_b in bench_metal.attached_energy, "CSV9C_138 should attach the second selected Metal Energy"),
		assert_true(grass in player.discard_pile, "CSV9C_138 should ignore non-Metal Energy"),
	])


func test_csv9c_142_gholdengo_ex_bonus_and_optional_self_shuffle() -> String:
	var state := _make_state()
	var player := state.players[0]
	var gimmighoul := CardInstance.create(_pokemon("Any base", "Basic", "", "M", 60), 0)
	gimmighoul.card_data.name_en = "Gimmighoul"
	var gholdengo := CardInstance.create(_pokemon("Gholdengo", "Stage 1", "Gimmighoul", "M", 160, [_attack("Rich Strike", "M", "30+"), _attack("Surfing Turn", "MM", "100")]), 0)
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append_array([gimmighoul, gholdengo])
	slot.turn_evolved = state.turn_number
	player.active_pokemon = slot
	var energy := CardInstance.create(_energy("Metal Energy", "M"), 0)
	slot.attached_energy.append(energy)

	var rich := AdvancedEffects.GholdengoRichStrike.new()
	var bonus: int = rich.get_damage_bonus(slot, state)
	var surfing := AdvancedEffects.GholdengoSurfingTurn.new()
	surfing.set_attack_interaction_context([{
		"surfing_turn_choice": ["yes"],
	}])
	surfing.execute_attack(slot, state.players[1].active_pokemon, 1, state)
	surfing.clear_attack_interaction_context()

	return run_checks([
		assert_eq(bonus, 90, "CSV9C_142 should add 90 when evolved from Gimmighoul this turn"),
		assert_null(player.active_pokemon, "CSV9C_142 optional effect should clear the active slot after returning itself"),
		assert_true(gimmighoul in player.deck, "CSV9C_142 should return the base Pokemon to the deck"),
		assert_true(gholdengo in player.deck, "CSV9C_142 should return itself to the deck"),
		assert_true(energy in player.deck, "CSV9C_142 should return attached cards to the deck"),
	])


func test_csv9c_144_alolan_exeggutor_attaches_hand_energy_and_tails_ko_bench_basic() -> String:
	var state := _make_state()
	var player := state.players[0]
	var opponent := state.players[1]
	var exeggutor := _make_slot(_pokemon("Alolan Exeggutor ex", "Basic", "", "G", 300, [_attack("Tropical Frenzy", "G", "150"), _attack("Swinging Sphene", "GRF", "")]), 0)
	player.active_pokemon = exeggutor
	var bench_target := _make_slot(_pokemon("Own target", "Basic", "", "G", 100), 0)
	player.bench.append(bench_target)
	var grass := CardInstance.create(_energy("Grass", "G"), 0)
	var water := CardInstance.create(_energy("Water", "W"), 0)
	player.hand.append_array([grass, water])

	var attach := AdvancedEffects.AlolanExeggutorExTropicalFrenzy.new()
	var attach_steps: Array[Dictionary] = attach.get_attack_interaction_steps(exeggutor.get_top_card(), exeggutor.get_attacks()[0], state)
	attach.set_attack_interaction_context([{
		"tropical_frenzy_assignments": [
			{"source": grass, "target": exeggutor},
			{"source": water, "target": bench_target},
		],
	}])
	attach.execute_attack(exeggutor, opponent.active_pokemon, 0, state)
	attach.clear_attack_interaction_context()

	var opp_bench := _make_slot(_pokemon("Opponent Basic", "Basic", "", "L", 90), 1)
	opponent.bench.append(opp_bench)
	var sphene := AdvancedEffects.AlolanExeggutorExSwingingSphene.new(RiggedCoinFlipper.new([false]))
	sphene.set_attack_interaction_context([{
		"swinging_sphene_bench_basic": [opp_bench],
	}])
	sphene.execute_attack(exeggutor, opponent.active_pokemon, 1, state)
	sphene.clear_attack_interaction_context()

	return run_checks([
		assert_eq(attach_steps.size(), 1, "CSV9C_144 first attack should request hand Energy assignments"),
		assert_true(grass in exeggutor.attached_energy, "CSV9C_144 first attack should attach selected Grass Energy"),
		assert_true(water in bench_target.attached_energy, "CSV9C_144 first attack should attach selected Water Energy"),
		assert_eq(opp_bench.damage_counters, opp_bench.get_max_hp(), "CSV9C_144 tails should KO the selected opponent Bench Basic"),
	])


func test_csv9c_147_kyurem_trifrost_discards_all_energy_and_damages_three_targets() -> String:
	var state := _make_state()
	var player := state.players[0]
	var opponent := state.players[1]
	var kyurem := _make_slot(_pokemon("Kyurem", "Basic", "", "W", 130, [_attack("Trifrost", "WWMMC", "")]), 0)
	player.active_pokemon = kyurem
	var energy_a := CardInstance.create(_energy("Water A", "W"), 0)
	var energy_b := CardInstance.create(_energy("Metal B", "M"), 0)
	kyurem.attached_energy.append_array([energy_a, energy_b])
	var bench_a := _make_slot(_pokemon("Bench A", "Basic", "", "R", 100), 1)
	var bench_b := _make_slot(_pokemon("Bench B", "Basic", "", "G", 100), 1)
	opponent.bench.append_array([bench_a, bench_b])

	var effect := AdvancedEffects.KyuremTrifrost.new()
	var steps: Array[Dictionary] = effect.get_attack_interaction_steps(kyurem.get_top_card(), kyurem.get_attacks()[0], state)
	effect.set_attack_interaction_context([{
		"trifrost_targets": [opponent.active_pokemon, bench_a, bench_b],
	}])
	effect.execute_attack(kyurem, opponent.active_pokemon, 0, state)
	effect.clear_attack_interaction_context()

	return run_checks([
		assert_eq(steps.size(), 1, "CSV9C_147 should request three opponent Pokemon targets"),
		assert_eq(kyurem.attached_energy.size(), 0, "CSV9C_147 should discard all attached Energy"),
		assert_true(energy_a in player.discard_pile, "CSV9C_147 should discard attached Water Energy"),
		assert_true(energy_b in player.discard_pile, "CSV9C_147 should discard attached Metal Energy"),
		assert_eq(opponent.active_pokemon.damage_counters, 110, "CSV9C_147 should damage the selected Active Pokemon"),
		assert_eq(bench_a.damage_counters, 110, "CSV9C_147 should damage the first selected Bench Pokemon"),
		assert_eq(bench_b.damage_counters, 110, "CSV9C_147 should damage the second selected Bench Pokemon"),
	])


func test_csv9c_155_noctowl_and_161_rotom_full_deck_searches_filter_legal_cards() -> String:
	var state := _make_state()
	var player := state.players[0]
	var tera := _make_slot(_pokemon("Terapagos ex", "Basic", "", "C", 230), 0)
	tera.get_card_data().ancient_trait = "Tera"
	player.bench.append(tera)
	var noctowl := _make_slot(_pokemon("Noctowl", "Stage 1", "Hoothoot", "C", 100), 0)
	noctowl.turn_evolved = state.turn_number
	player.active_pokemon = noctowl
	player.deck.clear()
	var trainer_a := CardInstance.create(_trainer("Trainer A", "Item"), 0)
	var pokemon := CardInstance.create(_pokemon("Deck Pokemon", "Basic", "", "C", 80), 0)
	var trainer_b := CardInstance.create(_trainer("Trainer B", "Supporter"), 0)
	player.deck.append_array([trainer_a, pokemon, trainer_b])
	var visible_noctowl := player.deck.duplicate()

	var noctowl_effect := AdvancedEffects.NoctowlJewelSeeker.new()
	var noctowl_steps: Array[Dictionary] = noctowl_effect.get_interaction_steps(noctowl.get_top_card(), state)
	noctowl_effect.execute_ability(noctowl, 0, [{
		"jewel_seeker_trainers": [trainer_b, pokemon],
	}], state)

	state.turn_number = 1
	state.current_player_index = 0
	state.first_player_index = 0
	var rotom := _make_slot(_pokemon("Fan Rotom", "Basic", "", "L", 70), 0)
	player.active_pokemon = rotom
	player.deck.clear()
	var colorless_a := CardInstance.create(_pokemon("Colorless A", "Basic", "", "C", 100), 0)
	var colorless_big := CardInstance.create(_pokemon("Colorless Big", "Basic", "", "C", 120), 0)
	var grass_low := CardInstance.create(_pokemon("Grass Low", "Basic", "", "G", 60), 0)
	var colorless_b := CardInstance.create(_pokemon("Colorless B", "Basic", "", "C", 90), 0)
	player.deck.append_array([colorless_a, colorless_big, grass_low, colorless_b])
	var visible_rotom := player.deck.duplicate()
	var rotom_effect := AdvancedEffects.RotomFanCall.new()
	var rotom_steps: Array[Dictionary] = rotom_effect.get_interaction_steps(rotom.get_top_card(), state)
	rotom_effect.execute_ability(rotom, 0, [{
		"fan_call_targets": [colorless_a, colorless_big, colorless_b],
	}], state)
	var rotom_can_use_again := rotom_effect.can_use_ability(rotom, state)

	var noctowl_step: Dictionary = noctowl_steps[0] if not noctowl_steps.is_empty() else {}
	var rotom_step: Dictionary = rotom_steps[0] if not rotom_steps.is_empty() else {}
	return run_checks([
		assert_eq(str(noctowl_step.get("visible_scope", "")), BaseEffect.VISIBLE_SCOPE_OWN_FULL_DECK, "CSV9C_155 should expose the full own deck"),
		assert_eq(noctowl_step.get("card_items", []), visible_noctowl, "CSV9C_155 should show disabled deck cards"),
		assert_eq(noctowl_step.get("items", []), [trainer_a, trainer_b], "CSV9C_155 should only make Trainers selectable"),
		assert_true(trainer_b in player.hand, "CSV9C_155 should move the selected Trainer to hand"),
		assert_false(pokemon in player.hand, "CSV9C_155 should ignore selected non-Trainer cards"),
		assert_eq(str(rotom_step.get("visible_scope", "")), BaseEffect.VISIBLE_SCOPE_OWN_FULL_DECK, "CSV9C_161 should expose the full own deck"),
		assert_eq(rotom_step.get("card_items", []), visible_rotom, "CSV9C_161 should show disabled deck cards"),
		assert_eq(rotom_step.get("items", []), [colorless_a, colorless_b], "CSV9C_161 should only make low-HP Colorless Pokemon selectable"),
		assert_true(colorless_a in player.hand, "CSV9C_161 should move the first selected legal Pokemon to hand"),
		assert_true(colorless_b in player.hand, "CSV9C_161 should move the second selected legal Pokemon to hand"),
		assert_true(colorless_big in player.deck, "CSV9C_161 should ignore selected over-HP Pokemon"),
		assert_false(rotom_can_use_again, "CSV9C_161 Fan Call should be once per turn"),
	])


func test_csv9c_054_075_133_survival_extra_prize_and_ace_lock_helpers() -> String:
	var state := _make_state()
	var pikachu := _make_slot(_pokemon("Pikachu ex", "Basic", "", "L", 200), 0)
	var attacker := state.players[1].active_pokemon
	pikachu.damage_counters = 200
	var survival := AdvancedEffects.PikachuExTenaciousHeart.new()
	var survived: bool = survival.try_prevent_attack_knockout(pikachu, attacker, state, 0)

	var togekiss := _make_slot(_pokemon("Togekiss", "Stage 2", "Togetic", "C", 150), 0)
	var kiss := AdvancedEffects.TogekissMiracleKiss.new(RiggedCoinFlipper.new([true]))
	var extra_prize: int = kiss.get_extra_prize_for_active_knockout(togekiss, state.players[1].active_pokemon, state)

	var genesect := _make_slot(_pokemon("Genesect", "Basic", "", "M", 110), 0)
	genesect.attached_tool = CardInstance.create(_trainer("Tool", "Tool"), 0)
	var ace := CardInstance.create(_trainer("ACE card", "Item"), 1)
	ace.card_data.is_tags = PackedStringArray(["ACE SPEC"])
	var normal_item := CardInstance.create(_trainer("Normal item", "Item"), 1)
	var cancel := AdvancedEffects.GenesectAceCanceller.new()

	return run_checks([
		assert_true(survived, "CSV9C_054 helper should recognize a full-HP attack-damage KO"),
		assert_eq(pikachu.damage_counters, 190, "CSV9C_054 helper should leave Pikachu ex at 10 HP"),
		assert_eq(extra_prize, 1, "CSV9C_075 helper should award one extra Prize on heads"),
		assert_true(cancel.blocks_card_from_hand(genesect, ace, 1, state), "CSV9C_133 helper should block opponent ACE SPEC with a Tool attached"),
		assert_false(cancel.blocks_card_from_hand(genesect, normal_item, 1, state), "CSV9C_133 helper should not block normal Items"),
		assert_false(cancel.blocks_card_from_hand(genesect, ace, 0, state), "CSV9C_133 helper should not block its controller"),
	])


func test_csv9c_133_actual_ace_lock_blocks_tool_attachment_from_hand() -> String:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	var state := gsm.game_state
	state.current_player_index = 1

	var genesect_cd := _pokemon("Genesect", "Basic", "", "M", 110)
	genesect_cd.effect_id = "571a7dd294812109ab0bf179ecf863eb"
	var genesect := _make_slot(genesect_cd, 0)
	genesect.attached_tool = CardInstance.create(_trainer("Attached Tool", "Tool"), 0)
	state.players[0].active_pokemon = genesect
	gsm.effect_processor.register_effect("571a7dd294812109ab0bf179ecf863eb", CSV9CEffects.AbilityBlockAceSpecIfTooled.new())

	var target := state.players[1].active_pokemon
	var ace_tool := CardInstance.create(_trainer("ACE SPEC Tool", "Tool"), 1)
	ace_tool.card_data.is_tags = PackedStringArray(["ACE SPEC"])
	var normal_tool := CardInstance.create(_trainer("Normal Tool", "Tool"), 1)
	state.players[1].hand.append_array([ace_tool, normal_tool])

	var blocked_by_rule := not gsm.rule_validator.can_attach_tool(state, 1, target, gsm.effect_processor, ace_tool)
	var blocked_by_action := not gsm.attach_tool(1, ace_tool, target)
	var normal_attached := gsm.attach_tool(1, normal_tool, target)

	return run_checks([
		assert_true(blocked_by_rule, "CSV9C_133 actual lock should make RuleValidator reject opponent ACE SPEC Tool attachment"),
		assert_true(blocked_by_action, "CSV9C_133 actual lock should make GameStateMachine.attach_tool reject opponent ACE SPEC Tool"),
		assert_true(ace_tool in state.players[1].hand, "Blocked ACE SPEC Tool should remain in hand"),
		assert_true(normal_attached, "CSV9C_133 should not block normal Tool attachment"),
		assert_eq(target.attached_tool, normal_tool, "Normal Tool should attach after the ACE SPEC Tool is blocked"),
	])


func test_csv9c_119_actual_hydreigon_ex_mills_and_snipes_two_bench_targets() -> String:
	var state := _make_state()
	var player := state.players[0]
	var opponent := state.players[1]
	var hydreigon_cd := _pokemon("Hydreigon ex", "Stage 2", "Zweilous", "D", 330, [
		_attack("Crashing Headbutt", "DDD", "200"),
		_attack("Obsidian", "PDDC", ""),
	], "ex")
	hydreigon_cd.effect_id = "fa9e235782bba9bdb62005106bbdd6d9"
	var hydreigon := _make_slot(hydreigon_cd, 0)
	player.active_pokemon = hydreigon
	var milled_a := CardInstance.create(_trainer("Top 1"), 1)
	var milled_b := CardInstance.create(_trainer("Top 2"), 1)
	var milled_c := CardInstance.create(_trainer("Top 3"), 1)
	var remaining := CardInstance.create(_trainer("Top 4"), 1)
	opponent.deck.append_array([milled_a, milled_b, milled_c, remaining])
	var bench_a := _make_slot(_pokemon("Bench A", "Basic", "", "C", 150), 1)
	var bench_b := _make_slot(_pokemon("Bench B", "Basic", "", "C", 150), 1)
	opponent.bench.append_array([bench_a, bench_b])

	var processor := EffectProcessor.new()
	processor.register_pokemon_card(hydreigon_cd)
	processor.execute_attack_effect(hydreigon, 0, opponent.active_pokemon, state)
	processor.execute_attack_effect(hydreigon, 1, opponent.active_pokemon, state, [{
		"csv9c_bench_damage_targets": [bench_a, bench_b],
	}])

	return run_checks([
		assert_eq(opponent.discard_pile, [milled_a, milled_b, milled_c], "CSV9C_119 first attack should mill exactly the opponent deck top 3 cards"),
		assert_eq(opponent.deck, [remaining], "CSV9C_119 first attack should preserve remaining opponent deck order"),
		assert_eq(bench_a.damage_counters, 130, "CSV9C_119 second attack should damage the first selected Bench Pokemon"),
		assert_eq(bench_b.damage_counters, 130, "CSV9C_119 second attack should damage the second selected Bench Pokemon"),
		assert_eq(opponent.active_pokemon.damage_counters, 0, "CSV9C_119 second attack should not damage the Active Pokemon"),
	])


func test_csv9c_127_actual_poison_lock_boosts_poison_only_while_active() -> String:
	var state := _make_state()
	var pecharunt_cd := _pokemon("Pecharunt", "Basic", "", "D", 80)
	pecharunt_cd.effect_id = "277e3fdeae03359715f5b1432e00619c"
	var pecharunt := _make_slot(pecharunt_cd, 0)
	var defender := state.players[1].active_pokemon
	state.players[0].active_pokemon = pecharunt
	state.players[1].bench.append(_make_slot(_pokemon("Retreat target", "Basic", "", "C", 80), 1))

	var processor := EffectProcessor.new()
	processor.register_effect("277e3fdeae03359715f5b1432e00619c", CSV9CEffects.AbilityPoisonDamageBoostActive.new(50))
	var attack := CSV9CEffects.AttackPoisonAndRetreatLock.new(0)
	attack.execute_attack(pecharunt, defender, 0, state)
	var active_bonus := processor.get_poison_damage_bonus(defender, state)

	state.turn_number = 3
	state.current_player_index = 1
	var retreat_blocked := not RuleValidator.new().can_retreat(state, 1, processor)

	state.turn_number = 2
	state.current_player_index = 0
	state.players[0].active_pokemon = _make_slot(_pokemon("Other Active", "Basic", "", "D", 80), 0)
	state.players[0].bench = [pecharunt]
	var bench_bonus := processor.get_poison_damage_bonus(defender, state)

	return run_checks([
		assert_true(defender.status_conditions.get("poisoned", false), "CSV9C_127 attack should poison the opponent Active"),
		assert_true(defender.effects.any(func(e: Dictionary) -> bool: return e.get("type", "") == "retreat_lock"), "CSV9C_127 attack should add a next-turn retreat lock"),
		assert_eq(active_bonus, 50, "CSV9C_127 Ability should add 5 poison counters while Pecharunt is Active"),
		assert_true(retreat_blocked, "CSV9C_127 retreat lock should block retreat on the next opponent turn"),
		assert_eq(bench_bonus, 0, "CSV9C_127 Ability should stop boosting poison once Pecharunt leaves Active"),
	])


func test_csv9c_153_actual_eevee_early_evolution_requires_active_slot() -> String:
	var state := _make_state()
	state.turn_number = 1
	state.current_player_index = 0
	var processor := EffectProcessor.new()
	processor.register_effect("f37aecbe63a1039fb481286c9b6fcc3c", CSV9CEffects.AbilityEeveeEarlyEvolution.new())

	var active_eevee_cd := _pokemon("Eevee", "Basic", "", "C", 60)
	active_eevee_cd.effect_id = "f37aecbe63a1039fb481286c9b6fcc3c"
	var active_eevee := _make_slot(active_eevee_cd, 0, state.turn_number)
	state.players[0].active_pokemon = active_eevee
	var bench_eevee := _make_slot(active_eevee_cd, 0, state.turn_number)
	state.players[0].bench = [bench_eevee]
	var evolution := CardInstance.create(_pokemon("Jolteon", "Stage 1", "Eevee", "L", 110), 0)

	return run_checks([
		assert_true(RuleValidator.new().can_evolve(state, 0, active_eevee, evolution, processor), "CSV9C_153 should allow Active Eevee to evolve on the first/same turn"),
		assert_false(RuleValidator.new().can_evolve(state, 0, bench_eevee, evolution, processor), "CSV9C_153 should not allow Benched Eevee to use the Active-only early evolution exception"),
	])


func test_csv9c_175_actual_unified_beat_blocked_only_for_second_players_first_turn() -> String:
	var state := _make_state()
	state.first_player_index = 0
	state.turn_number = 2
	state.current_player_index = 1
	var terapagos_cd := _pokemon("Terapagos ex", "Basic", "", "C", 230, [_attack("Unified Beat", "C", "30x")])
	terapagos_cd.effect_id = "1e48ba6c2140461745fc407bf34f5598"
	var terapagos := _make_slot(terapagos_cd, 1)
	terapagos.attached_energy.append(CardInstance.create(_energy("Colorless Energy", "C"), 1))
	state.players[1].active_pokemon = terapagos

	var validator := RuleValidator.new()
	var blocked_first_turn := not validator.can_use_attack(state, 1, 0)
	state.turn_number = 4
	var allowed_later := validator.can_use_attack(state, 1, 0)

	return run_checks([
		assert_true(blocked_first_turn, "CSV9C_175 Unified Beat should be blocked on the second player's first turn"),
		assert_true(allowed_later, "CSV9C_175 Unified Beat should be usable after the second player's first turn when paid"),
	])


func test_csv9c_175_terapagos_crown_opal_blocks_basic_non_colorless_next_turn() -> String:
	var state := _make_state()
	var terapagos := _make_slot(_pokemon("Terapagos ex", "Basic", "", "C", 230, [_attack("Unified Beat", "C", "30x"), _attack("Crown Opal", "GWL", "180")]), 0)
	state.players[0].active_pokemon = terapagos
	var marker := AdvancedEffects.TerapagosExCrownOpalMarker.new()
	marker.execute_attack(terapagos, state.players[1].active_pokemon, 1, state)

	state.turn_number = 3
	state.current_player_index = 1
	var lightning_basic := _make_slot(_pokemon("Lightning Basic", "Basic", "", "L", 100), 1)
	var colorless_basic := _make_slot(_pokemon("Colorless Basic", "Basic", "", "C", 100), 1)
	var lightning_stage1 := _make_slot(_pokemon("Lightning Stage 1", "Stage 1", "Base", "L", 120), 1)
	var guard := AdvancedEffects.TerapagosExCrownOpalGuard.new()

	return run_checks([
		assert_true(guard.prevents_damage_from(lightning_basic, terapagos, state), "CSV9C_175 Crown Opal should block Basic non-Colorless attackers next turn"),
		assert_false(guard.prevents_damage_from(colorless_basic, terapagos, state), "CSV9C_175 Crown Opal should not block Colorless attackers"),
		assert_false(guard.prevents_damage_from(lightning_stage1, terapagos, state), "CSV9C_175 Crown Opal should not block evolved attackers"),
	])


func test_csv9c_main_kyurem_cost_reduction_respects_ability_disabled() -> String:
	var state := _make_state()
	var kyurem_cd := _pokemon("Kyurem", "Basic", "", "W", 130, [_attack("Trifrost", "WWMMC", "")])
	kyurem_cd.effect_id = "csv9c_kyurem_cost_test"
	var kyurem := _make_slot(kyurem_cd, 0)
	state.players[0].active_pokemon = kyurem
	state.players[1].discard_pile.append(CardInstance.create(_trainer("阿克罗玛的实验"), 1))
	var processor := EffectProcessor.new()
	processor.register_effect("csv9c_kyurem_cost_test", CSV9CEffects.AbilityKyuremCostReduction.new())
	var enabled_modifier := processor.get_attack_any_cost_modifier(kyurem, kyurem_cd.attacks[0], state)
	kyurem.effects.append({"type": "ability_disabled", "turn": state.turn_number})
	var disabled_modifier := processor.get_attack_any_cost_modifier(kyurem, kyurem_cd.attacks[0], state)

	return run_checks([
		assert_eq(enabled_modifier, -4, "Kyurem should reduce its first attack by four any-type Energy when Colress is in opponent discard"),
		assert_eq(disabled_modifier, 0, "Kyurem cost reduction should stop while its Ability is disabled"),
	])


func test_csv9c_main_bouffalant_defense_does_not_stack() -> String:
	var state := _make_state()
	var bouff_cd := _pokemon("Bouffalant", "Basic", "", "C", 100)
	bouff_cd.effect_id = "06ff860de906282c96487b440ecfd05e"
	var defender := _make_slot(_pokemon("Colorless Basic", "Basic", "", "C", 120), 0)
	var bouff_a := _make_slot(bouff_cd, 0)
	var bouff_b := _make_slot(bouff_cd, 0)
	state.players[0].active_pokemon = defender
	state.players[0].bench = [bouff_a, bouff_b]
	var processor := EffectProcessor.new()
	processor.register_effect("06ff860de906282c96487b440ecfd05e", CSV9CEffects.AbilityBouffalantDefense.new())
	state.shared_turn_flags["_draw_effect_processor"] = processor
	var stacked_modifier := processor.get_defender_modifier(defender, state, state.players[1].active_pokemon)
	bouff_a.effects.append({"type": "ability_disabled", "turn": state.turn_number})
	var disabled_source_modifier := processor.get_defender_modifier(defender, state, state.players[1].active_pokemon)

	return run_checks([
		assert_eq(stacked_modifier, -60, "CSV9C_162 two Bouffalant should grant one shared -60 damage modifier, not -120"),
		assert_eq(disabled_source_modifier, 0, "CSV9C_162 Bouffalant defense should require two enabled Ability sources"),
	])


func test_csv9c_main_togekiss_flips_once_per_knockout() -> String:
	var state := _make_state()
	var kiss_cd := _pokemon("Togekiss", "Stage 2", "Togetic", "C", 150)
	kiss_cd.effect_id = "csv9c_togekiss_test"
	var attacker := state.players[0].active_pokemon
	var kiss_a := _make_slot(kiss_cd, 0)
	var kiss_b := _make_slot(kiss_cd, 0)
	state.players[0].bench = [kiss_a, kiss_b]
	var processor := EffectProcessor.new()
	processor.register_effect("csv9c_togekiss_test", CSV9CEffects.AbilityTogekissExtraPrize.new(RiggedCoinFlipper.new([false, true])))
	state.shared_turn_flags["_draw_effect_processor"] = processor
	var knocked_out := state.players[1].active_pokemon
	processor.apply_attack_knockout_extra_prize_effects(attacker, knocked_out, state)

	return run_checks([
		assert_eq(knocked_out.effects.size(), 0, "Multiple Togekiss in play should still produce only one coin flip per active knockout"),
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
		player.active_pokemon = _make_slot(_pokemon("Active %d" % pi, "Basic", "", "C", 120), pi)
		state.players.append(player)
	return state


func _pokemon(
	name: String,
	stage: String = "Basic",
	evolves_from: String = "",
	energy_type: String = "C",
	hp: int = 100,
	attacks: Array[Dictionary] = [],
	mechanic: String = ""
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
	data.mechanic = mechanic
	return data


func _trainer(name: String, card_type: String = "Item") -> CardData:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = card_type
	return data


func _energy(name: String, energy_type: String, card_type: String = "Basic Energy") -> CardData:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = card_type
	data.energy_type = energy_type
	data.energy_provides = energy_type
	return data


func _attack(name: String, cost: String = "", damage: String = "", text: String = "") -> Dictionary:
	return {"name": name, "cost": cost, "damage": damage, "text": text, "is_vstar_power": false}


func _make_slot(card_data: CardData, owner_index: int, turn_played: int = 0) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	slot.turn_played = turn_played
	return slot
