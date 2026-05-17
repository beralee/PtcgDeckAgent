class_name TestCSV9CPokemonSimpleEffects
extends TestBase

const CSV9CEffects := preload("res://scripts/effects/CSV9CEffects.gd")
const EarlyEvolutionEffect := preload("res://scripts/effects/pokemon_effects/CSV9CSimpleEarlyEvolutionAttack.gd")
const PreventBasicDamageEffect := preload("res://scripts/effects/pokemon_effects/CSV9CSimplePreventDamageFromBasicAfterAttack.gd")
const TeraBenchBonusEffect := preload("res://scripts/effects/pokemon_effects/CSV9CSimpleBonusIfOwnBenchTera.gd")
const DiscardEnergyCountDamageEffect := preload("res://scripts/effects/pokemon_effects/CSV9CSimpleDiscardPileEnergyCountDamage.gd")
const JoltikChargeEffect := preload("res://scripts/effects/pokemon_effects/CSV9CSimpleAttachGrassLightningFromDeck.gd")
const RecoverPokemonEffect := preload("res://scripts/effects/pokemon_effects/CSV9CSimpleRecoverPokemonFromDiscard.gd")
const HealSelfEffect := preload("res://scripts/effects/pokemon_effects/CSV9CSimpleHealSelfAfterAttack.gd")
const OpponentSpecialEnergyDamageEffect := preload("res://scripts/effects/pokemon_effects/CSV9CSimpleOpponentSpecialEnergyCountDamage.gd")
const HealOwnPokemonEffect := preload("res://scripts/effects/pokemon_effects/CSV9CSimpleHealOwnPokemon.gd")
const PreviousAncientAttackBonusEffect := preload("res://scripts/effects/pokemon_effects/CSV9CSimplePreviousOwnTurnOtherAncientAttackBonus.gd")

const AttackSearchDeckToHandScript := preload("res://scripts/effects/pokemon_effects/AttackSearchDeckToHand.gd")
const AttackSelfDamageCounterMultiplierScript := preload("res://scripts/effects/pokemon_effects/AttackSelfDamageCounterMultiplier.gd")
const AttackFixedCoinFlipDamageScript := preload("res://scripts/effects/pokemon_effects/AttackFixedCoinFlipDamage.gd")
const AttackCoinFlipBonusDamageScript := preload("res://scripts/effects/pokemon_effects/AttackCoinFlipBonusDamage.gd")
const AttackCoinFlipDiscardEnergyScript := preload("res://scripts/effects/pokemon_effects/AttackCoinFlipDiscardOpponentActiveEnergy.gd")
const AttackDiscardAllEnergyScript := preload("res://scripts/effects/pokemon_effects/AttackDiscardAllAttachedEnergyFromSelf.gd")
const AttackDiscardTypedEnergyScript := preload("res://scripts/effects/pokemon_effects/AttackDiscardAttachedEnergyTypeFromSelf.gd")
const AttackMillOpponentDeckScript := preload("res://scripts/effects/pokemon_effects/AttackMillOpponentDeck.gd")


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


func test_csv9c_001_exeggcute_early_evolution_full_deck_visible_and_executes() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var exeggcute := _make_slot(_pokemon("Exeggcute", "Basic", "", "G", 30, [_attack("Precocious Evolution", "C", "")]), 0)
	player.active_pokemon = exeggcute
	player.deck.clear()
	var disabled_item := CardInstance.create(_trainer("Deck Item"), 0)
	var evolution := CardInstance.create(_pokemon("Exeggutor", "Stage 1", "Exeggcute", "G"), 0)
	player.deck.append_array([disabled_item, evolution])

	var effect = EarlyEvolutionEffect.new(0)
	var steps: Array[Dictionary] = effect.get_attack_interaction_steps(exeggcute.get_top_card(), exeggcute.get_attacks()[0], state)
	var step: Dictionary = steps[0] if not steps.is_empty() else {}
	effect.set_attack_interaction_context([{
		"csv9c_early_evolution_card": [disabled_item, evolution],
	}])
	effect.execute_attack(exeggcute, state.players[1].active_pokemon, 0, state)
	effect.clear_attack_interaction_context()

	return run_checks([
		assert_eq(steps.size(), 1, "CSV9C_001 should request one evolution search step"),
		assert_eq(str(step.get("visible_scope", "")), BaseEffect.VISIBLE_SCOPE_OWN_FULL_DECK, "CSV9C_001 must expose the full own deck"),
		assert_eq(step.get("card_items", []), [disabled_item, evolution], "CSV9C_001 should show disabled cards in the searched deck"),
		assert_eq(step.get("items", []), [evolution], "CSV9C_001 should make only matching evolutions selectable"),
		assert_eq(step.get("card_indices", []), [-1, 0], "CSV9C_001 should mark non-evolution deck cards disabled"),
		assert_eq(exeggcute.get_pokemon_name(), "Exeggutor", "CSV9C_001 should evolve into the selected card"),
		assert_eq(exeggcute.turn_evolved, state.turn_number, "CSV9C_001 should mark the slot as evolved this turn"),
		assert_true(disabled_item in player.deck, "CSV9C_001 must leave disabled deck cards in deck"),
	])


func test_csv9c_012_dipplin_prevents_basic_pokemon_damage_next_opponent_turn_only() -> String:
	var state := _make_state()
	var dipplin := _make_slot(_pokemon("Dipplin", "Stage 1", "Applin", "G", 90, [_attack("Coating Attack", "G", "20")]), 0)
	var basic_attacker := _make_slot(_pokemon("Basic Attacker", "Basic", "", "R", 80, [_attack("Hit", "R", "30")]), 1)
	var stage1_attacker := _make_slot(_pokemon("Stage1 Attacker", "Stage 1", "Basic Attacker", "R", 100, [_attack("Hit", "R", "30")]), 1)
	var effect = PreventBasicDamageEffect.new(0)
	effect.execute_attack(dipplin, basic_attacker, 0, state)
	state.turn_number = 3
	var basic_blocked := effect.prevents_damage_from(basic_attacker, dipplin, state)
	var stage1_blocked := effect.prevents_damage_from(stage1_attacker, dipplin, state)
	state.turn_number = 4
	var expired := effect.prevents_damage_from(basic_attacker, dipplin, state)
	return run_checks([
		assert_true(basic_blocked, "CSV9C_012 should block Basic Pokemon attack damage on the opponent's next turn"),
		assert_false(stage1_blocked, "CSV9C_012 should not block evolved Pokemon attack damage"),
		assert_false(expired, "CSV9C_012 protection should expire after the next turn"),
	])


func test_csv9c_021_034_038_damage_rules_and_ceruledge_energy_discard() -> String:
	var state := _make_state()
	var ho_oh := _make_slot(_pokemon("Ho-Oh", "Basic", "", "R", 130, [_attack("Flap", "RC", "50"), _attack("Shining Flame", "RRC", "100+")]), 0)
	state.players[0].active_pokemon = ho_oh
	var tera_bench := _make_slot(_pokemon("Tera Bench", "Basic", "", "C", 100), 0)
	tera_bench.get_card_data().ancient_trait = "Tera"
	state.players[0].bench.append(tera_bench)
	var ho_oh_bonus: int = TeraBenchBonusEffect.new(100, 1).get_damage_bonus(ho_oh, state)

	var ceruledge := _make_slot(_pokemon("Ceruledge ex", "Stage 1", "Charcadet", "R", 270, [_attack("Abyssal Fire", "R", "30+"), _attack("Amethyst Rage", "RPM", "280")], "ex"), 0)
	state.players[0].active_pokemon = ceruledge
	state.players[0].discard_pile.append(CardInstance.create(_energy("Fire Energy", "R"), 0))
	state.players[0].discard_pile.append(CardInstance.create(_energy("Special Energy", "C", "Special Energy"), 0))
	state.players[0].discard_pile.append(CardInstance.create(_trainer("Discard Item"), 0))
	var ceruledge_bonus: int = DiscardEnergyCountDamageEffect.new(20, 0).get_damage_bonus(ceruledge, state)
	var attached := _attach_energy(ceruledge, 0, "R", 3)
	var discard_all = AttackDiscardAllEnergyScript.new(1)
	discard_all.execute_attack(ceruledge, state.players[1].active_pokemon, 1, state)

	var feebas := _make_slot(_pokemon("Feebas", "Basic", "", "W", 30, [_attack("Flail", "W", "10x")]), 0)
	feebas.damage_counters = 30
	var feebas_bonus: int = AttackSelfDamageCounterMultiplierScript.new(10).get_damage_bonus(feebas, state)

	return run_checks([
		assert_eq(ho_oh_bonus, 100, "CSV9C_021 should add 100 when own Bench has a Tera Pokemon"),
		assert_eq(ceruledge_bonus, 40, "CSV9C_034 first attack should add 20 for each Energy in own discard"),
		assert_eq(ceruledge.attached_energy.size(), 0, "CSV9C_034 second attack should discard all attached Energy"),
		assert_true(attached[0] in state.players[0].discard_pile, "CSV9C_034 discarded Energy should enter discard pile"),
		assert_eq(feebas_bonus, 20, "CSV9C_038 should turn three damage counters into 30 total damage from printed 10x"),
	])


func test_csv9c_063_joltik_charge_full_deck_assignment_and_per_type_limit() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.bench.append(_make_slot(_pokemon("Bench Target", "Basic", "", "L"), 0))
	player.deck.clear()
	var grass_a := CardInstance.create(_energy("Grass A", "G"), 0)
	var item := CardInstance.create(_trainer("Deck Item"), 0)
	var grass_b := CardInstance.create(_energy("Grass B", "G"), 0)
	var grass_c := CardInstance.create(_energy("Grass C", "G"), 0)
	var lightning_a := CardInstance.create(_energy("Lightning A", "L"), 0)
	var lightning_b := CardInstance.create(_energy("Lightning B", "L"), 0)
	var lightning_c := CardInstance.create(_energy("Lightning C", "L"), 0)
	var fire := CardInstance.create(_energy("Fire", "R"), 0)
	player.deck.append_array([grass_a, item, grass_b, grass_c, lightning_a, lightning_b, lightning_c, fire])
	var visible_deck := player.deck.duplicate()

	var effect = JoltikChargeEffect.new(2, -1)
	var steps: Array[Dictionary] = effect.get_attack_interaction_steps(player.active_pokemon.get_top_card(), _attack("Joltik Charge", "C", ""), state)
	var grass_step: Dictionary = steps[0] if steps.size() > 0 else {}
	var lightning_step: Dictionary = steps[1] if steps.size() > 1 else {}
	var bench_target: PokemonSlot = player.bench[0]
	effect.set_attack_interaction_context([{
		"csv9c_grass_energy_assignments": [
			{"source": grass_a, "target": bench_target},
			{"source": grass_b, "target": bench_target},
			{"source": grass_c, "target": bench_target},
		],
		"csv9c_lightning_energy_assignments": [
			{"source": lightning_a, "target": bench_target},
			{"source": lightning_b, "target": bench_target},
			{"source": lightning_c, "target": bench_target},
		],
	}])
	effect.execute_attack(player.active_pokemon, state.players[1].active_pokemon, 0, state)
	effect.clear_attack_interaction_context()

	return run_checks([
		assert_eq(steps.size(), 2, "CSV9C_063 should expose Grass and Lightning assignment steps"),
		assert_eq(str(grass_step.get("source_visible_scope", "")), BaseEffect.VISIBLE_SCOPE_OWN_FULL_DECK, "CSV9C_063 Grass search must expose full deck"),
		assert_eq(grass_step.get("source_card_items", []), visible_deck, "CSV9C_063 Grass step should show every deck card"),
		assert_eq(grass_step.get("source_items", []), [grass_a, grass_b, grass_c], "CSV9C_063 Grass step should keep only Grass basic Energy selectable"),
		assert_eq(grass_step.get("source_card_indices", []), [0, -1, 1, 2, -1, -1, -1, -1], "CSV9C_063 Grass step should disable non-Grass cards"),
		assert_eq(str(lightning_step.get("source_visible_scope", "")), BaseEffect.VISIBLE_SCOPE_OWN_FULL_DECK, "CSV9C_063 Lightning search must expose full deck"),
		assert_eq(lightning_step.get("source_items", []), [lightning_a, lightning_b, lightning_c], "CSV9C_063 Lightning step should keep only Lightning basic Energy selectable"),
		assert_eq(lightning_step.get("source_card_indices", []), [-1, -1, -1, -1, 0, 1, 2, -1], "CSV9C_063 Lightning step should disable non-Lightning cards"),
		assert_eq(bench_target.attached_energy.size(), 4, "CSV9C_063 should attach at most two Energy of each requested type"),
		assert_true(grass_c in player.deck, "CSV9C_063 must leave the third selected Grass Energy in deck"),
		assert_true(lightning_c in player.deck, "CSV9C_063 must leave the third selected Lightning Energy in deck"),
		assert_true(item in player.deck, "CSV9C_063 must leave disabled non-Energy cards in deck"),
	])


func test_csv9c_071_and_096_searches_move_only_legal_selected_cards() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var slowpoke := player.active_pokemon
	var discard_pokemon := CardInstance.create(_pokemon("Discard Pokemon", "Basic", "", "P"), 0)
	var discard_item := CardInstance.create(_trainer("Discard Item"), 0)
	player.discard_pile.append_array([discard_item, discard_pokemon])
	var recover = RecoverPokemonEffect.new(1, -1)
	var recover_steps: Array[Dictionary] = recover.get_attack_interaction_steps(slowpoke.get_top_card(), _attack("Tail", "C", ""), state)
	recover.set_attack_interaction_context([{
		"csv9c_recover_pokemon_from_discard": [discard_item, discard_pokemon],
	}])
	recover.execute_attack(slowpoke, state.players[1].active_pokemon, 0, state)
	recover.clear_attack_interaction_context()

	player.deck.clear()
	var basic_energy := CardInstance.create(_energy("Basic Metal", "M"), 0)
	var special_energy := CardInstance.create(_energy("Special", "C", "Special Energy"), 0)
	var deck_item := CardInstance.create(_trainer("Deck Item"), 0)
	player.deck.append_array([special_energy, basic_energy, deck_item])
	var visible_deck := player.deck.duplicate()
	var messenger = AttackSearchDeckToHandScript.new(2, "Basic Energy")
	var search_steps: Array[Dictionary] = messenger.get_attack_interaction_steps(slowpoke.get_top_card(), _attack("Little Messenger", "C", ""), state)
	messenger.set_attack_interaction_context([{
		"search_cards": [special_energy, basic_energy],
	}])
	messenger.execute_attack(slowpoke, state.players[1].active_pokemon, 0, state)
	messenger.clear_attack_interaction_context()
	var search_step: Dictionary = search_steps[0] if not search_steps.is_empty() else {}

	return run_checks([
		assert_eq(recover_steps.size(), 1, "CSV9C_071 should request a discard Pokemon selection"),
		assert_eq(recover_steps[0].get("items", []), [discard_pokemon], "CSV9C_071 should make only Pokemon in discard selectable"),
		assert_true(discard_pokemon in player.hand, "CSV9C_071 should recover the selected Pokemon"),
		assert_true(discard_item in player.discard_pile, "CSV9C_071 should ignore non-Pokemon discard cards"),
		assert_eq(str(search_step.get("visible_scope", "")), BaseEffect.VISIBLE_SCOPE_OWN_FULL_DECK, "CSV9C_096 should expose the full own deck"),
		assert_eq(search_step.get("card_items", []), visible_deck, "CSV9C_096 should show legal and disabled deck cards"),
		assert_eq(search_step.get("items", []), [basic_energy], "CSV9C_096 should make only Basic Energy selectable"),
		assert_eq(search_step.get("card_indices", []), [-1, 0, -1], "CSV9C_096 should disable Special Energy and non-Energy cards"),
		assert_true(basic_energy in player.hand, "CSV9C_096 should move selected Basic Energy to hand"),
		assert_true(special_energy in player.deck, "CSV9C_096 should leave selected illegal Special Energy in deck"),
	])


func test_csv9c_074_and_148_healing_and_applin_coin_bonus() -> String:
	var state := _make_state()
	var attacker := state.players[0].active_pokemon
	attacker.damage_counters = 50
	HealSelfEffect.new(30, 0).execute_attack(attacker, state.players[1].active_pokemon, 0, state)

	var bench := _make_slot(_pokemon("Damaged Bench", "Basic", "", "G"), 0)
	bench.damage_counters = 60
	state.players[0].bench.append(bench)
	var heal_own = HealOwnPokemonEffect.new(30, -1)
	var steps: Array[Dictionary] = heal_own.get_attack_interaction_steps(attacker.get_top_card(), _attack("Nutrients", "C", ""), state)
	heal_own.set_attack_interaction_context([{
		"csv9c_heal_own_pokemon": [bench],
	}])
	heal_own.execute_attack(attacker, state.players[1].active_pokemon, 0, state)
	heal_own.clear_attack_interaction_context()

	var defender := state.players[1].active_pokemon
	defender.damage_counters = 20
	AttackCoinFlipBonusDamageScript.new(30, 1, RiggedCoinFlipper.new([true])).execute_attack(attacker, defender, 1, state)

	return run_checks([
		assert_eq(attacker.damage_counters, 20, "CSV9C_074 should heal 30 from itself"),
		assert_eq(steps.size(), 1, "CSV9C_148 first attack should request an own Pokemon heal target"),
		assert_true(bench in steps[0].get("items", []), "CSV9C_148 should offer damaged own Pokemon"),
		assert_eq(bench.damage_counters, 30, "CSV9C_148 first attack should heal the selected Pokemon by 30"),
		assert_eq(defender.damage_counters, 50, "CSV9C_148 second attack should add 30 damage on heads"),
	])


func test_csv9c_097_098_154_coin_attacks_and_primeape_energy_discard() -> String:
	var state := _make_state()
	var defender := state.players[1].active_pokemon
	defender.damage_counters = 10
	AttackFixedCoinFlipDamageScript.new(2, 10, 10, 0, RiggedCoinFlipper.new([true, true])).execute_attack(
		state.players[0].active_pokemon,
		defender,
		0,
		state
	)
	var mankey_damage := defender.damage_counters
	defender.damage_counters = 10
	AttackFixedCoinFlipDamageScript.new(3, 10, 10, 0, RiggedCoinFlipper.new([true, false, true])).execute_attack(
		state.players[0].active_pokemon,
		defender,
		0,
		state
	)
	var hoothoot_damage := defender.damage_counters

	var opponent := state.players[1]
	var energy_a := CardInstance.create(_energy("Energy A", "F"), 1)
	var energy_b := CardInstance.create(_energy("Energy B", "P"), 1)
	opponent.active_pokemon.attached_energy.append_array([energy_a, energy_b])
	var primeape = AttackCoinFlipDiscardEnergyScript.new(-1, RiggedCoinFlipper.new([true]))
	var steps: Array[Dictionary] = primeape.get_attack_interaction_steps(state.players[0].active_pokemon.get_top_card(), _attack("Sweep the Leg", "F", "30"), state)
	primeape.set_attack_interaction_context([{
		"discard_opponent_active_energy": [energy_b],
	}])
	primeape.execute_attack(state.players[0].active_pokemon, opponent.active_pokemon, 0, state)
	primeape.clear_attack_interaction_context()

	return run_checks([
		assert_eq(mankey_damage, 20, "CSV9C_097 should deal 10 damage per heads from two flips"),
		assert_eq(hoothoot_damage, 20, "CSV9C_154 should deal 10 damage per heads from three flips"),
		assert_eq(steps.size(), 1, "CSV9C_098 should request an opponent Active Energy target"),
		assert_true(energy_b in opponent.discard_pile, "CSV9C_098 should discard the selected Energy on heads"),
		assert_true(energy_a in opponent.active_pokemon.attached_energy, "CSV9C_098 should leave unselected Energy attached"),
	])


func test_csv9c_144_swinging_sphene_flips_before_tails_target_and_knocks_out_selected_bench() -> String:
	var state := _make_state()
	var attacker := _make_slot(_pokemon("Alolan Exeggutor ex", "Stage 1", "Exeggcute", "N", 300, [
		_attack("Tropical Frenzy", "GW", "150"),
		_attack("Swinging Sphene", "GWF", ""),
	]), 0)
	state.players[0].active_pokemon = attacker
	var opponent := state.players[1]
	var active_stage_one := _make_slot(_pokemon("Opponent Stage 1", "Stage 1", "Basic", "L", 120), 1)
	opponent.active_pokemon = active_stage_one
	var bench_basic := _make_slot(_pokemon("Opponent Bench Basic", "Basic", "", "L", 90), 1)
	opponent.bench.append(bench_basic)
	var flipper := RiggedCoinFlipper.new([false])
	var emitted: Array[bool] = []
	flipper.coin_flipped.connect(func(result: bool) -> void: emitted.append(result))
	var effect := CSV9CEffects.AttackBasicPokemonKnockoutCoin.new(1, flipper)

	var preview_steps: Array[Dictionary] = effect.get_attack_preview_interaction_steps(attacker.get_top_card(), attacker.get_attacks()[1], state)
	var steps: Array[Dictionary] = effect.get_attack_interaction_steps(attacker.get_top_card(), attacker.get_attacks()[1], state)
	effect.set_attack_interaction_context([{
		"csv9c_basic_bench_ko_target": [bench_basic],
	}])
	effect.execute_attack(attacker, opponent.active_pokemon, 1, state)
	effect.clear_attack_interaction_context()

	return run_checks([
		assert_eq(preview_steps.size(), 1, "CSV9C_144 attack previews should expose interaction without flipping the coin"),
		assert_eq(emitted, [false], "CSV9C_144 should emit the shared coin result before asking for a tails target"),
		assert_eq(flipper.flip_count, 1, "CSV9C_144 tails should flip exactly once across prompt and execution"),
		assert_eq(str(steps[0].get("id", "")) if not steps.is_empty() else "", "csv9c_basic_bench_ko_target", "CSV9C_144 tails should ask for a Benched Basic target"),
		assert_true(bool(steps[0].get("wait_for_coin_animation", false)) if not steps.is_empty() else false, "CSV9C_144 tails target prompt should wait for the coin animation"),
		assert_true(str(steps[0].get("title", "")).contains("反面"), "CSV9C_144 tails target prompt should be localized and show the branch"),
		assert_eq(bench_basic.damage_counters, bench_basic.get_max_hp(), "CSV9C_144 tails should KO the selected opponent Bench Basic"),
		assert_eq(active_stage_one.damage_counters, 0, "CSV9C_144 tails should not touch the opponent Active Pokemon"),
	])


func test_csv9c_144_swinging_sphene_heads_uses_active_branch_without_bench_target() -> String:
	var state := _make_state()
	var attacker := _make_slot(_pokemon("Alolan Exeggutor ex", "Stage 1", "Exeggcute", "N", 300, [
		_attack("Tropical Frenzy", "GW", "150"),
		_attack("Swinging Sphene", "GWF", ""),
	]), 0)
	state.players[0].active_pokemon = attacker
	var opponent := state.players[1]
	var active_basic := _make_slot(_pokemon("Opponent Active Basic", "Basic", "", "L", 120), 1)
	opponent.active_pokemon = active_basic
	var bench_basic := _make_slot(_pokemon("Opponent Bench Basic", "Basic", "", "L", 90), 1)
	opponent.bench.append(bench_basic)
	var flipper := RiggedCoinFlipper.new([true, false])
	var effect := CSV9CEffects.AttackBasicPokemonKnockoutCoin.new(1, flipper)

	var steps: Array[Dictionary] = effect.get_attack_interaction_steps(attacker.get_top_card(), attacker.get_attacks()[1], state)
	effect.execute_attack(attacker, opponent.active_pokemon, 1, state)

	return run_checks([
		assert_eq(str(steps[0].get("id", "")) if not steps.is_empty() else "", "csv9c_basic_ko_coin_result", "CSV9C_144 heads should expose a coin-result confirmation instead of a bench target"),
		assert_true(bool(steps[0].get("wait_for_coin_animation", false)) if not steps.is_empty() else false, "CSV9C_144 heads result should wait for the coin animation"),
		assert_eq(flipper.flip_count, 1, "CSV9C_144 heads should flip exactly once across prompt and execution"),
		assert_true(str(steps[0].get("title", "")).contains("正面"), "CSV9C_144 heads result prompt should be localized and show the branch"),
		assert_eq(active_basic.damage_counters, active_basic.get_max_hp(), "CSV9C_144 heads should KO the opponent Active Basic Pokemon"),
		assert_eq(bench_basic.damage_counters, 0, "CSV9C_144 heads should ignore Benched Basic Pokemon"),
	])


func test_csv9c_144_swinging_sphene_heads_active_evolved_reports_failure_without_reflip() -> String:
	var state := _make_state()
	var attacker := _make_slot(_pokemon("Alolan Exeggutor ex", "Stage 1", "Exeggcute", "N", 300, [
		_attack("Tropical Frenzy", "GW", "150"),
		_attack("Swinging Sphene", "GWF", ""),
	]), 0)
	state.players[0].active_pokemon = attacker
	var opponent := state.players[1]
	var active_stage_one := _make_slot(_pokemon("Opponent Stage 1", "Stage 1", "Basic", "L", 120), 1)
	opponent.active_pokemon = active_stage_one
	var bench_basic := _make_slot(_pokemon("Opponent Bench Basic", "Basic", "", "L", 90), 1)
	opponent.bench.append(bench_basic)
	var flipper := RiggedCoinFlipper.new([true, false])
	var effect := CSV9CEffects.AttackBasicPokemonKnockoutCoin.new(1, flipper)

	var steps: Array[Dictionary] = effect.get_attack_interaction_steps(attacker.get_top_card(), attacker.get_attacks()[1], state)
	effect.set_attack_interaction_context([{
		"csv9c_basic_ko_coin_result": ["heads"],
	}])
	effect.execute_attack(attacker, opponent.active_pokemon, 1, state)
	effect.clear_attack_interaction_context()

	return run_checks([
		assert_eq(steps.size(), 1, "CSV9C_144 heads failure should show one result prompt"),
		assert_true(str(steps[0].get("title", "")).contains("发动失败"), "CSV9C_144 heads failure should explain that no legal Active Basic target exists"),
		assert_eq(flipper.flip_count, 1, "CSV9C_144 heads failure should not flip again during execution"),
		assert_eq(active_stage_one.damage_counters, 0, "CSV9C_144 heads failure should not KO an evolved Active Pokemon"),
		assert_eq(bench_basic.damage_counters, 0, "CSV9C_144 heads failure should not fall through to the Bench branch"),
	])


func test_csv9c_144_swinging_sphene_tails_no_bench_basic_reports_failure_without_reflip() -> String:
	var state := _make_state()
	var attacker := _make_slot(_pokemon("Alolan Exeggutor ex", "Stage 1", "Exeggcute", "N", 300, [
		_attack("Tropical Frenzy", "GW", "150"),
		_attack("Swinging Sphene", "GWF", ""),
	]), 0)
	state.players[0].active_pokemon = attacker
	var opponent := state.players[1]
	opponent.active_pokemon = _make_slot(_pokemon("Opponent Active Basic", "Basic", "", "L", 120), 1)
	opponent.bench.clear()
	var flipper := RiggedCoinFlipper.new([false, true])
	var effect := CSV9CEffects.AttackBasicPokemonKnockoutCoin.new(1, flipper)

	var steps: Array[Dictionary] = effect.get_attack_interaction_steps(attacker.get_top_card(), attacker.get_attacks()[1], state)
	effect.set_attack_interaction_context([{
		"csv9c_basic_ko_coin_result": ["tails"],
	}])
	effect.execute_attack(attacker, opponent.active_pokemon, 1, state)
	effect.clear_attack_interaction_context()

	return run_checks([
		assert_eq(steps.size(), 1, "CSV9C_144 tails failure should show one result prompt"),
		assert_true(str(steps[0].get("title", "")).contains("发动失败"), "CSV9C_144 tails failure should explain that no Benched Basic target exists"),
		assert_eq(flipper.flip_count, 1, "CSV9C_144 tails failure should not flip again during execution"),
		assert_eq(opponent.active_pokemon.damage_counters, 0, "CSV9C_144 tails failure should not KO the Active Pokemon"),
	])


func test_csv9c_106_112_117_118_136_remaining_attack_effects() -> String:
	var state := _make_state()
	var attacker := state.players[0].active_pokemon
	var opponent := state.players[1]
	var special_a := CardInstance.create(_energy("Special A", "C", "Special Energy"), 1)
	var basic := CardInstance.create(_energy("Basic", "C"), 1)
	opponent.active_pokemon.attached_energy.append_array([special_a, basic])
	var opponent_bench := _make_slot(_pokemon("Opp Bench", "Basic", "", "C"), 1)
	var special_b := CardInstance.create(_energy("Special B", "C", "Special Energy"), 1)
	var special_c := CardInstance.create(_energy("Special C", "C", "Special Energy"), 1)
	opponent_bench.attached_energy.append_array([special_b, special_c])
	opponent.bench.append(opponent_bench)
	var diancie_bonus: int = OpponentSpecialEnergyDamageEffect.new(40, 40, 0).get_damage_bonus(attacker, state)

	var koraidon_effect = PreviousAncientAttackBonusEffect.new(150, 0)
	var koraidon := _make_slot(_pokemon("Koraidon", "Basic", "", "F", 130, [_attack("Ripple Attack", "CC", "30+")]), 0)
	koraidon.get_card_data().is_tags = PackedStringArray([CardData.ANCIENT_TAG])
	state.players[0].active_pokemon = koraidon
	var other_ancient := _make_slot(_pokemon("Other Ancient", "Basic", "", "F"), 0)
	other_ancient.get_card_data().is_tags = PackedStringArray([CardData.ANCIENT_TAG])
	state.turn_number = 3
	PreviousAncientAttackBonusEffect.record_ancient_attack(other_ancient, state)
	state.turn_number = 5
	var koraidon_bonus: int = koraidon_effect.get_damage_bonus(koraidon, state)

	state.players[1].deck.clear()
	var mill_a := CardInstance.create(_trainer("Mill A"), 1)
	var mill_b := CardInstance.create(_trainer("Mill B"), 1)
	var mill_c := CardInstance.create(_trainer("Mill C"), 1)
	state.players[1].deck.append_array([mill_a, mill_b, mill_c])
	AttackMillOpponentDeckScript.new(1, 0).execute_attack(koraidon, opponent.active_pokemon, 0, state)
	AttackMillOpponentDeckScript.new(2, 0).execute_attack(koraidon, opponent.active_pokemon, 0, state)

	var duraludon := _make_slot(_pokemon("Duraludon", "Basic", "", "M", 130, [_attack("Confront", "MM", "50"), _attack("Duraludon Beam", "MMM", "130")]), 0)
	state.players[0].active_pokemon = duraludon
	var metal_a := CardInstance.create(_energy("Metal A", "M"), 0)
	var metal_b := CardInstance.create(_energy("Metal B", "M"), 0)
	var metal_c := CardInstance.create(_energy("Metal C", "M"), 0)
	duraludon.attached_energy.append_array([metal_a, metal_b, metal_c])
	var duraludon_effect = AttackDiscardTypedEnergyScript.new("", 2, 1)
	var duraludon_steps: Array[Dictionary] = duraludon_effect.get_attack_interaction_steps(duraludon.get_top_card(), duraludon.get_attacks()[1], state)
	duraludon_effect.set_attack_interaction_context([{
		"discard_typed_attached_energy_from_self": [metal_a, metal_c],
	}])
	duraludon_effect.execute_attack(duraludon, opponent.active_pokemon, 1, state)
	duraludon_effect.clear_attack_interaction_context()

	return run_checks([
		assert_eq(diancie_bonus, 80, "CSV9C_106 should make three opponent Special Energy become 120 total from printed 40x"),
		assert_eq(koraidon_bonus, 150, "CSV9C_112 should add 150 when another Ancient Pokemon attacked on the previous own turn marker"),
		assert_eq(opponent.discard_pile, [mill_a, mill_b, mill_c], "CSV9C_117 and CSV9C_118 should mill one then two cards from the opponent deck top"),
		assert_eq(duraludon_steps.size(), 1, "CSV9C_136 should request a choice when more than two attached Energy are available"),
		assert_eq(duraludon.attached_energy, [metal_b], "CSV9C_136 should discard exactly the two selected attached Energy"),
		assert_true(metal_a in state.players[0].discard_pile, "CSV9C_136 selected Energy should enter discard"),
		assert_true(metal_c in state.players[0].discard_pile, "CSV9C_136 selected Energy should enter discard"),
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
		player.active_pokemon = _make_slot(_pokemon("Active %d" % pi, "Basic", "", "C"), pi)
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


func _make_slot(card_data: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	slot.turn_played = 0
	return slot


func _attach_energy(slot: PokemonSlot, owner_index: int, energy_type: String, count: int) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	for i: int in count:
		var energy := CardInstance.create(_energy("%s Energy %d" % [energy_type, i], energy_type), owner_index)
		slot.attached_energy.append(energy)
		result.append(energy)
	return result
