from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re
from types import MappingProxyType
from typing import Any, Mapping
import weakref

from scripts.ai.ptcgdap.author_strategy_package import (
    AuthorStrategyPackageHandle,
    BASE_EXECUTOR_SHA256,
    CABT_CONTRACT_SHA256,
    CARD_CATALOG_SHA256,
    WINDOWS_LOCAL_DECK_DOMAIN,
)
from scripts.ai.ptcgdap.cabt_selection import CabtSelectionWindow
from scripts.ai.ptcgdap.card_id_catalog import CardIdCatalog
from scripts.ai.ptcgdap.public_base_policy import PublicBasePolicyOrchestrator
from scripts.ai.ptcgdap.public_deck_adapter import (
    EXPECTED_LOCAL_BUNDLE_SHA256,
    LOCAL_CARD_ID_DOMAIN,
    OFFICIAL_CARD_ID_DOMAIN,
    PublicDeckAdapterCompiler,
    _local_context_error,
)
from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_bytes_strict, load_json_strict
from scripts.ai.ptcgdap.strategic_context_v18 import StrategicContextV18
from scripts.ai.ptcgdap.strategic_trace_v2 import RestrictedBaseGraphIRCompiler


PROFILE_ID = "ptcgdap-author-strategy-match-host-as-wp4-v1"
AUTHOR_PACKAGE_BUNDLE_SHA256 = "B416F2CBA2795B62126B6EF7B5F07A9000E84D5FA1DF62C1753CADC9E82E106B"
PORTABLE_BACKEND_ID = "gdscript_public_base_policy_v1"
PORTABLE_BACKEND_SHA256 = "18AAB663D9B429AC8657A75692F5DD8CF37C409CC057A328B57758C692FDB7F4"
AUDIT_PREFIX = b"PTCGDAP\0AUTHOR_STRATEGY_SHADOW_AUDIT_V1\0"
MAX_SAFE_INTEGER = 9_007_199_254_740_991
_IDENTIFIER = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")
_UPPER_SHA = re.compile(r"^[0-9A-F]{64}$")

_PIN_KEYS = {
    "schema_version",
    "profile_id",
    "package_id",
    "package_version",
    "archive_sha256",
    "manifest_sha256",
    "manifest_canonical_sha256",
    "files_manifest_sha256",
    "cabt_contract_sha256",
    "card_catalog_sha256",
    "base_executor_sha256",
    "policy_ir_sha256",
    "adapter_sha256",
    "config_sha256",
    "weights_sha256",
    "backend_id",
    "backend_sha256",
    "deck_manifest_sha256",
    "deck_csv_sha256",
    "deck_card_id_domain",
    "deck_platform_scope",
    "cabt_exportable",
    "local_deck_mapping_sha256",
    "local_deck_card_count",
    "local_deck_unique_printing_count",
    "signature_status",
    "execution_trusted",
    "development_shadow_ready",
    "live_authority",
}
_DECK_ROW_KEYS = {
    "official_card_id",
    "count",
    "set_code",
    "card_index",
    "source_canonical_json_v1_sha256",
    "card_type",
    "stage",
}
_WINDOWS_LOCAL_DECK_ROW_KEYS = {
    "local_card_uid",
    "count",
    "set_code",
    "card_index",
    "source_raw_sha256",
    "source_canonical_json_v1_sha256",
    "card_type",
    "stage",
    "effect_id",
}
_PROMPT_KEYS = {
    "prompt_id",
    "prompt_generation",
    "mandatory_indexes",
    "terminal_indexes",
    "base_hard_tiers",
    "base_vetoed_indexes",
}
_HANDLE_CLAIMS: weakref.WeakKeyDictionary[AuthorStrategyMatchHandle, str] = weakref.WeakKeyDictionary()
_PROMPT_CLAIMS: weakref.WeakKeyDictionary[AuthorStrategyShadowPrompt, str] = weakref.WeakKeyDictionary()


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def _json_bytes(value: object) -> bytes:
    return canonical_json_v1_bytes(value)


def _json_copy(value: bytes) -> Any:
    return json.loads(value.decode("utf-8"))


def _safe_int(value: object) -> bool:
    return type(value) is int and 0 <= value <= MAX_SAFE_INTEGER


def _identifier(value: object) -> bool:
    return type(value) is str and _IDENTIFIER.fullmatch(value) is not None


def _upper_sha(value: object) -> bool:
    return type(value) is str and _UPPER_SHA.fullmatch(value) is not None


def _index_list(value: object, option_count: int) -> bool:
    return (
        type(value) is list
        and len(value) == len(set(value))
        and all(type(index) is int and 0 <= index < option_count for index in value)
    )


def _tiers(value: object, option_count: int) -> bool:
    if type(value) is not list or len(value) != option_count:
        return False
    seen: set[int] = set()
    for entry in value:
        if type(entry) is not dict or set(entry) != {"index", "tier"}:
            return False
        index, tier = entry["index"], entry["tier"]
        if (
            type(index) is not int
            or not 0 <= index < option_count
            or index in seen
            or type(tier) is not list
            or not 1 <= len(tier) <= 8
            or not all(_safe_int(child) for child in tier)
        ):
            return False
        seen.add(index)
    return seen == set(range(option_count))


class AuthorStrategyMatchError(ValueError):
    def __init__(self, code: str) -> None:
        self.code = code
        super().__init__(code)


class AuthorStrategyExactDeckGate:
    __slots__ = ()

    @staticmethod
    def parse_deck_csv(value: bytes) -> list[dict[str, int]]:
        if type(value) is not bytes:
            raise AuthorStrategyMatchError("package_deck_unmapped")
        try:
            text = value.decode("ascii")
        except UnicodeDecodeError as exc:
            raise AuthorStrategyMatchError("package_deck_unmapped") from exc
        if not text.endswith("\n") or "\r" in text:
            raise AuthorStrategyMatchError("package_deck_unmapped")
        lines = text[:-1].split("\n")
        if not lines or lines[0] != "card_id,count":
            raise AuthorStrategyMatchError("package_deck_unmapped")
        rows: list[dict[str, int]] = []
        for line in lines[1:]:
            columns = line.split(",")
            if len(columns) != 2 or not all(column.isascii() and column.isdigit() for column in columns):
                raise AuthorStrategyMatchError("package_deck_unmapped")
            if any(len(column) > 1 and column.startswith("0") for column in columns):
                raise AuthorStrategyMatchError("package_deck_unmapped")
            rows.append({"official_card_id": int(columns[0]), "count": int(columns[1])})
        return rows

    @staticmethod
    def map_official_rows(rows: object, *, root: Path | None = None) -> list[dict[str, object]]:
        if type(rows) is not list or not rows:
            raise AuthorStrategyMatchError("package_deck_unmapped")
        repository_root = Path(root) if root is not None else Path(__file__).resolve().parents[3]
        catalog = CardIdCatalog.load_trusted_bundle(repository_root)
        mapped: list[dict[str, object]] = []
        total = 0
        previous = -1
        basic_pokemon = 0
        for row in rows:
            if type(row) is not dict or set(row) != {"official_card_id", "count"}:
                raise AuthorStrategyMatchError("package_deck_unmapped")
            card_id, count = row["official_card_id"], row["count"]
            if not _safe_int(card_id) or type(count) is not int or not 1 <= count <= 60 or card_id <= previous:
                raise AuthorStrategyMatchError("package_deck_unmapped")
            previous = card_id
            result = catalog.lookup_local_printing_for_official_card(card_id)
            if type(result) is not dict or not result.get("ok", False):
                raise AuthorStrategyMatchError("package_deck_unmapped")
            value = result.get("value")
            if type(value) is not dict or set(value) != {
                "local_printing",
                "official_card_id",
                "source_canonical_json_v1_sha256",
            }:
                raise AuthorStrategyMatchError("package_deck_unmapped")
            printing = value["local_printing"]
            if type(printing) is not dict or set(printing) != {"set_code", "card_index"}:
                raise AuthorStrategyMatchError("package_deck_unmapped")
            set_code, card_index = printing["set_code"], printing["card_index"]
            if not _identifier(set_code) or not _identifier(card_index):
                raise AuthorStrategyMatchError("package_deck_unmapped")
            card_path = repository_root / "data/bundled_user/cards" / f"{set_code}_{card_index}.json"
            try:
                card = load_json_strict(card_path)
            except (OSError, UnicodeDecodeError, ValueError) as exc:
                raise AuthorStrategyMatchError("package_deck_unmapped") from exc
            if type(card) is not dict or card.get("set_code") != set_code or card.get("card_index") != card_index:
                raise AuthorStrategyMatchError("package_deck_unmapped")
            if _sha(_json_bytes(card)) != value["source_canonical_json_v1_sha256"]:
                raise AuthorStrategyMatchError("package_deck_unmapped")
            card_type = card.get("card_type")
            stage = card.get("stage", "")
            if type(card_type) is not str or type(stage) is not str:
                raise AuthorStrategyMatchError("package_deck_unmapped")
            if count > 4 and card_type != "Basic Energy":
                raise AuthorStrategyMatchError("package_deck_unmapped")
            if card_type == "Pokemon" and stage == "Basic":
                basic_pokemon += count
            mapped.append(
                {
                    "official_card_id": card_id,
                    "count": count,
                    "set_code": set_code,
                    "card_index": card_index,
                    "source_canonical_json_v1_sha256": value["source_canonical_json_v1_sha256"],
                    "card_type": card_type,
                    "stage": stage,
                }
            )
            total += count
        if total != 60 or basic_pokemon < 1:
            raise AuthorStrategyMatchError("package_deck_unmapped")
        return mapped

    @staticmethod
    def parse_windows_local_deck_csv(value: bytes) -> list[dict[str, object]]:
        if type(value) is not bytes:
            raise AuthorStrategyMatchError("package_deck_unmapped")
        try:
            text = value.decode("ascii")
        except UnicodeDecodeError as exc:
            raise AuthorStrategyMatchError("package_deck_unmapped") from exc
        if not text.endswith("\n") or "\r" in text:
            raise AuthorStrategyMatchError("package_deck_unmapped")
        lines = text[:-1].split("\n")
        if not lines or lines[0] != "local_card_uid,count":
            raise AuthorStrategyMatchError("package_deck_unmapped")
        rows: list[dict[str, object]] = []
        previous = b""
        for line in lines[1:]:
            columns = line.split(",")
            if len(columns) != 2 or columns[0].count("_") != 1 or not columns[1].isascii() or not columns[1].isdigit():
                raise AuthorStrategyMatchError("package_deck_unmapped")
            uid, raw_count = columns
            set_code, card_index = uid.split("_", 1)
            try:
                encoded = uid.encode("ascii")
            except UnicodeEncodeError as exc:
                raise AuthorStrategyMatchError("package_deck_unmapped") from exc
            if (
                not _identifier(set_code)
                or not _identifier(card_index)
                or encoded <= previous
                or (len(raw_count) > 1 and raw_count.startswith("0"))
            ):
                raise AuthorStrategyMatchError("package_deck_unmapped")
            count = int(raw_count)
            if not 1 <= count <= 60:
                raise AuthorStrategyMatchError("package_deck_unmapped")
            rows.append({"local_card_uid": uid, "count": count})
            previous = encoded
        return rows

    @staticmethod
    def map_windows_local_rows(
        rows: object,
        manifest: object,
        *,
        root: Path | None = None,
    ) -> list[dict[str, object]]:
        if type(rows) is not list or not rows or type(manifest) is not dict:
            raise AuthorStrategyMatchError("package_deck_unmapped")
        repository_root = Path(root) if root is not None else Path(__file__).resolve().parents[3]
        if (
            manifest.get("document_type") != "deck_manifest_windows_local_v1"
            or manifest.get("schema_version") != 1
            or manifest.get("card_id_domain") != WINDOWS_LOCAL_DECK_DOMAIN
            or manifest.get("platform_scope") != ["windows"]
            or manifest.get("cabt_exportable") is not False
            or type(manifest.get("cards")) is not list
        ):
            raise AuthorStrategyMatchError("package_deck_unmapped")
        cards = manifest["cards"]
        expected_rows = [
            {"local_card_uid": entry.get("local_card_uid"), "count": entry.get("count")}
            for entry in cards
            if type(entry) is dict
        ]
        if rows != expected_rows or len(cards) != manifest.get("unique_card_count"):
            raise AuthorStrategyMatchError("package_deck_unmapped")
        mapped: list[dict[str, object]] = []
        total = 0
        basic_pokemon = 0
        for row, entry in zip(rows, cards, strict=True):
            uid, count = row["local_card_uid"], row["count"]
            if type(uid) is not str or type(count) is not int or type(entry) is not dict:
                raise AuthorStrategyMatchError("package_deck_unmapped")
            set_code, card_index = uid.split("_", 1)
            if (
                entry.get("set_code") != set_code
                or entry.get("card_index") != card_index
                or entry.get("count") != count
            ):
                raise AuthorStrategyMatchError("package_deck_unmapped")
            card_path = repository_root / "data/bundled_user/cards" / f"{uid}.json"
            try:
                card_bytes = card_path.read_bytes()
                card = load_json_strict(card_path)
            except (OSError, UnicodeDecodeError, ValueError) as exc:
                raise AuthorStrategyMatchError("package_deck_unmapped") from exc
            card_type = card.get("card_type")
            stage = card.get("stage", "")
            effect_id = card.get("effect_id")
            if (
                card.get("set_code") != set_code
                or card.get("card_index") != card_index
                or _sha(card_bytes) != entry.get("source_raw_sha256")
                or _sha(_json_bytes(card)) != entry.get("source_canonical_sha256")
                or card_type != entry.get("card_type")
                or stage != entry.get("stage")
                or effect_id != entry.get("effect_id")
                or (count > 4 and card_type != "Basic Energy")
            ):
                raise AuthorStrategyMatchError("package_deck_unmapped")
            if card_type == "Pokemon" and stage == "Basic":
                basic_pokemon += count
            mapped.append(
                {
                    "local_card_uid": uid,
                    "count": count,
                    "set_code": set_code,
                    "card_index": card_index,
                    "source_raw_sha256": entry["source_raw_sha256"],
                    "source_canonical_json_v1_sha256": entry["source_canonical_sha256"],
                    "card_type": card_type,
                    "stage": stage,
                    "effect_id": effect_id,
                }
            )
            total += count
        if total != 60 or manifest.get("card_count") != 60 or basic_pokemon < 1:
            raise AuthorStrategyMatchError("package_deck_unmapped")
        return mapped


class AuthorStrategyMatchHandle:
    __slots__ = ("_package", "_pins_json", "_deck_json", "__weakref__")

    def __new__(cls) -> AuthorStrategyMatchHandle:
        raise TypeError("AuthorStrategyMatchHandle is builder-owned")

    @classmethod
    def _create(
        cls,
        package: AuthorStrategyPackageHandle,
        pins: dict[str, object],
        local_deck: list[dict[str, object]],
        token: object,
    ) -> AuthorStrategyMatchHandle:
        if token is not _HANDLE_TOKEN:
            raise TypeError("AuthorStrategyMatchHandle is builder-owned")
        value = object.__new__(cls)
        object.__setattr__(value, "_package", package)
        object.__setattr__(value, "_pins_json", _json_bytes(pins))
        object.__setattr__(value, "_deck_json", _json_bytes(local_deck))
        if not value.validate_integrity():
            raise AuthorStrategyMatchError("package_integrity_invalid")
        return value

    def __hash__(self) -> int:
        return object.__hash__(self)

    def validate_integrity(self) -> bool:
        try:
            pins = _json_copy(self._pins_json)
            deck = _json_copy(self._deck_json)
            package = self._package
            if type(package) is not AuthorStrategyPackageHandle or type(pins) is not dict or set(pins) != _PIN_KEYS:
                return False
            if type(deck) is not list or not deck or any(
                type(row) is not dict or set(row) not in (_DECK_ROW_KEYS, _WINDOWS_LOCAL_DECK_ROW_KEYS)
                for row in deck
            ):
                return False
            metadata = package.to_dict()
            expected = AuthorStrategyMatchHandleBuilder._pins(package, deck)
            return (
                pins == expected
                and pins["package_id"] == metadata["package_id"]
                and pins["package_version"] == metadata["package_version"]
                and pins["archive_sha256"] == metadata["archive_sha256"]
                and pins["local_deck_mapping_sha256"] == _sha(_json_bytes(deck))
            )
        except (AttributeError, KeyError, TypeError, UnicodeDecodeError, ValueError):
            return False

    def to_public_dict(self) -> dict[str, object]:
        if not self.validate_integrity():
            raise AuthorStrategyMatchError("package_integrity_invalid")
        return _json_copy(self._pins_json)

    def local_deck_snapshot(self) -> list[dict[str, object]]:
        if not self.validate_integrity():
            raise AuthorStrategyMatchError("package_integrity_invalid")
        return _json_copy(self._deck_json)

    def _policy_documents(self) -> tuple[dict[str, Any], dict[str, Any], dict[str, Any]]:
        if not self.validate_integrity():
            raise AuthorStrategyMatchError("package_integrity_invalid")
        try:
            documents = tuple(
                load_json_bytes_strict(self._package.payload_bytes(path))
                for path in ("policy/policy_ir.json", "policy/adapter.json", "policy/config.json")
            )
        except (KeyError, UnicodeDecodeError, ValueError) as exc:
            raise AuthorStrategyMatchError("package_policy_unsupported") from exc
        if not all(type(document) is dict for document in documents):
            raise AuthorStrategyMatchError("package_policy_unsupported")
        return documents  # type: ignore[return-value]


_HANDLE_TOKEN = object()


class AuthorStrategyMatchHandleBuilder:
    __slots__ = ()

    @staticmethod
    def _pins(package: AuthorStrategyPackageHandle, local_deck: list[dict[str, object]]) -> dict[str, object]:
        metadata = package.to_dict()
        deck_csv = package.payload_bytes("deck/deck.csv")
        try:
            deck_manifest = load_json_bytes_strict(package.payload_bytes("deck/deck_manifest.json"))
        except (UnicodeDecodeError, ValueError) as exc:
            raise AuthorStrategyMatchError("package_deck_unmapped") from exc
        if type(deck_manifest) is not dict:
            raise AuthorStrategyMatchError("package_deck_unmapped")
        try:
            weights_sha = _sha(package.payload_bytes("policy/weights.bin"))
        except KeyError:
            weights_sha = None
        return {
            "schema_version": 1,
            "profile_id": PROFILE_ID,
            "package_id": package.package_id,
            "package_version": package.package_version,
            "archive_sha256": package.archive_sha256,
            "manifest_sha256": package.manifest_sha256,
            "manifest_canonical_sha256": package.manifest_canonical_sha256,
            "files_manifest_sha256": package.files_manifest_sha256,
            "cabt_contract_sha256": metadata["compatibility"]["cabt_contract_sha256"],
            "card_catalog_sha256": metadata["compatibility"]["card_catalog_sha256"],
            "base_executor_sha256": metadata["compatibility"]["base_executor_sha256"],
            "policy_ir_sha256": package.policy_ir_sha256,
            "adapter_sha256": _sha(package.payload_bytes("policy/adapter.json")),
            "config_sha256": _sha(package.payload_bytes("policy/config.json")),
            "weights_sha256": weights_sha,
            "backend_id": PORTABLE_BACKEND_ID,
            "backend_sha256": PORTABLE_BACKEND_SHA256,
            "deck_manifest_sha256": package.deck_manifest_sha256,
            "deck_csv_sha256": _sha(deck_csv),
            "deck_card_id_domain": deck_manifest.get("card_id_domain"),
            "deck_platform_scope": (
                deck_manifest.get("platform_scope", []).copy()
                if type(deck_manifest.get("platform_scope", [])) is list
                else []
            ),
            "cabt_exportable": deck_manifest.get("cabt_exportable"),
            "local_deck_mapping_sha256": _sha(_json_bytes(local_deck)),
            "local_deck_card_count": sum(int(row["count"]) for row in local_deck),
            "local_deck_unique_printing_count": len(local_deck),
            "signature_status": package.signature_status,
            "execution_trusted": bool(package.execution_trusted),
            "development_shadow_ready": package.signature_status == "test_fixture_trusted" and not package.execution_trusted,
            "live_authority": False,
        }

    @staticmethod
    def build(package: object, *, root: Path | None = None) -> AuthorStrategyMatchHandle:
        if type(package) is not AuthorStrategyPackageHandle:
            raise AuthorStrategyMatchError("package_integrity_invalid")
        metadata = package.to_dict()
        compatibility = metadata.get("compatibility")
        expected_game_api = (
            "ptcgdap-author-host-v2"
            if metadata.get("package_document_type") == "strategy_package_v2"
            else "ptcgdap-author-host-v1"
        )
        if compatibility != {
            "minimum_game_api": expected_game_api,
            "cabt_contract_sha256": CABT_CONTRACT_SHA256,
            "card_catalog_sha256": CARD_CATALOG_SHA256,
            "base_executor_sha256": BASE_EXECUTOR_SHA256,
            "required_capabilities": compatibility.get("required_capabilities") if type(compatibility) is dict else None,
        }:
            raise AuthorStrategyMatchError("package_contract_incompatible")
        try:
            deck_manifest = load_json_bytes_strict(package.payload_bytes("deck/deck_manifest.json"))
        except (UnicodeDecodeError, ValueError) as exc:
            raise AuthorStrategyMatchError("package_deck_unmapped") from exc
        if type(deck_manifest) is not dict:
            raise AuthorStrategyMatchError("package_deck_unmapped")
        if deck_manifest.get("card_id_domain") == WINDOWS_LOCAL_DECK_DOMAIN:
            rows = AuthorStrategyExactDeckGate.parse_windows_local_deck_csv(package.payload_bytes("deck/deck.csv"))
            local_deck = AuthorStrategyExactDeckGate.map_windows_local_rows(rows, deck_manifest, root=root)
        else:
            rows = AuthorStrategyExactDeckGate.parse_deck_csv(package.payload_bytes("deck/deck.csv"))
            local_deck = AuthorStrategyExactDeckGate.map_official_rows(rows, root=root)
        pins = AuthorStrategyMatchHandleBuilder._pins(package, local_deck)
        return AuthorStrategyMatchHandle._create(package, pins, local_deck, _HANDLE_TOKEN)


class AuthorStrategyShadowPrompt:
    __slots__ = ("_context", "_window", "_input_json", "_local_uid_context_json", "__weakref__")

    def __new__(cls) -> AuthorStrategyShadowPrompt:
        raise TypeError("AuthorStrategyShadowPrompt is owner-produced")

    @classmethod
    def create(
        cls,
        context: object,
        window: object,
        *,
        prompt_id: object,
        prompt_generation: object,
        mandatory_indexes: object,
        terminal_indexes: object,
        base_hard_tiers: object,
        base_vetoed_indexes: object,
        local_uid_public_context: object = None,
    ) -> AuthorStrategyShadowPrompt:
        if type(context) is not StrategicContextV18 or type(window) is not CabtSelectionWindow:
            raise AuthorStrategyMatchError("invalid_current_window_owner")
        if not context.validate_integrity() or getattr(context, "_window_binding", None) is not window:
            raise AuthorStrategyMatchError("invalid_current_window_owner")
        option_count = window.option_count
        source = {
            "prompt_id": prompt_id,
            "prompt_generation": prompt_generation,
            "mandatory_indexes": mandatory_indexes,
            "terminal_indexes": terminal_indexes,
            "base_hard_tiers": base_hard_tiers,
            "base_vetoed_indexes": base_vetoed_indexes,
        }
        if (
            set(source) != _PROMPT_KEYS
            or not _identifier(prompt_id)
            or not _safe_int(prompt_generation)
            or prompt_generation < 1
            or not _index_list(mandatory_indexes, option_count)
            or not _index_list(terminal_indexes, option_count)
            or not _index_list(base_vetoed_indexes, option_count)
            or not _tiers(base_hard_tiers, option_count)
        ):
            raise AuthorStrategyMatchError("invalid_prompt_authority")
        value = object.__new__(cls)
        object.__setattr__(value, "_context", context)
        object.__setattr__(value, "_window", window)
        object.__setattr__(value, "_input_json", _json_bytes(source))
        if local_uid_public_context is None:
            object.__setattr__(value, "_local_uid_context_json", None)
        elif _local_context_error(context, local_uid_public_context, None) is None:
            object.__setattr__(value, "_local_uid_context_json", _json_bytes(local_uid_public_context))
        else:
            raise AuthorStrategyMatchError("invalid_local_uid_public_context")
        if not value.validate_integrity():
            raise AuthorStrategyMatchError("invalid_prompt_authority")
        return value

    def __hash__(self) -> int:
        return object.__hash__(self)

    def validate_integrity(self) -> bool:
        try:
            source = _json_copy(self._input_json)
            local_context = (
                None if self._local_uid_context_json is None else _json_copy(self._local_uid_context_json)
            )
            return (
                type(self._context) is StrategicContextV18
                and type(self._window) is CabtSelectionWindow
                and self._context.validate_integrity()
                and getattr(self._context, "_window_binding", None) is self._window
                and type(source) is dict
                and set(source) == _PROMPT_KEYS
                and _identifier(source["prompt_id"])
                and _safe_int(source["prompt_generation"])
                and source["prompt_generation"] >= 1
                and _index_list(source["mandatory_indexes"], self._window.option_count)
                and _index_list(source["terminal_indexes"], self._window.option_count)
                and _index_list(source["base_vetoed_indexes"], self._window.option_count)
                and _tiers(source["base_hard_tiers"], self._window.option_count)
                and (local_context is None or _local_context_error(self._context, local_context, None) is None)
            )
        except (AttributeError, KeyError, TypeError, UnicodeDecodeError, ValueError):
            return False

    def _snapshot(self) -> dict[str, object]:
        if not self.validate_integrity():
            raise AuthorStrategyMatchError("invalid_prompt_authority")
        return _json_copy(self._input_json)

    def _local_uid_public_context(self) -> dict[str, object] | None:
        if not self.validate_integrity() or self._local_uid_context_json is None:
            return None
        return _json_copy(self._local_uid_context_json)


class AuthorStrategyShadowResult:
    __slots__ = ("_audit_json",)

    def __new__(cls) -> AuthorStrategyShadowResult:
        raise TypeError("AuthorStrategyShadowResult is host-owned")

    @classmethod
    def _create(cls, audit: dict[str, object], token: object) -> AuthorStrategyShadowResult:
        if token is not _RESULT_TOKEN:
            raise TypeError("AuthorStrategyShadowResult is host-owned")
        value = object.__new__(cls)
        object.__setattr__(value, "_audit_json", _json_bytes(audit))
        if not value.validate_integrity():
            raise AuthorStrategyMatchError("shadow_audit_integrity_invalid")
        return value

    @property
    def indexes(self) -> list[int]:
        return list(self.to_public_dict()["selected_indexes"])

    def validate_integrity(self) -> bool:
        try:
            audit = _json_copy(self._audit_json)
            if type(audit) is not dict or audit.get("profile_id") != PROFILE_ID or audit.get("schema_version") != 1:
                return False
            digest = audit.pop("audit_hash", None)
            return _upper_sha(digest) and digest == _sha(AUDIT_PREFIX + _json_bytes(audit))
        except (TypeError, UnicodeDecodeError, ValueError):
            return False

    def to_public_dict(self) -> dict[str, object]:
        if not self.validate_integrity():
            raise AuthorStrategyMatchError("shadow_audit_integrity_invalid")
        return _json_copy(self._audit_json)


_RESULT_TOKEN = object()


class PtcgDAPAuthorMatchHost:
    __slots__ = ("_handle", "_match_id", "_ir", "_adapter", "_current_prompt", "_consumed_prompt_ids")

    def __init__(self) -> None:
        raise TypeError("PtcgDAPAuthorMatchHost is factory-owned")

    @classmethod
    def create(cls, handle: object, match_id: object) -> PtcgDAPAuthorMatchHost:
        if type(handle) is not AuthorStrategyMatchHandle or not handle.validate_integrity():
            raise AuthorStrategyMatchError("package_integrity_invalid")
        if not _identifier(match_id) or len(match_id) > 64:
            raise AuthorStrategyMatchError("invalid_match_identity")
        if handle in _HANDLE_CLAIMS:
            raise AuthorStrategyMatchError("package_handle_already_claimed")
        ir_document, adapter_document, _config = handle._policy_documents()
        ir_outcome = RestrictedBaseGraphIRCompiler.compile(ir_document)
        pins = handle.to_public_dict()
        if pins.get("deck_card_id_domain") == LOCAL_CARD_ID_DOMAIN:
            allowed = {item.get("local_card_uid") for item in handle.local_deck_snapshot()}
            adapter_outcome = PublicDeckAdapterCompiler.compile_local_uid(
                adapter_document,
                allowed_card_uids=allowed,
                deck_manifest_sha256=pins.get("deck_manifest_sha256"),
            )
        elif pins.get("deck_card_id_domain") == OFFICIAL_CARD_ID_DOMAIN:
            adapter_outcome = PublicDeckAdapterCompiler.compile(adapter_document)
        else:
            raise AuthorStrategyMatchError("package_policy_unsupported")
        if not ir_outcome.accepted or ir_outcome.ir is None or not adapter_outcome.accepted or adapter_outcome.adapter is None:
            raise AuthorStrategyMatchError("package_policy_unsupported")
        value = object.__new__(cls)
        value._handle = handle
        value._match_id = match_id
        value._ir = ir_outcome.ir
        value._adapter = adapter_outcome.adapter
        value._current_prompt = None
        value._consumed_prompt_ids = set()
        _HANDLE_CLAIMS[handle] = match_id
        return value

    def is_author_owner_ready(self) -> bool:
        return self._handle.validate_integrity() and self._current_prompt is None

    def open_current_prompt(self, source: object) -> dict[str, object]:
        if type(source) is not AuthorStrategyShadowPrompt or not source.validate_integrity():
            raise AuthorStrategyMatchError("invalid_prompt_authority")
        if self._current_prompt is not None:
            raise AuthorStrategyMatchError("prompt_already_open")
        local_context = source._local_uid_public_context()
        if self._adapter.card_id_domain == LOCAL_CARD_ID_DOMAIN:
            if local_context is None:
                raise AuthorStrategyMatchError("invalid_local_uid_public_context")
        elif local_context is not None:
            raise AuthorStrategyMatchError("invalid_local_uid_public_context")
        snapshot = source._snapshot()
        prompt_key = f"{snapshot['prompt_id']}:{snapshot['prompt_generation']}"
        if source in _PROMPT_CLAIMS or prompt_key in self._consumed_prompt_ids:
            raise AuthorStrategyMatchError("prompt_already_consumed")
        _PROMPT_CLAIMS[source] = self._match_id
        self._current_prompt = source
        return {"ok": True, "error_code": ""}

    def request_current_selection(self) -> AuthorStrategyShadowResult:
        source = self._current_prompt
        if type(source) is not AuthorStrategyShadowPrompt or not source.validate_integrity():
            self._current_prompt = None
            raise AuthorStrategyMatchError("prompt_not_open")
        prompt = source._snapshot()
        base_id = f"{self._match_id}.{prompt['prompt_id']}.{prompt['prompt_generation']}"
        if len(base_id) > 105:
            self._current_prompt = None
            raise AuthorStrategyMatchError("invalid_prompt_authority")
        pins = self._handle.to_public_dict()
        request = {
            "orchestration_id": base_id + ".orchestration",
            "proposal_id": base_id + ".proposal",
            "execution_id": base_id + ".execution",
            "scene_id": base_id + ".scene",
            "decision_id": base_id + ".decision",
            "determinism_key": base_id + ".determinism",
            "trace_id": base_id + ".trace",
            "policy_hash": pins["policy_ir_sha256"],
            "mandatory_indexes": prompt["mandatory_indexes"],
            "terminal_indexes": prompt["terminal_indexes"],
            "base_hard_tiers": prompt["base_hard_tiers"],
            "base_vetoed_indexes": prompt["base_vetoed_indexes"],
        }
        adapter = self._adapter
        if adapter.card_id_domain == LOCAL_CARD_ID_DOMAIN:
            bound = PublicDeckAdapterCompiler.bind_local_context(
                adapter,
                source._context,
                source._local_uid_public_context(),
            )
            if not bound.accepted or bound.adapter is None:
                self._current_prompt = None
                raise AuthorStrategyMatchError("invalid_local_uid_public_context")
            adapter = bound.adapter
        outcome = PublicBasePolicyOrchestrator.orchestrate(
            source._context,
            source._window,
            self._ir,
            adapter,
            request,
        )
        self._current_prompt = None
        prompt_key = f"{prompt['prompt_id']}:{prompt['prompt_generation']}"
        self._consumed_prompt_ids.add(prompt_key)
        if not outcome.accepted or outcome.result is None:
            raise AuthorStrategyMatchError("shadow_policy_failed")
        base = outcome.result.to_public_dict()
        context_public = source._context.to_public_dict()
        audit: dict[str, object] = {
            "schema_version": 1,
            "profile_id": PROFILE_ID,
            "match_id": self._match_id,
            "prompt_id": prompt["prompt_id"],
            "prompt_generation": prompt["prompt_generation"],
            "package": {
                "package_id": pins["package_id"],
                "package_version": pins["package_version"],
                "archive_sha256": pins["archive_sha256"],
            },
            "pins": {
                key: pins[key]
                for key in (
                    "manifest_sha256",
                    "files_manifest_sha256",
                    "cabt_contract_sha256",
                    "card_catalog_sha256",
                    "base_executor_sha256",
                    "policy_ir_sha256",
                    "adapter_sha256",
                    "config_sha256",
                    "weights_sha256",
                    "backend_sha256",
                    "deck_manifest_sha256",
                    "deck_csv_sha256",
                    "local_deck_mapping_sha256",
                )
            },
            "source": {
                "public_observation_hash": source._window.public_observation_hash,
                "window_id": source._window.window_id,
                "context_hash": context_public["context_hash"],
                "orchestration_hash": base["orchestration_hash"],
                "decision_audit_id": outcome.result.decision.audit_id,
                "trace_hash": outcome.result.trace.trace_hash,
            },
            "selected_indexes": outcome.result.agent_output(),
            "status": "shadow_selected",
            "diagnostic_code": "",
            "public_only": True,
            "development_shadow": True,
            "execution_trusted": False,
            "authoritative": False,
            "classic_fallback_used": False,
        }
        if adapter.card_id_domain == LOCAL_CARD_ID_DOMAIN:
            audit["source"]["card_id_domain"] = LOCAL_CARD_ID_DOMAIN
            audit["source"]["local_uid_contract_sha256"] = EXPECTED_LOCAL_BUNDLE_SHA256
            audit["source"]["local_uid_public_context_hash"] = adapter.local_context_hash
        audit["audit_hash"] = _sha(AUDIT_PREFIX + _json_bytes(audit))
        return AuthorStrategyShadowResult._create(audit, _RESULT_TOKEN)

    def abort_current_prompt(self, error_code: object) -> dict[str, object]:
        if type(error_code) is not str or not error_code or len(error_code) > 128:
            raise AuthorStrategyMatchError("invalid_abort_code")
        self._current_prompt = None
        return {"ok": True, "error_code": ""}
