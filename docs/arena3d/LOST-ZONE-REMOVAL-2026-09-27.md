# 3D 对战场移除 Lost 区

按用户要求，双方 3D 桌面移除 Lost（放逐）牌堆、空槽、标签、计数和点击入口。
窄屏横向工具栏与竖屏按钮行仅保留双方弃牌入口；桌面牌库和弃牌堆按两列重新居中。
`ArenaFrame` 不再输出 Lost 数据，场地选择中的林间道馆缩略图已重新从真实对局渲染。

## 验证

- 修改前，公开牌堆探针在“3D 不再投影 Lost”断言处失败。
- 修改后，`test_arena3d_public_piles.gd`、`test_arena3d_card_backs.gd`、
  `test_arena3d_platforms.gd` 三项通过，无脚本或引擎错误。
- `ArenaReadabilityAcceptance` 通过：双方弃牌区实际鼠标点击、公开顶牌、空牌堆、
  回收后刷新、弹窗，以及 1280×720、1440×900、1920×1080、2560×1440 布局。
  牌堆无重叠、未覆盖八备战位，也未超出画面。
- `render_field_previews.gd` 成功截取林间道馆正常开局；已目视检查桌面和竖屏截图。

本地日志、机器报告及截图位于
`.godot_test_user/lost_zone_removal_20260927/`（`red/`、`green/`、`visual/`）。
本次仅为 Godot 展示变更，不构成 CABT、引擎等价或设备发布验收。

## 回退

只回退五个 `scenes/arena3d/` 展示脚本、对应公开牌堆探针、
`ArenaReadabilityAcceptance.gd`、README 和 `assets/arena3d/previews/grove.png`
的本次差异即可。修改前文件保留在上述本地目录的 `before/` 中；
其中包含既有未提交工作，不能用仓库级重置代替局部回退。
