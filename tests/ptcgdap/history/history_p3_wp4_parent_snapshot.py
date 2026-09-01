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
from tests.ptcgdap.test_p3_wp6_parent_snapshot import P3_WP6_PATHS
from tests.ptcgdap.test_p3_wp7_parent_snapshot import P3_WP7_PATHS, P3_WP8_PATHS, P4_WP1_PARENT_BYTES, P4_WP1_PATHS, P4_WP2_PATHS, P4_WP3_PATHS, P4_WP4_PATHS


ROOT = Path(__file__).resolve().parents[2]
P5_WP1_PATHS = frozenset(
    load_json_strict(ROOT / "artifacts/ptcgdap/p5_wp1/parent_snapshot/manifest.json")["rollback_scope"]["delete_exact_paths"]
)
P5_WP2_PATHS = frozenset(
    load_json_strict(ROOT / "artifacts/ptcgdap/p5_wp2/parent_snapshot/manifest.json")["rollback_scope"]["delete_exact_paths"]
)
SNAPSHOT_ROOT = ROOT / "artifacts/ptcgdap/p3_wp4/parent_snapshot"
MANIFEST_PATH = SNAPSHOT_ROOT / "manifest.json"
EXPECTED_MANIFEST_RAW = "D3268DADC5D6E737E4206DDFCBE327CAA0AEF3EC3711F1D7649FE267E364A161"
EXPECTED_MANIFEST_CANONICAL = "D271A2B97F8E6913A98CF9C9924317CDEB8132B4DEABBF1F5C9F7A9AD88C7665"
EXPECTED_PARENT_MANIFEST_RAW = "9564EE72D2BD400D010123E8563F50CCF0233BDC6436A3C35FDCDD9F78710556"
EXPECTED_PARENT_MANIFEST_CANONICAL = "5ACC39769D3A63EA7B27CAA61B107FCCF284DC52FCFB93F9B77B1547883FAF2B"
EXPECTED_PARENT_DIGEST = "2D54DC26B3FF96859252C43415D82F63F6E4D6657917BB7D484A3A4FF33CB994"
EXPECTED_COUNTS = {"untracked": 421, "deleted": 28, "modified": 1}
P3_WP4_PATHS = {
    "contracts/ptcgdap/godot_action_executor.schema.json",
    "contracts/ptcgdap/godot_action_executor_profile.json",
    "contracts/ptcgdap/godot_action_executor_conformance_vectors.json",
    "contracts/ptcgdap/godot_action_executor_bundle.json",
    "scripts/ai/ptcgdap/godot_action_executor.py",
    "scripts/engine/decision/GodotActionExecutor.gd",
    "tools/ptcgdap/build_godot_action_executor_contract.py",
    "tests/ptcgdap/test_godot_action_executor_contract_builder.py",
    "tests/ptcgdap/test_godot_action_executor.py",
    "tests/ptcgdap/test_godot_action_executor_properties.py",
    "tests/ptcgdap/test_p3_wp4_boundaries.py",
    "tests/ptcgdap/test_p3_wp4_parent_snapshot.py",
    "tests/ptcgdap/godot/test_godot_action_executor.gd",
}
P3_WP5_PREFIX = "artifacts/ptcgdap/p3_wp5/"
P3_WP5_PATHS = {
    "contracts/ptcgdap/shadow_prompt_broker.schema.json", "contracts/ptcgdap/shadow_prompt_broker_profile.json",
    "contracts/ptcgdap/shadow_prompt_broker_conformance_vectors.json", "contracts/ptcgdap/shadow_prompt_broker_bundle.json",
    "scripts/ai/ptcgdap/shadow_prompt_broker.py", "scripts/engine/decision/ShadowPromptBroker.gd",
    "tools/ptcgdap/build_shadow_prompt_broker_contract.py", "tests/ptcgdap/test_shadow_prompt_broker_contract_builder.py",
    "tests/ptcgdap/test_shadow_prompt_broker.py", "tests/ptcgdap/test_shadow_prompt_broker_properties.py",
    "tests/ptcgdap/test_p3_wp5_boundaries.py", "tests/ptcgdap/test_p3_wp5_parent_snapshot.py",
    "tests/ptcgdap/godot/test_shadow_prompt_broker.gd",
}
P3_WP5_PARENT_BYTES = {
    "tests/ptcgdap/test_p1_wp3_boundaries.py": base64.b64decode(
        (ROOT / "artifacts/ptcgdap/p3_wp5/parent_snapshot/tests__ptcgdap__test_p1_wp3_boundaries.py.base64")
        .read_text(encoding="ascii")
        .strip(),
        validate=True,
    ),
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
    name = safe_path(entry["snapshot_path"])
    if "/" in name:
        raise AssertionError(name)
    encoded_file = (SNAPSHOT_ROOT / name).read_bytes()
    if not encoded_file.endswith(b"\n") or encoded_file.count(b"\n") != 1 or b"\r" in encoded_file:
        raise AssertionError(name)
    encoded = encoded_file[:-1]
    value = base64.b64decode(encoded.decode("ascii"), validate=True)
    if base64.b64encode(value) != encoded:
        raise AssertionError(name)
    if len(encoded_file) != entry["snapshot_file_bytes"] or sha(encoded_file) != entry["snapshot_file_raw_sha256"]:
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
    records = []
    parts = output.split(b"\0")
    index = 0
    while index < len(parts):
        record = parts[index]
        index += 1
        if not record:
            continue
        code = record[:2].decode("ascii")
        path = safe_path(record[3:].decode("utf-8").replace("\\", "/"))
        if path.startswith("artifacts/ptcgdap/p5_wp1/") or path in P5_WP1_PATHS or path.startswith("artifacts/ptcgdap/p5_wp2/") or path in P5_WP2_PATHS or is_p5_wp3_path(path):
            continue
        if "R" in code or "C" in code:
            raise AssertionError("rename/copy outside algorithm")
        records.append((code, path))
    return records


class P3Wp4ParentSnapshotTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        raw = MANIFEST_PATH.read_bytes()
        if sha(raw) != EXPECTED_MANIFEST_RAW:
            raise AssertionError("P3-WP4 snapshot raw drift")
        cls.manifest = load_json_strict(MANIFEST_PATH)
        if sha(canonical_json_v1_bytes(cls.manifest)) != EXPECTED_MANIFEST_CANONICAL:
            raise AssertionError("P3-WP4 snapshot canonical drift")
        cls.entries = {safe_path(entry["original_path"]): entry for entry in cls.manifest["files"]}

    def test_payloads_are_exact_safe_and_complete(self) -> None:
        self.assertEqual(self.manifest["work_package"], "P3-WP4")
        self.assertEqual(self.manifest["file_count"], 20)
        self.assertEqual(len(self.entries), 20)
        parent = self.manifest["parent"]
        self.assertEqual(parent["manifest_raw_sha256"], EXPECTED_PARENT_MANIFEST_RAW)
        self.assertEqual(parent["manifest_canonical_sha256"], EXPECTED_PARENT_MANIFEST_CANONICAL)
        self.assertEqual(parent["worktree_snapshot_canonical_sha256"], EXPECTED_PARENT_DIGEST)
        self.assertEqual(parent["worktree_status_counts"], EXPECTED_COUNTS)
        self.assertEqual(set(self.manifest["rollback_scope"]["restore_exact_paths"]), set(self.entries))
        self.assertEqual(set(self.manifest["rollback_scope"]["delete_exact_paths"]), P3_WP4_PATHS)
        names = [entry["snapshot_path"] for entry in self.entries.values()]
        self.assertEqual(len(names), len(set(names)))
        self.assertEqual({path.name for path in SNAPSHOT_ROOT.iterdir() if path.is_file()}, {"manifest.json", *names})
        for entry in self.entries.values():
            decode(entry)

    def test_isolated_restore_contains_only_parent_files(self) -> None:
        with tempfile.TemporaryDirectory(prefix="ptcgdap-p3-wp4-parent-") as temp:
            root = Path(temp)
            for path, entry in self.entries.items():
                destination = root / path
                destination.parent.mkdir(parents=True, exist_ok=True)
                destination.write_bytes(decode(entry))
            self.assertEqual({path.relative_to(root).as_posix() for path in root.rglob("*") if path.is_file()}, set(self.entries))

    def test_virtual_rollback_reproduces_p3_wp3_candidate(self) -> None:
        parent_bytes = {path: decode(entry) for path, entry in self.entries.items()}
        records = []
        restored = set()
        for code, path in status():
            if path.startswith("artifacts/ptcgdap/p3_wp6/") or path in P3_WP6_PATHS or path.startswith("artifacts/ptcgdap/p3_wp7/") or path in P3_WP7_PATHS or path.startswith("artifacts/ptcgdap/p3_wp8/") or path in P3_WP8_PATHS or path.startswith("artifacts/ptcgdap/p4_wp1/") or path in P4_WP1_PATHS or path.startswith("artifacts/ptcgdap/p4_wp2/") or path in P4_WP2_PATHS or path.startswith("artifacts/ptcgdap/p4_wp3/") or path in P4_WP3_PATHS or path.startswith("artifacts/ptcgdap/p4_wp4/") or path in P4_WP4_PATHS or path.startswith("artifacts/ptcgdap/p4_wp5/") or path in P4_WP5_PATHS or path.startswith("artifacts/ptcgdap/p4_wp6/") or path in P4_WP6_PATHS:
                continue
            if path.startswith("artifacts/ptcgdap/p3_wp3/") or path.startswith("artifacts/ptcgdap/p3_wp4/") or path in P3_WP4_PATHS or path.startswith(P3_WP5_PREFIX) or path in P3_WP5_PATHS:
                continue
            if path in P3_WP5_PARENT_BYTES:
                data = P3_WP5_PARENT_BYTES[path]
            elif path in P4_WP1_PARENT_BYTES:
                data = P4_WP1_PARENT_BYTES[path]
            elif path in parent_bytes:
                data = parent_bytes[path]
                restored.add(path)
            elif path in P5_WP2_PARENT_BYTES:
                data = P5_WP2_PARENT_BYTES[path]
            elif "D" in code:
                data = None
            else:
                data = p5_wp4_parent_bytes(path, (ROOT / path).read_bytes())
            records.append({
                "path": path,
                "status": code,
                "bytes": None if data is None else len(data),
                "sha256": None if data is None else sha(data),
            })
        self.assertEqual(restored, set(parent_bytes))
        records.sort(key=lambda item: item["path"])
        counts = Counter("untracked" if item["status"] == "??" else "deleted" if "D" in item["status"] else "modified" for item in records)
        self.assertEqual(len(records), 450)
        self.assertEqual(dict(counts), EXPECTED_COUNTS)
        self.assertEqual(sha(canonical_json_v1_bytes(records)), EXPECTED_PARENT_DIGEST)


if __name__ == "__main__":
    unittest.main()
