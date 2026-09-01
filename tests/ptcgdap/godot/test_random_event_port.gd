class_name TestRandomEventPort
extends TestBase

const RandomEventPortScript = preload("res://scripts/engine/RandomEventPort.gd")


func test_seeded_port_is_exactly_replayable_and_records_required_fields() -> String:
	var first := RandomEventPortScript.new()
	first.configure_seed(9917, 3)
	var first_coin := first.coin({"acting_seat":0,"source_identity":"test-coin","pre_state_hash":"STATE"})
	var first_order := first.permutation(["a","b","c","d"], {"acting_seat":1,"source_identity":"test-shuffle"})
	var second := RandomEventPortScript.new()
	second.configure_seed(9917, 3)
	var second_coin := second.coin({"acting_seat":0,"source_identity":"test-coin","pre_state_hash":"STATE"})
	var second_order := second.permutation(["a","b","c","d"], {"acting_seat":1,"source_identity":"test-shuffle"})
	var events := first.events_since(0)
	return run_checks([
		assert_eq(first_coin, second_coin),
		assert_eq(first_order, second_order),
		assert_eq(events.size(), 2),
		assert_eq(events[0].get("event_ordinal"), 0),
		assert_eq(events[0].get("event_kind"), "coin"),
		assert_eq(events[0].get("acting_seat"), 0),
		assert_eq(events[0].get("source_identity"), "test-coin"),
		assert_eq(str(events[0].get("source_context_fingerprint", "")).length(), 64),
		assert_eq(str(events[0].get("pre_state_hash", "")).length(), 64),
		assert_eq(events[0].get("owner_generation"), 3),
		assert_eq(str(events[0].get("population_fingerprint", "")).length(), 64),
	])


func test_conditioned_tape_replays_exact_schedule_and_outcomes() -> String:
	var source := RandomEventPortScript.new()
	source.configure_seed(117, 1)
	var expected_coin := source.coin({"acting_seat":0,"source_identity":"coin"})
	var expected_order := source.permutation([1,2,3], {"acting_seat":0,"source_identity":"shuffle"})
	var tape := source.events_since(0)
	var replay := RandomEventPortScript.new()
	var configured := replay.configure_tape(tape, 2)
	var actual_coin := replay.coin({"acting_seat":0,"source_identity":"coin"})
	var actual_order := replay.permutation([1,2,3], {"acting_seat":0,"source_identity":"shuffle"})
	return run_checks([
		assert_true(configured),
		assert_eq(actual_coin, expected_coin),
		assert_eq(actual_order, expected_order),
		assert_eq(replay.capability_snapshot().get("tape_cursor"), 2),
	])


func test_tape_mismatch_faults_atomically_without_advancing_cursor() -> String:
	var source := RandomEventPortScript.new()
	source.configure_seed(12, 3)
	source.coin({"acting_seat":0,"source_identity":"test"})
	var tape: Array = source.events_since(0)
	tape[0]["population_fingerprint"] = "A".repeat(64)
	var port := RandomEventPortScript.new()
	if not port.configure_tape(tape, 3):
		return "well-shaped mismatch tape was rejected before consumption"
	var outcome: bool = port.coin({"acting_seat":0,"source_identity":"test"})
	var snapshot: Dictionary = port.capability_snapshot()
	return run_checks([
		assert_false(outcome),
		assert_eq(snapshot.get("fault_code"), "random_event_tape_mismatch"),
		assert_eq(snapshot.get("event_count"), 0),
		assert_eq(snapshot.get("tape_cursor"), 0),
	])


func test_game_state_machine_uses_one_port_for_coin_and_both_player_shuffles() -> String:
	var gsm := GameStateMachine.new()
	var player_zero := PlayerState.new()
	var player_one := PlayerState.new()
	player_zero.player_index = 0
	player_one.player_index = 1
	player_zero.random_event_port = gsm.random_event_port
	player_one.random_event_port = gsm.random_event_port
	var card_data := CardData.new()
	card_data.set_code = "TEST"
	card_data.card_index = "1"
	for index: int in 3:
		player_zero.deck.append(CardInstance.create(card_data, 0))
		player_one.deck.append(CardInstance.create(card_data, 1))
	gsm.random_event_port.call("configure_seed", 42)
	gsm.coin_flipper.flip()
	player_zero.shuffle_deck()
	player_one.shuffle_deck()
	var events: Array = gsm.random_event_port.call("events_since", 0)
	var checks := run_checks([
		assert_eq(gsm.coin_flipper.random_event_port, gsm.random_event_port),
		assert_eq(player_zero.random_event_port, gsm.random_event_port),
		assert_eq(player_one.random_event_port, gsm.random_event_port),
		assert_eq(events.size(), 3),
		assert_eq(events[0].get("event_kind"), "coin"),
		assert_eq(events[1].get("event_kind"), "shuffle"),
		assert_eq(events[2].get("event_kind"), "shuffle"),
	])
	gsm.prepare_for_disposal()
	return checks


func test_context_stack_binds_card_attack_effect_and_tape_rejects_wrong_source() -> String:
	var source := RandomEventPortScript.new()
	source.configure_seed(712, 4)
	var token := source.push_context({
		"acting_seat": 1,
		"source_identity": "attack:CSV10C_127#1:effect:EFFECT",
		"source_card_uid": "CSV10C_127",
		"source_attack_ordinal": 1,
		"effect_id": "EFFECT",
		"effect_phase": "attack_effect",
		"effect_implementation": "res://effects/Test.gd",
		"pre_state_hash": "A".repeat(64),
	})
	source.coin()
	source.pop_context(token)
	var tape: Array = source.events_since(0)
	var event: Dictionary = tape[0]
	var replay := RandomEventPortScript.new()
	replay.configure_tape(tape, 5)
	var wrong_token := replay.push_context({
		"acting_seat": 1,
		"source_identity": "attack:CSV10C_127#0:effect:EFFECT",
		"source_card_uid": "CSV10C_127",
		"source_attack_ordinal": 0,
		"effect_id": "EFFECT",
		"effect_phase": "attack_effect",
		"effect_implementation": "res://effects/Test.gd",
		"pre_state_hash": "A".repeat(64),
	})
	var wrong_outcome := replay.coin()
	var snapshot: Dictionary = replay.capability_snapshot()
	replay.pop_context(wrong_token)
	return run_checks([
		assert_eq(event.get("source_card_uid"), "CSV10C_127"),
		assert_eq(event.get("source_attack_ordinal"), 1),
		assert_eq(event.get("effect_id"), "EFFECT"),
		assert_eq(event.get("effect_phase"), "attack_effect"),
		assert_eq(event.get("pre_state_hash"), "A".repeat(64)),
		assert_false(wrong_outcome),
		assert_eq(snapshot.get("fault_code"), "random_event_tape_mismatch"),
		assert_eq(snapshot.get("tape_cursor"), 0),
	])


func test_coin_context_fingerprint_distinguishes_group_target_status_and_ability() -> String:
	var port := RandomEventPortScript.new()
	port.configure_seed(81234)
	var shared := {
		"acting_seat": 0,
		"source_identity": "pokemon_check",
		"source_card_uid": "P_1",
		"source_ability_ordinal": 1,
		"effect_phase": "between_turns_status",
		"pre_state_hash": "A".repeat(64),
	}
	var first := shared.duplicate(true)
	first.merge({
		"target_identity": "seat:0:active:P_1",
		"status_condition": "burned",
		"event_in_group": 0,
	}, true)
	var second := shared.duplicate(true)
	second.merge({
		"target_identity": "seat:1:active:P_2",
		"status_condition": "asleep",
		"event_in_group": 1,
	}, true)
	port.coin(first)
	port.coin(second)
	var events: Array = port.events_since(0)
	return run_checks([
		assert_eq(events.size(), 2),
		assert_true(events[0].get("source_context_fingerprint") != events[1].get("source_context_fingerprint")),
		assert_eq(events[0].get("source_ability_ordinal"), 1),
		assert_eq(events[0].get("status_condition"), "burned"),
		assert_eq(events[1].get("target_identity"), "seat:1:active:P_2"),
		assert_eq(events[1].get("event_in_group"), 1),
	])
