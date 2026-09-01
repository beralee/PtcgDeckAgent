from __future__ import annotations

import copy
import hashlib
from pathlib import Path
from typing import Any

from .cabt_tree_hash import CabtTreeHashError, CabtTreeHashLimits, jcs_canonical_json_bytes
from .public_observation_firewall import PublicFirewallError, PublicFirewallResult
from .source_lock import canonical_json_v1_bytes, load_json_bytes_strict, sha256_bytes


SCHEMA_VERSION = 1
PROFILE_ID = "cabt_public_log_cursor_profile_v1"
EXPECTED_CURSOR_BUNDLE_SHA256 = "ED246F029531AA8F21956A64D70F557F1BBC90450A6F9109C5286261E290319D"
EXPECTED_PROFILE_SHA256 = "20B9B9744B152D74D53BBE5EA3005110B36D86D0D9B13FBF09A7C27AB24C21A5"
EXPECTED_FIREWALL_BUNDLE_SHA256 = "A2781CE6B3AC7BB6BAD04A9F15F57CE23AEC338306F60E5B3050B31245685947"
EXPECTED_P1_CONTRACT_SHA256 = "2CD02F54538985426EFDB057F3A6BDA4AD154DD171BCC03667D42D102982D294"
EXPECTED_BUNDLE_ID = "ptcgdap-public-log-cursor-p2-wp4-v1"
WITNESS_PREFIX = b"PTCGDAP\0CABT_PUBLIC_LOG_SLICE_V1\0"
MAX_CONTRACT_BYTES = 2 * 1024 * 1024
MAX_SAFE_INTEGER = 9_007_199_254_740_991
_EXPECTED_ARTIFACTS = {
    "cabt_public_log_cursor_schema_v1": "contracts/ptcgdap/cabt_public_log_cursor.schema.json",
    PROFILE_ID: "contracts/ptcgdap/cabt_public_log_cursor_profile.json",
    "cabt_public_log_cursor_conformance_v1": "contracts/ptcgdap/cabt_public_log_cursor_conformance_vectors.json",
}
_ERROR_CODES = frozenset(
    {
        "invalid_firewall_result",
        "firewall_result_not_accepted",
        "cursor_contract_error",
        "pending_selection_uncommitted",
        "invalid_slice_result",
        "slice_not_pending",
        "slice_cursor_mismatch",
        "slice_generation_stale",
        "slice_integrity_invalid",
        "source_result_replayed",
        "public_log_limit",
        "witness_error",
    }
)
_CONSTRUCTION_TOKEN = object()


class PublicLogCursorError(ValueError):
    def __init__(self, code: str) -> None:
        self.code = code
        super().__init__(code)


def _canonical_hash(value: Any) -> str:
    return sha256_bytes(canonical_json_v1_bytes(value))


def _read_contract(path: Path) -> Any:
    try:
        data = path.read_bytes()
        if len(data) > MAX_CONTRACT_BYTES:
            raise PublicLogCursorError("cursor_contract_error")
        return load_json_bytes_strict(data)
    except PublicLogCursorError:
        raise
    except (OSError, UnicodeError, ValueError, TypeError, RecursionError) as exc:
        raise PublicLogCursorError("cursor_contract_error") from exc


def _is_sha(value: object) -> bool:
    return type(value) is str and len(value) == 64 and all(character in "0123456789ABCDEF" for character in value)


def _issue(code: str) -> dict[str, str]:
    if code not in _ERROR_CODES:
        code = "cursor_contract_error"
    return {"code": code, "severity": "error"}


def public_log_slice_witness(payload: object) -> tuple[bytes, str]:
    if type(payload) is not dict or set(payload) != {
        "ordinal",
        "previous_witness",
        "source_public_observation_hash",
        "logs",
    }:
        raise PublicLogCursorError("witness_error")
    ordinal = payload.get("ordinal")
    previous = payload.get("previous_witness")
    source_hash = payload.get("source_public_observation_hash")
    logs = payload.get("logs")
    if type(ordinal) is not int or ordinal < 0 or ordinal > MAX_SAFE_INTEGER:
        raise PublicLogCursorError("witness_error")
    if previous is not None and not _is_sha(previous):
        raise PublicLogCursorError("witness_error")
    if not _is_sha(source_hash) or type(logs) is not list:
        raise PublicLogCursorError("witness_error")
    try:
        canonical = jcs_canonical_json_bytes(payload)
    except (CabtTreeHashError, TypeError, ValueError, RecursionError) as exc:
        raise PublicLogCursorError("witness_error") from exc
    return canonical, hashlib.sha256(WITNESS_PREFIX + canonical).hexdigest().upper()


class _CursorContracts:
    __slots__ = ("_profile", "_root", "_seal")

    def __init__(self, token: object, profile: dict[str, Any], root: Path) -> None:
        if token is not _CONSTRUCTION_TOKEN:
            raise PublicLogCursorError("cursor_contract_error")
        self._profile = copy.deepcopy(profile)
        self._root = root.resolve()
        self._seal = EXPECTED_CURSOR_BUNDLE_SHA256

    @property
    def limits(self) -> dict[str, int]:
        return copy.deepcopy(self._profile["limits"])

    def integrity_valid(self) -> bool:
        try:
            return (
                type(self._profile) is dict
                and isinstance(self._root, Path)
                and self._seal == EXPECTED_CURSOR_BUNDLE_SHA256
                and self._profile.get("profile_id") == PROFILE_ID
                and _canonical_hash(self._profile) == EXPECTED_PROFILE_SHA256
                and self._profile.get("parent_firewall", {}).get("canonical_sha256")
                == EXPECTED_FIREWALL_BUNDLE_SHA256
                and self._profile.get("result_contract", {}).get("error_codes")
                == list(_profile_error_codes())
            )
        except Exception:
            return False


def _profile_error_codes() -> tuple[str, ...]:
    return (
        "invalid_firewall_result",
        "firewall_result_not_accepted",
        "cursor_contract_error",
        "pending_selection_uncommitted",
        "invalid_slice_result",
        "slice_not_pending",
        "slice_cursor_mismatch",
        "slice_generation_stale",
        "slice_integrity_invalid",
        "source_result_replayed",
        "public_log_limit",
        "witness_error",
    )


def _load_contracts(root: Path) -> _CursorContracts:
    root = root.resolve()
    try:
        bundle = _read_contract(root / "cabt_public_log_cursor_bundle.json")
        if type(bundle) is not dict or _canonical_hash(bundle) != EXPECTED_CURSOR_BUNDLE_SHA256:
            raise PublicLogCursorError("cursor_contract_error")
        if bundle.get("bundle_id") != EXPECTED_BUNDLE_ID:
            raise PublicLogCursorError("cursor_contract_error")
        if bundle.get("parent_firewall_bundle") != {
            "id": "ptcgdap-public-firewall-p2-wp3-v1",
            "canonical_sha256": EXPECTED_FIREWALL_BUNDLE_SHA256,
        }:
            raise PublicLogCursorError("cursor_contract_error")
        if bundle.get("p1_contract_canonical_sha256") != EXPECTED_P1_CONTRACT_SHA256:
            raise PublicLogCursorError("cursor_contract_error")
        if _canonical_hash(_read_contract(root / "cabt_public_firewall_bundle.json")) != EXPECTED_FIREWALL_BUNDLE_SHA256:
            raise PublicLogCursorError("cursor_contract_error")
        artifacts = bundle.get("artifacts")
        if type(artifacts) is not list or len(artifacts) != len(_EXPECTED_ARTIFACTS):
            raise PublicLogCursorError("cursor_contract_error")
        loaded: dict[str, Any] = {}
        paths: set[str] = set()
        for entry in artifacts:
            if type(entry) is not dict or set(entry) != {"id", "path", "canonical_sha256"}:
                raise PublicLogCursorError("cursor_contract_error")
            artifact_id = entry.get("id")
            relative_path = entry.get("path")
            if type(artifact_id) is not str or type(relative_path) is not str:
                raise PublicLogCursorError("cursor_contract_error")
            if _EXPECTED_ARTIFACTS.get(artifact_id) != relative_path or relative_path in paths:
                raise PublicLogCursorError("cursor_contract_error")
            paths.add(relative_path)
            value = _read_contract(root / Path(relative_path).name)
            if not _is_sha(entry.get("canonical_sha256")) or _canonical_hash(value) != entry["canonical_sha256"]:
                raise PublicLogCursorError("cursor_contract_error")
            loaded[artifact_id] = value
        if set(loaded) != set(_EXPECTED_ARTIFACTS):
            raise PublicLogCursorError("cursor_contract_error")
        profile = loaded.get(PROFILE_ID)
        if type(profile) is not dict or _canonical_hash(profile) != EXPECTED_PROFILE_SHA256:
            raise PublicLogCursorError("cursor_contract_error")
        return _CursorContracts(_CONSTRUCTION_TOKEN, profile, root)
    except PublicLogCursorError:
        raise
    except (OSError, KeyError, TypeError, ValueError, RecursionError) as exc:
        raise PublicLogCursorError("cursor_contract_error") from exc


class PublicLogCursorResult:
    __slots__ = (
        "_owner",
        "_source_result",
        "_generation",
        "_status",
        "_ordinal",
        "_previous_witness",
        "_source_public_observation_hash",
        "_logs",
        "_witness_hash",
        "_issues",
        "_snapshot",
    )

    def __init__(self, token: object, owner: PublicLogCursor, source_result: object, generation: int, evaluation: dict[str, Any]) -> None:
        if token is not _CONSTRUCTION_TOKEN:
            raise PublicLogCursorError("slice_integrity_invalid")
        self._owner = owner
        self._source_result = source_result
        self._generation = generation
        self._status = evaluation["status"]
        slice_value = evaluation["slice"]
        self._ordinal = slice_value.get("ordinal") if type(slice_value) is dict else None
        self._previous_witness = slice_value.get("previous_witness") if type(slice_value) is dict else None
        self._source_public_observation_hash = slice_value.get("source_public_observation_hash") if type(slice_value) is dict else None
        self._logs = copy.deepcopy(slice_value.get("logs")) if type(slice_value) is dict else None
        self._witness_hash = slice_value.get("witness_hash") if type(slice_value) is dict else None
        self._issues = copy.deepcopy(evaluation["issues"])
        self._snapshot = copy.deepcopy(self._serialize_unchecked())

    @property
    def status(self) -> str:
        return self._status

    @property
    def ready(self) -> bool:
        return self._status == "slice_ready"

    @property
    def ordinal(self) -> int | None:
        return self._ordinal

    @property
    def previous_witness(self) -> str | None:
        return self._previous_witness

    @property
    def source_public_observation_hash(self) -> str | None:
        return self._source_public_observation_hash

    @property
    def logs(self) -> list[dict[str, Any]]:
        return copy.deepcopy(self._logs) if type(self._logs) is list else []

    @property
    def witness_hash(self) -> str | None:
        return self._witness_hash

    @property
    def issues(self) -> list[dict[str, str]]:
        return copy.deepcopy(self._issues)

    @property
    def slice(self) -> dict[str, Any] | None:
        return copy.deepcopy(self._slice_unchecked())

    def _slice_unchecked(self) -> dict[str, Any] | None:
        if self._status != "slice_ready":
            return None
        return {
            "schema_version": SCHEMA_VERSION,
            "profile_id": PROFILE_ID,
            "ordinal": self._ordinal,
            "previous_witness": self._previous_witness,
            "source_public_observation_hash": self._source_public_observation_hash,
            "logs": copy.deepcopy(self._logs),
            "witness_hash": self._witness_hash,
        }

    def _serialize_unchecked(self) -> dict[str, Any]:
        return {"status": self._status, "slice": self._slice_unchecked(), "issues": copy.deepcopy(self._issues)}

    def validate_integrity(self, current_cursor: object) -> bool:
        return type(current_cursor) is PublicLogCursor and current_cursor._validate_result(self)

    def to_public_dict(self) -> dict[str, Any]:
        if not self.validate_integrity(self._owner):
            raise PublicLogCursorError("slice_integrity_invalid")
        return copy.deepcopy(self._snapshot)


class PublicLogCommitResult:
    __slots__ = ("_owner", "_status", "_committed_ordinal", "_witness_hash", "_issues", "_snapshot")

    def __init__(self, token: object, owner: PublicLogCursor, evaluation: dict[str, Any]) -> None:
        if token is not _CONSTRUCTION_TOKEN:
            raise PublicLogCursorError("slice_integrity_invalid")
        self._owner = owner
        self._status = evaluation["status"]
        self._committed_ordinal = evaluation["committed_ordinal"]
        self._witness_hash = evaluation["witness_hash"]
        self._issues = copy.deepcopy(evaluation["issues"])
        self._snapshot = copy.deepcopy(self._serialize_unchecked())

    @property
    def status(self) -> str:
        return self._status

    @property
    def committed_ordinal(self) -> int | None:
        return self._committed_ordinal

    @property
    def witness_hash(self) -> str | None:
        return self._witness_hash

    @property
    def issues(self) -> list[dict[str, str]]:
        return copy.deepcopy(self._issues)

    def _serialize_unchecked(self) -> dict[str, Any]:
        return {"status": self._status, "committed_ordinal": self._committed_ordinal, "witness_hash": self._witness_hash, "issues": copy.deepcopy(self._issues)}

    def validate_integrity(self) -> bool:
        try:
            if type(self._owner) is not PublicLogCursor or type(self._snapshot) is not dict or self._snapshot != self._serialize_unchecked():
                return False
            if self._status == "committed":
                return type(self._committed_ordinal) is int and self._committed_ordinal >= 0 and _is_sha(self._witness_hash) and self._issues == []
            return self._status == "rejected" and self._committed_ordinal is None and self._witness_hash is None and type(self._issues) is list and len(self._issues) == 1 and self._issues[0].get("code") in _ERROR_CODES
        except Exception:
            return False

    def to_public_dict(self) -> dict[str, Any]:
        if not self.validate_integrity():
            raise PublicLogCursorError("slice_integrity_invalid")
        return copy.deepcopy(self._snapshot)


class PublicLogCursor:
    __slots__ = ("_contracts", "_generation", "_ordinal", "_previous_witness", "_pending", "_committed_sources", "_state_snapshot", "_seal")

    def __init__(self, token: object, contracts: _CursorContracts) -> None:
        if token is not _CONSTRUCTION_TOKEN or type(contracts) is not _CursorContracts:
            raise PublicLogCursorError("cursor_contract_error")
        self._contracts = contracts
        self._generation = 0
        self._ordinal = 0
        self._previous_witness: str | None = None
        self._pending: PublicLogCursorResult | None = None
        self._committed_sources: list[PublicFirewallResult] = []
        self._seal = EXPECTED_CURSOR_BUNDLE_SHA256
        self._state_snapshot: tuple[Any, ...] = ()
        self._refresh_state_snapshot()

    @classmethod
    def load_default(cls) -> PublicLogCursor:
        root = Path(__file__).resolve().parents[3] / "contracts" / "ptcgdap"
        return cls.load_from_root(root)

    @classmethod
    def load_from_root(cls, contract_root: str | Path) -> PublicLogCursor:
        if type(contract_root) is not str and not isinstance(contract_root, Path):
            raise PublicLogCursorError("cursor_contract_error")
        return cls(_CONSTRUCTION_TOKEN, _load_contracts(Path(contract_root)))

    @property
    def contract_hash(self) -> str:
        return EXPECTED_CURSOR_BUNDLE_SHA256

    @property
    def ordinal(self) -> int:
        return self._ordinal

    @property
    def previous_witness(self) -> str | None:
        return self._previous_witness

    def _state_tuple(self) -> tuple[Any, ...]:
        return (self._generation, self._ordinal, self._previous_witness, self._pending, tuple(self._committed_sources))

    def _refresh_state_snapshot(self) -> None:
        self._state_snapshot = self._state_tuple()

    def _integrity_valid(self) -> bool:
        try:
            return (
                type(self._contracts) is _CursorContracts
                and self._contracts.integrity_valid()
                and self._seal == EXPECTED_CURSOR_BUNDLE_SHA256
                and type(self._generation) is int
                and 0 <= self._generation <= MAX_SAFE_INTEGER
                and type(self._ordinal) is int
                and 0 <= self._ordinal <= MAX_SAFE_INTEGER
                and (self._previous_witness is None or _is_sha(self._previous_witness))
                and (self._pending is None or type(self._pending) is PublicLogCursorResult)
                and type(self._committed_sources) is list
                and all(type(source) is PublicFirewallResult for source in self._committed_sources)
                and type(self._state_snapshot) is tuple
                and self._state_snapshot == self._state_tuple()
            )
        except Exception:
            return False

    def _rejected(self, code: str, source_result: object = None) -> PublicLogCursorResult:
        return PublicLogCursorResult(_CONSTRUCTION_TOKEN, self, source_result, self._generation, {"status": "rejected", "slice": None, "issues": [_issue(code)]})

    def _commit_rejected(self, code: str) -> PublicLogCommitResult:
        return PublicLogCommitResult(_CONSTRUCTION_TOKEN, self, {"status": "rejected", "committed_ordinal": None, "witness_hash": None, "issues": [_issue(code)]})

    def _source_snapshot(self, source_result: object) -> dict[str, Any] | None:
        if type(source_result) is not PublicFirewallResult:
            return None
        try:
            value = source_result.to_public_dict()
        except (PublicFirewallError, AttributeError, TypeError, ValueError, RecursionError):
            return None
        return value if type(value) is dict else None

    def peek(self, source_result: object) -> PublicLogCursorResult:
        if not self._integrity_valid():
            return self._rejected("cursor_contract_error")
        source_snapshot = self._source_snapshot(source_result)
        if source_snapshot is None:
            return self._rejected("invalid_firewall_result")
        if source_snapshot.get("status") != "accepted":
            return self._rejected("firewall_result_not_accepted")
        if self._pending is not None:
            if self._pending._source_result is source_result and self._pending.validate_integrity(self):
                return self._pending
            return self._rejected("pending_selection_uncommitted")
        if any(source is source_result for source in self._committed_sources):
            return self._rejected("source_result_replayed")
        public_observation = source_snapshot.get("public_observation")
        source_hash = source_snapshot.get("public_observation_hash")
        if type(public_observation) is not dict or not _is_sha(source_hash):
            return self._rejected("invalid_firewall_result")
        logs = public_observation.get("logs")
        if type(logs) is not list:
            return self._rejected("invalid_firewall_result")
        limits = self._contracts.limits
        if len(logs) > limits["max_logs_per_slice"]:
            return self._rejected("public_log_limit")
        try:
            jcs_canonical_json_bytes(
                logs,
                limits=CabtTreeHashLimits(
                    max_depth=limits["max_log_tree_depth"],
                    max_nodes=limits["max_log_tree_nodes"],
                ),
            )
            payload = {
                "ordinal": self._ordinal,
                "previous_witness": self._previous_witness,
                "source_public_observation_hash": source_hash,
                "logs": copy.deepcopy(logs),
            }
            _, witness = public_log_slice_witness(payload)
        except (CabtTreeHashError, PublicLogCursorError, KeyError, TypeError, ValueError, RecursionError):
            return self._rejected("public_log_limit")
        slice_value = {
            "schema_version": SCHEMA_VERSION,
            "profile_id": PROFILE_ID,
            **payload,
            "witness_hash": witness,
        }
        result = PublicLogCursorResult(_CONSTRUCTION_TOKEN, self, source_result, self._generation, {"status": "slice_ready", "slice": slice_value, "issues": []})
        self._pending = result
        self._refresh_state_snapshot()
        return result

    def _validate_result(self, result: object) -> bool:
        try:
            if not self._integrity_valid() or type(result) is not PublicLogCursorResult or result._owner is not self:
                return False
            if type(result._snapshot) is not dict or result._snapshot != result._serialize_unchecked():
                return False
            if result._status == "rejected":
                return result._slice_unchecked() is None and type(result._issues) is list and len(result._issues) == 1 and result._issues[0].get("code") in _ERROR_CODES
            if result._status != "slice_ready" or result._issues != [] or result._generation != self._generation or self._pending is not result:
                return False
            if result._ordinal != self._ordinal or result._previous_witness != self._previous_witness:
                return False
            source_snapshot = self._source_snapshot(result._source_result)
            if source_snapshot is None or source_snapshot.get("status") != "accepted":
                return False
            public_observation = source_snapshot.get("public_observation")
            if type(public_observation) is not dict:
                return False
            if source_snapshot.get("public_observation_hash") != result._source_public_observation_hash or public_observation.get("logs") != result._logs:
                return False
            payload = {
                "ordinal": result._ordinal,
                "previous_witness": result._previous_witness,
                "source_public_observation_hash": result._source_public_observation_hash,
                "logs": copy.deepcopy(result._logs),
            }
            _, witness = public_log_slice_witness(payload)
            return witness == result._witness_hash and result._slice_unchecked() == result._snapshot.get("slice")
        except Exception:
            return False

    def commit(self, result: object) -> PublicLogCommitResult:
        if not self._integrity_valid():
            return self._commit_rejected("cursor_contract_error")
        if type(result) is not PublicLogCursorResult:
            return self._commit_rejected("invalid_slice_result")
        if result._owner is not self:
            return self._commit_rejected("slice_cursor_mismatch")
        if result._generation != self._generation:
            return self._commit_rejected("slice_generation_stale")
        if self._pending is None or self._pending is not result:
            return self._commit_rejected("slice_not_pending")
        if not result.validate_integrity(self):
            return self._commit_rejected("slice_integrity_invalid")
        if self._ordinal >= MAX_SAFE_INTEGER:
            return self._commit_rejected("cursor_contract_error")
        committed_ordinal = result._ordinal
        witness = result._witness_hash
        source_result = result._source_result
        self._pending = None
        self._ordinal += 1
        self._previous_witness = witness
        self._committed_sources.append(source_result)
        self._refresh_state_snapshot()
        return PublicLogCommitResult(_CONSTRUCTION_TOKEN, self, {"status": "committed", "committed_ordinal": committed_ordinal, "witness_hash": witness, "issues": []})

    def reset(self) -> None:
        if not self._integrity_valid() or self._generation >= MAX_SAFE_INTEGER:
            raise PublicLogCursorError("cursor_contract_error")
        self._generation += 1
        self._ordinal = 0
        self._previous_witness = None
        self._pending = None
        self._committed_sources = []
        self._refresh_state_snapshot()
