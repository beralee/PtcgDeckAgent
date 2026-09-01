class_name CabtDeckSelectionValidator
extends RefCounted

const CabtOptionFingerprintScript = preload(
	"res://scripts/ai/ptcgdap/cabt/CabtOptionFingerprint.gd"
)
const CabtContractSetScript = preload("res://scripts/ai/ptcgdap/cabt/CabtContractSet.gd")
const INITIAL_DECK_PROFILE := "cabt_initial_deck_v1"
const MANIFEST_KEYS := [
	"profile",
	"card_ids",
	"deck_hash",
	"source_artifact_id",
	"source_sha256",
	"authority_scope",
]
const POLICY_OUTCOMES := ["returned", "exception", "timeout", "unavailable"]
static var _AUTHORITY_FACTORY_TOKEN: RefCounted = RefCounted.new()
static var _RESULT_FACTORY_TOKEN: RefCounted = RefCounted.new()
static var _RESULT_REGISTRY: Dictionary = {}


class PinnedDeckAuthority extends RefCounted:
	var _profile := ""
	var _card_ids: Array = []
	var _deck_hash := ""
	var _source_artifact_id := ""
	var _source_sha256 := ""
	var _authority_scope := ""
	var _trusted_factory_instance := false
	var _factory_token: Variant = null
	var _contracts: Variant = null
	var _contract_source_hash := ""

	var profile: String:
		get:
			return _profile

	var card_ids: Array:
		get:
			return _card_ids.duplicate(true)

	var deck_hash: String:
		get:
			return _deck_hash

	var source_artifact_id: String:
		get:
			return _source_artifact_id

	var source_sha256: String:
		get:
			return _source_sha256

	var authority_scope: String:
		get:
			return _authority_scope

	func _init(
		value: Dictionary = {},
		factory_token: Variant = null,
		contracts: Variant = null
	) -> void:
		_factory_token = factory_token
		_contracts = contracts
		if factory_token == null or typeof(contracts) != TYPE_OBJECT or contracts == null:
			return
		_trusted_factory_instance = true
		_contract_source_hash = str(contracts.get("source_contract_hash"))
		_profile = str(value.get("profile", ""))
		_card_ids = (value.get("card_ids", []) as Array).duplicate(true)
		_deck_hash = str(value.get("deck_hash", ""))
		_source_artifact_id = str(value.get("source_artifact_id", ""))
		_source_sha256 = str(value.get("source_sha256", ""))
		_authority_scope = str(value.get("authority_scope", ""))

	func to_dict() -> Dictionary:
		return {
			"profile": _profile,
			"card_ids": _card_ids.duplicate(true),
			"deck_hash": _deck_hash,
			"source_artifact_id": _source_artifact_id,
			"source_sha256": _source_sha256,
			"authority_scope": _authority_scope,
		}

	func to_public_dict() -> Dictionary:
		return to_dict()


class DeckBuildResult extends RefCounted:
	var _accepted := false
	var _reason_code := "invalid_pinned_deck"
	var _pinned_deck: Variant = null
	var _contracts: Variant = null
	var _factory_token: Variant = null
	var _public_snapshot: Dictionary = {}

	var accepted: bool:
		get:
			return _accepted

	var reason_code: String:
		get:
			return _reason_code

	var pinned_deck: Variant:
		get:
			return _pinned_deck

	func _init(
		accepted_value: bool = false,
		reason_value: String = "invalid_pinned_deck",
		pinned_value: Variant = null,
		contracts: Variant = null,
		factory_token: Variant = null,
		public_snapshot: Dictionary = {}
	) -> void:
		_accepted = accepted_value
		_reason_code = reason_value
		_pinned_deck = pinned_value
		_contracts = contracts
		_factory_token = factory_token
		_public_snapshot = public_snapshot

	func to_dict() -> Dictionary:
		var owner_script: GDScript = load(
			"res://scripts/ai/ptcgdap/cabt/CabtDeckSelectionValidator.gd"
		)
		return owner_script.call("_registered_public_snapshot", self)

	func to_public_dict() -> Dictionary:
		return to_dict()


class InitialDeckResolution extends RefCounted:
	var _accepted := false
	var _selected_card_ids: Array = []
	var _owner := "none"
	var _reason_code := "invalid_pinned_deck"
	var _fallback_branch: Variant = null
	var _deck_hash: Variant = null
	var _candidate_reason_code := "invalid_pinned_deck"
	var _authority_binding: Variant = null
	var _contracts: Variant = null
	var _factory_token: Variant = null
	var _public_snapshot: Dictionary = {}

	var accepted: bool:
		get:
			return _accepted

	var selected_card_ids: Array:
		get:
			return _selected_card_ids.duplicate(true)

	var owner: String:
		get:
			return _owner

	var reason_code: String:
		get:
			return _reason_code

	var fallback_branch: Variant:
		get:
			return _fallback_branch

	var deck_hash: Variant:
		get:
			return _deck_hash

	var candidate_reason_code: String:
		get:
			return _candidate_reason_code

	func _init(
		accepted_value: bool = false,
		selected_value: Array = [],
		owner_value: String = "none",
		reason_value: String = "invalid_pinned_deck",
		branch_value: Variant = null,
		hash_value: Variant = null,
		candidate_reason_value: String = "invalid_pinned_deck",
		authority_value: Variant = null,
		contracts: Variant = null,
		factory_token: Variant = null,
		public_snapshot: Dictionary = {}
	) -> void:
		_accepted = accepted_value
		_selected_card_ids = selected_value.duplicate(true)
		_owner = owner_value
		_reason_code = reason_value
		_fallback_branch = branch_value
		_deck_hash = hash_value
		_candidate_reason_code = candidate_reason_value
		_authority_binding = authority_value
		_contracts = contracts
		_factory_token = factory_token
		_public_snapshot = public_snapshot

	func to_dict() -> Dictionary:
		var owner_script: GDScript = load(
			"res://scripts/ai/ptcgdap/cabt/CabtDeckSelectionValidator.gd"
		)
		return owner_script.call("_registered_public_snapshot", self)

	func to_public_dict() -> Dictionary:
		return to_dict()


static func _new_deck_build_result(
	accepted_value: bool,
	reason_value: String,
	pinned_value: Variant,
	contracts: Variant
) -> DeckBuildResult:
	var public_value := {
		"accepted": accepted_value,
		"reason_code": reason_value,
		"pinned_deck": null if pinned_value == null else pinned_value.to_dict(),
	}
	var snapshot: Dictionary = _deep_read_only_copy(public_value)
	var result := DeckBuildResult.new(
		accepted_value,
		reason_value,
		pinned_value,
		contracts,
		_RESULT_FACTORY_TOKEN,
		snapshot
	)
	_register_result(result, snapshot, contracts)
	return result


static func _new_initial_resolution(
	accepted_value: bool,
	selected_value: Array,
	owner_value: String,
	reason_value: String,
	branch_value: Variant,
	hash_value: Variant,
	candidate_reason_value: String,
	contracts: Variant,
	authority: Variant
) -> InitialDeckResolution:
	var public_value := {
		"accepted": accepted_value,
		"selected_card_ids": selected_value.duplicate(true),
		"owner": owner_value,
		"reason_code": reason_value,
		"fallback_branch": branch_value,
		"deck_hash": hash_value,
		"candidate_reason_code": candidate_reason_value,
	}
	var snapshot: Dictionary = _deep_read_only_copy(public_value)
	var result := InitialDeckResolution.new(
		accepted_value,
		selected_value,
		owner_value,
		reason_value,
		branch_value,
		hash_value,
		candidate_reason_value,
		authority,
		contracts,
		_RESULT_FACTORY_TOKEN,
		snapshot
	)
	_register_result(result, snapshot, authority)
	return result


static func validate_build_result_integrity(value: Variant, contracts: Variant) -> bool:
	var registry_entry := _result_registry_entry(value)
	if (
		not value is DeckBuildResult
		or registry_entry.is_empty()
		or value._factory_token != _RESULT_FACTORY_TOKEN
		or value._contracts != contracts
		or registry_entry.get("binding") != contracts
		or value._public_snapshot != registry_entry.get("snapshot")
		or not _is_exact_contract_set(contracts)
		or typeof(value._public_snapshot) != TYPE_DICTIONARY
		or typeof(value._accepted) != TYPE_BOOL
		or typeof(value._reason_code) != TYPE_STRING
		or (
			value._pinned_deck != null
			and not value._pinned_deck is PinnedDeckAuthority
		)
	):
		return false
	var allowed_reasons := _reason_code_domain(contracts, "pinned_deck_build")
	if not allowed_reasons.has(value._reason_code):
		return false
	var live_public := {
		"accepted": value._accepted,
		"reason_code": value._reason_code,
		"pinned_deck": null if value._pinned_deck == null else value._pinned_deck.to_dict(),
	}
	if value._public_snapshot != live_public:
		return false
	if value._accepted:
		return (
			value._reason_code == "pinned_deck_accepted"
			and value._pinned_deck is PinnedDeckAuthority
			and _pinned_integrity(value._pinned_deck)
			and value._pinned_deck._contracts == contracts
		)
	return value._reason_code == "invalid_pinned_deck" and value._pinned_deck == null


static func validate_resolution_integrity(value: Variant, pinned_deck: Variant) -> bool:
	var registry_entry := _result_registry_entry(value)
	if (
		not value is InitialDeckResolution
		or registry_entry.is_empty()
		or value._factory_token != _RESULT_FACTORY_TOKEN
		or value._authority_binding != pinned_deck
		or registry_entry.get("binding") != pinned_deck
		or value._public_snapshot != registry_entry.get("snapshot")
		or not _is_exact_contract_set(value._contracts)
		or typeof(value._public_snapshot) != TYPE_DICTIONARY
		or typeof(value._accepted) != TYPE_BOOL
		or typeof(value._selected_card_ids) != TYPE_ARRAY
		or typeof(value._owner) != TYPE_STRING
		or typeof(value._reason_code) != TYPE_STRING
		or typeof(value._candidate_reason_code) != TYPE_STRING
	):
		return false
	var resolution_reasons := _reason_code_domain(value._contracts, "initial_deck_resolution")
	var candidate_reasons := _reason_code_domain(value._contracts, "initial_deck_candidate")
	if (
		not resolution_reasons.has(value._reason_code)
		or not candidate_reasons.has(value._candidate_reason_code)
	):
		return false
	var live_public := {
		"accepted": value._accepted,
		"selected_card_ids": value._selected_card_ids.duplicate(true),
		"owner": value._owner,
		"reason_code": value._reason_code,
		"fallback_branch": value._fallback_branch,
		"deck_hash": value._deck_hash,
		"candidate_reason_code": value._candidate_reason_code,
	}
	if value._public_snapshot != live_public:
		return false
	if not pinned_deck is PinnedDeckAuthority or not _pinned_integrity(pinned_deck):
		return live_public == {
			"accepted": false,
			"selected_card_ids": [],
			"owner": "none",
			"reason_code": "invalid_pinned_deck",
			"fallback_branch": null,
			"deck_hash": null,
			"candidate_reason_code": "invalid_pinned_deck",
		}
	var pinned: PinnedDeckAuthority = pinned_deck
	if (
		pinned._contracts != value._contracts
		or value._accepted != true
		or value._selected_card_ids != pinned._card_ids
		or value._deck_hash != pinned._deck_hash
	):
		return false
	if value._owner == "initial_candidate":
		return (
			value._reason_code == "pinned_deck_accepted"
			and value._candidate_reason_code == "pinned_deck_accepted"
			and value._fallback_branch == null
		)
	var fallback_candidate_reasons := candidate_reasons.duplicate()
	fallback_candidate_reasons.erase("pinned_deck_accepted")
	fallback_candidate_reasons.erase("invalid_pinned_deck")
	return (
		value._owner == "pinned_deck_fallback"
		and value._reason_code == "pinned_deck_fallback"
		and fallback_candidate_reasons.has(value._candidate_reason_code)
		and value._fallback_branch == "pinned_verified_deck"
	)


static func build_pinned_deck(manifest: Variant, contracts: Variant) -> Variant:
	var selection_profile := _selection_profile(contracts)
	if selection_profile.is_empty() or typeof(manifest) != TYPE_DICTIONARY:
		return _new_deck_build_result(false, "invalid_pinned_deck", null, contracts)
	var manifest_value: Dictionary = manifest
	if not _has_exact_string_keys(manifest_value, MANIFEST_KEYS):
		return _new_deck_build_result(false, "invalid_pinned_deck", null, contracts)
	var expected := _normative_authority(selection_profile)
	if expected.is_empty():
		return _new_deck_build_result(false, "invalid_pinned_deck", null, contracts)
	var bounds := _safe_integer_bounds(selection_profile)
	if bounds.is_empty():
		return _new_deck_build_result(false, "invalid_pinned_deck", null, contracts)
	var card_ids_value: Variant = manifest_value.get("card_ids")
	if not _valid_deck_ids(
		card_ids_value,
		int(bounds.get("minimum")),
		int(bounds.get("maximum"))
	):
		return _new_deck_build_result(false, "invalid_pinned_deck", null, contracts)
	for string_field: String in [
		"profile",
		"deck_hash",
		"source_artifact_id",
		"source_sha256",
		"authority_scope",
	]:
		if typeof(manifest_value.get(string_field)) != TYPE_STRING:
			return _new_deck_build_result(false, "invalid_pinned_deck", null, contracts)
	if manifest_value != expected:
		return _new_deck_build_result(false, "invalid_pinned_deck", null, contracts)
	var computed_hash: String = CabtOptionFingerprintScript.initial_deck_hash(
		selection_profile,
		card_ids_value
	)
	if computed_hash.is_empty() or computed_hash != manifest_value.get("deck_hash"):
		return _new_deck_build_result(false, "invalid_pinned_deck", null, contracts)
	var pinned := PinnedDeckAuthority.new(manifest_value, _AUTHORITY_FACTORY_TOKEN, contracts)
	return _new_deck_build_result(true, "pinned_deck_accepted", pinned, contracts)


static func resolve_initial_output(pinned_deck: Variant, attempt: Variant) -> Variant:
	var contracts: Variant = _resolution_contracts(pinned_deck)
	if not pinned_deck is PinnedDeckAuthority or not _pinned_integrity(pinned_deck):
		return _new_initial_resolution(
			false,
			[],
			"none",
			"invalid_pinned_deck",
			null,
			null,
			"invalid_pinned_deck",
			contracts,
			pinned_deck
		)
	var pinned: PinnedDeckAuthority = pinned_deck
	var pinned_ids: Array = pinned.card_ids
	if pinned_ids.size() != 60:
		return _new_initial_resolution(
			false,
			[],
			"none",
			"invalid_pinned_deck",
			null,
			null,
			"invalid_pinned_deck",
			contracts,
			pinned_deck
		)
	var status := "unavailable"
	var output: Variant = null
	if typeof(attempt) == TYPE_DICTIONARY:
		var attempt_value: Dictionary = attempt
		var status_value: Variant = attempt_value.get("status")
		if typeof(status_value) == TYPE_STRING and POLICY_OUTCOMES.has(status_value):
			status = status_value
		output = attempt_value.get("output")
	var candidate_reason := _candidate_reason(status, output, pinned)
	if candidate_reason == "pinned_deck_accepted":
		return _new_initial_resolution(
			true,
			(output as Array),
			"initial_candidate",
			"pinned_deck_accepted",
			null,
			pinned.deck_hash,
			candidate_reason,
			contracts,
			pinned_deck
		)
	return _new_initial_resolution(
		true,
		pinned_ids,
		"pinned_deck_fallback",
		"pinned_deck_fallback",
		"pinned_verified_deck",
		pinned.deck_hash,
		candidate_reason,
		contracts,
		pinned_deck
	)


static func _resolution_contracts(pinned_deck: Variant) -> Variant:
	if pinned_deck is PinnedDeckAuthority and _is_exact_contract_set(pinned_deck._contracts):
		return pinned_deck._contracts
	var contracts: Variant = CabtContractSetScript.load_default()
	return contracts if _is_exact_contract_set(contracts) else null


static func _candidate_reason(
	status: String,
	output: Variant,
	pinned: PinnedDeckAuthority
) -> String:
	if status == "exception":
		return "deck_exception"
	if status == "timeout":
		return "deck_timeout"
	if status != "returned":
		return "deck_unavailable"
	if typeof(output) != TYPE_ARRAY:
		return "deck_not_list"
	var candidate: Array = output
	if candidate.size() != 60:
		return "deck_cardinality"
	for card_id: Variant in candidate:
		if typeof(card_id) != TYPE_INT:
			return "deck_card_not_exact_int"
	var bounds := _safe_integer_bounds(_selection_profile(pinned._contracts))
	if bounds.is_empty():
		return "deck_card_not_positive"
	var maximum_safe := int(bounds.get("maximum"))
	for card_id: Variant in candidate:
		if int(card_id) < 1 or int(card_id) > maximum_safe:
			return "deck_card_not_positive"
	if candidate != pinned._card_ids:
		return "deck_mismatch"
	return "pinned_deck_accepted"


static func _selection_profile(contracts: Variant) -> Dictionary:
	if not _is_exact_contract_set(contracts):
		return {}
	var profile: Variant = contracts.get("selection_profile")
	return (profile as Dictionary).duplicate(true) if typeof(profile) == TYPE_DICTIONARY else {}


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


static func _pinned_integrity(pinned: PinnedDeckAuthority) -> bool:
	if (
		not pinned._trusted_factory_instance
		or pinned._factory_token != _AUTHORITY_FACTORY_TOKEN
		or not _is_exact_contract_set(pinned._contracts)
		or not _is_upper_sha256(pinned._contract_source_hash)
		or pinned._contracts.get("source_contract_hash") != pinned._contract_source_hash
	):
		return false
	var selection_profile := _selection_profile(pinned._contracts)
	var expected := _normative_authority(selection_profile)
	if expected.is_empty() or pinned.to_dict() != expected:
		return false
	var bounds := _safe_integer_bounds(selection_profile)
	if (
		bounds.is_empty()
		or not _valid_deck_ids(
			pinned._card_ids,
			int(bounds.get("minimum")),
			int(bounds.get("maximum"))
		)
	):
		return false
	var recomputed: String = CabtOptionFingerprintScript.initial_deck_hash(
		selection_profile,
		pinned._card_ids
	)
	return not recomputed.is_empty() and recomputed == pinned._deck_hash


static func _normative_authority(selection_profile: Dictionary) -> Dictionary:
	var initial_contract: Variant = selection_profile.get("initial_deck_contract")
	if typeof(initial_contract) != TYPE_DICTIONARY:
		return {}
	var authority_value: Variant = (initial_contract as Dictionary).get("conformance_authority")
	if typeof(authority_value) != TYPE_DICTIONARY:
		return {}
	var authority: Dictionary = authority_value
	if authority.get("local_mapping_claim") != false or authority.get("cabt_exportable_claim") != false:
		return {}
	var normalized_ids := _normalize_contract_ids(authority.get("card_ids"))
	if normalized_ids.size() != 60:
		return {}
	for required_field: String in ["artifact_id", "source_sha256", "scope", "deck_hash"]:
		if typeof(authority.get(required_field)) != TYPE_STRING:
			return {}
	return {
		"profile": INITIAL_DECK_PROFILE,
		"card_ids": normalized_ids,
		"deck_hash": authority.get("deck_hash"),
		"source_artifact_id": authority.get("artifact_id"),
		"source_sha256": authority.get("source_sha256"),
		"authority_scope": authority.get("scope"),
	}


static func _normalize_contract_ids(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	var normalized: Array = []
	for card_id: Variant in value:
		if typeof(card_id) not in [TYPE_INT, TYPE_FLOAT]:
			return []
		var numeric := float(card_id)
		if not is_finite(numeric) or numeric != floor(numeric):
			return []
		normalized.append(int(card_id))
	return normalized


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


static func _valid_deck_ids(value: Variant, minimum_safe: int, maximum_safe: int) -> bool:
	if typeof(value) != TYPE_ARRAY or (value as Array).size() != 60:
		return false
	for card_id: Variant in value:
		if (
			typeof(card_id) != TYPE_INT
			or int(card_id) < 1
			or int(card_id) < minimum_safe
			or int(card_id) > maximum_safe
		):
			return false
	return true


static func _has_exact_string_keys(value: Dictionary, expected_keys: Array) -> bool:
	if value.size() != expected_keys.size():
		return false
	for key_value: Variant in value.keys():
		if typeof(key_value) != TYPE_STRING or not expected_keys.has(key_value):
			return false
	for expected_key: String in expected_keys:
		if not value.has(expected_key):
			return false
	return true


static func _is_upper_sha256(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or (value as String).length() != 64:
		return false
	for index: int in (value as String).length():
		if (value as String).substr(index, 1) not in "0123456789ABCDEF":
			return false
	return true


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
