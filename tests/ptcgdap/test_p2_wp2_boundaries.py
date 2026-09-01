from __future__ import annotations

import ast
import hashlib
import json
import re
import unittest
from pathlib import Path
from typing import Any

from scripts.ai.ptcgdap.source_lock import (
    canonical_json_v1_bytes,
    load_json_strict,
)
from tests.ptcgdap.test_as_wp5_parent_snapshot import AS_WP5_APPROVED_SUCCESSOR_RUNTIME_PATHS


ROOT = Path(__file__).resolve().parents[2]
WORK_PACKAGE = ROOT / "artifacts" / "ptcgdap" / "p2_wp2" / "work_package.json"
CONTRACT_BUNDLE = ROOT / "contracts" / "ptcgdap" / "cabt_contract_bundle.json"
SOURCE_LOCK = ROOT / "docs" / "ptcgdap" / "SOURCE_LOCK.json"
P2_WP1_MANIFEST = ROOT / "artifacts" / "ptcgdap" / "p2_wp1" / "manifest.json"

CATALOG_SCHEMA = ROOT / "contracts" / "ptcgdap" / "card_id_catalog.schema.json"
SOURCE_MANIFEST = (
    ROOT / "contracts" / "ptcgdap" / "card_id_catalog_source_manifest.json"
)
CATALOG_BUNDLE = ROOT / "contracts" / "ptcgdap" / "card_id_catalog_bundle.json"
CATALOG_VECTORS = (
    ROOT / "contracts" / "ptcgdap" / "card_id_catalog_conformance_vectors.json"
)
OFFICIAL_MASTER = (
    ROOT
    / "data"
    / "ptcgdap"
    / "card_id_catalog"
    / "official_card_attack_master_v1.json"
)
EXACT_BRIDGE = (
    ROOT
    / "data"
    / "ptcgdap"
    / "card_id_catalog"
    / "marnie_exact_print_bridge_v1.json"
)
PYTHON_RUNTIME = ROOT / "scripts" / "ai" / "ptcgdap" / "card_id_catalog.py"
GODOT_RUNTIME = (
    ROOT
    / "scripts"
    / "ai"
    / "ptcgdap"
    / "host"
    / "godot"
    / "CardIdCatalog.gd"
)
PROJECTOR_PYTHON_RUNTIME = ROOT / "scripts" / "ai" / "ptcgdap" / "observation_projector.py"
PROJECTOR_GODOT_RUNTIME = (
    ROOT
    / "scripts"
    / "ai"
    / "ptcgdap"
    / "host"
    / "godot"
    / "GodotObservationProjector.gd"
)
IDENTITY_PYTHON_RUNTIME = ROOT / "scripts/ai/ptcgdap/marnie_identity_projection.py"
IDENTITY_GODOT_RUNTIME = ROOT / "scripts/ai/ptcgdap/public/MarnieIdentityProjection.gd"
BUILDER = ROOT / "tools" / "ptcgdap" / "build_card_id_catalog.py"

P1_CABT_BUNDLE_RAW_SHA256 = (
    "F1E8269B7E4908660E5BE993F574D433B89FF5134FFE853110751E8BA9777920"
)
P1_CABT_BUNDLE_CANONICAL_SHA256 = (
    "2CD02F54538985426EFDB057F3A6BDA4AD154DD171BCC03667D42D102982D294"
)
SOURCE_LOCK_RAW_SHA256 = (
    "DD5B2FB796731DCC4D2068B2C3D939346AB89A54D162F625845AB58A66767023"
)
SOURCE_LOCK_CANONICAL_SHA256 = (
    "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"
)
P2_WP1_MANIFEST_RAW_SHA256 = (
    "1465FF641BCF722DA3AD411F02DF8377B26872723509EABC355EE1167A1C20E9"
)
P2_WP1_MANIFEST_CANONICAL_SHA256 = (
    "81BDB4B254B1A7246F1A071FB0D1ABF2125B9AF31BE6FCB20A9F7DA0DA0C8A3C"
)

EXPECTED_OWNER_PATHS = {
    "contract_and_identity_artifacts": [
        "contracts/ptcgdap/card_id_catalog.schema.json",
        "contracts/ptcgdap/card_id_catalog_source_manifest.json",
        "contracts/ptcgdap/card_id_catalog_bundle.json",
        "contracts/ptcgdap/card_id_catalog_conformance_vectors.json",
        "data/ptcgdap/card_id_catalog/official_card_attack_master_v1.json",
        "data/ptcgdap/card_id_catalog/marnie_exact_print_bridge_v1.json",
    ],
    "implementation": [
        "scripts/ai/ptcgdap/card_id_catalog.py",
        "scripts/ai/ptcgdap/host/godot/CardIdCatalog.gd",
        "tools/ptcgdap/build_card_id_catalog.py",
    ],
}

EXPECTED_BRIDGE: dict[tuple[str, str], dict[str, Any]] = {
    ("CSVE1C", "DAR"): {
        "official_card_id": 7,
        "source_file": "data/bundled_user/cards/CSVE1C_DAR.json",
        "source_bytes": 912,
        "source_raw_sha256": (
            "B86CF49A7890C45951CDB80C87BC75F0392812C5370DA66866FCC979DC79CAB2"
        ),
        "source_canonical_sha256": (
            "B29AF1051D130851567F72BA2759A71B9BF51405DDF15305645B3C0BFF218084"
        ),
        "attacks": {},
    },
    ("CSV7C", "059"): {
        "official_card_id": 104,
        "source_file": "data/bundled_user/cards/CSV7C_059.json",
        "source_bytes": 1496,
        "source_raw_sha256": (
            "042936F1770BD8B9B9A06EDFA28DE212CA04A0D5022E1EB8B915F705323B2499"
        ),
        "source_canonical_sha256": (
            "6342EEAB3468FF43718D841C9DD55E750F0FFA27ECB8622FD5478AA820AFDD95"
        ),
        "attacks": {0: 131},
    },
    ("CSV8C", "094"): {
        "official_card_id": 112,
        "source_file": "data/bundled_user/cards/CSV8C_094.json",
        "source_bytes": 1686,
        "source_raw_sha256": (
            "9EEDD84B0FDA69DFBED0A32C0321C2E4B9A8A4B6C905D22F3EB8FEBBAB56C2A1"
        ),
        "source_canonical_sha256": (
            "8540B67BA8C3F5D45AC0F9E372A7C3B7BDCA7F3F050D4159D704C08E18526A8F"
        ),
        "attacks": {0: 141},
    },
    ("LEN_DRI", "134"): {
        "official_card_id": 646,
        "source_file": "data/bundled_user/cards/LEN_DRI_134.json",
        "source_bytes": 1700,
        "source_raw_sha256": (
            "7A09714B9835766BF5BAC71C0D2FEC1735E908D97980E3E06FBDBCE39B1D27E2"
        ),
        "source_canonical_sha256": (
            "D7259EED7B9B583DFF95AC92D7CF1E258B84B1F678F21C1743563AC03929C733"
        ),
        "attacks": {0: 934, 1: 935},
    },
    ("LEN_DRI", "135"): {
        "official_card_id": 647,
        "source_file": "data/bundled_user/cards/LEN_DRI_135.json",
        "source_bytes": 1497,
        "source_raw_sha256": (
            "1BD94CB5EAC1EA0021F423A07A23508059E4BCEAB288B90620D71B51F63706C4"
        ),
        "source_canonical_sha256": (
            "651B012760D24BBC2E09BCC2A4A1F5010AEB595B4C98046246CC669C2362E824"
        ),
        "attacks": {0: 936},
    },
    ("LEN_DRI", "136"): {
        "official_card_id": 648,
        "source_file": "data/bundled_user/cards/LEN_DRI_136.json",
        "source_bytes": 2788,
        "source_raw_sha256": (
            "5EFA9B7F30F3ADA7DF097D68A6D7851553E9C3E5490406239DA2434406716D3C"
        ),
        "source_canonical_sha256": (
            "A041E7168A5CA50C82E76DDBA0CEC6F2C7F66C34593B4D6A9A8C68690664021A"
        ),
        "attacks": {0: 937},
    },
    ("CSV8C", "173"): {
        "official_card_id": 1080,
        "source_file": "data/bundled_user/cards/CSV8C_173.json",
        "source_bytes": 1167,
        "source_raw_sha256": (
            "4FF6B61A942B6D7023AC4FEB149E701ACCC70F556F0F53B8CBD69227E26FE3EE"
        ),
        "source_canonical_sha256": (
            "DE4487B0030DEBAFE37303E51E978E3FA5C0C09BCADDD8245B365F2ED988ED94"
        ),
        "attacks": {},
    },
    ("CSV8C", "183"): {
        "official_card_id": 1097,
        "source_file": "data/bundled_user/cards/CSV8C_183.json",
        "source_bytes": 1008,
        "source_raw_sha256": (
            "713F2B15DED2F144E562667A5B7AC853E6770DDA3616934882664BF67D9AA457"
        ),
        "source_canonical_sha256": (
            "FB05919614D31D6362E7CBCDDCB7137EC1EC2AB160B4D20FA8E0634F3E2A0AB2"
        ),
        "attacks": {},
    },
    ("LEN_DRI", "169"): {
        "official_card_id": 1259,
        "source_file": "data/bundled_user/cards/LEN_DRI_169.json",
        "source_bytes": 1427,
        "source_raw_sha256": (
            "486CEC705A0DAB6D855C938CF43291ECBCFD36C646F105D129F5E549B8BD3642"
        ),
        "source_canonical_sha256": (
            "28079978B465F21F50CE9FDDA8B7EB9B6406C409F29BDCDC9D67E747FEAF3E1B"
        ),
        "attacks": {},
    },
}

RUNTIME_FORBIDDEN_MARKERS = {
    "AIOpponent",
    "BattleScene",
    "CardData",
    "CardDatabase",
    "CardInstance",
    "CardCatalogIndex",
    "GameState",
    "GameStateMachine",
    "GodotObservationProjector",
    "HTTPRequest",
    "HTTPClient",
    "ObjectDB",
    "OS.create_process",
    "OS.execute",
    "PacketPeerUDP",
    "PokemonSlot",
    "PublicObservationFirewall",
    "StreamPeerTCP",
    "WebSocketPeer",
    "build_card_id_catalog",
    "ptcg-limitless-importer",
    "ptcgabc",
    "user://",
}

FORBIDDEN_PYTHON_IMPORT_ROOTS = {
    "ctypes",
    "http",
    "multiprocessing",
    "requests",
    "socket",
    "subprocess",
    "urllib",
}

FORBIDDEN_INFERENCE_FIELD = re.compile(
    r"['\"](?:display_name|effect_text|image|image_url|name|name_en|name_zh|"
    r"resolved_via|same_print_group|source_print|source_prints|text)['\"]",
    flags=re.IGNORECASE,
)


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest().upper()


def _gdscript_without_comments(source: str) -> str:
    return "\n".join(line.split("#", 1)[0] for line in source.splitlines())


def _load_required_json(path: Path) -> Any:
    if not path.is_file():
        raise AssertionError(f"required P2-WP2 artifact is missing: {path.relative_to(ROOT)}")
    return load_json_strict(path)


def _read_required_text(path: Path) -> str:
    if not path.is_file():
        raise AssertionError(f"required P2-WP2 file is missing: {path.relative_to(ROOT)}")
    return path.read_text(encoding="utf-8")


def _bridge_entries(document: Any) -> list[dict[str, Any]]:
    if not isinstance(document, dict):
        raise AssertionError("bridge root must be an object")
    raw_entries = document.get("entries", document.get("mappings"))
    if not isinstance(raw_entries, list):
        raise AssertionError("bridge must expose an entries array")
    if not all(isinstance(entry, dict) for entry in raw_entries):
        raise AssertionError("every bridge entry must be an object")
    return raw_entries


def _normalize_attack_map(raw: Any) -> dict[int, int]:
    if isinstance(raw, dict):
        result: dict[int, int] = {}
        for raw_index, attack_id in raw.items():
            if (
                not isinstance(raw_index, str)
                or re.fullmatch(r"(?:0|[1-9][0-9]*)", raw_index) is None
            ):
                raise AssertionError("attack-map object keys must be decimal index strings")
            index = int(raw_index)
            if index in result or type(attack_id) is not int:
                raise AssertionError("attack-map entries must be unique exact integers")
            result[index] = attack_id
        return result
    if isinstance(raw, list):
        result = {}
        for entry in raw:
            if not isinstance(entry, dict):
                raise AssertionError("attack-map array entries must be objects")
            index = entry.get("local_attack_index")
            attack_id = entry.get("official_attack_id")
            if type(index) is not int or type(attack_id) is not int or index in result:
                raise AssertionError("attack-map entries must be unique exact integers")
            result[index] = attack_id
        return result
    raise AssertionError("attack mapping must be an object or an explicit record array")


def _iter_object_keys(value: Any, path: str = "$") -> list[tuple[str, str]]:
    result: list[tuple[str, str]] = []
    if isinstance(value, dict):
        for key, child in value.items():
            result.append((path, key))
            result.extend(_iter_object_keys(child, f"{path}.{key}"))
    elif isinstance(value, list):
        for index, child in enumerate(value):
            result.extend(_iter_object_keys(child, f"{path}[{index}]"))
    return result


class P2Wp2BoundaryTests(unittest.TestCase):
    def test_parent_cabt_source_lock_and_p2_wp1_manifest_remain_exact(self) -> None:
        bundle_raw = CONTRACT_BUNDLE.read_bytes()
        self.assertEqual(_sha256(bundle_raw), P1_CABT_BUNDLE_RAW_SHA256)
        self.assertEqual(
            _sha256(canonical_json_v1_bytes(load_json_strict(CONTRACT_BUNDLE))),
            P1_CABT_BUNDLE_CANONICAL_SHA256,
        )

        source_lock_raw = SOURCE_LOCK.read_bytes()
        self.assertEqual(_sha256(source_lock_raw), SOURCE_LOCK_RAW_SHA256)
        self.assertEqual(
            _sha256(canonical_json_v1_bytes(load_json_strict(SOURCE_LOCK))),
            SOURCE_LOCK_CANONICAL_SHA256,
        )

        parent_raw = P2_WP1_MANIFEST.read_bytes()
        self.assertEqual(_sha256(parent_raw), P2_WP1_MANIFEST_RAW_SHA256)
        self.assertEqual(
            _sha256(canonical_json_v1_bytes(load_json_strict(P2_WP1_MANIFEST))),
            P2_WP1_MANIFEST_CANONICAL_SHA256,
        )

    def test_work_package_preserves_exact_owner_scope_and_catalog_counts(self) -> None:
        work_package = _load_required_json(WORK_PACKAGE)
        self.assertEqual(work_package["work_package"], "P2-WP2")
        self.assertEqual(
            work_package["files_allowed"]["contract_and_identity_artifacts"],
            EXPECTED_OWNER_PATHS["contract_and_identity_artifacts"],
        )
        self.assertEqual(
            work_package["files_allowed"]["implementation"],
            EXPECTED_OWNER_PATHS["implementation"],
        )
        self.assertEqual(work_package["official_master_scope"]["expected_card_id_count"], 1267)
        self.assertEqual(
            work_package["official_master_scope"]["expected_attack_id_count"],
            1556,
        )
        self.assertEqual(work_package["exact_godot_bridge_scope"]["entry_count"], 9)
        actual: dict[tuple[str, str], dict[str, Any]] = {}
        for entry in work_package["exact_godot_bridge_scope"]["entries"]:
            local = entry["local_printing"]
            key = (local["set_code"], local["card_index"])
            self.assertNotIn(key, actual)
            actual[key] = {
                "official_card_id": entry["official_card_id"],
                "source_file": entry["source_file"],
                "attacks": _normalize_attack_map(
                    entry["local_attack_index_to_official_attack_id"]
                ),
            }
        self.assertEqual(set(actual), set(EXPECTED_BRIDGE))
        for key, expected in EXPECTED_BRIDGE.items():
            with self.subTest(local_printing=key):
                self.assertEqual(actual[key]["official_card_id"], expected["official_card_id"])
                self.assertEqual(actual[key]["source_file"], expected["source_file"])
                self.assertEqual(actual[key]["attacks"], expected["attacks"])

    def test_work_package_must_finish_as_shadow_without_advancing_alignment(self) -> None:
        work_package = _load_required_json(WORK_PACKAGE)
        self.assertEqual(work_package["status"], "shadow")
        self.assertEqual(work_package["implementation_state"], "completed")
        self.assertEqual(
            work_package["shadow_or_live"],
            "shadow_identity_catalog_only_no_live_consumer",
        )
        self.assertEqual(work_package["alignment_claim"]["A0"], "partial / not claimed")
        for level in ("A1", "A2", "A3", "A4", "A5"):
            self.assertEqual(work_package["alignment_claim"][level], "not evaluated")
        self.assertEqual(work_package["phase_gates"]["P2"], "incomplete")
        self.assertIn("incomplete", work_package["phase_gates"]["C05"])

    def test_complete_master_contains_only_portable_identity(self) -> None:
        master = _load_required_json(OFFICIAL_MASTER)
        self.assertIsInstance(master, dict)
        self.assertEqual(
            set(master),
            {
                "schema_version",
                "artifact_id",
                "source_manifest_id",
                "cards",
                "attacks",
                "source_evidence",
            },
        )
        cards = master.get("cards")
        attacks = master.get("attacks")
        self.assertIsInstance(cards, list)
        self.assertIsInstance(attacks, list)
        self.assertEqual(len(cards), 1267)
        self.assertEqual(len(attacks), 1556)

        ordered_card_ids: list[int] = []
        attack_membership: dict[int, tuple[int, int]] = {}
        for record in cards:
            self.assertIsInstance(record, dict)
            self.assertEqual(
                set(record),
                {
                    "official_card_id",
                    "exact_english_printing_or_null",
                    "ordered_official_attack_ids",
                },
            )
            card_id = record.get("official_card_id")
            ordered_attacks = record.get("ordered_official_attack_ids")
            printing = record.get("exact_english_printing_or_null")
            self.assertIs(type(card_id), int)
            self.assertNotIn(card_id, ordered_card_ids)
            self.assertTrue(printing is None or isinstance(printing, dict))
            if isinstance(printing, dict):
                self.assertEqual(set(printing), {"expansion", "collection_no"})
                self.assertIs(type(printing["expansion"]), str)
                self.assertIs(type(printing["collection_no"]), str)
                self.assertNotEqual(printing["expansion"], "")
                self.assertNotEqual(printing["collection_no"], "")
            self.assertIsInstance(ordered_attacks, list)
            ordered_card_ids.append(card_id)
            for ordinal, attack_id in enumerate(ordered_attacks):
                self.assertIs(type(attack_id), int)
                self.assertNotIn(attack_id, attack_membership)
                attack_membership[attack_id] = (card_id, ordinal)

        ordered_attack_ids: list[int] = []
        for record in attacks:
            self.assertIsInstance(record, dict)
            self.assertEqual(
                set(record),
                {
                    "official_attack_id",
                    "owner_official_card_id",
                    "owner_attack_ordinal",
                },
            )
            attack_id = record["official_attack_id"]
            owner_card_id = record["owner_official_card_id"]
            owner_ordinal = record["owner_attack_ordinal"]
            self.assertIs(type(attack_id), int)
            self.assertIs(type(owner_card_id), int)
            self.assertIs(type(owner_ordinal), int)
            self.assertEqual(
                attack_membership.get(attack_id),
                (owner_card_id, owner_ordinal),
            )
            ordered_attack_ids.append(attack_id)

        self.assertEqual(ordered_card_ids, list(range(1, 1268)))
        self.assertEqual(set(attack_membership), set(range(1, 1557)))
        self.assertEqual(ordered_attack_ids, list(range(1, 1557)))
        forbidden_keys = []
        for path, key in _iter_object_keys(master):
            normalized = key.casefold()
            if (
                "name" in normalized
                or "text" in normalized
                or "image" in normalized
                or normalized in {"description", "effect"}
            ):
                forbidden_keys.append(f"{path}.{key}")
        self.assertEqual(
            forbidden_keys,
            [],
            "identity master must not carry display/name/text/image payload",
        )

    def test_bridge_is_exactly_the_nine_pinned_structured_printings(self) -> None:
        bridge = _load_required_json(EXACT_BRIDGE)
        source_manifest = _load_required_json(SOURCE_MANIFEST)
        self.assertIsInstance(source_manifest, dict)
        source_inputs = source_manifest.get("inputs")
        self.assertIsInstance(source_inputs, list)
        input_ids = [record.get("id") for record in source_inputs]
        input_paths = [
            (record.get("root_id"), record.get("path"))
            for record in source_inputs
        ]
        self.assertEqual(len(input_ids), len(set(input_ids)))
        self.assertEqual(len(input_paths), len(set(input_paths)))
        reviewed_sources = {
            record["path"]: record
            for record in source_inputs
            if record.get("role") == "reviewed_exact_local_printing_source"
        }
        self.assertEqual(set(reviewed_sources), {
            expected["source_file"] for expected in EXPECTED_BRIDGE.values()
        })
        entries = _bridge_entries(bridge)
        self.assertEqual(len(entries), 9)

        master = _load_required_json(OFFICIAL_MASTER)
        master_by_id = {record["official_card_id"]: record for record in master["cards"]}
        actual_keys: set[tuple[str, str]] = set()
        for entry in entries:
            self.assertEqual(
                set(entry),
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
            )
            local = entry.get("local_printing")
            self.assertIsInstance(local, dict)
            self.assertEqual(set(local), {"set_code", "card_index"})
            self.assertIs(type(local["set_code"]), str)
            self.assertIs(type(local["card_index"]), str)
            key = (local["set_code"], local["card_index"])
            self.assertNotIn(key, actual_keys)
            actual_keys.add(key)
            expected = EXPECTED_BRIDGE[key]

            self.assertEqual(entry.get("official_card_id"), expected["official_card_id"])
            self.assertEqual(entry.get("source_root_id"), "ptcgdap")
            self.assertEqual(entry.get("source_file"), expected["source_file"])
            self.assertEqual(entry.get("source_bytes"), expected["source_bytes"])
            self.assertEqual(
                entry.get("source_raw_sha256"),
                expected["source_raw_sha256"],
            )
            self.assertEqual(
                entry.get("source_canonical_json_v1_sha256"),
                expected["source_canonical_sha256"],
            )
            attack_map = _normalize_attack_map(
                entry.get("local_attack_index_to_official_attack_id")
            )
            self.assertEqual(attack_map, expected["attacks"])

            source_path = ROOT / expected["source_file"]
            source_raw = source_path.read_bytes()
            source_record = load_json_strict(source_path)
            source_hash = _sha256(canonical_json_v1_bytes(source_record))
            self.assertEqual(len(source_raw), expected["source_bytes"])
            self.assertEqual(_sha256(source_raw), expected["source_raw_sha256"])
            self.assertEqual(source_hash, expected["source_canonical_sha256"])
            source_input = reviewed_sources[expected["source_file"]]
            self.assertEqual(source_input["root_id"], "ptcgdap")
            self.assertEqual(source_input["bytes"], expected["source_bytes"])
            self.assertEqual(
                source_input["raw_sha256"],
                expected["source_raw_sha256"],
            )
            self.assertEqual(
                source_input["canonical_json_v1_sha256"],
                expected["source_canonical_sha256"],
            )
            self.assertEqual(
                (source_record["set_code"], source_record["card_index"]),
                key,
            )

            official_record = master_by_id[expected["official_card_id"]]
            official_printing = official_record["exact_english_printing_or_null"]
            self.assertIsInstance(official_printing, dict)
            self.assertEqual(
                (source_record["set_code_en"], source_record["card_index_en"]),
                (
                    official_printing["expansion"],
                    official_printing["collection_no"],
                ),
            )
            self.assertEqual(
                list(attack_map.values()),
                official_record["ordered_official_attack_ids"],
            )
            self.assertEqual(len(source_record.get("attacks", [])), len(attack_map))

        self.assertEqual(actual_keys, set(EXPECTED_BRIDGE))

    def test_catalog_artifacts_and_runtime_do_not_enable_guessing(self) -> None:
        for path in (OFFICIAL_MASTER, EXACT_BRIDGE):
            source = _read_required_text(path)
            with self.subTest(path=path.relative_to(ROOT).as_posix()):
                self.assertIsNone(FORBIDDEN_INFERENCE_FIELD.search(source))

        for path in (PYTHON_RUNTIME, GODOT_RUNTIME):
            source = _read_required_text(path)
            code = source if path.suffix == ".py" else _gdscript_without_comments(source)
            with self.subTest(path=path.relative_to(ROOT).as_posix()):
                self.assertIsNone(FORBIDDEN_INFERENCE_FIELD.search(code))

    def test_runtime_loaders_have_no_engine_ui_network_process_or_builder_dependency(self) -> None:
        for path in (PYTHON_RUNTIME, GODOT_RUNTIME):
            self.assertTrue(path.is_file(), path.relative_to(ROOT).as_posix())
            source = path.read_text(encoding="utf-8")
            code = source if path.suffix == ".py" else _gdscript_without_comments(source)
            for marker in RUNTIME_FORBIDDEN_MARKERS:
                with self.subTest(path=path.relative_to(ROOT).as_posix(), marker=marker):
                    self.assertNotIn(marker, code)

        tree = ast.parse(PYTHON_RUNTIME.read_text(encoding="utf-8"), filename=str(PYTHON_RUNTIME))
        imported_roots: set[str] = set()
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                imported_roots.update(alias.name.split(".", 1)[0] for alias in node.names)
            elif isinstance(node, ast.ImportFrom) and node.module:
                imported_roots.add(node.module.split(".", 1)[0])
        self.assertEqual(imported_roots & FORBIDDEN_PYTHON_IMPORT_ROOTS, set())

    def test_catalog_has_no_live_consumer_or_autoload_wiring(self) -> None:
        markers = {
            "CardIdCatalog",
            "res://scripts/ai/ptcgdap/host/godot/CardIdCatalog.gd",
            "scripts.ai.ptcgdap.card_id_catalog",
        }
        owners = {
            PYTHON_RUNTIME.resolve(),
            GODOT_RUNTIME.resolve(),
            PROJECTOR_PYTHON_RUNTIME.resolve(),
            PROJECTOR_GODOT_RUNTIME.resolve(),
            IDENTITY_PYTHON_RUNTIME.resolve(),
            IDENTITY_GODOT_RUNTIME.resolve(),
            (ROOT / "scripts/ai/ptcgdap/author_strategy_match_host.py").resolve(),
            (ROOT / "scripts/ai/ptcgdap/packages/AuthorStrategyDeckGate.gd").resolve(),
        }
        consumers: list[str] = []
        candidate_paths = [
            *(
                path
                for path in (ROOT / "scripts").rglob("*")
                if path.is_file() and path.suffix in {".gd", ".py"}
            ),
            *(
                path
                for path in (ROOT / "scenes").rglob("*")
                if path.is_file() and path.suffix in {".gd", ".tscn"}
            ),
            ROOT / "project.godot",
        ]
        for path in candidate_paths:
            relative = path.relative_to(ROOT).as_posix()
            if relative in AS_WP5_APPROVED_SUCCESSOR_RUNTIME_PATHS:
                continue
            if path.resolve() in owners:
                continue
            source = path.read_text(encoding="utf-8", errors="strict")
            if any(marker in source for marker in markers):
                consumers.append(relative)
        self.assertEqual(
            consumers,
            [],
            "P2-WP2 must remain shadow-only with no script, scene or autoload consumer",
        )

    def test_catalog_owner_files_are_additive_and_builder_is_development_only(self) -> None:
        required_paths = (
            CATALOG_SCHEMA,
            SOURCE_MANIFEST,
            CATALOG_BUNDLE,
            CATALOG_VECTORS,
            OFFICIAL_MASTER,
            EXACT_BRIDGE,
            PYTHON_RUNTIME,
            GODOT_RUNTIME,
            BUILDER,
        )
        missing = [
            path.relative_to(ROOT).as_posix()
            for path in required_paths
            if not path.is_file()
        ]
        self.assertEqual(missing, [], "P2-WP2 owner files must all be present")
        python_source = _read_required_text(PYTHON_RUNTIME)
        godot_source = _read_required_text(GODOT_RUNTIME)
        self.assertNotIn("tools.ptcgdap", python_source)
        self.assertNotIn("build_card_id_catalog", python_source)
        self.assertNotIn("build_card_id_catalog", godot_source)


if __name__ == "__main__":
    unittest.main()
