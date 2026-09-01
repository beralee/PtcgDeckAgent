from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes


CONTRACT_ROOT = ROOT / "contracts/ptcgdap"
PROFILE_ID = "ptcgdap-author-strategy-live-seam-as-wp5-v1"
BUNDLE_ID = PROFILE_ID
PARENT_MATCH_HOST_BUNDLE = "4BD207E9F9200E5AF9E2206A13EAF506382B6BA42BDEE3F0FEB5CA872885DBB9"
ENGINE_DECISION_PORT_BUNDLE = "CC0026D523F2B5435031AC4E5952DB4E2C8B2C39944B333E97B1A2E4F3374C81"
OPTION_BINDING_BUNDLE = "4FFFEC48E4E1FE0774BB6E343D4D4B0384A9210057DEE06415C2A20F2899B1C1"
TICKET_BUNDLE = "41F3E84C6DC5C9BC6C162B848B097211E617B5558ECB59554757E82CE58817ED"
EXECUTOR_BUNDLE = "45952BE629AE98EB6070C77188FD6A2C2A644C4B6A36876193BB745B7CDA4E92"
BROKER_BUNDLE = "D19EC7B9B77370312C82E0572DFB016B75E3FE9F438B6C1EFFD50E0AB43C551E"
PROJECTOR_BUNDLE = "C51EA4CF1AEFCBB5B9C6D83825FF3A717CCDCC4105B804210BF6169372619041"
SOURCE_LOCK = "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"


def digest(value: object) -> str:
    return hashlib.sha256(canonical_json_v1_bytes(value)).hexdigest().upper()


def schema() -> dict[str, object]:
    sha = {"type": "string", "pattern": "^[0-9A-F]{64}$"}
    return {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "https://ptcgdap.local/contracts/author_strategy_live_seam.schema.json",
        "title": "PTCGDAP AS-WP5 W1 setup-active development canary witness",
        "type": "object",
        "additionalProperties": False,
        "required": [
            "schema_version", "profile_id", "accepted", "error_code", "prompt_family",
            "callback_role", "match_generation", "decision_generation", "snapshot_id",
            "window_id", "public_observation_hash", "selected_indexes", "selection_source",
            "broker_state", "engine_applied", "reobserved", "old_authority_invalidated",
            "development_canary", "player_package_authority", "classic_fallback_used",
            "witness_hash",
        ],
        "properties": {
            "schema_version": {"const": 1},
            "profile_id": {"const": PROFILE_ID},
            "accepted": {"type": "boolean"},
            "error_code": {"type": "string", "maxLength": 96},
            "prompt_family": {"const": "W1"},
            "callback_role": {"const": "setup_active"},
            "match_generation": {"type": "integer", "minimum": 1},
            "decision_generation": {"type": "integer", "minimum": 1},
            "snapshot_id": sha,
            "window_id": sha,
            "public_observation_hash": sha,
            "selected_indexes": {
                "type": "array", "minItems": 0, "maxItems": 1,
                "uniqueItems": True, "items": {"type": "integer", "minimum": 0},
            },
            "selection_source": {"enum": ["policy", "deterministic_fallback", "none"]},
            "broker_state": {"enum": ["awaiting_reobserve", "aborted", "none"]},
            "engine_applied": {"type": "boolean"},
            "reobserved": {"type": "boolean"},
            "old_authority_invalidated": {"type": "boolean"},
            "development_canary": {"const": True},
            "player_package_authority": {"const": False},
            "classic_fallback_used": {"const": False},
            "witness_hash": sha,
        },
    }


def profile() -> dict[str, object]:
    return {
        "schema_version": 1,
        "profile_id": PROFILE_ID,
        "enabled_prompt_families": ["W1"],
        "enabled_callback_roles": ["setup_active"],
        "parent_contracts": {
            "author_match_host_bundle_canonical_sha256": PARENT_MATCH_HOST_BUNDLE,
            "engine_decision_port_bundle_canonical_sha256": ENGINE_DECISION_PORT_BUNDLE,
            "godot_option_binding_bundle_canonical_sha256": OPTION_BINDING_BUNDLE,
            "godot_action_ticket_bundle_canonical_sha256": TICKET_BUNDLE,
            "godot_action_executor_bundle_canonical_sha256": EXECUTOR_BUNDLE,
            "shadow_prompt_broker_bundle_canonical_sha256": BROKER_BUNDLE,
            "godot_observation_projector_bundle_canonical_sha256": PROJECTOR_BUNDLE,
            "source_lock_canonical_sha256": SOURCE_LOCK,
        },
        "lifecycle": {
            "exact_engine_prompt_required": True,
            "projector_firewall_required": True,
            "fresh_immutable_window_required": True,
            "same_window_sanitize_required": True,
            "one_use_ticket_required": True,
            "preflight_commit_required": True,
            "immediate_reobserve_required": True,
            "old_window_ticket_reuse_allowed": False,
        },
        "trust_scope": {
            "development_canary": True,
            "test_fixture_may_drive_canary": True,
            "player_package_execution": False,
            "catalog_ready_record": False,
            "exportable": False,
            "device_acceptance_claim": False,
        },
        "fallback": {
            "same_window_deterministic_only": True,
            "classic_ai_allowed": False,
            "fallback_after_engine_mutation": False,
        },
        "stable_error_codes": [
            "", "live_seam_contract_error", "unsupported_prompt_family", "invalid_live_owner",
            "invalid_engine_prompt", "projector_rejected", "window_rejected", "host_rejected",
            "binding_rejected", "broker_rejected", "preflight_rejected", "commit_rejected",
            "prompt_changed", "engine_apply_rejected", "reobserve_rejected", "replay_rejected",
            "resource_limit_exceeded",
        ],
        "resource_limits": {
            "max_options": 32,
            "max_source_documents": 128,
            "max_public_events": 512,
        },
        "device_budget_handoff": {
            "gate_owner": "AS-WP6",
            "enforced_in_as_wp5": False,
            "candidate_max_decision_msec": 250,
        },
    }


def vectors() -> dict[str, object]:
    return {
        "schema_version": 1,
        "profile_id": PROFILE_ID,
        "cases": [
            {"id": "w1-policy-success", "fault": "none", "expected": "accepted"},
            {"id": "w1-policy-exception-fallback", "fault": "policy_exception", "expected": "accepted_fallback"},
            {"id": "w1-illegal-output-fallback", "fault": "illegal_output", "expected": "accepted_fallback"},
            {"id": "w1-prompt-reordered", "fault": "candidate_reorder", "expected": "prompt_changed"},
            {"id": "w1-prompt-card-removed", "fault": "candidate_removed", "expected": "prompt_changed"},
            {"id": "w1-replay", "fault": "replay", "expected": "replay_rejected"},
            {"id": "w1-engine-precondition", "fault": "active_already_present", "expected": "engine_apply_rejected"},
            {"id": "w2-not-enabled", "fault": "unsupported_family", "expected": "unsupported_prompt_family"},
        ],
    }


def build_artifacts() -> dict[str, dict[str, object]]:
    documents = {
        "author_strategy_live_seam.schema.json": schema(),
        "author_strategy_live_seam_profile.json": profile(),
        "author_strategy_live_seam_conformance_vectors.json": vectors(),
    }
    bundle = {
        "schema_version": 1,
        "bundle_id": BUNDLE_ID,
        "profile_id": PROFILE_ID,
        "parent_author_match_host_bundle_canonical_sha256": PARENT_MATCH_HOST_BUNDLE,
        "artifacts": [
            {
                "id": name.removesuffix(".json"),
                "path": f"contracts/ptcgdap/{name}",
                "canonical_sha256": digest(document),
            }
            for name, document in documents.items()
        ],
    }
    return {**documents, "author_strategy_live_seam_bundle.json": bundle}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    artifacts = build_artifacts()
    if args.write:
        for name, document in artifacts.items():
            (CONTRACT_ROOT / name).write_text(
                json.dumps(document, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
            )
    if args.check:
        for name, document in artifacts.items():
            actual = json.loads((CONTRACT_ROOT / name).read_text(encoding="utf-8"))
            if actual != document:
                raise SystemExit(f"contract drift: {name}")
    bundle = artifacts["author_strategy_live_seam_bundle.json"]
    print(f"bundle_canonical_sha256={digest(bundle)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
