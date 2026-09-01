from __future__ import annotations

import argparse
import csv
import ctypes
from collections import Counter
from copy import deepcopy
import json
from pathlib import Path, PurePosixPath
import sys
from typing import Any, Mapping, Sequence

_MODULE_REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
if str(_MODULE_REPOSITORY_ROOT) not in sys.path:
    sys.path.insert(0, str(_MODULE_REPOSITORY_ROOT))

from scripts.ai.ptcgdap.source_lock import (
    canonical_json_v1_bytes,
    load_json_bytes_strict,
    load_json_strict,
    sha256_bytes,
)


CATALOG_SCHEMA_VERSION = 1
CATALOG_BUNDLE_ID = "ptcgdap-card-id-catalog-bundle-p2-wp2-v1"
SOURCE_MANIFEST_ID = "ptcgdap-card-id-catalog-source-manifest-p2-wp2-v1"
OFFICIAL_MASTER_ID = "ptcgdap-official-card-attack-master-v1"
EXACT_BRIDGE_ID = "ptcgdap-marnie-exact-print-bridge-v1"
CONFORMANCE_VECTORS_ID = "ptcgdap-card-id-catalog-conformance-vectors-v1"
MAX_SAFE_INTEGER = 2**53 - 1

SOURCE_LOCK_CANONICAL_SHA256 = (
    "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"
)
P1_CONTRACT_CANONICAL_SHA256 = (
    "2CD02F54538985426EFDB057F3A6BDA4AD154DD171BCC03667D42D102982D294"
)
P2_WP1_MANIFEST_RAW_SHA256 = (
    "1465FF641BCF722DA3AD411F02DF8377B26872723509EABC355EE1167A1C20E9"
)
P2_WP1_MANIFEST_CANONICAL_SHA256 = (
    "81BDB4B254B1A7246F1A071FB0D1ABF2125B9AF31BE6FCB20A9F7DA0DA0C8A3C"
)
OFFICIAL_BUNDLE_MANIFEST_RAW_SHA256 = (
    "9728A4409F2D8378F161E6BF33A871186C583CEAD3222372A5C4E092C5CB356C"
)

OFFICIAL_BUNDLE_RELATIVE = PurePosixPath("official_data/kaggle_bundle")
OFFICIAL_INPUTS: dict[str, tuple[str, str]] = {
    "official_en_card_data_csv": (
        "EN_Card_Data.csv",
        "A0EA63CF7ADCB65D35436CE0EB390DE6E2E35654A7C67C065A45F4ABAA00F373",
    ),
    "official_cg_api_py": (
        "sample_submission/sample_submission/cg/api.py",
        "593F1298E52A635F90F8F505A52113E9AF114F444C293404E37906F18EE06CED",
    ),
    "official_cg_sim_py": (
        "sample_submission/sample_submission/cg/sim.py",
        "1555F57F5D22BF4C09D70E0E667A916E575E68C9DD1DE9EAD34BA5E7E4968655",
    ),
    "official_cg_dll": (
        "sample_submission/sample_submission/cg/cg.dll",
        "A3A401D0F5CCC3474B9C8A7A2431920C4B728D28105A510AA6927AD6283E5CF7",
    ),
    "official_api_h": (
        "ptcg_engine/ptcgProgram 22/Api.h",
        "786ACAE884631BDCBAB0311471316BC75D62ACB465B8011BF09DAD05628BCAFD",
    ),
    "official_to_json_h": (
        "ptcg_engine/ptcgProgram 22/ToJson.h",
        "84EE63939863493520EBE29E8CA717217EBF90191829EA80D1349942AA867602",
    ),
}
OFFICIAL_MARNIE_DECK_RELATIVE = PurePosixPath(
    "agents/marnie_raihan_graph_r121_pre_attack_phase_order/deck.csv"
)
OFFICIAL_MARNIE_DECK_RAW_SHA256 = (
    "48F1A03E8AB8162F6DC608E6743A4F3B32004CB702CA447050E62055B85DEFBF"
)
LOCAL_DECK_RELATIVE = PurePosixPath("data/bundled_user/decks/800018501.json")
LOCAL_DECK_CANONICAL_SHA256 = (
    "CB2FD50F40D75BDD9E38B826580A516BDCE7C51B17A43C63CE58E0CC19127CAB"
)
LOCAL_DECK_RAW_SHA256 = (
    "8E28C31BE70AB2971EAED9AAB8C6A2D7A3412A95E0E335A702C1F13D547B805F"
)
LOCAL_DECK_BYTES = 13_723

ALL_CARD_BYTES = 461_443
ALL_CARD_RAW_SHA256 = (
    "D7E29C6284BDB4D3A1EAABC38C247A1522F6E924AD3F81B569AA6D97FD49C80C"
)
ALL_ATTACK_BYTES = 206_848
ALL_ATTACK_RAW_SHA256 = (
    "EA1E10F6F031FC973E16F4B5DAFCD9CF116AAD2FAB7A82723E693E8DD9EA00E5"
)
EXPECTED_CARD_COUNT = 1267
EXPECTED_ATTACK_COUNT = 1556
EXPECTED_EN_ROW_COUNT = 2022
EXPECTED_NULL_PRINTINGS = [916, 925, 929, 947, 992, 998, 999, 1083]

ARTIFACT_PATHS = {
    "schema": "contracts/ptcgdap/card_id_catalog.schema.json",
    "source_manifest": "contracts/ptcgdap/card_id_catalog_source_manifest.json",
    "official_master": "data/ptcgdap/card_id_catalog/official_card_attack_master_v1.json",
    "exact_bridge": "data/ptcgdap/card_id_catalog/marnie_exact_print_bridge_v1.json",
    "conformance_vectors": "contracts/ptcgdap/card_id_catalog_conformance_vectors.json",
    "bundle": "contracts/ptcgdap/card_id_catalog_bundle.json",
}

BRIDGE_SPECS = [
    {
        "official_card_id": 7,
        "local_printing": {"set_code": "CSVE1C", "card_index": "DAR"},
        "source_file": "data/bundled_user/cards/CSVE1C_DAR.json",
        "source_raw_sha256": "B86CF49A7890C45951CDB80C87BC75F0392812C5370DA66866FCC979DC79CAB2",
        "source_canonical_json_v1_sha256": "B29AF1051D130851567F72BA2759A71B9BF51405DDF15305645B3C0BFF218084",
        "local_attack_index_to_official_attack_id": {},
    },
    {
        "official_card_id": 104,
        "local_printing": {"set_code": "CSV7C", "card_index": "059"},
        "source_file": "data/bundled_user/cards/CSV7C_059.json",
        "source_raw_sha256": "042936F1770BD8B9B9A06EDFA28DE212CA04A0D5022E1EB8B915F705323B2499",
        "source_canonical_json_v1_sha256": "6342EEAB3468FF43718D841C9DD55E750F0FFA27ECB8622FD5478AA820AFDD95",
        "local_attack_index_to_official_attack_id": {"0": 131},
    },
    {
        "official_card_id": 112,
        "local_printing": {"set_code": "CSV8C", "card_index": "094"},
        "source_file": "data/bundled_user/cards/CSV8C_094.json",
        "source_raw_sha256": "9EEDD84B0FDA69DFBED0A32C0321C2E4B9A8A4B6C905D22F3EB8FEBBAB56C2A1",
        "source_canonical_json_v1_sha256": "8540B67BA8C3F5D45AC0F9E372A7C3B7BDCA7F3F050D4159D704C08E18526A8F",
        "local_attack_index_to_official_attack_id": {"0": 141},
    },
    {
        "official_card_id": 646,
        "local_printing": {"set_code": "LEN_DRI", "card_index": "134"},
        "source_file": "data/bundled_user/cards/LEN_DRI_134.json",
        "source_raw_sha256": "7A09714B9835766BF5BAC71C0D2FEC1735E908D97980E3E06FBDBCE39B1D27E2",
        "source_canonical_json_v1_sha256": "D7259EED7B9B583DFF95AC92D7CF1E258B84B1F678F21C1743563AC03929C733",
        "local_attack_index_to_official_attack_id": {"0": 934, "1": 935},
    },
    {
        "official_card_id": 647,
        "local_printing": {"set_code": "LEN_DRI", "card_index": "135"},
        "source_file": "data/bundled_user/cards/LEN_DRI_135.json",
        "source_raw_sha256": "1BD94CB5EAC1EA0021F423A07A23508059E4BCEAB288B90620D71B51F63706C4",
        "source_canonical_json_v1_sha256": "651B012760D24BBC2E09BCC2A4A1F5010AEB595B4C98046246CC669C2362E824",
        "local_attack_index_to_official_attack_id": {"0": 936},
    },
    {
        "official_card_id": 648,
        "local_printing": {"set_code": "LEN_DRI", "card_index": "136"},
        "source_file": "data/bundled_user/cards/LEN_DRI_136.json",
        "source_raw_sha256": "5EFA9B7F30F3ADA7DF097D68A6D7851553E9C3E5490406239DA2434406716D3C",
        "source_canonical_json_v1_sha256": "A041E7168A5CA50C82E76DDBA0CEC6F2C7F66C34593B4D6A9A8C68690664021A",
        "local_attack_index_to_official_attack_id": {"0": 937},
    },
    {
        "official_card_id": 1080,
        "local_printing": {"set_code": "CSV8C", "card_index": "173"},
        "source_file": "data/bundled_user/cards/CSV8C_173.json",
        "source_raw_sha256": "4FF6B61A942B6D7023AC4FEB149E701ACCC70F556F0F53B8CBD69227E26FE3EE",
        "source_canonical_json_v1_sha256": "DE4487B0030DEBAFE37303E51E978E3FA5C0C09BCADDD8245B365F2ED988ED94",
        "local_attack_index_to_official_attack_id": {},
    },
    {
        "official_card_id": 1097,
        "local_printing": {"set_code": "CSV8C", "card_index": "183"},
        "source_file": "data/bundled_user/cards/CSV8C_183.json",
        "source_raw_sha256": "713F2B15DED2F144E562667A5B7AC853E6770DDA3616934882664BF67D9AA457",
        "source_canonical_json_v1_sha256": "FB05919614D31D6362E7CBCDDCB7137EC1EC2AB160B4D20FA8E0634F3E2A0AB2",
        "local_attack_index_to_official_attack_id": {},
    },
    {
        "official_card_id": 1259,
        "local_printing": {"set_code": "LEN_DRI", "card_index": "169"},
        "source_file": "data/bundled_user/cards/LEN_DRI_169.json",
        "source_raw_sha256": "486CEC705A0DAB6D855C938CF43291ECBCFD36C646F105D129F5E549B8BD3642",
        "source_canonical_json_v1_sha256": "28079978B465F21F50CE9FDDA8B7EB9B6406C409F29BDCDC9D67E747FEAF3E1B",
        "local_attack_index_to_official_attack_id": {},
    },
]

OFFICIAL_INPUT_BYTES = {
    "official_en_card_data_csv": 359_151,
    "official_cg_api_py": 26_933,
    "official_cg_sim_py": 2_273,
    "official_cg_dll": 1_525_248,
    "official_api_h": 8_427,
    "official_to_json_h": 9_993,
}
LOCAL_SOURCE_BYTES = {
    "data/bundled_user/cards/CSVE1C_DAR.json": 912,
    "data/bundled_user/cards/CSV7C_059.json": 1_496,
    "data/bundled_user/cards/CSV8C_094.json": 1_686,
    "data/bundled_user/cards/LEN_DRI_134.json": 1_700,
    "data/bundled_user/cards/LEN_DRI_135.json": 1_497,
    "data/bundled_user/cards/LEN_DRI_136.json": 2_788,
    "data/bundled_user/cards/CSV8C_173.json": 1_167,
    "data/bundled_user/cards/CSV8C_183.json": 1_008,
    "data/bundled_user/cards/LEN_DRI_169.json": 1_427,
}

STABLE_ERROR_CODES = [
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
]


class CatalogBuildError(ValueError):
    def __init__(self, code: str) -> None:
        super().__init__(code)
        self.code = code


def _fail(code: str) -> None:
    raise CatalogBuildError(code)


def _raw_sha256(path: Path) -> str:
    try:
        return sha256_bytes(path.read_bytes())
    except OSError:
        _fail("source_file_missing")


def _require_file(root: Path, relative: PurePosixPath) -> Path:
    if relative.is_absolute() or any(part in {"", ".", ".."} for part in relative.parts):
        _fail("source_path_invalid")
    try:
        resolved_root = root.resolve(strict=True)
        candidate = (resolved_root / Path(*relative.parts)).resolve(strict=True)
        candidate.relative_to(resolved_root)
    except (OSError, RuntimeError, ValueError):
        _fail("source_file_missing")
    if not candidate.is_file():
        _fail("source_file_missing")
    return candidate


def _require_raw_hash(path: Path, expected: str) -> bytes:
    data = path.read_bytes()
    if sha256_bytes(data) != expected:
        _fail("source_hash_mismatch")
    return data


def _require_exact_int(value: Any, code: str) -> int:
    if type(value) is not int or value < 1 or value > MAX_SAFE_INTEGER:
        _fail(code)
    return value


def _load_native_snapshots(dll_path: Path) -> tuple[bytes, bytes]:
    try:
        library = ctypes.CDLL(str(dll_path))
        initialize = getattr(library, "GameInitialize")
        initialize()
        all_card = getattr(library, "AllCard")
        all_attack = getattr(library, "AllAttack")
        all_card.restype = ctypes.c_char_p
        all_attack.restype = ctypes.c_char_p
        card_value = all_card()
        attack_value = all_attack()
    except (AttributeError, OSError, TypeError, ValueError):
        _fail("official_native_snapshot_unavailable")
    if not isinstance(card_value, bytes) or not isinstance(attack_value, bytes):
        _fail("official_native_snapshot_invalid")
    return card_value, attack_value


def _parse_official_printings(csv_path: Path) -> tuple[dict[int, dict[str, str] | None], int]:
    try:
        with csv_path.open("r", encoding="utf-8-sig", newline="") as stream:
            rows = list(csv.DictReader(stream))
    except (OSError, UnicodeError, csv.Error):
        _fail("official_csv_invalid")
    if len(rows) != EXPECTED_EN_ROW_COUNT:
        _fail("official_csv_row_count_mismatch")
    by_id: dict[int, dict[str, str] | None] = {}
    printing_owner: dict[tuple[str, str], int] = {}
    for row in rows:
        try:
            card_id = int(row["Card ID"])
            expansion = row["Expansion"]
            collection_no = row["Collection No."]
        except (KeyError, TypeError, ValueError):
            _fail("official_csv_invalid")
        _require_exact_int(card_id, "official_card_id_invalid")
        if type(expansion) is not str or type(collection_no) is not str or not collection_no:
            _fail("official_csv_invalid")
        printing = None if not expansion else {
            "expansion": expansion,
            "collection_no": collection_no,
        }
        if card_id in by_id and by_id[card_id] != printing:
            _fail("official_printing_conflict")
        by_id[card_id] = printing
        if printing is not None:
            pair = (printing["expansion"], printing["collection_no"])
            prior = printing_owner.get(pair)
            if prior is not None and prior != card_id:
                _fail("official_printing_conflict")
            printing_owner[pair] = card_id
    return by_id, len(rows)


def _build_official_master(
    all_card_bytes: bytes,
    all_attack_bytes: bytes,
    printings: Mapping[int, dict[str, str] | None],
    row_count: int,
) -> dict[str, Any]:
    try:
        raw_cards = load_json_bytes_strict(all_card_bytes)
        raw_attacks = load_json_bytes_strict(all_attack_bytes)
    except (UnicodeError, ValueError, json.JSONDecodeError):
        _fail("official_native_snapshot_invalid")
    if not isinstance(raw_cards, list) or not isinstance(raw_attacks, list):
        _fail("official_native_snapshot_invalid")
    if len(raw_cards) != EXPECTED_CARD_COUNT or len(raw_attacks) != EXPECTED_ATTACK_COUNT:
        _fail("official_native_snapshot_count_mismatch")

    cards: list[dict[str, Any]] = []
    attacks_by_id: dict[int, dict[str, int]] = {}
    previous_card_id = 0
    for raw_card in raw_cards:
        if type(raw_card) is not dict:
            _fail("official_card_invalid")
        card_id = _require_exact_int(raw_card.get("cardId"), "official_card_id_invalid")
        if card_id <= previous_card_id:
            _fail("master_card_order_or_duplicate")
        previous_card_id = card_id
        raw_attack_ids = raw_card.get("attacks")
        if type(raw_attack_ids) is not list:
            _fail("official_card_invalid")
        ordered_attack_ids: list[int] = []
        for ordinal, raw_attack_id in enumerate(raw_attack_ids):
            attack_id = _require_exact_int(raw_attack_id, "official_attack_id_invalid")
            if attack_id in attacks_by_id:
                _fail("master_attack_owner_conflict")
            attacks_by_id[attack_id] = {
                "official_attack_id": attack_id,
                "owner_official_card_id": card_id,
                "owner_attack_ordinal": ordinal,
            }
            ordered_attack_ids.append(attack_id)
        if card_id not in printings:
            _fail("official_printing_missing")
        cards.append(
            {
                "official_card_id": card_id,
                "exact_english_printing_or_null": deepcopy(printings[card_id]),
                "ordered_official_attack_ids": ordered_attack_ids,
            }
        )

    native_attack_ids: list[int] = []
    previous_attack_id = 0
    for raw_attack in raw_attacks:
        if type(raw_attack) is not dict:
            _fail("official_attack_invalid")
        attack_id = _require_exact_int(raw_attack.get("attackId"), "official_attack_id_invalid")
        if attack_id <= previous_attack_id:
            _fail("master_attack_order_or_duplicate")
        previous_attack_id = attack_id
        native_attack_ids.append(attack_id)
    if set(native_attack_ids) != set(attacks_by_id) or len(attacks_by_id) != EXPECTED_ATTACK_COUNT:
        _fail("master_attack_membership_mismatch")
    if set(printings) != {record["official_card_id"] for record in cards}:
        _fail("official_printing_membership_mismatch")

    null_ids = [
        record["official_card_id"]
        for record in cards
        if record["exact_english_printing_or_null"] is None
    ]
    if null_ids != EXPECTED_NULL_PRINTINGS:
        _fail("official_printing_null_set_mismatch")
    return {
        "schema_version": CATALOG_SCHEMA_VERSION,
        "artifact_id": OFFICIAL_MASTER_ID,
        "source_manifest_id": SOURCE_MANIFEST_ID,
        "cards": cards,
        "attacks": [attacks_by_id[attack_id] for attack_id in sorted(attacks_by_id)],
        "source_evidence": {
            "current_official_card_count": len(cards),
            "current_official_attack_count": len(attacks_by_id),
            "english_csv_data_row_count": row_count,
            "printing_null_official_card_ids": null_ids,
            "id_range_semantics": "observed_current_source_evidence_only_not_a_future_dense_id_contract",
        },
    }


def _load_official_deck(path: Path) -> list[int]:
    try:
        lines = path.read_text(encoding="utf-8-sig").splitlines()
        values = [int(line) for line in lines if line != ""]
    except (OSError, UnicodeError, ValueError):
        _fail("official_deck_invalid")
    if len(values) != 60 or any(value <= 0 for value in values):
        _fail("official_deck_invalid")
    return values


def _load_local_deck(path: Path) -> dict[str, Any]:
    value = load_json_strict(path)
    if type(value) is not dict or type(value.get("cards")) is not list:
        _fail("local_deck_invalid")
    counts: list[int] = []
    seen_printings: set[tuple[str, str]] = set()
    for entry in value["cards"]:
        if type(entry) is not dict:
            _fail("local_deck_invalid")
        set_code = entry.get("set_code")
        card_index = entry.get("card_index")
        count = entry.get("count")
        if (
            type(set_code) is not str
            or not set_code
            or type(card_index) is not str
            or not card_index
            or type(count) is not int
            or count <= 0
        ):
            _fail("local_deck_invalid")
        printing = (set_code, card_index)
        if printing in seen_printings:
            _fail("local_deck_invalid")
        seen_printings.add(printing)
        counts.append(count)
    if sum(counts) != 60:
        _fail("local_deck_invalid")
    return value


def _build_exact_bridge(
    repository_root: Path,
    master: Mapping[str, Any],
    official_deck: Sequence[int],
    local_deck: Mapping[str, Any],
) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    cards_by_id = {record["official_card_id"]: record for record in master["cards"]}
    entries: list[dict[str, Any]] = []
    local_input_records: list[dict[str, Any]] = []
    seen_local: set[tuple[str, str]] = set()
    seen_official: set[int] = set()
    for spec in BRIDGE_SPECS:
        local = spec["local_printing"]
        key = (local["set_code"], local["card_index"])
        card_id = spec["official_card_id"]
        if key in seen_local or card_id in seen_official:
            _fail("mapping_conflict")
        seen_local.add(key)
        seen_official.add(card_id)
        relative = PurePosixPath(spec["source_file"])
        source_path = _require_file(repository_root, relative)
        source_bytes = _require_raw_hash(source_path, spec["source_raw_sha256"])
        try:
            source_tree = load_json_bytes_strict(source_bytes)
            canonical_hash = sha256_bytes(canonical_json_v1_bytes(source_tree))
        except (UnicodeError, ValueError, TypeError, json.JSONDecodeError):
            _fail("local_source_invalid")
        if canonical_hash != spec["source_canonical_json_v1_sha256"]:
            _fail("source_hash_mismatch")
        if type(source_tree) is not dict:
            _fail("local_source_invalid")
        if source_tree.get("set_code") != key[0] or source_tree.get("card_index") != key[1]:
            _fail("bridge_local_printing_mismatch")
        official_record = cards_by_id.get(card_id)
        if official_record is None:
            _fail("bridge_official_card_unknown")
        printing = official_record["exact_english_printing_or_null"]
        if printing is None:
            _fail("bridge_official_printing_unavailable")
        if (
            source_tree.get("set_code_en") != printing["expansion"]
            or source_tree.get("card_index_en") != printing["collection_no"]
        ):
            _fail("bridge_official_printing_mismatch")
        attack_map = spec["local_attack_index_to_official_attack_id"]
        if [attack_map[str(index)] for index in range(len(attack_map))] != official_record[
            "ordered_official_attack_ids"
        ]:
            _fail("attack_map_incomplete")
        if type(source_tree.get("attacks")) is not list or len(source_tree["attacks"]) != len(attack_map):
            _fail("attack_map_incomplete")
        entries.append(
            {
                "official_card_id": card_id,
                "local_printing": deepcopy(local),
                "source_root_id": "ptcgdap",
                "source_file": spec["source_file"],
                "source_bytes": len(source_bytes),
                "source_raw_sha256": spec["source_raw_sha256"],
                "source_canonical_json_v1_sha256": canonical_hash,
                "local_attack_index_to_official_attack_id": deepcopy(attack_map),
            }
        )
        local_input_records.append(
            {
                "id": f"local_exact_printing_{key[0]}_{key[1]}",
                "root_id": "ptcgdap",
                "path": spec["source_file"],
                "role": "reviewed_exact_local_printing_source",
                "bytes": len(source_bytes),
                "raw_sha256": spec["source_raw_sha256"],
                "canonical_json_v1_sha256": canonical_hash,
            }
        )

    official_counts = Counter(official_deck)
    local_counts = {
        (entry["set_code"], entry["card_index"]): entry["count"]
        for entry in local_deck["cards"]
        if type(entry) is dict
        and type(entry.get("set_code")) is str
        and type(entry.get("card_index")) is str
        and type(entry.get("count")) is int
    }
    bridge_ids = {entry["official_card_id"] for entry in entries}
    bridge_keys = {
        (entry["local_printing"]["set_code"], entry["local_printing"]["card_index"])
        for entry in entries
    }
    scope = {
        "entry_count": len(entries),
        "official_marnie_unique_card_id_count": len(official_counts),
        "official_marnie_bridge_unique_card_id_count": len(bridge_ids & set(official_counts)),
        "official_marnie_bridge_card_count": sum(
            count for card_id, count in official_counts.items() if card_id in bridge_ids
        ),
        "official_marnie_unmapped_card_ids": sorted(set(official_counts) - bridge_ids),
        "local_800018501_bridge_unique_printing_count": len(bridge_keys & set(local_counts)),
        "local_800018501_bridge_card_count": sum(
            count for key, count in local_counts.items() if key in bridge_keys
        ),
        "local_800018501_cabt_exportable": False,
        "inference_policy": "denied_exact_entries_only",
    }
    if (
        scope["entry_count"] != 9
        or scope["official_marnie_unique_card_id_count"] != 19
        or scope["official_marnie_bridge_unique_card_id_count"] != 9
        or scope["official_marnie_bridge_card_count"] != 34
        or scope["local_800018501_bridge_unique_printing_count"] != 4
        or scope["local_800018501_bridge_card_count"] != 15
        or len(scope["official_marnie_unmapped_card_ids"]) != 10
    ):
        _fail("bridge_scope_mismatch")
    return (
        {
            "schema_version": CATALOG_SCHEMA_VERSION,
            "artifact_id": EXACT_BRIDGE_ID,
            "source_manifest_id": SOURCE_MANIFEST_ID,
            "bridge_scope": scope,
            "entries": entries,
        },
        local_input_records,
    )


def _build_schema() -> dict[str, Any]:
    safe_integer = {
        "type": "integer",
        "minimum": -MAX_SAFE_INTEGER,
        "maximum": MAX_SAFE_INTEGER,
    }
    positive_integer = {
        "allOf": [
            {"$ref": "#/$defs/safe_integer"},
            {"minimum": 1},
        ]
    }
    sha256 = {"type": "string", "pattern": "^[0-9A-F]{64}$"}
    printing = {
        "type": "object",
        "additionalProperties": False,
        "required": ["expansion", "collection_no"],
        "properties": {
            "expansion": {"type": "string", "minLength": 1},
            "collection_no": {"type": "string", "minLength": 1},
        },
    }
    return {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "https://ptcgdap.local/contracts/card_id_catalog.schema.json",
        "title": "PtcgDAP source-locked Card/Attack identity catalog artifacts",
        "schema_version": CATALOG_SCHEMA_VERSION,
        "unevaluatedProperties": False,
        "$defs": {
            "safe_integer": safe_integer,
            "positive_integer": positive_integer,
            "sha256": sha256,
            "printing": printing,
            "local_printing": {
                "type": "object",
                "additionalProperties": False,
                "required": ["set_code", "card_index"],
                "properties": {
                    "set_code": {"type": "string", "minLength": 1},
                    "card_index": {"type": "string", "minLength": 1},
                },
            },
            "result": {
                "type": "object",
                "additionalProperties": False,
                "required": ["ok", "error_code", "value"],
                "properties": {
                    "ok": {"type": "boolean"},
                    "error_code": {"type": ["string", "null"]},
                    "value": {},
                },
            },
        },
        "oneOf": [
            {"$ref": "#/$defs/official_master"},
            {"$ref": "#/$defs/exact_bridge"},
            {"$ref": "#/$defs/source_manifest"},
            {"$ref": "#/$defs/catalog_bundle"},
            {"$ref": "#/$defs/conformance_vectors"},
        ],
    }


def _schema_with_artifact_defs(schema: dict[str, Any]) -> dict[str, Any]:
    positive = {"$ref": "#/$defs/positive_integer"}
    nonnegative = {
        "allOf": [
            {"$ref": "#/$defs/safe_integer"},
            {"minimum": 0},
        ]
    }
    source_input = {
        "type": "object",
        "additionalProperties": False,
        "required": ["id", "root_id", "path", "role", "bytes", "raw_sha256"],
        "properties": {
            "id": {"type": "string", "minLength": 1},
            "root_id": {"enum": ["official_bundle", "ptcgabc", "ptcgdap"]},
            "path": {
                "type": "string",
                "minLength": 1,
                "pattern": "^(?!/)(?!.*\\\\)(?!.*(?:^|/)\\.\\.(?:/|$)).+$",
            },
            "role": {"type": "string", "minLength": 1},
            "bytes": nonnegative,
            "raw_sha256": {"$ref": "#/$defs/sha256"},
            "canonical_json_v1_sha256": {"$ref": "#/$defs/sha256"},
        },
        "allOf": [
            {
                "if": {
                    "required": ["root_id"],
                    "properties": {"root_id": {"const": "ptcgdap"}},
                },
                "then": {"required": ["canonical_json_v1_sha256"]},
            }
        ],
    }
    artifact_reference = {
        "type": "object",
        "additionalProperties": False,
        "required": ["path", "canonical_sha256"],
        "properties": {
            "path": {"type": "string", "minLength": 1},
            "canonical_sha256": {"$ref": "#/$defs/sha256"},
        },
    }
    host_integer_input = {
        "oneOf": [
            {"$ref": "#/$defs/safe_integer"},
            {
                "type": "object",
                "additionalProperties": False,
                "required": ["host_type", "value"],
                "properties": {
                    "host_type": {"const": "bool"},
                    "value": {"type": "boolean"},
                },
            },
            {
                "type": "object",
                "additionalProperties": False,
                "required": ["host_type", "decimal"],
                "properties": {
                    "host_type": {"const": "unsafe_integer"},
                    "decimal": {
                        "type": "string",
                        "pattern": "^-?(0|[1-9][0-9]*)$",
                    },
                },
            },
        ]
    }
    host_string_input = {
        "oneOf": [
            {"type": "string"},
            {
                "type": "object",
                "additionalProperties": False,
                "required": ["host_type", "value"],
                "properties": {
                    "host_type": {"const": "integer"},
                    "value": {"$ref": "#/$defs/safe_integer"},
                },
            },
        ]
    }
    local_printing_host_input = {
        "type": "object",
        "additionalProperties": False,
        "required": ["set_code", "card_index"],
        "properties": {
            "set_code": host_string_input,
            "card_index": host_string_input,
        },
    }
    local_printing_input = {
        "type": "object",
        "additionalProperties": False,
        "required": ["local_printing"],
        "properties": {
            "local_printing": local_printing_host_input,
        },
    }
    exact_integer_input = lambda field: {
        "type": "object",
        "additionalProperties": False,
        "required": [field],
        "properties": {field: host_integer_input},
    }
    failure_result = {
        "type": "object",
        "additionalProperties": False,
        "required": ["ok", "error_code", "value"],
        "properties": {
            "ok": {"const": False},
            "error_code": {"enum": STABLE_ERROR_CODES},
            "value": {"type": "null"},
        },
    }

    def operation_result(value_schema: Mapping[str, Any]) -> dict[str, Any]:
        return {
            "oneOf": [
                {
                    "type": "object",
                    "additionalProperties": False,
                    "required": ["ok", "error_code", "value"],
                    "properties": {
                        "ok": {"const": True},
                        "error_code": {"type": "null"},
                        "value": deepcopy(value_schema),
                    },
                },
                {"$ref": "#/$defs/failure_result"},
            ]
        }

    schema["$defs"].update(
        {
            "failure_result": failure_result,
            "result": {
                "oneOf": [
                    {
                        "type": "object",
                        "additionalProperties": False,
                        "required": ["ok", "error_code", "value"],
                        "properties": {
                            "ok": {"const": True},
                            "error_code": {"type": "null"},
                            "value": {},
                        },
                    },
                    {"$ref": "#/$defs/failure_result"},
                ]
            },
            "official_card_record": {
                "type": "object",
                "additionalProperties": False,
                "required": [
                    "official_card_id",
                    "exact_english_printing_or_null",
                    "ordered_official_attack_ids",
                ],
                "properties": {
                    "official_card_id": positive,
                    "exact_english_printing_or_null": {
                        "oneOf": [
                            {"type": "null"},
                            {"$ref": "#/$defs/printing"},
                        ]
                    },
                    "ordered_official_attack_ids": {
                        "type": "array",
                        "items": positive,
                        "uniqueItems": True,
                    },
                },
            },
            "official_attack_record": {
                "type": "object",
                "additionalProperties": False,
                "required": [
                    "official_attack_id",
                    "owner_official_card_id",
                    "owner_attack_ordinal",
                ],
                "properties": {
                    "official_attack_id": positive,
                    "owner_official_card_id": positive,
                    "owner_attack_ordinal": nonnegative,
                },
            },
            "local_lookup_value": {
                "type": "object",
                "additionalProperties": False,
                "required": [
                    "official_card_id",
                    "local_printing",
                    "source_canonical_json_v1_sha256",
                    "local_attack_index_to_official_attack_id",
                ],
                "properties": {
                    "official_card_id": positive,
                    "local_printing": {"$ref": "#/$defs/local_printing"},
                    "source_canonical_json_v1_sha256": {
                        "$ref": "#/$defs/sha256"
                    },
                    "local_attack_index_to_official_attack_id": {
                        "type": "object",
                        "patternProperties": {
                            "^(0|[1-9][0-9]*)$": positive,
                        },
                        "additionalProperties": False,
                    },
                },
            },
            "reverse_local_lookup_value": {
                "type": "object",
                "additionalProperties": False,
                "required": [
                    "official_card_id",
                    "local_printing",
                    "source_canonical_json_v1_sha256",
                ],
                "properties": {
                    "official_card_id": positive,
                    "local_printing": {"$ref": "#/$defs/local_printing"},
                    "source_canonical_json_v1_sha256": {
                        "$ref": "#/$defs/sha256"
                    },
                },
            },
            "local_attack_lookup_value": {
                "type": "object",
                "additionalProperties": False,
                "required": [
                    "official_card_id",
                    "official_attack_id",
                    "owner_attack_ordinal",
                ],
                "properties": {
                    "official_card_id": positive,
                    "official_attack_id": positive,
                    "owner_attack_ordinal": nonnegative,
                },
            },
            "master_source_evidence": {
                "type": "object",
                "additionalProperties": False,
                "required": [
                    "current_official_card_count",
                    "current_official_attack_count",
                    "english_csv_data_row_count",
                    "printing_null_official_card_ids",
                    "id_range_semantics",
                ],
                "properties": {
                    "current_official_card_count": positive,
                    "current_official_attack_count": positive,
                    "english_csv_data_row_count": positive,
                    "printing_null_official_card_ids": {
                        "type": "array",
                        "items": positive,
                        "uniqueItems": True,
                    },
                    "id_range_semantics": {
                        "const": "observed_current_source_evidence_only_not_a_future_dense_id_contract"
                    },
                },
            },
            "official_master": {
                "type": "object",
                "additionalProperties": False,
                "required": [
                    "schema_version",
                    "artifact_id",
                    "source_manifest_id",
                    "cards",
                    "attacks",
                    "source_evidence",
                ],
                "properties": {
                    "schema_version": {"const": 1},
                    "artifact_id": {"const": OFFICIAL_MASTER_ID},
                    "source_manifest_id": {"const": SOURCE_MANIFEST_ID},
                    "cards": {
                        "type": "array",
                        "minItems": EXPECTED_CARD_COUNT,
                        "maxItems": EXPECTED_CARD_COUNT,
                        "items": {"$ref": "#/$defs/official_card_record"},
                        "uniqueItems": True,
                    },
                    "attacks": {
                        "type": "array",
                        "minItems": EXPECTED_ATTACK_COUNT,
                        "maxItems": EXPECTED_ATTACK_COUNT,
                        "items": {"$ref": "#/$defs/official_attack_record"},
                        "uniqueItems": True,
                    },
                    "source_evidence": {"$ref": "#/$defs/master_source_evidence"},
                },
            },
            "bridge_scope": {
                "type": "object",
                "additionalProperties": False,
                "required": [
                    "entry_count",
                    "official_marnie_unique_card_id_count",
                    "official_marnie_bridge_unique_card_id_count",
                    "official_marnie_bridge_card_count",
                    "official_marnie_unmapped_card_ids",
                    "local_800018501_bridge_unique_printing_count",
                    "local_800018501_bridge_card_count",
                    "local_800018501_cabt_exportable",
                    "inference_policy",
                ],
                "properties": {
                    "entry_count": nonnegative,
                    "official_marnie_unique_card_id_count": nonnegative,
                    "official_marnie_bridge_unique_card_id_count": nonnegative,
                    "official_marnie_bridge_card_count": nonnegative,
                    "official_marnie_unmapped_card_ids": {
                        "type": "array",
                        "items": positive,
                        "uniqueItems": True,
                    },
                    "local_800018501_bridge_unique_printing_count": nonnegative,
                    "local_800018501_bridge_card_count": nonnegative,
                    "local_800018501_cabt_exportable": {"const": False},
                    "inference_policy": {"const": "denied_exact_entries_only"},
                },
            },
            "bridge_entry": {
                "type": "object",
                "additionalProperties": False,
                "required": [
                    "official_card_id",
                    "local_printing",
                    "source_root_id",
                    "source_file",
                    "source_bytes",
                    "source_raw_sha256",
                    "source_canonical_json_v1_sha256",
                    "local_attack_index_to_official_attack_id",
                ],
                "properties": {
                    "official_card_id": positive,
                    "local_printing": {"$ref": "#/$defs/local_printing"},
                    "source_root_id": {"const": "ptcgdap"},
                    "source_file": {"type": "string", "minLength": 1},
                    "source_bytes": positive,
                    "source_raw_sha256": {"$ref": "#/$defs/sha256"},
                    "source_canonical_json_v1_sha256": {"$ref": "#/$defs/sha256"},
                    "local_attack_index_to_official_attack_id": {
                        "type": "object",
                        "patternProperties": {
                            "^(0|[1-9][0-9]*)$": positive,
                        },
                        "additionalProperties": False,
                    },
                },
            },
            "exact_bridge": {
                "type": "object",
                "additionalProperties": False,
                "required": ["schema_version", "artifact_id", "source_manifest_id", "bridge_scope", "entries"],
                "properties": {
                    "schema_version": {"const": 1},
                    "artifact_id": {"const": EXACT_BRIDGE_ID},
                    "source_manifest_id": {"const": SOURCE_MANIFEST_ID},
                    "bridge_scope": {"$ref": "#/$defs/bridge_scope"},
                    "entries": {
                        "type": "array",
                        "minItems": 9,
                        "maxItems": 9,
                        "items": {"$ref": "#/$defs/bridge_entry"},
                        "uniqueItems": True,
                    },
                },
            },
            "source_input": source_input,
            "native_snapshot_fact": {
                "type": "object",
                "additionalProperties": False,
                "required": [
                    "producer_input_ids",
                    "api_symbol",
                    "bytes",
                    "raw_sha256",
                    "record_count",
                ],
                "properties": {
                    "producer_input_ids": {
                        "type": "array",
                        "minItems": 1,
                        "items": {"type": "string", "minLength": 1},
                        "uniqueItems": True,
                    },
                    "api_symbol": {"enum": ["AllCard", "AllAttack"]},
                    "bytes": positive,
                    "raw_sha256": {"$ref": "#/$defs/sha256"},
                    "record_count": positive,
                },
            },
            "source_manifest": {
                "type": "object",
                "additionalProperties": False,
                "required": ["schema_version", "artifact_id", "source_lock", "official_bundle", "inputs", "derived_source_facts", "derived_artifacts"],
                "properties": {
                    "schema_version": {"const": 1},
                    "artifact_id": {"const": SOURCE_MANIFEST_ID},
                    "source_lock": {
                        "type": "object",
                        "additionalProperties": False,
                        "required": ["lock_id", "canonical_sha256"],
                        "properties": {
                            "lock_id": {"type": "string", "minLength": 1},
                            "canonical_sha256": {"$ref": "#/$defs/sha256"},
                        },
                    },
                    "official_bundle": {
                        "type": "object",
                        "additionalProperties": False,
                        "required": ["manifest_path", "manifest_raw_sha256", "file_count", "total_bytes", "role"],
                        "properties": {
                            "manifest_path": {"type": "string", "minLength": 1},
                            "manifest_raw_sha256": {"$ref": "#/$defs/sha256"},
                            "file_count": positive,
                            "total_bytes": positive,
                            "role": {"const": "read_only_development_oracle_not_runtime_payload"},
                        },
                    },
                    "inputs": {
                        "type": "array",
                        "minItems": 17,
                        "maxItems": 17,
                        "items": {"$ref": "#/$defs/source_input"},
                        "uniqueItems": True,
                    },
                    "derived_source_facts": {
                        "type": "object",
                        "additionalProperties": False,
                        "required": ["all_card_json", "all_attack_json", "attack_owner_derivation", "ability_numeric_identity", "native_snapshot_platform"],
                        "properties": {
                            "all_card_json": {"$ref": "#/$defs/native_snapshot_fact"},
                            "all_attack_json": {"$ref": "#/$defs/native_snapshot_fact"},
                            "attack_owner_derivation": {"type": "string", "minLength": 1},
                            "ability_numeric_identity": {"const": "not_available_no_id_in_official_skill_payload"},
                            "native_snapshot_platform": {"const": "Windows x86_64 development oracle only"},
                        },
                    },
                    "derived_artifacts": {
                        "type": "object",
                        "additionalProperties": False,
                        "required": ["official_master", "exact_bridge"],
                        "properties": {
                            "official_master": artifact_reference,
                            "exact_bridge": artifact_reference,
                        },
                    },
                },
            },
            "bundle_artifact": {
                "oneOf": [
                    {
                        "type": "object",
                        "additionalProperties": False,
                        "required": ["id", "path", "canonical_sha256"],
                        "properties": {
                            "id": {"const": artifact_id},
                            "path": {"const": ARTIFACT_PATHS[artifact_id]},
                            "canonical_sha256": {"$ref": "#/$defs/sha256"},
                        },
                    }
                    for artifact_id in (
                        "schema",
                        "source_manifest",
                        "official_master",
                        "exact_bridge",
                        "conformance_vectors",
                    )
                ]
            },
            "catalog_bundle": {
                "type": "object",
                "additionalProperties": False,
                "required": ["schema_version", "artifact_id", "digest_mode", "artifact_set_policy", "source_lock_canonical_sha256", "parent_p1_contract", "parent_p2_wp1", "artifacts"],
                "properties": {
                    "schema_version": {"const": 1},
                    "artifact_id": {"const": CATALOG_BUNDLE_ID},
                    "digest_mode": {"const": "canonical_json_v1"},
                    "artifact_set_policy": {"const": "exact_ids_and_paths_no_duplicates"},
                    "source_lock_canonical_sha256": {"$ref": "#/$defs/sha256"},
                    "parent_p1_contract": {
                        "type": "object",
                        "additionalProperties": False,
                        "required": ["contract_id", "canonical_sha256"],
                        "properties": {
                            "contract_id": {"const": "ptcgdap-cabt-contract-p1-wp3-v1"},
                            "canonical_sha256": {"$ref": "#/$defs/sha256"},
                        },
                    },
                    "parent_p2_wp1": {
                        "type": "object",
                        "additionalProperties": False,
                        "required": ["work_package", "manifest_path", "manifest_raw_sha256", "manifest_canonical_sha256"],
                        "properties": {
                            "work_package": {"const": "P2-WP1"},
                            "manifest_path": {"const": "artifacts/ptcgdap/p2_wp1/manifest.json"},
                            "manifest_raw_sha256": {"$ref": "#/$defs/sha256"},
                            "manifest_canonical_sha256": {"$ref": "#/$defs/sha256"},
                        },
                    },
                    "artifacts": {
                        "type": "array",
                        "minItems": 5,
                        "maxItems": 5,
                        "items": {"$ref": "#/$defs/bundle_artifact"},
                        "uniqueItems": True,
                        "allOf": [
                            {
                                "contains": {
                                    "type": "object",
                                    "required": ["id"],
                                    "properties": {"id": {"const": artifact_id}},
                                },
                                "minContains": 1,
                                "maxContains": 1,
                            }
                            for artifact_id in (
                                "schema",
                                "source_manifest",
                                "official_master",
                                "exact_bridge",
                                "conformance_vectors",
                            )
                        ],
                    },
                },
            },
            "vector_case": {
                "allOf": [
                    {
                        "type": "object",
                        "additionalProperties": False,
                        "required": ["id", "operation", "input", "expected"],
                        "properties": {
                            "id": {"type": "string", "minLength": 1},
                            "operation": {
                                "enum": [
                                    "lookup_official_card",
                                    "lookup_official_attack",
                                    "lookup_official_printing",
                                    "lookup_local_printing",
                                    "lookup_local_printing_for_official_card",
                                    "lookup_local_attack",
                                    "validate_local_source",
                                    "artifact_canonical_sha256",
                                ]
                            },
                            "input": {"type": "object"},
                            "expected": {"$ref": "#/$defs/result"},
                        },
                    },
                    {
                        "oneOf": [
                            {
                                "properties": {
                                    "operation": {"const": "lookup_official_card"},
                                    "input": exact_integer_input("official_card_id"),
                                    "expected": operation_result(
                                        {"$ref": "#/$defs/official_card_record"}
                                    ),
                                }
                            },
                            {
                                "properties": {
                                    "operation": {
                                        "const": "lookup_official_printing"
                                    },
                                    "input": exact_integer_input("official_card_id"),
                                    "expected": operation_result(
                                        {"$ref": "#/$defs/printing"}
                                    ),
                                }
                            },
                            {
                                "properties": {
                                    "operation": {
                                        "const": "lookup_local_printing_for_official_card"
                                    },
                                    "input": exact_integer_input("official_card_id"),
                                    "expected": operation_result(
                                        {
                                            "$ref": "#/$defs/reverse_local_lookup_value"
                                        }
                                    ),
                                }
                            },
                            {
                                "properties": {
                                    "operation": {"const": "lookup_official_attack"},
                                    "input": exact_integer_input("official_attack_id"),
                                    "expected": operation_result(
                                        {"$ref": "#/$defs/official_attack_record"}
                                    ),
                                }
                            },
                            {
                                "properties": {
                                    "operation": {"const": "lookup_local_printing"},
                                    "input": local_printing_input,
                                    "expected": operation_result(
                                        {"$ref": "#/$defs/local_lookup_value"}
                                    ),
                                }
                            },
                            {
                                "properties": {
                                    "operation": {"const": "lookup_local_attack"},
                                    "input": {
                                        "type": "object",
                                        "additionalProperties": False,
                                        "required": [
                                            "local_printing",
                                            "local_attack_index",
                                        ],
                                        "properties": {
                                            "local_printing": local_printing_host_input,
                                            "local_attack_index": host_integer_input,
                                        },
                                    },
                                    "expected": operation_result(
                                        {
                                            "$ref": "#/$defs/local_attack_lookup_value"
                                        }
                                    ),
                                }
                            },
                            {
                                "properties": {
                                    "operation": {"const": "validate_local_source"},
                                    "input": {
                                        "oneOf": [
                                            {
                                                "type": "object",
                                                "additionalProperties": False,
                                                "required": [
                                                    "local_printing",
                                                    "source_file",
                                                    "materialization",
                                                ],
                                                "properties": {
                                                    "local_printing": {
                                                        "$ref": "#/$defs/local_printing"
                                                    },
                                                    "source_file": {
                                                        "type": "string",
                                                        "minLength": 1,
                                                    },
                                                    "materialization": {
                                                        "const": "bytes"
                                                    },
                                                },
                                            },
                                            {
                                                "type": "object",
                                                "additionalProperties": False,
                                                "required": [
                                                    "local_printing",
                                                    "source_file",
                                                    "materialization",
                                                    "mutation",
                                                ],
                                                "properties": {
                                                    "local_printing": {
                                                        "$ref": "#/$defs/local_printing"
                                                    },
                                                    "source_file": {
                                                        "type": "string",
                                                        "minLength": 1,
                                                    },
                                                    "materialization": {
                                                        "const": "mutated_tree"
                                                    },
                                                    "mutation": {
                                                        "type": "object",
                                                        "additionalProperties": False,
                                                        "required": ["field", "value"],
                                                        "properties": {
                                                            "field": {
                                                                "const": "card_index"
                                                            },
                                                            "value": {
                                                                "const": "__PTCGDAP_DRIFT__"
                                                            },
                                                        },
                                                    },
                                                },
                                            },
                                        ]
                                    },
                                    "expected": operation_result({"const": True}),
                                }
                            },
                            {
                                "properties": {
                                    "operation": {
                                        "const": "artifact_canonical_sha256"
                                    },
                                    "input": {
                                        "type": "object",
                                        "additionalProperties": False,
                                        "required": ["artifact_id"],
                                        "properties": {
                                            "artifact_id": {
                                                "enum": [
                                                    "schema",
                                                    "source_manifest",
                                                    "official_master",
                                                    "exact_bridge",
                                                ]
                                            }
                                        },
                                    },
                                    "expected": operation_result(
                                        {"$ref": "#/$defs/sha256"}
                                    ),
                                }
                            },
                        ]
                    },
                ]
            },
            "conformance_vectors": {
                "type": "object",
                "additionalProperties": False,
                "required": ["schema_version", "artifact_id", "result_contract", "stable_error_codes", "vectors"],
                "properties": {
                    "schema_version": {"const": 1},
                    "artifact_id": {"const": CONFORMANCE_VECTORS_ID},
                    "result_contract": {
                        "type": "object",
                        "additionalProperties": False,
                        "required": ["fields_in_order", "success", "failure", "copy_only", "rejected_value_echo"],
                        "properties": {
                            "fields_in_order": {"const": ["ok", "error_code", "value"]},
                            "success": {
                                "const": {"ok": True, "error_code": None}
                            },
                            "failure": {
                                "const": {"ok": False, "value": None}
                            },
                            "copy_only": {"const": True},
                            "rejected_value_echo": {"const": "forbidden"},
                        },
                    },
                    "stable_error_codes": {"const": STABLE_ERROR_CODES},
                    "vectors": {
                        "type": "array",
                        "minItems": 104,
                        "maxItems": 104,
                        "items": {"$ref": "#/$defs/vector_case"},
                        "uniqueItems": True,
                    },
                },
            },
        }
    )
    return schema


def _input_record(
    *,
    input_id: str,
    root_id: str,
    path: str,
    role: str,
    data: bytes,
    canonical_sha256: str | None = None,
) -> dict[str, Any]:
    record: dict[str, Any] = {
        "id": input_id,
        "root_id": root_id,
        "path": path,
        "role": role,
        "bytes": len(data),
        "raw_sha256": sha256_bytes(data),
    }
    if canonical_sha256 is not None:
        record["canonical_json_v1_sha256"] = canonical_sha256
    return record


def _build_source_manifest(
    *,
    official_bundle_manifest: Mapping[str, Any],
    official_input_records: list[dict[str, Any]],
    local_input_records: list[dict[str, Any]],
    official_deck_record: dict[str, Any],
    local_deck_record: dict[str, Any],
    master: Mapping[str, Any],
    bridge: Mapping[str, Any],
) -> dict[str, Any]:
    return {
        "schema_version": CATALOG_SCHEMA_VERSION,
        "artifact_id": SOURCE_MANIFEST_ID,
        "source_lock": {
            "lock_id": "ptcgdap-source-lock-2026-08-09-p1wp1",
            "canonical_sha256": SOURCE_LOCK_CANONICAL_SHA256,
        },
        "official_bundle": {
            "manifest_path": "official_data/kaggle_bundle/competition_files.sha256.json",
            "manifest_raw_sha256": OFFICIAL_BUNDLE_MANIFEST_RAW_SHA256,
            "file_count": official_bundle_manifest["file_count"],
            "total_bytes": official_bundle_manifest["total_bytes"],
            "role": "read_only_development_oracle_not_runtime_payload",
        },
        "inputs": [
            *official_input_records,
            official_deck_record,
            local_deck_record,
            *local_input_records,
        ],
        "derived_source_facts": {
            "all_card_json": {
                "producer_input_ids": [
                    "official_cg_api_py",
                    "official_cg_sim_py",
                    "official_cg_dll",
                ],
                "api_symbol": "AllCard",
                "bytes": ALL_CARD_BYTES,
                "raw_sha256": ALL_CARD_RAW_SHA256,
                "record_count": EXPECTED_CARD_COUNT,
            },
            "all_attack_json": {
                "producer_input_ids": [
                    "official_cg_api_py",
                    "official_cg_sim_py",
                    "official_cg_dll",
                ],
                "api_symbol": "AllAttack",
                "bytes": ALL_ATTACK_BYTES,
                "raw_sha256": ALL_ATTACK_RAW_SHA256,
                "record_count": EXPECTED_ATTACK_COUNT,
            },
            "attack_owner_derivation": "unique ordered membership in AllCard.attacks, cross-checked against the complete AllAttack attackId set",
            "ability_numeric_identity": "not_available_no_id_in_official_skill_payload",
            "native_snapshot_platform": "Windows x86_64 development oracle only",
        },
        "derived_artifacts": {
            "official_master": {
                "path": ARTIFACT_PATHS["official_master"],
                "canonical_sha256": sha256_bytes(canonical_json_v1_bytes(master)),
            },
            "exact_bridge": {
                "path": ARTIFACT_PATHS["exact_bridge"],
                "canonical_sha256": sha256_bytes(canonical_json_v1_bytes(bridge)),
            },
        },
    }


def _success(value: Any) -> dict[str, Any]:
    return {"ok": True, "error_code": None, "value": deepcopy(value)}


def _error(code: str) -> dict[str, Any]:
    return {"ok": False, "error_code": code, "value": None}


def _build_vectors(
    master: Mapping[str, Any],
    bridge: Mapping[str, Any],
    artifact_hashes: Mapping[str, str],
) -> dict[str, Any]:
    cards = {record["official_card_id"]: record for record in master["cards"]}
    attacks = {record["official_attack_id"]: record for record in master["attacks"]}
    entries = {
        (entry["local_printing"]["set_code"], entry["local_printing"]["card_index"]): entry
        for entry in bridge["entries"]
    }
    vectors: list[dict[str, Any]] = []

    def add(vector_id: str, operation: str, input_value: Any, expected: dict[str, Any]) -> None:
        vectors.append(
            {
                "id": vector_id,
                "operation": operation,
                "input": deepcopy(input_value),
                "expected": deepcopy(expected),
            }
        )

    for card_id in (7, 103, 104, 112, 646, 647, 648, 860, 1080, 1097, 1259):
        add(
            f"official-card-{card_id}",
            "lookup_official_card",
            {"official_card_id": card_id},
            _success(cards[card_id]),
        )
    add("official-card-unknown", "lookup_official_card", {"official_card_id": 1268}, _error("official_card_unknown"))
    add("official-card-bool", "lookup_official_card", {"official_card_id": {"host_type": "bool", "value": True}}, _error("input_type_invalid"))
    add("official-card-unsafe", "lookup_official_card", {"official_card_id": {"host_type": "unsafe_integer", "decimal": "9007199254740992"}}, _error("input_type_invalid"))
    for card_id in EXPECTED_NULL_PRINTINGS:
        add(
            f"official-card-printing-null-{card_id}",
            "lookup_official_card",
            {"official_card_id": card_id},
            _success(cards[card_id]),
        )

    for attack_id in (130, 131, 141, 934, 935, 1239):
        add(
            f"official-attack-{attack_id}",
            "lookup_official_attack",
            {"official_attack_id": attack_id},
            _success(attacks[attack_id]),
        )
    add("official-attack-unknown", "lookup_official_attack", {"official_attack_id": 1557}, _error("official_attack_unknown"))

    for key in sorted(entries):
        entry = entries[key]
        value = {
            "official_card_id": entry["official_card_id"],
            "local_printing": deepcopy(entry["local_printing"]),
            "source_canonical_json_v1_sha256": entry["source_canonical_json_v1_sha256"],
            "local_attack_index_to_official_attack_id": deepcopy(entry["local_attack_index_to_official_attack_id"]),
        }
        add(
            f"local-printing-{key[0]}-{key[1]}",
            "lookup_local_printing",
            {"local_printing": {"set_code": key[0], "card_index": key[1]}},
            _success(value),
        )
    for vector_id, local in (
        ("local-printing-case", {"set_code": "csv7c", "card_index": "059"}),
        ("local-printing-space", {"set_code": "CSV7C ", "card_index": "059"}),
        ("local-printing-leading-zero", {"set_code": "CSV7C", "card_index": "0059"}),
        ("local-printing-snorunt-no-name-guess", {"set_code": "CSV9.5C", "card_index": "043"}),
        ("local-printing-csv10c-alias-denied", {"set_code": "CSV10C", "card_index": "146"}),
    ):
        add(vector_id, "lookup_local_printing", {"local_printing": local}, _error("local_printing_unmapped"))
    add(
        "local-printing-type",
        "lookup_local_printing",
        {
            "local_printing": {
                "set_code": "CSV7C",
                "card_index": {"host_type": "integer", "value": 59},
            }
        },
        _error("input_type_invalid"),
    )

    for (set_code, card_index), entry in sorted(entries.items()):
        for raw_local_index, attack_id in sorted(
            entry["local_attack_index_to_official_attack_id"].items(),
            key=lambda item: int(item[0]),
        ):
            local_index = int(raw_local_index)
            add(
                f"local-attack-{set_code}-{card_index}-{local_index}",
                "lookup_local_attack",
                {
                    "local_printing": {
                        "set_code": set_code,
                        "card_index": card_index,
                    },
                    "local_attack_index": local_index,
                },
                _success(
                    {
                        "official_card_id": entry["official_card_id"],
                        "official_attack_id": attack_id,
                        "owner_attack_ordinal": attacks[attack_id]["owner_attack_ordinal"],
                    }
                ),
            )
    add("local-attack-oob", "lookup_local_attack", {"local_printing": {"set_code": "CSV7C", "card_index": "059"}, "local_attack_index": 1}, _error("attack_unmapped"))
    add("local-attack-unmapped-card", "lookup_local_attack", {"local_printing": {"set_code": "CSV9.5C", "card_index": "043"}, "local_attack_index": 0}, _error("local_printing_unmapped"))
    add("local-attack-bool", "lookup_local_attack", {"local_printing": {"set_code": "CSV7C", "card_index": "059"}, "local_attack_index": {"host_type": "bool", "value": True}}, _error("input_type_invalid"))

    mapped_by_id = {entry["official_card_id"]: entry for entry in bridge["entries"]}
    for card_id in sorted(mapped_by_id):
        entry = mapped_by_id[card_id]
        add(
            f"mapped-official-{card_id}",
            "lookup_local_printing_for_official_card",
            {"official_card_id": card_id},
            _success(
                {
                    "official_card_id": card_id,
                    "local_printing": deepcopy(entry["local_printing"]),
                    "source_canonical_json_v1_sha256": entry["source_canonical_json_v1_sha256"],
                }
            ),
        )
    for card_id in bridge["bridge_scope"]["official_marnie_unmapped_card_ids"]:
        add(
            f"known-official-unmapped-{card_id}",
            "lookup_local_printing_for_official_card",
            {"official_card_id": card_id},
            _error("official_card_unmapped"),
        )
    add("unknown-official-unmapped", "lookup_local_printing_for_official_card", {"official_card_id": 1268}, _error("official_card_unknown"))
    add(
        "official-printing-104",
        "lookup_official_printing",
        {"official_card_id": 104},
        _success(cards[104]["exact_english_printing_or_null"]),
    )
    for card_id in EXPECTED_NULL_PRINTINGS:
        add(
            f"official-printing-unavailable-{card_id}",
            "lookup_official_printing",
            {"official_card_id": card_id},
            _error("official_printing_unavailable"),
        )

    for (set_code, card_index), entry in sorted(entries.items()):
        source_descriptor = {
            "local_printing": {
                "set_code": set_code,
                "card_index": card_index,
            },
            "source_file": entry["source_file"],
            "materialization": "bytes",
        }
        add(
            f"validate-local-source-{set_code}-{card_index}-bytes",
            "validate_local_source",
            source_descriptor,
            _success(True),
        )
        mutated_descriptor = deepcopy(source_descriptor)
        mutated_descriptor["materialization"] = "mutated_tree"
        mutated_descriptor["mutation"] = {
            "field": "card_index",
            "value": "__PTCGDAP_DRIFT__",
        }
        add(
            f"validate-local-source-{set_code}-{card_index}-mutated",
            "validate_local_source",
            mutated_descriptor,
            _error("local_source_hash_mismatch"),
        )

    for artifact_id in ("schema", "source_manifest", "official_master", "exact_bridge"):
        add(
            f"artifact-hash-{artifact_id}",
            "artifact_canonical_sha256",
            {"artifact_id": artifact_id},
            _success(artifact_hashes[artifact_id]),
        )

    return {
        "schema_version": CATALOG_SCHEMA_VERSION,
        "artifact_id": CONFORMANCE_VECTORS_ID,
        "result_contract": {
            "fields_in_order": ["ok", "error_code", "value"],
            "success": {"ok": True, "error_code": None},
            "failure": {"ok": False, "value": None},
            "copy_only": True,
            "rejected_value_echo": "forbidden",
        },
        "stable_error_codes": STABLE_ERROR_CODES,
        "vectors": vectors,
    }


def _build_bundle(documents: Mapping[str, Any]) -> dict[str, Any]:
    artifact_ids = ["schema", "source_manifest", "official_master", "exact_bridge", "conformance_vectors"]
    return {
        "schema_version": CATALOG_SCHEMA_VERSION,
        "artifact_id": CATALOG_BUNDLE_ID,
        "digest_mode": "canonical_json_v1",
        "artifact_set_policy": "exact_ids_and_paths_no_duplicates",
        "source_lock_canonical_sha256": SOURCE_LOCK_CANONICAL_SHA256,
        "parent_p1_contract": {
            "contract_id": "ptcgdap-cabt-contract-p1-wp3-v1",
            "canonical_sha256": P1_CONTRACT_CANONICAL_SHA256,
        },
        "parent_p2_wp1": {
            "work_package": "P2-WP1",
            "manifest_path": "artifacts/ptcgdap/p2_wp1/manifest.json",
            "manifest_raw_sha256": P2_WP1_MANIFEST_RAW_SHA256,
            "manifest_canonical_sha256": P2_WP1_MANIFEST_CANONICAL_SHA256,
        },
        "artifacts": [
            {
                "id": artifact_id,
                "path": ARTIFACT_PATHS[artifact_id],
                "canonical_sha256": sha256_bytes(canonical_json_v1_bytes(documents[artifact_id])),
            }
            for artifact_id in artifact_ids
        ],
    }


def build_catalog_documents(repository_root: Path, oracle_root: Path) -> dict[str, Any]:
    repository_root = repository_root.resolve(strict=True)
    oracle_root = oracle_root.resolve(strict=True)

    source_lock_path = _require_file(repository_root, PurePosixPath("docs/ptcgdap/SOURCE_LOCK.json"))
    source_lock = load_json_strict(source_lock_path)
    if sha256_bytes(canonical_json_v1_bytes(source_lock)) != SOURCE_LOCK_CANONICAL_SHA256:
        _fail("source_anchor_mismatch")

    p1_bundle_path = _require_file(repository_root, PurePosixPath("contracts/ptcgdap/cabt_contract_bundle.json"))
    if sha256_bytes(canonical_json_v1_bytes(load_json_strict(p1_bundle_path))) != P1_CONTRACT_CANONICAL_SHA256:
        _fail("source_anchor_mismatch")
    p2_manifest_path = _require_file(repository_root, PurePosixPath("artifacts/ptcgdap/p2_wp1/manifest.json"))
    p2_manifest_bytes = _require_raw_hash(p2_manifest_path, P2_WP1_MANIFEST_RAW_SHA256)
    if sha256_bytes(canonical_json_v1_bytes(load_json_bytes_strict(p2_manifest_bytes))) != P2_WP1_MANIFEST_CANONICAL_SHA256:
        _fail("source_anchor_mismatch")

    official_bundle_root = _require_file(
        oracle_root,
        OFFICIAL_BUNDLE_RELATIVE / PurePosixPath("competition_files.sha256.json"),
    ).parent
    manifest_path = official_bundle_root / "competition_files.sha256.json"
    manifest_bytes = _require_raw_hash(manifest_path, OFFICIAL_BUNDLE_MANIFEST_RAW_SHA256)
    official_bundle_manifest = load_json_bytes_strict(manifest_bytes)
    if (
        type(official_bundle_manifest) is not dict
        or official_bundle_manifest.get("file_count") != 60
        or official_bundle_manifest.get("total_bytes") != 327589562
    ):
        _fail("official_bundle_manifest_invalid")
    manifest_entries = {
        entry.get("name"): entry
        for entry in official_bundle_manifest.get("files", [])
        if type(entry) is dict and type(entry.get("name")) is str
    }

    official_paths: dict[str, Path] = {}
    official_input_records: list[dict[str, Any]] = []
    role_by_id = {
        "official_en_card_data_csv": "official_english_printing_source",
        "official_cg_api_py": "official_native_api_definition",
        "official_cg_sim_py": "official_native_loader_and_GameInitialize_definition",
        "official_cg_dll": "official_native_identity_snapshot_producer",
        "official_api_h": "official_card_attack_master_semantics",
        "official_to_json_h": "official_wire_identity_semantics",
    }
    for input_id, (relative_text, expected_hash) in OFFICIAL_INPUTS.items():
        relative = PurePosixPath(relative_text)
        path = _require_file(official_bundle_root, relative)
        data = _require_raw_hash(path, expected_hash)
        manifest_entry = manifest_entries.get(relative_text)
        if (
            type(manifest_entry) is not dict
            or str(manifest_entry.get("sha256", "")).upper() != expected_hash
            or manifest_entry.get("size") != len(data)
        ):
            _fail("official_bundle_manifest_invalid")
        official_paths[input_id] = path
        official_input_records.append(
            _input_record(
                input_id=input_id,
                root_id="official_bundle",
                path=relative_text,
                role=role_by_id[input_id],
                data=data,
            )
        )

    all_card_bytes, all_attack_bytes = _load_native_snapshots(
        official_paths["official_cg_dll"]
    )
    if len(all_card_bytes) != ALL_CARD_BYTES or sha256_bytes(all_card_bytes) != ALL_CARD_RAW_SHA256:
        _fail("official_native_snapshot_hash_mismatch")
    if len(all_attack_bytes) != ALL_ATTACK_BYTES or sha256_bytes(all_attack_bytes) != ALL_ATTACK_RAW_SHA256:
        _fail("official_native_snapshot_hash_mismatch")
    printings, row_count = _parse_official_printings(official_paths["official_en_card_data_csv"])
    master = _build_official_master(all_card_bytes, all_attack_bytes, printings, row_count)

    official_deck_path = _require_file(oracle_root, OFFICIAL_MARNIE_DECK_RELATIVE)
    official_deck_bytes = _require_raw_hash(official_deck_path, OFFICIAL_MARNIE_DECK_RAW_SHA256)
    official_deck = _load_official_deck(official_deck_path)
    official_deck_record = _input_record(
        input_id="official_marnie_deck",
        root_id="ptcgabc",
        path=OFFICIAL_MARNIE_DECK_RELATIVE.as_posix(),
        role="source_locked_candidate_official_deck",
        data=official_deck_bytes,
    )

    local_deck_path = _require_file(repository_root, LOCAL_DECK_RELATIVE)
    local_deck_bytes = local_deck_path.read_bytes()
    local_deck = _load_local_deck(local_deck_path)
    local_deck_canonical = sha256_bytes(canonical_json_v1_bytes(local_deck))
    if local_deck_canonical != LOCAL_DECK_CANONICAL_SHA256:
        _fail("source_anchor_mismatch")
    local_deck_record = _input_record(
        input_id="local_800018501_deck",
        root_id="ptcgdap",
        path=LOCAL_DECK_RELATIVE.as_posix(),
        role="source_locked_candidate_local_deck_non_exportable",
        data=local_deck_bytes,
        canonical_sha256=local_deck_canonical,
    )

    bridge, local_input_records = _build_exact_bridge(
        repository_root,
        master,
        official_deck,
        local_deck,
    )
    schema = _schema_with_artifact_defs(_build_schema())
    source_manifest = _build_source_manifest(
        official_bundle_manifest=official_bundle_manifest,
        official_input_records=official_input_records,
        local_input_records=local_input_records,
        official_deck_record=official_deck_record,
        local_deck_record=local_deck_record,
        master=master,
        bridge=bridge,
    )
    artifact_hashes = {
        "schema": sha256_bytes(canonical_json_v1_bytes(schema)),
        "source_manifest": sha256_bytes(canonical_json_v1_bytes(source_manifest)),
        "official_master": sha256_bytes(canonical_json_v1_bytes(master)),
        "exact_bridge": sha256_bytes(canonical_json_v1_bytes(bridge)),
    }
    vectors = _build_vectors(master, bridge, artifact_hashes)
    documents: dict[str, Any] = {
        "schema": schema,
        "source_manifest": source_manifest,
        "official_master": master,
        "exact_bridge": bridge,
        "conformance_vectors": vectors,
    }
    documents["bundle"] = _build_bundle(documents)
    validate_catalog_documents(documents)
    return documents


def _require_exact_keys(value: Any, keys: set[str], code: str) -> dict[str, Any]:
    if type(value) is not dict or set(value) != keys:
        _fail(code)
    return value


def _expected_source_manifest(
    master: Mapping[str, Any], bridge: Mapping[str, Any]
) -> dict[str, Any]:
    role_by_id = {
        "official_en_card_data_csv": "official_english_printing_source",
        "official_cg_api_py": "official_native_api_definition",
        "official_cg_sim_py": "official_native_loader_and_GameInitialize_definition",
        "official_cg_dll": "official_native_identity_snapshot_producer",
        "official_api_h": "official_card_attack_master_semantics",
        "official_to_json_h": "official_wire_identity_semantics",
    }
    official_records = [
        {
            "id": input_id,
            "root_id": "official_bundle",
            "path": path,
            "role": role_by_id[input_id],
            "bytes": OFFICIAL_INPUT_BYTES[input_id],
            "raw_sha256": raw_sha256,
        }
        for input_id, (path, raw_sha256) in OFFICIAL_INPUTS.items()
    ]
    official_deck_record = {
        "id": "official_marnie_deck",
        "root_id": "ptcgabc",
        "path": OFFICIAL_MARNIE_DECK_RELATIVE.as_posix(),
        "role": "source_locked_candidate_official_deck",
        "bytes": 312,
        "raw_sha256": OFFICIAL_MARNIE_DECK_RAW_SHA256,
    }
    local_deck_record = {
        "id": "local_800018501_deck",
        "root_id": "ptcgdap",
        "path": LOCAL_DECK_RELATIVE.as_posix(),
        "role": "source_locked_candidate_local_deck_non_exportable",
        "bytes": LOCAL_DECK_BYTES,
        "raw_sha256": LOCAL_DECK_RAW_SHA256,
        "canonical_json_v1_sha256": LOCAL_DECK_CANONICAL_SHA256,
    }
    local_records = [
        {
            "id": (
                "local_exact_printing_"
                f"{spec['local_printing']['set_code']}_"
                f"{spec['local_printing']['card_index']}"
            ),
            "root_id": "ptcgdap",
            "path": spec["source_file"],
            "role": "reviewed_exact_local_printing_source",
            "bytes": LOCAL_SOURCE_BYTES[spec["source_file"]],
            "raw_sha256": spec["source_raw_sha256"],
            "canonical_json_v1_sha256": spec[
                "source_canonical_json_v1_sha256"
            ],
        }
        for spec in BRIDGE_SPECS
    ]
    return _build_source_manifest(
        official_bundle_manifest={"file_count": 60, "total_bytes": 327_589_562},
        official_input_records=official_records,
        local_input_records=local_records,
        official_deck_record=official_deck_record,
        local_deck_record=local_deck_record,
        master=master,
        bridge=bridge,
    )


def validate_catalog_documents(documents: Mapping[str, Any]) -> None:
    if type(documents) is not dict or set(documents) != set(ARTIFACT_PATHS):
        _fail("catalog_artifact_set_invalid")
    if documents["schema"] != _schema_with_artifact_defs(_build_schema()):
        _fail("schema_unsupported")
    master = _require_exact_keys(
        documents["official_master"],
        {"schema_version", "artifact_id", "source_manifest_id", "cards", "attacks", "source_evidence"},
        "master_shape_invalid",
    )
    if (
        master["schema_version"] != 1
        or master["artifact_id"] != OFFICIAL_MASTER_ID
        or master["source_manifest_id"] != SOURCE_MANIFEST_ID
    ):
        _fail("schema_unsupported")
    cards = master["cards"]
    attacks = master["attacks"]
    if type(cards) is not list or len(cards) != EXPECTED_CARD_COUNT:
        _fail("master_card_count_mismatch")
    if type(attacks) is not list or len(attacks) != EXPECTED_ATTACK_COUNT:
        _fail("master_attack_count_mismatch")
    card_ids: list[int] = []
    card_attack_membership: dict[int, tuple[int, int]] = {}
    for card in cards:
        _require_exact_keys(
            card,
            {"official_card_id", "exact_english_printing_or_null", "ordered_official_attack_ids"},
            "master_card_shape_invalid",
        )
        card_id = _require_exact_int(card["official_card_id"], "official_card_id_invalid")
        card_ids.append(card_id)
        printing = card["exact_english_printing_or_null"]
        if printing is not None:
            _require_exact_keys(printing, {"expansion", "collection_no"}, "official_printing_invalid")
            if type(printing["expansion"]) is not str or not printing["expansion"] or type(printing["collection_no"]) is not str or not printing["collection_no"]:
                _fail("official_printing_invalid")
        ordered = card["ordered_official_attack_ids"]
        if type(ordered) is not list:
            _fail("master_card_shape_invalid")
        for ordinal, raw_attack_id in enumerate(ordered):
            attack_id = _require_exact_int(raw_attack_id, "official_attack_id_invalid")
            if attack_id in card_attack_membership:
                _fail("master_attack_owner_conflict")
            card_attack_membership[attack_id] = (card_id, ordinal)
    if card_ids != list(range(1, EXPECTED_CARD_COUNT + 1)):
        _fail("master_card_order_or_duplicate")

    attack_ids: list[int] = []
    for attack in attacks:
        _require_exact_keys(
            attack,
            {"official_attack_id", "owner_official_card_id", "owner_attack_ordinal"},
            "master_attack_shape_invalid",
        )
        attack_id = _require_exact_int(attack["official_attack_id"], "official_attack_id_invalid")
        owner = _require_exact_int(attack["owner_official_card_id"], "official_card_id_invalid")
        ordinal = attack["owner_attack_ordinal"]
        if type(ordinal) is not int or ordinal < 0 or ordinal > MAX_SAFE_INTEGER:
            _fail("master_attack_ordinal_invalid")
        attack_ids.append(attack_id)
        if card_attack_membership.get(attack_id) != (owner, ordinal):
            _fail("master_attack_owner_mismatch")
    if attack_ids != list(range(1, EXPECTED_ATTACK_COUNT + 1)):
        _fail("master_attack_order_or_duplicate")
    expected_source_evidence = {
        "current_official_card_count": EXPECTED_CARD_COUNT,
        "current_official_attack_count": EXPECTED_ATTACK_COUNT,
        "english_csv_data_row_count": EXPECTED_EN_ROW_COUNT,
        "printing_null_official_card_ids": EXPECTED_NULL_PRINTINGS,
        "id_range_semantics": (
            "observed_current_source_evidence_only_not_a_future_dense_id_contract"
        ),
    }
    if master["source_evidence"] != expected_source_evidence:
        _fail("master_source_evidence_mismatch")
    actual_null_printings = [
        card["official_card_id"]
        for card in cards
        if card["exact_english_printing_or_null"] is None
    ]
    if actual_null_printings != EXPECTED_NULL_PRINTINGS:
        _fail("master_source_evidence_mismatch")

    bridge = _require_exact_keys(
        documents["exact_bridge"],
        {
            "schema_version",
            "artifact_id",
            "source_manifest_id",
            "bridge_scope",
            "entries",
        },
        "bridge_entry_shape_invalid",
    )
    if (
        bridge["schema_version"] != 1
        or bridge["artifact_id"] != EXACT_BRIDGE_ID
        or bridge["source_manifest_id"] != SOURCE_MANIFEST_ID
        or type(bridge["entries"]) is not list
        or len(bridge["entries"]) != 9
    ):
        _fail("bridge_entry_set_mismatch")
    expected_scope = {
        "entry_count": 9,
        "official_marnie_unique_card_id_count": 19,
        "official_marnie_bridge_unique_card_id_count": 9,
        "official_marnie_bridge_card_count": 34,
        "official_marnie_unmapped_card_ids": [
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
        ],
        "local_800018501_bridge_unique_printing_count": 4,
        "local_800018501_bridge_card_count": 15,
        "local_800018501_cabt_exportable": False,
        "inference_policy": "denied_exact_entries_only",
    }
    if bridge["bridge_scope"] != expected_scope:
        _fail("bridge_scope_mismatch")
    expected_specs = {
        (spec["local_printing"]["set_code"], spec["local_printing"]["card_index"]): spec
        for spec in BRIDGE_SPECS
    }
    seen: set[tuple[str, str]] = set()
    seen_ids: set[int] = set()
    cards_by_id = {card["official_card_id"]: card for card in cards}
    for entry in bridge["entries"]:
        _require_exact_keys(
            entry,
            {
                "official_card_id",
                "local_printing",
                "source_root_id",
                "source_file",
                "source_bytes",
                "source_raw_sha256",
                "source_canonical_json_v1_sha256",
                "local_attack_index_to_official_attack_id",
            },
            "bridge_entry_shape_invalid",
        )
        local = entry.get("local_printing")
        if type(local) is not dict or set(local) != {"set_code", "card_index"}:
            _fail("bridge_entry_shape_invalid")
        if type(local["set_code"]) is not str or type(local["card_index"]) is not str:
            _fail("bridge_entry_shape_invalid")
        key = (local["set_code"], local["card_index"])
        card_id = _require_exact_int(
            entry.get("official_card_id"), "official_card_id_invalid"
        )
        if key in seen or card_id in seen_ids or key not in expected_specs:
            _fail("bridge_entry_set_mismatch")
        seen.add(key)
        seen_ids.add(card_id)
        spec = expected_specs[key]
        if (
            card_id != spec["official_card_id"]
            or entry["source_root_id"] != "ptcgdap"
            or entry["source_file"] != spec["source_file"]
            or entry["source_bytes"] != LOCAL_SOURCE_BYTES[spec["source_file"]]
            or entry["source_raw_sha256"] != spec["source_raw_sha256"]
            or entry["source_canonical_json_v1_sha256"]
            != spec["source_canonical_json_v1_sha256"]
        ):
            _fail("bridge_entry_set_mismatch")
        attack_map = entry.get("local_attack_index_to_official_attack_id")
        if type(attack_map) is not dict or attack_map != spec["local_attack_index_to_official_attack_id"]:
            _fail("attack_map_incomplete")
        if [attack_map[str(index)] for index in range(len(attack_map))] != cards_by_id[card_id]["ordered_official_attack_ids"]:
            _fail("attack_owner_mismatch")
    if seen != set(expected_specs):
        _fail("bridge_entry_set_mismatch")

    expected_source_manifest = _expected_source_manifest(master, bridge)
    if documents["source_manifest"] != expected_source_manifest:
        _fail("source_manifest_mismatch")

    artifact_hashes = {
        artifact_id: sha256_bytes(
            canonical_json_v1_bytes(documents[artifact_id])
        )
        for artifact_id in (
            "schema",
            "source_manifest",
            "official_master",
            "exact_bridge",
        )
    }
    expected_vectors = _build_vectors(master, bridge, artifact_hashes)
    if documents["conformance_vectors"] != expected_vectors:
        _fail("conformance_vectors_invalid")

    expected_bundle = _build_bundle(documents)
    if documents["bundle"] != expected_bundle:
        _fail("catalog_bundle_invalid")


def render_catalog_documents(documents: Mapping[str, Any]) -> dict[str, bytes]:
    validate_catalog_documents(documents)
    return {
        ARTIFACT_PATHS[artifact_id]: (
            json.dumps(document, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
        ).encode("utf-8")
        for artifact_id, document in documents.items()
    }


def write_catalog_documents(repository_root: Path, documents: Mapping[str, Any]) -> None:
    repository_root = repository_root.resolve(strict=True)
    rendered = render_catalog_documents(documents)
    for relative, payload in rendered.items():
        destination = repository_root / Path(*PurePosixPath(relative).parts)
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(payload)


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Build the source-locked PtcgDAP Card/Attack identity catalog.")
    parser.add_argument("--repository-root", type=Path, required=True)
    parser.add_argument("--oracle-root", type=Path, required=True)
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--check", action="store_true")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = _build_parser().parse_args(argv)
    if args.write == args.check:
        raise SystemExit("exactly one of --write or --check is required")
    documents = build_catalog_documents(args.repository_root, args.oracle_root)
    rendered = render_catalog_documents(documents)
    if args.write:
        write_catalog_documents(args.repository_root, documents)
        return 0
    for relative, payload in rendered.items():
        path = args.repository_root / Path(*PurePosixPath(relative).parts)
        if not path.is_file() or path.read_bytes() != payload:
            print(f"DRIFT {relative}")
            return 1
    print("PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
