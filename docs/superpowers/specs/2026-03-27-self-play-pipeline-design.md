# Self-Play Pipeline 设计文档（第一期：权重调优阶段）

日期：2026-03-27

## 1. 背景

Phase 4 完成了 MCTS 回合序列搜索，AI 从"每步贪心"升级到了"规划整个回合"。但 AI 的决策质量仍然依赖手工调整的 heuristic 权重和 MCTS 参数。未提交的 HeuristicTuner 已经有了进化搜索的雏形，但只调 heuristic 权重，且规模较小（50 代 × 24 局）。

本设计的目标是建立一条完整的 self-play pipeline：**让 AI 通过自博弈自动进化，每轮产出比上一轮更强的 agent，无需人工干预**。

## 2. 分期策略

分两期建设：

- **第一期（本文档范围）**：纯 GDScript 闭环。用进化搜索联合调优 heuristic 权重 + MCTS 参数，通过大规模自博弈验证，产出越来越强的 agent。
- **第二期（未来）**：引入 Python + ML 框架，用第一期积累的对局数据训练策略/价值网络，替代 heuristic 评估函数。第一期预留数据接口。

## 3. 目标

### 3.1 功能目标

1. 一条可无人值守运行的自动化 pipeline：启动后自动进化，产出更强 agent
2. 搜索空间覆盖 heuristic 权重（40+）和 MCTS 参数（4 个）
3. 每代 agent 自动持久化，可回溯历史版本
4. 进化日志可观测，可分析收敛趋势

### 3.2 性能目标

1. 第一期不预设固定规模，先跑通 pipeline 再根据实际性能决定扩大
2. 单局 headless 对战目标：< 2 秒（heuristic 模式）或 < 15 秒（MCTS 模式）
3. 一轮进化（1 代）应在分钟级完成

### 3.3 非目标

1. 不引入神经网络或外部 ML 框架（第二期）
2. 不做分布式多机并行（当前单进程 Godot）
3. 不做 Elo 评分系统（第二期升级）
4. 不做卡组搜索（独立 Phase）
5. 不修改 MCTS 搜索算法本身，只调其参数

## 4. 系统架构

### 4.1 新增模块

```
scripts/ai/
  SelfPlayRunner.gd       — 批量自博弈执行器
  EvolutionEngine.gd      — 进化搜索引擎
  AgentVersionStore.gd    — Agent 版本持久化
```

### 4.2 改造模块

```
scripts/ai/
  HeuristicTuner.gd       — 并入 EvolutionEngine，废弃独立文件
  AIBenchmarkRunner.gd     — SelfPlayRunner 复用其 run_headless_duel 核心
```

### 4.3 模块职责

#### SelfPlayRunner

职责：接收两个 agent config，在多组卡组对上跑 N 局 headless 对战，输出结构化结果集。

接口：

```gdscript
func run_batch(
    agent_a_config: Dictionary,
    agent_b_config: Dictionary,
    deck_pairings: Array[Array],
    seeds: Array[int],
    max_steps_per_match: int = 200
) -> Dictionary
```

输入参数：
- `agent_a_config` / `agent_b_config`：包含 `heuristic_weights: Dictionary` 和 `mcts_config: Dictionary`
- `deck_pairings`：卡组 ID 对数组，如 `[[575720, 578647], [575720, 575716]]`
- `seeds`：随机种子数组
- `max_steps_per_match`：单局最大步数

返回值：

```gdscript
{
    "total_matches": int,
    "agent_a_wins": int,
    "agent_b_wins": int,
    "draws": int,
    "agent_a_win_rate": float,
    "match_results": Array[Dictionary],  # 每局详情
}
```

实现要点：
- 对每组 (deck_pairing, seed)，双方各做 player 0 和 player 1 各一局（消除先后手偏差）
- 复用 AIBenchmarkRunner 的 `run_headless_duel` 核心逻辑
- 根据 agent config 中是否包含 `mcts_config`，自动决定 heuristic / MCTS 模式

#### EvolutionEngine

职责：进化搜索引擎，联合调优 heuristic 权重和 MCTS 参数。

接口：

```gdscript
func run(initial_config: Dictionary = {}) -> Dictionary
```

输入参数：
- `initial_config`：初始 agent config。为空时使用默认权重和 MCTS 参数。

返回值：

```gdscript
{
    "best_config": Dictionary,         # 最终最优 agent config
    "generations_run": int,
    "generation_log": Array[Dictionary],
    "versions_saved": Array[String],   # 已保存的版本文件路径
}
```

搜索空间：

```gdscript
{
    "heuristic_weights": {
        "attack_knockout": 1000.0,
        "attack_base": 500.0,
        # ... 40+ 个权重
    },
    "mcts_config": {
        "branch_factor": 3,
        "rollouts_per_sequence": 20,
        "rollout_max_steps": 80,
        "time_budget_ms": 3000,
    }
}
```

进化策略：

1. **高斯扰动生成 mutant**：
   - heuristic 权重：乘性扰动 `value * (1 + N(0, sigma_w))`，`sigma_w` 默认 0.15
   - MCTS 参数：乘性扰动 `value * (1 + N(0, sigma_m))`，`sigma_m` 默认 0.10（MCTS 参数波动不宜太大）
   - MCTS 参数扰动后取整并 clamp 到合理范围（branch_factor: 2-5, rollouts: 5-50, rollout_steps: 30-200, time_budget: 1000-10000）

2. **自适应 sigma**：
   - 连续 3 代拒绝 → sigma 增大 20%（搜索步长太小，扩大探索）
   - 连续 3 代接受 → sigma 缩小 10%（接近最优，精细搜索）
   - sigma 范围 clamp: [0.05, 0.40]

3. **接受条件**：
   - mutant vs current-best 胜率 > 50%

配置参数：

```gdscript
var generations: int = 50
var sigma_weights: float = 0.15
var sigma_mcts: float = 0.10
var matches_per_eval: int = 24        # 每代评估对局数（初始值，可扩大）
var max_steps_per_match: int = 200
var seed_set: Array[int] = [11, 29, 47, 83]
var deck_pairings: Array[Array] = [
    [575720, 578647],
    [575720, 575716],
    [578647, 575716],
]
```

#### AgentVersionStore

职责：将 agent config 序列化为 JSON 文件，管理版本谱系。

接口：

```gdscript
func save_version(config: Dictionary, metadata: Dictionary) -> String
func load_version(path: String) -> Dictionary
func load_latest() -> Dictionary
func list_versions() -> Array[Dictionary]
```

存储位置：`user://ai_agents/`

文件格式：

```json
{
    "version": "v042_20260327_153022",
    "generation": 42,
    "parent_version": "v041_20260327_152815",
    "win_rate_vs_parent": 0.583,
    "timestamp": "2026-03-27T15:30:22",
    "heuristic_weights": { ... },
    "mcts_config": { ... }
}
```

命名规范：`agent_v{gen}_{timestamp}.json`

## 5. 数据流

```
EvolutionEngine.run() 启动
    ↓
加载 initial config（AgentVersionStore.load_latest() 或默认）
    ↓
循环每代 (gen = 0..generations-1):
    1. _mutate(current_best_config) → mutant_config
       - heuristic_weights 用 sigma_w 扰动
       - mcts_config 用 sigma_m 扰动 + clamp
    2. SelfPlayRunner.run_batch(mutant, current_best, deck_pairings, seeds)
       → { agent_a_win_rate, ... }
    3. if agent_a_win_rate > 0.5:
         current_best = mutant
         AgentVersionStore.save_version(mutant, {generation, win_rate})
         _adjust_sigma("accept")
       else:
         _adjust_sigma("reject")
    4. 记录 generation_log
    ↓
输出 best_config + evolution_log
```

## 6. 与现有系统的集成

| 现有模块 | 集成方式 |
|---|---|
| AIBenchmarkRunner | SelfPlayRunner 内部复用 `run_headless_duel()`，不修改原模块 |
| BenchmarkEvaluator | 第一期用其基础统计，不修改 |
| HeuristicTuner | 逻辑并入 EvolutionEngine，原文件标记为废弃 |
| MCTSPlanner | 不修改，参数通过 AIOpponent.mcts_config 注入 |
| AIHeuristics | 不修改评分逻辑，weights 通过 AIOpponent.heuristic_weights 注入 |
| AIOpponent | 不修改，SelfPlayRunner 通过现有 configure() + heuristic_weights + use_mcts + mcts_config 控制 |

## 7. 运行方式

### 7.1 命令行入口

通过一个场景脚本提供入口，可用 Godot headless 模式启动：

```bash
godot --headless --quit-after 3600 --path "." "res://scenes/tuner/TunerRunner.tscn"
```

`TunerRunner.tscn` 的脚本：
1. 创建 EvolutionEngine
2. 配置参数（可从命令行参数或配置文件读取）
3. 调用 `engine.run()`
4. 打印结果并退出

### 7.2 进度输出

每代打印一行摘要：

```
[Evolution] 第 0 代: mutant 胜率 54.2% → 接受 (sigma_w=0.150, sigma_m=0.100)
[Evolution] 第 1 代: mutant 胜率 45.8% → 拒绝 (sigma_w=0.150, sigma_m=0.100)
[Evolution] 第 2 代: mutant 胜率 62.5% → 接受 (sigma_w=0.150, sigma_m=0.100)
...
[Evolution] 完成! 50 代, 最终最优 agent: v023_20260327_160512
```

## 8. 第二期预留

### 8.1 对局数据格式

SelfPlayRunner 的 `match_results` 中每局包含：

```gdscript
{
    "winner_index": int,
    "turn_count": int,
    "seed": int,
    "deck_a_id": int,
    "deck_b_id": int,
    "agent_a_config_version": String,
    "agent_b_config_version": String,
}
```

第二期扩展时，在此基础上增加每步的 `(state_features, action_taken, reward)` 三元组，供 Python 训练脚本消费。第一期不实现这些字段。

### 8.2 评测升级路径

第一期：mutant vs current-best 胜率 > 50% 即接受。
第二期：引入 agent 联盟，新 agent 必须对联盟中所有现有 agent 的综合胜率 > 阈值才能晋级，输出 Elo 评分。

## 9. 测试策略

### 9.1 单元测试

1. **SelfPlayRunner**: 两个相同 config 的 agent 对战，胜率应在 40%-60% 之间（统计波动）
2. **EvolutionEngine**: mock SelfPlayRunner 返回固定胜率，验证接受/拒绝逻辑、sigma 自适应、代数终止
3. **AgentVersionStore**: save → load 往返测试，verify 字段完整性；list_versions 排序正确

### 9.2 集成测试

1. 端到端跑 3 代进化（小规模：2 局/代），验证：
   - 产出的 agent config 权重确实变了
   - AgentVersionStore 中有保存记录
   - generation_log 完整
2. 确保进化过程不修改默认权重（隔离性）

### 9.3 回归测试

1. 现有 Phase 2/3/4 的所有测试不受影响
2. AIBenchmarkRunner 行为不变

## 10. 文件结构

### 新建

- `scripts/ai/SelfPlayRunner.gd` — 批量自博弈执行器
- `scripts/ai/EvolutionEngine.gd` — 进化搜索引擎
- `scripts/ai/AgentVersionStore.gd` — Agent 版本持久化
- `scenes/tuner/TunerRunner.tscn` — headless 入口场景
- `scenes/tuner/TunerRunner.gd` — 入口脚本
- `tests/test_self_play_runner.gd` — SelfPlayRunner 测试
- `tests/test_evolution_engine.gd` — EvolutionEngine 测试
- `tests/test_agent_version_store.gd` — AgentVersionStore 测试

### 修改

- `scripts/ai/HeuristicTuner.gd` — 标记废弃，逻辑迁移到 EvolutionEngine
- `tests/TestRunner.gd` — 注册新测试文件

### 废弃

- `scripts/ai/HeuristicTuner.gd` — 被 EvolutionEngine 取代

## 11. 实施顺序

1. AgentVersionStore（基础设施，无外部依赖）
2. SelfPlayRunner（依赖现有 AIBenchmarkRunner）
3. EvolutionEngine（依赖 SelfPlayRunner + AgentVersionStore）
4. TunerRunner 场景入口（依赖 EvolutionEngine）
5. 端到端验证 + HeuristicTuner 废弃清理

## 12. 风险

1. **GDScript 单线程性能**：MCTS 模式下单局可能需要 10-15 秒。50 代 × 24 局 = 1200 局，MCTS 模式下可能需要 4+ 小时。缓解：第一期先用 heuristic 模式跑通（单局 < 2 秒），MCTS 参数用较小值。
2. **进化搜索收敛速度**：40+ 维权重空间 + 4 维 MCTS 参数，hill-climbing 可能收敛很慢。缓解：分组 sigma + 自适应步长；如果不收敛，可切换到 CMA-ES 等更高级的进化策略。
3. **过拟合到特定卡组对**：只用 3 组卡组对评估，可能产出只针对这 3 组表现好的权重。缓解：后续增加卡组对数量；第二期引入卡组搜索时自然缓解。
4. **统计显著性**：24 局/代的样本量较小，胜率波动大。缓解：先跑通再视情况增大 matches_per_eval。
