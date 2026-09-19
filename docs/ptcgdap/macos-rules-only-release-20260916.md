# macOS rules-only release — 2026-09-16

The user chose to ship macOS temporarily without local model strategy support.
Ordinary gameplay and rule strategies remain in the application. Existing
platform, package trust and OS admission requirements remain unchanged.

## Implementation

- Only the macOS export preset excludes the ORT GDExtension descriptor and
  `bin/ptcgai_ort/**`. Windows and Android retain their native backends.
- `AuthorStrategyPlatformCapabilities` explicitly reports models unavailable
  on macOS, even if an unexpected native runtime is present. It avoids probing
  the native model runtime on Mac while preserving the rules capability.
- `AuthorStrategyPortability` propagates the capability owner's model rejection
  reason through the existing selection and match-handle gates. Model packages
  are not silently run as rule packages.
- The strategy hub already displays capability rejection reasons for local
  packages. Battle setup now also explains: “Mac 版暂不支持模型策略，请选择规则策略。”
  Downloads/imports remain available for storage; an installed model strategy
  cannot become an available match through those entry points.

## Validation

Focused failing tests reproduced the missing Mac export exclusions, incorrectly
available Mac model capability, and generic battle setup message before their
respective fixes. Final suites passed:

| Suite | Passed |
| --- | ---: |
| Export presets | 24 |
| Platform compatibility / rules versus model admission | 5 |
| Author strategy battle setup | 13 |
| Strategy hub scene | 22 |
| AI ladder presentation | 6 |
| Strategy hub desktop flow | 4 |
| Native model inference on Windows | 4 |

Total: 78 tests. The separate Windows native runtime probe also passed with
ONNX Runtime 1.26.0 and CPUExecutionProvider.

Final Godot 4.6.1 release export finished without errors or warnings. Inspection
validated ZIP CRCs, every PCK member's MD5, the executable's Intel and Apple
Silicon slices, version 0.6.0 / build 60, absence of native model binaries and
GDExtension startup references, and presence of main menu, strategy hub, battle
setup and rule package runtime resources.

- Local artifact: `.tmp/macos-rules-release-20260916/PtcgDeckAgent-macOS-0.6.0-rules.zip`
- Size: 253,962,941 bytes
- SHA-256: `a19e91eb9e96669efc777fe1577cf9c10526d310560c909980b5e19b49d102fc`
- Logs and machine-readable inspection: `.tmp/macos-rules-release-20260916/`

This resolves the missing-library export blocker by the user's selected release
scope. It does not claim native Mac execution, signing verification on Mac,
notarization, or physical-device UI acceptance. No deployment, upload or public
release was performed. The deferred Web import endpoint issue is unaffected.
Public decision contract and engine alignment are unchanged.

## Restore model support

Build and validate the two universal libraries following
`native/ptcgai_ort_actor/README.md`. Together, remove the Mac-only export exclusions,
restore Mac runtime probing/model capability, and update the intentional
rules-only regression expectations. Keep package trust and model preflight
checks. Verify the exported bundle with `verify_macos_bundle.sh` and run native
inference and gameplay acceptance on Mac before advertising model support.

To revert only this task, undo its two Mac export exclusions, capability pause,
reason propagation, battle setup admission/message changes and added tests.
Preserve unrelated working-tree changes, including the previously corrected
ad-hoc entitlement setting.
