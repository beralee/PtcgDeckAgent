from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any, Final

from .source_lock import (
    canonical_json_v1_bytes,
    load_json_bytes_strict,
    sha256_bytes,
)


EXPECTED_CONTRACT_ID: Final = "ptcgdap-cabt-contract-p1-wp3-v1"
EXPECTED_CONTRACT_BUNDLE_SHA256: Final = (
    "2CD02F54538985426EFDB057F3A6BDA4AD154DD171BCC03667D42D102982D294"
)
EXPECTED_SOURCE_LOCK_ID: Final = "ptcgdap-source-lock-2026-08-09-p1wp1"
EXPECTED_SOURCE_LOCK_CANONICAL_SHA256: Final = (
    "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"
)
MAX_CONTRACT_BYTES: Final = 2 * 1024 * 1024

_EXPECTED_ARTIFACTS: Final = (
    (
        "raw_envelope_schema",
        "contracts/ptcgdap/raw_cabt_envelope.schema.json",
        "4BE60E82DC766A31D14B0823AEB462E3117C8652DC13EC649D5BF5219BA869F8",
    ),
    (
        "tree_hash_profile",
        "contracts/ptcgdap/cabt_tree_hash_profile.json",
        "93FB67638244843CCDCB6954A15385F27FA468438E5B6DBA5629A2AF345EE6F0",
    ),
    (
        "enum_snapshot",
        "contracts/ptcgdap/cabt_enum_snapshot.json",
        "67C13F67B533C1E3F4AC91A65608487FC4A41DE291FD8F2CF0EFCD475E4628A0",
    ),
    (
        "option_sparse_shapes",
        "contracts/ptcgdap/cabt_option_sparse_shapes.json",
        "F9D85B3D2E1EA0CFF7B023F0C366EFE1FB8DA00A2B85D40F26A6B7DFBF4B062D",
    ),
    (
        "typed_view_profile",
        "contracts/ptcgdap/cabt_typed_view_profile.json",
        "8BF305D68247111DB7C94908012AEF57636566E8246474FF0395EA25FDD89548",
    ),
    (
        "tree_hash_conformance_vectors",
        "contracts/ptcgdap/cabt_tree_hash_conformance_vectors.json",
        "2FA2313FE227CEF98F0813E0ED509EC1BB2E8D71DF9A29B019DF3C0802508CA6",
    ),
    (
        "selection_window_schema",
        "contracts/ptcgdap/cabt_selection_window.schema.json",
        "5F2F2E3889F6D47587A6386672E34D45EB3531E1DB4DE9D2BFA25F677AD44453",
    ),
    (
        "selection_profile",
        "contracts/ptcgdap/cabt_selection_profile.json",
        "8F2133706BC33FC0125109E47835D6A06A6CC21FD5E4B324AD284FAF1D03F460",
    ),
    (
        "selection_conformance_vectors",
        "contracts/ptcgdap/cabt_selection_conformance_vectors.json",
        "7467A7BCC32CAEECBCF1234DFB2E1A0497A37088765D51AB4D223E2D3773EE4E",
    ),
)
_SOURCE_LOCKED_DOCUMENT_IDS: Final = frozenset(
    {
        "enum_snapshot",
        "option_sparse_shapes",
        "typed_view_profile",
        "selection_profile",
        "selection_conformance_vectors",
    }
)
_BUNDLE_KEYS: Final = frozenset(
    {
        "schema_version",
        "contract_id",
        "status",
        "parent_contract",
        "digest_mode",
        "artifact_set_policy",
        "source_lock_id",
        "source_lock_canonical_sha256",
        "artifacts",
    }
)
_ARTIFACT_ENTRY_KEYS: Final = frozenset({"id", "path", "canonical_sha256"})
_CONSTRUCTION_TOKEN: Final = object()


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
            raise ValueError("contract objects require exact string keys")
        return _FrozenObject(
            tuple((key, _freeze_json(child)) for key, child in value.items())
        )
    raise ValueError("contract document contains a non-canonical JSON value")


def _thaw_json(value: Any) -> Any:
    if type(value) is _FrozenArray:
        return [_thaw_json(child) for child in value.items]
    if type(value) is _FrozenObject:
        return {key: _thaw_json(child) for key, child in value.items}
    return value


def _is_upper_sha256(value: Any) -> bool:
    return (
        type(value) is str
        and len(value) == 64
        and all(character in "0123456789ABCDEF" for character in value)
    )


def _load_bounded_contract_json(path: Path) -> tuple[bytes, Any]:
    with path.open("rb") as stream:
        source_bytes = stream.read(MAX_CONTRACT_BYTES + 1)
    if not source_bytes or len(source_bytes) > MAX_CONTRACT_BYTES:
        raise ValueError("contract JSON byte size is outside the locked limit")
    return source_bytes, load_json_bytes_strict(source_bytes)


@dataclass(frozen=True, slots=True, init=False)
class CabtContractSet:
    """Immutable snapshot proven against the current external bundle trust anchor."""

    contract_id: str
    source_lock_id: str
    source_lock_canonical_sha256: str
    source_contract_hash: str
    _artifact_hashes: tuple[tuple[str, str], ...]
    _documents: tuple[tuple[str, _FrozenObject], ...]
    _construction_seal: object

    def __new__(cls) -> CabtContractSet:
        raise TypeError("CabtContractSet instances must be created by load_contract_set()")

    @classmethod
    def _from_verified(
        cls,
        *,
        construction_token: object,
        source_contract_hash: str,
        artifact_hashes: tuple[tuple[str, str], ...],
        documents: tuple[tuple[str, _FrozenObject], ...],
    ) -> CabtContractSet:
        if construction_token is not _CONSTRUCTION_TOKEN:
            raise TypeError("CabtContractSet construction is loader-owned")
        result = object.__new__(cls)
        values = {
            "contract_id": EXPECTED_CONTRACT_ID,
            "source_lock_id": EXPECTED_SOURCE_LOCK_ID,
            "source_lock_canonical_sha256": EXPECTED_SOURCE_LOCK_CANONICAL_SHA256,
            "source_contract_hash": source_contract_hash,
            "_artifact_hashes": artifact_hashes,
            "_documents": documents,
            "_construction_seal": _CONSTRUCTION_TOKEN,
        }
        for field_name, value in values.items():
            object.__setattr__(result, field_name, value)
        return result

    @property
    def artifact_ids(self) -> tuple[str, ...]:
        return tuple(artifact_id for artifact_id, _ in self._documents)

    @property
    def artifact_canonical_hashes(self) -> dict[str, str]:
        return dict(self._artifact_hashes)

    @property
    def is_loader_verified(self) -> bool:
        if (
            self._construction_seal is not _CONSTRUCTION_TOKEN
            or self.contract_id != EXPECTED_CONTRACT_ID
            or self.source_lock_id != EXPECTED_SOURCE_LOCK_ID
            or self.source_lock_canonical_sha256
            != EXPECTED_SOURCE_LOCK_CANONICAL_SHA256
            or self.source_contract_hash != EXPECTED_CONTRACT_BUNDLE_SHA256
            or self._artifact_hashes
            != tuple(
                (artifact_id, canonical_hash)
                for artifact_id, _, canonical_hash in _EXPECTED_ARTIFACTS
            )
            or tuple(artifact_id for artifact_id, _ in self._documents)
            != tuple(artifact_id for artifact_id, _, _ in _EXPECTED_ARTIFACTS)
        ):
            return False
        for (_, frozen), (_, _, expected_hash) in zip(
            self._documents,
            _EXPECTED_ARTIFACTS,
        ):
            document = _thaw_json(frozen)
            if type(document) is not dict:
                return False
            try:
                actual_hash = sha256_bytes(canonical_json_v1_bytes(document))
            except (TypeError, ValueError, RuntimeError, RecursionError):
                return False
            if actual_hash != expected_hash:
                return False
        return True

    def document(self, artifact_id: str) -> dict[str, Any]:
        if type(artifact_id) is not str:
            raise TypeError("artifact_id must be an exact string")
        for current_id, frozen in self._documents:
            if current_id == artifact_id:
                result = _thaw_json(frozen)
                if type(result) is not dict:
                    raise RuntimeError("verified contract document is not an object")
                return result
        raise KeyError("unknown contract artifact id")

    @property
    def typed_profile(self) -> dict[str, Any]:
        return self.document("typed_view_profile")

    @property
    def enum_snapshot(self) -> dict[str, Any]:
        return self.document("enum_snapshot")

    @property
    def option_shapes(self) -> dict[str, Any]:
        return self.document("option_sparse_shapes")

    @property
    def selection_profile(self) -> dict[str, Any]:
        return self.document("selection_profile")


def load_contract_set(contract_root: str | Path) -> CabtContractSet:
    root = Path(contract_root).resolve()
    if not root.is_dir():
        raise ValueError("contract root is not a directory")
    bundle_path = root / "cabt_contract_bundle.json"
    bundle_source_bytes, bundle = _load_bounded_contract_json(bundle_path)
    if type(bundle) is not dict or any(type(key) is not str for key in bundle):
        raise ValueError("contract bundle must be an exact string-keyed object")
    bundle_bytes = canonical_json_v1_bytes(bundle)
    bundle_hash = sha256_bytes(bundle_bytes)
    if bundle_hash != EXPECTED_CONTRACT_BUNDLE_SHA256:
        raise ValueError("contract bundle trust-anchor hash mismatch")
    if set(bundle) != _BUNDLE_KEYS:
        raise ValueError("contract bundle fields are not exact")
    if (
        type(bundle["schema_version"]) is not int
        or bundle["schema_version"] != 2
        or type(bundle["contract_id"]) is not str
        or bundle["contract_id"] != EXPECTED_CONTRACT_ID
        or type(bundle["digest_mode"]) is not str
        or bundle["digest_mode"] != "canonical_json_v1"
        or type(bundle["artifact_set_policy"]) is not str
        or bundle["artifact_set_policy"] != "exact_ids_and_paths_no_duplicates"
        or type(bundle["source_lock_id"]) is not str
        or bundle["source_lock_id"] != EXPECTED_SOURCE_LOCK_ID
        or type(bundle["source_lock_canonical_sha256"]) is not str
        or bundle["source_lock_canonical_sha256"]
        != EXPECTED_SOURCE_LOCK_CANONICAL_SHA256
    ):
        raise ValueError("contract bundle identity or source lock is unsupported")
    if not _is_upper_sha256(bundle["source_lock_canonical_sha256"]):
        raise ValueError("contract bundle source-lock hash is invalid")

    entries = bundle["artifacts"]
    if type(entries) is not list or len(entries) != len(_EXPECTED_ARTIFACTS):
        raise ValueError("contract bundle artifact count is not exact")
    expected_by_id = {
        artifact_id: (relative_path, canonical_hash)
        for artifact_id, relative_path, canonical_hash in _EXPECTED_ARTIFACTS
    }
    actual_entries: dict[str, tuple[str, str]] = {}
    seen_paths: set[str] = set()
    for entry in entries:
        if (
            type(entry) is not dict
            or any(type(key) is not str for key in entry)
            or set(entry) != _ARTIFACT_ENTRY_KEYS
        ):
            raise ValueError("contract bundle artifact entry is invalid")
        artifact_id = entry["id"]
        relative_path = entry["path"]
        canonical_hash = entry["canonical_sha256"]
        if (
            type(artifact_id) is not str
            or type(relative_path) is not str
            or type(canonical_hash) is not str
            or artifact_id in actual_entries
            or relative_path in seen_paths
            or expected_by_id.get(artifact_id) != (relative_path, canonical_hash)
            or not _is_upper_sha256(canonical_hash)
        ):
            raise ValueError("contract bundle artifact binding is not exact")
        actual_entries[artifact_id] = (relative_path, canonical_hash)
        seen_paths.add(relative_path)
    if set(actual_entries) != set(expected_by_id):
        raise ValueError("contract bundle artifact ID set is not exact")

    repository_root = root.parents[1]
    documents: list[tuple[str, _FrozenObject]] = []
    artifact_hashes: list[tuple[str, str]] = []
    for artifact_id, relative_path, expected_hash in _EXPECTED_ARTIFACTS:
        document_path = (repository_root / relative_path).resolve()
        try:
            document_path.relative_to(repository_root)
        except ValueError:
            raise ValueError("contract artifact path escapes repository root") from None
        _document_source_bytes, document = _load_bounded_contract_json(document_path)
        if type(document) is not dict:
            raise ValueError("contract artifact must be a JSON object")
        actual_hash = sha256_bytes(canonical_json_v1_bytes(document))
        if actual_hash != expected_hash:
            raise ValueError("contract artifact canonical hash mismatch")
        if artifact_id in _SOURCE_LOCKED_DOCUMENT_IDS:
            if (
                type(document.get("source_lock_id")) is not str
                or document.get("source_lock_id") != EXPECTED_SOURCE_LOCK_ID
            ):
                raise ValueError("contract artifact source lock does not match")
        frozen = _freeze_json(document)
        if type(frozen) is not _FrozenObject:
            raise ValueError("contract artifact root is not an object")
        documents.append((artifact_id, frozen))
        artifact_hashes.append((artifact_id, actual_hash))

    return CabtContractSet._from_verified(
        construction_token=_CONSTRUCTION_TOKEN,
        source_contract_hash=bundle_hash,
        artifact_hashes=tuple(artifact_hashes),
        documents=tuple(documents),
    )


__all__ = [
    "CabtContractSet",
    "EXPECTED_CONTRACT_BUNDLE_SHA256",
    "EXPECTED_CONTRACT_ID",
    "EXPECTED_SOURCE_LOCK_CANONICAL_SHA256",
    "EXPECTED_SOURCE_LOCK_ID",
    "MAX_CONTRACT_BYTES",
    "load_contract_set",
]
