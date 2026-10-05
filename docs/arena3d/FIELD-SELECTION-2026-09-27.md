# 对战场地统一选择（2026-09-27）

Windows 对战设置不再显示独立的「画面：3D／2D」按钮。
3D 场地只保留林间道馆，使用真实对局截图，显示场地名称并在右下角显示 3D。
其后保留原有五个 2D 背景及原顺序。选择林间道馆进入 3D，选择原有背景进入 2D。
旧联盟赛事或无效选择自动归一到林间道馆；有效的 2D 选择在存档恢复和卡组编辑返回时继续保留。
其他平台仅列出原有五个场地，旧的 3D 选择回退到默认背景。

场地仍通过 `battle_setup.json` 的 `background_path` 保存；画廊延迟加载不会覆盖已恢复的选择。
从卡组编辑返回使用同一个场地值。旧的独立 3D 开关和主题偏好不覆盖玩家选择。
3D 场内的主题切换仍只影响当前展示及旧主题偏好，下次从设置开战以场地选择为准。

## 缩略图来源

`tools/arena3d/render_field_previews.gd` 启动真实 BattleScene，完成合法开局选择，
在主阶段截取 ArenaBattlePresenter 的 SubViewport，使用正常镜头、灯光和卡牌材质。
图片不含操作弹窗或战斗 HUD，保存为 `assets/arena3d/previews/grove.png`（960 × 546）。
截图中的抽牌结果仅用于展示，不作为规则复现证据。设置页读取静态图片，无需加载 3D 模型。

## 验证

本机 Godot 4.6.1 / Windows / OpenGL Compatibility：

- 聚焦测试先确认仅一项场地的旧实现会丢失五个 2D 背景及其选择，失败证据保存在 `red/`。
- `ArenaPlatformAdaptation`：4/4，包含 native Windows、Android、iOS、macOS、Linux 和 Web 的平台配置门。
- `ArenaPresentationIntegration`：6/6，覆盖林间道馆及全部五个 2D 背景、联盟赛事迁移、角标、预览、名称、2D 保存恢复与运行中模式固定。
- `BattleSetupLayout`：42/42，包含其他平台原有场地列表的触摸布局。
- 普通入口图形探针：行为断言通过，真实 Viewport 点击主菜单和场地，确认六张场地卡、联盟赛事迁移、真实林间道馆与 2D 对战，以及两种选择返回设置后的恢复；无脚本错误或超时。退出时有 ObjectDB 实例、纹理和资源未释放诊断，本次不声明生命周期无泄漏或引擎日志无错误。
- 实际对局缩略图生成成功，修改文件通过差异空白检查。

普通套件共 52 个不同用例通过。其他平台检查使用运行时配置模拟，不代表对应设备实测。
本次只验证展示入口与相关布局，不声明新的 CABT、策略或引擎对齐级别，也未导出、提交或发布产品。

本次保留 2D 的证据根目录：`.godot_test_user/grove-with-2d/`。
`green/report.json` 保存套件结果；`product.log` 保存真实入口检查。
缩略图生成记录仍在 `.godot_test_user/grove-preview/render.log`。
`product-user/Godot/app_userdata/PtcgDeckAgent/arena-field-setup-grove.png` 和
`arena-field-battle-grove.png` 保存设置页和真实对战截图，`arena-integrated-2d.png` 保存 2D 对战截图。

复查命令：

```powershell
python scripts/tools/run_test_matrix.py --suite ArenaPresentationIntegration,ArenaPlatformAdaptation,BattleSetupLayout
python tools/arena3d/run_probes.py --probe test_arena3d_product_entry.gd --output .godot_test_user/arena-field-recheck

$env:APPDATA = Join-Path (Get-Location) '.godot_test_user/grove-preview/render-user'
& 'D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe' --path . --resolution 1280x960 -s res://tools/arena3d/render_field_previews.gd -- --arena-theme=grove
```

## 回退

本次保留 2D 的修改前快照在 `.godot_test_user/grove-with-2d/before/`，只比对场地列表、测试及文档差异。
此前缩略图与名称修改前快照在 `.godot_test_user/grove-preview/before/`。
原二维背景与联盟赛事资源仍存在。保留工作区原有未提交修改和用户存档，不执行全局 reset 或 clean。
