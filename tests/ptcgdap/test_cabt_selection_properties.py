from __future__ import annotations

from dataclasses import replace
from enum import IntEnum
from typing import Any, Iterator
import unittest

from scripts.ai.ptcgdap.cabt_selection import (
    CabtDeckSelectionValidator,
    CabtDeterministicFallback,
    CabtSelectionSanitizer,
    build_cabt_selection_window,
    initial_deck_hash,
)


PUBLIC_HASH_A = "A" * 64
PUBLIC_HASH_B = "B" * 64


class _Zero(IntEnum):
    VALUE = 0


class _One(IntEnum):
    VALUE = 1


class _Seven(IntEnum):
    VALUE = 7


class _IntSubtype(int):
    pass


class _NonListSequence:
    def __init__(self, items: list[Any]) -> None:
        self._items = tuple(items)

    def __len__(self) -> int:
        return len(self._items)

    def __getitem__(self, index: int) -> Any:
        return self._items[index]

    def __iter__(self) -> Iterator[Any]:
        return iter(self._items)


def _select(option_count: int, min_count: int, max_count: int) -> dict[str, Any]:
    return {
        "type": 0,
        "context": 0,
        "minCount": min_count,
        "maxCount": max_count,
        "remainDamageCounter": 0,
        "remainEnergyCost": 0,
        "option": [{"type": 1} for _ in range(option_count)],
        "deck": None,
        "contextCard": None,
        "effect": None,
    }


def _build(select: dict[str, Any], public_hash: str = PUBLIC_HASH_A):
    return build_cabt_selection_window(
        select,
        public_observation_hash=public_hash,
        public_hash_authority="conformance_fixture",
        chooser_player_index=0,
    )


def _expected_validation_reason(
    proposal: Any,
    *,
    option_count: int,
    min_count: int,
    max_count: int,
) -> str:
    if type(proposal) is not list:
        return "proposal_not_list"
    if any(type(index) is not int for index in proposal):
        return "proposal_index_not_exact_int"
    if not min_count <= len(proposal) <= max_count:
        return "proposal_cardinality"
    if any(index < 0 or index >= option_count for index in proposal):
        return "proposal_index_out_of_range"
    if len(set(proposal)) != len(proposal):
        return "proposal_duplicate_index"
    return "policy_selection_accepted"


def _assert_legal_indexes(
    test: unittest.TestCase,
    indexes: tuple[int, ...],
    *,
    option_count: int,
    min_count: int,
    max_count: int,
) -> None:
    test.assertTrue(min_count <= len(indexes) <= max_count)
    test.assertTrue(all(type(index) is int for index in indexes))
    test.assertTrue(all(0 <= index < option_count for index in indexes))
    test.assertEqual(len(indexes), len(set(indexes)))


class CabtSelectionPropertySweepTests(unittest.TestCase):
    def test_sanitizer_and_resolver_are_legal_atomic_and_order_preserving(self) -> None:
        evaluated_windows = 0
        evaluated_proposals = 0
        for option_count in range(6):
            proposals: list[Any] = [
                None,
                {},
                tuple(range(option_count)),
                range(option_count),
                _NonListSequence(list(range(option_count))),
                [],
                [-1],
                [option_count],
                [True],
                [0.0],
                ["0"],
                [_Zero.VALUE],
                [_IntSubtype(0)],
                list(range(option_count)),
                list(reversed(range(option_count))),
            ]
            proposals.extend([[index] for index in range(option_count)])
            proposals.extend(
                [[first, second] for first in range(option_count) for second in range(option_count)]
            )
            for min_count in range(option_count + 1):
                for max_count in range(min_count, option_count + 1):
                    evaluated_windows += 1
                    result = _build(_select(option_count, min_count, max_count))
                    self.assertTrue(result.policy_allowed)
                    assert result.window is not None
                    window = result.window
                    fallback = CabtDeterministicFallback.resolve(window)
                    _assert_legal_indexes(
                        self,
                        fallback.selected_indexes,
                        option_count=option_count,
                        min_count=min_count,
                        max_count=max_count,
                    )
                    fallback_validation = CabtSelectionSanitizer.validate(
                        window,
                        list(fallback.selected_indexes),
                    )
                    self.assertTrue(fallback_validation.accepted)

                    for original_proposal in proposals:
                        evaluated_proposals += 1
                        proposal = (
                            list(original_proposal)
                            if type(original_proposal) is list
                            else original_proposal
                        )
                        expected_reason = _expected_validation_reason(
                            proposal,
                            option_count=option_count,
                            min_count=min_count,
                            max_count=max_count,
                        )
                        validation = CabtSelectionSanitizer.validate(window, proposal)
                        self.assertEqual(validation.reason_code, expected_reason)
                        self.assertEqual(
                            validation.accepted,
                            expected_reason == "policy_selection_accepted",
                        )
                        resolution = CabtSelectionSanitizer.resolve_policy_attempt(
                            window,
                            proposal,
                            outcome="returned",
                        )
                        self.assertEqual(resolution.window_id, window.window_id)
                        _assert_legal_indexes(
                            self,
                            resolution.selected_indexes,
                            option_count=option_count,
                            min_count=min_count,
                            max_count=max_count,
                        )
                        if validation.accepted:
                            self.assertEqual(
                                resolution.selected_indexes,
                                tuple(proposal),
                            )
                            self.assertEqual(resolution.owner, "policy")
                        else:
                            self.assertEqual(validation.selected_indexes, ())
                            self.assertEqual(
                                resolution.selected_indexes,
                                fallback.selected_indexes,
                            )
                            self.assertEqual(
                                resolution.reason_code,
                                "invalid_policy_output",
                            )
                            self.assertEqual(resolution.owner, "deterministic_fallback")
                            if type(proposal) is list:
                                legal_prefix = tuple(
                                    index
                                    for index in proposal
                                    if type(index) is int
                                    and 0 <= index < option_count
                                )
                                if legal_prefix != fallback.selected_indexes:
                                    self.assertNotEqual(
                                        resolution.selected_indexes,
                                        legal_prefix,
                                    )
                        if type(proposal) is list:
                            accepted_snapshot = resolution.selected_indexes
                            proposal.append(0)
                            self.assertEqual(
                                resolution.selected_indexes,
                                accepted_snapshot,
                            )

        self.assertEqual(evaluated_windows, 56)
        self.assertGreater(evaluated_proposals, 1_000)

    def test_window_copy_reorder_hash_and_current_window_binding_are_deterministic(self) -> None:
        select = {
            "type": 0,
            "context": 0,
            "minCount": 1,
            "maxCount": 2,
            "remainDamageCounter": 0,
            "remainEnergyCost": 0,
            "option": [
                {"type": 15, "cardId": 860, "serial": 41},
                {"type": 15, "cardId": 860, "serial": 42},
                {"type": 15, "cardId": 860, "serial": 43},
            ],
            "deck": None,
            "contextCard": {"id": 860, "serial": 41, "playerIndex": 0},
            "effect": None,
        }
        first = _build(select)
        self.assertTrue(first.policy_allowed)
        assert first.window is not None
        first_window = first.window
        first_public = first_window.to_public_dict()

        select["option"].reverse()
        select["contextCard"]["serial"] = 99
        self.assertEqual(first_window.to_public_dict(), first_public)
        returned = first_window.to_public_dict()
        returned["options"][0]["serial"] = 999
        returned["context_card"]["serial"] = 999
        self.assertEqual(first_window.to_public_dict(), first_public)

        reordered_select = first_window.select_payload
        reordered_select["option"].reverse()
        reordered = _build(reordered_select)
        changed_hash = _build(first_window.select_payload, PUBLIC_HASH_B)
        serial_changed_select = first_window.select_payload
        serial_changed_select["option"][0]["serial"] += 1
        serial_changed = _build(serial_changed_select)
        for changed in (reordered, changed_hash, serial_changed):
            self.assertTrue(changed.policy_allowed)
            assert changed.window is not None
            self.assertNotEqual(changed.window.window_id, first_window.window_id)
            self.assertNotEqual(
                changed.window.option_fingerprints,
                first_window.option_fingerprints,
            )

        assert reordered.window is not None
        rebound = CabtSelectionSanitizer.resolve_policy_attempt(
            reordered.window,
            [2, 0],
            outcome="returned",
        )
        self.assertEqual(rebound.window_id, reordered.window.window_id)
        self.assertNotEqual(rebound.window_id, first_window.window_id)
        self.assertEqual(rebound.selected_indexes, (2, 0))

        narrower = _build(_select(1, 1, 1))
        assert narrower.window is not None
        stale_numeric_index = CabtSelectionSanitizer.resolve_policy_attempt(
            narrower.window,
            [2],
            outcome="returned",
        )
        self.assertEqual(stale_numeric_index.window_id, narrower.window.window_id)
        self.assertEqual(stale_numeric_index.owner, "deterministic_fallback")
        self.assertEqual(stale_numeric_index.selected_indexes, (0,))

    def test_python_intenum_is_rejected_at_every_exact_integer_boundary(self) -> None:
        valid = _select(1, 1, 1)
        chooser = build_cabt_selection_window(
            valid,
            public_observation_hash=PUBLIC_HASH_A,
            public_hash_authority="conformance_fixture",
            chooser_player_index=_Zero.VALUE,
        )
        self.assertEqual(chooser.issues[0].code, "invalid_chooser_player_index")

        for field_name, value in (
            ("minCount", _One.VALUE),
            ("maxCount", _One.VALUE),
            ("type", _Zero.VALUE),
            ("context", _Zero.VALUE),
        ):
            select = _select(1, 1, 1)
            select[field_name] = value
            result = _build(select)
            self.assertTrue(result.rejected, field_name)
            self.assertEqual(result.issues[0].code, "invalid_select_field_type")

        option_type = _select(1, 1, 1)
        option_type["option"][0]["type"] = _One.VALUE
        result = _build(option_type)
        self.assertEqual(result.issues[0].code, "invalid_option")

        option_field = _select(1, 1, 1)
        option_field["option"] = [
            {"type": 15, "cardId": _One.VALUE, "serial": 1}
        ]
        result = _build(option_field)
        self.assertEqual(result.issues[0].code, "invalid_option")

        window_result = _build(_select(1, 1, 1))
        assert window_result.window is not None
        validation = CabtSelectionSanitizer.validate(
            window_result.window,
            [_Zero.VALUE],
        )
        self.assertEqual(validation.reason_code, "proposal_index_not_exact_int")

        authority = CabtDeckSelectionValidator.build_marnie_conformance_authority()
        candidate = list(authority.card_ids)
        candidate[0] = _Seven.VALUE
        resolution = CabtDeckSelectionValidator.resolve(authority, candidate)
        self.assertEqual(resolution.owner, "pinned_deck_fallback")
        self.assertEqual(resolution.reason_code, "pinned_deck_fallback")
        with self.assertRaises(ValueError):
            initial_deck_hash(candidate)

        invalid_authority_ids = list(authority.card_ids)
        invalid_authority_ids[0] = _Seven.VALUE
        invalid_authority = replace(
            authority,
            card_ids=tuple(invalid_authority_ids),
        )
        rejected = CabtDeckSelectionValidator.resolve(
            invalid_authority,
            list(authority.card_ids),
        )
        self.assertFalse(rejected.accepted)
        self.assertEqual(rejected.reason_code, "invalid_pinned_deck")


if __name__ == "__main__":
    unittest.main()
