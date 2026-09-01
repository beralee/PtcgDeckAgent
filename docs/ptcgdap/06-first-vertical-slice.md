# 06 — 第一副牌纵向切片

## 1. 推荐切片：玛俐的长毛巨魔

第一副牌推荐使用“玛俐的长毛巨魔”轴。选择它不是因为可以直接复用现有策略，而是因为
Godot 与 `ptcgabc` 两侧都有较成熟的独立证据，同时其真实决策链覆盖了接口改造最容易出错的
连续选择窗口：

```text
60-card deck callback
-> setup active/bench
-> MAIN search/play/evolve/attach
-> Spikemuth deck selection
-> Punk Up: choose 0..5 energy and ordered target assignments
-> attack and bench-damage target
-> take prize
-> forced send-out
```

它能同时检验 optional multi-select、牌库授权可见性、同类能量实例、目标 serial、进化后身份
稳定、每次选择后 reobserve，以及攻击后多阶段 prompt。

## 2. 两条现状 lane，禁止按名称合并

### 2.1 官方 CABT lane

候选 canonical deck：

```text
D:\ai\code\ptcgabc\agents\marnie_raihan_graph_r121_pre_attack_phase_order\deck.csv
SHA-256: 48F1A03E8AB8162F6DC608E6743A4F3B32004CB702CA447050E62055B85DEFBF
```

这一 lane 的 60 个数值 ID、Card printing、Python Base Graph/adapter 和官方 native engine 行为是
Kaggle 端的候选权威。正式实施前仍须把其 parent/manifest、contract hash 与支持能力写入切片
manifest，不能只锁一个 deck 文件。

### 2.2 Godot lane

现有本地材料：

- `data/bundled_user/decks/800018501.json`；
- `scripts/ai/DeckStrategyV18MarnieCynthia.gd`；
- `scripts/ai/v18_cpg/profiles/800018501.json`；
- `scripts/ai/v18_cpg/profiles/generated_semantic_manifests/800018501.json`；
- `scripts/effects/pokemon_effects/AbilityMarniesGrimmsnarlPunkUp.gd`；
- `tests/test_v18_marnie_cynthia_strategy.gd`；
- `tests/v18_llm_policy_graph/test_optimize_800018501_complex_decision_scenarios.gd`；
- `tests/v18_llm_policy_graph/test_optimize_800018501_round01_attackless_second_gust_hold.gd`。

这些文件证明本地引擎/策略已有可利用的规则场景和测试思想，但它们的接口仍读取
`GameState`、`PlayerState`、`CardInstance`、`PokemonSlot` 和本地 interaction 字典；它们不是 CABT
adapter，也不是 public-only policy package。

### 2.3 强制身份结论

`800018501` 是本地 deck id，不是官方 deck identity。初始化审计已确认本地 JSON 与上述
`deck.csv` 的 Trainer/数量配置不一致，部分打印映射也需要逐张核验。因此：

- 不得因为展示名相同就把两副 60 卡视为相同；
- 不得把本地 `set_code_card_index` 当作官方数值 Card ID；
- 不得按中文名、英文名、效果文本或图片猜 printing；
- 在 60 张逐项映射、数量、效果和 deck hash 全通过前，`cabt_exportable` 必须为 `false`；
- Godot lane 可以先做 host/interface 测试，但 Kaggle lane 的 deck callback 只能返回官方
  canonical deck；
- 若需要同时保留两套列表，必须拥有两个不同 identity 和 manifest。

P2-WP2 的精确身份审计进一步量化了差距，但没有关闭 VS0：官方 lane 的 19 个唯一 Marnie Card ID 中
只有 9 个进入 exact bridge，覆盖 34/60 张；另 10 个 ID
`860,1079,1086,1122,1137,1152,1182,1219,1227,1231` 保持
known-official-but-local-unmapped，共 26/60 张。本地 `800018501` 只命中 bridge 中 4 个 exact printing、
15/60 张，45/60 未桥接，因此 `cabt_exportable=false` 不变。完整官方 master 的 1267 Card IDs / 1556
Attack IDs 只证明官方 identity domain；官方 skill payload 没有数值 Ability ID，不能据此推断 ability
identity、effect support 或两副 deck 等价。

建议官方 lane identity：

```text
cabt:marnie_grimmsnarl_froslass:48f1a03e8ab8162f
```

本地 lane identity 应由本地 60 卡 canonical serialization 的 hash 生成，不能复用上面的 identity。

## 3. 为什么不直接迁移现有 `DeckStrategyV18MarnieCynthia`

该类混合了两副牌的逻辑，且允许策略读取完整本地对象。它可作为以下内容的行为参考：

- setup 偏好；
- Marnie 进化线、Froslass/Munkidori 引擎事实；
- Spikemuth、Poffin、Rare Candy、Night Stretcher 等次序约束；
- Punk Up 能量目标与攻击准备；
- 回收、gust、prize clock 的战术样例。

但不能直接成为新 adapter，因为：

- 它拥有 raw `GameState` hidden-information 访问权；
- action 以本地对象引用和名称别名表示；
- prediction context 会持有 engine object；
- 本地 step id 和 interaction payload 不是官方 Select/Option；
- Marnie/Cynthia 共类会放大 owner 与 capability 边界；
- 旧策略中的合法行为不证明官方 option 顺序或 callback 粒度一致。

迁移方式是从公开 observation 重新表达“事实、目标、macro、constraint、scorer”，不是复制方法体。

## 4. 纵向切片目标

### 4.1 接口目标

- 初始 callback 返回官方 canonical 60 Card IDs；
- setup 到 forced send-out 的每个决策都经 `CabtSelectionWindow`；
- policy 只返回当前 option indexes；
- 当前 window 外没有可执行本地对象引用；
- logs 是 selection-to-selection 增量；
- public observation 与 trace 零隐藏信息；
- 每个动作均有 accepted/bound/executed witness；
- legacy 与 aligned owner 整局二选一；
- aligned owner 在声明的 Windows PC 与 Android 设备上本机完成完整对局，无需网络、系统 Python、
  sidecar、动态模型下载或运营方推理服务。

### 4.2 策略目标

使用 Base Graph v1.8 公共责任链：

```text
legality -> mandatory/terminal -> Strategic Context
-> goal stage -> macro intent -> proof-gated constraints
-> tactical scorer -> current-option selection -> reobserve
```

adapter 至少表达以下 typed goal stage：

- `acquire`：获取基础种、进化件、场地、能量或回收件；
- `deploy`：建立 active/bench 与进化线；
- `fund`：为当前/下一攻击手分配能量；
- `ready`：达到攻击、撤退、damage-spread 的可执行条件；
- `execute`：攻击、gust、bench damage 和 prize route；
- `maintain`：保存第二攻击手与后续资源；
- `recover`：夜间担架/钓竿等恢复关键实体。

### 4.3 非目标

- 不以 P5 为契机改写全部 Godot 卡牌规则；
- 不迁移其余 23 副牌；
- 不把 Kaggle native Search API 伪造成 Godot 功能；
- 不承诺两引擎全卡池/全随机等价；
- 不接在线 LLM、数据库、遥测或赛中下载；
- 不把普通 Android 设备能否嵌入完整 Python/PyTorch 作为生产前提；
- 不把旧 V18 CPG JSON 直接宣布为 CABT schema；
- 不以胜率提升作为接口完成证明。

## 5. Adapter 的最小语义包

建议第一版只包含明确、可审计的 public macros：

| Macro ID | 公开意图 | 主要 proof obligation |
|---|---|---|
| `marnie.engine.poffin_primary` | 用 Poffin 建立低 HP 基础种 | bench 有空位、当前 options 含合法目标、不会破坏更高优先 mandatory |
| `marnie.engine.spikemuth_tutor` | 用 Spikemuth 获取玛俐系宝可梦 | 当前 stadium 使用合法、公开手场信息证明目标缺口、在授权 deck window 重绑定 |
| `marnie.engine.evolve_grimmsnarl` | 建成长毛巨魔并触发能量引擎 | 进化合法、当前实体 serial 稳定、后续 interaction 能被 broker 表达 |
| `marnie.energy.punk_up` | 选择最多 5 个基本恶能量并分配 | source 来自授权 deck options、source 不重复、target 是公开合法的玛俐宝可梦、可选 0 |
| `marnie.prize.shadow_bullet` | 选择攻击并规划备战 30 点 | 攻击可支付、bench target 来自当前 options、prize/damage clock 只用公开信息 |
| `marnie.recover.night_stretcher` | 恢复关键宝可梦/能量 | discard identity 公开、当前 interaction 类型与数量合法、后续资源约束可证明 |

这些 macro 只产生语义意图/评分，不保存未来 index。每次进入新的 callback 都必须对当前 options
重新绑定。

## 6. 需要覆盖的窗口序列

### W0 — Initial deck

- 输入 `select=null`；
- 清空 session；
- 返回 canonical deck；
- 验证 60 张、Card IDs、hash 和 native deck legality。

### W1 — Setup active

- 对当前 basic options 评分；
- index 对应当前 official order；
- 只基于公开 initial hand；
- 不读取 prize/deck identity。

### W2 — Setup bench

- 支持 `minCount/maxCount` 多选与官方顺序；
- 不重复实体；
- 选择后 reobserve，不复用 active window index。

### W3 — MAIN 原子动作

- play trainer/stadium、evolve、attach、ability、retreat、attack/end turn 都表现为当前 option；
- Base 处理 mandatory/terminal/legality；
- adapter 只提供 public facts 与 scorer。

### W4 — Spikemuth/搜索

- `select.deck` 只在授权回调出现；
- card identity 来源于官方 option/Card ID/serial；
- 搜索前的 semantic intent 在新 window 重绑定；
- 选择完成后 logs 和牌库 count 正确，未泄漏牌库顺序。

### W5 — Punk Up 能量分配

这是本切片的核心 interaction：

- 支持 0..5 个基本恶能量；
- 同名能量用不同 serial 区分；
- 每个 source 只使用一次；
- target 只能是当前合法的玛俐宝可梦；
- 如官方协议分成多个 callback，逐 callback 重新观察，不把本地 assignment 字典直接序列化；
- 顺序和 confirm/finish 语义以官方 SelectType/Context/Option 为准；
- 结束后 shuffle/log/count 与可见性正确。

### W6 — Attack 与 bench target

- 攻击本身和附加 target 若为连续 callback，分别绑定；
- attack identity 不依赖本地数组 index 漂移；
- 对手面朝下/隐藏实体不进入候选；
- damage 结果属于 engine evidence，不反向泄露给之前的 policy。

### W7 — Prize 与 forced send-out

- prize identity 只在规则公开时出现；
- 多奖赏选择遵守 cardinality/order；
- KO 后 forced send-out 是新的 window；
- `selectMax=0` 的自动推进不伪造 Agent 回调；
- 终局没有额外 end callback，session 仍可在下局正确重置。

## 7. 工作包

### VS0 — Exact deck 与 Card printing audit

交付物：

- 官方 60 卡 canonical manifest；
- 本地 60 卡 canonical manifest；
- 逐项 diff：count、官方 ID、本地 uid、printing、效果实现、支持状态；
- deck identity 规则与 `cabt_exportable=false` 默认值；
- Marnie 切片所需 SelectType/Option/capability inventory。

退出门：没有任何 name-only 映射；两套 deck 是否相同由精确 diff 决定。

当前状态：P5-WP1 已在 P2-WP2 的完整官方 identity master 与 9 条 exact bridge 子证据上固定两份互不合并的
exact 60-card manifest、逐项 identity/count/support diff 与 10 项 capability inventory；官方 lane 覆盖 34/60，
本地 `800018501` 覆盖 15/60、仍有 45/60 未桥接并保持 `cabt_exportable=false`。因此 VS0 的 offline fixture
子门已关闭；Q002 已 resolved: yes — 仅批准 Marnie 作为首个 offline vertical slice。官方与本地 deck identity
仍不合并，10 个官方 Card ID 仍未映射；这不构成 native legality、完整 effect/engine parity、live、canary、
package/device 或 A5 声明。

D041（2026-08-13）另为作者包 Windows 首发建立本地 deck/policy identity 档：`800018501` 的 28 个游戏内 printing UID/60 张牌
已能按源 deck、逐卡 hash 和 `CardDatabase` 精确物化；候选包 adapter 的卡牌谓词也只接受 manifest 内的字符串 UID，config 绑定
exact manifest hash。它不修改上述 P5 official/local identity diff，不把两副牌合并，也不补造 10 个 official Card ID；因此只关闭
Windows-local package deck/policy validation subgate，CABT export、local UID runtime compiler、effect/engine parity、完整
W0–W7、player live 与 A5 仍未关闭。后续 local-UID public-context bundle canonical
`42706B8426968F4EB1A9C79A3EFC3828236966454013BB791D51684E5C346AAA` 已关闭 Python/GDScript shadow compiler 与逐 prompt
绑定子门：只把当前窗口 option 和行动方公开 hand/active serial 绑定到 manifest 内游戏 UID，official CABT identity/projector 不变；该子门
仍不等于 CABT export、完整 effect/engine parity、完整 W0–W7、player live 或 A5。

### VS1 — Golden trajectory skeleton

交付物：

- W0–W7 的最小官方 observation fixtures；
- 每个 fixture 的 expected option fingerprints、cardinality 和 visibility；
- 无 search token 的 public trajectory 轮廓；
- Godot private scenario 与 public fixture 的隔离映射。

退出门：每个窗口都能在不加载 raw GameState 的纯 contract runner 中解析。

当前状态：P5-WP1 已固定 13 个 source-hash/seat/step 绑定的 W0–W7 public frame；P5-WP2 又以不改 P2 base `project()` 的 exact overlay
重放全部 13 帧，在 Python/GDScript 复现 firewall/public hash/window/fingerprint/cardinality、visibility 与 ordered audit chain。W2 的 own-active
concealed placeholder 原样保留；生产 replay action 仍不是 policy golden。P5-WP3 再以双运行时 closed rule set 对 13 帧产生 same-window deterministic
audit proposal 与 exact W0 initial deck，23 个共享 case 零 mismatch/skip。VS1 的 offline fixture/replay/policy 子门关闭，但无 Host replay consumer、
serial/catalog/projector 接线或执行 authority。

### VS2 — Godot serial/catalog/projector shadow

交付物：

- 该 deck 所需 Card ID catalog；
- serial registry；
- W1–W7 shadow observation；
- sentinel 与 evolution-stability tests。

退出门：零 identity collision、零 hidden leak、零 live 行为变化。

当前状态：serial registry、CardIdCatalog、official-wire PublicObservationFirewall、pure GodotLogCursor 与
GodotObservationProjector 五个 shadow 子件已分别完成。P5-WP4 再以 13 个 source-locked frame 审计 573 个公开 identity occurrence、94 个跨帧
official serial 与 34 个 official Card ID（9 mapped/25 known-unmapped），并以一个 source-hashed Godot engine probe 重新绑定 sealed registry、exact
catalog/projector、physical-card serial 与 hidden/private 零输出。official Marnie deck 保持 9 ID/34 张 mapped、10 ID/26 张 local-unmapped；官方 replay
serial 与 Godot registry serial 不作数值等同。由此 P5-03/VS2 的 offline shadow 子门关闭。

当前 projector/attestation DTO 仍不能自行提升为 window/执行 authority；完整 W1–W7 live/headless broker、current-window binding、execution、package/device、
canary 与 engine parity 尚未完成，因此不得把 P5、P2 总门或 A0/A1–A5 记为通过。

### VS3 — Broker 与窗口绑定

交付物：

- W1–W7 `EngineDecisionWindow` adapters；
- option binding 与 ActionTicket；
- live/headless 共用的 decision broker；
- stale/reorder/replay fault tests。

P3-WP1 完成 VS3 的前置 decision-source snapshot 子门，P3-WP2 又完成 exact current snapshot/window 上的 Host-private
option binding 子门；P3-WP3 再完成 one-use ticket/claim 子门：source order、generation、fingerprint、callback 与 WeakRef identity
可重验，accepted replacement 会撤销旧 binding，ticket 最多成功 claim 一次。P5-WP5 又把 11 个 source-locked W1–W7 callback 逐项接入 fresh
window/snapshot/binding 与同一 offline `ShadowPromptBroker` lifecycle，并以 exact P5 profile 补齐 OptionType 8/12/13 的离线 source/binding 适配，W3/W6
完整 frontier 与 W2 optional-zero 均保持。但仍无 live/UI/headless 共用 owner、P5 ActionTicket/production command、真实 engine commit/executor，故完整 VS3 退出门保持未通过。

退出门：所有声明窗口只能用当前 ticket 执行，legacy flag 可整局关闭新路径。

### VS4 — Base Graph 公共核

交付物：

- `StrategicContextV18`；
- mandatory/terminal/legality/phase/fallback；
- strategic trace v2；
- adapter ownership audit。

退出门：Base 不读 private engine，adapter 无法绕过 sanitizer。

当前状态：P5-WP6 已把 16 个 public case 接入 exact firewall/window/context/restricted IR/adapter/Base policy/sanitizer/decision/trace
owner 链，13 个完成 orchestration，W0/W2/terminal 3 个明确 N/A。Base forced/tier/veto/fallback authority 保持不变，VS4 offline 子门关闭；
live Host、ActionTicket 与 engine execution 仍未实现。

### VS5 — Marnie adapter

交付物：

- 上述六个 macro 的事实、goal、constraint 与 scorer；
- public-only matchup-neutral baseline；
- interaction binder intents；
- adapter tests 只使用 CABT fixtures。

退出门：不存在 `GameState`/`CardInstance`/`PokemonSlot` 参数或 name-only action identity。

当前状态：P5-WP6 已实现六个 numeric-only public macro，并在 13 个 source-locked frame 与 3 个明确 seeded extension 中全部激活。
macro 只形成 same-tier adapter hint，不持久化 index，也不授予窗口、ticket 或执行 authority；VS5 offline 子门关闭。

### VS6 — Python/GDScript differential

交付物：

- constrained policy package；
- Python reference outputs；
- GDScript outputs；
- W0–W7 differential report；
- unknown/reorder/tie-break fixtures。

退出门：声明 portable 的节点 action/owner/trace hash 100% 一致。

当前状态：P5-WP7 已固定受限 bundle canonical
`992B7F00DF412496BA414ABCC87C21C6136CB513C9C90799C897ADD18D15EDB2`。Python/GDScript 都重新执行 exact
P5-WP3 capability-policy 与 P5-WP6 public-Base owners，再组合 13 个 source-locked W0–W7 frame：W0 initial、W2
optional-zero 与 terminal lifecycle 由 capability/lifecycle route 保留，其余 10 个 current-window action 采用 Base final
decision。28 个 shared case 对 action/node/owner/portable trace、unknown node/operation、stale/reorder binding 与 W4/W5
tie-break audit 零 mismatch/skip，因此 VS6 offline differential 子门关闭。该 bundle/audit 不授予 live window、binding、
ticket、command 或 engine execution；Godot 首次完整重算约 467 秒，只是离线 guard，不是 hot-path 或设备性能声明。

### VS7 — Shadow 与 canary

交付物：

- 双座位 shadow trajectories；
- first-divergence report；
- canary manifest 与 feature flag；
- resource report；
- rollback drill。

退出门：A0/A1 通过；如声明 A2 则 A2 通过；`0 leak/invalid/stale/error/timeout`。

### VS8 — 玩家设备本地运行

交付物：

- Marnie aligned AI 所需 contract/IR/config/catalog/weights/executor/fallback 的完整本地 manifest；
- GDScript portable baseline，以及声明 backend 的 Windows x86_64 与 Android arm64 构建；
- 独立、产品批准的 device acceptance profile 及其固定设备/资源测试协议；
- 平台包/离线内容签名、signer/trust policy 与篡改拒载证据；
- 项目自有、非 repo Skill 的 export/install/launch/offline 测试入口；
- Windows clean-install 断网完整对局与 Android clean-install 飞行模式完整对局；
- aligned AI 零 DNS/socket/HTTP/外部 Python 进程尝试的审计；
- 每个声明 OS/ABI 的 model operator/量化/数值 conformance，以及正常 lane 的
  backend/model load、invocation/output witness 与零意外 fallback；
- 冷启动、每决策延迟、峰值内存、包体与 Android 长时温度/降频/电量报告；
- backend/模型损坏、低性能和资源超限时 deterministic local aligned fallback 与回滚演练；
  如下一局切回 local legacy，必须明确撤销 A1/A2/A5 声明。

退出门：A5 通过，且该设备路径保持 A0/A1/A2 的已声明范围；远程算力不能成为任何降级路线。

### VS9 — Kaggle operational 与推广

交付物：

- `ptcgabc` 权威打包器消费的 artifact；
- isolated archive validation；
- self-play、双座位与 no-ingress/egress 证据；
- A4 报告；
- 之后才是 Bench v7 策略质量报告。

退出门：A4 通过。A3 只按已认证 Card ID 集另行声明。

## 8. 文件迁移映射

| 现有材料 | 允许复用 | 目标位置/表达 | 禁止复用 |
|---|---|---|---|
| `V18CPGObservationGateway.gd` | allow-list、visibility sentinel、stable response 思想 | `scripts/ai/ptcgdap/public/` 与 host projector | 自定义 envelope 直接冒充 CABT；本地 instance/slot action ID |
| `AILegalActionBuilder.gd` | 引擎合法动作枚举知识 | `scripts/engine/decision/` window adapter | 把 `CardInstance/PokemonSlot` 暴露给 policy |
| `AIOpponent.gd` | legacy execution 与接入点知识 | `compat/LegacyAIOpponentFacade.gd` + broker | 原地改名成 Kaggle agent |
| `DeckStrategyV18MarnieCynthia.gd` | 公开可证明的牌组事实/顺序样例 | 独立 Marnie adapter fixtures/IR | raw GameState、预测对象缓存、名称别名 action |
| `AbilityMarniesGrimmsnarlPunkUp.gd` | 本地规则与 interaction 场景 | W5 engine adapter/E-track fixtures | 本地 assignment 字典作为 CABT wire |
| V18 CPG tests | sentinel、stale、witness、路线测试思想 | `tests/ptcgdap/**` | 用旧测试通过宣称 CABT 已对齐 |
| private battle recording | engine debug/oracle | 隔离 E-track evidence | 作为 Agent observation 或 public replay |

## 9. 切片测试集

最低测试组：

1. exact 60-card and reset；
2. both-seat setup；
3. opponent hand/deck/prize sentinel；
4. authorized `select.deck`；
5. identical-energy distinct serial；
6. evolve-with-stable-serial；
7. Punk Up choose zero；
8. Punk Up choose one/five；
9. duplicate source rejection；
10. illegal non-Marnie target rejection；
11. option reorder/rebind；
12. window expires between source and target；
13. Spikemuth search then reobserve；
14. attack then bench target；
15. KO/prize/forced send-out；
16. terminal without end callback；
17. exception/timeout deterministic fallback；
18. public trajectory replay；
19. Python/GDScript golden differential；
20. legacy rollback on next match；
21. Windows clean-install、断网完整对局与零 aligned AI 网络/外部进程尝试；
22. Android arm64 clean-install、飞行模式完整对局；
23. backend/model reject 与低性能 deterministic local fallback；
24. 每个声明 OS/ABI 的 model/operator/量化 vectors 与 nominal invocation witness；
25. package/content signature trust 与 tamper rejection；
26. Android 持续对局 latency/memory/package/thermal/battery resource gate。

每个测试必须记录 contract hash、deck identity、seat 和 window id。使用本地固定开局测试时要标注
`offline_seeded_extension=true`，不得把它写成官方线上确定性保证。

## 10. No-go 条件

出现以下情况不得进入 canary：

- 官方 60 卡与本地映射仍有未解释项；
- 任一所需 selection family 沿用另一套 prompt owner；
- 策略仍能访问 raw GameState；
- Punk Up 通过未来 index 计划或本地对象直接执行；
- serial 在进化/换位后漂移或跨玩家冲突；
- public trace 包含牌库顺序、盖奖、对手手牌、private replay 或 search token；
- Base 与 adapter 对 mandatory/terminal/legality 产生双 owner；
- shadow option 顺序或增量 logs 有未解释差异；
- manifest 不能完整回滚；
- 玩家端 aligned 决策需要远程推理、运行时下载、系统 Python/sidecar，或资源不足时转远端；
- 以现有旧策略测试或胜率代替 CABT conformance。

即使 canary 已通过，当前声明的 Windows 平台尚未完成 clean-install 断网完整对局、设备资源门
和本地 fallback/rollback 演练时，也不得进入 Godot `active` 或声称 A5。Android 已按 D041 后移；未来重新声明时必须独立完成同级门。

## 11. 完成定义

首个纵向切片完成，必须同时满足：

- VS0–VS9 的相应出口全部有 evidence；
- 官方 lane 精确 deck 可提交，本地 lane 不被误标为同一 deck；
- W0–W7 端到端经过统一 CABT host/broker；
- A1 完整通过，A2 对声明 portable subset 完整通过，A4 与 A5 分别完整通过；
- A3 的支持/不支持范围被明确写出；
- 双座位 `0 invalid / 0 error / 0 timeout`；
- `0 public leak / 0 stale execution / 0 unexplained contract diff`；
- rollback drill 成功；
- `STATUS.md` 指向下一副牌或 E-track 工作，而不是笼统写“继续优化”。

阶段映射固定为：VS0–VS7 属于 P5，VS8 属于 P6，VS9 属于 P7。P5 的 canary 出口不等于整个
首切片完成；只有 P6/P7 的 A5/A4 也分别通过后，才满足本节完成定义。

## 12. 实际开工顺序

尽管本文件推荐了 Marnie 切片，当前唯一工作游标以 `STATUS.md` 为准；本文件不再复制
具体 work package 名称，避免阶段推进后形成第二个过期游标。

只有 P1、P2 的通用 contract/identity/firewall 基础通过后，才能开始 VS0/VS1。禁止新 Agent
跳过通用层，直接把 `DeckStrategyV18MarnieCynthia.gd` 接到 live broker。

P3-WP4 已完成 non-live executor preflight/commit 子门：exact claim/context 在 prepare 与 commit 两次重验，整批 resolution
只可能全部返回或零项；成功路径不调用 engine command。P3-WP5 又把 W1–W7 编排成同一 shadow broker：每个 prompt 最多一次
成功 non-live commit，下一 prompt 强制 reobserve 与全新 snapshot/window/binding。P3-WP6 又固定整局 `legacy|aligned_shadow`
owner，并把 rollback 限定为下一严格更新 match generation 的一次性 legacy 强制。P3-WP7 再增加 isolated reversible command
applier 与 private-free executed witness：它只在测试 harness 中按 capture/apply/restore 协议运行，不是 production GSM adapter。
P3-WP8 再把上述 owners 组成离线整局链，验证多 prompt 严格代际、故障后 terminal close、dirty 标记与下一严格更新 generation 的一次性
legacy rollback。首切片仍缺真实 Host command transaction、feature flag 与 canary；live owner 仍未改变。

P4-WP1 只在上述公共 Host 基础上增加 `StrategicContextV18` 与 `PolicyDecision` 的离线、双运行时合同壳：它把 exact accepted
public observation 与 exact current window 编译为 acting-player-visible context，并把 same-window selection/fallback 记录为 non-authoritative
public audit。P4-WP2 又补齐 Strategic Trace v2 与 restricted Base Graph IR 的离线合同：trace 绑定 exact context/decision/current frontier，
IR 锁定 Base authority 次序、封闭 operator/config 与 adapter proposal 边界。两包仍没有 IR executor、牌组 adapter、策略/model、W0、
live owner 或首切片 trajectory，因此不构成 VS0–VS9 任一阶段完成；只关闭 P4-01 合同项，P4-02 至 P4-06 仍未完成。
P4-WP3 又实现双运行时 restricted executor，锁定 terminal/mandatory、minimum tier、veto、same-tier adapter ordering 与 deterministic
fallback，但仍没有首副牌 adapter、策略/model、W0、live owner 或 trajectory consumer。因此它只关闭 P4-02，不构成 VS0–VS9
任一阶段完成；P4-03 至 P4-06 仍未完成。
P4-WP4 又实现语言中立 public deck adapter proposal core，锁定 7 个 goal stage、3 个 proposal operator、7 个 public numeric predicate
与 minimum-priority/source-order/current-index 排序，并证明它不能绕过 P4-WP3 Base authority。它仍没有 Marnie-specific rule document、
W0–W7 trajectory、policy/model、time-bank 或 live consumer，因此只关闭通用 P4-04，不构成 VS0–VS9 任一阶段完成；P4-03、P4-05、
P4-06 仍未完成。
P4-WP5 又把 exact context/window、restricted IR、public adapter、executor、sanitizer、PolicyDecision 与 Strategic Trace v2 串成固定七阶段
离线 orchestration，并以双运行时 shared cases 证明 Base forced/tier/veto/fallback authority、same-tier adapter 限制与 failure atomicity。
它仍没有 Marnie-specific policy/model、W0–W7 trajectory、time-budget telemetry、unsupported-capability degradation 或 live consumer，因此只关闭
P4-03/P4-05 的离线子门，不构成 VS0–VS9 任一阶段完成；P4-06 仍未完成。
P4-WP6 再增加不读时钟的 deterministic budget ledger 与 closed capability degradation：600000/30000/5000 ms 分档、required/unknown
same-window fallback、optional adapter `base_only` 和 optional learned/search 非远程 fallback 已由双运行时共享向量锁定。它关闭 P4-06 离线子门与
P4 offline pure-core chain，但仍没有 Marnie exact 60 identity/capability fixture、W0–W7 trajectory、deck-specific policy/model、Host clock、live consumer
或 package/device，因此仍不构成 VS0–VS9 任一阶段完成；下一步必须从 P5-WP1 的 exact Marnie fixture gate 开始。

P5-WP1 已完成该 fixture gate：官方 60/19 与本地 60/28 两份 identity 不合并，9 条 exact bridge 对官方覆盖 34/60、对本地
`800018501` 仅覆盖 15/60；10 项 capability 明确列出证据与 blocker，均不冒充 portable ready。13 个 exact replay/seat/step public frame
覆盖 W0–W7，并在 Python/GDScript 复现 public hash、window、fingerprint/cardinality 与 visibility；production action 不作为 policy golden。
官方 W2 setup-bench 的 own-active concealed placeholder 仍被 P2 base firewall 拒绝为 `own_active_concealed`；P5-WP2 已新增精确 scoped overlay，
仅在 official W2 shape 下接受并完成 13-frame public trajectory replay，且没有恢复隐藏身份、扩大 P2 allow-list 或使用 production action 作 policy golden。
P5-01/VS0 与 P5-02/VS1 的离线子门关闭；P5-WP3 已完成 offline capability-policy gate：W0/W1–W7/terminal 均有 closed rule、same-window legality 与
decision-hash audit，且 production action 不参与。P5-WP4 已关闭 VS2 的 identity/projector offline shadow 子门；P5-WP5 再关闭 11 个 callback 的
offline broker/current-window integration 子门，每帧 fresh rebind、non-live commit、mandatory reobserve，且不改 P3 default profile。P5-WP6 又关闭
VS4/VS5 的 public Base/macro offline 子门；P5-WP7 再关闭 VS6 的受限 artifact Python/GDScript differential 与 offline
shadow trajectory 子门。作者策略包实施随后已完成 AS-WP0 至 AS-WP5 的限定子门；当前唯一工作游标以
`STATUS.md` 的 AS-WP6 为准。完整 W0–W7 player live、production trust/approval、物理设备、A5 与 engine parity
仍须由当前及后续工作包分别关闭。
