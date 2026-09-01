from __future__ import annotations

import copy
from dataclasses import replace
from pathlib import Path
from typing import Any, Iterator
import unittest

from scripts.ai.ptcgdap.cabt_selection import (
    CabtDeckSelectionValidator,
    CabtDeterministicFallback,
    CabtSelectionSanitizer,
    DEFAULT_SELECTION_CONTRACTS,
    build_cabt_selection_window,
)
from scripts.ai.ptcgdap.source_lock import load_json_strict


ROOT = Path(__file__).resolve().parents[2]
VECTORS_PATH = ROOT / "contracts" / "ptcgdap" / "cabt_selection_conformance_vectors.json"


class _NonListSequence:
    def __init__(self, items: list[Any]) -> None:
        self._items = tuple(items)

    def __len__(self) -> int:
        return len(self._items)

    def __getitem__(self, index: int) -> Any:
        return self._items[index]

    def __iter__(self) -> Iterator[Any]:
        return iter(self._items)


def _materialize_typed_item(value: Any) -> Any:
    if type(value) is dict and value.get("type") == "float":
        return float(value["decimal"])
    if type(value) is dict and value.get("type") == "unsafe_integer":
        return int(value["decimal"])
    return copy.deepcopy(value)


def _materialize_proposal(descriptor: Any) -> Any:
    if type(descriptor) is not dict:
        return copy.deepcopy(descriptor)
    if descriptor.get("kind") == "json":
        return copy.deepcopy(descriptor["value"])
    if descriptor.get("kind") != "typed":
        raise AssertionError("unknown proposal descriptor")
    items = [_materialize_typed_item(item) for item in descriptor.get("items", [])]
    if descriptor["type"] == "list":
        return items
    if descriptor["type"] == "non_list_sequence":
        return _NonListSequence(items)
    raise AssertionError("unknown typed proposal")


def _window_expected(case: dict[str, Any]) -> dict[str, Any]:
    select = case["select"]
    return {
        "window_version": 1,
        "window_id": case["expected_window_id"],
        "hash_profile": "cabt_selection_window_v1",
        "option_fingerprint_profile": "cabt_option_fingerprint_v1",
        "public_observation_hash": case["public_observation_hash"],
        "public_hash_authority": case["public_hash_authority"],
        "chooser_player_index": case["chooser_player_index"],
        "decision_state": case["expected_decision_state"],
        "fallback_reasons": case["expected_fallback_reasons"],
        "select_type_raw": select["type"],
        "select_context_raw": select["context"],
        "min_count": select["minCount"],
        "max_count": select["maxCount"],
        "remain_damage_counter": select["remainDamageCounter"],
        "remain_energy_cost": select["remainEnergyCost"],
        "context_card": select["contextCard"],
        "effect": select["effect"],
        "public_deck_candidates": select["deck"],
        "options": select["option"],
        "option_fingerprints": case["expected_option_fingerprints"],
    }


def _pointer_value(root: dict[str, Any], pointer: str) -> Any:
    current: Any = root
    if pointer == "":
        return current
    for segment in pointer.strip("/").split("/"):
        if type(current) is list:
            current = current[int(segment)]
        else:
            current = current[segment]
    return current


class CabtSelectionSharedVectorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.vectors = load_json_strict(VECTORS_PATH)
        cls.window_cases = {
            case["id"]: case for case in cls.vectors["window_cases"]
        }

    def _build_window(self, case: dict[str, Any]):
        result = build_cabt_selection_window(
            copy.deepcopy(case["select"]),
            public_observation_hash=case["public_observation_hash"],
            public_hash_authority=case["public_hash_authority"],
            chooser_player_index=case["chooser_player_index"],
        )
        self.assertIsNotNone(result.window, case["id"])
        self.assertTrue(result.validate_integrity(), case["id"])
        for issue in result.issues:
            self.assertTrue(issue.validate_integrity(), case["id"])
        return result

    def test_all_seventeen_option_types_execute_the_shared_hash_contract(self) -> None:
        matrix = self.vectors["option_type_matrix"]
        self.assertEqual(len(matrix["cases"]), 17)
        common = matrix["common"]
        for case in matrix["cases"]:
            with self.subTest(case=case["id"]):
                select = copy.deepcopy(common["select_without_option"])
                select["option"] = [copy.deepcopy(case["option"])]
                result = build_cabt_selection_window(
                    select,
                    public_observation_hash=common["public_observation_hash"],
                    public_hash_authority=common["public_hash_authority"],
                    chooser_player_index=common["chooser_player_index"],
                )
                self.assertTrue(result.policy_allowed)
                self.assertTrue(result.validate_integrity(), case["id"])
                assert result.window is not None
                self.assertEqual(result.window.window_id, case["expected_window_id"])
                self.assertEqual(
                    result.window.option_fingerprints,
                    (case["expected_fingerprint"],),
                )
                self.assertEqual(result.window.options, [case["option"]])

    def test_every_window_serializes_exactly_and_falls_back_from_itself(self) -> None:
        cases = self.vectors["window_cases"]
        self.assertEqual(len(cases), 21)
        for case in cases:
            with self.subTest(case=case["id"]):
                result = self._build_window(case)
                assert result.window is not None
                self.assertEqual(result.decision_state, case["expected_decision_state"])
                self.assertEqual(result.window.to_public_dict(), _window_expected(case))
                self.assertEqual(
                    [issue.code for issue in result.issues],
                    case["expected_fallback_reasons"],
                )
                fallback = CabtDeterministicFallback.resolve(result.window)
                self.assertTrue(
                    fallback.validate_integrity(result.window),
                    case["id"],
                )
                self.assertEqual(
                    fallback.to_public_dict(),
                    {
                        "accepted": True,
                        "window_id": case["expected_window_id"],
                        "selected_indexes": case["expected_fallback"],
                        "owner": "deterministic_fallback",
                        "reason_code": "window_fallback_only",
                        "fallback_branch": case["expected_fallback_branch"],
                    },
                )
                if "accepted_ordered_proposal" in case:
                    ordered = copy.deepcopy(case["accepted_ordered_proposal"])
                    validation = CabtSelectionSanitizer.validate(result.window, ordered)
                    self.assertTrue(validation.accepted)
                    self.assertTrue(
                        validation.validate_integrity(result.window),
                        case["id"],
                    )
                    self.assertEqual(validation.selected_indexes, tuple(ordered))
                    accepted = CabtSelectionSanitizer.resolve_policy_attempt(
                        result.window,
                        ordered,
                        outcome="returned",
                    )
                    self.assertEqual(accepted.owner, "policy")
                    self.assertEqual(accepted.selected_indexes, tuple(ordered))
                    self.assertTrue(
                        accepted.validate_integrity(result.window),
                        case["id"],
                    )

    def test_all_build_rejects_execute_with_exact_non_echoing_diagnostics(self) -> None:
        cases = self.vectors["build_reject_cases"]
        self.assertEqual(len(cases), 17)
        option_cases = {
            case["id"]: case
            for case in self.vectors["option_type_matrix"]["cases"]
        }
        common = self.vectors["option_type_matrix"]["common"]
        for case in cases:
            with self.subTest(case=case["id"]):
                if case.get("base_section") == "option_type_matrix":
                    option_case = option_cases[case["base_window_case_id"]]
                    select = copy.deepcopy(common["select_without_option"])
                    select["option"] = [copy.deepcopy(option_case["option"])]
                    inputs = {
                        "select": select,
                        "public_observation_hash": common["public_observation_hash"],
                        "public_hash_authority": common["public_hash_authority"],
                        "chooser_player_index": common["chooser_player_index"],
                    }
                else:
                    base = self.window_cases[case["base_window_case_id"]]
                    inputs = {
                        key: copy.deepcopy(base[key])
                        for key in (
                            "select",
                            "public_observation_hash",
                            "public_hash_authority",
                            "chooser_player_index",
                        )
                    }
                mutation = case["mutation"]
                operation = mutation["operation"]
                if operation == "replace_input":
                    inputs[mutation["field"]] = copy.deepcopy(mutation["value"])
                elif operation == "add_key":
                    target = _pointer_value(inputs, mutation["pointer"])
                    target[mutation["key"]] = copy.deepcopy(mutation["value"])
                elif operation == "remove_key":
                    target = _pointer_value(inputs, mutation["pointer"])
                    del target[mutation["key"]]
                elif operation == "replace_pointer":
                    segments = mutation["pointer"].strip("/").split("/")
                    parent_pointer = (
                        "" if len(segments) == 1 else "/" + "/".join(segments[:-1])
                    )
                    parent = _pointer_value(inputs, parent_pointer)
                    final = segments[-1]
                    parent[int(final) if type(parent) is list else final] = copy.deepcopy(
                        mutation["value"]
                    )
                else:
                    raise AssertionError("unknown build mutation")

                result = build_cabt_selection_window(
                    inputs["select"],
                    public_observation_hash=inputs["public_observation_hash"],
                    public_hash_authority=inputs["public_hash_authority"],
                    chooser_player_index=inputs["chooser_player_index"],
                )
                self.assertTrue(result.validate_integrity(), case["id"])
                self.assertEqual(len(result.issues), 1, case["id"])
                self.assertTrue(result.issues[0].validate_integrity(), case["id"])
                expected = {
                    "decision_state": "reject",
                    "window": None,
                    "issues": [
                        {
                            "code": case["expected_issue_code"],
                            "pointer": case["expected_issue_pointer"],
                            "severity": "error",
                        }
                    ],
                }
                self.assertEqual(result.to_public_dict(), expected)
                diagnostic = str(result.to_public_dict())
                for forbidden in case.get("forbidden_diagnostic_substrings", []):
                    self.assertNotIn(forbidden, diagnostic)

    def test_all_sanitizer_cases_validate_and_resolve_atomically(self) -> None:
        cases = self.vectors["sanitizer_cases"]
        self.assertEqual(len(cases), 14)
        for case in cases:
            with self.subTest(case=case["id"]):
                window_case = self.window_cases[case["window_case_id"]]
                result = self._build_window(window_case)
                assert result.window is not None
                proposal = _materialize_proposal(case["proposal"])
                validation = CabtSelectionSanitizer.validate(result.window, proposal)
                self.assertTrue(
                    validation.validate_integrity(result.window),
                    case["id"],
                )
                self.assertEqual(
                    validation.to_public_dict(),
                    case["expected_validation"],
                )
                resolution_result = CabtSelectionSanitizer.resolve_policy_attempt(
                    result.window,
                    proposal,
                    outcome="returned",
                )
                self.assertTrue(
                    resolution_result.validate_integrity(result.window),
                    case["id"],
                )
                resolution = resolution_result.to_public_dict()
                expected_resolution = {
                    "window_id": window_case["expected_window_id"],
                    **case["expected_resolution"],
                }
                self.assertEqual(resolution, expected_resolution)
                if "forbidden_partial_result" in case:
                    self.assertNotEqual(
                        resolution["selected_indexes"],
                        case["forbidden_partial_result"],
                    )

    def test_all_policy_faults_use_the_current_window_only(self) -> None:
        cases = self.vectors["policy_fault_cases"]
        self.assertEqual(len(cases), 5)
        for case in cases:
            with self.subTest(case=case["id"]):
                window_case = self.window_cases[case["window_case_id"]]
                result = self._build_window(window_case)
                assert result.window is not None
                resolution_result = CabtSelectionSanitizer.resolve_policy_attempt(
                    result.window,
                    copy.deepcopy(case.get("proposal")),
                    outcome=case["policy_outcome"],
                )
                self.assertTrue(
                    resolution_result.validate_integrity(result.window),
                    case["id"],
                )
                resolution = resolution_result.to_public_dict()
                self.assertEqual(
                    resolution,
                    {
                        "window_id": window_case["expected_window_id"],
                        **case["expected_resolution"],
                    },
                )

    def test_all_initial_deck_and_invalid_authority_vectors_execute(self) -> None:
        fixture = self.vectors["initial_deck_fixture"]
        pinned_ids = fixture["card_ids"]
        pinned_build = CabtDeckSelectionValidator.build_pinned_deck()
        self.assertTrue(
            pinned_build.validate_integrity(DEFAULT_SELECTION_CONTRACTS)
        )
        self.assertTrue(pinned_build.accepted)
        authority = pinned_build.pinned_deck
        assert authority is not None
        self.assertEqual(
            authority.to_public_dict(),
            {
                "profile": fixture["profile"],
                "card_ids": pinned_ids,
                "deck_hash": fixture["deck_hash"],
                "source_artifact_id": fixture["source_artifact_id"],
                "source_sha256": fixture["source_sha256"],
                "authority_scope": fixture["authority_scope"],
            },
        )

        deck_cases = self.vectors["initial_deck_cases"]
        self.assertEqual(len(deck_cases), 11)
        for case in deck_cases:
            with self.subTest(case=case["id"]):
                descriptor = case["candidate"]
                kind = descriptor["kind"]
                if kind == "pinned_copy":
                    candidate: Any = list(pinned_ids)
                elif kind == "pinned_prefix":
                    candidate = list(pinned_ids[: descriptor["length"]])
                elif kind == "pinned_plus":
                    candidate = list(pinned_ids) + [
                        _materialize_typed_item(item)
                        for item in descriptor["items"]
                    ]
                elif kind == "pinned_replace":
                    candidate = list(pinned_ids)
                    candidate[descriptor["index"]] = _materialize_typed_item(
                        descriptor["value"]
                    )
                elif kind == "typed" and descriptor["type"] == "non_list_sequence":
                    candidate = _NonListSequence(list(pinned_ids))
                elif kind == "absent":
                    candidate = None
                else:
                    raise AssertionError("unknown initial-deck candidate descriptor")
                resolution_result = CabtDeckSelectionValidator.resolve(
                    authority,
                    candidate,
                    policy_outcome=case["policy_outcome"],
                )
                self.assertTrue(
                    resolution_result.validate_integrity(authority),
                    case["id"],
                )
                resolution = resolution_result.to_public_dict()
                expected_candidate_reason = case["expected_candidate_reason"]
                self.assertEqual(
                    resolution["candidate_reason_code"],
                    expected_candidate_reason,
                )
                expected = copy.deepcopy(case["expected_resolution"])
                expected.pop("selected_card_ids_ref", None)
                expected["selected_card_ids"] = pinned_ids
                self.assertEqual(resolution, expected)

        invalid_cases = self.vectors["invalid_pinned_deck_cases"]
        self.assertEqual(len(invalid_cases), 8)
        for case in invalid_cases:
            with self.subTest(case=case["id"]):
                mutation = case["authority_mutation"]
                operation = mutation["operation"]
                build_kwargs: dict[str, Any] = {}
                if operation == "truncate_card_ids":
                    invalid = replace(
                        authority,
                        card_ids=authority.card_ids[: mutation["length"]],
                    )
                elif operation == "replace_card_id":
                    card_ids = list(authority.card_ids)
                    card_ids[mutation["index"]] = _materialize_typed_item(
                        mutation["value"]
                    )
                    invalid = replace(authority, card_ids=tuple(card_ids))
                elif operation == "replace_field":
                    invalid = replace(
                        authority,
                        **{mutation["field"]: mutation["value"]},
                    )
                    build_kwargs[mutation["field"]] = mutation["value"]
                elif operation == "replace_card_id_and_hash":
                    card_ids = list(authority.card_ids)
                    card_ids[mutation["index"]] = mutation["value"]
                    invalid = replace(
                        authority,
                        card_ids=tuple(card_ids),
                        deck_hash=mutation["deck_hash"],
                    )
                else:
                    raise AssertionError("unknown invalid-authority mutation")
                invalid_build = CabtDeckSelectionValidator.build_pinned_deck(
                    list(invalid.card_ids),
                    deck_hash=build_kwargs.get("deck_hash", invalid.deck_hash),
                    source_artifact_id=build_kwargs.get(
                        "source_artifact_id", invalid.source_artifact_id
                    ),
                    source_sha256=build_kwargs.get(
                        "source_sha256", invalid.source_sha256
                    ),
                    authority_scope=build_kwargs.get(
                        "authority_scope", invalid.authority_scope
                    ),
                )
                self.assertTrue(
                    invalid_build.validate_integrity(DEFAULT_SELECTION_CONTRACTS),
                    case["id"],
                )
                self.assertFalse(invalid_build.accepted, case["id"])
                resolution = CabtDeckSelectionValidator.resolve(
                    invalid,
                    list(pinned_ids),
                )
                self.assertTrue(
                    resolution.validate_integrity(invalid),
                    case["id"],
                )
                self.assertEqual(
                    resolution.to_public_dict(),
                    case["expected_resolution"],
                )


if __name__ == "__main__":
    unittest.main()
