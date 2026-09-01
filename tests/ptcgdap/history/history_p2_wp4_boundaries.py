from __future__ import annotations

import ast
import hashlib
from pathlib import Path
import unittest

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[2]
WORK_PACKAGE = ROOT / "artifacts/ptcgdap/p2_wp4/work_package.json"
FINAL_MANIFEST = ROOT / "artifacts/ptcgdap/p2_wp4/manifest.json"
PARENT_MANIFEST = ROOT / "artifacts/ptcgdap/p2_wp3/manifest.json"
P1_BUNDLE = ROOT / "contracts/ptcgdap/cabt_contract_bundle.json"
FIREWALL_BUNDLE = ROOT / "contracts/ptcgdap/cabt_public_firewall_bundle.json"
SOURCE_LOCK = ROOT / "docs/ptcgdap/SOURCE_LOCK.json"
SCHEMA = ROOT / "contracts/ptcgdap/cabt_public_log_cursor.schema.json"
PROFILE = ROOT / "contracts/ptcgdap/cabt_public_log_cursor_profile.json"
VECTORS = ROOT / "contracts/ptcgdap/cabt_public_log_cursor_conformance_vectors.json"
BUNDLE = ROOT / "contracts/ptcgdap/cabt_public_log_cursor_bundle.json"
PYTHON_RUNTIME = ROOT / "scripts/ai/ptcgdap/public_log_cursor.py"
GODOT_RUNTIME = ROOT / "scripts/ai/ptcgdap/public/GodotLogCursor.gd"

PARENT_RAW = "0ECCD6341E0A06980EFF1269B9FCBD5422793DBC68703E67E12B5FE1B4717DB7"
PARENT_CANONICAL = "D1387EBF915C7865A5B2F7B5D7E1D1078C3FCDE0D6A18A0A1DCEA8FAC5EC126C"
P1_CANONICAL = "2CD02F54538985426EFDB057F3A6BDA4AD154DD171BCC03667D42D102982D294"
FIREWALL_CANONICAL = "A2781CE6B3AC7BB6BAD04A9F15F57CE23AEC338306F60E5B3050B31245685947"
SOURCE_LOCK_CANONICAL = "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"
CURSOR_CANONICAL = "ED246F029531AA8F21956A64D70F557F1BBC90450A6F9109C5286261E290319D"
EXPECTED_ARTIFACTS = {
    "cabt_public_log_cursor_schema_v1": ("contracts/ptcgdap/cabt_public_log_cursor.schema.json", "44C277A27A04170B464DC1D9FF8CC0AC069507D498BE8C12A52B3905B376526B"),
    "cabt_public_log_cursor_profile_v1": ("contracts/ptcgdap/cabt_public_log_cursor_profile.json", "20B9B9744B152D74D53BBE5EA3005110B36D86D0D9B13FBF09A7C27AB24C21A5"),
    "cabt_public_log_cursor_conformance_v1": ("contracts/ptcgdap/cabt_public_log_cursor_conformance_vectors.json", "12DBB22C8C29B85DCC9F92A2BE01682976636DEF646C0C9B79A6CCDBD39CB52D"),
}


def _sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest().upper()


def _canonical(path: Path) -> str:
    return _sha(canonical_json_v1_bytes(load_json_strict(path)))


def _gd_without_comments(source: str) -> str:
    return "\n".join(line.split("#", 1)[0] for line in source.splitlines())


class P2Wp4BoundaryTests(unittest.TestCase):
    def test_parent_firewall_p1_and_source_lock_remain_exact(self) -> None:
        self.assertEqual(_sha(PARENT_MANIFEST.read_bytes()), PARENT_RAW)
        self.assertEqual(_canonical(PARENT_MANIFEST), PARENT_CANONICAL)
        self.assertEqual(_canonical(P1_BUNDLE), P1_CANONICAL)
        self.assertEqual(_canonical(FIREWALL_BUNDLE), FIREWALL_CANONICAL)
        self.assertEqual(_canonical(SOURCE_LOCK), SOURCE_LOCK_CANONICAL)

    def test_subordinate_bundle_binds_exactly_three_artifacts_without_cycle(self) -> None:
        bundle = load_json_strict(BUNDLE)
        self.assertEqual(_canonical(BUNDLE), CURSOR_CANONICAL)
        self.assertEqual(bundle["bundle_id"], "ptcgdap-public-log-cursor-p2-wp4-v1")
        self.assertEqual(bundle["parent_firewall_bundle"], {
            "id": "ptcgdap-public-firewall-p2-wp3-v1",
            "canonical_sha256": FIREWALL_CANONICAL,
        })
        self.assertEqual(bundle["p1_contract_canonical_sha256"], P1_CANONICAL)
        self.assertEqual(
            {entry["id"]: (entry["path"], entry["canonical_sha256"]) for entry in bundle["artifacts"]},
            EXPECTED_ARTIFACTS,
        )
        paths = {
            "cabt_public_log_cursor_schema_v1": SCHEMA,
            "cabt_public_log_cursor_profile_v1": PROFILE,
            "cabt_public_log_cursor_conformance_v1": VECTORS,
        }
        for artifact_id, (_, digest) in EXPECTED_ARTIFACTS.items():
            self.assertEqual(_canonical(paths[artifact_id]), digest)
            self.assertNotIn(CURSOR_CANONICAL, paths[artifact_id].read_text(encoding="utf-8"))

    def test_profile_and_vectors_lock_order_commit_replay_and_private_exclusion(self) -> None:
        profile = load_json_strict(PROFILE)
        vectors = load_json_strict(VECTORS)
        self.assertEqual(bytes.fromhex(profile["witness_contract"]["prefix_utf8_hex"]), b"PTCGDAP\0CABT_PUBLIC_LOG_SLICE_V1\0")
        self.assertIs(profile["input_authority"]["copied_dictionary_authorizes"], False)
        self.assertIs(profile["input_authority"]["caller_log_array_authorizes"], False)
        self.assertEqual(profile["result_contract"]["serialization_authority"], "audit_and_conformance_only")
        self.assertEqual(len(vectors["sources"]), 4)
        self.assertEqual(len(vectors["hash_vectors"]), 4)
        self.assertEqual(len(vectors["scenarios"]), 9)
        self.assertEqual(
            [record["type"] for record in vectors["sources"]["turn_draw_ordered"]["logs"]],
            [2, 4, 5],
        )
        self.assertEqual(
            [record["type"] for record in vectors["sources"]["move_attack_ordered"]["logs"]],
            [6, 15],
        )
        for forbidden in profile["witness_contract"]["forbidden_fields"]:
            for case in vectors["hash_vectors"]:
                self.assertNotIn(forbidden, case["payload"])

    def test_work_package_scope_status_alignment_and_next_cursor_are_exact(self) -> None:
        package = load_json_strict(WORK_PACKAGE)
        self.assertEqual(package["work_package"], "P2-WP4")
        self.assertEqual(package["entry_evidence"]["parent_manifest_raw_sha256"], PARENT_RAW)
        self.assertEqual(package["entry_evidence"]["parent_manifest_canonical_sha256"], PARENT_CANONICAL)
        self.assertEqual(package["entry_evidence"]["firewall_bundle_canonical_sha256"], FIREWALL_CANONICAL)
        self.assertEqual(package["alignment_claim"]["A0"], "partial / not claimed")
        for level in ("A1", "A2", "A3", "A4", "A5"):
            self.assertEqual(package["alignment_claim"][level], "not evaluated")
        self.assertEqual(package["next_permitted_work"]["work_package"], "P2-WP5")
        if FINAL_MANIFEST.is_file():
            self.assertEqual(package["status"], "shadow")
            self.assertEqual(package["implementation_state"], "completed")
        else:
            self.assertIn(package["status"], {"planned", "shadow"})
            self.assertIn(package["implementation_state"], {"not_started", "implementation_complete_evidence_pending", "completed"})

    def test_runtime_sources_are_pure_read_only_and_have_no_engine_or_host_dependency(self) -> None:
        python_source = PYTHON_RUNTIME.read_text(encoding="utf-8")
        godot_source = _gd_without_comments(GODOT_RUNTIME.read_text(encoding="utf-8"))
        forbidden = {
            "AIOpponent", "BattleScene", "CardDatabase", "CardInstance", "GameState",
            "GameStateMachine", "GodotObservationProjector", "HTTPRequest", "HTTPClient",
            "PlayerState", "PokemonSlot", "WebSocketPeer", "_dialog_data", "_pending_choice",
            "ptcgabc", "search_begin_input", "raw_private_hash", "token_free_callback_hash",
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
            "res://scripts/ai/ptcgdap/public/PublicObservationFirewall.gd",
        })

    def test_no_script_scene_or_project_wires_shadow_cursor_live(self) -> None:
        owners = {PYTHON_RUNTIME.resolve(), GODOT_RUNTIME.resolve()}
        matches: list[str] = []
        for scan_root in (ROOT / "scripts", ROOT / "scenes"):
            if not scan_root.exists():
                continue
            for path in scan_root.rglob("*"):
                if not path.is_file() or path.resolve() in owners or path.suffix.lower() not in {".py", ".gd", ".tscn", ".tres"}:
                    continue
                text = path.read_text(encoding="utf-8", errors="strict")
                if "GodotLogCursor" in text or "public_log_cursor" in text or "public/GodotLogCursor.gd" in text:
                    matches.append(path.relative_to(ROOT).as_posix())
        project = (ROOT / "project.godot").read_text(encoding="utf-8")
        self.assertNotIn("GodotLogCursor", project)
        self.assertNotIn("public_log_cursor", project)
        self.assertEqual(matches, [])


if __name__ == "__main__":
    unittest.main()
