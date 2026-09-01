# PtcgDAP public status

Updated: 2026-09-01

## Current state

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
- Built-in 18.0 opponents are rendered before author packages and cannot be
  displaced by the previous shared 80-entry cap. The bounded picker now admits
  up to 512 entries and remains searchable.
- Windows landscape setup and the AI-opponent picker use real vertical scroll
  viewports; neither relies on an off-screen fixed list height.
- Focused evidence: `test_battle_setup_ai_versions.gd` 41/41,
  `test_author_strategy_battle_setup.gd` 11/11, and the Python setup-boundary
  suite 6/6. The broader AI runner remains 1511/1524; its 13 failures are in
  battle rules, headless prompt handling, strategy behavior, and author-game
  seams outside this setup slice.
- No BattleScene, card-position, card-size, animation, or combat HUD layout was
  changed by this compatibility slice.

## Rollback

The pre-split private migration manifest and all moved local artifacts remain
in the adjacent private worktree. The public Git history before the merge is
unchanged and can be used to revert the public checkpoint if needed.

The battle-setup compatibility slice can be rolled back independently by
reverting the BattleSetup scene/script, its focused regression tests, and the
public local execution-gate cleanup. It does not require reverting battle UI or
engine code.
