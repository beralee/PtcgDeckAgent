# 赤松与同类候选窗口复核 — 2026-09-08

复核对象为当前未提交工作区。未加载 skill，未提交、推送或发布；未修改外部 oracle、私有服务或策略包。

## 结论和变更

赤松原报告的物理 ENERGY 候选缺少 `energy_type_raw` 问题已经在当前源码修复。草、雷、斗分别为 1、4、6，完整 0–11 映射及未知能量拒绝测试通过，Competitive/A3 validator 保持原约束。

新增真实 `CSV9C_196` 双座次集成场景，通过 Host 的 `_pick_interaction_items`、`_pick_interaction_target_index` 与 A3 submit/rebind 完成入手来源、附能来源和目标三个窗口。每席位三次成功选择、零 policy error / invalid output / fallback / engine rejection；卡效随后执行并验证实际入手和附着为不同属性。对 A3 帧去除该入口特有的位置、剩余费用字段后，等价 Competitive 公开帧通过完整 `_frame_error`。A3 等待与提交是两次调用，不将它们的调用总数冒充正式策略资格指标。

本轮另发现并修复两处问题：

1. `AttackChosenDefenderAttackLockNextTurn.gd` 用招式名字符串构造候选，真实黑暗鸦场景返回 `unsupported_interaction_shape`。现在使用当前防守宝可梦与招式序号的类型化 ATTACK 候选，非法目标/索引不会默认封锁第一招；旧名称上下文仍兼容。
2. `_energy_type_from_card` 将来源宝可梦的属性当作能量属性。失败场景为恶属性宝可梦附着草能量，却投影为 7；修复后为 1，移除能量后保持 null。函数现在只从能量卡读取能量字段。

## 可复现验证

在仓库根目录串行运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tools/run_godot_tests.ps1 -Runner focused -SuiteScript <下表 suite> [过滤参数]
```

日志位于 `.godot_test_user/logs/`。本轮最终测试结果：

| Suite（res:// 前缀） | 过滤参数 | 结果 | 日志 |
|---|---|---|---|
| tests/ptcgdap/godot/test_a3_external_decision_port.gd | 无 | 19/19 | focused-20260908-033051.log |
| tests/ptcgdap/godot/test_ucis_effect_option_shapes.gd | 无 | 7/7 | focused-20260908-033127.log |
| tests/ptcgdap/godot/test_competitive_policy_v2.gd | 无 | 19/19 | focused-20260908-033208.log |
| tests/test_csv9c_trainer_stadium_energy_effects.gd | 无 | 44/44 | focused-20260908-032551.log |
| tests/test_csv10c_131_135.gd | 无 | 6/6 | focused-20260908-033011.log |
| tests/test_limitless_naic2025_effects.gd | --test=crispin | 1/1 | focused-20260908-033132.log |
| tests/test_battle_ui_features_part2.gd | --test=portrait_crispin | 1/1 | focused-20260908-033137.log |

合计 97/97；所有以上进程退出码为 0。`git diff --check` 通过。部分进程有启动 Unicode 警告和退出资源泄漏诊断，未据此宣称资源生命周期验收通过。

RED 证据：`focused-20260908-032732.log`（能量属性 1 vs 7）；`focused-20260908-032804.log`（黑暗鸦 unsupported_interaction_shape）。

## 验证边界与回滚

这是本地 Host、公开帧和卡效集成验证，不是完整作者包双座次资格、官方引擎对齐、正式发布或 Android/A5 证据。没有重新运行或修改 `dev.z.raging-bolt-forge`。旧状态文档引用的 0.1.1 完整对局，只能说明该包当时干净结束；用户报告指出该版本隔离了赤松，因此不能以此代替实际使用赤松的资格测试。

回滚本轮运行时代码只需恢复攻击封锁效果文件，以及移除能量卡类型检查和对应新增回归。保留开始复核前已经存在的赤松候选卡解析、其他卡效和文档修改。未改动 validator、策略包、BattleScene 或 UI 代码。
