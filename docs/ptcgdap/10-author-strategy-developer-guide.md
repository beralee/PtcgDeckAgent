# 作者策略开发者指南

## 1. 适用范围

本文面向需要为 PtcgDAP 开发、修改和验证 `.ptcgai` 作者策略的开发者，给出一条可以直接执行的 Windows 工作流：

```text
创建工作区 → 修改受限策略数据 → 确定性构建 → 严格校验 → 安装到开发目录 → 公开窗口模拟 → Godot 规则回归
```

当前可自助完成的是：

- 从已集成的 Marnie 18.0 长毛巨魔包建立可编辑工作区；
- 修改作者信息、策略说明、受限 IR、adapter 规则、config 和未执行的 weights payload；
- 在不准备私钥的情况下生成 test-fixture 签名开发包；
- 把严格校验后的开发包安装到当前 Windows 用户的 Godot 固定策略目录，使 BattleSetup 作者策略列表可以发现它；
- 使用真实 Python 公共边界运行当前窗口模拟，查看命中规则、提案顺序和最终索引；
- 对仓库已集成的 exact Marnie 候选运行 Godot 真实规则对战与完整回归。

当前不能自助完成的是：

- 把任意新包直接放进玩家 production 列表；
- 为一个尚未审核的新牌组自行声明完整本地 Card UID、卡效或引擎一致性；
- 用显示名、卡名或官方 Card ID 猜测本地卡牌身份；
- 绕过 exact archive、产品签名、release approval、device canary 或 A5 门；
- 把 Python、GDScript、DLL、EXE 或其他可执行代码塞入 `.ptcgai`；
- 把开发模拟结果声明为 CABT export、正式 live、官方引擎一致性或 A5。

当前平台范围只有 Windows x86_64 / Godot 4.6.1。Android 延后；OS 断网取证由产品豁免，但
`os_network_isolation_proven=false`，不能写成验证通过。

## 2. 最重要的心智模型

作者策略不是一个能调用游戏对象的脚本。包只提供数据，游戏内置执行器拥有全部执行权：

```text
raw observation
  → public-information firewall
  → immutable current select window
  → public strategic context
  → restricted Base Graph
  → author adapter ordering hints
  → list[int]（当前窗口索引）
  → Host 重验、ticket、engine commit
```

公共策略边界仍是：

```text
agent(raw_observation) -> list[int]
```

`.ptcgai` 作者不直接实现任意 Python/GDScript `agent` 函数，而是用 `policy_ir.json`、`adapter.json` 和 `config.json`
声明受限行为。内置 Host 把这些数据编译为同一个边界。

必须始终遵守：

1. 返回值只能是当前 `select.option` 的索引；
2. 任何一次选择后都必须重新观察，旧窗口索引不可复用；
3. adapter 只能在 Base Graph 允许的同层合法选项之间提供排序提示；
4. Base Graph 保留合法性、强制/终局保护、veto、fallback 和最终决策权；
5. 策略看不到 `GameState`、`BattleScene`、对象引用、对手隐藏手牌、牌库顺序、盖放奖赏或私有 RNG；
6. 模拟报告是 public-only audit，不是 engine authority。

## 3. 环境准备

从仓库根目录 `D:\ai\code\PtcgDAP` 执行命令。最低开发环境：

- Windows；
- Python 3.13，且仓库依赖已安装；
- Godot 4.6.1，用于真实规则和 UI 回归；
- 不需要 production key；
- 不需要外部 Python 服务、推理服务器或联网运行时。

先做轻量自检：

```powershell
python tools/ptcgdap/author_strategy_developer.py --help
python tools/ptcgdap/build_author_strategy_package.py --check-contracts
```

## 4. 五分钟完整路径

以下命令会从当前已集成的 Marnie 包创建工作区、构建开发包、校验、安装并模拟“魔灵珊进化”窗口。

选择一个尚不存在的工作区目录：

```powershell
$work = ".tmp/author-strategy-dev-marnie"
```

### 4.1 创建工作区

```powershell
python tools/ptcgdap/author_strategy_developer.py scaffold `
  --output $work `
  --report "$work-scaffold-report.json"
```

`scaffold` 不覆盖已有目录。输出结构为：

```text
author-strategy-dev-marnie/
  package/
    strategy_package.json
    README.md
    LICENSE
    deck/
      deck_manifest.json
      deck.csv
    policy/
      policy_ir.json
      adapter.json
      config.json
      weights.bin
  scenarios/
    morgrem-evolve.json
  build/
```

`package/` 中不会出现 `files.sha256.json`、`signature.json` 或私钥；前两者由构建器生成，开发测试密钥是固定、公开、
不可晋升的夹具材料，不由作者管理。

### 4.2 构建确定性开发包

```powershell
python tools/ptcgdap/author_strategy_developer.py build `
  --source "$work/package" `
  --output "$work/build/marnie-dev.ptcgai" `
  --report "$work/build/build-report.json"
```

构建器会：

- 只接受允许的固定路径；
- 拒绝 symlink、额外文件、脚本、native executable 和嵌套压缩包；
- 生成规范化 `files.sha256.json`；
- 使用固定 test-fixture Ed25519 材料生成开发签名；
- 固定 ZIP 顺序、时间、权限和压缩方式；
- 立即用正式严格 loader 重新读取输出；
- 校验精确 60 卡 deck、本地 UID、卡源 hash、IR、adapter 和 config；
- 在发布输出前调用与运行 Host 相同的 `PtcgDAPAuthorMatchHost.create` 编译路径；
- 明确输出 `execution_trusted=false`、`production_ready=false`。

不需要传 `--private-key` 或 `--key-id`。低层 `build_author_strategy_package.py --source` 的显式 key 参数只服务合同和
内部测试；作者日常开发应使用本工作台。

为了避免误覆盖证据，`build` 不覆盖已有输出。再次构建时使用新的版本化文件名或先由开发者明确处理旧的生成文件。

### 4.3 严格校验

```powershell
python tools/ptcgdap/author_strategy_developer.py validate `
  --package "$work/build/marnie-dev.ptcgai" `
  --report "$work/build/validate-report.json"
```

成功报告至少包含：

```text
status=valid
signature_status=test_fixture_trusted
execution_trusted=false
production_ready=false
card_id_domain=godot_local_card_uid_v1
deck_card_count=60
deck_unique_printing_count=28
policy_preflight.accepted=true
policy_preflight.owning_layer=PtcgDAPAuthorMatchHost.create
policy_preflight.stage=compile_policy
policy_preflight.invalid_local_card_uids=[]
```

`validate` 不再只停在 ZIP、签名和 deck manifest。它会把整副牌的 UID 集、IR 和 adapter 交给与 Host 相同的编译入口；若失败，CLI
错误报告的 `diagnostic` 只按 allow-list 发布 owning layer、stage、稳定错误码和具体失败 UID，不回显任意包内容。

### 4.4 安装到 Godot 开发目录

```powershell
python tools/ptcgdap/author_strategy_developer.py install `
  --package "$work/build/marnie-dev.ptcgai" `
  --report "$work/build/install-report.json"
```

`install` 会先重新执行严格校验，再原子写入固定目录
`%APPDATA%\Godot\app_userdata\PtcgDeckAgent\ptcgdap\author_strategy_packages`。同一 `package_id + package_version`
已存在不同 archive hash 时会以 `developer_install_identity_conflict` 拒绝，避免 catalog 因版本身份冲突而把两个包一起隔离。

安装报告固定包含 `catalog_discoverable=true`、`catalog_status=metadata_only`、`player_start_allowed=false` 和
`catalog_reload_required=true`。关闭并重新打开游戏后，可在 BattleSetup 的“作者策略对战”列表中查看开发包；`install` 本身不会让
test-fixture 获得开战或 production 权限。若包已以完全相同字节安装，命令幂等成功并返回 `already_installed=true`。

玩家开战是另一个独立门。当前仓库只审核了两个 exact、built-in、Windows-only development candidate：Marnie 与
`ptcgdap.cynthia-garchomp-800018543.windows-local@0.1.0`（archive SHA-256 `3059C308...8FF06`）。竹兰包的相同用户副本会在 catalog
去重时由 built-in 记录取得优先级；重启后按钮显示“开始 Windows 开发对战”。任何其他安装包、不同 hash、user-only 来源、Android 或 production
请求仍 fail closed。这个例外保持 `execution_trusted=false`、`production_ready=false`，不能作为通用作者包发布流程。

### 4.5 运行公开窗口模拟

```powershell
python tools/ptcgdap/author_strategy_developer.py simulate `
  --package "$work/build/marnie-dev.ptcgai" `
  --scenario "$work/scenarios/morgrem-evolve.json" `
  --report "$work/build/simulation-report.json"
```

默认场景应得到：

```text
status=passed
frontier.decision_state=policy_allowed
adapter.matched_rules[0].rule_id=marnie.morgrem.evolve
decision.selected_indexes=[1]
adjudication.selected_source=adapter_proposal
adjudication.adapter_preference_applied=true
adjudication.deterministic_fallback_used=false
expectation.matched=true
claims.engine_execution=false
claims.production_authority=false
```

这条模拟不是自造的规则解释器。它实际调用当前 Python 的 CABT envelope parser、public firewall、`CabtSelectionWindow`、
`StrategicContextCompiler`、local-UID adapter compiler、Base Graph orchestrator 和 `PtcgDAPAuthorMatchHost`。工具只把 Host 拥有的
context/window hash 自动补入临时 local-UID public context，作者场景不能提供或覆盖这些 authority 字段。

## 5. 逐个文件开发策略

### 5.1 `strategy_package.json`

负责包身份、展示信息、路径和兼容性。运行时身份是：

```text
package_id + package_version + archive_sha256
```

编辑建议：

- `package_id` 使用稳定反向域名 slug，例如 `dev.example.marnie-control`；
- 每次改变可分发行为都提升 `package_version`；
- `display_name` 和 `summary` 只用于 UI，不能参与规则或卡牌映射；
- 保留当前固定 `minimum_game_api` 与三个 compatibility hash；
- 不手工添加未知 capability；
- `policy.entry_kind` 当前只能是 `restricted_policy_ir_v1`。

### 5.2 `deck/deck.csv`

Windows 本地域固定表头：

```csv
local_card_uid,count
```

`local_card_uid` 是游戏内稳定印刷 UID：

```text
set_code + "_" + card_index
```

例如：

```text
CSV10C_146
CSV8C_094
CSV9.5C_043
SVP_105
```

语法固定为 `^[A-Za-z0-9.]+_[A-Za-z0-9]+$`：集合代码不要求以 `C` 结尾，`SVP_105` 因而是合法 UID；连字符、多个下划线、
空组件和 `PRIVATE` sentinel 均非法。集合代码与卡号组件各不超过 32 个字符，总长不超过 64。它不是官方 Card ID，也不是卡名、
翻译名、Godot object ID 或图片文件名。CSV 必须正好 60 张，并按 ASCII UID 排序。

### 5.3 `deck/deck_manifest.json`

manifest 固定每个 UID 的：

- 数量；
- `set_code` / `card_index`；
- card type / stage；
- effect ID；
- 卡源 raw/canonical SHA-256；
- 源 deck raw/canonical SHA-256；
- deck CSV SHA-256；
- `platform_scope=["windows"]`；
- `cabt_exportable=false`。

不要在修改策略时顺手改 deck manifest。当前开发工作台默认针对已审核的 Marnie 牌组。若需要新牌组，先走第 11 节的
“新牌组接入”流程，由维护者建立 exact local mapping、卡效审计和新的受控候选；不能复制 Marnie hash 后改显示名。

### 5.4 `policy/policy_ir.json`

IR 是受限、线性的 Base Graph。节点只能来自两类 owner：

- `base`：合法性、强制/终局、层级、veto、fallback、最终输出；
- `adapter`：目标、macro 和同层 tie-break 提案。

当前 Marnie IR 顺序为：

```text
legality_guard
→ mandatory_terminal_guard
→ macro_proposal
→ hard_tier_filter
→ base_veto
→ deterministic_fallback
→ emit_decision
```

约束：

- `entry_node_id` 必须是第一个节点；
- `next_node_ids` 必须形成固定单链；
- adapter 不能省略 Base 保护节点；
- adapter 不能拥有 `emit_decision`；
- 不能增加脚本名、回调、命令、URL、private state 或对象引用；
- `macro_ids` 应与 adapter 的 `rule_id` 精确对应。

多数作者只需修改 `adapter.json`，不需要改 IR 拓扑。

### 5.5 `policy/adapter.json`

每条规则形状固定为：

```json
{
  "rule_id": "marnie.morgrem.evolve",
  "operator": "macro_proposal",
  "reason_code": "public_macro_proposal",
  "goal_stage": "deploy",
  "priority": 0,
  "predicate": {
    "select_type_raw": null,
    "select_context_raw": null,
    "option_type_raw": 3,
    "option_card_id": "CSV10C_146",
    "option_player_index": null,
    "acting_hand_card_id": "CSV10C_147",
    "acting_active_card_id": null
  }
}
```

允许的 `operator`：

| operator | reason_code | 含义 |
|---|---|---|
| `goal_proposal` | `public_goal_proposal` | 对公开目标给出同层排序提示 |
| `macro_proposal` | `public_macro_proposal` | 对一个公开、可重绑定的动作 macro 给出提示 |
| `tiebreak_score` | `public_tiebreak_proposal` | 对仍然同层的合法项提供 tie-break |

允许的 `goal_stage`：

```text
acquire, deploy, fund, ready, execute, maintain, recover
```

predicate 语义：

- `null` 表示该字段不参与匹配，不表示实际值必须为空；
- `select_type_raw` / `select_context_raw` 来自当前官方选择窗口；
- `option_type_raw` / `option_player_index` 来自当前 option；
- `option_card_id` 在 Windows 本地域中是当前 option 的游戏 UID；
- `acting_hand_card_id` 要求行动方公开手牌中存在该 UID；
- `acting_active_card_id` 要求行动方公开 active 中存在该 UID；
- 所有非空 UID 都必须存在于本包 deck manifest；
- `priority` 越小越靠前；同 priority 按 adapter 中的规则顺序，再按 option index 稳定排序。

规则只是 ordering hint。即使命中，Base Graph 仍可因 mandatory、terminal、hard tier 或 veto 拒绝它。

### 5.6 `policy/config.json`

当前 Windows 本地配置必须固定：

```text
card_id_domain=godot_local_card_uid_v1
platform_scope=windows
cabt_exportable=false
deck_manifest_sha256=<当前 deck manifest raw SHA-256>
source_deck_id=800018501
```

`source_deck_id` 是既有 v1 已签包保留的构建来源备注，不是安装前置、运行时身份或牌组查询键。Host 不会查找同编号的用户/内置牌组；
实际 60 张牌只由 `deck.csv` + deck manifest 决定，并按 `set_code + "_" + card_index` 逐张验证。新工具不得重新引入
`CardDatabase.get_deck(source_deck_id)`。如果修改了 deck manifest，必须重新计算并同步 hash；普通策略规则修改不需要改它。

### 5.7 `policy/weights.bin`

当前 D051/D054 明确：

```text
learned_model=none
backend=none
learned_model_invoked=false
```

现有 `weights.bin` 是未使用 payload，只用于证明包体和 hash closure；不要把它写成已运行的模型。未来模型后端需要独立 ABI、
许可、资源、A2/A5、package 和 rollback 审查。

## 6. 模拟场景接口

场景文档类型为：

```text
author_strategy_developer_scenario_v1
```

顶层字段是闭合的：

```json
{
  "document_type": "author_strategy_developer_scenario_v1",
  "schema_version": 1,
  "scenario_id": "marnie-morgrem-evolve",
  "raw_observation": {},
  "prompt": {},
  "local_uid_bindings": {},
  "expected_selected_indexes": [1]
}
```

### 6.1 `raw_observation`

使用官方 CABT wire shape。模拟器首先通过 strict envelope parser 和 public firewall；未知字段、错误枚举、float、unsafe integer、隐藏字段
污染或非法选择形状会被拒绝或降为 fallback-only。报告不会回显 raw observation。

option 必须使用对应类型的真实稀疏形状，不能给所有类型都套上 `area/index/playerIndex`。例如：

```json
{"type": 7, "index": 1}
{"type": 13, "attackId": 1}
{"type": 14}
```

攻击 option 缺少 `attackId` 会被当前窗口门降为 `developer_current_window_fallback_only`；这类失败发生在策略编译之前。

### 6.2 `prompt`

固定字段：

```text
prompt_id
prompt_generation
mandatory_indexes
terminal_indexes
base_hard_tiers
base_vetoed_indexes
```

这些值代表 Base Graph authority，不是 adapter authority。开发场景可以构造它们以覆盖边界，但真实游戏中由 Host 产生。

### 6.3 `local_uid_bindings`

固定字段：

```text
options
acting_hand
acting_active
```

示例：

```json
{
  "options": [
    {"index": 0, "local_card_uid": null},
    {"index": 1, "local_card_uid": "CSV10C_146"}
  ],
  "acting_hand": [
    {"serial": 30, "local_card_uid": "CSV10C_147"}
  ],
  "acting_active": [
    {"serial": 10, "local_card_uid": "CSV10C_148"}
  ]
}
```

开发者只写公开绑定，不写 `context_hash` 或 `window_id`。模拟器在 firewall/window/context 全部成功后，用当前 owner 产生的 exact hash
构造临时 local context。未知 UID、错误 serial、错误 option index、跨窗口或隐藏 sentinel 会 fail closed。

### 6.4 `expected_selected_indexes`

这是测试断言，不是强制策略输出。实际输出不同则：

```text
status=failed
error_code=simulation_expectation_failed
```

报告同时保留 expected 与 actual，退出码为 2。验证错误退出码为 1；通过为 0。

### 6.5 读模拟报告

重点字段：

| 字段 | 用途 |
|---|---|
| `frontier.decision_state` | 必须为 `policy_allowed` 才会调用策略 |
| `frontier.option_count` | 当前唯一合法行动前沿大小 |
| `adapter.matched_rules` | 哪些规则匹配了哪些 option indexes |
| `adapter.proposals` | 各 operator 提供的稳定排序 |
| `decision.selected_indexes` | 真实 Host/Base 输出 |
| `decision.trace_hash` | 本次决策的 public trace 身份 |
| `adjudication.forced_owner` | `terminal`、`mandatory` 或 `none` |
| `adjudication.minimum_hard_tier` | 无 forced frontier 时 Base 保留的最低层级 |
| `adjudication.base_vetoed_indexes` | Base 明确否决的 indexes |
| `adjudication.selected_source` | terminal、mandatory、adapter proposal、deterministic fallback 或合法 optional-zero |
| `adjudication.candidates[].elimination_reasons` | 每个候选因 forced/tier/veto/cardinality 落选的公开原因 |
| `expectation.matched` | 场景断言是否命中 |
| `claims` | 明确本次没有引擎或 production authority |

报告有意不包含 raw observation、私有状态、callback、ticket、engine command、对象引用或密钥材料。

## 7. 推荐的策略迭代方式

每条行为规则使用独立场景，并按 RED→GREEN 工作：

1. 复制一个场景并改 `scenario_id`；
2. 构造当前公开观察、option 和 local UID bindings；
3. 先写期望索引；
4. 运行 `simulate`，确认先失败；
5. 只修改一条 adapter 规则或其 priority；
6. 用新文件名重新 `build`；
7. 再运行 `validate` 和 `simulate`；
8. 检查 `matched_rules`，不要只看最终索引；
9. 增加 mandatory、terminal、veto、重排 option 和 unknown-field 负例；
10. 所有窗口场景稳定后再申请 Godot 规则接入。

建议每个 macro 至少有：

- 一个正向命中场景；
- 一个关键卡不在手牌/active 的负例；
- 一个目标 UID 不同的负例；
- 一个 option 顺序重排场景；
- 一个 mandatory 或 hard tier 阻止 adapter 的场景；
- 一个旧窗口/错误 UID fail-closed 场景。

不要用胜率替代合法性、隐藏信息、stale window、dirty game 或 package integrity 测试。

## 8. API 使用参考

### 8.1 推荐的开发 API

开发者优先使用稳定命令行：

```text
author_strategy_developer.py scaffold
author_strategy_developer.py build
author_strategy_developer.py validate
author_strategy_developer.py simulate
```

对应 Python 函数：

```python
scaffold_workspace(output, template_package=DEFAULT_TEMPLATE_PACKAGE)
build_development_package(source, output)
validate_development_package(package)
simulate_public_window(package, scenario)
```

所有函数成功时返回 copy-safe JSON object；可预期的输入、合同和模拟失败抛出含稳定 `code` 的 `DeveloperToolError`。Host 预编译失败时
可以附带受限 `diagnostic`（owner、stage、错误码和失败的本地 UID）；除此之外不回显包内任意字符串或私有输入。磁盘故障、权限错误等
宿主级 I/O 异常仍由调用者按普通系统异常处理。

### 8.2 Python runtime 边界

维护者需要排查更深层问题时，真实入口为：

```python
package = AuthorStrategyPackageLoader().load_path(package_path)
handle = AuthorStrategyMatchHandleBuilder.build(package, root=repo_root)
host = PtcgDAPAuthorMatchHost.create(handle, match_id)
host.open_current_prompt(owner_produced_prompt)
result = host.request_current_selection()
indexes = result.indexes
```

注意：

- handle 一局一次，不能跨 match 复用；
- prompt 必须是 owner-produced `AuthorStrategyShadowPrompt`；
- 一个 prompt 只能消费一次；
- 不能从 Dictionary 伪造 handle/prompt；
- `result.indexes` 只属于产生它的当前窗口。

### 8.3 Godot catalog API

UI 或宿主只使用：

```gdscript
scan_startup() -> Dictionary
list_metadata_records() -> Array[Dictionary]
list_ready_records() -> Array[Dictionary]
list_diagnostics() -> Array[Dictionary]
install_from_local_path(source_path) -> Dictionary
request_match_handle(package_id, package_version, archive_sha256) -> Dictionary
request_ready_match_handle(package_id, package_version, archive_sha256) -> Dictionary
audit_snapshot() -> Dictionary
```

`list_*` 返回 copy-only 数据。`request_match_handle` 会重新捕获和验证 archive；启动 metadata 不能直接提升为 match authority。
production 玩家入口必须使用 `request_ready_match_handle` 并通过产品固定 release/canary gate。开发工具不调用或伪造 ready record。

`install_from_local_path` 只供策略中心在玩家通过文件管理器明确选中 `.ptcgai` 后调用。它会在写盘前运行 loader 的 match inspection 与 exact deck gate，验证卡牌均存在、牌表为 60 张、UID/卡源一致、格式/签名/hash/compatibility/policy 均正确；成功后原子写入固定 `user://ptcgdap/author_strategy_packages/` 并立即刷新 catalog。同 ID+version 不同 hash、symlink 源、错误扩展名、未知卡牌或写入后漂移均 fail closed。

返回值中的 `catalog_discoverable=true`、`status=installed` 或 UI 的“已加载”不授予 match authority。是否可开战仍由 `AuthorStrategyWindowsExecutionGate` 和 match-time exact-byte 重验决定。

#### 8.3.1 玩家侧导入与 AI 对手选择

1. 玩家在“AI 策略中心”点击“加载本地策略包”；
2. 原生文件管理器只显示 `.ptcgai`；
3. 游戏验证包、策略和整副牌表，失败时显示稳定的本地化原因且用户目录无残留；
4. 成功包立即出现在策略中心本地列表和对战设置的“AI 卡组”选择器；
5. 选择作者包会切入内部 `VS_AUTHOR_STRATEGY_AI` owner，选择经典卡组会清空作者包选择并回到 `VS_AI`；
6. 不可执行包仍可选择和查看元数据，但开始按钮保持禁用并明确显示“暂不可开战”。

该 UI 合流不允许把 package ID 写入 `ai_deck_strategy`，也不允许作者包经过 `DeckStrategyRegistry`、旧 LLM 配置或经典 AI fallback。

### 8.4 Godot Match Host API

```gdscript
PtcgDAPAuthorMatchHost.create(handle, match_id)
is_author_owner_ready()
card_id_domain()
open_current_prompt(owner_produced_source)
request_current_selection()
abort_current_prompt(error_code)
PtcgDAPAuthorMatchHost.validate_shadow_result(value)
```

成功选择仍需经过 current-window binding、ticket、preflight 和 engine executor。作者包从不直接调用这些引擎方法。
`card_id_domain()` 用于核对本局固定的身份域；`validate_shadow_result()` 只校验 copy-safe shadow result 形状，不授予执行权。

## 9. 测试分层

### 9.1 工作台聚焦测试

```powershell
python -m unittest -v tests.ptcgdap.test_author_strategy_developer_tool
```

### 9.2 包和 Host 合同

```powershell
python -m unittest -v `
  tests.ptcgdap.test_author_strategy_package_contract `
  tests.ptcgdap.test_author_strategy_package_loader `
  tests.ptcgdap.test_author_strategy_windows_local_deck `
  tests.ptcgdap.test_author_strategy_match_host
```

### 9.3 当前已集成 Marnie 的真实 Godot 规则模拟

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File scripts/tools/run_godot_tests.ps1 `
  -Runner focused `
  -SuiteScript res://tests/ptcgdap/godot/test_author_strategy_package_rules_e2e.gd
```

该测试会真实创建 `GameStateMachine`，让 exact Marnie 包对战现有规则 AI，并检查：

- 有正常 winner/终局原因；
- 未 stall、未触发 action cap；
- policy calls 与 successes 相等；
- 0 policy error / invalid output / fallback / external process；
- adapter macro 确实被匹配和选用；
- opponent hidden zones 不进入公开策略状态；
- stale window 在 engine execution 前拒绝；
- runtime deck 漂移拒绝。

这条 runner 只接受仓库已审核、exact SHA 的内置 Marnie 候选。普通作者重新构建后的新 SHA 不会自动获得 Godot engine authority；
这是安全边界，不是工具缺陷。

### 9.4 Godot AI 与功能回归

完成一个已审核候选接入后串行运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tools/run_godot_tests.ps1 -Runner ai
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tools/run_godot_tests.ps1 -Runner functional
```

不要并行启动多个高负载模拟或 benchmark pool。

### 9.5 Python 全量

```powershell
python -m unittest discover -s tests/ptcgdap -p "test_*.py" -v
python -m compileall -q scripts/ai/ptcgdap tools/ptcgdap tests/ptcgdap
git diff --check
```

## 10. 常见诊断码

| 错误码 | 含义与处理 |
|---|---|
| `developer_output_exists` | scaffold/build 拒绝覆盖；换新路径或明确处理旧生成物 |
| `developer_source_invalid` | source 含额外路径、symlink、错误类型或缺必需文件 |
| `developer_scenario_invalid` | 场景 JSON 不是闭合 v1 shape、含 float/重复 key/非法索引 |
| `developer_user_data_unavailable` / `developer_user_data_invalid` | 当前 Windows Godot 用户目录缺失、不可写、是 symlink 或逃逸固定 APPDATA 根 |
| `developer_install_identity_conflict` | 用户目录已有相同 package ID/version、不同 archive hash；提升版本或明确卸载旧包，不能覆盖 |
| `developer_install_destination_conflict` / `developer_install_failed` | 固定目标已被异常文件占用或原子安装失败；保留原包并检查用户目录 |
| `developer_install_package_not_development` | `install` 只接受 test-fixture、不可执行、非 production 的开发包 |
| `developer_observation_rejected` | raw observation 未通过官方 envelope/firewall |
| `developer_current_window_missing` | 当前 observation 没有可决策 select/current |
| `developer_current_window_fallback_only` | option shape/unknown enum 只能走 audited fallback，策略不应取得 authority |
| `invalid_local_uid_public_context` | UID 不在 deck、serial/index/source 不匹配或跨窗口 |
| `simulation_expectation_failed` | 策略实际索引与场景期望不同；检查 matched rules、priority 和 Base gate |
| `package_file_hash_mismatch` | source/build 后 payload 与 hash manifest 不一致 |
| `package_policy_unsupported` | IR/adapter/config shape 或 owner/operator 违反受限合同；检查 `diagnostic.owning_layer/stage/invalid_local_card_uids` |
| `package_deck_unmapped` | 60 卡、本地 UID、CardDatabase、卡源 hash 或 deck identity 不一致 |
| `package_signature_untrusted` | key 不在固定 trust store；不能由 caller 注入 trust |
| `package_contract_incompatible` | host/CABT/catalog/Base hash 与当前版本不一致 |

所有错误都应以稳定码处理。UI、CLI 和日志不要回显任意包内内容、私有输入或密钥路径作为诊断。

## 11. 新牌组接入流程

`scaffold` 的默认模板仍是已经接受的 Marnie Windows vertical slice；工作台本身可以构建其他完成 exact deck 审核的 workspace。添加新牌组
属于维护者工作，顺序如下：

1. 固定游戏内 deck ID 和源 deck JSON raw/canonical hash；
2. 确认精确 60 张牌和每个 `set_code_card_index` UID；
3. 对每个 UID 固定卡源 raw/canonical hash、card type、stage、effect ID；
4. 运行卡效/引擎支持审核，未知效果不得伪装支持；
5. 生成新的 closed local deck manifest 与 CSV；
6. 为新牌组建立 adapter/config，所有 UID 必须来自 manifest；
7. 增加正负 package、deck gate、public context 和 scenario 测试；
8. 用工作台完成 build/validate/install/public-window simulate；
9. 通过代码评审后增加 exact built-in development gate；
10. 新增 Godot rules E2E，覆盖两个 seat、多个 seed、零 dirty counter 和 rollback；
11. 更新 policy package/device manifest/export inventory 和证据链；
12. production signing、approval、canary、official conformance 与 A5 仍独立验收。

不要把官方与本地 identity 合并。一个本地包即使 60 张全部映射完成，也仍可保持 `cabt_exportable=false`。

## 12. 开发签名与正式签名

开发工作台使用固定 test-fixture Ed25519 材料，目的只是让 hash/signature/integrity 路径在开发期真实运行。它具备以下属性：

```text
signature_status=test_fixture_trusted
signature_scope=test_fixture_only
execution_trusted=false
production_ready=false
```

该 key 不是秘密，也绝不能进入产品 trust root。作者开发无需生成、保存或传递 key。

正式发布由产品维护者在仓库外管理 private key，并通过：

```text
tools/ptcgdap/sign_author_strategy_release_package.py
```

正式流程要求固定 trust store、唯一 active production public key、仓库外 non-symlink private key、派生公钥恒等、正式 loader
预检和 exact approval。目前 trust store 仍为 `unprovisioned`，所以正式发布预期 fail closed。

## 13. 完成定义

一个开发策略可以提交评审，至少应满足：

- [ ] 包 source 只含允许的数据文件；
- [ ] `build`、`validate` 成功且二次构建字节一致；
- [ ] exact 60 卡和 UID 域正确；
- [ ] 每条 adapter rule 有正向和负向场景；
- [ ] 每个场景的 matched rule、proposal 和 selected index 均符合预期；
- [ ] mandatory/terminal/veto/reorder/stale/unknown UID 负例通过；
- [ ] 报告不含隐藏信息或 raw authority；
- [ ] 已集成候选的 Godot rules E2E 正常终局且 failure counters 为 0；
- [ ] classic AI 回归不变；
- [ ] known gaps 明确写出 Windows-only、non-production、non-A5、CABT/engine parity 状态；
- [ ] rollback 能恢复上一 exact package/owner，且不删除用户包。

## 14. 本轮实现优化

本指南配套的开发工作台解决了此前四个问题：

1. 作者不再需要组合多个内部 builder/loader/Host 测试入口；
2. 作者不再需要接触低层 test key 参数，production key 边界更清晰；
3. local context 的 `context_hash/window_id` 改由模拟 Host 自动拥有，避免开发场景伪造 authority；
4. `validate` 经过与 Host 相同的 policy compiler，整副 UID 集不再拖到 `simulate` 才暴露错误；
5. deck、Python 和 GDScript 的本地 UID 语法统一为 `set_code + "_" + card_index`，覆盖 `SVP_105`；
6. 模拟报告在 `matched_rules → proposals → selected_indexes` 之外给出 forced/tier/veto/fallback 的逐候选公开裁决链。

这些优化没有改变玩家 start、exact archive development gate、production trust、Android 或 A5 状态。它们是开发者工具与
public-window simulation 子门，不是新的 live owner。D058 的初始工作台证据位于
`artifacts/ptcgdap/as_wp6_author_developer_workbench/`；D059 的 UID 合同与 Host 预编译修复证据位于
`artifacts/ptcgdap/as_wp6_author_developer_uid_contract/`。
