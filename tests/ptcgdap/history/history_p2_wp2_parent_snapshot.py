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

SNAPSHOT_ROOT = ROOT / "artifacts" / "ptcgdap" / "p2_wp2" / "parent_snapshot"
MANIFEST_PATH = SNAPSHOT_ROOT / "manifest.json"
FUTURE_P2_WP3_SNAPSHOT_ROOT = (
    ROOT / "artifacts" / "ptcgdap" / "p2_wp3" / "parent_snapshot"
)
FUTURE_P2_WP5_SNAPSHOT_ROOT = (
    ROOT / "artifacts" / "ptcgdap" / "p2_wp5" / "parent_snapshot"
)
FUTURE_P2_WP5_RESTORE_PATHS = {
    "tests/ptcgdap/test_p2_wp1_boundaries.py",
}
EXPECTED_PARENT_DOCS = {
    "docs/ptcgdap/README.md": {
        "bytes": 7686,
        "raw_sha256": "50A412B841F0C7176BE5336876C54B7E31F5DC048AA6CB62CCABC0DDAD2F91C4",
        "snapshot_path": "README.md.base64",
        "snapshot_file_bytes": 10249,
        "snapshot_file_raw_sha256": "DD756141EE1A17FCF0342A55ED6EF7F3E7DC8FD243575887547E3ECB83D78A27",
    },
    "docs/ptcgdap/STATUS.md": {
        "bytes": 12675,
        "raw_sha256": "03A7DCC0A160C2DAAB6CAB13E0067C420EA6639D5C49898C91F4F931F8BE1C73",
        "snapshot_path": "STATUS.md.base64",
        "snapshot_file_bytes": 16901,
        "snapshot_file_raw_sha256": "23E5A6C3DB3435431601C2D63595F843CAC1B871EF3BE390ADED2F11FAF1480A",
    },
    "docs/ptcgdap/IMPLEMENTATION_CHECKLIST.md": {
        "bytes": 24642,
        "raw_sha256": "FC618C8FCDA1960082A09F99B1BC59F0B343A5B96B2150D588FC46E25BD7AB86",
        "snapshot_path": "IMPLEMENTATION_CHECKLIST.md.base64",
        "snapshot_file_bytes": 32857,
        "snapshot_file_raw_sha256": "37F16627D88CED4FFFA54A9F7EDA7718EC7B228B56D1203DB52AE86B08819587",
    },
    "docs/ptcgdap/02-current-state-and-gap-analysis.md": {
        "bytes": 12284,
        "raw_sha256": "245C45A1BA3D43E97C91634C87BDE9755F49B6A0A3727EB87AFC8FA71B69C645",
        "snapshot_path": "02-current-state-and-gap-analysis.md.base64",
        "snapshot_file_bytes": 16381,
        "snapshot_file_raw_sha256": "1CB7816AAF53594EF94242270885AF7672F10D40393959CA985C1625FEF0C3E7",
    },
    "docs/ptcgdap/03-target-architecture.md": {
        "bytes": 21225,
        "raw_sha256": "DBA2A6F271337E6FE6A2F3448C825AB1B0B5A1E0B9592E73A0C8C83B9A3F0AB4",
        "snapshot_path": "03-target-architecture.md.base64",
        "snapshot_file_bytes": 28301,
        "snapshot_file_raw_sha256": "02F3BF67274F1FA5C3B6AE0A8A90D24A4FEB2A861069671F1497B118C24D17E8",
    },
    "docs/ptcgdap/04-migration-roadmap.md": {
        "bytes": 17223,
        "raw_sha256": "563C00BF761963830BBD6184B3EA309D3FD75FE74DE0EB26A013A875A21415B0",
        "snapshot_path": "04-migration-roadmap.md.base64",
        "snapshot_file_bytes": 22965,
        "snapshot_file_raw_sha256": "1C3043B94FDD618E157D246ABE8085B0420BC4FC2A9DFD2116123C2417148146",
    },
    "docs/ptcgdap/05-validation-promotion-and-rollback.md": {
        "bytes": 22574,
        "raw_sha256": "AAC2330A4E8842127239594E395ACCC5ECE0F1D84A1C6A9C892C8E01FD97E7D2",
        "snapshot_path": "05-validation-promotion-and-rollback.md.base64",
        "snapshot_file_bytes": 30101,
        "snapshot_file_raw_sha256": "293DDD0095F401E6423D304BFFBFF4B16B8D87C7F90509029CB60BF1D7090B65",
    },
    "docs/ptcgdap/06-first-vertical-slice.md": {
        "bytes": 18483,
        "raw_sha256": "D70EA4B16E6060304C4B7054AFE7B02A1226A9BDBC8FDBABAED240303B8199AC",
        "snapshot_path": "06-first-vertical-slice.md.base64",
        "snapshot_file_bytes": 24645,
        "snapshot_file_raw_sha256": "72FCCB6D23B50318FA88830E59E0E5135440AA81F5CC3C83904661EF33B925DE",
    },
    "docs/ptcgdap/07-decisions-risks-and-open-questions.md": {
        "bytes": 23467,
        "raw_sha256": "984603AD7481A2E81AE2B70C8F6789F7ABA17EB093835A1469DBF963510EE47E",
        "snapshot_path": "07-decisions-risks-and-open-questions.md.base64",
        "snapshot_file_bytes": 31293,
        "snapshot_file_raw_sha256": "305BEAA9B485106629FDF685E4506FE8B43A15C895B16D398EF730D1AD37AF2D",
    },
    "tests/ptcgdap/test_p2_wp1_parent_snapshot.py": {
        "bytes": 12899,
        "raw_sha256": "9974C305B6F269BFC731F9FE2EDA6E3AE0D4C745A897AAFBFE02E175E2BE6343",
        "snapshot_path": "test_p2_wp1_parent_snapshot.py.base64",
        "snapshot_file_bytes": 17201,
        "snapshot_file_raw_sha256": "D064FDF8C84C98AB81FF1E80A3EB419F3196A9CFAFFCF5ED4B42185C8D54E11C",
    },
}
EXPECTED_DELETE_PREFIXES = {"artifacts/ptcgdap/p2_wp2/"}
EXPECTED_DELETE_PATHS = {
    "contracts/ptcgdap/card_id_catalog.schema.json",
    "contracts/ptcgdap/card_id_catalog_source_manifest.json",
    "contracts/ptcgdap/card_id_catalog_bundle.json",
    "contracts/ptcgdap/card_id_catalog_conformance_vectors.json",
    "data/ptcgdap/card_id_catalog/official_card_attack_master_v1.json",
    "data/ptcgdap/card_id_catalog/marnie_exact_print_bridge_v1.json",
    "scripts/ai/ptcgdap/card_id_catalog.py",
    "scripts/ai/ptcgdap/host/godot/CardIdCatalog.gd",
    "tools/ptcgdap/build_card_id_catalog.py",
    "tests/ptcgdap/test_card_id_catalog_builder.py",
    "tests/ptcgdap/test_card_id_catalog_schema.py",
    "tests/ptcgdap/test_card_id_catalog.py",
    "tests/ptcgdap/test_p2_wp2_boundaries.py",
    "tests/ptcgdap/test_p2_wp2_parent_snapshot.py",
    "tests/ptcgdap/godot/test_card_id_catalog.gd",
}
FUTURE_P2_WP3_PARENT_DOCS = {
    "docs/ptcgdap/01-official-cabt-contract.md": {
        "bytes": 14939,
        "raw_sha256": "1262AE24BEEE3CFF56F533EFFAD7468AB57C9F63EBB248D076B191322B28DC91",
        "snapshot_path": "01-official-cabt-contract.md.base64",
        "snapshot_file_bytes": 19921,
        "snapshot_file_raw_sha256": "4516722CF012261847B69C2AE13A5601235603B10211BCE8711E7DD571A83CDD",
    },
}
FUTURE_P2_WP3_DELETE_PREFIXES = {"artifacts/ptcgdap/p2_wp3/"}
FUTURE_P2_WP3_DELETE_PATHS = {
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
EXPECTED_P2_WP1_WORKTREE_HASH = (
    "F21CB3625B4C00A85A041A81AC14FA754E8737377C1A6188F626589BB4637E8C"
)
EXPECTED_P2_WP1_STATUS_COUNTS = {"untracked": 153, "deleted": 28, "modified": 1}
EXPECTED_P2_WP1_MANIFEST_RAW_SHA256 = (
    "1465FF641BCF722DA3AD411F02DF8377B26872723509EABC355EE1167A1C20E9"
)
EXPECTED_P2_WP1_MANIFEST_CANONICAL_SHA256 = (
    "81BDB4B254B1A7246F1A071FB0D1ABF2125B9AF31BE6FCB20A9F7DA0DA0C8A3C"
)


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
    snapshot_path = snapshot_root / snapshot_name
    encoded_file = snapshot_path.read_bytes()
    if (
        not encoded_file.endswith(b"\n")
        or encoded_file.count(b"\n") != 1
        or b"\r" in encoded_file
    ):
        raise AssertionError(f"payload must contain one ASCII base64 line plus LF: {snapshot_name}")
    encoded = encoded_file[:-1]
    try:
        encoded_text = encoded.decode("ascii")
        decoded = base64.b64decode(encoded_text, validate=True)
    except (UnicodeDecodeError, ValueError) as error:
        raise AssertionError(f"invalid canonical base64: {snapshot_name}") from error
    if base64.b64encode(decoded) != encoded:
        raise AssertionError(f"non-canonical RFC4648 base64: {snapshot_name}")
    if len(encoded_file) != entry["snapshot_file_bytes"]:
        raise AssertionError(f"payload byte count drift: {snapshot_name}")
    if _sha256(encoded_file) != entry["snapshot_file_raw_sha256"]:
        raise AssertionError(f"payload hash drift: {snapshot_name}")
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
    parts = completed.stdout.split(b"\x00")
    output: list[tuple[str, str]] = []
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
            raise AssertionError("rename/copy status is outside the pinned parent algorithm")
        output.append((status, path))
    if len({path for _, path in output}) != len(output):
        raise AssertionError("duplicate path in git status")
    return output


class P2Wp2ParentSnapshotTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.manifest = load_json_strict(MANIFEST_PATH)
        cls.entries = {
            _safe_repo_path(entry["original_path"]): entry
            for entry in cls.manifest["files"]
        }

    def test_manifest_payloads_are_exact_safe_and_non_overlapping(self) -> None:
        self.assertEqual(self.manifest["schema_version"], 1)
        self.assertEqual(self.manifest["work_package"], "P2-WP2")
        self.assertEqual(self.manifest["snapshot_kind"], "exact_parent_bytes_before_p2_wp2")
        self.assertEqual(self.manifest["file_count"], 10)
        self.assertEqual(self.entries.keys(), EXPECTED_PARENT_DOCS.keys())

        parent = self.manifest["parent"]
        self.assertEqual(parent["work_package"], "P2-WP1")
        self.assertEqual(parent["manifest_raw_sha256"], EXPECTED_P2_WP1_MANIFEST_RAW_SHA256)
        self.assertEqual(
            parent["manifest_canonical_sha256"],
            EXPECTED_P2_WP1_MANIFEST_CANONICAL_SHA256,
        )

        snapshot_names = [entry["snapshot_path"] for entry in self.entries.values()]
        self.assertEqual(len(snapshot_names), len(set(snapshot_names)))
        original_paths = set(self.entries)
        payload_paths = {
            f"artifacts/ptcgdap/p2_wp2/parent_snapshot/{name}"
            for name in snapshot_names
        }
        self.assertTrue(original_paths.isdisjoint(payload_paths))

        for original_path, expected in EXPECTED_PARENT_DOCS.items():
            with self.subTest(path=original_path):
                entry = self.entries[original_path]
                self.assertEqual(entry["original_git_status"], "??")
                for key, value in expected.items():
                    self.assertEqual(entry[key], value)
                _decode_snapshot(entry)

        rollback = self.manifest["rollback_scope"]
        restore_paths = {_safe_repo_path(path) for path in rollback["restore_exact_paths"]}
        delete_prefixes = {
            _safe_repo_prefix(path) for path in rollback["delete_prefixes"]
        }
        delete_paths = {_safe_repo_path(path) for path in rollback["delete_exact_paths"]}
        self.assertEqual(restore_paths, set(EXPECTED_PARENT_DOCS))
        self.assertEqual(delete_prefixes, EXPECTED_DELETE_PREFIXES)
        self.assertEqual(delete_paths, EXPECTED_DELETE_PATHS)
        self.assertTrue(restore_paths.isdisjoint(delete_paths))
        self.assertTrue(
            all(not any(path.startswith(prefix) for prefix in delete_prefixes) for path in restore_paths)
        )
        self.assertTrue(
            all(not any(path.startswith(prefix) for prefix in delete_prefixes) for path in delete_paths)
        )

    def test_isolated_restore_recreates_only_the_ten_parent_paths(self) -> None:
        with tempfile.TemporaryDirectory(prefix="ptcgdap-p2-wp2-rollback-") as temp:
            restore_root = Path(temp)
            for original_path, entry in self.entries.items():
                destination = restore_root / original_path
                destination.parent.mkdir(parents=True, exist_ok=True)
                destination.write_bytes(_decode_snapshot(entry))

            restored_files = sorted(
                path.relative_to(restore_root).as_posix()
                for path in restore_root.rglob("*")
                if path.is_file()
            )
            self.assertEqual(restored_files, sorted(EXPECTED_PARENT_DOCS))
            for original_path, expected in EXPECTED_PARENT_DOCS.items():
                restored = (restore_root / original_path).read_bytes()
                self.assertEqual(len(restored), expected["bytes"])
                self.assertEqual(_sha256(restored), expected["raw_sha256"])
            self.assertFalse((restore_root / "artifacts" / "ptcgdap" / "p2_wp2").exists())
            self.assertFalse((restore_root / "contracts" / "ptcgdap").exists())
            self.assertFalse((restore_root / "data" / "ptcgdap").exists())

    def test_virtual_rollback_reproduces_exact_p2_wp1_worktree_snapshot(self) -> None:
        parent_bytes = {
            original_path: _decode_snapshot(entry)
            for original_path, entry in self.entries.items()
        }
        future_parent_bytes = {
            original_path: _decode_snapshot(entry, FUTURE_P2_WP3_SNAPSHOT_ROOT)
            for original_path, entry in FUTURE_P2_WP3_PARENT_DOCS.items()
        }
        wp5_manifest = load_json_strict(FUTURE_P2_WP5_SNAPSHOT_ROOT / "manifest.json")
        wp5_entries = {
            entry["original_path"]: entry
            for entry in wp5_manifest["files"]
            if entry["original_path"] in FUTURE_P2_WP5_RESTORE_PATHS
        }
        self.assertEqual(set(wp5_entries), FUTURE_P2_WP5_RESTORE_PATHS)
        future_parent_bytes.update(
            {
                path: _decode_snapshot(entry, FUTURE_P2_WP5_SNAPSHOT_ROOT)
                for path, entry in wp5_entries.items()
            }
        )
        records: list[dict[str, object]] = []
        seen_parent_docs: set[str] = set()
        for status, path in _git_status():
            if path.startswith("artifacts/ptcgdap/p3_wp6/") or path in P3_WP6_PATHS or path.startswith("artifacts/ptcgdap/p3_wp7/") or path in P3_WP7_PATHS or path.startswith("artifacts/ptcgdap/p3_wp8/") or path in P3_WP8_PATHS or path.startswith("artifacts/ptcgdap/p4_wp1/") or path in P4_WP1_PATHS or path.startswith("artifacts/ptcgdap/p4_wp2/") or path in P4_WP2_PATHS or path.startswith("artifacts/ptcgdap/p4_wp3/") or path in P4_WP3_PATHS or path.startswith("artifacts/ptcgdap/p4_wp4/") or path in P4_WP4_PATHS or path.startswith("artifacts/ptcgdap/p4_wp5/") or path in P4_WP5_PATHS or path.startswith("artifacts/ptcgdap/p4_wp6/") or path in P4_WP6_PATHS:
                continue
            if (path.startswith(FUTURE_P3_WP1_PREFIX) or path in FUTURE_P3_WP1_PATHS or path.startswith(FUTURE_P3_WP2_PREFIX) or path in FUTURE_P3_WP2_PATHS or path.startswith(FUTURE_P3_WP3_PREFIX) or path in FUTURE_P3_WP3_PATHS or path.startswith(FUTURE_P3_WP4_PREFIX) or path in FUTURE_P3_WP4_PATHS or path.startswith(FUTURE_P3_WP5_PREFIX) or path in FUTURE_P3_WP5_PATHS):
                continue
            if path.startswith("artifacts/ptcgdap/p2_wp1/"):
                continue
            if any(path.startswith(prefix) for prefix in EXPECTED_DELETE_PREFIXES):
                continue
            if path in EXPECTED_DELETE_PATHS:
                continue
            if any(path.startswith(prefix) for prefix in FUTURE_P2_WP3_DELETE_PREFIXES):
                continue
            if path in FUTURE_P2_WP3_DELETE_PATHS:
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
                seen_parent_docs.add(path)
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

        self.assertEqual(seen_parent_docs, set(EXPECTED_PARENT_DOCS))
        records.sort(key=lambda record: str(record["path"]))
        counts = Counter(
            "untracked"
            if record["status"] == "??"
            else "deleted"
            if "D" in str(record["status"])
            else "modified"
            for record in records
        )
        expected = self.manifest["virtual_parent_worktree"]
        self.assertEqual(len(records), expected["entry_count"])
        self.assertEqual(dict(counts), expected["status_counts"])
        self.assertEqual(dict(counts), EXPECTED_P2_WP1_STATUS_COUNTS)
        digest = _sha256(canonical_json_v1_bytes(records))
        self.assertEqual(digest, expected["canonical_records_sha256"])
        self.assertEqual(digest, EXPECTED_P2_WP1_WORKTREE_HASH)


if __name__ == "__main__":
    unittest.main()
