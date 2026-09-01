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
STRATEGIC_CONTEXT_VECTORS = CONTRACT_ROOT / "strategic_context_v18_conformance_vectors.json"
PROFILE_ID = "ptcgdap-local-uid-public-context-as-wp6-v1"
BUNDLE_ID = PROFILE_ID
PARENT_BUNDLE = "C80F4C4FDAEA5AC29BD3C5617BFAC72BE38709696F7EA1995D3D153113DD3CA1"
SOURCE_LOCK = "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"
LOCAL_CONTEXT_PREFIX = b"PTCGDAP\0LOCAL_UID_PUBLIC_CONTEXT_V1\0"
LOCAL_UID_SET_PREFIX = b"PTCGDAP\0LOCAL_UID_ALLOWED_SET_V1\0"
LOCAL_DOMAIN = "godot_local_card_uid_v1"
LOCAL_UID_PATTERN = "^[A-Za-z0-9.]+_[A-Za-z0-9]+$"
ARTIFACTS = (
    "local_uid_public_context.schema.json",
    "local_uid_public_context_profile.json",
    "local_uid_public_context_conformance_vectors.json",
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


def load(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def schema() -> dict[str, Any]:
    local_uid = {
        "type": "string",
        "minLength": 4,
        "maxLength": 64,
        "pattern": LOCAL_UID_PATTERN,
        "not": {"pattern": "(?i:private)"},
    }
    return {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "https://ptcgdap.local/contracts/local_uid_public_context.schema.json",
        "title": "PTCGDAP local stable-card-UID public prompt binding",
        "$defs": {
            "safeInteger": {"type": "integer", "minimum": -SAFE_MAX, "maximum": SAFE_MAX},
            "hash": {"type": "string", "pattern": "^[0-9A-F]{64}$"},
            "localCardUid": local_uid,
            "option": {
                "type": "object",
                "additionalProperties": False,
                "required": ["index", "local_card_uid"],
                "properties": {
                    "index": {"allOf": [{"$ref": "#/$defs/safeInteger"}, {"minimum": 0}]},
                    "local_card_uid": {"oneOf": [{"type": "null"}, {"$ref": "#/$defs/localCardUid"}]},
                },
            },
            "publicCard": {
                "type": "object",
                "additionalProperties": False,
                "required": ["serial", "local_card_uid"],
                "properties": {
                    "serial": {"allOf": [{"$ref": "#/$defs/safeInteger"}, {"minimum": 1}]},
                    "local_card_uid": {"$ref": "#/$defs/localCardUid"},
                },
            },
            "localUidPublicContext": {
                "type": "object",
                "additionalProperties": False,
                "required": ["schema_version", "card_id_domain", "source", "options", "acting_hand", "acting_active"],
                "properties": {
                    "schema_version": {"const": 1},
                    "card_id_domain": {"const": LOCAL_DOMAIN},
                    "source": {
                        "type": "object",
                        "additionalProperties": False,
                        "required": ["context_hash", "window_id"],
                        "properties": {
                            "context_hash": {"$ref": "#/$defs/hash"},
                            "window_id": {"$ref": "#/$defs/hash"},
                        },
                    },
                    "options": {"type": "array", "maxItems": 1024, "items": {"$ref": "#/$defs/option"}},
                    "acting_hand": {"type": "array", "maxItems": 1024, "items": {"$ref": "#/$defs/publicCard"}},
                    "acting_active": {"type": "array", "maxItems": 1, "items": {"$ref": "#/$defs/publicCard"}},
                },
            },
        },
        "$ref": "#/$defs/localUidPublicContext",
    }


def profile() -> dict[str, Any]:
    return {
        "schema_version": 1,
        "profile_id": PROFILE_ID,
        "parent_bundle_canonical_sha256": PARENT_BUNDLE,
        "source_lock_canonical_sha256": SOURCE_LOCK,
        "card_identity": {
            "domain": LOCAL_DOMAIN,
            "construction": "set_code + '_' + card_index",
            "syntax_pattern": LOCAL_UID_PATTERN,
            "set_code_pattern": "^[A-Za-z0-9.]+$",
            "card_index_pattern": "^[A-Za-z0-9]+$",
            "component_max_length": 32,
            "portable_to_cabt": False,
            "merge_with_official_card_id": False,
            "display_name_mapping_allowed": False,
        },
        "binding_contract": {
            "exact_top_level_allowlist": ["schema_version", "card_id_domain", "source", "options", "acting_hand", "acting_active"],
            "source_matches_current_strategic_context": ["context_hash", "window_id"],
            "options_match_current_window_by_exact_index_order": True,
            "acting_cards_match_public_serial_order": True,
            "all_non_null_uids_must_be_in_pinned_deck_manifest": True,
            "opponent_hidden_identity_allowed": False,
            "private_sentinel_allowed": False,
            "old_window_reuse_allowed": False,
        },
        "hash_contract": {
            "canonicalization": "RFC8785_JCS_IJSON_SAFE_SUBSET",
            "local_context_prefix_utf8_hex": LOCAL_CONTEXT_PREFIX.hex().upper(),
            "allowed_uid_set_prefix_utf8_hex": LOCAL_UID_SET_PREFIX.hex().upper(),
            "allowed_uid_set_sort": "ascending_unicode_codepoint",
        },
        "stable_error_codes": ["local_uid_contract_error", "invalid_local_uid_public_context"],
        "scope": {
            "windows_device_local_shadow": True,
            "player_live_authority": False,
            "cabt_export": False,
            "android": False,
        },
    }


def vectors() -> dict[str, Any]:
    strategic = load(STRATEGIC_CONTEXT_VECTORS)["fixture"]["expected_context"]
    options = strategic["select_semantics"]["options"]
    acting = strategic["public_state"]["acting_player"]
    allowed_uids = ["CSV10C_146", "CSV10C_148", "CSV7C_177", "SVP_105"]
    valid = {
        "schema_version": 1,
        "card_id_domain": LOCAL_DOMAIN,
        "source": {
            "context_hash": strategic["context_hash"],
            "window_id": strategic["source"]["window_id"],
        },
        "options": [
            {"index": item["index"], "local_card_uid": "CSV10C_146" if item["index"] == 0 else None}
            for item in options
        ],
        "acting_hand": [
            {"serial": item["serial"], "local_card_uid": "CSV7C_177"}
            for item in acting["hand"]
        ],
        "acting_active": [
            {"serial": item["serial"], "local_card_uid": "CSV10C_148"}
            for item in acting["active"]
        ],
    }
    invalid_cases: list[dict[str, Any]] = []

    def reject(case_id: str, mutation: Any) -> None:
        value = copy.deepcopy(valid)
        mutation(value)
        invalid_cases.append({"id": case_id, "value": value, "expected_error_code": "invalid_local_uid_public_context"})

    reject("unknown_uid", lambda value: value["options"][0].update(local_card_uid="CSV999C_999"))
    reject("serial_drift", lambda value: value["acting_hand"][0].update(serial=value["acting_hand"][0]["serial"] + 1))
    reject("window_drift", lambda value: value["source"].update(window_id="A" * 64))
    reject("option_index_drift", lambda value: value["options"][0].update(index=1))
    reject("extra_opponent_hidden_field", lambda value: value.update(opponent_hidden_cards=[]))
    reject("private_sentinel", lambda value: value["acting_hand"][0].update(local_card_uid="PRIVATE_SENTINEL"))
    return {
        "schema_version": 1,
        "vector_set_id": PROFILE_ID,
        "profile_id": PROFILE_ID,
        "strategic_context_fixture": {
            "contract_path": "contracts/ptcgdap/strategic_context_v18_conformance_vectors.json",
            "context_hash": strategic["context_hash"],
            "window_id": strategic["source"]["window_id"],
        },
        "deck_binding": {
            "allowed_card_uids": allowed_uids,
            "deck_manifest_sha256": "B" * 64,
            "expected_allowed_uid_set_hash": domain_hash(LOCAL_UID_SET_PREFIX, allowed_uids),
        },
        "accepted_case": {
            "id": "exact_current_public_bind",
            "value": valid,
            "expected_local_context_hash": domain_hash(LOCAL_CONTEXT_PREFIX, valid),
        },
        "rejected_cases": invalid_cases,
        "private_sentinels": ["PRIVATE_SENTINEL", "PRIVATE_OPPONENT_HAND", "PRIVATE_CALLBACK"],
    }


def artifacts() -> dict[str, Any]:
    owned = {
        "local_uid_public_context.schema.json": schema(),
        "local_uid_public_context_profile.json": profile(),
        "local_uid_public_context_conformance_vectors.json": vectors(),
    }
    bundle = {
        "schema_version": 1,
        "bundle_id": BUNDLE_ID,
        "parent_bundle_canonical_sha256": PARENT_BUNDLE,
        "source_lock_canonical_sha256": SOURCE_LOCK,
        "artifacts": [
            {
                "id": name.removesuffix(".json"),
                "path": f"contracts/ptcgdap/{name}",
                "canonical_sha256": digest(owned[name]),
            }
            for name in ARTIFACTS
        ],
    }
    return {**owned, "local_uid_public_context_bundle.json": bundle}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    generated = artifacts()
    mismatches: list[str] = []
    for name, value in generated.items():
        path = CONTRACT_ROOT / name
        expected = pretty(value)
        if args.check:
            if not path.exists() or path.read_bytes() != expected:
                mismatches.append(str(path.relative_to(ROOT)))
        else:
            path.write_bytes(expected)
    if mismatches:
        print("contract drift: " + ", ".join(mismatches), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
