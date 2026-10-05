# Android 战斗输入穿透与卡牌动画错位修复

日期：2026-09-26。状态：源码修复及 Godot 场景回归通过，未提交、推送或发布。

## 复现与根因

使用真实 `BattleScene.tscn`、规则状态、原生 Android 输入配置、Viewport 事件分发和真实 Tween 构造回归，复现了以下问题。没有用户原局录像，因此不宣称重放了用户的具体对局。

| 问题 | 原因 | 修复后的行为 |
| --- | --- | --- |
| 拿奖后误开 LOST | 规则提交同步关闭弹层，随后到达的兼容鼠标事件命中底层；手牌重建还会清除已经归属弹层的输入序列 | 提交前认领本次指针序列，手牌刷新保留其归属，同一次触摸只产生一次操作 |
| 部分原生触摸仍穿透 | GUI 回调收到的是局部坐标副本；release 在 GUI 回调前已由 `_input` 标记完成；同步 UI 耗时可能超过兼容事件识别窗口 | GUI 回调绑定本次原始分发，允许当前帧的 release 完成认领，并扣除本次同步分发耗时；没有增加全局点击冷却 |
| 竖屏中隐藏的 HUD 点击区域 | 命中检测同时接受旋转前、旋转后两套位置 | 只按真实控件变换转换一次坐标，并检查可见性与裁剪 |
| 抽卡确认触发底层 LOST / 弃牌区 | 抽卡覆盖层未登记为场上模态层，直接 HUD 回调缺少同等隔离 | 抽卡覆盖层登记为模态层，HUD 入口同时检查覆盖层及动画状态 |
| 排队动画显示别的牌或漏牌 | 动画延迟播放时重新从当前牌区查找卡牌，并共享可变动作数据 | 在动作入队时复制数据，按实例 ID 捕获当次卡牌及顺序；后续牌区变化不改变已入队的展示 |
| 恢复后旧翻牌覆盖新牌 | 看门狗结束展示后，旧 Tween 仍能回写已经复用的奖赏槽 | 恢复时停止旧 Tween，回调校验展示代次；抽卡恢复也清空旧队列、视图与 Tween |
| 奖赏还在翻牌时底层可操作 | 清理最后一个规则提示时提前清除了展示锁 | 保持翻牌期间的操作锁，完成或恢复后释放 |
| 系统取消触摸仍选择卡牌 | 卡牌、奖赏、HUD 及语义手势将 canceled 当成正常抬手 | 取消只清理对应手势，不确认、不点击 |
| 动画中途退出后仍持有回调 | 新增的 Tween 所有权需要纳入场景既有资源清理 | 场景退出显式停止抽卡和奖赏动画，断开持有关系，不在清理阶段重新推进对局 |

卡图加载路径也已检查：`BattleCardView` 根据具体图片路径同步加载并缓存，没有发现本次需要修改的异步卡图回写路径。抽牌规则、牌库顺序和卡效没有修改。

展示快照仅保存在展示专用的动作副本 metadata 中；原始 `GameAction.data`、引擎日志和公开策略输入不加入卡牌对象引用。奖赏交换动画继续遵守既有背面展示规则。

## 验证

新增自动发现套件 `tests/test_battle_presentation_isolation.gd`，最终为 20 项测试，覆盖：

- 真实竖屏场景的 touch-first / mouse-first 事件顺序，包含未标记的原生兼容鼠标事件；领取一张奖赏、兼容事件不打开 LOST、独立的下一次点击立即有效。
- 抽卡确认、直接 LOST / 弃牌入口、手牌重建期间的输入归属、多指清理、当前分发与过期 release 的边界。
- 实际引擎连续抽三张牌，含同名但不同实例的卡牌；展示顺序和落入手牌后的实例顺序一致，原始日志不被展示引用污染。
- 排队期间卡牌离开手牌、原始动作数据变化、强制完成后旧动画不再回写、奖赏槽复用、翻牌操作锁。
- 原生触摸取消、旋转 HUD 的真实命中区域，以及中途退出后动画控制器弱引用释放。

既有 `BattleUIFeaturesPart2` 中两项“旋转前幽灵区域也应命中”的断言改为不命中；保留了实际旋转位置、viewport 拉伸、原生输入及鼠标先到的既有断言。

修复前的真实失败记录保存在本地 `.godot_test_user/`：

| 运行目录 | 已复现的失败 |
| --- | --- |
| `presentation_isolation_red` | 取消触摸误拿奖、确认尾事件穿透、过期队列重启、排队显示第一张而非第二张、幽灵命中区域 |
| `presentation_isolation_red_hud` | 补齐测试夹具后，确认抽卡层下的 LOST / 弃牌入口仍可打开 |
| `presentation_isolation_android_red` | 原生配置下手牌刷新抹掉拿奖与抽卡确认的序列归属 |
| `presentation_animation_red` | 恢复后槽位应为 Replacement prize，却被旧回调改为 Prize A；旧完成回调仍执行 |
| `presentation_prize_lock_red` | 翻牌尚未完成时展示锁已清除、背景操作仍被接受 |
| `presentation_scene_exit_red2` | 退出战斗后动画控制器弱引用仍存活 |

早期夹具缺少弃牌标题的异常、退出测试首轮的类型推断编译错误不作为产品缺陷证据。

| 验证阶段 | 结果 | 本地报告 |
| --- | --- | --- |
| 输入与动画修复后的完整相关回归，退出清理补充前 | 19 套件，637 通过，0 失败，0 跳过 | `.godot_test_user/presentation_regression_final/report.json` |
| 最终源码复核：PresentationIsolation、SceneLifecycle、SwitchingTicketAnimation、EffectsSetting | 4 套件，33 通过，0 失败，0 跳过；含全部 20 项新增专项 | `.godot_test_user/presentation_final_lifecycle/report.json` |
| 本次改动差异与回退可用性 | `git diff --check`、反向补丁 `--check` 通过 | `.tmp/battle_presentation_baseline_20260926/` |

上述两阶段包含重复用例，不应把 637 与 33 相加宣称独立用例总数。每个套件串行运行，使用独立进程及用户数据目录。运行环境为 Godot 4.6.1 Windows headless；Android 输入配置和真实场景分发由测试设置。当前 adb 无连接设备，未执行本次安卓真机或模拟器运行，也未生成或安装更新 APK。

各阶段通过断言、报告及脚本错误门禁。部分 UI 套件退出时仍有 Godot ObjectDB / 纹理 RID / 资源未释放告警，包括最终专项；新增的动画控制器释放断言已通过，不将这些退出告警描述为已全部消除。

完整相关回归命令：

```powershell
python scripts/tools/run_test_matrix.py --suite BattlePresentationIsolation,BattlePointerInputRouter,BattlePointerSurfaceController,BattleHandSurfaceReconciliation,IosWebHudTouchAdapter,BattleModalEndTurnInputIsolation,BattleDisplayController,BattleDisplayCoordinator,BattleEffectsSetting,SwitchingTicketAnimation,BattleVisualAnimationPlans,AndroidPortraitEnergyInteractionRegressions,BattleUIFeatures,BattleUIFeaturesPart2,BattleUIFeaturesPart3,BattleUIFeaturesPart4,BattleUIFeaturesPart5,BattlePortraitLayout,AiSelfKnockoutPrizeDialog --timeout 300 --output .godot_test_user/presentation_regression_recheck
```

最终补充复核命令：

```powershell
python scripts/tools/run_test_matrix.py --suite BattlePresentationIsolation,BattleSceneLifecycle,SwitchingTicketAnimation,BattleEffectsSetting --output .godot_test_user/presentation_lifecycle_recheck
```

## 范围与回退

本次达到 Godot 展示与输入场景级自动回归，不新增 CABT 接口、跨运行时一致性、引擎一致性或策略胜率声明。未修改外部 oracle 或私有云服务；保留工作区原有改动。

本地 `.tmp/battle_presentation_baseline_20260926/task_changes.patch` 只包含本次 13 个代码/测试文件的差异，基于开始修复时的工作区版本生成；`task_manifest.json` 记录前后 SHA-256。反向补丁预检已通过。需要回退时先重新检查上下文，只反向应用本次补丁，不恢复整个文件到 HEAD，以免覆盖此前未提交的修改。

```powershell
git apply --reverse --check --ignore-space-change .tmp/battle_presentation_baseline_20260926/task_changes.patch
# 确认本次差异仍匹配后，再反向应用同一补丁。
```

机器可读证据：[android_battle_input_animation_20260926.json](../../../evidence/ptcgdap/android_battle_input_animation_20260926.json)。本地详细日志与补丁不作为发布产物。
