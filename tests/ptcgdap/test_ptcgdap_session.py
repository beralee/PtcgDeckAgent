from __future__ import annotations

import copy
import unittest
from pathlib import Path

from scripts.ai.ptcgdap.ptcgdap_session import PtcgDAPSession
from scripts.ai.ptcgdap.source_lock import load_json_strict


ROOT = Path(__file__).resolve().parents[2]
CONTRACT_ROOT = ROOT / "contracts" / "ptcgdap"
FIXTURE_ROOT = ROOT / "tests" / "ptcgdap" / "fixtures" / "public"


def _fixture(name: str) -> dict:
    value = load_json_strict(FIXTURE_ROOT / f"{name}.json")
    if not isinstance(value, dict):
        raise AssertionError(name)
    return value


class PtcgDAPSessionTests(unittest.TestCase):
    def test_select_null_resets_and_regular_callback_advances_without_end_hook(self) -> None:
        session = PtcgDAPSession("seat-0", contract_root=CONTRACT_ROOT)

        first = session.ingest(_fixture("initial_callback"))
        self.assertTrue(first.reset)
        self.assertTrue(first.policy_eligible)
        self.assertEqual(session.episode_generation, 1)
        self.assertEqual(session.callback_generation, 0)
        first_binding = session.current_callback_binding_hash

        session.remember_callback_local("semantic_intent", {"id": "old-window"})
        regular = session.ingest(_fixture("normal_single_select"))
        self.assertFalse(regular.reset)
        self.assertEqual(session.episode_generation, 1)
        self.assertEqual(session.callback_generation, 1)
        self.assertNotEqual(session.current_callback_binding_hash, first_binding)
        self.assertEqual(
            session.callback_local_state,
            {},
            "callback-local state must be invalidated on every new observation",
        )

        session.remember_callback_local("old_ticket", 17)
        second = session.ingest(_fixture("initial_callback"))
        self.assertTrue(second.reset)
        self.assertEqual(session.episode_generation, 2)
        self.assertEqual(session.callback_generation, 0)
        self.assertEqual(session.callback_local_state, {})
        self.assertFalse(session.opaque_search_capability_present)

    def test_missing_select_or_invalid_callback_never_masquerades_as_episode_reset(self) -> None:
        session = PtcgDAPSession("seat-0", contract_root=CONTRACT_ROOT)
        session.ingest(_fixture("initial_callback"))
        token_callback = _fixture("normal_single_select")
        token_callback["search_begin_input"] = "ephemeral-token"
        session.ingest(token_callback)
        session.remember_callback_local("old_ticket", {"index": 1})
        generation = session.episode_generation
        callback_generation = session.callback_generation

        missing = _fixture("normal_single_select")
        del missing["select"]
        result = session.ingest(missing)

        self.assertFalse(result.reset)
        self.assertFalse(result.policy_eligible)
        self.assertIsNone(result.envelope)
        self.assertEqual(session.episode_generation, generation)
        self.assertEqual(session.callback_generation, callback_generation)
        self.assertIsNone(session.current_callback_binding_hash)
        self.assertFalse(session.opaque_search_capability_present)
        self.assertEqual(session.callback_local_state, {})

    def test_unknown_decision_enum_is_preserved_but_not_policy_eligible(self) -> None:
        session = PtcgDAPSession("seat-1", contract_root=CONTRACT_ROOT)
        session.ingest(_fixture("initial_callback"))
        result = session.ingest(_fixture("unknown_additive_and_enum"))

        self.assertIsNotNone(result.envelope)
        self.assertFalse(result.policy_eligible)
        self.assertFalse(result.reset)
        self.assertEqual(result.envelope.raw_payload["select"]["type"], 99)
        self.assertIn("unknown_enum_value", {issue.code for issue in result.issues})

    def test_sessions_and_seats_have_no_shared_mutable_state(self) -> None:
        seat_zero = PtcgDAPSession("seat-0", contract_root=CONTRACT_ROOT)
        seat_one = PtcgDAPSession("seat-1", contract_root=CONTRACT_ROOT)
        initial = _fixture("initial_callback")
        seat_zero.ingest(copy.deepcopy(initial))
        seat_one.ingest(copy.deepcopy(initial))

        seat_zero.remember_callback_local("only-seat-zero", [1, 2, 3])
        token_callback = _fixture("normal_single_select")
        token_callback["search_begin_input"] = "ephemeral-token"
        seat_one.ingest(token_callback)

        self.assertIn("only-seat-zero", seat_zero.callback_local_state)
        self.assertNotIn("only-seat-zero", seat_one.callback_local_state)
        self.assertFalse(seat_zero.opaque_search_capability_present)
        self.assertTrue(seat_one.opaque_search_capability_present)
        self.assertNotEqual(
            seat_zero.current_callback_binding_hash,
            seat_one.current_callback_binding_hash,
        )

    def test_callback_local_getter_is_not_an_alias(self) -> None:
        session = PtcgDAPSession("seat-0", contract_root=CONTRACT_ROOT)
        session.ingest(_fixture("initial_callback"))
        session.remember_callback_local("intent", {"targets": [1]})

        returned = session.callback_local_state
        returned["intent"]["targets"].append(2)
        self.assertEqual(session.callback_local_state["intent"]["targets"], [1])


if __name__ == "__main__":
    unittest.main()
