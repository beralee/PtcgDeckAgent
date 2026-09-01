from __future__ import annotations

import copy
from dataclasses import replace
from pathlib import Path
import unittest

from scripts.ai.ptcgdap.cabt_selection import (
    CabtDeckSelectionValidator,
    CabtDeterministicFallback,
    CabtInitialDeckResolution,
    CabtPinnedDeckAuthority,
    CabtPinnedDeckBuildResult,
    CabtSelectionBuildResult,
    CabtSelectionContracts,
    CabtSelectionIssue,
    CabtSelectionResolution,
    CabtSelectionSanitizer,
    CabtSelectionValidation,
    CabtSelectionWindow,
    DEFAULT_SELECTION_CONTRACTS,
    build_cabt_selection_window,
    initial_deck_hash,
)
from scripts.ai.ptcgdap.contract_set import load_contract_set
from scripts.ai.ptcgdap.source_lock import load_json_strict


ROOT = Path(__file__).resolve().parents[2]
VECTORS_PATH = ROOT / "contracts" / "ptcgdap" / "cabt_selection_conformance_vectors.json"


class CabtSelectionApiTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        vectors = load_json_strict(VECTORS_PATH)
        cls.window_case = next(
            case for case in vectors["window_cases"] if case["id"] == "ordered_multi"
        )

    def _build_window(self) -> CabtSelectionWindow:
        case = self.window_case
        result = build_cabt_selection_window(
            case["select"],
            public_observation_hash=case["public_observation_hash"],
            public_hash_authority=case["public_hash_authority"],
            chooser_player_index=case["chooser_player_index"],
        )
        self.assertTrue(result.policy_allowed)
        assert result.window is not None
        return result.window

    def test_wp3_public_owners_are_available_without_host_or_engine_dependencies(self) -> None:
        self.assertIsNotNone(CabtSelectionWindow)
        self.assertIsNotNone(CabtSelectionSanitizer)
        self.assertIsNotNone(CabtDeterministicFallback)
        self.assertIsNotNone(CabtDeckSelectionValidator)

    def test_window_direct_replace_and_post_build_mutation_cannot_gain_authority(self) -> None:
        window = self._build_window()
        with self.assertRaises(TypeError):
            CabtSelectionWindow()
        with self.assertRaises(TypeError):
            replace(window, min_count=0)
        object.__setattr__(window, "min_count", 0)
        with self.assertRaises(ValueError):
            CabtSelectionSanitizer.validate(window, [])
        with self.assertRaises(ValueError):
            CabtDeterministicFallback.resolve(window)

    def test_authority_requires_exact_tuple_ints_and_exact_string_fields(self) -> None:
        authority = CabtDeckSelectionValidator.build_marnie_conformance_authority()

        class StringSubtype(str):
            pass

        invalid_authorities = (
            replace(
                authority,
                card_ids=tuple(float(card_id) for card_id in authority.card_ids),
            ),
            replace(authority, card_ids=list(authority.card_ids)),
            replace(authority, deck_hash=StringSubtype(authority.deck_hash)),
        )
        changed_ids = list(authority.card_ids)
        changed_ids[-1] += 1
        invalid_authorities += (
            replace(
                authority,
                card_ids=tuple(changed_ids),
                deck_hash=initial_deck_hash(changed_ids),
            ),
        )
        for invalid in invalid_authorities:
            self.assertIsInstance(invalid, CabtPinnedDeckAuthority)
            resolution = CabtDeckSelectionValidator.resolve(
                invalid,
                list(authority.card_ids),
            )
            self.assertFalse(resolution.accepted)
            self.assertEqual(resolution.reason_code, "invalid_pinned_deck")

    def test_public_fallback_reason_is_closed_and_never_echoes_caller_text(self) -> None:
        sentinel = "private-sentinel-must-not-be-echoed"
        for reason in (sentinel, None, 7):
            resolution = CabtDeterministicFallback.resolve(
                self._build_window(),
                reason_code=reason,
            )
            self.assertEqual(resolution.reason_code, "policy_unavailable")
            self.assertNotIn(sentinel, str(resolution.to_public_dict()))
        accepted = CabtDeterministicFallback.resolve(
            self._build_window(),
            reason_code="invalid_policy_output",
        )
        self.assertEqual(accepted.reason_code, "invalid_policy_output")

    def test_contracts_and_sanitizer_policy_entry_are_immutable_and_public(self) -> None:
        self.assertIsInstance(DEFAULT_SELECTION_CONTRACTS, CabtSelectionContracts)
        with self.assertRaises(TypeError):
            CabtSelectionContracts()
        resolution = CabtSelectionSanitizer.resolve_policy_attempt(
            self._build_window(),
            [0, 99],
            outcome="returned",
        )
        self.assertEqual(resolution.owner, "deterministic_fallback")
        self.assertEqual(resolution.reason_code, "invalid_policy_output")

        tampered = CabtSelectionContracts.from_contract_set(
            load_contract_set(ROOT / "contracts" / "ptcgdap")
        )
        object.__setattr__(
            tampered,
            "public_hash_authorities",
            frozenset({"caller_self_attested"}),
        )
        case = self.window_case
        with self.assertRaises(TypeError):
            build_cabt_selection_window(
                case["select"],
                public_observation_hash=case["public_observation_hash"],
                public_hash_authority="caller_self_attested",
                chooser_player_index=case["chooser_player_index"],
                contracts=tampered,
            )

    def test_mutating_the_public_default_contract_cannot_redefine_its_own_trust_baseline(self) -> None:
        original_authorities = DEFAULT_SELECTION_CONTRACTS.public_hash_authorities
        object.__setattr__(
            DEFAULT_SELECTION_CONTRACTS,
            "public_hash_authorities",
            frozenset({"caller_self_attested"}),
        )
        try:
            case = self.window_case
            with self.assertRaises(TypeError):
                build_cabt_selection_window(
                    case["select"],
                    public_observation_hash=case["public_observation_hash"],
                    public_hash_authority="caller_self_attested",
                    chooser_player_index=case["chooser_player_index"],
                )
        finally:
            object.__setattr__(
                DEFAULT_SELECTION_CONTRACTS,
                "public_hash_authorities",
                original_authorities,
            )

    def test_owner_results_reject_ordinary_construction_and_detect_mutation(self) -> None:
        with self.assertRaises(TypeError):
            CabtSelectionIssue("invalid_card", "/select/contextCard")
        with self.assertRaises(TypeError):
            CabtSelectionBuildResult("reject", None, ())
        with self.assertRaises(TypeError):
            CabtSelectionValidation(True, (0,), "policy_selection_accepted")
        with self.assertRaises(TypeError):
            CabtSelectionResolution(
                True,
                "A" * 64,
                (0,),
                "policy",
                "policy_selection_accepted",
                None,
            )
        with self.assertRaises(TypeError):
            CabtPinnedDeckBuildResult()
        with self.assertRaises(TypeError):
            CabtInitialDeckResolution(
                True,
                (1,),
                "initial_candidate",
                "pinned_deck_accepted",
                None,
                "A" * 64,
                "pinned_deck_accepted",
            )

        case = self.window_case
        build_result = build_cabt_selection_window(
            case["select"],
            public_observation_hash=case["public_observation_hash"],
            public_hash_authority=case["public_hash_authority"],
            chooser_player_index=case["chooser_player_index"],
        )
        self.assertTrue(build_result.validate_integrity())
        assert build_result.window is not None
        validation = CabtSelectionSanitizer.validate(
            build_result.window,
            case["accepted_ordered_proposal"],
        )
        self.assertTrue(validation.validate_integrity(build_result.window))
        resolution = CabtSelectionSanitizer.resolve_policy_attempt(
            build_result.window,
            case["accepted_ordered_proposal"],
        )
        self.assertTrue(resolution.validate_integrity(build_result.window))

        pinned_build = CabtDeckSelectionValidator.build_pinned_deck()
        self.assertTrue(
            pinned_build.validate_integrity(DEFAULT_SELECTION_CONTRACTS)
        )
        equivalent_contracts = CabtSelectionContracts.from_contract_set(
            load_contract_set(ROOT / "contracts" / "ptcgdap")
        )
        self.assertIsNot(equivalent_contracts, DEFAULT_SELECTION_CONTRACTS)
        self.assertFalse(pinned_build.validate_integrity(equivalent_contracts))
        authority = pinned_build.pinned_deck
        assert authority is not None
        deck_resolution = CabtDeckSelectionValidator.resolve(
            authority,
            list(authority.card_ids),
        )
        self.assertTrue(deck_resolution.validate_integrity(authority))
        second_pinned_build = CabtDeckSelectionValidator.build_pinned_deck()
        second_authority = second_pinned_build.pinned_deck
        assert second_authority is not None
        self.assertIsNot(second_authority, authority)
        self.assertFalse(deck_resolution.validate_integrity(second_authority))

        reject_result = build_cabt_selection_window(
            case["select"],
            public_observation_hash="a" * 64,
            public_hash_authority=case["public_hash_authority"],
            chooser_player_index=case["chooser_player_index"],
        )
        self.assertTrue(reject_result.validate_integrity())
        issue = reject_result.issues[0]

        original_public = {
            "issue": issue.to_public_dict(),
            "build": build_result.to_public_dict(),
            "validation": validation.to_public_dict(),
            "resolution": resolution.to_public_dict(),
            "pinned_build": pinned_build.to_public_dict(),
            "deck_resolution": deck_resolution.to_public_dict(),
        }
        sentinel = "private-sentinel-must-not-be-echoed"
        object.__setattr__(issue, "code", sentinel)
        object.__setattr__(validation, "selected_indexes", (999_999,))
        object.__setattr__(resolution, "selected_indexes", (999_999,))
        object.__setattr__(deck_resolution, "selected_card_ids", (1,))
        object.__setattr__(build_result, "decision_state", "reject")
        object.__setattr__(pinned_build, "reason_code", sentinel)
        for value in (
            issue,
            build_result,
            validation,
            resolution,
            pinned_build,
            deck_resolution,
        ):
            object.__setattr__(
                value,
                "_public_snapshot",
                {"reason_code": sentinel, "selected_indexes": [999_999]},
            )

        self.assertFalse(issue.validate_integrity())
        self.assertFalse(validation.validate_integrity(build_result.window))
        self.assertFalse(resolution.validate_integrity(build_result.window))
        self.assertFalse(deck_resolution.validate_integrity(authority))
        self.assertFalse(build_result.validate_integrity())
        self.assertFalse(
            pinned_build.validate_integrity(DEFAULT_SELECTION_CONTRACTS)
        )
        for label, value in (
            ("issue", issue),
            ("build", build_result),
            ("validation", validation),
            ("resolution", resolution),
            ("pinned_build", pinned_build),
            ("deck_resolution", deck_resolution),
        ):
            serialized = value.to_public_dict()
            self.assertEqual(serialized, original_public[label])
            self.assertNotIn(sentinel, str(serialized))

    def test_unregistered_copies_fail_and_results_bind_the_exact_window(self) -> None:
        window_a = self._build_window()
        case = self.window_case
        select_b = copy.deepcopy(case["select"])
        select_b["option"][0]["serial"] += 1000
        result_b = build_cabt_selection_window(
            select_b,
            public_observation_hash=case["public_observation_hash"],
            public_hash_authority=case["public_hash_authority"],
            chooser_player_index=case["chooser_player_index"],
        )
        self.assertTrue(result_b.validate_integrity())
        assert result_b.window is not None
        window_b = result_b.window
        self.assertNotEqual(window_a.window_id, window_b.window_id)
        proposal = case["accepted_ordered_proposal"]
        validation = CabtSelectionSanitizer.validate(window_a, proposal)
        resolution = CabtSelectionSanitizer.resolve_policy_attempt(
            window_a,
            proposal,
        )
        self.assertFalse(validation.validate_integrity(window_b))
        self.assertFalse(resolution.validate_integrity(window_b))

        forged = object.__new__(CabtSelectionValidation)
        for field_name in (
            "accepted",
            "selected_indexes",
            "reason_code",
            "_window_binding",
            "_construction_seal",
            "_public_snapshot",
        ):
            object.__setattr__(forged, field_name, getattr(validation, field_name))
        self.assertFalse(forged.validate_integrity(window_a))
        self.assertEqual(forged.to_public_dict(), {})


if __name__ == "__main__":
    unittest.main()
