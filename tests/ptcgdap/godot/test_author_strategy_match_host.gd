class_name TestAuthorStrategyMatchHost
extends TestBase

const CatalogScript = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageCatalog.gd")
const LoaderScript = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageLoader.gd")
const DeckGateScript = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyDeckGate.gd")
const HandleScript = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageHandle.gd")
const PromptScript = preload("res://scripts/ai/ptcgdap/host/godot/AuthorStrategyShadowPrompt.gd")
const HostScript = preload("res://scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorMatchHost.gd")
const FactoryScript = preload("res://scripts/ui/battle/ai/BattleDecisionOwnerFactory.gd")
const FirewallScript = preload("res://scripts/ai/ptcgdap/public/PublicObservationFirewall.gd")
const StrategicContextScript = preload("res://scripts/ai/ptcgdap/public/StrategicContextV18.gd")
const PublicDeckAdapterScript = preload("res://scripts/ai/ptcgdap/public/PublicDeckAdapter.gd")
const CabtContractSetScript = preload("res://scripts/ai/ptcgdap/cabt/CabtContractSet.gd")
const CabtObservationParserScript = preload("res://scripts/ai/ptcgdap/cabt/CabtObservationParser.gd")
const CabtSelectionWindowScript = preload("res://scripts/ai/ptcgdap/cabt/CabtSelectionWindow.gd")
const PolicyPackageManifestScript = preload("res://scripts/ai/ptcgdap/runtime/local/PolicyPackageManifest.gd")

const FIXTURE_PATH := "res://tests/ptcgdap/fixtures/author_strategy_packages/as_wp4/00-exact-mapped-shadow.ptcgai"
const MARNIE_WINDOWS_PATH := "res://data/ptcgdap/author_strategy_packages/ptcgdap-author-strategy-release-candidate.ptcgai"
const REPLACEMENT_PATH := "res://tests/ptcgdap/fixtures/author_strategy_packages/as_wp2/01-valid_manifest_whitespace_identity.ptcgai"
const VECTOR_PATH := "res://contracts/ptcgdap/author_strategy_match_host_conformance_vectors.json"
const LOCAL_CONTEXT_VECTOR_PATH := "res://contracts/ptcgdap/local_uid_public_context_conformance_vectors.json"
const FIREWALL_VECTOR_PATH := "res://contracts/ptcgdap/cabt_public_firewall_conformance_vectors.json"
const USER_DIR := "user://ptcgdap/author_strategy_packages"
const USER_PACKAGE := USER_DIR + "/as-wp4-test.ptcgai"

var _handle_templates := {}


func _read_bytes(path: String) -> PackedByteArray:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_buffer(file.get_length()) if file != null else PackedByteArray()


func _read_json(path: String) -> Dictionary:
	var parsed: Dictionary = FirewallScript._parse_contract_json_bytes(_read_bytes(path))
	var value: Variant = parsed.get("value") if bool(parsed.get("ok", false)) else null
	return value if value is Dictionary else {}


func _write_user_package(bytes: PackedByteArray) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(USER_DIR))
	var file := FileAccess.open(USER_PACKAGE, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	file.close()
	return true


func _cleanup_user_package() -> void:
	if FileAccess.file_exists(USER_PACKAGE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(USER_PACKAGE))


func _record_by_package_id(report: Dictionary, package_id: String) -> Dictionary:
	var match_record: Dictionary = {}
	for value: Variant in report.get("metadata_records", []):
		if not value is Dictionary or value.get("package_id") != package_id:
			continue
		if not match_record.is_empty():
			return {}
		match_record = value
	return match_record


func _fixture_identity() -> Dictionary:
	_cleanup_user_package()
	if not _write_user_package(_read_bytes(FIXTURE_PATH)):
		return {}
	var catalog := CatalogScript.new()
	var report: Dictionary = catalog.rebuild_from_paths_for_test([{
		"archive_path": USER_PACKAGE,
		"install_source": "user",
		"location_id": "as-wp4-test.ptcgai",
	}])
	var record := _record_by_package_id(report, "test.fixture.mapped-shadow")
	if record.is_empty():
		return {"error": "metadata", "catalog": catalog, "report": report}
	return {
		"catalog": catalog,
		"package_id": record.get("package_id"),
		"package_version": record.get("package_version"),
		"archive_sha256": record.get("archive_sha256"),
	}


func _fresh_handle(path: String) -> Dictionary:
	if not _handle_templates.has(path):
		var captured := _read_bytes(path)
		if captured.is_empty():
			return {"ok": false, "error_code": "package_file_missing"}
		var loader := LoaderScript.new()
		var inspected: Dictionary = loader.inspect_match_bytes(captured, _sha(captured))
		if not bool(inspected.get("ok", false)):
			return inspected
		var gated: Dictionary = DeckGateScript.build(inspected.get("payloads", {}))
		if not bool(gated.get("ok", false)):
			return gated
		_handle_templates[path] = {
			"metadata": inspected.get("metadata", {}).duplicate(true),
			"payloads": inspected.get("payloads", {}).duplicate(true),
			"local_deck": gated.get("local_deck", []).duplicate(true),
		}
	var template: Dictionary = _handle_templates[path]
	return HandleScript.create(
		template.get("metadata", {}).duplicate(true),
		template.get("payloads", {}).duplicate(true),
		template.get("local_deck", []).duplicate(true),
	)


static func _sha(source: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(source) != OK:
		return ""
	return context.finish().hex_encode().to_upper()


func _apply_path_mutation(root: Variant, mutation: Dictionary) -> void:
	var path: Array = mutation.get("path", [])
	var parent: Variant = root
	for index: int in range(path.size() - 1):
		parent = parent[path[index]]
	var key: Variant = path[-1]
	match str(mutation.get("op")):
		"set": parent[key] = mutation.get("value").duplicate(true) if mutation.get("value") is Dictionary or mutation.get("value") is Array else mutation.get("value")
		"delete": parent.erase(key)
		"append": parent[key].append(mutation.get("value").duplicate(true) if mutation.get("value") is Dictionary or mutation.get("value") is Array else mutation.get("value"))


func _context_window() -> Dictionary:
	var firewall_vectors := _read_json(FIREWALL_VECTOR_PATH)
	var spec: Dictionary = {}
	for value: Variant in firewall_vectors.get("cases", []):
		if value is Dictionary and value.get("id") == "regular-accepted":
			spec = value
			break
	var raw: Dictionary = firewall_vectors.get("base_observations", {}).get(spec.get("base"), {}).duplicate(true)
	for mutation: Variant in spec.get("mutations", []):
		_apply_path_mutation(raw, mutation)
	var contracts: Variant = CabtContractSetScript.load_default()
	var parsed: Variant = CabtObservationParserScript.parse_raw_cabt_envelope(raw, contracts)
	var firewall_result: Variant = FirewallScript.load_default().project(parsed)
	var public: Dictionary = firewall_result.get("public_observation")
	var current: Dictionary = public.get("current")
	var built: Variant = CabtSelectionWindowScript.build(
		{
			"public_observation_hash": firewall_result.get("public_observation_hash"),
			"public_hash_authority": "firewall_accepted",
			"chooser_player_index": current.get("yourIndex"),
			"select": public.get("select").duplicate(true),
		},
		contracts,
	)
	var window: Variant = built.get("window")
	var context: Variant = StrategicContextScript.build_context(firewall_result, window).get("context")
	return {"context": context, "window": window}


func _prompt(case: Dictionary) -> Dictionary:
	var owners := _context_window()
	return PromptScript.create(
		owners.context,
		owners.window,
		case.get("prompt_id"),
		case.get("prompt_generation"),
		case.get("mandatory_indexes", []).duplicate(true),
		case.get("terminal_indexes", []).duplicate(true),
		case.get("base_hard_tiers", []).duplicate(true),
		case.get("base_vetoed_indexes", []).duplicate(true),
	)


func test_match_request_recaptures_bytes_and_seals_copy_isolated_full_pins() -> String:
	var setup := _fixture_identity()
	if setup.has("error") or setup.is_empty():
		_cleanup_user_package()
		return "fixture catalog failed: %s" % str(setup.get("report", {}))
	var requested: Dictionary = setup.catalog.request_match_handle(setup.package_id, setup.package_version, setup.archive_sha256)
	setup.catalog.free()
	_cleanup_user_package()
	if not bool(requested.get("ok", false)):
		return "match request rejected: %s" % requested.get("error_code")
	var handle: Variant = requested.get("handle")
	if handle == null or not handle.validate_integrity():
		return "invalid handle"
	var pins: Dictionary = handle.to_public_dict()
	if pins.get("package_id") != "test.fixture.mapped-shadow" or pins.get("local_deck_card_count") != 60 or pins.get("local_deck_unique_printing_count") != 9:
		return "deck pins mismatch: %s" % str(pins)
	if pins.get("execution_trusted") != false or pins.get("development_shadow_ready") != true or pins.get("live_authority") != false:
		return "trust scope drift: %s" % str(pins)
	for key: String in ["archive_sha256", "manifest_sha256", "files_manifest_sha256", "cabt_contract_sha256", "card_catalog_sha256", "base_executor_sha256", "policy_ir_sha256", "adapter_sha256", "config_sha256", "backend_sha256", "deck_manifest_sha256", "deck_csv_sha256", "local_deck_mapping_sha256"]:
		if str(pins.get(key, "")).length() != 64:
			return "missing pin %s" % key
	var local: Array = handle.local_deck_snapshot()
	local[0].count = 999
	if handle.local_deck_snapshot()[0].count != 28:
		return "local deck copy leaked"
	return ""


func test_deleted_and_replaced_archives_fail_closed_before_handle() -> String:
	var setup := _fixture_identity()
	if setup.has("error") or setup.is_empty():
		_cleanup_user_package()
		return "fixture catalog failed"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(USER_PACKAGE))
	var deleted: Dictionary = setup.catalog.request_match_handle(setup.package_id, setup.package_version, setup.archive_sha256)
	if deleted.get("ok") or deleted.get("handle") != null or deleted.get("error_code") != "package_file_missing":
		return "delete did not fail closed: %s" % str(deleted)
	if not _write_user_package(_read_bytes(REPLACEMENT_PATH)):
		return "replacement write failed"
	var replaced: Dictionary = setup.catalog.request_match_handle(setup.package_id, setup.package_version, setup.archive_sha256)
	setup.catalog.free()
	_cleanup_user_package()
	if replaced.get("ok") or replaced.get("handle") != null or replaced.get("error_code") != "package_integrity_invalid":
		return "replacement did not fail closed: %s" % str(replaced)
	return ""


func test_exact_deck_gate_rejects_energy_only_package_and_handle_tamper() -> String:
	_cleanup_user_package()
	if not _write_user_package(_read_bytes(REPLACEMENT_PATH)):
		return "energy-only fixture write failed"
	var catalog := CatalogScript.new()
	var report: Dictionary = catalog.scan_startup()
	var record := _record_by_package_id(report, "test.fixture.author-ai")
	if record.is_empty():
		_cleanup_user_package()
		return "energy-only fixture did not reach metadata: %s" % str(report)
	var rejected: Dictionary = catalog.request_match_handle(record.package_id, record.package_version, record.archive_sha256)
	catalog.free()
	_cleanup_user_package()
	if rejected.get("ok") or rejected.get("handle") != null or rejected.get("error_code") != "package_deck_unmapped":
		return "exact deck gate accepted energy-only deck: %s" % str(rejected)
	var setup := _fixture_identity()
	if setup.has("error") or setup.is_empty():
		_cleanup_user_package()
		return "mapped fixture catalog failed"
	var accepted: Dictionary = setup.catalog.request_match_handle(setup.package_id, setup.package_version, setup.archive_sha256)
	setup.catalog.free()
	_cleanup_user_package()
	var handle: Variant = accepted.get("handle")
	if handle == null or not handle.validate_integrity():
		return "mapped handle missing: %s" % str(accepted)
	var pins: Dictionary = handle.get("_pins").duplicate(true)
	pins["local_deck_card_count"] = 59
	handle.set("_pins", pins)
	if handle.validate_integrity() or not handle.to_public_dict().is_empty() or not handle.local_deck_snapshot().is_empty():
		return "tampered handle retained authority"
	return ""


func test_shared_shadow_vectors_match_exact_indexes_and_audits() -> String:
	var vectors := _read_json(VECTOR_PATH)
	var cases: Array = vectors.get("shadow_cases", [])
	for case_index: int in cases.size():
		print("AuthorStrategyMatchHost vector %d/%d" % [case_index + 1, cases.size()])
		var case_value: Variant = cases[case_index]
		var case: Dictionary = case_value
		var requested: Dictionary = _fresh_handle(FIXTURE_PATH)
		if not bool(requested.get("ok", false)):
			return "%s handle rejected: %s" % [case.get("id"), requested.get("error_code")]
		var built: Dictionary = HostScript.create(requested.get("handle"), case.get("match_id"))
		if not bool(built.get("ok", false)):
			return "%s host rejected: %s" % [case.get("id"), built.get("error_code")]
		var host: Variant = built.get("host")
		var opened: Dictionary = host.open_current_prompt(_prompt(case).get("prompt"))
		if opened != {"ok":true,"error_code":""}:
			return "%s prompt rejected: %s" % [case.get("id"), str(opened)]
		var selected: Dictionary = host.request_current_selection()
		var result: Variant = selected.get("result")
		if not bool(selected.get("ok", false)) or result == null or not result.validate_integrity():
			return "%s selection rejected: %s" % [case.get("id"), str(selected)]
		var actual_audit: Dictionary = result.to_public_dict()
		var expected_audit: Dictionary = case.get("expected_audit", {}).duplicate(true)
		# AS-WP4 vectors predate the additive local model telemetry. Keep their
		# public decision/audit core exact while checking the current rules-only
		# fallback witness independently; ShadowResult integrity already verifies
		# the current full-document audit hash above.
		var model: Dictionary = actual_audit.get("model", {})
		actual_audit.erase("model")
		actual_audit.erase("audit_hash")
		expected_audit.erase("audit_hash")
		var expected_indexes: Array = case.get("expected_selected_indexes", [])
		if result.indexes != expected_indexes \
			or actual_audit != expected_audit \
			or model != {
				"invoked": false,
				"fallback_indexes": expected_indexes,
				"elapsed_us": 0,
				"model_manifest_sha256": null,
				"model_artifact_sha256": null,
			}:
			return "%s output mismatch: %s" % [case.get("id"), str(result.to_public_dict())]
	return ""


func test_handle_and_prompt_are_one_match_one_use() -> String:
	var case: Dictionary = _read_json(VECTOR_PATH).get("shadow_cases", [])[0]
	var requested: Dictionary = _fresh_handle(FIXTURE_PATH)
	var handle: Variant = requested.get("handle")
	var first_build: Dictionary = HostScript.create(handle, "one-use-match")
	var second_build: Dictionary = HostScript.create(handle, "other-match")
	if not bool(first_build.get("ok", false)) or second_build.get("ok") or second_build.get("error_code") != "package_handle_already_claimed":
		return "handle claim mismatch: %s / %s" % [str(first_build), str(second_build)]
	var host: Variant = first_build.get("host")
	var prompt_result := _prompt(case)
	var source: Variant = prompt_result.get("prompt")
	if not bool(host.open_current_prompt(source).get("ok", false)):
		return "first open failed"
	if not bool(host.request_current_selection().get("ok", false)):
		return "first request failed"
	var repeat: Dictionary = host.request_current_selection()
	if repeat.get("ok") or repeat.get("error_code") != "prompt_not_open":
		return "repeat request stayed open: %s" % str(repeat)
	var replay: Dictionary = host.open_current_prompt(source)
	if replay.get("ok") or replay.get("error_code") != "prompt_already_consumed":
		return "prompt replay accepted: %s" % str(replay)
	return ""


func test_mode_factory_separates_none_classic_and_author_without_live_authority() -> String:
	var none: Dictionary = FactoryScript.build_for_mode(GameManager.GameMode.TWO_PLAYER, null, "none-match", null, null)
	if not bool(none.get("ok", false)) or none.get("owner") != null or none.get("owner_kind") != "none":
		return "two-player routing mismatch: %s" % str(none)
	var requested: Dictionary = _fresh_handle(FIXTURE_PATH)
	var author: Dictionary = FactoryScript.build_for_mode(GameManager.GameMode.VS_AUTHOR_STRATEGY_AI, requested.get("handle"), "author-match", null, null)
	if not bool(author.get("ok", false)) or author.get("owner_kind") != "author_shadow" or author.get("owner") == null:
		return "author routing mismatch: %s" % str(author)
	if author.get("execution_authority") != false or author.get("engine_command_authority") != false:
		return "author factory granted live authority"
	return ""


func test_windows_local_marnie_candidate_materializes_exact_60_without_official_card_ids() -> String:
	var requested: Dictionary = _fresh_handle(MARNIE_WINDOWS_PATH)
	if not bool(requested.get("ok", false)):
		return "Marnie candidate rejected: %s" % requested.get("error_code")
	var handle: Variant = requested.get("handle")
	var pins: Dictionary = handle.to_public_dict() if handle != null else {}
	if pins.get("deck_card_id_domain") != "godot_local_card_uid_v1" or pins.get("deck_platform_scope") != ["windows"] or pins.get("cabt_exportable") != false:
		return "Marnie identity pins mismatch: %s" % str(pins)
	if pins.get("local_deck_card_count") != 60 or pins.get("local_deck_unique_printing_count") != 28:
		return "Marnie deck pins mismatch: %s" % str(pins)
	if pins.get("signature_scope") != "test_fixture_only" or pins.get("signature_key_id") != null:
		return "Marnie signature identity pins missing: %s" % str(pins)
	if pins.get("source_deck_id") != 800018501:
		return "Marnie source deck pin missing: %s" % str(pins)
	var local: Array = handle.local_deck_snapshot()
	var allowed_uids := {}
	for row_value: Variant in local:
		if not row_value is Dictionary or not row_value.has("local_card_uid") or row_value.has("official_card_id"):
			return "Marnie local row identity drift: %s" % str(row_value)
		allowed_uids[str(row_value.get("local_card_uid"))] = true
	var documents_result: Dictionary = handle.policy_documents()
	if not bool(documents_result.get("ok", false)):
		return "Marnie policy documents missing: %s" % str(documents_result)
	var documents: Dictionary = documents_result.get("documents", {})
	var adapter: Variant = documents.get("policy/adapter.json")
	var config: Variant = documents.get("policy/config.json")
	if not adapter is Dictionary or adapter.get("adapter_id") != "ptcgdap.marnie.windows-local" or str(adapter).contains("test.fixture"):
		return "Marnie adapter identity drift: %s" % str(adapter)
	if not config is Dictionary or config.get("values", {}).get("card_id_domain") != "godot_local_card_uid_v1" or config.get("values", {}).get("deck_manifest_sha256") != pins.get("deck_manifest_sha256"):
		return "Marnie adapter/deck binding drift: %s" % str(config)
	var referenced_uids := {}
	for rule_value: Variant in adapter.get("rules", []):
		if not rule_value is Dictionary:
			return "Marnie adapter rule drift"
		var predicate: Variant = rule_value.get("predicate")
		if not predicate is Dictionary:
			return "Marnie adapter predicate drift"
		for field: String in ["option_card_id", "acting_hand_card_id", "acting_active_card_id"]:
			var card_id: Variant = predicate.get(field)
			if card_id == null:
				continue
			if typeof(card_id) != TYPE_STRING or not allowed_uids.has(str(card_id)):
				return "Marnie adapter used non-local Card ID: %s" % str(card_id)
			referenced_uids[str(card_id)] = true
	for required_uid: String in ["CSV10C_146", "CSV10C_147", "CSV10C_148", "CSV7C_177", "CSV10C_216", "CSV8C_183", "CSVE1C_DAR"]:
		if not referenced_uids.has(required_uid):
			return "Marnie adapter omitted reviewed local UID: %s" % required_uid
	var deck_manifest := _read_json("res://data/ptcgdap/marnie_vertical_slice/windows_local_deck_manifest_v1.json")
	var loader := LoaderScript.new()
	if not bool(loader.call("_public_adapter_valid", adapter, deck_manifest)):
		return "Marnie local-UID adapter rejected by Godot validator"
	for invalid_card_id: Variant in [1086, "CSV999C_999"]:
		var invalid_adapter: Dictionary = adapter.duplicate(true)
		invalid_adapter["rules"][0]["predicate"]["acting_hand_card_id"] = invalid_card_id
		if bool(loader.call("_public_adapter_valid", invalid_adapter, deck_manifest)):
			return "Godot validator accepted cross-domain Card ID: %s" % str(invalid_card_id)
	var host_attempt: Dictionary = HostScript.create(handle, "marnie-local-shadow")
	if not bool(host_attempt.get("ok", false)):
		return "local UID Host compile failed: %s" % str(host_attempt)
	var host: Variant = host_attempt.get("host")
	var owners := _context_window()
	var context_public: Dictionary = StrategicContextScript.context_public_dict(owners.context)
	var options: Array = []
	for option_value: Variant in context_public.get("select_semantics", {}).get("options", []):
		options.append({
			"index": option_value.get("index"),
			"local_card_uid": "CSV10C_146" if option_value.get("index") == 0 else null,
		})
	var acting: Dictionary = context_public.get("public_state", {}).get("acting_player", {})
	var hand: Array = []
	for card_value: Variant in acting.get("hand", []):
		hand.append({"serial": card_value.get("serial"), "local_card_uid": "CSV7C_177"})
	var active: Array = []
	for card_value: Variant in acting.get("active", []):
		active.append({"serial": card_value.get("serial"), "local_card_uid": "CSV10C_148"})
	var local_context := {
		"schema_version": 1,
		"card_id_domain": "godot_local_card_uid_v1",
		"source": {"context_hash": context_public.get("context_hash"), "window_id": context_public.get("source", {}).get("window_id")},
		"options": options,
		"acting_hand": hand,
		"acting_active": active,
	}
	var local_vectors: Dictionary = _read_json(LOCAL_CONTEXT_VECTOR_PATH)
	if local_context != local_vectors.get("accepted_case", {}).get("value"):
		return "local UID public context drifted from shared vector"
	if not PublicDeckAdapterScript.validate_local_uid_public_context(owners.context, local_context):
		return "valid local UID public context rejected"
	var non_c_suffix_uids: Array = allowed_uids.keys()
	non_c_suffix_uids.append("SVP_105")
	var non_c_suffix_compiled: Variant = PublicDeckAdapterScript.compile_local_uid(
		adapter, non_c_suffix_uids, pins.get("deck_manifest_sha256")
	)
	if non_c_suffix_compiled == null or not bool(non_c_suffix_compiled.get("accepted")):
		return "deck-valid non-C-suffix local UID rejected: %s" % str(non_c_suffix_compiled)
	var compiled: Variant = PublicDeckAdapterScript.compile_local_uid(
		adapter, allowed_uids.keys(), pins.get("deck_manifest_sha256")
	)
	if compiled == null or not bool(compiled.get("accepted")) or compiled.get("adapter") == null:
		return "local UID adapter compile rejected: %s" % str(compiled)
	var bound: Variant = PublicDeckAdapterScript.bind_local_context(compiled.get("adapter"), owners.context, local_context)
	if bound == null or not bool(bound.get("accepted")) or bound.get("adapter") == null:
		return "valid local UID public context bind rejected: %s" % str(bound)
	if bound.get("adapter").local_context_hash != local_vectors.get("accepted_case", {}).get("expected_local_context_hash"):
		return "local UID shared context hash mismatch"
	for rejected_case: Variant in local_vectors.get("rejected_cases", []):
		if not rejected_case is Dictionary:
			return "local UID rejected vector malformed"
		var invalid_context: Variant = rejected_case.get("value")
		var rejected: Variant = PublicDeckAdapterScript.bind_local_context(compiled.get("adapter"), owners.context, invalid_context)
		if rejected != null and bool(rejected.get("accepted")):
			return "local UID public context fail-closed gate accepted %s" % str(rejected_case.get("id"))
	var tiers: Array = []
	for index: int in range(owners.window.option_count):
		tiers.append({"index": index, "tier": [0]})
	var missing_view: Dictionary = PromptScript.create(owners.context, owners.window, "local-no-view", 1, [], [], tiers, [])
	var missing_open: Dictionary = host.open_current_prompt(missing_view.get("prompt"))
	if missing_open.get("ok") or missing_open.get("error_code") != "invalid_local_uid_public_context":
		return "local Host accepted a prompt without UID public context: %s" % str(missing_open)
	var prompt_result: Dictionary = PromptScript.create(owners.context, owners.window, "local-with-view", 2, [], [], tiers, [], local_context)
	if not bool(prompt_result.get("ok", false)):
		return "local UID prompt rejected: %s" % str(prompt_result)
	var opened: Dictionary = host.open_current_prompt(prompt_result.get("prompt"))
	if not bool(opened.get("ok", false)):
		return "local UID prompt open failed: %s" % str(opened)
	var selected: Dictionary = host.request_current_selection()
	var result: Variant = selected.get("result")
	if not bool(selected.get("ok", false)) or result == null or not result.validate_integrity():
		return "local UID shadow selection failed: %s" % str(selected)
	var audit: Dictionary = result.to_public_dict()
	if (
		audit.get("source", {}).get("card_id_domain") != "godot_local_card_uid_v1"
		or audit.get("source", {}).get("local_uid_contract_sha256") != PublicDeckAdapterScript.EXPECTED_LOCAL_BUNDLE_SHA256
		or str(audit.get("source", {}).get("local_uid_public_context_hash", "")).length() != 64
	):
		return "local UID shadow audit binding missing: %s" % str(audit)
	if audit.get("status") != "shadow_selected" or audit.get("execution_trusted") != false or audit.get("authoritative") != false:
		return "local UID Host exceeded shadow authority: %s" % str(audit)
	return ""


func test_windows_policy_package_manifest_recomputes_real_handle_and_declares_no_model() -> String:
	var requested: Dictionary = _fresh_handle(MARNIE_WINDOWS_PATH)
	if not bool(requested.get("ok", false)):
		return "Marnie policy manifest handle rejected: %s" % requested.get("error_code")
	var verified: Dictionary = PolicyPackageManifestScript.load_and_verify(requested.get("handle"))
	if not bool(verified.get("accepted", false)):
		return "Marnie policy manifest rejected: %s" % str(verified)
	if verified.get("learned_model") != "none" or verified.get("execution_location") != "device_local" or verified.get("production_ready") != false:
		return "Marnie policy manifest authority drift: %s" % str(verified)
	var document := _read_json("res://data/ptcgdap/marnie_windows_policy_package_v1.json")
	document["model"]["learned_model"] = "declared"
	var rejected: Dictionary = PolicyPackageManifestScript.verify_document(document, requested.get("handle"))
	if rejected.get("accepted") or rejected.get("error_code") != "policy_package_model_mismatch":
		return "undeclared model mutation did not fail closed: %s" % str(rejected)
	return ""
