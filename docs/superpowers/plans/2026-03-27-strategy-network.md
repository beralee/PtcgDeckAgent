# Phase 5.2 Strategy Network Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a neural network value function to replace MCTS rollouts, trained from self-play data via an offline Python pipeline.

**Architecture:** GDScript StateEncoder converts GameState to 30-dim float vector. NeuralNetInference runs a 30->64->32->1 MLP in pure GDScript. SelfPlayDataExporter records per-turn features during self-play, exports JSON. Python train_value_net.py trains PyTorch model and exports weights as JSON. MCTSPlanner uses value net instead of rollouts when available.

**Tech Stack:** Godot 4.6 / GDScript, Python 3 / PyTorch

**Spec:** `docs/superpowers/specs/2026-03-27-strategy-network-design.md`

**Test command:** `"D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path . res://tests/TestRunner.tscn --quit-after 90`

---

## File Structure

### New Files

| File | Responsibility |
|------|---------------|
| `scripts/ai/StateEncoder.gd` | GameState -> 30-dim float vector |
| `scripts/ai/NeuralNetInference.gd` | Pure GDScript MLP forward pass |
| `scripts/ai/SelfPlayDataExporter.gd` | Collect per-turn features, export JSON |
| `scripts/training/train_value_net.py` | PyTorch training script |
| `scripts/training/requirements.txt` | Python dependencies |
| `tests/test_state_encoder.gd` | StateEncoder unit tests |
| `tests/test_neural_net_inference.gd` | NeuralNetInference unit tests |
| `tests/test_self_play_data_exporter.gd` | SelfPlayDataExporter unit tests |

### Modified Files

| File | Change |
|------|--------|
| `scripts/ai/MCTSPlanner.gd` | Add value_net + state_encoder fields, use in _evaluate_sequence |
| `scripts/ai/SelfPlayRunner.gd` | Add export_training_data flag, integrate SelfPlayDataExporter |
| `scripts/ai/EvolutionEngine.gd` | Pass value_net_path through config |
| `scenes/tuner/TunerRunner.gd` | Add --value-net and --export-data CLI args |
| `tests/TestRunner.gd` | Register 3 new test suites |

---

### Task 1: StateEncoder

**Files:**
- Create: `scripts/ai/StateEncoder.gd`
- Create: `tests/test_state_encoder.gd`

- [ ] **Step 1: Write the test file**

```gdscript
## tests/test_state_encoder.gd
class_name TestStateEncoder
extends TestBase

const StateEncoderScript = preload("res://scripts/ai/StateEncoder.gd")


func _make_game_state() -> GameState:
	var gs := GameState.new()
	gs.turn_number = 3
	gs.first_player_index = 0
	gs.current_player_index = 0
	gs.energy_attached_this_turn = false
	gs.supporter_used_this_turn = false

	for i in 2:
		var ps := PlayerState.new()
		ps.player_index = i

		## 前场宝可梦
		var active_cd := CardData.new()
		active_cd.name = "Pikachu ex" if i == 0 else "Gardevoir ex"
		active_cd.card_type = "Pokemon"
		active_cd.stage = "Basic" if i == 0 else "Stage 2"
		active_cd.hp = 200 if i == 0 else 310
		active_cd.mechanic = "ex"
		active_cd.energy_type = "L" if i == 0 else "P"
		active_cd.attacks = [{"name": "攻击", "cost": "LC", "damage": "90", "text": ""}]
		var active_card := CardInstance.create(active_cd, i)
		var active_slot := PokemonSlot.new()
		active_slot.pokemon_stack = [active_card]
		active_slot.damage_counters = 30 if i == 0 else 0
		## 贴 2 张能量
		for _e in 2:
			var energy_cd := CardData.new()
			energy_cd.card_type = "Basic Energy"
			energy_cd.energy_type = "L" if i == 0 else "P"
			active_slot.attached_energy.append(CardInstance.create(energy_cd, i))
		ps.active_pokemon = active_slot

		## 后备 1 只
		var bench_cd := CardData.new()
		bench_cd.name = "后备宝可梦"
		bench_cd.card_type = "Pokemon"
		bench_cd.stage = "Basic"
		bench_cd.hp = 60
		bench_cd.energy_type = "C"
		bench_cd.attacks = []
		var bench_card := CardInstance.create(bench_cd, i)
		var bench_slot := PokemonSlot.new()
		bench_slot.pokemon_stack = [bench_card]
		ps.bench = [bench_slot]

		## 手牌 5 张、牌库 30 张、奖赏 5 张
		for _h in 5:
			ps.hand.append(CardInstance.create(CardData.new(), i))
		for _d in 30:
			ps.deck.append(CardInstance.create(CardData.new(), i))
		for _p in 5:
			ps.prizes.append(CardInstance.create(CardData.new(), i))

		gs.players.append(ps)

	return gs


func test_encode_returns_30_floats() -> String:
	var gs := _make_game_state()
	var features: Array[float] = StateEncoderScript.encode(gs, 0)
	return run_checks([
		assert_eq(features.size(), 30, "特征向量维度应为 30"),
	])


func test_encode_values_in_expected_range() -> String:
	var gs := _make_game_state()
	var f: Array[float] = StateEncoderScript.encode(gs, 0)
	## active_hp_ratio: (200 - 30) / 200 = 0.85
	## active_damage_ratio: 30 / 200 = 0.15
	## active_energy_count: 2 / 5.0 = 0.4
	## active_can_attack: 需要 LC，有 2L，无 C -> 取决于 rule_validator，这里无 gsm 所以 0.0
	## active_is_ex: 1.0
	## active_stage: 0.0 (Basic)
	## bench_count: 1 / 5.0 = 0.2
	## bench_total_hp: 60 / 500.0 = 0.12
	## bench_total_energy: 0 / 10.0 = 0.0
	## hand_size: 5 / 20.0 = 0.25
	## deck_size: 30 / 40.0 = 0.75
	## prizes_remaining: 5 / 6.0 = 0.833...
	## supporter_available: 1.0
	## energy_available: 1.0
	return run_checks([
		assert_true(absf(f[0] - 0.85) < 0.01, "active_hp_ratio 应为 0.85，实际 %.4f" % f[0]),
		assert_true(absf(f[1] - 0.15) < 0.01, "active_damage_ratio 应为 0.15，实际 %.4f" % f[1]),
		assert_true(absf(f[2] - 0.4) < 0.01, "active_energy_count 应为 0.4，实际 %.4f" % f[2]),
		assert_true(f[4] == 1.0, "active_is_ex 应为 1.0"),
		assert_true(f[5] == 0.0, "active_stage 应为 0.0 (Basic)"),
		assert_true(absf(f[6] - 0.2) < 0.01, "bench_count 应为 0.2"),
		assert_true(absf(f[9] - 0.25) < 0.01, "hand_size 应为 0.25"),
		assert_true(absf(f[10] - 0.75) < 0.01, "deck_size 应为 0.75"),
		assert_true(f[12] == 1.0, "supporter_available 应为 1.0"),
		assert_true(f[13] == 1.0, "energy_available 应为 1.0"),
	])


func test_encode_symmetry() -> String:
	## 交换视角时，自己的特征和对手的特征应互换
	var gs := _make_game_state()
	var f0: Array[float] = StateEncoderScript.encode(gs, 0)
	var f1: Array[float] = StateEncoderScript.encode(gs, 1)
	## 玩家 0 的前 14 维 = 玩家 1 视角的 14-27 维
	var symmetric: bool = true
	for i in 14:
		if absf(f0[i] - f1[14 + i]) > 0.001:
			symmetric = false
			break
	return run_checks([
		assert_true(symmetric, "交换视角后自己的特征应等于对手的特征"),
	])


func test_encode_turn_and_first_player() -> String:
	var gs := _make_game_state()
	gs.turn_number = 15
	gs.first_player_index = 0
	var f0: Array[float] = StateEncoderScript.encode(gs, 0)
	var f1: Array[float] = StateEncoderScript.encode(gs, 1)
	## turn_number / 30 = 0.5
	## is_first_player: p0=1.0, p1=0.0
	return run_checks([
		assert_true(absf(f0[28] - 0.5) < 0.01, "回合数归一化应为 0.5"),
		assert_true(f0[29] == 1.0, "玩家 0 是先手"),
		assert_true(f1[29] == 0.0, "玩家 1 不是先手"),
	])


func test_encode_empty_bench() -> String:
	var gs := _make_game_state()
	gs.players[0].bench.clear()
	var f: Array[float] = StateEncoderScript.encode(gs, 0)
	return run_checks([
		assert_true(f[6] == 0.0, "空后备 bench_count 应为 0"),
		assert_true(f[7] == 0.0, "空后备 bench_total_hp 应为 0"),
		assert_true(f[8] == 0.0, "空后备 bench_total_energy 应为 0"),
	])


func test_encode_no_active_pokemon() -> String:
	var gs := _make_game_state()
	gs.players[0].active_pokemon = null
	var f: Array[float] = StateEncoderScript.encode(gs, 0)
	return run_checks([
		assert_true(f[0] == 0.0, "无前场 active_hp_ratio 应为 0"),
		assert_true(f[1] == 0.0, "无前场 active_damage_ratio 应为 0"),
		assert_true(f[2] == 0.0, "无前场 active_energy_count 应为 0"),
	])
```

- [ ] **Step 2: Run test to verify it fails**

Run: `"D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path . res://tests/TestRunner.tscn --quit-after 90 2>&1 | grep -E "StateEncoder|FAIL|Total"`

Expected: Compilation error — StateEncoder not found.

- [ ] **Step 3: Write StateEncoder implementation**

```gdscript
## scripts/ai/StateEncoder.gd
class_name StateEncoder
extends RefCounted

## 局面编码为固定长度特征向量。
## 对称编码：以 perspective_player 为视角。

const FEATURE_DIM: int = 30


static func encode(game_state: GameState, perspective_player: int) -> Array[float]:
	var features: Array[float] = []
	features.resize(FEATURE_DIM)
	features.fill(0.0)

	if game_state == null or perspective_player < 0 or perspective_player >= game_state.players.size():
		return features

	var my_player: PlayerState = game_state.players[perspective_player]
	var opp_player: PlayerState = game_state.players[1 - perspective_player]

	## 索引 0-13: 自己的特征
	var my_is_current: bool = game_state.current_player_index == perspective_player
	_encode_player(my_player, features, 0, my_is_current, game_state)
	## 索引 14-27: 对手的特征
	_encode_player(opp_player, features, 14, not my_is_current, game_state)
	## 索引 28: 回合数归一化
	features[28] = clampf(float(game_state.turn_number) / 30.0, 0.0, 1.0)
	## 索引 29: 是否先手
	features[29] = 1.0 if game_state.first_player_index == perspective_player else 0.0

	return features


static func _encode_player(player: PlayerState, features: Array[float], offset: int, is_current_player: bool, game_state: GameState) -> void:
	if player == null:
		return

	## 前场宝可梦
	var slot: PokemonSlot = player.active_pokemon
	if slot != null:
		var cd: CardData = slot.get_card_data()
		if cd != null and cd.hp > 0:
			var remaining_hp: float = float(cd.hp - slot.damage_counters)
			features[offset + 0] = clampf(remaining_hp / float(cd.hp), 0.0, 1.0)
			features[offset + 1] = clampf(float(slot.damage_counters) / float(cd.hp), 0.0, 1.0)
		features[offset + 2] = float(slot.attached_energy.size()) / 5.0
		## active_can_attack: 简化判定——有能量且有招式即视为可攻击
		if slot.get_card_data() != null and not slot.get_card_data().attacks.is_empty() and slot.attached_energy.size() > 0:
			features[offset + 3] = 1.0
		features[offset + 4] = 1.0 if _is_ex(slot) else 0.0
		features[offset + 5] = _stage_to_float(slot)

	## 后备区
	features[offset + 6] = float(player.bench.size()) / 5.0
	var bench_hp: float = 0.0
	var bench_energy: float = 0.0
	for bench_slot: PokemonSlot in player.bench:
		if bench_slot == null:
			continue
		var bcd: CardData = bench_slot.get_card_data()
		if bcd != null:
			bench_hp += float(bcd.hp - bench_slot.damage_counters)
		bench_energy += float(bench_slot.attached_energy.size())
	features[offset + 7] = bench_hp / 500.0
	features[offset + 8] = bench_energy / 10.0

	## 手牌、牌库、奖赏
	features[offset + 9] = float(player.hand.size()) / 20.0
	features[offset + 10] = float(player.deck.size()) / 40.0
	features[offset + 11] = float(player.prizes.size()) / 6.0

	## supporter / energy 可用性：只有当前回合玩家的标志有意义
	if is_current_player:
		features[offset + 12] = 0.0 if game_state.supporter_used_this_turn else 1.0
		features[offset + 13] = 0.0 if game_state.energy_attached_this_turn else 1.0
	else:
		features[offset + 12] = 1.0
		features[offset + 13] = 1.0


static func _is_ex(slot: PokemonSlot) -> bool:
	if slot == null:
		return false
	var cd: CardData = slot.get_card_data()
	if cd == null:
		return false
	return cd.mechanic == "ex" or cd.mechanic == "V" or cd.mechanic == "VSTAR" or cd.mechanic == "VMAX"


static func _stage_to_float(slot: PokemonSlot) -> float:
	if slot == null:
		return 0.0
	var cd: CardData = slot.get_card_data()
	if cd == null:
		return 0.0
	match cd.stage:
		"Basic":
			return 0.0
		"Stage 1":
			return 0.5
		"Stage 2":
			return 1.0
		_:
			return 0.0
```

- [ ] **Step 4: Register test in TestRunner.gd**

Add to `tests/TestRunner.gd`:
- Const: `const TestStateEncoder = preload("res://tests/test_state_encoder.gd")`
- Call: `_run_test_suite("StateEncoder", TestStateEncoder.new())` (before CardCatalogAudit)

- [ ] **Step 5: Run tests and verify all pass**

Run: `"D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path . res://tests/TestRunner.tscn --quit-after 90 2>&1 | grep -E "StateEncoder|FAIL|Total"`

Expected: All StateEncoder tests PASS, total failures unchanged (only CardCatalogAudit).

- [ ] **Step 6: Commit**

```bash
git add scripts/ai/StateEncoder.gd tests/test_state_encoder.gd tests/TestRunner.gd
git commit -m "feat: add StateEncoder for game state to feature vector encoding"
```

---

### Task 2: NeuralNetInference

**Files:**
- Create: `scripts/ai/NeuralNetInference.gd`
- Create: `tests/test_neural_net_inference.gd`

- [ ] **Step 1: Write the test file**

```gdscript
## tests/test_neural_net_inference.gd
class_name TestNeuralNetInference
extends TestBase

const NeuralNetInferenceScript = preload("res://scripts/ai/NeuralNetInference.gd")


func _make_simple_weights() -> Dictionary:
	## 单层网络: 2 输入 -> 1 输出 (sigmoid), weights=[[1,1]], bias=[0]
	## predict([1,1]) = sigmoid(1*1 + 1*1 + 0) = sigmoid(2) = 0.8808
	return {
		"architecture": "mlp",
		"input_dim": 2,
		"layers": [
			{
				"out_features": 1,
				"activation": "sigmoid",
				"weights": [[1.0, 1.0]],
				"bias": [0.0],
			}
		]
	}


func _make_two_layer_weights() -> Dictionary:
	## 2 输入 -> 2 hidden (relu) -> 1 output (sigmoid)
	## Hidden: weights=[[1,0],[0,1]], bias=[0,0] => identity through relu
	## Output: weights=[[0.5, 0.5]], bias=[0] => sigmoid(0.5*x0 + 0.5*x1)
	return {
		"architecture": "mlp",
		"input_dim": 2,
		"layers": [
			{
				"out_features": 2,
				"activation": "relu",
				"weights": [[1.0, 0.0], [0.0, 1.0]],
				"bias": [0.0, 0.0],
			},
			{
				"out_features": 1,
				"activation": "sigmoid",
				"weights": [[0.5, 0.5]],
				"bias": [0.0],
			}
		]
	}


func _make_full_size_weights() -> Dictionary:
	## 30 -> 64 -> 32 -> 1 全零权重（用于测试形状兼容性）
	var layer1_w: Array = []
	for _i in 64:
		var row: Array = []
		row.resize(30)
		row.fill(0.0)
		layer1_w.append(row)
	var layer1_b: Array = []
	layer1_b.resize(64)
	layer1_b.fill(0.0)

	var layer2_w: Array = []
	for _i in 32:
		var row: Array = []
		row.resize(64)
		row.fill(0.0)
		layer2_w.append(row)
	var layer2_b: Array = []
	layer2_b.resize(32)
	layer2_b.fill(0.0)

	var layer3_w: Array = [[]]; layer3_w[0] = []
	layer3_w[0].resize(32)
	layer3_w[0].fill(0.0)
	var layer3_b: Array = [0.0]

	return {
		"architecture": "mlp",
		"input_dim": 30,
		"layers": [
			{"out_features": 64, "activation": "relu", "weights": layer1_w, "bias": layer1_b},
			{"out_features": 32, "activation": "relu", "weights": layer2_w, "bias": layer2_b},
			{"out_features": 1, "activation": "sigmoid", "weights": layer3_w, "bias": layer3_b},
		]
	}


func test_load_weights_from_dict() -> String:
	var net := NeuralNetInferenceScript.new()
	var ok: bool = net.load_weights_from_dict(_make_simple_weights())
	return run_checks([
		assert_true(ok, "加载简单权重应成功"),
		assert_true(net.is_loaded(), "加载后 is_loaded 应为 true"),
	])


func test_predict_simple_sigmoid() -> String:
	var net := NeuralNetInferenceScript.new()
	net.load_weights_from_dict(_make_simple_weights())
	var result: float = net.predict([1.0, 1.0])
	## sigmoid(2) = 1 / (1 + exp(-2)) ~= 0.8808
	return run_checks([
		assert_true(absf(result - 0.8808) < 0.01, "sigmoid(2) 应约为 0.8808，实际 %.4f" % result),
	])


func test_predict_two_layer() -> String:
	var net := NeuralNetInferenceScript.new()
	net.load_weights_from_dict(_make_two_layer_weights())
	var result: float = net.predict([2.0, 3.0])
	## Hidden: relu([2, 3]) = [2, 3]
	## Output: sigmoid(0.5*2 + 0.5*3) = sigmoid(2.5) ~= 0.924
	return run_checks([
		assert_true(absf(result - 0.924) < 0.01, "两层网络输出应约为 0.924，实际 %.4f" % result),
	])


func test_predict_relu_clips_negative() -> String:
	var net := NeuralNetInferenceScript.new()
	net.load_weights_from_dict(_make_two_layer_weights())
	var result: float = net.predict([-5.0, -3.0])
	## Hidden: relu([-5, -3]) = [0, 0]
	## Output: sigmoid(0) = 0.5
	return run_checks([
		assert_true(absf(result - 0.5) < 0.01, "负输入经 relu 后应得 sigmoid(0)=0.5，实际 %.4f" % result),
	])


func test_predict_full_size_zero_weights() -> String:
	var net := NeuralNetInferenceScript.new()
	net.load_weights_from_dict(_make_full_size_weights())
	var input: Array[float] = []
	input.resize(30)
	input.fill(1.0)
	var result: float = net.predict(input)
	## 全零权重 + 全零偏置 -> 每层输出全 0 -> sigmoid(0) = 0.5
	return run_checks([
		assert_true(absf(result - 0.5) < 0.01, "全零权重应输出 0.5，实际 %.4f" % result),
	])


func test_predict_not_loaded_returns_fallback() -> String:
	var net := NeuralNetInferenceScript.new()
	var result: float = net.predict([1.0, 2.0])
	return run_checks([
		assert_true(absf(result - 0.5) < 0.01, "未加载时应返回 0.5，实际 %.4f" % result),
	])


func test_load_and_save_json_roundtrip() -> String:
	var net := NeuralNetInferenceScript.new()
	net.load_weights_from_dict(_make_two_layer_weights())
	var path := "user://test_nn_weights_roundtrip.json"
	var save_ok: bool = net.save_weights(path)
	var net2 := NeuralNetInferenceScript.new()
	var load_ok: bool = net2.load_weights(path)
	var result1: float = net.predict([2.0, 3.0])
	var result2: float = net2.predict([2.0, 3.0])
	## 清理
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return run_checks([
		assert_true(save_ok, "保存权重应成功"),
		assert_true(load_ok, "加载权重应成功"),
		assert_true(absf(result1 - result2) < 0.001, "往返后推理结果应一致"),
	])
```

- [ ] **Step 2: Run test to verify it fails**

Expected: Compilation error — NeuralNetInference not found.

- [ ] **Step 3: Write NeuralNetInference implementation**

```gdscript
## scripts/ai/NeuralNetInference.gd
class_name NeuralNetInference
extends RefCounted

## 纯 GDScript 前馈网络推理。
## 加载 JSON 权重，执行矩阵-向量乘法。
## 网络结构: Input -> [Linear + Activation] * N -> Output

var _layers: Array[Dictionary] = []
var _loaded: bool = false


func is_loaded() -> bool:
	return _loaded


func load_weights(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("[NeuralNetInference] 无法打开权重文件: %s" % path)
		return false
	var text: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_warning("[NeuralNetInference] JSON 解析失败: %s" % json.get_error_message())
		return false
	var data: Variant = json.data
	if not data is Dictionary:
		return false
	return load_weights_from_dict(data as Dictionary)


func load_weights_from_dict(data: Dictionary) -> bool:
	_layers.clear()
	_loaded = false
	var layers_data: Variant = data.get("layers", [])
	if not layers_data is Array:
		return false
	for layer_data: Variant in layers_data:
		if not layer_data is Dictionary:
			return false
		var ld: Dictionary = layer_data as Dictionary
		var weights: Variant = ld.get("weights", [])
		var bias: Variant = ld.get("bias", [])
		var activation: String = str(ld.get("activation", "relu"))
		if not weights is Array or not bias is Array:
			return false
		_layers.append({
			"weights": weights,
			"bias": bias,
			"activation": activation,
		})
	_loaded = not _layers.is_empty()
	return _loaded


func save_weights(path: String) -> bool:
	var layers_out: Array = []
	for layer: Dictionary in _layers:
		layers_out.append({
			"out_features": (layer.get("bias", []) as Array).size(),
			"activation": layer.get("activation", "relu"),
			"weights": layer.get("weights", []),
			"bias": layer.get("bias", []),
		})
	var data := {
		"architecture": "mlp",
		"input_dim": 0,
		"layers": layers_out,
	}
	if not _layers.is_empty():
		var first_weights: Array = _layers[0].get("weights", [])
		if not first_weights.is_empty() and first_weights[0] is Array:
			data["input_dim"] = (first_weights[0] as Array).size()
	var text: String = JSON.stringify(data, "  ")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	return true


func predict(features: Variant) -> float:
	if not _loaded:
		return 0.5
	var input: Array = []
	if features is Array:
		for f: Variant in features:
			input.append(float(f))
	else:
		return 0.5

	for layer: Dictionary in _layers:
		var weights: Array = layer.get("weights", [])
		var bias: Array = layer.get("bias", [])
		var activation: String = str(layer.get("activation", "relu"))
		var output: Array = []
		for j in weights.size():
			var row: Array = weights[j]
			var sum: float = float(bias[j]) if j < bias.size() else 0.0
			for i in row.size():
				if i < input.size():
					sum += float(row[i]) * float(input[i])
			output.append(sum)
		## 激活函数
		if activation == "relu":
			for k in output.size():
				if output[k] < 0.0:
					output[k] = 0.0
		elif activation == "sigmoid":
			for k in output.size():
				output[k] = _sigmoid(float(output[k]))
		input = output

	return float(input[0]) if not input.is_empty() else 0.5


static func _sigmoid(x: float) -> float:
	if x > 20.0:
		return 1.0
	if x < -20.0:
		return 0.0
	return 1.0 / (1.0 + exp(-x))
```

- [ ] **Step 4: Register test in TestRunner.gd**

Add to `tests/TestRunner.gd`:
- Const: `const TestNeuralNetInference = preload("res://tests/test_neural_net_inference.gd")`
- Call: `_run_test_suite("NeuralNetInference", TestNeuralNetInference.new())` (before CardCatalogAudit)

- [ ] **Step 5: Run tests and verify all pass**

Run: `"D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path . res://tests/TestRunner.tscn --quit-after 90 2>&1 | grep -E "NeuralNet|FAIL|Total"`

Expected: All NeuralNetInference tests PASS.

- [ ] **Step 6: Commit**

```bash
git add scripts/ai/NeuralNetInference.gd tests/test_neural_net_inference.gd tests/TestRunner.gd
git commit -m "feat: add NeuralNetInference for pure GDScript MLP forward pass"
```

---

### Task 3: SelfPlayDataExporter

**Files:**
- Create: `scripts/ai/SelfPlayDataExporter.gd`
- Create: `tests/test_self_play_data_exporter.gd`

- [ ] **Step 1: Write the test file**

```gdscript
## tests/test_self_play_data_exporter.gd
class_name TestSelfPlayDataExporter
extends TestBase

const SelfPlayDataExporterScript = preload("res://scripts/ai/SelfPlayDataExporter.gd")
const StateEncoderScript = preload("res://scripts/ai/StateEncoder.gd")


func _make_minimal_game_state() -> GameState:
	var gs := GameState.new()
	gs.turn_number = 1
	gs.first_player_index = 0
	gs.current_player_index = 0
	for i in 2:
		var ps := PlayerState.new()
		ps.player_index = i
		var cd := CardData.new()
		cd.name = "测试宝可梦"
		cd.card_type = "Pokemon"
		cd.stage = "Basic"
		cd.hp = 100
		cd.energy_type = "C"
		cd.attacks = []
		var card := CardInstance.create(cd, i)
		var slot := PokemonSlot.new()
		slot.pokemon_stack = [card]
		ps.active_pokemon = slot
		for _p in 6:
			ps.prizes.append(CardInstance.create(CardData.new(), i))
		gs.players.append(ps)
	return gs


func test_record_and_export_produces_valid_json() -> String:
	var exporter := SelfPlayDataExporterScript.new()
	exporter.base_dir = "user://test_training_data"
	var gs := _make_minimal_game_state()

	exporter.start_game()
	exporter.record_state(gs, 0)
	exporter.record_state(gs, 1)
	exporter.end_game(0)

	var path: String = exporter.export_game()
	var file := FileAccess.open(path, FileAccess.READ)
	var text: String = file.get_as_text() if file != null else ""
	file.close() if file != null else null

	var json := JSON.new()
	var parse_ok: bool = json.parse(text) == OK
	var data: Dictionary = json.data if json.data is Dictionary else {}

	## 清理
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	return run_checks([
		assert_true(path != "", "导出路径应非空"),
		assert_true(parse_ok, "导出文件应是有效 JSON"),
		assert_eq(data.get("version", ""), "1.0", "版本应为 1.0"),
		assert_eq(int(data.get("winner_index", -1)), 0, "胜者应为 0"),
		assert_eq((data.get("records", []) as Array).size(), 2, "应有 2 条记录"),
	])


func test_records_have_correct_features_length() -> String:
	var exporter := SelfPlayDataExporterScript.new()
	exporter.base_dir = "user://test_training_data"
	var gs := _make_minimal_game_state()

	exporter.start_game()
	exporter.record_state(gs, 0)
	exporter.end_game(0)

	var path: String = exporter.export_game()
	var file := FileAccess.open(path, FileAccess.READ)
	var text: String = file.get_as_text() if file != null else ""
	file.close() if file != null else null

	var json := JSON.new()
	json.parse(text)
	var data: Dictionary = json.data if json.data is Dictionary else {}
	var records: Array = data.get("records", [])
	var first_record: Dictionary = records[0] if not records.is_empty() else {}
	var features: Array = first_record.get("features", [])

	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	return run_checks([
		assert_eq(features.size(), StateEncoderScript.FEATURE_DIM, "特征向量维度应为 %d" % StateEncoderScript.FEATURE_DIM),
	])


func test_result_backfill() -> String:
	var exporter := SelfPlayDataExporterScript.new()
	exporter.base_dir = "user://test_training_data"
	var gs := _make_minimal_game_state()

	exporter.start_game()
	exporter.record_state(gs, 0)
	exporter.record_state(gs, 1)
	exporter.end_game(0)

	var path: String = exporter.export_game()
	var file := FileAccess.open(path, FileAccess.READ)
	var text: String = file.get_as_text() if file != null else ""
	file.close() if file != null else null

	var json := JSON.new()
	json.parse(text)
	var data: Dictionary = json.data if json.data is Dictionary else {}
	var records: Array = data.get("records", [])

	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	var r0: Dictionary = records[0] if records.size() > 0 else {}
	var r1: Dictionary = records[1] if records.size() > 1 else {}
	return run_checks([
		assert_true(absf(float(r0.get("result", -1.0)) - 1.0) < 0.01, "玩家 0 赢了，result 应为 1.0"),
		assert_true(absf(float(r1.get("result", -1.0)) - 0.0) < 0.01, "玩家 1 输了，result 应为 0.0"),
	])
```

- [ ] **Step 2: Run test to verify it fails**

Expected: Compilation error — SelfPlayDataExporter not found.

- [ ] **Step 3: Write SelfPlayDataExporter implementation**

```gdscript
## scripts/ai/SelfPlayDataExporter.gd
class_name SelfPlayDataExporter
extends RefCounted

## 自博弈数据收集器。
## 每回合记录局面特征，对局结束后用胜负结果回填，导出 JSON。

const StateEncoderScript = preload("res://scripts/ai/StateEncoder.gd")

var base_dir: String = "user://training_data"

var _records: Array[Dictionary] = []
var _winner_index: int = -1
var _total_turns: int = 0


func start_game() -> void:
	_records.clear()
	_winner_index = -1
	_total_turns = 0


func record_state(game_state: GameState, current_player: int) -> void:
	var features: Array[float] = StateEncoderScript.encode(game_state, current_player)
	_records.append({
		"turn": game_state.turn_number if game_state != null else 0,
		"player": current_player,
		"features": features,
		"result": 0.5,
	})
	if game_state != null and game_state.turn_number > _total_turns:
		_total_turns = game_state.turn_number


func end_game(winner_index: int) -> void:
	_winner_index = winner_index
	## 回填结果
	for record: Dictionary in _records:
		var player: int = int(record.get("player", -1))
		if player == winner_index:
			record["result"] = 1.0
		elif winner_index >= 0:
			record["result"] = 0.0
		else:
			record["result"] = 0.5


func export_game() -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base_dir))

	var timestamp: int = Time.get_unix_time_from_system() as int
	var seed_val: int = randi()
	var filename := "game_%d_%d.json" % [timestamp, seed_val]
	var path := base_dir.path_join(filename)

	## 将 features 数组转为普通 Array 以便 JSON 序列化
	var serializable_records: Array = []
	for record: Dictionary in _records:
		var r := record.duplicate()
		var feats: Variant = r.get("features", [])
		if feats is Array:
			var plain: Array = []
			for f: Variant in feats:
				plain.append(float(f))
			r["features"] = plain
		serializable_records.append(r)

	var data := {
		"version": "1.0",
		"winner_index": _winner_index,
		"total_turns": _total_turns,
		"records": serializable_records,
	}

	var text: String = JSON.stringify(data)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("[SelfPlayDataExporter] 无法写入: %s" % path)
		return ""
	file.store_string(text)
	file.close()
	return path
```

- [ ] **Step 4: Register test in TestRunner.gd**

Add to `tests/TestRunner.gd`:
- Const: `const TestSelfPlayDataExporter = preload("res://tests/test_self_play_data_exporter.gd")`
- Call: `_run_test_suite("SelfPlayDataExporter", TestSelfPlayDataExporter.new())` (before CardCatalogAudit)

- [ ] **Step 5: Run tests and verify all pass**

Run: `"D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path . res://tests/TestRunner.tscn --quit-after 90 2>&1 | grep -E "DataExporter|FAIL|Total"`

Expected: All SelfPlayDataExporter tests PASS.

- [ ] **Step 6: Commit**

```bash
git add scripts/ai/SelfPlayDataExporter.gd tests/test_self_play_data_exporter.gd tests/TestRunner.gd
git commit -m "feat: add SelfPlayDataExporter for training data collection"
```

---

### Task 4: SelfPlayRunner Integration

**Files:**
- Modify: `scripts/ai/SelfPlayRunner.gd`

- [ ] **Step 1: Add export_training_data flag and SelfPlayDataExporter integration**

Add to `SelfPlayRunner.gd`:

```gdscript
## 在文件顶部 const 区添加
const SelfPlayDataExporterScript = preload("res://scripts/ai/SelfPlayDataExporter.gd")
```

Add `export_training_data` parameter to `run_batch`:

```gdscript
func run_batch(
	agent_a_config: Dictionary,
	agent_b_config: Dictionary,
	deck_pairings: Array,
	seeds: Array,
	max_steps_per_match: int = 200,
	export_training_data: bool = false,
) -> Dictionary:
```

In `_run_one_match`, add exporter parameter and record states:

```gdscript
func _run_one_match(
	runner: AIBenchmarkRunner,
	p0_config: Dictionary,
	p1_config: Dictionary,
	deck_a: DeckData,
	deck_b: DeckData,
	seed_value: int,
	max_steps: int,
	exporter: SelfPlayDataExporter = null,
) -> Dictionary:
	var p0_ai := _make_agent(0, p0_config)
	var p1_ai := _make_agent(1, p1_config)

	var gsm := GameStateMachine.new()
	_apply_seed(gsm, seed_value)
	_set_forced_shuffle_seed(seed_value)
	gsm.start_game(deck_a, deck_b, 0)

	if exporter != null:
		exporter.start_game()
		## 记录初始状态
		exporter.record_state(gsm.game_state, 0)
		exporter.record_state(gsm.game_state, 1)

	var result: Dictionary = runner.run_headless_duel(p0_ai, p1_ai, gsm, max_steps)

	if exporter != null:
		exporter.end_game(int(result.get("winner_index", -1)))
		exporter.export_game()

	_clear_forced_shuffle_seed()
	return result
```

In `run_batch`, create exporter and pass to each match:

```gdscript
	for pairing: Variant in deck_pairings:
		# ... existing pairing logic ...
		for seed_value: Variant in seeds:
			var sv: int = int(seed_value)
			var exporter_a0: SelfPlayDataExporter = null
			if export_training_data:
				exporter_a0 = SelfPlayDataExporterScript.new()
			var result_a0 := _run_one_match(
				runner, agent_a_config, agent_b_config,
				deck_a, deck_b, sv, max_steps_per_match, exporter_a0
			)
			# ... rest of logic for a0 ...

			var exporter_a1: SelfPlayDataExporter = null
			if export_training_data:
				exporter_a1 = SelfPlayDataExporterScript.new()
			var result_a1 := _run_one_match(
				runner, agent_b_config, agent_a_config,
				deck_a, deck_b, sv + 10000, max_steps_per_match, exporter_a1
			)
			# ... rest of logic for a1 ...
```

- [ ] **Step 2: Run existing SelfPlayRunner tests to verify no regression**

Run: `"D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path . res://tests/TestRunner.tscn --quit-after 90 2>&1 | grep -E "SelfPlay|FAIL|Total"`

Expected: All existing tests PASS (new parameter has default `false`).

- [ ] **Step 3: Commit**

```bash
git add scripts/ai/SelfPlayRunner.gd
git commit -m "feat: integrate SelfPlayDataExporter into SelfPlayRunner"
```

---

### Task 5: Python Training Script

**Files:**
- Create: `scripts/training/train_value_net.py`
- Create: `scripts/training/requirements.txt`

- [ ] **Step 1: Create requirements.txt**

```
torch>=2.0
numpy
```

- [ ] **Step 2: Create train_value_net.py**

```python
#!/usr/bin/env python3
"""
PTCG Train 价值网络训练脚本。
加载 Godot 导出的 JSON 自博弈数据，训练 MLP 价值网络，导出权重为 GDScript 可读的 JSON。

用法:
    python scripts/training/train_value_net.py \
        --data-dir "path/to/training_data" \
        --output "value_net_weights.json" \
        --epochs 100 --batch-size 256 --lr 0.001 \
        --hidden1 64 --hidden2 32
"""

import argparse
import glob
import json
import os
import sys

import numpy as np
import torch
import torch.nn as nn
from torch.utils.data import DataLoader, TensorDataset


class ValueNet(nn.Module):
    def __init__(self, input_dim: int = 30, hidden1: int = 64, hidden2: int = 32):
        super().__init__()
        self.net = nn.Sequential(
            nn.Linear(input_dim, hidden1),
            nn.ReLU(),
            nn.Linear(hidden1, hidden2),
            nn.ReLU(),
            nn.Linear(hidden2, 1),
            nn.Sigmoid(),
        )

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.net(x).squeeze(-1)


def load_data(data_dir: str) -> tuple[np.ndarray, np.ndarray]:
    """加载所有 game_*.json 文件，提取 (features, result) 对。"""
    pattern = os.path.join(data_dir, "game_*.json")
    files = sorted(glob.glob(pattern))
    if not files:
        print(f"[错误] 未找到训练数据文件: {pattern}")
        sys.exit(1)

    all_features = []
    all_results = []
    for fpath in files:
        with open(fpath, "r", encoding="utf-8") as f:
            data = json.load(f)
        for record in data.get("records", []):
            features = record.get("features", [])
            result = record.get("result", 0.5)
            if len(features) > 0:
                all_features.append(features)
                all_results.append(result)

    print(f"[数据] 加载 {len(files)} 个文件, {len(all_features)} 条记录")
    return np.array(all_features, dtype=np.float32), np.array(all_results, dtype=np.float32)


def export_weights(model: ValueNet, output_path: str, input_dim: int) -> None:
    """将 PyTorch 模型权重导出为 GDScript 可读的 JSON 格式。"""
    layers = []
    activation_map = {
        "ReLU": "relu",
        "Sigmoid": "sigmoid",
    }

    i = 0
    modules = list(model.net.children())
    while i < len(modules):
        module = modules[i]
        if isinstance(module, nn.Linear):
            activation = "relu"
            if i + 1 < len(modules):
                next_mod = modules[i + 1]
                act_name = type(next_mod).__name__
                activation = activation_map.get(act_name, "relu")
            layer = {
                "out_features": module.out_features,
                "activation": activation,
                "weights": module.weight.detach().cpu().numpy().tolist(),
                "bias": module.bias.detach().cpu().numpy().tolist(),
            }
            layers.append(layer)
        i += 1

    data = {
        "architecture": "mlp",
        "input_dim": input_dim,
        "layers": layers,
    }

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
    print(f"[导出] 权重已保存到 {output_path}")


def main():
    parser = argparse.ArgumentParser(description="PTCG Train 价值网络训练")
    parser.add_argument("--data-dir", required=True, help="训练数据目录")
    parser.add_argument("--output", default="value_net_weights.json", help="输出权重文件路径")
    parser.add_argument("--epochs", type=int, default=100, help="训练轮数")
    parser.add_argument("--batch-size", type=int, default=256, help="批次大小")
    parser.add_argument("--lr", type=float, default=0.001, help="学习率")
    parser.add_argument("--hidden1", type=int, default=64, help="第一隐藏层大小")
    parser.add_argument("--hidden2", type=int, default=32, help="第二隐藏层大小")
    args = parser.parse_args()

    features, results = load_data(args.data_dir)
    input_dim = features.shape[1]

    # 80/20 划分
    n = len(features)
    indices = np.random.permutation(n)
    split = int(n * 0.8)
    train_idx, val_idx = indices[:split], indices[split:]

    train_x = torch.from_numpy(features[train_idx])
    train_y = torch.from_numpy(results[train_idx])
    val_x = torch.from_numpy(features[val_idx])
    val_y = torch.from_numpy(results[val_idx])

    train_loader = DataLoader(
        TensorDataset(train_x, train_y),
        batch_size=args.batch_size,
        shuffle=True,
    )

    model = ValueNet(input_dim, args.hidden1, args.hidden2)
    optimizer = torch.optim.Adam(model.parameters(), lr=args.lr)
    criterion = nn.BCELoss()

    print(f"[训练] input_dim={input_dim}, hidden1={args.hidden1}, hidden2={args.hidden2}")
    print(f"[训练] 训练集={len(train_idx)}, 验证集={len(val_idx)}, epochs={args.epochs}")

    for epoch in range(args.epochs):
        model.train()
        train_loss = 0.0
        train_count = 0
        for batch_x, batch_y in train_loader:
            optimizer.zero_grad()
            pred = model(batch_x)
            loss = criterion(pred, batch_y)
            loss.backward()
            optimizer.step()
            train_loss += loss.item() * len(batch_x)
            train_count += len(batch_x)

        if (epoch + 1) % 10 == 0 or epoch == 0:
            model.eval()
            with torch.no_grad():
                val_pred = model(val_x)
                val_loss = criterion(val_pred, val_y).item()
            print(f"  Epoch {epoch+1:3d}: train_loss={train_loss/train_count:.4f}, val_loss={val_loss:.4f}")

    export_weights(model, args.output, input_dim)
    print("[完成]")


if __name__ == "__main__":
    main()
```

- [ ] **Step 3: Commit**

```bash
git add scripts/training/train_value_net.py scripts/training/requirements.txt
git commit -m "feat: add Python training script for value network"
```

---

### Task 6: MCTSPlanner Value Net Integration

**Files:**
- Modify: `scripts/ai/MCTSPlanner.gd`

- [ ] **Step 1: Add value_net and state_encoder fields**

Add after the existing instance variables (after line 17):

```gdscript
## 价值网络（可选）：如果已加载则用于替代 rollout
var value_net: RefCounted = null  # NeuralNetInference
var state_encoder_class: GDScript = null  # StateEncoder
```

- [ ] **Step 2: Modify _evaluate_sequence to use value net**

Replace the `_evaluate_sequence` method (lines 185-219) with:

```gdscript
func _evaluate_sequence(
	gsm: GameStateMachine,
	player_index: int,
	sequence: Array,
	num_rollouts: int,
	max_rollout_steps: int,
	deadline_ms: int = 0
) -> float:
	## 克隆状态、执行整条序列、然后评估
	var sim_gsm := _cloner.clone_gsm(gsm)
	for action: Dictionary in sequence:
		var kind: String = str(action.get("kind", ""))
		if kind == "end_turn":
			if sim_gsm.game_state.phase == GameState.GamePhase.MAIN:
				sim_gsm.end_turn(player_index)
			break
		var resolved := _resolve_action_for_gsm(action, sim_gsm, player_index)
		_try_execute_action(sim_gsm, player_index, resolved)
		if sim_gsm.game_state.is_game_over():
			break

	if sim_gsm.game_state.is_game_over():
		return 1.0 if sim_gsm.game_state.winner_index == player_index else 0.0

	## 价值网络路径：如果可用，用一次前向推理替代多次 rollout
	if value_net != null and value_net.is_loaded() and state_encoder_class != null:
		var features: Array[float] = state_encoder_class.encode(sim_gsm.game_state, player_index)
		return value_net.predict(features)

	## Rollout 路径（原有逻辑）
	var wins: int = 0
	var completed_rollouts: int = 0
	for _i in num_rollouts:
		if deadline_ms > 0 and Time.get_ticks_msec() > deadline_ms:
			break
		var result: Dictionary = _rollout_sim.run_rollout(sim_gsm, player_index, max_rollout_steps)
		completed_rollouts += 1
		if int(result.get("winner_index", -1)) == player_index:
			wins += 1
	return float(wins) / float(completed_rollouts) if completed_rollouts > 0 else 0.0
```

- [ ] **Step 3: Run existing MCTSPlanner tests to verify no regression**

Run: `"D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path . res://tests/TestRunner.tscn --quit-after 90 2>&1 | grep -E "MCTS|FAIL|Total"`

Expected: All MCTS tests PASS (value_net defaults to null, fallback to rollout).

- [ ] **Step 4: Commit**

```bash
git add scripts/ai/MCTSPlanner.gd
git commit -m "feat: add value network evaluation path to MCTSPlanner"
```

---

### Task 7: AIOpponent + EvolutionEngine + TunerRunner Integration

**Files:**
- Modify: `scripts/ai/AIOpponent.gd`
- Modify: `scripts/ai/EvolutionEngine.gd`
- Modify: `scenes/tuner/TunerRunner.gd`

- [ ] **Step 1: AIOpponent — load and pass value net to MCTSPlanner**

Add to `AIOpponent.gd` after existing const declarations:

```gdscript
const NeuralNetInferenceScript = preload("res://scripts/ai/NeuralNetInference.gd")
const StateEncoderScript = preload("res://scripts/ai/StateEncoder.gd")
```

Add variable after `heuristic_weights`:

```gdscript
var value_net_path: String = ""
var _value_net: RefCounted = null
```

In the method that creates the MCTS planner (find where `_mcts_planner` is created or where MCTS planning begins), after creating the planner, set the value net:

```gdscript
## 在 _choose_mcts_action 或 MCTS 初始化位置添加
if _value_net == null and value_net_path != "":
	_value_net = NeuralNetInferenceScript.new()
	if not _value_net.load_weights(value_net_path):
		push_warning("[AIOpponent] 无法加载价值网络: %s" % value_net_path)
		_value_net = null
if _mcts_planner != null:
	_mcts_planner.value_net = _value_net
	_mcts_planner.state_encoder_class = StateEncoderScript
```

- [ ] **Step 2: EvolutionEngine — pass value_net_path through config**

In `EvolutionEngine.gd`, add to `get_default_config()`:

```gdscript
static func get_default_config() -> Dictionary:
	return {
		"heuristic_weights": AIHeuristicsScript.get_default_weights(),
		"mcts_config": {
			"branch_factor": 3,
			"rollouts_per_sequence": 20,
			"rollout_max_steps": 80,
			"time_budget_ms": 3000,
		},
		"value_net_path": "",
	}
```

Add `value_net_path` variable:

```gdscript
var value_net_path: String = ""
```

In `run()`, after building current_best, set value_net_path on both configs before run_batch:

```gdscript
	## 在 run_batch 调用前
	if value_net_path != "":
		mutant_config["value_net_path"] = value_net_path
		current_best["value_net_path"] = value_net_path
```

- [ ] **Step 3: SelfPlayRunner._make_agent — pass value_net_path**

In `SelfPlayRunner.gd`, in `_make_agent`, add:

```gdscript
	var vn_path: Variant = config.get("value_net_path", "")
	if vn_path is String and (vn_path as String) != "":
		agent.value_net_path = vn_path as String
```

- [ ] **Step 4: TunerRunner — add CLI args**

In `scenes/tuner/TunerRunner.gd`, add to the `_ready()` command-line parsing loop:

```gdscript
		elif arg.begins_with("--value-net="):
			engine.value_net_path = arg.split("=")[1]
		elif arg == "--export-data":
			export_data = true
```

Add `export_data` variable before the loop:

```gdscript
	var export_data: bool = false
```

Pass `export_data` to `run_batch` calls (via EvolutionEngine). Add `export_training_data` to EvolutionEngine:

In `EvolutionEngine.gd` add variable:

```gdscript
var export_training_data: bool = false
```

In `EvolutionEngine.run()`, pass it to `_runner.run_batch()`:

```gdscript
		var result: Dictionary = _runner.run_batch(
			mutant_config,
			current_best,
			deck_pairings,
			seed_set,
			max_steps_per_match,
			export_training_data,
		)
```

In `TunerRunner.gd`, set it:

```gdscript
	engine.export_training_data = export_data
```

Update the TunerRunner header comment to document new args:

```gdscript
##   --value-net=path          价值网络权重路径（user:// 格式）
##   --export-data             导出训练数据
```

- [ ] **Step 5: Run all tests to verify no regression**

Run: `"D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path . res://tests/TestRunner.tscn --quit-after 90 2>&1 | grep -E "FAIL|Total"`

Expected: No new failures.

- [ ] **Step 6: Commit**

```bash
git add scripts/ai/AIOpponent.gd scripts/ai/EvolutionEngine.gd scripts/ai/SelfPlayRunner.gd scenes/tuner/TunerRunner.gd
git commit -m "feat: wire value net through AIOpponent, EvolutionEngine, TunerRunner"
```

---

### Task 8: End-to-End Verification

- [ ] **Step 1: Run full test suite**

Run: `"D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --path . res://tests/TestRunner.tscn --quit-after 90 2>&1 | grep -E "FAIL|Total"`

Expected: Only pre-existing CardCatalogAudit failure. All new tests pass.

- [ ] **Step 2: Verify NeuralNetInference can load Python-exported weights format**

This is already covered by `test_load_and_save_json_roundtrip`. Additionally verify the full-size network shape works with StateEncoder output in a manual integration check — this is covered by `test_predict_full_size_zero_weights`.

- [ ] **Step 3: Commit pending changes and verify clean status**

```bash
git status
```

Expected: Clean working tree (all changes committed across Tasks 1-7).

- [ ] **Step 4: Final summary commit if needed**

If there are any loose ends, clean up and commit.
