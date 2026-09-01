from __future__ import annotations

import hashlib
from pathlib import Path
from typing import Any, Mapping, Sequence

from .a3_qualification import (
    CONSTRUCTION_AUTHORITIES,
    OFFICIAL_CONSTRUCTION_AUTHORITIES,
    REQUIRED_MULTI_WINDOW_CHAINS,
    REQUIRED_SCENARIO_KINDS,
)
from .cabt_tree_hash import jcs_canonical_json_bytes
from .source_lock import load_json_strict


class A3ScenarioCoverageError(RuntimeError):
    pass


def _hash(value: Any) -> str:
    return hashlib.sha256(jcs_canonical_json_bytes(value)).hexdigest().upper()


def _self_hash_valid(value: Any, field: str = "evidence_sha256") -> bool:
    if type(value) is not dict or type(value.get(field)) is not str:
        return False
    projected = dict(value)
    expected = projected.pop(field)
    return len(expected) == 64 and expected == _hash(projected)


def _seal(value: Mapping[str, Any], field: str = "evidence_sha256") -> dict[str, Any]:
    result = dict(value)
    result[field] = _hash(result)
    return result


def load_capability_profile(path: str | Path) -> dict[str, Any]:
    profile = load_json_strict(path)
    if (
        type(profile) is not dict
        or profile.get("document_type") != "ptcgdap_a3_five_deck_capability_profile_v2"
        or set(profile.get("required_scenario_kinds", [])) != REQUIRED_SCENARIO_KINDS
        or set(profile.get("required_multi_window_chains", [])) != REQUIRED_MULTI_WINDOW_CHAINS
        or type(profile.get("capabilities")) is not list
        or not profile["capabilities"]
    ):
        raise A3ScenarioCoverageError("a3_capability_profile_invalid")
    ids: set[str] = set()
    for capability in profile["capabilities"]:
        if (
            type(capability) is not dict
            or type(capability.get("capability_id")) is not str
            or not capability["capability_id"]
            or capability["capability_id"] in ids
            or type(capability.get("decks")) is not list
            or not capability["decks"]
            or any(type(deck_id) is not int for deck_id in capability["decks"])
            or type(capability.get("domain")) is not str
            or capability.get("random_capability") not in ("R0", "R1", "R2A", "R2B", "R3", "RX", "R1_or_R2A")
        ):
            raise A3ScenarioCoverageError("a3_capability_profile_invalid")
        ids.add(capability["capability_id"])
    return profile


def _valid_scenario_receipt(receipt: Any, scope_hash: str, capability_ids: set[str]) -> bool:
    return (
        type(receipt) is dict
        and receipt.get("document_type") == "ptcgdap_a3_micro_scenario_receipt_v2"
        and receipt.get("scope_sha256") == scope_hash
        and receipt.get("capability_id") in capability_ids
        and receipt.get("scenario_kind") in REQUIRED_SCENARIO_KINDS
        and receipt.get("status") == "aligned"
        and receipt.get("construction_authority") in CONSTRUCTION_AUTHORITIES
        and type(receipt.get("scenario_id")) is str
        and bool(receipt.get("scenario_id"))
        and receipt.get("public_projection_status") == "reviewed"
        and receipt.get("private_evidence_status") == "isolated"
        and _self_hash_valid(receipt)
    )


def _valid_chain_receipt(receipt: Any, scope_hash: str) -> bool:
    return (
        type(receipt) is dict
        and receipt.get("document_type") == "ptcgdap_a3_multi_window_chain_receipt_v2"
        and receipt.get("scope_sha256") == scope_hash
        and receipt.get("chain_id") in REQUIRED_MULTI_WINDOW_CHAINS
        and receipt.get("status") == "aligned"
        and receipt.get("construction_authority") in CONSTRUCTION_AUTHORITIES
        and type(receipt.get("window_count")) is int
        and receipt.get("window_count") >= 2
        and receipt.get("reobserve_count") == receipt.get("window_count") - 1
        and receipt.get("stale_index_reuse_count") == 0
        and receipt.get("public_projection_status") == "reviewed"
        and receipt.get("private_evidence_status") == "isolated"
        and _self_hash_valid(receipt)
    )


def build_scenario_coverage(
    scope: Mapping[str, Any],
    profile: Mapping[str, Any],
    *,
    scenario_receipts: Sequence[Mapping[str, Any]] = (),
    chain_receipts: Sequence[Mapping[str, Any]] = (),
) -> dict[str, Any]:
    scope_hash = scope.get("scope_sha256")
    if type(scope_hash) is not str or len(scope_hash) != 64:
        raise A3ScenarioCoverageError("a3_scope_invalid")
    capabilities = profile.get("capabilities")
    if type(capabilities) is not list:
        raise A3ScenarioCoverageError("a3_capability_profile_invalid")
    capability_ids = {item["capability_id"] for item in capabilities}
    if any(not _valid_scenario_receipt(receipt, scope_hash, capability_ids) for receipt in scenario_receipts):
        raise A3ScenarioCoverageError("a3_scenario_receipt_invalid")
    if any(not _valid_chain_receipt(receipt, scope_hash) for receipt in chain_receipts):
        raise A3ScenarioCoverageError("a3_chain_receipt_invalid")

    scenario_by_capability: dict[str, list[Mapping[str, Any]]] = {
        capability_id: [] for capability_id in capability_ids
    }
    for receipt in scenario_receipts:
        scenario_by_capability[receipt["capability_id"]].append(receipt)
    capability_rows: list[dict[str, Any]] = []
    for capability in capabilities:
        receipts = scenario_by_capability[capability["capability_id"]]
        kinds = {receipt["scenario_kind"] for receipt in receipts}
        authorities = {receipt["construction_authority"] for receipt in receipts}
        aligned = (
            REQUIRED_SCENARIO_KINDS.issubset(kinds)
            and bool(OFFICIAL_CONSTRUCTION_AUTHORITIES.intersection(authorities))
            and all(
                receipt["construction_authority"] in OFFICIAL_CONSTRUCTION_AUTHORITIES
                for receipt in receipts
                if receipt["scenario_kind"] in REQUIRED_SCENARIO_KINDS
            )
        )
        capability_rows.append(_seal({
            "capability_id": capability["capability_id"],
            "decks": list(capability["decks"]),
            "domain": capability["domain"],
            "random_capability": capability["random_capability"],
            "status": "aligned" if aligned else "blocked",
            "scenario_kinds": sorted(kinds),
            "construction_authorities": sorted(authorities),
            "receipt_sha256s": sorted(receipt["evidence_sha256"] for receipt in receipts),
            "missing_scenario_kinds": sorted(REQUIRED_SCENARIO_KINDS - kinds),
            "blocker": None if aligned else "oracle_construction_evidence_incomplete",
        }))

    chain_by_id = {receipt["chain_id"]: receipt for receipt in chain_receipts}
    chain_rows: list[dict[str, Any]] = []
    for chain_id in sorted(REQUIRED_MULTI_WINDOW_CHAINS):
        receipt = chain_by_id.get(chain_id)
        aligned = (
            receipt is not None
            and receipt["construction_authority"] in OFFICIAL_CONSTRUCTION_AUTHORITIES
        )
        chain_rows.append(_seal({
            "chain_id": chain_id,
            "status": "aligned" if aligned else "blocked",
            "construction_authority": None if receipt is None else receipt["construction_authority"],
            "receipt_sha256": None if receipt is None else receipt["evidence_sha256"],
            "blocker": None if aligned else "oracle_multi_window_evidence_incomplete",
        }))

    report = {
        "document_type": "ptcgdap_a3_scenario_coverage_v2",
        "schema_version": 2,
        "scope_sha256": scope_hash,
        "profile_sha256": _hash(profile),
        "capabilities": capability_rows,
        "multi_window_chains": chain_rows,
        "aligned_capability_count": sum(row["status"] == "aligned" for row in capability_rows),
        "required_capability_count": len(capability_rows),
        "authority": "scenario_coverage_owner",
        "maximum_claim": "research_private_id_corresponding_card_a3_scenario_coverage" if all(
            row["status"] == "aligned" for row in capability_rows + chain_rows
        ) else "coverage_gap_inventory",
    }
    return _seal(report)


__all__ = [
    "A3ScenarioCoverageError", "build_scenario_coverage", "load_capability_profile",
]
