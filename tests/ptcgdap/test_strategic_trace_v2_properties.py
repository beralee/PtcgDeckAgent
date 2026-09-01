from __future__ import annotations

import copy
from enum import IntEnum
import hashlib
from pathlib import Path
import unittest

from scripts.ai.ptcgdap.source_lock import load_json_strict
from scripts.ai.ptcgdap.strategic_trace_v2 import RestrictedBaseGraphIRCompiler, StrategicTraceV2Builder
from tests.ptcgdap.test_strategic_trace_v2 import _context_decision


ROOT = Path(__file__).resolve().parents[2]
VECTORS = load_json_strict(ROOT / "contracts" / "ptcgdap" / "strategic_trace_v2_conformance_vectors.json")


class _Index(IntEnum):
    ZERO = 0


def _renumber(document: dict) -> dict:
    value = copy.deepcopy(document)
    for index, node in enumerate(value["nodes"]):
        node["node_id"] = f"p{index:02d}"
    for index, node in enumerate(value["nodes"]):
        node["next_node_ids"] = [] if index + 1 == len(value["nodes"]) else [value["nodes"][index + 1]["node_id"]]
    value["entry_node_id"] = value["nodes"][0]["node_id"]
    value["graph_id"] = "property-" + hashlib.sha256(str(value["nodes"]).encode("utf-8")).hexdigest()[:16]
    return value


class StrategicTraceV2PropertyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.context, cls.decision = _context_decision()

    def test_all_legal_adapter_presence_combinations_compile_and_hash_deterministically(self) -> None:
        base = VECTORS["ir_cases"][0]["document"]
        goal = {"node_id": "goal", "operator": "goal_proposal", "owner": "adapter", "config": {"goal_ids": ["ready"]}, "next_node_ids": []}
        macro = {"node_id": "macro", "operator": "macro_proposal", "owner": "adapter", "config": {"macro_ids": ["attack"]}, "next_node_ids": []}
        tie = {"node_id": "tie", "operator": "tiebreak_score", "owner": "adapter", "config": {"feature_ids": ["pressure"], "weight_scale": 1000000}, "next_node_ids": []}
        seen = set()
        for mask in range(8):
            document = copy.deepcopy(base)
            if mask & 1:
                document["nodes"].insert(2, copy.deepcopy(goal))
            if mask & 2:
                hard_index = next(i for i, node in enumerate(document["nodes"]) if node["operator"] == "hard_tier_filter")
                document["nodes"].insert(hard_index, copy.deepcopy(macro))
            if mask & 4:
                veto_index = next(i for i, node in enumerate(document["nodes"]) if node["operator"] == "base_veto")
                document["nodes"].insert(veto_index, copy.deepcopy(tie))
            document = _renumber(document)
            first = RestrictedBaseGraphIRCompiler.compile(document)
            second = RestrictedBaseGraphIRCompiler.compile(copy.deepcopy(document))
            self.assertTrue(first.accepted, (mask, first.error_code))
            self.assertTrue(second.accepted, (mask, second.error_code))
            self.assertEqual(first.ir.to_public_dict(), second.ir.to_public_dict())
            self.assertNotIn(first.ir.ir_hash, seen)
            seen.add(first.ir.ir_hash)

    def test_adapter_nodes_outside_their_authority_zone_are_rejected(self) -> None:
        document = copy.deepcopy(VECTORS["ir_cases"][1]["document"])
        goal_index = next(i for i, node in enumerate(document["nodes"]) if node["operator"] == "goal_proposal")
        goal = document["nodes"].pop(goal_index)
        document["nodes"].insert(-1, goal)
        result = RestrictedBaseGraphIRCompiler.compile(_renumber(document))
        self.assertFalse(result.accepted)
        self.assertEqual("invalid_ir_topology", result.error_code)

        document = copy.deepcopy(VECTORS["ir_cases"][1]["document"])
        tie_index = next(i for i, node in enumerate(document["nodes"]) if node["operator"] == "tiebreak_score")
        tie = document["nodes"].pop(tie_index)
        document["nodes"].insert(1, tie)
        result = RestrictedBaseGraphIRCompiler.compile(_renumber(document))
        self.assertFalse(result.accepted)
        self.assertEqual("invalid_ir_topology", result.error_code)

    def test_trace_relation_matrix_accepts_only_same_best_tier_and_unvetoed_selection(self) -> None:
        ir = RestrictedBaseGraphIRCompiler.compile(copy.deepcopy(VECTORS["ir_cases"][0]["document"])).ir
        accepted = 0
        for strategic in ([0], [0, 1]):
            for mandatory in ([], [0]):
                for terminal in ([], [0]):
                    for second_tier in ([0], [1], [-1]):
                        audit = {
                            "legal_indexes": [0, 1],
                            "strategic_indexes": list(strategic),
                            "mandatory_indexes": list(mandatory),
                            "terminal_indexes": list(terminal),
                            "base_hard_tiers": [{"index": 0, "tier": [0]}],
                            "base_vetoed_indexes": [],
                            "adapter_proposals": [],
                            "fallback_reason": "",
                        }
                        if 1 in strategic:
                            audit["base_hard_tiers"].append({"index": 1, "tier": list(second_tier)})
                        result = StrategicTraceV2Builder.build(
                            self.context,
                            self.decision,
                            ir,
                            trace_id=f"matrix-{accepted}-{len(strategic)}-{len(mandatory)}-{len(terminal)}-{second_tier[0]}",
                            audit=audit,
                        )
                        should_accept = bool(terminal or mandatory) or 1 not in strategic or tuple(second_tier) >= (0,)
                        self.assertEqual(should_accept, result.accepted, (audit, result.error_code))
                        if result.accepted:
                            accepted += 1
                            self.assertTrue(result.trace.validate_integrity(self.context, self.decision, ir))
        self.assertGreater(accepted, 0)

        audit = copy.deepcopy(VECTORS["trace_cases"][0]["audit"])
        audit["base_vetoed_indexes"] = [0]
        result = StrategicTraceV2Builder.build(self.context, self.decision, ir, trace_id="veto-property", audit=audit)
        self.assertFalse(result.accepted)
        self.assertEqual("invalid_trace_audit", result.error_code)

    def test_exact_host_types_and_self_consistent_rehashes_do_not_gain_authority(self) -> None:
        document = copy.deepcopy(VECTORS["ir_cases"][0]["document"])
        faults = []
        value = copy.deepcopy(document); value["schema_version"] = True; faults.append(value)
        value = copy.deepcopy(document); value["nodes"][0]["node_id"] = 1; faults.append(value)
        value = copy.deepcopy(document); value["nodes"][1]["config"]["mandatory_precedence"] = 1; faults.append(value)
        value = copy.deepcopy(VECTORS["ir_cases"][1]["document"]); value["nodes"][5]["config"]["weight_scale"] = True; faults.append(value)
        value = copy.deepcopy(document); value["graph_id"] = "PRIVATE_SENTINEL"; faults.append(value)
        for value in faults:
            self.assertFalse(RestrictedBaseGraphIRCompiler.compile(value).accepted)

        ir = RestrictedBaseGraphIRCompiler.compile(document).ir
        audit = copy.deepcopy(VECTORS["trace_cases"][0]["audit"])
        audit["legal_indexes"] = [_Index.ZERO, 1]
        self.assertFalse(StrategicTraceV2Builder.build(self.context, self.decision, ir, trace_id="int-enum", audit=audit).accepted)

        forged = ir.to_public_dict()
        forged["nodes"][0]["config"]["frontier"] = "private_engine"
        object.__setattr__(ir, "_snapshot", forged)
        self.assertFalse(ir.validate_integrity())


if __name__ == "__main__":
    unittest.main()
