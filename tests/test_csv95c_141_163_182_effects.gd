class_name TestCSV95C141163182Effects
extends TestBase

const AILegalActionBuilderScript = preload("res://scripts/ai/AILegalActionBuilder.gd")
const CSV95C182AokisSkillScript = preload("res://scripts/effects/trainer_effects/CSV95C182AokisSkill.gd")
const EffectApplyStatusScript = preload("res://scripts/effects/pokemon_effects/EffectApplyStatus.gd")
const EffectLanasAidScript = preload("res://scripts/effects/trainer_effects/EffectLanasAid.gd")

const HOOTHOOT_ID := "76f4e0d39348c21f1f1a4be4d653b6a5"
const AOKI_ID := "60efb96839df10bb78737047da1c4fb1"


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
	var max_rod := CardInstance.create(_make_trainer_data("Max Rod", "Item", "6a7fe7ec3f22c435f50b49909e85b3d3"), 0)
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
