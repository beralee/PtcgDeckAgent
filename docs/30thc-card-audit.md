# 30thC G/H/I/J 全卡实现与复审报告

完成日期：2026-09-10。使用 card-audit，每批不超过 5 张实施，全部落地后再次 review。本报告基于冻结源数据、真实注册结果、实际测试日志及显式复审记录生成。

## 结论与范围

来源：[30 周年卡表](https://tcg.mik.moe/cards/30thC)。产品共 169 个印刷版本，G/H/I/J 范围 **139 个印刷版本 / 111 个源 effect_id**：G=8、H=0、I=2、J=129；其余 30 个版本不在范围。

- 已落地 138 份与 API 转换结果严格相等的 JSON 及图片，保留原有 057 照片版本，共 139 张。
- 全部清单引用、图片格式和路径大小写验证通过；139 张真实源 JSON 注册状态均为已实现。
- 本地用户缓存的 138 张新增卡与 bundle 逐文件哈希一致。057 原缓存仅 Pokemon/Pokémon 拼写规范化不同，身份及规则语义一致，未覆盖。
- 全部卡牌完成规则、注册参数、逐招式索引、交互及跨层 review，修复本次确认的问题。
- 这不是对所有卡牌组合的穷举证明，也不代表整个仓库测试全绿。没有提交、发布、执行训练或设备发行构建。
- 现有 card_status_matrix_latest.txt 仅包含旧 057，不能为新增卡背书；本次使用冻结源注册审计与新卡专项重新验证。大小写敏感路径已测，但没有宣称执行过 Android/Linux 真机构建。

### 身份兼容例外

057 保留 `data/bundled_user/cards/30THC_057.json`：source_provider=user_photo，effect_id=`9256615fd387482e220b7e2630343eb7`，规则名仍为 `Mew ex / Memory Helix / Teleportation Burst`。没有覆盖旧照片身份与图片。API 057/135 的 effect_id=`dd6e658057478ff1eb223c71000b08a2` 另行注册，135 已落地；两个来源都覆盖备战招式复制/额外奖赏行为。全部图片使用实际 `30THC` 目录，并给 API `30thC` 身份补大小写敏感路径候选。

## 跨层 review 与修复

| 链路 | 核对及结果 |
|---|---|
| API -> CardData -> bundle/manifest -> CardDatabase | 源规则文本、费用/HP/弱抗/退却/进化字段逐份核对；057 兼容身份保留，图片路径可解析。 |
| effect_id -> EffectRegistry -> ThirtiethCelebrationRegistry -> EffectProcessor | 稳定 ID 路由、异画复用、逐招式索引；纯伤害/基本能量使用通用引擎。 |
| 效果 -> DamageCalculator/EffectProcessor -> GSM | 弱点倍率、能量单位、HP、减伤及伤害反应接线；指定目标伤害写公开目标事件，结算生存道具和受伤反应。 |
| PokemonSlot.heal -> EffectProcessor.can_heal_pokemon | 伊裴尔塔尔阻止对手战斗宝可梦治疗；已有治疗卡统一通过拦截器，指示物移动/离场/生存不经过治疗。 |
| 训练家声明 -> UI/Headless -> 核心提交 | 蟾蜍王投币在搜索揭示之前；正面缓存，反面只弃牌，不消耗成功使用次数。 |
| 进化元数据 -> RuleValidator -> RareCandy 配对 -> GSM -> UI/Headless | 9 条二阶线覆盖普通进化及缺 Stage 1 跳进化，中英基础别名、非首个合法目标、登场回合/错误配对负例。 |
| UCIS 选择 -> 新窗口 -> 执行 | 整副己方牌库区分可见与可选牌；顶 3 张效果不扩张视野；特殊能量逐步选择；受伤反应保留防守方选择权。 |

主要复审修复：退化清状态与防护、飘飘球单独在场离场分支、特殊能量多单位支付、日出/冲锋之舞空搜、宝可平板交互、指定目标伤害事件及手持风扇反应、基拉祈第二招式绑定、图片目录大小写。下文逐卡记录列出规则到实现的对应关系。

规则疑点辅助核对：[官方术语表（退化）](https://www.pokemon.com/us/play-pokemon/about/pokemon-tcg-glossary)、[官方规则书（场上无宝可梦）](https://assets.pokemon.com/assets/cms2/pdf/trading-card-game/rulebook/sm12_rulebook_en.pdf)。具体卡牌效果以冻结源 JSON 为准。

## 验证与未解决的原有问题

| 验证 | 实际结果 | 证据文件（均在 .tmp/30thc-card-audit/） |
|---|---|---|
| 新卡专项 | Total: 123; Failed: 0 | `final-30thc.log` |
| CSV9C/CSV10C 全功能分组 + 规则/伤害/GSM/UI/照片卡 | Total: 425; Passed: 423; Failed: 2 | `final-functional-group.log` |
| HeadlessMatchBridge | Total: 38; Failed: 2 | `final-headless.log` |
| 全仓源码编码 | Total: 2; Failed: 1 | `final-source-encoding.log` |
| 源文件/资源/清单 | 139/139 通过 | `bundle-verification.json` |
| 真实源注册 | 139/139 已实现 | `registration-audit.json` |

仍未解决的仓库原有回归（不计作通过）：

1. CSV10C 101/105 两项投币测试：RiggedCoinFlipper 的 runtime port 未初始化，push_context/pop_context 调用 null。HEAD 隔离副本使用同样真实卡数据复现为 5 项中 2 项失败：`head-reference-coin-fixture.log`。
2. Headless 两项起手重抽测试：恢复了 setup_active_0 而非 mulligan_extra_draw、额外抽牌未发生。HEAD 副本两项同样失败：`head-reference-mulligan.log`。
3. 愿增猿/光明能量第一项在 AbilityMoveDamageCountersToOpponent.gd:30 出现 GDScript 初始化异常；HEAD 副本同样复现为 6 项中 1 项失败。混合分组还出现 Godot 原生崩溃，没有计为通过：`head-reference-munkidori.log`、`review-functional-core.log`。
4. 实现早期曾跑完整 FunctionalTestRunner：5514 项，5334 通过、180 失败（`.godot_test_user/logs/functional-20260910-104122.log`）。包含已移除策略包、旧训练夹具及其他既有失败。这不是最终全仓通过证明，没有为测试恢复用户已删除的策略。最终采用上述相关功能全分组验证。
5. 现有全卡库加载仍有 Unexpected NUL character 提示，部分旧套件退出有资源泄漏警告。本次新卡文本/资源验证通过，但没有宣称解决全库及 Godot 退出警告。
6. 源码编码专项 2 项中 1 项失败，定位到 PublicReplayViewer.gd:465 的 U+23F8 暂停字符；git show HEAD 同一位置已有该字符，文件不属于本任务改动，未修改。

HEAD 对照副本在 `.tmp/30thc-card-audit/head-reference/`，git archive 提取脚本/场景/测试，隔离配置去掉 autoload，并补所需原始卡、证书与 contracts；没有回退/覆盖工作区。

## 复现与回滚边界

```powershell
python scripts/tools/verify_30thc_bundle.py
& 'D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . -s scripts/tools/audit_tcg_mik_snapshot.gd
& 'D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . -s tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_30thc_cards.gd
$cardSuites = @(Get-ChildItem tests -File | Where-Object { $_.Name -match '^test_csv(9|10)c.*\.gd$' } | ForEach-Object { $_.BaseName -replace '^test_', '' -replace '_', '' })
$cardSuites += @('DamageCalculator','RuleValidator','GameStateMachine','BattleActionController','BattleActionControllerInvalidHints','Photo30thCelebrationCards')
& 'D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . -s tests/FunctionalTestRunner.gd -- ('--suite=' + ($cardSuites -join ','))
```

快照工具 `snapshot_tcg_mik_product.py`、安装工具 `install_30thc_snapshot_batch.py` 使用 --help 查看参数；单批上限 5 张。重新抓取应先比较源变化，不要盲目覆盖审计版本。报告生成依赖本次 .tmp 冻结快照和最终日志。

回滚仅限本次新增的 138 张 30thC JSON/图片、对应 manifest 行、新增效果/注册/工具/测试/报告及相关引擎 hunk。保留 057 照片、同文件原有修改、策略包及其他用户工作。不要使用 git reset --hard 或整目录删除；本任务没有执行回滚。

## 逐卡源文本、实现与测试

“匹配/通过”是本次逐句审查结论，结合列出的注册及行为测试，不是仅凭注册存在自动认定。测试数量为关联函数数，并非每句规则独占一条测试。异画复用基础版行为测试并验证实际印刷数据；纯伤害/基本能量不虚构独立效果类。

### 001 蛋蛋

- 名称：蛋蛋；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`d1f3b4174792a4a51d66a96108302713`。
- 本地文件：[30thC_001.json](../data/bundled_user/cards/30thC_001.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 60, "energyType": "G", "weakness": {"energy": "R", "value": "×2"}, "resistance": null, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/001", "source_set_code": "30thC", "source_card_index": "001", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【无】 催眠术 
令对手的战斗宝可梦陷入【睡眠】状态。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 催眠术；cost=C；damage=；令对手的战斗宝可梦陷入【睡眠】状态。 | `res://scripts/effects/pokemon_effects/EffectApplyStatus.gd` | 通过 |

关联新增测试：

- [`test_30thc_001_sleep_and_003_owner_selected_switch`](../tests/test_30thc_cards.gd#L31)
- [`test_30thc_001_to_005_real_json_registration`](../tests/test_30thc_cards.gd#L107)

### 002 阿罗拉 椰蛋树

- 名称：阿罗拉 椰蛋树；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`c77d3be6b3f3347323cd1b3df86dde1d`。
- 本地文件：[30thC_002.json](../data/bundled_user/cards/30thC_002.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Stage 1", "evolvesFrom": "蛋蛋", "hp": 150, "energyType": "G", "weakness": {"energy": "R", "value": "×2"}, "resistance": null, "retreatCost": 4}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/002", "source_set_code": "30thC", "source_card_index": "002", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 1 项（含共享链路，非穷举缺陷数）；状态：已修复并验证。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
特性: 枝繁叶茂
如果这只宝可梦身上附着了6个及以上【草】能量的话，则这只宝可梦的最大HP「+250」。

【草】【无】【无】【无】 超级吸取 150
回复这只宝可梦「50」HP。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 特性 枝繁叶茂: 如果这只宝可梦身上附着了6个及以上【草】能量的话，则这只宝可梦的最大HP「+250」。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AbilityGrassEnergyHP` -> EffectProcessor/GSM | 通过 |
| 招式 0: 超级吸取；cost=GCCC；damage=150；回复这只宝可梦「50」HP。 | `res://scripts/effects/pokemon_effects/CSV9CSimpleHealSelfAfterAttack.gd` | 通过 |

关联新增测试：

- [`test_30thc_001_to_005_real_json_registration`](../tests/test_30thc_cards.gd#L107)
- [`test_30thc_002_exeggutor_hp_threshold_and_healing`](../tests/test_30thc_cards.gd#L823)

复审修复：

- 真实反转能量按供给单位计数；奖赏条件消失时 HP 加成随之失效。

### 003 电萤虫

- 名称：电萤虫；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`e47c3acd5fdeb66f6535ab4daca5ab28`。
- 本地文件：[30thC_003.json](../data/bundled_user/cards/30thC_003.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 80, "energyType": "G", "weakness": {"energy": "R", "value": "×2"}, "resistance": null, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/003", "source_set_code": "30thC", "source_card_index": "003", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【草】 引诱光芒 
选择对手的1只备战宝可梦，将其与战斗宝可梦互换。

【无】【无】【无】 虫鸣 90
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 引诱光芒；cost=G；damage=；选择对手的1只备战宝可梦，将其与战斗宝可梦互换。 | `res://scripts/effects/CSV10C101To200Effects.gd::AttackChooseOpponentBenchAsActive` | 通过 |
| 招式 1: 虫鸣；cost=CCC；damage=90； | `GameStateMachine.use_attack` -> `DamageCalculator`（纯伤害） | 通过 |

关联新增测试：

- [`test_30thc_001_sleep_and_003_owner_selected_switch`](../tests/test_30thc_cards.gd#L31)
- [`test_30thc_001_to_005_real_json_registration`](../tests/test_30thc_cards.gd#L107)

### 004 甜甜萤

- 名称：甜甜萤；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`392dd3f185cc878a05428f48fa76c736`。
- 本地文件：[30thC_004.json](../data/bundled_user/cards/30thC_004.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 80, "energyType": "G", "weakness": {"energy": "R", "value": "×2"}, "resistance": null, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/004", "source_set_code": "30thC", "source_card_index": "004", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
特性: 绝佳费洛蒙
如果自己场上有「电萤虫」的话，则能生效。只要这只宝可梦在场上，双方战斗宝可梦的弱点按「×3」计算伤害。

【草】【无】 冲撞 30
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 特性 绝佳费洛蒙: 如果自己场上有「电萤虫」的话，则能生效。只要这只宝可梦在场上，双方战斗宝可梦的弱点按「×3」计算伤害。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AbilityExcellentPheromone` -> EffectProcessor/GSM | 通过 |
| 招式 0: 冲撞；cost=GC；damage=30； | `GameStateMachine.use_attack` -> `DamageCalculator`（纯伤害） | 通过 |

关联新增测试：

- [`test_30thc_001_to_005_real_json_registration`](../tests/test_30thc_cards.gd#L107)
- [`test_30thc_004_illumise_weakness_both_players_not_bench`](../tests/test_30thc_cards.gd#L847)

### 005 彩粉蝶

- 名称：彩粉蝶；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`48e8990e5652874688fcd2ce0b8cf9e4`。
- 本地文件：[30thC_005.json](../data/bundled_user/cards/30thC_005.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Stage 2", "evolvesFrom": "粉蝶蛹", "hp": 120, "energyType": "G", "weakness": {"energy": "R", "value": "×2"}, "resistance": null, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/005", "source_set_code": "30thC", "source_card_index": "005", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 4 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 1 项（含共享链路，非穷举缺陷数）；状态：已修复并验证。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
特性: 指引之舞
在自己的回合可以使用1次。抛掷1次硬币，如果为正面，则选择自己牌库中的1张宝可梦，在给对手看过之后加入手牌。并重洗牌库。

【草】【无】 毒粉 60
令对手的战斗宝可梦陷入【中毒】状态。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 特性 指引之舞: 在自己的回合可以使用1次。抛掷1次硬币，如果为正面，则选择自己牌库中的1张宝可梦，在给对手看过之后加入手牌。并重洗牌库。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AbilityGuidingDance` -> EffectProcessor/GSM | 通过 |
| 招式 0: 毒粉；cost=GC；damage=60；令对手的战斗宝可梦陷入【中毒】状态。 | `res://scripts/effects/pokemon_effects/EffectApplyStatus.gd` | 通过 |

关联新增测试：

- [`test_30thc_005_vivillon_coin_visibility_turn_limit_and_ai_preview`](../tests/test_30thc_cards.gd#L63)
- [`test_30thc_001_to_005_real_json_registration`](../tests/test_30thc_cards.gd#L107)
- [`test_30thc_005_vivillon_rare_candy_without_stage_one_reference`](../tests/test_30thc_cards.gd#L2046)
- [`test_30thc_review_evolution_batch_one`](../tests/test_30thc_cards.gd#L1803)

复审修复：

- 普通进化及神奇糖果双路径；缺 Stage 1 实体时按稳定中英映射选择同线基础宝可梦，拒绝错误/当回合登场目标。

### 006 火焰鸟

- 名称：火焰鸟；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`efa2faba61d1b2cd26c7371fe79c23b0`。
- 本地文件：[30thC_006.json](../data/bundled_user/cards/30thC_006.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 120, "energyType": "R", "weakness": {"energy": "W", "value": "×2"}, "resistance": null, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/006", "source_set_code": "30thC", "source_card_index": "006", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 1 项（含共享链路，非穷举缺陷数）；状态：已修复并验证。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
特性: 燃烧展翼
如果自己场上有「急冻鸟」「闪电鸟」的话，则在自己的回合可以使用1次。选择自己手牌中的1张「基本【火】能量」，附着于这只宝可梦身上。

【火】【火】【无】 火焰旋涡 130
选择这只宝可梦身上附着的2个能量，放于弃牌区。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 特性 燃烧展翼: 如果自己场上有「急冻鸟」「闪电鸟」的话，则在自己的回合可以使用1次。选择自己手牌中的1张「基本【火】能量」，附着于这只宝可梦身上。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AbilityLegendaryBirdAttachment` -> EffectProcessor/GSM | 通过 |
| 招式 0: 火焰旋涡；cost=RRC；damage=130；选择这只宝可梦身上附着的2个能量，放于弃牌区。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackDiscardEnergyRequirements` | 通过 |

关联新增测试：

- [`test_30thc_006_to_010_real_json_registration`](../tests/test_30thc_cards.gd#L111)
- [`test_30thc_006_moltres_partners_attach_once_and_discard_two`](../tests/test_30thc_cards.gd#L169)

复审修复：

- 丢弃能量按供给单位而非卡片张数支付，逐步选择且拒绝重复引用。

### 007 凤王

- 名称：凤王；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`040aed788238e1f99d1278fa1ea1a7e7`。
- 本地文件：[30thC_007.json](../data/bundled_user/cards/30thC_007.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 130, "energyType": "R", "weakness": {"energy": "W", "value": "×2"}, "resistance": null, "retreatCost": 2}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/007", "source_set_code": "30thC", "source_card_index": "007", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【火】【火】 神圣气息 
将这只宝可梦身上附着的能量全部放于弃牌区。回复自己1只备战宝可梦的全部HP。

【火】【火】【火】 火焰之翼 100
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 神圣气息；cost=RR；damage=；将这只宝可梦身上附着的能量全部放于弃牌区。回复自己1只备战宝可梦的全部HP。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackSacredBreath` | 通过 |
| 招式 1: 火焰之翼；cost=RRR；damage=100； | `GameStateMachine.use_attack` -> `DamageCalculator`（纯伤害） | 通过 |

关联新增测试：

- [`test_30thc_006_to_010_real_json_registration`](../tests/test_30thc_cards.gd#L111)
- [`test_30thc_007_hooh_heals_only_selected_bench_discards_all_energy`](../tests/test_30thc_cards.gd#L197)

### 008 莱希拉姆

- 名称：莱希拉姆；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`eca20db642e6e7ab1af841dc90d9b347`。
- 本地文件：[30thC_008.json](../data/bundled_user/cards/30thC_008.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 130, "energyType": "R", "weakness": {"energy": "W", "value": "×2"}, "resistance": null, "retreatCost": 2}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/008", "source_set_code": "30thC", "source_card_index": "008", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【火】【无】 劈开 50


【火】【无】【无】 镭射火焰 80+
如果这只宝可梦身上附着了【雷】能量的话，则追加造成80伤害。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 劈开；cost=RC；damage=50； | `GameStateMachine.use_attack` -> `DamageCalculator`（纯伤害） | 通过 |
| 招式 1: 镭射火焰；cost=RCC；damage=80+；如果这只宝可梦身上附着了【雷】能量的话，则追加造成80伤害。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackAttachedTypeBonus` | 通过 |

关联新增测试：

- [`test_30thc_006_to_010_real_json_registration`](../tests/test_30thc_cards.gd#L111)
- [`test_30thc_008_reshiram_lightning_bonus_actual_damage`](../tests/test_30thc_cards.gd#L217)

### 009 呆火鳄ex

- 名称：呆火鳄ex；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`4c6d5da418dfa92f148946c38e0227c6`。
- 本地文件：[30thC_009.json](../data/bundled_user/cards/30thC_009.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 210, "energyType": "R", "weakness": {"energy": "W", "value": "×2"}, "resistance": null, "retreatCost": 2}。
- mechanic / ancient_trait / is_tags：{"mechanic": "ex", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/009", "source_set_code": "30thC", "source_card_index": "009", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【火】 致焦 
令对手的战斗宝可梦陷入【灼伤】状态。

【火】【火】【无】 愉快火焰 70×
造成自己已经获得的奖赏卡张数×70伤害。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 致焦；cost=R；damage=；令对手的战斗宝可梦陷入【灼伤】状态。 | `res://scripts/effects/pokemon_effects/EffectApplyStatus.gd` | 通过 |
| 招式 1: 愉快火焰；cost=RRC；damage=70×；造成自己已经获得的奖赏卡张数×70伤害。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackOwnTakenPrizeMultiplier` | 通过 |

关联新增测试：

- [`test_30thc_006_to_010_real_json_registration`](../tests/test_30thc_cards.gd#L111)
- [`test_30thc_009_fuecoco_uses_own_taken_prizes_zero_and_two`](../tests/test_30thc_cards.gd#L229)

### 010 呆呆兽

- 名称：呆呆兽；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`2240b955de9bb9bf1339f846e023f1e7`。
- 本地文件：[30thC_010.json](../data/bundled_user/cards/30thC_010.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 80, "energyType": "W", "weakness": {"energy": "L", "value": "×2"}, "resistance": null, "retreatCost": 2}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/010", "source_set_code": "30thC", "source_card_index": "010", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【无】 躲入井中 
抛掷1次硬币，如果为正面，则在下一个对手的回合，这只宝可梦不会受到招式的伤害和效果影响。

【水】【无】 水枪 20
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 躲入井中；cost=C；damage=；抛掷1次硬币，如果为正面，则在下一个对手的回合，这只宝可梦不会受到招式的伤害和效果影响。 | `res://scripts/effects/pokemon_effects/AttackCoinFlipPreventDamageAndEffectsNextTurn.gd` | 通过 |
| 招式 1: 水枪；cost=WC；damage=20； | `GameStateMachine.use_attack` -> `DamageCalculator`（纯伤害） | 通过 |

关联新增测试：

- [`test_30thc_006_to_010_real_json_registration`](../tests/test_30thc_cards.gd#L111)
- [`test_30thc_010_slowpoke_protection_coin_and_expiry`](../tests/test_30thc_cards.gd#L242)

### 011 拉普拉斯

- 名称：拉普拉斯；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`fcdfdf2c053d45b97f98ac821dbdf7a8`。
- 本地文件：[30thC_011.json](../data/bundled_user/cards/30thC_011.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 130, "energyType": "W", "weakness": {"energy": "M", "value": "×2"}, "resistance": null, "retreatCost": 2}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": ["Rapid Strike"]}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/011", "source_set_code": "30thC", "source_card_index": "011", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【无】 乘载游动 
选择自己牌库中的1张支援者，在给对手看过之后加入手牌。并重洗牌库。

【水】【无】【无】 冰冻光束 80
抛掷1次硬币，如果为正面，则令对手的战斗宝可梦陷入【麻痹】状态。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 乘载游动；cost=C；damage=；选择自己牌库中的1张支援者，在给对手看过之后加入手牌。并重洗牌库。 | `res://scripts/effects/pokemon_effects/AttackSearchDeckToHand.gd` | 通过 |
| 招式 1: 冰冻光束；cost=WCC；damage=80；抛掷1次硬币，如果为正面，则令对手的战斗宝可梦陷入【麻痹】状态。 | `res://scripts/effects/pokemon_effects/EffectApplyStatus.gd` | 通过 |

关联新增测试：

- [`test_30thc_011_to_015_real_json_registration`](../tests/test_30thc_cards.gd#L115)
- [`test_30thc_011_lapras_search_visibility_and_selected_supporter`](../tests/test_30thc_cards.gd#L289)

### 012 急冻鸟

- 名称：急冻鸟；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`831872607eca83307cb94cfa8afc7730`。
- 本地文件：[30thC_012.json](../data/bundled_user/cards/30thC_012.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 120, "energyType": "W", "weakness": {"energy": "M", "value": "×2"}, "resistance": null, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/012", "source_set_code": "30thC", "source_card_index": "012", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
特性: 冻结展翼
如果自己场上有「火焰鸟」「闪电鸟」的话，则在自己的回合可以使用1次。选择自己手牌中的1张「基本【水】能量」，附着于这只宝可梦身上。

【水】【水】【无】 冰雹 
给对手所有宝可梦各造成30伤害。[备战宝可梦不计算弱点、抗性。]
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 特性 冻结展翼: 如果自己场上有「火焰鸟」「闪电鸟」的话，则在自己的回合可以使用1次。选择自己手牌中的1张「基本【水】能量」，附着于这只宝可梦身上。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AbilityLegendaryBirdAttachment` -> EffectProcessor/GSM | 通过 |
| 招式 0: 冰雹；cost=WWC；damage=；给对手所有宝可梦各造成30伤害。[备战宝可梦不计算弱点、抗性。] | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackHail` | 通过 |

关联新增测试：

- [`test_30thc_011_to_015_real_json_registration`](../tests/test_30thc_cards.gd#L115)
- [`test_30thc_012_articuno_hail_active_weakness_and_bench_no_weakness`](../tests/test_30thc_cards.gd#L311)

### 013 盖欧卡

- 名称：盖欧卡；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`35da9bccad39223d970a5dcaade97abf`。
- 本地文件：[30thC_013.json](../data/bundled_user/cards/30thC_013.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 140, "energyType": "W", "weakness": {"energy": "L", "value": "×2"}, "resistance": null, "retreatCost": 4}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/013", "source_set_code": "30thC", "source_card_index": "013", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【无】【无】【无】【无】 水炮 60+
追加造成这只宝可梦身上附着的【水】能量数量×30伤害。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 水炮；cost=CCCC；damage=60+；追加造成这只宝可梦身上附着的【水】能量数量×30伤害。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackWaterEnergyBonus` | 通过 |

关联新增测试：

- [`test_30thc_011_to_015_real_json_registration`](../tests/test_30thc_cards.gd#L115)
- [`test_30thc_013_kyogre_water_energy_damage_before_weakness`](../tests/test_30thc_cards.gd#L326)

### 014 帕路奇亚

- 名称：帕路奇亚；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`1bb5d4a79e97af758bb961e3501b26a7`。
- 本地文件：[30thC_014.json](../data/bundled_user/cards/30thC_014.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 130, "energyType": "W", "weakness": {"energy": "L", "value": "×2"}, "resistance": null, "retreatCost": 2}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/014", "source_set_code": "30thC", "source_card_index": "014", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【水】【水】【无】 虫洞 100
将这只宝可梦与备战宝可梦互换。然后，对手将其战斗宝可梦与备战宝可梦互换。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 虫洞；cost=WWC；damage=100；将这只宝可梦与备战宝可梦互换。然后，对手将其战斗宝可梦与备战宝可梦互换。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackWormhole` | 通过 |

关联新增测试：

- [`test_30thc_011_to_015_real_json_registration`](../tests/test_30thc_cards.gd#L115)
- [`test_30thc_014_palkia_switches_both_sides_with_distinct_choosers`](../tests/test_30thc_cards.gd#L337)

### 015 甲贺忍蛙ex

- 名称：甲贺忍蛙ex；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`de1d3ab0a4a8f5e15498e7a5413c039c`。
- 本地文件：[30thC_015.json](../data/bundled_user/cards/30thC_015.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Stage 2", "evolvesFrom": "呱头蛙", "hp": 300, "energyType": "W", "weakness": {"energy": "L", "value": "×2"}, "resistance": null, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "ex", "ancient_trait": "Tera", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/015", "source_set_code": "30thC", "source_card_index": "015", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 3 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 1 项（含共享链路，非穷举缺陷数）；状态：已修复并验证。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【水】 隐秘斩 
给对手的1只宝可梦造成其身上放置的伤害指示物数量×30伤害。[备战宝可梦不计算弱点、抗性。]

【水】【水】 水流利刃 160
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 隐秘斩；cost=W；damage=；给对手的1只宝可梦造成其身上放置的伤害指示物数量×30伤害。[备战宝可梦不计算弱点、抗性。] | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackStealthSlash` | 通过 |
| 招式 1: 水流利刃；cost=WW；damage=160； | `GameStateMachine.use_attack` -> `DamageCalculator`（纯伤害） | 通过 |

关联新增测试：

- [`test_30thc_011_to_015_real_json_registration`](../tests/test_30thc_cards.gd#L115)
- [`test_30thc_015_greninja_scales_selected_targets_existing_counters`](../tests/test_30thc_cards.gd#L358)
- [`test_30thc_review_evolution_batch_one`](../tests/test_30thc_cards.gd#L1803)

复审修复：

- 普通进化及神奇糖果双路径；缺 Stage 1 实体时按稳定中英映射选择同线基础宝可梦，拒绝错误/当回合登场目标。

### 016 弱丁鱼

- 名称：弱丁鱼；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`2b88722cf752d07c0234a9dd2da0ca39`。
- 本地文件：[30thC_016.json](../data/bundled_user/cards/30thC_016.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 30, "energyType": "W", "weakness": {"energy": "L", "value": "×2"}, "resistance": null, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": ["Rapid Strike"]}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/016", "source_set_code": "30thC", "source_card_index": "016", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
特性: 群起反击
只要这只宝可梦在场上，自己战斗场上的「弱丁鱼（包含『宝可梦【ex】』）」受到对手宝可梦的招式的伤害时，就给使用了招式的宝可梦身上放置3个伤害指示物。

【水】 偷袭 30
抛掷1次硬币，如果为反面，则这个招式失败。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 特性 群起反击: 只要这只宝可梦在场上，自己战斗场上的「弱丁鱼（包含『宝可梦【ex】』）」受到对手宝可梦的招式的伤害时，就给使用了招式的宝可梦身上放置3个伤害指示物。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AbilitySchoolingRetaliation` -> EffectProcessor/GSM | 通过 |
| 招式 0: 偷袭；cost=W；damage=30；抛掷1次硬币，如果为反面，则这个招式失败。 | `res://scripts/effects/pokemon_effects/AttackCoinFlipOrFail.gd` | 通过 |

关联新增测试：

- [`test_30thc_016_to_020_real_json_registration`](../tests/test_30thc_cards.gd#L119)
- [`test_30thc_016_wishiwashi_bench_aura_stacks_only_on_named_active_damage`](../tests/test_30thc_cards.gd#L376)

### 017 皮卡丘

- 名称：皮卡丘；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`b67eb0b4a33026c81e8347de890f489f`。
- 本地文件：[30thC_017.json](../data/bundled_user/cards/30thC_017.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 70, "energyType": "L", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/017", "source_set_code": "30thC", "source_card_index": "017", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【雷】【无】 电击 20
抛掷1次硬币，如果为正面，则令对手的战斗宝可梦陷入【麻痹】状态。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 电击；cost=LC；damage=20；抛掷1次硬币，如果为正面，则令对手的战斗宝可梦陷入【麻痹】状态。 | `res://scripts/effects/pokemon_effects/EffectApplyStatus.gd` | 通过 |

关联新增测试：

- [`test_30thc_016_to_020_real_json_registration`](../tests/test_30thc_cards.gd#L119)
- [`test_30thc_017_pikachu_paralysis_heads_and_tails`](../tests/test_30thc_cards.gd#L398)

### 018 皮卡丘

- 名称：皮卡丘；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`0cce96ae9a96da81a435b8bc6b616d40`。
- 本地文件：[30thC_018.json](../data/bundled_user/cards/30thC_018.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 70, "energyType": "L", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/018", "source_set_code": "30thC", "source_card_index": "018", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【雷】【无】【无】 伏特攻击 80
给这只宝可梦也造成30伤害。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 伏特攻击；cost=LCC；damage=80；给这只宝可梦也造成30伤害。 | `res://scripts/effects/pokemon_effects/EffectSelfDamage.gd` | 通过 |

关联新增测试：

- [`test_30thc_016_to_020_real_json_registration`](../tests/test_30thc_cards.gd#L119)
- [`test_30thc_018_pikachu_recoil_and_019_selected_bench_damage`](../tests/test_30thc_cards.gd#L414)

### 019 皮卡丘

- 名称：皮卡丘；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`b4cd2c7e5bd5040d5b3809105f8411be`。
- 本地文件：[30thC_019.json](../data/bundled_user/cards/30thC_019.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 70, "energyType": "L", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 2}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/019", "source_set_code": "30thC", "source_card_index": "019", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【雷】【无】 电光 20
给对手的1只备战宝可梦也造成20伤害。[备战宝可梦不计算弱点、抗性。]
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 电光；cost=LC；damage=20；给对手的1只备战宝可梦也造成20伤害。[备战宝可梦不计算弱点、抗性。] | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackBenchTarget` | 通过 |

关联新增测试：

- [`test_30thc_016_to_020_real_json_registration`](../tests/test_30thc_cards.gd#L119)
- [`test_30thc_018_pikachu_recoil_and_019_selected_bench_damage`](../tests/test_30thc_cards.gd#L414)

### 020 皮卡丘

- 名称：皮卡丘；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`c24ad9eb6576efbeed0ac25016a926d7`。
- 本地文件：[30thC_020.json](../data/bundled_user/cards/30thC_020.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 70, "energyType": "L", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 2}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/020", "source_set_code": "30thC", "source_card_index": "020", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【无】 窥视 
查看对手的手牌。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 窥视；cost=C；damage=；查看对手的手牌。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackPeek` | 通过 |

关联新增测试：

- [`test_30thc_016_to_020_real_json_registration`](../tests/test_30thc_cards.gd#L119)
- [`test_30thc_020_pikachu_peek_reveals_hand_only_after_confirmation`](../tests/test_30thc_cards.gd#L432)

### 021 皮卡丘

- 名称：皮卡丘；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`728e4471a1c8d8d5ce730a31051f31a3`。
- 本地文件：[30thC_021.json](../data/bundled_user/cards/30thC_021.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 80, "energyType": "L", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 3}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/021", "source_set_code": "30thC", "source_card_index": "021", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【无】 稍事休息 
回复这只宝可梦「30」HP。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 稍事休息；cost=C；damage=；回复这只宝可梦「30」HP。 | `res://scripts/effects/pokemon_effects/CSV9CSimpleHealSelfAfterAttack.gd` | 通过 |

关联新增测试：

- [`test_30thc_021_to_025_real_json_registration`](../tests/test_30thc_cards.gd#L123)
- [`test_30thc_021_heal_023_search_and_024_025_vanilla_damage`](../tests/test_30thc_cards.gd#L451)

### 022 皮卡丘

- 名称：皮卡丘；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`cf9419068cb1df6aec5ad050d16039fb`。
- 本地文件：[30thC_022.json](../data/bundled_user/cards/30thC_022.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 60, "energyType": "L", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/022", "source_set_code": "30thC", "source_card_index": "022", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
特性: 孤寂视线
只要这只宝可梦在战斗场上，对手战斗宝可梦所使用的招式的伤害「-20」。

【雷】【无】 皮卡球 20
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 特性 孤寂视线: 只要这只宝可梦在战斗场上，对手战斗宝可梦所使用的招式的伤害「-20」。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AbilityLonelyGaze` -> EffectProcessor/GSM | 通过 |
| 招式 0: 皮卡球；cost=LC；damage=20； | `GameStateMachine.use_attack` -> `DamageCalculator`（纯伤害） | 通过 |

关联新增测试：

- [`test_30thc_021_to_025_real_json_registration`](../tests/test_30thc_cards.gd#L123)
- [`test_30thc_022_lonely_gaze_outgoing_reduction_before_weakness_and_bench`](../tests/test_30thc_cards.gd#L471)

### 023 皮卡丘

- 名称：皮卡丘；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`87dc2fa8cddd65cd238e462f2238e000`。
- 本地文件：[30thC_023.json](../data/bundled_user/cards/30thC_023.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 60, "energyType": "L", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/023", "source_set_code": "30thC", "source_card_index": "023", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【无】 找朋友 
选择自己牌库中的1张宝可梦，在给对手看过之后加入手牌。并重洗牌库。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 找朋友；cost=C；damage=；选择自己牌库中的1张宝可梦，在给对手看过之后加入手牌。并重洗牌库。 | `res://scripts/effects/pokemon_effects/AttackSearchDeckToHand.gd` | 通过 |

关联新增测试：

- [`test_30thc_021_to_025_real_json_registration`](../tests/test_30thc_cards.gd#L123)
- [`test_30thc_021_heal_023_search_and_024_025_vanilla_damage`](../tests/test_30thc_cards.gd#L451)

### 024 皮卡丘

- 名称：皮卡丘；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`3d2fc8522ca3ddac6c4db2801923e5b5`。
- 本地文件：[30thC_024.json](../data/bundled_user/cards/30thC_024.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 60, "energyType": "L", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/024", "source_set_code": "30thC", "source_card_index": "024", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【雷】 音速伏特 30
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 音速伏特；cost=L；damage=30； | `GameStateMachine.use_attack` -> `DamageCalculator`（纯伤害） | 通过 |

关联新增测试：

- [`test_30thc_021_to_025_real_json_registration`](../tests/test_30thc_cards.gd#L123)
- [`test_30thc_021_heal_023_search_and_024_025_vanilla_damage`](../tests/test_30thc_cards.gd#L451)

### 025 皮卡丘

- 名称：皮卡丘；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`eaeb8eb1ce00137885bc19a7a1eef109`。
- 本地文件：[30thC_025.json](../data/bundled_user/cards/30thC_025.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 50, "energyType": "L", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 0}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/025", "source_set_code": "30thC", "source_card_index": "025", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【无】 啃咬 10
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 啃咬；cost=C；damage=10； | `GameStateMachine.use_attack` -> `DamageCalculator`（纯伤害） | 通过 |

关联新增测试：

- [`test_30thc_021_to_025_real_json_registration`](../tests/test_30thc_cards.gd#L123)
- [`test_30thc_021_heal_023_search_and_024_025_vanilla_damage`](../tests/test_30thc_cards.gd#L451)

### 026 皮卡丘

- 名称：皮卡丘；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`5caef03379545b126b26ba32fa3900d8`。
- 本地文件：[30thC_026.json](../data/bundled_user/cards/30thC_026.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 50, "energyType": "L", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/026", "source_set_code": "30thC", "source_card_index": "026", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【无】 逃窜 
将这只宝可梦与备战宝可梦互换。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 逃窜；cost=C；damage=；将这只宝可梦与备战宝可梦互换。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackMandatorySelfSwitch` | 通过 |

关联新增测试：

- [`test_30thc_026_to_030_real_json_registration`](../tests/test_30thc_cards.gd#L127)
- [`test_30thc_026_switch_029_vanilla_030_recoil`](../tests/test_30thc_cards.gd#L491)

### 027 皮卡丘

- 名称：皮卡丘；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`6198144fca9bc57c5ffa06bcac4c1933`。
- 本地文件：[30thC_027.json](../data/bundled_user/cards/30thC_027.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 60, "energyType": "L", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/027", "source_set_code": "30thC", "source_card_index": "027", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 1 项（含共享链路，非穷举缺陷数）；状态：已修复并验证。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
特性: 藏身
只要这只宝可梦在备战区，就不会受到对手宝可梦的招式的伤害和效果影响。

【雷】 小型电击 10
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 特性 藏身: 只要这只宝可梦在备战区，就不会受到对手宝可梦的招式的伤害和效果影响。 | `res://scripts/effects/pokemon_effects/AbilityBenchImmune.gd` -> EffectProcessor/GSM | 通过 |
| 招式 0: 小型电击；cost=L；damage=10； | `GameStateMachine.use_attack` -> `DamageCalculator`（纯伤害） | 通过 |

关联新增测试：

- [`test_30thc_026_to_030_real_json_registration`](../tests/test_30thc_cards.gd#L127)
- [`test_30thc_027_hide_bench_only_damage_and_effect_protection`](../tests/test_30thc_cards.gd#L509)

复审修复：

- 备战伤害与放置伤害指示物/退化等效果保护分开接线，压制后不保护。

### 028 皮卡丘

- 名称：皮卡丘；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`b16f2a48835dd0ee4f9b7a5718feb46f`。
- 本地文件：[30thC_028.json](../data/bundled_user/cards/30thC_028.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 70, "energyType": "L", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 2}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/028", "source_set_code": "30thC", "source_card_index": "028", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【雷】【雷】【雷】 皮卡连锁 40×
造成自己场上的「皮卡丘（包含『宝可梦【ex】』）」数量×40伤害。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 皮卡连锁；cost=LLL；damage=40×；造成自己场上的「皮卡丘（包含『宝可梦【ex】』）」数量×40伤害。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackPikachuChain` | 通过 |

关联新增测试：

- [`test_30thc_026_to_030_real_json_registration`](../tests/test_30thc_cards.gd#L127)
- [`test_30thc_028_pikachu_chain_counts_exact_pikachu_and_ex`](../tests/test_30thc_cards.gd#L526)

### 029 皮卡丘

- 名称：皮卡丘；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`22ce184c779135e052d5b450abfd9e8c`。
- 本地文件：[30thC_029.json](../data/bundled_user/cards/30thC_029.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 60, "energyType": "L", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/029", "source_set_code": "30thC", "source_card_index": "029", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【无】【无】 滚动 30
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 滚动；cost=CC；damage=30； | `GameStateMachine.use_attack` -> `DamageCalculator`（纯伤害） | 通过 |

关联新增测试：

- [`test_30thc_026_to_030_real_json_registration`](../tests/test_30thc_cards.gd#L127)
- [`test_30thc_026_switch_029_vanilla_030_recoil`](../tests/test_30thc_cards.gd#L491)

### 030 皮卡丘

- 名称：皮卡丘；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`e744c180a78847f1fb4c25eadc3c08dd`。
- 本地文件：[30thC_030.json](../data/bundled_user/cards/30thC_030.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 70, "energyType": "L", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 2}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/030", "source_set_code": "30thC", "source_card_index": "030", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【雷】【无】 小小莽撞 40
给这只宝可梦也造成10伤害。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 小小莽撞；cost=LC；damage=40；给这只宝可梦也造成10伤害。 | `res://scripts/effects/pokemon_effects/EffectSelfDamage.gd` | 通过 |

关联新增测试：

- [`test_30thc_026_to_030_real_json_registration`](../tests/test_30thc_cards.gd#L127)
- [`test_30thc_026_switch_029_vanilla_030_recoil`](../tests/test_30thc_cards.gd#L491)

### 031 皮卡丘

- 名称：皮卡丘；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`8466088fd32e6b7496ce3462a6e65aff`。
- 本地文件：[30thC_031.json](../data/bundled_user/cards/30thC_031.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 70, "energyType": "L", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/031", "source_set_code": "30thC", "source_card_index": "031", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【无】 能量之尾 
选择自己牌库中的1张能量，在给对手看过之后加入手牌。并重洗牌库。

【雷】【无】 皮卡拳 30
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 能量之尾；cost=C；damage=；选择自己牌库中的1张能量，在给对手看过之后加入手牌。并重洗牌库。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackSearchEnergy` | 通过 |
| 招式 1: 皮卡拳；cost=LC；damage=30； | `GameStateMachine.use_attack` -> `DamageCalculator`（纯伤害） | 通过 |

关联新增测试：

- [`test_30thc_031_to_035_real_json_registration`](../tests/test_30thc_cards.gd#L131)
- [`test_30thc_031_search_basic_or_special_energy_and_032_035_damage`](../tests/test_30thc_cards.gd#L540)

### 032 皮卡丘

- 名称：皮卡丘；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`ed842de73ebe6fb24ce3236e371fa49d`。
- 本地文件：[30thC_032.json](../data/bundled_user/cards/30thC_032.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 60, "energyType": "L", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/032", "source_set_code": "30thC", "source_card_index": "032", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 1 项（含共享链路，非穷举缺陷数）；状态：已修复并验证。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【雷】 瞄准电光 
给对手的1只宝可梦造成20伤害。[备战宝可梦不计算弱点、抗性。]
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 瞄准电光；cost=L；damage=；给对手的1只宝可梦造成20伤害。[备战宝可梦不计算弱点、抗性。] | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackAnyTargetFixed` | 通过 |

关联新增测试：

- [`test_30thc_031_to_035_real_json_registration`](../tests/test_30thc_cards.gd#L131)
- [`test_30thc_031_search_basic_or_special_energy_and_032_035_damage`](../tests/test_30thc_cards.gd#L540)

复审修复：

- 指定目标伤害补齐伤害事件、生存道具及手持风扇反应；Headless 保留防守方选择窗口。

### 033 皮卡丘

- 名称：皮卡丘；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`6299b6e51aaec31bb5b709b318f9c956`。
- 本地文件：[30thC_033.json](../data/bundled_user/cards/30thC_033.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 70, "energyType": "L", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/033", "source_set_code": "30thC", "source_card_index": "033", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【无】 铁尾 20×
抛掷硬币直到出现反面，造成正面次数×20伤害。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 铁尾；cost=C；damage=20×；抛掷硬币直到出现反面，造成正面次数×20伤害。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackIronTail` | 通过 |

关联新增测试：

- [`test_30thc_031_to_035_real_json_registration`](../tests/test_30thc_cards.gd#L131)
- [`test_30thc_033_iron_tail_coin_count_before_weakness_and_preview_no_rng`](../tests/test_30thc_cards.gd#L565)

### 034 皮卡丘

- 名称：皮卡丘；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`602b93b1b8f83af2c2ed08ed93715884`。
- 本地文件：[30thC_034.json](../data/bundled_user/cards/30thC_034.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 80, "energyType": "L", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 2}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/034", "source_set_code": "30thC", "source_card_index": "034", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【雷】 改写伏特 10
在下一个自己的回合结束前，受到这个招式影响的宝可梦的弱点变为【雷】属性。［弱点按「×2」计算伤害。］
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 改写伏特；cost=L；damage=10；在下一个自己的回合结束前，受到这个招式影响的宝可梦的弱点变为【雷】属性。［弱点按「×2」计算伤害。］ | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackRewriteVolt` | 通过 |

关联新增测试：

- [`test_30thc_031_to_035_real_json_registration`](../tests/test_30thc_cards.gd#L131)
- [`test_30thc_034_rewrite_weakness_expiry_evolution_and_leave_active`](../tests/test_30thc_cards.gd#L588)

### 035 皮卡丘

- 名称：皮卡丘；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`d7eb6471145eeef2d692563c27b91367`。
- 本地文件：[30thC_035.json](../data/bundled_user/cards/30thC_035.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 60, "energyType": "L", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/035", "source_set_code": "30thC", "source_card_index": "035", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【无】 垂吊 10


【雷】【无】【无】 电气踢 40
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 垂吊；cost=C；damage=10； | `GameStateMachine.use_attack` -> `DamageCalculator`（纯伤害） | 通过 |
| 招式 1: 电气踢；cost=LCC；damage=40； | `GameStateMachine.use_attack` -> `DamageCalculator`（纯伤害） | 通过 |

关联新增测试：

- [`test_30thc_031_to_035_real_json_registration`](../tests/test_30thc_cards.gd#L131)
- [`test_30thc_031_search_basic_or_special_energy_and_032_035_damage`](../tests/test_30thc_cards.gd#L540)

### 036 皮卡丘

- 名称：皮卡丘；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`7753f583491e6aae491e9774e2a778de`。
- 本地文件：[30thC_036.json](../data/bundled_user/cards/30thC_036.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 60, "energyType": "L", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/036", "source_set_code": "30thC", "source_card_index": "036", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 3 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 1 项（含共享链路，非穷举缺陷数）；状态：已修复并验证。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【无】 充电冲刺 
抛掷硬币直到出现反面，选择自己牌库中最多与出现正面次数相同数量的「基本【雷】能量」，附着于这只宝可梦身上。并重洗牌库。

【雷】【雷】【无】 皮卡伏特 50
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 充电冲刺；cost=C；damage=；抛掷硬币直到出现反面，选择自己牌库中最多与出现正面次数相同数量的「基本【雷】能量」，附着于这只宝可梦身上。并重洗牌库。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackChargeDash` | 通过 |
| 招式 1: 皮卡伏特；cost=LLC；damage=50； | `GameStateMachine.use_attack` -> `DamageCalculator`（纯伤害） | 通过 |

关联新增测试：

- [`test_30thc_036_to_040_real_json_registration`](../tests/test_30thc_cards.gd#L135)
- [`test_30thc_036_charge_dash_coin_limit_zero_and_two_no_special_energy`](../tests/test_30thc_cards.gd#L611)
- [`test_30thc_review_036_heads_whiff_still_opens_deck_search`](../tests/test_30thc_cards.gd#L1888)

复审修复：

- 抛币不被 AI 预览消耗；有正面但无基本雷能量时仍可查看己方牌库并空搜。

### 037 皮卡丘

- 名称：皮卡丘；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`707f8f3d4ef85eb5f679761bd0f89fa9`。
- 本地文件：[30thC_037.json](../data/bundled_user/cards/30thC_037.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 70, "energyType": "L", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 2}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/037", "source_set_code": "30thC", "source_card_index": "037", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【无】【无】 南国心境 
令这只宝可梦陷入【睡眠】状态。从牌库上方抽取卡牌，直到自己的手牌变为6张为止。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 南国心境；cost=CC；damage=；令这只宝可梦陷入【睡眠】状态。从牌库上方抽取卡牌，直到自己的手牌变为6张为止。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackTropicalMood` | 通过 |

关联新增测试：

- [`test_30thc_036_to_040_real_json_registration`](../tests/test_30thc_cards.gd#L135)
- [`test_30thc_037_tropical_mood_sleep_then_draw_to_six_or_full_hand`](../tests/test_30thc_cards.gd#L646)

### 038 皮卡丘

- 名称：皮卡丘；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`215450d0afa5da811b5be9f24b779ad7`。
- 本地文件：[30thC_038.json](../data/bundled_user/cards/30thC_038.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 60, "energyType": "L", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/038", "source_set_code": "30thC", "source_card_index": "038", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【无】 高速移动 10
抛掷1次硬币，如果为正面，则在下一个对手的回合，这只宝可梦不会受到招式的伤害和效果影响。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 高速移动；cost=C；damage=10；抛掷1次硬币，如果为正面，则在下一个对手的回合，这只宝可梦不会受到招式的伤害和效果影响。 | `res://scripts/effects/pokemon_effects/AttackCoinFlipPreventDamageAndEffectsNextTurn.gd` | 通过 |

关联新增测试：

- [`test_30thc_036_to_040_real_json_registration`](../tests/test_30thc_cards.gd#L135)
- [`test_30thc_038_agility_039_draw_040_cure`](../tests/test_30thc_cards.gd#L665)

### 039 皮卡丘

- 名称：皮卡丘；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`86c2e2cd7c5443dd1ad6e3a0b7bcf6cc`。
- 本地文件：[30thC_039.json](../data/bundled_user/cards/30thC_039.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 60, "energyType": "L", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/039", "source_set_code": "30thC", "source_card_index": "039", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【无】 夜间散步 
从自己牌库上方抽取1张卡牌。

【雷】【无】 劈啪作响 20
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 夜间散步；cost=C；damage=；从自己牌库上方抽取1张卡牌。 | `res://scripts/effects/pokemon_effects/AttackDrawCards.gd` | 通过 |
| 招式 1: 劈啪作响；cost=LC；damage=20； | `GameStateMachine.use_attack` -> `DamageCalculator`（纯伤害） | 通过 |

关联新增测试：

- [`test_30thc_036_to_040_real_json_registration`](../tests/test_30thc_cards.gd#L135)
- [`test_30thc_038_agility_039_draw_040_cure`](../tests/test_30thc_cards.gd#L665)

### 040 皮卡丘

- 名称：皮卡丘；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`b53b2abedf7bf024e0b886b1e64c7e8e`。
- 本地文件：[30thC_040.json](../data/bundled_user/cards/30thC_040.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 60, "energyType": "L", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/040", "source_set_code": "30thC", "source_card_index": "040", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【无】 迎风 
恢复这只宝可梦的全部特殊状态。

【无】【无】 踢飞 20
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 迎风；cost=C；damage=；恢复这只宝可梦的全部特殊状态。 | `res://scripts/effects/pokemon_effects/AttackClearOwnStatus.gd` | 通过 |
| 招式 1: 踢飞；cost=CC；damage=20； | `GameStateMachine.use_attack` -> `DamageCalculator`（纯伤害） | 通过 |

关联新增测试：

- [`test_30thc_036_to_040_real_json_registration`](../tests/test_30thc_cards.gd#L135)
- [`test_30thc_038_agility_039_draw_040_cure`](../tests/test_30thc_cards.gd#L665)

### 041 皮卡丘

- 名称：皮卡丘；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`eca0671907dac835ac5b50bb62c630c3`。
- 本地文件：[30thC_041.json](../data/bundled_user/cards/30thC_041.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 70, "energyType": "L", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/041", "source_set_code": "30thC", "source_card_index": "041", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【无】 嬉闹 10+
抛掷1次硬币，如果为正面，则追加造成20伤害。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 嬉闹；cost=C；damage=10+；抛掷1次硬币，如果为正面，则追加造成20伤害。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackPlayRough` | 通过 |

关联新增测试：

- [`test_30thc_041_to_045_real_json_registration`](../tests/test_30thc_cards.gd#L139)
- [`test_30thc_041_play_rough_bonus_before_weakness`](../tests/test_30thc_cards.gd#L688)

### 042 皮卡丘

- 名称：皮卡丘；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`2abf73288ff5b3acd4652dcf84641f96`。
- 本地文件：[30thC_042.json](../data/bundled_user/cards/30thC_042.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 70, "energyType": "L", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/042", "source_set_code": "30thC", "source_card_index": "042", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【无】 积攒 
选择自己弃牌区中最多2张基本能量，在给对手看过之后加入手牌。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 积攒；cost=C；damage=；选择自己弃牌区中最多2张基本能量，在给对手看过之后加入手牌。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackCollectBasicEnergy` | 通过 |

关联新增测试：

- [`test_30thc_041_to_045_real_json_registration`](../tests/test_30thc_cards.gd#L139)
- [`test_30thc_042_collect_recovers_up_to_two_basic_energy_not_special`](../tests/test_30thc_cards.gd#L706)

### 043 皮卡丘

- 名称：皮卡丘；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`53f077cda92c302a72e7f6ab5e57798b`。
- 本地文件：[30thC_043.json](../data/bundled_user/cards/30thC_043.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 80, "energyType": "L", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 3}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/043", "source_set_code": "30thC", "source_card_index": "043", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【雷】【无】【无】 斗志惊雷 20+
如果对手的战斗宝可梦是「宝可梦【ex】」的话，则追加造成80伤害。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 斗志惊雷；cost=LCC；damage=20+；如果对手的战斗宝可梦是「宝可梦【ex】」的话，则追加造成80伤害。 | `res://scripts/effects/pokemon_effects/AttackBonusIfDefenderMechanic.gd` | 通过 |

关联新增测试：

- [`test_30thc_041_to_045_real_json_registration`](../tests/test_30thc_cards.gd#L139)
- [`test_30thc_043_ex_bonus_044_printed_damage_and_045_discard_lightning_only`](../tests/test_30thc_cards.gd#L724)

### 044 皮卡丘

- 名称：皮卡丘；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`48eaa3fb9a0ead744c6c4cb75e08c2c9`。
- 本地文件：[30thC_044.json](../data/bundled_user/cards/30thC_044.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 80, "energyType": "L", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 3}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/044", "source_set_code": "30thC", "source_card_index": "044", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【雷】【雷】【无】【无】 满足电光 100
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 满足电光；cost=LLCC；damage=100； | `GameStateMachine.use_attack` -> `DamageCalculator`（纯伤害） | 通过 |

关联新增测试：

- [`test_30thc_041_to_045_real_json_registration`](../tests/test_30thc_cards.gd#L139)
- [`test_30thc_043_ex_bonus_044_printed_damage_and_045_discard_lightning_only`](../tests/test_30thc_cards.gd#L724)

### 045 皮卡丘

- 名称：皮卡丘；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`ae37c5bd0e12492200c33c025fd686cb`。
- 本地文件：[30thC_045.json](../data/bundled_user/cards/30thC_045.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 70, "energyType": "L", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 2}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/045", "source_set_code": "30thC", "source_card_index": "045", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【雷】【雷】【雷】 雷电坠击 
将这只宝可梦身上附着的【雷】能量全部放于弃牌区，给对手的1只宝可梦造成90伤害。[备战宝可梦不计算弱点、抗性。]
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 雷电坠击；cost=LLL；damage=；将这只宝可梦身上附着的【雷】能量全部放于弃牌区，给对手的1只宝可梦造成90伤害。[备战宝可梦不计算弱点、抗性。] | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackThunderCrash` | 通过 |

关联新增测试：

- [`test_30thc_041_to_045_real_json_registration`](../tests/test_30thc_cards.gd#L139)
- [`test_30thc_043_ex_bonus_044_printed_damage_and_045_discard_lightning_only`](../tests/test_30thc_cards.gd#L724)

### 046 皮卡丘

- 名称：皮卡丘；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`df07c7c9e66ddd482c9f94cd9015ba3c`。
- 本地文件：[30thC_046.json](../data/bundled_user/cards/30thC_046.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 70, "energyType": "L", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/046", "source_set_code": "30thC", "source_card_index": "046", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【雷】 愤恨伏特 10+
追加造成这只宝可梦身上放置的伤害指示物数量×10伤害。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 愤恨伏特；cost=L；damage=10+；追加造成这只宝可梦身上放置的伤害指示物数量×10伤害。 | `res://scripts/effects/pokemon_effects/AttackSelfDamageCounterBonus.gd` | 通过 |

关联新增测试：

- [`test_30thc_046_to_050_real_json_registration`](../tests/test_30thc_cards.gd#L143)
- [`test_30thc_046_damage_counters_049_recoil_050_fire_bonus`](../tests/test_30thc_cards.gd#L755)

### 047 皮卡丘ex

- 名称：皮卡丘ex；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`2418309668a6102d250f4bdb4fd89742`。
- 本地文件：[30thC_047.json](../data/bundled_user/cards/30thC_047.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 190, "energyType": "L", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "ex", "ancient_trait": "Tera", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/047", "source_set_code": "30thC", "source_card_index": "047", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【无】 皮卡巡游 
选择自己牌库中任意数量的【基础】宝可梦，放于备战区。并重洗牌库。

【雷】【雷】【无】 十万伏特 200
将这只宝可梦身上附着的能量全部放于弃牌区。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 皮卡巡游；cost=C；damage=；选择自己牌库中任意数量的【基础】宝可梦，放于备战区。并重洗牌库。 | `res://scripts/effects/pokemon_effects/AttackCallForFamily.gd` | 通过 |
| 招式 1: 十万伏特；cost=LLC；damage=200；将这只宝可梦身上附着的能量全部放于弃牌区。 | `res://scripts/effects/pokemon_effects/AttackDiscardAllAttachedEnergyFromSelf.gd` | 通过 |

关联新增测试：

- [`test_30thc_046_to_050_real_json_registration`](../tests/test_30thc_cards.gd#L143)
- [`test_30thc_047_pika_parade_filters_and_fills_only_available_bench`](../tests/test_30thc_cards.gd#L774)

### 048 皮卡丘ex

- 名称：皮卡丘ex；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`a15ad334101499f5283f47631736ee1c`。
- 本地文件：[30thC_048.json](../data/bundled_user/cards/30thC_048.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 190, "energyType": "L", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "ex", "ancient_trait": "Tera", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/048", "source_set_code": "30thC", "source_card_index": "048", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【雷】 麻麻狂热 
选择自己手牌中任意数量的基本能量，以任意方式附着于自己的宝可梦身上。

【雷】【雷】【无】 打雷 200
给这只宝可梦也造成30伤害。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 麻麻狂热；cost=L；damage=；选择自己手牌中任意数量的基本能量，以任意方式附着于自己的宝可梦身上。 | `res://scripts/effects/CSV9CEffects.gd::AttackHandBasicEnergyAttach` | 通过 |
| 招式 1: 打雷；cost=LLC；damage=200；给这只宝可梦也造成30伤害。 | `res://scripts/effects/pokemon_effects/EffectSelfDamage.gd` | 通过 |

关联新增测试：

- [`test_30thc_046_to_050_real_json_registration`](../tests/test_30thc_cards.gd#L143)
- [`test_30thc_048_energy_fever_splits_only_basic_hand_energy_among_own_targets`](../tests/test_30thc_cards.gd#L797)

### 049 闪电鸟

- 名称：闪电鸟；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`23a00b18e1944b72ea1e1598affc5fe4`。
- 本地文件：[30thC_049.json](../data/bundled_user/cards/30thC_049.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 120, "energyType": "L", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/049", "source_set_code": "30thC", "source_card_index": "049", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
特性: 迸发展翼
如果自己场上有「火焰鸟」「急冻鸟」的话，则在自己的回合可以使用1次。选择自己手牌中的1张「基本【雷】能量」，附着于这只宝可梦身上。

【雷】【雷】【雷】【无】 雷轰 210
给这只宝可梦也造成60伤害。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 特性 迸发展翼: 如果自己场上有「火焰鸟」「急冻鸟」的话，则在自己的回合可以使用1次。选择自己手牌中的1张「基本【雷】能量」，附着于这只宝可梦身上。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AbilityLegendaryBirdAttachment` -> EffectProcessor/GSM | 通过 |
| 招式 0: 雷轰；cost=LLLC；damage=210；给这只宝可梦也造成60伤害。 | `res://scripts/effects/pokemon_effects/EffectSelfDamage.gd` | 通过 |

关联新增测试：

- [`test_30thc_046_to_050_real_json_registration`](../tests/test_30thc_cards.gd#L143)
- [`test_30thc_046_damage_counters_049_recoil_050_fire_bonus`](../tests/test_30thc_cards.gd#L755)

### 050 捷克罗姆

- 名称：捷克罗姆；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`67895895dd26e7d68e8854f48ff88e37`。
- 本地文件：[30thC_050.json](../data/bundled_user/cards/30thC_050.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 130, "energyType": "L", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 2}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/050", "source_set_code": "30thC", "source_card_index": "050", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【雷】【无】 劈开 50


【雷】【无】【无】 闪电焰袭 80+
如果这只宝可梦身上附着了【火】能量的话，则追加造成80伤害。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 劈开；cost=LC；damage=50； | `GameStateMachine.use_attack` -> `DamageCalculator`（纯伤害） | 通过 |
| 招式 1: 闪电焰袭；cost=LCC；damage=80+；如果这只宝可梦身上附着了【火】能量的话，则追加造成80伤害。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackAttachedTypeBonus` | 通过 |

关联新增测试：

- [`test_30thc_046_to_050_real_json_registration`](../tests/test_30thc_cards.gd#L143)
- [`test_30thc_046_damage_counters_049_recoil_050_fire_bonus`](../tests/test_30thc_cards.gd#L755)

### 051 颤弦蝾螈

- 名称：颤弦蝾螈；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`2210e38ce299e07646e3a1a67fc1b258`。
- 本地文件：[30thC_051.json](../data/bundled_user/cards/30thC_051.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Stage 1", "evolvesFrom": "电音婴", "hp": 140, "energyType": "L", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 2}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": ["Fusion Strike"]}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/051", "source_set_code": "30thC", "source_card_index": "051", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【雷】 殴打 40


【雷】【无】【无】 雷电伏特 150
在下一个自己的回合，这只宝可梦无法使用招式。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 殴打；cost=L；damage=40； | `GameStateMachine.use_attack` -> `DamageCalculator`（纯伤害） | 通过 |
| 招式 1: 雷电伏特；cost=LCC；damage=150；在下一个自己的回合，这只宝可梦无法使用招式。 | `res://scripts/effects/pokemon_effects/AttackSelfAllAttacksLockNextTurn.gd` | 通过 |

关联新增测试：

- [`test_30thc_051_to_055_real_json_registration`](../tests/test_30thc_cards.gd#L147)
- [`test_30thc_051_and_055_second_attack_locks_all_attacks`](../tests/test_30thc_cards.gd#L866)

### 052 莫鲁贝可

- 名称：莫鲁贝可；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`508470eb99327c31713a9a0543dbb5bc`。
- 本地文件：[30thC_052.json](../data/bundled_user/cards/30thC_052.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 70, "energyType": "L", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": ["Single Strike"]}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/052", "source_set_code": "30thC", "source_card_index": "052", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【无】 选点心 
将自己牌库上方3张卡牌放于弃牌区，选择其中1张卡牌，在给对手看过之后加入手牌。

【雷】 巴掌 30
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 选点心；cost=C；damage=；将自己牌库上方3张卡牌放于弃牌区，选择其中1张卡牌，在给对手看过之后加入手牌。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackPickSnack` | 通过 |
| 招式 1: 巴掌；cost=L；damage=30； | `GameStateMachine.use_attack` -> `DamageCalculator`（纯伤害） | 通过 |

关联新增测试：

- [`test_30thc_051_to_055_real_json_registration`](../tests/test_30thc_cards.gd#L147)
- [`test_30thc_052_snack_only_recovers_from_newly_milled_top_three`](../tests/test_30thc_cards.gd#L884)

### 053 密勒顿

- 名称：密勒顿；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`ab01ac05b94cfa923001e55a1dfde220`。
- 本地文件：[30thC_053.json](../data/bundled_user/cards/30thC_053.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 120, "energyType": "L", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": ["Future"]}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/053", "source_set_code": "30thC", "source_card_index": "053", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 1 项（含共享链路，非穷举缺陷数）；状态：已修复并验证。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【雷】 音速伏特 20


【雷】【雷】【无】 闪电猛冲 140
选择这只宝可梦身上附着的2个【雷】能量，放于弃牌区。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 音速伏特；cost=L；damage=20； | `GameStateMachine.use_attack` -> `DamageCalculator`（纯伤害） | 通过 |
| 招式 1: 闪电猛冲；cost=LLC；damage=140；选择这只宝可梦身上附着的2个【雷】能量，放于弃牌区。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackDiscardEnergyRequirements` | 通过 |

关联新增测试：

- [`test_30thc_051_to_055_real_json_registration`](../tests/test_30thc_cards.gd#L147)
- [`test_30thc_053_discards_selected_two_lightning_not_fire`](../tests/test_30thc_cards.gd#L903)

复审修复：

- 两个雷能量按有效供给单位支付，交互逐步收集所选能量。

### 054 超梦

- 名称：超梦；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`41d19b25408b67ee69dd56dc60f094f8`。
- 本地文件：[30thC_054.json](../data/bundled_user/cards/30thC_054.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 130, "energyType": "P", "weakness": {"energy": "D", "value": "×2"}, "resistance": {"energy": "F", "value": "-30"}, "retreatCost": 2}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/054", "source_set_code": "30thC", "source_card_index": "054", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【超】 给予力量 
选择自己弃牌区中最多2张基本能量，附着于自己的1只宝可梦身上。

【超】【超】【无】 精神驱动 120
选择这只宝可梦身上附着的1个能量，放于弃牌区。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 给予力量；cost=P；damage=；选择自己弃牌区中最多2张基本能量，附着于自己的1只宝可梦身上。 | `res://scripts/effects/pokemon_effects/AttackAttachBasicEnergyFromDiscard.gd` | 通过 |
| 招式 1: 精神驱动；cost=PPC；damage=120；选择这只宝可梦身上附着的1个能量，放于弃牌区。 | `res://scripts/effects/pokemon_effects/AttackDiscardAttachedEnergyFromSelf.gd` | 通过 |

关联新增测试：

- [`test_30thc_051_to_055_real_json_registration`](../tests/test_30thc_cards.gd#L147)
- [`test_30thc_054_energy_absorption_one_chosen_target`](../tests/test_30thc_cards.gd#L917)

### 055 超梦ex

- 名称：超梦ex；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`11641ee70b056fe9c3ef8d2e04ef6dd7`。
- 本地文件：[30thC_055.json](../data/bundled_user/cards/30thC_055.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 230, "energyType": "P", "weakness": {"energy": "D", "value": "×2"}, "resistance": {"energy": "F", "value": "-30"}, "retreatCost": 2}。
- mechanic / ancient_trait / is_tags：{"mechanic": "ex", "ancient_trait": "Tera", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/055", "source_set_code": "30thC", "source_card_index": "055", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 3 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【超】【超】 光子子弹 
给对手所有「宝可梦【ex】」各造成50伤害。[备战宝可梦不计算弱点、抗性。]

【超】【超】【超】 精神之力 230
在下一个自己的回合，这只宝可梦无法使用招式。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 光子子弹；cost=PP；damage=；给对手所有「宝可梦【ex】」各造成50伤害。[备战宝可梦不计算弱点、抗性。] | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackPhotonBullet` | 通过 |
| 招式 1: 精神之力；cost=PPP；damage=230；在下一个自己的回合，这只宝可梦无法使用招式。 | `res://scripts/effects/pokemon_effects/AttackSelfAllAttacksLockNextTurn.gd` | 通过 |

关联新增测试：

- [`test_30thc_051_to_055_real_json_registration`](../tests/test_30thc_cards.gd#L147)
- [`test_30thc_051_and_055_second_attack_locks_all_attacks`](../tests/test_30thc_cards.gd#L866)
- [`test_30thc_055_photon_bullet_hits_only_ex_with_active_weakness`](../tests/test_30thc_cards.gd#L933)

### 056 梦幻

- 名称：梦幻；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`91e47d789c8f695b74e59253913e15d2`。
- 本地文件：[30thC_056.json](../data/bundled_user/cards/30thC_056.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 60, "energyType": "P", "weakness": {"energy": "D", "value": "×2"}, "resistance": {"energy": "F", "value": "-30"}, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/056", "source_set_code": "30thC", "source_card_index": "056", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【超】【超】 精神强念 10+
追加造成对手战斗宝可梦身上附着的能量数量×40伤害。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 精神强念；cost=PP；damage=10+；追加造成对手战斗宝可梦身上附着的能量数量×40伤害。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackPsychic` | 通过 |

关联新增测试：

- [`test_30thc_056_to_060_real_json_registration`](../tests/test_30thc_cards.gd#L954)
- [`test_30thc_056_psychic_counts_energy_and_059_counts_distinct_basic_types`](../tests/test_30thc_cards.gd#L958)

### 057 梦幻ex

- 名称：Mew ex；英文=Mew ex；中文显示=梦幻ex。
- 类型=Pokemon；标记=J；源 effect_id=`dd6e658057478ff1eb223c71000b08a2`。
- 本地文件：[30THC_057.json](../data/bundled_user/cards/30THC_057.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 160, "energyType": "P", "weakness": {"energy": "D", "value": "×2"}, "resistance": {"energy": "F", "value": "-30"}, "retreatCost": 0}。
- mechanic / ancient_trait / is_tags：{"mechanic": "ex", "ancient_trait": "", "is_tags": ["Basic", "ex"]}。
- 来源字段：{"source_provider": "user_photo", "source_language": "zh-CN", "source_url": "https://www.serebii.net/card/30thcelebrationjapan/057.shtml", "source_set_code": "30th C", "source_card_index": "057", "source_prints": ["CN/30thC/057", "JP/M6a/057"], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
特性: 记忆螺旋
这只宝可梦可以使用自己备战宝可梦所拥有的全部招式。[需要满足使用招式所需能量。]

【超】 瞬移破坏 30
若希望，可以将这只宝可梦与备战宝可梦互换。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 特性 记忆螺旋: 这只宝可梦可以使用自己备战宝可梦所拥有的全部招式。[需要满足使用招式所需能量。] | `res://scripts/effects/pokemon_effects/AbilityOwnBenchAttacks.gd` -> EffectProcessor/GSM | 通过 |
| 招式 0: 瞬移破坏；cost=P；damage=30；若希望，可以将这只宝可梦与备战宝可梦互换。 | `res://scripts/effects/pokemon_effects/AttackSwitchSelfToBench.gd` | 通过 |

关联新增测试：

- [`test_30thc_056_to_060_real_json_registration`](../tests/test_30thc_cards.gd#L954)
- [`test_30thc_printings_135_mew_copies_real_unown_and_earns_extra_prize`](../tests/test_30thc_cards.gd#L2001)

### 058 太阳伊布

- 名称：太阳伊布；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`4e8f2003856715ec3ae5e5b65ebe2e75`。
- 本地文件：[30thC_058.json](../data/bundled_user/cards/30thC_058.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Stage 1", "evolvesFrom": "伊布", "hp": 110, "energyType": "P", "weakness": {"energy": "D", "value": "×2"}, "resistance": {"energy": "F", "value": "-30"}, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/058", "source_set_code": "30thC", "source_card_index": "058", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 1 项（含共享链路，非穷举缺陷数）；状态：已修复并验证。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【超】【无】 奇迹光芒 
从对手所有已经进化的宝可梦身上各移除1张「进化卡」使其退化。将被移除的卡牌放回对手的手牌。

【超】【无】【无】 超念力 90
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 奇迹光芒；cost=PC；damage=；从对手所有已经进化的宝可梦身上各移除1张「进化卡」使其退化。将被移除的卡牌放回对手的手牌。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackMiracleBeam` | 通过 |
| 招式 1: 超念力；cost=PCC；damage=90； | `GameStateMachine.use_attack` -> `DamageCalculator`（纯伤害） | 通过 |

关联新增测试：

- [`test_30thc_056_to_060_real_json_registration`](../tests/test_30thc_cards.gd#L954)
- [`test_30thc_058_returns_one_evolution_per_opponent_stack_to_hand`](../tests/test_30thc_cards.gd#L982)

复审修复：

- 退化清除特殊状态及效果、保留伤害，尊重备战特性和防止招式效果保护。

### 059 仙子伊布ex

- 名称：仙子伊布ex；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`c1adb66087005031a31ed27fb30dcd96`。
- 本地文件：[30thC_059.json](../data/bundled_user/cards/30thC_059.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Stage 1", "evolvesFrom": "伊布", "hp": 270, "energyType": "P", "weakness": {"energy": "M", "value": "×2"}, "resistance": null, "retreatCost": 2}。
- mechanic / ancient_trait / is_tags：{"mechanic": "ex", "ancient_trait": "Tera", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/059", "source_set_code": "30thC", "source_card_index": "059", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【超】【无】【无】 多彩和弦 50×
造成自己所有宝可梦身上附着的基本能量的属性种类数量×50伤害。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 多彩和弦；cost=PCC；damage=50×；造成自己所有宝可梦身上附着的基本能量的属性种类数量×50伤害。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackColorfulHarmony` | 通过 |

关联新增测试：

- [`test_30thc_056_to_060_real_json_registration`](../tests/test_30thc_cards.gd#L954)
- [`test_30thc_056_psychic_counts_energy_and_059_counts_distinct_basic_types`](../tests/test_30thc_cards.gd#L958)

### 060 未知图腾

- 名称：未知图腾；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`20f3bd0141978828bc0e191ce5090b98`。
- 本地文件：[30thC_060.json](../data/bundled_user/cards/30thC_060.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 80, "energyType": "P", "weakness": {"energy": "D", "value": "×2"}, "resistance": {"energy": "F", "value": "-30"}, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/060", "source_set_code": "30thC", "source_card_index": "060", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 1 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【超】【超】 神秘信号 40
如果对手的宝可梦受到这个招式的伤害而【昏厥】的话，则多拿取1张奖赏卡。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 神秘信号；cost=PP；damage=40；如果对手的宝可梦受到这个招式的伤害而【昏厥】的话，则多拿取1张奖赏卡。 | `res://scripts/effects/pokemon_effects/AttackExtraPrize.gd` | 通过 |

关联新增测试：

- [`test_30thc_056_to_060_real_json_registration`](../tests/test_30thc_cards.gd#L954)

### 061 飘飘球

- 名称：飘飘球；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`b813a0097cf2b40184888c03f51832fd`。
- 本地文件：[30thC_061.json](../data/bundled_user/cards/30thC_061.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 70, "energyType": "P", "weakness": {"energy": "D", "value": "×2"}, "resistance": {"energy": "F", "value": "-30"}, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/061", "source_set_code": "30thC", "source_card_index": "061", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 3 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 1 项（含共享链路，非穷举缺陷数）；状态：已修复并验证。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【超】 飘飘扬 20
若希望，可以将这只宝可梦以及放于其身上的全部的卡牌放回牌库并重洗牌库。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 飘飘扬；cost=P；damage=20；若希望，可以将这只宝可梦以及放于其身上的全部的卡牌放回牌库并重洗牌库。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackDrifloonReturn` | 通过 |

关联新增测试：

- [`test_30thc_061_to_065_real_json_registration`](../tests/test_30thc_cards.gd#L1001)
- [`test_30thc_061_optional_return_preserves_decline_and_selected_replacement`](../tests/test_30thc_cards.gd#L1005)
- [`test_30thc_review_061_last_pokemon_may_decline_or_return_and_lose`](../tests/test_30thc_cards.gd#L1940)

复审修复：

- 只剩这只宝可梦也可选择回牌库；可以放弃，选择返回则触发无宝可梦败北。

### 062 水晶灯火灵

- 名称：水晶灯火灵；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`035ac595564a924d0d2563f374e4adb9`。
- 本地文件：[30thC_062.json](../data/bundled_user/cards/30thC_062.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Stage 2", "evolvesFrom": "灯火幽灵", "hp": 140, "energyType": "P", "weakness": {"energy": "D", "value": "×2"}, "resistance": {"energy": "F", "value": "-30"}, "retreatCost": 2}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/062", "source_set_code": "30thC", "source_card_index": "062", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 3 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 1 项（含共享链路，非穷举缺陷数）；状态：已修复并验证。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【超】【超】 奇异灯火 130
令对手的战斗宝可梦陷入【灼伤】和【混乱】状态。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 奇异灯火；cost=PP；damage=130；令对手的战斗宝可梦陷入【灼伤】和【混乱】状态。 | `res://scripts/effects/pokemon_effects/EffectApplyStatus.gd`, `res://scripts/effects/pokemon_effects/EffectApplyStatus.gd` | 通过 |

关联新增测试：

- [`test_30thc_061_to_065_real_json_registration`](../tests/test_30thc_cards.gd#L1001)
- [`test_30thc_062_two_statuses_and_063_stadium_search_scope`](../tests/test_30thc_cards.gd#L1026)
- [`test_30thc_review_evolution_batch_one`](../tests/test_30thc_cards.gd#L1803)

复审修复：

- 普通进化及神奇糖果双路径；缺 Stage 1 实体时按稳定中英映射选择同线基础宝可梦，拒绝错误/当回合登场目标。

### 063 哲尔尼亚斯

- 名称：哲尔尼亚斯；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`7b1750e79eb2adf1fc8cc4ba79e713a3`。
- 本地文件：[30thC_063.json](../data/bundled_user/cards/30thC_063.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 120, "energyType": "P", "weakness": {"energy": "M", "value": "×2"}, "resistance": null, "retreatCost": 2}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/063", "source_set_code": "30thC", "source_card_index": "063", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【无】 大地导航 
选择自己牌库中最多2张竞技场，在给对手看过之后加入手牌。并重洗牌库。

【超】【超】【无】 极光角击 100
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 大地导航；cost=C；damage=；选择自己牌库中最多2张竞技场，在给对手看过之后加入手牌。并重洗牌库。 | `res://scripts/effects/pokemon_effects/AttackSearchDeckToHand.gd` | 通过 |
| 招式 1: 极光角击；cost=PPC；damage=100； | `GameStateMachine.use_attack` -> `DamageCalculator`（纯伤害） | 通过 |

关联新增测试：

- [`test_30thc_061_to_065_real_json_registration`](../tests/test_30thc_cards.gd#L1001)
- [`test_30thc_062_two_statuses_and_063_stadium_search_scope`](../tests/test_30thc_cards.gd#L1026)

### 064 科斯莫古

- 名称：科斯莫古；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`17c900feba1de0e2290e2310bb79731f`。
- 本地文件：[30thC_064.json](../data/bundled_user/cards/30thC_064.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 60, "energyType": "P", "weakness": {"energy": "D", "value": "×2"}, "resistance": {"energy": "F", "value": "-30"}, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/064", "source_set_code": "30thC", "source_card_index": "064", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【无】 跃起 10
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 跃起；cost=C；damage=10； | `GameStateMachine.use_attack` -> `DamageCalculator`（纯伤害） | 通过 |

关联新增测试：

- [`test_30thc_061_to_065_real_json_registration`](../tests/test_30thc_cards.gd#L1001)
- [`test_30thc_064_plain_damage_and_065_exact_reduction`](../tests/test_30thc_cards.gd#L1052)

### 065 科斯莫姆

- 名称：科斯莫姆；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`9163fc34feb6948638166d7d08e215a1`。
- 本地文件：[30thC_065.json](../data/bundled_user/cards/30thC_065.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Stage 1", "evolvesFrom": "科斯莫古", "hp": 100, "energyType": "P", "weakness": {"energy": "D", "value": "×2"}, "resistance": {"energy": "F", "value": "-30"}, "retreatCost": 3}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/065", "source_set_code": "30thC", "source_card_index": "065", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【无】【无】 硬邦邦 
在下一个对手的回合，这只宝可梦所受到的招式的伤害「-60」。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 硬邦邦；cost=CC；damage=；在下一个对手的回合，这只宝可梦所受到的招式的伤害「-60」。 | `res://scripts/effects/pokemon_effects/AttackReduceDamageNextTurn.gd` | 通过 |

关联新增测试：

- [`test_30thc_061_to_065_real_json_registration`](../tests/test_30thc_cards.gd#L1001)
- [`test_30thc_064_plain_damage_and_065_exact_reduction`](../tests/test_30thc_cards.gd#L1052)

### 066 露奈雅拉

- 名称：露奈雅拉；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`c8015fd4179304101ddb870edfffc872`。
- 本地文件：[30thC_066.json](../data/bundled_user/cards/30thC_066.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Stage 2", "evolvesFrom": "科斯莫姆", "hp": 160, "energyType": "P", "weakness": {"energy": "D", "value": "×2"}, "resistance": {"energy": "F", "value": "-30"}, "retreatCost": 2}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/066", "source_set_code": "30thC", "source_card_index": "066", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 3 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 1 项（含共享链路，非穷举缺陷数）；状态：已修复并验证。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【超】 午夜射线 20+
追加造成自己弃牌区中能量张数×20伤害。

【超】【无】【无】 月光爆破 120
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 午夜射线；cost=P；damage=20+；追加造成自己弃牌区中能量张数×20伤害。 | `res://scripts/effects/CSV9CEffects.gd::AttackDiscardPileEnergyBonus` | 通过 |
| 招式 1: 月光爆破；cost=PCC；damage=120； | `GameStateMachine.use_attack` -> `DamageCalculator`（纯伤害） | 通过 |

关联新增测试：

- [`test_30thc_066_to_070_real_json_registration`](../tests/test_30thc_cards.gd#L1065)
- [`test_30thc_066_discard_counts_cards_and_069_selected_bench_damage`](../tests/test_30thc_cards.gd#L1101)
- [`test_30thc_review_evolution_batch_one`](../tests/test_30thc_cards.gd#L1803)

复审修复：

- 普通进化及神奇糖果双路径；缺 Stage 1 实体时按稳定中英映射选择同线基础宝可梦，拒绝错误/当回合登场目标。

### 067 索财灵

- 名称：索财灵；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`9b7a3e1691f97e2d30d8437093c3500c`。
- 本地文件：[30thC_067.json](../data/bundled_user/cards/30thC_067.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 60, "energyType": "P", "weakness": {"energy": "D", "value": "×2"}, "resistance": {"energy": "F", "value": "-30"}, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/067", "source_set_code": "30thC", "source_card_index": "067", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【无】 多走走 
抛掷1次硬币，如果为正面，则选择自己牌库中任意1张卡牌，加入手牌。并重洗牌库。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 多走走；cost=C；damage=；抛掷1次硬币，如果为正面，则选择自己牌库中任意1张卡牌，加入手牌。并重洗牌库。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackCoinSearch` | 通过 |

关联新增测试：

- [`test_30thc_066_to_070_real_json_registration`](../tests/test_30thc_cards.gd#L1065)
- [`test_30thc_067_coin_search_heads_and_tails_visibility`](../tests/test_30thc_cards.gd#L1120)

### 068 固拉多

- 名称：固拉多；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`262402030e46715de21eb138e520134f`。
- 本地文件：[30thC_068.json](../data/bundled_user/cards/30thC_068.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 140, "energyType": "F", "weakness": {"energy": "G", "value": "×2"}, "resistance": null, "retreatCost": 4}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/068", "source_set_code": "30thC", "source_card_index": "068", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【斗】【斗】【斗】【斗】【斗】 大地破坏 250
给自己所有备战宝可梦也各造成20伤害。[备战宝可梦不计算弱点、抗性。]
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 大地破坏；cost=FFFFF；damage=250；给自己所有备战宝可梦也各造成20伤害。[备战宝可梦不计算弱点、抗性。] | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackOwnBenchWave` | 通过 |

关联新增测试：

- [`test_30thc_066_to_070_real_json_registration`](../tests/test_30thc_cards.gd#L1065)
- [`test_30thc_068_hits_own_bench_except_tera`](../tests/test_30thc_cards.gd#L1143)

### 069 路卡利欧

- 名称：路卡利欧；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`00265a9c83b1196e14f44c7e6ce90bac`。
- 本地文件：[30thC_069.json](../data/bundled_user/cards/30thC_069.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Stage 1", "evolvesFrom": "利欧路", "hp": 120, "energyType": "F", "weakness": {"energy": "P", "value": "×2"}, "resistance": null, "retreatCost": 2}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/069", "source_set_code": "30thC", "source_card_index": "069", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【斗】【斗】【无】 波导弹 100
给对手的1只备战宝可梦也造成60伤害。[备战宝可梦不计算弱点、抗性。]
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 波导弹；cost=FFC；damage=100；给对手的1只备战宝可梦也造成60伤害。[备战宝可梦不计算弱点、抗性。] | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackBenchTarget` | 通过 |

关联新增测试：

- [`test_30thc_066_to_070_real_json_registration`](../tests/test_30thc_cards.gd#L1065)
- [`test_30thc_066_discard_counts_cards_and_069_selected_bench_damage`](../tests/test_30thc_cards.gd#L1101)

### 070 蟾蜍王

- 名称：蟾蜍王；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`5e8f8e53cc52507e705900387a3be87a`。
- 本地文件：[30thC_070.json](../data/bundled_user/cards/30thC_070.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Stage 2", "evolvesFrom": "蓝蟾蜍", "hp": 160, "energyType": "F", "weakness": {"energy": "G", "value": "×2"}, "resistance": null, "retreatCost": 3}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/070", "source_set_code": "30thC", "source_card_index": "070", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 5 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 2 项（含共享链路，非穷举缺陷数）；状态：已修复并验证。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【斗】 振动拳 60
在下一个对手的回合，每当对手从手牌使出训练家时，在使用前抛掷1次硬币。如果为反面，则那张卡牌不视作被使用过，将其放于弃牌区。

【斗】【无】【无】【无】 百万吨重拳 180
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 振动拳；cost=F；damage=60；在下一个对手的回合，每当对手从手牌使出训练家时，在使用前抛掷1次硬币。如果为反面，则那张卡牌不视作被使用过，将其放于弃牌区。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackVibrationPunch` | 通过 |
| 招式 1: 百万吨重拳；cost=FCCC；damage=180； | `GameStateMachine.use_attack` -> `DamageCalculator`（纯伤害） | 通过 |

关联新增测试：

- [`test_30thc_066_to_070_real_json_registration`](../tests/test_30thc_cards.gd#L1065)
- [`test_30thc_070_tails_discards_trainers_without_using_them`](../tests/test_30thc_cards.gd#L1069)
- [`test_30thc_070_heads_cached_between_declaration_and_commit`](../tests/test_30thc_cards.gd#L1159)
- [`test_30thc_review_070_real_ui_controller_and_headless_discard_before_search`](../tests/test_30thc_cards.gd#L1705)
- [`test_30thc_review_evolution_batch_one`](../tests/test_30thc_cards.gd#L1803)

复审修复：

- 物品/支援者/道具/竞技场共用声明投币；反面先弃牌，不揭示搜索内容、不消耗成功使用次数。
- 普通进化及神奇糖果双路径；缺 Stage 1 实体时按稳定中英映射选择同线基础宝可梦，拒绝错误/当回合登场目标。

### 071 鬃岩狼人

- 名称：鬃岩狼人；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`e9c95aca720c468d19bc2c9b4f0e90a8`。
- 本地文件：[30thC_071.json](../data/bundled_user/cards/30thC_071.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Stage 1", "evolvesFrom": "岩狗狗", "hp": 130, "energyType": "F", "weakness": {"energy": "G", "value": "×2"}, "resistance": null, "retreatCost": 2}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": ["Single Strike"]}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/071", "source_set_code": "30thC", "source_card_index": "071", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【斗】 双倍奉还 10+
追加造成与这只宝可梦在上一个对手的回合所受到的招式的伤害相同数值的伤害。

【斗】【斗】 岩石粉碎 80
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 双倍奉还；cost=F；damage=10+；追加造成与这只宝可梦在上一个对手的回合所受到的招式的伤害相同数值的伤害。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackCounterDamage` | 通过 |
| 招式 1: 岩石粉碎；cost=FF；damage=80； | `GameStateMachine.use_attack` -> `DamageCalculator`（纯伤害） | 通过 |

关联新增测试：

- [`test_30thc_071_to_075_real_json_registration`](../tests/test_30thc_cards.gd#L1182)
- [`test_30thc_071_counter_uses_previous_attack_damage_not_current_counters`](../tests/test_30thc_cards.gd#L1186)

### 072 故勒顿

- 名称：故勒顿；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`7deaab75aeac8b6a9f1a4c6182ee0485`。
- 本地文件：[30thC_072.json](../data/bundled_user/cards/30thC_072.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 130, "energyType": "F", "weakness": {"energy": "P", "value": "×2"}, "resistance": null, "retreatCost": 2}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": ["Ancient"]}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/072", "source_set_code": "30thC", "source_card_index": "072", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 1 项（含共享链路，非穷举缺陷数）；状态：已修复并验证。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【斗】【斗】 踢倒 50


【斗】【斗】【无】 全开猛撞 140
选择这只宝可梦身上附着的2个【斗】能量，放于弃牌区。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 踢倒；cost=FF；damage=50； | `GameStateMachine.use_attack` -> `DamageCalculator`（纯伤害） | 通过 |
| 招式 1: 全开猛撞；cost=FFC；damage=140；选择这只宝可梦身上附着的2个【斗】能量，放于弃牌区。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackDiscardEnergyRequirements` | 通过 |

关联新增测试：

- [`test_30thc_071_to_075_real_json_registration`](../tests/test_30thc_cards.gd#L1182)
- [`test_30thc_072_discards_fighting_073_growl_and_075_free_draw`](../tests/test_30thc_cards.gd#L1203)

复审修复：

- 两个斗能量按有效供给单位支付，交互逐步收集所选能量。

### 073 尼多兰

- 名称：尼多兰；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`adc2b7eef45640632f3c67ec02aed83b`。
- 本地文件：[30thC_073.json](../data/bundled_user/cards/30thC_073.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 60, "energyType": "D", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/073", "source_set_code": "30thC", "source_card_index": "073", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【无】 叫声 
在下一个对手的回合，受到这个招式影响的宝可梦所使用的招式的伤害「-30」。

【恶】 头锤 10
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 叫声；cost=C；damage=；在下一个对手的回合，受到这个招式影响的宝可梦所使用的招式的伤害「-30」。 | `res://scripts/effects/CSV9CEffects.gd::AttackReduceDefenderOutgoingDamage` | 通过 |
| 招式 1: 头锤；cost=D；damage=10； | `GameStateMachine.use_attack` -> `DamageCalculator`（纯伤害） | 通过 |

关联新增测试：

- [`test_30thc_071_to_075_real_json_registration`](../tests/test_30thc_cards.gd#L1182)
- [`test_30thc_072_discards_fighting_073_growl_and_075_free_draw`](../tests/test_30thc_cards.gd#L1203)

### 074 尼多娜

- 名称：尼多娜；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`2212a16966600c8c707bcfbfcce7cd1a`。
- 本地文件：[30thC_074.json](../data/bundled_user/cards/30thC_074.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Stage 1", "evolvesFrom": "尼多兰", "hp": 90, "energyType": "D", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 2}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/074", "source_set_code": "30thC", "source_card_index": "074", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
特性: 幸福分享
在自己的回合可以使用1次。回复自己1只宝可梦「30」HP。

【无】【无】 咬住 30
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 特性 幸福分享: 在自己的回合可以使用1次。回复自己1只宝可梦「30」HP。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AbilityShareHappiness` -> EffectProcessor/GSM | 通过 |
| 招式 0: 咬住；cost=CC；damage=30； | `GameStateMachine.use_attack` -> `DamageCalculator`（纯伤害） | 通过 |

关联新增测试：

- [`test_30thc_071_to_075_real_json_registration`](../tests/test_30thc_cards.gd#L1182)
- [`test_30thc_074_heals_one_chosen_own_pokemon_once`](../tests/test_30thc_cards.gd#L1222)

### 075 阿罗拉 喵喵

- 名称：阿罗拉 喵喵；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`a4813d15f7f218c519135b8fa6e6b34d`。
- 本地文件：[30thC_075.json](../data/bundled_user/cards/30thC_075.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 60, "energyType": "D", "weakness": {"energy": "G", "value": "×2"}, "resistance": null, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/075", "source_set_code": "30thC", "source_card_index": "075", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【0】 聚宝功 10
从自己牌库上方抽取1张卡牌。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 聚宝功；cost=；damage=10；从自己牌库上方抽取1张卡牌。 | `res://scripts/effects/pokemon_effects/AttackDrawCards.gd` | 通过 |

关联新增测试：

- [`test_30thc_071_to_075_real_json_registration`](../tests/test_30thc_cards.gd#L1182)
- [`test_30thc_072_discards_fighting_073_growl_and_075_free_draw`](../tests/test_30thc_cards.gd#L1203)

### 076 耿鬼ex

- 名称：耿鬼ex；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`3aa3c4269d9f1a5cd5dcbb52a16a9c1d`。
- 本地文件：[30thC_076.json](../data/bundled_user/cards/30thC_076.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Stage 2", "evolvesFrom": "鬼斯通", "hp": 280, "energyType": "D", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 2}。
- mechanic / ancient_trait / is_tags：{"mechanic": "ex", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/076", "source_set_code": "30thC", "source_card_index": "076", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 3 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 1 项（含共享链路，非穷举缺陷数）；状态：已修复并验证。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
特性: 归天宣告
当这只宝可梦受到对手宝可梦的招式的伤害而【昏厥】时，自己抛掷1次硬币。如果为正面，则令使用了招式的宝可梦【昏厥】。

【恶】【恶】 混沌伤痛 
给对手的1只宝可梦身上放置13个伤害指示物。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 特性 归天宣告: 当这只宝可梦受到对手宝可梦的招式的伤害而【昏厥】时，自己抛掷1次硬币。如果为正面，则令使用了招式的宝可梦【昏厥】。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AbilityDeathSentence` -> EffectProcessor/GSM | 通过 |
| 招式 0: 混沌伤痛；cost=DD；damage=；给对手的1只宝可梦身上放置13个伤害指示物。 | `res://scripts/effects/pokemon_effects/AttackChooseOpponentPokemonDamageCounters.gd` | 通过 |

关联新增测试：

- [`test_30thc_076_to_080_real_json_registration`](../tests/test_30thc_cards.gd#L1240)
- [`test_30thc_076_counter_placement_is_not_attack_damage_and_death_sentence_coin`](../tests/test_30thc_cards.gd#L1263)
- [`test_30thc_review_evolution_batch_two`](../tests/test_30thc_cards.gd#L1807)

复审修复：

- 普通进化及神奇糖果双路径；缺 Stage 1 实体时按稳定中英映射选择同线基础宝可梦，拒绝错误/当回合登场目标。

### 077 月亮伊布

- 名称：月亮伊布；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`3860e7c78ea98edb870cdd58b5001170`。
- 本地文件：[30thC_077.json](../data/bundled_user/cards/30thC_077.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Stage 1", "evolvesFrom": "伊布", "hp": 110, "energyType": "D", "weakness": {"energy": "G", "value": "×2"}, "resistance": null, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/077", "source_set_code": "30thC", "source_card_index": "077", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【恶】 报仇 30+
在上一个对手的回合，如果自己的宝可梦受到招式的伤害而【昏厥】的话，则追加造成100伤害。

【恶】【无】【无】 暗之牙 100
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 报仇；cost=D；damage=30+；在上一个对手的回合，如果自己的宝可梦受到招式的伤害而【昏厥】的话，则追加造成100伤害。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackDamageKORevenge` | 通过 |
| 招式 1: 暗之牙；cost=DCC；damage=100； | `GameStateMachine.use_attack` -> `DamageCalculator`（纯伤害） | 通过 |

关联新增测试：

- [`test_30thc_076_to_080_real_json_registration`](../tests/test_30thc_cards.gd#L1240)
- [`test_30thc_077_only_damage_ko_bonus_078_shuffle_four_and_080_hand_multiplier`](../tests/test_30thc_cards.gd#L1283)

### 078 滑滑小子

- 名称：滑滑小子；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`3dd4bd773322d8d5040badce1f880c61`。
- 本地文件：[30thC_078.json](../data/bundled_user/cards/30thC_078.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 80, "energyType": "D", "weakness": {"energy": "G", "value": "×2"}, "resistance": null, "retreatCost": 2}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/078", "source_set_code": "30thC", "source_card_index": "078", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【恶】 挑毛病 
对手将其手牌全部放回牌库并重洗牌库。然后，对手从牌库上方抽取4张卡牌。

【恶】【无】 推打 30
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 挑毛病；cost=D；damage=；对手将其手牌全部放回牌库并重洗牌库。然后，对手从牌库上方抽取4张卡牌。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackOpponentShuffleDrawFour` | 通过 |
| 招式 1: 推打；cost=DC；damage=30； | `GameStateMachine.use_attack` -> `DamageCalculator`（纯伤害） | 通过 |

关联新增测试：

- [`test_30thc_076_to_080_real_json_registration`](../tests/test_30thc_cards.gd#L1240)
- [`test_30thc_077_only_damage_ko_bonus_078_shuffle_four_and_080_hand_multiplier`](../tests/test_30thc_cards.gd#L1283)

### 079 伊裴尔塔尔

- 名称：伊裴尔塔尔；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`d39da7a78d3666d00e84860f5d122649`。
- 本地文件：[30thC_079.json](../data/bundled_user/cards/30thC_079.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 120, "energyType": "D", "weakness": {"energy": "L", "value": "×2"}, "resistance": {"energy": "F", "value": "-30"}, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": ["Single Strike"]}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/079", "source_set_code": "30thC", "source_card_index": "079", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 1 项（含共享链路，非穷举缺陷数）；状态：已修复并验证。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
特性: 生命制约
只要这只宝可梦在场上，对手的战斗宝可梦无法回复HP。

【恶】【无】【无】 暗黑利刃 90
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 特性 生命制约: 只要这只宝可梦在场上，对手的战斗宝可梦无法回复HP。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AbilityLifeConstraint` -> EffectProcessor/GSM | 通过 |
| 招式 0: 暗黑利刃；cost=DCC；damage=90； | `GameStateMachine.use_attack` -> `DamageCalculator`（纯伤害） | 通过 |

关联新增测试：

- [`test_30thc_076_to_080_real_json_registration`](../tests/test_30thc_cards.gd#L1240)
- [`test_30thc_079_blocks_opponent_active_heal_not_bench_or_counter_moves`](../tests/test_30thc_cards.gd#L1244)

复审修复：

- 统一治疗入口覆盖已有治疗卡，不把移动伤害指示物、生存和离场重置误判为治疗。

### 080 伽勒尔 喵喵

- 名称：伽勒尔 喵喵；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`2b9a93502964323c8ee21715e1b9d1ff`。
- 本地文件：[30thC_080.json](../data/bundled_user/cards/30thC_080.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 70, "energyType": "M", "weakness": {"energy": "R", "value": "×2"}, "resistance": {"energy": "G", "value": "-30"}, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/080", "source_set_code": "30thC", "source_card_index": "080", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【无】 聚宝功 10
从自己牌库上方抽取1张卡牌。

【钢】 宝物突进 10×
造成自己手牌张数×10伤害。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 聚宝功；cost=C；damage=10；从自己牌库上方抽取1张卡牌。 | `res://scripts/effects/pokemon_effects/AttackDrawCards.gd` | 通过 |
| 招式 1: 宝物突进；cost=M；damage=10×；造成自己手牌张数×10伤害。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackHandSizeDamage` | 通过 |

关联新增测试：

- [`test_30thc_076_to_080_real_json_registration`](../tests/test_30thc_cards.gd#L1240)
- [`test_30thc_077_only_damage_ko_bonus_078_shuffle_four_and_080_hand_multiplier`](../tests/test_30thc_cards.gd#L1283)

### 081 基拉祈ex

- 名称：基拉祈ex；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`b64c857949b418dc7c83e2d803fa5f60`。
- 本地文件：[30thC_081.json](../data/bundled_user/cards/30thC_081.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 160, "energyType": "M", "weakness": {"energy": "R", "value": "×2"}, "resistance": {"energy": "G", "value": "-30"}, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "ex", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/081", "source_set_code": "30thC", "source_card_index": "081", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 1 项（含共享链路，非穷举缺陷数）；状态：已修复并验证。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【无】 愿望成真 
从牌库上方抽取卡牌，直到自己的手牌变为7张为止。

【无】【无】【无】 高速星星 150
这个招式的伤害不计算弱点、抗性以及对手战斗宝可梦身上所附加的效果。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 愿望成真；cost=C；damage=；从牌库上方抽取卡牌，直到自己的手牌变为7张为止。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackWishComeTrue` | 通过 |
| 招式 1: 高速星星；cost=CCC；damage=150；这个招式的伤害不计算弱点、抗性以及对手战斗宝可梦身上所附加的效果。 | `res://scripts/effects/pokemon_effects/AttackIgnoreWeaknessResistanceAndEffects.gd` | 通过 |

关联新增测试：

- [`test_30thc_081_to_085_real_json_registration`](../tests/test_30thc_cards.gd#L1304)
- [`test_30thc_081_mandatory_seven_and_swift_ignores_weakness_and_protection`](../tests/test_30thc_cards.gd#L1308)

复审修复：

- 高速星星限定第二招式，避免无视弱点/效果标记串到第一招式。

### 082 帝牙卢卡

- 名称：帝牙卢卡；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`3ab33883e0c28b50994d0369caf2a261`。
- 本地文件：[30thC_082.json](../data/bundled_user/cards/30thC_082.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 130, "energyType": "M", "weakness": {"energy": "R", "value": "×2"}, "resistance": {"energy": "G", "value": "-30"}, "retreatCost": 2}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": ["Single Strike"]}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/082", "source_set_code": "30thC", "source_card_index": "082", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【无】 逆动时钟 
选择自己弃牌区中的宝可梦和基本能量合计最多3张，在给对手看过之后放回牌库并重洗牌库。

【钢】【钢】【无】 重磅冲击 110
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 逆动时钟；cost=C；damage=；选择自己弃牌区中的宝可梦和基本能量合计最多3张，在给对手看过之后放回牌库并重洗牌库。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackReverseClock` | 通过 |
| 招式 1: 重磅冲击；cost=MMC；damage=110； | `GameStateMachine.use_attack` -> `DamageCalculator`（纯伤害） | 通过 |

关联新增测试：

- [`test_30thc_081_to_085_real_json_registration`](../tests/test_30thc_cards.gd#L1304)
- [`test_30thc_082_returns_only_chosen_pokemon_and_basic_energy`](../tests/test_30thc_cards.gd#L1326)

### 083 坚果哑铃

- 名称：坚果哑铃；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`e94c582847c08c302ce02aa2f4e3ed55`。
- 本地文件：[30thC_083.json](../data/bundled_user/cards/30thC_083.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Stage 1", "evolvesFrom": "种子铁球", "hp": 130, "energyType": "M", "weakness": {"energy": "R", "value": "×2"}, "resistance": {"energy": "G", "value": "-30"}, "retreatCost": 3}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/083", "source_set_code": "30thC", "source_card_index": "083", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【无】【无】 针刺 50


【钢】【钢】 爆炸针刺 
给对手所有宝可梦各造成50伤害。给这只宝可梦也造成130伤害。[备战宝可梦不计算弱点、抗性。]
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 针刺；cost=CC；damage=50； | `GameStateMachine.use_attack` -> `DamageCalculator`（纯伤害） | 通过 |
| 招式 1: 爆炸针刺；cost=MM；damage=；给对手所有宝可梦各造成50伤害。给这只宝可梦也造成130伤害。[备战宝可梦不计算弱点、抗性。] | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackExplosiveNeedles`, `res://scripts/effects/pokemon_effects/EffectSelfDamage.gd` | 通过 |

关联新增测试：

- [`test_30thc_081_to_085_real_json_registration`](../tests/test_30thc_cards.gd#L1304)
- [`test_30thc_083_spread_and_self_damage`](../tests/test_30thc_cards.gd#L1341)

### 084 索尔迦雷欧

- 名称：索尔迦雷欧；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`caeed4efe12242b3c0177cf125d42f12`。
- 本地文件：[30thC_084.json](../data/bundled_user/cards/30thC_084.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Stage 2", "evolvesFrom": "科斯莫姆", "hp": 170, "energyType": "M", "weakness": {"energy": "R", "value": "×2"}, "resistance": {"energy": "G", "value": "-30"}, "retreatCost": 2}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/084", "source_set_code": "30thC", "source_card_index": "084", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 3 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 2 项（含共享链路，非穷举缺陷数）；状态：已修复并验证。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
特性: 日出
如果这只宝可梦在备战区的话，则在自己的回合可以使用1次。选择自己牌库中最多2张「基本【钢】能量」，附着于这只宝可梦身上。并重洗牌库。

【钢】【钢】【无】【无】 流星闪冲 220
将这只宝可梦身上附着的能量全部放于弃牌区。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 特性 日出: 如果这只宝可梦在备战区的话，则在自己的回合可以使用1次。选择自己牌库中最多2张「基本【钢】能量」，附着于这只宝可梦身上。并重洗牌库。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AbilitySunrise` -> EffectProcessor/GSM | 通过 |
| 招式 0: 流星闪冲；cost=MMCC；damage=220；将这只宝可梦身上附着的能量全部放于弃牌区。 | `res://scripts/effects/pokemon_effects/AttackDiscardAllAttachedEnergyFromSelf.gd` | 通过 |

关联新增测试：

- [`test_30thc_081_to_085_real_json_registration`](../tests/test_30thc_cards.gd#L1304)
- [`test_30thc_084_sunrise_bench_only_self_basic_metal_once`](../tests/test_30thc_cards.gd#L1358)
- [`test_30thc_review_evolution_batch_two`](../tests/test_30thc_cards.gd#L1807)

复审修复：

- 日出允许牌库无基本钢能量时空搜，查看牌库、零张选择和每回合次数一致。
- 普通进化及神奇糖果双路径；缺 Stage 1 实体时按稳定中英映射选择同线基础宝可梦，拒绝错误/当回合登场目标。

### 085 苍响

- 名称：苍响；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`0b1754ca815d6f06b3ae1dcf7565fc73`。
- 本地文件：[30thC_085.json](../data/bundled_user/cards/30thC_085.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 130, "energyType": "M", "weakness": {"energy": "R", "value": "×2"}, "resistance": {"energy": "G", "value": "-30"}, "retreatCost": 2}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/085", "source_set_code": "30thC", "source_card_index": "085", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【钢】 坚硬利刃 20+
如果这只宝可梦身上放有「宝可梦道具」的话，则追加造成40伤害。

【钢】【钢】【无】 斩落 120
在下一个自己的回合，这只宝可梦无法使用「斩落」。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 坚硬利刃；cost=M；damage=20+；如果这只宝可梦身上放有「宝可梦道具」的话，则追加造成40伤害。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackToolBonus` | 通过 |
| 招式 1: 斩落；cost=MMC；damage=120；在下一个自己的回合，这只宝可梦无法使用「斩落」。 | `res://scripts/effects/pokemon_effects/AttackSelfLockNextTurn.gd` | 通过 |

关联新增测试：

- [`test_30thc_081_to_085_real_json_registration`](../tests/test_30thc_cards.gd#L1304)
- [`test_30thc_085_tool_bonus_does_not_apply_to_second_attack`](../tests/test_30thc_cards.gd#L1376)

### 086 藏玛然特

- 名称：藏玛然特；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`a4dd7f1126ac49fc7ec08efe43097cf8`。
- 本地文件：[30thC_086.json](../data/bundled_user/cards/30thC_086.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 130, "energyType": "M", "weakness": {"energy": "R", "value": "×2"}, "resistance": {"energy": "G", "value": "-30"}, "retreatCost": 2}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/086", "source_set_code": "30thC", "source_card_index": "086", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【钢】 弹落 20
在造成伤害前，将放于对手战斗宝可梦身上的「宝可梦道具」放于弃牌区。

【钢】【钢】【无】 盾牌压制 100
在下一个对手的回合，这只宝可梦所受到的招式的伤害「-50」。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 弹落；cost=M；damage=20；在造成伤害前，将放于对手战斗宝可梦身上的「宝可梦道具」放于弃牌区。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackKnockOff` | 通过 |
| 招式 1: 盾牌压制；cost=MMC；damage=100；在下一个对手的回合，这只宝可梦所受到的招式的伤害「-50」。 | `res://scripts/effects/pokemon_effects/AttackReduceDamageNextTurn.gd` | 通过 |

关联新增测试：

- [`test_30thc_086_to_090_real_json_registration`](../tests/test_30thc_cards.gd#L1388)
- [`test_30thc_086_removes_defender_tool_before_damage`](../tests/test_30thc_cards.gd#L1392)

### 087 赛富豪

- 名称：赛富豪；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`fecc124734bc8d0b3d50e6915d4958ee`。
- 本地文件：[30thC_087.json](../data/bundled_user/cards/30thC_087.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Stage 1", "evolvesFrom": "索财灵", "hp": 130, "energyType": "M", "weakness": {"energy": "R", "value": "×2"}, "resistance": {"energy": "G", "value": "-30"}, "retreatCost": 2}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/087", "source_set_code": "30thC", "source_card_index": "087", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 3 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【钢】 欢庆 
如果自己的手牌为30张的话，则拿取自己的2张奖赏卡。然后，将自己的手牌全部放回牌库并重洗牌库。

【钢】 三重粉碎 50×
抛掷3次硬币，造成正面次数×50伤害。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 欢庆；cost=M；damage=；如果自己的手牌为30张的话，则拿取自己的2张奖赏卡。然后，将自己的手牌全部放回牌库并重洗牌库。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackFestivity` | 通过 |
| 招式 1: 三重粉碎；cost=M；damage=50×；抛掷3次硬币，造成正面次数×50伤害。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackTripleSmash` | 通过 |

关联新增测试：

- [`test_30thc_086_to_090_real_json_registration`](../tests/test_30thc_cards.gd#L1388)
- [`test_30thc_087_exact_thirty_takes_selected_hidden_prizes_then_shuffles_hand`](../tests/test_30thc_cards.gd#L1409)
- [`test_30thc_087_triple_smash_three_coins_before_weakness`](../tests/test_30thc_cards.gd#L1432)

### 088 暴飞龙ex

- 名称：暴飞龙ex；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`8b1f439835db2ae1688662a68d3ac62c`。
- 本地文件：[30thC_088.json](../data/bundled_user/cards/30thC_088.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Stage 2", "evolvesFrom": "甲壳龙", "hp": 330, "energyType": "N", "weakness": null, "resistance": null, "retreatCost": 2}。
- mechanic / ancient_trait / is_tags：{"mechanic": "ex", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/088", "source_set_code": "30thC", "source_card_index": "088", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 3 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 1 项（含共享链路，非穷举缺陷数）；状态：已修复并验证。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【无】 轰鸣呼声 
选择自己弃牌区中最多3张【龙】宝可梦，放于备战区。

【火】【水】 龙之波动 240
将自己牌库上方2张卡牌放于弃牌区。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 轰鸣呼声；cost=C；damage=；选择自己弃牌区中最多3张【龙】宝可梦，放于备战区。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackRoaringCall` | 通过 |
| 招式 1: 龙之波动；cost=RW；damage=240；将自己牌库上方2张卡牌放于弃牌区。 | `res://scripts/effects/pokemon_effects/AttackMillSelfDeck.gd` | 通过 |

关联新增测试：

- [`test_30thc_086_to_090_real_json_registration`](../tests/test_30thc_cards.gd#L1388)
- [`test_30thc_088_revives_evolved_dragons_and_honors_explicit_zero`](../tests/test_30thc_cards.gd#L1447)
- [`test_30thc_review_evolution_batch_two`](../tests/test_30thc_cards.gd#L1807)

复审修复：

- 普通进化及神奇糖果双路径；缺 Stage 1 实体时按稳定中英映射选择同线基础宝可梦，拒绝错误/当回合登场目标。

### 089 心鳞宝

- 名称：心鳞宝；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`f9ce260f2d33fd863626d289736c0cc6`。
- 本地文件：[30thC_089.json](../data/bundled_user/cards/30thC_089.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 70, "energyType": "N", "weakness": null, "resistance": null, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/089", "source_set_code": "30thC", "source_card_index": "089", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【无】 刺耳声 
在下一个自己的回合，受到这个招式影响的宝可梦所受到的招式的伤害「+30」。

【雷】【斗】 龙爪 40
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 刺耳声；cost=C；damage=；在下一个自己的回合，受到这个招式影响的宝可梦所受到的招式的伤害「+30」。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackScreech` | 通过 |
| 招式 1: 龙爪；cost=LF；damage=40； | `GameStateMachine.use_attack` -> `DamageCalculator`（纯伤害） | 通过 |

关联新增测试：

- [`test_30thc_086_to_090_real_json_registration`](../tests/test_30thc_cards.gd#L1388)
- [`test_30thc_089_screech_next_own_turn_only_and_090_plain_damage`](../tests/test_30thc_cards.gd#L1462)

### 090 鳞甲龙

- 名称：鳞甲龙；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`3d3f2ec431904d54a364a75002a7b8c5`。
- 本地文件：[30thC_090.json](../data/bundled_user/cards/30thC_090.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Stage 1", "evolvesFrom": "心鳞宝", "hp": 90, "energyType": "N", "weakness": null, "resistance": null, "retreatCost": 2}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/090", "source_set_code": "30thC", "source_card_index": "090", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【无】 锐利之牙 20


【雷】【斗】 龙爪 70
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 锐利之牙；cost=C；damage=20； | `GameStateMachine.use_attack` -> `DamageCalculator`（纯伤害） | 通过 |
| 招式 1: 龙爪；cost=LF；damage=70； | `GameStateMachine.use_attack` -> `DamageCalculator`（纯伤害） | 通过 |

关联新增测试：

- [`test_30thc_086_to_090_real_json_registration`](../tests/test_30thc_cards.gd#L1388)
- [`test_30thc_089_screech_next_own_turn_only_and_090_plain_damage`](../tests/test_30thc_cards.gd#L1462)

### 091 杖尾鳞甲龙

- 名称：杖尾鳞甲龙；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`8860030a26a0467a1fb55e5132c9a479`。
- 本地文件：[30thC_091.json](../data/bundled_user/cards/30thC_091.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Stage 2", "evolvesFrom": "鳞甲龙", "hp": 180, "energyType": "N", "weakness": null, "resistance": null, "retreatCost": 2}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/091", "source_set_code": "30thC", "source_card_index": "091", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 3 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 1 项（含共享链路，非穷举缺陷数）；状态：已修复并验证。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【雷】【斗】【无】 炽热冲天 250
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 炽热冲天；cost=LFC；damage=250； | `GameStateMachine.use_attack` -> `DamageCalculator`（纯伤害） | 通过 |

关联新增测试：

- [`test_30thc_091_to_095_real_json_registration`](../tests/test_30thc_cards.gd#L1478)
- [`test_30thc_091_plain_attack_and_092_pay_day`](../tests/test_30thc_cards.gd#L1482)
- [`test_30thc_review_evolution_batch_two`](../tests/test_30thc_cards.gd#L1807)

复审修复：

- 普通进化及神奇糖果双路径；缺 Stage 1 实体时按稳定中英映射选择同线基础宝可梦，拒绝错误/当回合登场目标。

### 092 喵喵

- 名称：喵喵；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`ae8b67067d78d9ed2768fcb38a2f18d4`。
- 本地文件：[30thC_092.json](../data/bundled_user/cards/30thC_092.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 60, "energyType": "C", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/092", "source_set_code": "30thC", "source_card_index": "092", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【无】【无】 聚宝功 30
从自己牌库上方抽取1张卡牌。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 聚宝功；cost=CC；damage=30；从自己牌库上方抽取1张卡牌。 | `res://scripts/effects/pokemon_effects/AttackDrawCards.gd` | 通过 |

关联新增测试：

- [`test_30thc_091_to_095_real_json_registration`](../tests/test_30thc_cards.gd#L1478)
- [`test_30thc_091_plain_attack_and_092_pay_day`](../tests/test_30thc_cards.gd#L1482)

### 093 百变怪

- 名称：百变怪；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`06a0c72fadedf66b5169678d05d53132`。
- 本地文件：[30thC_093.json](../data/bundled_user/cards/30thC_093.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 70, "energyType": "C", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/093", "source_set_code": "30thC", "source_card_index": "093", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【无】【无】 整蛊变身 
抛掷1次硬币，如果为正面，则选择自己牌库中的1张宝可梦，与这只宝可梦互换（放于其身上的卡牌、伤害指示物、特殊状态、效果等会全部继承）。如果互换了的话，则将这张卡牌放回牌库。并重洗牌库。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 整蛊变身；cost=CC；damage=；抛掷1次硬币，如果为正面，则选择自己牌库中的1张宝可梦，与这只宝可梦互换（放于其身上的卡牌、伤害指示物、特殊状态、效果等会全部继承）。如果互换了的话，则将这张卡牌放回牌库。并重洗牌库。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackPrankTransform` | 通过 |

关联新增测试：

- [`test_30thc_091_to_095_real_json_registration`](../tests/test_30thc_cards.gd#L1478)
- [`test_30thc_093_transforms_into_stage_two_preserving_all_attached_state`](../tests/test_30thc_cards.gd#L1494)

### 094 伊布

- 名称：伊布；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`010b6a244ea472834e1384bc4efb7634`。
- 本地文件：[30thC_094.json](../data/bundled_user/cards/30thC_094.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 70, "energyType": "C", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/094", "source_set_code": "30thC", "source_card_index": "094", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【无】 嘴叼埋藏 
查看对手的手牌，选择其中1张物品放回对手的牌库下方。

【无】 撞击 10
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 嘴叼埋藏；cost=C；damage=；查看对手的手牌，选择其中1张物品放回对手的牌库下方。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackBuryItem` | 通过 |
| 招式 1: 撞击；cost=C；damage=10； | `GameStateMachine.use_attack` -> `DamageCalculator`（纯伤害） | 通过 |

关联新增测试：

- [`test_30thc_091_to_095_real_json_registration`](../tests/test_30thc_cards.gd#L1478)
- [`test_30thc_094_reveals_hand_but_only_item_is_selectable`](../tests/test_30thc_cards.gd#L1517)

### 095 卡比兽

- 名称：卡比兽；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`c580b384fb944d40c09ebdcda9c6d94f`。
- 本地文件：[30thC_095.json](../data/bundled_user/cards/30thC_095.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 160, "energyType": "C", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 4}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": ["Single Strike"]}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/095", "source_set_code": "30thC", "source_card_index": "095", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
特性: 安眠
当这只宝可梦处于【睡眠】状态时，在宝可梦检查中，如果这只宝可梦没有从【睡眠】状态恢复的话，则回复这只宝可梦的全部HP。

【无】【无】【无】 瘫倒 130
令这只宝可梦陷入【睡眠】状态。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 特性 安眠: 当这只宝可梦处于【睡眠】状态时，在宝可梦检查中，如果这只宝可梦没有从【睡眠】状态恢复的话，则回复这只宝可梦的全部HP。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AbilitySoundSleep` -> EffectProcessor/GSM | 通过 |
| 招式 0: 瘫倒；cost=CCC；damage=130；令这只宝可梦陷入【睡眠】状态。 | `res://scripts/effects/pokemon_effects/AttackApplySelfStatus.gd` | 通过 |

关联新增测试：

- [`test_30thc_091_to_095_real_json_registration`](../tests/test_30thc_cards.gd#L1478)
- [`test_30thc_095_heals_only_when_sleep_recovery_fails`](../tests/test_30thc_cards.gd#L1535)

### 096 宝宝丁

- 名称：宝宝丁；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`0718f0d8e41f74fee27dd895fab2a9bf`。
- 本地文件：[30thC_096.json](../data/bundled_user/cards/30thC_096.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 30, "energyType": "C", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 0}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/096", "source_set_code": "30thC", "source_card_index": "096", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【0】 软软圆阵 30×
造成自己最大HP为「30」的备战宝可梦数量×30伤害。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 软软圆阵；cost=；damage=30×；造成自己最大HP为「30」的备战宝可梦数量×30伤害。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackThirtyHPCircle` | 通过 |

关联新增测试：

- [`test_30thc_096_to_100_real_json_registration`](../tests/test_30thc_cards.gd#L1551)
- [`test_30thc_096_counts_only_thirty_max_hp_bench`](../tests/test_30thc_cards.gd#L1555)

### 097 洛奇亚

- 名称：洛奇亚；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`cb21f414f39c7d17fc3f47144ed2c342`。
- 本地文件：[30thC_097.json](../data/bundled_user/cards/30thC_097.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 120, "energyType": "C", "weakness": {"energy": "L", "value": "×2"}, "resistance": {"energy": "F", "value": "-30"}, "retreatCost": 2}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/097", "source_set_code": "30thC", "source_card_index": "097", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 1 项（含共享链路，非穷举缺陷数）；状态：已修复并验证。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【火】【水】【雷】 元素爆破 250
选择这只宝可梦身上附着的【火】【水】【雷】能量各1个，放于弃牌区。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 元素爆破；cost=RWL；damage=250；选择这只宝可梦身上附着的【火】【水】【雷】能量各1个，放于弃牌区。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackDiscardEnergyRequirements` | 通过 |

关联新增测试：

- [`test_30thc_096_to_100_real_json_registration`](../tests/test_30thc_cards.gd#L1551)
- [`test_30thc_097_discards_exact_selected_fire_water_lightning`](../tests/test_30thc_cards.gd#L1565)

复审修复：

- 火/水/雷需求按单位匹配；真实反转能量可同时支付多属性，双重涡轮仅支付无色。

### 098 洗翠 索罗亚

- 名称：洗翠 索罗亚；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`3ca5cce2de4b9bb9b92726424408d2e9`。
- 本地文件：[30thC_098.json](../data/bundled_user/cards/30thC_098.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 60, "energyType": "C", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/098", "source_set_code": "30thC", "source_card_index": "098", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【无】 抓 20
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 抓；cost=C；damage=20； | `GameStateMachine.use_attack` -> `DamageCalculator`（纯伤害） | 通过 |

关联新增测试：

- [`test_30thc_096_to_100_real_json_registration`](../tests/test_30thc_cards.gd#L1551)
- [`test_30thc_098_plain_scratch_099_counter_floor_fifty`](../tests/test_30thc_cards.gd#L1581)

### 099 洗翠 索罗亚克

- 名称：洗翠 索罗亚克；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`1aacf3bfb76bd000769bddef339474fe`。
- 本地文件：[30thC_099.json](../data/bundled_user/cards/30thC_099.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Stage 1", "evolvesFrom": "洗翠 索罗亚", "hp": 120, "energyType": "C", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/099", "source_set_code": "30thC", "source_card_index": "099", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【无】 抓 30


【无】【无】【无】 怨恨漩涡 
在对手的战斗宝可梦身上放置伤害指示物，直到其剩余HP变为「50」为止。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 抓；cost=C；damage=30； | `GameStateMachine.use_attack` -> `DamageCalculator`（纯伤害） | 通过 |
| 招式 1: 怨恨漩涡；cost=CCC；damage=；在对手的战斗宝可梦身上放置伤害指示物，直到其剩余HP变为「50」为止。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackGrudgeVortex` | 通过 |

关联新增测试：

- [`test_30thc_096_to_100_real_json_registration`](../tests/test_30thc_cards.gd#L1551)
- [`test_30thc_098_plain_scratch_099_counter_floor_fifty`](../tests/test_30thc_cards.gd#L1581)

### 100 一家鼠

- 名称：一家鼠；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`4482a5c8b104aa74ad1a4f488e5bdb17`。
- 本地文件：[30thC_100.json](../data/bundled_user/cards/30thC_100.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Stage 1", "evolvesFrom": "一对鼠", "hp": 80, "energyType": "C", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/100", "source_set_code": "30thC", "source_card_index": "100", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【无】 一同啃住 
抛掷与自己场上的「一家鼠」数量相同次数的硬币，从对手牌库上方将出现正面次数×2张卡牌放于弃牌区。

【无】 拍击 40
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 一同啃住；cost=C；damage=；抛掷与自己场上的「一家鼠」数量相同次数的硬币，从对手牌库上方将出现正面次数×2张卡牌放于弃牌区。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackGnawTogether` | 通过 |
| 招式 1: 拍击；cost=C；damage=40； | `GameStateMachine.use_attack` -> `DamageCalculator`（纯伤害） | 通过 |

关联新增测试：

- [`test_30thc_096_to_100_real_json_registration`](../tests/test_30thc_cards.gd#L1551)
- [`test_30thc_100_counts_own_named_maushold_and_mills_two_per_head`](../tests/test_30thc_cards.gd#L1597)

### 101 高级球

- 名称：高级球；英文=Ultra Ball；中文显示=。
- 类型=Item；标记=I；源 effect_id=`a337ed34a45e63c6d21d98c3d8e0cb6e`。
- 本地文件：[30thC_101.json](../data/bundled_user/cards/30thC_101.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": null, "evolvesFrom": null, "hp": null, "energyType": null, "weakness": null, "resistance": null, "retreatCost": null}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/101", "source_set_code": "30thC", "source_card_index": "101", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
只有将自己的2张手牌放于弃牌区后才可以使用这张卡牌。



选择自己牌库中的1张宝可梦，在给对手看过之后加入手牌。并重洗牌库。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 上述训练家/能量文本 | `res://scripts/effects/trainer_effects/EffectUltraBall.gd` | 通过 |

关联新增测试：

- [`test_30thc_101_to_105_real_json_registration`](../tests/test_30thc_cards.gd#L1613)
- [`test_30thc_101_ultra_ball_pays_two_and_searches_chosen_real_pokemon`](../tests/test_30thc_cards.gd#L1617)

### 102 宝可平板

- 名称：宝可平板；英文=；中文显示=。
- 类型=Item；标记=J；源 effect_id=`b0754293ea1611bb9f931f02060ceb3b`。
- 本地文件：[30thC_102.json](../data/bundled_user/cards/30thC_102.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": null, "evolvesFrom": null, "hp": null, "energyType": null, "weakness": null, "resistance": null, "retreatCost": null}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/102", "source_set_code": "30thC", "source_card_index": "102", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 1 项（含共享链路，非穷举缺陷数）；状态：已修复并验证。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
选择自己牌库中的1张宝可梦（除「拥有规则的宝可梦」外），在给对手看过之后加入手牌。并重洗牌库。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 上述训练家/能量文本 | `res://scripts/effects/trainer_effects/EffectPokePad.gd` | 通过 |

关联新增测试：

- [`test_30thc_101_to_105_real_json_registration`](../tests/test_30thc_cards.gd#L1613)
- [`test_30thc_102_poke_pad_full_deck_visible_but_rule_box_excluded`](../tests/test_30thc_cards.gd#L1632)

复审修复：

- 宝可平板接入 UCIS；完整己方牌库可见、仅合法牌可选，空搜 UI/Headless 一致。

### 103 宝可梦交替

- 名称：宝可梦交替；英文=Switch；中文显示=。
- 类型=Item；标记=I；源 effect_id=`7c0b20e121c9d0e0d2d8a43524f7494e`。
- 本地文件：[30thC_103.json](../data/bundled_user/cards/30thC_103.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": null, "evolvesFrom": null, "hp": null, "energyType": null, "weakness": null, "resistance": null, "retreatCost": null}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/103", "source_set_code": "30thC", "source_card_index": "103", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
将自己的战斗宝可梦与备战宝可梦互换。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 上述训练家/能量文本 | `res://scripts/effects/trainer_effects/EffectSwitchPokemon.gd` | 通过 |

关联新增测试：

- [`test_30thc_101_to_105_real_json_registration`](../tests/test_30thc_cards.gd#L1613)
- [`test_30thc_103_switch_selected_nonfirst_bench`](../tests/test_30thc_cards.gd#L1650)

### 104 阿罗拉 椰蛋树

- 名称：阿罗拉 椰蛋树；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`c77d3be6b3f3347323cd1b3df86dde1d`。
- 本地文件：[30thC_104.json](../data/bundled_user/cards/30thC_104.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Stage 1", "evolvesFrom": "蛋蛋", "hp": 150, "energyType": "G", "weakness": {"energy": "R", "value": "×2"}, "resistance": null, "retreatCost": 4}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/104", "source_set_code": "30thC", "source_card_index": "104", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 4 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 1 项（含共享链路，非穷举缺陷数）；状态：已修复并验证。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
特性: 枝繁叶茂
如果这只宝可梦身上附着了6个及以上【草】能量的话，则这只宝可梦的最大HP「+250」。

【草】【无】【无】【无】 超级吸取 150
回复这只宝可梦「50」HP。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 特性 枝繁叶茂: 如果这只宝可梦身上附着了6个及以上【草】能量的话，则这只宝可梦的最大HP「+250」。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AbilityGrassEnergyHP` -> EffectProcessor/GSM | 通过 |
| 招式 0: 超级吸取；cost=GCCC；damage=150；回复这只宝可梦「50」HP。 | `res://scripts/effects/pokemon_effects/CSV9CSimpleHealSelfAfterAttack.gd` | 通过 |

关联新增测试：

- [`test_30thc_101_to_105_real_json_registration`](../tests/test_30thc_cards.gd#L1613)
- [`test_30thc_printings_104_to_105`](../tests/test_30thc_cards.gd#L1977)
- [`test_30thc_001_to_005_real_json_registration`](../tests/test_30thc_cards.gd#L107)
- [`test_30thc_002_exeggutor_hp_threshold_and_healing`](../tests/test_30thc_cards.gd#L823)

复审修复：

- 真实反转能量按供给单位计数；奖赏条件消失时 HP 加成随之失效。

### 105 火焰鸟

- 名称：火焰鸟；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`efa2faba61d1b2cd26c7371fe79c23b0`。
- 本地文件：[30thC_105.json](../data/bundled_user/cards/30thC_105.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 120, "energyType": "R", "weakness": {"energy": "W", "value": "×2"}, "resistance": null, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/105", "source_set_code": "30thC", "source_card_index": "105", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 4 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 1 项（含共享链路，非穷举缺陷数）；状态：已修复并验证。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
特性: 燃烧展翼
如果自己场上有「急冻鸟」「闪电鸟」的话，则在自己的回合可以使用1次。选择自己手牌中的1张「基本【火】能量」，附着于这只宝可梦身上。

【火】【火】【无】 火焰旋涡 130
选择这只宝可梦身上附着的2个能量，放于弃牌区。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 特性 燃烧展翼: 如果自己场上有「急冻鸟」「闪电鸟」的话，则在自己的回合可以使用1次。选择自己手牌中的1张「基本【火】能量」，附着于这只宝可梦身上。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AbilityLegendaryBirdAttachment` -> EffectProcessor/GSM | 通过 |
| 招式 0: 火焰旋涡；cost=RRC；damage=130；选择这只宝可梦身上附着的2个能量，放于弃牌区。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackDiscardEnergyRequirements` | 通过 |

关联新增测试：

- [`test_30thc_101_to_105_real_json_registration`](../tests/test_30thc_cards.gd#L1613)
- [`test_30thc_printings_104_to_105`](../tests/test_30thc_cards.gd#L1977)
- [`test_30thc_006_to_010_real_json_registration`](../tests/test_30thc_cards.gd#L111)
- [`test_30thc_006_moltres_partners_attach_once_and_discard_two`](../tests/test_30thc_cards.gd#L169)

复审修复：

- 丢弃能量按供给单位而非卡片张数支付，逐步选择且拒绝重复引用。

### 106 拉普拉斯

- 名称：拉普拉斯；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`fcdfdf2c053d45b97f98ac821dbdf7a8`。
- 本地文件：[30thC_106.json](../data/bundled_user/cards/30thC_106.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 130, "energyType": "W", "weakness": {"energy": "M", "value": "×2"}, "resistance": null, "retreatCost": 2}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": ["Rapid Strike"]}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/106", "source_set_code": "30thC", "source_card_index": "106", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 3 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【无】 乘载游动 
选择自己牌库中的1张支援者，在给对手看过之后加入手牌。并重洗牌库。

【水】【无】【无】 冰冻光束 80
抛掷1次硬币，如果为正面，则令对手的战斗宝可梦陷入【麻痹】状态。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 乘载游动；cost=C；damage=；选择自己牌库中的1张支援者，在给对手看过之后加入手牌。并重洗牌库。 | `res://scripts/effects/pokemon_effects/AttackSearchDeckToHand.gd` | 通过 |
| 招式 1: 冰冻光束；cost=WCC；damage=80；抛掷1次硬币，如果为正面，则令对手的战斗宝可梦陷入【麻痹】状态。 | `res://scripts/effects/pokemon_effects/EffectApplyStatus.gd` | 通过 |

关联新增测试：

- [`test_30thc_printings_106_to_110`](../tests/test_30thc_cards.gd#L1981)
- [`test_30thc_011_to_015_real_json_registration`](../tests/test_30thc_cards.gd#L115)
- [`test_30thc_011_lapras_search_visibility_and_selected_supporter`](../tests/test_30thc_cards.gd#L289)

### 107 急冻鸟

- 名称：急冻鸟；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`831872607eca83307cb94cfa8afc7730`。
- 本地文件：[30thC_107.json](../data/bundled_user/cards/30thC_107.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 120, "energyType": "W", "weakness": {"energy": "M", "value": "×2"}, "resistance": null, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/107", "source_set_code": "30thC", "source_card_index": "107", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 3 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
特性: 冻结展翼
如果自己场上有「火焰鸟」「闪电鸟」的话，则在自己的回合可以使用1次。选择自己手牌中的1张「基本【水】能量」，附着于这只宝可梦身上。

【水】【水】【无】 冰雹 
给对手所有宝可梦各造成30伤害。[备战宝可梦不计算弱点、抗性。]
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 特性 冻结展翼: 如果自己场上有「火焰鸟」「闪电鸟」的话，则在自己的回合可以使用1次。选择自己手牌中的1张「基本【水】能量」，附着于这只宝可梦身上。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AbilityLegendaryBirdAttachment` -> EffectProcessor/GSM | 通过 |
| 招式 0: 冰雹；cost=WWC；damage=；给对手所有宝可梦各造成30伤害。[备战宝可梦不计算弱点、抗性。] | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackHail` | 通过 |

关联新增测试：

- [`test_30thc_printings_106_to_110`](../tests/test_30thc_cards.gd#L1981)
- [`test_30thc_011_to_015_real_json_registration`](../tests/test_30thc_cards.gd#L115)
- [`test_30thc_012_articuno_hail_active_weakness_and_bench_no_weakness`](../tests/test_30thc_cards.gd#L311)

### 108 闪电鸟

- 名称：闪电鸟；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`23a00b18e1944b72ea1e1598affc5fe4`。
- 本地文件：[30thC_108.json](../data/bundled_user/cards/30thC_108.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 120, "energyType": "L", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/108", "source_set_code": "30thC", "source_card_index": "108", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 3 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
特性: 迸发展翼
如果自己场上有「火焰鸟」「急冻鸟」的话，则在自己的回合可以使用1次。选择自己手牌中的1张「基本【雷】能量」，附着于这只宝可梦身上。

【雷】【雷】【雷】【无】 雷轰 210
给这只宝可梦也造成60伤害。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 特性 迸发展翼: 如果自己场上有「火焰鸟」「急冻鸟」的话，则在自己的回合可以使用1次。选择自己手牌中的1张「基本【雷】能量」，附着于这只宝可梦身上。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AbilityLegendaryBirdAttachment` -> EffectProcessor/GSM | 通过 |
| 招式 0: 雷轰；cost=LLLC；damage=210；给这只宝可梦也造成60伤害。 | `res://scripts/effects/pokemon_effects/EffectSelfDamage.gd` | 通过 |

关联新增测试：

- [`test_30thc_printings_106_to_110`](../tests/test_30thc_cards.gd#L1981)
- [`test_30thc_046_to_050_real_json_registration`](../tests/test_30thc_cards.gd#L143)
- [`test_30thc_046_damage_counters_049_recoil_050_fire_bonus`](../tests/test_30thc_cards.gd#L755)

### 109 颤弦蝾螈

- 名称：颤弦蝾螈；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`2210e38ce299e07646e3a1a67fc1b258`。
- 本地文件：[30thC_109.json](../data/bundled_user/cards/30thC_109.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Stage 1", "evolvesFrom": "电音婴", "hp": 140, "energyType": "L", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 2}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": ["Fusion Strike"]}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/109", "source_set_code": "30thC", "source_card_index": "109", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 3 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【雷】 殴打 40


【雷】【无】【无】 雷电伏特 150
在下一个自己的回合，这只宝可梦无法使用招式。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 殴打；cost=L；damage=40； | `GameStateMachine.use_attack` -> `DamageCalculator`（纯伤害） | 通过 |
| 招式 1: 雷电伏特；cost=LCC；damage=150；在下一个自己的回合，这只宝可梦无法使用招式。 | `res://scripts/effects/pokemon_effects/AttackSelfAllAttacksLockNextTurn.gd` | 通过 |

关联新增测试：

- [`test_30thc_printings_106_to_110`](../tests/test_30thc_cards.gd#L1981)
- [`test_30thc_051_to_055_real_json_registration`](../tests/test_30thc_cards.gd#L147)
- [`test_30thc_051_and_055_second_attack_locks_all_attacks`](../tests/test_30thc_cards.gd#L866)

### 110 莫鲁贝可

- 名称：莫鲁贝可；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`508470eb99327c31713a9a0543dbb5bc`。
- 本地文件：[30thC_110.json](../data/bundled_user/cards/30thC_110.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 70, "energyType": "L", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": ["Single Strike"]}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/110", "source_set_code": "30thC", "source_card_index": "110", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 3 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【无】 选点心 
将自己牌库上方3张卡牌放于弃牌区，选择其中1张卡牌，在给对手看过之后加入手牌。

【雷】 巴掌 30
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 选点心；cost=C；damage=；将自己牌库上方3张卡牌放于弃牌区，选择其中1张卡牌，在给对手看过之后加入手牌。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackPickSnack` | 通过 |
| 招式 1: 巴掌；cost=L；damage=30； | `GameStateMachine.use_attack` -> `DamageCalculator`（纯伤害） | 通过 |

关联新增测试：

- [`test_30thc_printings_106_to_110`](../tests/test_30thc_cards.gd#L1981)
- [`test_30thc_051_to_055_real_json_registration`](../tests/test_30thc_cards.gd#L147)
- [`test_30thc_052_snack_only_recovers_from_newly_milled_top_three`](../tests/test_30thc_cards.gd#L884)

### 111 飘飘球

- 名称：飘飘球；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`b813a0097cf2b40184888c03f51832fd`。
- 本地文件：[30thC_111.json](../data/bundled_user/cards/30thC_111.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 70, "energyType": "P", "weakness": {"energy": "D", "value": "×2"}, "resistance": {"energy": "F", "value": "-30"}, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/111", "source_set_code": "30thC", "source_card_index": "111", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 4 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 1 项（含共享链路，非穷举缺陷数）；状态：已修复并验证。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【超】 飘飘扬 20
若希望，可以将这只宝可梦以及放于其身上的全部的卡牌放回牌库并重洗牌库。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 飘飘扬；cost=P；damage=20；若希望，可以将这只宝可梦以及放于其身上的全部的卡牌放回牌库并重洗牌库。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackDrifloonReturn` | 通过 |

关联新增测试：

- [`test_30thc_printings_111_to_115`](../tests/test_30thc_cards.gd#L1985)
- [`test_30thc_061_to_065_real_json_registration`](../tests/test_30thc_cards.gd#L1001)
- [`test_30thc_061_optional_return_preserves_decline_and_selected_replacement`](../tests/test_30thc_cards.gd#L1005)
- [`test_30thc_review_061_last_pokemon_may_decline_or_return_and_lose`](../tests/test_30thc_cards.gd#L1940)

复审修复：

- 只剩这只宝可梦也可选择回牌库；可以放弃，选择返回则触发无宝可梦败北。

### 112 水晶灯火灵

- 名称：水晶灯火灵；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`035ac595564a924d0d2563f374e4adb9`。
- 本地文件：[30thC_112.json](../data/bundled_user/cards/30thC_112.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Stage 2", "evolvesFrom": "灯火幽灵", "hp": 140, "energyType": "P", "weakness": {"energy": "D", "value": "×2"}, "resistance": {"energy": "F", "value": "-30"}, "retreatCost": 2}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/112", "source_set_code": "30thC", "source_card_index": "112", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 4 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 1 项（含共享链路，非穷举缺陷数）；状态：已修复并验证。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【超】【超】 奇异灯火 130
令对手的战斗宝可梦陷入【灼伤】和【混乱】状态。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 奇异灯火；cost=PP；damage=130；令对手的战斗宝可梦陷入【灼伤】和【混乱】状态。 | `res://scripts/effects/pokemon_effects/EffectApplyStatus.gd`, `res://scripts/effects/pokemon_effects/EffectApplyStatus.gd` | 通过 |

关联新增测试：

- [`test_30thc_printings_111_to_115`](../tests/test_30thc_cards.gd#L1985)
- [`test_30thc_061_to_065_real_json_registration`](../tests/test_30thc_cards.gd#L1001)
- [`test_30thc_062_two_statuses_and_063_stadium_search_scope`](../tests/test_30thc_cards.gd#L1026)
- [`test_30thc_review_evolution_batch_one`](../tests/test_30thc_cards.gd#L1803)

复审修复：

- 普通进化及神奇糖果双路径；缺 Stage 1 实体时按稳定中英映射选择同线基础宝可梦，拒绝错误/当回合登场目标。

### 113 鬃岩狼人

- 名称：鬃岩狼人；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`e9c95aca720c468d19bc2c9b4f0e90a8`。
- 本地文件：[30thC_113.json](../data/bundled_user/cards/30thC_113.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Stage 1", "evolvesFrom": "岩狗狗", "hp": 130, "energyType": "F", "weakness": {"energy": "G", "value": "×2"}, "resistance": null, "retreatCost": 2}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": ["Single Strike"]}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/113", "source_set_code": "30thC", "source_card_index": "113", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 3 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【斗】 双倍奉还 10+
追加造成与这只宝可梦在上一个对手的回合所受到的招式的伤害相同数值的伤害。

【斗】【斗】 岩石粉碎 80
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 双倍奉还；cost=F；damage=10+；追加造成与这只宝可梦在上一个对手的回合所受到的招式的伤害相同数值的伤害。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackCounterDamage` | 通过 |
| 招式 1: 岩石粉碎；cost=FF；damage=80； | `GameStateMachine.use_attack` -> `DamageCalculator`（纯伤害） | 通过 |

关联新增测试：

- [`test_30thc_printings_111_to_115`](../tests/test_30thc_cards.gd#L1985)
- [`test_30thc_071_to_075_real_json_registration`](../tests/test_30thc_cards.gd#L1182)
- [`test_30thc_071_counter_uses_previous_attack_damage_not_current_counters`](../tests/test_30thc_cards.gd#L1186)

### 114 尼多娜

- 名称：尼多娜；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`2212a16966600c8c707bcfbfcce7cd1a`。
- 本地文件：[30thC_114.json](../data/bundled_user/cards/30thC_114.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Stage 1", "evolvesFrom": "尼多兰", "hp": 90, "energyType": "D", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 2}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/114", "source_set_code": "30thC", "source_card_index": "114", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 3 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
特性: 幸福分享
在自己的回合可以使用1次。回复自己1只宝可梦「30」HP。

【无】【无】 咬住 30
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 特性 幸福分享: 在自己的回合可以使用1次。回复自己1只宝可梦「30」HP。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AbilityShareHappiness` -> EffectProcessor/GSM | 通过 |
| 招式 0: 咬住；cost=CC；damage=30； | `GameStateMachine.use_attack` -> `DamageCalculator`（纯伤害） | 通过 |

关联新增测试：

- [`test_30thc_printings_111_to_115`](../tests/test_30thc_cards.gd#L1985)
- [`test_30thc_071_to_075_real_json_registration`](../tests/test_30thc_cards.gd#L1182)
- [`test_30thc_074_heals_one_chosen_own_pokemon_once`](../tests/test_30thc_cards.gd#L1222)

### 115 阿罗拉 喵喵

- 名称：阿罗拉 喵喵；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`a4813d15f7f218c519135b8fa6e6b34d`。
- 本地文件：[30thC_115.json](../data/bundled_user/cards/30thC_115.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 60, "energyType": "D", "weakness": {"energy": "G", "value": "×2"}, "resistance": null, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/115", "source_set_code": "30thC", "source_card_index": "115", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 3 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【0】 聚宝功 10
从自己牌库上方抽取1张卡牌。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 聚宝功；cost=；damage=10；从自己牌库上方抽取1张卡牌。 | `res://scripts/effects/pokemon_effects/AttackDrawCards.gd` | 通过 |

关联新增测试：

- [`test_30thc_printings_111_to_115`](../tests/test_30thc_cards.gd#L1985)
- [`test_30thc_071_to_075_real_json_registration`](../tests/test_30thc_cards.gd#L1182)
- [`test_30thc_072_discards_fighting_073_growl_and_075_free_draw`](../tests/test_30thc_cards.gd#L1203)

### 116 滑滑小子

- 名称：滑滑小子；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`3dd4bd773322d8d5040badce1f880c61`。
- 本地文件：[30thC_116.json](../data/bundled_user/cards/30thC_116.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 80, "energyType": "D", "weakness": {"energy": "G", "value": "×2"}, "resistance": null, "retreatCost": 2}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/116", "source_set_code": "30thC", "source_card_index": "116", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 3 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【恶】 挑毛病 
对手将其手牌全部放回牌库并重洗牌库。然后，对手从牌库上方抽取4张卡牌。

【恶】【无】 推打 30
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 挑毛病；cost=D；damage=；对手将其手牌全部放回牌库并重洗牌库。然后，对手从牌库上方抽取4张卡牌。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackOpponentShuffleDrawFour` | 通过 |
| 招式 1: 推打；cost=DC；damage=30； | `GameStateMachine.use_attack` -> `DamageCalculator`（纯伤害） | 通过 |

关联新增测试：

- [`test_30thc_printings_116_to_121`](../tests/test_30thc_cards.gd#L1989)
- [`test_30thc_076_to_080_real_json_registration`](../tests/test_30thc_cards.gd#L1240)
- [`test_30thc_077_only_damage_ko_bonus_078_shuffle_four_and_080_hand_multiplier`](../tests/test_30thc_cards.gd#L1283)

### 117 伽勒尔 喵喵

- 名称：伽勒尔 喵喵；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`2b9a93502964323c8ee21715e1b9d1ff`。
- 本地文件：[30thC_117.json](../data/bundled_user/cards/30thC_117.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 70, "energyType": "M", "weakness": {"energy": "R", "value": "×2"}, "resistance": {"energy": "G", "value": "-30"}, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/117", "source_set_code": "30thC", "source_card_index": "117", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 3 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【无】 聚宝功 10
从自己牌库上方抽取1张卡牌。

【钢】 宝物突进 10×
造成自己手牌张数×10伤害。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 聚宝功；cost=C；damage=10；从自己牌库上方抽取1张卡牌。 | `res://scripts/effects/pokemon_effects/AttackDrawCards.gd` | 通过 |
| 招式 1: 宝物突进；cost=M；damage=10×；造成自己手牌张数×10伤害。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackHandSizeDamage` | 通过 |

关联新增测试：

- [`test_30thc_printings_116_to_121`](../tests/test_30thc_cards.gd#L1989)
- [`test_30thc_076_to_080_real_json_registration`](../tests/test_30thc_cards.gd#L1240)
- [`test_30thc_077_only_damage_ko_bonus_078_shuffle_four_and_080_hand_multiplier`](../tests/test_30thc_cards.gd#L1283)

### 118 赛富豪

- 名称：赛富豪；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`fecc124734bc8d0b3d50e6915d4958ee`。
- 本地文件：[30thC_118.json](../data/bundled_user/cards/30thC_118.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Stage 1", "evolvesFrom": "索财灵", "hp": 130, "energyType": "M", "weakness": {"energy": "R", "value": "×2"}, "resistance": {"energy": "G", "value": "-30"}, "retreatCost": 2}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/118", "source_set_code": "30thC", "source_card_index": "118", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 4 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【钢】 欢庆 
如果自己的手牌为30张的话，则拿取自己的2张奖赏卡。然后，将自己的手牌全部放回牌库并重洗牌库。

【钢】 三重粉碎 50×
抛掷3次硬币，造成正面次数×50伤害。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 欢庆；cost=M；damage=；如果自己的手牌为30张的话，则拿取自己的2张奖赏卡。然后，将自己的手牌全部放回牌库并重洗牌库。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackFestivity` | 通过 |
| 招式 1: 三重粉碎；cost=M；damage=50×；抛掷3次硬币，造成正面次数×50伤害。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackTripleSmash` | 通过 |

关联新增测试：

- [`test_30thc_printings_116_to_121`](../tests/test_30thc_cards.gd#L1989)
- [`test_30thc_086_to_090_real_json_registration`](../tests/test_30thc_cards.gd#L1388)
- [`test_30thc_087_exact_thirty_takes_selected_hidden_prizes_then_shuffles_hand`](../tests/test_30thc_cards.gd#L1409)
- [`test_30thc_087_triple_smash_three_coins_before_weakness`](../tests/test_30thc_cards.gd#L1432)

### 120 喵喵

- 名称：喵喵；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`ae8b67067d78d9ed2768fcb38a2f18d4`。
- 本地文件：[30thC_120.json](../data/bundled_user/cards/30thC_120.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 60, "energyType": "C", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/120", "source_set_code": "30thC", "source_card_index": "120", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 3 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【无】【无】 聚宝功 30
从自己牌库上方抽取1张卡牌。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 聚宝功；cost=CC；damage=30；从自己牌库上方抽取1张卡牌。 | `res://scripts/effects/pokemon_effects/AttackDrawCards.gd` | 通过 |

关联新增测试：

- [`test_30thc_printings_116_to_121`](../tests/test_30thc_cards.gd#L1989)
- [`test_30thc_091_to_095_real_json_registration`](../tests/test_30thc_cards.gd#L1478)
- [`test_30thc_091_plain_attack_and_092_pay_day`](../tests/test_30thc_cards.gd#L1482)

### 121 百变怪

- 名称：百变怪；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`06a0c72fadedf66b5169678d05d53132`。
- 本地文件：[30thC_121.json](../data/bundled_user/cards/30thC_121.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 70, "energyType": "C", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/121", "source_set_code": "30thC", "source_card_index": "121", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 3 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【无】【无】 整蛊变身 
抛掷1次硬币，如果为正面，则选择自己牌库中的1张宝可梦，与这只宝可梦互换（放于其身上的卡牌、伤害指示物、特殊状态、效果等会全部继承）。如果互换了的话，则将这张卡牌放回牌库。并重洗牌库。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 整蛊变身；cost=CC；damage=；抛掷1次硬币，如果为正面，则选择自己牌库中的1张宝可梦，与这只宝可梦互换（放于其身上的卡牌、伤害指示物、特殊状态、效果等会全部继承）。如果互换了的话，则将这张卡牌放回牌库。并重洗牌库。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackPrankTransform` | 通过 |

关联新增测试：

- [`test_30thc_printings_116_to_121`](../tests/test_30thc_cards.gd#L1989)
- [`test_30thc_091_to_095_real_json_registration`](../tests/test_30thc_cards.gd#L1478)
- [`test_30thc_093_transforms_into_stage_two_preserving_all_attached_state`](../tests/test_30thc_cards.gd#L1494)

### 122 洗翠 索罗亚

- 名称：洗翠 索罗亚；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`3ca5cce2de4b9bb9b92726424408d2e9`。
- 本地文件：[30thC_122.json](../data/bundled_user/cards/30thC_122.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 60, "energyType": "C", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/122", "source_set_code": "30thC", "source_card_index": "122", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 3 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【无】 抓 20
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 抓；cost=C；damage=20； | `GameStateMachine.use_attack` -> `DamageCalculator`（纯伤害） | 通过 |

关联新增测试：

- [`test_30thc_printings_122_to_126`](../tests/test_30thc_cards.gd#L1993)
- [`test_30thc_096_to_100_real_json_registration`](../tests/test_30thc_cards.gd#L1551)
- [`test_30thc_098_plain_scratch_099_counter_floor_fifty`](../tests/test_30thc_cards.gd#L1581)

### 123 一家鼠

- 名称：一家鼠；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`4482a5c8b104aa74ad1a4f488e5bdb17`。
- 本地文件：[30thC_123.json](../data/bundled_user/cards/30thC_123.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Stage 1", "evolvesFrom": "一对鼠", "hp": 80, "energyType": "C", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/123", "source_set_code": "30thC", "source_card_index": "123", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 3 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【无】 一同啃住 
抛掷与自己场上的「一家鼠」数量相同次数的硬币，从对手牌库上方将出现正面次数×2张卡牌放于弃牌区。

【无】 拍击 40
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 一同啃住；cost=C；damage=；抛掷与自己场上的「一家鼠」数量相同次数的硬币，从对手牌库上方将出现正面次数×2张卡牌放于弃牌区。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackGnawTogether` | 通过 |
| 招式 1: 拍击；cost=C；damage=40； | `GameStateMachine.use_attack` -> `DamageCalculator`（纯伤害） | 通过 |

关联新增测试：

- [`test_30thc_printings_122_to_126`](../tests/test_30thc_cards.gd#L1993)
- [`test_30thc_096_to_100_real_json_registration`](../tests/test_30thc_cards.gd#L1551)
- [`test_30thc_100_counts_own_named_maushold_and_mills_two_per_head`](../tests/test_30thc_cards.gd#L1597)

### 124 呆火鳄ex

- 名称：呆火鳄ex；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`4c6d5da418dfa92f148946c38e0227c6`。
- 本地文件：[30thC_124.json](../data/bundled_user/cards/30thC_124.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 210, "energyType": "R", "weakness": {"energy": "W", "value": "×2"}, "resistance": null, "retreatCost": 2}。
- mechanic / ancient_trait / is_tags：{"mechanic": "ex", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/124", "source_set_code": "30thC", "source_card_index": "124", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 3 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【火】 致焦 
令对手的战斗宝可梦陷入【灼伤】状态。

【火】【火】【无】 愉快火焰 70×
造成自己已经获得的奖赏卡张数×70伤害。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 致焦；cost=R；damage=；令对手的战斗宝可梦陷入【灼伤】状态。 | `res://scripts/effects/pokemon_effects/EffectApplyStatus.gd` | 通过 |
| 招式 1: 愉快火焰；cost=RRC；damage=70×；造成自己已经获得的奖赏卡张数×70伤害。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackOwnTakenPrizeMultiplier` | 通过 |

关联新增测试：

- [`test_30thc_printings_122_to_126`](../tests/test_30thc_cards.gd#L1993)
- [`test_30thc_006_to_010_real_json_registration`](../tests/test_30thc_cards.gd#L111)
- [`test_30thc_009_fuecoco_uses_own_taken_prizes_zero_and_two`](../tests/test_30thc_cards.gd#L229)

### 125 甲贺忍蛙ex

- 名称：甲贺忍蛙ex；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`de1d3ab0a4a8f5e15498e7a5413c039c`。
- 本地文件：[30thC_125.json](../data/bundled_user/cards/30thC_125.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Stage 2", "evolvesFrom": "呱头蛙", "hp": 300, "energyType": "W", "weakness": {"energy": "L", "value": "×2"}, "resistance": null, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "ex", "ancient_trait": "Tera", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/125", "source_set_code": "30thC", "source_card_index": "125", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 4 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 1 项（含共享链路，非穷举缺陷数）；状态：已修复并验证。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【水】 隐秘斩 
给对手的1只宝可梦造成其身上放置的伤害指示物数量×30伤害。[备战宝可梦不计算弱点、抗性。]

【水】【水】 水流利刃 160
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 隐秘斩；cost=W；damage=；给对手的1只宝可梦造成其身上放置的伤害指示物数量×30伤害。[备战宝可梦不计算弱点、抗性。] | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackStealthSlash` | 通过 |
| 招式 1: 水流利刃；cost=WW；damage=160； | `GameStateMachine.use_attack` -> `DamageCalculator`（纯伤害） | 通过 |

关联新增测试：

- [`test_30thc_printings_122_to_126`](../tests/test_30thc_cards.gd#L1993)
- [`test_30thc_011_to_015_real_json_registration`](../tests/test_30thc_cards.gd#L115)
- [`test_30thc_015_greninja_scales_selected_targets_existing_counters`](../tests/test_30thc_cards.gd#L358)
- [`test_30thc_review_evolution_batch_one`](../tests/test_30thc_cards.gd#L1803)

复审修复：

- 普通进化及神奇糖果双路径；缺 Stage 1 实体时按稳定中英映射选择同线基础宝可梦，拒绝错误/当回合登场目标。

### 126 皮卡丘ex

- 名称：皮卡丘ex；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`2418309668a6102d250f4bdb4fd89742`。
- 本地文件：[30thC_126.json](../data/bundled_user/cards/30thC_126.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 190, "energyType": "L", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "ex", "ancient_trait": "Tera", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/126", "source_set_code": "30thC", "source_card_index": "126", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 3 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【无】 皮卡巡游 
选择自己牌库中任意数量的【基础】宝可梦，放于备战区。并重洗牌库。

【雷】【雷】【无】 十万伏特 200
将这只宝可梦身上附着的能量全部放于弃牌区。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 皮卡巡游；cost=C；damage=；选择自己牌库中任意数量的【基础】宝可梦，放于备战区。并重洗牌库。 | `res://scripts/effects/pokemon_effects/AttackCallForFamily.gd` | 通过 |
| 招式 1: 十万伏特；cost=LLC；damage=200；将这只宝可梦身上附着的能量全部放于弃牌区。 | `res://scripts/effects/pokemon_effects/AttackDiscardAllAttachedEnergyFromSelf.gd` | 通过 |

关联新增测试：

- [`test_30thc_printings_122_to_126`](../tests/test_30thc_cards.gd#L1993)
- [`test_30thc_046_to_050_real_json_registration`](../tests/test_30thc_cards.gd#L143)
- [`test_30thc_047_pika_parade_filters_and_fills_only_available_bench`](../tests/test_30thc_cards.gd#L774)

### 127 皮卡丘ex

- 名称：皮卡丘ex；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`a15ad334101499f5283f47631736ee1c`。
- 本地文件：[30thC_127.json](../data/bundled_user/cards/30thC_127.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 190, "energyType": "L", "weakness": {"energy": "F", "value": "×2"}, "resistance": null, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "ex", "ancient_trait": "Tera", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/127", "source_set_code": "30thC", "source_card_index": "127", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 3 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【雷】 麻麻狂热 
选择自己手牌中任意数量的基本能量，以任意方式附着于自己的宝可梦身上。

【雷】【雷】【无】 打雷 200
给这只宝可梦也造成30伤害。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 麻麻狂热；cost=L；damage=；选择自己手牌中任意数量的基本能量，以任意方式附着于自己的宝可梦身上。 | `res://scripts/effects/CSV9CEffects.gd::AttackHandBasicEnergyAttach` | 通过 |
| 招式 1: 打雷；cost=LLC；damage=200；给这只宝可梦也造成30伤害。 | `res://scripts/effects/pokemon_effects/EffectSelfDamage.gd` | 通过 |

关联新增测试：

- [`test_30thc_printings_127_to_134`](../tests/test_30thc_cards.gd#L1997)
- [`test_30thc_046_to_050_real_json_registration`](../tests/test_30thc_cards.gd#L143)
- [`test_30thc_048_energy_fever_splits_only_basic_hand_energy_among_own_targets`](../tests/test_30thc_cards.gd#L797)

### 130 仙子伊布ex

- 名称：仙子伊布ex；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`c1adb66087005031a31ed27fb30dcd96`。
- 本地文件：[30thC_130.json](../data/bundled_user/cards/30thC_130.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Stage 1", "evolvesFrom": "伊布", "hp": 270, "energyType": "P", "weakness": {"energy": "M", "value": "×2"}, "resistance": null, "retreatCost": 2}。
- mechanic / ancient_trait / is_tags：{"mechanic": "ex", "ancient_trait": "Tera", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/130", "source_set_code": "30thC", "source_card_index": "130", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 3 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【超】【无】【无】 多彩和弦 50×
造成自己所有宝可梦身上附着的基本能量的属性种类数量×50伤害。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 多彩和弦；cost=PCC；damage=50×；造成自己所有宝可梦身上附着的基本能量的属性种类数量×50伤害。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackColorfulHarmony` | 通过 |

关联新增测试：

- [`test_30thc_printings_127_to_134`](../tests/test_30thc_cards.gd#L1997)
- [`test_30thc_056_to_060_real_json_registration`](../tests/test_30thc_cards.gd#L954)
- [`test_30thc_056_psychic_counts_energy_and_059_counts_distinct_basic_types`](../tests/test_30thc_cards.gd#L958)

### 132 基拉祈ex

- 名称：基拉祈ex；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`b64c857949b418dc7c83e2d803fa5f60`。
- 本地文件：[30thC_132.json](../data/bundled_user/cards/30thC_132.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 160, "energyType": "M", "weakness": {"energy": "R", "value": "×2"}, "resistance": {"energy": "G", "value": "-30"}, "retreatCost": 1}。
- mechanic / ancient_trait / is_tags：{"mechanic": "ex", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/132", "source_set_code": "30thC", "source_card_index": "132", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 3 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 1 项（含共享链路，非穷举缺陷数）；状态：已修复并验证。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【无】 愿望成真 
从牌库上方抽取卡牌，直到自己的手牌变为7张为止。

【无】【无】【无】 高速星星 150
这个招式的伤害不计算弱点、抗性以及对手战斗宝可梦身上所附加的效果。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 愿望成真；cost=C；damage=；从牌库上方抽取卡牌，直到自己的手牌变为7张为止。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackWishComeTrue` | 通过 |
| 招式 1: 高速星星；cost=CCC；damage=150；这个招式的伤害不计算弱点、抗性以及对手战斗宝可梦身上所附加的效果。 | `res://scripts/effects/pokemon_effects/AttackIgnoreWeaknessResistanceAndEffects.gd` | 通过 |

关联新增测试：

- [`test_30thc_printings_127_to_134`](../tests/test_30thc_cards.gd#L1997)
- [`test_30thc_081_to_085_real_json_registration`](../tests/test_30thc_cards.gd#L1304)
- [`test_30thc_081_mandatory_seven_and_swift_ignores_weakness_and_protection`](../tests/test_30thc_cards.gd#L1308)

复审修复：

- 高速星星限定第二招式，避免无视弱点/效果标记串到第一招式。

### 133 暴飞龙ex

- 名称：暴飞龙ex；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`8b1f439835db2ae1688662a68d3ac62c`。
- 本地文件：[30thC_133.json](../data/bundled_user/cards/30thC_133.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Stage 2", "evolvesFrom": "甲壳龙", "hp": 330, "energyType": "N", "weakness": null, "resistance": null, "retreatCost": 2}。
- mechanic / ancient_trait / is_tags：{"mechanic": "ex", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/133", "source_set_code": "30thC", "source_card_index": "133", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 4 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 1 项（含共享链路，非穷举缺陷数）；状态：已修复并验证。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【无】 轰鸣呼声 
选择自己弃牌区中最多3张【龙】宝可梦，放于备战区。

【火】【水】 龙之波动 240
将自己牌库上方2张卡牌放于弃牌区。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 轰鸣呼声；cost=C；damage=；选择自己弃牌区中最多3张【龙】宝可梦，放于备战区。 | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackRoaringCall` | 通过 |
| 招式 1: 龙之波动；cost=RW；damage=240；将自己牌库上方2张卡牌放于弃牌区。 | `res://scripts/effects/pokemon_effects/AttackMillSelfDeck.gd` | 通过 |

关联新增测试：

- [`test_30thc_printings_127_to_134`](../tests/test_30thc_cards.gd#L1997)
- [`test_30thc_086_to_090_real_json_registration`](../tests/test_30thc_cards.gd#L1388)
- [`test_30thc_088_revives_evolved_dragons_and_honors_explicit_zero`](../tests/test_30thc_cards.gd#L1447)
- [`test_30thc_review_evolution_batch_two`](../tests/test_30thc_cards.gd#L1807)

复审修复：

- 普通进化及神奇糖果双路径；缺 Stage 1 实体时按稳定中英映射选择同线基础宝可梦，拒绝错误/当回合登场目标。

### 134 超梦ex

- 名称：超梦ex；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`11641ee70b056fe9c3ef8d2e04ef6dd7`。
- 本地文件：[30thC_134.json](../data/bundled_user/cards/30thC_134.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 230, "energyType": "P", "weakness": {"energy": "D", "value": "×2"}, "resistance": {"energy": "F", "value": "-30"}, "retreatCost": 2}。
- mechanic / ancient_trait / is_tags：{"mechanic": "ex", "ancient_trait": "Tera", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/134", "source_set_code": "30thC", "source_card_index": "134", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 4 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
【超】【超】 光子子弹 
给对手所有「宝可梦【ex】」各造成50伤害。[备战宝可梦不计算弱点、抗性。]

【超】【超】【超】 精神之力 230
在下一个自己的回合，这只宝可梦无法使用招式。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 招式 0: 光子子弹；cost=PP；damage=；给对手所有「宝可梦【ex】」各造成50伤害。[备战宝可梦不计算弱点、抗性。] | `res://scripts/effects/ThirtiethCelebrationEffects.gd::AttackPhotonBullet` | 通过 |
| 招式 1: 精神之力；cost=PPP；damage=230；在下一个自己的回合，这只宝可梦无法使用招式。 | `res://scripts/effects/pokemon_effects/AttackSelfAllAttacksLockNextTurn.gd` | 通过 |

关联新增测试：

- [`test_30thc_printings_127_to_134`](../tests/test_30thc_cards.gd#L1997)
- [`test_30thc_051_to_055_real_json_registration`](../tests/test_30thc_cards.gd#L147)
- [`test_30thc_051_and_055_second_attack_locks_all_attacks`](../tests/test_30thc_cards.gd#L866)
- [`test_30thc_055_photon_bullet_hits_only_ex_with_active_weakness`](../tests/test_30thc_cards.gd#L933)

### 135 梦幻ex

- 名称：梦幻ex；英文=；中文显示=。
- 类型=Pokemon；标记=J；源 effect_id=`dd6e658057478ff1eb223c71000b08a2`。
- 本地文件：[30thC_135.json](../data/bundled_user/cards/30thC_135.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": "Basic", "evolvesFrom": "", "hp": 160, "energyType": "P", "weakness": {"energy": "D", "value": "×2"}, "resistance": {"energy": "F", "value": "-30"}, "retreatCost": 0}。
- mechanic / ancient_trait / is_tags：{"mechanic": "ex", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/135", "source_set_code": "30thC", "source_card_index": "135", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 2 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text
特性: 记忆螺旋
这只宝可梦可以使用自己备战宝可梦所拥有的全部招式。[需要满足使用招式所需能量。]

【超】 瞬移破坏 30
若希望，可以将这只宝可梦与备战宝可梦互换。
```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 特性 记忆螺旋: 这只宝可梦可以使用自己备战宝可梦所拥有的全部招式。[需要满足使用招式所需能量。] | `res://scripts/effects/pokemon_effects/AbilityOwnBenchAttacks.gd` -> EffectProcessor/GSM | 通过 |
| 招式 0: 瞬移破坏；cost=P；damage=30；若希望，可以将这只宝可梦与备战宝可梦互换。 | `res://scripts/effects/pokemon_effects/AttackSwitchSelfToBench.gd` | 通过 |

关联新增测试：

- [`test_30thc_printings_135_mew_copies_real_unown_and_earns_extra_prize`](../tests/test_30thc_cards.gd#L2001)
- [`test_30thc_056_to_060_real_json_registration`](../tests/test_30thc_cards.gd#L954)

### GRA 基本草能量

- 名称：基本草能量；英文=Grass Energy；中文显示=。
- 类型=Basic Energy；标记=G；源 effect_id=`5e2d0ce37ca0c539aa45908da10544a0`。
- 本地文件：[30thC_GRA.json](../data/bundled_user/cards/30thC_GRA.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": null, "evolvesFrom": null, "hp": null, "energyType": null, "weakness": null, "resistance": null, "retreatCost": null}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/GRA", "source_set_code": "30thC", "source_card_index": "GRA", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 1 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text

```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 上述训练家/能量文本 | `EffectProcessor 能量供给 / GSM attach_energy` | 通过 |

关联新增测试：

- [`test_30thc_printings_basic_energy_grass_fire_water_lightning`](../tests/test_30thc_cards.gd#L2038)

### FIR 基本火能量

- 名称：基本火能量；英文=Fire Energy；中文显示=。
- 类型=Basic Energy；标记=G；源 effect_id=`22db5405bf0cce61a00aa8082cdd1e65`。
- 本地文件：[30thC_FIR.json](../data/bundled_user/cards/30thC_FIR.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": null, "evolvesFrom": null, "hp": null, "energyType": null, "weakness": null, "resistance": null, "retreatCost": null}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/FIR", "source_set_code": "30thC", "source_card_index": "FIR", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 1 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text

```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 上述训练家/能量文本 | `EffectProcessor 能量供给 / GSM attach_energy` | 通过 |

关联新增测试：

- [`test_30thc_printings_basic_energy_grass_fire_water_lightning`](../tests/test_30thc_cards.gd#L2038)

### WAT 基本水能量

- 名称：基本水能量；英文=Water Energy；中文显示=。
- 类型=Basic Energy；标记=G；源 effect_id=`0cf075ae61b8a0b4e9151e5146c3aa26`。
- 本地文件：[30thC_WAT.json](../data/bundled_user/cards/30thC_WAT.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": null, "evolvesFrom": null, "hp": null, "energyType": null, "weakness": null, "resistance": null, "retreatCost": null}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/WAT", "source_set_code": "30thC", "source_card_index": "WAT", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 1 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text

```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 上述训练家/能量文本 | `EffectProcessor 能量供给 / GSM attach_energy` | 通过 |

关联新增测试：

- [`test_30thc_printings_basic_energy_grass_fire_water_lightning`](../tests/test_30thc_cards.gd#L2038)

### LIG 基本雷能量

- 名称：基本雷能量；英文=Lightning Energy；中文显示=。
- 类型=Basic Energy；标记=G；源 effect_id=`45550fd10011f6ade7eef16ba88788cf`。
- 本地文件：[30thC_LIG.json](../data/bundled_user/cards/30thC_LIG.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": null, "evolvesFrom": null, "hp": null, "energyType": null, "weakness": null, "resistance": null, "retreatCost": null}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/LIG", "source_set_code": "30thC", "source_card_index": "LIG", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 1 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text

```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 上述训练家/能量文本 | `EffectProcessor 能量供给 / GSM attach_energy` | 通过 |

关联新增测试：

- [`test_30thc_printings_basic_energy_grass_fire_water_lightning`](../tests/test_30thc_cards.gd#L2038)

### PSY 基本超能量

- 名称：基本超能量；英文=Psychic Energy；中文显示=。
- 类型=Basic Energy；标记=G；源 effect_id=`41b2d1a95fafc35e4cf39383ffae928a`。
- 本地文件：[30thC_PSY.json](../data/bundled_user/cards/30thC_PSY.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": null, "evolvesFrom": null, "hp": null, "energyType": null, "weakness": null, "resistance": null, "retreatCost": null}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/PSY", "source_set_code": "30thC", "source_card_index": "PSY", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 1 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text

```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 上述训练家/能量文本 | `EffectProcessor 能量供给 / GSM attach_energy` | 通过 |

关联新增测试：

- [`test_30thc_printings_basic_energy_psychic_fighting_darkness_metal`](../tests/test_30thc_cards.gd#L2042)

### FIG 基本斗能量

- 名称：基本斗能量；英文=Fighting Energy；中文显示=。
- 类型=Basic Energy；标记=G；源 effect_id=`9fedb80a97ddd5cc8b8022a21364c326`。
- 本地文件：[30thC_FIG.json](../data/bundled_user/cards/30thC_FIG.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": null, "evolvesFrom": null, "hp": null, "energyType": null, "weakness": null, "resistance": null, "retreatCost": null}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/FIG", "source_set_code": "30thC", "source_card_index": "FIG", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 1 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text

```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 上述训练家/能量文本 | `EffectProcessor 能量供给 / GSM attach_energy` | 通过 |

关联新增测试：

- [`test_30thc_printings_basic_energy_psychic_fighting_darkness_metal`](../tests/test_30thc_cards.gd#L2042)

### DAR 基本恶能量

- 名称：基本恶能量；英文=Darkness Energy；中文显示=。
- 类型=Basic Energy；标记=G；源 effect_id=`46c769fc57a6c250c560df648bb779f8`。
- 本地文件：[30thC_DAR.json](../data/bundled_user/cards/30thC_DAR.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": null, "evolvesFrom": null, "hp": null, "energyType": null, "weakness": null, "resistance": null, "retreatCost": null}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/DAR", "source_set_code": "30thC", "source_card_index": "DAR", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 1 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text

```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 上述训练家/能量文本 | `EffectProcessor 能量供给 / GSM attach_energy` | 通过 |

关联新增测试：

- [`test_30thc_printings_basic_energy_psychic_fighting_darkness_metal`](../tests/test_30thc_cards.gd#L2042)

### MET 基本钢能量

- 名称：基本钢能量；英文=Metal Energy；中文显示=。
- 类型=Basic Energy；标记=G；源 effect_id=`4557c01497b81767fdaa0004089ecfb3`。
- 本地文件：[30thC_MET.json](../data/bundled_user/cards/30thC_MET.json)；源：tcg_mik / zh-CN。
- 源元数据：{"stage": null, "evolvesFrom": null, "hp": null, "energyType": null, "weakness": null, "resistance": null, "retreatCost": null}。
- mechanic / ancient_trait / is_tags：{"mechanic": "", "ancient_trait": "", "is_tags": []}。
- 来源字段：{"source_provider": "tcg_mik", "source_language": "zh-CN", "source_url": "https://tcg.mik.moe/cards/30thC/MET", "source_set_code": "30thC", "source_card_index": "MET", "source_prints": [], "source_parser_version": 1}。
- 英文原版核对：非 Limitless，不适用；中文源为真理来源，057 另保留照片英文身份。
- 快扫：通过；描述匹配：通过；跨层核对：通过；本次关联测试 1 个；旧测试：共享效果见功能分组（057/060 另有照片卡专项，不虚计独占数量）。
- 复审修正记录 0 项（含共享链路，非穷举缺陷数）；状态：已实现并复审，无本卡未结项。
- 入口：EffectRegistry -> ThirtiethCelebrationRegistry（宝可梦）/通用训练家与能量注册。

源描述原文：

```text

```

| 规则原文 -> 参数 | 实现 -> 消费者 | 匹配 |
|---|---|---|
| 上述训练家/能量文本 | `EffectProcessor 能量供给 / GSM attach_energy` | 通过 |

关联新增测试：

- [`test_30thc_printings_basic_energy_psychic_fighting_darkness_metal`](../tests/test_30thc_cards.gd#L2042)

## 不在 G/H/I/J 范围的版本

- 136 皮卡丘：标记 `无`。
- 137 喷火龙：标记 `无`。
- 138 小霞：标记 `无`。
- 139 莉佳的胖丁：标记 `无`。
- 140 狃拉：标记 `无`。
- 141 闪耀时拉比：标记 `无`。
- 142 洛奇亚：标记 `无`。
- 143 优雅猫：标记 `无`。
- 144 邪恶班基拉斯：标记 `无`。
- 145 巨钳螳螂ex：标记 `无`。
- 146 巨金怪：标记 `无`。
- 147 帕路奇亚LV.X：标记 `无`。
- 148 由克希：标记 `无`。
- 149 叉字蝠G：标记 `无`。
- 150 耿鬼：标记 `无`。
- 151 达克莱伊&克雷色利亚LEGEND：标记 `无`。
- 152 达克莱伊&克雷色利亚LEGEND：标记 `无`。
- 153 N：标记 `无`。
- 154 烈空坐EX：标记 `无`。
- 155 盖诺赛克特EX：标记 `无`。
- 156 M沙奈朵EX：标记 `无`。
- 157 甲贺忍蛙BREAK：标记 `无`。
- 158 索尔迦雷欧GX：标记 `A`。
- 159 爆肌蚊GX：标记 `A`。
- 160 皮卡丘&捷克罗姆GX：标记 `C`。
- 161 苍响V：标记 `D`。
- 162 雷公：标记 `D`。
- 163 梦幻VMAX：标记 `E`。
- 164 阿尔宙斯VSTAR：标记 `F`。
- 165 鲤鱼王：标记 `F`。
