# Kaggle v5.23a 厄诡椪／岩殿居蟹 Godot 18.0 迁移与引擎闭环

日期：2026-08-25  
状态：Windows development Host 端到端完成；supporter stage-curve 1.4.0 已内置、可选、可运行并完成同／新 seed 终验  
声明边界：local Godot development evidence；非 official CABT parity、production、Android/A5

## 最终交付

- deck ID：`800052301`，精确 60 卡／19 printing；
- package ID：`dev.beralee.v18.ogerpon-crustle-v523a`；
- current development version：`1.4.0`；
- current archive：`3B4E78A16EB2C238CD9CFB29CA29B8CF44E0D7D99822CA9C1ECD90A2651DFFB8`；
- 内置路径：`data/ptcgdap/author_strategy_packages/ogerpon-crustle-v523a-supporter-r4-1.4.0.ptcgai`；
- runtime：`reviewed_competitive_policy_v2`；
- runner：`scripts/tools/run_ogerpon_author_vs_rule_matrix.tscn`；
- focused suite：`tests/ptcgdap/godot/test_ogerpon_author_vs_rule_matrix.gd`，26/26；
- Forge strict suite：31/31。

Windows development gate 精确固定 R0 `0.1.0`、R1 `0.2.0`、R2 `0.3.0`、R3 `0.4.0`、历史 final `1.0.0`、supporter final `1.3.0` 与 stage-curve `1.4.0` 的 ID/version/archive。`BattleSetup` 回归直接扫描真实 catalog、选择 1.4.0 exact ref，并证明可开战；不是只在 benchmark runner 中旁路加载。1.3.0 保留为直接回滚身份。

## 本地运行

在游戏的 AI 对手选择中切换到作者策略包，选择：

```text
dev.beralee.v18.ogerpon-crustle-v523a / 1.4.0
```

BattleSetup 在开始对局前会再次复验 exact package identity、archive、deck mapping 和 Windows development authority。当前对局不热换包，旧窗口 index 不跨决策保存。

开发矩阵命令：

```powershell
& 'D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe' `
  --headless --quiet --path 'D:\ai\code\PtcgDAP' `
  'res://scripts/tools/run_ogerpon_author_vs_rule_matrix.tscn' -- `
  --games-per-matchup=20 --seed-base=92300 --matchup-offset=1000 `
  --max-steps=700 --package-version=1.4.0 `
  --capture-public-replays `
  --replay-output-root=res://artifacts/deck_training/ogerpon_supporter_1_4_0_fresh_seed92300_replays_after_entity_rebind `
  --output=res://artifacts/deck_training/ogerpon_supporter_1_4_0_fresh_seed92300_20x5_clean_after_entity_rebind.json
```

runner 固定五个 Rule 18.0 deck identity、成对 seed、换座、真实 Host frame preflight、dirty fail-fast、Wilson 区间和每局公开录像。任何 invalid、policy error、fallback、engine rejection、non-terminal、无 winner、无 engine commit 或录像拒绝都会令报告不 clean。

## 历史 1.0.0 最终矩阵

| Rule 对手 | deck ID | final 1.0.0 |
|---|---:|---:|
| 玛俐长毛巨魔 | 800018501 | 17–3（85%） |
| 无碟沙奈朵 | 800017097 | 16–4（80%） |
| 多龙巴鲁托 | 800018499 | 12–8（60%） |
| 猛雷鼓厄诡椪 | 800018509 | 11–9（55%） |
| N 的索罗亚克 | 800018502 | 19–1（95%） |
| 合计 | — | **75–25（75%）** |

验收审计：100/100 terminal、100/100 winner；3995/3995 policy calls 成功；invalid/error/classic fallback/same-window fallback/engine rejection 均为 0。100 份录像全部 accepted，独立复核 artifact SHA-256、match envelope、frame-chain root 和 frame count，差异为 0。

正式证据：

- `artifacts/deck_training/ogerpon_final_1_0_0_20x5_one_shot_clean.json`
- `artifacts/deck_training/ogerpon_final_1_0_0_representatives_one_shot_clean/`

每个对局只有 20 场，结果是策略开发侦察证据，不是统计强度保证。R0 旧 seed 为 73–27；final 使用新 seed，不能把两场差异解释成严格因果提升。

## 支援者专项 1.3.0 发布与终验

玩家录像显示 1.0.0 的部分真实对局在 37 个可见支援者窗口中 0 次选择奇树/裁判。平台持续提供合法 option，且 policy error、invalid、fallback 均为 0；根因属于 adapter：两张支援者错误地以己方手牌 `<=4` 为关键门，同时正向 `end_turn` 分数压制可用动作。

相邻 Forge 完成三轮 data-only 修复：展开债务驱动奇树、公开奖赏时钟落后且对手大手牌时用裁判干扰、删除所有正向结束回合规则并否决危险能量转移。经用户显式授权，exact 1.3.0 bytes 以新文件内置并加入 Windows development gate，没有覆盖 1.0.0。门禁测试先得到 candidate hash 缺失的 16 pass / 1 fail RED，登记后 focused suite 为 17/17 GREEN；真实 catalog、BattleSetup、reviewed policy bind 与 Host setup frame 均通过。

同 seed base `72300` 的版本对照保持 engine/rules/Host/catalog 哈希一致：

| Rule 对手 | 1.0.0 | 1.3.0 |
|---|---:|---:|
| 玛俐长毛巨魔 | 17–3 | 18–2 |
| 无碟沙奈朵 | 16–4 | 15–5 |
| 多龙巴鲁托 | 12–8 | 13–7 |
| 猛雷鼓厄诡椪 | 11–9 | 12–8 |
| N 的索罗亚克 | 19–1 | 19–1 |
| 合计 | **75–25（75%）** | **77–23（77%）** |

独立新 seed base `82300` 的 1.3.0 为 16–4、12–8、15–5、11–9、20–0，合计 **74–26（74%）**。两组 1.3.0 共 151–49（75.5%），`7960/7960` policy calls 成功，invalid/error/classic fallback/same-window fallback/engine rejection 全零。200/200 public replay、18,185 帧经独立冻结 CSP validator 复核 artifact、envelope、frame chain、frame count 与 exact participant identity，差异 0。

为区分“规则命中”和“实际打出”，另以公开录像跟踪候选方支援者 card serial 首次进入弃牌区，并要求同帧满足对应公开卡效形状。1.0.0 同 seed 100 局实际打出裁判 3 次、奇树 7 次；1.3.0 同 seed 为裁判 31 次、奇树 4 次，新 seed 为裁判 19 次、奇树 2 次，两组共裁判 50 次、奇树 6 次，未分类 0。支援者不再被手牌数和正向结束回合规则普遍压制；本轮主要增加的是落后时的裁判干扰路线。

一次 seed `72308` targeted developer-trace 单独重跑在开局前因 `setup_option_missing` 被 Host preflight 拒绝，执行 0 局；该 3,385-byte 诊断报告（SHA `C0FCBF0A5E14982462EB775DBC6411681C09D0A596262CD6DE3796899325F8CD`）未计入胜率或支援者次数。它保留用于证明 fail-closed，实际打出结论来自 200 份 accepted public replay。

新增证据：

- `artifacts/deck_training/ogerpon_supporter_1_3_0_same_seed72300_20x5_clean.json`（SHA `C4DC7CE83F0AA50941B926B68ECBE7354249B50A778A64296237E90ECAEB5173`）与对应 100 份 replay；
- `artifacts/deck_training/ogerpon_supporter_1_3_0_fresh_seed82300_20x5_clean.json`（SHA `430E73134FDCCB724754D2F707187BDAA1CD9CFE2924F64212A8AF71C28CC6BA`）与对应 100 份 replay。

每个 matchup 仍只有 20 局，77% 与 74% 都是开发侦察证据；不能把同 seed +2pp 或 200 局汇总冒充稳定统计优势。

## 支援者阶段曲线 1.4.0 发布与终验

1.3.0 的 200 局公开录像只确认奇树 6 次、裁判 50 次。1.4.0 不再把己方／对方手牌数当作关键硬门：无就绪攻击手且存在能量债务时允许奇树在前中期解卡手；对手进入三奖以内时提高奇树压手价值；裁判只在前六回合、对手至少四奖且我方攻击时钟落后时正向触发，并在对手三奖以内计负分。Forge archive 为 85,056 bytes / `3B4E78A1…DFFB8`，67 score + 6 count rules，31/31 strict 场景与双构建通过。

经用户显式授权，exact 1.4.0 bytes 以新文件内置并登记 Windows development gate，没有覆盖 1.3.0。未登记时 focused 为 17/20，唯一三项失败是 exact gate、BattleSetup 可见性与真实 Host frame；登记后 20/20。随后加入 dirty replay 诊断、实体生命周期回归及共享工作树新增门禁后，当前最终 Ogerpon suite 26/26、serial registry suite 21/21。

冻结运行时、同 seed base `72300`、同席位和同五个 Rule 对手的 package-only A/B 为：

| Rule 对手 | 1.3.0 | 1.4.0 |
|---|---:|---:|
| 玛俐长毛巨魔 | 18–2 | 15–5 |
| 无碟沙奈朵 | 15–5 | 13–7 |
| 多龙巴鲁托 | 13–7 | 13–7 |
| 猛雷鼓厄诡椪 | 12–8 | 13–7 |
| N 的索罗亚克 | 19–1 | 19–1 |
| 合计 | **77–23（77%）** | **73–27（73%）** |

两边公开 replay envelope 的 engine `D78E40E2…CEE6`、runtime manifest `AD66CB3A…9A78`、rules `58AC8F82…74D0`、card catalog `AB8CF104…70D4`、Host contract `B642E704…2262`、evaluation profile、seed 与 seat identity 相同，仅策略包 identity 不同。因此 1.4.0 的同 seed 胜率是 **-4pp**，不能宣称胜率升级。独立 seed base `92300` 的 1.4.0 为 17–3、13–7、15–5、12–8、20–0，合计 **77–23（77%）**；两个 1.4.0 组共 **150–50（75.0%）**，但每 matchup 仍只有 20 局，只是开发侦察证据。

支援者行为达到了本轮目标：同 seed 下，奇树由 4 次升至 29 次，其中 25 次为后期压奖形态、3 次为前中期解卡手；裁判由 31 次变为 29 次，且从 11 次目标前中期／9 次后期／11 次其他，收敛为 29 次全部目标前中期。独立 seed 下奇树 16、裁判 34；两组共奇树 **45**、裁判 **63**，108 个事件全部由候选方支援者 card serial 首次进入弃牌区且同帧满足公开卡效形状确认，未分类 0。两组 8,336/8,336 policy calls 成功，invalid/error/classic fallback/same-window fallback/engine rejection 全零；200/200 replay、18,740 帧逐文件校验差异 0。

首次运行 seed `92300` 在对手 `800018509` 的 game 17 / exact seed `95308` 暴露 `pokemon_entity_projection_failed`，该 96-replay 脏批次完全排除。精确复现证明策略此前 14/14 次选择成功，owning layer 是 Host：引擎换前台时复用 `PokemonSlot` 容器，但实体注册表把旧根身份永久绑定到容器。修复只允许“旧实体已退休且公开根卡已变化”时签发更大的新实体序号；同根退休引用仍禁止复用。registry RED 20/21→GREEN 21/21；exact seed 成对复跑 2/2 terminal、58/58 calls、2 replay / 146 帧零差异，随后从新目录完整重跑 100 局通过。

核心证据：

- `artifacts/deck_training/ogerpon_supporter_1_4_0_same_seed72300_20x5_clean_runtime_f8fe.json`（SHA `3D3B098AA59D766D2F3466773D6FB01C1C3D4DC35251870C34AD415581437D85`）及 audit `999B191F…C7F5`；
- `artifacts/deck_training/ogerpon_supporter_1_3_0_same_seed72300_20x5_clean_runtime_f8fe.json`（SHA `7F19D640AC6E9310429B8619165EAB3AF7CAE3A237D7CBA64D43BEE43A7AED2C`）及 audit `4BA4F9DE…0355`；
- `artifacts/deck_training/ogerpon_supporter_1_4_0_fresh_seed92300_20x5_clean_after_entity_rebind.json`（SHA `8B66B96184A5CBBCAD3C29C2802D11CB1B53E7F17427690BFEA3CEA7DAF31959`）及 audit `67353090…E7E9`；
- `evidence/ptcgdap/ogerpon_supporter_stage_curve_r4_v1.json`。

结论分开记录：支援者阶段行为问题已关闭；同 seed 胜率门未提升。1.4.0 保持 Windows development 发布版本供继续观察，1.3.0 是明确回滚版本；不把 1.4.0 冒充竞技优胜、production 或 official CABT parity。

## 三轮策略变化

- R1：移除石居蟹 Ascension 对场上厄诡椪的错误依赖；同 seed 4×5 从 12/20 到 13/20。
- R2：能量转移只在岩殿居蟹有债务且存在安全 donor 时使用；source 选过量充能、ready 的厄诡椪，target 选岩殿居蟹。真实 trace 证明 `2/28/5 -> 1/22/3` 两个 fresh UCIS 窗口。
- R3：牌库 `<=4` 时停止 Teal Dance。固定失败种子不再做错误动作，但只把 deck-out 从 step 160 延迟到 161，没有冒充翻胜。

详细策略与场景记录位于相邻 Forge：`docs/16-OGERPON-GODOT-ADAPTATION-FINDINGS.md`。

## 本轮关闭的引擎 Block

1. competitive-v2 Host frame 与 exact validator schema 漂移；
2. public replay 无法绑定异构 Rule deck identity；
3. `send_out` frontier 暴露 effectively-KO Bench；
4. UCIS Trainer 诊断缺 source/effect，Brock bool mode 不标准；
5. Phantom Dive/伤害分配未统一 effective HP；
6. assignment target 丢失 originating effect identity；
7. assignment source 未暴露当前附着卡 owner 的公开能量/ready/debt；
8. Energy Switch source/target wire 不标准；
9. Forge 超过 64 条 rule 时跳过 IR preflight，而 Godot 正确拒绝；
10. Headless bridge 从历史 MULLIGAN 日志猜测 pending prompt，双方同步 mulligan 后制造幽灵窗口。

最后一项由 `GameStateMachine.get_pending_decision_snapshot()` 提供 durable one-shot authority，bridge 不再从 action log 推断；合法数量提交后重复调用被拒，非法输出不消费窗口。首次 final 运行在 72 局后 dirty fail-fast；三个固定种子修复后各 2/2 clean，再从空目录完整重跑 100 局。one-shot 收紧后又从第二个空目录重跑同一 100 局，结果仍为 75–25、3995/3995 且录像 100/100，无任何部分结果拼接。

## 回滚与非声明

回滚只影响新对局：从 1.4.0 切回 exact 1.3.0 / `B813433007BCC1A516376D2C95E4911999B4B4B5A804BD5EE1329799280C40CA`；当前 match 不热换，也不删除 1.4.0 及其失败／成功证据。1.0.0 / `9531F683…8D9F` 继续保留为更早历史身份。相关 Host/UCIS 修复若漂移，真实 frame、实体换根、KO frontier、Energy Switch、double-mulligan 与 replay/hash tests 会 fail closed。

本任务没有证明 official numeric card ID equality、官方 RNG、整场规则 parity、production signing、社区审核、Android/A5 或 clean-install device acceptance。Godot 退出期仍有既有 ObjectDB/resource leak 警告；本轮相关 runner exit code 与 test verdict 均为成功，资源生命周期清理保留为独立后续。
