class_name TestA3ExternalDecisionPort
extends TestBase

const PortScript = preload("res://scripts/ai/ptcgdap/host/godot/A3ExternalDecisionPort.gd")
const OwnerScript = preload("res://scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorDevelopmentBattleOwner.gd")
const ResolverScript = preload("res://scripts/ai/AIStepResolver.gd")

const MARNIE_DECK_ID := 800018501
const RULES_AI_DECK_ID := 575720


class FakeSerialRegistry extends RefCounted:
	var _serials: Dictionary = {}
	var _entity_serials: Dictionary = {}
	var _next := 100

	func lookup_card(card: CardInstance, _generation: int, _owner: int) -> Dictionary:
		if card == null:
			return {"ok": false}
		var key := card.get_instance_id()
		if not _serials.has(key):
			_next += 1
			_serials[key] = _next
		return {"ok": true, "serial": _serials[key]}

	func lookup_pokemon_entity(slot: PokemonSlot, _generation: int, owner: int) -> Dictionary:
		if slot == null:
			return {"ok": false, "code": "invalid_pokemon_reference"}
		var key := slot.get_instance_id()
		if not _entity_serials.has(key):
			return {"ok": false, "code": "pokemon_entity_not_registered"}
		return {"ok": true, "serial": _entity_serials[key], "player_index": owner}

	func begin_pokemon_entity(slot: PokemonSlot, owner: int) -> Dictionary:
		if slot == null:
			return {"ok": false, "code": "invalid_pokemon_reference"}
		var key := slot.get_instance_id()
		if not _entity_serials.has(key):
			_next += 1
			_entity_serials[key] = _next
		return {"ok": true, "serial": _entity_serials[key], "player_index": owner}

	func retire_pokemon_entity(slot: PokemonSlot, _generation: int, owner: int) -> Dictionary:
		if slot == null:
			return {"ok": false, "code": "invalid_pokemon_reference"}
		var key := slot.get_instance_id()
		if not _entity_serials.has(key):
			return {"ok": false, "code": "pokemon_entity_not_registered"}
		var serial: int = int(_entity_serials[key])
		_entity_serials.erase(key)
		return {"ok": true, "serial": serial, "player_index": owner}


class FakeBattleScene extends Control:
	var _pending_choice := "starting_player_choice"
	var _dialog_data := {"chooser": 0}


class FakeEvolveTriggerScene extends Control:
	var _pending_choice := ""
	var started_slot: PokemonSlot = null

	func _try_start_evolve_trigger_ability_interaction(_player_index: int, slot: PokemonSlot) -> void:
		started_slot = slot
		_pending_choice = "effect_interaction"


class PendingInteractionStrategy extends RefCounted:
	var pending := true

	func pick_interaction_items(_items: Array, _step: Dictionary, _context: Dictionary = {}) -> Array:
		return []

	func should_preserve_empty_interaction_selection(_step: Dictionary, _context: Dictionary = {}) -> bool:
		return true

	func pick_interaction_target_index(
		_items: Array,
		_excluded_targets: Array,
		_step: Dictionary,
		_context: Dictionary = {}
	) -> int:
		return -1

	func has_pending_external_decision() -> bool:
		return pending


func _frame(
	window_fill: String = "B",
	options: Array = [
		{"index":0,"option_type_raw":14},
		{"index":1,"option_type_raw":14},
	]
) -> Dictionary:
	return {
		"schema_version": 2,
		"profile_id": "ptcgdap-competitive-public-frame-v2",
		"sequence": 1,
		"seat": 0,
		"prompt_kind": "main",
		"source": {
			"public_observation_hash": "A".repeat(64),
			"window_id": window_fill.repeat(64),
		},
		"public_state": {"turn_number": 1, "phase": "MAIN"},
		"select_semantics": {
			"min_count": 1,
			"max_count": 1,
			"select_type_raw": 0,
			"select_context_raw": 0,
		},
		"options": options.duplicate(true),
	}


func test_port_publishes_then_rebinds_submitted_indexes_to_fresh_current_frame() -> String:
	var port := PortScript.new()
	var first: Dictionary = port.select(_frame())
	var checkpoint: Dictionary = port.pending_checkpoint()
	var submitted: Dictionary = port.submit(str(checkpoint.get("window_handle", "")), [1])
	var fresh := _frame("C")
	fresh["sequence"] = 2
	fresh["source"]["public_observation_hash"] = "D".repeat(64)
	var delivered: Dictionary = port.select(fresh)
	var acknowledged: bool = port.acknowledge_selection(fresh, [1])
	return run_checks([
		assert_true(bool(first.get("decision_pending", false))),
		assert_true(bool(checkpoint.get("ok", false))),
		assert_true(bool(submitted.get("ok", false))),
		assert_true(bool(delivered.get("ok", false))),
		assert_eq(delivered.get("selected_indexes"), [1]),
		assert_eq(delivered.get("window_id"), "C".repeat(64)),
		assert_eq(delivered.get("public_observation_hash"), "D".repeat(64)),
		assert_true(acknowledged),
		assert_eq(port.audit_snapshot().get("state"), "idle"),
	])


func test_port_rejects_stale_handle_invalid_cardinality_and_semantic_drift() -> String:
	var stale := PortScript.new()
	stale.select(_frame())
	var stale_result: Dictionary = stale.submit("E".repeat(64), [0])
	var invalid := PortScript.new()
	invalid.select(_frame())
	var invalid_checkpoint: Dictionary = invalid.pending_checkpoint()
	var invalid_result: Dictionary = invalid.submit(
		str(invalid_checkpoint.get("window_handle", "")), [0, 1]
	)
	var drift := PortScript.new()
	drift.select(_frame())
	var drift_checkpoint: Dictionary = drift.pending_checkpoint()
	drift.submit(str(drift_checkpoint.get("window_handle", "")), [0])
	var drift_result: Dictionary = drift.select(_frame("F", [
		{"index":1,"option_type_raw":14},
		{"index":0,"option_type_raw":14},
	]))
	return run_checks([
		assert_eq(stale_result.get("error_code"), "stale_external_window_handle"),
		assert_eq(invalid_result.get("error_code"), "invalid_external_selection"),
		assert_eq(drift_result.get("error_code"), "external_window_changed"),
		assert_eq(drift.audit_snapshot().get("state"), "faulted"),
	])


func test_external_owner_never_falls_back_while_waiting_and_executes_only_submitted_indexes() -> String:
	var marnie: DeckData = CardDatabase.get_deck(MARNIE_DECK_ID)
	var rules: DeckData = CardDatabase.get_deck(RULES_AI_DECK_ID)
	if marnie == null or rules == null:
		return "required decks unavailable"
	var gsm := GameStateMachine.new()
	gsm.random_event_port.call("configure_seed", 83421)
	gsm.start_game(marnie, rules, 0)
	var port := PortScript.new()
	var created: Dictionary = OwnerScript.create_external(
		gsm, 0, "a3-external-owner-test", port
	)
	if not bool(created.get("ok", false)):
		gsm.prepare_for_disposal()
		return "external owner bind failed: %s" % str(created)
	var owner: Variant = created.get("owner")
	var options: Array = owner.call("_options_for_items", [
		{"kind": "end_turn"},
		{"kind": "end_turn"},
	], "")
	var first: Array = owner.call("_select_items", "main", options, 1, 1)
	var checkpoint: Dictionary = port.pending_checkpoint()
	var submitted: Dictionary = port.submit(str(checkpoint.get("window_handle", "")), [1])
	var second: Array = owner.call("_select_items", "main", options, 1, 1)
	var audit: Dictionary = owner.audit_snapshot()
	var checks := run_checks([
		assert_eq(first, []),
		assert_true(bool(checkpoint.get("ok", false))),
		assert_true(bool(submitted.get("ok", false))),
		assert_eq(second, [1]),
		assert_eq(audit.get("policy_calls"), 2),
		assert_eq(audit.get("policy_successes"), 1),
		assert_eq(audit.get("policy_errors"), 0),
		assert_eq(audit.get("same_window_fallbacks"), 0),
		assert_true(bool(audit.get("external_decision_port", false))),
		assert_true(bool(audit.get("research_private_oracle_only", false))),
	])
	owner.close_match()
	gsm.prepare_for_disposal()
	return checks


func test_optional_empty_selection_is_distinct_from_a_pending_external_decision() -> String:
	var marnie: DeckData = CardDatabase.get_deck(MARNIE_DECK_ID)
	var rules: DeckData = CardDatabase.get_deck(RULES_AI_DECK_ID)
	if marnie == null or rules == null:
		return "required decks unavailable"
	var gsm := GameStateMachine.new()
	gsm.random_event_port.call("configure_seed", 83425)
	gsm.start_game(marnie, rules, 0)
	var port := PortScript.new()
	var created: Dictionary = OwnerScript.create_external(
		gsm, 0, "a3-external-optional-empty-test", port
	)
	if not bool(created.get("ok", false)):
		gsm.prepare_for_disposal()
		return "external owner bind failed: %s" % str(created)
	var owner: Variant = created.get("owner")
	var options: Array = [
		{"index": 0, "option_type_raw": 14},
		{"index": 1, "option_type_raw": 14},
	]
	var first: Array = owner.call(
		"_select_items", "search", options, 0, 1, {"type": 1, "context": 7}
	)
	var pending_preserved := bool(owner.call(
		"_should_preserve_empty_interaction_selection", {"min_select": 0}
	))
	var checkpoint: Dictionary = port.pending_checkpoint()
	var submitted: Dictionary = port.submit(
		str(checkpoint.get("window_handle", "")), []
	)
	var second: Array = owner.call(
		"_select_items", "search", options, 0, 1, {"type": 1, "context": 7}
	)
	var committed_preserved := bool(owner.call(
		"_should_preserve_empty_interaction_selection", {"min_select": 0}
	))
	var audit: Dictionary = owner.audit_snapshot()
	var checks := run_checks([
		assert_eq(first, []),
		assert_true(bool(owner.has_method("has_pending_external_decision"))),
		assert_false(pending_preserved),
		assert_true(bool(checkpoint.get("ok", false))),
		assert_true(bool(submitted.get("ok", false))),
		assert_eq(second, []),
		assert_false(bool(owner.call("has_pending_external_decision"))),
		assert_true(committed_preserved),
		assert_eq(port.audit_snapshot().get("state"), "idle"),
		assert_eq(audit.get("policy_successes"), 1),
		assert_eq(audit.get("same_window_fallbacks"), 0),
	])
	owner.close_match()
	gsm.prepare_for_disposal()
	return checks


func test_step_resolver_propagates_pending_instead_of_using_empty_or_target_fallback() -> String:
	var strategy := PendingInteractionStrategy.new()
	var resolver := ResolverScript.new()
	resolver.set_deck_strategy(strategy)
	var explicit: Dictionary = resolver.call(
		"_pick_explicit_interaction_items_with_empty_support",
		["candidate"],
		{"min_select": 0, "max_select": 1},
		1,
		{}
	)
	var no_features: Array[float] = []
	var target_index: int = int(resolver.call(
		"_best_legal_target_index",
		["target"],
		[],
		{"min_select": 1, "max_select": 1},
		{},
		no_features
	))
	strategy.pending = false
	var committed_empty: Dictionary = resolver.call(
		"_pick_explicit_interaction_items_with_empty_support",
		["candidate"],
		{"min_select": 0, "max_select": 1},
		1,
		{}
	)
	return run_checks([
		assert_true(bool(explicit.get("decision_pending", false))),
		assert_false(bool(explicit.get("has_plan", false))),
		assert_eq(target_index, -2),
		assert_false(bool(committed_empty.get("decision_pending", false))),
		assert_true(bool(committed_empty.get("has_plan", false))),
		assert_eq(committed_empty.get("items"), []),
	])


func test_external_owner_fails_closed_instead_of_executing_same_window_fallback() -> String:
	var marnie: DeckData = CardDatabase.get_deck(MARNIE_DECK_ID)
	var rules: DeckData = CardDatabase.get_deck(RULES_AI_DECK_ID)
	if marnie == null or rules == null:
		return "required decks unavailable"
	var gsm := GameStateMachine.new()
	gsm.random_event_port.call("configure_seed", 83426)
	gsm.start_game(marnie, rules, 0)
	var port := PortScript.new()
	var created: Dictionary = OwnerScript.create_external(
		gsm, 0, "a3-external-fail-closed-test", port
	)
	if not bool(created.get("ok", false)):
		gsm.prepare_for_disposal()
		return "external owner bind failed: %s" % str(created)
	var owner: Variant = created.get("owner")
	var selected: Array = owner.call(
		"_select_items",
		"main",
		[{"index": 0, "option_type_raw": 3}],
		1,
		1
	)
	var audit: Dictionary = owner.audit_snapshot()
	var checks := run_checks([
		assert_eq(selected, []),
		assert_eq(owner.call("external_decision_failure_code"), "invalid_external_frame"),
		assert_eq(port.audit_snapshot().get("state"), "faulted"),
		assert_eq(audit.get("policy_errors"), 1),
		assert_eq(audit.get("same_window_fallbacks"), 0),
		assert_eq(audit.get("engine_commits"), 0),
	])
	owner.close_match()
	gsm.prepare_for_disposal()
	return checks


func test_deferred_starting_player_choice_is_engine_owned_and_one_shot() -> String:
	var marnie: DeckData = CardDatabase.get_deck(MARNIE_DECK_ID)
	var rules: DeckData = CardDatabase.get_deck(RULES_AI_DECK_ID)
	if marnie == null or rules == null:
		return "required decks unavailable"
	var gsm := GameStateMachine.new()
	gsm.random_event_port.call("configure_seed", 83422)
	gsm.start_game(marnie, rules, 0, true)
	var pending: Dictionary = gsm.get_pending_decision_snapshot()
	var wrong_owner := bool(gsm.call("resolve_starting_player_choice", 1, true))
	var resolved := bool(gsm.call("resolve_starting_player_choice", 0, false))
	var replayed := bool(gsm.call("resolve_starting_player_choice", 0, true))
	var checks := run_checks([
		assert_eq(pending.get("kind"), "choose_starting_player"),
		assert_eq(pending.get("owner_player_index"), 0),
		assert_eq(gsm.game_state.first_player_index, 1),
		assert_eq(gsm.game_state.current_player_index, 1),
		assert_false(wrong_owner),
		assert_true(resolved),
		assert_false(replayed),
		assert_eq(gsm.count_player_total_cards(0), 60),
		assert_eq(gsm.count_player_total_cards(1), 60),
	])
	gsm.prepare_for_disposal()
	return checks


func test_owner_maps_official_yes_to_chooser_going_first() -> String:
	var marnie: DeckData = CardDatabase.get_deck(MARNIE_DECK_ID)
	var rules: DeckData = CardDatabase.get_deck(RULES_AI_DECK_ID)
	if marnie == null or rules == null:
		return "required decks unavailable"
	var gsm := GameStateMachine.new()
	gsm.random_event_port.call("configure_seed", 83423)
	gsm.start_game(marnie, rules, 0, true)
	var port := PortScript.new()
	var created: Dictionary = OwnerScript.create_external(
		gsm, 0, "a3-starting-player-owner-test", port
	)
	if not bool(created.get("ok", false)):
		gsm.prepare_for_disposal()
		return "external owner bind failed: %s" % str(created)
	var owner: Variant = created.get("owner")
	var scene := FakeBattleScene.new()
	var waiting := bool(owner.call("_run_starting_player_step", scene))
	var checkpoint: Dictionary = port.pending_checkpoint()
	var submitted: Dictionary = port.submit(
		str(checkpoint.get("window_handle", "")), [0]
	)
	var committed := bool(owner.call("_run_starting_player_step", scene))
	var checks := run_checks([
		assert_false(waiting),
		assert_true(bool(checkpoint.get("ok", false))),
		assert_true(bool(submitted.get("ok", false))),
		assert_true(committed),
		assert_eq(gsm.game_state.first_player_index, 0),
		assert_eq(gsm.game_state.current_player_index, 0),
		assert_eq(scene._pending_choice, ""),
	])
	owner.close_match()
	scene.free()
	gsm.prepare_for_disposal()
	return checks


func test_owner_maps_official_no_to_opponent_going_first() -> String:
	var marnie: DeckData = CardDatabase.get_deck(MARNIE_DECK_ID)
	var rules: DeckData = CardDatabase.get_deck(RULES_AI_DECK_ID)
	if marnie == null or rules == null:
		return "required decks unavailable"
	var gsm := GameStateMachine.new()
	gsm.random_event_port.call("configure_seed", 83424)
	gsm.start_game(marnie, rules, 0, true)
	var port := PortScript.new()
	var created: Dictionary = OwnerScript.create_external(
		gsm, 0, "a3-starting-player-owner-no-test", port
	)
	if not bool(created.get("ok", false)):
		gsm.prepare_for_disposal()
		return "external owner bind failed: %s" % str(created)
	var owner: Variant = created.get("owner")
	var scene := FakeBattleScene.new()
	var waiting := bool(owner.call("_run_starting_player_step", scene))
	var checkpoint: Dictionary = port.pending_checkpoint()
	var submitted: Dictionary = port.submit(
		str(checkpoint.get("window_handle", "")), [1]
	)
	var committed := bool(owner.call("_run_starting_player_step", scene))
	var checks := run_checks([
		assert_false(waiting),
		assert_true(bool(checkpoint.get("ok", false))),
		assert_true(bool(submitted.get("ok", false))),
		assert_true(committed),
		assert_eq(gsm.game_state.first_player_index, 1),
		assert_eq(gsm.game_state.current_player_index, 1),
		assert_eq(scene._pending_choice, ""),
	])
	owner.close_match()
	scene.free()
	gsm.prepare_for_disposal()
	return checks


func test_owner_emits_native_tool_energy_card_and_energy_unit_option_shapes() -> String:
	var owner := OwnerScript.new()
	owner.player_index = 0
	owner.set("_external_decision_port", PortScript.new())
	owner.set("_serial_registry", FakeSerialRegistry.new())
	owner.set("_match_generation", 1)
	var pokemon_data := CardData.new()
	pokemon_data.set_code = "TEST"
	pokemon_data.card_index = "001"
	pokemon_data.card_type = "Pokemon"
	var pokemon_card := CardInstance.create(pokemon_data, 0)
	var source_slot := PokemonSlot.new()
	source_slot.pokemon_stack.append(pokemon_card)
	var tool_data := CardData.new()
	tool_data.set_code = "TEST"
	tool_data.card_index = "002"
	tool_data.card_type = "Pokemon Tool"
	var tool := CardInstance.create(tool_data, 0)
	var energy_data := CardData.new()
	energy_data.set_code = "TEST"
	energy_data.card_index = "003"
	energy_data.card_type = "Basic Energy"
	energy_data.energy_provides = "D"
	var energy := CardInstance.create(energy_data, 0)
	var tool_option: Dictionary = owner.call("_make_option", 0, tool, "effect_target", {
		"cabt_select_type_raw": 2,
		"cabt_select_context_raw": 27,
	})
	var energy_card_option: Dictionary = owner.call("_make_option", 0, energy, "effect_target", {
		"cabt_select_type_raw": 2,
		"cabt_select_context_raw": 26,
	})
	var energy_unit_option: Dictionary = owner.call("_make_option", 0, {
		"source": source_slot,
		"energy_type_raw": 7,
		"energy_count": 2,
	}, "effect_target", {
		"cabt_select_type_raw": 4,
		"cabt_select_context_raw": 30,
	})
	var accepted_tool := PortScript.new().select(_frame("C", [tool_option]))
	var accepted_energy_card := PortScript.new().select(_frame("D", [energy_card_option]))
	var accepted_energy_unit := PortScript.new().select(_frame("E", [energy_unit_option]))
	var invalid_energy_unit := PortScript.new().select(_frame("F", [{
		"index": 0,
		"option_type_raw": 6,
		"source_uid": null,
		"source_serial": null,
		"energy_type_raw": 7,
		"energy_count": 1,
	}]))
	return run_checks([
		assert_eq(tool_option.get("option_type_raw"), 4),
		assert_true(int(tool_option.get("card_serial", 0)) > 0),
		assert_eq(energy_card_option.get("option_type_raw"), 5),
		assert_true(int(energy_card_option.get("card_serial", 0)) > 0),
		assert_eq(energy_unit_option.get("option_type_raw"), 6),
		assert_eq(energy_unit_option.get("source_uid"), "TEST_001"),
		assert_true(int(energy_unit_option.get("source_serial", 0)) > 0),
		assert_eq(energy_unit_option.get("energy_type_raw"), 7),
		assert_eq(energy_unit_option.get("energy_count"), 2),
		assert_true(bool(accepted_tool.get("decision_pending", false))),
		assert_true(bool(accepted_energy_card.get("decision_pending", false))),
		assert_true(bool(accepted_energy_unit.get("decision_pending", false))),
		assert_eq(invalid_energy_unit.get("error_code"), "invalid_external_frame"),
	])


func test_owner_main_and_typed_interaction_option_families_match_official_enum() -> String:
	var owner := OwnerScript.new()
	owner.player_index = 0
	owner.set("_external_decision_port", PortScript.new())
	owner.set("_serial_registry", FakeSerialRegistry.new())
	owner.set("_match_generation", 1)
	var basic_data := CardData.new()
	basic_data.set_code = "TEST"
	basic_data.card_index = "010"
	basic_data.card_type = "Pokemon"
	var basic := CardInstance.create(basic_data, 0)
	var energy_data := CardData.new()
	energy_data.set_code = "TEST"
	energy_data.card_index = "011"
	energy_data.card_type = "Basic Energy"
	var energy := CardInstance.create(energy_data, 0)
	var evolved_data := CardData.new()
	evolved_data.set_code = "TEST"
	evolved_data.card_index = "012"
	evolved_data.card_type = "Pokemon"
	var evolved := CardInstance.create(evolved_data, 0)
	var target := PokemonSlot.new()
	target.pokemon_stack.append(basic)
	var play_option: Dictionary = owner.call(
		"_make_option", 0, {"kind": "play_basic_to_bench", "card": basic}, "", {}
	)
	var attach_option: Dictionary = owner.call(
		"_make_option", 0,
		{"kind": "attach_energy", "card": energy, "target_slot": target}, "", {}
	)
	var evolve_option: Dictionary = owner.call(
		"_make_option", 0,
		{"kind": "evolve", "card": evolved, "target_slot": target}, "", {}
	)
	var typed_target_option: Dictionary = owner.call(
		"_make_option", 0, target, "attach_energy",
		{
			"cabt_select_type_raw": 1,
			"cabt_select_context_raw": 21,
			"source_card": energy,
		}
	)
	return run_checks([
		assert_eq(play_option.get("option_type_raw"), 7),
		assert_eq(attach_option.get("option_type_raw"), 8),
		assert_eq(evolve_option.get("option_type_raw"), 9),
		assert_eq(typed_target_option.get("option_type_raw"), 3),
		assert_eq(typed_target_option.get("card_uid"), "TEST_010"),
		assert_true(typed_target_option.get("card_uid") != "TEST_011"),
	])


func test_owner_main_tail_matches_official_attack_retreat_end_order() -> String:
	var owner := OwnerScript.new()
	var actions: Array[Dictionary] = [
		{"kind": "attach_energy", "marker": 1},
		{"kind": "retreat", "marker": 2},
		{"kind": "attack", "marker": 3},
		{"kind": "granted_attack", "marker": 4},
		{"kind": "end_turn", "marker": 5},
	]
	var ordered: Array[Dictionary] = owner.call("_cabt_order_main_action_tail", actions)
	return run_checks([
		assert_eq(ordered.map(func(action: Dictionary) -> String: return str(action.kind)), [
			"attach_energy", "attack", "granted_attack", "retreat", "end_turn",
		]),
		assert_eq(ordered.map(func(action: Dictionary) -> int: return int(action.marker)), [1, 3, 4, 2, 5]),
	])


func test_owner_recovers_missing_rare_candy_evolve_trigger_before_publishing_main() -> String:
	var marnie: DeckData = CardDatabase.get_deck(MARNIE_DECK_ID)
	var rules: DeckData = CardDatabase.get_deck(RULES_AI_DECK_ID)
	if marnie == null or rules == null:
		return "required decks unavailable"
	var grimmsnarl_data: CardData = CardDatabase.get_card("CSV10C", "148")
	var impidimp_data: CardData = CardDatabase.get_card("CSV10C", "146")
	var darkness_data: CardData = CardDatabase.get_card("CSVE1C", "DAR")
	if grimmsnarl_data == null or impidimp_data == null or darkness_data == null:
		return "required cards unavailable"
	var gsm := GameStateMachine.new()
	gsm.random_event_port.call("configure_seed", 83427)
	gsm.start_game(marnie, rules, 0)
	var state: GameState = gsm.game_state
	state.current_player_index = 0
	state.turn_number = 3
	var player: PlayerState = state.players[0]
	var slot := PokemonSlot.new()
	var impidimp := CardInstance.create(impidimp_data, 0)
	var grimmsnarl := CardInstance.create(grimmsnarl_data, 0)
	slot.pokemon_stack.append(impidimp)
	slot.pokemon_stack.append(grimmsnarl)
	slot.turn_evolved = state.turn_number
	player.active_pokemon = slot
	player.deck.append(CardInstance.create(darkness_data, 0))
	var owner := OwnerScript.new()
	owner.player_index = 0
	owner.set("_gsm", gsm)
	var scene := FakeEvolveTriggerScene.new()
	var started := bool(owner.call("_start_missing_evolve_trigger_interaction", scene))
	var checks := run_checks([
		assert_true(started),
		assert_true(scene.started_slot == slot),
		assert_eq(scene._pending_choice, "effect_interaction"),
	])
	scene.free()
	gsm.prepare_for_disposal()
	return checks


func test_owner_keeps_face_down_prize_as_public_position_without_card_identity() -> String:
	var owner := OwnerScript.new()
	owner.player_index = 1
	owner.set("_authority_mode", "a3_private_oracle_research")
	owner.set("_external_decision_port", PortScript.new())
	owner.set("_serial_registry", FakeSerialRegistry.new())
	owner.set("_match_generation", 1)
	var option: Dictionary = owner.call(
		"_make_option",
		0,
		4,
		"take_prize",
		{
			"cabt_select_type_raw": 1,
			"cabt_select_context_raw": 7,
			"option_area_raw": 6,
		}
	)
	var accepted := PortScript.new().select(_frame("C", [option]))
	return run_checks([
		assert_eq(option.get("option_type_raw"), 3),
		assert_eq(option.get("option_area_raw"), 6),
		assert_eq(option.get("option_area_index"), 4),
		assert_eq(option.get("option_player_index"), 1),
		assert_eq(option.get("card_uid"), null),
		assert_eq(option.get("card_serial"), null),
		assert_true(bool(accepted.get("decision_pending", false))),
	])
