# 18.0 阿响的火暴兽对玛俐礼盒十轮 Godot 开发验收

日期：2026-08-28

## 精确身份

- 候选卡组：Godot `800018880` / Limitless 18880，60 张、26 printing。
- 对手：`dev.bodao-yongzhe.marnies-gift-box@1.8.0`，SHA-256 `209FA7EDF7321A142F1B8A25E44667D44E49AF728E799AFF112716951E72DFD1`。
- 冻结冠军：`dev.bodao-yongzhe.ethans-typhlosion@0.6.0`，SHA-256 `26AD9CCCB2EA848AEA0D1A8D38DFDA0BE544E341D91A1E863654A4A28921F1FD`，95,783 bytes。
- 回滚基线：`0.1.0`，SHA-256 `FDECBD7FE2C2F2DA9D890150E166498AE2F607BCDC19F393C16873DB2346B0EA`。

## 十轮固定 A/B

所有轮次使用 seed base `188100`、10 个配对 seed、候选轮换两个座位、每轮 20 局、最大 700 步，并保存 developer decision trace 与 public replay。胜场序列为：

`R0 5, R1 6, R2 6, R3 7, R4 7, R5 8, R6 8, R7 7, R8 8, R9 8, R10 8`。

R5 是最早达到最高 8/20 的候选，固定调优集相对 R0 从 25% 到 40%，绝对提升 15 个百分点。R7 回退被拒；R6/R8/R9/R10 因同分未替代更小的 R5。R10 的神奇糖果直升火暴兽规则命中 5 个窗口，但逐局胜负与 R5 完全一致。

## 独立新种子验收

- seed base：`288100`
- 结果：28/100（28%），Wilson 95%：20.14%–37.49%
- 座位拆分：seat 0 为 16/50；seat 1 为 12/50
- 100/100 正常终局，100/100 public replay 接受
- 双方 policy calls：10,657；success：10,657
- policy error / invalid output / classic fallback / same-window fallback / engine rejection：全部 0

固定集的 40% 只用于十轮相对 A/B；独立集的 28% 是 R5 的泛化估计，未在该组种子上与 R0 做配对，因此不能反推 R5 对 R0 的独立集提升。

## Godot 见证

`test_ethans_typhlosion_author_package.gd` focused 5/5：

- exact R0/R10 identity 放行且 SHA 漂移拒绝；
- 包内 60/26 牌组物化并绑定 reviewed owner；
- 冻结 R5 在 BattleSetup 显示“已加载 · 可开战”，可精确选择且 `_apply_setup_selection()` 成功；
- author-vs-author CLI 精确固定候选与玛俐礼盒 1.8.0。

迭代报告：`artifacts/deck_training/ethans_typhlosion_r0_vs_marnie_20g.json` 至 `ethans_typhlosion_r10_vs_marnie_20g.json`。独立报告：`artifacts/deck_training/ethans_typhlosion_r5_final_vs_marnie_fresh_100g.json`。

## 声明边界

这是 Windows 本地、test-fixture 签名下的开发包和 Godot 引擎见证。它不构成 production approval、设备发布、官方 CABT 整场规则 parity、Android/A5 或统计显著强度声明。runner 的历史 `document_type` 仍名为 `marnie_gift_box_vs_ogerpon_author_benchmark_v1`，但报告内 candidate/opponent 的 package/deck/version/SHA 均为本次精确身份；该命名漂移是已知非行为缺口。
