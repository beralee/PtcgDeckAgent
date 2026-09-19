"""Copy a frozen public working-tree snapshot without touching the live editor."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    destination = args.destination.resolve()
    destination.mkdir(parents=True, exist_ok=False)
    names = subprocess.check_output(["git", "ls-files", "-c", "-o", "--exclude-standard", "-z"], cwd=root).decode().split("\0")
    digests = {}
    for name in sorted(set(names)):
        source = root / name
        if not name or not source.is_file() or Path(name).parts[0] in (".tmp", ".codex", ".godot", ".godot_test_user"):
            continue
        target = destination / name
        target.parent.mkdir(parents=True, exist_ok=True)
        data = source.read_bytes()
        target.write_bytes(data)
        digests[name] = hashlib.sha256(data).hexdigest().upper()
    shutil.copytree(root / ".godot/imported", destination / ".godot/imported")
    for name in ("global_script_class_cache.cfg", "uid_cache.bin", "extension_list.cfg", "export_credentials.cfg"):
        source = root / ".godot" / name
        if source.is_file(): shutil.copy2(source, destination / ".godot" / name)
    (destination.parent / "source-manifest.json").write_text(json.dumps(digests, indent=2), encoding="utf-8")
    print(f"Frozen {len(digests)} public files in {destination}")


if __name__ == "__main__":
    main()
