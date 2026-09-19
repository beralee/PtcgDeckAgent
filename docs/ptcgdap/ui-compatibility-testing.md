# UI compatibility regression gate

## Ownership and behavior

StrategyHub owns touchscreen gestures for its complete workspace, including the
outer embedded-settings ScrollContainer. Embedded Settings does not independently
consume those events. A gesture records its initial target, finger and scroll
offset; vertical dragging cancels a candidate click/focus/horizontal-slider edit.
Release without a matching press, cancellation, a second finger and synthetic
mouse echoes cannot activate another control. Scene/workspace/modal transitions,
resize and focus loss cancel the old gesture. Real mouse and trackpad events stay
in Godot's existing GUI path. The shared legacy bridge and desktop layouts are
not replaced by this change.

The StrategyHub title/subtitle are centered. Narrow portrait text scales to the
available logical width, with minimum readable text sizes; desktop metrics remain
unchanged. Model picker and strategy detail overlays retain exclusive input scope.

## Run locally (PowerShell 7)

```powershell
./scripts/tools/run_ui_compatibility.ps1
./scripts/tools/run_ui_compatibility.ps1 -IncludeWeb
./scripts/tools/export_android_ui_review.ps1 -Architecture arm64
./scripts/tools/run_android_ui_compatibility.ps1 -Serial YOUR_DEVICE_SERIAL -ApkPath .tmp/ui_compatibility/ui-review-arm64.apk
```

Use an explicitly selected, dedicated Android test device. The device script
installs the APK, restarts it and dismisses the first-use fullscreen coachmark;
it does not uninstall or erase application data. Its normalized tap coordinates
target the current portrait menu at 1080 × 2400. Layout changes require updating
these coordinates and inspecting the screenshots. Missing navigation or an
incorrect scroll target fails the run. Do not run multiple exports concurrently
in this worktree: Godot reads the shared export preset. Review export restores
the original preset bytes in `finally`; signing/export logs stay local/private.

An optional `-Architecture x86_64` review build exercises Android UI without ARM
translation. It has no native model library for that architecture and is strictly
UI-only, not a player release or an inference acceptance test. Production exports
remain ARM64 with no review/probe arguments.

## Coverage and evidence

`tests/ui/UiCompatibilityHarness.gd` instantiates the real scene in an isolated
SubViewport and injects actual viewport input events. Profiles cover Android phone,
narrow Web phone, Web tablet, Windows, macOS and desktop Web dimensions. Profiles
simulate geometry/input semantics; they do not emulate those operating systems.

The focused suite covers settings dragging; dragging from buttons, text fields
and sliders without side effects; exact-once tab activation; synthetic mouse echo;
multitouch/cancel/orphan release; modal/background isolation; checkbox and range
semantics; focus loss; native input focus; mouse wheel; clipping; and centered,
single-line headings. Existing hub, battle setup, portrait and Web input suites
are included to detect desktop and adjacent-scene regressions.

Browser E2E exports the actual Godot Web build. Chromium uses browser touch input
via CDP and desktop mouse wheel. WebKit drag uses DOM touch events through the
canvas listener because Playwright exposes no equivalent native drag API; this
does not establish physical iOS Safari acceptance. The landscape project is
explicitly skipped for this portrait-specific case.
The focused browser gate also checks navigation back to the menu and real WebKit
API-key DOM entry. Run `run_web_ui_e2e.ps1` without `-TestFilter` for the broader
existing application suite. That broader suite currently has an unresolved
DeckManager DOM search-editor detachment, recorded separately from this gate.

Android evidence requires both an `AISettingsTab` activation and a drag whose
target is exactly `AISettingsWorkspace` with an offset increase over 100 logical
pixels. Probe output contains control names and movement only, never field values
or credentials. Screenshots before/after, APK SHA-256 and structured results live
under `.tmp/ui_compatibility/android/`. The probe is disabled in ordinary builds.

TDD evidence is kept in ignored local logs: input-matrix-red.log captures the
toggle failure before the fix; input-matrix.log captures narrow-Web heading wrap
before the width adjustment; the final input suite passes. Two old battle-setup
portrait tests were corrected to use actual portrait SubViewports and available
content bounds, rather than assuming a 1000-pixel popup inside 998 pixels of space.
No production battle-setup changes were needed for those test corrections.

Run this gate before releasing UI/input changes. A failed suite returns nonzero;
inspect JSON reports and browser traces rather than treating export success as UI
acceptance. Full native macOS/trackpad and physical Android-device acceptance must
still run on those devices before claiming universal compatibility.

## Rollback

Revert only the new scoped gesture router, StrategyHub input routing/title/narrow
portrait metrics, embedded Settings input ownership/metrics and associated tests.
Preserve unrelated pre-existing changes in these files. No package/data migration,
policy contract or inference implementation changes are involved.
