# Android strategy hub layout validation — 2026-09-13

## Changes

- Strategy hub converts the physical Android safe area through viewport stretch before applying logical canvas margins. The observed 1080 × 2400 emulator surface uses a 1600 × 3555 logical canvas; the previous identity transform incorrectly reduced the content width to 1080 logical pixels.
- Portrait text accounts for logical canvas width. Local strategy rows stack their titles, readiness badges and actions; embedded AI settings also scale text, inputs and the SpinBox editor.
- Strategy/author details use a modal on all platforms. Close, status and download/import controls remain outside the scrolling detail content. Touch input is routed to the modal while it is open.
- Android and Web hide the replay workspace and representative replay controls; Android/Web cannot navigate to the hidden workspace. Desktop replay behavior remains available. Existing recording files are not deleted.

## Validation

- Godot 4.6.1: strategy hub suite 21/21; AI settings portrait tests 17/17; export preset suite 22/22. Focused mobile readability regression rerun after the final local-title adjustment passed.
- Android emulator `Medium_Phone_API_36.1`, 1080 × 2400: installed an ARM64 review APK, loaded the live strategy leaderboard, opened a strategy, downloaded/imported it successfully and confirmed its presence in the local strategy list. Checked modal scrolling with its import action retained, local strategy layout and embedded AI settings.
- The emulator required host GPU rendering and explicit OpenGL startup arguments. The earlier Vulkan-to-OpenGL fallback failed before UI startup. Review APK arguments are isolated from the normal export preset. This is UI/import acceptance, not an AI battle or broad device-parity claim.
- Web visibility is covered by the platform-configuration regression; this task does not publish or claim browser-device acceptance.

Local screenshots, test logs and APKs are under `.tmp/strategy_hub_android/`. Signing credentials remain in ignored Godot local configuration and are not included in this document. The deliverable is `PtcgDeckAgent-android.apk`; `PtcgDeckAgent-arm64-review.apk` is the emulator review build with OpenGL/diagnostic startup arguments.

## Mobile simplification follow-up — 2026-09-14

- Portrait hub prioritizes Discover, Downloaded and Settings. Routine connection diagnostics, duplicate descriptions, author boards and detailed match/rating histories no longer occupy the phone's primary surface. Errors remain visible.
- Strategy details use a shorter centered modal with a persistent primary action. Recent win rate uses the number of games in its own performance sample, rather than the lifetime game count.
- Exact installed releases expose Start; local cards expose Start and a collapsed Manage action. Download validation and package identity checks remain unchanged.
- Strategy launches pass a one-shot exact package reference into battle setup after saved preferences are restored. Missing/untrusted packages cannot silently select a replacement or bypass execution admission. The player's saved deck remains selected.
- When arriving from a strategy on a portrait screen, optional mode, scenery, effects and music controls are under More settings. Readiness errors remain visible.
- Final focused suites: StrategyHub 22/22; author-strategy battle setup 12/12. Regression coverage includes compact visibility, visible errors, exact-version entry overriding saved mode, missing/untrusted rejection and expanding optional settings.
- Android emulator review: inspected Discover, Downloaded, compact details and compact setup; selected the installed v5.13.0 package and entered the actual battle opening selection. This is startup/UI acceptance, not a completed AI-match evaluation. Screenshots are `compact-discover-final.png`, `compact-local-final.png`, `compact-detail2.png`, `compact-setup-final.png`, `compact-battle-final.png` in the ignored local artifact directory above.
- One review launch terminated in a native Scudo/GLThread error on the ARM64-translating emulator; relaunch completed the UI and battle-entry flow. Its cause is not established by this UI change, and broad emulator stability is not claimed.

## Touch compatibility follow-up — 2026-09-14

- Added the scoped gesture owner and the reusable [UI compatibility gate](ui-compatibility-testing.md). StrategyHub settings now scroll through their outer viewport; dragging from a button/input does not click/focus it. Modal isolation, synthetic click suppression, gesture cancellation and desktop mouse behavior have focused coverage.
- Final headless gate: 118 tests passed across seven suites. Six geometry/input profiles include Windows/macOS desktop dimensions; these are not native macOS runs.
- Actual exported Web build: strategy settings scrolling passed on Chromium desktop, Chromium touch and WebKit DOM touch (three passing cases; landscape explicitly skipped for this portrait-specific case).
- Expanded final browser gate: seven passing cases, five intentional profile skips. Covers the three scrolling cases, three main-menu/settings round trips and WebKit API-key DOM entry. Old settings test navigation was updated to the current StrategyHub entry and waits for scene readiness before locating the settings tab.
- Dedicated Android API 36.1 emulator, native x86_64 UI-only review build: entered Settings through the visible tab and swiped the actual `AISettingsWorkspace` by 723 logical pixels. Before/after screenshots and structured evidence are in `.tmp/ui_compatibility/android/`. The title is centered and the settings save/test actions can be reached.
- ARM64 translation on this separate x86 emulator repeatedly aborted in Godot/Android native allocation (`Scudo`, corrupted chunk header). Native x86 UI review succeeds, but this does not establish the ARM64 crash cause or physical-phone stability. The x86 review does not contain a compatible model runtime and must not be distributed as a player build.
- Normal ARM64 release was rebuilt with empty extra startup arguments and the existing release signing certificate. APK SHA-256: `653CDA2E7AF686D62529E41110D87C981447A6FB80956FB9B91524A2BBE698CF`. No deployment/publishing was performed.
- An additional, broader browser run found a DeckManager search DOM editor detaching during input; that case is outside the focused StrategyHub gate and remains unresolved. Its failure log is `.tmp/ui_compatibility/browser-existing-regressions.log`. Do not interpret this focused green gate as all application UI tests passing.

## Rollback details

Revert only this change's strategy hub modal/layout/platform-gate edits, embedded settings metric edits and matching regression additions. Preserve pre-existing changes in those files. Export with the previous UI implementation if needed; no installed strategy package format, user data, replay storage or strategy policy contract migration is involved.
