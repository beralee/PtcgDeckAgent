# 对战视觉事件系统研发测试与平台验收矩阵

设计来源：`docs/superpowers/specs/2026-07-18-battle-visual-event-system-design.md`

状态含义：`Pending`、`Red`、`Green`、`Verified`、`Blocked by hardware`。只有自动化和所需平台证据都完成后才能标记 `Verified`。

## 1. 研发顺序

### Phase 0：基线与功能不变量

- [x] 记录当前 focused battle tests、完整 functional suite 和 card audit 基线。
- [x] 记录 Windows/Web/Android/macOS/iOS 导出预设与当前可用工具链。
- [x] 新增规则终态指纹 helper：双方区域实例 ID、槽位堆叠、附着、伤害、状态、阶段、胜负。
- [x] 新增测试证明纯 UI 消费者不能改变终态指纹和 `action_log`。

Gate：现有已知失败与本改造新增失败可以区分；没有基线就不进入实现。

### Phase 1：轻量快照、隐私和差分（纯函数 TDD）

RED：

- [x] 捕获所有区域、槽位、附着、伤害、状态、阶段和胜负字段。
- [x] 同一实例跨区域生成一个且仅一个 `zone_transfer`。
- [x] 进化堆叠生成 `stack_change`，不误判为宝可梦离场。
- [x] 战斗区/备战区移动生成 `field_move`，不重复生成销毁/创建。
- [x] 伤害、治疗、状态、洗牌、阶段和胜负差分正确。
- [x] 对手隐藏手牌和奖赏不输出可展示名称/卡面。
- [x] 同输入事件顺序确定，批量合并稳定。

GREEN：实现 `BattleVisualSnapshot`、`BattleVisualPrivacyPolicy`、`BattleVisualEventBuilder`。

Gate：纯函数 focused suite 全绿；快照不复制纹理或完整卡牌字典。

### Phase 2：队列、区域锚点和生命周期（TDD）

RED：

- [x] FIFO、动作分组、单次完成、超时和取消语义。
- [x] 场景不在树内时同步安全完成。
- [x] 锚点缺失时降级且不阻塞下一事件。
- [x] 重复的 action/refresh 快照签名不会重复入队。
- [x] 场景退出、回放切换、观察者切换和交接清空隐藏信息。
- [x] 横竖屏变化后重新解析目标矩形。

GREEN：实现 `BattleVisualSequenceController` 和 `BattleZoneTransferAnimator`，接入 `BattleSceneRuntime`。

Gate：现有抽牌、弃牌、换位和洗牌测试无重复播放。

### Phase 3：卡牌生命周期动画

- [x] 通用区域移动。
- [x] 训练家中央展示与真实目标收束。
- [x] 普通进化和神奇糖果两段式展示。
- [x] 能量附着、移动、弃置、放逐、回牌库。
- [x] 昏厥红扫、整组离场、奖赏、替补的因果链。

每项遵循：先新增失败测试，再最小实现，再复用/清理旧控制器。

Gate：真实 `GameStateMachine` 案例终态与无动画基线一致；卡牌总数不变量一致。

### Phase 4：数值、检索和批量流程

- [x] 伤害、治疗、状态变化。
- [x] 公开检索、隐藏检索、磨牌、放逐。
- [x] 手牌回牌库、洗牌、重抽；双方同时重置不泄露。
- [x] 大于 5 张的批量合并与数量徽标。

Gate：多目标攻击、超额治疗、空牌库、牌库耗尽和 8 张手牌重置边界测试通过。

### Phase 5：语义反馈与结算

- [x] 主动特性、被动特性和竞技场使用触发。
- [x] 回合开始、宝可梦检查和回合交接。
- [x] 胜负压暗、胜者提亮和胜负原因。
- [x] 无效动作不播放成功反馈。

Gate：AI 连续动作、本地双人交接、回放导航和游戏结束期间无队列卡死。

### Phase 6：全量回归与平台验证

- [x] 所有 focused suites。
- [x] `FunctionalTestRunner`；4111/4113，两个全量顺序污染失败均隔离复跑通过（31/31、35/35）。
- [x] `scripts/run_card_audit.ps1` 并审阅两份最新报告。
- [x] Windows 横屏与竖屏真实 Tween、布局和 Release 启动检查。
- [ ] Web release export 和产物检查已完成；浏览器运行 smoke 被内置浏览器本机地址策略拦截。
- [x] Android release export、签名、安装、启动、焦点、截图、真实对战与 logcat。
- [x] macOS/iOS 预设与共享脚本/布局契约；macOS 导出成功，iOS 因 Team ID/Bundle ID 和 Windows 主机限制记录为阻塞。

## 2. 动画需求追踪矩阵

| ID | 动画类型 | 事件/语义 | 必测案例 | 状态 |
|---|---|---|---|---|
| V01 | 通用区域移动 | `zone_transfer` | 牌库→手牌、手牌→弃牌、牌库→弃牌、公开/隐藏 | Verified |
| V02 | 训练家卡 | `trainer_play` + transfer | 物品、支援者、Boss 指令、效果失败不播放 | Verified |
| V03 | 进化/神奇糖果 | `stack_change` | 普通进化、跳阶段进化、退化 | Verified |
| V04 | 能量生命周期 | `attach_energy`/transfer | 手牌附能、场上移动、弃置、放逐 | Verified |
| V05 | 昏厥/弃牌/奖赏 | `knockout_chain` | 单奖赏、多奖赏、放逐替代、替补 | Verified |
| V06 | 伤害/治疗/状态 | delta events | 单体、多目标、无实际治疗、状态增减 | Verified |
| V07 | 检索/磨牌/放逐 | transfer batch | 公开检索、隐藏检索、磨 3、放逐 2 | Verified |
| V08 | 洗手牌/重置 | transfer + shuffle + draw | Judge/Iono 类、双方重置、对手隐私 | Verified |
| V09 | 特性/被动/竞技场 | `trigger_pulse` | 主动特性、自动触发、使用竞技场、替换竞技场 | Verified |
| V10 | 回合/阶段 | `phase_banner` | 回合开始→抽牌、宝可梦检查、交接 | Verified |
| V11 | 胜负结算 | `match_result` | 奖赏胜利、无宝可梦、牌库耗尽 | Verified |

## 3. 功能不影响矩阵

| 不变量 | 比较方式 | 验收 |
|---|---|---|
| 卡牌区域和顺序 | 动画前后终态指纹；区域内实例 ID 顺序 | 完全一致 |
| 场上槽位 | active/bench 堆叠、能量、道具实例 ID | 完全一致 |
| 数值与状态 | 伤害、HP、特殊状态、回合 flags | 完全一致 |
| 动作日志 | action type/player/data/turn/description | 完全一致 |
| 胜负 | phase、winner、reason | 完全一致 |
| AI/玩家输入 | 相同 seed 的合法动作和终态；动画忙碌时仍可提交原本允许的动作 | 不因 UI 动画改变或被新增门控 |
| 卡牌总数 | `count_player_total_cards()` | 每个动作前后一致 |
| 回放 | 快照加载与继续后的状态 | 不播放跨快照虚假动画 |

## 4. 隐藏信息测试矩阵

| 场景 | 本方看到 | 对方看到 | 自动断言 |
|---|---|---|---|
| 抽牌 | 正面 | 卡背 | 对方事件无 card name/正面 texture |
| 对手洗回手牌 | 卡背 | 正面（其本人视角） | 切换视角重建基线 |
| 调换票 | 卡背 | 卡背 | 所有阶段不显示奖赏内容 |
| 公开检索 | 正面 | 正面 | `PUBLIC_REVEAL` 允许展示 |
| 隐藏检索 | 正面（操作者） | 卡背/数量 | 日志和 Label 无隐藏牌名 |
| 奖赏拿取 | 操作者正面 | 对手只见数量减少 | 交接前清理临时正面卡 |

## 5. UI、压力和生命周期测试

- 0、1、5、8、20 张批量移动。
- 队列 48 个事件时合并且最终状态反馈仍存在。
- 动画中旋转横竖屏、改变窗口大小、目标节点被刷新替换。
- 动画中结束对局、退出场景、进入回放、从回放继续、本地双人交接。
- `BattleCardView` 图片缺失时使用文字代理，动画仍结束。
- AI 连续提交 10 个动作，队列不无限增长且 UI 最终与状态一致。
- 所有临时节点 `mouse_filter = IGNORE`，没有不可点击透明层残留。

## 6. 平台验收矩阵

| 平台/形态 | 自动验证 | 运行验证 | 视觉证据 | 状态 |
|---|---|---|---|---|
| Windows 1600×900 | focused + functional + script load | Release EXE 启动 8 秒无提前退出；真实 Tween 完成 | 自动化节点/泄漏检查 | Verified |
| Windows 900×1600 | portrait layout 104/104 | 真实 Tween、队列收尾和规则快照检查 | 控件不越界、临时节点归零 | Verified |
| Web Desktop | Release 导出、产物清单、专项 18/18 | 本机 URL 被内置浏览器策略拦截 | PCK/WASM/manifest 完整 | Blocked by environment |
| Web Mobile viewport | portrait/anchor tests | 本机 URL 被内置浏览器策略拦截 | 共享竖屏与触控契约通过 | Blocked by environment |
| Android emulator | Release export + signature | install/launch/focus/真实对战/logcat | 1080×2400 首页、设置、战场与附能截图 | Verified |
| macOS | shared GDScript + layout contracts；cross-export | 当前 Windows 主机不可原生运行 | Release ZIP 导出成功 | Export verified / native blocked |
| iOS | shared GDScript + safe-area/layout contracts | 缺 Team ID/Bundle ID，且 Windows 不可原生运行 | 导出尝试给出明确签名配置错误 | Blocked by signing and hardware |

## 7. 计划执行命令

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\tools\run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_battle_visual_event_builder.gd
powershell -ExecutionPolicy Bypass -File .\scripts\tools\run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_battle_visual_sequence_controller.gd
powershell -ExecutionPolicy Bypass -File .\scripts\tools\run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_battle_visual_animation_plans.gd
powershell -ExecutionPolicy Bypass -File .\scripts\tools\run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_battle_ui_features.gd
powershell -ExecutionPolicy Bypass -File .\scripts\tools\run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_battle_portrait_layout.gd
powershell -ExecutionPolicy Bypass -File .\scripts\tools\run_godot_tests.ps1 -Runner functional
powershell -ExecutionPolicy Bypass -File .\scripts\run_card_audit.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\tools\export_web_release.ps1
powershell -ExecutionPolicy Bypass -File .\.codex\skills\ptcg-android-export-emulator\scripts\export_and_run_android.ps1
```

Windows/macOS/iOS 的额外导出命令在执行前根据安装的 Godot export templates 与签名要求确定；不得为了让导出成功而静默修改发布签名或架构策略。

## 8. 2026-07-18 实际验收记录

```text
Animation coverage: V01..V11 = Verified
Functional invariance: 视觉专项 21/21；规则快照和 action_log 不变；portrait 104/104
Hidden information: 对手手牌/牌库/奖赏默认卡背；公开展示例外；调换票由原专属控制器拥有
Focused tests: 视觉 21/21；Battle UI 267/267；Web/export 18/18；全量失败项隔离 66/66
Functional suite: 4111/4113；两项 BattleSetup 顺序污染失败隔离重跑均通过
Card audit: 678 exercised / 82 skipped / 0 registry / 0 smoke / 0 interaction / 9 existing verification gaps
Windows landscape/portrait: Release EXE 实际启动；1600×900 与 900×1600 真实 Tween 完成且临时节点归零
Web desktop/mobile: Release 与专项通过；内置浏览器阻止访问本机 URL，未取得运行截图
Android: 290620582-byte APK；PID 3736；前台 Activity 正确；1080×2400 进入真实对战并完成附能；无 FATAL/ANR
macOS/iOS: macOS Release ZIP 成功；iOS 缺 Team ID/Bundle ID 且当前为 Windows 主机
Known unrelated failures: FunctionalTestRunner 的两个 BattleSetup 顺序污染失败；隔离复跑 31/31、35/35
```

## 9. 完成审计模板

最终交付必须逐项填写：

```text
Animation coverage: V01..V11 = <status>
Functional invariance: <tests and fingerprint result>
Hidden information: <tests>
Focused tests: <passed/failed>
Functional suite: <passed/failed>
Card audit: <exercised/skipped/gaps>
Windows landscape/portrait: <evidence>
Web desktop/mobile: <evidence>
Android: <APK, PID, focus, screenshot, logcat>
macOS/iOS: <export/device evidence or explicit hardware limitation>
Known unrelated failures: <list>
```
