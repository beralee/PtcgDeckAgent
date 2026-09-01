# 01 — 官方 CABT/Kaggle AI 合约

## 1. 合约入口

官方样例公开的唯一业务入口为：

```python
def agent(obs_dict: dict) -> list[int]:
    ...
```

没有官方 Agent 基类、`init`、`reset`、`close`、`end` 或 capability
negotiation。通用 Kaggle loader 可能支持不同函数 arity，但本项目只把官方样例
保证的单参数入口当成线上合约。

提交包的 `main.py` 必须位于 `.tar.gz` 根目录，且 `deck.csv` 同样位于根目录。
平台从 `/kaggle_simulations/agent/` 加载。导出器还必须验证 Kaggle 选择最后一个
顶层 callable 的加载行为，避免辅助函数意外成为入口。

本地权威文件：

- `D:\ai\code\ptcgabc\official_data\kaggle_bundle\sample_submission\sample_submission\main.py`
- `D:\ai\code\ptcgabc\docs\official\external\kaggle_cabt.py`

## 2. Episode 生命周期

### 2.1 初始 callback

初次 callback 的可观察形状为：

```text
select = null
current = null
logs = []
search_begin_input = null
```

Agent 必须返回一个长度恰为 60 的数值 Card ID 列表。牌组非法、长度错误或
不可启动都会使该席位 INVALID。

`select == null` 也是唯一可靠的 session reset 信号。收到它时必须：

1. 清除上局 observation/window/action ticket；
2. 清除 goal、macro、belief、trace cursor 和 timeout state；
3. 固定本局 contract/policy/catalog/capability hashes；
4. 返回已离线验证的 60 Card ID；
5. 不沿用跨 episode 的模块全局状态。

### 2.2 正常 callback

后续只在当前 `yourIndex` 对应席位需要选择时调用 Agent。每次 callback 给出一个
新的当前窗口，Agent 只解决这一个窗口。多阶段效果不是一次返回完整路线，而是：

```text
observation N -> indexes N -> engine transition
-> observation N+1 -> indexes N+1 -> ...
```

没有额外的终局回调。引擎在 battle finish 后直接结束 episode。不能依赖
`end()` 来刷 trace、清理资源或提交状态。

## 3. Raw Observation Envelope

官方 `Observation` dataclass 声明四个字段：

| 字段 | 类型 | 语义 |
|---|---|---|
| `select` | `SelectData | null` | 当前选择窗口；初始牌组时为 null |
| `logs` | `list[Log]` | 从上次选择到当前选择的增量事件 |
| `current` | `State | null` | 当前公开状态；初始牌组时为 null |
| `search_begin_input` | `string | null` | 官方 native search 的 opaque 输入 |

锁定来源显示 raw callback 分三层形成：native engine 先序列化 `select/logs/current`，
Python Host 再加入 `search_begin_input`，Kaggle framework 最后提供 `step` 与
`remainingOverageTime`。因此不能把任一层的 dataclass 当成完整 raw authority。

线上 raw dict 还观察到 Kaggle 框架字段：

- `step`
- `remainingOverageTime`

官方 `to_observation_class()` 只复制 dataclass 声明字段，因此会静默丢掉这些 raw
extras 和未来新增字段。目标实现必须先保存 raw envelope，再构造 typed view：

```text
RawCabtEnvelope
  raw_payload                 # 原样、只读、仅 Host 持有
  raw_private_hash            # 完整 tree（含 opaque token）的 Host 私有 hash
  token_free_callback_hash    # token 归一化且保留未知字段的 Host-private callback binding hash
  known_view                  # 当前已知 CABT typed fields
  unknown_fields              # Host-private quarantine；不交给策略，safe metadata 也不输出未知键名
  step
  remaining_overage_time
  source_contract_hash
```

这里“原样”指保留 callback 已解析 JSON tree 的键、值类型、数组顺序以及
missing/null/value 三态；callback 已不是原始 JSON bytes，所以不宣称保留空白或对象键的文本顺序。
真实 `search_begin_input` 只允许在当前 Host 内存中短暂存在。持久 golden fixture 中该字段
一律写为 null；provenance 只记录来源值是 null 还是 non-null，并记录 sanitizer，不得保存
真实 token。`known_view` 不携带该 capability。

`token_free_callback_hash` 对完整 callback tree（包括 additive unknown fields）计算，但先把
`search_begin_input` 归一化为仅表示“是否存在”的结构化标记。只有公开信息防火墙通过后，
它才能成为 Host-private window/ticket 的 callback binding hash；它不是 policy input，公开 trace
不序列化未知字段内容或该 binding hash。
精确 hash profile 固定在 `contracts/ptcgdap/cabt_tree_hash_profile.json`：受限 I-JSON 上的 RFC 8785 JCS、
SHA-256、三个 domain tag、有限 binary64、安全整数、UTF-16 键排序、surrogate/noncharacter 拒绝、
missing/null 区分且不做 Unicode normalization。bytes 入口只接受无 UTF-8 BOM 的严格 JSON；
内存 tree 的字符串值与对象键必须是运行时的精确 JSON string 类型，Godot `StringName` 不作隐式转换。
P1-WP2 已由同一份语言中立 vectors 证明
Python/GDScript canonical bytes、hash 与 fail-closed error code 对齐；在 firewall 接受前
`public_observation_hash=null`。合约文件自身另用 `canonical_json_v1`：精确 JSON runtime types、
安全整数、Unicode code-point 键排序、拒绝 surrogate/noncharacter 且禁止 float；不得与对局
observation 的 JCS 混用。两端 contract loader 对 bundle 与每个 artifact 另锁原始输入不超过 2 MiB；
该门不等于声称任意 canonical-json 调用都具有相同资源上限。

三个 domain 的输入不是同一棵树的三个别名：`raw_private` 对完整 Host callback；
`token_free_callback` 对其深拷贝且只替换根级 Search capability；`public_observation` 只对
firewall 接受后的独立 allow-list 投影，投影中不得出现 token 或 presence marker。原始 additive
字段继续隔离，除非后续经审查的公开 schema 明确允许。`source_contract_hash` 不是 observation
hash；它固定 `contracts/ptcgdap/cabt_contract_bundle.json`。P1-WP1 的历史审查值为
`50FC7A507F2E4FE194447C535D51FF0B375AD34B604533E83DECA810D4FA2844`。P1-WP2 当前值为
`A9BD1BBB725FF002DCE5BF60043AD62AC078EC07E2FDB772ED394AC5FA3EE6F3`，精确绑定 envelope schema、
hash profile、enum snapshot、Option 稀疏形状、typed-wire profile 与共享 conformance vectors；
P1-WP3 当前值为 `2CD02F54538985426EFDB057F3A6BDA4AD154DD171BCC03667D42D102982D294`。它保留
六项父 artifact 路径与其中四项 canonical hash；另外审查并修订 raw-envelope schema 的说明文字和
tree-hash profile 的跨运行时 `canonical_json_v1` 子集，再精确绑定 selection-window schema、
selection profile 与共享 selection vectors。Python/GDScript loader 都要求九项 ID/path/hash 唯一完整，并拒绝缺项、额外项、
重复或错配。该 hash 只证明 P1 pure core 的离线合同，不是 public-firewall、Host 或 live 声明。

P2-WP3 另建不改写 P1 bundle 的 subordinate firewall bundle，canonical hash 为
`A2781CE6B3AC7BB6BAD04A9F15F57CE23AEC338306F60E5B3050B31245685947`。它精确绑定 public
observation schema、firewall profile 与 23 条 shared vectors，并把父合同固定为上述 P1-WP3 hash。
两端只接受 replay-verified P1 envelope，再正向构造 `select/logs/current` 与实际 present 的 framework
字段；unknown additive key/value、Search capability/presence 与 private hashes 不复制。这个 hash 和
`public_observation_hash` 只证明 official-wire shadow firewall，不证明 Godot engine projector、Host 或 live。

P2-WP4 再建独立 subordinate log-cursor bundle，canonical hash 为
`ED246F029531AA8F21956A64D70F557F1BBC90450A6F9109C5286261E290319D`。它精确绑定 schema、profile 与
4 条 witness vectors，并把父 firewall 固定为上述 P2-WP3 hash。witness payload 只含 ordinal、previous witness、
source public-observation hash 与 exact ordered logs；前缀为 `PTCGDAP\\0CABT_PUBLIC_LOG_SLICE_V1\\0`，
canonicalization 为 RFC8785-JCS。它只证明 offline exact-owner cursor 语义，不证明 Godot engine log 来源、
public trajectory persistence、Host selection boundary 或 live。

P2-WP5 再建独立 subordinate Godot projector bundle，canonical hash 为
`C51EA4CF1AEFCBB5B9C6D83825FF3A717CCDCC4105B804210BF6169372619041`。它精确绑定 strict projector
schema、positive-provenance profile 与 W1–W7/rejection vectors，并固定上述 P1、catalog、firewall 和 cursor
父身份。GDScript owner 从 exact engine objects、match registry、strict catalog/source bytes 与 direct-reference
public events 正向枚举 official-wire shape；Python 仅作为语言中立 conformance reference。这个 hash 只证明
offline shadow engine-to-public projection，不证明 official option generation、decision port、window binding、执行或 live。

策略可以看到经允许的时间预算摘要，但不得获得 `search_begin_input` 原文。

## 4. `current` 的公开状态

`State` 核心字段包括：

- `turn`、`turnActionCount`、`yourIndex`、`firstPlayer`、`result`；
- 本回合 Supporter、Stadium、手贴、撤退标志；
- 当前 Stadium；
- `players[2]`；
- 当前被查看的公开/授权卡牌 `looking`。

`PlayerState` 的公开边界：

| 区域 | 自己 | 对手 |
|---|---|---|
| Active/Bench | 公开；面朝下 Active 可为 null | 同规则 |
| Hand | `hand` 完整可见 | `hand=null`，只有 `handCount` |
| Deck | 只有 `deckCount` | 只有 `deckCount` |
| Prize | 面朝下位置为 null | 面朝下位置为 null |
| Discard | 公开 Card 列表 | 公开 Card 列表 |
| Status/Energy/Tool/Evolution | 公开 | 公开 |

只有在牌库选择窗口中，`select.deck` 才会携带当前获准查看的牌库候选。不得把私有
Godot deck 顺序填入普通 observation。

## 5. Portable identity

官方 Card：

```text
id           # 官方数值 Card ID
serial       # 本局每张实体牌的唯一 serial
playerIndex  # 所属玩家
```

官方 Pokemon 在此基础上携带 HP、能量、工具和进化链。Portable identity 不得使用：

锁定 wire serializer 会给 Pokemon 发出 `playerIndex`，但当前官方 Python `Pokemon`
dataclass 没有该字段并会由 helper 静默丢弃。因此 `playerIndex` 是已验证 wire-known field，
typed view 不能仅照抄 SDK dataclass。

- 本地 UID；
- 卡牌中文/英文名；
- Godot `Object` 或 `instance_id`；
- 当前 hand/bench index 作为跨窗口永久身份。

Godot Host 必须拥有明确的 `local_uid <-> official_card_id` catalog 和本局全局唯一
serial registry。映射缺失时，该牌组标记为 `cabt_exportable=false`，不能靠名称
猜配继续运行。

## 6. SelectData

`SelectData` 字段为：

```text
type
context
minCount
maxCount
remainDamageCounter
remainEnergyCost
option[]
deck
contextCard
effect
```

当前官方 `SelectType`：

```text
MAIN, CARD, ATTACHED_CARD, CARD_OR_ATTACHED_CARD, ENERGY,
SKILL, ATTACK, EVOLVE, COUNT, YES_NO, SPECIAL_CONDITION
```

当前 `SelectContext` 覆盖 setup、switch、区域移动、伤害/治疗、进化、附着/丢弃、
`SKILL_ORDER`、攻击、数量、先后手、mulligan、效果发动和特殊状态等。官方明确
允许比赛期间向 enum 末尾追加元素。因此：

- 生成快照用于已知语义；
- runtime 同时保留 raw integer；
- 未知值不得触发崩溃或任意猜测；
- 使用同一窗口的合法、确定性 fallback 并记录审计事件。

枚举解释采用三态：`official_known`、`locked_engine_only`、`unknown_future`。例如官方
SDK `AreaType` 只声明 1–12，但生产 replay 的公开 `MOVE_CARD` log 已出现 `toArea=14`；
该值只能标为锁定引擎侧事实，不能冒充 SDK enum，也不能因闭枚举转换而崩溃。

`SKILL_ORDER` 表示效果发动顺序。多选结果不能被通用 sanitizer 排序成无序集合。

## 7. Option

Option 的 type-dependent 字段包括：

```text
type, number, area, index, playerIndex,
toolIndex, energyIndex, count,
inPlayArea, inPlayIndex,
attackId, cardId, serial,
specialConditionType
```

Option 是稀疏对象：`type` 总存在，其余键按 OptionType 出现。字段缺失与字段显式 null
不是同一状态，不得为了统一结构补 null。17 种当前 OptionType 的精确键集冻结在
`contracts/ptcgdap/cabt_option_sparse_shapes.json`。

每个 option 的 fingerprint 必须包含：

1. 当前 `select.type/context`；
2. option 原始位置；
3. option `type`；
4. 所有实际 present 的官方字段；显式 null 进入 payload，missing 则省略；
5. `contextCard/effect` identity；
6. observation hash 与 window ID。

fingerprint 使用独立 `cabt_option_fingerprint_v1` domain，窗口、option 与初始 deck 不能复用
observation hash domain。它用于审计和 Godot command binding，但 Agent 对外仍返回原始 index。

## 8. 输出约束

正常 callback 的返回值必须同时满足：

```text
type(result) is list
minCount <= len(result) <= maxCount
0 <= index < len(select.option)
每项 type(index) is int，bool/IntEnum/float/string 不得冒充
所有 index 唯一，顺序原样保留
```

Policy 给出的合法顺序必须原样保留。Host validator 不得为“稳定”而统一排序。

建议的确定性 fallback：

1. 初始 callback：只返回已验证的固定 deck；无合法 deck 时显式失败。
2. `minCount == 0`：返回 `[]`。
3. `minCount == maxCount == len(option)`：按官方顺序返回全部 index。
4. 其他已知或未知窗口：返回前 `minCount` 个当前合法 index。
5. 若 `len(option) < minCount`，这是 Host/engine 合约错误，不得制造 index；记录并阻断。

这是安全与合法性 fallback，不代表最佳策略。

## 9. Incremental logs

`logs` 是选择到选择之间的增量，不是整局事件重放。Godot 端必须维护独立 log
cursor，并在成功生成下一 observation 后推进 cursor。

必须区分：

- event accepted；
- option bound；
- command executed；
- public witness observed。

不得因为发出 engine method 就提前写“执行成功”。`accepted-unexecuted` 必须在验收中
保持为 0。

## 10. Search API

`search_begin_input` 由官方 native engine 生成，`search_begin()` 要求把本次官方
observation 原样传入，并提供对隐藏区的预测。它是 belief/counterfactual search，
不是隐藏信息 oracle。

规则：

- Token 只存在于 Kaggle Host 的临时 capability adapter。
- 不进入模型、Strategic Context、公开 trace 或持久 replay。
- Godot 自研引擎不得伪造 token。
- 默认 Godot capability 为 `search=none`。
- 若未来要求 Godot 也具备官方 Search API，必须单独引入官方 native bridge，并作为
  独立、可关闭、可回滚能力验收。

P3-WP1 新增的 `EngineDecisionPort` snapshot 仍是 Godot Host-private source 边界，不是官方 CABT wire 对象；其
`source_digest`/`snapshot_id` 不得写入 CABT Option、替代 option fingerprint，或被当作 `search_begin_input`、window、binding、
ticket 与执行 authority。官方 `select.option` 的 portable 映射仍须由后续 Host owner 从当前 snapshot 正向构造。

P3-WP2 新增的 `GodotOptionBinding` 同样只属于 Godot Host-private authority：独立 bundle canonical 为
`4FFFEC48E4E1FE0774BB6E343D4D4B0384A9210057DEE06415C2A20F2899B1C1`。它把 exact current port snapshot、
exact current selection window、option position/fingerprint 与 private callback/command/object refs 绑定，但这些 private
字段零输出到 official wire、public observation、fingerprint payload 或 serialized audit。binding 本身也不是 ticket、commit
或执行 authority。

P3-WP3 新增的 one-use `GodotActionTicket` 仍只属于 Godot Host-private claim seam：独立 bundle canonical 为
`41F3E84C6DC5C9BC6C162B848B097211E617B5558ECB59554757E82CE58817ED`。ticket id 绑定 private session/callback、
exact current binding/window/public hash 与 ordered selected indexes/fingerprints；serialized audit 只保留非私密 audit identity，
不输出 session、callback、current source、command/object refs。成功 claim 最多一次且只返回 exact private binding resolutions；
本包不调用、提交或执行 engine command，因此也不构成官方 CABT action execution parity。

## 11. 时间、资源与网络

当前 CABT 配置快照：

```text
actTimeout = 0
remainingOverageTime = 600 seconds
runTimeout = 2000 seconds
episodeSteps = 10,000,000
```

`actTimeout=0` 表示没有免费单步额度；callback 耗时直接消耗整局 overage bank。
Policy 应有分档 TimeBudget，并保留终局/异常 fallback 预算。

当前比赛页面资源快照约为：

- submission archive 197.7 MiB；
- 11.8 GiB disk；
- 12.2 GiB RAM；
- 2 vCPU；
- 未承诺 GPU。

比赛规则明确禁止 episode 期间 ingress/egress。Kaggle runtime 不得调用在线 LLM、
API、数据库、遥测或赛中下载。依赖、模型、规则、Card catalog 与权重必须随包或由
平台环境提供。

## 12. 版本与兼容声明

当前存在多个版本命名空间：页面标签、local vendor、线上 replay、CABT env schema、
CABT docs 互不相同。兼容声明必须同时绑定：

1. 官方 bundle 文件哈希；
2. CABT environment schema；
3. 生产 replay/module 证据；
4. 本项目生成 schema/enum/catalog hash；
5. policy/executor hash。

具体值见 `SOURCE_LOCK.json`。schema v2 使用逻辑 root 加相对路径，保留原机器
`captured_path` 作为 provenance；官方 manifest 自身先锁 hash，验证通过后才信任其 60 个
条目。Git 管理的本地 JSON 可使用已声明的 `canonical_json_v1`，避免 CRLF/LF 改变结构身份。
任何现有来源 hash 变化仍必须先进入 P0 contract diff，不能顺手刷新锁后继续实现。

## 13. 官方合约最小测试集

- 初始 null observation 与 60 卡返回。
- raw extras 保留。
- known field round-trip。
- unknown additive field 保留。
- unknown enum 不崩溃且 fallback 合法。
- forced selection、optional-zero、multi-select、empty option。
- index 范围、唯一性、min/max 与顺序。
- 两席位/多 episode session reset。
- public visibility sentinel。
- incremental logs cursor。
- opaque search token 不泄漏。
- time budget 降级。
- package root、最后 callable、offline import 与双座位运行。

### P3-WP4 Host-private executor 边界（2026-08-10）

P3-WP4 的 `GodotActionExecutor` 独立 bundle canonical 为
`45952BE629AE98EB6070C77188FD6A2C2A644C4B6A36876193BB745B7CDA4E92`。preflight 与 commit 都重验 exact
P3-WP3 claim、current binding/port/snapshot/window/callback/source 与 ordered private resolutions；成功 commit 只原子返回整批
resolution，不调用 engine method。serialized audit、preflight id、schema pass 均不构成 CABT 或 live execution authority。

### P3-WP5 Host-private prompt broker 边界（2026-08-10）

P3-WP5 的 `ShadowPromptBroker` 独立 bundle canonical 为
`D19EC7B9B77370312C82E0572DFB016B75E3FE9F438B6C1EFFD50E0AB43C551E`。W1–W7 共用同一生命周期合同；每个 prompt
绑定 exact broker generation、family、decision snapshot、window、binding、callback 与 owner-produced selection。成功 non-live commit
后必须 re-observe，并提供严格更新且不同的 snapshot/window/binding 才能打开下一 prompt。family 仅用于审计分类，不能扩大 option
frontier 或放宽 sanitizer/cardinality。serialized broker audit 不含 private resolutions、session、callback、source、command 或 object refs，
也不授予 engine execution authority。

### P3-WP6 Host-private whole-match owner gate 边界（2026-08-10）

P3-WP6 的 `ShadowMatchOwnerGate` 独立 bundle canonical 为
`9B8202E67756E388AFB0A13EA1FD20227ADF0718DF8454420A2B1FC7A5D31B8C`。每个 active match 只能固定
`legacy` 或 `aligned_shadow`；aligned 必须绑定同一 match generation 的 exact P3-WP5 broker。rollback request 不改变当前 match，
只在下一严格更新 generation 一次性强制 legacy。serialized audit、schema pass 或复制结果均不授予 CABT、owner 或 engine execution
authority；本包没有 live/UI/headless consumer，也没有调用 engine method。

### P3-WP7 isolated shadow command applier 边界（2026-08-10）

P3-WP7 的独立 applier bundle canonical 为
`7539A9D5120666AEBA1325DD6623F437831A024996BD612F3EC677F78C9F8F4C`。applier 只接受 exact active
`aligned_shadow` gate、其 exact 同代 broker 与 successful committed result；命令必须是互不重复的对象，并提供闭集
`shadow_capture()`、`shadow_apply()`、`shadow_restore(snapshot)`。capture 是只读观察钩子；apply 失败后必须逆序恢复全部
captured state，否则 applier 永久 poisoned。serialized executed witness 只绑定 match/broker/snapshot/window/index/fingerprint，
不包含 private command/object/state/session/callback/source，且 schema、DTO 或 witness 都不构成 CABT 或 execution authority。
本包没有定义 production engine command adapter，也没有改变官方 CABT wire 或 live owner。

### P3-WP8 offline whole-match integration 边界（2026-08-10）

P3-WP8 的独立 whole-match bundle canonical 为
`0C5A8FDAB61A73F623EA6B0D364C38E6C4797087287B3DF3C88D0191261296B5`。harness 只编排 exact P3-WP6
aligned gate、同代 P3-WP5 broker 与每 prompt 新建的 P3-WP7 applier；它不改变 CABT raw observation、option frontier、ticket 或官方 wire。
成功链必须严格增加 broker/decision generation，并禁止复用 snapshot/window/execution ID。任一 prompt fault 会终止当前 aligned 路径，
恢复失败显式标记 dirty，并只请求下一严格更新 match generation 一次性 legacy rollback。serialized report 是 private-free、
non-authoritative audit，不是 CABT、Host 或 execution authority。本包没有 live consumer、production command adapter、feature flag 或 canary。

### P4-WP1 StrategicContextV18 / PolicyDecision 公共合同边界（2026-08-10）

P4-WP1 的独立 public-strategy bundle raw 为
`4A7D740391DC72B120D2D120B5EEBF278DD13648216F51A78347CC1A01A97D8C`，canonical 为
`AACFA7E2E7F914180A2B7A5C4D92D6514ACC5F4622FC95B57DC225673893F98F`。`StrategicContextV18` 只从 exact、当前仍有效且
accepted 的 `PublicFirewallResult` 与其 exact matching `CabtSelectionWindow` 编译：acting seat 手牌保持可见，对手手牌必须为
`null`，当前 option 顺序与既有 fingerprint 原样绑定，公开 logs 作为 event delta，opponent belief 在本包固定为无候选的
`unknown` 占位。Search capability、private envelope hashes、session/callback、Host object/binding/ticket/command 与 Host entity serial
均没有输入或序列化路径。

`PolicyDecision` 只接受同一个 exact context、同一个 current window 与 owner-produced `CabtSelectionResolution`，把有序 indexes
绑定到当前 option fingerprints、context hash 与 policy hash。其 dict、`context_hash`、`audit_id` 和 `selected_indexes` 副本都只是
公开审计 DTO，不授权 binding、ticket、engine command 或 live execution。P4-WP1 不包含 Base Graph IR/executor、adapter、policy、
Strategic Trace v2 完整管线或 live owner，因此 P4-01、P4 总门与 A0–A5 均未因此通过。

### P4-WP2 Strategic Trace v2 / restricted Base Graph IR 合同边界（2026-08-10）

P4-WP2 的独立 bundle raw 为 `99577D5D4F466C7ECF7B3AEDBF8F5ABEC707E37123641C3746890743A50FA702`，canonical 为
`ADDD4CB48BD10FA0478854124D8E63AEE42B898C0EB81692BA35F8D7F90414C4`，父指针精确绑定 P4-WP1 canonical
`AACFA7E2E7F914180A2B7A5C4D92D6514ACC5F4622FC95B57DC225673893F98F`。restricted IR 只允许 6 个按固定次序出现的
Base operator（legality、mandatory/terminal、hard tier、veto、fallback、emit）与 3 个 public adapter proposal operator；config、owner、
capability 与单入口线性 DAG 均为封闭集合，callable/module/class/path/code 与 `PRIVATE_*` identifier 不在语言域内。

Strategic Trace v2 只由 exact current `StrategicContextV18`、其 exact bound `PolicyDecision` 与 exact compiler-owned IR 构造；它记录当前
option fingerprint、legal/strategic/mandatory/terminal index、Base hard tier/veto、adapter proposal 与 owner/reason audit，并在独立
`STRATEGIC_TRACE_V2` domain 签名。IR/trace dict 都是 non-authoritative public audit/conformance value，不是 CABT、policy、executor、
binding、ticket 或 engine authority。本包没有 IR executor、adapter、policy/model、time-bank、live owner、package/device 或 engine parity；
仅 P4-01 合同项关闭，P4-02 至 P4-06、P4 总门与 A0–A5 仍未因此通过。

### P4-WP3 restricted Base Graph executor 边界（2026-08-10）

P4-WP3 的独立 bundle raw 为 `B11EC37BE93A8712960D45BA51AA60F41AF74FAEF69545F6DED6ECB55938C9CA`，canonical 为
`69D05747A9F91C19765D448B676C86E1D9DFA1BBAB108ED1374B854B34E48389`，父指针精确绑定 P4-WP2 canonical
`ADDD4CB48BD10FA0478854124D8E63AEE42B898C0EB81692BA35F8D7F90414C4`。executor 只消费 exact current
`StrategicContextV18` owner 与 exact compiler-owned restricted IR；serialized context/IR 或 schema-valid clone 都不授予执行。

执行优先级固定为 terminal → mandatory → legal frontier → minimum hard tier → Base veto → same-tier adapter ordering → deterministic fallback。
adapter goal/macro/tiebreak 只能排序仍在同一最佳 Base tier 内的候选，不能移除或重排 forced terminal/mandatory indexes，也不能恢复被 veto 的候选。
结果绑定 exact context/IR owner 与 execution hash，但只是 non-authoritative public audit；current-window sanitizer、binding、ticket 与 engine executor 仍必须
在后续 owner 中重新验证。P4-02 已关闭；P4-03 至 P4-06、P4 总门与 A0–A5 仍未因此通过。

### P4-WP4 public deck adapter proposal 边界（2026-08-11）

P4-WP4 的独立 bundle raw 为 `8ED483B801195DA19F47C375EC98DD5E0F5F90F7178B7C83F7CF3968EDD4E5A8`，canonical 为
`C80F4C4FDAEA5AC29BD3C5617BFAC72BE38709696F7EA1995D3D153113DD3CA1`，父指针精确绑定 P4-WP3 canonical
`69D05747A9F91C19765D448B676C86E1D9DFA1BBAB108ED1374B854B34E48389`。adapter 只消费 exact current P4-WP1
`StrategicContextV18` owner；规则语言固定为 7 个 goal stage、3 个 proposal operator 和 7 个 official/public numeric predicate，禁止名称、
路径、callable、private state 与任意表达式。

输出只包含 executor-compatible goal/macro/tiebreak same-tier ordering hints、matched-rule audit 与独立 proposal hash。minimum priority、source rule
order 与 current option index 构成唯一排序；serialized adapter/result 均不授权 legality、terminal/mandatory、hard tier、veto、fallback、
selection、ticket 或 engine。P4-04 关闭；P4-03、P4-05、P4-06、P4 总门与 A0–A5 仍未因此通过。

### P4-WP5 public Base policy orchestration 边界（2026-08-11）

P4-WP5 的独立 bundle raw 为 `08C326F997B6DBE513FA00874F6DFDF12156547C4F47E1DF9D943FF490267B05`，canonical 为
`18AAB663D9B429AC8657A75692F5DD8CF37C409CC057A328B57758C692FDB7F4`，父指针精确绑定 P4-WP4 canonical
`C80F4C4FDAEA5AC29BD3C5617BFAC72BE38709696F7EA1995D3D153113DD3CA1`。一次调用必须绑定 exact current
`StrategicContextV18`、selection window、restricted IR 与 public adapter owners，并按 validate → propose → execute → sanitize →
PolicyDecision → Strategic Trace → seal 的固定次序运行；任一阶段失败只返回封闭 stage/error，且不发布部分结果。

terminal 非空时只以 terminal 为 forced frontier，否则以 mandatory 为 forced frontier；只有没有 forced frontier 时才允许 minimum hard tier
决定选择。Base 始终拥有 legality/cardinality、forced、tier、veto、fallback 与 emit，adapter 只能给存活的同一 Base tier 排序。executor
结果在签发 decision/trace 前必须再次由 exact current-window sanitizer 验证。serialized orchestration/decision/trace 仅作 public audit，
不授予 selection、binding、ticket 或 engine authority。P4-03 与 P4-05 的离线子门关闭；P4-06、P4 总门与 A0–A5 仍未因此通过。

### P4-WP6 time-budget 与 capability degradation 边界（2026-08-11）

P4-WP6 的独立 bundle raw 为 `D4FBDF0D326AF4D03701DF1125F39F65CFCA032E70BC5EE310B8FBC26E73AB6E`，canonical 为
`0D82BDE31BD0FA0C44527880D9D6451C2733702913708532C512F3BFF81D8BF9`，父指针精确绑定 P4-WP5 canonical
`18AAB663D9B429AC8657A75692F5DD8CF37C409CC057A328B57758C692FDB7F4`。纯核心不读取 wall/monotonic clock；每步只接受未来 Host
提供的 exact nonnegative safe-integer `elapsed_ms`，并把 600000 ms 总预算饱和扣减。剩余预算 `<=30000` 进入 `base_only`，`<=5000`
或耗尽进入 exact current-window deterministic fallback。

required capability 缺失、`unavailable` 或 `unsupported` 必须 fallback；unknown capability 同样 fallback，但 serialized result 只写 unknown count，
不回显名称。optional adapter 不可用只允许 `base_only`；optional learned/search 不可用不会变成 required、网络或远程 fallback。ledger/result/hash
均为 non-authoritative audit，fallback indexes 必须重新绑定 exact current window。本包关闭 P4-06 离线子门与 P4 offline pure-core chain，
但不提供 Host clock、live owner、engine command、model、package/device、A0 或 A1–A5 结论。

### P5-WP1 Marnie identity/capability/public trajectory fixture 边界（2026-08-11）

P5-WP1 的独立 bundle raw 为 `32150BFB80E0ED5845E43F185FB4D74C82ED7EFA03CC9B38EBF6034ADBBDCC2A`，canonical 为
`7E0CF80D7B2872C29F69BA15548857F1F32407943371D3C12A266A0E471EC425`，父指针精确绑定 P4-WP6 manifest canonical
`93B0F8170124AE5DD184FBD1BD17BBEC60C805A6EFC9D348C1B5ADAF5AD3369E`。它只绑定 exact official/local 60-card manifest、
明确的 identity diff、10 项 capability inventory 与 13 个 source-locked public W0–W7 frames；不修改 CABT 主 bundle、P4-WP6 bundle 或
`SOURCE_LOCK.json`。

官方 deck 的 ordered 60 Card ID 是官方初始牌组 authority；本地 `800018501` 是另一份 printing identity，二者不得按名称、文本、图像或
same-print 猜配。官方侧 bridge 只覆盖 34/60，本地侧 exact bridge 只覆盖 15/60，且 Ability numeric identity 不可从官方 payload 合成。
public trajectory 只保存 acting-seat-visible tree、既有 `public_observation` hash、serialized selection window/fingerprint/cardinality 与 visibility audit；
原始 replay container、Search capability、private hashes 与 engine object 不进入 artifact。

W2 setup-bench 的官方 public frame 含 own-active concealed placeholder；当前 P2 firewall 因 `own_active_concealed` 拒绝。P5-WP1 保留该 exact
rejection，同时证明 frame 中 raw selection 可独立构造 `policy_allowed` window；这不把 rejection 改写为 accepted authority。生产 replay action
统一标记 `not_policy_golden`，除 exact initial-deck action 外均不授权 policy output。serialized fixture/result 只作 audit/conformance，不授权
selection、binding、ticket、policy、Host 或 engine；最小 W2 合同修正与 public trajectory replay 属于 P5-WP2。

### P5-WP2 setup concealment overlay 与 trajectory replay 边界（2026-08-11）

P5-WP2 的独立 bundle raw 为 `AC4D798C411BD3D4AF93F3F23789C70E5DDE09ABBF5C50C2333A751CCFCADB07`，canonical 为
`E203A688BEC1AFFFABAAF06098361B3FAE04B84431F99AE75A19F891BFA9599F`。它绑定 strict schema/profile、19 个共享 conformance case 与
13-frame replay artifact；P2 firewall bundle canonical `A2781CE6B3AC7BB6BAD04A9F15F57CE23AEC338306F60E5B3050B31245685947` 和
P5-WP1 fixture bundle 均保持原 identity。

基础 P2 `project()` 仍必须对 W2 返回 `own_active_concealed`。P5 overlay 只在 exact `CARD(1)/SETUP_BENCH(2)`、turn `0`、result `-1`、
`minCount=0`、`0<=maxCount<=len(option)`、remain 字段为 `0`、deck/contextCard/effect 为 null、双方 active 均为 `[null]`，且 acting hand 可见、
opponent hand/prizes 隐藏、logs 满足既有 public gate 时接受。输出保留 concealed placeholder，不推断 card identity；任何字段、type、visibility 或
shape 扩张均 fail closed。13 帧 replay 只复算 firewall result、public hash、current window/fingerprint 与 ordered audit chain；production action、
Search capability、private replay container 和 selected indexes 不构成 authority。

### P5-WP3 capability policy overlay 边界（2026-08-11）

P5-WP3 的独立 bundle raw 为 `56DBAD25BF1EAC32F17EF65E768E0C143EB81E4F5A65C6C41076F0F859D36CF0`，canonical 为
`F4E88E5DB4E480BA8441BE7B3A7C81CE3DB40ED1917EB37BCDCAC1C32B1ABD6C`。它只绑定 strict schema/profile、source-locked rule artifact 与
23 个共享 conformance case；P5-WP1 fixture bundle、P5-WP2 replay bundle、P2 firewall bundle、CABT 主 bundle 与 `SOURCE_LOCK.json` 都保持原 identity。

policy owner 只读取 exact P5-WP1 frame 与 P5-WP2 replay result，并在同一 owner 调用中重新核对 public-observation hash、window ID、option
fingerprints 与 cardinality。常规输出只能是当前窗口的唯一合法 indexes；W0 是 exact official 60 Card ID fixture；terminal 明确无 callback。
W4/W5/W6 的数值匹配只使用 artifact 中已授权的公开 deck candidates、official Card ID 648/7 与 official Attack ID 937。production replay action、
名称/文本/图像、隐藏 identity、Search token、private replay 与 engine object 都没有输入路径。

serialized result 与 decision-hash chain 只作 audit/conformance，`validate_integrity` 也不授予 Host capability、current live window、binding、ticket、
engine command 或执行权。未来 consumer 必须从 live current window 与受信 owner 同一调用链重新验证；当前完整父链加载成本仅适合 offline shadow。

### P5-WP4 identity/projector integration attestation 边界（2026-08-11）

P5-WP4 的独立 bundle raw 为 `1388050C7975CC918E0340F9706CAB4EF0E6D60758696235D853728DFD8E9DD4`，canonical 为
`1EB530AB7DFACBE6AB098A6C67D6AAE0BC1871FF3E2F48C9284E8539EE6ACDC4`。它只绑定 strict schema/profile、23 个共享 conformance case 与
13-frame identity audit artifact；父 P5-WP1/P5-WP2/P5-WP3、CardIdCatalog、GodotObservationProjector、GodotSerialRegistry、CABT 主 bundle 和
`SOURCE_LOCK.json` 均保持原 identity。

13 个 source-locked frame 的公开 identity 必须完整分区为 catalog-known mapped 或 catalog-known local-unmapped；unknown Card/Attack ID、Attack owner/order
不一致、同一 official serial 的 player/card relation 漂移、隐藏字段或 host-type 替换均 fail closed。当前 audit 固定 573 个公开 identity occurrence、
94 个跨帧唯一 official serial、34 个 official Card ID，其中 9 个 mapped、25 个 known-unmapped。official Marnie exact-60 继续固定 19 个唯一 Card ID，
只允许 9 个 ID/34 张 exact bridge；其余 10 个 ID/26 张不得按名称、文本、图像、效果或 same-print 推断。

Godot-only engine attestation 必须从 source-hashed mapped CardData、sealed match-scoped serial registry、exact catalog 与 exact projector owner/result 同一调用链
重验公开树。这里仅证明物理 CardInstance 到公开 `serial` 的关系和 hidden/Host-private 零输出；官方 replay serial 与 Godot registry serial 是两个独立分配域，
不得声明数值相等。serialized result、audit hash 与 attestation DTO 只作 audit/conformance，不授权 Host、window、selection、binding、ticket 或执行。

### P5-WP5 W1–W7 broker/current-window integration 边界（2026-08-11）

P5-WP5 的独立 bundle raw 为 `8EBD0CB33DEF2BBA81541B93FB3D8624D8C25722D51425F488EF3DEB66B7DFD4`，canonical 为
`E2EFDDE373EFBA0FDC929BE817595C8B3F0A5653956DB56418ADED57AFF960A1`。它只绑定 strict schema/profile、13-frame broker audit 与 23 个共享 case；
父 P5-WP1 至 P5-WP4、P3 shadow broker/decision port/option binding、CABT 主 bundle 与 `SOURCE_LOCK.json` 均保持原 identity。

W0 只保留 initial-deck fixture；11 个非终止 callback 必须从 exact source frame 新建当前 `CabtSelectionWindow`、严格更新的 decision snapshot 与
Host-private option binding，经过同一个 `ShadowPromptBroker` 的 open → prepare → non-live commit 后进入 `awaiting_reobserve`；terminal 不创建 callback。
W3 的 OptionType `[8,8,7,14]` 与 W6 的 `[7,13,12,14]` 必须原序保留，W2 optional-zero 必须提交零项。P3 owner 的扩展只可由 exact P5 profile 显式启用；
default P3 路径继续拒绝未支持形状，原 bundle 不重签。

fixture capability 不得调用 engine method。serialized result、lifecycle hash 与 audit DTO 不得包含 command/object/callback/session/source/ticket/private resolution，
也不授予 current window、ActionTicket 或 execution authority。本门只关闭 offline broker/current-window integration 子门，不证明 live/UI/headless Host、Base
orchestration、engine execution、package/device、canary、engine parity、A0 或 A1–A5。

### P5-WP6 public Base/macro orchestration 边界（2026-08-11）

P5-WP6 的独立 bundle canonical 为 `67EBA6348277001692942FD58E8D1B9D50C54F0FFC783D8802BA3CCB45691105`。它只绑定 strict
schema/profile、16 个 shared case 与 exact audit artifact；父 P5-WP1 至 P5-WP5、P4 public Base owners、CABT 主 bundle 与 `SOURCE_LOCK.json`
均保持原 identity。

适用 case 必须从 source public frame 重新经过 exact firewall，构造 fresh `firewall_accepted` `CabtSelectionWindow`，再依次重验
`StrategicContextV18`、restricted IR、六个 numeric-only macro、`PublicDeckAdapter`、`PublicBasePolicy`、same-window sanitizer、
`PolicyDecision` 与 Strategic Trace v2。13 个 source-locked production frame 与 3 个 `offline_seeded_extension` 必须保持证据类别隔离；
W0、W2 与 terminal 明确 N/A，不伪造 Base authority。

Base 继续独占 legality、mandatory/terminal、minimum hard tier、veto、fallback 与 emit；adapter 只能在存活的同一 tier 提供排序 hint。
serialized result/macro proof/decision/trace 只作 public audit，不授权 Host、current window、binding、ticket 或 engine execution。本门无 live/UI/headless
consumer、canary、package/device、engine parity、A0 或 A1–A5 声明。

### P5-WP7 constrained portable differential 边界（2026-08-12）

P5-WP7 的独立 bundle canonical 为 `992B7F00DF412496BA414ABCC87C21C6136CB513C9C90799C897ADD18D15EDB2`，
四文档 integrity anchor 为 `6A2381855F98FB806B456F445AEE5A6F24A3C93A4ADE8259C8A106593AFC9210`。它只绑定
exact P5-WP3 capability-policy、P5-WP6 public-Base 与 P5-WP2 trajectory bundle；父 bundle、CABT 主 contract 与
`SOURCE_LOCK.json` 不重签。

Python/GDScript 必须重新执行父 owner，再按 closed dispatch 组合 13 个 source-locked frame：W0 initial deck 仍返回
official Card ID list；W2 setup-bench 保留 same-window optional-zero；terminal 只记录 no-callback lifecycle；其余 10 个
current-window frame 的 `list[int]` 只采用 P5-WP6 Base final decision。每个 window result 绑定 exact public observation hash、
window ID 与 ordered option fingerprints；stale/reorder 只返回 audited mismatch，不返回 action。

package 另以公开 domain 签发 portable trace chain，并保留父 capability decision 与 Base result/decision-audit/trace hash。
serialized package/audit、binding probe 与 tie-break probe 都不授权 current window、binding、ticket、Host command 或 execution；
本门不完成 live/UI/headless consumer、canary、export/package/device、engine parity、A0 或 A1–A5。
