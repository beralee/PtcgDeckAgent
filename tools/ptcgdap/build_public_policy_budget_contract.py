from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
CONTRACT_ROOT = ROOT / "contracts" / "ptcgdap"
PROFILE_ID = "ptcgdap-public-policy-budget-p4-wp6-v1"
BUNDLE_ID = PROFILE_ID
PARENT_BUNDLE = "18AAB663D9B429AC8657A75692F5DD8CF37C409CC057A328B57758C692FDB7F4"
SOURCE_LOCK = "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"
TOTAL_BUDGET_MS = 600_000
BASE_ONLY_THRESHOLD_MS = 30_000
FALLBACK_THRESHOLD_MS = 5_000
SAFE_MAX = 9_007_199_254_740_991
REQUIRED_CAPABILITIES = (
    "public_base_policy_v1",
    "current_window_sanitizer_v1",
    "deterministic_base_fallback_v1",
)
OPTIONAL_CAPABILITIES = (
    "public_deck_adapter_v1",
    "learned_policy_head_v1",
    "search_v1",
)
CAPABILITY_STATES = ("available", "unavailable", "unsupported")
MODES = ("full", "base_only", "deterministic_fallback")
LEDGER_PREFIX = b"PTCGDAP\0PUBLIC_POLICY_BUDGET_LEDGER_V1\0"
TELEMETRY_PREFIX = b"PTCGDAP\0PUBLIC_POLICY_BUDGET_TELEMETRY_V1\0"
RESULT_PREFIX = b"PTCGDAP\0PUBLIC_POLICY_BUDGET_RESULT_V1\0"
ARTIFACTS = (
    "public_policy_budget.schema.json",
    "public_policy_budget_profile.json",
    "public_policy_budget_conformance_vectors.json",
)


def canonical(value: Any) -> bytes:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")


def digest(value: Any) -> str:
    return hashlib.sha256(canonical(value)).hexdigest().upper()


def domain_hash(prefix: bytes, value: Any) -> str:
    return hashlib.sha256(prefix + canonical(value)).hexdigest().upper()


def pretty(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def identifier_schema() -> dict[str, Any]:
    return {
        "type": "string",
        "pattern": "^[a-z0-9][a-z0-9._-]{0,127}$",
        "not": {"pattern": "(?i:private)"},
    }


def schema() -> dict[str, Any]:
    ledger_properties = {
        "schema_version": {"const": 1},
        "profile_id": {"const": PROFILE_ID},
        "ledger_id": {"$ref": "#/$defs/identifier"},
        "decision_ordinal": {"$ref": "#/$defs/nonnegativeSafeInteger"},
        "total_budget_ms": {"const": TOTAL_BUDGET_MS},
        "remaining_ms": {"allOf": [{"$ref": "#/$defs/nonnegativeSafeInteger"}, {"maximum": TOTAL_BUDGET_MS}]},
        "cumulative_elapsed_ms": {"allOf": [{"$ref": "#/$defs/nonnegativeSafeInteger"}, {"maximum": TOTAL_BUDGET_MS}]},
        "previous_telemetry_hash": {"oneOf": [{"type": "null"}, {"$ref": "#/$defs/hash"}]},
        "ledger_hash": {"$ref": "#/$defs/hash"},
    }
    result_properties = {
        "schema_version": {"const": 1},
        "profile_id": {"const": PROFILE_ID},
        "ledger_id": {"$ref": "#/$defs/identifier"},
        "window_id": {"$ref": "#/$defs/hash"},
        "ledger_before_hash": {"$ref": "#/$defs/hash"},
        "decision_ordinal": {"$ref": "#/$defs/nonnegativeSafeInteger"},
        "remaining_before_ms": {"allOf": [{"$ref": "#/$defs/nonnegativeSafeInteger"}, {"maximum": TOTAL_BUDGET_MS}]},
        "elapsed_ms": {"$ref": "#/$defs/nonnegativeSafeInteger"},
        "remaining_after_ms": {"allOf": [{"$ref": "#/$defs/nonnegativeSafeInteger"}, {"maximum": TOTAL_BUDGET_MS}]},
        "mode": {"enum": list(MODES)},
        "reason_code": {
            "enum": [
                "full_budget_available",
                "budget_constrained",
                "optional_capability_unavailable",
                "budget_reserve",
                "budget_exhausted",
                "required_capability_unavailable",
                "unknown_capability",
            ]
        },
        "known_unavailable_capabilities": {
            "type": "array",
            "maxItems": len(REQUIRED_CAPABILITIES) + len(OPTIONAL_CAPABILITIES),
            "uniqueItems": True,
            "items": {"enum": list(REQUIRED_CAPABILITIES + OPTIONAL_CAPABILITIES)},
        },
        "unknown_capability_count": {"$ref": "#/$defs/nonnegativeSafeInteger"},
        "selected_indexes": {"$ref": "#/$defs/indexArray"},
        "fallback_used": {"type": "boolean"},
        "telemetry_hash": {"$ref": "#/$defs/hash"},
        "next_ledger": {"$ref": "#/$defs/ledger"},
        "authority": {"const": "public_policy_budget_audit"},
        "authoritative": {"const": False},
        "result_hash": {"$ref": "#/$defs/hash"},
    }
    ledger = {
        "type": "object",
        "additionalProperties": False,
        "required": list(ledger_properties),
        "properties": ledger_properties,
        "allOf": [
            {
                "if": {"properties": {"decision_ordinal": {"const": 0}}, "required": ["decision_ordinal"]},
                "then": {
                    "properties": {
                        "remaining_ms": {"const": TOTAL_BUDGET_MS},
                        "cumulative_elapsed_ms": {"const": 0},
                        "previous_telemetry_hash": {"type": "null"},
                    }
                },
                "else": {"properties": {"previous_telemetry_hash": {"$ref": "#/$defs/hash"}}},
            }
        ],
    }
    result = {
        "type": "object",
        "additionalProperties": False,
        "required": list(result_properties),
        "properties": result_properties,
        "allOf": [
            {
                "if": {"properties": {"mode": {"const": "deterministic_fallback"}}},
                "then": {"properties": {"fallback_used": {"const": True}, "selected_indexes": {"minItems": 0}}},
            },
            {
                "if": {"properties": {"mode": {"enum": ["full", "base_only"]}}},
                "then": {"properties": {"fallback_used": {"const": False}, "selected_indexes": {"maxItems": 0}}},
            },
            {
                "if": {"properties": {"mode": {"const": "full"}}},
                "then": {"properties": {"reason_code": {"const": "full_budget_available"}}},
            },
            {
                "if": {"properties": {"mode": {"const": "base_only"}}},
                "then": {"properties": {"reason_code": {"enum": ["budget_constrained", "optional_capability_unavailable"]}}},
            },
            {
                "if": {"properties": {"mode": {"const": "deterministic_fallback"}}},
                "then": {"properties": {"reason_code": {"enum": ["budget_reserve", "budget_exhausted", "required_capability_unavailable", "unknown_capability"]}}},
            },
            {
                "if": {"properties": {"reason_code": {"const": "unknown_capability"}}},
                "then": {"properties": {"unknown_capability_count": {"minimum": 1}}},
                "else": {"properties": {"unknown_capability_count": {"const": 0}}},
            },
        ],
    }
    return {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "https://ptcgdap.local/contracts/public_policy_budget.schema.json",
        "title": "PTCGDAP P4-WP6 public policy budget ledger and degradation audit",
        "$defs": {
            "safeInteger": {"type": "integer", "minimum": -SAFE_MAX, "maximum": SAFE_MAX},
            "nonnegativeSafeInteger": {"allOf": [{"$ref": "#/$defs/safeInteger"}, {"minimum": 0}]},
            "identifier": identifier_schema(),
            "hash": {"type": "string", "pattern": "^[0-9A-F]{64}$"},
            "index": {"$ref": "#/$defs/nonnegativeSafeInteger"},
            "indexArray": {"type": "array", "maxItems": 1024, "uniqueItems": True, "items": {"$ref": "#/$defs/index"}},
            "ledger": ledger,
            "result": result,
        },
        "oneOf": [{"$ref": "#/$defs/ledger"}, {"$ref": "#/$defs/result"}],
    }


def profile() -> dict[str, Any]:
    return {
        "schema_version": 1,
        "profile_id": PROFILE_ID,
        "parent_bundle_canonical_sha256": PARENT_BUNDLE,
        "source_lock_canonical_sha256": SOURCE_LOCK,
        "budget_contract": {
            "total_match_budget_ms": TOTAL_BUDGET_MS,
            "base_only_at_or_below_remaining_ms": BASE_ONLY_THRESHOLD_MS,
            "fallback_at_or_below_remaining_ms": FALLBACK_THRESHOLD_MS,
            "modes": list(MODES),
            "elapsed_input": "host_supplied_exact_nonnegative_safe_integer",
            "remaining_and_cumulative_saturate_at_budget_bounds": True,
        },
        "capability_contract": {
            "required": list(REQUIRED_CAPABILITIES),
            "optional": list(OPTIONAL_CAPABILITIES),
            "states": list(CAPABILITY_STATES),
            "unknown_name_behavior": "same_current_window_deterministic_fallback_without_name_echo",
            "missing_required_behavior": "same_current_window_deterministic_fallback",
            "missing_optional_adapter_behavior": "base_only",
            "missing_optional_learned_or_search_behavior": "ignore_without_remote_fallback",
        },
        "precedence": [
            "unknown_capability",
            "required_capability_unavailable",
            "budget_exhausted",
            "budget_reserve",
            "budget_constrained",
            "optional_capability_unavailable",
            "full_budget_available",
        ],
        "hash_contract": {
            "canonicalization": "RFC8785_JCS_IJSON_SAFE_SUBSET",
            "ledger_prefix_utf8_hex": LEDGER_PREFIX.hex().upper(),
            "telemetry_prefix_utf8_hex": TELEMETRY_PREFIX.hex().upper(),
            "result_prefix_utf8_hex": RESULT_PREFIX.hex().upper(),
        },
        "serialization_contract": {
            "ledger_and_result_are_execution_authority": False,
            "unknown_capability_names_are_serialized": False,
            "selected_indexes_only_exist_for_same_current_window_fallback": True,
            "consumer_must_revalidate_exact_window": True,
        },
        "scope": {
            "reads_clock": False,
            "network": False,
            "model": False,
            "host": False,
            "live_owner": False,
            "package_or_device_profile": False,
        },
    }


def ledger_payload(
    ledger_id: str,
    ordinal: int,
    remaining_ms: int,
    cumulative_elapsed_ms: int,
    previous_telemetry_hash: str | None,
) -> dict[str, Any]:
    payload = {
        "schema_version": 1,
        "profile_id": PROFILE_ID,
        "ledger_id": ledger_id,
        "decision_ordinal": ordinal,
        "total_budget_ms": TOTAL_BUDGET_MS,
        "remaining_ms": remaining_ms,
        "cumulative_elapsed_ms": cumulative_elapsed_ms,
        "previous_telemetry_hash": previous_telemetry_hash,
    }
    return {**payload, "ledger_hash": domain_hash(LEDGER_PREFIX, payload)}


def classify(elapsed_ms: int, capabilities: dict[str, str]) -> tuple[str, str, list[str], int, int]:
    known = set(REQUIRED_CAPABILITIES + OPTIONAL_CAPABILITIES)
    unknown_count = sum(1 for key in capabilities if key not in known)
    unavailable = sorted(key for key in known if capabilities.get(key) != "available")
    remaining = max(0, TOTAL_BUDGET_MS - elapsed_ms)
    if unknown_count:
        return "deterministic_fallback", "unknown_capability", unavailable, unknown_count, remaining
    if any(capabilities.get(key) != "available" for key in REQUIRED_CAPABILITIES):
        return "deterministic_fallback", "required_capability_unavailable", unavailable, 0, remaining
    if remaining == 0:
        return "deterministic_fallback", "budget_exhausted", unavailable, 0, remaining
    if remaining <= FALLBACK_THRESHOLD_MS:
        return "deterministic_fallback", "budget_reserve", unavailable, 0, remaining
    if remaining <= BASE_ONLY_THRESHOLD_MS:
        return "base_only", "budget_constrained", unavailable, 0, remaining
    if capabilities.get("public_deck_adapter_v1") != "available":
        return "base_only", "optional_capability_unavailable", unavailable, 0, remaining
    return "full", "full_budget_available", unavailable, 0, remaining


def result_payload(
    ledger: dict[str, Any],
    window_id: str,
    elapsed_ms: int,
    capabilities: dict[str, str],
    fallback_indexes: list[int],
) -> dict[str, Any]:
    mode, reason, unavailable, unknown_count, remaining = classify(elapsed_ms, capabilities)
    charged = min(elapsed_ms, ledger["remaining_ms"])
    telemetry = {
        "schema_version": 1,
        "profile_id": PROFILE_ID,
        "ledger_id": ledger["ledger_id"],
        "window_id": window_id,
        "ledger_before_hash": ledger["ledger_hash"],
        "decision_ordinal": ledger["decision_ordinal"] + 1,
        "remaining_before_ms": ledger["remaining_ms"],
        "elapsed_ms": elapsed_ms,
        "charged_elapsed_ms": charged,
        "remaining_after_ms": remaining,
        "mode": mode,
        "reason_code": reason,
        "known_unavailable_capabilities": unavailable,
        "unknown_capability_count": unknown_count,
        "fallback_used": mode == "deterministic_fallback",
    }
    telemetry_hash = domain_hash(TELEMETRY_PREFIX, telemetry)
    next_ledger = ledger_payload(
        ledger["ledger_id"],
        ledger["decision_ordinal"] + 1,
        remaining,
        min(TOTAL_BUDGET_MS, ledger["cumulative_elapsed_ms"] + charged),
        telemetry_hash,
    )
    payload = {
        "schema_version": 1,
        "profile_id": PROFILE_ID,
        "ledger_id": ledger["ledger_id"],
        "window_id": window_id,
        "ledger_before_hash": ledger["ledger_hash"],
        "decision_ordinal": ledger["decision_ordinal"] + 1,
        "remaining_before_ms": ledger["remaining_ms"],
        "elapsed_ms": elapsed_ms,
        "remaining_after_ms": remaining,
        "mode": mode,
        "reason_code": reason,
        "known_unavailable_capabilities": unavailable,
        "unknown_capability_count": unknown_count,
        "selected_indexes": fallback_indexes if mode == "deterministic_fallback" else [],
        "fallback_used": mode == "deterministic_fallback",
        "telemetry_hash": telemetry_hash,
        "next_ledger": next_ledger,
        "authority": "public_policy_budget_audit",
        "authoritative": False,
    }
    return {**payload, "result_hash": domain_hash(RESULT_PREFIX, payload)}


def vectors() -> dict[str, Any]:
    strategic = json.loads((CONTRACT_ROOT / "strategic_context_v18_conformance_vectors.json").read_text(encoding="utf-8"))
    window_id = strategic["fixture"]["expected_window"]["window_id"]
    ledger_id = "fixture.public-policy-budget"
    initial = ledger_payload(ledger_id, 0, TOTAL_BUDGET_MS, 0, None)
    all_available = {key: "available" for key in REQUIRED_CAPABILITIES + OPTIONAL_CAPABILITIES}
    specs: list[tuple[str, int, dict[str, str]]] = [
        ("full-budget", 0, all_available),
        ("full-optional-absent", 1, {**all_available, "learned_policy_head_v1": "unsupported", "search_v1": "unavailable"}),
        ("base-threshold", 570_000, all_available),
        ("base-adapter-unavailable", 1, {**all_available, "public_deck_adapter_v1": "unsupported"}),
        ("fallback-threshold", 595_000, all_available),
        ("budget-exhausted", 600_000, all_available),
        ("required-missing", 1, {key: value for key, value in all_available.items() if key != "public_base_policy_v1"}),
        ("unknown-capability", 1, {**all_available, "vendor.future_capability": "available"}),
    ]
    cases = [
        {
            "id": case_id,
            "elapsed_ms": elapsed,
            "capabilities": copy.deepcopy(capabilities),
            "expected_result": result_payload(initial, window_id, elapsed, capabilities, [0]),
        }
        for case_id, elapsed, capabilities in specs
    ]
    rejections = [
        {"id": "fake-ledger", "fault": "fake_ledger", "expected_error_code": "invalid_ledger"},
        {"id": "fake-window", "fault": "fake_window", "expected_error_code": "invalid_window"},
        {"id": "elapsed-bool", "fault": "elapsed_bool", "expected_error_code": "invalid_elapsed_ms"},
        {"id": "elapsed-negative", "fault": "elapsed_negative", "expected_error_code": "invalid_elapsed_ms"},
        {"id": "elapsed-unsafe", "fault": "elapsed_unsafe", "expected_error_code": "invalid_elapsed_ms"},
        {"id": "capabilities-not-object", "fault": "capabilities_not_object", "expected_error_code": "invalid_capability_report"},
        {"id": "capability-state-not-string", "fault": "capability_state_not_string", "expected_error_code": "invalid_capability_report"},
        {"id": "capability-state-unknown", "fault": "capability_state_unknown", "expected_error_code": "invalid_capability_report"},
    ]
    return {
        "schema_version": 1,
        "vector_set_id": "ptcgdap-public-policy-budget-conformance-p4-wp6-v1",
        "profile_id": PROFILE_ID,
        "fixture": {
            "ledger_id": ledger_id,
            "window_id": window_id,
            "initial_ledger": initial,
            "all_available_capabilities": all_available,
        },
        "step_cases": cases,
        "rejections": rejections,
        "private_sentinels": ["PRIVATE_CLOCK_SENTINEL", "PRIVATE_CAPABILITY_SENTINEL", "PRIVATE_HOST_SENTINEL"],
        "consumer_rule": "Serialized ledgers and results are public audit only and never execution authority.",
    }


def bundle(documents: dict[str, Any]) -> dict[str, Any]:
    return {
        "schema_version": 1,
        "bundle_id": BUNDLE_ID,
        "parent_bundle_canonical_sha256": PARENT_BUNDLE,
        "source_lock_canonical_sha256": SOURCE_LOCK,
        "artifacts": [
            {
                "id": name.removesuffix(".json"),
                "path": f"contracts/ptcgdap/{name}",
                "canonical_sha256": digest(documents[name]),
            }
            for name in ARTIFACTS
        ],
    }


def documents() -> dict[str, Any]:
    values = {
        "public_policy_budget.schema.json": schema(),
        "public_policy_budget_profile.json": profile(),
        "public_policy_budget_conformance_vectors.json": vectors(),
    }
    return {**values, "public_policy_budget_bundle.json": bundle(values)}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    expected = documents()
    failures: list[str] = []
    for name, value in expected.items():
        path = CONTRACT_ROOT / name
        rendered = pretty(value)
        if args.check:
            if not path.is_file() or path.read_bytes() != rendered:
                failures.append(name)
        else:
            path.write_bytes(rendered)
    if failures:
        raise SystemExit("contract artifacts differ: " + ", ".join(failures))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
