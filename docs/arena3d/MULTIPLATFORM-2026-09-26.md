# 3D 战斗 UI 多平台适配回执

日期：2026-09-26。基于同日的桌面 3D 集成继续开发，当前分支 `main`，
HEAD 为 `53cc7f86cb2048827ae29dc510494ded92ceb48c`。本次没有新增提交、推送或发布。
工作区原有大量未提交修改，本次按开始时的文件 SHA-256 清单核对并保留。

## 已接入的能力

- 3D 设置入口支持桌面、原生移动端和 Web，保留每局开始前的 2D/3D 选择。
- `ArenaPlatform`、`ArenaLayout`、`ArenaCompactHud` 依据实际宽高布局，
  手机横屏使用左右工具栏，竖屏使用上下工具栏，平板和桌面保留更大牌桌。
  原生移动设备避开安全区；Web 复用原页面的安全区。
- 触摸目标、字号与手牌高度随屏幕调整；竖屏八个备战位分两排。
  菜单保留手牌查看、AI 探讨、宙斯、退出及回放操作，记录支持滚动阅读。
- `ArenaTouchInput` 负责点击、长按查看、移动取消、多指取消、失焦和旋转取消。
  奖赏、搜牌、场上操作仍调用原战斗界面的规则与交互入口。
- 牌桌、手牌飞行动画及预览共享画质预算；移动端/Web 默认省电，
  3D 表面最长边限制为 1280，关闭阴影、MSAA 和环境粒子。
  高画质最长边 2560；Web 各 3D 表面始终关闭 MSAA。
- 牌桌材质增加移动端压缩导入并限制分辨率，原图与卡图保留。
  Web 导出排除不适用的本机 ONNX GDExtension 文件。
  Web 测试包 PCK 为 222.16 MiB，WASM 为 34.08 MiB，未提高原 225/40 MiB 门槛。

不修改卡牌效果、AI 决策、CABT 公共输入、选择窗口权限、存档标识、版本号和主菜单。
没有新增玩家端 Python 或在线推理依赖。本次验收属于展示与交互，不声明新的策略对齐等级。

## 解决的兼容冲突

1. 旧移动端布局会在横屏仍强制竖屏并旋转整块画布。3D 场景按真实宽高布局，
   2D 路径继续使用原有设置；离开 3D 后恢复原画布尺寸。
2. 原竖屏代码写入的弹窗固定矩形在转横屏后残留，导致操作框和取消按钮离开屏幕。
   3D 布局变化时重新绑定原弹窗与居中容器的边界，保留其原操作逻辑。
3. 桌面手牌扇形和搜牌双大图不适合手机。触摸模式使用原手牌滚动容器及搜牌选择界面，
   同时修复继承容器的最小宽度造成的横向溢出。
4. Godot Web 会先发送触摸模拟鼠标，再发送真实触摸。3D 区域在去重之前拦截
   自己拥有的模拟鼠标，使真实触摸能完成长按、取消及一次性操作；原弹窗仍保留原路由。
5. HUD 触摸适配器新增显式 3D 入口，默认的 2D 平台启用条件保持不变。
6. 降低 3D 渲染分辨率后，投影与射线拾取通过同一坐标映射转换，避免显示位置与点击目标错位。

## 验证

本地证据目录：`D:/ai/scratch/ptcgdap-3d-platforms-20260926/`。

| 检查 | 结果与范围 |
| --- | --- |
| 自动发现的功能套件 | 10 个套件、202 项通过，见 `suite-summary.json`；包含 3D 接入、手牌事件、原竖屏布局、触摸适配和输入去重 |
| Godot 脚本导入与解析 | 导入及 Windows、Android、Web 导出完成，无脚本解析错误 |
| Compatibility 渲染探针 | 5 项通过；最后针对手牌渲染和平台交互再次回归，见 `touch-final/` |
| 多平台几何与交互 | 390×844、844×390、768×1024、1600×900；验证点击/长按、取消、过期输入、弹窗边界、附能只执行一次、连续领奖、搜牌与八备战位 |
| Windows 导出程序 | `windows-final-acceptance/` 中平台验收通过，包括模拟鼠标先到达的长按输入 |
| Android | 最终调试 APK 导出成功；未连接设备，未完成安装与真机运行 |
| Web | Chromium 桌面、Pixel 7 配置两项通过；WebKit 桌面、iPad、iPhone 横/竖屏四项因渲染错误失败，交互断言通过。详见 `browser-strict-final/results.json` |

浏览器验收用真实鼠标或触摸事件，覆盖横竖屏、打开场上操作、关闭弹窗和切换主题。
Web UI E2E 包包含仅测试导出启用的固定公开牌面与观测桥，不能作为生产 Web 包发布。
Windows 与 Android 文件来自当前整个工作区，也包含开始本任务前已经存在的改动。

## 未通过与未覆盖

- Windows 版 Playwright WebKit 的严格渲染检查仍出现
  `glBlitFramebuffer: Read and write color attachments cannot be the same image`，
  部分截图变黑；交互断言已通过，渲染验收仍不通过。没有过滤或豁免该错误。
  [Playwright 上游问题 #42885](https://github.com/microsoft/playwright/issues/42885)
  报告了相似的 Windows WebKit 画布缩放后截图异常，但这只能作为相关线索，
  不能证明本项目错误完全来自测试环境。需要 macOS Safari/iPhone 实机复测后再判断发布资格。
- Android/iOS 原生真机的安全区、后台恢复、长时间性能、温升与功耗尚未验证；
  macOS/Linux 原生桌面也没有在对应系统运行。Windows 上的设备尺寸模拟不能替代这些验收。
- 快速重复旋转探针中仍能看到手牌投影自修复警告；稳定后的滚动范围、手牌点击和附能断言通过。
  未移除原警告，需要移动端长局验证是否存在可见抖动。
- 本轮是聚焦 UI 回归，没有重新执行全卡牌规则、全部策略基准、在线对战和完整回放矩阵。

## 复现与回退

```powershell
python scripts/tools/run_test_matrix.py --suite ArenaPlatformAdaptation,ArenaPresentationIntegration,BattlePortraitLayout,IosWebHudTouchAdapter --output D:/ai/scratch/arena-platform-suites
python tools/arena3d/run_probes.py --probe test_arena3d_platforms.gd --output D:/ai/scratch/arena-platform-probes
python tools/arena3d/run_probes.py --exe D:/ai/scratch/ptcgdap-3d-platforms-20260926/windows/PtcgDeckAgent.exe --probe test_arena3d_platforms.gd --output D:/ai/scratch/arena-export-probes
$env:PTCG_WEB_E2E_EXPORT_DIR='D:/ai/scratch/ptcgdap-3d-platforms-20260926/web-final'
$env:PTCG_WEB_E2E_ARTIFACT_DIR='D:/ai/scratch/arena-browser-results'
# 在 tests/web_e2e 目录执行
npx playwright test -c arena.config.cjs
```

用户侧可在对战设置切回 2D，或启动时传入 `--battle-2d`，保留存档和当前策略。
源码回退应根据证据目录的 `task-changes.patch`、`changed-since-start.json`、
`new-task-files.json` 和 `ours/` 逐项处理，仅移除本次增量；
不要对脏工作区执行整仓库重置，也不要删除此前整合的 3D 资源。
