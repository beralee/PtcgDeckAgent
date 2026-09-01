from __future__ import annotations

import ast
import hashlib
from pathlib import Path
import re
import unittest

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[2]
WORK_PACKAGE = ROOT / "artifacts/ptcgdap/p4_wp5/work_package.json"
FINAL_MANIFEST = ROOT / "artifacts/ptcgdap/p4_wp5/manifest.json"
PARENT_MANIFEST = ROOT / "artifacts/ptcgdap/p4_wp4/manifest.json"
CONTRACT_ROOT = ROOT / "contracts/ptcgdap"
PYTHON_RUNTIME = ROOT / "scripts/ai/ptcgdap/public_base_policy.py"
GODOT_RUNTIME = ROOT / "scripts/ai/ptcgdap/public/PublicBasePolicy.gd"
PARENT_RAW = "7BEF12014634888BE94B24FC7D962020D2ADF1AC2DD4307FC2728A66C4BFF660"
PARENT_CANONICAL = "BFD5FE2CA361720973085E792C02EBA2382FA1CA1ABCC767D440FAE7C40D6380"
PARENT_BUNDLE = "C80F4C4FDAEA5AC29BD3C5617BFAC72BE38709696F7EA1995D3D153113DD3CA1"
SOURCE_LOCK = "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"
CURRENT_BUNDLE = "18AAB663D9B429AC8657A75692F5DD8CF37C409CC057A328B57758C692FDB7F4"


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


class P4Wp5BoundaryTests(unittest.TestCase):
    def test_governance_parent_status_cursor_and_alignment_are_closed(self) -> None:
        work = load_json_strict(WORK_PACKAGE)
        if FINAL_MANIFEST.is_file():
            self.assertEqual(("shadow", "completed"), (work["status"], work["implementation_state"]))
            self.assertEqual("allowed", work["next_permitted_work"]["status"])
        else:
            self.assertEqual(("planned", "not_started"), (work["status"], work["implementation_state"]))
            self.assertEqual("proposed_only_after_p4_wp5_exit", work["next_permitted_work"]["status"])
        self.assertEqual("P4-WP6", work["next_permitted_work"]["work_package"])
        self.assertEqual(
            {"A0":"partial / not claimed","A1":"not evaluated","A2":"not evaluated","A3":"not evaluated","A4":"not evaluated","A5":"not evaluated"},
            work["alignment_claim"],
        )
        self.assertEqual(PARENT_RAW, sha(PARENT_MANIFEST.read_bytes()))
        self.assertEqual(PARENT_CANONICAL, sha(canonical_json_v1_bytes(load_json_strict(PARENT_MANIFEST))))
        self.assertEqual(PARENT_BUNDLE, work["entry_evidence"]["parent_bundle_canonical_sha256"])
        self.assertEqual(SOURCE_LOCK, work["entry_evidence"]["source_lock_canonical_sha256"])

    def test_contract_freezes_atomic_stage_order_and_base_authority(self) -> None:
        profile = load_json_strict(CONTRACT_ROOT / "public_base_policy_profile.json")
        bundle = load_json_strict(CONTRACT_ROOT / "public_base_policy_bundle.json")
        self.assertEqual(CURRENT_BUNDLE, sha(canonical_json_v1_bytes(bundle)))
        self.assertEqual(PARENT_BUNDLE, profile["parent_bundle_canonical_sha256"])
        contract = profile["orchestration_contract"]
        self.assertEqual(7, len(contract["fixed_stage_order"]))
        self.assertEqual("no_partial_proposal_execution_resolution_decision_or_trace", contract["failure_atomicity"])
        self.assertTrue(contract["executor_output_revalidated_by_current_window_sanitizer"])
        self.assertTrue(contract["mandatory_terminal_precedes_hard_tier"])
        self.assertEqual("same_base_tier_ordering_hint_only", contract["adapter_authority"])
        self.assertFalse(profile["result_contract"]["serialized_result_is_execution_authority"])
        self.assertFalse(profile["scope"]["time_budget_telemetry"])
        self.assertFalse(profile["scope"]["live_owner"])

    def test_runtime_dependency_boundary_has_no_engine_network_process_or_dynamic_code(self) -> None:
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
        self.assertTrue(imported <= {"__future__", "copy", "dataclasses", "hashlib", "pathlib", "re", "types", "typing"}, imported)
        forbidden = (
            "GameState", "GameStateMachine", "BattleScene", "CardInstance", "PokemonSlot", "AIOpponent",
            "HeadlessMatchBridge", "ShadowWholeMatchHarness", "HTTPClient", "HTTPRequest", "OS.execute",
            "subprocess", "random", "eval(", "exec(", "D:\\ai\\code\\ptcgabc",
        )
        for token in forbidden:
            self.assertNotIn(token, python_text)
            self.assertNotIn(token, godot_text)
        resource_pattern = re.compile(r'(?:preload|load)\("(res://[^"]+)"\)')
        for resource_path in resource_pattern.findall(godot_text):
            self.assertTrue(resource_path.startswith("res://scripts/ai/ptcgdap/"), resource_path)

    def test_no_live_consumer_or_autoload_references_orchestrator(self) -> None:
        owner_paths = {
            PYTHON_RUNTIME.resolve(),
            GODOT_RUNTIME.resolve(),
            (ROOT / "scripts/ai/ptcgdap/marnie_public_base.py").resolve(),
            (ROOT / "scripts/ai/ptcgdap/public/MarniePublicBase.gd").resolve(),
            (ROOT / "scripts/ai/ptcgdap/author_strategy_match_host.py").resolve(),
            (ROOT / "scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorMatchHost.gd").resolve(),
        }
        needles = (
            "PublicBasePolicyOrchestrator",
            "PublicBasePolicyCore",
            "public_base_policy.py",
            "public/PublicBasePolicy.gd",
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

    def test_orchestrator_owns_no_deck_strategy_model_time_or_execution_ticket(self) -> None:
        combined = PYTHON_RUNTIME.read_text(encoding="utf-8") + "\n" + GODOT_RUNTIME.read_text(encoding="utf-8")
        for token in (
            "DeckStrategy", "model_path", "weights", "time_budget", "deadline", "ActionTicket",
            "execute_ticket", "canary", "active_rollout", "Kaggle", "PlayerState",
        ):
            self.assertNotIn(token, combined)

    def test_authoritative_docs_keep_p4_wp5_offline_and_next_exact(self) -> None:
        combined = "\n".join(
            (ROOT / path).read_text(encoding="utf-8")
            for path in (
                "docs/ptcgdap/README.md",
                "docs/ptcgdap/01-official-cabt-contract.md",
                "docs/ptcgdap/03-target-architecture.md",
                "docs/ptcgdap/04-migration-roadmap.md",
                "docs/ptcgdap/05-validation-promotion-and-rollback.md",
                "docs/ptcgdap/06-first-vertical-slice.md",
                "docs/ptcgdap/07-decisions-risks-and-open-questions.md",
                "docs/ptcgdap/STATUS.md",
                "docs/ptcgdap/IMPLEMENTATION_CHECKLIST.md",
            )
        )
        self.assertIn("P4-WP5", combined if FINAL_MANIFEST.is_file() else WORK_PACKAGE.read_text(encoding="utf-8"))
        self.assertIn("P4-WP6", combined if FINAL_MANIFEST.is_file() else WORK_PACKAGE.read_text(encoding="utf-8"))
        self.assertIn("A0 partial / not claimed", combined)
        self.assertIn("A5", combined)


if __name__ == "__main__":
    unittest.main()
