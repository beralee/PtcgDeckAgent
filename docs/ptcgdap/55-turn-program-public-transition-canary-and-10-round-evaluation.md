# Turn Program 公开转移 canary 与十轮评估

日期：2026-08-31

## 1. 工作包与验收门

本工作包把 `Turn Program v1` 从“只生成整回合影子计划”推进到一个窄、可回滚的 Windows 本地开发 canary，并在这个边界上连续完成十轮玛俐礼盒策略参数迭代。

验收门分为两类：

1. 架构门：只接收公开观察，只从当前 `select.option` 返回 index；每次选择后旧窗口立即失效；Base Graph 保留合法性、强制/终结保护、事务安全和最终 veto；Python 与 GDScript 对相同工件给出一致结果。
2. 晋级门：以 5.15.0 的固定 100 局 46 胜为 Round0；候选必须在同一 100 局合同上达到至少 56 胜，同时保持 invalid、policy error、fallback、engine rejection 和 dirty game 全零。

结果：架构门通过；胜率晋级门失败。筛选最佳第 5 轮在 20 局中为 11 胜，但 100 局复验只有 49 胜，相对 Round0 仅 `+3pp`，因此不晋级。

## 2. 已闭合的架构链路

当前 Windows 本地开发链路为：

```text
public raw observation
  -> immutable current select window
  -> Base Graph legal/mandatory/terminal owner
  -> automatic transaction candidate generation
  -> public transition evaluator
  -> package-scoped language-neutral value model
  -> narrow canary adjudication
  -> fresh current-window semantic rebind
  -> Base Graph final veto
  -> list[int]
  -> reobserve; old window and proof are discarded
```

本轮新增或补齐：

- 公开转移评估器：计算公开状态增量、资源冲突、依赖冲突、不确定性、commit-safe 与 fresh-observation outcome label。
- 自动事务候选审计：候选生成结果携带可复核的 transition audit，并进入 Python/GDScript 一致性向量。
- 窄 live canary：只能覆盖 Base Graph 的 attack/end 候选；要求当前绑定新鲜、转移安全、来源与效果在包声明集合内、效用超过 margin，且不能延迟已公开证明的最后奖赏终结攻击。
- 稳定卡牌 UID 语义：通用 trainer window 由包内 `set_code + "_" + card_index` 声明 draw、disruption、search、conversion、evolution、bench 与一次性资源 claim。决策不读取 deck number、source deck ID、牌组槽位编号或 benchmark seed。
- 公开结果前置条件：以己方公开手牌数、对手公开手牌数表达 draw/disruption 的最低条件；条件未知或不满足时 fail closed。
- 设备本地配置：作者包的扁平标量配置由 Godot 本地 runtime 读取；Python/PyTorch 不进入玩家决策路径。
- 可回滚构建：architecture 与 round01–round10 共 11 个包由单一脚本确定性生成，逐包 byte SHA 复现 11/11。

包内 `source_deck_id=646600` 仍作为既有作者包格式的来源/卡表身份元数据存在，但没有进入生成器、转移评估、价值打分、canary、重绑定或 Base Graph 决策条件。策略语义只使用当前公开状态和 Godot-local stable printing UID。

## 3. 根因证据与架构调整

第 2 轮 trace 共 71 个决策，canary 仅应用 2 次；45 次因 `effect_kind_not_allowed` 被拒，23 次不是 commit，另有 1 次来源类型不符。根因不是“某一张牌优先级少几分”，而是通用 trainer action 没有公开效果语义，导致 evaluator 只能把它视为高不确定性 search，绝大多数事务根本没有进入可比较集合。

因此第 3 轮起把“卡牌语义”提升为包级、语言无关的公开合同，并明确一次性资源 claim。第 6、7 轮又证明广泛放开 draw/disruption 会伤害事务完成度；第 8 轮开始增加公开手牌结果条件。第 9 轮广泛放开 bench 明显伤害先手席位，第 10 轮提高效用 margin 也只恢复到 9/20。这些结果表明架构已经能改变真实动作链，但当前值函数仍不足以可靠预测跨窗口的最终胜负价值。

## 4. 十轮固定 20 局筛选

architecture control 与 Round0 在固定 20 局子集均为 10/20。十轮结果全部 terminal、clean，invalid/error/fallback/rejection 为零。

| 轮次 | 主要方向 | 总胜场 | seat 0 | seat 1 |
|---:|---|---:|---:|---:|
| 1 | 基础 canary 参数 | 10/20 | 4/10 | 6/10 |
| 2 | 扩大事务候选观察 | 10/20 | 4/10 | 6/10 |
| 3 | 引入 UID 公开动作语义 | 9/20 | 2/10 | 7/10 |
| 4 | 调整事务效用 | 9/20 | 2/10 | 7/10 |
| 5 | 攻击压力与连续性，保持窄效果集 | **11/20** | 4/10 | 7/10 |
| 6 | 放开 draw | 8/20 | 2/10 | 6/10 |
| 7 | 放开 disruption | 8/20 | 2/10 | 6/10 |
| 8 | draw/disruption 加公开手牌 guard | 9/20 | 2/10 | 7/10 |
| 9 | 扩大 bench 行为 | 8/20 | 1/10 | 7/10 |
| 10 | 提高 live override margin | 9/20 | 2/10 | 7/10 |

20 局筛选只用于选择候选，不作为胜率结论。第 5 轮的 55% 是小样本高估。

## 5. 固定 100 局复验

| 版本 | 总胜场 | seat 0 | seat 1 | 相对 Round0 | clean |
|---|---:|---:|---:|---:|---|
| Round0 / 5.15.0 | 46/100 | 20/50 | 26/50 | — | 是 |
| Round5 / 5.21.0 | 49/100 | 22/50 | 27/50 | `+3pp` | 是 |

第 5 轮 Wilson 95% 区间为 39.42%–58.65%。这 100 局使用固定 `2919000–2919049`，包含十轮筛选所用的 10 个 seed，因此它是同合同扩大样本复验，不是统计独立的确认集。即使在这组更宽松的复验上，候选也没有达到预注册的 56/100；因此没有继续用第二组 100 局把失败候选包装成“冠军”，也没有把 5.21.0 切成默认或受信策略。

## 6. Exam、跨运行时与安全结果

- Python：50 passed，另有 2 个 subtests passed。
- Godot：52/52；其中 transition evaluator 2、generator 8、Competitive Policy v2 19、R55 real-window shadow 1、玛俐事务 exam 22。
- 事务 exam 覆盖：两目标进化、长毛巨魔精确补能链、尖钉镇中段、雪妖女展开、支援者补手/干扰、后期含羞苞、愿增猿换伤、送出与“完成事务后再攻击”。
- 11 个 architecture/round 包全部通过 deterministic `--check`，adapter v48、212 条既有规则与 17 个 turn transaction 保持不变。
- 所有 100 局：terminal/winner 完整；invalid output、policy error、classic/same-window fallback、engine rejection 均为 0。

## 7. 推广、回滚与权限边界

推广结论：`NO-GO`。

- 5.21.0 与其余十轮包全部 `execution_trusted=false`，只保留为开发证据。
- 默认与回滚保持 5.15.0，archive SHA `D669C1C756A5D6AD8CAA36A6A91EE7FB6D031A2A00CF9ACC896080E725A6B4ED`；只允许新对局回滚，不热换当前 match。
- 已达到：Windows 本地开发、公开窗口子集、设备本地 canary、Python/GDScript 合同一致性、固定 benchmark clean gate。
- 未达到：官方 CABT 整局验证、full-engine parity、Android/A5 资源门、production signature/community promotion、统计显著的胜率提升。

## 8. 下一次架构跃迁需要什么

十轮说明继续调单张牌权重不能产生断崖式提升。下一 owner 应是“事务条件化的结果价值学习/有界公开前瞻”：从公开轨迹学习或搜索 `完成某事务 -> 新窗口 -> 终局价值`，同时让 Base Graph 继续拥有合法性和最终 veto。下一阶段至少需要：

1. 把公开 precondition 从少量手牌阈值升级为类型化状态谓词和资源债务。
2. 用更大、独立、预注册的 trace/seed 集校准多窗口 outcome value，筛选与确认数据隔离。
3. 将 seat 0 明显退化作为独立损失项，而不是用 seat 1 收益掩盖。
4. 保留当前窄 canary 与 5.15.0 回滚，不在未达胜率门时扩大 live authority。

机器可读回执：`evidence/ptcgdap/marnie_turn_program_10_round_receipt_20260831.json`，SHA-256 `B7048B2C6989B4C65B88E2E805365AE8039F9A9EBDC8C12C4ACC15CFF4FAF09D`。
