# 移动端竖屏输入、坐标与安全区架构加固设计

日期：2026-07-18

## 1. 背景与目标

当前移动端 UI 同时存在三套历史机制：Godot 的触摸转鼠标、`GameManager` 的全局按钮扫描、以及战斗场景内针对卡牌和拖动的专用触摸桥。iOS Web 还会在浏览器不能锁定方向时旋转整棵战斗 UI。各机制分别可用，但边界重叠后产生三个系统性风险：

1. 全局按钮扫描不理解战斗模态层，可能越过 `mouse_filter = IGNORE` 的隔离规则触发底层按钮。
2. 旋转画布下，部分手写命中使用屏幕坐标，部分使用战斗逻辑坐标，卡牌画廊可能误选或漏选。
3. Web Shell 只给启动遮罩使用 CSS 安全区，游戏 Canvas 仍覆盖刘海、灵动岛和 Home Indicator 区域。

本设计的目标是建立三条不可交叉的架构契约，并用回归测试固定：

- 输入所有权契约：战斗输入归战斗场景所有，通用全局桥不得进入战斗场景。
- 坐标空间契约：所有手写 Control 命中都由统一几何工具完成屏幕到本地的逆变换。
- 安全区契约：平台外壳负责物理安全区，Godot 布局只负责安全 Canvas 内部的视觉间距。

## 2. 非目标

- 不重做 Godot 原生 GUI 事件系统。
- 不改变现有卡牌拖动、长按、鼠标桌面操作的业务语义。
- 不为 Android 开启 edge-to-edge；Android 继续使用导出预设的系统安全窗口。
- 不把设备安全区数值散落到每个场景脚本。

## 3. 架构

### 3.1 移动输入所有权

`GameManager` 只保留非战斗页面的兼容性按钮桥。检测到活动 `BattleScene` 后，它必须立即清空候选按钮并退出，不消费 `ScreenTouch`，也不处理触摸产生的鼠标回声。

战斗场景继续使用：

- Godot `emulate_mouse_from_touch` 驱动普通 GUI 控件；
- `BattleSceneRuntime` 驱动卡牌画廊、手牌拖动、备战区落点等专用交互；
- 各模态控制器负责事件代际、回声抑制和底层按钮 `mouse_filter` 状态。

这样战斗模态隔离只存在一个权威，不再被全局树扫描绕过。作为防御性约束，通用按钮桥也不得桥接 `MOUSE_FILTER_IGNORE` 的按钮。

### 3.2 统一指针几何

新增无状态 `PointerGeometry` 工具，提供：

- `screen_to_control_local(control, screen_position)`：用 `get_global_transform_with_canvas().affine_inverse()` 将视口屏幕坐标转换到 Control 本地坐标；脱离 SceneTree 的测试节点回退到 `get_global_transform()`。
- `control_contains_screen_point(control, screen_position)`：在 Control 本地矩形内判断命中，不使用旋转后语义不稳定的 `get_global_rect()`。
- `control_visible_point(control, screen_position)`：同时检查自身和所有裁剪祖先的本地矩形。

对话框普通卡牌、分配来源卡牌、分配目标卡牌都通过此工具判断。调用方不再关心当前是否旋转，旋转、缩放和 CanvasTransform 都由逆矩阵自然处理。

现有 `_screen_position_to_battle_local()` 继续服务战斗棋盘逻辑坐标；它不再被误用为 Control GUI 命中工具。两者职责分别是“战斗逻辑空间”和“具体控件本地空间”。

### 3.3 平台安全 Canvas

Web Shell 在 `:root` 定义四个 CSS 安全区变量，并将游戏 Canvas 固定在：

```text
left   = safe-area-inset-left
top    = safe-area-inset-top
right  = safe-area-inset-right
bottom = safe-area-inset-bottom
```

Canvas 的 CSS 宽高由扣除四侧 inset 后的可交互区域决定。Godot 的 resize policy 读取 Canvas 的 client rect，因此引擎视口天然不包含危险区域。启动遮罩仍覆盖全屏，并在内部使用安全区 padding。

此方案优于把 CSS 像素通过 JSBridge 传给各场景：

- 不存在 CSS 像素、设备像素和 Godot 逻辑像素的二次换算误差；
- 地址栏、PWA、横竖屏导致安全区变化时由浏览器布局和 Canvas ResizeObserver 统一触发；
- 所有场景、动态弹窗和未来页面自动获得同一安全边界。

Android 原生继续由 `screen/edge_to_edge=false` 提供物理安全窗口。Godot 内的 `safe_rect` 和 `portrait_horizontal_safe_inset` 明确定义为安全 Canvas 内部的视觉排版间距，不再承担设备刘海含义。

## 4. 事件流

### 4.1 Android 战斗点击

```text
ScreenTouch
  -> GameManager 检测 BattleScene，退出且不消费
  -> BattleScene 专用触摸处理（若适用）
  -> Godot GUI / 触摸转鼠标
  -> 当前最上层 Control
```

模态层下方按钮即使仍在树中，也不会再被全局扫描主动触发。

### 4.2 iOS Web 旋转画布卡牌命中

```text
屏幕触点
  -> PointerGeometry
  -> 目标 ScrollContainer 本地坐标并检查裁剪
  -> BattleCardView 本地坐标
  -> 选择控制器
```

无论战斗根节点是否旋转 90 度，命中过程完全相同。

### 4.3 iOS Web 安全区

```text
CSS env(safe-area-inset-*)
  -> 安全 Canvas client rect
  -> Godot viewport resize
  -> 现有 responsive layout
```

## 5. 测试策略

必须新增并通过以下测试：

1. 活动 BattleScene 存在时，全局触摸桥不能记录或触发任何 Button。
2. `MOUSE_FILTER_IGNORE` Button 不能被通用桥接。
3. 旋转 90 度的战斗根节点内，对话框画廊能命中可见卡牌且不会命中裁剪区外卡牌。
4. Web Shell 的 Canvas 四边必须直接引用安全区变量；仅启动遮罩出现 `safe-area-inset` 不算通过。
5. 原有 GameManager、竖屏布局、战斗 UI、Web 导出测试全部通过。
6. Android APK 导出、安装、启动成功，主界面截图正常，logcat 无崩溃。

## 6. 完成标准

- 战斗场景不存在全局按钮扫描路径。
- 旋转画布的对话框卡牌命中不再使用 `get_global_rect()` 与原始屏幕坐标直接比较。
- iOS Web 游戏 Canvas 四侧均受 CSS 安全区约束。
- 聚焦回归和 Android 模拟器验证全部通过。
