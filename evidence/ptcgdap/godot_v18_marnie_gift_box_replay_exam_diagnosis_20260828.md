# 玛俐礼盒 1.9.0 实战录像根因与定向 Exam 证据（2026-08-28）

> 后续状态（2026-08-29）：本文保留为 1.9.0 的 RED 基线与根因证据。策略修订、9/9 目标 exam 晋级和 31%→41% 同种子 benchmark 结果见 `godot_v18_marnie_gift_box_r43_promotion_20260829.md`；默认 exam 入口现已固定到晋级后的 5.3.0 语料。

## 工作包与边界

- 工作包：诊断 `match_20260828_215722_938052` 中用户指出的五类策略判断，并把相关回合固化为独立定向 exam。
- 本次冻结项：不修改 `policy/adapter.json`、`policy/policy_ir.json`、规则效果、引擎执行或 1.9.0 `.ptcgai`。
- 目标门禁：每个 exam 都从新的 1.9.0 策略实例运行；当前行为必须可重复，用户要求的目标判断必须作为后续策略版本的 100% 提升门禁。
- 对齐层级：完成 Godot 原生录像完整性验证、公开窗口重建和当前本地策略包执行验证；没有声称官方 CABT 引擎一致性或策略晋级。

## 证据身份

- 录像目录：`C:\Users\24726\AppData\Roaming\Godot\app_userdata\PtcgDeckAgent\match_records\match_20260828_215722_938052`
- 原生录像契约：`ptcgdap-native-replay-diagnostic-v2`
- `detail.jsonl` SHA-256：`7EEBADA7BC5A42F532B42D504BE46DB8161C31CA2ED97409F3EB8048A8AD6347`
- 记录链根：`76E360C91BC01578C6F10A5A16C0CD854051DC35E75CC69E2568032E8666A416`
- 完整性结果：`accepted=true`、`complete=true`、`integrity_status=verified`、411/411 条 witness 有效。
- 策略包：`dev.bodao-yongzhe.marnies-gift-box@1.9.0`
- 策略 ID：`bodao-yongzhe.marnies-gift-box.competitive-v2-rule-marnie-r9`
- `.ptcgai` SHA-256：`BDC7C0969D6F4A4F5CC94C480E3CE2C19F4C2542AB1902C16DEC51AE1333DB20`
- 作者对局审计 SHA-256：`0BB1B2B80EE5F4360A63A0535AC9546AD6F46CD92AC102076C1072139E305A56`
- 对局审计终态：61 次策略调用、61 次成功、0 次策略错误、0 次非法输出、0 次同窗口回退、36 次引擎提交、0 次引擎拒绝。

因此，这五个现象不是“AI 卡死”“宿主拒绝”“牌组编号选错”或错误回退；这局确实由上面固定哈希的 1.9.0 包作出这些选择。录像中的 `selected_deck_ids[1]=0` 只是作者策略座位不使用传统编号牌组的表现，实际牌表与策略身份由包内 CSV 和包哈希绑定。

## 录像能力边界

本局使用 `player_compact_v1`：原生事件、公开状态快照、选择上下文和终局都可验证，但 `decision_windows` 与 `host_acceptance` 详细帧被录制配置关闭。因此：

- 候选顺序、选择数量、实际落子、回合前后状态属于直接录像事实。
- exam 的 CABT 风格公开 frame 是从这些事实重建的；使用确定性的公开 serial，不声称逐字等同于未录制的开发者决策帧。
- 每个 exam 在语料中标注 `direct_replay_window`、`direct_replay_state_reduced_to_competing_actions` 或 `linked_counterfactual`，不得混用。

## 五项根因

### 1. 第 6 回合：进化学习器只进化一只

直接事实：效果窗口允许最多选择 2 只，候选为雪童子和玛俐的捣蛋小妖；策略选择 `[0]`。后续只为雪童子打开进化卡窗口并选择第一张雪妖女。

最早责任层：`adapter_interaction_cardinality`。

- 引擎效果正确发布 `min=1, max=2`，不是效果实现把上限错误设成 1。
- 1.9.0 有高分规则让 AI 使用进化学习器，但没有针对 `prompt_kind=evolve` 的 count rule，也没有“一只雪妖女 + 一只诈唬魔”的配对选择规则。
- Base 在合法窗口中按默认最小基数返回一个索引，所以主窗口和联动进化卡窗口都停在 1 张。

Exam：

- `t6_tm_evolution_choose_two_bench_targets`：目标 `[0,1]`。
- `t6_tm_evolution_choose_one_evolution_for_each_target`：目标 `[0,2]`，锁定一张雪妖女和一张诈唬魔，而不是选两张重复雪妖女。

### 2. 第 8 回合：长毛巨魔出场后只从牌库填一能

直接事实：庞克泵感窗口中牌库只剩 2 张可选基本恶能，长毛巨魔原有 1 能，策略只选择第一张，最后从 1 能变成 2 能。

最早责任层：`adapter_count_rule`。

- 引擎正确给出 `max=2`；卡牌效果自身允许最多 5 张。
- 1.9.0 的最高优先级计数规则 `punk-up.exact-public-debt` 使用 `goal_energy_debt`。
- 这时长毛巨魔距离当前招式就绪只差 1 能，因此策略有意把选择数量算成 1；它优化“刚好能攻击”，没有表达“把本次可用的两能全部取出并储备”的要求。

Exam：`t8_punk_up_take_all_two_available_dark_energy`，目标 `[0,1]`。

### 3. 第 4 回合：有捣蛋小妖却没有用尖钉镇拿中段

直接事实：回合开始时手牌同时有尖钉镇与奇树，场上已有带能量的捣蛋小妖。策略先使用奇树，把尖钉镇洗回牌库；随后抽到深钵镇并使用它。秘密箱虽又拿到尖钉镇，但本回合竞技场动作已经消耗，不能再打出。

最早责任层：`adapter_main_action_scoring`。

- `main.spikemuth-continuity` 基础分只有 6000。
- `main.iono-development` 为 12500；`main.artazon-development` 为 23500，`main.artazon-use` 为 27000。
- 策略已有 `search.spikemuth-morgrem-from-impidimp`（34000），且单独 exam 证明打开检索窗口后会正确选诈唬魔；缺陷是上游没有把“场上有捣蛋小妖但无诈唬魔”转换成必须先保住并发动尖钉镇的主行动优先级。

Exam：

- `t4_play_spikemuth_before_spending_the_development_window`：目标先选尖钉镇 `[0]`。
- `t4_spikemuth_search_morgrem_for_benched_impidimp`：目标选诈唬魔 `[2]`；这是当前唯一已经通过的目标 exam。

### 4. 第 4/6 回合链：没有先补手并干扰，再使用回合终结招式

直接事实：

- 第 4 回合秘密箱的支援者候选顺序是 `[博士的研究, 派帕, 奇树, 派帕, 派帕, 派帕]`，策略无匹配偏好，选择第一个博士的研究。
- 第 6 回合真实手牌因此是博士的研究，而不是奇树。策略在博士仍在手牌、支援者次数可用时直接使用进化学习器招式并结束回合。
- 第 10 回合手里只有派帕，不存在可同时补牌并干扰的奇树；用户观察到的后果实际由第 4 与第 6 回合的选择链造成。

最早责任层：`adapter_search_preference` + `adapter_terminal_action_ordering`。

- 博士发展规则 10500，奇树发展规则 12500。
- 两条进化学习器攻击规则各 55000；没有“回合终结招式前先消耗有价值支援者窗口”的事务约束。
- 所以不论第 6 回合手里是实际的博士，还是由秘密箱正确保留的奇树，当前策略都会先攻击。

Exam：

- `t4_secret_box_keep_iono_for_next_turn_disruption`：目标秘密箱选奇树 `[2]`。
- `t6_use_actual_research_before_turn_ending_tm_attack`：锁定真实录像场面，目标先博士 `[0]`。
- `t6_linked_iono_disrupt_before_turn_ending_tm_attack`：锁定修正后的联动场面，目标先奇树 `[0]`。

### 5. 第 5 回合：昏厥后没有让 0 撤退含羞苞上场

直接事实：送出候选顺序为 `[捣蛋小妖(带恶能), 雪童子, 愿增猿, 含羞苞, 捣蛋小妖]`，策略选择 `[0]`。

最早责任层：`adapter_send_out_preference_and_public_retreat_capability`。

- 1.9.0 的含羞苞规则只覆盖 `setup_active`，不覆盖 `send_out`。
- 已有的单奖桥规则只在对手剩 2 奖时偏好愿增猿；第 5 回合不满足。就绪长毛巨魔的送出规则此时也不满足。
- 没有规则命中后，Base 确定性选择第一个合法候选，即捣蛋小妖。
- Competitive v2 公开 slot 没有 `retreat_cost` 字段，因此通用策略无法根据公开帧推导“0 撤退”；当前包仍可用稳定本地 UID 为含羞苞增加专用送出规则。若未来要求所有牌组通用，则需另开观察契约变更，不能在 adapter 中猜。

Exam：`t5_send_out_zero_retreat_budew_pivot`，目标 `[3]`。

## Exam 结果

语料：`tests/ptcgdap/exams/marnie_gift_box_match_20260828_215722_938052.json`

| 门禁 | 结果 | 解释 |
|---|---:|---|
| 1.9.0 当前行为复现 | 9/9 exams；45/45 独立运行；100% | 每次新建密封包策略实例，当前错误判断稳定可复现 |
| 用户目标判断 | 1/9；11.11% | 只有“尖钉镇窗口打开后拿诈唬魔”已满足；其余 8 个目标为 RED |
| 公开信息防火墙 | 9/9 | 对手只有 `hand_count`，无隐藏手牌、牌库顺序或运行时对象 |
| 录像完整性 | 411/411；verified | 原生事件哈希链和文件哈希通过 |

这满足“先看清问题、做好 exam、不改策略”的要求，但不把 11.11% 虚报成 100%。后续任何明确授权的策略修订，必须让 `target_selected_indexes` 门禁达到 9/9、所有独立运行 100%，才可称这五项判断被锁死。

## 可复现命令

现状与语料结构测试：

```powershell
& scripts/tools/run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/ptcgdap/godot/test_marnie_gift_box_replay_exams.gd
```

录像 + 当前/目标双报告：

```powershell
& D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe --headless --path D:\ai\code\PtcgDAP -s res://tools/ptcgdap/run_marnie_gift_box_replay_exams.gd -- --mode=report --repetitions=1 --replay-dir=C:\Users\24726\AppData\Roaming\Godot\app_userdata\PtcgDeckAgent\match_records\match_20260828_215722_938052
```

未来策略晋级门禁（当前应返回非零，因为只有 1/9）：

```powershell
& D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe --headless --path D:\ai\code\PtcgDAP -s res://tools/ptcgdap/run_marnie_gift_box_replay_exams.gd -- --mode=target --repetitions=5 --replay-dir=C:\Users\24726\AppData\Roaming\Godot\app_userdata\PtcgDeckAgent\match_records\match_20260828_215722_938052
```

## 回滚与未支持项

- 本工作包没有改变游戏或策略运行行为；回滚只需移除新增 exam 语料、测试、runner 和本证据文件。
- 1.9.0 原包、包内 CSV、规则引擎和宿主选择路径保持原样。
- 未完成：目标判断 100%、新策略包构建、正式 CABT 对照、整局胜率评估；这些都必须在用户授权“修改策略”后另开工作包。
