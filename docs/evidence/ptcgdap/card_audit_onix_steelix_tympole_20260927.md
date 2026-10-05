# 大钢蛇、大岩蛇、蓝蟾蜍、圆蝌蚪卡效审核

日期：2026-09-27。范围：用户指定的四个简中印刷版本，Godot 4.6.1 本地规则、UCIS 及作者 Host 选择链路。

## 来源和逐卡结论

通过卡牌页面使用的 `POST /api/v3/card/card-detail` 获取具体 `setCode/cardIndex` 的原始数据，并逐张核对卡面图片。API 数据按 JSON 保存为 `tests/fixtures/card_audit_20260927/*.api.json`；这些是来源快照，不是手写简化卡。

| 印刷与来源 | 核对结果与修复 | 验证 |
| --- | --- | --- |
| [CSV6C/097 大钢蛇](https://tcg.mik.moe/cards/CSV6C/097) | HP180、钢、一阶、大岩蛇进化、火弱点×2、草抗性−30、撤退4。地震 M/130 缺少己方全部备战各30伤害的注册，现已补齐；重磅冲击 MMCCC/180 保持普通伤害。 | 两座位、只伤己方备战、不算弱抗、太晶保护、己方备战昏厥及对方取得奖赏、进化后实际攻击。 |
| [CSV6C/067 大岩蛇](https://tcg.mik.moe/cards/CSV6C/067) | HP120、斗、基础、草弱点×2、无抗性、撤退4。坚硬头锤 C/20 缺少抛币保护注册，现已绑定第0招式；大地粉碎 CCC/80 无附加效果。 | 正反面、预览不消耗随机数、下一个对手回合防伤害及中毒、期限结束、离开战斗场失效、第二招不获得保护。 |
| [CSV5C/032 蓝蟾蜍](https://tcg.mik.moe/cards/CSV5C/032) | HP100、水、一阶、圆蝌蚪进化、雷弱点×2、无抗性、撤退2。泼水 WW/50 的普通伤害实现正确，无需新注册。 | 水费用不足拒绝、正确费用50伤害、正常与错误进化线、无附加效果。 |
| [CSV5C/031 圆蝌蚪](https://tcg.mik.moe/cards/CSV5C/031) | HP70、水、基础、雷弱点×2、无抗性、撤退1。螺旋之尾 W/10 缺少抛币弃对方战斗宝可梦能量的注册，现已补齐并修复共用选择实现。 | 正反面、先抛币后选择、重复观察不重抛、无能量、特殊能量整卡弃置、非法选择在伤害前拒绝、薄雾/大岩蛇保护、真实 Host 双座位与旧窗口拒绝。 |

审核开始时，游戏默认 `user://cards/` 中存在两张 CSV6C 卡，内容与新获取的 API 一致；两张 CSV5C 卡及四张目标卡的 bundled JSON 均不存在。测试直接经过 `CardData.from_api_json` 和真实 `EffectProcessor.register_pokemon_card`。没有改写玩家缓存，也没有新增内置牌组或内置卡牌。

## 最早责任层和改动

- `EffectRegistry.gd`：按三个准确 `effect_id` 注册第0招式，不靠卡名猜配；保留之前已存在的未提交改动。
- `EffectBenchDamage.gd`：执行时检查招式索引，己方备战伤害同样遵守太晶卡面保护。
- `AttackCoinFlipDiscardOpponentActiveEnergy.gd`：预览不抛币；实际交互保存当前卡牌/回合的结果，正面才开放能量窗口；提交验证要求当前对方战斗宝可梦的一张能量，去除非法选择改选首张的行为；执行遵守防止招式效果的保护。
- UCIS runtime attestation、catalog、legacy inventory、coverage 和 bundle 重新生成，使源码/交互目录一致。其他历史资格和性能收据未重写，也不沿用为本次验收证据。

## 验证证据

专项套件：`tests/test_onix_steelix_tympole_audit.gd`，自动发现，独立用户数据目录。

- 注册修复前：5项中4项失败、1项通过，复现三个缺失效果。
- 只补注册后：5项中2项失败，复现太晶己方伤害和抛币时机问题。
- 交互负例补齐后：8项中4项失败，另外复现非法选择自动弃首张及效果保护被绕过。
- 完整修复后：专项12/12通过。
- 8个 Godot 相关套件：155/155通过，0失败、0跳过。
- 生成文件同步后：4个 Godot 套件31/31通过，含注册及实现状态检测。与前一轮去重后为165个 Godot 测试。
- `python -m unittest tests.ptcgdap.test_ucis_contract`：重新生成前准确报告生成文件漂移；重新生成后8/8通过。
- `git diff --check`：本次修改文件通过。

主要命令：

```powershell
.\scripts\tools\run_godot_tests.ps1 -Runner all -Suite 'OnixSteelixTympoleAudit,EffectSystem,Csv9cPokemonSimpleEffects,ImportedUnimplementedCards202605,UcisInteractionCompiler,UcisEffectOptionShapes,CompetitivePolicyV2,A3ExternalDecisionPort' -UserDataRoot .godot_test_user/card_audit_20260927_regression -ReportDirectory .godot_test_user/card_audit_20260927_regression_report -TimeoutSeconds 240
.\scripts\tools\run_godot_tests.ps1 -Runner all -Suite 'OnixSteelixTympoleAudit,UcisInteractionCompiler,EffectRegistry,CardImplementationStatus' -UserDataRoot .godot_test_user/card_audit_20260927_final -ReportDirectory .godot_test_user/card_audit_20260927_final_report -TimeoutSeconds 240
python -m unittest tests.ptcgdap.test_ucis_contract
```

完整本地输出保留在以上报告目录；可持久复核的摘要和文件哈希见 `evidence/ptcgdap/card_audit_onix_steelix_tympole_20260927.json`。Host 专项对每个座位接受一个真实附着能量窗口，拒绝重复提交，重排后仍绑定被选中的物理能量卡，最终通过 `GameStateMachine.use_attack` 完成弃置；两席位的错误、非法输出、fallback 和引擎拒绝计数均为0。

## 声明边界和回滚

本次完成 Godot 规则与 Host/UCIS 集成验证；没有运行官方 CABT 引擎差分、完整对战胜率或 Windows/Android 界面及导出包验收，不宣称这些门通过。没有提交、推送、发布或修改只读 oracle / 私有云。

回滚只撤销本次三个 `effect_id` 注册分支、两个共用效果的本次改动和新增专项夹具/测试，再根据保留后的工作树重新生成 UCIS 文件；不要对已有未提交改动的文件进行整体还原。生成前的 UCIS 文件副本另保留在本地 `.tmp/card-audit-20260927/ucis-before/`。
