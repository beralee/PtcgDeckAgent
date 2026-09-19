# Strategy Hub installed-package delete HUD — 2026-09-14

## Finding and owning change

Installed strategy deletion used a Godot `ConfirmationDialog` Window. Hub typography explicitly skips Windows, and the page-level `NonBattleGestureRouter` did not route touches to that Window. This reproduces the incorrect UI/input ownership; it does not establish an Android OS-level deadlock.

Replace only the strategy-delete confirmation with an in-page HUD Control: opaque dark panel, cyan border, readable adaptive text, cancel and red-accented confirm buttons, safe-area bounds and a background input blocker. The visible modal owns the touch route. Cancel, `ui_cancel`, page back and Android go-back notification close it and clear the pending reference/gesture. Confirmation copies the exact reference and clears/hides the modal before yielding for deletion; duplicate confirmation is ignored. Success and failure restore page controls. Existing catalogue deletion semantics remain intact.

Files: `scenes/ptcgdap_strategy_hub/StrategyHub.gd`, `StrategyHub.tscn`; dedicated regression `tests/ptcgdap/godot/test_strategy_hub_delete_modal.gd`. Existing scene assertions now inspect the Control and its message label. The responsive test had an obsolete two-column discovery expectation; it now verifies the existing one-column discovery plus two-column installed-library behavior, with no corresponding production-layout change.

## Validation

Run each using `scripts/tools/run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/ptcgdap/godot/<suite>.gd` with isolated test APPDATA.

| Suite | Result | Log under `.godot_test_user/logs/` |
| --- | --- | --- |
| test_strategy_hub_delete_modal | 2 passed | focused-20260914-235424.log |
| test_strategy_hub_scene | 22 passed | focused-20260914-235307.log |
| test_strategy_hub_deck_preview | 2 passed | focused-20260914-235459.log |
| test_strategy_hub_import_lifecycle | 8 passed | focused-20260914-235524.log |
| test_strategy_hub_responsive | 4 passed | focused-20260914-235543.log |

Focused tests failed against the native Window before the fix (`focused-20260914-234740.log`). Final checks cover HUD ownership/readability, actual touch cancel/confirm, back action/go-back notification, immediate modal release, duplicate confirmation, failure recovery and subsequent tab interaction. Fake catalogue deletion never removes player data. Existing startup Unicode NUL warnings remain.

Godot OpenGL captures were inspected at 900×1800, 390×844 and 1600×900; panel and buttons fit each viewport with readable HUD colors. Probe: `tmp/strategy_delete_modal_probe.gd`; captures: `tmp/strategy-delete-900.png`, `tmp/strategy-delete-390.png`, `tmp/strategy-delete-1600.png`; log `tmp/strategy-delete-preview.log`. Final probe exits normally. Scoped `git diff --check` passed.

## Boundary and rollback

This establishes local Godot UI/input behavior, not physical Android acceptance. No APK was built/installed, no strategy policy contract changed, and no commit/push/private service change was made.

Rollback only the package-delete Control subtree, delete-theme/layout/input/back handling and delete handlers introduced for this fix, plus the dedicated regression and corresponding scene-test adaptation. Preserve the preceding strategy deck preview, other workspace changes, and catalogue removal implementation. Reverting restores the original native-dialog defect.
