from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path, PurePosixPath
from typing import Any, Final

from .source_lock import (
    canonical_json_v1_bytes,
    load_json_bytes_strict,
    sha256_bytes,
)


TRUSTED_CATALOG_BUNDLE_CANONICAL_SHA256: Final = (
    "AB8CF10465F492A98DA8247A84572AECEE281D0726F7BB7B8E5DBC03A6AC70D4"
)
EXPECTED_RUNTIME_INTEGRITY_SHA256: Final = (
    "CC15E1F5219973C7E2E03181B12B818CB5DEA913A44571CA340C49973B349A3E"
)
EXPECTED_SOURCE_LOCK_CANONICAL_SHA256: Final = (
    "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"
)
EXPECTED_SOURCE_LOCK_ID: Final = "ptcgdap-source-lock-2026-08-09-p1wp1"
EXPECTED_SOURCE_MANIFEST_ID: Final = (
    "ptcgdap-card-id-catalog-source-manifest-p2-wp2-v1"
)
EXPECTED_CATALOG_BUNDLE_ID: Final = "ptcgdap-card-id-catalog-bundle-p2-wp2-v1"
EXPECTED_OFFICIAL_MASTER_ID: Final = "ptcgdap-official-card-attack-master-v1"
EXPECTED_EXACT_BRIDGE_ID: Final = "ptcgdap-marnie-exact-print-bridge-v1"
EXPECTED_VECTOR_ID: Final = "ptcgdap-card-id-catalog-conformance-vectors-v1"
MAX_CATALOG_JSON_BYTES: Final = 2 * 1024 * 1024
MAX_SAFE_INTEGER: Final = 2**53 - 1

_EXPECTED_ARTIFACTS: Final = (
    ("schema", "contracts/ptcgdap/card_id_catalog.schema.json"),
    (
        "source_manifest",
        "contracts/ptcgdap/card_id_catalog_source_manifest.json",
    ),
    (
        "official_master",
        "data/ptcgdap/card_id_catalog/official_card_attack_master_v1.json",
    ),
    (
        "exact_bridge",
        "data/ptcgdap/card_id_catalog/marnie_exact_print_bridge_v1.json",
    ),
    (
        "conformance_vectors",
        "contracts/ptcgdap/card_id_catalog_conformance_vectors.json",
    ),
)
_BUNDLE_RELATIVE_PATH: Final = "contracts/ptcgdap/card_id_catalog_bundle.json"
_BUNDLE_KEYS: Final = frozenset(
    {
        "schema_version",
        "artifact_id",
        "digest_mode",
        "artifact_set_policy",
        "source_lock_canonical_sha256",
        "parent_p1_contract",
        "parent_p2_wp1",
        "artifacts",
    }
)
_ARTIFACT_ENTRY_KEYS: Final = frozenset(
    {"id", "path", "canonical_sha256"}
)
_MASTER_KEYS: Final = frozenset(
    {
        "schema_version",
        "artifact_id",
        "source_manifest_id",
        "cards",
        "attacks",
        "source_evidence",
    }
)
_CARD_KEYS: Final = frozenset(
    {
        "official_card_id",
        "exact_english_printing_or_null",
        "ordered_official_attack_ids",
    }
)
_ATTACK_KEYS: Final = frozenset(
    {
        "official_attack_id",
        "owner_official_card_id",
        "owner_attack_ordinal",
    }
)
_BRIDGE_KEYS: Final = frozenset(
    {
        "schema_version",
        "artifact_id",
        "source_manifest_id",
        "bridge_scope",
        "entries",
    }
)
_BRIDGE_ENTRY_KEYS: Final = frozenset(
    {
        "official_card_id",
        "local_printing",
        "source_root_id",
        "source_file",
        "source_bytes",
        "source_raw_sha256",
        "source_canonical_json_v1_sha256",
        "local_attack_index_to_official_attack_id",
    }
)
_SOURCE_MANIFEST_KEYS: Final = frozenset(
    {
        "schema_version",
        "artifact_id",
        "source_lock",
        "official_bundle",
        "inputs",
        "derived_source_facts",
        "derived_artifacts",
    }
)
_LOCAL_SOURCE_INPUT_KEYS: Final = frozenset(
    {
        "id",
        "root_id",
        "path",
        "role",
        "bytes",
        "raw_sha256",
        "canonical_json_v1_sha256",
    }
)
_LOCAL_SOURCE_ROLE: Final = "reviewed_exact_local_printing_source"
_EXPECTED_UNMAPPED_OFFICIAL_IDS: Final = (
    860,
    1079,
    1086,
    1122,
    1137,
    1152,
    1182,
    1219,
    1227,
    1231,
)
_EXPECTED_PRINTING_NULL_IDS: Final = (916, 925, 929, 947, 992, 998, 999, 1083)
_EXPECTED_MAPPED_OFFICIAL_IDS: Final = (7, 104, 112, 646, 647, 648, 1080, 1097, 1259)
_STABLE_ERROR_CODES: Final = frozenset(
    {
        "catalog_not_loaded",
        "catalog_bundle_trust_anchor_mismatch",
        "catalog_artifact_set_invalid",
        "catalog_artifact_hash_mismatch",
        "catalog_integrity_invalid",
        "source_anchor_mismatch",
        "source_file_missing",
        "source_hash_mismatch",
        "schema_unsupported",
        "input_type_invalid",
        "official_card_unknown",
        "official_card_unmapped",
        "official_printing_unavailable",
        "official_attack_unknown",
        "local_printing_unmapped",
        "local_source_missing",
        "local_source_hash_mismatch",
        "mapping_conflict",
        "attack_unmapped",
        "attack_owner_mismatch",
        "attack_map_incomplete",
    }
)
_CONSTRUCTION_TOKEN: Final = object()


class CardIdCatalogError(RuntimeError):
    __slots__ = ("code",)

    def __init__(self, code: str) -> None:
        safe_code = code if code in _STABLE_ERROR_CODES else "catalog_integrity_invalid"
        self.code = safe_code
        super().__init__(safe_code)


@dataclass(frozen=True, slots=True)
class _FrozenObject:
    items: tuple[tuple[str, Any], ...]


@dataclass(frozen=True, slots=True)
class _FrozenArray:
    items: tuple[Any, ...]


def _freeze_json(value: Any) -> Any:
    value_type = type(value)
    if value is None or value_type in (bool, int, str):
        return value
    if value_type is list:
        return _FrozenArray(tuple(_freeze_json(child) for child in value))
    if value_type is dict:
        if any(type(key) is not str for key in value):
            raise CardIdCatalogError("catalog_integrity_invalid")
        return _FrozenObject(
            tuple((key, _freeze_json(child)) for key, child in value.items())
        )
    raise CardIdCatalogError("catalog_integrity_invalid")


def _thaw_json(value: Any) -> Any:
    if type(value) is _FrozenArray:
        return [_thaw_json(child) for child in value.items]
    if type(value) is _FrozenObject:
        return {key: _thaw_json(child) for key, child in value.items}
    return value


def _success(value: Any) -> dict[str, Any]:
    return {"ok": True, "error_code": None, "value": value}


def _failure(code: str) -> dict[str, Any]:
    safe_code = code if code in _STABLE_ERROR_CODES else "catalog_integrity_invalid"
    return {"ok": False, "error_code": safe_code, "value": None}


def _is_upper_sha256(value: Any) -> bool:
    return (
        type(value) is str
        and len(value) == 64
        and all(character in "0123456789ABCDEF" for character in value)
    )


def _is_safe_integer(value: Any) -> bool:
    return type(value) is int and -MAX_SAFE_INTEGER <= value <= MAX_SAFE_INTEGER


def _is_positive_safe_integer(value: Any) -> bool:
    return _is_safe_integer(value) and value > 0


def _is_nonnegative_safe_integer(value: Any) -> bool:
    return _is_safe_integer(value) and value >= 0


def _is_exact_identity_string(value: Any) -> bool:
    if type(value) is not str or not value:
        return False
    try:
        canonical_json_v1_bytes(value)
    except (TypeError, ValueError, RuntimeError, RecursionError):
        return False
    return True


def _require_exact_object(
    value: Any,
    expected_keys: frozenset[str],
    error_code: str,
) -> dict[str, Any]:
    if (
        type(value) is not dict
        or any(type(key) is not str for key in value)
        or set(value) != expected_keys
    ):
        raise CardIdCatalogError(error_code)
    return value


def _resolve_contained(repository_root: Path, relative_path: str) -> Path:
    if type(relative_path) is not str:
        raise CardIdCatalogError("catalog_artifact_set_invalid")
    pure = PurePosixPath(relative_path)
    if (
        pure.is_absolute()
        or not pure.parts
        or any(part in ("", ".", "..") for part in pure.parts)
        or "\\" in relative_path
    ):
        raise CardIdCatalogError("catalog_artifact_set_invalid")
    candidate = repository_root.joinpath(*pure.parts).resolve()
    try:
        candidate.relative_to(repository_root)
    except ValueError:
        raise CardIdCatalogError("catalog_artifact_set_invalid") from None
    return candidate


def _read_bounded(path: Path, missing_code: str, invalid_code: str) -> bytes:
    if not path.is_file():
        raise CardIdCatalogError(missing_code)
    try:
        with path.open("rb") as stream:
            payload = stream.read(MAX_CATALOG_JSON_BYTES + 1)
    except OSError:
        raise CardIdCatalogError(missing_code) from None
    if not payload or len(payload) > MAX_CATALOG_JSON_BYTES:
        raise CardIdCatalogError(invalid_code)
    return payload


def _parse_canonical(payload: bytes, error_code: str) -> tuple[Any, str]:
    try:
        document = load_json_bytes_strict(payload)
        canonical_hash = sha256_bytes(canonical_json_v1_bytes(document))
    except (TypeError, ValueError, RuntimeError, RecursionError, UnicodeError):
        raise CardIdCatalogError(error_code) from None
    return document, canonical_hash


def _validate_bundle(bundle: Any) -> tuple[tuple[str, str, str], ...]:
    bundle = _require_exact_object(bundle, _BUNDLE_KEYS, "catalog_artifact_set_invalid")
    if type(bundle["schema_version"]) is not int or bundle["schema_version"] != 1:
        raise CardIdCatalogError("schema_unsupported")
    if (
        bundle["artifact_id"] != EXPECTED_CATALOG_BUNDLE_ID
        or bundle["digest_mode"] != "canonical_json_v1"
        or bundle["artifact_set_policy"]
        != "exact_ids_and_paths_no_duplicates"
    ):
        raise CardIdCatalogError("catalog_artifact_set_invalid")
    if bundle["source_lock_canonical_sha256"] != EXPECTED_SOURCE_LOCK_CANONICAL_SHA256:
        raise CardIdCatalogError("source_anchor_mismatch")
    parent_p1 = _require_exact_object(
        bundle["parent_p1_contract"],
        frozenset({"contract_id", "canonical_sha256"}),
        "catalog_artifact_set_invalid",
    )
    if parent_p1 != {
        "contract_id": "ptcgdap-cabt-contract-p1-wp3-v1",
        "canonical_sha256": (
            "2CD02F54538985426EFDB057F3A6BDA4AD154DD171BCC03667D42D102982D294"
        ),
    }:
        raise CardIdCatalogError("catalog_artifact_set_invalid")
    parent_p2 = _require_exact_object(
        bundle["parent_p2_wp1"],
        frozenset(
            {
                "work_package",
                "manifest_path",
                "manifest_raw_sha256",
                "manifest_canonical_sha256",
            }
        ),
        "catalog_artifact_set_invalid",
    )
    if parent_p2 != {
        "work_package": "P2-WP1",
        "manifest_path": "artifacts/ptcgdap/p2_wp1/manifest.json",
        "manifest_raw_sha256": (
            "1465FF641BCF722DA3AD411F02DF8377B26872723509EABC355EE1167A1C20E9"
        ),
        "manifest_canonical_sha256": (
            "81BDB4B254B1A7246F1A071FB0D1ABF2125B9AF31BE6FCB20A9F7DA0DA0C8A3C"
        ),
    }:
        raise CardIdCatalogError("catalog_artifact_set_invalid")

    entries = bundle["artifacts"]
    if type(entries) is not list or len(entries) != len(_EXPECTED_ARTIFACTS):
        raise CardIdCatalogError("catalog_artifact_set_invalid")
    expected = dict(_EXPECTED_ARTIFACTS)
    actual: dict[str, tuple[str, str]] = {}
    seen_paths: set[str] = set()
    for entry in entries:
        entry = _require_exact_object(
            entry, _ARTIFACT_ENTRY_KEYS, "catalog_artifact_set_invalid"
        )
        artifact_id = entry["id"]
        relative_path = entry["path"]
        canonical_hash = entry["canonical_sha256"]
        if (
            type(artifact_id) is not str
            or type(relative_path) is not str
            or artifact_id in actual
            or relative_path in seen_paths
            or expected.get(artifact_id) != relative_path
            or not _is_upper_sha256(canonical_hash)
        ):
            raise CardIdCatalogError("catalog_artifact_set_invalid")
        actual[artifact_id] = (relative_path, canonical_hash)
        seen_paths.add(relative_path)
    if set(actual) != set(expected):
        raise CardIdCatalogError("catalog_artifact_set_invalid")
    return tuple(
        (artifact_id, expected[artifact_id], actual[artifact_id][1])
        for artifact_id, _ in _EXPECTED_ARTIFACTS
    )


def _validate_schema(document: Any) -> None:
    if type(document) is not dict:
        raise CardIdCatalogError("catalog_integrity_invalid")
    if (
        document.get("schema_version") != 1
        or document.get("$schema") != "https://json-schema.org/draft/2020-12/schema"
        or document.get("$id")
        != "https://ptcgdap.local/contracts/card_id_catalog.schema.json"
    ):
        raise CardIdCatalogError("schema_unsupported")


def _validate_master(
    document: Any,
) -> tuple[
    tuple[tuple[int, _FrozenObject], ...],
    tuple[tuple[int, _FrozenObject], ...],
    dict[int, dict[str, Any]],
    dict[int, dict[str, Any]],
]:
    master = _require_exact_object(document, _MASTER_KEYS, "catalog_integrity_invalid")
    if type(master["schema_version"]) is not int or master["schema_version"] != 1:
        raise CardIdCatalogError("schema_unsupported")
    if (
        master["artifact_id"] != EXPECTED_OFFICIAL_MASTER_ID
        or master["source_manifest_id"] != EXPECTED_SOURCE_MANIFEST_ID
    ):
        raise CardIdCatalogError("catalog_integrity_invalid")
    cards = master["cards"]
    attacks = master["attacks"]
    if type(cards) is not list or len(cards) != 1267:
        raise CardIdCatalogError("catalog_integrity_invalid")
    if type(attacks) is not list or len(attacks) != 1556:
        raise CardIdCatalogError("catalog_integrity_invalid")

    card_by_id: dict[int, dict[str, Any]] = {}
    attack_membership: dict[int, tuple[int, int]] = {}
    frozen_cards: list[tuple[int, _FrozenObject]] = []
    null_printing_ids: list[int] = []
    for record in cards:
        record = _require_exact_object(record, _CARD_KEYS, "catalog_integrity_invalid")
        card_id = record["official_card_id"]
        if not _is_positive_safe_integer(card_id) or card_id in card_by_id:
            raise CardIdCatalogError("mapping_conflict")
        printing = record["exact_english_printing_or_null"]
        if printing is None:
            null_printing_ids.append(card_id)
        else:
            printing = _require_exact_object(
                printing,
                frozenset({"expansion", "collection_no"}),
                "catalog_integrity_invalid",
            )
            if not _is_exact_identity_string(
                printing["expansion"]
            ) or not _is_exact_identity_string(printing["collection_no"]):
                raise CardIdCatalogError("catalog_integrity_invalid")
        ordered_attacks = record["ordered_official_attack_ids"]
        if type(ordered_attacks) is not list:
            raise CardIdCatalogError("catalog_integrity_invalid")
        for ordinal, attack_id in enumerate(ordered_attacks):
            if (
                not _is_positive_safe_integer(attack_id)
                or attack_id in attack_membership
            ):
                raise CardIdCatalogError("mapping_conflict")
            attack_membership[attack_id] = (card_id, ordinal)
        frozen = _freeze_json(record)
        if type(frozen) is not _FrozenObject:
            raise CardIdCatalogError("catalog_integrity_invalid")
        card_by_id[card_id] = record
        frozen_cards.append((card_id, frozen))
    if tuple(card_by_id) != tuple(range(1, 1268)):
        raise CardIdCatalogError("catalog_integrity_invalid")
    if tuple(null_printing_ids) != _EXPECTED_PRINTING_NULL_IDS:
        raise CardIdCatalogError("catalog_integrity_invalid")

    attack_by_id: dict[int, dict[str, Any]] = {}
    frozen_attacks: list[tuple[int, _FrozenObject]] = []
    for record in attacks:
        record = _require_exact_object(record, _ATTACK_KEYS, "catalog_integrity_invalid")
        attack_id = record["official_attack_id"]
        owner_id = record["owner_official_card_id"]
        ordinal = record["owner_attack_ordinal"]
        if (
            not _is_positive_safe_integer(attack_id)
            or attack_id in attack_by_id
            or not _is_positive_safe_integer(owner_id)
            or owner_id not in card_by_id
            or not _is_nonnegative_safe_integer(ordinal)
        ):
            raise CardIdCatalogError("mapping_conflict")
        if attack_membership.get(attack_id) != (owner_id, ordinal):
            raise CardIdCatalogError("attack_owner_mismatch")
        frozen = _freeze_json(record)
        if type(frozen) is not _FrozenObject:
            raise CardIdCatalogError("catalog_integrity_invalid")
        attack_by_id[attack_id] = record
        frozen_attacks.append((attack_id, frozen))
    if (
        tuple(attack_by_id) != tuple(range(1, 1557))
        or set(attack_by_id) != set(attack_membership)
    ):
        raise CardIdCatalogError("attack_map_incomplete")

    evidence = master["source_evidence"]
    if type(evidence) is not dict:
        raise CardIdCatalogError("catalog_integrity_invalid")
    if (
        evidence.get("current_official_card_count") != 1267
        or evidence.get("current_official_attack_count") != 1556
        or evidence.get("printing_null_official_card_ids")
        != list(_EXPECTED_PRINTING_NULL_IDS)
    ):
        raise CardIdCatalogError("catalog_integrity_invalid")
    return (
        tuple(frozen_cards),
        tuple(frozen_attacks),
        card_by_id,
        attack_by_id,
    )


def _validate_bridge(
    document: Any,
    card_by_id: dict[int, dict[str, Any]],
    attack_by_id: dict[int, dict[str, Any]],
) -> tuple[
    tuple[tuple[str, str, _FrozenObject], ...],
    tuple[tuple[str, str, _FrozenObject], ...],
]:
    bridge = _require_exact_object(document, _BRIDGE_KEYS, "catalog_integrity_invalid")
    if type(bridge["schema_version"]) is not int or bridge["schema_version"] != 1:
        raise CardIdCatalogError("schema_unsupported")
    if (
        bridge["artifact_id"] != EXPECTED_EXACT_BRIDGE_ID
        or bridge["source_manifest_id"] != EXPECTED_SOURCE_MANIFEST_ID
    ):
        raise CardIdCatalogError("catalog_integrity_invalid")
    scope = bridge["bridge_scope"]
    if type(scope) is not dict:
        raise CardIdCatalogError("catalog_integrity_invalid")
    if (
        scope.get("entry_count") != 9
        or scope.get("inference_policy") != "denied_exact_entries_only"
        or scope.get("local_800018501_cabt_exportable") is not False
        or scope.get("official_marnie_unmapped_card_ids")
        != list(_EXPECTED_UNMAPPED_OFFICIAL_IDS)
    ):
        raise CardIdCatalogError("catalog_integrity_invalid")
    entries = bridge["entries"]
    if type(entries) is not list or len(entries) != 9:
        raise CardIdCatalogError("catalog_integrity_invalid")

    local_entries: list[tuple[str, str, _FrozenObject]] = []
    source_bindings: list[tuple[str, str, _FrozenObject]] = []
    coordinates: set[tuple[str, str]] = set()
    official_ids: set[int] = set()
    for entry in entries:
        entry = _require_exact_object(
            entry, _BRIDGE_ENTRY_KEYS, "catalog_integrity_invalid"
        )
        local = _require_exact_object(
            entry["local_printing"],
            frozenset({"set_code", "card_index"}),
            "catalog_integrity_invalid",
        )
        set_code = local["set_code"]
        card_index = local["card_index"]
        if not _is_exact_identity_string(set_code) or not _is_exact_identity_string(
            card_index
        ):
            raise CardIdCatalogError("catalog_integrity_invalid")
        coordinate = (set_code, card_index)
        official_id = entry["official_card_id"]
        if (
            coordinate in coordinates
            or not _is_positive_safe_integer(official_id)
            or official_id in official_ids
            or official_id not in card_by_id
        ):
            raise CardIdCatalogError("mapping_conflict")
        coordinates.add(coordinate)
        official_ids.add(official_id)

        expected_source_path = f"data/bundled_user/cards/{set_code}_{card_index}.json"
        if (
            entry["source_root_id"] != "ptcgdap"
            or entry["source_file"] != expected_source_path
            or not _is_positive_safe_integer(entry["source_bytes"])
            or not _is_upper_sha256(entry["source_raw_sha256"])
            or not _is_upper_sha256(entry["source_canonical_json_v1_sha256"])
        ):
            raise CardIdCatalogError("source_anchor_mismatch")

        attack_map = entry["local_attack_index_to_official_attack_id"]
        if type(attack_map) is not dict:
            raise CardIdCatalogError("attack_map_incomplete")
        normalized_attack_map: dict[str, int] = {}
        for raw_index, attack_id in attack_map.items():
            if (
                type(raw_index) is not str
                or not raw_index.isascii()
                or not raw_index.isdigit()
                or str(int(raw_index)) != raw_index
                or not _is_positive_safe_integer(attack_id)
                or raw_index in normalized_attack_map
            ):
                raise CardIdCatalogError("attack_map_incomplete")
            normalized_attack_map[raw_index] = attack_id
        official_attack_ids = card_by_id[official_id]["ordered_official_attack_ids"]
        if (
            tuple(int(index) for index in normalized_attack_map)
            != tuple(range(len(official_attack_ids)))
            or list(normalized_attack_map.values()) != official_attack_ids
        ):
            raise CardIdCatalogError("attack_map_incomplete")
        for ordinal, attack_id in enumerate(official_attack_ids):
            attack = attack_by_id.get(attack_id)
            if attack is None or (
                attack["owner_official_card_id"], attack["owner_attack_ordinal"]
            ) != (official_id, ordinal):
                raise CardIdCatalogError("attack_owner_mismatch")

        query_record = {
            "local_attack_index_to_official_attack_id": normalized_attack_map,
            "local_printing": {"card_index": card_index, "set_code": set_code},
            "official_card_id": official_id,
            "source_canonical_json_v1_sha256": entry[
                "source_canonical_json_v1_sha256"
            ],
        }
        source_record = {
            "local_printing": {"card_index": card_index, "set_code": set_code},
            "official_card_id": official_id,
            "source_file": entry["source_file"],
            "source_bytes": entry["source_bytes"],
            "source_raw_sha256": entry["source_raw_sha256"],
            "source_canonical_json_v1_sha256": entry[
                "source_canonical_json_v1_sha256"
            ],
            "local_attack_count": len(normalized_attack_map),
        }
        frozen_query = _freeze_json(query_record)
        frozen_source = _freeze_json(source_record)
        if type(frozen_query) is not _FrozenObject or type(frozen_source) is not _FrozenObject:
            raise CardIdCatalogError("catalog_integrity_invalid")
        local_entries.append((set_code, card_index, frozen_query))
        source_bindings.append((set_code, card_index, frozen_source))
    if tuple(sorted(official_ids)) != _EXPECTED_MAPPED_OFFICIAL_IDS:
        raise CardIdCatalogError("mapping_conflict")
    return tuple(local_entries), tuple(source_bindings)


def _validate_source_manifest(
    document: Any,
    artifact_hashes: tuple[tuple[str, str], ...],
    source_bindings: tuple[tuple[str, str, _FrozenObject], ...],
) -> None:
    manifest = _require_exact_object(
        document, _SOURCE_MANIFEST_KEYS, "source_anchor_mismatch"
    )
    if type(manifest["schema_version"]) is not int or manifest["schema_version"] != 1:
        raise CardIdCatalogError("schema_unsupported")
    if manifest["artifact_id"] != EXPECTED_SOURCE_MANIFEST_ID:
        raise CardIdCatalogError("source_anchor_mismatch")
    source_lock = _require_exact_object(
        manifest["source_lock"],
        frozenset({"lock_id", "canonical_sha256"}),
        "source_anchor_mismatch",
    )
    if source_lock != {
        "lock_id": EXPECTED_SOURCE_LOCK_ID,
        "canonical_sha256": EXPECTED_SOURCE_LOCK_CANONICAL_SHA256,
    }:
        raise CardIdCatalogError("source_anchor_mismatch")

    artifact_hash_by_id = dict(artifact_hashes)
    derived = manifest["derived_artifacts"]
    if type(derived) is not dict or set(derived) != {"official_master", "exact_bridge"}:
        raise CardIdCatalogError("source_anchor_mismatch")
    expected_paths = dict(_EXPECTED_ARTIFACTS)
    for artifact_id in ("official_master", "exact_bridge"):
        record = _require_exact_object(
            derived[artifact_id],
            frozenset({"path", "canonical_sha256"}),
            "source_anchor_mismatch",
        )
        if record != {
            "path": expected_paths[artifact_id],
            "canonical_sha256": artifact_hash_by_id[artifact_id],
        }:
            raise CardIdCatalogError("source_anchor_mismatch")

    facts = manifest["derived_source_facts"]
    if type(facts) is not dict:
        raise CardIdCatalogError("source_anchor_mismatch")
    all_cards = facts.get("all_card_json")
    all_attacks = facts.get("all_attack_json")
    if (
        type(all_cards) is not dict
        or all_cards.get("record_count") != 1267
        or type(all_attacks) is not dict
        or all_attacks.get("record_count") != 1556
    ):
        raise CardIdCatalogError("source_anchor_mismatch")

    inputs = manifest["inputs"]
    if type(inputs) is not list:
        raise CardIdCatalogError("source_anchor_mismatch")
    ids: set[str] = set()
    paths: set[str] = set()
    local_inputs: dict[tuple[str, str], dict[str, Any]] = {}
    for record in inputs:
        if type(record) is not dict:
            raise CardIdCatalogError("source_anchor_mismatch")
        input_id = record.get("id")
        path = record.get("path")
        if (
            type(input_id) is not str
            or type(path) is not str
            or input_id in ids
            or (record.get("root_id"), path) in paths
        ):
            raise CardIdCatalogError("source_anchor_mismatch")
        ids.add(input_id)
        paths.add((record.get("root_id"), path))
        if record.get("role") != _LOCAL_SOURCE_ROLE:
            continue
        record = _require_exact_object(
            record, _LOCAL_SOURCE_INPUT_KEYS, "source_anchor_mismatch"
        )
        matching = [
            (set_code, card_index, _thaw_json(binding))
            for set_code, card_index, binding in source_bindings
            if _thaw_json(binding)["source_file"] == path
        ]
        if len(matching) != 1:
            raise CardIdCatalogError("source_anchor_mismatch")
        set_code, card_index, binding = matching[0]
        if record != {
            "bytes": binding["source_bytes"],
            "canonical_json_v1_sha256": binding[
                "source_canonical_json_v1_sha256"
            ],
            "id": f"local_exact_printing_{set_code}_{card_index}",
            "path": binding["source_file"],
            "raw_sha256": binding["source_raw_sha256"],
            "role": _LOCAL_SOURCE_ROLE,
            "root_id": "ptcgdap",
        }:
            raise CardIdCatalogError("source_anchor_mismatch")
        local_inputs[(set_code, card_index)] = record
    if set(local_inputs) != {
        (set_code, card_index) for set_code, card_index, _ in source_bindings
    }:
        raise CardIdCatalogError("source_anchor_mismatch")


def _validate_vectors(document: Any) -> None:
    vectors = _require_exact_object(
        document,
        frozenset(
            {
                "schema_version",
                "artifact_id",
                "result_contract",
                "stable_error_codes",
                "vectors",
            }
        ),
        "catalog_integrity_invalid",
    )
    if type(vectors["schema_version"]) is not int or vectors["schema_version"] != 1:
        raise CardIdCatalogError("schema_unsupported")
    if vectors["artifact_id"] != EXPECTED_VECTOR_ID:
        raise CardIdCatalogError("catalog_integrity_invalid")
    result_contract = vectors["result_contract"]
    if (
        type(result_contract) is not dict
        or result_contract.get("fields_in_order") != ["ok", "error_code", "value"]
        or result_contract.get("copy_only") is not True
        or result_contract.get("rejected_value_echo") != "forbidden"
    ):
        raise CardIdCatalogError("catalog_integrity_invalid")
    stable_codes = vectors["stable_error_codes"]
    if type(stable_codes) is not list or set(stable_codes) != set(_STABLE_ERROR_CODES):
        raise CardIdCatalogError("catalog_integrity_invalid")
    records = vectors["vectors"]
    if type(records) is not list or not records:
        raise CardIdCatalogError("catalog_integrity_invalid")
    seen_ids: set[str] = set()
    for record in records:
        if type(record) is not dict:
            raise CardIdCatalogError("catalog_integrity_invalid")
        vector_id = record.get("id")
        if (
            type(vector_id) is not str
            or vector_id in seen_ids
            or type(record.get("operation")) is not str
            or type(record.get("input")) is not dict
            or type(record.get("expected")) is not dict
        ):
            raise CardIdCatalogError("catalog_integrity_invalid")
        seen_ids.add(vector_id)


def _verify_local_sources(
    repository_root: Path,
    source_bindings: tuple[tuple[str, str, _FrozenObject], ...],
    card_by_id: dict[int, dict[str, Any]],
) -> None:
    for set_code, card_index, frozen_binding in source_bindings:
        binding = _thaw_json(frozen_binding)
        path = _resolve_contained(repository_root, binding["source_file"])
        payload = _read_bounded(path, "source_file_missing", "source_hash_mismatch")
        if (
            len(payload) != binding["source_bytes"]
            or sha256_bytes(payload) != binding["source_raw_sha256"]
        ):
            raise CardIdCatalogError("source_hash_mismatch")
        source, canonical_hash = _parse_canonical(payload, "source_hash_mismatch")
        if canonical_hash != binding["source_canonical_json_v1_sha256"]:
            raise CardIdCatalogError("source_hash_mismatch")
        if type(source) is not dict:
            raise CardIdCatalogError("source_hash_mismatch")
        if source.get("set_code") != set_code or source.get("card_index") != card_index:
            raise CardIdCatalogError("source_hash_mismatch")
        official = card_by_id[binding["official_card_id"]]
        printing = official["exact_english_printing_or_null"]
        if type(printing) is not dict or (
            source.get("set_code_en"), source.get("card_index_en")
        ) != (printing["expansion"], printing["collection_no"]):
            raise CardIdCatalogError("source_hash_mismatch")
        local_attacks = source.get("attacks")
        if type(local_attacks) is not list or len(local_attacks) != binding[
            "local_attack_count"
        ]:
            raise CardIdCatalogError("attack_map_incomplete")


def _runtime_integrity_digest(
    source_contract_hash: str,
    artifact_hashes: tuple[tuple[str, str], ...],
    cards: tuple[tuple[int, _FrozenObject], ...],
    attacks: tuple[tuple[int, _FrozenObject], ...],
    local_entries: tuple[tuple[str, str, _FrozenObject], ...],
    source_bindings: tuple[tuple[str, str, _FrozenObject], ...],
    audit: _FrozenObject,
) -> str:
    payload = {
        "source_contract_hash": source_contract_hash,
        "artifact_hashes": [
            {"artifact_id": artifact_id, "canonical_sha256": canonical_hash}
            for artifact_id, canonical_hash in artifact_hashes
        ],
        "cards": [
            {"key": card_id, "value": _thaw_json(record)}
            for card_id, record in cards
        ],
        "attacks": [
            {"key": attack_id, "value": _thaw_json(record)}
            for attack_id, record in attacks
        ],
        "local_entries": [
            {
                "set_code": set_code,
                "card_index": card_index,
                "value": _thaw_json(record),
            }
            for set_code, card_index, record in local_entries
        ],
        "source_bindings": [
            {
                "set_code": set_code,
                "card_index": card_index,
                "value": _thaw_json(record),
            }
            for set_code, card_index, record in source_bindings
        ],
        "audit": _thaw_json(audit),
    }
    return sha256_bytes(canonical_json_v1_bytes(payload))


@dataclass(frozen=True, slots=True, init=False)
class CardIdCatalog:
    """Sealed, source-verified shadow catalog with exact coordinate lookups only."""

    source_contract_hash: str
    _artifact_hashes: tuple[tuple[str, str], ...]
    _cards: tuple[tuple[int, _FrozenObject], ...]
    _attacks: tuple[tuple[int, _FrozenObject], ...]
    _local_entries: tuple[tuple[str, str, _FrozenObject], ...]
    _source_bindings: tuple[tuple[str, str, _FrozenObject], ...]
    _audit: _FrozenObject
    _runtime_integrity_sha256: str
    _construction_seal: object

    def __new__(cls) -> CardIdCatalog:
        raise TypeError("CardIdCatalog instances must be created by a trusted loader")

    @classmethod
    def _from_verified(
        cls,
        *,
        construction_token: object,
        source_contract_hash: str,
        artifact_hashes: tuple[tuple[str, str], ...],
        cards: tuple[tuple[int, _FrozenObject], ...],
        attacks: tuple[tuple[int, _FrozenObject], ...],
        local_entries: tuple[tuple[str, str, _FrozenObject], ...],
        source_bindings: tuple[tuple[str, str, _FrozenObject], ...],
        audit: _FrozenObject,
    ) -> CardIdCatalog:
        if construction_token is not _CONSTRUCTION_TOKEN:
            raise TypeError("CardIdCatalog construction is loader-owned")
        result = object.__new__(cls)
        integrity = _runtime_integrity_digest(
            source_contract_hash,
            artifact_hashes,
            cards,
            attacks,
            local_entries,
            source_bindings,
            audit,
        )
        values = {
            "source_contract_hash": source_contract_hash,
            "_artifact_hashes": artifact_hashes,
            "_cards": cards,
            "_attacks": attacks,
            "_local_entries": local_entries,
            "_source_bindings": source_bindings,
            "_audit": audit,
            "_runtime_integrity_sha256": integrity,
            "_construction_seal": _CONSTRUCTION_TOKEN,
        }
        for field_name, value in values.items():
            object.__setattr__(result, field_name, value)
        return result

    @classmethod
    def load_default(cls) -> CardIdCatalog:
        repository_root = Path(__file__).resolve().parents[3]
        return cls.load_trusted_bundle(repository_root)

    @classmethod
    def load_trusted_bundle(cls, repository_root: str | Path) -> CardIdCatalog:
        return _load_catalog(repository_root)

    def _integrity_valid(self) -> bool:
        try:
            card_keys = tuple(card_id for card_id, _ in self._cards)
            attack_keys = tuple(attack_id for attack_id, _ in self._attacks)
            local_keys = tuple(
                (set_code, card_index)
                for set_code, card_index, _ in self._local_entries
            )
            source_keys = tuple(
                (set_code, card_index)
                for set_code, card_index, _ in self._source_bindings
            )
            if (
                self._construction_seal is not _CONSTRUCTION_TOKEN
                or self.source_contract_hash
                != TRUSTED_CATALOG_BUNDLE_CANONICAL_SHA256
                or tuple(artifact_id for artifact_id, _ in self._artifact_hashes)
                != tuple(artifact_id for artifact_id, _ in _EXPECTED_ARTIFACTS)
                or len(self._cards) != 1267
                or len(self._attacks) != 1556
                or len(self._local_entries) != 9
                or len(self._source_bindings) != 9
                or card_keys != tuple(range(1, 1268))
                or attack_keys != tuple(range(1, 1557))
                or len(set(local_keys)) != 9
                or len(set(source_keys)) != 9
                or set(local_keys) != set(source_keys)
            ):
                return False
            for card_id, frozen in self._cards:
                record = _thaw_json(frozen)
                if type(record) is not dict or record.get("official_card_id") != card_id:
                    return False
            for attack_id, frozen in self._attacks:
                record = _thaw_json(frozen)
                if type(record) is not dict or record.get("official_attack_id") != attack_id:
                    return False
            for set_code, card_index, frozen in (
                self._local_entries + self._source_bindings
            ):
                record = _thaw_json(frozen)
                printing = record.get("local_printing") if type(record) is dict else None
                if type(printing) is not dict or printing != {
                    "card_index": card_index,
                    "set_code": set_code,
                }:
                    return False
            actual = _runtime_integrity_digest(
                self.source_contract_hash,
                self._artifact_hashes,
                self._cards,
                self._attacks,
                self._local_entries,
                self._source_bindings,
                self._audit,
            )
            return (
                self._runtime_integrity_sha256
                == EXPECTED_RUNTIME_INTEGRITY_SHA256
                and actual == EXPECTED_RUNTIME_INTEGRITY_SHA256
            )
        except Exception:
            return False

    def _guard(self) -> dict[str, Any] | None:
        if not self._integrity_valid():
            return _failure("catalog_integrity_invalid")
        return None

    def _require_integrity(self) -> None:
        if not self._integrity_valid():
            raise CardIdCatalogError("catalog_integrity_invalid")

    def catalog_hash(self) -> str:
        self._require_integrity()
        return self.source_contract_hash

    def audit_snapshot(self) -> dict[str, Any]:
        self._require_integrity()
        result = _thaw_json(self._audit)
        if type(result) is not dict:
            raise CardIdCatalogError("catalog_integrity_invalid")
        return result

    def artifact_canonical_sha256(self, artifact_id: Any) -> dict[str, Any]:
        if (guard := self._guard()) is not None:
            return guard
        if type(artifact_id) is not str:
            return _failure("input_type_invalid")
        for current_id, canonical_hash in self._artifact_hashes:
            if current_id == artifact_id:
                return _success(canonical_hash)
        return _failure("catalog_artifact_set_invalid")

    def is_known_official_card_id(self, official_card_id: Any) -> dict[str, Any]:
        if (guard := self._guard()) is not None:
            return guard
        if not _is_safe_integer(official_card_id):
            return _failure("input_type_invalid")
        return _success(any(card_id == official_card_id for card_id, _ in self._cards))

    def lookup_official_card(self, official_card_id: Any) -> dict[str, Any]:
        if (guard := self._guard()) is not None:
            return guard
        if not _is_safe_integer(official_card_id):
            return _failure("input_type_invalid")
        for card_id, frozen in self._cards:
            if card_id == official_card_id:
                return _success(_thaw_json(frozen))
        return _failure("official_card_unknown")

    def official_printing_for(self, official_card_id: Any) -> dict[str, Any]:
        if (guard := self._guard()) is not None:
            return guard
        if not _is_safe_integer(official_card_id):
            return _failure("input_type_invalid")
        for card_id, frozen in self._cards:
            if card_id == official_card_id:
                record = _thaw_json(frozen)
                printing = record["exact_english_printing_or_null"]
                if printing is None:
                    return _failure("official_printing_unavailable")
                return _success(printing)
        return _failure("official_card_unknown")

    def lookup_official_attack(self, official_attack_id: Any) -> dict[str, Any]:
        if (guard := self._guard()) is not None:
            return guard
        if not _is_safe_integer(official_attack_id):
            return _failure("input_type_invalid")
        for attack_id, frozen in self._attacks:
            if attack_id == official_attack_id:
                return _success(_thaw_json(frozen))
        return _failure("official_attack_unknown")

    def official_attack_owner(self, official_attack_id: Any) -> dict[str, Any]:
        result = self.lookup_official_attack(official_attack_id)
        if not result["ok"]:
            return result
        attack = result["value"]
        return _success(
            {
                "owner_official_card_id": attack["owner_official_card_id"],
                "owner_attack_ordinal": attack["owner_attack_ordinal"],
            }
        )

    def lookup_local_printing(self, set_code: Any, card_index: Any) -> dict[str, Any]:
        if (guard := self._guard()) is not None:
            return guard
        if not _is_exact_identity_string(set_code) or not _is_exact_identity_string(
            card_index
        ):
            return _failure("input_type_invalid")
        for current_set, current_index, frozen in self._local_entries:
            if (current_set, current_index) == (set_code, card_index):
                return _success(_thaw_json(frozen))
        return _failure("local_printing_unmapped")

    def lookup_official_card_id(self, set_code: Any, card_index: Any) -> dict[str, Any]:
        result = self.lookup_local_printing(set_code, card_index)
        if not result["ok"]:
            return result
        return _success(result["value"]["official_card_id"])

    def lookup_local_printing_for_official_card(
        self, official_card_id: Any
    ) -> dict[str, Any]:
        if (guard := self._guard()) is not None:
            return guard
        if not _is_safe_integer(official_card_id):
            return _failure("input_type_invalid")
        known = False
        for card_id, _ in self._cards:
            if card_id == official_card_id:
                known = True
                break
        if not known:
            return _failure("official_card_unknown")
        for _, _, frozen in self._local_entries:
            record = _thaw_json(frozen)
            if record["official_card_id"] == official_card_id:
                return _success(
                    {
                        "local_printing": record["local_printing"],
                        "official_card_id": official_card_id,
                        "source_canonical_json_v1_sha256": record[
                            "source_canonical_json_v1_sha256"
                        ],
                    }
                )
        return _failure("official_card_unmapped")

    def lookup_local_attack(
        self,
        set_code: Any,
        card_index: Any,
        local_attack_index: Any,
    ) -> dict[str, Any]:
        if (guard := self._guard()) is not None:
            return guard
        if (
            not _is_exact_identity_string(set_code)
            or not _is_exact_identity_string(card_index)
            or not _is_nonnegative_safe_integer(local_attack_index)
        ):
            return _failure("input_type_invalid")
        for current_set, current_index, frozen in self._local_entries:
            if (current_set, current_index) != (set_code, card_index):
                continue
            record = _thaw_json(frozen)
            attack_id = record["local_attack_index_to_official_attack_id"].get(
                str(local_attack_index)
            )
            if attack_id is None:
                return _failure("attack_unmapped")
            for current_attack_id, frozen_attack in self._attacks:
                if current_attack_id == attack_id:
                    attack = _thaw_json(frozen_attack)
                    if attack["owner_official_card_id"] != record["official_card_id"]:
                        return _failure("attack_owner_mismatch")
                    return _success(
                        {
                            "official_attack_id": attack_id,
                            "official_card_id": record["official_card_id"],
                            "owner_attack_ordinal": attack["owner_attack_ordinal"],
                        }
                    )
            return _failure("official_attack_unknown")
        return _failure("local_printing_unmapped")

    def lookup_official_attack_id(
        self,
        set_code: Any,
        card_index: Any,
        local_attack_index: Any,
    ) -> dict[str, Any]:
        result = self.lookup_local_attack(set_code, card_index, local_attack_index)
        if not result["ok"]:
            return result
        return _success(result["value"]["official_attack_id"])

    def validate_local_source(
        self,
        set_code: Any,
        card_index: Any,
        actual_source: Any,
    ) -> dict[str, Any]:
        if (guard := self._guard()) is not None:
            return guard
        if not _is_exact_identity_string(set_code) or not _is_exact_identity_string(
            card_index
        ):
            return _failure("input_type_invalid")
        binding = None
        for current_set, current_index, frozen in self._source_bindings:
            if (current_set, current_index) == (set_code, card_index):
                binding = _thaw_json(frozen)
                break
        if binding is None:
            return _failure("local_source_missing")
        if type(actual_source) is bytes:
            if (
                len(actual_source) != binding["source_bytes"]
                or sha256_bytes(actual_source) != binding["source_raw_sha256"]
            ):
                return _failure("local_source_hash_mismatch")
            try:
                source_tree = load_json_bytes_strict(actual_source)
            except (TypeError, ValueError, RuntimeError, UnicodeError):
                return _failure("local_source_hash_mismatch")
        elif type(actual_source) is dict:
            source_tree = actual_source
        else:
            return _failure("input_type_invalid")
        try:
            actual_hash = sha256_bytes(canonical_json_v1_bytes(source_tree))
        except (TypeError, ValueError, RuntimeError, RecursionError):
            return _failure("local_source_hash_mismatch")
        if actual_hash != binding["source_canonical_json_v1_sha256"]:
            return _failure("local_source_hash_mismatch")
        return _success(True)


def _load_catalog(repository_root: str | Path) -> CardIdCatalog:
    try:
        root = Path(repository_root).resolve()
    except (TypeError, ValueError, OSError):
        raise CardIdCatalogError("catalog_not_loaded") from None
    if not root.is_dir():
        raise CardIdCatalogError("catalog_not_loaded")

    bundle_path = _resolve_contained(root, _BUNDLE_RELATIVE_PATH)
    bundle_payload = _read_bounded(
        bundle_path,
        "catalog_bundle_trust_anchor_mismatch",
        "catalog_bundle_trust_anchor_mismatch",
    )
    bundle, bundle_hash = _parse_canonical(
        bundle_payload, "catalog_bundle_trust_anchor_mismatch"
    )
    if bundle_hash != TRUSTED_CATALOG_BUNDLE_CANONICAL_SHA256:
        raise CardIdCatalogError("catalog_bundle_trust_anchor_mismatch")
    artifact_entries = _validate_bundle(bundle)

    documents: dict[str, Any] = {}
    artifact_hashes: list[tuple[str, str]] = []
    for artifact_id, relative_path, expected_hash in artifact_entries:
        artifact_path = _resolve_contained(root, relative_path)
        payload = _read_bounded(
            artifact_path,
            "catalog_artifact_hash_mismatch",
            "catalog_artifact_hash_mismatch",
        )
        document, actual_hash = _parse_canonical(
            payload, "catalog_artifact_hash_mismatch"
        )
        if actual_hash != expected_hash:
            raise CardIdCatalogError("catalog_artifact_hash_mismatch")
        documents[artifact_id] = document
        artifact_hashes.append((artifact_id, actual_hash))
    artifact_hash_tuple = tuple(artifact_hashes)

    _validate_schema(documents["schema"])
    cards, attacks, card_by_id, attack_by_id = _validate_master(
        documents["official_master"]
    )
    local_entries, source_bindings = _validate_bridge(
        documents["exact_bridge"], card_by_id, attack_by_id
    )
    _validate_source_manifest(
        documents["source_manifest"], artifact_hash_tuple, source_bindings
    )
    _validate_vectors(documents["conformance_vectors"])
    _verify_local_sources(root, source_bindings, card_by_id)

    audit_document = {
        "status": "loaded",
        "authority": "shadow_coordinate_lookup_only",
        "live_consumer_authorized": False,
        "official_card_count": len(cards),
        "official_attack_count": len(attacks),
        "mapped_local_printing_count": len(local_entries),
        "verified_artifact_count": len(artifact_hash_tuple),
        "verified_local_source_count": len(source_bindings),
        "bundle_canonical_sha256": bundle_hash,
        "source_manifest_id": EXPECTED_SOURCE_MANIFEST_ID,
        "source_lock_canonical_sha256": EXPECTED_SOURCE_LOCK_CANONICAL_SHA256,
        "inference_policy": "denied_exact_entries_only",
    }
    frozen_audit = _freeze_json(audit_document)
    if type(frozen_audit) is not _FrozenObject:
        raise CardIdCatalogError("catalog_integrity_invalid")
    return CardIdCatalog._from_verified(
        construction_token=_CONSTRUCTION_TOKEN,
        source_contract_hash=bundle_hash,
        artifact_hashes=artifact_hash_tuple,
        cards=cards,
        attacks=attacks,
        local_entries=local_entries,
        source_bindings=source_bindings,
        audit=frozen_audit,
    )


def load_default() -> CardIdCatalog:
    return CardIdCatalog.load_default()


def load_trusted_bundle(repository_root: str | Path) -> CardIdCatalog:
    return CardIdCatalog.load_trusted_bundle(repository_root)


__all__ = [
    "CardIdCatalog",
    "CardIdCatalogError",
    "EXPECTED_RUNTIME_INTEGRITY_SHA256",
    "EXPECTED_SOURCE_LOCK_CANONICAL_SHA256",
    "MAX_CATALOG_JSON_BYTES",
    "TRUSTED_CATALOG_BUNDLE_CANONICAL_SHA256",
    "load_default",
    "load_trusted_bundle",
]
