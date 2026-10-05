# 全量回归与版本验收（2026-10-05）

本轮在 Windows / RTX 4090 / Godot 4.6.1 上进行。全量功能回归及追加的 Android 模拟器功能验收已通过，严格浏览器 3D 仍有失败。最初因此保留原生 0.6.3 / build 63；随后用户明确改为自行手工验证，并授权先升至 0.6.5、按现有模板导出本地各平台包。当前原生版本为 0.6.5 / build 65，Web 按用户补充要求为 0.6.5 / build 650，卡牌内容更新保持关闭。该授权没有改变下列测试结果，不作全平台发布通过声明；没有提交、推送、上传或发布。

## 测试执行结果

| 类型 | 结果 | 证据 |
| --- | --- | --- |
| 自动发现的 Godot 全量套件 | 747/747 套件、7875/7875 用例通过，0 失败、0 跳过 | `.tmp/full-regression-20261004/merged-current.json` |
| Python 全量测试 | 1104 项及 1703 个子测试通过 | `python-verified-run.log`、`python-verified-results.xml` |
| 最终卡牌索引改动的 Python 回归 | 33 项及 23 个子测试通过 | `catalog-python-final.log` |
| 浏览器功能矩阵 | 96 个组合：52 通过、44 明确不适用，0 失败、0 前置条件跳过 | `web-ui-merged-final.json`，保留原始两轮报告 |
| 严格浏览器 3D 矩阵 | 12 项全部执行：Chromium 桌面/手机的 4 项通过，WebKit 的 8 项失败，0 跳过 | `web-arena-isolated-complete/summary.json` |
| 相同平板尺寸的 Chromium 对照 | 2/2 通过，包含真实输入、旋转刷新及 2D/3D 性能对比 | `web-arena-tablet-control/summary.json` |
| 卡组中心浏览器界面 | 桌面、竖屏、横屏 3/3 通过 | `web-deck-center/summary.json` |
| 原生 3D 独立渲染探针 | 19/19 通过 | C 盘证据目录 `arena-probes/run-20261005-004327/report.json` |
| 原生 3D 实际输入界面 | 11/11 通过 | `arena-ui/run-20261005-004858-328500/report.json` |
| 修复后原生 3D 完整对局 | 通过；实际开局、选择、结束回合和 AI，48 回合正常胜负结束，耗时 165.03 秒 | `layout-full-match-bounded/` |
| 原生 portable 3D 性能 | 12 次实际渲染采样、横竖屏各 3 组 2D/3D 对比全部通过 | C 盘证据目录 `arena-performance/summary.json` |
| Windows 安装器与更新导出实验 | 6/6、2/2 通过 | `windows-installer.log`、`windows-update-export.log` |
| 修复后 Windows release 导出 | 构建成功；首页/更新入口健康检查通过，四尺寸 3D 输入验收通过 | `windows-layout-export.private.log`、`windows-layout-health.log`、`windows-layout-probe/` |
| Android release 包静态验收 | 更新器插件、portable 3D 资源、ARM64 符号和 16 KiB 对齐均通过 | `android-updater-inventory.json`、`android-portable-assets.json`、`android-native-inventory.log` |
| Android 模拟器追加运行验收 | 横竖屏触摸、实战、反馈、模型显示共 8/8 组通过；横屏反馈采用独立冷启动实例的结果，两次旧实例超时保留 | `android-emulator-merged-final.json`、`android-layout-acceptance/`、`android-layout-feedback-fresh/` |
| 横屏台词布局修复的完整相关套件 | 4/4 套件、37/37 用例通过，保留新增用例修复前的失败 | `android-speech-before/`、`android-speech-after/report.json` |
| 竖屏布局修复的完整相关套件 | 16/16 套件、215/215 用例通过，包含旧 2D 竖屏布局回归；新增用例先失败后通过 | `android-layout-before/`、`android-layout-full/report.json` |
| 修复后 Chromium 实际渲染与输入 | 桌面、触摸 2/2 通过，均检查旋转后真实绘制与操作；新 Web 包资源完整性与大小检查通过 | `web-layout-chromium-actual/summary.json`、`web-layout-assets.json`、`web-layout-budget.json` |
| Node 服务适配器与 PowerShell 运行器 | Node 8/8；PowerShell harness 通过 | `web-unit-live.log`、`powershell-benchmark-runner.log` |

未加前缀的证据文件均位于 `.tmp/full-regression-20261004/`。大型本地导出和渲染证据位于 `C:/Users/24726/.codex/visualizations/2026/10/04/01a1076e-bba8-7761-9157-f854e4a656d4/ptcgdap-full-regression-20261005/`。这些本机产物没有作为公开仓库内容提交。

全量套件由真实发现列表确定，没有用固定数量或少量筛选用例冒充全量。`merge-inputs.json` 列出整套重跑的覆盖顺序，合并报告保留失败尝试；单用例诊断不覆盖整套结果。工作区中途的 3 个场景文件变更已补跑 110 个完整相关套件及配置了服务前置条件的 HTTP 回归。

## 本轮修复

1. 卡牌内容更新保持关闭：首页不创建按钮和更新弹窗，初始化、自动检查、手动检查、下载和底层请求均受开关约束。关闭状态不挂载、激活或改写以前下载的内容。普通应用更新保留。详见 [内容更新暂停记录](CONTENT-UPDATE-HOLD-2026-10-04.md)。
2. 有签名内容的卡图只按完整 SHA-256 和大小复用现有 bundled/旧缓存图片，原子写入按摘要寻址的图片缓存；拒绝签名不匹配的图片。修复更新切换图片路径后，有图的本地资源未被复用的问题。
3. 卡牌搜索投影漏掉 `evolves_from`。索引 schema 升至 3，旧 schema 回退到完整数据，所有 1107 张卡的进化字段与完整印刷记录独立核对。55 个原始系列分片的字节不变；未改卡牌规则来适应索引。
4. 公开伤害能力注册表补齐 96 张实际已注册卡牌。保持已有条目，不通过把真实注册卡作为“不支持”负例来阻止修复。
5. A3 测试桥正常结束时关闭输入、等待引擎退出，超时才清理自己的进程树。修复只结束控制台包装进程而遗留游戏引擎的现象。新增生命周期测试验证优雅退出、超时和断开清理，完整 Python 回归通过。
6. Android 2400×1080 横屏下，台词气泡沿用竖屏头像最小高度，导致其覆盖战斗卡。横屏改用与同排操作按钮相配的头像尺寸，保持文字字号；空间不足时隐藏气泡而不遮挡战斗卡。新增实际测得的布局用例先失败后通过，4 个完整相关套件全部通过；模拟器实测另行记录，不用逻辑测试替代。
7. Android 1080×2400 竖屏“结束回合”触摸被布局变化取消：旧 2D 竖屏布局直接把 3D 继承容器宽度写为 1041.12，随后异步容器排序恢复为 1080，导致按下和松开时的输入指纹不一致。确认局面、回合、选择代数均未变化后，在 `BattlePortraitLayoutView.enforce_field_axis_width` 阻止这项 2D 写入作用于 3D 场景，继续由 `ArenaLayout` 管理 3D 场地。保留触摸时效、旋转、模态框与误触取消检查，没有靠延长测试等待或删除指纹中的尺寸掩盖问题。新增确定性回归复现同一宽度后通过，16 个完整相关套件通过，修复后的 Android 验证包实测回合从 8 切到 9、行动方从 0 切到 1。

A3 相关生成证据仍是开发状态，`a3_promoted=false`；本轮不提升 CABT 引擎等价、策略强度或外部认证等级，不修改外部 oracle。

## 测试本身的同步

更新了已经与当前产品行为不一致的夹具：动态未来版本、真实双份无色能量、工具结算阶段、授权攻击来源、可滚动内容边界、实际内置卡牌集合、五项紧凑状态栏等。保留数量、身份、选择窗口、真实点击、取消和视觉刷新断言。没有通过过滤引擎错误、放宽性能阈值或跳过失败用例把报告改绿。

浏览器性能运行器改为每种模式使用独立浏览器上下文，并在下一种模式开始前关闭上一种模式，与原生运行器的独立用户数据原则一致。同一页面重复启动时记录到约 76 秒的额外等待，隔离后同一 WebKit 的 3D 启动约 4 秒。固定 20 秒测量窗口、两种场景和共享阈值均不变。渲染错误仍导致失败，但会继续保存独立的帧耗时比较结果，避免一个错误掩盖另一类测试结果。

追加完整对局时发现运行器的通用 100 秒上限会早于完整对局脚本自身的 180 秒截止。首轮在 100 秒被外层终止，记录保留于 `layout-full-match/`。加入公开回合/阶段/动画状态的进度日志，并让完整对局的默认外层上限为 200 秒（其他探针仍为 100 秒，显式参数优先），不改脚本自身的 180 秒截止或终局断言。实测重跑持续推进到 48 回合，以 165.03 秒正常结束、0 引擎错误；不能再把这种长对局误报为 100 秒卡死。

Android 横屏反馈在既有模拟器中两次超时：一次与 Windows 渲染对局同时运行，另一次单独运行仍超时，因此没有直接归咎于并发。两次均在推进规则操作、生成新截图，无脚本错误，但系统画面频繁出现数秒延迟。使用同一 APK、相同 Android 16 x86_64 系统镜像、1080×2400/420 dpi、2 GiB 内存与 4 核配置的独立冷启动实例，再以相同横屏尺寸、断言和时限完成检查。首次画面时间从旧实例 44 秒降到 3.136 秒，横屏反馈完整通过。合并结果保留两次超时及冷启动通过记录；旧实例长期变慢的具体机理尚未查清，不把这次功能验收当作多小时稳定性或真机性能通过。

浏览器 3D 额外检查发现 Windows WebKit 的 `glBlitFramebuffer` 错误。尝试 Emscripten 自带的另一条展示路径后，虽然错误日志消失，但实际截图刷新未通过，因此已撤回该尝试。产品 Web shell 与尝试前一致。原失败、诊断日志和截图均保留；尚不能将该项列为通过。

进一步在不含 Godot 或游戏代码的独立 WebGL2 页面复现同一错误：WebKit build 2311 和 2370 的帧缓冲复制都返回 `INVALID_OPERATION (1282)`，Chromium 的相同 9 次复制全部无错误。证据为 `webgl-engine-independent.cjs` 和 `webgl-engine-independent.json`。新内核只下载到本机诊断目录，未改项目依赖。此证据定位了本机渲染环境的问题，但不能替代 Safari/iOS 真机对产品的验收。上游还有相关的 [Windows WebKit 画布截图问题](https://github.com/microsoft/playwright/issues/42885)，该上游问题与本轮最小复现分开记录，不视作所有渲染问题都已解决。

北京时间 03:04 再次核对：相关[上游测试修复 PR](https://github.com/microsoft/playwright/pull/43085) 仍为草稿，声明需要 WebKit build 2371；该 Windows 构建的官方下载地址仍返回 HTTP 404（`webkit-2371-availability.json`）。未通过更改浏览器报错过滤或放宽像素断言规避此阻塞。

严格浏览器矩阵中的 6 个独立帧耗时比较有 5 个达标。平板 WebKit 持续攻击场景的平均帧耗时为 43.07 ms，2D 基线为 33.44 ms，超过 36.78 ms 的门槛；其 p95、p99、最大帧耗时及超过 50 ms 的比例达标。这项平均值失败保留，不能只因同平台存在渲染错误就宣称游戏性能无问题。其他 WebKit 配置即使帧耗时达标，也因渲染错误而整体失败。

额外使用相同平板视口、像素比例、触摸参数和用户代理，改用 Chromium 渲染内核作对照：实际绘制、交互和旋转全部通过；持续攻击场景 3D 平均 16.74 ms、2D 平均 16.90 ms，所有共享性能门均通过。两边实际画布均为 1536×2048。这说明该尺寸没有在本机 Chromium 重现性能失败，不能据此替代 Safari 真机结论，也不覆盖原来的 WebKit 失败记录。

机器可读的全量汇总为 `.tmp/full-regression-20261004/full-validation.json`，保留 `status=not_passed`、`version_bump_permitted=false`，表示自动验收没有授予升版资格。后续用户授权的手工验证包单独记录于 `.tmp/manual-release-0.6.5-20261005/`，不修改原失败报告。相对先前功能回归基线，追加的产品变更是两个对手台词布局文件及一个竖屏布局文件，由 `android-speech-after/` 和 `android-layout-full/` 的完整相关套件覆盖，其摘要记录于 `source-android-layout.json`。Windows release、Android 独立验证包和 Web E2E 包已用修复后源码重建；各自运行结果分别记录。原先 Android ARM64 release 静态验收与完整浏览器性能矩阵对应修复前源码，不冒充新候选包的最终验收。测试专用包均在本机证据目录，未放入待发布下载目录。

## 覆盖边界

测试类型包含规则单元测试、接口/数据契约、集成与 HTTP、升级/回退、资源完整性、真实渲染与鼠标/触摸输入、横竖屏、完整对局和相对性能。类型齐全不等于所有场景和设备已覆盖，也不是代码分支覆盖率 100% 的声明。

仍需要区分以下验收：

- Android APK 静态验收不能替代 Android 真机安装、后台恢复、触摸、长局、温升和功耗。
- Windows 上的 WebKit/iPhone/iPad 视口模拟不能替代 macOS Safari 和 iOS 真机。
- macOS/iOS/Linux 原生程序尚未在相应系统运行。
- 本轮完整对局不是多小时稳定性或所有牌组组合的胜率基准。
- 快速调整窗口的原生探针仍记录手牌投影修复警告；当前交互、滚动范围与结束回合断言通过。没有把警告从日志中移除，不将其作为已彻底定位并消除的问题。
- 本轮没有修改或发布生产静态站点，也没有把测试专用 Web 导出作为产品包。

## 待发布导出约束

用户于 2026-10-05 指定：全部问题处理完、验收通过后，使用现有导出模板，将候选产物放到 `D:/ai/code/ptcgdojopage/downloads` 等待发布，不自行发布。这项授权只包含本地导出；不包含提交、推送、上传、部署或切换线上更新入口。

已核对现有 Windows、macOS 和 Android 模板的输出文件分别为 `PtcgDeckAgent-win.zip`、`ptcgdeckagent-mac.zip`、`ptcgdeckagent-android.apk`，目录均为上述待发布目录。通过验收后再将原生版本改为 0.6.5 / build 65，并检查最终导出包的版本、资源和启动行为。Web 使用独立版本配置，测试专用 Web UI E2E 包不得作为产品包。Web 导出后的本地更新元数据也不代表已获发布授权。

后续用户明确要求“我手工试试吧……先把版本号改成 0.6.5，然后按要求导出最新的各平台包”，并确认 Web 也改为 0.6.5。因此本轮改为交付手工验证候选包，使用现有 Windows、Android、macOS、Web 正式导出模板；不是 Web UI E2E 或 Android performance 专用包。原生构建号 65，Web 构建号 650。旧下载包备份于本机 `.tmp/manual-release-0.6.5-20261005/previous/`。iOS 模板未配置应用标识、签名和输出路径，本机未生成可安装的 iOS 包；Linux Server 为内部比赛服务端模板，不作为玩家包。

本次版本、更新检查与卡牌更新关闭的 4 个完整套件共 53 项通过。四平台包内版本、卡牌内容关闭开关、主场景、关键修复脚本一致性、资源完整性均通过；Android 正式签名与原目录旧包一致，原生库与 16 KiB 对齐通过；macOS 包含 x86_64/arm64，尚无 macOS 实机启动验收。Web 资源大小和文件摘要通过，原 WebKit 失败仍待手工验证。具体包清单与最终校验见本机交付记录及 `docs/release-notes-0.6.5.md`。本地导出不授权任何上传、部署或切换线上入口。

## 回退与重现

卡牌内容开关必须继续保持关闭。回退本轮其他改动不应重新启用该功能。索引 schema 3 的生成、读取与产物应成组回退；不得仅降低 schema 门槛继续使用缺失进化字段的旧投影。A3 进程清理修复独立于游戏规则。

重现全量测试使用 `scripts/tools/run_test_matrix.py` 的发现目录和 `merge-inputs.json` 中的完整套件报告；Python 的冻结 oracle 和独立用户目录配置记录在该次原始运行日志。浏览器使用 `tests/web_e2e/playwright.config.cjs` 和 `arena.config.cjs`，性能门使用 `tools/arena3d/run_render_performance.py` 与共享比较器。诊断导出必须显式指定本地临时输出；本轮手工验证候选包依据上述用户新授权使用指定的待发布目录，并继续保留未通过验收的说明。
