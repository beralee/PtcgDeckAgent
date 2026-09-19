# PtcgAI ORT Actor GDExtension

This platform-owned extension is the only native boundary used by `.ptcgai` v2 model packages. Packages contain a frozen `actor.ort`; they never contain a DLL, dylib, custom operator, Python runtime, network client, or download instruction.

The runtime fixes CPU execution, one intra/inter-op thread, fixed integer tensor shapes, and a 25 ms inference budget. A reusable native worker measures execution on the producer thread; thread dispatch and delayed consumer wake-up cannot silently consume the inference budget. Dispatch has a separate one-second guard, and `dispatch_us` records its cost. Cancellation cleanup is separately reported as `cancel_cleanup_us`; the budget is not an asserted end-to-end hard deadline. ORT exceptions return stable failure codes rather than terminating the game. `tests/inference_worker_test.cpp` verifies thread reuse, producer-side timing, exception propagation and recovery.

## Dependency and runtime boundary

Model activation also runs one bounded fixed-shape zero-data warmup (500 ms
budget, with the same cancellation cleanup). Cold session initialization is
completed before accepting a public decision. Its output has no action authority;
normal decisions retain the 25 ms limit. `load_actor` reports `warmup_elapsed_us`
or rejects the session with `model_warmup_failed`. Windows builds run the native
worker regression automatically before staging the DLL.

`dependencies.lock.json` pins Godot 4.6.1, godot-cpp commit `58d1de720b8ffe9f8ffcdfe3a85148582cfd2e74`, ORT source commit `8c546c37b43caaca1fa25db430dab94b901cf277`, and Android NDK r28c (`28.2.13676358`). The existing Windows ORT DLL hash is also pinned. Source builds need Python 3.10+, CMake 3.28+ (validated with 3.31.6) and Ninja; none are player dependencies. Queue builds serially and use at most four jobs.

`PtcgOrtActor.get_runtime_info()` returns `available`, `error_code`, `runtime`, `version`, `execution_provider`, `api_version`, `source_commit`, and `library_loaded`. It initializes the C API on demand without allocating an ORT environment or model session. `load_actor(bytes)` and `run(...)` keep their existing interfaces.

On macOS and Android, the extension is a small loader with no strong ORT dependency and no eager ORT initialization. It checks macOS 13.3 / Android API 29 before loading the adjacent application-bundled runtime by absolute path. It never searches the current directory or a strategy archive. The small extension itself targets macOS 10.12 (Intel), 11.0 (Apple Silicon), and Android API 24, so the game's older system floor is preserved. Android x86, iOS, Web and the Linux dedicated server receive no model backend in this phase.

## Windows

Run `build_windows.ps1 -GodotCppRoot <checkout> -OnnxRuntimeRoot <pinned-distribution>`, adding `-CmakePath`, `-NinjaPath` and `-VsDevCmdPath` when needed. It writes the v3 extension and pinned ORT DLL into `bin/ptcgai_ort`, then records hashes in `build/windows-x86_64/runtime-build.json`. Previous extensions remain available for rollback; they are not referenced by the new GDExtension descriptor. This also allows deployment without replacing a DLL currently held by a running game.

Run `verify_windows_native.ps1 -Directory <export-directory>` on the exported executable's adjacent libraries. Merely finding a DLL in the source project does not prove it was exported.

## Android ARM64 and x86_64

1. Prepare a clean ORT checkout at the pinned source commit and install the pinned NDK.
2. On Windows run `build_onnxruntime.ps1 -SourceRoot <ort-checkout> -BuildRoot <separate-build-dir> -OutputRoot <staged-ort-dir> -AndroidSdkRoot <sdk> -NdkRoot <ndk> -CmakePath <cmake> -NinjaPath <ninja>`. This builds the full CPU runtime with shared libc++, API 29, and 16 KB alignment. It writes headers, the runtime, license and build provenance.
3. Run `build_android.ps1 -GodotCppRoot <checkout> -OnnxRuntimeRoot <staged-ort-dir> -NdkRoot <ndk> -CmakePath <cmake> -NinjaPath <ninja>`. This builds the API 24 loader, checks staged ELF dependencies and alignment against the NDK C++ runtime, and installs the extension and ORT into `bin/ptcgai_ort`.
4. Export using the existing Android preset. No Gradle/AAR project is needed. The standard Godot template already supplies `libc++_shared.so`; do not declare a second copy as a GDExtension dependency, as duplicate APK entries break signing. `verify_android_native.ps1 -ApkPath <apk> -NdkRoot <ndk> -ZipalignPath <sdk-build-tools/zipalign.exe>` checks all ARM64 ELF libraries in the actual APK, their dependency closure, required C++ symbol availability in the template's runtime, and APK ZIP alignment.

`export_ptcgdap_device_release.ps1` performs these checks and records native inventories. It discovers tools from Android SDK/NDK environment variables, the standard SDK installation, or the completed native build cache. Supply `-AndroidNdkRoot` and `-ZipalignPath` only when discovery is insufficient; existing Android UI test invocations remain compatible. Both 4 KB and 16 KB device tests remain required after structural verification; an aligned ELF alone is not runtime evidence.

For an x86_64 Android emulator, pass `-Architecture x86_64` to the ORT build,
extension build and native verification scripts, using separate ORT build and
output directories. The extension stages that architecture under
`bin/ptcgai_ort/android-x86_64`; it never overwrites the ARM64 runtime. Enable
`architectures/x86_64` in the export being tested. The parity export builder
accepts `-AndroidArchitecture x86_64` and changes only its isolated snapshot.
The regression runner requires the APK ABI to match the device's primary ABI:
ARM translation on an x86_64 emulator is not accepted as native device evidence.

## macOS universal

The 0.6.0 Mac release currently ships without this model backend by explicit
release choice. The macOS export preset excludes the native descriptor/binaries,
and the platform capability owner disables models while retaining rules. See
`docs/ptcgdap/macos-rules-only-release-20260916.md` for validation and the coordinated
steps required to restore model support; building the libraries alone does not
re-enable the shipped capability.

On a Mac, set `ONNXRUNTIME_SOURCE_ROOT`, `ONNXRUNTIME_BUILD_ROOT` and `ONNXRUNTIME_OUTPUT_ROOT`, then run `bash build_onnxruntime_macos.sh`. The Intel and Apple Silicon runtimes are built serially at minimum macOS 13.3 into separate directories.

Set `GODOT_CPP_ROOT`, `ONNXRUNTIME_ARM64_ROOT=<output>/arm64`, and `ONNXRUNTIME_X86_64_ROOT=<output>/x86_64`, then run `bash build_macos.sh`. A prebuilt universal runtime may instead be supplied with `ONNXRUNTIME_ROOT` and matching provenance. The script builds and validates both loader slices, combines both loader and ORT into universal binaries, sets application-relative install names, and signs the output ad hoc. It never overwrites one architecture with the other.

Godot's descriptor exports both libraries into `Contents/Frameworks`. Run `bash verify_macos_bundle.sh <Game.app>` after export/signing to verify architectures, dependency closure and signatures. A distribution identity/notarization remains a release operation; the build script does not publish or notarize. Test Intel and Apple Silicon independently, including an older system where only the loader should load.

## Focused verification

Run Godot headlessly with `tests/ai/ptcgdap/test_ptcgai_ort_runtime_info.gd` to verify runtime information and recoverable malformed-model handling. Use `-- --expect-unavailable` on an unsupported target or a controlled fixture with the optional ORT library absent. `test_ptcgai_ort_inference_smoke.gd -- --actor=<actor.ort>` performs real CPU inference; `test_platform_model_inference.gd` adds a deterministic cross-platform fixture.

Source tests, actual exported bundles, model output parity, and full-device battles are separate acceptance gates. Do not mark a platform supported based solely on build success or a rules fallback. Missing ORT dependencies must remain an actionable preflight failure for model packages while ordinary gameplay remains available.
