# 竖屏弹框宽度与赛后结算精简设计

## 背景

竖屏对战布局已经有独立的 `BattlePortraitLayoutView` 和统一的 portrait content frame，但弹框体系还没有完全接入这一套 surface contract。当前代码里，`DialogBox` 已经通过 `_apply_portrait_dialog_width_metrics()` 做了竖屏宽度适配；弃牌区、Lost 区、卡牌详情、场上交互、复盘和赛后结算仍有不少固定横屏尺寸或直接读取 raw viewport 的逻辑。

这会带来两个问题：

- 手机竖屏下，查看弃牌区、Lost 区、卡牌详情等弹框没有充分利用屏幕宽度。
- 不同弹框各自维护尺寸，后续调整容易出现同类问题反复修。

本次设计只处理 UI 结构和尺寸策略，不改变卡牌效果、对战状态机、AI 决策和实际胜负结算。

## 现状梳理

### 已经有竖屏适配的部分

- `BattleScene.gd`
  - `_update_portrait_overlay_metrics(viewport_size)`
  - `_apply_portrait_popup_text_metrics()`
  - `_apply_portrait_dialog_width_metrics()`
  - `_portrait_dialog_width(viewport_size)`

这些方法目前主要服务 `DialogOverlay/DialogBox`，并顺带放大弹框中的文字和滚动条。

### 需要纳入统一尺寸策略的弹框

1. `DialogOverlay / DialogBox`
   - 选卡、普通确认、效果交互说明都从这里走。
   - 当前卡牌选择弹框竖屏宽度约为 `80%`，普通弹框约为 `94%`。

2. `DiscardOverlay / DiscardBox`
   - 弃牌区、Lost 区、奖赏卡、牌库查看共用这套 UI。
   - 当前核心内容通过 `BattleDisplayController._show_card_collection()` 填充。
   - 竖屏下应优先改这里，因为它直接对应“查看弃牌区”等高频操作。

3. `DetailOverlay / DetailBox`
   - 手牌右键/长按、弃牌区卡牌点击、卡组编辑卡牌详情都依赖类似体验。
   - 对战内的 `DetailBox` 现在有固定大尺寸和左右布局，需要按竖屏安全宽度重新计算。

4. `FieldInteractionOverlay / FieldInteractionPanel`
   - 能量分配、伤害指示物分配、场上目标选择等效果使用。
   - `BattleInteractionController.update_field_interaction_panel_metrics()` 已有 touch profile，但仍应改为从 portrait content frame 推导有效宽度，而不是直接使用 raw viewport。

5. `ReviewOverlay / ReviewBox`
   - 现有 AI 复盘结果展示。
   - 不是本次主要体验目标，但作为内容型弹框，应复用统一宽度策略，避免后续打开时仍是横屏尺寸。

6. `HandoverPanel / HandoverBox` 与 `CoinFlipOverlay / CoinBox`
   - 轻量确认类弹框。
   - 不必强行接近满屏，但应使用统一的确认弹框宽度规则，保证按钮触摸面积足够。

7. `MatchEndOverlay / MatchEndBox`
   - 当前赛后结算由 `BattleOverlayController` 动态创建。
   - 包含统计卡、资源摘要、行动摘要、AI 快评面板、AI 复盘/学习池相关按钮。
   - 本次需要重写为精简版，只保留基本必要信息，不再展示或自动触发 AI 复盘/AI 快评。

## 设计目标

1. 竖屏内容型弹框宽度接近屏幕宽度，并且基于 portrait content frame，而不是 raw viewport。
2. 横屏弹框视觉不因为竖屏优化发生大幅变化。
3. 同类弹框复用一套尺寸策略，后续不再逐个硬编码。
4. 赛后结算弹窗改为轻量、清晰、无网络依赖。
5. 不删除现有 AI 复盘服务代码，避免影响独立测试和未来入口；但赛后结算弹窗不再调用它。

## 统一弹框尺寸规则

新增一个竖屏弹框尺寸 profile，建议放在 `BattleScene.gd` 或后续抽到 HUD/theme helper：

- `content_width`: 来自 `_portrait_dialog_viewport_size().x`，优先使用 `_portrait_layout_frame_rect.size.x`。
- `content_height`: 同上。
- `near_width`: `round(content_width * 0.94)`。
- `compact_width`: `round(content_width * 0.84)`。
- `min_width`: `min(320, content_width - margin * 2)`，避免窄屏异常。
- `max_width`: 不超过 content frame。
- `margin`: 竖屏默认 `16 - 24` 逻辑像素，具体沿用 `HudTheme.TOUCH_DIALOG_MARGIN`。

弹框分类：

| 类型 | 代表 UI | 竖屏宽度 | 说明 |
| --- | --- | --- | --- |
| 内容型 | 弃牌区、Lost 区、牌库、奖赏卡、卡牌详情、AI 复盘 | `near_width` | 接近屏宽，优先可读性 |
| 卡牌选择型 | 巢穴球、宝芬、高级球、大比鸟等 | `near_width` | 替代当前 `80%`，给滑轮/横向卡牌更多空间 |
| 场上交互型 | 目标选择、能量/伤害分配 | `near_width` | 基于 content frame，而不是 raw viewport |
| 确认型 | 投币、换边确认、短提示 | `compact_width` | 不需要满屏，但按钮要大 |
| 赛后结算 | MatchEndOverlay | `near_width`，但内容更少 | 精简版，单按钮 |

## 弹框调整方案

### DialogOverlay

- 将 `_portrait_dialog_width()` 从“卡牌选择 80%、普通 94%”改为更统一的逻辑。
- 卡牌选择和普通内容默认都使用 `near_width`。
- 极短确认类如果继续走 `DialogOverlay`，可以通过显式 profile 使用 `compact_width`。
- 显示弹框前必须调用统一尺寸刷新，避免首次打开仍使用旧尺寸。

### DiscardOverlay

覆盖：

- 查看弃牌区
- 查看 Lost 区
- 查看奖赏卡
- 查看牌库
- 效果空挥后的只读牌库预览

调整：

- `DiscardBox.custom_minimum_size.x = near_width`。
- `DiscardCardScroll` 高度按竖屏 content height 计算，建议 `content_height * 0.42 - 0.52`，并设置上下限。
- 横向卡牌 row 保持滑动模式，不改为多列网格，保证和现有“滑块模式”一致。
- 弹框显示后重置横向滚动到 `0`。
- `BattleDisplayController._show_card_collection()` 在 `discard_overlay.visible = true` 前后调用统一 portrait popup metrics。

### DetailOverlay

调整：

- `DetailBox.custom_minimum_size.x = near_width`。
- 高度使用可读上限，建议不超过 content height 的 `0.78`。
- 竖屏安全宽度较窄时，保留卡图左、说明右的结构会挤压文本；需要加入响应式规则：
  - 宽度足够时继续左右布局。
  - 宽度不足时改为上图下文，或缩小卡图并给文本区更大伸展空间。
- 打开详情前调用统一 portrait popup metrics，再播放详情弹出动画。

### FieldInteractionOverlay

调整：

- `BattleInteractionController.update_field_interaction_panel_metrics()` 的 `effective_viewport` 应优先来自 scene 暴露的 portrait content frame。
- touch profile 下 `target_panel_width` 仍可为 `0.94`，但基准从 raw viewport 改为 content frame。
- 目标卡牌滚动条、按钮字号和按钮高度继续沿用 touch profile。
- 保持现有交互路径不变，不改变能量分配、目标选择、确认按钮逻辑。

### ReviewOverlay

调整：

- `ReviewBox` 纳入内容型弹框宽度。
- 只处理显示尺寸，不改变 AI 复盘生成、重新生成和关闭逻辑。
- 后续如果要弱化 AI 复盘入口，可以单独做，不和本次竖屏宽度混在一起。

### Handover 与 Coin

调整：

- 使用 `compact_width`。
- 按钮高度保持 touch profile 最小值。
- 不扩大到满屏，避免短确认弹框显得空。

## 赛后结算弹窗重写

### 当前问题

`BattleOverlayController` 的赛后结算 UI 功能过重：

- 自动触发 `MatchEndQuickReviewService` 或本地快评。
- 显示 AI 快评面板。
- 保留 AI 快评、生成 AI 复盘、加入学习池等按钮变量和刷新逻辑。
- 面板多、文字多，不适合手机竖屏结算。

### 新版原则

赛后结算只回答三件事：

1. 这局赢了还是输了。
2. 为什么结束。
3. 下一步去哪。

不展示 AI 复盘，不触发大模型请求，不显示“重新 AI 快评”，不显示“加入学习池”。

### 精简版内容

建议结构：

- 标题：
  - 赢：`胜利`
  - 输：`再接再厉`
- 副标题：
  - `{获胜方} 获胜`
  - 或 `{玩家名} 使用 {卡组名} 获胜`，如果当前上下文能稳定拿到卡组名。
- 基本信息区：
  - 结束原因：击倒 / 奖赏卡拿完 / 牌库无法抽牌 / 无宝可梦可派出。
  - 回合数。
  - 奖赏进度：我方 `x/6`，对方 `y/6`。
- 一个轻量提示：
  - 胜利：`关键资源处理完成，继续保持节奏。`
  - 失败：`下一局优先关注前期展开和奖赏节奏。`
  - 这条只用本地规则生成，不调用 AI。
- 底部按钮：
  - 普通对战：`返回对战准备`
  - 比赛模式：保留现有比赛模式返回路径和按钮文案，不能误退到普通准备页。

### 代码边界

- 重写 `BattleOverlayController._ensure_match_end_screen()` 生成的节点结构。
- `show_match_end_screen()` 不再自动调用 `_begin_match_end_quick_review()`。
- `_refresh_match_end_ai_panel()`、AI 按钮刷新逻辑不再参与结算弹窗。
- 可以保留 `MatchEndQuickReviewService.gd` 和相关测试，作为未来独立入口或历史兼容，不在本次删除。
- `BattleScene._on_match_end_return_pressed()` 继续作为唯一返回入口，保持比赛模式与普通模式分流。

## 实施计划

1. 新增统一 portrait popup metrics helper。
   - 读取 portrait content frame。
   - 提供 `near_width`、`compact_width`、内容高度上限。

2. 改造 `DialogOverlay`。
   - 卡牌选择弹框改为接近屏宽。
   - 确认型弹框保留紧凑 profile。

3. 改造 `DiscardOverlay`。
   - 宽度接近屏宽。
   - 横向卡牌区高度随竖屏 content height 调整。
   - 显示弃牌、Lost、牌库、奖赏卡时刷新 metrics。

4. 改造 `DetailOverlay`。
   - 宽度接近屏宽。
   - 竖屏下检查图文布局，必要时切换成竖向或缩图布局。

5. 改造 `FieldInteractionOverlay`。
   - 使用 portrait content frame 计算宽度。
   - 保持现有 touch 按钮和滚动条规则。

6. 改造轻确认弹框。
   - Handover 和 Coin 使用 compact width。

7. 重写赛后结算弹窗。
   - 移除结算弹窗内 AI 面板和 AI 相关按钮。
   - 停止赛后自动请求大模型快评。
   - 保留单一返回按钮，并确认比赛模式返回逻辑不变。

8. 回归测试与手动验证。

## 测试计划

新增或更新 `tests/test_battle_portrait_layout.gd`：

1. `test_portrait_dialog_uses_near_screen_width_for_card_selection`
   - 验证卡牌选择弹框竖屏宽度接近 content frame。

2. `test_portrait_discard_overlay_uses_near_screen_width`
   - 验证弃牌区 / Lost 区共用弹框宽度接近 content frame。

3. `test_portrait_detail_overlay_uses_near_screen_width`
   - 验证卡牌详情弹框宽度接近 content frame。

4. `test_portrait_field_interaction_uses_content_frame_width`
   - 验证场上交互面板不再基于 raw viewport 外溢。

5. `test_match_end_screen_is_compact_and_has_single_return_action`
   - 验证赛后结算只有必要信息和一个返回按钮。

6. `test_match_end_screen_does_not_start_quick_review`
   - 验证结算弹窗出现时不触发 `_begin_match_end_quick_review()`。

7. `test_tournament_match_end_keeps_tournament_return_path`
   - 验证比赛模式下返回按钮仍进入比赛流程，不回普通对战准备。

手动验证：

- 安卓竖屏：巢穴球、宝芬、高级球、大比鸟特性。
- 安卓竖屏：查看双方弃牌区、Lost 区、奖赏卡、牌库预览。
- 安卓竖屏：手牌卡详情、弃牌区卡详情、场上宝可梦行动弹框。
- 安卓竖屏：投币结果、换边确认。
- 横屏：确认上述弹框没有变得过宽或破坏原布局。
- 普通对战结束、比赛模式单局结束、比赛冠军页面三条路径分别验证。

## 风险控制

- 不在本次删除 `MatchEndQuickReviewService`，避免影响独立服务测试。
- 不改变 `GameStateMachine` 胜负结算和 action log。
- 不改变卡牌详情文本生成，只改变容器尺寸和布局。
- 不改变弃牌区、Lost 区、牌库数据来源，只改变展示尺寸。
- 所有竖屏尺寸必须从 portrait content frame 推导，避免再次出现首次进入对战时宽度漂移。

## 非目标

- 不重做全部对战 HUD。
- 不增加新的 AI 复盘入口。
- 不改变战斗记录、训练数据、学习池逻辑。
- 不修改卡牌效果或 AI 出牌策略。
- 不把弹框改成独立场景；先在现有节点和控制器结构内收敛尺寸规则。
