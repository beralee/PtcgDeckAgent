from __future__ import annotations

from copy import deepcopy
import json
from pathlib import Path
import shutil
import tempfile
import unittest

from scripts.ai.ptcgdap.marnie_trajectory_replay import (
    MarnieTrajectoryReplay,
    MarnieTrajectoryReplayError,
)
from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict, sha256_bytes


ROOT = Path(__file__).resolve().parents[2]
CONTRACT_ROOT = ROOT / "contracts/ptcgdap"


def materialize(value: object) -> object:
    if isinstance(value, dict):
        if set(value) == {"host_type", "value"} and value["host_type"] == "integer":
            return int(value["value"])
        return {key: materialize(child) for key, child in value.items()}
    if isinstance(value, list):
        return [materialize(child) for child in value]
    return value


class MarnieTrajectoryReplayPropertyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.owner = MarnieTrajectoryReplay.load_default()
        cls.vectors = load_json_strict(CONTRACT_ROOT / "marnie_trajectory_replay_conformance_vectors.json")

    def test_every_shared_vector_is_consumed_with_exact_closed_result(self) -> None:
        self.assertEqual(19, len(self.vectors["cases"]))
        for case in self.vectors["cases"]:
            with self.subTest(case_id=case["case_id"]):
                operation = materialize(case["operation"])
                input_value = materialize(case["input"])
                result = (
                    self.owner.run(input_value["operation"], input_value["value"])
                    if operation == "run"
                    else self.owner.run(operation, input_value)
                )
                if "expected_error_code" in case:
                    self.assertEqual({"ok":False,"error_code":case["expected_error_code"],"value":None}, result)
                    continue
                expected = case["expected"]
                if operation in {"replay_all", "replay_frame"}:
                    self.assertTrue(result["ok"])
                    actual = result["value"]
                    self.assertTrue(actual["accepted"])
                    if operation == "replay_all":
                        self.assertEqual(expected["frame_count"], actual["frame_count"])
                        self.assertEqual(expected["chain_head"], actual["chain_head"])
                    else:
                        self.assertEqual(expected["frame"], actual["frames"][0])
                else:
                    self.assertEqual(expected, result)

    def test_frame_reorder_internal_mutation_and_cross_owner_binding_fail_closed(self) -> None:
        clean = self.owner.replay_frame("w2_setup_bench")
        second = MarnieTrajectoryReplay.load_default()
        self.assertFalse(clean.validate_integrity(second))
        replay_copy = load_json_strict(ROOT / "data/ptcgdap/marnie_vertical_slice/w0_w7_firewall_replay_v1.json")
        replay_copy["frames"] = list(reversed(replay_copy["frames"]))
        object.__setattr__(self.owner, "_replay", replay_copy)
        self.assertFalse(self.owner._integrity_valid())
        self.assertFalse(clean.validate_integrity(self.owner))
        with self.assertRaises(MarnieTrajectoryReplayError) as caught:
            clean.to_public_dict()
        self.assertEqual("result_integrity_invalid", caught.exception.code)
        object.__setattr__(self.owner, "_replay", MarnieTrajectoryReplay.load_default()._replay)
        self.assertTrue(self.owner._integrity_valid())

    def test_disk_whitespace_is_canonical_but_semantic_and_self_resigned_drift_reject(self) -> None:
        with tempfile.TemporaryDirectory(prefix="ptcgdap-p5-wp2-replay-") as temp:
            root = Path(temp)
            shutil.copytree(ROOT / "contracts/ptcgdap", root / "contracts/ptcgdap")
            shutil.copytree(ROOT / "data/ptcgdap/marnie_vertical_slice", root / "data/ptcgdap/marnie_vertical_slice")
            replay_path = root / "data/ptcgdap/marnie_vertical_slice/w0_w7_firewall_replay_v1.json"
            original = replay_path.read_bytes()
            replay_path.write_bytes(original + b"\n \t\n")
            self.assertEqual(
                MarnieTrajectoryReplay.load_default().bundle_hash(),
                MarnieTrajectoryReplay.load_trusted_bundle(root).bundle_hash(),
            )
            replay = json.loads(original)
            replay["frames"][0]["frame_id"] = "PRIVATE_SENTINEL"
            replay_path.write_text(json.dumps(replay, indent=2) + "\n", encoding="utf-8")
            with self.assertRaises(MarnieTrajectoryReplayError) as caught:
                MarnieTrajectoryReplay.load_trusted_bundle(root)
            self.assertEqual("replay_artifact_hash_mismatch", caught.exception.code)

            bundle_path = root / "contracts/ptcgdap/marnie_trajectory_replay_bundle.json"
            bundle = load_json_strict(bundle_path)
            new_hash = sha256_bytes(canonical_json_v1_bytes(replay))
            next(entry for entry in bundle["artifacts"] if entry["id"] == "w0_w7_firewall_replay_v1")["canonical_sha256"] = new_hash
            bundle_path.write_text(json.dumps(bundle, indent=2) + "\n", encoding="utf-8")
            with self.assertRaises(MarnieTrajectoryReplayError) as caught:
                MarnieTrajectoryReplay.load_trusted_bundle(root)
            self.assertEqual("replay_bundle_trust_anchor_mismatch", caught.exception.code)


if __name__ == "__main__":
    unittest.main()
