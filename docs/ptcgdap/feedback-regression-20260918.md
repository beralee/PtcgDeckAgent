# 2026-09-18 玩家反馈回归

验证完成于 2026-09-19。基于本地 `0.6.0` 工作区（HEAD `b4608d2e`，包含既有未提交改动），使用 Godot 4.6.1。这里记录开发回归，不代表已发布安装包或安卓真机验收。

## 反馈与处理

| 反馈 | 当前源码验证 | 本次处理 |
| --- | --- | --- |
| 铁斑叶换位后不转移能量 | `CSV7C_033` 从手牌上备战区，通过真实交互选择来自旧战斗宝可梦和另一只备战宝可梦的两张能量；均转移到新战斗位置，未选择的能量留在原处 | 已通过，增加回归覆盖 |
| 安卓平板横屏缺少结束回合、界面越界 | 实例化完整战斗场景并等待容器布局后，1024×768 的结束回合按钮越过右边界；手牌区也超过下边界 | 修正状态栏实际宽度预算和卡片文字引起的最小尺寸膨胀 |
| 祭典乐舞装备头带后伤害错误 | 按用户同意的头带假设，采用本地“不服输头带 / Defiance Band”`CSV1C_117`。`CSV8C_024` 配 `CSV8C_201`，五只备战、奖赏落后时预览与实伤均 130；奖赏追平后第二击均为 100 | 已通过，增加连续两击条件重新计算的回归；原玩家具体道具和伤害数值仍未知 |
| 呆呆王复制酋雷姆招式，点击与命中目标不符 | `CSV9C_072` 灵感挑战复制 `CSV9C_147` 三重冰霜，从六只对手宝可梦中依次选择备战 5、2、4，仅所选三只各受到 110 伤害；战斗位置及未选备战不受伤害 | 已通过，增加非默认顺序、部分目标的真实交互回归 |
| 删除卡组卡死 | 既有竖屏删除回归与新增横屏确认框回归均通过：先关闭确认框，输入回调结束后删除，其他卡组行实例保持不变 | 保留工作区既有修复，补测横屏路径 |
| 紧急切换不能转移多颗能量 | `CSV9C_180` 分配第一张后，来源选择区被提前收起，玩家无法继续选第二张 | 尚可分配时重新显示能量来源；选择目标期间及达到上限后继续收起 |

## 修改范围

- `scripts/ui/battle/BattleInteractionController.gd`：修正来源选择区收起条件，不改变卡牌效果或选择数据格式。
- `scripts/ui/battle/layouts/BattleLandscapeLayoutView.gd`：布局前按实际 VSTAR 图片、状态栏和按钮高度校正卡片尺寸，奖赏及牌库预览同步缩放。
- `scenes/battle/BattleCardView.gd`：卡图与覆盖文字改为由卡槽确定尺寸；缺图提示不再撑大外层容器；手牌标题、副标题限制行数并显示省略号，避免小尺寸时文字溢出。
- 新增 `tests/test_player_feedback_20260918.gd` 六项回归。测试目录自动发现该文件。
- 两处现有测试随实际布局调整：横屏 HUD 对齐使用最终卡片尺寸；空卡槽样式检查依赖 `Control` 接口而非旧容器类型。保留原断言意图。

## 验证

| 完整 focused suite | 通过 / 总数 |
| --- | --- |
| `test_player_feedback_20260918.gd` | 6 / 6 |
| `test_battle_layout_controller.gd` | 8 / 8 |
| `test_battle_portrait_layout.gd` | 107 / 107 |
| `test_battle_ui_features.gd` | 116 / 116 |
| `test_battle_ui_features_part2.gd` | 92 / 92 |
| `test_battle_ui_features_part5.gd` | 15 / 15 |
| `test_csv9c_trainer_stadium_energy_effects.gd` | 44 / 44 |
| `test_csv5c_053_054_csv9c_072_cards.gd` | 9 / 9 |
| `test_ucis_interaction_compiler.gd` | 9 / 9 |
| `test_deck_delete_feedback_regressions.gd` | 6 / 6 |
| 合计 | 412 / 412 |

横屏回归使用真实 `SubViewport`：1024×768、1280×800、1340×800、1600×960、1600×1200、1920×1200、2560×1600。覆盖双方满五只备战、七张手牌、缺图占位、零之大空洞八备战位，检查按钮、手牌、奖赏、日志及备战区边界。额外使用 Windows OpenGL 渲染检查 1024×768、1600×960、1600×1200 截图。

测试在隔离的 APPDATA 下运行。复现示例（PowerShell）：

```powershell
$env:APPDATA = 'D:/ai/code/PtcgDAP/.godot_test_user/player_feedback_20260918'
& 'D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe' --headless --path . -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_player_feedback_20260918.gd
```

本地诊断位于 `tmp/player_feedback_20260918/`，包括修复前失败日志、最终 focused 日志和渲染图。退出时有资源释放警告，日志已保留；最终测试没有脚本错误。

验收范围为 Godot 本地规则与交互回归、Windows 渲染及平板尺寸模拟。未声称安卓实体平板或 0.6.0 已发布 APK 验收通过，也未进行 CABT 官方引擎一致性或策略胜率验收。

## 回退

如需回退，只移除上述三个生产文件的本次差异、新增回归文件及两处测试适配。修改前快照保存在同一临时目录的 `*.before.gd` 中；现有测试文件包含其他未提交工作，不能整文件恢复到 Git HEAD。无需迁移数据。本次未提交、推送或发布。
