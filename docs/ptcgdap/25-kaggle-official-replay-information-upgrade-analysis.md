# Kaggle/CABT 官方录像对比与 PtcgDAP 录像信息升级分析

状态：`analysis only / no runtime code changed`  
复核日期：2026-08-23  
范围：官方 Kaggle/CABT episode、官方 visualizer payload、PtcgDAP 公开录像、开发者审计日志与本地完整录像  
结论等级：字段与真实样本对比已完成；远程 `ptcgvis` 的未开源界面行为不作推测

本轮交付边界：只复核证据并整理本文，没有修改 recorder、loader、BattleScene、公开录像合同或任何运行时代码。第 16 节记录的是本轮开始前已经存在的 D092 文件诊断实现，不是本轮代码交付。

## 1. 执行结论

当前 PtcgDAP 录像的主要短板已经不是牌桌画面，而是“为什么会走到这个画面”的证据不足。

官方 CABT/Kaggle 录像在一盘结束后同时保留两类视角：

1. 供录像渲染使用的全局状态，包括双方完整手牌、牌库顺序、奖赏卡身份和临时查看区；
2. 当步行动 Agent 实际收到的 observation、当前 `select`、有序合法 `option`、返回的 action index、结构化 logs、奖励、状态和剩余时间。

PtcgDAP 的本地 `detail.jsonl` 已经记录完整牌面快照、双方区域卡牌、卡牌详细属性、场上附着物、状态与一部分 `choice_context`。这部分信息量并不弱于官方录像，且现有 BattleScene 的卡图、场景和区域交互明显比 Kaggle 默认 canvas 更适合玩家观看。

真正的缺口分成两类：

- **已经记录但没有呈现**：`choice_context`、回合使用标志、完整结构化 action data、临时效果上下文、卡牌稳定身份、终局原因等在文件中存在，但当前回放时间线只装载 `state_snapshot` 和最近一条 `action_resolved`，操作日志又主要退化为描述文本。
- **没有形成可验证记录**：每个决策窗口的精确 policy observation、完整合法选项及字段存在性、同窗口选中的 index、窗口/观察 hash 绑定、每席位 action/status/reward/timeout、结构化引擎事件、决策失败与 fallback 证据仍不完整。

因此升级方向不应是复制 Kaggle 的简易牌桌，而应保留现有 BattleScene，补上一层可审计的信息系统：

`原生完整录像主记录 -> 视角投影 -> BattleScene 播放 -> 决策/事件/终局信息面板`

同时必须继续分离：

- 本地私有完整录像；
- 固定玩家视角录像；
- 可分享公开录像；
- 本地开发者决策轨迹。

官方 omniscient visualizer 中的对手手牌、牌库顺序和奖赏卡身份不得直接进入 PtcgDAP 公开录像。

## 2. 对比对象与证据边界

### 2.1 “官方录像”实际由三层组成

| 层 | 内容 | 本文如何使用 |
|---|---|---|
| Kaggle episode | `configuration`、`info`、`rewards`、`statuses`、逐席位 `observation/action/reward/status` | 作为比赛结果、Agent 输入输出和故障语义的官方基线 |
| CABT visualizer payload | `current`、`obs`、`select`、`selected`、`logs`、`action`、`ver` | 作为录像可用信息上限；其中 `current` 是赛后全局状态，`obs` 是行动方真实可见状态 |
| Kaggle 默认 canvas / 外部 ptcgvis | 默认 canvas 绘制场上、手牌、区域计数、胜负，并可把 visualizer payload 提交给外部 ptcgvis | 只采用仓库内可验证行为；不臆测外部 ptcgvis 未开源界面显示了哪些面板 |

官方适配器在对局结束时调用 `visualize_data()`，把每帧行动方 `obs` 和下一步两席位 `action` 绑定到 visualizer frame，并主动移除 `search_begin_input`。相关实现见只读官方源 `D:\ai\code\ptcgabc\docs\official\external\kaggle_cabt.py:90-106`。Bench 默认剪枝同样移除 `visualize` 和 `search_begin_input`，说明 exact replay 与可分享轨迹本来就是不同产物，见 `D:\ai\code\ptcgabc\league\runner.py:528-543`。

可公开复核的官方入口：

- [Kaggle 比赛说明与 CABT Agent 接口](https://www.kaggle.com/competitions/pokemon-tcg-ai-battle/overview/how-to-submit-to-this-competition)：Agent 接收 observation、公开牌面与合法 option，返回 option indexes；
- [Kaggle Staff：Official Visualiser/Replay Viewer](https://www.kaggle.com/competitions/pokemon-tcg-ai-battle/discussion/713051)：比赛 Game History 的 `Open Visualiser` 与主办方本地 JSON notebook 是官方录像入口；
- [主办方本地 JSON 录像 notebook](https://www.kaggle.com/code/kiyotah/how-to-output-local-battle-as-json-and-view)：用于导出本地对局并交给官方 viewer；
- [CABT API 文档](https://matsuoinstitute.github.io/cabt/api.html)：定义 `Observation`、`SelectData`、`Option`、`Log`、稳定 ID/serial 与结构化事件字段；
- [Kaggle CLI simulation episode 文档](https://github.com/Kaggle/kaggle-cli/blob/main/docs/simulation_competitions.md)：说明 episode/replay 的获取与比赛历史工作流。

官方默认 renderer 的仓库内实现只明确绘制胜负、stadium、active、bench、双方手牌以及 deck/discard/prize 数量，并把完整 visualizer payload POST 到 `ptcgvis.heroz.jp`。因此本文把“payload 中可用的信息”和“默认 canvas 已画出的信息”分开列示；不会把外部 `ptcgvis` 未开源面板的可能行为写成已验证事实。

### 2.2 本次抽查的真实官方 episode

| Episode | 大小 | steps / visualizer frames | 结果 | 取样价值 |
|---|---:|---:|---|---|
| `88807159` | 279,907 B | 17 / 16 | `DONE / DONE`，reward `[-1, 1]` | 短局；验证初始化、终局和基础字段 |
| `92095005` | 8,237,855 B | 260 / 259 | `DONE / DONE`，reward `[1, -1]` | 正常长局；覆盖多数选择与事件类型 |
| `89833675` | 37,475,769 B | 1045 / 1043 | `DONE / TIMEOUT`，reward `[1, null]` | 异常终止；验证超时和不完整终局证据 |

SHA-256：

- `88807159`: `DDF84A0B2ABDA37D3F46F7676C4E82C085020E2620B3BE72954845D5A097B22A`
- `92095005`: `E9016B4BAC59E2AAF9E7AF3E5BD58CF6CCAD803A7193F350F9898ECF9B1FD750`
- `89833675`: `154254C6CDE06A3682C74A61E75658459A3330D822CB9054DC7FDC21782BF4C4`

样本位于只读参考仓库 `D:\ai\code\ptcgabc\artifacts\online_episodes\`。本次没有重新模拟、改写或上传这些录像。

### 2.3 PtcgDAP 对照样本

公开录像使用两盘本地作者策略实战：

| Replay | 帧数 | 决策轨迹引用 | 终局 |
|---|---:|---:|---|
| `community-windows-player-1787327494-60015249` | 195 | 0 | seat 0 胜，turn 22 |
| `community-windows-player-1787328666-14541100` | 153 | 0 | seat 0 胜，turn 18 |

公开 artifact SHA-256 分别为：

- `A6D932C096A1A7600AB3B3A2DA6B5F18182135DE0D7712D74EF3CBDBDBA02AF8`
- `09EB8946F135BF367100203334CB9193567F947AFA8640D12ECFBD333C17C7DD`

本地原生录像取样：

- `match_20260809_153147_162118/detail.jsonl`
- 5,333,967 B
- SHA-256 `19F9EB02D0F4F1A3AC0581FC0D614D261AF944AAB6372801A5425A21C9570DDF`
- 120 条事件：60 `state_snapshot`、38 `action_resolved`、20 `choice_context`、1 `match_started`、1 `match_ended`

## 3. 官方录像实际具备的信息

### 3.1 比赛与终局层

官方 episode 顶层保留：

- Episode ID、双方 Agent/队伍、module/schema/version；
- seed、`actTimeout`、`runTimeout`、最大 episode steps；
- 每席位 reward、`DONE`/`TIMEOUT` 等 status；
- 每一步的 seat action、observation、reward 和 status；
- `remainingOverageTime`，并由默认 renderer 注入 visualizer payload。

这意味着官方录像不仅回答“谁赢了”，还回答“是否正常结束、谁超时、当时还剩多少时间、哪一步之后状态变坏”。第三个样本的 `DONE / TIMEOUT` 是当前 PtcgDAP UI 信息层最缺失的一类实战证据。

### 3.2 牌面状态层

官方 visualizer `current` 包含：

- 当前回合、行动方、先手、结果、stadium；
- 双方 active/bench 的卡牌 ID、名称、serial、HP/max HP、能量、能量卡、工具、进化前身；
- 双方手牌、牌库、弃牌区和奖赏卡；
- `energyAttached`、`supporterPlayed`、`stadiumPlayed`、`retreated` 等回合标志；
- `looking` / `lookingCount`，用于呈现搜索、查看或揭示中的临时卡牌。

对 1,318 个实际 visualizer frame 的抽查表明：`current` 中双方 hand 和 deck 都是完整身份列表，prize 身份也通常可见。因此它是**赛后全局/私有录像状态**，不是可直接公开的 player observation。

### 3.3 决策层

每个行动帧还保留当时 Agent 的 `obs`：

- own hand 身份可见；
- opponent hand 隐藏；
- 双方 deck 顺序隐藏；
- prize 使用空占位，不暴露身份；
- 当前 `select` 及其 `type/context/contextCard/effect/deck/minCount/maxCount/remainDamageCounter/remainEnergyCost`；
- 有序 `option` 列表；实际样本覆盖 `area/attackId/count/energyIndex/inPlayArea/inPlayIndex/index/number/playerIndex/type` 等稀疏字段；
- `selected` index 列表和两席位下一步 action。

这是官方录像最值得吸收的部分：观众或 Agent 可以精确回答“当时有哪些合法选择”“实际选择的是第几个”“这个选择是否来自同一个 observation/window”。

### 3.4 结构化事件层

实际样本中的 `logs` 不是纯文本，而是带稳定字段的事件。覆盖类型包括：

`Attach`、`Attack`、`Coin`、`Draw`、`Evolve`、`HasBasicPokemon`、`HpChange`、`MoveCard`、`Play`、`Result`、`Shuffle`、`Switch`、`TurnStart`、`TurnEnd`。

事件可携带 card ID/serial、attack ID、来源/目标区域、active/bench/target serial、伤害指示物、硬币结果、失败原因和值。它可以支持搜索、过滤、定位首个分歧和自动构造回归 fixture；纯中文描述文本做不到这些。

## 4. PtcgDAP 当前三层录像现状

| 层 | 当前记录 | 当前优点 | 当前主要缺口 |
|---|---|---|---|
| 公开 replay artifact | `frames + manifest + match_envelope`；帧含 acting seat、turn/phase/event kind、公开 board/cards/zone counts、hash chain | 隐私边界明确、不可变 hash chain、可远程验证 | 两盘真实录像都没有 decision trace 引用；没有合法窗口、选择、结构化事件、结果故障和计时 |
| 开发者 author audit | start、public action、累计 owner step、finish；含 policy call/success/error、fallback 和 engine commit 汇总 | 能判断 owner 是否健康、是否出现错误/拒绝 | 只有累计健康指标和动作描述，不能重建每次 policy 输入、候选、选择和首个策略分歧；记录自身无 hash chain |
| 本地原生 `detail.jsonl` | 完整 state snapshot、action resolved、choice context、match start/end | 双方区域完整、卡牌属性丰富、能恢复 BattleScene；具备本地私有 exact-state 基础 | 没有统一 decision-window/selected-index 证据；异常、计时和策略轨迹未形成统一合同；每条记录无 hash chain |
| 当前 BattleScene 回放 | 从固定玩家视角恢复 state snapshot；前后帧、播放/暂停、倍速、退出；动作动画和描述日志 | 真正复用游戏对战场景、卡图、区域交互和现有动画 | 时间线忽略 `choice_context`；日志主要是 description；缺少决策、事件过滤、元数据、终局/故障和视角说明面板 |

公开帧构造位置见 `scripts/ai/ptcgdap/platform/replay/PublicReplayCapture.gd:187-198`。本地完整快照已记录回合标志和 lost zone 等信息，见 `scripts/ui/battle/BattleRecordingController.gd:137-183`。但播放装载器只接受 `state_snapshot`，见 `scripts/engine/BattleReplaySnapshotLoader.gd:19-37`；BattleScene 加载后只按附着 action 重建描述日志，见 `scenes/battle/runtime/BattleSceneSetupEffectAiRuntime.gd:2406-2457`。

## 5. 信息差异矩阵

符号：`有` = 已形成可使用记录；`部分` = 有相关数据但不完整或未绑定；`无` = 对照样本/当前合同中不存在；`隐藏` = 按视角正确隐藏。

| 信息项 | 官方 episode / visualizer | PtcgDAP 公开录像 | PtcgDAP 本地完整记录 | 当前 BattleScene 呈现 | 升级判断 |
|---|---|---|---|---|---|
| Episode/match、版本、双方身份 | 有 | 部分 | 部分 | 部分 | 应补固定录像头与版本信息 |
| reward、seat status、timeout | 有 | 终局有限 | 终局有限 | 弱 | P0，必须能区分正常胜负与异常结束 |
| seed、timeout 配置、步数上限 | 有 | 无 | 未形成固定合同 | 无 | 私有 manifest 保存；公开只给必要承诺/版本，不泄露私密 RNG |
| 回合、行动方、先手、phase | 有 | 有 | 有 | 有 | 已基本覆盖 |
| Active/bench、HP、能量、工具、状态 | 有 | 公开摘要 | 有 | 有，但细节入口不统一 | 保留现有 BattleScene，补 tooltip/详情状态 |
| own hand | acting `obs` 有 | 公开策略决定 | 有 | 固定玩家视角有 | 已有基础，需明确视角标签 |
| opponent hand | `obs` 隐藏；global `current` 有 | 隐藏 | 私有主记录有 | 固定玩家视角隐藏 | 行为正确；仅本地开发者全知模式可选显示 |
| deck order / face-down prize identity | `obs` 隐藏；global `current` 有 | 隐藏 | 私有主记录有 | deck 已隐藏；prize 呈现需继续按牌背约束 | 严禁进入公开投影 |
| discard / lost zone 完整身份 | discard 有；lost zone 取决于引擎模型 | 公开摘要 | 两者有 | 现有区域入口可复用 | 补按帧可检索列表和区域转移历史 |
| 回合使用标志 | 有 | 无 | 有 | 未集中呈现 | P1，显示能量/支援者/竞技场/撤退/VSTAR 使用状态 |
| 临时 `looking` / reveal 区 | 有 | 无 | 效果数据部分存在但无统一生命周期 | 无专门回放呈现 | P2，搜索/查看/揭示过程应成为短暂 overlay |
| 结构化 logs | 有 | 无 | action data 部分 | 文本描述为主 | P1，建立稳定事件类型与过滤器 |
| 当前 policy observation | 有 | 无 | 无统一快照 | 无 | P0（开发者轨迹），是 Agent 迭代基础 |
| select 语义、min/max、context/effect | 有 | 无 | `choice_context` 部分 | 被 loader 丢弃 | P0，必须呈现并与状态帧绑定 |
| 有序合法 option 全字段 | 有 | 无 | prompt items 部分，非统一合法 frontier | 无 | P0，记录字段存在性、fingerprint 和顺序 |
| selected index 与同窗口绑定 | 有 | 无 | 实际样本不足 | 无 | P0，必须有 observation/window hash 证据 |
| 每席位 action | 有 | 无 | action resolved 部分 | 最近 action 动画/文本 | P1，保留原始 index 与语义化展示 |
| 剩余时间、决策耗时 | 有 | 无 | 无统一合同 | 无 | P1，至少展示超时席位和每步耗时 |
| 卡牌/攻击稳定 ID 与 serial | 有 | public card 表达有限 | 本地 printing UID、instance ID 丰富 | UI 主要名称/卡图 | P1，详情层显示稳定身份，不用本地化名称做关联 |
| 每帧/每事件完整性 | episode 文件级；Bench 可精确重放校验 | 有 frame hash chain | `detail.jsonl` 无 record hash chain | 不显示验证状态 | P0，私有录像也应有 manifest/root/capabilities |
| 策略 rationale、候选分数、fallback 原因 | 官方基础录像也不保证 | 无 | author audit 仅累计 | 无 | 单独 developer trace；不能伪装成官方 replay 字段 |

## 6. 已记录但当前播放器没有呈现的内容

这部分应优先利用，不需要先扩大私有快照范围。

1. **决策提示上下文**：实际原生样本有 20 条 `choice_context`，包含 prompt type、source、title、items 和 extra data；当前 loader 全部跳过。
2. **回合资源状态**：能量、支援者、竞技场、撤退、VSTAR 等是否已使用已经存在于 snapshot，但缺少统一、只读的回放状态栏。
3. **结构化动作 data**：`action_resolved` 除描述外有 action type、player、turn 和 data；当前主要显示本地化 description。
4. **稳定卡牌与实例身份**：本地 snapshot 有 `set_code + card_index` printing UID、instance ID、卡牌完整文本、攻击、特性、弱点、抗性、撤退、进化栈；播放器未把它们组织成按帧可查询证据。
5. **弃牌区、lost zone 和场上附着细节**：底层恢复数据存在，现有 BattleScene 区域 UI 可以继续复用，但需验证每个历史帧的点击结果来自该帧 snapshot，而不是当前全局缓存。
6. **终局原因和完整 match meta**：文件有 winner/win reason/start/end 信息，播放器缺少清晰的固定比赛头和终局卡片。

## 7. 当前没有充分记录、不能靠 UI 补出来的内容

这些信息必须由未来 recorder/decision owner 在事件发生时记录，回放端不能事后推断或重新模拟。

1. 每次调用 policy 时的**精确公开 observation**及 canonical hash；
2. 同一 observation 生成的 immutable select window ID；
3. option 的完整稀疏字段、字段存在性、排序和 fingerprint；
4. policy 返回的原始 index list、清洗/拒绝/fallback 结果和最终被 engine 接受的 index；
5. observation hash、window ID、option fingerprint、execution ticket 与 action resolved 的完整绑定；
6. 每席位 action/reward/status、timeout/error/dirty termination；
7. Draw/MoveCard/Shuffle/Coin/HpChange 等结构化、稳定身份事件；
8. 搜索/查看/揭示的临时 `looking` 生命周期；
9. 每步决策耗时、剩余时间、预算降级原因；
10. 私有原生录像的逐记录 hash chain、最终 root、schema/runtime/policy/catalog manifest。

若这些字段当时没有记录，录像 UI 必须显示“该旧录像不具备此能力”，不得用新版引擎重演或根据前后 snapshot 猜测。

## 8. 绝不能照搬到公开录像的信息

官方 visualizer `current` 是赛后全局状态，并不等于行动 Agent 当时可见的信息。以下内容只能留在本地私有主记录，或者经过显式授权在本地开发者全知模式中显示：

- 对手隐藏手牌身份；
- 双方牌库身份和顺序；
- 未公开的奖赏卡身份；
- 私有随机状态、未承诺的 seed 和内部 effect 状态；
- 官方 `search_begin_input` 或任何可执行搜索 capability；
- engine object、callback、mutable ticket、Godot 对象引用；
- 私有策略权重、未公开 rationale 或训练 oracle 身份。

其中 `search_begin_input` 在官方 Kaggle visualizer 生成时就被移除，PtcgDAP 不应把它当成“官方录像有，所以也要保留”的字段。

## 9. 建议的信息架构

### 9.1 四种产物，不再让一种录像承担所有职责

| 产物 | 保存内容 | 默认受众 | Authority |
|---|---|---|---|
| Native replay master | 完整本地赛后状态、结构化事件、决策绑定、manifest/hash chain | 本机玩家/开发者 | 只读证据，无执行权限 |
| Player-view projection | 固定 seat 的可见状态、公开事件、该 seat 当时决策 | 普通录像播放器 | 只读；不能接手、分支或重演 |
| Public share replay | allow-list 公开状态、公开结构化事件、可公开决策摘要、完整 hash chain | 社区/远程服务 | 非权威、无 engine/ticket/callback |
| Developer decision trace | policy observation、window/options、selected、scores/rationale/fallback/latency | 本地策略迭代 Agent | 诊断证据；与 public replay 分库存储 |

这四种产物通过 `match_id + step/decision id + observation/window hash` 关联，而不是互相嵌套私有 payload。

### 9.2 播放器建议保留一个 BattleScene，增加三种只读视图

1. **玩家视角（默认）**：固定到录像入口选择的 seat；隐藏信息规则与当时一致。
2. **公开视角**：只显示 public projection，明确“公开录像 / 非官方 / 无执行权限”。
3. **本地开发者全知视角（可选）**：只允许本地 private master；显著标记“包含隐藏信息，不可分享”。

任何视角切换都只改变 projection，不改变原始记录，不调用 engine，不重新计算合法性。

### 9.3 BattleScene 上新增的信息区域

不建议重新套一个独立牌桌壳。建议在现有对战场景上增加：

- 顶部固定比赛头：双方、版本、录像类型、视角、回合/帧、终局/异常状态；
- 决策检查器：prompt、min/max、context/effect、合法选项、实际选择、fallback/拒绝；
- 结构化事件时间线：按事件类型、玩家、区域和卡牌过滤；
- 回合状态条：能量、支援者、竞技场、撤退、VSTAR 等已用标志；
- 临时 reveal/looking overlay：只在对应事件区间出现；
- 卡牌/动作详情：稳定 ID、serial/instance、来源/目标区域和效果上下文；
- 终局卡：胜者、原因、reward/status、timeout/error、录像完整性验证结果。

旧录像缺字段时使用能力标签，例如“无决策窗口”“无结构化事件”“无计时证据”，不显示伪造空数据。

## 10. 升级优先级

### P0：先保证录像可解释、可验证且不泄密

1. 定义 native replay manifest、schema/runtime/policy/catalog identity、capability flags 和逐记录 hash chain；
2. 记录并绑定 exact policy observation、window、options、selected indexes、engine acceptance；
3. 固定 player/public/private projection 和隐藏信息测试；
4. 记录 `DONE/TIMEOUT/ERROR/dirty`、winner/reason/reward/status；
5. 旧录像继续播放，缺失能力必须显式标记。

### P1：让人和 Agent 能定位“第一处错误决策”

1. 决策检查器；
2. 结构化事件类型与动作/卡牌稳定身份；
3. 每步耗时、剩余时间和 fallback/engine rejection；
4. 回合使用标志、状态、附件和进化栈详情；
5. 公开录像可选绑定经过 firewall 的 decision summary 或独立 trace hash。

### P2：补齐复杂效果和检索体验

1. `looking` / search / reveal 生命周期；
2. 按卡牌、区域、事件、回合和玩家搜索；
3. 从时间线定位到对应 BattleScene 帧；
4. 终局与异常路径专题视图。

### P3：策略迭代增强，不混入基础录像合同

1. 候选分数、策略目标、宏计划、fallback 原因；
2. 两个 policy/version 的同一决策对比；
3. 首个分歧自动定位和 red fixture 导出；
4. 失败类别、机会成本和可复现测试建议。

P3 必须是独立开发者 trace。Kaggle 官方录像本身也不保证策略 rationale，因此不能把缺少 rationale 误判为录像兼容问题。

## 11. 建议的数据合同轮廓（仅分析，不是本轮实现）

后续可采用 additive v2，而不是破坏现有 v1：

| 合同 | 最低字段职责 |
|---|---|
| `native_replay_manifest_v2` | match/schema/runtime/policy/catalog/version、seat、projection capabilities、record count、hash root、terminal status |
| `replay_state_frame_v2` | step/frame/turn/phase/acting seat、state projection、previous hash、关联 event/decision IDs |
| `decision_window_record_v1` | public observation hash、window ID、select type/context/effect/min/max、options+fingerprints、raw/accepted indexes、result/fallback/latency |
| `structured_battle_event_v1` | event type、actor、card/attack/serial、source/target area、value/result/reason、关联 frame/decision |
| `replay_projection_profile_v1` | `player_private` / `public_share` / `developer_omniscient` 的 allow-list 和禁止字段 |
| `replay_terminal_v1` | reward、seat status、winner/reason、timeout/error、dirty/incomplete、最后完整记录 hash |

这些合同应引用现有 PtcgDAP raw observation、select-window、public firewall 和 identity 合同，不另造一套按名称匹配的录像身份系统。

## 12. 测试驱动验收建议

后续真正实现时应先写失败测试，再改 recorder/loader/UI。最低验收如下：

### 12.1 精确性

- 每个 decision record 都能从同一 observation/window 验证 option 顺序和 selected index；
- accepted selection 后旧 window 失效，下一决策必须有新 observation/window；
- action resolved 精确关联到选中的语义目标，不能只靠 description；
- seek 前进、后退、倍速和随机跳帧得到同一 snapshot hash；
- 旧录像不会因新字段缺失崩溃。

### 12.2 隐私

- player/public projection 对 opponent hand、deck order、face-down prizes 做负面 golden 测试；
- `search_begin_input`、私有 RNG、runtime object 和策略私有字段全仓录像扫描为 0；
- developer omniscient 录像不能进入 public upload；
- public artifact 仍保持 `engine/ticket/callback invocations = 0`。

### 12.3 异常与完整性

- 正常胜负、投降、超时、Agent error、非法输出 fallback、engine rejection、dirty/incomplete 各有 fixture；
- 修改任一 record、删中间记录、换 manifest 或跨对局拼接都必须 fail closed；
- partial file 能报告最后完整 hash 和缺失能力，但不能冒充完整录像。

### 12.4 呈现

- BattleScene 中双方场上、手牌可见性、区域计数、附着能量/工具、状态与 snapshot 一致；
- prompt/options/selected 与当前帧一致，不残留上一窗口；
- 结构化时间线筛选不会改变 frame/state；
- 全知/玩家/公开视角切换只改变投影；
- 横屏、窗口化和现有布局回归均不遮挡手牌及播放控制。

## 13. 建议后续工作包

本轮只产出分析，不执行下列工作：

1. **Replay-info WP0：合同与 fixture**  
   冻结官方三个 episode 和 PtcgDAP 三类录像的字段 golden；定义 capabilities、终局状态和投影负面样本。
2. **Replay-info WP1：原生记录完整性**  
   Additive manifest/hash chain/terminal/error/time；保持旧 `detail.jsonl` 可读。
3. **Replay-info WP2：决策窗口证据**  
   在 decision owner 最早层记录 observation/window/options/selected/accepted，不由 UI 反推。
4. **Replay-info WP3：结构化事件与临时查看区**  
   统一 card/attack/serial、zone transfer、coin/damage/search/reveal 生命周期。
5. **Replay-info WP4：BattleScene 信息面板**  
   复用现有牌桌和卡牌 UI，加入决策检查器、事件过滤、回合状态和终局卡。
6. **Replay-info WP5：公开投影与远程兼容**  
   从 native master 正向 allow-list 生成 public v2；继续支持 public v1 和现有服务。

## 14. 最终判断

与 Kaggle 官方录像相比，PtcgDAP 当前录像已经具备更适合玩家的游戏场景和更丰富的本地卡牌快照，但还没有把“比赛状态、Agent 观察、合法选择、实际选择、引擎结果、结构化事件、异常终局”串成一条可验证的证据链。

最有价值的升级不是增加更多文本，也不是再做一个仿官方播放器，而是：

1. 保留 BattleScene 作为唯一主视觉；
2. 把已记录的 `choice_context`、状态标志、action data 和终局信息真正呈现出来；
3. 从 decision owner 原位补录 exact observation/window/options/selected/accepted；
4. 用结构化事件替代纯描述日志；
5. 用严格 projection 同时满足玩家观看、公开分享和开发者自迭代，绝不混淆隐藏信息边界。

达到 P0+P1 后，录像才能从“能看对局经过”升级为“能定位第一处策略分歧，并为 Agent 生成可信回归输入”。当前两盘公开录像及配套 author audit 尚未达到这一水平。

## 15. 证据索引

- 官方 CABT Kaggle adapter：`D:\ai\code\ptcgabc\docs\official\external\kaggle_cabt.py`
- 官方 Bench replay 剪枝/精确重建：`D:\ai\code\ptcgabc\league\runner.py`
- 官方 Kaggle renderer：`D:\ai\code\ptcgabc\vendor\kaggle-environments\kaggle_environments\envs\cabt\visualizer\default\src\cabt_renderer.ts`
- 官方 exact review builder：`D:\ai\code\ptcgabc\tools\build_cabt_replay_review_page.py`
- PtcgDAP 公开录像客户端：`scripts/ai/ptcgdap/platform/replay/PublicReplayCapture.gd`
- PtcgDAP 公开帧捕获：`scripts/ai/ptcgdap/platform/replay/PublicReplayCapture.gd`
- PtcgDAP 原生录像快照：`scripts/ui/battle/BattleRecordingController.gd`
- PtcgDAP 原生时间线装载：`scripts/engine/BattleReplaySnapshotLoader.gd`
- PtcgDAP BattleScene 回放：`scenes/battle/runtime/BattleSceneSetupEffectAiRuntime.gd`
- Hosted replay service operations and release evidence are maintained in the
  confidential sibling worktree.

## 16. 既有实现状态回填：Replay-info WP1–WP2（非本轮代码变更）

在本分析之后，D092 已完成本地文件层第一阶段实现，且没有改动旧录像 schema 或执行 owner：

| 原分析要求 | 当前实现 | 验证结果 |
|---|---|---|
| additive native manifest/hash chain | `native_replay_manifest.json` + `detail.chain.jsonl` | 编辑/删除/重排/跨局替换 fail closed |
| exact observation/window/options/selected/accepted | 独立 `developer_decisions.jsonl`，由作者策略 owner 原位记录 | option fingerprint、policy/Base audit、fallback/error/latency 可搜索 |
| normal terminal status/reward/fault | game-over 信号当场记录 `DONE/DONE`、`+1/-1`、fault/winner/reason/turn | 完整 fixture 的 `terminal_status=available` |
| legacy compatibility | 无 manifest 即 `legacy_v1`，显式 capability gaps | 120 条 complete 与 262 条 incomplete 历史录像均可读但不可自主迭代 |
| privacy/authority | acting-policy public allow-list；trace/loader 无 engine/ticket/callback authority | 私有字段负测 fail closed；`execution_authority_granted=false` |
| cross-runtime verification | Godot 写入，Python 对 exact bytes/canonical chains 独立验真 | 完整 fixture `self_iteration_ready=true`、`capability_gaps=[]` |

这关闭的是“未来本地作者策略录像”的文件诊断子门，不追溯升级 D089 两盘公开录像，也不把经典 `VS_AI`、异常 TIMEOUT/ERROR 全枚举、公开 replay v2、UI 决策检查器或 CABT 引擎一致性标成完成。实现与审计证据见 `artifacts/ptcgdap/d091_native_replay_diagnostics/`。
