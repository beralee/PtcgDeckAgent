from __future__ import annotations

import ast
import hashlib
from pathlib import Path
import unittest

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict
from tests.ptcgdap.test_as_wp5_parent_snapshot import AS_WP5_APPROVED_SUCCESSOR_RUNTIME_PATHS


ROOT = Path(__file__).resolve().parents[2]
WORK_PACKAGE = ROOT / "artifacts/ptcgdap/p2_wp5/work_package.json"
FINAL_MANIFEST = ROOT / "artifacts/ptcgdap/p2_wp5/manifest.json"
PARENT_MANIFEST = ROOT / "artifacts/ptcgdap/p2_wp4/manifest.json"
P1_BUNDLE = ROOT / "contracts/ptcgdap/cabt_contract_bundle.json"
CATALOG_BUNDLE = ROOT / "contracts/ptcgdap/card_id_catalog_bundle.json"
FIREWALL_BUNDLE = ROOT / "contracts/ptcgdap/cabt_public_firewall_bundle.json"
CURSOR_BUNDLE = ROOT / "contracts/ptcgdap/cabt_public_log_cursor_bundle.json"
SOURCE_LOCK = ROOT / "docs/ptcgdap/SOURCE_LOCK.json"
SCHEMA = ROOT / "contracts/ptcgdap/godot_observation_projector.schema.json"
PROFILE = ROOT / "contracts/ptcgdap/godot_observation_projector_profile.json"
VECTORS = ROOT / "contracts/ptcgdap/godot_observation_projector_conformance_vectors.json"
BUNDLE = ROOT / "contracts/ptcgdap/godot_observation_projector_bundle.json"
PYTHON_RUNTIME = ROOT / "scripts/ai/ptcgdap/observation_projector.py"
GODOT_RUNTIME = ROOT / "scripts/ai/ptcgdap/host/godot/GodotObservationProjector.gd"
IDENTITY_PYTHON_RUNTIME = ROOT / "scripts/ai/ptcgdap/marnie_identity_projection.py"
IDENTITY_GODOT_RUNTIME = ROOT / "scripts/ai/ptcgdap/public/MarnieIdentityProjection.gd"

PARENT_RAW = "EC004DBDD0F2E6696A9BEBB7B09726D78BD2705D06518BBFE74C5FDA367BFC2D"
PARENT_CANONICAL = "08058AA0D8237443BAB579797D3ABCEBE5B5C14061CA1752D05FCB44A8578E5A"
P1_CANONICAL = "2CD02F54538985426EFDB057F3A6BDA4AD154DD171BCC03667D42D102982D294"
CATALOG_CANONICAL = "AB8CF10465F492A98DA8247A84572AECEE281D0726F7BB7B8E5DBC03A6AC70D4"
FIREWALL_CANONICAL = "A2781CE6B3AC7BB6BAD04A9F15F57CE23AEC338306F60E5B3050B31245685947"
CURSOR_CANONICAL = "ED246F029531AA8F21956A64D70F557F1BBC90450A6F9109C5286261E290319D"
SOURCE_LOCK_CANONICAL = "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"
PROJECTOR_CANONICAL = "C51EA4CF1AEFCBB5B9C6D83825FF3A717CCDCC4105B804210BF6169372619041"
EXPECTED_ARTIFACTS = {
    "godot_observation_projector_schema_v1": (
        "contracts/ptcgdap/godot_observation_projector.schema.json",
        "6045AF6A55B10FF43A917D5ED85DB98204CFDFE78AAEABCD6B20051CEAF011DF",
    ),
    "godot_observation_projector_profile_v1": (
        "contracts/ptcgdap/godot_observation_projector_profile.json",
        "175C4422EDB2DB5ECCF3BF04AC16AC8B9BF74F80E8B4C3F75E634C6772A4BFD1",
    ),
    "godot_observation_projector_conformance_v1": (
        "contracts/ptcgdap/godot_observation_projector_conformance_vectors.json",
        "D3724188C8ED7569749E8733AF8666107922E83C632ABD0D7D14F977EBF3AF73",
    ),
}


def _sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest().upper()


def _canonical(path: Path) -> str:
    return _sha(canonical_json_v1_bytes(load_json_strict(path)))


def _gd_without_comments(source: str) -> str:
    return "\n".join(line.split("#", 1)[0] for line in source.splitlines())


class P2Wp5BoundaryTests(unittest.TestCase):
    def test_parent_contract_chain_and_source_lock_remain_exact(self) -> None:
        self.assertEqual(_sha(PARENT_MANIFEST.read_bytes()), PARENT_RAW)
        self.assertEqual(_canonical(PARENT_MANIFEST), PARENT_CANONICAL)
        self.assertEqual(_canonical(P1_BUNDLE), P1_CANONICAL)
        self.assertEqual(_canonical(CATALOG_BUNDLE), CATALOG_CANONICAL)
        self.assertEqual(_canonical(FIREWALL_BUNDLE), FIREWALL_CANONICAL)
        self.assertEqual(_canonical(CURSOR_BUNDLE), CURSOR_CANONICAL)
        self.assertEqual(_canonical(SOURCE_LOCK), SOURCE_LOCK_CANONICAL)

    def test_subordinate_bundle_binds_exactly_three_artifacts_without_cycle(self) -> None:
        bundle = load_json_strict(BUNDLE)
        self.assertEqual(_canonical(BUNDLE), PROJECTOR_CANONICAL)
        self.assertEqual(bundle["bundle_id"], "ptcgdap-godot-observation-projector-p2-wp5-v1")
        self.assertEqual(bundle["p1_contract_canonical_sha256"], P1_CANONICAL)
        self.assertEqual(bundle["catalog_bundle_canonical_sha256"], CATALOG_CANONICAL)
        self.assertEqual(bundle["firewall_bundle_canonical_sha256"], FIREWALL_CANONICAL)
        self.assertEqual(bundle["parent_cursor_bundle_canonical_sha256"], CURSOR_CANONICAL)
        actual = {
            entry["id"]: (entry["path"], entry["canonical_sha256"])
            for entry in bundle["artifacts"]
        }
        self.assertEqual(actual, EXPECTED_ARTIFACTS)
        paths = {
            "godot_observation_projector_schema_v1": SCHEMA,
            "godot_observation_projector_profile_v1": PROFILE,
            "godot_observation_projector_conformance_v1": VECTORS,
        }
        for artifact_id, (_, digest) in EXPECTED_ARTIFACTS.items():
            self.assertEqual(_canonical(paths[artifact_id]), digest)
            self.assertNotIn(PROJECTOR_CANONICAL, paths[artifact_id].read_text(encoding="utf-8"))

    def test_profile_and_vectors_lock_positive_visibility_and_all_w1_w7_success(self) -> None:
        profile = load_json_strict(PROFILE)
        vectors = load_json_strict(VECTORS)
        self.assertEqual(profile["execution_scope"], "shadow_only_no_live_consumer")
        self.assertEqual(profile["visibility"]["opponent_hand"], "count_only_null_identity_list")
        self.assertEqual(profile["visibility"]["host_entity_serial"], "never_public")
        self.assertEqual(profile["result_contract"]["serialization_authority"], "audit/conformance only; serialized dictionaries never authorize window, policy or execution")
        cases = vectors["projection_cases"]
        self.assertEqual({case["window"] for case in cases}, {"W1", "W2", "W3", "W4", "W5", "W6", "W7"})
        self.assertTrue(all(case["expected_result"]["accepted"] is True for case in cases))
        base = vectors["state_fixtures"]["base_mapped_state"]
        acting = base["acting_player_index"]
        self.assertIs(type(base["players"][acting]["hand"]), list)
        self.assertIsNone(base["players"][1 - acting]["hand"])

    def test_work_package_scope_status_alignment_and_next_cursor_are_exact(self) -> None:
        package = load_json_strict(WORK_PACKAGE)
        self.assertEqual(package["work_package"], "P2-WP5")
        self.assertEqual(package["entry_evidence"]["parent_manifest_raw_sha256"], PARENT_RAW)
        self.assertEqual(package["entry_evidence"]["parent_manifest_canonical_sha256"], PARENT_CANONICAL)
        self.assertEqual(package["alignment_claim"]["A0"], "partial / not claimed")
        for level in ("A1", "A2", "A3", "A4", "A5"):
            self.assertEqual(package["alignment_claim"][level], "not evaluated")
        self.assertEqual(package["next_permitted_work"]["work_package"], "P3-WP1")
        if FINAL_MANIFEST.is_file():
            self.assertEqual(package["status"], "shadow")
            self.assertEqual(package["implementation_state"], "completed")
        else:
            self.assertEqual(package["status"], "planned")
            self.assertEqual(package["implementation_state"], "not_started")

    def test_runtime_dependencies_are_owner_scoped_and_read_only(self) -> None:
        python_source = PYTHON_RUNTIME.read_text(encoding="utf-8")
        godot_source = _gd_without_comments(GODOT_RUNTIME.read_text(encoding="utf-8"))
        forbidden = {
            "AIOpponent", "BattleScene", "GameStateMachine", "HeadlessMatchBridge",
            "DeckStrategy", "HTTPRequest", "HTTPClient", "WebSocketPeer",
            "_dialog_data", "_pending_choice", "ptcgabc", "get_instance_id",
            "instance_id", "search_begin_input\"] =", "raw_private_hash",
            "token_free_callback_hash",
        }
        for marker in forbidden:
            self.assertNotIn(marker, python_source)
            self.assertNotIn(marker, godot_source)
        for marker in ("write_bytes", "write_text", "FileAccess.WRITE", "store_buffer(", "store_string(", "store_line("):
            self.assertNotIn(marker, python_source)
            self.assertNotIn(marker, godot_source)
        tree = ast.parse(python_source)
        imported: set[str] = set()
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                imported.update(alias.name.split(".", 1)[0] for alias in node.names)
            elif isinstance(node, ast.ImportFrom) and node.module:
                imported.add(node.module.split(".", 1)[0])
        self.assertTrue(imported.isdisjoint({"ctypes", "http", "multiprocessing", "requests", "socket", "subprocess", "urllib"}))
        preloads = {
            line.split('preload("', 1)[1].split('")', 1)[0]
            for line in godot_source.splitlines() if 'preload("' in line
        }
        self.assertEqual(preloads, {
            "res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd",
            "res://scripts/ai/ptcgdap/cabt/CabtContractSet.gd",
            "res://scripts/ai/ptcgdap/cabt/CabtObservationParser.gd",
            "res://scripts/ai/ptcgdap/host/godot/CardIdCatalog.gd",
            "res://scripts/ai/ptcgdap/host/godot/GodotSerialRegistry.gd",
            "res://scripts/ai/ptcgdap/public/PublicObservationFirewall.gd",
            "res://scripts/data/GameState.gd",
            "res://scripts/data/PlayerState.gd",
            "res://scripts/data/CardInstance.gd",
            "res://scripts/data/CardData.gd",
            "res://scripts/data/PokemonSlot.gd",
        })

    def test_no_script_scene_or_project_wires_shadow_projector_live(self) -> None:
        owners = {
            PYTHON_RUNTIME.resolve(), GODOT_RUNTIME.resolve(),
            IDENTITY_PYTHON_RUNTIME.resolve(), IDENTITY_GODOT_RUNTIME.resolve(),
        }
        matches: list[str] = []
        for scan_root in (ROOT / "scripts", ROOT / "scenes"):
            if not scan_root.exists():
                continue
            for path in scan_root.rglob("*"):
                if not path.is_file() or path.resolve() in owners or path.suffix.lower() not in {".py", ".gd", ".tscn", ".tres"}:
                    continue
                relative = path.relative_to(ROOT).as_posix()
                if relative in AS_WP5_APPROVED_SUCCESSOR_RUNTIME_PATHS:
                    continue
                text = path.read_text(encoding="utf-8", errors="strict")
                if "GodotObservationProjector" in text or "godot_observation_projector" in text:
                    matches.append(relative)
        project = (ROOT / "project.godot").read_text(encoding="utf-8")
        self.assertNotIn("GodotObservationProjector", project)
        self.assertNotIn("godot_observation_projector", project)
        self.assertEqual(matches, [])


if __name__ == "__main__":
    unittest.main()
