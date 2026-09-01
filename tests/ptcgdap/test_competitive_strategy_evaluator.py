from __future__ import annotations

import copy
import unittest
from pathlib import Path

from scripts.ai.ptcgdap.competitive_strategy_evaluator import (
    CspEvaluatorError,
    CspEvaluatorOwner,
    build_replay_fixture,
    build_serial_evaluation_plan,
    build_unsigned_evidence,
)


ROOT = Path(__file__).resolve().parents[2]
FIXTURE_PRIVATE_KEY = bytes.fromhex(
    "9D61B19DEFFD5A60BA844AF492EC2CC4"
    "4449C5697B326919703BAC031CAE7F60"
)


class CompetitiveStrategyEvaluatorTests(unittest.TestCase):
    def setUp(self) -> None:
        self.owner = CspEvaluatorOwner.load_trusted(ROOT)

    def _record(
        self,
        match_id: str,
        *,
        target_seat: int,
        outcome: str,
        winner_seat: int | None,
        faults: dict[str, int] | None = None,
        runtime_dirty_reasons: list[str] | None = None,
    ) -> dict:
        replay = build_replay_fixture(self.owner, match_id, target_seat)
        evidence = build_unsigned_evidence(
            self.owner,
            replay,
            reported_outcome=outcome,
            winner_seat=winner_seat,
            fault_counts=faults,
            runtime_dirty_reasons=runtime_dirty_reasons,
        )
        return self.owner.issue_record(evidence, FIXTURE_PRIVATE_KEY, replay["frames"])

    def test_trusted_profile_and_test_only_evaluator_authority_are_exact(self) -> None:
        audit = self.owner.audit_snapshot()
        self.assertEqual(audit["authority_mode"], "shadow_test_only")
        self.assertEqual(audit["evaluator_id"], "ptcgdap-csp-wp2-shadow-evaluator")
        self.assertEqual(audit["key_id"], "csp-wp2-rfc8032-fixture-key")
        self.assertFalse(audit["production_authority"])
        self.assertFalse(audit["authoritative"])
        self.assertEqual(audit["grants"], [])

        plan = build_serial_evaluation_plan(self.owner, "wp2-serial-batch", 2)
        self.assertEqual(plan["execution_mode"], "serial_only")
        self.assertEqual([row["serial_ordinal"] for row in plan["matches"]], [0, 1, 2, 3])
        self.assertEqual([row["target_seat"] for row in plan["matches"]], [0, 1, 0, 1])
        self.assertEqual(plan["matches"][0]["seed_commitment_sha256"], plan["matches"][1]["seed_commitment_sha256"])
        self.assertEqual(plan["matches"][2]["seed_commitment_sha256"], plan["matches"][3]["seed_commitment_sha256"])
        self.assertNotEqual(plan["matches"][0]["seed_commitment_sha256"], plan["matches"][2]["seed_commitment_sha256"])

    def test_signed_records_materialize_deterministically_with_faults_and_dirty_visible(self) -> None:
        zero = {key: 0 for key in self.owner.fault_keys()}
        invalid = dict(zero, invalid_output=1)
        fallback = dict(zero, fallback=1)
        records = [
            self._record("wp2-match-001", target_seat=0, outcome="seat_0_win", winner_seat=0),
            self._record("wp2-match-002", target_seat=1, outcome="seat_1_win", winner_seat=1),
            self._record(
                "wp2-match-003",
                target_seat=0,
                outcome="seat_0_win",
                winner_seat=0,
                faults=invalid,
            ),
            self._record("wp2-match-004", target_seat=1, outcome="draw", winner_seat=None),
            self._record(
                "wp2-match-005",
                target_seat=0,
                outcome="seat_0_win",
                winner_seat=0,
                faults=fallback,
            ),
        ]
        summary = self.owner.materialize(records)
        reversed_summary = self.owner.materialize(list(reversed(records)))
        self.assertEqual(summary, reversed_summary)
        self.assertEqual(summary["input_match_ids"], sorted(summary["input_match_ids"]))
        self.assertEqual(
            summary["counts"],
            {"wins": 2, "losses": 1, "draws": 1, "valid": 4, "dirty": 1},
        )
        self.assertEqual(summary["fault_counts"]["invalid_output"], 1)
        self.assertEqual(summary["fault_counts"]["fallback"], 1)
        self.assertEqual(summary["win_rate_basis_points"], 5000)
        self.assertEqual(
            summary["seat_breakdown"],
            [
                {"seat": 0, "wins": 1, "losses": 1, "draws": 0},
                {"seat": 1, "wins": 1, "losses": 0, "draws": 1},
            ],
        )
        self.assertEqual(records[2]["result"]["outcome"], "seat_1_win")
        self.assertEqual(records[4]["result"]["trust_lane"], "rejected_or_dirty")
        self.assertIsNone(records[4]["result"]["verification"])

    def test_signature_evidence_profile_release_lane_and_duplicate_tamper_fail_closed(self) -> None:
        record = self._record(
            "wp2-tamper-001", target_seat=0, outcome="seat_0_win", winner_seat=0
        )
        mutations: list[tuple[str, dict]] = []
        bad_signature = copy.deepcopy(record)
        bad_signature["result"]["verification"]["signature"] = "00" * 64
        mutations.append(("result_signature_invalid", bad_signature))
        bad_evidence = copy.deepcopy(record)
        bad_evidence["evidence"]["runtime_report"]["decision_count"] += 1
        mutations.append(("evidence_signature_invalid", bad_evidence))
        bad_profile = copy.deepcopy(record)
        bad_profile["evidence"]["evaluation_profile_sha256"] = "A" * 64
        mutations.append(("evaluation_profile_mismatch", bad_profile))
        for expected, value in mutations:
            with self.subTest(expected=expected):
                with self.assertRaisesRegex(CspEvaluatorError, expected):
                    self.owner.verify_record(value)

        with self.assertRaisesRegex(CspEvaluatorError, "duplicate_match_id"):
            self.owner.materialize([record, copy.deepcopy(record)])
        with self.assertRaisesRegex(CspEvaluatorError, "evaluation_inputs_empty"):
            self.owner.materialize([])

        incomplete = copy.deepcopy(record)
        incomplete["evidence"]["replay_manifest"]["complete"] = False
        with self.assertRaisesRegex(CspEvaluatorError, "replay_incomplete"):
            self.owner.verify_record(incomplete)

        developer = build_replay_fixture(
            self.owner, "wp2-developer-lane", 0, lane="developer_local"
        )
        evidence = build_unsigned_evidence(
            self.owner, developer, reported_outcome="seat_0_win", winner_seat=0
        )
        with self.assertRaisesRegex(CspEvaluatorError, "match_lane_invalid"):
            self.owner.issue_record(evidence, FIXTURE_PRIVATE_KEY, developer["frames"])

    def test_wrong_private_key_and_historical_benchmark_source_cannot_issue(self) -> None:
        replay = build_replay_fixture(self.owner, "wp2-wrong-key", 0)
        evidence = build_unsigned_evidence(
            self.owner, replay, reported_outcome="seat_0_win", winner_seat=0
        )
        with self.assertRaisesRegex(CspEvaluatorError, "replay_frames_required"):
            self.owner.issue_record(evidence, FIXTURE_PRIVATE_KEY)
        tampered_frames = copy.deepcopy(replay["frames"])
        tampered_frames[1]["public_state"]["zone_counts"][0]["deck_count"] -= 1
        with self.assertRaisesRegex(CspEvaluatorError, "replay_chain_invalid"):
            self.owner.issue_record(evidence, FIXTURE_PRIVATE_KEY, tampered_frames)
        with self.assertRaisesRegex(CspEvaluatorError, "evaluator_private_key_mismatch"):
            self.owner.issue_record(evidence, b"\x01" * 32, replay["frames"])
        evidence["runtime_report"]["source"] = "historical_benchmark_import"
        with self.assertRaisesRegex(CspEvaluatorError, "evaluation_source_invalid"):
            self.owner.issue_record(evidence, FIXTURE_PRIVATE_KEY, replay["frames"])

    def test_fault_taxonomy_and_cross_runtime_integer_intervals_are_explicit(self) -> None:
        zero = {key: 0 for key in self.owner.fault_keys()}
        policy_error = self._record(
            "wp2-policy-error",
            target_seat=1,
            outcome="seat_1_win",
            winner_seat=1,
            faults=dict(zero, policy_error=1),
        )
        timeout = self._record(
            "wp2-timeout",
            target_seat=0,
            outcome="seat_0_win",
            winner_seat=0,
            faults=dict(zero, timeout=1),
        )
        runtime_dirty = self._record(
            "wp2-runtime-dirty",
            target_seat=0,
            outcome="seat_0_win",
            winner_seat=0,
            runtime_dirty_reasons=["runtime_identity_drift"],
        )
        self.assertEqual(policy_error["result"]["outcome"], "seat_0_win")
        self.assertEqual(timeout["result"]["outcome"], "seat_1_win")
        self.assertEqual(runtime_dirty["result"]["trust_lane"], "rejected_or_dirty")
        self.assertIsNone(runtime_dirty["result"]["verification"])
        summary = self.owner.materialize([policy_error, timeout, runtime_dirty])
        self.assertEqual(summary["counts"], {"wins": 0, "losses": 2, "draws": 0, "valid": 2, "dirty": 1})
        self.assertEqual(summary["fault_counts"]["policy_error"], 1)
        self.assertEqual(summary["fault_counts"]["timeout"], 1)
        for case in self.owner.conformance_vectors()["confidence_interval_cases"]:
            self.assertEqual(
                self.owner.confidence_interval_audit(case["wins"], case["valid"]),
                case["expected"],
            )

    def test_release_engine_community_and_client_report_drift_never_issue(self) -> None:
        mutations = []
        replay = build_replay_fixture(self.owner, "wp2-identity-drift", 0)
        engine = copy.deepcopy(replay)
        engine["match_envelope"]["engine_sha256"] = "A" * 64
        mutations.append(("match_profile_mismatch", engine))
        release = copy.deepcopy(replay)
        release["match_envelope"]["participants"][0]["archive_sha256"] = "B" * 64
        mutations.append(("strategy_release_mismatch", release))
        community = build_replay_fixture(self.owner, "wp2-community", 0, lane="community_challenge")
        mutations.append(("match_lane_invalid", community))
        for expected, fixture in mutations:
            evidence = build_unsigned_evidence(
                self.owner,
                fixture,
                reported_outcome="seat_0_win",
                winner_seat=0,
            )
            with self.subTest(expected=expected):
                with self.assertRaisesRegex(CspEvaluatorError, expected):
                    self.owner.issue_record(evidence, FIXTURE_PRIVATE_KEY, fixture["frames"])
        client = build_unsigned_evidence(
            self.owner,
            replay,
            reported_outcome="seat_0_win",
            winner_seat=0,
        )
        client["runtime_report"]["source"] = "client_self_report"
        with self.assertRaisesRegex(CspEvaluatorError, "evaluation_source_invalid"):
            self.owner.issue_record(client, FIXTURE_PRIVATE_KEY, replay["frames"])


if __name__ == "__main__":
    unittest.main()
