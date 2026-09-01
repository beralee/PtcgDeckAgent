from __future__ import annotations

from dataclasses import asdict
import json
import unittest

from scripts.ai.ptcgdap.cabt_a1_contract import CONTEXT_OPTION_TYPES, CONTEXT_SELECT_TYPE
from scripts.ai.ptcgdap.cabt_window_v2 import CabtWindowV2Error, SelectionWindowBindingV2


CAPABILITY_HASH = "A" * 64
SESSION_KEY = b"window-v2-test-session-key-material"


def _option(raw: int, marker: int = 0) -> dict:
    return {
        0: {"type": 0, "number": marker},
        1: {"type": 1},
        2: {"type": 2},
        3: {"type": 3, "area": 2, "index": marker, "playerIndex": 0},
        4: {"type": 4, "area": 4, "index": 0, "playerIndex": 0, "toolIndex": marker},
        5: {"type": 5, "area": 4, "index": 0, "playerIndex": 0, "energyIndex": marker},
        6: {"type": 6, "area": 8, "index": 0, "playerIndex": 0, "energyIndex": marker, "count": 1},
        7: {"type": 7, "index": marker},
        8: {"type": 8, "area": 2, "index": marker, "inPlayArea": 4, "inPlayIndex": 0},
        9: {"type": 9, "area": 2, "index": marker, "inPlayArea": 4, "inPlayIndex": 0},
        10: {"type": 10, "area": 2, "index": marker},
        11: {"type": 11, "area": 2, "index": marker},
        12: {"type": 12},
        13: {"type": 13, "attackId": marker + 1},
        14: {"type": 14},
        15: {"type": 15, "cardId": 0, "serial": 0},
        16: {"type": 16, "specialConditionType": marker},
    }[raw]


def _callback(context: int, options: list[dict], **extras: object) -> dict:
    return {
        "select": {
            "type": CONTEXT_SELECT_TYPE[context],
            "context": context,
            "minCount": 1,
            "maxCount": 1,
            "remainDamageCounter": 0,
            "remainEnergyCost": 0,
            "option": options,
            "deck": None,
            "contextCard": None,
            "effect": None,
        },
        "current": {},
        "logs": [],
        **extras,
    }


def _issue(context: int, options: list[dict], private: list[object] | None = None, **extras: object) -> SelectionWindowBindingV2:
    return SelectionWindowBindingV2.issue(
        _callback(context, options, **extras),
        session_id="session-a",
        match_generation=1,
        seat=0,
        window_generation=1,
        private_options=private if private is not None else [object() for _ in options],
        log_cursor=0,
        capability_profile_hash=CAPABILITY_HASH,
        session_hmac_key=SESSION_KEY,
    )


class _Executor:
    def __init__(self, fail: bool = False) -> None:
        self.fail = fail
        self.prepared = None
        self.rolled_back = False

    def prepare(self, targets: tuple[object, ...]) -> tuple[object, ...]:
        self.prepared = targets
        return targets

    def commit(self, prepared: tuple[object, ...]) -> str:
        if self.fail:
            raise RuntimeError("private engine detail")
        return f"committed:{len(prepared)}"

    def rollback(self, _prepared: tuple[object, ...]) -> None:
        self.rolled_back = True


class CabtWindowV2Tests(unittest.TestCase):
    def test_every_official_context_issues_and_commits_through_one_port(self) -> None:
        for context in range(49):
            with self.subTest(context=context):
                raw_option = CONTEXT_OPTION_TYPES[context][0]
                target = object()
                binding = _issue(context, [_option(raw_option)], [target])
                accepted = binding.accept([0])
                self.assertEqual("accepted", binding.state)
                bound = binding.bind(accepted)
                self.assertIs(target, bound.private_targets[0])
                self.assertEqual("committed:1", binding.commit(bound, _Executor()))
                witness_callback = _callback(context, [_option(raw_option)])
                witness_callback["logs"] = [{"type": 0, "playerIndex": 0}]
                witness = binding.witness(witness_callback)
                self.assertTrue(witness.public_witness)
                self.assertEqual("public-witness", binding.state)

    def test_hash_domains_reorder_time_and_search_are_separated(self) -> None:
        first = _issue(0, [_option(7, 0), _option(7, 1)], step=5, remainingOverageTime=600.0)
        reordered = _issue(0, [_option(7, 1), _option(7, 0)], step=5, remainingOverageTime=600.0)
        timed = _issue(0, [_option(7, 0), _option(7, 1)], step=5, remainingOverageTime=599.5)
        searched = _issue(
            0,
            [_option(7, 0), _option(7, 1)],
            step=5,
            remainingOverageTime=600.0,
            search_begin_input="opaque-token-A",
        )
        self.assertNotEqual(first.public.window_id, reordered.public.window_id)
        self.assertEqual(first.public.engine_semantic_hash, timed.public.engine_semantic_hash)
        self.assertNotEqual(first.public.policy_input_hash, timed.public.policy_input_hash)
        self.assertEqual(first.public.engine_semantic_hash, searched.public.engine_semantic_hash)
        self.assertNotEqual(first._callback_binding_hash, searched._callback_binding_hash)
        rendered = json.dumps(asdict(searched.public), ensure_ascii=False)
        self.assertNotIn("opaque-token-A", rendered)
        self.assertNotIn("callback_binding_hash", rendered)

    def test_invalid_stale_and_partial_execution_fail_atomically(self) -> None:
        binding = _issue(34, [_option(15)])
        for proposal in ([True], [0, 0], [1], []):
            with self.subTest(proposal=proposal):
                fresh = _issue(34, [_option(15)])
                with self.assertRaisesRegex(CabtWindowV2Error, "invalid_agent_output"):
                    fresh.accept(proposal)
        accepted = binding.accept([0])
        with self.assertRaisesRegex(CabtWindowV2Error, "stale"):
            binding.accept([0])
        bound = binding.bind(accepted)
        executor = _Executor(fail=True)
        with self.assertRaisesRegex(CabtWindowV2Error, "atomic_failure"):
            binding.commit(bound, executor)
        self.assertTrue(executor.rolled_back)
        self.assertEqual("invalidated", binding.state)

    def test_unknown_context_and_private_binding_mismatch_fail_closed(self) -> None:
        unknown = _callback(0, [_option(7)])
        unknown["select"]["context"] = 49
        with self.assertRaises(CabtWindowV2Error):
            SelectionWindowBindingV2.issue(
                unknown,
                session_id="session-a",
                match_generation=1,
                seat=0,
                window_generation=1,
                private_options=[object()],
                log_cursor=0,
                capability_profile_hash=CAPABILITY_HASH,
                session_hmac_key=SESSION_KEY,
            )
        with self.assertRaisesRegex(CabtWindowV2Error, "cardinality_mismatch"):
            _issue(0, [_option(7)], [])


if __name__ == "__main__":
    unittest.main()
