class_name TestV18FlareonWellspringChipRound9
extends TestBase


const DECK_PATH := "res://data/bundled_user/decks/800017643.json"
const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")


func test_short_and_long_losses_keep_wellspring_chip_below_live_eevee_route() -> String:
	var strategy := _load_strategy()
	var wellspring: CardData = CardDatabase.get_card("CSV8C", "067")
	var eevee: CardData = CardDatabase.get_card("151C", "133")
	var flareon: CardData = CardDatabase.get_card("CSV9.5C", "023")
	var water: CardData = CardDatabase.get_card("CSVE1C", "WAT")
	var checks: Array[String] = [
		assert_not_null(strategy, "Deck 800017643 should resolve through the production registry"),
		assert_not_null(wellspring, "Wellspring Mask Ogerpon ex should load"),
		assert_not_null(eevee, "The seed15302 Eevee should load"),
		assert_not_null(flareon, "Flareon ex should load"),
		assert_not_null(water, "Water Energy should load"),
	]
	if strategy == null or wellspring == null or eevee == null or flareon == null or water == null:
		return run_checks(checks)

	var state := _make_state()
	var player: PlayerState = state.players[0]
	var active_wellspring := _make_slot(wellspring)
	var eevee_lane := _make_slot(eevee)
	player.active_pokemon = active_wellspring
	player.bench = [eevee_lane]
	player.deck.append(CardInstance.create(flareon, 0))
	var energy := CardInstance.create(water, 0)
	var chip_score := _score(strategy, {
		"kind": "attach_energy",
		"card": energy,
		"target_slot": active_wellspring,
	}, state)
	var lane_score := _score(strategy, {
		"kind": "attach_energy",
		"card": energy,
		"target_slot": eevee_lane,
	}, state)
	active_wellspring.attached_energy.append(energy)
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	checks.append_array([
		assert_true(chip_score < 0.0, "One-Energy 20-damage Sob must not consume the attachment while a compatible Eevee lane is live (score=%f)" % chip_score),
		assert_true(lane_score > chip_score + 2000.0, "The typed Flareon lane must outrank funding Wellspring chip (eevee=%f wellspring=%f)" % [lane_score, chip_score]),
		assert_eq(str(plan.get("intent", "")), "fund_flareon_attack_route", "A 20-damage Wellspring must not retire the live Flareon setup debt"),
	])
	return run_checks(checks)


func test_wellspring_chip_remains_available_without_a_compatible_eevee_lane() -> String:
	var strategy := _load_strategy()
	var wellspring: CardData = CardDatabase.get_card("CSV8C", "067")
	var water: CardData = CardDatabase.get_card("CSVE1C", "WAT")
	if strategy == null or wellspring == null or water == null:
		return assert_true(false, "The production strategy, Wellspring, and Water Energy should load")
	var state := _make_state()
	var active_wellspring := _make_slot(wellspring)
	state.players[0].active_pokemon = active_wellspring
	var score := _score(strategy, {
		"kind": "attach_energy",
		"card": CardInstance.create(water, 0),
		"target_slot": active_wellspring,
	}, state)
	return assert_true(score > 2000.0, "Without a live Eevee evolution lane, Wellspring chip should remain a legal fallback route (score=%f)" % score)


func _load_strategy() -> RefCounted:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DECK_PATH))
	var deck := DeckData.from_dict(parsed) if parsed is Dictionary else null
	return REGISTRY_SCRIPT.new().resolve_strategy_for_deck(deck) if deck != null else null


func _score(strategy: RefCounted, action: Dictionary, state: GameState) -> float:
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	return float(strategy.call("score_action_absolute_with_plan", action, state, 0, plan))


func _make_state() -> GameState:
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	state.players = [player, opponent]
	state.current_player_index = 0
	state.turn_number = 3
	state.phase = GameState.GamePhase.MAIN
	return state


func _make_slot(card: CardData) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, 0))
	return slot
