class_name TestSharedInteractionRegressions
extends TestBase


class HeadsCoinFlipper extends CoinFlipper:
	func flip() -> bool:
		coin_flipped.emit(true)
		return true


class TwoStageCopiedAttackEffect extends BaseEffect:
	const FIRST_STEP_ID := "copied_contract_first"
	const SECOND_STEP_ID := "copied_contract_second"

	func get_attack_interaction_steps(_card: CardInstance, _attack: Dictionary, _state: GameState) -> Array[Dictionary]:
		return [{
			"id": FIRST_STEP_ID,
			"items": [true],
			"labels": ["First"],
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": false,
		}]

	func get_followup_attack_interaction_steps(
		_card: CardInstance,
		_attack: Dictionary,
		_state: GameState,
		resolved_context: Dictionary
	) -> Array[Dictionary]:
		if not resolved_context.has(FIRST_STEP_ID) or resolved_context.has(SECOND_STEP_ID):
			return []
		return [{
			"id": SECOND_STEP_ID,
			"items": [true],
			"labels": ["Second"],
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": false,
		}]


func _pokemon_data(name: String, effect_id: String = "", attacks: Array[Dictionary] = []) -> CardData:
	var card := CardData.new()
	card.name = name
	card.name_en = name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = 130
	card.energy_type = "C"
	card.effect_id = effect_id
	card.attacks.assign(attacks)
	return card


func _attack(name: String, text: String = "", damage: String = "") -> Dictionary:
	return {
		"name": name,
		"text": text,
		"cost": "",
		"damage": damage,
		"is_vstar_power": false,
	}


func _slot(card: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner_index))
	return slot


func _state() -> GameState:
	var state := GameState.new()
	state.current_player_index = 0
	state.turn_number = 4
	state.phase = GameState.GamePhase.MAIN
	for owner_index: int in 2:
		var player := PlayerState.new()
		player.player_index = owner_index
		player.active_pokemon = _slot(_pokemon_data("Active %d" % owner_index, "", [_attack("Strike", "", "20")]), owner_index)
		state.players.append(player)
	return state


func _item(name: String, owner_index: int = 0) -> CardInstance:
	var card := CardData.new()
	card.name = name
	card.card_type = "Item"
	return CardInstance.create(card, owner_index)


func _kyurem_data() -> CardData:
	return _pokemon_data(
		"酋雷姆",
		"5ed7ff97aa96afb6a023ad8ce6636eba",
		[_attack("三重冰霜", "给对手的3只宝可梦各造成110伤害。")]
	)


func _prepare_three_target_state() -> Array:
	var state := _state()
	var processor := EffectProcessor.new()
	var kyurem := _kyurem_data()
	processor.register_pokemon_card(kyurem)
	state.players[1].active_pokemon = _slot(_pokemon_data("Target Active"), 1)
	state.players[1].bench = [
		_slot(_pokemon_data("Target Bench A"), 1),
		_slot(_pokemon_data("Target Bench B"), 1),
	]
	return [state, processor, kyurem]


func _battle_ui_context(step_id: String, option: Dictionary) -> Dictionary:
	return {
		step_id: [option],
		BaseEffect.INTERACTION_SOURCE_KEY: BaseEffect.INTERACTION_SOURCE_BATTLE_UI,
		"__interaction_generation": 17,
		BaseEffect.INTERACTION_INTENTS_KEY: {step_id: BaseEffect.INTERACTION_INTENT_SELECT},
	}


func _assert_three_target_followup(steps: Array[Dictionary], label: String) -> String:
	var step: Dictionary = steps[0] if not steps.is_empty() else {}
	return run_checks([
		assert_eq(steps.size(), 1, "%s should preserve the copied attack follow-up" % label),
		assert_eq(str(step.get("id", "")), "csv9c_tri_frost_targets", "%s should open Kyurem's target chooser" % label),
		assert_eq(int(step.get("min_select", -1)), 3, "%s should require exactly three targets" % label),
		assert_eq(int(step.get("max_select", -1)), 3, "%s should not auto-resolve the copied attack" % label),
	])


func test_all_empty_search_effects_offer_a_closable_readonly_preview() -> String:
	var state := _state()
	state.players[0].deck = [_item("Only non-matching card")]
	var source := state.players[0].active_pokemon.get_top_card()
	var cases: Array[Dictionary] = [
		{"effect": AbilitySearchBasicWaterEnergyActive.new(2), "kind": "ability"},
		{"effect": AbilitySearchDeckCardType.new(1, "Pokemon"), "kind": "ability"},
		{"effect": EffectMesagoza.new(HeadsCoinFlipper.new()), "kind": "stadium"},
		{"effect": CSV10CEffects.AbilitySearchNamedCard.new(["Missing Card"]), "kind": "ability"},
		{"effect": CSV10CEffects.AttackSearchNamedPokemonToHand.new(1, ["Missing"], 0), "kind": "attack"},
		{"effect": CSV10C101To200Effects.AbilitySearchNamedPokemon.new(PackedStringArray(["Missing"]), 1), "kind": "ability"},
		{"effect": CSV10C101To200Effects.EffectCoinSearchNamedPokemonByStage.new(PackedStringArray(["Team Rocket"]), HeadsCoinFlipper.new()), "kind": "trainer"},
		{"effect": CSV10C101To200Effects.EffectSearchNamedSupporter.new(PackedStringArray(["Team Rocket"])), "kind": "trainer"},
	]
	var checks: Array[String] = []
	var view_context := {"empty_search_resolution": [BaseEffect.EMPTY_SEARCH_VIEW_DECK]}
	for test_case: Dictionary in cases:
		var effect: BaseEffect = test_case["effect"]
		var followup: Array[Dictionary] = []
		if str(test_case.get("kind", "")) == "attack":
			followup.assign(effect.get_followup_attack_interaction_steps(source, source.card_data.attacks[0], state, view_context))
		else:
			followup.assign(effect.get_followup_interaction_steps(source, state, view_context))
		var preview: Dictionary = followup[0] if not followup.is_empty() else {}
		var utilities: Array = preview.get("utility_actions", [])
		var close_action: Dictionary = utilities[0] if not utilities.is_empty() and utilities[0] is Dictionary else {}
		checks.append(assert_eq(followup.size(), 1, "%s should implement the advertised View deck branch" % effect.get_script().resource_path.get_file()))
		checks.append(assert_eq(str(preview.get("id", "")), "empty_search_view_deck", "%s should use the shared readonly preview" % effect.get_script().resource_path.get_file()))
		checks.append(assert_eq(close_action.get("selected_indices", null), [], "%s preview should close with an explicit empty selection" % effect.get_script().resource_path.get_file()))
	return run_checks(checks)


func test_battle_controller_falls_back_when_an_empty_search_effect_omits_its_preview() -> String:
	var state := _state()
	var deck_card := _item("Fallback-visible card")
	state.players[0].deck = [deck_card]
	var source := state.players[0].active_pokemon.get_top_card()
	var controller := BattleEffectInteractionController.new()
	var fallback := controller.ensure_empty_search_preview_fallback(
		[],
		source,
		state,
		{"empty_search_resolution": [BaseEffect.EMPTY_SEARCH_VIEW_DECK]}
	)
	var preview: Dictionary = fallback[0] if not fallback.is_empty() else {}
	var utility_actions: Array = preview.get("utility_actions", [])
	return run_checks([
		assert_eq(fallback.size(), 1, "The battle interaction layer should provide a last-resort preview"),
		assert_eq(str(preview.get("id", "")), "empty_search_view_deck", "The fallback should use the standard closable preview"),
		assert_eq(preview.get("items", []), [deck_card], "The fallback should expose the searching player's deck"),
		assert_false(utility_actions.is_empty(), "The fallback preview must always expose a close action"),
	])


func test_named_card_search_ability_can_resolve_a_hidden_information_whiff() -> String:
	var state := _state()
	state.players[0].deck = [_item("Only non-matching card")]
	var pokemon := state.players[0].active_pokemon
	var effect := CSV10CEffects.AbilitySearchNamedCard.new(["Missing Card"])
	var usable := effect.can_use_ability(pokemon, state)
	effect.execute_ability(pokemon, 0, [{
		"empty_search_resolution": [BaseEffect.EMPTY_SEARCH_VIEW_DECK],
		"empty_search_view_deck": [],
	}], state)
	return run_checks([
		assert_true(usable, "A hidden-information search Ability should remain usable when the non-empty deck has no match"),
		assert_eq(state.players[0].deck.size(), 1, "A whiff must preserve the deck card count"),
		assert_true(pokemon.has_ability_used(state.turn_number), "Closing the whiff preview should consume the once-per-turn Ability"),
	])


func test_opponent_attack_and_own_bench_copy_ignore_internal_ui_context_keys() -> String:
	var setup := _prepare_three_target_state()
	var state: GameState = setup[0]
	var processor: EffectProcessor = setup[1]
	var kyurem: CardData = setup[2]
	state.players[1].active_pokemon = _slot(kyurem, 1)
	var attacker := state.players[0].active_pokemon

	var opponent_copy := AttackCopyAttack.new(processor)
	var opponent_steps := opponent_copy.get_attack_interaction_steps(attacker.get_top_card(), attacker.get_attacks()[0], state)
	var opponent_option: Dictionary = opponent_steps[0].get("items", [])[0]
	var opponent_followup := opponent_copy.get_followup_attack_interaction_steps(
		attacker.get_top_card(), attacker.get_attacks()[0], state,
		_battle_ui_context(AttackCopyAttack.STEP_ID, opponent_option)
	)

	state.players[0].bench = [_slot(kyurem, 0)]
	var bench_copy := AttackCopyOwnBenchNamedPokemonAttack.new(processor)
	var bench_steps := bench_copy.get_attack_interaction_steps(attacker.get_top_card(), attacker.get_attacks()[0], state)
	var bench_option: Dictionary = bench_steps[0].get("items", [])[0]
	var bench_followup := bench_copy.get_followup_attack_interaction_steps(
		attacker.get_top_card(), attacker.get_attacks()[0], state,
		_battle_ui_context(AttackCopyOwnBenchNamedPokemonAttack.STEP_ID, bench_option)
	)
	return run_checks([
		_assert_three_target_followup(opponent_followup, "Opponent-Active copy"),
		_assert_three_target_followup(bench_followup, "Own-Bench copy"),
	])


func test_persian_top_deck_copy_ignores_internal_ui_context_keys() -> String:
	var setup := _prepare_three_target_state()
	var state: GameState = setup[0]
	var processor: EffectProcessor = setup[1]
	var kyurem: CardData = setup[2]
	state.players[1].deck = [CardInstance.create(kyurem, 1)]
	var attacker := state.players[0].active_pokemon
	var effect := CSV10C101To200Effects.AttackCopyOpponentTopDeckPokemonAttack.new(processor, 10, 0)
	var steps := effect.get_attack_interaction_steps(attacker.get_top_card(), attacker.get_attacks()[0], state)
	var option: Dictionary = steps[0].get("items", [])[0]
	var followup := effect.get_followup_attack_interaction_steps(
		attacker.get_top_card(), attacker.get_attacks()[0], state,
		_battle_ui_context("csv10c_persian_top_attack", option)
	)
	return _assert_three_target_followup(followup, "Team Rocket's Persian ex")


func test_coin_flip_copy_routes_selected_attack_followup_after_heads_result() -> String:
	var setup := _prepare_three_target_state()
	var state: GameState = setup[0]
	var processor: EffectProcessor = setup[1]
	var kyurem: CardData = setup[2]
	state.players[1].active_pokemon = _slot(kyurem, 1)
	var attacker := state.players[0].active_pokemon
	var effect := CSV10C101To200Effects.AttackCoinFlipCopyOpponentAttack.new(processor, 0, HeadsCoinFlipper.new())
	var result_steps := effect.get_attack_interaction_steps(attacker.get_top_card(), attacker.get_attacks()[0], state)
	var result_context := {
		"csv10c101_coin_result": ["heads"],
		BaseEffect.INTERACTION_SOURCE_KEY: BaseEffect.INTERACTION_SOURCE_BATTLE_UI,
		"__interaction_generation": 21,
		BaseEffect.INTERACTION_INTENTS_KEY: {"csv10c101_coin_result": BaseEffect.INTERACTION_INTENT_SELECT},
	}
	var copy_steps := effect.get_followup_attack_interaction_steps(attacker.get_top_card(), attacker.get_attacks()[0], state, result_context)
	var option: Dictionary = copy_steps[0].get("items", [])[0]
	var copied_context := result_context.duplicate(true)
	copied_context[AttackCopyAttack.STEP_ID] = [option]
	(copied_context[BaseEffect.INTERACTION_INTENTS_KEY] as Dictionary)[AttackCopyAttack.STEP_ID] = BaseEffect.INTERACTION_INTENT_SELECT
	var followup := effect.get_followup_attack_interaction_steps(attacker.get_top_card(), attacker.get_attacks()[0], state, copied_context)
	return run_checks([
		assert_eq(str(result_steps[0].get("id", "")), "csv10c101_coin_result", "Coin-copy should resolve the coin result first"),
		_assert_three_target_followup(followup, "Ethan's Sudowoodo coin copy"),
	])


func test_pre_evolution_granted_attack_forwards_dynamic_followup_steps() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var lower := _pokemon_data("Lower Stage", "fixture_pre_evolution_followup", [_attack("Return and Snipe")])
	var evolved := _pokemon_data("Evolved Stage", "fixture_evolved", [_attack("Top Attack")])
	evolved.stage = "Stage 1"
	var attacker := PokemonSlot.new()
	attacker.pokemon_stack = [CardInstance.create(lower, 0), CardInstance.create(evolved, 0)]
	var energy_data := CardData.new()
	energy_data.name = "Energy"
	energy_data.card_type = "Basic Energy"
	energy_data.energy_provides = "C"
	var energy := CardInstance.create(energy_data, 0)
	attacker.attached_energy = [energy]
	state.players[0].active_pokemon = attacker
	state.players[1].bench = [_slot(_pokemon_data("Bench Target"), 1)]
	processor.register_attack_effect(lower.effect_id, AttackReturnEnergyThenBenchDamage.new(120, 0, 1))
	var memory_effect := AbilityPreEvolutionAttacks.new(processor)
	var granted := memory_effect.get_granted_attacks_for_target(_slot(_pokemon_data("Relicanth"), 0), attacker, state)
	var granted_attack: Dictionary = granted[0] if not granted.is_empty() else {}
	var initial := memory_effect.get_granted_attack_interaction_steps(attacker, granted_attack, state)
	var context := {
		"return_energy_to_deck": [energy],
		BaseEffect.INTERACTION_SOURCE_KEY: BaseEffect.INTERACTION_SOURCE_BATTLE_UI,
		"__interaction_generation": 23,
		BaseEffect.INTERACTION_INTENTS_KEY: {"return_energy_to_deck": BaseEffect.INTERACTION_INTENT_SELECT},
	}
	var followup: Array[Dictionary] = []
	if memory_effect.has_method("get_followup_granted_attack_interaction_steps"):
		followup.assign(memory_effect.call("get_followup_granted_attack_interaction_steps", attacker, granted_attack, state, context))
	return run_checks([
		assert_eq(str(initial[0].get("id", "")) if not initial.is_empty() else "", "return_energy_to_deck", "Memory Dive should expose the borrowed attack's initial interaction"),
		assert_eq(str(followup[0].get("id", "")) if not followup.is_empty() else "", "bench_target", "Memory Dive should also forward the borrowed attack's dynamic follow-up"),
	])


func test_every_live_copy_adapter_forwards_second_level_dynamic_steps() -> String:
	var state := _state()
	var processor := EffectProcessor.new()
	var source := _pokemon_data(
		"Contract Dragon",
		"fixture_two_stage_copied_attack",
		[_attack("Two-stage attack")]
	)
	source.energy_type = "N"
	processor.register_attack_effect(source.effect_id, TwoStageCopiedAttackEffect.new())
	var attacker := state.players[0].active_pokemon
	var checks: Array[String] = []

	var discard_source := CardInstance.create(source, 0)
	state.players[0].discard_pile = [discard_source]
	var regidrago := AttackUseDiscardDragonAttack.new(processor)
	checks.append(_assert_copy_adapter_second_stage(
		regidrago,
		attacker,
		state,
		"copied_attack",
		"Regidrago VSTAR"
	))

	state.players[0].bench = [_slot(source, 0)]
	var own_bench := AttackCopyOwnBenchNamedPokemonAttack.new(processor)
	checks.append(_assert_copy_adapter_second_stage(
		own_bench,
		attacker,
		state,
		AttackCopyOwnBenchNamedPokemonAttack.STEP_ID,
		"N's Zoroark / own-Bench copy"
	))

	state.players[1].deck = [CardInstance.create(source, 1)]
	var persian := CSV10C101To200Effects.AttackCopyOpponentTopDeckPokemonAttack.new(processor, 10, 0)
	checks.append(_assert_copy_adapter_second_stage(
		persian,
		attacker,
		state,
		"csv10c_persian_top_attack",
		"Team Rocket's Persian ex"
	))

	state.players[0].deck = [CardInstance.create(source, 0)]
	var slowking := CSV9CEffects.AttackSlowkingInspiration.new(0, processor)
	checks.append(_assert_copy_adapter_second_stage(
		slowking,
		attacker,
		state,
		"csv9c_slowking_copied_attack",
		"Slowking"
	))

	for standard_adapter: BaseEffect in [regidrago, own_bench, persian]:
		var adapter_name: String = standard_adapter.get_script().resource_path.get_file()
		checks.append(assert_true(standard_adapter.has_method("validate_attack_interaction"), "%s must forward source validation" % adapter_name))
		checks.append(assert_true(standard_adapter.has_method("before_attack_damage"), "%s must forward source before-damage effects" % adapter_name))
		checks.append(assert_true(standard_adapter.has_method("cancels_attack_damage"), "%s must forward source damage cancellation" % adapter_name))
	return run_checks(checks)


func _assert_copy_adapter_second_stage(
	effect: BaseEffect,
	attacker: PokemonSlot,
	state: GameState,
	outer_step_id: String,
	label: String
) -> String:
	var attack := attacker.get_attacks()[0]
	var initial := effect.get_attack_interaction_steps(attacker.get_top_card(), attack, state)
	var outer_step: Dictionary = initial[0] if not initial.is_empty() else {}
	var items: Array = outer_step.get("items", [])
	var option: Dictionary = items[0] if not items.is_empty() and items[0] is Dictionary else {}
	var first_context := {outer_step_id: [option]}
	var first := effect.get_followup_attack_interaction_steps(attacker.get_top_card(), attack, state, first_context)
	var second_context := first_context.duplicate(true)
	second_context[TwoStageCopiedAttackEffect.FIRST_STEP_ID] = ["first"]
	var second := effect.get_followup_attack_interaction_steps(attacker.get_top_card(), attack, state, second_context)
	return run_checks([
		assert_false(option.is_empty(), "%s should expose the source attack" % label),
		assert_eq(str(first[0].get("id", "")) if not first.is_empty() else "", TwoStageCopiedAttackEffect.FIRST_STEP_ID, "%s should forward the source's initial step" % label),
		assert_eq(str(second[0].get("id", "")) if not second.is_empty() else "", TwoStageCopiedAttackEffect.SECOND_STEP_ID, "%s should forward the source's dynamic follow-up" % label),
	])
