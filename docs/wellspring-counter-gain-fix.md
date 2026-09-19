# 水井面具厄诡椪ex与反击增幅器：2026-09-14

## 规则与缺陷

玩家反馈：己方剩余奖赏卡比对手多，水椪携带反击增幅器且只附着水＋一个其他能量，能够使用激流水泵，却不能洗回这两个能量造成备战伤害。

审核输入为实际内置卡 `CSV8C_067`、`CSV9C_190` 和 `CSV8C_186`。水椪第二招为 WCC / 100，可洗回三个能量并造成备战 120。反击在落后奖赏时减少一个无色攻击费用，结晶对太晶宝可梦减少一个任意类型攻击费用。

[日本官方结晶 FAQ](https://www.pokemon-card.com/rules/faq/search.php?freeword=きらめく結晶&regulation_faq_main_item1=all) 明确允许水椪只有两个能量时洗回两能并造成备战 120。[Stellar Crown FAQ](https://pokegym.net/wp-content/uploads/2024/08/Stellar-Crown-FAQ-SV07.pdf) 将其解释为尽量执行，必须实际洗回一些能量。结合反击的出招减费规则，合法出招后适用同样的回能处理；不是把“回三能”永久改成“回两能”。

修复前实测反击配置：出招成功、战斗场 100、备战 0、两张能量仍附着；结晶同配置则为 100 / 120 并回收两张。根因是 `AttackReturnEnergyThenBenchDamage` 仅对结晶做减一特判，并且将能量个数当成卡牌张数。

## 改动

- 删除结晶专属回能特判。实际要求为三能与当前附着能量总个数中的较小值；零能量不能触发备战伤害。
- 出招合法性仍由原费用校验处理：反击未生效、道具被干扰之塔禁用或缺少水能量时，不会因为回能规则而获准出招。
- 普通能量继续一次选择所需张数；存在多能量卡时逐张开新窗口，累计其实际提供的能量个数，再选择备战目标。同一张多能量卡只移动一次。
- 完整选择在伤害前校验；重复卡、过期卡、不足回能及非法备战目标拒绝执行。初始窗口仍可选择不洗回，此时仅造成战斗场伤害；选择回能后必须完成后续选择。
- 双重涡轮等攻击修正在能量移动前计算，因此洗回双重涡轮的这次攻击仍按 80 / 100 结算。备战弱点/抗性不计算，原有备战防伤仍生效。
- 精确注册时注入当前 EffectProcessor，使用当前特殊能量规则。未修改通用费用校验、Host schema 或其他卡的回能规则。

## 验证

Godot 4.6.3 stable / Windows / headless。新增套件最初 5 项中 4 项失败，修复并扩展后 9/9 通过：

- 反击两能完整结算、结晶三能不能只回两能。
- 结晶＋一张双重涡轮、重复/过期/不足选择、不洗回、奖赏相同、干扰之塔、缺水。
- 玩家真实回能选择→备战目标→回合结束。
- 四张普通能量回其中三张、备战防伤后仍洗回能量、零能量的复制效果不打备战。
- 反击、结晶、水能＋双重涡轮三种配置在双方座位通过 UCIS→Host 窗口→提交→重新绑定→规则结算。每座位分别接受 2、2、3 个窗口，合计 14 次选择；重复提交拒绝，无同窗口回退。

| 套件 | 通过 / 总数 |
| --- | --- |
| `test_wellspring_energy_return.gd` | 9 / 9 |
| `test_missing_card_batch_2026_03.gd` | 123 / 127 |
| `test_player_feedback_card_regressions.gd` | 17 / 17 |
| `test_shared_interaction_regressions.gd` | 8 / 8 |
| `test_battle_ui_features_part3.gd` | 83 / 84 |
| `test_csv9c_trainer_stadium_energy_effects.gd` | 44 / 44 |
| `test_a3_external_decision_port.gd` | 19 / 19 |

总计 303/308。5 项无关失败：米立龙空检索提示、土龙弟弟及两项怨影娃娃的模拟投币器未初始化随机事件接口、移动伤害指示物的其他特性访问空属性名。失败没有计入通过，也没有扩展修复这些其他卡牌。已有 NUL 解析提示和场景夹具退出泄漏警告仍保留。

本机日志：临时目录 `ptcg-wellspring-red.log`、`ptcg-wellspring-green.log` 及 `ptcg-wellspring-test_*.log`。

复现新增套件：

```powershell
& 'D:\ai\godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path 'D:\ai\code\PtcgDAP' -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_wellspring_energy_return.gd
```

未进行官方 oracle 差分对局或发布包设备验收，未提交或发布。回滚仅撤销此效果文件、本次注册构造参数、新增测试及旧结晶测试的命名/说明调整；`EffectRegistry.gd` 含其他未提交工作，不能整文件恢复。
