from __future__ import annotations

import argparse
import base64
from collections import Counter
import hashlib
import json
from pathlib import Path, PurePosixPath
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


WORK_PACKAGE = ROOT / "artifacts/ptcgdap/as_wp5/work_package.json"
OUTPUT_ROOT = ROOT / "artifacts/ptcgdap/as_wp5/parent_snapshot"
PARENT_MANIFEST = ROOT / "artifacts/ptcgdap/as_wp4/manifest.json"
EXPECTED_PARENT_MANIFEST_RAW = "1C65FB41A15C433FCB43F29A354218B4D8BE93E46B9E0E762B338E9760554DB6"
EXPECTED_PARENT_MANIFEST_CANONICAL = "21E201F8C550781B95E45ED537BA0B3CAFE5FAFD078C46CC8D3E2AC16BC8A19F"
EXPECTED_MATCH_HOST_BUNDLE = "4BD207E9F9200E5AF9E2206A13EAF506382B6BA42BDEE3F0FEB5CA872885DBB9"
EXPECTED_SOURCE_LOCK = "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"
EXPECTED_PARENT_ENTRY_COUNT = 1774
EXPECTED_PARENT_COUNTS = {"deleted": 28, "modified": 7, "untracked": 1739}
EXPECTED_PARENT_DIGEST = "D8FEB0F9D8179ABAE07B2A6BB5CE2D657DE8700D65999DD74E81C300DE2BDA4F"


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def canonical_sha(path: Path) -> str:
    return sha(canonical_json_v1_bytes(load_json_strict(path)))


def safe_path(raw: object) -> str:
    if not isinstance(raw, str) or not raw or "\\" in raw or "\0" in raw:
        raise ValueError(f"unsafe path: {raw!r}")
    path = PurePosixPath(raw)
    if path.is_absolute() or "." in path.parts or ".." in path.parts or ":" in path.parts[0] or path.as_posix() != raw:
        raise ValueError(f"unsafe path: {raw!r}")
    return raw


def encode(value: bytes) -> bytes:
    encoded = base64.b64encode(value)
    return b"\n".join(encoded[index:index + 4096] for index in range(0, len(encoded), 4096)) + b"\n"


def status_records(excluded: set[str]) -> tuple[list[dict[str, object]], dict[str, int]]:
    output = subprocess.run(
        ["git", "status", "--porcelain=v1", "-z", "--untracked-files=all"],
        cwd=ROOT,
        check=True,
        capture_output=True,
    ).stdout
    records: list[dict[str, object]] = []
    counts: Counter[str] = Counter()
    for raw in output.split(b"\0"):
        if not raw:
            continue
        code = raw[:2].decode("ascii")
        path = safe_path(raw[3:].decode("utf-8").replace("\\", "/"))
        if path.startswith("artifacts/ptcgdap/as_wp5/") or path in excluded:
            continue
        if "R" in code or "C" in code:
            raise SystemExit("rename/copy is outside the snapshot algorithm")
        value = None if "D" in code else (ROOT / path).read_bytes()
        records.append({
            "path": path,
            "status": code,
            "bytes": None if value is None else len(value),
            "sha256": None if value is None else sha(value),
        })
        counts["untracked" if code == "??" else "deleted" if "D" in code else "modified"] += 1
    records.sort(key=lambda item: str(item["path"]))
    return records, dict(counts)


def scope(work: dict[str, object]) -> tuple[list[str], list[str]]:
    allowed = work.get("files_allowed")
    if not isinstance(allowed, dict):
        raise SystemExit("invalid files_allowed")
    restore = [
        *allowed["existing_project_files"],
        *allowed["existing_docs"],
        *allowed["existing_compatibility_files"],
    ]
    delete = list(allowed["as_wp5_additive"])
    restore = [safe_path(value) for value in restore]
    delete = [safe_path(value) for value in delete]
    if len(restore) != len(set(restore)) or len(delete) != len(set(delete)) or set(restore) & set(delete):
        raise SystemExit("invalid restore/delete scope")
    return restore, delete


def validate_parent(work: dict[str, object]) -> tuple[list[str], list[str]]:
    entry = work.get("entry_evidence")
    if not isinstance(entry, dict):
        raise SystemExit("invalid entry evidence")
    if sha(PARENT_MANIFEST.read_bytes()) != EXPECTED_PARENT_MANIFEST_RAW or canonical_sha(PARENT_MANIFEST) != EXPECTED_PARENT_MANIFEST_CANONICAL:
        raise SystemExit("AS-WP4 manifest drift")
    if entry.get("author_match_host_bundle_canonical_sha256") != EXPECTED_MATCH_HOST_BUNDLE:
        raise SystemExit("match Host bundle drift")
    if entry.get("source_lock_canonical_sha256") != EXPECTED_SOURCE_LOCK:
        raise SystemExit("source lock drift")
    restore, delete = scope(work)
    records, counts = status_records(set(delete))
    if len(records) != EXPECTED_PARENT_ENTRY_COUNT or counts != EXPECTED_PARENT_COUNTS:
        raise SystemExit(f"pre-AS-WP5 counts drift: {len(records)} {counts}")
    if sha(canonical_json_v1_bytes(records)) != EXPECTED_PARENT_DIGEST:
        raise SystemExit("pre-AS-WP5 worktree digest drift")
    return restore, delete


def render(work: dict[str, object], restore: list[str], delete: list[str]) -> tuple[dict[str, object], dict[str, bytes]]:
    files: list[dict[str, object]] = []
    payloads: dict[str, bytes] = {}
    for relative in restore:
        value = (ROOT / relative).read_bytes()
        name = relative.replace("/", "__") + ".base64"
        payload = encode(value)
        payloads[name] = payload
        files.append({
            "original_path": relative,
            "snapshot_path": name,
            "bytes": len(value),
            "raw_sha256": sha(value),
            "snapshot_file_bytes": len(payload),
            "snapshot_file_raw_sha256": sha(payload),
        })
    entry = work["entry_evidence"]
    manifest: dict[str, object] = {
        "schema_version": 1,
        "work_package": "AS-WP5",
        "captured_at": "2026-08-12T18:00:00+08:00",
        "file_count": len(files),
        "parent": {
            "work_package": "AS-WP4",
            "manifest_path": entry["parent_manifest_path"],
            "manifest_raw_sha256": entry["parent_manifest_raw_sha256"],
            "manifest_canonical_sha256": entry["parent_manifest_canonical_sha256"],
            "author_match_host_bundle_canonical_sha256": entry["author_match_host_bundle_canonical_sha256"],
            "source_lock_canonical_sha256": entry["source_lock_canonical_sha256"],
            "worktree_entry_count": entry["pre_as_wp5_worktree_entry_count"],
            "worktree_status_counts": entry["pre_as_wp5_worktree_status_counts"],
            "worktree_snapshot_canonical_sha256": entry["pre_as_wp5_worktree_canonical_sha256"],
        },
        "files": files,
        "rollback_scope": {
            "restore_exact_paths": restore,
            "delete_exact_paths": delete,
            "delete_evidence_prefix": "artifacts/ptcgdap/as_wp5/",
        },
    }
    return manifest, payloads


def extend_compatibility_snapshot(work: dict[str, object]) -> tuple[dict[str, object], dict[str, bytes]]:
    restore, delete = scope(work)
    if not OUTPUT_ROOT.is_dir() or not (OUTPUT_ROOT / "manifest.json").is_file():
        raise SystemExit("snapshot missing")
    manifest = load_json_strict(OUTPUT_ROOT / "manifest.json")
    if manifest.get("work_package") != "AS-WP5" or manifest.get("parent", {}).get("worktree_snapshot_canonical_sha256") != EXPECTED_PARENT_DIGEST:
        raise SystemExit("snapshot parent drift")
    existing = {safe_path(entry["original_path"]): entry for entry in manifest.get("files", [])}
    if not set(existing).issubset(set(restore)):
        raise SystemExit("existing snapshot scope is not a subset of the extended scope")
    payloads: dict[str, bytes] = {}
    files: list[dict[str, object]] = []
    for relative in restore:
        if relative in existing:
            entry = existing[relative]
            name = safe_path(entry["snapshot_path"])
            payloads[name] = (OUTPUT_ROOT / name).read_bytes()
            files.append(entry)
            continue
        value = (ROOT / relative).read_bytes()
        name = relative.replace("/", "__") + ".base64"
        payload = encode(value)
        payloads[name] = payload
        files.append({
            "original_path": relative,
            "snapshot_path": name,
            "bytes": len(value),
            "raw_sha256": sha(value),
            "snapshot_file_bytes": len(payload),
            "snapshot_file_raw_sha256": sha(payload),
        })
    manifest["file_count"] = len(files)
    manifest["files"] = files
    manifest["rollback_scope"] = {
        "restore_exact_paths": restore,
        "delete_exact_paths": delete,
        "delete_evidence_prefix": "artifacts/ptcgdap/as_wp5/",
    }
    return manifest, payloads


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--extend-compatibility", action="store_true")
    args = parser.parse_args()
    work = load_json_strict(WORK_PACKAGE)
    if args.extend_compatibility:
        if args.check:
            raise SystemExit("choose one mode")
        manifest, payloads = extend_compatibility_snapshot(work)
        rendered = {**payloads, "manifest.json": (json.dumps(manifest, ensure_ascii=False, indent=2) + "\n").encode("utf-8")}
        for name, value in rendered.items():
            (OUTPUT_ROOT / name).write_bytes(value)
        print(f"extended snapshot to {manifest['file_count']} files")
        data = rendered["manifest.json"]
        print(f"manifest_raw_sha256={sha(data)}")
        print(f"manifest_canonical_sha256={sha(canonical_json_v1_bytes(manifest))}")
        return 0
    restore, delete = validate_parent(work)
    manifest, payloads = render(work, restore, delete)
    rendered = {**payloads, "manifest.json": (json.dumps(manifest, ensure_ascii=False, indent=2) + "\n").encode("utf-8")}
    if args.check:
        actual = {path.name for path in OUTPUT_ROOT.iterdir() if path.is_file()} if OUTPUT_ROOT.is_dir() else set()
        if actual != set(rendered):
            raise SystemExit("snapshot file set drift")
        for name, value in rendered.items():
            if (OUTPUT_ROOT / name).read_bytes() != value:
                raise SystemExit(f"snapshot drift: {name}")
        print("AS-WP5 parent snapshot verified")
    else:
        if OUTPUT_ROOT.exists():
            raise SystemExit("snapshot already exists")
        OUTPUT_ROOT.mkdir(parents=True)
        for name, value in rendered.items():
            (OUTPUT_ROOT / name).write_bytes(value)
        print(f"captured {len(restore)} files")
    data = rendered["manifest.json"]
    print(f"manifest_raw_sha256={sha(data)}")
    print(f"manifest_canonical_sha256={sha(canonical_json_v1_bytes(manifest))}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
