# Competitive Author Policy v2 — Host/Forge 对齐设计与实施计划

## 状态

- work package: `AS2-WP0..WP5`
- 状态：implemented / dual-runtime green / Godot engine witnessed / development-only
- 外部边界：`agent(raw_observation) -> list[int]` 不变
- 兼容：restricted adapter v1 保持原语义；v2 为新增 data-only 档
- authority：development-only，不能据此声明 official CABT parity、production 或 A5

## 决策

作者包低胜率的 owning layer 是 P4/P5 策略表达与 Godot interaction Host，不是 ZIP、签名、安装或
外部 wire。当前 owner 关闭经典 DeckStrategy 偏好，却只给作者包七字段 predicate、排序提示和
`minCount` fallback，未实现 Base Graph v1.8 oracle 的 Goal State、Threat Clock、Macro、资源债务、
future/uncertainty 和类型化交互。

AS2 采用新增 Competitive Policy IR v2，要求：

1. `list[int]` 长度表达精确合法数量，Base 不再把 v2 提案固定裁成 `minCount`；
2. setup/main/search/discard/send-out/retreat/effect/assignment/damage/optional-zero 都经过同一作者窗口；
3. assignment 每个 source→target 重新构造当前窗口，不能由通用 scorer 包外自动完成；
4. public frame 增加 target serial、公开能量、attack readiness/debt、prize value、pending allocation；
5. goal/resource/threat 只保存语义，不保存旧 index/score/proof；
6. Python/GDScript 使用同一安全整数、闭合 fact/operator 和稳定排序；
7. Base 继续拥有 legality、forced、terminal、hard tier、veto、cardinality、fallback、rebind 和 commit。

完整数据模型、官方对齐说明和验收矩阵见 Forge
`docs/11-COMPETITIVE-POLICY-IR-V2.md`；两份文档必须在 SDK snapshot 时保持语义一致。

## 官方接口映射

官方不需要新的 API：

```text
select.option + minCount/maxCount -> agent -> ordered list[int]
accepted selection -> old window invalid -> next callback/reobserve
```

精确数量是列表长度；目标分配是后续窗口。Godot local lane 可以增加公开的本地 UID overlay，但不得
改变 CABT raw envelope 或把本地 UID 冒充 official Card ID。

本实现不是凭接口名称猜测，而是复核了 `docs/ptcgdap/SOURCE_LOCK.json` 固定的官方/只读 oracle：

| 官方来源 | 固定 SHA-256 | v2 对齐点 |
|---|---|---|
| `official_data/kaggle_bundle/sample_submission/sample_submission/main.py` | `CD434298…D8367A` | 单一 agent 入口与 `list[int]` 返回，不新增方法 |
| `official_data/kaggle_bundle/sample_submission/sample_submission/cg/api.py` | `593F1298…E06CED` | select/option 与 enum 数据形状 |
| `official_data/kaggle_bundle/ptcg_engine/ptcgProgram 22/ApiJson.h` | `FA405A04…326851` | option 当前顺序和 wire serializer |
| `docs/official/external/kaggle_cabt.py` | `83966930…0D176` | CABT callback/environment 调用形态 |
| `strategy_graph/base_graph_v1_8.py` | `5D303531…CA3D2` | Goal/Threat/Macro/资源与 Base 裁决 oracle |
| `strategy_graph/base_graph_v1_8_architecture_contract.json` | `E8A010E5…EB5B9` | Base authority 顺序和 adapter 权限边界 |

`docs/ptcgdap/01-official-cabt-contract.md` 把官方输出条件固定为
`minCount <= len(result) <= maxCount`、唯一且有序的当前 option index；其“返回前 minCount 个”只是确定性安全 fallback，文档明确说明不代表最佳策略。v2 正是在同一合法区间内用策略提案决定列表长度和顺序，没有改写官方 validator 或 wire。

## 工作包

### AS2-WP0 — Design/source lock

- 固定本设计、oracle 关系、v1 兼容和 rollback；
- 不改变 live 行为。

### AS2-WP1 — RED contracts

- precise 3-of-5；
- option reorder；
- 1+2 assignment and stale rejection；
- current-energy and prize-clock metamorphic flips；
- forced/tier/veto/unknown/private negative gates；
- Python/GDScript differential.

### AS2-WP2 — Competitive evaluator/Base cardinality

- closed v2 schema and package loader union；
- public fact/goal/resource/threat compiler；
- safe-integer scorer；
- ordered indexes + desired count Base adjudication；
- v1 byte/behavior compatibility.

### AS2-WP3 — Godot interaction windows

- public frame v2 projection；
- explicit optional-zero；
- per-assignment current target window；
- target energy/readiness/prize/pending allocation；
- one accepted selection => reobserve/rebind.

### AS2-WP4 — Forge SDK/workflow

- vendored reviewed sources/contracts；
- v2 new/build/validate/simulate/test/check；
- scoring/count/assignment diagnostics；
- deterministic archive and provenance refresh.

### AS2-WP5 — Raging Bolt architecture validation

- v2 Raging Bolt package only after WP1–WP4 green；
- public scenarios then Godot paired-seed benchmark；
- safety gates zero failure；
- pre-upgrade improvement plus classic non-inferiority gate；
- no production/official claim without their independent evidence.

## Rollback

- v2 loader/runtime stays feature- and package-profile gated；
- v1 packages continue through the existing owner；
- disabling v2 affects new matches only；
- never hot-swap a running match or silently fall back to classic strategy；
- user packages remain installed and discoverable.

## Completion evidence

Completion requires executable RED→GREEN evidence, exact hashes, v1 regression, dual-runtime vectors, Godot
interaction witness, Raging Bolt paired benchmark, known gaps and rollback identity. Design or scenario-only evidence
does not close Host execution or competitive-strength goals.

## 2026-08-23 实施结果

AS2-WP1..WP5 已按上述顺序完成：

- Python/GDScript 共用闭合 v2 schema、profile、conformance vectors、safe-integer evaluator 与 Base cardinality；
- Godot Host 将 setup、main、search、discard、send-out、retreat、effect、assignment、damage 和 optional-zero 发布为 fresh author windows；
- source/target 分配逐步提交，每次成功后旧窗口失效并重新观察；
- frame 只从 allow-list 暴露目标 public serial、能量 UID/数量、最小攻击费用、ready/debt、HP、prize value、双方剩余奖赏、投影伤害/KO 和当前分配进度；
- Base 对 `projected_damage > 0` 的合法攻击增加贡献值 1 的通用执行底线，防止无 adapter 命中时把 end-turn 移到前面；该底线不能盖过任一牌组规则，零伤害效果攻击仍由 adapter 显式表达；
- v1 package profile 与旧 owner 保持原路由；v2 只对 exact-hash reviewed candidate 启用。

最终猛雷鼓包：

| 字段 | 值 |
|---|---|
| package | `dev.beralee.v18.raging-bolt-ogerpon` v1.0.0 |
| strategy | `beralee.raging-bolt-ogerpon.18.0.competitive-v2-round3` |
| archive SHA-256 | `59FB9D35BAB8987B1156714E64FB488A90432A491D42FBF8F3076E4E823ABD76` |
| policy | 4 goals / 89 rules / 10 count rules |
| Forge strict scenarios | 21/21 |
| Round 0 baseline | 100 games, 8–92, 8% |
| Round 1 | 20 games, 4–16, 20% |
| Round 2 | 10 games, 6–4, 60% |
| Round 3 final same-seed gate | 100 games, 37–63, 37%; Wilson 95% 28.18%–46.78% |
| Round 3 execution audit | 5784/5784 policy success, 4085 commits, 0 error/invalid/rejection/fallback |

固定问题种子 `91003` 的 2 局 developer trace 为 2–0、151/151 policy success、105 commits、0 rejection/invalid；11 次 `@base.positive-damage-attack` 命中，未出现公开正伤害攻击却结束回合。轨迹还实际见证 `8 选 3`、`10 选 4`、`6 选 3`，证明精确数量已在 Host/engine 路径执行，而非仅在 Forge 模拟器中存在。

最终 100 局使用与 Round 0 相同的 `seed_base=91000` 和 paired seat swap；包在 seat 0 为 21/50、seat 1 为 16/50，5 个 package sweep、18 个 classic sweep、27 个 seat split。相对 Round 0 的 8% 提升 29 个百分点，超过预注册的 +10pp 架构有效性门。

性能仍是明确的实现缺口：100 局耗时 6,962,804 ms（116.05 分钟）。固定 trace 的 151 次作者决策平均 819.5 ms、P50 721.3 ms、P95 1122.4 ms；决策累计 123.7 秒，占两局总时长 236.6 秒约 52%。代码检查确认每个窗口仍重复完整 policy schema/hash 校验、frame 深拷贝、全量 option×rule 解释执行和完整 scorecard/audit SHA；这些是开发审计实现开销，不是官方 `agent -> list[int]` 或 fresh-window 生命周期的要求。后续性能工作应保持语义不变，把 sealed policy 验证移到加载期、规则按 prompt/option 预编译分桶，并在非 trace 对局仅生成紧凑审计。

报告：

- `artifacts/deck_training/raging_v2_round3_final_trace_seed91003.json`
- `artifacts/deck_training/raging_v2_round3_final_seed91000_100.json`
- Forge `evidence/raging-bolt-competitive-v2-validation.json`

## 当前权限与已知缺口

本结果证明 Forge public-window simulation 与本地 Godot engine execution；不证明 official CABT engine parity、production approval、Android/A5 或任意外部作者包 authority。benchmark 是同牌表 package-vs-classic paired local match，置信区间只描述采样不确定性。关闭 v2 exact candidate 只影响新比赛，运行中 match 不热换 owner 或 archive。

## 2026-08-24 Phase A–D 与性能收口

旧实现的性能缺口已经关闭：`CompetitivePolicyV2` 在加载期完成 policy schema/hash/UID 验证并保存 sealed compiled execution plan；每个窗口复用 frame fact cache、frame/option 条件拆分和 option-kind 分桶。`decide_compiled(policy_hash, frame)` 只接受已封存 hash，公开 policy 副本被修改不会污染计划，未知 hash 返回 `invalid_compiled_policy`。strict 与 compiled 输出有逐结果一致性测试。

同一 seed 91003 双局从 236647 ms 降到 10958 ms（21.6×）；151 次作者决策平均 819.485 ms→26.211 ms，P95 1121.872 ms→35.668 ms。外部 `agent(raw_observation) -> list[int]`、fresh-window、Base authority 和审计字段未改变。

表达层补齐了四组能力：

1. goal route：按具体 Pokémon 的 attack/ability index 计算 acquire/deploy/fund/complete/pivot/execute；
2. typed quota 与 reserve count：按缺失能量类型选择 source，并为 variable damage 保留攻击核心；
3. 当前窗口 progress：`goal.window.max_progress` 与 setup-only progress，避免把可攻击但不完成目标的动作误作路线完成；
4. field-slot seam：`AIStepResolver` 先接收合法作者交互提案，再使用经典 scorer fallback。对手 gust 映射 `opponent_switch/attack_target`，己方强制换位映射 `self_switch/send_out`，每次仍重观察、重绑索引并由 Host 验证。

接受的猛雷鼓包回滚固定为 Round 29：

| 字段 | 值 |
|---|---|
| archive SHA-256 | `EEB7A5CE507CCB0979EEADB336EEC916E488F2E13076387983C01F49B868F451` |
| strategy | `beralee.raging-bolt-ogerpon.18.0.competitive-v2-round29` |
| policy | 9 goals / 137 rules / 10 count rules |
| Forge scenarios | 75/75 |
| seed 91000 | 9–11，45% |
| seed 93000 | 8–12，40% |
| combined | 17–23，42.5% |
| execution audit | 2470 policy success / 1656 commits / 0 error、invalid、rejection、fallback |

Round 30–32 的 Night Stretcher 回收实验虽然修复了单个轨迹，但两个开发种子均退化到 40%，已按 benchmark gate 拒绝并回滚。Round 29 也没有达到预注册 47%（相对 Round 3 正式 37% 的 +10pp）门，因此未运行 100 局正式非劣门，不能声称已达到经典策略水准。

下一阶段不改官方接口：先为 effect source 建立 typed interaction recipe，再增加公开 turn ledger（Supporter、attach、ability、bench/attacker debt）和受限 semantic route phase guard；两个独立开发种子都达到 47% 后才允许 100 局正式验证。Forge 对应设计为 `docs/12-ARCHITECTURE-UPGRADE-DESIGN-AND-PLAN.md`。

## 2026-08-24 Phase E — 整回合多路线裁决

上段“下一阶段”已被本节取代。typed interaction recipe、公开 turn ledger、bench capacity 和受限 `turn_routes` 均已实现，但 Round 41/43/44 的 fresh 100 分别为 42%/41%/40%。单点路线修复能改变一条录像，却不能稳定提升新样本，owning layer 因此升级为整回合候选路线比较。

Competitive v2 新增可选 `route_candidates`。作者数据声明 route/owner/bridge/pivot 稳定身份、公开 guard、typed resource budget、有序 current-window steps，以及：

```text
attack_windows ASC
prize_progress DESC
continuity DESC
resource_cost ASC
response_risk ASC
uncertainty ASC
route_id ASC
```

Runtime 只比较 guard、当前资源 gate 和当前 step 可执行的候选。所选 route 的第一步获得 same-tier current-window authority，但 `terminal -> mandatory -> hard tier -> veto -> cardinality -> fallback` 仍由 Base 最终裁决。commit 后旧 index/score/proof 全部失效，新窗口重新观察、重新比较、重新绑定。

Supporter、手贴、撤退和 bench slots 由公开 ledger/capacity 验证；ability/discard/search 数量当前是机会成本声明，不是未来引擎合法性证明。route value 禁止 option facts，避免重新退化为局部动作加分。

审计新增 `route_candidate_adjudication`，记录 considered routes、稳定拒绝原因、六维值、selected route/step/current indexes 和 `route_authority_applied`。Python 与 GDScript 已统一使用 CABT public tree hash；conformance vectors 同时锁定 `selected_indexes` 与 `audit_hash`。

当前合同：

```text
schema  C3835C23C62C13F0191A281302F408288F982FE70F0387B0A9D466538CF81879
profile 737CF28BF83D9CF270266B163DDFCDE03B6645D0BDE7012B54906BEE6CE723FF
vectors AEA98005727EEF0016687AB18A26E72608EDEE10697373B2E26C17ACBCF799FA
bundle  1D7864C1828CEE1965E8C1A766155A716C2FC35C7AB2206BEDE4386F42793BD7
```

focused evidence 包含资源可用性翻转、奖赏时钟/response-risk 翻转、option reorder、mandatory、terminal、hard tier、veto 和 cross-runtime audit hash；Godot competitive suite 为 17/17，250 次 compiled route decision P95 为 4.070 ms。

猛雷鼓冻结并回滚到 Round 41，archive SHA-256 `5DEEC95080A537B9BF10B4744050A2C53690486B057E556FBC11E3F55BEDA57A`。全量 Forge、Host Python、Godot route、SDK 来源锁、Round 41 competitive package 专用路径和 P95<50ms 门已关闭；按用户要求不运行新胜率 benchmark，也不声明经典非劣、official CABT engine parity 或 production authority。五包通用 owner 套件仍有既有随机 setup-option 波动，隔离运行的失败对象会变化，但 Round 41 专用 competitive owner 路径稳定通过。
