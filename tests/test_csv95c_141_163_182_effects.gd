class_name TestCSV95C141163182Effects
extends TestBase

const AILegalActionBuilderScript = preload("res://scripts/ai/AILegalActionBuilder.gd")
const CSV95C182AokisSkillScript = preload("res://scripts/effects/trainer_effects/CSV95C182AokisSkill.gd")
const EffectMortysConvictionScript = preload("res://scripts/effects/trainer_effects/EffectMortysConviction.gd")
const EffectApplyStatusScript = preload("res://scripts/effects/pokemon_effects/EffectApplyStatus.gd")
const EffectLanasAidScript = preload("res://scripts/effects/trainer_effects/EffectLanasAid.gd")
const AbilityToedscruelSlimeMoldColonyScript = preload("res://scripts/effects/pokemon_effects/AbilityToedscruelSlimeMoldColony.gd")

const HOOTHOOT_ID := "76f4e0d39348c21f1f1a4be4d653b6a5"
const AOKI_ID := "60efb96839df10bb78737047da1c4fb1"
const MORTY_ID := "0d2ca8f42fe1500644bc1bd21c89eeb1"
const MAX_ROD_ID := "6a7fe7ec3f22c435f50b49909e85b3d3"
const TOEDSCRUEL_ID := "880338810e1bc9460b1d20044377e08c"


func test_csv95c_141_insomnia_only_prevents_sleep() -> String:
	var state := _make_state()
	var processor := EffectProcessor.new()
	var hoothoot := _make_pokemon_data("Hoothoot", "C", 80, "Basic", "", HOOTHOOT_ID)
	processor.register_pokemon_card(hoothoot)
	state.shared_turn_flags["_draw_effect_processor"] = processor

	var defender := _make_slot(hoothoot, 0)
	var attacker := state.players[1].active_pokemon
	EffectApplyStatusScript.new("asleep").execute_attack(attacker, defender, 0, state)
	EffectApplyStatusScript.new("poisoned").execute_attack(attacker, defender, 0, state)

	return run_checks([
		assert_false(bool(defender.status_conditions.get("asleep", false)), "Insomnia should prevent Asleep"),
		assert_true(bool(defender.status_conditions.get("poisoned", false)), "Insomnia should not prevent Poisoned"),
		assert_true(processor.prevents_special_status(defender, state, "asleep"), "Insomnia should report Asleep prevention"),
		assert_false(processor.prevents_special_status(defender, state, "burned"), "Insomnia should not report blanket status prevention"),
	])


func test_csv95c_163_max_rod_recovers_up_to_five_pokemon_and_basic_energy() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var normal_pokemon := CardInstance.create(_make_pokemon_data("Normal Pokemon", "C"), 0)
	var rule_pokemon := CardInstance.create(_make_pokemon_data("Rule Pokemon ex", "C", 200, "Basic", "ex"), 0)
	var grass_energy := CardInstance.create(_make_energy_data("Grass Energy", "G"), 0)
	var fire_energy := CardInstance.create(_make_energy_data("Fire Energy", "R"), 0)
	var water_energy := CardInstance.create(_make_energy_data("Water Energy", "W"), 0)
	var sixth_valid := CardInstance.create(_make_pokemon_data("Sixth Pokemon", "C"), 0)
	var special_energy := CardInstance.create(_make_energy_data("Special Energy", "C", "Special Energy"), 0)
	var trainer := CardInstance.create(_make_trainer_data("Item Card", "Item"), 0)
	player.discard_pile.append_array([
		normal_pokemon,
		rule_pokemon,
		grass_energy,
		fire_energy,
		water_energy,
		sixth_valid,
		special_energy,
		trainer,
	])
	var max_rod := CardInstance.create(_make_trainer_data("Max Rod", "Item", MAX_ROD_ID), 0)
	var effect := EffectLanasAidScript.new(5, true)
	effect.execute(max_rod, [{
		EffectLanasAidScript.STEP_ID: [
			normal_pokemon,
			rule_pokemon,
			grass_energy,
			fire_energy,
			water_energy,
			sixth_valid,
			special_energy,
			trainer,
		],
	}], state)

	return run_checks([
		assert_true(normal_pokemon in player.hand, "Max Rod should recover normal Pokemon"),
		assert_true(rule_pokemon in player.hand, "Max Rod should recover rule-box Pokemon"),
		assert_true(grass_energy in player.hand, "Max Rod should recover Basic Energy"),
		assert_true(fire_energy in player.hand, "Max Rod should recover a second Basic Energy"),
		assert_true(water_energy in player.hand, "Max Rod should recover up to five total cards"),
		assert_true(sixth_valid in player.discard_pile, "Max Rod should cap selection at five cards"),
		assert_true(special_energy in player.discard_pile, "Max Rod should not recover Special Energy"),
		assert_true(trainer in player.discard_pile, "Max Rod should not recover Trainer cards"),
	])


func test_csv95c_163_max_rod_blocked_by_toedscruel_is_not_playable_or_spent() -> String:
	var gsm := _make_gsm()
	var state := gsm.game_state
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	player.hand.clear()
	player.discard_pile.clear()
	var max_rod := CardInstance.create(_make_trainer_data("Max Rod", "Item", MAX_ROD_ID), 0)
	var discard_target := CardInstance.create(_make_pokemon_data("Discard Pokemon", "C"), 0)
	player.hand.append(max_rod)
	player.discard_pile.append(discard_target)
	opponent.bench.append(_make_slot(_make_pokemon_data("Toedscruel", "G", 120, "Stage 1", "", TOEDSCRUEL_ID), 1))
	gsm.effect_processor.register_effect(MAX_ROD_ID, EffectLanasAidScript.new(5, true))
	gsm.effect_processor.register_effect(TOEDSCRUEL_ID, AbilityToedscruelSlimeMoldColonyScript.new())

	var actions := AILegalActionBuilderScript.new().build_actions(gsm, 0)
	var action := _find_action(actions, "play_trainer", func(candidate: Dictionary) -> bool:
		return candidate.get("card") == max_rod
	)
	var effect: BaseEffect = gsm.effect_processor.get_effect(MAX_ROD_ID)
	var can_execute_after_builder := effect.can_execute(max_rod, state)
	var steps_after_builder := effect.get_interaction_steps(max_rod, state)
	var played := gsm.play_trainer(0, max_rod, [{
		EffectLanasAidScript.STEP_ID: [discard_target],
	}])

	var checks: Array[String] = [
		assert_not_null(effect, "Max Rod should be registered by effect id"),
		assert_false(can_execute_after_builder, "Max Rod should not be executable while Toedscruel blocks discard-to-hand Trainer effects"),
		assert_true(steps_after_builder.is_empty(), "Blocked Max Rod should expose no discard recovery choices"),
		assert_true(action.is_empty(), "AI legal actions should not expose a blocked Max Rod play"),
		assert_false(played, "GameStateMachine.play_trainer should reject blocked Max Rod instead of spending it"),
		assert_true(max_rod in player.hand, "Blocked Max Rod should remain in hand"),
		assert_false(max_rod in player.discard_pile, "Blocked Max Rod should not be discarded"),
		assert_true(discard_target in player.discard_pile, "Blocked Max Rod target should stay in discard"),
		assert_false(discard_target in player.hand, "Blocked Max Rod target should not enter hand"),
	]
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_csv95c_182_aokis_skill_discards_hand_and_searches_three_categories() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.deck.clear()
	var aoki := CardInstance.create(_make_trainer_data("Aoki's Skill", "Supporter", "60efb96839df10bb78737047da1c4fb1"), 0)
	var discard_a := CardInstance.create(_make_trainer_data("Discard A", "Item"), 0)
	var discard_b := CardInstance.create(_make_pokemon_data("Discard B", "C"), 0)
	player.hand.append_array([aoki, discard_a, discard_b])
	var pokemon := CardInstance.create(_make_pokemon_data("Deck Pokemon", "C"), 0)
	var supporter := CardInstance.create(_make_trainer_data("Deck Supporter", "Supporter"), 0)
	var basic_energy := CardInstance.create(_make_energy_data("Basic Fire Energy", "R"), 0)
	var special_energy := CardInstance.create(_make_energy_data("Special Energy", "C", "Special Energy"), 0)
	var item := CardInstance.create(_make_trainer_data("Deck Item", "Item"), 0)
	player.deck.append_array([pokemon, supporter, basic_energy, special_energy, item])

	CSV95C182AokisSkillScript.new().execute(aoki, [{
		CSV95C182AokisSkillScript.POKEMON_STEP_ID: [pokemon],
		CSV95C182AokisSkillScript.SUPPORTER_STEP_ID: [supporter],
		CSV95C182AokisSkillScript.ENERGY_STEP_ID: [basic_energy, special_energy],
	}], state)

	return run_checks([
		assert_true(discard_a in player.discard_pile, "Aoki's Skill should discard the first hand card"),
		assert_true(discard_b in player.discard_pile, "Aoki's Skill should discard the second hand card"),
		assert_true(aoki in player.hand, "The played card should not be discarded by its own hand-discard effect in isolated execution"),
		assert_true(pokemon in player.hand, "Aoki's Skill should add the selected Pokemon"),
		assert_true(supporter in player.hand, "Aoki's Skill should add the selected Supporter"),
		assert_true(basic_energy in player.hand, "Aoki's Skill should add the selected Basic Energy"),
		assert_true(special_energy in player.deck, "Aoki's Skill should not accept Special Energy as Basic Energy"),
		assert_true(item in player.deck, "Aoki's Skill should leave unrelated Trainer cards in deck"),
	])


func test_csv95c_182_aokis_skill_explicit_empty_search_does_not_fallback() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.hand.clear()
	player.deck.clear()
	var aoki := CardInstance.create(_make_trainer_data("Aoki's Skill", "Supporter"), 0)
	var pokemon := CardInstance.create(_make_pokemon_data("Deck Pokemon", "C"), 0)
	player.hand.append(aoki)
	player.deck.append(pokemon)

	CSV95C182AokisSkillScript.new().execute(aoki, [{
		CSV95C182AokisSkillScript.POKEMON_STEP_ID: [],
	}], state)

	return run_checks([
		assert_false(pokemon in player.hand, "Explicit empty Pokemon search should not fall back to a deck target"),
		assert_true(pokemon in player.deck, "Explicit empty Pokemon search should leave the Pokemon in deck"),
	])


func test_csv95c_182_aokis_skill_search_steps_keep_full_deck_visible() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.deck.clear()
	var aoki := CardInstance.create(_make_trainer_data("Aoki's Skill", "Supporter", AOKI_ID), 0)
	var pokemon := CardInstance.create(_make_pokemon_data("Deck Pokemon", "C"), 0)
	var supporter := CardInstance.create(_make_trainer_data("Deck Supporter", "Supporter"), 0)
	var basic_energy := CardInstance.create(_make_energy_data("Basic Fire Energy", "R"), 0)
	var item := CardInstance.create(_make_trainer_data("Deck Item", "Item"), 0)
	var special_energy := CardInstance.create(_make_energy_data("Special Energy", "C", "Special Energy"), 0)
	player.deck.append_array([pokemon, supporter, basic_energy, item, special_energy])

	var steps := CSV95C182AokisSkillScript.new().get_interaction_steps(aoki, state)
	var pokemon_step := _find_step(steps, CSV95C182AokisSkillScript.POKEMON_STEP_ID)
	var supporter_step := _find_step(steps, CSV95C182AokisSkillScript.SUPPORTER_STEP_ID)
	var energy_step := _find_step(steps, CSV95C182AokisSkillScript.ENERGY_STEP_ID)
	var pokemon_indices: Array = pokemon_step.get("card_indices", [])
	var supporter_indices: Array = supporter_step.get("card_indices", [])
	var energy_indices: Array = energy_step.get("card_indices", [])

	return run_checks([
		assert_eq(steps.size(), 3, "Aoki's Skill should expose one full-deck step for each searchable category"),
		assert_eq(str(pokemon_step.get("visible_scope", "")), BaseEffect.VISIBLE_SCOPE_OWN_FULL_DECK, "Pokemon search should be full-deck visible"),
		assert_eq(int(pokemon_step.get("visible_count", -1)), 5, "Pokemon search should keep the whole deck visible"),
		assert_eq((pokemon_step.get("card_items", []) as Array).size(), 5, "Pokemon search should include illegal cards as visible cards"),
		assert_eq((pokemon_step.get("items", []) as Array).size(), 1, "Pokemon search should only make Pokemon selectable"),
		assert_eq(pokemon_indices, [0, -1, -1, -1, -1], "Pokemon search should mark only the Pokemon selectable"),
		assert_eq(supporter_indices, [-1, 0, -1, -1, -1], "Supporter search should mark only the Supporter selectable"),
		assert_eq(energy_indices, [-1, -1, 0, -1, -1], "Energy search should mark only Basic Energy selectable"),
	])


func test_csv95c_182_aokis_skill_ai_allows_hidden_search_whiff() -> String:
	var gsm := _make_gsm()
	var player: PlayerState = gsm.game_state.players[0]
	player.hand.clear()
	player.deck.clear()
	var aoki := CardInstance.create(_make_trainer_data("Aoki's Skill", "Supporter", AOKI_ID), 0)
	var item := CardInstance.create(_make_trainer_data("Deck Item", "Item"), 0)
	var special_energy := CardInstance.create(_make_energy_data("Special Energy", "C", "Special Energy"), 0)
	player.hand.append(aoki)
	player.deck.append_array([item, special_energy])
	gsm.effect_processor.register_effect(AOKI_ID, CSV95C182AokisSkillScript.new())

	var effect := CSV95C182AokisSkillScript.new()
	var actions := AILegalActionBuilderScript.new().build_actions(gsm, 0)
	var action := _find_action(actions, "play_trainer", func(candidate: Dictionary) -> bool:
		return candidate.get("card") == aoki
	)
	var targets: Array = action.get("targets", [])
	var ctx: Dictionary = {} if targets.is_empty() else targets[0]
	var empty_resolution: Array = ctx.get("empty_search_resolution", [])

	return run_checks([
		assert_true(effect.can_execute(aoki, gsm.game_state), "Aoki's Skill should be playable with a non-empty deck even when search whiffs"),
		assert_true(effect.can_headless_execute(aoki, gsm.game_state), "Headless playability should match real playability for hidden-search whiffs"),
		assert_false(action.is_empty(), "AI legal action builder should enumerate Aoki's Skill when the hidden search can whiff"),
		assert_false(bool(action.get("requires_interaction", true)), "AI should auto-resolve the empty-search confirmation"),
		assert_eq(empty_resolution.size(), 1, "AI should synthesize an empty-search resolution target"),
		assert_eq(str(empty_resolution[0]), BaseEffect.EMPTY_SEARCH_CONTINUE, "AI should continue when no legal hidden-search targets exist"),
	])


func test_csv95c_199_mortys_conviction_discards_selected_card_and_draws_for_opponent_bench() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	player.hand.clear()
	player.deck.clear()
	var morty := CardInstance.create(_make_trainer_data("Morty's Conviction", "Supporter", MORTY_ID), 0)
	var keep := CardInstance.create(_make_trainer_data("Keep", "Item"), 0)
	var discard := CardInstance.create(_make_trainer_data("Discard", "Item"), 0)
	player.hand.append_array([morty, keep, discard])
	opponent.bench.append_array([
		_make_slot(_make_pokemon_data("Opp Bench A", "C"), 1),
		_make_slot(_make_pokemon_data("Opp Bench B", "C"), 1),
		_make_slot(_make_pokemon_data("Opp Bench C", "C"), 1),
	])
	var draw_a := CardInstance.create(_make_trainer_data("Draw A", "Item"), 0)
	var draw_b := CardInstance.create(_make_trainer_data("Draw B", "Item"), 0)
	var draw_c := CardInstance.create(_make_trainer_data("Draw C", "Item"), 0)
	var stay_deck := CardInstance.create(_make_trainer_data("Stay Deck", "Item"), 0)
	player.deck.append_array([draw_a, draw_b, draw_c, stay_deck])

	EffectMortysConvictionScript.new().execute(morty, [{
		EffectMortysConvictionScript.DISCARD_STEP_ID: [discard],
	}], state)

	return run_checks([
		assert_true(discard in player.discard_pile, "Morty's Conviction should discard the selected hand card"),
		assert_false(discard in player.hand, "Discarded card should leave hand"),
		assert_true(keep in player.hand, "Unselected hand card should stay in hand"),
		assert_true(morty in player.hand, "The played Supporter should not be discarded by isolated effect execution"),
		assert_true(draw_a in player.hand and draw_b in player.hand and draw_c in player.hand, "Morty's Conviction should draw one card per opponent Benched Pokemon"),
		assert_true(stay_deck in player.deck, "Morty's Conviction should not draw beyond opponent Bench count"),
	])


func test_csv95c_199_mortys_conviction_exposes_one_card_discard_step() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	player.hand.clear()
	player.deck.clear()
	var morty := CardInstance.create(_make_trainer_data("Morty's Conviction", "Supporter", MORTY_ID), 0)
	var keep := CardInstance.create(_make_trainer_data("Keep", "Item"), 0)
	var discard := CardInstance.create(_make_trainer_data("Discard", "Item"), 0)
	player.hand.append_array([morty, keep, discard])
	player.deck.append(CardInstance.create(_make_trainer_data("Draw", "Item"), 0))
	opponent.bench.append(_make_slot(_make_pokemon_data("Opp Bench", "C"), 1))
	var effect: BaseEffect = EffectMortysConvictionScript.new()

	var steps: Array[Dictionary] = effect.get_interaction_steps(morty, state)
	var step: Dictionary = steps[0] if not steps.is_empty() else {}

	return run_checks([
		assert_true(effect.can_execute(morty, state), "Morty's Conviction should be playable when it can discard and draw"),
		assert_eq(steps.size(), 1, "Morty's Conviction should ask for exactly one discard choice"),
		assert_eq(str(step.get("id", "")), EffectMortysConvictionScript.DISCARD_STEP_ID, "Morty's Conviction discard step id should be stable"),
		assert_eq(step.get("items", []), [keep, discard], "Morty's Conviction should expose only other hand cards as discard candidates"),
		assert_eq(int(step.get("min_select", 0)), 1, "Morty's Conviction discard cost should require one card"),
		assert_eq(int(step.get("max_select", 0)), 1, "Morty's Conviction should discard exactly one card"),
		assert_false(bool(step.get("allow_cancel", true)), "Morty's Conviction should not allow cancel after choosing to play it"),
	])


func test_csv95c_199_mortys_conviction_rejects_empty_cost_or_draw_state() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	player.hand.clear()
	player.deck.clear()
	var morty := CardInstance.create(_make_trainer_data("Morty's Conviction", "Supporter", MORTY_ID), 0)
	player.hand.append(morty)
	player.deck.append(CardInstance.create(_make_trainer_data("Draw", "Item"), 0))
	opponent.bench.append(_make_slot(_make_pokemon_data("Opp Bench", "C"), 1))
	var effect: BaseEffect = EffectMortysConvictionScript.new()
	var no_extra_hand_card: bool = effect.can_execute(morty, state)

	player.hand.append(CardInstance.create(_make_trainer_data("Discard", "Item"), 0))
	player.deck.clear()
	var no_deck: bool = effect.can_execute(morty, state)

	player.deck.append(CardInstance.create(_make_trainer_data("Draw", "Item"), 0))
	opponent.bench.clear()
	var no_opponent_bench: bool = effect.can_execute(morty, state)

	return run_checks([
		assert_false(no_extra_hand_card, "Morty's Conviction should require another hand card to discard"),
		assert_false(no_deck, "Morty's Conviction should require a card available to draw"),
		assert_false(no_opponent_bench, "Morty's Conviction should require at least one opponent Benched Pokemon"),
	])


func test_csv95c_199_mortys_conviction_ai_play_trainer_entry_discards_and_draws() -> String:
	var gsm := _make_gsm()
	var state := gsm.game_state
	var player: PlayerState = state.players[0]
	var opponent: PlayerState = state.players[1]
	player.hand.clear()
	player.deck.clear()
	var morty := CardInstance.create(_make_trainer_data("Morty's Conviction", "Supporter", MORTY_ID), 0)
	var discard := CardInstance.create(_make_trainer_data("Discard", "Item"), 0)
	var draw_a := CardInstance.create(_make_trainer_data("Draw A", "Item"), 0)
	var draw_b := CardInstance.create(_make_trainer_data("Draw B", "Item"), 0)
	var draw_c := CardInstance.create(_make_trainer_data("Draw C", "Item"), 0)
	player.hand.append_array([morty, discard])
	player.deck.append_array([draw_a, draw_b, draw_c])
	opponent.bench.append_array([
		_make_slot(_make_pokemon_data("Opp Bench A", "C"), 1),
		_make_slot(_make_pokemon_data("Opp Bench B", "C"), 1),
	])

	var effect: BaseEffect = gsm.effect_processor.get_effect(MORTY_ID)
	var actions := AILegalActionBuilderScript.new().build_actions(gsm, 0)
	var action := _find_action(actions, "play_trainer", func(candidate: Dictionary) -> bool:
		return candidate.get("card") == morty
	)
	var played := false
	if not action.is_empty():
		played = gsm.play_trainer(0, morty, action.get("targets", []))

	var checks: Array[String] = [
		assert_not_null(effect, "Morty's Conviction should be registered by effect id"),
		assert_false(action.is_empty(), "AI legal action builder should expose Morty's Conviction as playable"),
		assert_false(bool(action.get("requires_interaction", true)), "AI should auto-resolve the discard choice for Morty's Conviction"),
		assert_true(played, "GameStateMachine.play_trainer should resolve Morty's Conviction"),
		assert_true(morty in player.discard_pile, "Played Morty's Conviction should go to discard"),
		assert_true(discard in player.discard_pile, "Morty's Conviction should discard the selected cost card"),
		assert_true(draw_a in player.hand and draw_b in player.hand, "Morty's Conviction should draw for the two opponent Benched Pokemon"),
		assert_true(draw_c in player.deck, "Morty's Conviction should stop drawing after opponent Bench count"),
	]
	gsm.prepare_for_disposal()
	return run_checks(checks)


func _make_state() -> GameState:
	CardInstance.reset_id_counter()
	var state := GameState.new()
	state.turn_number = 2
	state.current_player_index = 0
	state.phase = GameState.GamePhase.MAIN
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		player.active_pokemon = _make_slot(_make_pokemon_data("Active %d" % pi, "C"), pi)
		state.players.append(player)
	return state


func _make_gsm() -> GameStateMachine:
	var gsm := GameStateMachine.new()
	gsm.game_state = _make_state()
	return gsm


func _find_action(actions: Array[Dictionary], kind: String, predicate: Callable = Callable()) -> Dictionary:
	for action: Dictionary in actions:
		if str(action.get("kind", "")) != kind:
			continue
		if predicate.is_null() or bool(predicate.call(action)):
			return action
	return {}


func _find_step(steps: Array[Dictionary], step_id: String) -> Dictionary:
	for step: Dictionary in steps:
		if str(step.get("id", "")) == step_id:
			return step
	return {}


func _make_slot(card_data: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	slot.turn_played = 0
	return slot


func _make_pokemon_data(
	name: String,
	energy_type: String,
	hp: int = 100,
	stage: String = "Basic",
	mechanic: String = "",
	effect_id: String = ""
) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = "Pokemon"
	cd.energy_type = energy_type
	cd.hp = hp
	cd.stage = stage
	cd.mechanic = mechanic
	cd.effect_id = effect_id
	return cd


func _make_energy_data(name: String, energy_type: String, card_type: String = "Basic Energy") -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = card_type
	cd.energy_provides = energy_type
	return cd


func _make_trainer_data(name: String, card_type: String = "Item", effect_id: String = "") -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = card_type
	cd.effect_id = effect_id
	return cd
