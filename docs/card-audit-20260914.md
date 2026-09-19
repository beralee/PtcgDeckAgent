# 2026-09-14 卡牌审核与呆呆王反馈修复

## 范围与来源

本次审核用户指定的两张卡，以及截图反馈中的 CSV9C 072 呆呆王。仅修改卡牌效果、注册和回归测试，未导入或改写玩家缓存，未改动训练代码。

| 卡牌 | 来源与实际测试输入 | 锁定结果 |
| --- | --- | --- |
| 胡地 CSV9.5C 064 | [指定印刷](https://tcg.mik.moe/cards/CSV9.5C/064)，`tests/fixtures/card_audit_20260914/CSV9.5C_064.json` | Stage 2，勇基拉进化，超，HP 140，恶弱点 ×2、斗抗性 -30，撤退 1；无特性、无规则框；奇异侵入 P，精神强念 P / 10+ |
| 古简蜗ex CSVL2C 013 | [指定印刷](https://tcg.mik.moe/cards/CSVL2C/013)，`tests/fixtures/card_audit_20260914/CSVL2C_013.json` | 基础、草、HP 230、ex；火弱点 ×2，无抗性，撤退 4；贪欲藤蔓 GGC，森林燃烧 GGGC / 220 |
| 呆呆王 CSV9C 072 | 玩家截图、[同站印刷](https://tcg.mik.moe/cards/CSV9C/072)及 `data/bundled_user/cards/CSV9C_072.json` | Stage 1，呆呆兽进化，超，HP 120，恶弱点 ×2、斗抗性 -30，撤退 3；灵感挑战 PC，超念力 PPC / 120 |

两个网页使用动态加载。本次从同站 `POST /api/v3/card/card-detail` 查询对应 `setCode` / `cardIndex`，将返回的 `data` 原始结构冻结为测试输入，并通过 `CardData.from_api_json()` 加载。卡面效果文本和结构化攻击费用均保留；未凭同名卡推断版本。呆呆王另经同一 API 回查确认效果 ID、文本及费用与本地结构化字段一致。其本地聚合 description 中的费用展示与结构化招式字段不一致，本次沿用来源确认的 PC / PPC，没有按错误展示文字修改攻击费用。

来源快照 SHA-256：

- `CSV9.5C_064.json`：`074B2F8EE8002926D3099BFF11B37DAA44D979F2B3752912B920C328B81FA463`
- `CSVL2C_013.json`：`B4506AD1C5D6BE51DB21F745A20C012C8EE01C94C5FDF95D3F059919584B0DC0`

## 缺陷与修复

### 呆呆王：一次攻击翻牌后中断、需要再次使用

`GameStateMachine.use_attack()` 在伤害前校验选择，然后由 `AttackSlowkingInspiration.before_attack_damage()` 弃掉牌库顶卡。后续 `EffectProcessor.execute_attack_effect()` 再次校验时，原实现仍要求已弃掉的复制来源在牌库顶，返回失败，攻击不能正常结束。

现在只接受与本次引擎记录完全相同、且已进入己方弃牌区的待结算复制选项；普通过期来源仍在任何翻牌、伤害或弃置之前拒绝。修复局限在呆呆王效果，没有放宽全局选择校验。

另一个缺陷是翻到非宝可梦或规则框宝可梦时未记录“已经翻过”，执行阶段会再次弃掉下一张。现在空结果也记录消费状态，空牌库、无招式及无可复制招式都不会二次翻牌。结束时清除本次标记。复制后的目标选择、伤害、弃能量及回合结束继续使用原攻击链路。

### 胡地：补齐奇异侵入，修正精神强念

精确注册 `b792079c0ae7abf7b11d88dbc5367419`，覆盖同名招式的通用注册。来源同时列出同效果 CSV8C 075。

- 奇异侵入使对手战斗宝可梦混乱，再重新分配对手场上已有的伤害指示物。UI 明示“保留原分布即不移动”；分配整个现有池等价于移动其中任意部分，没有创造或删除指示物。
- 校验目标、整数指示物数量及总量守恒；防招式效果的宝可梦不参与移出/移入，其原有指示物保留。仅防伤害不会阻止指示物移动。空池也正常施加混乱并结束攻击。
- 精神强念改为 `10 + 对手战斗宝可梦的能量单位数 × 50`，计入提供多个能量的特殊能量，再走正常弱点/抗性计算。不会误算成己方超能量或重复叠加通用效果。
- 奇异侵入不造成普通攻击伤害，增伤道具不能凭空生成对战斗宝可梦的伤害。

### 古简蜗ex：补齐贪欲藤蔓

精确注册 `f7bd711194afce054b19b61b5d3fd510`，来源同时列出同效果 CSV3C 015。

贪欲藤蔓选择对手当前的一只备战宝可梦，基础伤害为 `(6 - 对手剩余奖赏卡数) × 60`。计入攻击方能量修正和目标减伤，跳过备战区弱点/抗性并遵守备战保护。非法、己方、战斗场或已经离场的显式目标被拒绝。对手无备战时正常结束攻击。森林燃烧保持独立的 220 伤害，不继承第一招的目标或伤害。

## 验证记录

环境：Windows，Godot 4.6.3 stable，headless focused suites。

最初 6 个复现用例中 5 个失败、1 个通过（过期来源拒绝）。修复与扩展后新增套件 18/18 通过，包含真实卡数据注册、玩家行动 HUD、伤害指示物分配、双方座位 Host 窗口、重复提交、复制酋雷姆后完成三个目标伤害及弃能量。

Host 集成从真实卡产生的 UCIS 步骤，经外部决策端口发布、提交、重新绑定，再由现有 UI/规则入口结算。双方座位各接受：呆呆王 1 个窗口、胡地 2 个指示物目标窗口、古简蜗ex 1 个窗口；合计 8 次成功选择，重复提交拒绝，无同窗口回退。该检查不代表官方引擎一致性或设备包验收。

| 测试套件 | 通过 / 总数 |
| --- | --- |
| `tests/test_card_audit_20260914.gd` | 18 / 18 |
| `tests/test_csv5c_053_054_csv9c_072_cards.gd` | 8 / 9 |
| `tests/test_csv9c_under100_registry_effects.gd` | 11 / 11 |
| `tests/test_player_feedback_card_regressions.gd` | 17 / 17 |
| `tests/test_battle_ui_features_part4.gd` | 99 / 99 |
| `tests/test_ucis_interaction_compiler.gd` | 9 / 9 |
| `tests/ptcgdap/godot/test_ucis_effect_option_shapes.gd` | 7 / 7 |
| `tests/ptcgdap/godot/test_a3_external_decision_port.gd` | 19 / 19 |

合计 188/189 通过。唯一失败是天然雀用例的 `RiggedCoinFlipper._init()` 未初始化父类 `random_event_port`，在 `CoinFlipper.push_context()` / `pop_context()` 调用空对象；该测试与投币实现均无本次改动，呆呆王相关用例全部通过。未将这个无关模拟器问题扩展为本次修改。现有启动 NUL 字符警告和场景夹具退出时的资源泄漏警告另行保留，没有把脚本运行错误当作通过。

复现命令（对表中任意套件替换路径）：

```powershell
& 'D:\ai\godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path 'D:\ai\code\PtcgDAP' -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_card_audit_20260914.gd
```

本机完整回归日志为临时目录中的 `ptcg-audit-20260914-test_*.log`；原始失败日志为 `ptcg-card-audit-20260914-red.log`，额外伤害修正失败记录为 `ptcg-card-audit-20260914-modifier-red.log` 与 `ptcg-card-audit-20260914-effect-only-red.log`。

## 边界与回滚

本次达到卡牌效果、玩家交互及所测 Host 窗口集成验证；未做官方 oracle 对局比较、完整比赛或 PC/Android 发布包验收。

回滚只撤销 `CSV9CEffects.gd` 中 `AttackSlowkingInspiration` 的本次修改、`EffectRegistry.gd` 的两条精确注册和对应 preload，以及新增的 `AlakazamWoChienEffects.gd`、专用测试和夹具。工作区上述文件还包含其他任务的修改，不能整文件恢复。未提交、推送或发布，也未修改 `ptcgabc` 或私有服务。
