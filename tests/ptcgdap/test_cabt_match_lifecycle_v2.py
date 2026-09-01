from __future__ import annotations

import copy
import unittest
from pathlib import Path

from scripts.ai.ptcgdap.cabt_match_lifecycle_v2 import (
    CabtLifecycleV2Error,
    CabtMatchLifecycleV2,
)
from scripts.ai.ptcgdap.source_lock import load_json_strict


ROOT = Path(__file__).resolve().parents[2]
FIXTURES = ROOT / "tests" / "ptcgdap" / "fixtures" / "public"
PROFILE_HASH = "A" * 64


def fixture(name: str) -> dict:
    return load_json_strict(FIXTURES / f"{name}.json")


class Executor:
    def __init__(self, fail: bool = False) -> None:
        self.fail = fail
        self.rolled_back = False

    def prepare(self, targets: tuple[object, ...]) -> tuple[object, ...]:
        return targets

    def commit(self, prepared: tuple[object, ...]) -> list[object]:
        if self.fail:
            raise RuntimeError("injected")
        return list(prepared)

    def rollback(self, prepared: tuple[object, ...]) -> None:
        self.rolled_back = True


class CabtMatchLifecycleV2Tests(unittest.TestCase):
    def make_host(self) -> CabtMatchLifecycleV2:
        return CabtMatchLifecycleV2(
            "match-1",
            capability_profile_hash=PROFILE_HASH,
            session_hmac_keys=(b"0" * 32, b"1" * 32),
            deck_validator=lambda _seat, deck: len(deck) == 60,
        )

    def bootstrap(self, host: CabtMatchLifecycleV2) -> None:
        initial = fixture("initial_callback")
        host.bootstrap(0, initial, list(range(1, 61)))
        host.bootstrap(1, copy.deepcopy(initial), list(range(101, 161)))
        host.start_engine()

    def test_initial_deck_domain_is_exact_and_separate_from_selection_domain(self) -> None:
        host = self.make_host()
        initial = fixture("initial_callback")
        first = host.bootstrap(0, initial, list(range(1, 61)))
        self.assertEqual(len(first.deck), 60)
        with self.assertRaisesRegex(CabtLifecycleV2Error, "cabt_bootstrap_stale"):
            host.bootstrap(0, initial, list(range(1, 61)))
        with self.assertRaisesRegex(CabtLifecycleV2Error, "cabt_engine_start_before_decks"):
            host.start_engine()
        host.bootstrap(1, initial, list(range(101, 161)))
        decks = host.start_engine()
        self.assertEqual(decks[0][0], 1)
        self.assertEqual(decks[1][0], 101)

    def test_initial_callback_requires_exact_null_and_empty_lifecycle_shape(self) -> None:
        for mutation in (
            lambda value: value.update(select={}),
            lambda value: value.update(current={}),
            lambda value: value.update(logs=[{}]),
            lambda value: value.update(search_begin_input="private-token"),
        ):
            host = self.make_host()
            raw = fixture("initial_callback")
            mutation(raw)
            with self.assertRaisesRegex(CabtLifecycleV2Error, "cabt_initial_callback_invalid"):
                host.bootstrap(0, raw, list(range(1, 61)))
        with self.assertRaisesRegex(CabtLifecycleV2Error, "cabt_bootstrap_deck_invalid"):
            self.make_host().bootstrap(0, fixture("initial_callback"), [True] * 60)

    def test_full_selection_state_machine_is_one_shot_seat_bound_and_witnessed(self) -> None:
        host = self.make_host()
        self.bootstrap(host)
        raw = fixture("normal_single_select")
        binding = host.issue_selection(0, raw, private_options=["private-0", "private-1"])
        self.assertEqual(binding.public.incremental_log_cursor, 0)
        with self.assertRaisesRegex(CabtLifecycleV2Error, "cabt_window_seat_or_state_invalid"):
            host.accept(1, [0])
        accepted = host.accept(0, [1])
        bound = host.bind(accepted)
        self.assertEqual(bound.private_targets, ("private-1",))
        self.assertEqual(host.commit(bound, Executor()), ["private-1"])
        with self.assertRaisesRegex(CabtLifecycleV2Error, "cabt_bound_selection_stale"):
            host.commit(bound, Executor())
        next_raw = copy.deepcopy(raw)
        next_raw["step"] += 1
        next_raw["logs"] = [{"type": 10}]
        witness = host.witness(next_raw)
        self.assertTrue(witness.public_witness)
        next_binding = host.issue_selection(1, next_raw, private_options=[1, 2])
        self.assertEqual(next_binding.public.incremental_log_cursor, 0)
        self.assertEqual(host.log_cursors, (0, 1))

    def test_atomic_failure_invalidates_window_and_never_commits_again(self) -> None:
        host = self.make_host()
        self.bootstrap(host)
        binding = host.issue_selection(0, fixture("normal_single_select"), private_options=[0, 1])
        bound = host.bind(host.accept(0, [0]))
        executor = Executor(fail=True)
        with self.assertRaisesRegex(CabtLifecycleV2Error, "cabt_executor_atomic_failure"):
            host.commit(bound, executor)
        self.assertTrue(executor.rolled_back)
        self.assertEqual(binding.state, "invalidated")

    def test_terminal_is_not_an_agent_callback_and_dispose_erases_authority(self) -> None:
        host = self.make_host()
        self.bootstrap(host)
        terminal = host.terminal({"winner": 0, "reason": "prizes"}, incremental_logs_by_seat=([{"type": 23}], []))
        self.assertEqual(host.state, "terminal")
        self.assertEqual(terminal.result["winner"], 0)
        with self.assertRaisesRegex(CabtLifecycleV2Error, "cabt_selection_checkpoint_out_of_order"):
            host.issue_selection(0, fixture("normal_single_select"), private_options=[0, 1])
        host.dispose()
        self.assertEqual(host.state, "disposed")
        self.assertEqual(host.log_cursors, (0, 0))
        self.assertIsNone(host.current_window)


if __name__ == "__main__":
    unittest.main()
