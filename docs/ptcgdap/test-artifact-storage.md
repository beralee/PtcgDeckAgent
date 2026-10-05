# 测试与导出产物的磁盘生命周期

2026-10-03 的本地排查发现，磁盘增长主要来自诊断快照、导出产物和隔离测试
用户数据。普通 `run_test_matrix.py` 不会自动导出客户端；它已在每个套件结束后
释放默认创建的 user data，保留结构化结果与日志。

## 已修复的生成路径

`snapshot_strategy_parity.py` 过去直接复制 Git 列出的全部文件，未忽略的历史
`output` 安装包也会进入下一次快照。现在快照边界独立于 Git ignore，排除输出、
测试用户镜像、临时目录和原生构建目录；导入缓存只复制本次资源的 `.import`
实际引用文件。刷新时逐字节比较，未变化文件不重写；源码副本保持独立，不使用
可能互相修改的硬链接。清理旧清单里误收录的生成文件前必须核对原 SHA，变化
的文件保留并报错。

`build_strategy_parity_exports.ps1` 和 `build_performance_player.ps1` 默认在成功或
失败退出时释放本次新建的 UUID 快照。最终二进制、导出日志、源码清单与源码/
项目配置/导出配置哈希继续保留。清理只能作用于当前调用创建的目录，并拒绝
链接、junction 和越界路径。

需要继续在同一冻结源码上调试或调用 `export_strategy_parity_player.ps1` 时，
首次构建显式传入 `-KeepSourceSnapshot`。性能构建的 `-ReuseSourceSnapshot`
始终保留调用者提供的目录。同目录复用不会把清单复制到自身。

`run_performance_bench.py` 的每次冷进程结束后也释放本次播种的重复数据，
支持 `--keep-user-data` 保留。成功、失败、超时和中断都先结束本次进程；
只移除与源逐字节一致的播种内容，将回放、运行日志、自定义卡和所有未知文件
原样保留到 `run-*/user-evidence`，报告位置仍为 `samples.json`。

## 普通测试的使用方式

优先使用默认隔离与自动清理，不为每次测试人为生成永久用户目录：

```powershell
python scripts/tools/run_test_matrix.py --suite BundledDeckCatalog,CardDatabaseSeed
```

`--keep-user-data` 是明确的调试保留选项。`--user-data-root` / `-UserDataRoot`
继续表示由调用者管理的测试目录，运行器不自动删除；不要把真实玩家目录传给
测试入口。测试报告与录像不是可再生缓存，不以历史次数自动淘汰。

## 历史重复文件的安全回收

新工具默认仅生成预览清单：

```powershell
python scripts/tools/cleanup_test_artifacts.py --report .tmp/disk-audit/preview.json
# 对同一范围重新核对并执行，完整保留本地回执。
python scripts/tools/cleanup_test_artifacts.py --execute --report .tmp/disk-audit/cleanup.json
```

默认范围是本仓 `.tmp` 和 `.godot_test_user`，默认要求所属 run 已静置 24 小时。
`--test-root` 可重复指定已确认的外部测试产物目录；不会自行清理其他工作区。
年龄同时考虑文件创建与修改时间，避免复制时保留旧修改时间造成误判。
已有多个硬链接的文件保持共享，不计入可回收量。逻辑文件长度不能直接相加
当作真实占盘；清理回执同时记录实际删除量，机器验收另测磁盘剩余空间。

只选取以下有原件且 SHA-256 完全相同的文件：

- 隔离 Godot 用户目录的内置卡图，对照 `data/bundled_user`，包括去除 `.bin`
  包装后的播种路径；
- 内置音乐镜像，对照 `assets/audio/bgm`，不包含自定义音乐；
- 含 `project.godot` 的快照内部 `output` 副本，对照主仓相对路径的原文件。

执行前再次检查路径、活动进程、run 是否变化和文件哈希。真实玩家用户目录及
其祖先不能作为扫描根；所有 reparse point 均拒绝或跳过。headless 项目测试
仍在运行时，不根据日志路径猜测它的 APPDATA，也不回收播种资源。

工具逐文件删除，不递归删除 run 或快照目录。移除卡图前使播种完成标记失效，
下次启动由正常播种逻辑重建；内置音乐由音乐管理器重新生成。不同内容、无原件
的包、卡牌 JSON、牌组、安装策略、回放、报告、截图与冻结源码均不属于候选。
详细文件路径与哈希回执保存在被忽略的本地目录，不提交到公共证据目录。

## 验证与回滚

```powershell
python -m unittest tests.test_snapshot_strategy_parity tests.test_cleanup_test_artifacts tests.test_test_matrix tests.test_performance_userdata_lifecycle tests.test_performance_bench_report
```

回归覆盖快照内容边界、真实 PowerShell 控制流的成功/失败清理、显式保留和
复用、链接保护，以及重复文件的原件/证据保留、计划后变化拒绝和播种恢复。
微型导出替身用于验证生命周期，不能宣称完整设备导出、引擎一致性或设备验收。

本轮工具回归共 64 项通过（含既有矩阵、macOS 导出及性能报告回归）。本地
清理后再次扫描，已声明且静置足够时间的范围中没有剩余的独立重复文件；共享
硬链接、正在使用的目录、源码及唯一证据保留。详细清理回执位于本机被忽略的
`.tmp/disk-audit-20261003/`，包含完整路径、原件哈希及实际执行结果。

源码回滚仅针对本次测试/快照工具和对应测试、Git ignore 条目及本文，不回退
工作区其他改动。已回收的重复卡图/音乐由启动重建；快照输出可由清理回执中的
原件路径恢复。默认释放的诊断源码目录需用保留选项重新创建。
