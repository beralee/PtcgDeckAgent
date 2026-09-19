#!/usr/bin/env bash
set -euo pipefail

[[ "$(uname -s)" == Darwin ]] || { echo "Run this build on macOS." >&2; exit 2; }
: "${GODOT_CPP_ROOT:?GODOT_CPP_ROOT is required}"
# Inputs may be single-architecture or universal; outputs are always universal.
ort_arm64="${ONNXRUNTIME_ARM64_ROOT:-${ONNXRUNTIME_ROOT:-}}"
ort_x86_64="${ONNXRUNTIME_X86_64_ROOT:-${ONNXRUNTIME_ROOT:-}}"
[[ -n "$ort_arm64" && -n "$ort_x86_64" ]] || { echo "Set ONNXRUNTIME_ROOT or both architecture-specific roots." >&2; exit 2; }

source_root="$(cd "$(dirname "$0")" && pwd)"
project_root="$(cd "$source_root/../.." && pwd)"
stage_root="$source_root/build/macos-universal"
output_root="$project_root/bin/ptcgai_ort"
mkdir -p "$stage_root" "$output_root"

for arch in x86_64 arm64; do
  ort_root="$ort_x86_64"
  min_os=10.12
  if [[ "$arch" == arm64 ]]; then ort_root="$ort_arm64"; min_os=11.0; fi
  python3 -c 'import hashlib,json,sys; m=json.load(open(sys.argv[1])); assert m["onnxruntime_source_commit"] == "8c546c37b43caaca1fa25db430dab94b901cf277"; assert m["platform"] in ("macos."+sys.argv[2], "macos.universal"); assert m["runtime_sha256"] == hashlib.sha256(open(sys.argv[3],"rb").read()).hexdigest()' "$ort_root/runtime-build.json" "$arch" "$ort_root/lib/libonnxruntime.dylib"
  lipo -verify_arch "$arch" "$ort_root/lib/libonnxruntime.dylib"
  build_root="$source_root/build/macos-$arch"
  cmake -S "$source_root" -B "$build_root" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_ARCHITECTURES="$arch" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="$min_os" \
    -DGODOT_CPP_ROOT="$GODOT_CPP_ROOT" -DONNXRUNTIME_ROOT="$ort_root"
  cmake --build "$build_root" --config Release --parallel 4
  if otool -L "$build_root/libptcgai_ort.macos.template_release.$arch.dylib" | tail -n +2 | grep -q onnxruntime; then
    echo "Extension must load ORT lazily." >&2; exit 1
  fi
  if [[ "$(lipo -archs "$ort_root/lib/libonnxruntime.dylib")" == "$arch" ]]; then
    cp "$ort_root/lib/libonnxruntime.dylib" "$stage_root/ort.$arch.dylib"
  else
    lipo "$ort_root/lib/libonnxruntime.dylib" -extract "$arch" -output "$stage_root/ort.$arch.dylib"
  fi
done

lipo -create \
  "$source_root/build/macos-x86_64/libptcgai_ort.macos.template_release.x86_64.dylib" \
  "$source_root/build/macos-arm64/libptcgai_ort.macos.template_release.arm64.dylib" \
  -output "$output_root/libptcgai_ort.macos.template_release.universal.dylib"
lipo -create "$stage_root/ort.x86_64.dylib" "$stage_root/ort.arm64.dylib" -output "$output_root/libonnxruntime.dylib"
install_name_tool -id '@rpath/libonnxruntime.dylib' "$output_root/libonnxruntime.dylib"
install_name_tool -id '@rpath/libptcgai_ort.macos.template_release.universal.dylib' "$output_root/libptcgai_ort.macos.template_release.universal.dylib"
for file in "$output_root/libptcgai_ort.macos.template_release.universal.dylib" "$output_root/libonnxruntime.dylib"; do
  lipo -verify_arch x86_64 arm64 "$file"
  codesign --force --sign - "$file"
done
echo "Built universal extension and ORT. Validate the exported .app with verify_macos_bundle.sh."
