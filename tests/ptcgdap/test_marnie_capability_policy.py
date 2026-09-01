from __future__ import annotations

from copy import deepcopy
import json
from pathlib import Path
import tempfile
import unittest

from scripts.ai.ptcgdap.marnie_capability_policy import (
    MarnieCapabilityPolicy,
    MarnieCapabilityPolicyError,
    MarnieCapabilityPolicyResult,
)


EXPECTED_INDEXES = {
    "w1_setup_active": [0],
    "w2_setup_bench": [],
    "w3_main": [0],
    "w4_spikemuth_deck": [1],
    "w5_punk_up_sources": [0, 1, 2, 3, 4],
    "w5_punk_up_target_1": [0],
    "w5_punk_up_target_2": [0],
    "w6_shadow_bullet_attack": [1],
    "w6_shadow_bullet_target": [0],
    "w7_take_prize": [0],
    "w7_forced_send_out": [0],
}


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
VECTORS_PATH = REPOSITORY_ROOT / "contracts/ptcgdap/marnie_capability_policy_conformance_vectors.json"


def _materialize_host_value(value: object) -> object:
    if type(value) is dict and set(value) == {"host_type", "value"}:
        if value["host_type"] == "integer":
            return int(value["value"])
        raise AssertionError(f"unknown host vector type: {value['host_type']!r}")
    if type(value) is dict:
        return {key: _materialize_host_value(child) for key, child in value.items()}
    if type(value) is list:
        return [_materialize_host_value(child) for child in value]
    return value


class MarnieCapabilityPolicyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.policy = MarnieCapabilityPolicy.load_default()
        cls.vectors = json.loads(VECTORS_PATH.read_text(encoding="utf-8"))

    def test_every_shared_vector_is_consumed_without_mismatch_or_skip(self) -> None:
        cases = self.vectors["cases"]
        self.assertEqual(23, len(cases))
        self.assertEqual(23, len({case["case_id"] for case in cases}))
        for case in cases:
            with self.subTest(case_id=case["case_id"]):
                actual = self.policy.run(
                    case["operation"],
                    _materialize_host_value(case["input"]),
                )
                self.assertEqual(case["expected"], actual)

    def test_all_source_locked_frames_have_deterministic_non_authoritative_results(self) -> None:
        result = self.policy.evaluate_all()
        self.assertTrue(result.validate_integrity(self.policy))
        public = result.to_public_dict()
        self.assertEqual(13, public["frame_count"])
        self.assertFalse(public["execution_authority"])
        self.assertFalse(public["production_actions_used"])
        by_id = {frame["frame_id"]: frame for frame in public["frames"]}
        self.assertEqual(set(EXPECTED_INDEXES) | {"w0_initial", "w7_terminal"}, set(by_id))
        for frame_id, indexes in EXPECTED_INDEXES.items():
            frame = by_id[frame_id]
            self.assertEqual("accepted", frame["status"])
            self.assertEqual("current_window_indexes", frame["selection_domain"])
            self.assertEqual(indexes, frame["selected_indexes"])
            self.assertIsNone(frame["selected_card_ids"])
            self.assertFalse(frame["execution_authority"])
        initial = by_id["w0_initial"]
        self.assertEqual("official_initial_deck_fixture", initial["reason_code"])
        self.assertEqual("initial_deck_card_ids", initial["selection_domain"])
        self.assertEqual(60, len(initial["selected_card_ids"]))
        self.assertIsNone(initial["selected_indexes"])
        terminal = by_id["w7_terminal"]
        self.assertEqual("not_applicable_terminal", terminal["status"])
        self.assertEqual("terminal_no_callback", terminal["reason_code"])
        self.assertEqual("none", terminal["selection_domain"])
        self.assertIsNone(terminal["selected_indexes"])
        self.assertIsNone(terminal["selected_card_ids"])

    def test_capability_specific_public_rules_do_not_use_production_action(self) -> None:
        by_id = {item["frame_id"]: item for item in self.policy.evaluate_all().to_public_dict()["frames"]}
        self.assertEqual("spikemuth_tutor", by_id["w4_spikemuth_deck"]["capability_id"])
        self.assertEqual("public_deck_card_id", by_id["w4_spikemuth_deck"]["rule_id"])
        self.assertEqual("punk_up", by_id["w5_punk_up_sources"]["capability_id"])
        self.assertEqual("all_public_deck_card_id", by_id["w5_punk_up_sources"]["rule_id"])
        self.assertEqual("shadow_bullet", by_id["w6_shadow_bullet_attack"]["capability_id"])
        self.assertEqual("official_attack_id", by_id["w6_shadow_bullet_attack"]["rule_id"])
        self.assertTrue(all(not item["production_action_used"] for item in by_id.values()))

    def test_uniform_runner_fail_closed(self) -> None:
        self.assertEqual(
            {"ok": False, "error_code": "input_type_invalid", "value": None},
            self.policy.run("evaluate_frame", {"frame_id": 1}),
        )
        self.assertEqual(
            {"ok": False, "error_code": "frame_unknown", "value": None},
            self.policy.run("evaluate_frame", {"frame_id": "private_sentinel"}),
        )
        self.assertEqual(
            {"ok": False, "error_code": "operation_unknown", "value": None},
            self.policy.run("private_sentinel", {}),
        )
        self.assertNotIn("private_sentinel", repr(self.policy.audit_snapshot()))

    def test_results_are_owner_bound_copy_only_and_mutation_fails_closed(self) -> None:
        with self.assertRaises(MarnieCapabilityPolicyError) as direct:
            MarnieCapabilityPolicyResult()
        self.assertEqual("direct_construction_forbidden", direct.exception.code)
        result = self.policy.evaluate_frame("w6_shadow_bullet_attack")
        public = result.to_public_dict()
        changed = deepcopy(public)
        changed["frames"][0]["selected_indexes"] = [999]
        self.assertNotEqual(changed, result.to_public_dict())
        object.__setattr__(result, "_snapshot", changed)
        self.assertFalse(result.validate_integrity(self.policy))
        with self.assertRaises(MarnieCapabilityPolicyError) as mutated:
            result.to_public_dict()
        self.assertEqual("result_integrity_invalid", mutated.exception.code)

    def test_disk_bundle_missing_drift_and_self_resign_fail_before_parent_load(self) -> None:
        with tempfile.TemporaryDirectory(prefix="ptcgdap-marnie-policy-") as temp:
            root = Path(temp)
            with self.assertRaises(MarnieCapabilityPolicyError) as missing:
                MarnieCapabilityPolicy.load_trusted_bundle(root)
            self.assertEqual("policy_file_missing", missing.exception.code)
            target = root / "contracts/ptcgdap/marnie_capability_policy_bundle.json"
            target.parent.mkdir(parents=True)
            bundle = json.loads(
                (REPOSITORY_ROOT / "contracts/ptcgdap/marnie_capability_policy_bundle.json").read_text(encoding="utf-8")
            )
            drift = deepcopy(bundle)
            drift["status"] = "private_sentinel"
            target.write_text(json.dumps(drift, ensure_ascii=False), encoding="utf-8")
            with self.assertRaises(MarnieCapabilityPolicyError) as changed:
                MarnieCapabilityPolicy.load_trusted_bundle(root)
            self.assertEqual("policy_bundle_trust_anchor_mismatch", changed.exception.code)
            resigned = deepcopy(bundle)
            resigned["artifacts"][0]["canonical_sha256"] = "0" * 64
            target.write_text(json.dumps(resigned, ensure_ascii=False), encoding="utf-8")
            with self.assertRaises(MarnieCapabilityPolicyError) as self_signed:
                MarnieCapabilityPolicy.load_trusted_bundle(root)
            self.assertEqual("policy_bundle_trust_anchor_mismatch", self_signed.exception.code)


if __name__ == "__main__":
    unittest.main()
