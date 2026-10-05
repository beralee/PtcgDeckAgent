# Android 自爆后领奖界面不可见：复现与修复

日期：2026-09-21。状态：源码修复、功能回归及 Android 模拟器触摸验收通过；未发布手机更新。

## 结论

已复现与用户截图一致的停顿表现：AI 的彷徨夜灵自爆后，日志停留在“玩家2的 彷徨夜灵 昏厥”，玩家奖赏区亮黄，但选择奖赏卡的窗口不可见。

根因是共享对话框残留 `modulate.a = 0`。游戏正确进入了玩家领奖状态；领奖窗口已打开，但整体透明，无法让玩家看见需要点击的牌。

这次修复属于 Godot 领奖界面，不能据此判断开发者策略的整体强度。没有用户这局的完整录像、随机种子及安装版本，因此验收使用构造局面复现相同链路，不宣称重放了原对局。

## 根因与最小改动

1. `BattleDialogController.show_dialog()` 为等待布局，先把共用对话框透明度设为 0。
2. AI 自动处理检索选择时，`BattleEffectInteractionController.hide_ai_owned_effect_step_ui()` 隐藏对话框。
3. 下一帧 `_flush_pending_dialog_reveals()` 跳过已经隐藏的窗口，透明度继续为 0。
4. AI 自爆导致真人拿奖赏。竖屏领奖直接复用该窗口，原来只设置 `visible = true`，没有恢复透明度。

在 `scenes/battle/runtime/BattleSceneSharedHudAiRuntime.gd` 的 `_prepare_dialog_overlay_for_prize_selection()` 中增加 `dialog_overlay.modulate = Color.WHITE`，由领奖入口恢复自身显示状态。未改卡牌规则、AI 策略或奖赏数量。

## 回归证据

新增 `tests/test_ai_self_knockout_prize_dialog.gd`，通过实际卡牌 JSON、效果注册、BattleScene 交互入口、AI 选择和触摸输入验证：

- 彷徨夜灵 `CSV8C_082`：实际注册 `AbilitySelfKnockoutDamageCounters`，放置 50 点伤害并自爆，真人领取一张奖赏后回到同一个 AI 主阶段。
- 黑夜魔灵 `CSV8C_083`：相同链路，放置 130 点伤害。
- AI 先实际使用巢穴球 `CSVH1C_043` 完成检索，再使用彷徨夜灵自爆，领奖窗口必须不透明。

彷徨夜灵规则参考：[宝可梦官方卡牌页](https://asia.pokemon-card.com/hk-en/card-search/detail/13741/)。测试直接加载仓库内具体印刷版本，周围普通宝可梦、牌库和奖赏采用最小夹具。

修复前，第三项失败：`Prize dialog must not inherit the transparent AI dialog | 期望 1.0，实际 0.0`。修复后三项全部通过，并确认标准功能测试目录能自动发现该套件。

| 套件 | 结果 |
| --- | --- |
| AISelfKnockoutPrizeDialog | 3/3 |
| Battle UI Features Part 4 | 99/99 |
| Battle UI Handover Regression | 17/17 |
| Battle Dialog Controller | 32/32 |
| 合计（不重复计数） | 151/151 |

两个既有 UI 大套件退出时报告 ObjectDB/资源未释放警告；测试断言通过。新增专项及对话框套件没有脚本错误。修复前的隔离诊断运行也有退出资源告警，不影响已捕获的透明度断言失败。

复跑专项：

```powershell
.\scripts\tools\run_godot_tests.ps1 -Runner functional -Suite AISelfKnockoutPrizeDialog -UserDataRoot .godot_test_user/self_ko_check
```

其他三组使用 `-Runner focused -SuiteScript res://tests/<脚本名>`，脚本分别为 `test_battle_ui_features_part4.gd`、`test_battle_ui_handover_regression.gd`、`test_battle_dialog_controller.gd`。

## Android 实机运行路径验收（模拟器）

环境：Godot 4.6.1、Android 模拟器 `Medium_Phone_API_36.1`、x86_64、1080×2400、独立只读实例 `emulator-5556`，宿主 GPU / OpenGL Compatibility。测试结束已关闭只读实例。

诊断入口 `tests/probe_self_knockout_prize_scene.gd` 仅在隔离源码快照中临时注册为 autoload，未加入正式 `project.godot`。它加载实际 BattleScene 和实际彷徨夜灵效果，通过 AI 执行自爆；前置的 AI 窗口隐藏状态由真实窗口 API 构造。完整的“巢穴球检索”前置流程由上述桌面回归覆盖。诊断 APK 不是可分发的游戏更新包。

| 观测 | 修复前 | 修复后，点击前 | 修复后，点击后 |
| --- | --- | --- | --- |
| 领奖窗口 visible | true | true | false |
| 领奖窗口 opacity | 0 | 1 | 1 |
| 待领数量 | 1 | 1 | 0 |
| 玩家剩余奖赏 | 6 | 6 | 5 |
| pending choice | take_prize | take_prize | 空 |
| 回合 / 当前玩家 | T10 / AI | T10 / AI | T11 / 玩家 |
| 玩家手牌 | 0 | 0 | 2（奖赏 1 + 新回合抽牌 1） |

使用 Android `input tap 292 1040` 实际点击可见的第一张奖赏卡，随后确认窗口关闭、领奖待处理状态清空、AI 完成本回合并轮到玩家。

宿主 GPU 的验收运行未出现 Godot `ERROR:`、`SCRIPT ERROR` 或解析错误；存在一次 shader 缓存失效后重编译警告。早期 SwiftShader 尝试有 Vulkan 崩溃 / GLES uniform 上限导致的灰屏，这些运行不作为视觉验收证据，未因此改动产品渲染设置。

本地截图：

- [修复前：自爆后窗口不可见](../../../.tmp/android-self-ko-20260921/self-ko-red-host.png)
- [修复后：可见奖赏卡窗口](../../../.tmp/android-self-ko-20260921/self-ko-green-host.png)
- [触摸领奖后：第 11 回合继续](../../../.tmp/android-self-ko-20260921/self-ko-green-resumed.png)

机器可读记录：[验收结果](../../../evidence/ptcgdap/android_self_ko_prize_dialog_20260921.json)。详细日志、构建脚本、隔离快照及诊断 APK 留在 `.tmp/android-self-ko-20260921/`。

## 边界与回退

本次达到真实卡牌效果 → AI 交互 → 真人领奖 → Android 触摸继续游戏的验收范围。未重跑策略胜率评测，也不新增 CABT 官方引擎一致性声明。尚未在用户原手机安装修复版本。

若需要回退，仅撤销领奖入口新增的 `modulate = Color.WHITE` 及其注释；这会重新暴露本报告的透明窗口问题。未提交、推送或发布，没有修改相邻 oracle 或私有云服务。
