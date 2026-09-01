from __future__ import annotations

import copy
import json
import unittest
from pathlib import Path

from scripts.ai.ptcgdap.engine_decision_port import EngineDecisionPort


ROOT = Path(__file__).resolve().parents[2]
VECTORS = json.loads((ROOT / "contracts/ptcgdap/engine_decision_port_conformance_vectors.json").read_text(encoding="utf-8"))


class CardRef:
    pass


def materialize(value, refs):
    if isinstance(value, str) and value.startswith("card:"):
        return refs.setdefault(value, CardRef())
    if isinstance(value, list):
        return [materialize(item, refs) for item in value]
    if isinstance(value, dict):
        return {key: materialize(item, refs) for key, item in value.items()}
    return value


class EngineDecisionPortTests(unittest.TestCase):
    def test_shared_publish_vectors(self) -> None:
        for case in VECTORS["publish_cases"]:
            with self.subTest(case=case["id"]):
                refs = {}
                port = EngineDecisionPort(case["match_generation"])
                result = port.publish(materialize(case["source"], refs), case["decision_generation"], case["chooser_player_index"])
                self.assertEqual(result.accepted, case["expected"]["accepted"])
                self.assertEqual(result.error_code, case["expected"]["error_code"])
                public = result.to_public_dict()
                self.assertEqual(set(public), {"accepted", "error_code", "audit"})
                if result.accepted:
                    self.assertTrue(result.validate_integrity(port))
                    self.assertTrue(result.snapshot.validate_integrity(port))
                    audit = result.snapshot.to_audit_dict()
                    self.assertFalse(audit["authoritative"])
                    self.assertEqual(audit["authority"], "engine_decision_port_shadow")
                    self.assertNotIn("card:", json.dumps(audit))
                    rebound = port.rebind(result.snapshot, materialize(case["source"], refs))
                    self.assertTrue(rebound["ok"], rebound)
                    self.assertEqual(rebound["value"]["turn_action_count"], case["source"]["turn_action_count"])
                    expected_types = [] if case["source"]["select"] is None else [item["type"] for item in case["source"]["select"]["option"]]
                    actual_types = [] if rebound["value"]["select"] is None else [item["type"] for item in rebound["value"]["select"]["option"]]
                    self.assertEqual(actual_types, expected_types)
                else:
                    self.assertIsNone(result.snapshot)

    def test_generation_replacement_is_atomic_and_stale(self) -> None:
        source = materialize(VECTORS["publish_cases"][1]["source"], {})
        for case in VECTORS["transition_cases"]:
            with self.subTest(case=case["id"]):
                port = EngineDecisionPort(1)
                snapshots = []
                actual = []
                for generation in case["generations"]:
                    result = port.publish(source, generation, 0)
                    actual.append(result.error_code)
                    if result.accepted:
                        snapshots.append(result.snapshot)
                self.assertEqual(actual, case["expected"])
                if len(snapshots) > 1:
                    self.assertEqual(port.rebind(snapshots[0], source)["error_code"], "snapshot_not_current")
                    self.assertTrue(port.rebind(snapshots[-1], source)["ok"])

    def test_mutation_reorder_reference_release_cross_port_and_dto_copy_fail_closed(self) -> None:
        refs = {}
        source = materialize(VECTORS["publish_cases"][3]["source"], refs)
        port = EngineDecisionPort(1)
        result = port.publish(source, 1, 1)
        snapshot = result.snapshot
        self.assertTrue(port.rebind(snapshot, source)["ok"])
        source["select"]["option"].reverse()
        source["option_card_refs"].reverse()
        self.assertIn(port.rebind(snapshot, source)["error_code"], {"source_mutated", "reference_released"})

        source = materialize(VECTORS["publish_cases"][3]["source"], {})
        port = EngineDecisionPort(1)
        snapshot = port.publish(source, 1, 1).snapshot
        source["option_card_refs"][0] = CardRef()
        self.assertIn(port.rebind(snapshot, source)["error_code"], {"source_mutated", "reference_released"})

        source = materialize(VECTORS["publish_cases"][3]["source"], {})
        port = EngineDecisionPort(1)
        snapshot = port.publish(source, 1, 1).snapshot
        other = EngineDecisionPort(1)
        self.assertEqual(other.rebind(snapshot, source)["error_code"], "snapshot_owner_mismatch")
        dto = copy.deepcopy(snapshot.to_audit_dict())
        self.assertEqual(port.rebind(dto, source)["error_code"], "snapshot_integrity_invalid")
        dto["snapshot_id"] = "F" * 64
        self.assertNotIn("F" * 64, json.dumps(snapshot.to_audit_dict()))
        snapshot._audit["select"] = {"private_command": "private-sentinel"}
        self.assertFalse(snapshot.validate_integrity(port))
        self.assertEqual(snapshot.to_audit_dict(), {})
        self.assertNotIn("private-sentinel", json.dumps(snapshot.to_audit_dict()))

    def test_released_reference_rejects_without_leak(self) -> None:
        ref = CardRef()
        source = materialize(VECTORS["publish_cases"][3]["source"], {"card:a": ref})
        port = EngineDecisionPort(1)
        snapshot = port.publish(source, 1, 1).snapshot
        source["option_card_refs"][0] = None
        del ref
        self.assertIn(port.rebind(snapshot, source)["error_code"], {"reference_released", "source_mutated"})
        self.assertNotIn("option_card_refs", snapshot.to_audit_dict())

    def test_result_and_snapshot_public_fields_cannot_be_mutated(self) -> None:
        source = materialize(VECTORS["publish_cases"][1]["source"], {})
        result = EngineDecisionPort(1).publish(source, 1, 0)
        with self.assertRaises((AttributeError, TypeError)):
            result.error_code = "private-sentinel"
        with self.assertRaises((AttributeError, TypeError)):
            result.snapshot.decision_generation = 999


if __name__ == "__main__":
    unittest.main()
