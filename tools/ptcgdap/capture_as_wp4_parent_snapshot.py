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


WORK_PACKAGE = ROOT / "artifacts/ptcgdap/as_wp4/work_package.json"
OUTPUT_ROOT = ROOT / "artifacts/ptcgdap/as_wp4/parent_snapshot"
PARENT_MANIFEST = ROOT / "artifacts/ptcgdap/as_wp3/manifest.json"
EXPECTED_PARENT_MANIFEST_RAW = "8C49F3E12149AE5869FE91C45AE2B757A6D03BBD52ADFC4323C6AF7F4ECCDD06"
EXPECTED_PARENT_MANIFEST_CANONICAL = "E65CDA3B195E5C8FD521AAD7BE812C1083B954DBCAB7314A24F60FAD3502F7B6"
EXPECTED_PACKAGE_BUNDLE = "B416F2CBA2795B62126B6EF7B5F07A9000E84D5FA1DF62C1753CADC9E82E106B"
EXPECTED_SOURCE_LOCK = "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"
EXPECTED_PARENT_ENTRY_COUNT = 1722
EXPECTED_PARENT_COUNTS = {"deleted": 28, "modified": 7, "untracked": 1687}
EXPECTED_PARENT_DIGEST = "980DE58954F5E5BE7C1BDC4E2ACA0DE595F00B893233CB5ED82753489FD7352F"


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def canonical_sha(path: Path) -> str:
    return sha(canonical_json_v1_bytes(load_json_strict(path)))


def safe_repo_path(raw: object) -> str:
    if not isinstance(raw, str) or not raw or "\\" in raw or "\0" in raw:
        raise ValueError(f"unsafe path: {raw!r}")
    path = PurePosixPath(raw)
    if path.is_absolute() or "." in path.parts or ".." in path.parts or ":" in path.parts[0] or path.as_posix() != raw:
        raise ValueError(f"unsafe path: {raw!r}")
    return raw


def encode(value: bytes) -> bytes:
    encoded = base64.b64encode(value)
    return b"\n".join(encoded[index : index + 4096] for index in range(0, len(encoded), 4096)) + b"\n"


def decode_existing(entry: dict[str, object]) -> bytes:
    name = safe_repo_path(entry["snapshot_path"])
    if "/" in name:
        raise SystemExit("nested snapshot payload")
    source = (OUTPUT_ROOT / name).read_bytes()
    if not source.endswith(b"\n") or b"\r" in source:
        raise SystemExit(f"invalid existing snapshot payload: {name}")
    encoded = b"".join(source[:-1].split(b"\n"))
    value = base64.b64decode(encoded.decode("ascii"), validate=True)
    if len(value) != entry["bytes"] or sha(value) != entry["raw_sha256"]:
        raise SystemExit(f"existing snapshot payload drift: {name}")
    return value


def status_records(excluded_prefix: str, excluded_paths: set[str]) -> tuple[list[dict[str, object]], dict[str, int]]:
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
        path = safe_repo_path(raw[3:].decode("utf-8").replace("\\", "/"))
        if "R" in code or "C" in code:
            raise SystemExit("rename/copy outside snapshot algorithm")
        if path.startswith(excluded_prefix) or path in excluded_paths:
            continue
        value = None if "D" in code else (ROOT / path).read_bytes()
        records.append(
            {
                "path": path,
                "status": code,
                "bytes": None if value is None else len(value),
                "sha256": None if value is None else sha(value),
            }
        )
        counts["untracked" if code == "??" else "deleted" if "D" in code else "modified"] += 1
    records.sort(key=lambda item: str(item["path"]))
    return records, dict(counts)


def _scope(work: dict[str, object]) -> tuple[list[str], list[str]]:
    allowed = work["files_allowed"]
    if not isinstance(allowed, dict):
        raise SystemExit("invalid files_allowed")
    restore_paths = [
        *allowed["existing_project_files"],
        *allowed["existing_docs"],
        *allowed["existing_compatibility_files"],
    ]
    delete_paths = list(allowed["as_wp4_additive"])
    restore_paths = [safe_repo_path(path) for path in restore_paths]
    delete_paths = [safe_repo_path(path) for path in delete_paths]
    if len(restore_paths) != 20 or len(restore_paths) != len(set(restore_paths)):
        raise SystemExit("expected twenty unique AS-WP4 parent paths")
    if len(delete_paths) != 19 or len(delete_paths) != len(set(delete_paths)):
        raise SystemExit("expected nineteen unique AS-WP4 additive paths")
    if set(restore_paths) & set(delete_paths):
        raise SystemExit("restore/delete path overlap")
    return restore_paths, delete_paths


def _validate_parent(work: dict[str, object]) -> tuple[list[str], list[str]]:
    entry = work["entry_evidence"]
    if not isinstance(entry, dict):
        raise SystemExit("invalid entry_evidence")
    if sha(PARENT_MANIFEST.read_bytes()) != EXPECTED_PARENT_MANIFEST_RAW:
        raise SystemExit("AS-WP3 manifest raw drift")
    if canonical_sha(PARENT_MANIFEST) != EXPECTED_PARENT_MANIFEST_CANONICAL:
        raise SystemExit("AS-WP3 manifest canonical drift")
    if entry.get("author_package_bundle_canonical_sha256") != EXPECTED_PACKAGE_BUNDLE:
        raise SystemExit("author package bundle anchor drift")
    if entry.get("source_lock_canonical_sha256") != EXPECTED_SOURCE_LOCK:
        raise SystemExit("source lock anchor drift")
    restore_paths, delete_paths = _scope(work)
    records, counts = status_records("artifacts/ptcgdap/as_wp4/", set(delete_paths))
    if (OUTPUT_ROOT / "manifest.json").is_file():
        existing = load_json_strict(OUTPUT_ROOT / "manifest.json")
        existing_bytes = {
            safe_repo_path(item["original_path"]): decode_existing(item)
            for item in existing.get("files", [])
        }
        for record in records:
            path = str(record["path"])
            if path in existing_bytes:
                record["bytes"] = len(existing_bytes[path])
                record["sha256"] = sha(existing_bytes[path])
    if len(records) != EXPECTED_PARENT_ENTRY_COUNT or counts != EXPECTED_PARENT_COUNTS:
        raise SystemExit(f"pre-AS-WP4 worktree counts drift: {len(records)} {counts}")
    if sha(canonical_json_v1_bytes(records)) != EXPECTED_PARENT_DIGEST:
        raise SystemExit("pre-AS-WP4 worktree digest drift")
    return restore_paths, delete_paths


def _render_manifest(work: dict[str, object], restore_paths: list[str], delete_paths: list[str]) -> tuple[dict[str, object], dict[str, bytes]]:
    entry = work["entry_evidence"]
    files: list[dict[str, object]] = []
    payloads: dict[str, bytes] = {}
    existing_bytes: dict[str, bytes] = {}
    if (OUTPUT_ROOT / "manifest.json").is_file():
        existing = load_json_strict(OUTPUT_ROOT / "manifest.json")
        existing_bytes = {
            safe_repo_path(item["original_path"]): decode_existing(item)
            for item in existing.get("files", [])
        }
    for relative in restore_paths:
        value = existing_bytes.get(relative, (ROOT / relative).read_bytes())
        name = relative.replace("/", "__") + ".base64"
        payload = encode(value)
        payloads[name] = payload
        files.append(
            {
                "original_path": relative,
                "snapshot_path": name,
                "bytes": len(value),
                "raw_sha256": sha(value),
                "snapshot_file_bytes": len(payload),
                "snapshot_file_raw_sha256": sha(payload),
            }
        )
    manifest: dict[str, object] = {
        "schema_version": 1,
        "work_package": "AS-WP4",
        "captured_at": "2026-08-12T15:00:00+08:00",
        "file_count": len(files),
        "parent": {
            "work_package": "AS-WP3",
            "manifest_path": entry["parent_manifest_path"],
            "manifest_raw_sha256": entry["parent_manifest_raw_sha256"],
            "manifest_canonical_sha256": entry["parent_manifest_canonical_sha256"],
            "author_package_bundle_canonical_sha256": entry["author_package_bundle_canonical_sha256"],
            "source_lock_canonical_sha256": entry["source_lock_canonical_sha256"],
            "worktree_entry_count": entry["pre_as_wp4_worktree_entry_count"],
            "worktree_status_counts": entry["pre_as_wp4_worktree_status_counts"],
            "worktree_snapshot_canonical_sha256": entry["pre_as_wp4_worktree_canonical_sha256"],
        },
        "files": files,
        "rollback_scope": {
            "restore_exact_paths": restore_paths,
            "delete_exact_paths": delete_paths,
            "delete_evidence_prefix": "artifacts/ptcgdap/as_wp4/",
        },
    }
    return manifest, payloads


def capture(replace: bool, check: bool) -> int:
    work = load_json_strict(WORK_PACKAGE)
    restore_paths, delete_paths = _validate_parent(work)
    manifest, payloads = _render_manifest(work, restore_paths, delete_paths)
    rendered = {**payloads, "manifest.json": (json.dumps(manifest, ensure_ascii=False, indent=2) + "\n").encode("utf-8")}
    if check:
        actual_names = {path.name for path in OUTPUT_ROOT.iterdir() if path.is_file()} if OUTPUT_ROOT.is_dir() else set()
        if actual_names != set(rendered):
            raise SystemExit(f"snapshot file set drift: {sorted(actual_names ^ set(rendered))}")
        for name, expected in rendered.items():
            if (OUTPUT_ROOT / name).read_bytes() != expected:
                raise SystemExit(f"snapshot drift: {name}")
        print("AS-WP4 parent snapshot verified")
    else:
        OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
        existing = list(OUTPUT_ROOT.iterdir())
        if existing and not replace:
            raise SystemExit("snapshot already exists; use --replace only while parent bytes are unchanged")
        if replace:
            for path in existing:
                if not path.is_file():
                    raise SystemExit(f"unexpected snapshot entry: {path}")
                path.unlink()
        for name, value in rendered.items():
            (OUTPUT_ROOT / name).write_bytes(value)
        print(f"captured {len(restore_paths)} files")
    manifest_bytes = rendered["manifest.json"]
    print(f"manifest_raw_sha256={sha(manifest_bytes)}")
    print(f"manifest_canonical_sha256={sha(canonical_json_v1_bytes(manifest))}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Capture or verify the exact AS-WP4 parent bytes")
    parser.add_argument("--replace", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    return capture(args.replace, args.check)


if __name__ == "__main__":
    raise SystemExit(main())
