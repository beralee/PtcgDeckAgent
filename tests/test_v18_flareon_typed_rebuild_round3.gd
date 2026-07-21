class_name TestV18FlareonTypedRebuildRound3
extends TestBase


const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const FLAREON_DECK_ID := 800017643
const TORD_DECK_ID := 800015934
const DECK_DIR := "res://data/bundled_user/decks"
const CRISPIN_HAND_STEP := "csv9c196_energy_to_hand"
const CRISPIN_ATTACH_STEP := "csv9c196_energy_attachment"


func test_registry_keeps_area_zero_and_crispin_as_flareon_noctowl_bridge() -> String:
	var strategy := _registry_strategy(FLAREON_DECK_ID)
	var delegate := _delegate_of(strategy)
	var area_zero := _card("CSV9C", "207")
	var crispin := _card("CSV9C", "196")
	var switch_card := _card("CSV1C", "113")
	if strategy == null or delegate == null or area_zero == null or crispin == null or switch_card == null:
		return assert_true(false, "Registry Flareon bridge fixtures should load")
	var picks: Array = strategy.call("pick_interaction_items", [switch_card, crispin, area_zero], {
		"id": "csv9c_noctowl_trainers",
		"max_select": 2,
	}, {})
	return run_checks([
		assert_true(str(strategy.call("get_strategy_id")).contains("flareon_noctowl"), "Registry must keep the exact Flareon V18 profile"),
		assert_eq(str(delegate.call("get_strategy_id")), "v18_tera_noctowl_core", "Registry must keep the TeraNoctowl delegate"),
		assert_true(area_zero in picks and crispin in picks, "Noctowl must still bridge through Area Zero plus Crispin"),
	])


func test_registry_crispin_pairs_water_and_lightning_for_the_rwl_gap() -> String:
	var strategy := _registry_strategy(FLAREON_DECK_ID)
	var delegate := _delegate_of(strategy)
	var flareon := _slot("CSV9.5C", "023")
	var wellspring := _slot("CSV8C", "067")
	var noctowl := _slot("CSV9C", "155")
	if strategy == null or delegate == null or flareon == null or wellspring == null or noctowl == null:
		return assert_true(false, "Crispin typed rebuild fixtures should load")
	flareon.attached_energy = [_energy("R")]
	wellspring.attached_energy = [_energy("W")]
	var state := _state()
	state.players[0].active_pokemon = flareon
	state.players[0].bench = [wellspring, noctowl]
	var fire := _energy("R")
	var water := _energy("W")
	var lightning := _energy("L")
	var psychic := _energy("P")
	var grass := _energy("G")
	state.players[0].deck = [fire, lightning, water, psychic, grass]
	var context := {"game_state": state, "player_index": 0}
	var hand_pick: Array = strategy.call("pick_interaction_items", state.players[0].deck, {
		"id": CRISPIN_HAND_STEP,
		"max_select": 1,
	}, context)
	var attachment_candidates: Array = [fire, water, lightning, psychic, grass]
	var attach_pick: Array = strategy.call("pick_interaction_items", attachment_candidates, {
		"id": CRISPIN_ATTACH_STEP,
		"max_select": 1,
	}, context.merged({
		"target_items": [flareon, wellspring, noctowl],
		CRISPIN_HAND_STEP: [water],
	}))
	var target_context := context.merged({"source_card": lightning})
	var flareon_score: float = strategy.call("score_interaction_target", flareon, {"id": CRISPIN_ATTACH_STEP}, target_context)
	var wellspring_score: float = strategy.call("score_interaction_target", wellspring, {"id": CRISPIN_ATTACH_STEP}, target_context)
	var noctowl_score: float = strategy.call("score_interaction_target", noctowl, {"id": CRISPIN_ATTACH_STEP}, target_context)
	return run_checks([
		assert_eq(hand_pick, [water], "Crispin should put Water into hand when R leaves a W/L pair"),
		assert_eq(attach_pick, [lightning], "Crispin should attach the distinct Lightning half of the W/L pair"),
		assert_false(psychic in hand_pick or psychic in attach_pick, "Crispin must reject Psychic while W/L is available"),
		assert_false(grass in hand_pick or grass in attach_pick, "Crispin must reject Grass while W/L is available"),
		assert_true(flareon_score >= wellspring_score + 3000.0, "Typed Crispin target scoring must reject Wellspring support"),
		assert_true(flareon_score >= noctowl_score + 3000.0, "Typed Crispin target scoring must reject Noctowl support"),
	])


func test_crispin_accepts_only_flareon_or_an_eevee_with_a_live_flareon_evolution() -> String:
	var strategy := _registry_strategy(FLAREON_DECK_ID)
	var delegate := _delegate_of(strategy)
	var eevee := _slot("CSV9C", "153")
	var eevee_ex := _slot("CSV9.5C", "140")
	var noctowl := _slot("CSV9C", "155")
	var flareon_card := _card("CSV9.5C", "023")
	if delegate == null or eevee == null or eevee_ex == null or noctowl == null or flareon_card == null:
		return assert_true(false, "Crispin Eevee target fixtures should load")
	var state := _state()
	state.players[0].active_pokemon = noctowl
	state.players[0].bench = [eevee, eevee_ex]
	state.players[0].hand = [flareon_card]
	var context := {"game_state": state, "player_index": 0, "source_card": _energy("R")}
	var eevee_score: float = delegate.call("score_interaction_target", eevee, {"id": CRISPIN_ATTACH_STEP}, context)
	var eevee_ex_score: float = delegate.call("score_interaction_target", eevee_ex, {"id": CRISPIN_ATTACH_STEP}, context)
	var noctowl_score: float = delegate.call("score_interaction_target", noctowl, {"id": CRISPIN_ATTACH_STEP}, context)
	return run_checks([
		assert_true(eevee_score > 0.0, "A real Eevee with Flareon in hand should be a typed rebuild target"),
		assert_true(eevee_score >= eevee_ex_score + 3000.0, "Eevee ex must be rejected when Flareon cannot evolve from it"),
		assert_true(eevee_score >= noctowl_score + 3000.0, "Support Pokemon must not receive the typed rebuild attachment"),
	])


func test_attack_debt_moves_until_an_unlocked_flareon_satisfies_rwl() -> String:
	var strategy := _registry_strategy(FLAREON_DECK_ID)
	var delegate := _delegate_of(strategy)
	var rc_flareon := _slot("CSV9.5C", "023")
	var locked_flareon := _slot("CSV9.5C", "023")
	var wellspring := _slot("CSV8C", "067")
	if delegate == null or rc_flareon == null or locked_flareon == null or wellspring == null:
		return assert_true(false, "Flareon attack-debt fixtures should load")
	rc_flareon.attached_energy = [_energy("R"), _energy("C")]
	locked_flareon.attached_energy = [_energy("R"), _energy("W"), _energy("L")]
	wellspring.attached_energy = [_energy("W")]
	_lock_from_turn(locked_flareon, 3)
	var state := _state()
	state.players[0].active_pokemon = locked_flareon
	state.players[0].bench = [rc_flareon, wellspring]
	var locked_debt: bool = delegate.call("_flareon_attack_debt", state.players[0], state)
	var water := _energy("W")
	var lightning := _energy("L")
	state.players[0].deck = [water, lightning]
	var rebuild_pick: Array = strategy.call("pick_interaction_items", [water, lightning], {
		"id": CRISPIN_HAND_STEP,
		"max_select": 1,
	}, {"game_state": state, "player_index": 0})
	rc_flareon.attached_energy = [_energy("R"), _energy("W"), _energy("L")]
	var transferred_debt: bool = delegate.call("_flareon_attack_debt", state.players[0], state)
	return run_checks([
		assert_true(locked_debt, "A locked RWL Flareon, RC-only Flareon, and ready Wellspring must leave attack debt live"),
		assert_true(rebuild_pick.size() == 1 and rebuild_pick[0] in [water, lightning], "Crispin debt should transfer to the unlocked RC-only Flareon"),
		assert_false(transferred_debt, "Only the unlocked Flareon that now satisfies RWL may clear attack debt"),
	])


func test_non_locked_switch_targets_reuse_handoff_and_prefer_full_rwl_flareon() -> String:
	var strategy := _registry_strategy(FLAREON_DECK_ID)
	var flareon := _slot("CSV9.5C", "023")
	var wellspring := _slot("CSV8C", "067")
	if strategy == null or flareon == null or wellspring == null:
		return assert_true(false, "Non-locked handoff fixtures should load")
	flareon.attached_energy = [_energy("R"), _energy("W"), _energy("L")]
	wellspring.attached_energy = [_energy("W"), _energy("C"), _energy("C")]
	var state := _state()
	state.players[0].active_pokemon = _slot("CSV9C", "161")
	state.players[0].bench = [wellspring, flareon]
	var context := {"game_state": state, "player_index": 0}
	var flareon_handoff: float = strategy.call("score_handoff_target", flareon, {"id": "switch_target"}, context)
	var wellspring_handoff: float = strategy.call("score_handoff_target", wellspring, {"id": "switch_target"}, context)
	var flareon_switch: float = strategy.call("score_interaction_target", flareon, {"id": "switch_target"}, context)
	var wellspring_switch: float = strategy.call("score_interaction_target", wellspring, {"id": "switch_target"}, context)
	return run_checks([
		assert_true(flareon_handoff >= wellspring_handoff + 3000.0, "A full RWL Flareon must dominate ready Wellspring handoff by at least 3000"),
		assert_true(flareon_switch >= wellspring_switch + 3000.0, "A normal Switch prompt must reuse the same Flareon handoff priority"),
		assert_true(absf((flareon_switch - wellspring_switch) - (flareon_handoff - wellspring_handoff)) < 300.0, "Switch target ranking should preserve the handoff score gap"),
	])


func test_complete_rwl_flareon_skips_crispin_in_a_low_deck() -> String:
	var strategy := _registry_strategy(FLAREON_DECK_ID)
	var flareon := _slot("CSV9.5C", "023")
	var crispin := _card("CSV9C", "196")
	if strategy == null or flareon == null or crispin == null:
		return assert_true(false, "Low-deck Crispin fixtures should load")
	flareon.attached_energy = [_energy("R"), _energy("W"), _energy("L")]
	var state := _state()
	state.players[0].active_pokemon = flareon
	state.players[0].hand = [crispin]
	state.players[0].deck = [_energy("R"), _energy("W"), _energy("L"), _energy("P")]
	var crispin_score: float = strategy.call("score_action_absolute", {
		"kind": "play_trainer",
		"card": crispin,
		"productive": true,
	}, state, 0)
	var end_score: float = strategy.call("score_action_absolute", {"kind": "end_turn"}, state, 0)
	var search_score: float = strategy.call("score_interaction_target", crispin, {
		"id": "csv9c_noctowl_trainers",
	}, {"game_state": state, "player_index": 0})
	return run_checks([
		assert_true(crispin_score < end_score, "A complete RWL route must not churn a low deck with Crispin"),
		assert_true(search_score < 0.0, "Noctowl must not search a dead Crispin after the RWL debt is clear"),
	])


func test_tord_complete_fan_call_debt_remains_explicitly_handled() -> String:
	var strategy := _registry_strategy(TORD_DECK_ID)
	var delegate := _delegate_of(strategy)
	var fan_rotom := _slot("CSV9C", "161")
	var field_line := _evolved_line("CSV9C", "154")
	var hand_hoothoot := _card("CSV9.5C", "141")
	var hand_noctowl := _card("CSV9C", "155")
	var terapagos := _slot("CSV9C", "175")
	if delegate == null or fan_rotom == null or field_line == null or hand_hoothoot == null \
			or hand_noctowl == null or terapagos == null:
		return assert_true(false, "Tord Fan Call regression fixtures should load")
	var state := _state()
	state.players[0].active_pokemon = fan_rotom
	state.players[0].bench = [field_line]
	state.players[0].hand = [hand_hoothoot, hand_noctowl]
	var response: Variant = delegate.call("_pick_fan_call_targets", [
		_card("CSV9C", "154"), _card("CSV9C", "155"), _card("CSV9C", "161"),
	], {"id": "csv9c_fan_call_cards", "max_select": 3}, {"game_state": state, "player_index": 0})
	var envelope: Dictionary = response if response is Dictionary else {}
	state.players[0].active_pokemon = terapagos
	state.players[0].bench = []
	var unfunded_debt: bool = delegate.call("_route_attack_debt", state.players[0], state)
	for _index: int in 5:
		terapagos.attached_energy.append(_energy("ANY"))
	var funded_debt: bool = delegate.call("_route_attack_debt", state.players[0], state)
	return run_checks([
		assert_true(bool(envelope.get("handled", false)), "Tord zero-debt Fan Call must remain explicitly handled"),
		assert_true((envelope.get("items", []) as Array).is_empty(), "Tord zero-debt Fan Call must not gain Flareon fallback picks"),
		assert_true(unfunded_debt, "Tord must retain its unfunded Tera attacker continuity debt"),
		assert_false(funded_debt, "Tord must still clear continuity debt for a ready Tera attacker"),
	])


func _registry_strategy(deck_id: int) -> RefCounted:
	var deck := _load_deck(deck_id)
	if deck == null:
		return null
	var registry: RefCounted = REGISTRY_SCRIPT.new()
	return registry.call("resolve_strategy_for_deck", deck)


func _delegate_of(strategy: RefCounted) -> RefCounted:
	if strategy == null:
		return null
	var delegate: Variant = strategy.get("_delegate")
	return delegate as RefCounted if delegate is RefCounted else null


func _load_deck(deck_id: int) -> DeckData:
	var path := "%s/%d.json" % [DECK_DIR, deck_id]
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return DeckData.from_dict(parsed) if parsed is Dictionary else null


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


func _evolved_line(hoothoot_set: String, hoothoot_index: String) -> PokemonSlot:
	var slot := _slot(hoothoot_set, hoothoot_index)
	var noctowl := _card("CSV9C", "155")
	if slot == null or noctowl == null:
		return null
	slot.pokemon_stack.append(noctowl)
	return slot


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
