from __future__ import annotations

import argparse
import base64
import binascii
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


WORK_PACKAGE = ROOT / "artifacts/ptcgdap/as_wp6/work_package.json"
OUTPUT_ROOT = ROOT / "artifacts/ptcgdap/as_wp6/parent_snapshot"
PARENT_MANIFEST = ROOT / "artifacts/ptcgdap/as_wp5/manifest.json"
PARENT_SNAPSHOT_MANIFEST = ROOT / "artifacts/ptcgdap/as_wp5/parent_snapshot/manifest.json"
LIVE_SEAM_BUNDLE = ROOT / "contracts/ptcgdap/author_strategy_live_seam_bundle.json"
SOURCE_LOCK = ROOT / "docs/ptcgdap/SOURCE_LOCK.json"
EXPECTED_PARENT_MANIFEST_RAW = "23AC931624F4056D53FC4E0798731A436BE7628DEB5485B075561087654928FC"
EXPECTED_PARENT_MANIFEST_CANONICAL = "4E2693E9143C3326C131DE9C64917632129408870C1AF897199DBA8841FA4428"
EXPECTED_PARENT_SNAPSHOT_RAW = "DA2B946303B454CDDCE22A4373C4175E556648AE73C9F60773A3C00185E00E77"
EXPECTED_PARENT_SNAPSHOT_CANONICAL = "BC17973CF54E8B8BE6C45D7494DCBE47FE2CB0AD9DC784455DC7E54FFDE34E33"
EXPECTED_LIVE_SEAM_BUNDLE = "5CDC360999A23A2CADCAC6E7FA8D81549566DFABE37B2DB4F813C0C5189C3E16"
EXPECTED_SOURCE_LOCK = "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"
EXPECTED_PARENT_ENTRY_COUNT = 1836
EXPECTED_PARENT_COUNTS = {"deleted": 28, "modified": 11, "untracked": 1797}
EXPECTED_PARENT_DIGEST = "7D1BD926E3018E8C1F8AB06F93F3535336122D379B32C034F49B79FE4A379871"


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


def scope(work: dict[str, object]) -> tuple[list[str], list[str]]:
    allowed = work.get("files_allowed")
    if not isinstance(allowed, dict):
        raise SystemExit("invalid files_allowed")
    restore = [
        *allowed["existing_project_files"],
        *allowed["existing_docs"],
        *allowed["existing_compatibility_files"],
    ]
    delete = list(allowed["as_wp6_additive"])
    restore = [safe_path(value) for value in restore]
    delete = [safe_path(value) for value in delete]
    if len(restore) != len(set(restore)) or len(delete) != len(set(delete)) or set(restore) & set(delete):
        raise SystemExit("invalid restore/delete scope")
    return restore, delete


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
        if path.startswith("artifacts/ptcgdap/as_wp6/") or path in excluded:
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


def validate_anchors() -> None:
    anchors = (
        (PARENT_MANIFEST, EXPECTED_PARENT_MANIFEST_RAW, EXPECTED_PARENT_MANIFEST_CANONICAL, "AS-WP5 manifest"),
        (PARENT_SNAPSHOT_MANIFEST, EXPECTED_PARENT_SNAPSHOT_RAW, EXPECTED_PARENT_SNAPSHOT_CANONICAL, "AS-WP5 parent snapshot"),
    )
    for path, expected_raw, expected_canonical, label in anchors:
        if sha(path.read_bytes()) != expected_raw or canonical_sha(path) != expected_canonical:
            raise SystemExit(f"{label} drift")
    if canonical_sha(LIVE_SEAM_BUNDLE) != EXPECTED_LIVE_SEAM_BUNDLE:
        raise SystemExit("author live seam bundle drift")
    if canonical_sha(SOURCE_LOCK) != EXPECTED_SOURCE_LOCK:
        raise SystemExit("source lock drift")


def validate_parent(work: dict[str, object]) -> tuple[list[str], list[str]]:
    entry = work.get("entry_evidence")
    if not isinstance(entry, dict):
        raise SystemExit("invalid entry evidence")
    validate_anchors()
    restore, delete = scope(work)
    records, counts = status_records(set(delete))
    if len(records) != EXPECTED_PARENT_ENTRY_COUNT or counts != EXPECTED_PARENT_COUNTS:
        raise SystemExit(f"pre-AS-WP6 counts drift: {len(records)} {counts}")
    if sha(canonical_json_v1_bytes(records)) != EXPECTED_PARENT_DIGEST:
        raise SystemExit("pre-AS-WP6 worktree digest drift")
    return restore, delete


def verify_frozen_snapshot(work: dict[str, object]) -> dict[str, object]:
    validate_anchors()
    restore, delete = scope(work)
    manifest_path = OUTPUT_ROOT / "manifest.json"
    manifest = load_json_strict(manifest_path)
    if manifest.get("work_package") != "AS-WP6":
        raise SystemExit("snapshot work package drift")
    rollback = manifest.get("rollback_scope")
    if not isinstance(rollback, dict):
        raise SystemExit("snapshot rollback scope drift")
    if rollback.get("restore_exact_paths") != restore or rollback.get("delete_exact_paths") != delete:
        raise SystemExit("snapshot rollback scope drift")
    entries = manifest.get("files")
    if not isinstance(entries, list) or manifest.get("file_count") != len(entries):
        raise SystemExit("snapshot file count drift")
    expected_files = {"manifest.json"}
    seen_originals: set[str] = set()
    seen_snapshots: set[str] = set()
    for entry in entries:
        if not isinstance(entry, dict):
            raise SystemExit("snapshot entry drift")
        original_path = safe_path(entry.get("original_path"))
        snapshot_path = safe_path(entry.get("snapshot_path"))
        if "/" in snapshot_path or original_path not in restore:
            raise SystemExit("snapshot entry path drift")
        if original_path in seen_originals or snapshot_path in seen_snapshots:
            raise SystemExit("snapshot duplicate entry drift")
        seen_originals.add(original_path)
        seen_snapshots.add(snapshot_path)
        encoded = (OUTPUT_ROOT / snapshot_path).read_bytes()
        if not encoded.endswith(b"\n") or b"\r" in encoded:
            raise SystemExit(f"snapshot encoding drift: {snapshot_path}")
        compact = b"".join(encoded[:-1].split(b"\n"))
        try:
            value = base64.b64decode(compact, validate=True)
        except (ValueError, binascii.Error) as exc:
            raise SystemExit(f"snapshot base64 drift: {snapshot_path}") from exc
        if base64.b64encode(value) != compact:
            raise SystemExit(f"snapshot base64 drift: {snapshot_path}")
        if len(encoded) != entry.get("snapshot_file_bytes") or sha(encoded) != entry.get("snapshot_file_raw_sha256"):
            raise SystemExit(f"snapshot payload drift: {snapshot_path}")
        if len(value) != entry.get("bytes") or sha(value) != entry.get("raw_sha256"):
            raise SystemExit(f"snapshot source drift: {snapshot_path}")
        expected_files.add(snapshot_path)
    if seen_originals != set(restore):
        raise SystemExit("snapshot restore coverage drift")
    actual_files = {path.name for path in OUTPUT_ROOT.iterdir() if path.is_file()}
    if actual_files != expected_files:
        raise SystemExit("snapshot file set drift")
    return manifest


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
        "work_package": "AS-WP6",
        "captured_at": "2026-08-12T09:15:18+08:00",
        "file_count": len(files),
        "parent": {
            "work_package": "AS-WP5",
            "manifest_path": entry["parent_manifest_path"],
            "manifest_raw_sha256": entry["parent_manifest_raw_sha256"],
            "manifest_canonical_sha256": entry["parent_manifest_canonical_sha256"],
            "parent_snapshot_manifest_raw_sha256": entry["parent_snapshot_manifest_raw_sha256"],
            "parent_snapshot_manifest_canonical_sha256": entry["parent_snapshot_manifest_canonical_sha256"],
            "author_live_seam_bundle_canonical_sha256": entry["author_live_seam_bundle_canonical_sha256"],
            "source_lock_canonical_sha256": entry["source_lock_canonical_sha256"],
            "worktree_entry_count": entry["pre_as_wp6_worktree_entry_count"],
            "worktree_status_counts": entry["pre_as_wp6_worktree_status_counts"],
            "worktree_snapshot_canonical_sha256": entry["pre_as_wp6_worktree_canonical_sha256"],
        },
        "files": files,
        "rollback_scope": {
            "restore_exact_paths": restore,
            "delete_exact_paths": delete,
            "delete_evidence_prefix": "artifacts/ptcgdap/as_wp6/",
            "preserve_user_packages": True,
        },
    }
    return manifest, payloads


def _contains_prior_record(value: object, path: str, byte_count: int, raw_sha256: str) -> bool:
    if isinstance(value, dict):
        if value.get("path") == path and value.get("bytes") == byte_count and value.get("raw_sha256", value.get("sha256")) == raw_sha256:
            return True
        return any(_contains_prior_record(child, path, byte_count, raw_sha256) for child in value.values())
    if isinstance(value, list):
        return any(_contains_prior_record(child, path, byte_count, raw_sha256) for child in value)
    return False


def _contains_prior_path_hash(value: object, path: str, raw_sha256: str) -> bool:
    if isinstance(value, dict):
        if value.get("path") == path and value.get("raw_sha256", value.get("sha256")) == raw_sha256:
            return True
        return any(_contains_prior_path_hash(child, path, raw_sha256) for child in value.values())
    if isinstance(value, list):
        return any(_contains_prior_path_hash(child, path, raw_sha256) for child in value)
    return False


def append_recovered_scope(work: dict[str, object], source_root_raw: str, *, refresh_existing: bool = False) -> int:
    extension = work.get("parent_snapshot_scope_extension")
    if not isinstance(extension, dict) or extension.get("recovery_method") != "reverse_captured_filechange_patches_with_core_autocrlf_false":
        raise SystemExit("parent snapshot scope extension is not declared")
    recovery_values = extension.get("files")
    if not isinstance(recovery_values, list) or not recovery_values:
        raise SystemExit("parent snapshot recovery files are missing")
    source_root = Path(source_root_raw).resolve()
    allowed_root = (ROOT / ".tmp/ptcgdap_parent_reconstruct").resolve()
    if source_root == allowed_root or allowed_root not in source_root.parents or not source_root.is_dir():
        raise SystemExit("recovered source root must be an isolated child of .tmp/ptcgdap_parent_reconstruct")

    restore, delete = scope(work)
    manifest_path = OUTPUT_ROOT / "manifest.json"
    manifest = load_json_strict(manifest_path)
    entries = manifest.get("files")
    rollback = manifest.get("rollback_scope")
    if not isinstance(entries, list) or not isinstance(rollback, dict):
        raise SystemExit("snapshot manifest drift")
    recovered: dict[str, tuple[bytes, dict[str, object]]] = {}
    for value in recovery_values:
        base_keys = {"path", "bytes", "raw_sha256", "prior_evidence"}
        special_keys = base_keys | {"captured_patch_item", "supersedes_raw_sha256"}
        if not isinstance(value, dict) or set(value) not in (base_keys, special_keys):
            raise SystemExit("invalid recovered parent record")
        relative = safe_path(value.get("path"))
        byte_count = value.get("bytes")
        raw_sha256 = value.get("raw_sha256")
        prior_relative = safe_path(value.get("prior_evidence"))
        if relative in recovered or relative not in restore or not isinstance(byte_count, int) or byte_count < 0 or not isinstance(raw_sha256, str):
            raise SystemExit("invalid recovered parent identity")
        source = (source_root / relative).resolve()
        if source_root not in source.parents or not source.is_file() or source.is_symlink():
            raise SystemExit(f"unsafe recovered parent source: {relative}")
        payload = source.read_bytes()
        if len(payload) != byte_count or sha(payload) != raw_sha256:
            raise SystemExit(f"recovered parent bytes drift: {relative}")
        prior_path = ROOT / prior_relative
        prior_value = load_json_strict(prior_path) if prior_path.is_file() else None
        exact_prior = prior_value is not None and _contains_prior_record(prior_value, relative, byte_count, raw_sha256)
        captured_patch = value.get("captured_patch_item")
        supersedes = value.get("supersedes_raw_sha256")
        captured_prior = (
            isinstance(captured_patch, str)
            and captured_patch.startswith("exec-")
            and isinstance(supersedes, str)
            and prior_value is not None
            and _contains_prior_path_hash(prior_value, relative, supersedes)
        )
        if not exact_prior and not captured_prior:
            raise SystemExit(f"prior evidence does not bind recovered bytes: {relative}")
        recovered[relative] = (payload, value)

    existing_restore = {safe_path(entry.get("original_path")) for entry in entries if isinstance(entry, dict)}
    existing_delete = {safe_path(path) for path in rollback.get("delete_exact_paths", [])}
    required_existing = set(restore) - set(recovered)
    if not required_existing.issubset(existing_restore) or not existing_restore.issubset(set(restore)) or not existing_delete.issubset(set(delete)):
        raise SystemExit("recovered scope may only append the declared omitted parent files")
    entry_by_path = {safe_path(entry.get("original_path")): entry for entry in entries if isinstance(entry, dict)}
    refresh_paths: set[str] = set()
    for relative in existing_restore & set(recovered):
        entry = entry_by_path.get(relative, {})
        value, record = recovered[relative]
        if entry.get("bytes") != len(value) or entry.get("raw_sha256") != sha(value):
            if not refresh_existing or entry.get("raw_sha256") != record.get("supersedes_raw_sha256"):
                raise SystemExit(f"existing recovered snapshot drift: {relative}")
            refresh_paths.add(relative)
    additions: dict[str, bytes] = {}
    for relative in restore:
        if relative not in recovered:
            continue
        if relative in existing_restore and relative not in refresh_paths:
            continue
        value, _record = recovered[relative]
        name = relative.replace("/", "__") + ".base64"
        if relative not in refresh_paths and ((OUTPUT_ROOT / name).exists() or name in additions):
            raise SystemExit(f"snapshot payload already exists: {name}")
        encoded = encode(value)
        additions[name] = encoded
        new_entry = {
            "original_path": relative,
            "snapshot_path": name,
            "bytes": len(value),
            "raw_sha256": sha(value),
            "snapshot_file_bytes": len(encoded),
            "snapshot_file_raw_sha256": sha(encoded),
        }
        if relative in refresh_paths:
            entries[entries.index(entry_by_path[relative])] = new_entry
        else:
            entries.append(new_entry)
    manifest["file_count"] = len(entries)
    rollback["restore_exact_paths"] = restore
    rollback["delete_exact_paths"] = delete
    rendered = (json.dumps(manifest, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
    for name, value in additions.items():
        (OUTPUT_ROOT / name).write_bytes(value)
    manifest_path.write_bytes(rendered)
    print(f"updated {len(additions)} recovered parent files")
    print(f"manifest_raw_sha256={sha(rendered)}")
    print(f"manifest_canonical_sha256={sha(canonical_json_v1_bytes(manifest))}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--extend-scope", action="store_true")
    parser.add_argument("--append-restore")
    parser.add_argument("--append-recovered-root")
    parser.add_argument("--refresh-recovered-root")
    args = parser.parse_args()
    work = load_json_strict(WORK_PACKAGE)
    if args.refresh_recovered_root is not None:
        if args.check or args.extend_scope or args.append_restore is not None or args.append_recovered_root is not None:
            raise SystemExit("choose one mode")
        validate_anchors()
        return append_recovered_scope(work, args.refresh_recovered_root, refresh_existing=True)
    if args.append_recovered_root is not None:
        if args.check or args.extend_scope or args.append_restore is not None:
            raise SystemExit("choose one mode")
        validate_anchors()
        return append_recovered_scope(work, args.append_recovered_root)
    if args.append_restore is not None:
        if args.check or args.extend_scope:
            raise SystemExit("choose one mode")
        validate_anchors()
        requested = safe_path(args.append_restore)
        restore, delete = scope(work)
        if requested not in restore:
            raise SystemExit("append restore path is not declared")
        manifest_path = OUTPUT_ROOT / "manifest.json"
        manifest = load_json_strict(manifest_path)
        entries = manifest.get("files")
        rollback = manifest.get("rollback_scope")
        if not isinstance(entries, list) or not isinstance(rollback, dict):
            raise SystemExit("snapshot manifest drift")
        existing_restore = [safe_path(entry["original_path"]) for entry in entries]
        expected_existing = [path for path in restore if path != requested]
        if len(existing_restore) != len(expected_existing) or set(existing_restore) != set(expected_existing) or requested in existing_restore:
            raise SystemExit("restore extension may append only one newly declared parent path")
        if rollback.get("restore_exact_paths") != expected_existing or rollback.get("delete_exact_paths") != delete:
            raise SystemExit("snapshot rollback scope drift")
        value = (ROOT / requested).read_bytes()
        name = requested.replace("/", "__") + ".base64"
        payload = encode(value)
        if (OUTPUT_ROOT / name).exists():
            raise SystemExit("snapshot payload already exists")
        entries.append({
            "original_path": requested,
            "snapshot_path": name,
            "bytes": len(value),
            "raw_sha256": sha(value),
            "snapshot_file_bytes": len(payload),
            "snapshot_file_raw_sha256": sha(payload),
        })
        manifest["file_count"] = len(entries)
        rollback["restore_exact_paths"] = restore
        rendered = (json.dumps(manifest, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
        (OUTPUT_ROOT / name).write_bytes(payload)
        manifest_path.write_bytes(rendered)
        print(f"appended restore path {requested}")
        print(f"manifest_raw_sha256={sha(rendered)}")
        print(f"manifest_canonical_sha256={sha(canonical_json_v1_bytes(manifest))}")
        return 0
    if args.extend_scope:
        if args.check:
            raise SystemExit("choose one mode")
        restore, delete = scope(work)
        manifest_path = OUTPUT_ROOT / "manifest.json"
        manifest = load_json_strict(manifest_path)
        existing_restore = [safe_path(entry["original_path"]) for entry in manifest.get("files", [])]
        existing_delete = [safe_path(path) for path in manifest.get("rollback_scope", {}).get("delete_exact_paths", [])]
        if len(existing_restore) != len(restore) or set(existing_restore) != set(restore) or not set(existing_delete).issubset(set(delete)):
            raise SystemExit("scope extension may only add delete paths")
        manifest["rollback_scope"]["delete_exact_paths"] = delete
        rendered = (json.dumps(manifest, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
        manifest_path.write_bytes(rendered)
        print(f"extended delete scope to {len(delete)} paths")
        print(f"manifest_raw_sha256={sha(rendered)}")
        print(f"manifest_canonical_sha256={sha(canonical_json_v1_bytes(manifest))}")
        return 0
    if args.check:
        manifest = verify_frozen_snapshot(work)
        data = (OUTPUT_ROOT / "manifest.json").read_bytes()
        print("AS-WP6 parent snapshot verified")
        print(f"manifest_raw_sha256={sha(data)}")
        print(f"manifest_canonical_sha256={sha(canonical_json_v1_bytes(manifest))}")
        return 0
    restore, delete = validate_parent(work)
    manifest, payloads = render(work, restore, delete)
    rendered = {
        **payloads,
        "manifest.json": (json.dumps(manifest, ensure_ascii=False, indent=2) + "\n").encode("utf-8"),
    }
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
