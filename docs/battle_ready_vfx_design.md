# Battle Ready VFX Design

## 目标

战斗中除了攻击动画，还需要在关键宝可梦进入“战术 ready”状态时播放短动画，帮助玩家快速理解局面已经成型。Ready VFX 只做视觉提示，不改变任何规则结算、行动合法性或 AI 决策。

## 架构原则

- `BattleReadyVfxEvaluator` 只读取 `GameState`，返回当前满足条件的 trigger。
- `BattleReadyVfxRegistry` 维护 `rule_id -> BattleReadyVfxProfile`，profile 固定动画资源、大小、时长和颜色。
- `BattleReadyVfxController` 只负责非阻塞播放，overlay 使用 `Control.MOUSE_FILTER_IGNORE`。
- `BattleSceneRuntime` 在 `_refresh_ui()` 完成布局刷新后检查 ready trigger。
- `_ready_vfx_seen_keys` 使用 `<rule_id>:p<player>:<slot><index>:c<card_instance>:t<turn>` 去重，避免每次 UI 刷新重复播放。
- Ready VFX 不参与攻击动画 handover 等待逻辑。

## 已实现场景

| # | rule_id | 触发目标 | 程序判定 |
|---|---|---|---|
| 1 | `budew_opening_item_lock_ready` | 含羞苞 `CSV9.5C_004` | 当前玩家主阶段，含羞苞在战斗区，前两个全局 turn window 内。 |
| 2 | `dragapult_phantom_dive_ready` | 多龙巴鲁托ex `CSV8C_159` | 当前玩家主阶段，多龙巴鲁托ex 在战斗区，第二招费用可支付，对手有备战目标可放伤害指示物。 |
| 3 | `lugia_double_archeops_ready` | 洛奇亚VSTAR `CS6aC_103` | VSTAR 未用，弃牌区至少 2 张始祖大鸟 `CS6aC_113`，备战区至少能放下 2 张。 |
| 4 | `iron_hands_amp_ready` | 铁臂膀ex `CSV6C_051` | 场上铁臂膀ex 已连接 4 个有效能量，额外奖赏攻击费用可支付。 |
| 5 | `terapagos_cavern_board_ready` | 太乐巴戈斯ex `CSV9C_175` | 零之大空洞生效，太乐巴戈斯ex 在战斗区，己方备战数达到 6+，同盟打击费用可支付。 |
| 6 | `palkia_vstar_acceleration_ready` | 起源帕路奇亚VSTAR `CS5bC_051` | VSTAR 未用，弃牌区有水能，己方有可填水能目标。 |
| 7 | `gholdengo_big_swing_ready` | 赛富豪ex `CSV4C_089` | 赛富豪ex 在战斗区，攻击费用可支付，手牌基本能量数量足以按 50 倍数覆盖对手战斗宝可梦剩余 HP。 |
| 8 | `charizard_infernal_reign_ready` | 喷火龙ex `CSV5C_075` | 喷火龙ex 本回合进化，特性未使用，牌库有基本火能，己方有合法火能目标。 |
| 9 | `miraidon_generator_line_ready` | 密勒顿ex `CSV1C_050` | 密勒顿ex 在场，特性未用，备战区未满，并且牌库有雷系基础宝可梦或手牌电气发生器加牌库雷能路线。 |
| 10 | `regigigas_ancient_wisdom_ready` | 雷吉奇卡斯 `CS5.5C_056` | 场上齐五柱，弃牌区有能量，古代智慧未使用。 |
| 11 | `radiant_greninja_concealed_cards_ready` | 光辉甲贺忍蛙 `CS6.5C_020` | 光辉甲贺忍蛙在场，附着能量足以支付月光手里剑 `WWC`。 |
| 12 | `ceruledge_discard_energy_ready` | 苍炎刃鬼ex `CSV9C_034` | 苍炎刃鬼ex 在战斗区，第一招费用可支付，弃牌区能量达到 5 张。 |
| 13 | `roaring_moon_frenzied_ready` | 轰鸣月ex `CSV6C_096` | 轰鸣月ex 在战斗区，发狂深挖费用可支付，对手有战斗宝可梦。 |
| 14 | `archaludon_metal_bridge_ready` | 铝钢桥龙ex `CSV9C_138` | 铝钢桥龙ex 本回合完成进化，并且附着能量足以支付金属防卫 `MMM` / 220。 |

## 资源策略

本轮只为含羞苞 ready 使用专属生成素材：

- `assets/textures/vfx/ready_budew_item_lock/sheet-transparent.png`

其余 ready 场景复用已有属性和英雄攻击 VFX 的 impact/burst 素材，统一通过 ready profile 控制大小、时长、锚点和闪光色，避免一次性引入大量未经验证的新图。

## 测试闭环

测试文件：`tests/test_battle_ready_vfx.gd`

覆盖内容：

- 14 个 rule profile 全部注册。
- 每个 profile 的 `burst` 图片可从 `res://assets/textures/vfx/` 加载。
- 含羞苞专属素材尺寸、帧数、时长、放大倍率固定。
- 14 个 ready 场景的正向触发条件。
- VSTAR 已用、Area Zero 缺失、赛富豪手牌能量不足、铝钢桥龙特性已用等关键负向门槛。
- `_check_ready_vfx_triggers()` 去重，overlay 不拦截输入。

验证命令：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\tools\run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_battle_ready_vfx.gd
powershell -ExecutionPolicy Bypass -File scripts\tools\run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_attack_vfx_controller.gd
powershell -ExecutionPolicy Bypass -File scripts\tools\run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_script_load_regressions.gd
```
