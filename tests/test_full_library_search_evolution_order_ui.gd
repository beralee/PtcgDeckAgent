class_name TestFullLibrarySearchEvolutionOrderUI
extends TestBase

const AttackCallForFamilyScript = preload("res://scripts/effects/pokemon_effects/AttackCallForFamily.gd")
const AttackSearchAndAttachScript = preload("res://scripts/effects/pokemon_effects/AttackSearchAndAttach.gd")
const AttackSearchDeckToHandScript = preload("res://scripts/effects/pokemon_effects/AttackSearchDeckToHand.gd")
const AttackSearchDeckToTopScript = preload("res://scripts/effects/pokemon_effects/AttackSearchDeckToTop.gd")
const AttackSearchEnergyFromDeckToSelfScript = preload("res://scripts/effects/pokemon_effects/AttackSearchEnergyFromDeckToSelf.gd")
const AttackTMEvolutionScript = preload("res://scripts/effects/pokemon_effects/AttackTMEvolution.gd")
const AbilityDittoTransformScript = preload("res://scripts/effects/pokemon_effects/AbilityDittoTransform.gd")
const EffectSalvatoreScript = preload("res://scripts/effects/trainer_effects/EffectSalvatore.gd")


func test_ciphermaniac_full_deck_step_keeps_selected_top_order() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.deck.clear()
	var card_a := CardInstance.create(_make_trainer_data("A"), 0)
	var card_b := CardInstance.create(_make_trainer_data("B"), 0)
	var card_c := CardInstance.create(_make_trainer_data("C"), 0)
	var card_d := CardInstance.create(_make_trainer_data("D"), 0)
	player.deck.append_array([card_a, card_b, card_c, card_d])
	var visible_deck := player.deck.duplicate()

	var effect := EffectCiphermaniac.new()
	var supporter := CardInstance.create(_make_trainer_data("Ciphermaniac", "Supporter"), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(supporter, state)
	var step: Dictionary = steps[0] if not steps.is_empty() else {}

	effect.execute(supporter, [{
		"top_cards": [card_c, card_a],
	}], state)

	var checks := _full_deck_step_checks(step, visible_deck, visible_deck, [0, 1, 2, 3], "top_cards", "Ciphermaniac")
	checks.append(assert_eq(int(step.get("min_select", -1)), 2, "Ciphermaniac should require the exact top-card count when the deck has enough cards"))
	checks.append(assert_eq(int(step.get("max_select", -1)), 2, "Ciphermaniac should cap the order selection at two cards"))
	checks.append(assert_eq(player.deck[0], card_c, "The first selected Ciphermaniac card should become the top card"))
	checks.append(assert_eq(player.deck[1], card_a, "The second selected Ciphermaniac card should become the second card"))
	checks.append(assert_eq(player.deck.size(), 4, "Ciphermaniac should preserve deck size"))
	return run_checks(checks)


func test_salvatore_full_deck_evolution_search_filters_to_same_line() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.active_pokemon = _make_slot(_make_pokemon_data("Charmander", "Basic", "", "R"), 0)
	player.bench.clear()
	var ralts_slot := _make_slot(_make_pokemon_data("Ralts", "Basic", "", "P"), 0)
	player.bench.append(ralts_slot)
	player.deck.clear()
	var deck_item := CardInstance.create(_make_trainer_data("Deck Item"), 0)
	var charmeleon := CardInstance.create(_make_pokemon_data("Charmeleon", "Stage 1", "Charmander", "R"), 0)
	var kirlia_with_ability := CardInstance.create(_make_pokemon_data("Kirlia", "Stage 1", "Ralts", "P", 90, [{"name": "Draw", "text": ""}]), 0)
	var wartortle := CardInstance.create(_make_pokemon_data("Wartortle", "Stage 1", "Squirtle", "W"), 0)
	player.deck.append_array([deck_item, charmeleon, kirlia_with_ability, wartortle])
	var visible_deck := player.deck.duplicate()

	var effect := EffectSalvatoreScript.new()
	var salvatore := CardInstance.create(_make_trainer_data("Salvatore", "Supporter"), 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(salvatore, state)
	var search_step: Dictionary = steps[0] if steps.size() > 0 else {}
	var target_step: Dictionary = steps[1] if steps.size() > 1 else {}

	var checks := _full_deck_step_checks(search_step, visible_deck, [charmeleon], [-1, 0, -1, -1], "evolution_card", "Salvatore")
	checks.append(assert_eq(target_step.get("items", []), [player.active_pokemon], "Salvatore should only offer Pokemon that match a legal no-Ability evolution card"))
	checks.append(assert_false(ralts_slot in target_step.get("items", []), "Salvatore should not offer a line whose only deck evolution has an Ability"))
	return run_checks(checks)


func test_tm_evolution_full_deck_search_pairs_selected_evolutions_by_line() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.bench.clear()
	var charmander_slot := _make_slot(_make_pokemon_data("Charmander", "Basic", "", "R"), 0)
	var squirtle_slot := _make_slot(_make_pokemon_data("Squirtle", "Basic", "", "W"), 0)
	player.bench.append_array([charmander_slot, squirtle_slot])
	player.deck.clear()
	var charmeleon := CardInstance.create(_make_pokemon_data("Charmeleon", "Stage 1", "Charmander", "R"), 0)
	var wartortle := CardInstance.create(_make_pokemon_data("Wartortle", "Stage 1", "Squirtle", "W"), 0)
	var deck_item := CardInstance.create(_make_trainer_data("Deck Item"), 0)
	player.deck.append_array([charmeleon, wartortle, deck_item])
	var visible_deck := player.deck.duplicate()

	var effect = AttackTMEvolutionScript.new(2)
	var steps: Array[Dictionary] = effect.get_granted_attack_interaction_steps(player.active_pokemon, {"id": "tm_evolution"}, state)
	var search_step: Dictionary = steps[0] if steps.size() > 0 else {}
	var target_step: Dictionary = steps[1] if steps.size() > 1 else {}

	effect.execute_granted_attack(player.active_pokemon, {"id": "tm_evolution"}, state, [{
		"evolution_cards": [wartortle, charmeleon],
		"evolution_bench": [charmander_slot, squirtle_slot],
	}])

	var checks := _full_deck_step_checks(search_step, visible_deck, [charmeleon, wartortle], [0, 1, -1], "evolution_cards", "TM Evolution")
	checks.append(assert_eq(target_step.get("items", []), [charmander_slot, squirtle_slot], "TM Evolution should offer only bench Pokemon with matching deck evolutions"))
	checks.append(assert_eq(charmander_slot.get_pokemon_name(), "Charmeleon", "TM Evolution should pair Charmeleon with the Charmander line"))
	checks.append(assert_eq(squirtle_slot.get_pokemon_name(), "Wartortle", "TM Evolution should pair Wartortle with the Squirtle line"))
	checks.append(assert_true(deck_item in player.deck, "TM Evolution must leave disabled non-evolution cards in deck"))
	return run_checks(checks)


func test_ditto_transform_full_deck_replacement_ignores_disabled_cards() -> String:
	var state := _make_state()
	state.turn_number = 1
	state.first_player_index = 0
	state.current_player_index = 0
	var player: PlayerState = state.players[0]
	player.deck.clear()
	player.active_pokemon = _make_slot(_make_pokemon_data("Ditto", "Basic", "", "C", 60, [], "Ditto"), 0)
	var deck_ditto := CardInstance.create(_make_pokemon_data("Ditto", "Basic", "", "C", 60, [], "Ditto"), 0)
	var stage_one := CardInstance.create(_make_pokemon_data("Stage One", "Stage 1", "Basic Seed", "C"), 0)
	var legal_basic := CardInstance.create(_make_pokemon_data("Legal Basic", "Basic", "", "L"), 0)
	var deck_item := CardInstance.create(_make_trainer_data("Deck Item"), 0)
	player.deck.append_array([deck_ditto, stage_one, legal_basic, deck_item])
	var visible_deck := player.deck.duplicate()

	var effect := AbilityDittoTransformScript.new()
	var steps: Array[Dictionary] = effect.get_interaction_steps(player.active_pokemon.get_top_card(), state)
	var step: Dictionary = steps[0] if not steps.is_empty() else {}

	effect.execute_ability(player.active_pokemon, 0, [{
		"transform_target": [deck_ditto, stage_one, legal_basic],
	}], state)

	var checks := _full_deck_step_checks(step, visible_deck, [legal_basic], [-1, -1, 0, -1], "transform_target", "Ditto Transform")
	checks.append(assert_eq(player.active_pokemon.get_pokemon_name(), "Legal Basic", "Ditto Transform should replace only with a legal non-Ditto Basic Pokemon"))
	checks.append(assert_true(deck_ditto in player.deck, "Ditto Transform must ignore disabled Ditto replacement cards"))
	checks.append(assert_true(stage_one in player.deck, "Ditto Transform must ignore disabled evolution replacement cards"))
	checks.append(assert_true(deck_item in player.deck, "Ditto Transform must ignore disabled non-Pokemon cards"))
	return run_checks(checks)


func test_beldum_magnetic_lift_full_deck_step_preserves_chosen_top_card() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.deck.clear()
	var card_a := CardInstance.create(_make_trainer_data("Other A"), 0)
	var chosen := CardInstance.create(_make_trainer_data("Chosen Top"), 0)
	var card_b := CardInstance.create(_make_trainer_data("Other B"), 0)
	player.deck.append_array([card_a, chosen, card_b])
	var visible_deck := player.deck.duplicate()

	var effect := AttackSearchDeckToTopScript.new(1)
	var steps: Array[Dictionary] = effect.get_attack_interaction_steps(player.active_pokemon.get_top_card(), {"name": "Magnetic Lift"}, state)
	var step: Dictionary = steps[0] if not steps.is_empty() else {}
	effect.set_attack_interaction_context([{
		"search_cards": [chosen],
	}])
	effect.execute_attack(player.active_pokemon, state.players[1].active_pokemon, 0, state)
	effect.clear_attack_interaction_context()

	var checks := _full_deck_step_checks(step, visible_deck, visible_deck, [0, 1, 2], "search_cards", "Beldum Magnetic Lift")
	checks.append(assert_eq(player.deck[0], chosen, "Magnetic Lift should leave the selected card on top"))
	checks.append(assert_eq(player.deck.size(), 3, "Magnetic Lift should preserve deck size"))
	return run_checks(checks)


func test_call_for_family_full_deck_step_ignores_disabled_non_basics() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.bench.clear()
	player.deck.clear()
	var basic_a := CardInstance.create(_make_pokemon_data("Basic A", "Basic", "", "C"), 0)
	var stage_one := CardInstance.create(_make_pokemon_data("Stage One", "Stage 1", "Basic A", "C"), 0)
	var deck_item := CardInstance.create(_make_trainer_data("Deck Item"), 0)
	var basic_b := CardInstance.create(_make_pokemon_data("Basic B", "Basic", "", "C"), 0)
	player.deck.append_array([basic_a, stage_one, deck_item, basic_b])
	var visible_deck := player.deck.duplicate()

	var effect := AttackCallForFamilyScript.new(2)
	var steps: Array[Dictionary] = effect.get_attack_interaction_steps(player.active_pokemon.get_top_card(), {"name": "Call for Family"}, state)
	var step: Dictionary = steps[0] if not steps.is_empty() else {}
	effect.set_attack_interaction_context([{
		"search_basic_pokemon": [deck_item, basic_b],
	}])
	effect.execute_attack(player.active_pokemon, state.players[1].active_pokemon, 0, state)
	effect.clear_attack_interaction_context()

	var checks := _full_deck_step_checks(step, visible_deck, [basic_a, basic_b], [0, -1, -1, 1], "search_basic_pokemon", "Call for Family")
	checks.append(assert_eq(_bench_names(player), ["Basic B"], "Call for Family should bench only selected legal Basic Pokemon"))
	checks.append(assert_true(stage_one in player.deck, "Call for Family must ignore disabled evolution cards"))
	checks.append(assert_true(deck_item in player.deck, "Call for Family must ignore disabled non-Pokemon cards"))
	return run_checks(checks)


func test_raichu_fast_charge_full_deck_step_ignores_disabled_non_lightning_energy() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.deck.clear()
	player.active_pokemon.attached_energy.clear()
	var fire_energy := CardInstance.create(_make_energy_data("Fire Energy", "R"), 0)
	var lightning_energy := CardInstance.create(_make_energy_data("Lightning Energy", "L"), 0)
	var deck_item := CardInstance.create(_make_trainer_data("Deck Item"), 0)
	player.deck.append_array([fire_energy, lightning_energy, deck_item])
	var visible_deck := player.deck.duplicate()

	var effect := AttackSearchEnergyFromDeckToSelfScript.new("L", 1)
	var steps: Array[Dictionary] = effect.get_attack_interaction_steps(player.active_pokemon.get_top_card(), {"name": "Fast Charge"}, state)
	var step: Dictionary = steps[0] if not steps.is_empty() else {}
	effect.set_attack_interaction_context([{
		"deck_energy": [fire_energy, lightning_energy],
	}])
	effect.execute_attack(player.active_pokemon, state.players[1].active_pokemon, 0, state)
	effect.clear_attack_interaction_context()

	var checks := _full_deck_step_checks(step, visible_deck, [lightning_energy], [-1, 0, -1], "deck_energy", "Raichu Fast Charge")
	checks.append(assert_eq(player.active_pokemon.attached_energy, [lightning_energy], "Fast Charge should attach only selected legal Lightning Energy"))
	checks.append(assert_true(fire_energy in player.deck, "Fast Charge must ignore disabled non-Lightning Energy"))
	checks.append(assert_true(deck_item in player.deck, "Fast Charge must ignore disabled non-Energy cards"))
	return run_checks(checks)


func test_stadium_search_attack_full_deck_step_ignores_disabled_non_stadium() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.deck.clear()
	player.hand.clear()
	var deck_item := CardInstance.create(_make_trainer_data("Deck Item"), 0)
	var stadium := CardInstance.create(_make_trainer_data("Deck Stadium", "Stadium"), 0)
	var pokemon := CardInstance.create(_make_pokemon_data("Deck Pokemon", "Basic", "", "W"), 0)
	player.deck.append_array([deck_item, stadium, pokemon])
	var visible_deck := player.deck.duplicate()

	var effect := AttackSearchDeckToHandScript.new(1, "Stadium")
	var steps: Array[Dictionary] = effect.get_attack_interaction_steps(player.active_pokemon.get_top_card(), {"name": "Subspace Swell"}, state)
	var step: Dictionary = steps[0] if not steps.is_empty() else {}
	effect.set_attack_interaction_context([{
		"search_cards": [deck_item, stadium],
	}])
	effect.execute_attack(player.active_pokemon, state.players[1].active_pokemon, 0, state)
	effect.clear_attack_interaction_context()

	var checks := _full_deck_step_checks(step, visible_deck, [stadium], [-1, 0, -1], "search_cards", "Stadium search attack")
	checks.append(assert_true(stadium in player.hand, "Stadium search attack should move the selected legal Stadium to hand"))
	checks.append(assert_true(deck_item in player.deck, "Stadium search attack must ignore disabled non-Stadium cards"))
	checks.append(assert_true(pokemon in player.deck, "Stadium search attack must ignore disabled non-Trainer cards"))
	return run_checks(checks)


func test_deck_search_energy_assignment_exposes_full_deck_without_polluting_sources() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.bench.clear()
	var v_bench := _make_slot(_make_pokemon_data("Bench V", "Basic", "", "C", 200, [], "", "V"), 0)
	player.bench.append(v_bench)
	player.deck.clear()
	var grass_energy := CardInstance.create(_make_energy_data("Grass Energy", "G"), 0)
	var deck_item := CardInstance.create(_make_trainer_data("Deck Item"), 0)
	var psychic_energy := CardInstance.create(_make_energy_data("Psychic Energy", "P"), 0)
	player.deck.append_array([grass_energy, deck_item, psychic_energy])

	var effect := AttackSearchAndAttachScript.new("", 2, "deck_search", 0, "v_only")
	var steps: Array[Dictionary] = effect.get_attack_interaction_steps(player.active_pokemon.get_top_card(), {"name": "Trinity Charge"}, state)
	var step: Dictionary = steps[0] if not steps.is_empty() else {}

	var checks := _assignment_full_deck_checks(step, player.deck, [grass_energy, psychic_energy], [0, -1, 1], "Energy assignment")
	checks.append(assert_eq(step.get("source_items", []), [grass_energy, psychic_energy], "Assignment sources should remain legal Basic Energy only"))
	checks.append(assert_false(deck_item in step.get("source_items", []), "Assignment source_items must not include disabled visible-only cards"))
	return run_checks(checks)


func _full_deck_step_checks(
	step: Dictionary,
	expected_card_items: Array,
	expected_items: Array,
	expected_indices: Array,
	step_id: String,
	card_name: String
) -> Array[String]:
	var card_items: Array = step.get("card_items", [])
	var legal_items: Array = step.get("items", [])
	var labels: Array = step.get("choice_labels", [])
	return [
		assert_eq(str(step.get("id", "")), step_id, "%s should keep the expected step id" % card_name),
		assert_eq(str(step.get("visible_scope", "")), "own_full_deck", "%s should declare own full-deck visibility" % card_name),
		assert_eq(card_items, expected_card_items, "%s should show the complete searched deck" % card_name),
		assert_eq(legal_items, expected_items, "%s should keep legal selectable items separate" % card_name),
		assert_eq(step.get("card_indices", []), expected_indices, "%s should map disabled visible cards to -1" % card_name),
		assert_eq(labels.size(), expected_card_items.size(), "%s should label every visible card" % card_name),
	]


func _assignment_full_deck_checks(
	step: Dictionary,
	expected_card_items: Array,
	expected_sources: Array,
	expected_indices: Array,
	card_name: String
) -> Array[String]:
	var sources: Array = step.get("source_items", [])
	var source_card_items: Array = step.get("source_card_items", [])
	var labels: Array = step.get("source_choice_labels", [])
	return [
		assert_eq(str(step.get("ui_mode", "")), "card_assignment", "%s should keep assignment UI mode" % card_name),
		assert_eq(str(step.get("source_visible_scope", "")), "own_full_deck", "%s should declare own full-deck source visibility" % card_name),
		assert_eq(source_card_items, expected_card_items, "%s should expose the complete searched deck in source metadata" % card_name),
		assert_eq(sources, expected_sources, "%s should keep legal assignment sources separate" % card_name),
		assert_eq(step.get("source_card_indices", []), expected_indices, "%s should map disabled visible source cards to -1" % card_name),
		assert_eq(labels.size(), expected_card_items.size(), "%s should label every visible card" % card_name),
	]


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
		player.active_pokemon = _make_slot(_make_pokemon_data("Active %d" % pi, "Basic", "", "C"), pi)
		state.players.append(player)
	return state


func _make_pokemon_data(
	name: String,
	stage: String = "Basic",
	evolves_from: String = "",
	energy_type: String = "C",
	hp: int = 80,
	abilities: Array = [],
	name_en: String = "",
	mechanic: String = ""
) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name_en
	cd.card_type = "Pokemon"
	cd.stage = stage
	cd.evolves_from = evolves_from
	cd.energy_type = energy_type
	cd.hp = hp
	var typed_abilities: Array[Dictionary] = []
	for ability: Variant in abilities:
		if ability is Dictionary:
			typed_abilities.append((ability as Dictionary).duplicate(true))
	cd.abilities = typed_abilities
	cd.mechanic = mechanic
	return cd


func _make_trainer_data(name: String, card_type: String = "Item") -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = card_type
	return cd


func _make_energy_data(name: String, energy_type: String, card_type: String = "Basic Energy") -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = card_type
	cd.energy_type = energy_type
	cd.energy_provides = energy_type
	return cd


func _make_slot(cd: CardData, owner_index: int) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(cd, owner_index))
	slot.turn_played = 0
	return slot


func _bench_names(player: PlayerState) -> Array[String]:
	var names: Array[String] = []
	for slot: PokemonSlot in player.bench:
		names.append(slot.get_pokemon_name())
	return names
