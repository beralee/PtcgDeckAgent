from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import shutil
import tempfile
import unittest

from scripts.ai.ptcgdap.cabt_selection import CabtSelectionSanitizer
from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict
from scripts.ai.ptcgdap.strategic_context_v18 import PolicyDecisionFactory, StrategicContextCompiler
from scripts.ai.ptcgdap.strategic_trace_v2 import (
    RestrictedBaseGraphIRCompiler,
    StrategicTraceContractError,
    StrategicTraceV2Builder,
)
from tests.ptcgdap.test_strategic_context_v18 import _firewall_case, _window


ROOT = Path(__file__).resolve().parents[2]
CONTRACT_ROOT = ROOT / "contracts" / "ptcgdap"
VECTORS = load_json_strict(CONTRACT_ROOT / "strategic_trace_v2_conformance_vectors.json")
P4_VECTORS = load_json_strict(CONTRACT_ROOT / "strategic_context_v18_conformance_vectors.json")


def _context_decision():
    _, firewall = _firewall_case("regular-accepted")
    window = _window(firewall)
    context_result = StrategicContextCompiler.build(firewall, window)
    assert context_result.context is not None
    case = P4_VECTORS["decision_cases"][0]
    resolution = CabtSelectionSanitizer.resolve_policy_attempt(window, case["selected_indexes"])
    decision_result = PolicyDecisionFactory.build(
        context_result.context,
        window,
        resolution,
        policy_hash=case["policy_hash"],
        scene_id=case["scene_id"],
        decision_id=case["decision_id"],
        determinism_key=case["determinism_key"],
    )
    assert decision_result.decision is not None
    return context_result.context, decision_result.decision


def _mutate_ir(document: dict, mutation: dict) -> dict:
    value = copy.deepcopy(document)
    kind = mutation["kind"]
    if kind == "replace_operator":
        value["nodes"][mutation["node_index"]]["operator"] = mutation["value"]
    elif kind == "replace_owner":
        value["nodes"][mutation["node_index"]]["owner"] = mutation["value"]
    elif kind == "replace_config":
        value["nodes"][mutation["node_index"]]["config"] = copy.deepcopy(mutation["value"])
    elif kind == "replace_next":
        value["nodes"][mutation["node_index"]]["next_node_ids"] = copy.deepcopy(mutation["value"])
    elif kind == "remove_node":
        value["nodes"].pop(mutation["node_index"])
    elif kind == "append_capability":
        value["required_capabilities"].append(mutation["value"])
    elif kind == "replace_node_id":
        value["nodes"][mutation["node_index"]]["node_id"] = mutation["value"]
    else:
        raise AssertionError(kind)
    return value


def _mutate_trace_inputs(trace_case: dict, mutation: dict) -> tuple[str, dict]:
    trace_id = trace_case["trace_id"]
    audit = copy.deepcopy(trace_case["audit"])
    kind = mutation["kind"]
    if kind == "replace_strategic":
        audit["strategic_indexes"] = copy.deepcopy(mutation["value"])
    elif kind == "replace_mandatory":
        audit["mandatory_indexes"] = copy.deepcopy(mutation["value"])
    elif kind == "replace_terminal":
        audit["terminal_indexes"] = copy.deepcopy(mutation["value"])
    elif kind == "swap_best_tier":
        audit["base_hard_tiers"] = [{"index": 0, "tier": [1]}, {"index": 1, "tier": [0]}]
    elif kind == "replace_vetoed":
        audit["base_vetoed_indexes"] = copy.deepcopy(mutation["value"])
    elif kind == "replace_proposals":
        audit["adapter_proposals"] = copy.deepcopy(mutation["value"])
    elif kind == "replace_trace_id":
        trace_id = mutation["value"]
    else:
        raise AssertionError(kind)
    return trace_id, audit


class StrategicTraceV2Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.context, cls.decision = _context_decision()

    def test_all_shared_ir_cases_compile_exactly(self) -> None:
        for case in VECTORS["ir_cases"]:
            with self.subTest(case=case["id"]):
                result = RestrictedBaseGraphIRCompiler.compile(copy.deepcopy(case["document"]))
                self.assertTrue(result.accepted, result.error_code)
                self.assertIsNotNone(result.ir)
                self.assertTrue(result.ir.validate_integrity())
                self.assertEqual(case["expected_ir"], result.ir.to_public_dict())

    def test_all_shared_ir_rejections_fail_closed(self) -> None:
        base = VECTORS["ir_cases"][0]["document"]
        for case in VECTORS["ir_rejections"]:
            with self.subTest(case=case["id"]):
                result = RestrictedBaseGraphIRCompiler.compile(_mutate_ir(base, case["mutation"]))
                self.assertFalse(result.accepted)
                self.assertEqual(case["expected_error_code"], result.error_code)
                self.assertIsNone(result.ir)

    def test_all_shared_trace_cases_build_exactly(self) -> None:
        ir_by_id = {}
        for case in VECTORS["ir_cases"]:
            ir_by_id[case["id"]] = RestrictedBaseGraphIRCompiler.compile(copy.deepcopy(case["document"])).ir
        for case in VECTORS["trace_cases"]:
            with self.subTest(case=case["id"]):
                ir = ir_by_id[case["ir_case_id"]]
                result = StrategicTraceV2Builder.build(
                    self.context,
                    self.decision,
                    ir,
                    trace_id=case["trace_id"],
                    audit=copy.deepcopy(case["audit"]),
                )
                self.assertTrue(result.accepted, result.error_code)
                self.assertIsNotNone(result.trace)
                self.assertTrue(result.trace.validate_integrity(self.context, self.decision, ir))
                self.assertEqual(case["expected_trace"], result.trace.to_public_dict())

    def test_all_shared_trace_rejections_fail_closed(self) -> None:
        ir = RestrictedBaseGraphIRCompiler.compile(copy.deepcopy(VECTORS["ir_cases"][0]["document"])).ir
        base = VECTORS["trace_cases"][0]
        for case in VECTORS["trace_rejections"]:
            with self.subTest(case=case["id"]):
                trace_id, audit = _mutate_trace_inputs(base, case["mutation"])
                result = StrategicTraceV2Builder.build(
                    self.context,
                    self.decision,
                    ir,
                    trace_id=trace_id,
                    audit=audit,
                )
                self.assertFalse(result.accepted)
                self.assertEqual(case["expected_error_code"], result.error_code)
                self.assertIsNone(result.trace)

    def test_runtime_objects_fail_closed_after_mutation_and_do_not_echo(self) -> None:
        ir_result = RestrictedBaseGraphIRCompiler.compile(copy.deepcopy(VECTORS["ir_cases"][0]["document"]))
        ir = ir_result.ir
        result = StrategicTraceV2Builder.build(
            self.context,
            self.decision,
            ir,
            trace_id=VECTORS["trace_cases"][0]["trace_id"],
            audit=copy.deepcopy(VECTORS["trace_cases"][0]["audit"]),
        )
        trace = result.trace
        object.__setattr__(trace, "_snapshot", {"private": "PRIVATE_SENTINEL"})
        self.assertFalse(trace.validate_integrity(self.context, self.decision, ir))
        with self.assertRaisesRegex(StrategicTraceContractError, "trace_integrity_invalid"):
            trace.to_public_dict()
        object.__setattr__(ir, "_snapshot", {"callable": "PRIVATE_SENTINEL"})
        self.assertFalse(ir.validate_integrity())
        with self.assertRaisesRegex(StrategicTraceContractError, "ir_integrity_invalid"):
            ir.to_public_dict()

    def test_stale_context_decision_binding_is_rejected(self) -> None:
        other_context, other_decision = _context_decision()
        ir = RestrictedBaseGraphIRCompiler.compile(copy.deepcopy(VECTORS["ir_cases"][0]["document"])).ir
        first = StrategicTraceV2Builder.build(
            self.context,
            self.decision,
            ir,
            trace_id=VECTORS["trace_cases"][0]["trace_id"],
            audit=copy.deepcopy(VECTORS["trace_cases"][0]["audit"]),
        ).trace
        self.assertFalse(first.validate_integrity(other_context, other_decision, ir))
        result = StrategicTraceV2Builder.build(
            other_context,
            self.decision,
            ir,
            trace_id="stale-context",
            audit=copy.deepcopy(VECTORS["trace_cases"][0]["audit"]),
        )
        self.assertFalse(result.accepted)
        self.assertEqual("invalid_decision", result.error_code)

    def test_contract_whitespace_is_allowed_but_semantic_resign_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory(prefix="ptcgdap-p4-wp2-contract-") as temp:
            root = Path(temp)
            names = (
                "strategic_trace_v2.schema.json",
                "strategic_trace_v2_profile.json",
                "strategic_trace_v2_conformance_vectors.json",
                "strategic_trace_v2_bundle.json",
            )
            for name in names:
                shutil.copyfile(CONTRACT_ROOT / name, root / name)
            with (root / "strategic_trace_v2_profile.json").open("ab") as handle:
                handle.write(b" \n")
            result = RestrictedBaseGraphIRCompiler.compile(copy.deepcopy(VECTORS["ir_cases"][0]["document"]), contract_root=root)
            self.assertTrue(result.accepted, result.error_code)
            profile = load_json_strict(root / "strategic_trace_v2_profile.json")
            profile["scope"]["live_owner"] = True
            (root / "strategic_trace_v2_profile.json").write_text(json.dumps(profile), encoding="utf-8")
            result = RestrictedBaseGraphIRCompiler.compile(copy.deepcopy(VECTORS["ir_cases"][0]["document"]), contract_root=root)
            self.assertFalse(result.accepted)
            self.assertEqual("contract_error", result.error_code)
            bundle = load_json_strict(root / "strategic_trace_v2_bundle.json")
            resigned = hashlib.sha256(canonical_json_v1_bytes(profile)).hexdigest().upper()
            next(entry for entry in bundle["artifacts"] if entry["id"] == "profile")["canonical_sha256"] = resigned
            (root / "strategic_trace_v2_bundle.json").write_text(json.dumps(bundle), encoding="utf-8")
            result = RestrictedBaseGraphIRCompiler.compile(copy.deepcopy(VECTORS["ir_cases"][0]["document"]), contract_root=root)
            self.assertFalse(result.accepted, "self-consistent artifact+bundle resign must not replace the fixed bundle trust anchor")
            self.assertEqual("contract_error", result.error_code)
            missing = RestrictedBaseGraphIRCompiler.compile(
                copy.deepcopy(VECTORS["ir_cases"][0]["document"]),
                contract_root=root / "missing",
            )
            self.assertFalse(missing.accepted)
            self.assertEqual("contract_error", missing.error_code)


if __name__ == "__main__":
    unittest.main()
