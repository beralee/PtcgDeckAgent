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
from tools.ptcgdap.build_public_log_cursor_contract import OUTPUTS, build_documents


ROOT = Path(__file__).resolve().parents[2]


class PublicLogCursorContractBuilderTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.built = build_documents()
        cls.schema = load_json_strict(OUTPUTS["schema"])
        cls.profile = load_json_strict(OUTPUTS["profile"])
        cls.vectors = load_json_strict(OUTPUTS["vectors"])
        cls.bundle = load_json_strict(OUTPUTS["bundle"])
        cls.validator = Draft202012Validator(cls.schema)

    def test_checked_in_artifacts_are_exact_reproducible_builder_output(self) -> None:
        self.assertEqual(set(self.built), set(OUTPUTS))
        for artifact_id, path in OUTPUTS.items():
            with self.subTest(artifact_id=artifact_id):
                expected = (json.dumps(self.built[artifact_id], ensure_ascii=False, indent=2) + "\n").encode("utf-8")
                self.assertEqual(path.read_bytes(), expected)
                canonical_json_v1_bytes(load_json_strict(path))

    def test_bundle_binds_exact_three_artifacts_and_parent_firewall_without_cycle(self) -> None:
        self.assertEqual(
            self.bundle["parent_firewall_bundle"],
            {
                "id": "ptcgdap-public-firewall-p2-wp3-v1",
                "canonical_sha256": "A2781CE6B3AC7BB6BAD04A9F15F57CE23AEC338306F60E5B3050B31245685947",
            },
        )
        self.assertEqual(
            self.bundle["p1_contract_canonical_sha256"],
            "2CD02F54538985426EFDB057F3A6BDA4AD154DD171BCC03667D42D102982D294",
        )
        expected = {
            "cabt_public_log_cursor_schema_v1": "contracts/ptcgdap/cabt_public_log_cursor.schema.json",
            "cabt_public_log_cursor_profile_v1": "contracts/ptcgdap/cabt_public_log_cursor_profile.json",
            "cabt_public_log_cursor_conformance_v1": "contracts/ptcgdap/cabt_public_log_cursor_conformance_vectors.json",
        }
        self.assertEqual(len(self.bundle["artifacts"]), 3)
        self.assertEqual({entry["id"]: entry["path"] for entry in self.bundle["artifacts"]}, expected)
        for entry in self.bundle["artifacts"]:
            value = load_json_strict(ROOT / entry["path"])
            self.assertEqual(entry["canonical_sha256"], sha256_bytes(canonical_json_v1_bytes(value)))
        bundle_hash = sha256_bytes(canonical_json_v1_bytes(self.bundle))
        self.assertNotIn(bundle_hash, json.dumps(self.bundle, sort_keys=True))

    def test_schema_accepts_owner_dtos_and_rejects_open_private_or_inconsistent_shapes(self) -> None:
        case = self.vectors["hash_vectors"][1]
        slice_value = {
            "schema_version": 1,
            "profile_id": self.profile["profile_id"],
            **copy.deepcopy(case["payload"]),
            "witness_hash": case["witness_hash"],
        }
        ready = {"status": "slice_ready", "slice": slice_value, "issues": []}
        committed = {
            "status": "committed",
            "committed_ordinal": 1,
            "witness_hash": case["witness_hash"],
            "issues": [],
        }
        rejected = {
            "status": "rejected",
            "slice": None,
            "issues": [{"code": "invalid_firewall_result", "severity": "error"}],
        }
        for value in (slice_value, ready, committed, rejected):
            self.validator.validate(value)

        negatives: list[dict] = []
        private_slice = copy.deepcopy(slice_value)
        private_slice["session_id"] = "PRIVATE_SESSION"
        negatives.append(private_slice)
        private_log = copy.deepcopy(slice_value)
        private_log["logs"][0]["search_begin_input"] = "PRIVATE_SEARCH"
        negatives.append(private_log)
        unknown_log = copy.deepcopy(slice_value)
        unknown_log["logs"][0]["type"] = 24
        negatives.append(unknown_log)
        unsafe_ordinal = copy.deepcopy(slice_value)
        unsafe_ordinal["ordinal"] = 9_007_199_254_740_992
        negatives.append(unsafe_ordinal)
        lowercase_hash = copy.deepcopy(slice_value)
        lowercase_hash["witness_hash"] = case["witness_hash"].lower()
        negatives.append(lowercase_hash)
        bad_ready = copy.deepcopy(ready)
        bad_ready["issues"] = [{"code": "witness_error", "severity": "error"}]
        negatives.append(bad_ready)
        bad_reject = copy.deepcopy(rejected)
        bad_reject["slice"] = slice_value
        negatives.append(bad_reject)
        open_issue = copy.deepcopy(rejected)
        open_issue["issues"][0]["message"] = "PRIVATE_MESSAGE"
        negatives.append(open_issue)
        bad_commit = copy.deepcopy(committed)
        bad_commit["witness_hash"] = None
        negatives.append(bad_commit)
        for index, value in enumerate(negatives):
            with self.subTest(index=index):
                self.assertTrue(list(self.validator.iter_errors(value)))

    def test_profile_prefix_limits_and_closed_errors_match_both_runtime_owners(self) -> None:
        witness = self.profile["witness_contract"]
        self.assertEqual(
            bytes.fromhex(witness["prefix_utf8_hex"]),
            b"PTCGDAP\0CABT_PUBLIC_LOG_SLICE_V1\0",
        )
        self.assertEqual(witness["canonicalization"], "RFC8785-JCS")
        self.assertEqual(self.profile["limits"], {
            "max_logs_per_slice": 4096,
            "max_log_tree_depth": 64,
            "max_log_tree_nodes": 200000,
        })
        self.assertEqual(
            set(self.profile["result_contract"]["error_codes"]),
            {
                "invalid_firewall_result",
                "firewall_result_not_accepted",
                "cursor_contract_error",
                "pending_selection_uncommitted",
                "invalid_slice_result",
                "slice_not_pending",
                "slice_cursor_mismatch",
                "slice_generation_stale",
                "slice_integrity_invalid",
                "source_result_replayed",
                "public_log_limit",
                "witness_error",
            },
        )

    def test_shared_vectors_are_closed_unique_and_bind_all_expected_sequences(self) -> None:
        self.assertEqual(set(self.vectors["sources"]), {
            "initial_empty",
            "regular_empty",
            "turn_draw_ordered",
            "move_attack_ordered",
        })
        self.assertEqual(len(self.vectors["hash_vectors"]), 4)
        self.assertEqual(len(self.vectors["scenarios"]), 9)
        ids = [case["id"] for case in self.vectors["hash_vectors"] + self.vectors["scenarios"]]
        self.assertEqual(len(ids), len(set(ids)))
        for case in self.vectors["hash_vectors"]:
            self.assertEqual(set(case), {"id", "payload", "canonical_json_utf8", "witness_hash"})
            self.assertEqual(set(case["payload"]), {
                "ordinal", "previous_witness", "source_public_observation_hash", "logs",
            })
        rendered = json.dumps(self.vectors, sort_keys=True)
        for sentinel in self.vectors["private_sentinels"]:
            self.assertEqual(rendered.count(sentinel), 1)


if __name__ == "__main__":
    unittest.main()
