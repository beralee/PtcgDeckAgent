class_name TestV18TordActivePivotAttachmentRound3
extends TestBase


const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")

const DECK_ID := 800015934
const REPLAY_SEED := 15508
const RULES_PATH := "res://scripts/ai/DeckStrategyV18Rules.gd"
const DELEGATE_PATH := "res://scripts/ai/DeckStrategyV18TeraNoctowl.gd"
const LOCK_PIVOT_ACTION_SCORE := 4400.0


func test_seed15508_active_noctowl_attach_beats_bench_support_with_ready_terapagos() -> String:
	var strategy := _production_strategy()
	var state := _state()
	var noctowl := _evolved_noctowl()
	var bench_hoothoot := _slot("CSV9C", "154")
	var terapagos := _ready_terapagos()
	var energy := _basic_energy("Grass Energy", "G")
	if strategy == null or noctowl == null or bench_hoothoot == null or terapagos == null:
		return assert_true(false, "Seed %d Tord pivot fixtures should load" % REPLAY_SEED)
	state.players[0].active_pokemon = noctowl
	state.players[0].bench = [bench_hoothoot, terapagos]
	state.players[0].hand = [energy]

	var active_score := _score_attachment(strategy, state, energy, noctowl)
	var support_score := _score_attachment(strategy, state, energy, bench_hoothoot)
	return run_checks([
		assert_eq(strategy.get_script().resource_path, RULES_PATH, "Seed replay must score through the production V18Rules wrapper"),
		assert_eq(_delegate_path(strategy), DELEGATE_PATH, "Deck 800015934 must retain the TeraNoctowl delegate"),
		assert_true(active_score >= LOCK_PIVOT_ACTION_SCORE, "The exact Noctowl retreat unlock must receive the pivot score floor (got %f)" % active_score),
		assert_true(active_score > support_score, "Seed %d must attach Active Noctowl before powering a bench support (%f vs %f)" % [REPLAY_SEED, active_score, support_score]),
	])


func test_active_fan_rotom_is_an_eligible_exact_retreat_pivot() -> String:
	var strategy := _production_strategy()
	var state := _state()
	var fan_rotom := _slot("CSV9C", "161")
	var bench_hoothoot := _slot("CSV9C", "154")
	var terapagos := _ready_terapagos()
	var energy := _basic_energy("Water Energy", "W")
	if strategy == null or fan_rotom == null or bench_hoothoot == null or terapagos == null:
		return assert_true(false, "Tord Fan Rotom pivot fixtures should load")
	state.players[0].active_pokemon = fan_rotom
	state.players[0].bench = [bench_hoothoot, terapagos]
	state.players[0].hand = [energy]

	var fan_score := _score_attachment(strategy, state, energy, fan_rotom)
	var support_score := _score_attachment(strategy, state, energy, bench_hoothoot)
	return run_checks([
		assert_true(fan_score >= LOCK_PIVOT_ACTION_SCORE, "Fan Rotom's exact one-Energy retreat unlock must receive the pivot score floor (got %f)" % fan_score),
		assert_true(fan_score > support_score, "Active Fan Rotom must be funded before a bench support when ready Terapagos can attack"),
	])


func test_partial_hoothoot_retreat_payment_does_not_receive_pivot_floor() -> String:
	var strategy := _production_strategy()
	var state := _state()
	var expensive_hoothoot := _slot("CSV9.5C", "141")
	var terapagos := _ready_terapagos()
	var energy := _basic_energy("Grass Energy", "G")
	if strategy == null or expensive_hoothoot == null or terapagos == null:
		return assert_true(false, "Tord partial-retreat fixtures should load")
	state.players[0].active_pokemon = expensive_hoothoot
	state.players[0].bench = [terapagos]
	state.players[0].hand = [energy]

	var partial_score := _score_attachment(strategy, state, energy, expensive_hoothoot)
	return assert_true(
		partial_score < LOCK_PIVOT_ACTION_SCORE,
		"One basic Energy must not boost a zero-of-two Hoothoot retreat payment (got %f)" % partial_score
	)


func test_tera_short_state_preserves_productive_direct_terapagos_attachment() -> String:
	var strategy := _production_strategy()
	var state := _state()
	var noctowl := _evolved_noctowl()
	var terapagos := _slot("CSV9C", "175")
	var energy := _basic_energy("Water Energy", "W")
	if strategy == null or noctowl == null or terapagos == null:
		return assert_true(false, "Tord Tera-short fixtures should load")
	terapagos.attached_energy = [_basic_energy("Grass Energy", "G")]
	state.players[0].active_pokemon = noctowl
	state.players[0].bench = [terapagos]
	state.players[0].hand = [energy]

	var active_score := _score_attachment(strategy, state, energy, noctowl)
	var terapagos_score := _score_attachment(strategy, state, energy, terapagos)
	return run_checks([
		assert_true(active_score < LOCK_PIVOT_ACTION_SCORE, "Active Noctowl must not receive the pivot floor while bench Terapagos still needs this attachment (got %f)" % active_score),
		assert_true(terapagos_score > active_score, "A productive direct Terapagos attachment must still beat retreat funding while Terapagos is one Energy short (%f vs %f)" % [terapagos_score, active_score]),
	])


func test_already_retreatable_active_noctowl_does_not_receive_pivot_floor() -> String:
	var strategy := _production_strategy()
	var state := _state()
	var noctowl := _evolved_noctowl()
	var terapagos := _ready_terapagos()
	var energy := _basic_energy("Water Energy", "W")
	if strategy == null or noctowl == null or terapagos == null:
		return assert_true(false, "Tord already-retreatable fixtures should load")
	noctowl.attached_energy = [_basic_energy("Grass Energy", "G")]
	state.players[0].active_pokemon = noctowl
	state.players[0].bench = [terapagos]
	state.players[0].hand = [energy]

	var redundant_score := _score_attachment(strategy, state, energy, noctowl)
	return assert_true(
		redundant_score < LOCK_PIVOT_ACTION_SCORE,
		"An Active Noctowl that can already retreat must not receive another pivot attachment boost (got %f)" % redundant_score
	)


func _score_attachment(
	strategy: RefCounted,
	state: GameState,
	energy: CardInstance,
	target: PokemonSlot
) -> float:
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


func _slot(set_code: String, card_index: String) -> PokemonSlot:
	var card := _card(set_code, card_index)
	if card == null:
		return null
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(card)
	return slot


func _evolved_noctowl() -> PokemonSlot:
	var hoothoot := _card("CSV9C", "154")
	var noctowl := _card("CSV9C", "155")
	if hoothoot == null or noctowl == null:
		return null
	var slot := PokemonSlot.new()
	slot.pokemon_stack = [hoothoot, noctowl]
	return slot


func _ready_terapagos() -> PokemonSlot:
	var terapagos := _slot("CSV9C", "175")
	if terapagos != null:
		terapagos.attached_energy = [
			_basic_energy("Grass Energy", "G"),
			_basic_energy("Water Energy", "W"),
		]
	return terapagos


func _basic_energy(card_name: String, symbol: String) -> CardInstance:
	var data := CardData.new()
	data.name = card_name
	data.name_en = card_name
	data.card_type = "Basic Energy"
	data.energy_type = symbol
	data.energy_provides = symbol
	return CardInstance.create(data, 0)


func _delegate_path(strategy: RefCounted) -> String:
	var delegate: RefCounted = strategy.get("_delegate") if strategy != null else null
	return delegate.get_script().resource_path if delegate != null else ""
