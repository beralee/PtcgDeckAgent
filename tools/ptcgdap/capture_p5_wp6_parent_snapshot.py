from __future__ import annotations

import argparse
import base64
import hashlib
import json
from pathlib import Path, PurePosixPath


ROOT = Path(__file__).resolve().parents[2]
WORK_PACKAGE = ROOT / "artifacts/ptcgdap/p5_wp6/work_package.json"
OUTPUT_ROOT = ROOT / "artifacts/ptcgdap/p5_wp6/parent_snapshot"
SUPPLEMENTAL_ROOT = ROOT / "artifacts/ptcgdap/p5_wp6/supplemental_parent_snapshot"


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
    parser.add_argument("--supplemental", action="store_true")
    args = parser.parse_args()
    work = json.loads(WORK_PACKAGE.read_text(encoding="utf-8"))
    files = work["files_allowed"]
    all_restore_paths = [safe_repo_path(path) for path in [
        *files["existing_docs"],
        *files["existing_compatibility_tests"],
        *files["existing_runtime_optimizations"],
    ]]
    supplemental_paths = [
        "scripts/ai/ptcgdap/cabt/CabtContractSet.gd",
        "tests/ptcgdap/test_p2_wp3_boundaries.py",
        "tests/ptcgdap/test_p4_wp1_boundaries.py",
        "tests/ptcgdap/test_p4_wp2_boundaries.py",
        "tests/ptcgdap/test_p4_wp3_boundaries.py",
        "tests/ptcgdap/test_p4_wp4_boundaries.py",
        "tests/ptcgdap/test_p5_wp5_parent_snapshot.py",
    ]
    restore_paths = supplemental_paths if args.supplemental else [path for path in all_restore_paths if path not in supplemental_paths]
    delete_paths = [safe_repo_path(path) for path in [*files["contracts"], *files["data"], *files["implementation"], *files["tests"]]]
    expected_count = 7 if args.supplemental else 19
    if len(restore_paths) != expected_count or len(all_restore_paths) != 26 or len(all_restore_paths) != len(set(all_restore_paths)):
        raise SystemExit("unexpected parent restore paths")
    if len(delete_paths) != 16 or len(delete_paths) != len(set(delete_paths)):
        raise SystemExit("expected 16 unique additive paths")
    if set(restore_paths) & set(delete_paths):
        raise SystemExit("restore/delete path overlap")
    output_root = SUPPLEMENTAL_ROOT if args.supplemental else OUTPUT_ROOT
    output_root.mkdir(parents=True, exist_ok=True)
    existing = list(output_root.iterdir())
    extending_supplemental = args.supplemental and existing and not args.replace
    if existing and not args.replace and not extending_supplemental:
        raise SystemExit("snapshot already exists; use --replace only while parent bytes are unchanged")
    if args.replace:
        for path in existing:
            if not path.is_file():
                raise SystemExit(f"unexpected snapshot directory entry: {path}")
            path.unlink()
    entries = []
    existing_entries = {}
    if extending_supplemental:
        prior = json.loads((output_root / "manifest.json").read_text(encoding="utf-8"))
        existing_entries = {entry["original_path"]: entry for entry in prior["files"]}
    for relative in restore_paths:
        if relative in existing_entries:
            entries.append(existing_entries[relative])
            continue
        value = (ROOT / relative).read_bytes()
        name = payload_name(relative)
        payload = encode(value)
        (output_root / name).write_bytes(payload)
        entries.append({
            "original_path": relative,
            "snapshot_path": name,
            "bytes": len(value),
            "raw_sha256": sha(value),
            "snapshot_file_bytes": len(payload),
            "snapshot_file_raw_sha256": sha(payload),
        })
    manifest = {
        "schema_version": 1,
        "work_package": "P5-WP6-supplemental" if args.supplemental else "P5-WP6",
        "captured_at": "2026-08-11T10:00:00+08:00",
        "file_count": len(entries),
        "parent": {
            "work_package": "P5-WP5",
            "manifest_path": work["entry_evidence"]["parent_manifest_path"],
            "manifest_raw_sha256": work["entry_evidence"]["parent_manifest_raw_sha256"],
            "manifest_canonical_sha256": work["entry_evidence"]["parent_manifest_canonical_sha256"],
            "worktree_entry_count": work["entry_evidence"]["parent_candidate_entry_count"],
            "worktree_status_counts": {"untracked": 1295, "deleted": 28, "modified": 1},
            "worktree_snapshot_canonical_sha256": work["entry_evidence"]["parent_candidate_canonical_sha256"],
        },
        "files": entries,
        "rollback_scope": {
            "restore_exact_paths": restore_paths,
            "delete_exact_paths": [] if args.supplemental else delete_paths,
            "delete_evidence_prefix": "artifacts/ptcgdap/p5_wp6/",
        },
    }
    output = (json.dumps(manifest, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
    (output_root / "manifest.json").write_bytes(output)
    print(f"captured {len(entries)} files")
    print(f"manifest_raw_sha256={sha(output)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
