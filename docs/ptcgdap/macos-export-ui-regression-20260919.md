# macOS 规则版导出与 UI 回归：2026-09-19

## 结果与范围

在 Apple M1 / arm64、macOS 15.7.2 上修复当前规则版的导入崩溃和真实下载包无法开战问题，重新导出、验证签名并安装到本机。独立诊断导出使用生产游戏代码，完成在线下载后的完整对局，以及操作系统禁止该进程联网后的重启、已下载列表和完整对局。

源码基线为 `origin/main` 的 `2b2ea57e5acc4a940a4e0a129a8d04e12325909e`，工作分支为 `codex/macos-export-ui-regression`。该基线已包含 Windows 交接文档列出的关键源码。构建记录同时保存 dirty 状态与逐文件 SHA-256；不能仅凭 HEAD 重建本次产物。

本次沿用交接文档第 5 节的规则版范围，Mac 模型策略支持仍暂停。未修改跨平台 GDExtension 描述、Windows/Android 导出、模型能力判断、官方 CABT 来源锁或私有服务。验收完成后，用户明确授权将本次代码提交并推送到 GitHub；安装包仍仅保存在本机，未上传或发布。

## 两个根因与修复

1. **干净导入崩溃**：Godot 4.6.1 在 macOS 扫描到指向缺失 dylib 的可选 GDExtension 时，出现 `NSBundle initWithURL` 异常。macOS preset 的排除规则只控制之后的导出，无法保护之前的导入。
   - 新增 `scripts/tools/export_macos_release.py`：建立全新公共源码快照，仅在快照的 `scripts/ai/ptcgdap/native/` 写入 `.gdignore`，然后导入和导出。不修改共享源码中的跨平台描述。
   - 固定官方 Godot 4.6.1；拒绝覆写已有输出目录；记录源码清单、导入/导出日志、包哈希、双架构与签名检查；即使进程退出 0，也拒绝含引擎错误的日志。
2. **下载完成却无法开战**：真实 e719 规则包的 28 张卡牌来源固定的是 Windows CRLF 原始哈希，Mac Git 工作区为 LF；JSON canonical 哈希全部相同。旧 `AuthorStrategyDeckGate` 因此返回 `package_deck_unmapped`。
   - Godot 与 Python 的本地卡组准入只增加同一 UTF-8 源码的统一 LF/CRLF 两种字节表示匹配，仍独立检查 canonical 哈希、卡牌身份、规则域和包签名。
   - 不接受额外空白、内容改写、错误哈希、转换路径上的混合换行或非法 UTF-8；不重新序列化后冒充 raw hash。
   - 保存未修改的公共下载包及来源哈希作为可离线复现 fixture。新增红→绿测试覆盖真实 60 张卡组 / 28 种印刷及篡改拒绝。

顺带修复两处 UI 回归夹具：桌面策略测试 mock 跟进当前 admission 接口；回放 UI 测试改用跟踪在 Git 中的合成公共回放，不再依赖缺失的本机 `artifacts/` 文件。合成回放仅验证 UI，不用作真实对局证据。

## 可复现命令

在仓库根目录执行；每次使用新的输出目录。先安装官方 Godot 4.6.1 macOS 编辑器及对应的 `4.6.1.stable/macos.zip` 导出模板。

```bash
python3 scripts/tools/export_macos_release.py \
  --godot .tmp/godot-4.6.1/Godot.app/Contents/MacOS/Godot \
  --output-root .tmp/macos-rules-new

python3 scripts/tools/export_macos_release.py \
  --godot .tmp/godot-4.6.1/Godot.app/Contents/MacOS/Godot \
  --output-root .tmp/macos-diagnostic-new --diagnostic

python3 scripts/tools/run_macos_rules_acceptance.py \
  --app .tmp/macos-diagnostic-new/unpacked/PtcgDeckAgent.app \
  --output-root .tmp/macos-acceptance-new
```

诊断导出使用独立 bundle ID 和随机的 `PtcgDAP-macOS-acceptance-*` 用户目录。正式包排除测试脚本；Python 仅用于开发构建和验收，玩家 App 不需要 Python。

测试通过实际主菜单、策略中心、对战准备和 BattleScene 的控件信号操作界面，使用真实 HTTPS、严格安装器与正式作者策略 owner。为自动完成对局，仅诊断代码为玩家席提供内置规则对手并缩短动作停顿、关闭特效。截图由实际渲染 viewport 产生。

离线测试使用 `/usr/bin/sandbox-exec` 对子进程执行 `(deny network*)`，并先证明 socket 调用返回 `EPERM`；不会修改系统网络配置。测试先在线安装，退出后重启同一诊断 App，再从“已下载”开战。在线验收需要该公共 release 仍可发现；服务移除该版本时会明确失败。

## 本机产物

| 项目 | 值 |
| --- | --- |
| 已安装 App | `/Users/bera/Applications/PtcgDeckAgent.app` |
| 交付 ZIP | `/Users/bera/Downloads/PtcgDeckAgent-macOS-0.6.0-rules-20260919.zip` |
| ZIP SHA-256 | `489b32beca06e450db1fda247c6d59a11480c194324860079bdcff5eef99bb87` |
| ZIP 字节数 | 255784063 |
| Godot | `4.6.1.stable.official.14d19694e` |
| Bundle | 0.6.0 / build 60；x86_64 + arm64 |
| 代码签名 | built-in ad-hoc；`codesign --verify --deep --strict` 通过 |
| 公证 / Gatekeeper | 未公证；`spctl --assess` 返回 rejected，不能宣称可无提示分发 |
| 正式资源包 | 5237 个文件；无测试、开发 artifacts 或可选模型扩展；1067 个游戏运行脚本与诊断包逐字节相同 |

依赖取自官方 Godot 4.6.1 GitHub release：编辑器 ZIP SHA-256 `f43613ad72ab1cc9ef14383545f4de344844451a5c9c5f4ea4a923f1f34f91e4`；模板 TPZ SHA-256 `e6d372afd4fdfaae9571eb5e3568afcd96ce6db9a569244034154faf0ac69875`。实际下载文件保存在 `.tmp/godot-4.6.1/`，可重新校验。

已使用严格 Catalog 安装入口，把在线验收下载的 e719 `dev.e719.marnies-gift-box-v2` / `0.4.0` 安装到正常玩家目录 `~/Library/Application Support/Godot/app_userdata/PtcgDeckAgent`。此准备步骤通过编辑器运行同一生产安装代码，返回成功；没有手工伪造安装记录。随后启动的是上表中的正式 App。可从 **AI 策略中心 → 已下载 → 玛俐的礼盒 V2 优化版 → 对战** 开始游戏。

策略包 SHA-256：`9ABE532AD39FA6C2A04385382A7EB3826642497E7391A1BB123FC40CB1808A4E`。

## 验收证据与边界

本机证据根目录：`/Users/bera/ai/code/ptcgdeckagent/.tmp/macos-regression-20260919/`。

| 验收 | 结果与证据 |
| --- | --- |
| 干净导入、规则版导出 | `release/import.log`、`release/export.log`；无引擎错误 |
| 源码/签名/资源检查 | `release/build.json`、`source-manifest.json`、`codesign.log`、`pack-inspection.json` |
| 正式包启动与本机安装 | `release/player-strategy-install.json`；已安装 App 的实际进程启动成功 |
| 在线 UI 全对局 | `visible-acceptance/online/report.json`：16 回合、正常奖赏胜利、58 次规则调用全部成功、36 次引擎提交；重复点击仅一次下载 |
| 禁网重启 UI 全对局 | `visible-acceptance/offline/report.json`：15 回合、正常奖赏胜利、63 次规则调用全部成功、43 次引擎提交 |
| 引擎健康 | 上述两个实际导出进程退出 0；脚本错误、策略错误、无效动作、同窗口 fallback、引擎拒绝均为 0；最终轮无退出警告 |
| UI 图片 | 两个验收目录内的 PNG：菜单、策略中心、下载/本地列表、准备、对局、终局 |
| Python 定向测试 | `python-targeted-final.log`：11/11，包括导出隔离、换行兼容、真实下载和本地卡组拒绝路径 |
| Godot 定向断言 | `test-results.json`：198/198；下文列出套件及附带问题 |

Godot 套件断言：export presets 24、平台能力 7、作者对战准备 13、策略中心 22、桌面流程 4、导入生命周期 8、响应式布局 4、排行榜 6、平台客户端 8、生产 HTTPS 1、对战 AI 版本 45、对战布局 42、输入兼容 10、新卡牌来源兼容 4。

最终 `visible-acceptance` 验收还通过实际主菜单按钮进入策略中心，并将下载/开战控件滚动到可见区域，检查控件未被父容器裁剪后才操作。较早的 `ui-online-v3`、`ui-offline`、`final-acceptance` 记录保留作排查历史，不替代最新结果。

保留而未掩盖的测试问题：

- 原有 `test_battle_setup_ai_versions.gd` 45 个断言通过，但退出时报告未释放 Canvas/CanvasItem/资源；`test_battle_setup_layout.gd` 42 个断言通过，退出时有 ObjectDB 警告。因此 198 项是断言通过数，不代表所有原有测试进程日志都干净。实际完整 UI 对局进程无这些警告。
- 扩展运行旧 `test_author_strategy_match_host.py` 时，官方 CardIdCatalog 来源锁在当前 LF 工作区报告 `source_hash_mismatch`（6 条 error，含子测试）。该路径不使用本次修改的本地卡组 gate；没有修改官方来源锁来放行。日志为 `python-host-regression.log`，不能宣称全仓库测试通过。
- 本次原生实机只测 Apple Silicon / macOS 15.7.2；Intel 仅验证二进制 slice 存在，未做 Intel 实机运行。旧版 macOS 未测。
- 已完成有渲染窗口的 UI 自动回归，但控件由测试信号驱动。Computer Use 两次被 macOS 辅助功能/屏幕录制权限阻塞，尚无真实鼠标、键盘、拖拽手工验收；报告明确标记 `physical_mouse_input=false`。
- 当前包是本地 ad-hoc 规则版，模型策略仍明确不可用。签名完整性通过与 Apple 公证/下载后 Gatekeeper 放行是不同检查，参见 [Godot macOS 导出说明](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_macos.html)。

## 回滚

只回退本任务的两个本地卡组 gate 修改及新增导出/验收工具、测试夹具；不要对整个工作区 hard reset。保留原有 `assets/ui/title1.png.import`、`scenes/.DS_Store`。构建全部使用新的 `.tmp` 目录；正式安装也未替换已有同名 App。需要移除本次安装时，只处理上述明确列出的 App、ZIP 和该策略，不删除整个玩家数据目录。
