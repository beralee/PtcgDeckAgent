# Android portrait battle feedback (v22)

## Changes

- Home actions fit the height between the title and footer, as well as the width. All six actions remain visible at 9:16 and taller phone ratios.
- Compact card HP uses a larger text/bar scale; energy icons and counts use larger cells that wrap instead of colliding. Decorative fern meshes are hidden and excluded from table deformation.
- A normal tap on a revealed opposing field card opens its detail panel. Current effect-target selection retains priority. Field details lead with effective HP, damage, actual attached energy names/counts, tool name and special conditions, followed by printed abilities/attacks.
- The first Psychic Embrace by a Gardevoir each turn keeps its model animation. Further committed attachments by that same instance use a brief target pulse, without another cinematic input wait. Each use still needs fresh legal energy and target choices and applies its own damage.
- Committed knockout prize counts queue a reward celebration after attack and card-departure animation. Six tiers increase rings, rays and particles, with a crown at six. Subsequent knockouts from the same action advance the cumulative tier. Effects are bounded procedural canvas drawing, without new textures/videos or player-runtime dependencies.
- The legacy portrait prize popup is suppressed only in the arena. Otherwise it appeared over the attack/reward even while the arena buttons were disabled. The scene prize-commit entry also checks the presentation gate.

## Three-prize investigation

The staged Dragapult Phantom Dive knocks out a 2-prize active and a 1-prize bench Pokemon using the production counter-assignment and attack owners. The engine's current sequence is: two prize selections, opponent replacement, then the remaining bench prize. All three prizes are received. No lost-prize engine defect was reproduced; no card rules or engine transition were changed. The probe checks each individual prize delta, the intermediate replacement and final total, rather than expecting one initial three-card prompt.

## Evidence and limits

Local evidence: `D:/ai/scratch/arena-feedback-20261001/`.

- `red/`: original focused failures for home overflow, opponent normal tap, missing condition text, foliage and premature prize commit. The initial three-prize test also exposed the intermediate replacement window; it was corrected to resolve that legal window.
- `owner-final/`: 40 assertions/cases across ArenaMobileFeedback (13), ArenaMobileLive (3), ArenaSignatureVfx (7), BattleDisplayController (17), all passed. `prize-owner-final/` repeats 13 with the legacy-popup gate.
- `cancel-final/`: 14/14, including releasing the input gate when a queued reward is cleared (e.g. disabling motion).
- `menu-final/`: six main-menu layout/touch tests passed.
- Rendered iterations discovered the premature legacy popup and a degenerate small-polygon draw error; these were fixed before final Android acceptance.
- A broader NonBattlePortraitLayout run has an unrelated landscape BattleSetup content-height assertion failure, also reproduced in isolation (`unrelated-isolated/`) and against the frozen release source (`frozen-layout-control/`). MainMenu's obsolete fixed-height/offset expectations were replaced with footer-clearance checks.
- `android-pre-chain/`: actual Android 1080×1920 and 1920×1080 feedback acceptance passed without engine errors. Screenshots confirm the old prize popup no longer covers the reward. Final acceptance also checks cumulative three-prize presentation after preserving the count across transient layout resets.
- `android-final/summary.json`: all six final Android runs passed without engine errors: `arena_feedback`, `arena_live`, and `arena_input`, each at 1080×1920 and 1920×1080. The diagnostic APK includes the exact final presentation sources; screenshots cover the home menu, readable board, opponent detail, first/repeated Psychic Embrace, three-prize completion, and all six reward tiers. The six-tier gallery uses a synthetic public prize modifier through actual attack/KO transitions; it is not evidence of a natural six-prize card combination.
- `apk-v22/player-arm64-smoke.json`: final release APK updated the existing player app successfully, stayed running, and logged no script errors or fatal exception. Existing user data was not cleared.
- Mac and the user's physical phone are not tested here. This does not claim the earlier 2D/3D performance-parity gate passed.

## Release artifact

`PtcgDeckDojo-0.6.2-20261001-feedback-v22-arm64.apk`: 192,539,078 bytes (192.54 MB), SHA-256 `f04ea0d2c2b26fed4683fd3eeab085ab5bfaf57fa2936bbcc129d30f52382db2`.

Release signature, ARM64 native library alignment/symbol checks, arena/2D asset inventory, app-update export checks, and the local strategy runtime package audit passed. The archive contains only this APK; archive testing and streamed extraction reproduced the exact APK size and SHA-256. Receipts are under `apk-v22/`.

CLI packing produced two volumes; the connected Google Drive upload API uploaded them, and returned metadata confirmed both names and sizes. Existing Drive permissions were retained.

- [Volume 001](https://drive.google.com/file/d/1DOIxDOVDHiS2coCU43fvEZG6AnJQF_0-/view?usp=drivesdk): 100,000,000 bytes; SHA-256 `6d6aa5bffe5af8705a879e23ff3dc4668bb432dfb305d88239669f52c9275caf`.
- [Volume 002](https://drive.google.com/file/d/1_U8j99bLl75Qjf7AVVCgV8iBPU1IUU_2/view?usp=drivesdk): 91,420,284 bytes; SHA-256 `23bf73d8386e0a906c379062815045205307429c076a927a60396a8167cfb228`.

Put both volumes in the same directory and extract 001 to obtain the APK.

After export, all 105 preserved files in the disposable build snapshot were restored byte-for-byte from its pre-task backup, and eight added source scripts plus their generated UID sidecars were removed. The root working-tree implementation and release evidence remain available.

## Rollback / scope

Restore only the files changed by this task from `before/` and the recorded v21 manifest; remove the new prize-celebration and acceptance scripts if rolling back. Preserve unrelated working-tree changes. The APK snapshot applies only this task's MainMenu diff to the frozen release, so the separately developed card-content updater is not accidentally included. No service, strategy policy, built-in deck, external oracle, commit or deployment is changed.
