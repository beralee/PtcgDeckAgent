"""Strict, offline-only access to the P5-WP1 Marnie vertical-slice fixtures.

The serialized results exposed here are audit/conformance data.  They do not
grant execution authority and this module has no engine, Host, policy, replay,
or live-owner dependency.
"""

from __future__ import annotations

from copy import deepcopy
from pathlib import Path
import re
from types import MappingProxyType
from typing import Any, Mapping

from .source_lock import (
    canonical_json_v1_bytes,
    load_json_bytes_strict,
    sha256_bytes,
)


_MAX_JSON_BYTES = 2 * 1024 * 1024
_SHA256_RE = re.compile(r"^[0-9A-F]{64}$")
_EXPECTED_BUNDLE_CANONICAL_SHA256 = (
    "7E0CF80D7B2872C29F69BA15548857F1F32407943371D3C12A266A0E471EC425"
)
_EXPECTED_RUNTIME_INTEGRITY_SHA256 = (
    "B0559C5A404EB22058E4A21C28F17F4ADFEB8BA4B894A1FCBBA3DFACF65FCDE0"
)
_EXPECTED_ARTIFACTS = (
    ("marnie_vertical_slice.schema", "contracts/ptcgdap/marnie_vertical_slice.schema.json"),
    ("marnie_vertical_slice_profile", "contracts/ptcgdap/marnie_vertical_slice_profile.json"),
    ("marnie_vertical_slice_source_manifest", "contracts/ptcgdap/marnie_vertical_slice_source_manifest.json"),
    ("marnie_vertical_slice_conformance_vectors", "contracts/ptcgdap/marnie_vertical_slice_conformance_vectors.json"),
    ("official_deck_manifest_v1", "data/ptcgdap/marnie_vertical_slice/official_deck_manifest_v1.json"),
    ("local_deck_manifest_v1", "data/ptcgdap/marnie_vertical_slice/local_deck_manifest_v1.json"),
    ("deck_identity_diff_v1", "data/ptcgdap/marnie_vertical_slice/deck_identity_diff_v1.json"),
    ("capability_inventory_v1", "data/ptcgdap/marnie_vertical_slice/capability_inventory_v1.json"),
    ("w0_w7_public_trajectory_v1", "data/ptcgdap/marnie_vertical_slice/w0_w7_public_trajectory_v1.json"),
)
_KEY_BY_ARTIFACT_ID = {
    "marnie_vertical_slice.schema": "schema",
    "marnie_vertical_slice_profile": "profile",
    "marnie_vertical_slice_source_manifest": "source_manifest",
    "marnie_vertical_slice_conformance_vectors": "vectors",
    "official_deck_manifest_v1": "official_deck",
    "local_deck_manifest_v1": "local_deck",
    "deck_identity_diff_v1": "deck_diff",
    "capability_inventory_v1": "capabilities",
    "w0_w7_public_trajectory_v1": "trajectory",
}


class MarnieVerticalSliceError(RuntimeError):
    """Stable fail-closed error whose string form never echoes input data."""

    def __init__(self, code: str) -> None:
        self.code = code
        super().__init__(code)


def _freeze(value: Any) -> Any:
    if type(value) is dict:
        return MappingProxyType({key: _freeze(child) for key, child in value.items()})
    if type(value) is list:
        return tuple(_freeze(child) for child in value)
    return value


def _thaw(value: Any) -> Any:
    if isinstance(value, Mapping):
        return {key: _thaw(child) for key, child in value.items()}
    if type(value) is tuple:
        return [_thaw(child) for child in value]
    return value


def _read_json_once(path: Path) -> tuple[Any, bytes]:
    try:
        data = path.read_bytes()
    except OSError as exc:
        raise MarnieVerticalSliceError("fixture_file_missing") from exc
    if len(data) > _MAX_JSON_BYTES:
        raise MarnieVerticalSliceError("fixture_file_too_large")
    try:
        return load_json_bytes_strict(data), data
    except (UnicodeError, ValueError) as exc:
        raise MarnieVerticalSliceError("fixture_json_invalid") from exc


def _contained_path(root: Path, relative: str) -> Path:
    if type(relative) is not str or not relative or "\\" in relative:
        raise MarnieVerticalSliceError("fixture_path_invalid")
    candidate = (root / relative).resolve()
    try:
        candidate.relative_to(root.resolve())
    except (OSError, ValueError) as exc:
        raise MarnieVerticalSliceError("fixture_path_invalid") from exc
    return candidate


def _runtime_integrity_digest(documents: Mapping[str, Any]) -> str:
    payload = {
        "bundle": _thaw(documents["bundle"]),
        "schema": _thaw(documents["schema"]),
        "profile": _thaw(documents["profile"]),
        "source_manifest": _thaw(documents["source_manifest"]),
        "vectors": _thaw(documents["vectors"]),
        "official_deck": _thaw(documents["official_deck"]),
        "local_deck": _thaw(documents["local_deck"]),
        "deck_diff": _thaw(documents["deck_diff"]),
        "capabilities": _thaw(documents["capabilities"]),
        "trajectory": _thaw(documents["trajectory"]),
    }
    return sha256_bytes(canonical_json_v1_bytes(payload))


class MarnieVerticalSlice:
    """Immutable-by-interface, bundle-bound P5-WP1 fixture catalog."""

    __slots__ = (
        "_bundle",
        "_schema",
        "_profile",
        "_source_manifest",
        "_vectors",
        "_official_deck",
        "_local_deck",
        "_deck_diff",
        "_capabilities",
        "_trajectory",
        "_runtime_integrity_sha256",
    )

    def __init__(self, *_: Any, **__: Any) -> None:
        raise MarnieVerticalSliceError("direct_construction_forbidden")

    @classmethod
    def _from_documents(cls, documents: Mapping[str, Any]) -> "MarnieVerticalSlice":
        frozen = {key: _freeze(value) for key, value in documents.items()}
        digest = _runtime_integrity_digest(frozen)
        if digest != _EXPECTED_RUNTIME_INTEGRITY_SHA256:
            raise MarnieVerticalSliceError("fixture_integrity_invalid")
        instance = object.__new__(cls)
        for key, value in frozen.items():
            object.__setattr__(instance, f"_{key}", value)
        object.__setattr__(instance, "_runtime_integrity_sha256", digest)
        return instance

    @classmethod
    def load_default(cls) -> "MarnieVerticalSlice":
        return cls.load_trusted_bundle(Path(__file__).resolve().parents[3])

    @classmethod
    def load_trusted_bundle(cls, repository_root: Path) -> "MarnieVerticalSlice":
        root = Path(repository_root).resolve()
        bundle_path = _contained_path(
            root, "contracts/ptcgdap/marnie_vertical_slice_bundle.json"
        )
        bundle, _ = _read_json_once(bundle_path)
        if type(bundle) is not dict:
            raise MarnieVerticalSliceError("fixture_bundle_invalid")
        try:
            bundle_hash = sha256_bytes(canonical_json_v1_bytes(bundle))
        except ValueError as exc:
            raise MarnieVerticalSliceError("fixture_bundle_invalid") from exc
        if bundle_hash != _EXPECTED_BUNDLE_CANONICAL_SHA256:
            raise MarnieVerticalSliceError("fixture_bundle_trust_anchor_mismatch")
        if (
            bundle.get("bundle_id") != "ptcgdap-marnie-vertical-slice-p5-wp1-v1"
            or bundle.get("status") != "offline_shadow_fixture"
            or type(bundle.get("artifacts")) is not list
            or len(bundle["artifacts"]) != len(_EXPECTED_ARTIFACTS)
        ):
            raise MarnieVerticalSliceError("fixture_bundle_invalid")

        documents: dict[str, Any] = {"bundle": bundle}
        seen_paths: set[str] = set()
        for index, expected in enumerate(_EXPECTED_ARTIFACTS):
            entry = bundle["artifacts"][index]
            if type(entry) is not dict or set(entry) != {"id", "path", "canonical_sha256"}:
                raise MarnieVerticalSliceError("fixture_bundle_invalid")
            if (entry.get("id"), entry.get("path")) != expected:
                raise MarnieVerticalSliceError("fixture_bundle_invalid")
            expected_hash = entry.get("canonical_sha256")
            if type(expected_hash) is not str or _SHA256_RE.fullmatch(expected_hash) is None:
                raise MarnieVerticalSliceError("fixture_bundle_invalid")
            relative = entry["path"]
            if relative in seen_paths:
                raise MarnieVerticalSliceError("fixture_bundle_invalid")
            seen_paths.add(relative)
            document, _ = _read_json_once(_contained_path(root, relative))
            try:
                actual_hash = sha256_bytes(canonical_json_v1_bytes(document))
            except ValueError as exc:
                raise MarnieVerticalSliceError("fixture_artifact_invalid") from exc
            if actual_hash != expected_hash:
                raise MarnieVerticalSliceError("fixture_artifact_hash_mismatch")
            documents[_KEY_BY_ARTIFACT_ID[entry["id"]]] = document

        return cls._from_documents(documents)

    def _documents(self) -> dict[str, Any]:
        return {
            "bundle": self._bundle,
            "schema": self._schema,
            "profile": self._profile,
            "source_manifest": self._source_manifest,
            "vectors": self._vectors,
            "official_deck": self._official_deck,
            "local_deck": self._local_deck,
            "deck_diff": self._deck_diff,
            "capabilities": self._capabilities,
            "trajectory": self._trajectory,
        }

    def _integrity_valid(self) -> bool:
        try:
            actual = _runtime_integrity_digest(self._documents())
            return (
                type(self._runtime_integrity_sha256) is str
                and self._runtime_integrity_sha256 == _EXPECTED_RUNTIME_INTEGRITY_SHA256
                and actual == _EXPECTED_RUNTIME_INTEGRITY_SHA256
            )
        except Exception:
            return False

    def _require_integrity(self) -> None:
        if not self._integrity_valid():
            raise MarnieVerticalSliceError("fixture_integrity_invalid")

    @staticmethod
    def _result(value: Any = None, error_code: str = "") -> dict[str, Any]:
        return {
            "ok": error_code == "",
            "error_code": error_code,
            "value": deepcopy(value) if error_code == "" else None,
        }

    def frame(self, frame_id: str) -> dict[str, Any]:
        self._require_integrity()
        if type(frame_id) is not str:
            raise MarnieVerticalSliceError("input_type_invalid")
        for frame in self._trajectory["frames"]:
            if frame["frame_id"] == frame_id:
                return _thaw(frame)
        raise MarnieVerticalSliceError("frame_unknown")

    def bundle_hash(self) -> str:
        self._require_integrity()
        return _EXPECTED_BUNDLE_CANONICAL_SHA256

    def audit_snapshot(self) -> dict[str, Any]:
        self._require_integrity()
        return {
            "bundle_canonical_sha256": _EXPECTED_BUNDLE_CANONICAL_SHA256,
            "artifact_count": len(_EXPECTED_ARTIFACTS),
            "frame_count": len(self._trajectory["frames"]),
            "capability_count": len(self._capabilities["capabilities"]),
            "execution_authority": False,
            "live_consumer": False,
        }

    def run(self, operation: str, input_value: object) -> dict[str, Any]:
        if not self._integrity_valid():
            return self._result(error_code="fixture_integrity_invalid")
        if type(operation) is not str or type(input_value) is not dict:
            return self._result(error_code="input_type_invalid")
        if operation in {"official_summary", "local_summary", "identity_summary"}:
            if input_value:
                return self._result(error_code="input_type_invalid")
            if operation == "official_summary":
                return self._result(
                    {
                        "card_count": self._official_deck["card_count"],
                        "unique_card_id_count": self._official_deck["unique_card_id_count"],
                        "cabt_exportable": self._official_deck["cabt_exportable"],
                    }
                )
            if operation == "local_summary":
                return self._result(
                    {
                        "card_count": self._local_deck["card_count"],
                        "unique_printing_count": self._local_deck["unique_printing_count"],
                        "cabt_exportable": self._local_deck["cabt_exportable"],
                    }
                )
            return self._result(
                {
                    "same_deck": self._deck_diff["same_deck"],
                    "official_bridged": self._deck_diff["official"]["bridged_card_count"],
                    "official_unmapped": self._deck_diff["official"]["unmapped_card_count"],
                    "local_bridged": self._deck_diff["local"]["bridged_card_count"],
                    "local_unbridged": self._deck_diff["local"]["unbridged_card_count"],
                }
            )
        if operation == "frame_summary":
            if set(input_value) != {"frame_id"} or type(input_value["frame_id"]) is not str:
                return self._result(error_code="input_type_invalid")
            try:
                frame = self.frame(input_value["frame_id"])
            except MarnieVerticalSliceError as exc:
                return self._result(error_code=exc.code)
            return self._result(
                {
                    "family": frame["window_family"],
                    "firewall_status": frame["current_firewall"]["status"],
                    "issue_code": frame["current_firewall"]["issue_code"],
                    "window_state": None if frame["window"] is None else frame["window"]["decision_state"],
                }
            )
        if operation == "capability":
            if set(input_value) != {"capability_id"} or type(input_value["capability_id"]) is not str:
                return self._result(error_code="input_type_invalid")
            for capability in self._capabilities["capabilities"]:
                if capability["capability_id"] == input_value["capability_id"]:
                    return self._result(
                        {
                            "window_family": capability["window_family"],
                            "portable_ready": capability["portable_ready"],
                        }
                    )
            return self._result(error_code="capability_unknown")
        return self._result(error_code="operation_unknown")


def load_default() -> MarnieVerticalSlice:
    return MarnieVerticalSlice.load_default()
