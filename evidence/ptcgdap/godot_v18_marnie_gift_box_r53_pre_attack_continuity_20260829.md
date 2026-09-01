# 玛俐礼盒 R53：攻击前连续性、后期愿增猿与含羞苞边界

日期：2026-08-29

## 结论

Windows 本地开发策略 `dev.bodao-yongzhe.marnies-gift-box@5.13.0` 已晋级。归档为 170,498 bytes，SHA-256 `E7539DB5639B236365A801476F685C22BD45B10F3E9C09A46960EBC60063EBED`，策略 ID 为 `bodao-yongzhe.marnies-gift-box.competitive-v2-rule-marnie-r53`。

固定 seed `2919000–2919049`、每 seed 换座的 100 局结果为 43–57，比 1.9.0 的 31–69 提升 12 个百分点。100/100 对局正常终局、winner 存在且公共回放接受；6000/6000 次候选策略调用成功，3967 次引擎提交，policy error、invalid output、classic fallback、same-window fallback、engine rejection 均为 0。

该结果只授予本地 Windows development package、公开窗口 exam 和同种子 Godot benchmark 证据，不授予 production、Android/A5、官方 CABT 整局 engine parity 或统计显著性声明。

## 录像诊断

玩家录像 `match_20260829_093731_374046` 共 370 条记录，完整性为 verified：

- detail SHA-256：`52F48F3A8173CE009F5D1E8203C720FBC06A18589CE1E0FF6DAE26BF4EF6AA5D`
- chain root SHA-256：`9560525706F869D01490F8498D992B526FDE44D59E6CD19B0785E02912E276FC`
- 终局：turn 10，player 0 获胜

根因均位于 data-only 公开策略层，不在卡效实现：

1. 庞克泵感旧计数把“攻击所需”或“当前窗口可取”当目标，未表达每只场上玛俐宝可梦恰好 2 能；assignment target 也必须逐个 fresh window 排除已达 2 能目标。
2. 雪妖女、愿增猿资源、奇树在攻击选项出现后分数不足，导致策略把合法攻击误当成回合已完成。
3. 后期含羞苞的两个语义被混在一起：它不应在昏厥送出和宝芬搜索中抢核心位，但已经在前台且仍能封锁时，也不应被无条件硬撤。
4. 诈唬魔/捣蛋小妖送出补线不能压过已经存在的长毛巨魔；只有窗口里没有长毛巨魔候选时，才允许下位进化线压过雪童子等纯养成位。
5. 愿增猿的阿德雷脑必须在有公开可转伤害时先于非终结攻击，并且不能因为己方只剩最后一张奖赏而失去优先级。

## 最终策略边界

- 庞克泵感只取场上所有玛俐宝可梦到 2 能的总欠能；同 UID 的不同实体分别计数，已到 2 能的实体不再接收。
- 非终结攻击前依次完成可执行的雪妖女进化、愿增猿找恶能/手贴、阿德雷脑转伤和适用的奇树补手干扰；每次选择后重观察，不保存旧索引。
- 后期送出优先级为能立即工作的愿增猿、长毛巨魔、无长毛巨魔候选时的诈唬魔/捣蛋小妖、其他养成位；含羞苞最低。
- 已在前台的含羞苞不会仅因 turn 大于等于 5 被强制撤退；Base 的立即终结动作仍保留最终保护权。

## RED/GREEN exam

Forge 完整场景集为 121 项：

- 5.12.0 对最终套件为 118/121，失败点正是场上含羞苞强撤、近就绪长毛巨魔被中段压过、最后奖赏阶段愿增猿未先转伤。
- 5.13.0 为 121/121，确定性双构建一致。
- GREEN 报告：`D:\ai\code\ptcg-strategy-forge\work\marnies-gift-box-rule-marnie-r43\build\marnies-gift-box-rule-marnie-r53-check3-report.json`，SHA-256 `1A890CFB84C5FF04D9E1C7508D999CDB6715F0C04C3830DBA85953F0535ACDE7`。
- RED 报告：`D:\ai\code\ptcg-strategy-forge\work\marnies-gift-box-rule-marnie-r43\build\marnies-gift-box-rule-marnie-r53-red3-report.json`，SHA-256 `8D77E91295BE564DC5D35FB971E72F1858A6008BA860D0A2B52C516230AD4572`。

Godot 最终语料 `tests/ptcgdap/exams/marnie_gift_box_match_20260829_093731_374046_r53.json` 包含 18 个公开决策场景，SHA-256 `A9AE303621407753C46B795D05ED36DE557C5F9F61A8B19E3C158912F174504E`。18/18 场景各重复 5 次为 90/90；随后确定性、公开信息和 observation/window hash 绑定复核再次执行 90 次，全部通过。测试日志 `.godot_test_user/logs/focused-20260829-133324.log` 的 SHA-256 为 `21F4E464C0DD549692544371DB1A6990D2B69D6CE3BB3AB29E38BF7B40AE27F5`。

终态等价门同时复跑 3/3：五类终态各重复五次，前台精确、后备/手牌/弃牌区按无序多重集比较；缺少一张弃牌的负控按预期失败。日志 `.godot_test_user/logs/focused-20260829-134329.log` 的 SHA-256 为 `F207C1786A231875FFDD804BDA47A1BFD36FAAA40B268ED1AEA99CBA9B351B0A`。

Python Competitive Policy v2 定向合同为 21/21，通过同 UID 多实体精确欠能、数量上限和 current-window 绑定。

## Benchmark 与回放

- 九个已知翻转座位：5.13.0 为 9/9 胜；报告 `artifacts/deck_training/marnie_gift_box_5_13_0_flip18_20260829.json`，SHA-256 `A3D603432A00A2E6BD3E15D645DC69B76C0044E47ABF67F510AFAB55B49E1BD8`。
- 最终 100 局：`artifacts/deck_training/marnie_gift_box_5_13_0_final_exact100_with_replays_20260829.json`，SHA-256 `49D60350D65BF978D0D59DC5DD915E67D9B4F40575FF00F0E5AA7B045A8FABAC`。
- 座位拆分：candidate seat 0 为 21/50，seat 1 为 22/50；Wilson 95% 区间为 33.73%–52.78%。
- 100 个公共回放位于 `artifacts/deck_training/marnie_gift_box_5_13_0_final_exact100_replays_20260829/`。按文件名排序后，以 `文件名<TAB>文件 SHA-256`、LF 连接所得清单聚合 SHA-256 为 `225E8CE4BE2D5C202453A988D77D1B213E6590E102AE75AE9284AC1BE677B403`。

## 已知独立缺口与回滚

`test_reviewed_author_strategy_packages.gd` 为 5/6；唯一失败仍是既存、无关的 `dev.beralee.v18.marnie-grimmsnarl` actual owner frame `invalid_development_frame`。玛俐礼盒的 exact admission、Competitive v2 owner 路由和 BattleSetup 可见/可开战项均通过。失败日志 `.godot_test_user/logs/focused-20260829-133752.log` 的 SHA-256 为 `AECBF61C4123A5A534E6E04D46CE3AD4E9E669B6405E15B69267E93F23CC5BD1`；本工作包没有借机修改该无关包。

新局可回退到冻结的 5.3.0（`863EE8C8…A3A3`），或原始 1.9.0 基线（`BDC7C096…3DB20`）。当前进行中的 match 不热换包；所有失败候选、基线、exam 和公共回放继续保留用于审计。
