from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import shutil
import tempfile
import unittest

from scripts.ai.ptcgdap.marnie_portable_policy import MarniePortablePolicy, MarniePortablePolicyError
from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[2]
TRUST_FILES = [
    "contracts/ptcgdap/marnie_portable_policy_bundle.json",
    "contracts/ptcgdap/marnie_portable_policy.schema.json",
    "contracts/ptcgdap/marnie_portable_policy_profile.json",
    "contracts/ptcgdap/marnie_portable_policy_conformance_vectors.json",
    "data/ptcgdap/marnie_vertical_slice/marnie_portable_policy_v1.json",
    "contracts/ptcgdap/marnie_capability_policy_bundle.json",
    "contracts/ptcgdap/marnie_public_base_bundle.json",
]


class MarniePortablePolicyPropertyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.owner = MarniePortablePolicy.load_default()

    def test_actions_bind_exact_ordered_fingerprints_and_parent_owners(self) -> None:
        frames = self.owner.evaluate_all().to_public_dict()["frames"]
        for frame in frames:
            self.assertFalse(frame["authoritative"])
            self.assertFalse(frame["execution_authority"])
            self.assertEqual(len(frame["action"]), len(set(frame["action"]))) if frame["output_domain"] == "current_window_indexes" else None
            if frame["window_id"] is not None:
                self.assertTrue(frame["option_fingerprints"] or frame["frame_id"] == "w2_setup_bench")
                self.assertEqual(
                    [frame["option_fingerprints"][index] for index in frame["action"]],
                    frame["selected_option_fingerprints"],
                )
            if frame["owner_route"] == "base_final":
                self.assertIsNotNone(frame["parent_base_decision_audit_id"])
                self.assertIsNotNone(frame["parent_base_trace_hash"])
            else:
                self.assertIsNone(frame["parent_base_decision_audit_id"])
                self.assertIsNone(frame["parent_base_trace_hash"])

    def test_reorder_stale_and_tie_break_probes_are_public_and_non_authoritative(self) -> None:
        frame = self.owner.evaluate_frame("w3_main").to_public_dict()["frames"][0]
        exact = {
            "frame_id": frame["frame_id"],
            "public_observation_hash": frame["public_observation_hash"],
            "window_id": frame["window_id"],
            "option_fingerprints": copy.deepcopy(frame["option_fingerprints"]),
        }
        self.assertTrue(self.owner.run("verify_binding", exact)["ok"])
        reordered = copy.deepcopy(exact)
        reordered["option_fingerprints"].reverse()
        self.assertEqual("binding_mismatch", self.owner.run("verify_binding", reordered)["error_code"])
        stale = copy.deepcopy(exact)
        stale["window_id"] = "0" * 64
        self.assertEqual("binding_mismatch", self.owner.run("verify_binding", stale)["error_code"])
        for frame_id, expected_hints in (("w4_spikemuth_deck", [0, 1]), ("w5_punk_up_sources", [0, 1, 2, 3, 4])):
            tie = self.owner.run("inspect_tie_break", {"frame_id": frame_id})
            self.assertTrue(tie["ok"])
            self.assertEqual(expected_hints, tie["value"]["adapter_hint_indexes"])
            self.assertEqual([], tie["value"]["base_final_action"])
            self.assertFalse(tie["value"]["authoritative"])

    def test_artifact_parent_and_internal_tampering_fail_closed(self) -> None:
        with tempfile.TemporaryDirectory(prefix="ptcgdap-p5-wp7-tamper-") as temp:
            root = Path(temp)
            for relative in TRUST_FILES:
                destination = root / relative
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT / relative, destination)
            schema_path = root / TRUST_FILES[1]
            schema = load_json_strict(schema_path)
            schema["title"] = "PRIVATE_SENTINEL"
            schema_path.write_text(json.dumps(schema), encoding="utf-8")
            with self.assertRaisesRegex(MarniePortablePolicyError, "contract_integrity_invalid"):
                MarniePortablePolicy.load_trusted_bundle(root)

            shutil.copy2(ROOT / TRUST_FILES[1], schema_path)
            profile_path = root / TRUST_FILES[2]
            profile = load_json_strict(profile_path)
            profile["status"] = "forged"
            profile_path.write_text(json.dumps(profile), encoding="utf-8")
            bundle_path = root / TRUST_FILES[0]
            bundle = load_json_strict(bundle_path)
            bundle["artifacts"][1]["canonical_sha256"] = hashlib.sha256(canonical_json_v1_bytes(profile)).hexdigest().upper()
            bundle_path.write_text(json.dumps(bundle), encoding="utf-8")
            with self.assertRaisesRegex(MarniePortablePolicyError, "contract_integrity_invalid"):
                MarniePortablePolicy.load_trusted_bundle(root)

            shutil.copy2(ROOT / TRUST_FILES[0], bundle_path)
            shutil.copy2(ROOT / TRUST_FILES[2], profile_path)
            parent_path = root / TRUST_FILES[6]
            parent = load_json_strict(parent_path)
            parent["contract_id"] = "forged"
            parent_path.write_text(json.dumps(parent), encoding="utf-8")
            with self.assertRaisesRegex(MarniePortablePolicyError, "parent_contract_invalid"):
                MarniePortablePolicy.load_trusted_bundle(root)

        original = self.owner._frames
        frames = copy.deepcopy(self.owner.evaluate_all().to_public_dict()["frames"])
        frames[3]["action"] = [999999]
        object.__setattr__(self.owner, "_frames", tuple(frames))
        self.assertFalse(self.owner._integrity_valid())
        object.__setattr__(self.owner, "_frames", original)
        self.assertTrue(self.owner._integrity_valid())


if __name__ == "__main__":
    unittest.main()
