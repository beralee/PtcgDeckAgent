# 公共 AI Intent Planner 架构设计

日期：2026-05-05
负责人：Codex
状态：设计稿
适用范围：规则策略、LLM 策略、强模式、headless benchmark、UI 对战

## 1. 背景

当前 AI 策略已经形成两条执行路径：

- 规则版卡组通过 `DeckStrategy*.gd` 给合法动作打分。
- LLM 版卡组通过 `DeckStrategyLLMRuntimeBase.gd` 构造 prompt、接收决策树、编译队列、桥接交互，并在失败时回退到规则版。

这两条路径都在变强，但仍然反复出现同一类问题：

- 能量贴错对象，例如多龙喷火龙第一回合把火能贴给吉雉鸡或玛纳霏。
- 能量贴错属性，例如多龙 ex 已有火能仍继续贴火，实际缺超能。
- 能量超额浪费，例如洛奇亚已经满足 4 任意能量仍继续堆能。
- 特殊例外处理不稳定，例如厄诡椪既是自身攻击手，又可能是猛雷鼓的草能弹药库。
- 攻击技能选择不稳定，例如多龙 ex 能用 2 技却用 1 技，洛奇亚 V 有 1 技抽牌窗口但运行时错误插入撤退。
- 进化主线和能量主线没有统一理解，例如小多龙身上的火/超是给未来多龙 ex 用的，而不是只看当前小多龙的攻击费用。

这些不是单个卡组的局部 bug。根因是：AI 当前缺少一层公共的战术语义建模。很多人类会自然先想清楚的中间结论，现在散落在 deck-local 分数、LLM prompt、candidate route、runtime repair、interaction fallback 中。

本文设计首批三个公共 Planner：

- `AttackIntentPlanner`
- `EnergyIntentPlanner`
- `EvolutionIntentPlanner`

目标不是让公共层取代卡组策略，而是让规则版和 LLM 版都消费同一套结构化事实，减少每套牌重复写补丁。

## 2. 核心目标

### 2.1 要解决什么

公共 Planner 要回答这些问题：

- 当前哪个攻击最值得作为回合终端？
- 当前攻击是否只是低价值 fallback、抽牌、蓄力、资源透支，还是主输出？
- 当前这张能量贴给谁最有边际价值？
- 这次贴能是为了当前攻击、下回合攻击、进化后攻击、撤退，还是完全浪费？
- 当前是否应该继续铺第二条进化线，而不是做出一个打手就停止展开？
- 当前搜索、加速、进化、攻击之间，是否形成一条闭环路线？

### 2.2 不要解决什么

首批 Planner 不直接做完整 turn planning，不直接替代：

- `DeckStrategy*.gd` 的卡组战术偏好。
- `LLMRouteCandidateBuilder.gd` 的路线构建。
- `LLMInteractionIntentBridge.gd` 的具体交互选择。
- MCTS 或训练模型。

它们先提供事实、约束、边际价值和候选意图，让现有路径消费。

### 2.3 成功标准

短期成功标准：

- 明显错误被公共层挡住，不再需要每套牌各写一次。
- LLM prompt 中出现稳定的 `attack_intents`、`energy_intents`、`evolution_intents`。
- 规则版打分能使用同一套 facts 给动作加分/降分。
- 交互桥接能用同一套 facts 选择能量、搜索目标、加速目标。

中期成功标准：

- 洛奇亚、猛雷鼓、多龙、喷火龙、沙奈朵等卡组的能量分配错误减少。
- LLM 不再靠长 prompt 猜“这张能量为什么要贴这里”。
- 新卡组 LLM 化时，卡组层只声明角色和例外，不重写整套能量/攻击逻辑。

## 3. 总体架构

建议新增一个公共协调器和三个 Planner：

```text
GameState + legal_actions + deck_strategy profile
        |
        v
AIIntentPlannerCoordinator
        |
        +-- AttackIntentPlanner
        +-- EvolutionIntentPlanner
        +-- EnergyIntentPlanner
        |
        v
AIIntentFacts
        |
        +-- DeckStrategy*.gd score_action_absolute()
        +-- DeckStrategy*.gd pick_interaction_items()
        +-- AIStepResolver / AIOpponent
        +-- LLMTurnPlanPromptBuilder.turn_tactical_facts
        +-- LLMRouteCandidateBuilder.candidate_routes
        +-- DeckStrategyLLMRuntimeBase queue repair and end_turn replacement
```

公共 Planner 的输出只是一份 facts，不直接执行动作。

执行路径仍然保持现有架构：

```text
规则版：
legal_actions -> strategy score -> choose action
                    ^
                    |
             AIIntentFacts

LLM 版：
legal_actions + AIIntentFacts -> prompt -> decision_tree -> route compile -> queue execute
                                    ^
                                    |
                             same AIIntentFacts
```

## 4. 设计原则

### 4.1 公共层负责通用推导

公共层应该自动从卡牌 JSON 和当前场面推导：

- 攻击费用。
- 当前附着能量。
- 缺哪些属性。
- 哪些能量已经超额。
- 攻击伤害和 KO 阈值。
- 攻击是否抽牌、弃手、加速、换位、狙击后排、缩放伤害。
- 当前是否有 deck-out 风险。
- 当前进化链是否可推进。

### 4.2 卡组层只声明角色和例外

卡组层不应该为每张卡写完整逻辑，但需要提供 profile：

- 主攻击手。
- 副攻击手。
- 支援宝可梦。
- 进化线。
- 能量银行。
- 特殊缩放攻击。
- 特殊加速手段。
- 低价值或高风险技能。
- 对局特定优先级。

例如：

```gdscript
func get_intent_planner_profile() -> Dictionary:
    return {
        "primary_attackers": ["Lugia VSTAR", "Cinccino"],
        "evolution_lines": [
            {"basic": "Lugia V", "stages": ["Lugia VSTAR"], "role": "engine_owner"},
            {"basic": "Minccino", "stages": ["Cinccino"], "role": "scaling_attacker"}
        ],
        "energy_banks": [],
        "scaling_attackers": [
            {
                "pokemon": "Cinccino",
                "attack": "Special Roll",
                "scales_with": "attached_special_energy_count",
                "damage_per_unit": 70
            }
        ],
        "support_only": ["Lumineon V", "Fezandipiti ex", "Radiant Greninja"],
        "setup_draw_attacks": ["Read the Wind"]
    }
```

### 4.3 Facts 先观察，后影响

迁移必须分阶段：

1. 先只生成 facts 和日志，不改变行为。
2. 再加入明显错误的硬防错。
3. 再进入规则打分和 LLM route。
4. 最后再减少 deck-local 补丁。

避免一口气替换所有策略导致胜率回退。

### 4.4 规则版和 LLM 版必须共用

公共 Planner 不是 LLM prompt 工具。它必须同时服务：

- 规则版动作打分。
- LLM prompt facts。
- LLM candidate routes。
- 交互选择。
- runtime repair。
- trace/debug。

否则规则版和 LLM 版会继续走两套理解。

## 5. 公共数据契约

### 5.1 顶层输出

建议统一输出：

```json
{
  "attack_intents": [],
  "energy_intents": [],
  "evolution_intents": [],
  "route_hints": [],
  "hard_blocks": [],
  "soft_penalties": [],
  "audit": {}
}
```

### 5.2 AttackIntent

```json
{
  "action_id": "attack:1:幻影潜袭",
  "pokemon_position": "active",
  "pokemon_name": "Dragapult ex",
  "attack_name": "幻影潜袭",
  "attack_index": 1,
  "role": "primary_damage",
  "ready_now": true,
  "unlock_cost": ["R", "P"],
  "missing_cost": [],
  "estimated_damage": 200,
  "bench_damage": 60,
  "ko_active": false,
  "ko_bench_targets": [
    {"position": "bench_1", "hp_remaining": 60, "damage_to_place": 60}
  ],
  "terminal_priority": "high",
  "can_replace_end_turn": true,
  "blocked_by_better_attack": false,
  "deck_draw_risk": false,
  "reason": "primary attack ready and creates active pressure plus bench damage"
}
```

### 5.3 EnergyIntent

```json
{
  "action_id": "attach_energy:c22:active",
  "source": "manual_attach",
  "energy_name": "Fire Energy",
  "energy_symbol": "R",
  "target_position": "active",
  "target_name": "Dreepy",
  "target_role": "future_primary_attacker",
  "serves_attack": "Dragapult ex 幻影潜袭",
  "serves_stage": "Dragapult ex",
  "current_attached": {},
  "desired_energy": {"R": 1, "P": 1},
  "missing_before": ["R", "P"],
  "missing_after": ["P"],
  "is_overfill": false,
  "is_wrong_attribute": false,
  "is_support_padding": false,
  "marginal_value": "high",
  "reason": "Dreepy evolves into Dragapult ex and Fire is one required Phantom Dive cost"
}
```

### 5.4 EvolutionIntent

```json
{
  "action_id": "evolve:c18:bench_0",
  "from": "Drakloak",
  "to": "Dragapult ex",
  "line": "Dreepy -> Drakloak -> Dragapult ex",
  "role": "primary_attacker",
  "board_need": "first_primary_attacker",
  "attack_after_evolve": {
    "attack_name": "幻影潜袭",
    "missing_cost": ["P"],
    "ready_after_known_attach": true
  },
  "priority": "high",
  "reason": "first Dragapult ex is needed and can pressure immediately after energy completion"
}
```

## 6. AttackIntentPlanner

### 6.1 职责

`AttackIntentPlanner` 负责判断攻击的战术角色和终端价值。

它不直接选攻击，但必须输出：

- 每个合法攻击的角色。
- 当前最优攻击。
- 是否有高压攻击已经 ready。
- 低价值攻击是否应该被压制。
- 哪些未来攻击能通过当前可见 setup 变成 ready。
- 是否允许攻击替代 queued `end_turn`。

### 6.2 攻击角色分类

建议初始分类：

| role | 含义 | 例子 |
|---|---|---|
| `primary_damage` | 主输出攻击 | 多龙 ex 幻影潜袭，洛奇亚 VSTAR 220 |
| `finisher` | 拿奖或终结游戏攻击 | Boss 后 KO 残血 |
| `scaling_damage` | 额外资源继续提升伤害 | 奇诺栗鼠 Special Roll |
| `setup_draw_attack` | 低伤害或无伤害，但能抽牌/弃牌 setup | 洛奇亚 V Read the Wind |
| `desperation_redraw` | 高风险重抽，通常只能兜底 | 猛雷鼓 1 技丢整手抽 6 |
| `fallback_chip` | 没有更好路线时的小伤害 | 多龙 ex 70，小多龙 10 |
| `lock_or_control` | 控制型攻击 | 诅咒娃娃物品封锁 |
| `self_risk` | 自伤/自爆/丢大量资源 | 黑夜魔灵自爆不是攻击但同类风险 |

### 6.3 关键场景

#### 场景 A：洛奇亚 V 1 技

洛奇亚 V 的 1 技不是普通主攻击。它应该被识别为：

```json
{
  "role": "setup_draw_attack",
  "can_replace_end_turn": true,
  "conditions": [
    "deck_count_safe",
    "no_high_pressure_attack_ready",
    "main_engine_not_completed_or_hand_needs_setup"
  ]
}
```

这能解决刚才的场景：

- LLM 队列：`attach Double Turbo -> end_turn`
- 执行后：洛奇亚 V 1 技可用
- 公共 Planner 判断：可以用 1 技丢 1 抽 3，而不是插入无意义撤退

这个逻辑不应该写成 Lugia 专用 if。公共语义是：setup draw attack 在安全条件下可替代 end turn。

#### 场景 B：猛雷鼓 1 技

猛雷鼓 1 技丢整手抽 6，应识别为：

```json
{
  "role": "desperation_redraw",
  "terminal_priority": "low",
  "discard_entire_hand": true,
  "can_replace_end_turn": false,
  "allowed_only_if": [
    "hand_quality_low",
    "no_productive_setup",
    "primary_attack_not_reachable",
    "deck_count_safe"
  ]
}
```

它不能像洛奇亚 V 1 技一样宽松，因为代价不同。

#### 场景 C：多龙 ex 1 技 vs 2 技

多龙 ex：

- 1 技 70 是 fallback chip。
- 2 技 200 + 后排 60 是 primary damage。

如果 2 技 ready，1 技必须被压制。

```json
{
  "attack_name": "喷射头击",
  "role": "fallback_chip",
  "blocked_by_better_attack": true
}
```

#### 场景 D：奇诺栗鼠缩放攻击

奇诺栗鼠不是“满足最低费用就停止”。它的攻击应该输出 damage curve：

```json
{
  "role": "scaling_damage",
  "scaling_resource": "attached_special_energy_count",
  "damage_per_unit": 70,
  "current_damage": 210,
  "next_damage": 280,
  "useful_breakpoints": [210, 280, 330, 350]
}
```

公共层要理解：额外特殊能量是否有价值，取决于当前或下回合目标 HP，而不是只看攻击费用。

### 6.4 实现建议

新增文件：

- `scripts/ai/AIIntentAttackPlanner.gd`

主要方法：

```gdscript
func build_attack_intents(
    game_state: GameState,
    player_index: int,
    legal_actions: Array,
    profile: Dictionary = {}
) -> Array[Dictionary]
```

内部推导来源：

- `legal_actions` 中的 attack / granted_attack。
- `CardData.attacks` 的 cost、damage、text。
- 当前双方 active / bench HP。
- deck profile 的 role overrides。
- 已有 `get_attack_preview_damage()` 可用时优先使用真实 preview。

## 7. EnergyIntentPlanner

### 7.1 职责

`EnergyIntentPlanner` 负责判断每个贴能、加速、能量交互目标的边际价值。

它要覆盖：

- 手贴。
- 发电机。
- 奥琳博士。
- 始祖大鸟。
- 喷火龙 ex 特性。
- 厄诡椪特性。
- 沙奈朵超能拥抱。
- 能量搜索后的 future attach。

### 7.2 核心判断

每个能量分配要判断：

- 是否补齐当前攻击。
- 是否补齐下回合攻击。
- 是否服务进化后攻击。
- 是否帮助撤退。
- 是否超过合理上限。
- 是否贴给支援宝可梦。
- 是否贴错属性。
- 是否是特殊能量银行或弹药库。

### 7.3 能量需求模型

不能只使用 “attack cost length”。需要分成：

```text
unlock_cost: 启动攻击的最低费用
required_symbols: 必须满足的属性
colorless_slots: 任意能量槽
scaling_value: 额外能量是否继续提升攻击或战术价值
retreat_value: 是否服务撤退
future_stage_cost: 进化后的需求
```

### 7.4 关键场景

#### 场景 A：多龙 ex 火+超

如果小多龙或多龙 ex 已有火能，再贴第二火通常是错的。

正确 facts：

```json
{
  "target_name": "Dreepy",
  "future_stage": "Dragapult ex",
  "desired_energy": {"R": 1, "P": 1},
  "attached": {"R": 1},
  "candidate_energy": "R",
  "is_overfill": true,
  "missing_after": ["P"],
  "hard_block_reason": "second Fire does not advance Phantom Dive while Psychic is missing"
}
```

#### 场景 B：洛奇亚前期和后期阶段切换

前期 Archeops 未上线：

```json
{
  "battle_phase": "pre_archeops_online",
  "preferred_energy_target": "Lugia V",
  "reason": "Lugia V/VSTAR is the shell owner and early pressure carrier"
}
```

后期 Archeops 上线：

```json
{
  "battle_phase": "post_archeops_online",
  "preferred_energy_target": "Cinccino",
  "reason": "Cinccino scales with Special Energy and reaches KO breakpoints"
}
```

这不是“洛奇亚最多 4 能”的固定规则。它是阶段、攻击计划、伤害阈值共同决定。

#### 场景 C：洛奇亚超额能量

洛奇亚 VSTAR 4 任意能量攻击。第 5、第 6 能通常是 padding，除非：

- 需要支付撤退。
- 需要 Jet Energy 换位。
- 有工具或特殊效果明确收益。
- 当前能量转移/保护策略需要。

否则应该标记：

```json
{
  "is_overfill": true,
  "marginal_value": "low",
  "soft_penalty": -500,
  "reason": "Lugia VSTAR already satisfies Tempest Dive cost; extra Energy does not change prize math"
}
```

#### 场景 D：厄诡椪是特殊能量银行

厄诡椪不能用普通攻击费用上限限制。

卡组 profile 应声明：

```json
{
  "energy_banks": [
    {
      "pokemon": "Teal Mask Ogerpon ex",
      "energy": "G",
      "serves": "Raging Bolt ex burst damage",
      "max_reasonable_energy": "dynamic_by_burst_damage"
    }
  ]
}
```

公共层根据猛雷鼓当前爆发伤害需求判断草能是否继续有价值。

### 7.5 实现建议

新增文件：

- `scripts/ai/AIIntentEnergyPlanner.gd`

主要方法：

```gdscript
func build_energy_intents(
    game_state: GameState,
    player_index: int,
    legal_actions: Array,
    attack_intents: Array,
    evolution_intents: Array,
    profile: Dictionary = {}
) -> Array[Dictionary]
```

应提供辅助 API：

```gdscript
func score_energy_assignment(
    source_card: CardInstance,
    target_slot: PokemonSlot,
    context: Dictionary
) -> Dictionary

func best_energy_targets_for_interaction(
    candidate_energy: Array,
    candidate_targets: Array,
    context: Dictionary
) -> Array[Dictionary]
```

用于 `pick_interaction_items()`、`score_interaction_target()`、`AIStepResolver`。

## 8. EvolutionIntentPlanner

### 8.1 职责

`EvolutionIntentPlanner` 负责判断进化线推进和场面连续性。

它要回答：

- 当前是否缺第一只主打手。
- 是否需要第二只备用打手。
- 当前 Rare Candy 是否有效。
- 当前直接进化是否比继续铺基础种更重要。
- 当前是否应该保留一阶引擎，例如 Drakloak 抽牌。
- 当前进化后能量是否已经或即将满足攻击。

### 8.2 关键场景

#### 场景 A：做出一个打手后仍要铺第二线

很多规则卡组共性问题是：

```text
第一只打手成型 -> 直接攻击 -> 不再铺第二只
```

公共 facts 应明确：

```json
{
  "line": "Dreepy -> Drakloak -> Dragapult ex",
  "field_ready_count": 1,
  "desired_ready_count": 2,
  "needs_backup_seed": true,
  "safe_before_attack": true,
  "reason": "Miraidon can gust/KO the first Stage 2; second Dreepy keeps continuity"
}
```

#### 场景 B：Rare Candy 不是看到就用

Rare Candy 应该结合：

- 是否能做出主 Stage 2。
- 是否会消耗唯一基础种。
- 是否进化后能攻击或稳定局面。
- 是否应该保留给更关键二阶。

#### 场景 C：多龙奇是否保留

多龙奇可能既是进化中间件，也是抽牌引擎。

公共层不能简单“能进化就进化”。卡组 profile 应声明：

```json
{
  "stage1_engine": [
    {"pokemon": "Drakloak", "ability": "侦察指令", "keep_one_if_possible": true}
  ]
}
```

### 8.3 实现建议

新增文件：

- `scripts/ai/AIIntentEvolutionPlanner.gd`

主要方法：

```gdscript
func build_evolution_intents(
    game_state: GameState,
    player_index: int,
    legal_actions: Array,
    profile: Dictionary = {}
) -> Array[Dictionary]
```

需要 profile 提供：

- evolution lines。
- desired counts。
- stage1 engine exception。
- primary / secondary attacker roles。
- setup priority。

## 9. Deck Profile 设计

### 9.1 为什么需要 profile

公共层能从卡牌 JSON 读攻击费用和文本，但无法可靠知道：

- 哪条进化线是这套牌主线。
- 哪些支援宝可梦完全不该贴能。
- 哪些攻击虽然文本像抽牌，但在本套牌是关键 setup。
- 哪些宝可梦是能量银行。
- 哪个缩放攻击是核心输出。

所以卡组层必须提供轻量 profile。

### 9.2 建议接口

在 `DeckStrategyBase.gd` 新增可选 hook：

```gdscript
func get_intent_planner_profile() -> Dictionary:
    return {}
```

LLM wrapper 默认委托 rules strategy：

```gdscript
func get_intent_planner_profile() -> Dictionary:
    return _rules.call("get_intent_planner_profile") if _rules.has_method("get_intent_planner_profile") else {}
```

### 9.3 Profile 结构

```json
{
  "primary_attackers": [],
  "secondary_attackers": [],
  "support_only": [],
  "pivot_only": [],
  "evolution_lines": [],
  "stage1_engine": [],
  "energy_banks": [],
  "scaling_attackers": [],
  "setup_draw_attacks": [],
  "desperation_redraw_attacks": [],
  "low_value_attacks": [],
  "high_value_control_attacks": [],
  "energy_accelerators": [],
  "deck_phase_rules": []
}
```

### 9.4 原则

Profile 是声明式，不写动作选择逻辑。

可以声明：

```json
{"pokemon": "Teal Mask Ogerpon ex", "role": "energy_bank"}
```

不应该写：

```text
if hand_has_3_grass and active_is_raging_bolt then use ability first
```

后者属于 Planner + route builder 的职责。

## 10. 接入点

### 10.1 Prompt Builder

文件：`scripts/ai/LLMTurnPlanPromptBuilder.gd`

新增：

```json
"intent_facts": {
  "attack_intents": [],
  "energy_intents": [],
  "evolution_intents": []
}
```

也可以逐步合并进现有 `turn_tactical_facts`，但建议先独立输出，便于日志比对。

### 10.2 Route Candidate Builder

文件：`scripts/ai/LLMRouteCandidateBuilder.gd`

使用 Planner facts 生成：

- `route:attack_now`
- `route:setup_draw_attack_before_end`
- `route:manual_attach_to_primary_attack`
- `route:manual_attach_for_future_stage`
- `route:energy_acceleration_to_scaling_attacker`
- `route:evolve_to_primary_attacker`
- `route:continuity_setup_before_attack`

### 10.3 Runtime Base

文件：`scripts/ai/DeckStrategyLLMRuntimeBase.gd`

使用 Planner facts 判断：

- queued `end_turn` 是否可被 attack 替代。
- queued `end_turn` 是否可被 setup 替代。
- 是否阻止 low-value attack。
- 是否阻止 energy overfill。
- 是否允许 replan。

重点：不要把 deck-specific 逻辑继续写在 runtime base。runtime base 只消费 facts。

### 10.4 Rule Strategy

文件：`scripts/ai/DeckStrategy*.gd`

规则版应通过统一 helper 使用 facts：

```gdscript
var facts := AIIntentPlannerCoordinator.build_facts(game_state, player_index, legal_actions, get_intent_planner_profile())
var adjustment := AIIntentScoring.score_action_adjustment(action, facts)
```

先只做明显错误的降分：

- 支援宝可梦无撤退需求贴能。
- 过量贴能。
- 错属性贴能。
- 有高压主攻击却选择 fallback chip。

### 10.5 Interaction Bridge

文件：

- `scripts/ai/LLMInteractionIntentBridge.gd`
- `scripts/ai/AIStepResolver.gd`

使用 `energy_intents` 处理：

- 始祖大鸟选哪两张特殊能量，贴给谁。
- 奥琳博士贴什么属性给哪个古代宝可梦。
- 喷火龙 ex 三个火能怎么分。
- 发电机命中雷能后给谁。
- 厄诡椪从手牌贴哪张草能。

## 11. 低风险迁移计划

### Phase 0：只做文档和测试场景

产出：

- 本文档。
- 选定 8 到 12 个 focused scenario。

不改行为。

### Phase 1：Observe-only facts

新增 Planner 文件和 coordinator。

只做：

- 生成 facts。
- 写入 trace / audit。
- 写入 LLM prompt。

不参与打分。

验收：

- focused tests 验证 facts 正确。
- UI/LLM 日志能看到 facts。

### Phase 2：硬性防错

只拦明显错误：

- 多龙 ex 缺超时继续贴第二火。
- 洛奇亚 VSTAR 满 4 能后继续 padding。
- 支援宝可梦无撤退需求贴能。
- 多龙 ex 2 技 ready 时用 1 技。
- deck 低时使用危险抽牌攻击。

验收：

- focused tests 覆盖每个错误。
- 规则版和 LLM 版脚本加载回归。

### Phase 3：规则打分接入

给 `DeckStrategyBase` 或 helper 提供统一 adjustment。

只做软加分/降分，不完全接管。

验收：

- 单卡组 focused tests。
- 小规模 matchup smoke。

### Phase 4：LLM route 接入

让 route builder 使用 facts 生成高质量路线。

验收：

- prompt payload 中 route 能覆盖人类可见路线。
- audit 中 route id 被选择并正确 materialize。
- queue consumption 完整。

### Phase 5：删除重复 deck-local 补丁

等公共 Planner 事实稳定后，逐步删除 deck wrapper 中重复逻辑。

原则：

- 先保留旧补丁和新 facts 同时运行。
- 日志确认行为一致后再删除。
- 每删除一个补丁必须有 focused test。

## 12. 首批验收场景

### 12.1 洛奇亚

场景 1：洛奇亚 V 贴 DTE 后可用 1 技抽牌。

期望：

- `AttackIntentPlanner` 标记 Read the Wind 为 `setup_draw_attack`。
- deck count safe 时 `can_replace_end_turn=true`。
- 不插入 retreat 到未成型备战洛奇亚 V。

场景 2：Archeops 未上线时，能量优先给 Lugia V / VSTAR。

期望：

- battle phase 为 `pre_archeops_online`。
- Lugia 是主能量目标。

场景 3：Archeops 上线后，特殊能量优先给 Cinccino 达到 KO 阈值。

期望：

- battle phase 为 `post_archeops_online`。
- Cinccino scaling damage curve 正确。
- 填到当前目标 KO 阈值后停止。

场景 4：Lugia VSTAR 已有 4 能时不继续 padding。

期望：

- 第 5 能标记为 overfill。
- 除非有明确撤退/Jet/保护理由，否则降分或阻止。

### 12.2 多龙

场景 5：多龙 ex 已有火能，缺超能。

期望：

- 第二火能被标记为 overfill/wrong_attribute。
- 超能被标记为 high marginal value。

场景 6：多龙 ex 2 技 ready。

期望：

- 1 技 70 被标记为 fallback chip。
- 2 技 200 + 后排 60 被标记为 primary damage。
- 1 技被压制。

场景 7：第一只多龙已成型但只有一条线。

期望：

- EvolutionIntent 标记 `needs_backup_seed=true`。
- route builder 插入安全铺第二只小多龙的路线。

### 12.3 猛雷鼓

场景 8：厄诡椪手牌有草能。

期望：

- 厄诡椪不是按自身攻击费用硬限制。
- 如果猛雷鼓 burst 需要更多弹药，草能继续有价值。

场景 9：猛雷鼓 1 技 ready，但主攻击可达。

期望：

- 1 技为 `desperation_redraw`。
- 主攻击可达时禁止优先使用。

### 12.4 喷火龙

场景 10：喷火龙 ex 特性填 3 火。

期望：

- 喷火龙自身最多只拿满足攻击的火能。
- 多余火能给第二打手或撤退 pivot，而不是堆到已满足费用的喷火龙身上。

### 12.5 通用支援宝可梦

场景 11：玛纳霏、洛托姆、吉雉鸡在备战区。

期望：

- 无撤退需求时不贴能。
- 如果在 active 且能量能支付撤退进入 ready attacker，则允许。

## 13. 风险和边界

### 13.1 文本解析不能无限泛化

PTCG 卡牌文本复杂，不能指望公共层从任意中文文本百分百理解所有攻击。

解决：

- 优先用 effect_id / card tags / existing effect implementation。
- 对常见模式做模板识别。
- 卡组 profile 提供声明式 override。
- 不用自然语言 prompt 代替执行逻辑。

### 13.2 不要让 Planner 变成第二套 deck strategy

Planner 输出 facts，不应该直接写“本回合必须做 A -> B -> C”。

路线仍由：

- route builder。
- deck strategy。
- LLM decision tree。
- runtime compiler。

共同完成。

### 13.3 名称匹配要谨慎

`Lugia V` 和 `Lugia VSTAR` 这类名称包含关系会误伤。

要求：

- 需要进化阶段或 exact name 时必须使用精确匹配。
- fuzzy matching 只能用于搜索文本和本地化兜底。

### 13.4 Deck-specific 例外仍然必要

完全无 profile 的公共层只能做保守判断。

例如：

- 厄诡椪能量银行。
- 沙奈朵超能拥抱扣血。
- 奇诺栗鼠特殊能量缩放。
- 黑夜魔灵自爆补刀。

这些都需要 profile 声明。

## 14. 建议文件结构

新增：

```text
scripts/ai/intent/
  AIIntentPlannerCoordinator.gd
  AIIntentAttackPlanner.gd
  AIIntentEnergyPlanner.gd
  AIIntentEvolutionPlanner.gd
  AIIntentProfileDefaults.gd
  AIIntentScoring.gd
```

新增测试：

```text
tests/ai_intent/
  test_attack_intent_planner.gd
  test_energy_intent_planner.gd
  test_evolution_intent_planner.gd
  test_intent_planner_integration.gd
```

逐步接入：

```text
scripts/ai/DeckStrategyBase.gd
scripts/ai/LLMTurnPlanPromptBuilder.gd
scripts/ai/LLMRouteCandidateBuilder.gd
scripts/ai/DeckStrategyLLMRuntimeBase.gd
scripts/ai/LLMInteractionIntentBridge.gd
scripts/ai/AIStepResolver.gd
scripts/ai/AIOpponent.gd
```

## 15. 实施顺序建议

首批只做三个 Planner，但顺序要务实：

1. `AttackIntentPlanner`
2. `EnergyIntentPlanner`
3. `EvolutionIntentPlanner`

理由：

- Attack 最容易验证，能直接修技能选择和 end_turn 替代。
- Energy 影响最大，但依赖 Attack 的攻击需求和伤害阈值。
- Evolution 最复杂，需要结合铺场连续性和未来能量需求。

每个 Planner 都按 observe-only -> hard guard -> scoring -> route 四步走。

## 16. 第一轮开发交付定义

第一轮不追求全卡组完美。交付应包括：

- 三个 Planner 的基础实现。
- `get_intent_planner_profile()` hook。
- LLM payload 中输出 `intent_facts`。
- 规则路径能通过 helper 读取 facts。
- 至少 11 个 focused tests 覆盖本文场景。
- Lugia / Dragapult / Raging Bolt / Charizard 四类高频问题至少各有一个通过用例。
- 不改变无关卡组胜率路径，除明显错误 guard 外不做强接管。

## 17. 最终判断

公共 Planner 是当前 AI 架构继续提升的必要层。

继续靠 deck-local 补丁会有两个问题：

- 每套牌都会重复修“能量、攻击、进化”三类共性 bug。
- LLM prompt 会越来越长，但仍然缺少可执行的结构化事实。

正确方向是：

```text
卡组层声明角色和例外
公共 Planner 生成战术语义 facts
规则策略和 LLM 策略共同消费
执行层用 facts 防错和桥接
测试用场景确保 facts 与人类判断一致
```

这套设计落地后，规则版和 LLM 版都会受益。更重要的是，后续每套卡组不再从零开始理解能量、攻击、进化，而是在统一语义层上表达自己的卡组特性。
