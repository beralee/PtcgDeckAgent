class_name TestV18TordReserveTeraRound8
extends TestBase


const DECK_PATH := "res://data/bundled_user/decks/800015934.json"
const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")


func test_seed15304_first_nest_ball_after_setup_builds_a_backup_tera() -> String:
	var strategy := _load_strategy()
	var terapagos: CardData = CardDatabase.get_card("CSV9C", "175")
	var wellspring: CardData = CardDatabase.get_card("CSV8C", "067")
	var teal: CardData = CardDatabase.get_card("CSV8C", "028")
	var fan_rotom: CardData = CardDatabase.get_card("CSV9C", "161")
	var checks: Array[String] = [
		assert_not_null(strategy, "Deck 800015934 should resolve through the production registry"),
		assert_not_null(terapagos, "Terapagos ex should load"),
		assert_not_null(wellspring, "Wellspring Mask Ogerpon ex should load"),
		assert_not_null(teal, "Teal Mask Ogerpon ex should load"),
		assert_not_null(fan_rotom, "Fan Rotom should load"),
	]
	if strategy == null or terapagos == null or wellspring == null or teal == null or fan_rotom == null:
		return run_checks(checks)

	var state := _make_state()
	var player: PlayerState = state.players[0]
	player.active_pokemon = _make_slot(terapagos)
	var wellspring_candidate := CardInstance.create(wellspring, 0)
	var fan_candidate := CardInstance.create(fan_rotom, 0)
	player.deck = [wellspring_candidate, fan_candidate]
	var step := {"id": "basic_pokemon"}
	var context := {"game_state": state, "player_index": 0}
	var reserve_score := float(strategy.call("score_interaction_target", wellspring_candidate, step, context))
	var filler_before_reserve := float(strategy.call("score_interaction_target", fan_candidate, step, context))

	player.bench.append(_make_slot(teal))
	var filler_after_reserve := float(strategy.call("score_interaction_target", fan_candidate, step, context))
	checks.append_array([
		assert_true(reserve_score >= 6000.0, "With only the active Terapagos in play, Nest Ball must establish one backup Tera before filler (score=%f)" % reserve_score),
		assert_true(filler_before_reserve < 0.0, "The first post-setup Nest Ball must not repeat seed15304's Fan Rotom filler pick (score=%f)" % filler_before_reserve),
		assert_true(reserve_score >= filler_before_reserve + 6000.0, "The reserve Tera must deterministically beat Fan Rotom while the attack route has no backup"),
		assert_true(filler_after_reserve >= filler_before_reserve + 1000.0, "After a second Tera reaches the bench, normal Fan Rotom filler scoring must resume"),
	])
	return run_checks(checks)


func _load_strategy() -> RefCounted:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DECK_PATH))
	var deck := DeckData.from_dict(parsed) if parsed is Dictionary else null
	return REGISTRY_SCRIPT.new().resolve_strategy_for_deck(deck) if deck != null else null


func _make_state() -> GameState:
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	state.players = [player, opponent]
	state.current_player_index = 0
	state.turn_number = 9
	state.phase = GameState.GamePhase.MAIN
	return state


func _make_slot(card: CardData) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card, 0))
	return slot
