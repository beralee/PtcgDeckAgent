from __future__ import annotations

import argparse
import hashlib
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict  # noqa: E402


SCHEMA_PATH = ROOT / "contracts/ptcgdap/policy_executor_conformance_v1.schema.json"
PROFILE_PATH = ROOT / "contracts/ptcgdap/policy_executor_conformance_v1_profile.json"
VECTORS_PATH = ROOT / "contracts/ptcgdap/policy_executor_conformance_v1_vectors.json"
BUNDLE_PATH = ROOT / "contracts/ptcgdap/policy_executor_conformance_v1_bundle.json"
POLICY_MANIFEST_PATH = ROOT / "data/ptcgdap/marnie_windows_policy_package_v1.json"
PORTABLE_BUNDLE_PATH = ROOT / "contracts/ptcgdap/marnie_portable_policy_bundle.json"
PARENT_VECTORS_PATH = ROOT / "contracts/ptcgdap/marnie_portable_policy_conformance_vectors.json"

EXPECTED_POLICY_MANIFEST = "3243ABD7937B3F53D8E5D7A887FC90BFBDF9A4D94E4030A3A9BE194C82370FFC"
EXPECTED_PORTABLE_BUNDLE = "992B7F00DF412496BA414ABCC87C21C6136CB513C9C90799C897ADD18D15EDB2"


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def _canonical_sha(path: Path) -> str:
    return _sha(canonical_json_v1_bytes(load_json_strict(path)))


def build_schema() -> dict[str, object]:
    sha = {"type": "string", "pattern": "^[0-9A-F]{64}$"}
    case = {
        "type": "object",
        "additionalProperties": False,
        "required": ["case_id", "probe", "expected"],
        "properties": {
            "case_id": {"type": "string", "pattern": "^[a-z0-9][a-z0-9_-]{0,63}$"},
            "probe": {"enum": ["order", "float", "default", "unknown_node", "fault", "tie_break", "option_reorder", "unknown_operation"]},
            "expected": {"type": "object"},
        },
    }
    common = {
        "schema_version": {"const": 1},
        "policy_package_manifest_canonical_sha256": sha,
        "portable_policy_bundle_canonical_sha256": sha,
        "parent_vector_set_id": {"const": "ptcgdap-marnie-portable-policy-conformance-v1"},
    }
    return {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "https://ptcgdap.local/contracts/policy_executor_conformance_v1.schema.json",
        "title": "PTCGDAP policy executor conformance v1",
        "oneOf": [
            {
                "type": "object",
                "additionalProperties": False,
                "required": [
                    "document_type", "schema_version", "profile_id",
                    "policy_package_manifest_canonical_sha256", "portable_policy_bundle_canonical_sha256",
                    "parent_vector_set_id", "required_dimensions", "numeric_contract", "default_contract",
                    "fault_contract", "model_contract", "authority_contract",
                ],
                "properties": {
                    **common,
                    "document_type": {"const": "policy_executor_conformance_profile_v1"},
                    "profile_id": {"const": "ptcgdap-windows-no-model-policy-conformance-v1"},
                    "required_dimensions": {
                        "type": "array", "minItems": 8, "maxItems": 8, "uniqueItems": True,
                        "items": {"enum": ["order", "float", "default", "unknown_node", "fault", "tie_break", "option_reorder", "unknown_operation"]},
                    },
                    "numeric_contract": {
                        "type": "object", "additionalProperties": False,
                        "required": ["artifact_float", "runtime_float_input", "safe_integer_only"],
                        "properties": {
                            "artifact_float": {"const": "forbidden"},
                            "runtime_float_input": {"const": "input_type_invalid"},
                            "safe_integer_only": {"const": True},
                        },
                    },
                    "default_contract": {
                        "type": "object", "additionalProperties": False,
                        "required": ["operation", "input", "rule"],
                        "properties": {
                            "operation": {"const": "evaluate_all"},
                            "input": {"type": "object", "maxProperties": 0},
                            "rule": {"const": "exact_empty_object_only"},
                        },
                    },
                    "fault_contract": {
                        "type": "object", "additionalProperties": False,
                        "required": ["mutated_result", "unknown_node", "reordered_options"],
                        "properties": {
                            "mutated_result": {"const": "result_integrity_invalid"},
                            "unknown_node": {"const": "unsupported_node"},
                            "reordered_options": {"const": "binding_mismatch"},
                        },
                    },
                    "model_contract": {
                        "type": "object", "additionalProperties": False,
                        "required": ["learned_model", "backend", "required_operator_case_count", "skipped_operator_case_count"],
                        "properties": {
                            "learned_model": {"const": "none"}, "backend": {"const": "none"},
                            "required_operator_case_count": {"const": 0}, "skipped_operator_case_count": {"const": 0},
                        },
                    },
                    "authority_contract": {
                        "type": "object", "additionalProperties": False,
                        "required": ["public_only", "execution_authority", "production_ready"],
                        "properties": {
                            "public_only": {"const": True}, "execution_authority": {"const": False}, "production_ready": {"const": False},
                        },
                    },
                },
            },
            {
                "type": "object",
                "additionalProperties": False,
                "required": [
                    "document_type", "schema_version", "vector_set_id", "profile_id",
                    "policy_package_manifest_canonical_sha256", "portable_policy_bundle_canonical_sha256",
                    "parent_vector_set_id", "cases",
                ],
                "properties": {
                    **common,
                    "document_type": {"const": "policy_executor_conformance_vectors_v1"},
                    "vector_set_id": {"const": "ptcgdap-policy-executor-conformance-d052-v1"},
                    "profile_id": {"const": "ptcgdap-windows-no-model-policy-conformance-v1"},
                    "cases": {"type": "array", "minItems": 8, "maxItems": 8, "items": case},
                },
            },
        ],
    }


def _parent_hashes() -> tuple[str, str, str]:
    policy = _canonical_sha(POLICY_MANIFEST_PATH)
    portable = _canonical_sha(PORTABLE_BUNDLE_PATH)
    if policy != EXPECTED_POLICY_MANIFEST or portable != EXPECTED_PORTABLE_BUNDLE:
        raise ValueError("D052 parent identity drift")
    parent_vectors = load_json_strict(PARENT_VECTORS_PATH)
    if type(parent_vectors) is not dict or parent_vectors.get("vector_set_id") != "ptcgdap-marnie-portable-policy-conformance-v1":
        raise ValueError("D052 parent vector drift")
    return policy, portable, parent_vectors["vector_set_id"]


def build_profile() -> dict[str, object]:
    policy, portable, parent_vectors = _parent_hashes()
    return {
        "document_type": "policy_executor_conformance_profile_v1",
        "schema_version": 1,
        "profile_id": "ptcgdap-windows-no-model-policy-conformance-v1",
        "policy_package_manifest_canonical_sha256": policy,
        "portable_policy_bundle_canonical_sha256": portable,
        "parent_vector_set_id": parent_vectors,
        "required_dimensions": ["order", "float", "default", "unknown_node", "fault", "tie_break", "option_reorder", "unknown_operation"],
        "numeric_contract": {"artifact_float": "forbidden", "runtime_float_input": "input_type_invalid", "safe_integer_only": True},
        "default_contract": {"operation": "evaluate_all", "input": {}, "rule": "exact_empty_object_only"},
        "fault_contract": {"mutated_result": "result_integrity_invalid", "unknown_node": "unsupported_node", "reordered_options": "binding_mismatch"},
        "model_contract": {"learned_model": "none", "backend": "none", "required_operator_case_count": 0, "skipped_operator_case_count": 0},
        "authority_contract": {"public_only": True, "execution_authority": False, "production_ready": False},
    }


def build_vectors() -> dict[str, object]:
    policy, portable, parent_vectors = _parent_hashes()
    return {
        "document_type": "policy_executor_conformance_vectors_v1",
        "schema_version": 1,
        "vector_set_id": "ptcgdap-policy-executor-conformance-d052-v1",
        "profile_id": "ptcgdap-windows-no-model-policy-conformance-v1",
        "policy_package_manifest_canonical_sha256": policy,
        "portable_policy_bundle_canonical_sha256": portable,
        "parent_vector_set_id": parent_vectors,
        "cases": [
            {"case_id": "dictionary-order-insensitive", "probe": "order", "expected": {"ok": True, "error_code": "", "value": {"binding_matches": True, "frame_id": "w3_main", "portable_trace_hash": "11D7DB09CEA8AB0D6AF552C324FD5A6A9D7FB38737DCDB6AB5CEDED5117F79F3", "authoritative": False, "execution_authority": False}}},
            {"case_id": "runtime-float-rejected", "probe": "float", "expected": {"ok": False, "error_code": "input_type_invalid", "value": None}},
            {"case_id": "empty-input-default", "probe": "default", "expected": {"ok": True, "error_code": "", "frame_count": 13, "chain_head": "AF8630DCEB004664A4BB90F16C9FD582FCA191316FB3482E5B3ACED773EC84E1"}},
            {"case_id": "unknown-node-fails-closed", "probe": "unknown_node", "expected": {"ok": False, "error_code": "unsupported_node", "value": None}},
            {"case_id": "mutated-result-fails-integrity", "probe": "fault", "expected": {"valid_after_fault": False, "error_code": "result_integrity_invalid"}},
            {"case_id": "same-tier-tie-break-exact", "probe": "tie_break", "expected": {"frame_id": "w4_spikemuth_deck", "node_id": "n10_base_final", "owner_route": "base_final", "adapter_hint_indexes": [0, 1], "base_final_action": [], "portable_trace_hash": "F936109A19D79C1083ACAF0C716864577002F5946665B90BE029D6FB659BB638"}},
            {"case_id": "option-reorder-rebind-required", "probe": "option_reorder", "expected": {"ok": False, "error_code": "binding_mismatch", "value": None}},
            {"case_id": "unknown-operation-fails-closed", "probe": "unknown_operation", "expected": {"ok": False, "error_code": "operation_unknown", "value": None}},
        ],
    }


def build_bundle(schema: dict[str, object], profile: dict[str, object], vectors: dict[str, object]) -> dict[str, object]:
    documents = (("schema", SCHEMA_PATH, schema), ("profile", PROFILE_PATH, profile), ("vectors", VECTORS_PATH, vectors))
    return {
        "schema_version": 1,
        "bundle_id": "ptcgdap-policy-executor-conformance-d052-v1",
        "artifacts": [
            {"id": artifact_id, "path": path.relative_to(ROOT).as_posix(), "canonical_sha256": _sha(canonical_json_v1_bytes(document))}
            for artifact_id, path, document in documents
        ],
    }


def _render(value: dict[str, object]) -> bytes:
    return canonical_json_v1_bytes(value) + b"\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--write", action="store_true")
    group.add_argument("--check", action="store_true")
    args = parser.parse_args()
    schema = build_schema()
    profile = build_profile()
    vectors = build_vectors()
    bundle = build_bundle(schema, profile, vectors)
    for path, document in ((SCHEMA_PATH, schema), (PROFILE_PATH, profile), (VECTORS_PATH, vectors), (BUNDLE_PATH, bundle)):
        expected = _render(document)
        if args.write:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(expected)
        elif not path.is_file() or path.read_bytes() != expected:
            raise SystemExit(f"D052 generated artifact drift: {path.relative_to(ROOT).as_posix()}")
    print("policy executor conformance v1 verified" if args.check else "policy executor conformance v1 written")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
