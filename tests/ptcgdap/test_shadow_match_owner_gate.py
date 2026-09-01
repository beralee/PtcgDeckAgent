from __future__ import annotations

from enum import IntEnum
import json
from pathlib import Path
import unittest

from scripts.ai.ptcgdap.shadow_prompt_broker import ShadowPromptBroker
from scripts.ai.ptcgdap.shadow_match_owner_gate import (
    EXPECTED_BUNDLE_CANONICAL_SHA256,
    ShadowMatchOwnerGate,
    ShadowMatchOwnerGateResult,
)
from scripts.ai.ptcgdap.source_lock import load_json_strict


EXPECTED_BUNDLE = "9B8202E67756E388AFB0A13EA1FD20227ADF0718DF8454420A2B1FC7A5D31B8C"
ROOT = Path(__file__).resolve().parents[2]


class FakeInt(IntEnum):
    ONE = 1


class ShadowMatchOwnerGateTests(unittest.TestCase):
    def test_contract_anchor_and_initial_audit(self) -> None:
        self.assertEqual(EXPECTED_BUNDLE_CANONICAL_SHA256, EXPECTED_BUNDLE)
        gate = ShadowMatchOwnerGate()
        self.assertTrue(gate.validate_integrity())
        self.assertEqual(gate.audit_snapshot(), {
            "profile": "ptcgdap-shadow-match-owner-gate-p3-wp6-v1",
            "gate_generation": 0,
            "state": "idle",
            "match_generation": None,
            "active_mode": None,
            "rollback_pending": False,
            "next_forced_mode": None,
            "rollback_applied": False,
            "authority": "shadow_match_owner_gate_audit",
            "authoritative": False,
        })

    def test_legacy_owner_is_immutable_for_active_match(self) -> None:
        gate = ShadowMatchOwnerGate()
        started = gate.begin_match(1, "legacy")
        self._assert_result(started, True, "", "active", "legacy")
        rejected = gate.begin_match(2, "aligned_shadow", ShadowPromptBroker(2, "session:two"))
        self._assert_result(rejected, False, "active_match_exists", "active", "legacy")
        current = gate.current_owner()
        self._assert_result(current, True, "", "active", "legacy")

    def test_aligned_requires_exact_valid_same_generation_broker(self) -> None:
        gate = ShadowMatchOwnerGate()
        self._assert_result(gate.begin_match(1, "aligned_shadow"), False, "broker_required", "idle", None)
        self._assert_result(
            gate.begin_match(1, "aligned_shadow", ShadowPromptBroker(2, "session:wrong")),
            False, "broker_match_generation_mismatch", "idle", None,
        )
        broken = ShadowPromptBroker(1, "session:ok")
        object.__setattr__(broken, "_session_id", "PRIVATE_SESSION_SENTINEL")
        self._assert_result(gate.begin_match(1, "aligned_shadow", broken), False, "broker_invalid", "idle", None)
        broker = ShadowPromptBroker(1, "session:one")
        self._assert_result(gate.begin_match(1, "aligned_shadow", broker), True, "", "active", "aligned_shadow")

    def test_legacy_forbids_broker(self) -> None:
        gate = ShadowMatchOwnerGate()
        result = gate.begin_match(1, "legacy", ShadowPromptBroker(1, "session:one"))
        self._assert_result(result, False, "broker_forbidden", "idle", None)

    def test_rollback_changes_only_next_strictly_newer_match(self) -> None:
        gate = ShadowMatchOwnerGate()
        broker = ShadowPromptBroker(4, "session:four")
        self._assert_result(gate.begin_match(4, "aligned_shadow", broker), True, "", "active", "aligned_shadow")
        requested = gate.request_legacy_next_match(4)
        self._assert_result(requested, True, "", "active", "aligned_shadow", rollback_pending=True)
        self._assert_result(
            gate.request_legacy_next_match(4), False, "rollback_already_pending", "active", "aligned_shadow", rollback_pending=True
        )
        self._assert_result(gate.current_owner(), True, "", "active", "aligned_shadow", rollback_pending=True)
        self._assert_result(gate.end_match(4), True, "", "between_matches", None, rollback_pending=True)
        forced = gate.begin_match(5, "aligned_shadow", ShadowPromptBroker(5, "session:five"))
        self._assert_result(forced, True, "", "active", "legacy", rollback_applied=True)
        self.assertFalse(forced.audit_snapshot()["rollback_pending"])
        self.assertIsNone(forced.audit_snapshot()["next_forced_mode"])

    def test_stale_and_invalid_generations_fail_closed(self) -> None:
        for bad in (None, True, False, 0, -1, 9007199254740992, 1.0, "1", FakeInt.ONE):
            with self.subTest(bad=bad):
                self.assertEqual(ShadowMatchOwnerGate().begin_match(bad, "legacy").error_code, "invalid_match_generation")
        gate = ShadowMatchOwnerGate()
        self.assertTrue(gate.begin_match(2, "legacy").accepted)
        self.assertTrue(gate.end_match(2).accepted)
        self._assert_result(gate.begin_match(2, "legacy"), False, "stale_match_generation", "between_matches", None)
        self._assert_result(gate.begin_match(1, "legacy"), False, "stale_match_generation", "between_matches", None)
        self.assertTrue(gate.begin_match(3, "legacy").accepted)

    def test_wrong_generation_cannot_request_or_end(self) -> None:
        gate = ShadowMatchOwnerGate()
        self.assertTrue(gate.begin_match(8, "legacy").accepted)
        self.assertEqual(gate.request_legacy_next_match(7).error_code, "stale_match_generation")
        self.assertEqual(gate.end_match(9).error_code, "stale_match_generation")
        self.assertEqual(gate.current_owner().audit_snapshot()["active_mode"], "legacy")

    def test_result_and_audit_are_copy_only_non_authority(self) -> None:
        gate = ShadowMatchOwnerGate()
        result = gate.begin_match(1, "legacy")
        self.assertIsInstance(result, ShadowMatchOwnerGateResult)
        self.assertTrue(result.validate_integrity(gate))
        audit = result.audit_snapshot()
        audit["active_mode"] = "aligned_shadow"
        audit["PRIVATE_BROKER_SENTINEL"] = "PRIVATE_PROMPT_SENTINEL"
        self.assertEqual(gate.current_owner().audit_snapshot()["active_mode"], "legacy")
        serialized = json.dumps(gate.audit_snapshot(), sort_keys=True)
        self.assertNotIn("PRIVATE_", serialized)
        self.assertFalse(gate.audit_snapshot()["authoritative"])
        object.__setattr__(result, "error_code", "PRIVATE_PROMPT_SENTINEL")
        self.assertFalse(result.validate_integrity(gate))
        self.assertEqual(result.to_public_dict(), {"accepted": False, "error_code": "invalid_gate", "audit": None})

    def test_corrupted_gate_fails_without_leaking_private_fields(self) -> None:
        gate = ShadowMatchOwnerGate()
        self.assertTrue(gate.begin_match(1, "aligned_shadow", ShadowPromptBroker(1, "session:one")).accepted)
        object.__setattr__(gate, "_active_mode", "PRIVATE_BROKER_SENTINEL")
        self.assertFalse(gate.validate_integrity())
        result = gate.current_owner()
        self.assertFalse(result.accepted)
        self.assertEqual(result.error_code, "invalid_gate")
        self.assertEqual(result.to_public_dict(), {"accepted": False, "error_code": "invalid_gate", "audit": None})

    def test_every_shared_vector_executes_with_exact_result(self) -> None:
        vectors = load_json_strict(ROOT / "contracts/ptcgdap/shadow_match_owner_gate_conformance_vectors.json")
        for case in vectors["cases"]:
            with self.subTest(case=case["case_id"]):
                result, audit = self._run_vector(case["scenario"])
                self.assertEqual(result.accepted, case["expected_accepted"])
                self.assertEqual(result.error_code, case["expected_error"])
                self.assertEqual(audit["state"], case["expected_state"])
                self.assertEqual(audit["active_mode"], case["expected_mode"])
                self.assertEqual(audit["rollback_pending"], case["expected_rollback_pending"])
                self.assertEqual(audit["rollback_applied"], case.get("expected_rollback_applied", False))

    def _run_vector(self, scenario: str) -> tuple[ShadowMatchOwnerGateResult, dict[str, object]]:
        gate = ShadowMatchOwnerGate()
        if scenario == "begin_legacy":
            result = gate.begin_match(1, "legacy")
        elif scenario == "begin_aligned":
            result = gate.begin_match(1, "aligned_shadow", ShadowPromptBroker(1, "session:one"))
        elif scenario == "active_owner_switch":
            gate.begin_match(1, "legacy")
            result = gate.begin_match(2, "aligned_shadow", ShadowPromptBroker(2, "session:two"))
        elif scenario in {"request_next_legacy", "current_owner_after_request", "duplicate_rollback_request", "end_with_pending"}:
            gate.begin_match(1, "aligned_shadow", ShadowPromptBroker(1, "session:one"))
            first = gate.request_legacy_next_match(1)
            result = (
                first if scenario == "request_next_legacy"
                else gate.current_owner() if scenario == "current_owner_after_request"
                else gate.request_legacy_next_match(1) if scenario == "duplicate_rollback_request"
                else gate.end_match(1)
            )
        elif scenario == "next_forced_legacy":
            gate.begin_match(1, "aligned_shadow", ShadowPromptBroker(1, "session:one"))
            gate.request_legacy_next_match(1)
            gate.end_match(1)
            result = gate.begin_match(2, "aligned_shadow", ShadowPromptBroker(2, "session:two"))
        elif scenario == "stale_generation":
            gate.begin_match(2, "legacy")
            gate.end_match(2)
            result = gate.begin_match(2, "legacy")
        elif scenario == "aligned_without_broker":
            result = gate.begin_match(1, "aligned_shadow")
        elif scenario == "aligned_cross_generation_broker":
            result = gate.begin_match(1, "aligned_shadow", ShadowPromptBroker(2, "session:two"))
        elif scenario == "legacy_with_broker":
            result = gate.begin_match(1, "legacy", ShadowPromptBroker(1, "session:one"))
        elif scenario == "strictly_newer_match":
            gate.begin_match(1, "legacy")
            gate.end_match(1)
            result = gate.begin_match(2, "legacy")
        elif scenario == "audit_copy_nonauthority":
            result = gate.begin_match(1, "legacy")
            copied = result.audit_snapshot()
            copied["active_mode"] = "aligned_shadow"
            object.__setattr__(result, "error_code", "PRIVATE_PROMPT_SENTINEL")
            safe = result.to_public_dict()
            result = ShadowMatchOwnerGateResult._from_owner(gate, safe["accepted"], safe["error_code"], safe["audit"])
        else:
            self.fail(f"unknown vector scenario: {scenario}")
        return result, gate.audit_snapshot()

    def _assert_result(
        self,
        result: ShadowMatchOwnerGateResult,
        accepted: bool,
        error: str,
        state: str,
        mode: str | None,
        *,
        rollback_pending: bool = False,
        rollback_applied: bool = False,
    ) -> None:
        self.assertEqual(result.accepted, accepted)
        self.assertEqual(result.error_code, error)
        audit = result.audit_snapshot()
        self.assertEqual(audit["state"], state)
        self.assertEqual(audit["active_mode"], mode)
        self.assertEqual(audit["rollback_pending"], rollback_pending)
        self.assertEqual(audit["rollback_applied"], rollback_applied)


if __name__ == "__main__":
    unittest.main()
