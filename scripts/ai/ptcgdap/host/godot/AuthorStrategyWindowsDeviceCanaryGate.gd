class_name AuthorStrategyWindowsDeviceCanaryGate
extends RefCounted

## One-shot authority for collecting the first formal Windows device evidence.
## It deliberately stops below ordinary player start and never accepts the
## development fixture key or a caller-supplied approval/device report.
const ACTIVATION_ARG := "--ptcgdap-production-device-canary"
const DEVELOPMENT_UI_ARG := "--ptcgdap-development-ui-match"
const AUTHORITY_MODE := "production_device_canary"
const INSTALL_SOURCE := "built_in"
const SOURCE_DECK_ID := 800018501
const CARD_ID_DOMAIN := "godot_local_card_uid_v1"
const ReleaseGateScript = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyReleaseGate.gd")
const FeatureGateScript = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyFeatureGate.gd")


static func is_activation_requested(args: Variant = null) -> bool:
	return ACTIVATION_ARG in _resolved_args(args)


static func activation_state(args: Variant = null) -> Dictionary:
	var resolved := _resolved_args(args)
	var canary_count := resolved.count(ACTIVATION_ARG)
	if canary_count == 0:
		return {"active": false, "error_code": ""}
	if canary_count != 1 or DEVELOPMENT_UI_ARG in resolved:
		return {"active": false, "error_code": "device_canary_activation_invalid"}
	return {"active": true, "error_code": ""}


static func evaluate_selection(
	catalog: Variant,
	selection: Dictionary,
	platform_name: String = "",
	args: Variant = null,
	template_feature: Variant = null,
	editor_feature: Variant = null
) -> Dictionary:
	var environment_error := _runtime_environment_error(
		platform_name, args, template_feature, editor_feature
	)
	if not environment_error.is_empty():
		return _error(environment_error)
	if selection.get("install_source") != INSTALL_SOURCE:
		return _error("device_canary_not_approved")
	if catalog == null or not catalog.has_method("list_metadata_records"):
		return _error("package_catalog_unavailable")
	var metadata: Dictionary = {}
	for value: Variant in catalog.call("list_metadata_records"):
		if not value is Dictionary:
			continue
		var record: Dictionary = value
		if (
			record.get("package_id") == selection.get("package_id")
			and record.get("package_version") == selection.get("package_version")
			and record.get("archive_sha256") == str(selection.get("archive_sha256", "")).to_upper()
			and record.get("install_source") == INSTALL_SOURCE
		):
			metadata = record.duplicate(true)
			break
	if metadata.is_empty():
		return _error("device_canary_not_approved")
	if (
		metadata.get("source_deck_id") != SOURCE_DECK_ID
		or metadata.get("deck_card_id_domain") != CARD_ID_DOMAIN
		or metadata.get("deck_platform_scope") != ["windows"]
		or metadata.get("deck_card_count") != 60
	):
		return _error("device_canary_not_approved")
	var release := ReleaseGateScript.new().evaluate_device_canary_package(metadata, "windows")
	if not bool(release.get("accepted", false)) or not bool(release.get("device_canary_allowed", false)):
		return _error(str(release.get("error_code", "device_canary_not_approved")))
	return {
		"ok": true,
		"error_code": "",
		"authority_mode": AUTHORITY_MODE,
		"source_deck_id": SOURCE_DECK_ID,
		"device_canary_allowed": true,
		"player_start_allowed": false,
		"production_ready": false,
		"approval_source": release.get("authority_source"),
	}


static func request_match_handle(
	catalog: Variant,
	selection: Dictionary,
	platform_name: String = "",
	args: Variant = null,
	template_feature: Variant = null,
	editor_feature: Variant = null
) -> Dictionary:
	var admitted := evaluate_selection(
		catalog, selection, platform_name, args, template_feature, editor_feature
	)
	if not bool(admitted.get("ok", false)):
		return {"ok": false, "error_code": admitted.get("error_code"), "handle": null}
	if not catalog.has_method("request_match_handle"):
		return {"ok": false, "error_code": "package_catalog_unavailable", "handle": null}
	var requested: Variant = catalog.call(
		"request_match_handle",
		str(selection.get("package_id", "")),
		str(selection.get("package_version", "")),
		str(selection.get("archive_sha256", "")).to_upper()
	)
	if not requested is Dictionary or not bool(requested.get("ok", false)):
		return {
			"ok": false,
			"error_code": str(requested.get("error_code", "package_integrity_invalid")) if requested is Dictionary else "package_integrity_invalid",
			"handle": null,
		}
	var handle: Variant = requested.get("handle")
	if handle == null or not handle.has_method("validate_integrity") or not handle.validate_integrity():
		return {"ok": false, "error_code": "package_integrity_invalid", "handle": null}
	var pin_error := validate_handle_pins(handle.to_public_dict())
	if not pin_error.is_empty():
		return {"ok": false, "error_code": pin_error, "handle": null}
	return {
		"ok": true,
		"error_code": "",
		"handle": handle,
		"authority_mode": AUTHORITY_MODE,
		"source_deck_id": SOURCE_DECK_ID,
		"device_canary_allowed": true,
		"player_start_allowed": false,
		"production_ready": false,
	}


static func validate_handle_pins(pins: Dictionary) -> String:
	if (
		pins.get("source_deck_id") != SOURCE_DECK_ID
		or pins.get("deck_card_id_domain") != CARD_ID_DOMAIN
		or pins.get("deck_platform_scope") != ["windows"]
		or pins.get("local_deck_card_count") != 60
		or pins.get("local_deck_unique_printing_count") != 28
		or pins.get("cabt_exportable") != false
		or pins.get("signature_status") != "production_trusted"
		or pins.get("signature_scope") != "production_release"
		or pins.get("execution_trusted") != true
		or pins.get("development_shadow_ready") != false
		or pins.get("live_authority") != false
	):
		return "device_canary_not_approved"
	var release := ReleaseGateScript.new().evaluate_device_canary_package(pins, "windows")
	if not bool(release.get("accepted", false)) or not bool(release.get("device_canary_allowed", false)):
		return str(release.get("error_code", "device_canary_not_approved"))
	return ""


static func validate_runtime_activation() -> String:
	return _runtime_environment_error("", null, null, null)


static func _runtime_environment_error(
	platform_name: String,
	args: Variant,
	template_feature: Variant,
	editor_feature: Variant
) -> String:
	var resolved_args := _resolved_args(args)
	var activation := activation_state(resolved_args)
	if not bool(activation.get("active", false)):
		return str(activation.get("error_code", "device_canary_activation_invalid")) \
			if not str(activation.get("error_code", "")).is_empty() else "device_canary_activation_invalid"
	if not FeatureGateScript.is_enabled_for_args(resolved_args):
		return "author_strategy_feature_disabled"
	var platform := platform_name if not platform_name.is_empty() else OS.get_name()
	if platform != "Windows":
		return "device_canary_platform_invalid"
	var is_template: bool = OS.has_feature("template") if template_feature == null else bool(template_feature)
	var is_editor: bool = OS.has_feature("editor") if editor_feature == null else bool(editor_feature)
	if not is_template or is_editor:
		return "device_canary_activation_invalid"
	return ""


static func _resolved_args(args: Variant) -> PackedStringArray:
	if args == null:
		return OS.get_cmdline_user_args()
	var result := PackedStringArray()
	if args is PackedStringArray or args is Array:
		for value: Variant in args:
			result.append(str(value))
	return result


static func _error(code: String) -> Dictionary:
	return {
		"ok": false,
		"error_code": code,
		"authority_mode": AUTHORITY_MODE,
		"source_deck_id": -1,
		"device_canary_allowed": false,
		"player_start_allowed": false,
		"production_ready": false,
	}
