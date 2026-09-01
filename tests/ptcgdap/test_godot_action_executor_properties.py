from __future__ import annotations

import copy
import random
import unittest

from scripts.ai.ptcgdap.godot_action_executor import GodotActionExecutor
from tests.ptcgdap.test_godot_action_executor import claimed_context, commit, prepare


class GodotActionExecutorPropertyTests(unittest.TestCase):
    def test_seeded_prepare_commit_fault_sweep_is_atomic(self) -> None:
        rng = random.Random(0xCAB7_0304)
        outcomes = {"success": 0, "abort": 0}
        for _ in range(40):
            ctx, ticket_owner, claimed = claimed_context()
            executor = GodotActionExecutor()
            prepared = prepare(executor, ctx, ticket_owner, claimed)
            self.assertTrue(prepared.accepted)
            batch = prepared.preflight
            mode = rng.choice(("success", "source", "callback", "snapshot"))
            if mode == "success":
                result = commit(executor, batch, ctx, ticket_owner)
                self.assertTrue(result.accepted)
                self.assertEqual([item.option_index for item in result.binding_resolutions], [1, 0])
                self.assertEqual(batch.state, "committed")
                outcomes["success"] += 1
            elif mode == "source":
                changed = copy.deepcopy(ctx["source"])
                changed["turn_action_count"] += 1
                result = commit(executor, batch, ctx, ticket_owner, current_source=changed)
                self.assertEqual(result.error_code, "commit_context_changed")
                outcomes["abort"] += 1
            elif mode == "callback":
                result = commit(executor, batch, ctx, ticket_owner, callback_binding_hash="B" * 64)
                self.assertEqual(result.error_code, "commit_context_changed")
                outcomes["abort"] += 1
            else:
                other, _, _ = claimed_context()
                result = commit(executor, batch, ctx, ticket_owner, snapshot=other["snapshot"])
                self.assertEqual(result.error_code, "commit_context_changed")
                outcomes["abort"] += 1
            if not result.accepted:
                self.assertEqual(result.binding_resolutions, ())
                self.assertEqual(batch.state, "aborted")
            self.assertTrue(result.validate_integrity(executor))
        self.assertGreater(outcomes["success"], 0)
        self.assertGreater(outcomes["abort"], 0)

    def test_generation_ids_are_monotonic_unique_and_do_not_reuse_closed_batches(self) -> None:
        ctx, ticket_owner, claimed = claimed_context()
        executor = GodotActionExecutor()
        ids: list[str] = []
        for generation in range(1, 17):
            prepared = prepare(executor, ctx, ticket_owner, claimed)
            self.assertTrue(prepared.accepted)
            self.assertEqual(prepared.preflight.preflight_generation, generation)
            ids.append(prepared.preflight.preflight_id)
            if generation % 2:
                self.assertTrue(commit(executor, prepared.preflight, ctx, ticket_owner).accepted)
            else:
                self.assertTrue(executor.abort(prepared.preflight))
        self.assertEqual(len(ids), len(set(ids)))

    def test_commit_never_invokes_private_command_objects(self) -> None:
        class CallableCommand:
            def __init__(self) -> None:
                self.calls = 0

            def __call__(self) -> None:
                self.calls += 1

        ctx, ticket_owner, claimed = claimed_context()
        replacements = [CallableCommand() for _ in ctx["commands"]]
        state = ctx["binding_owner"]._current
        import weakref
        state.command_refs = tuple(weakref.ref(item) for item in replacements)
        for result, replacement in zip(claimed.binding_resolutions, (replacements[index] for index in result_indexes(claimed)), strict=True):
            object.__setattr__(result, "private_engine_command", replacement)
        executor = GodotActionExecutor()
        prepared = prepare(executor, ctx, ticket_owner, claimed)
        self.assertTrue(prepared.accepted)
        committed = commit(executor, prepared.preflight, ctx, ticket_owner)
        self.assertTrue(committed.accepted)
        self.assertTrue(all(command.calls == 0 for command in replacements))


def result_indexes(claimed):
    return [item.option_index for item in claimed.binding_resolutions]


if __name__ == "__main__":
    unittest.main()
