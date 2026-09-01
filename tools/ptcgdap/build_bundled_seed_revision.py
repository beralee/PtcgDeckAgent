from __future__ import annotations

import argparse
import hashlib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "data/bundled_user/_manifest.txt"
REVISION = ROOT / "data/bundled_user/_seed_content_sha256.txt"


def compute_revision() -> str:
    digest = hashlib.sha256()
    entries = [line.strip() for line in MANIFEST.read_text(encoding="utf-8").splitlines() if line.strip()]
    if len(entries) != len(set(entries)):
        raise ValueError("bundled seed manifest must be duplicate-free")
    for resource_path in sorted(entries):
        if not resource_path.startswith("res://"):
            raise ValueError(f"invalid bundled seed resource path: {resource_path}")
        path = ROOT / resource_path.removeprefix("res://")
        digest.update(resource_path.encode("utf-8"))
        digest.update(b"\0")
        digest.update(hashlib.sha256(path.read_bytes()).digest() if path.is_file() else b"MISSING")
        digest.update(b"\n")
    return digest.hexdigest().upper()


def main() -> int:
    parser = argparse.ArgumentParser(description="Build or verify the bundled-user seed content revision.")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    actual = compute_revision()
    if args.check:
        expected = REVISION.read_text(encoding="utf-8").strip() if REVISION.is_file() else ""
        if expected != actual:
            raise SystemExit(f"bundled seed revision mismatch: expected={expected!r} actual={actual}")
    print(actual)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
