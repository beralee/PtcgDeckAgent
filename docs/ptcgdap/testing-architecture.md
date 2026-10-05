# 游戏测试架构与回归指南

测试入口由 `tests/TestSuiteCatalog.gd` 统一发现，`SharedSuiteRunner.gd`
统一执行。文件位置可以暂时保持原样，分类不再依赖旧的双组运行器。
新 `test_*.gd` 中的测试方法会自动进入全量回归；套件名和路径必须唯一。

## 三类测试

| 类别 | 负责的证据 | 示例 |
| --- | --- | --- |
| `ui` | 场景生命周期、布局、输入、弹窗、牌组选择、显示状态 | BattleSetupAIVersions、DeckManager、StrategyHubInputCompatibility |
| `functional` | 卡效、规则、数据、存档、导入、更新与资源完整性 | RuleValidator、BundledDeckCatalog、CardDatabaseSeed |
| `ai` | 合法选择、公开信息边界、策略行为、模型推理、包和执行器 | PublicObservationFirewall、PlatformModelInference、PlatformPlayerMatches |

每个套件只有一个主分类。目录规则、语义文件名和少量明确的 UI owner
映射在 catalog 中集中维护；明确的 UI 页面例外优先，其后 AI 所属目录优先于
通用文件名词语，避免将模型的 input 误认成界面输入。`ai_training` 是 `ai` 的兼容别名。
UI 展示 AI 版本的测试归 UI。牌组完整性门禁仍归功能，并独立扫描真实文件，
不以 AI 名单或固定数量替代完整性检查。

## 常用命令

```powershell
# 每次改动的快速门禁；profile 中的套件必须真实存在且分类正确。
python scripts/tools/run_test_matrix.py --tier smoke

# 三类完整回归（每个类别内部串行）。
.\scripts\tools\run_godot_tests.ps1 -Runner ui
.\scripts\tools\run_godot_tests.ps1 -Runner functional
.\scripts\tools\run_godot_tests.ps1 -Runner ai

# 单个套件或单个测试；原 FocusedSuiteRunner 命令继续可用。
.\scripts\tools\run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_deck_manager.gd --test-filter=search
python scripts/tools/run_test_matrix.py --suite BundledDeckCatalog,CardDatabaseSeed

# 指定引擎版本、AI 环境或布局/输入配置。
python scripts/tools/run_test_matrix.py --tier smoke --godot D:/ai/godot/Godot_v4.6.3-stable_win64_console.exe
python scripts/tools/run_test_matrix.py --ai-version v18.5
python scripts/tools/run_test_matrix.py --profile touch-layout

# 保留原始失败证据，在新目录复查。
python scripts/tools/run_test_matrix.py --rerun-failed <旧报告.json> --output <新目录>
python scripts/tools/run_test_matrix.py --resume <中断报告.json> --output <新目录>
# 按时间先后合并完整套件结果，保留每次尝试和原始日志；不接受单方法结果替换整套。
python scripts/tools/merge_test_reports.py --catalog <discovery/result.json> --output <最终报告.json> <全量报告.json> <修复复查报告.json>

# 运行器自身与测试质量门禁。
python -m unittest tests.test_test_matrix tests.test_test_quality_audit tests.test_runner_process_contract tests.test_web_test_report tests.test_merge_test_reports
python scripts/tools/audit_test_quality.py
```

`--resume` 仅用于相同代码、相同 Godot 可执行文件的中断续跑；修改 owner
之后需要重新跑受影响的套件。已完成记录保留原报告路径，不覆盖过去的失败。
续跑会重新校验原始用例、日志和筛选条件，重新计算数量；部分方法的结果不能
代替整个套件，摘要里的成功标记也不能覆盖原始失败。
合并工具按真实发现目录检查遗漏，只接受相同引擎的完整套件报告；去重后统计，
不会把多次重跑累加为覆盖量。未完成的矩阵在第一项长测试执行前也保存进度。
`--tier smoke` 是快速反馈集合，不能替代完整发布回归。
普通套件默认限时 180 秒；已确认耗时较长的回放语料和基准测试在 `test_profiles.json`
声明 600 秒预算，引用必须通过目录门禁。`--timeout` / `-TimeoutSeconds` 可显式覆盖，
报告记录实际预算；加长预算不会改变断言或失败规则。

## 失败、跳过和证据

以下情况不得通过：空选择、拼错的套件或分类、重复注册、脚本加载/运行错误、
带必填参数的测试、非字符串结果、没有匹配方法、超时或缺失 JSON 报告。
即使调用者忽略断言返回值，`TestBase` 也会记录失败，由运行器收集。

测试返回空字符串表示通过；失败返回原因。外部先决条件未满足必须返回
`SKIP: 具体原因`，不能返回空字符串；断言失败不能借 SKIP 变成跳过。
单套件报告分别记录 passed、failed、skipped 和每个测试的路径、耗时、原因。
命令行矩阵有跳过时返回 2 并标记 incomplete，有失败时返回 1。
直接 Godot 入口全部跳过也返回 2；混合通过/跳过仍由矩阵聚合为 incomplete。

只有退出码与结构化报告、用例身份和数量一致才能算通过。聚合报告原子替换，
中断或写盘失败不会把上一次完整结果截断成空文件。服务凭据不进入报告 filters。
自动加载脚本先于测试运行器启动，其错误由进程日志前缀补充检查，不能因某个
无关套件仍能运行就被忽略。

每个套件有独立进程和 user://，日志及 JSON 常驻；新建的临时用户数据在
进程终止后释放。显式提供的 `--user-data-root` 不会被清理。
`--keep-user-data` 可用于调试。开始前不足 2 GiB 可用磁盘空间会停止，
避免逐套件复制卡图库耗尽磁盘。超时/中断先停止本次创建的进程，再释放缓存。
训练、基准和 Python 进程池继续遵守 AGENTS.md 的内存与串行限制。

诊断源码快照、导出中间目录及历史重复卡图的保留/回收规则见
[测试与导出产物的磁盘生命周期](test-artifact-storage.md)。

## 多版本与多平台

AI 标签包含 legacy、v17、v17.5、v18、v18.5、author，标识测试实际针对的
环境/执行路径，不把注册或 UI 可见性当作策略强度证明。模型、作者策略和
经典规则的真实本机对局与公开轨迹验证保留各自门禁。

UI 的 desktop-layout、touch-layout、web-contract 标签是配置选择器。
`UiCompatibilityHarness` 使用真实场景和输入事件，覆盖 PC、窄屏手机、平板
等尺寸；尺寸模拟不等于对应操作系统或物理设备验收。

Web 使用 `run_web_ui_e2e.ps1` 导出真实包，再由 Chromium/WebKit 执行操作，
保存 JSON、截图和失败 trace。WebKit 的触屏模拟不等于真 iOS Safari。
浏览器报告由 `validate_web_test_report.py` 检查用例与汇总是否一致：缺少策略
样本等先决条件标为 incomplete；明确的 `not-applicable` 平台范围注解单列，
不计入通过数。空集合、全部不适用、旧报告、预期失败或重试后才通过不能报绿。
语义坐标点击会先等待 Godot 布局稳定，再发送一次真实点击，不靠重复点击掩盖问题。
Android 需要连接设备，Windows 原生窗口和 macOS 也各自需要真实运行环境；
没有设备时应明确记录未验证，不能拿 headless 布局测试代替。
Android 入口先检查设备，再进行构建或安装；缺少设备返回 2 并写入未验证报告。
平台总入口把每个 gate 的 JSON 和日志归入本次 ArtifactDirectory。

## 无效测试治理

质量扫描阻断空壳通过、重复方法和静默跳过先决条件。矩阵启动前自动执行
该门禁，并保存 `quality-audit.json`。源码检查列为 review，不会一律删除：
公开/私有边界、禁止的依赖和文案约束可以使用静态断言。
它们不能替代实际交互或执行验证。解析回归已改为加载并检查真实脚本，
不再通过搜索几个历史错误字符推断脚本可以运行。
卡牌目录审核必须提交新交互要求的来源/目标分配，并验证真实出牌结果。
编码审核检查损坏字符，允许合法多语言和卡牌稀有度符号；它不承担字体字符集限制。
公开回放布局使用仓库里的三帧合成样本，读写测试比较整个 artifact；真实整局
门禁现场捕获对局，并让只读播放器逐帧核对公开棋盘、公开卡牌和区域计数。
自动测试不依赖被忽略的本机历史录像，也不把合成样本称为真实整局证明。

独立 SceneTree 探针单独盘点，不混入 SharedSuiteRunner 的运行数量。
历史策略优化探针、真设备测试、在线服务 E2E 必须使用自己的先决条件和入口；
未运行的探针不计入覆盖。扫描器是治理辅助，不能证明所有测试都具有有效断言。

## 回滚边界

本次框架改动不更改策略授权或云服务。回滚时仅回退 catalog/runner/filter、
测试基类、测试工具和对应回归；保留本任务开始前已有的卡牌、牌组、导出和
游戏功能修改。原始报告保留在 `.godot_test_user/matrix`，不要把本机证据或
用户数据提交进公共仓库。
