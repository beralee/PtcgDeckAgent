# 30thDC 全套卡牌实现记录

**2026-09-19 追加完整复审：发现并修复混乱判定顺序、三首恶龙多重能量的选择分支，以及空搜索查看牌库三个功能遗漏；新增 15 项复审测试。最终同一批运行 20 个功能套件 477/477 通过，另一个 Headless 套件 38/38 通过，合计 515/515。** 具体修复、回归和退出警告见 [复审记录](30thdc-card-review-20260919.md)。下文的 283 项是首轮实现记录。

完成日期：2026-09-18。按 `card-audit` 核对 [30 周年庆典 豪华卡组套装](https://tcg.mik.moe/cards/30thDC) 的 **45 个印刷版本**：001–040，以及 GRA、FIR、LIG、PSY、DAR 五张基本能量。不按标记年份过滤；025、026 两种伊布插画均保留。

## 结果与来源

- 45 份卡牌 JSON、45 张卡图已加入内置卡库和导出清单；实际 `CardDatabase` 与组卡卡池均能加载全部 45 张。
- 修复前有 21 张被标记为未实现；修复后为 0。另将比克提尼的同名通用招式从检索 1 只改为此印刷规定的至多 2 只。
- 规则以冻结的卡牌详情为依据，逐张保留费用、伤害、规则文本、HP、弱抗、撤退费、进化来源、特性、`effect_id` 和 `source_*`。离线核验与 Godot 解析核验均通过。
- 原始详情保存在 [冻结源数据](../tests/fixtures/30thdc_source.json)，来源为 `/api/v3/card/product-detail` 与 `/api/v3/card/card-detail`，抓取日期为 2026-09-18。
- 冻结源数据 SHA-256：`B0C0DD7480D3ADC9D732EE75BF21513BBD5685C6C45867C99D5A5DFCEAC3735E`。
- 卡图按项目现有工具转换为 WebP，保留 `.png.bin` 资源命名；45 张从 12.20 MiB 降至 1.71 MiB，Godot 解码全部通过。种子内容修订已重新计算。

本次只新增此系列的效果、注册、数据、测试和报告，并在共享注册入口增加两次调用。复用了工作区已有的 `ThirtiethCelebrationEffects` 及其他通用实现，保留原有未提交工作。运行时全部在 Godot 本地执行。

## 实现与交互

入口为 [ThirtiethDeluxeRegistry.gd](../scripts/engine/ThirtiethDeluxeRegistry.gd)，新增规则在 [ThirtiethDeluxeEffects.gd](../scripts/effects/ThirtiethDeluxeEffects.gd)。所有卡的真实注册、原始字段、卡库可见性及卡图均由 [test_30thdc_cards.gd](../tests/test_30thdc_cards.gd) 验证。

表中“Host”表示测试经过真实效果步骤、UCIS 编译、作者 Host 投影、当前窗口索引提交和 `GameStateMachine` 最终结算。总计 **29 次成功窗口提交**，包含女服务生双方座位、三首恶龙连续重观察、超梦第二招式及小刚两种搜索分支；消费过的窗口拒绝重放，候选顺序变化后仍绑定所选牌。Host 审计中的策略错误、同窗口回退、非法输出和引擎拒绝计数均为 0。

| 卡号 | 卡名 | 规则核对及实现 | 行为与交互证据 |
|---|---|---|---|
| 001 | 热带龙 | `AttackComeback`：上个对手回合己方因招式伤害昏厥，第一招式加 90；第二招式 90 | 条件成立/不成立、招式隔离；消费现有伤害昏厥记录 |
| 002 | 樱花宝 | 正面时下个对手回合防招式伤害和效果；第二招式 10 | 正反面、实际阻止伤害及麻痹、保护到期 |
| 003 | 樱花儿 | `AttackSearchAndAttach`：牌库至多 2 张基本能量任意分配；第二招式 50 | Host 分配；两张附同一只、可选零张 |
| 004 | 六尾 | `AttackCoinFlipOrFail`：30，反面招式失败 | 正反面分别造成 30/0 |
| 005 | 九尾 | 原生伤害 60 | 实际攻击，无多余效果 |
| 006 | 比克提尼 | `AttackCallForFamily(2)`：至多 2 只基础宝可梦到备战；第二招式 50 | Host 检索两只、排除进化、明确零张不回退 |
| 007 | 捷拉奥拉 | 第一招式 20 并抽 1；第二招式 50 并对指定备战造成 20 | 抽牌数量；Host 指定备战目标 |
| 008 | 电音婴 | 原生伤害 10 | 实际攻击，无多余效果 |
| 009 | 颤弦蝾螈 | 原生伤害 80 | 实际攻击，无多余效果 |
| 010 | 超梦 | 弃牌区至多 2 张基本能量附于同一己方目标；第二招式 120 并弃自身 1 个能量 | 两个招式均通过 Host；所选牌及能量结算 |
| 011 | 梦幻 | `AttackPsychic`：10 加对手战斗宝可梦每个能量 40 | 双重涡轮加基本能量合计 3 个，造成 130 |
| 012 | 玛力露 | 原生伤害 30 | 实际攻击，无多余效果 |
| 013 | 玛力露丽 | 90，正面麻痹 | 正反面状态及伤害 |
| 014 | 太阳伊布ex | 己方场上宝可梦总数乘 30，包含战斗宝可梦 | 战斗加两只备战造成 90 |
| 015 | 克雷色利亚 | 第一招式 30 并回复自身 30；第二招式 100 | 仅第一招式治疗 |
| 016 | 花疗环环 | `AttackSoothingScent`：回复己方 1 只备战宝可梦 80；第二招式 30 | Host 选指定备战；拒绝选择自身战斗宝可梦 |
| 017 | 月亮伊布ex | 对手战斗宝可梦已有伤害时 100 加 140 | 有/无既有伤害分别造成 240/100 |
| 018 | 黑暗鸦 | `AttackGentleGrip`：20，正面下个对手回合不能撤退 | 正反面、现有撤退锁定消费者 |
| 019 | 索罗亚 | 原生伤害 40 | 实际攻击，无多余效果 |
| 020 | 索罗亚克 | `AbilityNightPath`：自身在备战时己方战斗撤退费减 2；招式 90 | 备战限制、可叠加、敌我隔离、特性压制、原生伤害 |
| 021 | 单首龙 | 两招式分别 10/20 | 两招式实际攻击 |
| 022 | 双首暴龙 | 两招式分别 20/50 | 两招式实际攻击 |
| 023 | 三首恶龙 | `AttackTripleBite`：投 3 次，按正面数弃对手战斗能量；第二招式 140 | Host 连续选择；多重能量可整张计数或从多张各选 1 个，明确完成/继续；不足、零正面、重复引用；混乱先判定，预览不投币、重建不重复投币 |
| 024 | 袋兽 | 20 加自身每个伤害指示物 10；第二招式 100 | 自身 50 点伤害时第一招式 70，第二招式不串效果 |
| 025 | 伊布 | `AttackQuickAttack`：20，正面加 20 | 正反面；额外伤害先于弱点计算；预览不消耗硬币 |
| 026 | 伊布 | 与 025 同规则，独立印刷及卡图 | 真实印刷注册、反面实际造成 20；复用同 effect_id 的正面验证 |
| 027 | 小陨星 | `AttackMeteorShot`：弃自身全部能量，对指定对手宝可梦造成 120 | Host 指定目标；战斗弱点、备战不算弱点、防护、双重涡轮减伤；非法己方目标拒绝且不弃能量 |
| 028 | 伤药 | `Potion`：选择己方受伤宝可梦回复 30 | Host 备战治疗；对手目标拒绝且不消耗卡牌 |
| 029 | 粉碎之锤 | `EffectCrushingHammer`：正面丢弃指定对手宝可梦 1 张能量卡 | Host 选择备战附着能量并弃置 |
| 030 | 高级球 | `EffectUltraBall`：弃 2 张手牌后检索 1 只宝可梦 | Host 弃牌及搜索两窗口；费用和所选结果 |
| 031 | 宝可平板 | `EffectPokePad`：检索无规则框宝可梦 | Host 候选顺序重排、排除规则框、所选牌入手 |
| 032 | 宝可梦交替 | `EffectSwitchPokemon`：己方战斗与指定备战交换 | Host 指定第二只备战及最终场位 |
| 033 | 宝可梦捕捉器 | `EffectPokemonCatcher`：正面将指定对手备战拉至战斗场 | Host 正面选择及最终场位 |
| 034 | 艾莉丝的斗志 | `IrissFightingSpirit`：弃 1 张手牌后补至 6 | Host 支付所选弃牌、手牌数量 |
| 035 | 女服务生 | `Waitress`：查看牌库上方 6 张，选 1 张基本能量附于己方宝可梦，其余洗回 | 双座位 Host 源牌/目标两窗口；第 7 张不可见不可选；不足 6、无能量和空牌库 |
| 036 | 盖伊 | `EffectDrawCards(3)` | 实际抽取 3 张 |
| 037 | 裁判 | `EffectShuffleDrawCards`：双方手牌洗回，各抽 4 | 双方各 4 张 |
| 038 | 小刚的发掘 | `EffectBrocksScouting`：至多 2 只基础或 1 只进化宝可梦 | 两分支均通过 Host，重新观察后选牌入手 |
| 039 | 老大的指令 | `EffectBossOrders`：指定对手备战切至战斗场 | Host 指定第二只备战及最终场位 |
| 040 | 莉莉艾的决心 | `EffectLilliesDetermination`：洗回抽 6，剩余奖赏恰为 6 时抽 8 | 剩余奖赏 6/5 分别抽 8/6 |
| GRA | 基本草能量 | 标准草能量 G | 实际手动附着、1 个能量供给 |
| FIR | 基本火能量 | 标准火能量 R | 实际手动附着、1 个能量供给 |
| LIG | 基本雷能量 | 标准雷能量 L | 实际手动附着、1 个能量供给 |
| PSY | 基本超能量 | 标准超能量 P | 实际手动附着、1 个能量供给 |
| DAR | 基本恶能量 | 标准恶能量 D | 实际手动附着、1 个能量供给 |

## 验证记录

Godot 4.6.1，当前 Windows 工作区。以下共 **283 项测试通过，断言失败 0**：

| 套件 | 通过/总数 | 本地日志（`.tmp/30thdc-card-audit/`） |
|---|---:|---|
| `tests/test_30thdc_cards.gd` | 24/24 | `final-test_30thdc_cards.log` |
| `tests/test_30thc_cards.gd` | 123/123 | `regression-30thc.log` |
| `tests/test_ucis_interaction_compiler.gd` | 9/9 | `regression-test_ucis_interaction_compiler.log` |
| `tests/ptcgdap/godot/test_ucis_effect_option_shapes.gd` | 7/7 | `regression-test_ucis_effect_option_shapes.log` |
| `tests/ptcgdap/godot/test_a3_external_decision_port.gd` | 19/19 | `regression-test_a3_external_decision_port.log` |
| `tests/ptcgdap/godot/test_competitive_policy_v2.gd` | 19/19 | `regression-test_competitive_policy_v2.log` |
| `tests/test_card_database_seed.gd` | 82/82 | `final-test_card_database_seed.log` |

卡库套件退出时仍输出 ObjectDB 清理警告及 3 个资源仍在使用的提示；进程返回 0，82 项断言通过。本次没有修改该套件的资源清理机制。UCIS 套件包含故意拒绝错误形状的诊断测试，其预期诊断不等于套件失败。

失败到通过证据位于同一日志目录：`red.log`、`behavior-red.log`、`second-red.log` 和 `edge-red.log`。具体复现了缺少注册/资源、比克提尼数量、三首恶龙能量单位、女服务生越界选第 7 张、花疗环环非法治疗目标、小陨星非法目标。卡图格式回归最初失败，转换后 82/82 通过。

真实注册枚举记录为 `final-registration-audit.json`（45 张、未实现 0）；修复前为 `registration-audit.json`（未实现 21）。实际用户目录由 `OS.get_user_data_dir()` 解析，日志有解析结果；逻辑路径为 `user://cards/30thDC_*.json`、`user://cards/images/30thDC/*.png`，数据与 `res://data/bundled_user/` 精确对照。

## 复跑与边界

在项目根目录运行：

```powershell
python scripts/tools/verify_30thdc_bundle.py
python tools/ptcgdap/build_bundled_seed_revision.py --check
& 'D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path . -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_30thdc_cards.gd
```

其他回归使用同一 `FocusedSuiteRunner`，替换 `--suite-script` 为上表路径。验证不需要网络、训练或 Python 进程池。

已达到：源数据一致、逐卡注册、Godot 规则结算、真实 UCIS/Host 当前窗口交互及相关回归。未声称完成 CABT 官方引擎逐局一致性、完整对战策略胜率评测、人工逐卡界面操作或 Android 真机验收。本次没有新增设备运行时 Python 或网络依赖，也没有修改 `ptcgabc` 或私有云工程。

回滚范围：仅删除本次 45 份 `30thDC_*.json`、对应 `images/30thDC/*.png.bin`、两个新增效果/注册文件、此套测试/源夹具/核验脚本/报告，移除 manifest 中本系列的 90 行与 `EffectRegistry.gd` 中本系列的两行调用，然后重建种子内容修订。不要整文件还原共享注册表或清单，以免覆盖其他未提交工作。没有执行提交、推送、发布或回滚。
