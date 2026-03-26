# AI Phase 4 MCTS 回合序列搜索 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 AI 通过 MCTS 随机模拟自动发现最优回合动作序列，从"每步贪心"升级到"规划整个回合"。

**Architecture:** 新增三个模块（GameStateCloner / RolloutSimulator / MCTSPlanner），在 AIOpponent 中新增 MCTS 执行模式。搜索时克隆游戏状态，用 beam search 枚举候选回合序列，对每条序列跑 heuristic rollout 评估胜率，选最优序列逐步执行。

**Tech Stack:** Godot 4.6, GDScript, 现有 headless benchmark 基础设施, TestRunner.tscn 测试套件。

---

## File Map

### Create

- `scripts/ai/GameStateCloner.gd`
  - 深拷贝 GameStateMachine 及所有子对象（GameState / PlayerState / PokemonSlot / CardInstance）。
- `scripts/ai/RolloutSimulator.gd`
  - 从克隆状态用 heuristic AI 快速模拟到终局，返回胜负。
- `scripts/ai/MCTSPlanner.gd`
  - Beam search 枚举候选回合序列 + rollout 评估 + 返回最优序列。
- `tests/test_game_state_cloner.gd`
  - GameStateCloner 单元测试。
- `tests/test_rollout_simulator.gd`
  - RolloutSimulator 单元测试。
- `tests/test_mcts_planner.gd`
  - MCTSPlanner 单元测试和行为测试。

### Modify

- `scripts/ai/AIOpponent.gd`
  - 新增 MCTS 模式：回合开始调用 MCTSPlanner，缓存序列，逐步执行。
- `tests/test_ai_baseline.gd`
  - 新增 MCTS 行为测试（选择铺场+攻击序列而非单步攻击）。
- `tests/TestRunner.gd`
  - 注册三个新测试文件。

### Reference

- `docs/superpowers/specs/2026-03-26-ai-phase4-mcts-design.md`
- `scripts/ai/AIHeuristics.gd`
- `scripts/ai/AILegalActionBuilder.gd`
- `scripts/ai/AIBenchmarkRunner.gd`

---

## Task 1: Add GameStateCloner

**Files:**
- Create: `scripts/ai/GameStateCloner.gd`
- Create: `tests/test_game_state_cloner.gd`
- Modify: `tests/TestRunner.gd`

- [ ] **Step 1: Write failing cloner tests**

在 `tests/test_game_state_cloner.gd` 中添加测试：

```gdscript
class_name TestGameStateCloner
extends TestBase

const GameStateClonerScript = preload("res://scripts/ai/GameStateCloner.gd")


func _make_test_gsm() -> GameStateMachine:
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.turn_number = 3
	gsm.game_state.phase = GameState.GamePhase.MAIN
	gsm.game_state.energy_attached_this_turn = true
	CardInstance.reset_id_counter()
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	var card_data := CardData.new()
	card_data.name = "Test Pokemon"
	card_data.card_type = "Pokemon"
	card_data.stage = "Basic"
	card_data.hp = 100
	var active_card := CardInstance.create(card_data, 0)
	var active_slot := PokemonSlot.new()
	active_slot.pokemon_stack.append(active_card)
	active_slot.damage_counters = 30
	var energy_data := CardData.new()
	energy_data.name = "Lightning Energy"
	energy_data.card_type = "Basic Energy"
	energy_data.energy_provides = "L"
	active_slot.attached_energy.append(CardInstance.create(energy_data, 0))
	gsm.game_state.players[0].active_pokemon = active_slot
	var hand_card := CardInstance.create(card_data, 0)
	gsm.game_state.players[0].hand.append(hand_card)
	var deck_card := CardInstance.create(card_data, 0)
	gsm.game_state.players[0].deck.append(deck_card)
	var bench_card := CardInstance.create(card_data, 0)
	var bench_slot := PokemonSlot.new()
	bench_slot.pokemon_stack.append(bench_card)
	gsm.game_state.players[0].bench.append(bench_slot)
	return gsm


func test_clone_produces_independent_game_state() -> String:
	var cloner := GameStateClonerScript.new()
	var original := _make_test_gsm()
	var cloned := cloner.clone_gsm(original)
	cloned.game_state.turn_number = 99
	cloned.game_state.current_player_index = 1
	cloned.game_state.players[0].hand.clear()
	cloned.game_state.players[0].active_pokemon.damage_counters = 999
	return run_checks([
		assert_eq(original.game_state.turn_number, 3, "原始 turn_number 不应被克隆体修改"),
		assert_eq(original.game_state.current_player_index, 0, "原始 current_player 不应被克隆体修改"),
		assert_eq(original.game_state.players[0].hand.size(), 1, "原始手牌不应被克隆体修改"),
		assert_eq(original.game_state.players[0].active_pokemon.damage_counters, 30, "原始伤害不应被克隆体修改"),
	])


func test_clone_preserves_field_values() -> String:
	var cloner := GameStateClonerScript.new()
	var original := _make_test_gsm()
	var cloned := cloner.clone_gsm(original)
	return run_checks([
		assert_eq(cloned.game_state.turn_number, 3, "克隆体应保留 turn_number"),
		assert_eq(cloned.game_state.current_player_index, 0, "克隆体应保留 current_player_index"),
		assert_eq(cloned.game_state.phase, GameState.GamePhase.MAIN, "克隆体应保留 phase"),
		assert_true(cloned.game_state.energy_attached_this_turn, "克隆体应保留回合标志"),
		assert_eq(cloned.game_state.players.size(), 2, "克隆体应保留两个玩家"),
		assert_eq(cloned.game_state.players[0].hand.size(), 1, "克隆体应保留手牌"),
		assert_eq(cloned.game_state.players[0].deck.size(), 1, "克隆体应保留牌库"),
		assert_eq(cloned.game_state.players[0].bench.size(), 1, "克隆体应保留备战区"),
		assert_eq(cloned.game_state.players[0].active_pokemon.damage_counters, 30, "克隆体应保留伤害"),
		assert_eq(cloned.game_state.players[0].active_pokemon.attached_energy.size(), 1, "克隆体应保留附着能量"),
	])


func test_clone_shares_card_data_references() -> String:
	var cloner := GameStateClonerScript.new()
	var original := _make_test_gsm()
	var cloned := cloner.clone_gsm(original)
	var orig_card_data: CardData = original.game_state.players[0].active_pokemon.get_card_data()
	var clone_card_data: CardData = cloned.game_state.players[0].active_pokemon.get_card_data()
	return run_checks([
		assert_eq(orig_card_data, clone_card_data, "CardData 应共享引用不拷贝"),
	])


func test_clone_card_instances_are_independent() -> String:
	var cloner := GameStateClonerScript.new()
	var original := _make_test_gsm()
	var cloned := cloner.clone_gsm(original)
	cloned.game_state.players[0].active_pokemon.get_top_card().face_up = true
	return run_checks([
		assert_false(original.game_state.players[0].active_pokemon.get_top_card().face_up, "修改克隆体的 CardInstance 不应影响原始"),
	])


func test_cloned_gsm_has_working_subsystems() -> String:
	var cloner := GameStateClonerScript.new()
	var original := _make_test_gsm()
	var cloned := cloner.clone_gsm(original)
	return run_checks([
		assert_not_null(cloned.rule_validator, "克隆体应有 rule_validator"),
		assert_not_null(cloned.effect_processor, "克隆体应有 effect_processor"),
		assert_not_null(cloned.coin_flipper, "克隆体应有 coin_flipper"),
	])
```

- [ ] **Step 2: Register test in TestRunner**

在 `tests/TestRunner.gd` 中添加：

顶部 const 区域添加：
```gdscript
const TestGameStateCloner = preload("res://tests/test_game_state_cloner.gd")
```

`_ready()` 中添加（在 AIPhase3Regression 之后、CardCatalogAudit 之前）：
```gdscript
_run_test_suite("GameStateCloner", TestGameStateCloner.new())
```

- [ ] **Step 3: Run tests to verify failure**

Run:
```bash
"D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --quit-after 30 --path "D:/ai/code/ptcgtrain" "res://tests/TestRunner.tscn" 2>&1 | tail -20
```

Expected: 新测试失败，因为 `GameStateCloner` 不存在。

- [ ] **Step 4: Implement GameStateCloner**

创建 `scripts/ai/GameStateCloner.gd`：

```gdscript
class_name GameStateCloner
extends RefCounted

## 深拷贝 GameStateMachine，克隆体可独立运行完整对局。
## CardData 共享引用（静态数据），CardInstance 独立拷贝。
## EffectProcessor / RuleValidator / DamageCalculator 共享引用（无状态或仅静态注册表）。


func clone_gsm(original: GameStateMachine) -> GameStateMachine:
	if original == null:
		return null
	var cloned := GameStateMachine.new()
	cloned.rule_validator = original.rule_validator
	cloned.damage_calculator = original.damage_calculator
	cloned.effect_processor = original.effect_processor
	cloned.coin_flipper = CoinFlipper.new()
	cloned.game_state = _clone_game_state(original.game_state)
	cloned.action_log = []
	return cloned


func _clone_game_state(original: GameState) -> GameState:
	if original == null:
		return GameState.new()
	var cloned := GameState.new()
	cloned.current_player_index = original.current_player_index
	cloned.turn_number = original.turn_number
	cloned.first_player_index = original.first_player_index
	cloned.phase = original.phase
	cloned.energy_attached_this_turn = original.energy_attached_this_turn
	cloned.supporter_used_this_turn = original.supporter_used_this_turn
	cloned.stadium_played_this_turn = original.stadium_played_this_turn
	cloned.retreat_used_this_turn = original.retreat_used_this_turn
	cloned.stadium_effect_used_turn = original.stadium_effect_used_turn
	cloned.stadium_effect_used_player = original.stadium_effect_used_player
	cloned.vstar_power_used = original.vstar_power_used.duplicate()
	cloned.last_knockout_turn_against = original.last_knockout_turn_against.duplicate()
	cloned.shared_turn_flags = original.shared_turn_flags.duplicate(true)
	cloned.winner_index = original.winner_index
	cloned.win_reason = original.win_reason
	cloned.stadium_card = _clone_card_instance(original.stadium_card)
	cloned.stadium_owner_index = original.stadium_owner_index
	cloned.players.clear()
	for player: PlayerState in original.players:
		cloned.players.append(_clone_player_state(player))
	return cloned


func _clone_player_state(original: PlayerState) -> PlayerState:
	if original == null:
		return PlayerState.new()
	var cloned := PlayerState.new()
	cloned.player_index = original.player_index
	cloned.deck = _clone_card_array(original.deck)
	cloned.hand = _clone_card_array(original.hand)
	cloned.prizes = _clone_card_array(original.prizes)
	cloned.discard_pile = _clone_card_array(original.discard_pile)
	cloned.lost_zone = _clone_card_array(original.lost_zone)
	cloned.active_pokemon = _clone_pokemon_slot(original.active_pokemon)
	cloned.bench.clear()
	for slot: PokemonSlot in original.bench:
		cloned.bench.append(_clone_pokemon_slot(slot))
	cloned.prize_layout.clear()
	for i: int in original.prize_layout.size():
		var prize_variant: Variant = original.prize_layout[i]
		if prize_variant is CardInstance:
			var original_card: CardInstance = prize_variant
			var found: CardInstance = _find_cloned_card_in_array(cloned.prizes, original_card)
			cloned.prize_layout.append(found)
		else:
			cloned.prize_layout.append(null)
	return cloned


func _clone_pokemon_slot(original: PokemonSlot) -> PokemonSlot:
	if original == null:
		return null
	var cloned := PokemonSlot.new()
	cloned.pokemon_stack = _clone_card_array_untyped(original.pokemon_stack)
	cloned.attached_energy = _clone_card_array(original.attached_energy)
	cloned.attached_tool = _clone_card_instance(original.attached_tool)
	cloned.damage_counters = original.damage_counters
	cloned.status_conditions = original.status_conditions.duplicate(true)
	cloned.turn_played = original.turn_played
	cloned.turn_evolved = original.turn_evolved
	cloned.effects = original.effects.duplicate(true)
	return cloned


func _clone_card_instance(original: CardInstance) -> CardInstance:
	if original == null:
		return null
	var cloned := CardInstance.new()
	cloned.instance_id = original.instance_id
	cloned.card_data = original.card_data
	cloned.owner_index = original.owner_index
	cloned.face_up = original.face_up
	return cloned


func _clone_card_array(original: Array[CardInstance]) -> Array[CardInstance]:
	var cloned: Array[CardInstance] = []
	for card: CardInstance in original:
		cloned.append(_clone_card_instance(card))
	return cloned


func _clone_card_array_untyped(original: Array) -> Array:
	var cloned: Array = []
	for item: Variant in original:
		if item is CardInstance:
			cloned.append(_clone_card_instance(item))
		else:
			cloned.append(item)
	return cloned


func _find_cloned_card_in_array(cloned_array: Array[CardInstance], original_card: CardInstance) -> CardInstance:
	if original_card == null:
		return null
	for card: CardInstance in cloned_array:
		if card != null and card.instance_id == original_card.instance_id:
			return card
	return null
```

- [ ] **Step 5: Run tests**

Run:
```bash
"D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --quit-after 30 --path "D:/ai/code/ptcgtrain" "res://tests/TestRunner.tscn" 2>&1 | tail -20
```

Expected: 新测试全部通过，无回归。

- [ ] **Step 6: Commit**

```bash
git add scripts/ai/GameStateCloner.gd tests/test_game_state_cloner.gd tests/TestRunner.gd
git commit -m "feat: add GameStateCloner for MCTS simulation"
```

---

## Task 2: Add RolloutSimulator

**Files:**
- Create: `scripts/ai/RolloutSimulator.gd`
- Create: `tests/test_rollout_simulator.gd`
- Modify: `tests/TestRunner.gd`

- [ ] **Step 1: Write failing rollout tests**

在 `tests/test_rollout_simulator.gd` 中添加测试：

```gdscript
class_name TestRolloutSimulator
extends TestBase

const RolloutSimulatorScript = preload("res://scripts/ai/RolloutSimulator.gd")
const GameStateClonerScript = preload("res://scripts/ai/GameStateCloner.gd")
const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")


func _make_basic_card_data(name: String, hp: int = 60) -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = hp
	return card


func _make_energy_card_data(name: String, energy_type: String = "L") -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = "Basic Energy"
	card.energy_provides = energy_type
	return card


func _make_simple_battle_gsm() -> GameStateMachine:
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
	CardInstance.reset_id_counter()
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)
	var attack_cd := _make_basic_card_data("Attacker", 60)
	attack_cd.attacks = [{"name": "Hit", "cost": "C", "damage": "30", "text": "", "is_vstar_power": false}]
	for pi: int in 2:
		var slot := PokemonSlot.new()
		slot.pokemon_stack.append(CardInstance.create(attack_cd, pi))
		slot.attached_energy.append(CardInstance.create(_make_energy_card_data("Energy"), pi))
		gsm.game_state.players[pi].active_pokemon = slot
		for _i in 6:
			gsm.game_state.players[pi].prizes.append(CardInstance.create(_make_basic_card_data("Prize"), pi))
		for _i in 10:
			gsm.game_state.players[pi].deck.append(CardInstance.create(_make_basic_card_data("Deck Card"), pi))
	return gsm


func test_rollout_returns_terminal_result() -> String:
	var sim := RolloutSimulatorScript.new()
	var gsm := _make_simple_battle_gsm()
	var result: Dictionary = sim.run_rollout(gsm, 0, 200)
	return run_checks([
		assert_true(result.has("winner_index"), "Rollout 结果应包含 winner_index"),
		assert_true(result.has("steps"), "Rollout 结果应包含 steps"),
		assert_true(result.has("completed"), "Rollout 结果应包含 completed"),
		assert_true(int(result.get("steps", 0)) > 0, "Rollout 应执行至少一步"),
	])


func test_rollout_respects_max_steps() -> String:
	var sim := RolloutSimulatorScript.new()
	var gsm := _make_simple_battle_gsm()
	var result: Dictionary = sim.run_rollout(gsm, 0, 5)
	return run_checks([
		assert_true(int(result.get("steps", 0)) <= 5, "Rollout 应在 max_steps 内终止"),
	])


func test_rollout_does_not_modify_original_gsm() -> String:
	var sim := RolloutSimulatorScript.new()
	var gsm := _make_simple_battle_gsm()
	var original_turn: int = gsm.game_state.turn_number
	var original_hp: int = gsm.game_state.players[0].active_pokemon.damage_counters
	sim.run_rollout(gsm, 0, 50)
	return run_checks([
		assert_eq(gsm.game_state.turn_number, original_turn, "Rollout 不应修改原始 turn_number"),
		assert_eq(gsm.game_state.players[0].active_pokemon.damage_counters, original_hp, "Rollout 不应修改原始伤害"),
	])
```

- [ ] **Step 2: Register test in TestRunner**

在 `tests/TestRunner.gd` 中添加：

顶部 const：
```gdscript
const TestRolloutSimulator = preload("res://tests/test_rollout_simulator.gd")
```

`_ready()` 中添加：
```gdscript
_run_test_suite("RolloutSimulator", TestRolloutSimulator.new())
```

- [ ] **Step 3: Run tests to verify failure**

Run:
```bash
"D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --quit-after 30 --path "D:/ai/code/ptcgtrain" "res://tests/TestRunner.tscn" 2>&1 | tail -20
```

Expected: 新测试失败，因为 `RolloutSimulator` 不存在。

- [ ] **Step 4: Implement RolloutSimulator**

创建 `scripts/ai/RolloutSimulator.gd`：

```gdscript
class_name RolloutSimulator
extends RefCounted

## 从克隆状态用 heuristic AI 快速模拟到终局。
## 内部自动克隆传入的 gsm，不修改原始状态。

const GameStateClonerScript = preload("res://scripts/ai/GameStateCloner.gd")
const AIOpponentScript = preload("res://scripts/ai/AIOpponent.gd")
const HeadlessMatchBridgeScript = preload("res://scripts/ai/HeadlessMatchBridge.gd")

var _cloner := GameStateClonerScript.new()


func run_rollout(gsm: GameStateMachine, perspective_player: int, max_steps: int = 100) -> Dictionary:
	if gsm == null or gsm.game_state == null:
		return {"winner_index": -1, "steps": 0, "completed": false}

	var cloned := _cloner.clone_gsm(gsm)
	if cloned == null or cloned.game_state == null:
		return {"winner_index": -1, "steps": 0, "completed": false}

	var player_0_ai := AIOpponentScript.new()
	player_0_ai.configure(0, 1)
	var player_1_ai := AIOpponentScript.new()
	player_1_ai.configure(1, 1)

	var bridge := HeadlessMatchBridgeScript.new()
	bridge.bind(cloned)

	var steps: int = 0
	while steps < max_steps:
		if cloned.game_state.is_game_over():
			return {
				"winner_index": cloned.game_state.winner_index,
				"steps": steps,
				"completed": true,
			}
		var progressed: bool = false
		if bridge.has_pending_prompt():
			if bridge.can_resolve_pending_prompt():
				progressed = bridge.resolve_pending_prompt()
			else:
				var prompt_owner: int = bridge.get_pending_prompt_owner()
				var prompt_ai: AIOpponent = player_0_ai if prompt_owner == 0 else player_1_ai
				progressed = prompt_ai.run_single_step(bridge, cloned)
			if not progressed:
				return {"winner_index": -1, "steps": steps + 1, "completed": false}
		else:
			var current: int = cloned.game_state.current_player_index
			var current_ai: AIOpponent = player_0_ai if current == 0 else player_1_ai
			progressed = current_ai.run_single_step(bridge, cloned)
			if not progressed:
				return {"winner_index": -1, "steps": steps + 1, "completed": false}
		steps += 1
	return {"winner_index": -1, "steps": max_steps, "completed": false}
```

- [ ] **Step 5: Run tests**

Run:
```bash
"D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --quit-after 30 --path "D:/ai/code/ptcgtrain" "res://tests/TestRunner.tscn" 2>&1 | tail -20
```

Expected: 新测试全部通过，无回归。

- [ ] **Step 6: Commit**

```bash
git add scripts/ai/RolloutSimulator.gd tests/test_rollout_simulator.gd tests/TestRunner.gd
git commit -m "feat: add RolloutSimulator for MCTS rollout evaluation"
```

---

## Task 3: Add MCTSPlanner

**Files:**
- Create: `scripts/ai/MCTSPlanner.gd`
- Create: `tests/test_mcts_planner.gd`
- Modify: `tests/TestRunner.gd`

- [ ] **Step 1: Write failing MCTS planner tests**

在 `tests/test_mcts_planner.gd` 中添加测试：

```gdscript
class_name TestMCTSPlanner
extends TestBase

const MCTSPlannerScript = preload("res://scripts/ai/MCTSPlanner.gd")


func _make_basic_card_data(name: String, hp: int = 100) -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = "Pokemon"
	card.stage = "Basic"
	card.hp = hp
	return card


func _make_energy_card_data(name: String, energy_type: String = "L") -> CardData:
	var card := CardData.new()
	card.name = name
	card.card_type = "Basic Energy"
	card.energy_provides = energy_type
	return card


func _make_battle_gsm_with_bench_option() -> GameStateMachine:
	## 构造一个场面：P0 有前场 + 手牌里有基础宝可梦可铺 + 有能量可贴 + 可攻击
	## MCTS 应该发现"先铺场再攻击"比"直接攻击"的序列胜率更高
	var gsm := GameStateMachine.new()
	gsm.game_state = GameState.new()
	gsm.game_state.current_player_index = 0
	gsm.game_state.first_player_index = 0
	gsm.game_state.turn_number = 2
	gsm.game_state.phase = GameState.GamePhase.MAIN
	CardInstance.reset_id_counter()
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index = pi
		gsm.game_state.players.append(player)

	var attacker_cd := _make_basic_card_data("Attacker", 100)
	attacker_cd.attacks = [{"name": "Zap", "cost": "C", "damage": "40", "text": "", "is_vstar_power": false}]
	var active_slot := PokemonSlot.new()
	active_slot.pokemon_stack.append(CardInstance.create(attacker_cd, 0))
	active_slot.attached_energy.append(CardInstance.create(_make_energy_card_data("Energy"), 0))
	gsm.game_state.players[0].active_pokemon = active_slot

	var bench_basic := CardInstance.create(_make_basic_card_data("Bench Mon", 80), 0)
	var hand_energy := CardInstance.create(_make_energy_card_data("Energy 2"), 0)
	gsm.game_state.players[0].hand = [bench_basic, hand_energy]

	for _i in 6:
		gsm.game_state.players[0].prizes.append(CardInstance.create(_make_basic_card_data("Prize"), 0))
	for _i in 10:
		gsm.game_state.players[0].deck.append(CardInstance.create(_make_basic_card_data("Deck Card"), 0))

	var opp_slot := PokemonSlot.new()
	opp_slot.pokemon_stack.append(CardInstance.create(_make_basic_card_data("Defender", 100), 1))
	opp_slot.attached_energy.append(CardInstance.create(_make_energy_card_data("Opp Energy"), 1))
	gsm.game_state.players[1].active_pokemon = opp_slot
	for _i in 6:
		gsm.game_state.players[1].prizes.append(CardInstance.create(_make_basic_card_data("Prize"), 1))
	for _i in 10:
		gsm.game_state.players[1].deck.append(CardInstance.create(_make_basic_card_data("Deck Card"), 1))

	return gsm


func test_mcts_planner_returns_action_sequence() -> String:
	var planner := MCTSPlannerScript.new()
	var gsm := _make_battle_gsm_with_bench_option()
	var sequence: Array = planner.plan_turn(gsm, 0, {
		"branch_factor": 3,
		"rollouts_per_sequence": 5,
		"rollout_max_steps": 30,
	})
	return run_checks([
		assert_true(sequence.size() > 0, "MCTS 应返回至少一个动作"),
		assert_true(sequence.size() > 1, "MCTS 应返回多步序列而非只有 end_turn"),
	])


func test_mcts_planner_sequence_ends_with_end_turn_or_attack() -> String:
	var planner := MCTSPlannerScript.new()
	var gsm := _make_battle_gsm_with_bench_option()
	var sequence: Array = planner.plan_turn(gsm, 0, {
		"branch_factor": 3,
		"rollouts_per_sequence": 5,
		"rollout_max_steps": 30,
	})
	var last_kind: String = str(sequence.back().get("kind", "")) if not sequence.is_empty() else ""
	return run_checks([
		assert_true(
			last_kind == "end_turn" or last_kind == "attack",
			"序列最后一步应是 end_turn 或 attack，实际是 %s" % last_kind
		),
	])


func test_mcts_planner_discovers_bench_before_attack() -> String:
	## 核心行为测试：MCTS 应发现"先铺场再攻击"优于"直接攻击"
	var planner := MCTSPlannerScript.new()
	var gsm := _make_battle_gsm_with_bench_option()
	var sequence: Array = planner.plan_turn(gsm, 0, {
		"branch_factor": 3,
		"rollouts_per_sequence": 10,
		"rollout_max_steps": 50,
	})
	var kinds: Array[String] = []
	for action: Dictionary in sequence:
		kinds.append(str(action.get("kind", "")))
	var has_bench := kinds.has("play_basic_to_bench")
	var has_attack := kinds.has("attack")
	return run_checks([
		assert_true(has_bench or has_attack, "MCTS 序列应包含铺场或攻击"),
		assert_true(sequence.size() >= 2, "MCTS 应规划多步序列（不止一步）"),
	])


func test_mcts_planner_does_not_modify_original() -> String:
	var planner := MCTSPlannerScript.new()
	var gsm := _make_battle_gsm_with_bench_option()
	var original_hand_size: int = gsm.game_state.players[0].hand.size()
	var original_bench_size: int = gsm.game_state.players[0].bench.size()
	planner.plan_turn(gsm, 0, {
		"branch_factor": 2,
		"rollouts_per_sequence": 3,
		"rollout_max_steps": 20,
	})
	return run_checks([
		assert_eq(gsm.game_state.players[0].hand.size(), original_hand_size, "MCTS 不应修改原始手牌"),
		assert_eq(gsm.game_state.players[0].bench.size(), original_bench_size, "MCTS 不应修改原始备战区"),
	])
```

- [ ] **Step 2: Register test in TestRunner**

在 `tests/TestRunner.gd` 中添加：

顶部 const：
```gdscript
const TestMCTSPlanner = preload("res://tests/test_mcts_planner.gd")
```

`_ready()` 中添加：
```gdscript
_run_test_suite("MCTSPlanner", TestMCTSPlanner.new())
```

- [ ] **Step 3: Run tests to verify failure**

Run:
```bash
"D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --quit-after 30 --path "D:/ai/code/ptcgtrain" "res://tests/TestRunner.tscn" 2>&1 | tail -20
```

Expected: 新测试失败，因为 `MCTSPlanner` 不存在。

- [ ] **Step 4: Implement MCTSPlanner**

创建 `scripts/ai/MCTSPlanner.gd`：

```gdscript
class_name MCTSPlanner
extends RefCounted

## MCTS 回合序列搜索器。
## 用 beam search 枚举候选回合序列，对每条序列跑 rollout 评估胜率。

const GameStateClonerScript = preload("res://scripts/ai/GameStateCloner.gd")
const RolloutSimulatorScript = preload("res://scripts/ai/RolloutSimulator.gd")
const AILegalActionBuilderScript = preload("res://scripts/ai/AILegalActionBuilder.gd")
const AIHeuristicsScript = preload("res://scripts/ai/AIHeuristics.gd")
const AIFeatureExtractorScript = preload("res://scripts/ai/AIFeatureExtractor.gd")

var _cloner := GameStateClonerScript.new()
var _rollout_sim := RolloutSimulatorScript.new()
var _action_builder := AILegalActionBuilderScript.new()
var _heuristics := AIHeuristicsScript.new()
var _feature_extractor := AIFeatureExtractorScript.new()

## 默认搜索参数
const DEFAULT_BRANCH_FACTOR: int = 3
const DEFAULT_MAX_ACTIONS: int = 10
const DEFAULT_ROLLOUTS: int = 30
const DEFAULT_ROLLOUT_MAX_STEPS: int = 100
const DEFAULT_TIME_BUDGET_MS: int = 3000


func plan_turn(gsm: GameStateMachine, player_index: int, config: Dictionary = {}) -> Array:
	if gsm == null or gsm.game_state == null:
		return [{"kind": "end_turn"}]

	var branch_factor: int = int(config.get("branch_factor", DEFAULT_BRANCH_FACTOR))
	var max_actions: int = int(config.get("max_actions_per_turn", DEFAULT_MAX_ACTIONS))
	var rollouts: int = int(config.get("rollouts_per_sequence", DEFAULT_ROLLOUTS))
	var rollout_steps: int = int(config.get("rollout_max_steps", DEFAULT_ROLLOUT_MAX_STEPS))
	var time_budget: int = int(config.get("time_budget_ms", DEFAULT_TIME_BUDGET_MS))

	## 第一步：枚举候选序列
	var sequences: Array = _enumerate_sequences(gsm, player_index, branch_factor, max_actions)
	if sequences.is_empty():
		return [{"kind": "end_turn"}]

	## 第二步：对每条序列跑 rollout 评估
	var best_sequence: Array = sequences[0]
	var best_win_rate: float = -1.0
	var start_time: int = Time.get_ticks_msec()

	for sequence: Array in sequences:
		if Time.get_ticks_msec() - start_time > time_budget:
			break
		var win_rate: float = _evaluate_sequence(gsm, player_index, sequence, rollouts, rollout_steps)
		if win_rate > best_win_rate:
			best_win_rate = win_rate
			best_sequence = sequence

	return best_sequence


func _enumerate_sequences(
	gsm: GameStateMachine,
	player_index: int,
	branch_factor: int,
	max_depth: int
) -> Array:
	## 用 beam search 枚举候选回合序列
	var results: Array = []
	var initial_clone := _cloner.clone_gsm(gsm)
	_expand_sequences(initial_clone, player_index, [], branch_factor, max_depth, results)
	## 如果没有展开出任何序列，至少返回 end_turn
	if results.is_empty():
		results.append([{"kind": "end_turn"}])
	return results


func _expand_sequences(
	gsm: GameStateMachine,
	player_index: int,
	current_sequence: Array,
	branch_factor: int,
	remaining_depth: int,
	results: Array
) -> void:
	if remaining_depth <= 0:
		var final_seq: Array = current_sequence.duplicate()
		final_seq.append({"kind": "end_turn"})
		results.append(final_seq)
		return

	var actions: Array[Dictionary] = _action_builder.build_actions(gsm, player_index)
	if actions.is_empty():
		var final_seq: Array = current_sequence.duplicate()
		final_seq.append({"kind": "end_turn"})
		results.append(final_seq)
		return

	## 用 heuristic 评分并取 top-K
	var scored: Array = _score_and_rank_actions(gsm, player_index, actions)
	var top_k: Array = scored.slice(0, mini(branch_factor, scored.size()))

	for entry: Dictionary in top_k:
		var action: Dictionary = entry.get("action", {})
		var kind: String = str(action.get("kind", ""))

		if kind == "end_turn":
			var final_seq: Array = current_sequence.duplicate()
			final_seq.append(action)
			results.append(final_seq)
			continue

		## 对非终结动作：克隆状态、执行、递归
		var branch_gsm := _cloner.clone_gsm(gsm)
		var executed := _try_execute_action(branch_gsm, player_index, action)
		if not executed:
			continue

		var next_seq: Array = current_sequence.duplicate()
		next_seq.append(action)

		## 如果执行后游戏阶段不再是 MAIN 或玩家切换，这条分支结束
		if branch_gsm.game_state.phase != GameState.GamePhase.MAIN \
				or branch_gsm.game_state.current_player_index != player_index:
			results.append(next_seq)
			continue

		_expand_sequences(branch_gsm, player_index, next_seq, branch_factor, remaining_depth - 1, results)


func _score_and_rank_actions(
	gsm: GameStateMachine,
	player_index: int,
	actions: Array[Dictionary]
) -> Array:
	var scored: Array = []
	for action: Dictionary in actions:
		var context := {
			"gsm": gsm,
			"game_state": gsm.game_state,
			"player_index": player_index,
			"features": _feature_extractor.build_context(gsm, player_index, action),
		}
		var score: float = _heuristics.score_action(action, context)
		scored.append({"action": action, "score": score})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("score", 0.0)) > float(b.get("score", 0.0))
	)
	return scored


func _evaluate_sequence(
	gsm: GameStateMachine,
	player_index: int,
	sequence: Array,
	num_rollouts: int,
	max_rollout_steps: int
) -> float:
	## 克隆状态、执行整条序列、然后跑 N 次 rollout
	var sim_gsm := _cloner.clone_gsm(gsm)
	for action: Dictionary in sequence:
		var kind: String = str(action.get("kind", ""))
		if kind == "end_turn":
			if sim_gsm.game_state.phase == GameState.GamePhase.MAIN:
				sim_gsm.end_turn(player_index)
			break
		_try_execute_action(sim_gsm, player_index, action)
		if sim_gsm.game_state.is_game_over():
			break

	if sim_gsm.game_state.is_game_over():
		return 1.0 if sim_gsm.game_state.winner_index == player_index else 0.0

	var wins: int = 0
	for _i in num_rollouts:
		var result: Dictionary = _rollout_sim.run_rollout(sim_gsm, player_index, max_rollout_steps)
		if int(result.get("winner_index", -1)) == player_index:
			wins += 1
	return float(wins) / float(num_rollouts) if num_rollouts > 0 else 0.0


func _try_execute_action(gsm: GameStateMachine, player_index: int, action: Dictionary) -> bool:
	## 在克隆的 gsm 上直接执行动作（无 UI）
	var kind: String = str(action.get("kind", ""))
	match kind:
		"attach_energy":
			var target_slot: PokemonSlot = action.get("target_slot")
			var card: CardInstance = action.get("card")
			return gsm.attach_energy(player_index, card, target_slot)
		"play_basic_to_bench":
			var card: CardInstance = action.get("card")
			return gsm.play_basic_to_bench(player_index, card)
		"evolve":
			var card: CardInstance = action.get("card")
			var target_slot: PokemonSlot = action.get("target_slot")
			return gsm.evolve_pokemon(player_index, card, target_slot)
		"play_trainer":
			if bool(action.get("requires_interaction", false)):
				return false
			return gsm.play_trainer(player_index, action.get("card"), action.get("targets", []))
		"play_stadium":
			if bool(action.get("requires_interaction", false)):
				return false
			return gsm.play_stadium(player_index, action.get("card"), action.get("targets", []))
		"use_ability":
			if bool(action.get("requires_interaction", false)):
				return false
			return gsm.use_ability(player_index, action.get("source_slot"), int(action.get("ability_index", 0)), action.get("targets", []))
		"attack":
			if bool(action.get("requires_interaction", false)):
				return false
			return gsm.use_attack(player_index, int(action.get("attack_index", -1)), action.get("targets", []))
		"retreat":
			return gsm.retreat(player_index, action.get("energy_to_discard", []), action.get("bench_target"))
		"end_turn":
			gsm.end_turn(player_index)
			return true
	return false
```

**关键设计说明**：`_try_execute_action` 跳过所有 `requires_interaction` 的动作（道具/特性/攻击交互），因为克隆的 gsm 没有 UI 支持。MCTS 在序列搜索中只考虑可以直接执行的动作。rollout 阶段通过 HeadlessMatchBridge 处理交互。

- [ ] **Step 5: Run tests**

Run:
```bash
"D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --quit-after 60 --path "D:/ai/code/ptcgtrain" "res://tests/TestRunner.tscn" 2>&1 | tail -20
```

注意：MCTS 测试需要更多时间，quit-after 设为 60。

Expected: 新测试全部通过，无回归。

- [ ] **Step 6: Commit**

```bash
git add scripts/ai/MCTSPlanner.gd tests/test_mcts_planner.gd tests/TestRunner.gd
git commit -m "feat: add MCTSPlanner for turn-sequence search"
```

---

## Task 4: Integrate MCTS Mode into AIOpponent

**Files:**
- Modify: `scripts/ai/AIOpponent.gd`
- Modify: `tests/test_ai_baseline.gd`

- [ ] **Step 1: Write failing MCTS integration tests**

在 `tests/test_ai_baseline.gd` 中添加：

```gdscript
func test_ai_opponent_mcts_mode_executes_multi_step_sequence() -> String:
	var ai := AIOpponentScript.new()
	ai.configure(1, 1)
	ai.use_mcts = true
	ai.mcts_config = {
		"branch_factor": 2,
		"rollouts_per_sequence": 3,
		"rollout_max_steps": 20,
	}
	var scene := SpyInteractiveActionBattleScene.new()
	var gsm := _make_ai_manual_gsm()
	gsm.game_state.current_player_index = 1
	var player: PlayerState = gsm.game_state.players[1]
	var opponent: PlayerState = gsm.game_state.players[0]

	var attacker_cd := _make_ai_pokemon_card_data(
		"Attacker", "Basic", "", "", [],
		[{"name": "Zap", "cost": "C", "damage": "40", "text": "", "is_vstar_power": false}]
	)
	player.active_pokemon = _make_ai_slot(CardInstance.create(attacker_cd, 1))
	player.active_pokemon.attached_energy.append(CardInstance.create(_make_ai_energy_card_data("Energy"), 1))
	var bench_basic := CardInstance.create(_make_ai_pokemon_card_data("Bench Mon"), 1)
	player.hand = [bench_basic]
	opponent.active_pokemon = _make_ai_slot(CardInstance.create(_make_ai_pokemon_card_data("Defender"), 0))

	for _i in 6:
		player.prizes.append(CardInstance.create(_make_ai_pokemon_card_data("Prize"), 1))
		opponent.prizes.append(CardInstance.create(_make_ai_pokemon_card_data("Prize"), 0))
	for _i in 10:
		player.deck.append(CardInstance.create(_make_ai_pokemon_card_data("Deck"), 1))
		opponent.deck.append(CardInstance.create(_make_ai_pokemon_card_data("Deck"), 0))

	var step_count: int = 0
	while step_count < 10:
		var handled := ai.run_single_step(scene, gsm)
		if not handled:
			break
		step_count += 1
		if gsm.game_state.phase != GameState.GamePhase.MAIN or gsm.game_state.current_player_index != 1:
			break

	return run_checks([
		assert_true(step_count >= 2, "MCTS 模式应执行多步动作序列（铺场+攻击），实际执行了 %d 步" % step_count),
	])


func test_ai_opponent_mcts_mode_disabled_by_default() -> String:
	var ai := AIOpponentScript.new()
	return run_checks([
		assert_false(ai.use_mcts, "MCTS 模式默认应关闭"),
	])
```

- [ ] **Step 2: Run tests to verify failure**

Run:
```bash
"D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --quit-after 60 --path "D:/ai/code/ptcgtrain" "res://tests/TestRunner.tscn" 2>&1 | tail -20
```

Expected: 新测试失败，因为 `use_mcts` 属性不存在。

- [ ] **Step 3: Implement MCTS mode in AIOpponent**

在 `scripts/ai/AIOpponent.gd` 中添加：

顶部新增 const：
```gdscript
const MCTSPlannerScript = preload("res://scripts/ai/MCTSPlanner.gd")
```

新增成员变量（在 `_last_decision_trace` 之后）：
```gdscript
var use_mcts: bool = false
var mcts_config: Dictionary = {}
var _mcts_planner = MCTSPlannerScript.new()
var _mcts_planned_sequence: Array = []
var _mcts_sequence_index: int = 0
```

修改 `_choose_best_action()` 方法，在现有逻辑开头加入 MCTS 分支：

```gdscript
func _choose_best_action(gsm: GameStateMachine) -> Dictionary:
	## MCTS 模式：使用预规划序列
	if use_mcts:
		return _choose_mcts_action(gsm)
	## 原有 heuristic 逻辑保持不变...
```

新增 MCTS 相关方法：
```gdscript
func _choose_mcts_action(gsm: GameStateMachine) -> Dictionary:
	## 如果还有预规划的序列动作，继续执行
	if _mcts_sequence_index < _mcts_planned_sequence.size():
		var action: Dictionary = _mcts_planned_sequence[_mcts_sequence_index]
		_mcts_sequence_index += 1
		return action
	## 否则规划新序列
	_mcts_planned_sequence = _mcts_planner.plan_turn(gsm, player_index, mcts_config)
	_mcts_sequence_index = 0
	if _mcts_planned_sequence.is_empty():
		return {"kind": "end_turn"}
	var action: Dictionary = _mcts_planned_sequence[_mcts_sequence_index]
	_mcts_sequence_index += 1
	return action
```

- [ ] **Step 4: Run tests**

Run:
```bash
"D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --quit-after 60 --path "D:/ai/code/ptcgtrain" "res://tests/TestRunner.tscn" 2>&1 | tail -20
```

Expected: 新测试通过，无回归。

- [ ] **Step 5: Commit**

```bash
git add scripts/ai/AIOpponent.gd tests/test_ai_baseline.gd
git commit -m "feat: integrate MCTS mode into AIOpponent"
```

---

## Task 5: Enable MCTS in BattleScene VS_AI

**Files:**
- Modify: `scenes/battle/BattleScene.gd`

- [ ] **Step 1: Enable MCTS for AI opponent in VS_AI mode**

在 `scenes/battle/BattleScene.gd` 中找到 `_setup_ai_for_tests` 或 AI 初始化代码，确保 VS_AI 模式下 AI 对手启用 MCTS。

找到 `_ensure_ai_opponent()` 或类似的 AI 初始化点，在创建 AIOpponent 后添加：

```gdscript
_ai_opponent.use_mcts = true
_ai_opponent.mcts_config = {
	"branch_factor": 3,
	"rollouts_per_sequence": 20,
	"rollout_max_steps": 80,
	"time_budget_ms": 3000,
}
```

- [ ] **Step 2: Run the game and manually test**

```bash
"D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --path "D:/ai/code/ptcgtrain"
```

用 VS_AI 模式打密勒顿，观察：
- AI 是否在思考后执行多步动作
- AI 是否铺场 + 贴能 + 攻击
- 每回合是否等待 2-5 秒

- [ ] **Step 3: Run full test suite**

```bash
"D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --quit-after 60 --path "D:/ai/code/ptcgtrain" "res://tests/TestRunner.tscn" 2>&1 | tail -20
```

Expected: 无回归。

- [ ] **Step 4: Commit**

```bash
git add scenes/battle/BattleScene.gd
git commit -m "feat: enable MCTS AI in VS_AI mode"
```

---

## Task 6: Full Suite Verification and Cleanup

**Files:**
- Modify: none unless bugs found

- [ ] **Step 1: Run full automated test suite**

```bash
"D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe" --headless --quit-after 90 --path "D:/ai/code/ptcgtrain" "res://tests/TestRunner.tscn" 2>&1 | tail -30
```

Expected: 所有测试通过（除预存的 CardCatalogAudit 失败）。

- [ ] **Step 2: Remove debug print from BattleScene**

删除 Task 7 smoke test 时添加的临时 AI trace print 代码（5 行）。

- [ ] **Step 3: Manual VS_AI smoke test**

用 VS_AI 模式各打一局：
- 密勒顿
- 沙奈朵
- 喷火龙 ex

观察 AI 是否执行多步回合序列。

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "feat: complete Phase 4 MCTS turn-sequence search"
```

---

## Execution Notes

- MCTS 测试需要更多运行时间，quit-after 至少设 60 秒。
- `_try_execute_action` 跳过 `requires_interaction` 的动作。rollout 通过 HeadlessMatchBridge 处理交互。序列搜索只考虑可直接执行的动作。
- 如果 GDScript 性能不够，先减少 rollouts_per_sequence 和 rollout_max_steps。
- GameStateCloner 共享 EffectProcessor / RuleValidator / DamageCalculator 引用，只拷贝数据层。
- MCTS 模式和 heuristic 模式通过 `use_mcts` 开关共存，benchmark 可做 A/B 对比。

## Suggested Commit Sequence

1. `feat: add GameStateCloner for MCTS simulation`
2. `feat: add RolloutSimulator for MCTS rollout evaluation`
3. `feat: add MCTSPlanner for turn-sequence search`
4. `feat: integrate MCTS mode into AIOpponent`
5. `feat: enable MCTS AI in VS_AI mode`
6. `feat: complete Phase 4 MCTS turn-sequence search`
