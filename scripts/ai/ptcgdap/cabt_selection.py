from __future__ import annotations

import hashlib
import re
import weakref
from dataclasses import dataclass, fields
from pathlib import Path
from typing import Any, Final

from .cabt_tree_hash import CabtTreeHashError, jcs_canonical_json_bytes
from .contract_set import (
    CabtContractSet,
    EXPECTED_CONTRACT_BUNDLE_SHA256,
    load_contract_set,
)


WINDOW_VERSION: Final = 1
WINDOW_HASH_PROFILE: Final = "cabt_selection_window_v1"
OPTION_FINGERPRINT_PROFILE: Final = "cabt_option_fingerprint_v1"
INITIAL_DECK_PROFILE: Final = "cabt_initial_deck_v1"

_SAFE_INTEGER_MIN: Final = -(2**53) + 1
_SAFE_INTEGER_MAX: Final = 2**53 - 1
_DEFAULT_CONTRACT_ROOT: Final = (
    Path(__file__).resolve().parents[3] / "contracts" / "ptcgdap"
)
_CONTRACTS_CONSTRUCTION_TOKEN: Final = object()
_WINDOW_CONSTRUCTION_TOKEN: Final = object()
_RESULT_CONSTRUCTION_TOKEN: Final = object()
_OWNER_RESULT_REGISTRY: dict[int, tuple[Any, str, Any, Any]] = {}


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
        return _FrozenObject(
            tuple((key, _freeze_json(child)) for key, child in value.items())
        )
    raise TypeError("validated public JSON tree contains an unsupported value")


def _thaw_json(value: Any) -> Any:
    if isinstance(value, _FrozenArray):
        return [_thaw_json(child) for child in value.items]
    if isinstance(value, _FrozenObject):
        return {key: _thaw_json(child) for key, child in value.items}
    return value


def _is_exact_safe_int(value: Any) -> bool:
    return (
        type(value) is int
        and _SAFE_INTEGER_MIN <= value <= _SAFE_INTEGER_MAX
    )


def _is_upper_sha256(value: Any) -> bool:
    if type(value) is not str or len(value) != 64:
        return False
    return all(character in "0123456789ABCDEF" for character in value)


def _domain_hash(prefix: bytes, payload: dict[str, Any]) -> str:
    canonical = jcs_canonical_json_bytes(payload)
    digest = hashlib.sha256()
    digest.update(prefix)
    digest.update(canonical)
    return digest.hexdigest().upper()


def _require_exact_object(value: Any, label: str) -> dict[str, Any]:
    if type(value) is not dict or any(type(key) is not str for key in value):
        raise ValueError(f"{label} must be an exact string-keyed object")
    return value


def _require_exact_string_list(value: Any, label: str) -> tuple[str, ...]:
    if type(value) is not list or any(type(item) is not str for item in value):
        raise ValueError(f"{label} must be an exact list of exact strings")
    result = tuple(value)
    if len(result) != len(set(result)):
        raise ValueError(f"{label} must not contain duplicates")
    return result


def _require_enum_values(
    enums: dict[str, Any],
    enum_name: str,
) -> tuple[dict[str, int], frozenset[int]]:
    raw = _require_exact_object(enums.get(enum_name), f"enums.{enum_name}")
    result: dict[str, int] = {}
    for name, raw_value in raw.items():
        if type(name) is not str or not name or not _is_exact_safe_int(raw_value):
            raise ValueError(f"enums.{enum_name} contains an invalid member")
        result[name] = raw_value
    values = frozenset(result.values())
    if len(values) != len(result):
        raise ValueError(f"enums.{enum_name} contains duplicate raw values")
    return result, values


def _profile_prefix(
    hash_profiles: dict[str, Any],
    profile_id: str,
) -> bytes:
    profile = _require_exact_object(
        hash_profiles.get(profile_id),
        f"hash_contract.profiles.{profile_id}",
    )
    prefix_hex = profile.get("prefix_utf8_hex")
    if (
        type(prefix_hex) is not str
        or not prefix_hex
        or len(prefix_hex) % 2 != 0
        or any(character not in "0123456789ABCDEF" for character in prefix_hex)
    ):
        raise ValueError(
            f"{profile_id} prefix_utf8_hex must be non-empty, even-length "
            "uppercase hexadecimal"
        )
    prefix_bytes = bytes.fromhex(prefix_hex)
    expected = b"PTCGDAP\x00" + profile_id.upper().encode("ascii") + b"\x00"
    if prefix_bytes != expected:
        raise ValueError(f"{profile_id} prefix is not the locked domain prefix")
    return prefix_bytes


@dataclass(frozen=True, slots=True, init=False)
class CabtSelectionContracts:
    """Validated immutable semantic inputs for the selection pure core."""

    source_lock_id: str
    source_contract_hash: str
    public_hash_authorities: frozenset[str]
    policy_outcomes: frozenset[str]
    build_fallback_reason_codes: frozenset[str]
    build_reject_reason_codes: frozenset[str]
    sanitize_reason_codes: frozenset[str]
    resolution_reason_codes: frozenset[str]
    fallback_resolution_reason_codes: frozenset[str]
    pinned_deck_build_reason_codes: frozenset[str]
    initial_deck_resolution_reason_codes: frozenset[str]
    initial_deck_candidate_reason_codes: frozenset[str]
    select_keys: tuple[str, ...]
    select_integer_keys: tuple[str, ...]
    card_keys: tuple[str, ...]
    card_positive_integer_keys: tuple[str, ...]
    option_fields: tuple[str, ...]
    option_shapes: tuple[tuple[int, tuple[str, ...]], ...]
    known_select_types: frozenset[int]
    known_select_contexts: frozenset[int]
    known_areas: frozenset[int]
    known_special_conditions: frozenset[int]
    window_prefix: bytes
    option_fingerprint_prefix: bytes
    initial_deck_prefix: bytes
    pinned_card_ids: tuple[int, ...]
    pinned_deck_hash: str
    pinned_source_artifact_id: str
    pinned_source_sha256: str
    pinned_authority_scope: str
    _construction_seal: object

    def __new__(cls) -> CabtSelectionContracts:
        raise TypeError("CabtSelectionContracts must be created from contract documents")

    @classmethod
    def _from_validated(
        cls,
        *,
        construction_token: object,
        **values: Any,
    ) -> CabtSelectionContracts:
        if construction_token is not _CONTRACTS_CONSTRUCTION_TOKEN:
            raise TypeError("CabtSelectionContracts construction is contract-set-owned")
        expected_fields = {
            "source_lock_id",
            "source_contract_hash",
            "public_hash_authorities",
            "policy_outcomes",
            "build_fallback_reason_codes",
            "build_reject_reason_codes",
            "sanitize_reason_codes",
            "resolution_reason_codes",
            "fallback_resolution_reason_codes",
            "pinned_deck_build_reason_codes",
            "initial_deck_resolution_reason_codes",
            "initial_deck_candidate_reason_codes",
            "select_keys",
            "select_integer_keys",
            "card_keys",
            "card_positive_integer_keys",
            "option_fields",
            "option_shapes",
            "known_select_types",
            "known_select_contexts",
            "known_areas",
            "known_special_conditions",
            "window_prefix",
            "option_fingerprint_prefix",
            "initial_deck_prefix",
            "pinned_card_ids",
            "pinned_deck_hash",
            "pinned_source_artifact_id",
            "pinned_source_sha256",
            "pinned_authority_scope",
            "_construction_seal",
        }
        if set(values) != expected_fields:
            raise ValueError("validated selection contract fields are incomplete")
        contracts = object.__new__(cls)
        for field_name, value in values.items():
            object.__setattr__(contracts, field_name, value)
        return contracts

    @classmethod
    def from_contract_set(
        cls,
        contract_set: CabtContractSet,
    ) -> CabtSelectionContracts:
        if type(contract_set) is not CabtContractSet:
            raise TypeError("contract_set must be an exact CabtContractSet")
        if not contract_set.is_loader_verified:
            raise ValueError("contract_set integrity validation failed")
        selection_profile = contract_set.selection_profile
        option_sparse_shapes = contract_set.option_shapes
        enum_snapshot = contract_set.enum_snapshot
        profile = _require_exact_object(selection_profile, "selection_profile")
        sparse = _require_exact_object(
            option_sparse_shapes,
            "option_sparse_shapes",
        )
        snapshot = _require_exact_object(enum_snapshot, "enum_snapshot")
        if type(profile.get("schema_version")) is not int or profile.get(
            "schema_version"
        ) != 1:
            raise ValueError("unsupported selection profile schema")
        if profile.get("profile_id") != "cabt_selection_profile_v1":
            raise ValueError("unsupported selection profile")
        source_lock_id = profile.get("source_lock_id")
        if type(source_lock_id) is not str or not source_lock_id:
            raise ValueError("selection profile source lock is invalid")
        if source_lock_id != contract_set.source_lock_id:
            raise ValueError("selection profile source lock is not contract-set bound")
        if (
            type(sparse.get("schema_version")) is not int
            or sparse.get("schema_version") != 1
            or sparse.get("source_lock_id") != source_lock_id
            or type(snapshot.get("schema_version")) is not int
            or snapshot.get("schema_version") != 1
            or snapshot.get("source_lock_id") != source_lock_id
        ):
            raise ValueError("selection dependency source locks do not match")

        dependencies = _require_exact_object(
            profile.get("dependencies"),
            "selection_profile.dependencies",
        )
        if dependencies.get("option_sparse_shapes") != (
            "contracts/ptcgdap/cabt_option_sparse_shapes.json"
        ) or dependencies.get("enum_snapshot") != (
            "contracts/ptcgdap/cabt_enum_snapshot.json"
        ):
            raise ValueError("selection profile dependency paths are not locked")

        input_authority = _require_exact_object(
            profile.get("input_authority"),
            "selection_profile.input_authority",
        )
        public_hash_authorities = frozenset(
            _require_exact_string_list(
                input_authority.get("accepted_public_hash_authorities"),
                "accepted_public_hash_authorities",
            )
        )
        if not public_hash_authorities:
            raise ValueError("at least one public hash authority is required")
        policy_outcomes = frozenset(
            _require_exact_string_list(
                profile.get("policy_outcomes"),
                "policy_outcomes",
            )
        )
        if policy_outcomes != frozenset(
            {"returned", "exception", "timeout", "unavailable"}
        ):
            raise ValueError("policy outcomes are not supported by this core")
        reason_codes = _require_exact_object(
            profile.get("reason_codes"),
            "selection_profile.reason_codes",
        )
        expected_reason_codes = {
            "build_fallback": frozenset(
                {
                    "unknown_select_type",
                    "unknown_select_context",
                    "unknown_option_type",
                    "unknown_option_enum",
                    "sparse_shape_mismatch",
                }
            ),
            "build_reject": frozenset(
                {
                    "public_hash_authority_required",
                    "invalid_public_observation_hash",
                    "invalid_chooser_player_index",
                    "select_not_object",
                    "unknown_public_key",
                    "missing_select_field",
                    "invalid_select_field_type",
                    "invalid_cardinality",
                    "invalid_option",
                    "invalid_card",
                }
            ),
            "sanitize": frozenset(
                {
                    "policy_selection_accepted",
                    "window_fallback_only",
                    "proposal_not_list",
                    "proposal_index_not_exact_int",
                    "proposal_cardinality",
                    "proposal_index_out_of_range",
                    "proposal_duplicate_index",
                }
            ),
            "resolution": frozenset(
                {
                    "policy_selection_accepted",
                    "window_fallback_only",
                    "invalid_policy_output",
                    "policy_exception",
                    "policy_timeout",
                    "policy_unavailable",
                }
            ),
            "pinned_deck_build": frozenset(
                {"pinned_deck_accepted", "invalid_pinned_deck"}
            ),
            "initial_deck_resolution": frozenset(
                {
                    "pinned_deck_accepted",
                    "pinned_deck_fallback",
                    "invalid_pinned_deck",
                }
            ),
            "initial_deck_candidate": frozenset(
                {
                    "pinned_deck_accepted",
                    "invalid_pinned_deck",
                    "deck_not_list",
                    "deck_cardinality",
                    "deck_card_not_exact_int",
                    "deck_card_not_positive",
                    "deck_mismatch",
                    "deck_exception",
                    "deck_timeout",
                    "deck_unavailable",
                }
            ),
        }
        parsed_reason_codes: dict[str, frozenset[str]] = {}
        if set(reason_codes) != set(expected_reason_codes):
            raise ValueError("selection reason-code domains are not exact")
        for domain, expected_codes in expected_reason_codes.items():
            parsed_codes = frozenset(
                _require_exact_string_list(
                    reason_codes.get(domain),
                    f"reason_codes.{domain}",
                )
            )
            if parsed_codes != expected_codes:
                raise ValueError(
                    f"{domain} reason codes are not supported by this core"
                )
            parsed_reason_codes[domain] = parsed_codes
        resolution_reason_codes = frozenset(
            parsed_reason_codes["resolution"]
        )
        fallback_resolution_reason_codes = resolution_reason_codes - {
            "policy_selection_accepted"
        }

        select_contract = _require_exact_object(
            profile.get("select_contract"),
            "selection_profile.select_contract",
        )
        select_keys = _require_exact_string_list(
            select_contract.get("required_keys"),
            "select_contract.required_keys",
        )
        select_integer_keys = _require_exact_string_list(
            select_contract.get("raw_integer_keys"),
            "select_contract.raw_integer_keys",
        )
        if not set(select_integer_keys).issubset(select_keys):
            raise ValueError("select integer keys are not a subset of select keys")
        if set(select_keys) != {
            "type",
            "context",
            "minCount",
            "maxCount",
            "remainDamageCounter",
            "remainEnergyCost",
            "option",
            "deck",
            "contextCard",
            "effect",
        }:
            raise ValueError("Select fields are not supported by this core")
        card_shape = _require_exact_object(
            select_contract.get("card_shape"),
            "select_contract.card_shape",
        )
        card_keys = _require_exact_string_list(
            card_shape.get("required_keys"),
            "select_contract.card_shape.required_keys",
        )
        card_integer_keys = _require_exact_string_list(
            card_shape.get("integer_keys"),
            "select_contract.card_shape.integer_keys",
        )
        if card_integer_keys != card_keys:
            raise ValueError("every Card field must be an exact integer")
        if set(card_keys) != {"id", "serial", "playerIndex"}:
            raise ValueError("Card fields are not supported by this core")
        card_positive_integer_keys = _require_exact_string_list(
            card_shape.get("positive_integer_keys"),
            "select_contract.card_shape.positive_integer_keys",
        )
        if card_positive_integer_keys != ("id",):
            raise ValueError("Card positive integer fields are not supported by this core")
        player_index_values = card_shape.get("player_index_values")
        if (
            type(player_index_values) is not list
            or player_index_values != [0, 1]
            or any(type(value) is not int for value in player_index_values)
        ):
            raise ValueError("Card player index values are not locked")

        option_contract = _require_exact_object(
            profile.get("option_contract"),
            "selection_profile.option_contract",
        )
        option_fields = _require_exact_string_list(
            option_contract.get("official_field_order"),
            "option_contract.official_field_order",
        )
        if not option_fields or option_fields[0] != "type":
            raise ValueError("Option field order must begin with type")

        enums = _require_exact_object(snapshot.get("enums"), "enum_snapshot.enums")
        option_types, known_option_types = _require_enum_values(enums, "OptionType")
        _, known_select_types = _require_enum_values(enums, "SelectType")
        _, known_select_contexts = _require_enum_values(enums, "SelectContext")
        _, known_areas = _require_enum_values(enums, "AreaType")
        _, known_special_conditions = _require_enum_values(
            enums,
            "SpecialConditionType",
        )

        sparse_option_types = _require_exact_object(
            sparse.get("option_types"),
            "option_sparse_shapes.option_types",
        )
        if sparse_option_types != option_types:
            raise ValueError("OptionType snapshot and sparse-shape source disagree")
        raw_shapes = _require_exact_object(
            sparse.get("shapes"),
            "option_sparse_shapes.shapes",
        )
        expected_shape_keys = {str(raw) for raw in known_option_types}
        if set(raw_shapes) != expected_shape_keys:
            raise ValueError("sparse Option shapes do not cover the exact enum universe")
        option_field_set = frozenset(option_fields)
        option_shapes: list[tuple[int, tuple[str, ...]]] = []
        for raw_option_type in sorted(known_option_types):
            shape = _require_exact_string_list(
                raw_shapes[str(raw_option_type)],
                f"option_sparse_shapes.shapes.{raw_option_type}",
            )
            if (
                not shape
                or shape[0] != "type"
                or not set(shape).issubset(option_field_set)
            ):
                raise ValueError("sparse Option shape is outside the official universe")
            option_shapes.append((raw_option_type, shape))

        hash_contract = _require_exact_object(
            profile.get("hash_contract"),
            "selection_profile.hash_contract",
        )
        hash_profiles = _require_exact_object(
            hash_contract.get("profiles"),
            "selection_profile.hash_contract.profiles",
        )
        window_prefix = _profile_prefix(hash_profiles, WINDOW_HASH_PROFILE)
        option_fingerprint_prefix = _profile_prefix(
            hash_profiles,
            OPTION_FINGERPRINT_PROFILE,
        )
        initial_deck_prefix = _profile_prefix(hash_profiles, INITIAL_DECK_PROFILE)

        initial_deck_contract = _require_exact_object(
            profile.get("initial_deck_contract"),
            "selection_profile.initial_deck_contract",
        )
        authority = _require_exact_object(
            initial_deck_contract.get("conformance_authority"),
            "initial_deck_contract.conformance_authority",
        )
        required_authority_keys = {
            "artifact_id",
            "source_sha256",
            "scope",
            "card_ids",
            "deck_hash",
            "local_mapping_claim",
            "cabt_exportable_claim",
        }
        if set(authority) != required_authority_keys:
            raise ValueError("pinned deck authority fields are not exact")
        if (
            type(authority["local_mapping_claim"]) is not bool
            or authority["local_mapping_claim"]
            or type(authority["cabt_exportable_claim"]) is not bool
            or authority["cabt_exportable_claim"]
        ):
            raise ValueError("pinned deck authority must not claim local mapping or exportability")
        card_ids = authority["card_ids"]
        if (
            type(card_ids) is not list
            or len(card_ids) != 60
            or any(
                type(card_id) is not int
                or card_id < 1
                or card_id > _SAFE_INTEGER_MAX
                for card_id in card_ids
            )
        ):
            raise ValueError("pinned deck authority has invalid Card IDs")
        for field_name in ("artifact_id", "source_sha256", "scope", "deck_hash"):
            if type(authority[field_name]) is not str or not authority[field_name]:
                raise ValueError("pinned deck authority contains an invalid string")
        if not _is_upper_sha256(authority["source_sha256"]) or not _is_upper_sha256(
            authority["deck_hash"]
        ):
            raise ValueError("pinned deck authority hashes must be uppercase SHA-256")
        computed_deck_hash = _domain_hash(
            initial_deck_prefix,
            {"card_ids": card_ids},
        )
        if computed_deck_hash != authority["deck_hash"]:
            raise ValueError("pinned deck authority hash does not match Card IDs")

        return cls._from_validated(
            construction_token=_CONTRACTS_CONSTRUCTION_TOKEN,
            source_lock_id=source_lock_id,
            source_contract_hash=contract_set.source_contract_hash,
            public_hash_authorities=public_hash_authorities,
            policy_outcomes=policy_outcomes,
            build_fallback_reason_codes=parsed_reason_codes["build_fallback"],
            build_reject_reason_codes=parsed_reason_codes["build_reject"],
            sanitize_reason_codes=parsed_reason_codes["sanitize"],
            resolution_reason_codes=resolution_reason_codes,
            fallback_resolution_reason_codes=fallback_resolution_reason_codes,
            pinned_deck_build_reason_codes=parsed_reason_codes["pinned_deck_build"],
            initial_deck_resolution_reason_codes=parsed_reason_codes[
                "initial_deck_resolution"
            ],
            initial_deck_candidate_reason_codes=parsed_reason_codes[
                "initial_deck_candidate"
            ],
            select_keys=select_keys,
            select_integer_keys=select_integer_keys,
            card_keys=card_keys,
            card_positive_integer_keys=card_positive_integer_keys,
            option_fields=option_fields,
            option_shapes=tuple(option_shapes),
            known_select_types=known_select_types,
            known_select_contexts=known_select_contexts,
            known_areas=known_areas,
            known_special_conditions=known_special_conditions,
            window_prefix=window_prefix,
            option_fingerprint_prefix=option_fingerprint_prefix,
            initial_deck_prefix=initial_deck_prefix,
            pinned_card_ids=tuple(card_ids),
            pinned_deck_hash=authority["deck_hash"],
            pinned_source_artifact_id=authority["artifact_id"],
            pinned_source_sha256=authority["source_sha256"],
            pinned_authority_scope=authority["scope"],
            _construction_seal=_CONTRACTS_CONSTRUCTION_TOKEN,
        )

    def option_shape(self, raw_option_type: int) -> tuple[str, ...] | None:
        for current_raw, shape in self.option_shapes:
            if current_raw == raw_option_type:
                return shape
        return None


DEFAULT_SELECTION_CONTRACTS: Final = CabtSelectionContracts.from_contract_set(
    load_contract_set(_DEFAULT_CONTRACT_ROOT)
)
_EXPECTED_SELECTION_CONTRACT_VALUES: Final = tuple(
    (field.name, getattr(DEFAULT_SELECTION_CONTRACTS, field.name))
    for field in fields(CabtSelectionContracts)
    if field.name != "_construction_seal"
)


def _exact_immutable_contract_value_matches(value: Any, expected: Any) -> bool:
    value_type = type(value)
    if value_type is not type(expected):
        return False
    if value_type in (str, int, bytes):
        return value == expected
    if value_type is tuple:
        return len(value) == len(expected) and all(
            _exact_immutable_contract_value_matches(child, expected_child)
            for child, expected_child in zip(value, expected)
        )
    if value_type is frozenset:
        if len(value) != len(expected):
            return False
        if not all(type(child) in (str, int) for child in value):
            return False
        if not all(type(child) in (str, int) for child in expected):
            return False
        return value == expected
    return False


def _require_selection_contracts(value: Any) -> CabtSelectionContracts:
    if (
        type(value) is not CabtSelectionContracts
        or value._construction_seal is not _CONTRACTS_CONSTRUCTION_TOKEN
        or value.source_contract_hash != EXPECTED_CONTRACT_BUNDLE_SHA256
        or any(
            not _exact_immutable_contract_value_matches(
                getattr(value, field_name),
                expected_value,
            )
            for field_name, expected_value in _EXPECTED_SELECTION_CONTRACT_VALUES
        )
    ):
        raise TypeError("contracts must be the exact verified CabtSelectionContracts")
    return value


_BUILD_ISSUE_POINTER_PATTERNS: Final[dict[str, tuple[str, ...]]] = {
    "public_hash_authority_required": (r"",),
    "invalid_public_observation_hash": (r"",),
    "invalid_chooser_player_index": (r"",),
    "select_not_object": (r"", r"/select"),
    "unknown_public_key": (
        r"",
        r"/select",
        r"/select/(?:contextCard|effect)",
        r"/select/(?:deck|option)/(?:0|[1-9][0-9]*)",
    ),
    "missing_select_field": (r"", r"/select"),
    "invalid_select_field_type": (
        r"",
        r"/select",
        r"/select/(?:type|context|minCount|maxCount|remainDamageCounter|remainEnergyCost|option|deck)",
    ),
    "invalid_cardinality": (r"/select",),
    "invalid_option": (r"/select/option/(?:0|[1-9][0-9]*)",),
    "invalid_card": (
        r"/select/(?:contextCard|effect)",
        r"/select/deck/(?:0|[1-9][0-9]*)",
    ),
    "unknown_select_type": (r"/select/type",),
    "unknown_select_context": (r"/select/context",),
    "unknown_option_type": (r"/select/option/(?:0|[1-9][0-9]*)/type",),
    "unknown_option_enum": (
        r"/select/option/(?:0|[1-9][0-9]*)/(?:area|inPlayArea|specialConditionType)",
    ),
    "sparse_shape_mismatch": (r"/select/option/(?:0|[1-9][0-9]*)",),
}


def _build_issue_pointer_is_valid(code: Any, pointer: Any) -> bool:
    if type(code) is not str or type(pointer) is not str:
        return False
    patterns = _BUILD_ISSUE_POINTER_PATTERNS.get(code)
    return patterns is not None and any(
        re.fullmatch(pattern, pointer) is not None for pattern in patterns
    )


def _snapshot_public_dict(snapshot: Any) -> dict[str, Any]:
    if type(snapshot) is not _FrozenObject:
        return {}
    value = _thaw_json(snapshot)
    return value if type(value) is dict else {}


def _register_owner_result(
    value: Any,
    kind: str,
    snapshot: _FrozenObject,
    binding: Any,
) -> None:
    instance_id = id(value)

    def _discard(dead_ref: weakref.ReferenceType[Any], key: int = instance_id) -> None:
        current = _OWNER_RESULT_REGISTRY.get(key)
        if current is not None and current[0] is dead_ref:
            _OWNER_RESULT_REGISTRY.pop(key, None)

    reference = weakref.ref(value, _discard)
    _OWNER_RESULT_REGISTRY[instance_id] = (reference, kind, snapshot, binding)


def _owner_result_record(
    value: Any,
    kind: str,
) -> tuple[weakref.ReferenceType[Any], str, _FrozenObject, Any] | None:
    record = _OWNER_RESULT_REGISTRY.get(id(value))
    if record is None or record[0]() is not value or record[1] != kind:
        return None
    if type(record[2]) is not _FrozenObject:
        return None
    return record


def _registered_result_public_dict(value: Any, kind: str) -> dict[str, Any]:
    record = _owner_result_record(value, kind)
    if (
        record is None
        or getattr(value, "_construction_seal", None)
        is not _RESULT_CONSTRUCTION_TOKEN
    ):
        return {}
    return _snapshot_public_dict(record[2])


@dataclass(frozen=True, slots=True, init=False, weakref_slot=True)
class CabtSelectionIssue:
    """Owner-produced diagnostic value; it is never accepted as authority."""

    code: str
    pointer: str
    severity: str = "error"
    _construction_seal: object
    _public_snapshot: _FrozenObject

    def __new__(cls) -> CabtSelectionIssue:
        raise TypeError("CabtSelectionIssue instances must be created by the builder")

    @classmethod
    def _from_owner(
        cls,
        code: str,
        pointer: str,
        *,
        construction_token: object,
    ) -> CabtSelectionIssue:
        if construction_token is not _RESULT_CONSTRUCTION_TOKEN:
            raise TypeError("CabtSelectionIssue construction is builder-owned")
        issue = object.__new__(cls)
        object.__setattr__(issue, "code", code)
        object.__setattr__(issue, "pointer", pointer)
        object.__setattr__(issue, "severity", "error")
        object.__setattr__(issue, "_construction_seal", construction_token)
        snapshot = _freeze_json(
            {"code": code, "pointer": pointer, "severity": "error"}
        )
        object.__setattr__(issue, "_public_snapshot", snapshot)
        _register_owner_result(issue, "selection_issue", snapshot, None)
        return issue

    def validate_integrity(self) -> bool:
        if any(
            not hasattr(self, field_name)
            for field_name in (
                "code",
                "pointer",
                "severity",
                "_construction_seal",
                "_public_snapshot",
            )
        ):
            return False
        if (
            type(self) is not CabtSelectionIssue
            or (record := _owner_result_record(self, "selection_issue")) is None
            or record[3] is not None
            or self._construction_seal is not _RESULT_CONSTRUCTION_TOKEN
            or type(self._public_snapshot) is not _FrozenObject
            or self._public_snapshot is not record[2]
            or type(self.code) is not str
            or type(self.pointer) is not str
            or type(self.severity) is not str
            or self.severity != "error"
            or not _build_issue_pointer_is_valid(self.code, self.pointer)
        ):
            return False
        return _snapshot_public_dict(record[2]) == {
            "code": self.code,
            "pointer": self.pointer,
            "severity": self.severity,
        }

    def to_public_dict(self) -> dict[str, str]:
        return _registered_result_public_dict(self, "selection_issue")

    def to_dict(self) -> dict[str, str]:
        return self.to_public_dict()


@dataclass(frozen=True, slots=True, init=False)
class CabtSelectionWindow:
    """Sealed immutable current-window authority produced only by the strict builder."""

    window_version: int
    window_id: str
    hash_profile: str
    option_fingerprint_profile: str
    public_observation_hash: str
    public_hash_authority: str
    chooser_player_index: int
    decision_state: str
    fallback_reasons: tuple[str, ...]
    select_type_raw: int
    select_context_raw: int
    min_count: int
    max_count: int
    remain_damage_counter: int
    remain_energy_cost: int
    _context_card: _FrozenObject | None
    _effect: _FrozenObject | None
    _public_deck_candidates: _FrozenArray | None
    _options: _FrozenArray
    _option_fingerprints: tuple[str, ...]
    _select_payload: _FrozenObject
    _contracts: CabtSelectionContracts

    def __new__(cls) -> CabtSelectionWindow:
        raise TypeError("CabtSelectionWindow instances must be created by build()")

    @classmethod
    def _from_validated(
        cls,
        *,
        construction_token: object,
        window_id: str,
        public_observation_hash: str,
        public_hash_authority: str,
        chooser_player_index: int,
        decision_state: str,
        fallback_reasons: tuple[str, ...],
        select_type_raw: int,
        select_context_raw: int,
        min_count: int,
        max_count: int,
        remain_damage_counter: int,
        remain_energy_cost: int,
        context_card: _FrozenObject | None,
        effect: _FrozenObject | None,
        public_deck_candidates: _FrozenArray | None,
        options: _FrozenArray,
        option_fingerprints: tuple[str, ...],
        select_payload: _FrozenObject,
        contracts: CabtSelectionContracts,
    ) -> CabtSelectionWindow:
        if construction_token is not _WINDOW_CONSTRUCTION_TOKEN:
            raise TypeError("CabtSelectionWindow construction is builder-owned")
        window = object.__new__(cls)
        values = {
            "window_version": WINDOW_VERSION,
            "window_id": window_id,
            "hash_profile": WINDOW_HASH_PROFILE,
            "option_fingerprint_profile": OPTION_FINGERPRINT_PROFILE,
            "public_observation_hash": public_observation_hash,
            "public_hash_authority": public_hash_authority,
            "chooser_player_index": chooser_player_index,
            "decision_state": decision_state,
            "fallback_reasons": fallback_reasons,
            "select_type_raw": select_type_raw,
            "select_context_raw": select_context_raw,
            "min_count": min_count,
            "max_count": max_count,
            "remain_damage_counter": remain_damage_counter,
            "remain_energy_cost": remain_energy_cost,
            "_context_card": context_card,
            "_effect": effect,
            "_public_deck_candidates": public_deck_candidates,
            "_options": options,
            "_option_fingerprints": option_fingerprints,
            "_select_payload": select_payload,
            "_contracts": contracts,
        }
        for field_name, value in values.items():
            object.__setattr__(window, field_name, value)
        return window

    @classmethod
    def build(
        cls,
        select_payload: Any,
        *,
        public_observation_hash: Any,
        public_hash_authority: Any,
        chooser_player_index: Any,
        contracts: CabtSelectionContracts | None = None,
    ) -> CabtSelectionBuildResult:
        return build_cabt_selection_window(
            select_payload,
            public_observation_hash=public_observation_hash,
            public_hash_authority=public_hash_authority,
            chooser_player_index=chooser_player_index,
            contracts=contracts,
        )

    @property
    def context_card(self) -> dict[str, int] | None:
        value = _thaw_json(self._context_card)
        return value

    @property
    def effect(self) -> dict[str, int] | None:
        value = _thaw_json(self._effect)
        return value

    @property
    def public_deck_candidates(self) -> list[dict[str, int]] | None:
        value = _thaw_json(self._public_deck_candidates)
        return value

    @property
    def options(self) -> list[dict[str, int | None]]:
        value = _thaw_json(self._options)
        return value

    @property
    def option_fingerprints(self) -> tuple[str, ...]:
        return self._option_fingerprints

    @property
    def option_count(self) -> int:
        return len(self._option_fingerprints)

    @property
    def policy_allowed(self) -> bool:
        return self.decision_state == "policy_allowed"

    @property
    def select_payload(self) -> dict[str, Any]:
        value = _thaw_json(self._select_payload)
        return value

    def to_public_dict(self) -> dict[str, Any]:
        return {
            "window_version": self.window_version,
            "window_id": self.window_id,
            "hash_profile": self.hash_profile,
            "option_fingerprint_profile": self.option_fingerprint_profile,
            "public_observation_hash": self.public_observation_hash,
            "public_hash_authority": self.public_hash_authority,
            "chooser_player_index": self.chooser_player_index,
            "decision_state": self.decision_state,
            "fallback_reasons": list(self.fallback_reasons),
            "select_type_raw": self.select_type_raw,
            "select_context_raw": self.select_context_raw,
            "min_count": self.min_count,
            "max_count": self.max_count,
            "remain_damage_counter": self.remain_damage_counter,
            "remain_energy_cost": self.remain_energy_cost,
            "context_card": self.context_card,
            "effect": self.effect,
            "public_deck_candidates": self.public_deck_candidates,
            "options": self.options,
            "option_fingerprints": list(self._option_fingerprints),
        }

    def to_dict(self) -> dict[str, Any]:
        return self.to_public_dict()


@dataclass(frozen=True, slots=True, init=False, weakref_slot=True)
class CabtSelectionBuildResult:
    """Owner-produced build value; only its sealed window can authorize selection."""

    decision_state: str
    window: CabtSelectionWindow | None
    issues: tuple[CabtSelectionIssue, ...]
    _contracts: CabtSelectionContracts
    _construction_seal: object
    _public_snapshot: _FrozenObject

    def __new__(cls) -> CabtSelectionBuildResult:
        raise TypeError("CabtSelectionBuildResult instances must be created by the builder")

    @classmethod
    def _from_owner(
        cls,
        decision_state: str,
        window: CabtSelectionWindow | None,
        issues: tuple[CabtSelectionIssue, ...],
        contracts: CabtSelectionContracts,
        *,
        construction_token: object,
    ) -> CabtSelectionBuildResult:
        if construction_token is not _RESULT_CONSTRUCTION_TOKEN:
            raise TypeError("CabtSelectionBuildResult construction is builder-owned")
        issue_tuple = tuple(issues)
        result = object.__new__(cls)
        object.__setattr__(result, "decision_state", decision_state)
        object.__setattr__(result, "window", window)
        object.__setattr__(result, "issues", issue_tuple)
        object.__setattr__(result, "_contracts", contracts)
        object.__setattr__(result, "_construction_seal", construction_token)
        public_value = {
            "decision_state": decision_state,
            "window": None if window is None else window.to_public_dict(),
            "issues": [issue.to_public_dict() for issue in issue_tuple],
        }
        object.__setattr__(result, "_public_snapshot", _freeze_json(public_value))
        _register_owner_result(
            result,
            "selection_build_result",
            result._public_snapshot,
            contracts,
        )
        return result

    @property
    def accepted(self) -> bool:
        return self.window is not None

    @property
    def policy_allowed(self) -> bool:
        return self.decision_state == "policy_allowed" and self.window is not None

    @property
    def fallback_only(self) -> bool:
        return self.decision_state == "fallback_only" and self.window is not None

    @property
    def rejected(self) -> bool:
        return self.decision_state == "reject" and self.window is None

    def validate_integrity(self) -> bool:
        if any(
            not hasattr(self, field_name)
            for field_name in (
                "decision_state",
                "window",
                "issues",
                "_contracts",
                "_construction_seal",
                "_public_snapshot",
            )
        ):
            return False
        try:
            contracts = _require_selection_contracts(self._contracts)
        except (AttributeError, TypeError, ValueError):
            return False
        if (
            type(self) is not CabtSelectionBuildResult
            or (record := _owner_result_record(self, "selection_build_result"))
            is None
            or record[3] is not contracts
            or self._construction_seal is not _RESULT_CONSTRUCTION_TOKEN
            or type(self._public_snapshot) is not _FrozenObject
            or self._public_snapshot is not record[2]
            or type(self.decision_state) is not str
            or self.decision_state not in {"policy_allowed", "fallback_only", "reject"}
            or type(self.issues) is not tuple
            or (
                self.window is not None
                and type(self.window) is not CabtSelectionWindow
            )
            or any(
                type(issue) is not CabtSelectionIssue
                or not issue.validate_integrity()
                for issue in self.issues
            )
        ):
            return False
        live_public = {
            "decision_state": self.decision_state,
            "window": None if self.window is None else self.window.to_public_dict(),
            "issues": [
                {
                    "code": issue.code,
                    "pointer": issue.pointer,
                    "severity": issue.severity,
                }
                for issue in self.issues
            ],
        }
        if _snapshot_public_dict(record[2]) != live_public:
            return False
        if self.decision_state == "reject":
            return (
                self.window is None
                and len(self.issues) == 1
                and self.issues[0].code in contracts.build_reject_reason_codes
            )
        if type(self.window) is not CabtSelectionWindow:
            return False
        try:
            window = _require_current_window(self.window)
        except (AttributeError, TypeError, ValueError):
            return False
        if window._contracts is not contracts or window.decision_state != self.decision_state:
            return False
        if self.decision_state == "policy_allowed":
            return not self.issues and not window.fallback_reasons
        if (
            not self.issues
            or any(
                issue.code not in contracts.build_fallback_reason_codes
                for issue in self.issues
            )
        ):
            return False
        ordered_unique_codes: list[str] = []
        for issue in self.issues:
            if issue.code not in ordered_unique_codes:
                ordered_unique_codes.append(issue.code)
        return tuple(ordered_unique_codes) == window.fallback_reasons

    def to_public_dict(self) -> dict[str, Any]:
        return _registered_result_public_dict(self, "selection_build_result")

    def to_dict(self) -> dict[str, Any]:
        return self.to_public_dict()


@dataclass(frozen=True, slots=True, init=False, weakref_slot=True)
class CabtSelectionValidation:
    """Owner-produced validation value; it is not an executable ticket."""

    accepted: bool
    selected_indexes: tuple[int, ...]
    reason_code: str
    _window_binding: CabtSelectionWindow
    _construction_seal: object
    _public_snapshot: _FrozenObject

    def __new__(cls) -> CabtSelectionValidation:
        raise TypeError("CabtSelectionValidation instances must be created by the sanitizer")

    @classmethod
    def _from_owner(
        cls,
        accepted: bool,
        selected_indexes: tuple[int, ...],
        reason_code: str,
        window: CabtSelectionWindow,
        *,
        construction_token: object,
    ) -> CabtSelectionValidation:
        if construction_token is not _RESULT_CONSTRUCTION_TOKEN:
            raise TypeError("CabtSelectionValidation construction is sanitizer-owned")
        indexes = tuple(selected_indexes)
        result = object.__new__(cls)
        object.__setattr__(result, "accepted", accepted)
        object.__setattr__(result, "selected_indexes", indexes)
        object.__setattr__(result, "reason_code", reason_code)
        object.__setattr__(result, "_window_binding", window)
        object.__setattr__(result, "_construction_seal", construction_token)
        snapshot = _freeze_json(
            {
                "accepted": accepted,
                "selected_indexes": list(indexes),
                "reason_code": reason_code,
            }
        )
        object.__setattr__(result, "_public_snapshot", snapshot)
        _register_owner_result(result, "selection_validation", snapshot, window)
        return result

    def validate_integrity(self, window: CabtSelectionWindow) -> bool:
        if any(
            not hasattr(self, field_name)
            for field_name in (
                "accepted",
                "selected_indexes",
                "reason_code",
                "_window_binding",
                "_construction_seal",
                "_public_snapshot",
            )
        ):
            return False
        try:
            current = _require_current_window(window)
        except (AttributeError, TypeError, ValueError):
            return False
        if (
            type(self) is not CabtSelectionValidation
            or (record := _owner_result_record(self, "selection_validation"))
            is None
            or record[3] is not current
            or self._window_binding is not current
            or self._construction_seal is not _RESULT_CONSTRUCTION_TOKEN
            or type(self._public_snapshot) is not _FrozenObject
            or self._public_snapshot is not record[2]
            or type(self.accepted) is not bool
            or type(self.selected_indexes) is not tuple
            or type(self.reason_code) is not str
            or self.reason_code not in current._contracts.sanitize_reason_codes
        ):
            return False
        live_public = {
            "accepted": self.accepted,
            "selected_indexes": list(self.selected_indexes),
            "reason_code": self.reason_code,
        }
        if _snapshot_public_dict(record[2]) != live_public:
            return False
        if self.accepted:
            return (
                current.policy_allowed
                and self.reason_code == "policy_selection_accepted"
                and _selection_indexes_are_legal(current, self.selected_indexes)
            )
        if self.selected_indexes:
            return False
        if not current.policy_allowed:
            return self.reason_code == "window_fallback_only"
        return self.reason_code in {
            "proposal_not_list",
            "proposal_index_not_exact_int",
            "proposal_cardinality",
            "proposal_index_out_of_range",
            "proposal_duplicate_index",
        }

    def to_public_dict(self) -> dict[str, Any]:
        return _registered_result_public_dict(self, "selection_validation")

    def to_dict(self) -> dict[str, Any]:
        return self.to_public_dict()


@dataclass(frozen=True, slots=True, init=False, weakref_slot=True)
class CabtSelectionResolution:
    """Owner-produced resolution value; callers cannot feed it back as authority."""

    accepted: bool
    window_id: str
    selected_indexes: tuple[int, ...]
    owner: str
    reason_code: str
    fallback_branch: str | None
    _window_binding: CabtSelectionWindow
    _construction_seal: object
    _public_snapshot: _FrozenObject

    def __new__(cls) -> CabtSelectionResolution:
        raise TypeError("CabtSelectionResolution instances must be created by the resolver")

    @classmethod
    def _from_owner(
        cls,
        accepted: bool,
        window_id: str,
        selected_indexes: tuple[int, ...],
        owner: str,
        reason_code: str,
        fallback_branch: str | None,
        window: CabtSelectionWindow,
        *,
        construction_token: object,
    ) -> CabtSelectionResolution:
        if construction_token is not _RESULT_CONSTRUCTION_TOKEN:
            raise TypeError("CabtSelectionResolution construction is resolver-owned")
        indexes = tuple(selected_indexes)
        result = object.__new__(cls)
        for field_name, value in (
            ("accepted", accepted),
            ("window_id", window_id),
            ("selected_indexes", indexes),
            ("owner", owner),
            ("reason_code", reason_code),
            ("fallback_branch", fallback_branch),
            ("_window_binding", window),
            ("_construction_seal", construction_token),
        ):
            object.__setattr__(result, field_name, value)
        snapshot = _freeze_json(
            {
                "accepted": accepted,
                "window_id": window_id,
                "selected_indexes": list(indexes),
                "owner": owner,
                "reason_code": reason_code,
                "fallback_branch": fallback_branch,
            }
        )
        object.__setattr__(result, "_public_snapshot", snapshot)
        _register_owner_result(result, "selection_resolution", snapshot, window)
        return result

    def validate_integrity(self, window: CabtSelectionWindow) -> bool:
        if any(
            not hasattr(self, field_name)
            for field_name in (
                "accepted",
                "window_id",
                "selected_indexes",
                "owner",
                "reason_code",
                "fallback_branch",
                "_window_binding",
                "_construction_seal",
                "_public_snapshot",
            )
        ):
            return False
        try:
            current = _require_current_window(window)
        except (AttributeError, TypeError, ValueError):
            return False
        if (
            type(self) is not CabtSelectionResolution
            or (record := _owner_result_record(self, "selection_resolution"))
            is None
            or record[3] is not current
            or self._window_binding is not current
            or self._construction_seal is not _RESULT_CONSTRUCTION_TOKEN
            or type(self._public_snapshot) is not _FrozenObject
            or self._public_snapshot is not record[2]
            or self.accepted is not True
            or type(self.window_id) is not str
            or self.window_id != current.window_id
            or type(self.selected_indexes) is not tuple
            or type(self.owner) is not str
            or type(self.reason_code) is not str
            or self.reason_code not in current._contracts.resolution_reason_codes
            or not _selection_indexes_are_legal(current, self.selected_indexes)
        ):
            return False
        live_public = {
            "accepted": self.accepted,
            "window_id": self.window_id,
            "selected_indexes": list(self.selected_indexes),
            "owner": self.owner,
            "reason_code": self.reason_code,
            "fallback_branch": self.fallback_branch,
        }
        if _snapshot_public_dict(record[2]) != live_public:
            return False
        if self.owner == "policy":
            return (
                current.policy_allowed
                and self.reason_code == "policy_selection_accepted"
                and self.fallback_branch is None
            )
        if self.owner != "deterministic_fallback":
            return False
        expected_indexes, expected_branch = _fallback_indexes(current)
        return (
            self.reason_code in current._contracts.fallback_resolution_reason_codes
            and self.selected_indexes == expected_indexes
            and self.fallback_branch == expected_branch
        )

    def to_public_dict(self) -> dict[str, Any]:
        return _registered_result_public_dict(self, "selection_resolution")

    def to_dict(self) -> dict[str, Any]:
        return self.to_public_dict()


@dataclass(frozen=True, slots=True)
class CabtPinnedDeckAuthority:
    """Portable DTO that is untrusted until the deck validator rechecks every field."""

    profile: str
    card_ids: tuple[int, ...]
    deck_hash: str
    source_artifact_id: str
    source_sha256: str
    authority_scope: str

    def to_public_dict(self) -> dict[str, Any]:
        return {
            "profile": self.profile,
            "card_ids": list(self.card_ids),
            "deck_hash": self.deck_hash,
            "source_artifact_id": self.source_artifact_id,
            "source_sha256": self.source_sha256,
            "authority_scope": self.authority_scope,
        }

    def to_dict(self) -> dict[str, Any]:
        return self.to_public_dict()


@dataclass(frozen=True, slots=True, init=False, weakref_slot=True)
class CabtPinnedDeckBuildResult:
    """Sealed result for constructing the one normative pinned deck authority."""

    accepted: bool
    reason_code: str
    pinned_deck: CabtPinnedDeckAuthority | None
    _contracts: CabtSelectionContracts
    _construction_seal: object
    _public_snapshot: _FrozenObject

    def __new__(cls) -> CabtPinnedDeckBuildResult:
        raise TypeError("CabtPinnedDeckBuildResult instances must be created by the deck validator")

    @classmethod
    def _from_owner(
        cls,
        accepted: bool,
        reason_code: str,
        pinned_deck: CabtPinnedDeckAuthority | None,
        contracts: CabtSelectionContracts,
        *,
        construction_token: object,
    ) -> CabtPinnedDeckBuildResult:
        if construction_token is not _RESULT_CONSTRUCTION_TOKEN:
            raise TypeError("CabtPinnedDeckBuildResult construction is deck-validator-owned")
        result = object.__new__(cls)
        for field_name, value in (
            ("accepted", accepted),
            ("reason_code", reason_code),
            ("pinned_deck", pinned_deck),
            ("_contracts", contracts),
            ("_construction_seal", construction_token),
        ):
            object.__setattr__(result, field_name, value)
        snapshot = _freeze_json(
            {
                "accepted": accepted,
                "reason_code": reason_code,
                "pinned_deck": (
                    None if pinned_deck is None else pinned_deck.to_public_dict()
                ),
            }
        )
        object.__setattr__(result, "_public_snapshot", snapshot)
        _register_owner_result(result, "pinned_deck_build_result", snapshot, contracts)
        return result

    def validate_integrity(self, contracts: CabtSelectionContracts) -> bool:
        if any(
            not hasattr(self, field_name)
            for field_name in (
                "accepted",
                "reason_code",
                "pinned_deck",
                "_contracts",
                "_construction_seal",
                "_public_snapshot",
            )
        ):
            return False
        try:
            verified_contracts = _require_selection_contracts(contracts)
            own_contracts = _require_selection_contracts(self._contracts)
        except (AttributeError, TypeError, ValueError):
            return False
        if (
            type(self) is not CabtPinnedDeckBuildResult
            or (record := _owner_result_record(self, "pinned_deck_build_result"))
            is None
            or record[3] is not verified_contracts
            or own_contracts is not verified_contracts
            or self._construction_seal is not _RESULT_CONSTRUCTION_TOKEN
            or type(self._public_snapshot) is not _FrozenObject
            or self._public_snapshot is not record[2]
            or type(self.accepted) is not bool
            or type(self.reason_code) is not str
            or self.reason_code not in own_contracts.pinned_deck_build_reason_codes
            or (
                self.pinned_deck is not None
                and type(self.pinned_deck) is not CabtPinnedDeckAuthority
            )
        ):
            return False
        live_public = {
            "accepted": self.accepted,
            "reason_code": self.reason_code,
            "pinned_deck": (
                None
                if self.pinned_deck is None
                else self.pinned_deck.to_public_dict()
            ),
        }
        if _snapshot_public_dict(record[2]) != live_public:
            return False
        if self.accepted:
            return (
                self.reason_code == "pinned_deck_accepted"
                and type(self.pinned_deck) is CabtPinnedDeckAuthority
                and _authority_from_any(self.pinned_deck, own_contracts) is not None
            )
        return self.reason_code == "invalid_pinned_deck" and self.pinned_deck is None

    def to_public_dict(self) -> dict[str, Any]:
        return _registered_result_public_dict(self, "pinned_deck_build_result")

    def to_dict(self) -> dict[str, Any]:
        return self.to_public_dict()


@dataclass(frozen=True, slots=True, init=False, weakref_slot=True)
class CabtInitialDeckResolution:
    """Owner-produced initial-deck result; it is never accepted as deck authority."""

    accepted: bool
    selected_card_ids: tuple[int, ...]
    owner: str
    reason_code: str
    fallback_branch: str | None
    deck_hash: str | None
    candidate_reason_code: str
    _authority_binding: Any
    _contracts: CabtSelectionContracts
    _construction_seal: object
    _public_snapshot: _FrozenObject

    def __new__(cls) -> CabtInitialDeckResolution:
        raise TypeError("CabtInitialDeckResolution instances must be created by the deck resolver")

    @classmethod
    def _from_owner(
        cls,
        accepted: bool,
        selected_card_ids: tuple[int, ...],
        owner: str,
        reason_code: str,
        fallback_branch: str | None,
        deck_hash: str | None,
        candidate_reason_code: str,
        contracts: CabtSelectionContracts,
        authority: Any,
        *,
        construction_token: object,
    ) -> CabtInitialDeckResolution:
        if construction_token is not _RESULT_CONSTRUCTION_TOKEN:
            raise TypeError("CabtInitialDeckResolution construction is deck-validator-owned")
        selected = tuple(selected_card_ids)
        result = object.__new__(cls)
        for field_name, value in (
            ("accepted", accepted),
            ("selected_card_ids", selected),
            ("owner", owner),
            ("reason_code", reason_code),
            ("fallback_branch", fallback_branch),
            ("deck_hash", deck_hash),
            ("candidate_reason_code", candidate_reason_code),
            ("_authority_binding", authority),
            ("_contracts", contracts),
            ("_construction_seal", construction_token),
        ):
            object.__setattr__(result, field_name, value)
        snapshot = _freeze_json(
            {
                "accepted": accepted,
                "selected_card_ids": list(selected),
                "owner": owner,
                "reason_code": reason_code,
                "fallback_branch": fallback_branch,
                "deck_hash": deck_hash,
                "candidate_reason_code": candidate_reason_code,
            }
        )
        object.__setattr__(result, "_public_snapshot", snapshot)
        _register_owner_result(result, "initial_deck_resolution", snapshot, authority)
        return result

    def validate_integrity(self, authority: Any) -> bool:
        if any(
            not hasattr(self, field_name)
            for field_name in (
                "accepted",
                "selected_card_ids",
                "owner",
                "reason_code",
                "fallback_branch",
                "deck_hash",
                "candidate_reason_code",
                "_authority_binding",
                "_contracts",
                "_construction_seal",
                "_public_snapshot",
            )
        ):
            return False
        try:
            contracts = _require_selection_contracts(self._contracts)
        except (AttributeError, TypeError, ValueError):
            return False
        if (
            type(self) is not CabtInitialDeckResolution
            or (record := _owner_result_record(self, "initial_deck_resolution"))
            is None
            or record[3] is not authority
            or self._authority_binding is not authority
            or self._construction_seal is not _RESULT_CONSTRUCTION_TOKEN
            or type(self._public_snapshot) is not _FrozenObject
            or self._public_snapshot is not record[2]
            or type(self.accepted) is not bool
            or type(self.selected_card_ids) is not tuple
            or type(self.owner) is not str
            or type(self.reason_code) is not str
            or self.reason_code not in contracts.initial_deck_resolution_reason_codes
            or type(self.candidate_reason_code) is not str
            or self.candidate_reason_code
            not in contracts.initial_deck_candidate_reason_codes
        ):
            return False
        live_public = {
            "accepted": self.accepted,
            "selected_card_ids": list(self.selected_card_ids),
            "owner": self.owner,
            "reason_code": self.reason_code,
            "fallback_branch": self.fallback_branch,
            "deck_hash": self.deck_hash,
            "candidate_reason_code": self.candidate_reason_code,
        }
        if _snapshot_public_dict(record[2]) != live_public:
            return False
        verified = _authority_from_any(authority, contracts)
        if verified is None:
            return live_public == {
                "accepted": False,
                "selected_card_ids": [],
                "owner": "none",
                "reason_code": "invalid_pinned_deck",
                "fallback_branch": None,
                "deck_hash": None,
                "candidate_reason_code": "invalid_pinned_deck",
            }
        if (
            not self.accepted
            or self.selected_card_ids != verified.card_ids
            or self.deck_hash != verified.deck_hash
        ):
            return False
        if self.owner == "initial_candidate":
            return (
                self.reason_code == "pinned_deck_accepted"
                and self.candidate_reason_code == "pinned_deck_accepted"
                and self.fallback_branch is None
            )
        return (
            self.owner == "pinned_deck_fallback"
            and self.reason_code == "pinned_deck_fallback"
            and self.candidate_reason_code
            in contracts.initial_deck_candidate_reason_codes
            - {"pinned_deck_accepted", "invalid_pinned_deck"}
            and self.fallback_branch == "pinned_verified_deck"
        )

    def to_public_dict(self) -> dict[str, Any]:
        return _registered_result_public_dict(self, "initial_deck_resolution")

    def to_dict(self) -> dict[str, Any]:
        return self.to_public_dict()


def _selection_issue(code: str, pointer: str) -> CabtSelectionIssue:
    return CabtSelectionIssue._from_owner(
        code,
        pointer,
        construction_token=_RESULT_CONSTRUCTION_TOKEN,
    )


def _selection_build_result(
    decision_state: str,
    window: CabtSelectionWindow | None,
    issues: tuple[CabtSelectionIssue, ...],
    contracts: CabtSelectionContracts,
) -> CabtSelectionBuildResult:
    return CabtSelectionBuildResult._from_owner(
        decision_state,
        window,
        issues,
        contracts,
        construction_token=_RESULT_CONSTRUCTION_TOKEN,
    )


def _selection_validation(
    accepted: bool,
    selected_indexes: tuple[int, ...],
    reason_code: str,
    window: CabtSelectionWindow,
) -> CabtSelectionValidation:
    return CabtSelectionValidation._from_owner(
        accepted,
        selected_indexes,
        reason_code,
        window,
        construction_token=_RESULT_CONSTRUCTION_TOKEN,
    )


def _selection_resolution(
    *,
    accepted: bool,
    window_id: str,
    selected_indexes: tuple[int, ...],
    owner: str,
    reason_code: str,
    fallback_branch: str | None,
    window: CabtSelectionWindow,
) -> CabtSelectionResolution:
    return CabtSelectionResolution._from_owner(
        accepted,
        window_id,
        selected_indexes,
        owner,
        reason_code,
        fallback_branch,
        window,
        construction_token=_RESULT_CONSTRUCTION_TOKEN,
    )


def _initial_deck_resolution(
    *,
    accepted: bool,
    selected_card_ids: tuple[int, ...],
    owner: str,
    reason_code: str,
    fallback_branch: str | None,
    deck_hash: str | None,
    candidate_reason_code: str,
    contracts: CabtSelectionContracts,
    authority: Any,
) -> CabtInitialDeckResolution:
    return CabtInitialDeckResolution._from_owner(
        accepted,
        selected_card_ids,
        owner,
        reason_code,
        fallback_branch,
        deck_hash,
        candidate_reason_code,
        contracts,
        authority,
        construction_token=_RESULT_CONSTRUCTION_TOKEN,
    )


def _pinned_deck_build_result(
    *,
    accepted: bool,
    reason_code: str,
    pinned_deck: CabtPinnedDeckAuthority | None,
    contracts: CabtSelectionContracts,
) -> CabtPinnedDeckBuildResult:
    return CabtPinnedDeckBuildResult._from_owner(
        accepted,
        reason_code,
        pinned_deck,
        contracts,
        construction_token=_RESULT_CONSTRUCTION_TOKEN,
    )


def _reject_build(
    code: str,
    pointer: str,
    contracts: CabtSelectionContracts = DEFAULT_SELECTION_CONTRACTS,
) -> CabtSelectionBuildResult:
    return _selection_build_result(
        "reject",
        None,
        (_selection_issue(code, pointer),),
        contracts,
    )


def _copy_card(
    value: Any,
    pointer: str,
    contracts: CabtSelectionContracts,
) -> tuple[dict[str, int] | None, CabtSelectionIssue | None]:
    if type(value) is not dict:
        return None, _selection_issue("invalid_card", pointer)
    if any(type(key) is not str for key in value):
        return None, _selection_issue("unknown_public_key", pointer)
    keys = frozenset(value)
    card_key_set = frozenset(contracts.card_keys)
    if keys - card_key_set:
        return None, _selection_issue("unknown_public_key", pointer)
    if keys != card_key_set:
        return None, _selection_issue("invalid_card", pointer)
    for key in contracts.card_keys:
        if not _is_exact_safe_int(value[key]):
            return None, _selection_issue("invalid_card", pointer)
    for key in contracts.card_positive_integer_keys:
        if value[key] < 1:
            return None, _selection_issue("invalid_card", pointer)
    if value["playerIndex"] not in (0, 1):
        return None, _selection_issue("invalid_card", pointer)
    return {key: value[key] for key in contracts.card_keys}, None


def _copy_option(
    value: Any,
    pointer: str,
    contracts: CabtSelectionContracts,
) -> tuple[dict[str, int | None] | None, tuple[CabtSelectionIssue, ...], CabtSelectionIssue | None]:
    if type(value) is not dict:
        return None, (), _selection_issue("invalid_option", pointer)
    if any(type(key) is not str for key in value):
        return None, (), _selection_issue("unknown_public_key", pointer)
    keys = frozenset(value)
    if keys - frozenset(contracts.option_fields):
        return None, (), _selection_issue("unknown_public_key", pointer)
    if "type" not in value or not _is_exact_safe_int(value["type"]):
        return None, (), _selection_issue("invalid_option", pointer)
    copied: dict[str, int | None] = {}
    for field_name in contracts.option_fields:
        if field_name not in value:
            continue
        field_value = value[field_name]
        if field_name == "type":
            copied[field_name] = field_value
            continue
        if field_value is not None and not _is_exact_safe_int(field_value):
            return None, (), _selection_issue("invalid_option", pointer)
        if (
            field_name == "cardId"
            and field_value is not None
            and field_value < 1
            and not (
                value["type"] == 15
                and field_value == 0
                and value.get("serial") == 0
            )
        ):
            return None, (), _selection_issue("invalid_option", pointer)
        copied[field_name] = field_value

    fallback_issues: list[CabtSelectionIssue] = []
    option_type = value["type"]
    expected_shape = contracts.option_shape(option_type)
    if expected_shape is None:
        fallback_issues.append(_selection_issue("unknown_option_type", f"{pointer}/type"))
    else:
        sparse_mismatch = keys != frozenset(expected_shape)
        if not sparse_mismatch:
            sparse_mismatch = any(value[field] is None for field in expected_shape[1:])
        if sparse_mismatch:
            fallback_issues.append(_selection_issue("sparse_shape_mismatch", pointer))
    if option_type == 15:
        card_id = copied.get("cardId")
        serial = copied.get("serial")
        if not (
            (card_id == 0 and serial == 0)
            or (
                type(card_id) is int
                and type(serial) is int
                and card_id > 0
                and serial > 0
            )
        ):
            return None, (), _selection_issue("invalid_option", pointer)

    for field_name in ("area", "inPlayArea"):
        if field_name in copied and copied[field_name] is not None:
            if copied[field_name] not in contracts.known_areas:
                fallback_issues.append(
                    _selection_issue("unknown_option_enum", f"{pointer}/{field_name}")
                )
    if (
        "specialConditionType" in copied
        and copied["specialConditionType"] is not None
        and copied["specialConditionType"] not in contracts.known_special_conditions
    ):
        fallback_issues.append(
            _selection_issue("unknown_option_enum", f"{pointer}/specialConditionType")
        )
    return copied, tuple(fallback_issues), None


def _append_unique_reason(reasons: list[str], code: str) -> None:
    if code not in reasons:
        reasons.append(code)


def build_cabt_selection_window(
    select_payload: Any,
    *,
    public_observation_hash: Any,
    public_hash_authority: Any,
    chooser_player_index: Any,
    contracts: CabtSelectionContracts | None = None,
) -> CabtSelectionBuildResult:
    if contracts is None:
        contracts = DEFAULT_SELECTION_CONTRACTS
    contracts = _require_selection_contracts(contracts)
    if (
        type(public_hash_authority) is not str
        or public_hash_authority not in contracts.public_hash_authorities
    ):
        return _reject_build("public_hash_authority_required", "", contracts)
    if not _is_upper_sha256(public_observation_hash):
        return _reject_build("invalid_public_observation_hash", "", contracts)
    if type(chooser_player_index) is not int or chooser_player_index not in (0, 1):
        return _reject_build("invalid_chooser_player_index", "", contracts)
    if type(select_payload) is not dict:
        return _reject_build("select_not_object", "/select", contracts)
    if any(type(key) is not str for key in select_payload):
        return _reject_build("unknown_public_key", "/select", contracts)
    select_keys = frozenset(select_payload)
    if select_keys - frozenset(contracts.select_keys):
        return _reject_build("unknown_public_key", "/select", contracts)
    for field_name in contracts.select_keys:
        if field_name not in select_payload:
            return _reject_build("missing_select_field", "/select", contracts)
    for field_name in contracts.select_integer_keys:
        if not _is_exact_safe_int(select_payload[field_name]):
            return _reject_build(
                "invalid_select_field_type", f"/select/{field_name}", contracts
            )
    options_value = select_payload["option"]
    if type(options_value) is not list:
        return _reject_build("invalid_select_field_type", "/select/option", contracts)
    min_count = select_payload["minCount"]
    max_count = select_payload["maxCount"]
    option_count = len(options_value)
    if not (0 <= min_count <= max_count <= option_count):
        return _reject_build("invalid_cardinality", "/select", contracts)

    copied_deck: list[dict[str, int]] | None
    deck_value = select_payload["deck"]
    if deck_value is None:
        copied_deck = None
    elif type(deck_value) is list:
        copied_deck = []
        for index, card_value in enumerate(deck_value):
            card, card_issue = _copy_card(
                card_value,
                f"/select/deck/{index}",
                contracts,
            )
            if card_issue is not None:
                return _selection_build_result("reject", None, (card_issue,), contracts)
            copied_deck.append(card)
    else:
        return _reject_build("invalid_select_field_type", "/select/deck", contracts)

    copied_cards: dict[str, dict[str, int] | None] = {}
    for field_name in ("contextCard", "effect"):
        card_value = select_payload[field_name]
        if card_value is None:
            copied_cards[field_name] = None
            continue
        card, card_issue = _copy_card(
            card_value,
            f"/select/{field_name}",
            contracts,
        )
        if card_issue is not None:
            return _selection_build_result("reject", None, (card_issue,), contracts)
        copied_cards[field_name] = card

    copied_options: list[dict[str, int | None]] = []
    fallback_issues: list[CabtSelectionIssue] = []
    if select_payload["type"] not in contracts.known_select_types:
        fallback_issues.append(_selection_issue("unknown_select_type", "/select/type"))
    if select_payload["context"] not in contracts.known_select_contexts:
        fallback_issues.append(
            _selection_issue("unknown_select_context", "/select/context")
        )
    for index, option_value in enumerate(options_value):
        copied_option, option_fallbacks, option_issue = _copy_option(
            option_value,
            f"/select/option/{index}",
            contracts,
        )
        if option_issue is not None:
            return _selection_build_result("reject", None, (option_issue,), contracts)
        copied_options.append(copied_option)
        fallback_issues.extend(option_fallbacks)

    fallback_reasons: list[str] = []
    for issue in fallback_issues:
        _append_unique_reason(fallback_reasons, issue.code)
    decision_state = "fallback_only" if fallback_reasons else "policy_allowed"
    copied_select: dict[str, Any] = {
        "type": select_payload["type"],
        "context": select_payload["context"],
        "minCount": min_count,
        "maxCount": max_count,
        "remainDamageCounter": select_payload["remainDamageCounter"],
        "remainEnergyCost": select_payload["remainEnergyCost"],
        "option": copied_options,
        "deck": copied_deck,
        "contextCard": copied_cards["contextCard"],
        "effect": copied_cards["effect"],
    }
    try:
        window_id = _domain_hash(
            contracts.window_prefix,
            {
                "chooser_player_index": chooser_player_index,
                "public_observation_hash": public_observation_hash,
                "select": copied_select,
            },
        )
        fingerprints: list[str] = []
        for option_index, option in enumerate(copied_options):
            fingerprints.append(
                _domain_hash(
                    contracts.option_fingerprint_prefix,
                    {
                        "window_id": window_id,
                        "public_observation_hash": public_observation_hash,
                        "option_index": option_index,
                        "select_type_raw": select_payload["type"],
                        "select_context_raw": select_payload["context"],
                        "option": option,
                        "context_card": copied_cards["contextCard"],
                        "effect": copied_cards["effect"],
                    },
                )
            )
    except CabtTreeHashError:
        return _reject_build("invalid_select_field_type", "/select", contracts)

    frozen_context = _freeze_json(copied_cards["contextCard"])
    frozen_effect = _freeze_json(copied_cards["effect"])
    frozen_deck = _freeze_json(copied_deck)
    frozen_options = _freeze_json(copied_options)
    frozen_select = _freeze_json(copied_select)
    window = CabtSelectionWindow._from_validated(
        construction_token=_WINDOW_CONSTRUCTION_TOKEN,
        window_id=window_id,
        public_observation_hash=public_observation_hash,
        public_hash_authority=public_hash_authority,
        chooser_player_index=chooser_player_index,
        decision_state=decision_state,
        fallback_reasons=tuple(fallback_reasons),
        select_type_raw=select_payload["type"],
        select_context_raw=select_payload["context"],
        min_count=min_count,
        max_count=max_count,
        remain_damage_counter=select_payload["remainDamageCounter"],
        remain_energy_cost=select_payload["remainEnergyCost"],
        context_card=frozen_context,
        effect=frozen_effect,
        public_deck_candidates=frozen_deck,
        options=frozen_options,
        option_fingerprints=tuple(fingerprints),
        select_payload=frozen_select,
        contracts=contracts,
    )
    return _selection_build_result(
        decision_state,
        window,
        tuple(fallback_issues),
        contracts,
    )


def _require_current_window(window: Any) -> CabtSelectionWindow:
    if type(window) is not CabtSelectionWindow:
        raise TypeError("window must be an exact CabtSelectionWindow")
    try:
        rebuilt = build_cabt_selection_window(
            window.select_payload,
            public_observation_hash=window.public_observation_hash,
            public_hash_authority=window.public_hash_authority,
            chooser_player_index=window.chooser_player_index,
            contracts=window._contracts,
        )
    except (AttributeError, CabtTreeHashError, TypeError, ValueError):
        raise ValueError("window integrity validation failed") from None
    if rebuilt.window is None or rebuilt.window != window:
        raise ValueError("window integrity validation failed")
    return window


def _selection_indexes_are_legal(
    window: CabtSelectionWindow,
    indexes: Any,
) -> bool:
    return (
        type(indexes) is tuple
        and all(type(index) is int for index in indexes)
        and window.min_count <= len(indexes) <= window.max_count
        and all(0 <= index < window.option_count for index in indexes)
        and len(set(indexes)) == len(indexes)
    )


class CabtSelectionSanitizer:
    __slots__ = ()

    @staticmethod
    def validate(window: CabtSelectionWindow, proposal: Any) -> CabtSelectionValidation:
        window = _require_current_window(window)
        if not window.policy_allowed:
            return _selection_validation(False, (), "window_fallback_only", window)
        if type(proposal) is not list:
            return _selection_validation(False, (), "proposal_not_list", window)
        for index in proposal:
            if type(index) is not int:
                return _selection_validation(
                    False, (), "proposal_index_not_exact_int", window
                )
        if not (window.min_count <= len(proposal) <= window.max_count):
            return _selection_validation(False, (), "proposal_cardinality", window)
        for index in proposal:
            if index < 0 or index >= window.option_count:
                return _selection_validation(
                    False, (), "proposal_index_out_of_range", window
                )
        seen: set[int] = set()
        for index in proposal:
            if index in seen:
                return _selection_validation(
                    False, (), "proposal_duplicate_index", window
                )
            seen.add(index)
        return _selection_validation(
            True, tuple(proposal), "policy_selection_accepted", window
        )

    @staticmethod
    def resolve_policy_attempt(
        window: CabtSelectionWindow,
        proposal: Any = None,
        *,
        outcome: Any = "returned",
    ) -> CabtSelectionResolution:
        return CabtDeterministicFallback.resolve_policy_attempt(
            window,
            proposal,
            outcome=outcome,
        )

    sanitize = validate


def sanitize_selection(
    window: CabtSelectionWindow,
    proposal: Any,
) -> CabtSelectionValidation:
    return CabtSelectionSanitizer.validate(window, proposal)


def _fallback_indexes(window: CabtSelectionWindow) -> tuple[tuple[int, ...], str]:
    if window.min_count == 0:
        return (), "optional_zero"
    if (
        window.min_count == window.max_count
        and window.max_count == window.option_count
    ):
        return tuple(range(window.option_count)), "forced_all"
    return tuple(range(window.min_count)), "first_minimum"


class CabtDeterministicFallback:
    __slots__ = ()

    @staticmethod
    def resolve(
        window: CabtSelectionWindow,
        *,
        reason_code: Any = "window_fallback_only",
    ) -> CabtSelectionResolution:
        window = _require_current_window(window)
        if (
            type(reason_code) is not str
            or reason_code not in window._contracts.fallback_resolution_reason_codes
        ):
            reason_code = "policy_unavailable"
        indexes, branch = _fallback_indexes(window)
        return _selection_resolution(
            accepted=True,
            window_id=window.window_id,
            selected_indexes=indexes,
            owner="deterministic_fallback",
            reason_code=reason_code,
            fallback_branch=branch,
            window=window,
        )

    @staticmethod
    def resolve_policy_attempt(
        window: CabtSelectionWindow,
        proposal: Any = None,
        *,
        outcome: Any = "returned",
    ) -> CabtSelectionResolution:
        window = _require_current_window(window)
        if not window.policy_allowed:
            return CabtDeterministicFallback.resolve(
                window, reason_code="window_fallback_only"
            )
        if type(outcome) is not str or outcome not in window._contracts.policy_outcomes:
            outcome = "unavailable"
        if outcome == "returned":
            validation = CabtSelectionSanitizer.validate(window, proposal)
            if validation.accepted:
                return _selection_resolution(
                    accepted=True,
                    window_id=window.window_id,
                    selected_indexes=validation.selected_indexes,
                    owner="policy",
                    reason_code="policy_selection_accepted",
                    fallback_branch=None,
                    window=window,
                )
            return CabtDeterministicFallback.resolve(
                window, reason_code="invalid_policy_output"
            )
        reason_by_outcome = {
            "exception": "policy_exception",
            "timeout": "policy_timeout",
            "unavailable": "policy_unavailable",
        }
        return CabtDeterministicFallback.resolve(
            window, reason_code=reason_by_outcome[outcome]
        )

    select = resolve


def deterministic_fallback(window: CabtSelectionWindow) -> CabtSelectionResolution:
    return CabtDeterministicFallback.resolve(window)


def resolve_selection(
    window: CabtSelectionWindow,
    proposal: Any = None,
    policy_outcome: Any = "returned",
) -> CabtSelectionResolution:
    return CabtDeterministicFallback.resolve_policy_attempt(
        window,
        proposal,
        outcome=policy_outcome,
    )


def _deck_shape_error(value: Any) -> str | None:
    if type(value) is not list:
        return "deck_not_list"
    if len(value) != 60:
        return "deck_cardinality"
    for card_id in value:
        if type(card_id) is not int:
            return "deck_card_not_exact_int"
    for card_id in value:
        if card_id < 1 or card_id > _SAFE_INTEGER_MAX:
            return "deck_card_not_positive"
    return None


def _initial_candidate_reason(
    candidate: Any,
    policy_outcome: str,
    verified: CabtPinnedDeckAuthority,
) -> str:
    if policy_outcome == "exception":
        return "deck_exception"
    if policy_outcome == "timeout":
        return "deck_timeout"
    if policy_outcome != "returned":
        return "deck_unavailable"
    shape_error = _deck_shape_error(candidate)
    if shape_error is not None:
        return shape_error
    if tuple(candidate) != verified.card_ids:
        return "deck_mismatch"
    return "pinned_deck_accepted"


def _initial_deck_hash_valid(
    card_ids: tuple[int, ...] | list[int],
    contracts: CabtSelectionContracts,
) -> str:
    return _domain_hash(
        contracts.initial_deck_prefix,
        {"card_ids": list(card_ids)},
    )


def initial_deck_hash(
    card_ids: Any,
    *,
    contracts: CabtSelectionContracts | None = None,
) -> str:
    if contracts is None:
        contracts = DEFAULT_SELECTION_CONTRACTS
    contracts = _require_selection_contracts(contracts)
    reason = _deck_shape_error(card_ids)
    if reason is not None:
        raise ValueError(reason)
    return _initial_deck_hash_valid(card_ids, contracts)


def _authority_from_any(
    value: Any,
    contracts: CabtSelectionContracts,
) -> CabtPinnedDeckAuthority | None:
    if type(value) is CabtPinnedDeckAuthority:
        authority = value
        if (
            type(authority.card_ids) is not tuple
            or len(authority.card_ids) != 60
            or any(
                type(card_id) is not int
                or card_id < 1
                or card_id > _SAFE_INTEGER_MAX
                for card_id in authority.card_ids
            )
            or any(
                type(getattr(authority, field)) is not str
                for field in (
                    "profile",
                    "deck_hash",
                    "source_artifact_id",
                    "source_sha256",
                    "authority_scope",
                )
            )
        ):
            return None
    elif type(value) is dict:
        required = {
            "profile",
            "card_ids",
            "deck_hash",
            "source_artifact_id",
            "source_sha256",
            "authority_scope",
        }
        if any(type(key) is not str for key in value) or set(value) != required:
            return None
        if _deck_shape_error(value["card_ids"]) is not None:
            return None
        if any(
            type(value[field]) is not str
            for field in (
                "profile",
                "deck_hash",
                "source_artifact_id",
                "source_sha256",
                "authority_scope",
            )
        ):
            return None
        authority = CabtPinnedDeckAuthority(
            profile=value["profile"],
            card_ids=tuple(value["card_ids"]),
            deck_hash=value["deck_hash"],
            source_artifact_id=value["source_artifact_id"],
            source_sha256=value["source_sha256"],
            authority_scope=value["authority_scope"],
        )
    else:
        return None
    if authority.profile != INITIAL_DECK_PROFILE:
        return None
    if authority.card_ids != contracts.pinned_card_ids:
        return None
    if authority.deck_hash != contracts.pinned_deck_hash:
        return None
    if authority.source_artifact_id != contracts.pinned_source_artifact_id:
        return None
    if authority.source_sha256 != contracts.pinned_source_sha256:
        return None
    if authority.authority_scope != contracts.pinned_authority_scope:
        return None
    if not _is_upper_sha256(authority.deck_hash) or not _is_upper_sha256(
        authority.source_sha256
    ):
        return None
    if _initial_deck_hash_valid(authority.card_ids, contracts) != authority.deck_hash:
        return None
    return authority


_UNSET: Final = object()


class CabtDeckSelectionValidator:
    __slots__ = ()

    @staticmethod
    def build_marnie_conformance_authority(
        *,
        contracts: CabtSelectionContracts | None = None,
    ) -> CabtPinnedDeckAuthority:
        if contracts is None:
            contracts = DEFAULT_SELECTION_CONTRACTS
        contracts = _require_selection_contracts(contracts)
        authority = CabtPinnedDeckAuthority(
            profile=INITIAL_DECK_PROFILE,
            card_ids=contracts.pinned_card_ids,
            deck_hash=contracts.pinned_deck_hash,
            source_artifact_id=contracts.pinned_source_artifact_id,
            source_sha256=contracts.pinned_source_sha256,
            authority_scope=contracts.pinned_authority_scope,
        )
        if _authority_from_any(authority, contracts) is None:
            raise RuntimeError("locked Marnie conformance authority is inconsistent")
        return authority

    @staticmethod
    def build_pinned_deck(
        card_ids: Any = _UNSET,
        *,
        deck_hash: Any = _UNSET,
        source_artifact_id: Any = _UNSET,
        source_sha256: Any = _UNSET,
        authority_scope: Any = _UNSET,
        contracts: CabtSelectionContracts | None = None,
    ) -> CabtPinnedDeckBuildResult:
        if contracts is None:
            contracts = DEFAULT_SELECTION_CONTRACTS
        contracts = _require_selection_contracts(contracts)
        if card_ids is _UNSET:
            card_ids = list(contracts.pinned_card_ids)
        if deck_hash is _UNSET:
            deck_hash = contracts.pinned_deck_hash
        if source_artifact_id is _UNSET:
            source_artifact_id = contracts.pinned_source_artifact_id
        if source_sha256 is _UNSET:
            source_sha256 = contracts.pinned_source_sha256
        if authority_scope is _UNSET:
            authority_scope = contracts.pinned_authority_scope
        verified: CabtPinnedDeckAuthority | None = None
        if _deck_shape_error(card_ids) is None:
            candidate = CabtPinnedDeckAuthority(
                profile=INITIAL_DECK_PROFILE,
                card_ids=tuple(card_ids),
                deck_hash=deck_hash,
                source_artifact_id=source_artifact_id,
                source_sha256=source_sha256,
                authority_scope=authority_scope,
            )
            verified = _authority_from_any(candidate, contracts)
        return _pinned_deck_build_result(
            accepted=verified is not None,
            reason_code=(
                "pinned_deck_accepted"
                if verified is not None
                else "invalid_pinned_deck"
            ),
            pinned_deck=verified,
            contracts=contracts,
        )

    @staticmethod
    def build_pinned_deck_authority(
        card_ids: Any = _UNSET,
        *,
        deck_hash: Any = _UNSET,
        source_artifact_id: Any = _UNSET,
        source_sha256: Any = _UNSET,
        authority_scope: Any = _UNSET,
        contracts: CabtSelectionContracts | None = None,
    ) -> CabtPinnedDeckAuthority | None:
        result = CabtDeckSelectionValidator.build_pinned_deck(
            card_ids,
            deck_hash=deck_hash,
            source_artifact_id=source_artifact_id,
            source_sha256=source_sha256,
            authority_scope=authority_scope,
            contracts=contracts,
        )
        if not result.validate_integrity(result._contracts):
            return None
        return result.pinned_deck

    @staticmethod
    def resolve(
        authority: Any,
        candidate: Any = None,
        *,
        policy_outcome: Any = "returned",
        contracts: CabtSelectionContracts | None = None,
    ) -> CabtInitialDeckResolution:
        if contracts is None:
            contracts = DEFAULT_SELECTION_CONTRACTS
        contracts = _require_selection_contracts(contracts)
        verified = _authority_from_any(authority, contracts)
        if verified is None:
            return _initial_deck_resolution(
                accepted=False,
                selected_card_ids=(),
                owner="none",
                reason_code="invalid_pinned_deck",
                fallback_branch=None,
                deck_hash=None,
                candidate_reason_code="invalid_pinned_deck",
                contracts=contracts,
                authority=authority,
            )
        if (
            type(policy_outcome) is not str
            or policy_outcome not in contracts.policy_outcomes
        ):
            policy_outcome = "unavailable"
        candidate_reason = _initial_candidate_reason(
            candidate,
            policy_outcome,
            verified,
        )
        if candidate_reason == "pinned_deck_accepted":
            return _initial_deck_resolution(
                accepted=True,
                selected_card_ids=tuple(candidate),
                owner="initial_candidate",
                reason_code="pinned_deck_accepted",
                fallback_branch=None,
                deck_hash=verified.deck_hash,
                candidate_reason_code=candidate_reason,
                contracts=contracts,
                authority=authority,
            )
        return _initial_deck_resolution(
            accepted=True,
            selected_card_ids=verified.card_ids,
            owner="pinned_deck_fallback",
            reason_code="pinned_deck_fallback",
            fallback_branch="pinned_verified_deck",
            deck_hash=verified.deck_hash,
            candidate_reason_code=candidate_reason,
            contracts=contracts,
            authority=authority,
        )

    validate = resolve


def build_pinned_deck(
    card_ids: Any = _UNSET,
    *,
    deck_hash: Any = _UNSET,
    source_artifact_id: Any = _UNSET,
    source_sha256: Any = _UNSET,
    authority_scope: Any = _UNSET,
    contracts: CabtSelectionContracts | None = None,
) -> CabtPinnedDeckBuildResult:
    return CabtDeckSelectionValidator.build_pinned_deck(
        card_ids,
        deck_hash=deck_hash,
        source_artifact_id=source_artifact_id,
        source_sha256=source_sha256,
        authority_scope=authority_scope,
        contracts=contracts,
    )


def build_pinned_deck_authority(
    card_ids: Any = _UNSET,
    *,
    deck_hash: Any = _UNSET,
    source_artifact_id: Any = _UNSET,
    source_sha256: Any = _UNSET,
    authority_scope: Any = _UNSET,
    contracts: CabtSelectionContracts | None = None,
) -> CabtPinnedDeckAuthority | None:
    return CabtDeckSelectionValidator.build_pinned_deck_authority(
        card_ids,
        deck_hash=deck_hash,
        source_artifact_id=source_artifact_id,
        source_sha256=source_sha256,
        authority_scope=authority_scope,
        contracts=contracts,
    )


def build_marnie_conformance_authority(
    *,
    contracts: CabtSelectionContracts | None = None,
) -> CabtPinnedDeckAuthority:
    return CabtDeckSelectionValidator.build_marnie_conformance_authority(
        contracts=contracts,
    )


def validate_initial_deck(
    candidate: Any,
    pinned_card_ids: Any,
    pinned_deck_hash: Any = _UNSET,
    policy_outcome: Any = "returned",
    *,
    contracts: CabtSelectionContracts | None = None,
) -> CabtInitialDeckResolution:
    build_result = CabtDeckSelectionValidator.build_pinned_deck(
        pinned_card_ids,
        deck_hash=pinned_deck_hash,
        contracts=contracts,
    )
    return CabtDeckSelectionValidator.resolve(
        build_result.pinned_deck,
        candidate,
        policy_outcome=policy_outcome,
        contracts=contracts,
    )


__all__ = [
    "CabtDeckSelectionValidator",
    "CabtDeterministicFallback",
    "CabtInitialDeckResolution",
    "CabtPinnedDeckBuildResult",
    "CabtPinnedDeckAuthority",
    "CabtSelectionBuildResult",
    "CabtSelectionContracts",
    "CabtSelectionIssue",
    "CabtSelectionResolution",
    "CabtSelectionSanitizer",
    "CabtSelectionValidation",
    "CabtSelectionWindow",
    "DEFAULT_SELECTION_CONTRACTS",
    "build_cabt_selection_window",
    "build_marnie_conformance_authority",
    "build_pinned_deck",
    "build_pinned_deck_authority",
    "deterministic_fallback",
    "initial_deck_hash",
    "resolve_selection",
    "sanitize_selection",
    "validate_initial_deck",
]
