from __future__ import annotations

import ast
import hashlib
from pathlib import Path
import re
import unittest

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[2]
WORK_PACKAGE = ROOT / "artifacts/ptcgdap/p5_wp4/work_package.json"
FINAL_MANIFEST = ROOT / "artifacts/ptcgdap/p5_wp4/manifest.json"
PARENT_MANIFEST = ROOT / "artifacts/ptcgdap/p5_wp3/manifest.json"
PYTHON_RUNTIME = ROOT / "scripts/ai/ptcgdap/marnie_identity_projection.py"
GODOT_RUNTIME = ROOT / "scripts/ai/ptcgdap/public/MarnieIdentityProjection.gd"
BUNDLE = ROOT / "contracts/ptcgdap/marnie_identity_projection_bundle.json"
PROFILE = ROOT / "contracts/ptcgdap/marnie_identity_projection_profile.json"
AUDIT = ROOT / "data/ptcgdap/marnie_vertical_slice/marnie_identity_projection_v1.json"
VECTORS = ROOT / "contracts/ptcgdap/marnie_identity_projection_conformance_vectors.json"
CURRENT_BUNDLE = "1EB530AB7DFACBE6AB098A6C67D6AAE0BC1871FF3E2F48C9284E8539EE6ACDC4"
PARENT_MANIFEST_RAW = "D71340F8A8EC0919B5A27F051753B115B346702BCFAC0C1ABFABC5F3AC00A473"
PARENT_MANIFEST_CANONICAL = "6593A8C5A88495785257A3AFEF9EB63BA1ACD22D2F200636D3DB102FA23A6BDD"
PARENT_POLICY = "F4E88E5DB4E480BA8441BE7B3A7C81CE3DB40ED1917EB37BCDCAC1C32B1ABD6C"
CATALOG = "AB8CF10465F492A98DA8247A84572AECEE281D0726F7BB7B8E5DBC03A6AC70D4"
PROJECTOR = "C51EA4CF1AEFCBB5B9C6D83825FF3A717CCDCC4105B804210BF6169372619041"


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


class P5Wp4BoundaryTests(unittest.TestCase):
    def test_governance_parent_cursor_and_alignment_are_exact(self) -> None:
        work = load_json_strict(WORK_PACKAGE)
        if FINAL_MANIFEST.is_file():
            self.assertEqual(("shadow", "completed"), (work["status"], work["implementation_state"]))
            self.assertEqual("allowed", work["next_permitted_work"]["status"])
        else:
            self.assertEqual(("planned", "not_started"), (work["status"], work["implementation_state"]))
            self.assertEqual("proposed_only_after_p5_wp4_exit", work["next_permitted_work"]["status"])
        self.assertEqual("P5-WP5", work["next_permitted_work"]["work_package"])
        self.assertEqual(
            {"A0":"partial / not claimed","A1":"not evaluated","A2":"not evaluated","A3":"not evaluated","A4":"not evaluated","A5":"not evaluated"},
            work["alignment_claim"],
        )
        self.assertEqual(PARENT_MANIFEST_RAW, sha(PARENT_MANIFEST.read_bytes()))
        self.assertEqual(PARENT_MANIFEST_CANONICAL, sha(canonical_json_v1_bytes(load_json_strict(PARENT_MANIFEST))))
        self.assertEqual(PARENT_POLICY, work["entry_evidence"]["parent_policy_bundle_canonical_sha256"])
        self.assertEqual(CATALOG, work["entry_evidence"]["catalog_bundle_canonical_sha256"])
        self.assertEqual(PROJECTOR, work["entry_evidence"]["projector_bundle_canonical_sha256"])

    def test_bundle_and_audit_are_exact_non_authoritative_overlays(self) -> None:
        bundle = load_json_strict(BUNDLE)
        profile = load_json_strict(PROFILE)
        audit = load_json_strict(AUDIT)
        vectors = load_json_strict(VECTORS)
        self.assertEqual(CURRENT_BUNDLE, sha(canonical_json_v1_bytes(bundle)))
        self.assertEqual(4, len(bundle["artifacts"]))
        self.assertEqual(PARENT_POLICY, bundle["parent_capability_policy_bundle"]["canonical_sha256"])
        self.assertEqual(CATALOG, bundle["card_catalog_bundle"]["canonical_sha256"])
        self.assertEqual(PROJECTOR, bundle["projector_bundle"]["canonical_sha256"])
        self.assertEqual(13, len(audit["frames"]))
        self.assertEqual(23, len(vectors["cases"]))
        self.assertEqual(573, audit["summary"]["identity_occurrence_count"])
        self.assertEqual(94, audit["summary"]["cross_frame_unique_serial_count"])
        self.assertEqual(34, len(audit["summary"]["distinct_official_card_ids"]))
        self.assertEqual((9, 25), (len(audit["summary"]["mapped_official_card_ids"]), len(audit["summary"]["known_unmapped_official_card_ids"])))
        self.assertFalse(audit["execution_authority"])
        self.assertFalse(audit["production_actions_used"])
        self.assertFalse(profile["live_owner"])
        self.assertFalse(profile["portable_ready"])

    def test_runtime_dependencies_are_offline_bounded_and_have_no_mapping_guess(self) -> None:
        python_text = PYTHON_RUNTIME.read_text(encoding="utf-8")
        godot_text = GODOT_RUNTIME.read_text(encoding="utf-8")
        tree = ast.parse(python_text)
        imported = {
            alias.name.split(".")[0]
            for node in ast.walk(tree)
            if isinstance(node, ast.Import)
            for alias in node.names
        }
        imported.update(
            (node.module or "").split(".")[0]
            for node in ast.walk(tree)
            if isinstance(node, ast.ImportFrom) and node.level == 0
        )
        self.assertTrue(imported <= {"__future__","copy","hashlib","pathlib","re","struct","types","typing"}, imported)
        forbidden = (
            "GameState", "GameStateMachine", "BattleScene", "AIOpponent", "HeadlessMatchBridge",
            "CardDatabase", "CardCatalogIndex", "HTTPClient", "HTTPRequest", "OS.execute",
            "subprocess", "random", "ctypes", "D:\\ai\\code\\ptcgabc", "set_code_en",
            "card_index_en", "localized", "display_name", "same_print", "execution_ticket",
        )
        for token in forbidden:
            self.assertNotIn(token, python_text)
            self.assertNotIn(token, godot_text)
        for resource in re.findall(r'(?:preload|load)\("(res://[^"]+)"\)', godot_text):
            self.assertTrue(resource.startswith("res://scripts/ai/ptcgdap/"), resource)

    def test_no_live_consumer_or_autoload_references_integration_owner(self) -> None:
        owners = {PYTHON_RUNTIME.resolve(), GODOT_RUNTIME.resolve()}
        needles = ("MarnieIdentityProjection", "marnie_identity_projection.py", "public/MarnieIdentityProjection.gd")
        matches: list[str] = []
        for base in (ROOT / "scripts", ROOT / "scenes"):
            if not base.exists():
                continue
            for path in base.rglob("*"):
                if not path.is_file() or path.suffix.lower() not in {".py", ".gd", ".tscn", ".tres"} or path.resolve() in owners:
                    continue
                text = path.read_text(encoding="utf-8", errors="replace")
                if any(needle in text for needle in needles):
                    matches.append(path.relative_to(ROOT).as_posix())
        project = (ROOT / "project.godot").read_text(encoding="utf-8")
        self.assertFalse(matches, matches)
        self.assertFalse(any(needle in project for needle in needles))

    def test_contract_contains_no_private_value_or_numeric_serial_equivalence_claim(self) -> None:
        serialized = "\n".join(canonical_json_v1_bytes(load_json_strict(path)).decode("utf-8") for path in (PROFILE, AUDIT, VECTORS))
        for token in (
            "search_begin_input", "raw_private_hash", "token_free_callback_hash",
            "PRIVATE_MUTATION_SENTINEL", "production_action\"", "engine_command",
            "official_native_serial_equals_godot", "host_entity_serial_is_wire_serial",
        ):
            self.assertNotIn(token, serialized)


if __name__ == "__main__":
    unittest.main()
