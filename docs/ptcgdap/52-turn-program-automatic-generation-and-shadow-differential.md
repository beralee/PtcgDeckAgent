# Turn Program 自动生成与整局影子差异

日期：2026-08-31  
工作包：`TP-WP2A`  
状态：`automatic generation and whole-match shadow differential complete; canary disabled`

## 1. 结论

TP-WP2A 已把 TP-WP1 的“调用方手写完整回合方案”升级为当前公开窗口自动生成：R55 的 turn transaction、turn route，以及 Base Graph 当前放行的所有动作都可以成为无 option index 的 Turn Program 候选；Python 与 GDScript 对同一输入生成相同 Top-K、排序和 audit hash。开发者决策 trace 会自动记录 live 决策、shadow 胜出方案和两者的语义差异，但 live `selected_indexes` 仍完全由原 Competitive Policy/Base 路径产生。

本工作包解决了“事务级能力存在，但没有统一进入整回合比较”的候选覆盖问题。它没有证明影子选择更强，也没有打开 canary：当前 evaluator 是有界、确定性的公开效果摘要，不会真实推进引擎分支，尚不能可靠计算未来窗口、对手响应、随机结果和资源互斥。因此 R55 包保持原字节，胜率声明仍是 R55 exact100 的 `46/100`，未达到此前的 `57/100` 晋级门。

## 2. 最早责任层与链路

新增链路位于语义 transaction/route 和现有 Base 执行 owner 之间：

```text
fresh public frame + current immutable option frontier
  -> transaction / route / Base-admissible action expansion
  -> bounded public effect-summary transition
  -> 1..8 semantic Turn Program candidates
  -> Base-owned fresh first-step proof for every candidate
  -> deterministic whole-turn arbitration
  -> shadow winner + live/shadow differential audit

existing Competitive Policy + Base final tier/veto
  -> live selected_indexes (unchanged)
```

候选集合必须覆盖 current Base frontier，不能只把 attack/end-turn 当作 Base 候选。第一轮真实影子运行暴露了这个架构缺口：只有 `181/307` 个窗口能生成方案，`126` 个窗口因候选为空而 fail closed，`138` 个窗口只有一个候选。补齐所有 Base-admissible action 后，第二轮达到 `307/307` 生成成功，单候选窗口降到 `25`。

## 3. 语言中立生成合同

新增合同：

- `contracts/ptcgdap/turn_program_generation_v1.schema.json`
- `contracts/ptcgdap/turn_program_generation_v1_conformance_vectors.json`

生成器输入候选只允许：

- `program_id / goal_id / route_id / source_kind / priority / deadline_turns`；
- `semantic_steps / current_step_id`；
- 当前第一步、终局步骤的公开 option facts；
- Base proof。

调用方不能注入 `public_outcome`。Python `turn_program_generator.py` 与 GDScript `TurnProgramGenerator.gd` 从允许的公开事实计算同一整数 outcome。当前 effect kind 封闭为 ability、attack、bench、conversion、damage transfer、disruption、draw、end turn、energy、evolution、handoff、search、tool。未知字段、未知 effect、隐藏信息键、无 fresh first-step proof、非法 program 或超过 Top-K 上限都 fail closed。

输出不含 option index。Competitive Policy 内部只保留当次调用的临时 semantic binding，用于比较 shadow 当前第一步与 live 选择；它不进入 generator request、journal 或下一窗口。

## 4. 终局与重新观察

`final_prize_knockout` 仍是硬终局例外，但只有当前第一步是已经证明可执行的 attack，且公开目标 HP、奖赏价值和剩余奖赏证明本次击倒结束比赛时才成立。实际窗口若 attack option 没有重复目标奖赏字段，策略只从 public opponent active slot 补齐该事实，不读取隐藏区。

每次 accepted selection 后，旧 window、候选、outcome、priority、proof 和 binding 全部失效。journal 只保存 package/seat/program/goal/route/turn deadline；真实 runtime 的 `package@version#archive_sha` 已被纳入合法 scope，但旧 index、score、proof、window ID 和 observation hash 仍不持久化。

## 5. Runtime 接入与回滚

`AuthorStrategyDevelopmentPolicy` 新增显式 Turn Program shadow 开关和 match-scoped journal。开发者 decision trace 开启时，Godot battle owner 才启用自动影子；普通决策和关闭 trace 的路径不增加执行权。

每次决策新增三段非权威 audit：

- `turn_program_generation`：候选来源、数量、Top-K 和生成状态；
- `turn_program_shadow`：Base 证明后的方案级胜者；
- `turn_program_differential`：live semantic step 与 shadow current step 是否相同。

回滚不需要替换 `.ptcgai`：关闭 developer decision trace 或 `auto_turn_program_shadow` 即恢复原路径。shadow 失败只写审计，不能改变 live 选择、fallback、RNG 或 engine state。

## 6. 真实整局影子证据

两轮均使用相同 6 个 R55 loss seeds，串行运行，整局 `is_clean=true`，共 `307` 个候选决策。两轮均为 `0/6`，这是预期结果：影子不接管动作，实战轨迹与原 live 策略相同，不能把它当成新算法胜率。

第一轮（候选 frontier 不完整）：

- artifact：`artifacts/deck_training/marnie_gift_box_r55_turn_program_shadow6_20260831.json`
- SHA-256：`824E7B4BF03361E779646BAFBD383E0556223AE76197D3F84EB44BDAB323F2FD`
- generation accepted/failed：`181/126`
- 单候选窗口：`138`
- 已接受窗口 live/shadow：`61` 相同、`120` 分歧
- 候选来源行：Base terminal `211`、transaction `37`、route `2`

第二轮（完整 Base action frontier）：

- artifact：`artifacts/deck_training/marnie_gift_box_r55_turn_program_shadow6_v2_20260831.json`
- SHA-256：`977F64189F6648EC8589B9E0DE872C48564C68C2CA2DB842B3ADE8A5F26A2350`
- generation accepted/failed：`307/0`
- 单候选窗口：`25`
- emitted 数量分布：`1:25, 2:38, 3:28, 4:21, 5:28, 6:23, 7:26, 8:118`
- 候选来源行：Base action `1806`、Base terminal `211`、transaction `37`、route `2`
- live/shadow：`107` 相同、`200` 分歧；shadow 选择 transaction `23` 次、route `0` 次
- 9 个 live attack 窗口全部被 shadow 的发展步骤挑战；没有 live development 被 shadow 改成 attack

后两项只说明方案层正在发现“攻击前可能仍有公开发展动作”的诊断信号。`200` 次分歧包含同类动作不同目标，也没有反事实终局标签，因此不能将 `34.85%` 一致率解释为 live 或 shadow 的正确率。6 场中没有公开可证的最终奖赏击倒窗口；硬终局判断由 Python/GDScript 合成对照锁定。

## 7. 回归与确定性证据

- Python Turn Program/transaction/Competitive Policy：`54/54`。
- Python compileall：通过。
- GDScript generator：`5/5`；generation vector 的顺序和完整 audit hash 与 Python 一致。
- GDScript Competitive Policy：`19/19`，compiled route P95 `5.311 ms`。
- GDScript Turn Program planner：`4/4`。
- GDScript turn transaction：`1/1`。
- R55 完整 transaction/exam：`22/22`，包含真实 R55 当前窗口自动影子 exam。
- R55 确定性 build check：282,898 bytes，版本 `5.15.0`、adapter `48`、17 transactions、`execution_trusted=false`；archive SHA-256 仍为 `D669C1C756A5D6AD8CAA36A6A91EE7FB6D031A2A00CF9ACC896080E725A6B4ED`。

新增合同 SHA-256：

- generation schema：`055DA454E81975632A7C6A3DD64C92F17859FA9BC9DBD5AAD3B6F4972A71373A`
- generation vectors：`598FAE4B693BE440DE879A765DDFAA7E6A8CC6E3E9E9B5D7450A6BCBBA4F34D9`
- vector expected audit hash：`DAFCBCE8E2DBCD2A03E976186FC11275B5110C0555EC82AC47804354764E6691`
- Godot generator log：`E83BCBCC3099826154544725233F0E61EE32FAD61902966B046A4DA5CAAB2EBE`
- Godot Competitive Policy log：`0E6744E96D7D0B6C084DD82354680AFB508A13D3C11CFE21F41FC186842E9C28`
- Godot R55 full log：`83BC4FC739D53DFB4862719AB3ECEC4CCBCEAEC6D1753DED5E26AC1ACC6190B4`

## 8. 当前达到与未达到的层级

已达到：

- public-only Top-K 自动生成合同；
- Python/GDScript 生成与方案排序一致；
- device-local Godot development shadow integration；
- 真实整局差异采集、候选覆盖和 fail-closed 证据；
- R55 旧 exam 与包字节不退化。

未达到：

- 可执行的 public counterfactual state transition / closed-loop roll-forward；
- 对每个分歧的真实后果标签、校准误差和 value promotion gate；
- learned value artifact 或 2-turn bounded beam/MPC；
- canary、active owner 或胜率提升；
- exact100 `57/100`、fresh/multi-matchup 晋级；
- official CABT engine parity、production、Android 或 A5。

所以对齐声明只提升到 `local public-only automatic Turn Program generation + whole-match non-authoritative shadow differential`，不提升策略、引擎、官方或产品发布层级。

## 9. 下一工作包

下一步应是 `TP-WP2B public transition evaluator and labeled shadow gate`：

1. 为已声明 effect 子集建立不可变 public state delta，逐步应用 program 并在每步重新校验资源互斥；
2. 对无法建模的随机、Search 和对手响应显式产生 uncertainty/debt，而不是乐观计分；
3. 从真实 replay/exam 构造 live-vs-shadow 后果标签，分别统计攻击时机、发展完成度、奖赏交换和失败原因；
4. 冻结跨 Python/GDScript 一致的小型 evaluator/value artifact；
5. 只有 stale/private/invalid/dirty 全零、分歧校准门通过、R55 exams 不退化，才允许一个窄、可回滚 canary；
6. canary 仍需通过原 exact100 `57/100` 及 fresh/multi-matchup 门，不能用 6 场影子信号替代。
