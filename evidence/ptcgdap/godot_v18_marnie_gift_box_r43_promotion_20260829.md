# 玛俐礼盒 5.3.0（r43）策略晋级证据（2026-08-29）

## 工作包与验收门

- 目标：修复实战录像 `match_20260828_215722_938052` 的五类策略判断；策略决策不得依赖牌组编号或 benchmark seed；同一组 100 局对厄诡椪 1.4.0 的胜率须比 1.9.0 基线提高至少 10 个百分点。
- 晋级条件：录像选择 exam 9/9 且五次重复 45/45；最终状态 exam 5/5 且五次重复 25/25；100 局必须全部合法终局、公开录像可接受，invalid output、policy error、classic fallback、same-window fallback 和 engine rejection 全为 0。
- 本证据只授予 Godot Windows 本地开发策略晋级；不授予 production、Android/A5、官方 CABT 整局规则 parity 或统计显著强度保证。

## 最终策略包

- 包：`dev.bodao-yongzhe.marnies-gift-box@5.3.0`
- 策略：`bodao-yongzhe.marnies-gift-box.competitive-v2-rule-marnie-r43`
- 文件：`data/ptcgdap/author_strategy_packages/marnies-gift-box-rule-marnie-r43-5.3.0.ptcgai`
- 大小：147,805 bytes
- SHA-256：`863EE8C8FA093B67863C5C60754A3BF4DF9796C7557084191A0C2A581E94A3A3`
- adapter：116 条评分规则、7 条计数规则；Forge `check` 111/111，确定性重复构建一致；Forge SDK snapshot `--check` 通过。

包内 `deck_manifest.json` 和 `policy/config.json` 仍保存 `source_deck_id=646600`，用途只是把 CSV 卡表与 60 张构筑身份固定在包中。`policy/adapter.json` 的决策条件没有 `deck_id`、`source_deck_id`、seed 或本次 benchmark 数字；运行时只使用当前合法选项、己方稳定 local UID 和公开场面事实。因此“牌组元数据负责装载卡表”与“策略判断不依赖牌组编号”已经分离。

## 五类录像判断的关闭方式

1. 进化学习器：新增 `distinct_card_uids` 计数模式，以当前窗口不同卡 UID 为基数，选择两只不同后备目标并为两条进化线各选一张进化卡，不再由 Base 默认最小数量 1 截断。
2. 庞克泵感：`punk-up.take-all-offered-dark` 取本窗口全部可用基本恶能；不再只按“离当前招式就绪还差 1 能”的 debt 取一张。
3. 尖钉镇：提高“有捣蛋小妖、缺诈唬魔”的上游主行动连续性，并保留检索窗口对诈唬魔的精确偏好，避免先用奇树洗走尖钉镇或消耗竞技场动作。
4. 支援者：秘密箱优先保留奇树；`development-supporter-before-tm-evolution` 回合路线在回合终结型进化学习器招式前先使用可用的博士/奇树，完成补手或干扰。
5. 昏厥送出：`handoff.zero-retreat-budew-pivot` 在 `send_out` 窗口选择含羞苞，不再因无规则命中而回退到候选 0。

为达到整局 +10pp 门，r43 还增加了严格受公开局面约束的后期奇树和撤退规则：大手牌/奖赏时钟后期干扰、双方两奖内且己方前台愿增猿时撤到已就绪长毛巨魔。宽泛版本曾引起早期含羞苞/愿增猿回归，最终约束后才晋级。

## Exam 证据

### 录像选择 exam（真实策略执行）

- 语料：`tests/ptcgdap/exams/marnie_gift_box_match_20260828_215722_938052_r43.json`
- 原生录像：411/411 witness，`accepted=true`、`integrity_status=verified`。
- `detail.jsonl` SHA-256：`7EEBADA7BC5A42F532B42D504BE46DB8161C31CA2ED97409F3EB8048A8AD6347`
- 记录链根：`76E360C91BC01578C6F10A5A16C0CD854051DC35E75CC69E2568032E8666A416`
- 结果：9/9 exams、45/45 独立新策略实例运行、100%；公开帧不含对手隐藏手牌、牌库顺序或运行时对象。

### 最终状态 exam（验收比较器）

- 语料：`tests/ptcgdap/exams/marnie_gift_box_outcome_exams_r43.json`
- 结果：5/5 exams、25/25 重复比较、100%。
- 契约：前台精确；后备、手牌、弃牌区按无序多重集比较；奖赏、能量、伤害、工具与进化链精确；不比较动作顺序。
- 负控：从候选终态移除一张弃牌会返回 `DIVERGE`，证明弃牌区不是被忽略。
- 边界：该语料是录像回合对应的冻结终态验收 fixture，用于锁定“最终结果正确”的比较语义；策略自身的实际选择由上面的 9 个录像选择 exam 执行验证，不能把这 25 次静态终态比较冒充 25 次完整引擎重放。

## 同种子 100 局 benchmark

- 对手：`dev.beralee.v18.ogerpon-crustle-v523a@1.4.0`，SHA-256 `3B4E78A16EB2C238CD9CFB29CA29B8CF44E0D7D99822CA9C1ECD90A2651DFFB8`。
- 方法：seed `2919000–2919049`，每个 seed 交换双方座位，精确 100 局；引擎、规则、对手包、seed 和座位政策相同，仅候选包变化。
- 1.9.0 基线：31–69（31%）；报告 `artifacts/deck_training/marnie_gift_box_1_9_0_r0_100_20260828.json`，SHA-256 `28677701D98A3979C01240ECBA13B93B8FB5D827EA8BE7A3875539764ADD0D44`。
- 5.3.0 最终：41–59（41%），seat 0 为 19/50、seat 1 为 22/50；绝对提升 `+10pp`，达到用户门。
- 最终报告：`artifacts/deck_training/marnie_gift_box_5_3_0_final_exact100_with_replays_20260829.json`，446,776 bytes，SHA-256 `5A767B73E82BD891F03F0FC5DF724ACA5521F0F2E42C17ADBE288F1C6DDE8970`。
- 运行审计：候选 6,066/6,066 policy calls 成功；3,935 次 engine commit；policy error、invalid output、same-window fallback、classic fallback、engine rejection 均为 0。
- 公开录像：100/100 accepted，100 个独立 JSON；全部 terminal 且 winner 有效，`is_clean=true`、dirty reason 0。

该结果是固定 100 局开发门的精确 +10pp，不声称置信区间已经证明真实总体强度必然提升 10pp。

## 额外规则核查

录像/bench 中长毛巨魔 ex 的伤害没有打到对方前台岩殿居蟹并非攻击引擎漏伤害：该岩殿居蟹效果会阻止对手 Pokémon ex 对它造成的伤害；后备 30 伤仍按攻击处理。该项没有修改卡牌效果或规则引擎。

## 回归与回滚

- Competitive Policy v2 Python 合同：2/2；Godot conformance/runtime：19/19。
- 场面终态比较器：11/11；其中手牌、后备和弃牌区无序多重集、弃牌缺失负控，以及 approved alternative 不得绕过弃牌检查均通过。
- 录像 exam Godot focused：4/4 tests；目标行为 9/9、重复 45/45。
- 最终状态 exam Godot focused：3/3 tests；5/5、重复 25/25。
- 回滚：新对局选择 1.9.0 `BDC7C0969D6F4A4F5CC94C480E3CE2C19F4C2542AB1902C16DEC51AE1333DB20`。不热换进行中的 match；5.3.0、1.9.0 与所有 benchmark/replay 证据均保留。

## 对齐结论

达到：`local Godot Windows development package + public-window strategy exams + clean exact-seed benchmark + public replay integrity`。

未达到：官方 CABT 全引擎 parity、production/community approval、Android/A5 设备验收、统计显著性强度保证。
