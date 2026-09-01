#!/usr/bin/env bash
set -euo pipefail

arch="${1:-}"
if [[ "$arch" != "arm64" && "$arch" != "x86_64" ]]; then
  echo "usage: GODOT_CPP_ROOT=/path ONNXRUNTIME_ROOT=/path $0 arm64|x86_64" >&2
  exit 2
fi
: "${GODOT_CPP_ROOT:?GODOT_CPP_ROOT is required}"
: "${ONNXRUNTIME_ROOT:?ONNXRUNTIME_ROOT is required}"

source_root="$(cd "$(dirname "$0")" && pwd)"
project_root="$(cd "$source_root/../.." && pwd)"
build_root="$source_root/build/macos-$arch"
output_root="$project_root/bin/ptcgai_ort"

cmake -S "$source_root" -B "$build_root" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_OSX_ARCHITECTURES="$arch" \
  -DGODOT_CPP_ROOT="$GODOT_CPP_ROOT" \
  -DONNXRUNTIME_ROOT="$ONNXRUNTIME_ROOT"
cmake --build "$build_root" --config Release

mkdir -p "$output_root"
cp "$build_root/libptcgai_ort.macos.template_release.$arch.dylib" "$output_root/"
cp "$ONNXRUNTIME_ROOT/lib/libonnxruntime.dylib" "$output_root/"
