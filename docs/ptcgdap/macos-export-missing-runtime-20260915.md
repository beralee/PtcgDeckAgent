# macOS export diagnosis — 2026-09-15

The macOS preset uses ad-hoc signing and references a native model extension.
Explicitly enable `codesign/entitlements/disable_library_validation` so the
exporter does not need to repair this entitlement automatically.

The blocking export error is separate: both files below are absent from
`bin/ptcgai_ort` in the current Windows checkout:

- `libptcgai_ort.macos.template_release.universal.dylib`
- `libonnxruntime.dylib`

Follow `native/ptcgai_ort_actor/README.md`, macOS universal section: build the
pinned ORT runtime using `build_onnxruntime_macos.sh`, then the extension with
`build_macos.sh` on a Mac. Copy both resulting universal libraries into this
checkout before exporting here, or export on that Mac. Verify the exported app
with `verify_macos_bundle.sh` and perform native runtime/inference checks on Mac.
Changing the entitlement cannot create the missing libraries. Do not remove the
descriptor entries to conceal the incomplete model runtime.

Focused export preset regression: 23 tests, one expected failure before the
configuration change, all 23 passing afterwards. Logs are local ignored evidence
under `.tmp/macos-export-diagnosis/presets-{red,green}.log`. This is configuration
verification only; no new macOS binary was built or tested, and the macOS release
remains blocked. Public policy/runtime alignment is unchanged.

Rollback: revert only the `disable_library_validation` boolean and the added
`test_macos_ad_hoc_signing_allows_bundled_native_libraries` test. Preserve all
other existing export preset and test changes.
