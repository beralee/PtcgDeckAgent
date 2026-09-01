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

SNAPSHOT_ROOT = ROOT / "artifacts" / "ptcgdap" / "p2_wp3" / "parent_snapshot"
MANIFEST_PATH = SNAPSHOT_ROOT / "manifest.json"
FUTURE_P2_WP5_SNAPSHOT_ROOT = (
    ROOT / "artifacts" / "ptcgdap" / "p2_wp5" / "parent_snapshot"
)
FUTURE_P2_WP5_RESTORE_PATHS = {
    "tests/ptcgdap/test_p2_wp1_boundaries.py",
    "tests/ptcgdap/test_p2_wp2_boundaries.py",
}
EXPECTED_MANIFEST_RAW_SHA256 = (
    "9125FA300FE9CE47FE8285A8903AA34D76E8D54049BF2B24F38F8404F1E090A1"
)
EXPECTED_MANIFEST_CANONICAL_SHA256 = (
    "6812D53DA622FDF10278F8C33AFECE0EA1CE560614F837F19E94280229254716"
)
EXPECTED_PARENT_MANIFEST_RAW_SHA256 = (
    "9FC8CDDD8B13A3EAC5FAC84DA592D27EF167D0536A7FD83EF66EA538490504D8"
)
EXPECTED_PARENT_MANIFEST_CANONICAL_SHA256 = (
    "3DD2C5CF29F2DB53A87BCB1B4F3601369B97444B84A4533272CA0DB2673B96EA"
)
EXPECTED_PARENT_WORKTREE_SHA256 = (
    "AE736B2660D2F78A9BE6821BFC47FA775DEBF047C60DA1FAE3ED356910E21F46"
)
EXPECTED_PARENT_COUNTS = {"untracked": 187, "deleted": 28, "modified": 1}
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
}
EXPECTED_DELETE_PREFIXES = {"artifacts/ptcgdap/p2_wp3/"}
PARENT_EVIDENCE_PREFIX = "artifacts/ptcgdap/p2_wp2/"
EXPECTED_DELETE_PATHS = {
    "contracts/ptcgdap/cabt_public_observation.schema.json",
    "contracts/ptcgdap/cabt_public_firewall_profile.json",
    "contracts/ptcgdap/cabt_public_firewall_conformance_vectors.json",
    "contracts/ptcgdap/cabt_public_firewall_bundle.json",
    "scripts/ai/ptcgdap/public_observation_firewall.py",
    "scripts/ai/ptcgdap/public/PublicObservationFirewall.gd",
    "tools/ptcgdap/build_public_firewall_contract.py",
    "tests/ptcgdap/test_public_firewall_contract_builder.py",
    "tests/ptcgdap/test_public_observation_firewall.py",
    "tests/ptcgdap/test_public_observation_firewall_properties.py",
    "tests/ptcgdap/test_p2_wp3_boundaries.py",
    "tests/ptcgdap/test_p2_wp3_parent_snapshot.py",
    "tests/ptcgdap/godot/test_public_observation_firewall.gd",
}
FUTURE_P2_WP4_DELETE_PREFIXES = {"artifacts/ptcgdap/p2_wp4/"}
FUTURE_P2_WP4_DELETE_PATHS = {
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
FUTURE_P2_WP5_DELETE_PREFIXES = {"artifacts/ptcgdap/p2_wp5/"}
FUTURE_P2_WP5_DELETE_PATHS = {
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


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest().upper()


def _safe_repo_path(raw: object) -> str:
    if not isinstance(raw, str) or not raw or "\\" in raw or "\x00" in raw:
        raise AssertionError(f"invalid repository-relative path: {raw!r}")
    path = PurePosixPath(raw)
    if path.is_absolute() or ".." in path.parts or "." in path.parts:
        raise AssertionError(f"unsafe repository-relative path: {raw!r}")
    if ":" in path.parts[0] or path.as_posix() != raw:
        raise AssertionError(f"non-canonical repository-relative path: {raw!r}")
    return raw


def _safe_repo_prefix(raw: object) -> str:
    if not isinstance(raw, str) or not raw.endswith("/"):
        raise AssertionError(f"repository prefix must end with slash: {raw!r}")
    _safe_repo_path(raw[:-1])
    return raw


def _decode_snapshot(
    entry: dict[str, object], snapshot_root: Path = SNAPSHOT_ROOT
) -> bytes:
    snapshot_name = _safe_repo_path(entry["snapshot_path"])
    if "/" in snapshot_name:
        raise AssertionError(f"snapshot payload must be a direct child: {snapshot_name}")
    encoded_file = (snapshot_root / snapshot_name).read_bytes()
    if (
        not encoded_file.endswith(b"\n")
        or encoded_file.count(b"\n") != 1
        or b"\r" in encoded_file
    ):
        raise AssertionError(f"payload must be one base64 line plus LF: {snapshot_name}")
    encoded = encoded_file[:-1]
    try:
        decoded = base64.b64decode(encoded.decode("ascii"), validate=True)
    except (UnicodeDecodeError, ValueError) as error:
        raise AssertionError(f"invalid canonical base64: {snapshot_name}") from error
    if base64.b64encode(decoded) != encoded:
        raise AssertionError(f"non-canonical RFC4648 base64: {snapshot_name}")
    if len(encoded_file) != entry["snapshot_file_bytes"]:
        raise AssertionError(f"snapshot byte count drift: {snapshot_name}")
    if _sha256(encoded_file) != entry["snapshot_file_raw_sha256"]:
        raise AssertionError(f"snapshot hash drift: {snapshot_name}")
    if len(decoded) != entry["bytes"]:
        raise AssertionError(f"decoded byte count drift: {snapshot_name}")
    if _sha256(decoded) != entry["raw_sha256"]:
        raise AssertionError(f"decoded parent hash drift: {snapshot_name}")
    return decoded


def _git_status() -> list[tuple[str, str]]:
    completed = subprocess.run(
        ["git", "status", "--porcelain=v1", "-z", "--untracked-files=all"],
        cwd=ROOT,
        check=True,
        capture_output=True,
    )
    records: list[tuple[str, str]] = []
    parts = completed.stdout.split(b"\x00")
    index = 0
    while index < len(parts):
        record = parts[index]
        index += 1
        if not record:
            continue
        if len(record) < 4 or record[2:3] != b" ":
            raise AssertionError(f"malformed porcelain-v1 record: {record!r}")
        status = record[:2].decode("ascii")
        path = record[3:].decode("utf-8").replace("\\", "/")
        _safe_repo_path(path)
        if path.startswith("artifacts/ptcgdap/p5_wp1/") or path in P5_WP1_PATHS or path.startswith("artifacts/ptcgdap/p5_wp2/") or path in P5_WP2_PATHS or is_p5_wp3_path(path):
            continue
        if "R" in status or "C" in status:
            if index < len(parts):
                index += 1
            raise AssertionError("rename/copy status is outside the pinned algorithm")
        records.append((status, path))
    if len({path for _, path in records}) != len(records):
        raise AssertionError("duplicate path in git status")
    return records


class P2Wp3ParentSnapshotTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        raw = MANIFEST_PATH.read_bytes()
        if _sha256(raw) != EXPECTED_MANIFEST_RAW_SHA256:
            raise AssertionError("P2-WP3 parent snapshot manifest raw hash drift")
        cls.manifest = load_json_strict(MANIFEST_PATH)
        canonical = canonical_json_v1_bytes(cls.manifest)
        if _sha256(canonical) != EXPECTED_MANIFEST_CANONICAL_SHA256:
            raise AssertionError("P2-WP3 parent snapshot manifest canonical hash drift")
        cls.entries = {
            _safe_repo_path(entry["original_path"]): entry
            for entry in cls.manifest["files"]
        }

    def test_manifest_payloads_are_exact_safe_and_non_overlapping(self) -> None:
        self.assertEqual(self.manifest["schema_version"], 1)
        self.assertEqual(self.manifest["work_package"], "P2-WP3")
        self.assertEqual(
            self.manifest["snapshot_kind"], "exact_parent_bytes_before_p2_wp3"
        )
        self.assertEqual(self.manifest["file_count"], 11)
        self.assertEqual(set(self.entries), EXPECTED_PARENT_PATHS)

        parent = self.manifest["parent"]
        self.assertEqual(parent["work_package"], "P2-WP2")
        self.assertEqual(
            parent["manifest_raw_sha256"], EXPECTED_PARENT_MANIFEST_RAW_SHA256
        )
        self.assertEqual(
            parent["manifest_canonical_sha256"],
            EXPECTED_PARENT_MANIFEST_CANONICAL_SHA256,
        )
        self.assertEqual(parent["worktree_snapshot_entry_count"], 216)
        self.assertEqual(parent["worktree_snapshot_status_counts"], EXPECTED_PARENT_COUNTS)
        self.assertEqual(
            parent["worktree_snapshot_canonical_sha256"],
            EXPECTED_PARENT_WORKTREE_SHA256,
        )

        snapshot_names = [entry["snapshot_path"] for entry in self.entries.values()]
        self.assertEqual(len(snapshot_names), len(set(snapshot_names)))
        for entry in self.entries.values():
            self.assertEqual(entry["original_git_status"], "??")
            _decode_snapshot(entry)

        rollback = self.manifest["rollback_scope"]
        restore_paths = {_safe_repo_path(path) for path in rollback["restore_exact_paths"]}
        delete_prefixes = {
            _safe_repo_prefix(path) for path in rollback["delete_prefixes"]
        }
        delete_paths = {_safe_repo_path(path) for path in rollback["delete_exact_paths"]}
        self.assertEqual(restore_paths, EXPECTED_PARENT_PATHS)
        self.assertEqual(delete_prefixes, EXPECTED_DELETE_PREFIXES)
        self.assertEqual(delete_paths, EXPECTED_DELETE_PATHS)
        self.assertTrue(restore_paths.isdisjoint(delete_paths))

    def test_isolated_restore_recreates_only_the_eleven_parent_paths(self) -> None:
        with tempfile.TemporaryDirectory(prefix="ptcgdap-p2-wp3-rollback-") as temp:
            restore_root = Path(temp)
            for original_path, entry in self.entries.items():
                destination = restore_root / original_path
                destination.parent.mkdir(parents=True, exist_ok=True)
                destination.write_bytes(_decode_snapshot(entry))
            restored = sorted(
                path.relative_to(restore_root).as_posix()
                for path in restore_root.rglob("*")
                if path.is_file()
            )
            self.assertEqual(restored, sorted(EXPECTED_PARENT_PATHS))

    def test_virtual_rollback_reproduces_exact_p2_wp2_candidate(self) -> None:
        parent_bytes = {
            original_path: _decode_snapshot(entry)
            for original_path, entry in self.entries.items()
        }
        wp5_manifest = load_json_strict(FUTURE_P2_WP5_SNAPSHOT_ROOT / "manifest.json")
        wp5_entries = {
            entry["original_path"]: entry
            for entry in wp5_manifest["files"]
            if entry["original_path"] in FUTURE_P2_WP5_RESTORE_PATHS
        }
        self.assertEqual(set(wp5_entries), FUTURE_P2_WP5_RESTORE_PATHS)
        future_parent_bytes = {
            path: _decode_snapshot(entry, FUTURE_P2_WP5_SNAPSHOT_ROOT)
            for path, entry in wp5_entries.items()
        }
        records: list[dict[str, object]] = []
        seen_parent_paths: set[str] = set()
        for status, path in _git_status():
            if path.startswith("artifacts/ptcgdap/p3_wp6/") or path in P3_WP6_PATHS or path.startswith("artifacts/ptcgdap/p3_wp7/") or path in P3_WP7_PATHS or path.startswith("artifacts/ptcgdap/p3_wp8/") or path in P3_WP8_PATHS or path.startswith("artifacts/ptcgdap/p4_wp1/") or path in P4_WP1_PATHS or path.startswith("artifacts/ptcgdap/p4_wp2/") or path in P4_WP2_PATHS or path.startswith("artifacts/ptcgdap/p4_wp3/") or path in P4_WP3_PATHS or path.startswith("artifacts/ptcgdap/p4_wp4/") or path in P4_WP4_PATHS or path.startswith("artifacts/ptcgdap/p4_wp5/") or path in P4_WP5_PATHS or path.startswith("artifacts/ptcgdap/p4_wp6/") or path in P4_WP6_PATHS:
                continue
            if (path.startswith(FUTURE_P3_WP1_PREFIX) or path in FUTURE_P3_WP1_PATHS or path.startswith(FUTURE_P3_WP2_PREFIX) or path in FUTURE_P3_WP2_PATHS or path.startswith(FUTURE_P3_WP3_PREFIX) or path in FUTURE_P3_WP3_PATHS or path.startswith(FUTURE_P3_WP4_PREFIX) or path in FUTURE_P3_WP4_PATHS or path.startswith(FUTURE_P3_WP5_PREFIX) or path in FUTURE_P3_WP5_PATHS):
                continue
            if path.startswith(PARENT_EVIDENCE_PREFIX):
                continue
            if any(path.startswith(prefix) for prefix in EXPECTED_DELETE_PREFIXES):
                continue
            if path in EXPECTED_DELETE_PATHS:
                continue
            if any(path.startswith(prefix) for prefix in FUTURE_P2_WP4_DELETE_PREFIXES):
                continue
            if path in FUTURE_P2_WP4_DELETE_PATHS:
                continue
            if any(path.startswith(prefix) for prefix in FUTURE_P2_WP5_DELETE_PREFIXES):
                continue
            if path in FUTURE_P2_WP5_DELETE_PATHS:
                continue

            if path in FUTURE_P3_WP3_PARENT_BYTES:
                self.assertEqual(status, "??", f"P3-WP3 parent status drift: {path}")
                data: bytes | None = FUTURE_P3_WP3_PARENT_BYTES[path]
            elif path in parent_bytes:
                self.assertEqual(status, "??", f"parent status drift: {path}")
                data = parent_bytes[path]
                seen_parent_paths.add(path)
            elif path in future_parent_bytes:
                self.assertEqual(status, "??", f"future parent status drift: {path}")
                data = future_parent_bytes[path]
            elif path in P5_WP2_PARENT_BYTES:
                data = P5_WP2_PARENT_BYTES[path]
            elif "D" in status:
                data = None
            else:
                candidate = ROOT / path
                self.assertTrue(candidate.is_file(), f"status path is not a file: {path}")
                data = p5_wp4_parent_bytes(path, candidate.read_bytes())
            records.append(
                {
                    "path": path,
                    "status": status,
                    "bytes": None if data is None else len(data),
                    "sha256": None if data is None else _sha256(data),
                }
            )

        self.assertEqual(seen_parent_paths, EXPECTED_PARENT_PATHS)
        records.sort(key=lambda record: str(record["path"]))
        counts = Counter(
            "untracked"
            if record["status"] == "??"
            else "deleted"
            if "D" in str(record["status"])
            else "modified"
            for record in records
        )
        self.assertEqual(len(records), 216)
        self.assertEqual(dict(counts), EXPECTED_PARENT_COUNTS)
        self.assertEqual(
            _sha256(canonical_json_v1_bytes(records)), EXPECTED_PARENT_WORKTREE_SHA256
        )


if __name__ == "__main__":
    unittest.main()
