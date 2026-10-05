# Android arena follow-up (v23)

## Scope and fixes

- Prize selection again shows six full card backs in stable 3×2 slots, with the current number owed. The small on-table pile remains stacked outside selection. Attack/KO/reward presentation still gates commits.
- The arena discard callback passed a boolean into an API whose non-string argument means an absolute player index. It now passes a visual role (`self`/`opponent`) and resolves ownership at click time. A second bug retained the old public frame during animation hold after a viewer change. Handover now replaces the entire displayed frame atomically and cancels stale presentation; both pile counts and opened discard collections follow the new viewer.
- Reward presentation uses a red/white ball charging and opening, orbiting attribute icons, card backs emerging into a fan and flying toward the prize area. Higher tiers add bursts/rays and a six-prize rainbow. The field stays visible; no hidden prize identity or new video/3D asset is introduced.
- Home input is scoped to the active modal before the descendant-search touch bridge runs. Covered buttons temporarily use `MOUSE_FILTER_IGNORE`, because native Button activation can precede a `gui_input` guard. Native mouse GUI remains owned by modal Controls. Named modals and the separately named app-update dialog both participate. Closing or self-dismissing a modal clears stale candidates and drains its short compatibility release/echo window, then restores the original filters.
- Opponent dialogue expires after four seconds rather than eight; placement and phone font size remain unchanged.
- The portable default felt no longer multiplies an already dark fabric by another dark green. It uses brighter forest green, a static clearing/diagonal sunlight tint, and green surroundings. Existing stadium art still blends over the same surface; no foliage meshes are restored or added.

## Verification

Evidence is local at `D:/ai/scratch/arena-followup-20261001/`.

- `red/`: reproduces missing prize card backs, eight-second dialogue, and desktop mouse modal guard failure. The first hotseat test incorrectly replaced a ready scene's script and was corrected before accepting its result.
- `handover-red/`: focused, clean failing case proves an animation hold exposes the old seat's discard/count after the viewer has changed.
- `owner-final/`: 10/10, including both hotseat bugs, six card backs, modal guard, dialogue lifetime, and inherited actual supporter/Pokemon/entry-path regressions.
- `owner-web-final/`: 11/11 after adding the Web v2/native mouse regression; only compatibility echoes already handled by the bridge are consumed, while the modal's native mouse Controls remain usable.
- `android-pre-web/`: portrait acceptance passed on the intermediate build. `android-final/`: the subsequent native-mouse routing change exposed footer click-through on Android and was rejected. This failure led to removing covered buttons from both native and bridge hit testing and recognizing independently named update dialogs. Neither intermediate APK is delivered.
- `native-scope.log`: complete Windows rendered acceptance passed after the covered-button fix; final owner/menu and Android delivery runs include the self-dismiss release drain as well.
- `owner-delivery-wallclock/`: 12/12, including covered-button filters, independently named/self-dismissed dialogs, Web v2 native mouse ownership, both hotseat fixes and card/talk behavior. The headless self-dismiss test uses wall time for the release guard rather than accelerated SceneTree timer time. `menu-delivery/`: 6/6 existing home tests passed.
- `regression-final/`: 32/32 across the then-nine follow-up cases, 14 mobile feedback cases, and nine opponent-talk cases. `menu/`: six existing MainMenu layout/touch tests passed.
- `native1.log`: complete rendered Windows compatibility-mode input acceptance passed, including actual footer modal touch/mouse events, both players' discard taps, three Dragapult prizes, repeated Gardevoir, all reward tiers and six-card selection. The later held-frame correction is separately covered by `owner-final/` and the final Android probe.
- `android-delivery/summary.json`: 6/6 passed with no engine errors: `arena_feedback`, `arena_live`, and `arena_input`, each at 1080×1920 and 1920×1080. Actual Viewport touch/mouse tests verify all five covered footer controls, dismissal/reopening, both players' deck/discard counts and discard collection ownership (including held-frame handover), prize timing/card backs, three Dragapult prizes, repeated Gardevoir, existing supporter/Pokemon entry paths and controls. Screenshots confirm brighter portable felt and six-tier ball/card/attribute presentation. Prize tiers use the existing synthetic public prize modifier through production attack/KO owners.
- `apk-v23/player-arm64-smoke.json`: final ARM64 release installed over v22 without clearing data, remained running, and logged no script error or fatal exception.
- Mac, physical Android hardware and a browser binary are not exercised here. Web v2 mouse behavior is covered by the shared-owner test. No 2D/3D performance-parity claim is made.

## Delivered APK

`PtcgDeckDojo-0.6.2-20261001-followup-v23-arm64.apk`: 192,543,818 bytes (192.54 MB); SHA-256 `922a209194e996bdaab7bd708609593ab8f0d5a23245bc76b29191537a1916cb`.

Signature, native alignment/C++ symbols, update-package health, all 24 required local strategy-runtime paths, 156 arena import targets and 121 required 2D resources passed. The CLI-created two-volume archive contains only the APK; archive testing and streamed extraction reproduce its exact size/hash. Connected Google Drive uploads and returned name/size metadata are recorded in `apk-v23/drive-upload-receipts.json`. The second volume's initial blob-transfer timeout occurred before Drive upload and succeeded on retry; existing sharing permissions were retained.

- [Volume 001](https://drive.google.com/file/d/1jfLI2o5r5skxykbOwMUXxwgaWuHN7RmR/view?usp=drivesdk): 100,000,000 bytes; SHA-256 `83c62076e0dbee30b39d23ae90e63d4eea3fd73cb4458c6235b9730ff3e9f1e2`.
- [Volume 002](https://drive.google.com/file/d/1Q2QThB1dbvhfRCmN9V7SBqsp8-fSKzQ4/view?usp=drivesdk): 90,976,235 bytes; SHA-256 `50556f516117fed48ebe2e12ed49b00a30fae17bedbacb2a95080ddfb6d488eb`.

Place both files in one directory and extract 001 to obtain the APK. After export, 106 preserved build-snapshot files were restored byte-for-byte from their pre-task backup; nine added scripts and their UID sidecars were removed from that disposable snapshot. Root working-tree changes and release evidence remain intact.

## Rollback

Restore only this task's source files from `before/`; remove the new follow-up test. Preserve unrelated worktree changes. Production packaging starts from the recorded frozen source, applies v22 plus this task's MainMenu patch, and excludes unrelated updater work. No engine rule, policy boundary, deck contents, private service, commit or push is changed.
