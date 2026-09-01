# D192 作者策略后台计算、思考 HUD、18.0 入口与启动缓存证据

日期：2026-08-31
工作树：`D:\ai\code\PtcgDAP`
Godot：`4.6.1.stable.official.14d19694e`

## 1. 请求与验收门

本工作包关闭四个相互关联但 owner 不同的问题：

1. 作者策略包计算不得继续阻塞 BattleScene 渲染主线程；
2. 等待策略时复用现有大模型策略的 AI 思考窗口，保持友好、可见的逐帧反馈；
3. 作者模式不得遮蔽或伪装成内置 AI，玩家必须能重新选择游戏内置 18.0 策略；
4. 生成证据/打包暂存不得污染 Godot 项目缓存并拖慢普通游戏启动。

显式负向门：不改战斗卡牌绑定、位置、尺寸、布局、动画完成时序或 UI authority。玩家可见 Windows 完整对局及动画结束帧的 frame-time/p95 仍是独立验收门。

## 2. 归因

### 2.1 策略并未真正与渲染解耦

`BattleScene` 原路径用 `call_deferred("_run_ai_step")` 延后 AI step，但 deferred callable 仍在主线程执行。作者 owner 随后同步调用 `selector.select(frame)`；`rules_with_model` 还会在同一调用栈继续执行本地模型叶。因此策略包越复杂，主线程停帧越长，思考结束附近还会与后续 UI/动画工作叠加。

### 2.2 18.0 数据没有丢失，模式入口被折叠

玩家配置处于 mode 2（作者策略），但对战设置隐藏了现有 `ModeAuthorStrategyButton`，并把普通 AI 按钮在 mode 2 时也显示为 active。持久化作者选择因此在界面上冒充内置 AI，玩家不能明确切回内置 18.0。修复没有改动 18.0 策略注册数据，而是恢复两个 mode 的独立状态和点击路径。

### 2.3 启动缓存被生成证据污染

旧 `.godot/global_script_class_cache.cfg` 含 75 个指向 `res://artifacts/ptcgdap/...` 的重复全局类；旧 extension cache 含 12 个该目录中的复制 GDExtension，再加项目真实扩展，造成重复注册和启动扫描。生成证据目录现在以根 `.gdignore` 隔离；损坏的两个缓存先改名备份，再由 Godot 重建。

## 3. 实现合同

### 3.1 单工作线程与冻结输入

`AuthorStrategyPolicyWorker` 是 match-owned 单任务 worker。live BattleScene 默认配置 `worker_v1`，只把深拷贝的 public frame、package selector 和可选本地模型 actor 交给线程。线程不持有或调用：

- `BattleScene` / UI 节点；
- `GameState` / `GameStateMachine`；
- `CardInstance` / `PokemonSlot`；
- 当前 prompt 控件或 Host-private option binding；
- 网络或系统 Python。

public frame 的构造仍留在主线程，因为它从当前可变引擎状态生成 allow-list 投影。异步边界只覆盖冻结后最重的策略/模型纯计算，不冒充全引擎线程安全。

### 3.2 等待、加入与 current-window 重验

第一次 live step 调度 worker 后立即返回 `waiting_policy`。BattleScene 复用既有 `_start_llm_wait_hud`，并在 `_await_author_policy_completion` 中逐次 `await get_tree().process_frame`。等待期间不重复调用策略；只有 `Thread.is_alive()==false` 才 `wait_to_finish`，所以正常轮询不会阻塞渲染主线程。

完成结果必须在主线程重新匹配：

- prompt identity；
- public observation hash；
- window ID；
- options fingerprint；
- selection constraints fingerprint。

任一漂移都记为 `stale_policy_response`，旧结果不执行；fresh current window 的确定性 fallback 保留 Base/Host 最终 authority。可选模型结果也必须随同一个 worker result 返回，缺失时以 `model_worker_result_missing` 本地降级。

### 3.3 复用 HUD，不改战斗 UI

现有 LLM wait lifecycle 增加本地身份 `ptcgdap-author-local`，展示“作者策略 正在计算行动… 第 N 回合 (Xs)”。本项只改变等待 label 的身份/文案，没有修改卡牌视图、场地槽、Control anchors、尺寸、位置、样式、动画队列或 completion repaint。作者性能合同继续负向禁止 D161 的 stable binding、style signature、completion batch 和 draw reconciliation 捷径。

### 3.4 18.0 与作者模式分离

作者 feature gate 开启时，对战设置显示三个独立模式：双人、内置 AI、作者策略。active 状态只由精确 `mode_option.selected` 决定。测试从持久化作者模式点击内置 AI，再选择 `v18cpg_800018502_ns_zoroark`，确认 18.0 路径恢复。

### 3.5 启动隔离

`artifacts/ptcgdap/.gdignore` 只阻止 Godot 资源扫描；原始证据仍可由 `FileAccess` 按路径读取。重建后的缓存：

- artifact global class path：0；
- artifact GDExtension path：0；
- 项目 GDExtension path：1，`res://scripts/ai/ptcgdap/native/ptcgai_ort_actor.gdextension`；
- plain `--headless --path <project> --quit`：2,309 ms，exit 0。

此前 warm editor 扫描约 11,955 个正常项目资产仍约 16 秒；这不是普通游戏 bootstrap 回归，D192 不声称编辑器即时启动。

### 3.6 作者与卡组展示快照

英文牌组名的最早 owner 是 `AuthorStrategyDeckMaterializer`：它原来主动生成 `作者策略包 · <package_id> · v<version>`。与此同时，顶部 `get_selected_deck_name_for_scene` 的 fallback 会再次调用 `GameManager.resolve_selected_battle_deck(1)`，可能只为刷新一行文字重新读取、验哈希并检查策略 archive。

现在 exact package handle 把清洗后的 `author.display_name`、`strategy.display_name`、`deck.display_name` 和 exact `package_version` 纳入内部完整性 seal，并通过只读 `presentation_snapshot()` 提供。materializer 使用卡组显示名和压缩版本；只裁掉第三段及之后的尾随 `.0`，因此 `5.30.0` 显示为 `5.30`，不会改写 exact package identity。

BattleScene 在本局开局时固定作者名和最终卡组 label。思考 HUD 读作者名，顶部当前牌组优先读本局 label；两者都不在每帧从 catalog 或 archive 重建展示信息。最终精确字符串已锁定为：

- `波导的勇者 正在计算行动...`（其后继续显示回合与耗时）；
- `玛丽的礼盒5.30`。

这只是现有 Label 的文字数据源变更，没有修改锚点、尺寸、字体、卡牌 Control、卡牌绑定或动画时序。

## 4. 执行证据

| 门 | 结果 | 日志 |
|---|---:|---|
| worker 非阻塞、stale 拒绝、模型叶后台执行 | 3/3 | `.godot_test_user/logs/focused-20260831-224812.log` |
| 实时节奏、批量日志、动画先入队、worker/HUD、展示快照、D163 UI 护栏 | 8/8 | `.godot_test_user/logs/focused-20260831-231503.log` |
| 包作者/卡组/5.30 文案与本局 pinned label 行为 | 1/1 | `.godot_test_user/logs/focused-20260831-231442.log` |
| GameManager/BattleScene exact author owner 路由 | 1/1 | `.godot_test_user/logs/focused-20260831-231512.log` |
| 三模式 HUD segment | 1/1 | `.godot_test_user/logs/focused-20260831-224526.log` |
| 作者模式切回内置 18.0 | 1/1 | `.godot_test_user/logs/focused-20260831-224539.log` |
| Windows landscape 18.0 N 的索罗亚克入口 | 1/1 | `.godot_test_user/logs/focused-20260831-224552.log` |

worker 用例中的 slow selector/model 各人为阻塞 160 ms；首调度要求 100 ms 内返回，并在后台期间观察多次 `process_frame`。三个用例均通过，并验证策略/模型分别只调用一次。

宽 `test_author_strategy_windows_player_owner.gd` suite 为 20/21。单独复跑 `test_windows_ui_acceptance_routes_rules_seat_zero_and_author_seat_one` 仍失败：fixture 通过 `_pending_choice` 注入 seat，但当前 runtime 优先读取 authoritative pending-decision snapshot，导致对象身份预期不一致。该 RED 不属于 D192 worker/18.0/启动缓存 owner，未通过改变 authority 顺序来迁就，也没有被 focused 绿灯豁免。该 suite 加载时另有 NUL Unicode 警告；plain project bootstrap 不出现这些警告。

## 5. 回滚

- 策略执行：新局设置 `PTCGDAP_AUTHOR_POLICY_EXECUTION_PROFILE=main_thread_v1`，恢复旧同步路径；进行中对局不热切。
- worker 故障：start/response/model failure 在本机从同一公开窗口确定性 fallback；不得路由远端服务。
- 启动隔离：两个旧生成缓存已保留为 timestamped `.bak`，仅供取证。恢复它们会重新引入重复类/扩展，不是安全产品回滚。若将来移除 `.gdignore`，必须先把 artifact 中的源码/扩展副本迁出 Godot 扫描根并重新生成缓存。
- UI：没有卡牌 UI 变更可回滚；思考 HUD 的本地作者 identity/text 可以独立撤回，不影响 worker authority。

## 6. 当前对齐级别与未关闭门

达到：local Godot Windows author-player orchestration、current-window async revalidation、focused non-blocking contract、plain project bootstrap cache acceptance。

未达到：玩家可见 Windows 完整对局 frame-time/p95、动画结束帧视觉验收、Android/A5、production trust、official CABT conformance、full-engine parity。不能从 headless 结果推导这些更高门已经关闭。

机器未启动新的 Python 训练、benchmark、replay、simulation 或 evaluation pool；外部 `D:\ai\code\ptcgabc` 未修改。
