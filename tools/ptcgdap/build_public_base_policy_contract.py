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
PROFILE_ID = "ptcgdap-public-base-policy-p4-wp5-v1"
BUNDLE_ID = PROFILE_ID
PARENT_BUNDLE = "C80F4C4FDAEA5AC29BD3C5617BFAC72BE38709696F7EA1995D3D153113DD3CA1"
SOURCE_LOCK = "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"
ORCHESTRATION_PREFIX = b"PTCGDAP\0PUBLIC_BASE_POLICY_ORCHESTRATION_V1\0"
EXECUTION_PREFIX = b"PTCGDAP\0RESTRICTED_BASE_GRAPH_EXECUTION_V1\0"
DECISION_PREFIX = b"PTCGDAP\0POLICY_DECISION_AUDIT_V1\0"
TRACE_PREFIX = b"PTCGDAP\0STRATEGIC_TRACE_V2\0"
ARTIFACTS = (
    "public_base_policy.schema.json",
    "public_base_policy_profile.json",
    "public_base_policy_conformance_vectors.json",
)
STAGES = (
    "validate_exact_owners",
    "propose_public_adapter_hints",
    "execute_restricted_base_graph",
    "sanitize_against_exact_current_window",
    "issue_policy_decision",
    "issue_strategic_trace",
    "seal_public_audit_result",
)
REQUEST_KEYS = (
    "orchestration_id",
    "proposal_id",
    "execution_id",
    "scene_id",
    "decision_id",
    "determinism_key",
    "trace_id",
    "policy_hash",
    "mandatory_indexes",
    "terminal_indexes",
    "base_hard_tiers",
    "base_vetoed_indexes",
)
SAFE_MAX = 9007199254740991


def canonical(value: Any) -> bytes:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")


def digest(value: Any) -> str:
    return hashlib.sha256(canonical(value)).hexdigest().upper()


def domain_hash(prefix: bytes, value: Any) -> str:
    return hashlib.sha256(prefix + canonical(value)).hexdigest().upper()


def pretty(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def load(name: str) -> Any:
    return json.loads((CONTRACT_ROOT / name).read_text(encoding="utf-8"))


def identifier_schema() -> dict[str, Any]:
    return {"type": "string", "pattern": "^[a-z0-9][a-z0-9._-]{0,127}$", "not": {"pattern": "(?i:private)"}}


def schema() -> dict[str, Any]:
    tier_entry = {
        "type": "object",
        "additionalProperties": False,
        "required": ["index", "tier"],
        "properties": {
            "index": {"$ref": "#/$defs/index"},
            "tier": {"type": "array", "minItems": 1, "maxItems": 8, "items": {"$ref": "#/$defs/safeInteger"}},
        },
    }
    request = {
        "type": "object",
        "additionalProperties": False,
        "required": list(REQUEST_KEYS),
        "properties": {
            **{key: {"$ref": "#/$defs/identifier"} for key in REQUEST_KEYS[:7]},
            "policy_hash": {"$ref": "#/$defs/hash"},
            "mandatory_indexes": {"$ref": "#/$defs/indexArray"},
            "terminal_indexes": {"$ref": "#/$defs/indexArray"},
            "base_hard_tiers": {"type": "array", "maxItems": 1024, "items": {"$ref": "#/$defs/tierEntry"}},
            "base_vetoed_indexes": {"$ref": "#/$defs/indexArray"},
        },
    }
    result = {
        "type": "object",
        "additionalProperties": False,
        "required": ["schema_version", "profile_id", "orchestration_id", "source", "selected_indexes", "owner_layer", "reason_code", "fallback_tier", "completed_stages", "public_only", "authority", "authoritative", "orchestration_hash"],
        "properties": {
            "schema_version": {"const": 1},
            "profile_id": {"const": PROFILE_ID},
            "orchestration_id": {"$ref": "#/$defs/identifier"},
            "source": {
                "type": "object",
                "additionalProperties": False,
                "required": ["context_hash", "window_id", "ir_hash", "adapter_hash", "proposal_hash", "execution_hash", "decision_audit_id", "trace_hash", "policy_hash"],
                "properties": {key: {"$ref": "#/$defs/hash"} for key in ("context_hash", "window_id", "ir_hash", "adapter_hash", "proposal_hash", "execution_hash", "decision_audit_id", "trace_hash", "policy_hash")},
            },
            "selected_indexes": {"$ref": "#/$defs/indexArray"},
            "owner_layer": {"enum": ["base_graph", "base_fallback"]},
            "reason_code": {"enum": ["policy_selection_accepted", "window_fallback_only", "invalid_policy_output", "policy_exception", "policy_timeout", "policy_unavailable"]},
            "fallback_tier": {"enum": ["none", "same_public_window_deterministic"]},
            "completed_stages": {"const": list(STAGES)},
            "public_only": {"const": True},
            "authority": {"const": "public_base_policy_orchestration_audit"},
            "authoritative": {"const": False},
            "orchestration_hash": {"$ref": "#/$defs/hash"},
        },
        "allOf": [
            {"if": {"properties": {"owner_layer": {"const": "base_graph"}}}, "then": {"properties": {"reason_code": {"const": "policy_selection_accepted"}, "fallback_tier": {"const": "none"}}}},
            {"if": {"properties": {"owner_layer": {"const": "base_fallback"}}}, "then": {"properties": {"fallback_tier": {"const": "same_public_window_deterministic"}}}},
        ],
    }
    return {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "https://ptcgdap.local/contracts/public_base_policy.schema.json",
        "title": "PTCGDAP P4-WP5 public Base policy orchestration request and audit result",
        "$defs": {
            "safeInteger": {"type": "integer", "minimum": -SAFE_MAX, "maximum": SAFE_MAX},
            "identifier": identifier_schema(),
            "hash": {"type": "string", "pattern": "^[0-9A-F]{64}$"},
            "index": {"allOf": [{"$ref": "#/$defs/safeInteger"}, {"minimum": 0}]},
            "indexArray": {"type": "array", "maxItems": 1024, "uniqueItems": True, "items": {"$ref": "#/$defs/index"}},
            "tierEntry": tier_entry,
            "orchestrationRequest": request,
            "orchestrationResult": result,
        },
        "oneOf": [{"$ref": "#/$defs/orchestrationRequest"}, {"$ref": "#/$defs/orchestrationResult"}],
    }


def profile() -> dict[str, Any]:
    return {
        "schema_version": 1,
        "profile_id": PROFILE_ID,
        "parent_bundle_canonical_sha256": PARENT_BUNDLE,
        "source_lock_canonical_sha256": SOURCE_LOCK,
        "upstream_bundle_canonical_sha256": {
            "strategic_context_v18": "AACFA7E2E7F914180A2B7A5C4D92D6514ACC5F4622FC95B57DC225673893F98F",
            "strategic_trace_v2_ir": "ADDD4CB48BD10FA0478854124D8E63AEE42B898C0EB81692BA35F8D7F90414C4",
            "restricted_executor": "69D05747A9F91C19765D448B676C86E1D9DFA1BBAB108ED1374B854B34E48389",
            "public_deck_adapter": PARENT_BUNDLE,
        },
        "hash_contract": {"canonicalization": "RFC8785_JCS_IJSON_SAFE_SUBSET", "orchestration_prefix_utf8_hex": ORCHESTRATION_PREFIX.hex().upper()},
        "orchestration_contract": {
            "fixed_stage_order": list(STAGES),
            "base_public_inputs": list(REQUEST_KEYS[8:]),
            "identity_inputs": list(REQUEST_KEYS[:8]),
            "failure_atomicity": "no_partial_proposal_execution_resolution_decision_or_trace",
            "executor_output_revalidated_by_current_window_sanitizer": True,
            "mandatory_terminal_precedes_hard_tier": True,
            "adapter_authority": "same_base_tier_ordering_hint_only",
        },
        "result_contract": {
            "serialized_result_is_execution_authority": False,
            "exact_owner_revalidation_required": True,
            "decision_and_trace_remain_exact_object_bound": True,
            "agent_output_requires_integrity": True,
        },
        "stable_failed_stages": ["contract", *STAGES],
        "stable_error_codes": ["contract_error", "invalid_context", "invalid_window", "invalid_ir", "invalid_adapter", "invalid_orchestration_input", "private_orchestration_input", "adapter_proposal_failed", "base_execution_failed", "selection_sanitization_failed", "policy_decision_failed", "strategic_trace_failed", "orchestration_integrity_invalid"],
        "private_keys_denied": ["raw_private_hash", "token_free_callback_hash", "search_begin_input", "session", "callback", "binding", "ticket", "command", "object_ref", "pokemon_entity_serial"],
        "scope": {"policy_orchestration": True, "policy_decision_issuer": True, "strategic_trace_issuer": True, "deck_specific_rules": False, "model": False, "time_budget_telemetry": False, "live_owner": False},
    }


def _ordered_hint(current: list[int], proposals: list[dict[str, Any]], operator: str) -> list[int]:
    preferred: list[int] = []
    for proposal in proposals:
        if proposal["operator"] == operator:
            for index in proposal["indexes"]:
                if index in current and index not in preferred:
                    preferred.append(index)
    return preferred + [index for index in current if index not in preferred]


def execution(context: dict[str, Any], ir: dict[str, Any], request: dict[str, Any], proposals: list[dict[str, Any]]) -> dict[str, Any]:
    option_count = context["source"]["option_count"]
    mandatory, terminal = request["mandatory_indexes"], request["terminal_indexes"]
    forced = terminal or mandatory
    current = list(range(option_count))
    tiers = {entry["index"]: tuple(entry["tier"]) for entry in request["base_hard_tiers"]}
    audit = []
    for node in ir["nodes"]:
        before = list(current); operator = node["operator"]
        if operator == "legality_guard": current = list(range(option_count))
        elif operator == "mandatory_terminal_guard" and forced: current = list(forced)
        elif operator in {"goal_proposal", "macro_proposal", "tiebreak_score"} and not forced: current = _ordered_hint(current, proposals, operator)
        elif operator == "hard_tier_filter" and not forced and current:
            best = min(tiers[index] for index in current); current = [index for index in current if tiers[index] == best]
        elif operator == "base_veto" and not forced: current = [index for index in current if index not in request["base_vetoed_indexes"]]
        elif operator == "deterministic_fallback": current = current[:context["select_semantics"]["min_count"]]
        audit.append({"node_id": node["node_id"], "operator": operator, "owner": node["owner"], "input_indexes": before, "output_indexes": list(current)})
    if terminal: reason, branch = "terminal_selection", "terminal"
    elif mandatory: reason, branch = "mandatory_selection", "mandatory"
    else: reason, branch = "deterministic_fallback", "same_window_first_min"
    payload = {
        "schema_version": 1,
        "profile_id": "ptcgdap-restricted-base-graph-executor-p4-wp3-v1",
        "execution_id": request["execution_id"],
        "source": {"context_hash": context["context_hash"], "window_id": context["source"]["window_id"], "ir_hash": ir["ir_hash"]},
        "selected_indexes": current,
        "reason_code": reason,
        "fallback_branch": branch,
        "node_audit": audit,
        "adapter_audit": copy.deepcopy(proposals),
        "authoritative": False,
    }
    return {**payload, "execution_hash": domain_hash(EXECUTION_PREFIX, payload)}


def decision(context: dict[str, Any], window: dict[str, Any], request: dict[str, Any], selected: list[int]) -> dict[str, Any]:
    fingerprints = window["option_fingerprints"]
    payload = {
        "schema_version": 1,
        "profile_id": "ptcgdap-policy-decision-p4-wp1-v1",
        "selected_indexes": selected,
        "selected_semantic_intent": {"kind": "current_option_fingerprints", "options": [{"index": index, "fingerprint": fingerprints[index]} for index in selected]},
        "owner_layer": "base_graph",
        "reason_code": "policy_selection_accepted",
        "fallback_tier": "none",
        "context_hash": context["context_hash"],
        "policy_hash": request["policy_hash"],
        "window_id": window["window_id"],
        "public_observation_hash": window["public_observation_hash"],
        "scene_id": request["scene_id"],
        "decision_id": request["decision_id"],
        "determinism_key": request["determinism_key"],
        "authority": "policy_decision_public_audit",
        "authoritative": False,
    }
    return {**payload, "audit_id": domain_hash(DECISION_PREFIX, payload)}


def trace(context: dict[str, Any], decision_value: dict[str, Any], ir: dict[str, Any], request: dict[str, Any], proposals: list[dict[str, Any]]) -> dict[str, Any]:
    payload = {
        "schema_version": 2,
        "profile_id": "ptcgdap-strategic-trace-v2-p4-wp2-v1",
        "trace_id": request["trace_id"],
        "identities": {"scene_id": decision_value["scene_id"], "decision_id": decision_value["decision_id"], "determinism_key": decision_value["determinism_key"]},
        "source": {"context_hash": context["context_hash"], "decision_audit_id": decision_value["audit_id"], "policy_hash": decision_value["policy_hash"], "window_id": decision_value["window_id"], "public_observation_hash": decision_value["public_observation_hash"]},
        "ir": {"graph_id": ir["graph_id"], "ir_hash": ir["ir_hash"], "required_capabilities": copy.deepcopy(ir["required_capabilities"])},
        "frontier": {
            "option_fingerprints": [value["fingerprint"] for value in context["select_semantics"]["options"]],
            "legal_indexes": list(range(context["source"]["option_count"])),
            "strategic_indexes": list(range(context["source"]["option_count"])),
            "mandatory_indexes": copy.deepcopy(request["mandatory_indexes"]),
            "terminal_indexes": copy.deepcopy(request["terminal_indexes"]),
            "base_hard_tiers": copy.deepcopy(request["base_hard_tiers"]),
            "base_vetoed_indexes": copy.deepcopy(request["base_vetoed_indexes"]),
        },
        "adapter_proposals": copy.deepcopy(proposals),
        "owner_audit": [{"node_id": value["node_id"], "operator": value["operator"], "owner": value["owner"]} for value in ir["nodes"]],
        "decision": {"selected_indexes": copy.deepcopy(decision_value["selected_indexes"]), "owner_layer": decision_value["owner_layer"], "reason_code": decision_value["reason_code"], "fallback_tier": decision_value["fallback_tier"]},
        "fallback_reason": "",
        "public_only": True,
        "authority": "strategic_trace_v2_public_audit",
        "authoritative": False,
    }
    return {**payload, "trace_hash": domain_hash(TRACE_PREFIX, payload)}


def result(context: dict[str, Any], ir: dict[str, Any], adapter: dict[str, Any], proposal: dict[str, Any], execution_value: dict[str, Any], decision_value: dict[str, Any], trace_value: dict[str, Any], request: dict[str, Any]) -> dict[str, Any]:
    payload = {
        "schema_version": 1,
        "profile_id": PROFILE_ID,
        "orchestration_id": request["orchestration_id"],
        "source": {"context_hash": context["context_hash"], "window_id": context["source"]["window_id"], "ir_hash": ir["ir_hash"], "adapter_hash": adapter["adapter_hash"], "proposal_hash": proposal["proposal_hash"], "execution_hash": execution_value["execution_hash"], "decision_audit_id": decision_value["audit_id"], "trace_hash": trace_value["trace_hash"], "policy_hash": request["policy_hash"]},
        "selected_indexes": copy.deepcopy(decision_value["selected_indexes"]),
        "owner_layer": decision_value["owner_layer"],
        "reason_code": decision_value["reason_code"],
        "fallback_tier": decision_value["fallback_tier"],
        "completed_stages": list(STAGES),
        "public_only": True,
        "authority": "public_base_policy_orchestration_audit",
        "authoritative": False,
    }
    return {**payload, "orchestration_hash": domain_hash(ORCHESTRATION_PREFIX, payload)}


def request(case_id: str, mandatory: list[int], terminal: list[int], tiers: list[list[int]], vetoed: list[int]) -> dict[str, Any]:
    return {
        "orchestration_id": f"{case_id}.orchestration",
        "proposal_id": f"{case_id}.proposal",
        "execution_id": f"{case_id}.execution",
        "scene_id": f"{case_id}.scene",
        "decision_id": f"{case_id}.decision",
        "determinism_key": f"{case_id}.determinism",
        "trace_id": f"{case_id}.trace",
        "policy_hash": hashlib.sha256(b"PTCGDAP_PUBLIC_BASE_POLICY_FIXTURE_V1").hexdigest().upper(),
        "mandatory_indexes": mandatory,
        "terminal_indexes": terminal,
        "base_hard_tiers": [{"index": index, "tier": tier} for index, tier in enumerate(tiers)],
        "base_vetoed_indexes": vetoed,
    }


def vectors() -> dict[str, Any]:
    context_vectors = load("strategic_context_v18_conformance_vectors.json")
    trace_vectors = load("strategic_trace_v2_conformance_vectors.json")
    adapter_vectors = load("public_deck_adapter_conformance_vectors.json")
    context = context_vectors["fixture"]["expected_context"]
    window = context_vectors["fixture"]["expected_window"]
    ir_case = next(value for value in trace_vectors["ir_cases"] if value["id"] == "public-adapter-proposals")
    adapter_case = next(value for value in adapter_vectors["adapter_documents"] if value["id"] == "stable")
    adapter = adapter_case["expected_adapter"]
    proposal_template = next(value["expected_result"] for value in adapter_vectors["proposal_cases"] if value["id"] == "stable-proposal")
    specs = [
        ("adapter-hint", [], [], [[0], [0]], []),
        ("best-hard-tier", [], [], [[1], [0]], []),
        ("veto-adapter-first", [], [], [[0], [0]], [1]),
        ("mandatory-nonminimum-tier", [0], [], [[1], [0]], []),
        ("terminal-nonminimum-tier", [1], [0], [[1], [0]], []),
    ]
    cases = []
    for case_id, mandatory, terminal, tiers, vetoed in specs:
        request_value = request(case_id, mandatory, terminal, tiers, vetoed)
        proposal_payload = {key: copy.deepcopy(value) for key, value in proposal_template.items() if key != "proposal_hash"}
        proposal_payload["proposal_id"] = request_value["proposal_id"]
        proposal_value = {**proposal_payload, "proposal_hash": domain_hash(b"PTCGDAP\0PUBLIC_DECK_ADAPTER_PROPOSAL_V1\0", proposal_payload)}
        execution_value = execution(context, ir_case["expected_ir"], request_value, proposal_value["adapter_proposals"])
        decision_value = decision(context, window, request_value, execution_value["selected_indexes"])
        trace_value = trace(context, decision_value, ir_case["expected_ir"], request_value, proposal_value["adapter_proposals"])
        result_value = result(context, ir_case["expected_ir"], adapter, proposal_value, execution_value, decision_value, trace_value, request_value)
        cases.append({
            "id": case_id,
            "request": request_value,
            "expected_selected_indexes": execution_value["selected_indexes"],
            "expected_decision_audit_id": decision_value["audit_id"],
            "expected_trace_hash": trace_value["trace_hash"],
            "expected_result": result_value,
        })
    rejections = [
        {"id": "fake-context", "fault": "fake_context", "expected_failed_stage": "validate_exact_owners", "expected_error_code": "invalid_context"},
        {"id": "fake-window", "fault": "fake_window", "expected_failed_stage": "validate_exact_owners", "expected_error_code": "invalid_window"},
        {"id": "fake-ir", "fault": "fake_ir", "expected_failed_stage": "validate_exact_owners", "expected_error_code": "invalid_ir"},
        {"id": "fake-adapter", "fault": "fake_adapter", "expected_failed_stage": "validate_exact_owners", "expected_error_code": "invalid_adapter"},
        {"id": "private-identity", "fault": "private_identity", "expected_failed_stage": "validate_exact_owners", "expected_error_code": "private_orchestration_input"},
        {"id": "lowercase-policy-hash", "fault": "lowercase_policy_hash", "expected_failed_stage": "validate_exact_owners", "expected_error_code": "invalid_orchestration_input"},
        {"id": "mandatory-bool", "fault": "mandatory_bool", "expected_failed_stage": "validate_exact_owners", "expected_error_code": "invalid_orchestration_input"},
        {"id": "forced-veto", "fault": "forced_veto", "expected_failed_stage": "execute_restricted_base_graph", "expected_error_code": "base_execution_failed"},
        {"id": "cross-window", "fault": "cross_window", "expected_failed_stage": "validate_exact_owners", "expected_error_code": "invalid_window"},
        {"id": "mutated-adapter", "fault": "mutated_adapter", "expected_failed_stage": "validate_exact_owners", "expected_error_code": "invalid_adapter"},
    ]
    return {
        "schema_version": 1,
        "vector_set_id": PROFILE_ID,
        "profile_id": PROFILE_ID,
        "fixture": {"context_fixture_id": "regular-accepted", "ir_case_id": "public-adapter-proposals", "adapter_case_id": "stable", "option_count": 2},
        "orchestration_cases": cases,
        "orchestration_rejections": rejections,
        "private_sentinels": ["PRIVATE", "PRIVATE_HAND_SENTINEL", "PRIVATE_SEARCH_SENTINEL", "PRIVATE_SESSION_SENTINEL"],
        "consumer_rule": "The orchestration result, PolicyDecision and Strategic Trace are public audit only. Future selection, binding, ticket and engine owners must revalidate exact current authority.",
    }


def artifacts() -> dict[str, Any]:
    values = {ARTIFACTS[0]: schema(), ARTIFACTS[1]: profile(), ARTIFACTS[2]: vectors()}
    bundle = {
        "schema_version": 1,
        "bundle_id": BUNDLE_ID,
        "parent_bundle_canonical_sha256": PARENT_BUNDLE,
        "source_lock_canonical_sha256": SOURCE_LOCK,
        "artifacts": [{"id": name.removesuffix(".json"), "path": f"contracts/ptcgdap/{name}", "canonical_sha256": digest(values[name])} for name in ARTIFACTS],
    }
    return {**values, "public_base_policy_bundle.json": bundle}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    generated = artifacts()
    if args.check:
        bad = [name for name, value in generated.items() if not (CONTRACT_ROOT / name).is_file() or (CONTRACT_ROOT / name).read_bytes() != pretty(value)]
        if bad:
            print("artifact drift: " + ", ".join(bad), file=sys.stderr)
            return 1
        return 0
    for name, value in generated.items():
        (CONTRACT_ROOT / name).write_bytes(pretty(value))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
