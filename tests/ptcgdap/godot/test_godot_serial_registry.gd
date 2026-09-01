class_name TestGodotSerialRegistry
extends TestBase

const RegistryScript = preload("res://scripts/ai/ptcgdap/host/godot/GodotSerialRegistry.gd")
const MAX_SAFE_INTEGER := 9007199254740991


func _card(owner_index: int, legacy_instance_id: int = 0) -> CardInstance:
	var card := CardInstance.new()
	card.owner_index = owner_index
	card.instance_id = legacy_instance_id
	return card


func _slot(cards: Array[CardInstance]) -> PokemonSlot:
	var slot := PokemonSlot.new()
	for card: CardInstance in cards:
		slot.pokemon_stack.append(card)
	return slot


func _serial(result: Dictionary) -> int:
	var value: Variant = result.get("serial", -1)
	return int(value) if typeof(value) == TYPE_INT else -1


func _register_inventory(registry: Variant, cards: Array[CardInstance]) -> String:
	var counts: Array[int] = [0, 0]
	for card: CardInstance in cards:
		var result: Dictionary = registry.register_card(card, card.owner_index)
		if not bool(result.get("ok", false)):
			return "card registration failed: %s" % result.get("code", "")
		counts[card.owner_index] += 1
	var sealed: Dictionary = registry.seal_card_inventory(counts)
	if not bool(sealed.get("ok", false)):
		return "card inventory seal failed: %s" % sealed.get("code", "")
	return ""


func _released_card_serial(registry: Variant) -> int:
	var card := _card(0, 777)
	var result: Dictionary = registry.register_card(card, 0)
	return _serial(result)


func test_two_seats_receive_match_wide_unique_card_serials_despite_legacy_id_collisions() -> String:
	var registry: Variant = RegistryScript.new()
	var seen: Dictionary = {}
	var cards: Array[CardInstance] = []
	for owner_index: int in 2:
		for legacy_id: int in 60:
			var card := _card(owner_index, legacy_id)
			cards.append(card)
			var result: Dictionary = registry.register_card(card, owner_index)
			var serial := _serial(result)
			if not bool(result.get("ok", false)):
				return "registration rejected at seat %d card %d: %s" % [owner_index, legacy_id, result]
			if typeof(result.get("serial")) != TYPE_INT or serial <= 0 or serial > MAX_SAFE_INTEGER:
				return "serial is outside the positive safe-integer domain: %s" % result
			if seen.has(serial):
				return "duplicate card serial %d" % serial
			seen[serial] = true
	var repeated: Dictionary = registry.register_card(cards[0], 0)
	return run_checks([
		assert_eq(seen.size(), 120),
		assert_true(repeated.get("ok", false)),
		assert_eq(_serial(repeated), 1, "same object registration must be idempotent"),
		assert_eq(repeated.get("domain"), "card"),
		assert_eq(repeated.get("match_generation"), registry.get_match_generation()),
	])


func test_card_identity_is_object_based_and_stable_across_zone_movement() -> String:
	var registry: Variant = RegistryScript.new()
	var original := _card(0, 9)
	var copied_legacy_id := _card(0, 9)
	var original_result: Dictionary = registry.register_card(original, 0)
	var copy_result: Dictionary = registry.register_card(copied_legacy_id, 0)
	var deck: Array[CardInstance] = [original]
	var hand: Array[CardInstance] = []
	var prizes: Array[CardInstance] = []
	var in_play_stack: Array[CardInstance] = []
	var discard: Array[CardInstance] = []
	hand.append(deck.pop_front())
	prizes.append(hand.pop_front())
	in_play_stack.append(prizes.pop_front())
	discard.append(in_play_stack.pop_front())
	var moved_lookup: Dictionary = registry.lookup_card(
		discard[0], registry.get_match_generation(), 0
	)
	return run_checks([
		assert_true(original_result.get("ok", false)),
		assert_true(copy_result.get("ok", false)),
		assert_true(_serial(original_result) != _serial(copy_result)),
		assert_true(moved_lookup.get("ok", false)),
		assert_eq(_serial(moved_lookup), _serial(original_result)),
		assert_eq(registry.lookup_card(_card(0, 9), registry.get_match_generation()).get("code"), "card_not_registered"),
	])


func test_card_registration_and_lookup_fail_closed_on_host_type_seat_and_owner_drift() -> String:
	var registry: Variant = RegistryScript.new()
	var card := _card(0, 4)
	var registered: Dictionary = registry.register_card(card, 0)
	var wrong_owner: Dictionary = registry.register_card(card, 1)
	card.owner_index = 1
	var drifted: Dictionary = registry.lookup_card(card, registry.get_match_generation(), 0)
	return run_checks([
		assert_true(registered.get("ok", false)),
		assert_eq(registry.register_card(null, 0).get("code"), "invalid_card_reference"),
		assert_eq(registry.register_card("card", 0).get("code"), "invalid_card_reference"),
		assert_eq(registry.register_card(StringName("card"), 0).get("code"), "invalid_card_reference"),
		assert_eq(registry.register_card(_card(0), true).get("code"), "invalid_player_index"),
		assert_eq(registry.register_card(_card(0), 0.0).get("code"), "invalid_player_index"),
		assert_eq(registry.register_card(_card(0), -1).get("code"), "invalid_player_index"),
		assert_eq(wrong_owner.get("code"), "card_owner_mismatch"),
		assert_eq(drifted.get("code"), "card_owner_mismatch"),
		assert_eq(_serial(registry.register_card(_card(0, 4), 0)), 2, "rejections must not consume serials"),
	])


func test_sealed_inventory_rejects_late_or_clone_cards_without_revoking_registered_cards() -> String:
	var registry: Variant = RegistryScript.new()
	var live_card := _card(0, 31)
	var first: Dictionary = registry.register_card(live_card, 0)
	var opponent := _card(1, 32)
	registry.register_card(opponent, 1)
	var sealed: Dictionary = registry.seal_card_inventory([1, 1])
	var clone := _card(0, 31)
	var late: Dictionary = registry.register_card(clone, 0)
	var repeat: Dictionary = registry.register_card(live_card, 0)
	return run_checks([
		assert_true(first.get("ok", false)),
		assert_true(sealed.get("ok", false)),
		assert_true(registry.seal_card_inventory([1, 1]).get("ok", false), "inventory seal must be idempotent"),
		assert_eq(late.get("code"), "card_inventory_sealed"),
		assert_true(repeat.get("ok", false)),
		assert_eq(_serial(repeat), _serial(first)),
		assert_eq(registry.audit_snapshot().get("card_count"), 2),
	])


func test_inventory_seal_requires_live_owner_consistent_declared_counts_for_both_seats() -> String:
	var missing_seat: Variant = RegistryScript.new()
	var missing_card := _card(0, 1)
	missing_seat.register_card(missing_card, 0)
	var missing_result: Dictionary = missing_seat.seal_card_inventory([1, 1])
	var drifted: Variant = RegistryScript.new()
	var drifted_card := _card(0, 2)
	var drifted_opponent := _card(1, 2)
	drifted.register_card(drifted_card, 0)
	drifted.register_card(drifted_opponent, 1)
	drifted_card.owner_index = 1
	var drifted_result: Dictionary = drifted.seal_card_inventory([1, 1])
	var released: Variant = RegistryScript.new()
	var persistent_opponent := _card(1, 3)
	released.register_card(persistent_opponent, 1)
	_released_card_serial(released)
	var released_result: Dictionary = released.seal_card_inventory([1, 1])
	var valid: Variant = RegistryScript.new()
	var own := _card(0, 4)
	var opponent := _card(1, 4)
	valid.register_card(own, 0)
	valid.register_card(opponent, 1)
	var accepted: Dictionary = valid.seal_card_inventory([1, 1])
	var snapshot: Dictionary = valid.audit_snapshot()
	return run_checks([
		assert_eq(missing_result.get("code"), "card_inventory_mismatch"),
		assert_false(missing_seat.audit_snapshot().get("card_inventory_sealed", true)),
		assert_eq(drifted_result.get("code"), "card_owner_mismatch"),
		assert_false(drifted.audit_snapshot().get("card_inventory_sealed", true)),
		assert_eq(released_result.get("code"), "card_inventory_incomplete"),
		assert_false(released.audit_snapshot().get("card_inventory_sealed", true)),
		assert_eq(valid.seal_card_inventory([]).get("code"), "invalid_inventory_counts"),
		assert_eq(valid.seal_card_inventory([1, 0]).get("code"), "invalid_inventory_counts"),
		assert_eq(valid.seal_card_inventory([true, 1]).get("code"), "invalid_inventory_counts"),
		assert_true(accepted.get("ok", false)),
		assert_eq(valid.seal_card_inventory([2, 1]).get("code"), "card_inventory_mismatch"),
		assert_eq(snapshot.get("sealed_player_card_counts"), [1, 1]),
		assert_true(valid.audit_snapshot().get("card_inventory_valid", false)),
	])


func test_successful_seal_becomes_terminally_invalid_after_unrelated_owner_drift_or_release() -> String:
	var drifted: Variant = RegistryScript.new()
	var drifted_root := _card(0, 1)
	var unrelated := _card(0, 2)
	var drifted_opponent := _card(1, 1)
	var drifted_setup := _register_inventory(
		drifted,
		[drifted_root, unrelated, drifted_opponent]
	)
	if not drifted_setup.is_empty():
		return drifted_setup
	var drifted_slot := _slot([drifted_root])
	var active_before_drift: Dictionary = drifted.begin_pokemon_entity(drifted_slot, 0)
	unrelated.owner_index = 1
	var drifted_lookup: Dictionary = drifted.lookup_pokemon_entity(
		drifted_slot,
		drifted.get_match_generation(),
		0
	)
	var cleanup_after_drift: Dictionary = drifted.retire_pokemon_entity(
		drifted_slot,
		drifted.get_match_generation(),
		0
	)
	var drifted_snapshot: Dictionary = drifted.audit_snapshot()
	unrelated.owner_index = 0
	var still_invalid: Dictionary = drifted.begin_pokemon_entity(_slot([drifted_root]), 0)

	var released: Variant = RegistryScript.new()
	var released_root := _card(0, 3)
	var released_extra := _card(0, 4)
	var released_opponent := _card(1, 3)
	var released_setup := _register_inventory(
		released,
		[released_root, released_extra, released_opponent]
	)
	if not released_setup.is_empty():
		return released_setup
	released_extra = null
	var released_begin: Dictionary = released.begin_pokemon_entity(_slot([released_root]), 0)
	var released_snapshot: Dictionary = released.audit_snapshot()
	return run_checks([
		assert_true(active_before_drift.get("ok", false)),
		assert_eq(drifted_lookup.get("code"), "card_owner_mismatch"),
		assert_true(cleanup_after_drift.get("ok", false), "retire must remain available for safe cleanup after inventory invalidation"),
		assert_false(drifted_snapshot.get("card_inventory_valid", true)),
		assert_eq(drifted_snapshot.get("card_inventory_state"), "sealed_invalid"),
		assert_eq(drifted_snapshot.get("card_inventory_error_code"), "card_owner_mismatch"),
		assert_eq(still_invalid.get("code"), "card_owner_mismatch"),
		assert_eq(released_begin.get("code"), "card_inventory_incomplete"),
		assert_false(released_snapshot.get("card_inventory_valid", true)),
		assert_eq(released_snapshot.get("card_inventory_state"), "sealed_invalid"),
	])


func test_host_entity_serial_survives_position_evolution_devolution_and_rejects_unproven_root_replacement() -> String:
	var registry: Variant = RegistryScript.new()
	var basic := _card(0, 1)
	var stage_one := _card(0, 2)
	var replacement := _card(0, 3)
	var energy := _card(0, 4)
	var inventory: Array[CardInstance] = [basic, stage_one, replacement, energy, _card(1, 40)]
	var setup_error := _register_inventory(registry, inventory)
	if not setup_error.is_empty():
		return setup_error
	var slot := _slot([basic])
	slot.attached_energy.append(energy)
	var begun: Dictionary = registry.begin_pokemon_entity(slot, 0)
	var active: Array[PokemonSlot] = [slot]
	var bench: Array[PokemonSlot] = []
	bench.append(active.pop_front())
	var after_switch: Dictionary = registry.lookup_pokemon_entity(slot, registry.get_match_generation(), 0)
	var basic_top_card_serial_candidate := _serial(
		registry.lookup_card(slot.get_top_card(), registry.get_match_generation(), 0)
	)
	slot.pokemon_stack.append(stage_one)
	var evolved_entity: Dictionary = registry.lookup_pokemon_entity(slot, registry.get_match_generation(), 0)
	var evolved_top_card_serial_candidate := _serial(
		registry.lookup_card(slot.get_top_card(), registry.get_match_generation(), 0)
	)
	slot.pokemon_stack.pop_back()
	var devolved_entity: Dictionary = registry.lookup_pokemon_entity(slot, registry.get_match_generation(), 0)
	var devolved_top_card_serial_candidate := _serial(
		registry.lookup_card(slot.get_top_card(), registry.get_match_generation(), 0)
	)
	slot.pokemon_stack[0] = replacement
	var unannounced_change: Dictionary = registry.lookup_pokemon_entity(slot, registry.get_match_generation(), 0)
	var repeated_begin: Dictionary = registry.begin_pokemon_entity(slot, 0)
	var changed_top_card_serial_candidate := _serial(
		registry.lookup_card(slot.get_top_card(), registry.get_match_generation(), 0)
	)
	return run_checks([
		assert_true(begun.get("ok", false)),
		assert_eq(_serial(after_switch), _serial(begun)),
		assert_eq(_serial(evolved_entity), _serial(begun)),
		assert_eq(_serial(devolved_entity), _serial(begun)),
		assert_eq(unannounced_change.get("code"), "pokemon_entity_root_changed"),
		assert_eq(repeated_begin.get("code"), "pokemon_entity_root_changed"),
		assert_true(
			basic_top_card_serial_candidate != evolved_top_card_serial_candidate,
			"the later CABT projector candidate must follow the new top physical card"
		),
		assert_eq(devolved_top_card_serial_candidate, basic_top_card_serial_candidate),
		assert_true(
			changed_top_card_serial_candidate not in [
				basic_top_card_serial_candidate,
				evolved_top_card_serial_candidate,
			]
		),
		assert_eq(begun.get("domain"), "host_pokemon_entity"),
	])


func test_entity_serials_are_unique_across_both_seats_and_repeated_begin_is_idempotent() -> String:
	var registry: Variant = RegistryScript.new()
	var own := _card(0, 1)
	var opponent := _card(1, 1)
	var setup_error := _register_inventory(registry, [own, opponent])
	if not setup_error.is_empty():
		return setup_error
	var own_slot := _slot([own])
	var opponent_slot := _slot([opponent])
	var own_entity: Dictionary = registry.begin_pokemon_entity(own_slot, 0)
	var opponent_entity: Dictionary = registry.begin_pokemon_entity(opponent_slot, 1)
	var repeated: Dictionary = registry.begin_pokemon_entity(own_slot, 0)
	var wrong_seat: Dictionary = registry.begin_pokemon_entity(own_slot, 1)
	return run_checks([
		assert_true(own_entity.get("ok", false)),
		assert_true(opponent_entity.get("ok", false)),
		assert_true(_serial(own_entity) != _serial(opponent_entity)),
		assert_eq(_serial(repeated), _serial(own_entity)),
		assert_eq(wrong_seat.get("code"), "pokemon_owner_mismatch"),
		assert_eq(registry.audit_snapshot().get("host_entity_issued_count"), 2),
	])


func test_one_root_card_cannot_back_two_active_slot_entities_and_rebinds_only_after_retire() -> String:
	var registry: Variant = RegistryScript.new()
	var shared_root := _card(0, 71)
	var opponent := _card(1, 71)
	var setup_error := _register_inventory(registry, [shared_root, opponent])
	if not setup_error.is_empty():
		return setup_error
	var first_slot := _slot([shared_root])
	var duplicate_slot := _slot([shared_root])
	var first: Dictionary = registry.begin_pokemon_entity(first_slot, 0)
	var duplicate_while_active: Dictionary = registry.begin_pokemon_entity(duplicate_slot, 0)
	var retired: Dictionary = registry.retire_pokemon_entity(
		first_slot,
		registry.get_match_generation(),
		0
	)
	var rebound: Dictionary = registry.begin_pokemon_entity(duplicate_slot, 0)
	return run_checks([
		assert_true(first.get("ok", false)),
		assert_eq(duplicate_while_active.get("code"), "pokemon_entity_root_already_active"),
		assert_true(retired.get("ok", false)),
		assert_true(rebound.get("ok", false)),
		assert_eq(_serial(rebound), _serial(first) + 1, "a rejected duplicate root must not consume a serial"),
		assert_eq(registry.audit_snapshot().get("host_entity_issued_count"), 2),
	])


func test_entity_inventory_checks_evolution_and_cross_owner_attachments_without_guessing_control() -> String:
	var registry: Variant = RegistryScript.new()
	var basic := _card(0, 20)
	var own_evolution := _card(0, 21)
	var opponent_evolution := _card(1, 21)
	var opponent_energy := _card(1, 22)
	var own_tool := _card(0, 23)
	var setup_error := _register_inventory(
		registry,
		[basic, own_evolution, opponent_evolution, opponent_energy, own_tool]
	)
	if not setup_error.is_empty():
		return setup_error
	var slot := _slot([basic])
	slot.attached_energy.append(opponent_energy)
	slot.attached_tool = own_tool
	var begun: Dictionary = registry.begin_pokemon_entity(slot, 0)
	var cross_owner_attachment_ok: Dictionary = registry.lookup_pokemon_entity(
		slot, registry.get_match_generation(), 0
	)
	slot.attached_tool = _card(0, 999)
	var unregistered_tool: Dictionary = registry.lookup_pokemon_entity(slot, registry.get_match_generation(), 0)
	slot.attached_tool = own_tool
	slot.pokemon_stack.append(opponent_evolution)
	var foreign_evolution: Dictionary = registry.lookup_pokemon_entity(slot, registry.get_match_generation(), 0)
	slot.pokemon_stack.pop_back()
	slot.pokemon_stack.append(own_evolution)
	own_evolution.owner_index = 1
	var evolution_drift: Dictionary = registry.lookup_pokemon_entity(slot, registry.get_match_generation(), 0)

	var attachment_registry: Variant = RegistryScript.new()
	var attachment_basic := _card(0, 30)
	var attachment_energy := _card(1, 31)
	var attachment_opponent := _card(1, 30)
	var attachment_setup := _register_inventory(
		attachment_registry,
		[attachment_basic, attachment_energy, attachment_opponent]
	)
	if not attachment_setup.is_empty():
		return attachment_setup
	var attachment_slot := _slot([attachment_basic])
	attachment_slot.attached_energy.append(attachment_energy)
	var attachment_begun: Dictionary = attachment_registry.begin_pokemon_entity(attachment_slot, 0)
	attachment_energy.owner_index = 0
	var attachment_drift: Dictionary = attachment_registry.lookup_pokemon_entity(
		attachment_slot,
		attachment_registry.get_match_generation(),
		0
	)
	return run_checks([
		assert_true(begun.get("ok", false)),
		assert_true(cross_owner_attachment_ok.get("ok", false)),
		assert_eq(unregistered_tool.get("code"), "card_not_registered"),
		assert_eq(foreign_evolution.get("code"), "pokemon_owner_mismatch"),
		assert_eq(evolution_drift.get("code"), "card_owner_mismatch"),
		assert_true(attachment_begun.get("ok", false)),
		assert_eq(attachment_drift.get("code"), "card_owner_mismatch"),
	])


func test_entity_begin_requires_a_sealed_registered_nonempty_same_owner_inventory() -> String:
	var unsealed_registry: Variant = RegistryScript.new()
	var basic := _card(0, 1)
	unsealed_registry.register_card(basic, 0)
	var unsealed: Dictionary = unsealed_registry.begin_pokemon_entity(_slot([basic]), 0)
	var registry: Variant = RegistryScript.new()
	var own := _card(0, 2)
	var opponent := _card(1, 2)
	var setup_error := _register_inventory(registry, [own, opponent])
	if not setup_error.is_empty():
		return setup_error
	var empty := PokemonSlot.new()
	var foreign_slot := _slot([opponent])
	var unregistered_slot := _slot([_card(0, 99)])
	var never_begun_slot := _slot([own])
	return run_checks([
		assert_eq(unsealed.get("code"), "card_inventory_not_sealed"),
		assert_eq(registry.begin_pokemon_entity(null, 0).get("code"), "invalid_pokemon_reference"),
		assert_eq(registry.begin_pokemon_entity("slot", 0).get("code"), "invalid_pokemon_reference"),
		assert_eq(registry.begin_pokemon_entity(empty, 0).get("code"), "empty_pokemon_stack"),
		assert_eq(registry.begin_pokemon_entity(foreign_slot, 0).get("code"), "pokemon_owner_mismatch"),
		assert_eq(registry.begin_pokemon_entity(unregistered_slot, 0).get("code"), "card_not_registered"),
		assert_eq(
			registry.lookup_pokemon_entity(never_begun_slot, registry.get_match_generation(), 0).get("code"),
			"pokemon_entity_not_registered"
		),
		assert_eq(
			registry.retire_pokemon_entity(never_begun_slot, registry.get_match_generation(), 0).get("code"),
			"pokemon_entity_not_registered"
		),
		assert_eq(registry.begin_pokemon_entity(_slot([own]), false).get("code"), "invalid_player_index"),
	])


func test_entity_retirement_is_terminal_for_the_same_live_slot_and_serials_are_never_reused() -> String:
	var registry: Variant = RegistryScript.new()
	var basic := _card(0, 8)
	var opponent := _card(1, 80)
	var setup_error := _register_inventory(registry, [basic, opponent])
	if not setup_error.is_empty():
		return setup_error
	var first_slot := _slot([basic])
	var first: Dictionary = registry.begin_pokemon_entity(first_slot, 0)
	var retired: Dictionary = registry.retire_pokemon_entity(
		first_slot, registry.get_match_generation(), 0
	)
	var stale_lookup: Dictionary = registry.lookup_pokemon_entity(
		first_slot, registry.get_match_generation(), 0
	)
	var forbidden_reuse: Dictionary = registry.begin_pokemon_entity(first_slot, 0)
	var second_slot := _slot([basic])
	var second: Dictionary = registry.begin_pokemon_entity(second_slot, 0)
	return run_checks([
		assert_true(first.get("ok", false)),
		assert_true(retired.get("ok", false)),
		assert_eq(_serial(retired), _serial(first)),
		assert_eq(stale_lookup.get("code"), "pokemon_entity_retired"),
		assert_eq(forbidden_reuse.get("code"), "pokemon_entity_retired"),
		assert_true(second.get("ok", false)),
		assert_true(_serial(second) > _serial(first)),
		assert_eq(registry.retire_pokemon_entity(first_slot, registry.get_match_generation(), 0).get("code"), "pokemon_entity_retired"),
	])


func test_retired_engine_slot_container_can_rebind_only_after_its_public_root_changes() -> String:
	var registry: Variant = RegistryScript.new()
	var first_root := _card(0, 18)
	var replacement_root := _card(0, 19)
	var opponent := _card(1, 180)
	var setup_error := _register_inventory(registry, [first_root, replacement_root, opponent])
	if not setup_error.is_empty():
		return setup_error
	var slot := _slot([first_root])
	var first: Dictionary = registry.begin_pokemon_entity(slot, 0)
	slot.pokemon_stack[0] = replacement_root
	var unannounced: Dictionary = registry.lookup_pokemon_entity(
		slot, registry.get_match_generation(), 0
	)
	var begin_before_retire: Dictionary = registry.begin_pokemon_entity(slot, 0)
	var retired: Dictionary = registry.retire_pokemon_entity(
		slot, registry.get_match_generation(), 0
	)
	var rebound: Dictionary = registry.begin_pokemon_entity(slot, 0)
	var rebound_lookup: Dictionary = registry.lookup_pokemon_entity(
		slot, registry.get_match_generation(), 0
	)
	return run_checks([
		assert_true(first.get("ok", false)),
		assert_eq(unannounced.get("code"), "pokemon_entity_root_changed"),
		assert_eq(begin_before_retire.get("code"), "pokemon_entity_root_changed"),
		assert_true(retired.get("ok", false)),
		assert_true(rebound.get("ok", false)),
		assert_true(_serial(rebound) > _serial(first)),
		assert_eq(_serial(rebound_lookup), _serial(rebound)),
		assert_eq(registry.audit_snapshot().get("host_entity_issued_count"), 2),
	])


func test_entity_lookup_detects_top_card_owner_drift_and_unregistered_mutation() -> String:
	var registry: Variant = RegistryScript.new()
	var basic := _card(0, 12)
	var evolution := _card(0, 13)
	var opponent := _card(1, 90)
	var setup_error := _register_inventory(registry, [basic, evolution, opponent])
	if not setup_error.is_empty():
		return setup_error
	var slot := _slot([basic])
	var begun: Dictionary = registry.begin_pokemon_entity(slot, 0)
	var unknown := _card(0, 14)
	slot.pokemon_stack.append(unknown)
	var unknown_result: Dictionary = registry.lookup_pokemon_entity(slot, registry.get_match_generation(), 0)
	slot.pokemon_stack.pop_back()
	slot.pokemon_stack.append(evolution)
	evolution.owner_index = 1
	var owner_drift: Dictionary = registry.lookup_pokemon_entity(slot, registry.get_match_generation(), 0)
	return run_checks([
		assert_true(begun.get("ok", false)),
		assert_eq(unknown_result.get("code"), "card_not_registered"),
		assert_eq(owner_drift.get("code"), "card_owner_mismatch"),
	])


func test_match_generation_and_close_revoke_stale_lookups_without_cross_match_aliasing() -> String:
	var first_registry: Variant = RegistryScript.new()
	var card := _card(0, 5)
	var first: Dictionary = first_registry.register_card(card, 0)
	var first_generation: int = int(first_registry.get_match_generation())
	first_registry.close_match()
	var after_close: Dictionary = first_registry.lookup_card(card, first_generation, 0)
	var second_registry: Variant = RegistryScript.new()
	var second_generation: int = int(second_registry.get_match_generation())
	var stale_on_new: Dictionary = second_registry.lookup_card(card, first_generation, 0)
	var stale_precedes_bad_reference: Dictionary = second_registry.lookup_card(null, first_generation, false)
	var explicit_new_registration: Dictionary = second_registry.register_card(card, 0)
	return run_checks([
		assert_true(first.get("ok", false)),
		assert_true(second_generation != first_generation),
		assert_eq(after_close.get("code"), "stale_match_generation"),
		assert_eq(stale_on_new.get("code"), "stale_match_generation"),
		assert_eq(stale_precedes_bad_reference.get("code"), "stale_match_generation"),
		assert_true(explicit_new_registration.get("ok", false)),
		assert_eq(explicit_new_registration.get("match_generation"), second_generation),
	])


func test_result_and_audit_snapshots_are_copy_only_non_echoing_metadata() -> String:
	var registry: Variant = RegistryScript.new()
	var card := _card(0, 404)
	var registered: Dictionary = registry.register_card(card, 0)
	registered["serial"] = 999999
	registered["private_object"] = card
	var lookup: Dictionary = registry.lookup_card(card, registry.get_match_generation(), 0)
	var opponent := _card(1, 405)
	registry.register_card(opponent, 1)
	registry.seal_card_inventory([1, 1])
	var slot := _slot([card])
	registry.begin_pokemon_entity(slot, 0)
	var first_snapshot: Dictionary = registry.audit_snapshot()
	(first_snapshot.get("cards", []) as Array).clear()
	first_snapshot["card_count"] = 999
	first_snapshot["private_object"] = slot
	var fresh_snapshot: Dictionary = registry.audit_snapshot()
	var snapshot_text := JSON.stringify(fresh_snapshot)
	return run_checks([
		assert_eq(_serial(lookup), 1),
		assert_eq(fresh_snapshot.get("card_count"), 2),
		assert_eq((fresh_snapshot.get("cards", []) as Array).size(), 2),
		assert_true(snapshot_text.find("instance_id") == -1),
		assert_true(snapshot_text.find("get_instance_id") == -1),
		assert_true(snapshot_text.find("private_object") == -1),
		assert_true(snapshot_text.find("CardData") == -1),
		assert_true(snapshot_text.find("name") == -1),
		assert_true(snapshot_text.find("404") == -1, "legacy local IDs must not enter audit output"),
		assert_eq(fresh_snapshot.get("visibility"), "host_private_identity_audit"),
		assert_false(fresh_snapshot.get("runtime_policy_input", true)),
		assert_false(fresh_snapshot.get("public_trajectory_eligible", true)),
	])


func test_registry_uses_weak_references_and_sweeps_released_objects_to_tombstones() -> String:
	var registry: Variant = RegistryScript.new()
	var released_serial := _released_card_serial(registry)
	var sweep: Dictionary = registry.sweep_freed()
	var replacement := _card(0, 778)
	var replacement_result: Dictionary = registry.register_card(replacement, 0)
	var snapshot: Dictionary = registry.audit_snapshot()
	var cards: Array = snapshot.get("cards", [])
	return run_checks([
		assert_eq(released_serial, 1),
		assert_eq(sweep.get("released_cards"), 1),
		assert_true(_serial(replacement_result) > released_serial),
		assert_eq(cards.size(), 2),
		assert_eq((cards[0] as Dictionary).get("state"), "released"),
		assert_eq((cards[0] as Dictionary).get("serial"), released_serial),
	])


func test_released_active_entity_is_retired_without_retaining_the_slot() -> String:
	var registry: Variant = RegistryScript.new()
	var card := _card(0, 1)
	var opponent := _card(1, 1)
	var setup_error := _register_inventory(registry, [card, opponent])
	if not setup_error.is_empty():
		return setup_error
	var issued_serial := -1
	var slot := _slot([card])
	issued_serial = _serial(registry.begin_pokemon_entity(slot, 0))
	slot = null
	var sweep: Dictionary = registry.sweep_freed()
	var new_slot := _slot([card])
	var new_entity: Dictionary = registry.begin_pokemon_entity(new_slot, 0)
	var entities: Array = registry.audit_snapshot().get("host_entities", [])
	return run_checks([
		assert_eq(issued_serial, 1),
		assert_eq(sweep.get("retired_entities"), 1),
		assert_true(_serial(new_entity) > issued_serial),
		assert_eq(entities.size(), 2),
		assert_eq((entities[0] as Dictionary).get("state"), "retired"),
	])


func test_deterministic_property_sweep_preserves_card_bijection_and_entity_lifecycle() -> String:
	var registry: Variant = RegistryScript.new()
	var cards: Array[CardInstance] = []
	for index: int in 80:
		cards.append(_card(index % 2, index % 7))
	var serial_by_card: Dictionary = {}
	var seen_serials: Dictionary = {}
	for step: int in 80:
		var index := (step * 37) % 80
		var card: CardInstance = cards[index]
		var result: Dictionary = registry.register_card(card, card.owner_index)
		if not result.get("ok", false):
			return "property registration failed at %d: %s" % [index, result]
		var serial := _serial(result)
		if seen_serials.has(serial):
			return "property registration duplicated serial %d" % serial
		seen_serials[serial] = true
		serial_by_card[card] = serial
	for round_index: int in 5:
		for step: int in 80:
			var index := (step * 53 + round_index * 11) % 80
			var card: CardInstance = cards[index]
			var lookup: Dictionary = registry.lookup_card(card, registry.get_match_generation(), card.owner_index)
			if not lookup.get("ok", false) or _serial(lookup) != int(serial_by_card[card]):
				return "property lookup drifted at round %d index %d" % [round_index, index]
	var sealed: Dictionary = registry.seal_card_inventory([40, 40])
	if not sealed.get("ok", false):
		return "property inventory seal failed: %s" % sealed
	var entity_serials: Dictionary = {}
	var live_slots: Array[PokemonSlot] = []
	for index: int in 10:
		var root: CardInstance = cards[index * 2 + (index % 2)]
		var evolution: CardInstance = cards[40 + index * 2 + (index % 2)]
		if root.owner_index != evolution.owner_index:
			return "property fixture owner mismatch"
		var slot := _slot([root])
		live_slots.append(slot)
		var begun: Dictionary = registry.begin_pokemon_entity(slot, root.owner_index)
		var entity_serial := _serial(begun)
		if entity_serials.has(entity_serial):
			return "property entity serial duplicated"
		entity_serials[entity_serial] = true
		slot.pokemon_stack.append(evolution)
		if _serial(registry.lookup_pokemon_entity(slot, registry.get_match_generation(), root.owner_index)) != entity_serial:
			return "property entity drifted on evolution"
		slot.pokemon_stack.pop_back()
		if _serial(registry.lookup_pokemon_entity(slot, registry.get_match_generation(), root.owner_index)) != entity_serial:
			return "property entity drifted on devolution"
		if index % 2 == 0:
			registry.retire_pokemon_entity(slot, registry.get_match_generation(), root.owner_index)
			if registry.lookup_pokemon_entity(slot, registry.get_match_generation(), root.owner_index).get("code") != "pokemon_entity_retired":
				return "property retired entity regained authority"
	return run_checks([
		assert_eq(seen_serials.size(), 80),
		assert_eq(entity_serials.size(), 10),
		assert_eq(registry.audit_snapshot().get("host_entity_retired_count"), 5),
	])


func test_serial_space_exhaustion_fails_closed_before_unsafe_integers_are_issued() -> String:
	var card_registry: Variant = RegistryScript.new()
	var last_safe_card := _card(0, 1)
	var overflow_card := _card(0, 2)
	card_registry.set("_next_card_serial", MAX_SAFE_INTEGER)
	var last_safe_card_result: Dictionary = card_registry.register_card(last_safe_card, 0)
	var card_result: Dictionary = card_registry.register_card(overflow_card, 0)
	var entity_registry: Variant = RegistryScript.new()
	var own := _card(0, 2)
	var second_own := _card(0, 3)
	var opponent := _card(1, 2)
	var setup_error := _register_inventory(entity_registry, [own, second_own, opponent])
	if not setup_error.is_empty():
		return setup_error
	entity_registry.set("_next_entity_serial", MAX_SAFE_INTEGER)
	var last_safe_entity_result: Dictionary = entity_registry.begin_pokemon_entity(_slot([own]), 0)
	var entity_result: Dictionary = entity_registry.begin_pokemon_entity(_slot([second_own]), 0)
	return run_checks([
		assert_true(last_safe_card_result.get("ok", false)),
		assert_eq(_serial(last_safe_card_result), MAX_SAFE_INTEGER),
		assert_eq(card_result.get("code"), "serial_space_exhausted"),
		assert_true(last_safe_entity_result.get("ok", false)),
		assert_eq(_serial(last_safe_entity_result), MAX_SAFE_INTEGER),
		assert_eq(entity_result.get("code"), "serial_space_exhausted"),
		assert_eq(card_registry.audit_snapshot().get("card_count"), 1),
		assert_eq(entity_registry.audit_snapshot().get("host_entity_issued_count"), 1),
	])


func test_separate_typed_domains_never_require_cross_domain_numeric_identity() -> String:
	var registry: Variant = RegistryScript.new()
	var card := _card(0, 0)
	var card_result: Dictionary = registry.register_card(card, 0)
	var opponent := _card(1, 1)
	registry.register_card(opponent, 1)
	registry.seal_card_inventory([1, 1])
	var entity_result: Dictionary = registry.begin_pokemon_entity(_slot([card]), 0)
	return run_checks([
		assert_true(card_result.get("ok", false)),
		assert_true(entity_result.get("ok", false)),
		assert_eq(card_result.get("domain"), "card"),
		assert_eq(entity_result.get("domain"), "host_pokemon_entity"),
		assert_eq(_serial(card_result), 1),
		assert_eq(_serial(entity_result), 1, "typed domains use independent allocators"),
		assert_eq(registry.audit_snapshot().get("identity_domains"), ["card", "host_pokemon_entity"]),
	])
