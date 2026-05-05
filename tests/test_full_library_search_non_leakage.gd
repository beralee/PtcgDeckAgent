class_name TestFullLibrarySearchNonLeakage
extends TestBase

const EffectElectricGeneratorScript = preload("res://scripts/effects/trainer_effects/EffectElectricGenerator.gd")
const EffectLookTopCardsScript = preload("res://scripts/effects/trainer_effects/EffectLookTopCards.gd")
const EffectLookBottomCardsScript = preload("res://scripts/effects/trainer_effects/EffectLookBottomCards.gd")
const EffectMissFortuneSistersScript = preload("res://scripts/effects/trainer_effects/EffectMissFortuneSisters.gd")
const EffectAccompanyingFluteScript = preload("res://scripts/effects/trainer_effects/EffectAccompanyingFlute.gd")
const AILegalActionBuilderScript = preload("res://scripts/ai/AILegalActionBuilder.gd")
const AIStepResolverScript = preload("res://scripts/ai/AIStepResolver.gd")


class VisibleOnlySourceStrategy extends RefCounted:
	var wanted: Variant = null

	func pick_interaction_items(_items: Array, step: Dictionary, _context: Dictionary = {}) -> Array:
		if str(step.get("id", "")) != "energy_assignments":
			return []
		return [wanted]


func _make_card_data(name: String, card_type: String = "Item", energy_type: String = "", stage: String = "Basic") -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.card_type = card_type
	cd.energy_type = energy_type
	cd.energy_provides = energy_type
	cd.stage = stage
	cd.hp = 70
	if card_type == "Pokemon":
		cd.attacks = [{"name": "Test Attack", "cost": "C", "damage": "10", "text": "", "is_vstar_power": false}]
	return cd


func _make_card(name: String, card_type: String = "Item", owner_index: int = 0, energy_type: String = "", stage: String = "Basic") -> CardInstance:
	return CardInstance.create(_make_card_data(name, card_type, energy_type, stage), owner_index)


func _make_slot(name: String, owner_index: int = 0, energy_type: String = "C") -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(_make_card(name, "Pokemon", owner_index, energy_type))
	slot.turn_played = 0
	return slot


func _make_state() -> GameState:
	var state := GameState.new()
	state.turn_number = 2
	state.current_player_index = 0
	CardInstance.reset_id_counter()
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		player.active_pokemon = _make_slot("Active%d" % pi, pi)
		state.players.append(player)
	return state


func _assert_step_does_not_expose_hidden(step: Dictionary, hidden_cards: Array, max_visible_count: int) -> String:
	var card_items: Array = step.get("card_items", [])
	if not card_items.is_empty():
		var check := assert_true(card_items.size() <= max_visible_count, "Limited reveal card_items must not contain more than the rule-visible cards")
		if check != "":
			return check
		for hidden: Variant in hidden_cards:
			check = assert_false(hidden in card_items, "Limited reveal card_items leaked unrevealed card %s" % _card_name(hidden))
			if check != "":
				return check
	var payload_arrays := [
		step.get("items", []),
		step.get("source_items", []),
		step.get("target_items", []),
	]
	for payload_variant: Variant in payload_arrays:
		if not (payload_variant is Array):
			continue
		var payload: Array = payload_variant
		for hidden: Variant in hidden_cards:
			var check := assert_false(hidden in payload, "Limited reveal legal payload leaked unrevealed card %s" % _card_name(hidden))
			if check != "":
				return check
	var title := str(step.get("title", ""))
	for hidden: Variant in hidden_cards:
		var hidden_name := _card_name(hidden)
		var check := assert_false(hidden_name != "" and hidden_name in title, "Limited reveal title leaked unrevealed card %s" % hidden_name)
		if check != "":
			return check
	return ""


func _card_name(value: Variant) -> String:
	if value is CardInstance and (value as CardInstance).card_data != null:
		return str((value as CardInstance).card_data.name)
	return str(value)


func test_electric_generator_reveals_only_top_five_cards() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.bench = [_make_slot("Lightning Bench", 0, "L")]
	var visible_lightning := _make_card("Visible Lightning", "Basic Energy", 0, "L")
	var hidden_lightning := _make_card("Hidden Lightning", "Basic Energy", 0, "L")
	player.deck = [
		_make_card("Top Item 0"),
		visible_lightning,
		_make_card("Top Item 2"),
		_make_card("Top Item 3"),
		_make_card("Top Item 4"),
		_make_card("Hidden Item 5"),
		hidden_lightning,
		_make_card("Hidden Item 7"),
	]
	var effect = EffectElectricGeneratorScript.new()
	var card := _make_card("Electric Generator", "Item", 0)
	var steps: Array[Dictionary] = effect.get_interaction_steps(card, state)
	if steps.is_empty():
		return "Electric Generator should expose a top-5 assignment or reveal step"
	return _assert_step_does_not_expose_hidden(steps[0], [hidden_lightning, player.deck[5], player.deck[7]], 5)


func test_great_ball_and_pokegear_do_not_upgrade_top_seven_to_full_deck() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var hidden_pokemon := _make_card("Hidden Pokemon 8", "Pokemon", 0)
	var hidden_supporter := _make_card("Hidden Supporter 9", "Supporter", 0)
	player.deck = [
		_make_card("Visible Pokemon 0", "Pokemon", 0),
		_make_card("Visible Supporter 1", "Supporter", 0),
		_make_card("Visible Item 2"),
		_make_card("Visible Item 3"),
		_make_card("Visible Item 4"),
		_make_card("Visible Item 5"),
		_make_card("Visible Item 6"),
		_make_card("Hidden Item 7"),
		hidden_pokemon,
		hidden_supporter,
	]
	var great_ball = EffectLookTopCardsScript.new(7, "Pokemon", 1)
	var great_steps: Array[Dictionary] = great_ball.get_interaction_steps(_make_card("Great Ball", "Item", 0), state)
	if great_steps.is_empty():
		return "Great Ball should expose a top-7 search step"
	var great_check := _assert_step_does_not_expose_hidden(great_steps[0], [hidden_pokemon, hidden_supporter], 7)
	if great_check != "":
		return great_check
	var pokegear = EffectLookTopCardsScript.new(7, "Supporter", 1)
	var gear_steps: Array[Dictionary] = pokegear.get_interaction_steps(_make_card("Pokegear 3.0", "Item", 0), state)
	if gear_steps.is_empty():
		return "Pokegear should expose a top-7 search step"
	return _assert_step_does_not_expose_hidden(gear_steps[0], [hidden_pokemon, hidden_supporter], 7)


func test_dusk_ball_reveals_only_bottom_seven_cards() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var hidden_top_pokemon := _make_card("Hidden Top Pokemon", "Pokemon", 0)
	player.deck = [
		hidden_top_pokemon,
		_make_card("Hidden Top Item 1"),
		_make_card("Hidden Top Item 2"),
		_make_card("Bottom Pokemon 3", "Pokemon", 0),
		_make_card("Bottom Item 4"),
		_make_card("Bottom Item 5"),
		_make_card("Bottom Item 6"),
		_make_card("Bottom Item 7"),
		_make_card("Bottom Item 8"),
		_make_card("Bottom Item 9"),
	]
	var effect = EffectLookBottomCardsScript.new(7, "Pokemon", 1)
	var steps: Array[Dictionary] = effect.get_interaction_steps(_make_card("Dusk Ball", "Item", 0), state)
	if steps.is_empty():
		return "Dusk Ball should expose a bottom-7 search step"
	return _assert_step_does_not_expose_hidden(steps[0], [hidden_top_pokemon, player.deck[1], player.deck[2]], 7)


func test_opponent_reveal_effects_do_not_expose_unrevealed_opponent_deck() -> String:
	var state := _make_state()
	var opponent: PlayerState = state.players[1]
	var hidden_opponent_item := _make_card("Opponent Hidden Item", "Item", 1)
	var hidden_opponent_basic := _make_card("Opponent Hidden Basic", "Pokemon", 1)
	opponent.deck = [
		_make_card("Opponent Top Item", "Item", 1),
		_make_card("Opponent Top Basic", "Pokemon", 1),
		_make_card("Opponent Top Supporter", "Supporter", 1),
		_make_card("Opponent Top Stadium", "Stadium", 1),
		_make_card("Opponent Top Tool", "Tool", 1),
		hidden_opponent_item,
		hidden_opponent_basic,
	]
	opponent.bench.clear()
	var miss = EffectMissFortuneSistersScript.new()
	var miss_steps: Array[Dictionary] = miss.get_interaction_steps(_make_card("Miss Fortune Sisters", "Supporter", 0), state)
	if miss_steps.is_empty():
		return "Miss Fortune Sisters should expose an opponent top-5 step"
	var miss_check := _assert_step_does_not_expose_hidden(miss_steps[0], [hidden_opponent_item, hidden_opponent_basic], 5)
	if miss_check != "":
		return miss_check
	var flute = EffectAccompanyingFluteScript.new()
	var flute_steps: Array[Dictionary] = flute.get_interaction_steps(_make_card("Accompanying Flute", "Item", 0), state)
	if flute_steps.is_empty():
		return "Accompanying Flute should expose an opponent top-5 step"
	return _assert_step_does_not_expose_hidden(flute_steps[0], [hidden_opponent_item, hidden_opponent_basic], 5)


func test_headless_assignment_ignores_visible_only_card_items() -> String:
	var legal_fire := _make_card("Legal Fire", "Basic Energy", 0, "R")
	var visible_only_water := _make_card("Visible Only Water", "Basic Energy", 0, "W")
	var target := _make_slot("Target", 0, "R")
	var builder = AILegalActionBuilderScript.new()
	var resolved: Variant = builder.call("_resolve_headless_assignment_step", null, 0, 0, {
		"id": "energy_assignments",
		"ui_mode": "card_assignment",
		"source_items": [legal_fire],
		"target_items": [target],
		"card_items": [visible_only_water, legal_fire],
		"card_indices": [-1, 0],
		"visible_scope": "own_full_deck",
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
		assert_true(legal_fire in sources, "Headless assignment should keep the legal source"),
		assert_false(visible_only_water in sources, "Headless assignment must ignore visible-only card_items"),
	])


func test_ai_step_resolver_filters_strategy_visible_only_assignment_sources() -> String:
	var legal_fire := _make_card("Legal Fire", "Basic Energy", 0, "R")
	var visible_only_water := _make_card("Visible Only Water", "Basic Energy", 0, "W")
	var strategy := VisibleOnlySourceStrategy.new()
	strategy.wanted = visible_only_water
	var resolver = AIStepResolverScript.new()
	resolver.set_deck_strategy(strategy)
	var plan: Dictionary = resolver.call("_build_assignment_source_plan", [legal_fire], 1, 2, {
		"id": "energy_assignments",
		"ui_mode": "card_assignment",
		"source_items": [legal_fire],
		"card_items": [visible_only_water, legal_fire],
		"card_indices": [-1, 0],
		"visible_scope": "own_full_deck",
	})
	var selected_indices: Array = plan.get("selected_source_indices", [])
	return run_checks([
		assert_true(bool(plan.get("has_explicit_plan", false)), "Strategy attempted an explicit assignment plan"),
		assert_true(selected_indices.is_empty(), "AI resolver should discard strategy-picked visible-only sources"),
		assert_false(bool(plan.get("handled", false)), "Required assignment should remain unresolved when only visible-only sources were requested"),
	])
