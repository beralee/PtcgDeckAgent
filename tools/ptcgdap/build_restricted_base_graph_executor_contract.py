from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
import sys
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
CONTRACT_ROOT = ROOT / "contracts/ptcgdap"
PARENT_VECTORS = CONTRACT_ROOT / "strategic_trace_v2_conformance_vectors.json"
PROFILE_ID = "ptcgdap-restricted-base-graph-executor-p4-wp3-v1"
BUNDLE_ID = "ptcgdap-restricted-base-graph-executor-p4-wp3-v1"
PARENT_BUNDLE = "ADDD4CB48BD10FA0478854124D8E63AEE42B898C0EB81692BA35F8D7F90414C4"
SOURCE_LOCK = "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"
EXECUTION_PREFIX = b"PTCGDAP\0RESTRICTED_BASE_GRAPH_EXECUTION_V1\0"
ARTIFACTS = (
    "restricted_base_graph_executor.schema.json",
    "restricted_base_graph_executor_profile.json",
    "restricted_base_graph_executor_conformance_vectors.json",
)
ADAPTER_REASONS = {
    "goal_proposal": "public_goal_proposal",
    "macro_proposal": "public_macro_proposal",
    "tiebreak_score": "public_tiebreak_proposal",
}


def canonical(value: Any) -> bytes:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")


def digest(value: Any) -> str:
    return hashlib.sha256(canonical(value)).hexdigest().upper()


def domain_hash(value: Any) -> str:
    return hashlib.sha256(EXECUTION_PREFIX + canonical(value)).hexdigest().upper()


def pretty(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def load(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def schema() -> dict[str, Any]:
    safe_integer = {"type": "integer", "minimum": -9007199254740991, "maximum": 9007199254740991}
    index = {"allOf": [{"$ref": "#/$defs/safeInteger"}, {"minimum": 0}]}
    index_array = {"type": "array", "items": {"$ref": "#/$defs/index"}, "uniqueItems": True, "maxItems": 1024}
    proposal = {
        "type": "object",
        "additionalProperties": False,
        "required": ["operator", "indexes", "reason_code"],
        "properties": {
            "operator": {"enum": list(ADAPTER_REASONS)},
            "indexes": {"$ref": "#/$defs/indexArray"},
            "reason_code": {"enum": list(ADAPTER_REASONS.values())},
        },
        "allOf": [
            {"if": {"properties": {"operator": {"const": op}}}, "then": {"properties": {"reason_code": {"const": reason}}}}
            for op, reason in ADAPTER_REASONS.items()
        ],
    }
    execution_input = {
        "type": "object",
        "additionalProperties": False,
        "required": ["execution_id", "mandatory_indexes", "terminal_indexes", "base_hard_tiers", "base_vetoed_indexes", "adapter_proposals"],
        "properties": {
            "execution_id": {"type": "string", "pattern": "^[a-z0-9][a-z0-9._-]{0,127}$", "not": {"pattern": "PRIVATE"}},
            "mandatory_indexes": {"$ref": "#/$defs/indexArray"},
            "terminal_indexes": {"$ref": "#/$defs/indexArray"},
            "base_hard_tiers": {
                "type": "array",
                "maxItems": 1024,
                "items": {
                    "type": "object",
                    "additionalProperties": False,
                    "required": ["index", "tier"],
                    "properties": {
                        "index": {"$ref": "#/$defs/index"},
                        "tier": {"type": "array", "minItems": 1, "maxItems": 8, "items": {"$ref": "#/$defs/safeInteger"}},
                    },
                },
            },
            "base_vetoed_indexes": {"$ref": "#/$defs/indexArray"},
            "adapter_proposals": {"type": "array", "maxItems": 64, "items": {"$ref": "#/$defs/adapterProposal"}},
        },
    }
    node_audit = {
        "type": "object",
        "additionalProperties": False,
        "required": ["node_id", "operator", "owner", "input_indexes", "output_indexes"],
        "properties": {
            "node_id": {"type": "string"},
            "operator": {"type": "string"},
            "owner": {"enum": ["base", "adapter"]},
            "input_indexes": {"$ref": "#/$defs/indexArray"},
            "output_indexes": {"$ref": "#/$defs/indexArray"},
        },
    }
    result = {
        "type": "object",
        "additionalProperties": False,
        "required": ["schema_version", "profile_id", "execution_id", "source", "selected_indexes", "reason_code", "fallback_branch", "node_audit", "adapter_audit", "authoritative", "execution_hash"],
        "properties": {
            "schema_version": {"const": 1},
            "profile_id": {"const": PROFILE_ID},
            "execution_id": {"type": "string"},
            "source": {
                "type": "object",
                "additionalProperties": False,
                "required": ["context_hash", "window_id", "ir_hash"],
                "properties": {key: {"type": "string", "pattern": "^[0-9A-F]{64}$"} for key in ("context_hash", "window_id", "ir_hash")},
            },
            "selected_indexes": {"$ref": "#/$defs/indexArray"},
            "reason_code": {"enum": ["terminal_selection", "mandatory_selection", "deterministic_fallback", "empty_selection"]},
            "fallback_branch": {"enum": ["terminal", "mandatory", "same_window_first_min", "optional_zero"]},
            "node_audit": {"type": "array", "minItems": 6, "maxItems": 9, "items": {"$ref": "#/$defs/nodeAudit"}},
            "adapter_audit": {"type": "array", "maxItems": 64, "items": {"$ref": "#/$defs/adapterProposal"}},
            "authoritative": {"const": False},
            "execution_hash": {"type": "string", "pattern": "^[0-9A-F]{64}$"},
        },
    }
    return {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "https://ptcgdap.local/contracts/restricted_base_graph_executor.schema.json",
        "title": "PtcgDAP restricted Base Graph executor contract",
        "$defs": {"safeInteger": safe_integer, "index": index, "indexArray": index_array, "adapterProposal": proposal, "executionInput": execution_input, "nodeAudit": node_audit, "executionResult": result},
        "oneOf": [{"$ref": "#/$defs/executionInput"}, {"$ref": "#/$defs/executionResult"}],
    }


def profile() -> dict[str, Any]:
    return {
        "schema_version": 1,
        "profile_id": PROFILE_ID,
        "parent_bundle_canonical_sha256": PARENT_BUNDLE,
        "source_lock_canonical_sha256": SOURCE_LOCK,
        "source_authority": "exact_current_p4_wp1_context_and_p4_wp2_ir_owner",
        "hash_contract": {"canonicalization": "RFC8785_JCS_IJSON_SAFE_SUBSET", "execution_prefix_utf8_hex": EXECUTION_PREFIX.hex().upper()},
        "execution_contract": {
            "selection_precedence": ["terminal", "mandatory", "legal_frontier"],
            "hard_tier_order": "lexicographic_ascending_safe_integer_array",
            "adapter_authority": "same_tier_ordering_hint_only",
            "base_veto_cannot_remove_forced_indexes": True,
            "fallback": "same_window_first_min",
            "option_order": "current_context_source_order",
            "node_audit": "every_ir_node_in_exact_graph_order",
        },
        "result_contract": {"serialized_result_is_execution_authority": False, "owner_revalidation_required": True, "selected_indexes_require_future_current_window_sanitization": True},
        "stable_error_codes": ["contract_error", "invalid_context", "invalid_ir", "invalid_execution_input", "forced_index_vetoed", "insufficient_candidates", "execution_integrity_invalid"],
        "private_identifier_tokens_denied": ["PRIVATE"],
        "private_keys_denied": ["raw_private_hash", "token_free_callback_hash", "search_begin_input", "session", "callback", "binding", "ticket", "command", "object_ref", "pokemon_entity_serial"],
        "scope": {"restricted_ir_executor": True, "adapter_implementation": False, "policy": False, "trace_issuer": False, "live_owner": False},
    }


def ordered_hint(current: list[int], proposals: list[dict[str, Any]], operator: str) -> list[int]:
    preferred: list[int] = []
    for proposal in proposals:
        if proposal["operator"] == operator:
            for index in proposal["indexes"]:
                if index in current and index not in preferred:
                    preferred.append(index)
    return preferred + [index for index in current if index not in preferred]


def expected_result(case_id: str, ir: dict[str, Any], context_hash: str, window_id: str, value: dict[str, Any]) -> dict[str, Any]:
    frontier = [0, 1]
    forced = value["terminal_indexes"] or value["mandatory_indexes"]
    current = list(frontier)
    audit: list[dict[str, Any]] = []
    tiers = {item["index"]: tuple(item["tier"]) for item in value["base_hard_tiers"]}
    for node in ir["nodes"]:
        before = list(current)
        op = node["operator"]
        if op == "legality_guard":
            current = list(frontier)
        elif op == "mandatory_terminal_guard" and forced:
            current = list(forced)
        elif op in ("goal_proposal", "macro_proposal", "tiebreak_score") and not forced:
            current = ordered_hint(current, value["adapter_proposals"], op)
        elif op == "hard_tier_filter" and not forced:
            best = min(tiers[index] for index in current)
            current = [index for index in current if tiers[index] == best]
        elif op == "base_veto" and not forced:
            current = [index for index in current if index not in value["base_vetoed_indexes"]]
        elif op == "deterministic_fallback":
            current = current[:1]
        audit.append({"node_id": node["node_id"], "operator": op, "owner": node["owner"], "input_indexes": before, "output_indexes": list(current)})
    reason = "terminal_selection" if value["terminal_indexes"] else "mandatory_selection" if value["mandatory_indexes"] else "deterministic_fallback"
    branch = "terminal" if value["terminal_indexes"] else "mandatory" if value["mandatory_indexes"] else "same_window_first_min"
    payload = {
        "schema_version": 1,
        "profile_id": PROFILE_ID,
        "execution_id": case_id,
        "source": {"context_hash": context_hash, "window_id": window_id, "ir_hash": ir["ir_hash"]},
        "selected_indexes": current,
        "reason_code": reason,
        "fallback_branch": branch,
        "node_audit": audit,
        "adapter_audit": copy.deepcopy(value["adapter_proposals"]),
        "authoritative": False,
    }
    return {**payload, "execution_hash": domain_hash(payload)}


def vectors() -> dict[str, Any]:
    parent = load(PARENT_VECTORS)
    irs = {case["id"]: case["expected_ir"] for case in parent["ir_cases"]}
    context_hash = parent["trace_fixture"]["context_hash"]
    window_id = parent["trace_cases"][0]["expected_trace"]["source"]["window_id"]
    base = {
        "mandatory_indexes": [],
        "terminal_indexes": [],
        "base_hard_tiers": [{"index": 0, "tier": [0, 0]}, {"index": 1, "tier": [0, 0]}],
        "base_vetoed_indexes": [],
        "adapter_proposals": [],
    }
    cases: list[dict[str, Any]] = []
    specs = [
        ("fallback-first", "minimal-base", {}),
        ("best-hard-tier", "minimal-base", {"base_hard_tiers": [{"index": 0, "tier": [1]}, {"index": 1, "tier": [0]}]}),
        ("base-veto-first", "minimal-base", {"base_vetoed_indexes": [0]}),
        ("mandatory-second", "minimal-base", {"mandatory_indexes": [1]}),
        ("terminal-over-mandatory", "minimal-base", {"mandatory_indexes": [0], "terminal_indexes": [1]}),
        ("goal-hint-second", "public-adapter-proposals", {"adapter_proposals": [{"operator": "goal_proposal", "indexes": [1], "reason_code": "public_goal_proposal"}]}),
        ("macro-hint-second", "public-adapter-proposals", {"adapter_proposals": [{"operator": "macro_proposal", "indexes": [1], "reason_code": "public_macro_proposal"}]}),
        ("tiebreak-hint-second", "public-adapter-proposals", {"adapter_proposals": [{"operator": "tiebreak_score", "indexes": [1], "reason_code": "public_tiebreak_proposal"}]}),
    ]
    for case_id, ir_id, changes in specs:
        value = copy.deepcopy(base)
        value.update(copy.deepcopy(changes))
        value = {"execution_id": case_id, **value}
        cases.append({"id": case_id, "ir_case_id": ir_id, "input": value, "expected_result": expected_result(case_id, irs[ir_id], context_hash, window_id, value)})
    rejections = [
        {"id": "fake-context", "fault": "fake_context", "expected_error_code": "invalid_context"},
        {"id": "fake-ir", "fault": "fake_ir", "expected_error_code": "invalid_ir"},
        {"id": "mandatory-not-list", "mutation": {"field": "mandatory_indexes", "value": True}, "expected_error_code": "invalid_execution_input"},
        {"id": "duplicate-mandatory", "mutation": {"field": "mandatory_indexes", "value": [0, 0]}, "expected_error_code": "invalid_execution_input"},
        {"id": "terminal-out-of-range", "mutation": {"field": "terminal_indexes", "value": [2]}, "expected_error_code": "invalid_execution_input"},
        {"id": "missing-tier", "mutation": {"field": "base_hard_tiers", "value": [{"index": 0, "tier": [0]}]}, "expected_error_code": "invalid_execution_input"},
        {"id": "forced-index-vetoed", "mutation": {"field": "mandatory_indexes", "value": [0], "also": {"field": "base_vetoed_indexes", "value": [0]}}, "expected_error_code": "forced_index_vetoed"},
        {"id": "unknown-proposal", "mutation": {"field": "adapter_proposals", "value": [{"operator": "python_callable", "indexes": [0], "reason_code": "public_goal_proposal"}]}, "expected_error_code": "invalid_execution_input"},
        {"id": "private-proposal", "mutation": {"field": "adapter_proposals", "value": [{"operator": "goal_proposal", "indexes": [0], "reason_code": "PRIVATE_SENTINEL"}]}, "expected_error_code": "invalid_execution_input"},
        {"id": "proposal-out-of-range", "mutation": {"field": "adapter_proposals", "value": [{"operator": "goal_proposal", "indexes": [2], "reason_code": "public_goal_proposal"}]}, "expected_error_code": "invalid_execution_input"},
        {"id": "veto-all", "mutation": {"field": "base_vetoed_indexes", "value": [0, 1]}, "expected_error_code": "insufficient_candidates"},
    ]
    return {
        "schema_version": 1,
        "vector_set_id": "ptcgdap-restricted-base-graph-executor-p4-wp3-v1",
        "profile_id": PROFILE_ID,
        "parent_ir_profile_id": parent["ir_profile_id"],
        "context_fixture": {"case_id": parent["trace_fixture"]["context_case_id"], "context_hash": context_hash, "window_id": window_id, "option_count": 2, "min_count": 1, "max_count": 1},
        "execution_cases": cases,
        "execution_rejections": rejections,
        "private_sentinels": parent["private_sentinels"],
        "consumer_rule": "Serialized execution results are audit/conformance values only. Future selection authority must revalidate exact current window and sanitize selected indexes in the owner call chain.",
    }


def artifacts() -> dict[str, Any]:
    docs = {ARTIFACTS[0]: schema(), ARTIFACTS[1]: profile(), ARTIFACTS[2]: vectors()}
    bundle = {
        "schema_version": 1,
        "bundle_id": BUNDLE_ID,
        "parent_bundle_canonical_sha256": PARENT_BUNDLE,
        "source_lock_canonical_sha256": SOURCE_LOCK,
        "artifacts": [
            {"id": name.removesuffix(".json"), "path": f"contracts/ptcgdap/{name}", "canonical_sha256": digest(docs[name])}
            for name in ARTIFACTS
        ],
    }
    return {**docs, "restricted_base_graph_executor_bundle.json": bundle}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    generated = artifacts()
    if args.check:
        bad = []
        for name, value in generated.items():
            path = CONTRACT_ROOT / name
            if not path.is_file() or path.read_bytes() != pretty(value):
                bad.append(name)
        if bad:
            print("artifact drift: " + ", ".join(bad), file=sys.stderr)
            return 1
        return 0
    for name, value in generated.items():
        (CONTRACT_ROOT / name).write_bytes(pretty(value))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
