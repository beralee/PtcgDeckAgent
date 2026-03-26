# AI Phase 3 Heuristics Iteration Design

日期：2026-03-25

## 1. 背景

Phase 1 完成了 baseline AI、`VS_AI` 接管、基础交互自动选择与 benchmark 雏形。  
Phase 2 完成了稳定的 headless runner、固定三套牌组的 benchmark case、结构化结果输出，以及 deck identity 事件跟踪。

当前系统已经具备两项关键能力：

1. 可以稳定跑完 `密勒顿 / 沙奈朵 / 喷火龙 ex` 的 headless `AI vs AI`
2. 可以用固定 seeds 和结构化 JSON 对 AI 版本做回归评测

因此下一阶段不应继续优先扩 runner 或 benchmark 基础设施，而应开始利用这套评测体系，持续增强同一个共享 AI 的驾驶能力。

Phase 3 的核心问题是：

1. 让共享 AI 在三套 pinned decks 上打得更合理
2. 让 AI 的改进可以被 benchmark 稳定测量，而不是靠主观观感
3. 在不引入搜索或训练系统的前提下，把 baseline heuristic agent 推进到更强的规则型 agent

## 2. 目标

Phase 3 的目标分为三层。

### 2.1 决策质量目标

共享 AI 需要在以下方面明显优于 Phase 2 baseline：

1. 更少出现“只贴能就过”“明明能展开却不展开”的低质量回合
2. 更少浪费关键资源，例如不必要地过早丢弃资源或错过检索窗口
3. 更稳定地打出三套牌组的核心资源线
4. 在简单收益明确的局面里更容易做出高价值动作顺序

### 2.2 可解释性目标

Phase 3 必须让 AI 的决策过程可观察、可定位、可复盘。

具体要求：

1. 能查看某一回合 AI 的合法动作列表
2. 能查看每个动作的评分
3. 能查看最终选中的动作
4. 能区分“动作没枚举到”和“动作枚举到了但评分输掉”

### 2.3 评测闭环目标

Phase 3 的每次迭代都要能通过 Phase 2 的 benchmark 套件判断“是否真的变强”。

成功标准不是单局观感，而是：

1. 固定 seeds 下 benchmark 胜率、identity hit rate、stall rate 的对比
2. 新版本 AI 与旧版本 AI 的 A/B 结果
3. 没有显著引入新的卡死、unsupported prompt 或 action-cap 问题

## 3. 非目标

Phase 3 不做以下内容：

1. 不引入 MCTS、rollout search、强化学习或自博弈训练
2. 不引入 deck-specific 独立 AI
3. 不扩到全卡池或更多 benchmark 牌组
4. 不重写 Phase 2 的 runner、result schema 或 identity tracker
5. 不追求把 AI 一次性做成“高手级”

Phase 3 只处理：

1. 共享 heuristic AI 的可解释性
2. 动作评分与优先级的增强
3. 通过 benchmark 驱动的稳定增量改进

## 4. 路线选项

### 方案 A：纯启发式加权迭代

直接在 `AIHeuristics` 上堆更多规则和权重。

优点：

1. 交付快
2. 与现有代码最兼容

缺点：

1. 如果没有观察能力，定位回归会很痛苦
2. 容易把 heuristic 文件堆成黑盒

### 方案 B：先做调试观测，再做 heuristic 增强

先补 AI 决策观测层，再增强 heuristics。

优点：

1. 每次异常都能快速判断是枚举问题还是评分问题
2. 更适合长期持续迭代共享 AI
3. benchmark 回归分析更容易落地

缺点：

1. 前几步收益不直接体现在对战强度上

### 方案 C：直接做轻量前瞻

跳过大量 heuristic 打磨，直接尝试 1-step lookahead。

优点：

1. 理论上天花板更高

缺点：

1. 当前卡牌交互复杂度高，前瞻成本和不稳定性都高
2. 很容易在还没打磨好 feature/score 前就引入更难 debug 的问题

### 推荐结论

采用方案 B。

Phase 3 的顺序应为：

1. 先补 AI 决策观测与解释能力
2. 再重构动作评分输入
3. 再逐步提升 heuristic 质量
4. 最后用 benchmark A/B 验证改进是否成立

这样能最大化利用已经完成的 Phase 2 benchmark 体系，并为未来的搜索式 agent 留出干净接口。

## 5. 成功标准

Phase 3 完成时，至少满足以下标准：

### 5.1 Benchmark 层

固定三套牌组：

1. `575720` 密勒顿
2. `578647` 沙奈朵
3. `575716` 喷火龙 大比鸟

在固定 seeds benchmark 下：

1. `candidate-v*` 对 `baseline-v1` 的总胜率不劣化
2. 至少一个主要 pairing 的胜率有明确提升
3. `stall_rate` 不上升
4. `cap_termination_rate` 不上升
5. 核心 identity events 的 hit rate 不显著下降

### 5.2 行为层

至少在部分 benchmark 对局与人工 smoke 中，能看到以下改进：

1. 密勒顿更稳定地铺基础、开 `电气发生器`、形成攻击链
2. 沙奈朵更稳定地推进演化、开 `精神拥抱`、连起资源线
3. 喷火龙更稳定地展开演化线，而不是频繁只贴能过

### 5.3 可解释性层

对于一局指定对战，开发者能回答：

1. 当前 AI 有哪些合法动作
2. 它为什么选了这个动作
3. 它为什么没选另一个看起来更好的动作

## 6. 系统拆分

Phase 3 建议拆成四个子系统。

### 6.1 AIDecisionTrace

职责：

1. 记录某一 AI step 的合法动作列表
2. 记录每个动作的评分明细
3. 记录最终 chosen action
4. 为 benchmark、调试 HUD、日志输出提供统一数据源

约束：

1. 不直接参与决策
2. 只负责记录与输出
3. 必须保持结构化，不能只依赖人类可读字符串

建议输出字段：

1. `turn_number`
2. `player_index`
3. `legal_actions`
4. `scored_actions`
5. `chosen_action`
6. `reason_tags`

### 6.2 AIFeatures / Scoring Context

职责：

1. 从 `GameState` 提取更稳定的决策特征
2. 让 heuristics 不再只靠 `kind` 做粗粒度打分

建议特征包括：

1. 当前场上宝可梦数量
2. 可攻击数量
3. 演化线就绪程度
4. 检索动作是否能直接带来基础、演化或能量推进
5. 当前动作是否提高本回合或下回合攻击概率
6. 奖赏差距与潜在击倒收益

### 6.3 SharedHeuristicPolicy

职责：

1. 维持“一个共享 AI”的主线
2. 在共享策略中容纳少量 deck-specific light bias

这里的 deck bias 不是单独 agent，而是：

1. 对共享评分体系的轻量参数化
2. 只允许影响少量高层偏好，例如铺场、演化推进、能量循环、主攻形成

约束：

1. 不允许每套牌完全独立出一套 heuristics 脚本
2. 不允许把 deck bias 写成无法比较的硬编码黑箱

### 6.4 Benchmark Regression Gate

职责：

1. 固定 benchmark case
2. 比较 `baseline-v1` 与 `candidate-v*`
3. 输出 JSON 与文本摘要
4. 给出“通过 / 不通过 / 需要人工复查”的回归结论

这层不是新 benchmark 系统，而是建立在 Phase 2 结果结构之上的版本回归门槛。

## 7. 数据流

推荐数据流如下：

1. `AILegalActionBuilder` 枚举合法动作
2. `AIFeatures` 从当前状态和动作构造评分上下文
3. `SharedHeuristicPolicy` 对每个动作评分
4. `AIDecisionTrace` 记录评分过程与 chosen action
5. `AIOpponent` 执行动作
6. `HeadlessMatchBridge / AIBenchmarkRunner` 记录对局结果
7. `BenchmarkEvaluator` 比较新旧版本结果

关键点：

1. 观测层不应写在 `BattleScene` 私有逻辑里
2. benchmark 不应重新实现 AI 打分逻辑
3. 一个 action 的 score 需要能追溯到 feature 或 reason tag

## 8. 评分策略增强方向

Phase 3 不要求一次性做完，但建议按优先级推进：

### 8.1 展开优先级

1. 基础宝可梦铺场
2. 检索基础宝可梦
3. 避免在明显可展开时过早结束回合

### 8.2 演化优先级

1. 形成关键 Stage 1 / Stage 2 线
2. 提高“演化后立即产生收益”的动作分数
3. 避免把演化支持资源浪费在低收益目标上

### 8.3 能量与攻击节奏

1. 优先让本回合能攻击
2. 其次提高下回合能攻击的概率
3. 避免把关键能量贴到低价值目标上

### 8.4 检索与资源动作

1. 检索到直接提高场面质量的牌时应显著加分
2. 没有有效目标的检索不应高分
3. 对“合法但低收益”的 trainer 需要降权

### 8.5 奖赏与交换

1. 可击倒时优先判断 prize gain
2. 对高价值 target 的交换应得到更多分数
3. 避免为了无明显收益的换位浪费整回合节奏

## 9. 三套牌组的共享 AI 轻量偏置

仍然坚持一个共享 AI，但可以有轻量 bias。

### 密勒顿

重点偏置：

1. 铺基础电系
2. `电气发生器`
3. 快速形成能攻击的雷系主攻手

### 沙奈朵

重点偏置：

1. 演化推进
2. `精神拥抱`
3. 弃牌区能量转为场面攻击力

### 喷火龙 ex

重点偏置：

1. 演化线推进
2. `神奇糖果 / 派帕 / 检索` 这类演化支撑资源
3. 形成喷火龙 ex 或备用主攻，而不是长期空转

这些偏置必须表现为共享评分体系中的少量规则或参数，而不是拆成三个 agent。

## 10. 测试策略

测试分三层。

### 10.1 单元测试

覆盖：

1. 新 feature 提取是否正确
2. 新 scoring rule 是否对目标动作加分
3. `AIDecisionTrace` 是否记录完整

### 10.2 行为测试

覆盖：

1. AI 在特定局面下不再错误早停
2. AI 能选择更符合牌组身份的动作
3. 某些低质量行为被压制

### 10.3 Benchmark 回归

覆盖：

1. 固定 seeds 下新旧版本 A/B
2. pairing summary 不劣化
3. identity hit rate 不明显下降
4. stalled / cap / unsupported failure 不上升

## 11. 实施边界

Phase 3 的实施应分两步：

1. 先交付“可观察的共享 heuristic AI”
2. 再交付“第一轮 benchmark 驱动的 heuristic 提升”

不要在同一轮里同时引入：

1. 复杂前瞻
2. 大规模重构
3. 更多牌组扩展

这样可以确保每次 benchmark 变化都能解释得清楚。

## 12. 结论

Phase 3 的本质不是“继续补功能”，而是开始进入真正的 AI 质量迭代期。

推荐路线是：

1. 先补 AI 决策观测与 trace
2. 再增强共享 heuristic policy
3. 再用 Phase 2 benchmark 做固定 seed 的 A/B 回归
4. 让三套 pinned decks 的对局质量逐步提升

只有把这一层做好，后续 Phase 4 才适合讨论轻量前瞻、搜索或更强的 agent 形态。
