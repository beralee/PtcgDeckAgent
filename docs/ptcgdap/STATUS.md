# PtcgDAP public status

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
