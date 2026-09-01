from __future__ import annotations

import unittest

from scripts.ai.ptcgdap.shadow_prompt_broker import ShadowPromptBroker
from scripts.ai.ptcgdap.shadow_match_owner_gate import ShadowMatchOwnerGate


class ShadowMatchOwnerGatePropertyTests(unittest.TestCase):
    def test_monotonic_matches_and_every_third_rollback(self) -> None:
        gate = ShadowMatchOwnerGate()
        expected_mode = None
        for generation in range(1, 65):
            requested = "aligned_shadow" if generation % 2 else "legacy"
            broker = ShadowPromptBroker(generation, f"session:g{generation}") if requested == "aligned_shadow" else None
            result = gate.begin_match(generation, requested, broker)
            expected_mode = "legacy" if generation > 1 and (generation - 1) % 3 == 0 else requested
            self.assertTrue(result.accepted)
            self.assertEqual(result.audit_snapshot()["active_mode"], expected_mode)
            self.assertEqual(gate.begin_match(generation + 1, "legacy").error_code, "active_match_exists")
            if generation % 3 == 0:
                rollback = gate.request_legacy_next_match(generation)
                self.assertTrue(rollback.accepted)
                self.assertEqual(rollback.audit_snapshot()["active_mode"], expected_mode)
            self.assertTrue(gate.end_match(generation).accepted)
            self.assertEqual(gate.begin_match(generation, "legacy").error_code, "stale_match_generation")

    def test_rollback_never_changes_current_owner(self) -> None:
        for mode in ("legacy", "aligned_shadow"):
            with self.subTest(mode=mode):
                gate = ShadowMatchOwnerGate()
                broker = ShadowPromptBroker(1, "session:one") if mode == "aligned_shadow" else None
                self.assertTrue(gate.begin_match(1, mode, broker).accepted)
                before = gate.audit_snapshot()
                self.assertTrue(gate.request_legacy_next_match(1).accepted)
                after = gate.audit_snapshot()
                self.assertEqual(after["active_mode"], before["active_mode"])
                self.assertEqual(after["match_generation"], before["match_generation"])
                self.assertTrue(after["rollback_pending"])

    def test_two_gates_have_no_shared_authority(self) -> None:
        first = ShadowMatchOwnerGate()
        second = ShadowMatchOwnerGate()
        self.assertTrue(first.begin_match(1, "legacy").accepted)
        self.assertEqual(second.audit_snapshot()["state"], "idle")
        self.assertTrue(second.begin_match(1, "aligned_shadow", ShadowPromptBroker(1, "session:second")).accepted)
        self.assertEqual(first.audit_snapshot()["active_mode"], "legacy")
        self.assertEqual(second.audit_snapshot()["active_mode"], "aligned_shadow")


if __name__ == "__main__":
    unittest.main()
