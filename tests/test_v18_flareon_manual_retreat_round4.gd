class_name TestV18FlareonManualRetreatRound4
extends TestBase


const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")

const DECK_ID := 800017643
const REPLAY_SEED := 15300
const DECK_PATH := "res://data/bundled_user/decks/800017643.json"
const RULES_PATH := "res://scripts/ai/DeckStrategyV18Rules.gd"
const DELEGATE_PATH := "res://scripts/ai/DeckStrategyV18TeraNoctowl.gd"


func test_seed15300_registry_retreat_ranks_concrete_flareon_handoff_target() -> String:
	var strategy := _production_strategy()
	var active := _slot("CSV9C", "161")
	var flareon := _slot("CSV9.5C", "023")
	var sylveon := _slot("CSV9C", "090")
	var noctowl := _slot("CSV9C", "155")
	if strategy == null or active == null or flareon == null or sylveon == null or noctowl == null:
		return assert_true(false, "Seed %d manual-retreat fixtures should load" % REPLAY_SEED)
	active.attached_energy = [_energy("C")]
	_fund_flareon(flareon)
	sylveon.attached_energy = [_energy("P"), _energy("C"), _energy("C")]
	var state := _state()
	state.players[0].active_pokemon = active
	state.players[0].bench = [noctowl, sylveon, flareon]
	state.players[1].active_pokemon = _dummy_slot("High-HP defender", 400, 1)

	var flareon_score := _score_retreat(strategy, state, flareon)
	var sylveon_score := _score_retreat(strategy, state, sylveon)
	var noctowl_score := _score_retreat(strategy, state, noctowl)
	return run_checks([
		assert_eq(strategy.get_script().resource_path, RULES_PATH, "Seed replay must score through the production V18Rules wrapper"),
		assert_eq(_delegate_path(strategy), DELEGATE_PATH, "Deck 800017643 must retain the TeraNoctowl delegate"),
		assert_true(flareon_score >= sylveon_score + 3000.0, "Full-RWL Flareon must dominate the lower-damage executable target (%f vs %f)" % [flareon_score, sylveon_score]),
		assert_true(sylveon_score >= noctowl_score + 3000.0, "An executable higher-damage target must beat support in the concrete retreat action (%f vs %f)" % [sylveon_score, noctowl_score]),
	])


func test_carnelian_lock_retreat_ranking_tracks_lifecycle_and_reentry() -> String:
	var strategy := _production_strategy()
	var active := _slot("CSV9.5C", "023")
	var backup_flareon := _slot("CSV9.5C", "023")
	var sylveon := _slot("CSV9C", "090")
	if strategy == null or active == null or backup_flareon == null or sylveon == null:
		return assert_true(false, "Carnelian lock lifecycle fixtures should load")
	_fund_flareon(active)
	_fund_flareon(backup_flareon)
	sylveon.attached_energy = [_energy("P"), _energy("C"), _energy("C")]
	_lock_from_turn(active, 3)
	var state := _state()
	state.players[0].active_pokemon = active
	state.players[0].bench = [sylveon, backup_flareon]
	state.players[1].active_pokemon = _dummy_slot("High-HP defender", 400, 1)

	var locked_flareon_score := _score_retreat(strategy, state, backup_flareon)
	var locked_sylveon_score := _score_retreat(strategy, state, sylveon)
	state.current_player_index = 1
	var opponent_turn_score := _score_retreat(strategy, state, backup_flareon)
	state.turn_number = 7
	state.current_player_index = 0
	var expired_score := _score_retreat(strategy, state, backup_flareon)
	_lock_from_turn(active, 5)
	var reentry_flareon_score := _score_retreat(strategy, state, backup_flareon)
	var reentry_sylveon_score := _score_retreat(strategy, state, sylveon)
	return run_checks([
		assert_true(locked_flareon_score >= locked_sylveon_score + 3000.0, "Current-own-turn lock pivot must rank the full-RWL backup above Sylveon"),
		assert_true(opponent_turn_score < locked_flareon_score - 3000.0, "The Carnelian marker must not create a retreat window during the opponent turn"),
		assert_true(expired_score < locked_flareon_score - 3000.0, "An expired Carnelian marker must not keep the pivot window live"),
		assert_true(reentry_flareon_score >= reentry_sylveon_score + 3000.0, "A later Carnelian lock must re-enter the same target-aware pivot policy"),
		assert_true(reentry_flareon_score >= expired_score + 3000.0, "Lock re-entry must restore the executable retreat route"),
	])


func test_manual_retreat_stays_active_for_ko_full_rwl_and_non_improving_targets() -> String:
	var strategy := _production_strategy()
	var active_rotom := _slot("CSV9C", "161")
	var target_flareon := _slot("CSV9.5C", "023")
	if strategy == null or active_rotom == null or target_flareon == null:
		return assert_true(false, "Manual-retreat negative guard fixtures should load")
	active_rotom.attached_energy = [_energy("C")]
	_fund_flareon(target_flareon)
	var ko_state := _state()
	ko_state.players[0].active_pokemon = active_rotom
	ko_state.players[0].bench = [target_flareon]
	ko_state.players[1].active_pokemon = _dummy_slot("KO defender", 60, 1)
	var projected_ko_score := _score_retreat(strategy, ko_state, target_flareon)
	var projected_ko_end := _score_end_turn(strategy, ko_state)

	var active_flareon := _slot("CSV9.5C", "023")
	var backup_flareon := _slot("CSV9.5C", "023")
	if active_flareon == null or backup_flareon == null:
		return assert_true(false, "Full-RWL Active guard fixtures should load")
	_fund_flareon(active_flareon)
	_fund_flareon(backup_flareon)
	var full_rwl_state := _state()
	full_rwl_state.players[0].active_pokemon = active_flareon
	full_rwl_state.players[0].bench = [backup_flareon]
	full_rwl_state.players[1].active_pokemon = _dummy_slot("High-HP defender", 400, 1)
	var full_rwl_retreat := _score_retreat(strategy, full_rwl_state, backup_flareon)
	var full_rwl_end := _score_end_turn(strategy, full_rwl_state)

	var active_sylveon := _slot("CSV9C", "090")
	var weaker_wellspring := _slot("CSV8C", "067")
	if active_sylveon == null or weaker_wellspring == null:
		return assert_true(false, "Non-improving retreat fixtures should load")
	active_sylveon.attached_energy = [_energy("P"), _energy("C"), _energy("C")]
	weaker_wellspring.attached_energy = [_energy("W"), _energy("C"), _energy("C")]
	var non_improving_state := _state()
	non_improving_state.players[0].active_pokemon = active_sylveon
	non_improving_state.players[0].bench = [weaker_wellspring]
	non_improving_state.players[1].active_pokemon = _dummy_slot("High-HP defender", 400, 1)
	var non_improving_retreat := _score_retreat(strategy, non_improving_state, weaker_wellspring)
	var non_improving_end := _score_end_turn(strategy, non_improving_state)
	return run_checks([
		assert_true(projected_ko_score < projected_ko_end, "An Active projected KO must beat retreating to full-RWL Flareon"),
		assert_true(full_rwl_retreat < full_rwl_end, "An unlocked full-RWL Active Flareon must stay Active"),
		assert_true(non_improving_retreat < non_improving_end, "Retreat must be rejected when target executable damage does not exceed Active damage"),
	])


func _score_retreat(strategy: RefCounted, state: GameState, target: PokemonSlot) -> float:
	var plan: Dictionary = strategy.call("build_turn_contract", state, 0, {
		"prompt_kind": "action_selection",
		"replay_seed": REPLAY_SEED,
	})
	return float(strategy.call("score_action_absolute_with_plan", {
		"kind": "retreat",
		"bench_target": target,
		"energy_to_discard": [],
	}, state, 0, plan))


func _score_end_turn(strategy: RefCounted, state: GameState) -> float:
	var plan: Dictionary = strategy.call("build_turn_contract", state, 0, {
		"prompt_kind": "action_selection",
		"replay_seed": REPLAY_SEED,
	})
	return float(strategy.call("score_action_absolute_with_plan", {"kind": "end_turn"}, state, 0, plan))


func _production_strategy() -> RefCounted:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DECK_PATH))
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


func _slot(set_code: String, card_index: String) -> PokemonSlot:
	var data := CardDatabase.get_card(set_code, card_index)
	if data == null:
		return null
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(data, 0))
	return slot


func _dummy_slot(card_name: String, hp: int, owner_index: int) -> PokemonSlot:
	var data := CardData.new()
	data.name = card_name
	data.name_en = card_name
	data.card_type = "Pokemon"
	data.stage = "Basic"
	data.hp = hp
	data.attacks = [{"cost": "", "damage": "0"}]
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(data, owner_index))
	return slot


func _fund_flareon(slot: PokemonSlot) -> void:
	slot.attached_energy = [_energy("R"), _energy("W"), _energy("L")]


func _energy(symbol: String) -> CardInstance:
	var data := CardData.new()
	data.name = "%s Energy" % symbol
	data.name_en = data.name
	data.card_type = "Basic Energy"
	data.energy_provides = symbol
	return CardInstance.create(data, 0)


func _lock_from_turn(slot: PokemonSlot, turn_number: int) -> void:
	slot.effects.append({
		"type": "attack_lock_all",
		"source_attack_index": 1,
		"turn": turn_number,
	})


func _delegate_path(strategy: RefCounted) -> String:
	var delegate: RefCounted = strategy.get("_delegate") if strategy != null else null
	return delegate.get_script().resource_path if delegate != null else ""
