from __future__ import annotations

import json
import unittest

from scripts.ai.ptcgdap.shadow_engine_command_applier import ShadowEngineCommandApplier
from tests.ptcgdap.test_shadow_engine_command_applier import ReversibleCommand, aligned_gate, committed_fixture


class ShadowEngineCommandApplierPropertyTests(unittest.TestCase):
    def test_order_is_preserved_and_each_selected_command_applies_once(self) -> None:
        for start_a in range(4):
            for start_b in range(4):
                with self.subTest(start_a=start_a, start_b=start_b):
                    order: list[str] = []
                    first = RecordingCommand("first", order)
                    second = RecordingCommand("second", order)
                    first.value = start_a
                    second.value = start_b
                    ctx, broker, committed, _ = committed_fixture(first=first, second=second)
                    applier = ShadowEngineCommandApplier(aligned_gate(ctx, broker), broker)
                    result = applier.apply(committed)
                    self.assertTrue(result.accepted)
                    self.assertEqual(order, ["first", "second"])
                    self.assertEqual((first.value, second.value), (start_a + 1, start_b + 1))

    def test_every_failure_position_restores_the_whole_captured_batch(self) -> None:
        for fail_first in (True, False):
            with self.subTest(fail_first=fail_first):
                first = ReversibleCommand("first", apply_ok=not fail_first)
                second = ReversibleCommand("second", apply_ok=fail_first)
                first.value = 17
                second.value = 29
                ctx, broker, committed, _ = committed_fixture(first=first, second=second)
                applier = ShadowEngineCommandApplier(aligned_gate(ctx, broker), broker)
                result = applier.apply(committed)
                self.assertFalse(result.accepted)
                self.assertEqual(result.error_code, "command_apply_failed")
                self.assertTrue(result.rolled_back)
                self.assertEqual((first.value, second.value), (17, 29))

    def test_audit_and_result_are_private_free_for_all_terminal_states(self) -> None:
        configurations = (
            (ReversibleCommand("first"), ReversibleCommand("second")),
            (ReversibleCommand("first", capture_ok=False), ReversibleCommand("second")),
            (ReversibleCommand("first", restore_ok=False), ReversibleCommand("second", apply_ok=False)),
        )
        for first, second in configurations:
            ctx, broker, committed, _ = committed_fixture(first=first, second=second)
            applier = ShadowEngineCommandApplier(aligned_gate(ctx, broker), broker)
            result = applier.apply(committed)
            serialized = json.dumps({"result": result.to_public_dict(), "audit": applier.audit_snapshot()}, sort_keys=True)
            for forbidden in ("PRIVATE_", "private_engine_command", "captured_state", "session_id", "callback_binding_hash", "current_source"):
                self.assertNotIn(forbidden, serialized.lower() if forbidden.islower() else serialized)


class RecordingCommand(ReversibleCommand):
    def __init__(self, name: str, order: list[str]) -> None:
        super().__init__(name)
        self.order = order

    def shadow_apply(self):
        self.order.append(self.name)
        return super().shadow_apply()


if __name__ == "__main__":
    unittest.main()
