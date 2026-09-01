from __future__ import annotations

import copy
from pathlib import Path
import tempfile
import unittest

from scripts.ai.ptcgdap.marnie_vertical_slice import MarnieVerticalSlice, MarnieVerticalSliceError
from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict, sha256_bytes


ROOT = Path(__file__).resolve().parents[2]
VECTORS = load_json_strict(ROOT / "contracts/ptcgdap/marnie_vertical_slice_conformance_vectors.json")


class _StringSubclass(str):
    pass


def materialize(value: object) -> object:
    if type(value) is dict:
        if value.get("host_type") == "string_name" and set(value) == {"host_type", "value"}:
            return _StringSubclass(value["value"])
        return {key: materialize(child) for key, child in value.items()}
    if type(value) is list:
        return [materialize(child) for child in value]
    return value


class MarnieVerticalSliceTests(unittest.TestCase):
    def setUp(self) -> None:
        self.runtime = MarnieVerticalSlice.load_default()

    def test_shared_vectors_and_copy_only_results(self) -> None:
        self.assertEqual(10, len(VECTORS["cases"]))
        for case in VECTORS["cases"]:
            with self.subTest(case=case["id"]):
                result = self.runtime.run(case["operation"], materialize(copy.deepcopy(case["input"])))
                if "expected_error" in case:
                    self.assertFalse(result["ok"])
                    self.assertEqual(case["expected_error"], result["error_code"])
                    self.assertIsNone(result["value"])
                else:
                    self.assertTrue(result["ok"], result)
                    self.assertEqual(case["expected"], result["value"])
                mutated = copy.deepcopy(result)
                mutated["value"] = "PRIVATE_MUTATION_SENTINEL"
                self.assertNotEqual(mutated, self.runtime.run(case["operation"], materialize(copy.deepcopy(case["input"]))))

    def test_artifact_access_is_deep_copy_and_internal_tamper_fails_closed(self) -> None:
        frame = self.runtime.frame("w4_spikemuth_deck")
        self.assertEqual("w4_spikemuth_deck", frame["frame_id"])
        frame["window"]["options"][0]["index"] = 999999
        self.assertNotEqual(999999, self.runtime.frame("w4_spikemuth_deck")["window"]["options"][0].get("index"))
        object.__setattr__(self.runtime, "_trajectory", {"PRIVATE": "SENTINEL"})
        with self.assertRaises(MarnieVerticalSliceError) as raised:
            self.runtime.frame("w3_main")
        self.assertEqual("fixture_integrity_invalid", raised.exception.code)

    def test_disk_bundle_anchor_rejects_missing_drift_and_self_consistent_resign(self) -> None:
        bundle_path = ROOT / "contracts/ptcgdap/marnie_vertical_slice_bundle.json"
        bundle = load_json_strict(bundle_path)
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_root = Path(temp_dir)
            target_bundle = temp_root / "contracts/ptcgdap/marnie_vertical_slice_bundle.json"
            target_bundle.parent.mkdir(parents=True)
            target_bundle.write_bytes(bundle_path.read_bytes())
            for entry in bundle["artifacts"]:
                target = temp_root / entry["path"]
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes((ROOT / entry["path"]).read_bytes())

            self.assertEqual(MarnieVerticalSlice.load_default().bundle_hash(), MarnieVerticalSlice.load_trusted_bundle(temp_root).bundle_hash())
            trajectory_entry = next(entry for entry in bundle["artifacts"] if entry["id"] == "w0_w7_public_trajectory_v1")
            trajectory_path = temp_root / trajectory_entry["path"]
            original = trajectory_path.read_bytes()
            trajectory_path.write_bytes(original + b"\n  \n")
            self.assertEqual(MarnieVerticalSlice.load_default().bundle_hash(), MarnieVerticalSlice.load_trusted_bundle(temp_root).bundle_hash())

            trajectory = load_json_strict(trajectory_path)
            trajectory["frames"][0]["callback_role"] = "PRIVATE_MUTATION_SENTINEL"
            trajectory_path.write_bytes(canonical_json_v1_bytes(trajectory))
            with self.assertRaises(MarnieVerticalSliceError) as drift:
                MarnieVerticalSlice.load_trusted_bundle(temp_root)
            self.assertEqual("fixture_artifact_hash_mismatch", drift.exception.code)

            resigned = copy.deepcopy(bundle)
            for entry in resigned["artifacts"]:
                if entry["id"] == "w0_w7_public_trajectory_v1":
                    entry["canonical_sha256"] = sha256_bytes(canonical_json_v1_bytes(trajectory))
            target_bundle.write_bytes(canonical_json_v1_bytes(resigned))
            with self.assertRaises(MarnieVerticalSliceError) as resigned_error:
                MarnieVerticalSlice.load_trusted_bundle(temp_root)
            self.assertEqual("fixture_bundle_trust_anchor_mismatch", resigned_error.exception.code)

            target_bundle.write_bytes(bundle_path.read_bytes())
            trajectory_path.unlink()
            with self.assertRaises(MarnieVerticalSliceError) as missing:
                MarnieVerticalSlice.load_trusted_bundle(temp_root)
            self.assertEqual("fixture_file_missing", missing.exception.code)


if __name__ == "__main__":
    unittest.main()
