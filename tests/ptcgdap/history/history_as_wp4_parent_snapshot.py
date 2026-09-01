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
    is_dragapult_acceptance_additive,
    restore_pre_author_player_owner_record,
    restore_pre_dragapult_bytes,
)
from tests.ptcgdap.test_as_wp5_parent_snapshot import as_wp5_parent_bytes, is_as_wp5_parent_clean_path, is_as_wp5_path


ROOT = Path(__file__).resolve().parents[2]
SNAPSHOT_ROOT = ROOT / "artifacts/ptcgdap/as_wp4/parent_snapshot"
MANIFEST_PATH = SNAPSHOT_ROOT / "manifest.json"
PARENT_MANIFEST_PATH = ROOT / "artifacts/ptcgdap/as_wp3/manifest.json"
WORK_PACKAGE_PATH = ROOT / "artifacts/ptcgdap/as_wp4/work_package.json"
EXPECTED_MANIFEST_RAW = "9F52F724C00DD573F5836881A19965EDEE86FABE2D698529CFA5BDC88B1B2C23"
EXPECTED_MANIFEST_CANONICAL = "E6C5B00CC4FB1D68627DE6AFACEBCB428FDFB0D0546C2642675EA6D52A237A37"
EXPECTED_PARENT_MANIFEST_RAW = "8C49F3E12149AE5869FE91C45AE2B757A6D03BBD52ADFC4323C6AF7F4ECCDD06"
EXPECTED_PARENT_MANIFEST_CANONICAL = "E65CDA3B195E5C8FD521AAD7BE812C1083B954DBCAB7314A24F60FAD3502F7B6"
EXPECTED_PACKAGE_BUNDLE = "B416F2CBA2795B62126B6EF7B5F07A9000E84D5FA1DF62C1753CADC9E82E106B"
EXPECTED_SOURCE_LOCK = "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"
EXPECTED_PARENT_ENTRY_COUNT = 1722
EXPECTED_PARENT_COUNTS = {"deleted": 28, "modified": 7, "untracked": 1687}
EXPECTED_PARENT_DIGEST = "980DE58954F5E5BE7C1BDC4E2ACA0DE595F00B893233CB5ED82753489FD7352F"


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
    lines = source[:-1].split(b"\n")
    if not lines or any(not line or len(line) > 4096 for line in lines) or any(len(line) != 4096 for line in lines[:-1]):
        raise AssertionError(name)
    encoded = b"".join(lines)
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
    result: list[tuple[str, str]] = []
    for record in output.split(b"\0"):
        if not record:
            continue
        code = record[:2].decode("ascii")
        path = safe_path(record[3:].decode("utf-8").replace("\\", "/"))
        if "R" in code or "C" in code:
            raise AssertionError("rename/copy outside snapshot algorithm")
        result.append((code, path))
    return result


class AsWp4ParentSnapshotTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        if EXPECTED_MANIFEST_RAW != sha(MANIFEST_PATH.read_bytes()):
            raise AssertionError("AS-WP4 snapshot raw drift")
        cls.manifest = load_json_strict(MANIFEST_PATH)
        if EXPECTED_MANIFEST_CANONICAL != sha(canonical_json_v1_bytes(cls.manifest)):
            raise AssertionError("AS-WP4 snapshot canonical drift")
        cls.entries = {safe_path(entry["original_path"]): entry for entry in cls.manifest["files"]}
        cls.work = load_json_strict(WORK_PACKAGE_PATH)

    def test_payloads_are_exact_safe_complete_and_bind_as_wp3(self) -> None:
        self.assertEqual("AS-WP4", self.manifest["work_package"])
        self.assertEqual(20, self.manifest["file_count"])
        self.assertEqual(20, len(self.entries))
        parent = self.manifest["parent"]
        self.assertEqual(EXPECTED_PARENT_MANIFEST_RAW, parent["manifest_raw_sha256"])
        self.assertEqual(EXPECTED_PARENT_MANIFEST_CANONICAL, parent["manifest_canonical_sha256"])
        self.assertEqual(EXPECTED_PACKAGE_BUNDLE, parent["author_package_bundle_canonical_sha256"])
        self.assertEqual(EXPECTED_SOURCE_LOCK, parent["source_lock_canonical_sha256"])
        self.assertEqual(EXPECTED_PARENT_ENTRY_COUNT, parent["worktree_entry_count"])
        self.assertEqual(EXPECTED_PARENT_COUNTS, parent["worktree_status_counts"])
        self.assertEqual(EXPECTED_PARENT_DIGEST, parent["worktree_snapshot_canonical_sha256"])
        self.assertEqual(EXPECTED_PARENT_MANIFEST_RAW, sha(PARENT_MANIFEST_PATH.read_bytes()))
        self.assertEqual(EXPECTED_PARENT_MANIFEST_CANONICAL, sha(canonical_json_v1_bytes(load_json_strict(PARENT_MANIFEST_PATH))))
        allowed = self.work["files_allowed"]
        expected_restore = {
            *allowed["existing_project_files"],
            *allowed["existing_docs"],
            *allowed["existing_compatibility_files"],
        }
        scope = self.manifest["rollback_scope"]
        self.assertEqual(expected_restore, set(self.entries))
        self.assertEqual(expected_restore, set(scope["restore_exact_paths"]))
        self.assertEqual(set(allowed["as_wp4_additive"]), set(scope["delete_exact_paths"]))
        self.assertFalse(set(self.entries) & set(scope["delete_exact_paths"]))
        names = [entry["snapshot_path"] for entry in self.entries.values()]
        self.assertEqual({"manifest.json", *names}, {path.name for path in SNAPSHOT_ROOT.iterdir() if path.is_file()})
        for entry in self.entries.values():
            decode(entry)

    def test_isolated_restore_contains_only_parent_files(self) -> None:
        with tempfile.TemporaryDirectory(prefix="ptcgdap-as-wp4-parent-") as temp:
            restore_root = Path(temp)
            for path, entry in self.entries.items():
                destination = restore_root / path
                destination.parent.mkdir(parents=True, exist_ok=True)
                destination.write_bytes(decode(entry))
            self.assertEqual(
                set(self.entries),
                {path.relative_to(restore_root).as_posix() for path in restore_root.rglob("*") if path.is_file()},
            )

    def test_virtual_rollback_reproduces_pre_as_wp4_candidate(self) -> None:
        parent_bytes = {path: decode(entry) for path, entry in self.entries.items()}
        scope = self.manifest["rollback_scope"]
        delete_paths = set(scope["delete_exact_paths"])
        delete_prefix = scope["delete_evidence_prefix"]
        records: list[dict[str, object]] = []
        restored: set[str] = set()
        observed_paths: set[str] = set()
        for code, path in status():
            if is_dragapult_acceptance_additive(path):
                continue
            if is_as_wp5_path(path) or is_as_wp5_parent_clean_path(path) or path in delete_paths or path.startswith(delete_prefix):
                continue
            observed_paths.add(path)
            if path in parent_bytes:
                data = parent_bytes[path]
                restored.add(path)
            elif "D" in code:
                data = None
            else:
                data = as_wp5_parent_bytes(
                    path,
                    restore_pre_dragapult_bytes(path, (ROOT / path).read_bytes()),
                )
            records.append(
                restore_pre_author_player_owner_record("AS-WP4", {
                    "path": path,
                    "status": code,
                    "bytes": None if data is None else len(data),
                    "sha256": None if data is None else sha(data),
                })
            )
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
