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
SNAPSHOT_ROOT = ROOT / "artifacts/ptcgdap/as_wp3/parent_snapshot"
MANIFEST_PATH = SNAPSHOT_ROOT / "manifest.json"
PARENT_MANIFEST_PATH = ROOT / "artifacts/ptcgdap/as_wp2/manifest.json"
AS_WP4_SUCCESSOR_ROOT = ROOT / "artifacts/ptcgdap/as_wp4/parent_snapshot"
AS_WP4_SUCCESSOR_MANIFEST_PATH = AS_WP4_SUCCESSOR_ROOT / "manifest.json"
AS_WP4_WORK_PACKAGE_PATH = ROOT / "artifacts/ptcgdap/as_wp4/work_package.json"
AS_WP4_EVIDENCE_PREFIX = "artifacts/ptcgdap/as_wp4/"
EXPECTED_MANIFEST_RAW = "784178E46C9BD325B51B91591D42A95A162FAE72E5BF451351117F608DE7E16B"
EXPECTED_MANIFEST_CANONICAL = "02E915137A69B5F9F3D294C5E423B35F4B9CBEBC41BA70EACB7E7A51BF3D517A"
EXPECTED_PARENT_MANIFEST_RAW = "5CBEB06779E698920F357FF76E99C91B2E677E538C5143C9058F6D60198C643B"
EXPECTED_PARENT_MANIFEST_CANONICAL = "D191516688415965960BB7692CA443AD7329F2D59EDFD718DBFB6DFD6BA3A0AD"
EXPECTED_PACKAGE_BUNDLE = "B416F2CBA2795B62126B6EF7B5F07A9000E84D5FA1DF62C1753CADC9E82E106B"
EXPECTED_SOURCE_LOCK = "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"
EXPECTED_PARENT_ENTRY_COUNT = 1687
EXPECTED_PARENT_COUNTS = {"deleted": 28, "modified": 3, "untracked": 1656}
EXPECTED_PARENT_DIGEST = "3D65625D9FC953F3852303E69EB708A55D252697409B7791836323BCF39398F7"
EXPECTED_CLEAN_PARENT_PATHS = {
    "scripts/autoload/GameManager.gd",
    "scenes/battle_setup/BattleSetup.tscn",
    "scenes/battle_setup/BattleSetup.gd",
    "tests/test_battle_setup_ai_versions.gd",
}


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def safe_path(raw: object) -> str:
    if not isinstance(raw, str) or not raw or "\\" in raw or "\0" in raw:
        raise AssertionError(raw)
    path = PurePosixPath(raw)
    if path.is_absolute() or "." in path.parts or ".." in path.parts or ":" in path.parts[0] or path.as_posix() != raw:
        raise AssertionError(raw)
    return raw


def decode(entry: dict[str, object], root: Path = SNAPSHOT_ROOT) -> bytes:
    name = safe_path(entry["snapshot_path"])
    if "/" in name:
        raise AssertionError(name)
    source = (root / name).read_bytes()
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


class AsWp3ParentSnapshotTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        if EXPECTED_MANIFEST_RAW != sha(MANIFEST_PATH.read_bytes()):
            raise AssertionError("AS-WP3 snapshot raw drift")
        cls.manifest = load_json_strict(MANIFEST_PATH)
        if EXPECTED_MANIFEST_CANONICAL != sha(canonical_json_v1_bytes(cls.manifest)):
            raise AssertionError("AS-WP3 snapshot canonical drift")
        cls.entries = {safe_path(entry["original_path"]): entry for entry in cls.manifest["files"]}

    def test_payloads_are_exact_safe_complete_and_bind_as_wp2(self) -> None:
        self.assertEqual("AS-WP3", self.manifest["work_package"])
        self.assertEqual(15, self.manifest["file_count"])
        self.assertEqual(15, len(self.entries))
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
        scope = self.manifest["rollback_scope"]
        self.assertEqual(set(self.entries), set(scope["restore_exact_paths"]))
        self.assertEqual(5, len(set(scope["delete_exact_paths"])))
        self.assertFalse(set(self.entries) & set(scope["delete_exact_paths"]))
        self.assertEqual(EXPECTED_CLEAN_PARENT_PATHS, set(scope["omit_parent_clean_paths"]))
        self.assertEqual("artifacts/ptcgdap/as_wp3/", scope["delete_evidence_prefix"])
        names = [entry["snapshot_path"] for entry in self.entries.values()]
        self.assertEqual({"manifest.json", *names}, {path.name for path in SNAPSHOT_ROOT.iterdir() if path.is_file()})
        for entry in self.entries.values():
            decode(entry)

    def test_isolated_restore_contains_only_parent_files(self) -> None:
        with tempfile.TemporaryDirectory(prefix="ptcgdap-as-wp3-parent-") as temp:
            restore_root = Path(temp)
            for path, entry in self.entries.items():
                destination = restore_root / path
                destination.parent.mkdir(parents=True, exist_ok=True)
                destination.write_bytes(decode(entry))
            self.assertEqual(
                set(self.entries),
                {path.relative_to(restore_root).as_posix() for path in restore_root.rglob("*") if path.is_file()},
            )

    def test_virtual_rollback_reproduces_pre_as_wp3_candidate(self) -> None:
        parent_bytes = {path: decode(entry) for path, entry in self.entries.items()}
        scope = self.manifest["rollback_scope"]
        delete_paths = set(scope["delete_exact_paths"])
        omit_clean_paths = set(scope["omit_parent_clean_paths"])
        delete_prefix = scope["delete_evidence_prefix"]
        as_wp4_successor = load_json_strict(AS_WP4_SUCCESSOR_MANIFEST_PATH)
        as_wp4_parent_bytes = {
            safe_path(entry["original_path"]): decode(entry, AS_WP4_SUCCESSOR_ROOT)
            for entry in as_wp4_successor["files"]
        }
        as_wp4_additive_paths = set(
            load_json_strict(AS_WP4_WORK_PACKAGE_PATH)["files_allowed"]["as_wp4_additive"]
        )
        records = []
        restored = set()
        observed_paths = set()
        for code, path in status():
            if is_dragapult_acceptance_additive(path):
                continue
            if (
                is_as_wp5_path(path)
                or is_as_wp5_parent_clean_path(path)
                or path in as_wp4_additive_paths
                or path.startswith(AS_WP4_EVIDENCE_PREFIX)
                or path in delete_paths
                or path.startswith(delete_prefix)
            ):
                continue
            observed_paths.add(path)
            if path in parent_bytes:
                data = parent_bytes[path]
                restored.add(path)
                if path in omit_clean_paths:
                    continue
            elif path in as_wp4_parent_bytes:
                data = as_wp4_parent_bytes[path]
            elif "D" in code:
                data = None
            else:
                data = as_wp5_parent_bytes(
                    path,
                    restore_pre_dragapult_bytes(path, (ROOT / path).read_bytes()),
                )
            records.append(
                restore_pre_author_player_owner_record("AS-WP3", {
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
