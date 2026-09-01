from __future__ import annotations

import copy
import hashlib
import importlib
import unittest
from pathlib import Path
from typing import Any

from jsonschema import Draft202012Validator


ROOT = Path(__file__).resolve().parents[2]

from scripts.ai.ptcgdap.cabt_tree_hash import jcs_canonical_json_bytes
from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


CONTRACT_ROOT = ROOT / "contracts" / "ptcgdap"
SCHEMA_PATH = CONTRACT_ROOT / "cabt_selection_window.schema.json"
PROFILE_PATH = CONTRACT_ROOT / "cabt_selection_profile.json"
VECTORS_PATH = CONTRACT_ROOT / "cabt_selection_conformance_vectors.json"
SOURCE_LOCK_PATH = ROOT / "docs" / "ptcgdap" / "SOURCE_LOCK.json"

PREFIXES = {
    "cabt_selection_window_v1": b"PTCGDAP\x00CABT_SELECTION_WINDOW_V1\x00",
    "cabt_option_fingerprint_v1": b"PTCGDAP\x00CABT_OPTION_FINGERPRINT_V1\x00",
    "cabt_initial_deck_v1": b"PTCGDAP\x00CABT_INITIAL_DECK_V1\x00",
}


def _digest(profile: str, payload: Any) -> str:
    digest = hashlib.sha256()
    digest.update(PREFIXES[profile])
    digest.update(jcs_canonical_json_bytes(payload))
    return digest.hexdigest().upper()


def _walk(value: Any):
    yield value
    if type(value) is dict:
        for child in value.values():
            yield from _walk(child)
    elif type(value) is list:
        for child in value:
            yield from _walk(child)


def _fingerprint_payload(
    *, window_id: str, public_hash: str, select: dict[str, Any], option_index: int
) -> dict[str, Any]:
    return {
        "window_id": window_id,
        "public_observation_hash": public_hash,
        "option_index": option_index,
        "select_type_raw": select["type"],
        "select_context_raw": select["context"],
        "option": select["option"][option_index],
        "context_card": select["contextCard"],
        "effect": select["effect"],
    }


def _window_public(case: dict[str, Any]) -> dict[str, Any]:
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


def _definition_validator(schema: dict[str, Any], name: str) -> Draft202012Validator:
    root_window = {
        key: copy.deepcopy(schema[key])
        for key in (
            "type",
            "additionalProperties",
            "required",
            "properties",
            "oneOf",
            "x-ptcgdap-runtime-invariants",
        )
    }
    definitions = copy.deepcopy(schema["$defs"])
    definitions["cabtWindow"] = root_window

    def redirect_root_ref(value: Any) -> Any:
        if type(value) is dict:
            return {
                key: (
                    "#/$defs/cabtWindow"
                    if key == "$ref" and child == "#"
                    else redirect_root_ref(child)
                )
                for key, child in value.items()
            }
        if type(value) is list:
            return [redirect_root_ref(child) for child in value]
        return value

    definitions[name] = redirect_root_ref(definitions[name])
    wrapper = {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$ref": f"#/$defs/{name}",
        "$defs": definitions,
    }
    Draft202012Validator.check_schema(wrapper)
    return Draft202012Validator(wrapper)


class CabtSelectionContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.schema = load_json_strict(SCHEMA_PATH)
        cls.profile = load_json_strict(PROFILE_PATH)
        cls.vectors = load_json_strict(VECTORS_PATH)

    def test_artifacts_are_strict_canonical_json_v1_inputs_without_embedded_final_digest(self) -> None:
        for artifact in (self.schema, self.profile, self.vectors):
            canonical_json_v1_bytes(artifact)
            self.assertFalse(any(type(node) is float for node in _walk(artifact)))
            keys = {
                key
                for node in _walk(artifact)
                if type(node) is dict
                for key in node
            }
            self.assertNotIn("self_hash", keys)
            self.assertNotIn("final_bundle_hash", keys)

    def test_profile_closes_authority_states_hash_domains_and_unknown_key_diagnostics(self) -> None:
        self.assertEqual(self.profile["profile_id"], "cabt_selection_profile_v1")
        self.assertEqual(
            set(self.profile["decision_states"]),
            {"policy_allowed", "fallback_only", "reject"},
        )
        self.assertEqual(
            self.profile["input_authority"]["accepted_public_hash_authorities"],
            ["firewall_accepted", "conformance_fixture"],
        )
        profiles = self.profile["hash_contract"]["profiles"]
        self.assertEqual(set(profiles), set(PREFIXES))
        for profile_id, prefix in PREFIXES.items():
            prefix_hex = profiles[profile_id]["prefix_utf8_hex"]
            self.assertIs(type(prefix_hex), str)
            self.assertGreater(len(prefix_hex), 0)
            self.assertEqual(len(prefix_hex) % 2, 0)
            self.assertTrue(
                all(character in "0123456789ABCDEF" for character in prefix_hex)
            )
            self.assertEqual(prefix_hex, prefix.hex().upper())
            self.assertEqual(bytes.fromhex(prefix_hex), prefix)
            self.assertNotIn("prefix", profiles[profile_id])
        self.assertIn(
            "stable parent JSON pointer",
            self.profile["select_contract"]["unknown_additive_diagnostic"],
        )
        self.assertIn(
            "never echo",
            self.profile["select_contract"]["unknown_additive_diagnostic"],
        )
        self.assertIn(
            "force fallback_only",
            self.profile["option_contract"]["known_type_rule"],
        )
        result_contract = self.profile["result_serialization_contract"]
        self.assertIn("never authorizes", result_contract["not_authority"])
        self.assertIn("No execution layer may accept", result_contract["consumer_rule"])
        self.assertIn("same call path", result_contract["consumer_rule"])
        self.assertIn("not a cryptographic", result_contract["owner_provenance"])
        self.assertIn("schema-valid dictionary never grants authority", result_contract["mutation_rule"])
        reasons = self.profile["reason_codes"]
        self.assertIn("window_fallback_only", reasons["sanitize"])
        self.assertEqual(
            set(reasons["pinned_deck_build"]),
            {"pinned_deck_accepted", "invalid_pinned_deck"},
        )
        self.assertEqual(
            set(reasons["initial_deck_resolution"]),
            {"pinned_deck_accepted", "pinned_deck_fallback", "invalid_pinned_deck"},
        )
        self.assertNotIn("initial_deck", reasons)
        self.assertNotIn("deck_hash_mismatch", str(reasons))

    def test_schema_freezes_window_and_cross_runtime_result_shapes(self) -> None:
        self.assertFalse(self.schema["additionalProperties"])
        self.assertEqual(
            set(self.schema["properties"]),
            {
                "window_version",
                "window_id",
                "hash_profile",
                "option_fingerprint_profile",
                "public_observation_hash",
                "public_hash_authority",
                "chooser_player_index",
                "decision_state",
                "fallback_reasons",
                "select_type_raw",
                "select_context_raw",
                "min_count",
                "max_count",
                "remain_damage_counter",
                "remain_energy_cost",
                "context_card",
                "effect",
                "public_deck_candidates",
                "options",
                "option_fingerprints",
            },
        )
        self.assertTrue(
            {
                "buildIssue",
                "windowBuildResult",
                "selectionValidation",
                "selectionResolution",
                "pinnedDeckAuthority",
                "pinnedDeckBuildResult",
                "initialDeckResolution",
            }.issubset(self.schema["$defs"])
        )
        self.assertEqual(
            set(self.schema["$defs"]["windowBuildResult"]["properties"]),
            {"decision_state", "window", "issues"},
        )
        self.assertEqual(
            set(self.schema["$defs"]["selectionResolution"]["properties"]),
            {
                "accepted",
                "window_id",
                "selected_indexes",
                "owner",
                "reason_code",
                "fallback_branch",
            },
        )
        self.assertEqual(
            set(self.schema["$defs"]["initialDeckResolution"]["properties"]),
            {
                "accepted",
                "selected_card_ids",
                "owner",
                "reason_code",
                "candidate_reason_code",
                "fallback_branch",
                "deck_hash",
            },
        )
        public_property_names = {
            key
            for node in _walk(self.schema["properties"])
            if type(node) is dict
            for key in node
        }
        for forbidden in (
            "raw_private_hash",
            "token_free_callback_hash",
            "callback_binding_hash",
            "search_begin_input",
            "known_select_type",
            "known_select_context",
        ):
            self.assertNotIn(forbidden, public_property_names)

    def test_schema_executes_closed_result_and_issue_relationships(self) -> None:
        validators = {
            name: _definition_validator(self.schema, name)
            for name in (
                "buildIssue",
                "windowBuildResult",
                "selectionValidation",
                "selectionResolution",
                "pinnedDeckBuildResult",
                "initialDeckResolution",
            )
        }
        windows = {case["id"]: case for case in self.vectors["window_cases"]}
        policy_window = _window_public(windows["ordered_multi"])
        fallback_window = _window_public(windows["unknown_select_type"])
        window_validator = Draft202012Validator(self.schema)
        window_validator.validate(policy_window)
        build_results = (
            {
                "decision_state": "policy_allowed",
                "window": policy_window,
                "issues": [],
            },
            {
                "decision_state": "fallback_only",
                "window": fallback_window,
                "issues": [
                    {
                        "code": "unknown_select_type",
                        "pointer": "/select/type",
                        "severity": "error",
                    }
                ],
            },
            {
                "decision_state": "reject",
                "window": None,
                "issues": [
                    {
                        "code": "invalid_public_observation_hash",
                        "pointer": "",
                        "severity": "error",
                    }
                ],
            },
        )
        for value in build_results:
            validators["windowBuildResult"].validate(value)
        for value in (
            {"code": "select_not_object", "pointer": "", "severity": "error"},
            {"code": "missing_select_field", "pointer": "", "severity": "error"},
            {"code": "unknown_public_key", "pointer": "", "severity": "error"},
        ):
            validators["buildIssue"].validate(value)
        for case in self.vectors["sanitizer_cases"]:
            validators["selectionValidation"].validate(case["expected_validation"])
            resolution = {
                "window_id": windows[case["window_case_id"]]["expected_window_id"],
                **case["expected_resolution"],
            }
            validators["selectionResolution"].validate(resolution)
        for case in self.vectors["policy_fault_cases"]:
            resolution = {
                "window_id": windows[case["window_case_id"]]["expected_window_id"],
                **case["expected_resolution"],
            }
            validators["selectionResolution"].validate(resolution)

        deck = self.vectors["initial_deck_fixture"]
        authority = {
            "profile": deck["profile"],
            "card_ids": deck["card_ids"],
            "deck_hash": deck["deck_hash"],
            "source_artifact_id": deck["source_artifact_id"],
            "source_sha256": deck["source_sha256"],
            "authority_scope": deck["authority_scope"],
        }
        validators["pinnedDeckBuildResult"].validate(
            {
                "accepted": True,
                "reason_code": "pinned_deck_accepted",
                "pinned_deck": authority,
            }
        )
        validators["pinnedDeckBuildResult"].validate(
            {
                "accepted": False,
                "reason_code": "invalid_pinned_deck",
                "pinned_deck": None,
            }
        )
        initial_results = []
        for case in self.vectors["initial_deck_cases"]:
            result = copy.deepcopy(case["expected_resolution"])
            result.pop("selected_card_ids_ref", None)
            result["selected_card_ids"] = deck["card_ids"]
            initial_results.append(result)
        initial_results.extend(
            copy.deepcopy(case["expected_resolution"])
            for case in self.vectors["invalid_pinned_deck_cases"]
        )
        for value in initial_results:
            validators["initialDeckResolution"].validate(value)

        valid_policy = {
            "accepted": True,
            "window_id": policy_window["window_id"],
            "selected_indexes": [2, 0],
            "owner": "policy",
            "reason_code": "policy_selection_accepted",
            "fallback_branch": None,
        }
        valid_fallback = {
            "accepted": True,
            "window_id": policy_window["window_id"],
            "selected_indexes": [0, 1],
            "owner": "deterministic_fallback",
            "reason_code": "window_fallback_only",
            "fallback_branch": "first_minimum",
        }
        invalid_values = (
            (
                "buildIssue",
                {
                    "code": "unknown_select_type",
                    "pointer": "/select/deck/999",
                    "severity": "error",
                },
            ),
            (
                "buildIssue",
                {
                    "code": "invalid_card",
                    "pointer": "/select/type",
                    "severity": "error",
                },
            ),
            (
                "buildIssue",
                {
                    "code": "invalid_card",
                    "pointer": "/private/sentinel",
                    "severity": "error",
                },
            ),
            (
                "selectionResolution",
                {**valid_policy, "reason_code": "private-sentinel"},
            ),
            (
                "selectionResolution",
                {**valid_policy, "fallback_branch": "first_minimum"},
            ),
            (
                "selectionResolution",
                {**valid_fallback, "fallback_branch": None},
            ),
            (
                "selectionValidation",
                {
                    "accepted": False,
                    "selected_indexes": [0],
                    "reason_code": "proposal_cardinality",
                },
            ),
            (
                "selectionValidation",
                {
                    "accepted": True,
                    "selected_indexes": [0, 0],
                    "reason_code": "policy_selection_accepted",
                },
            ),
            (
                "selectionValidation",
                {
                    "accepted": True,
                    "selected_indexes": [9007199254740992],
                    "reason_code": "policy_selection_accepted",
                },
            ),
            (
                "selectionResolution",
                {**valid_policy, "selected_indexes": [0, 0]},
            ),
            (
                "selectionResolution",
                {**valid_policy, "selected_indexes": [9007199254740992]},
            ),
            (
                "windowBuildResult",
                {
                    "decision_state": "reject",
                    "window": policy_window,
                    "issues": build_results[2]["issues"],
                },
            ),
            (
                "initialDeckResolution",
                {**initial_results[0], "selected_card_ids": [1]},
            ),
            (
                "initialDeckResolution",
                {
                    **initial_results[-1],
                    "candidate_reason_code": "deck_mismatch",
                    "deck_hash": deck["deck_hash"],
                },
            ),
        )
        for definition, value in invalid_values:
            with self.subTest(definition=definition, value=value):
                self.assertFalse(validators[definition].is_valid(value))
        for field_name in ("min_count", "max_count"):
            with self.subTest(window_field=field_name):
                self.assertFalse(
                    window_validator.is_valid(
                        {**policy_window, field_name: 9007199254740992}
                    )
                )

    def test_vector_sections_and_case_identifiers_are_closed_and_unique(self) -> None:
        self.assertEqual(
            set(self.vectors),
            {
                "schema_version",
                "vector_set_id",
                "profile_id",
                "source_lock_id",
                "artifact_policy",
                "constants",
                "hash_conformance_cases",
                "option_type_matrix",
                "window_cases",
                "build_reject_cases",
                "sanitizer_cases",
                "policy_fault_cases",
                "initial_deck_fixture",
                "initial_deck_cases",
                "invalid_pinned_deck_cases",
            },
        )
        case_lists = [
            self.vectors["hash_conformance_cases"],
            self.vectors["option_type_matrix"]["cases"],
            self.vectors["window_cases"],
            self.vectors["build_reject_cases"],
            self.vectors["sanitizer_cases"],
            self.vectors["policy_fault_cases"],
            self.vectors["initial_deck_cases"],
            self.vectors["invalid_pinned_deck_cases"],
        ]
        case_ids = [case["id"] for cases in case_lists for case in cases]
        self.assertEqual(len(case_ids), len(set(case_ids)))
        self.assertEqual(
            set(self.profile["policy_outcomes"]),
            {"returned", "exception", "timeout", "unavailable"},
        )
        section_keys = {
            "hash_conformance_cases": (
                {"id", "profile", "payload", "expected_canonical_utf8", "expected_digest"},
                set(),
            ),
            "window_cases": (
                {
                    "id",
                    "public_observation_hash",
                    "public_hash_authority",
                    "chooser_player_index",
                    "select",
                    "expected_decision_state",
                    "expected_fallback_reasons",
                    "expected_window_id",
                    "expected_option_fingerprints",
                    "expected_fallback",
                    "expected_fallback_branch",
                },
                {"accepted_ordered_proposal"},
            ),
            "build_reject_cases": (
                {
                    "id",
                    "base_window_case_id",
                    "mutation",
                    "expected_decision_state",
                    "expected_issue_code",
                    "expected_issue_pointer",
                },
                {"base_section", "forbidden_diagnostic_substrings"},
            ),
            "sanitizer_cases": (
                {
                    "id",
                    "window_case_id",
                    "proposal",
                    "expected_validation",
                    "expected_resolution",
                },
                {"forbidden_partial_result"},
            ),
            "policy_fault_cases": (
                {"id", "window_case_id", "policy_outcome", "expected_resolution"},
                {"proposal"},
            ),
            "initial_deck_cases": (
                {
                    "id",
                    "policy_outcome",
                    "candidate",
                    "expected_candidate_reason",
                    "expected_resolution",
                },
                set(),
            ),
            "invalid_pinned_deck_cases": (
                {"id", "authority_mutation", "expected_resolution"},
                set(),
            ),
        }
        for section, (required, optional) in section_keys.items():
            for case in self.vectors[section]:
                with self.subTest(section=section, case=case["id"]):
                    self.assertEqual(set(case) - optional, required)
                    self.assertTrue(set(case).issubset(required | optional))

        option_cases = self.vectors["option_type_matrix"]["cases"]
        for case in option_cases:
            self.assertEqual(
                set(case),
                {
                    "id",
                    "raw_option_type",
                    "option",
                    "expected_decision_state",
                    "expected_window_id",
                    "expected_fingerprint",
                },
            )

    def test_explicit_hash_vectors_freeze_payload_canonical_utf8_and_digest(self) -> None:
        covered = set()
        for case in self.vectors["hash_conformance_cases"]:
            profile = case["profile"]
            covered.add(profile)
            canonical = jcs_canonical_json_bytes(case["payload"])
            self.assertEqual(canonical.decode("utf-8"), case["expected_canonical_utf8"], case["id"])
            self.assertEqual(_digest(profile, case["payload"]), case["expected_digest"], case["id"])
        self.assertEqual(covered, set(PREFIXES))

    def test_all_seventeen_official_option_types_have_exact_hash_vectors(self) -> None:
        matrix = self.vectors["option_type_matrix"]
        self.assertEqual(
            [case["raw_option_type"] for case in matrix["cases"]], list(range(17))
        )
        common = matrix["common"]
        for case in matrix["cases"]:
            select = copy.deepcopy(common["select_without_option"])
            select["option"] = [copy.deepcopy(case["option"])]
            window_payload = {
                "chooser_player_index": common["chooser_player_index"],
                "public_observation_hash": common["public_observation_hash"],
                "select": select,
            }
            window_id = _digest("cabt_selection_window_v1", window_payload)
            self.assertEqual(window_id, case["expected_window_id"], case["id"])
            fingerprint = _digest(
                "cabt_option_fingerprint_v1",
                _fingerprint_payload(
                    window_id=window_id,
                    public_hash=common["public_observation_hash"],
                    select=select,
                    option_index=0,
                ),
            )
            self.assertEqual(fingerprint, case["expected_fingerprint"], case["id"])

    def test_window_vectors_freeze_strict_cardinality_fallback_and_every_fingerprint(self) -> None:
        states = set()
        branches = set()
        by_id = {case["id"]: case for case in self.vectors["window_cases"]}
        for case in by_id.values():
            select = case["select"]
            self.assertLessEqual(0, select["minCount"], case["id"])
            self.assertLessEqual(select["minCount"], select["maxCount"], case["id"])
            self.assertLessEqual(select["maxCount"], len(select["option"]), case["id"])
            window_id = _digest(
                "cabt_selection_window_v1",
                {
                    "chooser_player_index": case["chooser_player_index"],
                    "public_observation_hash": case["public_observation_hash"],
                    "select": select,
                },
            )
            self.assertEqual(window_id, case["expected_window_id"], case["id"])
            actual_fingerprints = [
                _digest(
                    "cabt_option_fingerprint_v1",
                    _fingerprint_payload(
                        window_id=window_id,
                        public_hash=case["public_observation_hash"],
                        select=select,
                        option_index=index,
                    ),
                )
                for index in range(len(select["option"]))
            ]
            self.assertEqual(actual_fingerprints, case["expected_option_fingerprints"], case["id"])
            states.add(case["expected_decision_state"])
            branches.add(case["expected_fallback_branch"])
        self.assertEqual(states, {"policy_allowed", "fallback_only"})
        self.assertEqual(branches, {"optional_zero", "forced_all", "first_minimum"})
        self.assertNotEqual(by_id["reorder_a"]["expected_window_id"], by_id["reorder_b"]["expected_window_id"])
        self.assertNotEqual(by_id["identity_serial_41"]["expected_window_id"], by_id["identity_serial_42"]["expected_window_id"])
        self.assertNotEqual(by_id["public_hash_a"]["expected_window_id"], by_id["public_hash_b"]["expected_window_id"])
        self.assertNotEqual(
            by_id["present_null_sparse_drift"]["expected_option_fingerprints"],
            by_id["missing_sparse_field"]["expected_option_fingerprints"],
        )

    def test_reject_vectors_cover_hard_cardinality_and_key_name_side_channel(self) -> None:
        cases = {case["id"]: case for case in self.vectors["build_reject_cases"]}
        self.assertIn("select_not_object_rejected", cases)
        self.assertEqual(
            cases["select_not_object_rejected"]["expected_issue_pointer"],
            "/select",
        )
        self.assertIn("max_greater_than_option_count_rejected", cases)
        self.assertEqual(
            cases["max_greater_than_option_count_rejected"]["expected_issue_code"],
            "invalid_cardinality",
        )
        for case_id in (
            "unknown_select_key_rejected_without_echo",
            "unknown_option_key_rejected_without_echo",
            "unknown_card_key_rejected_without_echo",
        ):
            case = cases[case_id]
            self.assertEqual(case["expected_decision_state"], "reject")
            self.assertEqual(case["expected_issue_code"], "unknown_public_key")
            self.assertNotIn(case["mutation"]["key"], case["expected_issue_pointer"])
            self.assertNotIn(str(case["mutation"]["value"]), case["expected_issue_pointer"])

    def test_sanitizer_and_fault_vectors_cover_atomic_rejection_and_all_outcomes(self) -> None:
        sanitizer = {case["id"]: case for case in self.vectors["sanitizer_cases"]}
        reasons = {case["expected_validation"]["reason_code"] for case in sanitizer.values()}
        self.assertTrue(
            {
                "policy_selection_accepted",
                "proposal_not_list",
                "proposal_index_not_exact_int",
                "proposal_cardinality",
                "proposal_index_out_of_range",
                "proposal_duplicate_index",
            }.issubset(reasons)
        )
        atomic = sanitizer["invalid_proposal_is_discarded_atomically"]
        self.assertEqual(atomic["expected_validation"]["selected_indexes"], [])
        self.assertNotEqual(
            atomic["expected_resolution"]["selected_indexes"],
            atomic["forbidden_partial_result"],
        )
        float_case = sanitizer["proposal_float_index"]["proposal"]
        self.assertEqual(float_case["items"][0], {"type": "float", "decimal": "0.0"})
        outcomes = {case["policy_outcome"] for case in self.vectors["policy_fault_cases"]}
        self.assertEqual(outcomes, {"returned", "exception", "timeout", "unavailable"})

    def test_only_source_locked_marnie_authority_is_pinned_and_faults_fall_back_to_it(self) -> None:
        deck = self.vectors["initial_deck_fixture"]
        self.assertEqual(len(deck["card_ids"]), 60)
        self.assertTrue(all(type(card_id) is int and 0 < card_id <= 2**53 - 1 for card_id in deck["card_ids"]))
        self.assertEqual(
            _digest("cabt_initial_deck_v1", {"card_ids": deck["card_ids"]}),
            deck["deck_hash"],
        )
        source_lock = load_json_strict(SOURCE_LOCK_PATH)
        source = next(
            artifact
            for artifact in source_lock["artifacts"]
            if artifact["id"] == "candidate_official_marnie_deck"
        )
        self.assertEqual(source["sha256"], deck["source_sha256"])
        self.assertEqual(deck["authority_scope"], "source_locked_conformance_fixture_only")
        self.assertFalse(deck["local_mapping_claim"])
        self.assertFalse(deck["cabt_exportable_claim"])
        normative = self.profile["initial_deck_contract"]["conformance_authority"]
        self.assertEqual(
            normative,
            {
                "artifact_id": deck["source_artifact_id"],
                "source_sha256": deck["source_sha256"],
                "scope": deck["authority_scope"],
                "card_ids": deck["card_ids"],
                "deck_hash": deck["deck_hash"],
                "local_mapping_claim": deck["local_mapping_claim"],
                "cabt_exportable_claim": deck["cabt_exportable_claim"],
            },
        )
        self.assertIn(
            "never production runtime configuration",
            self.profile["initial_deck_contract"]["only_accepted_p1_wp3_authority"],
        )
        pinned_schema = self.schema["$defs"]["pinnedDeckAuthority"]["properties"]
        self.assertEqual(pinned_schema["card_ids"]["const"], deck["card_ids"])
        self.assertEqual(pinned_schema["deck_hash"]["const"], deck["deck_hash"])
        self.assertEqual(pinned_schema["source_artifact_id"]["const"], deck["source_artifact_id"])
        self.assertEqual(pinned_schema["source_sha256"]["const"], deck["source_sha256"])
        self.assertEqual(pinned_schema["authority_scope"]["const"], deck["authority_scope"])
        cases = {case["id"]: case for case in self.vectors["initial_deck_cases"]}
        self.assertEqual(len(cases), 11)
        for case in cases.values():
            self.assertEqual(
                case["expected_resolution"]["candidate_reason_code"],
                case["expected_candidate_reason"],
                case["id"],
            )
        for case_id in (
            "candidate_59_falls_back",
            "candidate_61_falls_back",
            "candidate_boolean_card_falls_back",
            "candidate_unsafe_integer_card_falls_back",
            "candidate_sequence_mismatch_falls_back",
            "candidate_exception_falls_back",
            "candidate_timeout_falls_back",
            "candidate_unavailable_falls_back",
        ):
            expected = cases[case_id]["expected_resolution"]
            self.assertTrue(expected["accepted"], case_id)
            self.assertEqual(expected["owner"], "pinned_deck_fallback", case_id)
            self.assertEqual(expected["fallback_branch"], "pinned_verified_deck", case_id)
        arbitrary = next(
            case
            for case in self.vectors["invalid_pinned_deck_cases"]
            if case["id"] == "arbitrary_self_consistent_60_rejected"
        )
        self.assertFalse(arbitrary["expected_resolution"]["accepted"])
        self.assertEqual(len(self.vectors["invalid_pinned_deck_cases"]), 8)

    def test_runtime_api_exists_for_the_contract_first_red_gate(self) -> None:
        module = importlib.import_module("scripts.ai.ptcgdap.cabt_selection")
        for symbol in (
            "CabtSelectionWindow",
            "CabtSelectionSanitizer",
            "CabtDeterministicFallback",
            "CabtDeckSelectionValidator",
        ):
            self.assertTrue(hasattr(module, symbol), symbol)


if __name__ == "__main__":
    unittest.main()
