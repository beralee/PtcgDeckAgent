class_name CabtSelectionSanitizer
extends RefCounted

const CabtSelectionWindowScript = preload(
	"res://scripts/ai/ptcgdap/cabt/CabtSelectionWindow.gd"
)
const CabtDeterministicFallbackScript = preload(
	"res://scripts/ai/ptcgdap/cabt/CabtDeterministicFallback.gd"
)
const POLICY_OUTCOMES := ["returned", "exception", "timeout", "unavailable"]
static var _RESULT_FACTORY_TOKEN: RefCounted = RefCounted.new()
static var _RESULT_REGISTRY: Dictionary = {}


class SelectionValidation extends RefCounted:
	var _accepted := false
	var _selected_indexes: Array = []
	var _reason_code := ""
	var _window_binding: Variant = null
	var _factory_token: Variant = null
	var _public_snapshot: Dictionary = {}

	var accepted: bool:
		get:
			return _accepted

	var selected_indexes: Array:
		get:
			return _selected_indexes.duplicate(true)

	var reason_code: String:
		get:
			return _reason_code

	func _init(
		accepted_value: bool = false,
		indexes_value: Array = [],
		reason_value: String = "",
		window_value: Variant = null,
		factory_token: Variant = null,
		public_snapshot: Dictionary = {}
	) -> void:
		_accepted = accepted_value
		_selected_indexes = indexes_value.duplicate(true)
		_reason_code = reason_value
		_window_binding = window_value
		_factory_token = factory_token
		_public_snapshot = public_snapshot

	func to_dict() -> Dictionary:
		var owner_script: GDScript = load(
			"res://scripts/ai/ptcgdap/cabt/CabtSelectionSanitizer.gd"
		)
		return owner_script.call("_registered_public_snapshot", self)

	func to_public_dict() -> Dictionary:
		return to_dict()


static func _new_validation(
	accepted_value: bool,
	indexes_value: Array,
	reason_value: String,
	window: Variant
) -> SelectionValidation:
	var public_value := {
		"accepted": accepted_value,
		"selected_indexes": indexes_value.duplicate(true),
		"reason_code": reason_value,
	}
	var snapshot: Dictionary = _deep_read_only_copy(public_value)
	var result := SelectionValidation.new(
		accepted_value,
		indexes_value,
		reason_value,
		window,
		_RESULT_FACTORY_TOKEN,
		snapshot
	)
	_register_result(result, snapshot, window)
	return result


static func validate_result_integrity(value: Variant, window: Variant) -> bool:
	var registry_entry := _result_registry_entry(value)
	if (
		not value is SelectionValidation
		or registry_entry.is_empty()
		or value._factory_token != _RESULT_FACTORY_TOKEN
		or not _is_window(window)
		or value._window_binding != window
		or registry_entry.get("binding") != window
		or value._public_snapshot != registry_entry.get("snapshot")
		or typeof(value._public_snapshot) != TYPE_DICTIONARY
		or typeof(value._accepted) != TYPE_BOOL
		or typeof(value._selected_indexes) != TYPE_ARRAY
		or typeof(value._reason_code) != TYPE_STRING
	):
		return false
	var allowed_reasons := _reason_code_domain(window, "sanitize")
	if not allowed_reasons.has(value._reason_code):
		return false
	var live_public := {
		"accepted": value._accepted,
		"selected_indexes": value._selected_indexes.duplicate(true),
		"reason_code": value._reason_code,
	}
	if value._public_snapshot != live_public:
		return false
	if value._accepted:
		return (
			window.get("policy_allowed") == true
			and value._reason_code == "policy_selection_accepted"
			and _selection_indexes_are_legal(window, value._selected_indexes)
		)
	if not value._selected_indexes.is_empty():
		return false
	if window.get("policy_allowed") != true:
		return value._reason_code == "window_fallback_only"
	return value._reason_code in [
		"proposal_not_list",
		"proposal_index_not_exact_int",
		"proposal_cardinality",
		"proposal_index_out_of_range",
		"proposal_duplicate_index",
	]


static func validate(window: Variant, proposal: Variant) -> Variant:
	if not _is_window(window):
		return null
	if window.get("policy_allowed") != true:
		return _new_validation(false, [], "window_fallback_only", window)
	if typeof(proposal) != TYPE_ARRAY:
		return _new_validation(false, [], "proposal_not_list", window)
	var proposed_indexes: Array = proposal
	for index_value: Variant in proposed_indexes:
		if typeof(index_value) != TYPE_INT:
			return _new_validation(false, [], "proposal_index_not_exact_int", window)
	var proposal_size := proposed_indexes.size()
	if proposal_size < int(window.get("min_count")) or proposal_size > int(window.get("max_count")):
		return _new_validation(false, [], "proposal_cardinality", window)
	for index_value: Variant in proposed_indexes:
		var index := int(index_value)
		if index < 0 or index >= int(window.get("option_count")):
			return _new_validation(false, [], "proposal_index_out_of_range", window)
	var seen := {}
	for index_value: Variant in proposed_indexes:
		var index := int(index_value)
		if seen.has(index):
			return _new_validation(false, [], "proposal_duplicate_index", window)
		seen[index] = true
	return _new_validation(true, proposed_indexes, "policy_selection_accepted", window)


static func resolve_policy_attempt(window: Variant, attempt: Variant) -> Variant:
	if not _is_window(window):
		return CabtDeterministicFallbackScript.resolve(window, "policy_unavailable")
	if window.get("policy_allowed") != true:
		return CabtDeterministicFallbackScript.resolve(window, "window_fallback_only")
	var status := "unavailable"
	var output: Variant = null
	if typeof(attempt) == TYPE_DICTIONARY:
		var attempt_value: Dictionary = attempt
		var status_value: Variant = attempt_value.get("status")
		if typeof(status_value) == TYPE_STRING and POLICY_OUTCOMES.has(status_value):
			status = status_value
		output = attempt_value.get("output")
	if status == "returned":
		var validation: Variant = validate(window, output)
		if validation.get("accepted") == true:
			return CabtDeterministicFallbackScript.accept_policy(
				window,
				validation.get("selected_indexes")
			)
		return CabtDeterministicFallbackScript.resolve(window, "invalid_policy_output")
	return CabtDeterministicFallbackScript.resolve(window, "policy_%s" % status)


static func _is_window(value: Variant) -> bool:
	return (
		typeof(value) == TYPE_OBJECT
		and value != null
		and value.get_script() == CabtSelectionWindowScript
		and value.has_method("validate_integrity")
		and value.validate_integrity() == true
	)


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
