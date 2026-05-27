# 设计文档：安卓端非对战场景字号优化

- **日期**：2026-05-24
- **状态**：待实施
- **影响范围**：仅安卓端非对战 & 非对战设置场景
- **PC/Mac 端**：行为完全不变

---

## 1. 问题描述

项目 `project.godot` 中 viewport 基准为 1600×900，stretch mode 为 `canvas_items` + `expand`。
在安卓手机（典型分辨率 1080×2400）上，1 逻辑像素 ≈ 0.675 物理像素。
代码中大量硬编码字号 14–15 px 在手机上只有约 9–10 物理像素，中文字体在此尺寸下难以辨认。

## 2. 设计目标

| 目标 | 约束 |
|------|------|
| 安卓端非对战场景字号放大至可读水平 | PC/Mac 端所有字号不变 |
| 不改动对战场景 `scenes/battle/` | 对战场景已有独立的 portrait 布局系统 |
| 不改动对战设置 `scenes/battle_setup/` | 用户明确要求排除 |
| 不改 `project.godot` 的 content_scale | 全局缩放会同时影响对战场景 |
| 不改 `DeckDiscussionDialog` 现有逻辑 | 已有完善的 portrait 适配 |

## 3. 方案概述

在 `HudTheme.gd` 中新增一个 **静态公共方法** `scaled_font_size(base: int) -> int`：

```gdscript
static func scaled_font_size(base: int) -> int:
    if not _is_touch_runtime():
        return base
    return ceili(float(base) * 1.4)
```

- **PC/Mac/桌面端**：`_is_touch_runtime()` 返回 `false`，函数原样返回 `base`，零行为差异。
- **安卓/iOS/移动 Web 端**：字号放大 40%（14→20, 15→21, 32→45）。

然后将**受影响场景脚本**中的所有硬编码 `font_size` 数值替换为 `HudTheme.scaled_font_size(原值)` 调用。

## 4. _is_touch_runtime() 已有实现

`HudTheme.gd:142-143` 已有此方法，判断条件为：

```gdscript
static func _is_touch_runtime() -> bool:
    return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
```

此条件在 PC/Mac 上始终返回 `false`，保证桌面端零影响。

## 5. 放大倍数选择依据

| 基准字号 | ×1.4 结果 | 在 1080p 手机上的物理像素 | 可读性 |
|----------|-----------|---------------------------|--------|
| 11 | 16 | ~10.8 | 最小可读 |
| 14 | 20 | ~13.5 | 舒适 |
| 15 | 21 | ~14.2 | 舒适 |
| 18 | 26 | ~17.6 | 标题级 |
| 24 | 34 | ~23.0 | 大标题 |
| 32 | 45 | ~30.4 | 页面标题 |
| 34 | 48 | ~32.4 | 页面标题 |

1.4 倍使最小字号（11→16）仍可读，大标题（34→48）不至于过大，是一个平衡点。

## 6. 改动文件清单

### 6.1 HudTheme.gd（核心，1 处新增 + 6 处内部替换）

**文件**：`scripts/ui/HudTheme.gd`

**新增**：公共静态方法 `scaled_font_size(base: int) -> int`

**内部替换**（HudTheme 自身的 style 函数也用硬编码字号）：

| 函数 | 行号 | 原值 | 改为 |
|------|------|------|------|
| `_style_label` (TitleLabel) | 215 | `32` | `scaled_font_size(32)` |
| `_style_label` (xxxTitle) | 221 | `18` | `scaled_font_size(18)` |
| `_style_label` (默认) | 224 | `14` | `scaled_font_size(14)` |
| `_style_button` | 229 | `15` | `scaled_font_size(15)` |
| `_style_option` | 242 | `15` | `scaled_font_size(15)` |
| `_style_line_edit` | 252 | `15` | `scaled_font_size(15)` |
| `_style_text_edit` | 261 | `14` | `scaled_font_size(14)` |
| `_style_rich_text` | 271 | `14` | `scaled_font_size(14)` |

### 6.2 MainMenu.gd（13 处）

**文件**：`scenes/main_menu/MainMenu.gd`

| 行号 | 上下文 | 原值 | 改为 |
|------|--------|------|------|
| 124 | 菜单按钮 | `18` | `HudTheme.scaled_font_size(18)` |
| 296 | 角落操作标签 | `15` | `HudTheme.scaled_font_size(15)` |
| 363 | 版本号 | `14` | `HudTheme.scaled_font_size(14)` |
| 415 | 更新按钮 | `16` | `HudTheme.scaled_font_size(16)` |
| 673 | 弹窗标题 | `22` | `HudTheme.scaled_font_size(22)` |
| 699 | 富文本正文 | `16` | `HudTheme.scaled_font_size(16)` |
| 711 | 纯文本正文 | `16` | `HudTheme.scaled_font_size(16)` |
| 849 | 关于页标题 | `24` | `HudTheme.scaled_font_size(24)` |
| 857 | 关于页副标题 | `14` | `HudTheme.scaled_font_size(14)` |
| 925 | 联系人名 | `20` | `HudTheme.scaled_font_size(20)` |
| 932 | 联系人 ID | `13` | `HudTheme.scaled_font_size(13)` |
| 950 | 联系人信息 | `14` | `HudTheme.scaled_font_size(14)` |
| 991 | 按钮 | `15` | `HudTheme.scaled_font_size(15)` |

### 6.3 Settings.gd（10 处）

**文件**：`scenes/settings/Settings.gd`

| 行号 | 上下文 | 原值 | 改为 |
|------|--------|------|------|
| 279 | 页面标题 | `34` | `HudTheme.scaled_font_size(34)` |
| 285 | 分区标题 | `18` | `HudTheme.scaled_font_size(18)` |
| 289 | 子标题 | `17` | `HudTheme.scaled_font_size(17)` |
| 293 | 正文 | `14` | `HudTheme.scaled_font_size(14)` |
| 298 | 说明文本 | `12` | `HudTheme.scaled_font_size(12)` |
| 302 | 标签 | `14` | `HudTheme.scaled_font_size(14)` |
| 307 | 按钮 | `15` | `HudTheme.scaled_font_size(15)` |
| 320 | 下拉框 | `15` | `HudTheme.scaled_font_size(15)` |
| 332 | 输入框 | `15` | `HudTheme.scaled_font_size(15)` |
| 342 | SpinBox | `15` | `HudTheme.scaled_font_size(15)` |

### 6.4 DeckManager.gd（14 处）

**文件**：`scenes/deck_manager/DeckManager.gd`

| 行号 | 上下文 | 原值 | 改为 |
|------|--------|------|------|
| 28 | 常量 `HUD_BUTTON_FONT_SIZE` | `23` | `HudTheme.scaled_font_size(23)` — 注：常量改为动态调用，需改为函数/变量 |
| 29 | 常量 `HUD_BUTTON_COMPACT_FONT_SIZE` | `21` | `HudTheme.scaled_font_size(21)` — 同上 |
| 169 | 页面标题 | `32` | `HudTheme.scaled_font_size(32)` |
| 243 | 搜索输入框 | `15` | `HudTheme.scaled_font_size(15)` |
| 365 | 推荐状态 | `12` | `HudTheme.scaled_font_size(12)` |
| 430 | 卡组元信息 | `12` | `HudTheme.scaled_font_size(12)` |
| 438 | 卡组名 | `23` | `HudTheme.scaled_font_size(23)` |
| 446 | 卡组行标题 | `17` | `HudTheme.scaled_font_size(17)` |
| 460 | 推荐理由标题 | `15` | `HudTheme.scaled_font_size(15)` |
| 527 | 小标题 | `14` | `HudTheme.scaled_font_size(14)` |
| 1025 | 卡组名（详情） | `24` | `HudTheme.scaled_font_size(24)` |
| 1058 | 详情标题 | `18` | `HudTheme.scaled_font_size(18)` |
| 1144 | 行标签 | `17` | `HudTheme.scaled_font_size(17)` |
| 1246 | 名称标签 | `23` | `HudTheme.scaled_font_size(23)` |
| 1740 | 小字标签 | `11` | `HudTheme.scaled_font_size(11)` |
| 1779 | 头部 | `20` | `HudTheme.scaled_font_size(20)` |

> **注意**：`HUD_BUTTON_FONT_SIZE` / `HUD_BUTTON_COMPACT_FONT_SIZE` 是 `const`，不能直接赋值为函数调用。
> 改法：将这两个常量保留为桌面端基准值，在使用处 `font_size` 变量赋值时包一层 `HudTheme.scaled_font_size()`：
> ```gdscript
> var font_size := HudTheme.scaled_font_size(
>     HUD_BUTTON_COMPACT_FONT_SIZE if compact else HUD_BUTTON_FONT_SIZE)
> ```

### 6.5 ReplayBrowser.gd（6 处，含 2 个常量）

**文件**：`scenes/replay_browser/ReplayBrowser.gd`

| 行号 | 上下文 | 原值 | 改为 |
|------|--------|------|------|
| 14 | 常量 `REPLAY_ROW_TITLE_FONT_SIZE` | `23` | 保留常量，使用处包 `scaled_font_size` |
| 15 | 常量 `REPLAY_ROW_META_FONT_SIZE` | `18` | 同上 |
| 16 | 常量 `HUD_BUTTON_FONT_SIZE` | `23` | 同上 |
| 17 | 常量 `HUD_BUTTON_COMPACT_FONT_SIZE` | `21` | 同上 |
| 40 | 页面标题 | `34` | `HudTheme.scaled_font_size(34)` |
| 120-124 | 按钮字号变量 | `font_size` | 包 `HudTheme.scaled_font_size()` |
| 163 | 空列表提示 | 常量引用 | 包 `HudTheme.scaled_font_size()` |
| 224 | 回放行标题 | 常量引用 | 包 `HudTheme.scaled_font_size()` |
| 242 | 回放行元信息 | 常量引用 | 包 `HudTheme.scaled_font_size()` |
| 314 | 空搜索提示 | 常量引用 | 包 `HudTheme.scaled_font_size()` |

### 6.6 DeckEditor.gd（17 处）

**文件**：`scenes/deck_editor/DeckEditor.gd`

| 行号 | 上下文 | 原值 | 改为 |
|------|--------|------|------|
| 39 | 常量 `CATEGORY_TAB_FONT_SIZE` | `18` | 保留常量，使用处包 `scaled_font_size` |
| 42 | 常量 `ACTION_BUTTON_FONT_SIZE` | `30` | 同上 |
| 172 | 操作按钮 | 常量引用 | 包 `HudTheme.scaled_font_size()` |
| 360 | 分类标签 | 常量引用 | 包 `HudTheme.scaled_font_size()` |
| 745 | 卡牌瓦片标签 | `_card_tile_label_font_size()` | 包 `HudTheme.scaled_font_size()` |
| 799 | 数量标签 | `10` | `HudTheme.scaled_font_size(10)` |
| 1047 | 弹窗标题 | `24` | `HudTheme.scaled_font_size(24)` |
| 1061 | 关闭按钮 | `24` | `HudTheme.scaled_font_size(24)` |
| 1078 | 提示 | `20` | `HudTheme.scaled_font_size(20)` |
| 1085 | 描述 | `14` | `HudTheme.scaled_font_size(14)` |
| 1104 | 文本编辑 | `15` | `HudTheme.scaled_font_size(15)` |
| 1176 | 按钮 | `14` | `HudTheme.scaled_font_size(14)` |
| 1185 | 大按钮 | `24` | `HudTheme.scaled_font_size(24)` |
| 1212 | 目标头 | `16` | `HudTheme.scaled_font_size(16)` |
| 1262 | 目标头 | `16` | `HudTheme.scaled_font_size(16)` |
| 1681 | 高亮 | `12` | `HudTheme.scaled_font_size(12)` |
| 1707 | 标题 | `13` | `HudTheme.scaled_font_size(13)` |
| 1714 | 理由 | `12` | `HudTheme.scaled_font_size(12)` |
| 1955 | 卡牌详情标题 | `20` | `HudTheme.scaled_font_size(20)` |
| 1979 | 卡牌详情正文 | `14` | `HudTheme.scaled_font_size(14)` |
| 2007 | 按钮 | `14` | `HudTheme.scaled_font_size(14)` |

### 6.7 DeckViewDialog.gd（2 处）

**文件**：`scripts/ui/decks/DeckViewDialog.gd`

| 行号 | 上下文 | 原值 | 改为 |
|------|--------|------|------|
| 285 | 标签 | `11` | `HudTheme.scaled_font_size(11)` |
| 328 | 头部 | `20` | `HudTheme.scaled_font_size(20)` |

### 6.8 TournamentDeckSelect.gd（7 处）

**文件**：`scenes/tournament/TournamentDeckSelect.gd`

| 行号 | 上下文 | 原值 | 改为 |
|------|--------|------|------|
| 186 | 标题 | `22` | `HudTheme.scaled_font_size(22)` |
| 308 | 按钮 | `14` | `HudTheme.scaled_font_size(14)` |
| 327 | 按钮 | `14` | `HudTheme.scaled_font_size(14)` |
| 514 | 按钮 | `15` | `HudTheme.scaled_font_size(15)` |
| 525 | 按钮 | `15` | `HudTheme.scaled_font_size(15)` |
| 536 | 标签 | `14` | `HudTheme.scaled_font_size(14)` |
| 541 | 输入框 | `15` | `HudTheme.scaled_font_size(15)` |

### 6.9 TournamentStandings.gd（2 处）

**文件**：`scenes/tournament/TournamentStandings.gd`

| 行号 | 上下文 | 原值 | 改为 |
|------|--------|------|------|
| 91 | 冠军小标题 | `13` | `HudTheme.scaled_font_size(13)` |
| 96 | 冠军副标题 | `16` | `HudTheme.scaled_font_size(16)` |

### 6.10 .tscn 场景文件中的硬编码字号（4 处）

以下 `.tscn` 文件中存在 `theme_override_font_sizes/font_size` 硬编码：

| 文件 | 行号 | 原值 | 处理方式 |
|------|------|------|----------|
| `TournamentDeckSelect.tscn` | 63 | `24` | 移除 tscn 硬编码，改由 .gd 脚本的 `_ready()` 中设置 `scaled_font_size(24)` |
| `TournamentSetup.tscn` | 63 | `24` | 同上 |
| `TournamentOverview.tscn` | 63 | `26` | 同上 |
| `TournamentStandings.tscn` | 63, 93 | `26`, `34` | 同上 |

## 7. 不改动的文件（明确排除）

| 文件/目录 | 排除原因 |
|-----------|----------|
| `scenes/battle/**` | 对战场景，用户要求不动 |
| `scenes/battle_setup/**` | 对战设置，用户要求不动 |
| `scenes/deck_editor/DeckDiscussionDialog.gd` | 已有完善的 `_portrait_font_size()` 适配系统，不需要改 |
| `scripts/autoload/FontBootstrap.gd` | 只管字体加载，`DEFAULT_FALLBACK_FONT_SIZE` 是兜底值，不影响实际显示 |
| `project.godot` | 不改 content_scale_factor，避免全局副作用 |
| `scripts/ui/battle/**` | 对战 UI 控制器 |
| `scenes/tuner/**` | 训练/调参工具，不面向用户 |

## 8. 回滚方案

所有改动可通过以下方式一键回滚：

1. **`HudTheme.scaled_font_size()`**：删除该方法，全局搜索 `HudTheme.scaled_font_size(` 替换回纯数值。
2. **`.tscn` 文件**：恢复 `theme_override_font_sizes/font_size = 原值`，删除 .gd 中对应的 `_ready()` 设置代码。

由于改动模式完全一致（硬编码数值 → `HudTheme.scaled_font_size(硬编码数值)`），可通过正则批量回滚：

```
# 正则：HudTheme.scaled_font_size\((\d+)\) → $1
```

## 9. 影响汇总

| 指标 | 数值 |
|------|------|
| 新增方法 | 1 个（`HudTheme.scaled_font_size`） |
| 修改 .gd 文件 | 10 个 |
| 修改 .tscn 文件 | 4 个 |
| 总替换点 | ~80 处 |
| PC/Mac 行为变化 | 0 |
| 对战场景改动 | 0 |
| 对战设置改动 | 0 |

## 10. 验证计划

1. **桌面端回归**：在 PC 上运行，逐一进入主菜单 → 设置 → 卡组管理 → 卡组编辑 → 回放浏览 → 锦标赛，截图对比改动前后，确认字号无任何变化。
2. **安卓端测试**：在安卓设备上同样流程，确认字号从原来的 ~9px 物理像素提升到 ~14px 以上。
3. **对战场景隔离**：进入对战和对战设置，确认 UI 布局和字号与改动前完全一致。
4. **运行 `SourceEncodingAudit` 测试**：确认无编码问题。
