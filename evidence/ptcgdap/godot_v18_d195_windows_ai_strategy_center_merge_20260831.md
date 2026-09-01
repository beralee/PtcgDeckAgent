# D195 Windows 首页 AI 设置并入策略中心证据

## 验收范围

本工作包只处理 Windows 首页与非战斗策略中心导航：

1. 首页不再并列显示“AI 策略中心”和“AI 设置”；
2. 策略中心从三个工作区调整为四个，顺序为“策略广场 / 本地策略 / 对战录像 / AI 设置”；
3. 普通入口默认进入策略广场；旧设置导航进入末尾 AI 设置；
4. AI 设置复用原保存、连接测试、模型和性格页面，不复制配置 owner；
5. 不修改 BattleScene、战斗卡牌 UI 或动画路径。

## TDD RED

- `focused-20260831-233239.log`：第四页签/工作区不存在，workspace 回归在读取末页索引时失败。
- `focused-20260831-233242.log`：首页/导航测试显示默认工作区 handoff 为空，旧设置路径尚未合并。

## 实现结果

- `MainMenu.tscn/MainMenu.gd` 删除独立 `BtnSettings`，首页按钮组按 6 个动作布局。
- `GameManager.gd` 为策略中心增加一次性初始工作区 handoff；`goto_settings()` 现在进入 `settings`，消费后默认恢复 `catalog`。
- `StrategyHub.tscn/StrategyHub.gd` 增加第四页签和滚动工作区，默认策略广场；设置 PackedScene 仅在首次进入末页时加载。
- `Settings.gd` 增加嵌入模式：保留原配置逻辑，只隐藏重复背景、页面标题和内部返回按钮；设置页隐藏后不抢占其他工作区输入。

## GREEN 证据

| Lane | 结果 | 日志 |
|---|---:|---|
| StrategyHub 完整 focused suite | 19/19 | `.godot_test_user/logs/focused-20260831-233958.log` |
| Settings 文案/控件原行为 | 1/1 | `.godot_test_user/logs/focused-20260831-234010.log` |
| Settings 竖屏布局/固定操作区 | 1/1 | `.godot_test_user/logs/focused-20260831-234037.log` |
| 首页竖屏布局 | 1/1 | `.godot_test_user/logs/focused-20260831-234058.log` |
| 首页 Windows 横屏状态与动作区 | 1/1 | `.godot_test_user/logs/focused-20260831-234104.log` |
| 首页触控入口 | 1/1 | `.godot_test_user/logs/focused-20260831-234110.log` |

合计 24/24。完整 StrategyHub lane 的公开录像 fixture 仍会打印既存 NUL Unicode warning，但对应 replay lazy-load 测试通过；本工作包没有修改该 fixture 或录像 owner。

## 变更文件 SHA-256 快照

| 文件 | SHA-256 |
|---|---|
| `scenes/main_menu/MainMenu.gd` | `85E2F574254080B50472A96290B94AE987B35D29D2C9B49FE378697EE37BA5C7` |
| `scenes/main_menu/MainMenu.tscn` | `D0F2159CB4A4C3D275942EB548D67D1A48E370FACD73884289ACCAEDE47BB3D4` |
| `scenes/settings/Settings.gd` | `367DA72FAE89C531BB68B6745A02805E9134141652084B585BDD48D590F2DBC6` |
| `scripts/autoload/GameManager.gd` | `3BB9D3C78ADCA205C260AD0EEB4E419C3A54CCCFD695F70F301241D75D9048A0` |
| `scenes/ptcgdap_strategy_hub/StrategyHub.gd` | `1AC4FEBEC5D356F8D7349D9E1D13F8AABAD37849CD66A5526D67C1C5DB8FA14D` |
| `scenes/ptcgdap_strategy_hub/StrategyHub.tscn` | `52F56CB45235EB1CB770F22CC2DE2713D7085BD0B9F2430F2C97DEC26484298B` |
| `tests/ptcgdap/godot/test_strategy_hub_scene.gd` | `4217A0A6F69544DF83E84321C01CD2FFE16AB24516B22FAE6B2286DB470831D6` |

这些是脏工作树当前文件快照，相关文件包含本工作包之前的用户/并行改动；它们不是独立提交边界。

## 回滚与未关闭门

- 源级回滚可恢复首页按钮、独立 Settings 路由和原三页签；不需要迁移或删除用户 AI 配置。
- 设置页加载失败只影响第四工作区，另外三个工作区仍可用。
- 未执行玩家可见 Windows 最终像素检查；headless 场景回归不提升该门。
- 不声明 official CABT、engine parity、production、Android/A5。
