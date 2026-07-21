class_name TestV18RulesInteractionDelegateProtocol
extends TestBase


const RULES_SCRIPT = preload("res://scripts/ai/DeckStrategyV18Rules.gd")
const DECK_DIR := "res://data/bundled_user/decks"
const TORD_DECK_ID := 800015934
const CYNTHIA_DECK_ID := 800018543
const RAGING_BOLT_DECK_ID := 800018509


class ExplicitSkipDelegate:
	extends RefCounted

	func pick_interaction_items(_items: Array, _step: Dictionary, _context: Dictionary = {}) -> Variant:
		return {"handled": true, "items": []}


func test_noctowl_delegate_preserves_complementary_trainer_roles() -> String:
	var strategy := _strategy_for_deck(TORD_DECK_ID)
	var nest_ball := _card("CSVH1C", "043")
	var ultra_ball := _card("CSV1C", "112")
	var switch_card := _card("CSV1C", "113")
	if strategy == null or nest_ball == null or ultra_ball == null or switch_card == null:
		return "Tord wrapper and Noctowl Trainer candidates should load"
	var picked: Array = strategy.call("pick_interaction_items", [nest_ball, ultra_ball, switch_card], {
		"id": "csv9c_noctowl_trainers",
		"max_select": 2,
	}, {})
	return run_checks([
		assert_eq(picked.size(), 2, "Jewel Seeker should choose two complementary Trainer roles"),
		assert_true(nest_ball in picked, "The higher-value Pokemon access card should be retained"),
		assert_true(switch_card in picked, "The second choice should add a switch role"),
		assert_false(ultra_ball in picked, "The wrapper must not replace the delegate's switch choice with duplicate Pokemon access"),
	])


func test_cynthia_delegate_owns_both_crispin_interactions() -> String:
	var strategy := _strategy_for_deck(CYNTHIA_DECK_ID)
	var garchomp_data := CardDatabase.get_card("CSV10C", "113")
	if strategy == null or garchomp_data == null:
		return "Cynthia wrapper and Garchomp should load"
	var state := _make_state()
	var garchomp := _slot(garchomp_data)
	state.players[0].active_pokemon = garchomp
	var fighting := _energy("F")
	var darkness := _energy("D")
	var context := {"game_state": state, "player_index": 0}
	var hand_pick: Array = strategy.call("pick_interaction_items", [fighting, darkness], {
		"id": "csv9c196_energy_to_hand",
		"max_select": 1,
	}, context)
	var fighting_assignment := {"source": fighting, "target": garchomp}
	var darkness_assignment := {"source": darkness, "target": garchomp}
	var attachment_pick: Array = strategy.call("pick_interaction_items", [darkness_assignment, fighting_assignment], {
		"id": "csv9c196_energy_attachment",
		"max_select": 1,
	}, context)
	return run_checks([
		assert_true(hand_pick.size() == 1 and hand_pick[0] == darkness, "Cynthia should keep Darkness in hand so Fighting remains available for Garchomp"),
		assert_true(attachment_pick.size() == 1 and attachment_pick[0] == fighting_assignment, "Cynthia should delegate Crispin's assignment and attach Fighting to Garchomp"),
	])


func test_raging_bolt_keeps_wrapper_crispin_fallback_after_legacy_empty_delegate_result() -> String:
	var strategy := _strategy_for_deck(RAGING_BOLT_DECK_ID)
	var raging_bolt_data := CardDatabase.get_card("CSV7C", "154")
	if strategy == null or raging_bolt_data == null:
		return "Raging Bolt wrapper and attacker should load"
	var state := _make_state()
	state.players[0].active_pokemon = _slot(raging_bolt_data)
	var grass := _energy("G")
	var fighting := _energy("F")
	var lightning := _energy("L")
	var context := {"game_state": state, "player_index": 0}
	var hand_pick: Array = strategy.call("pick_interaction_items", [grass, fighting, lightning], {
		"id": "csv9c196_energy_to_hand",
		"max_select": 1,
	}, context)
	if hand_pick.size() != 1:
		return "Raging Bolt should still choose one Crispin Energy for hand"
	var hand_type := _energy_type(hand_pick[0])
	var attach_candidates: Array = []
	for energy: CardInstance in [grass, fighting, lightning]:
		if _energy_type(energy) != hand_type:
			attach_candidates.append(energy)
	var attachment_pick: Array = strategy.call("pick_interaction_items", attach_candidates, {
		"id": "csv9c196_energy_attachment",
		"max_select": 1,
	}, context)
	var attachment_type := _energy_type(attachment_pick[0]) if attachment_pick.size() == 1 else ""
	return run_checks([
		assert_true(hand_type in ["L", "F"], "Raging Bolt should keep one LF attack type in hand"),
		assert_true(attachment_type in ["L", "F"] and attachment_type != hand_type, "Raging Bolt should attach the other LF type through the wrapper fallback"),
	])


func test_delegate_envelope_can_explicitly_skip_with_empty_items() -> String:
	var strategy: RefCounted = RULES_SCRIPT.new()
	strategy.set("_delegate", ExplicitSkipDelegate.new())
	var fallback_candidate := _card("CSVH1C", "043")
	if fallback_candidate == null:
		return "Explicit-skip fallback candidate should load"
	var picked: Array = strategy.call("pick_interaction_items", [fallback_candidate], {
		"id": "csv9c_noctowl_trainers",
		"max_select": 1,
	}, {})
	return assert_true(picked.is_empty(), "A handled delegate envelope with empty items must suppress wrapper and base fallbacks")


func test_production_noctowl_delegate_can_explicitly_skip_dead_trainer_targets() -> String:
	var strategy := _strategy_for_deck(TORD_DECK_ID)
	var state := _make_state()
	var player := state.players[0]
	var terapagos_data := CardDatabase.get_card("CSV9C", "175")
	var rotom_data := CardDatabase.get_card("CSV9C", "161")
	var area_zero := _card("CSV9C", "207")
	var nest_ball := _card("CSVH1C", "043")
	if strategy == null or terapagos_data == null or rotom_data == null or area_zero == null or nest_ball == null:
		return "Production Noctowl wrapper state should load"
	player.active_pokemon = _slot(terapagos_data)
	for _index: int in 8:
		player.bench.append(_slot(rotom_data))
	player.deck = []
	state.stadium_card = area_zero
	var picked: Array = strategy.call("pick_interaction_items", [area_zero, nest_ball], {
		"id": "csv9c_noctowl_trainers",
		"max_select": 2,
	}, {"game_state": state, "player_index": 0})
	return assert_true(
		picked.is_empty(),
		"The production Noctowl delegate must be able to choose zero when Area Zero is already active and Nest Ball has no legal target"
	)


func _strategy_for_deck(deck_id: int) -> RefCounted:
	var deck := _load_deck(deck_id)
	if deck == null:
		return null
	var strategy: RefCounted = RULES_SCRIPT.new()
	strategy.call("configure_from_deck", deck)
	return strategy


func _load_deck(deck_id: int) -> DeckData:
	var path := "%s/%d.json" % [DECK_DIR, deck_id]
	if not FileAccess.file_exists(path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return DeckData.from_dict(parsed) if parsed is Dictionary else null


func _make_state() -> GameState:
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


func _card(set_code: String, card_index: String) -> CardInstance:
	var data := CardDatabase.get_card(set_code, card_index)
	return CardInstance.create(data, 0) if data != null else null


func _slot(data: CardData) -> PokemonSlot:
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(data, 0))
	return slot


func _energy(symbol: String) -> CardInstance:
	var data := CardData.new()
	data.name = "%s Energy" % symbol
	data.name_en = data.name
	data.card_type = "Basic Energy"
	data.energy_type = symbol
	data.energy_provides = symbol
	return CardInstance.create(data, 0)


func _energy_type(card: CardInstance) -> String:
	return str(card.card_data.energy_provides) if card != null and card.card_data != null else ""
