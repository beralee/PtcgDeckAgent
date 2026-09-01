from __future__ import annotations

import hashlib
import json
from pathlib import Path
import sys
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_bytes_strict


OUTPUT = ROOT / "evidence/ptcgdap/ucis/ucis_catalog_qualification_v1.json"
CONTRACTS = ROOT / "contracts/ptcgdap"
PERFORMANCE = ROOT / "evidence/ptcgdap/ucis/ucis_performance_qualification_v1.json"
WHOLE_BATTLE = ROOT / "evidence/ptcgdap/a3/corresponding_card_whole_battle_input_index_v1.json"


def _load(path: Path) -> dict[str, Any]:
    value = load_json_bytes_strict(path.read_bytes())
    if type(value) is not dict:
        raise ValueError(f"ucis_qualification_document_invalid:{path.name}")
    return value


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def _payload_hash(document: dict[str, Any], field: str) -> str:
    payload = dict(document)
    expected = payload.pop(field, None)
    actual = hashlib.sha256(canonical_json_v1_bytes(payload)).hexdigest().upper()
    if expected != actual:
        raise ValueError(f"ucis_qualification_evidence_hash_invalid:{field}")
    return actual


def _require_contract_bundle(bundle: dict[str, Any]) -> None:
    if bundle.get("document_type") != "ptcgdap_ucis_bundle_v1":
        raise ValueError("ucis_qualification_bundle_invalid")
    for row in bundle.get("files", []):
        path = ROOT / row["path"]
        document = _load(path)
        actual = hashlib.sha256(canonical_json_v1_bytes(document)).hexdigest().upper()
        if row.get("canonical_sha256") != actual:
            raise ValueError(f"ucis_qualification_bundle_drift:{row['path']}")


def build_qualification() -> dict[str, Any]:
    bundle = _load(CONTRACTS / "ucis_bundle_v1.json")
    registry = _load(CONTRACTS / "ucis_registry_v1.json")
    catalog = _load(CONTRACTS / "ucis_card_catalog_v1.json")
    attestation = _load(CONTRACTS / "ucis_runtime_attestation_v1.json")
    legacy = _load(CONTRACTS / "ucis_legacy_inventory_v1.json")
    coverage = _load(CONTRACTS / "ucis_coverage_ledger_v1.json")
    performance = _load(PERFORMANCE)
    whole_battle = _load(WHOLE_BATTLE)
    _require_contract_bundle(bundle)
    performance_hash = _payload_hash(performance, "evidence_sha256")
    whole_battle_hash = _payload_hash(whole_battle, "evidence_sha256")

    closure = catalog.get("closure", {})
    attested = attestation.get("closure", {})
    legacy_closure = legacy.get("closure", {})
    metrics = coverage.get("metrics", {})
    reasons: list[str] = []
    if any(closure.get(key) != value for key, value in attested.items()):
        reasons.append("catalog_runtime_attestation_drift")
    if any(closure.get(key) != 0 for key in (
        "unregistered", "legacy_author_visible", "custom_prompt_builder", "silent_fallback"
    )):
        reasons.append("catalog_closure_not_closed")
    if closure.get("compiled", 0) + closure.get("automatic", 0) + closure.get(
        "unsupported", 0
    ) != closure.get("total_effects", -1):
        reasons.append("catalog_partition_incomplete")
    if any(
        metric.get("numerator") != metric.get("denominator")
        for metric in metrics.values()
    ):
        reasons.append("coverage_denominator_open")
    if legacy_closure.get("ucis_owned_callsite_count") != legacy_closure.get(
        "interaction_callsite_count"
    ) or any(
        legacy_closure.get(key) != 0
        for key in (
            "legacy_author_visible",
            "legacy_write_entrypoints",
            "dual_authority",
            "custom_prompt_builder",
        )
    ):
        reasons.append("legacy_authority_not_eliminated")
    if performance.get("qualification", {}).get("status") != "passed":
        reasons.append("runtime_performance_not_qualified")
    required_families = set(whole_battle.get("required_operation_families", []))
    actual_families = {row.get("family") for row in whole_battle.get("families", [])}
    if (
        whole_battle.get("qualification_status") != "passed"
        or whole_battle.get("claim_scope")
        != "corresponding_card_whole_battle_input_index_contract"
        or actual_families != required_families
        or any(row.get("status") != "input-index-aligned" for row in whole_battle.get("families", []))
    ):
        reasons.append("representative_live_operation_scope_not_qualified")

    status = "passed" if not reasons else "failed"
    return {
        "document_type": "ptcgdap_ucis_catalog_qualification_v1",
        "schema_version": 1,
        "qualification_status": status,
        "failure_reasons": reasons,
        "maximum_claim": "ptcgdap_card_interactions_use_ucis_for_declared_usable_catalog_v1",
        "contract_generation": registry["contract_generation"],
        "ucis_generation": registry["ucis_generation"],
        "scope": {
            "identity_domain": catalog["identity_domain"],
            "total_cards": closure["total_cards"],
            "total_effects": closure["total_effects"],
            "compiled": closure["compiled"],
            "automatic": closure["automatic"],
            "explicit_unsupported": closure["unsupported"],
            "declared_usable": closure["compiled"] + closure["automatic"],
            "unregistered": closure["unregistered"],
            "silent_fallback": closure["silent_fallback"],
            "legacy_author_visible": closure["legacy_author_visible"],
            "custom_prompt_builder": closure["custom_prompt_builder"],
            "legacy_callsites_ucis_owned": legacy_closure["ucis_owned_callsite_count"],
            "legacy_callsites_total": legacy_closure["interaction_callsite_count"],
        },
        "coverage": metrics,
        "representative_live_operation_scope": {
            "claim": whole_battle["claim_scope"],
            "qualification_status": whole_battle["qualification_status"],
            "operation_families": sorted(actual_families),
            "evidence_sha256": whole_battle_hash,
        },
        "performance_scope": {
            "qualification_status": performance["qualification"]["status"],
            "build_cost": performance["build_cost"],
            "per_window_runtime_cost": performance["per_window_runtime_cost"],
            "runtime_operation_audit": performance["runtime_operation_audit"],
            "evidence_sha256": performance_hash,
        },
        "contract_identities": {
            "bundle_raw_sha256": _sha(CONTRACTS / "ucis_bundle_v1.json"),
            "registry_canonical_sha256": hashlib.sha256(
                canonical_json_v1_bytes(registry)
            ).hexdigest().upper(),
            "catalog_raw_sha256": _sha(CONTRACTS / "ucis_card_catalog_v1.json"),
            "runtime_attestation_raw_sha256": _sha(
                CONTRACTS / "ucis_runtime_attestation_v1.json"
            ),
            "coverage_raw_sha256": _sha(CONTRACTS / "ucis_coverage_ledger_v1.json"),
            "legacy_inventory_raw_sha256": _sha(
                CONTRACTS / "ucis_legacy_inventory_v1.json"
            ),
        },
        "required_green_suites": [
            "tests/ptcgdap/test_ucis_contract.py",
            "tests/ptcgdap/test_ucis_properties.py",
            "tests/ptcgdap/test_ucis_sdk.py",
            "tests/ptcgdap/test_ucis_performance.py",
            "tests/ptcgdap/test_a3_live_operation_witness.py",
            "tests/test_ucis_interaction_compiler.gd",
            "tests/test_author_strategy_interaction_contract_v2.gd",
            "tests/test_battle_ui_features_part3.gd",
            "tests/test_headless_match_bridge.gd",
        ],
        "rollback_identity": {
            "contract_generation": registry["contract_generation"],
            "ucis_generation": registry["ucis_generation"],
            "registry_document_hash": hashlib.sha256(
                canonical_json_v1_bytes(registry)
            ).hexdigest().upper(),
            "catalog_source_manifest": catalog["source_manifest"],
        },
        "source_identities": {
            "qualification_generator": _sha(
                ROOT / "tools/ptcgdap/build_ucis_catalog_qualification.py"
            ),
            "contract_generator": _sha(
                ROOT / "scripts/ai/ptcgdap/ucis_contract.py"
            ),
            "catalog_compiler": _sha(ROOT / "scripts/ai/ptcgdap/ucis_catalog.py"),
            "python_compiler": _sha(ROOT / "scripts/ai/ptcgdap/ucis.py"),
            "godot_compiler": _sha(
                ROOT / "scripts/engine/ucis/UcisInteractionCompiler.gd"
            ),
        },
        "nonclaims": [
            "not_kaggle_or_pokemon_company_endorsement",
            "not_official_card_id_equality",
            "not_full_card_pool_official_rule_parity",
            "not_post_selection_state_damage_ko_rng_or_terminal_a3",
            "not_production_third_party_python_sandbox_qualification",
            "not_android_or_device_acceptance",
            "explicit_unsupported_effects_are_excluded_from_declared_usable_scope",
        ],
    }


def main() -> int:
    report = build_qualification()
    payload = dict(report)
    report["evidence_sha256"] = hashlib.sha256(
        canonical_json_v1_bytes(payload)
    ).hexdigest().upper()
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_bytes(canonical_json_v1_bytes(report))
    print(json.dumps(report, ensure_ascii=False, sort_keys=True, separators=(",", ":")))
    return 0 if report["qualification_status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
