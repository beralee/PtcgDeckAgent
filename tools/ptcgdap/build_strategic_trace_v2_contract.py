from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
import sys
from typing import Any

_BOOTSTRAP_ROOT = Path(__file__).resolve().parents[2]
if str(_BOOTSTRAP_ROOT) not in sys.path:
    sys.path.insert(0, str(_BOOTSTRAP_ROOT))

from scripts.ai.ptcgdap.cabt_tree_hash import jcs_canonical_json_bytes
from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[2]
CONTRACT_ROOT = ROOT / "contracts/ptcgdap"
SCHEMA_PATH = CONTRACT_ROOT / "strategic_trace_v2.schema.json"
PROFILE_PATH = CONTRACT_ROOT / "strategic_trace_v2_profile.json"
VECTORS_PATH = CONTRACT_ROOT / "strategic_trace_v2_conformance_vectors.json"
BUNDLE_PATH = CONTRACT_ROOT / "strategic_trace_v2_bundle.json"
P4_WP1_VECTORS = CONTRACT_ROOT / "strategic_context_v18_conformance_vectors.json"

PROFILE_ID = "ptcgdap-strategic-trace-v2-p4-wp2-v1"
IR_PROFILE_ID = "ptcgdap-restricted-base-graph-ir-p4-wp2-v1"
PARENT_BUNDLE = "AACFA7E2E7F914180A2B7A5C4D92D6514ACC5F4622FC95B57DC225673893F98F"
SOURCE_LOCK = "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"
BASE_GRAPH_SOURCE = "5D3035312390936D86DE4E2BAF520CE38AB0A79137E1D93199B909D79FBCA3D2"
BASE_GRAPH_CONTRACT = "E8A010E5B6458D2B43811DE683EA2147044D06624502B7314907747E8B0EB5B9"
IR_PREFIX = b"PTCGDAP\0RESTRICTED_BASE_GRAPH_IR_V1\0"
TRACE_PREFIX = b"PTCGDAP\0STRATEGIC_TRACE_V2\0"
SAFE_MAX = 2**53 - 1

BASE_OPERATORS = (
    "legality_guard",
    "mandatory_terminal_guard",
    "hard_tier_filter",
    "base_veto",
    "deterministic_fallback",
    "emit_decision",
)
ADAPTER_OPERATORS = ("goal_proposal", "macro_proposal", "tiebreak_score")
ADAPTER_REASON_CODES = (
    "public_goal_proposal",
    "public_macro_proposal",
    "public_tiebreak_proposal",
)
PRIVATE_IDENTIFIER_TOKENS = ("PRIVATE",)
CAPABILITIES = ("public_context", "current_window", "deterministic_fallback", "strategic_trace_v2")
ERROR_CODES = (
    "contract_error",
    "invalid_ir_document",
    "unsupported_ir_operator",
    "unsupported_capability",
    "invalid_ir_owner",
    "invalid_ir_config",
    "invalid_ir_topology",
    "missing_base_authority",
    "ir_integrity_invalid",
    "invalid_context",
    "invalid_decision",
    "invalid_trace_identity",
    "invalid_trace_audit",
    "trace_integrity_invalid",
)


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest().upper()


def domain_hash(prefix: bytes, payload: dict[str, Any]) -> str:
    return sha(prefix + jcs_canonical_json_bytes(payload))


def node(node_id: str, operator: str, owner: str, config: dict[str, Any], next_ids: list[str]) -> dict[str, Any]:
    return {"node_id": node_id, "operator": operator, "owner": owner, "config": config, "next_node_ids": next_ids}


def minimal_ir() -> dict[str, Any]:
    nodes = [
        node("n00", "legality_guard", "base", {"frontier": "current_window"}, ["n10"]),
        node("n10", "mandatory_terminal_guard", "base", {"mandatory_precedence": True, "terminal_precedence": True}, ["n20"]),
        node("n20", "hard_tier_filter", "base", {"same_tier_only": True}, ["n30"]),
        node("n30", "base_veto", "base", {"enabled": True}, ["n40"]),
        node("n40", "deterministic_fallback", "base", {"strategy": "same_window_first_min"}, ["n50"]),
        node("n50", "emit_decision", "base", {}, []),
    ]
    return {
        "schema_version": 1,
        "profile_id": IR_PROFILE_ID,
        "graph_id": "base-minimal-v1",
        "entry_node_id": "n00",
        "required_capabilities": list(CAPABILITIES),
        "nodes": nodes,
    }


def adapter_ir() -> dict[str, Any]:
    nodes = [
        node("n00", "legality_guard", "base", {"frontier": "current_window"}, ["n10"]),
        node("n10", "mandatory_terminal_guard", "base", {"mandatory_precedence": True, "terminal_precedence": True}, ["n12"]),
        node("n12", "goal_proposal", "adapter", {"goal_ids": ["board-ready"]}, ["n14"]),
        node("n14", "macro_proposal", "adapter", {"macro_ids": ["prepare-attack"]}, ["n20"]),
        node("n20", "hard_tier_filter", "base", {"same_tier_only": True}, ["n22"]),
        node("n22", "tiebreak_score", "adapter", {"feature_ids": ["public-pressure"], "weight_scale": 1000000}, ["n30"]),
        node("n30", "base_veto", "base", {"enabled": True}, ["n40"]),
        node("n40", "deterministic_fallback", "base", {"strategy": "same_window_first_min"}, ["n50"]),
        node("n50", "emit_decision", "base", {}, []),
    ]
    return {
        "schema_version": 1,
        "profile_id": IR_PROFILE_ID,
        "graph_id": "base-with-public-adapter-proposals-v1",
        "entry_node_id": "n00",
        "required_capabilities": list(CAPABILITIES),
        "nodes": nodes,
    }


def compiled_ir(document: dict[str, Any]) -> dict[str, Any]:
    payload = copy.deepcopy(document)
    payload.update({"authority": "restricted_base_graph_ir_audit", "authoritative": False})
    payload["ir_hash"] = domain_hash(IR_PREFIX, payload)
    return payload


def owner_audit(document: dict[str, Any]) -> list[dict[str, Any]]:
    return [
        {"node_id": value["node_id"], "operator": value["operator"], "owner": value["owner"]}
        for value in document["nodes"]
    ]


def trace_payload(
    context: dict[str, Any],
    decision: dict[str, Any],
    ir: dict[str, Any],
    *,
    trace_id: str,
    legal: list[int],
    strategic: list[int],
    mandatory: list[int],
    terminal: list[int],
    tiers: list[dict[str, Any]],
    vetoed: list[int],
    proposals: list[dict[str, Any]],
    fallback_reason: str,
) -> dict[str, Any]:
    payload = {
        "schema_version": 2,
        "profile_id": PROFILE_ID,
        "trace_id": trace_id,
        "identities": {
            "scene_id": decision["scene_id"],
            "decision_id": decision["decision_id"],
            "determinism_key": decision["determinism_key"],
        },
        "source": {
            "context_hash": context["context_hash"],
            "decision_audit_id": decision["audit_id"],
            "policy_hash": decision["policy_hash"],
            "window_id": decision["window_id"],
            "public_observation_hash": decision["public_observation_hash"],
        },
        "ir": {"graph_id": ir["graph_id"], "ir_hash": ir["ir_hash"], "required_capabilities": list(ir["required_capabilities"])},
        "frontier": {
            "option_fingerprints": [value["fingerprint"] for value in context["select_semantics"]["options"]],
            "legal_indexes": legal,
            "strategic_indexes": strategic,
            "mandatory_indexes": mandatory,
            "terminal_indexes": terminal,
            "base_hard_tiers": tiers,
            "base_vetoed_indexes": vetoed,
        },
        "adapter_proposals": proposals,
        "owner_audit": owner_audit(ir),
        "decision": {
            "selected_indexes": list(decision["selected_indexes"]),
            "owner_layer": decision["owner_layer"],
            "reason_code": decision["reason_code"],
            "fallback_tier": decision["fallback_tier"],
        },
        "fallback_reason": fallback_reason,
        "public_only": True,
        "authority": "strategic_trace_v2_public_audit",
        "authoritative": False,
    }
    payload["trace_hash"] = domain_hash(TRACE_PREFIX, payload)
    return payload


def profile() -> dict[str, Any]:
    return {
        "schema_version": 1,
        "profile_id": PROFILE_ID,
        "ir_profile_id": IR_PROFILE_ID,
        "parent_bundle_canonical_sha256": PARENT_BUNDLE,
        "source_lock_canonical_sha256": SOURCE_LOCK,
        "base_graph_v1_8_source_raw_sha256": BASE_GRAPH_SOURCE,
        "base_graph_v1_8_contract_raw_sha256": BASE_GRAPH_CONTRACT,
        "hash_contract": {
            "canonicalization": "RFC8785_JCS_IJSON_SAFE_SUBSET",
            "ir_prefix_utf8_hex": IR_PREFIX.hex().upper(),
            "trace_prefix_utf8_hex": TRACE_PREFIX.hex().upper(),
        },
        "ir_contract": {
            "base_operators_in_required_order": list(BASE_OPERATORS),
            "adapter_operators": list(ADAPTER_OPERATORS),
            "adapter_reason_codes": list(ADAPTER_REASON_CODES),
            "private_identifier_tokens_denied": list(PRIVATE_IDENTIFIER_TOKENS),
            "required_capabilities": list(CAPABILITIES),
            "graph_shape": "single_entry_linear_dag",
            "base_owns": ["legality", "mandatory_terminal", "hard_tier", "veto", "fallback", "emit"],
            "adapter_owns": ["goal_proposal", "macro_proposal", "same_tier_tiebreak_proposal"],
            "forbidden_fields": ["callable", "module", "class", "code", "script", "path", "url", "import", "private_state"],
            "serialized_result_is_execution_authority": False,
        },
        "trace_contract": {
            "source_authority": "exact_current_p4_wp1_context_and_decision_owner",
            "legal_frontier": "all_current_window_option_indexes_in_original_order",
            "mandatory_terminal_cannot_be_filtered": True,
            "adapter_cannot_cross_best_base_hard_tier": True,
            "adapter_cannot_override_base_veto_or_fallback": True,
            "serialized_result_is_execution_authority": False,
        },
        "stable_error_codes": list(ERROR_CODES),
        "private_keys_denied": ["raw_private_hash", "token_free_callback_hash", "search_begin_input", "session", "callback", "binding", "ticket", "command", "object_ref", "pokemon_entity_serial"],
        "scope": {"strategic_trace_v2": True, "restricted_ir_contract": True, "ir_executor": False, "adapter": False, "policy": False, "live_owner": False},
    }


def schema() -> dict[str, Any]:
    sha_def = {"type": "string", "pattern": "^[0-9A-F]{64}$"}
    ident = {"type": "string", "minLength": 1, "maxLength": 128, "pattern": "^(?!.*PRIVATE)[A-Za-z0-9._:-]+$"}
    index = {"type": "integer", "minimum": 0, "maximum": SAFE_MAX}
    index_array = {"type": "array", "items": index, "uniqueItems": True, "maxItems": 1024}
    node_common = {
        "type": "object",
        "required": ["node_id", "operator", "owner", "config", "next_node_ids"],
        "additionalProperties": False,
        "properties": {"node_id": ident, "operator": {"type": "string"}, "owner": {"enum": ["base", "adapter"]}, "config": {"type": "object"}, "next_node_ids": {"type": "array", "items": ident, "maxItems": 1, "uniqueItems": True}},
    }
    def variant(operator: str, owner: str, config: dict[str, Any]) -> dict[str, Any]:
        value = copy.deepcopy(node_common)
        value["properties"]["operator"] = {"const": operator}
        value["properties"]["owner"] = {"const": owner}
        value["properties"]["config"] = config
        return value
    def exact(properties: dict[str, Any], required: list[str] | None = None) -> dict[str, Any]:
        value: dict[str, Any] = {
            "type": "object",
            "additionalProperties": False,
            "properties": properties,
        }
        required_properties = list(properties) if required is None else required
        if required_properties:
            value["required"] = required_properties
        return value
    nodes = [
        variant("legality_guard", "base", exact({"frontier": {"const": "current_window"}})),
        variant("mandatory_terminal_guard", "base", exact({"mandatory_precedence": {"const": True}, "terminal_precedence": {"const": True}})),
        variant("hard_tier_filter", "base", exact({"same_tier_only": {"const": True}})),
        variant("base_veto", "base", exact({"enabled": {"const": True}})),
        variant("deterministic_fallback", "base", exact({"strategy": {"const": "same_window_first_min"}})),
        variant("emit_decision", "base", exact({})),
        variant("goal_proposal", "adapter", exact({"goal_ids": {"type": "array", "items": ident, "minItems": 1, "maxItems": 64, "uniqueItems": True}})),
        variant("macro_proposal", "adapter", exact({"macro_ids": {"type": "array", "items": ident, "minItems": 1, "maxItems": 64, "uniqueItems": True}})),
        variant("tiebreak_score", "adapter", exact({"feature_ids": {"type": "array", "items": ident, "minItems": 1, "maxItems": 64, "uniqueItems": True}, "weight_scale": {"const": 1000000}})),
    ]
    ir_doc = exact({
        "schema_version": {"const": 1}, "profile_id": {"const": IR_PROFILE_ID}, "graph_id": ident, "entry_node_id": ident,
        "required_capabilities": {"type": "array", "items": {"enum": list(CAPABILITIES)}, "minItems": 4, "maxItems": 4, "uniqueItems": True},
        "nodes": {"type": "array", "items": {"oneOf": nodes}, "minItems": 6, "maxItems": 64},
    })
    ir_value = copy.deepcopy(ir_doc)
    ir_value["required"] += ["authority", "authoritative", "ir_hash"]
    ir_value["properties"].update({"authority": {"const": "restricted_base_graph_ir_audit"}, "authoritative": {"const": False}, "ir_hash": sha_def})
    trace = exact({
        "schema_version": {"const": 2}, "profile_id": {"const": PROFILE_ID}, "trace_id": ident,
        "identities": exact({"scene_id": ident, "decision_id": ident, "determinism_key": ident}),
        "source": exact({"context_hash": sha_def, "decision_audit_id": sha_def, "policy_hash": sha_def, "window_id": sha_def, "public_observation_hash": sha_def}),
        "ir": exact({"graph_id": ident, "ir_hash": sha_def, "required_capabilities": {"type": "array", "items": {"enum": list(CAPABILITIES)}, "minItems": 4, "maxItems": 4, "uniqueItems": True}}),
        "frontier": exact({
            "option_fingerprints": {"type": "array", "items": sha_def, "maxItems": 1024}, "legal_indexes": index_array,
            "strategic_indexes": index_array, "mandatory_indexes": index_array, "terminal_indexes": index_array,
            "base_hard_tiers": {"type": "array", "items": exact({"index": index, "tier": {"type": "array", "items": {"type": "integer", "minimum": -SAFE_MAX, "maximum": SAFE_MAX}, "minItems": 1, "maxItems": 8}})},
            "base_vetoed_indexes": index_array,
        }),
        "adapter_proposals": {"type": "array", "items": exact({"operator": {"enum": list(ADAPTER_OPERATORS)}, "indexes": index_array, "reason_code": {"enum": list(ADAPTER_REASON_CODES)}}), "maxItems": 64},
        "owner_audit": {"type": "array", "items": exact({"node_id": ident, "operator": {"enum": list(BASE_OPERATORS + ADAPTER_OPERATORS)}, "owner": {"enum": ["base", "adapter"]}}), "minItems": 6, "maxItems": 64},
        "decision": exact({"selected_indexes": index_array, "owner_layer": {"const": "base_graph"}, "reason_code": ident, "fallback_tier": ident}),
        "fallback_reason": {"type": "string", "maxLength": 128}, "public_only": {"const": True},
        "authority": {"const": "strategic_trace_v2_public_audit"}, "authoritative": {"const": False}, "trace_hash": sha_def,
    })
    return {"$schema": "https://json-schema.org/draft/2020-12/schema", "$id": "ptcgdap://strategic-trace-v2-p4-wp2-v1", "title": "PtcgDAP Strategic Trace v2 and restricted Base Graph IR", "oneOf": [{"$ref": "#/$defs/irDocument"}, {"$ref": "#/$defs/restrictedIr"}, {"$ref": "#/$defs/strategicTraceV2"}], "$defs": {"irDocument": ir_doc, "restrictedIr": ir_value, "strategicTraceV2": trace}}


def vectors() -> dict[str, Any]:
    p4 = load_json_strict(P4_WP1_VECTORS)
    context = p4["fixture"]["expected_context"]
    decision = p4["decision_cases"][0]["expected_decision"]
    minimal = minimal_ir()
    adapter = adapter_ir()
    minimal_value = compiled_ir(minimal)
    adapter_value = compiled_ir(adapter)
    base_audit = {
        "legal_indexes": [0, 1], "strategic_indexes": [0, 1], "mandatory_indexes": [], "terminal_indexes": [],
        "base_hard_tiers": [{"index": 0, "tier": [0, 0]}, {"index": 1, "tier": [0, 1]}], "base_vetoed_indexes": [],
        "adapter_proposals": [], "fallback_reason": "",
    }
    adapter_audit = copy.deepcopy(base_audit)
    adapter_audit["base_hard_tiers"] = [{"index": 0, "tier": [0, 0]}, {"index": 1, "tier": [0, 0]}]
    adapter_audit["adapter_proposals"] = [{"operator": "tiebreak_score", "indexes": [1], "reason_code": "public_tiebreak_proposal"}]
    trace1 = trace_payload(context, decision, minimal_value, trace_id="trace-policy-first", legal=base_audit["legal_indexes"], strategic=base_audit["strategic_indexes"], mandatory=[], terminal=[], tiers=base_audit["base_hard_tiers"], vetoed=[], proposals=[], fallback_reason="")
    trace2 = trace_payload(context, decision, adapter_value, trace_id="trace-adapter-proposal-base-selected", legal=adapter_audit["legal_indexes"], strategic=adapter_audit["strategic_indexes"], mandatory=[], terminal=[], tiers=adapter_audit["base_hard_tiers"], vetoed=[], proposals=adapter_audit["adapter_proposals"], fallback_reason="")
    rejections = [
        {"id": "unknown-operator", "mutation": {"kind": "replace_operator", "node_index": 0, "value": "python_callable"}, "expected_error_code": "unsupported_ir_operator"},
        {"id": "adapter-owns-legality", "mutation": {"kind": "replace_owner", "node_index": 0, "value": "adapter"}, "expected_error_code": "invalid_ir_owner"},
        {"id": "bad-config", "mutation": {"kind": "replace_config", "node_index": 0, "value": {"frontier": "private_engine"}}, "expected_error_code": "invalid_ir_config"},
        {"id": "cycle", "mutation": {"kind": "replace_next", "node_index": 5, "value": ["n00"]}, "expected_error_code": "invalid_ir_topology"},
        {"id": "missing-base-veto", "mutation": {"kind": "remove_node", "node_index": 3}, "expected_error_code": "missing_base_authority"},
        {"id": "unsupported-capability", "mutation": {"kind": "append_capability", "value": "private_oracle"}, "expected_error_code": "unsupported_capability"},
        {"id": "duplicate-node-id", "mutation": {"kind": "replace_node_id", "node_index": 1, "value": "n00"}, "expected_error_code": "invalid_ir_topology"},
    ]
    trace_rejections = [
        {"id": "selected-not-strategic", "mutation": {"kind": "replace_strategic", "value": [1]}, "expected_error_code": "invalid_trace_audit"},
        {"id": "mandatory-filtered", "mutation": {"kind": "replace_mandatory", "value": [1]}, "expected_error_code": "invalid_trace_audit"},
        {"id": "terminal-filtered", "mutation": {"kind": "replace_terminal", "value": [1]}, "expected_error_code": "invalid_trace_audit"},
        {"id": "selected-crosses-best-tier", "mutation": {"kind": "swap_best_tier"}, "expected_error_code": "invalid_trace_audit"},
        {"id": "base-veto-selected", "mutation": {"kind": "replace_vetoed", "value": [0]}, "expected_error_code": "invalid_trace_audit"},
        {"id": "adapter-proposal-outside-strategic", "mutation": {"kind": "replace_proposals", "value": [{"operator": "tiebreak_score", "indexes": [2], "reason_code": "public_tiebreak_proposal"}]}, "expected_error_code": "invalid_trace_audit"},
        {"id": "invalid-trace-id", "mutation": {"kind": "replace_trace_id", "value": ""}, "expected_error_code": "invalid_trace_identity"},
    ]
    return {
        "schema_version": 1, "vector_set_id": "ptcgdap-strategic-trace-v2-p4-wp2-v1", "profile_id": PROFILE_ID, "ir_profile_id": IR_PROFILE_ID,
        "ir_cases": [{"id": "minimal-base", "document": minimal, "expected_ir": minimal_value}, {"id": "public-adapter-proposals", "document": adapter, "expected_ir": adapter_value}],
        "ir_rejections": rejections,
        "trace_fixture": {"context_case_id": "single-select-main-policy-context", "decision_case_id": "policy-first", "context_hash": context["context_hash"], "decision_audit_id": decision["audit_id"]},
        "trace_cases": [
            {"id": "base-policy-first", "ir_case_id": "minimal-base", "trace_id": "trace-policy-first", "audit": base_audit, "expected_trace": trace1},
            {"id": "adapter-proposal-base-selected", "ir_case_id": "public-adapter-proposals", "trace_id": "trace-adapter-proposal-base-selected", "audit": adapter_audit, "expected_trace": trace2},
        ],
        "trace_rejections": trace_rejections,
        "private_sentinels": ["PRIVATE_HAND_SENTINEL", "PRIVATE_SEARCH_SENTINEL", "PRIVATE_SESSION_SENTINEL"],
        "consumer_rule": "IR and trace dictionaries are audit/conformance values only; future execution must consume exact owner-produced runtime objects and revalidate the current context/window.",
    }


def bundle(artifacts: dict[str, dict[str, Any]]) -> dict[str, Any]:
    values = []
    for artifact_id, filename in (("schema", SCHEMA_PATH.name), ("profile", PROFILE_PATH.name), ("vectors", VECTORS_PATH.name)):
        values.append({"id": artifact_id, "path": f"contracts/ptcgdap/{filename}", "canonical_sha256": sha(canonical_json_v1_bytes(artifacts[artifact_id]))})
    return {"schema_version": 1, "bundle_id": "ptcgdap-strategic-trace-v2-p4-wp2-v1", "profile_id": PROFILE_ID, "ir_profile_id": IR_PROFILE_ID, "parent_strategic_context_bundle_canonical_sha256": PARENT_BUNDLE, "source_lock_canonical_sha256": SOURCE_LOCK, "base_graph_v1_8_source_raw_sha256": BASE_GRAPH_SOURCE, "base_graph_v1_8_contract_raw_sha256": BASE_GRAPH_CONTRACT, "artifacts": values}


def render() -> dict[Path, bytes]:
    artifacts = {"schema": schema(), "profile": profile(), "vectors": vectors()}
    artifacts["bundle"] = bundle(artifacts)
    return {SCHEMA_PATH: json.dumps(artifacts["schema"], ensure_ascii=False, indent=2).encode("utf-8") + b"\n", PROFILE_PATH: json.dumps(artifacts["profile"], ensure_ascii=False, indent=2).encode("utf-8") + b"\n", VECTORS_PATH: json.dumps(artifacts["vectors"], ensure_ascii=False, indent=2).encode("utf-8") + b"\n", BUNDLE_PATH: json.dumps(artifacts["bundle"], ensure_ascii=False, indent=2).encode("utf-8") + b"\n"}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    rendered = render()
    if args.check:
        drift = [path for path, data in rendered.items() if not path.is_file() or path.read_bytes() != data]
        if drift:
            raise SystemExit("contract drift: " + ", ".join(str(path.relative_to(ROOT)) for path in drift))
        return 0
    for path, data in rendered.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
