# 浏览器 Pointer Surface UI 重构

日期：2026-07-29
状态：已实施并完成 UI 验收

## 1. 背景与根因

当前浏览器对战 UI 的问题不是单个点击阈值错误，而是输入会话与动态
Control 生命周期不一致：

- `BattleDisplayController.refresh_ui()` 每次都会刷新手牌。
- `refresh_hand()` 会销毁整排 `BattleCardView` 并重新连接信号。
- 拖拽、点击抑制、Touch/Mouse 回声和 pointer owner 却保存在长生命周期对象中。
- iOS Web 有重建前清理和更大触摸容差，Chromium Touch 没有等价生命周期。
- 对战页同时使用 `WebInputAdapter` 和 `BattlePointerInputRouter` 识别同一个物理指针。
- `BattleCardView` 和 `BattleDragScrollCoordinator` 都会在 press 阶段建立自己的状态。

因此，只要浏览器在出牌、弹窗关闭或回合交接时没有交付对应 release，旧状态就可能
跨过手牌节点换代。下一次 press 被旧拖拽所有权消费，新卡只收到 release，表现为
“开局正常，几回合后卡牌越来越难点”。

## 2. 不可破坏契约

本次只重构 UI 输入与展示层：

- 不修改 `GameState`、规则校验、卡牌效果和 AI 行为。
- 手牌点击仍进入现有 `_show_hand_card_detail(CardInstance)`。
- 卡牌详情、使用、取消、选择 HUD 的业务 signal 和 callback 保持不变。
- Windows 鼠标与 Native Android 的既有 GUI 输入继续可用。
- 弹窗优先级高于手牌，手牌优先级高于棋盘兜底命中。
- 一次物理手势最多提交一个业务动作。
- pointer cancel、页面失焦、surface 换代后不能补交旧动作。

## 3. 目标架构

```text
Browser / Godot raw event
             |
             v
BattlePointerInputRouter
  - 唯一 PointerSequence
  - Touch/Mouse echo 归并
  - owner / intent
             |
             v
BattlePointerSurfaceController
  - surface generation
  - PendingTap / Scrolling / Cancelled
  - stable semantic target key
             |
       +-----+------+
       |            |
       v            v
 Hand surface    Card gallery surface
       |            |
       v            v
 existing semantic callbacks/signals
```

`WebInputAdapter` 继续服务非战斗页面，但不再作为对战页的第二份 pointer sequence
真相源。

## 4. Pointer Surface 协议

每个动态可交互区域注册：

- `surface_id`
- `generation`
- `root` 与 `ScrollContainer`
- `hit_test(position) -> semantic_target_key`
- `activate(target_key, generation)`
- 横向滚动能力与物理触摸阈值

每条活动手势记录：

- `sequence_id`
- `pointer_id`
- `surface_id`
- `surface_generation`
- `target_key`
- `press_position`
- `latest_position`
- `start_scroll`
- `state`

状态机：

```text
Idle
  -> PendingTap
       -> TapCommitted
       -> Scrolling
       -> Cancelled
```

规则：

1. press 只建立 `PendingTap`，不立即认定为拖拽。
2. 只有内容真实横向溢出、横向运动占主导并超过阈值时，才能进入 `Scrolling`。
3. release 必须属于同一 sequence、同一 surface generation。
4. tap 使用稳定业务 key（手牌为 `CardInstance.instance_id`），不持有旧 Node 作为真相。
5. generation 变化会同步取消该 surface 的所有活动手势。
6. orphan release、echo、cancel 都不得提交 tap。

## 5. 手牌展示对账

手牌从“清空并重建”改为 keyed reconciliation：

1. 生成当前可见手牌的有序 `instance_id` 列表。
2. 复用相同 `instance_id` 的 `BattleCardView`。
3. 只创建新抽到的卡，只释放已经离开手牌的卡。
4. 使用 `move_child` 同步顺序。
5. 选择状态、标题和副标题作为属性更新，不触发节点换代。
6. 等待对手回合与可操作手牌之间的模式变化视为 generation 变化。

手牌 signature：

```text
mode | ordered visible instance ids
```

signature 不变时，普通 `_refresh_ui()` 不增加 generation，也不取消有效 press。

## 6. 布局与滚动

- 滚动范围每次从当前子节点重新计算，不读取旧 `content.size.x` 作为新的最小宽度。
- 内容不溢出时强制 `scroll_horizontal = 0`。
- 内容缩小时把 scroll clamp 到新范围。
- 点击阈值使用 touch profile，而不是 `web_ios` 特判。
- 滚动条仍可见/可拖动的 HUD 保留原生 scrollbar 行为；surface controller 只处理内容区手势。

## 7. 迁移编排

### Phase A：测试与诊断

- Pointer router 增加 active snapshot 与 surface owner 断言。
- 新增纯状态机测试：丢 release、换代、echo、轻微抖动、真实拖动。
- 新增 keyed hand reconciliation 测试。

### Phase B：唯一 pointer source

- 对战 `_input` 只调用 `BattlePointerInputRouter.observe()`。
- Web echo/orphan 判断使用同一个 observation。
- E2E 诊断读取 router snapshot。

### Phase C：手牌 surface

- 接入 `BattlePointerSurfaceController`。
- Chromium/WebKit 触摸手牌统一走 surface 路径。
- 旧 iOS hand bridge 仅在 legacy feature gate 下保留，随后删除。
- Native mouse/card GUI 语义保持不变。

### Phase D：稳定手牌节点

- `refresh_hand()` 改为 keyed reconciliation。
- generation 与 signature 在节点变更前提交。
- 修正滚动范围的单调增长问题。

### Phase E：横向 HUD

- 弃牌区、牌库检索、选择弹窗使用相同 surface 协议。
- 移除 CardView 与 scroller 的双重 press ownership。
- 原生 scrollbar 作为独立 owner，不和内容拖动共享 candidate。

### Phase F：兼容层清理

- 删除 Web 对战路径中的重复 adapter ingestion。
- 删除 iOS-only hand hit-test 与 tap tolerance。
- 仅为 legacy/native 保留确有测试证明需要的 fallback。

## 8. 实际落地结构

实现后，对战场景不再把浏览器输入兼容、动态 HUD 手势和业务编排都堆在
`BattleSceneRuntime.gd`：

```text
BattleSceneRuntime
  -> BattleSceneBrowserPointerRuntime
       -> BattleSceneDialogInteractionReviewRuntime
```

`BattleSceneBrowserPointerRuntime` 现在统一负责：

- 注册、换代和取消语义 pointer surface。
- 手牌、弃牌区及横向卡牌 HUD 的点击/拖动仲裁。
- iOS WebKit touch 与 compatibility mouse 回声归并。
- 页面失焦、弹窗切换和场景退出时的 pointer 清理。
- 调用现有业务 callback，不拥有规则状态。

核心实现文件：

- `scripts/ui/battle/interactions/BattlePointerSurfaceController.gd`
- `scripts/ui/battle/interactions/BattlePointerInputRouter.gd`
- `scripts/ui/battle/BattleDisplayController.gd`
- `scripts/ui/battle/BattleDragScrollCoordinator.gd`
- `scripts/ui/battle/IosWebHudTouchAdapter.gd`
- `scenes/battle/runtime/BattleSceneBrowserPointerRuntime.gd`

手牌已经按 `CardInstance.instance_id` 做 keyed reconciliation。UI 刷新不会再无条件
销毁整排卡牌节点；surface generation 和语义 key 也不再依赖旧 Node。横向 HUD
采用同一手势状态机，并保留原生滚动条作为独立 owner。

## 9. TDD 与平台矩阵

### Godot 纯逻辑

- 同一物理 Touch + Mouse echo 只产生一个 sequence。
- surface generation 变化取消旧 PendingTap。
- 丢失 release 后下一次 press 立即可用。
- 无 overflow 时水平抖动仍是 tap。
- 有 overflow 且超过阈值时只滚动，不提交 tap。
- release 的坐标或旧 Node 不影响稳定 target key。

### Godot 场景 UI

- 连续刷新相同手牌复用相同 CardView。
- 抽牌、出牌、洗牌后仅增删需要的节点。
- 对手回合等待标签切换不残留 pointer owner。
- 弹窗打开/关闭不会把 release 传给手牌或棋盘。
- 手牌缩小时滚动位置被正确 clamp。

### 浏览器 E2E

| 项目 | 布局 | 输入 |
| --- | --- | --- |
| Chromium Desktop | 横屏 | 鼠标 |
| Chromium Pixel 7 | 竖屏 | Touch + compatibility mouse |
| WebKit iPhone | 竖屏 | Touch |
| WebKit iPhone Landscape | 横屏 | Touch |

每个平台至少执行：

- 连续 20 次手牌回合换代并一次点击成功。
- press 后强制手牌 generation 变化且不发送 release；下一次点击成功。
- 轻微抖动点击与真实横向滚动。
- 详情 HUD、弃牌区、牌库选择之间连续切换。
- blur、visibility hidden、pointer cancel 后活动 pointer 数为 0。

### Native 回归

- Windows 原生鼠标 smoke。
- Android emulator 竖屏 tap/swipe。
- `test_battle_ui_features*`
- `test_battle_pointer_input_router`
- `test_battle_drag_scroll_coordinator`
- `test_ios_web_hud_touch_adapter`
- `test_battle_portrait_layout`
- functional runner。

## 10. 验收结果

| Gate | 结果 |
| --- | --- |
| Pointer surface 状态机 | 6/6 |
| 手牌 keyed reconciliation | 5/5 |
| iOS Web HUD adapter | 17/17 |
| Replay / AI 设置功能 UI | 9/9 |
| 架构边界审计 | 3/3 |
| 核心 Godot UI 矩阵（20 suites） | 720/720 |
| Chromium / Pixel 7 / WebKit iPhone 浏览器矩阵 | 13 applicable passed，19 platform-conditioned skipped，0 failed |
| Pixel 7 连续 20 代语义手牌换代 | 通过 |
| Windows 1600×900 真实鼠标往返 | 通过；页面差异 0.2123，返回差异 0.0033 |
| Android 1080×2400 真实触控往返 | 通过；页面差异 0.2134，返回差异 0.0034 |
| Web 导出资源预算 | 通过；PCK 153.22 MiB / 225 MiB，WASM 34.08 MiB / 40 MiB |

Windows 与 Android 的 gate 都会等待游戏运行时真正进入主菜单，再截取基线；不会再
把浏览器窗口或应用启动图误判成测试页面。两者均检查崩溃、ANR 和脚本错误标记。

当前环境没有可执行原生 macOS 包的物理机，因此 macOS 原生窗口只能由 Godot
布局测试覆盖；Safari/WebKit 的竖屏与横屏输入路径已由 Playwright WebKit 项目覆盖。

仓库全量 functional runner 在本次 UI 修复前记录为 4557/4561；其中本次相关的
架构超长和 Replay/ZenMux 过期断言均已修复并分别通过 focused gate。剩余两项是
V18 CPG 模型 transport 状态和一份既有设计文档的源码字符审计，不属于 UI 输入层，
本次未扩大范围修改。

## 11. 完成门槛

- 相关 focused UI 测试全部通过。
- 功能性 UI suite 全部通过。
- Chromium/WebKit 四个项目全部通过。
- 首次 tap 成功率自动化断言为 100%，且每次恰好一个动作。
- 连续换代后 active pointer、active gesture 和旧 generation owner 均为 0。
- 代码中不再新增 `web_ios` 手牌行为分支。
- 所有修改均不改变规则层；浏览器输入兼容被隔离在专用 runtime layer。
