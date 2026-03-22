# 开始先后攻选项设计

## 目标

在对战设置页面新增一个“开始先后攻”选项，支持两种模式：

- `随机先后攻`
- `玩家1卡组先攻`

当选择“随机先后攻”时，保持现有行为：

- 进入对战后由 `GameStateMachine.start_game(..., force_first = -1)` 触发一次投硬币
- `BattleScene` 继续接收 `coin_flipped` 信号并播放现有投币动画

当选择“玩家1卡组先攻”时，行为改为：

- 对战启动时传入 `force_first = 0`
- `GameStateMachine` 直接将 `first_player_index` 和 `current_player_index` 设为 `0`
- 不触发投硬币，不发出 `coin_flipped`，战斗场景也不播放投币动画

## 非目标

- 本次不开放“玩家2卡组先攻”给 UI 使用
- 不改动现有回合规则、首回合限制、Mulligan、放置流程
- 不修改 AI 行为，AI 只消费最终先攻结果

## 现状

- `GameManager.first_player_choice` 已存在，语义为：
  - `-1` = 随机
  - `0` = 玩家1先攻
  - `1` = 玩家2先攻
- `BattleScene._start_battle()` 已经把这个值透传给 `GameStateMachine.start_game(...)`
- `GameStateMachine.start_game()` 已经支持 `force_first`
- 缺失的是：
  - 对战设置页面没有 UI 可改这个值
  - 没有回归测试覆盖“强制玩家1先攻时不投硬币”

## 方案

### 1. 对战设置页

在 `BattleSetup.tscn` 中新增：

- `FirstPlayerLabel`
- `FirstPlayerOption`

在 `BattleSetup.gd` 中：

- 初始化两个选项：
  - `随机先后攻`
  - `玩家1卡组先攻`
- 页面加载时根据 `GameManager.first_player_choice` 回填当前选择
- 点击开始时写回：
  - 选中随机 -> `GameManager.first_player_choice = -1`
  - 选中玩家1卡组先攻 -> `GameManager.first_player_choice = 0`

### 2. 启动流程

不新增新的启动参数，也不改 `BattleScene` 的主流程。

依赖已有链路：

- `BattleSetup` 写入 `GameManager.first_player_choice`
- `BattleScene._start_battle()` 读取它并传给 `GameStateMachine.start_game()`
- `GameStateMachine` 根据 `force_first` 决定是否投硬币

这样改动面最小，也能保持随机模式完全不变。

### 3. 兼容性

- 内部仍保留 `first_player_choice = 1` 的表达能力，避免将来做“玩家2先攻”时还要再改数据结构
- 当前 UI 只暴露两项，不影响已有调用者

## 测试策略

### 设置页测试

验证：

- 对战设置页能显示先手选项
- 切到“玩家1卡组先攻”后点击开始，会把 `GameManager.first_player_choice` 写成 `0`
- 切回随机时写成 `-1`

### 引擎测试

验证：

- `start_game(..., force_first = 0)` 后：
  - `first_player_index == 0`
  - `current_player_index == 0`
  - `coin_flipper.flip()` 没有被调用

### 全量回归

跑现有 headless Godot 全量测试，确认：

- 随机模式没有回归
- 强制玩家1先攻不会破坏 setup / main phase / 首回合限制
