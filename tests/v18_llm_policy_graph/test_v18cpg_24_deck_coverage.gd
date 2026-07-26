extends SceneTree

const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const RuleProfileCatalogScript = preload("res://scripts/ai/DeckStrategyV18ProfileCatalog.gd")
const CapabilityRegistryScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCapabilityRegistry.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")
const RegistryAdapterScript = preload("res://scripts/ai/v18_cpg/runtime/V18CPGRegistryAdapter.gd")
const SharedRegistryScript = preload("res://scripts/ai/DeckStrategyRegistry.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	var rule_ids := RuleProfileCatalogScript.deck_ids()
	var profiles := ProfileCatalogScript.list_profiles()
	var expected_ids := ProfileCatalogScript.ALL_DECK_IDS.duplicate()
	rule_ids.sort()
	expected_ids.sort()
	_check(rule_ids == expected_ids, "V18CPG deck ids must exactly match the Rule v18 catalog")
	_check(profiles.size() == 24, "V18CPG must construct exactly 24 profiles")
	var strategy_ids: Dictionary = {}
	var rows: Array[Dictionary] = []
	var released_ids := ProfileCatalogScript.released_deck_ids()
	_check(
		released_ids == [
			800015934,
			800018497,
			800018499,
			800018501,
			800018502,
			800018509,
		],
		"BattleSetup release metadata must contain exactly the promoted ROI decks"
	)
	_check(not RegistryAdapterScript.feature_enabled(), "V18CPG production feature flag must default off")
	for profile: Dictionary in profiles:
		var deck_id := int(profile.get("deck_id", 0))
		var strategy_id := str(profile.get("strategy_id", ""))
		var modules: Array = profile.get("modules", []) if profile.get("modules", []) is Array else []
		_check(deck_id in expected_ids, "%d is not a built-in 18.0 deck" % deck_id)
		_check(strategy_id != "" and not strategy_ids.has(strategy_id), "%d must have a unique strategy id" % deck_id)
		strategy_ids[strategy_id] = true
		_check(str(profile.get("base_strategy_id", "")) == RuleProfileCatalogScript.strategy_id_for_deck(deck_id), "%d must bind its exact Rule floor" % deck_id)
		_check(not modules.is_empty(), "%d must enable at least one capability module" % deck_id)
		_check(str(profile.get("primary_module", "")) == str(modules[0]), "%d primary module must be the first composed module" % deck_id)
		var registry := CapabilityRegistryScript.new()
		var frontier: Array[Dictionary] = [{
			"candidate_id": "candidate:end",
			"route_id": "route:end_turn",
			"safe_prefix_action_id": "end",
			"action_kind": "end_turn",
			"action_semantic_roles": [],
			"outcome": {"terminal": true},
		}]
		var observation := {
			"own": {"deck_count": 20, "discard": [], "active": {}, "bench": []},
			"opponent": {"deck_count": 20, "active": {}, "bench": []},
			"legal_actions": [{"id": "end", "kind": "end_turn"}],
			"turn": {"quotas": {"supporter_available": true, "energy_available": true}},
			"stadium": {},
		}
		var facts := {
			"attack": {"ready": false, "ko_available": false},
			"turn": {"supporter_available": true, "energy_available": true},
			"resources": {"deck_low": false, "deck_critical": false, "energy_on_board": 0, "bench_slots_free": 5},
			"board": {"has_tera": false, "bench_full": false},
		}
		var annotated := registry.annotate_frontier(frontier, observation, facts, profile, {})
		var annotations: Dictionary = annotated[0].get("module_annotations", {}) \
			if not annotated.is_empty() and annotated[0].get("module_annotations", {}) is Dictionary else {}
		for raw_module: Variant in modules:
			_check(annotations.has(str(raw_module)), "%d module %s must load and annotate" % [deck_id, str(raw_module)])
		var strategy := StrategyScript.new()
		strategy.configure_profile(profile)
		var metadata := strategy.get_runtime_metadata()
		_check(str(metadata.get("strategy_id", "")) == strategy_id, "%d runtime metadata must retain strategy identity" % deck_id)
		_check(bool(metadata.get("battle_setup_available", false)) == (deck_id in released_ids), "%d runtime metadata must retain release availability" % deck_id)
		_check(str(metadata.get("promotion_status", "")) == str(profile.get("promotion_status", "")), "%d runtime metadata must retain promotion status" % deck_id)
		var adapter_strategy := RegistryAdapterScript.create_strategy_by_id(strategy_id, false)
		_check(adapter_strategy != null and str(adapter_strategy.call("get_strategy_id")) == strategy_id, "%d registry adapter must construct the generic runtime" % deck_id)
		_check(RegistryAdapterScript.variants_for_deck(deck_id, str(profile.get("base_strategy_id", "")), true, false).is_empty(), "%d feature-off adapter must expose no variants" % deck_id)
		_check(RegistryAdapterScript.variants_for_deck(deck_id, str(profile.get("base_strategy_id", "")), true, true).size() == 2, "%d feature-on adapter must expose Rule and CPG variants" % deck_id)
		var production_variants := RegistryAdapterScript.variants_for_deck(deck_id, str(profile.get("base_strategy_id", "")), true)
		_check(production_variants.size() == (2 if deck_id in released_ids else 0), "%d production adapter visibility must follow ROI5 release metadata" % deck_id)
		_check(bool(profile.get("experimental", true)) == (deck_id not in released_ids), "%d experimental metadata must match release status" % deck_id)
		rows.append({
			"deck_id": deck_id,
			"display_name": str(profile.get("display_name", "")),
			"strategy_id": strategy_id,
			"base_strategy_id": str(profile.get("base_strategy_id", "")),
			"primary_module": str(profile.get("primary_module", "")),
			"modules": modules.duplicate(),
			"profile_version": int(profile.get("profile_version", 0)),
			"semantic_version": int(profile.get("semantic_version", 0)),
			"status": "profile-and-module-ready",
		})
	var variants := ProfileCatalogScript.list_variant_metadata(true)
	_check(variants.size() == 24, "feature-on metadata must expose exactly 24 V18CPG variants")
	_check(ProfileCatalogScript.list_variant_metadata(false).is_empty(), "feature-off metadata must expose zero V18CPG variants")
	var sample_profile := ProfileCatalogScript.get_profile_for_deck(expected_ids[0])
	var sample_strategy_id := str(sample_profile.get("strategy_id", ""))
	var shared_registry := SharedRegistryScript.new()
	_check(shared_registry.create_strategy_by_id(sample_strategy_id) == null, "shared registry must hide V18CPG while the production flag is off")
	_check(shared_registry.create_strategy_by_id(str(sample_profile.get("base_strategy_id", ""))) != null, "feature-off integration must preserve the existing Rule registry path")
	var released_profile := ProfileCatalogScript.get_profile_for_deck(800018502)
	var released_strategy_id := str(released_profile.get("strategy_id", ""))
	var released_strategy: RefCounted = shared_registry.create_strategy_by_id(released_strategy_id)
	_check(released_strategy != null and str(released_strategy.call("get_strategy_id")) == released_strategy_id, "released N's Zoroark strategy must construct while the experimental feature flag stays off")
	var setting_key := "ai/v18_conditional_policy_enabled"
	var had_setting := ProjectSettings.has_setting(setting_key)
	var previous_setting: Variant = ProjectSettings.get_setting(setting_key, false)
	ProjectSettings.set_setting(setting_key, true)
	for profile: Dictionary in profiles:
		var integrated_id := str(profile.get("strategy_id", ""))
		var integrated_strategy: RefCounted = shared_registry.create_strategy_by_id(integrated_id)
		_check(integrated_strategy != null and str(integrated_strategy.call("get_strategy_id")) == integrated_id, "%d shared registry must construct V18CPG after the production flag is enabled" % int(profile.get("deck_id", 0)))
	if had_setting:
		ProjectSettings.set_setting(setting_key, previous_setting)
	else:
		ProjectSettings.set_setting(setting_key, null)
	var report := {
		"schema_version": 1,
		"architecture": "V18CPG",
		"profile_count": profiles.size(),
		"unique_strategy_count": strategy_ids.size(),
		"feature_on_variant_count": variants.size(),
		"battle_setup_release_count": released_ids.size(),
		"all_passed": _failures.is_empty(),
		"rows": rows,
		"failures": _failures.duplicate(),
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tmp/v18cpg"))
	var output := FileAccess.open(ProjectSettings.globalize_path("res://tmp/v18cpg/v18cpg_24_profile_coverage.json"), FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(report, "  "))
		output.close()
	if _failures.is_empty():
		print("V18CPG 24-deck coverage: PASS (24/24 profiles, 12/12 capability modules)")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("V18CPG 24-deck coverage: FAIL (%d)" % _failures.size())
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
