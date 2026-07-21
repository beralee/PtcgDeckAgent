# V18CPG 三卡组十轮总体验收

日期：2026-07-19
架构：隔离的 V18CPG conditional policy graph
模型：`deepseek-v4-flash`
Rule 对手：rules-only 密勒顿，deck `575720`

## 验收口径

- 三套牌各自完成 10 轮：每轮先确定失败责任层，再增加确定性 fixture，只保留同 seed 不退化的最小改动。
- 最终 A/B 使用 seeds `181820..181829`、交替 tracked seat、`max_steps=220`；Rule 与 V18CPG 使用相同异步 runner。
- 正式结果来自最终 capability exact-set、稳定 UID 路线分类和 typed action summary 代码：`tmp/v18cpg/architect_final_typed_model_n10.json`。
- 无模型地板来自 `tmp/v18cpg/architect_final_no_model_n10.json`。
- 胜率样本只有 10 局/套；可用于 pilot 诊断，不能替代设计规定的 100 局 pilot 和 300 局 promotion。

## 最终强度

| 卡组 | Rule | V18CPG | 配对差值 | 单套 bootstrap 95% | Clean | 判定 |
|---|---:|---:|---:|---:|---:|---|
| 800018509 猛雷鼓厄诡椪 | 6/10（60%） | 6/10（60%） | 0pp | `[0, 0]` | 10/10 | 持平，未证明更强 |
| 800017643 火伊布猫头夜鹰 | 1/10（10%） | 1/10（10%） | 0pp | `[0, 0]` | 10/10 | 持平，模型覆盖不足 |
| 800015934 Tord 太晶盒 | 2/10（20%） | 3/10（30%） | +10pp | `[0pp, +30pp]` | 10/10 | 正向信号，尚未统计证明 |
| 合计 | 9/30（30.0%） | 10/30（33.3%） | +3.3pp | `[0pp, +10pp]` | 30/30 | 总体区间仍包含 0 |

没有 Rule 胜局被 V18CPG 翻成败局。唯一结果翻转发生在 Tord seed `181825`：最终 typed 版本在 turn 16 使用碧草面具厄诡椪 ex 的能力后，先把超能量附给该攻击手再攻击；Rule 直接攻击。V18CPG 最终把 31 回合败局翻成 22 回合胜局。该 seed 在 capability 裁剪前和最终 typed 版本中都由负转胜；具体动作线受模型输出影响，并非逐动作完全相同。

## Rule 地板与安全

- 关闭模型后，三套各 10 局的 outcome、turn count、step count 逐 seed 完全一致，差异 `0/30`。
- Rule 与 V18CPG 两个正式 arm 均为 30/30 clean；无 crash、stall、timeout 或 action cap。
- 核心 fixture 8 groups、猛雷鼓 10/10、火伊布猫头夜鹰 rounds 1-10、Tord rounds 1-10 全部通过。
- 生产 V18CPG 目录没有旧 `DeckStrategy*LLM` 或 Agent runtime 引用；策略仍为 experimental，feature flag 关闭，未接入 BattleSetup。
- 三个能力模块由核心测试静态 preload，模块 parse error 会直接令验收非零退出，不再允许动态加载“假绿”。

Godot benchmark 进程退出码为 0，但退出时仍打印全局 `ObjectDB/resources still in use` 清理告警；对局结果不受影响，正式 promotion 前应单独清理 runner 生命周期告警。

## 模型接管与反馈速度

| 卡组 | calls/game | 接收/拒绝 | branch / uncovered | request p50/p95 | turn visible p50/p95 | payload p50/p95 |
|---|---:|---:|---:|---:|---:|---:|
| 猛雷鼓厄诡椪 | 1.8 | 13/5 | 2 / 6 | 6157 / 6720 ms | 6157 / 6720 ms | 25.5 / 31.9 KB |
| 火伊布猫头夜鹰 | 0.2 | 2/0 | 1 / 1 | 6176 / 6623 ms | 12799 / 12799 ms | 22.6 / 24.8 KB |
| Tord 太晶盒 | 2.3 | 23/0 | 6 / 16 | 6270 / 7849 ms | 6311 / 12407 ms | 22.0 / 26.7 KB |
| 合计 | 1.43 | 38/5 | 9 / 23 | 6205 / 6855 ms | 6242 / 12407 ms | 23.5 / 30.7 KB |

猛雷鼓的 5 次拒绝全部安全回落：2 次 `deckout_margin_blocks_search`、3 次 `model_route_below_switch_margin`。火伊布猫头夜鹰仅在一局同一回合调用两次，因此 request 等待不高，但 turn-visible wait 达 12.8 秒。Tord 也存在多调用回合，turn p95 12.4 秒。当前速度不能视为 promotion 通过。

Capability exact-set 裁剪去除了非相关模块的错误提示：猛雷鼓只加载 EnergyBurst + Noctowl，火伊布只加载 Noctowl + CyclePivot，Tord 只加载 Noctowl。Tord payload 相比裁剪前诊断由约 30.4/39.2 KB 降至 22.0/26.7 KB。

## 十轮带来的有效改进

- profile override 只接受白名单 typed 字段，不允许身份、runtime、Rule owner 被覆盖。
- 战略优先级改为注册 goal、fact guard、route 和 protected role，不允许自由文本 objective/condition。
- 猛雷鼓增加最低资源 KO、基础能量与特殊能量分离、单只攻击手费用、目标绑定、下一攻击手储备和低牌库安全。
- 火伊布猫头夜鹰增加 R-W-L 连续性、Fan Call 展开顺序、Jewel Seeker 互补配对、锁定主动位换位、功能备战位预留与低牌库终止纪律。
- Tord 增加 Tera/Fan Call 门控、路线绑定成对检索、Supporter 额度、最低资源攻击、满备战、低牌库显式空选和 Energy Switch liveness。
- RouteSearch 的 Noctowl/Fan Call 分类改用 exact source UID；model-visible action summary 改为 typed kind/card UID/source UID/target/damage，不依赖中英文能力名。
- Audit 现在跨真实 wait samples 统计 request p50/p95，并独立统计 turn-visible wait、payload、fallback reasons；无调用局不再以 0ms 稀释延迟。

## 总体结论与下一步

十轮迭代达成了隔离、安全、可复验和 Rule 不退化，但没有证明三套整体显著强于 Rule。Tord 有可重复的 `+10pp` pilot 信号；猛雷鼓与火伊布猫头夜鹰仍持平。因此三套均保持 `experimental/benchmarked`，不晋级、不接 BattleSetup。

下一轮最早应修的不是继续调 prompt/profile，而是：

1. `frontier_gap`：同一 macro category 当前只保留一个动作，模型无法比较不同附能目标、Trainer、gust target。
2. interaction ownership：补 EnergyBurst 弃能数/对象、typed attachment target 和关键 Trainer 搜索选择的稳定契约。
3. coverage：火伊布的高 regret typed-energy、Fan Call、Jewel Seeker、locked-pivot 状态很少进入模型。
4. latency：同回合第二次调用必须优先命中策略图/本地 branch，降低 12 秒级 turn-visible wait。
5. evidence：修复后先跑每套 100 paired pilot，达到至少 +5pp；再跑 3 个独立批次、合计至少 300 局，要求配对区间下界高于 0 或满足预声明非劣界。
6. semantic registry：当前 deck semantic compiler 仍有基于卡名/描述的编译期角色推断；扩到 24 套前应产出 UID/effect-id 版本化 manifest，并把文本推断降为构建期告警而非正式角色来源。

## 逐套台账

- `scripts/tools/v18cpg/iterations/raging_bolt_10_round_ledger.md`
- `scripts/tools/v18cpg/iterations/flareon_noctowl_10_round_ledger.md`
- `scripts/tools/v18cpg/iterations/tord_tera_box_10_rounds.md`
