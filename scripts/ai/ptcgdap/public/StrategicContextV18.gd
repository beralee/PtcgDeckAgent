class_name StrategicContextV18ContractCore
extends RefCounted

const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")
const CabtSelectionWindowScript = preload(
	"res://scripts/ai/ptcgdap/cabt/CabtSelectionWindow.gd"
)
const CabtDeterministicFallbackScript = preload(
	"res://scripts/ai/ptcgdap/cabt/CabtDeterministicFallback.gd"
)
const PublicObservationFirewallScript = preload(
	"res://scripts/ai/ptcgdap/public/PublicObservationFirewall.gd"
)

const DEFAULT_ROOT := "res://contracts/ptcgdap"
const PROFILE_ID := "ptcgdap-strategic-context-v18-p4-wp1-v1"
const DECISION_PROFILE_ID := "ptcgdap-policy-decision-p4-wp1-v1"
const EXPECTED_BUNDLE_SHA256 := "AACFA7E2E7F914180A2B7A5C4D92D6514ACC5F4622FC95B57DC225673893F98F"
const EXPECTED_FIREWALL_BUNDLE_SHA256 := "A2781CE6B3AC7BB6BAD04A9F15F57CE23AEC338306F60E5B3050B31245685947"
const EXPECTED_SELECTION_BUNDLE_SHA256 := "2CD02F54538985426EFDB057F3A6BDA4AD154DD171BCC03667D42D102982D294"
const EXPECTED_SOURCE_LOCK_SHA256 := "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"
const EXPECTED_ARTIFACTS := {
	"schema": {
		"path": "contracts/ptcgdap/strategic_context_v18.schema.json",
		"canonical_sha256": "C355A905C25EF40D228BFA1B77B3080589DA62756E162A52B8D9CC286B8DCC0C",
	},
	"profile": {
		"path": "contracts/ptcgdap/strategic_context_v18_profile.json",
		"canonical_sha256": "76BB67D817D61FCAAA4CD6BA125E23F51330E94575F119653E8F364E69A720A2",
	},
	"vectors": {
		"path": "contracts/ptcgdap/strategic_context_v18_conformance_vectors.json",
		"canonical_sha256": "428B2466643B0F4341FC92BA5B2918650AA4974DB8ED1B41B77114DAFC29FCEA",
	},
}
const CONTEXT_PREFIX_UTF8_HEX := "50544347444150005354524154454749435F434F4E544558545F56313800"
const DECISION_PREFIX_UTF8_HEX := "5054434744415000504F4C4943595F4445434953494F4E5F41554449545F563100"
const MAX_CONTRACT_BYTES := 2 * 1024 * 1024
const MAX_CONTEXT_BYTES := 1024 * 1024
const CONTEXT_KEYS := [
	"schema_version",
	"profile_id",
	"context_hash",
	"source",
	"clocks",
	"public_state",
	"select_semantics",
	"opponent_public_belief",
	"public_event_delta",
	"provenance",
	"authority",
	"authoritative",
]
const DECISION_KEYS := [
	"schema_version",
	"profile_id",
	"selected_indexes",
	"selected_semantic_intent",
	"owner_layer",
	"reason_code",
	"fallback_tier",
	"context_hash",
	"policy_hash",
	"audit_id",
	"window_id",
	"public_observation_hash",
	"scene_id",
	"decision_id",
	"determinism_key",
	"authority",
	"authoritative",
]
const PRIVATE_KEYS := {
	"raw_private_hash": true,
	"token_free_callback_hash": true,
	"search_begin_input": true,
	"session": true,
	"callback": true,
	"binding": true,
	"ticket": true,
	"command": true,
	"object_ref": true,
	"pokemon_entity_serial": true,
}
const RESOLUTION_REASONS := {
	"policy_selection_accepted": true,
	"window_fallback_only": true,
	"invalid_policy_output": true,
	"policy_exception": true,
	"policy_timeout": true,
	"policy_unavailable": true,
}

static var _CONTEXT_TOKEN: RefCounted = RefCounted.new()
static var _DECISION_TOKEN: RefCounted = RefCounted.new()
static var _CONTEXT_REGISTRY: Dictionary = {}
static var _DECISION_REGISTRY: Dictionary = {}
static var _DEFAULT_CONTRACT_CACHE: Dictionary = {}


class BuildResult extends RefCounted:
	var accepted := false
	var error_code := "contract_error"
	var context: Variant = null
	var decision: Variant = null

	func _init(
		accepted_value: bool,
		error_value: String,
		context_value: Variant = null,
		decision_value: Variant = null,
	) -> void:
		accepted = accepted_value
		error_code = error_value
		context = context_value
		decision = decision_value


class ContextValue extends RefCounted:
	var _snapshot: Variant = {}
	var _factory_token: Variant = null
	var _firewall_binding: Variant = null
	var _window_binding: Variant = null

	var context_hash: String:
		get:
			return str(_snapshot.get("context_hash", "")) if _snapshot is Dictionary else ""

	var window_id: String:
		get:
			if not _snapshot is Dictionary:
				return ""
			var source_value: Variant = _snapshot.get("source")
			return str(source_value.get("window_id", "")) if source_value is Dictionary else ""

	func _init(
		snapshot_value: Dictionary = {},
		firewall_value: Variant = null,
		window_value: Variant = null,
		token_value: Variant = null,
	) -> void:
		_snapshot = snapshot_value.duplicate(true)
		_firewall_binding = firewall_value
		_window_binding = window_value
		_factory_token = token_value

	func validate_integrity() -> bool:
		var owner_script: GDScript = load(
			"res://scripts/ai/ptcgdap/public/StrategicContextV18.gd"
		)
		return bool(owner_script.call("validate_context", self))

	func to_public_dict() -> Dictionary:
		var owner_script: GDScript = load(
			"res://scripts/ai/ptcgdap/public/StrategicContextV18.gd"
		)
		return owner_script.call("context_public_dict", self)


class PolicyDecisionValue extends RefCounted:
	var _snapshot: Variant = {}
	var _factory_token: Variant = null
	var _context_binding: Variant = null
	var _window_binding: Variant = null
	var _resolution_binding: Variant = null

	var selected_indexes: Array:
		get:
			var value: Variant = _snapshot.get("selected_indexes", []) if _snapshot is Dictionary else []
			return value.duplicate(true) if value is Array else []

	var audit_id: String:
		get:
			return str(_snapshot.get("audit_id", "")) if _snapshot is Dictionary else ""

	func _init(
		snapshot_value: Dictionary = {},
		context_value: Variant = null,
		window_value: Variant = null,
		resolution_value: Variant = null,
		token_value: Variant = null,
	) -> void:
		_snapshot = snapshot_value.duplicate(true)
		_context_binding = context_value
		_window_binding = window_value
		_resolution_binding = resolution_value
		_factory_token = token_value

	func validate_integrity(context_value: Variant, window_value: Variant, resolution_value: Variant) -> bool:
		var owner_script: GDScript = load(
			"res://scripts/ai/ptcgdap/public/StrategicContextV18.gd"
		)
		return bool(owner_script.call(
			"validate_decision",
			self,
			context_value,
			window_value,
			resolution_value,
		))

	func to_public_dict() -> Dictionary:
		var owner_script: GDScript = load(
			"res://scripts/ai/ptcgdap/public/StrategicContextV18.gd"
		)
		return owner_script.call("decision_public_dict", self)

	func agent_output() -> Array:
		return selected_indexes if validate_integrity(
			_context_binding,
			_window_binding,
			_resolution_binding,
		) else []


static func build_context(
	firewall_result: Variant,
	window: Variant,
	contract_root: Variant = DEFAULT_ROOT,
) -> BuildResult:
	if typeof(contract_root) != TYPE_STRING or not _load_contracts(str(contract_root)).get("ok", false):
		return BuildResult.new(false, "contract_error")
	if not _firewall_result_valid(firewall_result, false):
		return BuildResult.new(false, "invalid_firewall_result")
	if not bool(firewall_result.get("accepted")):
		return BuildResult.new(false, "firewall_not_accepted")
	var public_value: Variant = firewall_result.get("public_observation")
	if not public_value is Dictionary:
		return BuildResult.new(false, "firewall_not_accepted")
	var public: Dictionary = public_value
	if public.get("select") == null or public.get("current") == null:
		return BuildResult.new(false, "unsupported_initial_window")
	if not _window_valid(window):
		return BuildResult.new(false, "invalid_window")
	if (
		window.get("public_hash_authority") != "firewall_accepted"
		or window.get("public_observation_hash") != firewall_result.get("public_observation_hash")
	):
		return BuildResult.new(false, "source_hash_mismatch")
	var current_value: Variant = public.get("current")
	if not current_value is Dictionary or window.get("chooser_player_index") != current_value.get("yourIndex"):
		return BuildResult.new(false, "chooser_mismatch")
	if window.get("select_payload") != public.get("select"):
		return BuildResult.new(false, "select_mismatch")
	var payload := _context_payload(firewall_result, window)
	if not _context_payload_valid(payload):
		return BuildResult.new(false, "context_integrity_invalid")
	var context := ContextValue.new(payload, firewall_result, window, _CONTEXT_TOKEN)
	_register_context(context, payload, firewall_result, window)
	return BuildResult.new(true, "", context)


static func build_policy_decision(
	context: Variant,
	window: Variant,
	resolution: Variant,
	policy_hash: Variant,
	scene_id: Variant,
	decision_id: Variant,
	determinism_key: Variant,
	contract_root: Variant = DEFAULT_ROOT,
) -> BuildResult:
	if typeof(contract_root) != TYPE_STRING or not _load_contracts(str(contract_root)).get("ok", false):
		return BuildResult.new(false, "contract_error")
	if not validate_context(context):
		return BuildResult.new(false, "invalid_context")
	if not _window_valid(window):
		return BuildResult.new(false, "invalid_context")
	var context_public := context_public_dict(context)
	if (
		context.get("window_id") != window.get("window_id")
		or context_public.get("source", {}).get("public_observation_hash") != window.get("public_observation_hash")
	):
		return BuildResult.new(false, "invalid_context")
	if not _resolution_valid(resolution, window):
		return BuildResult.new(false, "invalid_resolution")
	if not RESOLUTION_REASONS.has(resolution.get("reason_code")):
		return BuildResult.new(false, "invalid_resolution")
	if not _is_upper_sha256(policy_hash):
		return BuildResult.new(false, "invalid_policy_hash")
	if not _identifier(scene_id) or not _identifier(decision_id) or not _identifier(determinism_key):
		return BuildResult.new(false, "invalid_decision_identity")
	var payload := _decision_payload(
		context,
		window,
		resolution,
		str(policy_hash),
		str(scene_id),
		str(decision_id),
		str(determinism_key),
	)
	if payload.is_empty():
		return BuildResult.new(false, "decision_integrity_invalid")
	var decision := PolicyDecisionValue.new(
		payload,
		context,
		window,
		resolution,
		_DECISION_TOKEN,
	)
	_register_decision(decision, payload, context, window, resolution)
	return BuildResult.new(true, "", null, decision)


static func validate_context(value: Variant) -> bool:
	var entry := _registry_entry(_CONTEXT_REGISTRY, value)
	if (
		not value is ContextValue
		or entry.is_empty()
		or value.get("_factory_token") != _CONTEXT_TOKEN
		or entry.get("firewall") != value.get("_firewall_binding")
		or entry.get("window") != value.get("_window_binding")
		or not value.get("_snapshot") is Dictionary
		or value.get("_snapshot") != entry.get("snapshot")
	):
		return false
	var firewall_result: Variant = entry.get("firewall")
	var window: Variant = entry.get("window")
	if not _firewall_result_valid(firewall_result, true) or not _window_valid(window):
		return false
	var expected := _context_payload(firewall_result, window)
	return _context_payload_valid(expected) and value.get("_snapshot") == expected


static func context_public_dict(value: Variant) -> Dictionary:
	if not validate_context(value):
		return {}
	return (value.get("_snapshot") as Dictionary).duplicate(true)


static func validate_decision(
	value: Variant,
	context: Variant,
	window: Variant,
	resolution: Variant,
) -> bool:
	var entry := _registry_entry(_DECISION_REGISTRY, value)
	if (
		not value is PolicyDecisionValue
		or entry.is_empty()
		or value.get("_factory_token") != _DECISION_TOKEN
		or context != entry.get("context")
		or window != entry.get("window")
		or resolution != entry.get("resolution")
		or value.get("_context_binding") != context
		or value.get("_window_binding") != window
		or value.get("_resolution_binding") != resolution
		or not value.get("_snapshot") is Dictionary
		or value.get("_snapshot") != entry.get("snapshot")
		or not validate_context(context)
		or not _window_valid(window)
		or not _resolution_valid(resolution, window)
	):
		return false
	var public: Dictionary = value.get("_snapshot")
	if not _has_exact_keys(public, DECISION_KEYS) or _contains_private_key(public):
		return false
	if (
		public.get("schema_version") != 1
		or public.get("profile_id") != DECISION_PROFILE_ID
		or public.get("authority") != "policy_decision_public_audit"
		or public.get("authoritative") != false
		or not _is_upper_sha256(public.get("policy_hash"))
		or not _identifier(public.get("scene_id"))
		or not _identifier(public.get("decision_id"))
		or not _identifier(public.get("determinism_key"))
	):
		return false
	var expected := _decision_payload(
		context,
		window,
		resolution,
		str(public.get("policy_hash")),
		str(public.get("scene_id")),
		str(public.get("decision_id")),
		str(public.get("determinism_key")),
	)
	return not expected.is_empty() and public == expected


static func decision_public_dict(value: Variant) -> Dictionary:
	if not value is PolicyDecisionValue:
		return {}
	if not validate_decision(
		value,
		value.get("_context_binding"),
		value.get("_window_binding"),
		value.get("_resolution_binding"),
	):
		return {}
	return (value.get("_snapshot") as Dictionary).duplicate(true)


static func _context_payload(firewall_result: Variant, window: Variant) -> Dictionary:
	var public_value: Variant = firewall_result.get("public_observation")
	if not public_value is Dictionary:
		return {}
	var public: Dictionary = public_value
	var current_value: Variant = public.get("current")
	if not current_value is Dictionary:
		return {}
	var current: Dictionary = current_value
	var chooser_value: Variant = current.get("yourIndex")
	var players_value: Variant = current.get("players")
	if typeof(chooser_value) != TYPE_INT or int(chooser_value) not in [0, 1] or not players_value is Array or players_value.size() != 2:
		return {}
	var chooser := int(chooser_value)
	var opponent := 1 - chooser
	var players: Array = players_value
	if not players[chooser] is Dictionary or not players[opponent] is Dictionary:
		return {}
	var acting: Dictionary = players[chooser]
	var opposing: Dictionary = players[opponent]
	var fingerprints_value: Variant = window.get("option_fingerprints")
	var options_value: Variant = window.get("options")
	if not fingerprints_value is Array or not options_value is Array or fingerprints_value.size() != options_value.size():
		return {}
	var fingerprints: Array = fingerprints_value
	var options: Array = options_value
	var semantic_options: Array = []
	for index: int in options.size():
		semantic_options.append({
			"index": index,
			"fingerprint": fingerprints[index],
			"raw": _copy_json(options[index]),
		})
	var payload := {
		"schema_version": 1,
		"profile_id": PROFILE_ID,
		"source": {
			"public_observation_hash": firewall_result.get("public_observation_hash"),
			"window_id": window.get("window_id"),
			"chooser_player_index": chooser,
			"option_fingerprint_profile": window.get("option_fingerprint_profile"),
			"option_count": options.size(),
		},
		"clocks": {
			"turn": current.get("turn"),
			"turn_action_count": current.get("turnActionCount"),
			"remaining_overage_time": public.get("remainingOverageTime"),
			"acting_prizes_remaining": (acting.get("prize") as Array).size() if acting.get("prize") is Array else -1,
			"opponent_prizes_remaining": (opposing.get("prize") as Array).size() if opposing.get("prize") is Array else -1,
			"acting_deck_count": acting.get("deckCount"),
			"opponent_deck_count": opposing.get("deckCount"),
			"acting_hand_count": acting.get("handCount"),
			"opponent_hand_count": opposing.get("handCount"),
		},
		"public_state": {
			"turn_flags": {
				"first_player": current.get("firstPlayer"),
				"result": current.get("result"),
				"supporter_played": current.get("supporterPlayed"),
				"stadium_played": current.get("stadiumPlayed"),
				"energy_attached": current.get("energyAttached"),
				"retreated": current.get("retreated"),
			},
			"stadium": _copy_json(current.get("stadium")),
			"acting_player": _copy_json(acting),
			"opponent_player": _copy_json(opposing),
		},
		"select_semantics": {
			"select_type_raw": window.get("select_type_raw"),
			"select_context_raw": window.get("select_context_raw"),
			"min_count": window.get("min_count"),
			"max_count": window.get("max_count"),
			"remain_damage_counter": window.get("remain_damage_counter"),
			"remain_energy_cost": window.get("remain_energy_cost"),
			"context_card": _copy_json(window.get("context_card")),
			"effect": _copy_json(window.get("effect")),
			"options": semantic_options,
		},
		"opponent_public_belief": {
			"status": "unknown",
			"candidates": [],
			"public_evidence_ids": [],
		},
		"public_event_delta": _copy_json(public.get("logs")),
		"provenance": {
			"firewall_contract_hash": EXPECTED_FIREWALL_BUNDLE_SHA256,
			"records": _copy_json(firewall_result.get("provenance")),
		},
		"authority": "strategic_context_public_audit",
		"authoritative": false,
	}
	var context_hash := _domain_hash(CONTEXT_PREFIX_UTF8_HEX, payload)
	if context_hash.is_empty():
		return {}
	payload["context_hash"] = context_hash
	return payload


static func _context_payload_valid(value: Variant) -> bool:
	if not value is Dictionary or not _has_exact_keys(value, CONTEXT_KEYS) or _contains_private_key(value):
		return false
	var context: Dictionary = value
	if (
		context.get("schema_version") != 1
		or context.get("profile_id") != PROFILE_ID
		or context.get("authority") != "strategic_context_public_audit"
		or context.get("authoritative") != false
		or not _is_upper_sha256(context.get("context_hash"))
	):
		return false
	var source_value: Variant = context.get("source")
	var state_value: Variant = context.get("public_state")
	var semantics_value: Variant = context.get("select_semantics")
	if not source_value is Dictionary or not state_value is Dictionary or not semantics_value is Dictionary:
		return false
	var source: Dictionary = source_value
	var state: Dictionary = state_value
	var semantics: Dictionary = semantics_value
	if (
		not _is_upper_sha256(source.get("public_observation_hash"))
		or not _is_upper_sha256(source.get("window_id"))
		or typeof(source.get("chooser_player_index")) != TYPE_INT
		or int(source.get("chooser_player_index")) not in [0, 1]
		or source.get("option_fingerprint_profile") != "cabt_option_fingerprint_v1"
	):
		return false
	var acting_value: Variant = state.get("acting_player")
	var opponent_value: Variant = state.get("opponent_player")
	if not acting_value is Dictionary or not opponent_value is Dictionary:
		return false
	if not acting_value.get("hand") is Array or opponent_value.get("hand") != null:
		return false
	var options_value: Variant = semantics.get("options")
	if not options_value is Array or typeof(source.get("option_count")) != TYPE_INT or options_value.size() != int(source.get("option_count")):
		return false
	for index: int in options_value.size():
		var option_value: Variant = options_value[index]
		if (
			not option_value is Dictionary
			or not _has_exact_keys(option_value, ["index", "fingerprint", "raw"])
			or option_value.get("index") != index
			or not _is_upper_sha256(option_value.get("fingerprint"))
			or not option_value.get("raw") is Dictionary
		):
			return false
	var payload := context.duplicate(true)
	payload.erase("context_hash")
	var canonical := CabtJsonTreeScript.canonicalize(context, {"max_output_bytes": MAX_CONTEXT_BYTES})
	return (
		bool(canonical.get("ok", false))
		and canonical.get("bytes", PackedByteArray()).size() <= MAX_CONTEXT_BYTES
		and _domain_hash(CONTEXT_PREFIX_UTF8_HEX, payload) == context.get("context_hash")
	)


static func _decision_payload(
	context: Variant,
	window: Variant,
	resolution: Variant,
	policy_hash: String,
	scene_id: String,
	decision_id: String,
	determinism_key: String,
) -> Dictionary:
	var indexes_value: Variant = resolution.get("selected_indexes")
	var fingerprints_value: Variant = window.get("option_fingerprints")
	if not indexes_value is Array or not fingerprints_value is Array:
		return {}
	var indexes: Array = indexes_value
	var fingerprints: Array = fingerprints_value
	var intents: Array = []
	for index_value: Variant in indexes:
		if typeof(index_value) != TYPE_INT or int(index_value) < 0 or int(index_value) >= fingerprints.size():
			return {}
		intents.append({"index": int(index_value), "fingerprint": fingerprints[int(index_value)]})
	var owner := str(resolution.get("owner"))
	var payload := {
		"schema_version": 1,
		"profile_id": DECISION_PROFILE_ID,
		"selected_indexes": indexes.duplicate(true),
		"selected_semantic_intent": {
			"kind": "current_option_fingerprints",
			"options": intents,
		},
		"owner_layer": "base_graph" if owner == "policy" else "base_fallback",
		"reason_code": resolution.get("reason_code"),
		"fallback_tier": "none" if owner == "policy" else "same_public_window_deterministic",
		"context_hash": context.get("context_hash"),
		"policy_hash": policy_hash,
		"window_id": window.get("window_id"),
		"public_observation_hash": window.get("public_observation_hash"),
		"scene_id": scene_id,
		"decision_id": decision_id,
		"determinism_key": determinism_key,
		"authority": "policy_decision_public_audit",
		"authoritative": false,
	}
	var audit_id := _domain_hash(DECISION_PREFIX_UTF8_HEX, payload)
	if audit_id.is_empty():
		return {}
	payload["audit_id"] = audit_id
	return payload


static func _firewall_result_valid(value: Variant, require_accepted: bool) -> bool:
	if typeof(value) != TYPE_OBJECT or value == null:
		return false
	var owner: Variant = value.get("_owner")
	var bound: Variant = value.get("_bound_input")
	if (
		typeof(owner) != TYPE_OBJECT
		or owner == null
		or owner.get_script() != PublicObservationFirewallScript
		or not owner.has_method("validate_integrity")
		or owner.validate_integrity() != true
		or not owner.has_method("_validate_result")
		or not bool(owner._validate_result(value, bound))
	):
		return false
	return not require_accepted or bool(value.get("accepted"))


static func _window_valid(value: Variant) -> bool:
	return (
		typeof(value) == TYPE_OBJECT
		and value != null
		and value.get_script() == CabtSelectionWindowScript
		and value.has_method("validate_integrity")
		and value.validate_integrity() == true
	)


static func _resolution_valid(value: Variant, window: Variant) -> bool:
	return (
		typeof(value) == TYPE_OBJECT
		and value != null
		and _window_valid(window)
		and CabtDeterministicFallbackScript.validate_resolution_integrity(value, window)
		and value.get("owner") in ["policy", "deterministic_fallback"]
	)


static func _register_context(
	value: RefCounted,
	snapshot: Dictionary,
	firewall_result: Variant,
	window: Variant,
) -> void:
	_prune_registry(_CONTEXT_REGISTRY)
	_CONTEXT_REGISTRY[value.get_instance_id()] = {
		"weak": weakref(value),
		"snapshot": snapshot.duplicate(true),
		"firewall": firewall_result,
		"window": window,
	}


static func _register_decision(
	value: RefCounted,
	snapshot: Dictionary,
	context: Variant,
	window: Variant,
	resolution: Variant,
) -> void:
	_prune_registry(_DECISION_REGISTRY)
	_DECISION_REGISTRY[value.get_instance_id()] = {
		"weak": weakref(value),
		"snapshot": snapshot.duplicate(true),
		"context": context,
		"window": window,
		"resolution": resolution,
	}


static func _registry_entry(registry: Dictionary, value: Variant) -> Dictionary:
	if typeof(value) != TYPE_OBJECT or value == null:
		return {}
	var instance_id: int = value.get_instance_id()
	var entry_value: Variant = registry.get(instance_id)
	if not entry_value is Dictionary:
		return {}
	var weak_value: Variant = entry_value.get("weak")
	if typeof(weak_value) != TYPE_OBJECT or weak_value == null or weak_value.get_ref() != value:
		registry.erase(instance_id)
		return {}
	return entry_value


static func _prune_registry(registry: Dictionary) -> void:
	for instance_id: Variant in registry.keys():
		var entry_value: Variant = registry.get(instance_id)
		var weak_value: Variant = entry_value.get("weak") if entry_value is Dictionary else null
		if typeof(weak_value) != TYPE_OBJECT or weak_value == null or weak_value.get_ref() == null:
			registry.erase(instance_id)


static func _load_contracts(root_path: String) -> Dictionary:
	var root := root_path.trim_suffix("/")
	if root.is_empty():
		return {"ok": false}
	if root == DEFAULT_ROOT and bool(_DEFAULT_CONTRACT_CACHE.get("ok", false)):
		return _DEFAULT_CONTRACT_CACHE.duplicate(true)
	var bundle_bytes := _load_bytes("%s/strategic_context_v18_bundle.json" % root)
	if bundle_bytes.is_empty() or _canonical_artifact_sha256(bundle_bytes) != EXPECTED_BUNDLE_SHA256:
		return {"ok": false}
	var parsed := PublicObservationFirewallScript._parse_contract_json_bytes(bundle_bytes)
	var bundle_value: Variant = parsed.get("value") if bool(parsed.get("ok", false)) else null
	if not bundle_value is Dictionary or not _has_exact_keys(bundle_value, [
		"schema_version",
		"contract_id",
		"source_lock_canonical_sha256",
		"public_firewall_bundle_canonical_sha256",
		"selection_contract_bundle_canonical_sha256",
		"artifacts",
		"runtime_authority",
	]):
		return {"ok": false}
	var bundle: Dictionary = bundle_value
	if (
		bundle.get("schema_version") != 1
		or bundle.get("contract_id") != "ptcgdap-strategic-public-contract-p4-wp1-v1"
		or bundle.get("source_lock_canonical_sha256") != EXPECTED_SOURCE_LOCK_SHA256
		or bundle.get("public_firewall_bundle_canonical_sha256") != EXPECTED_FIREWALL_BUNDLE_SHA256
		or bundle.get("selection_contract_bundle_canonical_sha256") != EXPECTED_SELECTION_BUNDLE_SHA256
	):
		return {"ok": false}
	var artifacts_value: Variant = bundle.get("artifacts")
	if not artifacts_value is Array or artifacts_value.size() != EXPECTED_ARTIFACTS.size():
		return {"ok": false}
	var seen := {}
	var profile: Variant = null
	for entry_value: Variant in artifacts_value:
		if not entry_value is Dictionary or not _has_exact_keys(entry_value, ["id", "path", "canonical_sha256"]):
			return {"ok": false}
		var artifact_id: Variant = entry_value.get("id")
		if typeof(artifact_id) != TYPE_STRING or seen.has(artifact_id) or not EXPECTED_ARTIFACTS.has(artifact_id):
			return {"ok": false}
		var expected: Dictionary = EXPECTED_ARTIFACTS.get(artifact_id)
		if entry_value.get("path") != expected.get("path") or entry_value.get("canonical_sha256") != expected.get("canonical_sha256"):
			return {"ok": false}
		var bytes := _load_bytes("%s/%s" % [root, str(expected.get("path")).get_file()])
		if bytes.is_empty() or _canonical_artifact_sha256(bytes) != expected.get("canonical_sha256"):
			return {"ok": false}
		var document_result := PublicObservationFirewallScript._parse_contract_json_bytes(bytes)
		if not bool(document_result.get("ok", false)):
			return {"ok": false}
		if artifact_id == "profile":
			profile = document_result.get("value")
		seen[artifact_id] = true
	if seen.size() != EXPECTED_ARTIFACTS.size() or not profile is Dictionary:
		return {"ok": false}
	if (
		profile.get("profile_id") != PROFILE_ID
		or profile.get("decision_profile_id") != DECISION_PROFILE_ID
		or profile.get("hash_profiles", {}).get("strategic_context_v18", {}).get("prefix_utf8_hex") != CONTEXT_PREFIX_UTF8_HEX
		or profile.get("hash_profiles", {}).get("policy_decision_audit_v1", {}).get("prefix_utf8_hex") != DECISION_PREFIX_UTF8_HEX
	):
		return {"ok": false}
	var result := {"ok": true, "profile": profile.duplicate(true)}
	if root == DEFAULT_ROOT:
		_DEFAULT_CONTRACT_CACHE = result.duplicate(true)
	return result


static func _load_bytes(path: String) -> PackedByteArray:
	if not FileAccess.file_exists(path):
		return PackedByteArray()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return PackedByteArray()
	var length := file.get_length()
	if length < 1 or length > MAX_CONTRACT_BYTES:
		return PackedByteArray()
	return file.get_buffer(length)


static func _canonical_artifact_sha256(source_bytes: PackedByteArray) -> String:
	var canonical := CabtJsonTreeScript.canonicalize_artifact_json_bytes(
		source_bytes,
		{"max_input_bytes": MAX_CONTRACT_BYTES, "max_output_bytes": MAX_CONTRACT_BYTES},
	)
	return _raw_sha256(canonical.get("bytes", PackedByteArray())) if bool(canonical.get("ok", false)) else ""


static func _domain_hash(prefix_hex: String, payload: Dictionary) -> String:
	var canonical := CabtJsonTreeScript.canonicalize(
		payload,
		{"max_output_bytes": MAX_CONTEXT_BYTES},
	)
	if not bool(canonical.get("ok", false)):
		return ""
	var bytes: PackedByteArray = prefix_hex.hex_decode()
	bytes.append_array(canonical.get("bytes", PackedByteArray()))
	return _raw_sha256(bytes)


static func _raw_sha256(source_bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(source_bytes) != OK:
		return ""
	return context.finish().hex_encode().to_upper()


static func _is_upper_sha256(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or str(value).length() != 64 or str(value) != str(value).to_upper():
		return false
	for index: int in 64:
		var character := str(value).substr(index, 1)
		if not character in "0123456789ABCDEF":
			return false
	return true


static func _identifier(value: Variant) -> bool:
	return (
		typeof(value) == TYPE_STRING
		and not str(value).is_empty()
		and str(value).to_utf8_buffer().size() <= 128
	)


static func _has_exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key_value: Variant in value.keys():
		if typeof(key_value) != TYPE_STRING or not expected.has(key_value):
			return false
	return true


static func _contains_private_key(value: Variant) -> bool:
	if value is Dictionary:
		for key_value: Variant in value.keys():
			if typeof(key_value) != TYPE_STRING or PRIVATE_KEYS.has(key_value) or _contains_private_key(value[key_value]):
				return true
	elif value is Array:
		for child: Variant in value:
			if _contains_private_key(child):
				return true
	return false


static func _copy_json(value: Variant) -> Variant:
	return value.duplicate(true) if value is Dictionary or value is Array else value
