# Android compact APK — 2026-09-30

This is the requested ARM64 UI test package from the recorded v17 source snapshot.
It does not mark Android frame-time performance accepted or publish an updater
release. The output directory is
`D:/ai/scratch/arena-portable-20260930/parity/apk-ui-v18-compact/`.

## Package changes

The original APK was 301,382,397 bytes. The compact signed APK is **192,527,878
bytes** (192.53 MB decimal, 183.61 MiB), a 36.12% reduction.

- Enable Godot's Android `gradle_build/compress_native_libraries` option. The
  native libraries are compressed in the APK and extracted by Android during
  installation; their decompressed bytes match the previous APK exactly.
- The 28 stadium backgrounds previously used lossless imported textures despite
  having compressed WebP sources. The isolated Android export imports them with
  `compress/mode=1`, quality 0.85, preserving 1920×1080 dimensions. Their imported
  payload falls from 58,136,032 to 9,149,906 bytes. Original desktop assets and
  import settings in the working repository remain unchanged.
- Exclude CLI-only `scripts/tools/Arena*` and `scripts/performance/Arena*` probes
  from the player APK. `PerformanceTrace` and the regular game scripts remain.
  Exactly 46 probe/remap members are removed. No card, deck, strategy, model,
  supporter pose, sound or live interaction is removed.
- Every bundled-user-data member, including card images, has the same content
  as before. All non-probe game script payloads are unchanged.

The snapshot-only preparation/export scripts and exact before files are saved
beside the APK (`prepare_compact.py`, `export.ps1`, `profile.json`, `before/`).
The public v17 source manifest SHA256 is
`d03c01142f822f77ba5f47d187c61214d0ed592cf393d78bc10e14f2e5b2dec5`.

The relevant engine options are documented by
[Godot's Android exporter](https://docs.godotengine.org/en/4.6/classes/class_editorexportplatformandroid.html#class-editorexportplatformandroid-property-gradle-build-compress-native-libraries)
and [texture importer](https://docs.godotengine.org/en/4.6/classes/class_resourceimportertexture.html#class-resourceimportertexture-property-compress-mode).

## Verification

- APK v2 signature, ARM64 native dependency closure, C++ symbols, 16 KB ELF/ZIP
  alignment, updater and player resource inventories pass.
- Portable inventory checks 156 known arena import targets and retains all 121
  required shared/portable resource paths.
- All 28 imported textures load at their original dimensions. Three inspected
  backgrounds have PSNR 39.17–41.69 dB relative to the source and mean absolute
  RGB channel error 1.50–2.09 out of 255; the actual decoded images were inspected.
- The actual ARM64 APK installs over the emulator's existing version 0.6.2,
  preserves its user data and opens the normal main menu without script errors
  or a fatal exception. The previous APK was backed up locally. This emulator
  uses Android's ARM translation, not physical ARM hardware.
- Expanded diagnostic visual/input checks pass **4/4** at actual 1080×2400 and
  2400×1080, with no engine script errors. Both orientations exercise all 14
  Pokémon and 18 supporters and the full touch/prize/search/rotation checks.
  Evidence: `parity/android-acceptance-v18-compact/summary.json`.
- All 86 overwritten snapshot configuration/import/cache files were restored
  and hash-checked after exports; the primary worktree resources were not edited.

## Two-volume delivery

APK: `PtcgDeckDojo-0.6.2-20260930-3D-UI-compact-arm64.apk`

SHA256: `54e37d2f1b5c181e77ed10c9fb02005322eddbbef5d849f99acc59d53bf16d7e`

The APK is inside a two-volume 7z archive, made using the official 7-Zip CLI:

| File | Bytes | MD5 |
| --- | ---: | --- |
| `PtcgDeckDojo-0.6.2-20260930-arm64.7z.001` | 100,000,000 | `687975eba1594b9212a3580f80a9c4f9` |
| `PtcgDeckDojo-0.6.2-20260930-arm64.7z.002` | 91,408,517 | `0833811d132ff310615d29881d3e7d60` |

Both volumes are below the connected Drive transfer limit of 104,857,600 bytes.
The archive test passed, and streaming extraction reproduced the APK SHA256
exactly. Download both parts into one directory, open `.001` with a tool that
supports 7z volumes, and install the extracted APK. The parts are not independent
APK files. Upload uses the already authorized Drive connector; rclone remains
unauthorized because the user cannot complete its separate sign-in.

Both volumes were uploaded successfully and their names and exact byte sizes
were verified through Drive metadata readback. The connector does not expose
the requested remote MD5 field, so the checksums above describe local files.
The upload receipt is saved beside the APK as `drive-upload-receipt.json`.

- [Download volume 001](https://drive.google.com/file/d/1RS05HcOAiLSM9fx5NDAVsH-M_R986Vgq/view?usp=drivesdk)
- [Download volume 002](https://drive.google.com/file/d/1Rmx654ZuNsa_7kwj5tm52Pizp-f7KSyB/view?usp=drivesdk)
