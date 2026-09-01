extends RefCounted

const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")
const PromptScript = preload("res://scripts/ai/ptcgdap/host/godot/AuthorStrategyShadowPrompt.gd")
const PublicBasePolicyScript = preload("res://scripts/ai/ptcgdap/public/PublicBasePolicy.gd")
const StrategicTraceScript = preload("res://scripts/ai/ptcgdap/public/StrategicTraceV2.gd")
const PublicDeckAdapterScript = preload("res://scripts/ai/ptcgdap/public/PublicDeckAdapter.gd")
const ModelActorScript = preload("res://scripts/ai/ptcgdap/host/godot/PtcgDAPModelActor.gd")
const LOCAL_CARD_ID_DOMAIN := "godot_local_card_uid_v1"
const OFFICIAL_CARD_ID_DOMAIN := "official_cabt_card_id"
const PROFILE_ID := "ptcgdap-author-strategy-match-host-as-wp4-v1"
const AUDIT_PREFIX_UTF8_HEX := "5054434744415000415554484F525F53545241544547595F534841444F575F41554449545F563100"
static var _FACTORY_TOKEN: RefCounted = RefCounted.new()
static var _RESULT_TOKEN: RefCounted = RefCounted.new()

var _handle: Variant = null
var _match_id := ""
var _ir: Variant = null
var _adapter: Variant = null
var _model_actor: Variant = null
var _current_prompt: Variant = null
var _consumed_prompt_ids := {}
var _factory_token: Variant = null


class ShadowResult extends RefCounted:
	var _snapshot: Dictionary = {}
	var _factory_token: Variant = null

	var indexes: Array:
		get:
			return _snapshot.get("selected_indexes", []).duplicate(true) if validate_integrity() else []

	func _init(snapshot: Dictionary = {}, token: Variant = null) -> void:
		_snapshot = snapshot.duplicate(true)
		_factory_token = token

	func validate_integrity() -> bool:
		var owner: GDScript = load("res://scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorMatchHost.gd")
		return bool(owner.call("validate_shadow_result", self))

	func to_public_dict() -> Dictionary:
		return _snapshot.duplicate(true) if validate_integrity() else {}


static func create(handle: Variant, match_id: Variant) -> Dictionary:
	if handle == null or not handle.has_method("validate_integrity") or not handle.validate_integrity():
		return _error("package_integrity_invalid")
	if not _identifier(match_id) or str(match_id).length() > 64:
		return _error("invalid_match_identity")
	var documents_result: Dictionary = handle.policy_documents()
	if not bool(documents_result.get("ok", false)):
		return _error(str(documents_result.get("error_code", "package_policy_unsupported")))
	var documents: Dictionary = documents_result.get("documents", {})
	var ir_outcome: Variant = StrategicTraceScript.compile_ir(documents.get("policy/policy_ir.json"))
	var pins: Dictionary = handle.to_public_dict()
	var adapter_outcome: Variant = null
	if pins.get("deck_card_id_domain") == LOCAL_CARD_ID_DOMAIN:
		var allowed_uids: Array = []
		for row: Variant in handle.local_deck_snapshot():
			if row is Dictionary:
				allowed_uids.append(row.get("local_card_uid"))
		adapter_outcome = PublicDeckAdapterScript.compile_local_uid(
			documents.get("policy/adapter.json"), allowed_uids, pins.get("deck_manifest_sha256")
		)
	elif pins.get("deck_card_id_domain") == OFFICIAL_CARD_ID_DOMAIN:
		adapter_outcome = PublicDeckAdapterScript.compile(documents.get("policy/adapter.json"))
	else:
		return _error("package_policy_unsupported")
	if ir_outcome == null or not bool(ir_outcome.get("accepted")) or ir_outcome.get("ir") == null or adapter_outcome == null or not bool(adapter_outcome.get("accepted")) or adapter_outcome.get("adapter") == null:
		return _error("package_policy_unsupported")
	var model_result: Dictionary = ModelActorScript.create(handle)
	if not bool(model_result.get("ok", false)):
		return _error(str(model_result.get("error_code", "package_model_relation_invalid")))
	var claim: Dictionary = handle.claim_for_match(str(match_id))
	if not bool(claim.get("ok", false)):
		return _error(str(claim.get("error_code", "package_handle_already_claimed")))
	var script: GDScript = load("res://scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorMatchHost.gd")
	var host: Variant = script.new(handle, str(match_id), ir_outcome.get("ir"), adapter_outcome.get("adapter"), model_result.get("owner"), _FACTORY_TOKEN)
	return {"ok": true, "error_code": "", "host": host}


func _init(handle: Variant = null, match_id: String = "", ir: Variant = null, adapter: Variant = null, model_actor: Variant = null, token: Variant = null) -> void:
	if token != _FACTORY_TOKEN:
		return
	_handle = handle
	_match_id = match_id
	_ir = ir
	_adapter = adapter
	_model_actor = model_actor
	_factory_token = token


func is_author_owner_ready() -> bool:
	return _factory_token == _FACTORY_TOKEN and _handle != null and _handle.validate_integrity() and _current_prompt == null


func card_id_domain() -> String:
	if _factory_token != _FACTORY_TOKEN or _adapter == null:
		return ""
	return str(_adapter.get("card_id_domain"))


func open_current_prompt(source: Variant) -> Dictionary:
	if _factory_token != _FACTORY_TOKEN or source == null or not source.has_method("validate_integrity") or not source.validate_integrity():
		return _error("invalid_prompt_authority")
	if _current_prompt != null:
		return _error("prompt_already_open")
	var local_context: Variant = source.local_uid_public_context() if source.has_method("local_uid_public_context") else null
	if _adapter.get("card_id_domain") == LOCAL_CARD_ID_DOMAIN:
		if not local_context is Dictionary:
			return _error("invalid_local_uid_public_context")
	elif local_context != null:
		return _error("invalid_local_uid_public_context")
	var snapshot: Dictionary = source.snapshot()
	var prompt_key := "%s:%s" % [snapshot.get("prompt_id"), snapshot.get("prompt_generation")]
	if _consumed_prompt_ids.has(prompt_key):
		return _error("prompt_already_consumed")
	var claim: Dictionary = source.claim_for_match(_match_id)
	if not bool(claim.get("ok", false)):
		return _error(str(claim.get("error_code", "prompt_already_consumed")))
	_current_prompt = source
	return {"ok": true, "error_code": ""}


func request_current_selection() -> Dictionary:
	var source: Variant = _current_prompt
	if source == null or not source.has_method("validate_integrity") or not source.validate_integrity():
		_current_prompt = null
		return _error("prompt_not_open")
	var prompt: Dictionary = source.snapshot()
	var base_id := "%s.%s.%s" % [_match_id, prompt.get("prompt_id"), prompt.get("prompt_generation")]
	if base_id.length() > 105:
		_current_prompt = null
		return _error("invalid_prompt_authority")
	var pins: Dictionary = _handle.to_public_dict()
	var request := {
		"orchestration_id": base_id + ".orchestration",
		"proposal_id": base_id + ".proposal",
		"execution_id": base_id + ".execution",
		"scene_id": base_id + ".scene",
		"decision_id": base_id + ".decision",
		"determinism_key": base_id + ".determinism",
		"trace_id": base_id + ".trace",
		"policy_hash": pins.get("policy_ir_sha256"),
		"mandatory_indexes": prompt.get("mandatory_indexes", []).duplicate(true),
		"terminal_indexes": prompt.get("terminal_indexes", []).duplicate(true),
		"base_hard_tiers": prompt.get("base_hard_tiers", []).duplicate(true),
		"base_vetoed_indexes": prompt.get("base_vetoed_indexes", []).duplicate(true),
	}
	var context: Variant = source.context_owner()
	var window: Variant = source.window_owner()
	var adapter: Variant = _adapter
	if _adapter.get("card_id_domain") == LOCAL_CARD_ID_DOMAIN:
		var bound: Variant = PublicDeckAdapterScript.bind_local_context(_adapter, context, source.local_uid_public_context())
		if bound == null or not bool(bound.get("accepted")) or bound.get("adapter") == null:
			_current_prompt = null
			return _error("invalid_local_uid_public_context")
		adapter = bound.get("adapter")
	var outcome: Variant = PublicBasePolicyScript.orchestrate(context, window, _ir, adapter, request)
	_current_prompt = null
	var prompt_key := "%s:%s" % [prompt.get("prompt_id"), prompt.get("prompt_generation")]
	_consumed_prompt_ids[prompt_key] = true
	if outcome == null or not bool(outcome.get("accepted")) or outcome.get("result") == null:
		return _error("shadow_policy_failed")
	var base: Dictionary = outcome.get("result").to_public_dict()
	var context_public: Dictionary = context.to_public_dict()
	var result_value: Variant = outcome.get("result")
	var rule_indexes: Array = result_value.agent_output()
	var model_decision: Dictionary = (
		_model_actor.decide(context, source.local_uid_public_context(), prompt, rule_indexes)
		if _model_actor != null
		else {"selected_indexes":rule_indexes, "model_used":false, "diagnostic_code":"model_unavailable", "elapsed_us":0, "model_manifest_sha256":null, "model_artifact_sha256":null}
	)
	var selected_indexes: Array = model_decision.get("selected_indexes", rule_indexes).duplicate()
	var audit := {
		"schema_version": 1,
		"profile_id": PROFILE_ID,
		"match_id": _match_id,
		"prompt_id": prompt.get("prompt_id"),
		"prompt_generation": prompt.get("prompt_generation"),
		"package": {
			"package_id": pins.get("package_id"),
			"package_version": pins.get("package_version"),
			"archive_sha256": pins.get("archive_sha256"),
		},
		"pins": {
			"manifest_sha256": pins.get("manifest_sha256"),
			"files_manifest_sha256": pins.get("files_manifest_sha256"),
			"cabt_contract_sha256": pins.get("cabt_contract_sha256"),
			"card_catalog_sha256": pins.get("card_catalog_sha256"),
			"base_executor_sha256": pins.get("base_executor_sha256"),
			"policy_ir_sha256": pins.get("policy_ir_sha256"),
			"adapter_sha256": pins.get("adapter_sha256"),
			"config_sha256": pins.get("config_sha256"),
			"weights_sha256": pins.get("weights_sha256"),
			"backend_sha256": pins.get("backend_sha256"),
			"deck_manifest_sha256": pins.get("deck_manifest_sha256"),
			"deck_csv_sha256": pins.get("deck_csv_sha256"),
			"local_deck_mapping_sha256": pins.get("local_deck_mapping_sha256"),
		},
		"source": {
			"public_observation_hash": window.get("public_observation_hash"),
			"window_id": window.get("window_id"),
			"context_hash": context_public.get("context_hash"),
			"orchestration_hash": base.get("orchestration_hash"),
			"decision_audit_id": result_value.get("decision").get("audit_id"),
			"trace_hash": result_value.get("trace").get("trace_hash"),
		},
		"selected_indexes": selected_indexes,
		"status": "shadow_selected",
		"diagnostic_code": str(model_decision.get("diagnostic_code", "")),
		"model": {
			"invoked": bool(model_decision.get("model_used", false)),
			"fallback_indexes": rule_indexes,
			"elapsed_us": int(model_decision.get("elapsed_us", 0)),
			"model_manifest_sha256": model_decision.get("model_manifest_sha256"),
			"model_artifact_sha256": model_decision.get("model_artifact_sha256"),
		},
		"public_only": true,
		"development_shadow": true,
		"execution_trusted": false,
		"authoritative": false,
		"classic_fallback_used": false,
	}
	if adapter.get("card_id_domain") == LOCAL_CARD_ID_DOMAIN:
		audit["source"]["card_id_domain"] = LOCAL_CARD_ID_DOMAIN
		audit["source"]["local_uid_contract_sha256"] = PublicDeckAdapterScript.EXPECTED_LOCAL_BUNDLE_SHA256
		audit["source"]["local_uid_public_context_hash"] = adapter.get("local_context_hash")
	audit["audit_hash"] = _domain_hash(audit)
	var result := ShadowResult.new(audit, _RESULT_TOKEN)
	if not result.validate_integrity():
		return _error("shadow_audit_integrity_invalid")
	return {"ok": true, "error_code": "", "result": result}


func abort_current_prompt(error_code: Variant) -> Dictionary:
	if typeof(error_code) != TYPE_STRING or str(error_code).is_empty() or str(error_code).length() > 128:
		return _error("invalid_abort_code")
	_current_prompt = null
	return {"ok": true, "error_code": ""}


static func validate_shadow_result(value: Variant) -> bool:
	if not value is ShadowResult or value.get("_factory_token") != _RESULT_TOKEN or not value.get("_snapshot") is Dictionary:
		return false
	var snapshot: Dictionary = value.get("_snapshot").duplicate(true)
	var digest: Variant = snapshot.get("audit_hash")
	snapshot.erase("audit_hash")
	return _is_sha(digest) and digest == _domain_hash(snapshot)


static func _domain_hash(payload: Dictionary) -> String:
	var canonical: Dictionary = CabtJsonTreeScript.canonicalize_artifact_json_bytes(JSON.stringify(payload).to_utf8_buffer())
	if not bool(canonical.get("ok", false)):
		return ""
	var bytes := _hex_bytes(AUDIT_PREFIX_UTF8_HEX)
	bytes.append_array(canonical.get("bytes", PackedByteArray()))
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode().to_upper()


static func _hex_bytes(value: String) -> PackedByteArray:
	var result := PackedByteArray()
	for index in range(0, value.length(), 2):
		result.append(str("0x" + value.substr(index, 2)).hex_to_int())
	return result


static func _identifier(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or str(value).is_empty() or str(value).length() > 128:
		return false
	for index in range(str(value).length()):
		var character := str(value).substr(index, 1)
		var code := character.unicode_at(0)
		var alphanumeric := (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122)
		if (index == 0 and not alphanumeric) or (index > 0 and not alphanumeric and character not in [".", "_", "-"]):
			return false
	return true


static func _is_sha(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or str(value).length() != 64:
		return false
	for character in str(value):
		if character not in "0123456789ABCDEF":
			return false
	return true


static func _error(code: String) -> Dictionary:
	return {"ok": false, "error_code": code, "host": null, "result": null}
