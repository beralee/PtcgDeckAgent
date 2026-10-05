# PtcgDAP public status

2026-10-04 AI 领奖卡死修复：原盘第 19 回合的伤害指示物子选择耗尽了界面 20 次行动计数，领奖被统一限额提前拦截。共享调度器改为仅限制新发起的 MAIN 行动，效果子步骤、领奖和强制替换继续结算。8 项专项与 139 项相关回归通过；原盘快照、原多龙 0.29 包和完整战斗场景续局见证奖赏 3→2、手牌 2→3，并进入玩家第 20 回合。仅本地源码，重启生效，未发布。见 [根因、验证与回滚](ai-prize-action-limit.md)。

2026-10-04 大钢蛇再次导致作者 AI 空过：定位到新 `reviewed-gust-v1` 模式未继承旧目录缺项保护；Python/Godot 统一仅将 `unknown_damage_card_uid` 作为可选伤害预测不可用，独立合法规则继续，Base 和隐私门保留。原 0.29 包在二维/三维、前期/满能、大岩蛇/大钢蛇八种完整场景中均出牌/攻击，0 错误/兜底/引擎拒绝。构造局面不冒充原盘，包及发行版本不变，本地源码需重启。见 [修复记录](../evidence/ptcgdap/developer_ai_damage_catalog_gap_20260928.md)。

2026-10-04 本地 Windows 后台策略修复：多龙已选幻影潜袭，却因指示物窗口的调度/回收摘要不一致被误判 `stale_policy_response`，随后 12 秒超时丢失攻击。两侧统一使用当前公开选择状态，真实过期仍拒绝；原盘第 6/8 回合分别恢复后，以原 0.29 包、完整战斗场景和后台策略执行见证 200+60 结算与拿奖赏卡提示。未改策略、未复验整局胜率、未发布；本地源码重启生效。见 [指示物状态与证据](author-public-counter-state.md)。

2026-10-03 开战补充修复：精确多龙 0.29/0.23 原包登记为 Windows 本地开发可执行；异步准备保留开发元数据与市场 ready 记录边界，修复导入后误入市场资格门。策略列表、详情和导入完成提示说明具体阻塞原因。0.29 实际安装、异步准备及真实引擎 Owner 初始化通过；仍为本地 0.6.3 / build 63 源码，重启生效，未导出或发布。见 [兼容性](strategy-runtime-compatibility.md) 和 Forge `work/dragapult-local-start-20261003/RESULTS.md`。

2026-10-03：Windows 本地源码 0.6.3 / build 63 接入 reviewed-gust-v1 与 resource-continuity-v2，原多龙 0.29 包无需改动。导入诊断和策略详情显示最低客户端要求；能力检查不授予生产资格。见 [策略运行时兼容性](strategy-runtime-compatibility.md)。

2026-10-03 expert feedback 0.1.1 / local：四项评价提示和模板、同一示范的反馈草稿恢复、键盘高度布局与保存前 IME 提交、恢复弹窗独占输入已实现，13 项专项通过。独立 APK 覆盖安装/文件回读和限制见 Forge `work/dragapult-expert-save-20261003/RESULTS.md`；未改生产更新器或策略。

2026-10-03 active / local：新增多龙 675701 专家共创开放训练，36 局面、五题短组、真实公开事件记录和 Android 原生文件导出。8 项新模式与 53 项旧训练回归通过。示范保持待审，不冒充 current-window/Host 标签；独立安卓试用包和设备/上传验收单独记录。见 [设计与边界](expert-play-teaching.md)。

2026-09-30：active / local — 卡牌增量更新支持自动/手动检查、签名内容包、按需图片、重启激活、失败回退和对局版本记录。Windows 一次导出 12 步、Android 模拟器一次安装 9 步及完整游戏效果执行验证通过。实现、TDD 与边界见 [设计文档](card-content-updates.md)。未部署生产、未改变作者策略本地执行和精确源摘要门。

2026-09-30 多龙后续本地迭代：新增公开派生 counter_prize_plan fact，Python/Godot 当前指示物子集规划和 7 个跨语言向量同步；原生真实幻影潜袭见证 2+2+2 结算，相关原生组 16/16 通过。没有改变生产策略安装或部署；Forge 的整局 Bench 尚受磁盘准入门阻塞，未声明胜率提升。参见 author-public-decision-api.md。

2026-09-30：用户授权本地公开决策 API 审计与 SDK 同步，未授权本轮上线。Owner 已修复 effective remaining HP，并投影 decision v1 的逐招式成本/逐能量供给、进化与状态、撤退资源、公开全局上下文及显式交互限制；Python/Godot 规则层共享 160 个事实及闭合验证。严格选择边界和 Base 权限保留，未将费用满足冒充当前合法。详见 [接口说明](author-public-decision-api.md)；Forge 侧证据目录为 work/public-decision-api-20260930。原多龙策略逻辑未变，未新增胜率证明、未上传 z/部署。

2026-09-30: User-authorized local public counter-state repair and scoped Forge SDK port completed. The exact Dragapult attack publishes six successive budgets before settling 200 + 60. 64/64 Godot checks pass, including counter, cross-language, cost and privacy regressions; Forge 0.11.0 passes all 950 scenarios, strict Host validation and deterministic double build. No online deployment or new strategy strength is claimed. See [counter state](author-public-counter-state.md).

2026-09-25: User-authorized public attack-cost projection repair has been applied
to the local author Host. Crystal/Bloodmoon discounts now enter the public
payment profile through the same cost modifiers as attack validation. Applied
engine checks pass 45/45; maintained cost / competitive / privacy suites pass
7/7, 19/19 and 5/5. The 44 isolated developer-only matches are clean with
4,881/4,881 successful policy calls. No reliable strength gain, cloud deployment
or new strategy promotion is claimed. See [cost projection](author-public-attack-cost.md).

2026-09-20: Built-in Marnie/Froslass deck 675700 now uses three CSV9.5C/043
Snorunt as explicitly corrected by the user. Exact old-seed migration preserves
newer player edits and original import ordering. Bundled catalog, seed and
printing regressions pass 101/101, plus the seed-digest unit test. See
[printing correction](marnie185-snorunt-printing-correction.md). No game release
or full-match strength claim is made by this change.

2026-09-20: The user-authorized local-author counter-distribution repair routes
sequential-capable adapters through fresh source/count/target windows. Two
focused RED cases reproduced the skipped NUMBER window; after the one-branch
fix, 68 Godot regressions pass, including classic, official, local and pending
adapter paths. Full-game strategy comparisons remain a separate Forge gate.
See [local counter-window validation](local-author-counter-windows.md).

2026-09-20: User-authorized public damage registry refresh covers all 1,011
current card printings, preserving the original 797 entries. Fourteen damage
planner regressions pass, including anniversary Bench cards and retained
unknown/hidden-input rejection. Local full-game verification is recorded
separately by Forge's Gardevoir bench. See [71](71-developer-card-catalog-refresh.md).

2026-09-19: Complete 1,011-card developer catalog refresh and source-delivery checks; see [71](71-developer-card-catalog-refresh.md). Server deployment remains a separate acceptance claim.

2026-09-19: Added the versioned local semantic 128/32 Actor profile, Base-owned single-choice frontier, teacher projection capture and Windows native v4 support for Forge's Marnie BC experiment. Old 24/16 rules/model behavior remains separate. Cross-language and real native probes pass; full-game results are reported independently. See `70-local-semantic-neural-actor.md`. No new production or other-device authority is asserted.

Updated: 2026-09-14

## Current state

- 2026-09-14: Android emulator / Windows exported-runtime strategy parity
  passes 12 paired complete matches (24 games), 636 public decision windows
  and 217 native model inferences per platform. The exact e719 strategy-center
  download supplies six rules matches; a separate fixed-output model fixture
  supplies six model matches. Pending interaction forwarding, sequential
  assignment lifecycle, owner cleanup on close, native inference scheduling/warmup and exported trace
  evidence are repaired. Native Android x86_64 support replaces unstable ARM
  translation on the test emulator; both sides pass twelve hub/native/lifecycle
  checks and clean crash gates. Model fixture guards remain enforced and are
  compared separately from policy failures. The reusable local runner produces
  searchable public-window review reports and fails closed on incomplete runs.
  Physical ARM devices remain a separate acceptance gate. See
  `69-android-strategy-execution-parity.md` and
  `../../evidence/ptcgdap/android_strategy_parity_20260914.json`.

- 2026-09-09: strategy-center responsive/touch layout, bounded original-byte
  import and player-platform admission are implemented for the Windows/macOS/
  Android design. Windows native integer inference and four full player-owner
  matches pass; the model cases perform 20 and 11 real CPU inferences. Existing
  stale-worker guards are exercised, so this is not zero-fallback certification.
  Android ARM64 native libraries and a signed full-project diagnostic APK pass
  native dependency and 16 KB structural checks. Formal export inventory still
  lacks the legacy release-candidate package; macOS builds and Android/Mac
  device acceptance remain separate gates. Battle UI logic and private services
  are unchanged. See `68-ai-strategy-cross-platform-design.md` and
  `evidence/ptcgdap/cross_platform_20260909.md` for scope, evidence and rollback.

- 2026-09-09: additive developer model-input trace capture passed three focused
  Godot tests. This is diagnostic-only, without native BC or production claims;
  see `67-developer-model-trace-evidence.md` for fields, limits and rollback.

- The public repository owns the CABT-compatible policy boundary, Godot host
  adapters, author `.ptcgai` package format, local strategy execution,
  conformance contracts, and public client integrations.
- The aligned player path remains device-local and does not require a hosted
  inference service.
- Confidential Control/Battle Bot implementation, MySQL operations, cloud
  deployment tooling, private tests, release archives and operational evidence
  were separated into `D:\ai\code\PtcgDAP-private-cloud`.
- The public tree contains no `services/ptcgdap_replay` or Alipay Cloudrun
  deployment implementation. A boundary test guards against reintroduction.

## Claims and limits

- Public interface and conformance evidence remains available in this tree.
- Official CABT engine parity is claimed only for explicitly recorded scopes.
- Cloud production status, database state and deployment verification belong to
  the private operations record and are not asserted by this public status.

## Windows battle-setup compatibility (2026-09-01)

- The player-facing battle setup exposes one AI battle surface. Classic AI
  decks and author packages share the AI-opponent picker, while the internal
  `VS_AUTHOR_STRATEGY_AI` owner boundary remains separate.
- User-downloaded author strategies are rendered first, followed by bundled
  author packages and classic AI decks. The bounded picker reserves slots for
  all matching built-in opponents, so 18.0 cannot be displaced by a large
  package catalog; it now admits up to 512 entries and remains searchable.
- Windows landscape setup and the AI-opponent picker use real vertical scroll
  viewports; neither relies on an off-screen fixed list height.
- Focused evidence: `test_battle_setup_ai_versions.gd` 45/45, including a
  real 1280x720 `SubViewport` layout with 96 author strategies and a verified
  non-empty strategy-picker scrollbar range, plus a full-height default setup
  HUD with no initial scrollbar and a fully visible start-battle button;
  `test_author_strategy_battle_setup.gd` 11/11, and the Python setup-boundary
  suite 6/6. The broader AI runner remains 1511/1524; its 13 failures are in
  battle rules, headless prompt handling, strategy behavior, and author-game
  seams outside this setup slice.
- No BattleScene, card-position, card-size, animation, or combat HUD layout was
  changed by this compatibility slice.

## Godot editor scan boundary (2026-09-02)

- Generated `tmp`, machine-local `Godot`, native build, and
  `artifacts/deck_training` roots are guarded by versioned `.gdignore` files.
  Author-package fixtures under `artifacts/ptcgdap` remain visible.
- The guarded cleanup entrypoint removed 652,472 untracked, reproducible cache
  files (about 23.2 GiB) without deleting strategy packages or training
  evidence. Historical isolated test roots are opt-in cleanup targets, while a
  live editor cache is preserved unless explicitly selected.
- A clean headless editor rebuild completed in 21.43 seconds; the following
  warm editor start completed in 6.80 seconds. The filesystem index fell from
  34,684 to 4,424 lines, and imported cache entries fell from 13,798 to 586.
- Focused evidence: `test_project_scan_boundaries.gd` 3/3,
  `test_battle_setup_ai_versions.gd` 45/45, and
  `test_author_strategy_battle_setup.gd` 11/11. The broader package-catalog
  suite is 22/26 in the current dirty worktree because its four Marnie checks
  still reference tracked author-package archives that are already deleted
  outside this cleanup slice.

## Physical ENERGY option projection (2026-09-05)

- The Godot author-policy Host now derives `energy_type_raw` from the current
  physical `CardInstance` candidate when a UCIS `SelectType.ENERGY` window
  exposes deck cards, as Crispin (`CSV9C_196`) does for its first search step.
- Resolution keeps the closed-contract precedence: explicit raw value, action
  type, action Energy card, current candidate card, then attached Energy. Card
  data uses `energy_provides` first and `energy_type` only as a fallback.
- Unknown Energy types still project as `null` and fail closed. Neither the
  Competitive Policy v2 validator nor the A3 native-option validator was
  relaxed, and no battle UI or card layout code was changed.
- TDD evidence: the real Grass candidate first failed with expected `1` versus
  actual `null`; after the Host fix, real Grass/Lightning/Fighting candidates
  project as `1/4/6`, the complete native `0..11` mapping passes, and both A3
  and the full Competitive v2 public-frame validation accept the Crispin
  window. Focused suites pass: `test_a3_external_decision_port.gd` 17/17,
  `test_competitive_policy_v2.gd` 19/19, and
  `test_csv9c_trainer_stadium_energy_effects.gd` 44/44.
- The current local Godot runtime log records a later dual-seat qualification
  for `dev.z.raging-bolt-forge@0.1.1`: both games are terminal and clean, with
  candidate calls/successes `11/11` and `81/81`; policy errors, invalid
  outputs, same-window fallbacks, and engine rejections are all zero. The
  private package archive itself remains outside this public worktree.

## Native option-shape expansion audit (2026-09-05)

- A registry-wide follow-up audit found a second deployed failure family:
  several effects encoded semantic choices such as keep/discard, take/discard,
  return, and swap as opaque strings. UCIS correctly rejected those steps as
  `unsupported_interaction_shape`, but older card tests could still pass by
  calling `execute()` directly and therefore masked the live failure.
- Current binary choices now use typed `[false, true]` candidates and retain
  legacy string decoding only for old replay/context compatibility. Mandatory
  acknowledgement windows use a typed boolean or an explicit coin-result UCIS
  context. This covers Trekking Shoes, Miss Fortune Sisters, the shared
  optional recoil/Stadium/self-return attacks, Tinkatink's Seeking Mountain,
  Gholdengo's Surfing Turn, Rockruff's top-card choice, Team Rocket's Crobat,
  Team Rocket's Orbeetle, and the affected coin-result windows.
- Two scalar projector holes were also closed: direct integer NUMBER and
  SPECIAL_CONDITION candidates now populate `option_number` and
  `special_condition_type`. Values are not coerced into range, so unknown or
  invalid values still fail closed in the unchanged Competitive/A3 validators.
- Facedown opponent-Prize position choices now compile with explicit UCIS
  semantics. Competitive v2 keeps the indistinguishable position choice in
  deterministic Base ownership; only the reviewed A3 private-research port
  may receive the position-only shape. No hidden card identity enters a public
  package frame.
- Red/green evidence: the new focused option-shape suite first failed 3/3 with
  `unsupported_interaction_shape`, then passes 5/5. The A3/Competitive suites
  pass 17/17 and 19/19. Focused real-card semantics pass for Trekking Shoes,
  Gurdurr, Rockruff, Bombirdier, Gholdengo, Alolan Exeggutor, Cetitan/Dondozo,
  Team Rocket's Orbeetle, Miss Fortune Sisters, and the opponent-Prize reveal
  attack. Trekking Shoes' existing battle-UI presentation/commit regressions
  also pass 3/3; no UI-layer source was changed.

## Crispin and related option recheck (2026-09-08)

- Re-ran the physical Energy mapping and strict validator regressions. Added
  a real `CSV9C_196` fixture for each seat: all three compiled windows
  (TO_HAND_ENERGY, ATTACH_TO, ATTACH_FROM) pass through the Host and A3
  submit/rebind lifecycle; each seat records three accepted selections and
  zero policy errors, invalid outputs, fallbacks or engine rejections. The
  effect resolves the selected Energy to hand and a different type onto the
  selected Pokemon. The equivalent frozen Competitive frame also passes its
  full validator after excluding A3-only position/debt fields.
- Found and fixed a remaining string-candidate window in the shared defender
  attack-lock effect, including Team Rocket's Murkrow (`CSV10C_135`). Its
  `unsupported_interaction_shape` RED now becomes a typed ATTACK window with
  the defender identity and attack index. Invalid typed selections do not
  default to the first attack; old name-based contexts remain compatible.
- Found and fixed an Energy projection edge case: a source Pokemon's
  `energy_type` could shadow its attached Energy type. The RED was a Dark
  Pokemon holding Grass Energy projecting 7 instead of 1. Card-based Energy
  extraction now accepts Energy cards only; missing Energy remains null.
- Focused verification: A3/Host 19/19, UCIS shapes 7/7, Competitive v2 19/19,
  CSV9C trainer/Energy effects 44/44, CSV10C 131-135 6/6, English Crispin 1/1,
  and portrait Crispin stale/empty-confirm regression 1/1 (97/97 total).
  Some Godot test processes still emit startup Unicode warnings and teardown
  resource-leak diagnostics; this is not a clean resource-lifetime gate.
- Scope: local Host/option and effect integration only. No full developer
  package qualification, official engine parity, release or device acceptance
  is claimed. The earlier 0.1.1 qualification receipt alone cannot prove that
  Crispin executed, because the supplied bug report says that version carried
  a Crispin quarantine rule. Evidence and commands are recorded in
  `evidence/ptcgdap/crispin_option_recheck_20260908.md`.

## Rollback

The pre-split private migration manifest and all moved local artifacts remain
in the adjacent private worktree. The public Git history before the merge is
unchanged and can be used to revert the public checkpoint if needed.

The battle-setup compatibility slice can be rolled back independently by
reverting the BattleSetup scene/script, its focused regression tests, and the
public local execution-gate cleanup. It does not require reverting battle UI or
engine code.

The editor-scan boundary can be rolled back by reverting the three `.gdignore`
markers, `.gitignore`, its regression test, and the cleanup script. Deleted
machine-local caches are not source artifacts and can only be regenerated by
rerunning the corresponding editor or test workflows; retained training
evidence is unaffected.

The physical ENERGY projection fix can be rolled back independently by
reverting the candidate-card resolution in
`PtcgDAPAuthorDevelopmentBattleOwner.gd` and its focused A3/Competitive
regressions. No validator, card effect, or UI rollback is required.

The option-shape expansion slice can be rolled back independently by reverting
the typed effect candidates, scalar Host extraction, hidden-position Base/A3
split, and `test_ucis_effect_option_shapes.gd`. It does not require changing a
validator or battle UI file.

The September 8 recheck fixes can be rolled back separately: remove the
Energy-card-type guard and restore the defender attack-lock effect with its
associated new regressions. Preserve the pre-existing Crispin candidate-card
fix and the other uncommitted option-shape changes. No strategy package or
validator was changed by this recheck.
