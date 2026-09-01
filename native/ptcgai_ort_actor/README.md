# PtcgAI ORT Actor GDExtension

This platform-owned extension is the only native boundary used by `.ptcgai` v2 model packages. Packages contain a frozen `actor.ort`; they never contain a DLL, dylib, custom operator, Python runtime, network client, or download instruction.

Configure with pinned Godot C++ bindings and the official ONNX Runtime C/C++ distribution, then build `template_release`. The runtime fixes CPU execution, one intra/inter-op thread, fixed tensor shapes, a 25 ms cancelable hard deadline, and stable fail-closed error codes.

Use `build_windows.ps1` on Windows x86_64 or `build_macos.sh arm64|x86_64` on macOS. Both scripts require explicit pinned dependency roots and place only the platform extension plus the adjacent ONNX Runtime shared library in `res://bin/ptcgai_ort`. The macOS build uses `@loader_path`, so it never depends on a developer-machine absolute library path.
