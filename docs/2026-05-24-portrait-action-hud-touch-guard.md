# 竖屏宝可梦行动 HUD 触摸穿透修复设计

## 背景

安卓竖屏模式下，点击己方战斗宝可梦有时不会停留在“技能/招式/撤退”行动 HUD，而是直接进入某个行动的后续流程。例如：

- 点击旋转洛托姆后直接进入“风扇呼唤”。
- 点击太乐巴戈斯上半部分后直接进入撤退的备战宝可梦选择。
- 点击卡牌下半部分仍可能正常显示行动 HUD。

代码排查显示，场上宝可梦卡牌视图本身在 field slot 中不直接处理点击，战斗位输入统一走外层 slot：

`_on_slot_input -> _handle_slot_touch_detail_input -> _handle_slot_left_click -> _show_pokemon_action_dialog`

撤退选择框不会由 slot 点击直接打开，只会在 `pokemon_action` 选择了 `retreat` 后打开。因此问题不是卡牌规则分支错误，而是同一次触摸打开行动 HUD 后，后续派发的模拟鼠标/触摸事件继续落到刚出现的 action HUD 选项上。

## 目标

竖屏触摸点击己方场上宝可梦时：

- 第一次触摸只打开宝可梦行动 HUD。
- 同一次物理触摸派生出来的后续鼠标/触摸事件不能选择行动项。
- 用户下一次明确点击行动 HUD 时，仍能正常选择特性、招式或撤退。
- 不影响横屏鼠标点击、手牌点击、场地/弃牌/Lost 区 HUD 的现有输入保护。

## 方案

新增一个“行动 HUD 刚打开输入保护窗口”：

1. 在 slot 短触摸释放准备打开行动 HUD 前，记录一个短时间保护截止时间。
2. action HUD 选项收到点击时，先检查保护窗口。
3. 如果仍在保护窗口内，消费该事件并保持 `pending_choice == "pokemon_action"`。
4. 保护窗口过后，action HUD 选项恢复正常点击。

保护只在 slot 触摸释放路径设置，不在普通鼠标右键/左键打开行动 HUD 时设置，避免影响桌面端快速操作。

## TDD Plan

1. 新增失败用例：竖屏模式下 `ScreenTouch press/release` 点击 `my_active`，确认只打开 `pokemon_action`。
2. 在同一时间窗口内向 action HUD 第一项发送模拟鼠标点击，期望仍停留在 `pokemon_action`，不能进入 `retreat_bench`。
3. 新增正向用例：保护窗口过期后再次点击同一 action HUD 选项，期望可以进入 `retreat_bench`。
4. 实现最小输入保护逻辑。
5. 跑相关 UI 回归测试：
   - `tests/test_battle_ui_features.gd`
   - `tests/test_battle_ui_handover_regression.gd`
   - `tests/test_battle_portrait_layout.gd`

## 验收标准

- 竖屏触摸战斗宝可梦不会直接触发风扇呼唤、撤退或其他行动。
- 用户第二次点 action HUD 时可以正常触发目标行动。
- 现有 modal follow-up suppression 测试保持通过。
