# Android 系统后台下载验收 · 2026-09-19

Android 传输改为系统 DownloadManager。游戏退出不取消系统任务，重开根据持久化任务 ID 接回。收起弹窗时，应用级进度入口显示真实百分比、大小和速度；完成后保留安装入口。macOS 继续官网下载安装，Windows 保留既有游戏内更新路径。

## 实现边界

- 下载中的通知由 Android 系统维护，展开后显示进度条并可取消；点击可返回游戏。完成/失败由接收器发通知，点击只进入游戏，不直接启动安装器。
- 首次下载请求通知权限；关闭权限时保留游戏内进度，并提供通知设置入口。Android 7 使用应用详情设置，Android 8+ 使用通知设置。
- 系统完成文件先复制到应用私有缓存，再做完整大小和 SHA-256 校验；安装前再次校验，原生安装器仍检查包名、签名和 build。只有确认过的私有完整包可进入系统安装确认。
- 外部下载、内部导入均检查空间；导入中取消/进程退出不能将半包标为完成。主动取消移除系统任务；普通退出不取消。旧版应用下载半包仍按原有规则提示重新下载。
- Android 的网络超时、调度、重试和跳转遵循系统下载管理器。具备 Range/ETag 的服务可续传；无法恢复时提供重新下载和官网兜底。系统“强行停止”和厂商电池限制不等同于普通退出，不声称绕过这些限制。

## 实际验证

环境为 Android 16 / API 36 / x86_64，只读临时模拟器，使用电脑上的真实 HTTP 服务与实际 B APK。没有更改线上服务、正式游戏包名、版本或签名。模拟器的互联网探测在本机网络受阻，测试中关闭了该临时模拟器的联网探测，再启用网络；未改变应用的网络或 TLS 校验。

自动化后台检查 **6/6 通过**，见 [记录](evidence/android-background/background.json)：

1. 游戏进程不存在时，系统通知的真实进度从 2% 增长到 6%。
2. 重开保持同一个下载任务 ID，没有重复下载。
3. 断开模拟器网络后进入等待；恢复后进度从 7% 增长到 10%，HTTP 服务实际响应 `206`，续传偏移 `12582912` 字节。
4. 主动取消后系统任务与下载通知移除。
5. 游戏关闭时实际下载完成，并显示“更新包已下载”。
6. 点击完成通知进入游戏，经历整理、校验后才成为可安装，数据标记保留。

另实际点击过进行中的系统通知，确认能启动已退出的游戏并接回同一任务。UI 截图：[游戏内进度](evidence/android-background/game-progress.png)、[展开的系统进度](evidence/android-background/notification-progress-expanded.png)、[完成通知](evidence/android-background/completed-notification.png)。模拟器结果不代替各品牌真机验收。

更新状态回归 **18/18**，包含系统等待不被旧超时取消、退出不撤销下载、重开不重复任务、完成后必须验证哈希、常驻进度和单一弹窗；原有弹窗布局 **8/8**。对应 [状态测试](evidence/android-background/updater.txt) 和 [布局测试](evidence/android-background/ui.txt)。

异常与恢复场景 **10/10** 已完成，见 [记录](evidence/android-background/faults.json)：低空间注入、404、长度不足、半途断流、哈希损坏、不是 APK、缓存删除、版本不符、无响应时仍可取消、恢复后正常下载。LAN 服务的微小非法文件曾在传输层提前断开，被系统拒绝；重新下载可成功，本机真实 HTTP 服务进一步验证了原生 APK 解析拒绝路径。没有把这一网络失败记为安装器测试通过。

还实际拒绝了首次通知权限弹窗：下载继续，游戏显示进度与“开启更新通知”，点击成功进入对应应用的系统通知设置。截图为 [拒绝后游戏界面](evidence/android-background/notifications-disabled.png) 和 [系统设置](evidence/android-background/notification-settings.png)。

最终 A/B 包的原生流程 **4/4 通过**：拒绝安装权限后重试、取消系统安装后重试、确认页游戏进程退出后重试、实际覆盖安装 A→B。系统版本为 `1.0.1 / 2`，数据标记仍为 `created-in-1.0.0`。见 [原生记录](evidence/android-background/native.json)、[安装结果](evidence/android-background/native.png) 与 [最终包 SHA-256](evidence/android-background/checksums.json)。

## 复现与交付

重新构建：`python tools/build_android_update_lab.py`。手机安装 `output/android-update-lab/Install-A-first.apk`；若已经升级过 B，仅卸载“升级验证”再装 A。关闭应用的测试必须启动附带 `start-lan.ps1`，在应用中输入电脑局域网地址。步骤见 [手机验证指南](android-validation.md)。

`tests/run_android_update_lab_background.py` 接受明确的设备、ADB 路径、局域网 URL 和结果路径；`--emulator-network` 仅允许在临时模拟器切换网络。它只操作独立验证包，最终停在包已就绪。异常下载测试为 `tests/run_android_update_lab_checks.py`；真实系统确认与覆盖安装测试为 `tests/run_android_update_lab_native.py`。

本改动只涉及更新组件，不改变本地策略运行时、公共观察或 CABT 动作边界。回退可恢复此前 Android 应用内下载实现、移除系统下载接收器和进度入口，保留原生安装校验与官网入口；不需要修改服务端，也不清空玩家数据。尚未发布或提交。

系统行为参考 [DownloadManager 官方文档](https://developer.android.com/reference/android/app/DownloadManager)。
