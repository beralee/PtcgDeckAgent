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
SNAPSHOT_ROOT = ROOT / "artifacts/ptcgdap/as_wp1/parent_snapshot"
MANIFEST_PATH = SNAPSHOT_ROOT / "manifest.json"
SUPPLEMENTAL_ROOT = ROOT / "artifacts/ptcgdap/as_wp1/supplemental_parent_snapshot"
SUPPLEMENTAL_MANIFEST_PATH = SUPPLEMENTAL_ROOT / "manifest.json"
PARENT_MANIFEST_PATH = ROOT / "artifacts/ptcgdap/as_wp0/manifest.json"
SUCCESSOR_ROOT = ROOT / "artifacts/ptcgdap/as_wp2/parent_snapshot"
SUCCESSOR_MANIFEST_PATH = SUCCESSOR_ROOT / "manifest.json"
LATEST_SUCCESSOR_MANIFEST_PATH = ROOT / "artifacts/ptcgdap/as_wp3/parent_snapshot/manifest.json"
AS_WP4_SUCCESSOR_ROOT = ROOT / "artifacts/ptcgdap/as_wp4/parent_snapshot"
AS_WP4_SUCCESSOR_MANIFEST_PATH = AS_WP4_SUCCESSOR_ROOT / "manifest.json"
AS_WP4_WORK_PACKAGE_PATH = ROOT / "artifacts/ptcgdap/as_wp4/work_package.json"
AS_WP4_EVIDENCE_PREFIX = "artifacts/ptcgdap/as_wp4/"
EXPECTED_MANIFEST_RAW = "D854DEFAEE054D8956050A569C3F0C25BB6AFAF0A48AA46B8130A519AF6D3738"
EXPECTED_MANIFEST_CANONICAL = "CD384C0A81B97837085E81759D85B654565AD58145DBF3D0F99B92770FBD65AE"
EXPECTED_SUPPLEMENTAL_MANIFEST_RAW = "3D23B24B3B6652EA22EAF56297EE5F23A23F17939E75D5F2F9AA0F013D0739B2"
EXPECTED_SUPPLEMENTAL_MANIFEST_CANONICAL = "04AA38E208894A185FD69FC89FBF89275F835F53D08F45D68A7A5038E6AB7176"
EXPECTED_PARENT_MANIFEST_RAW = "4FE26588FCEC67BFF56F64BE6BF0019F343BA07DA04C972E20C1727CDDBEDDB7"
EXPECTED_PARENT_MANIFEST_CANONICAL = "43DE8A833E9D5E7F10E72652D07DB824748714BC6B48A489A79FDA829A8C695F"
EXPECTED_PORTABLE_POLICY_BUNDLE = "992B7F00DF412496BA414ABCC87C21C6136CB513C9C90799C897ADD18D15EDB2"
EXPECTED_SOURCE_LOCK = "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"
EXPECTED_PARENT_ENTRY_COUNT = 1575
EXPECTED_PARENT_COUNTS = {"deleted": 28, "modified": 2, "untracked": 1545}
EXPECTED_PARENT_DIGEST = "CF2A424546969DC4E4256C02A1E4322BDA06906DDA562E1192CFF06DD8C25434"


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


class AsWp1ParentSnapshotTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        if EXPECTED_MANIFEST_RAW != sha(MANIFEST_PATH.read_bytes()):
            raise AssertionError("AS-WP1 snapshot raw drift")
        cls.manifest = load_json_strict(MANIFEST_PATH)
        if EXPECTED_MANIFEST_CANONICAL != sha(canonical_json_v1_bytes(cls.manifest)):
            raise AssertionError("AS-WP1 snapshot canonical drift")
        cls.entries = {safe_path(entry["original_path"]): entry for entry in cls.manifest["files"]}

    def test_payloads_are_exact_safe_complete_and_bind_as_wp0(self) -> None:
        self.assertEqual("AS-WP1", self.manifest["work_package"])
        self.assertEqual(9, self.manifest["file_count"])
        self.assertEqual(9, len(self.entries))
        parent = self.manifest["parent"]
        self.assertEqual(EXPECTED_PARENT_MANIFEST_RAW, parent["manifest_raw_sha256"])
        self.assertEqual(EXPECTED_PARENT_MANIFEST_CANONICAL, parent["manifest_canonical_sha256"])
        self.assertEqual(EXPECTED_PORTABLE_POLICY_BUNDLE, parent["portable_policy_bundle_canonical_sha256"])
        self.assertEqual(EXPECTED_SOURCE_LOCK, parent["source_lock_canonical_sha256"])
        self.assertEqual(EXPECTED_PARENT_ENTRY_COUNT, parent["worktree_entry_count"])
        self.assertEqual(EXPECTED_PARENT_COUNTS, parent["worktree_status_counts"])
        self.assertEqual(EXPECTED_PARENT_DIGEST, parent["worktree_snapshot_canonical_sha256"])
        self.assertEqual(EXPECTED_PARENT_MANIFEST_RAW, sha(PARENT_MANIFEST_PATH.read_bytes()))
        self.assertEqual(EXPECTED_PARENT_MANIFEST_CANONICAL, sha(canonical_json_v1_bytes(load_json_strict(PARENT_MANIFEST_PATH))))
        scope = self.manifest["rollback_scope"]
        self.assertEqual(set(self.entries), set(scope["restore_exact_paths"]))
        self.assertEqual(9, len(set(scope["delete_exact_paths"])))
        self.assertFalse(set(self.entries) & set(scope["delete_exact_paths"]))
        self.assertEqual("artifacts/ptcgdap/as_wp1/", scope["delete_evidence_prefix"])
        names = [entry["snapshot_path"] for entry in self.entries.values()]
        self.assertEqual({"manifest.json", *names}, {path.name for path in SNAPSHOT_ROOT.iterdir() if path.is_file()})
        for entry in self.entries.values():
            decode(entry)

    def test_isolated_restore_contains_only_parent_files(self) -> None:
        with tempfile.TemporaryDirectory(prefix="ptcgdap-as-wp1-parent-") as temp:
            restore_root = Path(temp)
            for path, entry in self.entries.items():
                destination = restore_root / path
                destination.parent.mkdir(parents=True, exist_ok=True)
                destination.write_bytes(decode(entry))
            self.assertEqual(
                set(self.entries),
                {path.relative_to(restore_root).as_posix() for path in restore_root.rglob("*") if path.is_file()},
            )

    def test_supplemental_compatibility_snapshot_is_exact_and_disjoint(self) -> None:
        self.assertEqual(EXPECTED_SUPPLEMENTAL_MANIFEST_RAW, sha(SUPPLEMENTAL_MANIFEST_PATH.read_bytes()))
        supplemental = load_json_strict(SUPPLEMENTAL_MANIFEST_PATH)
        self.assertEqual(
            EXPECTED_SUPPLEMENTAL_MANIFEST_CANONICAL,
            sha(canonical_json_v1_bytes(supplemental)),
        )
        self.assertEqual("AS-WP1-supplemental", supplemental["work_package"])
        self.assertEqual(1, supplemental["file_count"])
        paths = {safe_path(entry["original_path"]) for entry in supplemental["files"]}
        self.assertEqual({"tests/ptcgdap/test_p5_wp7_parent_snapshot.py"}, paths)
        self.assertFalse(paths & set(self.entries))
        for entry in supplemental["files"]:
            decode(entry, SUPPLEMENTAL_ROOT)

    def test_virtual_rollback_reproduces_pre_as_wp1_candidate(self) -> None:
        parent_bytes = {path: decode(entry) for path, entry in self.entries.items()}
        supplemental = load_json_strict(SUPPLEMENTAL_MANIFEST_PATH)
        for entry in supplemental["files"]:
            parent_bytes[safe_path(entry["original_path"])] = decode(entry, SUPPLEMENTAL_ROOT)
        scope = self.manifest["rollback_scope"]
        delete_paths = set(scope["delete_exact_paths"])
        delete_prefix = scope["delete_evidence_prefix"]
        successor = load_json_strict(SUCCESSOR_MANIFEST_PATH)
        successor_scope = successor["rollback_scope"]
        successor_parent_bytes = {
            safe_path(entry["original_path"]): decode(entry, SUCCESSOR_ROOT)
            for entry in successor["files"]
        }
        successor_delete_paths = set(successor_scope["delete_exact_paths"])
        successor_omit_clean_paths = set(successor_scope["omit_parent_clean_paths"])
        successor_delete_prefixes = (
            successor_scope["delete_evidence_prefix"],
            successor_scope["delete_fixture_prefix"],
        )
        latest_scope = load_json_strict(LATEST_SUCCESSOR_MANIFEST_PATH)["rollback_scope"]
        latest_delete_paths = set(latest_scope["delete_exact_paths"])
        latest_omit_clean_paths = set(latest_scope["omit_parent_clean_paths"])
        latest_delete_prefix = latest_scope["delete_evidence_prefix"]
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
        for code, path in status():
            if is_dragapult_acceptance_additive(path):
                continue
            if (
                is_as_wp5_path(path)
                or is_as_wp5_parent_clean_path(path)
                or path in as_wp4_additive_paths
                or path.startswith(AS_WP4_EVIDENCE_PREFIX)
                or path.startswith(latest_delete_prefix)
                or path in latest_delete_paths
                or path in latest_omit_clean_paths
                or path.startswith(successor_delete_prefixes)
                or path in successor_delete_paths
                or path in successor_omit_clean_paths
                or path.startswith(delete_prefix)
                or path in delete_paths
            ):
                continue
            if path in parent_bytes:
                data = parent_bytes[path]
                restored.add(path)
            elif path in successor_parent_bytes:
                data = successor_parent_bytes[path]
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
                restore_pre_author_player_owner_record("AS-WP1", {
                    "path": path,
                    "status": code,
                    "bytes": None if data is None else len(data),
                    "sha256": None if data is None else sha(data),
                })
            )
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
