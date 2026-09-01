# 玛俐的礼盒 R55 事务架构验收（2026-08-30）

## 工作包与验收门

- 工作包：把玛俐的礼盒策略从相互竞争的单点规则升级为当前窗口重绑定的事务链，并关闭录像暴露的进化碟、免费展开、愿增猿上场、含羞苞交接和退化时机问题。
- 基线：R54 `5.14.0`，同种子 `2919000–2919049`、每 seed 换座的 clean exact100 为 `47/100`。
- 预先声明的胜率门：至少 `57/100`，即相对基线绝对提升 10 个百分点；invalid/error/fallback/rejection、脏局、回放拒绝均不能由胜率豁免。
- 本证据只覆盖本地 Godot 4.6.1 Windows development Host；不声明 official CABT engine parity、production、Android/A5 或统计显著性。

## 最终精确制品

- package：`dev.bodao-yongzhe.marnies-gift-box@5.15.0`
- 内置文件：`data/ptcgdap/author_strategy_packages/marnies-gift-box-rule-marnie-r55-5.15.0.ptcgai`
- archive bytes：`282898`
- archive SHA-256：`D669C1C756A5D6AD8CAA36A6A91EE7FB6D031A2A00CF9ACC896080E725A6B4ED`
- adapter version：`48`
- adapter bytes：`262142 / 262144`
- scalar rules：`212`
- turn transactions：`17`
- `execution_trusted=false`
- `python tools/ptcgdap/build_marnie_gift_box_r55.py --check` 可确定性复建相同 bytes/SHA。

适配器没有读取 deck ID、source deck ID、benchmark seed 或录像身份来决策；它只使用当前 select window、包内稳定 local printing UID 和 allow-list 公开状态。`CSV1C_123` 是支援者派帕，不是阿尔宙斯；本牌组和事务中没有阿尔宙斯。

## 所有者层修复

1. 早期派帕搜索进化碟事务在当前窗口仍有巨蛋、尖钉镇、雪妖女或诈唬魔等免费且安全的场面发展时不接管；先执行免费动作，再从新 observation 重建和证明事务。
2. 进化碟只在当前 fresh 窗口能证明两个安全目标时绑定；保留两雪童子、雪童子+捣蛋小妖、以及有能量诈唬魔等安全组合，零能量诈唬魔继续禁止。
3. 派帕搜索退化事务增加公开墙伤害时钟：当前攻击为 0、单奖墙且 `opponent.active.remaining_hp <= 80` 才启动；轻伤墙不再被过早退化并放出后排攻击手。
4. 上场优先级采用窄例外链：前四回合、双雪妖女在线、唯一成型长毛巨魔需要保护、愿增猿未供能且对面双奖攻击手已在前台时，含羞苞只作一次 Item-lock 交接；其他中后期双雪妖女场面优先愿增猿，即使愿增猿暂时不能攻击。
5. R55 搜索/上场/攻击事务仍遵守每次选择后旧窗口失效、重新观察、重新证明和重新绑定；没有持久化 option index、旧分数或旧证明。

## RED→GREEN 与 exam

- 新增并先证明 RED：
  - `test_r55_early_item_lock_handoff_protects_the_only_ready_grimmsnarl`
  - `test_r55_search_owned_devolution_waits_for_public_wall_damage`
  - `test_r55_early_tm_search_waits_for_free_board_development`
  - `test_r55_late_sendout_munkidori_does_not_require_attack_ready`
- 最终 exact package 的 focused suite：`21/21`，失败 `0`；首项内部历史/边界语料为 `103/103`。
- 最终日志：`.godot_test_user/logs/focused-20260830-195925.log`
- 日志 SHA-256：`D329C7D4F580C068AB64A848D4950C09FABCE70898E7DB0E4525C97556288868`
- 进化碟三个定向检查在最终 SHA 下另行 `3/3`；免费发展、早期含羞苞、愿增猿无攻击就上场均在最终 SHA 下单项通过。

## Benchmark 结果

| 候选 | exact100 | seat 0 | seat 1 | clean |
|---|---:|---:|---:|---|
| R54 `5.14.0` 基线 | 47/100 | 22/50 | 25/50 | 是 |
| R55 adapter v47 | 45/100 | 21/50 | 24/50 | 是 |
| R55 adapter v48 最终 | 46/100 | 20/50 | 26/50 | 是 |

最终报告：`artifacts/deck_training/marnie_gift_box_5_15_0_r55_free_development_munk_exact100_20260830.json`

- 报告 SHA-256：`F1331ECCFDB488236CF6C247E20249647CFF849221909F57154266E249883D40`
- 100/100 terminal/winner/public replay accepted。
- candidate invalid output、policy error、engine rejection、classic fallback、same-window fallback 全为 `0`。
- Wilson 95% 区间：`36.56%–55.74%`。
- 100 个回放按文件名排序后，以 `filename<TAB>file_sha256<LF>` 聚合的 SHA-256：`7BADE42EC59EF7D0C8E0F5CEC26F63FE626E7BA5A741326053897D744A7AE2C3`。
- 相对 R54：新增 9 胜、丢失 10 个 R54 胜，净 `-1pp`。
- 相对 adapter v47：恢复 8 胜、丢失 7 胜，净 `+1pp`。
- 回归簇 8 seed/16 局：R54 `12/16`、修复前 R55 `4/16`、最终 R55 `8/16`；最终报告 SHA-256 `86751E9CAFF931919DD59A256F5F6EAD1E06427CBF72A69AE20A019BFF7E7A2B`。该小集合只证明四个目标回归恢复，不替代 exact100。

## 结论、缺口与回滚

- 事务架构、当前窗口重绑定和已知录像场景已实现并通过本地 Windows exam；它们确实恢复了四个事务级回归。
- `57/100` 胜率门失败，最终只有 `46/100`；不得把 early exact20 的 `13/20` 或回归簇 `8/16` 解释为整体提升，也不得晋级为胜率冠军。
- package 保持 `execution_trusted=false`；未验证 official CABT、full-engine parity、production、Android/A5。
- 回滚：新对局选择 R54 `5.14.0`，文件 `data/ptcgdap/author_strategy_packages/marnies-gift-box-rule-marnie-r54-5.14.0.ptcgai`，archive `E0F575511DD29CBBBC5ABD9354BB67C78010DFC7C7CA8BD90E196630AD1A21B4`。不热换当前对局，不删除 R55、exam、报告或回放证据。

