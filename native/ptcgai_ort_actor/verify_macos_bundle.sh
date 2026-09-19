#!/usr/bin/env bash
set -euo pipefail

app="${1:?usage: verify_macos_bundle.sh /path/Game.app}"
frameworks="$app/Contents/Frameworks"
extension="$frameworks/libptcgai_ort.macos.template_release.universal.dylib"
runtime="$frameworks/libonnxruntime.dylib"
for file in "$extension" "$runtime"; do
  [[ -f "$file" ]] || { echo "Missing native library: $file" >&2; exit 1; }
  lipo -verify_arch x86_64 arm64 "$file"
  codesign --verify --strict "$file"
  for arch in x86_64 arm64; do
    while IFS= read -r dependency; do
      case "$dependency" in
        /usr/lib/*|/System/Library/*) ;;
        @rpath/*) [[ -f "$frameworks/${dependency#@rpath/}" ]] || exit 1 ;;
        @loader_path/*) [[ -f "$frameworks/${dependency#@loader_path/}" ]] || exit 1 ;;
        *) echo "Unbundled or absolute dependency: $dependency" >&2; exit 1 ;;
      esac
    done < <(otool -arch "$arch" -L "$file" | tail -n +2 | awk '{ print $1 }')
    minimum="$(otool -arch "$arch" -l "$file" | awk '$1 == "cmd" { command=$2 } (command == "LC_BUILD_VERSION" && $1 == "minos") || (command == "LC_VERSION_MIN_MACOSX" && $1 == "version") { print $2 }')"
    floor=13.3
    if [[ "$file" == "$extension" ]]; then
      floor=10.12
      if [[ "$arch" == arm64 ]]; then floor=11.0; fi
    fi
    python3 -c 'import sys; v=lambda s: tuple((list(map(int,s.split(".")))+[0,0])[:3]); assert sys.argv[1] and v(sys.argv[1]) <= v(sys.argv[2]), "Native minimum OS exceeds capability floor"' "$minimum" "$floor"
  done
done
if otool -L "$extension" | tail -n +2 | grep -q onnxruntime; then
  echo "Extension must not strongly link ORT." >&2; exit 1
fi
codesign --verify --deep --strict "$app"
echo 'Universal native dependency closure and signatures verified. Runtime/device tests are separate gates.'
