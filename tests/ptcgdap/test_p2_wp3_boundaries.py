from __future__ import annotations

import ast
import hashlib
from pathlib import Path
import unittest

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict
from tests.ptcgdap.test_as_wp5_parent_snapshot import AS_WP5_APPROVED_SUCCESSOR_RUNTIME_PATHS


ROOT = Path(__file__).resolve().parents[2]
WORK_PACKAGE = ROOT / "artifacts" / "ptcgdap" / "p2_wp3" / "work_package.json"
FINAL_MANIFEST = ROOT / "artifacts" / "ptcgdap" / "p2_wp3" / "manifest.json"
PARENT_MANIFEST = ROOT / "artifacts" / "ptcgdap" / "p2_wp2" / "manifest.json"
P1_BUNDLE = ROOT / "contracts" / "ptcgdap" / "cabt_contract_bundle.json"
SOURCE_LOCK = ROOT / "docs" / "ptcgdap" / "SOURCE_LOCK.json"

SCHEMA = ROOT / "contracts" / "ptcgdap" / "cabt_public_observation.schema.json"
PROFILE = ROOT / "contracts" / "ptcgdap" / "cabt_public_firewall_profile.json"
VECTORS = ROOT / "contracts" / "ptcgdap" / "cabt_public_firewall_conformance_vectors.json"
BUNDLE = ROOT / "contracts" / "ptcgdap" / "cabt_public_firewall_bundle.json"
PYTHON_RUNTIME = ROOT / "scripts" / "ai" / "ptcgdap" / "public_observation_firewall.py"
GODOT_RUNTIME = (
    ROOT / "scripts" / "ai" / "ptcgdap" / "public" / "PublicObservationFirewall.gd"
)
PROJECTOR_PYTHON_RUNTIME = ROOT / "scripts" / "ai" / "ptcgdap" / "observation_projector.py"
PROJECTOR_GODOT_RUNTIME = (
    ROOT
    / "scripts"
    / "ai"
    / "ptcgdap"
    / "host"
    / "godot"
    / "GodotObservationProjector.gd"
)

PARENT_MANIFEST_RAW_SHA256 = (
    "9FC8CDDD8B13A3EAC5FAC84DA592D27EF167D0536A7FD83EF66EA538490504D8"
)
PARENT_MANIFEST_CANONICAL_SHA256 = (
    "3DD2C5CF29F2DB53A87BCB1B4F3601369B97444B84A4533272CA0DB2673B96EA"
)
P1_BUNDLE_RAW_SHA256 = (
    "F1E8269B7E4908660E5BE993F574D433B89FF5134FFE853110751E8BA9777920"
)
P1_BUNDLE_CANONICAL_SHA256 = (
    "2CD02F54538985426EFDB057F3A6BDA4AD154DD171BCC03667D42D102982D294"
)
SOURCE_LOCK_RAW_SHA256 = (
    "DD5B2FB796731DCC4D2068B2C3D939346AB89A54D162F625845AB58A66767023"
)
SOURCE_LOCK_CANONICAL_SHA256 = (
    "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"
)
EXPECTED_ARTIFACTS = {
    "cabt_public_observation_schema_v1": (
        "contracts/ptcgdap/cabt_public_observation.schema.json",
        "7920429205450F22312332BE41DF1B82F3ED5F4277B2BFE16A63F7B07121B912",
    ),
    "cabt_public_firewall_profile_v1": (
        "contracts/ptcgdap/cabt_public_firewall_profile.json",
        "AA287117DF497ED51DCA19FA36DC6212E3AAC0E9A1D2B871BA6130B6E963332A",
    ),
    "cabt_public_firewall_conformance_v1": (
        "contracts/ptcgdap/cabt_public_firewall_conformance_vectors.json",
        "62C52602EE3914D62FCE5A6571C6D93E7CBF9F5E2CB6CE7DCF82A8E1018CEC58",
    ),
}
EXPECTED_BUNDLE_CANONICAL_SHA256 = (
    "A2781CE6B3AC7BB6BAD04A9F15F57CE23AEC338306F60E5B3050B31245685947"
)
EXPECTED_OWNER_FILES = {
    "contracts/ptcgdap/cabt_public_observation.schema.json",
    "contracts/ptcgdap/cabt_public_firewall_profile.json",
    "contracts/ptcgdap/cabt_public_firewall_conformance_vectors.json",
    "contracts/ptcgdap/cabt_public_firewall_bundle.json",
    "scripts/ai/ptcgdap/public_observation_firewall.py",
    "scripts/ai/ptcgdap/public/PublicObservationFirewall.gd",
    "tools/ptcgdap/build_public_firewall_contract.py",
}
FORBIDDEN_RUNTIME_MARKERS = {
    "AIOpponent",
    "BattleScene",
    "CardData",
    "CardDatabase",
    "CardInstance",
    "GameState",
    "GameStateMachine",
    "GodotLogCursor",
    "GodotObservationProjector",
    "HTTPRequest",
    "HTTPClient",
    "OS.create_process",
    "OS.execute",
    "PacketPeerUDP",
    "PlayerState",
    "PokemonSlot",
    "StreamPeerTCP",
    "WebSocketPeer",
    "_dialog_data",
    "_pending_choice",
    "ptcgabc",
    "user://",
}
FORBIDDEN_PYTHON_IMPORTS = {
    "ctypes",
    "http",
    "multiprocessing",
    "requests",
    "socket",
    "subprocess",
    "urllib",
}


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest().upper()


def _canonical_sha256(path: Path) -> str:
    return _sha256(canonical_json_v1_bytes(load_json_strict(path)))


def _gdscript_without_comments(source: str) -> str:
    return "\n".join(line.split("#", 1)[0] for line in source.splitlines())


class P2Wp3BoundaryTests(unittest.TestCase):
    def test_parent_contract_source_lock_and_p2_wp2_manifest_remain_exact(self) -> None:
        self.assertEqual(_sha256(PARENT_MANIFEST.read_bytes()), PARENT_MANIFEST_RAW_SHA256)
        self.assertEqual(
            _canonical_sha256(PARENT_MANIFEST), PARENT_MANIFEST_CANONICAL_SHA256
        )
        self.assertEqual(_sha256(P1_BUNDLE.read_bytes()), P1_BUNDLE_RAW_SHA256)
        self.assertEqual(_canonical_sha256(P1_BUNDLE), P1_BUNDLE_CANONICAL_SHA256)
        self.assertEqual(_sha256(SOURCE_LOCK.read_bytes()), SOURCE_LOCK_RAW_SHA256)
        self.assertEqual(_canonical_sha256(SOURCE_LOCK), SOURCE_LOCK_CANONICAL_SHA256)

    def test_subordinate_bundle_binds_exactly_three_artifacts_without_cycle(self) -> None:
        paths = {
            "cabt_public_observation_schema_v1": SCHEMA,
            "cabt_public_firewall_profile_v1": PROFILE,
            "cabt_public_firewall_conformance_v1": VECTORS,
        }
        actual_artifacts: dict[str, tuple[str, str]] = {}
        bundle = load_json_strict(BUNDLE)
        self.assertEqual(_canonical_sha256(BUNDLE), EXPECTED_BUNDLE_CANONICAL_SHA256)
        self.assertEqual(bundle["bundle_id"], "ptcgdap-public-firewall-p2-wp3-v1")
        self.assertEqual(
            bundle["parent_contract"],
            {
                "id": "ptcgdap-cabt-contract-p1-wp3-v1",
                "path": "contracts/ptcgdap/cabt_contract_bundle.json",
                "canonical_sha256": P1_BUNDLE_CANONICAL_SHA256,
            },
        )
        self.assertEqual(len(bundle["artifacts"]), 3)
        for entry in bundle["artifacts"]:
            artifact_id = entry["id"]
            self.assertNotIn(artifact_id, actual_artifacts)
            actual_artifacts[artifact_id] = (
                entry["path"],
                entry["canonical_sha256"],
            )
        self.assertEqual(actual_artifacts, EXPECTED_ARTIFACTS)
        for artifact_id, (_, expected_hash) in EXPECTED_ARTIFACTS.items():
            self.assertEqual(_canonical_sha256(paths[artifact_id]), expected_hash)
            self.assertNotIn(
                EXPECTED_BUNDLE_CANONICAL_SHA256,
                paths[artifact_id].read_text(encoding="utf-8"),
            )

    def test_profile_and_all_twenty_three_vectors_lock_the_public_boundary(self) -> None:
        profile = load_json_strict(PROFILE)
        self.assertIs(profile["projection"]["positive_allow_list_only"], True)
        self.assertEqual(
            profile["projection"]["required_root_fields"],
            ["select", "logs", "current"],
        )
        self.assertEqual(
            profile["projection"]["optional_framework_fields"],
            ["step", "remainingOverageTime"],
        )
        self.assertEqual(profile["hash_contract"]["domain"], "public_observation")
        self.assertEqual(
            profile["projection"]["unknown_field_policy"],
            "quarantine_and_omit_key_pointer_and_value",
        )
        self.assertIs(profile["provenance"]["unknown_key_names_allowed"], False)
        self.assertIs(profile["provenance"]["private_hashes_allowed"], False)

        vectors = load_json_strict(VECTORS)
        cases = vectors["cases"]
        self.assertEqual(len(vectors["base_observations"]), 3)
        self.assertEqual(len(cases), 23)
        case_ids = [case["id"] for case in cases]
        self.assertEqual(len(case_ids), len(set(case_ids)))
        self.assertEqual({case["status"] for case in cases}, {"accepted", "rejected"})
        required = {
            "search-token-omitted",
            "unknown-private-fields-quarantined",
            "unknown-key-name-quarantined",
            "opponent-hand-exposed",
            "own-prize-exposed",
            "opponent-prize-exposed",
            "own-active-concealed",
            "opponent-active-concealed-accepted",
            "unauthorized-select-deck",
            "opponent-draw-identity-exposed",
            "opponent-draw-reverse-accepted",
            "string-name-host-fault",
            "unsafe-integer-host-fault",
        }
        self.assertTrue(required.issubset(case_ids))
        for case in cases:
            if case["status"] == "rejected":
                self.assertIsNone(case["expected_public_observation"])
                self.assertIsNone(case["expected_public_observation_hash"])
                self.assertIn(case["expected_issue_code"], profile["result_contract"]["error_codes"])

    def test_work_package_scope_and_alignment_claim_are_exact(self) -> None:
        work_package = load_json_strict(WORK_PACKAGE)
        self.assertEqual(work_package["work_package"], "P2-WP3")
        self.assertEqual(work_package["entry_evidence"]["parent_manifest_raw_sha256"], PARENT_MANIFEST_RAW_SHA256)
        self.assertEqual(
            work_package["entry_evidence"]["parent_manifest_canonical_sha256"],
            PARENT_MANIFEST_CANONICAL_SHA256,
        )
        owner_files = set(work_package["files_allowed"]["contracts"])
        owner_files.update(work_package["files_allowed"]["implementation"])
        self.assertEqual(owner_files, EXPECTED_OWNER_FILES)
        self.assertIn("shadow_public_firewall_only", work_package["shadow_or_live"])
        self.assertEqual(work_package["alignment_claim"]["A0"], "partial / not claimed")
        for level in ("A1", "A2", "A3", "A4", "A5"):
            self.assertEqual(work_package["alignment_claim"][level], "not evaluated")
        self.assertEqual(work_package["next_permitted_work"]["work_package"], "P2-WP4")
        if FINAL_MANIFEST.is_file():
            self.assertEqual(work_package["status"], "shadow")
            self.assertEqual(work_package["implementation_state"], "completed")
        else:
            self.assertIn(work_package["status"], {"planned", "shadow"})
            self.assertIn(
                work_package["implementation_state"],
                {"not_started", "implementation_complete_evidence_pending", "completed"},
            )

    def test_runtime_sources_have_only_pure_contract_dependencies(self) -> None:
        python_source = PYTHON_RUNTIME.read_text(encoding="utf-8")
        godot_source = _gdscript_without_comments(GODOT_RUNTIME.read_text(encoding="utf-8"))
        for marker in FORBIDDEN_RUNTIME_MARKERS:
            self.assertNotIn(marker, python_source, f"forbidden Python marker: {marker}")
            self.assertNotIn(marker, godot_source, f"forbidden GDScript marker: {marker}")
        self.assertNotIn("write_bytes", python_source)
        self.assertNotIn("write_text", python_source)
        self.assertNotIn("FileAccess.WRITE", godot_source)
        for write_method in ("store_buffer(", "store_string(", "store_line("):
            self.assertNotIn(write_method, godot_source)

        tree = ast.parse(python_source, filename=str(PYTHON_RUNTIME))
        import_roots: set[str] = set()
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                import_roots.update(alias.name.split(".", 1)[0] for alias in node.names)
            elif isinstance(node, ast.ImportFrom) and node.module:
                import_roots.add(node.module.split(".", 1)[0])
        self.assertTrue(import_roots.isdisjoint(FORBIDDEN_PYTHON_IMPORTS))

        allowed_preloads = {
            "res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd",
            "res://scripts/ai/ptcgdap/cabt/CabtTreeHash.gd",
            "res://scripts/ai/ptcgdap/cabt/CabtContractSet.gd",
            "res://scripts/ai/ptcgdap/cabt/CabtObservationParser.gd",
            "res://scripts/ai/ptcgdap/cabt/CabtRawEnvelope.gd",
        }
        preload_paths = {
            line.split('preload("', 1)[1].split('")', 1)[0]
            for line in godot_source.splitlines()
            if 'preload("' in line
        }
        self.assertEqual(preload_paths, allowed_preloads)

    def test_no_script_scene_or_project_wires_the_shadow_firewall_live(self) -> None:
        approved_non_live_conformance_witnesses = {
            # D052 parses sealed public JSON fixtures through the established
            # firewall parser, but never owns a match, window, index, or
            # engine commit.  Keep this exception local to the live-consumer
            # scan rather than treating the acceptance runner as a runtime
            # successor across unrelated boundary tests.
            "scripts/ai/ptcgdap/runtime/local/PolicyExecutorConformance.gd",
        }
        owner_paths = {
            PYTHON_RUNTIME.resolve(),
            GODOT_RUNTIME.resolve(),
            (ROOT / "scripts/ai/ptcgdap/public_log_cursor.py").resolve(),
            (ROOT / "scripts/ai/ptcgdap/public/GodotLogCursor.gd").resolve(),
            PROJECTOR_PYTHON_RUNTIME.resolve(),
            PROJECTOR_GODOT_RUNTIME.resolve(),
            (ROOT / "scripts/ai/ptcgdap/strategic_context_v18.py").resolve(),
            (ROOT / "scripts/ai/ptcgdap/public/StrategicContextV18.gd").resolve(),
            (ROOT / "scripts/ai/ptcgdap/strategic_trace_v2.py").resolve(),
            (ROOT / "scripts/ai/ptcgdap/public/StrategicTraceV2.gd").resolve(),
            (ROOT / "scripts/ai/ptcgdap/restricted_base_graph_executor.py").resolve(),
            (ROOT / "scripts/ai/ptcgdap/public/RestrictedBaseGraphExecutor.gd").resolve(),
            (ROOT / "scripts/ai/ptcgdap/public_deck_adapter.py").resolve(),
            (ROOT / "scripts/ai/ptcgdap/public/PublicDeckAdapter.gd").resolve(),
            (ROOT / "scripts/ai/ptcgdap/public/PublicBasePolicy.gd").resolve(),
            (ROOT / "scripts/ai/ptcgdap/public/PublicPolicyBudget.gd").resolve(),
            (ROOT / "scripts/ai/ptcgdap/marnie_trajectory_replay.py").resolve(),
            (ROOT / "scripts/ai/ptcgdap/public/MarnieTrajectoryReplay.gd").resolve(),
            (ROOT / "scripts/ai/ptcgdap/marnie_public_base.py").resolve(),
            (ROOT / "scripts/ai/ptcgdap/public/MarniePublicBase.gd").resolve(),
        }
        matches: list[str] = []
        roots = [ROOT / "scripts", ROOT / "scenes"]
        for scan_root in roots:
            if not scan_root.exists():
                continue
            for path in scan_root.rglob("*"):
                if not path.is_file() or path.resolve() in owner_paths:
                    continue
                if path.suffix.lower() not in {".py", ".gd", ".tscn", ".tres"}:
                    continue
                relative = path.relative_to(ROOT).as_posix()
                if (
                    relative in AS_WP5_APPROVED_SUCCESSOR_RUNTIME_PATHS
                    or relative in approved_non_live_conformance_witnesses
                ):
                    continue
                text = path.read_text(encoding="utf-8", errors="strict")
                if (
                    "PublicObservationFirewall" in text
                    or "public_observation_firewall" in text
                    or "public/PublicObservationFirewall.gd" in text
                ):
                    matches.append(relative)
        project_text = (ROOT / "project.godot").read_text(encoding="utf-8")
        self.assertNotIn("PublicObservationFirewall", project_text)
        self.assertNotIn("public_observation_firewall", project_text)
        self.assertEqual(matches, [], "shadow firewall must have no live consumer")


if __name__ == "__main__":
    unittest.main()
