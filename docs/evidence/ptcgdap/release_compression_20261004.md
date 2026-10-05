# v0.6.3 release compression — 2026-10-04

## Measured artifacts

Both measurements use locally exported release builds from this worktree on
2026-10-04, not the older v0.6.2 download directory. One MiB is 1,048,576 bytes.

| Artifact | Before | After | Saved | Reduction |
| --- | ---: | ---: | ---: | ---: |
| Android arm64 APK | 310.713 MiB | 170.056 MiB | 140.657 MiB | 45.27% |
| Windows x64 ZIP | 318.525 MiB | 205.362 MiB | 113.163 MiB | 35.53% |
| Windows unpacked files | 417.719 MiB | 304.195 MiB | 113.524 MiB | 27.18% |

Outputs are in `output/release-compressed-20261004/`:

- `PtcgDeckAgent-0.6.3-android.apk`: 178,316,812 bytes;
  SHA-256 `76c79f77952796083b76aab7cf28ec3bd879ec8faedc2797bb2b280dd980d6ab`.
- `PtcgDeckAgent-0.6.3-win.zip`: 215,337,404 bytes;
  SHA-256 `551a4d36df8064b5f73b3cbf9b639fa6a9783ef584d90444f7c66587382cc371`.

The shared worktree contained existing changes and concurrent work. These are
the actual before/after package sizes, not an isolated source-code benchmark.
The resource comparison records other changed compiled scripts separately;
none of those changes were made for compression. No version bump, commit,
publication, private-cloud change or policy-runtime change was performed.

## Changes

- Convert 258 lossless WebP card images to WebP quality 94. Existing lossy WebP
  files (848) remain byte-identical. This includes the newer extended WebP
  images with VP8L data inside VP8X/EXIF containers, which the old optimizer
  skipped merely because they were already WebP.
- All 1,106 card images: 94,628,498 → 60,036,414 bytes; save 34,592,084 bytes
  (32.99 MiB). Dimensions and alpha channels are unchanged. Compression is
  lossy for color data; sampled original/compressed card text was visually
  inspected. No resizing was used.
- Import 32 stadium backgrounds and 18 desktop supporter textures at quality
  90. Original source images remain unchanged. Android uses the 32 backgrounds
  and continues excluding the desktop supporter textures.
- Enable Android native-library ZIP compression. All four decompressed native
  libraries are byte-identical to the baseline. Their archive payload decreases
  from 90,178,432 to 30,365,620 bytes (57.04 MiB saved). The final manifest has
  `extractNativeLibs=true`; installed library storage is not eliminated by this
  download-size reduction.
- Exclude `evidence/**/*.png` from Windows exports: 15 imported screenshot
  payloads plus their descriptors disappear from the package.
- Update the bundled content digest to
  `91C0B5A94E3C292B6E15DF39A5F3E0B9171A0953DB39EC12100F8EC4A0B5FC14`.
- Extend the optimizer with RIFF chunk detection, candidate dimension/alpha
  checks and focused regression coverage. A second pass does not recompress
  already lossy card images. Candidates replace sources only when smaller.

## Validation and limits

- Python: 14/14 pass (`test_release_asset_optimization`,
  `test_bundled_seed_revision`, `test_2d_export_assets`).
- Isolated Godot functional suites: 103/103 pass (`BundledDeckCatalog` 10,
  `CardDatabaseSeed` 84, `CardImageFallback` 9).
- Decode and compare all 1,106 source card images against their backups:
  dimensions/alpha preserved, 258 changed and 848 byte-identical.
- ZIP/APK CRC checks pass. Both packages contain all 1,106 expected card
  payloads and the current seed digest. All 50 Windows and 32 Android changed
  texture payloads match the current imported files.
- Windows updater/content export inspection and native DLL verification pass.
  Exported executable starts headlessly with isolated user data and exits 0.
  Godot reports an ObjectDB cleanup warning at shutdown; this is not a full
  graphical or battle-runtime acceptance test.
- Android release/updater/content export inspection, portable resource closure
  (156 import targets, 121 required 2D resources), APK v2 signature, ZIP
  alignment, ELF 16 KiB alignment and native dependency/C++ checks pass.
- Android installation was attempted on the available emulator. It refused
  version code 63 because version code 64 is already installed
  (`INSTALL_FAILED_VERSION_DOWNGRADE`). No uninstall or forced downgrade was
  attempted. Compressed APK startup/device gameplay is therefore not verified.
  This evidence makes no new strategy alignment or device-runtime promotion
  claim.

## Evidence and rollback

Detailed reports, SHA-256 resource comparisons, build logs and sampled visual
comparisons are under `.tmp/release_compression_20261004/`. The primary package
report is `package-verification.json`; the baseline audit is
`.tmp/package_size_audit_20261004/`.

Original card images are backed up under
`.tmp/release_asset_optimization_20261004_233138/backup/`. The corresponding
`report.json` lists exactly which 258 files changed. Configuration, optimizer,
seed and import-descriptor backups and their hashes are in
`.tmp/release_compression_20261004/backup/` and `backup_manifest.json`.

For rollback, restore only the card files identified as optimized, and only
after checking that they still match this pass's recorded output hashes.
Restore the 50 changed import settings, remove the added Windows screenshot
exclusion, and disable Android native compression. Restore the optimizer patch
selectively and regenerate the seed digest from the resulting bundled content.
Reimport and rebuild. Do not restore whole shared files blindly or overwrite
later/unrelated changes. Backups are local and should be retained until the
compressed release is accepted.
