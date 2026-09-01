class_name PublicDeckAdapterCore
extends RefCounted

const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")
const PublicObservationFirewallScript = preload("res://scripts/ai/ptcgdap/public/PublicObservationFirewall.gd")
const StrategicContextScript = preload("res://scripts/ai/ptcgdap/public/StrategicContextV18.gd")

const DEFAULT_ROOT := "res://contracts/ptcgdap"
const PROFILE_ID := "ptcgdap-public-deck-adapter-p4-wp4-v1"
const EXPECTED_BUNDLE_SHA256 := "C80F4C4FDAEA5AC29BD3C5617BFAC72BE38709696F7EA1995D3D153113DD3CA1"
const EXPECTED_PARENT_BUNDLE_SHA256 := "69D05747A9F91C19765D448B676C86E1D9DFA1BBAB108ED1374B854B34E48389"
const EXPECTED_SOURCE_LOCK_SHA256 := "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"
const EXPECTED_ARTIFACT_NAMES := [
	"public_deck_adapter.schema.json",
	"public_deck_adapter_profile.json",
	"public_deck_adapter_conformance_vectors.json",
]
const EXPECTED_ARTIFACTS := {
	"public_deck_adapter.schema.json": "5DCA15806729755F3EF6FA84901C4D65FF369077F09145A2C61149A4355787AE",
	"public_deck_adapter_profile.json": "93A6D659CB3636BE95747AC6F66516463D8C2BB3D1D4082A23AEDA678D684066",
	"public_deck_adapter_conformance_vectors.json": "FAB9FA1105510B7416DC643B5011738FCE4FFC79E4EB8F230FC636229BDC3B5D",
}
const LOCAL_PROFILE_ID := "ptcgdap-local-uid-public-context-as-wp6-v1"
const EXPECTED_LOCAL_BUNDLE_SHA256 := "42706B8426968F4EB1A9C79A3EFC3828236966454013BB791D51684E5C346AAA"
const EXPECTED_LOCAL_ARTIFACT_NAMES := [
	"local_uid_public_context.schema.json",
	"local_uid_public_context_profile.json",
	"local_uid_public_context_conformance_vectors.json",
]
const EXPECTED_LOCAL_ARTIFACTS := {
	"local_uid_public_context.schema.json": "6DD02C41A39BB627D90842BFA9CE39531B8A9D00BA64BF2568BC66C211B87FA2",
	"local_uid_public_context_profile.json": "6905C81FC6203AA97F926235C74DF63E2E199FC6875C743BCC6A8C0C2995ADB8",
	"local_uid_public_context_conformance_vectors.json": "D668BCCB098744E201AA000EBEA282762CC0BDD6075277E3C7EB8C9FB4C1A3C6",
}
const ADAPTER_PREFIX_UTF8_HEX := "50544347444150005055424C49435F4445434B5F414441505445525F563100"
const PROPOSAL_PREFIX_UTF8_HEX := "50544347444150005055424C49435F4445434B5F414441505445525F50524F504F53414C5F563100"
const LOCAL_CONTEXT_PREFIX_UTF8_HEX := "50544347444150004C4F43414C5F5549445F5055424C49435F434F4E544558545F563100"
const LOCAL_UID_SET_PREFIX_UTF8_HEX := "50544347444150004C4F43414C5F5549445F414C4C4F5745445F5345545F563100"
const OFFICIAL_CARD_ID_DOMAIN := "official_cabt_card_id"
const LOCAL_CARD_ID_DOMAIN := "godot_local_card_uid_v1"
const OPERATORS := ["goal_proposal", "macro_proposal", "tiebreak_score"]
const GOAL_STAGES := ["acquire", "deploy", "fund", "ready", "execute", "maintain", "recover"]
const PREDICATES := [
	"select_type_raw",
	"select_context_raw",
	"option_type_raw",
	"option_card_id",
	"option_player_index",
	"acting_hand_card_id",
	"acting_active_card_id",
]
const REASONS := {
	"goal_proposal": "public_goal_proposal",
	"macro_proposal": "public_macro_proposal",
	"tiebreak_score": "public_tiebreak_proposal",
}
const MAX_SAFE_INTEGER := 9007199254740991
const MAX_CONTRACT_BYTES := 2 * 1024 * 1024
const MAX_VALUE_BYTES := 1024 * 1024

static var _ADAPTER_TOKEN: RefCounted = RefCounted.new()
static var _RESULT_TOKEN: RefCounted = RefCounted.new()
static var _ADAPTER_REGISTRY: Array = []
static var _RESULT_REGISTRY: Array = []
static var _DEFAULT_CONTRACT_CACHE: Dictionary = {}
static var _DEFAULT_LOCAL_CONTRACT_CACHE: Dictionary = {}


class CompileOutcome extends RefCounted:
	var accepted := false
	var error_code := "contract_error"
	var adapter: Variant = null

	func _init(accepted_value: bool, error_value: String, adapter_value: Variant = null) -> void:
		accepted = accepted_value
		error_code = error_value
		adapter = adapter_value


class ProposalOutcome extends RefCounted:
	var accepted := false
	var error_code := "contract_error"
	var result: Variant = null

	func _init(accepted_value: bool, error_value: String, result_value: Variant = null) -> void:
		accepted = accepted_value
		error_code = error_value
		result = result_value


class AdapterValue extends RefCounted:
	var _document: Variant = {}
	var _snapshot: Variant = {}
	var _card_id_domain := OFFICIAL_CARD_ID_DOMAIN
	var _allowed_card_uids: Dictionary = {}
	var _deck_manifest_sha256: Variant = null
	var _local_context: Variant = null
	var _factory_token: Variant = null

	var adapter_hash: String:
		get:
			var owner: GDScript = load("res://scripts/ai/ptcgdap/public/PublicDeckAdapter.gd")
			return str(_snapshot.get("adapter_hash", "")) if bool(owner.call("validate_adapter", self)) else ""

	var adapter_id: String:
		get:
			var owner: GDScript = load("res://scripts/ai/ptcgdap/public/PublicDeckAdapter.gd")
			return str(_snapshot.get("adapter_id", "")) if bool(owner.call("validate_adapter", self)) else ""

	var card_id_domain: String:
		get:
			var owner: GDScript = load("res://scripts/ai/ptcgdap/public/PublicDeckAdapter.gd")
			return str(_card_id_domain) if bool(owner.call("validate_adapter", self)) else ""

	var local_context_bound: bool:
		get:
			return card_id_domain == LOCAL_CARD_ID_DOMAIN and _local_context is Dictionary

	var local_context_hash: String:
		get:
			return str(_snapshot.get("local_uid_public_context_hash", "")) if local_context_bound else ""

	func _init(
		document_value: Dictionary = {},
		snapshot_value: Dictionary = {},
		card_id_domain_value: String = OFFICIAL_CARD_ID_DOMAIN,
		allowed_card_uids_value: Dictionary = {},
		deck_manifest_sha256_value: Variant = null,
		local_context_value: Variant = null,
		token_value: Variant = null,
	) -> void:
		_document = document_value.duplicate(true)
		_snapshot = snapshot_value.duplicate(true)
		_card_id_domain = card_id_domain_value
		_allowed_card_uids = allowed_card_uids_value.duplicate(true)
		_deck_manifest_sha256 = deck_manifest_sha256_value
		_local_context = local_context_value.duplicate(true) if local_context_value is Dictionary else null
		_factory_token = token_value

	func validate_integrity() -> bool:
		var owner: GDScript = load("res://scripts/ai/ptcgdap/public/PublicDeckAdapter.gd")
		return bool(owner.call("validate_adapter", self))

	func to_public_dict() -> Dictionary:
		var owner: GDScript = load("res://scripts/ai/ptcgdap/public/PublicDeckAdapter.gd")
		return owner.call("adapter_public_dict", self)


class ProposalValue extends RefCounted:
	var _snapshot: Variant = {}
	var _context_binding: Variant = null
	var _adapter_binding: Variant = null
	var _proposal_id := ""
	var _factory_token: Variant = null

	var adapter_proposals: Array:
		get:
			var owner: GDScript = load("res://scripts/ai/ptcgdap/public/PublicDeckAdapter.gd")
			if not bool(owner.call("validate_result", self, _context_binding, _adapter_binding)):
				return []
			return _snapshot.get("adapter_proposals", []).duplicate(true)

	var proposal_hash: String:
		get:
			var owner: GDScript = load("res://scripts/ai/ptcgdap/public/PublicDeckAdapter.gd")
			return str(_snapshot.get("proposal_hash", "")) if bool(owner.call("validate_result", self, _context_binding, _adapter_binding)) else ""

	func _init(snapshot_value: Dictionary = {}, context_value: Variant = null, adapter_value: Variant = null, proposal_id_value: String = "", token_value: Variant = null) -> void:
		_snapshot = snapshot_value.duplicate(true)
		_context_binding = context_value
		_adapter_binding = adapter_value
		_proposal_id = proposal_id_value
		_factory_token = token_value

	func validate_integrity(context_value: Variant, adapter_value: Variant) -> bool:
		var owner: GDScript = load("res://scripts/ai/ptcgdap/public/PublicDeckAdapter.gd")
		return bool(owner.call("validate_result", self, context_value, adapter_value))

	func to_public_dict() -> Dictionary:
		var owner: GDScript = load("res://scripts/ai/ptcgdap/public/PublicDeckAdapter.gd")
		return owner.call("result_public_dict", self)


static func compile(document: Variant, contract_root: Variant = DEFAULT_ROOT) -> CompileOutcome:
	if typeof(contract_root) != TYPE_STRING or not _load_contracts(str(contract_root)).get("ok", false):
		return CompileOutcome.new(false, "contract_error")
	var error := _document_error(document)
	if not error.is_empty():
		return CompileOutcome.new(false, error)
	var source: Dictionary = document.duplicate(true)
	var payload := _adapter_payload(source, OFFICIAL_CARD_ID_DOMAIN, {}, null, null)
	var adapter_hash := _domain_hash(ADAPTER_PREFIX_UTF8_HEX, payload)
	if adapter_hash.is_empty():
		return CompileOutcome.new(false, "adapter_integrity_invalid")
	var snapshot := payload.duplicate(true)
	snapshot["adapter_hash"] = adapter_hash
	var adapter := AdapterValue.new(source, snapshot, OFFICIAL_CARD_ID_DOMAIN, {}, null, null, _ADAPTER_TOKEN)
	_register_adapter(adapter, source, snapshot, OFFICIAL_CARD_ID_DOMAIN, {}, null, null)
	if not validate_adapter(adapter):
		return CompileOutcome.new(false, "adapter_integrity_invalid")
	return CompileOutcome.new(true, "", adapter)


static func compile_local_uid(
	document: Variant,
	allowed_card_uids: Variant,
	deck_manifest_sha256: Variant,
	contract_root: Variant = DEFAULT_ROOT,
) -> CompileOutcome:
	if typeof(contract_root) != TYPE_STRING or not _load_contracts(str(contract_root)).get("ok", false):
		return CompileOutcome.new(false, "contract_error")
	if not _load_local_contracts(str(contract_root)).get("ok", false):
		return CompileOutcome.new(false, "local_uid_contract_error")
	if not allowed_card_uids is Array or allowed_card_uids.is_empty() or not _is_sha(deck_manifest_sha256):
		return CompileOutcome.new(false, "invalid_adapter_document")
	var allowed := {}
	for uid: Variant in allowed_card_uids:
		if not _local_uid(uid) or allowed.has(uid):
			return CompileOutcome.new(false, "invalid_adapter_document")
		allowed[uid] = true
	var error := _document_error(document, LOCAL_CARD_ID_DOMAIN, allowed)
	if not error.is_empty():
		return CompileOutcome.new(false, error)
	var source: Dictionary = document.duplicate(true)
	var payload := _adapter_payload(source, LOCAL_CARD_ID_DOMAIN, allowed, str(deck_manifest_sha256), null)
	var adapter_hash := _domain_hash(ADAPTER_PREFIX_UTF8_HEX, payload)
	if adapter_hash.is_empty():
		return CompileOutcome.new(false, "adapter_integrity_invalid")
	var snapshot := payload.duplicate(true)
	snapshot["adapter_hash"] = adapter_hash
	var adapter := AdapterValue.new(source, snapshot, LOCAL_CARD_ID_DOMAIN, allowed, str(deck_manifest_sha256), null, _ADAPTER_TOKEN)
	_register_adapter(adapter, source, snapshot, LOCAL_CARD_ID_DOMAIN, allowed, str(deck_manifest_sha256), null)
	if not validate_adapter(adapter):
		return CompileOutcome.new(false, "adapter_integrity_invalid")
	return CompileOutcome.new(true, "", adapter)


static func bind_local_context(adapter: Variant, context: Variant, local_uid_public_context: Variant) -> CompileOutcome:
	if not _load_local_contracts(DEFAULT_ROOT).get("ok", false):
		return CompileOutcome.new(false, "local_uid_contract_error")
	if not validate_adapter(adapter) or adapter.get("_card_id_domain") != LOCAL_CARD_ID_DOMAIN or adapter.get("_local_context") is Dictionary:
		return CompileOutcome.new(false, "invalid_local_uid_public_context")
	var allowed: Dictionary = adapter.get("_allowed_card_uids")
	if not _local_context_error(context, local_uid_public_context, allowed).is_empty():
		return CompileOutcome.new(false, "invalid_local_uid_public_context")
	var source: Dictionary = adapter.get("_document").duplicate(true)
	var local_context: Dictionary = local_uid_public_context.duplicate(true)
	var payload := _adapter_payload(source, LOCAL_CARD_ID_DOMAIN, allowed, adapter.get("_deck_manifest_sha256"), local_context)
	var adapter_hash := _domain_hash(ADAPTER_PREFIX_UTF8_HEX, payload)
	if adapter_hash.is_empty():
		return CompileOutcome.new(false, "adapter_integrity_invalid")
	var snapshot := payload.duplicate(true)
	snapshot["adapter_hash"] = adapter_hash
	var bound := AdapterValue.new(source, snapshot, LOCAL_CARD_ID_DOMAIN, allowed, adapter.get("_deck_manifest_sha256"), local_context, _ADAPTER_TOKEN)
	_register_adapter(bound, source, snapshot, LOCAL_CARD_ID_DOMAIN, allowed, adapter.get("_deck_manifest_sha256"), local_context)
	if not validate_adapter(bound):
		return CompileOutcome.new(false, "adapter_integrity_invalid")
	return CompileOutcome.new(true, "", bound)


static func propose(context: Variant, adapter: Variant, proposal_id: Variant, contract_root: Variant = DEFAULT_ROOT) -> ProposalOutcome:
	if typeof(contract_root) != TYPE_STRING or not _load_contracts(str(contract_root)).get("ok", false):
		return ProposalOutcome.new(false, "contract_error")
	if not StrategicContextScript.validate_context(context):
		return ProposalOutcome.new(false, "invalid_context")
	if not validate_adapter(adapter):
		return ProposalOutcome.new(false, "invalid_adapter")
	if adapter.get("_card_id_domain") == LOCAL_CARD_ID_DOMAIN and not _load_local_contracts(str(contract_root)).get("ok", false):
		return ProposalOutcome.new(false, "local_uid_contract_error")
	if not _identifier(proposal_id):
		return ProposalOutcome.new(false, "invalid_proposal_id")
	var payload := _proposal_payload(context, adapter, str(proposal_id))
	if payload.is_empty():
		return ProposalOutcome.new(false, "proposal_integrity_invalid")
	var proposal_hash := _domain_hash(PROPOSAL_PREFIX_UTF8_HEX, payload)
	if proposal_hash.is_empty():
		return ProposalOutcome.new(false, "proposal_integrity_invalid")
	var snapshot := payload.duplicate(true)
	snapshot["proposal_hash"] = proposal_hash
	var value := ProposalValue.new(snapshot, context, adapter, str(proposal_id), _RESULT_TOKEN)
	_register_result(value, snapshot, context, adapter, str(proposal_id))
	if not validate_result(value, context, adapter):
		return ProposalOutcome.new(false, "proposal_integrity_invalid")
	return ProposalOutcome.new(true, "", value)


static func validate_adapter(value: Variant) -> bool:
	var entry := _registry_entry(_ADAPTER_REGISTRY, value)
	if (
		not value is AdapterValue
		or entry.is_empty()
		or value.get("_factory_token") != _ADAPTER_TOKEN
		or not value.get("_document") is Dictionary
		or not value.get("_snapshot") is Dictionary
		or value.get("_document") != entry.get("document")
		or value.get("_snapshot") != entry.get("snapshot")
		or value.get("_card_id_domain") != entry.get("card_id_domain")
		or value.get("_allowed_card_uids") != entry.get("allowed_card_uids")
		or value.get("_deck_manifest_sha256") != entry.get("deck_manifest_sha256")
		or value.get("_local_context") != entry.get("local_context")
	):
		return false
	var document: Dictionary = value.get("_document")
	var domain: String = str(value.get("_card_id_domain"))
	var allowed: Dictionary = value.get("_allowed_card_uids")
	var manifest_sha: Variant = value.get("_deck_manifest_sha256")
	var local_context: Variant = value.get("_local_context")
	if domain not in [OFFICIAL_CARD_ID_DOMAIN, LOCAL_CARD_ID_DOMAIN] or not _document_error(document, domain, allowed).is_empty():
		return false
	if domain == OFFICIAL_CARD_ID_DOMAIN:
		if not allowed.is_empty() or manifest_sha != null or local_context != null:
			return false
	elif allowed.is_empty() or not _is_sha(manifest_sha) or (local_context != null and not local_context is Dictionary):
		return false
	var payload := _adapter_payload(document, domain, allowed, manifest_sha, local_context)
	var expected := payload.duplicate(true)
	expected["adapter_hash"] = _domain_hash(ADAPTER_PREFIX_UTF8_HEX, payload)
	return not expected.get("adapter_hash", "").is_empty() and value.get("_snapshot") == expected


static func adapter_public_dict(value: Variant) -> Dictionary:
	return value.get("_snapshot").duplicate(true) if validate_adapter(value) else {}


static func validate_result(value: Variant, context: Variant, adapter: Variant) -> bool:
	var entry := _registry_entry(_RESULT_REGISTRY, value)
	if (
		not value is ProposalValue
		or entry.is_empty()
		or value.get("_factory_token") != _RESULT_TOKEN
		or context != value.get("_context_binding")
		or adapter != value.get("_adapter_binding")
		or context != entry.get("context")
		or adapter != entry.get("adapter")
		or value.get("_proposal_id") != entry.get("proposal_id")
		or not value.get("_snapshot") is Dictionary
		or value.get("_snapshot") != entry.get("snapshot")
		or not StrategicContextScript.validate_context(context)
		or not validate_adapter(adapter)
	):
		return false
	var payload := _proposal_payload(context, adapter, str(value.get("_proposal_id")))
	if payload.is_empty():
		return false
	var expected := payload.duplicate(true)
	expected["proposal_hash"] = _domain_hash(PROPOSAL_PREFIX_UTF8_HEX, payload)
	return not expected.get("proposal_hash", "").is_empty() and value.get("_snapshot") == expected


static func result_public_dict(value: Variant) -> Dictionary:
	return value.get("_snapshot").duplicate(true) if validate_result(value, value.get("_context_binding"), value.get("_adapter_binding")) else {}


static func validate_local_uid_public_context(context: Variant, value: Variant) -> bool:
	return _load_local_contracts(DEFAULT_ROOT).get("ok", false) and _local_context_error(context, value, null).is_empty()


static func _local_context_error(context: Variant, value: Variant, allowed_card_uids: Variant) -> String:
	if not StrategicContextScript.validate_context(context) or _contains_private(value):
		return "invalid_local_uid_public_context"
	if not value is Dictionary or not _has_exact_keys(value, ["schema_version", "card_id_domain", "source", "options", "acting_hand", "acting_active"]):
		return "invalid_local_uid_public_context"
	var public: Dictionary = StrategicContextScript.context_public_dict(context)
	var source: Variant = value.get("source")
	if (
		value.get("schema_version") != 1
		or value.get("card_id_domain") != LOCAL_CARD_ID_DOMAIN
		or not source is Dictionary
		or not _has_exact_keys(source, ["context_hash", "window_id"])
		or source.get("context_hash") != public.get("context_hash")
		or source.get("window_id") != public.get("source", {}).get("window_id")
	):
		return "invalid_local_uid_public_context"
	var options: Variant = value.get("options")
	var public_options: Variant = public.get("select_semantics", {}).get("options")
	if not options is Array or not public_options is Array or options.size() != public_options.size():
		return "invalid_local_uid_public_context"
	for index: int in range(options.size()):
		var entry: Variant = options[index]
		if (
			not entry is Dictionary
			or not _has_exact_keys(entry, ["index", "local_card_uid"])
			or typeof(entry.get("index")) != TYPE_INT
			or int(entry.get("index")) != index
			or public_options[index].get("index") != index
		):
			return "invalid_local_uid_public_context"
		var uid: Variant = entry.get("local_card_uid")
		if uid != null and (not _local_uid(uid) or (allowed_card_uids is Dictionary and not allowed_card_uids.has(uid))):
			return "invalid_local_uid_public_context"
	var acting: Variant = public.get("public_state", {}).get("acting_player")
	if not acting is Dictionary:
		return "invalid_local_uid_public_context"
	for pair: Array in [["acting_hand", "hand"], ["acting_active", "active"]]:
		var entries: Variant = value.get(pair[0])
		var cards: Variant = acting.get(pair[1])
		if not entries is Array or not cards is Array or entries.size() != cards.size():
			return "invalid_local_uid_public_context"
		for index: int in range(entries.size()):
			var entry: Variant = entries[index]
			if (
				not entry is Dictionary
				or not _has_exact_keys(entry, ["serial", "local_card_uid"])
				or typeof(entry.get("serial")) != TYPE_INT
				or entry.get("serial") != cards[index].get("serial")
				or not _local_uid(entry.get("local_card_uid"))
				or (allowed_card_uids is Dictionary and not allowed_card_uids.has(entry.get("local_card_uid")))
			):
				return "invalid_local_uid_public_context"
	return ""


static func _document_error(
	value: Variant,
	card_id_domain: String = OFFICIAL_CARD_ID_DOMAIN,
	allowed_card_uids: Dictionary = {},
) -> String:
	if _contains_private(value):
		return "private_adapter_input"
	if not value is Dictionary or not _has_exact_keys(value, ["schema_version", "adapter_id", "adapter_version", "rules"]):
		return "invalid_adapter_document"
	if value.get("schema_version") != 1 or not _identifier(value.get("adapter_id")) or not _safe_int(value.get("adapter_version")) or value.get("adapter_version") < 1:
		return "invalid_adapter_document"
	var rules: Variant = value.get("rules")
	if not rules is Array or rules.size() > 128:
		return "invalid_adapter_document"
	var seen := {}
	for item: Variant in rules:
		if not item is Dictionary or not _has_exact_keys(item, ["rule_id", "operator", "reason_code", "goal_stage", "priority", "predicate"]):
			return "invalid_adapter_document"
		if not _identifier(item.get("rule_id")) or seen.has(item.get("rule_id")):
			return "invalid_adapter_document"
		seen[item.get("rule_id")] = true
		var operator: Variant = item.get("operator")
		if typeof(operator) != TYPE_STRING or not OPERATORS.has(operator):
			return "unsupported_adapter_operator"
		var stage: Variant = item.get("goal_stage")
		if typeof(stage) != TYPE_STRING or not GOAL_STAGES.has(stage):
			return "unsupported_goal_stage"
		if item.get("reason_code") != REASONS.get(operator) or not _safe_int(item.get("priority")) or item.get("priority") < 0:
			return "invalid_adapter_document"
		var predicate: Variant = item.get("predicate")
		if not predicate is Dictionary or not _has_exact_keys(predicate, PREDICATES):
			return "invalid_public_predicate"
		for key: String in PREDICATES:
			var predicate_value: Variant = predicate.get(key)
			var card_field := key in ["option_card_id", "acting_hand_card_id", "acting_active_card_id"]
			if card_field and card_id_domain == LOCAL_CARD_ID_DOMAIN:
				if predicate_value != null and (not _local_uid(predicate_value) or not allowed_card_uids.has(predicate_value)):
					return "invalid_public_predicate"
			elif predicate_value != null and (not _safe_int(predicate_value) or (card_field and predicate_value <= 0)):
				return "invalid_public_predicate"
	return ""


static func _adapter_payload(
	document: Dictionary,
	card_id_domain: String,
	allowed_card_uids: Dictionary,
	deck_manifest_sha256: Variant,
	local_context: Variant,
) -> Dictionary:
	var payload := {
		"schema_version": 1,
		"profile_id": PROFILE_ID,
		"adapter_id": document.get("adapter_id"),
		"adapter_version": document.get("adapter_version"),
		"rules": document.get("rules", []).duplicate(true),
		"authoritative": false,
	}
	if card_id_domain == LOCAL_CARD_ID_DOMAIN:
		var sorted_uids: Array = allowed_card_uids.keys()
		sorted_uids.sort()
		payload["card_id_domain"] = LOCAL_CARD_ID_DOMAIN
		payload["deck_manifest_sha256"] = deck_manifest_sha256
		payload["allowed_card_uids_hash"] = _domain_hash(LOCAL_UID_SET_PREFIX_UTF8_HEX, sorted_uids)
		payload["local_uid_public_context_hash"] = _domain_hash(LOCAL_CONTEXT_PREFIX_UTF8_HEX, local_context) if local_context is Dictionary else null
	return payload


static func _proposal_payload(context: Variant, adapter: Variant, proposal_id: String) -> Dictionary:
	var public: Dictionary = StrategicContextScript.context_public_dict(context)
	var adapter_public := adapter_public_dict(adapter)
	if public.is_empty() or adapter_public.is_empty():
		return {}
	var local: bool = adapter.get("_card_id_domain") == LOCAL_CARD_ID_DOMAIN
	var local_context: Variant = adapter.get("_local_context")
	if local and (not local_context is Dictionary or not _local_context_error(context, local_context, adapter.get("_allowed_card_uids")).is_empty()):
		return {}
	var semantics: Variant = public.get("select_semantics")
	var state: Variant = public.get("public_state")
	var source: Variant = public.get("source")
	if not semantics is Dictionary or not state is Dictionary or not source is Dictionary:
		return {}
	var options: Variant = semantics.get("options")
	if not options is Array:
		return {}
	var proposals: Array = []
	var matches: Array = []
	for operator: String in OPERATORS:
		var best := {}
		var order := 0
		for item: Variant in adapter_public.get("rules", []):
			if item.get("operator") == operator:
				var indexes: Array = []
				for option: Variant in options:
					if _matches(item.get("predicate"), public, option, adapter):
						indexes.append(option.get("index"))
				if not indexes.is_empty():
					matches.append({"rule_id": item.get("rule_id"), "operator": operator, "goal_stage": item.get("goal_stage"), "matched_indexes": indexes.duplicate(true)})
				for index: Variant in indexes:
					var rank := [item.get("priority"), order]
					if not best.has(index) or _rank_less(rank, best.get(index)):
						best[index] = rank
			order += 1
		if not best.is_empty():
			var ordered: Array = []
			while ordered.size() < best.size():
				var selected: Variant = null
				for index: Variant in best.keys():
					if ordered.has(index):
						continue
					if selected == null or _rank_less([best.get(index)[0], best.get(index)[1], index], [best.get(selected)[0], best.get(selected)[1], selected]):
						selected = index
				ordered.append(selected)
			proposals.append({"operator": operator, "indexes": ordered, "reason_code": REASONS.get(operator)})
	var source_payload := {"context_hash": public.get("context_hash"), "window_id": source.get("window_id"), "adapter_hash": adapter_public.get("adapter_hash")}
	var payload := {
		"schema_version": 1,
		"profile_id": PROFILE_ID,
		"proposal_id": proposal_id,
		"adapter_id": adapter_public.get("adapter_id"),
		"source": source_payload,
		"adapter_proposals": proposals,
		"matched_rules": matches,
		"authoritative": false,
	}
	if local:
		payload["card_id_domain"] = LOCAL_CARD_ID_DOMAIN
		source_payload["local_uid_public_context_hash"] = adapter.get("local_context_hash")
	return payload


static func _matches(predicate: Dictionary, context: Dictionary, option: Dictionary, adapter: Variant) -> bool:
	var semantics: Dictionary = context.get("select_semantics")
	var raw: Dictionary = option.get("raw")
	var local: bool = adapter.get("_card_id_domain") == LOCAL_CARD_ID_DOMAIN
	var local_context: Dictionary = adapter.get("_local_context") if local else {}
	var option_index := int(option.get("index", -1))
	var local_options: Array = local_context.get("options", []) if local else []
	if local and (option_index < 0 or option_index >= local_options.size()):
		return false
	var actual := {
		"select_type_raw": semantics.get("select_type_raw"),
		"select_context_raw": semantics.get("select_context_raw"),
		"option_type_raw": raw.get("type"),
		"option_card_id": local_options[option_index].get("local_card_uid") if local else raw.get("cardId"),
		"option_player_index": raw.get("playerIndex"),
	}
	for key: String in ["select_type_raw", "select_context_raw", "option_type_raw", "option_card_id", "option_player_index"]:
		if predicate.get(key) != null and actual.get(key) != predicate.get(key):
			return false
	var state: Dictionary = context.get("public_state")
	var acting: Dictionary = state.get("acting_player")
	var hand_ids := _local_context_ids(local_context.get("acting_hand", [])) if local else _card_ids(acting.get("hand"))
	var active_ids := _local_context_ids(local_context.get("acting_active", [])) if local else _card_ids(acting.get("active"))
	if predicate.get("acting_hand_card_id") != null and not hand_ids.has(predicate.get("acting_hand_card_id")):
		return false
	if predicate.get("acting_active_card_id") != null and not active_ids.has(predicate.get("acting_active_card_id")):
		return false
	return true


static func _card_ids(value: Variant) -> Dictionary:
	var result := {}
	if value is Array:
		for item: Variant in value:
			if item is Dictionary and typeof(item.get("id")) == TYPE_INT:
				result[item.get("id")] = true
	return result


static func _local_context_ids(value: Variant) -> Dictionary:
	var result := {}
	if value is Array:
		for item: Variant in value:
			if item is Dictionary and _local_uid(item.get("local_card_uid")):
				result[item.get("local_card_uid")] = true
	return result


static func _register_adapter(
	value: Variant,
	document: Dictionary,
	snapshot: Dictionary,
	card_id_domain: String,
	allowed_card_uids: Dictionary,
	deck_manifest_sha256: Variant,
	local_context: Variant,
) -> void:
	_prune_registry(_ADAPTER_REGISTRY)
	_ADAPTER_REGISTRY.append({
		"weak": weakref(value),
		"document": document.duplicate(true),
		"snapshot": snapshot.duplicate(true),
		"card_id_domain": card_id_domain,
		"allowed_card_uids": allowed_card_uids.duplicate(true),
		"deck_manifest_sha256": deck_manifest_sha256,
		"local_context": local_context.duplicate(true) if local_context is Dictionary else null,
	})


static func _register_result(value: Variant, snapshot: Dictionary, context: Variant, adapter: Variant, proposal_id: String) -> void:
	_prune_registry(_RESULT_REGISTRY)
	_RESULT_REGISTRY.append({"weak": weakref(value), "snapshot": snapshot.duplicate(true), "context": context, "adapter": adapter, "proposal_id": proposal_id})


static func _registry_entry(registry: Array, value: Variant) -> Dictionary:
	if typeof(value) != TYPE_OBJECT or value == null:
		return {}
	_prune_registry(registry)
	for entry: Variant in registry:
		var weak_value: Variant = entry.get("weak") if entry is Dictionary else null
		if typeof(weak_value) == TYPE_OBJECT and weak_value != null and weak_value.get_ref() == value:
			return entry
	return {}


static func _prune_registry(registry: Array) -> void:
	for index: int in range(registry.size() - 1, -1, -1):
		var entry: Variant = registry[index]
		var weak_value: Variant = entry.get("weak") if entry is Dictionary else null
		if typeof(weak_value) != TYPE_OBJECT or weak_value == null or weak_value.get_ref() == null:
			registry.remove_at(index)


static func _load_contracts(root_path: String) -> Dictionary:
	var root := root_path.trim_suffix("/")
	if root.is_empty():
		return {"ok": false}
	if root == DEFAULT_ROOT and bool(_DEFAULT_CONTRACT_CACHE.get("ok", false)):
		return _DEFAULT_CONTRACT_CACHE.duplicate(true)
	var bundle_bytes := _load_bytes("%s/public_deck_adapter_bundle.json" % root)
	if bundle_bytes.is_empty() or _canonical_artifact_sha256(bundle_bytes) != EXPECTED_BUNDLE_SHA256:
		return {"ok": false}
	var parsed := PublicObservationFirewallScript._parse_contract_json_bytes(bundle_bytes)
	var bundle: Variant = parsed.get("value") if bool(parsed.get("ok", false)) else null
	if not bundle is Dictionary or not _has_exact_keys(bundle, ["schema_version", "bundle_id", "parent_bundle_canonical_sha256", "source_lock_canonical_sha256", "artifacts"]):
		return {"ok": false}
	if bundle.get("schema_version") != 1 or bundle.get("bundle_id") != PROFILE_ID or bundle.get("parent_bundle_canonical_sha256") != EXPECTED_PARENT_BUNDLE_SHA256 or bundle.get("source_lock_canonical_sha256") != EXPECTED_SOURCE_LOCK_SHA256:
		return {"ok": false}
	var artifacts: Variant = bundle.get("artifacts")
	if not artifacts is Array or artifacts.size() != EXPECTED_ARTIFACT_NAMES.size():
		return {"ok": false}
	var profile: Variant = null
	for index: int in EXPECTED_ARTIFACT_NAMES.size():
		var name: String = EXPECTED_ARTIFACT_NAMES[index]
		var entry: Variant = artifacts[index]
		if not entry is Dictionary or not _has_exact_keys(entry, ["id", "path", "canonical_sha256"]):
			return {"ok": false}
		if entry.get("id") != name.trim_suffix(".json") or entry.get("path") != "contracts/ptcgdap/%s" % name or entry.get("canonical_sha256") != EXPECTED_ARTIFACTS.get(name):
			return {"ok": false}
		var bytes := _load_bytes("%s/%s" % [root, name])
		if bytes.is_empty() or _canonical_artifact_sha256(bytes) != EXPECTED_ARTIFACTS.get(name):
			return {"ok": false}
		var document_result := PublicObservationFirewallScript._parse_contract_json_bytes(bytes)
		if not bool(document_result.get("ok", false)):
			return {"ok": false}
		if name == "public_deck_adapter_profile.json":
			profile = document_result.get("value")
	if not profile is Dictionary:
		return {"ok": false}
	var adapter_contract: Variant = profile.get("adapter_contract")
	var result_contract: Variant = profile.get("result_contract")
	if (
		profile.get("profile_id") != PROFILE_ID
		or profile.get("parent_bundle_canonical_sha256") != EXPECTED_PARENT_BUNDLE_SHA256
		or profile.get("source_authority") != "exact_current_p4_wp1_strategic_context_owner"
		or not adapter_contract is Dictionary
		or adapter_contract.get("goal_stages") != GOAL_STAGES
		or adapter_contract.get("operators") != OPERATORS
		or adapter_contract.get("predicate_fields") != PREDICATES
		or adapter_contract.get("proposal_authority") != "same_base_tier_ordering_hint_only"
		or not result_contract is Dictionary
		or result_contract.get("serialized_result_is_execution_authority") != false
	):
		return {"ok": false}
	var result := {"ok": true}
	if root == DEFAULT_ROOT:
		_DEFAULT_CONTRACT_CACHE = result.duplicate(true)
	return result


static func _load_local_contracts(root_path: String) -> Dictionary:
	var root := root_path.trim_suffix("/")
	if root.is_empty():
		return {"ok": false}
	if root == DEFAULT_ROOT and bool(_DEFAULT_LOCAL_CONTRACT_CACHE.get("ok", false)):
		return _DEFAULT_LOCAL_CONTRACT_CACHE.duplicate(true)
	var bundle_bytes := _load_bytes("%s/local_uid_public_context_bundle.json" % root)
	if bundle_bytes.is_empty() or _canonical_artifact_sha256(bundle_bytes) != EXPECTED_LOCAL_BUNDLE_SHA256:
		return {"ok": false}
	var parsed := PublicObservationFirewallScript._parse_contract_json_bytes(bundle_bytes)
	var bundle: Variant = parsed.get("value") if bool(parsed.get("ok", false)) else null
	if not bundle is Dictionary or not _has_exact_keys(bundle, ["schema_version", "bundle_id", "parent_bundle_canonical_sha256", "source_lock_canonical_sha256", "artifacts"]):
		return {"ok": false}
	if (
		bundle.get("schema_version") != 1
		or bundle.get("bundle_id") != LOCAL_PROFILE_ID
		or bundle.get("parent_bundle_canonical_sha256") != EXPECTED_BUNDLE_SHA256
		or bundle.get("source_lock_canonical_sha256") != EXPECTED_SOURCE_LOCK_SHA256
	):
		return {"ok": false}
	var artifacts: Variant = bundle.get("artifacts")
	if not artifacts is Array or artifacts.size() != EXPECTED_LOCAL_ARTIFACT_NAMES.size():
		return {"ok": false}
	var profile: Variant = null
	for index: int in EXPECTED_LOCAL_ARTIFACT_NAMES.size():
		var name: String = EXPECTED_LOCAL_ARTIFACT_NAMES[index]
		var entry: Variant = artifacts[index]
		if not entry is Dictionary or not _has_exact_keys(entry, ["id", "path", "canonical_sha256"]):
			return {"ok": false}
		if entry.get("id") != name.trim_suffix(".json") or entry.get("path") != "contracts/ptcgdap/%s" % name or entry.get("canonical_sha256") != EXPECTED_LOCAL_ARTIFACTS.get(name):
			return {"ok": false}
		var bytes := _load_bytes("%s/%s" % [root, name])
		if bytes.is_empty() or _canonical_artifact_sha256(bytes) != EXPECTED_LOCAL_ARTIFACTS.get(name):
			return {"ok": false}
		var document_result := PublicObservationFirewallScript._parse_contract_json_bytes(bytes)
		if not bool(document_result.get("ok", false)):
			return {"ok": false}
		if name == "local_uid_public_context_profile.json":
			profile = document_result.get("value")
	if not profile is Dictionary:
		return {"ok": false}
	var identity: Variant = profile.get("card_identity")
	var binding: Variant = profile.get("binding_contract")
	var hashes: Variant = profile.get("hash_contract")
	var scope: Variant = profile.get("scope")
	if (
		profile.get("profile_id") != LOCAL_PROFILE_ID
		or profile.get("parent_bundle_canonical_sha256") != EXPECTED_BUNDLE_SHA256
		or not identity is Dictionary
		or identity.get("domain") != LOCAL_CARD_ID_DOMAIN
		or identity.get("construction") != "set_code + '_' + card_index"
		or identity.get("syntax_pattern") != "^[A-Za-z0-9.]+_[A-Za-z0-9]+$"
		or identity.get("set_code_pattern") != "^[A-Za-z0-9.]+$"
		or identity.get("card_index_pattern") != "^[A-Za-z0-9]+$"
		or identity.get("component_max_length") != 32
		or identity.get("merge_with_official_card_id") != false
		or not binding is Dictionary
		or binding.get("opponent_hidden_identity_allowed") != false
		or binding.get("old_window_reuse_allowed") != false
		or not hashes is Dictionary
		or hashes.get("local_context_prefix_utf8_hex") != LOCAL_CONTEXT_PREFIX_UTF8_HEX
		or hashes.get("allowed_uid_set_prefix_utf8_hex") != LOCAL_UID_SET_PREFIX_UTF8_HEX
		or not scope is Dictionary
		or scope.get("player_live_authority") != false
		or scope.get("cabt_export") != false
	):
		return {"ok": false}
	var result := {"ok": true}
	if root == DEFAULT_ROOT:
		_DEFAULT_LOCAL_CONTRACT_CACHE = result.duplicate(true)
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
	var result := CabtJsonTreeScript.canonicalize_artifact_json_bytes(source_bytes, {"max_input_bytes": MAX_CONTRACT_BYTES, "max_output_bytes": MAX_CONTRACT_BYTES})
	return _raw_sha256(result.get("bytes", PackedByteArray())) if bool(result.get("ok", false)) else ""


static func _domain_hash(prefix_hex: String, payload: Variant) -> String:
	var result := CabtJsonTreeScript.canonicalize(payload, {"max_output_bytes": MAX_VALUE_BYTES})
	if not bool(result.get("ok", false)):
		return ""
	var bytes: PackedByteArray = prefix_hex.hex_decode()
	bytes.append_array(result.get("bytes", PackedByteArray()))
	return _raw_sha256(bytes)


static func _raw_sha256(source_bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(source_bytes) != OK:
		return ""
	return context.finish().hex_encode().to_upper()


static func _contains_private(value: Variant) -> bool:
	if typeof(value) == TYPE_STRING:
		return str(value).to_upper().contains("PRIVATE")
	if value is Dictionary:
		for key: Variant in value.keys():
			if typeof(key) != TYPE_STRING or str(key).to_upper().contains("PRIVATE") or _contains_private(value.get(key)):
				return true
	elif value is Array:
		for child: Variant in value:
			if _contains_private(child):
				return true
	return false


static func _identifier(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or str(value).is_empty() or str(value).length() > 128 or str(value).to_upper().contains("PRIVATE"):
		return false
	const ALLOWED := "abcdefghijklmnopqrstuvwxyz0123456789._-"
	for character: String in str(value):
		if not ALLOWED.contains(character):
			return false
	return str(value)[0] in "abcdefghijklmnopqrstuvwxyz0123456789"


static func _safe_int(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and value >= -MAX_SAFE_INTEGER and value <= MAX_SAFE_INTEGER


static func _local_uid(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or str(value).length() < 4 or str(value).length() > 64 or str(value).to_upper().contains("PRIVATE"):
		return false
	if str(value).count("_") != 1:
		return false
	var parts: PackedStringArray = str(value).split("_", true)
	if parts.size() != 2 or parts[0].is_empty() or parts[1].is_empty() or parts[0].length() > 32 or parts[1].length() > 32:
		return false
	const SET_CODE_ALLOWED := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789."
	const CARD_INDEX_ALLOWED := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	for character: String in parts[0]:
		if not SET_CODE_ALLOWED.contains(character):
			return false
	for character: String in parts[1]:
		if not CARD_INDEX_ALLOWED.contains(character):
			return false
	return true


static func _is_sha(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or str(value).length() != 64:
		return false
	for character: String in str(value):
		if character not in "0123456789ABCDEF":
			return false
	return true


static func _has_exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key: Variant in value.keys():
		if typeof(key) != TYPE_STRING or not expected.has(key):
			return false
	return true


static func _rank_less(left: Array, right: Array) -> bool:
	var count := mini(left.size(), right.size())
	for index: int in count:
		if left[index] < right[index]:
			return true
		if left[index] > right[index]:
			return false
	return left.size() < right.size()
