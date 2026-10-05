# 主菜单启动加载优化（2026-10-05）

Godot 启动图之后，主菜单出现前的主要开销来自自动加载脚本的依赖编译。
原有 `call_deferred` 和目录缓存只能推迟实际扫描，不能阻止 `preload`、
全局类引用及类型声明在解析时加载整条依赖链。

## 原因与修改

- `CardDatabase → CardCatalogIndex / CardImplementationStatus` 与
  `CardEffectAliasResolver → EffectProcessor` 提前加载整套卡效实现。
  两个辅助类现在只在真正查询卡效时加载处理器；状态缓存及别名语义保持原样。
  实现检查的内部参数使用 `RefCounted`，避免 `BaseEffect` 类型重新带入依赖。
- 策略包 loader 的 `CompetitivePolicyV2` 预加载提前编译策略规划图。
  合同和缓存仍正常校验；实际检查 v2 策略时才加载原有编译器，所有接受/拒绝规则保留。
- `GameManager` 提前加载作者策略执行门、模型输入及比赛策略池。
  执行门在准备对战时加载；比赛策略池通过延迟 getter 加载，保留比赛设置页使用的
  `TournamentAuthorPoolScript` 接口。对战完整校验和后台场景预热流程保留。

## 测量

Windows、Godot 4.6.1，本机源码运行。同一份隔离源码快照、同一份已初始化用户目录，
交替运行修改前/后各三次，记录新进程内 `Time.get_ticks_msec()` 的中位数。
修改前使用任务开始时的四个文件备份，保留工作区原有修改，不使用 Git HEAD 代替基线。

| 阶段 | 修改前 | 修改后 | 缩短 |
| --- | ---: | ---: | ---: |
| 自动加载脚本准备完成 | 2568 ms | 817 ms | 68.2% |
| 主菜单节点准备完成 | 3295 ms | 1569 ms | 52.4% |

以上是 headless 基准，不能等同于显卡初始化或 Android APK 启动时间。
另用 Windows OpenGL 实际渲染主菜单，菜单准备 2055 ms、截图帧 2517 ms，
截图检查正常，目录扫描完成，没有提前缓存上述四个重型模块。
首次安装仍需要初始化内置用户数据；本次没有改动复制、迁移、签名或策略授权规则。

本机原始记录位于 `.godot_test_user/startup_20261005/`：
`comparison.json`、`compare_*_*.log`、`rendered.log`、`menu.png`。
这些是本机诊断文件，不作为公共发行证据提交。

## 验证

- 新增独立进程探针 `tests/probe_startup_loading.gd`：修改前在自动加载和主菜单两处
  均发现四个重型模块（RED），修改后均不再提前加载（GREEN）。
- `python -m unittest tests.test_startup_loading tests.test_godot_preload_paths` 通过。
  新启动测试覆盖首次安装、已有安装，以及首次卡效查询、别名识别、有效 v2 策略接受和
  未知字段拒绝。共享测试运行器会提前加载其他套件，不能替代此独立进程检查。
- 六个相关 Godot 套件最终通过 78/78：`CardEffectAliasResolver`、
  `CardImplementationStatus`、`GameManager`、`MainMenuStatusHeader`、
  `AuthorStrategyPackageCatalog`、`TournamentAuthorRuntime`。
  比赛套件包含四局真实引擎对战及存档恢复。初次回归暴露的比赛设置公开属性兼容问题
  已修复，并完整重跑受影响的 `GameManager` 与比赛套件（43/43）。
- 原始回归及重跑报告分别保留在 `regression_reports/`、`regression_retry_reports/`；
  同套件以最后一次完整运行作为结果，不重复累计测试数。
- 启动进程退出仍有既存 `ObjectDB instances leaked` 警告；本次不声明资源释放门通过。
  未重新导出客户端、未做 Android 真机启动测量，也不新增 CABT/策略强度对齐声明。

可用独立探针重复测量（为 APPDATA 指定隔离目录）：

```powershell
& $env:GODOT_EXE --headless --path . --script res://tests/probe_startup_loading.gd
```

## 回滚

仅撤销 `CardEffectAliasResolver.gd`、`CardImplementationStatus.gd`、
`AuthorStrategyPackageLoader.gd`、`GameManager.gd` 中本次的延迟加载修改，
恢复处理器直接构造与原预加载引用。不要整体恢复已有其他修改的文件。
对应探针、Python 回归和本文可随之移除；无需更改用户数据、内置卡组、内容签名或云服务。
