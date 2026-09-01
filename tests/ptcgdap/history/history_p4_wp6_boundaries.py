from __future__ import annotations

import ast
import hashlib
from pathlib import Path
import re
import unittest

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[2]
WORK_PACKAGE = ROOT / "artifacts/ptcgdap/p4_wp6/work_package.json"
FINAL_MANIFEST = ROOT / "artifacts/ptcgdap/p4_wp6/manifest.json"
PARENT_MANIFEST = ROOT / "artifacts/ptcgdap/p4_wp5/manifest.json"
CONTRACT_ROOT = ROOT / "contracts/ptcgdap"
PYTHON_RUNTIME = ROOT / "scripts/ai/ptcgdap/public_policy_budget.py"
GODOT_RUNTIME = ROOT / "scripts/ai/ptcgdap/public/PublicPolicyBudget.gd"
PARENT_RAW = "B93FBCD2F3DF67692B6D2CD9F6F7FED99002783672A9C7055DF6AD3BBB368E2B"
PARENT_CANONICAL = "E013989E65D3148EDAFA50045BB6C3E25AA79E1B14217DBCF2D76BB9BCB1CD71"
PARENT_BUNDLE = "18AAB663D9B429AC8657A75692F5DD8CF37C409CC057A328B57758C692FDB7F4"
SOURCE_LOCK = "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"
CURRENT_BUNDLE = "0D82BDE31BD0FA0C44527880D9D6451C2733702913708532C512F3BFF81D8BF9"


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


class P4Wp6BoundaryTests(unittest.TestCase):
    def test_governance_parent_status_cursor_and_alignment_are_closed(self) -> None:
        work = load_json_strict(WORK_PACKAGE)
        if FINAL_MANIFEST.is_file():
            self.assertEqual(("shadow", "completed"), (work["status"], work["implementation_state"]))
            self.assertEqual("allowed", work["next_permitted_work"]["status"])
        else:
            self.assertEqual(("planned", "not_started"), (work["status"], work["implementation_state"]))
            self.assertEqual("proposed_only_after_p4_wp6_exit", work["next_permitted_work"]["status"])
        self.assertEqual("P5-WP1", work["next_permitted_work"]["work_package"])
        self.assertEqual(
            {"A0":"partial / not claimed","A1":"not evaluated","A2":"not evaluated","A3":"not evaluated","A4":"not evaluated","A5":"not evaluated"},
            work["alignment_claim"],
        )
        self.assertEqual(PARENT_RAW, sha(PARENT_MANIFEST.read_bytes()))
        self.assertEqual(PARENT_CANONICAL, sha(canonical_json_v1_bytes(load_json_strict(PARENT_MANIFEST))))
        self.assertEqual(PARENT_BUNDLE, work["entry_evidence"]["parent_bundle_canonical_sha256"])
        self.assertEqual(SOURCE_LOCK, work["entry_evidence"]["source_lock_canonical_sha256"])

    def test_contract_freezes_budget_capability_precedence_and_non_authority(self) -> None:
        profile = load_json_strict(CONTRACT_ROOT / "public_policy_budget_profile.json")
        bundle = load_json_strict(CONTRACT_ROOT / "public_policy_budget_bundle.json")
        self.assertEqual(CURRENT_BUNDLE, sha(canonical_json_v1_bytes(bundle)))
        self.assertEqual(PARENT_BUNDLE, profile["parent_bundle_canonical_sha256"])
        budget = profile["budget_contract"]
        self.assertEqual((600000, 30000, 5000), (
            budget["total_match_budget_ms"], budget["base_only_at_or_below_remaining_ms"], budget["fallback_at_or_below_remaining_ms"],
        ))
        self.assertEqual(["full", "base_only", "deterministic_fallback"], budget["modes"])
        capabilities = profile["capability_contract"]
        self.assertEqual(3, len(capabilities["required"]))
        self.assertEqual(3, len(capabilities["optional"]))
        self.assertEqual("same_current_window_deterministic_fallback_without_name_echo", capabilities["unknown_name_behavior"])
        self.assertFalse(profile["serialization_contract"]["ledger_and_result_are_execution_authority"])
        self.assertFalse(profile["serialization_contract"]["unknown_capability_names_are_serialized"])
        self.assertTrue(profile["serialization_contract"]["consumer_must_revalidate_exact_window"])

    def test_runtime_dependency_boundary_has_no_clock_engine_network_process_rng_or_dynamic_code(self) -> None:
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
        self.assertTrue(imported <= {"__future__", "copy", "dataclasses", "hashlib", "pathlib", "re", "types", "typing", "scripts"}, imported)
        forbidden = (
            "GameState", "GameStateMachine", "BattleScene", "CardInstance", "PokemonSlot", "AIOpponent",
            "HeadlessMatchBridge", "ShadowWholeMatchHarness", "HTTPClient", "HTTPRequest", "OS.execute",
            "subprocess", "random", "datetime", "perf_counter", "monotonic", "time.time", "Time.get_ticks",
            "OS.get_ticks", "eval(", "exec(", "D:\\ai\\code\\ptcgabc", "search_begin_input",
            "token_free_callback_hash", "raw_private_hash",
        )
        for token in forbidden:
            self.assertNotIn(token, python_text)
            self.assertNotIn(token, godot_text)
        resource_pattern = re.compile(r'(?:preload|load)\("(res://[^"]+)"\)')
        for resource_path in resource_pattern.findall(godot_text):
            self.assertTrue(resource_path.startswith("res://scripts/ai/ptcgdap/"), resource_path)

    def test_no_live_consumer_or_autoload_references_budget_core(self) -> None:
        owner_paths = {PYTHON_RUNTIME.resolve(), GODOT_RUNTIME.resolve()}
        needles = (
            "PublicPolicyBudgetController", "PublicPolicyBudgetCore", "public_policy_budget.py", "public/PublicPolicyBudget.gd",
        )
        matches: list[str] = []
        for base in (ROOT / "scripts", ROOT / "scenes"):
            if not base.exists():
                continue
            for path in base.rglob("*"):
                if not path.is_file() or path.suffix.lower() not in {".py", ".gd", ".tscn", ".tres"} or path.resolve() in owner_paths:
                    continue
                text = path.read_text(encoding="utf-8", errors="replace")
                if any(needle in text for needle in needles):
                    matches.append(path.relative_to(ROOT).as_posix())
        project = (ROOT / "project.godot").read_text(encoding="utf-8")
        self.assertFalse(matches, matches)
        self.assertFalse(any(needle in project for needle in needles))

    def test_unknown_capabilities_and_private_names_never_enter_serialized_vectors(self) -> None:
        vectors = load_json_strict(CONTRACT_ROOT / "public_policy_budget_conformance_vectors.json")
        unknown = next(value for value in vectors["step_cases"] if value["id"] == "unknown-capability")
        serialized = canonical_json_v1_bytes(unknown["expected_result"]).decode("utf-8")
        self.assertNotIn("vendor.future_capability", serialized)
        self.assertNotIn("PRIVATE", serialized)
        self.assertEqual(1, unknown["expected_result"]["unknown_capability_count"])
        self.assertEqual("deterministic_fallback", unknown["expected_result"]["mode"])
        self.assertEqual([0], unknown["expected_result"]["selected_indexes"])

    def test_authoritative_docs_keep_p4_wp6_offline_and_next_exact(self) -> None:
        combined = "\n".join(
            (ROOT / path).read_text(encoding="utf-8")
            for path in (
                "docs/ptcgdap/README.md", "docs/ptcgdap/01-official-cabt-contract.md",
                "docs/ptcgdap/03-target-architecture.md", "docs/ptcgdap/04-migration-roadmap.md",
                "docs/ptcgdap/05-validation-promotion-and-rollback.md", "docs/ptcgdap/06-first-vertical-slice.md",
                "docs/ptcgdap/07-decisions-risks-and-open-questions.md", "docs/ptcgdap/STATUS.md",
                "docs/ptcgdap/IMPLEMENTATION_CHECKLIST.md",
            )
        )
        source = combined if FINAL_MANIFEST.is_file() else WORK_PACKAGE.read_text(encoding="utf-8")
        self.assertIn("P4-WP6", source)
        self.assertIn("P5-WP1", source)
        self.assertIn("A0 partial / not claimed", combined)
        self.assertIn("A5", combined)


if __name__ == "__main__":
    unittest.main()
