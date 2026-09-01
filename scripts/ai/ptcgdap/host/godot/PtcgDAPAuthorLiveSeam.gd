class_name PtcgDAPAuthorLiveSeam
extends RefCounted

const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")
const CabtSelectionSanitizerScript = preload("res://scripts/ai/ptcgdap/cabt/CabtSelectionSanitizer.gd")
const CabtDeterministicFallbackScript = preload("res://scripts/ai/ptcgdap/cabt/CabtDeterministicFallback.gd")
const FirewallScript = preload("res://scripts/ai/ptcgdap/public/PublicObservationFirewall.gd")
const EngineDecisionPortScript = preload("res://scripts/engine/decision/EngineDecisionPort.gd")
const GodotOptionBindingScript = preload("res://scripts/engine/decision/GodotOptionBinding.gd")
const ShadowPromptBrokerScript = preload("res://scripts/engine/decision/ShadowPromptBroker.gd")
const GodotObservationProjectorScript = preload("res://scripts/ai/ptcgdap/host/godot/GodotObservationProjector.gd")
const PromptSourceScript = preload("res://scripts/ai/ptcgdap/host/godot/AuthorStrategyLivePromptSource.gd")
const LiveCommandScript = preload("res://scripts/ai/ptcgdap/host/godot/AuthorStrategyLiveCommand.gd")
const HostScript = preload("res://scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorMatchHost.gd")

const PROFILE_ID := "ptcgdap-author-strategy-live-seam-as-wp5-v1"
const EXPECTED_BUNDLE_SHA256 := "5CDC360999A23A2CADCAC6E7FA8D81549566DFABE37B2DB4F813C0C5189C3E16"
const BUNDLE_PATH := "res://contracts/ptcgdap/author_strategy_live_seam_bundle.json"
const EXPECTED_ARTIFACTS := {
	"author_strategy_live_seam.schema": ["res://contracts/ptcgdap/author_strategy_live_seam.schema.json", "BFC814B80EB1AE68107C407756F13C034135D7A4D1B748D5F1355B3F782C8FC2"],
	"author_strategy_live_seam_profile": ["res://contracts/ptcgdap/author_strategy_live_seam_profile.json", "C83A69D91B2C2B3CC936253BF8E7C4E13EDB76212E85769ED4CF98BC4A87BE16"],
	"author_strategy_live_seam_conformance_vectors": ["res://contracts/ptcgdap/author_strategy_live_seam_conformance_vectors.json", "58B5752C4504D9E64EF9F86DF2AA5BAB1169CDA4EDCAFAD70683CBFF74442F39"],
}
const HASH_PREFIX_HEX := "5054434744415000415554484F525F4C4956455F5345414D5F5749544E4553535F563100"
static var _FACTORY_TOKEN: RefCounted = RefCounted.new()

var _ok := false
var _error_code := "live_seam_contract_error"
var _profile: Dictionary = {}
var _host: Variant = null
var _match_generation := 0
var _session_id := ""
var _port: Variant = null
var _binding_owner: Variant = null
var _broker: Variant = null
var _consumed_sources: Array[WeakRef] = []
var _factory_token: Variant = null
var _last_development_diagnostic: Dictionary = {}

var contract_hash: String:
	get: return EXPECTED_BUNDLE_SHA256 if _ok else ""
var error_code: String:
	get: return _error_code


static func create(host: Variant, match_generation: Variant, session_id: Variant) -> Dictionary:
	if not _exact_script(host, HostScript):
		return _error("invalid_live_owner")
	if typeof(match_generation) != TYPE_INT or int(match_generation) < 1:
		return _error("invalid_live_owner")
	if not _valid_session(session_id):
		return _error("invalid_live_owner")
	var script: GDScript = load("res://scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorLiveSeam.gd")
	var seam: Variant = script.new()
	if not seam.validate_integrity():
		return _error("live_seam_contract_error")
	seam._host = host
	seam._match_generation = int(match_generation)
	seam._session_id = str(session_id)
	seam._port = EngineDecisionPortScript.open_match(int(match_generation))
	seam._binding_owner = GodotOptionBindingScript.new()
	seam._broker = ShadowPromptBrokerScript.new(int(match_generation), str(session_id))
	seam._factory_token = _FACTORY_TOKEN
	if not seam.validate_integrity() or not seam._owner_ready():
		return _error("invalid_live_owner")
	return {"ok": true, "error_code": "", "seam": seam}


func _init() -> void:
	var loaded := _load_contracts()
	_ok = bool(loaded.get("ok", false))
	_error_code = "" if _ok else "live_seam_contract_error"
	_profile = loaded.get("profile", {})


func validate_integrity() -> bool:
	if not _ok or _error_code != "" or _canonical_hash(_profile) != EXPECTED_ARTIFACTS["author_strategy_live_seam_profile"][1]:
		return false
	if _factory_token == null:
		return true
	return (
		_factory_token == _FACTORY_TOKEN
		and _exact_script(_host, HostScript)
		and _exact_script(_port, EngineDecisionPortScript)
		and _exact_script(_binding_owner, GodotOptionBindingScript)
		and _exact_script(_broker, ShadowPromptBrokerScript)
		and _port.validate_integrity()
		and _binding_owner.contract_hash == GodotOptionBindingScript.EXPECTED_BUNDLE_SHA256
		and _binding_owner.error_code == ""
		and _broker.validate_integrity()
	)


func run_setup_active(source: Variant, fault: String = "none") -> Dictionary:
	if not _owner_ready():
		return _reject("invalid_live_owner")
	if not _exact_script(source, PromptSourceScript):
		return _reject("unsupported_prompt_family")
	if _source_consumed(source):
		return _reject("replay_rejected")
	if not source.validate_integrity() or not source.validate_current():
		return _reject("prompt_changed")
	if source.match_generation() != _match_generation:
		return _reject("invalid_engine_prompt")
	var current_source: Dictionary = source.port_source()
	var window: Variant = source.window_owner()
	var publish: Variant = _port.publish(current_source, source.decision_generation(), source.chooser_player_index())
	if publish == null or not publish.accepted:
		return _reject("invalid_engine_prompt")
	var snapshot: Variant = publish.snapshot
	var callback_hash: String = source.callback_binding_hash()
	var bind_result: Variant = _binding_owner.bind(
		_port, snapshot, current_source, window, callback_hash,
		source.private_commands(), source.private_object_refs()
	)
	if bind_result == null or not bind_result.accepted:
		return _reject("binding_rejected")
	var binding: Variant = bind_result.binding
	var opened: Variant = _broker.open_prompt(
		"W1", _port, snapshot, _binding_owner, binding,
		current_source, window, callback_hash
	)
	if opened == null or not opened.accepted:
		return _reject("broker_rejected")
	_mark_consumed(source)
	var host_attempt := {"status": "unavailable", "output": null}
	if fault in ["policy_exception", "active_already_present"]:
		host_attempt = {"status": "exception", "output": null}
	elif fault == "illegal_output":
		host_attempt = {"status": "returned", "output": [window.option_count]}
	elif fault == "none":
		var host_open: Dictionary = _host.open_current_prompt(source.host_prompt_owner())
		if bool(host_open.get("ok", false)):
			var host_result: Dictionary = _host.request_current_selection()
			var result: Variant = host_result.get("result")
			if bool(host_result.get("ok", false)) and result != null and result.validate_integrity():
				host_attempt = {"status": "returned", "output": result.indexes}
			else:
				host_attempt = {"status": "exception", "output": null}
		else:
			host_attempt = {"status": "exception", "output": null}
	else:
		return _reject("invalid_engine_prompt")
	var resolution: Variant = CabtSelectionSanitizerScript.resolve_policy_attempt(window, host_attempt)
	if not CabtDeterministicFallbackScript.validate_resolution_integrity(resolution, window):
		return _reject("host_rejected")
	if not source.validate_current() or not source.revalidate_public_window():
		return _reject("prompt_changed")
	var prepared: Variant = _broker.prepare_selection(opened.prompt, resolution)
	if prepared == null or not prepared.accepted:
		return _reject("preflight_rejected")
	if not source.validate_current():
		return _reject("prompt_changed")
	var committed: Variant = _broker.commit_prompt(prepared.prompt)
	if committed == null or not committed.accepted or committed.prompt.state != "awaiting_reobserve":
		return _reject("commit_rejected")
	var resolutions: Array = committed.private_resolutions
	if resolutions.size() != 1:
		return _reject("commit_rejected")
	var private_resolution: Variant = resolutions[0]
	var command: Variant = private_resolution.private_engine_command
	if not _exact_script(command, LiveCommandScript) or not command.validate_current():
		return _reject("prompt_changed")
	if fault == "active_already_present":
		return _reject("engine_apply_rejected")
	var selected_private_refs: Array = private_resolution.private_object_refs
	if selected_private_refs.size() != 1:
		return _reject("commit_rejected")
	var selected_card: Variant = selected_private_refs[0]
	var selected_indexes: Array = resolution.selected_indexes
	var snapshot_id: String = snapshot.snapshot_id
	var window_id: String = window.window_id
	var public_hash: String = window.public_observation_hash
	var selection_source := "policy" if resolution.owner == "policy" else "deterministic_fallback"
	if not command.execute_once():
		return _reject("engine_apply_rejected")
	var next_sources: Dictionary = source.setup_bench_reobserve_sources()
	if next_sources.is_empty():
		return _reject("reobserve_rejected")
	var next_projector_source: Dictionary = next_sources.get("projector_source", {})
	var next_port_source: Dictionary = next_sources.get("port_source", {})
	var next_events: Array = source.public_events()
	next_events.append({"kind": "play", "card_ref": selected_card})
	var projector: Variant = source.projector_owner()
	var reobserved: Variant = projector.capture_engine(
		source.game_state_machine_owner().game_state,
		source.registry_owner(),
		next_projector_source,
		next_events,
		source.source_documents_owner().documents(),
		null,
		null,
		source.chooser_player_index()
	)
	if reobserved == null or not reobserved.accepted:
		_last_development_diagnostic = {
			"stage": projector.get("_capture_stage") if projector != null else "missing_projector",
			"projector_error_code": reobserved.error_code if reobserved != null else "missing_result",
		}
		return _reject("reobserve_rejected")
	var invalidator: Variant = _port.publish(
		next_port_source, source.decision_generation() + 1, source.chooser_player_index()
	)
	if invalidator == null or not invalidator.accepted:
		return _reject("reobserve_rejected")
	var old_rebind: Dictionary = _port.rebind(snapshot, current_source)
	var old_invalidated: bool = (
		not bool(old_rebind.get("ok", false))
		and _port.current_snapshot() != snapshot
		and not binding.validate_integrity(_binding_owner)
	)
	if not old_invalidated:
		return _reject("reobserve_rejected")
	var witness := {
		"schema_version": 1,
		"profile_id": PROFILE_ID,
		"accepted": true,
		"error_code": "",
		"prompt_family": "W1",
		"callback_role": "setup_active",
		"match_generation": _match_generation,
		"decision_generation": source.decision_generation(),
		"snapshot_id": snapshot_id,
		"window_id": window_id,
		"public_observation_hash": public_hash,
		"selected_indexes": selected_indexes.duplicate(true),
		"selection_source": selection_source,
		"broker_state": "awaiting_reobserve",
		"engine_applied": true,
		"reobserved": true,
		"old_authority_invalidated": true,
		"development_canary": true,
		"player_package_authority": false,
		"classic_fallback_used": false,
	}
	witness["witness_hash"] = _domain_hash(witness)
	return {"ok": true, "error_code": "", "witness": witness}


func last_development_diagnostic() -> Dictionary:
	return _last_development_diagnostic.duplicate(true)


func owns_author_host(host: Variant) -> bool:
	return _factory_token == _FACTORY_TOKEN and host != null and host == _host


func is_bound_owner_ready() -> bool:
	return _owner_ready()


func uses_local_uid_domain() -> bool:
	return _owner_ready() and _host.card_id_domain() == "godot_local_card_uid_v1"


func _owner_ready() -> bool:
	return validate_integrity() and _factory_token == _FACTORY_TOKEN and _match_generation >= 1 and _valid_session(_session_id)


func _source_consumed(source: Variant) -> bool:
	for reference: WeakRef in _consumed_sources:
		if reference.get_ref() == source:
			return true
	return false


func _mark_consumed(source: Variant) -> void:
	_consumed_sources.append(weakref(source))


func _load_contracts() -> Dictionary:
	var bundle_result := _read_json(BUNDLE_PATH)
	if not bool(bundle_result.get("ok", false)):
		return {"ok": false}
	var bundle: Dictionary = bundle_result.get("value")
	if _canonical_hash(bundle) != EXPECTED_BUNDLE_SHA256 or bundle.get("bundle_id") != PROFILE_ID or bundle.get("profile_id") != PROFILE_ID:
		return {"ok": false}
	var entries: Variant = bundle.get("artifacts")
	if not entries is Array or entries.size() != EXPECTED_ARTIFACTS.size():
		return {"ok": false}
	var profile := {}
	var seen := {}
	for entry_value: Variant in entries:
		if not entry_value is Dictionary:
			return {"ok": false}
		var artifact_id: Variant = entry_value.get("id")
		if typeof(artifact_id) != TYPE_STRING or not EXPECTED_ARTIFACTS.has(artifact_id) or seen.has(artifact_id):
			return {"ok": false}
		var expected: Array = EXPECTED_ARTIFACTS[artifact_id]
		if "res://" + str(entry_value.get("path")) != expected[0] or entry_value.get("canonical_sha256") != expected[1]:
			return {"ok": false}
		var artifact := _read_json(expected[0])
		if not bool(artifact.get("ok", false)) or _canonical_hash(artifact.get("value")) != expected[1]:
			return {"ok": false}
		seen[artifact_id] = true
		if artifact_id == "author_strategy_live_seam_profile":
			profile = artifact.get("value")
	if seen.size() != EXPECTED_ARTIFACTS.size() or profile.get("enabled_prompt_families") != ["W1"]:
		return {"ok": false}
	if bool(profile.get("trust_scope", {}).get("player_package_execution", true)):
		return {"ok": false}
	return {"ok": true, "profile": profile}


static func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "value": null}
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	return FirewallScript._parse_contract_json_bytes(bytes)


static func _canonical_hash(value: Variant) -> String:
	var canonical: Dictionary = CabtJsonTreeScript.canonicalize_artifact(value)
	if not bool(canonical.get("ok", false)):
		return ""
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(canonical.get("bytes", PackedByteArray()))
	return context.finish().hex_encode().to_upper()


static func _domain_hash(value: Dictionary) -> String:
	var canonical: Dictionary = CabtJsonTreeScript.canonicalize_artifact(value)
	if not bool(canonical.get("ok", false)):
		return ""
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(_hex_bytes(HASH_PREFIX_HEX))
	context.update(canonical.get("bytes", PackedByteArray()))
	return context.finish().hex_encode().to_upper()


static func _hex_bytes(value: String) -> PackedByteArray:
	var result := PackedByteArray()
	for index: int in range(0, value.length(), 2):
		result.append(str("0x" + value.substr(index, 2)).hex_to_int())
	return result


static func _valid_session(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or not str(value).begins_with("session:"):
		return false
	var suffix := str(value).trim_prefix("session:")
	if suffix.is_empty() or suffix.length() > 64:
		return false
	for character: String in suffix:
		var code := character.unicode_at(0)
		var alphanumeric := (code >= 48 and code <= 57) or (code >= 97 and code <= 122)
		if not alphanumeric and character not in ["_", "-"]:
			return false
	return true


static func _exact_script(value: Variant, expected: GDScript) -> bool:
	return value != null and typeof(value) == TYPE_OBJECT and value.get_script() == expected


static func _reject(code: String) -> Dictionary:
	return {"ok": false, "error_code": code, "witness": null}


static func _error(code: String) -> Dictionary:
	return {"ok": false, "error_code": code, "seam": null}
