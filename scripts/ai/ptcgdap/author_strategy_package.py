from __future__ import annotations

import base64
import copy
import csv
from dataclasses import dataclass
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import re
import struct
from types import MappingProxyType
from typing import Any, Mapping
import zipfile

from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey
from jsonschema import Draft202012Validator

from .author_strategy_release import AuthorStrategyReleaseGate
from .competitive_policy_v2 import CompetitivePolicyV2Compiler
from .ptcgai_model_package import (
    MODEL_ARTIFACT_PATH,
    MODEL_MANIFEST_PATH,
    ModelPackageError,
    load_model_manifest_bytes,
    validate_v2_package_manifest,
)
from .source_lock import canonical_json_v1_bytes, load_json_bytes_strict, load_json_strict


ROOT = Path(__file__).resolve().parents[3]
DEFAULT_CONTRACT_ROOT = ROOT / "contracts/ptcgdap"
PROFILE_ID = "ptcgdap-author-strategy-package-v1"
BUNDLE_ID = "ptcgdap-author-strategy-package-as-wp1-v1"
TEST_FIXTURE_KEY_ID = "ptcgdap-as-wp1-test-fixture-ed25519-v1"
CABT_CONTRACT_SHA256 = "2CD02F54538985426EFDB057F3A6BDA4AD154DD171BCC03667D42D102982D294"
CARD_CATALOG_SHA256 = "AB8CF10465F492A98DA8247A84572AECEE281D0726F7BB7B8E5DBC03A6AC70D4"
BASE_EXECUTOR_SHA256 = "69D05747A9F91C19765D448B676C86E1D9DFA1BBAB108ED1374B854B34E48389"
EXPECTED_BUNDLE_CANONICAL_SHA256 = "B416F2CBA2795B62126B6EF7B5F07A9000E84D5FA1DF62C1753CADC9E82E106B"
EXPECTED_ARTIFACT_CANONICAL_SHA256 = {
    "schema": "B3469DA24400407775FB6069CB5D9EE2147633770542322208B9FE102E0E20BE",
    "profile": "1137187EF1C073E081B541602A7498B7235A3606309C35212BC6559F0EF30B79",
    "vectors": "49F4493D89E74B4ED6F54957BAFDC0E3C1161C5BA695203AE3CEE17DEE50EE33",
}
COMPETITIVE_POLICY_V2_PROFILE_ID = "ptcgdap-competitive-policy-v2"
COMPETITIVE_POLICY_V2_BUNDLE_ID = "ptcgdap-competitive-policy-v2-as2-wp1"
COMPETITIVE_POLICY_V2_EXPECTED_BUNDLE_CANONICAL_SHA256 = "5F87E10C6C87B5CE71CBB2ACE2C31A5FA39C49C95F84F0D7983DEC86DCA2F3C3"
COMPETITIVE_POLICY_V2_CONTRACT_FILENAMES = {
    "schema": "competitive_policy_v2.schema.json",
    "profile": "competitive_policy_v2_profile.json",
    "vectors": "competitive_policy_v2_conformance_vectors.json",
    "bundle": "competitive_policy_v2_bundle.json",
}
COMPETITIVE_POLICY_V2_EXPECTED_ARTIFACT_CANONICAL_SHA256 = {
    "schema": "4A8E21D90A0B6EF1921BDC123BB58C0297F57EEACF8490F44EC0B46E8E60B910",
    "profile": "46FC76FFD292FDA0A9F4F4221EA14C8F7DFC2462163733E42876EAA7CFE63677",
    "vectors": "42BEB7D514686600F255E06BB76AF4440A08294D845C8D9CE4A7966C28701F7E",
}
CONTRACT_FILENAMES = {
    "schema": "author_strategy_package.schema.json",
    "profile": "author_strategy_package_profile.json",
    "vectors": "author_strategy_package_conformance_vectors.json",
    "bundle": "author_strategy_package_bundle.json",
}
WINDOWS_LOCAL_DECK_PROFILE_ID = "ptcgdap-author-strategy-windows-local-deck-v1"
WINDOWS_LOCAL_DECK_BUNDLE_ID = "ptcgdap-author-strategy-windows-local-deck-as-wp6-v1"
WINDOWS_LOCAL_DECK_DOMAIN = "godot_local_card_uid_v1"
WINDOWS_LOCAL_DECK_EXPECTED_BUNDLE_CANONICAL_SHA256 = "944440FB15D9C3C3533C4DFDF7B163BF690160CF1F6D6AB8C776958A6EDBDB56"
WINDOWS_LOCAL_DECK_CONTRACT_FILENAMES = {
    "schema": "author_strategy_windows_local_deck.schema.json",
    "profile": "author_strategy_windows_local_deck_profile.json",
    "vectors": "author_strategy_windows_local_deck_conformance_vectors.json",
    "bundle": "author_strategy_windows_local_deck_bundle.json",
}
WINDOWS_LOCAL_DECK_EXPECTED_ARTIFACT_CANONICAL_SHA256 = {
    "schema": "3E953F9289634BDD4D35C5DB4FC35BDA7BE0DABCAEDF25EA4B8190016B186F72",
    "profile": "917834D3F018CBC52B037E19FCECFF9A6B1967E4CA9206B9AE68FA70C557921C",
    "vectors": "8158B85B8F97E2B9539006810AA7D46C8B5752BC3A6DF968A8484DAA6DD7019A",
}
REQUIRED_PAYLOAD_PATHS = frozenset(
    {
        "strategy_package.json",
        "README.md",
        "LICENSE",
        "deck/deck_manifest.json",
        "deck/deck.csv",
        "policy/policy_ir.json",
        "policy/adapter.json",
        "policy/config.json",
    }
)
GENERATED_PATHS = frozenset({"files.sha256.json", "signature.json"})
OPTIONAL_PAYLOAD_KINDS = {
    "policy/weights.bin": "weights",
    MODEL_MANIFEST_PATH: "json",
    MODEL_ARTIFACT_PATH: "weights",
    "assets/icon.png": "png",
    "assets/banner.png": "png",
    "assets/icon.webp": "webp",
    "assets/banner.webp": "webp",
}
FIXED_PAYLOAD_KINDS = {
    "strategy_package.json": "json",
    "README.md": "text",
    "LICENSE": "text",
    "deck/deck_manifest.json": "json",
    "deck/deck.csv": "csv",
    "policy/policy_ir.json": "json",
    "policy/adapter.json": "json",
    "policy/config.json": "json",
}
FORBIDDEN_SUFFIXES = frozenset(
    {
        ".gd",
        ".py",
        ".pck",
        ".exe",
        ".dll",
        ".so",
        ".aar",
        ".jar",
        ".sh",
        ".bat",
        ".ps1",
        ".zip",
        ".7z",
        ".rar",
        ".tar",
        ".gz",
    }
)
FORBIDDEN_POLICY_KEYS = frozenset(
    {
        "callable",
        "module",
        "class",
        "code",
        "script",
        "path",
        "url",
        "import",
        "private_state",
        "search_begin_input",
        "session",
        "callback",
        "binding",
        "ticket",
        "command",
        "object_ref",
        "pokemon_entity_serial",
    }
)
FIXED_TIME = (1980, 1, 1, 0, 0, 0)
FIXED_MODE = 0o100644 << 16
HEX_RE = re.compile(r"^[0-9A-F]{64}$")
PATH_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*(?:/[A-Za-z0-9][A-Za-z0-9._-]*)*$")
SUPPORTED_CAPABILITIES = frozenset(
    {
        "public_context",
        "current_window",
        "deterministic_fallback",
        "strategic_trace_v2",
        "public_damage_plan_v1",
        "semantic_transaction_v1",
        "turn_transaction_v1",
        "learned_policy_head_v1",
    }
)
BASE_OPERATOR_ORDER = (
    "legality_guard",
    "mandatory_terminal_guard",
    "hard_tier_filter",
    "base_veto",
    "deterministic_fallback",
    "emit_decision",
)
ADAPTER_OPERATORS = frozenset({"goal_proposal", "macro_proposal", "tiebreak_score"})
ADAPTER_REASONS = {
    "goal_proposal": "public_goal_proposal",
    "macro_proposal": "public_macro_proposal",
    "tiebreak_score": "public_tiebreak_proposal",
}
GOAL_STAGES = frozenset({"acquire", "deploy", "fund", "ready", "execute", "maintain", "recover"})
PREDICATE_FIELDS = frozenset(
    {
        "select_type_raw",
        "select_context_raw",
        "option_type_raw",
        "option_card_id",
        "option_player_index",
        "acting_hand_card_id",
        "acting_active_card_id",
    }
)
CARD_PREDICATE_FIELDS = frozenset(
    {"option_card_id", "acting_hand_card_id", "acting_active_card_id"}
)


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


class AuthorStrategyPackageError(ValueError):
    def __init__(self, code: str) -> None:
        self.code = code
        super().__init__(code)


@dataclass(frozen=True, slots=True)
class AuthorStrategyPackageHandle:
    profile_id: str
    package_id: str
    package_version: str
    archive_sha256: str
    manifest_sha256: str
    manifest_canonical_sha256: str
    files_manifest_sha256: str
    policy_ir_sha256: str
    deck_manifest_sha256: str
    signature_status: str
    signature_key_id: str
    signature_scope: str
    execution_trusted: bool
    _metadata_json: bytes
    _payloads: Mapping[str, bytes]

    def to_dict(self) -> dict[str, Any]:
        return json.loads(self._metadata_json.decode("utf-8"))

    def payload_bytes(self, path: str) -> bytes:
        if type(path) is not str or path not in self._payloads:
            raise KeyError(path)
        return self._payloads[path]


def _raise(code: str) -> None:
    raise AuthorStrategyPackageError(code)


def _safe_path(raw: Any, max_path_bytes: int) -> str:
    if type(raw) is not str or not raw or "\\" in raw or "\0" in raw:
        _raise("package_path_invalid")
    try:
        encoded = raw.encode("ascii")
    except UnicodeEncodeError:
        _raise("package_path_invalid")
    if len(encoded) > max_path_bytes or not PATH_RE.fullmatch(raw):
        _raise("package_path_invalid")
    path = PurePosixPath(raw)
    if path.is_absolute() or "." in path.parts or ".." in path.parts or ":" in path.parts[0] or path.as_posix() != raw:
        _raise("package_path_invalid")
    return raw


def _strict_json(value: bytes, validator: Draft202012Validator, code: str) -> dict[str, Any]:
    try:
        document = load_json_bytes_strict(value)
        canonical_json_v1_bytes(document)
    except (UnicodeDecodeError, ValueError, TypeError):
        _raise(code)
    if type(document) is not dict or not validator.is_valid(document):
        _raise(code)
    return document


def _contains_forbidden_policy_key(value: Any) -> bool:
    stack = [value]
    while stack:
        current = stack.pop()
        if type(current) is dict:
            for key, child in current.items():
                if type(key) is not str or key.casefold() in FORBIDDEN_POLICY_KEYS:
                    return True
                stack.append(child)
        elif type(current) is list:
            stack.extend(current)
    return False


def _restricted_ir_valid(document: dict[str, Any]) -> bool:
    if document["required_capabilities"] != [
        "public_context",
        "current_window",
        "deterministic_fallback",
        "strategic_trace_v2",
    ]:
        return False
    nodes = document["nodes"]
    node_ids = [node["node_id"] for node in nodes]
    if len(node_ids) != len(set(node_ids)) or document["entry_node_id"] != node_ids[0]:
        return False
    for index, node in enumerate(nodes):
        expected_next = [] if index + 1 == len(nodes) else [node_ids[index + 1]]
        if node["next_node_ids"] != expected_next:
            return False
        operator = node["operator"]
        if operator in BASE_OPERATOR_ORDER:
            if node["owner"] != "base":
                return False
        elif operator in ADAPTER_OPERATORS:
            if node["owner"] != "adapter":
                return False
        else:
            return False
    return tuple(node["operator"] for node in nodes if node["owner"] == "base") == BASE_OPERATOR_ORDER


def _public_adapter_valid(document: dict[str, Any], deck: dict[str, Any]) -> bool:
    local_domain = deck.get("card_id_domain") == WINDOWS_LOCAL_DECK_DOMAIN
    local_uids = (
        {
            entry.get("local_card_uid")
            for entry in deck.get("cards", [])
            if type(entry) is dict and type(entry.get("local_card_uid")) is str
        }
        if local_domain
        else set()
    )
    if local_domain and len(local_uids) != deck.get("unique_card_count"):
        return False
    if document.get("schema_version") == 2:
        if not local_domain:
            return False
        compiled = CompetitivePolicyV2Compiler.compile_local_uid(
            document,
            allowed_card_uids=local_uids,
        )
        return compiled.accepted and compiled.policy is not None
    if document.get("schema_version") != 1:
        return False
    seen = set()
    for rule in document["rules"]:
        if type(rule) is not dict or set(rule) != {
            "rule_id",
            "operator",
            "reason_code",
            "goal_stage",
            "priority",
            "predicate",
        }:
            return False
        if (
            type(rule["rule_id"]) is not str
            or not rule["rule_id"]
            or rule["rule_id"] in seen
            or rule["operator"] not in ADAPTER_OPERATORS
            or rule["reason_code"] != ADAPTER_REASONS[rule["operator"]]
            or rule["goal_stage"] not in GOAL_STAGES
            or type(rule["priority"]) is not int
            or not 0 <= rule["priority"] <= 9007199254740991
            or type(rule["predicate"]) is not dict
            or set(rule["predicate"]) != PREDICATE_FIELDS
        ):
            return False
        for field, value in rule["predicate"].items():
            if value is None:
                continue
            if local_domain and field in CARD_PREDICATE_FIELDS:
                if type(value) is not str or value not in local_uids:
                    return False
            elif type(value) is not int or not 0 <= value <= 9007199254740991:
                return False
        seen.add(rule["rule_id"])
    return True


def _image_dimensions(value: bytes, kind: str) -> tuple[int, int] | None:
    if kind == "png":
        if len(value) < 24 or value[:8] != b"\x89PNG\r\n\x1a\n" or value[12:16] != b"IHDR":
            return None
        return int.from_bytes(value[16:20], "big"), int.from_bytes(value[20:24], "big")
    if len(value) < 30 or value[:4] != b"RIFF" or value[8:12] != b"WEBP":
        return None
    chunk = value[12:16]
    if chunk == b"VP8X":
        return 1 + int.from_bytes(value[24:27], "little"), 1 + int.from_bytes(value[27:30], "little")
    if chunk == b"VP8 " and len(value) >= 30 and value[23:26] == b"\x9d\x01\x2a":
        return int.from_bytes(value[26:28], "little") & 0x3FFF, int.from_bytes(value[28:30], "little") & 0x3FFF
    if chunk == b"VP8L" and len(value) >= 25 and value[20] == 0x2F:
        b1, b2, b3, b4 = value[21:25]
        width = 1 + b1 + ((b2 & 0x3F) << 8)
        height = 1 + ((b2 & 0xC0) >> 6) + (b3 << 2) + ((b4 & 0x0F) << 10)
        return width, height
    return None


def _raw_zip_names(archive_bytes: bytes, max_entry_count: int) -> list[str]:
    eocd_offset = archive_bytes.rfind(b"PK\x05\x06", max(0, len(archive_bytes) - 65557))
    if eocd_offset < 0 or eocd_offset + 22 > len(archive_bytes):
        _raise("package_archive_invalid")
    try:
        (
            signature,
            disk_number,
            central_disk,
            disk_entries,
            total_entries,
            central_size,
            central_offset,
            comment_length,
        ) = struct.unpack_from("<4s4H2LH", archive_bytes, eocd_offset)
    except struct.error:
        _raise("package_archive_invalid")
    if (
        signature != b"PK\x05\x06"
        or disk_number != 0
        or central_disk != 0
        or disk_entries != total_entries
        or total_entries == 0xFFFF
        or central_size == 0xFFFFFFFF
        or central_offset == 0xFFFFFFFF
        or comment_length != 0
        or eocd_offset + 22 != len(archive_bytes)
        or central_offset + central_size != eocd_offset
    ):
        _raise("package_archive_invalid")
    if total_entries > max_entry_count:
        _raise("package_resource_limit_exceeded")
    cursor = central_offset
    names: list[str] = []
    for _index in range(total_entries):
        if cursor + 46 > eocd_offset or archive_bytes[cursor : cursor + 4] != b"PK\x01\x02":
            _raise("package_archive_invalid")
        try:
            name_length, extra_length, entry_comment_length = struct.unpack_from("<3H", archive_bytes, cursor + 28)
            local_offset = struct.unpack_from("<L", archive_bytes, cursor + 42)[0]
        except struct.error:
            _raise("package_archive_invalid")
        end = cursor + 46 + name_length + extra_length + entry_comment_length
        if end > eocd_offset or local_offset + 30 > central_offset:
            _raise("package_archive_invalid")
        raw_name = archive_bytes[cursor + 46 : cursor + 46 + name_length]
        try:
            name = raw_name.decode("ascii")
        except UnicodeDecodeError:
            _raise("package_path_invalid")
        if archive_bytes[local_offset : local_offset + 4] != b"PK\x03\x04":
            _raise("package_archive_invalid")
        try:
            local_name_length, local_extra_length = struct.unpack_from("<2H", archive_bytes, local_offset + 26)
        except struct.error:
            _raise("package_archive_invalid")
        local_name = archive_bytes[local_offset + 30 : local_offset + 30 + local_name_length]
        if local_name != raw_name or local_extra_length != 0:
            _raise("package_archive_invalid")
        names.append(name)
        cursor = end
    if cursor != eocd_offset:
        _raise("package_archive_invalid")
    return names


class AuthorStrategyPackageLoader:
    def __init__(self, *, contract_root: Path | None = None) -> None:
        self._contract_root = DEFAULT_CONTRACT_ROOT if contract_root is None else Path(contract_root)
        self._documents = self._load_contracts()
        self._schema_validator = Draft202012Validator(self._documents["schema"])
        self._competitive_policy_v2_documents = self._load_competitive_policy_v2_contracts()
        self._competitive_policy_v2_validator = Draft202012Validator(
            self._competitive_policy_v2_documents["schema"]
        )
        self._windows_local_deck_documents = self._load_windows_local_deck_contracts()
        self._windows_local_deck_validator = Draft202012Validator(self._windows_local_deck_documents["schema"])
        self._profile = self._documents["profile"]
        self._limits = self._profile["resource_limits"]
        self._trust_store = {
            entry["key_id"]: copy.deepcopy(entry) for entry in self._profile["trust_store"]["keys"]
        }
        self._release_gate = AuthorStrategyReleaseGate(ROOT)
        for entry in self._release_gate.trusted_release_keys():
            key_id = entry["key_id"]
            if key_id in self._trust_store:
                _raise("package_integrity_invalid")
            self._trust_store[key_id] = copy.deepcopy(entry)

    def _load_contracts(self) -> dict[str, dict[str, Any]]:
        try:
            documents = {
                artifact_id: load_json_strict(self._contract_root / filename)
                for artifact_id, filename in CONTRACT_FILENAMES.items()
            }
            bundle_hash = _sha(canonical_json_v1_bytes(documents["bundle"]))
        except (OSError, UnicodeDecodeError, ValueError, TypeError):
            _raise("package_integrity_invalid")
        if bundle_hash != EXPECTED_BUNDLE_CANONICAL_SHA256:
            _raise("package_integrity_invalid")
        bundle = documents["bundle"]
        if (
            bundle.get("schema_version") != 1
            or bundle.get("bundle_id") != BUNDLE_ID
            or bundle.get("profile_id") != PROFILE_ID
            or type(bundle.get("artifacts")) is not list
            or len(bundle["artifacts"]) != 3
        ):
            _raise("package_integrity_invalid")
        expected_paths = {
            artifact_id: f"contracts/ptcgdap/{CONTRACT_FILENAMES[artifact_id]}"
            for artifact_id in EXPECTED_ARTIFACT_CANONICAL_SHA256
        }
        seen = set()
        for entry in bundle["artifacts"]:
            if type(entry) is not dict or set(entry) != {"id", "path", "canonical_sha256"}:
                _raise("package_integrity_invalid")
            artifact_id = entry["id"]
            if artifact_id not in expected_paths or artifact_id in seen:
                _raise("package_integrity_invalid")
            actual = _sha(canonical_json_v1_bytes(documents[artifact_id]))
            if (
                entry["path"] != expected_paths[artifact_id]
                or entry["canonical_sha256"] != EXPECTED_ARTIFACT_CANONICAL_SHA256[artifact_id]
                or actual != EXPECTED_ARTIFACT_CANONICAL_SHA256[artifact_id]
            ):
                _raise("package_integrity_invalid")
            seen.add(artifact_id)
        if seen != set(EXPECTED_ARTIFACT_CANONICAL_SHA256):
            _raise("package_integrity_invalid")
        profile = documents["profile"]
        if (
            profile.get("schema_version") != 1
            or profile.get("profile_id") != PROFILE_ID
            or profile.get("trust_store", {}).get("caller_overrides") is not False
        ):
            _raise("package_integrity_invalid")
        return documents

    def _load_competitive_policy_v2_contracts(self) -> dict[str, dict[str, Any]]:
        try:
            documents = {
                artifact_id: load_json_strict(self._contract_root / filename)
                for artifact_id, filename in COMPETITIVE_POLICY_V2_CONTRACT_FILENAMES.items()
            }
            bundle_hash = _sha(canonical_json_v1_bytes(documents["bundle"]))
        except (OSError, UnicodeDecodeError, ValueError, TypeError):
            _raise("package_integrity_invalid")
        bundle = documents["bundle"]
        if (
            bundle_hash != COMPETITIVE_POLICY_V2_EXPECTED_BUNDLE_CANONICAL_SHA256
            or bundle.get("schema_version") != 2
            or bundle.get("bundle_id") != COMPETITIVE_POLICY_V2_BUNDLE_ID
            or bundle.get("profile_id") != COMPETITIVE_POLICY_V2_PROFILE_ID
            or bundle.get("parent_author_package_bundle_canonical_sha256")
            != EXPECTED_BUNDLE_CANONICAL_SHA256
            or type(bundle.get("artifacts")) is not list
            or len(bundle["artifacts"]) != 3
        ):
            _raise("package_integrity_invalid")
        seen = set()
        for entry in bundle["artifacts"]:
            if type(entry) is not dict or set(entry) != {"id", "path", "canonical_sha256"}:
                _raise("package_integrity_invalid")
            artifact_id = entry["id"]
            if (
                artifact_id not in COMPETITIVE_POLICY_V2_EXPECTED_ARTIFACT_CANONICAL_SHA256
                or artifact_id in seen
            ):
                _raise("package_integrity_invalid")
            expected_path = f"contracts/ptcgdap/{COMPETITIVE_POLICY_V2_CONTRACT_FILENAMES[artifact_id]}"
            expected_hash = COMPETITIVE_POLICY_V2_EXPECTED_ARTIFACT_CANONICAL_SHA256[artifact_id]
            if (
                entry["path"] != expected_path
                or entry["canonical_sha256"] != expected_hash
                or _sha(canonical_json_v1_bytes(documents[artifact_id])) != expected_hash
            ):
                _raise("package_integrity_invalid")
            seen.add(artifact_id)
        if seen != set(COMPETITIVE_POLICY_V2_EXPECTED_ARTIFACT_CANONICAL_SHA256):
            _raise("package_integrity_invalid")
        profile = documents["profile"]
        if (
            profile.get("schema_version") != 2
            or profile.get("profile_id") != COMPETITIVE_POLICY_V2_PROFILE_ID
            or profile.get("official_policy_boundary") != "agent(raw_observation)->list[int]"
            or profile.get("compatibility", {}).get("v1_behavior_unchanged") is not True
        ):
            _raise("package_integrity_invalid")
        return documents

    def _load_windows_local_deck_contracts(self) -> dict[str, dict[str, Any]]:
        try:
            documents = {
                artifact_id: load_json_strict(self._contract_root / filename)
                for artifact_id, filename in WINDOWS_LOCAL_DECK_CONTRACT_FILENAMES.items()
            }
            bundle_hash = _sha(canonical_json_v1_bytes(documents["bundle"]))
        except (OSError, UnicodeDecodeError, ValueError, TypeError):
            _raise("package_integrity_invalid")
        bundle = documents["bundle"]
        if (
            bundle_hash != WINDOWS_LOCAL_DECK_EXPECTED_BUNDLE_CANONICAL_SHA256
            or bundle.get("schema_version") != 1
            or bundle.get("bundle_id") != WINDOWS_LOCAL_DECK_BUNDLE_ID
            or bundle.get("profile_id") != WINDOWS_LOCAL_DECK_PROFILE_ID
            or bundle.get("parent_author_package_bundle_canonical_sha256") != EXPECTED_BUNDLE_CANONICAL_SHA256
            or type(bundle.get("artifacts")) is not list
            or len(bundle["artifacts"]) != 3
        ):
            _raise("package_integrity_invalid")
        seen = set()
        for entry in bundle["artifacts"]:
            if type(entry) is not dict or set(entry) != {"id", "path", "canonical_sha256"}:
                _raise("package_integrity_invalid")
            artifact_id = entry["id"]
            if artifact_id not in WINDOWS_LOCAL_DECK_EXPECTED_ARTIFACT_CANONICAL_SHA256 or artifact_id in seen:
                _raise("package_integrity_invalid")
            expected_path = f"contracts/ptcgdap/{WINDOWS_LOCAL_DECK_CONTRACT_FILENAMES[artifact_id]}"
            expected_hash = WINDOWS_LOCAL_DECK_EXPECTED_ARTIFACT_CANONICAL_SHA256[artifact_id]
            if (
                entry["path"] != expected_path
                or entry["canonical_sha256"] != expected_hash
                or _sha(canonical_json_v1_bytes(documents[artifact_id])) != expected_hash
            ):
                _raise("package_integrity_invalid")
            seen.add(artifact_id)
        profile = documents["profile"]
        if (
            seen != set(WINDOWS_LOCAL_DECK_EXPECTED_ARTIFACT_CANONICAL_SHA256)
            or profile.get("profile_id") != WINDOWS_LOCAL_DECK_PROFILE_ID
            or profile.get("supported_platforms") != ["windows"]
            or profile.get("card_id_domain") != WINDOWS_LOCAL_DECK_DOMAIN
            or profile.get("cabt_exportable") is not False
        ):
            _raise("package_integrity_invalid")
        return documents

    def contract_report(self) -> dict[str, Any]:
        release = self._release_gate.audit_snapshot()
        return {
            "profile_id": PROFILE_ID,
            "bundle_id": BUNDLE_ID,
            "bundle_canonical_sha256": EXPECTED_BUNDLE_CANONICAL_SHA256,
            "competitive_policy_v2_bundle_canonical_sha256": COMPETITIVE_POLICY_V2_EXPECTED_BUNDLE_CANONICAL_SHA256,
            "windows_local_deck_bundle_canonical_sha256": WINDOWS_LOCAL_DECK_EXPECTED_BUNDLE_CANONICAL_SHA256,
            "windows_local_deck_card_id_domain": WINDOWS_LOCAL_DECK_DOMAIN,
            "test_fixture_key_execution_trusted": False,
            "production_trust_status": release["production_trust_status"],
            "active_production_key_count": release["active_production_key_count"],
            "live_consumer": False,
            "execution_authority": False,
        }

    def load_path(self, path: Path, *, expected_archive_sha256: str | None = None) -> AuthorStrategyPackageHandle:
        try:
            value = Path(path).read_bytes()
        except OSError:
            _raise("package_archive_invalid")
        return self.load_bytes(value, expected_archive_sha256=expected_archive_sha256)

    def load_bytes(
        self,
        archive_bytes: bytes,
        *,
        expected_archive_sha256: str | None = None,
    ) -> AuthorStrategyPackageHandle:
        if type(archive_bytes) is not bytes or not archive_bytes:
            _raise("package_archive_invalid")
        if len(archive_bytes) > self._limits["max_archive_bytes"]:
            _raise("package_resource_limit_exceeded")
        archive_sha = _sha(archive_bytes)
        if expected_archive_sha256 is not None:
            if type(expected_archive_sha256) is not str or not HEX_RE.fullmatch(expected_archive_sha256):
                _raise("package_integrity_invalid")
            if expected_archive_sha256 != archive_sha:
                _raise("package_integrity_invalid")
        members = self._read_archive(archive_bytes)
        return self._validate_members(members, archive_sha)

    def _read_archive(self, archive_bytes: bytes) -> dict[str, bytes]:
        raw_names = _raw_zip_names(archive_bytes, self._limits["max_entry_count"])
        try:
            with zipfile.ZipFile(io.BytesIO(archive_bytes), "r") as archive:
                if archive.comment != b"":
                    _raise("package_archive_invalid")
                infos = archive.infolist()
                if len(infos) != len(raw_names):
                    _raise("package_archive_invalid")
                names = []
                folded = set()
                for info, raw_name in zip(infos, raw_names):
                    name = _safe_path(raw_name, self._limits["max_path_bytes"])
                    if info.filename != raw_name:
                        _raise("package_archive_invalid")
                    if name in names or name.casefold() in folded:
                        _raise("package_duplicate_path")
                    names.append(name)
                    folded.add(name.casefold())
                if len(infos) > self._limits["max_entry_count"]:
                    _raise("package_resource_limit_exceeded")
                total = 0
                for info in infos:
                    if info.file_size > self._limits["max_single_file_bytes"]:
                        _raise("package_resource_limit_exceeded")
                    total += info.file_size
                    if total > self._limits["max_uncompressed_bytes"]:
                        _raise("package_resource_limit_exceeded")
                    if info.file_size > self._limits["max_compression_ratio"] * max(info.compress_size, 1):
                        _raise("package_resource_limit_exceeded")
                if names != sorted(names, key=lambda value: value.encode("ascii")):
                    _raise("package_archive_invalid")
                for info in infos:
                    if (
                        info.date_time != FIXED_TIME
                        or info.compress_type != zipfile.ZIP_STORED
                        or info.create_system != 3
                        or info.external_attr != FIXED_MODE
                        or info.internal_attr != 0
                        or info.flag_bits != 0
                        or info.extra != b""
                        or info.comment != b""
                        or info.volume != 0
                        or info.is_dir()
                    ):
                        _raise("package_archive_invalid")
                members = {info.filename: archive.read(info) for info in infos}
        except AuthorStrategyPackageError:
            raise
        except (zipfile.BadZipFile, RuntimeError, OSError, EOFError, ValueError):
            _raise("package_archive_invalid")
        return members

    def _validate_package_manifest(self, members: dict[str, bytes]) -> dict[str, Any]:
        try:
            raw = load_json_bytes_strict(members["strategy_package.json"])
        except (UnicodeDecodeError, ValueError, TypeError):
            _raise("package_manifest_invalid")
        if type(raw) is not dict or raw.get("document_type") != "strategy_package_v2":
            return _strict_json(
                members["strategy_package.json"],
                self._schema_validator,
                "package_manifest_invalid",
            )
        try:
            manifest = validate_v2_package_manifest(raw, members)
        except ModelPackageError as error:
            _raise(error.code)
        compatibility_copy = copy.deepcopy(manifest)
        compatibility_copy["document_type"] = "strategy_package_v1"
        compatibility_copy["schema_version"] = 1
        compatibility_copy["compatibility"]["minimum_game_api"] = "ptcgdap-author-host-v1"
        compatibility_copy["policy"] = {
            key: compatibility_copy["policy"][key]
            for key in (
                "entry_kind",
                "ir_path",
                "adapter_path",
                "config_path",
                "weights_path",
            )
        }
        if not self._schema_validator.is_valid(compatibility_copy):
            _raise("package_manifest_invalid")
        return manifest

    def _validate_members(self, members: dict[str, bytes], archive_sha: str) -> AuthorStrategyPackageHandle:
        names = set(members)
        for path in names:
            suffix = PurePosixPath(path).suffix.casefold()
            if suffix in FORBIDDEN_SUFFIXES:
                _raise("package_policy_unsupported")
        allowed = REQUIRED_PAYLOAD_PATHS | GENERATED_PATHS | set(OPTIONAL_PAYLOAD_KINDS)
        if names - allowed:
            _raise("package_file_unlisted")
        required = REQUIRED_PAYLOAD_PATHS | GENERATED_PATHS
        if required - names:
            _raise("package_file_missing")
        self._validate_kind_sizes(members)

        manifest = self._validate_package_manifest(members)
        files_manifest = _strict_json(members["files.sha256.json"], self._schema_validator, "package_manifest_invalid")
        signature = _strict_json(members["signature.json"], self._schema_validator, "package_manifest_invalid")

        listed_entries = files_manifest["files"]
        listed_paths = [entry["path"] for entry in listed_entries]
        if listed_paths != sorted(listed_paths, key=lambda value: value.encode("ascii")) or len(listed_paths) != len(set(listed_paths)):
            _raise("package_manifest_invalid")
        actual_payload_paths = names - GENERATED_PATHS
        listed_set = set(listed_paths)
        if listed_set - actual_payload_paths:
            _raise("package_file_missing")
        if actual_payload_paths - listed_set:
            _raise("package_file_unlisted")
        for entry in listed_entries:
            path = entry["path"]
            expected_kind = FIXED_PAYLOAD_KINDS.get(path, OPTIONAL_PAYLOAD_KINDS.get(path))
            if expected_kind is None or entry["kind"] != expected_kind:
                _raise("package_manifest_invalid")
            value = members[path]
            if entry["bytes"] != len(value) or entry["sha256"] != _sha(value):
                _raise("package_file_hash_mismatch")

        signature_key = self._verify_signature(manifest, signature, members)
        self._verify_compatibility(manifest)
        deck_manifest, policy_ir, adapter, config = self._verify_deck_and_policy(manifest, members)
        model_manifest = self._verify_optional_relations(manifest, members)

        manifest_sha = _sha(members["strategy_package.json"])
        manifest_canonical = _sha(canonical_json_v1_bytes(manifest))
        files_sha = _sha(members["files.sha256.json"])
        policy_sha = _sha(members["policy/policy_ir.json"])
        deck_sha = _sha(members["deck/deck_manifest.json"])
        signature_scope = str(signature_key["scope"])
        execution_trusted = signature_key.get("execution_trusted") is True
        signature_status = "production_trusted" if execution_trusted else "test_fixture_trusted"
        metadata = {
            "profile_id": "ptcgdap-author-strategy-package-v2" if manifest["schema_version"] == 2 else PROFILE_ID,
            "package_document_type": manifest["document_type"],
            "package_id": manifest["package_id"],
            "package_version": manifest["package_version"],
            "archive_sha256": archive_sha,
            "manifest_sha256": manifest_sha,
            "manifest_canonical_sha256": manifest_canonical,
            "files_manifest_sha256": files_sha,
            "policy_ir_sha256": policy_sha,
            "deck_manifest_sha256": deck_sha,
            "author": copy.deepcopy(manifest["author"]),
            "strategy": copy.deepcopy(manifest["strategy"]),
            "deck": copy.deepcopy(manifest["deck"]),
            "compatibility": copy.deepcopy(manifest["compatibility"]),
            "signature_status": signature_status,
            "execution_trusted": execution_trusted,
            "metadata_only": True,
            "live_consumer": False,
            "execution_authority": False,
            "deck_contract_valid": deck_manifest["card_count"] == 60,
            "policy_contract_valid": bool(policy_ir and adapter and config),
            "policy_mode": manifest["policy"].get("policy_mode", "rules_only"),
            "model_manifest_sha256": _sha(members[MODEL_MANIFEST_PATH]) if model_manifest is not None else None,
            "model_artifact_sha256": _sha(members[MODEL_ARTIFACT_PATH]) if model_manifest is not None else None,
            "source_deck_id": deck_manifest.get("source_deck_id"),
            "deck_card_id_domain": deck_manifest.get("card_id_domain"),
            "deck_platform_scope": copy.deepcopy(deck_manifest.get("platform_scope", [])),
            "deck_card_count": deck_manifest.get("card_count"),
        }
        if execution_trusted:
            metadata["signature_key_id"] = signature["key_id"]
            metadata["signature_scope"] = signature_scope
        frozen_payloads = MappingProxyType({path: members[path] for path in actual_payload_paths})
        return AuthorStrategyPackageHandle(
            profile_id=PROFILE_ID,
            package_id=manifest["package_id"],
            package_version=manifest["package_version"],
            archive_sha256=archive_sha,
            manifest_sha256=manifest_sha,
            manifest_canonical_sha256=manifest_canonical,
            files_manifest_sha256=files_sha,
            policy_ir_sha256=policy_sha,
            deck_manifest_sha256=deck_sha,
            signature_status=signature_status,
            signature_key_id=signature["key_id"],
            signature_scope=signature_scope,
            execution_trusted=execution_trusted,
            _metadata_json=canonical_json_v1_bytes(metadata),
            _payloads=frozen_payloads,
        )

    def _validate_kind_sizes(self, members: dict[str, bytes]) -> None:
        per_kind = {
            "json": self._limits["max_json_bytes"],
            "text": self._limits["max_text_bytes"],
            "csv": self._limits["max_csv_bytes"],
            "weights": self._limits["max_weights_bytes"],
            "png": self._limits["max_image_bytes"],
            "webp": self._limits["max_image_bytes"],
        }
        for path, value in members.items():
            kind = FIXED_PAYLOAD_KINDS.get(path, OPTIONAL_PAYLOAD_KINDS.get(path))
            if kind is not None and len(value) > per_kind[kind]:
                _raise("package_resource_limit_exceeded")
            if kind in {"png", "webp"}:
                dimensions = _image_dimensions(value, kind)
                if dimensions is None:
                    _raise("package_policy_unsupported")
                width, height = dimensions
                if width < 1 or height < 1 or width > self._limits["max_image_width"] or height > self._limits["max_image_height"]:
                    _raise("package_resource_limit_exceeded")

    def _verify_signature(
        self,
        manifest: dict[str, Any],
        signature: dict[str, Any],
        members: dict[str, bytes],
    ) -> dict[str, Any]:
        key = self._trust_store.get(signature["key_id"])
        is_test_key = key is not None and key.get("scope") == "test_fixture_only" and key.get("execution_trusted") is False
        is_release_key = (
            key is not None
            and key.get("scope") == "production_release"
            and key.get("execution_trusted") is True
            and key.get("status") == "active"
        )
        if not is_test_key and not is_release_key:
            _raise("package_signature_untrusted")
        signed_payload = {
            "schema_version": 1,
            "domain": "ptcgdap-author-strategy-package-signature-v1",
            "package_id": manifest["package_id"],
            "package_version": manifest["package_version"],
            "manifest_sha256": _sha(members["strategy_package.json"]),
            "files_manifest_sha256": _sha(members["files.sha256.json"]),
        }
        signed_bytes = canonical_json_v1_bytes(signed_payload)
        if signature["signed_payload_sha256"] != _sha(signed_bytes):
            _raise("package_signature_untrusted")
        try:
            public_key = base64.b64decode(key["public_key_base64"], validate=True)
            raw_signature = base64.b64decode(signature["signature_base64"], validate=True)
            if len(public_key) != 32 or len(raw_signature) != 64:
                _raise("package_signature_untrusted")
            Ed25519PublicKey.from_public_bytes(public_key).verify(raw_signature, signed_bytes)
        except AuthorStrategyPackageError:
            raise
        except (ValueError, InvalidSignature):
            _raise("package_signature_untrusted")
        return copy.deepcopy(key)

    def _verify_compatibility(self, manifest: dict[str, Any]) -> None:
        compatibility = manifest["compatibility"]
        expected_game_api = (
            "ptcgdap-author-host-v2"
            if manifest.get("document_type") == "strategy_package_v2"
            else "ptcgdap-author-host-v1"
        )
        if (
            compatibility["minimum_game_api"] != expected_game_api
            or compatibility["cabt_contract_sha256"] != CABT_CONTRACT_SHA256
            or compatibility["base_executor_sha256"] != BASE_EXECUTOR_SHA256
        ):
            _raise("package_contract_incompatible")
        if compatibility["card_catalog_sha256"] != CARD_CATALOG_SHA256:
            _raise("package_catalog_incompatible")
        if any(capability not in SUPPORTED_CAPABILITIES for capability in compatibility["required_capabilities"]):
            _raise("package_policy_unsupported")

    def _verify_deck_and_policy(
        self,
        manifest: dict[str, Any],
        members: dict[str, bytes],
    ) -> tuple[dict[str, Any], dict[str, Any], dict[str, Any], dict[str, Any]]:
        try:
            raw_deck = load_json_bytes_strict(members["deck/deck_manifest.json"])
        except (UnicodeDecodeError, ValueError, TypeError):
            _raise("package_deck_unmapped")
        if type(raw_deck) is not dict:
            _raise("package_deck_unmapped")
        if raw_deck.get("document_type") == "deck_manifest_windows_local_v1":
            deck = _strict_json(
                members["deck/deck_manifest.json"],
                self._windows_local_deck_validator,
                "package_deck_unmapped",
            )
        else:
            deck = _strict_json(members["deck/deck_manifest.json"], self._schema_validator, "package_deck_unmapped")
        policy_ir = _strict_json(members["policy/policy_ir.json"], self._schema_validator, "package_policy_unsupported")
        try:
            raw_adapter = load_json_bytes_strict(members["policy/adapter.json"])
        except (UnicodeDecodeError, ValueError, TypeError):
            _raise("package_policy_unsupported")
        if type(raw_adapter) is not dict:
            _raise("package_policy_unsupported")
        adapter_validator = (
            self._competitive_policy_v2_validator
            if raw_adapter.get("schema_version") == 2
            else self._schema_validator
        )
        adapter = _strict_json(
            members["policy/adapter.json"],
            adapter_validator,
            "package_policy_unsupported",
        )
        config = _strict_json(members["policy/config.json"], self._schema_validator, "package_policy_unsupported")
        if _contains_forbidden_policy_key(policy_ir) or _contains_forbidden_policy_key(adapter) or _contains_forbidden_policy_key(config):
            _raise("package_policy_unsupported")
        self._verify_deck_csv(deck, members["deck/deck.csv"])
        if not _restricted_ir_valid(policy_ir):
            _raise("package_policy_unsupported")
        if not _public_adapter_valid(adapter, deck):
            _raise("package_policy_unsupported")
        if deck.get("card_id_domain") == WINDOWS_LOCAL_DECK_DOMAIN:
            values = config.get("values")
            if (
                type(values) is not dict
                or values.get("card_id_domain") != WINDOWS_LOCAL_DECK_DOMAIN
                or values.get("source_deck_id") != deck.get("source_deck_id")
                or values.get("cabt_exportable") is not False
            ):
                _raise("package_policy_unsupported")
            if values.get("deck_manifest_sha256") != _sha(members["deck/deck_manifest.json"]):
                _raise("package_deck_unmapped")
        if manifest["policy"]["entry_kind"] != "restricted_policy_ir_v1":
            _raise("package_policy_unsupported")
        return deck, policy_ir, adapter, config

    def _verify_deck_csv(self, deck: dict[str, Any], value: bytes) -> None:
        if deck["deck_csv_sha256"] != _sha(value):
            _raise("package_deck_unmapped")
        try:
            text = value.decode("ascii")
        except UnicodeDecodeError:
            _raise("package_deck_unmapped")
        if not text.endswith("\n") or "\r" in text:
            _raise("package_deck_unmapped")
        try:
            rows = list(csv.reader(io.StringIO(text, newline="")))
        except csv.Error:
            _raise("package_deck_unmapped")
        local_domain = deck.get("card_id_domain") == WINDOWS_LOCAL_DECK_DOMAIN
        expected_header = ["local_card_uid", "count"] if local_domain else ["card_id", "count"]
        if not rows or rows[0] != expected_header or len(rows) < 2:
            _raise("package_deck_unmapped")
        if local_domain:
            self._verify_windows_local_deck_rows(deck, rows[1:])
            return
        total = 0
        seen = set()
        previous = -1
        for row in rows[1:]:
            if len(row) != 2 or not row[0].isdigit() or not row[1].isdigit():
                _raise("package_deck_unmapped")
            if (len(row[0]) > 1 and row[0].startswith("0")) or (len(row[1]) > 1 and row[1].startswith("0")):
                _raise("package_deck_unmapped")
            card_id, count = int(row[0]), int(row[1])
            if card_id < 0 or card_id > 9007199254740991 or count < 1 or count > 60 or card_id in seen or card_id <= previous:
                _raise("package_deck_unmapped")
            seen.add(card_id)
            previous = card_id
            total += count
        if total != 60 or deck["card_count"] != 60:
            _raise("package_deck_unmapped")

    def _verify_windows_local_deck_rows(self, deck: dict[str, Any], rows: list[list[str]]) -> None:
        if (
            deck.get("document_type") != "deck_manifest_windows_local_v1"
            or deck.get("schema_version") != 1
            or deck.get("card_id_domain") != WINDOWS_LOCAL_DECK_DOMAIN
            or deck.get("platform_scope") != ["windows"]
            or deck.get("cabt_exportable") is not False
            or type(deck.get("cards")) is not list
        ):
            _raise("package_deck_unmapped")
        parsed: list[tuple[str, int]] = []
        previous = ""
        total = 0
        for row in rows:
            if len(row) != 2 or PATH_RE.fullmatch(row[0]) is None or "/" in row[0] or not row[1].isdigit():
                _raise("package_deck_unmapped")
            uid, raw_count = row
            if uid.count("_") != 1 or "_" not in uid or (len(raw_count) > 1 and raw_count.startswith("0")):
                _raise("package_deck_unmapped")
            set_code, card_index = uid.split("_", 1)
            if not set_code or not card_index or uid.encode("ascii") <= previous.encode("ascii"):
                _raise("package_deck_unmapped")
            count = int(raw_count)
            if not 1 <= count <= 60:
                _raise("package_deck_unmapped")
            parsed.append((uid, count))
            previous = uid
            total += count
        cards = deck["cards"]
        manifest_rows: list[tuple[str, int]] = []
        basic_pokemon = 0
        for entry in cards:
            if type(entry) is not dict:
                _raise("package_deck_unmapped")
            uid = entry.get("local_card_uid")
            set_code = entry.get("set_code")
            card_index = entry.get("card_index")
            count = entry.get("count")
            if (
                type(uid) is not str
                or type(set_code) is not str
                or type(card_index) is not str
                or uid != f"{set_code}_{card_index}"
                or type(count) is not int
                or not 1 <= count <= 60
                or (count > 4 and entry.get("card_type") != "Basic Energy")
            ):
                _raise("package_deck_unmapped")
            if entry.get("card_type") == "Pokemon" and entry.get("stage") == "Basic":
                basic_pokemon += count
            manifest_rows.append((uid, count))
        if (
            parsed != manifest_rows
            or len(cards) != deck.get("unique_card_count")
            or len(cards) != len({uid for uid, _count in manifest_rows})
            or total != 60
            or deck.get("card_count") != 60
            or basic_pokemon < 1
        ):
            _raise("package_deck_unmapped")

    def _verify_optional_relations(
        self,
        manifest: dict[str, Any],
        members: dict[str, bytes],
    ) -> dict[str, Any] | None:
        expected = set()
        weights_path = manifest["policy"]["weights_path"]
        if weights_path is not None:
            expected.add(weights_path)
        for key in ("icon_path", "banner_path"):
            path = manifest["presentation"][key]
            if path is not None:
                expected.add(path)
        model_manifest = None
        if manifest.get("document_type") == "strategy_package_v2":
            policy = manifest["policy"]
            if policy["policy_mode"] == "rules_with_model":
                expected.update({MODEL_MANIFEST_PATH, MODEL_ARTIFACT_PATH})
                if "learned_policy_head_v1" not in manifest["compatibility"]["required_capabilities"]:
                    _raise("package_policy_unsupported")
                try:
                    model_manifest = load_model_manifest_bytes(
                        members[MODEL_MANIFEST_PATH],
                        members[MODEL_ARTIFACT_PATH],
                        cabt_contract_sha256=CABT_CONTRACT_SHA256,
                        card_catalog_sha256=CARD_CATALOG_SHA256,
                    )
                except ModelPackageError as error:
                    _raise(error.code)
        actual = set(members) & set(OPTIONAL_PAYLOAD_KINDS)
        if expected - actual:
            _raise("package_file_missing")
        if actual - expected:
            _raise("package_file_unlisted")
        return model_manifest


__all__ = [
    "AuthorStrategyPackageError",
    "AuthorStrategyPackageHandle",
    "AuthorStrategyPackageLoader",
    "BASE_EXECUTOR_SHA256",
    "BUNDLE_ID",
    "CABT_CONTRACT_SHA256",
    "CARD_CATALOG_SHA256",
    "EXPECTED_BUNDLE_CANONICAL_SHA256",
    "PROFILE_ID",
    "TEST_FIXTURE_KEY_ID",
]
