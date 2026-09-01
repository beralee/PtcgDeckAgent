class_name CabtDeterministicFallback
extends RefCounted

const CabtSelectionWindowScript = preload(
	"res://scripts/ai/ptcgdap/cabt/CabtSelectionWindow.gd"
)
const ALLOWED_REASON_CODES := [
	"window_fallback_only",
	"invalid_policy_output",
	"policy_exception",
	"policy_timeout",
	"policy_unavailable",
]
static var _RESULT_FACTORY_TOKEN: RefCounted = RefCounted.new()
static var _RESULT_REGISTRY: Dictionary = {}


class SelectionResolution extends RefCounted:
	var _accepted := false
	var _window_id := ""
	var _selected_indexes: Array = []
	var _owner := "none"
	var _reason_code := ""
	var _fallback_branch: Variant = null
	var _window_binding: Variant = null
	var _factory_token: Variant = null
	var _public_snapshot: Dictionary = {}

	var accepted: bool:
		get:
			return _accepted

	var window_id: String:
		get:
			return _window_id

	var selected_indexes: Array:
		get:
			return _selected_indexes.duplicate(true)

	var owner: String:
		get:
			return _owner

	var reason_code: String:
		get:
			return _reason_code

	var fallback_branch: Variant:
		get:
			return _fallback_branch

	func _init(
		accepted_value: bool = false,
		window_id_value: String = "",
		indexes_value: Array = [],
		owner_value: String = "none",
		reason_value: String = "",
		branch_value: Variant = null,
		window_value: Variant = null,
		factory_token: Variant = null,
		public_snapshot: Dictionary = {}
	) -> void:
		_accepted = accepted_value
		_window_id = window_id_value
		_selected_indexes = indexes_value.duplicate(true)
		_owner = owner_value
		_reason_code = reason_value
		_fallback_branch = branch_value
		_window_binding = window_value
		_factory_token = factory_token
		_public_snapshot = public_snapshot

	func to_dict() -> Dictionary:
		var owner_script: GDScript = load(
			"res://scripts/ai/ptcgdap/cabt/CabtDeterministicFallback.gd"
		)
		return owner_script.call("_registered_public_snapshot", self)

	func to_public_dict() -> Dictionary:
		return to_dict()


static func _new_resolution(
	accepted_value: bool,
	window_id_value: String,
	indexes_value: Array,
	owner_value: String,
	reason_value: String,
	branch_value: Variant,
	window: Variant
) -> SelectionResolution:
	var public_value := {
		"accepted": accepted_value,
		"window_id": window_id_value,
		"selected_indexes": indexes_value.duplicate(true),
		"owner": owner_value,
		"reason_code": reason_value,
		"fallback_branch": branch_value,
	}
	var snapshot: Dictionary = _deep_read_only_copy(public_value)
	var result := SelectionResolution.new(
		accepted_value,
		window_id_value,
		indexes_value,
		owner_value,
		reason_value,
		branch_value,
		window,
		_RESULT_FACTORY_TOKEN,
		snapshot
	)
	_register_result(result, snapshot, window)
	return result


static func validate_resolution_integrity(value: Variant, window: Variant) -> bool:
	var registry_entry := _result_registry_entry(value)
	if (
		not value is SelectionResolution
		or registry_entry.is_empty()
		or value._factory_token != _RESULT_FACTORY_TOKEN
		or not _is_window(window)
		or value._window_binding != window
		or registry_entry.get("binding") != window
		or value._public_snapshot != registry_entry.get("snapshot")
		or typeof(value._public_snapshot) != TYPE_DICTIONARY
		or value._accepted != true
		or typeof(value._window_id) != TYPE_STRING
		or value._window_id != window.get("window_id")
		or typeof(value._selected_indexes) != TYPE_ARRAY
		or typeof(value._owner) != TYPE_STRING
		or typeof(value._reason_code) != TYPE_STRING
		or not _selection_indexes_are_legal(window, value._selected_indexes)
	):
		return false
	var allowed_reasons := _reason_code_domain(window, "resolution")
	if not allowed_reasons.has(value._reason_code):
		return false
	var live_public := {
		"accepted": value._accepted,
		"window_id": value._window_id,
		"selected_indexes": value._selected_indexes.duplicate(true),
		"owner": value._owner,
		"reason_code": value._reason_code,
		"fallback_branch": value._fallback_branch,
	}
	if value._public_snapshot != live_public:
		return false
	if value._owner == "policy":
		return (
			window.get("policy_allowed") == true
			and value._reason_code == "policy_selection_accepted"
			and value._fallback_branch == null
		)
	if value._owner != "deterministic_fallback" or not ALLOWED_REASON_CODES.has(value._reason_code):
		return false
	var expected := _fallback_selection(window)
	return (
		value._selected_indexes == expected.get("indexes")
		and value._fallback_branch == expected.get("branch")
	)


static func resolve(window: Variant, trigger_code: Variant) -> Variant:
	if not _is_window(window):
		return null
	var reason := "policy_unavailable"
	if typeof(trigger_code) == TYPE_STRING and ALLOWED_REASON_CODES.has(trigger_code):
		reason = trigger_code
	var indexes: Array = []
	var branch := "first_minimum"
	if int(window.get("min_count")) == 0:
		branch = "optional_zero"
	elif (
		int(window.get("min_count")) == int(window.get("max_count"))
		and int(window.get("max_count")) == int(window.get("option_count"))
	):
		branch = "forced_all"
		for index: int in int(window.get("option_count")):
			indexes.append(index)
	else:
		for index: int in int(window.get("min_count")):
			indexes.append(index)
	return _new_resolution(
		true,
		str(window.get("window_id")),
		indexes,
		"deterministic_fallback",
		reason,
		branch,
		window
	)


static func accept_policy(window: Variant, selected_indexes: Variant) -> Variant:
	if not _is_window(window) or typeof(selected_indexes) != TYPE_ARRAY:
		return null
	if window.get("policy_allowed") != true:
		return null
	var proposed: Array = selected_indexes
	for index_value: Variant in proposed:
		if typeof(index_value) != TYPE_INT:
			return null
	if proposed.size() < int(window.get("min_count")) or proposed.size() > int(window.get("max_count")):
		return null
	var seen := {}
	for index_value: Variant in proposed:
		var index := int(index_value)
		if index < 0 or index >= int(window.get("option_count")) or seen.has(index):
			return null
		seen[index] = true
	return _new_resolution(
		true,
		str(window.get("window_id")),
		proposed,
		"policy",
		"policy_selection_accepted",
		null,
		window
	)


static func _is_window(value: Variant) -> bool:
	return (
		typeof(value) == TYPE_OBJECT
		and value != null
		and value.get_script() == CabtSelectionWindowScript
		and value.has_method("validate_integrity")
		and value.validate_integrity() == true
	)


static func _fallback_selection(window: Variant) -> Dictionary:
	var indexes: Array = []
	var branch := "first_minimum"
	if int(window.get("min_count")) == 0:
		branch = "optional_zero"
	elif (
		int(window.get("min_count")) == int(window.get("max_count"))
		and int(window.get("max_count")) == int(window.get("option_count"))
	):
		branch = "forced_all"
		for index: int in int(window.get("option_count")):
			indexes.append(index)
	else:
		for index: int in int(window.get("min_count")):
			indexes.append(index)
	return {"indexes": indexes, "branch": branch}


static func _selection_indexes_are_legal(window: Variant, indexes: Array) -> bool:
	if indexes.size() < int(window.get("min_count")) or indexes.size() > int(window.get("max_count")):
		return false
	var seen := {}
	for index_value: Variant in indexes:
		if typeof(index_value) != TYPE_INT:
			return false
		var index := int(index_value)
		if index < 0 or index >= int(window.get("option_count")) or seen.has(index):
			return false
		seen[index] = true
	return true


static func _reason_code_domain(window: Variant, domain: String) -> Array:
	var contracts: Variant = window.get("_contracts")
	if contracts == null or typeof(contracts) != TYPE_OBJECT:
		return []
	var profile_value: Variant = contracts.get("selection_profile")
	if typeof(profile_value) != TYPE_DICTIONARY:
		return []
	var reason_codes_value: Variant = (profile_value as Dictionary).get("reason_codes")
	if typeof(reason_codes_value) != TYPE_DICTIONARY:
		return []
	var domain_value: Variant = (reason_codes_value as Dictionary).get(domain)
	if typeof(domain_value) != TYPE_ARRAY:
		return []
	var result: Array = []
	for code_value: Variant in domain_value:
		if typeof(code_value) != TYPE_STRING or result.has(code_value):
			return []
		result.append(code_value)
	return result


static func _register_result(
	value: RefCounted,
	public_snapshot: Dictionary,
	window: Variant
) -> void:
	_prune_result_registry()
	_RESULT_REGISTRY[value.get_instance_id()] = {
		"weak": weakref(value),
		"snapshot": public_snapshot,
		"binding": window,
	}


static func _result_registry_entry(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_OBJECT or value == null:
		return {}
	var instance_id: int = value.get_instance_id()
	var entry_value: Variant = _RESULT_REGISTRY.get(instance_id)
	if typeof(entry_value) != TYPE_DICTIONARY:
		return {}
	var entry: Dictionary = entry_value
	var weak_value: Variant = entry.get("weak")
	if typeof(weak_value) != TYPE_OBJECT or weak_value == null or weak_value.get_ref() != value:
		_RESULT_REGISTRY.erase(instance_id)
		return {}
	return entry


static func _registered_public_snapshot(value: Variant) -> Dictionary:
	var entry := _result_registry_entry(value)
	if entry.is_empty() or value.get("_factory_token") != _RESULT_FACTORY_TOKEN:
		return {}
	var snapshot_value: Variant = entry.get("snapshot")
	if typeof(snapshot_value) != TYPE_DICTIONARY:
		return {}
	return (snapshot_value as Dictionary).duplicate(true)


static func _prune_result_registry() -> void:
	if _RESULT_REGISTRY.size() < 256:
		return
	for instance_id: Variant in _RESULT_REGISTRY.keys():
		var entry_value: Variant = _RESULT_REGISTRY.get(instance_id)
		if typeof(entry_value) != TYPE_DICTIONARY:
			_RESULT_REGISTRY.erase(instance_id)
			continue
		var weak_value: Variant = (entry_value as Dictionary).get("weak")
		if typeof(weak_value) != TYPE_OBJECT or weak_value == null or weak_value.get_ref() == null:
			_RESULT_REGISTRY.erase(instance_id)


static func _deep_read_only_copy(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY:
		var copied_dictionary: Dictionary = {}
		for key_value: Variant in (value as Dictionary).keys():
			copied_dictionary[key_value] = _deep_read_only_copy((value as Dictionary)[key_value])
		copied_dictionary.make_read_only()
		return copied_dictionary
	if typeof(value) == TYPE_ARRAY:
		var copied_array: Array = []
		for child_value: Variant in value:
			copied_array.append(_deep_read_only_copy(child_value))
		copied_array.make_read_only()
		return copied_array
	return value
