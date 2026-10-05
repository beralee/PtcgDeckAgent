# Windows 3D UI 回归

在仓库根目录执行：

```powershell
powershell -ExecutionPolicy Bypass -File tools/arena3d/Run-UiRegression.ps1
```

默认串行执行林间道馆的 11 个场景，共 11 次独立游戏进程。使用隔离的 APPDATA，不读取玩家真实录像，不改玩家卡组、设置或存档。Python 仅用于开发测试，成品游戏不依赖 Python。

测试导出包：

```powershell
powershell -ExecutionPolicy Bypass -File tools/arena3d/Run-UiRegression.ps1 -GameExe D:/path/to/PtcgDeckAgent.exe
```

选择场景或切换 Vulkan：

```powershell
powershell -ExecutionPolicy Bypass -File tools/arena3d/Run-UiRegression.ps1 -Cases stadium_detail -Renderer forward_plus -Repeat 2
```

Python 入口还支持 `--timeout`、`--output`、`--godot`。Godot 默认路径是本机 `D:\ai\godot\Godot_v4.6.1-stable_win64.exe`；其他机器通过 `-Godot` 指定。测试机需图形桌面，本套件不以无头测试替代鼠标和渲染验收。

## 场景

| ID | 验证内容 |
|---|---|
| setup | 初始战斗位、备战选择期间点击被遮挡的退出按钮；原必选流程可继续 |
| mulligan | 当前主分支自动补抽一次、非阻塞提示和重复信号拒绝；接续正常开局 |
| search | 实际巢穴球检索、已选状态、遮挡、确认后上场并归还控制 |
| prize_overlays | 真实击倒后取消退出、查看卡牌/弃牌、模态防穿透、开关表现设置与缩放、领奖和补位 |
| replacement | 双人模式真实击倒、领奖、交接视角、人工选择补位、下一回合 |
| stadium_detail | 右键场地只查看详情；领奖期间左键仍可阅读且不覆盖领奖选择 |
| hand_resume | 实际奇树双手牌结算，飞牌中缩放窗口，手牌恢复并可结束回合 |
| core_input | 原完整鼠标回归：目标、多选、清除、取消、旧窗口释放拒绝、拖牌、详情叠层、领奖 |
| search_motion | 四分辨率检索、大图、滚动、不可选项、奇树、关闭动态和缩放清理 |
| bench_eight | 实卡零之大空洞、第 6–8 只备战、悬停、风动、光影与飞牌 |
| two_prizes | 快速动画、两张奖赏逐张领取、取消退出、补位和下一回合 |

全部交互通过根 Viewport 发送鼠标事件。构造规则状态只用于搭建测试场面；用例的结论来自后续规则状态、牌数、输入恢复及界面断言。它们不是自然完整对局或所有卡效的验证。

## 结果与失败规则

- 输出位于 `evidence/arena3d/ui-regression/`，每次创建全新子目录，避免旧 PASS 文件污染。
- `report.html` 是可点击的结果表；`report.json` 可供持续集成读取；每场包含 `engine.log`、`process.log`、场景结果和截图。
- 未生成场景结果、进程非零退出、超时、脚本错误和 Godot `ERROR` 都算失败，即便日志打印过 PASS。已有 NUL 字符提示及 WARNING 不冒充通过的脚本检查，也不会单独触发失败。
- 失败后继续运行其余场景，最终有任意失败就返回退出码 1。报告在每场结束时保存。
- 默认每场最多 160 秒；超时只终止本次启动的子进程树，不会关闭其他游戏/编辑器。
- 没有启动到渲染阶段的崩溃/超时可能没有截图，仍会保存日志和失败记录。

不要把本脚本设置成并行启动多个矩阵。一般修改先用 `-Cases` 跑相关场景，通过后再跑完整矩阵；发布前传入确切 `-GameExe` 复核最终包。
