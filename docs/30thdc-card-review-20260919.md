# 30thDC 功能与测试完整复审

日期：2026-09-19。范围为原始 [30thDC](https://tcg.mik.moe/cards/30thDC) 45 个印刷版本及本次变更实际影响的规则、玩家交互和作者 Host 链路。原始规则和字段仍以 [冻结源数据](../tests/fixtures/30thdc_source.json) 为准；[逐卡清单](30thdc-card-audit.md) 保留首轮记录。

## 修复结果

1. **混乱判定顺序错误。** 三首恶龙原先在生成交互步骤时先投三枚招式硬币、发布弃能量选择，最后执行攻击才判定混乱。现在由 `GameStateMachine.prepare_attack_interaction()` 先完成混乱判定；反面只受到自身 30 点伤害并结束攻击，正面结果在同一次攻击最终结算时复用。玩家入口、Headless/Host 入口、普通及借用招式采用同一处理。非法目标先经过无随机副作用的预检；成功判定后不能取消回主行动，后续交互也保持此限制。
2. **多重能量遗漏合法选法。** 两次正面时，原实现选择一张双重涡轮能量后立即结束，无法从两张多重能量卡各选一个能量并弃掉两张。修复后，达到所需能量单位且仍可选择另一物理卡时，出现明确“完成弃置／继续选择”窗口。最终校验同时限制所选物理牌张数及提供的能量总量，拒绝重复、过多、无效及不完整的选择。此选法依据官方针对“双重钳击”的[两张双无色能量裁定](https://www.pokemon-card.com/rules/faq/search.php?freeword=%E3%82%B7%E3%82%B6%E3%83%AA%E3%82%AC%E3%83%BC&regulation_faq_main_item1=all)，并将相同的“选择能量单位”规则应用于三首恶龙。
3. **空搜索缺少查看入口。** 樱花儿、比克提尼的共享搜索实现遇到无匹配卡时直接跳过交互，玩家无法按规则查看己方牌库。现在提供空搜索确认，以及仅向玩家展示完整己方牌库的只读后续步骤；最终仍洗牌。公开 Host 的候选及可见范围继续按契约限制。

修复位于：

- [ThirtiethDeluxeEffects.gd](../scripts/effects/ThirtiethDeluxeEffects.gd)：三首恶龙预算、继续选择、无随机副作用的输入预检。
- [GameStateMachine.gd](../scripts/engine/GameStateMachine.gd)、[EffectProcessor.gd](../scripts/engine/EffectProcessor.gd)：攻击宣告及验证顺序。
- [BattleSceneSetupEffectAiRuntime.gd](../scenes/battle/runtime/BattleSceneSetupEffectAiRuntime.gd)、[HeadlessMatchBridge.gd](../scripts/ai/HeadlessMatchBridge.gd)、[BattleEffectInteractionController.gd](../scripts/ui/battle/BattleEffectInteractionController.gd)：真实入口及已宣告攻击的交互锁定。
- [AttackSearchAndAttach.gd](../scripts/effects/pokemon_effects/AttackSearchAndAttach.gd)、[AttackCallForFamily.gd](../scripts/effects/pokemon_effects/AttackCallForFamily.gd)：空搜索确认和只读牌库查看。

## 测试复审

首轮 `test_30thdc_cards.gd` 的 24 项保留，其中三首恶龙单张双重能量用例改为明确选择“完成弃置”，而不是错误地要求没有后续窗口。

新增 [test_30thdc_review.gd](../tests/test_30thdc_review.gd) 的 15 项测试覆盖：

- 从主行动经真实动作执行器、Headless 交互、步骤解析器、Host 当前索引提交到最终结算的 18 个场景；每一步检查窗口更新及审计计数。
- 9 条实际进化关系的合法进化、同回合禁止进化、伤害保留和特殊状态清除。
- 混乱反面阻止招式投币和选择；玩家 UI 方法、直接引擎调用及正面重入；非法目标不消耗混乱硬币；正面宣告后不可取消。
- 三首恶龙一张／两张多重能量及超额选择；真实 Host 的完成／继续分支；雾之能量防护。
- 樱花儿、比克提尼空搜索及完整 Host 的明确零张选择，确认不偷偷自动选牌。
- 粉碎之锤、宝可梦捕捉器的反面完整流程，仅投一次、不打开目标窗口但正常消耗物品。
- 女服务生缺少、重复或错误归属分配的原子拒绝，手牌、牌库顺序和弃牌区保持不变。
- 索罗亚克的减费实际进入撤退支付；黑暗鸦的效果防护；热带龙排除旧回合、错误归属和当前回合的昏厥记录。

规则、卡库及卡图再次离线核验：45 份 JSON 与冻结详情转换结果精确一致，45 张 WebP 图可解码，manifest 中 90 个资源引用唯一且大小写正确，种子内容修订一致。

## 最终统一验证

同一 Godot 4.6.1 进程运行以下 20 个功能套件：**477 通过、0 失败**；另串行运行 Headless 套件：**38 通过、0 失败**。合计 **515 项全部通过**，两个进程返回码均为 0。校验了套件实际发现数，未将漏跑或零测试当作通过。

| 套件 | 通过 |
|---|---:|
| 30thdcCards | 24 |
| 30thdcReview | 15 |
| 30thcCards | 123 |
| A3ExternalDecisionPort | 19 |
| CompetitivePolicyV2 | 19 |
| UcisEffectOptionShapes | 7 |
| CardDatabaseSeed | 82 |
| CoinFlipInteractionOrder | 2 |
| DamageCalculator | 12 |
| FullLibrarySearchAssignmentUI | 6 |
| FullLibrarySearchNonLeakage | 6 |
| FullLibrarySearchPokemonUI | 6 |
| FullLibrarySearchSupporterStadiumUI | 10 |
| FullLibrarySearchTrainerItemsUI | 5 |
| FullLibrarySearchUI | 6 |
| GameStateMachine | 80 |
| RuleValidator | 25 |
| SharedInteractionRegressions | 8 |
| SpecialStatusRules | 13 |
| UcisInteractionCompiler | 9 |
| HeadlessMatchBridge（单独串行） | 38 |

本地证据目录：`.tmp/30thdc-card-review/`。

- 最终结果：`final-functional.log`、`final-headless.log`、`final-summary.json`。
- 失败到通过：`confirmed-red.log` → `first-green.log`（混乱顺序）；`second-red.log` → 后续通过日志（多重能量）；`third-red.log` → `third-green.log`（空搜索、攻击取消）；`preflight-red.log` → `preflight-green-*`（输入预检）。
- 本轮修改前的共享文件保存在 `before/`，本轮差异保存在 `review-only.patch`，不含此前工作区的其他修改。

**退出诊断单列：** 功能批次退出仍报告 ObjectDB 和 181 个资源未释放；Headless 套件退出报告 34 个 CanvasItem RID、ObjectDB 和 205 个资源未释放。这些是进程退出清理诊断，未造成脚本测试失败，退出码为 0；本次没有把它们标成已修复，也不把 515/515 表述为“无警告”验收。新增复审套件单独执行 15/15 通过，无这些退出诊断。

## 复跑命令

在项目根目录执行，以下测试串行运行：

```powershell
$suites = '30thdcCards,30thdcReview,30thcCards,SpecialStatusRules,CoinFlipInteractionOrder,GameStateMachine,RuleValidator,DamageCalculator,SharedInteractionRegressions,FullLibrarySearchPokemonUI,FullLibrarySearchAssignmentUI,FullLibrarySearchNonLeakage,FullLibrarySearchUI,FullLibrarySearchTrainerItemsUI,FullLibrarySearchSupporterStadiumUI,UcisInteractionCompiler,UcisEffectOptionShapes,A3ExternalDecisionPort,CompetitivePolicyV2,CardDatabaseSeed'
& 'D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . -s res://tests/FunctionalTestRunner.gd -- "--suite=$suites"
& 'D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_headless_match_bridge.gd
python scripts/tools/verify_30thdc_bundle.py
python tools/ptcgdap/build_bundled_seed_revision.py --check
```

本次达到源数据、Godot 效果、玩家交互方法、UCIS/Host 流程和相关共享回归的验证范围；没有宣称完成官方引擎逐局一致性、Android 真机或全部界面人工点击验收。没有运行训练／对战评测池，没有修改 `ptcgabc`、私有云，没有提交或发布。

回滚时只撤销本轮差异及新增复审测试／文档，不整文件还原共享规则或场景文件。尤其应保留本轮之前的所有未提交工作；若已出现后续改动，先比对 `before/` 与 `review-only.patch` 再逐段处理。
