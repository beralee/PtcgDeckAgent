class_name TestV175LugiaArcheopsLLM
extends TestBase

const LLM_SCRIPT_PATH := "res://scripts/ai/DeckStrategy175LugiaArcheopsLLM.gd"


func _new_llm_strategy() -> RefCounted:
	CardInstance.reset_id_counter()
	var script: Variant = load(LLM_SCRIPT_PATH)
	return script.new() if script is GDScript else null


func _make_regigigas_cd(name: String = "Localized Regigigas") -> CardData:
	var cd := CardData.new()
	cd.name = name
	cd.name_en = name
	cd.card_type = "Pokemon"
	cd.stage = "Basic"
	cd.energy_type = "C"
	cd.hp = 160
	cd.attacks.append({"name": "Jewel Break", "cost": "CCCC", "damage": "100+", "text": "Add damage against Tera.", "is_vstar_power": false})
	return cd


func _array_has_text(values: Variant, expected: String) -> bool:
	if not (values is Array):
		return false
	for raw: Variant in values:
		if str(raw) == expected:
			return true
	return false


func test_v175_lugia_llm_loads_registers_and_uses_v175_rules() -> String:
	var llm_script := load(LLM_SCRIPT_PATH)
	var registry_script := load("res://scripts/ai/DeckStrategyRegistry.gd")
	var llm_instance = llm_script.new() if llm_script != null and llm_script.can_instantiate() else null
	var registry = registry_script.new() if registry_script != null and registry_script.can_instantiate() else null
	var registry_instance = registry.call("create_strategy_by_id", "v175_lugia_archeops_llm") if registry != null else null
	var mcts_config: Dictionary = registry_instance.call("get_mcts_config") if registry_instance != null else {}
	return run_checks([
		assert_not_null(llm_script, "DeckStrategy175LugiaArcheopsLLM.gd should load"),
		assert_not_null(llm_instance, "DeckStrategy175LugiaArcheopsLLM.gd should instantiate"),
		assert_eq(str(llm_instance.call("get_strategy_id")) if llm_instance != null else "", "v175_lugia_archeops_llm", "17.5 Lugia LLM id should be stable"),
		assert_not_null(registry_instance, "Registry should create v175_lugia_archeops_llm"),
		assert_eq(str(registry_instance.call("get_strategy_id")) if registry_instance != null else "", "v175_lugia_archeops_llm", "Registered 17.5 Lugia LLM should report its id"),
		assert_true(registry_instance != null and registry_instance.has_method("get_llm_stats"), "17.5 Lugia LLM should expose runtime stats"),
		assert_true(int(mcts_config.get("time_budget_ms", 0)) >= 2200, "17.5 Lugia LLM should delegate rules fallback to the 17.5 Lugia strategy"),
	])


func test_v175_lugia_llm_prompt_and_profile_match_175_plan() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategy175LugiaArcheopsLLM.gd should load"
	var prompt_text := "\n".join(strategy.call("get_llm_deck_strategy_prompt", null, 0))
	var profile: Dictionary = strategy.call("get_intent_planner_profile")
	var energy_needs: Dictionary = profile.get("energy_needs", {}) if profile.get("energy_needs", {}) is Dictionary else {}
	return run_checks([
		assert_str_contains(prompt_text, "17.5 Lugia adjustments", "Prompt should identify the 17.5 Lugia variant"),
		assert_str_contains(prompt_text, "Nest Ball", "Prompt should explain the 17.5 Nest Ball route"),
		assert_str_contains(prompt_text, "Mesagoza", "Prompt should explain the 17.5 Mesagoza route"),
		assert_str_contains(prompt_text, "Wyrdeer V", "Prompt should name Wyrdeer V as a late attacker"),
		assert_str_contains(prompt_text, "Regigigas", "Prompt should name Regigigas as a late attacker"),
		assert_true(_array_has_text(profile.get("secondary_attackers", []), "Wyrdeer V"), "Profile should expose Wyrdeer V as a side attacker"),
		assert_true(_array_has_text(profile.get("secondary_attackers", []), "Regigigas"), "Profile should expose Regigigas as a side attacker"),
		assert_eq(str((energy_needs.get("Wyrdeer V", {}) as Dictionary).get("C", "")) if energy_needs.get("Wyrdeer V", {}) is Dictionary else "", "3", "Wyrdeer V profile should need 3 Colorless Energy"),
		assert_eq(str((energy_needs.get("Regigigas", {}) as Dictionary).get("C", "")) if energy_needs.get("Regigigas", {}) is Dictionary else "", "4", "Regigigas profile should need 4 Colorless Energy"),
	])


func test_v175_lugia_llm_role_hint_recognizes_regigigas_by_jewel_break() -> String:
	var strategy := _new_llm_strategy()
	if strategy == null:
		return "DeckStrategy175LugiaArcheopsLLM.gd should load"
	var regigigas_cd := _make_regigigas_cd()
	var hint := str(strategy.call("get_llm_setup_role_hint", regigigas_cd))
	return run_checks([
		assert_str_contains(hint, "late Basic side attacker", "Role hint should recognize Regigigas even when the runtime name is localized"),
		assert_true(bool(strategy.call("_is_lugia_setup_card", regigigas_cd)), "17.5 Lugia LLM setup catalog should treat Jewel Break Regigigas as a productive card"),
	])
