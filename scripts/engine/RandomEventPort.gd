## Single audited owner for battle-semantic randomness.
class_name RandomEventPort
extends RefCounted

const JsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")

const MODE_LIVE := "live"
const MODE_SEEDED := "seeded-development"
const MODE_TAPE := "conditioned-tape"

var _rng := RandomNumberGenerator.new()
var _mode := MODE_LIVE
var _owner_generation := 1
var _event_ordinal := 0
var _events: Array[Dictionary] = []
var _tape: Array[Dictionary] = []
var _tape_cursor := 0
var _fault_code := ""
var _context_stack: Array[Dictionary] = []


func _init() -> void:
	_rng.randomize()


func configure_seed(seed_value: int, owner_generation: int = 1) -> void:
	_rng.seed = seed_value
	_mode = MODE_SEEDED
	_owner_generation = maxi(1, owner_generation)
	_event_ordinal = 0
	_events.clear()
	_tape.clear()
	_tape_cursor = 0
	_fault_code = ""
	_context_stack.clear()


func configure_tape(tape: Array, owner_generation: int = 1) -> bool:
	for value: Variant in tape:
		if (
			not value is Dictionary
			or str(value.get("event_kind", "")) not in ["coin", "shuffle"]
			or not _upper_sha(value.get("population_fingerprint"))
			or typeof(value.get("requested_count")) != TYPE_INT
			or int(value.get("requested_count")) < 0
			or not _upper_sha(value.get("source_context_fingerprint"))
		):
			return false
	_mode = MODE_TAPE
	_owner_generation = maxi(1, owner_generation)
	_event_ordinal = 0
	_events.clear()
	_tape = tape.duplicate(true)
	_tape_cursor = 0
	_fault_code = ""
	_context_stack.clear()
	return true


func legacy_rng() -> RandomNumberGenerator:
	return _rng


func push_context(metadata: Dictionary) -> int:
	_context_stack.append(metadata.duplicate(true))
	return _context_stack.size()


func pop_context(token: int) -> bool:
	if token <= 0 or token != _context_stack.size():
		_fail("random_event_context_stack_mismatch")
		return false
	_context_stack.pop_back()
	return true


func event_cursor() -> int:
	return _events.size()


func events_since(cursor: int) -> Array[Dictionary]:
	if cursor < 0 or cursor > _events.size():
		return []
	return _events.slice(cursor).duplicate(true)


func capability_snapshot() -> Dictionary:
	return {
		"mode": _mode,
		"owner_generation": _owner_generation,
		"event_count": _events.size(),
		"tape_cursor": _tape_cursor,
		"tape_size": _tape.size(),
		"fault_code": _fault_code,
	}


func coin(metadata: Dictionary = {}) -> bool:
	if not _fault_code.is_empty():
		return false
	var population_hash: String = _fingerprint([false, true])
	var resolved_metadata := _resolved_metadata(metadata, population_hash)
	var context_hash := _source_context_fingerprint(resolved_metadata)
	var outcome: bool
	if _mode == MODE_TAPE:
		var taped: Variant = _consume_tape("coin", population_hash, 1, context_hash)
		if taped == null or typeof(taped) != TYPE_BOOL:
			_fail("random_event_tape_mismatch")
			return false
		outcome = bool(taped)
	else:
		outcome = _rng.randi_range(0, 1) == 1
	_record("coin", resolved_metadata, population_hash, 1, outcome, [], context_hash)
	return outcome


func permutation(
	population: Array,
	metadata: Dictionary = {},
	seed_override: int = -1
) -> Array[int]:
	if not _fault_code.is_empty():
		return []
	var indexes: Array[int] = []
	for index: int in population.size():
		indexes.append(index)
	var population_hash: String = _fingerprint(population)
	var resolved_metadata := _resolved_metadata(metadata, population_hash)
	var context_hash := _source_context_fingerprint(resolved_metadata)
	if _mode == MODE_TAPE:
		var taped: Variant = _consume_tape(
			"shuffle", population_hash, population.size(), context_hash
		)
		if not taped is Array or not _valid_permutation(taped, population.size()):
			_fail("random_event_tape_mismatch")
			return []
		indexes.clear()
		for value: Variant in taped:
			indexes.append(int(value))
	else:
		var event_rng := _rng
		if seed_override >= 0:
			event_rng = RandomNumberGenerator.new()
			event_rng.seed = seed_override
		for index: int in range(indexes.size() - 1, 0, -1):
			var swap_index := event_rng.randi_range(0, index)
			var temporary := indexes[index]
			indexes[index] = indexes[swap_index]
			indexes[swap_index] = temporary
	_record(
		"shuffle", resolved_metadata, population_hash, population.size(), null, indexes, context_hash
	)
	return indexes


func _consume_tape(
	kind: String,
	population_hash: String,
	requested_count: int,
	context_hash: String
) -> Variant:
	if _tape_cursor >= _tape.size():
		return null
	var event: Dictionary = _tape[_tape_cursor]
	if (
		str(event.get("event_kind", "")) != kind
		or str(event.get("population_fingerprint", "")) != population_hash
		or int(event.get("requested_count", -1)) != requested_count
		or str(event.get("source_context_fingerprint", "")) != context_hash
	):
		return null
	_tape_cursor += 1
	return event.get("permutation") if kind == "shuffle" else event.get("outcome")


func _fail(code: String) -> void:
	_fault_code = code


func _record(
	kind: String,
	metadata: Dictionary,
	population_hash: String,
	requested_count: int,
	outcome: Variant,
	permutation_value: Array,
	context_hash: String
) -> void:
	var event := {
		"event_ordinal": _event_ordinal,
		"event_kind": kind,
		"acting_seat": int(metadata.get("acting_seat", -1)),
		"source_identity": str(metadata.get("source_identity", "unspecified")),
		"source_card_uid": str(metadata.get("source_card_uid", "")),
		"source_attack_ordinal": int(metadata.get("source_attack_ordinal", -1)),
		"source_ability_ordinal": int(metadata.get("source_ability_ordinal", -1)),
		"effect_id": str(metadata.get("effect_id", "")),
		"effect_phase": str(metadata.get("effect_phase", "unspecified")),
		"effect_implementation": str(metadata.get("effect_implementation", "")),
		"target_identity": str(metadata.get("target_identity", "")),
		"status_condition": str(metadata.get("status_condition", "")),
		"event_in_group": int(metadata.get("event_in_group", -1)),
		"source_context_fingerprint": context_hash,
		"population_fingerprint": population_hash,
		"requested_count": requested_count,
		"pre_state_hash": str(metadata.get("pre_state_hash", population_hash)),
		"owner_generation": _owner_generation,
		"outcome": outcome,
		"permutation": permutation_value.duplicate(),
	}
	_events.append(event)
	_event_ordinal += 1


func _resolved_metadata(metadata: Dictionary, population_hash: String) -> Dictionary:
	var result: Dictionary = {}
	for context: Dictionary in _context_stack:
		for key: Variant in context.keys():
			result[key] = context[key]
	for key: Variant in metadata.keys():
		result[key] = metadata[key]
	if str(result.get("source_identity", "")).is_empty():
		result["source_identity"] = "engine_random_event"
	if str(result.get("effect_phase", "")).is_empty():
		result["effect_phase"] = "engine_rule"
	if not _upper_sha(result.get("pre_state_hash")):
		result["pre_state_hash"] = population_hash
	return result


static func _source_context_fingerprint(metadata: Dictionary) -> String:
	return _fingerprint({
		"acting_seat": int(metadata.get("acting_seat", -1)),
		"source_identity": str(metadata.get("source_identity", "engine_random_event")),
		"source_card_uid": str(metadata.get("source_card_uid", "")),
		"source_attack_ordinal": int(metadata.get("source_attack_ordinal", -1)),
		"source_ability_ordinal": int(metadata.get("source_ability_ordinal", -1)),
		"effect_id": str(metadata.get("effect_id", "")),
		"effect_phase": str(metadata.get("effect_phase", "engine_rule")),
		"effect_implementation": str(metadata.get("effect_implementation", "")),
		"target_identity": str(metadata.get("target_identity", "")),
		"status_condition": str(metadata.get("status_condition", "")),
		"event_in_group": int(metadata.get("event_in_group", -1)),
		"pre_state_hash": str(metadata.get("pre_state_hash", "")),
	})


static func _valid_permutation(values: Array, size: int) -> bool:
	if values.size() != size:
		return false
	var seen: Dictionary = {}
	for value: Variant in values:
		if typeof(value) != TYPE_INT or int(value) < 0 or int(value) >= size or seen.has(int(value)):
			return false
		seen[int(value)] = true
	return true


static func _fingerprint(value: Variant) -> String:
	var canonical: Dictionary = JsonTreeScript.canonicalize(value)
	if not bool(canonical.get("ok", false)):
		return ""
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(canonical.get("bytes", PackedByteArray()))
	return context.finish().hex_encode().to_upper()


static func _upper_sha(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or str(value).length() != 64 or str(value) != str(value).to_upper():
		return false
	for character: String in str(value):
		if character not in "0123456789ABCDEF":
			return false
	return true
