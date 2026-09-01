from __future__ import annotations

import ast
import hashlib
from pathlib import Path
import unittest

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict
from tests.ptcgdap.test_as_wp5_parent_snapshot import AS_WP5_APPROVED_SUCCESSOR_RUNTIME_PATHS


ROOT = Path(__file__).resolve().parents[2]
WORK_PACKAGE_PATH = ROOT / "artifacts/ptcgdap/p4_wp1/work_package.json"
FINAL_MANIFEST_PATH = ROOT / "artifacts/ptcgdap/p4_wp1/manifest.json"
PARENT_MANIFEST_PATH = ROOT / "artifacts/ptcgdap/p3_wp8/manifest.json"
CONTRACT_ROOT = ROOT / "contracts/ptcgdap"
PYTHON_RUNTIME = ROOT / "scripts/ai/ptcgdap/strategic_context_v18.py"
GODOT_RUNTIME = ROOT / "scripts/ai/ptcgdap/public/StrategicContextV18.gd"
EXPECTED_PARENT_RAW = "E4FC0A98E75AA40BC6243076C2163F28D3B6BBF39C6C9011950DAACC8552E274"
EXPECTED_PARENT_CANONICAL = "E44B6DE0DD52C9357BE96F44D6C9B8C1A799D51C747660007C53E9BEB055BF25"
EXPECTED_BUNDLE_CANONICAL = "AACFA7E2E7F914180A2B7A5C4D92D6514ACC5F4622FC95B57DC225673893F98F"
EXPECTED_SOURCE_LOCK_CANONICAL = "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"
EXPECTED_FIREWALL_CANONICAL = "A2781CE6B3AC7BB6BAD04A9F15F57CE23AEC338306F60E5B3050B31245685947"
EXPECTED_SELECTION_CANONICAL = "2CD02F54538985426EFDB057F3A6BDA4AD154DD171BCC03667D42D102982D294"
EXPECTED_WHOLE_MATCH_CANONICAL = "0C5A8FDAB61A73F623EA6B0D364C38E6C4797087287B3DF3C88D0191261296B5"
EXPECTED_OWNER_PATHS = {
    "contracts/ptcgdap/strategic_context_v18.schema.json",
    "contracts/ptcgdap/strategic_context_v18_profile.json",
    "contracts/ptcgdap/strategic_context_v18_conformance_vectors.json",
    "contracts/ptcgdap/strategic_context_v18_bundle.json",
    "scripts/ai/ptcgdap/strategic_context_v18.py",
    "scripts/ai/ptcgdap/public/StrategicContextV18.gd",
    "tools/ptcgdap/build_strategic_context_v18_contract.py",
    "tests/ptcgdap/test_strategic_context_v18_contract_builder.py",
    "tests/ptcgdap/test_strategic_context_v18.py",
    "tests/ptcgdap/test_strategic_context_v18_properties.py",
    "tests/ptcgdap/test_p4_wp1_boundaries.py",
    "tests/ptcgdap/test_p4_wp1_parent_snapshot.py",
    "tests/ptcgdap/godot/test_strategic_context_v18.gd",
}


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def canonical(path: Path) -> str:
    return sha(canonical_json_v1_bytes(load_json_strict(path)))


class P4Wp1BoundaryTests(unittest.TestCase):
    def test_governance_scope_status_parent_and_cursor_are_closed(self) -> None:
        work = load_json_strict(WORK_PACKAGE_PATH)
        self.assertEqual(work["entry_evidence"]["parent_manifest_raw_sha256"], EXPECTED_PARENT_RAW)
        self.assertEqual(work["entry_evidence"]["parent_manifest_canonical_sha256"], EXPECTED_PARENT_CANONICAL)
        self.assertEqual(work["entry_evidence"]["parent_candidate_entry_count"], 680)
        self.assertEqual(
            work["entry_evidence"]["parent_candidate_canonical_sha256"],
            "1F1F5459A57842CD5A04015AE9FD853D8AEC3ED99DA832D4FBA55415FB22B849",
        )
        self.assertTrue(work["contracts_changed"])
        self.assertEqual(work["shadow_or_live"], "shadow, offline-only public contract core")
        self.assertEqual(work["alignment_claim"]["A0"], "partial / not claimed")
        self.assertTrue(all(work["alignment_claim"][level] == "not evaluated" for level in ("A1", "A2", "A3", "A4", "A5")))
        self.assertEqual(
            work["next_permitted_work"],
            {
                "work_package": "P4-WP2",
                "title": "Strategic Trace v2 and restricted Base Graph IR contract",
                "status": "allowed",
            },
        )
        owner_paths = set().union(
            work["files_allowed"]["contracts"],
            work["files_allowed"]["implementation"],
            work["files_allowed"]["tests"],
        )
        self.assertEqual(owner_paths, EXPECTED_OWNER_PATHS)
        if FINAL_MANIFEST_PATH.exists():
            self.assertEqual((work["status"], work["implementation_state"]), ("shadow", "completed"))
            self.assertEqual(load_json_strict(FINAL_MANIFEST_PATH)["status"], "shadow")
        else:
            self.assertEqual((work["status"], work["implementation_state"]), ("planned", "not_started"))

    def test_parent_and_existing_contract_authority_remain_byte_identical(self) -> None:
        self.assertEqual(sha(PARENT_MANIFEST_PATH.read_bytes()), EXPECTED_PARENT_RAW)
        self.assertEqual(canonical(PARENT_MANIFEST_PATH), EXPECTED_PARENT_CANONICAL)
        self.assertEqual(canonical(CONTRACT_ROOT / "cabt_contract_bundle.json"), EXPECTED_SELECTION_CANONICAL)
        self.assertEqual(canonical(CONTRACT_ROOT / "cabt_public_firewall_bundle.json"), EXPECTED_FIREWALL_CANONICAL)
        self.assertEqual(canonical(CONTRACT_ROOT / "shadow_whole_match_harness_bundle.json"), EXPECTED_WHOLE_MATCH_CANONICAL)
        self.assertEqual(canonical(ROOT / "docs/ptcgdap/SOURCE_LOCK.json"), EXPECTED_SOURCE_LOCK_CANONICAL)

    def test_new_bundle_is_exact_subordinate_and_has_no_self_cycle(self) -> None:
        bundle = load_json_strict(CONTRACT_ROOT / "strategic_context_v18_bundle.json")
        self.assertEqual(canonical(CONTRACT_ROOT / "strategic_context_v18_bundle.json"), EXPECTED_BUNDLE_CANONICAL)
        self.assertEqual(bundle["source_lock_canonical_sha256"], EXPECTED_SOURCE_LOCK_CANONICAL)
        self.assertEqual(bundle["public_firewall_bundle_canonical_sha256"], EXPECTED_FIREWALL_CANONICAL)
        self.assertEqual(bundle["selection_contract_bundle_canonical_sha256"], EXPECTED_SELECTION_CANONICAL)
        expected = {
            "schema": "strategic_context_v18.schema.json",
            "profile": "strategic_context_v18_profile.json",
            "vectors": "strategic_context_v18_conformance_vectors.json",
        }
        self.assertEqual([entry["id"] for entry in bundle["artifacts"]], list(expected))
        for entry in bundle["artifacts"]:
            self.assertEqual(entry["path"], f"contracts/ptcgdap/{expected[entry['id']]}")
            self.assertEqual(entry["canonical_sha256"], canonical(CONTRACT_ROOT / expected[entry["id"]]))
            self.assertNotEqual(entry["canonical_sha256"], EXPECTED_BUNDLE_CANONICAL)
        serialized = canonical_json_v1_bytes(bundle).decode("utf-8")
        self.assertNotIn(EXPECTED_BUNDLE_CANONICAL, serialized)

    def test_python_and_godot_runtime_dependencies_stay_public_and_pure(self) -> None:
        python_text = PYTHON_RUNTIME.read_text(encoding="utf-8")
        godot_text = GODOT_RUNTIME.read_text(encoding="utf-8")
        tree = ast.parse(python_text)
        imported: set[str] = set()
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                imported.update(alias.name for alias in node.names)
            elif isinstance(node, ast.ImportFrom):
                imported.add(node.module or "")
        allowed_roots = {"__future__", "copy", "dataclasses", "hashlib", "pathlib", "types", "typing"}
        allowed_relative = {"cabt_selection", "cabt_tree_hash", "public_observation_firewall", "source_lock"}
        self.assertTrue(
            all(
                name.startswith("scripts.ai.ptcgdap")
                or name.split(".")[0] in allowed_roots
                or name in allowed_relative
                or name == ""
                for name in imported
            ),
            imported,
        )
        forbidden = (
            "GameState",
            "GameStateMachine",
            "BattleScene",
            "CardInstance",
            "PokemonSlot",
            "AIOpponent",
            "HeadlessMatchBridge",
            "DeckStrategy",
            "ptcgabc",
            "subprocess",
            "socket",
            "requests",
            "urllib",
            "random",
        )
        for token in forbidden:
            self.assertNotIn(token, python_text)
            self.assertNotIn(token, godot_text)
        self.assertNotIn("FileAccess.WRITE", godot_text)
        self.assertNotIn("store_", godot_text)
        self.assertNotIn("HTTPClient", godot_text)
        self.assertNotIn("OS.execute", godot_text)
        for denylisted_key in ("search_begin_input", "token_free_callback_hash", "raw_private_hash"):
            self.assertEqual(python_text.count(denylisted_key), 1)
            self.assertEqual(godot_text.count(denylisted_key), 1)

    def test_no_live_consumer_or_autoload_can_observe_new_dtos(self) -> None:
        owner_paths = {
            PYTHON_RUNTIME.resolve(),
            GODOT_RUNTIME.resolve(),
            (ROOT / "scripts/ai/ptcgdap/strategic_trace_v2.py").resolve(),
            (ROOT / "scripts/ai/ptcgdap/public/StrategicTraceV2.gd").resolve(),
            (ROOT / "scripts/ai/ptcgdap/restricted_base_graph_executor.py").resolve(),
            (ROOT / "scripts/ai/ptcgdap/public/RestrictedBaseGraphExecutor.gd").resolve(),
            (ROOT / "scripts/ai/ptcgdap/public_deck_adapter.py").resolve(),
            (ROOT / "scripts/ai/ptcgdap/public/PublicDeckAdapter.gd").resolve(),
            (ROOT / "scripts/ai/ptcgdap/public_base_policy.py").resolve(),
            (ROOT / "scripts/ai/ptcgdap/public/PublicBasePolicy.gd").resolve(),
            (ROOT / "scripts/ai/ptcgdap/marnie_public_base.py").resolve(),
            (ROOT / "scripts/ai/ptcgdap/public/MarniePublicBase.gd").resolve(),
            (ROOT / "scripts/ai/ptcgdap/host/godot/AuthorStrategyShadowPrompt.gd").resolve(),
        }
        needles = (
            "StrategicContextV18ContractCore",
            "PolicyDecisionFactory",
            "strategic_context_v18.py",
            "public/StrategicContextV18.gd",
        )
        matches: list[str] = []
        for base in (ROOT / "scripts", ROOT / "scenes"):
            if not base.exists():
                continue
            for path in base.rglob("*"):
                if not path.is_file() or path.suffix.lower() not in {".py", ".gd", ".tscn", ".tres"} or path.resolve() in owner_paths:
                    continue
                relative = path.relative_to(ROOT).as_posix()
                if relative in AS_WP5_APPROVED_SUCCESSOR_RUNTIME_PATHS:
                    continue
                text = path.read_text(encoding="utf-8", errors="replace")
                if any(needle in text for needle in needles):
                    matches.append(relative)
        project_text = (ROOT / "project.godot").read_text(encoding="utf-8")
        self.assertFalse(matches, matches)
        self.assertFalse(any(needle in project_text for needle in needles))

    def test_shared_vectors_lock_public_visibility_order_and_closed_errors(self) -> None:
        vectors = load_json_strict(CONTRACT_ROOT / "strategic_context_v18_conformance_vectors.json")
        profile = load_json_strict(CONTRACT_ROOT / "strategic_context_v18_profile.json")
        self.assertEqual(len(vectors["context_rejections"]), 7)
        self.assertEqual(len(vectors["decision_cases"]), 4)
        self.assertEqual(len(vectors["decision_rejections"]), 4)
        expected = vectors["fixture"]["expected_context"]
        self.assertIsInstance(expected["public_state"]["acting_player"]["hand"], list)
        self.assertIsNone(expected["public_state"]["opponent_player"]["hand"])
        self.assertEqual(
            [item["index"] for item in expected["select_semantics"]["options"]],
            list(range(expected["source"]["option_count"])),
        )
        self.assertFalse(profile["decision_contract"]["serialized_result_is_execution_authority"])
        self.assertIn("never authorizes", profile["decision_contract"]["consumer_rule"])
        self.assertEqual(
            set(profile["stable_error_codes"]),
            {case["expected_error_code"] for case in vectors["context_rejections"] + vectors["decision_rejections"]}
            | {"contract_error", "context_integrity_invalid", "decision_integrity_invalid"},
        )

    def test_architecture_cursor_and_completion_claim_remain_truthful(self) -> None:
        docs = {
            path.name: path.read_text(encoding="utf-8")
            for path in (
                ROOT / "docs/ptcgdap/README.md",
                ROOT / "docs/ptcgdap/STATUS.md",
                ROOT / "docs/ptcgdap/IMPLEMENTATION_CHECKLIST.md",
                ROOT / "docs/ptcgdap/04-migration-roadmap.md",
            )
        }
        joined = "\n".join(docs.values())
        if FINAL_MANIFEST_PATH.exists():
            self.assertIn("P4-WP2", docs["STATUS.md"])
            self.assertIn(EXPECTED_BUNDLE_CANONICAL, joined)
        else:
            self.assertIn("P4-WP1", docs["STATUS.md"])
        for prohibited_claim in (
            "A0 complete",
            "A1 passed",
            "A2 passed",
            "A3 passed",
            "A4 passed",
            "A5 passed",
            "P4 complete",
        ):
            self.assertNotIn(prohibited_claim, joined)


if __name__ == "__main__":
    unittest.main()
