class_name AuthorStrategyWindowsExecutionGate
extends RefCounted

const DevelopmentGateScript = preload("res://scripts/ai/ptcgdap/host/godot/AuthorStrategyWindowsDevelopmentGate.gd")
const DeviceCanaryGateScript = preload("res://scripts/ai/ptcgdap/host/godot/AuthorStrategyWindowsDeviceCanaryGate.gd")
const ControlDistributionGateScript = preload("res://scripts/ai/ptcgdap/host/godot/AuthorStrategyControlDistributionGate.gd")
const DEVELOPMENT_MODE := "development_exact_fixture"
const DEVICE_CANARY_MODE := "production_device_canary"
const CONTROL_DISTRIBUTED_MODE := "control_distributed_player"
const PlatformCapabilitiesScript = preload("res://scripts/ai/ptcgdap/host/godot/AuthorStrategyPlatformCapabilities.gd")
const PortabilityScript = preload("res://scripts/ai/ptcgdap/host/godot/AuthorStrategyPortability.gd")
const ModelActorScript = preload("res://scripts/ai/ptcgdap/host/godot/PtcgDAPModelActor.gd")


static func is_device_canary_requested(args: Variant = null) -> bool:
	return DeviceCanaryGateScript.is_activation_requested(args)


static func evaluate_selection(
	catalog: Variant,
	selection: Dictionary,
	platform_name: String = "",
	args: Variant = null,
	template_feature: Variant = null,
	editor_feature: Variant = null
) -> Dictionary:
	if is_device_canary_requested(args):
		return DeviceCanaryGateScript.evaluate_selection(
			catalog, selection, platform_name, args, template_feature, editor_feature
		)
	if ControlDistributionGateScript.has_selection(catalog, selection):
		return _with_selection_compatibility(
			ControlDistributionGateScript.evaluate_selection(catalog, selection, platform_name),
			catalog, selection, platform_name
		)
	var result := DevelopmentGateScript.evaluate_selection(selection, platform_name)
	result["authority_mode"] = DEVELOPMENT_MODE
	return _with_selection_compatibility(result, catalog, selection, platform_name)


static func request_match_handle(
	catalog: Variant,
	selection: Dictionary,
	platform_name: String = "",
	args: Variant = null,
	template_feature: Variant = null,
	editor_feature: Variant = null
) -> Dictionary:
	if is_device_canary_requested(args):
		return DeviceCanaryGateScript.request_match_handle(
			catalog, selection, platform_name, args, template_feature, editor_feature
		)
	if ControlDistributionGateScript.has_selection(catalog, selection):
		return _with_handle_compatibility(
			ControlDistributionGateScript.request_match_handle(catalog, selection, platform_name)
		)
	var result := DevelopmentGateScript.request_match_handle(
		catalog, selection, platform_name
	)
	result["authority_mode"] = DEVELOPMENT_MODE
	return _with_handle_compatibility(result)


static func validate_handle_pins(pins: Dictionary, authority_mode: String) -> String:
	if authority_mode == DEVICE_CANARY_MODE:
		var activation_error := DeviceCanaryGateScript.validate_runtime_activation()
		if not activation_error.is_empty():
			return activation_error
		return DeviceCanaryGateScript.validate_handle_pins(pins)
	if authority_mode == DEVELOPMENT_MODE:
		return DevelopmentGateScript.validate_handle_pins(pins)
	if authority_mode == CONTROL_DISTRIBUTED_MODE:
		return ControlDistributionGateScript.validate_handle_pins(pins)
	return "invalid_bind"


static func validate_player_start(pins: Dictionary, authority_mode: String) -> String:
	# Admission switches affect new owners only. An active owner continues to
	# validate its original trust pins without changing authority mid-match.
	var error := validate_handle_pins(pins, authority_mode)
	if not error.is_empty() or authority_mode == DEVICE_CANARY_MODE:
		return error
	return _player_compatibility_error(pins, authority_mode)


static func candidate_for_pins(pins: Dictionary, authority_mode: String) -> Dictionary:
	if authority_mode == CONTROL_DISTRIBUTED_MODE:
		return ControlDistributionGateScript.candidate_for_pins(pins)
	if authority_mode in [DEVELOPMENT_MODE, DEVICE_CANARY_MODE]:
		return DevelopmentGateScript.candidate_for_pins(pins)
	return {}


static func player_host_available() -> bool:
	return bool(PlatformCapabilitiesScript.inspect().get("rules_available"))


static func _player_compatibility_error(pins: Dictionary, authority_mode: String) -> String:
	# Dedicated competition remains governed by its existing host authorization.
	if OS.get_name() == "Linux":
		return ""
	var outcome := PortabilityScript.evaluate(
		pins, candidate_for_pins(pins, authority_mode), PlatformCapabilitiesScript.inspect()
	)
	return str(outcome.get("error_code", "author_strategy_package_not_portable"))


static func _with_selection_compatibility(
	result: Dictionary, catalog: Variant, selection: Dictionary, platform_name: String
) -> Dictionary:
	if not bool(result.get("ok", false)) or catalog == null:
		return result
	var records: Variant = []
	if catalog.has_method("list_metadata_records"):
		records = catalog.call("list_metadata_records")
	elif catalog.has_method("list_ready_records"):
		records = catalog.call("list_ready_records")
	if not records is Array:
		return result
	for value: Variant in records:
		if not value is Dictionary or value.get("package_id") != selection.get("package_id") \
				or value.get("package_version") != selection.get("package_version") \
				or str(value.get("archive_sha256", "")).to_upper() != str(selection.get("archive_sha256", "")).to_upper() \
				or value.get("install_source") != selection.get("install_source"):
			continue
		var candidate: Dictionary = value.get("server_competition_candidate", {}) \
			if result.get("authority_mode") == CONTROL_DISTRIBUTED_MODE \
			else DevelopmentGateScript.candidate_for_selection(selection)
		var portability := PortabilityScript.evaluate(value, candidate, PlatformCapabilitiesScript.inspect(platform_name))
		if not bool(portability.get("ok", false)):
			result["ok"] = false
			result["player_start_allowed"] = false
			result["error_code"] = portability.get("error_code")
		return result
	return result


static func _with_handle_compatibility(result: Dictionary) -> Dictionary:
	if not bool(result.get("ok", false)):
		return result
	var handle: Variant = result.get("handle")
	var error := _player_compatibility_error(handle.to_public_dict(), str(result.get("authority_mode")))
	if error.is_empty():
		error = ModelActorScript.preflight_error(handle)
	if not error.is_empty():
		result["ok"] = false
		result["handle"] = null
		result["error_code"] = error
	return result
