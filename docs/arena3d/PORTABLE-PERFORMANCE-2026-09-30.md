# Portable 3D parity and performance — 2026-09-30

Status: Live-style portrait UI implemented; Android performance gate not passed.
Final Android visual/input checks and Chromium checks passed as recorded below. No release,
commit, push or production download has been published. The user owns macOS
hardware testing; no macOS device pass is claimed.

## Delivered presentation scope

Windows, Android, macOS and Web can select the grove 3D field. Android, macOS
and Web force the portable quality profile even with a saved desktop high-quality
preference. Native iOS and Linux retain the existing 2D fallback.

The earlier six-box table and omitted character cinematics did not meet the
requested Windows parity. The portable implementation now uses offline LODs of
the authored grove table and prize cradles. All original table components,
14 Pokémon and their articulated joints, 18 supporters with all six poses,
character audio, attack/ability choreography, card movement, stadium illustration,
prizes, deck/discard stacks and shared interaction owners remain present.

`tools/arena3d/build_portable_assets.py` runs in Blender 5.2 and uses ffmpeg for
OGG conversion. It retains source meshes/joints in
`assets/arena3d/portable/manifest.json`, with source/output SHA256 hashes. It
reduces table triangles from 107,660 to 30,140, retains eight material groups,
batches Pokémon palette meshes by articulated joint (6–13 draws per character),
and preserves supporter sheets at 1152×768 (six 384-pixel poses). Original
Windows assets are unchanged. These tools are development dependencies only.
The original asset license notices continue to apply.

The reduced profile omits dynamic shadow maps, HDR environment, moving point
lights and ambient GPU particles; foliage is static. Character geometry and
stage VFX use the same timing and endpoints as desktop. The arena framebuffer's
maximum edge is 832 pixels; UI, text, input and full card details retain the
normal UI resolution. The shared portable palette shader corrects linear glTF
vertex colors for the Compatibility renderer's sRGB output, without doing color
conversion per fragment. See the [Godot spatial shader built-ins](https://docs.godotengine.org/en/4.6/tutorials/shaders/shader_reference/spatial_shader.html#global-built-ins).

Portrait adaptation follows the supplied Live reference: overlapping prize backs
at the left, stadium at middle-left, deck/discard modules at the right and the
end-turn button between both players' right-hand modules. Both toolbar rows are
removed; their actions remain in the top-right menu. Six separate prize choices
appear only during the existing claim transaction. Eight bench cards use two rows
with explicit side-pile clearance, also on short portrait tablets. Compact HUD
cards retain current/maximum HP, damage, effective
energy types and counts, tool name/art, individual status icons and used-ability
markers. Existing menu actions, logs, discard views, card details and choice
owners remain available. The legacy portrait HUD is prevented from reappearing
on refresh, including after claiming prizes.
The legacy 2D stadium card is also suppressed at its refresh owner: it previously
floated above the landscape menu despite the correct 3D stadium on the table.
Compact end-turn buttons omit the decorative arrow so their full label fits.

## Performance changes

- Cache the static 3D framebuffer; invalidate on public card/pile changes,
  camera/layout changes, highlights, ongoing VFX and animation completion.
- Portable presenter refreshes on actual public/UI changes and motion-stage
  transitions. It no longer polls and reconstructs the full public board every
  0.13 seconds or allocates button styles every display frame.
- Keep hidden legacy field-card anchor identities for shared controllers without
  decoding their artwork or rebuilding their invisible 2D status controls.
- Load portable character resources in the background during scene entry and
  retain them for the battle lifetime. Consume outstanding jobs on early exit.
  Render the actual palette, transparent mesh, flame and billboard shader
  variants into an unshown 16×16 viewport at entry, retaining their materials.
  Headless tests skip this GPU prefetch.
- UI-only motion-stage changes reuse the cached public frame. Compact card HUD
  drawing is cached by camera/card geometry, state and occlusion, so moving
  creature meshes do not reconstruct unchanged labels every frame.
- Separate compact HUD state updates from geometry/style allocation. A busy
  transition no longer rearranges an unchanged board. A hold boundary refreshes
  only when a committed public frame is waiting; the rendered input regression
  verifies that the old frame remains until settle and then reveals new damage.
- Portable ribbons and flame volumes use fewer segments; the stage shadow
  curtain uses a coarser grid. All effect categories and timings remain present.
  Hidden defender effects do not regenerate geometry. Procedural effect meshes
  are sampled at 30 Hz; character transforms/joints, presentation/input processing
  and the root framebuffer keep their display-rate clock.
- Generate the existing deterministic sound waveforms during scene loading,
  before the first action. This moves cost into startup rather than dropping
  audio. Startup is recorded separately and is not excluded from product cost.
- Keep pointer processing at display rate. Rotating an unchanged eight-bench
  frame explicitly reflows the board. Finished/stopped card tweens cannot keep
  the static viewport awake indefinitely.

## Measurement contract

`ArenaPerformanceRunner.gd` displays the real BattleScene with a synthetic public
fixture: two active Pokémon, eight bench Pokémon on each side, hands, prizes
and a stadium. No strategy evaluation or hidden replay enters the comparison.
`public-eight-bench-signature-v4` measures 20 seconds of idle board followed by
20 seconds of public updates and attacks, one every four seconds, alternating
Dragapult (CSV8C_159), Charizard (CSV5C_075), and Raging Bolt (CSV7C_154).
2D uses its existing attack controller; 3D uses the full character choreography.

Raw samples are wall-clock intervals at `RenderingServer.frame_post_draw`.
Reports retain every interval, actual platform/window/GPU/renderer, render size,
update timing, signature count and draw/primitive statistics. Godot process
monitor values are supplementary, not a per-frame CPU/GPU breakdown.
`setup_wall_ms` includes fixture settling, so it is not a launch-time claim.

The comparator rejects missing/truncated windows, nonfinite samples, headless
runs, mismatched platforms/workloads and missing character attacks. Per window:

- Mean and P95: at most max(2D × 1.10, 2D + 1 ms).
- P99: at most max(2D × 1.15, 2D + 2 ms).
- Maximum: at most max(2D × 1.20, 50 ms), and always below one second.
- Fraction of frames above 50 ms: at most 2D + 0.5 percentage points.

No failing sample is trimmed or waived. Relative success does not imply that
baseline stalls are smooth. Host-GPU emulator results do not establish ARM
hardware performance or sustained thermal behavior.

## Local evidence

All raw evidence and before-edit backups are under
`D:/ai/scratch/arena-portable-20260930/`, with this parity revision in `parity/`.
Reports from earlier versions remain intact, including failures.

### Live-style portrait revision

- `suites-live-final.json`: 22/22 owner checks passed. The new prize-stack test
  first failed in `live-layout-failing.json` before the owner change.
- `native-live-overlap-fail-errors.log`: reproduced the expanded-bench/prize
  overlap. `native-live-final.log` passes after adjusting side-pile spacing and
  tablet camera fit, including aligned discard touch targets after expansion.
- `android-acceptance-v14/summary.json`: 4/4 passed at actual 1080×2400 and
  2400×1080 windows. Each orientation retains all 32 model/supporter checks and
  the existing touch/prize/search checks. Portrait menu-to-log input is also
  exercised after removing the standalone toolbar button.
- `native-live-final-user/.../platform-390x844.png` and
  `android-acceptance-v14/1080x2400-arena_input/app/platform-eight-bench.png`
  show the new table layout. Rendered native phone/tablet/landscape rotations pass.
- Both v14 export inventories pass; Python validator/export tests remain 15/15.
- The emulator logs retain an exit-time GFXSTREAM VAO warning and ObjectDB
  cleanup warning; no Godot script error occurred in the acceptance checks.
- v14 APK SHA256: `f3adb71faa1a22e94384cc6dc32110dde9427e709d6164f9af823b0205e3bac3`.
  Its public source manifest SHA256 is
  `f7382572ff0e504895f66913da60720e8d1939563766199186db66f4d9324e6b`.
- v14 Web E2E PCK SHA256:
  `1b1726e100d4c69e838156ec5b3e08e164d1197641c48018bb0ec1b85bc2187e`.

`android-perf-v14/` was interrupted after five complete comparisons once all
three portrait comparisons failed (3D attack P95 22.428–24.707 ms). The failed
summary and partial final pair remain; it is not an accepted six-pair run.

`native-label-cache-fail-errors.log` reproduced pile labels being redrawn when
only the 3D framebuffer changed. The labels now cache their own public state,
camera and visible empty-slot geometry. The first fix still tracked invisible
subpixel interpolation; `native-label-cache-diagnose.log` isolates that key,
and the final cache ignores movement below a quarter UI pixel.
`native-label-cache-final.log`, `android-input-v15/summary.json` (2/2) and
`browser-v15-ui/` (2/2, mouse and touch) passed this owner change.
`android-perf-v15-pilot/` nevertheless failed attack P95: 21.268 ms against a
2D baseline of 18.041 ms. No tail samples were removed.

The opt-in `ArenaProcessProfiler.gd` times script owners for diagnosis. Its
`arena_process_diagnostic` report kind is explicitly rejected by the normal
comparator; the corresponding Python gate test passes. The uninstrumented
report also records scene-phase and render-submission intervals; these include
engine/driver waits and are not isolated GPU hardware durations.
`android-cpu-profile-v16/` found that the measured script calls themselves were
small, so the apparent scene-phase cost was not treated as GDScript time.

`prize-transform-fail.json` then reproduced redundant descendant transform
notifications from resetting each stacked cradle to its narrow scale before
widening it again every frame. v17 computes the final transform once, caches
settled portable piles, and updates material readiness only when it changes.
`suites-v17-fixed.json` passes 23/23 checks; `native-v17-fixed.log` passes the
full input/rotation probe. An initial int/bool sentinel error was caught by
`suites-v17.json` and fixed before the completed v17 build.

`android-perf-v17/summary.json` completed all six comparisons and is **not
accepted**. All three portrait idle cases passed. Portrait attack P95 was
19.608–24.983 ms against 2D 18.436–18.825 ms; all three failed P99 and two also
failed P95. Landscape attack P95 was 43.307–46.110 ms, with idle slowdowns too.
Later landscape 2D samples also degraded (P95 31.981–38.316 ms); this does not
justify discarding the 3D failures or attributing them to a proven external
cause. The cradle-cache fix therefore does not establish performance parity.

The one-off `v17-surface-latency-probe.txt` is an unpaired, unlabelled Android
SurfaceFlinger diagnostic sample. It cannot replace the complete frame-gap
comparison, prove input latency, or qualify a performance pass.

Final v17 APK/PCK inventories both pass (156 arena import targets and 121
required shared/portable resource paths); Python gate tests pass 16/16.
`android-acceptance-v17/summary.json` passes all four final-package checks at
actual 1080×2400 and 2400×1080 windows, with no engine script errors. Both visual
runs cover all 14 Pokémon and 18 supporters; both input runs cover the new
portrait layout, menu/log route, full prize/search flow, eight-bench targets and
phone/tablet rotation. The clean portrait captures are
`android-acceptance-v17/1080x2400-arena_input/app/platform-1080x2400.png` and
`platform-eight-bench.png` in the same directory.
The earlier browser result below does not substitute for this layout's checks.

`browser-v17/results.json` passes **4/4**, zero retries/skips: real mouse/touch
input, portrait menu/log/close, modal cancellation, rotation and paired frame
budgets. Both profiles record ANGLE / NVIDIA RTX 4090 / D3D11. Values are ms;
all comparator gates pass, including those not shown in this compact table.
This is Chromium on Windows, not macOS/Safari or an Android browser device pass.

| Browser profile | Idle P95 2D / 3D | Attack P95 2D / 3D | Attack P99 2D / 3D |
| --- | --- | --- | --- |
| Desktop | 17.6 / 17.7 | 17.7 / 17.9 | 19.3 / 18.9 |
| Touch | 17.6 / 17.7 | 17.6 / 18.4 | 18.9 / 20.1 |

Current diagnostic artifacts (emulator x86_64, not a phone ARM release):

- APK: `parity/build-v17/PtcgDAP-performance.apk`, SHA256
  `ee1a7097f151cd1520bc3a068da9779d5f8c6854bb5536b6bde106219f144069`.
- Public source manifest SHA256:
  `d03c01142f822f77ba5f47d187c61214d0ed592cf393d78bc10e14f2e5b2dec5`.
- Browser PCK: `parity/web-final/PtcgDeckAgent.pck`, SHA256
  `7a3a10b546dbcb836b0645ab738e525dd0a825bb6e9dc6f09a207c3ebc942d0c`.

### Earlier revisions

- `windows-reference/`: all 32 authored desktop character/supporter captures.
- `visual-hud-v6/`: native portrait captures showing restored models and HUD.
- `android-acceptance-v4b/`: early input/visual inventory passed, but inspection
  found the old 2D HUD reappearing. These are superseded, not final acceptance.
- `android-perf-v5-pilot/`: failed first-attack and tail-frame gates.
- `android-perf-v6-pilot/`: failed; exposed periodic public-frame reconstruction
  and hidden legacy-card work. Full raw samples retained.
- `suites-v13.json`: 21/21 owner checks passed: portable parity 8,
  platform adaptation 7, presentation integration 6. These include model/joint/
  audio inventory, ability routing, legacy HUD isolation, static sleep/wake,
  completed-tween cleanup and invisible-card allocation regression.
- `native-input-v13.log`: viewport-input regression passed across phone portrait,
  landscape, tablet and desktop dimensions, including unchanged eight-bench
  rotation, unchanged-board busy transitions and held/committed public frames.
  The existing hand-surface repair warning during rapid rotation is retained.
- `android-acceptance-v13/summary.json`: all four actual-window visual/input
  runs passed at 1080×2400 and 2400×1080. Both visual runs verify all 14 Pokémon
  and 18 supporters, articulation, six poses and local audio. Input includes
  touch cancellation, tap/long press, modal cancellation, one-time energy
  attachment, sequential prize selection, search and all eight bench targets.
  Compact evidence capture saves selected PNGs without reducing assertions.
- Python export-inventory/performance-validation tests: 15 passed.
- `android-v13-inventory.json`, `web-v13-e2e-inventory.json`: portable export inventory
  passed, checking 156 known arena import targets and 121 required shared/portable
  resource paths, with no missing resources or forbidden full-detail assets.
  Web diagnostic PCK is 216.42 MiB / 225 MiB; WASM is 34.08 MiB / 40 MiB.

Final APK visual/input, three performance pairs per Android orientation, and
final Chromium input/performance results must be recorded below before declaring
portable performance accepted. Windows-hosted WebKit has a previously observed
Godot blit error; it is not waived or represented as a Safari/macOS pass.

The v9 run in `android-perf-final/` was not accepted: three P99 comparisons
failed, and requested landscape runs were actually portrait after startup
orientation selection. The runner now passes explicit requested dimensions into
the diagnostic app and rejects an actual-window mismatch. That failed directory
is retained as historical evidence despite its earlier intended name.

`browser-final/` used Playwright's default Chromium headless shell. Its GPU
process explicitly reported `--use-angle=swiftshader-webgl` and the renderer
`--disable-gpu-compositing`. Input passed, but the CPU-rendered 3D performance
comparison failed; this remains a limitation, not an accepted browser result.
Hardware browser acceptance uses the full Chromium channel and records the
actual WebGL renderer. Playwright documents the distinction between
[headless shell and full Chromium headless mode](https://playwright.dev/docs/browsers#chromium-new-headless-mode).
Hardware tests also disable continuous video/trace capture while timing frames;
explicit screenshots are taken outside the measurement windows.

`android-perf-v10/` is an interrupted, unaccepted run: actual landscape attack
P95 was about 24 ms against an 18 ms 2D baseline. Its first two complete pairs
remain available. v11 subsequently reduces the portable render edge and samples
procedural effect geometry less frequently without dropping model animation.

`android-perf-v11/` completed six unaccepted comparisons. The later 2D baseline
also slowed, so the emulator was cold-started without loading or saving a RAM
snapshot. `android-perf-v11-cold-pilot/` restored normal landscape P95 (2D
18.067 ms / 3D 18.709 ms), but 3D P99 22.475 ms exceeded its 22.1145 ms limit.
No result from these runs is an Android performance pass.

`browser-hardware-v11/` passed all four Chromium desktop/touch input/performance
tests on the recorded RTX 4090 D3D11 backend. Attack P95 was 18.2 / 18.5 ms
(2D / 3D desktop), and 18.0 / 18.7 ms (touch). This precedes the final HUD
state/layout separation and must not substitute for its final regression run.

`suites-v12.json` passed 20/20 owner tests. `native-input-v12.log` passed the
rendered input/rotation probe including the new busy/held-frame regressions;
`layout-failing*.log` preserves the pre-fix failure. The existing hand-surface
repair warning during rapid native rotation remains recorded.

`android-perf-v12/` completed six comparisons and is **not accepted**. All three
portrait pairs passed (attack 3D P95 18.735–18.873 ms versus 2D 18.155–18.459 ms).
Landscape pair 1 passed, pair 2 had a degraded 2D baseline (idle P95 79.358 ms),
and pair 3 failed idle/attack tail gates. Its 3D idle P95 was 30.55 ms and attack
P95 22.876 ms. The system log and post-run memory report showed background
Google application activity and substantial paging; this is a possible source
of interference, not proof that the application has no remaining regression.
Every sample and the failed summary are retained. A controlled follow-up must
be reported separately rather than replacing these results.

`browser-hardware-v12/` passed all four tests; desktop attack P95 was 17.9 / 18.2 ms
(2D / 3D), touch 17.8 / 18.1 ms. This result precedes the v13 stadium overlay fix.
`stadium-regression-failing.json` records the reproduced v13 pre-fix HUD failure;
the corrected 21-test suite and rendered Android input/visual checks pass.

`android-perf-v13-controlled/` completed six comparisons after a cold boot with
emulator networking disabled. It is **not accepted**: all three landscape pairs
passed, but portrait pair 1 failed P99 (3D 22.41 ms), pair 2 failed with 3D attack
P95 44.72 ms / P99 57.17 ms, and pair 3 passed. This does not establish background
network activity as the cause of the intermittent slowdown. Raw failures remain.

v13 browser verification, `browser-hardware-v13-e2e/`: **4/4 passed**,
zero retries, real mouse/touch input plus rotation and paired performance.
Both modes recorded ANGLE / NVIDIA RTX 4090 / D3D11; software-renderer checks
remain enabled. Values below are milliseconds; every comparator gate passed.

| Browser profile | Window | Idle P95 2D / 3D | Attack P95 2D / 3D | Attack P99 2D / 3D | 3D attack max |
| --- | --- | --- | --- | --- | --- |
| Desktop | 1440×900 | 17.0 / 17.1 | 17.0 / 18.0 | 18.0 / 18.9 | 78.4 |
| Touch | 1081×2202 | 17.8 / 18.1 | 18.0 / 18.3 | 19.8 / 19.2 | 80.6 |

Pre-Live-layout diagnostic artifacts (v13; emulator x86_64, not a phone ARM release):

- APK: `parity/build-v13/PtcgDAP-performance.apk`, SHA256
  `fec59c04a9d9ac4ea3ea959df6ac7d86de62138538117a71e72cdd81b512b2fd`.
- Public source manifest SHA256:
  `41ee52cd36fc0ae5480409f02b275451cbcb61d0895c3db172837b366371f5b9`.
- Browser PCK: `parity/web-final/PtcgDeckAgent.pck`, SHA256
  `3b2b74bb913497b036b8d5fa5572ffa7d32499c0501e62209085673ea2c79770`.

`browser-hardware-v13/` was interrupted after two setup failures: the ordinary
Web export lacks the automation bridge. No performance samples were accepted.
The corrected local export uses `Web UI E2E`, retaining the same game renderer
with the explicit test bridge; its evidence is `browser-hardware-v13-e2e/`.

## Reproduction

Use a fresh evidence directory for every run:

```powershell
scripts/tools/build_performance_player.ps1 -OutputRoot NEW_EXPORT_DIR -AndroidArchitecture x86_64
python tools/arena3d/run_portable_acceptance.py --device emulator-5554 --apk NEW_EXPORT_DIR/PtcgDAP-performance.apk --output NEW_VISUAL_DIR
python tools/arena3d/run_render_performance.py --device emulator-5554 --apk NEW_EXPORT_DIR/PtcgDAP-performance.apk --sizes 1080x2400 2400x1080 --runs 3 --output NEW_PERF_DIR
```

Only verified package `com.example.ptcgdeckagent.performance` is installed/cleared;
personal emulator data is retained. Display-size overrides are restored afterward.
The reusable diagnostic snapshot mode validates its original source record and
refreshes public sources, retaining a new source manifest per output build.
It must never be used to overwrite production downloads.

The browser's test-only bridge uses the same renderer and comparator:
`tests/web_e2e/arena-platform.spec.cjs`, config `arena.config.cjs`. Portable
resource inventory is checked with `tools/inspect_2d_export_assets.py --arena-mode
portable`; default strict-2D mode remains available for old exports.
Export the browser harness with the `Web UI E2E` preset, then set
`PTCG_WEB_E2E_EXPORT_DIR` to its directory and `PTCG_WEB_E2E_ARTIFACT_DIR` to a
fresh evidence directory. Run Playwright with `--config=tests/web_e2e/arena.config.cjs
--project=chromium-desktop --project=chromium-touch`. The ordinary `Web` preset
intentionally excludes the automation bridge.

## Cleanup and rollback

The previously authorized temporary-output cleanup achieved C: 11.65 GiB and
D: 32.83 GiB free. The cleanup plan/results CSVs remain in the work directory.
Source, personal saves/emulator data, release downloads, retained evidence and
rollback copies were not removed. Subsequent diagnostics consume some space;
final free space was checked again before handoff: C: 11.13 GiB, D: 19.18 GiB.
C currently meets the requested 11 GiB target; D no longer meets 22 GiB after
subsequent workspace activity and diagnostics. Automatic approval review blocked
removal of old diagnostic snapshots/exports and duplicate reports, returning only
`blocked by policy`. No equivalent deletion workaround was attempted. Allowed
NTFS compression of this task's caches retained their contents; its logs remain
under `parity/`. The D target is not claimed complete.

`android-restored-network.json` confirms the temporary measurement settings were
restored: airplane mode 0, Wi-Fi 1, mobile data 1, physical 1080×2400 display with
no size override. The diagnostic app was stopped; no personal emulator data was
removed.

Reverse only this task's owner changes, preserving unrelated dirty work. The
pre-edit owners/export presets are saved in `before/` and `parity/before/`.
Availability gates and export filters must be reverted together. This work only
changes presentation/interaction integration; it claims no new CABT, strategy,
engine-parity or competitive-strength alignment level.
