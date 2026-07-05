# 横屏牌库取牌 UI 改造设计

日期：2026-06-30

## 背景

玩家参考 PTCG Live 的交互，希望横屏模式下“从牌库里拿卡”的 UI 更清晰：上方展示牌库候选卡，下方展示已选中的卡，中间一条提示说明和确认区，侧边展示当前使用的卡（例如巢穴球、高级球、大地容器）。

本设计只改 UI 层展示和输入组织，不改变卡牌效果脚本、GameState 结算逻辑、选择 step 的数据契约。

参考 mockup：[2026-06-30-landscape-library-search-ui.svg](assets/2026-06-30-landscape-library-search-ui.svg)

## 现状代码判断

相关入口：

- `scripts/effects/BaseEffect.gd`
  - `build_full_library_search_step(...)` 已经统一构造完整牌库检索 step。
  - 关键元数据包括 `visible_scope`、`items`、`card_items`、`card_indices`、`choice_labels`、`min_select`、`max_select`、`allow_cancel`、`force_confirm`、`card_click_selectable`。
- `scripts/ui/battle/BattleEffectInteractionController.gd`
  - `show_interaction_step(...)` 把 step 转为 `_show_dialog(...)` 所需的 `dialog_data`。
  - 这里已经透传 `visible_scope`、`force_confirm`、`cancel_resolves_empty` 等字段，是新 UI 的最佳触发点。
- `scripts/ui/battle/BattleDialogController.gd`
  - `show_dialog(...)` 根据 `presentation` 分支到 `show_card_dialog(...)` / `show_text_dialog(...)` / `show_assignment_dialog(...)`。
  - 卡牌选择最终仍通过 `confirm_dialog_selection(scene, PackedInt32Array([...]))` 回传。
  - 当前卡牌模式在单选时会立即确认，多选或 `force_confirm` 才显示确认按钮。
- `scripts/ui/battle/layouts/BattleLandscapeLayoutView.gd`
  - 横屏 `DialogBox` 当前宽度约为视口 62%，普通弹窗合适，但完整牌库检索需要临时更宽的布局。

结论：新 UI 应作为 `BattleDialogController` 的一个横屏牌库检索展示分支，不需要修改 `BaseEffect` 的语义，也不需要各卡牌效果单独适配。

## 目标

1. 横屏完整牌库检索使用 PTCG Live 风格的三段式结构：
   - 上方：牌库候选区，横向拖动浏览。
   - 中间：蓝色指令条，显示本次选择要求、确认、取消。
   - 下方：已选区，展示当前选择的卡槽。
   - 右侧：当前使用卡，只读展示触发这次检索的卡。
2. 点击上方卡牌只改变 UI 选择状态，把卡移入/移出下方槽位；确认后才真正结算。
3. 保留右键/长按查看详情能力。
4. 支持 0 张空开、1 张选择、最多 N 张选择、不可选候选卡、取消。
5. 仅横屏启用。竖屏暂不改，避免牵动之前修过的竖屏事件隔离问题。

## 非目标

- 不改卡牌效果脚本的 step 构造。
- 不改 `GameStateMachine` 的效果结算。
- 不改 AI 自动选择逻辑。
- 不把所有卡牌弹窗都改成这个模式；只针对完整牌库检索类 UI。
- 不在本轮直接实现代码。

## 触发规则

建议新增一个 UI 判定函数，例如：

```gdscript
func dialog_should_use_library_search_board(scene: Object, items: Array, extra_data: Dictionary) -> bool:
    return str(extra_data.get("visible_scope", "")) == "own_full_deck" \
        and str(extra_data.get("presentation", "auto")) == "cards" \
        and not bool(extra_data.get("ui_mode", "") == "card_assignment") \
        and str(scene.get("_active_battle_layout_mode")) == "landscape"
```

不要用单纯 viewport 宽高比兜底。这个项目存在浏览器、Android 旋转、竖屏适配和特殊画布尺寸，宽高比会误判；必须以布局控制器已写入的 `_active_battle_layout_mode == "landscape"` 为准。

触发例子：

- 巢穴球：从牌库选择 1 张基础宝可梦。
- 高级球：弃牌后从牌库选择 1 张宝可梦。
- 大地容器：弃牌后从牌库选择最多 2 张基本能量，可以空开。
- 深钵镇：选择最多 1 张特定宝可梦，可以空开。
- 阿尔宙斯/其他从牌库找卡能力：只要走 `build_full_library_search_step` 并带 `visible_scope == own_full_deck`。

## 推荐 UI 结构

在现有 `DialogOverlay -> DialogCenter -> DialogBox -> DialogVBox` 内动态创建一个新容器，不新增 tscn 静态节点，降低迁移风险。

建议节点层级：

```text
DialogVBox
  DialogTitle                         仍保留，用于辅助可访问性/日志，可视觉上降权
  LibrarySearchBoard                  新增，默认隐藏；mouse_filter = STOP
    MainRow
      LibraryAndSelectionColumn
        LibraryScroll                 上方牌库候选区
          LibraryCardRow
        InstructionBar                中间提示条
          InstructionText
          DialogButtons               移入原 DialogConfirm/DialogCancel，不能新建绕路按钮
        SelectedScroll                下方已选区
          SelectedSlotRow
      SourceCardPanel                 右侧当前使用卡
        SourceCardView
        SourceCardCaption
  DialogCardScroll                    旧卡牌模式，非此分支隐藏
  DialogList                          旧文本模式，非此分支隐藏
  DialogButtons                       此分支可隐藏，按钮移动到 InstructionBar
```

按钮复用建议：

- 优先复用现有 `_dialog_confirm`、`_dialog_cancel` 的信号和输入保护逻辑。
- 视觉上可把原 `DialogButtons` 或原 `_dialog_confirm/_dialog_cancel` 移入 `InstructionBar`，但必须保存原 parent/index，退出 board 后恢复。
- 不要新建第二套确认按钮去绕开 `on_dialog_confirm()`。原按钮还绑定了 `gui_input` 和 `button_down`，用于记录新鲜输入并阻止点击穿透。
- Board 模式要有显式状态，例如 `_dialog_library_search_board_mode`，并在 `show_dialog()` 每次进入时清理旧 board、隐藏旧 scroll/list/assignment、恢复按钮父节点。
- Board 模式仍保留 card-dialog 语义：`_dialog_card_mode = true`，确认状态和回传继续使用 `_dialog_card_selected_indices`。

## 布局参数

横屏 16:9 基准：

- 遮罩：沿用 `DialogOverlay`，`mouse_filter = STOP`，`z_index` 沿用当前 dialog。
- `DialogBox` 宽度：`clampf(viewport.x * 0.88, 960, viewport.x - 48)`，只在 board 模式生效。
- 内容总高度：`clampf(viewport.y * 0.78, 520, viewport.y - 40)`。
- 右侧源卡栏宽度：`clampf(viewport.x * 0.14, 168, 230)`。
- 牌库候选卡尺寸：沿用 `_dialog_card_size`，但上限可略小，避免 60 张时滚动负担过大。
- 已选区卡尺寸：候选卡 0.85 倍。
- 中间指令条高度：72 px 左右，内部使用两栏：左侧任务文案和计数，右侧固定按钮。
- 确认/取消按钮最小高度 44-48 px，不能使用 34 px 这种窄按钮。
- 选中态使用金色描边/勾选角标/下方已选复制卡，不能只靠小字提示。

窄横屏（例如 1280x720）：

- 右侧源卡可缩小，但不要隐藏。
- 已选区显示最多 3 个槽位，其余横向滚动。
- 指令文字可换行，但按钮宽高固定，不随文字挤压。
- 下方只显示有效槽位和已选结果；不要展示“未启用”这类工程状态。
- 候选区和已选区应弱化大面板感，更接近 PTCG Live 的战场浮层轨道。

宽度实现必须放到 `BattleLandscapeLayoutView.gd`，以 `_dialog_library_search_board_mode` 或 `LibrarySearchBoard.visible` 为条件设置。只在 `show_library_search_board_dialog()` 里设置宽度会被横屏 layout 刷新覆盖。

## 选择交互

状态仍使用 `_dialog_card_selected_indices`，不新建结算状态。

Board 分支不是新选择系统。它必须保持 `_dialog_card_mode = true`，这样 `update_dialog_confirm_state()` 和 `on_dialog_confirm()` 才会继续从 `_dialog_card_selected_indices` 读取选择并回传 `PackedInt32Array`。

点击候选卡：

1. 如果 `card_indices[i] < 0`，只允许详情查看，不进入已选区。
2. 如果 `max_select == 1`，替换当前已选卡，不立即确认。
3. 如果 `max_select > 1`，在未超过上限时追加；已选则移除。
4. 如果 `max_select == 0`，不允许选择，但仍允许查看详情。
5. 每次变化调用：
   - `sync_dialog_card_selection(scene)`
   - 新增 `sync_library_search_selected_slots(scene)`
   - `update_dialog_confirm_state(scene)`

点击已选槽：

- 移除对应 `real_index`，同步上方高亮和确认按钮状态。
- 已选槽 meta 保存 real index，不能保存 display index。

确认：

- 继续调用 `on_dialog_confirm(scene)`。
- 空开场景依赖 `min_select == 0`，确认按钮必须可用。
- `force_confirm` 在该分支应视为 true，因为这个 UI 的核心就是二段确认。
- 回传必须是 `card_indices` 映射后的真实 index。旧实现已经把 `card_indices[i]` 写入 `dialog_choice_index`，新下方槽位也必须沿用同一 real index。

取消：

- 继续调用 `on_dialog_cancel(scene)`。
- `allow_cancel == false` 时按钮隐藏或禁用，行为沿用现有逻辑。

详情查看：

- 右键/长按候选卡仍连接 `_on_dialog_card_right_signal`。
- 点击源卡只查看详情，不参与选择。

## 当前使用卡来源

理想数据源是在发起效果交互时透传：

- `_pending_effect_card`：当前使用的训练家卡、招式来源或特性来源。
- `pending_effect_kind`：可用于 caption，例如“当前使用：道具”。

实现时可以在 `show_interaction_step(...)` 构造 `dialog_data` 时增加 UI 元数据：

```gdscript
dialog_data["source_card"] = pending_effect_card
dialog_data["source_kind"] = pending_effect_kind
```

这属于 UI 元数据透传，不改变结算逻辑。如果没有来源卡，右侧栏显示为空态：“本次效果”。

显示契约：

- 道具、支援者、竞技场：显示被使用的训练家卡图，caption 显示卡牌类型。
- 特性、招式：显示发动效果的宝可梦，caption 显示“特性”或“招式”。
- 工具赋予招式：`_pending_effect_card` 可能是使用招式的宝可梦，而真实工具来源在 `granted_attack.source_card_instance_id`。第一版可以回退显示宝可梦，不做深解析；如果实现工具来源解析，也必须只读查询，不能影响效果结算。
- 缺失来源卡：显示低权重占位，不要和真实源卡同等视觉权重。
- 源卡栏只读。点击/长按只允许打开详情，不改变 `_dialog_card_selected_indices`。

## 代码落点建议

最小改动路径：

1. `BattleEffectInteractionController.gd`
   - 在 `dialog_data` 中透传 `source_card` / `source_kind`。
   - 不要把 `presentation` 改成 `library_search_board` 之类的具体 UI 字符串。效果交互层只透传 UI 元数据，分支判定放在 `BattleDialogController`。
2. `BattleDialogController.gd`
   - 新增判定函数 `dialog_should_use_library_search_board(...)`。
   - 新增 `show_library_search_board_dialog(...)`。
   - 新增构建/复用容器函数：`ensure_library_search_board(...)`。
   - 新增同步函数：`sync_library_search_board_selection(...)`。
   - 新增槽位点击 handler：`on_library_selected_slot_pressed(...)`。
   - 新增 `_dialog_library_search_board_mode` 状态，进入任意 dialog 前先清理/恢复 board 节点和按钮父节点。
   - Board 模式设置 `_dialog_card_mode = true`，不要改 `on_dialog_confirm()` 的结算契约。
   - `show_dialog(...)` 分支顺序调整为：
     - assignment
     - action_hud
     - library_search_board
     - card
     - text
3. `BattleLandscapeLayoutView.gd`
   - 如果 dialog 当前处于 library search board，应用更宽 `DialogBox` 和内容高度。
   - 其他 dialog 保持现状，避免影响 Windows 横屏对战设置/普通弹窗。
4. `BattleSceneRuntimeFoundation.gd`
   - 只在需要长期保存节点引用时新增变量。优先用 Controller 内部通过 meta 或 `find_child` 管理，减少 scene 全局变量膨胀。

实现细节：

- `LibraryScroll` 和 `SelectedScroll` 都接入现有 `_configure_card_gallery_drag_scroll()` / `_configure_card_gallery_card_view()`，否则横向拖动容易重新变成点击误触。
- 候选卡列表不要在每次点击后全量重建；优先同步 selected 状态和重建下方已选槽，降低 60 张牌时的卡顿。
- 已选槽用 `BattleCardView` 克隆展示，左键移除，右键/长按详情。
- 不可选候选卡保留详情入口，用低饱和、信息角标或锁形状态表达“可看不可选”。

## 事件隔离要求

这是本改动的硬约束，因为此前多次出现遮罩穿透和按钮连带点击问题。

- `LibrarySearchBoard`、`InstructionBar`、候选卡、已选槽、源卡栏都必须 `mouse_filter = STOP`。
- 确认/取消必须继续走现有 `_prepare_dialog_action_input_guard`、`_record_dialog_fresh_input`、`mark_modal_input_consumed` 路径。
- 隐藏 dialog 后必须保持 `_begin_dialog_modal_transition/_end_dialog_modal_transition` 顺序。
- 不用新按钮直接调用 `_handle_effect_interaction_choice`。
- 选卡点击只更新 `_dialog_card_selected_indices`，不得在 card click 内直接调用结算。
- 如果移动 `DialogButtons` 到指令条，退出 board 必须恢复到原 parent/index；普通 dialog 的按钮布局和输入保护不能变化。

## TDD 计划

新增或扩展测试优先放在 `tests/test_battle_modal_end_turn_input_isolation.gd`、`tests/test_battle_effect_interaction_controller.gd` 或新建 `tests/test_landscape_library_search_ui.gd`。

建议测试：

1. `test_full_library_search_uses_board_only_in_landscape`
   - 给 `visible_scope = own_full_deck`、`presentation = cards`。
   - 横屏时进入 board 分支；竖屏时仍走原卡牌 dialog。
   - 非 `own_full_deck`、assignment、action_hud 不进入 board。
2. `test_single_select_does_not_auto_confirm_in_library_board`
   - `min_select = 1`、`max_select = 1`。
   - 点击候选卡只更新 `_dialog_card_selected_indices`，不调用 `_handle_effect_interaction_choice`。
3. `test_confirm_returns_original_real_indices`
   - 使用 `card_indices` 混合真实 index 和 `-1`。
   - 确认时回传真实 index，不回传显示 index。
4. `test_empty_confirm_allowed_when_min_select_zero`
   - 大地容器/深钵镇类 `min_select = 0`。
   - 未选择时确认按钮可用，确认回传空数组。
5. `test_disabled_candidate_cannot_enter_selected_slots`
   - `card_indices[i] == -1` 的候选点击不改变选择。
6. `test_source_card_panel_is_read_only`
   - 点击源卡不会改变选择，只触发详情或无动作。
7. `test_dialog_input_does_not_fall_through_after_confirm`
   - 模拟确认按钮下方有场上宝可梦/结束回合按钮。
   - 确认事件后不能触发底层 board action。
8. `test_existing_card_dialog_unaffected`
   - 非 `own_full_deck` 的 discard/hand/field 选择仍走旧分支。
9. `test_landscape_board_layout_does_not_resize_regular_dialog`
   - 横屏普通 dialog 保持现有宽度；只有 board 进入 88% 宽度。
10. `test_real_card_smoke_nest_ultra_vessel_artazon`
   - 用真实效果 step 打开 UI：巢穴球、高级球、大地容器、深钵镇。
   - 大地容器覆盖 0/1/2 张；深钵镇覆盖 0/1 张。

测试落点建议：

- 新建 `tests/test_landscape_library_search_ui.gd`：集中测 board predicate、点击候选、已选槽、禁选卡、源卡只读、确认/取消。
- 扩展 `tests/test_battle_modal_end_turn_input_isolation.gd`：新增横屏 board 事件不穿透，不要复用强制 portrait 的 helper。
- 扩展 `tests/test_battle_effect_interaction_controller.gd`：断言 `visible_scope/force_confirm/cancel_resolves_empty/source_card/source_kind` 只作为 UI metadata 透传，不改变结算。
- 保留现有 portrait 测试，不要把旧测试改成 board 期望；新增 landscape counterpart。

## 验收标准

- 横屏巢穴球：点击基础宝可梦后卡移到下方已选区，再点确认才加入手牌。
- 横屏高级球：弃牌完成后牌库检索 UI 正常弹出，选择后确认生效。
- 横屏大地容器：弃牌完成后能选择 0/1/2 张能量，确认与取消都有效。
- 横屏深钵镇：能空开，确认空选择有效。
- 横屏普通弃牌区/手牌选择弹窗不变。
- 竖屏行为不变。
- 确认、取消、候选卡点击不会穿透到底层结束回合、撤退或备战区宝可梦。

## 分阶段实现建议

阶段 1：无视觉重构的行为 TDD

- 增加判定函数和测试替身。
- 确保单选不自动确认、空确认可用、回传 index 正确。

阶段 2：容器和视觉实现

- 动态创建 `LibrarySearchBoard`。
- 上方候选区、下方已选区、指令条、源卡栏。
- 复用现有 `BattleCardView`。

阶段 3：横屏布局适配

- 仅 board 模式调整 `DialogBox` 宽度和高度。
- 720p、1080p、窗口缩放回归。

阶段 4：事件隔离回归

- 跑已有 modal/input/portrait/landscape 相关测试。
- 手动验证巢穴球、高级球、大地容器、深钵镇。

## 风险与取舍

- 风险：如果把确认按钮做成新按钮，容易绕开现有事件保护。规避：复用 `_dialog_confirm` 或确保新按钮只转发到 `on_dialog_confirm()`。
- 风险：新按钮只调用 `on_dialog_confirm()` 仍可能缺少 `gui_input/button_down` 的新鲜输入记录。规避：移动原按钮/原按钮行，不新建替身按钮。
- 风险：动态移动 `_dialog_confirm` parent 可能影响普通弹窗。规避：显示 board 时保存原 parent/index，隐藏时恢复到 `DialogButtons`；测试普通 dialog 不受影响。
- 风险：60 张候选卡全部实例化 BattleCardView 会增加布局负担。短期可接受，后续可做分页/虚拟化；本设计先不引入虚拟化，避免扩大范围。
- 风险：横屏宽 dialog 影响其他弹窗。规避：所有宽度逻辑只在 board 模式生效。
- 风险：宽度只在 show 阶段设置会被 `BattleLandscapeLayoutView` 覆盖。规避：横屏 layout 根据 board mode 设置宽度。
- 风险：源卡栏在工具赋予招式等边缘情况下显示的来源不完全准确。规避：第一版允许回退显示发动宝可梦，避免为 UI 深挖结算链路。

## 评审记录

- UI 设计师：
  - 认可 PTCG Live 的上方候选、下方已选、中间指令条、右侧源卡心智模型。
  - 要求弱化“大弹窗+分区面板”观感，做成战场浮层轨道。
  - 要求选中态和可选态分离，使用勾选/金色描边/下方复制卡，不只靠文字。
  - 要求确认/取消按钮最小 44-48 px，指令条文案和按钮分栏，已选区使用“已选 1/2”等玩家语言。
- 一线开发：
  - 确认方案能落在现有架构里，但 board 必须接回现有 card-dialog 状态机。
  - `_dialog_card_mode` 仍要为 true，否则确认会走 list/hud 路径。
  - 横屏 88% 宽度必须在 `BattleLandscapeLayoutView` 里按 board mode 应用，否则会被 62% 默认宽度覆盖。
  - 不要新建确认按钮绕开 `gui_input/button_down` 和输入防穿透链路。
  - `card_indices` 必须始终表示真实 index，已选槽删除/追加都操作 real index。
- 测试专家：
  - 现有效果契约已覆盖巢穴球、高级球、大地容器、深钵镇，但缺横屏 board UI 测试。
  - 必须新增 board 触发条件、单选不自动确认、真实 index 回传、空确认、取消、禁选卡、源卡只读、事件不穿透、横屏尺寸和竖屏不受影响测试。
  - 大地容器要覆盖 0/1/2 张；深钵镇覆盖 0/1 张。
