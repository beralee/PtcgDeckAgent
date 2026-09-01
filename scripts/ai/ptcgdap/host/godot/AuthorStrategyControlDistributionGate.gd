class_name AuthorStrategyControlDistributionGate
extends RefCounted

## Player authority for strategies installed from an exact Control download.
## Control owns public admission; the device still rechecks the immutable archive,
## package relations, deck mapping, and compatibility before every match.
const AUTHORITY_MODE := "control_distributed_player"
const INSTALL_SOURCE := "user"
const CARD_ID_DOMAIN := "godot_local_card_uid_v1"
const RUNTIME_KINDS := [
	"reviewed_restricted_ir_v1",
	"reviewed_competitive_policy_v2",
]
const FeatureGateScript = preload(
	"res://scripts/ai/ptcgdap/packages/AuthorStrategyFeatureGate.gd"
)


static func has_selection(catalog: Variant, selection: Dictionary) -> bool:
	return not _record_for_selection(catalog, selection).is_empty()


static func evaluate_selection(
	catalog: Variant,
	selection: Dictionary,
	platform_name: String = ""
) -> Dictionary:
	if not FeatureGateScript.is_enabled():
		return _error("author_strategy_feature_disabled")
	var platform := platform_name if not platform_name.is_empty() else OS.get_name()
	if platform != "Windows":
		return _error("control_distributed_platform_not_authorized")
	var record := _record_for_selection(catalog, selection)
	if record.is_empty() or not _valid_record(record):
		return _error("control_distributed_package_not_ready")
	var candidate: Dictionary = record.get("server_competition_candidate", {})
	return {
		"ok": true,
		"error_code": "",
		"authority_mode": AUTHORITY_MODE,
		"package_id": record.get("package_id"),
		"package_version": record.get("package_version"),
		"archive_sha256": record.get("archive_sha256"),
		"install_source": INSTALL_SOURCE,
		"source_deck_id": candidate.get("source_deck_id"),
		"card_id_domain": CARD_ID_DOMAIN,
		"player_start_allowed": true,
		"development_execution_only": false,
		"production_ready": false,
		"android_ready": false,
	}


static func request_match_handle(
	catalog: Variant,
	selection: Dictionary,
	platform_name: String = ""
) -> Dictionary:
	var admitted := evaluate_selection(catalog, selection, platform_name)
	if not bool(admitted.get("ok", false)):
		return {
			"ok": false,
			"error_code": admitted.get("error_code"),
			"handle": null,
			"authority_mode": AUTHORITY_MODE,
		}
	if catalog == null or not catalog.has_method("request_ready_match_handle"):
		return _request_error("package_catalog_unavailable")
	var requested: Variant = catalog.call(
		"request_ready_match_handle",
		admitted.get("package_id"),
		admitted.get("package_version"),
		admitted.get("archive_sha256")
	)
	if not requested is Dictionary or not bool(requested.get("ok", false)):
		return _request_error(
			str(requested.get("error_code", "package_integrity_invalid"))
			if requested is Dictionary
			else "package_integrity_invalid"
		)
	var handle: Variant = requested.get("handle")
	if handle == null or not handle.has_method("validate_integrity") \
			or not handle.validate_integrity():
		return _request_error("package_integrity_invalid")
	var pin_error := validate_handle_pins(handle.to_public_dict())
	if not pin_error.is_empty():
		return _request_error(pin_error)
	return {
		"ok": true,
		"error_code": "",
		"handle": handle,
		"authority_mode": AUTHORITY_MODE,
		"source_deck_id": admitted.get("source_deck_id"),
		"player_start_allowed": true,
		"development_execution_only": false,
		"production_ready": false,
	}


static func validate_handle_pins(pins: Dictionary) -> String:
	var candidate := candidate_for_pins(pins)
	if (
		candidate.is_empty()
		or pins.get("source_deck_id") != candidate.get("source_deck_id")
		or pins.get("deck_card_id_domain") != CARD_ID_DOMAIN
		or pins.get("deck_platform_scope") != ["windows"]
		or pins.get("local_deck_card_count") != 60
		or pins.get("local_deck_unique_printing_count")
			!= candidate.get("unique_printing_count")
		or pins.get("cabt_exportable") != false
		or pins.get("signature_status") != "control_distributed"
		or pins.get("signature_scope") != "control_distributed_release"
		or str(pins.get("signature_key_id", "")).is_empty()
		or pins.get("execution_trusted") != false
		or pins.get("development_shadow_ready") != false
		or pins.get("live_authority") != false
	):
		return "control_distributed_package_not_ready"
	return ""


static func candidate_for_pins(pins: Dictionary) -> Dictionary:
	var candidate: Variant = pins.get("server_competition_candidate")
	if not candidate is Dictionary:
		return {}
	if (
		candidate.get("package_id") != pins.get("package_id")
		or candidate.get("package_version") != pins.get("package_version")
		or candidate.get("source_deck_id") != pins.get("source_deck_id")
		or candidate.get("runtime_kind") not in RUNTIME_KINDS
		or int(candidate.get("unique_printing_count", 0)) <= 0
		or int(candidate.get("adapter_rule_count", -1)) < 0
		or str(candidate.get("strategy_id", "")).is_empty()
		or str(candidate.get("frame_profile_id", "")).is_empty()
	):
		return {}
	return (candidate as Dictionary).duplicate(true)


static func _record_for_selection(catalog: Variant, selection: Dictionary) -> Dictionary:
	if catalog == null or not catalog.has_method("list_ready_records"):
		return {}
	if selection.get("install_source") != INSTALL_SOURCE:
		return {}
	var records: Variant = catalog.call("list_ready_records")
	if not records is Array:
		return {}
	for value: Variant in records:
		if not value is Dictionary:
			continue
		var record := value as Dictionary
		if (
			record.get("package_id") == selection.get("package_id")
			and record.get("package_version") == selection.get("package_version")
			and str(record.get("archive_sha256", "")).to_upper()
				== str(selection.get("archive_sha256", "")).to_upper()
			and record.get("install_source") == INSTALL_SOURCE
		):
			return record.duplicate(true)
	return {}


static func _valid_record(record: Dictionary) -> bool:
	var candidate: Variant = record.get("server_competition_candidate")
	return (
		record.get("status") == "ready"
		and record.get("player_start_allowed") == true
		and record.get("signature_status") == "control_distributed"
		and record.get("signature_scope") == "control_distributed_release"
		and record.get("execution_trusted") == false
		and record.get("deck_card_id_domain") == CARD_ID_DOMAIN
		and record.get("deck_platform_scope") == ["windows"]
		and record.get("deck_card_count") == 60
		and candidate is Dictionary
		and candidate.get("package_id") == record.get("package_id")
		and candidate.get("package_version") == record.get("package_version")
		and candidate.get("source_deck_id") == record.get("source_deck_id")
		and candidate.get("runtime_kind") in RUNTIME_KINDS
	)


static func _request_error(code: String) -> Dictionary:
	return {
		"ok": false,
		"error_code": code,
		"handle": null,
		"authority_mode": AUTHORITY_MODE,
	}


static func _error(code: String) -> Dictionary:
	return {
		"ok": false,
		"error_code": code,
		"authority_mode": AUTHORITY_MODE,
		"source_deck_id": -1,
		"player_start_allowed": false,
		"development_execution_only": false,
		"production_ready": false,
		"android_ready": false,
	}
