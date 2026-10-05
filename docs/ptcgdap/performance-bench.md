# 游戏响应性能基线

目标：操作首反馈小于 1 秒（工程预算 100 ms），可立即完成的操作小于 1 秒；更长的本地准备应持续显示真实阶段、基于事件耗时基线的进度条及失败后的返回入口。平滑度另行检查，不能把“显示过加载提示”等同于不卡顿。

首份设备基线与优化对照：[2026-09-25 实测报告](../evidence/ptcgdap/performance_20260925.md)。当前仍有未达标项，报告同时保留冷入口、热运行和最坏样本。

## 测量与门槛

`tests/performance/PerformanceBenchRunner.gd` 调用实际产品的目录、安装器、策略包校验、牌组物化、决策执行器、场景及对局代码。每条样本包含成功/失败、耗时、进程内首次/热运行标记、逐帧间隔。导航及开战反馈时间来自加载提示的 `frame_post_draw`，不是设置按钮文案的时间。

| 组 | 覆盖 |
|---|---|
| components | 卡牌搜索、牌组列表、策略目录刷新、规则/模型包加载器初始化、完整校验、牌组映射、句柄完整性、物化、引擎及执行器构建 |
| navigation | 主菜单→对战设置、卡组管理、策略广场、设置、残局训练；AI 选择与搜索 |
| battle | 固定卡组的经典/下载规则策略开战、完整棋盘刷新、开局画面帧间隔；真实安装器安装固定策略 |
| author_start | 直接进入下载策略对战，不预先运行经典战斗或组件测试，单独验证首次战斗入口 |
| matches | 固定种子的完整规则/模型对局，逐次策略决策/原生模型推理耗时，以及窗口失效、非法输出、引擎拒绝和回退审计 |

`all` 包含前三组。完整对局单独运行，以免把多局策略计算混入导航基线。整局耗时和一秒采样窗口不适用“操作完成 <1 秒”，逐次决策适用。组件的同步调用用于定位 CPU 成本，不能代替实际异步开战的帧指标。

- 保留每个样本，分别汇总 P50/P95/P99/最大值；首次样本、最慢样本不剔除。小样本的 P95 常等于最大值，不是大规模用户分布。
- 首反馈 <1000 ms；普通操作完成 <1000 ms；最大帧间隔 ≤50 ms 是卡顿告警，≥1000 ms 是严重无响应。60 FPS 的理想帧预算为 16.7 ms。
- 按实际 OS/版本、架构、CPU/GPU/设备、Godot 版本、渲染器、debug/release、编辑器/导出程序、视口区分。桌面缩小窗口不能算 Android；模拟器不能算小米 14 Pro。
- 冷进程使用全新测试数据目录；`warm_in_process` 只表示进程内后续迭代，不能声称已清除系统文件缓存。多场景可能提前暖好资源，冷入口应额外单跑 `navigation` 和 `battle`。
- 运行错误、缺少预期用例、超时、NaN、非正常退出或缺少完成标记，均使报告无效。超时会清理本次测试进程树，不终止用户编辑器。
- 不测真实网络、第三方模型服务延迟、电池温度、热降频、后台压力、触屏到显示器的物理延迟。无画面运行不能证明帧率。当前一秒开局帧窗口不能代表长局动画流畅度。

## Windows / 本地引擎

在仓库根目录运行。命令自动串行，不使用 Python 进程池，也不修改玩家存档：

```powershell
python scripts/tools/run_performance_bench.py --group all --runs 3 --repeat 3 --output .godot_test_user/performance/windows
python scripts/tools/run_performance_bench.py --group battle --runs 3 --repeat 3 --output .godot_test_user/performance/windows-cold-battle
python scripts/tools/run_performance_bench.py --group author_start --runs 3 --repeat 3 --output .godot_test_user/performance/windows-author-entry
python scripts/tools/run_performance_bench.py --group matches --runs 1 --repeat 3 --headless --output .godot_test_user/performance/logic-matches
```

报告位于指定目录的 `report.md` / `report.json`，逐次原始数据和日志在 `run-*/`。输出目录必须是新目录，避免覆盖证据。默认仅记录超预算项；回归流水线添加 `--enforce-budgets` 才会对超预算返回非零状态。错误用例始终返回非零。

## 独立诊断导出与 Android

```powershell
.\scripts\tools\build_performance_player.ps1 -OutputRoot .godot_test_user/performance/device-exports -AndroidArchitecture x86_64
```

该工具冻结当前工作区，单独导出 Windows 和 Android release 程序，保留源码及产物散列。实际项目设置不变。Android 使用独立包名 `com.example.ptcgdeckagent.performance`，不会覆盖正式游戏。x86_64 仅供本机模拟器；实体 Android 用 `-AndroidArchitecture arm64`。仅本地构建，不发布。

Windows 诊断程序启动后自动执行。Android 先由应用创建自己的目录，再等待至多 60 秒接收 `request.json`，内容例如 `{"group":"matches","repeat":3}`。输出固定在 `/sdcard/Android/data/com.example.ptcgdeckagent.performance/files/performance/result.json`。不要提前用 ADB 创建此目录，否则目录可能归 shell 所有，应用无法写报告。

用 `run_android_performance.ps1` 安装到明确指定的设备并收集报告。每次使用新输出目录；只清理该诊断包数据，正式游戏不受影响。Windows 导出程序使用 `run_performance_bench.py --exported --godot <诊断exe> --group all ...`；编辑器程序与 release 程序的结果分别保留。

```powershell
.\scripts\tools\run_android_performance.ps1 -Device emulator-5556 -Apk .godot_test_user/performance/device-exports/PtcgDAP-performance.apk -OutputRoot .godot_test_user/performance/android -Runs 3 -Repeat 2
```

导入其他设备报告时必须同时提供同名 `.log` 的原始 Godot 日志：

```powershell
python scripts/tools/run_performance_bench.py --import-reports path/to/result.json --group all --repeat 3 --output .godot_test_user/performance/imported-device
python scripts/tools/compare_performance_bench.py before/report.json after/report.json --output comparison.json
```

对比只接受相同平台/构建方式/缓存分组/策略包及卡组身份。不同设备或不同策略的数值不能用来计算优化比例。

导入时 `--group`、`--repeat` 必须与计划执行的请求一致，不能从已返回的样本推断应有覆盖，否则完全丢失的最后一轮会被漏报。Android 脚本自动传递这两个参数，并检查 APK 包名、进程退出和 Godot 日志。

## 已实施的优化与边界

1. JSON 规范化在**单次调用内**复用短字符串编码、字节长度和排序键。仍逐节点检查类型、深度、节点数、总输出长度；保留 Unicode、转义等价重复键和精确数字规则。不缓存观察或旧选择窗口。
2. 策略句柄直接规范化内存中的基本类型树，去掉先生成 JSON 再重新解析的往返。每次仍重新计算完整性，修改载荷仍拒绝。
3. V18 CPG 查找按策略中的卡组 ID 定位，避免为普通规则策略构建全部模型配置；动态覆盖文件仍读取，完整 ID 仍核对。
4. 设置页启动只传不可变策略引用，对战页负责唯一一次完整校验与生成牌组。兼容的同步校验入口仍用于非启动调用者。
5. 包捕获、严格 JSON 解析和签名计算使用一个独立后台任务。后台仅持有文件字节和私有加载器；不访问场景、CardDatabase、策略计划缓存或对局对象。返回后重新检查当前目录成员、路径、权限、包身份，再在主线程完成原有 schema、策略编译和卡组校验。
6. 跨场景加载提示先绘制，再准备数据。场景资源持续后台加载；原来的 100 ms 等待后转同步加载已改为可见等待及超时恢复。执行器绑定与首个选择窗口分帧进行。

所有策略与模型仍在玩家设备运行。上述改变不修改 AI 决策内容、签名信任来源或对局动作授权。

## 验证与回滚

2026-09-27：跨场景提示已用进度条替换秒数。`SceneLoadingBaseline.gd` 读取
`data/performance/scene_loading_baselines.json` 中的事件 P50，按页面、经典/作者开战、
首次/再次进入、Windows 编辑器/发布版/Android 模拟器参考分别估算。Windows 编辑器导航
使用本次 3 个独立进程 × 2 次的直接入口采样；发布版与 Android 继续使用 9 月 25 日
的独立导航/作者入口数据，优先于会预热资源的 `all` 组。Android 模拟器仅作为显示估算，
不等于实体设备验收。macOS/Web、未测量页面、双人操控及残局开战使用循环滚动条。

到达基线时进度约 90%，超时逐渐趋近 95%；只有场景真实准备完成才填满并移除遮罩。
阶段文字变化保留时钟，切换目标或失败重试重置；只有成功完成的事件才能选择重复进入的基线。
不显示精确百分比，不用进度值解除输入保护。生成数据包含来源摘要的规范化 SHA，避免换行格式影响复现：

```powershell
python scripts/tools/build_scene_loading_baselines.py --check
python -m unittest tests.test_scene_loading_baselines tests.test_performance_bench_report
```

导航原始数据位于 `.godot_test_user/loading-progress/navigation-baseline/`，可复核摘要见
`evidence/ptcgdap/scene_loading_navigation_20260927.json`。这次改变只优化等待反馈；
bench 仍报告 `needs_optimization`，不宣称缩短真实加载时间或提升 CABT 对齐等级。
回滚时只反向应用本次 overlay、GameManager 事件映射和 BattleSetup 事件选择的改动，
并移除新增的基线读取器/生成数据；保留此前后台加载和其他工作区修改。

本次验证：`SceneLoadingOverlay` 7/7、`GameManager` 37/37、`BattleSetupAIVersions`
47/47、`AsyncStrategyPreparation` 2/2；Python 基线生成/报告检查 11/11。
最终回归报告在 `.godot_test_user/loading-progress/final-regression/report.json`。
真实渲染导航共 30 条事件样本全部完成，首反馈最大 14.92 ms；作者策略首次/再次开战
各一次全部完成，首反馈最大 69.13 ms。开战完成和帧停顿仍存在超预算项，未作为
性能晋级通过。1280×720 与 390×844 的真实控件渲染已检查进度条与失败返回画面，
截图保留在同一根目录的 `preview-*.png` / `failure-*.png`；窄视口不算手机验收。

自动发现的针对性套件包括 `CabtTreeHash`、`CanonicalizationPerformance`、`HandleHashPerformance`、`StrategyLookupPerformance`、`AsyncStrategyPreparation`、`SceneLoadingOverlay`、`PerformanceStatistics`，并结合现有 `GameManager`、`AuthorStrategyBattleSetup`、`DeckStrategyRegistryExpansion`、`AuthorLivePerformanceContract` 和完整规则/模型对局。

```powershell
python -m unittest tests.test_performance_bench_report
python scripts/tools/run_test_matrix.py --group all --suite CabtTreeHash,CanonicalizationPerformance,HandleHashPerformance,StrategyLookupPerformance,AsyncStrategyPreparation,SceneLoadingOverlay,PerformanceStatistics
```

回滚应按优化所属文件反向应用本次差异，不覆盖本任务前已有的工作区改动。保留诊断入口与证据可独立于运行时优化回滚。签名/JSON 后台准备和场景提示共同回滚，避免提示生命周期与同步/异步启动不一致。
