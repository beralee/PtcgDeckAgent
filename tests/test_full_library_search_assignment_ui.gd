class_name TestFullLibrarySearchAssignmentUI
extends TestBase

const AbilityAttachFromDeckScript = preload("res://scripts/effects/pokemon_effects/AbilityAttachFromDeck.gd")
const AILegalActionBuilderScript = preload("res://scripts/ai/AILegalActionBuilder.gd")
const AttackSearchAndAttachScript = preload("res://scripts/effects/pokemon_effects/AttackSearchAndAttach.gd")
const EffectJaninesSecretArtScript = preload("res://scripts/effects/trainer_effects/EffectJaninesSecretArt.gd")
const EffectMirageGateScript = preload("res://scripts/effects/trainer_effects/EffectMirageGate.gd")
const EffectTMTurboEnergizeScript = preload("res://scripts/effects/trainer_effects/EffectTMTurboEnergize.gd")


func _make_card_data(
	name: String,
	card_type: String = "Item",
	energy_type: String = "",
	stage: String = "Basic",
	tags: PackedStringArray = PackedStringArray()
) -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = card_type
	cd.energy_type = energy_type
	cd.energy_provides = energy_type
	cd.stage = stage
	cd.hp = 100
	cd.is_tags = tags
	return cd


func _make_card(
	name: String,
	card_type: String = "Item",
	energy_type: String = "",
	owner_index: int = 0,
	stage: String = "Basic",
	tags: PackedStringArray = PackedStringArray()
) -> CardInstance:
	return CardInstance.create(_make_card_data(name, card_type, energy_type, stage, tags), owner_index)


func _make_slot(
	name: String,
	energy_type: String = "C",
	owner_index: int = 0,
	tags: PackedStringArray = PackedStringArray()
) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(_make_card(name, "Pokemon", energy_type, owner_index, "Basic", tags))
	slot.turn_played = 0
	return slot


func _make_state() -> GameState:
	CardInstance.reset_id_counter()
	var state := GameState.new()
	state.phase = GameState.GamePhase.MAIN
	state.current_player_index = 0
	state.turn_number = 2
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		player.active_pokemon = _make_slot("Active%d" % pi, "C", pi)
		player.bench.append(_make_slot("Bench%d" % pi, "C", pi))
		state.players.append(player)
	return state


func _assert_assignment_source_deck_visibility(
	step: Dictionary,
	visible_cards: Array,
	legal_sources: Array,
	source_indices: Array,
	target_items: Array,
	step_id: String,
	context_name: String
) -> String:
	var source_choice_labels: Array = step.get("source_choice_labels", [])
	return run_checks([
		assert_eq(str(step.get("id", "")), step_id, "%s should keep the same step id" % context_name),
		assert_eq(str(step.get("ui_mode", "")), "card_assignment", "%s should stay on assignment UI" % context_name),
		assert_eq(step.get("source_items", []), legal_sources, "%s source_items must contain only legal assignable sources" % context_name),
		assert_eq(step.get("target_items", []), target_items, "%s target_items must be unchanged" % context_name),
		assert_eq(step.get("source_card_items", []), visible_cards, "%s should expose the complete searched deck as source_card_items" % context_name),
		assert_eq(step.get("source_card_indices", []), source_indices, "%s should map visible source cards to legal source indices" % context_name),
		assert_eq(str(step.get("source_visible_scope", "")), "own_full_deck", "%s should declare own full-deck source visibility" % context_name),
		assert_eq(source_choice_labels.size(), visible_cards.size(), "%s should label every visible source card" % context_name),
		assert_eq(int(step.get("source_selectable_count", -1)), legal_sources.size(), "%s should keep source selectable count separate" % context_name),
	])


func test_mirage_gate_full_deck_sources_keep_unique_basic_energy_pool() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.deck.clear()
	player.lost_zone.clear()
	for i: int in 7:
		player.lost_zone.append(_make_card("Lost%d" % i, "Pokemon", "C"))
	var grass_a := _make_card("Grass A", "Basic Energy", "G")
	var grass_b := _make_card("Grass B", "Basic Energy", "G")
	var psychic := _make_card("Psychic", "Basic Energy", "P")
	var item := _make_card("Deck Item", "Item")
	player.deck.append_array([grass_a, grass_b, item, psychic])
	var visible_deck := player.deck.duplicate()
	var targets := player.get_all_pokemon()
	var effect := EffectMirageGateScript.new()
	var card := _make_card("Mirage Gate")
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, state)
	var step: Dictionary = steps[0] if not steps.is_empty() else {}

	effect.execute(card, [{
		"mirage_gate_assignments": [
			{"source": grass_b, "target": player.active_pokemon},
			{"source": psychic, "target": player.bench[0]},
		],
	}], state)

	var checks: Array[String] = [
		assert_eq(steps.size(), 1, "Mirage Gate should expose one assignment step"),
		_assert_assignment_source_deck_visibility(
			step,
			visible_deck,
			[grass_a, psychic],
			[0, -1, -1, 1],
			targets,
			"mirage_gate_assignments",
			"Mirage Gate"
		),
		assert_false(grass_b in player.active_pokemon.attached_energy, "Execution must ignore same-type visible-only duplicate source"),
		assert_true(grass_b in player.deck, "Visible-only duplicate Basic Energy should remain in deck"),
		assert_true(psychic in player.bench[0].attached_energy, "Legal different-type source should still attach"),
	]
	return run_checks(checks)


func test_ability_attach_from_deck_archeops_and_charizard_sources_show_full_deck() -> String:
	var archeops_state := _make_state()
	var archeops_player: PlayerState = archeops_state.players[0]
	archeops_player.deck.clear()
	var special_a := _make_card("Double Turbo", "Special Energy", "C")
	var basic_fire := _make_card("Fire Energy", "Basic Energy", "R")
	var special_b := _make_card("Gift Energy", "Special Energy", "C")
	var deck_item := _make_card("Deck Item", "Item")
	archeops_player.deck.append_array([special_a, basic_fire, deck_item, special_b])
	var archeops_visible := archeops_player.deck.duplicate()
	var archeops_effect := AbilityAttachFromDeckScript.new("Special Energy", 2, "own_one", false, true)
	var archeops_steps: Array[Dictionary] = archeops_effect.get_interaction_steps(archeops_player.active_pokemon.get_top_card(), archeops_state)
	var archeops_step: Dictionary = archeops_steps[0] if not archeops_steps.is_empty() else {}

	var charizard_state := _make_state()
	var charizard_player: PlayerState = charizard_state.players[0]
	charizard_player.deck.clear()
	var fire_a := _make_card("Fire A", "Basic Energy", "R")
	var water := _make_card("Water", "Basic Energy", "W")
	var fire_b := _make_card("Fire B", "Basic Energy", "R")
	var special := _make_card("Special Fire", "Special Energy", "R")
	charizard_player.deck.append_array([fire_a, water, fire_b, special])
	var charizard_visible := charizard_player.deck.duplicate()
	var charizard_effect := AbilityAttachFromDeckScript.new("R", 3, "own", true, false)
	var charizard_steps: Array[Dictionary] = charizard_effect.get_interaction_steps(charizard_player.active_pokemon.get_top_card(), charizard_state)
	var charizard_step: Dictionary = charizard_steps[0] if not charizard_steps.is_empty() else {}

	var checks: Array[String] = [
		assert_eq(archeops_steps.size(), 1, "Archeops should expose one assignment step"),
		_assert_assignment_source_deck_visibility(
			archeops_step,
			archeops_visible,
			[special_a, special_b],
			[0, -1, -1, 1],
			archeops_player.get_all_pokemon(),
			"energy_assignments",
			"Archeops Primal Turbo"
		),
		assert_eq(charizard_steps.size(), 1, "Charizard ex should expose one assignment step"),
		_assert_assignment_source_deck_visibility(
			charizard_step,
			charizard_visible,
			[fire_a, fire_b],
			[0, -1, 1, -1],
			charizard_player.get_all_pokemon(),
			"energy_assignments",
			"Charizard ex Infernal Reign"
		),
	]
	return run_checks(checks)


func test_janine_full_deck_sources_and_execution_ignore_illegal_source() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.active_pokemon = _make_slot("Dark Active", "D")
	player.bench = [_make_slot("Dark Bench", "D")]
	player.deck.clear()
	var water := _make_card("Water", "Basic Energy", "W")
	var dark_a := _make_card("Dark A", "Basic Energy", "D")
	var item := _make_card("Deck Item", "Item")
	var dark_b := _make_card("Dark B", "Basic Energy", "D")
	player.deck.append_array([water, dark_a, item, dark_b])
	var visible_deck := player.deck.duplicate()
	var targets := player.get_all_pokemon()
	var effect := EffectJaninesSecretArtScript.new()
	var card := _make_card("Janine's Secret Art", "Supporter")
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, state)
	var step: Dictionary = steps[0] if not steps.is_empty() else {}

	effect.execute(card, [{
		"janine_assignments": [
			{"source": water, "target": player.active_pokemon},
			{"source": dark_b, "target": player.bench[0]},
		],
	}], state)

	var checks: Array[String] = [
		assert_eq(steps.size(), 1, "Janine should expose one assignment step"),
		_assert_assignment_source_deck_visibility(
			step,
			visible_deck,
			[dark_a, dark_b],
			[-1, 0, -1, 1],
			targets,
			"janine_assignments",
			"Janine's Secret Art"
		),
		assert_false(water in player.active_pokemon.attached_energy, "Execution must ignore visible-only non-Dark Energy"),
		assert_true(water in player.deck, "Visible-only non-Dark Energy should remain in deck"),
		assert_true(dark_b in player.bench[0].attached_energy, "Legal Dark Energy should attach"),
	]
	return run_checks(checks)


func test_tm_turbo_energize_full_deck_sources_and_execution_ignore_illegal_source() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.deck.clear()
	var grass := _make_card("Grass", "Basic Energy", "G")
	var item := _make_card("Deck Item", "Item")
	var special := _make_card("Special", "Special Energy", "C")
	var lightning := _make_card("Lightning", "Basic Energy", "L")
	player.deck.append_array([grass, item, special, lightning])
	var visible_deck := player.deck.duplicate()
	var targets := player.bench.duplicate()
	var effect := EffectTMTurboEnergizeScript.new()
	var steps: Array[Dictionary] = effect.get_granted_attack_interaction_steps(player.active_pokemon, {}, state)
	var step: Dictionary = steps[0] if not steps.is_empty() else {}

	effect.execute_granted_attack(player.active_pokemon, {"id": "tm_turbo_energize"}, state, [{
		"tm_turbo_energize": [
			{"source": special, "target": player.bench[0]},
			{"source": lightning, "target": player.bench[0]},
		],
	}])

	var checks: Array[String] = [
		assert_eq(steps.size(), 1, "TM Turbo Energize should expose one assignment step"),
		_assert_assignment_source_deck_visibility(
			step,
			visible_deck,
			[grass, lightning],
			[0, -1, -1, 1],
			targets,
			"tm_turbo_energize",
			"TM Turbo Energize"
		),
		assert_false(special in player.bench[0].attached_energy, "Execution must ignore visible-only Special Energy"),
		assert_true(special in player.deck, "Visible-only Special Energy should remain in deck"),
		assert_true(lightning in player.bench[0].attached_energy, "Legal Basic Energy should attach"),
	]
	return run_checks(checks)


func test_attack_search_and_attach_deck_search_sources_show_full_deck() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var future_tags := PackedStringArray([CardData.FUTURE_TAG])
	player.active_pokemon = _make_slot("Future Active", "C", 0, future_tags)
	player.bench = [_make_slot("Future Bench", "C", 0, future_tags)]
	player.deck.clear()
	var lightning := _make_card("Lightning", "Basic Energy", "L")
	var item := _make_card("Deck Item", "Item")
	var fighting := _make_card("Fighting", "Basic Energy", "F")
	var special := _make_card("Special", "Special Energy", "C")
	player.deck.append_array([lightning, item, fighting, special])
	var visible_deck := player.deck.duplicate()
	var targets: Array = [player.bench[0], player.active_pokemon]
	var effect := AttackSearchAndAttachScript.new("", 2, "deck_search", 0, "any", CardData.FUTURE_TAG)
	var steps: Array[Dictionary] = effect.get_attack_interaction_steps(
		player.active_pokemon.get_top_card(),
		{},
		state
	)
	var step: Dictionary = steps[0] if not steps.is_empty() else {}

	return run_checks([
		assert_eq(steps.size(), 1, "AttackSearchAndAttach should expose one assignment step"),
		_assert_assignment_source_deck_visibility(
			step,
			visible_deck,
			[lightning, fighting],
			[0, -1, 1, -1],
			targets,
			"energy_assignments",
			"AttackSearchAndAttach"
		),
	])


func test_headless_assignment_ignores_source_card_items_metadata() -> String:
	var legal_fire := _make_card("Legal Fire", "Basic Energy", "R")
	var visible_only_water := _make_card("Visible Water", "Basic Energy", "W")
	var target := _make_slot("Target", "R")
	var builder = AILegalActionBuilderScript.new()
	var resolved: Variant = builder.call("_resolve_headless_assignment_step", null, 0, 0, {
		"id": "energy_assignments",
		"ui_mode": "card_assignment",
		"source_items": [legal_fire],
		"target_items": [target],
		"source_card_items": [visible_only_water, legal_fire],
		"source_card_indices": [-1, 0],
		"source_visible_scope": "own_full_deck",
		"min_select": 1,
		"max_select": 2,
	})
	var assignments: Array = resolved.get("energy_assignments", []) if resolved is Dictionary else []
	var sources: Array = []
	for assignment_variant: Variant in assignments:
		if assignment_variant is Dictionary:
			sources.append((assignment_variant as Dictionary).get("source"))
	return run_checks([
		assert_eq(assignments.size(), 1, "Headless assignment should resolve only legal source_items"),
		assert_true(legal_fire in sources, "Headless assignment should use legal source_items"),
		assert_false(visible_only_water in sources, "Headless assignment must ignore source_card_items metadata"),
	])
