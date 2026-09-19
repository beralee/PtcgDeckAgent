# PC strategy discovery and install flow — 2026-09-15

## Follow-up: shared DeepSeek tab label

The user requested that every platform's Strategy Hub settings tab read `DeepSeek`. The shared scene default and both responsive presentation assignments now use that exact label. Workspace routing and the settings content are unchanged. The existing responsive assertion failed first (`focused-20260915-001418.log`), then the responsive suite passed 4/4 (`focused-20260915-001433.log`) and workspace navigation passed 1/1 (`focused-20260915-001437.log`). These cover narrow/wide and portrait transitions in the common PC/Android/Web scene; no platform artifacts were rebuilt. Rollback only these three label assignments and their updated assertions.

## Player flow

The Strategy Hub now opens on the strength ranking. PC rows retain the server ordering, score, sample count and provisional label, with a prominent filled HUD action for one-click download/install and a secondary details action. File import is visible above both discovery and the installed library. Installed strategies expose Start Battle and card details; deletion is behind Manage. Start Battle retains the exact package reference and opens the existing battle setup with that strategy selected.

Desktop page copy no longer displays filesystem paths, service configuration/status chatter, duplicate library headings and the large import/settings instruction panel. Errors remain visible. Detailed match/rating history is expandable; the compact detail dialog retains the download action at its bottom. Both desktop libraries use a single outer scroll, avoiding clipped local cards and nested scrollbars. Existing downloaded-deck previews and the HUD delete modal remain in place.

## Owning implementation

Changes are in `scenes/ptcgdap_strategy_hub/StrategyHub.gd` and `StrategyHub.tscn`. The live public leaderboard does not include an installable reference, while the release profile does. The new quick-install action requests the selected profile first, checks the returned release identity, then uses the existing validated downloader and strict catalogue byte installer. It requires no extra player click. Missing device packages, request failure and retry are handled explicitly; duplicate pending clicks cannot queue duplicate downloads. A freed source row cannot trigger a late automatic download.

Installed-state actions are resolved from the exact current local record, on both list and detail buttons. They retain platform admission checks and re-resolve before battle setup. There is no policy/runtime or private-service change.

## Validation

Runner: `scripts/tools/run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/ptcgdap/godot/<suite>.gd`; isolated APPDATA. Logs under `.godot_test_user/logs/`.

| Suite | Passed | Log |
| --- | ---: | --- |
| test_strategy_hub_desktop_flow | 4 | focused-20260915-000914.log |
| test_strategy_hub_scene | 22 | focused-20260915-000917.log |
| test_strategy_hub_responsive | 4 | focused-20260915-001000.log |
| test_strategy_hub_deck_preview | 2 | focused-20260915-000658.log |
| test_strategy_hub_delete_modal | 2 | focused-20260915-000830.log |
| test_strategy_hub_import_lifecycle | 8 | focused-20260915-000833.log |

The new flow tests failed before implementation (`focused-20260914-235826.log`). They cover default ranking/import visibility, byte-install handoff, in-place start conversion, exact reference, no redownload on start, profile resolution, mismatched response rejection, duplicate input, retry and real desktop library layout/import navigation. Existing assertions were updated for the intentional labels and single-scroll layout. Startup Unicode NUL warnings predate this task.

Actual Godot OpenGL renders were inspected at 1600×900, 1280×720 and 900×1800 using read-only snapshots of the documented public leaderboard and top release profile. Probe: `tmp/strategy_discovery_probe.gd`; screenshots `tmp/strategy-discovery-1600.png`, `tmp/strategy-discovery-1280.png`, `tmp/strategy-discovery-900.png`, `tmp/strategy-library-1600.png`, `tmp/strategy-discovery-detail.png`. No live strategy was installed/deleted for this visual check. Scoped diff whitespace check passed.

## Scope and rollback

This is local Godot UI/flow validation, not new engine parity or packaged-device acceptance. No executable/APK was exported, no commit or push was made, and neither adjacent repository was modified.

Rollback only this task's presentation helpers, quick-action scene nodes, install-to-start action synchronization, quick profile resolution, row presentation and updated/new flow assertions. Preserve the earlier exact deck preview, retreat routing and HUD delete fix, as well as unrelated existing workspace edits. Restoring the old flow makes PC users navigate via details and then manually find the installed strategy again.
