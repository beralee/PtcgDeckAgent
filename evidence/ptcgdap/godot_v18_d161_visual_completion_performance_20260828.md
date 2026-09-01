# Godot v18 D161 animation completion performance evidence — 2026-08-28

> **REJECTED / ROLLED BACK BY D163:** Windows player-visible acceptance found that operated field cards moved downward and changed size. The stable-binding, equality-shortcut, deferred completion-batch, field-only foil, and draw/prize completion changes documented below were removed on 2026-08-28. This file is historical evidence only and must not be cited as the current implementation or as a passed UI-geometry gate. Current evidence: `evidence/ptcgdap/godot_v18_d163_battle_ui_geometry_rollback_20260828.md`.

## Scope and gate

This work package owns only live battle presentation completion. Acceptance requires executable evidence that animation callbacks no longer synchronously repeat whole-field/full-UI work, that committed state is still repainted before AI continuation, and that cancellation/timeout recovery remains deterministic. It does not change game rules, author policy input/output, select-window indexes, execution tickets, public replay schema, or package identity.

Status: `rejected_rolled_back_by_D163_after_failed_Windows_UI_geometry_acceptance`.

## Reproduction evidence

The player-visible author match `match_20260828_215722_938052` ran from 21:57:20 to 22:04:04 and completed normally. Its native replay has 411 events: 146 `action_resolved`, 59 `choice_context`, 204 `state_snapshot`, one start, and one end. `detail.jsonl` is 19,471,148 bytes. This closes D158's earlier lack of a complete visible rerun, but the player's report that animation endings still stutter is a failed visual acceptance, not a pass.

Input hashes:

- `native_replay_manifest.json`: `159C73ADBA28ED6C2EA3AAB41EA1CEDD3B1A4C58DB463D47EA8BCCA53F1AD40A`
- `summary.log`: `4DFB325125562862222B98680231953E7AC46E302F6B259724950E356F9471A0`

## Earliest owner and root cause

The earliest owner is the Godot presentation/UI completion path:

1. Each damage/heal/status/KO callback synchronously called `refresh_field` before starting the next visual.
2. Field refresh visited up to 18 slot views. Unchanged cards were rebound with `setup_from_instance`, re-resolved texture paths, rebuilt status icon rows, and allocated new styles.
3. The same completion then recursively traversed the whole scene tree to reapply foil materials.
4. Draw/discard, prize exchange, and prize flip callbacks synchronously invoked hand or full-UI reconciliation on the Tween's final frame. Prize exchange could perform both a full refresh and another hand refresh.

This explains why D158 reduced policy/logging overhead but did not remove the visible hitch at the animation boundary.

## Implemented boundary

- `BattleVisualSequenceController` retains affected field events until the serial visual queue drains, then requests one batch resync. The AI visual gate remains closed until the batch callback completes.
- Live `BattleScene` performs the batch on the next idle frame. Timeout still repaints the committed state and stale generations remain invalid.
- Draw/discard completion, prize exchange, and prize flip completion move their reconciliation off the final Tween frame. Prize exchange consumes the pending hand reconciliation inside one full refresh.
- `BattleCardView` and `BattleDisplayController` reuse the same `CardInstance + display_mode`, and short-circuit unchanged status, layout, selection, badges, tilt, style, disabled state, and foil state.
- Field-only completion foil sync iterates `_slot_card_views`; it no longer recursively scans the entire UI tree.
- Only completion work at or above 8,000 microseconds emits `battle_visual_completion_profile_v1`; no per-frame diagnostic stream was added.
- Timing rollback for a new match: `PTCGDAP_VISUAL_COMPLETION_PROFILE=immediate_v1`. This restores synchronous completion while retaining correctness and identity reuse.

## Executable evidence

| Focused suite | Result | Coverage |
|---|---:|---|
| `test_battle_visual_sequence_controller.gd` | 16/16 | serial queue, coalesced resync, cross-frame idle/AI gate, timeout, stale callbacks |
| `test_battle_display_controller.gd` | 17/17 | unchanged field identity and status avoid complete rebuild |
| `test_battle_visual_runtime.gd` | 7/7 | real Tweens, portrait/landscape cleanup, Bench KO resync |
| `test_author_live_performance_contract.gd` | 6/6 | deferred completion, field-only foil, rollback contract |
| `test_battle_ui_features_part3.gd` | 84/84 | real BattleScene effects, selected Bench damage/KO and field UI |
| `test_switching_ticket_animation.gd` | 9/9 | four-phase prize exchange and final state |
| `test_battle_hand_surface_reconciliation.gd` | 16/16 | identity-preserving hand reconciliation and visual barrier |
| Total clean focused gate | **155/155** | local Windows structural and focused integration |

Broader dirty-worktree lanes were observed but are not waived or attributed to D161: `test_battle_ui_features_part2.gd` was 88/92 with existing Trekking Shoes UCIS/Nest Ball failures; `test_ai_baseline.gd` was 99/101 with existing mulligan-window and interactive-ability failures; architecture audit was 4/5 because `BattleSceneRuntime.gd` already exceeds its 3,000-line baseline. Direct draw-reveal, prize, AI visual-gate, and completion tests in those lanes passed.

## Limits

No post-fix player-visible full match has been completed yet, and headless tests cannot establish rendered frame-time p95. This evidence therefore reaches only `local Godot Windows structural + focused integration`. Android/A5, production, official CABT/Kaggle alignment, full-engine parity, and strategy strength are unchanged.
