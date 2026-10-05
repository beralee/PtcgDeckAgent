# 当前战斗界面的 3D 展示

2026-10-04：当前版本以 3D 场地能力和功能回归为发布重点。卡牌内容更新暂时关闭，
首页入口、自动检查/下载和启动时的外部内容包加载均停用；已有存档保留。
重新启用须先完成独立验收，不能随 3D 版本自动发布。
本轮停用范围、功能回归和验收边界见 [2026-10-04 验收记录](CONTENT-UPDATE-HOLD-2026-10-04.md)。

3D 展示来自 `D:/ai/code/PtcgDAP-3d` 工作区的 `codex/ptcg-3d-windows` 分支。
该分支的提交 `b4608d2e` 已是 main 的祖先；本次整合的是其未提交的 v12 展示实现。
历史独立版本的应用名称、主菜单、存档目录、版本号和发布路径不应用到当前产品。

## 使用

从原主菜单进入对战设置，在「对战场地」选择缩略图。
Windows 的 3D 场地只保留「林间道馆」，使用真实对局截图，右下角标有「3D」；其后保留原有五个 2D 背景。
旧存档中的联盟赛事自动归一到林间道馆，原有 2D 选择继续有效。独立的「画面：3D／2D」按钮已移除。
所选场地随 `battle_setup.json` 保存，重新进入设置或从卡组编辑返回时保持选择。
旧 `arena_visuals.cfg` 中的 3D 开关和主题偏好不覆盖所选场地。
当前工作区已为 Android、Web、macOS 接入轻量 3D 场地，Live 风格竖屏布局已实现。
最终安卓包的横竖屏视觉与输入检查 4/4 通过；六组性能对比未达门槛，尚未发布。
Windows 上 Chromium 的桌面／触屏输入与性能检查 4/4 通过，不代表安卓浏览器或 Mac 实机通过。
iOS 原生版、Linux 保留 2D 回退。横屏、竖屏和触摸继续由既有交互路径处理。
对局开始时固定展示模式，不在进行中的对局热切换。
本轮实现与待验收项见 [轻量 3D 性能记录](PORTABLE-PERFORMANCE-2026-09-30.md)。
最新截图反馈修复与安卓验证见 [手机 UI 反馈记录](MOBILE-UI-FEEDBACK-2026-09-30.md)。
异步策略对局漏播、手机动画开关和 DeepSeek 大字展示的修复见 [实际对局动画记录](LIVE-EFFECTS-2026-10-01.md)。
9:16 主菜单、能量与 HP、对手详情、连续附能和领奖演出见 [安卓反馈修复记录](ANDROID-FEEDBACK-2026-10-01.md)。

六卡领奖、人人对战换位、首页点击穿透、四秒对话和明亮林间底色见 [后续修复记录](ANDROID-FOLLOWUP-2026-10-01.md)。
历史 WebKit 严格渲染失败仍需复核；旧 Windows/Chromium 回执不能代替本轮验证。
本轮按用户要求使用安卓模拟器，Mac 实机由用户测试。

现有主菜单、卡组、经典 AI、作者策略、更新器、版本号和存档路径保持原归属。
战斗顶栏的手牌查看、AI 探讨及宙斯帮助保留。3D 场景仅保留林间道馆。
桌面保留画质、动态、速度、音效、记录等入口；场景切换按钮已移除。
3D 桌面每方仅保留牌库和弃牌堆，横屏与竖屏均不再显示 Lost（放逐）区或入口。
触摸模式点击出牌／选目标，长按场上卡查看详情，滑动浏览手牌；
手机横竖屏顶部统一显示回合、对手手牌、AI、宙斯和退出，移除右上角菜单与侧工具栏；
回放模式仍通过回放菜单使用原导航。竖屏参考 Live 的模块位置：双方奖赏卡在左侧叠放，
场地卡在左侧中间，牌库／弃牌区在右侧，结束回合位于双方牌堆之间。
竖屏上下两排工具栏已移除，场地卡、弃牌区继续直接触摸查看。
领奖时才展开六个独立选项；默认五备战时放大战斗位与备战牌，八备战时切回紧凑双排布局。
奖赏计数收在牌堆内，结束按钮按上下牌堆计数的实际边界定位。
旧 2D 特效偏好不再关闭 3D 演出；换手提示等待 3D 攻击演出结束，空操作回合也可正常结束。
Android、macOS 和浏览器使用固定的轻量画质：原卡桌与奖赏托架的离线 LOD、最长边 832 像素及静态缓存。
14 种宝可梦保留全部关节与演出，18 位训练家保留六姿态立绘、特效和声音；共用 Windows 的动作时序。
竖屏保留 HP 上限、伤害、实际能量类型、道具、异常状态及已用特性标记。
这些平台不继承桌面精细画质开关，文字、触摸与详情界面保留 UI 分辨率。
原 2D 特效预览和屏幕方向切换可通过 2D 模式使用。

## 实现边界

- `BattleScene.gd` 在既有战斗场景中安装 `ArenaBattlePresenter`，将点击返回原操作 owner。
- `ArenaFrame` 只投影公开场上卡、数量、状态、场地和公开弃牌。私有手牌、牌库顺序和奖赏身份不进入 3D DTO。
- `ArenaWorld`、牌桌模型、着色器、卡面 HUD、手牌和搜牌展示只承担画面。
- `ArenaHandEventBridge` 在可信场景层复用动作时刻快照，只向动画输出角色、数量和方向。
- `BattlePresentation` 按场景隔离旧 2D 动画，避免改写全局特效开关；场景销毁取消拖动与回调。
- 点击受模态状态、输入代次、当前公开状态约束；领奖和多阶段选择继续由既有规则 owner 决定。

CABT 接口、策略输入、选择索引、卡牌效果和策略包信任没有因 3D 获得新权限。
本次属于 Godot 展示／交互集成，不声明新的策略对齐、引擎等价、强度或 A5 验收。

## 资源与依赖

运行时使用已有 Godot 4.6.1 和本地 GLB、纹理、HDR、着色器，无新增外部推理或 Python 依赖。
保留兼容渲染器，3D 回归可分别选择 OpenGL Compatibility 和 Forward+。
只导入当前 v6 林间道馆牌桌、v5 奖赏托架、v4 雷电贴图和 v3 环境光，不导入旧版重复牌桌或历史构建。

可编辑 Blender 文件在 `art/arena3d/product-v6/` 和 `art/arena3d/product-v5/`。
原材质来源在 `art/arena3d/product-v3/sources/`，由 `.gdignore` 和导出排除隔离。
Blender 仅用于开发重建：以 Blender 5.2 运行 `tools/arena3d/build_living_tables.py`
及 `build_tactical_modules.py`。材质和环境来源见
`assets/arena3d/product-v3/THIRD_PARTY.md` 和 `asset-sources.json`；卡背来源见
`assets/ui/card_backs/README.md`。未扩张原素材的授权声明。

## 验证和回退

普通测试通过项目的自动发现目录运行：

```powershell
python scripts/tools/run_test_matrix.py --group ui --suite ArenaPresentationIntegration,ArenaHandEventBridge
python tools/arena3d/run_probes.py --output .godot_test_user/arena-probes
python tools/arena3d/run_ui_regression.py --themes grove --renderer gl_compatibility --output .godot_test_user/arena-ui
```

独立 SceneTree 探针不计入普通 suite 数量。两个 3D runner 均串行、隔离存档、保留日志并拒绝超时／脚本错误。
`--arena-3d` 为 Windows 直接场景／探针开启 3D；`--battle-2d` 强制下一场使用 2D。
玩家可在对战设置选择原有背景进入 2D；开发验证也可使用 `--battle-2d`，不删除存档，不更换 AI owner。
缩略图由 `tools/arena3d/render_field_previews.gd` 启动真实 BattleScene，完成开局后截取正常镜头的 3D 画面；设置页无需实时加载 3D 模型。
首次整合范围见 [集成回执](INTEGRATION-2026-09-26.md)，后续适配见 [多平台回执](MULTIPLATFORM-2026-09-26.md)。
暗色场地移除、压缩备份与空间统计见 [仅保留林间道馆](GROVE-ONLY-2026-09-27.md)。
测试导出程序时 runner 会传入 `--arena-acceptance` 进入固定本地验收场景；正常启动仍打开原主菜单。
