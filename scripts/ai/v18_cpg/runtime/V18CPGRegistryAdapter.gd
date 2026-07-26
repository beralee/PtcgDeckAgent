class_name V18CPGRegistryAdapter
extends RefCounted

const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")


static func feature_enabled() -> bool:
	var environment := OS.get_environment("V18CPG_FEATURE_ENABLED").strip_edges().to_lower()
	if environment != "":
		return environment in ["1", "true", "yes", "on"]
	return bool(ProjectSettings.get_setting("ai/v18_conditional_policy_enabled", false))


static func create_strategy_by_id(strategy_id: String, require_feature: bool = true) -> RefCounted:
	var profile := ProfileCatalogScript.get_profile_for_strategy(strategy_id)
	if profile.is_empty():
		return null
	if require_feature and not feature_enabled() and not bool(profile.get("battle_setup_available", false)):
		return null
	var strategy := StrategyScript.new()
	strategy.configure_profile(profile)
	return strategy


static func variants_for_deck(
	deck_id: int,
	base_strategy_id: String,
	api_configured: bool,
	feature_override: Variant = null
) -> Array[Dictionary]:
	var profile := ProfileCatalogScript.get_profile_for_deck(deck_id)
	if profile.is_empty() or str(profile.get("base_strategy_id", "")) != base_strategy_id:
		return []
	var enabled := feature_enabled() if feature_override == null else bool(feature_override)
	if not enabled and not (feature_override == null and bool(profile.get("battle_setup_available", false))):
		return []
	var result: Array[Dictionary] = [{
		"id": base_strategy_id,
		"label": "规则版",
		"runtime_kind": "rules",
	}]
	if api_configured:
		result.append({
			"id": str(profile.get("strategy_id", "")),
			"label": "大模型版",
			"runtime_kind": str(profile.get("runtime_kind", "")),
			"requires_model": true,
			"experimental": bool(profile.get("experimental", true)),
			"promotion_status": str(profile.get("promotion_status", "experimental")),
		})
	return result


static func is_v18cpg_strategy_id(strategy_id: String) -> bool:
	return not ProfileCatalogScript.get_profile_for_strategy(strategy_id).is_empty()
