from __future__ import annotations

import copy
import json
import unittest
from pathlib import Path

from jsonschema import Draft202012Validator

from scripts.ai.ptcgdap.source_lock import (
    canonical_json_v1_bytes,
    load_json_strict,
    sha256_bytes,
)
from tools.ptcgdap.build_public_firewall_contract import OUTPUTS, build_all


ROOT = Path(__file__).resolve().parents[2]
CONTRACT_ROOT = ROOT / "contracts" / "ptcgdap"


class PublicFirewallContractBuilderTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.built = build_all()
        cls.schema = load_json_strict(OUTPUTS["schema"])
        cls.profile = load_json_strict(OUTPUTS["profile"])
        cls.vectors = load_json_strict(OUTPUTS["vectors"])
        cls.bundle = load_json_strict(OUTPUTS["bundle"])
        cls.validator = Draft202012Validator(cls.schema)

    def test_checked_in_artifacts_are_exact_builder_output(self) -> None:
        for name, path in OUTPUTS.items():
            with self.subTest(name=name):
                expected = (json.dumps(self.built[name], ensure_ascii=False, indent=2) + "\n").encode("utf-8")
                self.assertEqual(path.read_bytes(), expected)

    def test_bundle_binds_exact_three_artifacts_and_unchanged_parent(self) -> None:
        self.assertEqual(
            self.bundle["parent_contract"],
            {
                "id": "ptcgdap-cabt-contract-p1-wp3-v1",
                "path": "contracts/ptcgdap/cabt_contract_bundle.json",
                "canonical_sha256": "2CD02F54538985426EFDB057F3A6BDA4AD154DD171BCC03667D42D102982D294",
            },
        )
        expected = {
            "cabt_public_observation_schema_v1": "contracts/ptcgdap/cabt_public_observation.schema.json",
            "cabt_public_firewall_profile_v1": "contracts/ptcgdap/cabt_public_firewall_profile.json",
            "cabt_public_firewall_conformance_v1": "contracts/ptcgdap/cabt_public_firewall_conformance_vectors.json",
        }
        self.assertEqual(len(self.bundle["artifacts"]), 3)
        self.assertEqual(
            {entry["id"]: entry["path"] for entry in self.bundle["artifacts"]},
            expected,
        )
        for entry in self.bundle["artifacts"]:
            value = load_json_strict(ROOT / entry["path"])
            self.assertEqual(entry["canonical_sha256"], sha256_bytes(canonical_json_v1_bytes(value)))
        bundle_text = json.dumps(self.bundle, sort_keys=True)
        self.assertNotIn(sha256_bytes(canonical_json_v1_bytes(self.bundle)), bundle_text)

    def test_schema_accepts_owner_shapes_and_rejects_private_or_open_dtos(self) -> None:
        accepted_case = next(case for case in self.vectors["cases"] if case["status"] == "accepted")
        contract_hash = sha256_bytes(canonical_json_v1_bytes(self.bundle))
        accepted = {
            "schema_version": 1,
            "profile_id": self.profile["profile_id"],
            "source_contract_hash": self.profile["parent_contract"]["canonical_sha256"],
            "firewall_contract_hash": contract_hash,
            "status": "accepted",
            "public_observation": accepted_case["expected_public_observation"],
            "public_observation_hash": accepted_case["expected_public_observation_hash"],
            "provenance": [{
                "output_pointer": "/select",
                "source_pointer": "/select",
                "visibility": "official_public",
                "authority": "official_cabt_wire",
                "transform": "exact_copy",
            }],
            "issues": [],
        }
        self.validator.validate(accepted)
        rejected = {
            **accepted,
            "status": "rejected",
            "public_observation": None,
            "public_observation_hash": None,
            "provenance": [],
            "issues": [{"code": "opponent_hand_exposed", "pointer": "/current/players/1/hand", "severity": "error"}],
        }
        self.validator.validate(rejected)

        negatives = []
        private_field = copy.deepcopy(accepted)
        private_field["raw_private_hash"] = "A" * 64
        negatives.append(private_field)
        private_tree = copy.deepcopy(accepted)
        private_tree["public_observation"]["search_begin_input"] = "secret"
        negatives.append(private_tree)
        private_pointer = copy.deepcopy(rejected)
        private_pointer["issues"][0]["pointer"] = "/PRIVATE_SENTINEL"
        negatives.append(private_pointer)
        bad_relation = copy.deepcopy(accepted)
        bad_relation["public_observation_hash"] = None
        negatives.append(bad_relation)
        bad_reject = copy.deepcopy(rejected)
        bad_reject["public_observation"] = accepted["public_observation"]
        negatives.append(bad_reject)
        extra_card_name = copy.deepcopy(accepted)
        current = extra_card_name["public_observation"].get("current")
        if current is not None:
            current["players"][0]["hand"][0]["name"] = "PRIVATE_NAME"
            negatives.append(extra_card_name)
        for index, value in enumerate(negatives):
            with self.subTest(index=index):
                self.assertTrue(list(self.validator.iter_errors(value)))

    def test_vectors_are_closed_unique_and_expected_outputs_contain_no_sentinel(self) -> None:
        cases = self.vectors["cases"]
        self.assertEqual(len(cases), 23)
        self.assertEqual(len({case["id"] for case in cases}), len(cases))
        self.assertEqual({case["status"] for case in cases}, {"accepted", "rejected"})
        closed_case_keys = {
            "id",
            "base",
            "mutations",
            "status",
            "expected_public_observation",
            "expected_public_observation_hash",
            "expected_issue_code",
        }
        for case in cases:
            self.assertEqual(set(case), closed_case_keys)
            output_text = json.dumps(
                {
                    "tree": case["expected_public_observation"],
                    "hash": case["expected_public_observation_hash"],
                    "issue": case["expected_issue_code"],
                },
                sort_keys=True,
            )
            for sentinel in self.vectors["sentinel_strings"]:
                self.assertNotIn(sentinel, output_text)
        self.assertEqual(
            set(self.profile["result_contract"]["error_codes"]),
            {
                "invalid_envelope",
                "envelope_not_policy_eligible",
                "source_contract_mismatch",
                "firewall_contract_error",
                "initial_shape_mismatch",
                "invalid_your_index",
                "invalid_player_count",
                "own_hand_not_visible",
                "opponent_hand_exposed",
                "prize_identity_exposed",
                "own_active_concealed",
                "unauthorized_select_deck",
                "opponent_draw_identity_exposed",
                "public_projection_limit",
                "public_hash_error",
                "result_integrity_invalid",
            },
        )

    def test_contract_artifacts_use_canonical_json_subset(self) -> None:
        for path in OUTPUTS.values():
            with self.subTest(path=path.name):
                value = load_json_strict(path)
                canonical_json_v1_bytes(value)


if __name__ == "__main__":
    unittest.main()
