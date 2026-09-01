from __future__ import annotations

import argparse
import base64
import hashlib
import json
from pathlib import Path, PurePosixPath


ROOT = Path(__file__).resolve().parents[2]
WORK_PACKAGE = ROOT / "artifacts/ptcgdap/p5_wp1/work_package.json"
OUTPUT_ROOT = ROOT / "artifacts/ptcgdap/p5_wp1/parent_snapshot"


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def safe_repo_path(raw: object) -> str:
    if not isinstance(raw, str) or not raw or "\\" in raw or "\0" in raw:
        raise ValueError(f"unsafe path: {raw!r}")
    path = PurePosixPath(raw)
    if path.is_absolute() or "." in path.parts or ".." in path.parts or ":" in path.parts[0] or path.as_posix() != raw:
        raise ValueError(f"unsafe path: {raw!r}")
    return raw


def payload_name(path: str) -> str:
    return path.replace("/", "__") + ".base64"


def encode(value: bytes) -> bytes:
    encoded = base64.b64encode(value)
    return b"\n".join(encoded[index : index + 4096] for index in range(0, len(encoded), 4096)) + b"\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--replace", action="store_true")
    args = parser.parse_args()
    work = json.loads(WORK_PACKAGE.read_text(encoding="utf-8"))
    files = work["files_allowed"]
    restore_paths = [safe_repo_path(path) for path in [*files["existing_docs"], *files["existing_compatibility_tests"]]]
    if len(restore_paths) != 36 or len(restore_paths) != len(set(restore_paths)):
        raise SystemExit("expected 36 unique parent restore paths")
    delete_paths = [
        *files["contracts"],
        *files["data"],
        *files["implementation"],
        *files["tests"],
    ]
    delete_paths = [safe_repo_path(path) for path in delete_paths]
    if len(delete_paths) != 21 or len(delete_paths) != len(set(delete_paths)):
        raise SystemExit("expected 21 unique additive paths")
    if set(restore_paths) & set(delete_paths):
        raise SystemExit("restore/delete path overlap")
    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
    existing = list(OUTPUT_ROOT.iterdir())
    if existing and not args.replace:
        raise SystemExit("snapshot already exists; use --replace after verifying parent bytes are still unchanged")
    if args.replace:
        for path in existing:
            if not path.is_file():
                raise SystemExit(f"unexpected snapshot directory entry: {path}")
            path.unlink()
    entries = []
    for path in restore_paths:
        source_path = ROOT / path
        value = source_path.read_bytes()
        name = payload_name(path)
        payload = encode(value)
        (OUTPUT_ROOT / name).write_bytes(payload)
        entries.append(
            {
                "original_path": path,
                "snapshot_path": name,
                "bytes": len(value),
                "raw_sha256": sha(value),
                "snapshot_file_bytes": len(payload),
                "snapshot_file_raw_sha256": sha(payload),
            }
        )
    manifest = {
        "schema_version": 1,
        "work_package": "P5-WP1",
        "captured_at": "2026-08-11T03:00:00+08:00",
        "file_count": len(entries),
        "parent": {
            "work_package": "P4-WP6",
            "manifest_path": "artifacts/ptcgdap/p4_wp6/manifest.json",
            "manifest_raw_sha256": work["entry_evidence"]["parent_manifest_raw_sha256"],
            "manifest_canonical_sha256": work["entry_evidence"]["parent_manifest_canonical_sha256"],
            "worktree_entry_count": work["entry_evidence"]["parent_candidate_entry_count"],
            "worktree_status_counts": {"untracked": 965, "deleted": 28, "modified": 1},
            "worktree_snapshot_canonical_sha256": work["entry_evidence"]["parent_candidate_canonical_sha256"],
        },
        "files": entries,
        "rollback_scope": {
            "restore_exact_paths": restore_paths,
            "delete_exact_paths": delete_paths,
            "delete_evidence_prefix": "artifacts/ptcgdap/p5_wp1/",
        },
    }
    manifest_bytes = (json.dumps(manifest, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
    (OUTPUT_ROOT / "manifest.json").write_bytes(manifest_bytes)
    print(f"captured {len(entries)} files")
    print(f"manifest_raw_sha256={sha(manifest_bytes)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
