class_name TestV18Stage2BoilingSpiritRound6
extends TestBase


const DECK_PATH := "res://data/bundled_user/decks/800017047.json"
const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const STEP := {"id": "attach_basic_energy_from_discard"}
const FALLBACK_STEP := {"id": "energy_target"}


func test_fighting_boiling_spirit_prefers_unready_mamoswine_through_production_wrapper() -> String:
	var strategy := _load_strategy()
	var mamoswine: CardData = CardDatabase.get_card("CSV10C", "104")
	var blaziken: CardData = CardDatabase.get_card("CSV7C", "038")
	var fighting: CardData = CardDatabase.get_card("CSVE1C", "FIG")
	var checks := _load_checks(strategy, mamoswine, blaziken, fighting)
	if strategy == null or mamoswine == null or blaziken == null or fighting == null:
		return run_checks(checks)

	var state := _make_state()
	var mamoswine_slot := _make_slot(mamoswine)
	mamoswine_slot.attached_energy.append(CardInstance.create(fighting, 0))
	var blaziken_slot := _make_slot(blaziken)
	state.players[0].active_pokemon = mamoswine_slot
	state.players[0].bench.append(blaziken_slot)
	var context := _context(state, CardInstance.create(fighting, 0))
	var mamoswine_score := float(strategy.call("score_interaction_target", mamoswine_slot, STEP, context))
	var blaziken_score := float(strategy.call("score_interaction_target", blaziken_slot, STEP, context))
	var fallback_score := float(strategy.call("score_interaction_target", mamoswine_slot, FALLBACK_STEP, context))
	checks.append_array([
		assert_true(
			mamoswine_score > blaziken_score,
			"Fighting from Boiling Spirit should prefer Mamoswine while its FF cost is incomplete (mamoswine=%f blaziken=%f)" % [mamoswine_score, blaziken_score]
		),
		assert_true(mamoswine_score > fallback_score, "The Fighting preference must come from the source-aware Boiling Spirit route"),
	])
	return run_checks(checks)


func test_fire_boiling_spirit_prefers_blaziken_and_forbids_mamoswine_through_production_wrapper() -> String:
	var strategy := _load_strategy()
	var mamoswine: CardData = CardDatabase.get_card("CSV10C", "104")
	var blaziken: CardData = CardDatabase.get_card("CSV7C", "038")
	var fighting: CardData = CardDatabase.get_card("CSVE1C", "FIG")
	var fire: CardData = CardDatabase.get_card("CSVE1C", "FIR")
	var checks := _load_checks(strategy, mamoswine, blaziken, fire)
	checks.append(assert_not_null(fighting, "Fighting Energy should load"))
	if strategy == null or mamoswine == null or blaziken == null or fighting == null or fire == null:
		return run_checks(checks)

	var state := _make_state()
	var mamoswine_slot := _make_slot(mamoswine)
	mamoswine_slot.attached_energy.append(CardInstance.create(fighting, 0))
	var blaziken_slot := _make_slot(blaziken)
	state.players[0].active_pokemon = mamoswine_slot
	state.players[0].bench.append(blaziken_slot)
	var context := _context(state, CardInstance.create(fire, 0))
	var mamoswine_score := float(strategy.call("score_interaction_target", mamoswine_slot, STEP, context))
	var blaziken_score := float(strategy.call("score_interaction_target", blaziken_slot, STEP, context))
	checks.append_array([
		assert_true(blaziken_score > mamoswine_score, "Fire from Boiling Spirit should prefer Blaziken"),
		assert_true(is_inf(mamoswine_score) and mamoswine_score < 0.0, "Fire from Boiling Spirit must forbid Mamoswine while setup debt remains"),
	])
	return run_checks(checks)


func test_boiling_spirit_debt_zero_and_missing_source_fall_back_to_existing_scoring() -> String:
	var strategy := _load_strategy()
	var mamoswine: CardData = CardDatabase.get_card("CSV10C", "104")
	var blaziken: CardData = CardDatabase.get_card("CSV7C", "038")
	var fighting: CardData = CardDatabase.get_card("CSVE1C", "FIG")
	var checks := _load_checks(strategy, mamoswine, blaziken, fighting)
	if strategy == null or mamoswine == null or blaziken == null or fighting == null:
		return run_checks(checks)

	var missing_source_state := _make_state()
	var debt_mamoswine := _make_slot(mamoswine)
	debt_mamoswine.attached_energy.append(CardInstance.create(fighting, 0))
	var debt_blaziken := _make_slot(blaziken)
	missing_source_state.players[0].active_pokemon = debt_mamoswine
	missing_source_state.players[0].bench.append(debt_blaziken)
	var missing_source_context := _context(missing_source_state, null)
	var missing_source_mamoswine := float(strategy.call("score_interaction_target", debt_mamoswine, STEP, missing_source_context))
	var missing_source_blaziken := float(strategy.call("score_interaction_target", debt_blaziken, STEP, missing_source_context))
	var fallback_missing_source_mamoswine := float(strategy.call("score_interaction_target", debt_mamoswine, FALLBACK_STEP, missing_source_context))
	var fallback_missing_source_blaziken := float(strategy.call("score_interaction_target", debt_blaziken, FALLBACK_STEP, missing_source_context))

	var debt_zero_state := _make_state()
	var ready_mamoswine := _make_slot(mamoswine)
	ready_mamoswine.attached_energy.append(CardInstance.create(fighting, 0))
	ready_mamoswine.attached_energy.append(CardInstance.create(fighting, 0))
	var ready_blaziken := _make_slot(blaziken)
	debt_zero_state.players[0].active_pokemon = ready_mamoswine
	debt_zero_state.players[0].bench.append(ready_blaziken)
	var debt_zero_context := _context(debt_zero_state, CardInstance.create(fighting, 0))
	var debt_zero_mamoswine := float(strategy.call("score_interaction_target", ready_mamoswine, STEP, debt_zero_context))
	var debt_zero_blaziken := float(strategy.call("score_interaction_target", ready_blaziken, STEP, debt_zero_context))
	var fallback_debt_zero_mamoswine := float(strategy.call("score_interaction_target", ready_mamoswine, FALLBACK_STEP, debt_zero_context))
	var fallback_debt_zero_blaziken := float(strategy.call("score_interaction_target", ready_blaziken, FALLBACK_STEP, debt_zero_context))
	checks.append_array([
		assert_eq(missing_source_mamoswine, fallback_missing_source_mamoswine, "Missing source_card should preserve Mamoswine's existing target score"),
		assert_eq(missing_source_blaziken, fallback_missing_source_blaziken, "Missing source_card should preserve Blaziken's existing target score"),
		assert_eq(debt_zero_mamoswine, fallback_debt_zero_mamoswine, "Zero setup debt should preserve Mamoswine's existing target score"),
		assert_eq(debt_zero_blaziken, fallback_debt_zero_blaziken, "Zero setup debt should preserve Blaziken's existing target score"),
	])
	return run_checks(checks)


func _load_strategy() -> RefCounted:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DECK_PATH))
	var deck := DeckData.from_dict(parsed) if parsed is Dictionary else null
	var registry: RefCounted = REGISTRY_SCRIPT.new()
	return registry.call("resolve_strategy_for_deck", deck) if deck != null else null


func _load_checks(strategy: RefCounted, mamoswine: CardData, blaziken: CardData, energy: CardData) -> Array[String]:
	var delegate: RefCounted = strategy.get("_delegate") if strategy != null else null
	return [
		assert_not_null(strategy, "Deck 800017047 should resolve through the production V18 registry"),
		assert_not_null(delegate, "Deck 800017047 should retain a production Stage2Core delegate"),
		assert_eq(str(delegate.call("get_strategy_id")) if delegate != null else "", "v18_stage2_core_800017047", "The production wrapper should retain the deck-scoped Stage2Core delegate"),
		assert_not_null(mamoswine, "Mamoswine ex should load"),
		assert_not_null(blaziken, "Blaziken ex should load"),
		assert_not_null(energy, "The source Energy should load"),
	]


func _context(state: GameState, source_card: CardInstance) -> Dictionary:
	var context := {"game_state": state, "player_index": 0}
	if source_card != null:
		context["source_card"] = source_card
	return context


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
