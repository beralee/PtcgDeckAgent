class_name CardIdCatalog
extends RefCounted

const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")

const DEFAULT_ROOT := "res://"
const MAX_DOCUMENT_BYTES := 2 * 1024 * 1024
const MAX_SAFE_INTEGER := 9_007_199_254_740_991
const EXPECTED_BUNDLE_ID := "ptcgdap-card-id-catalog-bundle-p2-wp2-v1"
const EXPECTED_BUNDLE_SHA256 := "AB8CF10465F492A98DA8247A84572AECEE281D0726F7BB7B8E5DBC03A6AC70D4"
const EXPECTED_RUNTIME_INTEGRITY_SHA256 := "B812F98BF096033E1EE6908B9A198B2357E1EA8D16CC1A05573335058B7FACD0"
const EXPECTED_SOURCE_LOCK_SHA256 := "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"
const EXPECTED_SOURCE_LOCK_ID := "ptcgdap-source-lock-2026-08-09-p1wp1"
const EXPECTED_SOURCE_MANIFEST_ID := "ptcgdap-card-id-catalog-source-manifest-p2-wp2-v1"
const EXPECTED_MASTER_ID := "ptcgdap-official-card-attack-master-v1"
const EXPECTED_BRIDGE_ID := "ptcgdap-marnie-exact-print-bridge-v1"
const EXPECTED_VECTORS_ID := "ptcgdap-card-id-catalog-conformance-vectors-v1"

const BUNDLE_PATH := "contracts/ptcgdap/card_id_catalog_bundle.json"
const EXPECTED_ARTIFACT_PATHS := {
	"schema": "contracts/ptcgdap/card_id_catalog.schema.json",
	"source_manifest": "contracts/ptcgdap/card_id_catalog_source_manifest.json",
	"official_master": "data/ptcgdap/card_id_catalog/official_card_attack_master_v1.json",
	"exact_bridge": "data/ptcgdap/card_id_catalog/marnie_exact_print_bridge_v1.json",
	"conformance_vectors": "contracts/ptcgdap/card_id_catalog_conformance_vectors.json",
}
const EXPECTED_ARTIFACT_SHA256 := {
	"schema": "9199FF5CDD6958FC3191F193E56829B75DB694A1488920250F4678AA052F79FE",
	"source_manifest": "14A01DB7AF8344C8289E02D03478DB5CB8195F8EB78E01976D0672B871EEC90F",
	"official_master": "3ED86C598ECD0BB5367FB575E94113BFE488E0B98FC64D6FABC50A1B0EAA8ED3",
	"exact_bridge": "15BDE946C5C5B0102D13C04AE5B7676CB7FB071C32BC35507C24556E1D9FBEC5",
	"conformance_vectors": "0AF76EB91CC69BE9D8102391C98EDEB3C9DCF399C1AB1BC5ED253B5E58E305C4",
}
const EXPECTED_MAPPED_CARD_IDS := [7, 104, 112, 646, 647, 648, 1080, 1097, 1259]
const EXPECTED_UNMAPPED_CARD_IDS := [860, 1079, 1086, 1122, 1137, 1152, 1182, 1219, 1227, 1231]
const EXPECTED_NULL_PRINTING_IDS := [916, 925, 929, 947, 992, 998, 999, 1083]
const STABLE_ERROR_CODES := {
	"catalog_not_loaded": true,
	"catalog_bundle_trust_anchor_mismatch": true,
	"catalog_artifact_set_invalid": true,
	"catalog_artifact_hash_mismatch": true,
	"catalog_integrity_invalid": true,
	"source_anchor_mismatch": true,
	"source_file_missing": true,
	"source_hash_mismatch": true,
	"schema_unsupported": true,
	"input_type_invalid": true,
	"official_card_unknown": true,
	"official_card_unmapped": true,
	"official_printing_unavailable": true,
	"official_attack_unknown": true,
	"local_printing_unmapped": true,
	"local_source_missing": true,
	"local_source_hash_mismatch": true,
	"mapping_conflict": true,
	"attack_unmapped": true,
	"attack_owner_mismatch": true,
	"attack_map_incomplete": true,
}

var _ok := false
var _error_code := "catalog_not_loaded"
var _source_contract_hash := ""
var _cards := {}
var _attacks := {}
var _local_entries := {}
var _local_by_card := {}
var _source_bindings := {}
var _artifact_hashes := {}
var _audit := {}
var _runtime_integrity_sha256 := ""
var _load_attempted := false

var ok: bool:
	get:
		return _ok

var error_code: String:
	get:
		return _error_code

var source_contract_hash: String:
	get:
		return _source_contract_hash


static func load_default() -> Variant:
	return load_trusted_bundle(DEFAULT_ROOT)


static func load_trusted_bundle(repository_root: Variant) -> Variant:
	var script: GDScript = load("res://scripts/ai/ptcgdap/host/godot/CardIdCatalog.gd")
	var result: RefCounted = script.new()
	if typeof(repository_root) != TYPE_STRING:
		result._load_attempted = true
		result._fail("catalog_not_loaded")
		return result
	result._load(str(repository_root))
	return result


func _load(repository_root: String) -> void:
	if _load_attempted:
		return
	_load_attempted = true
	if typeof(repository_root) != TYPE_STRING or repository_root.is_empty():
		_fail("catalog_not_loaded")
		return
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(repository_root)):
		_fail("catalog_not_loaded")
		return

	var bundle_bytes_result := _load_bytes_at(repository_root, BUNDLE_PATH, "catalog_bundle_trust_anchor_mismatch")
	if not bool(bundle_bytes_result.get("ok", false)):
		_fail(str(bundle_bytes_result.get("error_code", "catalog_bundle_trust_anchor_mismatch")))
		return
	var bundle_bytes: PackedByteArray = bundle_bytes_result.get("bytes", PackedByteArray())
	var bundle_digest := _canonical_sha256(bundle_bytes)
	if not bool(bundle_digest.get("ok", false)) or bundle_digest.get("sha256") != EXPECTED_BUNDLE_SHA256:
		_fail("catalog_bundle_trust_anchor_mismatch")
		return
	var bundle_result := _parse_json_bytes(bundle_bytes)
	if not bool(bundle_result.get("ok", false)):
		_fail("catalog_bundle_trust_anchor_mismatch")
		return
	var bundle_value: Variant = bundle_result.get("value")
	if not bundle_value is Dictionary:
		_fail("catalog_bundle_trust_anchor_mismatch")
		return
	var bundle: Dictionary = bundle_value
	if not _validate_bundle_header(bundle):
		_fail("catalog_bundle_trust_anchor_mismatch")
		return

	var entries_value: Variant = bundle.get("artifacts")
	if not entries_value is Array or (entries_value as Array).size() != EXPECTED_ARTIFACT_PATHS.size():
		_fail("catalog_artifact_set_invalid")
		return
	var seen_ids := {}
	var seen_paths := {}
	var documents := {}
	var artifact_hashes := {}
	for entry_value: Variant in entries_value as Array:
		if not entry_value is Dictionary:
			_fail("catalog_artifact_set_invalid")
			return
		var entry: Dictionary = entry_value
		if entry.keys().size() != 3:
			_fail("catalog_artifact_set_invalid")
			return
		var artifact_id_value: Variant = entry.get("id")
		var path_value: Variant = entry.get("path")
		var hash_value: Variant = entry.get("canonical_sha256")
		if typeof(artifact_id_value) != TYPE_STRING or typeof(path_value) != TYPE_STRING or typeof(hash_value) != TYPE_STRING:
			_fail("catalog_artifact_set_invalid")
			return
		var artifact_id := str(artifact_id_value)
		var relative_path := str(path_value)
		var expected_hash := str(hash_value)
		if (
			seen_ids.has(artifact_id)
			or seen_paths.has(relative_path)
			or EXPECTED_ARTIFACT_PATHS.get(artifact_id) != relative_path
			or EXPECTED_ARTIFACT_SHA256.get(artifact_id) != expected_hash
			or not _is_safe_relative_path(relative_path)
		):
			_fail("catalog_artifact_set_invalid")
			return
		seen_ids[artifact_id] = true
		seen_paths[relative_path] = true
		var document_result := _load_json_document(repository_root, relative_path, "catalog_artifact_hash_mismatch")
		if not bool(document_result.get("ok", false)):
			_fail(str(document_result.get("error_code", "catalog_artifact_hash_mismatch")))
			return
		var digest := _canonical_sha256(document_result.get("bytes", PackedByteArray()))
		if not bool(digest.get("ok", false)) or digest.get("sha256") != expected_hash:
			_fail("catalog_artifact_hash_mismatch")
			return
		documents[artifact_id] = (document_result.get("value") as Dictionary).duplicate(true)
		artifact_hashes[artifact_id] = expected_hash
	if seen_ids.size() != EXPECTED_ARTIFACT_PATHS.size():
		_fail("catalog_artifact_set_invalid")
		return

	var build_result := _build_runtime(repository_root, documents)
	if not bool(build_result.get("ok", false)):
		_fail(str(build_result.get("error_code", "catalog_integrity_invalid")))
		return
	_cards = (build_result.get("cards") as Dictionary).duplicate(true)
	_attacks = (build_result.get("attacks") as Dictionary).duplicate(true)
	_local_entries = (build_result.get("local_entries") as Dictionary).duplicate(true)
	_local_by_card = (build_result.get("local_by_card") as Dictionary).duplicate(true)
	_source_bindings = (build_result.get("source_bindings") as Dictionary).duplicate(true)
	_artifact_hashes = artifact_hashes.duplicate(true)
	_audit = (build_result.get("audit") as Dictionary).duplicate(true)
	_source_contract_hash = EXPECTED_BUNDLE_SHA256
	_error_code = ""
	_ok = true
	_runtime_integrity_sha256 = _runtime_digest()
	if _runtime_integrity_sha256 != EXPECTED_RUNTIME_INTEGRITY_SHA256:
		_fail("catalog_integrity_invalid")
		return
	_runtime_integrity_sha256 = EXPECTED_RUNTIME_INTEGRITY_SHA256


func _build_runtime(repository_root: String, documents: Dictionary) -> Dictionary:
	for artifact_id: String in EXPECTED_ARTIFACT_PATHS:
		if not documents.get(artifact_id) is Dictionary:
			return _failure_build("catalog_artifact_set_invalid")
	var schema: Dictionary = documents["schema"]
	if schema.get("schema_version") != 1 or schema.get("$schema") != "https://json-schema.org/draft/2020-12/schema":
		return _failure_build("schema_unsupported")
	var master: Dictionary = documents["official_master"]
	var bridge: Dictionary = documents["exact_bridge"]
	var source_manifest: Dictionary = documents["source_manifest"]
	var vectors: Dictionary = documents["conformance_vectors"]
	if (
		master.get("artifact_id") != EXPECTED_MASTER_ID
		or master.get("source_manifest_id") != EXPECTED_SOURCE_MANIFEST_ID
		or bridge.get("artifact_id") != EXPECTED_BRIDGE_ID
		or bridge.get("source_manifest_id") != EXPECTED_SOURCE_MANIFEST_ID
		or source_manifest.get("artifact_id") != EXPECTED_SOURCE_MANIFEST_ID
		or vectors.get("artifact_id") != EXPECTED_VECTORS_ID
	):
		return _failure_build("source_anchor_mismatch")
	var lock_value: Variant = source_manifest.get("source_lock")
	if not lock_value is Dictionary or lock_value.get("lock_id") != EXPECTED_SOURCE_LOCK_ID or lock_value.get("canonical_sha256") != EXPECTED_SOURCE_LOCK_SHA256:
		return _failure_build("source_anchor_mismatch")

	var cards_result := _build_cards(master)
	if not bool(cards_result.get("ok", false)):
		return cards_result
	var attacks_result := _build_attacks(master, cards_result.get("cards", {}))
	if not bool(attacks_result.get("ok", false)):
		return attacks_result
	var bridge_result := _build_bridge(bridge, cards_result.get("cards", {}), attacks_result.get("attacks", {}))
	if not bool(bridge_result.get("ok", false)):
		return bridge_result
	var sources_result := _verify_sources(repository_root, source_manifest, bridge_result.get("source_bindings", {}))
	if not bool(sources_result.get("ok", false)):
		return sources_result
	var vectors_value: Variant = vectors.get("vectors")
	var codes_value: Variant = vectors.get("stable_error_codes")
	if not vectors_value is Array or (vectors_value as Array).size() != 104 or not codes_value is Array:
		return _failure_build("catalog_integrity_invalid")
	var codes_seen := {}
	for code_value: Variant in codes_value as Array:
		if typeof(code_value) != TYPE_STRING or not STABLE_ERROR_CODES.has(str(code_value)):
			return _failure_build("catalog_integrity_invalid")
		codes_seen[str(code_value)] = true
	if codes_seen.size() != STABLE_ERROR_CODES.size():
		return _failure_build("catalog_integrity_invalid")
	return {
		"ok": true,
		"error_code": "",
		"cards": cards_result.get("cards", {}),
		"attacks": attacks_result.get("attacks", {}),
		"local_entries": bridge_result.get("local_entries", {}),
		"local_by_card": bridge_result.get("local_by_card", {}),
		"source_bindings": bridge_result.get("source_bindings", {}),
		"audit": {
			"authority": "shadow_identity_catalog_only",
			"source_contract_hash": EXPECTED_BUNDLE_SHA256,
			"source_lock_canonical_sha256": EXPECTED_SOURCE_LOCK_SHA256,
			"official_card_count": 1267,
			"official_attack_count": 1556,
			"local_bridge_count": 9,
			"shared_vector_count": 104,
			"live_authority": false,
			"package_authority": false,
		},
	}


func _build_cards(master: Dictionary) -> Dictionary:
	var values: Variant = master.get("cards")
	if not values is Array or (values as Array).size() != 1267:
		return _failure_build("catalog_integrity_invalid")
	var cards := {}
	var null_ids := []
	for offset: int in (values as Array).size():
		var value: Variant = (values as Array)[offset]
		if not value is Dictionary:
			return _failure_build("catalog_integrity_invalid")
		var record: Dictionary = value
		var card_id: Variant = record.get("official_card_id")
		var attacks: Variant = record.get("ordered_official_attack_ids")
		var printing: Variant = record.get("exact_english_printing_or_null")
		if typeof(card_id) != TYPE_INT or int(card_id) != offset + 1 or not attacks is Array:
			return _failure_build("catalog_integrity_invalid")
		if printing == null:
			null_ids.append(int(card_id))
		elif not printing is Dictionary or typeof(printing.get("expansion")) != TYPE_STRING or typeof(printing.get("collection_no")) != TYPE_STRING:
			return _failure_build("catalog_integrity_invalid")
		var seen_attacks := {}
		for attack_id: Variant in attacks as Array:
			if typeof(attack_id) != TYPE_INT or int(attack_id) < 1 or int(attack_id) > 1556 or seen_attacks.has(attack_id):
				return _failure_build("attack_map_incomplete")
			seen_attacks[attack_id] = true
		cards[int(card_id)] = record.duplicate(true)
	if null_ids != EXPECTED_NULL_PRINTING_IDS:
		return _failure_build("catalog_integrity_invalid")
	return {"ok": true, "error_code": "", "cards": cards}


func _build_attacks(master: Dictionary, cards: Dictionary) -> Dictionary:
	var values: Variant = master.get("attacks")
	if not values is Array or (values as Array).size() != 1556:
		return _failure_build("catalog_integrity_invalid")
	var attacks := {}
	var memberships := {}
	for card_id: Variant in cards:
		var ordered: Array = cards[card_id].get("ordered_official_attack_ids", [])
		for ordinal: int in ordered.size():
			var attack_id: int = int(ordered[ordinal])
			if memberships.has(attack_id):
				return _failure_build("mapping_conflict")
			memberships[attack_id] = {"owner": int(card_id), "ordinal": ordinal}
	for offset: int in (values as Array).size():
		var value: Variant = (values as Array)[offset]
		if not value is Dictionary:
			return _failure_build("catalog_integrity_invalid")
		var record: Dictionary = value
		var attack_id: Variant = record.get("official_attack_id")
		var owner: Variant = record.get("owner_official_card_id")
		var ordinal: Variant = record.get("owner_attack_ordinal")
		if typeof(attack_id) != TYPE_INT or int(attack_id) != offset + 1 or typeof(owner) != TYPE_INT or typeof(ordinal) != TYPE_INT:
			return _failure_build("catalog_integrity_invalid")
		var membership: Dictionary = memberships.get(int(attack_id), {})
		if membership.get("owner") != owner or membership.get("ordinal") != ordinal:
			return _failure_build("attack_owner_mismatch")
		attacks[int(attack_id)] = record.duplicate(true)
	if memberships.size() != 1556:
		return _failure_build("attack_map_incomplete")
	return {"ok": true, "error_code": "", "attacks": attacks}


func _build_bridge(bridge: Dictionary, cards: Dictionary, attacks: Dictionary) -> Dictionary:
	var values: Variant = bridge.get("entries")
	if not values is Array or (values as Array).size() != 9:
		return _failure_build("mapping_conflict")
	var local_entries := {}
	var local_by_card := {}
	var source_bindings := {}
	var mapped_ids := []
	for value: Variant in values as Array:
		if not value is Dictionary:
			return _failure_build("mapping_conflict")
		var record: Dictionary = value
		var card_id: Variant = record.get("official_card_id")
		var printing: Variant = record.get("local_printing")
		var attack_map: Variant = record.get("local_attack_index_to_official_attack_id")
		if typeof(card_id) != TYPE_INT or not cards.has(card_id) or not printing is Dictionary or not attack_map is Dictionary:
			return _failure_build("mapping_conflict")
		var set_code: Variant = printing.get("set_code")
		var card_index: Variant = printing.get("card_index")
		if not _is_identity_string(set_code) or not _is_identity_string(card_index):
			return _failure_build("mapping_conflict")
		var key := _local_key(str(set_code), str(card_index))
		if local_entries.has(key) or local_by_card.has(int(card_id)):
			return _failure_build("mapping_conflict")
		var ordered_attacks: Array = cards[card_id].get("ordered_official_attack_ids", [])
		if (attack_map as Dictionary).size() != ordered_attacks.size():
			return _failure_build("attack_map_incomplete")
		for ordinal: int in ordered_attacks.size():
			var ordinal_key := str(ordinal)
			if not (attack_map as Dictionary).has(ordinal_key) or (attack_map as Dictionary)[ordinal_key] != ordered_attacks[ordinal]:
				return _failure_build("attack_map_incomplete")
			var attack_record: Dictionary = attacks.get(int(ordered_attacks[ordinal]), {})
			if attack_record.get("owner_official_card_id") != card_id or attack_record.get("owner_attack_ordinal") != ordinal:
				return _failure_build("attack_owner_mismatch")
		var public_entry := {
			"local_attack_index_to_official_attack_id": (attack_map as Dictionary).duplicate(true),
			"local_printing": (printing as Dictionary).duplicate(true),
			"official_card_id": int(card_id),
			"source_canonical_json_v1_sha256": record.get("source_canonical_json_v1_sha256"),
		}
		local_entries[key] = public_entry
		local_by_card[int(card_id)] = {
			"local_printing": (printing as Dictionary).duplicate(true),
			"official_card_id": int(card_id),
			"source_canonical_json_v1_sha256": record.get("source_canonical_json_v1_sha256"),
		}
		source_bindings[key] = {
			"card_index": str(card_index),
			"local_attack_count": (attack_map as Dictionary).size(),
			"official_card_id": int(card_id),
			"official_printing": cards[card_id].get("exact_english_printing_or_null"),
			"set_code": str(set_code),
			"source_bytes": record.get("source_bytes"),
			"source_file": record.get("source_file"),
			"source_raw_sha256": record.get("source_raw_sha256"),
			"source_canonical_json_v1_sha256": record.get("source_canonical_json_v1_sha256"),
		}
		mapped_ids.append(int(card_id))
	mapped_ids.sort()
	if mapped_ids != EXPECTED_MAPPED_CARD_IDS:
		return _failure_build("mapping_conflict")
	var scope: Variant = bridge.get("bridge_scope")
	if not scope is Dictionary or scope.get("official_marnie_unmapped_card_ids") != EXPECTED_UNMAPPED_CARD_IDS:
		return _failure_build("mapping_conflict")
	return {
		"ok": true,
		"error_code": "",
		"local_entries": local_entries,
		"local_by_card": local_by_card,
		"source_bindings": source_bindings,
	}


func _verify_sources(repository_root: String, source_manifest: Dictionary, bindings: Dictionary) -> Dictionary:
	var inputs_value: Variant = source_manifest.get("inputs")
	if not inputs_value is Array or (inputs_value as Array).size() != 17:
		return _failure_build("source_anchor_mismatch")
	var local_manifest_by_path := {}
	for value: Variant in inputs_value as Array:
		if not value is Dictionary:
			return _failure_build("source_anchor_mismatch")
		var input: Dictionary = value
		if input.get("root_id") == "ptcgdap" and input.get("role") == "reviewed_exact_local_printing_source":
			var path_value: Variant = input.get("path")
			if typeof(path_value) != TYPE_STRING or local_manifest_by_path.has(path_value):
				return _failure_build("source_anchor_mismatch")
			local_manifest_by_path[path_value] = input
	if local_manifest_by_path.size() != 9 or bindings.size() != 9:
		return _failure_build("source_anchor_mismatch")
	for key: Variant in bindings:
		var binding: Dictionary = bindings[key]
		var relative_path: Variant = binding.get("source_file")
		if typeof(relative_path) != TYPE_STRING or not _is_safe_relative_path(str(relative_path)):
			return _failure_build("source_anchor_mismatch")
		var manifest_record: Dictionary = local_manifest_by_path.get(relative_path, {})
		if (
			manifest_record.get("bytes") != binding.get("source_bytes")
			or manifest_record.get("raw_sha256") != binding.get("source_raw_sha256")
			or manifest_record.get("canonical_json_v1_sha256") != binding.get("source_canonical_json_v1_sha256")
		):
			return _failure_build("source_anchor_mismatch")
		var bytes_result := _load_bytes_at(repository_root, str(relative_path), "source_file_missing")
		if not bool(bytes_result.get("ok", false)):
			return _failure_build(str(bytes_result.get("error_code", "source_file_missing")))
		var source_bytes: PackedByteArray = bytes_result.get("bytes", PackedByteArray())
		if source_bytes.size() != int(binding.get("source_bytes", -1)) or _raw_sha256(source_bytes) != binding.get("source_raw_sha256"):
			return _failure_build("source_hash_mismatch")
		var canonical := _canonical_sha256(source_bytes)
		if not bool(canonical.get("ok", false)) or canonical.get("sha256") != binding.get("source_canonical_json_v1_sha256"):
			return _failure_build("source_hash_mismatch")
		var parsed := _parse_json_bytes(source_bytes)
		if not bool(parsed.get("ok", false)) or not parsed.get("value") is Dictionary:
			return _failure_build("source_hash_mismatch")
		var source: Dictionary = parsed.get("value")
		if source.get("set_code") != binding.get("set_code") or source.get("card_index") != binding.get("card_index"):
			return _failure_build("source_hash_mismatch")
		var official_printing: Variant = binding.get("official_printing")
		if (
			not official_printing is Dictionary
			or source.get("set_code_en") != official_printing.get("expansion")
			or source.get("card_index_en") != official_printing.get("collection_no")
		):
			return _failure_build("source_hash_mismatch")
		var local_attacks: Variant = source.get("attacks")
		if not local_attacks is Array or (local_attacks as Array).size() != binding.get("local_attack_count"):
			return _failure_build("attack_map_incomplete")
	return {"ok": true, "error_code": ""}


func validate_integrity() -> bool:
	if (
		not _ok
		or _source_contract_hash != EXPECTED_BUNDLE_SHA256
		or _runtime_integrity_sha256 != EXPECTED_RUNTIME_INTEGRITY_SHA256
	):
		return false
	var actual := _runtime_digest()
	return actual == EXPECTED_RUNTIME_INTEGRITY_SHA256


func catalog_hash() -> String:
	return _source_contract_hash if validate_integrity() else ""


func audit_snapshot() -> Dictionary:
	return _audit.duplicate(true) if validate_integrity() else {}


func artifact_canonical_sha256(artifact_id: Variant) -> Dictionary:
	var guard: Variant = _guard()
	if guard != null:
		return guard
	if typeof(artifact_id) != TYPE_STRING:
		return _failure("input_type_invalid")
	if not _artifact_hashes.has(artifact_id):
		return _failure("catalog_artifact_set_invalid")
	return _success(_artifact_hashes[artifact_id])


func is_known_official_card_id(official_card_id: Variant) -> Dictionary:
	var guard: Variant = _guard()
	if guard != null:
		return guard
	if not _is_safe_integer(official_card_id):
		return _failure("input_type_invalid")
	return _success(_cards.has(int(official_card_id)))


func lookup_official_card(official_card_id: Variant) -> Dictionary:
	var guard: Variant = _guard()
	if guard != null:
		return guard
	if not _is_safe_integer(official_card_id):
		return _failure("input_type_invalid")
	if not _cards.has(int(official_card_id)):
		return _failure("official_card_unknown")
	return _success((_cards[int(official_card_id)] as Dictionary).duplicate(true))


func official_printing_for(official_card_id: Variant) -> Dictionary:
	var card_result := lookup_official_card(official_card_id)
	if not bool(card_result.get("ok", false)):
		return card_result
	var printing: Variant = (card_result.get("value") as Dictionary).get("exact_english_printing_or_null")
	if printing == null:
		return _failure("official_printing_unavailable")
	return _success((printing as Dictionary).duplicate(true))


func lookup_official_attack(official_attack_id: Variant) -> Dictionary:
	var guard: Variant = _guard()
	if guard != null:
		return guard
	if not _is_safe_integer(official_attack_id):
		return _failure("input_type_invalid")
	if not _attacks.has(int(official_attack_id)):
		return _failure("official_attack_unknown")
	return _success((_attacks[int(official_attack_id)] as Dictionary).duplicate(true))


func official_attack_owner(official_attack_id: Variant) -> Dictionary:
	var result := lookup_official_attack(official_attack_id)
	if not bool(result.get("ok", false)):
		return result
	var attack: Dictionary = result.get("value")
	return _success({
		"owner_official_card_id": attack.get("owner_official_card_id"),
		"owner_attack_ordinal": attack.get("owner_attack_ordinal"),
	})


func lookup_local_printing(set_code: Variant, card_index: Variant) -> Dictionary:
	var guard: Variant = _guard()
	if guard != null:
		return guard
	if not _is_identity_string(set_code) or not _is_identity_string(card_index):
		return _failure("input_type_invalid")
	var key := _local_key(str(set_code), str(card_index))
	if not _local_entries.has(key):
		return _failure("local_printing_unmapped")
	return _success((_local_entries[key] as Dictionary).duplicate(true))


func lookup_official_card_id(set_code: Variant, card_index: Variant) -> Dictionary:
	var result := lookup_local_printing(set_code, card_index)
	if not bool(result.get("ok", false)):
		return result
	return _success((result.get("value") as Dictionary).get("official_card_id"))


func lookup_local_printing_for_official_card(official_card_id: Variant) -> Dictionary:
	var guard: Variant = _guard()
	if guard != null:
		return guard
	if not _is_safe_integer(official_card_id):
		return _failure("input_type_invalid")
	if not _cards.has(int(official_card_id)):
		return _failure("official_card_unknown")
	if not _local_by_card.has(int(official_card_id)):
		return _failure("official_card_unmapped")
	return _success((_local_by_card[int(official_card_id)] as Dictionary).duplicate(true))


func lookup_local_attack(set_code: Variant, card_index: Variant, local_attack_index: Variant) -> Dictionary:
	var guard: Variant = _guard()
	if guard != null:
		return guard
	if not _is_identity_string(set_code) or not _is_identity_string(card_index) or not _is_nonnegative_safe_integer(local_attack_index):
		return _failure("input_type_invalid")
	var key := _local_key(str(set_code), str(card_index))
	if not _local_entries.has(key):
		return _failure("local_printing_unmapped")
	var entry: Dictionary = _local_entries[key]
	var attack_map: Dictionary = entry.get("local_attack_index_to_official_attack_id", {})
	var ordinal_key := str(int(local_attack_index))
	if not attack_map.has(ordinal_key):
		return _failure("attack_unmapped")
	var attack_id: int = int(attack_map[ordinal_key])
	if not _attacks.has(attack_id):
		return _failure("official_attack_unknown")
	var attack: Dictionary = _attacks[attack_id]
	if attack.get("owner_official_card_id") != entry.get("official_card_id"):
		return _failure("attack_owner_mismatch")
	return _success({
		"official_attack_id": attack_id,
		"official_card_id": entry.get("official_card_id"),
		"owner_attack_ordinal": attack.get("owner_attack_ordinal"),
	})


func lookup_official_attack_id(set_code: Variant, card_index: Variant, local_attack_index: Variant) -> Dictionary:
	var result := lookup_local_attack(set_code, card_index, local_attack_index)
	if not bool(result.get("ok", false)):
		return result
	return _success((result.get("value") as Dictionary).get("official_attack_id"))


func validate_local_source(set_code: Variant, card_index: Variant, actual_source: Variant) -> Dictionary:
	var guard: Variant = _guard()
	if guard != null:
		return guard
	if not _is_identity_string(set_code) or not _is_identity_string(card_index):
		return _failure("input_type_invalid")
	var key := _local_key(str(set_code), str(card_index))
	if not _source_bindings.has(key):
		return _failure("local_source_missing")
	var binding: Dictionary = _source_bindings[key]
	var canonical: Dictionary
	if actual_source is PackedByteArray:
		var source_bytes: PackedByteArray = actual_source
		if source_bytes.size() != int(binding.get("source_bytes", -1)) or _raw_sha256(source_bytes) != binding.get("source_raw_sha256"):
			return _failure("local_source_hash_mismatch")
		canonical = _canonical_sha256(source_bytes)
	elif actual_source is Dictionary:
		canonical = _canonical_value_sha256(actual_source)
	else:
		return _failure("input_type_invalid")
	if not bool(canonical.get("ok", false)) or canonical.get("sha256") != binding.get("source_canonical_json_v1_sha256"):
		return _failure("local_source_hash_mismatch")
	return _success(true)


func _guard() -> Variant:
	return null if validate_integrity() else _failure("catalog_integrity_invalid")


func _runtime_digest() -> String:
	if not _cards is Dictionary or not _attacks is Dictionary or not _local_entries is Dictionary or not _local_by_card is Dictionary or not _source_bindings is Dictionary or not _artifact_hashes is Dictionary or not _audit is Dictionary:
		return ""
	if (
		_cards.size() != 1267
		or _attacks.size() != 1556
		or _local_entries.size() != 9
		or _local_by_card.size() != 9
		or _source_bindings.size() != 9
		or _artifact_hashes.size() != 5
	):
		return ""
	for card_id: int in range(1, 1268):
		var card_value: Variant = _cards.get(card_id)
		if not card_value is Dictionary or card_value.get("official_card_id") != card_id:
			return ""
	for attack_id: int in range(1, 1557):
		var attack_value: Variant = _attacks.get(attack_id)
		if not attack_value is Dictionary or attack_value.get("official_attack_id") != attack_id:
			return ""
	for local_card_key: Variant in _local_by_card:
		if typeof(local_card_key) != TYPE_INT:
			return ""
		var local_value: Variant = _local_by_card[local_card_key]
		if not local_value is Dictionary or local_value.get("official_card_id") != local_card_key:
			return ""
	var payload := {
		"artifact_hashes": _artifact_hashes,
		"attacks": _dictionary_pairs_by_int_key(_attacks),
		"audit": _audit,
		"cards": _dictionary_pairs_by_int_key(_cards),
		"local_by_card": _dictionary_pairs_by_int_key(_local_by_card),
		"local_entries": _local_entries,
		"source_bindings": _source_bindings,
		"source_contract_hash": _source_contract_hash,
	}
	var digest := _canonical_value_sha256(payload)
	return str(digest.get("sha256", "")) if bool(digest.get("ok", false)) else ""


static func _dictionary_pairs_by_int_key(source: Dictionary) -> Array:
	var keys: Array = source.keys()
	keys.sort()
	var pairs := []
	for key: Variant in keys:
		if typeof(key) != TYPE_INT:
			return []
		pairs.append({"key": key, "value": source[key]})
	return pairs


func _fail(code: String) -> void:
	_ok = false
	_error_code = code if STABLE_ERROR_CODES.has(code) else "catalog_integrity_invalid"
	_source_contract_hash = ""
	_cards = {}
	_attacks = {}
	_local_entries = {}
	_local_by_card = {}
	_source_bindings = {}
	_artifact_hashes = {}
	_audit = {}
	_runtime_integrity_sha256 = ""


static func _validate_bundle_header(bundle: Dictionary) -> bool:
	return (
		bundle.get("schema_version") == 1
		and bundle.get("artifact_id") == EXPECTED_BUNDLE_ID
		and bundle.get("digest_mode") == "canonical_json_v1"
		and bundle.get("artifact_set_policy") == "exact_ids_and_paths_no_duplicates"
		and bundle.get("source_lock_canonical_sha256") == EXPECTED_SOURCE_LOCK_SHA256
	)


static func _failure_build(code: String) -> Dictionary:
	return {"ok": false, "error_code": code}


static func _success(value: Variant) -> Dictionary:
	var copied: Variant = value.duplicate(true) if value is Dictionary or value is Array else value
	return {"ok": true, "error_code": null, "value": copied}


static func _failure(code: String) -> Dictionary:
	var safe_code := code if STABLE_ERROR_CODES.has(code) else "catalog_integrity_invalid"
	return {"ok": false, "error_code": safe_code, "value": null}


static func _local_key(set_code: String, card_index: String) -> String:
	return "%d:%s%d:%s" % [set_code.length(), set_code, card_index.length(), card_index]


static func _is_safe_integer(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and int(value) >= -MAX_SAFE_INTEGER and int(value) <= MAX_SAFE_INTEGER


static func _is_nonnegative_safe_integer(value: Variant) -> bool:
	return _is_safe_integer(value) and int(value) >= 0


static func _is_identity_string(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING and not str(value).is_empty()


static func _join_root(root: String, relative_path: String) -> String:
	if root.ends_with("//"):
		return root + relative_path
	return root.trim_suffix("/") + "/" + relative_path


static func _is_safe_relative_path(relative_path: String) -> bool:
	if relative_path.is_empty() or relative_path.begins_with("/") or relative_path.contains("\\") or relative_path.contains(":"):
		return false
	for segment: String in relative_path.split("/"):
		if segment.is_empty() or segment == "." or segment == "..":
			return false
	return true


static func _load_json_document(root: String, relative_path: String, missing_code: String) -> Dictionary:
	var bytes_result := _load_bytes_at(root, relative_path, missing_code)
	if not bool(bytes_result.get("ok", false)):
		return bytes_result
	var source_bytes: PackedByteArray = bytes_result.get("bytes", PackedByteArray())
	var parsed := _parse_json_bytes(source_bytes)
	if not bool(parsed.get("ok", false)):
		return {"ok": false, "error_code": missing_code}
	parsed["bytes"] = source_bytes
	return parsed


static func _load_bytes_at(root: String, relative_path: String, missing_code: String) -> Dictionary:
	if not _is_safe_relative_path(relative_path):
		return {"ok": false, "error_code": missing_code}
	var path := _join_root(root, relative_path)
	if not FileAccess.file_exists(path):
		return {"ok": false, "error_code": missing_code}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error_code": missing_code}
	var length := file.get_length()
	if length < 1 or length > MAX_DOCUMENT_BYTES:
		return {"ok": false, "error_code": missing_code}
	return {"ok": true, "error_code": "", "bytes": file.get_buffer(length)}


static func _parse_json_bytes(source_bytes: PackedByteArray) -> Dictionary:
	var canonical := CabtJsonTreeScript.canonicalize_artifact_json_bytes(
		source_bytes,
		{"max_input_bytes": MAX_DOCUMENT_BYTES, "max_output_bytes": MAX_DOCUMENT_BYTES}
	)
	if not bool(canonical.get("ok", false)):
		return {"ok": false, "error_code": "catalog_integrity_invalid"}
	var text := source_bytes.get_string_from_utf8()
	if text.to_utf8_buffer() != source_bytes:
		return {"ok": false, "error_code": "catalog_integrity_invalid"}
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return {"ok": false, "error_code": "catalog_integrity_invalid"}
	var state := {"ok": true}
	var restored: Variant = _restore_integer_tokens(parser.data, state)
	if not bool(state.get("ok", false)) or not restored is Dictionary:
		return {"ok": false, "error_code": "catalog_integrity_invalid"}
	return {"ok": true, "error_code": "", "value": restored}


static func _restore_integer_tokens(value: Variant, state: Dictionary) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			var number := float(value)
			if not is_finite(number) or number != floorf(number) or number < -float(MAX_SAFE_INTEGER) or number > float(MAX_SAFE_INTEGER):
				state["ok"] = false
				return null
			return int(number)
		TYPE_ARRAY:
			var array := []
			for child: Variant in value as Array:
				array.append(_restore_integer_tokens(child, state))
				if not bool(state.get("ok", false)):
					return null
			return array
		TYPE_DICTIONARY:
			var object := {}
			for key: Variant in (value as Dictionary).keys():
				if typeof(key) != TYPE_STRING:
					state["ok"] = false
					return null
				object[key] = _restore_integer_tokens((value as Dictionary)[key], state)
				if not bool(state.get("ok", false)):
					return null
			return object
		_:
			return value


static func _canonical_sha256(source_bytes: PackedByteArray) -> Dictionary:
	var canonical := CabtJsonTreeScript.canonicalize_artifact_json_bytes(
		source_bytes,
		{"max_input_bytes": MAX_DOCUMENT_BYTES, "max_output_bytes": MAX_DOCUMENT_BYTES}
	)
	if not bool(canonical.get("ok", false)):
		return {"ok": false, "sha256": ""}
	return {"ok": true, "sha256": _raw_sha256(canonical.get("bytes", PackedByteArray()))}


static func _canonical_value_sha256(value: Variant) -> Dictionary:
	var canonical := CabtJsonTreeScript.canonicalize_artifact(
		value,
		{"max_input_bytes": MAX_DOCUMENT_BYTES, "max_output_bytes": MAX_DOCUMENT_BYTES}
	)
	if not bool(canonical.get("ok", false)):
		return {"ok": false, "sha256": ""}
	return {"ok": true, "sha256": _raw_sha256(canonical.get("bytes", PackedByteArray()))}


static func _raw_sha256(source_bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if context.update(source_bytes) != OK:
		return ""
	return context.finish().hex_encode().to_upper()
