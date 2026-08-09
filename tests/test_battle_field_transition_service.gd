class_name TestBattleFieldTransitionService
extends TestBase

const FieldTransition := preload("res://scripts/engine/BattleFieldTransitionService.gd")


func test_switch_transaction_commits_topology_leave_entry_and_audit_together() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var outgoing := _slot("Outgoing", 0)
	var incoming := _slot("Incoming", 0)
	var other := _slot("Other", 0)
	player.active_pokemon = outgoing
	player.bench = [incoming, other]
	outgoing.set_status("poisoned", true)
	outgoing.effects.append({"type": "retreat_lock", "turn": state.turn_number})

	var committed := FieldTransition.switch_active_with_bench(
		state,
		0,
		incoming,
		"contract_test"
	)
	var events := FieldTransition.get_transition_events(state)
	var event: Dictionary = events.back() if not events.is_empty() else {}

	return run_checks([
		assert_true(committed, "A valid field switch must commit"),
		assert_eq(player.active_pokemon, incoming, "The selected Bench Pokemon must become Active"),
		assert_eq(player.bench, [other, outgoing], "Append placement must preserve the established Bench ordering policy"),
		assert_false(outgoing.has_any_status(), "Leaving the Active Spot must clear Special Conditions"),
		assert_false(_has_effect(outgoing, "retreat_lock"), "Leaving the Active Spot must clear Active-only effects"),
		assert_true(incoming.entered_active_from_bench_this_turn(state.turn_number), "The incoming slot must receive the shared Bench-to-Active marker"),
		assert_eq(events.size(), 1, "One committed transaction must publish exactly one field event"),
		assert_eq(event.get("kind", ""), "switch", "The field event must expose its transition kind"),
		assert_eq(event.get("reason", ""), "contract_test", "The field event must retain the owning rule reason"),
		assert_eq(event.get("incoming_slot_id", -1), int(incoming.get_instance_id()), "The audit event must identify the incoming slot"),
	])


func test_switch_transaction_can_preserve_the_incoming_bench_index() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var outgoing := _slot("Outgoing", 0)
	var first := _slot("First", 0)
	var incoming := _slot("Incoming", 0)
	var last := _slot("Last", 0)
	player.active_pokemon = outgoing
	player.bench = [first, incoming, last]

	var committed := FieldTransition.switch_active_with_bench(
		state,
		0,
		incoming,
		"preserve_index_contract",
		FieldTransition.BENCH_PLACEMENT_REPLACE_INCOMING
	)

	return run_checks([
		assert_true(committed, "A replace-index switch must commit"),
		assert_eq(player.bench, [first, outgoing, last], "Replace-index placement must not reshuffle unrelated Bench slots"),
		assert_eq(player.active_pokemon, incoming, "The incoming slot must become Active"),
	])


func test_newcomer_transition_does_not_forge_a_bench_entry_trigger() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var outgoing := _slot("Outgoing", 0)
	var newcomer := _slot("Newcomer", 0)
	player.active_pokemon = outgoing

	var committed := FieldTransition.replace_active_with_newcomer(
		state,
		0,
		newcomer,
		"direct_from_hand"
	)
	var events := FieldTransition.get_transition_events(state)
	var event: Dictionary = events.back() if not events.is_empty() else {}

	return run_checks([
		assert_true(committed, "A direct-to-Active newcomer transition must commit"),
		assert_eq(player.active_pokemon, newcomer, "The newcomer must become Active"),
		assert_true(outgoing in player.bench, "The old Active Pokemon must move to the Bench"),
		assert_false(newcomer.entered_active_from_bench_this_turn(state.turn_number), "A Pokemon placed directly from hand must not satisfy Bench-to-Active abilities"),
		assert_true(newcomer.active_order > 0, "A direct newcomer must still receive Active ordering metadata"),
		assert_false(bool(event.get("incoming_from_bench", true)), "The audit event must distinguish direct entry from Bench promotion"),
	])


func test_invalid_transition_is_atomic_and_emits_no_event() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var outgoing := _slot("Outgoing", 0)
	var bench_slot := _slot("Bench", 0)
	var stale_slot := _slot("Stale", 0)
	player.active_pokemon = outgoing
	player.bench = [bench_slot]
	outgoing.set_status("poisoned", true)

	var committed := FieldTransition.switch_active_with_bench(
		state,
		0,
		stale_slot,
		"invalid_target"
	)

	return run_checks([
		assert_false(committed, "A stale target outside the Bench must be rejected"),
		assert_eq(player.active_pokemon, outgoing, "A rejected transaction must leave Active topology unchanged"),
		assert_eq(player.bench, [bench_slot], "A rejected transaction must leave Bench topology unchanged"),
		assert_true(outgoing.has_any_status(), "A rejected transaction must not partially apply leave cleanup"),
		assert_true(FieldTransition.get_transition_events(state).is_empty(), "A rejected transaction must not publish an event"),
	])


func test_remove_and_promote_is_one_bench_to_active_transaction() -> String:
	var state := _make_state()
	var player: PlayerState = state.players[0]
	var outgoing := _slot("Returning", 0)
	var incoming := _slot("Replacement", 0)
	var other := _slot("Other", 0)
	player.active_pokemon = outgoing
	player.bench = [incoming, other]

	var committed := FieldTransition.remove_active_and_promote(
		state,
		0,
		outgoing,
		incoming,
		"return_to_deck"
	)
	var events := FieldTransition.get_transition_events(state)

	return run_checks([
		assert_true(committed, "Removing an Active Pokemon with a valid replacement must commit"),
		assert_eq(player.active_pokemon, incoming, "The replacement must become Active in the same transaction"),
		assert_eq(player.bench, [other], "The removed Active Pokemon must not be reinserted into the Bench"),
		assert_true(incoming.entered_active_from_bench_this_turn(state.turn_number), "The replacement must receive the same Bench-to-Active event as every other path"),
		assert_eq(events.size(), 1, "Remove-and-promote must publish one event rather than two partial events"),
		assert_eq((events[0] as Dictionary).get("kind", ""), "remove_and_promote", "The audit event must identify the combined transaction"),
	])


func _make_state() -> GameState:
	var state := GameState.new()
	state.turn_number = 4
	state.phase = GameState.GamePhase.MAIN
	for player_index: int in 2:
		var player := PlayerState.new()
		player.player_index = player_index
		state.players.append(player)
	return state


func _slot(name: String, owner_index: int) -> PokemonSlot:
	var card_data := CardData.new()
	card_data.name = name
	card_data.card_type = "Pokemon"
	card_data.stage = "Basic"
	card_data.hp = 100
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(card_data, owner_index))
	return slot


func _has_effect(slot: PokemonSlot, effect_type: String) -> bool:
	for effect: Dictionary in slot.effects:
		if str(effect.get("type", "")) == effect_type:
			return true
	return false
