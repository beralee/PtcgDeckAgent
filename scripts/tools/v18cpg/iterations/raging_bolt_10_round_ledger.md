# 800018509 猛雷鼓厄诡椪 V18CPG：10 轮验收台账

日期：2026-07-19
架构：V18CPG（clean-room conditional policy graph）
模型：`deepseek-v4-flash`
对手：rules-only 密勒顿（deck `575720`）
单轮 runner：`run_pilot_benchmark.tscn`，同 seed、交替 tracked seat、`max_steps=220`
强度保留规则：同轮 paired 胜负不得退化；失败/脚本错误产物作废且不计轮次。

## Round 0 冻结基线

- 种子：`181820, 181821`。
- Rule：1/2；V18CPG：1/2。
- 新 regret/switch 门控下模型调用 0，逐局胜负与 rule 相同。
- 结论：这是“规则地板成立、尚无模型收益”的起点；旧的 18-call 报告不再作为本次基线。
- 证据：`tmp/v18cpg/raging_round00_baseline.json`。

## 十轮记录

| 轮次 | 最早责任层 / 失败 | 先行确定性 fixture | 最小接受改动 | paired seeds | Rule | V18CPG | 调用（接收/拒绝） | branch / uncovered | 探索 wait p50/p95 | 结论 |
|---:|---|---|---|---|---:|---:|---:|---:|---:|---|
| 1 | `model_selection_error`：新门控过严，零调用也零收益 | 10 场景基础 energy-burst suite | typed profile；只在 250 分 consideration band 内开放模型，switch gap 75 | 181820–181821 | 1/2 | 1/2 | 2 (2/0) | 1 / 3 | 6897/6897 ms | 保留；非退化且有真实模型路径 |
| 2 | `policy_graph_error`：旧 profile 自由字段被白名单过滤 | typed strategic-priority contract | 将 priority 改为注册 goal、fact guard、prefer/avoid route、preserve role | 181820–181821 | 1/2 | 1/2 | 4 (2/2) | 0 / 3 | 6571/6571 ms | 保留；1 route-validation、1 schema fallback 均安全降级 |
| 3 | `semantic_gap`：能力模块以本地化卡名识别引擎 | 同 effect id、任意显示名必须同结果 | 决策分支只读 semantic role / stable effect id；删除中英卡名判断 | 181820–181821 | 1/2 | 1/2 | 4 (4/0) | 1 / 3 | 6310/6475 ms | 保留；本地化无关、零 fallback |
| 4 | `fact_or_solver_error`：未绑定 gust 目标却用当前出战 HP 声称可 KO | bound/unbound gust target 双 fixture | 未绑定目标标成 `gust_target_unresolved`；只有可见 stable slot target 才计算 KO | 181820–181821 | 1/2 | 1/2 | 4 (4/0) | 1 / 3 | 5998/6868 ms | 保留；阻止虚假 prize closeout |
| 5 | `outcome_or_threat_error`：事实正确但模型缺少可执行结论 | payable KO 必须输出 typed decision hint | 输出 `commit_minimum_resource_ko`、`skip_optional_information`、`preserve_next_attacker_continuity` 等枚举 hint | 181820–181821 | 1/2 | 1/2 | 4 (4/0) | 1 / 3 | 6286/6958 ms | 保留；模型不再自行反推能量事实 |
| 6 | `fact_or_solver_error`：共享 deck-low 固定 8，与 profile 阈值 10 不一致 | 10 张 low、11 张非 low | 共享 FactBuilder 读取 profile safety 阈值；模块同阈值阻断可选抽牌 | 181822–181823 | 1/2 | 1/2 | 3 (2/1) | 0 / 0 | 6001/7277 ms | 保留；1 次 deckout safety route-validation |
| 7 | `fact_or_solver_error`：未知/空目标的 discard plan 被标成 payable | target HP=0 必须不可支付 | `discard_plan.payable` 要求目标 HP>0 | 181824–181825 | 2/2 | 2/2 | 5 (5/0) | 2 / 1 | 6167/6722 ms | 保留；两局均胜且零 fallback |
| 8 | `semantic_gap`：特殊能量被计入只能弃基本能量的 burst fuel | L+F+特殊能量只算 2 个 basic fuel | 分离 `total_attached` 与 `total_basic_attached`；弃能上限只用 basic | 181826–181827 | 1/2 | 1/2 | 6 (4/2) | 1 / 0 | 6930/7332 ms | 保留；2 次高风险路线被 validation 拒绝 |
| 9 | `fact_or_solver_error`：攻击费用错误地跨两只宝可梦拼接 | active L + bench F 必须未就绪 | 分离 active typed-energy counts 与 board totals | 181828–181829 | 1/2 | 1/2 | 2 (2/0) | 0 / 3 | 6115/6115 ms | 保留；2 次调用、零 fallback |
| 10 | `semantic_gap`：担心 profile 非默认 reserve 键静默回落默认值 | reserve=3、五能量时 max-safe-discard 必须为 2 | 将下一攻击手总能量储备提高至 3，并锁定键消费契约 | 181830–181831 | 1/2 | 1/2 | 2 (2/0) | 1 / 2 | 6527/6527 ms | 保留；逐局同胜负 |

说明：第 3 轮第一次执行期间共享 Noctowl 文件有 parse error，runner 仍错误地产出了 0-call JSON；该产物被覆盖，未计入轮次。上表 wait 来自旧聚合器，仅作为并发探索证据；共享 runner 已在本批之后修正，正式延迟由主线程顺序复跑。

## 最终连续 10 seeds 探索 A/B

证据：`tmp/v18cpg/raging_final_n10.json`

- Seeds：`181820..181829`，交替 tracked seat。
- Rule：6/10（60%）；V18CPG：6/10（60%）；paired delta `0pp`；bootstrap 95% `[0, 0]`。
- 逐 seed 胜负 10/10 完全相同；没有胜局转败，也没有败局转胜。
- Clean：Rule 10/10，V18CPG 10/10；0 crash、0 stall、0 timeout、0 action cap。
- 20 次模型调用（2.0/game）；16 接收、4 拒绝，acceptance 80%。
- Fallback：4 次 `route_validation`；其中 2 次 `deckout_margin_blocks_search`、2 次 `model_route_below_switch_margin`；0 schema fallback。
- Policy graph branch hits：5；uncovered events：7。
- Audit ownership events：`local_gate=588`、`model_selected_local_route=32`、`policy_graph_branch=10`。
- 报告中的探索 wait p50/p95 为 5814/6118 ms，但旧聚合器不是正式口径；单局曾出现 18111 ms request p95，必须由修复后的 runner 顺序复跑。
- 两个 loss 形态值得继续关注：seed 181822 双方都 deck-out；seed 181821 的 V18CPG 比 rule 多 2 回合/6 步仍未翻盘。

## 最终判断

这 10 轮证明了该卡组的 V18CPG 能保持 rule 强度地板、显著减少无价值模型调用，并修复能量/目标/低牌库语义错误；但当前数据没有证明策略更优。状态应保持 `experimental/benchmarked`，不能 promoted。

下一阶段的最早缺口是 `frontier_gap`：frontier 每类只保留一个 action，模型无法比较同类动作中的不同附能目标、不同 supporter/道具和不同 gust 目标。只继续调 profile 不足以翻转败局；应先扩展 typed same-category alternatives 和 energy-discard interaction ownership，再做至少 100 局 paired pilot。
