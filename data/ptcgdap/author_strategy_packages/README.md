# Author strategy packages

这是 Godot 内置作者策略包的唯一固定根目录：

```text
res://data/ptcgdap/author_strategy_packages/
```

用户安装包只从以下固定目录扫描：

```text
user://ptcgdap/author_strategy_packages/
```

AS-WP2 启动 catalog 只读取 `.ptcgai` 的 captured bytes，验证确定性 ZIP、路径、资源上限、逐文件哈希、test-fixture Ed25519 签名、兼容合同、精确 60 卡 deck 文档和受限策略文档，然后发布 copy-only 元数据与稳定诊断码。启动扫描不会构造策略 owner、不会加载权重到执行器、不会映射本地对战牌组，也不会授予 match 或 engine authority。

AS-WP6 现放置一个固定的开发候选包 `ptcgdap-author-strategy-release-candidate.ptcgai`。它是 Marnie `800018501`
“18.0 玛俐的长毛巨魔”的 Windows-local deck 候选：18792 bytes，SHA-256
`32E25453431886F76CEC606089ED4815EC681FBD33073F53A335A769D293643E`，使用 `godot_local_card_uid_v1`
精确锁定 28 个本地印刷 UID/60 张牌，`platform_scope=["windows"]`、`cabt_exportable=false`。牌组 manifest 同时锁定源 deck、
逐卡源文件和 effect 的 raw/canonical hash；adapter 的七条 Marnie macro 只引用 manifest 中的游戏 UID，config 绑定 exact manifest hash，
数字型 official ID、未知 UID 与跨域配置均拒绝；开战门还会经 `CardDatabase` 按 exact UID 重验。

该包用于证明内置包、受限策略、本地牌组和本地权重可被确定性纳入 Windows PCK/EXE，并能由导出后的 GDScript loader 重验。
它仍使用 AS-WP1 synthetic test-fixture key，明确为 `execution_trusted=false`。Python/GDScript Host 现会在独立 local-UID public-context
合同下编译并逐 prompt 绑定 adapter，产生 shadow indexes/audit；W1 development source 可用真实本地 UID 完成一次 current-window canary。
当前真实 W1 canary 使用已有 exact official bridge 的 `CSV8C_094` 建立旧 CABT 基础 context，再绑定同一窗口的游戏 UID；它不为其余
本地 printing 伪造 official Card ID。

D044 又只为这个 exact built-in archive 建立 Windows development player owner：BattleSetup 可启动开发态对战，BattleScene 使用不继承
`AIOpponent` 的独立 owner 驱动现有规则引擎，且不加载旧 deck strategy preferences。seeds 84400–84409 的 10 局验收为
593/593 policy success、586 engine commits、0 error/invalid/fallback/rejection。该开发例外不使包获得 production trust、Catalog ready record
或 `execution_trusted=true`，也不授权 user-installed copy。

D045 又以 Windows export template 完成 3 局 headless development 整局；D046 再用真实鼠标通过普通 MainMenu/BattleSetup/BattleScene
完成一局，并加入独立作者模式关闭开关。关闭后新局在 0 policy call/0 engine commit 前 fail closed，用户安装包文件不删除，进行中的
owner 不热切。D046 验收路径关闭应用启动网络客户端但未实施 OS-level network block，因此不构成 isolation 或 A5 证据；D057 后
OS-disconnection 取证由产品明确豁免，而不是验证通过。

production trust store、逐包 release approvals 与 device-canary approvals 目前均为 `unprovisioned`。D056 已以 3 局 ordinary-UI、173 个
决策样本证明固定 Windows 六项资源门，D057 再批准该 profile；当前 canonical `A8971FD...95169`、`formal_a5_eligible=false`，且
`os_network_isolation_proven=false`。因此 catalog 的
`ready_records` 仍为空，production 玩家开战门仍为 false；只有上述 exact Windows development candidate 有单独开发门。Marnie 的 Windows
60 卡本地牌组映射已经完成，但这不代表 production signing、official W0–W7 conformance、卡效/engine parity、商店发布或 A5 已通过。
Windows 飞行模式/WFP 验证是产品豁免，不是通过。Android 已按 D041 后移，既有 APK/AVD 只属历史开发证据。
D041 后 release profile、approval/device evidence 与双运行时 release gate 的当前 exact target 仅为 `windows`；Android 既不是 Windows
发布所需字段，也不能夹带进当前 platform evidence map。这个收口不改变 test-key non-promotion 或玩家开战门。

production 包必须通过 `tools/ptcgdap/sign_author_strategy_release_package.py` 离线签名。该工具只读取固定产品 trust store，要求仓库外、
non-symlink Ed25519 private key，并在写盘前校验派生 public key、正式 package loader 和 deterministic public-hash receipt。当前 store 仍
`unprovisioned`；因此任何真实签名请求都会 fail closed，目录内现有包仍只有 test-fixture trust。它仅能经 D043–D046 的 exact
Windows development gate 执行，不能取得 production authority。

禁止放入任意 `.gd`、`.py`、`.pck`、DLL、SO、AAR、EXE、嵌套压缩包或任何未列入 manifest/hash 表的文件。作者策略包只能携带由游戏内置执行器解释的受限数据制品。

设计与实施顺序见：

- `docs/ptcgdap/08-author-strategy-package-mode.md`
- `docs/ptcgdap/09-author-strategy-package-engineering-handoff.md`
- `docs/ptcgdap/10-author-strategy-developer-guide.md`

开发者应从仓库根运行 `tools/ptcgdap/author_strategy_developer.py`，按指南完成工作区创建、确定性开发构建、严格校验和公开窗口模拟。
不要手工复制或改写本目录中的 `.ptcgai`，也不要把开发工具生成的 test-fixture 签名包当作 production 包。
