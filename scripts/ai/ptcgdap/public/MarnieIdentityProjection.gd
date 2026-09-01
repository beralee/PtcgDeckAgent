class_name MarnieIdentityProjection
extends RefCounted

const CabtJsonTreeScript = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")
const MarnieVerticalSliceScript = preload("res://scripts/ai/ptcgdap/public/MarnieVerticalSlice.gd")
const CardIdCatalogScript = preload("res://scripts/ai/ptcgdap/host/godot/CardIdCatalog.gd")
const GodotObservationProjectorScript = preload("res://scripts/ai/ptcgdap/host/godot/GodotObservationProjector.gd")
const MarnieTrajectoryReplayScript = preload("res://scripts/ai/ptcgdap/public/MarnieTrajectoryReplay.gd")

const DEFAULT_ROOT := "res://"
const MAX_JSON_BYTES := 2 * 1024 * 1024
const MAX_SAFE_INTEGER := 9_007_199_254_740_991
const EXPECTED_BUNDLE_CANONICAL_SHA256 := "1EB530AB7DFACBE6AB098A6C67D6AAE0BC1871FF3E2F48C9284E8539EE6ACDC4"
const EXPECTED_RUNTIME_INTEGRITY_SHA256 := "CADBD5A469D93575DCF757BA701C9315A545B17271E758167C1D2C82E8F3595E"
const EXPECTED_RELATION_CACHE_SHA256 := "C16EE05C42083C55C555AC1C1DBB9A1C625F8DB06ADB4ECC5D5A9D6B1626C166"
const EXPECTED_PARENT_FIXTURE_SHA256 := "7E0CF80D7B2872C29F69BA15548857F1F32407943371D3C12A266A0E471EC425"
const EXPECTED_PARENT_POLICY_SHA256 := "F4E88E5DB4E480BA8441BE7B3A7C81CE3DB40ED1917EB37BCDCAC1C32B1ABD6C"
const EXPECTED_CATALOG_SHA256 := "AB8CF10465F492A98DA8247A84572AECEE281D0726F7BB7B8E5DBC03A6AC70D4"
const EXPECTED_PROJECTOR_SHA256 := "C51EA4CF1AEFCBB5B9C6D83825FF3A717CCDCC4105B804210BF6169372619041"
const BUNDLE_PATH := "contracts/ptcgdap/marnie_identity_projection_bundle.json"
const EXPECTED_ARTIFACTS := [
	["marnie_identity_projection_schema_v1", "contracts/ptcgdap/marnie_identity_projection.schema.json", "schema"],
	["marnie_identity_projection_profile_v1", "contracts/ptcgdap/marnie_identity_projection_profile.json", "profile"],
	["marnie_identity_projection_audit_v1", "data/ptcgdap/marnie_vertical_slice/marnie_identity_projection_v1.json", "audit"],
	["marnie_identity_projection_vectors_v1", "contracts/ptcgdap/marnie_identity_projection_conformance_vectors.json", "vectors"],
]
const FRAME_IDS := [
	"w0_initial", "w1_setup_active", "w2_setup_bench", "w3_main",
	"w4_spikemuth_deck", "w5_punk_up_sources", "w5_punk_up_target_1",
	"w5_punk_up_target_2", "w6_shadow_bullet_attack", "w6_shadow_bullet_target",
	"w7_take_prize", "w7_forced_send_out", "w7_terminal",
]
const MUTATIONS := [
	"card_unknown", "serial_relation_conflict", "player_index_invalid",
	"attack_unknown", "attack_owner_mismatch", "hidden_private_key", "host_entity_key",
]
const FORBIDDEN_PUBLIC_KEYS := {
	"search_begin_input": true, "raw_private_hash": true, "token_free_callback_hash": true,
	"host_pokemon_entity": true, "host_pokemon_entity_serial": true,
	"instance_id": true, "object_id": true, "private_sentinel": true,
}

var _ok := false
var _error_code := "identity_bundle_invalid"
var _bundle: Variant = {}
var _schema: Variant = {}
var _profile: Variant = {}
var _audit: Variant = {}
var _vectors: Variant = {}
var _parent_owner: Variant = null
var _catalog: Variant = null
var _known_cards := {}
var _mapped_cards := {}
var _attack_owners := {}
var _runtime_integrity_sha256 := ""
var _load_attempted := false

var ok: bool:
	get:
		return _ok and validate_integrity()

var error_code: String:
	get:
		return "" if ok else _error_code


static func load_default() -> Variant:
	return load_from_root(DEFAULT_ROOT)


static func load_from_root(root_path: Variant) -> Variant:
	var script: GDScript = load("res://scripts/ai/ptcgdap/public/MarnieIdentityProjection.gd")
	var result: RefCounted = script.new()
	if typeof(root_path) != TYPE_STRING:
		result._load_attempted = true
		result._fail("identity_bundle_invalid")
		return result
	result._load(str(root_path))
	return result


func _load(root_path: String) -> void:
	if _load_attempted:
		return
	_load_attempted = true
	var root := root_path.trim_suffix("/") + "/"
	if root == "/" or not _root_is_supported(root):
		_fail("identity_bundle_invalid")
		return
	var bundle_result := _read_json("%s%s" % [root, BUNDLE_PATH])
	if not bool(bundle_result.get("ok", false)):
		_fail(str(bundle_result.get("error_code", "identity_bundle_invalid")))
		return
	var bundle: Variant = bundle_result.get("value")
	if not bundle is Dictionary or _canonical_sha256(bundle) != EXPECTED_BUNDLE_CANONICAL_SHA256:
		_fail("identity_bundle_trust_anchor_mismatch")
		return
	if (
		not _same_keys(bundle, ["schema_version","artifact_kind","bundle_id","status","parent_fixture_bundle","parent_capability_policy_bundle","card_catalog_bundle","projector_bundle","artifacts","self_hash_policy"])
		or bundle.get("schema_version") != 1
		or bundle.get("artifact_kind") != "bundle"
		or bundle.get("bundle_id") != "ptcgdap-marnie-identity-projection-p5-wp4-v1"
		or bundle.get("status") != "offline_shadow_identity_projection_gate"
		or bundle.get("parent_fixture_bundle") != {"path":"contracts/ptcgdap/marnie_vertical_slice_bundle.json","canonical_sha256":EXPECTED_PARENT_FIXTURE_SHA256}
		or bundle.get("parent_capability_policy_bundle") != {"path":"contracts/ptcgdap/marnie_capability_policy_bundle.json","canonical_sha256":EXPECTED_PARENT_POLICY_SHA256}
		or bundle.get("card_catalog_bundle") != {"path":"contracts/ptcgdap/card_id_catalog_bundle.json","canonical_sha256":EXPECTED_CATALOG_SHA256}
		or bundle.get("projector_bundle") != {"path":"contracts/ptcgdap/godot_observation_projector_bundle.json","canonical_sha256":EXPECTED_PROJECTOR_SHA256}
		or bundle.get("self_hash_policy") != "bundle and bound artifacts do not contain the final bundle hash"
		or not bundle.get("artifacts") is Array
		or bundle.get("artifacts").size() != EXPECTED_ARTIFACTS.size()
	):
		_fail("identity_bundle_invalid")
		return
	var documents := {"bundle": bundle.duplicate(true)}
	var seen_paths := {}
	for index: int in range(EXPECTED_ARTIFACTS.size()):
		var expected: Array = EXPECTED_ARTIFACTS[index]
		var entry_value: Variant = bundle.get("artifacts")[index]
		if not entry_value is Dictionary or not _same_keys(entry_value, ["id","path","canonical_sha256"]):
			_fail("identity_bundle_invalid")
			return
		var entry: Dictionary = entry_value
		if entry.get("id") != expected[0] or entry.get("path") != expected[1] or typeof(entry.get("canonical_sha256")) != TYPE_STRING or seen_paths.has(entry.get("path")):
			_fail("identity_bundle_invalid")
			return
		if not _is_safe_relative_path(str(entry.get("path"))):
			_fail("identity_bundle_invalid")
			return
		seen_paths[entry.get("path")] = true
		var artifact_result := _read_json("%s%s" % [root, entry.get("path")])
		if not bool(artifact_result.get("ok", false)):
			_fail(str(artifact_result.get("error_code", "identity_artifact_invalid")))
			return
		var artifact: Variant = artifact_result.get("value")
		if _canonical_sha256(artifact) != entry.get("canonical_sha256"):
			_fail("identity_artifact_hash_mismatch")
			return
		documents[expected[2]] = _copy(artifact)
	if documents.size() != 5 or _canonical_sha256(documents) != EXPECTED_RUNTIME_INTEGRITY_SHA256:
		_fail("identity_integrity_invalid")
		return
	var parent_paths := [
		["contracts/ptcgdap/marnie_vertical_slice_bundle.json", EXPECTED_PARENT_FIXTURE_SHA256],
		["contracts/ptcgdap/marnie_capability_policy_bundle.json", EXPECTED_PARENT_POLICY_SHA256],
		["contracts/ptcgdap/card_id_catalog_bundle.json", EXPECTED_CATALOG_SHA256],
		["contracts/ptcgdap/godot_observation_projector_bundle.json", EXPECTED_PROJECTOR_SHA256],
	]
	for pair: Array in parent_paths:
		var parent_result := _read_json("%s%s" % [root, pair[0]])
		if not bool(parent_result.get("ok", false)) or _canonical_sha256(parent_result.get("value")) != pair[1]:
			_fail("identity_parent_hash_mismatch")
			return
	var parent: Variant = MarnieVerticalSliceScript.load_from_root(root)
	var catalog: Variant = CardIdCatalogScript.load_trusted_bundle(root)
	if (
		parent == null or parent.get_script() != MarnieVerticalSliceScript or not bool(parent.get("ok")) or parent.bundle_hash() != EXPECTED_PARENT_FIXTURE_SHA256
		or catalog == null or catalog.get_script() != CardIdCatalogScript or not bool(catalog.get("ok")) or catalog.catalog_hash() != EXPECTED_CATALOG_SHA256
	):
		_fail("identity_parent_invalid")
		return
	var summary: Variant = documents.get("audit", {}).get("summary")
	if not summary is Dictionary or not summary.get("distinct_official_card_ids") is Array or not summary.get("mapped_official_card_ids") is Array:
		_fail("identity_artifact_invalid")
		return
	var known := {}
	var mapped := {}
	for official_value: Variant in summary.get("distinct_official_card_ids"):
		if typeof(official_value) != TYPE_INT:
			_fail("identity_artifact_invalid")
			return
		var official_id := int(official_value)
		var bridge_result: Dictionary = catalog.lookup_local_printing_for_official_card(official_id)
		if bool(bridge_result.get("ok", false)):
			mapped[official_id] = true
		elif bridge_result != {"ok":false,"error_code":"official_card_unmapped","value":null}:
			_fail("identity_catalog_relation_invalid")
			return
		known[official_id] = true
	var expected_mapped := {}
	for official_value: Variant in summary.get("mapped_official_card_ids"):
		expected_mapped[int(official_value)] = true
	if known.size() != 34 or mapped.size() != 9 or mapped != expected_mapped:
		_fail("identity_catalog_relation_invalid")
		return
	var attack_owners := {}
	for attack_value: Variant in summary.get("official_attack_ids", []):
		if typeof(attack_value) != TYPE_INT:
			_fail("identity_artifact_invalid")
			return
		var attack_result: Dictionary = catalog.lookup_official_attack(int(attack_value))
		if not bool(attack_result.get("ok", false)):
			_fail("identity_catalog_relation_invalid")
			return
		attack_owners[int(attack_value)] = attack_result.get("value", {}).get("owner_official_card_id")
	_bundle = documents["bundle"]
	_schema = documents["schema"]
	_profile = documents["profile"]
	_audit = documents["audit"]
	_vectors = documents["vectors"]
	_parent_owner = parent
	_catalog = catalog
	_known_cards = known
	_mapped_cards = mapped
	_attack_owners = attack_owners
	_runtime_integrity_sha256 = EXPECTED_RUNTIME_INTEGRITY_SHA256
	if _relation_cache_digest() != EXPECTED_RELATION_CACHE_SHA256:
		_fail("identity_catalog_relation_invalid")
		return
	var derived := _derived_audit()
	if not bool(derived.get("ok", false)) or derived.get("value") != _audit:
		_fail(str(derived.get("error_code", "identity_source_relation_invalid")))
		return
	_ok = true
	_error_code = ""


func _fail(code: String) -> void:
	_ok = false
	_error_code = code


func validate_integrity() -> bool:
	if (
		not _ok
		or _runtime_integrity_sha256 != EXPECTED_RUNTIME_INTEGRITY_SHA256
		or _parent_owner == null or _parent_owner.get_script() != MarnieVerticalSliceScript
		or _catalog == null or _catalog.get_script() != CardIdCatalogScript
		or _runtime_digest() != EXPECTED_RUNTIME_INTEGRITY_SHA256
		or _relation_cache_digest() != EXPECTED_RELATION_CACHE_SHA256
	):
		return false
	return true


func bundle_hash() -> String:
	return EXPECTED_BUNDLE_CANONICAL_SHA256 if validate_integrity() else ""


func audit_snapshot() -> Dictionary:
	if not validate_integrity():
		return {}
	var summary: Dictionary = _audit.get("summary")
	return {
		"bundle_canonical_sha256": EXPECTED_BUNDLE_CANONICAL_SHA256,
		"runtime_integrity_sha256": EXPECTED_RUNTIME_INTEGRITY_SHA256,
		"frame_count": summary.get("frame_count"),
		"distinct_official_card_id_count": summary.get("distinct_official_card_ids", []).size(),
		"cross_frame_unique_serial_count": summary.get("cross_frame_unique_serial_count"),
		"mapped_official_card_id_count": summary.get("mapped_official_card_ids", []).size(),
		"known_unmapped_official_card_id_count": summary.get("known_unmapped_official_card_ids", []).size(),
		"production_actions_used": false, "execution_authority": false,
	}


func audit_all() -> Dictionary:
	if not validate_integrity():
		return _result(null, "identity_integrity_invalid")
	return _result(_result_value(_copy(_audit.get("frames")), "audit_all"))


func audit_frame(frame_id: Variant) -> Dictionary:
	if not validate_integrity():
		return _result(null, "identity_integrity_invalid")
	if typeof(frame_id) != TYPE_STRING:
		return _result(null, "input_type_invalid")
	for frame_value: Variant in _audit.get("frames", []):
		if frame_value is Dictionary and frame_value.get("frame_id") == frame_id:
			return _result(_result_value([frame_value.duplicate(true)], "audit_frame"))
	return _result(null, "frame_unknown")


func run(operation: Variant, input_value: Variant) -> Dictionary:
	if not validate_integrity():
		return _result(null, "identity_integrity_invalid")
	if typeof(operation) != TYPE_STRING or not input_value is Dictionary:
		return _result(null, "input_type_invalid")
	if operation == "audit_all" and input_value.is_empty():
		return audit_all()
	if operation == "audit_frame" and _same_keys(input_value, ["frame_id"]):
		return audit_frame(input_value.get("frame_id"))
	if operation == "probe_frame_mutation" and _same_keys(input_value, ["frame_id","mutation"]):
		return probe_frame_mutation(input_value.get("frame_id"), input_value.get("mutation"))
	return _result(null, "operation_unknown")


func probe_frame_mutation(frame_id: Variant, mutation: Variant) -> Dictionary:
	if not validate_integrity():
		return _result(null, "identity_integrity_invalid")
	if typeof(frame_id) != TYPE_STRING or typeof(mutation) != TYPE_STRING or mutation not in MUTATIONS:
		return _result(null, "input_type_invalid")
	if frame_id not in FRAME_IDS:
		return _result(null, "frame_unknown")
	var source: Dictionary = _parent_owner.frame(frame_id)
	var tree: Variant = MarnieTrajectoryReplayScript._decode_public_node(source.get("public_tree"))
	if not tree is Dictionary:
		return _result(null, "frame_identity_invalid")
	var mutation_error := _mutate_tree(tree, str(mutation))
	if not mutation_error.is_empty():
		return _result(null, mutation_error)
	var audited := _audit_tree(tree, source.get("visibility"))
	if not bool(audited.get("ok", false)):
		return _result(null, str(audited.get("error_code")))
	return _result(null, "frame_identity_invalid")


func attest_engine_projection(projector: Variant, projector_result: Variant) -> Dictionary:
	if not validate_integrity():
		return _result(null, "identity_integrity_invalid")
	if (
		projector == null or projector.get_script() != GodotObservationProjectorScript
		or not projector.has_method("validate_integrity") or not bool(projector.validate_integrity())
		or projector.contract_hash != EXPECTED_PROJECTOR_SHA256
		or projector_result == null or projector_result.get("_owner") != projector
		or not projector_result.has_method("to_public_dict")
	):
		return _result(null, "projector_result_invalid")
	var serialized: Variant = projector_result.to_public_dict()
	if not serialized is Dictionary or serialized.is_empty() or not serialized.get("accepted"):
		return _result(null, "projector_result_invalid")
	if not serialized.get("audit") is Dictionary or serialized.get("audit").get("authority") != "engine_attested_shadow":
		return _result(null, "projector_result_invalid")
	var observation: Variant = serialized.get("observation")
	if not observation is Dictionary:
		return _result(null, "projector_result_invalid")
	var engine_attack_owners: Dictionary = _attack_owners.duplicate(true)
	var dictionaries := []
	_collect_dictionaries(observation, dictionaries)
	for item_value: Variant in dictionaries:
		if not item_value.has("attackId") or typeof(item_value.get("attackId")) != TYPE_INT:
			continue
		var attack_id := int(item_value.get("attackId"))
		if engine_attack_owners.has(attack_id):
			continue
		var attack_result: Dictionary = _catalog.lookup_official_attack(attack_id)
		if not bool(attack_result.get("ok", false)):
			return _result(null, "official_attack_unknown")
		engine_attack_owners[attack_id] = attack_result.get("value", {}).get("owner_official_card_id")
	var audited := _audit_tree(observation, null, engine_attack_owners)
	if not bool(audited.get("ok", false)):
		return _result(null, str(audited.get("error_code")))
	var value: Dictionary = audited.get("value")
	value["source"] = "engine_attested_shadow"
	value["projector_contract_hash"] = EXPECTED_PROJECTOR_SHA256
	value["public_observation_hash"] = serialized.get("public_observation_hash")
	value["production_actions_used"] = false
	value["execution_authority"] = false
	return _result(value)


func _result_value(frames: Array, operation: String) -> Dictionary:
	return {
		"accepted": true, "operation": operation, "frame_count": frames.size(),
		"frames": frames.duplicate(true),
		"summary": _copy(_audit.get("summary")) if operation == "audit_all" else null,
		"production_actions_used": false, "execution_authority": false,
	}


func _derived_audit() -> Dictionary:
	var frames := []
	var cross := {}
	var all_ids := {}
	var all_attacks := {}
	var total := 0
	for ordinal: int in range(FRAME_IDS.size()):
		var frame_id: String = FRAME_IDS[ordinal]
		var source: Dictionary = _parent_owner.frame(frame_id)
		if source.is_empty():
			return _result(null, "frame_unknown")
		var detail: Dictionary
		var relations: Dictionary
		var status: String
		if source.get("public_tree") == null:
			detail = _empty_detail()
			relations = {}
			status = "terminal_no_observation"
		else:
			var tree: Variant = MarnieTrajectoryReplayScript._decode_public_node(source.get("public_tree"))
			if not tree is Dictionary:
				return _result(null, "frame_identity_invalid")
			var audited := _audit_tree(tree, source.get("visibility"))
			if not bool(audited.get("ok", false)):
				return audited
			detail = audited.get("value")
			relations = audited.get("relations")
			status = "verified_public_identity"
		for serial: Variant in relations:
			if cross.has(serial) and cross[serial] != relations[serial]:
				return _result(null, "serial_relation_conflict")
			cross[serial] = relations[serial]
		for official_id: Variant in detail.get("distinct_official_card_ids"):
			all_ids[official_id] = true
		for attack_id: Variant in detail.get("official_attack_ids"):
			all_attacks[attack_id] = true
		total += int(detail.get("identity_occurrence_count"))
		var frame := {"ordinal":ordinal,"frame_id":frame_id,"status":status,"public_observation_hash":source.get("public_observation_hash")}
		for key: Variant in detail:
			frame[key] = _copy(detail[key])
		frames.append(frame)
	var expected: Dictionary = _audit
	var summary: Dictionary = expected.get("summary")
	if (
		total != summary.get("identity_occurrence_count")
		or cross.size() != summary.get("cross_frame_unique_serial_count")
		or _sorted_int_keys(all_ids) != summary.get("distinct_official_card_ids")
		or _sorted_int_keys(all_attacks) != summary.get("official_attack_ids")
	):
		return _result(null, "identity_source_relation_invalid")
	return _result({
		"schema_version":1,"artifact_kind":"frame_audit","audit_id":expected.get("audit_id"),"profile_id":expected.get("profile_id"),
		"source_trajectory_artifact_id":expected.get("source_trajectory_artifact_id"),"source_trajectory_canonical_sha256":expected.get("source_trajectory_canonical_sha256"),
		"official_deck_artifact_id":expected.get("official_deck_artifact_id"),"official_deck_canonical_sha256":expected.get("official_deck_canonical_sha256"),
		"frames":frames,"summary":summary.duplicate(true),"production_actions_used":false,"execution_authority":false,
	})


func _audit_tree(tree: Dictionary, visibility: Variant, attack_owner_override: Variant = null) -> Dictionary:
	var attack_owner_source: Dictionary = attack_owner_override if attack_owner_override is Dictionary else _attack_owners
	var dictionaries := []
	_collect_dictionaries(tree, dictionaries)
	for item_value: Variant in dictionaries:
		var item: Dictionary = item_value
		for key: Variant in item:
			if FORBIDDEN_PUBLIC_KEYS.has(key):
				return _result(null, "host_entity_present" if key in ["host_pokemon_entity","host_pokemon_entity_serial"] else "hidden_identity_present")
	if visibility is Dictionary:
		if visibility.get("opponent_hand_hidden") != true or visibility.get("prizes_concealed") != true or visibility.get("opponent_draw_identity_absent") != true:
			return _result(null, "hidden_identity_present")
	elif not _engine_hidden_shape_safe(tree):
		return _result(null, "hidden_identity_present")
	var relations := {}
	var ids := {}
	var attacks := {}
	var attack_pairs := {}
	var occurrences := 0
	var evolved := 0
	var pre_count := 0
	for item_value: Variant in dictionaries:
		var item: Dictionary = item_value
		var identity := _identity_record(item)
		if bool(identity.get("present", false)):
			if not bool(identity.get("ok", false)):
				return _result(null, "frame_identity_invalid")
			var official_id: int = identity.get("official_id")
			var serial: int = identity.get("serial")
			var player: int = identity.get("player")
			if not _known_cards.has(official_id):
				return _result(null, "official_card_unknown")
			if relations.has(serial) and relations[serial] != [official_id, player]:
				return _result(null, "serial_relation_conflict")
			relations[serial] = [official_id, player]
			ids[official_id] = true
			occurrences += 1
		if item.has("attackId"):
			var attack_id: Variant = item.get("attackId")
			if not _is_positive_safe_int(attack_id) or not attack_owner_source.has(int(attack_id)):
				return _result(null, "official_attack_unknown")
			var owner: int = int(attack_owner_source[int(attack_id)])
			if item.has("cardId") and item.get("cardId") != owner:
				return _result(null, "attack_owner_mismatch")
			attacks[int(attack_id)] = true
			attack_pairs["%d:%d" % [int(attack_id), owner]] = {"official_attack_id":int(attack_id),"owner_official_card_id":owner}
		var pre: Variant = item.get("preEvolution")
		if pre is Array and not pre.is_empty():
			if not bool(identity.get("ok", false)):
				return _result(null, "frame_identity_invalid")
			evolved += 1
			pre_count += pre.size()
			for child_value: Variant in pre:
				if not child_value is Dictionary:
					return _result(null, "frame_identity_invalid")
				var child := _identity_record(child_value)
				if not bool(child.get("ok", false)) or child.get("serial") == identity.get("serial") or child.get("player") != identity.get("player"):
					return _result(null, "frame_identity_invalid")
	var mapped := {}
	var unmapped := {}
	for official_id: Variant in ids:
		if _mapped_cards.has(official_id): mapped[official_id] = true
		else: unmapped[official_id] = true
	var pair_keys: Array = attack_pairs.keys()
	pair_keys.sort()
	var pairs := []
	for key: Variant in pair_keys:
		pairs.append(attack_pairs[key].duplicate(true))
	return {"ok":true,"error_code":"","value":{
		"identity_occurrence_count":occurrences,"unique_serial_count":relations.size(),
		"distinct_official_card_ids":_sorted_int_keys(ids),"mapped_official_card_ids":_sorted_int_keys(mapped),
		"known_unmapped_official_card_ids":_sorted_int_keys(unmapped),"official_attack_ids":_sorted_int_keys(attacks),
		"attack_owner_pairs":pairs,"evolved_pokemon_count":evolved,"pre_evolution_card_count":pre_count,
		"serial_relation_consistent":true,"top_serial_distinct_from_pre_evolution":true,
		"hidden_identity_absent":true,"host_entity_absent":true,
	},"relations":relations}


static func _empty_detail() -> Dictionary:
	return {
		"identity_occurrence_count":0,"unique_serial_count":0,"distinct_official_card_ids":[],"mapped_official_card_ids":[],
		"known_unmapped_official_card_ids":[],"official_attack_ids":[],"attack_owner_pairs":[],"evolved_pokemon_count":0,
		"pre_evolution_card_count":0,"serial_relation_consistent":true,"top_serial_distinct_from_pre_evolution":true,
		"hidden_identity_absent":true,"host_entity_absent":true,
	}


static func _identity_record(item: Dictionary) -> Dictionary:
	if not item.has("serial") or not item.has("playerIndex") or (not item.has("id") and not item.has("cardId")):
		return {"present":false,"ok":true}
	var official_id: Variant = item.get("id") if item.has("id") else item.get("cardId")
	var serial: Variant = item.get("serial")
	var player: Variant = item.get("playerIndex")
	if not _is_positive_safe_int(official_id) or not _is_positive_safe_int(serial) or typeof(player) != TYPE_INT or int(player) not in [0, 1]:
		return {"present":true,"ok":false}
	return {"present":true,"ok":true,"official_id":int(official_id),"serial":int(serial),"player":int(player)}


static func _collect_dictionaries(value: Variant, output: Array) -> void:
	if value is Dictionary:
		output.append(value)
		for child: Variant in value.values():
			_collect_dictionaries(child, output)
	elif value is Array:
		for child: Variant in value:
			_collect_dictionaries(child, output)


static func _engine_hidden_shape_safe(tree: Dictionary) -> bool:
	var current: Variant = tree.get("current")
	if not current is Dictionary or typeof(current.get("yourIndex")) != TYPE_INT or int(current.get("yourIndex")) not in [0, 1]:
		return false
	var players: Variant = current.get("players")
	if not players is Array or players.size() != 2:
		return false
	var acting := int(current.get("yourIndex"))
	var opponent := 1 - acting
	for index: int in range(2):
		var player: Variant = players[index]
		if not player is Dictionary or (player.has("deck") and player.get("deck") is Array):
			return false
		var prize: Variant = player.get("prize")
		if not prize is Array:
			return false
		for card: Variant in prize:
			if card != null:
				return false
	if players[opponent].get("hand") != null or typeof(players[opponent].get("handCount")) != TYPE_INT:
		return false
	return true


func _mutate_tree(tree: Dictionary, mutation: String) -> String:
	var dictionaries := []
	_collect_dictionaries(tree, dictionaries)
	var identities := []
	for item_value: Variant in dictionaries:
		var identity := _identity_record(item_value)
		if bool(identity.get("present", false)):
			identities.append([item_value, identity])
	if identities.is_empty():
		return "frame_identity_invalid"
	if mutation == "card_unknown":
		var item: Dictionary = identities[0][0]
		item["id" if item.has("id") else "cardId"] = 9999
	elif mutation == "player_index_invalid":
		identities[0][0]["playerIndex"] = 2
	elif mutation == "serial_relation_conflict":
		var seen := {}
		var changed := false
		for pair: Array in identities:
			var item: Dictionary = pair[0]
			var identity: Dictionary = pair[1]
			var serial: int = identity.get("serial")
			if seen.has(serial):
				item["id" if item.has("id") else "cardId"] = 7 if identity.get("official_id") != 7 else 112
				changed = true
				break
			seen[serial] = true
		if not changed:
			return "frame_identity_invalid"
	elif mutation == "attack_unknown":
		for item_value: Variant in dictionaries:
			if item_value.has("attackId"):
				item_value["attackId"] = 9999
				break
	elif mutation == "attack_owner_mismatch":
		for item_value: Variant in dictionaries:
			if item_value.has("attackId") and item_value.has("cardId"):
				item_value["cardId"] = 7
				item_value["serial"] = MAX_SAFE_INTEGER
				break
	elif mutation == "hidden_private_key":
		tree["private_sentinel"] = "SECRET"
	elif mutation == "host_entity_key":
		tree["host_pokemon_entity_serial"] = 1
	else:
		return "input_type_invalid"
	return ""


func _runtime_digest() -> String:
	return _canonical_sha256({"bundle":_bundle,"schema":_schema,"profile":_profile,"audit":_audit,"vectors":_vectors})


func _relation_cache_digest() -> String:
	var owners := {}
	for attack_id: Variant in _attack_owners:
		owners[str(attack_id)] = _attack_owners[attack_id]
	return _canonical_sha256({
		"known_cards":_sorted_int_keys(_known_cards),
		"mapped_cards":_sorted_int_keys(_mapped_cards),
		"attack_owners":owners,
	})


static func _sorted_int_keys(value: Dictionary) -> Array:
	var result: Array = value.keys()
	result.sort()
	return result


static func _result(value: Variant, error: String = "") -> Dictionary:
	return {"ok":error.is_empty(),"error_code":error,"value":_copy(value) if error.is_empty() else null}


static func _copy(value: Variant) -> Variant:
	return value.duplicate(true) if value is Dictionary or value is Array else value


static func _same_keys(value: Variant, expected: Array) -> bool:
	if not value is Dictionary or value.keys().size() != expected.size():
		return false
	for key: Variant in expected:
		if typeof(key) != TYPE_STRING or not value.has(key):
			return false
	return true


static func _is_positive_safe_int(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and int(value) > 0 and int(value) <= MAX_SAFE_INTEGER


static func _root_is_supported(root: String) -> bool:
	return root.begins_with("res://") or root.begins_with("user://")


static func _is_safe_relative_path(path: String) -> bool:
	return not path.is_empty() and not path.begins_with("/") and not path.contains("\\") and not path.split("/").has("..") and not path.split("/").has(".")


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _result(null, "identity_file_missing")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _result(null, "identity_file_missing")
	var length := file.get_length()
	if length < 1 or length > MAX_JSON_BYTES:
		return _result(null, "identity_file_too_large")
	var source_bytes := file.get_buffer(length)
	var canonical := CabtJsonTreeScript.canonicalize_artifact_json_bytes(source_bytes, {"max_input_bytes":MAX_JSON_BYTES,"max_output_bytes":MAX_JSON_BYTES})
	if not bool(canonical.get("ok", false)):
		return _result(null, "identity_json_invalid")
	var text := source_bytes.get_string_from_utf8()
	if text.to_utf8_buffer() != source_bytes:
		return _result(null, "identity_json_invalid")
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return _result(null, "identity_json_invalid")
	var state := {"ok":true}
	var restored: Variant = _restore_integer_tokens(parser.data, state)
	if not bool(state.get("ok", false)) or not restored is Dictionary:
		return _result(null, "identity_json_invalid")
	return _result(restored)


static func _restore_integer_tokens(value: Variant, state: Dictionary) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			var number := float(value)
			if not is_finite(number) or number != floorf(number) or number < -float(MAX_SAFE_INTEGER) or number > float(MAX_SAFE_INTEGER):
				state["ok"] = false
				return null
			return int(number)
		TYPE_ARRAY:
			var result := []
			for child: Variant in value:
				result.append(_restore_integer_tokens(child, state))
				if not bool(state.get("ok", false)): return null
			return result
		TYPE_DICTIONARY:
			var result := {}
			for key: Variant in value:
				if typeof(key) != TYPE_STRING:
					state["ok"] = false
					return null
				result[key] = _restore_integer_tokens(value[key], state)
				if not bool(state.get("ok", false)): return null
			return result
		_:
			return value


static func _canonical_sha256(value: Variant) -> String:
	var canonical := CabtJsonTreeScript.canonicalize_artifact(value, {"max_input_bytes":MAX_JSON_BYTES,"max_output_bytes":MAX_JSON_BYTES})
	if not bool(canonical.get("ok", false)):
		return ""
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(canonical.get("bytes", PackedByteArray())) != OK:
		return ""
	return context.finish().hex_encode().to_upper()
