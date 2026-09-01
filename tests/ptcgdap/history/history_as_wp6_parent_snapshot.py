from __future__ import annotations

import base64
from collections import Counter
import hashlib
from pathlib import Path, PurePosixPath
import subprocess
import tempfile
import unittest

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict
from tests.ptcgdap.dragapult_acceptance_rollback import (
    POST_ACCEPTANCE_AS_WP6_CLEAN_PATHS,
    POST_ACCEPTANCE_DEVELOPMENT_CLEAN_PATHS,
    POST_ACCEPTANCE_DEVELOPMENT_PARENT_RESTORE_PATHS,
    is_dragapult_acceptance_additive,
    restore_pre_author_player_owner_record,
    restore_pre_dragapult_bytes,
)


ROOT = Path(__file__).resolve().parents[2]
SNAPSHOT_ROOT = ROOT / "artifacts/ptcgdap/as_wp6/parent_snapshot"
MANIFEST_PATH = SNAPSHOT_ROOT / "manifest.json"
WORK_PACKAGE_PATH = ROOT / "artifacts/ptcgdap/as_wp6/work_package.json"
EXPECTED_MANIFEST_RAW = "BD468C689CC3DDD01203425BAAF9EBED426ACCF22EB2E3AFC231999EE4557E69"
EXPECTED_MANIFEST_CANONICAL = "7B576808BC845495684BB79AD01D2768F686F245EB659C02C68ED935E1865C2C"
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


def safe_path(raw: object) -> str:
    if not isinstance(raw, str) or not raw or "\\" in raw or "\0" in raw:
        raise AssertionError(raw)
    path = PurePosixPath(raw)
    if path.is_absolute() or "." in path.parts or ".." in path.parts or ":" in path.parts[0] or path.as_posix() != raw:
        raise AssertionError(raw)
    return raw


def decode(entry: dict[str, object]) -> bytes:
    name = safe_path(entry["snapshot_path"])
    if "/" in name:
        raise AssertionError(name)
    source = (SNAPSHOT_ROOT / name).read_bytes()
    if not source.endswith(b"\n") or b"\r" in source:
        raise AssertionError(name)
    encoded = b"".join(source[:-1].split(b"\n"))
    value = base64.b64decode(encoded.decode("ascii"), validate=True)
    if base64.b64encode(value) != encoded:
        raise AssertionError(name)
    if len(source) != entry["snapshot_file_bytes"] or sha(source) != entry["snapshot_file_raw_sha256"]:
        raise AssertionError(name)
    if len(value) != entry["bytes"] or sha(value) != entry["raw_sha256"]:
        raise AssertionError(name)
    return value


def status() -> list[tuple[str, str]]:
    output = subprocess.run(
        ["git", "status", "--porcelain=v1", "-z", "--untracked-files=all"],
        cwd=ROOT,
        check=True,
        capture_output=True,
    ).stdout
    result = []
    for record in output.split(b"\0"):
        if not record:
            continue
        code = record[:2].decode("ascii")
        path = safe_path(record[3:].decode("utf-8").replace("\\", "/"))
        if "R" in code or "C" in code:
            raise AssertionError("rename/copy outside snapshot algorithm")
        result.append((code, path))
    return result


def tracked_head_bytes(path: str) -> bytes | None:
    result = subprocess.run(
        ["git", "cat-file", "--filters", f"--path={path}", f"HEAD:{path}"],
        cwd=ROOT,
        capture_output=True,
    )
    return result.stdout if result.returncode == 0 else None


class AsWp6ParentSnapshotTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        if sha(MANIFEST_PATH.read_bytes()) != EXPECTED_MANIFEST_RAW:
            raise AssertionError("AS-WP6 snapshot raw drift")
        cls.manifest = load_json_strict(MANIFEST_PATH)
        if sha(canonical_json_v1_bytes(cls.manifest)) != EXPECTED_MANIFEST_CANONICAL:
            raise AssertionError("AS-WP6 snapshot canonical drift")
        cls.entries = {safe_path(entry["original_path"]): entry for entry in cls.manifest["files"]}
        cls.work = load_json_strict(WORK_PACKAGE_PATH)

    def test_payloads_are_exact_safe_complete_and_bind_as_wp5(self) -> None:
        self.assertEqual("AS-WP6", self.manifest["work_package"])
        self.assertEqual(64, self.manifest["file_count"])
        self.assertEqual(64, len(self.entries))
        parent = self.manifest["parent"]
        self.assertEqual(EXPECTED_PARENT_MANIFEST_RAW, parent["manifest_raw_sha256"])
        self.assertEqual(EXPECTED_PARENT_MANIFEST_CANONICAL, parent["manifest_canonical_sha256"])
        self.assertEqual(EXPECTED_PARENT_SNAPSHOT_RAW, parent["parent_snapshot_manifest_raw_sha256"])
        self.assertEqual(EXPECTED_PARENT_SNAPSHOT_CANONICAL, parent["parent_snapshot_manifest_canonical_sha256"])
        self.assertEqual(EXPECTED_LIVE_SEAM_BUNDLE, parent["author_live_seam_bundle_canonical_sha256"])
        self.assertEqual(EXPECTED_SOURCE_LOCK, parent["source_lock_canonical_sha256"])
        self.assertEqual(EXPECTED_PARENT_ENTRY_COUNT, parent["worktree_entry_count"])
        self.assertEqual(EXPECTED_PARENT_COUNTS, parent["worktree_status_counts"])
        self.assertEqual(EXPECTED_PARENT_DIGEST, parent["worktree_snapshot_canonical_sha256"])
        allowed = self.work["files_allowed"]
        expected_restore = {
            *allowed["existing_project_files"],
            *allowed["existing_docs"],
            *allowed["existing_compatibility_files"],
        }
        scope = self.manifest["rollback_scope"]
        self.assertEqual(expected_restore, set(self.entries))
        self.assertEqual(expected_restore, set(scope["restore_exact_paths"]))
        self.assertEqual(set(allowed["as_wp6_additive"]), set(scope["delete_exact_paths"]))
        self.assertTrue(scope["preserve_user_packages"])
        self.assertFalse(set(self.entries) & set(scope["delete_exact_paths"]))
        self.assertEqual(
            {"manifest.json", *(entry["snapshot_path"] for entry in self.entries.values())},
            {path.name for path in SNAPSHOT_ROOT.iterdir() if path.is_file()},
        )
        for entry in self.entries.values():
            decode(entry)

    def test_isolated_restore_contains_only_parent_files(self) -> None:
        with tempfile.TemporaryDirectory(prefix="ptcgdap-as-wp6-parent-") as temp:
            restore_root = Path(temp)
            for path, entry in self.entries.items():
                destination = restore_root / path
                destination.parent.mkdir(parents=True, exist_ok=True)
                destination.write_bytes(decode(entry))
            self.assertEqual(
                set(self.entries),
                {path.relative_to(restore_root).as_posix() for path in restore_root.rglob("*") if path.is_file()},
            )

    def test_virtual_rollback_reproduces_pre_as_wp6_candidate(self) -> None:
        parent_bytes = {path: decode(entry) for path, entry in self.entries.items()}
        scope = self.manifest["rollback_scope"]
        delete_paths = set(scope["delete_exact_paths"])
        delete_prefix = scope["delete_evidence_prefix"]
        records: list[dict[str, object]] = []
        restored: set[str] = set()
        observed_paths: set[str] = set()
        for code, path in status():
            if path in POST_ACCEPTANCE_DEVELOPMENT_CLEAN_PATHS:
                observed_paths.add(path)
                if path in parent_bytes:
                    restored.add(path)
                continue
            if (
                is_dragapult_acceptance_additive(path)
                and path not in POST_ACCEPTANCE_DEVELOPMENT_PARENT_RESTORE_PATHS
            ) or path in POST_ACCEPTANCE_AS_WP6_CLEAN_PATHS:
                continue
            if path in delete_paths or path.startswith(delete_prefix):
                continue
            observed_paths.add(path)
            if path in parent_bytes:
                data = parent_bytes[path]
                restored.add(path)
                if tracked_head_bytes(path) == data:
                    continue
            elif "D" in code:
                data = None
            else:
                data = restore_pre_dragapult_bytes(path, (ROOT / path).read_bytes())
            record = {
                "path": path,
                "status": code,
                "bytes": None if data is None else len(data),
                "sha256": None if data is None else sha(data),
            }
            records.append(restore_pre_author_player_owner_record("AS-WP6", record))
        for path, data in parent_bytes.items():
            if path not in observed_paths:
                self.assertEqual(data, (ROOT / path).read_bytes())
                restored.add(path)
        self.assertEqual(set(parent_bytes), restored)
        records.sort(key=lambda item: item["path"])
        counts = Counter(
            "untracked" if item["status"] == "??" else "deleted" if "D" in item["status"] else "modified"
            for item in records
        )
        self.assertEqual(EXPECTED_PARENT_ENTRY_COUNT, len(records))
        self.assertEqual(EXPECTED_PARENT_COUNTS, dict(counts))
        self.assertEqual(EXPECTED_PARENT_DIGEST, sha(canonical_json_v1_bytes(records)))


if __name__ == "__main__":
    unittest.main()
