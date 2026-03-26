# AI Phase 4 MCTS 回合序列搜索设计

日期：2026-03-26

## 1. 背景

Phase 3 完成了决策追踪、特征提取、共享启发式增强和轻量牌组偏置。AI 现在可以观察、可以用 benchmark 回归验证，但核心决策质量仍然很低：每步贪心选最高分单动作，不理解"先铺场再攻击更赚"的回合内序列规划。

人工调 heuristic 权重治标不治本——问题不在参数，在于架构只能看一步。

Phase 4 的目标是让 AI 通过 **MCTS 随机模拟** 自动发现最优回合动作序列，类似 AlphaGo 的思路：对每个候选走法模拟多局后续对局，选胜率最高的。

## 2. 目标

### 2.1 决策质量目标

AI 在实时 VS_AI 对局中：

1. 能在一回合内执行多步有意义的动作序列（铺场 → 贴能 → 攻击）
2. 不再频繁"只贴能就过"或"能打就直接打不展开"
3. 三套 pinned decks 的对局质量明显优于 Phase 3 heuristic

### 2.2 性能目标

1. 实时对战中 AI 每回合思考时间 2-5 秒
2. 思考过程不阻塞 UI 主线程（使用分帧或后台执行）
3. 单次 rollout 对局足够快（复用 headless duel 逻辑）

### 2.3 评测目标

1. Phase 4 MCTS agent 对 Phase 3 heuristic agent 的 benchmark 胜率明显提升
2. stall rate 和 cap termination rate 不上升
3. identity hit rate 不下降

## 3. 非目标

1. 不引入神经网络或外部 ML 框架
2. 不做离线训练管线
3. 不处理隐藏信息（使用全知模拟，双方可见全部状态）
4. 不追求完美对局，目标是"明显比 heuristic 强"
5. 不扩展到更多牌组

## 4. 系统架构

### 4.1 整体流程

```
玩家回合开始
    ↓
AIOpponent 检测 MCTS 模式
    ↓
MCTSPlanner.plan_turn(gsm, player_index):
  1. 克隆当前 GameState
  2. 用 heuristic 预筛每步 top-K 候选动作（K=3）
  3. 逐步展开候选分支，每步选 top-K，直到回合结束（end_turn 或无合法动作）
  4. 得到 ~20-50 条候选回合序列
  5. 对每条序列:
     a. 克隆初始状态
     b. 依次执行序列中的所有动作
     c. 从执行完的状态跑 N 次 rollout 到终局
     d. 记录胜率
  6. 返回胜率最高的序列
    ↓
AIOpponent 逐步执行序列中的动作
```

### 4.2 模块划分

#### GameStateCloner

职责：深拷贝 GameStateMachine 及其所有子对象，使克隆体可以独立运行完整对局。

关键约束：
1. CardData 是静态数据，所有 CardInstance 共享引用，不需要拷贝
2. CardInstance 需要拷贝（instance_id、owner_index、face_up），但 card_data 字段直接引用原对象
3. PokemonSlot 需要递归拷贝 pokemon_stack、attached_energy、status_conditions、effects
4. PlayerState 需要拷贝 deck、hand、prizes、discard_pile、lost_zone、active_pokemon、bench
5. GameState 需要拷贝所有标量字段 + players 数组
6. EffectProcessor、RuleValidator、DamageCalculator 无状态或仅持有静态注册表，可在克隆体间共享
7. CoinFlipper 新建即可（用随机种子）
8. GameStateMachine 的 signal 连接不需要克隆（rollout 中无 UI 订阅）

#### MCTSPlanner

职责：给定当前局面，搜索最优回合动作序列。

接口：

```gdscript
func plan_turn(gsm: GameStateMachine, player_index: int, config: Dictionary = {}) -> Array[Dictionary]
```

返回值：有序的动作序列 `[action1, action2, ..., end_turn]`。

搜索过程：
1. 从当前状态出发
2. 用现有 AIHeuristics 对合法动作评分，取 top-K
3. 对每个候选动作，克隆状态并执行该动作，然后递归展开下一步
4. 当遇到 end_turn 或无合法动作时，该分支形成一条完整序列
5. 限制最大展开深度（max_actions_per_turn）防止序列过长
6. 对每条序列跑 rollout 评估

配置参数：
- `branch_factor`: 每步保留的候选数，默认 3
- `max_actions_per_turn`: 单回合最大动作数，默认 10
- `rollouts_per_sequence`: 每条序列的 rollout 次数，默认 30
- `rollout_max_steps`: 单次 rollout 的最大步数，默认 100
- `time_budget_ms`: 总思考时间上限（毫秒），默认 3000

#### RolloutSimulator

职责：从给定状态快速模拟到终局，返回胜负结果。

接口：

```gdscript
func run_rollout(gsm: GameStateMachine, player_index: int, max_steps: int = 100) -> Dictionary
```

返回值：`{ "winner_index": int, "steps": int, "completed": bool }`

实现：复用现有 headless duel 逻辑。双方都使用 heuristic AI（Phase 3）作为 rollout 策略。不做递归 MCTS——rollout 中只用快速 heuristic 决策。

#### AIOpponent 修改

新增 MCTS 执行模式：

1. 新增配置: `var use_mcts: bool = false`
2. 当 `use_mcts == true` 时，在回合开始时调用 `MCTSPlanner.plan_turn()` 获取完整序列
3. 缓存序列，每次 `run_single_step()` 从序列中取下一个动作执行
4. 序列执行完毕后清空缓存，等待下一回合

### 4.3 数据流

1. GameStateCloner.clone_gsm() -> 克隆体 A（用于序列展开）
   - 执行 action_1 -> 克隆体 A'
     - 执行 action_2 -> end_turn -> 序列 [a1, a2, end]
     - 执行 action_3 -> ...
   - 执行 action_4 -> ...
2. 对每条完整序列:
   - GameStateCloner.clone_gsm() -> 克隆体 B
   - 执行完整序列
   - RolloutSimulator.run_rollout() x N 次
   - 记录胜率
3. 选胜率最高的序列 -> 返回给 AIOpponent

## 5. 组合爆炸控制

回合序列级搜索的最大风险是组合爆炸。控制策略：

### 5.1 Beam Search 剪枝

每步只保留 heuristic 评分 top-K（K=3）的候选动作，而非全部合法动作。典型情况下合法动作有 5-15 个，K=3 大幅缩减。

### 5.2 序列深度限制

单回合最多展开 max_actions_per_turn（默认 10）步。超过后强制结束。

### 5.3 时间预算

设置总思考时间上限。超时后返回当前最优序列。

### 5.4 预期规模估算

- 每步 K=3，最多 10 步
- 但实际上很多分支会提前遇到 end_turn（无更多合法动作）
- 预期有效序列数：20-80 条
- 每条序列 30 次 rollout，每次 rollout ~100 步
- 单次 rollout 中每步：评分（微秒级）+ 执行（微秒级）
- 总计：约 60,000-240,000 步模拟
- GDScript 性能：每步约 10-50 微秒 → 总计 0.6-12 秒
- 配合时间预算可控制在 3-5 秒内

## 6. 隐藏信息处理

Phase 4 使用全知模拟：AI 在模拟时可以看到对手手牌和牌库顺序。

理由：
1. 当前最大的问题不是信息不对称，而是策略规划能力
2. AI vs AI 自我博弈时双方都全知，公平
3. VS_AI 对人类时 AI 有信息优势，但实际影响有限——AI 的提升主要来自更好的序列规划，不是偷看手牌
4. 全知模拟实现简单，避免需要做确定化采样

如果未来需要限制信息，可以在 RolloutSimulator 入口处对对手手牌和牌库做随机洗牌（确定化），但 Phase 4 不做。

## 7. 与现有系统的集成

### 7.1 AIOpponent 双模式

AIOpponent 支持 heuristic 模式（Phase 3）和 MCTS 模式（Phase 4）切换：

- heuristic 模式：每步独立评分，即时决策（现有行为）
- MCTS 模式：回合开始时规划完整序列，然后逐步执行

两种模式共存，benchmark 可以做 heuristic vs MCTS 的 A/B 对比。

### 7.2 Benchmark 集成

使用现有 Phase 2/3 benchmark 系统：
- 新增 agent_config: `{"agent_id": "shared-heuristic", "version_tag": "mcts-v1"}`
- 用 version_regression 模式对比 baseline-v1 和 mcts-v1
- 复用所有 regression gate 和 identity tracking

### 7.3 BattleScene 集成

MCTS 思考需要时间，在 BattleScene 中：
1. 显示"AI 思考中..."提示
2. 使用 `call_deferred` 或分帧处理避免阻塞 UI
3. 序列计算完成后逐步执行动作，每步间加短延迟让玩家看到过程

## 8. 测试策略

### 8.1 单元测试

1. GameStateCloner: 克隆后状态完全独立，修改克隆体不影响原始
2. MCTSPlanner: 给定简单确定性局面，返回的序列优于纯 heuristic
3. RolloutSimulator: 能跑到终局并返回胜负

### 8.2 行为测试

1. MCTS AI 在"能铺场+攻击"的局面选择先铺场再攻击（而非直接攻击）
2. MCTS AI 不会在明显可展开时过早结束回合
3. MCTS AI 的回合序列长度 > 1（不再只做一步就过）

### 8.3 Benchmark 回归

1. MCTS agent vs heuristic agent 的 A/B 对比
2. 胜率、stall rate、identity hit rate 等指标

## 9. 文件结构

### 新建

- `scripts/ai/GameStateCloner.gd` — 游戏状态深拷贝
- `scripts/ai/MCTSPlanner.gd` — MCTS 回合序列搜索
- `scripts/ai/RolloutSimulator.gd` — 快速 rollout 模拟
- `tests/test_game_state_cloner.gd` — 克隆器测试
- `tests/test_mcts_planner.gd` — MCTS 搜索测试
- `tests/test_rollout_simulator.gd` — rollout 测试

### 修改

- `scripts/ai/AIOpponent.gd` — 新增 MCTS 执行模式
- `tests/test_ai_baseline.gd` — 新增 MCTS 行为测试
- `tests/TestRunner.gd` — 注册新测试文件

## 10. 实施顺序

1. 先做 GameStateCloner（基础设施）
2. 再做 RolloutSimulator（依赖 cloner）
3. 再做 MCTSPlanner（依赖 cloner + rollout）
4. 最后集成到 AIOpponent 和 BattleScene
5. Benchmark A/B 验证

## 11. 风险

1. **GDScript 性能**：如果 rollout 太慢，可能需要减少 rollout 次数或降低搜索深度。备选方案：用局面评估函数替代部分 rollout。
2. **效果处理器的副作用**：某些卡牌效果可能依赖全局状态或 UI 回调。rollout 中需要确保这些不会崩溃。headless duel 已经处理了大部分情况。
3. **组合爆炸**：如果某些局面的合法动作特别多（如手牌多张道具），序列数可能超预期。时间预算是最终保障。
