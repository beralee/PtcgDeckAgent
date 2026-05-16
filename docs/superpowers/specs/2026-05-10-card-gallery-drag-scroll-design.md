# 通用选卡与卡牌查看弹窗拖拽滚动设计

## 背景

竖屏和手机端已经验证了一个结论：依赖滚动条本身拖动不适合卡牌横向列表。玩家期望按住卡牌区域后，列表能跟随手指或鼠标横向滑动。

本次只针对两类低耦合、高收益的卡牌横向列表做统一设计：

- 通用选卡弹窗：`BattleDialogController.gd` 中的 `_dialog_card_scroll`。
- 查看类卡牌列表：`BattleDisplayController.gd` 中的 `_discard_card_scroll`。

这两类 UI 都是横向卡牌画廊，适合复用同一套“按住内容区域拖拽”的交互。它们不负责具体卡牌效果结算，因此可以在不触碰规则系统的前提下改造。

## 目标

1. 通用选卡弹窗支持按住卡牌或空白区域横向拖拽滚动。
2. 弃牌区、放逐区、牌库查看、奖赏查看等查看弹窗支持同样的横向拖拽滚动。
3. 竖屏旋转画布下，拖拽方向与玩家视觉方向一致。
4. 拖拽和点击严格区分：超过阈值后只滚动，不触发选卡或查看详情。
5. 不影响现有卡牌选择、多选、禁用卡、右键详情、长按详情、全牌库可选/不可选展示顺序。
6. 不影响横屏桌面端原有滚轮和滚动条行为。
7. 用测试约束，避免后续再次出现“竖屏拖不动、反向、误点选中”的回归。

## 非目标

1. 不改 action HUD、文字选项弹窗、是否确认弹窗。
2. 不改奖赏卡领取选择流程。
3. 不改场上能量分配、猛雷鼓弃能、能量转移这类所见即所得场上交互 UI。
4. 不改卡牌效果、合法动作、资源消耗或规则结算。
5. 不在本轮重做所有弹窗布局，只增加横向卡牌画廊的拖拽能力。

## 现状入口

### 通用选卡弹窗

入口：

- `scripts/ui/battle/BattleDialogController.gd::show_card_dialog`
- `scripts/ui/battle/BattleDialogController.gd::_populate_card_dialog_cards`
- `scenes/battle/BattleScene.gd::_setup_dialog_gallery`

典型使用：

- 巢穴球、高级球、宝芬等从牌库找宝可梦。
- 大地之器等从牌库找能量。
- 派帕等找物品和道具。
- 洗翠沉重球风格的“可选卡在前，不可选卡也展示”的全牌库视图。
- 多选类卡牌弹窗。

风险点：

- 单选弹窗当前可能点卡即确认。
- 多选弹窗点卡会切换选中态。
- 禁用卡可展示但不能选择。
- `show_action_hud_dialog` 也复用 `_dialog_card_scroll`，但它不是卡牌画廊，不能被本次拖拽逻辑误伤。

### 查看类卡牌列表

入口：

- `scripts/ui/battle/BattleDisplayController.gd::_show_card_collection`
- `scripts/ui/battle/BattleDisplayController.gd::_populate_card_collection`
- `scenes/battle/BattleScene.gd::_setup_discard_gallery`

典型使用：

- 查看弃牌区。
- 查看放逐区。
- 查看牌库。
- 查看奖赏卡。
- 其他只读卡牌集合。

风险点：

- 右键/长按查看详情必须保留。
- 查看列表不应出现选中态。
- 空列表仍显示空提示，不需要拖拽。

## 设计原则

### 只给卡牌画廊加拖拽

本次改造对象必须满足两个条件：

1. 是 `ScrollContainer`。
2. 内容行是卡牌列表，例如 `BattleCardView` 或明确的卡牌分组容器。

不能仅凭节点名 `_dialog_card_scroll` 就启用拖拽，因为同一个 scroll 也被文字/action HUD 复用。

### 通用拖拽状态必须独立于手牌区

当前手牌区已有 `_hand_drag_*` 状态。弹窗拖拽不能复用这些全局变量，否则会造成：

- 手里拖拽和弹窗拖拽互相污染。
- 弹窗关闭后手牌点击被错误 suppress。
- 多个弹窗滚动容器无法独立判断。

应新增独立的卡牌画廊拖拽状态，建议统一抽象为：

```gdscript
var _card_gallery_drag_active_scroll: ScrollContainer = null
var _card_gallery_drag_active: bool = false
var _card_gallery_dragging: bool = false
var _card_gallery_drag_start_position: Vector2 = Vector2.ZERO
var _card_gallery_drag_start_scroll: int = 0
var _card_gallery_drag_suppress_click_until_msec: int = 0
```

如果后续还要覆盖 assignment/source/target 等更多画廊，再升级为 helper class 或 dictionary-based state。

### 竖屏坐标必须使用逻辑坐标

竖屏战斗画面存在旋转画布，原始鼠标/触摸坐标的 X/Y 不等于玩家视觉上的横向/纵向。

通用画廊拖拽必须复用当前手牌区修好的坐标转换思路：

```text
physical screen position -> battle local/logical position -> horizontal delta
```

不能直接用 `event.position.x` 做横向滚动，否则竖屏下会再次出现拖不动、反向或只响应极快滑动的问题。

### 拖拽优先级高于点击

交互规则：

1. 按下时记录起点和 scroll 起始值。
2. 移动距离未超过阈值时，不滚动，保留点击可能性。
3. 横向逻辑位移超过阈值后，进入 dragging。
4. dragging 后释放时，禁止本次点击触发选卡/详情。
5. suppress 时间只影响卡牌画廊卡片，不影响其他 HUD 按钮。

建议阈值沿用手牌区：

- `threshold`: 10-14 logical px。
- `sensitivity`: 1.0。
- click suppress: 150-250 ms。

### 滚轮和滚动条兼容

桌面横屏仍保留：

- 鼠标滚轮横向滚动。
- 原生/自定义滚动条可见时仍可操作。

手机和竖屏主要靠内容区域拖拽，不要求玩家抓住滚动条。

## 实施计划

### Phase 1：抽取通用卡牌画廊拖拽入口

改动范围：

- `scenes/battle/BattleScene.gd`
- 必要时新增轻量 helper，优先不新建复杂类。

计划：

1. 新增 `_configure_card_gallery_drag_scroll(scroll, row, source_name)`。
2. 新增 `_handle_card_gallery_drag_scroll_input(event, scroll, source_name)`。
3. 新增 `_is_card_gallery_drag_click_suppressed()`。
4. 复用 `_screen_position_to_battle_local()` 或等价转换，保证竖屏视觉横向拖拽正确。
5. 支持 MouseButton、MouseMotion、ScreenTouch、ScreenDrag。
6. 支持滚轮横向滚动。

边界：

- 不删除 `_handle_hand_drag_scroll_input`。
- 不改变手牌区行为。
- 不在本阶段接入任何弹窗。

### Phase 2：接入通用选卡弹窗

改动范围：

- `scenes/battle/BattleScene.gd::_setup_dialog_gallery`
- `scripts/ui/battle/BattleDialogController.gd::_populate_card_dialog_cards`

计划：

1. 在 `_dialog_card_scroll` 创建后注册 drag handler。
2. 只在 `show_card_dialog` / `_populate_card_dialog_cards` 的卡牌画廊模式启用。
3. 在 `show_text_dialog` / `show_action_hud_dialog` / 纯按钮模式禁用或忽略画廊拖拽。
4. 卡牌 left click 回调前检查 `_is_card_gallery_drag_click_suppressed()`。
5. 单选、多选都使用同一个 suppress 检查。
6. 右键详情不受拖拽 suppress 影响，除非本次释放已经被判定为拖拽。

验收场景：

- 巢穴球可拖动列表，轻点卡牌仍选择。
- 高级球可拖动列表，轻点卡牌仍选择。
- 宝芬可拖动列表，轻点卡牌仍选择。
- 大地之器多选时，拖动不误选；轻点仍可多选。
- 洗翠沉重球/全牌库视图中，可选卡在前，不可选卡可浏览。
- action HUD 选项不受影响。

### Phase 3：接入查看类卡牌列表

改动范围：

- `scenes/battle/BattleScene.gd::_setup_discard_gallery`
- `scripts/ui/battle/BattleDisplayController.gd::_show_card_collection`
- `scripts/ui/battle/BattleDisplayController.gd::_populate_card_collection`

计划：

1. 在 `_discard_card_scroll` 创建后注册 drag handler。
2. 显示弃牌区/放逐区/牌库/奖赏列表时重置滚动位置。
3. 卡牌详情点击前检查 gallery suppress。
4. 空列表不需要特殊逻辑，保持空提示。

验收场景：

- 点弃牌区 HUD 打开列表，列表可拖动。
- 拖动弃牌列表不会打开卡牌详情。
- 轻点/右键卡牌仍可打开详情。
- 放逐区、牌库查看、奖赏查看行为一致。

### Phase 4：测试与回归约束

新增或扩展测试：

- `tests/test_battle_ui_features.gd`
- `tests/test_battle_dialog_controller.gd`
- `tests/test_battle_display_controller.gd`
- `tests/test_battle_portrait_layout.gd`

建议测试项：

1. `test_card_dialog_drag_scroll_suppresses_selection`
   - 构建 `_dialog_card_scroll` 和多张卡。
   - 模拟按下、横向拖动、释放。
   - 断言 `scroll_horizontal` 变化。
   - 断言没有触发 dialog selection。

2. `test_card_dialog_click_without_drag_still_selects`
   - 模拟短点击。
   - 断言仍可选中或确认。

3. `test_card_dialog_action_hud_not_drag_enabled`
   - 打开 action HUD。
   - 断言不会启用卡牌画廊拖拽 meta 或不会 suppress 按钮点击。

4. `test_card_collection_drag_scroll_suppresses_detail`
   - 打开弃牌区列表。
   - 模拟拖动。
   - 断言列表滚动且没有打开详情。

5. `test_card_collection_click_without_drag_still_opens_detail`
   - 轻点卡牌。
   - 断言详情仍打开。

6. `test_portrait_card_gallery_drag_uses_logical_axis`
   - 复用手牌区竖屏旋转坐标测试思路。
   - 模拟手机竖屏中视觉横向拖动。
   - 断言 scroll 增加或减少符合预期。

必须跑的测试：

```powershell
godot --headless --path . -s tests/test_battle_ui_features.gd
godot --headless --path . -s tests/test_battle_dialog_controller.gd
godot --headless --path . -s tests/test_battle_display_controller.gd
godot --headless --path . -s tests/test_battle_portrait_layout.gd
```

如果单测入口仍使用项目既有 wrapper，则按当前仓库测试命令替换，但这四组测试必须覆盖。

## 风险与控制

### 风险：误伤 action HUD

原因：

- action HUD 也可能复用 `_dialog_card_scroll`。

控制：

- 只有当 row 内存在 `BattleCardView` 或 dialog mode 明确为 `card_dialog` 时才处理卡牌画廊拖拽。
- 增加 action HUD 不受影响测试。

### 风险：拖拽后误选卡

原因：

- `BattleCardView.left_clicked` 可能在释放时触发。

控制：

- 所有 dialog/card collection 卡牌回调前检查 gallery suppress。
- suppress 只在 dragging release 后设置。

### 风险：竖屏方向错误

原因：

- 使用物理 `event.position.x`。

控制：

- 强制使用 battle logical position。
- 增加竖屏旋转坐标测试。

### 风险：多个 scroll 状态混淆

原因：

- 弹窗可能重建 row 或切换 overlay。

控制：

- active drag 状态保存当前 scroll 引用。
- 弹窗关闭、重建 row、隐藏 overlay 时清理 active 状态。

### 风险：查看类列表拖动影响右键详情

原因：

- 右键/长按和拖动共享卡牌输入。

控制：

- 鼠标右键直接走详情，不启动 drag。
- 触摸长按详情如已有实现，应只在未进入 dragging 时触发。

## 回滚策略

所有接入点都应通过 meta 或开关隔离：

```gdscript
scroll.set_meta("card_gallery_drag_scroll_enabled", true)
```

如果上线后出现弹窗选择异常，可以快速：

1. 禁用 `_dialog_card_scroll` 的 gallery drag。
2. 保留 `_discard_card_scroll` 的查看类 gallery drag。
3. 或通过项目设置开关整体关闭 gallery drag，手牌区拖拽不受影响。

## 交付标准

1. 选卡弹窗和查看列表都能在竖屏中按住内容区域平滑横向拖动。
2. 拖动不会触发选卡、确认或详情。
3. 轻点卡牌的原有行为不变。
4. action HUD、文字确认弹窗、奖赏领取、场上能量分配不变。
5. 横屏模式原有滚轮、滚动条、点击行为不变。
6. 相关测试全部通过。
