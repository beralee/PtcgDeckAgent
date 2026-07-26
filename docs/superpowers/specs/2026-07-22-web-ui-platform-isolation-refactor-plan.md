# 浏览器 UI 平台隔离与无人值守自动化改造计划

日期：2026-07-22

状态：首轮架构改造已落地，并于 2026-07-22 完成实现后代码复审、全量功能/AI 回归以及 Web、Windows、Android 无人值守真实输入验收。

阅读约定：第 1～14 节保留改造前的目标、风险和 TDD 计划；第 15～18 节记录实际落地结果、实现后复审结论、可直接执行的自动化命令和本轮验证证据。如计划描述与实际实现存在差异，以第 15～18 节为准。

## 1. 结论

浏览器 UI 优化不能继续通过在页面、卡牌控件或对战弹窗中追加 `web_ios`、`web_android` 判断完成。目标架构是在原始平台事件与现有 UI/对战控制器之间增加 Web 专属适配边界，并让 Android、Windows 在迁移期继续走当前稳定路径。

改造必须同时处理但严格分离以下问题：

1. 输入问题：触摸、鼠标回声、拖拽、弹窗点击穿透、release 丢失和坐标转换。
2. 生命周期问题：Safari 切后台、地址栏变化、页面恢复、失焦和指针取消。
3. 异步交互问题：抽卡展示、效果选择、AI 道具与动画等待状态必须有确定的完成、取消和超时路径。
4. 资源问题：Web 包体、纹理解码和临时动画节点造成的 Safari 退出或进程回收。

四类问题允许共享诊断信息，但不能在同一控制器中相互补丁式修复。

## 2. 用户问题与成功标准

已知玩家反馈：

- 苹果网页版本进入后退出或无法继续使用。
- 苹果网页版本在抽三张、博士使用后、AI 使用部分道具后出现卡住。
- Android、Windows 当前已有大量经过验证的输入和响应修复，不能因 Web 优化而回退。

成功标准：

- 一次物理手势最多生成一个 UI 意图和一个业务动作。
- 任意交互会话最终进入 completed、cancelled 或 timed_out，不允许永久 pending。
- Web 页面在 pointer cancel、失焦、切后台和恢复后没有残留拖拽、按下或弹窗状态。
- 动画、Tween、纹理或锚点失败不影响规则状态、AI 决策、胜负或后续输入。
- Android 和 Windows 的既有事件轨迹、规则终态、UI 可见状态保持不变。
- 全部验收通过脚本和自动化完成，不依赖人工逐个点击。

## 3. 非目标

- 不修改卡牌规则、效果注册、AI 策略、牌组数据和胜负判定。
- 不一次性重写 `BattleScene` 输入系统。
- 不把 Android、Windows 切到未经验证的新 Web 输入路径。
- 不使用增加延迟窗口作为主要去重方案。
- 不以隐藏动画、跳过提示或自动确认掩盖未完成的状态机。
- 不要求自动化真实 Apple 设备的系统安装、签名或远程调试；真实 Safari 设备能力应通过可接入的远程 runner 执行，缺少 runner 时必须明确报告为未验证，不能改成人工点击清单后宣称通过。

## 4. 不可破坏的现有契约

### 4.1 输入所有权

- 活动 `BattleScene` 存在时，`GameManager` 的非战斗兜底桥必须立即退出。
- 对战模态层必须阻止底层竞技场、手牌、槽位和 HUD 接收同一指针序列。
- `MOUSE_FILTER_IGNORE` 控件不能被全局扫描器重新激活。
- 文本输入是普通指针输入的特例，由平台文本输入适配器负责。

### 4.2 坐标空间

- 原始事件携带屏幕/viewport 坐标。
- Control 命中统一使用可逆 CanvasTransform 转换。
- 战斗棋盘逻辑坐标与具体 Control 本地坐标必须保持两个不同概念。
- 不允许用旋转后的 `get_global_rect()` 与原始屏幕坐标直接比较。

### 4.3 规则与视觉单向依赖

- 规则状态产生视觉事件。
- 视觉层不得修改 `GameState`。
- 动画完成不是规则结算的唯一入口。
- 视觉事件在正常完成、节点释放、超时和取消路径都必须恰好完成一次。

### 4.4 平台隔离

- 场景和业务控制器不直接调用 `JavaScriptBridge`。
- 场景不自行拼装平台判断。
- Windows 和 Android 的现有路径先作为 legacy adapter 保留。
- 新行为只能通过 Web feature gate 激活，并具有运行时 kill switch。

## 5. 目标架构

```text
OS / Browser raw event
          |
          v
UiRuntimeProfile ---- BrowserLifecycleBridge
          |                    |
          v                    v
PlatformInputAdapter -> PointerSequence / UiIntent
          |                    |
          +----------+---------+
                     v
          existing page / battle controller
                     |
                     v
              rules and state machine
```

### 5.1 UiRuntimeProfile

运行时只计算一次能力快照，至少包含：

- `host_kind`: native、web、headless。
- `native_os`: windows、android、ios、macos、unknown。
- `pointer_mode`: mouse、touch、hybrid。
- `layout_class`: compact_portrait、compact_landscape、wide。
- `has_dom_text_input`。
- `supports_pointer_cancel`。
- `can_suspend_without_scene_exit`。
- `performance_tier`。
- `is_test_profile`。

布局、输入、生命周期和性能不得再由同一个 `is_mobile` 布尔值决定。

### 5.2 PlatformInputAdapter

统一输出：

```text
pointer_down(pointer_id, screen_position, source)
pointer_move(pointer_id, screen_position, delta, source)
pointer_up(pointer_id, screen_position, source)
pointer_cancel(pointer_id, reason)
wheel(screen_position, delta)
cancel_action(reason)
```

适配器：

- `WindowsNativeInputAdapter`：初期只透传现有鼠标事件。
- `AndroidNativeInputAdapter`：初期只透传现有触摸及 Godot mouse emulation 行为。
- `WebInputAdapter`：拥有 Web 的 Mouse/Touch 去重、pointer sequence、失焦取消和 DOM 输入边界。

任一 viewport 同一时刻只能有一个顶层输入适配器拥有原始事件。页面和单个按钮不得同时作为第二个全局扫描入口。

### 5.3 PointerSequence

每次物理手势建立稳定序列：

```text
sequence_id
pointer_id
source_kind
press_position
latest_position
owner
started_at
consumed_intent
cancel_reason
```

Touch 产生的合成 Mouse 事件通过序列归属去重，不依赖 180～220ms 时间窗。一个序列只能被一个 owner 消费。

### 5.4 UiInteractionSession

抽卡、效果选择、牌库选择、场上目标选择、奖赏选择、动画确认等交互统一持有：

- session ID 与 generation。
- owner controller。
- prompt/action 类型。
- opened_at、last_progress_at。
- blocking reason。
- completion policy。
- timeout policy。
- completed/cancelled/timed_out 状态。

所有退出路径必须幂等。旧 callback、旧 timer 和旧指针序列不能完成新的 generation。

超时策略按会话语义区分，不能共用一个“自动继续”：

| 会话类型 | 超时动作 |
| --- | --- |
| 纯展示，规则已经结算 | 安全快进到最终画面并完成 session，不重复规则动作 |
| 允许取消的人类选择 | 调用原有合法 cancel 路径 |
| 不允许取消的强制人类选择 | 当前 UI session 标记 timed_out，保留 pending choice，并以新 generation 重建同一提示；绝不代选 |
| AI 拥有的选择 | 由已有规则 fallback/watchdog 策略处理，并记录恢复原因 |

### 5.5 BrowserLifecycleBridge

仅 Web 构建注册浏览器事件：

- `visibilitychange`
- `pagehide` / `pageshow`
- `blur` / `focus`
- `pointercancel` / `touchcancel`
- viewport、orientation 与 visual viewport resize
- `window.onerror`
- `unhandledrejection`

Godot 侧只接收平台无关通知，不直接访问 DOM。暂停时取消 transient pointer capture，恢复时刷新布局并校验活动 interaction session；不能自动重复提交业务动作。

### 5.6 WebPresentationPolicy

Web 性能降级必须集中管理：

- 同屏完整卡牌视图上限。
- 动画队列长度和合并策略。
- 纹理最大解码尺寸。
- 低内存档的 VFX、模糊、阴影和粒子开关。
- 页面隐藏时暂停非必要视觉队列。

该 policy 只影响表现，不影响合法动作、规则或 AI。

## 6. 迁移策略

### Phase 0：诊断基线

- 建立平台能力、原始事件、UiIntent、interaction session 和场景切换的结构化日志。
- 记录 Web 发布包 PCK/WASM 大小、资源分类大小和场景峰值节点/纹理数量。
- 为玩家反馈场景建立确定牌序和确定 AI 行为的可重放 fixture。
- 冻结 Windows、Android 现有输入轨迹和关键 UI 快照。

退出条件：能够区分进程退出、主线程长帧、等待 UI、等待 AI、等待动画和无效重复输入。

### Phase 1：能力快照，不改变行为

- 引入 `UiRuntimeProfile` 和纯函数 resolver。
- 旧平台判断继续产生完全相同结果。
- 用静态审计阻止新增散落的 `OS.has_feature("web*")`。

退出条件：所有现有测试结果不变，运行时日志可打印统一 profile。

### Phase 2：浏览器生命周期与错误桥

- Web Shell 转发生命周期和运行错误。
- 新增 pointer cancel 的统一清理入口。
- 不修改 Android/Windows notification 路径。

退出条件：自动化隐藏/恢复页面后没有残留按下、拖拽和 DOM 输入节点。

### Phase 3：非战斗 Web 输入适配

- 从主菜单、设置、卡组中心、对战设置开始。
- Web adapter 替代 Web 环境中的全局扫描与控件重复桥接。
- Android 仍使用当前 `NonBattleTouchBridge`。
- DOM 文本输入通过注入接口调用。

退出条件：普通点击、滚动、OptionButton、LineEdit 和弹窗全部在桌面 Web、移动 Web 自动化通过。

### Phase 4：对战 Web 输入适配

- 保留现有 `BattleInteractionController`、`BattleDragScrollCoordinator`、modal gate 和卡牌业务 signal。
- 只替换 raw event 到 pointer sequence 的入口。
- 按卡牌点击、手牌拖动、场上槽位、弹窗卡牌、牌库搜索的顺序逐类迁移。

退出条件：每类输入同时通过 Web adapter 测试和 Android/Windows legacy parity 测试。

### Phase 5：interaction session 收口

- 抽卡展示、效果交互、AI prompt、奖赏和动画确认接入 session。
- 旧状态字段作为兼容镜像，迁移完成前不删除。
- 会话超时只做 UI 安全收口，不自行猜测玩家选择。
- AI 自有选择允许通过已有规则 fallback 恢复。

退出条件：所有阻塞状态均有自动恢复断言和 stale callback 测试。

### Phase 6：Web 资源与表现预算

- 收紧 Web export filter，排除 raw sheet、测试产物和未引用源素材。
- 验证移动 Web 纹理压缩和最大解码尺寸。
- 为 Web 低性能档限制临时 `BattleCardView`、Tween、粒子和队列。
- 不改变 Android/Windows 资源包，除非单独批准跨平台等价瘦身。

退出条件：首次载入、进入对战和连续抽牌的内存/长帧指标满足预算。

### Phase 7：清理兼容层

- Web 全量启用稳定后删除 Web 路径中的重复 root/control bridge。
- Android、Windows 是否迁移到新适配器另行决策，不作为本项目完成前提。
- 删除已无调用的时间窗去重，仅保留仍服务 legacy 平台的部分。

## 7. 自动化测试架构

### 7.1 测试层级

1. 纯函数契约测试：profile、坐标、序列归属、session 状态机。
2. Godot 节点级 UI 测试：构造真实 Control 树并注入事件。
3. 场景级无头测试：加载真实 `.tscn`、驱动固定牌序和 AI fixture。
4. 浏览器 E2E：真实 Web export，由浏览器自动执行点击、触摸、拖拽、失焦、恢复和断言。
5. 原生回归：Windows 自动启动与输入；Android emulator 通过 ADB 自动安装、启动、点击和截图。

### 7.2 测试控制接口

仅测试构建暴露 `window.__PTCG_TEST__`，提供：

- 查询当前场景、runtime profile、活动 pointer sequence。
- 查询 pending choice、interaction session、overlay 和 AI watchdog。
- 注入固定 deck、seed、牌序和 AI action fixture。
- 等待稳定条件，而不是固定 sleep。
- 导出结构化 UI 树、控件矩形、截图和最后 N 条 runtime log。
- 触发页面 hide/show、blur/focus、pointer cancel 和 resize。

正式 release 不导出测试桥，静态测试必须证明该接口不会进入生产 PCK。

### 7.3 稳定等待条件

自动化禁止使用“等待 2 秒后假定完成”作为主要同步方式。统一等待：

- `scene_ready`
- `layout_stable`：连续两个 frame 的关键矩形相同。
- `interaction_opened(session_id)`
- `interaction_finished(session_id)`
- `visual_queue_idle`
- `ai_idle`
- `game_state_revision >= expected`

每个等待都有硬超时；失败时自动保存 screenshot、UI tree、session、pending choice、action log 和浏览器 console。

### 7.4 核心输入契约

- Touch down/up + synthetic mouse down/up 只产生一次 pressed。
- Touch cancel 不产生 pressed，并清除 candidate。
- 拖动超过阈值只滚动，不激活卡牌或按钮。
- 模态关闭的同一 pointer sequence 不能点击底层控件。
- 下一条新 sequence 可以立即点击，不受旧时间窗误伤。
- 页面 blur 时取消 active sequence；focus 后不会补触发旧点击。
- hybrid 设备从 touch 切到 mouse 后各自序列独立。

### 7.5 玩家反馈场景

为以下场景建立确定性自动化：

- 玩家使用抽三张效果，抽卡展示完成，手牌数和牌库数正确，UI 回到可操作状态。
- 玩家使用博士，弃牌、抽牌和展示完成，旧手牌不重复出现。
- AI 使用需要牌库选择或后续目标选择的道具，prompt 自动完成或 watchdog 安全恢复。
- 抽卡动画被页面 hide/show 中断，恢复后最终状态与不中断时一致。
- Safari 风格 touch cancel 发生在弹窗 confirm 前，不确认选择且可以再次操作。

### 7.6 平台矩阵

| 平台 | 输入 | 布局 | 执行方式 |
| --- | --- | --- | --- |
| Windows native | mouse | landscape/portrait window | 自动启动 + Godot/OS 输入驱动 |
| Android emulator | touch | portrait/landscape | ADB install/start/tap/swipe/screencap/logcat |
| Chromium Web | mouse/touch emulation | wide/phone viewport | browser automation |
| WebKit Web | touch/mouse | iPhone/iPad viewport | browser automation |
| iOS Safari remote runner | touch | Safari/PWA | 可用时无人值守远程 runner |

### 7.7 视觉与布局断言

- 所有可点击控件矩形位于安全 Canvas 内。
- modal overlay 的 z-order 和 mouse filter 高于底层业务控件。
- 关键按钮中心点自动点击后触发正确 signal。
- 竖屏文字、卡牌详情、选择按钮不越界。
- 截图只用于发现视觉差异；业务正确性必须由状态和 signal 断言证明。
- Golden screenshot 只对稳定区域比较，并设置抗锯齿容差；动态背景、粒子和时间文字使用 mask。

### 7.8 性能与资源断言

- Web PCK/WASM 大小设置上限并在 CI 中比较基线。
- 禁止 `raw-sheet`、临时源图和测试资源进入 Web release manifest。
- 记录启动、首场对战、连续抽牌后的 JS heap（可用时）、节点数、纹理数和最长 frame。
- 连续运行多局后资源指标不得单调增长超过预算。

## 8. 发布与回滚

- 功能开关：`web_ui_adapter_v2`，默认先关闭，再对测试环境和小流量版本启用。
- kill switch 只影响 Web adapter，不改变 native 路径。
- Web 启动时只解析一次 adapter：发布 manifest 的 feature 值作为默认，`?web_ui_adapter=legacy|v2` 作为支持排障覆盖；不得在一次 pointer/session 进行中热切换。
- 自动回滚用例必须分别以 `legacy` 与 `v2` 启动同一个正式 Web export，证明关闭开关不需要另一套 Android/Windows 构建。
- 每个 phase 独立提交，结构迁移与行为修复分开。
- 失败时回退到旧 Web 输入入口；runtime profile、诊断和测试可以保留。
- Web 资源瘦身独立提交，避免把输入回归与包体变化混在一起定位。

## 9. 第二轮代码复审结论

以下结论来自对当前代码的逐文件复审，不是对玩家反馈的事后猜测。它们决定了迁移顺序和测试范围。

### 9.1 现有输入所有权不是单入口

非战斗页现在至少存在三种同时生效的入口：

```text
GameManager._input 全局兜底
        |
        +--> 页面自己的 _input / _gui_input
                    |
                    +--> NonBattleTouchBridge.handle_root_touch
                    |
                    +--> 动态 Button/Range/LineEdit 的 gui_input 绑定
```

逐页现状：

| 页面/文件 | 当前入口 | 迁移约束 |
| --- | --- | --- |
| `GameManager.gd:608` | 全局 `_input` 扫描非战斗按钮；检测到 `BattleScene` 后退出 | 保留 Android/Windows legacy 行为；Web v2 启用时不得再扫描 |
| `MainMenu.gd:132` | modal、root bridge、主菜单触摸、吉祥物鼠标；`_gui_input` 又处理一次 modal/触摸 | modal 必须第一优先；移除 Web 的双入口而不是删除页面业务手势 |
| `DeckManager.gd:200` | HUD modal、导入 modal、root bridge | 导入框、粘贴、卡组行滚动必须分别有稳定 intent |
| `Settings.gd:55` | 模型选择、底部操作区、root bridge；模型选项另绑 `gui_input` | Web 剪贴板和 DOM 输入移出场景；native clipboard 不变 |
| `BattleSetup.gd:237` | 启动屏蔽层后依次尝试八类自定义 handler，再走 root bridge | 保留既有优先级；适配器不能绕过启动屏蔽和 deck modal |
| `TournamentDeckSelect.gd:47` | root bridge，动态遮罩另绑 `gui_input` | 统一为 modal owner 后再路由普通控件 |
| `ReplayBrowser.gd:44` | root bridge | 作为首批低风险 Web 迁移页 |

`NonBattleTouchBridge.gd` 通过 node metadata 保存候选、滚动和去重状态，同时递归绑定 Button、Range、LineEdit。它仍是原生移动端的重要兼容层，不应在第一轮被重写；Web v2 应在它之前分流。现有 `180ms` 重复点击和 `220ms` 滚动释放窗口只能保留给 legacy 分支，不能继续成为 Web 正确性的依据。

对战页是另一套独立输入管线：`BattleSceneRuntime.gd:438` 先处理弃牌取消、牌库搜索、弹窗卡牌、弹窗拖动、手牌拖动和竖屏备战区；`BattleCardView.gd`、`BattleDialogController.gd` 与 `BattleDragScrollCoordinator.gd` 又分别接收控件事件。迁移必须把 Web raw event 标记为同一个 `PointerSequence`，但继续沿用这些控制器的业务优先级。

### 9.2 当前时间窗是兼容措施，不是最终所有权模型

代码中仍有多组相互独立的点击抑制窗口：

| 常量 | 当前值 | 用途 |
| --- | ---: | --- |
| `SLOT_FOLLOWUP_CLICK_SUPPRESS_MSEC` | 900ms | 槽位后续点击 |
| `BENCH_PLAY_FOLLOWUP_CLICK_SUPPRESS_MSEC` | 160ms | 放置备战宝可梦后续点击 |
| `MODAL_INPUT_SLOT_SUPPRESS_MSEC` | 250ms | modal 关闭后的槽位回声 |
| `MODAL_ORIGIN_SLOT_ECHO_SUPPRESS_MSEC` | 260ms | modal 原点点击回声 |
| `FIELD_ASSIGNMENT_SOURCE_FOLLOWUP_CHOICE_SUPPRESS_MSEC` | 260ms | 场上分配后续选择 |
| `DIALOG_MODAL_ECHO_SUPPRESS_MSEC` | 250ms | dialog modal 回声 |
| `HAND_DRAG_CLICK_SUPPRESS_MSEC` | 220ms | 手牌/卡牌列表拖动后点击 |

`_finish_modal_input_interaction()` 已有 `_modal_input_generation`，这是正确方向；但它仍会同时设置时间窗口。Web v2 先让 sequence/generation 成为判定依据，待等价测试稳定后再只从 Web 分支移除时间窗。任何阶段都不能直接全局删常量。

### 9.3 玩家反馈中的“卡住”至少有三条不同链路

#### 抽三张与博士后的抽卡展示

`BattleSceneRuntime._on_action_logged()` 会把非开局的 `DRAW_CARD` 动作送入 `BattleDrawRevealController`。当前控制器：

1. 把动作加入 `_draw_reveal_queue` 并设置 `_draw_reveal_active`。
2. 为每张卡创建临时 `BattleCardView`，由 Tween 串行展示。
3. 人类玩家等待 overlay 确认；AI/自动路径等待 `SceneTreeTimer`。
4. 飞向手牌后只依赖 Tween `finished` 调用 `_finish_current_reveal()`。
5. 队列清空后才清状态、刷新手牌、检查交接并再次调度 AI。

目前 overlay 的直接确认代码只接受 `InputEventMouseButton`，移动 Web 依赖 Godot 的 touch-to-mouse emulation。浏览器丢失 release、产生 cancel、页面进入后台或 Tween 不回调时，没有独立于动画的 human session 收口。这是必须补测和改造的高风险链路，但在取得浏览器日志前不能把它宣称为唯一根因。

博士类效果还会先产生手牌弃牌动作再产生抽牌动作，因此测试不能只断言“最后手牌数量正确”，还必须断言弃牌 reveal、抽牌 reveal、队列顺序、旧手牌 instance ID 和最终一次性恢复输入。

#### AI 使用带后续选择的道具

效果选择由 `BattleEffectInteractionController` 写入 `_pending_effect_*`、步骤数组和 `__interaction_generation`。`reset_effect_interaction()` 会清理字段、隐藏 field/dialog 并经 `_finish_modal_input_interaction()` 收口。这里已有 generation，但 session 的 owner、进展时间和统一终态仍分散在多个字段里。

#### AI 看门狗

`BattleAIWatchdog.gd` 每 `0.5s` 检查一次，当前阈值为软恢复 `3s`、动画 blocker `6s`、硬恢复 `12s`。它可以结束 AI pause、coin、draw reveal，或让 LLM 回退规则；但它只在 VS_AI live 且 AI 拥有下一决策（或 AI action pause）时监控，并明确不处理人类拥有的 prompt。

因此看门狗是最后一道 AI 兜底，不是 Web UI session 的主完成机制。后续只能让它观测 session ID/状态并调用 session 的幂等完成入口，不能让它直接猜测人类选择或掩盖浏览器事件丢失。

### 9.4 浏览器生命周期目前没有进入 Godot 状态机

`web/ptcg_web_shell.html` 已处理加载、缓存、安全区、PWA 和音频解锁，但当前没有注册 `visibilitychange`、`pagehide/pageshow`、`pointercancel/touchcancel`、`unhandledrejection`、`window.onerror` 或 `visualViewport`。因此 Godot 侧无法区分“用户尚未操作”和“浏览器已取消本次手势/暂停页面”。

现有 `WebTextInputBridge.gd` 用静态 callback host 与 callback 数组保持 JS 回调，`Settings.gd` 还直接创建 Web 剪贴板 callback。生命周期桥必须提供成对的 install/uninstall 与 generation 校验；Settings 中的直接 `JavaScriptBridge` 调用要迁到 Web 平台服务。`DeckSharePlatformAdapter.gd` 已经证明平台 JS 可以被隔离在 adapter 内，可作为结构先例。

### 9.5 平台判断需要分类迁移，不能机械替换

UI 行为中散落的 `mobile/web` 判断主要位于 `GameManager`、`NonBattleTouchBridge`、`WebTextInputBridge`、`MainMenu`、`DeckManager`、`Settings`、`BattleSetup`、`TournamentDeckSelect`、`ReplayBrowser`、`DeckEditor`、`HudTheme` 和两个 Battle runtime 文件。这些应逐步改读 `UiRuntimeProfile`。

`CardImageCacheService`、`DeckImporter`、`CardImageDownloader`、`UserVisitClient` 与 `DeckSharePlatformAdapter` 的平台分支属于缓存、HTTP 或分享能力，不属于输入重构。第一阶段只为它们补 profile 等价测试，不强行搬迁，避免扩大行为变化。

### 9.6 Web 资源风险必须单独治理

当前 Web preset 使用 `export_filter="all_resources"`、`variant/thread_support=false`、`vram_texture_compression/for_mobile=false`。仓库内 `assets` 约 `122.42MB`、`data` 约 `94.89MB`；已存在的旧 Web 导出样本 PCK 约 `192.67～246.12MB`，WASM 约 `35.94MB`。多个 `raw-sheet.png` 单张接近 `2MB`。

这些数字不能单独证明 Safari 退出原因，但足以要求独立的包体/峰值内存预算。资源瘦身不得与输入修复放在同一提交或用例中，否则崩溃与交互回归无法归因。

### 9.7 现有测试基础可复用，但缺少真实浏览器层

当前测试体系有以下能力：

- `scripts/tools/run_godot_tests.ps1` 支持 functional、AI 和单文件 focused runner，并隔离 `user://` 与日志目录。
- `TestSuiteCatalog.gd` 递归发现 `tests/**/test_*.gd`；新 UI 套件无需手工登记即可进入 functional 组。
- `SharedSuiteRunner.gd` 可以等待异步 test、捕获 GDScript 错误，并在每个用例后清理新建 root/orphan node。
- 现有测试已大量构造真实场景/Control，使用 `Viewport.push_input()` 注入 `InputEventScreenTouch` 与 Mouse 事件。
- `probe_portrait_library_search_board.gd` 和 landscape probe 已能保存 viewport PNG，可提取为通用失败取证工具。

目前仓库没有 Playwright、Selenium 或 Puppeteer 配置，也没有把真实 Web export 拉起后操作 Canvas 的 E2E runner。现有“Web 测试”主要是强制 feature flags、合成 Godot 事件与静态检查 HTML/preset，不能证明浏览器的合成鼠标、失焦、页面恢复和 WebKit 行为。

### 9.8 2026-07-22 复审基线执行结果

本次文档复审实际调用了现有 focused runner：

| Suite | 结果 | 结论 |
| --- | --- | --- |
| `tests/test_game_manager.gd` | 33/33 通过 | 当前 native/Web 判断、orientation 与 BattleScene 输入让权契约可作为迁移基线 |
| `tests/test_ai_watchdog.gd` | 7/7 通过 | 当前 3s/6s/12s 恢复层级和 human prompt 隔离已被测试保护 |
| `tests/test_export_presets.gd` | 15/16 通过 | 唯一失败是 shell 源文件使用 CRLF，而断言写死 `"\n\t\t"`；实际 `unlockAudioFromGesture()` 后紧接 `setStage(TEXT_LOADING_DOWNLOAD)`，属于换行敏感的测试缺陷，不是这两行的产品行为失败 |

运行日志还显示 `UTEST/001.png.bin` 缺失 warning，以及 focused suite 退出时的 ObjectDB/resource leak `ERROR`；前两个通过 suite 的进程退出码仍为 0。说明现有 `ScriptErrorGate` 能捕获 GDScript script error，但不能单靠退出码覆盖全部引擎错误。Phase 0 必须：

- 让静态 HTML 断言先统一 CRLF/LF，或解析函数调用顺序，不再匹配整段缩进文本。
- 为自动化总门禁增加日志 error scanner；未在有理由、带到期时间的 allowlist 中的 `ERROR` 必须让汇总脚本失败。
- warning 单独进入 `summary.json`，固定测试素材缺失不能长期用宽泛 warning allowlist 掩盖。
- 资源泄漏基线先记录 owner/数量；新代码不得增加，Phase 5/6 完成时目标为相关 UI 套件零泄漏。

## 10. 最终文件边界与职责

### 10.1 新增运行时文件

| 文件 | 单一职责 | 禁止事项 |
| --- | --- | --- |
| `scripts/ui/runtime/UiRuntimeProfile.gd` | 不可变能力数据 | 不访问场景、不改变 ProjectSettings |
| `scripts/ui/runtime/UiRuntimeProfileResolver.gd` | 从 OS/DisplayServer/显式测试 flags 解析 profile | 不处理业务输入 |
| `scripts/ui/input/PointerSequence.gd` | 一次物理手势的身份、owner、终态 | 不直接触发按钮或规则 |
| `scripts/ui/input/PlatformInputAdapter.gd` | 输入适配接口与统一 intent signal | 不知道卡牌规则 |
| `scripts/ui/input/WebInputAdapter.gd` | Web mouse/touch 去重、cancel、pointer owner | 不被 Android/Windows 默认启用 |
| `scripts/ui/input/NativeInputPassthroughAdapter.gd` | 包装现有 native 路径，初期完全透传 | 不趁迁移改变 legacy 阈值 |
| `scripts/ui/web/BrowserLifecycleBridge.gd` | JS 生命周期安装、卸载、转发、错误记录 | 不直接提交业务动作 |
| `scripts/ui/web/WebPlatformServices.gd` | DOM text、clipboard 等 Web 能力门面 | 场景不得再直调 JavaScriptBridge |
| `scripts/ui/web/WebPresentationPolicy.gd` | Web 表现预算与降级档 | 不修改规则和 AI 合法动作 |
| `scripts/ui/interactions/UiInteractionSession.gd` | owner/generation/progress/终态与幂等收口 | 超时不得猜测玩家选择 |
| `scripts/ui/interactions/UiInteractionSessionRegistry.gd` | 按 viewport 管理当前 blocking session | 不同时允许两个顶层 blocker |

### 10.2 修改现有文件

| 文件 | 计划改动 | 必须保留的行为 |
| --- | --- | --- |
| `scripts/autoload/GameManager.gd` | 创建 profile、选择 adapter、Web v2 时关闭全局 Web 扫描 | BattleScene 存在时全局 bridge 退出；native orientation 行为不变 |
| `scripts/ui/non_battle/NonBattleTouchBridge.gd` | 接受 profile/adapter 分流；保留 legacy | Android/Windows 当前输入轨迹与时间窗 |
| `scripts/ui/non_battle/WebTextInputBridge.gd` | 迁入 `WebPlatformServices` 或成为其私有实现 | IME/提交/取消语义不变 |
| `scenes/main_menu/MainMenu.gd` | root 只消费 adapter intent | modal 优先级、吉祥物手势 |
| `scenes/deck_manager/DeckManager.gd` | 导入 modal 与列表滚动改为明确 owner | 导入、重命名、删除、编辑逻辑 |
| `scenes/settings/Settings.gd` | 剪贴板与文本请求改调平台服务 | native clipboard 与模型选择逻辑 |
| `scenes/battle_setup/BattleSetup.gd` | 保留八类 handler 顺序，输入来自 adapter | startup shield、deck modal、竖屏 footer |
| `scenes/tournament/TournamentDeckSelect.gd` | modal/root 归一化 | 卡组选择结果 |
| `scenes/replay_browser/ReplayBrowser.gd` | 首批接入 Web adapter | 回放列表/导航 |
| `scenes/battle/BattleSceneRuntime.gd` | Web raw event 入口、session 观测、生命周期恢复 | 控制器调用顺序、规则状态机 |
| `scenes/battle/BattleCardView.gd` | legacy event 包装为 pointer intent | 点击、长按、拖动信号 |
| `scripts/ui/battle/BattleDialogController.gd` | modal sequence owner 与 generation 校验 | 现有选择/取消业务接口 |
| `scripts/ui/battle/interactions/BattleDragScrollCoordinator.gd` | 用 sequence 结束拖动与抑制回声 | native 的 220ms legacy 路径 |
| `scripts/ui/battle/BattleDrawRevealController.gd` | draw session、touch confirm、Tween/节点释放硬收口 | 规则已结算事实、展示顺序、隐私 |
| `scripts/ui/battle/ai/BattleAIWatchdog.gd` | 指纹加入 session/generation/visual queue；只调用统一恢复接口 | 人类 prompt 永不自动选择 |
| `web/ptcg_web_shell.html` | 生命周期与错误桥 | ASCII-safe、自定义加载、缓存升级、音频解锁；不包含测试 API |
| `export_presets.cfg` | 独立 `Web UI E2E` preset、Web 资源 filter | 正式 Web preset 不含测试桥 |
| `scripts/tools/export_web_release.ps1` | 可选 E2E preset/临时目录，增加预算报告 | 正式版本 manifest 和版本目录布局 |

### 10.3 明确不在首轮修改的文件

`CardImageCacheService.gd`、`DeckImporter.gd`、`CardImageDownloader.gd`、`UserVisitClient.gd`、`DeckSharePlatformAdapter.gd` 首轮只加等价测试或复用其 adapter 模式，不改网络、缓存和分享行为。卡牌效果、AI deck strategy、GameStateMachine 不在本项目范围内。

## 11. 精细化无人值守 UI 自动化方案

### 11.1 总体原则

自动化必须验证“真实输入到真实业务状态”的整条链路，而不是调用按钮 callback 冒充点击。所有关键用例同时断言：

1. 输入轨迹：sequence 数量、source、owner、cancel/completed 终态。
2. UI 轨迹：modal/overlay 可见性、控件矩形、焦点与拖动状态。
3. 业务轨迹：action log 增量、牌区 instance ID、pending choice 和 turn owner。
4. 恢复轨迹：session 归零、visual queue idle、AI 可继续调度。

截图是证据而不是唯一 oracle。禁止以“截图看起来对”代替状态断言，也禁止用固定坐标点击动态卡牌。

### 11.2 稳定定位与测试桥协议

Godot Web 在浏览器中只有一个 Canvas，Playwright 无法直接定位内部 Button。测试构建必须提供稳定语义定位：

```text
scene/main_menu/start
scene/deck_manager/create
battle/hand/card/{instance_id}
battle/dialog/option/{semantic_id}
battle/draw_reveal/overlay
battle/field/{player}/{slot_id}
```

测试桥采用异步 request/snapshot 协议，而不是依赖 JS callback 的同步返回值：

```text
window.__PTCG_TEST__.request(command, payload) -> request_id
window.__PTCG_TEST__.snapshot(request_id) -> pending | result | error
window.__PTCG_TEST__.query(test_id) -> visible rect + enabled + generation
window.__PTCG_TEST__.state() -> scene/profile/session/pending/action revision
```

实现边界：

- 新增单独的 `Web UI E2E` export preset，设置自定义 feature `web_ui_e2e`。
- Web 运行时测试桥和专用 shell 放在 `web/e2e/`；正式 Web preset 新增 `web/e2e/**` 排除项，E2E preset 才允许打包该目录。普通 Godot 测试仍放在 `tests/**` 并继续从正式包排除。
- 生产运行时代码只允许在检测到 `web_ui_e2e` 时按字符串路径加载 `web/e2e/WebUiE2EBridge.gd`；正式 preset 的静态测试必须断言没有该 feature、没有 `__PTCG_TEST__` shell hook、manifest 不含 `web/e2e/**`。
- 动态 Control 注册语义 ID；测试只查询 rect 后点击中心，不保存跨 layout 的像素坐标。
- 每个 request 带 generation；场景切换后旧 request 自动变成 cancelled。

### 11.3 浏览器 E2E 工具与目录

新增隔离工具目录，不把 Node 依赖放进游戏运行时：

```text
tools/web_ui_test/package.json
tools/web_ui_test/package-lock.json
tools/web_ui_test/playwright.config.ts
tools/web_ui_test/server.mjs
tools/web_ui_test/helpers/godot_canvas.ts
tools/web_ui_test/specs/non_battle_input.spec.ts
tools/web_ui_test/specs/battle_draw_reveal.spec.ts
tools/web_ui_test/specs/battle_modal_input.spec.ts
tools/web_ui_test/specs/browser_lifecycle.spec.ts
tools/web_ui_test/specs/web_resource_budget.spec.ts
web/e2e/WebUiE2EBridge.gd
web/e2e/ptcg_web_e2e_shell.html
scripts/tools/run_web_ui_e2e.ps1
```

Playwright project 至少包含：

| project | engine | viewport/input | 目的 |
| --- | --- | --- | --- |
| `chromium-desktop` | Chromium | 1440×900 mouse | 桌面 Web 基线 |
| `chromium-android` | Chromium | 390×844 touch | Android 浏览器合成鼠标与竖屏 |
| `webkit-iphone` | WebKit | 390×844 touch | iPhone 风格 touch/cancel/viewport |
| `webkit-ipad` | WebKit | 820×1180 touch | tablet safe area/modal |

Playwright WebKit 不是等价的真机 iOS Safari。它是提交门禁；如果要声明“真机 Safari 已验证”，CI 还必须接入真实 iOS remote runner。没有 runner 时报告 `NOT_VERIFIED_REAL_IOS`，不能降级成人工点击后标绿。

### 11.4 条件等待、超时与失败产物

禁止在业务用例里使用 `waitForTimeout()` 作为同步依据。辅助层统一轮询以下条件：

- `scene == expected`
- `layout_revision` 连续两帧不变
- `interaction.session_id == expected && state == active`
- `interaction.state in [completed, cancelled, timed_out]`
- `visual_queue_length == 0`
- `ai_running == false && ai_step_scheduled == false`
- `game_state_revision >= expected`

建议预算：普通 UI 意图 `2s`，单段视觉序列 `5s`，完整效果交互 `10s`，场景加载 `30s`。超时不自动重试业务动作；测试立即失败并保存：

```text
.tmp/web_ui_e2e/<run_id>/<project>/<case>/
  screenshot.png
  state.json
  ui_tree.json
  pointer_sequences.json
  interaction_sessions.json
  action_log_tail.json
  runtime_log_tail.txt
  browser_console.txt
  trace.zip
  video.webm
```

CI 默认 `retries=0`，避免重试掩盖竞争条件。只允许基础设施层在“浏览器未启动/端口占用”时重启一次，并在报告中单独标记。

Godot/Windows/Android wrapper 还必须扫描完整日志，而不是只信进程退出码。默认遇到 `SCRIPT ERROR`、`ERROR:`、崩溃、无结果尾标或测试素材缺失即失败；临时 allowlist 必须精确到 message pattern、owner、原因和失效日期，禁止 `ERROR:*` 或 `WARNING:*` 级别的宽泛放行。

### 11.5 必须新增的 Godot 测试文件

| 测试文件 | 首批 RED 用例 | GREEN 条件 |
| --- | --- | --- |
| `tests/test_ui_runtime_profile.gd` | 同一 `is_mobile` 无法区分布局、输入和性能 | 预设矩阵解析稳定；旧 native helper 输出逐项等价 |
| `tests/test_pointer_sequence.gd` | touch 后 synthetic mouse 产生两个 intent；cancel 后仍 click | 每个物理序列最多一个 intent；cancel 永不提交 |
| `tests/test_web_input_adapter.gd` | blur/release 丢失留下 pressed/drag | 所有 active sequence 在 cancel/blur 后终止且 owner 清空 |
| `tests/test_ui_interaction_session.gd` | 旧 timer/Tween callback 完成新 generation | stale callback 无效；每个 session 恰好一个终态 |
| `tests/test_browser_lifecycle_bridge.gd` | install 两次重复 callback；free 后回调仍命中 | install/uninstall 幂等，generation 隔离 |
| `tests/test_web_platform_services.gd` | Settings 直接持有 clipboard JS callback | text/clipboard 只经服务；native 分支输出不变 |
| `tests/test_draw_reveal_session.gd` | ScreenTouch 无法确认；Tween 不 finished 永久 active | touch/mouse 都可确认；cancel/timeout/节点释放恰好收口一次 |
| `tests/test_battle_web_pointer_ownership.gd` | modal 关闭事件落到底层 slot/hand | 同一 sequence 只被 modal 消费；下一 sequence 立即可用 |
| `tests/test_ai_watchdog.gd` | watchdog 指纹看不到 session 进展 | 只恢复 AI-owned stalled session；human session 不受影响 |
| `tests/test_web_production_excludes_test_bridge.gd` | E2E feature/脚本误入正式 preset | 正式 manifest、shell、preset 均无测试桥 |
| `tests/test_web_resource_budget.gd` | PCK 或 raw-sheet 无预算增长 | manifest 类型/大小预算自动通过 |

这些测试全部由现有 `FocusedSuiteRunner` 或 functional runner 执行；场景/viewport 截图能力从现有 portrait/landscape library probes 提取为 `tests/helpers/UiAutomationHarness.gd`，不再复制保存与失败清理代码。

每个阶段还必须固定回跑以下已有套件，不能因为新测试通过就跳过：

| 现有套件 | 保护的既有行为 |
| --- | --- |
| `tests/test_game_manager.gd` | Web/native 识别、orientation、全局 bridge 在 BattleScene 中让出所有权 |
| `tests/test_non_battle_portrait_layout.gd` | 主菜单、设置、卡组中心、对战设置的 Android touch 与竖屏布局 |
| `tests/test_deck_manager.gd` | 卡组行操作、modal、滚动与 Web/native 图片变体 |
| `tests/test_battle_setup_layout.gd` | deck picker、AI 选项、启动屏蔽与竖屏操作区 |
| `tests/test_battle_dialog_controller.gd` | 牌库搜索、选择、取消与移动端 dialog |
| `tests/test_battle_modal_end_turn_input_isolation.gd` | modal 输入不会穿透触发结束回合或底层竞技场 |
| `tests/test_battle_ui_handover_regression.gd` | 交接、能量/备战后续点击抑制 |
| `tests/test_battle_ui_features_part2.gd`、`part4.gd`、`part5.gd` | Android touch、旋转坐标、奖赏卡与 action HUD |
| `tests/test_battle_portrait_layout.gd` | Android/Web portrait 的 popup、HUD、可视区域与旋转 |
| `tests/test_ai_watchdog.gd` | AI soft/blocker/hard recovery 与 human prompt 隔离 |
| `tests/test_export_presets.gd`、`tests/test_web_release_layout.gd` | Web preset、custom shell、正式发布目录和 manifest |

### 11.6 输入契约用例明细

| ID | 自动操作 | 必须断言 |
| --- | --- | --- |
| INP-001 | touch down/up，随后同坐标 synthetic mouse down/up | 一个 sequence、一个 pressed、一个 action log 增量 |
| INP-002 | touch down 后 `touchcancel` | 零 pressed、sequence cancelled、无 candidate/drag |
| INP-003 | mouse down 后 window blur，再 mouse up/focus | 零业务动作，focus 后新 click 正常 |
| INP-004 | 在 ScrollContainer 拖动超过阈值并 release | scroll 值改变，卡牌/按钮不激活 |
| INP-005 | modal confirm 后同序列 release 落在底层 slot | modal 完成一次，slot 零调用 |
| INP-006 | modal 关闭后立即发起全新 sequence 点击 slot | 不受旧 250ms 窗口误伤，slot 一次调用 |
| INP-007 | hybrid profile 先 touch 再真实 mouse | 两个独立序列，各一次预期 intent |
| INP-008 | 旋转/resize 后用语义 ID 查询并点击中心 | 命中同一控件，坐标往返误差不超过 1px |
| INP-009 | 页面切换过程中发出旧场景 release | 旧 generation 丢弃，新场景零误触 |
| INP-010 | `MOUSE_FILTER_IGNORE` 控件覆盖按钮 | ignore 层不成为 owner，合法按钮仍按 Godot 层级命中 |

### 11.7 玩家反馈回归用例明细

| ID | Fixture 与自动操作 | 规则断言 | UI/恢复断言 |
| --- | --- | --- | --- |
| FLOW-001 抽三张 | 固定牌库，玩家触发一次 draw-3，等待整批展示完成后确认 | 手牌 +3、牌库 -3、抽到的三个 instance ID 唯一且顺序正确 | reveal queue 空、overlay 隐藏、session completed、下一手牌可点击 |
| FLOW-002 博士 | 固定含博士的起始手牌和至少 7 张牌库，自动点击博士并确认展示 | 动作前手牌 instance ID 最终都在弃牌区；新手牌为预期 7 张；trainer 只结算一次 | discard/draw 展示顺序正确，无重复旧卡，最终无 blocker |
| FLOW-003 AI 道具后续选择 | 固定 AI 动作和合法目标，AI 使用需要牌库/场上后续选择的道具 | action log 只有一次 trainer resolve，目标与牌区变化符合 fixture | prompt 不暴露给玩家；session completed；AI 继续或正常结束回合 |
| FLOW-004 抽卡中 hide/show | 在 reveal hold 与 fly 两个阶段分别触发 visibility/pagehide/pageshow | 最终牌区与不中断基线完全相同，不重复抽牌 | 旧 Tween callback 无效，session 收口，页面恢复后可操作 |
| FLOW-005 弹窗 touchcancel | option touch down 后 cancel，再发新 touch 选择 | cancel 阶段无效果提交；新序列只提交一次 | modal 保持可用，owner/generation 正确 |
| FLOW-006 AI watchdog | 冻结 AI-owned reveal/session 的视觉完成回调 | 不重复规则动作，不改变已结算牌区 | 6s 路径经统一接口收口；human-owned 等价场景保持 active |
| FLOW-007 连续 20 次抽牌展示 | 固定 action stream 自动确认 | 每个 action 恰好一次，最终牌数守恒 | 无残留 card view/timer/session，节点和纹理回到预算 |

所有 fixture 使用真实 `GameStateMachine` 与真实场景；只固定随机种子、牌序和 AI action，不 stub 掉被验证的输入、效果交互或展示控制器。

### 11.8 生命周期用例明细

| ID | 时机 | 自动事件 | 断言 |
| --- | --- | --- | --- |
| LIFE-001 | 普通页面按下按钮后 | blur/focus | 旧 click 不补发，新 click 可用 |
| LIFE-002 | 手牌拖动中 | pointercancel | drag capture、候选卡和滚动 suppress 状态清空 |
| LIFE-003 | DOM LineEdit 打开时 | pagehide/pageshow | DOM 节点安全关闭或恢复，不重复 commit |
| LIFE-004 | modal active | visibility hidden/visible | modal 业务状态保留，transient pointer 清空 |
| LIFE-005 | Tween active | pagehide 超过 timeout 后 pageshow | 视觉安全快进/取消，规则状态不变，完成回调一次 |
| LIFE-006 | 场景切换后 | 派发旧 JS callback | 旧 generation 被忽略，无 freed instance 错误 |
| LIFE-007 | JS promise reject | `unhandledrejection` | console/runtime 结构化日志包含阶段、session 和 stack，不静默卡住 |
| LIFE-008 | iPhone viewport | visual viewport resize/orientation | safe Canvas 内所有关键控件仍可点击，无横向溢出 |

### 11.9 Native 自动回归，不依赖人工点击

Windows 与 Android 不接入 Web adapter，但必须每阶段自动证明行为未变：

- Godot headless：对 legacy mouse/touch event trace 做快照比较，断言 signal 次数、owner、action log 和最终 UI 状态。
- Windows native smoke：用专用 `UiScenarioRunner.gd` 非 headless 启动真实场景，由 runner 注入输入并保存截图/日志，进程退出码即结果。
- Android emulator：脚本自动导出、安装、启动测试 APK；测试场景在 layout stable 后把语义控件的物理矩形写入 logcat，脚本解析中心点后用 `adb shell input tap/swipe` 驱动，再拉取 screenshot 与 JSON 结果。
- Android 脚本不得使用永久硬编码坐标；旋转后必须重新查询矩形。
- 任一平台失败自动收集 Godot log、Windows 截图或 Android logcat/screencap，并非交给人手工复点。

目标新增：

```text
tests/UiScenarioRunner.gd
tests/helpers/UiAutomationHarness.gd
tests/helpers/UiContractSnapshot.gd
scripts/tools/run_windows_ui_smoke.ps1
scripts/tools/run_android_ui_e2e.ps1
scripts/tools/run_ui_platform_validation.ps1
```

## 12. 分阶段 TDD 执行与提交门槛

| Phase | 先写并确认 RED | 最小实现 | GREEN 门槛 | 独立提交边界 |
| --- | --- | --- | --- | --- |
| 0 诊断 | 玩家反馈 fixture 无法区分等待 UI/AI/动画 | 结构化事件与状态快照，不改输入 | 重放能指出 blocker 类型；native baseline 产物冻结 | 仅诊断、fixture、baseline |
| 1 Profile | profile 矩阵/legacy parity RED | resolver + immutable profile | 全 functional 通过；旧 helper 逐项等价 | 仅能力层，不改场景路由 |
| 2 Lifecycle | LIFE-001～007 RED | shell bridge + Godot cancel/错误入口 | Chromium/WebKit 生命周期套件通过；native diff 为空 | 不包含非战斗重路由 |
| 3 非战斗 | INP-001～010 在主菜单/回放页先 RED | Web adapter，逐页启用 flag | 目标页 Web E2E 全绿；Android/Windows baseline 不变 | 每页单独提交，可单页回滚 |
| 4 对战输入 | modal/drag/card sequence RED | 只替换 raw event 归属，保留业务 controller | battle input focused + 浏览器 modal/drag E2E + native parity | 不改 draw/effect session |
| 5 Session | FLOW-001～006 与 stale callback RED | interaction registry；先 draw，再 effect，再 AI fallback | 所有 blocker 有终态；规则终态与迁移前一致 | 每类 session 单独提交 |
| 6 资源 | 包体/节点/纹理预算 RED | export filter、压缩和 Web 表现 policy | 包体不超预算；20 次连续展示无单调泄漏 | 与任何输入改动分离 |
| 7 清理 | 静态审计发现 Web 仍走重复 root/control bridge | 移除仅 Web 的兼容分支 | 全矩阵、生产排除测试桥、kill switch 回滚演练通过 | 最后清理提交 |

每个 Phase 的固定命令顺序：

```powershell
# 当前已存在：单文件 RED/GREEN 与全量 functional
powershell -ExecutionPolicy Bypass -File scripts/tools/run_godot_tests.ps1 `
  -Runner focused -SuiteScript res://tests/test_<phase>.gd
powershell -ExecutionPolicy Bypass -File scripts/tools/run_godot_tests.ps1 -Runner functional

# 计划新增：真实浏览器、Windows、Android 与汇总门禁
powershell -ExecutionPolicy Bypass -File scripts/tools/run_web_ui_e2e.ps1
powershell -ExecutionPolicy Bypass -File scripts/tools/run_windows_ui_smoke.ps1
powershell -ExecutionPolicy Bypass -File scripts/tools/run_android_ui_e2e.ps1
powershell -ExecutionPolicy Bypass -File scripts/tools/run_ui_platform_validation.ps1
```

`run_ui_platform_validation.ps1` 最终必须生成机器可读 `summary.json`，包含每个平台/用例的 passed、failed、not_verified、artifact_path 与耗时，并在任一必需门禁失败时返回非零退出码。

## 13. 量化验收预算

首个实现提交先采集 Phase 0 基线，再冻结正式数字；在基线前先采用以下保守上限：

| 指标 | 临时门槛 |
| --- | --- |
| 单物理手势业务动作数 | `<= 1` |
| active blocking session | `<= 1` |
| session 无进展硬超时 | 纯展示安全快进；可取消选择合法取消；强制人类选择重建 UI 但保留 pending choice；不得代选 |
| stale callback 造成的状态变更 | `0` |
| modal 同序列底层点击 | `0` |
| 页面恢复后的残留 pointer/drag | `0` |
| FLOW-007 后临时 BattleCardView | `0` |
| FLOW-007 后 active Tween/session/timer 引用 | `0` |
| Web E2E 业务重试 | `0` |
| 正式 Web 包中的 test bridge 文件 | `0` |
| native 规则终态/动作日志差异 | `0` |

PCK、WASM、JS heap、节点峰值、纹理解码峰值以 Phase 0 在同一版本/同一导出配置下采集的 p50/p95 为基线。Phase 6 的默认门槛为“不得比基线增长，目标至少下降 15% PCK 或证明所有剩余资源均被运行时引用”；不可拿旧版本不同导出目录的大小直接作为通过依据。

## 14. 完成定义

只有同时满足以下条件才算完成：

- Web 新路径只通过 `web_ui_adapter_v2` 激活，kill switch 已自动演练。
- Chromium desktop/mobile 与 WebKit iPhone/iPad 项目全部通过。
- Windows native 和 Android emulator 无规则终态、signal 次数或关键布局回归。
- FLOW-001～007、INP-001～010、LIFE-001～008 全部无人值守通过。
- 正式 Web export 不含测试桥，manifest/包体/资源预算通过。
- 每个失败路径都自动产生可诊断产物，不要求开发者先人工复点才能知道卡在哪里。
- 真实 iOS runner 若未接入，报告必须明确保留 `NOT_VERIFIED_REAL_IOS`；不得把 Playwright WebKit 结果写成真机 Safari 已验证。
- 未修改卡牌规则、AI 策略和 Android/Windows legacy 行为；如发现确需跨边界修改，另开设计与提交，不夹带在本改造中。

## 15. 实际落地架构

### 15.1 运行时能力边界

本轮新增 `UiRuntimeProfile` 与 `UiRuntimeProfileResolver`，由 `GameManager` 持有当前能力快照。快照把以下维度拆开：

- 宿主：`native`、`web`、`headless`。
- 原生系统：Windows、Android、iOS、macOS、unknown。
- 指针：mouse、touch、hybrid。
- 布局：compact portrait、compact landscape、wide。
- DOM 文本输入、pointer cancel、后台挂起、性能档和测试档能力。

浏览器 viewport 变化会重新解析快照；Android/Windows 的 orientation 与窗口尺寸逻辑仍走原来的 native 分支。`WebUiFeatureGate` 只在 Web runtime 返回 v2，非 Web 即使收到测试覆盖值也不会切换平台路径。

实际开关约定：

- 默认 Web 模式为 `v2`。
- `?web_ui_adapter=legacy` 是运行时回滚开关。
- `?web_ui_adapter=v2` 可显式确认新路径。
- 一次页面生命周期只解析一次，避免手势进行中热切换。

### 15.2 输入适配与所有权

`PointerSequence` 保存 sequence ID、pointer ID、来源、起点、当前位置、owner、消费 intent、终态与取消原因。`WebInputAdapter` 管理活动 touch/mouse sequence，并使用“最近完成的真实 touch 序列 + 距离/年龄”识别浏览器合成 mouse 回声。

实际接入方式刻意保持窄边界：

- 非战斗页面：`NonBattleTouchBridge` 在 Web v2 下先经过 `WebInputAdapter`；真实 mouse 仍交给 Godot Control，touch 继续复用原按钮、Range、LineEdit 和滚动业务处理。Android/Windows 不进入此 Web 分支。
- 全局兜底：`GameManager._input()` 在 Web v2 下停止扫描非战斗按钮，避免页面桥与全局桥双重触发；BattleScene 存在时仍无条件让出所有权。
- 对战页面：`BattleSceneRuntime` 只在 Web v2 下建立/取消 pointer ownership 和抑制合成回声，不改变既有 modal、手牌拖动、卡牌、场上槽位和 HUD 的业务优先级。
- blur、pagehide、visibility hidden、pointercancel、touchcancel 会统一清除非战斗候选、DOM 输入、对战拖动和活动 pointer。
- 取消后的迟到 release 最多被吞掉一次；任何新的 press 会立即解除该保护，避免 1.5 秒保护窗误伤新手势。

这里仍保留 legacy 的 180～900ms 局部抑制常量，因为它们继续服务 Android/Windows 和未迁移控件；Web v2 的顶层所有权不依赖这些窗口判断同一手势。

### 15.3 浏览器生命周期与平台服务

`BrowserLifecycleBridge` 只在 Web 安装 JS listener，并通过 generation 防止旧 callback 命中新实例。它处理：

- visibility、pagehide/pageshow、blur/focus；
- pointercancel、touchcancel；
- window、orientation、visualViewport resize/scroll；
- `window.error` 与 `unhandledrejection`。

自定义 shell 在 Godot 初始化前先建立最多 100 条的早期事件队列；正式 bridge 安装后接管 listener、排空队列并卸载早期 bridge。运行时错误统一输出 `WEB_RUNTIME_ERROR` 结构化日志。

`WebPlatformServices` 接管 Settings 的 Web 剪贴板读取和 JS callback 生命周期。`WebTextInputBridge.cancel_active()` 被纳入生命周期清理；场景退出时 callback 与 DOM 节点都能释放。业务场景不再直接创建剪贴板 JS callback。

### 15.4 交互会话与看门狗

`UiInteractionSession`、`UiInteractionSessionRegistry` 和 `UiInteractionWatchdog` 提供：

- 单活动 session、稳定 ID 与递增 generation；
- active/completed/cancelled/timed_out 四态；
- opened/progress/finished 时间；
- completion policy 与 owner；
- stale callback 拒绝和幂等终止；
- 250ms 轮询的 UI watchdog。

首轮接入聚焦玩家反馈风险最高的两条链路：

1. `BattleDrawRevealController`：每次 reveal 使用独立 generation；mouse/touch 都可确认；旧 Tween/timer 不能完成新 reveal；8 秒无进展时只安全收口展示，不重复抽牌或弃牌规则动作。
2. `BattleEffectInteractionController`：每一步根据 chooser 标记 human/AI owner；human 强制选择超时后重建原提示且不代选；AI-owned step 使用既有 AI fallback，12 秒/15 秒预算与业务选择分离。

旧 `_draw_reveal_*` 与 `_pending_effect_*` 字段继续作为兼容镜像，既有 AI 调度和 GameStateMachine 没有被 session 替代。场景退出会 invalidate registry 并释放 watchdog。

实现后复审发现，测试用 BattleScene 替身创建的 Panel 默认可见，但真实场景这些 modal 初始隐藏；这会让 `_discard_overlay.visible` 错误阻塞所有 AI。修复方式是让 `_setup_ai_for_tests()` 和共享测试替身匹配真实场景初态，而不是放宽正式 `_is_ui_blocking_ai()`。

### 15.5 构建与资源隔离

正式 Web preset 与 `Web UI E2E` preset 分离：

- 正式 Web 排除 `web/e2e/**`，没有 `web_ui_e2e` feature。
- E2E preset 增加 `web_ui_e2e` feature，并允许按字符串路径加载 `WebUiE2EBridge.gd`。
- 两者都排除 tests、docs、临时目录、output 产物，以及 ready VFX 的 raw sheet、charge 单帧、GIF、prompt 和 pipeline metadata。
- `tests/web_e2e/.gdignore` 阻止 Godot 扫描 Node 依赖。

`WebUiE2EBridge` 是只读语义桥：可查询当前 scene、runtime profile、活动 pointer、interaction session、pending choice、reveal 状态和可见 Control 矩形。它不直接触发按钮、不调用业务 callback；Playwright 查询矩形后仍通过浏览器 mouse/touch 点击真实 Canvas。

## 16. 实现后代码复审结论

### 16.1 已确认的隔离保证

| 检查项 | 代码结论 |
| --- | --- |
| Web JS 是否散落进业务场景 | 生命周期集中在 `BrowserLifecycleBridge`，剪贴板集中在 `WebPlatformServices`；Settings 不再拥有 JS callback |
| Native 是否误入 Web v2 | feature gate 先校验 `profile.is_web()`；native orientation、窗口和触摸桥路径保持原逻辑 |
| 对战适配是否改变业务优先级 | v2 入口位于 `BattleSceneRuntime._input()` 最前，仅吞掉明确的合成/孤儿事件，原处理顺序未重排 |
| 动画是否能重复结算规则 | reveal watchdog 只调用展示收口；规则动作仍先由 GameStateMachine 结算 |
| stale callback 是否能结束新会话 | draw/effect 都校验 generation；registry 终止也校验 session ID + generation |
| human prompt 是否被 watchdog 代选 | 不会；强制 human prompt 只重建 UI，AI fallback 只用于 AI owner |
| 测试桥是否进入生产 | 正式 preset 排除目录且没有 feature；相关静态测试通过 |
| rollback 是否需要 native 新包 | 不需要；query kill switch 只影响 Web adapter |

### 16.2 复审中修正的问题

- 投币动画本来就故意在下一 idle frame 推进，防止从旧 Tween callback 重入新 Tween。两个测试错误地同步断言，现已改为等待真实的下一帧契约。
- 两套测试替身未隐藏 discard/detail/coin modal，导致 AI 被测试环境假阻塞。现已把替身初态与 packed scene 对齐。
- `TestSuiteCatalog` 曾把 85 个自带 `_initialize()` 的独立 SceneTree 测试误收为 SharedSuiteRunner 测试，产生 “No test methods found”。现在只收集真正声明 `func test_*()` 的共享套件，独立测试仍由各自入口运行。
- 编码审计曾递归进入 Playwright `node_modules`，现排除 Node 报告/依赖目录；同时允许设计文档使用标准 U+2500～U+257F 框线字符，不放宽已知乱码码点检查。
- Android provision 在 adb daemon 刚启动时可能短暂返回 `offline`；导出脚本现在只在 state 为 `device` 时查询 boot property，并容忍状态过渡。
- 汇总门禁最初把 Godot/Playwright 的正常 stderr 进度行当成 PowerShell terminating error；现在捕获双流但以子进程 exit code 为唯一门禁结果。

### 16.3 变更边界复审

本轮没有修改卡牌效果、GameStateMachine、AI 策略评分、牌组数据或胜负逻辑。工作区中同时存在卡组训练、牌组数据和 VFX import 等其他改动；它们不属于本文改造，验证和后续提交时必须按文件清单分开处理，不能用 reset/checkout 覆盖。

## 17. 无人值守 UI 自动化：实际实现

### 17.1 Godot 契约与场景回归

新增的专用测试覆盖：

| 文件 | 覆盖内容 |
| --- | --- |
| `test_ui_runtime_profile.gd` | host/OS/pointer/layout/performance 组合与 native/Web 边界 |
| `test_pointer_sequence.gd` | owner、单次消费、cancel、synthetic echo 判定 |
| `test_web_input_adapter.gd` | touch/mouse 去重、orphan release、blur cancel、fresh press |
| `test_ui_interaction_session.gd` | 状态机、generation、幂等结束、registry replace/invalidate |
| `test_ui_interaction_watchdog.gd` | stalled 检测、一次恢复、非 stalled 不触发 |
| `test_browser_lifecycle_bridge.gd` | install/uninstall、旧 generation、cancel/viewport/error 路由 |
| `test_web_platform_services.gd` | 剪贴板请求、callback generation、shutdown |
| `test_non_battle_web_input_v2.gd` | Web v2 touch、synthetic mouse 与 native legacy 隔离 |
| `test_web_ui_e2e_bridge.gd` | 测试 feature、防误装、只读 snapshot/Control 查询 |

既有 Battle UI 测试继续验证 reveal、博士弃牌/抽牌、AI 投币后续步骤、灾祸场地清理、双方昏厥奖赏和换位链。测试不直接跳过动画契约：例如投币 follow-up 明确等待下一 `process_frame`。

### 17.2 浏览器真实 Canvas 输入

目录为 `tests/web_e2e/`，入口为 `scripts/tools/run_web_ui_e2e.ps1`。执行过程：

1. 导出独立 Web E2E 构建。
2. 执行 PCK/WASM 预算门禁。
3. 启动本地 HTTP server。
4. Playwright 等待测试桥可用和 scene 条件成立。
5. 通过只读 bridge 查询 Control 的 Godot global rect。
6. 按 Canvas/viewport 比例换算浏览器坐标。
7. 使用 Playwright mouse 或 touchscreen 对真实 Canvas 点击。
8. 轮询场景/指针状态，不以固定 sleep 作为业务完成条件。
9. 扫描 `pageerror` 与 `WEB_RUNTIME_ERROR`。

当前用例：

- 主菜单 → Settings → 主菜单。
- 主菜单 → BattleSetup → 主菜单 → DeckManager → 主菜单。
- mouse down → browser blur → 活动 pointer 清零 → 迟到 mouse up 不导航。
- `legacy` kill switch 启动同一生产 UI 并可正常进入 Settings。

项目矩阵：desktop Chromium、Pixel 7 风格 Chromium touch、iPhone 14 风格 WebKit touch。桌面专属 blur/legacy 用例在 touch project 中按设计 skip；所有项目都执行真实导航与返回。

外部 `*.skillserver.cn` 请求在 E2E 中由 Playwright 本地返回空 JSON，避免网络/CORS 波动污染 UI 稳定性结果；这不替代网络客户端自身测试。

### 17.3 Windows 原生真实鼠标

`scripts/tools/run_windows_ui_e2e.ps1` 会导出并启动真实 Windows executable，使用 user32 将窗口移动到稳定可见区域并发出真实 mouse down/up。它自动：

- 等待 1600×900 client area 和非空启动画面；
- 点击主菜单 AI 设置入口，再点击 Settings 返回；
- 保存 main/settings/main_return 三张 client screenshot；
- 计算导航差异与往返差异；
- 扫描 stdout/stderr 的崩溃与脚本错误；
- 恢复原鼠标位置/前台窗口并只关闭自己启动的进程。

门槛：navigation difference `>= 0.08`，round-trip difference `<= 0.12`。

### 17.4 Android 原生真实触摸

`scripts/tools/run_android_ui_e2e.ps1` 默认调用 Android skill 的标准 provision 脚本，完成导出、模拟器就绪、安装、启动、PID/focus 校验，再通过 `adb shell input tap` 发出真实触摸。它自动：

- 轮询截图复杂度确认主界面已经渲染，不用固定启动 sleep；
- 根据设备分辨率换算归一化点击位置；
- 主菜单进入 Settings 并返回；
- 拉取三张 screenshot；
- 计算同 Windows 一致的画面差异门槛；
- 扫描 logcat 的 FATAL、ANR、Godot script error 与崩溃标记。

当前 native smoke 的归一化坐标对应稳定主菜单/Settings 操作，不需要人工点击；截图差异和 focus 是失败 oracle。若后续扩大到动态卡牌/弹窗目标，应先为 native runner 增加语义矩形输出，不能继续扩散固定坐标。

### 17.5 一键汇总门禁

新增 `scripts/tools/run_ui_platform_validation.ps1`：

```powershell
# 全量：functional + AI + Web + Windows + Android
powershell -ExecutionPolicy Bypass -File scripts/tools/run_ui_platform_validation.ps1

# 单独复查 Web，复用现有导出和浏览器
powershell -ExecutionPolicy Bypass -File scripts/tools/run_ui_platform_validation.ps1 `
  -Scope web -SkipBrowserInstall -SkipWebExport
```

脚本为每个 gate 保存完整 log，并写入：

```text
.tmp/ui_platform_validation/<timestamp>/summary.json
.tmp/ui_platform_validation/latest-summary.json
```

`summary.json` 包含 schema、scope、总状态、passed/failed/not_verified、各 gate 的 exit code、耗时、artifact path 和失败原因；任一已执行 gate 失败时总进程返回非零。

### 17.6 自动化同步与失败证据

- Godot runner：等待测试协程与 scene frame，不用外部点击。
- Web：`expect.poll` 等待 scene、active pointers 和 bridge request 完成。
- Windows：等待窗口句柄、尺寸和截图复杂度。
- Android：等待 adb state、boot、PID、focus 和截图复杂度。
- 失败产物：Playwright report/trace（失败时）、Windows/Android screenshot、stdout/stderr/logcat、资源预算 JSON 和汇总 JSON。

所有入口均可在无人值守环境执行；不需要开发者观察画面再手工决定是否继续。

## 18. 2026-07-22 最终验证记录

### 18.1 全量回归

| 门禁 | 结果 | 证据 |
| --- | ---: | --- |
| Functional | 4,352 / 4,352 passed | `.godot_test_user/logs/functional-20260722-020116.log` |
| AI / training | 1,463 / 1,463 passed | `.godot_test_user/logs/ai-20260722-020923.log` |
| 关键 Battle UI focused | 110/110、80/80、90/90 passed | `test_battle_ui_features.gd`、part3、part4 |
| Runtime/input/session/lifecycle focused | 全部 passed | 九个新增专用测试文件 |

完整功能回归还执行了 Card Catalog Audit：766 张卡、101 个导入卡组；本轮没有改变其规则实现。

### 18.2 平台真实输入

| 平台 | 结果 | 关键数据 |
| --- | --- | --- |
| Chromium desktop | passed | Settings、BattleSetup、DeckManager 往返；blur/orphan release；legacy kill switch |
| Chromium Pixel 7 touch | passed | Settings、BattleSetup、DeckManager 真实 touch 往返 |
| WebKit iPhone 14 touch | passed | Settings、BattleSetup、DeckManager 真实 touch 往返 |
| Playwright 汇总 | 8 passed，4 intentional skipped | touch project 跳过 desktop-only blur/legacy 用例 |
| Windows native | passed | 1600×900；navigation `0.2143`；round trip `0.0091`；无 runtime failure marker |
| Android emulator | passed | 1080×2400；PID/focus 正确；navigation `0.2079`；round trip `0.0025`；无 crash marker |

平台证据：

- `.tmp/web_ui_e2e_artifacts/report/index.html`
- `.tmp/web_ui_e2e_artifacts/results/.last-run.json`
- `.tmp/windows_ui_e2e/report.json`
- `.tmp/android_ui_e2e/report.json`
- `.tmp/ui_platform_validation/latest-summary.json`

### 18.3 Web 资源预算

| 产物 | 本轮结果 | 门槛 |
| --- | ---: | ---: |
| PCK | 221.05 MiB | <= 225 MiB |
| WASM | 34.08 MiB | <= 40 MiB |

结果写入 `.tmp/web_ui_e2e_artifacts/resource-budget.json`。与未收紧排除规则时约 263.96 MiB 的 PCK 相比，减少约 42.91 MiB；本轮只排除可再生成源素材、测试/文档/临时产物，没有删除运行时卡牌数据。

### 18.4 尚未宣称的能力

- `NOT_VERIFIED_REAL_IOS`：WebKit automation 不是 Apple 真机 Safari/PWA；未接入真实 iOS remote runner，因此不能宣称真机已验证。
- 当前 Playwright 真实点击覆盖非战斗主路径和 lifecycle/kill switch；复杂 Battle draw/effect/AI 链由真实 Godot 场景与 5,815 项 functional + AI 回归覆盖，尚未把固定牌序对战完整搬进浏览器驱动。
- Windows/Android 当前是稳定入口的真实输入 smoke，不是动态卡牌目标的完整语义自动化。后续扩大用例时应复用语义矩形协议，而不是增加更多永久坐标。
- Phase 7 的 legacy 时间窗清理不是本轮完成条件；必须等 Web v2 线上稳定和更广 E2E 覆盖后单独执行。
