class_name TestV18TordPivotRetreatLegalityRound4
extends TestBase


const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const DECK_ID := 800015934
const REPLAY_SEED := 15508
const LOCK_PIVOT_ACTION_SCORE := 4400.0


func test_legal_pivot_still_beats_direct_terapagos_attachment() -> String:
	return _assert_pivot_legality_case("legal", false, false, false)


func test_asleep_active_must_attach_directly_to_terapagos() -> String:
	return _assert_pivot_legality_case("asleep", true, false, false)


func test_retreat_used_active_must_attach_directly_to_terapagos() -> String:
	return _assert_pivot_legality_case("retreat_used", false, true, false)


func test_retreat_locked_active_must_attach_directly_to_terapagos() -> String:
	return _assert_pivot_legality_case("retreat_lock", false, false, true)


func _assert_pivot_legality_case(
	case_name: String,
	asleep: bool,
	retreat_used: bool,
	retreat_locked: bool
) -> String:
	var strategy := _production_strategy()
	var state := _state()
	var active := _evolved_noctowl()
	var terapagos := _ready_terapagos()
	var energy := _basic_energy("Grass Energy", "G")
	if strategy == null or active == null or terapagos == null:
		return assert_true(false, "%s fixtures should load" % case_name)
	active.status_conditions["asleep"] = asleep
	if retreat_locked:
		active.effects.append({"type": "retreat_lock", "turn": state.turn_number - 1})
	state.retreat_used_this_turn = retreat_used
	state.players[0].active_pokemon = active
	state.players[0].bench = [terapagos]
	state.players[0].hand = [energy]

	var active_score := _score_attachment(strategy, state, energy, active)
	var terapagos_score := _score_attachment(strategy, state, energy, terapagos)
	if case_name == "legal":
		return run_checks([
			assert_true(active_score >= LOCK_PIVOT_ACTION_SCORE, "Legal Active pivot must retain the pivot floor (got %f)" % active_score),
			assert_true(active_score > terapagos_score, "Legal pivot must beat direct Terapagos attachment (%f vs %f)" % [active_score, terapagos_score]),
		])
	return run_checks([
		assert_true(active_score < LOCK_PIVOT_ACTION_SCORE, "%s Active must not receive the pivot floor (got %f)" % [case_name, active_score]),
		assert_true(terapagos_score > active_score, "Direct Terapagos attachment must beat %s pivot funding (%f vs %f)" % [case_name, terapagos_score, active_score]),
	])


func _score_attachment(strategy: RefCounted, state: GameState, energy: CardInstance, target: PokemonSlot) -> float:
	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {"replay_seed": REPLAY_SEED})
	return float(strategy.call("score_action_absolute_with_plan", {
		"kind": "attach_energy",
		"card": energy,
		"target_slot": target,
	}, state, 0, plan))


func _production_strategy() -> RefCounted:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/bundled_user/decks/%d.json" % DECK_ID
	))
	if not parsed is Dictionary:
		return null
	return REGISTRY_SCRIPT.new().call("resolve_strategy_for_deck", DeckData.from_dict(parsed))


func _state() -> GameState:
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	state.players = [player, opponent]
	state.current_player_index = 0
	state.first_player_index = 0
	state.turn_number = 5
	state.phase = GameState.GamePhase.MAIN
	return state


func _card(set_code: String, card_index: String) -> CardInstance:
	var data := CardDatabase.get_card(set_code, card_index)
	return CardInstance.create(data, 0) if data != null else null


func _evolved_noctowl() -> PokemonSlot:
	var hoothoot := _card("CSV9C", "154")
	var noctowl := _card("CSV9C", "155")
	if hoothoot == null or noctowl == null:
		return null
	var slot := PokemonSlot.new()
	slot.pokemon_stack = [hoothoot, noctowl]
	return slot


func _ready_terapagos() -> PokemonSlot:
	var terapagos := _card("CSV9C", "175")
	if terapagos == null:
		return null
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(terapagos)
	slot.attached_energy = [
		_basic_energy("Grass Energy", "G"),
		_basic_energy("Water Energy", "W"),
	]
	return slot


func _basic_energy(card_name: String, symbol: String) -> CardInstance:
	var data := CardData.new()
	data.name = card_name
	data.name_en = card_name
	data.card_type = "Basic Energy"
	data.energy_type = symbol
	data.energy_provides = symbol
	return CardInstance.create(data, 0)
