# Godot v18 玛俐的礼盒 1.9.0 录像驱动验收

## 身份与范围

- 录像：`match_20260827_234816_561101/match.json`，SHA-256 `79C9B9FD4AEC21504C3145E7DBFA5AF24E4CF0FD4BE45FC430C4DB84159E187B`。
- 候选：`dev.bodao-yongzhe.marnies-gift-box@1.9.0`。
- Archive SHA-256：`BDC7C0969D6F4A4F5CC94C480E3CE2C19F4C2542AB1902C16DEC51AE1333DB20`，120,933 bytes。
- 内置文件：`data/ptcgdap/author_strategy_packages/marnies-gift-box-rule-marnie-r9-1.9.0.ptcgai`。
- 范围：Windows 本地 development gate、public current-window 策略和 developer-only trace；不是 production、官方 CABT parity、Android 或赛事批准。

## Owning-layer 修复

1. Forge adapter 把庞克泵感精确数量绑定到真实 `assignment_source`，删除虚构的五能量分支。
2. Python/GDScript `PublicDamagePlanning` 只从当前 `main/main_action` 合法选项统计唯一愿增猿能力来源；嵌套 fresh 窗口只使用正在进行的公开事务债务。
3. capability registry 从 `CSV9.5C_006` 标准 effect `930f07ef177d44b0e1084343b66b13af` 登记 `attack.bench_heal.v1`、后排治疗 100，并按公开能量/费用判断是否 ready。
4. 公开 facts 增加最优 transfer/gust 稳定目标、攻击窗口、奖赏、剩余债务与当前攻击伤害；transaction candidate 以 `is_transfer_best`/`is_gust_best` 绑定，不再以最低序号偶然起事务。
5. `AIStepResolver` 在实际应用前记录愿增猿 count 与 target 两个 fresh child decision；记录不进入 public observation 或策略输入。

## 可复核结果

- Forge `check`：94/94 strict 场景，确定性双构建 exact SHA 一致。
- Forge 仓库全量 62/62，SDK snapshot manifest `--check` 通过。
- Python `tests.ptcgdap.test_public_damage_planning`：12/12。
- Godot `PublicDamagePlanning`：9/9；100 次 sealed hot path P95 2.463 ms。
- Godot `AuthorStrategyInteractionContractV2`：11/11，包含 count→target child trace。
- Godot `MarnieGiftBox190`：2/2，验证 exact gate、sealed handle、reviewed policy、60 卡物化以及错误 SHA/user/Android 负门。
- 基准工具先按旧 replay helper 参数 RED，修复为显式传入 candidate/opponent deck ID、seat、seed、opponent owner 后，同一批种子重新起跑；失败的首局未计入战绩。
- 同种子 `1199000–1199009`、双方换座 package-only A/B：1.8.0 为 6–14（30%），1.9.0 为 7–13（35%）；40/40 合法终局、40/40 public replay 接受，1.9.0 1,130/1,130 policy calls 成功且 invalid/error/stale/classic fallback/engine rejection 全零。
- 1.9.0 的 19 个庞克泵感 `assignment_source` 窗口全部满足 desired count=实际选择数（2×12、1×2、3×1、0×4）；精确两奖 Counter Catcher/Boss/gust target 分别命中 3/5/3 次，Shadow Bullet `attack_target` 命中 15 次。
- 1.9 报告：`artifacts/deck_training/marnie_gift_box_1_9_0_vs_ogerpon_20_final.json`，SHA-256 `F7126ED9231C9AB231BF328287E5EF68AB320C21595588FA37F71A33000EBDDC`；1.8 对照 SHA-256 `4F9788AD9EF9F5C65087C8B51BB3BEC37C719D9E5B1865B7FFBE6F0A6FB8846A`。
- 运行较大的历史 `OgerponAuthorVsRuleMatrix` 时，1.9.0 exact pin/bind 已通过；同套件仍有若干早期 R0–R6/旧 Ogerpon archive integrity 失败，属于工作树既存历史候选漂移，未被本证据记为 1.9.0 全套通过。

## 回滚

- 直接回滚：`dev.bodao-yongzhe.marnies-gift-box@1.8.0`，SHA-256 `209FA7EDF7321A142F1B8A25E44667D44E49AF728E799AFF112716951E72DFD1`。
- 1.7.0 的牌表不是精确 `646600`，不作为推荐构筑回滚。
