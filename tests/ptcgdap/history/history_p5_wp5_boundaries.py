from __future__ import annotations

import ast
import hashlib
from pathlib import Path
import re
import unittest

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[2]
WORK_PACKAGE = ROOT / "artifacts/ptcgdap/p5_wp5/work_package.json"
FINAL_MANIFEST = ROOT / "artifacts/ptcgdap/p5_wp5/manifest.json"
PARENT_MANIFEST = ROOT / "artifacts/ptcgdap/p5_wp4/manifest.json"
BUNDLE = ROOT / "contracts/ptcgdap/marnie_prompt_broker_bundle.json"
PROFILE = ROOT / "contracts/ptcgdap/marnie_prompt_broker_profile.json"
AUDIT = ROOT / "data/ptcgdap/marnie_vertical_slice/marnie_prompt_broker_v1.json"
VECTORS = ROOT / "contracts/ptcgdap/marnie_prompt_broker_conformance_vectors.json"
PYTHON_OWNER = ROOT / "scripts/ai/ptcgdap/marnie_prompt_broker.py"
GODOT_OWNER = ROOT / "scripts/ai/ptcgdap/public/MarniePromptBroker.gd"
CURRENT_BUNDLE = "E2EFDDE373EFBA0FDC929BE817595C8B3F0A5653956DB56418ADED57AFF960A1"
PARENT_RAW = "925E0FC61B2A9613D3B163CC895E522E91E05CFB4DAC14A4864463C10486FB17"
PARENT_CANONICAL = "D1643D75D34BF235ECE401B2453AC413A3D1D94C40B491D47FFD48520F3AEDBB"
SOURCE_LOCK = "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"
PARENT_BUNDLES = {
    "contracts/ptcgdap/marnie_vertical_slice_bundle.json": "7E0CF80D7B2872C29F69BA15548857F1F32407943371D3C12A266A0E471EC425",
    "contracts/ptcgdap/marnie_capability_policy_bundle.json": "F4E88E5DB4E480BA8441BE7B3A7C81CE3DB40ED1917EB37BCDCAC1C32B1ABD6C",
    "contracts/ptcgdap/marnie_identity_projection_bundle.json": "1EB530AB7DFACBE6AB098A6C67D6AAE0BC1871FF3E2F48C9284E8539EE6ACDC4",
    "contracts/ptcgdap/shadow_prompt_broker_bundle.json": "D19EC7B9B77370312C82E0572DFB016B75E3FE9F438B6C1EFFD50E0AB43C551E",
    "contracts/ptcgdap/engine_decision_port_bundle.json": "CC0026D523F2B5435031AC4E5952DB4E2C8B2C39944B333E97B1A2E4F3374C81",
    "contracts/ptcgdap/godot_option_binding_bundle.json": "4FFFEC48E4E1FE0774BB6E343D4D4B0384A9210057DEE06415C2A20F2899B1C1",
}


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


class P5Wp5BoundaryTests(unittest.TestCase):
    def test_governance_parent_cursor_and_alignment_are_exact(self) -> None:
        work = load_json_strict(WORK_PACKAGE)
        if FINAL_MANIFEST.is_file():
            self.assertEqual(("shadow", "completed"), (work["status"], work["implementation_state"]))
            self.assertEqual("allowed", work["next_permitted_work"]["status"])
        else:
            self.assertEqual(("planned", "not_started"), (work["status"], work["implementation_state"]))
            self.assertEqual("proposed_only_after_p5_wp5_exit", work["next_permitted_work"]["status"])
        self.assertEqual("P5-WP6", work["next_permitted_work"]["work_package"])
        self.assertEqual(
            {"A0":"partial / not claimed","A1":"not evaluated","A2":"not evaluated","A3":"not evaluated","A4":"not evaluated","A5":"not evaluated"},
            work["alignment_claim"],
        )
        self.assertEqual(PARENT_RAW, sha(PARENT_MANIFEST.read_bytes()))
        self.assertEqual(PARENT_CANONICAL, sha(canonical_json_v1_bytes(load_json_strict(PARENT_MANIFEST))))

    def test_bundle_parent_contracts_and_source_lock_remain_exact(self) -> None:
        bundle = load_json_strict(BUNDLE)
        self.assertEqual(CURRENT_BUNDLE, sha(canonical_json_v1_bytes(bundle)))
        self.assertEqual(4, len(bundle["artifacts"]))
        for relative, expected in PARENT_BUNDLES.items():
            with self.subTest(relative=relative):
                self.assertEqual(expected, sha(canonical_json_v1_bytes(load_json_strict(ROOT / relative))))
        source_lock = load_json_strict(ROOT / "docs/ptcgdap/SOURCE_LOCK.json")
        self.assertEqual(SOURCE_LOCK, sha(canonical_json_v1_bytes(source_lock)))

    def test_contract_is_exact_shadow_audit_with_complete_frontiers(self) -> None:
        profile = load_json_strict(PROFILE)
        audit = load_json_strict(AUDIT)
        vectors = load_json_strict(VECTORS)
        self.assertEqual(13, len(audit["frames"]))
        self.assertEqual(11, audit["summary"]["brokered_frame_count"])
        self.assertEqual(23, len(vectors["cases"]))
        self.assertEqual([8, 8, 7, 14], audit["frames"][3]["option_types"])
        self.assertEqual([7, 13, 12, 14], audit["frames"][8]["option_types"])
        self.assertFalse(audit["execution_authority"])
        self.assertFalse(audit["production_actions_used"])
        self.assertFalse(profile["result_contract"]["serialized_results_are_authority"])

    def test_new_owner_dependencies_are_offline_bounded(self) -> None:
        python_text = PYTHON_OWNER.read_text(encoding="utf-8")
        godot_text = GODOT_OWNER.read_text(encoding="utf-8")
        tree = ast.parse(python_text)
        imported = {
            alias.name.split(".")[0]
            for node in ast.walk(tree) if isinstance(node, ast.Import)
            for alias in node.names
        }
        imported.update(
            (node.module or "").split(".")[0]
            for node in ast.walk(tree)
            if isinstance(node, ast.ImportFrom) and node.level == 0
        )
        self.assertTrue(imported <= {"__future__", "collections", "hashlib", "pathlib", "types", "typing", "weakref"}, imported)
        for token in (
            "GameState", "GameStateMachine", "BattleScene", "AIOpponent", "HeadlessMatchBridge",
            "CardDatabase", "HTTPClient", "HTTPRequest", "OS.execute", "subprocess", "random", "ctypes",
            "D:\\ai\\code\\ptcgabc", "_pending_choice", "_dialog_data", "production_action(",
        ):
            self.assertNotIn(token, python_text)
            self.assertNotIn(token, godot_text)
        for resource in re.findall(r'(?:preload|load)\("(res://[^"]+)"\)', godot_text):
            self.assertTrue(resource.startswith(("res://scripts/ai/ptcgdap/", "res://scripts/engine/decision/")), resource)

    def test_no_live_consumer_or_autoload_references_owner(self) -> None:
        owners = {PYTHON_OWNER.resolve(), GODOT_OWNER.resolve()}
        needles = ("MarniePromptBroker", "marnie_prompt_broker.py", "public/MarniePromptBroker.gd")
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

    def test_serialized_contract_excludes_private_authority(self) -> None:
        serialized = "\n".join(
            canonical_json_v1_bytes(load_json_strict(path)).decode("utf-8")
            for path in (PROFILE, AUDIT, VECTORS)
        )
        for token in (
            "search_begin_input", "raw_private_hash", "token_free_callback_hash", "private_engine_command",
            "private_object_refs", "private_resolutions", "PRIVATE_MUTATION_SENTINEL", "execution_ticket",
        ):
            self.assertNotIn(token, serialized)


if __name__ == "__main__":
    unittest.main()
