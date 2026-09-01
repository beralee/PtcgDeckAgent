# 作者策略包模式工程交接手册

## 0. 交接目的

本文交给负责实现“作者策略对战”的下一位工程 Agent。目标不是继续讨论产品方向，而是让接手者在当前仓库中按正确顺序开始写 RED、实现、验证、留证据和回滚。

产品设计权威在 `08-author-strategy-package-mode.md`。本文补充当前代码现实、工作包拆分、文件 owner、API 草案、测试矩阵和停手机制。两份文档冲突时：先服从 CABT 架构与 `STATUS.md` 当前游标，再由同一变更修正文档，不能在代码中暗自选择第三种语义。

## 1. 一页结论

需要实现的新产品形态：

```text
自己练牌
经典 AI 对战
作者策略对战
```

作者策略的 UI 单元不是“旧 AI 牌组 + 一个新策略开关”，而是一份完整署名包：

```text
package = author + strategy + AI deck + version + content hash
```

展示例：

```text
z 的喷火龙 AI
喷火龙 / 比雕 · v1.0.0 · 本地已验证
```

运行时：

```text
.ptcgai deterministic ZIP
  -> startup metadata catalog
  -> BattleSetup author-package selection
  -> match-time full revalidation and pin
  -> PtcgDAPAuthorMatchHost
  -> public observation/current-window policy
  -> indexes only
```

新模式不得经过 `DeckStrategyRegistry`、旧规则版/大模型版、`ai_deck_strategy` 或 `AIOpponent` fallback。包不能携带任意 GDScript、Python 或 native executable。

## 2. 当前真实状态

截至 2026-08-18：

- P5-WP7 已完成限定 offline differential/shadow trajectory，bundle canonical 为
  `992B7F00DF412496BA414ABCC87C21C6136CB513C9C90799C897ADD18D15EDB2`；
- AS-WP0 已完成治理，AS-WP1 已完成 strict contract、deterministic builder 与 fixed-anchor Python loader，AS-WP2 已完成 Godot
  captured-byte loader 与 metadata-only startup catalog，AS-WP3 已完成 BattleSetup setup-only metadata UI，AS-WP4 已完成 match-time
  archive 重验、one-match sealed handle、exact deck gate 与 shadow Host，AS-WP5 已完成 W1 `setup_active` development/test canary；
  `STATUS.md` 的唯一即时游标已回到 AS-WP6 外部关闭链；D069 已关闭 prompt-evidence hash-binding，D070 已关闭 product trust/exact signing，
  当前等待预-canary official W0–W7 report/product approval 与后续 device/rollback/A5/release 批准；
- production aligned mode 尚未进入 live；D044 已只为 exact 内置 Marnie 候选接通 Windows development player path；
- 作者策略包已有 AS-WP1 offline contract/reference、AS-WP2 Godot metadata、AS-WP3 setup UI、AS-WP4 match-shadow 与 AS-WP5 W1 canary
  evidence；AS-WP6 已加入一个 test-fixture-signed、`execution_trusted=false` 的内置开发候选包用于导出/runtime probe，仍无玩家可执行发布包；
- D041 已把当前产品声明收窄到 Windows，Android 后续独立适配。内置候选包来自 Marnie 历史来源 `800018501` 的 Windows-local deck：
  `godot_local_card_uid_v1`、28 个唯一 UID/60 张牌、`cabt_exportable=false`；D144 起 Python/GDScript match gate 只以包内 CSV/manifest 作为牌表，
  重验逐卡源 hash 和 `CardDatabase` exact UID，不再按来源编号读取任何 deck JSON。adapter/config 也只接受该 manifest 内的字符串游戏 UID 并绑定 exact manifest hash；数字型 official ID、
  未知 UID 或跨域配置会 fail closed。语言中立 local-UID public-context bundle canonical
  `42706B8426968F4EB1A9C79A3EFC3828236966454013BB791D51684E5C346AAA` 现固定当前窗口、公开 serial、deck UID 集与隐藏字段闭合边界；
  Python/GDScript Host 已能编译、逐 prompt 绑定本地域 adapter 并产生 shadow audit，W1 development source 只在本地域注入该视图；真实
  Marnie W1 canary 仅使用已有 exact official bridge 的 `CSV8C_094`，不为其余本地 printing 伪造 CABT Card ID。
  该包仍为 test key、`execution_trusted=false`，production live、official CABT W0–W7 conformance/engine parity 均未因此完成；
- 已有 `.ptcgai` schema/builder/Python/Godot loader、autoload catalog、setup-only UI、development-only match handle/Host 和 exact mapped
  synthetic fixture；D044 又为 exact 内置候选增加独立 Windows development player owner 和 BattleScene consumer，仍没有 production trust root、
  ready record、任意用户包执行或玩家可执行发布包；
- 经典 AI 行为必须保持不变；
- `data/ptcgdap/author_strategy_packages/README.md` 已记录该开发候选包的非生产边界；它不是 production approval 或 player-ready 证据。
- D043 已在不改变上述正式边界的前提下建立 exact-SHA Windows development execution 子门：测试专用
  `MarniePackageDevelopmentAIOpponent` 复用 Dragapult development Host 的公开投影/serial/真实 rules bridge，但用包内 GDScript
  restricted IR/adapter 替换外部 Python。seeds 84200–84209 双座位 10/10 终局，918/918 policy success、0 error/invalid/fallback，
  166 次 adapter rule match、138 次 macro 首选生效。它不接生产 factory/玩家入口，不把正式 Host 伪装成 `AIOpponent`，且未覆盖
  headless bridge 自动处理的全部 W0–W7 提示；完整报告为 `artifacts/ptcgdap/marnie_package_rules_e2e_10_games.json`。
- D044 已把同一 exact 内置 archive 接到 Windows development 产品路径：GameManager 只解析 Marnie `800018501`，BattleSetup 只为该
  exact candidate 打开开发按钮，实际 `BattleScene.tscn` 创建 seat 1 独立 `RefCounted` owner 且不构造 classic `AIOpponent`。owner 统一处理
  Godot setup/mulligan、main、interaction/effect、take-prize、send-out 与 handoff 调度，策略仍只收公开 frame/本地 UID 并返回当前窗口 indexes。
  seeds 84400–84409 的 seat-1 Marnie 对 rules-only `575720` 为 10/10 终局、593/593 policy success、586 engine commits，
  error/invalid/same-window fallback/classic fallback/engine rejection 全为 0，战绩 1 胜 9 负。证据见
  `artifacts/ptcgdap/as_wp6_windows_player_owner/`；production Catalog ready/signature/device gate 没有变化。
- D045 已以 fresh-user-root Windows export template 完成 3 局 headless development 整局。D046 又用 3 次真实 Win32 鼠标点击通过普通
  MainMenu/BattleSetup/BattleScene 完成一局：44/44 policy success、44 engine commits、所有失败/回退计数为 0；同一当前源码 release EXE
  的 3 局为 186/186、186 commits。独立关闭开关会隐藏模式、停止 catalog 扫描并在 0 policy call/0 commit 前 fail closed，保留用户包且不
  热切进行中的 owner。证据见 `artifacts/ptcgdap/as_wp6_windows_ui_match/`。应用层启动网络入口虽已在显式验收路径关闭，仍没有 OS-level
  disconnected/airplane 证明，也没有 production trust/device/A5 晋升。

接手者在开始任何实现前必须重新读取 `STATUS.md`。AS-WP5 已关闭 W1 development-canary 子门，D044 已关闭 exact candidate 的 Windows
development player-owner 子门；D045/D046 又关闭 headless 与 ordinary-UI development execution 及工程回滚子门；D048 已关闭 acceptance-only
production device-canary 合同/执行路径子门。D056/D057 随后已完成固定 Windows 资源资格与产品批准，并由产品明确豁免当前
OS-disconnection 取证；该豁免不是 isolation proof。D069 又要求 release/canary approval 通过固定产品 store 绑定 exact package 的
pre-canary official W0–W7 report hash，裸 coverage 数组不再授权。当前 AS-WP6 只继续 production trust/signing、报告生成与审批、
exact package/device-canary approval及独立 A5 工作，不得把 development authority 扩写为 production live。Android 不再阻塞
当前 Windows 子门，但未来启用时必须另做 arm64/ABI/真机/A5，不能继承 Windows 结论。

当前 Marnie Windows-local 牌组映射已经关闭：内置 `800018501` 的 28 个 local UID/60 张牌可精确物化，不再等待 10 个 official Card ID bridge。
但官方 19-ID lane 仍只有 9 个 exact bridge、覆盖 34/60，另 10 个 unmapped；因此 CABT export、跨 Host official identity 和相应 engine parity
仍未关闭。不得把 local UID 档与官方 deck 合并，也不得按中文名/英文名猜映射。

## 3. 接手前必读与工作树保护

### 3.1 阅读顺序

严格按根 `AGENTS.md` 阅读：

1. `docs/ptcgdap/README.md`
2. `01-official-cabt-contract.md`
3. `02-current-state-and-gap-analysis.md`
4. `03-target-architecture.md`
5. `04-migration-roadmap.md`
6. `05-validation-promotion-and-rollback.md`
7. `06-first-vertical-slice.md`
8. `07-decisions-risks-and-open-questions.md`
9. `08-author-strategy-package-mode.md`
10. 本文
11. `10-author-strategy-developer-guide.md`
12. `STATUS.md`
13. `IMPLEMENTATION_CHECKLIST.md`
14. `SOURCE_LOCK.json`

### 3.2 启动检查

在仓库根执行只读检查：

```powershell
git status --short
git diff --check
rg -n "next_permitted_work|current phase" docs/ptcgdap/STATUS.md
```

当前 worktree 很可能包含大量未提交、未跟踪和删除记录，它们属于现有工程状态。不得 reset、checkout、清理或覆盖不属于本工作包的文件。不要提交、push 或修改只读 `D:\ai\code\ptcgabc`。

本任务不需要训练、benchmark 或 simulation pool。不要为了实现 package/UI 启动重型 Python 进程。

## 4. 现有 Godot 接点地图

### 4.1 游戏模式与对局选择

文件：`scripts/autoload/GameManager.gd`

当前事实：

- `GameMode` 已包含独立 `VS_AUTHOR_STRATEGY_AI`；
- `current_mode` 默认 `TWO_PLAYER`；
- `ai_deck_strategy` 是经典 AI 策略变体字段；
- 作者选择使用独立 copy-in/copy-out stable record，不写入 `ai_deck_strategy`；
- Windows development gate 只允许 exact built-in Marnie archive，并以本地 deck `800018501` 解析 seat 1；
- 独立 feature gate 关闭后拒绝新作者局；
- tournament/training 等路径也会显式设置 `VS_AI`，不能因新增枚举而改变它们。

保持边界：不得扩大到 user/non-exact package，不得把 package ID 填进 `ai_deck_strategy`，也不得让关闭开关热切进行中的 owner。

### 4.2 对战设置 UI

文件：

- `scenes/battle_setup/BattleSetup.tscn`
- `scenes/battle_setup/BattleSetup.gd`

当前事实：

- 场景已有第三个作者策略模式按钮、独立 metadata picker/detail/status 和 stable-ref 保存；
- 作者模式不枚举经典 AI deck、不显示经典 AI controls，也不构造 `ai_deck_strategy`；
- production catalog ready 仍为 false；仅 exact built-in Windows development candidate 可启用开始按钮；
- feature gate 关闭时作者按钮被隐藏/禁用、保存的作者选择被清空为非活动状态，用户包文件不删除；
- D046 的显式验收入口通过真实鼠标使用这条普通 UI 路径，而不是直接调用按钮 callback。

保持边界：production 开战仍必须等待正式签名、approval、device/A5 与 release gate；开发按钮不能扩大到任意用户包。

### 4.3 经典 AI 工厂

文件：`scripts/ui/battle/ai/BattleAiOpponentFactory.gd`

当前事实：

- `build_selected_ai_opponent()` 返回 `AIOpponent`；
- 加载失败会回落 `build_default_ai_opponent()`；
- 规则/MCTS/ValueNet/LLM 变体在这个经典 owner 内组合；
- 这套 fallback 语义不能用于作者包。

当前接线：经典 factory 行为保持不变；`BattleDecisionOwnerFactory.gd` 已在更高层分流，作者模式构造独立 `RefCounted` player owner。
D046 UI 验收另为 seat 0 构造现有 rules-only `AIOpponent`，只用于双自动 owner 的显式 Windows 验收，不改变普通经典模式。

### 4.4 BattleScene 运行层

入口 `scenes/battle/BattleScene.gd` 只是薄壳，真正逻辑位于：

- `scenes/battle/BattleSceneRuntime.gd`
- `scenes/battle/runtime/BattleSceneRuntimeFoundation.gd`
- `BattleSceneSharedHudAiRuntime.gd`
- `BattleSceneSetupEffectAiRuntime.gd`
- `BattleSceneDialogInteractionReviewRuntime.gd`
- 其他 runtime mixin。

当前代码已抽取 `_runtime_ai_owner()`/prompt-owner 路由：经典路径继续返回 `_ai_opponent`，作者路径返回独立 owner；D046 显式 UI 验收再按
authoritative chooser/current player 在 seat-0 rules owner 与 seat-1 author owner 间切换。作者 owner 不继承 `AIOpponent`，只消费公开 frame、
本地 UID 和当前窗口 indexes。终局报告由 setup/effect runtime 的 recording finalize 层触发，主 `BattleSceneRuntime.gd` 保持 3000 行门禁以下。

保持边界：不得把 Host 冒充 `AIOpponent`、不得让策略直接持有 scene/GSM/private refs、不得在旧窗口复用 authority，也不得一次性重写所有 runtime。

### 4.5 旧牌组数据库

文件：`scripts/autoload/CardDatabase.gd`

当前事实：

- 旧 AI 牌组来自 `user://ai_decks/` 与 bundled user data；
- `get_all_ai_decks()` 和 `build_deck_instances()` 服务旧 local printing/DeckData 路径；
- CardDatabase 不验证作者包签名/合同；
- 它不是新 package catalog owner。

目标：作者包 catalog 独立。只有 match package 已验证且 exact local deck mapping 完整后，专用 deck adapter 才可构造 `DeckData/CardInstance`；不能把未验证包复制进 `ai_decks`。

### 4.6 已有 PtcgDAP pure/shadow owners

可复用但不能越级的核心包括：

- `scripts/engine/decision/EngineDecisionPort.gd`
- `GodotOptionBinding.gd`
- `GodotActionTicket.gd`
- `GodotActionExecutor.gd`
- `ShadowPromptBroker.gd`
- `scripts/ai/ptcgdap/host/godot/GodotObservationProjector.gd`
- `scripts/ai/ptcgdap/public/PublicObservationFirewall.gd`
- `PublicBasePolicy.gd`、`PublicDeckAdapter.gd`、`RestrictedBaseGraphExecutor.gd`
- P5 Marnie fixture/policy/broker/base owners。

它们当前大量结果是 offline、copy-only、non-authoritative audit。调用 `to_dict()` 或 schema 验证通过不能建立 live window/ticket/engine authority。作者 Host 必须在同一可信调用链中从当前 Godot prompt 重建 owner 对象。

### 4.7 导出与测试

- `project.godot` 已包含作者 package catalog、production gate 及默认休眠的 Windows headless/UI 验收 autoload；后两者只在显式开发参数下激活；
- `export_presets.cfg` 的主要 preset 包含 `data/**`，因此内置 `.ptcgai` 位于 data 根时有候选导出路径；
- Windows resource inventory/PCK runtime 已逐项证明 19/19 必需合同、候选包和 weights 被包含；Android 仅保留历史开发记录并已 deferred；
- `scripts/tools/run_godot_tests.ps1` 默认 Godot 4.6.1 console；
- `tests/TestSuiteCatalog.gd` 会发现 `tests/**/test_*.gd`，新 suite 无需硬编码 catalog，除非分组特殊。

## 5. 目标文件边界

### 5.1 新增 owner

```text
contracts/ptcgdap/author_strategy_package.schema.json
contracts/ptcgdap/author_strategy_package_profile.json
contracts/ptcgdap/author_strategy_package_conformance_vectors.json
contracts/ptcgdap/author_strategy_package_bundle.json
tools/ptcgdap/build_author_strategy_package.py
scripts/ai/ptcgdap/author_strategy_package.py
scripts/ai/ptcgdap/packages/AuthorStrategyPackageCatalog.gd
scripts/ai/ptcgdap/packages/AuthorStrategyPackageLoader.gd
scripts/ai/ptcgdap/packages/AuthorStrategyPackageHandle.gd
scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorMatchHost.gd
scripts/ui/battle/ai/BattleDecisionOwnerFactory.gd
tests/ptcgdap/test_author_strategy_package_contract.py
tests/ptcgdap/test_author_strategy_package_loader.py
tests/ptcgdap/godot/test_author_strategy_package_catalog.gd
tests/ptcgdap/godot/test_author_strategy_battle_setup.gd
tests/ptcgdap/godot/test_author_strategy_match_host.gd
```

文件名可在正式 work package 中收束，但职责不能合并到旧 `CardDatabase/DeckStrategyRegistry/AIOpponent`。

### 5.2 预计修改的既有文件

```text
project.godot
export_presets.cfg
scripts/autoload/GameManager.gd
scenes/battle_setup/BattleSetup.tscn
scenes/battle_setup/BattleSetup.gd
scenes/battle/runtime/BattleSceneRuntimeFoundation.gd
scenes/battle/runtime/BattleSceneSharedHudAiRuntime.gd
scenes/battle/runtime/BattleSceneSetupEffectAiRuntime.gd
scenes/battle/runtime/BattleSceneDialogInteractionReviewRuntime.gd
```

每个工作包只能 snapshot 自己真正修改的父文件。不要一开始就同时修改全部 runtime mixin。

## 6. 工作包拆分与实施顺序

### AS-WP0：治理、父快照与 RED

目标：先建立可执行工作边界，不写 live。

必须完成：

- 检查 `STATUS.md` 是否已允许该子门；
- 新建 `artifacts/ptcgdap/<work_package>/work_package.json`；
- 精确列 `files_allowed`、parent bundle/hash、已关闭的 P5-WP7 前置、shadow 状态、exit/rollback；
- 为所有预计修改的既有文件保存 exact base64 parent bytes；
- 写 parent snapshot 测试并做虚拟恢复；
- 写第一个 module/package missing RED。

停手机制：若 P5-WP7 bundle/evidence 漂移、parent snapshot 不可恢复或用户现有改动与 owner 文件重叠，先报告，不继续写实现。

### AS-WP1：`.ptcgai` 合同、builder 与 Python reference loader

范围：纯离线，不改 project/autoload/UI。

交付：

- strict schema/profile/shared vectors；
- deterministic ZIP builder；
- Python fixed-anchor loader；
- synthetic golden valid/invalid packages；
- hash/signature/path/size/type/fault tests；
- package contract evidence 与 rollback。

退出：Python contract/builder/loader 全绿，schema 负例可执行，包内无可执行代码，archive 重新构建逐字节一致。

### AS-WP2：Godot loader 与启动 catalog

范围：新增 package GDScript 和 catalog autoload；不改 BattleScene。

交付：

- `ZIPReader` captured-byte loader；
- 固定内置/用户根扫描；
- metadata-only catalog、copy-only DTO 和稳定诊断码；
- Python/GDScript shared vector 100% 一致；
- cache 只加速 metadata，不授予 match authority；
- `project.godot` autoload 与 export contract inclusion 测试。

退出：启动扫描不会执行策略；invalid 包不进入 ready 列表；内置/user 同 identity 冲突 fail closed；完整包加载仍只在显式 match API 发生。

### AS-WP3：BattleSetup 独立模式和作者署名 UI

范围：GameManager、BattleSetup scene/script、UI tests；仍不执行 live 对战。

交付：

- `VS_AUTHOR_STRATEGY_AI`；
- 第三个 `ModeAuthorStrategyButton`；
- 独立 package picker 与详情；
- 主标题“作者 的 策略名”；
- `ready/metadata_only/incompatible/untrusted/invalid/disabled` 状态；
- author selection copy-only setup record；
- unavailable 包禁用开始按钮；
- classic AI 控件在作者模式完全隐藏，切回后状态恢复。

退出：metadata UI focused/functional tests 全绿；开始按钮仍由 stub match gate 拒绝或只进入 shadow；旧 BattleSetup tests 原样通过。

实际关闭（2026-08-12）：已新增独立 `VS_AUTHOR_STRATEGY_AI`、第三模式按钮、copy-only picker/detail/status、五字段 GameManager setup record
和三字段 stable-ref 保存。六类状态均可展示；同名不授权 identity，missing exact ref 恢复为空。作者模式不枚举旧 AI deck，隐藏 classic
strategy/LLM/opening 控件；即使 synthetic `ready` 也恒定 `not_live_ready`，不会进入 BattleScene。父快照封存 15 个既有文件并重现
1687-entry AS-WP2 handoff。未建立 handle、Host、local deck mapping 或 live authority；下一唯一允许工作为 AS-WP4。

### AS-WP4：match-time loader、deck gate 与 shadow Host

范围：精确包重验、handle、factory shadow，不执行 engine command。

交付：

- 开战时重新读取 archive raw bytes；
- immutable package handle；
- package/deck/contract/catalog/Base/IR/backend/weights 全局 pin；
- exact 60 local deck mapping 和 engine capability gate；
- `BattleDecisionOwnerFactory` 按模式分流；
- `PtcgDAPAuthorMatchHost` 对 W0–W7 只产生 shadow indexes/audit；
- classic `BattleAiOpponentFactory` 逐测试不变。

退出：删除/替换/mtime cache collision/hot swap 均在对战前拒绝；shadow output 与 Python reference 一致；BattleScene 不执行作者结果。

实际关闭（2026-08-12）：catalog 已从内部固定 archive path 重新捕获并完整重验；handle 固定 package/archive/manifest/files、
CABT/Card catalog、Base/IR/adapter/config、optional weights/backend 与 exact local deck mapping，且只允许一次 match claim。exact deck gate
只按 reviewed official Card ID bridge 物化 60 张本地 printing。Python/GDScript Host 对三个 shared case 的 indexes/diagnostic/public audit
一致；模式 factory 保持 classic branch 分离。BattleScene 未修改、未消费作者结果，test fixture 仍 `execution_trusted=false`。

### AS-WP5：current-window live seam 与 canary

范围：逐提示接入，不允许 big-bang。

顺序：setup/mulligan/turn-order → prize/send-out → main → attack/payment/effect/order → cleanup/terminal。

每个提示必须：

1. 从当前 engine prompt 构建 exact `EngineDecisionPort` snapshot；
2. 经过 Projector/Firewall 创建 fresh immutable window；
3. 调包内受限 policy；
4. sanitize current-window indexes；
5. 建立 one-use ticket；
6. preflight/commit；
7. 执行后立即 reobserve，旧 window/ticket 失效。

停手机制：任何未覆盖 prompt、engine callback 不可逆、hidden data 泄漏、same-window fallback 不成立或性能超预算，保持 shadow，不接 live。

实际关闭（2026-08-12）：只关闭 W1 `setup_active` development/test canary。engine-owned source 绑定 chooser-correct 公共观察、fresh window、
callback hash 与 exact private command；Host 只见 public context/window。selection 经 sanitizer、binding/ticket/preflight/commit 后只执行一次，
并立即发布 W2 `setup_bench` fresh observation 使 W1 authority 全失效。策略异常/非法输出只走变异前 same-window fallback；候选变化、重放、
unsupported family 与提交后引擎前置条件失败均 fail closed，绝不回落 classic AI。BattleSetup 玩家开战门仍为 false，fixture 仍
`execution_trusted=false`，W2 与后续 family 均无执行 authority。live-seam bundle canonical 为
`5CDC360999A23A2CADCAC6E7FA8D81549566DFABE37B2DB4F813C0C5189C3E16`；250ms 仅移交 AS-WP6 作为候选 device budget，未在本门验收。

### AS-WP6：安装包、设备与发布

范围：签名 trust root、当前 Windows 导出与资源门；D057 已产品豁免本轮 OS 断网取证；Android 按 D041 后续独立适配。

必须证明：

- 当前 PCK/EXE 中实际包含 contract、loader、受信内置包和权重；未来 Android 适配时 APK 重新独立证明；
- 无系统 Python、sidecar、动态下载或远程推理；
- 冷启动、catalog 扫描、match load、每决策、内存、包体、温度/电量过批准 profile；
- 包损坏走 local deterministic fallback 或赛前安全拒绝；
- rollback 可以关闭模式且不删除用户包。

当前实施证据（2026-08-18）：D048 补齐 acceptance-only canary approval/owner/export 路径；D056/D057 又完成固定 Windows 资源资格与产品批准，
并把 OS-disconnection 取证记为产品豁免。D058 又增加统一作者工作台与开发者指南：`scaffold/build/validate/simulate` 自动使用公开
test-fixture 签名，作者不管理 key；public-only 模拟由 Host 生成 current-window 身份并报告 matched rules/proposals/indexes。证据见
`artifacts/ptcgdap/as_wp6_author_developer_workbench/`。该开发子门不执行规则引擎，也不授予任意包 player/production authority。
release bundle 已由 D070 更新为 canonical `527D725B50946874D62C95B957DB401A5EC6F58A5A2E8653650E89E765E7AE26`，固定
product trust/release-approval/canary-approval/prompt-conformance-approval/device 文档、本地 UID
导出 owner chain 和两端 fail-closed gate；active production key 为 1，release/canary/prompt approvals 均为零，device profile 为 `approved`、
  `formal_a5_eligible=false`。当前 18792-byte Marnie Windows-local development candidate SHA-256
`32E25453431886F76CEC606089ED4815EC681FBD33073F53A335A769D293643E` 含 28 UID/60 张 exact deck、七条 local-UID macro 与 weights，但使用 synthetic test key 且
`execution_trusted=false`。Windows-local 扩展 bundle canonical `944440FB15D9C3C3533C4DFDF7B163BF690160CF1F6D6AB8C776958A6EDBDB56`；
local-UID public-context bundle canonical 为 `42706B84...6AAA`；D050 当前两次 Windows resource ZIP/PCK/EXE 已逐字节一致，哈希为
`9A90F8DC...0E12` / `47279C38...7B38` / `6D3DCA39...7AB0`，历史离线 inventory 与 PCK runtime 覆盖 19/19 必需路径；D048 当前 runtime probe
已覆盖新增 canary store/gates 后的 22/22。旧
`6308E12D.../C158CE7E.../93021050...` 只保留为前一候选的历史证据，不再代表当前树。先前 Android debug APK/AVD 结果
也只保留为历史开发证据，不进入当前 Windows 首发门或预批未来 Android。
当前 approval/device evidence 改用 exact platform map，只允许 `windows`；Android 字段缺失不是错误，但夹带 Android 证据会 fail closed，避免
D041 之后仍被旧双平台硬编码永久阻断。
正式 device report 现必须闭合绑定 exact profile ID/canonical hash、3 个冷启动样本、至少 100 个决策样本、重算 max/P95 与六个 evidence hash。
当前 provisional Windows probe 只记录三次 exported-EXE headless exit 0、2190–3021ms 启动期与 177–251 MiB 启动峰值；D045 又新增
fresh-user-root exported-EXE headless 三局整局：186/186 policy success、186 engine commits、六类错误/回退为 0，总耗时 12008ms、
峰值 321MiB、decision P95 81778us，包装器观察到 0 子进程/0 网络 endpoint。D046 又完成 ordinary UI development 整局与
feature-off fail-closed 演练；应用层网络入口关闭但未实施 OS-level block，因此仍不是 disconnected/airplane acceptance 或 A5。
历史 D045 重复导出审计显示 4485 个逻辑成员全等但 raw container 顺序/hash 漂移；D050 已在固定 release owner 中加入 fail-closed
ZIP/PCK/embedded-EXE canonicalizer，并以两次新完整导出的五项绑定产物逐字节一致关闭该子门。
D047 已把正式 report builder 收口为五类 evidence 文档的语义校验与同一 EXE/run/PID/production-signature 绑定，并增加管理员专用
WFP 5154–5159/4688 positive-control 包装器；语义读取字节会再次核对先前 evidence hash，TCP control 绑定当前 PID+随机端口，进程 control
绑定 exact PID。它在任何系统变更前拒绝非管理员会话，且普通 UI wrapper 仍不改 firewall。新 UI timing smoke
为 64/64 policy success、P95 35ms、catalog 384ms、peak 570MiB；D048 又测得 cold start 8056ms、match-load 3969ms。
proposed profile 因此修订为 10s/6s，并保留当时的 proposed/non-A5 状态。管理员 OS-block 三局未执行；D057 后该 lane 由产品明确豁免，
仍不能写成 airplane/isolation/A5。工具作为可选诊断保留，证据见 `artifacts/ptcgdap/as_wp6_windows_os_isolation_tooling/`。
D048 又增加产品固定 `author_strategy_device_canary_approvals_v1` 与 exclusive Windows execution gate：approval 只绑定 exact production package/key、
Windows 和 W0–W7，不预先绑定未来 device/rollback/A5 hash；只有 `--ptcgdap-production-device-canary` 的 standalone export template 可激活，
request 后重验 captured catalog、exact archive/sealed handle 和 Marnie 60 张/28 local UID pins，任何失败都不回落 development。当前 store
`unprovisioned`，因此只证明首次设备取证执行边界和 fail-closed；proposed profile 修订后的当前树最终回归为 PtcgDAP Python
891/891（805.240 秒）、Godot AI 1494/1494（299.4 秒）和功能/UI 4972/4972（2631.2 秒）。focused live-seam runner 的 pre-test startup timeout 已由完整 AI lane
覆盖为通过，只保留为基础设施诊断。证据见 `artifacts/ptcgdap/as_wp6_windows_device_canary_tooling/`。
D049 在同一 Windows owner 的 policy response 边界补上 current observation/window 回绑：成功响应必须回显当前
`public_observation_hash`、`window_id` 与 `restricted_ir_same_window`，否则记为 `stale_policy_response`，忽略返回索引并只运行当前 option list
上的确定性 fallback。optional-zero 输出另保留 validity bit，非法非数组/越界/重复/错误基数记为 `invalid_policy_output` 而不再冒充成功空选择。
stale RED 8/9→GREEN 9/9、optional-zero RED 9/10→GREEN 10/10、Python boundary 9/9、PtcgDAP Python 893/893 与 Godot AI 1496/1496 已通过；证据见
`artifacts/ptcgdap/as_wp6_same_window_response_binding/`。这只加固 development/device-canary 共用 owner，不提升 production/A5 声明。
D050 在正式导出脚本中把 canonicalization 固定在 Godot export 与 inventory/runtime probe/hash 之间：两次完整导出的 ZIP/PCK/embedded EXE、
inventory、PCK runtime log 精确一致，runtime 22/22；规范化 EXE 又以 3/3 终局、182/182 policy success、179 commits 验证执行未受破坏。
证据见 `artifacts/ptcgdap/as_wp6_windows_deterministic_export/`。raw-container reproducibility 已关闭；该子门本身不关闭 product
signing/approval、OS-isolation、profile 或 A5，后两项随后由 D057 分别以批准与产品豁免收口。
D051 已建立作者 `.ptcgai` 之外的产品 `policy_package_v1`，canonical
`3243ABD7937B3F53D8E5D7A887FC90BFBDF9A4D94E4030A3A9BE194C82370FFC`。它保持 candidate archive SHA 不变，固定 deck/catalog/Base/
adapter/IR/config、实际 GDScript policy/Base/match owner/engine executor、trace、parent、rollback 与 Windows capability；match owner 创建前重验。
当前诚实声明 `learned_model=none`、`backend=none`，51-byte weights 是 `unused_non_model_payload`。编辑器 10 局为 918/918 success；新导出 EXE
3 局为 133/133 success、131 commits、0 error/invalid/fallback/rejection。证据见 `artifacts/ptcgdap/as_wp6_policy_package_v1/`；该子门不关闭
model-backed conformance、production trust、profile、A5 或 Android，OS-disconnection/profile 状态随后由 D057 独立收口。D051 的
release-parent/rollback identity 保持封口值，不因 D057 产品批准而重写；当前 production eligibility 由独立 release gate 校验新 bundle。
D052 已复用 sealed P5 owner 关闭当前声明 no-model subset 的 P6-02：Python/GDScript 都重算原 28-case corpus，再运行同一 8-case
order/float/default/unknown/fault/tie/reorder/unknown-operation probe，0 mismatch、0 skip；无 model/backend 时 operator case/skip 均为 0。
证据见 `artifacts/ptcgdap/as_wp6_policy_executor_conformance/`。该 acceptance owner 不接 engine，不关闭 P6-03、A2/A5 或 device/production 门。
D053 已用版本化 `local_policy_executor_v1` 关闭 P6-03 当前 Windows no-model GDScript baseline 子门。新 manifest canonical
`6961EEECEEB33459002A40A52AA76AB0243871439D3FDF10B9F1F4927AB6D6E0` 固定 D051 parent、exact archive、完整
contract/IR/config/catalog/weights/fallback closure 与实际实现；`LocalPolicyExecutor` 继承 sealed restricted-IR/Base 实现，match 创建时重验并编译
handle，active factory 为新局建立独立 local-executor owner。旧 D051 policy/owner 字节不变且可作为下一局回滚。Python 7/7、Godot focused
2/2、旧 owner regression 10/10 与 fresh exported ordinary-UI 终局均通过；后者为 59/59 policy success、59 commits、0 failure counters。
factory 切换后旧 D051/D044 owner 还按原 seeds 84400–84409 完成 10/10 真实规则终局、593/593 success、586 commits 与 0 failure counters，
因此上一完整 owner 的新局回滚已有执行证据，而不是只靠保留文件。最终完整回归为 PtcgDAP Python 931/931（810.411 秒）、
Godot AI 1496/1496（319.925 秒）和功能/UI 4976/4976（约 3077 秒）。
证据见 `artifacts/ptcgdap/as_wp6_local_policy_executor/`。这不关闭 model-backed lane、A2/A5、device/production 或 Android。
D054 的 `device_manifest_v1` 关闭 P6-04 当前 Windows 子门；D057 后当前版本为 1.1.0、canonical
`FCEEFEC13989C49A796905F98C099DF6E4C9C486773EA264250C75E0F39B8948`：唯一 declared target 是 Windows x86_64/
`windows-x86_64` ABI、Godot minimum 4.6.1 与 GDScript，D053 executor、no-model/no-backend、device-local/denied-network/
external-compute、exact approved non-A5 profile limits 与 D051 新局
rollback 均被 pin；Android arm64-v8a 明确 `declared=false`。开发运行不需要 key；D054 当时 production trust 为 `unprovisioned`，D070 后已有
独立产品公钥与 exact signed candidate，但本 device manifest 子门仍不等于 release approval。
Python 6/6、Godot 2/2 拒绝 target/network/resource/key/rollback 篡改。证据见 `artifacts/ptcgdap/as_wp6_device_manifest/`；profile/resources
随后由 D057 批准，但该子门不关闭 P6-06、production、A2/A5 或 Android。
D055 随后关闭 P6-07 当前 Windows 项目自有入口子门。`run_ptcgdap_windows_offline_entry.ps1` 不依赖 repo Skill，串行执行 fresh
Windows-only canonical build、D054 6-member inventory 重验、独立 standalone install exact-copy、install-root working directory 和 ordinary
real-mouse UI 完整对局。fresh run 为 58/58 policy success、58 commits、0 failure counters，installed EXE
`767C8AC08F64ADC35852677F6E62F155BD42717279AA259FDFD72ED15B1CD6FD`。它只证明 application-disabled + dead-proxy development entry，
不替代管理员 WFP/4688 OS isolation、production trust 或 A5；D057 后 OS-isolation lane 为产品豁免，profile 由独立批准证据关闭。证据见
`artifacts/ptcgdap/as_wp6_windows_offline_entry/`。
D056 随后以不可由调用者覆盖的 proposed Windows profile 对 D055 exact EXE 串行运行 3 局 ordinary-UI 与一次 feature-off rollback：
173/173 policy success、172 engine commits、0 failure counters，cold-start/catalog/match-load/decision-P95/peak/package 为
5252ms/305ms/2103ms/22ms/545MiB/262MiB，六项候选门全部通过。历史 qualification canonical identity 为
`A19C3CBB3AD8D5F9B0FA93C6D385982DBCF8D1F97F60D61D427DB5806E1150AE`；证据见
`artifacts/ptcgdap/as_wp6_windows_profile_qualification/`。
D057 再由产品批准同一固定 Windows 档，当前 profile canonical
`A8971FDEC09DE2B22DC131FEC35146A32013E6D7928BFDD46847B567B2B95169`、`formal_a5_eligible=false`，关闭 P6-05/P6-11；同时把
P6-08 固定为 `waived_by_product` 而不是 passed，`os_network_isolation_proven=false`。历史 D056 报告仍绑定批准前
`DEE312...8FF`，不得回写。D057 不配置 production key/trust/canary，不关闭 W0–W7、A5、production 或 Android；证据见
`artifacts/ptcgdap/as_wp6_windows_profile_approval/`。
D043 证明 exact 内置 archive 可由测试 Host 驱动真实规则引擎完成 10 局；D044 又证明 actual BattleScene 启动会建立独立 development
player owner，且该 owner 在真实规则引擎 10 局中无 classic fallback。D045 补齐 exported EXE headless development 整局，D046 再补齐
ordinary UI development 整局与工程回滚；它们本身不是 exported EXE OS-level disconnected/airplane acceptance，也不提供 profile 批准或
production authority。D056/D057 后资源档已另行批准，OS-disconnection 取证已产品豁免。
完整证据见 `artifacts/ptcgdap/as_wp6/`。

AS-WP6 原收口回归为 PtcgDAP Python `862/862`、Godot AI `1482/1482`、隔离用户目录功能/UI `4964/4964`；D043 新增 focused
`4/4`、Python evidence/boundary/governance `7/7`，并把 Godot AI lane 提升为 `1486/1486`。D044 focused 为 `6/6`、相关功能/UI
分组 `76/76`、完整 Godot AI lane `1492/1492`、完整 PtcgDAP Python discovery `872/872`（807.313 秒）；完整 FunctionalTestRunner
本轮在 1204 秒上限超时且未输出失败断言，不能记为全量通过。64-file
父快照 raw `BD468C68...7E69` / canonical `7B576808...5C2C` 与 74-path virtual rollback 重现 1836-entry AS-WP6
父工作树。Card ID 口径仍为 `godot_local_card_uid_v1` 游戏内稳定 UID；D044 只改变 exact candidate 的 Windows development start，
不改变 production ready=false 或 A5 未评估状态。

D045 最终收口已在同一运行时实现上补齐功能/UI `4969/4969`、Godot AI `1492/1492`、PtcgDAP Python
`878/878` 全量 GREEN；18.0 Dragapult Python 策略对现有 rules AI 的独立开发验收为 10/10 终局、1218/1218
调用成功且 0 timeout/error/invalid/fallback。该 Python lane 不是玩家 Windows 运行时依赖，D045 的 Marnie 导出 EXE 路径仍为纯本地
GDScript owner，二者的身份域和声明等级不得合并。

外部 production-signing workflow 已由 `tools/ptcgdap/sign_author_strategy_release_package.py` 实现：CLI 不接受 trust-store override，私钥必须
在仓库外且非 symlink，派生 public key 必须匹配固定 store 中指定且唯一的 active production key；同一 payload 先通过正式 loader，receipt
只含 public hashes。package/receipt 只允许独占新建，既有产物不可覆盖，双产物写盘失败会清理本次新建项；6/6 测试已通过。
D070 已配置专用产品公钥并签出 exact `ptcgdap.marnie.windows-local@0.1.0`，archive SHA-256
`AA65C8B46D2CEB0658EC18BB966F4DFECDB932750EDA3E65CD0B60208A08A0FD`；真实密钥复签逐字节一致。产品包仅在 evidence 路径，
Python/GDScript 均识别为 production trusted，但无 release approval 时精确拒绝为 `release_package_not_approved`，普通玩家启动仍关闭。

AS-WP6 仍未关闭：P6-03 Windows no-model GDScript baseline、P6-04 Windows device manifest、P6-06 product trust/signing 与 P6-07 Windows 项目入口已关闭，
但 official W0–W7 与外部批准门仍开放。product 必须先为 exact production package 生成并批准 source-locked pre-canary report，再写入独立 canary
approval record；D048 已实现仅验收参数激活、只接收 production-signed exact package 的
device-canary 路径且普通 production player start 保持关闭；随后仍须在
exported Windows EXE 上完成 airplane-mode ordinary UI 到终局、批准资源、fallback/rollback、official W0–W7 conformance 与 A5。D045 的
headless complete-match 不能替代这些门，其他开发 owner、导出 inventory、PCK probe 或 W1 canary 同样不能替代。
Android release keystore、物理 arm64、温度/电量和 Android A5 已后移到未来 Android 适配工作包。

## 7. `.ptcgai` 合同必须锁死的细节

### 7.1 文件与哈希关系

避免自包含 hash 环：

```text
strategy_package.json
  does not contain archive hash

files.sha256.json
  lists every payload file except files.sha256.json and signature.json

signature.json
  signs canonical package identity + manifest hash + files-manifest hash

archive_sha256
  computed outside the archive by catalog/installer and used in match identity
```

所有 path 使用 `/`、ASCII 受限文件名、无 `.`/`..`/空段/反斜杠/绝对路径/盘符/重复规范路径。ZIP entry 顺序、压缩参数、timestamp、permissions 和 comment 必须 deterministic。

### 7.2 身份

建议精确 identity：

```text
package_id
package_version
archive_sha256
manifest_sha256
policy_ir_sha256
deck_manifest_sha256
```

`author_display_name`、`strategy_display_name`、deck title、icon 和 summary 永远不是 authority。

### 7.3 允许内容

允许：strict JSON、固定 CSV、受限 IR/config、声明的 weights、PNG/WebP、README、LICENSE。

拒绝：`.gd/.py/.pck/.exe/.dll/.so/.aar/.jar/.sh/.bat/.ps1`、嵌套压缩包、脚本入口、动态库、网络地址、包外路径和未列文件。

资源常量必须集中定义在 profile，不得散落在 Python/GDScript。第一版冻结前至少决定 archive bytes、uncompressed bytes、entry count、path bytes、单文件 bytes、image dimensions 和 compression ratio 上限，并用边界向量双端验证。

### 7.4 签名

caller 不能传 `trusted_hash` 或 `accept_any_key`。信任根来自产品固定 trust store；内置开发 key、正式发布 key 和用户未签名包必须是不同状态。未签名包首版只能 `untrusted/metadata_only`，不能因为 UI 勾选而获得执行权。

### 7.5 稳定错误码

至少关闭：

```text
package_file_missing
package_archive_invalid
package_path_invalid
package_duplicate_path
package_file_unlisted
package_file_hash_mismatch
package_signature_untrusted
package_manifest_invalid
package_identity_conflict
package_contract_incompatible
package_catalog_incompatible
package_deck_unmapped
package_policy_unsupported
package_resource_limit_exceeded
package_integrity_invalid
```

错误优先级建议：archive/path/resource → manifest/type → file/hash → signature → compatibility → deck/policy → runtime integrity。两端必须一致。

## 8. Catalog API 与数据边界

建议 autoload 公开最小 API：

```gdscript
signal catalog_ready()
signal catalog_changed()
signal package_rejected(package_ref: String, error_code: String)

func refresh_catalog() -> void
func list_packages() -> Array[Dictionary]
func get_package(package_id: String, version: String, archive_sha256: String) -> Dictionary
func request_match_handle(package_id: String, version: String, archive_sha256: String) -> Dictionary
```

`list/get` 只返回深拷贝 metadata：

```text
package_id
package_version
archive_sha256
author_id
author_display_name
strategy_display_name
summary
deck_display_name
compatibility_status
install_source
error_code
presentation_asset_ref
```

不得返回 ZIPReader、FileAccess、raw manifest mutable reference、policy object、weights、trust key 或 match handle。`request_match_handle` 必须重新开 archive、捕获 bytes、完整重验并返回 owner-produced handle；不能把 startup record 提升成 handle。

扫描根固定为：

```text
res://data/ptcgdap/author_strategy_packages/
user://ptcgdap/author_strategy_packages/
```

首版不要扫描下载、桌面、任意 mod 目录或网络 URL。

## 9. GameManager 与 UI 的建议实现

### 9.1 GameManager

新增：

```gdscript
VS_AUTHOR_STRATEGY_AI
```

新增 setup-only copy record，至少含：

```text
package_id
package_version
archive_sha256
display_name_snapshot
install_source
```

提供 `reset_author_strategy_selection()` 和 copy-in/copy-out getter。该 record 不是 authority；`goto_battle()` 前必须由 catalog 换成完整 handle。不要保存 raw handle、ZIP reader 或 policy owner到通用 settings JSON。

`resolve_selected_battle_deck(1)` 不应直接从 package metadata 返回旧 AI deck。作者模式的对手 deck 必须来自已验证 match handle 的 deck adapter；若 match handle 尚未建立则返回 null/拒绝开战。

### 9.2 BattleSetup

最小 UI 节点建议：

```text
ModeAuthorStrategyButton
AuthorStrategyPickerButton or Option
AuthorStrategyTitle
AuthorStrategySubtitle
AuthorStrategyAuthor
AuthorStrategyStatusBadge
AuthorStrategyDescription
AuthorStrategyIcon
```

模式逻辑不得用“非 0 就是 VS_AI”。使用显式映射：

```text
0 -> TWO_PLAYER
1 -> VS_AI
2 -> VS_AUTHOR_STRATEGY_AI
```

作者模式：

- player deck 仍来自玩家 deck list；
- opponent selection 来自 package catalog；
- Deck2 old option 与 AI strategy variant controls 隐藏；
- ready package 才启用开始；
- package 列表更新时按 stable identity 保留选择，不能按 display text；
- 切回经典 AI 后恢复原控件和原选择，不污染 `ai_deck_strategy`。

保存设置只保存 stable package ref。包不存在时恢复为未选择，不自动挑同名包。

## 10. Battle owner 对接策略

### 10.1 不要做的捷径

- 不要让 `PtcgDAPAuthorMatchHost extends AIOpponent`；
- 不要实现一组假的 `run_single_step/get_legal_actions` 适配器来读取 private GameState；
- 不要在 `BattleAiOpponentFactory` 的 fallback 链里加 package branch；
- 不要把 serialized P5 result 直接当选择或 ticket；
- 不要让包直接调用 engine method；
- 不要用旧 raw-state legacy AI 作为作者模式异常 fallback。

### 10.2 推荐 seam

`BattleDecisionOwnerFactory` 只负责模式级分流和构造：

```text
TWO_PLAYER -> no AI owner
VS_AI -> existing BattleAiOpponentFactory
VS_AUTHOR_STRATEGY_AI -> PtcgDAPAuthorMatchHost
```

对 BattleScene 不先抽“大一统 AI 接口”，而是按 prompt 生命周期建立小 seam：

```text
is_author_owner_ready()
open_current_prompt(prompt_source)
request_current_selection()
commit_current_selection()
abort_current_prompt(error_code)
```

参数必须是 exact prompt-source wrapper/owner capability，不是公开 Dictionary。返回成功只能是当前窗口 indexes 或 owner-produced claim。UI/runtime 再通过既有 EngineDecisionPort/binding/ticket/executor 处理。

### 10.3 第一条 shadow 接线

先选择一个 source-locked、已在 P5 覆盖的非执行 prompt。BattleScene 生成当前 prompt source，同时：

- 经典 AI 继续正常行动；
- 作者 Host 在旁路生成 public observation/window/index audit；
- 不把作者 indexes 交给 engine；
- 比较 Python/GDScript/package expected；
- 不读取经典 AI 的 private plan 或 chosen action作为 policy input。

shadow 轨迹稳定后再选择一个可逆、可重验的 setup prompt进入 canary。

## 11. 测试顺序

### 11.1 RED 顺序

1. package contract/module missing；
2. valid golden load；
3. path/hash/signature/resource invalid vectors；
4. Godot/Python metadata parity；
5. catalog startup metadata-only；
6. UI third mode and classic separation；
7. match-time replace/tamper rejection；
8. shadow Host same-window output；
9. one prompt canary；
10. complete W0–W7 and device package。

不能先做漂亮 UI 再补 security/contract。

### 11.2 Python targeted

示例：

```powershell
python -m unittest tests.ptcgdap.test_author_strategy_package_contract -v
python -m unittest tests.ptcgdap.test_author_strategy_package_loader -v
python -m unittest discover -s tests/ptcgdap -p "test_*.py" -q
python -m compileall -q scripts/ai/ptcgdap tools/ptcgdap tests/ptcgdap
```

### 11.3 Godot focused

```powershell
powershell -ExecutionPolicy Bypass -File scripts/tools/run_godot_tests.ps1 `
  -Runner focused `
  -SuiteScript res://tests/ptcgdap/godot/test_author_strategy_package_catalog.gd
```

之后依次跑 battle setup、match host focused。测试文件命名 `test_*.gd` 会进入 TestSuiteCatalog；再跑对应 functional suite，最后才跑完整适用 Godot regression。

### 11.4 必须覆盖的负例

- duplicate JSON key、BOM、float、unsafe int、StringName/typed container；
- `../`、反斜杠、绝对路径、大小写 collision、重复 ZIP path、未列 extra file；
- whitespace-only canonical equivalence与 raw archive identity 的区别；
- manifest 自洽重签但产品 trust anchor 不匹配；
- startup cache 后替换 archive；
- 同 ID/version 不同 archive；
- metadata mutability/普通 `Object.set`/internal rebaseline；
- 包内脚本/native executable；
- deck 59/61、unknown Card ID、unmapped local printing、Attack owner/order drift；
- old window、old match、cross-owner、hot swap、policy exception/timeout/illegal indexes；
- hidden sentinel、callback、ticket、engine object 不得回显；
- classic AI setup/factory/tournament/training 行为不变。

## 12. 证据与回滚

每个工作包至少提供：

```text
work_package.json
manifest.json
source_lock_snapshot.json
contract_hashes.json
fixtures_manifest.json
test_commands.txt
test_results.json
diff_report.json
applicability.json
rollback_report.md
known_gaps.md
parent_snapshot/manifest.json
parent_snapshot/*.base64
```

证据必须区分：contract、metadata discovery、shadow output、live execution、device packaging。UI 可选不等于 live 可执行；schema pass 不等于受信；Windows headless 不等于 Android A5。

回滚：

- 恢复所有被改既有文件 exact parent bytes；
- 删除本包新增代码/合同/tests/evidence；
- 关闭 autoload/feature flag/UI；
- 不删除 `user://.../*.ptcgai` 用户文件；
- 重跑经典 BattleSetup、BattleAiOpponentFactory、tournament/training launch 与 PtcgDAP 全 regression；
- 进行中的作者局不得热切到 classic owner。

## 13. 高风险陷阱

1. `BattleScene.gd` 是薄壳，真正耦合在 runtime mixin；只搜一个文件会低估工作量。
2. `_apply_setup_selection()` 当前“非 0 即 VS_AI”，新增第三模式后必须改成显式映射。
3. `_is_ai_mode()` 不能简单把两种 AI 合并后复用所有 UI；控制权相似，数据源和 owner 不同。
4. `BattleAiOpponentFactory` 的 default fallback 对 classic 合理，对作者模式是架构违规。
5. `data/**` 被多数 preset include，不代表 contracts/signatures/weights 的最终包可用性已经证明。
6. Godot Object 字段可被普通 `set()` 改写；自生成 runtime digest 可被重基线，必须使用固定 trust root/完整关系重验。
7. ZIP canonical content hash 与 raw archive hash是两个域；ZIP whitespace/ordering/timestamp不能混淆。
8. 显示名、Card name、set alias、image/text 不能做 identity bridge。
9. 现有 P5 DTO 大多只是 audit；不要把它们提升成 live authority。
10. 每次 public lookup 全量重算巨大 catalog/package digest可能在 Godot/Android不可用；构造时完整验证、hot path使用有界不可变关系，另保留显式 full audit。
11. 作者包里的 deck 是 AI deck authority，不能再次让玩家在旧 AI deck picker 中任意替换。
12. 未覆盖的 prompt 不能局中 fallback classic；应赛前标 incompatible 或保持整个模式 shadow。

## 14. 接手者第一天执行清单

- [x] 读完必读链和本文；
- [x] 保存 `git status --short`，确认不触碰用户改动；
- [x] 读 `STATUS.md` 当前唯一游标；
- [x] 检查/完成 P5-WP7 前置；
- [x] 新建 AS-WP0 work package；
- [x] 列 exact files_allowed 与 owner boundary；
- [x] 为预计修改父文件生成 exact snapshot；
- [x] 写 parent virtual rollback test；
- [x] 写 package module missing RED；
- [x] 只实现 AS-WP1，未过 exit 不并行 UI/live；
- [x] 每个 GREEN 后记录命令、版本、计数、日志 hash 和 known gaps；
- [x] 只实现 AS-WP2 Godot loader/catalog，未过 exit 不并行 BattleSetup/BattleScene/live；
- [x] 只实现 AS-WP3 BattleSetup 独立模式与 metadata UI，未过 exit 不并行 match Host/BattleScene/live。
- [x] 只实现 AS-WP4 match-time revalidation、immutable handle、exact deck gate 与 shadow Host，未过 exit 不并行 live/canary。
- [x] AS-WP5 已为 W1 `setup_active` 接通 current-window/binding/ticket/engine seam；W2 仅 fresh reobserve，其余 prompt 保持 shadow。
- [ ] 继续 AS-WP6；D070 已完成 product trust/signing，当前按 D069 顺序完成 exact-package pre-canary official W0–W7 report/approval →
  device-canary approval/run → 独立 A5/release review；D045/D050 已关闭
  headless development complete-match 子门，不得借 D044/D045 开启 production live；Android 按 D041 后续独立适配。
  正式 device report builder 已完成 actual-file hash、样本统计重算、固定 profile 和 exclusive-output 门；当前 profile 已批准但
  `formal_a5_eligible=false`，所以 builder 仍拒绝当前仓库的 A5 report。
  D047 又完成五类证据语义绑定与管理员 WFP/4688 验收器；D057 已明确该系统隔离 lane 对当前产品门不再必需，但不得声明 isolation proven。
  D048 已完成 production-signed acceptance-only canary 合同与执行入口；当前 active product key 为 1，但 canary/prompt/release approval 仍为 0，
  尚无 positive canary/formal report，仍不得勾选。
  D050 已关闭固定 Godot 4.6.1 Windows raw-container reproducibility，不替代本项外部 trust/device 门。
  D051 已关闭 P6-01 首个 Windows immutable manifest/no-model 子门；D052 已关闭当前 no-model portable subset 的 P6-02；D053 已关闭
  P6-03 当前 Windows no-model GDScript baseline 子门；D054 已关闭 P6-04 当前 Windows device-manifest 子门，D055 已关闭 P6-07 当前 Windows
  项目入口子门；D056/D057 已关闭 P6-05/P6-11 并把 P6-08 记为产品豁免；D069 已关闭 P6-39 evidence-hash binding，D070 已关闭 P6-06
  产品 trust/signing。未来 model-backed P6-09、实际 official conformance、A5 与 production 总门仍开放。

## 15. 首次可交付定义

最早可向用户展示、但仍不执行对战的 milestone：

- 游戏启动可发现一个受信 synthetic `.ptcgai`；
- BattleSetup 出现“作者策略”模式；
- 卡片显示作者、策略名、牌组、版本和状态；
- classic AI 控件不混入；
- 点击开始被明确的 `metadata_only/not_live_ready` gate 拒绝；
- valid/invalid package、UI 状态和回滚都有自动化证据。

首次 development 可执行 Windows milestone 已由 D044 对 exact 内置 Marnie 候选完成：完整本地 deck mapping、match-time verification、
same-window policy、独立 owner/engine seam 与真实规则引擎整局均有证据；D045 又证明 fresh-user-root exported EXE 可完成 headless
三局。D056/D057 已补齐固定 Windows 性能档的实测与产品批准，并明确豁免 airplane/WFP 取证；D070 已完成专用产品信任与 exact package signing。
首次可发布 Windows milestone 仍必须增加 official W0–W7 conformance、canary/package approval、回滚和独立 release/A5 review。Android 以后重复同级独立验收。

## 16. 可直接交给实施 Agent 的启动指令

```text
你负责 PtcgDAP 的“作者策略包模式”。先严格阅读根 AGENTS.md 规定的全部文档，重点阅读
08-author-strategy-package-mode.md、09-author-strategy-package-engineering-handoff.md 和 STATUS.md。
不要假定当前允许 live；先确认 next_permitted_work，并保护现有 dirty worktree。

AS-WP0 至 AS-WP5 已完成并有 sealed evidence；从 STATUS.md 当前游标 AS-WP6 继续。D044 已只为 exact 内置 Marnie 候选打开 Windows
development BattleSetup/owner 路径，D045 已关闭 exported-EXE headless development 三局子门，D050 已关闭固定 Windows raw-container
reproducibility；它们不授权 production live。未通过
production 签名/approval、official W0–W7、rollback 与 Windows A5 前不得打开正式 ready 门。D056/D057 已完成批准资源，OS 级断网
取证已产品豁免但不形成 isolation proof。Android 按 D041 后续独立适配。包禁止任意
GDScript/Python/native executable，
显示名不授权 identity，caller 不得传 trust hash，所有失败必须稳定 fail closed。
首个 Windows runtime 另由 D051 `policy_package_v1` 固定全部策略/执行/父链 hash，并明确 `learned_model=none`；不得把未调用 weights
写成模型已运行。

每次交付报告：实现了什么、仍是 shadow 还是 live、精确测试命令/计数、hash、known gaps、rollback、
alignment level 和下一唯一允许工作。不得声称高于实际证据。
```
