from __future__ import annotations

from copy import deepcopy
import json
from pathlib import Path
import tempfile
import unittest

from scripts.ai.ptcgdap.marnie_identity_projection import (
    MarnieIdentityProjection,
    MarnieIdentityProjectionError,
)
from scripts.ai.ptcgdap.source_lock import load_json_strict


ROOT = Path(__file__).resolve().parents[2]
VECTOR_PATH = ROOT / "contracts/ptcgdap/marnie_identity_projection_conformance_vectors.json"


def materialize(value: object) -> object:
    if type(value) is dict and value.get("host_type") == "integer" and set(value) == {"host_type", "value"}:
        return value["value"]
    if type(value) is dict:
        return {key: materialize(child) for key, child in value.items()}
    if type(value) is list:
        return [materialize(child) for child in value]
    return value


class MarnieIdentityProjectionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.runtime = MarnieIdentityProjection.load_default()
        cls.vectors = load_json_strict(VECTOR_PATH)

    def test_default_owner_is_bundle_bound_and_audit_only(self) -> None:
        self.assertTrue(self.runtime.validate_integrity())
        snapshot = self.runtime.audit_snapshot()
        self.assertEqual(13, snapshot["frame_count"])
        self.assertEqual(34, snapshot["distinct_official_card_id_count"])
        self.assertEqual(94, snapshot["cross_frame_unique_serial_count"])
        self.assertFalse(snapshot["execution_authority"])
        self.assertFalse(snapshot["production_actions_used"])

    def test_all_shared_vectors_match_exactly_and_never_echo_private_values(self) -> None:
        self.assertEqual(23, len(self.vectors["cases"]))
        for case in self.vectors["cases"]:
            with self.subTest(case=case["case_id"]):
                result = self.runtime.run(case["operation"], materialize(deepcopy(case["input"])))
                self.assertEqual(case["expected"], result)
                text = json.dumps(result, sort_keys=True)
                self.assertNotIn("private_sentinel", text)
                self.assertNotIn("host_pokemon_entity_serial", text)

    def test_output_is_copy_only_and_internal_tamper_fails_closed(self) -> None:
        first = self.runtime.audit_all()
        first["value"]["frames"][1]["distinct_official_card_ids"][0] = 9999
        self.assertNotEqual(first, self.runtime.audit_all())
        object.__setattr__(self.runtime, "_audit", None)
        self.assertFalse(self.runtime.validate_integrity())
        self.assertEqual(
            {"ok": False, "error_code": "identity_integrity_invalid", "value": None},
            self.runtime.audit_all(),
        )

    def test_relation_cache_rebaseline_is_rejected(self) -> None:
        runtime = MarnieIdentityProjection.load_default()
        object.__setattr__(runtime, "_known_cards", frozenset())
        object.__setattr__(runtime, "_runtime_integrity_sha256", runtime._runtime_integrity_sha256)
        self.assertFalse(runtime.validate_integrity())
        self.assertEqual(
            {"ok": False, "error_code": "identity_integrity_invalid", "value": None},
            runtime.audit_all(),
        )

    def test_bundle_and_artifact_semantic_drift_are_rejected(self) -> None:
        with tempfile.TemporaryDirectory(prefix="ptcgdap-p5-wp4-") as temp:
            copy_root = Path(temp)
            for relative in [
                "contracts/ptcgdap/marnie_identity_projection_bundle.json",
                "contracts/ptcgdap/marnie_identity_projection.schema.json",
                "contracts/ptcgdap/marnie_identity_projection_profile.json",
                "contracts/ptcgdap/marnie_identity_projection_conformance_vectors.json",
                "data/ptcgdap/marnie_vertical_slice/marnie_identity_projection_v1.json",
            ]:
                target = copy_root / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes((ROOT / relative).read_bytes())
            bundle_path = copy_root / "contracts/ptcgdap/marnie_identity_projection_bundle.json"
            bundle = load_json_strict(bundle_path)
            bundle["status"] = "forged_live"
            bundle_path.write_text(json.dumps(bundle), encoding="utf-8")
            with self.assertRaisesRegex(MarnieIdentityProjectionError, "identity_bundle_trust_anchor_mismatch"):
                MarnieIdentityProjection.load_trusted_bundle(copy_root)

    def test_runtime_has_no_live_engine_or_mapping_inference_dependency(self) -> None:
        source = (ROOT / "scripts/ai/ptcgdap/marnie_identity_projection.py").read_text(encoding="utf-8")
        for forbidden in ["GameState", "GameStateMachine", "BattleScene", "AIOpponent", "CardInstance", "PokemonSlot", "CardDatabase", "CardCatalogIndex", "name", "image", "text", "network", "subprocess", "ctypes"]:
            self.assertNotIn(forbidden, source)


if __name__ == "__main__":
    unittest.main()
