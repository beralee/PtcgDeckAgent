class_name TestEvolutionEngine
extends TestBase

const EvolutionEngineScript = preload("res://scripts/ai/EvolutionEngine.gd")
const AIHeuristicsScript = preload("res://scripts/ai/AIHeuristics.gd")


func test_mutate_produces_different_weights() -> String:
	var engine := EvolutionEngineScript.new()
	var base_config := {
		"heuristic_weights": AIHeuristicsScript.get_default_weights(),
		"mcts_config": {"branch_factor": 3, "rollouts_per_sequence": 20, "rollout_max_steps": 80, "time_budget_ms": 3000},
	}
	var mutant: Dictionary = engine.mutate(base_config)
	var base_w: Dictionary = base_config.get("heuristic_weights", {})
	var mutant_w: Dictionary = mutant.get("heuristic_weights", {})
	var any_different: bool = false
	for key: String in base_w.keys():
		if abs(float(mutant_w.get(key, 0.0)) - float(base_w[key])) > 0.001:
			any_different = true
			break
	return run_checks([
		assert_true(mutant.has("heuristic_weights"), "mutant 应包含 heuristic_weights"),
		assert_true(mutant.has("mcts_config"), "mutant 应包含 mcts_config"),
		assert_true(any_different, "突变后至少一个权重应不同"),
	])


func test_mutate_clamps_mcts_params() -> String:
	var engine := EvolutionEngineScript.new()
	engine.sigma_mcts = 10.0  # 极端扰动
	var base_config := {
		"heuristic_weights": AIHeuristicsScript.get_default_weights(),
		"mcts_config": {"branch_factor": 3, "rollouts_per_sequence": 20, "rollout_max_steps": 80, "time_budget_ms": 3000},
	}
	var mutant: Dictionary = engine.mutate(base_config)
	var mcts: Dictionary = mutant.get("mcts_config", {})
	return run_checks([
		assert_true(int(mcts.get("branch_factor", 0)) >= 2, "branch_factor 应 >= 2"),
		assert_true(int(mcts.get("branch_factor", 999)) <= 5, "branch_factor 应 <= 5"),
		assert_true(int(mcts.get("rollouts_per_sequence", 0)) >= 5, "rollouts 应 >= 5"),
		assert_true(int(mcts.get("rollouts_per_sequence", 999)) <= 50, "rollouts 应 <= 50"),
		assert_true(int(mcts.get("rollout_max_steps", 0)) >= 30, "rollout_steps 应 >= 30"),
		assert_true(int(mcts.get("rollout_max_steps", 999)) <= 200, "rollout_steps 应 <= 200"),
		assert_true(int(mcts.get("time_budget_ms", 0)) >= 1000, "time_budget 应 >= 1000"),
		assert_true(int(mcts.get("time_budget_ms", 99999)) <= 10000, "time_budget 应 <= 10000"),
	])


func test_adjust_sigma_increases_on_consecutive_rejects() -> String:
	var engine := EvolutionEngineScript.new()
	engine.sigma_weights = 0.15
	engine.sigma_mcts = 0.10
	engine.adjust_sigma("reject")
	engine.adjust_sigma("reject")
	engine.adjust_sigma("reject")
	return run_checks([
		assert_true(engine.sigma_weights > 0.15, "连续拒绝后 sigma_weights 应增大"),
		assert_true(engine.sigma_mcts > 0.10, "连续拒绝后 sigma_mcts 应增大"),
	])


func test_adjust_sigma_decreases_on_consecutive_accepts() -> String:
	var engine := EvolutionEngineScript.new()
	engine.sigma_weights = 0.15
	engine.sigma_mcts = 0.10
	engine.adjust_sigma("accept")
	engine.adjust_sigma("accept")
	engine.adjust_sigma("accept")
	return run_checks([
		assert_true(engine.sigma_weights < 0.15, "连续接受后 sigma_weights 应缩小"),
		assert_true(engine.sigma_mcts < 0.10, "连续接受后 sigma_mcts 应缩小"),
	])


func test_sigma_clamp_bounds() -> String:
	var engine := EvolutionEngineScript.new()
	engine.sigma_weights = 0.05
	engine.sigma_mcts = 0.05
	## 连续接受应不会低于下界
	for _i in 20:
		engine.adjust_sigma("accept")
	var below_min_w: bool = engine.sigma_weights < 0.05
	engine.sigma_weights = 0.40
	engine.sigma_mcts = 0.40
	## 连续拒绝应不会高于上界
	for _i in 20:
		engine.adjust_sigma("reject")
	var above_max_w: bool = engine.sigma_weights > 0.40
	return run_checks([
		assert_false(below_min_w, "sigma_weights 不应低于 0.05"),
		assert_false(above_max_w, "sigma_weights 不应高于 0.40"),
	])


func test_get_default_config_returns_valid_structure() -> String:
	var config: Dictionary = EvolutionEngineScript.get_default_config()
	return run_checks([
		assert_true(config.has("heuristic_weights"), "默认 config 应包含 heuristic_weights"),
		assert_true(config.has("mcts_config"), "默认 config 应包含 mcts_config"),
		assert_true(not config.get("heuristic_weights", {}).is_empty(), "权重不应为空"),
		assert_true(config.get("mcts_config", {}).has("branch_factor"), "MCTS config 应包含 branch_factor"),
	])
