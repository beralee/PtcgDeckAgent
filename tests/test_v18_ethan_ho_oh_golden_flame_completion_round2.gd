class_name TestV18EthanHoOhGoldenFlameCompletionRound2
extends TestBase


const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const STEP_RESOLVER_SCRIPT = preload("res://scripts/ai/AIStepResolver.gd")
const DECK_PATH := "res://data/bundled_user/decks/800018539.json"
const GOLDEN_FLAME_STEP := "attach_fire_to_benched_ethan"


func test_one_fire_prefers_three_fire_ho_oh_over_one_fire_ho_oh() -> String:
	var strategy := _production_strategy()
	var state := _state()
	var three_fire := _ho_oh_with_basic_fire(3)
	var one_fire := _ho_oh_with_basic_fire(1)
	state.players[0].bench.assign([three_fire, one_fire])
	var result := _assign_basic_fire(strategy, state, [three_fire, one_fire], 1)
	var assignments: Array = result.get("assignments", [])
	return run_checks([
		_assert_production_delegate(strategy),
		assert_eq(int(result.get("made", 0)), 1, "Golden Flame should assign the one available basic Fire"),
		assert_true(
			assignments.size() == 1 and assignments[0].get("target", null) == three_fire,
			"A one-Fire Golden Flame batch should complete the three-Fire Ho-Oh instead of funding the one-Fire Ho-Oh"
		),
	])


func test_two_fire_batch_locks_both_assignments_to_two_fire_ho_oh() -> String:
	var strategy := _production_strategy()
	var state := _state()
	var two_fire := _ho_oh_with_basic_fire(2)
	var empty := _ho_oh_with_basic_fire(0)
	state.players[0].bench.assign([two_fire, empty])
	var result := _assign_basic_fire(strategy, state, [two_fire, empty], 2)
	var assignments: Array = result.get("assignments", [])
	return run_checks([
		_assert_production_delegate(strategy),
		assert_eq(int(result.get("made", 0)), 2, "Golden Flame should assign both available basic Fire cards"),
		assert_true(
			assignments.size() == 2 \
				and assignments[0].get("target", null) == two_fire \
				and assignments[1].get("target", null) == two_fire,
			"The two-Fire batch should complete the two-Fire Ho-Oh and preserve the effect's single-target lock"
		),
	])


func test_ready_ho_oh_scores_below_incomplete_ho_oh_that_batch_can_complete() -> String:
	var strategy := _production_strategy()
	var state := _state()
	var ready := _ho_oh_with_basic_fire(4)
	var completable := _ho_oh_with_basic_fire(2)
	state.players[0].bench.assign([ready, completable])
	var result := _assign_basic_fire(strategy, state, [ready, completable], 2)
	var assignments: Array = result.get("assignments", [])
	return run_checks([
		_assert_production_delegate(strategy),
		assert_true(
			assignments.size() == 2 \
				and assignments[0].get("target", null) == completable \
				and assignments[1].get("target", null) == completable,
			"Golden Flame should complete an incomplete Ho-Oh instead of overfilling an already-ready Ho-Oh"
		),
	])


func test_legacy_with_suppressed_luminous_counts_as_three_fire_before_completion() -> String:
	var strategy := _production_strategy()
	var state := _state()
	var legacy_route := _ho_oh_with_basic_fire(2)
	legacy_route.attached_energy.append(_real_energy("CSV8C_207"))
	legacy_route.attached_energy.append(_real_energy("CSV1C_127"))
	var one_fire := _ho_oh_with_basic_fire(1)
	state.players[0].bench.assign([legacy_route, one_fire])
	var result := _assign_basic_fire(strategy, state, [legacy_route, one_fire], 1)
	var assignments: Array = result.get("assignments", [])
	var delegate: Variant = strategy.get("_delegate") if strategy != null else null
	return run_checks([
		_assert_production_delegate(strategy),
		assert_eq(
			int(delegate.call("_attached_fire", legacy_route)) if delegate is RefCounted else -1,
			3,
			"Two basic Fire plus Legacy and suppressed Luminous must expose a three-Fire completion gap"
		),
		assert_true(
			assignments.size() == 1 and assignments[0].get("target", null) == legacy_route,
			"The production delegate should send one basic Fire to the Legacy route that is truly one Fire short"
		),
	])


func _assign_basic_fire(
	strategy: RefCounted,
	state: GameState,
	targets: Array,
	batch_size: int
) -> Dictionary:
	var sources: Array = []
	for _index: int in batch_size:
		sources.append(_basic_fire())
	state.players[0].hand.assign(sources)
	var assignments: Array[Dictionary] = []
	var apply_assignment := func(source_index: int, target_index: int) -> void:
		assignments.append({
			"source": sources[source_index],
			"target": targets[target_index],
		})
	var step := {
		"id": GOLDEN_FLAME_STEP,
		"ui_mode": "card_assignment",
		"source_items": sources,
		"target_items": targets,
		"min_select": 0,
		"max_select": batch_size,
		"single_target_only": true,
	}
	var resolver: RefCounted = STEP_RESOLVER_SCRIPT.new()
	resolver.call("set_deck_strategy", strategy)
	var state_features: Array[float] = []
	var made := int(resolver.callv("_assign_sources_to_targets", [
		0,
		batch_size,
		sources,
		targets,
		{},
		apply_assignment,
		step,
		{"game_state": state, "player_index": 0},
		state_features,
		{"handled": false, "has_explicit_plan": false, "selected_count": batch_size},
	]))
	return {"made": made, "assignments": assignments}


func _assert_production_delegate(strategy: RefCounted) -> String:
	if strategy == null:
		return assert_true(false, "Deck 800018539 should resolve through the production registry")
	var delegate: Variant = strategy.get("_delegate")
	return assert_true(
		delegate is RefCounted \
			and (delegate as RefCounted).get_script() is Script \
			and str((delegate as RefCounted).get_script().resource_path) == "res://scripts/ai/DeckStrategyV18EthanHoOh.gd",
		"Deck 800018539 should exercise the production Ethan Ho-Oh delegate"
	)


func _production_strategy() -> RefCounted:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DECK_PATH))
	if not parsed is Dictionary:
		return null
	var registry: RefCounted = REGISTRY_SCRIPT.new()
	return registry.call("resolve_strategy_for_deck", DeckData.from_dict(parsed))


func _state() -> GameState:
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	state.players = [player, opponent]
	state.current_player_index = 0
	state.turn_number = 5
	state.phase = GameState.GamePhase.MAIN
	return state


func _ho_oh_with_basic_fire(count: int) -> PokemonSlot:
	var card := CardData.new()
	card.name = "Ethan's Ho-Oh ex"
	card.name_en = "Ethan's Ho-Oh ex"
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.energy_type = "R"
	card.hp = 230
	card.attacks = [{"name": "Shining Feather", "cost": "RRRR", "damage": "160"}]
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, 0))
	for _index: int in count:
		slot.attached_energy.append(_basic_fire())
	return slot


func _basic_fire() -> CardInstance:
	var card := CardData.new()
	card.name = "Fire Energy"
	card.name_en = "Fire Energy"
	card.card_type = "Basic Energy"
	card.energy_type = "R"
	card.energy_provides = "R"
	return CardInstance.create(card, 0)


func _real_energy(ref: String) -> CardInstance:
	var path := "res://data/bundled_user/cards/%s.json" % ref
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return CardInstance.create(CardData.from_dict(parsed), 0)
