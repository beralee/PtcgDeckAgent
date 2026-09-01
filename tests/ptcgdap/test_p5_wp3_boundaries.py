from __future__ import annotations

import ast
import hashlib
from pathlib import Path
import re
import unittest

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[2]
WORK_PACKAGE = ROOT / "artifacts/ptcgdap/p5_wp3/work_package.json"
FINAL_MANIFEST = ROOT / "artifacts/ptcgdap/p5_wp3/manifest.json"
PARENT_MANIFEST = ROOT / "artifacts/ptcgdap/p5_wp2/manifest.json"
PYTHON_RUNTIME = ROOT / "scripts/ai/ptcgdap/marnie_capability_policy.py"
GODOT_RUNTIME = ROOT / "scripts/ai/ptcgdap/public/MarnieCapabilityPolicy.gd"
POLICY = ROOT / "data/ptcgdap/marnie_vertical_slice/marnie_capability_policy_v1.json"
PROFILE = ROOT / "contracts/ptcgdap/marnie_capability_policy_profile.json"
BUNDLE = ROOT / "contracts/ptcgdap/marnie_capability_policy_bundle.json"
VECTORS = ROOT / "contracts/ptcgdap/marnie_capability_policy_conformance_vectors.json"
CURRENT_BUNDLE = "F4E88E5DB4E480BA8441BE7B3A7C81CE3DB40ED1917EB37BCDCAC1C32B1ABD6C"
PARENT_MANIFEST_RAW = "2A3827A51E4500C545684B0895996DD35475F5FCF6F9D0EDCD09F0CF0A16E83E"
PARENT_MANIFEST_CANONICAL = "EB6A0513D34116F16408F2E6293D7C62B6F12C5472018CDB3C3EDAA5D8E1608F"
PARENT_REPLAY = "E203A688BEC1AFFFABAAF06098361B3FAE04B84431F99AE75A19F891BFA9599F"
PARENT_FIXTURE = "7E0CF80D7B2872C29F69BA15548857F1F32407943371D3C12A266A0E471EC425"


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


class P5Wp3BoundaryTests(unittest.TestCase):
    def test_governance_parent_cursor_and_alignment_are_exact(self) -> None:
        work = load_json_strict(WORK_PACKAGE)
        if work["status"] == "shadow":
            self.assertEqual(("shadow", "completed"), (work["status"], work["implementation_state"]))
            self.assertEqual("allowed", work["next_permitted_work"]["status"])
        else:
            self.assertEqual(("planned", "tests_first"), (work["status"], work["implementation_state"]))
            self.assertEqual("proposed_only_after_p5_wp3_exit", work["next_permitted_work"]["status"])
        self.assertEqual("P5-WP4", work["next_permitted_work"]["work_package"])
        self.assertEqual(
            {"A0":"partial / not claimed","A1":"not evaluated","A2":"not evaluated","A3":"not evaluated","A4":"not evaluated","A5":"not evaluated"},
            work["alignment_claim"],
        )
        self.assertEqual(PARENT_MANIFEST_RAW, sha(PARENT_MANIFEST.read_bytes()))
        self.assertEqual(PARENT_MANIFEST_CANONICAL, sha(canonical_json_v1_bytes(load_json_strict(PARENT_MANIFEST))))
        self.assertEqual(PARENT_REPLAY, work["entry_evidence"]["parent_replay_bundle_canonical_sha256"])
        self.assertEqual(PARENT_FIXTURE, work["entry_evidence"]["parent_fixture_bundle_canonical_sha256"])

    def test_bundle_policy_and_vectors_are_exact_non_authoritative_overlays(self) -> None:
        bundle = load_json_strict(BUNDLE)
        policy = load_json_strict(POLICY)
        profile = load_json_strict(PROFILE)
        vectors = load_json_strict(VECTORS)
        self.assertEqual(CURRENT_BUNDLE, sha(canonical_json_v1_bytes(bundle)))
        self.assertEqual(4, len(bundle["artifacts"]))
        self.assertEqual(PARENT_REPLAY, bundle["parent_replay_bundle"]["canonical_sha256"])
        self.assertEqual(PARENT_FIXTURE, bundle["parent_fixture_bundle"]["canonical_sha256"])
        self.assertEqual(13, len(policy["rules"]))
        self.assertEqual(23, len(vectors["cases"]))
        self.assertEqual(13, len({rule["frame_id"] for rule in policy["rules"]}))
        self.assertFalse(policy["production_actions_used"])
        self.assertFalse(policy["execution_authority"])
        self.assertFalse(profile["live_owner"])
        self.assertFalse(profile["portable_ready"])
        for case in vectors["cases"]:
            expected = case["expected"]
            if expected["ok"]:
                self.assertFalse(expected["value"]["execution_authority"])
                self.assertFalse(expected["value"]["production_actions_used"])

    def test_runtime_dependencies_have_no_live_engine_network_process_rng_or_oracle(self) -> None:
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
        self.assertTrue(imported <= {"__future__","copy","hashlib","pathlib","re","types","typing"}, imported)
        forbidden = (
            "GameState", "GameStateMachine", "BattleScene", "CardInstance", "PokemonSlot", "AIOpponent",
            "HeadlessMatchBridge", "HTTPClient", "HTTPRequest", "OS.execute", "subprocess", "random",
            "datetime", "perf_counter", "monotonic", "time.time", "Time.get_ticks", "eval(", "exec(",
            "D:\\ai\\code\\ptcgabc", "search_begin_input", "raw_private_hash", "token_free_callback_hash",
            "production_action\"", "expected_action", "engine_command", "execution_ticket",
        )
        for token in forbidden:
            self.assertNotIn(token, python_text)
            self.assertNotIn(token, godot_text)
        for resource in re.findall(r'(?:preload|load)\("(res://[^"]+)"\)', godot_text):
            self.assertTrue(resource.startswith("res://scripts/ai/ptcgdap/"), resource)

    def test_no_live_consumer_or_autoload_references_policy_owner(self) -> None:
        owners = {PYTHON_RUNTIME.resolve(), GODOT_RUNTIME.resolve()}
        offline_p5_wp7_consumers = {
            (ROOT / "scripts/ai/ptcgdap/marnie_portable_policy.py").resolve(),
            (ROOT / "scripts/ai/ptcgdap/public/MarniePortablePolicy.gd").resolve(),
        }
        needles = ("MarnieCapabilityPolicy", "marnie_capability_policy.py", "public/MarnieCapabilityPolicy.gd")
        matches: list[str] = []
        for base in (ROOT / "scripts", ROOT / "scenes"):
            if not base.exists():
                continue
            for path in base.rglob("*"):
                if (
                    not path.is_file()
                    or path.suffix.lower() not in {".py", ".gd", ".tscn", ".tres"}
                    or path.resolve() in owners
                    or path.resolve() in offline_p5_wp7_consumers
                ):
                    continue
                text = path.read_text(encoding="utf-8", errors="replace")
                if any(needle in text for needle in needles):
                    matches.append(path.relative_to(ROOT).as_posix())
        project = (ROOT / "project.godot").read_text(encoding="utf-8")
        self.assertFalse(matches, matches)
        self.assertTrue(all(path.is_file() for path in offline_p5_wp7_consumers))
        self.assertFalse(any(needle in project for needle in needles))

    def test_policy_contract_contains_no_private_identity_or_replay_action(self) -> None:
        serialized = "\n".join(
            canonical_json_v1_bytes(load_json_strict(path)).decode("utf-8")
            for path in (POLICY, VECTORS)
        )
        for token in (
            "search_begin_input", "raw_private_hash", "token_free_callback_hash", "container_path",
            "PRIVATE_MUTATION_SENTINEL", "LiveVideoPath", "TeamNames", "production_action\"",
            "expected_action", "engine_command", "execution_ticket",
        ):
            self.assertNotIn(token, serialized)


if __name__ == "__main__":
    unittest.main()
