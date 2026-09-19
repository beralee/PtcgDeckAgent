#!/usr/bin/env bash
set -euo pipefail

[[ "$(uname -s)" == Darwin ]] || { echo "Run on macOS." >&2; exit 2; }
: "${ONNXRUNTIME_SOURCE_ROOT:?Use the pinned ORT checkout}"
: "${ONNXRUNTIME_BUILD_ROOT:?Use a separate build directory}"
: "${ONNXRUNTIME_OUTPUT_ROOT:?Use a separate staged runtime directory}"
revision=8c546c37b43caaca1fa25db430dab94b901cf277
[[ "$(git -C "$ONNXRUNTIME_SOURCE_ROOT" rev-parse HEAD)" == "$revision" ]] || { echo "ORT source revision mismatch." >&2; exit 1; }
[[ -z "$(git -C "$ONNXRUNTIME_SOURCE_ROOT" status --porcelain --untracked-files=no)" ]] || { echo "ORT source has tracked changes." >&2; exit 1; }

for arch in x86_64 arm64; do
  build_root="$ONNXRUNTIME_BUILD_ROOT/$arch"
  output_root="$ONNXRUNTIME_OUTPUT_ROOT/$arch"
  python3 "$ONNXRUNTIME_SOURCE_ROOT/tools/ci_build/build.py" \
    --config Release --update --build --build_dir "$build_root" \
    --build_shared_lib --skip_tests --parallel 4 --cmake_generator Ninja \
    --cmake_extra_defines "CMAKE_OSX_ARCHITECTURES=$arch" \
    CMAKE_OSX_DEPLOYMENT_TARGET=13.3 onnxruntime_BUILD_UNIT_TESTS=OFF
  mkdir -p "$output_root/include" "$output_root/lib"
  cp "$ONNXRUNTIME_SOURCE_ROOT/include/onnxruntime/core/session/"*.h "$output_root/include/"
  cp -L "$build_root/Release/libonnxruntime.dylib" "$output_root/lib/libonnxruntime.dylib"
  cp "$ONNXRUNTIME_SOURCE_ROOT/LICENSE" "$output_root/"
  lipo -verify_arch "$arch" "$output_root/lib/libonnxruntime.dylib"
  runtime_hash="$(shasum -a 256 "$output_root/lib/libonnxruntime.dylib" | awk '{print $1}')"
  printf '{"schema_version":1,"platform":"macos.%s","onnxruntime_source_commit":"%s","minimum_macos":"13.3","runtime_sha256":"%s","device_tested":false}\n' \
    "$arch" "$revision" "$runtime_hash" > "$output_root/runtime-build.json"
done
echo "Use ONNXRUNTIME_ARM64_ROOT=$ONNXRUNTIME_OUTPUT_ROOT/arm64 and ONNXRUNTIME_X86_64_ROOT=$ONNXRUNTIME_OUTPUT_ROOT/x86_64 with build_macos.sh."
