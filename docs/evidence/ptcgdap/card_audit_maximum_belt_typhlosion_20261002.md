# 极限腰带装备当回合伤害反馈核查

日期：2026-10-02。结论：当前工作区未复现玩家描述的 290 → 次回合 340；没有修改游戏规则实现，也没有发布客户端或卡牌更新。

## 卡牌和规则

使用实际 `CardDatabase` 卡牌：阿响的火暴兽 CSV10C/030、阿响的冒险 CSV10C/208、比克提尼 CSV9C/023、极限腰带 CSV7C/189、多龙巴鲁托ex CSV8C/159、基本火能量 CSVE1C/FIR。弃牌区四张冒险，场上一只比克提尼，对手战斗场为无额外保护的多龙。

- [火暴兽官方卡面](https://asia.pokemon-card.com/ph/card-search/detail/19583/)：搭档爆破 40 + 每张弃牌区冒险 60。
- [比克提尼官方卡面](https://asia.pokemon-card.com/ph/card-search/detail/16586/)：火属性进化宝可梦对对手战斗宝可梦的招式伤害 +10。
- [极限腰带官方卡面](https://asia.pokemon-card.com/ph/card-search/detail/17616/)：对对手战斗场宝可梦 ex 的招式伤害 +50，没有等待一回合的条件。
- [阻碍之塔官方卡面](https://asia.pokemon-card.com/my/card-search/detail/12635/)：消除双方宝可梦道具效果。因此此场面在塔有效时是 290，塔离场后为 340。这只是可能解释，截图没有提供竞技场或完整对局，不能归因到该玩家。

本机用户缓存中四张相关宝可梦/道具的类型、效果 ID 与内置卡一致；这不能代表反馈玩家的安装状态。

## 执行证据

扩展 `tests/test_maximum_belt_effect.gd`，新增四个回归用例：

1. 真实手牌装备流程：装备前预览 290，装备后预览 340，当回合实际伤害 340，多龙进入弃牌区。
2. 两个玩家座位都不提前调用伤害预览：装备后首次攻击均为 340。
3. `BattleScene` 控件测试替身承载真实手牌选择、战斗槽装备和招式交互方法：首次攻击实际 340。此项不是设备触控或完整渲染验收。
4. 阻碍之塔有效时实际伤害 290；同回合移除塔后立即为 340，无需等下回合。

已有非 ex 不加伤、备战区不加伤、双重涡轮能量叠加等五项也通过。测试夹具遵循 `_build_deck` / 对局恢复时的宝可梦效果注册前置条件。调查中的 `expanded` 报告曾因手工夹具遗漏该前置步骤而得到 100（缺少冒险的 240），补齐夹具后通过；这不是反馈中的缺少腰带 50，也未据此修改引擎。

验证命令：

```powershell
python scripts/tools/run_test_matrix.py --suite-script res://tests/test_maximum_belt_effect.gd --output .godot_test_user/maximum_belt_20261002/final
```

Godot 4.6.1，隔离进程与用户目录：**9 passed / 0 failed / 0 skipped**。最终报告在 `.godot_test_user/maximum_belt_20261002/final/report.json`。`git diff --check` 通过。UI 与引擎从当前场面查询道具，没有发现装备回合延迟或伤害结果缓存。

## 待补证据与回退

需要玩家客户端版本和该局录像/对战日志，重点核实攻击瞬间的竞技场、道具附着对象及多龙卡牌版本。当前不能断言截图是规则误解，也不能宣称玩家问题已修复。

本次仅增加上述测试和本文件。回退时只移除这四个测试及其 `_make_reported_typhlosion_battle` 夹具，不覆盖工作区其他修改。
