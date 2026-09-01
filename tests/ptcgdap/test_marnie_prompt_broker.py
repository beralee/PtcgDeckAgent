from __future__ import annotations

from copy import deepcopy
import json
from pathlib import Path
import shutil
import tempfile
from types import MappingProxyType
import unittest

from scripts.ai.ptcgdap.marnie_prompt_broker import (
    EXPECTED_ARTIFACTS,
    PARENT_BUNDLES,
    MarniePromptBroker,
    MarniePromptBrokerError,
    MarniePromptBrokerResult,
)
from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes


ROOT = Path(__file__).resolve().parents[2]
VECTORS = json.loads(
    (ROOT / "contracts/ptcgdap/marnie_prompt_broker_conformance_vectors.json").read_text(encoding="utf-8")
)
FORBIDDEN = (
    "private_engine_command", "private_object_refs", "private_resolutions",
    "callback_binding_hash", "session_id", "current_source", "ticket", "preflight",
)


def _copy_trust_root(destination: Path) -> None:
    paths = {"contracts/ptcgdap/marnie_prompt_broker_bundle.json"}
    paths.update(value[0] for value in EXPECTED_ARTIFACTS.values())
    paths.update(value[0] for value in PARENT_BUNDLES.values())
    for relative in paths:
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / relative, target)


class MarniePromptBrokerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.owner = MarniePromptBroker.load_default()

    def test_default_owner_runs_all_source_locked_frames_without_live_authority(self) -> None:
        result = self.owner.evaluate_all()
        self.assertTrue(result.validate_integrity(self.owner))
        public = result.to_public_dict()
        self.assertTrue(public["accepted"])
        self.assertEqual(13, public["frame_count"])
        self.assertEqual(11, public["brokered_frame_count"])
        self.assertEqual(0, public["serialized_private_resolution_count"])
        self.assertFalse(public["production_actions_used"])
        self.assertFalse(public["execution_authority"])
        frames = [frame for frame in public["frames"] if frame["status"] == "committed_shadow"]
        self.assertEqual(11, len(frames))
        self.assertEqual(11, len({frame["snapshot_id"] for frame in frames}))
        self.assertEqual(11, len({frame["window_id"] for frame in frames}))
        self.assertEqual(list(range(1, 12)), [frame["binding_version"] for frame in frames])
        serialized = json.dumps(public, sort_keys=True)
        for forbidden in FORBIDDEN:
            self.assertNotIn(forbidden, serialized)

    def test_all_shared_vectors_are_consumed_without_skip_or_mismatch(self) -> None:
        cases = VECTORS["cases"]
        self.assertEqual(23, len(cases))
        self.assertEqual(23, len({case["case_id"] for case in cases}))
        for case in cases:
            with self.subTest(case_id=case["case_id"]):
                self.assertEqual(case["expected"], self.owner.run(case["operation"], case["input"]))

    def test_frontiers_optional_zero_and_lifecycle_chain_are_exact(self) -> None:
        public = self.owner.evaluate_all().to_public_dict()
        by_id = {frame["frame_id"]: frame for frame in public["frames"]}
        self.assertEqual([8, 8, 7, 14], by_id["w3_main"]["option_types"])
        self.assertEqual([7, 13, 12, 14], by_id["w6_shadow_bullet_attack"]["option_types"])
        self.assertEqual([], by_id["w2_setup_bench"]["selected_indexes"])
        self.assertEqual(0, by_id["w2_setup_bench"]["committed_resolution_count"])
        previous = None
        for frame in public["frames"]:
            self.assertEqual(previous, frame["previous_lifecycle_hash"])
            previous = frame["lifecycle_hash"]
        self.assertEqual(previous, public["lifecycle_chain_head"])

    def test_results_are_owner_bound_copy_only_and_mutation_never_echoes(self) -> None:
        with self.assertRaises(TypeError):
            MarniePromptBrokerResult()
        result = self.owner.evaluate_frame("w3_main")
        public = result.to_public_dict()
        changed = deepcopy(public)
        changed["frames"][0]["selected_indexes"] = [999]
        self.assertNotEqual(changed, result.to_public_dict())

        changed["private_engine_command"] = "private-sentinel"
        object.__setattr__(result, "_snapshot", changed)
        self.assertFalse(result.validate_integrity(self.owner))
        safe = result.to_public_dict()
        self.assertFalse(safe["accepted"])
        self.assertNotIn("private-sentinel", json.dumps(safe))

    def test_internal_derived_indexes_and_malformed_slots_fail_closed(self) -> None:
        owner = MarniePromptBroker.load_default()
        frames = dict(owner._frames)
        frames["w1_setup_active"] = frames["w2_setup_bench"]
        object.__setattr__(owner, "_frames", MappingProxyType(frames))
        self.assertEqual(
            {"ok": False, "error_code": "contract_integrity_invalid", "value": None},
            owner.run("audit_snapshot", None),
        )

        for slot, value in (
            ("_documents", None), ("_frames", None), ("_expected", object()),
            ("_document_integrity", "0" * 64), ("_construction_seal", None),
        ):
            with self.subTest(slot=slot):
                damaged = MarniePromptBroker.load_default()
                object.__setattr__(damaged, slot, value)
                self.assertEqual(
                    {"ok": False, "error_code": "contract_integrity_invalid", "value": None},
                    damaged.run("audit_snapshot", None),
                )

    def test_disk_missing_semantic_drift_self_resign_and_canonical_whitespace(self) -> None:
        with tempfile.TemporaryDirectory(prefix="ptcgdap-marnie-broker-missing-") as temp:
            with self.assertRaises(MarniePromptBrokerError) as missing:
                MarniePromptBroker.load_trusted_bundle(Path(temp))
            self.assertEqual("contract_integrity_invalid", missing.exception.code)

        with tempfile.TemporaryDirectory(prefix="ptcgdap-marnie-broker-space-") as temp:
            root = Path(temp)
            _copy_trust_root(root)
            schema_path = root / EXPECTED_ARTIFACTS["schema"][0]
            schema = json.loads(schema_path.read_text(encoding="utf-8"))
            schema_path.write_text("\n  " + json.dumps(schema, ensure_ascii=False) + "\n", encoding="utf-8")
            self.assertEqual(self.owner.bundle_hash(), MarniePromptBroker.load_trusted_bundle(root).bundle_hash())

        with tempfile.TemporaryDirectory(prefix="ptcgdap-marnie-broker-resign-") as temp:
            root = Path(temp)
            _copy_trust_root(root)
            schema_path = root / EXPECTED_ARTIFACTS["schema"][0]
            schema = json.loads(schema_path.read_text(encoding="utf-8"))
            schema["$comment"] = "private-sentinel"
            schema_path.write_text(json.dumps(schema, ensure_ascii=False), encoding="utf-8")
            bundle_path = root / "contracts/ptcgdap/marnie_prompt_broker_bundle.json"
            bundle = json.loads(bundle_path.read_text(encoding="utf-8"))
            bundle["artifacts"][0]["canonical_sha256"] = __import__("hashlib").sha256(
                canonical_json_v1_bytes(schema)
            ).hexdigest().upper()
            bundle_path.write_text(json.dumps(bundle, ensure_ascii=False), encoding="utf-8")
            with self.assertRaises(MarniePromptBrokerError) as resigned:
                MarniePromptBroker.load_trusted_bundle(root)
            self.assertEqual("contract_integrity_invalid", resigned.exception.code)


if __name__ == "__main__":
    unittest.main()
