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
SNAPSHOT_ROOT = ROOT / "artifacts/ptcgdap/as_wp2/parent_snapshot"
MANIFEST_PATH = SNAPSHOT_ROOT / "manifest.json"
PARENT_MANIFEST_PATH = ROOT / "artifacts/ptcgdap/as_wp1/manifest.json"
SUCCESSOR_MANIFEST_PATH = ROOT / "artifacts/ptcgdap/as_wp3/parent_snapshot/manifest.json"
AS_WP4_SUCCESSOR_ROOT = ROOT / "artifacts/ptcgdap/as_wp4/parent_snapshot"
AS_WP4_SUCCESSOR_MANIFEST_PATH = AS_WP4_SUCCESSOR_ROOT / "manifest.json"
AS_WP4_WORK_PACKAGE_PATH = ROOT / "artifacts/ptcgdap/as_wp4/work_package.json"
AS_WP4_EVIDENCE_PREFIX = "artifacts/ptcgdap/as_wp4/"
EXPECTED_MANIFEST_RAW = "29C83B75BBC6070C7D9FC45FDC086DD0CFB6F454B974F76D0A838610EACC7521"
EXPECTED_MANIFEST_CANONICAL = "917F3FD4E0C89AF4D3D66067B874C3CF4B15BAA3A1FBFD6A52C414D1B0C89AE7"
EXPECTED_PARENT_MANIFEST_RAW = "3D717BA5C8171F17792A6FC407DF82DCA2F17B214CA57C08DFF5038B185177C0"
EXPECTED_PARENT_MANIFEST_CANONICAL = "CA44A3BEE5910116D8DF6467B6BBAF074609A64772B7BA67055A162D9E89DA41"
EXPECTED_PACKAGE_BUNDLE = "B416F2CBA2795B62126B6EF7B5F07A9000E84D5FA1DF62C1753CADC9E82E106B"
EXPECTED_SOURCE_LOCK = "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"
EXPECTED_PARENT_ENTRY_COUNT = 1611
EXPECTED_PARENT_COUNTS = {"deleted": 28, "modified": 2, "untracked": 1581}
EXPECTED_PARENT_DIGEST = "4AF465BEA81C08589598E08E0FBCCF7C588C46A8BAC8DAC37B8F1C2F213FA537"


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


class AsWp2ParentSnapshotTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        if EXPECTED_MANIFEST_RAW != sha(MANIFEST_PATH.read_bytes()):
            raise AssertionError("AS-WP2 snapshot raw drift")
        cls.manifest = load_json_strict(MANIFEST_PATH)
        if EXPECTED_MANIFEST_CANONICAL != sha(canonical_json_v1_bytes(cls.manifest)):
            raise AssertionError("AS-WP2 snapshot canonical drift")
        cls.entries = {safe_path(entry["original_path"]): entry for entry in cls.manifest["files"]}

    def test_payloads_are_exact_safe_complete_and_bind_as_wp1(self) -> None:
        self.assertEqual("AS-WP2", self.manifest["work_package"])
        self.assertEqual(13, self.manifest["file_count"])
        self.assertEqual(13, len(self.entries))
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
        self.assertEqual(10, len(set(scope["delete_exact_paths"])))
        self.assertFalse(set(self.entries) & set(scope["delete_exact_paths"]))
        self.assertEqual(["export_presets.cfg"], scope["omit_parent_clean_paths"])
        self.assertEqual("tests/ptcgdap/fixtures/author_strategy_packages/as_wp2/", scope["delete_fixture_prefix"])
        self.assertEqual("artifacts/ptcgdap/as_wp2/", scope["delete_evidence_prefix"])
        names = [entry["snapshot_path"] for entry in self.entries.values()]
        self.assertEqual({"manifest.json", *names}, {path.name for path in SNAPSHOT_ROOT.iterdir() if path.is_file()})
        for entry in self.entries.values():
            decode(entry)

    def test_isolated_restore_contains_only_parent_files(self) -> None:
        with tempfile.TemporaryDirectory(prefix="ptcgdap-as-wp2-parent-") as temp:
            restore_root = Path(temp)
            for path, entry in self.entries.items():
                destination = restore_root / path
                destination.parent.mkdir(parents=True, exist_ok=True)
                destination.write_bytes(decode(entry))
            self.assertEqual(
                set(self.entries),
                {path.relative_to(restore_root).as_posix() for path in restore_root.rglob("*") if path.is_file()},
            )

    def test_virtual_rollback_reproduces_pre_as_wp2_candidate(self) -> None:
        parent_bytes = {path: decode(entry) for path, entry in self.entries.items()}
        scope = self.manifest["rollback_scope"]
        delete_paths = set(scope["delete_exact_paths"])
        omit_clean_paths = set(scope["omit_parent_clean_paths"])
        delete_prefixes = (scope["delete_fixture_prefix"], scope["delete_evidence_prefix"])
        successor_scope = load_json_strict(SUCCESSOR_MANIFEST_PATH)["rollback_scope"]
        successor_delete_paths = set(successor_scope["delete_exact_paths"])
        successor_omit_clean_paths = set(successor_scope["omit_parent_clean_paths"])
        successor_delete_prefix = successor_scope["delete_evidence_prefix"]
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
                or path in successor_delete_paths
                or path in successor_omit_clean_paths
                or path.startswith(successor_delete_prefix)
                or path in delete_paths
                or path.startswith(delete_prefixes)
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
                restore_pre_author_player_owner_record("AS-WP2", {
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
