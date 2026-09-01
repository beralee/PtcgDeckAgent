from __future__ import annotations

import copy
from dataclasses import dataclass
import hashlib
from pathlib import Path
import re
from types import MappingProxyType
from typing import Any, Final

from .source_lock import canonical_json_v1_bytes, load_json_strict
from .strategic_context_v18 import StrategicContextV18


PROFILE_ID: Final = "ptcgdap-public-deck-adapter-p4-wp4-v1"
EXPECTED_BUNDLE_SHA256: Final = "C80F4C4FDAEA5AC29BD3C5617BFAC72BE38709696F7EA1995D3D153113DD3CA1"
EXPECTED_PARENT_BUNDLE_SHA256: Final = "69D05747A9F91C19765D448B676C86E1D9DFA1BBAB108ED1374B854B34E48389"
EXPECTED_ARTIFACTS: Final = MappingProxyType(
    {
        "public_deck_adapter.schema.json": "5DCA15806729755F3EF6FA84901C4D65FF369077F09145A2C61149A4355787AE",
        "public_deck_adapter_profile.json": "93A6D659CB3636BE95747AC6F66516463D8C2BB3D1D4082A23AEDA678D684066",
        "public_deck_adapter_conformance_vectors.json": "FAB9FA1105510B7416DC643B5011738FCE4FFC79E4EB8F230FC636229BDC3B5D",
    }
)
LOCAL_PROFILE_ID: Final = "ptcgdap-local-uid-public-context-as-wp6-v1"
EXPECTED_LOCAL_BUNDLE_SHA256: Final = "42706B8426968F4EB1A9C79A3EFC3828236966454013BB791D51684E5C346AAA"
EXPECTED_LOCAL_PARENT_BUNDLE_SHA256: Final = EXPECTED_BUNDLE_SHA256
EXPECTED_LOCAL_ARTIFACTS: Final = MappingProxyType(
    {
        "local_uid_public_context.schema.json": "6DD02C41A39BB627D90842BFA9CE39531B8A9D00BA64BF2568BC66C211B87FA2",
        "local_uid_public_context_profile.json": "6905C81FC6203AA97F926235C74DF63E2E199FC6875C743BCC6A8C0C2995ADB8",
        "local_uid_public_context_conformance_vectors.json": "D668BCCB098744E201AA000EBEA282762CC0BDD6075277E3C7EB8C9FB4C1A3C6",
    }
)
DEFAULT_ROOT: Final = Path(__file__).resolve().parents[3] / "contracts" / "ptcgdap"
ADAPTER_PREFIX: Final = b"PTCGDAP\0PUBLIC_DECK_ADAPTER_V1\0"
PROPOSAL_PREFIX: Final = b"PTCGDAP\0PUBLIC_DECK_ADAPTER_PROPOSAL_V1\0"
LOCAL_CONTEXT_PREFIX: Final = b"PTCGDAP\0LOCAL_UID_PUBLIC_CONTEXT_V1\0"
LOCAL_UID_SET_PREFIX: Final = b"PTCGDAP\0LOCAL_UID_ALLOWED_SET_V1\0"
OFFICIAL_CARD_ID_DOMAIN: Final = "official_cabt_card_id"
LOCAL_CARD_ID_DOMAIN: Final = "godot_local_card_uid_v1"
OPERATORS: Final = ("goal_proposal", "macro_proposal", "tiebreak_score")
REASONS: Final = MappingProxyType(
    {
        "goal_proposal": "public_goal_proposal",
        "macro_proposal": "public_macro_proposal",
        "tiebreak_score": "public_tiebreak_proposal",
    }
)
GOAL_STAGES: Final = frozenset(("acquire", "deploy", "fund", "ready", "execute", "maintain", "recover"))
PREDICATES: Final = (
    "select_type_raw",
    "select_context_raw",
    "option_type_raw",
    "option_card_id",
    "option_player_index",
    "acting_hand_card_id",
    "acting_active_card_id",
)
SAFE_MAX: Final = 9007199254740991
_IDENTIFIER = re.compile(r"^[a-z0-9][a-z0-9._-]{0,127}$")
LOCAL_UID_SYNTAX_PATTERN: Final = r"^[A-Za-z0-9.]+_[A-Za-z0-9]+$"
_LOCAL_UID = re.compile(LOCAL_UID_SYNTAX_PATTERN)
_UPPER_SHA = re.compile(r"^[0-9A-F]{64}$")
_ADAPTER_TOKEN = object()
_RESULT_TOKEN = object()


class PublicDeckAdapterError(ValueError):
    pass


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def _domain_hash(prefix: bytes, value: Any) -> str:
    return _sha(prefix + canonical_json_v1_bytes(value))


def _identifier(value: Any) -> bool:
    return type(value) is str and _IDENTIFIER.fullmatch(value) is not None and "private" not in value.lower()


def _safe_int(value: Any) -> bool:
    return type(value) is int and -SAFE_MAX <= value <= SAFE_MAX


def _freeze(value: Any) -> Any:
    if type(value) is dict:
        return MappingProxyType({key: _freeze(item) for key, item in value.items()})
    if type(value) is list:
        return tuple(_freeze(item) for item in value)
    return value


def _thaw(value: Any) -> Any:
    if isinstance(value, MappingProxyType):
        return {key: _thaw(item) for key, item in value.items()}
    if type(value) is tuple:
        return [_thaw(item) for item in value]
    return value


def _contains_private(value: Any) -> bool:
    if type(value) is str:
        return "PRIVATE" in value.upper()
    if type(value) is list:
        return any(_contains_private(item) for item in value)
    if type(value) is dict:
        return any(_contains_private(key) or _contains_private(item) for key, item in value.items())
    return False


def _load_contracts(root: Path | None = None) -> dict[str, Any]:
    contract_root = DEFAULT_ROOT if root is None else Path(root)
    try:
        bundle = load_json_strict(contract_root / "public_deck_adapter_bundle.json")
        if _sha(canonical_json_v1_bytes(bundle)) != EXPECTED_BUNDLE_SHA256:
            raise PublicDeckAdapterError("contract_error")
        if type(bundle) is not dict or set(bundle) != {"schema_version", "bundle_id", "parent_bundle_canonical_sha256", "source_lock_canonical_sha256", "artifacts"}:
            raise PublicDeckAdapterError("contract_error")
        if bundle["schema_version"] != 1 or bundle["bundle_id"] != PROFILE_ID or bundle["parent_bundle_canonical_sha256"] != EXPECTED_PARENT_BUNDLE_SHA256:
            raise PublicDeckAdapterError("contract_error")
        expected_names = tuple(EXPECTED_ARTIFACTS)
        entries = bundle["artifacts"]
        if type(entries) is not list or len(entries) != len(expected_names):
            raise PublicDeckAdapterError("contract_error")
        documents: dict[str, Any] = {}
        for entry, name in zip(entries, expected_names, strict=True):
            if type(entry) is not dict or set(entry) != {"id", "path", "canonical_sha256"}:
                raise PublicDeckAdapterError("contract_error")
            if entry["id"] != name.removesuffix(".json") or entry["path"] != f"contracts/ptcgdap/{name}" or entry["canonical_sha256"] != EXPECTED_ARTIFACTS[name]:
                raise PublicDeckAdapterError("contract_error")
            document = load_json_strict(contract_root / name)
            if _sha(canonical_json_v1_bytes(document)) != EXPECTED_ARTIFACTS[name]:
                raise PublicDeckAdapterError("contract_error")
            documents[name] = document
        profile = documents["public_deck_adapter_profile.json"]
        contract = profile.get("adapter_contract", {}) if type(profile) is dict else {}
        result = profile.get("result_contract", {}) if type(profile) is dict else {}
        if (
            profile.get("profile_id") != PROFILE_ID
            or profile.get("parent_bundle_canonical_sha256") != EXPECTED_PARENT_BUNDLE_SHA256
            or profile.get("source_authority") != "exact_current_p4_wp1_strategic_context_owner"
            or tuple(contract.get("goal_stages", ())) != ("acquire", "deploy", "fund", "ready", "execute", "maintain", "recover")
            or tuple(contract.get("operators", ())) != OPERATORS
            or tuple(contract.get("predicate_fields", ())) != PREDICATES
            or contract.get("proposal_authority") != "same_base_tier_ordering_hint_only"
            or result.get("serialized_result_is_execution_authority") is not False
        ):
            raise PublicDeckAdapterError("contract_error")
        return documents
    except PublicDeckAdapterError:
        raise
    except Exception as exc:
        raise PublicDeckAdapterError("contract_error") from exc


def _load_local_contracts(root: Path | None = None) -> dict[str, Any]:
    contract_root = DEFAULT_ROOT if root is None else Path(root)
    try:
        bundle = load_json_strict(contract_root / "local_uid_public_context_bundle.json")
        if _sha(canonical_json_v1_bytes(bundle)) != EXPECTED_LOCAL_BUNDLE_SHA256:
            raise PublicDeckAdapterError("local_uid_contract_error")
        if type(bundle) is not dict or set(bundle) != {
            "schema_version", "bundle_id", "parent_bundle_canonical_sha256", "source_lock_canonical_sha256", "artifacts"
        }:
            raise PublicDeckAdapterError("local_uid_contract_error")
        if (
            bundle["schema_version"] != 1
            or bundle["bundle_id"] != LOCAL_PROFILE_ID
            or bundle["parent_bundle_canonical_sha256"] != EXPECTED_LOCAL_PARENT_BUNDLE_SHA256
            or bundle["source_lock_canonical_sha256"] != "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"
        ):
            raise PublicDeckAdapterError("local_uid_contract_error")
        expected_names = tuple(EXPECTED_LOCAL_ARTIFACTS)
        entries = bundle["artifacts"]
        if type(entries) is not list or len(entries) != len(expected_names):
            raise PublicDeckAdapterError("local_uid_contract_error")
        documents: dict[str, Any] = {}
        for entry, name in zip(entries, expected_names, strict=True):
            if type(entry) is not dict or set(entry) != {"id", "path", "canonical_sha256"}:
                raise PublicDeckAdapterError("local_uid_contract_error")
            if (
                entry["id"] != name.removesuffix(".json")
                or entry["path"] != f"contracts/ptcgdap/{name}"
                or entry["canonical_sha256"] != EXPECTED_LOCAL_ARTIFACTS[name]
            ):
                raise PublicDeckAdapterError("local_uid_contract_error")
            document = load_json_strict(contract_root / name)
            if _sha(canonical_json_v1_bytes(document)) != EXPECTED_LOCAL_ARTIFACTS[name]:
                raise PublicDeckAdapterError("local_uid_contract_error")
            documents[name] = document
        profile = documents["local_uid_public_context_profile.json"]
        identity = profile.get("card_identity", {}) if type(profile) is dict else {}
        binding = profile.get("binding_contract", {}) if type(profile) is dict else {}
        hashes = profile.get("hash_contract", {}) if type(profile) is dict else {}
        scope = profile.get("scope", {}) if type(profile) is dict else {}
        if (
            profile.get("profile_id") != LOCAL_PROFILE_ID
            or profile.get("parent_bundle_canonical_sha256") != EXPECTED_LOCAL_PARENT_BUNDLE_SHA256
            or identity.get("domain") != LOCAL_CARD_ID_DOMAIN
            or identity.get("construction") != "set_code + '_' + card_index"
            or identity.get("syntax_pattern") != LOCAL_UID_SYNTAX_PATTERN
            or identity.get("set_code_pattern") != "^[A-Za-z0-9.]+$"
            or identity.get("card_index_pattern") != "^[A-Za-z0-9]+$"
            or identity.get("component_max_length") != 32
            or identity.get("merge_with_official_card_id") is not False
            or binding.get("opponent_hidden_identity_allowed") is not False
            or binding.get("old_window_reuse_allowed") is not False
            or hashes.get("local_context_prefix_utf8_hex") != LOCAL_CONTEXT_PREFIX.hex().upper()
            or hashes.get("allowed_uid_set_prefix_utf8_hex") != LOCAL_UID_SET_PREFIX.hex().upper()
            or scope.get("player_live_authority") is not False
            or scope.get("cabt_export") is not False
        ):
            raise PublicDeckAdapterError("local_uid_contract_error")
        return documents
    except PublicDeckAdapterError:
        raise
    except Exception as exc:
        raise PublicDeckAdapterError("local_uid_contract_error") from exc


def _local_uid(value: Any) -> bool:
    if (
        type(value) is not str
        or not 4 <= len(value) <= 64
        or "private" in value.lower()
        or _LOCAL_UID.fullmatch(value) is None
    ):
        return False
    set_code, card_index = value.split("_", 1)
    return len(set_code) <= 32 and len(card_index) <= 32


def is_valid_local_card_uid(value: Any) -> bool:
    """Return whether a UID obeys the pinned Godot-local printing identity contract."""
    return _local_uid(value)


def _document_error(
    value: Any,
    card_id_domain: str = OFFICIAL_CARD_ID_DOMAIN,
    allowed_card_uids: frozenset[str] = frozenset(),
) -> str | None:
    if _contains_private(value):
        return "private_adapter_input"
    if type(value) is not dict or set(value) != {"schema_version", "adapter_id", "adapter_version", "rules"}:
        return "invalid_adapter_document"
    if value["schema_version"] != 1 or not _identifier(value["adapter_id"]) or not _safe_int(value["adapter_version"]) or value["adapter_version"] < 1:
        return "invalid_adapter_document"
    rules = value["rules"]
    if type(rules) is not list or len(rules) > 128:
        return "invalid_adapter_document"
    seen: set[str] = set()
    for item in rules:
        if type(item) is not dict or set(item) != {"rule_id", "operator", "reason_code", "goal_stage", "priority", "predicate"}:
            return "invalid_adapter_document"
        if not _identifier(item["rule_id"]) or item["rule_id"] in seen:
            return "invalid_adapter_document"
        seen.add(item["rule_id"])
        if type(item["operator"]) is not str or item["operator"] not in OPERATORS:
            return "unsupported_adapter_operator"
        if type(item["goal_stage"]) is not str or item["goal_stage"] not in GOAL_STAGES:
            return "unsupported_goal_stage"
        if item["reason_code"] != REASONS[item["operator"]] or not _safe_int(item["priority"]) or item["priority"] < 0:
            return "invalid_adapter_document"
        predicate = item["predicate"]
        if type(predicate) is not dict or set(predicate) != set(PREDICATES):
            return "invalid_public_predicate"
        for key, entry in predicate.items():
            card_field = key in {"option_card_id", "acting_hand_card_id", "acting_active_card_id"}
            if card_field and card_id_domain == LOCAL_CARD_ID_DOMAIN:
                if entry is not None and (not _local_uid(entry) or entry not in allowed_card_uids):
                    return "invalid_public_predicate"
            elif entry is not None and (not _safe_int(entry) or (card_field and entry <= 0)):
                return "invalid_public_predicate"
    return None


def _allowed_uid_hash(allowed_card_uids: frozenset[str]) -> str:
    return _domain_hash(LOCAL_UID_SET_PREFIX, sorted(allowed_card_uids))


def _adapter_payload(
    document: dict[str, Any],
    card_id_domain: str,
    allowed_card_uids: frozenset[str],
    deck_manifest_sha256: str | None,
    local_context: dict[str, Any] | None,
) -> dict[str, Any]:
    payload = {
        "schema_version": 1,
        "profile_id": PROFILE_ID,
        "adapter_id": document["adapter_id"],
        "adapter_version": document["adapter_version"],
        "rules": copy.deepcopy(document["rules"]),
        "authoritative": False,
    }
    if card_id_domain == LOCAL_CARD_ID_DOMAIN:
        payload.update(
            {
                "card_id_domain": LOCAL_CARD_ID_DOMAIN,
                "deck_manifest_sha256": deck_manifest_sha256,
                "allowed_card_uids_hash": _allowed_uid_hash(allowed_card_uids),
                "local_uid_public_context_hash": (
                    _domain_hash(LOCAL_CONTEXT_PREFIX, local_context) if local_context is not None else None
                ),
            }
        )
    return payload


def _local_context_error(
    context: Any,
    value: Any,
    allowed_card_uids: frozenset[str] | None,
) -> str | None:
    if type(context) is not StrategicContextV18 or not context.validate_integrity() or _contains_private(value):
        return "invalid_local_uid_public_context"
    if type(value) is not dict or set(value) != {
        "schema_version", "card_id_domain", "source", "options", "acting_hand", "acting_active"
    }:
        return "invalid_local_uid_public_context"
    public = context.to_public_dict()
    source = value["source"]
    if (
        value["schema_version"] != 1
        or value["card_id_domain"] != LOCAL_CARD_ID_DOMAIN
        or type(source) is not dict
        or set(source) != {"context_hash", "window_id"}
        or source["context_hash"] != public["context_hash"]
        or source["window_id"] != public["source"]["window_id"]
    ):
        return "invalid_local_uid_public_context"

    options = value["options"]
    public_options = public["select_semantics"]["options"]
    if type(options) is not list or len(options) != len(public_options):
        return "invalid_local_uid_public_context"
    for index, entry in enumerate(options):
        if (
            type(entry) is not dict
            or set(entry) != {"index", "local_card_uid"}
            or type(entry["index"]) is not int
            or entry["index"] != index
            or public_options[index]["index"] != index
        ):
            return "invalid_local_uid_public_context"
        uid = entry["local_card_uid"]
        if uid is not None and (not _local_uid(uid) or (allowed_card_uids is not None and uid not in allowed_card_uids)):
            return "invalid_local_uid_public_context"

    acting = public["public_state"]["acting_player"]
    for key, public_key in (("acting_hand", "hand"), ("acting_active", "active")):
        entries = value[key]
        cards = acting[public_key]
        if type(entries) is not list or type(cards) is not list or len(entries) != len(cards):
            return "invalid_local_uid_public_context"
        for index, entry in enumerate(entries):
            if (
                type(entry) is not dict
                or set(entry) != {"serial", "local_card_uid"}
                or type(entry["serial"]) is not int
                or entry["serial"] != cards[index].get("serial")
                or not _local_uid(entry["local_card_uid"])
                or (allowed_card_uids is not None and entry["local_card_uid"] not in allowed_card_uids)
            ):
                return "invalid_local_uid_public_context"
    return None


@dataclass(frozen=True, slots=True, init=False)
class PublicDeckAdapter:
    _document: Any
    _snapshot: Any
    _card_id_domain: str
    _allowed_card_uids: Any
    _deck_manifest_sha256: str | None
    _local_context: Any

    @classmethod
    def _from_owner(
        cls,
        document: dict[str, Any],
        token: object,
        *,
        card_id_domain: str = OFFICIAL_CARD_ID_DOMAIN,
        allowed_card_uids: frozenset[str] = frozenset(),
        deck_manifest_sha256: str | None = None,
        local_context: dict[str, Any] | None = None,
    ) -> PublicDeckAdapter:
        if token is not _ADAPTER_TOKEN:
            raise PublicDeckAdapterError("adapter_integrity_invalid")
        value = object.__new__(cls)
        payload = _adapter_payload(document, card_id_domain, allowed_card_uids, deck_manifest_sha256, local_context)
        snapshot = {**payload, "adapter_hash": _domain_hash(ADAPTER_PREFIX, payload)}
        object.__setattr__(value, "_document", _freeze(copy.deepcopy(document)))
        object.__setattr__(value, "_snapshot", _freeze(snapshot))
        object.__setattr__(value, "_card_id_domain", card_id_domain)
        object.__setattr__(value, "_allowed_card_uids", frozenset(allowed_card_uids))
        object.__setattr__(value, "_deck_manifest_sha256", deck_manifest_sha256)
        object.__setattr__(value, "_local_context", _freeze(copy.deepcopy(local_context)) if local_context is not None else None)
        if not value.validate_integrity():
            raise PublicDeckAdapterError("adapter_integrity_invalid")
        return value

    @property
    def adapter_hash(self) -> str:
        return str(self._snapshot.get("adapter_hash", "")) if self.validate_integrity() else ""

    @property
    def adapter_id(self) -> str:
        return str(self._snapshot.get("adapter_id", "")) if self.validate_integrity() else ""

    @property
    def card_id_domain(self) -> str:
        return self._card_id_domain if self.validate_integrity() else ""

    @property
    def local_context_bound(self) -> bool:
        return self.card_id_domain == LOCAL_CARD_ID_DOMAIN and self._local_context is not None

    @property
    def local_context_hash(self) -> str:
        return str(self._snapshot.get("local_uid_public_context_hash", "")) if self.local_context_bound else ""

    def validate_integrity(self) -> bool:
        try:
            document = _thaw(self._document)
            snapshot = _thaw(self._snapshot)
            if self._card_id_domain not in {OFFICIAL_CARD_ID_DOMAIN, LOCAL_CARD_ID_DOMAIN}:
                return False
            if _document_error(document, self._card_id_domain, self._allowed_card_uids) is not None:
                return False
            local_context = _thaw(self._local_context) if self._local_context is not None else None
            if self._card_id_domain == OFFICIAL_CARD_ID_DOMAIN:
                if self._allowed_card_uids or self._deck_manifest_sha256 is not None or local_context is not None:
                    return False
            elif (
                not self._allowed_card_uids
                or not isinstance(self._deck_manifest_sha256, str)
                or _UPPER_SHA.fullmatch(self._deck_manifest_sha256) is None
            ):
                return False
            payload = _adapter_payload(
                document,
                self._card_id_domain,
                self._allowed_card_uids,
                self._deck_manifest_sha256,
                local_context,
            )
            expected = {**payload, "adapter_hash": _domain_hash(ADAPTER_PREFIX, payload)}
            return snapshot == expected
        except Exception:
            return False

    def to_public_dict(self) -> dict[str, Any]:
        if not self.validate_integrity():
            raise PublicDeckAdapterError("adapter_integrity_invalid")
        return copy.deepcopy(_thaw(self._snapshot))


@dataclass(frozen=True, slots=True)
class PublicDeckAdapterCompileOutcome:
    accepted: bool
    error_code: str
    adapter: PublicDeckAdapter | None


class PublicDeckAdapterCompiler:
    @staticmethod
    def compile(document: Any, *, contract_root: Path | None = None) -> PublicDeckAdapterCompileOutcome:
        try:
            _load_contracts(contract_root)
            error = _document_error(document)
            if error is not None:
                return PublicDeckAdapterCompileOutcome(False, error, None)
            adapter = PublicDeckAdapter._from_owner(copy.deepcopy(document), _ADAPTER_TOKEN)
            return PublicDeckAdapterCompileOutcome(True, "", adapter)
        except PublicDeckAdapterError as exc:
            return PublicDeckAdapterCompileOutcome(False, str(exc), None)
        except Exception:
            return PublicDeckAdapterCompileOutcome(False, "invalid_adapter_document", None)

    @staticmethod
    def compile_local_uid(
        document: Any,
        *,
        allowed_card_uids: Any,
        deck_manifest_sha256: Any,
        contract_root: Path | None = None,
    ) -> PublicDeckAdapterCompileOutcome:
        try:
            _load_contracts(contract_root)
            _load_local_contracts(contract_root)
            if type(allowed_card_uids) not in {set, frozenset}:
                return PublicDeckAdapterCompileOutcome(False, "invalid_adapter_document", None)
            allowed = frozenset(allowed_card_uids)
            if not allowed or not all(_local_uid(item) for item in allowed):
                return PublicDeckAdapterCompileOutcome(False, "invalid_adapter_document", None)
            if type(deck_manifest_sha256) is not str or _UPPER_SHA.fullmatch(deck_manifest_sha256) is None:
                return PublicDeckAdapterCompileOutcome(False, "invalid_adapter_document", None)
            error = _document_error(document, LOCAL_CARD_ID_DOMAIN, allowed)
            if error is not None:
                return PublicDeckAdapterCompileOutcome(False, error, None)
            adapter = PublicDeckAdapter._from_owner(
                copy.deepcopy(document),
                _ADAPTER_TOKEN,
                card_id_domain=LOCAL_CARD_ID_DOMAIN,
                allowed_card_uids=allowed,
                deck_manifest_sha256=deck_manifest_sha256,
            )
            return PublicDeckAdapterCompileOutcome(True, "", adapter)
        except PublicDeckAdapterError as exc:
            return PublicDeckAdapterCompileOutcome(False, str(exc), None)
        except Exception:
            return PublicDeckAdapterCompileOutcome(False, "invalid_adapter_document", None)

    @staticmethod
    def bind_local_context(
        adapter: Any,
        context: Any,
        local_uid_public_context: Any,
    ) -> PublicDeckAdapterCompileOutcome:
        try:
            if (
                type(adapter) is not PublicDeckAdapter
                or not adapter.validate_integrity()
                or adapter.card_id_domain != LOCAL_CARD_ID_DOMAIN
                or adapter.local_context_bound
            ):
                return PublicDeckAdapterCompileOutcome(False, "invalid_local_uid_public_context", None)
            value = copy.deepcopy(local_uid_public_context)
            if _local_context_error(context, value, adapter._allowed_card_uids) is not None:
                return PublicDeckAdapterCompileOutcome(False, "invalid_local_uid_public_context", None)
            bound = PublicDeckAdapter._from_owner(
                copy.deepcopy(_thaw(adapter._document)),
                _ADAPTER_TOKEN,
                card_id_domain=LOCAL_CARD_ID_DOMAIN,
                allowed_card_uids=adapter._allowed_card_uids,
                deck_manifest_sha256=adapter._deck_manifest_sha256,
                local_context=value,
            )
            return PublicDeckAdapterCompileOutcome(True, "", bound)
        except Exception:
            return PublicDeckAdapterCompileOutcome(False, "invalid_local_uid_public_context", None)


def _card_ids(value: Any) -> set[int]:
    if type(value) is not list:
        return set()
    return {item["id"] for item in value if type(item) is dict and type(item.get("id")) is int}


def _matches(predicate: dict[str, Any], context: dict[str, Any], option: dict[str, Any], adapter: PublicDeckAdapter) -> bool:
    raw = option["raw"]
    local_context = _thaw(adapter._local_context) if adapter._local_context is not None else None
    local = adapter._card_id_domain == LOCAL_CARD_ID_DOMAIN
    option_index = option["index"]
    actual = {
        "select_type_raw": context["select_semantics"]["select_type_raw"],
        "select_context_raw": context["select_semantics"]["select_context_raw"],
        "option_type_raw": raw.get("type"),
        "option_card_id": local_context["options"][option_index]["local_card_uid"] if local else raw.get("cardId"),
        "option_player_index": raw.get("playerIndex"),
    }
    for key in ("select_type_raw", "select_context_raw", "option_type_raw", "option_card_id", "option_player_index"):
        if predicate[key] is not None and actual[key] != predicate[key]:
            return False
    acting = context["public_state"]["acting_player"]
    hand_ids = {item["local_card_uid"] for item in local_context["acting_hand"]} if local else _card_ids(acting["hand"])
    active_ids = {item["local_card_uid"] for item in local_context["acting_active"]} if local else _card_ids(acting["active"])
    if predicate["acting_hand_card_id"] is not None and predicate["acting_hand_card_id"] not in hand_ids:
        return False
    if predicate["acting_active_card_id"] is not None and predicate["acting_active_card_id"] not in active_ids:
        return False
    return True


def _proposal_payload(context: StrategicContextV18, adapter: PublicDeckAdapter, proposal_id: str) -> dict[str, Any]:
    public = context.to_public_dict()
    adapter_public = adapter.to_public_dict()
    if adapter.card_id_domain == LOCAL_CARD_ID_DOMAIN:
        local_context = _thaw(adapter._local_context) if adapter._local_context is not None else None
        if _local_context_error(context, local_context, adapter._allowed_card_uids) is not None:
            raise PublicDeckAdapterError("invalid_local_uid_public_context")
    options = public["select_semantics"]["options"]
    proposals: list[dict[str, Any]] = []
    matches: list[dict[str, Any]] = []
    for operator in OPERATORS:
        best: dict[int, tuple[int, int]] = {}
        for order, item in enumerate(adapter_public["rules"]):
            if item["operator"] != operator:
                continue
            indexes = [option["index"] for option in options if _matches(item["predicate"], public, option, adapter)]
            if indexes:
                matches.append({"rule_id": item["rule_id"], "operator": operator, "goal_stage": item["goal_stage"], "matched_indexes": indexes})
            for index in indexes:
                key = (item["priority"], order)
                if index not in best or key < best[index]:
                    best[index] = key
        if best:
            proposals.append({"operator": operator, "indexes": sorted(best, key=lambda index: (*best[index], index)), "reason_code": REASONS[operator]})
    source = {"context_hash": public["context_hash"], "window_id": public["source"]["window_id"], "adapter_hash": adapter_public["adapter_hash"]}
    payload = {
        "schema_version": 1,
        "profile_id": PROFILE_ID,
        "proposal_id": proposal_id,
        "adapter_id": adapter_public["adapter_id"],
        "source": source,
        "adapter_proposals": proposals,
        "matched_rules": matches,
        "authoritative": False,
    }
    if adapter.card_id_domain == LOCAL_CARD_ID_DOMAIN:
        if not adapter.local_context_bound:
            raise PublicDeckAdapterError("invalid_local_uid_public_context")
        payload["card_id_domain"] = LOCAL_CARD_ID_DOMAIN
        source["local_uid_public_context_hash"] = adapter.local_context_hash
    return payload


@dataclass(frozen=True, slots=True, init=False)
class PublicDeckAdapterProposalResult:
    _snapshot: Any
    _context_binding: StrategicContextV18
    _adapter_binding: PublicDeckAdapter
    _proposal_id: str

    @classmethod
    def _from_owner(cls, context: StrategicContextV18, adapter: PublicDeckAdapter, proposal_id: str, token: object) -> PublicDeckAdapterProposalResult:
        if token is not _RESULT_TOKEN:
            raise PublicDeckAdapterError("proposal_integrity_invalid")
        value = object.__new__(cls)
        payload = _proposal_payload(context, adapter, proposal_id)
        snapshot = {**payload, "proposal_hash": _domain_hash(PROPOSAL_PREFIX, payload)}
        object.__setattr__(value, "_snapshot", _freeze(snapshot))
        object.__setattr__(value, "_context_binding", context)
        object.__setattr__(value, "_adapter_binding", adapter)
        object.__setattr__(value, "_proposal_id", proposal_id)
        if not value.validate_integrity(context, adapter):
            raise PublicDeckAdapterError("proposal_integrity_invalid")
        return value

    @property
    def adapter_proposals(self) -> list[dict[str, Any]]:
        return copy.deepcopy(_thaw(self._snapshot.get("adapter_proposals", ()))) if self.validate_integrity(self._context_binding, self._adapter_binding) else []

    @property
    def proposal_hash(self) -> str:
        return str(self._snapshot.get("proposal_hash", "")) if self.validate_integrity(self._context_binding, self._adapter_binding) else ""

    def validate_integrity(self, context: Any, adapter: Any) -> bool:
        try:
            if context is not self._context_binding or adapter is not self._adapter_binding:
                return False
            if type(context) is not StrategicContextV18 or not context.validate_integrity() or type(adapter) is not PublicDeckAdapter or not adapter.validate_integrity():
                return False
            payload = _proposal_payload(context, adapter, self._proposal_id)
            expected = {**payload, "proposal_hash": _domain_hash(PROPOSAL_PREFIX, payload)}
            return _thaw(self._snapshot) == expected
        except Exception:
            return False

    def to_public_dict(self) -> dict[str, Any]:
        if not self.validate_integrity(self._context_binding, self._adapter_binding):
            raise PublicDeckAdapterError("proposal_integrity_invalid")
        return copy.deepcopy(_thaw(self._snapshot))


@dataclass(frozen=True, slots=True)
class PublicDeckAdapterProposalOutcome:
    accepted: bool
    error_code: str
    result: PublicDeckAdapterProposalResult | None


class PublicDeckAdapterProposer:
    @staticmethod
    def propose(context: Any, adapter: Any, proposal_id: Any, *, contract_root: Path | None = None) -> PublicDeckAdapterProposalOutcome:
        try:
            _load_contracts(contract_root)
            if type(context) is not StrategicContextV18 or not context.validate_integrity():
                return PublicDeckAdapterProposalOutcome(False, "invalid_context", None)
            if type(adapter) is not PublicDeckAdapter or not adapter.validate_integrity():
                return PublicDeckAdapterProposalOutcome(False, "invalid_adapter", None)
            if adapter.card_id_domain == LOCAL_CARD_ID_DOMAIN:
                _load_local_contracts(contract_root)
            if not _identifier(proposal_id):
                return PublicDeckAdapterProposalOutcome(False, "invalid_proposal_id", None)
            result = PublicDeckAdapterProposalResult._from_owner(context, adapter, proposal_id, _RESULT_TOKEN)
            return PublicDeckAdapterProposalOutcome(True, "", result)
        except PublicDeckAdapterError as exc:
            return PublicDeckAdapterProposalOutcome(False, str(exc), None)
        except Exception:
            return PublicDeckAdapterProposalOutcome(False, "proposal_integrity_invalid", None)


__all__ = [
    "EXPECTED_BUNDLE_SHA256",
    "EXPECTED_LOCAL_BUNDLE_SHA256",
    "PublicDeckAdapter",
    "PublicDeckAdapterCompiler",
    "PublicDeckAdapterCompileOutcome",
    "PublicDeckAdapterError",
    "PublicDeckAdapterProposer",
    "PublicDeckAdapterProposalOutcome",
    "PublicDeckAdapterProposalResult",
]
