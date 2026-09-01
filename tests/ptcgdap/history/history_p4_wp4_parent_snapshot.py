from __future__ import annotations

import base64
from collections import Counter
import hashlib
from pathlib import Path, PurePosixPath
import subprocess
import tempfile
import unittest

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict
from tests.ptcgdap.test_p5_wp3_parent_snapshot import is_p5_wp3_path, p5_wp4_parent_bytes
from tests.ptcgdap.test_p3_wp7_parent_snapshot import P5_WP2_PARENT_BYTES
from tests.ptcgdap.test_p3_wp7_parent_snapshot import P4_WP5_PARENT_BYTES, P4_WP5_PATHS, P4_WP6_PATHS


ROOT = Path(__file__).resolve().parents[2]
P5_WP1_PATHS = frozenset(
    load_json_strict(ROOT / "artifacts/ptcgdap/p5_wp1/parent_snapshot/manifest.json")["rollback_scope"]["delete_exact_paths"]
)
P5_WP2_PATHS = frozenset(
    load_json_strict(ROOT / "artifacts/ptcgdap/p5_wp2/parent_snapshot/manifest.json")["rollback_scope"]["delete_exact_paths"]
)
SNAPSHOT_ROOT = ROOT / "artifacts/ptcgdap/p4_wp4/parent_snapshot"
MANIFEST_PATH = SNAPSHOT_ROOT / "manifest.json"
PARENT_MANIFEST_PATH = ROOT / "artifacts/ptcgdap/p4_wp3/manifest.json"
EXPECTED_MANIFEST_RAW = "A2F90642170B0C0A8845C685A8BD1CFDAC8299E4B9CAB1B3D9184EEBC0EE0EF2"
EXPECTED_MANIFEST_CANONICAL = "C70B813095D7FC71674C1444F23D07F78244B7C50BB51E1E4F195476BBDC7A6E"
EXPECTED_PARENT_MANIFEST_RAW = "9F941CEDC4A721C55EBF9F42B2528D9916A29A44B33BDDE31616A603FBBCB2AC"
EXPECTED_PARENT_MANIFEST_CANONICAL = "2B7672E1BF4A448111A1A03BE10AA6BBFED0C16A97BA7CAF8AAB8A90244A2D8C"
EXPECTED_PARENT_DIGEST = "B464E8A00EA350F8DF7A2EFD98AD6AEE4A9D325737A4A0BE083296547E282D39"
EXPECTED_COUNTS = {"untracked": 799, "deleted": 28, "modified": 1}


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
    result = []
    for record in output.split(b"\0"):
        if not record:
            continue
        code = record[:2].decode("ascii")
        path = safe_path(record[3:].decode("utf-8").replace("\\", "/"))
        if path.startswith("artifacts/ptcgdap/p5_wp1/") or path in P5_WP1_PATHS or path.startswith("artifacts/ptcgdap/p5_wp2/") or path in P5_WP2_PATHS or is_p5_wp3_path(path):
            continue
        if "R" in code or "C" in code:
            raise AssertionError("rename/copy outside snapshot algorithm")
        result.append((code, path))
    return result


class P4Wp4ParentSnapshotTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        raw = MANIFEST_PATH.read_bytes()
        if sha(raw) != EXPECTED_MANIFEST_RAW:
            raise AssertionError("P4-WP4 snapshot raw drift")
        cls.manifest = load_json_strict(MANIFEST_PATH)
        if sha(canonical_json_v1_bytes(cls.manifest)) != EXPECTED_MANIFEST_CANONICAL:
            raise AssertionError("P4-WP4 snapshot canonical drift")
        cls.entries = {safe_path(entry["original_path"]): entry for entry in cls.manifest["files"]}

    def test_payloads_are_exact_safe_complete_and_bind_parent(self) -> None:
        self.assertEqual(29, self.manifest["file_count"])
        self.assertEqual(29, len(self.entries))
        parent = self.manifest["parent"]
        self.assertEqual(EXPECTED_PARENT_MANIFEST_RAW, parent["manifest_raw_sha256"])
        self.assertEqual(EXPECTED_PARENT_MANIFEST_CANONICAL, parent["manifest_canonical_sha256"])
        self.assertEqual(EXPECTED_PARENT_DIGEST, parent["worktree_snapshot_canonical_sha256"])
        self.assertEqual(EXPECTED_COUNTS, parent["worktree_status_counts"])
        self.assertEqual(EXPECTED_PARENT_MANIFEST_RAW, sha(PARENT_MANIFEST_PATH.read_bytes()))
        scope = self.manifest["rollback_scope"]
        self.assertEqual(set(self.entries), set(scope["restore_exact_paths"]))
        self.assertEqual(13, len(set(scope["delete_exact_paths"])))
        self.assertEqual("artifacts/ptcgdap/p4_wp4/", scope["delete_evidence_prefix"])
        names = [entry["snapshot_path"] for entry in self.entries.values()]
        self.assertEqual(len(names), len(set(names)))
        self.assertEqual({"manifest.json", *names}, {path.name for path in SNAPSHOT_ROOT.iterdir() if path.is_file()})
        for entry in self.entries.values():
            decode(entry)

    def test_isolated_restore_contains_only_parent_files(self) -> None:
        with tempfile.TemporaryDirectory(prefix="ptcgdap-p4-wp4-parent-") as temp:
            restore_root = Path(temp)
            for path, entry in self.entries.items():
                destination = restore_root / path
                destination.parent.mkdir(parents=True, exist_ok=True)
                destination.write_bytes(decode(entry))
            self.assertEqual(set(self.entries), {path.relative_to(restore_root).as_posix() for path in restore_root.rglob("*") if path.is_file()})

    def test_virtual_rollback_reproduces_p4_wp3_candidate(self) -> None:
        parent_bytes = {path: decode(entry) for path, entry in self.entries.items()}
        delete_paths = set(self.manifest["rollback_scope"]["delete_exact_paths"])
        records = []
        restored = set()
        for code, path in status():
            if path.startswith("artifacts/ptcgdap/p4_wp3/") or path.startswith("artifacts/ptcgdap/p4_wp4/") or path in delete_paths or path.startswith("artifacts/ptcgdap/p4_wp5/") or path in P4_WP5_PATHS or path.startswith("artifacts/ptcgdap/p4_wp6/") or path in P4_WP6_PATHS:
                continue
            if path in parent_bytes:
                data = parent_bytes[path]
                restored.add(path)
            elif path in P4_WP5_PARENT_BYTES:
                data = P4_WP5_PARENT_BYTES[path]
            elif path in P5_WP2_PARENT_BYTES:
                data = P5_WP2_PARENT_BYTES[path]
            elif "D" in code:
                data = None
            else:
                data = p5_wp4_parent_bytes(path, (ROOT / path).read_bytes())
            records.append({"path": path, "status": code, "bytes": None if data is None else len(data), "sha256": None if data is None else sha(data)})
        self.assertEqual(set(parent_bytes), restored)
        records.sort(key=lambda item: item["path"])
        counts = Counter("untracked" if item["status"] == "??" else "deleted" if "D" in item["status"] else "modified" for item in records)
        self.assertEqual(828, len(records))
        self.assertEqual(EXPECTED_COUNTS, dict(counts))
        self.assertEqual(EXPECTED_PARENT_DIGEST, sha(canonical_json_v1_bytes(records)))


if __name__ == "__main__":
    unittest.main()
