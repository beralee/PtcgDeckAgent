class_name TestV18FiveDeckRound1Strategy
extends TestBase


const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")


func test_marnie_tm_evolution_energy_stays_on_the_active_carrier() -> String:
	var strategy := _delegate_for_deck(800018501)
	if strategy == null:
		return assert_true(false, "Marnie's Grimmsnarl delegate should resolve")
	var state := _state(2)
	var player: PlayerState = state.players[0]
	var carrier := _slot(_real_card("CSV9.5C_043", 0))
	var impidimp := _slot(_real_card("CSV10C_146", 0))
	var tm := _real_card("CSV5C_119", 0)
	var darkness := _real_card("CSVE1C_DAR", 0)
	carrier.attached_tool = tm
	player.active_pokemon = carrier
	player.bench = [impidimp]
	player.hand = [darkness]
	player.deck = [
		_real_card("CSV10C_147", 0),
		_real_card("CSV7C_059", 0),
	]
	var carrier_score := float(strategy.call("score_action_absolute", {
		"kind": "attach_energy", "card": darkness, "target_slot": carrier,
	}, state, 0))
	var bench_score := float(strategy.call("score_action_absolute", {
		"kind": "attach_energy", "card": darkness, "target_slot": impidimp,
	}, state, 0))
	return run_checks([
		assert_true(carrier_score >= 5600.0, "A live TM Evolution carrier should receive the Darkness Energy floor"),
		assert_true(carrier_score >= bench_score + 7000.0, "The current-window TM attack must outrank future Impidimp setup"),
	])


func test_no_balloon_gardevoir_iono_prevents_next_draw_deck_out() -> String:
	var strategy := _delegate_for_deck(800017097)
	if strategy == null:
		return assert_true(false, "No-balloon Gardevoir delegate should resolve")
	var state := _state(42)
	var player: PlayerState = state.players[0]
	var drifloon := _slot(_real_card("CSV2C_060", 0))
	_attach_basic_energy(drifloon, "P")
	_attach_basic_energy(drifloon, "P")
	player.active_pokemon = drifloon
	player.deck = [_filler_card("Last deck card", 0)]
	player.prizes = [_filler_card("Prize 1", 0), _filler_card("Prize 2", 0), _filler_card("Prize 3", 0)]
	var iono := _real_card("CSV3C_123", 0)
	player.hand = [
		iono,
		_filler_card("Survival card 1", 0),
		_filler_card("Survival card 2", 0),
		_filler_card("Survival card 3", 0),
	]
	var survival_score := float(strategy.call("score_action_absolute", {
		"kind": "play_trainer", "card": iono,
	}, state, 0))
	player.deck.append(_filler_card("Second deck card", 0))
	player.deck.append(_filler_card("Third deck card", 0))
	player.deck.append(_filler_card("Fourth deck card", 0))
	var ordinary_score := float(strategy.call("score_action_absolute", {
		"kind": "play_trainer", "card": iono,
	}, state, 0))
	return run_checks([
		assert_true(survival_score >= 2400.0, "Iono should refill a one-card deck before the next mandatory draw"),
		assert_true(survival_score >= ordinary_score + 2000.0, "The emergency score must disappear when deck-out is not immediate"),
	])


func test_pure_dragapult_brocks_scouting_selects_the_missing_evolution_mode() -> String:
	var strategy := _delegate_for_deck(800018499)
	if strategy == null:
		return assert_true(false, "Pure Dragapult delegate should resolve")
	var state := _state(25)
	var player: PlayerState = state.players[0]
	player.active_pokemon = _slot(_real_card("CSV9.5C_004", 0))
	player.bench = [_slot(_real_card("CSV8C_157", 0))]
	var drakloak := _real_card("CSV8C_158", 0)
	var dragapult := _real_card("CSV8C_159", 0)
	player.deck = [drakloak, dragapult, _real_card("CSV8C_094", 0)]
	var context := {"game_state": state, "player_index": 0}
	var mode_step := {"id": "brocks_scouting_mode", "min_select": 1, "max_select": 1}
	var first_modes: Array = strategy.call("pick_interaction_items", ["basic", "evolution"], mode_step, context)
	var reordered_modes: Array = strategy.call("pick_interaction_items", ["evolution", "basic"], mode_step, context)
	var evolution_step := {"id": "brocks_scouting_evolution", "min_select": 0, "max_select": 1}
	var first_cards: Array = strategy.call("pick_interaction_items", [dragapult, drakloak], evolution_step, context)
	var reordered_cards: Array = strategy.call("pick_interaction_items", [drakloak, dragapult], evolution_step, context)
	return run_checks([
		assert_eq(first_modes, ["evolution"], "Brock should choose Evolution when Dreepy is waiting"),
		assert_eq(reordered_modes, ["evolution"], "Brock's semantic mode must survive option reordering"),
		assert_eq(first_cards, [drakloak], "The live Dreepy lane should search Drakloak before an unplayable Stage 2"),
		assert_eq(reordered_cards, [drakloak], "Brock's Evolution target must survive option reordering"),
	])


func test_raging_bolt_emergency_search_and_bench_prioritize_latias() -> String:
	var strategy := _delegate_for_deck(800018509)
	if strategy == null:
		return assert_true(false, "Raging Bolt delegate should resolve")
	var state := _state(6)
	var player: PlayerState = state.players[0]
	player.active_pokemon = _slot(_real_card("CSV9C_154", 0))
	var bolt := _slot(_real_card("CSV7C_154", 0))
	_attach_basic_energy(bolt, "L")
	_attach_basic_energy(bolt, "F")
	player.bench = [bolt]
	var latias := _real_card("CSV9C_078", 0)
	var mew := _real_card("151C_151", 0)
	var context := {"game_state": state, "player_index": 0, "all_items": [mew, latias]}
	var step := {"id": "search_pokemon", "min_select": 0, "max_select": 1}
	var latias_search := float(strategy.call("score_interaction_target", latias, step, context))
	var mew_search := float(strategy.call("score_interaction_target", mew, step, context))
	var latias_bench := float(strategy.call("score_action_absolute", {
		"kind": "play_basic_to_bench", "card": latias,
	}, state, 0))
	var mew_bench := float(strategy.call("score_action_absolute", {
		"kind": "play_basic_to_bench", "card": mew,
	}, state, 0))
	return run_checks([
		assert_true(latias_search >= mew_search + 800.0, "A stuck Basic Active should search Latias before generic support"),
		assert_true(latias_bench >= mew_bench + 800.0, "A held Latias should be benched to unlock the current retreat window"),
	])


func test_ns_zoroark_n_castle_unlocks_a_ready_benched_n_attacker() -> String:
	var strategy := _delegate_for_deck(800018502)
	if strategy == null:
		return assert_true(false, "N's Zoroark delegate should resolve")
	var state := _state(16)
	var player: PlayerState = state.players[0]
	var zoroark := _slot(_real_card("CSV10C_145", 0))
	_attach_basic_energy(zoroark, "D")
	var reshiram := _slot(_real_card("CSV10C_166", 0))
	_attach_basic_energy(reshiram, "D")
	_attach_basic_energy(reshiram, "D")
	player.active_pokemon = zoroark
	player.bench = [reshiram]
	var n_castle := _real_card("CSV10C_215", 0)
	var artazon := _real_card("CSV2C_127", 0)
	var context := {"game_state": state, "player_index": 0, "all_items": [artazon, n_castle]}
	var search_step := {"id": "search_stadium", "min_select": 0, "max_select": 1}
	var n_castle_search := float(strategy.call("score_interaction_target", n_castle, search_step, context))
	var artazon_search := float(strategy.call("score_interaction_target", artazon, search_step, context))
	var n_castle_play := float(strategy.call("score_action_absolute", {
		"kind": "play_stadium", "card": n_castle,
	}, state, 0))
	var artazon_play := float(strategy.call("score_action_absolute", {
		"kind": "play_stadium", "card": artazon,
	}, state, 0))
	return run_checks([
		assert_true(n_castle_search >= artazon_search + 800.0, "Secret Box should find N's Castle for the ready Reshiram handoff"),
		assert_true(n_castle_play >= artazon_play + 800.0, "N's Castle should be played before generic stadium setup"),
	])


func _delegate_for_deck(deck_id: int) -> RefCounted:
	var payload: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/bundled_user/decks/%d.json" % deck_id
	))
	if not payload is Dictionary:
		return null
	var wrapper: RefCounted = REGISTRY_SCRIPT.new().resolve_strategy_for_deck(DeckData.from_dict(payload))
	if wrapper == null:
		return null
	var delegate: Variant = wrapper.get("_delegate")
	return delegate as RefCounted if delegate is RefCounted else wrapper


func _state(turn_number: int) -> GameState:
	var state := GameState.new()
	state.turn_number = turn_number
	state.current_player_index = 0
	state.first_player_index = 1
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	state.players[1].active_pokemon = _slot(_filler_card("Opponent Active", 1))
	return state


func _real_card(uid: String, owner_index: int) -> CardInstance:
	var parts := uid.rsplit("_", true, 1)
	var data: CardData = CardDatabase.get_card(parts[0], parts[1]) if parts.size() == 2 else null
	return CardInstance.create(data, owner_index) if data != null else null


func _filler_card(card_name: String, owner_index: int) -> CardInstance:
	var data := CardData.new()
	data.name = card_name
	data.name_en = card_name
	data.card_type = "Pokemon"
	data.stage = "Basic"
	data.hp = 120
	data.attacks = [{"name": "Test attack", "cost": "C", "damage": "10"}]
	return CardInstance.create(data, owner_index)


func _slot(card: CardInstance) -> PokemonSlot:
	var slot := PokemonSlot.new()
	if card != null:
		slot.pokemon_stack.append(card)
	return slot


func _attach_basic_energy(slot: PokemonSlot, energy_type: String) -> void:
	var data := CardData.new()
	data.name = "%s Energy" % energy_type
	data.name_en = "%s Energy" % energy_type
	data.card_type = "Basic Energy"
	data.energy_provides = energy_type
	slot.attached_energy.append(CardInstance.create(data, 0))
