from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
import sys
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


PROFILE_ID = "marnie_portable_policy_profile_v1"
CONTRACT_ID = "ptcgdap-marnie-portable-policy-p5-wp7-v1"
AUDIT_ID = "ptcgdap-marnie-portable-policy-audit-v1"
VECTOR_SET_ID = "ptcgdap-marnie-portable-policy-conformance-v1"
TRACE_PREFIX = b"PTCGDAP\0MARNIE_PORTABLE_TRACE_V1\0"
PARENT_HASHES = {
    "marnie_capability_policy": "F4E88E5DB4E480BA8441BE7B3A7C81CE3DB40ED1917EB37BCDCAC1C32B1ABD6C",
    "marnie_public_base": "67EBA6348277001692942FD58E8D1B9D50C54F0FFC783D8802BA3CCB45691105",
    "marnie_trajectory_replay": "E203A688BEC1AFFFABAAF06098361B3FAE04B84431F99AE75A19F891BFA9599F",
}
PARENT_PATHS = {
    "marnie_capability_policy": "contracts/ptcgdap/marnie_capability_policy_bundle.json",
    "marnie_public_base": "contracts/ptcgdap/marnie_public_base_bundle.json",
    "marnie_trajectory_replay": "contracts/ptcgdap/marnie_trajectory_replay_bundle.json",
}
FRAME_IDS = (
    "w0_initial",
    "w1_setup_active",
    "w2_setup_bench",
    "w3_main",
    "w4_spikemuth_deck",
    "w5_punk_up_sources",
    "w5_punk_up_target_1",
    "w5_punk_up_target_2",
    "w6_shadow_bullet_attack",
    "w6_shadow_bullet_target",
    "w7_take_prize",
    "w7_forced_send_out",
    "w7_terminal",
)
BASE_FRAMES = frozenset(FRAME_IDS) - {"w0_initial", "w2_setup_bench", "w7_terminal"}
NODE_CATALOG = (
    {
        "node_id": "n00_initial_deck",
        "owner_route": "capability_initial_deck",
        "output_domain": "initial_deck_card_ids",
        "action_owner": "capability_policy",
    },
    {
        "node_id": "n10_base_final",
        "owner_route": "base_final",
        "output_domain": "current_window_indexes",
        "action_owner": "public_base_graph",
    },
    {
        "node_id": "n20_optional_zero",
        "owner_route": "capability_optional_zero",
        "output_domain": "current_window_indexes",
        "action_owner": "capability_policy",
    },
    {
        "node_id": "n90_terminal",
        "owner_route": "terminal_lifecycle",
        "output_domain": "terminal_no_callback",
        "action_owner": "lifecycle",
    },
)


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def _canonical_hash(value: Any) -> str:
    return _sha(canonical_json_v1_bytes(value))


def _domain_hash(prefix: bytes, value: Any) -> str:
    return _sha(prefix + canonical_json_v1_bytes(value))


def _dispatch() -> list[dict[str, Any]]:
    result = []
    for ordinal, frame_id in enumerate(FRAME_IDS):
        if frame_id == "w0_initial":
            node_id = "n00_initial_deck"
            route = "capability_initial_deck"
            domain = "initial_deck_card_ids"
        elif frame_id == "w2_setup_bench":
            node_id = "n20_optional_zero"
            route = "capability_optional_zero"
            domain = "current_window_indexes"
        elif frame_id == "w7_terminal":
            node_id = "n90_terminal"
            route = "terminal_lifecycle"
            domain = "terminal_no_callback"
        else:
            node_id = "n10_base_final"
            route = "base_final"
            domain = "current_window_indexes"
        result.append(
            {
                "ordinal": ordinal,
                "frame_id": frame_id,
                "node_id": node_id,
                "owner_route": route,
                "output_domain": domain,
                "parent_base_case_id": f"source-{frame_id.replace('_', '-')}",
            }
        )
    return result


def _profile() -> dict[str, Any]:
    return {
        "schema_version": 1,
        "artifact_kind": "profile",
        "profile_id": PROFILE_ID,
        "status": "offline_shadow",
        "parent_bundle_hashes": copy.deepcopy(PARENT_HASHES),
        "portable_nodes": copy.deepcopy(list(NODE_CATALOG)),
        "dispatch": _dispatch(),
        "hash_profiles": {"portable_trace": {"prefix_utf8_hex": TRACE_PREFIX.hex().upper()}},
        "binding_contract": {
            "ordered_option_fingerprints_required": True,
            "stale_or_reordered_binding_fails_closed": True,
            "binding_probe_returns_action": False,
            "old_indexes_are_reusable": False,
        },
        "tie_break_contract": {
            "adapter_hints_are_diagnostic": True,
            "base_final_action_is_authoritative_inside_offline_composition": True,
            "package_can_override_base": False,
            "ordered_hints_are_preserved": True,
        },
        "authority_contract": {
            "parent_owners_are_recomputed": True,
            "serialized_results_are_authority": False,
            "window_or_binding_authority": False,
            "ticket_or_command_authority": False,
            "execution_authority": False,
            "live_owner": False,
        },
        "scope_contract": {
            "source_locked_frame_count": 13,
            "offline_seeded_extensions_in_trajectory": 0,
            "public_only": True,
            "portable_ready": False,
            "package_exportable": False,
            "device_accepted": False,
        },
    }


def _load_parent_outputs(root: Path) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    for parent_id, relative in PARENT_PATHS.items():
        actual = _canonical_hash(load_json_strict(root / relative))
        if actual != PARENT_HASHES[parent_id]:
            raise ValueError(f"parent hash mismatch: {parent_id}")
    capability_vectors = load_json_strict(root / "contracts/ptcgdap/marnie_capability_policy_conformance_vectors.json")
    evaluate_all = [case for case in capability_vectors["cases"] if case["operation"] == "evaluate_all"]
    if len(evaluate_all) != 1:
        raise ValueError("capability evaluate-all vector missing")
    capability_frames = copy.deepcopy(evaluate_all[0]["expected"]["value"]["frames"])
    base_audit = load_json_strict(root / "data/ptcgdap/marnie_vertical_slice/marnie_public_base_v1.json")
    base_cases = [copy.deepcopy(case) for case in base_audit["cases"] if not case["offline_seeded_extension"]]
    if [frame["frame_id"] for frame in capability_frames] != list(FRAME_IDS):
        raise ValueError("capability frame order mismatch")
    if [case["source_frame_id"] for case in base_cases] != list(FRAME_IDS):
        raise ValueError("base case order mismatch")
    return capability_frames, base_cases


def _compose(profile: dict[str, Any], capability_frames: list[dict[str, Any]], base_cases: list[dict[str, Any]]) -> list[dict[str, Any]]:
    results: list[dict[str, Any]] = []
    previous: str | None = None
    for dispatch, capability, base in zip(profile["dispatch"], capability_frames, base_cases, strict=True):
        frame_id = dispatch["frame_id"]
        if capability["frame_id"] != frame_id or base["source_frame_id"] != frame_id:
            raise ValueError("parent frame mismatch")
        route = dispatch["owner_route"]
        if route == "capability_initial_deck":
            if base["status"] != "not_applicable" or base["reason_code"] != "initial_no_window":
                raise ValueError("initial parent applicability mismatch")
            action = copy.deepcopy(capability["selected_card_ids"])
            reason = "official_initial_deck_fixture"
            status = "action"
        elif route == "capability_optional_zero":
            if base["status"] != "not_applicable" or base["reason_code"] != "firewall_not_accepted":
                raise ValueError("optional-zero parent applicability mismatch")
            if capability["selected_indexes"] != []:
                raise ValueError("optional-zero parent action mismatch")
            action = []
            reason = "deterministic_optional_zero"
            status = "action"
        elif route == "terminal_lifecycle":
            if capability["status"] != "not_applicable_terminal" or base["reason_code"] != "terminal_no_callback":
                raise ValueError("terminal parent lifecycle mismatch")
            action = []
            reason = "terminal_no_callback"
            status = "terminal_no_callback"
        elif route == "base_final":
            if frame_id not in BASE_FRAMES or base["status"] != "orchestrated":
                raise ValueError("base parent applicability mismatch")
            if capability["public_observation_hash"] != base["public_observation_hash"] or capability["window_id"] != base["window_id"]:
                raise ValueError("parent public/window mismatch")
            action = copy.deepcopy(base["selected_indexes"])
            reason = "base_final_decision"
            status = "action"
        else:
            raise ValueError("owner route unsupported")

        public_hash = capability["public_observation_hash"]
        window_id = capability["window_id"]
        fingerprints = copy.deepcopy(capability["option_fingerprints"])
        if window_id is None and fingerprints:
            raise ValueError("no-window fingerprint mismatch")
        selected_fingerprints = []
        if dispatch["output_domain"] == "current_window_indexes":
            if any(type(index) is not int or index < 0 or index >= len(fingerprints) for index in action):
                raise ValueError("selected index outside parent window")
            selected_fingerprints = [fingerprints[index] for index in action]

        payload = {
            "ordinal": dispatch["ordinal"],
            "frame_id": frame_id,
            "capability_id": capability["capability_id"],
            "node_id": dispatch["node_id"],
            "owner_route": route,
            "output_domain": dispatch["output_domain"],
            "status": status,
            "reason_code": reason,
            "action": action,
            "public_observation_hash": public_hash,
            "window_id": window_id,
            "option_fingerprints": fingerprints,
            "selected_option_fingerprints": selected_fingerprints,
            "capability_proposal_indexes": copy.deepcopy(capability["selected_indexes"] or []),
            "adapter_hint_indexes": copy.deepcopy(base["adapter_indexes"]),
            "parent_capability_decision_hash": capability["decision_hash"],
            "parent_base_result_hash": base["result_hash"],
            "parent_base_decision_audit_id": base["decision_audit_id"] if route == "base_final" else None,
            "parent_base_trace_hash": base["trace_hash"] if route == "base_final" else None,
            "previous_portable_trace_hash": previous,
            "public_only": True,
            "authoritative": False,
            "execution_authority": False,
        }
        result = {**payload, "portable_trace_hash": _domain_hash(TRACE_PREFIX, payload)}
        results.append(result)
        previous = result["portable_trace_hash"]
    return results


def _audit(frames: list[dict[str, Any]]) -> dict[str, Any]:
    return {
        "schema_version": 1,
        "artifact_kind": "audit",
        "audit_id": AUDIT_ID,
        "profile_id": PROFILE_ID,
        "summary": {
            "frame_count": len(frames),
            "base_owned_count": sum(frame["owner_route"] == "base_final" for frame in frames),
            "capability_owned_count": sum(frame["owner_route"].startswith("capability_") for frame in frames),
            "terminal_lifecycle_count": sum(frame["owner_route"] == "terminal_lifecycle" for frame in frames),
            "current_window_frame_count": sum(frame["window_id"] is not None for frame in frames),
            "initial_deck_card_count": len(frames[0]["action"]),
            "selected_current_window_index_count": sum(
                len(frame["action"]) for frame in frames if frame["output_domain"] == "current_window_indexes"
            ),
            "base_trace_count": sum(frame["parent_base_trace_hash"] is not None for frame in frames),
            "python_gdscript_mismatch_count": 0,
            "skip_count": 0,
        },
        "frames": frames,
        "chain_head": frames[-1]["portable_trace_hash"],
        "public_only": True,
        "authoritative": False,
        "execution_authority": False,
        "production_actions_used": False,
    }


def _snapshot(frames: list[dict[str, Any]]) -> dict[str, Any]:
    return {
        "accepted": True,
        "frame_count": len(frames),
        "chain_head": frames[-1]["portable_trace_hash"],
        "frames": copy.deepcopy(frames),
        "public_only": True,
        "authoritative": False,
        "execution_authority": False,
        "production_actions_used": False,
    }


def _dto(value: Any = None, error_code: str = "") -> dict[str, Any]:
    return {"ok": not error_code, "error_code": error_code, "value": copy.deepcopy(value) if not error_code else None}


def _binding_value(frame: dict[str, Any]) -> dict[str, Any]:
    return {
        "binding_matches": True,
        "frame_id": frame["frame_id"],
        "portable_trace_hash": frame["portable_trace_hash"],
        "authoritative": False,
        "execution_authority": False,
    }


def _tie_value(frame: dict[str, Any]) -> dict[str, Any]:
    return {
        "frame_id": frame["frame_id"],
        "node_id": frame["node_id"],
        "owner_route": frame["owner_route"],
        "option_fingerprints": copy.deepcopy(frame["option_fingerprints"]),
        "capability_proposal_indexes": copy.deepcopy(frame["capability_proposal_indexes"]),
        "adapter_hint_indexes": copy.deepcopy(frame["adapter_hint_indexes"]),
        "base_final_action": copy.deepcopy(frame["action"]),
        "parent_base_trace_hash": frame["parent_base_trace_hash"],
        "portable_trace_hash": frame["portable_trace_hash"],
        "authoritative": False,
        "execution_authority": False,
    }


def _node_value(node: dict[str, Any]) -> dict[str, Any]:
    return {
        **copy.deepcopy(node),
        "authoritative": False,
        "execution_authority": False,
    }


def _vectors(profile: dict[str, Any], audit: dict[str, Any]) -> dict[str, Any]:
    frames = audit["frames"]
    by_id = {frame["frame_id"]: frame for frame in frames}
    cases = [
        {
            "case_id": f"evaluate-{frame['frame_id'].replace('_', '-')}",
            "operation": "evaluate_frame",
            "input": {"frame_id": frame["frame_id"]},
            "expected": _dto(_snapshot([frame])),
        }
        for frame in frames
    ]
    cases.append({"case_id": "evaluate-all", "operation": "evaluate_all", "input": {}, "expected": _dto(_snapshot(frames))})
    binding = by_id["w3_main"]
    exact_input = {
        "frame_id": binding["frame_id"],
        "public_observation_hash": binding["public_observation_hash"],
        "window_id": binding["window_id"],
        "option_fingerprints": copy.deepcopy(binding["option_fingerprints"]),
    }
    reordered = copy.deepcopy(exact_input)
    reordered["option_fingerprints"].reverse()
    stale = copy.deepcopy(exact_input)
    stale["window_id"] = "0" * 64
    cases.extend(
        [
            {"case_id": "binding-exact", "operation": "verify_binding", "input": exact_input, "expected": _dto(_binding_value(binding))},
            {"case_id": "binding-reordered", "operation": "verify_binding", "input": reordered, "expected": _dto(error_code="binding_mismatch")},
            {"case_id": "binding-stale", "operation": "verify_binding", "input": stale, "expected": _dto(error_code="binding_mismatch")},
            {
                "case_id": "tie-break-spikemuth-current-order",
                "operation": "inspect_tie_break",
                "input": {"frame_id": "w4_spikemuth_deck"},
                "expected": _dto(_tie_value(by_id["w4_spikemuth_deck"])),
            },
            {
                "case_id": "tie-break-punk-up-current-order",
                "operation": "inspect_tie_break",
                "input": {"frame_id": "w5_punk_up_sources"},
                "expected": _dto(_tie_value(by_id["w5_punk_up_sources"])),
            },
        ]
    )
    for node in profile["portable_nodes"]:
        cases.append(
            {
                "case_id": f"inspect-{node['node_id'].replace('_', '-')}",
                "operation": "inspect_node",
                "input": {"node_id": node["node_id"]},
                "expected": _dto(_node_value(node)),
            }
        )
    cases.extend(
        [
            {
                "case_id": "unknown-node",
                "operation": "inspect_node",
                "input": {"node_id": "PRIVATE_SENTINEL"},
                "expected": _dto(error_code="unsupported_node"),
            },
            {
                "case_id": "unknown-frame",
                "operation": "evaluate_frame",
                "input": {"frame_id": "unknown"},
                "expected": _dto(error_code="frame_unknown"),
            },
            {
                "case_id": "invalid-frame-type",
                "operation": "evaluate_frame",
                "input": {"frame_id": {"host_type": "integer", "value": 1}},
                "expected": _dto(error_code="input_type_invalid"),
            },
            {
                "case_id": "invalid-operation-type",
                "operation": {"host_type": "string_name", "value": "evaluate_all"},
                "input": {},
                "expected": _dto(error_code="input_type_invalid"),
            },
            {
                "case_id": "unknown-operation",
                "operation": "PRIVATE_SENTINEL",
                "input": {},
                "expected": _dto(error_code="operation_unknown"),
            },
        ]
    )
    if len(cases) != 28:
        raise AssertionError(len(cases))
    return {
        "schema_version": 1,
        "artifact_kind": "vectors",
        "vector_set_id": VECTOR_SET_ID,
        "profile_id": PROFILE_ID,
        "cases": cases,
        "private_sentinels": ["PRIVATE_SENTINEL"],
        "consumer_rule": "Results are offline public differential DTOs; recompute exact parent owners and never use this artifact as live window, binding, ticket or execution authority.",
    }


def _schema(profile: dict[str, Any], vectors: dict[str, Any]) -> dict[str, Any]:
    sha = {"type": ["string", "null"], "pattern": "^[0-9A-F]{64}$"}
    sha_list = {"type": "array", "items": {"type": "string", "pattern": "^[0-9A-F]{64}$"}}
    index_list = {
        "type": "array",
        "items": {"type": "integer", "minimum": 0, "maximum": 9007199254740991},
        "uniqueItems": True,
    }
    action_list = {"type": "array", "items": {"type": "integer", "minimum": 0, "maximum": 9007199254740991}}
    frame = {
        "type": "object",
        "additionalProperties": False,
        "required": [
            "ordinal", "frame_id", "capability_id", "node_id", "owner_route", "output_domain", "status", "reason_code",
            "action", "public_observation_hash", "window_id", "option_fingerprints", "selected_option_fingerprints",
            "capability_proposal_indexes", "adapter_hint_indexes", "parent_capability_decision_hash", "parent_base_result_hash",
            "parent_base_decision_audit_id", "parent_base_trace_hash", "previous_portable_trace_hash", "public_only",
            "authoritative", "execution_authority", "portable_trace_hash",
        ],
        "properties": {
            "ordinal": {"type": "integer", "minimum": 0, "maximum": 12},
            "frame_id": {"enum": list(FRAME_IDS)},
            "capability_id": {"type": "string", "minLength": 1},
            "node_id": {"enum": [node["node_id"] for node in NODE_CATALOG]},
            "owner_route": {"enum": [node["owner_route"] for node in NODE_CATALOG]},
            "output_domain": {"enum": ["initial_deck_card_ids", "current_window_indexes", "terminal_no_callback"]},
            "status": {"enum": ["action", "terminal_no_callback"]},
            "reason_code": {"enum": ["official_initial_deck_fixture", "base_final_decision", "deterministic_optional_zero", "terminal_no_callback"]},
            "action": action_list,
            "public_observation_hash": copy.deepcopy(sha),
            "window_id": copy.deepcopy(sha),
            "option_fingerprints": sha_list,
            "selected_option_fingerprints": copy.deepcopy(sha_list),
            "capability_proposal_indexes": copy.deepcopy(index_list),
            "adapter_hint_indexes": copy.deepcopy(index_list),
            "parent_capability_decision_hash": {"type": "string", "pattern": "^[0-9A-F]{64}$"},
            "parent_base_result_hash": {"type": "string", "pattern": "^[0-9A-F]{64}$"},
            "parent_base_decision_audit_id": copy.deepcopy(sha),
            "parent_base_trace_hash": copy.deepcopy(sha),
            "previous_portable_trace_hash": copy.deepcopy(sha),
            "public_only": {"const": True},
            "authoritative": {"const": False},
            "execution_authority": {"const": False},
            "portable_trace_hash": {"type": "string", "pattern": "^[0-9A-F]{64}$"},
        },
        "allOf": [
            {
                "if": {"properties": {"owner_route": {"const": "base_final"}}},
                "then": {
                    "properties": {
                        "output_domain": {"const": "current_window_indexes"},
                        "parent_base_decision_audit_id": {"type": "string", "pattern": "^[0-9A-F]{64}$"},
                        "parent_base_trace_hash": {"type": "string", "pattern": "^[0-9A-F]{64}$"},
                    }
                },
                "else": {
                    "properties": {
                        "parent_base_decision_audit_id": {"const": None},
                        "parent_base_trace_hash": {"const": None},
                    }
                },
            },
            {
                "if": {"properties": {"output_domain": {"const": "terminal_no_callback"}}},
                "then": {"properties": {"status": {"const": "terminal_no_callback"}, "action": {"const": []}}},
                "else": {"properties": {"status": {"const": "action"}}},
            },
        ],
    }
    summary_properties = {
        "frame_count": {"const": 13},
        "base_owned_count": {"const": 10},
        "capability_owned_count": {"const": 2},
        "terminal_lifecycle_count": {"const": 1},
        "current_window_frame_count": {"const": 11},
        "initial_deck_card_count": {"const": 60},
        "selected_current_window_index_count": {"const": 8},
        "base_trace_count": {"const": 10},
        "python_gdscript_mismatch_count": {"const": 0},
        "skip_count": {"const": 0},
    }
    return {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "https://ptcgdap.local/contracts/marnie_portable_policy.schema.json",
        "title": "P5-WP7 Marnie portable policy differential artifacts",
        "oneOf": [
            {"$ref": "#/$defs/profile"},
            {"$ref": "#/$defs/audit"},
            {"$ref": "#/$defs/vectors"},
            {"$ref": "#/$defs/bundle"},
        ],
        "$defs": {
            "frame": frame,
            "profile": {"const": copy.deepcopy(profile)},
            "audit": {
                "type": "object",
                "additionalProperties": False,
                "required": ["schema_version", "artifact_kind", "audit_id", "profile_id", "summary", "frames", "chain_head", "public_only", "authoritative", "execution_authority", "production_actions_used"],
                "properties": {
                    "schema_version": {"const": 1},
                    "artifact_kind": {"const": "audit"},
                    "audit_id": {"const": AUDIT_ID},
                    "profile_id": {"const": PROFILE_ID},
                    "summary": {
                        "type": "object",
                        "additionalProperties": False,
                        "required": list(summary_properties),
                        "properties": summary_properties,
                    },
                    "frames": {"type": "array", "minItems": 13, "maxItems": 13, "items": {"$ref": "#/$defs/frame"}},
                    "chain_head": {"type": "string", "pattern": "^[0-9A-F]{64}$"},
                    "public_only": {"const": True},
                    "authoritative": {"const": False},
                    "execution_authority": {"const": False},
                    "production_actions_used": {"const": False},
                },
            },
            "vectors": {"const": copy.deepcopy(vectors)},
            "bundle": {
                "type": "object",
                "additionalProperties": False,
                "required": ["schema_version", "contract_id", "status", "parents", "artifacts", "runtime_authority"],
                "properties": {
                    "schema_version": {"const": 1},
                    "contract_id": {"const": CONTRACT_ID},
                    "status": {"const": "offline_shadow"},
                    "parents": {
                        "const": [
                            {"id": parent_id, "path": PARENT_PATHS[parent_id], "canonical_sha256": PARENT_HASHES[parent_id]}
                            for parent_id in ("marnie_capability_policy", "marnie_public_base", "marnie_trajectory_replay")
                        ]
                    },
                    "artifacts": {
                        "type": "array",
                        "minItems": 4,
                        "maxItems": 4,
                        "prefixItems": [
                            {"type": "object", "additionalProperties": False, "required": ["id", "path", "canonical_sha256"], "properties": {"id": {"const": "schema"}, "path": {"const": "contracts/ptcgdap/marnie_portable_policy.schema.json"}, "canonical_sha256": {"type": "string", "pattern": "^[0-9A-F]{64}$"}}},
                            {"type": "object", "additionalProperties": False, "required": ["id", "path", "canonical_sha256"], "properties": {"id": {"const": "profile"}, "path": {"const": "contracts/ptcgdap/marnie_portable_policy_profile.json"}, "canonical_sha256": {"type": "string", "pattern": "^[0-9A-F]{64}$"}}},
                            {"type": "object", "additionalProperties": False, "required": ["id", "path", "canonical_sha256"], "properties": {"id": {"const": "vectors"}, "path": {"const": "contracts/ptcgdap/marnie_portable_policy_conformance_vectors.json"}, "canonical_sha256": {"type": "string", "pattern": "^[0-9A-F]{64}$"}}},
                            {"type": "object", "additionalProperties": False, "required": ["id", "path", "canonical_sha256"], "properties": {"id": {"const": "audit"}, "path": {"const": "data/ptcgdap/marnie_vertical_slice/marnie_portable_policy_v1.json"}, "canonical_sha256": {"type": "string", "pattern": "^[0-9A-F]{64}$"}}},
                        ],
                        "items": False,
                    },
                    "runtime_authority": {"const": "offline_public_differential_only"},
                },
            },
        },
    }


def build_documents(root: Path) -> dict[str, Any]:
    profile = _profile()
    capability_frames, base_cases = _load_parent_outputs(root)
    frames = _compose(profile, capability_frames, base_cases)
    audit = _audit(frames)
    vectors = _vectors(profile, audit)
    schema = _schema(profile, vectors)
    values = {
        "contracts/ptcgdap/marnie_portable_policy.schema.json": schema,
        "contracts/ptcgdap/marnie_portable_policy_profile.json": profile,
        "contracts/ptcgdap/marnie_portable_policy_conformance_vectors.json": vectors,
        "data/ptcgdap/marnie_vertical_slice/marnie_portable_policy_v1.json": audit,
    }
    bundle = {
        "schema_version": 1,
        "contract_id": CONTRACT_ID,
        "status": "offline_shadow",
        "parents": [
            {"id": parent_id, "path": PARENT_PATHS[parent_id], "canonical_sha256": PARENT_HASHES[parent_id]}
            for parent_id in ("marnie_capability_policy", "marnie_public_base", "marnie_trajectory_replay")
        ],
        "artifacts": [
            {"id": artifact_id, "path": path, "canonical_sha256": _canonical_hash(values[path])}
            for artifact_id, path in (
                ("schema", "contracts/ptcgdap/marnie_portable_policy.schema.json"),
                ("profile", "contracts/ptcgdap/marnie_portable_policy_profile.json"),
                ("vectors", "contracts/ptcgdap/marnie_portable_policy_conformance_vectors.json"),
                ("audit", "data/ptcgdap/marnie_vertical_slice/marnie_portable_policy_v1.json"),
            )
        ],
        "runtime_authority": "offline_public_differential_only",
    }
    values["contracts/ptcgdap/marnie_portable_policy_bundle.json"] = bundle
    return values


def write_documents(root: Path, *, check: bool) -> int:
    documents = build_documents(root)
    drift = []
    for relative, value in documents.items():
        path = root / relative
        payload = (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
        if check:
            if not path.is_file() or path.read_bytes() != payload:
                drift.append(relative)
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(payload)
    if drift:
        print("drift=" + ",".join(drift))
        return 1
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    return write_documents(ROOT, check=args.check)


if __name__ == "__main__":
    raise SystemExit(main())
