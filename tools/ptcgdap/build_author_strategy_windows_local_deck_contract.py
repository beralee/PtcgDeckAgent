from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import sys
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


PROFILE_ID = "ptcgdap-author-strategy-windows-local-deck-v1"
BUNDLE_ID = "ptcgdap-author-strategy-windows-local-deck-as-wp6-v1"
CARD_ID_DOMAIN = "godot_local_card_uid_v1"
PARENT_PACKAGE_BUNDLE = "B416F2CBA2795B62126B6EF7B5F07A9000E84D5FA1DF62C1753CADC9E82E106B"
MARNIE_SOURCE_DECK_ID = 800018501
MARNIE_SOURCE_DECK_PATH = "data/bundled_user/decks/800018501.json"
MARNIE_SOURCE_DECK_RAW_SHA256 = "8E28C31BE70AB2971EAED9AAB8C6A2D7A3412A95E0E335A702C1F13D547B805F"
MARNIE_SOURCE_DECK_CANONICAL_SHA256 = "CB2FD50F40D75BDD9E38B826580A516BDCE7C51B17A43C63CE58E0CC19127CAB"
MARNIE_REVIEW_MANIFEST = "data/ptcgdap/marnie_vertical_slice/local_deck_manifest_v1.json"
MARNIE_OUTPUT_MANIFEST = "data/ptcgdap/marnie_vertical_slice/windows_local_deck_manifest_v1.json"
ARTIFACT_PATHS = {
    "schema": "contracts/ptcgdap/author_strategy_windows_local_deck.schema.json",
    "profile": "contracts/ptcgdap/author_strategy_windows_local_deck_profile.json",
    "vectors": "contracts/ptcgdap/author_strategy_windows_local_deck_conformance_vectors.json",
    "bundle": "contracts/ptcgdap/author_strategy_windows_local_deck_bundle.json",
}
UID_RE = re.compile(r"^[A-Za-z0-9.]+_[A-Za-z0-9]+$")
HEX32_RE = re.compile(r"^[0-9a-f]{32}$")


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def _strict_object(properties: dict[str, object], required: list[str]) -> dict[str, object]:
    return {
        "type": "object",
        "additionalProperties": False,
        "required": required,
        "properties": properties,
    }


def build_schema() -> dict[str, object]:
    upper_sha = {"type": "string", "pattern": "^[0-9A-F]{64}$"}
    slug = {"type": "string", "pattern": "^[a-z0-9][a-z0-9.-]{1,126}[a-z0-9]$"}
    card = _strict_object(
        {
            "local_card_uid": {"type": "string", "pattern": "^[A-Za-z0-9.]+_[A-Za-z0-9]+$", "maxLength": 64},
            "set_code": {"type": "string", "pattern": "^[A-Za-z0-9.]+$", "maxLength": 32},
            "card_index": {"type": "string", "pattern": "^[A-Za-z0-9]+$", "maxLength": 32},
            "count": {"type": "integer", "minimum": 1, "maximum": 60},
            "card_type": {"type": "string", "minLength": 1, "maxLength": 32},
            "stage": {"type": "string", "maxLength": 32},
            "effect_id": {"type": "string", "pattern": "^[0-9a-f]{32}$"},
            "source_raw_sha256": upper_sha,
            "source_canonical_sha256": upper_sha,
        },
        [
            "local_card_uid",
            "set_code",
            "card_index",
            "count",
            "card_type",
            "stage",
            "effect_id",
            "source_raw_sha256",
            "source_canonical_sha256",
        ],
    )
    return {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "https://ptcgdap.local/contracts/author_strategy_windows_local_deck.schema.json",
        "title": "PTCGDAP author strategy Windows local deck manifest",
        **_strict_object(
            {
                "document_type": {"const": "deck_manifest_windows_local_v1"},
                "schema_version": {"const": 1},
                "deck_id": slug,
                "card_id_domain": {"const": CARD_ID_DOMAIN},
                "card_count": {"const": 60},
                "unique_card_count": {"type": "integer", "minimum": 1, "maximum": 60},
                "deck_csv_sha256": upper_sha,
                "cabt_exportable": {"const": False},
                "platform_scope": {"const": ["windows"]},
                "source_deck_id": {"type": "integer", "minimum": 1, "maximum": 9007199254740991},
                "source_deck_raw_sha256": upper_sha,
                "source_deck_canonical_sha256": upper_sha,
                "cards": {"type": "array", "minItems": 1, "maxItems": 60, "items": card},
            },
            [
                "document_type",
                "schema_version",
                "deck_id",
                "card_id_domain",
                "card_count",
                "unique_card_count",
                "deck_csv_sha256",
                "cabt_exportable",
                "platform_scope",
                "source_deck_id",
                "source_deck_raw_sha256",
                "source_deck_canonical_sha256",
                "cards",
            ],
        ),
    }


def build_profile() -> dict[str, object]:
    return {
        "schema_version": 1,
        "profile_id": PROFILE_ID,
        "parent_author_package_bundle_canonical_sha256": PARENT_PACKAGE_BUNDLE,
        "supported_platforms": ["windows"],
        "card_id_domain": CARD_ID_DOMAIN,
        "cabt_exportable": False,
        "identity_rule": "local_card_uid is exact bundled CardData printing UID set_code + '_' + card_index",
        "forbidden_identity_sources": ["display_name", "localized_name", "godot_object_id", "per_match_instance_id", "official_card_id_guess"],
        "csv_profile": {
            "header": "local_card_uid,count",
            "encoding": "ASCII",
            "line_ending": "LF",
            "terminal_newline": True,
            "row_order": "ascending_ascii_local_card_uid",
        },
        "match_gate": {
            "source_deck_raw_and_canonical_hash_required": True,
            "per_card_raw_and_canonical_hash_required": True,
            "manifest_csv_exact_relation_required": True,
            "card_database_exact_uid_required": True,
            "minimum_basic_pokemon": 1,
            "non_basic_energy_copy_limit": 4,
            "unknown_or_drift": "package_deck_unmapped",
        },
        "claims": {
            "windows_local_deck_materialization": True,
            "official_cabt_identity": False,
            "cabt_export": False,
            "android": False,
            "engine_parity": False,
            "player_live": False,
        },
    }


def build_vectors() -> dict[str, object]:
    return {
        "schema_version": 1,
        "vector_set_id": "ptcgdap-author-strategy-windows-local-deck-v1",
        "profile_id": PROFILE_ID,
        "cases": [
            {"id": "valid_marnie_800018501", "expected_accepted": True, "expected_error_code": None},
            {"id": "android_scope", "expected_accepted": False, "expected_error_code": "package_deck_unmapped"},
            {"id": "cabt_exportable", "expected_accepted": False, "expected_error_code": "package_deck_unmapped"},
            {"id": "uid_path_traversal", "expected_accepted": False, "expected_error_code": "package_deck_unmapped"},
            {"id": "uid_duplicate_or_unsorted", "expected_accepted": False, "expected_error_code": "package_deck_unmapped"},
            {"id": "manifest_csv_mismatch", "expected_accepted": False, "expected_error_code": "package_deck_unmapped"},
            {"id": "source_deck_drift", "expected_accepted": False, "expected_error_code": "package_deck_unmapped"},
            {"id": "source_card_drift", "expected_accepted": False, "expected_error_code": "package_deck_unmapped"},
        ],
    }


def _validated_review_entries(root: Path) -> dict[str, dict[str, Any]]:
    review = load_json_strict(root / MARNIE_REVIEW_MANIFEST)
    if (
        review.get("deck_id") != MARNIE_SOURCE_DECK_ID
        or review.get("card_count") != 60
        or review.get("unique_printing_count") != 28
        or review.get("cabt_exportable") is not False
        or type(review.get("cards")) is not list
    ):
        raise ValueError("Marnie review manifest drift")
    result: dict[str, dict[str, Any]] = {}
    for entry in review["cards"]:
        printing = entry.get("local_printing") if type(entry) is dict else None
        if type(printing) is not dict:
            raise ValueError("Marnie review printing drift")
        uid = f"{printing.get('set_code')}_{printing.get('card_index')}"
        if not UID_RE.fullmatch(uid) or uid in result or entry.get("godot_card_implementation_status_expected") != "implemented":
            raise ValueError("Marnie review identity drift")
        result[uid] = entry
    if len(result) != 28:
        raise ValueError("Marnie review unique printing drift")
    return result


def build_marnie_deck_manifest(root: Path = ROOT) -> dict[str, object]:
    source_path = root / MARNIE_SOURCE_DECK_PATH
    source_bytes = source_path.read_bytes()
    source = load_json_strict(source_path)
    if (
        _sha(source_bytes) != MARNIE_SOURCE_DECK_RAW_SHA256
        or _sha(canonical_json_v1_bytes(source)) != MARNIE_SOURCE_DECK_CANONICAL_SHA256
        or source.get("id") != MARNIE_SOURCE_DECK_ID
        or source.get("total_cards") != 60
        or source.get("deck_name") != "18.0 玛俐的长毛巨魔"
        or source.get("source_url") != "https://limitlesstcg.com/decks/list/18501"
        or type(source.get("cards")) is not list
    ):
        raise ValueError("Marnie 18.0 source deck drift")
    review = _validated_review_entries(root)
    entries: list[dict[str, object]] = []
    source_uids: set[str] = set()
    total = 0
    for deck_entry in source["cards"]:
        if type(deck_entry) is not dict:
            raise ValueError("Marnie source deck entry drift")
        set_code = deck_entry.get("set_code")
        card_index = deck_entry.get("card_index")
        count = deck_entry.get("count")
        uid = f"{set_code}_{card_index}"
        if (
            type(set_code) is not str
            or type(card_index) is not str
            or type(count) is not int
            or not UID_RE.fullmatch(uid)
            or uid in source_uids
            or uid not in review
            or not 1 <= count <= 60
        ):
            raise ValueError("Marnie source deck identity drift")
        source_uids.add(uid)
        card_path = root / "data/bundled_user/cards" / f"{uid}.json"
        card_bytes = card_path.read_bytes()
        card = load_json_strict(card_path)
        effect_id = card.get("effect_id")
        card_type = card.get("card_type")
        stage = card.get("stage", "")
        reviewed = review[uid]
        if (
            card.get("set_code") != set_code
            or card.get("card_index") != card_index
            or type(card_type) is not str
            or type(stage) is not str
            or type(effect_id) is not str
            or HEX32_RE.fullmatch(effect_id) is None
            or reviewed.get("count") != count
            or reviewed.get("card_type") != card_type
            or reviewed.get("effect_id") != effect_id
            or deck_entry.get("effect_id") != effect_id
        ):
            raise ValueError(f"Marnie source card drift: {uid}")
        entries.append(
            {
                "local_card_uid": uid,
                "set_code": set_code,
                "card_index": card_index,
                "count": count,
                "card_type": card_type,
                "stage": stage,
                "effect_id": effect_id,
                "source_raw_sha256": _sha(card_bytes),
                "source_canonical_sha256": _sha(canonical_json_v1_bytes(card)),
            }
        )
        total += count
    entries.sort(key=lambda entry: str(entry["local_card_uid"]).encode("ascii"))
    if total != 60 or len(entries) != 28 or set(review) != source_uids:
        raise ValueError("Marnie exact 60 relation drift")
    draft: dict[str, object] = {
        "document_type": "deck_manifest_windows_local_v1",
        "schema_version": 1,
        "deck_id": "marnie.18.0.grimmsnarl.800018501",
        "card_id_domain": CARD_ID_DOMAIN,
        "card_count": 60,
        "unique_card_count": 28,
        "deck_csv_sha256": "0" * 64,
        "cabt_exportable": False,
        "platform_scope": ["windows"],
        "source_deck_id": MARNIE_SOURCE_DECK_ID,
        "source_deck_raw_sha256": MARNIE_SOURCE_DECK_RAW_SHA256,
        "source_deck_canonical_sha256": MARNIE_SOURCE_DECK_CANONICAL_SHA256,
        "cards": entries,
    }
    draft["deck_csv_sha256"] = _sha(build_marnie_deck_csv(draft))
    return draft


def build_marnie_deck_csv(manifest: dict[str, object]) -> bytes:
    cards = manifest.get("cards")
    if type(cards) is not list:
        raise ValueError("invalid local deck cards")
    lines = ["local_card_uid,count"]
    for entry in cards:
        if type(entry) is not dict:
            raise ValueError("invalid local deck entry")
        lines.append(f"{entry['local_card_uid']},{entry['count']}")
    return ("\n".join(lines) + "\n").encode("ascii")


def build_contract_documents() -> dict[str, dict[str, object]]:
    documents = {
        "schema": build_schema(),
        "profile": build_profile(),
        "vectors": build_vectors(),
    }
    documents["bundle"] = {
        "schema_version": 1,
        "bundle_id": BUNDLE_ID,
        "profile_id": PROFILE_ID,
        "parent_author_package_bundle_canonical_sha256": PARENT_PACKAGE_BUNDLE,
        "artifacts": [
            {
                "id": artifact_id,
                "path": ARTIFACT_PATHS[artifact_id],
                "canonical_sha256": _sha(canonical_json_v1_bytes(documents[artifact_id])),
            }
            for artifact_id in ("schema", "profile", "vectors")
        ],
    }
    return documents


def _render(value: object) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def rendered_artifacts(root: Path = ROOT) -> dict[str, bytes]:
    documents = build_contract_documents()
    rendered = {ARTIFACT_PATHS[key]: _render(value) for key, value in documents.items()}
    rendered[MARNIE_OUTPUT_MANIFEST] = _render(build_marnie_deck_manifest(root))
    return rendered


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.write == args.check:
        raise SystemExit("choose exactly one of --write or --check")
    rendered = rendered_artifacts(ROOT)
    if args.check:
        drift = [path for path, value in rendered.items() if not (ROOT / path).is_file() or (ROOT / path).read_bytes() != value]
        if drift:
            raise SystemExit("Windows local deck contract drift: " + ", ".join(drift))
    else:
        for path, value in rendered.items():
            destination = ROOT / path
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(value)
    documents = build_contract_documents()
    print(f"bundle_canonical_sha256={_sha(canonical_json_v1_bytes(documents['bundle']))}")
    print(f"marnie_manifest_canonical_sha256={_sha(canonical_json_v1_bytes(build_marnie_deck_manifest(ROOT)))}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
