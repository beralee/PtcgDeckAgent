class_name TestDeckIdentityTracker
extends TestBase

const DeckIdentityTrackerScript = preload("res://scripts/ai/DeckIdentityTracker.gd")


func _make_card(
	name: String,
	card_type: String,
	stage: String = "",
	energy_type: String = "",
	mechanic: String = "",
	evolves_from: String = "",
	attack_name: String = "",
	ability_name: String = ""
) -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = card_type
	card.stage = stage
	card.energy_type = energy_type
	card.mechanic = mechanic
	card.evolves_from = evolves_from
	card.attacks.clear()
	if attack_name != "":
		card.attacks.append({
			"name": attack_name,
			"text": "",
			"cost": "",
			"damage": "",
			"is_vstar_power": false,
		})
	card.abilities.clear()
	if ability_name != "":
		card.abilities.append({
			"name": ability_name,
			"text": "",
		})
	return card


func _make_slot(card: CardData, owner_index: int = 0, attached_energy_count: int = 0, attached_energy_type: String = "") -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, owner_index))
	for _i in attached_energy_count:
		var energy_card := _make_card("Basic %s Energy" % attached_energy_type, "Basic Energy", "", attached_energy_type)
		slot.attached_energy.append(CardInstance.create(energy_card, owner_index))
	return slot


func _make_state(board_cards: Array[CardData], attached_energy_count: int = 0, attached_energy_type: String = "") -> GameState:
	var state := GameState.new()
	state.players = [PlayerState.new(), PlayerState.new()]
	for pi in 2:
		state.players[pi].player_index = pi
	if not board_cards.is_empty():
		state.players[0].active_pokemon = _make_slot(board_cards[0], 0, attached_energy_count, attached_energy_type)
		for idx in range(1, board_cards.size()):
			state.players[0].bench.append(_make_slot(board_cards[idx], 0))
	return state


func _make_action(action_type: GameAction.ActionType, player_index: int, data: Dictionary) -> GameAction:
	return GameAction.create(action_type, player_index, data, 1, "identity tracker test")


func _run_hits(deck_key: String, actions: Array[GameAction], state: GameState = null) -> Dictionary:
	var tracker := DeckIdentityTrackerScript.new()
	return tracker.build_identity_hits(deck_key, actions, state)


func test_miraidon_bench_developed() -> String:
	var state := _make_state([
		_make_card("Lightning Basic A", "Pokemon", "Basic", "L"),
		_make_card("Lightning Basic B", "Pokemon", "Basic", "L"),
		_make_card("Colorless Basic", "Pokemon", "Basic", "C"),
	])
	var hits := _run_hits("miraidon", [], state)
	return run_checks([
		assert_true(bool(hits.get("miraidon_bench_developed", false)), "Miraidon bench development should be detected from board state"),
		assert_false(bool(hits.get("electric_generator_resolved", false)), "Unrelated Miraidon flags should remain false"),
		assert_false(bool(hits.get("miraidon_attack_ready", false)), "Unrelated Miraidon flags should remain false"),
	])


func test_electric_generator_resolved() -> String:
	var hits := _run_hits("miraidon", [
		_make_action(GameAction.ActionType.PLAY_TRAINER, 0, {"card_name": "Electric Generator"}),
	])
	return run_checks([
		assert_true(bool(hits.get("electric_generator_resolved", false)), "Electric Generator should be detected as resolved"),
	])


func test_miraidon_attack_ready() -> String:
	var hits := _run_hits("miraidon", [
		_make_action(GameAction.ActionType.ATTACK, 0, {"attack_name": "Photon Blaster"}),
	])
	return run_checks([
		assert_true(bool(hits.get("miraidon_attack_ready", false)), "Miraidon ex attack readiness should be detected"),
	])


func test_gardevoir_stage2_online() -> String:
	var hits := _run_hits("gardevoir", [
		_make_action(GameAction.ActionType.EVOLVE, 0, {"evolution": "Gardevoir ex", "base": "Kirlia"}),
	])
	return run_checks([
		assert_true(bool(hits.get("gardevoir_stage2_online", false)), "Gardevoir ex appearing on board should be detected"),
	])


func test_psychic_embrace_resolved() -> String:
	var hits := _run_hits("gardevoir", [
		_make_action(GameAction.ActionType.USE_ABILITY, 0, {"pokemon_name": "Gardevoir ex", "ability_name": "Psychic Embrace"}),
	])
	return run_checks([
		assert_true(bool(hits.get("psychic_embrace_resolved", false)), "Psychic Embrace resolution should be detected"),
	])


func test_gardevoir_energy_loop_online() -> String:
	var state := _make_state([
		_make_card("Gardevoir ex", "Pokemon", "Stage 2", "P", "ex", "Kirlia"),
	], 1, "P")
	var hits := _run_hits("gardevoir", [
		_make_action(GameAction.ActionType.USE_ABILITY, 0, {"pokemon_name": "Gardevoir ex", "ability_name": "Psychic Embrace"}),
		_make_action(GameAction.ActionType.ATTACK, 0, {"attack_name": "Miracle Force"}),
	], state)
	return run_checks([
		assert_true(bool(hits.get("gardevoir_energy_loop_online", false)), "Psychic Embrace followed by a later attack should mark the energy loop as online"),
	])


func test_gardevoir_energy_loop_requires_attack_after_psychic_embrace() -> String:
	var hits := _run_hits("gardevoir", [
		_make_action(GameAction.ActionType.ATTACK, 0, {"attack_name": "Miracle Force"}),
		_make_action(GameAction.ActionType.USE_ABILITY, 0, {"pokemon_name": "Gardevoir ex", "ability_name": "Psychic Embrace"}),
	])
	return run_checks([
		assert_false(bool(hits.get("gardevoir_energy_loop_online", false)), "The Gardevoir energy loop should require an attack after Psychic Embrace, not before it"),
	])


func test_charizard_stage2_online() -> String:
	var hits := _run_hits("charizard_ex", [
		_make_action(GameAction.ActionType.EVOLVE, 0, {"evolution": "Charizard ex", "base": "Charmeleon"}),
	])
	return run_checks([
		assert_true(bool(hits.get("charizard_stage2_online", false)), "Charizard ex appearing on board should be detected"),
	])


func test_charizard_evolution_support_used() -> String:
	var hits := _run_hits("charizard_ex", [
		_make_action(GameAction.ActionType.PLAY_TRAINER, 0, {"card_name": "Rare Candy"}),
	])
	return run_checks([
		assert_true(bool(hits.get("charizard_evolution_support_used", false)), "Rare Candy should be detected as Charizard evolution support"),
	])


func test_charizard_evolution_support_used_on_direct_fire_line_evolution() -> String:
	var hits := _run_hits("charizard_ex", [
		_make_action(GameAction.ActionType.EVOLVE, 0, {"evolution": "Charmeleon", "base": "Charmander"}),
	])
	return run_checks([
		assert_true(bool(hits.get("charizard_evolution_support_used", false)), "Direct evolution into the Charizard line is an allowed Phase 2 proxy for evolution support"),
	])


func test_charizard_evolution_support_ignores_unrelated_evolution() -> String:
	var hits := _run_hits("charizard_ex", [
		_make_action(GameAction.ActionType.EVOLVE, 0, {"evolution": "Pidgeot ex", "base": "Pidgey"}),
	])
	return run_checks([
		assert_false(bool(hits.get("charizard_evolution_support_used", false)), "Unrelated evolution should not count as Charizard evolution support"),
	])


func test_charizard_attack_ready() -> String:
	var hits := _run_hits("charizard_ex", [
		_make_action(GameAction.ActionType.ATTACK, 0, {"attack_name": "Burning Darkness"}),
	])
	return run_checks([
		assert_true(bool(hits.get("charizard_attack_ready", false)), "Charizard ex attack readiness should be detected"),
	])
