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
from tests.ptcgdap.test_p3_wp7_parent_snapshot import P3_WP7_PATHS, P3_WP8_PATHS, P4_WP1_PATHS, P4_WP2_PATHS, P4_WP3_PATHS, P4_WP4_PATHS


ROOT = Path(__file__).resolve().parents[2]
P5_WP1_PATHS = frozenset(
    load_json_strict(ROOT / "artifacts/ptcgdap/p5_wp1/parent_snapshot/manifest.json")["rollback_scope"]["delete_exact_paths"]
)
P5_WP2_PATHS = frozenset(
    load_json_strict(ROOT / "artifacts/ptcgdap/p5_wp2/parent_snapshot/manifest.json")["rollback_scope"]["delete_exact_paths"]
)
FUTURE_P3_WP1_PREFIX = "artifacts/ptcgdap/p3_wp1/"
FUTURE_P3_WP1_PATHS = {
    "contracts/ptcgdap/engine_decision_port.schema.json", "contracts/ptcgdap/engine_decision_port_profile.json",
    "contracts/ptcgdap/engine_decision_port_conformance_vectors.json", "contracts/ptcgdap/engine_decision_port_bundle.json",
    "scripts/ai/ptcgdap/engine_decision_port.py", "scripts/engine/decision/EngineDecisionPort.gd",
    "tools/ptcgdap/build_engine_decision_port_contract.py", "tests/ptcgdap/test_engine_decision_port_contract_builder.py",
    "tests/ptcgdap/test_engine_decision_port.py", "tests/ptcgdap/test_engine_decision_port_properties.py",
    "tests/ptcgdap/test_p3_wp1_boundaries.py", "tests/ptcgdap/test_p3_wp1_parent_snapshot.py",
    "tests/ptcgdap/godot/test_engine_decision_port.gd",
}

FUTURE_P3_WP2_PREFIX = "artifacts/ptcgdap/p3_wp2/"
FUTURE_P3_WP2_PATHS = {
    "contracts/ptcgdap/godot_option_binding.schema.json",
    "contracts/ptcgdap/godot_option_binding_profile.json",
    "contracts/ptcgdap/godot_option_binding_conformance_vectors.json",
    "contracts/ptcgdap/godot_option_binding_bundle.json",
    "scripts/ai/ptcgdap/godot_option_binding.py",
    "scripts/engine/decision/GodotOptionBinding.gd",
    "tools/ptcgdap/build_godot_option_binding_contract.py",
    "tests/ptcgdap/test_godot_option_binding_contract_builder.py",
    "tests/ptcgdap/test_godot_option_binding.py",
    "tests/ptcgdap/test_godot_option_binding_properties.py",
    "tests/ptcgdap/test_p3_wp2_boundaries.py",
    "tests/ptcgdap/test_p3_wp2_parent_snapshot.py",
    "tests/ptcgdap/godot/test_godot_option_binding.gd",
}
FUTURE_P3_WP3_PREFIX = "artifacts/ptcgdap/p3_wp3/"
FUTURE_P3_WP3_PATHS = {
    "contracts/ptcgdap/godot_action_ticket.schema.json", "contracts/ptcgdap/godot_action_ticket_profile.json",
    "contracts/ptcgdap/godot_action_ticket_conformance_vectors.json", "contracts/ptcgdap/godot_action_ticket_bundle.json",
    "scripts/ai/ptcgdap/godot_action_ticket.py", "scripts/engine/decision/GodotActionTicket.gd",
    "tools/ptcgdap/build_godot_action_ticket_contract.py", "tests/ptcgdap/test_godot_action_ticket_contract_builder.py",
    "tests/ptcgdap/test_godot_action_ticket.py", "tests/ptcgdap/test_godot_action_ticket_properties.py",
    "tests/ptcgdap/test_p3_wp3_boundaries.py", "tests/ptcgdap/test_p3_wp3_parent_snapshot.py",
    "tests/ptcgdap/godot/test_godot_action_ticket.gd",
}
FUTURE_P3_WP3_PARENT_BYTES = {
    "tests/ptcgdap/test_p1_wp3_boundaries.py": base64.b64decode(
        (ROOT / "artifacts/ptcgdap/p3_wp3/parent_snapshot/test_p1_wp3_boundaries.py.base64")
        .read_text(encoding="ascii")
        .strip(),
        validate=True,
    )
}
FUTURE_P3_WP4_PREFIX = "artifacts/ptcgdap/p3_wp4/"
FUTURE_P3_WP4_PATHS = {
    "contracts/ptcgdap/godot_action_executor.schema.json", "contracts/ptcgdap/godot_action_executor_profile.json",
    "contracts/ptcgdap/godot_action_executor_conformance_vectors.json", "contracts/ptcgdap/godot_action_executor_bundle.json",
    "scripts/ai/ptcgdap/godot_action_executor.py", "scripts/engine/decision/GodotActionExecutor.gd",
    "tools/ptcgdap/build_godot_action_executor_contract.py", "tests/ptcgdap/test_godot_action_executor_contract_builder.py",
    "tests/ptcgdap/test_godot_action_executor.py", "tests/ptcgdap/test_godot_action_executor_properties.py",
    "tests/ptcgdap/test_p3_wp4_boundaries.py", "tests/ptcgdap/test_p3_wp4_parent_snapshot.py",
    "tests/ptcgdap/godot/test_godot_action_executor.gd",
}
FUTURE_P3_WP5_PREFIX = "artifacts/ptcgdap/p3_wp5/"
FUTURE_P3_WP5_PATHS = {
    "contracts/ptcgdap/shadow_prompt_broker.schema.json", "contracts/ptcgdap/shadow_prompt_broker_profile.json",
    "contracts/ptcgdap/shadow_prompt_broker_conformance_vectors.json", "contracts/ptcgdap/shadow_prompt_broker_bundle.json",
    "scripts/ai/ptcgdap/shadow_prompt_broker.py", "scripts/engine/decision/ShadowPromptBroker.gd",
    "tools/ptcgdap/build_shadow_prompt_broker_contract.py", "tests/ptcgdap/test_shadow_prompt_broker_contract_builder.py",
    "tests/ptcgdap/test_shadow_prompt_broker.py", "tests/ptcgdap/test_shadow_prompt_broker_properties.py",
    "tests/ptcgdap/test_p3_wp5_boundaries.py", "tests/ptcgdap/test_p3_wp5_parent_snapshot.py",
    "tests/ptcgdap/godot/test_shadow_prompt_broker.gd",
}

SNAPSHOT_ROOT = ROOT / "artifacts" / "ptcgdap" / "p2_wp4" / "parent_snapshot"
MANIFEST_PATH = SNAPSHOT_ROOT / "manifest.json"
FUTURE_P2_WP5_SNAPSHOT_ROOT = (
    ROOT / "artifacts" / "ptcgdap" / "p2_wp5" / "parent_snapshot"
)
FUTURE_P2_WP5_RESTORE_PATHS = {
    "tests/ptcgdap/test_p2_wp1_boundaries.py",
    "tests/ptcgdap/test_p2_wp2_boundaries.py",
}
EXPECTED_MANIFEST_RAW = "7DA24EA8BC1566CA22BDD2DFFC48FA1730675DE21B21C16BE2477518BF45025D"
EXPECTED_MANIFEST_CANONICAL = "6945BDE6C04ACD0E8CC595808DE9DF717EE990EB6AC82140E5747978D36D1D3D"
EXPECTED_PARENT_MANIFEST_RAW = "0ECCD6341E0A06980EFF1269B9FCBD5422793DBC68703E67E12B5FE1B4717DB7"
EXPECTED_PARENT_MANIFEST_CANONICAL = "D1387EBF915C7865A5B2F7B5D7E1D1078C3FCDE0D6A18A0A1DCEA8FAC5EC126C"
EXPECTED_PARENT_DIGEST = "75AA6C649610E9CB55BA8458F69745718E31465BB86A89CAC34D515EECC0E7A4"
EXPECTED_COUNTS = {"untracked": 225, "deleted": 28, "modified": 1}
EXPECTED_PARENT_PATHS = {
    "docs/ptcgdap/README.md",
    "docs/ptcgdap/STATUS.md",
    "docs/ptcgdap/IMPLEMENTATION_CHECKLIST.md",
    "docs/ptcgdap/01-official-cabt-contract.md",
    "docs/ptcgdap/03-target-architecture.md",
    "docs/ptcgdap/04-migration-roadmap.md",
    "docs/ptcgdap/05-validation-promotion-and-rollback.md",
    "docs/ptcgdap/06-first-vertical-slice.md",
    "docs/ptcgdap/07-decisions-risks-and-open-questions.md",
    "tests/ptcgdap/test_p2_wp1_parent_snapshot.py",
    "tests/ptcgdap/test_p2_wp2_parent_snapshot.py",
    "tests/ptcgdap/test_p2_wp3_parent_snapshot.py",
    "tests/ptcgdap/test_p2_wp3_boundaries.py",
}
DELETE_PATHS = {
    "contracts/ptcgdap/cabt_public_log_cursor.schema.json",
    "contracts/ptcgdap/cabt_public_log_cursor_profile.json",
    "contracts/ptcgdap/cabt_public_log_cursor_conformance_vectors.json",
    "contracts/ptcgdap/cabt_public_log_cursor_bundle.json",
    "scripts/ai/ptcgdap/public_log_cursor.py",
    "scripts/ai/ptcgdap/public/GodotLogCursor.gd",
    "tools/ptcgdap/build_public_log_cursor_contract.py",
    "tests/ptcgdap/test_public_log_cursor_contract_builder.py",
    "tests/ptcgdap/test_public_log_cursor.py",
    "tests/ptcgdap/test_public_log_cursor_properties.py",
    "tests/ptcgdap/test_p2_wp4_boundaries.py",
    "tests/ptcgdap/test_p2_wp4_parent_snapshot.py",
    "tests/ptcgdap/godot/test_public_log_cursor.gd",
}
EVIDENCE_PREFIXES = (
    "artifacts/ptcgdap/p2_wp3/",
    "artifacts/ptcgdap/p2_wp4/",
    "artifacts/ptcgdap/p2_wp5/",
)
FUTURE_P2_WP5_PATHS = {
    "contracts/ptcgdap/godot_observation_projector.schema.json",
    "contracts/ptcgdap/godot_observation_projector_profile.json",
    "contracts/ptcgdap/godot_observation_projector_conformance_vectors.json",
    "contracts/ptcgdap/godot_observation_projector_bundle.json",
    "scripts/ai/ptcgdap/observation_projector.py",
    "scripts/ai/ptcgdap/host/godot/GodotObservationProjector.gd",
    "tools/ptcgdap/build_observation_projector_contract.py",
    "tests/ptcgdap/test_observation_projector_contract_builder.py",
    "tests/ptcgdap/test_observation_projector.py",
    "tests/ptcgdap/test_observation_projector_properties.py",
    "tests/ptcgdap/test_p2_wp5_boundaries.py",
    "tests/ptcgdap/test_p2_wp5_parent_snapshot.py",
    "tests/ptcgdap/godot/test_observation_projector.gd",
}


def _sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest().upper()


def _safe_path(raw: object) -> str:
    if not isinstance(raw, str) or not raw or "\\" in raw or "\0" in raw:
        raise AssertionError(f"invalid repository path: {raw!r}")
    path = PurePosixPath(raw)
    if path.is_absolute() or "." in path.parts or ".." in path.parts or ":" in path.parts[0]:
        raise AssertionError(f"unsafe repository path: {raw!r}")
    if path.as_posix() != raw:
        raise AssertionError(f"non-canonical repository path: {raw!r}")
    return raw


def _decode(
    entry: dict[str, object], snapshot_root: Path = SNAPSHOT_ROOT
) -> bytes:
    name = _safe_path(entry["snapshot_path"])
    if "/" in name:
        raise AssertionError("snapshot payload is not a direct child")
    encoded_file = (snapshot_root / name).read_bytes()
    if not encoded_file.endswith(b"\n") or encoded_file.count(b"\n") != 1 or b"\r" in encoded_file:
        raise AssertionError(f"non-canonical base64 file: {name}")
    encoded = encoded_file[:-1]
    decoded = base64.b64decode(encoded.decode("ascii"), validate=True)
    if base64.b64encode(decoded) != encoded:
        raise AssertionError(f"non-canonical RFC4648 payload: {name}")
    if len(encoded_file) != entry["snapshot_file_bytes"] or _sha(encoded_file) != entry["snapshot_file_raw_sha256"]:
        raise AssertionError(f"snapshot payload drift: {name}")
    if len(decoded) != entry["bytes"] or _sha(decoded) != entry["raw_sha256"]:
        raise AssertionError(f"decoded parent drift: {name}")
    return decoded


def _status() -> list[tuple[str, str]]:
    output = subprocess.run(
        ["git", "status", "--porcelain=v1", "-z", "--untracked-files=all"],
        cwd=ROOT,
        check=True,
        capture_output=True,
    ).stdout
    records: list[tuple[str, str]] = []
    parts = output.split(b"\0")
    index = 0
    while index < len(parts):
        record = parts[index]
        index += 1
        if not record:
            continue
        status = record[:2].decode("ascii")
        path = _safe_path(record[3:].decode("utf-8").replace("\\", "/"))
        if path.startswith("artifacts/ptcgdap/p5_wp1/") or path in P5_WP1_PATHS or path.startswith("artifacts/ptcgdap/p5_wp2/") or path in P5_WP2_PATHS or is_p5_wp3_path(path):
            continue
        if "R" in status or "C" in status:
            index += 1
            raise AssertionError("rename/copy is outside the pinned snapshot algorithm")
        records.append((status, path))
    return records


class P2Wp4ParentSnapshotTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        raw = MANIFEST_PATH.read_bytes()
        if _sha(raw) != EXPECTED_MANIFEST_RAW:
            raise AssertionError("P2-WP4 parent snapshot raw hash drift")
        cls.manifest = load_json_strict(MANIFEST_PATH)
        if _sha(canonical_json_v1_bytes(cls.manifest)) != EXPECTED_MANIFEST_CANONICAL:
            raise AssertionError("P2-WP4 parent snapshot canonical hash drift")
        cls.entries = {_safe_path(entry["original_path"]): entry for entry in cls.manifest["files"]}

    def test_manifest_payloads_are_exact_safe_and_complete(self) -> None:
        self.assertEqual(self.manifest["work_package"], "P2-WP4")
        self.assertEqual(self.manifest["snapshot_kind"], "exact_parent_bytes_before_p2_wp4")
        self.assertEqual(self.manifest["file_count"], 13)
        self.assertEqual(set(self.entries), EXPECTED_PARENT_PATHS)
        parent = self.manifest["parent"]
        self.assertEqual(parent["manifest_raw_sha256"], EXPECTED_PARENT_MANIFEST_RAW)
        self.assertEqual(parent["manifest_canonical_sha256"], EXPECTED_PARENT_MANIFEST_CANONICAL)
        self.assertEqual(parent["worktree_snapshot_entry_count"], 254)
        self.assertEqual(parent["worktree_snapshot_status_counts"], EXPECTED_COUNTS)
        self.assertEqual(parent["worktree_snapshot_canonical_sha256"], EXPECTED_PARENT_DIGEST)
        names = [entry["snapshot_path"] for entry in self.entries.values()]
        self.assertEqual(len(names), len(set(names)))
        for entry in self.entries.values():
            self.assertEqual(entry["original_git_status"], "??")
            _decode(entry)
        scope = self.manifest["rollback_scope"]
        self.assertEqual(set(scope["restore_exact_paths"]), EXPECTED_PARENT_PATHS)
        self.assertEqual(set(scope["delete_exact_paths"]), DELETE_PATHS)
        self.assertEqual(scope["delete_prefixes"], ["artifacts/ptcgdap/p2_wp4/"])
        self.assertTrue(EXPECTED_PARENT_PATHS.isdisjoint(DELETE_PATHS))

    def test_isolated_restore_contains_only_thirteen_parent_files(self) -> None:
        with tempfile.TemporaryDirectory(prefix="ptcgdap-p2-wp4-parent-") as temp:
            root = Path(temp)
            for path, entry in self.entries.items():
                destination = root / path
                destination.parent.mkdir(parents=True, exist_ok=True)
                destination.write_bytes(_decode(entry))
            actual = {path.relative_to(root).as_posix() for path in root.rglob("*") if path.is_file()}
            self.assertEqual(actual, EXPECTED_PARENT_PATHS)

    def test_virtual_rollback_reproduces_exact_p2_wp3_candidate(self) -> None:
        parent_bytes = {path: _decode(entry) for path, entry in self.entries.items()}
        wp5_manifest = load_json_strict(FUTURE_P2_WP5_SNAPSHOT_ROOT / "manifest.json")
        wp5_entries = {
            entry["original_path"]: entry
            for entry in wp5_manifest["files"]
            if entry["original_path"] in FUTURE_P2_WP5_RESTORE_PATHS
        }
        self.assertEqual(set(wp5_entries), FUTURE_P2_WP5_RESTORE_PATHS)
        future_parent_bytes = {
            path: _decode(entry, FUTURE_P2_WP5_SNAPSHOT_ROOT)
            for path, entry in wp5_entries.items()
        }
        records: list[dict[str, object]] = []
        restored: set[str] = set()
        for status, path in _status():
            if path.startswith("artifacts/ptcgdap/p3_wp6/") or path in P3_WP6_PATHS or path.startswith("artifacts/ptcgdap/p3_wp7/") or path in P3_WP7_PATHS or path.startswith("artifacts/ptcgdap/p3_wp8/") or path in P3_WP8_PATHS or path.startswith("artifacts/ptcgdap/p4_wp1/") or path in P4_WP1_PATHS or path.startswith("artifacts/ptcgdap/p4_wp2/") or path in P4_WP2_PATHS or path.startswith("artifacts/ptcgdap/p4_wp3/") or path in P4_WP3_PATHS or path.startswith("artifacts/ptcgdap/p4_wp4/") or path in P4_WP4_PATHS or path.startswith("artifacts/ptcgdap/p4_wp5/") or path in P4_WP5_PATHS or path.startswith("artifacts/ptcgdap/p4_wp6/") or path in P4_WP6_PATHS:
                continue
            if (
                any(path.startswith(prefix) for prefix in EVIDENCE_PREFIXES)
                or path in DELETE_PATHS
                or path in FUTURE_P2_WP5_PATHS
                or path.startswith(FUTURE_P3_WP1_PREFIX)
                or path in FUTURE_P3_WP1_PATHS
                or path.startswith(FUTURE_P3_WP2_PREFIX)
                or path in FUTURE_P3_WP2_PATHS
                or path.startswith(FUTURE_P3_WP3_PREFIX)
                or path in FUTURE_P3_WP3_PATHS
                or path.startswith(FUTURE_P3_WP4_PREFIX)
                or path in FUTURE_P3_WP4_PATHS
                or path.startswith(FUTURE_P3_WP5_PREFIX)
                or path in FUTURE_P3_WP5_PATHS
            ):
                continue
            if path in FUTURE_P3_WP3_PARENT_BYTES:
                self.assertEqual(status, "??")
                data: bytes | None = FUTURE_P3_WP3_PARENT_BYTES[path]
            elif path in parent_bytes:
                self.assertEqual(status, "??")
                data = parent_bytes[path]
                restored.add(path)
            elif path in future_parent_bytes:
                self.assertEqual(status, "??")
                data = future_parent_bytes[path]
            elif path in P5_WP2_PARENT_BYTES:
                data = P5_WP2_PARENT_BYTES[path]
            elif "D" in status:
                data = None
            else:
                data = p5_wp4_parent_bytes(path, (ROOT / path).read_bytes())
            records.append({
                "path": path,
                "status": status,
                "bytes": None if data is None else len(data),
                "sha256": None if data is None else _sha(data),
            })
        self.assertEqual(restored, EXPECTED_PARENT_PATHS)
        records.sort(key=lambda item: str(item["path"]))
        counts = Counter(
            "untracked" if item["status"] == "??" else "deleted" if "D" in str(item["status"]) else "modified"
            for item in records
        )
        self.assertEqual(len(records), 254)
        self.assertEqual(dict(counts), EXPECTED_COUNTS)
        self.assertEqual(_sha(canonical_json_v1_bytes(records)), EXPECTED_PARENT_DIGEST)


if __name__ == "__main__":
    unittest.main()
