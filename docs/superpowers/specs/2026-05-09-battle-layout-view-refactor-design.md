# 对战横竖屏布局视图重构设计

## 背景

当前对战区横屏和竖屏共用 `BattleScene.tscn`，竖屏由 `BattleScene.gd` 在运行时动态折叠侧栏、移动 HUD、调整手牌区和备战区。这个方案复用了节点和交互逻辑，但也让 `BattleScene.gd` 同时承担了战斗流程、规则交互、状态同步、布局计算、横竖屏差异处理等职责。

问题集中在两点：

- 竖屏改动容易影响横屏，因为大量 `_portrait_*` 方法直接操作横屏节点。
- 布局代码和功能代码交织，后续做手机专项优化时，很难判断一个改动属于 UI 摆放还是对战逻辑。

目标不是立即复制一整套战斗场景，而是先建立清晰边界：横屏布局和竖屏布局有各自的布局视图对象，功能层继续共用同一套对战状态、卡牌视图、交互控制器和弹窗控制器。

## 设计目标

1. `BattleScene` 不再直接决定横竖屏布局细节，只负责接线、状态刷新和用户意图处理。
2. 横屏和竖屏拥有独立布局入口，后续可以分别演进，不互相塞特殊分支。
3. 现阶段不重写卡牌效果、AI、选卡弹窗、卡牌详情、日志、结算等功能层。
4. 保持现有测试兼容，外部仍可通过 `_apply_portrait_layout()`、`_apply_landscape_layout()` 做回归测试。
5. 新结构要支持渐进迁移，先做适配器，再逐步把节点摆放代码从 `BattleScene.gd` 移出。

## 架构

### BattleScene

仍然是对战根场景，负责：

- 创建和持有 `GameStateMachine`、AI、回放、记录、弹窗、展示控制器。
- 接收按钮、卡牌、区域点击等用户输入。
- 把输入转成规则层可处理的动作。
- 调用布局协调器应用当前布局。

`BattleScene` 不应该新增横竖屏差异判断。保留的旧方法只作为兼容包装或第一阶段适配器入口。

### BattleLayoutCoordinator

新增布局协调器，负责：

- 根据视口尺寸、用户偏好和移动端标记解析当前布局模式。
- 处理强制竖屏但运行时仍是横屏时的 canvas 旋转。
- 选择 `BattleLandscapeLayoutView` 或 `BattlePortraitLayoutView`。
- 将视口、逻辑尺寸、内容安全区域等上下文传给布局视图。

它不处理规则状态，不刷新手牌，不决定能否攻击。

### BattleLayoutView

新增布局视图基类，定义布局对象的最小接口：

- `setup(scene, metrics_controller)`
- `mode()`
- `apply(context)`
- `exit()`

布局视图只做 UI 布局，不直接修改游戏状态。

### BattleLandscapeLayoutView

横屏布局视图。第一阶段作为适配器调用 `BattleScene._apply_landscape_layout_impl()`。

后续迁移目标：

- 主区域三栏宽度。
- 横屏 HUD 尺寸。
- 横屏弃牌/选卡/详情弹窗尺寸。
- 横屏手牌区和日志区尺寸。

### BattlePortraitLayoutView

竖屏布局视图。第一阶段作为适配器调用 `BattleScene._apply_portrait_layout_impl()`，并通过 `BattleScene._set_portrait_layout_frame()` 注入竖屏内容区域。

后续迁移目标：

- 竖屏顶部栏。
- 竖屏浮动 HUD rail。
- 竖屏备战区 grid。
- 竖屏更多操作抽屉。
- 竖屏奖励卡选择嵌入逻辑。

## 数据流

1. `BattleScene._apply_responsive_layout()` 取得物理视口。
2. `BattleLayoutCoordinator.apply()` 解析布局模式。
3. 协调器计算逻辑视口和竖屏内容区域。
4. 协调器调用对应布局视图。
5. 布局视图只应用 UI 摆放。
6. `BattleScene` 在布局完成后继续根据当前状态刷新手牌、对话框和 HUD。

## 第一阶段落地范围

本次实现只做结构切分，不改变现有视觉效果：

- 新增 `BattleLayoutView.gd`
- 新增 `BattleLandscapeLayoutView.gd`
- 新增 `BattlePortraitLayoutView.gd`
- 新增 `BattleLayoutCoordinator.gd`
- `BattleScene.gd` 接入协调器
- 原 `_apply_landscape_layout()` 和 `_apply_portrait_layout()` 保留为兼容包装
- 原具体布局代码重命名为 `_apply_landscape_layout_impl()` 和 `_apply_portrait_layout_impl()`
- 增加测试覆盖布局协调器和视图分派

## 后续迁移计划

1. 将横屏 `_apply_landscape_layout_impl()` 内部节点查找和尺寸设置迁入 `BattleLandscapeLayoutView`。
2. 将竖屏顶部栏、手牌区、备战区 grid 迁入 `BattlePortraitLayoutView`。
3. 将竖屏 HUD rail 的节点移动逻辑迁入 `BattlePortraitLayoutView`。
4. 将奖赏卡选择的竖屏嵌入逻辑独立成可复用的 `BattlePrizeLayoutPresenter`。
5. `BattleScene.gd` 只保留状态查询方法和动作派发方法。

## 风险控制

- 第一阶段不创建第二套场景，避免破坏现有节点路径和测试。
- 保留旧方法名，避免已有测试和控制器直接调用失败。
- 布局视图通过 `scene.call()` 适配旧实现，等测试稳定后再逐步搬迁具体代码。
- 聚焦运行 `test_battle_portrait_layout.gd`、`test_battle_ui_features.gd`、`test_script_load_regressions.gd`。
