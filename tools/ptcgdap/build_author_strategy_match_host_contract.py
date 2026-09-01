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

from scripts.ai.ptcgdap.author_strategy_match_host import (
    PROFILE_ID,
    AuthorStrategyMatchHandleBuilder,
    AuthorStrategyShadowPrompt,
    PtcgDAPAuthorMatchHost,
)
from scripts.ai.ptcgdap.author_strategy_package import AuthorStrategyPackageLoader
from scripts.ai.ptcgdap.cabt_envelope import parse_raw_cabt_envelope
from scripts.ai.ptcgdap.cabt_selection import CabtSelectionWindow
from scripts.ai.ptcgdap.public_observation_firewall import PublicObservationFirewall
from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict
from scripts.ai.ptcgdap.strategic_context_v18 import StrategicContextCompiler


CONTRACT_ROOT = ROOT / "contracts/ptcgdap"
FIXTURE_PATH = ROOT / "tests/ptcgdap/fixtures/author_strategy_packages/as_wp4/00-exact-mapped-shadow.ptcgai"
BUNDLE_ID = PROFILE_ID
ARTIFACT_NAMES = (
    "author_strategy_match_host.schema.json",
    "author_strategy_match_host_profile.json",
    "author_strategy_match_host_conformance_vectors.json",
)
PARENT_AUTHOR_PACKAGE_BUNDLE = "B416F2CBA2795B62126B6EF7B5F07A9000E84D5FA1DF62C1753CADC9E82E106B"
CABT_CONTRACT = "2CD02F54538985426EFDB057F3A6BDA4AD154DD171BCC03667D42D102982D294"
CARD_CATALOG_BUNDLE = "AB8CF10465F492A98DA8247A84572AECEE281D0726F7BB7B8E5DBC03A6AC70D4"
RESTRICTED_BASE_EXECUTOR_BUNDLE = "69D05747A9F91C19765D448B676C86E1D9DFA1BBAB108ED1374B854B34E48389"
PORTABLE_BACKEND_BUNDLE = "18AAB663D9B429AC8657A75692F5DD8CF37C409CC057A328B57758C692FDB7F4"
SOURCE_LOCK = "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"
MAX_SAFE_INTEGER = 9_007_199_254_740_991


def _digest(value: object) -> str:
    return hashlib.sha256(canonical_json_v1_bytes(value)).hexdigest().upper()


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def _object(properties: dict[str, object], required: list[str]) -> dict[str, object]:
    return {
        "type": "object",
        "additionalProperties": False,
        "required": required,
        "properties": properties,
    }


def schema() -> dict[str, object]:
    hash_schema = {"type": "string", "pattern": "^[0-9A-F]{64}$"}
    identifier = {
        "type": "string",
        "minLength": 1,
        "maxLength": 128,
        "pattern": "^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$",
    }
    index = {"type": "integer", "minimum": 0, "maximum": MAX_SAFE_INTEGER}
    index_list = {"type": "array", "uniqueItems": True, "items": index}
    tier = _object(
        {
            "index": index,
            "tier": {
                "type": "array",
                "minItems": 1,
                "maxItems": 8,
                "items": {"type": "integer", "minimum": 0, "maximum": MAX_SAFE_INTEGER},
            },
        },
        ["index", "tier"],
    )
    audit = _object(
        {
            "schema_version": {"const": 1},
            "profile_id": {"const": PROFILE_ID},
            "match_id": identifier,
            "prompt_id": identifier,
            "prompt_generation": {"type": "integer", "minimum": 1, "maximum": MAX_SAFE_INTEGER},
            "package": _object(
                {"package_id": identifier, "package_version": identifier, "archive_sha256": hash_schema},
                ["package_id", "package_version", "archive_sha256"],
            ),
            "pins": {
                "type": "object",
                "additionalProperties": False,
                "required": [
                    "manifest_sha256", "files_manifest_sha256", "cabt_contract_sha256",
                    "card_catalog_sha256", "base_executor_sha256", "policy_ir_sha256",
                    "adapter_sha256", "config_sha256", "weights_sha256", "backend_sha256",
                    "deck_manifest_sha256", "deck_csv_sha256", "local_deck_mapping_sha256",
                ],
                "properties": {
                    **{
                        key: hash_schema
                        for key in (
                            "manifest_sha256", "files_manifest_sha256", "cabt_contract_sha256",
                            "card_catalog_sha256", "base_executor_sha256", "policy_ir_sha256",
                            "adapter_sha256", "config_sha256", "backend_sha256",
                            "deck_manifest_sha256", "deck_csv_sha256", "local_deck_mapping_sha256",
                        )
                    },
                    "weights_sha256": {"oneOf": [hash_schema, {"type": "null"}]},
                },
            },
            "source": _object(
                {
                    "public_observation_hash": hash_schema,
                    "window_id": hash_schema,
                    "context_hash": hash_schema,
                    "orchestration_hash": hash_schema,
                    "decision_audit_id": hash_schema,
                    "trace_hash": hash_schema,
                },
                ["public_observation_hash", "window_id", "context_hash", "orchestration_hash", "decision_audit_id", "trace_hash"],
            ),
            "selected_indexes": index_list,
            "status": {"const": "shadow_selected"},
            "diagnostic_code": {"const": ""},
            "public_only": {"const": True},
            "development_shadow": {"const": True},
            "execution_trusted": {"const": False},
            "authoritative": {"const": False},
            "classic_fallback_used": {"const": False},
            "audit_hash": hash_schema,
        },
        [
            "schema_version", "profile_id", "match_id", "prompt_id", "prompt_generation",
            "package", "pins", "source", "selected_indexes", "status", "diagnostic_code",
            "public_only", "development_shadow", "execution_trusted", "authoritative",
            "classic_fallback_used", "audit_hash",
        ],
    )
    case = _object(
        {
            "id": identifier,
            "match_id": identifier,
            "prompt_id": identifier,
            "prompt_generation": {"type": "integer", "minimum": 1, "maximum": MAX_SAFE_INTEGER},
            "mandatory_indexes": index_list,
            "terminal_indexes": index_list,
            "base_hard_tiers": {"type": "array", "items": tier},
            "base_vetoed_indexes": index_list,
            "expected_selected_indexes": index_list,
            "expected_audit": audit,
        },
        [
            "id", "match_id", "prompt_id", "prompt_generation", "mandatory_indexes",
            "terminal_indexes", "base_hard_tiers", "base_vetoed_indexes",
            "expected_selected_indexes", "expected_audit",
        ],
    )
    return {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "https://ptcgdap.local/contracts/author_strategy_match_host.schema.json",
        "title": "PTCGDAP AS-WP4 author strategy match handle and public shadow audit",
        "$defs": {"shadowCase": case, "shadowAudit": audit},
        "oneOf": [{"$ref": "#/$defs/shadowCase"}, {"$ref": "#/$defs/shadowAudit"}],
    }


def profile() -> dict[str, object]:
    return {
        "schema_version": 1,
        "profile_id": PROFILE_ID,
        "parent_author_package_bundle_canonical_sha256": PARENT_AUTHOR_PACKAGE_BUNDLE,
        "cabt_contract_canonical_sha256": CABT_CONTRACT,
        "card_catalog_bundle_canonical_sha256": CARD_CATALOG_BUNDLE,
        "restricted_base_executor_bundle_canonical_sha256": RESTRICTED_BASE_EXECUTOR_BUNDLE,
        "portable_backend_bundle_canonical_sha256": PORTABLE_BACKEND_BUNDLE,
        "source_lock_canonical_sha256": SOURCE_LOCK,
        "match_handle_contract": {
            "archive_recaptured_at_match_prepare": True,
            "archive_and_all_payloads_revalidated": True,
            "one_match_claim": True,
            "pins_are_immutable_copy_isolated_values": True,
            "exact_official_id_to_local_printing_only": True,
            "localized_or_display_name_inference": False,
        },
        "shadow_host_contract": {
            "input_owner": "existing_exact_strategic_context_and_current_selection_window",
            "output": "current_window_indexes_and_public_audit_only",
            "prompt_one_use": True,
            "classic_fallback_allowed": False,
            "engine_execution_authority": False,
            "live_authority": False,
            "battle_scene_consumer": False,
        },
        "development_fixture_trust": {
            "test_signature_only": True,
            "execution_trusted": False,
            "development_shadow_ready": True,
            "exportable": False,
        },
        "stable_error_codes": [
            "package_file_missing", "package_integrity_invalid", "package_contract_incompatible",
            "package_deck_unmapped", "package_policy_unsupported", "package_handle_already_claimed",
            "invalid_match_identity", "invalid_current_window_owner", "invalid_prompt_authority",
            "prompt_already_open", "prompt_already_consumed", "prompt_not_open",
            "shadow_policy_failed", "shadow_audit_integrity_invalid",
        ],
    }


def _apply_mutation(root: object, mutation: dict[str, Any]) -> None:
    parent = root
    path = mutation["path"]
    for segment in path[:-1]:
        parent = parent[segment]  # type: ignore[index]
    key = path[-1]
    if mutation["op"] == "set":
        parent[key] = copy.deepcopy(mutation["value"])  # type: ignore[index]
    elif mutation["op"] == "delete":
        del parent[key]  # type: ignore[index]
    elif mutation["op"] == "append":
        parent[key].append(copy.deepcopy(mutation["value"]))  # type: ignore[index]
    else:
        raise ValueError("unsupported mutation")


def _public_owners() -> tuple[object, object]:
    firewall_vectors = load_json_strict(CONTRACT_ROOT / "cabt_public_firewall_conformance_vectors.json")
    case = next(value for value in firewall_vectors["cases"] if value["id"] == "regular-accepted")
    raw = copy.deepcopy(firewall_vectors["base_observations"][case["base"]])
    for mutation in case["mutations"]:
        _apply_mutation(raw, mutation)
    parsed = parse_raw_cabt_envelope(raw, contract_root=CONTRACT_ROOT)
    firewall = PublicObservationFirewall.load_default().project(parsed)
    public = firewall.public_observation
    if public is None or public["current"] is None or public["select"] is None:
        raise RuntimeError("regular public fixture was not accepted")
    strategic_vectors = load_json_strict(CONTRACT_ROOT / "strategic_context_v18_conformance_vectors.json")
    built_window = CabtSelectionWindow.build(
        copy.deepcopy(public["select"]),
        public_observation_hash=firewall.public_observation_hash,
        public_hash_authority=strategic_vectors["fixture"]["public_hash_authority"],
        chooser_player_index=public["current"]["yourIndex"],
    )
    if built_window.window is None:
        raise RuntimeError("current selection window did not build")
    built_context = StrategicContextCompiler.build(firewall, built_window.window)
    if built_context.context is None:
        raise RuntimeError("strategic context did not build")
    return built_context.context, built_window.window


def _case_specs() -> list[dict[str, object]]:
    return [
        {
            "id": "adapter-prefers-type-two-within-same-tier",
            "match_id": "as-wp4-adapter",
            "prompt_id": "main-action",
            "prompt_generation": 1,
            "mandatory_indexes": [],
            "terminal_indexes": [],
            "base_hard_tiers": [{"index": 0, "tier": [0]}, {"index": 1, "tier": [0]}],
            "base_vetoed_indexes": [],
        },
        {
            "id": "base-hard-tier-precedes-adapter",
            "match_id": "as-wp4-hard-tier",
            "prompt_id": "main-action",
            "prompt_generation": 1,
            "mandatory_indexes": [],
            "terminal_indexes": [],
            "base_hard_tiers": [{"index": 0, "tier": [0]}, {"index": 1, "tier": [1]}],
            "base_vetoed_indexes": [],
        },
        {
            "id": "mandatory-index-precedes-adapter",
            "match_id": "as-wp4-mandatory",
            "prompt_id": "mandatory-choice",
            "prompt_generation": 1,
            "mandatory_indexes": [0],
            "terminal_indexes": [],
            "base_hard_tiers": [{"index": 0, "tier": [0]}, {"index": 1, "tier": [0]}],
            "base_vetoed_indexes": [],
        },
    ]


def vectors() -> dict[str, object]:
    context, window = _public_owners()
    cases: list[dict[str, object]] = []
    for spec in _case_specs():
        package = AuthorStrategyPackageLoader().load_bytes(FIXTURE_PATH.read_bytes())
        handle = AuthorStrategyMatchHandleBuilder.build(package, root=ROOT)
        host = PtcgDAPAuthorMatchHost.create(handle, spec["match_id"])
        prompt = AuthorStrategyShadowPrompt.create(
            context,
            window,
            prompt_id=spec["prompt_id"],
            prompt_generation=spec["prompt_generation"],
            mandatory_indexes=copy.deepcopy(spec["mandatory_indexes"]),
            terminal_indexes=copy.deepcopy(spec["terminal_indexes"]),
            base_hard_tiers=copy.deepcopy(spec["base_hard_tiers"]),
            base_vetoed_indexes=copy.deepcopy(spec["base_vetoed_indexes"]),
        )
        host.open_current_prompt(prompt)
        result = host.request_current_selection()
        cases.append(
            {
                **copy.deepcopy(spec),
                "expected_selected_indexes": result.indexes,
                "expected_audit": result.to_public_dict(),
            }
        )
    return {
        "schema_version": 1,
        "profile_id": PROFILE_ID,
        "fixture": {
            "package_path": "tests/ptcgdap/fixtures/author_strategy_packages/as_wp4/00-exact-mapped-shadow.ptcgai",
            "archive_sha256": _sha(FIXTURE_PATH.read_bytes()),
            "public_observation_hash": window.public_observation_hash,
            "window_id": window.window_id,
            "option_count": window.option_count,
        },
        "shadow_cases": cases,
    }


def build_artifacts() -> dict[str, dict[str, object]]:
    documents: dict[str, dict[str, object]] = {
        ARTIFACT_NAMES[0]: schema(),
        ARTIFACT_NAMES[1]: profile(),
        ARTIFACT_NAMES[2]: vectors(),
    }
    documents["author_strategy_match_host_bundle.json"] = {
        "schema_version": 1,
        "bundle_id": BUNDLE_ID,
        "digest_mode": "RFC8785_JCS_IJSON_SAFE_SUBSET_CANONICAL_SHA256",
        "parent_author_package_bundle_canonical_sha256": PARENT_AUTHOR_PACKAGE_BUNDLE,
        "cabt_contract_canonical_sha256": CABT_CONTRACT,
        "card_catalog_bundle_canonical_sha256": CARD_CATALOG_BUNDLE,
        "restricted_base_executor_bundle_canonical_sha256": RESTRICTED_BASE_EXECUTOR_BUNDLE,
        "portable_backend_bundle_canonical_sha256": PORTABLE_BACKEND_BUNDLE,
        "artifacts": [
            {
                "path": f"contracts/ptcgdap/{name}",
                "canonical_sha256": _digest(documents[name]),
            }
            for name in ARTIFACT_NAMES
        ],
    }
    return documents


def _write(document: object, path: Path) -> None:
    path.write_text(json.dumps(document, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Build AS-WP4 author strategy match Host contracts")
    parser.add_argument("--check", action="store_true")
    arguments = parser.parse_args()
    artifacts = build_artifacts()
    if arguments.check:
        for name, expected in artifacts.items():
            if not (CONTRACT_ROOT / name).is_file() or load_json_strict(CONTRACT_ROOT / name) != expected:
                raise SystemExit(f"out of date: {name}")
        return 0
    for name, document in artifacts.items():
        _write(document, CONTRACT_ROOT / name)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
