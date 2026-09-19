# Android strategy execution parity and local regression review

Date: 2026-09-14. Scope: Godot 4.6.1 Windows x86_64 and Android on
`Medium_Phone_API_36.1` (`emulator-5554`). Initial ARM64 translation runs and
native x86_64 runs are separate evidence. Neither qualifies physical ARM
devices or asserts CABT engine parity.

## Download and comparison scope

The Android strategy-center UI downloaded and installed **玛丽的礼盒 V3 真·豆包**
by e719, package `dev.e719.marnies-gift-box-v2`, version `0.3.0`.

- Archive SHA256: `4D2CF64BAC2F2A44870473A9ECF11D452D7DBF22ACE515B9E9EE806F91FB57C1`
- Manifest canonical SHA256: `A56D3D2C099567A5C11267774D2BD59DFC0B0AF393C252BBB33B20D2211665B4`
- The normal client validated the download and the normal catalog installed it.
  The diagnostic listener retained the exact delivered bytes for PC comparison.
- Opponent: bundled rules deck `575720`. Seeds `84590`, `84591`, `84592`, each
  with the downloaded policy in seats 0 and 1. Both players' shuffle and engine
  random ports are seeded in the test harness; these private inputs never enter
  policy observations or exported decision records.
- Full matches use the production owner, resolver and engine through
  `HeadlessMatchBridge`. This tests strategy execution, not battle animation
  timing or every visual scene callback. The real Android hub download and
  battle-entry checks are separate UI evidence.

The first complete exported-runtime comparison produced the same 359 public
decision windows, with 56/81/67/69/56/30 windows in seed/seat order. All six
matches ended, and both platforms recorded zero policy errors, stale worker
results, invalid outputs, engine rejections and same-window fallbacks.

## Defects and owner fixes

1. **Reviewed/Cynthia adapters dropped the asynchronous pending protocol.** An
   empty response while the worker was still deciding could be interpreted as
   “no explicit plan,” allowing a generic selection to advance the engine.
   The real policy result then arrived for an old window. Both adapters now
   inherit the common interaction adapter, including pending, context, empty
   selection and external-port behavior. This affected PC as well as Android.
2. **Assignment target waits reopened the source decision.** The resolver only
   retained a sequential source plan for an external research port. An ordinary
   asynchronous local worker repeatedly restarted `assignment_source` while
   waiting for `assignment_target`. All author owners now declare sequential
   interaction windows. Retained source identity is rebound against the current
   option list; removed sources fail closed. No old option index gains authority.
3. **The x86_64 emulator had no native local-strategy backend.** Only ARM64
   libraries and admission existed, forcing translation. Translated runs
   intermittently aborted in font/shaped-text destruction, including
   `ubidi_close_78_godot`, FreeType autohinter cleanup and `sfnt_done_face` in
   the exact official Godot build. Disabling font hinting did not solve this
   and was reverted. The native ORT/extension build, ABI-specific staging,
   descriptor and platform admission now support x86_64 as well as ARM64.
   The regression runner requires a native ABI match. This avoids relying on
   the failing translator path; it does not claim to repair that translator,
   ICU or FreeType. FontBootstrap separately consolidates six deferred live
   theme updates into one idempotent update, verified by a focused regression.
4. **Exported projector evidence lost its artifact fingerprint.** FileAccess
   cannot read a source `.gd` that the exporter replaced with bytecode. The
   diagnostic hash now resolves `.gd.remap` and hashes the actual local compiled
   artifact. It remains diagnostic-only and is cached per owner.
5. **Native inference charged thread scheduling to the model budget.** The
   previous implementation created a `std::async` thread for every decision and
   measured completion on the waiting caller. Android could reject a small
   model when thread dispatch or consumer wake-up exceeded 25 ms. The actor now
   owns a persistent serial native worker and measures execution on that worker.
   The 25 ms inference limit and cancellation remain; dispatch has a separate
   bounded guard and diagnostic duration. A native regression deliberately
   delays the consumer by 60 ms and verifies that fast completed work is not
   mislabeled as a model timeout. Windows uses a new v3 DLL to avoid replacing
   the v2 library held by the running editor.
   Fixed-shape session warmup now occurs during activation with a separate
   500 ms cancellation budget and synthetic zero inputs, before any public
   decision is accepted. Its output is ignored and the normal decision limit
   remains 25 ms.
6. **Review traces omitted model adjudication.** `policy.reported_indexes`
   correctly describes the rules proposal, while a successful model may choose
   a different subset within the Base Graph frontier. The existing record did
   not retain the host's model adjudication. An explicit allow-list now records
   invocation, guard reason, fallback/final indexes and artifact identities,
   excluding timing and unknown additive fields. The review gate requires a
   matching model record for every inference, verifies the final host commit
   and forbids selections outside the Base Graph frontier.
7. **Closing a production match retained an owner/adapter reference cycle.**
   `close_match` stopped work but retained the resolver and an adapter pointing
   back to its RefCounted owner. A normal UI match exit exposed nine resources
   still in use. Earlier headless tests manually broke that cycle, concealing
   the production cleanup defect. The owning close method now revokes the
   adapter after joining its worker and releases the adapter/resolver. A weak
   reference regression covers all three author types and stale adapters;
   full-match tests no longer perform special cleanup. Resource-in-use errors
   at process exit now fail the automated gate.

The former platform-match test explicitly tolerated stale-worker fallback. It
now fails on any such error. Existing deterministic failure handling is retained
for real faults; tests no longer treat that path as normal successful execution.

## Automated detection and review

Build diagnostic exports from a frozen public working-tree snapshot:

```powershell
./scripts/tools/build_strategy_parity_exports.ps1 `
  -AndroidArchitecture x86_64 -OutputRoot .tmp/android_strategy_parity/release-exports
```

Run a previously captured exact package on both exported runtimes:

```powershell
./scripts/tools/run_android_strategy_parity.ps1 `
  -Package .tmp/android_strategy_parity/android-final/downloaded.ptcgai `
  -ExportRoot .tmp/android_strategy_parity/release-exports
```

Run this after changes to owner/resolver/public projection/native runtime or
before accepting a new Android build. It is a repeatable local regression gate;
no recurring cloud job or inference service is created. Python is only a
development-side snapshot/comparison tool, never a player dependency.

Each run creates a unique directory beneath `.tmp/android_strategy_parity/runs/`:

- `build.json`: immutable export identities and source-manifest digest.
- `android/` and `pc/`: completion, twelve native/lifecycle/hub smoke checks, and six
  complete public decision traces.
- `comparison.json`: success or the first differing match/window/field.
- `comparison.html`: searchable local review of each public decision, including
  options, accepted indexes, matched rules and captured model-input evidence.
- Platform logs; a failed orchestration retains `failure.json` and partial
  Android evidence. A crash, timeout or missing completion cannot pass.

The comparison ignores only `host.latency_usec`. Package hashes, window hashes,
public frames, option fingerprints, outputs, model input projections, terminal
winner and progress counts must agree. Script errors, missing native components,
trace truncation and unexpected model fallbacks fail closed. APK inspection
requires the selected native engine and both native model libraries. Windows is launched
from its own export directory. The build never temporarily rewrites the live
editor's project or presets.

Android Wi-Fi and mobile data are disabled during execution by default and
restored to their previous enabled states afterward. Use `-Online` only to test
that separate configuration. The downloaded package stays installed. Diagnostic
activation pointers are removed after each automated run.

The runner uses a dedicated ADB server (`-AdbServerPort 5039` by default), a
non-incremental APK install, and lets the app create its scoped-storage root
before transferring package files. Earlier shell-owned directories after an
app UID change could make the request invisible to the app; a shared ADB server
could also be restarted by another emulator task. These are orchestration
failures, not successful parity evidence. Previous directories are archived,
never cleared, and timeout/connection failures retain partial evidence.

The synthetic model package `17B6DFE95383C65A067283BB16FC09FE83128C0D6E73E13B7D969ADC016DF704`
is a fixed-output guard fixture, not a competitive learned strategy. Its native
vector test expects exact integer scores 29 and 12 and verifies that the model
can change an eligible selection without escaping a veto. Full games can
deliberately hit unknown-deck-UID and invalid desired-count guards. Only this
exact fixture is allowed those two diagnostics; downloaded model packages get
no such exemption. Guard counts must still match across platforms.

```powershell
./scripts/tools/run_android_strategy_parity.ps1 `
  -Package tests/ai/ptcgdap/fixtures/platform_model.ptcgai `
  -ExportRoot .tmp/android_strategy_parity/release-exports
```

After accepting the diagnostic runs, build an ordinary player APK from the
same snapshot. This removes the harness and verifies that no test assets ship:

```powershell
./scripts/tools/export_strategy_parity_player.ps1 `
  -ExportRoot .tmp/android_strategy_parity/release-exports
```

## Validation and limitations

Final native exported runs, both with Wi-Fi/mobile data disabled:

| Run | Package | Paired matches | Windows per platform | Native inferences per platform |
| --- | --- | ---: | ---: | ---: |
| `20260914-022431-b404d2e8` | e719 `0.3.0` exact download | 6 | 359 | 0 |
| `20260914-022645-0e6ae12b` | fixed-output model guard fixture | 6 | 277 | 217 |

All 636 windows agree including final indexes, public state, rule evidence,
model projection/adjudication and fingerprints. Winners and progress agree.
Both runs pass twelve startup checks per platform and the post-exit crash gate.
Policy errors, stale worker results, invalid outputs, engine rejections and
same-window fallbacks are zero. The model fixture's four unknown-UID and five
invalid-count guards are expected and identical; there are no timeout or
unexpected model diagnostics. Its 51 ordinary bypasses respect rules/terminal
ownership and are not counted as successful inference.

The frozen source manifest digest is
`BDBFB344EF2573B84012F06FA47205B6445540E50E2D65729CF3463430C9C6B6`.
The ordinary x86_64 player APK, built from that same snapshot with test assets
excluded, is `PtcgDeckAgent-fixed.apk`, SHA256
`1E093E9D8A0BEBA4470B7BAB948E38E30A01472491DCB6FC73AA5F670AB78080`.
Both APKs pass native dependency, C++ symbol and 16 KB ELF/ZIP alignment checks.
ARM64 native libraries remain separately staged for actual ARM devices.

The native player was installed on the emulator with `primaryCpuAbi=x86_64`.
Before the final close-cycle fix, its live strategy-center UI downloaded e719
`0.3.0` again and logged the same
archive SHA, `already_installed=false`, `catalog_discoverable=true`, `ok=true`.
The real battle setup showed that exact author/version. After human setup,
the downloaded AI completed its first turn (bench deployment, stadium and
energy attachment), and the UI advanced to turn 2 for the human. Screenshots
`native-download-after.png`, `native-battle-setup.png` and
`native-after-ai-turn.png` remain under the ignored local evidence directory.

The final ordinary APK above retained that download, showed e719 `0.3.0` in
setup and completed another real AI first turn, reaching human turn 2. The AI
deployed two Snorunt, used Buddy-Buddy Poffin and attached energy. The UI then
ended the match, returned to the main menu and exited the app normally. After
a seven-second post-exit wait the process was gone, with no script error,
native crash or resources-in-use error. This directly rechecks the production
close-cycle fix. Evidence: `release-strategy-ready.png`,
`release-battle-setup.png`, `release-after-ai-turn.png`, `release-player-ui.log`.

- Focused interaction regressions: three tests cover pending search/target,
  context forwarding, accepted source identity, current-index rebinding,
  removed-source rejection, and release/revocation on close for all three owners.
- Existing external decision-port integration suite: 19 tests passed.
- Font regression: old implementation fails with six live updates; fixed
  implementation passes with one update and no repeated update.
- Developer model evidence suite: five tests passed, including export remap,
  hidden-input rejection, reordered frontier projection and model adjudication.
- Native worker regression: thread reuse, delayed consumer timing, exceptions
  and recovery pass; both native artifacts are rebuilt from the changed source.
- Review detector: ten tests cover missing completion, truncation, stale
  fallback, wrong package, first differing output, unexpected model fallback,
  legal model changes and forbidden/unexplained host changes.

Earlier verbose test-only shutdown inspection reports two pending `SceneTreeTimer`
references; no strategy/model owner classes appear in that leak report.
This diagnostic warning is retained in local logs and is distinct from the
fatal native crashes and resources-in-use errors that the acceptance gate rejects.
The final ordinary player UI run has neither warning nor resource errors.

The evidence does not qualify macOS, physical Android ARM devices, all Android
versions, every deck/card effect, or all battle UI animation paths. Reproducible
emulator execution is a distinct gate from those broader release gates.

## Rollback and evidence handling

Keep the exact previous APK for application rollback. The platform admission
switch `ptcgdap/author_strategy/platforms/android_enabled=false` can stop Android
strategy starts while retaining downloaded packages. Do not restore permissive
stale-worker assertions or bypass current-window validation to obtain a pass.

Implementation rollback boundaries are the shared adapter and two subclasses,
the resolver's sequential-window predicate, FontBootstrap, the native actor
worker/activation and ABI changes, platform admission, and the diagnostic
projector-hash/model-adjudication helpers. The test harness is included only in diagnostic exports;
ordinary export presets continue excluding `tests/**`.

Raw local export logs may contain signing arguments, and isolated snapshots
include local signing metadata needed to build. They remain under ignored
`.tmp`; do not publish those files. Public evidence may include the sanitized
comparison report, source digests, package identities and UI screenshots. No
private-cloud implementation or external oracle was changed.
