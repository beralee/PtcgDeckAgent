from __future__ import annotations

import argparse
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
from types import ModuleType


SKILL_DIR = Path(__file__).resolve().parents[1]


def load_script(name: str) -> ModuleType:
    path = SKILL_DIR / "scripts" / f"{name}.py"
    spec = importlib.util.spec_from_file_location(f"skill_{name}", path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


INIT = load_script("init_strategy_run")
CLASSIFY = load_script("classify_strategic_failure")
AUDIT = load_script("audit_strategic_trace")
VERIFY = load_script("verify_candidate_contract")


def write(path: Path, content: str = "fixture\n") -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8", newline="\n")


def positive_trace() -> dict[str, object]:
    return {
        "schema_version": 2,
        "trace_id": "trace-1",
        "scene_id": "scene-1",
        "decision_id": "decision-1",
        "determinism_key": "det-1",
        "context_id": "ctx-1",
        "base_context_id": "base-ctx-1",
        "public_only": True,
        "opponent_belief": {"status": "unique", "candidates": ["marnie"]},
        "active_adapters": [
            {"id": "deck.core", "kind": "core", "activation": "always", "covers": []},
            {
                "id": "deck.marnie",
                "kind": "hard_matchup",
                "activation": "unique",
                "covers": ["marnie"],
            },
        ],
        "win_condition_weights": {"prize_race": 1.0},
        "goals": [{"id": "attack", "priority": 100, "source": "deck.core"}],
        "goal_modifiers": [],
        "goal_states": [],
        "threat_clock": {
            "own_attacks_to_win": 2,
            "opponent_attacks_to_win": 2,
            "goal_deadline_turn": 6,
            "confidence": 0.5,
            "source": "base.public_prize_clock",
            "context_id": "ctx-1",
        },
        "macro_intents": [],
        "dominance_constraints": [],
        "legal_action_ids": ["a", "b"],
        "strategic_action_ids": ["a", "b"],
        "mandatory_action_ids": [],
        "terminal_action_ids": [],
        "forbidden_reasons": [],
        "tactical_scores": {
            "a": {"total": 1.0, "components": {"target": 1.0}},
            "b": {"total": 0.0, "components": {}},
        },
        "future_evidence": {},
        "base_hard_tiers": {"a": [1, 0], "b": [1, 0]},
        "base_selected_action_id": "b",
        "tactical_preferred_action_id": "a",
        "tactical_override_applied": True,
        "base_vetoed_action_ids": [],
        "selected_action_id": "a",
        "fallback_reason": "",
        "execution_exam": {
            "action_order_required": False,
            "final_public_state_exact": True,
            "final_hand_exact": True,
        },
        "counterfactual_exam": {
            "separate_from_execution_score": True,
            "runtime_input": False,
        },
        "plan_memory": {"reused_constraints": False, "reused_scores": False},
        "audit_id": "audit-1",
    }


class InitStrategyRunTests(unittest.TestCase):
    def test_scaffold_declares_v18_owner_and_trace_contracts(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            for relative in INIT.REQUIRED_REPO_PATHS:
                write(root / relative)
            machine_contract = {
                "version": INIT.BASE_GRAPH_VERSION,
                "action_pipeline": [
                    "generate",
                    "strategic_context",
                    "legality_filter",
                    "goal_state_compile",
                    "macro_intent_compile",
                    "strategic_filter",
                    "tactical_score",
                    "future_evaluate",
                    "uncertainty_score",
                    "base_graph_select",
                    "transaction_execute",
                    "reobserve_replan",
                ],
                "base_authority": ["action_legality", "outcome_authority"],
                "adapter_authority": ["goal_priority", "tactical_tiebreak"],
                "invariants": ["public_only", "base_safety_has_final_veto"],
                "inherited_capabilities": list(INIT.V17_CAPABILITIES),
                "capabilities": list(INIT.V18_CAPABILITIES),
            }
            write(
                root / "strategy_graph/base_graph_v1_8_architecture_contract.json",
                json.dumps(machine_contract),
            )
            deck = root / "decks/fixed.csv"
            write(deck, "\n".join(str(value) for value in range(1, 61)) + "\n")
            args = argparse.Namespace(
                repo_root=root,
                run_id="fixture_v18",
                deck_id="fixture",
                deck_csv=Path("decks/fixed.csv"),
                candidate_dir=Path("agents/fixture_candidate"),
                champion_dir=None,
                training_seed=11,
                discovery_seed=22,
                confirmation_seed=33,
                artifacts_root=None,
            )
            run_dir, documents = INIT.build_documents(args)
            self.assertEqual(run_dir, root / "artifacts/architecture_runs/fixture_v18")
            architecture = json.loads(documents["architecture_contract.json"])
            manifest = json.loads(documents["candidate_manifest.json"])
            self.assertEqual(architecture["base_graph_version"], "1.8.0")
            self.assertIn("goal_state_machine", architecture["owner_layers"])
            self.assertIn("macro_intent", architecture["owner_layers"])
            self.assertIn("tactical_scorer", architecture["owner_layers"])
            self.assertEqual(manifest["runtime_class"], "BaseGraphRuntimeV18")
            self.assertTrue(manifest["strategic_trace_required"])
            self.assertFalse(manifest["tactical_cross_hard_tier"])
            self.assertTrue(manifest["hard_constraint_requires_public_dominance_proof"])
            self.assertEqual(manifest["future_horizon_turns"], 2)
            self.assertEqual(
                manifest["base_graph_v1_8_sha256"],
                INIT.sha256(root / "strategy_graph/base_graph_v1_8.py"),
            )
            self.assertIn("strategic_trace.jsonl", documents)


class FailureClassifierTests(unittest.TestCase):
    def test_declared_failure_routes_to_tactical_scorer(self) -> None:
        result = CLASSIFY.classify(
            {"failure_id": "f1", "failure_class": "same_hard_tier_misrank"},
            1,
        )
        self.assertEqual(result["owner_layer"], "tactical_scorer")
        self.assertEqual(result["learned_control"], "residual_only")
        self.assertTrue(result["resolved"])

    def test_earlier_legality_signal_wins(self) -> None:
        result = CLASSIFY.classify(
            {
                "failure_id": "f2",
                "signals": {
                    "invalid_action": True,
                    "same_base_hard_tier_misrank": True,
                },
            },
            1,
        )
        self.assertEqual(result["owner_layer"], "base_legality")

    def test_missing_evidence_is_unresolved(self) -> None:
        report = CLASSIFY.build_report([{"failure_id": "f3"}])
        self.assertFalse(report["ok"])
        self.assertEqual(report["unresolved_count"], 1)

    def test_goal_stage_and_macro_failures_have_distinct_owners(self) -> None:
        stage = CLASSIFY.classify(
            {"failure_id": "stage", "failure_class": "wrong_goal_stage"}, 1
        )
        macro = CLASSIFY.classify(
            {"failure_id": "macro", "failure_class": "missing_macro_intent"}, 2
        )
        self.assertEqual(stage["owner_layer"], "goal_state_machine")
        self.assertEqual(macro["owner_layer"], "macro_intent")

    def test_every_declared_failure_class_has_one_resolved_route(self) -> None:
        for ordinal, failure_class in enumerate(CLASSIFY.ROUTES, 1):
            with self.subTest(failure_class=failure_class):
                result = CLASSIFY.classify(
                    {"failure_id": failure_class, "failure_class": failure_class},
                    ordinal,
                )
                self.assertTrue(result["resolved"])
                self.assertNotEqual(result["owner_layer"], "unresolved")


class StrategicTraceAuditTests(unittest.TestCase):
    def test_positive_trace_passes(self) -> None:
        report = AUDIT.build_report([(1, positive_trace())])
        self.assertTrue(report["ok"], report)

    def test_ambiguous_hard_adapter_and_filtered_mandatory_fail(self) -> None:
        trace = positive_trace()
        trace["opponent_belief"] = {"status": "ambiguous", "candidates": ["a", "b"]}
        trace["mandatory_action_ids"] = ["b"]
        trace["strategic_action_ids"] = ["a"]
        trace["tactical_scores"] = {"a": {"total": 1.0, "components": {}}}
        report = AUDIT.build_report([(1, trace)])
        codes = {value["code"] for value in report["violations"]}
        self.assertIn("hard_adapter_without_unique_belief", codes)
        self.assertIn("mandatory_filtered", codes)

    def test_cross_hard_tier_takeover_fails(self) -> None:
        trace = positive_trace()
        trace["base_hard_tiers"] = {"a": [0], "b": [1]}
        report = AUDIT.build_report([(1, trace)])
        self.assertIn(
            "cross_hard_tier_tactical_takeover",
            {value["code"] for value in report["violations"]},
        )

    def test_repeated_input_drift_fails(self) -> None:
        first = positive_trace()
        second = positive_trace()
        second["selected_action_id"] = "b"
        second["tactical_override_applied"] = False
        second["audit_id"] = "audit-2"
        report = AUDIT.build_report([(1, first), (2, second)])
        self.assertIn(
            "deterministic_drift",
            {value["code"] for value in report["violations"]},
        )

    def test_v18_exam_and_dominance_boundaries_fail_closed(self) -> None:
        trace = positive_trace()
        trace["execution_exam"]["action_order_required"] = True
        trace["counterfactual_exam"]["runtime_input"] = True
        trace["dominance_constraints"] = [
            {
                "action_id": "b",
                "source": "deck.core",
                "context_id": "ctx-1",
                "certificate": {
                    "dominant_action_id": "a",
                    "dominated_action_id": "b",
                    "public_only": True,
                    "complete": False,
                    "context_id": "ctx-1",
                    "evidence_ids": ["fixture"],
                },
            }
        ]
        trace["strategic_action_ids"] = ["a"]
        trace["tactical_scores"] = {"a": {"total": 1.0, "components": {}}}
        report = AUDIT.build_report([(1, trace)])
        codes = {value["code"] for value in report["violations"]}
        self.assertIn("exam_requires_exact_action_order", codes)
        self.assertIn("counterfactual_exam_runtime_leak", codes)
        self.assertIn("unproven_dominance_constraint", codes)

    def test_remaining_safety_invariants_fail_closed(self) -> None:
        cases: list[tuple[str, callable, str]] = []

        def private_information(trace: dict[str, object]) -> None:
            trace["opponent_hand"] = [123]

        cases.append(("private", private_information, "private_information_key"))

        def robust_coverage(trace: dict[str, object]) -> None:
            trace["opponent_belief"] = {"status": "ambiguous", "candidates": ["a", "b"]}
            trace["active_adapters"] = [
                {"id": "deck.core", "kind": "core", "activation": "always", "covers": []},
                {
                    "id": "deck.robust",
                    "kind": "robust_matchup",
                    "activation": "ambiguous_robust",
                    "covers": ["a"],
                },
            ]

        cases.append(
            ("robust", robust_coverage, "incomplete_robust_adapter_coverage")
        )

        def strategic_outside_legal(trace: dict[str, object]) -> None:
            trace["strategic_action_ids"] = ["a", "b", "c"]
            scores = dict(trace["tactical_scores"])
            scores["c"] = {"total": 0.0, "components": {}}
            trace["tactical_scores"] = scores

        cases.append(("mask", strategic_outside_legal, "strategic_outside_legal"))

        def terminal_filtered(trace: dict[str, object]) -> None:
            trace["terminal_action_ids"] = ["b"]
            trace["strategic_action_ids"] = ["a"]
            trace["tactical_scores"] = {"a": {"total": 1.0, "components": {}}}

        cases.append(("terminal", terminal_filtered, "terminal_filtered"))

        def mandatory_forbidden(trace: dict[str, object]) -> None:
            trace["mandatory_action_ids"] = ["b"]
            trace["forbidden_reasons"] = [
                {
                    "action_id": "b",
                    "source": "deck.core",
                    "reason": "bad fixture",
                    "context_id": "ctx-1",
                }
            ]

        cases.append(("forbidden", mandatory_forbidden, "mandatory_forbidden"))

        def stale_constraint(trace: dict[str, object]) -> None:
            trace["forbidden_reasons"] = [
                {
                    "action_id": "b",
                    "source": "deck.core",
                    "reason": "stale fixture",
                    "context_id": "old-context",
                }
            ]

        cases.append(("stale", stale_constraint, "stale_constraint"))

        def future_legality(trace: dict[str, object]) -> None:
            trace["future_evidence"] = {"c": {"value": 1.0}}

        cases.append(("future", future_legality, "future_created_legality"))

        def base_veto(trace: dict[str, object]) -> None:
            trace["base_vetoed_action_ids"] = ["a"]

        cases.append(("veto", base_veto, "selected_base_vetoed"))

        def incomplete_fallback(trace: dict[str, object]) -> None:
            trace["strategic_action_ids"] = ["a"]
            trace["tactical_scores"] = {"a": {"total": 1.0, "components": {}}}
            trace["fallback_reason"] = "strategic_filter_all_removed_base_fallback"

        cases.append(
            ("fallback", incomplete_fallback, "incomplete_base_frontier_fallback")
        )

        for name, mutate, expected in cases:
            with self.subTest(name=name):
                trace = positive_trace()
                mutate(trace)
                report = AUDIT.build_report([(1, trace)])
                self.assertIn(expected, {value["code"] for value in report["violations"]})


class CandidateVerifierTests(unittest.TestCase):
    def test_valid_v18_candidate_passes_and_cross_tier_authority_fails(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            candidate = root / "agents/candidate"
            candidate.mkdir(parents=True)
            write(root / "strategy_graph/base_graph_v1_7.py", "base-v17\n")
            write(
                root / "strategy_graph/base_graph_v1_7_architecture_contract.json",
                "{}\n",
            )
            write(root / "strategy_graph/base_graph_v1_8.py", "base-v18\n")
            write(
                root / "strategy_graph/base_graph_v1_8_architecture_contract.json",
                "{}\n",
            )
            source = "\n".join(
                [
                    "GRAPH_FEATURES = frozenset([",
                    *(f"    {feature!r}," for feature in VERIFY.REQUIRED_FEATURES),
                    "])",
                    "controller = BaseGraphV18(adapters=())",
                    "runtime = BaseGraphRuntimeV18(policy=None, version='x', policy_version='x')",
                ]
            )
            write(candidate / "main.py", source + "\n")
            write(candidate / "deck.csv", "\n".join(str(value) for value in range(1, 61)) + "\n")
            manifest = {
                "architecture": VERIFY.REQUIRED_ARCHITECTURE,
                "base_graph_version": "1.8.0",
                "runtime_class": "BaseGraphRuntimeV18",
                "controller_class": "BaseGraphV18",
                "adapter_contract_version": "1.8.0",
                "adapters": [{"id": "deck.core", "kind": "core"}],
                "matchup_activation": {
                    "hard_requires_unique": True,
                    "ambiguous_requires_robust_coverage": True,
                },
                "owner_layers": sorted(VERIFY.REQUIRED_OWNER_LAYERS),
                "base_final_veto": True,
                "strategic_trace_schema_version": 2,
                "strategic_trace_required": True,
                "tactical_cross_hard_tier": False,
                "future_simulation_legality_authority": False,
                "future_horizon_turns": 2,
                "future_requires_uncertainty": True,
                "hard_constraint_requires_public_dominance_proof": True,
                "persistent_plan_reuses_constraints": False,
                "persistent_plan_reuses_scores": False,
                "execution_exam_action_order_required": False,
                "counterfactual_exam_separate": True,
                "base_graph_v1_7_sha256": VERIFY.sha256(
                    root / "strategy_graph/base_graph_v1_7.py"
                ),
                "base_graph_v1_7_contract_sha256": VERIFY.sha256(
                    root / "strategy_graph/base_graph_v1_7_architecture_contract.json"
                ),
                "base_graph_v1_8_sha256": VERIFY.sha256(
                    root / "strategy_graph/base_graph_v1_8.py"
                ),
                "base_graph_v1_8_contract_sha256": VERIFY.sha256(
                    root / "strategy_graph/base_graph_v1_8_architecture_contract.json"
                ),
                "strategy_dependencies": [],
                "imports_r121_or_r122_policy": False,
                "imports_other_deck_policy": False,
                "opponent_information": "public_only",
                "memorization_surface": [],
                "bc_mode": "disabled",
                "promotion_authorized": False,
                "submission_authorized": False,
                "main_sha256": VERIFY.sha256(candidate / "main.py"),
                "deck_sha256": VERIFY.sha256(candidate / "deck.csv"),
            }
            write(candidate / "candidate_manifest.json", json.dumps(manifest))
            result = VERIFY.validate(root, candidate)
            self.assertTrue(result["ok"], result)

            manifest["tactical_cross_hard_tier"] = True
            write(candidate / "candidate_manifest.json", json.dumps(manifest))
            result = VERIFY.validate(root, candidate)
            self.assertFalse(result["ok"])
            self.assertIn(
                "tactical_cross_hard_tier must be false",
                result["errors"],
            )


if __name__ == "__main__":
    unittest.main()
