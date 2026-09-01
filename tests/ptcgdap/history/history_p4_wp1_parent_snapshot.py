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
from tests.ptcgdap.test_p3_wp7_parent_snapshot import P4_WP5_PATHS, P4_WP6_PATHS
from tests.ptcgdap.test_p3_wp7_parent_snapshot import P4_WP2_PATHS, P4_WP3_PATHS, P4_WP4_PATHS


ROOT = Path(__file__).resolve().parents[2]
P5_WP1_PATHS = frozenset(
    load_json_strict(ROOT / "artifacts/ptcgdap/p5_wp1/parent_snapshot/manifest.json")["rollback_scope"]["delete_exact_paths"]
)
P5_WP2_PATHS = frozenset(
    load_json_strict(ROOT / "artifacts/ptcgdap/p5_wp2/parent_snapshot/manifest.json")["rollback_scope"]["delete_exact_paths"]
)
SNAPSHOT_ROOT = ROOT / "artifacts/ptcgdap/p4_wp1/parent_snapshot"
MANIFEST_PATH = SNAPSHOT_ROOT / "manifest.json"
PARENT_MANIFEST_PATH = ROOT / "artifacts/ptcgdap/p3_wp8/manifest.json"
EXPECTED_MANIFEST_RAW = "81B67B9AFCBD75B2CF5E5BB2619CE824297516042F4D0AA6F59FF558B4D5ECE3"
EXPECTED_MANIFEST_CANONICAL = "FB198F10E6572A10883520DC12BE1BB1620B44BC21AA62C34D6881C30151C787"
EXPECTED_PARENT_MANIFEST_RAW = "E4FC0A98E75AA40BC6243076C2163F28D3B6BBF39C6C9011950DAACC8552E274"
EXPECTED_PARENT_MANIFEST_CANONICAL = "E44B6DE0DD52C9357BE96F44D6C9B8C1A799D51C747660007C53E9BEB055BF25"
EXPECTED_PARENT_DIGEST = "1F1F5459A57842CD5A04015AE9FD853D8AEC3ED99DA832D4FBA55415FB22B849"
EXPECTED_COUNTS = {"untracked": 651, "deleted": 28, "modified": 1}
P4_WP1_PATHS = {
    "contracts/ptcgdap/strategic_context_v18.schema.json",
    "contracts/ptcgdap/strategic_context_v18_profile.json",
    "contracts/ptcgdap/strategic_context_v18_conformance_vectors.json",
    "contracts/ptcgdap/strategic_context_v18_bundle.json",
    "scripts/ai/ptcgdap/strategic_context_v18.py",
    "scripts/ai/ptcgdap/public/StrategicContextV18.gd",
    "tools/ptcgdap/build_strategic_context_v18_contract.py",
    "tests/ptcgdap/test_strategic_context_v18_contract_builder.py",
    "tests/ptcgdap/test_strategic_context_v18.py",
    "tests/ptcgdap/test_strategic_context_v18_properties.py",
    "tests/ptcgdap/test_p4_wp1_boundaries.py",
    "tests/ptcgdap/test_p4_wp1_parent_snapshot.py",
    "tests/ptcgdap/godot/test_strategic_context_v18.gd",
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


def decode(entry: dict[str, object]) -> bytes:
    snapshot_name = safe_path(entry["snapshot_path"])
    if "/" in snapshot_name:
        raise AssertionError(snapshot_name)
    encoded_file = (SNAPSHOT_ROOT / snapshot_name).read_bytes()
    if not encoded_file.endswith(b"\n") or encoded_file.count(b"\n") != 1 or b"\r" in encoded_file:
        raise AssertionError(snapshot_name)
    encoded = encoded_file[:-1]
    value = base64.b64decode(encoded.decode("ascii"), validate=True)
    if base64.b64encode(value) != encoded:
        raise AssertionError(snapshot_name)
    if len(encoded_file) != entry["snapshot_file_bytes"] or sha(encoded_file) != entry["snapshot_file_raw_sha256"]:
        raise AssertionError(snapshot_name)
    if len(value) != entry["bytes"] or sha(value) != entry["raw_sha256"]:
        raise AssertionError(snapshot_name)
    return value


def status() -> list[tuple[str, str]]:
    output = subprocess.run(
        ["git", "status", "--porcelain=v1", "-z", "--untracked-files=all"],
        cwd=ROOT,
        check=True,
        capture_output=True,
    ).stdout
    records: list[tuple[str, str]] = []
    for record in output.split(b"\0"):
        if not record:
            continue
        code = record[:2].decode("ascii")
        path = safe_path(record[3:].decode("utf-8").replace("\\", "/"))
        if path.startswith("artifacts/ptcgdap/p5_wp1/") or path in P5_WP1_PATHS or path.startswith("artifacts/ptcgdap/p5_wp2/") or path in P5_WP2_PATHS or is_p5_wp3_path(path):
            continue
        if "R" in code or "C" in code:
            raise AssertionError("rename/copy outside snapshot algorithm")
        records.append((code, path))
    return records


class P4Wp1ParentSnapshotTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        raw = MANIFEST_PATH.read_bytes()
        if sha(raw) != EXPECTED_MANIFEST_RAW:
            raise AssertionError("P4-WP1 snapshot raw drift")
        cls.manifest = load_json_strict(MANIFEST_PATH)
        if sha(canonical_json_v1_bytes(cls.manifest)) != EXPECTED_MANIFEST_CANONICAL:
            raise AssertionError("P4-WP1 snapshot canonical drift")
        cls.entries = {safe_path(entry["original_path"]): entry for entry in cls.manifest["files"]}

    def test_payloads_are_exact_safe_complete_and_bind_parent(self) -> None:
        self.assertEqual(self.manifest["file_count"], 24)
        self.assertEqual(len(self.entries), 24)
        parent = self.manifest["parent"]
        self.assertEqual(parent["manifest_raw_sha256"], EXPECTED_PARENT_MANIFEST_RAW)
        self.assertEqual(parent["manifest_canonical_sha256"], EXPECTED_PARENT_MANIFEST_CANONICAL)
        self.assertEqual(parent["worktree_snapshot_canonical_sha256"], EXPECTED_PARENT_DIGEST)
        self.assertEqual(parent["worktree_status_counts"], EXPECTED_COUNTS)
        self.assertEqual(sha(PARENT_MANIFEST_PATH.read_bytes()), EXPECTED_PARENT_MANIFEST_RAW)
        self.assertEqual(
            sha(canonical_json_v1_bytes(load_json_strict(PARENT_MANIFEST_PATH))),
            EXPECTED_PARENT_MANIFEST_CANONICAL,
        )
        scope = self.manifest["rollback_scope"]
        self.assertEqual(set(scope["restore_exact_paths"]), set(self.entries))
        self.assertEqual(set(scope["delete_exact_paths"]), P4_WP1_PATHS)
        self.assertEqual(scope["delete_evidence_prefix"], "artifacts/ptcgdap/p4_wp1/")
        names = [entry["snapshot_path"] for entry in self.entries.values()]
        self.assertEqual(len(names), len(set(names)))
        self.assertEqual(
            {path.name for path in SNAPSHOT_ROOT.iterdir() if path.is_file()},
            {"manifest.json", *names},
        )
        for entry in self.entries.values():
            decode(entry)

    def test_isolated_restore_contains_only_parent_files(self) -> None:
        with tempfile.TemporaryDirectory(prefix="ptcgdap-p4-wp1-parent-") as temp:
            root = Path(temp)
            for path, entry in self.entries.items():
                destination = root / path
                destination.parent.mkdir(parents=True, exist_ok=True)
                destination.write_bytes(decode(entry))
            self.assertEqual(
                {path.relative_to(root).as_posix() for path in root.rglob("*") if path.is_file()},
                set(self.entries),
            )

    def test_virtual_rollback_reproduces_p3_wp8_candidate(self) -> None:
        parent_bytes = {path: decode(entry) for path, entry in self.entries.items()}
        records: list[dict[str, object]] = []
        restored: set[str] = set()
        for code, path in status():
            if path.startswith("artifacts/ptcgdap/p3_wp8/") or path.startswith("artifacts/ptcgdap/p4_wp1/") or path in P4_WP1_PATHS or path.startswith("artifacts/ptcgdap/p4_wp2/") or path in P4_WP2_PATHS or path.startswith("artifacts/ptcgdap/p4_wp3/") or path in P4_WP3_PATHS or path.startswith("artifacts/ptcgdap/p4_wp4/") or path in P4_WP4_PATHS or path.startswith("artifacts/ptcgdap/p4_wp5/") or path in P4_WP5_PATHS or path.startswith("artifacts/ptcgdap/p4_wp6/") or path in P4_WP6_PATHS:
                continue
            if path in parent_bytes:
                data = parent_bytes[path]
                restored.add(path)
            elif path in P5_WP2_PARENT_BYTES:
                data = P5_WP2_PARENT_BYTES[path]
            elif "D" in code:
                data = None
            else:
                data = p5_wp4_parent_bytes(path, (ROOT / path).read_bytes())
            records.append(
                {
                    "path": path,
                    "status": code,
                    "bytes": None if data is None else len(data),
                    "sha256": None if data is None else sha(data),
                }
            )
        self.assertEqual(restored, set(parent_bytes))
        records.sort(key=lambda item: item["path"])
        counts = Counter(
            "untracked" if item["status"] == "??" else "deleted" if "D" in item["status"] else "modified"
            for item in records
        )
        self.assertEqual(len(records), 680)
        self.assertEqual(dict(counts), EXPECTED_COUNTS)
        self.assertEqual(sha(canonical_json_v1_bytes(records)), EXPECTED_PARENT_DIGEST)


if __name__ == "__main__":
    unittest.main()
