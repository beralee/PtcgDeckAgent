# Godot 作者策略包模式：产品设计与实现方案

## 1. 文档状态

- 状态：`accepted design / AS-WP6 implementation in progress; external release and device approvals required`
- 日期：2026-08-12
- 产品目标：让玩家在 Godot 游戏中把第三方作者策略作为一套独立的 AI 对战模式加载、识别、选择和执行。
- 当前工程前置：P5-WP7 已完成限定 offline differential/shadow trajectory，AS-WP0 已完成治理，AS-WP1 已完成 strict
  package contract、deterministic builder 与 fixed-anchor Python loader，AS-WP2 已完成 Godot captured-byte loader、固定根启动扫描与
  metadata-only catalog，AS-WP3 已完成 BattleSetup 独立模式、copy-only metadata UI 与恒 false 开战门，AS-WP4 已完成 match-time
  archive 重验、one-match sealed handle、exact deck gate 与 shadow Host；AS-WP5 已完成首个 W1 `setup_active` development/test canary，
  AS-WP6 已落地固定 release trust/approval/device 合同、test-key non-promotion、确定性导出与模拟器
  开发证据，并补齐固定 trust-store/仓库外 private-key/公私钥恒等/正式 loader 预检的 production-signing CLI；D056/D057 已完成固定
  Windows 资源资格与产品批准，且产品明确豁免当前 OS-disconnection 验证。当前 product key 仍未配置，release keystore、A5 与 Android
  arm64 完整对局仍未具备。唯一立即允许的工作仍是 AS-WP6，本文
  不把开发 owner、导出成功或 AVD UI 提前声明为 production live。
- D043 在 AS-WP6 内增加了一个 exact-SHA Windows development/test execution 子门：只对内置 Marnie 候选归档
  `32E254...643E` 放行测试 Host，以公开本地 UID frame/当前窗口 indexes 驱动既有 Godot rules execution bridge，10 局双座位
  真实 headless 对战为 918/918 policy success、0 error/invalid/fallback。该 Host 只在 `tests/` 中继承既有开发测试基座，
  不替换正式 `PtcgDAPAuthorMatchHost`，不接 GameManager/BattleSetup/ready record，也不覆盖自动 mulligan/turn-order/take-prize 等
  未由包 owner 控制的提示。
- D044 在保持 production signature/ready gate 关闭的前提下，进一步只为同一个 exact built-in archive 接通 Windows development
  `GameManager -> BattleSetup -> BattleScene` player path。独立 owner 不继承 `AIOpponent`，不加载旧 deck strategy preferences，覆盖实际
  Godot setup/mulligan、main、interaction/effect、take-prize、send-out 与 handoff 调度；10 局 seat-1 验收为 593/593 policy success、
  586 engine commits、0 error/invalid/fallback/rejection。它仍不等于 production-ready、official CABT W0–W7 conformance、
  exported EXE airplane-mode 完整对局或免除签名/设备门。
- D045 已证明同一 owner 可在 fresh-user-root Windows export template 内 headless 完成整局；D046 又以 3 次真实 Win32 鼠标点击经过普通
  MainMenu/BattleSetup/BattleScene 完成一局，并加入独立 startup/product feature gate。关闭 gate 后 catalog/UI/GameManager 在 0 次策略调用前
  fail closed，保留用户包，且不热切进行中的 owner。验收入口关闭应用启动网络客户端，但没有 OS-level network block；因此它关闭
  ordinary-UI development execution 与工程回滚子门，不关闭 airplane-mode、production trust/device/A5 总门；证据见
  `artifacts/ptcgdap/as_wp6_windows_ui_match/`。
- D047 已修复正式 device report 只哈希证据而不验证语义的缺口：builder 现在解析并绑定 exact export、WFP network、4688 process、
  ordinary-UI full-match 与 rollback 五类证据，并再次核对语义读取字节的 evidence hash；管理员验收器用 PID+随机端口 TCP 与 exact PID
  子进程 positive control 证明 OS event coverage，并只为 exact EXE 临时阻断网络后恢复
  firewall/audit state。当前非管理员会话只验证了赛前拒绝，尚未执行系统级三局；一次新 UI timing smoke 显示 proposed 5s cold-start/
  2s match-load 阈值偏紧，因此当时不能直接批准；D056/D057 随后以 10s/6s 固定阈值完成测量和批准。该工具仍保留为可选诊断，未运行
  不得写成 OS isolation proven。
- D048 已补齐首次正式设备取证的 acceptance-only canary：独立产品固定 store 精确批准 production-signed package/key/Windows/W0–W7，
  不预先写入尚未生成的 device/rollback/A5 hash；显式 export-template 参数独占激活，match-time 重验 exact archive 与 Marnie 本地 UID pins，
  且永不回落到 development owner。它只为生成首份正式设备证据提供受限 authority，不开放普通玩家开战。
- D049 又在该共用 Windows owner 的最终 policy→index 边界重验响应回显的当前 observation hash、window ID 与
  `restricted_ir_same_window` 来源；stale/foreign 响应只能触发同窗合法 fallback，不能把旧索引交给 engine executor。optional-zero prompt
  另保留独立 validity bit，只有显式空数组可作为成功，非数组/越界/重复/错误基数均记为 invalid output 并同窗回退。
- D050 关闭 D045 留下的 raw-container 漂移：固定 Windows release owner 在 inventory/hash/sign 前规范化 ZIP、PCK 和 embedded EXE；
  两次完整导出的五项绑定产物逐字节一致，规范化 EXE 又完成 3 局规则对战。该子门本身不替代 production key、OS-level 断网、批准设备档或 A5；
  其中 profile 与断网验证要求随后由 D057 独立决策。
- D051 增加作者包之外的产品 `policy_package_v1`：保持 exact `.ptcgai` 字节不变，另行固定 deck/catalog/Base/adapter/IR/config、
  GDScript policy/match/execution owner、trace、parent、rollback 和 capability。首个 Windows manifest 明确 `learned_model=none`；包内 weights
  是未使用 payload，不能冒充模型 invocation。编辑器 10 局与导出 EXE 3 局均产生 exact manifest/no-model witness。D057 产品批准不会
  反向改写该 immutable D051 artifact；当前 release gate 独立验证新的 release bundle。
- D052 复用 sealed P5 portable owner 建立 P6-02 双 runtime runner：Python/GDScript 都实际重算 28 个既有 action/owner/reason/trace
  向量并通过 8 个 order/float/default/unknown/fault/tie/reorder/unknown-operation 探针，0 mismatch、0 skip。当前无模型，所以 operator case
  与 skip 都是 0；这不关闭 P6-03、model-backed lane、A2/A5 或 production/device 门。
- D053 新增版本化 Windows `LocalPolicyExecutor`，在 match 创建时固定并重验 D051 parent 与 contract/IR/config/catalog/weights/fallback
  closure，通过继承直接执行 sealed restricted-IR/Base；活动 factory 为新局创建独立 local-executor owner，旧 D051 policy/owner 保持字节不变且
  可作为下一局回滚。fresh exported ordinary-UI 对局为 59/59 policy success、59 engine commits、0 error/invalid/fallback/rejection，关闭
  P6-03 当前 Windows no-model GDScript baseline 子门；factory 切换后旧 owner 又以原 seeds 完成 10/10 终局、593/593 success、586 commits
  和 0 failure counters，作为可执行的新局回滚证据；最终完整回归为 Python 931/931、Godot AI 1496/1496、功能/UI 4976/4976。
  它不关闭 production/device、A2/A5、model-backed lane 或 Android。
- D054 新增首个 `device_manifest_v1`，只声明 Windows x86_64、`windows-x86_64` ABI、Godot minimum 4.6.1、GDScript 与 D053
  no-model executor；本地执行、aligned-AI network/external compute denied、profile 精确引用和 D051 新局 rollback 均被固定。开发运行不要求
  key；production Ed25519 仍为 `unprovisioned`。D059 重建后 manifest 为 1.1.0/canonical `FCEEFEC1...B8948`，引用 approved non-A5 profile；
  该合同不证明 OS 级隔离、production、A5 或 Android。证据见 `artifacts/ptcgdap/as_wp6_device_manifest/`。
- D055 又提供仓库内、非 Skill 的 Windows P6-07 单入口：fresh canonical build、6 个 D054 export member 重验、独立 install exact-copy、
  install-root working directory、fresh user data 与 ordinary real-mouse UI 整局一次完成。最终 development run 为 58/58 policy success、58
  engine commits、0 failure counters；应用网络关闭和 dead proxy 不等同管理员 OS 隔离。
- D056 对 D055 exact EXE 串行完成 3 局 ordinary-UI 与一次 feature-off rollback，173/173 policy success、172 commits、0 failure counters；
  cold start/catalog/match load/decision P95/peak/package 为 5252ms/305ms/2103ms/22ms/545MiB/262MiB，六项均过固定候选门。
- D057 产品批准同一组 Windows 阈值，profile canonical `A8971FD...95169`、`formal_a5_eligible=false`，关闭 P6-05/P6-11；同时明确本轮
  不要求 airplane/WFP/4688，P6-08 为 `waived_by_product`，`os_network_isolation_proven=false`。这不放松 device-local、denied network/
  external compute/system Python/sidecar/remote inference 边界，也不配置 production trust/canary 或 A5。
- D058 增加面向作者的统一 Windows 开发工作台：`scaffold -> build -> validate -> simulate`。开发构建自动使用公开的 test-fixture
  签名材料，作者不管理 key；严格 loader 仍把结果固定为 `test_fixture_only`、`execution_trusted=false`。模拟器从公开 CABT envelope
  重新构造 firewall/current-window/context，并调用真实 Python Base/adapter/Match Host，报告命中规则、提案和最终索引；它不执行引擎、
  不授予 player/production authority，也不能替代 exact Marnie 候选的 Godot 规则回归。
- 对齐边界：策略仍遵守 `agent(raw_observation) -> list[int]`；包不能读取 Godot 私有对象、隐藏信息或直接执行引擎命令。

面向实施 Agent 的现有代码地图、工作包拆分、API 草案、测试命令和回滚清单见
`09-author-strategy-package-engineering-handoff.md`；面向策略作者的可复制流程和接口说明见
`10-author-strategy-developer-guide.md`。

## 2. 产品定义

作者策略不是现有“规则版”或“大模型版”的一个开关，也不是 `DeckStrategyRegistry` 的新变体。它是新的顶层游戏模式：

```text
自己练牌
经典 AI 对战
作者策略对战
```

其中：

- “经典 AI 对战”继续承载现有规则版和大模型版，保持兼容与回滚能力；
- “作者策略对战”只显示已安装、验证通过且与当前游戏版本兼容的作者策略包；
- 一份作者策略包同时确定作者、展示名、AI 牌组、策略制品与兼容性声明；
- 同一局中不能从作者策略静默降级到经典 AI，也不能把两套 owner 混合调用。

UI 主名称采用明确署名：

```text
{author_display_name} 的 {strategy_display_name}
```

例如：

```text
z 的喷火龙 AI
```

副标题显示牌组名称、版本和兼容状态，例如：

```text
喷火龙 / 比雕 · v1.2.0 · 本地已验证
```

展示名只用于 UI。运行时身份必须使用 `package_id + package_version + package_content_sha256`，不得按作者名、策略名或牌组名推断。

## 3. 玩家流程与 UI

### 3.1 对战设置页

`BattleSetup` 内部保留第三个 `ModeOption`/`VS_AUTHOR_STRATEGY_AI` 作为兼容和执行边界，但 D116 起不再向玩家展示一个与“AI 对战”竞争的第三个顶层按钮。玩家进入“AI 对战”后：

1. 玩家选择自己的牌组；
2. 在统一“AI 卡组”选择器中选择经典 AI 卡组或一个已加载策略包；
3. 右侧详情显示作者、策略说明、AI 牌组、版本、包来源、兼容状态和可选封面；
4. 点击开始时再次验证并锁定精确包，而不是仅复用启动时的元数据；
5. 已加载包都可选择；只有当前执行门逐次放行且牌组仍存在的包可以开始对战。

该模式不显示以下经典 AI 控件：

- 规则版 / 大模型版；
- `DeckStrategyRegistry` 策略来源；
- 旧 opening strength 或旧 LLM 配置；
- 任何会让玩家误以为作者包叠加在旧 AI 上的开关。

建议卡片状态：

| 状态 | UI 行为 |
|---|---|
| `ready` | 可选择、可开始 |
| `metadata_only` | 可查看，不可开始；缺执行制品或完整验证 |
| `incompatible` | 灰显并显示最低游戏/合同版本 |
| `untrusted` | 灰显并显示签名或来源问题 |
| `invalid` | 不进入正常列表，只在诊断页显示稳定错误码 |
| `disabled` | 用户主动停用，保留元数据 |

### 3.2 牌组与策略的一体化选择

在用户可见的 AI 对手选择器里，经典 `ai_decks` 与作者策略包可以同屏检索和选择；但两者只是共用 UI，不共用 runtime owner。策略包本身携带并锁定 AI 牌组，UI 的每个包条目就是一套完整成果：

```text
作者 + 策略 + AI 牌组 + 版本 + 内容哈希
```

一名作者可以发布多个包，例如：

- `z 的喷火龙 AI`
- `z 的密勒顿速攻 AI`
- `momo 的沙奈朵控制 AI`

若同一策略支持多套牌组，应发布多个明确包，或在未来引入经过合同约束的 package collection；首版不允许一个包在运行时任意替换牌组。

## 4. 游戏目录与包格式

### 4.1 专用目录

仓库内置包目录：

```text
res://data/ptcgdap/author_strategy_packages/
```

对应仓库路径：

```text
data/ptcgdap/author_strategy_packages/
```

玩家安装目录：

```text
user://ptcgdap/author_strategy_packages/
```

D116 已在策略中心加入原生文件选择器。玩家选择的外部文件只作为一次性源字节读取；通过完整 loader 与牌表 gate 后，安装器按 archive SHA-256 命名并原子复制到上述固定目录，随后立即重扫 catalog。游戏不会把任意外部目录加入扫描根，也不会递归扫描玩家文件系统。

包扩展名：

```text
.ptcgai
```

`.ptcgai` 是确定性 ZIP 容器。一个包只表示一个作者、一个 AI 牌组和一个策略入口。禁止嵌套压缩包。

本阶段已建立内置目录；真正样例包只能在 package contract、签名和执行器通过后加入，不能放一个看似可用但绕过验证的演示包。

### 4.2 包内布局

```text
strategy_package.json
files.sha256.json
signature.json
README.md
LICENSE
deck/
  deck_manifest.json
  deck.csv
policy/
  policy_ir.json
  adapter.json
  config.json
  weights.bin              # 可选，且必须由 manifest 声明
assets/
  icon.png                 # 可选
  banner.png               # 可选
```

首版允许的数据类别：严格 JSON、UTF-8 文本、固定 CSV、受限二进制权重和静态图片。以下内容一律拒载：

- `.gd`、`.py`、`.pck`；
- DLL、SO、AAR、EXE、脚本或 shell 命令；
- 可触发动态加载、网络访问或进程创建的文件；
- 包外相对路径、绝对路径、符号链接或 ZIP path traversal；
- 未被 `files.sha256.json` 精确列出的额外文件。

作者策略由游戏内置的 `LocalPolicyExecutor` 解释受限 IR/config/weights。包提供数据，不向游戏注入任意代码。未来若确需 native scoring backend，必须单独 ADR、签名、ABI、设备与回滚门，不能偷渡进 `.ptcgai`。

### 4.3 `strategy_package.json` 最小形状

```json
{
  "document_type": "strategy_package_v1",
  "schema_version": 1,
  "package_id": "dev.z.charizard-ai",
  "package_version": "1.0.0",
  "author": {
    "author_id": "dev.z",
    "display_name": "z"
  },
  "strategy": {
    "display_name": "喷火龙 AI",
    "summary": "围绕喷火龙主攻手的公开信息策略"
  },
  "deck": {
    "display_name": "喷火龙 / 比雕",
    "manifest_path": "deck/deck_manifest.json",
    "deck_path": "deck/deck.csv"
  },
  "policy": {
    "entry_kind": "restricted_policy_ir_v1",
    "ir_path": "policy/policy_ir.json",
    "adapter_path": "policy/adapter.json",
    "config_path": "policy/config.json",
    "weights_path": null
  },
  "compatibility": {
    "minimum_game_api": "ptcgdap-author-host-v1",
    "cabt_contract_sha256": "<exact hash>",
    "card_catalog_sha256": "<exact hash>",
    "base_executor_sha256": "<exact hash>",
    "required_capabilities": []
  },
  "presentation": {
    "icon_path": null,
    "banner_path": null
  }
}
```

所有字段使用 strict schema、closed key set、exact host type、safe integer 和规范路径。`display_name` 可以本地化，但不能参与牌卡、动作或运行时 authority 映射。

### 4.4 Windows 本地 deck/policy identity 扩展

D041 为当前 Windows 首发增加独立的 `deck_manifest_windows_local_v1`，不改写 AS-WP1 的 official-ID 牌组合同。其
`card_id_domain` 固定为 `godot_local_card_uid_v1`，`deck.csv` 表头固定为 `local_card_uid,count`，UID 只能是
`set_code + "_" + card_index`。manifest 同时逐项携带 UID、count、effect ID、card type/stage、卡源 raw/canonical hash，
并固定源 deck raw/canonical hash。D144 已取代旧的“按来源编号重读内置/用户 deck JSON”行为：match-time gate 以 CSV+manifest 为牌表 authority，
只用逐卡源 JSON 和 `CardDatabase.get_card(set_code, card_index)` 精确验证、物化；`source_deck_id` 不得进入 deck lookup。
D147 进一步固定 UI/Host 生命周期：BattleSetup 的 AI 牌组列表、tooltip、状态与普通刷新只读 catalog metadata，不得申请 match handle 或物化 CSV；
完整 archive 重验和临时 `DeckData` 构造只在玩家明确开始对战后发生，并在 BattleScene 继续 fresh revalidation。

同一 Windows-local 包内的 `policy/adapter.json` 卡牌谓词也使用这些字符串 UID；`policy/config.json` 固定
`card_id_domain=godot_local_card_uid_v1` 并绑定 exact deck manifest SHA-256。loader 按 deck domain 校验：数字型 official ID、
manifest 外 UID、配置域或 manifest hash 漂移都 fail closed。official-ID adapter 继续只接受数字值，两个域不共享隐式转换。

当前此档只允许 `platform_scope=["windows"]` 和 `cabt_exportable=false`。它解决的是 Godot Windows 本地牌组与策略制品身份，
不向 CABT observation/action 合同输出字符串 Card ID，不替代 official Card ID/Attack ID/serial，也不产生 reprint equivalence、
卡效 parity 或 Kaggle export 声明。Marnie 的历史构建来源为 `800018501`，但运行时牌组身份为 package ID/version + deck manifest hash，
28 个唯一 UID、60 张牌全部来自包内清单；官方 Marnie lane 继续独立保留。
当前已增加独立、allow-list 构造的 local-UID public context：它只含当前 `context_hash/window_id`、当前窗口 option→UID、行动方公开
hand/active serial→UID，并由语言中立 bundle canonical
`42706B8426968F4EB1A9C79A3EFC3828236966454013BB791D51684E5C346AAA` 固定。Python/GDScript Match Host 只在
`godot_local_card_uid_v1` 域编译本地 adapter，并按 exact deck manifest UID 集、当前窗口和公开 serial 顺序逐 prompt 绑定；official CABT
projector 与 official-ID adapter 字节语义不变。Host 现可为本地包产生 shadow indexes/audit，W1 development source 也只在本地域注入该视图；
当前真实 W1 canary 仅使用 Marnie 牌组中已有 exact official bridge 的 `CSV8C_094`，以便旧 CABT projector 仍按原合同建立基础 context；
它不把其余本地 printing 补成官方 Card ID。这只关闭本地 UID shadow compiler/绑定与一个 exact-bridge W1 子门，不授予 production trust、
完整 28 UID/W0–W7、玩家 live、CABT export 或 engine parity。

## 5. 启动时元数据发现

新增独立 autoload：

```text
AuthorStrategyPackageCatalog
```

它不属于 `CardDatabase`，也不属于 `DeckStrategyRegistry`。建议职责：

1. 在游戏启动阶段扫描固定的内置与用户目录；
2. 用 `ZIPReader` 读取 ZIP 中央目录并执行 path/size/count 上限预检；
3. 严格解析 `strategy_package.json`、文件哈希表和签名摘要；
4. 只把 copy-only 元数据、兼容状态和诊断码放进 catalog；
5. 发出 `catalog_ready`、`catalog_changed`、`package_rejected` 信号；
6. 不在启动阶段构造策略 owner、不加载权重到执行器、不执行策略。

为避免启动卡顿，元数据缓存可以保存：

```text
archive path + size + mtime + raw hash + parsed metadata snapshot
```

缓存命中不能授予对战 authority。开始对战时仍必须重新读取并验证精确 archive bytes。

稳定诊断码至少包括：

- `package_manifest_missing`
- `package_manifest_invalid`
- `package_path_invalid`
- `package_file_unlisted`
- `package_file_hash_mismatch`
- `package_signature_untrusted`
- `package_contract_incompatible`
- `package_catalog_incompatible`
- `package_policy_unsupported`
- `package_resource_limit_exceeded`
- `package_duplicate_identity`

UI 只显示经过清洗的摘要，不回显任意包内字符串作为错误详情。

## 6. Godot 现有模式对接

### 6.1 新游戏模式

`GameManager.GameMode` 增加独立枚举值：

```gdscript
VS_AUTHOR_STRATEGY_AI
```

新增 match setup 字段建议为：

```text
author_strategy_package_id
author_strategy_package_version
author_strategy_package_sha256
author_strategy_install_source
```

旧字段 `ai_deck_strategy` 只服务经典 AI。新模式不能把包 ID写入该字段冒充旧策略。

### 6.2 对战 owner 工厂

把现有只构造 `AIOpponent` 的入口逐步提升为：

```text
BattleDecisionOwnerFactory
├── LegacyAiDecisionOwnerAdapter
└── PtcgDAPAuthorMatchHost
```

经典 AI 继续走 `BattleAiOpponentFactory -> AIOpponent`。作者策略模式走 `PtcgDAPAuthorMatchHost`，绝不经过 `DeckStrategyRegistry` 或旧 LLM fallback。

`BattleScene` 当前直接调用许多 `AIOpponent` 方法，不能一次性把作者包伪装成 `AIOpponent`。实施时先抽取最小、显式的 prompt/decision owner 协议，再按 W0–W7 提示逐步迁移；任何尚未覆盖的提示都应在赛前判 incompatible，而不是局中落回经典 AI。

### 6.3 开战时精确锁定

按“开始对战”后执行：

1. 根据 catalog selection 定位精确 `.ptcgai`；
2. 重新读取 archive raw bytes；
3. 验证 archive/content hash、签名、manifest、全部文件 hash、schema、牌组、IR 和兼容性；
4. 构造不可变 `AuthorStrategyPackageHandle`；
5. 为整局固定 package、deck、CABT contract、Card/Attack catalog、Base executor、policy IR、weights 与 backend hash；
6. 构造 `PtcgDAPAuthorMatchHost`；
7. 只有全部完成后才进入 BattleScene。

局中禁止热更新包、切换版本或重新扫描目录。目录变化只影响下一局。

## 7. 对战执行链

```text
Godot prompt
  -> EngineDecisionPort
  -> GodotObservationProjector
  -> PublicObservationFirewall
  -> immutable current selection window
  -> PtcgDAPAuthorMatchHost
  -> package LocalPolicyExecutor / Base / public adapter
  -> strict selection sanitizer
  -> one-use ActionTicket
  -> engine adapter
  -> reobserve and rebuild
```

包只能获得公开 observation、当前 immutable window 和经合同允许的本地只读策略资源。输出只能是当前窗口 indexes。它不能接触：

- `GameState`、`GameStateMachine`、`BattleScene`；
- `CardInstance`、`PokemonSlot` 或任意 Godot Object reference；
- 对手隐藏手牌、牌库顺序、盖放奖赏、私有 RNG 或 Search capability；
- command callback、ActionTicket、engine method 或旧 AI 私有状态。

策略异常、超时、输出非法或能力未知时，只能使用同一个公开 observation 和同一个 current window 的 aligned deterministic fallback。包验证、合同或 authority 失败时安全终止，不静默切到经典 AI。

## 8. 分阶段实现计划

### WP-A：包合同与目录

- 固定 `.ptcgai` 容器规则、strict manifest/schema、文件 allow-list、大小上限与稳定错误码；
- 建立 `data/ptcgdap/author_strategy_packages/`；
- 建立 deterministic pack/verify 工具和 golden 包；
- 只做离线验证，不接 UI 或 live owner。

### WP-B：启动 catalog 与 UI 元数据

- 新建 `AuthorStrategyPackageCatalog` autoload；
- 扫描内置/用户目录并加载 copy-only metadata；
- `BattleSetup` 增加“作者策略”顶层模式和署名卡片；
- 不能开始真正对战，只做 metadata/shadow selection evidence。

### WP-C：match package loader

- 开战时重验 archive、签名、合同、牌组、IR、catalog 与资源预算；
- 建立 immutable package handle 和整局 hash pin；
- 验证删除、替换、同 ID 不同内容、重签、ZIP traversal 和资源炸弹均拒载。

### WP-D：Godot author host shadow

- 引入 `BattleDecisionOwnerFactory` 和最小 owner protocol；
- 构造 `PtcgDAPAuthorMatchHost`，对 W0–W7 运行 shadow；
- 与 Python/reference executor 做同包、同 observation、同 indexes 的 conformance；
- 不执行 engine command，不改变经典 AI。

### WP-E：canary 与玩家设备门

- 逐提示接通 current-window binding/ticket/executor；
- Windows 必须保持 device-local 且禁止 aligned-AI 网络/外部计算；D057 已由产品豁免 OS 断网取证，不能声称 isolation proven；Android 按 D041 后续独立适配；
- Windows 冷启动、每决策延迟、峰值内存、包体与签名门通过；Android 的温度/电量/ABI/真机矩阵不得由 Windows 结果代替；
- 只有 canary、rollback 和 A5 接受证据通过后才允许成为可执行模式。

P5-WP7 前置门已以 bundle canonical
`992B7F00DF412496BA414ABCC87C21C6136CB513C9C90799C897ADD18D15EDB2` 关闭；AS-WP0 完成治理，AS-WP1 又以 bundle canonical
`B416F2CBA2795B62126B6EF7B5F07A9000E84D5FA1DF62C1753CADC9E82E106B` 完成纯离线合同/builder/Python loader；AS-WP2 又完成
Godot raw-byte loader 与 metadata-only autoload catalog；AS-WP3 完成独立 GameMode、BattleSetup metadata picker/detail/status 与 stable-ref
  保存，并固定 production `not_live_ready`；AS-WP4 完成 match-time 重验、one-match sealed handle、exact local deck gate 与 shadow Host；AS-WP5 又只为
  W1 `setup_active` 完成 current-window/ticket/engine seam、same-window fallback 与 W2 fresh reobserve。AS-WP6 当前已建立固定 release gate、
不可执行内置候选包、Windows 导出清单/导出后 PCK runtime、历史 Android x86_64 AVD 飞行模式 UI 开发证据。D041 又把当前首发声明范围
收窄到 Windows，并增加 `godot_local_card_uid_v1` 隔离牌组档：Marnie `800018501` 的 28 个本地 printing/60 张牌已能双 runtime 精确物化；
  这不改变 CABT official Card ID 合同。D044 现只为 exact 内置候选接通 Windows development player owner，并以真实规则引擎 10 局证明
  development execution；D045 又以 fresh-user-root Windows export template 完成 3 局 headless development 整局，186/186 policy success、
  186 engine commits 且所有错误/回退计数为 0。D046 再完成 ordinary UI 真实鼠标 development 整局和独立关闭开关演练；应用层网络入口
  已在该验收路径关闭，但 `network_isolation_proven=false`。D050 又以固定 canonicalizer 关闭 Windows ZIP/PCK/embedded EXE 的 raw-container
  reproducibility，并用规范化 EXE 完成 3 局规则对战。D051 又让同一执行路径在创建 match owner 前验证外层 `policy_package_v1`，并明确
  当前没有 learned model。D052 再为这个精确 no-model portable subset 关闭 P6-02 双 runtime conformance 子门；D053 又以版本化
  `LocalPolicyExecutor`、完整 resource closure、actual factory 和 exported ordinary-UI 终局关闭 P6-03 当前 Windows no-model GDScript
  baseline 子门。D054–D057 又完成 Windows device manifest、三局资源资格、产品 profile 批准与 OS-disconnection 产品豁免。
  当前仍只允许 AS-WP6 补齐 production trust/signing、exact package/device-canary approval、official W0–W7 与独立 A5 门，
  不允许把开发 authority 升格为 production live；Android 以后另开适配证据。

AS-WP6 的正式 device report builder 只接受产品固定且已批准的 Windows profile，不提供 profile/阈值 override；它从同一 non-symlink evidence root
读取测量输入与五份实际证据，自行重算文件 SHA-256、cold-start max 和 decision nearest-rank P95，并以 exclusive create 写报告。路径穿越、别名、
自引用、空/超限证据、样本不足、统计漂移或既有输出都 fail closed。当前 profile 已批准但 `formal_a5_eligible=false`，所以该入口仍会以
`release_a5_unapproved` 拒绝当前仓库的 formal A5 报告；D057 产品资源批准由独立 evidence 承担。
五个 evidence hash 还必须对应可解析的闭合证据，且同一 EXE hash、run ID、target PID、production signature scope、原始样本、零网络/子进程
尝试和 rollback 事实逐项一致；语义解析的原始字节还必须重新命中报告所记录的 hash，任意五个非空文件或调用方布尔值不再能构成 formal report。
当前 production player start 仍关闭；D048 的独立 canary 路径已经实现，但固定 production trust 和 canary approvals 仍为 `unprovisioned`，
所以尚无 positive canary run。它不能通过伪造已批准 device report 绕开循环依赖，也不能被普通 player-ready gate 消费。
当前树最终兼容性回归为 PtcgDAP Python 891/891、Godot AI 1494/1494、功能/UI 4972/4972；这些结果只证明实现边界和旧路径未回归，
不替代 production key、positive canary、official conformance 或 A5。管理员 OS-isolation 工具保留为可选诊断；D057 已豁免其产品门且不形成证明。

D041 对 release contract 的实际收口固定为 exact platform map：当前 `supported_targets`、device profile 与 approval evidence 都只含
`windows`；缺失 Windows 或夹带 Android 会在 Python/GDScript gate 中 fail closed。Android 处于显式 `deferred`，以后必须独立重签
profile、approval、导出、真机和 A5；它不能继续由旧双平台字段阻断当前 Windows，也不能借历史 APK 自动获得支持声明。

## 9. 预期代码边界

建议新增：

```text
scripts/ai/ptcgdap/packages/AuthorStrategyPackageCatalog.gd
scripts/ai/ptcgdap/packages/AuthorStrategyPackageLoader.gd
scripts/ai/ptcgdap/packages/AuthorStrategyPackageHandle.gd
scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorMatchHost.gd
scripts/ui/battle/author_strategy/AuthorStrategySetupModel.gd
scripts/ui/battle/ai/BattleDecisionOwnerFactory.gd
contracts/ptcgdap/author_strategy_package.schema.json
tests/ptcgdap/godot/test_author_strategy_package_catalog.gd
tests/ptcgdap/godot/test_author_strategy_battle_setup.gd
tests/ptcgdap/godot/test_author_strategy_match_host.gd
```

需要修改但必须保留旧行为：

```text
scripts/autoload/GameManager.gd
scenes/battle_setup/BattleSetup.tscn
scenes/battle_setup/BattleSetup.gd
scenes/battle/BattleScene.gd
```

不得把包扫描或执行责任塞进：

```text
CardDatabase.gd
DeckStrategyRegistry.gd
AIOpponent.gd
```

## 10. 验收门

最低必须验证：

- 同作者/同显示名但不同 package ID 不冲突；同 ID+version 不同内容 fail closed；
- 启动只读元数据，不运行策略或加载任意代码；
- UI 名称、作者、牌组、版本和状态与 manifest 一致，文本不能授权 identity；
- 经典 AI 与作者策略的状态、factory 和 fallback 完全分域；
- 开战时精确 archive/hash/signature/contract/catalog/deck/policy pin；
- 包替换、删除、extra file、duplicate path、path traversal、oversize、hash drift 全拒载；
- Python/GDScript 对同包 shared vectors 产生完全一致的 indexes、fallback 与 diagnostics；
- hidden sentinel、engine object、callback、ticket 和 private state 在包输入与 audit 中零出现；
- 旧 window、旧包 handle、跨局 selection 和热替换全部 fail closed；
- 当前 Windows 安装包确实包含候选包与 contract，并以 device-local owner 完成声明范围内对局；OS-disconnection 取证已产品豁免；Android 仅在后续明确重新声明后适用同级门；
- 卸载作者包或关闭 feature flag 后，经典 AI 行为逐字节/逐测试保持原样。

## 11. 回滚

作者策略模式必须由独立 feature flag 和独立 `GameMode` 控制。回滚顺序：

1. 关闭作者策略 catalog 和 UI 入口；
2. 删除新增 package/host/factory 文件与内置包；
3. 恢复 `GameManager`、`BattleSetup`、`BattleScene` 父字节；
4. 重跑经典 AI setup、规则版、大模型版和完整 PtcgDAP regression；
5. 已安装 `.ptcgai` 保留在用户目录但不扫描、不执行，避免误删用户文件。

回滚不能把进行中的作者策略局切成经典 AI；当前局应安全终止或由 match-level rollback 规则处理，下一局才回到旧模式。

## 12. 当前明确不声称

本文是已接受的设计；AS-WP5 已提供仅限 W1 的 development/test canary，AS-WP6 又提供固定 release/export/emulator 开发证据、
D043 exact-SHA test-Host real-engine 对局、D044 exact-candidate Windows development player owner、D045 exported-EXE headless
development 整局、D046 ordinary-UI development/feature rollback 与 D048 acceptance-only production device canary 执行边界，但不表示以下能力已经实现：

- production 签名 trust root、外部私钥/Android release keystore 或包管理器已完成；当前 trust/approvals 为 `unprovisioned`，Godot loader/catalog
  仍只有不可执行 test key，`ready_records` 恒为空；
- 任意作者 Python/GDScript 可以直接在玩家设备执行；
- Marnie Windows-local 牌组门虽然已精确覆盖 28 个 UID/60 张牌，但这不表示已具备 production 签名、完整卡效/引擎一致或可发布策略；
- production 玩家 live、official CABT W0–W7 conformance、Windows A5 或商店分发已经通过；OS-level disconnected/airplane acceptance 是
  D057 产品豁免而不是通过，`os_network_isolation_proven=false`；
  Android 未进入当前声明范围，既有 x86_64 AVD 开发结果也不是未来 Android A5；
  P5-WP7、AS-WP5 W1 与开发导出均不能替代这些门；
- 外部包被官方信任或作者身份已经实名验证。

完成本文对应产品目标，必须有可执行合同、双 runtime conformance、UI/integration、设备、签名、回滚和独立 release evidence，且仍不得高于实际达到的 alignment level。

D116 关闭了 Windows 本机导入、安装后即时发现和统一 AI 对手选择器子门。它不改变本节的 production、official conformance、Android 或 A5 声明边界；“已加载”只表示 archive、策略和牌表已通过当前本机验证，不表示该包已获得执行或发布授权。
