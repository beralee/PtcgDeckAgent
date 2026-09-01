class_name AuthorStrategyWindowsExecutionGate
extends RefCounted

const DevelopmentGateScript = preload("res://scripts/ai/ptcgdap/host/godot/AuthorStrategyWindowsDevelopmentGate.gd")
const DeviceCanaryGateScript = preload("res://scripts/ai/ptcgdap/host/godot/AuthorStrategyWindowsDeviceCanaryGate.gd")
const ControlDistributionGateScript = preload("res://scripts/ai/ptcgdap/host/godot/AuthorStrategyControlDistributionGate.gd")
const DEVELOPMENT_MODE := "development_exact_fixture"
const DEVICE_CANARY_MODE := "production_device_canary"
const CONTROL_DISTRIBUTED_MODE := "control_distributed_player"


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
		return ControlDistributionGateScript.evaluate_selection(
			catalog, selection, platform_name
		)
	var result := DevelopmentGateScript.evaluate_selection(selection, platform_name)
	result["authority_mode"] = DEVELOPMENT_MODE
	return result


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
		return ControlDistributionGateScript.request_match_handle(
			catalog, selection, platform_name
		)
	var result := DevelopmentGateScript.request_match_handle(
		catalog, selection, platform_name
	)
	result["authority_mode"] = DEVELOPMENT_MODE
	return result


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


static func candidate_for_pins(pins: Dictionary, authority_mode: String) -> Dictionary:
	if authority_mode == CONTROL_DISTRIBUTED_MODE:
		return ControlDistributionGateScript.candidate_for_pins(pins)
	if authority_mode in [DEVELOPMENT_MODE, DEVICE_CANARY_MODE]:
		return DevelopmentGateScript.candidate_for_pins(pins)
	return {}
