class_name A3ExternalDecisionPort
extends RefCounted

const TreeHashScript = preload("res://scripts/ai/ptcgdap/cabt/CabtTreeHash.gd")

const STATE_IDLE := "idle"
const STATE_WAITING := "waiting_selection"
const STATE_SUBMITTED := "selection_submitted"
const STATE_DELIVERED := "selection_delivered"
const STATE_FAULTED := "faulted"
const SELECTION_SOURCE := "a3_external_current_window"

var _state := STATE_IDLE
var _pending_frame: Dictionary = {}
var _pending_signature := ""
var _pending_handle := ""
var _submitted_indexes: Array[int] = []
var _fault_code := ""
var _fault_detail: Dictionary = {}


func validate_integrity() -> bool:
	if _state not in [STATE_IDLE, STATE_WAITING, STATE_SUBMITTED, STATE_DELIVERED, STATE_FAULTED]:
		return false
	if _state == STATE_IDLE:
		return _pending_frame.is_empty() and _pending_signature.is_empty() and _pending_handle.is_empty()
	if _state == STATE_FAULTED:
		return not _fault_code.is_empty()
	return (
		not _pending_frame.is_empty()
		and _upper_sha(_pending_signature)
		and _upper_sha(_pending_handle)
		and _fault_code.is_empty()
	)


func requires_competitive_frame_v2() -> bool:
	return true


func expected_selection_source() -> String:
	return SELECTION_SOURCE


func select(frame: Dictionary) -> Dictionary:
	if _state == STATE_FAULTED:
		return _error(_fault_code)
	var validated := _validated_frame(frame)
	if not bool(validated.get("ok", false)):
		return _fault(
			str(validated.get("error_code", "invalid_external_frame")),
			validated.get("failure_detail", {})
		)
	var signature := str(validated.get("signature", ""))
	if _state == STATE_IDLE:
		_pending_frame = frame.duplicate(true)
		_pending_signature = signature
		_pending_handle = str((frame.get("source", {}) as Dictionary).get("window_id", ""))
		_state = STATE_WAITING
		return _pending()
	if signature != _pending_signature:
		return _fault("external_window_changed")
	if _state == STATE_WAITING:
		return _pending()
	if _state == STATE_SUBMITTED:
		_state = STATE_DELIVERED
		var source: Dictionary = frame.get("source", {})
		return {
			"ok": true,
			"error_code": "",
			"decision_pending": false,
			"selected_indexes": _submitted_indexes.duplicate(),
			"selection_source": SELECTION_SOURCE,
			"public_observation_hash": source.get("public_observation_hash"),
			"window_id": source.get("window_id"),
		}
	return _fault("external_selection_already_delivered")


func pending_checkpoint() -> Dictionary:
	if _state != STATE_WAITING or not validate_integrity():
		return _error("external_checkpoint_unavailable")
	return {
		"ok": true,
		"error_code": "",
		"state": _state,
		"window_handle": _pending_handle,
		"semantic_window_hash": _pending_signature,
		"frame": _pending_frame.duplicate(true),
	}


func submit(window_handle: String, indexes: Variant) -> Dictionary:
	if _state != STATE_WAITING or not validate_integrity():
		return _error("external_window_not_waiting")
	if window_handle != _pending_handle:
		return _error("stale_external_window_handle")
	var semantics: Dictionary = _pending_frame.get("select_semantics", {})
	var options: Array = _pending_frame.get("options", [])
	var validated: Variant = _validated_indexes(
		indexes,
		options.size(),
		int(semantics.get("min_count", -1)),
		int(semantics.get("max_count", -1))
	)
	if validated == null:
		return _error("invalid_external_selection")
	_submitted_indexes = validated
	_state = STATE_SUBMITTED
	return {
		"ok": true,
		"error_code": "",
		"state": _state,
		"window_handle": _pending_handle,
		"semantic_window_hash": _pending_signature,
	}


func acknowledge_selection(frame: Dictionary, indexes: Array) -> bool:
	if _state != STATE_DELIVERED or not validate_integrity():
		return false
	var validated := _validated_frame(frame)
	if (
		not bool(validated.get("ok", false))
		or str(validated.get("signature", "")) != _pending_signature
		or indexes != _submitted_indexes
	):
		_fault("external_commit_ack_mismatch")
		return false
	_clear_window()
	return true


func cancel_pending(code: String = "external_window_cancelled") -> void:
	if _state != STATE_IDLE:
		_fault(code)


func audit_snapshot() -> Dictionary:
	return {
		"execution_location": "godot_headless_a3_external_decision_port",
		"state": _state,
		"fault_code": _fault_code,
		"fault_detail": _fault_detail.duplicate(true),
		"window_handle": _pending_handle,
		"semantic_window_hash": _pending_signature,
	}


func close() -> void:
	_clear_window()


func _validated_frame(frame: Variant) -> Dictionary:
	if not frame is Dictionary:
		return _error("invalid_external_frame")
	var source: Variant = frame.get("source")
	var semantics: Variant = frame.get("select_semantics")
	var options: Variant = frame.get("options")
	if (
		not source is Dictionary
		or not semantics is Dictionary
		or not options is Array
		or not _upper_sha(source.get("public_observation_hash"))
		or not _upper_sha(source.get("window_id"))
		or typeof(semantics.get("min_count")) != TYPE_INT
		or typeof(semantics.get("max_count")) != TYPE_INT
		or int(semantics.get("min_count")) < 0
		or int(semantics.get("max_count")) < int(semantics.get("min_count"))
		or int(semantics.get("max_count")) > options.size()
	):
		return _error("invalid_external_frame")
	for option_index: int in options.size():
		var option_value: Variant = options[option_index]
		if not option_value is Dictionary or not _valid_native_option_shape(option_value):
			return {
				"ok": false,
				"error_code": "invalid_external_frame",
				"failure_detail": {
					"surface": "option_shape",
					"option_index": option_index,
					"option_kind": str(option_value.get("kind", "")) \
						if option_value is Dictionary else "",
					"option_type_raw": option_value.get("option_type_raw") \
						if option_value is Dictionary else null,
				},
			}
	var stable := {
		"schema_version": frame.get("schema_version"),
		"profile_id": frame.get("profile_id"),
		"seat": frame.get("seat"),
		"prompt_kind": frame.get("prompt_kind"),
		"public_state": frame.get("public_state"),
		"select_semantics": semantics,
		"options": options,
	}
	var digest: Dictionary = TreeHashScript.public_observation_hash(stable)
	var signature := str(digest.get("sha256", ""))
	if not _upper_sha(signature):
		return _error("invalid_external_frame")
	return {"ok": true, "error_code": "", "signature": signature}


static func _validated_indexes(
	values: Variant,
	option_count: int,
	minimum: int,
	maximum: int
) -> Variant:
	if not values is Array or values.size() < minimum or values.size() > maximum:
		return null
	var result: Array[int] = []
	for value: Variant in values:
		if typeof(value) != TYPE_INT:
			return null
		var index := int(value)
		if index < 0 or index >= option_count or index in result:
			return null
		result.append(index)
	return result


static func _valid_native_option_shape(option: Dictionary) -> bool:
	var option_type: Variant = option.get("option_type_raw")
	if typeof(option_type) != TYPE_INT:
		return false
	match int(option_type):
		0:
			return typeof(option.get("option_number")) == TYPE_INT
		3:
			return _entity(option, "card") or _public_position(option)
		4, 5, 7, 11:
			return _entity(option, "card")
		6:
			return (
				_entity(option, "source")
				and typeof(option.get("energy_type_raw")) == TYPE_INT
				and int(option.get("energy_type_raw")) >= 0
				and int(option.get("energy_type_raw")) <= 11
				and typeof(option.get("energy_count")) == TYPE_INT
				and int(option.get("energy_count")) > 0
			)
		8, 9:
			return _entity(option, "card") and _entity(option, "target")
		10:
			return _entity(option, "source")
		13:
			return (
				typeof(option.get("source_uid")) == TYPE_STRING
				and not str(option.get("source_uid")).is_empty()
				and typeof(option.get("attack_index")) == TYPE_INT
				and int(option.get("attack_index")) >= 0
			)
		15:
			return (
				(option.get("card_uid") == null and option.get("card_serial") == null)
				or _entity(option, "card")
			)
		16:
			return (
				typeof(option.get("special_condition_type")) == TYPE_INT
				and int(option.get("special_condition_type")) >= 0
				and int(option.get("special_condition_type")) <= 4
			)
		1, 2, 12, 14:
			return true
		_:
			return false


static func _entity(option: Dictionary, prefix: String) -> bool:
	return (
		typeof(option.get(prefix + "_uid")) == TYPE_STRING
		and not str(option.get(prefix + "_uid")).is_empty()
		and typeof(option.get(prefix + "_serial")) == TYPE_INT
		and int(option.get(prefix + "_serial")) > 0
	)


static func _public_position(option: Dictionary) -> bool:
	return (
		typeof(option.get("option_area_raw")) == TYPE_INT
		and int(option.get("option_area_raw")) >= 0
		and int(option.get("option_area_raw")) <= 11
		and typeof(option.get("option_area_index")) == TYPE_INT
		and int(option.get("option_area_index")) >= 0
		and typeof(option.get("option_player_index")) == TYPE_INT
		and int(option.get("option_player_index")) in [0, 1]
	)


func _pending() -> Dictionary:
	return {
		"ok": false,
		"error_code": "decision_pending",
		"decision_pending": true,
		"window_handle": _pending_handle,
		"semantic_window_hash": _pending_signature,
	}


func _fault(code: String, detail: Dictionary = {}) -> Dictionary:
	_fault_code = code if not code.is_empty() else "external_decision_fault"
	_fault_detail = detail.duplicate(true)
	_state = STATE_FAULTED
	return _error(_fault_code)


func _clear_window() -> void:
	_state = STATE_IDLE
	_pending_frame.clear()
	_pending_signature = ""
	_pending_handle = ""
	_submitted_indexes.clear()
	_fault_code = ""
	_fault_detail.clear()


static func _error(code: String) -> Dictionary:
	return {"ok": false, "error_code": code}


static func _upper_sha(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or str(value).length() != 64 or str(value) != str(value).to_upper():
		return false
	for character: String in str(value):
		if character not in "0123456789ABCDEF":
			return false
	return true
