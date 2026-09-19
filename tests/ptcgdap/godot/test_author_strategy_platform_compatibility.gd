extends TestBase

const CAPABILITIES_PATH := "res://scripts/ai/ptcgdap/host/godot/AuthorStrategyPlatformCapabilities.gd"
const PORTABILITY_PATH := "res://scripts/ai/ptcgdap/host/godot/AuthorStrategyPortability.gd"


func test_platform_baselines_and_unsupported_targets() -> String:
	if not ResourceLoader.exists(CAPABILITIES_PATH):
		return "Missing device-local platform capability owner"
	var service: Variant = load(CAPABILITIES_PATH)
	for target: Dictionary in [
		{"os":"Windows", "arch":"x86_64", "expected":true},
		{"os":"macOS", "arch":"arm64", "version":"13.3.0", "expected":true},
		{"os":"macOS", "arch":"x86_64", "version":"14.0", "expected":true},
		{"os":"macOS", "arch":"arm64", "version":"13.2.9", "expected":false},
		{"os":"macOS", "arch":"arm64", "version":"unknown", "expected":false},
		{"os":"Android", "arch":"arm64", "android_api":29, "expected":true},
		{"os":"Android", "arch":"x86_64", "android_api":29, "expected":true},
		{"os":"Android", "arch":"x86_64", "android_api":28, "expected":false},
		{"os":"Android", "arch":"arm64", "android_api":28, "expected":false},
		{"os":"Android", "arch":"x86", "android_api":35, "expected":false},
		{"os":"iOS", "arch":"arm64", "expected":false},
		{"os":"Web", "arch":"wasm32", "expected":true},
		{"os":"Linux", "arch":"x86_64", "expected":false},
	]:
		var result: Dictionary = service.evaluate_device(target, {})
		if result.get("rules_available") != target.get("expected"):
			return "Unexpected platform result: %s => %s" % [target, result]
	return ""


func test_web_rules_keep_package_authority_and_model_requirement() -> String:
	var service: Variant = load(CAPABILITIES_PATH)
	var portability: Variant = load(PORTABILITY_PATH)
	var caps: Dictionary = service.evaluate_device({"os":"Web", "arch":"wasm32"}, {
		"available":true, "version":"1.26.0", "execution_provider":"CPUExecutionProvider",
	})
	var metadata := {"package_schema_version":2, "policy_mode":"rules_only", "deck_card_id_domain":"godot_local_card_uid_v1", "deck_platform_scope":["windows"]}
	var candidate := {"runtime_kind":"reviewed_competitive_policy_v2"}
	var rules: Dictionary = portability.evaluate(metadata, candidate, caps)
	metadata["policy_mode"] = "rules_with_model"
	var model: Dictionary = portability.evaluate(metadata, candidate, caps)
	return run_checks([
		assert_true(rules.get("ok")),
		assert_eq(rules.get("effective_platform"), "web"),
		assert_eq(metadata.get("deck_platform_scope"), ["windows"]),
		assert_false(caps.get("model_available")),
		assert_eq(model.get("error_code"), "model_web_unavailable"),
		assert_true("浏览器" in service.error_text(str(model.get("error_code")))),
		assert_false(service.evaluate_device({"os":"Web", "arch":"wasm32", "enabled":false}, {}).get("rules_available")),
	])


func test_web_execution_resolves_worker_request_without_starting_threads() -> String:
	var service: Variant = load(CAPABILITIES_PATH)
	return run_checks([
		assert_eq(service.resolve_policy_execution_profile("worker_v1", "Web"), "main_thread_v1"),
		assert_eq(service.resolve_policy_execution_profile("main_thread_v1", "Web"), "main_thread_v1"),
		assert_eq(service.resolve_policy_execution_profile("worker_v1", "Windows"), "worker_v1"),
		assert_eq(service.resolve_policy_execution_profile("worker_v1", "Android"), "worker_v1"),
		assert_eq(service.resolve_policy_execution_profile("unknown", "Web"), "unknown"),
	])


func test_model_support_requires_real_compatible_backend() -> String:
	if not ResourceLoader.exists(CAPABILITIES_PATH):
		return "Missing platform capabilities"
	var service: Variant = load(CAPABILITIES_PATH)
	var target := {"os":"Android", "arch":"arm64", "android_api":35}
	var good := {"available":true, "version":"1.26.0", "execution_provider":"CPUExecutionProvider"}
	var result: Dictionary = service.evaluate_device(target, good)
	var missing: Dictionary = service.evaluate_device(target, {})
	var old: Dictionary = service.evaluate_device(target, {"available":true, "version":"1.25.0", "execution_provider":"CPUExecutionProvider"})
	return run_checks([
		assert_true(result.get("model_available")),
		assert_false(missing.get("model_available")),
		assert_true(missing.get("rules_available")),
		assert_false(old.get("model_available")),
	])


func test_macos_rules_release_rejects_models_even_if_a_runtime_is_present() -> String:
	var service: Variant = load(CAPABILITIES_PATH)
	var portability: Variant = load(PORTABILITY_PATH)
	var runtime := {"available":true, "version":"1.26.0", "execution_provider":"CPUExecutionProvider"}
	var metadata := {"package_schema_version":2, "policy_mode":"rules_only", "deck_card_id_domain":"godot_local_card_uid_v1", "deck_platform_scope":["windows"]}
	var candidate := {"runtime_kind":"reviewed_competitive_policy_v2"}
	var checks: Array[String] = []
	for arch: String in ["arm64", "x86_64"]:
		var caps: Dictionary = service.evaluate_device({"os":"macOS", "arch":arch, "version":"14.0"}, runtime)
		checks.append(assert_true(caps.get("rules_available"), "Mac rules remain available"))
		checks.append(assert_false(caps.get("model_available"), "Mac model support is intentionally paused"))
		metadata["policy_mode"] = "rules_only"
		checks.append(assert_true(portability.evaluate(metadata, candidate, caps).get("ok")))
		metadata["policy_mode"] = "rules_with_model"
		var rejected: Dictionary = portability.evaluate(metadata, candidate, caps)
		checks.append(assert_false(rejected.get("ok")))
		checks.append(assert_eq(rejected.get("error_code"), "model_macos_temporarily_unavailable"))
		checks.append(assert_true("Mac" in service.error_text(str(rejected.get("error_code"))), "Explain Mac limitation to the player"))
	for device: Dictionary in [{"os":"Windows", "arch":"x86_64"}, {"os":"Android", "arch":"arm64", "android_api":35}]:
		checks.append(assert_true(service.evaluate_device(device, runtime).get("model_available"), "Keep other native model platforms"))
	return run_checks(checks)


func test_platform_rollback_only_disables_that_target() -> String:
	if not ResourceLoader.exists(CAPABILITIES_PATH):
		return "Missing platform capabilities"
	var result: Dictionary = load(CAPABILITIES_PATH).evaluate_device(
		{"os":"macOS", "arch":"arm64", "version":"14.0", "enabled":false}, {}
	)
	return assert_eq(result.get("error_code"), "author_strategy_platform_disabled")


func test_legacy_portability_preserves_declared_identity_and_rejects_unknown_contracts() -> String:
	if not ResourceLoader.exists(PORTABILITY_PATH):
		return "Missing explicit legacy portability profile"
	var service: Variant = load(PORTABILITY_PATH)
	var pins := {"package_schema_version":2, "policy_mode":"rules_only", "deck_card_id_domain":"godot_local_card_uid_v1", "deck_platform_scope":["windows"]}
	var before := pins.duplicate(true)
	var candidate := {"runtime_kind":"reviewed_competitive_policy_v2"}
	var caps := {"rules_available":true, "model_available":false, "platform":"macos", "error_code":""}
	var good: Dictionary = service.evaluate(pins, candidate, caps)
	pins["package_schema_version"] = 99
	var unknown: Dictionary = service.evaluate(pins, candidate, caps)
	pins = before.duplicate(true)
	pins["policy_mode"] = "rules_with_model"
	var missing_model: Dictionary = service.evaluate(pins, candidate, caps)
	var altered_domain := before.duplicate(true)
	altered_domain["deck_card_id_domain"] = "cabt"
	return run_checks([
		assert_true(good.get("ok")),
		assert_eq(good.get("declared_platforms"), ["windows"]),
		assert_eq(good.get("effective_platform"), "macos"),
		assert_eq(before.get("deck_platform_scope"), ["windows"]),
		assert_false(unknown.get("ok")),
		assert_eq(missing_model.get("error_code"), "model_runtime_unavailable"),
		assert_false(service.evaluate(altered_domain, candidate, caps).get("ok")),
		assert_false(service.evaluate(before, {"runtime_kind":"unknown"}, caps).get("ok")),
	])
