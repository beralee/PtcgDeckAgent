class_name CabtSelectionWindow
extends RefCounted

const CabtOptionFingerprintScript = preload(
	"res://scripts/ai/ptcgdap/cabt/CabtOptionFingerprint.gd"
)
const CabtContractSetScript = preload("res://scripts/ai/ptcgdap/cabt/CabtContractSet.gd")
const WINDOW_VERSION := 1
const WINDOW_HASH_PROFILE := "cabt_selection_window_v1"
const OPTION_FINGERPRINT_PROFILE := "cabt_option_fingerprint_v1"
const BUILDER_KEYS := [
	"public_observation_hash",
	"public_hash_authority",
	"chooser_player_index",
	"select",
]
static var _FACTORY_TOKEN: RefCounted = RefCounted.new()
static var _RESULT_FACTORY_TOKEN: RefCounted = RefCounted.new()
static var _RESULT_REGISTRY: Dictionary = {}


class SelectionIssue extends RefCounted:
	var _code := ""
	var _pointer := ""
	var _factory_token: Variant = null
	var _public_snapshot: Dictionary = {}

	var code: String:
		get:
			return _code

	var pointer: String:
		get:
			return _pointer

	var severity: String:
		get:
			return "error"

	func _init(
		code_value: String = "",
		pointer_value: String = "",
		factory_token: Variant = null,
		public_snapshot: Dictionary = {}
	) -> void:
		_code = code_value
		_pointer = pointer_value
		_factory_token = factory_token
		_public_snapshot = public_snapshot

	func to_dict() -> Dictionary:
		var owner_script: GDScript = load(
			"res://scripts/ai/ptcgdap/cabt/CabtSelectionWindow.gd"
		)
		return owner_script.call("_registered_public_snapshot", self)

	func to_public_dict() -> Dictionary:
		return to_dict()


class BuildResult extends RefCounted:
	var _decision_state := "reject"
	var _window: Variant = null
	var _issues: Array = []
	var _contracts: Variant = null
	var _factory_token: Variant = null
	var _public_snapshot: Dictionary = {}

	var decision_state: String:
		get:
			return _decision_state

	var window: Variant:
		get:
			return _window

	var issues: Array:
		get:
			return _issues.duplicate()

	func _init(
		state_value: String = "reject",
		window_value: Variant = null,
		issues_value: Array = [],
		contracts: Variant = null,
		factory_token: Variant = null,
		public_snapshot: Dictionary = {}
	) -> void:
		_decision_state = state_value
		_window = window_value
		_issues = issues_value.duplicate()
		_contracts = contracts
		_factory_token = factory_token
		_public_snapshot = public_snapshot

	func to_dict() -> Dictionary:
		var owner_script: GDScript = load(
			"res://scripts/ai/ptcgdap/cabt/CabtSelectionWindow.gd"
		)
		return owner_script.call("_registered_public_snapshot", self)

	func to_public_dict() -> Dictionary:
		return to_dict()


var _window_id := ""
var _public_observation_hash := ""
var _public_hash_authority := ""
var _chooser_player_index := 0
var _decision_state := "fallback_only"
var _fallback_reasons: Array = []
var _select_type_raw := 0
var _select_context_raw := 0
var _min_count := 0
var _max_count := 0
var _remain_damage_counter := 0
var _remain_energy_cost := 0
var _context_card: Variant = null
var _effect: Variant = null
var _public_deck_candidates: Variant = null
var _options: Array = []
var _option_fingerprints: Array = []
var _select_payload: Dictionary = {}
var _trusted_factory_instance := false
var _contracts: Variant = null
var _contract_source_hash := ""
var _builder_input: Dictionary = {}

var window_version: int:
	get:
		return WINDOW_VERSION

var window_id: String:
	get:
		return _window_id

var hash_profile: String:
	get:
		return WINDOW_HASH_PROFILE

var option_fingerprint_profile: String:
	get:
		return OPTION_FINGERPRINT_PROFILE

var public_observation_hash: String:
	get:
		return _public_observation_hash

var public_hash_authority: String:
	get:
		return _public_hash_authority

var chooser_player_index: int:
	get:
		return _chooser_player_index

var decision_state: String:
	get:
		return _decision_state

var fallback_reasons: Array:
	get:
		return _fallback_reasons.duplicate(true)

var select_type_raw: int:
	get:
		return _select_type_raw

var select_context_raw: int:
	get:
		return _select_context_raw

var min_count: int:
	get:
		return _min_count

var max_count: int:
	get:
		return _max_count

var remain_damage_counter: int:
	get:
		return _remain_damage_counter

var remain_energy_cost: int:
	get:
		return _remain_energy_cost

var context_card: Variant:
	get:
		return _deep_copy_json(_context_card)

var effect: Variant:
	get:
		return _deep_copy_json(_effect)

var public_deck_candidates: Variant:
	get:
		return _deep_copy_json(_public_deck_candidates)

var options: Array:
	get:
		return _options.duplicate(true)

var option_fingerprints: Array:
	get:
		return _option_fingerprints.duplicate(true)

var option_count: int:
	get:
		return _options.size()

var policy_allowed: bool:
	get:
		return _decision_state == "policy_allowed"

var select_payload: Dictionary:
	get:
		return _select_payload.duplicate(true)


func _init(
	data: Dictionary = {},
	factory_token: Variant = null,
	contracts: Variant = null,
	builder_input: Dictionary = {}
) -> void:
	if factory_token != _FACTORY_TOKEN or not _is_exact_contract_set(contracts):
		return
	if data.is_empty() or builder_input.is_empty():
		return
	_trusted_factory_instance = true
	_contracts = contracts
	_contract_source_hash = str(contracts.get("source_contract_hash"))
	_builder_input = builder_input.duplicate(true)
	_window_id = str(data.get("window_id", ""))
	_public_observation_hash = str(data.get("public_observation_hash", ""))
	_public_hash_authority = str(data.get("public_hash_authority", ""))
	_chooser_player_index = int(data.get("chooser_player_index", 0))
	_decision_state = str(data.get("decision_state", "fallback_only"))
	_fallback_reasons = (data.get("fallback_reasons", []) as Array).duplicate(true)
	_select_type_raw = int(data.get("select_type_raw", 0))
	_select_context_raw = int(data.get("select_context_raw", 0))
	_min_count = int(data.get("min_count", 0))
	_max_count = int(data.get("max_count", 0))
	_remain_damage_counter = int(data.get("remain_damage_counter", 0))
	_remain_energy_cost = int(data.get("remain_energy_cost", 0))
	_context_card = _deep_copy_json(data.get("context_card"))
	_effect = _deep_copy_json(data.get("effect"))
	_public_deck_candidates = _deep_copy_json(data.get("public_deck_candidates"))
	_options = (data.get("options", []) as Array).duplicate(true)
	_option_fingerprints = (data.get("option_fingerprints", []) as Array).duplicate(true)
	_select_payload = (data.get("select_payload", {}) as Dictionary).duplicate(true)


func to_public_dict() -> Dictionary:
	return {
		"window_version": WINDOW_VERSION,
		"window_id": _window_id,
		"hash_profile": WINDOW_HASH_PROFILE,
		"option_fingerprint_profile": OPTION_FINGERPRINT_PROFILE,
		"public_observation_hash": _public_observation_hash,
		"public_hash_authority": _public_hash_authority,
		"chooser_player_index": _chooser_player_index,
		"decision_state": _decision_state,
		"fallback_reasons": _fallback_reasons.duplicate(true),
		"select_type_raw": _select_type_raw,
		"select_context_raw": _select_context_raw,
		"min_count": _min_count,
		"max_count": _max_count,
		"remain_damage_counter": _remain_damage_counter,
		"remain_energy_cost": _remain_energy_cost,
		"context_card": _deep_copy_json(_context_card),
		"effect": _deep_copy_json(_effect),
		"public_deck_candidates": _deep_copy_json(_public_deck_candidates),
		"options": _options.duplicate(true),
		"option_fingerprints": _option_fingerprints.duplicate(true),
	}


func to_dict() -> Dictionary:
	return to_public_dict()


func validate_integrity() -> bool:
	if (
		not _trusted_factory_instance
		or not _is_exact_contract_set(_contracts)
		or not _is_upper_sha256(_contract_source_hash)
		or _contracts.get("source_contract_hash") != _contract_source_hash
		or _builder_input.is_empty()
	):
		return false
	var window_script: GDScript = load("res://scripts/ai/ptcgdap/cabt/CabtSelectionWindow.gd")
	var rebuilt_result: Variant = window_script.build(_builder_input.duplicate(true), _contracts)
	if rebuilt_result == null or typeof(rebuilt_result) != TYPE_OBJECT:
		return false
	var rebuilt_window: Variant = rebuilt_result.get("window")
	if rebuilt_window == null or typeof(rebuilt_window) != TYPE_OBJECT:
		return false
	return rebuilt_window.to_public_dict() == to_public_dict()


static func _new_issue(code_value: String, pointer_value: String) -> SelectionIssue:
	var public_value := {
		"code": code_value,
		"pointer": pointer_value,
		"severity": "error",
	}
	var snapshot: Dictionary = _deep_read_only_copy(public_value)
	var result := SelectionIssue.new(
		code_value,
		pointer_value,
		_RESULT_FACTORY_TOKEN,
		snapshot
	)
	_register_result(result, snapshot, null)
	return result


static func _new_build_result(
	state_value: String,
	window_value: Variant,
	issues_value: Array,
	contracts: Variant
) -> BuildResult:
	var serialized_issues: Array = []
	for issue_value: Variant in issues_value:
		if typeof(issue_value) == TYPE_OBJECT and issue_value.has_method("to_dict"):
			serialized_issues.append(issue_value.to_dict())
	var public_value := {
		"decision_state": state_value,
		"window": null if window_value == null else window_value.to_public_dict(),
		"issues": serialized_issues,
	}
	var snapshot: Dictionary = _deep_read_only_copy(public_value)
	var result := BuildResult.new(
		state_value,
		window_value,
		issues_value,
		contracts,
		_RESULT_FACTORY_TOKEN,
		snapshot
	)
	_register_result(result, snapshot, contracts)
	return result


static func validate_issue_integrity(value: Variant) -> bool:
	var registry_entry := _result_registry_entry(value)
	if (
		not value is SelectionIssue
		or registry_entry.is_empty()
		or value._factory_token != _RESULT_FACTORY_TOKEN
		or registry_entry.get("binding") != null
		or value._public_snapshot != registry_entry.get("snapshot")
		or typeof(value._public_snapshot) != TYPE_DICTIONARY
		or typeof(value._code) != TYPE_STRING
		or typeof(value._pointer) != TYPE_STRING
		or not _build_issue_pointer_is_valid(value._code, value._pointer)
	):
		return false
	return value._public_snapshot == {
		"code": value._code,
		"pointer": value._pointer,
		"severity": "error",
	}


static func validate_build_result_integrity(value: Variant) -> bool:
	var registry_entry := _result_registry_entry(value)
	if (
		not value is BuildResult
		or registry_entry.is_empty()
		or value._factory_token != _RESULT_FACTORY_TOKEN
		or not _is_exact_contract_set(value._contracts)
		or registry_entry.get("binding") != value._contracts
		or value._public_snapshot != registry_entry.get("snapshot")
		or typeof(value._public_snapshot) != TYPE_DICTIONARY
		or typeof(value._decision_state) != TYPE_STRING
		or value._decision_state not in ["policy_allowed", "fallback_only", "reject"]
		or typeof(value._issues) != TYPE_ARRAY
		or (
			value._window != null
			and (
				typeof(value._window) != TYPE_OBJECT
				or not value._window.has_method("to_public_dict")
			)
		)
	):
		return false
	var live_issues: Array = []
	for issue_value: Variant in value._issues:
		if not validate_issue_integrity(issue_value):
			return false
		live_issues.append({
			"code": issue_value._code,
			"pointer": issue_value._pointer,
			"severity": "error",
		})
	var live_public := {
		"decision_state": value._decision_state,
		"window": null if value._window == null else value._window.to_public_dict(),
		"issues": live_issues,
	}
	if value._public_snapshot != live_public:
		return false
	var build_fallback := _reason_code_domain(value._contracts, "build_fallback")
	var build_reject := _reason_code_domain(value._contracts, "build_reject")
	if build_fallback.is_empty() or build_reject.is_empty():
		return false
	if value._decision_state == "reject":
		return (
			value._window == null
			and value._issues.size() == 1
			and build_reject.has(value._issues[0]._code)
		)
	var window_script: GDScript = load("res://scripts/ai/ptcgdap/cabt/CabtSelectionWindow.gd")
	if (
		typeof(value._window) != TYPE_OBJECT
		or value._window == null
		or value._window.get_script() != window_script
		or not value._window.has_method("validate_integrity")
		or value._window.validate_integrity() != true
		or value._window.get("decision_state") != value._decision_state
	):
		return false
	if value._decision_state == "policy_allowed":
		return value._issues.is_empty() and (value._window.get("fallback_reasons") as Array).is_empty()
	if value._issues.is_empty():
		return false
	var ordered_unique_codes: Array = []
	for issue_value: Variant in value._issues:
		if not build_fallback.has(issue_value._code):
			return false
		if not ordered_unique_codes.has(issue_value._code):
			ordered_unique_codes.append(issue_value._code)
	return ordered_unique_codes == value._window.get("fallback_reasons")


static func _register_result(
	value: RefCounted,
	public_snapshot: Dictionary,
	binding: Variant
) -> void:
	_prune_result_registry()
	_RESULT_REGISTRY[value.get_instance_id()] = {
		"weak": weakref(value),
		"snapshot": public_snapshot,
		"binding": binding,
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


static func build(input_value: Variant, contracts: Variant) -> Variant:
	var contract_data := _contract_data(contracts)
	if contract_data.is_empty():
		return _reject("invalid_select_field_type", "", contracts)
	if typeof(input_value) != TYPE_DICTIONARY:
		return _reject("select_not_object", "", contracts)
	var input: Dictionary = input_value
	if not _has_only_string_keys_from(input, BUILDER_KEYS):
		return _reject("unknown_public_key", "", contracts)
	for required_key: String in BUILDER_KEYS:
		if not input.has(required_key):
			return _reject("missing_select_field", "", contracts)

	var selection_profile: Dictionary = contract_data.get("selection_profile", {})
	var option_shapes: Dictionary = contract_data.get("option_shapes", {})
	var enum_snapshot: Dictionary = contract_data.get("enum_snapshot", {})
	var bounds := _safe_integer_bounds(selection_profile)
	if bounds.is_empty():
		return _reject("invalid_select_field_type", "", contracts)
	var minimum_safe := int(bounds.get("minimum"))
	var maximum_safe := int(bounds.get("maximum"))

	var input_authority: Dictionary = selection_profile.get("input_authority", {})
	var authority_value: Variant = input.get("public_hash_authority")
	var accepted_authorities: Variant = input_authority.get("accepted_public_hash_authorities")
	if (
		typeof(authority_value) != TYPE_STRING
		or typeof(accepted_authorities) != TYPE_ARRAY
		or not (accepted_authorities as Array).has(authority_value)
	):
		return _reject("public_hash_authority_required", "", contracts)
	var public_hash_value: Variant = input.get("public_observation_hash")
	if not _is_upper_sha256(public_hash_value):
		return _reject("invalid_public_observation_hash", "", contracts)
	var chooser_value: Variant = input.get("chooser_player_index")
	if (
		not _is_exact_safe_int(chooser_value, minimum_safe, maximum_safe)
		or int(chooser_value) not in [0, 1]
	):
		return _reject("invalid_chooser_player_index", "", contracts)
	var select_value: Variant = input.get("select")
	if typeof(select_value) != TYPE_DICTIONARY:
		return _reject("select_not_object", "/select", contracts)
	var select_payload: Dictionary = select_value
	var select_contract: Dictionary = selection_profile.get("select_contract", {})
	var required_select_keys: Variant = select_contract.get("required_keys")
	if typeof(required_select_keys) != TYPE_ARRAY:
		return _reject("invalid_select_field_type", "/select", contracts)
	if not _has_only_string_keys_from(select_payload, required_select_keys):
		return _reject("unknown_public_key", "/select", contracts)
	for key_value: Variant in required_select_keys:
		if typeof(key_value) != TYPE_STRING or not select_payload.has(key_value):
			return _reject("missing_select_field", "/select", contracts)

	var raw_integer_keys: Variant = select_contract.get("raw_integer_keys")
	if typeof(raw_integer_keys) != TYPE_ARRAY:
		return _reject("invalid_select_field_type", "/select", contracts)
	for key_value: Variant in raw_integer_keys:
		if typeof(key_value) != TYPE_STRING:
			return _reject("invalid_select_field_type", "/select", contracts)
		var field_name: String = key_value
		if not _is_exact_safe_int(select_payload.get(field_name), minimum_safe, maximum_safe):
			return _reject("invalid_select_field_type", "/select/%s" % field_name, contracts)

	var options_value: Variant = select_payload.get("option")
	if typeof(options_value) != TYPE_ARRAY:
		return _reject("invalid_select_field_type", "/select/option", contracts)
	var options_input: Array = options_value
	var min_count_value := int(select_payload.get("minCount"))
	var max_count_value := int(select_payload.get("maxCount"))
	if not (0 <= min_count_value and min_count_value <= max_count_value and max_count_value <= options_input.size()):
		return _reject("invalid_cardinality", "/select", contracts)

	var deck_result := _copy_deck(
		select_payload.get("deck"),
		select_contract,
		minimum_safe,
		maximum_safe
	)
	if not bool(deck_result.get("ok", false)):
		return _new_build_result("reject", null, [deck_result.get("issue")], contracts)
	var context_result := _copy_nullable_card(
		select_payload.get("contextCard"),
		"/select/contextCard",
		select_contract,
		minimum_safe,
		maximum_safe
	)
	if not bool(context_result.get("ok", false)):
		return _new_build_result("reject", null, [context_result.get("issue")], contracts)
	var effect_result := _copy_nullable_card(
		select_payload.get("effect"),
		"/select/effect",
		select_contract,
		minimum_safe,
		maximum_safe
	)
	if not bool(effect_result.get("ok", false)):
		return _new_build_result("reject", null, [effect_result.get("issue")], contracts)

	var fallback_issues: Array = []
	var select_type_value := int(select_payload.get("type"))
	var select_context_value := int(select_payload.get("context"))
	if not _enum_has_value(enum_snapshot, "SelectType", select_type_value):
		fallback_issues.append(_new_issue("unknown_select_type", "/select/type"))
	if not _enum_has_value(enum_snapshot, "SelectContext", select_context_value):
		fallback_issues.append(_new_issue("unknown_select_context", "/select/context"))
	var copied_options: Array = []
	for option_index: int in options_input.size():
		var option_result := _copy_option(
			options_input[option_index],
			"/select/option/%d" % option_index,
			selection_profile,
			option_shapes,
			enum_snapshot,
			minimum_safe,
			maximum_safe
		)
		if not bool(option_result.get("ok", false)):
			return _new_build_result("reject", null, [option_result.get("issue")], contracts)
		copied_options.append(option_result.get("value"))
		fallback_issues.append_array(option_result.get("fallback_issues", []))

	var copied_select := {
		"type": select_type_value,
		"context": select_context_value,
		"minCount": min_count_value,
		"maxCount": max_count_value,
		"remainDamageCounter": int(select_payload.get("remainDamageCounter")),
		"remainEnergyCost": int(select_payload.get("remainEnergyCost")),
		"option": copied_options,
		"deck": _deep_copy_json(deck_result.get("value")),
		"contextCard": _deep_copy_json(context_result.get("value")),
		"effect": _deep_copy_json(effect_result.get("value")),
	}
	var public_hash: String = public_hash_value
	var chooser_player_index_value := int(chooser_value)
	var window_id_value: String = CabtOptionFingerprintScript.window_id(
		selection_profile,
		chooser_player_index_value,
		public_hash,
		copied_select
	)
	if window_id_value.is_empty():
		return _reject("invalid_select_field_type", "/select", contracts)
	var fingerprints: Array = []
	for option_index: int in copied_options.size():
		var fingerprint: String = CabtOptionFingerprintScript.option_fingerprint(
			selection_profile,
			window_id_value,
			public_hash,
			option_index,
			select_type_value,
			select_context_value,
			copied_options[option_index],
			context_result.get("value"),
			effect_result.get("value")
		)
		if fingerprint.is_empty():
			return _reject("invalid_select_field_type", "/select", contracts)
		fingerprints.append(fingerprint)

	var fallback_reasons: Array = []
	for issue_value: Variant in fallback_issues:
		if typeof(issue_value) == TYPE_OBJECT:
			var code_value: Variant = issue_value.get("code")
			if typeof(code_value) == TYPE_STRING and not fallback_reasons.has(code_value):
				fallback_reasons.append(code_value)
	var state := "fallback_only" if not fallback_reasons.is_empty() else "policy_allowed"
	var window_script: GDScript = load("res://scripts/ai/ptcgdap/cabt/CabtSelectionWindow.gd")
	var window: RefCounted = window_script.new({
		"window_id": window_id_value,
		"public_observation_hash": public_hash,
		"public_hash_authority": authority_value,
		"chooser_player_index": chooser_player_index_value,
		"decision_state": state,
		"fallback_reasons": fallback_reasons,
		"select_type_raw": select_type_value,
		"select_context_raw": select_context_value,
		"min_count": min_count_value,
		"max_count": max_count_value,
		"remain_damage_counter": int(select_payload.get("remainDamageCounter")),
		"remain_energy_cost": int(select_payload.get("remainEnergyCost")),
		"context_card": context_result.get("value"),
		"effect": effect_result.get("value"),
		"public_deck_candidates": deck_result.get("value"),
		"options": copied_options,
		"option_fingerprints": fingerprints,
		"select_payload": copied_select,
	}, _FACTORY_TOKEN, contracts, input.duplicate(true))
	return _new_build_result(state, window, fallback_issues, contracts)


static func _contract_data(contracts: Variant) -> Dictionary:
	if not _is_exact_contract_set(contracts):
		return {}
	var selection_profile: Variant = contracts.get("selection_profile")
	var option_shapes: Variant = contracts.get("option_shapes")
	var enum_snapshot: Variant = contracts.get("enum_snapshot")
	if (
		typeof(selection_profile) != TYPE_DICTIONARY
		or typeof(option_shapes) != TYPE_DICTIONARY
		or typeof(enum_snapshot) != TYPE_DICTIONARY
	):
		return {}
	return {
		"selection_profile": (selection_profile as Dictionary).duplicate(true),
		"option_shapes": (option_shapes as Dictionary).duplicate(true),
		"enum_snapshot": (enum_snapshot as Dictionary).duplicate(true),
	}


static func _is_exact_contract_set(contracts: Variant) -> bool:
	return (
		typeof(contracts) == TYPE_OBJECT
		and contracts != null
		and contracts.get_script() == CabtContractSetScript
		and contracts.get("ok") == true
		and _is_upper_sha256(contracts.get("source_contract_hash"))
		and contracts.has_method("validate_integrity")
		and contracts.validate_integrity() == true
	)


static func _reject(
	code_value: String,
	pointer_value: String,
	contracts: Variant
) -> Variant:
	return _new_build_result(
		"reject",
		null,
		[_new_issue(code_value, pointer_value)],
		contracts
	)


static func _reason_code_domain(contracts: Variant, domain: String) -> Array:
	if not _is_exact_contract_set(contracts):
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


static func _regex_full_match(pattern: String, value: String) -> bool:
	var regex := RegEx.new()
	return regex.compile(pattern) == OK and regex.search(value) != null


static func _build_issue_pointer_is_valid(code_value: String, pointer_value: String) -> bool:
	var patterns: Dictionary = {
		"public_hash_authority_required": ["^$"],
		"invalid_public_observation_hash": ["^$"],
		"invalid_chooser_player_index": ["^$"],
		"select_not_object": ["^$", "^/select$"],
		"unknown_public_key": [
			"^$",
			"^/select$",
			"^/select/(?:contextCard|effect)$",
			"^/select/(?:deck|option)/(?:0|[1-9][0-9]*)$",
		],
		"missing_select_field": ["^$", "^/select$"],
		"invalid_select_field_type": [
			"^$",
			"^/select$",
			"^/select/(?:type|context|minCount|maxCount|remainDamageCounter|remainEnergyCost|option|deck)$",
		],
		"invalid_cardinality": ["^/select$"],
		"invalid_option": ["^/select/option/(?:0|[1-9][0-9]*)$"],
		"invalid_card": [
			"^/select/(?:contextCard|effect)$",
			"^/select/deck/(?:0|[1-9][0-9]*)$",
		],
		"unknown_select_type": ["^/select/type$"],
		"unknown_select_context": ["^/select/context$"],
		"unknown_option_type": ["^/select/option/(?:0|[1-9][0-9]*)/type$"],
		"unknown_option_enum": [
			"^/select/option/(?:0|[1-9][0-9]*)/(?:area|inPlayArea|specialConditionType)$",
		],
		"sparse_shape_mismatch": ["^/select/option/(?:0|[1-9][0-9]*)$"],
	}
	var selected_patterns: Variant = patterns.get(code_value)
	if typeof(selected_patterns) != TYPE_ARRAY:
		return false
	for pattern_value: Variant in selected_patterns:
		if typeof(pattern_value) == TYPE_STRING and _regex_full_match(pattern_value, pointer_value):
			return true
	return false


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


static func _safe_integer_bounds(selection_profile: Dictionary) -> Dictionary:
	var exact_types: Variant = selection_profile.get("exact_runtime_types")
	if typeof(exact_types) != TYPE_DICTIONARY:
		return {}
	var bounds: Variant = (exact_types as Dictionary).get("safe_integer_range")
	if typeof(bounds) != TYPE_DICTIONARY:
		return {}
	var minimum: Variant = (bounds as Dictionary).get("minimum")
	var maximum: Variant = (bounds as Dictionary).get("maximum")
	if typeof(minimum) not in [TYPE_INT, TYPE_FLOAT] or typeof(maximum) not in [TYPE_INT, TYPE_FLOAT]:
		return {}
	return {"minimum": int(minimum), "maximum": int(maximum)}


static func _is_exact_safe_int(value: Variant, minimum: int, maximum: int) -> bool:
	return typeof(value) == TYPE_INT and int(value) >= minimum and int(value) <= maximum


static func _is_upper_sha256(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or (value as String).length() != 64:
		return false
	for index: int in (value as String).length():
		if (value as String).substr(index, 1) not in "0123456789ABCDEF":
			return false
	return true


static func _has_only_string_keys_from(value: Dictionary, allowed_keys: Variant) -> bool:
	if typeof(allowed_keys) != TYPE_ARRAY:
		return false
	for key_value: Variant in value.keys():
		if typeof(key_value) != TYPE_STRING or not (allowed_keys as Array).has(key_value):
			return false
	return true


static func _copy_deck(
	value: Variant,
	select_contract: Dictionary,
	minimum_safe: int,
	maximum_safe: int
) -> Dictionary:
	if value == null:
		return {"ok": true, "value": null}
	if typeof(value) != TYPE_ARRAY:
		return {"ok": false, "issue": _new_issue("invalid_select_field_type", "/select/deck")}
	var copied: Array = []
	for index: int in (value as Array).size():
		var card_result := _copy_card(
			(value as Array)[index],
			"/select/deck/%d" % index,
			select_contract,
			minimum_safe,
			maximum_safe
		)
		if not bool(card_result.get("ok", false)):
			return card_result
		copied.append(card_result.get("value"))
	return {"ok": true, "value": copied}


static func _copy_nullable_card(
	value: Variant,
	pointer: String,
	select_contract: Dictionary,
	minimum_safe: int,
	maximum_safe: int
) -> Dictionary:
	if value == null:
		return {"ok": true, "value": null}
	return _copy_card(value, pointer, select_contract, minimum_safe, maximum_safe)


static func _copy_card(
	value: Variant,
	pointer: String,
	select_contract: Dictionary,
	minimum_safe: int,
	maximum_safe: int
) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {"ok": false, "issue": _new_issue("invalid_card", pointer)}
	var card: Dictionary = value
	var shape: Variant = select_contract.get("card_shape")
	if typeof(shape) != TYPE_DICTIONARY:
		return {"ok": false, "issue": _new_issue("invalid_card", pointer)}
	var required_keys: Variant = (shape as Dictionary).get("required_keys")
	if typeof(required_keys) != TYPE_ARRAY:
		return {"ok": false, "issue": _new_issue("invalid_card", pointer)}
	if not _has_only_string_keys_from(card, required_keys):
		return {"ok": false, "issue": _new_issue("unknown_public_key", pointer)}
	if card.size() != (required_keys as Array).size():
		return {"ok": false, "issue": _new_issue("invalid_card", pointer)}
	for key_value: Variant in required_keys:
		if typeof(key_value) != TYPE_STRING or not card.has(key_value):
			return {"ok": false, "issue": _new_issue("invalid_card", pointer)}
	var integer_keys: Variant = (shape as Dictionary).get("integer_keys")
	if typeof(integer_keys) != TYPE_ARRAY:
		return {"ok": false, "issue": _new_issue("invalid_card", pointer)}
	for key_value: Variant in integer_keys:
		if (
			typeof(key_value) != TYPE_STRING
			or not _is_exact_safe_int(card.get(key_value), minimum_safe, maximum_safe)
		):
			return {"ok": false, "issue": _new_issue("invalid_card", pointer)}
	if int(card.get("id")) < 1:
		return {"ok": false, "issue": _new_issue("invalid_card", pointer)}
	var player_values: Variant = (shape as Dictionary).get("player_index_values")
	if typeof(player_values) != TYPE_ARRAY or not _contract_int_array_has(player_values, int(card.get("playerIndex"))):
		return {"ok": false, "issue": _new_issue("invalid_card", pointer)}
	var copied := {}
	for key_value: Variant in required_keys:
		copied[key_value] = card.get(key_value)
	return {"ok": true, "value": copied}


static func _copy_option(
	value: Variant,
	pointer: String,
	selection_profile: Dictionary,
	option_shapes: Dictionary,
	enum_snapshot: Dictionary,
	minimum_safe: int,
	maximum_safe: int
) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {"ok": false, "issue": _new_issue("invalid_option", pointer)}
	var option: Dictionary = value
	var option_contract: Variant = selection_profile.get("option_contract")
	if typeof(option_contract) != TYPE_DICTIONARY:
		return {"ok": false, "issue": _new_issue("invalid_option", pointer)}
	var official_fields: Variant = (option_contract as Dictionary).get("official_field_order")
	if typeof(official_fields) != TYPE_ARRAY:
		return {"ok": false, "issue": _new_issue("invalid_option", pointer)}
	if not _has_only_string_keys_from(option, official_fields):
		return {"ok": false, "issue": _new_issue("unknown_public_key", pointer)}
	if not option.has("type") or not _is_exact_safe_int(option.get("type"), minimum_safe, maximum_safe):
		return {"ok": false, "issue": _new_issue("invalid_option", pointer)}
	var copied := {}
	for field_value: Variant in official_fields:
		if typeof(field_value) != TYPE_STRING or not option.has(field_value):
			continue
		var field_name: String = field_value
		var field_runtime_value: Variant = option.get(field_name)
		if field_name != "type" and field_runtime_value != null:
			if not _is_exact_safe_int(field_runtime_value, minimum_safe, maximum_safe):
				return {"ok": false, "issue": _new_issue("invalid_option", pointer)}
			if (
				field_name == "cardId"
				and int(field_runtime_value) < 1
				and not (
					int(option.get("type")) == 15
					and int(field_runtime_value) == 0
					and option.get("serial") == 0
				)
			):
				return {"ok": false, "issue": _new_issue("invalid_option", pointer)}
		copied[field_name] = field_runtime_value

	var fallback_issues: Array = []
	var raw_type := int(option.get("type"))
	var shapes_value: Variant = option_shapes.get("shapes")
	var expected_shape: Variant = null
	if typeof(shapes_value) == TYPE_DICTIONARY:
		expected_shape = (shapes_value as Dictionary).get(str(raw_type))
	if typeof(expected_shape) != TYPE_ARRAY:
		fallback_issues.append(_new_issue("unknown_option_type", "%s/type" % pointer))
	else:
		var sparse_mismatch := not _same_key_set(option, expected_shape)
		if not sparse_mismatch:
			for expected_field_value: Variant in expected_shape:
				if str(expected_field_value) != "type" and option.get(expected_field_value) == null:
					sparse_mismatch = true
					break
		if sparse_mismatch:
			fallback_issues.append(_new_issue("sparse_shape_mismatch", pointer))
	if raw_type == 15:
		var card_id: Variant = copied.get("cardId")
		var serial: Variant = copied.get("serial")
		var sentinel: bool = card_id == 0 and serial == 0
		var entity: bool = (
			typeof(card_id) == TYPE_INT
			and typeof(serial) == TYPE_INT
			and int(card_id) > 0
			and int(serial) > 0
		)
		if not sentinel and not entity:
			return {"ok": false, "issue": _new_issue("invalid_option", pointer)}

	var enum_locations: Variant = (option_contract as Dictionary).get("known_enum_locations")
	if typeof(enum_locations) == TYPE_DICTIONARY:
		for field_value: Variant in (enum_locations as Dictionary).keys():
			if typeof(field_value) != TYPE_STRING or field_value == "type" or not copied.has(field_value):
				continue
			var enum_value: Variant = copied.get(field_value)
			if enum_value == null:
				continue
			var enum_name_value: Variant = (enum_locations as Dictionary).get(field_value)
			if (
				typeof(enum_name_value) != TYPE_STRING
				or not _enum_has_value(enum_snapshot, enum_name_value, int(enum_value))
			):
				fallback_issues.append(
					_new_issue("unknown_option_enum", "%s/%s" % [pointer, field_value])
				)
	return {"ok": true, "value": copied, "fallback_issues": fallback_issues}


static func _same_key_set(value: Dictionary, expected_keys: Variant) -> bool:
	if typeof(expected_keys) != TYPE_ARRAY or value.size() != (expected_keys as Array).size():
		return false
	for key_value: Variant in expected_keys:
		if typeof(key_value) != TYPE_STRING or not value.has(key_value):
			return false
	return true


static func _enum_has_value(enum_snapshot: Dictionary, enum_name: String, raw_value: int) -> bool:
	var enums_value: Variant = enum_snapshot.get("enums")
	if typeof(enums_value) != TYPE_DICTIONARY:
		return false
	var enum_value: Variant = (enums_value as Dictionary).get(enum_name)
	if typeof(enum_value) != TYPE_DICTIONARY:
		return false
	for known_value: Variant in (enum_value as Dictionary).values():
		if typeof(known_value) in [TYPE_INT, TYPE_FLOAT] and int(known_value) == raw_value:
			return true
	return false


static func _contract_int_array_has(values: Variant, raw_value: int) -> bool:
	if typeof(values) != TYPE_ARRAY:
		return false
	for known_value: Variant in values:
		if typeof(known_value) in [TYPE_INT, TYPE_FLOAT] and int(known_value) == raw_value:
			return true
	return false


static func _deep_copy_json(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary).duplicate(true)
	if typeof(value) == TYPE_ARRAY:
		return (value as Array).duplicate(true)
	return value
