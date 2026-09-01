## Match-scoped, Host-private identity side table for the PtcgDAP migration.
##
## This class intentionally does not project CABT observations and does not
## execute engine actions.  It owns two typed identity domains:
##
## - card: one physical CardInstance for the lifetime of a match;
## - host_pokemon_entity: one in-play PokemonSlot lifecycle.
##
## CABT Pokemon.serial is the serial of the current top physical card.  The
## Host-private entity serial is continuity metadata only and must never be
## substituted for that wire value.
class_name GodotSerialRegistry
extends RefCounted

const DOMAIN_CARD := "card"
const DOMAIN_ENTITY := "host_pokemon_entity"
const DOMAIN_CARD_INVENTORY := "card_inventory"
const MAX_SAFE_INTEGER := 9007199254740991

const STATE_REGISTERED := "registered"
const STATE_ACTIVE := "active"
const STATE_RETIRED := "retired"
const STATE_RELEASED := "released"
const STATE_CLOSED := "closed"

const ERROR_CODES: Array[String] = [
	"stale_match_generation",
	"invalid_card_reference",
	"invalid_pokemon_reference",
	"invalid_player_index",
	"empty_pokemon_stack",
	"card_owner_mismatch",
	"pokemon_owner_mismatch",
	"card_not_registered",
	"pokemon_entity_not_registered",
	"pokemon_entity_retired",
	"pokemon_entity_root_changed",
	"pokemon_entity_root_already_active",
	"card_inventory_not_sealed",
	"card_inventory_sealed",
	"invalid_inventory_counts",
	"card_inventory_mismatch",
	"card_inventory_incomplete",
	"serial_space_exhausted",
	"internal_error",
]

static var _next_match_generation: int = 1

var _match_generation: int = -1
var _open: bool = false
var _card_inventory_sealed: bool = false
var _card_inventory_valid: bool = false
var _card_inventory_error_code: String = ""
var _sealed_player_card_counts: Array[int] = []
var _next_card_serial: int = 1
var _next_entity_serial: int = 1

# Match inventory size is tiny (normally 120 cards), so the registry uses a
# direct WeakRef equality scan.  It never reads or stores a Godot ObjectID.
var _card_records: Array[Dictionary] = []
var _entity_records: Array[Dictionary] = []

# Audit metadata deliberately contains no Object, WeakRef, runtime bucket,
# CardData, display name, local instance_id, zone, or option index.
var _card_audit_by_serial: Dictionary = {}
var _entity_audit_by_serial: Dictionary = {}


func _init() -> void:
	_match_generation = _allocate_match_generation()
	_open = _match_generation > 0


static func _allocate_match_generation() -> int:
	if _next_match_generation <= 0 or _next_match_generation > MAX_SAFE_INTEGER:
		return -1
	var generation := _next_match_generation
	_next_match_generation += 1
	return generation


func get_match_generation() -> int:
	return _match_generation


func is_open() -> bool:
	return _open


func close_match() -> void:
	if not _open:
		return
	_open = false
	_card_inventory_valid = false
	for serial: Variant in _card_audit_by_serial:
		var metadata: Dictionary = _card_audit_by_serial[serial]
		if metadata.get("state") == STATE_REGISTERED:
			metadata["state"] = STATE_CLOSED
	for serial: Variant in _entity_audit_by_serial:
		var metadata: Dictionary = _entity_audit_by_serial[serial]
		if metadata.get("state") == STATE_ACTIVE:
			metadata["state"] = STATE_CLOSED
	_card_records.clear()
	_entity_records.clear()


func register_card(card_ref: Variant, player_index: Variant) -> Dictionary:
	if not _open:
		return _error(DOMAIN_CARD, "stale_match_generation")
	if not _is_card_reference(card_ref):
		return _error(DOMAIN_CARD, "invalid_card_reference")
	if not _is_player_index(player_index):
		return _error(DOMAIN_CARD, "invalid_player_index")

	var card: CardInstance = card_ref as CardInstance
	var owner := int(player_index)
	var existing := _card_record(card)
	if not existing.is_empty():
		if _card_inventory_sealed:
			var inventory_error := _require_valid_sealed_inventory()
			if not inventory_error.is_empty():
				return _error(DOMAIN_CARD, inventory_error)
		if int(existing.get("player_index", -1)) != owner or card.owner_index != owner:
			return _error(DOMAIN_CARD, "card_owner_mismatch")
		return _success(
			DOMAIN_CARD,
			int(existing.get("serial", -1)),
			owner
		)

	if _card_inventory_sealed:
		return _error(DOMAIN_CARD, "card_inventory_sealed")
	if card.owner_index != owner:
		return _error(DOMAIN_CARD, "card_owner_mismatch")
	var serial := _take_card_serial()
	if serial < 0:
		return _error(DOMAIN_CARD, "serial_space_exhausted")
	var record := {
		"object_ref": weakref(card),
		"serial": serial,
		"player_index": owner,
		"state": STATE_REGISTERED,
	}
	_store_object_record(_card_records, record)
	_card_audit_by_serial[serial] = _audit_record(
		DOMAIN_CARD,
		serial,
		owner,
		STATE_REGISTERED
	)
	return _success(DOMAIN_CARD, serial, owner)


func seal_card_inventory(expected_player_card_counts: Variant) -> Dictionary:
	if not _open:
		return _error(DOMAIN_CARD_INVENTORY, "stale_match_generation")
	if not _is_inventory_counts(expected_player_card_counts):
		return _error(DOMAIN_CARD_INVENTORY, "invalid_inventory_counts")
	var expected: Array[int] = [
		int((expected_player_card_counts as Array)[0]),
		int((expected_player_card_counts as Array)[1]),
	]
	if _card_inventory_sealed:
		if _sealed_player_card_counts != expected:
			return _error(DOMAIN_CARD_INVENTORY, "card_inventory_mismatch")
		var repeated_error := _require_valid_sealed_inventory()
		if not repeated_error.is_empty():
			return _error(DOMAIN_CARD_INVENTORY, repeated_error)
		return _success_without_serial(DOMAIN_CARD_INVENTORY)
	var validation_error := _current_inventory_error(expected, "card_inventory_mismatch")
	if not validation_error.is_empty():
		return _error(DOMAIN_CARD_INVENTORY, validation_error)
	_card_inventory_sealed = true
	_card_inventory_valid = true
	_card_inventory_error_code = ""
	_sealed_player_card_counts = expected.duplicate()
	return _success_without_serial(DOMAIN_CARD_INVENTORY)


func lookup_card(
	card_ref: Variant,
	expected_match_generation: Variant,
	expected_player_index: Variant = -1
) -> Dictionary:
	var scope_error := _match_scope_error(expected_match_generation)
	if not scope_error.is_empty():
		return _error(DOMAIN_CARD, scope_error)
	if not _is_card_reference(card_ref):
		return _error(DOMAIN_CARD, "invalid_card_reference")
	if not _is_optional_player_index(expected_player_index):
		return _error(DOMAIN_CARD, "invalid_player_index")
	if _card_inventory_sealed:
		var inventory_error := _require_valid_sealed_inventory()
		if not inventory_error.is_empty():
			return _error(DOMAIN_CARD, inventory_error)

	var card: CardInstance = card_ref as CardInstance
	var record := _card_record(card)
	if record.is_empty():
		return _error(DOMAIN_CARD, "card_not_registered")
	var owner := int(record.get("player_index", -1))
	if card.owner_index != owner:
		return _error(DOMAIN_CARD, "card_owner_mismatch")
	if int(expected_player_index) >= 0 and int(expected_player_index) != owner:
		return _error(DOMAIN_CARD, "card_owner_mismatch")
	return _success(DOMAIN_CARD, int(record.get("serial", -1)), owner)


func begin_pokemon_entity(slot_ref: Variant, player_index: Variant) -> Dictionary:
	if not _open:
		return _error(DOMAIN_ENTITY, "stale_match_generation")
	if not _is_pokemon_reference(slot_ref):
		return _error(DOMAIN_ENTITY, "invalid_pokemon_reference")
	if not _is_player_index(player_index):
		return _error(DOMAIN_ENTITY, "invalid_player_index")
	var inventory_error := _require_valid_sealed_inventory()
	if not inventory_error.is_empty():
		return _error(DOMAIN_ENTITY, inventory_error)

	var slot: PokemonSlot = slot_ref as PokemonSlot
	var owner := int(player_index)
	var existing := _entity_record(slot)
	if not existing.is_empty():
		if existing.get("state") == STATE_RETIRED:
			var replacement_validation := _validate_slot_inventory(slot, owner)
			if not replacement_validation.is_empty():
				return _error(DOMAIN_ENTITY, replacement_validation)
			var replacement_root_serial := _slot_root_card_serial(slot)
			if replacement_root_serial == int(existing.get("root_card_serial", -1)):
				return _error(DOMAIN_ENTITY, "pokemon_entity_retired")
			if _has_active_entity_for_root(replacement_root_serial):
				return _error(DOMAIN_ENTITY, "pokemon_entity_root_already_active")
			return _issue_pokemon_entity(slot, owner, replacement_root_serial)
		if int(existing.get("player_index", -1)) != owner:
			return _error(DOMAIN_ENTITY, "pokemon_owner_mismatch")
		var existing_validation := _validate_slot_inventory(slot, owner)
		if not existing_validation.is_empty():
			return _error(DOMAIN_ENTITY, existing_validation)
		var existing_root_error := _entity_root_error(existing, slot)
		if not existing_root_error.is_empty():
			return _error(DOMAIN_ENTITY, existing_root_error)
		return _success(
			DOMAIN_ENTITY,
			int(existing.get("serial", -1)),
			owner
		)

	var validation_error := _validate_slot_inventory(slot, owner)
	if not validation_error.is_empty():
		return _error(DOMAIN_ENTITY, validation_error)
	var root_serial := _slot_root_card_serial(slot)
	if _has_active_entity_for_root(root_serial):
		return _error(DOMAIN_ENTITY, "pokemon_entity_root_already_active")
	return _issue_pokemon_entity(slot, owner, root_serial)


func _issue_pokemon_entity(slot: PokemonSlot, owner: int, root_serial: int) -> Dictionary:
	var serial := _take_entity_serial()
	if serial < 0:
		return _error(DOMAIN_ENTITY, "serial_space_exhausted")
	var record := {
		"object_ref": weakref(slot),
		"serial": serial,
		"player_index": owner,
		"root_card_serial": root_serial,
		"state": STATE_ACTIVE,
	}
	_store_object_record(_entity_records, record)
	_entity_audit_by_serial[serial] = _audit_record(
		DOMAIN_ENTITY,
		serial,
		owner,
		STATE_ACTIVE
	)
	return _success(DOMAIN_ENTITY, serial, owner)


func lookup_pokemon_entity(
	slot_ref: Variant,
	expected_match_generation: Variant,
	expected_player_index: Variant = -1
) -> Dictionary:
	var scope_error := _match_scope_error(expected_match_generation)
	if not scope_error.is_empty():
		return _error(DOMAIN_ENTITY, scope_error)
	if not _is_pokemon_reference(slot_ref):
		return _error(DOMAIN_ENTITY, "invalid_pokemon_reference")
	if not _is_optional_player_index(expected_player_index):
		return _error(DOMAIN_ENTITY, "invalid_player_index")
	var inventory_error := _require_valid_sealed_inventory()
	if not inventory_error.is_empty():
		return _error(DOMAIN_ENTITY, inventory_error)

	var slot: PokemonSlot = slot_ref as PokemonSlot
	var record := _entity_record(slot)
	if record.is_empty():
		return _error(DOMAIN_ENTITY, "pokemon_entity_not_registered")
	if record.get("state") == STATE_RETIRED:
		return _error(DOMAIN_ENTITY, "pokemon_entity_retired")
	var owner := int(record.get("player_index", -1))
	if int(expected_player_index) >= 0 and int(expected_player_index) != owner:
		return _error(DOMAIN_ENTITY, "pokemon_owner_mismatch")
	var validation_error := _validate_slot_inventory(slot, owner)
	if not validation_error.is_empty():
		return _error(DOMAIN_ENTITY, validation_error)
	var root_error := _entity_root_error(record, slot)
	if not root_error.is_empty():
		return _error(DOMAIN_ENTITY, root_error)
	return _success(DOMAIN_ENTITY, int(record.get("serial", -1)), owner)


func retire_pokemon_entity(
	slot_ref: Variant,
	expected_match_generation: Variant,
	expected_player_index: Variant = -1
) -> Dictionary:
	var scope_error := _match_scope_error(expected_match_generation)
	if not scope_error.is_empty():
		return _error(DOMAIN_ENTITY, scope_error)
	if not _is_pokemon_reference(slot_ref):
		return _error(DOMAIN_ENTITY, "invalid_pokemon_reference")
	if not _is_optional_player_index(expected_player_index):
		return _error(DOMAIN_ENTITY, "invalid_player_index")

	var slot: PokemonSlot = slot_ref as PokemonSlot
	var record := _entity_record(slot)
	if record.is_empty():
		return _error(DOMAIN_ENTITY, "pokemon_entity_not_registered")
	if record.get("state") == STATE_RETIRED:
		return _error(DOMAIN_ENTITY, "pokemon_entity_retired")
	var owner := int(record.get("player_index", -1))
	if int(expected_player_index) >= 0 and int(expected_player_index) != owner:
		return _error(DOMAIN_ENTITY, "pokemon_owner_mismatch")
	record["state"] = STATE_RETIRED
	var serial := int(record.get("serial", -1))
	var metadata: Dictionary = _entity_audit_by_serial.get(serial, {})
	if not metadata.is_empty():
		metadata["state"] = STATE_RETIRED
	return _success(DOMAIN_ENTITY, serial, owner)


func sweep_freed() -> Dictionary:
	var released_cards := _sweep_dead_records(
		_card_records,
		_card_audit_by_serial,
		STATE_RELEASED
	)
	var retired_entities := _sweep_dead_records(
		_entity_records,
		_entity_audit_by_serial,
		STATE_RETIRED
	)
	if released_cards > 0 and _card_inventory_sealed:
		_invalidate_card_inventory("card_inventory_incomplete")
	return {
		"released_cards": released_cards,
		"retired_entities": retired_entities,
	}


func audit_snapshot() -> Dictionary:
	if _open and _card_inventory_sealed:
		_require_valid_sealed_inventory()
	var cards := _audit_records_in_serial_order(_card_audit_by_serial)
	var entities := _audit_records_in_serial_order(_entity_audit_by_serial)
	var active_entities := 0
	var retired_entities := 0
	for record: Dictionary in entities:
		match record.get("state"):
			STATE_ACTIVE:
				active_entities += 1
			STATE_RETIRED:
				retired_entities += 1
	return {
		"schema_version": 1,
		"visibility": "host_private_identity_audit",
		"runtime_policy_input": false,
		"public_trajectory_eligible": false,
		"registry_state": "open" if _open else "closed",
		"match_generation": _match_generation,
		"identity_domains": [DOMAIN_CARD, DOMAIN_ENTITY],
		"card_inventory_sealed": _card_inventory_sealed,
		"card_inventory_valid": _card_inventory_valid,
		"card_inventory_state": _card_inventory_state(),
		"card_inventory_error_code": _card_inventory_error_code,
		"sealed_player_card_counts": _sealed_player_card_counts.duplicate(),
		"card_count": cards.size(),
		"host_entity_issued_count": entities.size(),
		"host_entity_active_count": active_entities,
		"host_entity_retired_count": retired_entities,
		"cards": cards,
		"host_entities": entities,
	}


func _validate_slot_inventory(slot: PokemonSlot, player_index: int) -> String:
	if slot.pokemon_stack.is_empty() or slot.get_top_card() == null:
		return "empty_pokemon_stack"
	var top: CardInstance = slot.get_top_card()
	var top_record := _card_record(top)
	if top_record.is_empty():
		return "card_not_registered"
	if top.owner_index != int(top_record.get("player_index", -1)):
		return "card_owner_mismatch"
	if int(top_record.get("player_index", -1)) != player_index:
		return "pokemon_owner_mismatch"

	for stack_card: CardInstance in slot.pokemon_stack:
		if _registered_card_error(stack_card) != "":
			return _registered_card_error(stack_card)
		var stack_record := _card_record(stack_card)
		if int(stack_record.get("player_index", -1)) != player_index:
			return "pokemon_owner_mismatch"
	for energy: CardInstance in slot.attached_energy:
		var energy_error := _registered_card_error(energy)
		if not energy_error.is_empty():
			return energy_error
	if slot.attached_tool != null:
		var tool_error := _registered_card_error(slot.attached_tool)
		if not tool_error.is_empty():
			return tool_error
	return ""


func _require_valid_sealed_inventory() -> String:
	if not _card_inventory_sealed:
		return "card_inventory_not_sealed"
	if not _card_inventory_valid:
		return (
			_card_inventory_error_code
			if _card_inventory_error_code in ERROR_CODES
			else "card_inventory_incomplete"
		)
	var error := _current_inventory_error(
		_sealed_player_card_counts,
		"card_inventory_incomplete"
	)
	if not error.is_empty():
		_invalidate_card_inventory(error)
	return error


func _current_inventory_error(expected: Array[int], count_error: String) -> String:
	var released := _sweep_dead_records(
		_card_records,
		_card_audit_by_serial,
		STATE_RELEASED
	)
	if released > 0:
		return "card_inventory_incomplete"
	for metadata: Variant in _card_audit_by_serial.values():
		if metadata is Dictionary and (metadata as Dictionary).get("state") == STATE_RELEASED:
			return "card_inventory_incomplete"
	var actual: Array[int] = [0, 0]
	for record: Dictionary in _card_records:
		var raw_weak: Variant = record.get("object_ref", null)
		var card_ref: Variant = (
			(raw_weak as WeakRef).get_ref() if raw_weak is WeakRef else null
		)
		if not _is_card_reference(card_ref):
			return "card_inventory_incomplete"
		var owner := int(record.get("player_index", -1))
		if owner not in [0, 1] or (card_ref as CardInstance).owner_index != owner:
			return "card_owner_mismatch"
		actual[owner] += 1
	if actual != expected:
		return count_error
	return ""


func _invalidate_card_inventory(code: String) -> void:
	if not _card_inventory_sealed:
		return
	_card_inventory_valid = false
	if _card_inventory_error_code.is_empty():
		_card_inventory_error_code = code if code in ERROR_CODES else "internal_error"


func _card_inventory_state() -> String:
	if not _open:
		return STATE_CLOSED
	if not _card_inventory_sealed:
		return "unsealed"
	return "sealed_valid" if _card_inventory_valid else "sealed_invalid"


func _registered_card_error(card: CardInstance) -> String:
	if card == null:
		return "invalid_card_reference"
	var record := _card_record(card)
	if record.is_empty():
		return "card_not_registered"
	if card.owner_index != int(record.get("player_index", -1)):
		return "card_owner_mismatch"
	return ""


func _slot_root_card_serial(slot: PokemonSlot) -> int:
	if slot == null or slot.pokemon_stack.is_empty():
		return -1
	var root: CardInstance = slot.pokemon_stack[0]
	var record := _card_record(root)
	return int(record.get("serial", -1)) if not record.is_empty() else -1


func _entity_root_error(record: Dictionary, slot: PokemonSlot) -> String:
	var current_root_serial := _slot_root_card_serial(slot)
	if current_root_serial < 0:
		return "card_not_registered"
	if current_root_serial != int(record.get("root_card_serial", -1)):
		return "pokemon_entity_root_changed"
	return ""


func _has_active_entity_for_root(root_card_serial: int) -> bool:
	if root_card_serial <= 0:
		return false
	_sweep_dead_records(_entity_records, _entity_audit_by_serial, STATE_RETIRED)
	for record: Dictionary in _entity_records:
		if (
			record.get("state") == STATE_ACTIVE
			and int(record.get("root_card_serial", -1)) == root_card_serial
		):
			return true
	return false


func _match_scope_error(expected_match_generation: Variant) -> String:
	if not _open:
		return "stale_match_generation"
	if typeof(expected_match_generation) != TYPE_INT:
		return "stale_match_generation"
	if int(expected_match_generation) != _match_generation:
		return "stale_match_generation"
	return ""


func _take_card_serial() -> int:
	if _next_card_serial <= 0 or _next_card_serial > MAX_SAFE_INTEGER:
		return -1
	var serial := _next_card_serial
	_next_card_serial += 1
	return serial


func _take_entity_serial() -> int:
	if _next_entity_serial <= 0 or _next_entity_serial > MAX_SAFE_INTEGER:
		return -1
	var serial := _next_entity_serial
	_next_entity_serial += 1
	return serial


func _card_record(card: CardInstance) -> Dictionary:
	return _record_for_object(
		_card_records,
		_card_audit_by_serial,
		card,
		STATE_RELEASED
	)


func _entity_record(slot: PokemonSlot) -> Dictionary:
	return _record_for_object(
		_entity_records,
		_entity_audit_by_serial,
		slot,
		STATE_RETIRED
	)


func _record_for_object(
	records: Array[Dictionary],
	audit_by_serial: Dictionary,
	object: Object,
	dead_state: String
) -> Dictionary:
	if object == null or not is_instance_valid(object):
		return {}
	for index: int in range(records.size() - 1, -1, -1):
		var record: Dictionary = records[index]
		var raw_weak: Variant = record.get("object_ref", null)
		var referenced: Variant = (
			(raw_weak as WeakRef).get_ref() if raw_weak is WeakRef else null
		)
		if referenced == object:
			return record
		if referenced == null:
			var serial := int(record.get("serial", -1))
			var metadata: Dictionary = audit_by_serial.get(serial, {})
			if not metadata.is_empty() and metadata.get("state") not in [STATE_RETIRED, STATE_RELEASED, STATE_CLOSED]:
				metadata["state"] = dead_state
			records.remove_at(index)
	return {}


func _store_object_record(records: Array[Dictionary], record: Dictionary) -> void:
	records.append(record)


func _sweep_dead_records(
	records: Array[Dictionary],
	audit_by_serial: Dictionary,
	dead_state: String
) -> int:
	var changed := 0
	for index: int in range(records.size() - 1, -1, -1):
		var record: Dictionary = records[index]
		var raw_weak: Variant = record.get("object_ref", null)
		var referenced: Variant = (
			(raw_weak as WeakRef).get_ref() if raw_weak is WeakRef else null
		)
		if referenced != null:
			continue
		var serial := int(record.get("serial", -1))
		var metadata: Dictionary = audit_by_serial.get(serial, {})
		if not metadata.is_empty() and metadata.get("state") not in [STATE_RETIRED, STATE_RELEASED, STATE_CLOSED]:
			metadata["state"] = dead_state
			changed += 1
		records.remove_at(index)
	return changed


func _audit_records_in_serial_order(audit_by_serial: Dictionary) -> Array:
	var serials: Array = audit_by_serial.keys()
	serials.sort()
	var output: Array = []
	for raw_serial: Variant in serials:
		var record: Dictionary = audit_by_serial[raw_serial]
		output.append(record.duplicate(true))
	return output


func _audit_record(domain: String, serial: int, player_index: int, state: String) -> Dictionary:
	return {
		"domain": domain,
		"serial": serial,
		"player_index": player_index,
		"match_generation": _match_generation,
		"state": state,
	}


func _success(domain: String, serial: int, player_index: int) -> Dictionary:
	return {
		"ok": true,
		"code": "ok",
		"domain": domain,
		"serial": serial,
		"player_index": player_index,
		"match_generation": _match_generation,
	}


func _success_without_serial(domain: String) -> Dictionary:
	return {
		"ok": true,
		"code": "ok",
		"domain": domain,
		"serial": null,
		"player_index": null,
		"match_generation": _match_generation,
	}


func _error(domain: String, code: String) -> Dictionary:
	var safe_code := code if code in ERROR_CODES else "internal_error"
	return {
		"ok": false,
		"code": safe_code,
		"domain": domain,
		"serial": null,
		"player_index": null,
		"match_generation": _match_generation,
	}


func _is_card_reference(value: Variant) -> bool:
	return value is CardInstance and is_instance_valid(value)


func _is_pokemon_reference(value: Variant) -> bool:
	return value is PokemonSlot and is_instance_valid(value)


func _is_player_index(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and int(value) in [0, 1]


func _is_optional_player_index(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and int(value) in [-1, 0, 1]


func _is_inventory_counts(value: Variant) -> bool:
	if not (value is Array) or (value as Array).size() != 2:
		return false
	for count: Variant in value:
		if typeof(count) != TYPE_INT or int(count) <= 0 or int(count) > MAX_SAFE_INTEGER:
			return false
	return true
