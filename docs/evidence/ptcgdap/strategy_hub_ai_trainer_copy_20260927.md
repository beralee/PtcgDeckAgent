# Strategy hub AI trainer copy — 2026-09-27

The strategy hub now calls strategy creators `AI训练家` in its navigation,
onboarding, rankings, profiles, ownership labels, empty states and status text.
The introduction invites players to create their own AI strategy, challenge the
ladder and face more human players. Its steps cover registration, Forge creation
and local testing, signed package upload and qualification, then sharing the
strategy. The existing mobile guidance recommends a computer for creation and
testing. Existing player-provided names and service identifiers remain verbatim.

## Validation

The existing scene and onboarding assertions were updated to the new wording.
The following isolated UI suites pass **40/40**, with no failures or skips:

| Suite | Passed |
| --- | ---: |
| StrategyHubDesktopFlow | 4 |
| StrategyHubDeveloperEntry | 4 |
| StrategyHubLadderPresentation | 6 |
| StrategyHubResponsive | 4 |
| StrategyHubScene | 22 |

Command:

```powershell
.\scripts\tools\run_godot_tests.ps1 -Runner ui -Suite 'StrategyHubDeveloperEntry,StrategyHubScene,StrategyHubResponsive,StrategyHubLadderPresentation,StrategyHubDesktopFlow' -UserDataRoot .godot_test_user/ai_trainer_copy_20260927 -ReportDirectory .godot_test_user/ai_trainer_copy_20260927/reports
```

Local report: `.godot_test_user/ai_trainer_copy_20260927/reports/report.json`.
Actual Godot 4.6.1 OpenGL captures were inspected at 1600×900, 900×1800 and
390×844, under `.godot_test_user/ai_trainer_copy_20260927/ai-trainer-<width>.png`.
The copy remains readable with wrapping and the portal button stays in the
first viewport at all three sizes. The capture process reported no stderr.
Scoped whitespace checks pass, and the two scene sources contain no remaining
`开发者` or `作者` UI labels.

## Scope and rollback

This is shared Godot UI copy validation, including simulated Android/Web entry
behavior; it is not device/export, engine parity or strategy-strength acceptance.
The portal URL, account behavior, package contracts and battle routing are unchanged.
No external portal, private service, account, release or deployment was modified.

Rollback only these wording substitutions in `StrategyHub.gd`, `StrategyHub.tscn`
and the two updated test expectations. Preserve the pre-existing offline
performance condition in `StrategyHub.gd` and all other workspace changes.
