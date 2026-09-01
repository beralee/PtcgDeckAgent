# Godot v18 D163 battle UI geometry rollback evidence — 2026-08-28

## Scope and acceptance gate

This work package removes the D161 performance changes that altered battle-card binding and animation-completion UI timing. The acceptance gate is source-level restoration plus executable regression evidence that every committed field repaint performs an authoritative card-view rebind. D158 live pacing/recording/log batching and D162 startup catalog caching remain in place.

Status: `implemented_focused_tested_visible_Windows_battle_confirmation_pending`.

## Player-visible failure and timeline

The D161 battle UI edits were written on 2026-08-28 between 22:14 and 22:24. The player then reported that, on Windows, cards that had been operated moved progressively downward and changed size. The player explicitly rejected performance work in the battle UI layer.

The failed visible acceptance overrides D161's headless 155/155 result. The old tests proved queue and callback structure, but did not prove stable Windows `Control` geometry after real interaction and layout passes.

## Rejected owner changes

D161 introduced the following UI-affecting shortcuts, all removed by D163:

- `BattleDisplayController` skipped `setup_from_instance` when `CardInstance + display_mode` appeared unchanged and reused a panel style signature.
- `BattleCardView` skipped repeated layout, status, selection, disabled, tilt, badge, info, foil, and style work when values compared equal.
- `BattleVisualSequenceController` retained field-resync events until queue drain and delegated one deferred completion batch to the scene.
- draw/discard and prize completion moved reconciliation across an idle-frame boundary.
- field completion synchronized foil only for `_slot_card_views` instead of the established whole-tree path.

These shortcuts could preserve transient or platform-specific UI state because the authoritative refresh no longer rebuilt the complete view on every committed repaint.

## Restored behavior

- Every occupied or empty field slot again calls `setup_from_instance` on every committed repaint.
- Field slot size, battle status, selection, disabled state, hint, badges, tilt, and panel style are reapplied without D161 equality/signature short-circuits.
- Damage/heal/status/KO and timeout completion again repaint committed field state per completed visual event.
- Draw/discard, prize exchange, and prize flip use the pre-D161 completion order.
- Foil synchronization at field completion again follows the established full-tree path.
- `PTCGDAP_VISUAL_COMPLETION_PROFILE` and its deferred-completion implementation are removed.

## Test-first evidence

The new display regression uses a recording `BattleCardView` and refreshes the same occupied slot twice. Under D161 it failed as expected:

```text
FAIL test_field_refresh_rebinds_unchanged_cards_to_restore_authoritative_ui_state
Expected setup count: 3; actual: 1
```

After the rollback, the same test passed. The author live performance contract was changed from approving D161 shortcuts to rejecting their source signatures.

| Focused suite | Result | Coverage |
|---|---:|---|
| `test_battle_display_controller.gd` | 17/17 | authoritative repeated field rebind, Windows hand/layout regressions |
| `test_battle_visual_sequence_controller.gd` | 14/14 | pre-D161 per-event committed-state resync, queue/timeout/stale callback safety |
| `test_author_live_performance_contract.gd` | 6/6 | preserves D158 and forbids D161 UI shortcuts |
| `test_battle_visual_runtime.gd` | 7/7 | real Tween cleanup, Bench KO repaint, portrait/landscape anchors |
| `test_switching_ticket_animation.gd` | 9/9 | prize exchange four-phase presentation and final state |
| `test_battle_hand_surface_reconciliation.gd` | 16/16 | draw/search/discard hand barrier and identity reconciliation |
| `test_battle_ui_features_part3.gd` | 84/84 | BattleScene effects, field interactions, Bench KO and fixed prize positions |
| Total | **153/153** | local structural and focused integration |

All seven processes exited with code 0. The headless runner emitted its existing resource-leak diagnostics after some suites; no test assertion failed.

## Preserved work and rollback

D158 remains active: `author_realtime_v1`, `player_compact_v1`, visual-first action capture, decision-boundary public replay sampling, and bounded batched native/author logs. D162 `cached_v2` startup catalog behavior also remains active. No package, deck, replay, rule, policy, select window, execution ticket, public observation, or external repository was modified by D163.

D163 is itself the safety rollback. D161 must not be restored without explicit approval plus a player-visible Windows position/size gate. Future performance work should start at measured non-UI owners such as policy computation, recording, resource prewarm, or data loading and must not alter battle UI binding, geometry, or completion semantics.

## Limits

The focused evidence reaches `local Godot Windows UI-authoritative-refresh contract + focused integration`. Headless tests cannot close pixel-level Windows acceptance. A fresh visible Windows game process and a complete battle with repeated card operations are still required. Android/A5, production, official CABT/Kaggle alignment, full-engine parity, and strategy strength are unchanged.
