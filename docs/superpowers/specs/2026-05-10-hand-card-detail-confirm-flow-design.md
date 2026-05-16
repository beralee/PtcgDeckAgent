# 手牌卡牌详情确认使用流程设计

## 背景

当前对战中，玩家左键点击手牌会立即进入执行链路：

- `scripts/ui/battle/BattleDisplayController.gd::build_hand_card()` 绑定手牌卡牌左键和右键。
- 左键调用 `BattleScene._on_hand_card_clicked()`。
- `BattleScene._on_hand_card_clicked()` 转发到 `BattleActionController.on_hand_card_clicked()`。
- `BattleActionController` 根据卡牌类型立即使用训练家/竞技场，或把宝可梦、能量、道具设为 `_selected_hand_card` 等待玩家点场上目标。
- 右键调用 `BattleScene._show_card_detail()`，只展示卡牌详情。

这个模式在桌面上效率高，但在手机和竖屏模式下容易误触。手牌区未来也计划改为更适合触控的滚动选牌，因此需要把“查看”和“执行”拆开。

## 目标

1. 点击任意可见手牌卡牌时，不再立即执行任何出牌、贴能、进化或选择目标行为。
2. 点击手牌卡牌统一打开当前右键使用的卡牌详情弹窗。
3. 从手牌打开的详情弹窗底部增加两个大按钮：`使用` 和 `取消`。
4. 点击 `使用` 后复用现有手牌执行入口，不重写卡牌效果或规则执行。
5. 点击 `取消` 或关闭详情时，不改变游戏状态。
6. 竖屏和手机触控下按钮足够大，并沿用已有 HUD 弹窗风格。
7. 为后续“滚动选牌、不直接出牌”的手牌区改造打基础。

## 非目标

1. 不重写卡牌效果系统。
2. 不改变训练家、能量、进化、道具、基础宝可梦的规则判定。
3. 不改变场上宝可梦行动弹窗、招式选择、特性选择。
4. 不改变效果交互弹窗里的卡牌选择逻辑。
5. 不在本阶段改造手牌区滚动方式，只先改点击语义。

## 设计原则

### 执行逻辑保持单一入口

`BattleActionController.on_hand_card_clicked()` 是现有的手牌出牌入口，应继续作为“真正使用手牌”的唯一入口。

新流程只在它之前增加确认层：

```text
手牌左键点击
  -> 打开手牌详情确认弹窗
  -> 使用按钮
  -> 调用原 BattleActionController.on_hand_card_clicked()
```

这样可以避免复制训练家、竞技场、能量、进化、道具、基础宝可梦的分支逻辑。

### 详情弹窗分模式

`DetailOverlay` 需要支持两种模式：

| 模式 | 来源 | 底部按钮 | 行为 |
| --- | --- | --- | --- |
| readonly | 右键、场上卡、弃牌区、奖赏区、对手手牌等 | 关闭 | 只查看，不执行 |
| hand_action | 我方当前可操作手牌左键 | 使用、取消 | 使用后进入现有手牌执行链路 |

不要让所有详情弹窗都出现 `使用`，否则玩家点击弃牌区、对手场上卡牌时会产生错误预期。

### “使用”不等于立即完成

不同卡牌类型在现有代码中的“使用”含义不同：

| 卡牌类型 | 使用按钮后的行为 |
| --- | --- |
| Item | 调用现有训练家使用流程，必要时进入效果交互 |
| Supporter | 调用现有支援者使用流程，保留每回合限制 |
| Stadium | 调用现有竞技场打出流程 |
| Basic Pokemon | 设为 `_selected_hand_card`，等待玩家点空备战位 |
| Evolution Pokemon | 设为 `_selected_hand_card`，等待玩家点可进化目标 |
| Basic/Special Energy | 设为 `_selected_hand_card`，等待玩家点己方宝可梦 |
| Tool | 设为 `_selected_hand_card`，等待玩家点己方宝可梦 |

这和现有执行入口一致，UI 文案应提示玩家“使用后请选择目标”，而不是让玩家误以为点击按钮后动作已经完成。

## 交互流程

### 主阶段手牌点击

```text
玩家点击手牌卡
  if 当前不能接受玩家动作:
    只展示 readonly 详情，或忽略
  else if 存在场上效果交互 / 奖赏选择 / 交接提示 / 抽牌 reveal:
    只展示 readonly 详情，或忽略使用按钮
  else:
    打开 hand_action 详情
```

推荐第一版行为：

- 自己回合主阶段：显示 `使用`、`取消`。
- 非自己回合或锁输入状态：显示只读详情，不显示 `使用`。

### 设置阶段手牌点击

设置阶段当前可能涉及选择起始战斗宝可梦和备战宝可梦。这里不能直接套主阶段出牌逻辑。

推荐第一版行为：

- 设置阶段左键手牌仍打开详情确认弹窗。
- 如果当前 pending choice 是设置战斗区/备战区选择，`使用` 按钮文案可显示为 `选择`。
- 点击 `选择` 后调用原手牌点击入口，让现有 setup 选择逻辑继续执行。
- 非基础宝可梦可禁用 `选择`，或显示只读详情。

如果第一版实现复杂，可先限定：设置阶段保持原逻辑不变，只改主阶段。最终版本再统一设置阶段。

### 右键和长按

右键/长按应继续作为只读查看：

- 不显示 `使用`。
- 保留 `关闭`。
- 不改变 `_selected_hand_card`。

原因：右键/长按在很多区域已作为“查看详情”的通用手势，不能引入执行风险。

### 使用按钮

使用按钮点击后：

1. 保存待使用卡牌实例 `CardInstance`。
2. 关闭详情弹窗。
3. 校验该实例仍在当前玩家手牌中。
4. 调用原 `_on_hand_card_clicked(inst, source_panel_or_null)` 或新增 `_execute_confirmed_hand_card(inst)`，内部仍转发 `BattleActionController.on_hand_card_clicked()`。
5. 执行后清空待使用引用。

必须在执行前重新校验：

- 当前仍是玩家可操作时机。
- 卡牌仍在手牌中。
- 没有新的 `_pending_choice` 阻塞。
- 当前玩家没有变更。

### 取消按钮

取消按钮点击后：

- 关闭详情弹窗。
- 清空待确认手牌引用。
- 不刷新手牌，除非详情弹窗本身改变了布局状态。
- 不写出牌日志，可写 runtime debug log。

## 数据状态

建议在 `BattleScene.gd` 增加以下状态：

```gdscript
var _detail_hand_action_card: CardInstance = null
var _detail_mode: String = "readonly"
```

或使用更明确的枚举字符串：

- `readonly`
- `hand_action`
- `setup_hand_choice`

详情弹窗打开 API：

```gdscript
func _show_card_detail(cd: CardData) -> void
func _show_hand_card_detail(inst: CardInstance) -> void
```

`_show_card_detail(cd)` 保持只读兼容。`_show_hand_card_detail(inst)` 负责设置 `_detail_hand_action_card` 和按钮状态，然后复用详情内容渲染。

## UI 结构

当前 `DetailOverlay` 结构在 `BattleScene.tscn`：

```text
DetailOverlay
  DetailCenter
    DetailBox
      DetailVBox
        DetailTitle
        DetailContent
        DetailCloseBtn
```

运行时 `_setup_detail_preview()` 已经重排为：

```text
DetailHeader
DetailBody
```

建议在 `_setup_detail_preview()` 中补充：

```text
DetailActionBar: HBoxContainer
  DetailUseButton: Button
  DetailCancelButton: Button
```

按钮规则：

- readonly：隐藏 `DetailActionBar`，只保留右上角 `X`。
- hand_action：显示 `DetailActionBar`。
- `使用` 使用暖色 HUD 主按钮。
- `取消` 使用冷色/中性 HUD 按钮。
- 竖屏下按钮高度跟现有 portrait dialog button 规格一致，至少 64px；安卓放大后跟随 portrait popup text metrics。

## 触控和滚动手牌的关系

这个设计为未来滚动选牌做准备：

- 现在：点击手牌卡牌打开确认详情。
- 未来：手牌区可以支持水平拖拽滚动，点击只负责选中/详情，不会误执行。
- 如果需要区分拖拽和点击，可以复用场地选择区的拖拽阈值思路：移动超过阈值则只滚动，不打开详情。

## 运行时边界

### 输入锁

以下状态下不得显示可执行按钮：

- `_pending_choice != ""`
- `_is_field_interaction_active() == true`
- `_handover_panel.visible == true`
- `_draw_reveal_active == true`
- AI 正在行动
- 当前玩家不是 `_view_player`
- 游戏已结束

这些状态下可选择：

- 显示 readonly 详情，方便玩家看牌。
- 或完全忽略点击。

推荐显示 readonly 详情，因为用户目标通常是看牌，不应被锁输入阻断。

### 已选中手牌

旧逻辑允许再次点击同一张手牌取消选中。新逻辑下：

- 手中卡点击不再切换 `_selected_hand_card`。
- 取消已选中的目标选择应该通过点击空白区、取消按钮或重新选择另一张手牌完成。

第一版可以保留旧的“使用后进入选目标，再点同张卡取消”的逻辑，因为 `使用` 后才会调用旧入口。

### 执行后刷新

使用训练家/竞技场后，现有执行链会刷新 UI。

基础宝可梦/进化/能量/道具使用后只是进入 `_selected_hand_card` 状态，需要刷新手牌，让被选中卡牌有高亮。这个仍由旧入口完成。

## 实施计划

### Phase 1：详情弹窗动作栏

1. 在 `BattleScene.gd` 增加 `_detail_hand_action_card` / `_detail_mode`。
2. 在 `_setup_detail_preview()` 创建 `DetailActionBar`、`DetailUseButton`、`DetailCancelButton`。
3. 增加 `_set_detail_action_mode(mode, card)`。
4. 修改 `_show_card_detail(cd)` 默认进入 readonly。
5. 增加 `_show_hand_card_detail(inst)`。
6. 增加 `_on_detail_use_pressed()` 和 `_on_detail_cancel_pressed()`。

### Phase 2：手牌点击入口改造

1. 修改 `BattleDisplayController.build_hand_card()`：
   - 左键改为 `scene.call("_show_hand_card_detail", inst)`。
   - 右键继续 `_show_card_detail(inst.card_data)`。
2. 保留 `_on_hand_card_clicked()` 作为确认后的执行入口。
3. 使用按钮调用 `_execute_confirmed_hand_card(inst)`，内部复用 `_battle_action_controller.on_hand_card_clicked()`。

### Phase 3：设置阶段兼容

1. 梳理 setup pending choice：
   - `setup_active_*`
   - `setup_bench_*`
2. 如果 pending choice 是设置阶段手牌选择，详情按钮文案改为 `选择`。
3. 点击 `选择` 后调用旧入口，保留原 setup 流程。
4. 非合法 setup 手卡禁用按钮并显示原因。

### Phase 4：移动端体验

1. 复用 portrait popup metrics，确保动作栏按钮字体、按钮高度在竖屏下放大。
2. 动作栏固定在详情内容下方，不被详情文本滚动挤出屏幕。
3. 详情弹窗层级继续高于场上 HUD、手牌 HUD、弃牌区 HUD。

## 测试计划

### 单元/集成测试

新增或更新测试文件建议：

- `tests/test_battle_ui_features.gd`
- `tests/test_battle_action_controller.gd`
- `tests/test_battle_portrait_layout.gd`

测试点：

1. 手牌左键只打开详情，不立即使用物品。
2. 手牌左键只打开详情，不立即设置 `_selected_hand_card`。
3. 详情 `使用` 后物品走原 trainer 执行链。
4. 详情 `使用` 后基础宝可梦进入等待备战位选择状态。
5. 详情 `使用` 后能量进入等待目标选择状态。
6. 详情 `取消` 不改变手牌、不改变 `_selected_hand_card`。
7. 右键详情不显示 `使用` 按钮。
8. 非当前玩家回合手牌点击只读，不显示可执行按钮。
9. 竖屏下 `使用` / `取消` 字体和按钮高度满足触控阈值。
10. DetailOverlay z-index 高于手牌区、HUD 和弹出层，按钮可点击。

### 回归测试

必须跑：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\tools\run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_battle_ui_features.gd
powershell -ExecutionPolicy Bypass -File scripts\tools\run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_battle_action_controller.gd
powershell -ExecutionPolicy Bypass -File scripts\tools\run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_battle_portrait_layout.gd
```

建议补跑：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\tools\run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_effect_interaction_flow.gd
```

原因：物品/支援者使用后经常进入效果交互，确认层不能影响后续交互步骤。

## 风险和缓解

| 风险 | 影响 | 缓解 |
| --- | --- | --- |
| 误把右键详情也变成可使用 | 玩家可能从弃牌区/对手卡执行非法动作 | 明确 readonly / hand_action 模式 |
| 使用按钮执行时卡牌已离开手牌 | 空引用或非法执行 | 点击使用前重新校验实例仍在当前玩家手牌 |
| 设置阶段流程被破坏 | 开局无法选战斗宝可梦 | Phase 3 单独兼容 setup pending choice |
| 竖屏按钮太小 | 手机仍然难操作 | 复用 portrait popup metrics，并补测试 |
| 使用后选目标提示不清楚 | 玩家以为按钮没有生效 | 使用后沿用现有日志，例如“已选中 X，点击目标” |
| 详情弹窗挡住后续效果弹窗 | 操作卡住 | 使用按钮先关闭详情，再调用执行入口 |

## 验收标准

1. 点击手牌中的任意卡不再立即打出、贴能、进化或选择手牌。
2. 点击手牌显示卡牌详情，且底部有清晰的 `使用` / `取消` 大按钮。
3. 点击 `取消` 无任何游戏状态变化。
4. 点击 `使用` 后行为与旧版直接点击手牌一致。
5. 右键/长按详情仍是只读。
6. 横屏和竖屏都可操作，按钮不被 HUD 遮挡。
7. 自动化测试覆盖手牌详情确认、取消、使用、右键只读和竖屏按钮尺寸。

