# 手机战斗 UI 反馈修复 — 2026-09-30

本轮修复用户截图中的数字重叠、右上角菜单、空操作无法结束回合、演出缺失及五备战牌面过小。
交付基于已记录的 v17 源码快照增量构建，继续使用 v18 的 Android 压缩配置。
属于 Godot 展示与输入集成，不增加规则、策略或 CABT 对齐声明。

## 行为与归属

- 手机横竖屏顶部统一为回合、对手手牌、AI 探讨、宙斯、退出五项；转发原按钮的动作与可用条件。
  原角落菜单、侧工具栏移除；回放模式仍保留原回放菜单。
- 奖赏计数放在叠牌内；牌库、弃牌计数避开备战。结束回合按钮按上下牌堆的实际投影边界居中，
  场地卡保持独立尺寸，攻击标题位于状态栏下方。窄牌面的数字、能量图标按牌宽缩放。
- 竖屏五备战时战斗牌比例从 2.2 调到 2.75、备战牌从 2.2 调到 2.55，并调整相机、间距；
  八备战保留 2.2 的紧凑双排。只改变展示尺寸，不改变备战容量或合法目标。
- `ArenaBattlePresenter` 的 UI 缓存键加入瞬时交互条件；等待结束而公开牌面不变时，结束回合也会恢复可用。
  按钮继续遵守原操作 owner 的模态、回合与待选择门槛。
- `BattleScene` 不再用旧 2D 特效偏好覆盖 3D 的动态设置。真实支援者出牌与攻击动作走既有演出链路。
  攻击提交时同步预留演出等待；原换手 owner 观察 3D busy 状态，避免换手提示提前遮挡模型。

## 验证

本地证据目录：`D:/ai/scratch/arena-mobile-feedback-20260930/`。

- `failing/` 先重现旧 2D 偏好关闭 3D、瞬时等待结束后按钮仍不可用；`handover-failing/` 重现换手不等待 3D。
- `final-owner-suites/report.json`：ArenaMobileLive 3、ArenaPlatformAdaptation 8、ArenaPortableParity 9、
  ArenaPresentationIntegration 6，共 **26/26** 通过。
- `native-final/run-20260930-223746/`：真实窗口 720×1280、1280×720、390×844、768×1024，
  五／八备战布局、旋转、触摸出牌、取消／过期事件、领奖、搜牌、空操作结束回合及真实演出通过。
- `android-v20/summary.json`：Android 模拟器实际 1080×1920、1920×1080，两方向各执行资源演出与输入验收，
  **4/4** 通过，无引擎脚本错误。14 个宝可梦保留关节，18 位支援者各保留六姿态。
  真实 `play_trainer` 和触摸攻击验证演出启动、模型可见、换手提示不覆盖；空操作通过触屏直接结束回合。
- `android-v19/` 保留前次失败：八备战场地卡与奖赏计数相交，以及退出清理恢复方向后报告了错误的测试窗口。
  后者修复为报告实际受测窗口，并在每次截图前校验窗口一致，未放宽尺寸或错误门槛。
- 实际查看横竖屏、五／八备战、支援者、宝可梦、空操作结束回合截图。功能验收与性能验收分开；
  本轮未重新宣称通过接近 2D 的性能门槛，历史六组性能未验收的结论仍有效，Mac 由用户实测。

复现命令：

```powershell
python scripts/tools/run_test_matrix.py --suite ArenaMobileLive,ArenaPortableParity,ArenaPlatformAdaptation,ArenaPresentationIntegration --output NEW_UNIT_DIR --timeout 120
python tools/arena3d/run_probes.py --probe test_arena3d_platforms.gd --output NEW_NATIVE_DIR --timeout 180
python tools/arena3d/run_portable_acceptance.py --device emulator-5554 --apk DIAGNOSTIC_APK --output NEW_ANDROID_DIR --groups arena_review arena_input --sizes 1080x1920 1920x1080 --compact-evidence
```

## 安装包与回退

本地包：`apk-v20/PtcgDeckDojo-0.6.2-20260930-UI-v20-arm64.apk`，**192,529,443 字节**。
SHA256：`12ff537814198fa4c2d876659cf481f1a9d68fc6055844c388dbc91b4df03517`。
APK v2 签名、ARM64 原生依赖与 16 KB 对齐、更新器、玩家策略资源和 121 项共享／轻量资源检查通过。
实际 ARM64 包在带 ARM 翻译的模拟器上覆盖 v18 安装，保留用户数据并打开主菜单，无脚本错误或崩溃。
诊断用 x86_64 APK 与交付用 ARM64 APK 分离；未清除玩家应用数据或发布更新器版本。

7-Zip CLI 生成两个分卷，100,000,000 与 91,409,471 字节。解压测试通过，流式解压 SHA256 与 APK 完全一致。
两个分卷已通过既有授权的 Google Drive 连接上传，回读文件名与字节数一致；上传前的传输超时重试后恢复。
这是连接器上传，rclone 的独立授权仍未配置。远端未返回 MD5，未声称远端内容哈希已核对。

- [分卷 001](https://drive.google.com/file/d/1iOKz-UonFZBq-rnlokJnrH1lz-vW0Liu/view?usp=drivesdk)
- [分卷 002](https://drive.google.com/file/d/1f7xstZchTGhJbyQCZIUc4lpzADlMQFDK/view?usp=drivesdk)

源文件增量哈希、导出配置、检查报告与分卷校验保存在 `apk-v20/`；原快照文件备份位于 `apk-v19/before/`。
导出后已恢复并逐一哈希核对快照中 95 个文件，删除仅本轮新增的两份脚本及 UID。
工作区 Android 导出设置和原始素材导入配置未修改。回退时只恢复 `before/` 中本轮 owner 文件，
删除本轮新增的 `ArenaStatusBar.gd` 与 `test_arena_mobile_live.gd`（及其 UID），保留其他未提交修改。
用户可重新覆盖安装已保留的 v18 APK 回退 UI；没有服务器或数据库迁移。
