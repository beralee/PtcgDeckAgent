# Turn Program v1 方案级影子规划架构

日期：2026-08-30  
工作包：`TP-WP1`  
状态：`shadow contract and dual-runtime arbitration complete; live authority disabled`

## 1. 结论

R55 已证明 current-window turn transaction 能稳定执行搜索、进化、填能、转伤、干扰、上场和攻击提交，但 exact100 从 R54 的 `47/100` 变为 `46/100`。这说明事务本身已经能执行，事务之间仍缺少同一尺度的整回合比较；继续给单个事务叠加优先级不能保证选中的组合是更好的完整回合。

TP-WP1 在事务之上增加 `Turn Program v1`：同一公开局面可以提交多个语义化完整回合方案，Base Graph 对每个方案的当前第一步独立给出安全证明，确定性整数价值层只在 Base 放行集合中排序。胜出结果只包含 `program_id / goal_id / route_id / current_step_id`，不包含 option index，也不能执行动作。Competitive Policy v2 仅在显式传入请求时把结果写入 `turn_program_shadow` 审计；默认调用的输出树和既有哈希不变。

本工作包没有修改 R55 `.ptcgai`，没有打开 canary，没有提高 `execution_trusted`，也没有宣称胜率变化。

## 2. 最早责任层

旧链路为：

```text
public frame
  -> Base current legal frontier
  -> route/transaction local arbitration
  -> one current-window semantic transaction step
  -> Base final tier/veto
  -> selected option indexes
```

缺口不是 transaction executor，而是多个可行完整回合之间的选择。新影子链路为：

```text
public frame + exact source hashes
  -> public-only Turn Program proposals
  -> Base-owned per-program admissibility/current-step proof
  -> deterministic whole-turn outcome comparison
  -> semantic winning program (shadow only)
  -> existing Competitive Policy/Base path remains live owner
```

未来激活后，胜出 program 也只能把语义第一步交回现有 current-window 绑定器；每次 accepted selection 后必须重观察、重新生成候选、重新计算价值并重新取得 Base 证明。

## 3. 语言中立合同

Schema：`contracts/ptcgdap/turn_program_v1.schema.json`  
Conformance vectors：`contracts/ptcgdap/turn_program_v1_conformance_vectors.json`

每个 program 只包含：

- 稳定语义身份：`program_id / goal_id / route_id`；
- 有向无环且按依赖顺序排列的 `semantic_steps`；
- 每步的 `transaction_id / method_id / step_id / terminal_kind`；
- 本次公开观察下重新估计的 `public_outcome`；
- 同 turn 的语义 deadline，不是跨窗口索引租约。

公开结果向量固定为：

- `final_prize_knockout`；
- `prize_gain_milli`；
- `board_development_milli`；
- `attack_pressure_milli`；
- `next_turn_continuity_milli`；
- `hand_quality_milli`；
- `disruption_milli`；
- `resource_preservation_milli`；
- `risk_milli`；
- `unresolved_debt_milli`。

`final_prize_knockout` 是硬终局通道；其余维度以固定整数权重计算，避免 Python/GDScript 浮点漂移。当前默认权重是 TP-WP1 的冻结测试模型，不是经过训练或晋级的竞技模型。

## 4. Base 权限与安全边界

每个 program 必须有一份独立 Base proof：

- `admissible`；
- `current_step_id`；
- `current_step_executable`；
- `mandatory_preserved`；
- `terminal_preserved`；
- `base_vetoed`。

Planner 不接受 program 自己声明安全。proof 必须与同一 request 的 program 一一对应，`current_step_id` 必须等于 fresh program 的第一语义步骤。任意缺失、重复、依赖逆序、未知 terminal、source hash 漂移或隐藏信息键都会 fail closed。

Planner 输出不含 `selected_indexes`。`TurnProgramJournal` 只保存 program/goal/route 和 turn deadline；不保存旧 index、utility、proof、binding、window ID 或 observation hash。下一窗口即使 program identity 相同，也必须用 fresh request 和 fresh Base proof 重新排序。

## 5. 玛俐事务级 exam

共享向量锁住两个方案级判断：

1. 普通非终局回合：
   `双进化 -> 庞克泵填场 -> 愿增猿转伤 -> 干扰手牌 -> 攻击`
   胜过 `立即攻击`。它比较的是完整回合结果，不是把第一张卡的局部分数抬高。
2. 最终奖赏击倒：
   即使仍有发展债务，`take-final-prize-now` 通过硬终局通道胜出，避免形成全局“攻击最后”规则。

另有负控覆盖 Base veto、不可执行第一步、mandatory/terminal 未保留、窗口哈希漂移、隐藏牌库顺序、非法依赖图和陈旧 journal。

## 6. Runtime 接入

Python：`CompetitivePolicyV2Runtime.decide(..., turn_program_request=..., turn_program_journal=...)`  
GDScript：`CompetitivePolicyV2Core.decide(..., turn_program_request, turn_program_journal)`

两端都满足：

- 不传 request：不增加审计字段，旧决策和旧 audit hash 不变；
- 传 request：附加 `audit.turn_program_shadow`；
- shadow request 无效或 journal 失败：只记录 shadow failure，不改变 live Base 选择；
- live `selected_indexes` 仍由现有 Base/mandatory/terminal/veto 路径产生。

因此回滚不需要包迁移：停止传入两个可选参数即可恢复 TP-WP1 之前的精确运行树。

## 7. 执行证据

- Python Turn Program + transaction：`21/21`；其中 Turn Program 自身 `9/9`。
- Python Competitive Policy v2：`25/25`。
- Python compileall：通过。
- GDScript Turn Program：`4/4`，共享向量的选择、排序和完整 audit hash 与 Python 一致。
- GDScript Competitive Policy v2：`19/19`，compiled route P95 `5.654 ms`。
- GDScript turn transaction：`1/1`。
- R55 原有完整 focused：`21/21`，其中首项内部历史/边界场景 `103/103`，证明默认无 request 路径未退化。

关键 SHA-256：

- schema：`8BB37BE3A934B9D1C493455BA26FC618D8A55A7BEE1EC0912B3639F8106227E7`
- vectors：`A05519FF0BAC95CA2A9FEFD3625C90B75326704F33F176B6DFCC17DD13C8F6DA`
- Python planner：`3645A3B8B64C4FE656680FFB3549C76E98D057C80CF6F8F211B338130950CD09`
- GDScript planner：`6F821E6DEF1915BC79B1A7818389DEACAE092CA5325A7765768715A39E49B8EC`
- GDScript journal：`C1DEFAE182F90C8EC510557F45FE495F3FF16B58CEDAEC59562003B8A59E16FD`
- GDScript Turn Program log：`2AB135A62CD10454953C89D08D31777C7312135CE77414C8B29568124745886D`
- GDScript Competitive Policy log：`09D31FDAB50AF18D941E8836FB3756880D85D187F86063EA1E823FC2D3E1D5BE`
- GDScript transaction log：`9F923AB2D79D0E8757BB33040722BCF4182D5BF75E14ACD2A1E76428A4D09AC2`
- R55 focused log：`D329C7D4F580C068AB64A848D4950C09FABCE70898E7DB0E4525C97556288868`

## 8. 尚未完成

TP-WP1 只关闭“方案可以被语言中立地表达、比较、审计且不夺取执行权”这一架构门。以下仍未完成：

- R55 的 17 个 turn transaction 尚未自动展开成 Top-K Turn Program；
- `public_outcome` 仍由请求提供，尚无 counterfactual public branch evaluator；
- 尚无回放语料训练的 GBDT/量化 MLP value artifact；
- 尚无 2-turn bounded beam/MPC；
- 尚未在真实 R55 回放上统计 shadow winner 与 live route 的分歧；
- 尚未触发 canary、exact100 或 fresh/multi-matchup 晋级门；
- 未验证 official CABT、Android、A5 或 production trust。

所以 TP-WP1 不是“新算法已经提高胜率”的证据。

## 9. 下一工作包

`TP-WP2` 应按以下顺序推进：

1. 从 adapter 的 `turn_transactions / turn_routes` 和 public frame 生成 3–8 个无 index 的候选 program；
2. 建立 public branch transition/effect summary，计算候选终局公开结果，而不是由作者直接填写结果向量；
3. 在录像/exam 上输出 live route 与 shadow Top-K 的逐回合差异；
4. 冻结可跨 Python/GDScript 的小型 value artifact；
5. 先做 shadow replay gate，再做一个窄 canary consumer；
6. 只有 invalid/stale/private/dirty 全零、R55 exam 不退化、exact100 达到原声明 `57/100` 且 fresh/multi-matchup 不崩时，才允许讨论晋级。
