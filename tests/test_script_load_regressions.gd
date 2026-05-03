class_name TestScriptLoadRegressions
extends TestBase


func test_rare_candy_and_card_semantic_matrix_scripts_load() -> String:
	var rare_candy_script := load("res://scripts/effects/trainer_effects/EffectRareCandy.gd")
	var semantic_matrix_script := load("res://tests/test_card_semantic_matrix.gd")
	var rare_candy_instance = rare_candy_script.new() if rare_candy_script != null and rare_candy_script.can_instantiate() else null
	var semantic_matrix_instance = semantic_matrix_script.new() if semantic_matrix_script != null and semantic_matrix_script.can_instantiate() else null

	return run_checks([
		assert_not_null(rare_candy_script, "EffectRareCandy.gd should load without compile errors"),
		assert_not_null(semantic_matrix_script, "test_card_semantic_matrix.gd should load without compile errors"),
		assert_not_null(rare_candy_instance, "EffectRareCandy.gd should instantiate without compile errors"),
		assert_not_null(semantic_matrix_instance, "test_card_semantic_matrix.gd should instantiate without compile errors"),
	])


func test_benchmark_runner_and_game_state_machine_scripts_load() -> String:
	var benchmark_runner_script := load("res://scripts/training/run_deck_benchmark.gd")
	var gsm_script := load("res://scripts/engine/GameStateMachine.gd")
	var benchmark_runner_instance = benchmark_runner_script.new() if benchmark_runner_script != null and benchmark_runner_script.can_instantiate() else null
	var gsm_instance = gsm_script.new() if gsm_script != null and gsm_script.can_instantiate() else null

	return run_checks([
		assert_not_null(benchmark_runner_script, "run_deck_benchmark.gd should load without compile errors"),
		assert_not_null(gsm_script, "GameStateMachine.gd should load without compile errors"),
		assert_not_null(benchmark_runner_instance, "run_deck_benchmark.gd should instantiate without compile errors"),
		assert_not_null(gsm_instance, "GameStateMachine.gd should instantiate without compile errors"),
	])


func test_raging_bolt_llm_self_play_tool_scripts_load() -> String:
	var tool_script := load("res://scripts/tools/RagingBoltLLMSelfPlayTool.gd")
	var runner_script := load("res://scripts/tools/run_raging_bolt_llm_self_play.gd")
	var tool_instance = tool_script.new() if tool_script != null and tool_script.can_instantiate() else null
	return run_checks([
		assert_not_null(tool_script, "RagingBoltLLMSelfPlayTool.gd should load without compile errors"),
		assert_not_null(runner_script, "run_raging_bolt_llm_self_play.gd should load without compile errors"),
		assert_not_null(tool_instance, "RagingBoltLLMSelfPlayTool.gd should instantiate without compile errors"),
	])


func test_llm_runtime_base_and_raging_bolt_variant_load() -> String:
	var runtime_script := load("res://scripts/ai/DeckStrategyLLMRuntimeBase.gd")
	var raging_script := load("res://scripts/ai/DeckStrategyRagingBoltLLM.gd")
	var runtime_instance = runtime_script.new() if runtime_script != null and runtime_script.can_instantiate() else null
	var raging_instance = raging_script.new() if raging_script != null and raging_script.can_instantiate() else null
	return run_checks([
		assert_not_null(runtime_script, "DeckStrategyLLMRuntimeBase.gd should load without compile errors"),
		assert_not_null(raging_script, "DeckStrategyRagingBoltLLM.gd should load without compile errors after runtime extraction"),
		assert_not_null(runtime_instance, "DeckStrategyLLMRuntimeBase.gd should instantiate without compile errors"),
		assert_not_null(raging_instance, "DeckStrategyRagingBoltLLM.gd should instantiate without compile errors"),
		assert_eq(str(raging_instance.call("get_strategy_id")) if raging_instance != null and raging_instance.has_method("get_strategy_id") else "", "raging_bolt_ogerpon_llm", "Raging Bolt LLM strategy id should remain stable"),
	])


func test_non_raging_llm_variants_extend_generic_runtime() -> String:
	var dragapult_source := FileAccess.get_file_as_string("res://scripts/ai/DeckStrategyDragapultCharizardLLM.gd")
	var miraidon_source := FileAccess.get_file_as_string("res://scripts/ai/DeckStrategyMiraidonLLM.gd")
	var lugia_source := FileAccess.get_file_as_string("res://scripts/ai/DeckStrategyLugiaArcheopsLLM.gd")
	var charizard_source := FileAccess.get_file_as_string("res://scripts/ai/DeckStrategyCharizardExLLM.gd")
	var dragapult_dusknoir_source := FileAccess.get_file_as_string("res://scripts/ai/DeckStrategyDragapultDusknoirLLM.gd")
	var gardevoir_source := FileAccess.get_file_as_string("res://scripts/ai/DeckStrategyGardevoirLLM.gd")
	var arceus_source := FileAccess.get_file_as_string("res://scripts/ai/DeckStrategyArceusGiratinaLLM.gd")
	return run_checks([
		assert_true(dragapult_source.contains("DeckStrategyLLMRuntimeBase.gd"), "Dragapult Charizard LLM should extend the generic LLM runtime base"),
		assert_true(miraidon_source.contains("DeckStrategyLLMRuntimeBase.gd"), "Miraidon LLM should extend the generic LLM runtime base"),
		assert_true(lugia_source.contains("DeckStrategyLLMRuntimeBase.gd"), "Lugia Archeops LLM should extend the generic LLM runtime base"),
		assert_true(charizard_source.contains("DeckStrategyLLMRuntimeBase.gd"), "Charizard ex LLM should extend the generic LLM runtime base"),
		assert_true(dragapult_dusknoir_source.contains("DeckStrategyLLMRuntimeBase.gd"), "Dragapult Dusknoir LLM should extend the generic LLM runtime base"),
		assert_true(gardevoir_source.contains("DeckStrategyLLMRuntimeBase.gd"), "Gardevoir LLM should extend the generic LLM runtime base"),
		assert_true(arceus_source.contains("DeckStrategyLLMRuntimeBase.gd"), "Arceus Giratina LLM should extend the generic LLM runtime base"),
		assert_false(dragapult_source.contains("DeckStrategyRagingBoltLLM.gd"), "Dragapult Charizard LLM must not inherit the Raging Bolt variant"),
		assert_false(miraidon_source.contains("DeckStrategyRagingBoltLLM.gd"), "Miraidon LLM must not inherit the Raging Bolt variant"),
		assert_false(lugia_source.contains("DeckStrategyRagingBoltLLM.gd"), "Lugia Archeops LLM must not inherit the Raging Bolt variant"),
		assert_false(charizard_source.contains("DeckStrategyRagingBoltLLM.gd"), "Charizard ex LLM must not inherit the Raging Bolt variant"),
		assert_false(dragapult_dusknoir_source.contains("DeckStrategyRagingBoltLLM.gd"), "Dragapult Dusknoir LLM must not inherit the Raging Bolt variant"),
		assert_false(gardevoir_source.contains("DeckStrategyRagingBoltLLM.gd"), "Gardevoir LLM must not inherit the Raging Bolt variant"),
		assert_false(arceus_source.contains("DeckStrategyRagingBoltLLM.gd"), "Arceus Giratina LLM must not inherit the Raging Bolt variant"),
		assert_false(miraidon_source.to_lower().contains("raging_bolt"), "Miraidon LLM wrapper must not contain Raging Bolt-specific references"),
		assert_false(lugia_source.to_lower().contains("raging_bolt"), "Lugia Archeops LLM wrapper must not contain Raging Bolt-specific references"),
	])


func test_llm_runtime_core_uses_deck_hooks_for_deck_specific_logic() -> String:
	var runtime_source := FileAccess.get_file_as_string("res://scripts/ai/DeckStrategyLLMRuntimeBase.gd")
	var core_end := runtime_source.find("func _is_raging_bolt_first_attack_ref")
	var core_source := runtime_source.substr(0, core_end) if core_end > 0 else runtime_source
	return run_checks([
		assert_true(core_source.contains("_deck_can_replace_end_turn_with_action"), "Runtime queue matching should use deck hook for end-turn replacement"),
		assert_true(core_source.contains("_deck_action_ref_enables_attack"), "Runtime contract repair should use deck hook for deck-specific attack setup"),
		assert_true(core_source.contains("_deck_validate_action_interactions"), "Runtime contract validation should delegate deck-specific interaction rules"),
		assert_false(core_source.contains("Raging Bolt"), "Core runtime section must not mention Raging Bolt directly"),
		assert_false(core_source.contains("Teal Mask Ogerpon"), "Core runtime section must not mention Ogerpon directly"),
		assert_false(core_source.contains("Professor Sada"), "Core runtime section must not mention Sada directly"),
		assert_false(core_source.contains("Earthen Vessel"), "Core runtime section must not mention Earthen Vessel directly"),
	])


func test_miraidon_llm_strategy_script_loads() -> String:
	var script := load("res://scripts/ai/DeckStrategyMiraidonLLM.gd")
	var instance = script.new() if script != null and script.can_instantiate() else null
	return run_checks([
		assert_not_null(script, "DeckStrategyMiraidonLLM.gd should load without compile errors"),
		assert_not_null(instance, "DeckStrategyMiraidonLLM.gd should instantiate without compile errors"),
		assert_eq(str(instance.call("get_strategy_id")) if instance != null and instance.has_method("get_strategy_id") else "", "miraidon_llm", "Miraidon LLM strategy id should be registered by the script"),
	])


func test_dragapult_charizard_llm_strategy_loads() -> String:
	var rules_script := load("res://scripts/ai/DeckStrategyDragapultCharizard.gd")
	var llm_script := load("res://scripts/ai/DeckStrategyDragapultCharizardLLM.gd")
	var registry_script := load("res://scripts/ai/DeckStrategyRegistry.gd")
	var llm_instance = llm_script.new() if llm_script != null and llm_script.can_instantiate() else null
	return run_checks([
		assert_not_null(rules_script, "DeckStrategyDragapultCharizard.gd should load without compile errors"),
		assert_not_null(llm_script, "DeckStrategyDragapultCharizardLLM.gd should load without compile errors"),
		assert_not_null(registry_script, "DeckStrategyRegistry.gd should load after registering the LLM variant"),
		assert_not_null(llm_instance, "DeckStrategyDragapultCharizardLLM.gd should instantiate without compile errors"),
	])


func test_lugia_archeops_llm_strategy_loads() -> String:
	var rules_script := load("res://scripts/ai/DeckStrategyLugiaArcheops.gd")
	var llm_script := load("res://scripts/ai/DeckStrategyLugiaArcheopsLLM.gd")
	var registry_script := load("res://scripts/ai/DeckStrategyRegistry.gd")
	var llm_instance = llm_script.new() if llm_script != null and llm_script.can_instantiate() else null
	var registry = registry_script.new() if registry_script != null and registry_script.can_instantiate() else null
	var registry_instance = registry.call("create_strategy_by_id", "lugia_archeops_llm") if registry != null else null
	return run_checks([
		assert_not_null(rules_script, "DeckStrategyLugiaArcheops.gd should load without compile errors"),
		assert_not_null(llm_script, "DeckStrategyLugiaArcheopsLLM.gd should load without compile errors"),
		assert_not_null(registry_script, "DeckStrategyRegistry.gd should load after registering the Lugia LLM variant"),
		assert_not_null(llm_instance, "DeckStrategyLugiaArcheopsLLM.gd should instantiate without compile errors"),
		assert_eq(str(llm_instance.call("get_strategy_id")) if llm_instance != null and llm_instance.has_method("get_strategy_id") else "", "lugia_archeops_llm", "Lugia LLM strategy id should be stable"),
		assert_not_null(registry_instance, "Registry should create lugia_archeops_llm"),
		assert_eq(str(registry_instance.call("get_strategy_id")) if registry_instance != null and registry_instance.has_method("get_strategy_id") else "", "lugia_archeops_llm", "Registered Lugia LLM variant should report its strategy id"),
	])


func test_dragapult_dusknoir_llm_strategy_loads() -> String:
	var rules_script := load("res://scripts/ai/DeckStrategyDragapultDusknoir.gd")
	var llm_script := load("res://scripts/ai/DeckStrategyDragapultDusknoirLLM.gd")
	var registry_script := load("res://scripts/ai/DeckStrategyRegistry.gd")
	var llm_instance = llm_script.new() if llm_script != null and llm_script.can_instantiate() else null
	var registry = registry_script.new() if registry_script != null and registry_script.can_instantiate() else null
	var registry_instance = registry.call("create_strategy_by_id", "dragapult_dusknoir_llm") if registry != null else null
	return run_checks([
		assert_not_null(rules_script, "DeckStrategyDragapultDusknoir.gd should load without compile errors"),
		assert_not_null(llm_script, "DeckStrategyDragapultDusknoirLLM.gd should load without compile errors"),
		assert_not_null(registry_script, "DeckStrategyRegistry.gd should load after registering the Dragapult Dusknoir LLM variant"),
		assert_not_null(llm_instance, "DeckStrategyDragapultDusknoirLLM.gd should instantiate without compile errors"),
		assert_eq(str(llm_instance.call("get_strategy_id")) if llm_instance != null and llm_instance.has_method("get_strategy_id") else "", "dragapult_dusknoir_llm", "Dragapult Dusknoir LLM strategy id should be stable"),
		assert_not_null(registry_instance, "Registry should create dragapult_dusknoir_llm"),
		assert_eq(str(registry_instance.call("get_strategy_id")) if registry_instance != null and registry_instance.has_method("get_strategy_id") else "", "dragapult_dusknoir_llm", "Registered Dragapult Dusknoir LLM variant should report its strategy id"),
	])


func test_charizard_ex_llm_strategy_loads() -> String:
	var rules_script := load("res://scripts/ai/DeckStrategyCharizardEx.gd")
	var llm_script := load("res://scripts/ai/DeckStrategyCharizardExLLM.gd")
	var registry_script := load("res://scripts/ai/DeckStrategyRegistry.gd")
	var llm_instance = llm_script.new() if llm_script != null and llm_script.can_instantiate() else null
	var registry = registry_script.new() if registry_script != null and registry_script.can_instantiate() else null
	var registry_instance = registry.call("create_strategy_by_id", "charizard_ex_llm") if registry != null else null
	return run_checks([
		assert_not_null(rules_script, "DeckStrategyCharizardEx.gd should load without compile errors"),
		assert_not_null(llm_script, "DeckStrategyCharizardExLLM.gd should load without compile errors"),
		assert_not_null(registry_script, "DeckStrategyRegistry.gd should load after registering the Charizard ex LLM variant"),
		assert_not_null(llm_instance, "DeckStrategyCharizardExLLM.gd should instantiate without compile errors"),
		assert_eq(str(llm_instance.call("get_strategy_id")) if llm_instance != null and llm_instance.has_method("get_strategy_id") else "", "charizard_ex_llm", "Charizard ex LLM strategy id should be stable"),
		assert_not_null(registry_instance, "Registry should create charizard_ex_llm"),
		assert_eq(str(registry_instance.call("get_strategy_id")) if registry_instance != null and registry_instance.has_method("get_strategy_id") else "", "charizard_ex_llm", "Registered Charizard ex LLM variant should report its strategy id"),
	])


func test_gardevoir_llm_strategy_loads() -> String:
	var rules_script := load("res://scripts/ai/DeckStrategyGardevoir.gd")
	var llm_script := load("res://scripts/ai/DeckStrategyGardevoirLLM.gd")
	var registry_script := load("res://scripts/ai/DeckStrategyRegistry.gd")
	var llm_instance = llm_script.new() if llm_script != null and llm_script.can_instantiate() else null
	var registry = registry_script.new() if registry_script != null and registry_script.can_instantiate() else null
	var registry_instance = registry.call("create_strategy_by_id", "gardevoir_llm") if registry != null else null
	return run_checks([
		assert_not_null(rules_script, "DeckStrategyGardevoir.gd should load without compile errors"),
		assert_not_null(llm_script, "DeckStrategyGardevoirLLM.gd should load without compile errors"),
		assert_not_null(registry_script, "DeckStrategyRegistry.gd should load after registering the Gardevoir LLM variant"),
		assert_not_null(llm_instance, "DeckStrategyGardevoirLLM.gd should instantiate without compile errors"),
		assert_eq(str(llm_instance.call("get_strategy_id")) if llm_instance != null and llm_instance.has_method("get_strategy_id") else "", "gardevoir_llm", "Gardevoir LLM strategy id should be stable"),
		assert_not_null(registry_instance, "Registry should create gardevoir_llm"),
		assert_eq(str(registry_instance.call("get_strategy_id")) if registry_instance != null and registry_instance.has_method("get_strategy_id") else "", "gardevoir_llm", "Registered Gardevoir LLM variant should report its strategy id"),
	])


func test_arceus_giratina_llm_strategy_loads() -> String:
	var rules_script := load("res://scripts/ai/DeckStrategyArceusGiratina.gd")
	var llm_script := load("res://scripts/ai/DeckStrategyArceusGiratinaLLM.gd")
	var registry_script := load("res://scripts/ai/DeckStrategyRegistry.gd")
	var llm_instance = llm_script.new() if llm_script != null and llm_script.can_instantiate() else null
	var registry = registry_script.new() if registry_script != null and registry_script.can_instantiate() else null
	var registry_instance = registry.call("create_strategy_by_id", "arceus_giratina_llm") if registry != null else null
	return run_checks([
		assert_not_null(rules_script, "DeckStrategyArceusGiratina.gd should load without compile errors"),
		assert_not_null(llm_script, "DeckStrategyArceusGiratinaLLM.gd should load without compile errors"),
		assert_not_null(registry_script, "DeckStrategyRegistry.gd should load after registering the Arceus Giratina LLM variant"),
		assert_not_null(llm_instance, "DeckStrategyArceusGiratinaLLM.gd should instantiate without compile errors"),
		assert_eq(str(llm_instance.call("get_strategy_id")) if llm_instance != null and llm_instance.has_method("get_strategy_id") else "", "arceus_giratina_llm", "Arceus Giratina LLM strategy id should be stable"),
		assert_not_null(registry_instance, "Registry should create arceus_giratina_llm"),
		assert_eq(str(registry_instance.call("get_strategy_id")) if registry_instance != null and registry_instance.has_method("get_strategy_id") else "", "arceus_giratina_llm", "Registered Arceus Giratina LLM variant should report its strategy id"),
	])
