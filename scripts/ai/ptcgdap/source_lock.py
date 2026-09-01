from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from dataclasses import asdict, dataclass, field
from pathlib import Path, PurePosixPath
from typing import Any, Mapping, Sequence


SUPPORTED_SCHEMA_VERSION = 2
REPORT_SCHEMA_VERSION = 1
VERIFIER_VERSION = "ptcgdap-source-lock-verifier-v1"
SUPPORTED_EXTRA_FILE_POLICY = (
    "reject_unlocked_extras_except_reported_pycache_diagnostics"
)
SUPPORTED_HASH_MODE_DESCRIPTIONS = {
    "raw_bytes": "SHA-256 over the exact file byte stream",
    "canonical_json_v1": "SHA-256 over duplicate-key-rejected UTF-8 JSON serialized with Unicode object keys sorted by Python code-point order, no insignificant whitespace or ASCII escaping; values are limited to object/list/string/integer/boolean/null (no floats), with no Unicode normalization",
}
AUXILIARY_HASH_POLICY = (
    "captured_raw_sha256_and_git_blob_lf_sha256_are_diagnostic_only"
)
_SHA256_RE = re.compile(r"^[0-9A-Fa-f]{64}$")
_LOCK_ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")
_CANDIDATE_ARTIFACT_REFERENCE_FIELDS = (
    "official_deck_artifact_id",
    "local_deck_artifact_id",
)
_CANONICAL_JSON_V1_MAX_SAFE_INTEGER = 2**53 - 1


class DuplicateJsonKeyError(ValueError):
    pass


def _safe_report_value(value: Any, *, depth: int = 0) -> Any:
    """Bound untrusted diagnostic values before they reach JSON/text evidence."""
    if value is None or isinstance(value, (bool, int)):
        return value
    if isinstance(value, float):
        return repr(value)
    if isinstance(value, str):
        return value if len(value) <= 1024 else value[:1021] + "..."
    if depth >= 4:
        return f"<{type(value).__name__}:truncated>"
    if isinstance(value, list):
        result = [_safe_report_value(item, depth=depth + 1) for item in value[:32]]
        if len(value) > 32:
            result.append(f"<{len(value) - 32} more items>")
        return result
    if isinstance(value, dict):
        result: dict[str, Any] = {}
        for index, (key, child) in enumerate(value.items()):
            if index >= 32:
                result["<truncated>"] = f"{len(value) - 32} more entries"
                break
            result[str(key)[:256]] = _safe_report_value(child, depth=depth + 1)
        return result
    return f"<{type(value).__name__}>"


@dataclass(frozen=True)
class VerificationIssue:
    code: str
    subject: str
    detail: str
    expected: Any = None
    actual: Any = None


@dataclass(frozen=True)
class ArtifactVerificationStatus:
    artifact_id: str
    status: str
    hash_mode: str | None = None
    expected_sha256: str | None = None
    actual_sha256: str | None = None


@dataclass
class SourceLockReport:
    verifier_version: str = VERIFIER_VERSION
    lock_id: str | None = None
    source_lock_canonical_sha256: str | None = None
    schema_version: int | None = None
    verified_manifest_sha256: str | None = None
    verified_bundle_entry_count: int = 0
    verified_bundle_bytes: int = 0
    verified_locked_artifact_count: int = 0
    extra_bundle_files: list[str] = field(default_factory=list)
    host_diagnostic_files: list[str] = field(default_factory=list)
    artifact_results: list[ArtifactVerificationStatus] = field(default_factory=list)
    issues: list[VerificationIssue] = field(default_factory=list)

    @property
    def ok(self) -> bool:
        return not self.issues

    def add(
        self,
        code: str,
        subject: str,
        detail: str,
        *,
        expected: Any = None,
        actual: Any = None,
    ) -> None:
        self.issues.append(
            VerificationIssue(
                code=code,
                subject=subject,
                detail=detail,
                expected=_safe_report_value(expected),
                actual=_safe_report_value(actual),
            )
        )

    def authoritative_dict(self) -> dict[str, Any]:
        """Stable verification evidence; excludes host-local unlocked diagnostics."""
        return {
            "report_schema_version": REPORT_SCHEMA_VERSION,
            "verifier_version": self.verifier_version,
            "ok": self.ok,
            "lock_id": self.lock_id,
            "source_lock_canonical_sha256": self.source_lock_canonical_sha256,
            "schema_version": self.schema_version,
            "verified_manifest_sha256": self.verified_manifest_sha256,
            "verified_bundle_entry_count": self.verified_bundle_entry_count,
            "verified_bundle_bytes": self.verified_bundle_bytes,
            "verified_locked_artifact_count": self.verified_locked_artifact_count,
            "artifact_results": [
                asdict(result)
                for result in sorted(
                    self.artifact_results,
                    key=lambda item: (item.artifact_id, item.status),
                )
            ],
            "issues": [
                asdict(issue)
                for issue in sorted(
                    self.issues,
                    key=lambda item: (item.code, item.subject),
                )
            ],
        }

    def to_dict(self) -> dict[str, Any]:
        authoritative = self.authoritative_dict()
        digest_scope = {
            "report_schema_version": REPORT_SCHEMA_VERSION,
            "verifier_version": self.verifier_version,
            "ok": self.ok,
            "lock_id": self.lock_id,
            "source_lock_canonical_sha256": self.source_lock_canonical_sha256,
            "schema_version": self.schema_version,
            "verified_manifest_sha256": self.verified_manifest_sha256,
            "verified_bundle_entry_count": self.verified_bundle_entry_count,
            "verified_bundle_bytes": self.verified_bundle_bytes,
            "verified_locked_artifact_count": self.verified_locked_artifact_count,
            "artifact_results": authoritative["artifact_results"],
            "issue_identities": [
                {"code": issue.code, "subject": issue.subject}
                for issue in sorted(self.issues, key=lambda item: (item.code, item.subject))
            ],
        }
        return {
            **authoritative,
            "authoritative_result_sha256": sha256_bytes(
                canonical_json_v1_bytes(digest_scope)
            ),
            "authoritative_digest_scope": "stable identity/count/hash fields plus issue code+subject; excludes localized detail and host diagnostics",
            "host_diagnostics": {
                "unlocked_non_executable_files": sorted(self.extra_bundle_files),
                "ignored_python_cache_files": sorted(self.host_diagnostic_files),
            },
            # Retained for report-schema v1 callers; never part of the authority digest.
            "extra_bundle_files": sorted(self.extra_bundle_files),
            "host_diagnostic_files": sorted(self.host_diagnostic_files),
        }

    def add_artifact_result(
        self,
        artifact_id: str,
        status: str,
        *,
        hash_mode: Any = None,
        expected_sha256: Any = None,
        actual_sha256: Any = None,
    ) -> None:
        self.artifact_results.append(
            ArtifactVerificationStatus(
                artifact_id=str(artifact_id),
                status=status,
                hash_mode=hash_mode if isinstance(hash_mode, str) else None,
                expected_sha256=(
                    expected_sha256.upper()
                    if _valid_sha256(expected_sha256)
                    else None
                ),
                actual_sha256=(
                    actual_sha256.upper()
                    if _valid_sha256(actual_sha256)
                    else None
                ),
            )
        )


def _reject_duplicate_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise DuplicateJsonKeyError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def load_json_bytes_strict(data: bytes) -> Any:
    def reject_nonstandard_constant(value: str) -> Any:
        raise ValueError(f"non-standard JSON constant is forbidden: {value}")

    return json.loads(
        data.decode("utf-8"),
        object_pairs_hook=_reject_duplicate_keys,
        parse_constant=reject_nonstandard_constant,
    )


def load_json_strict(path: Path) -> Any:
    return load_json_bytes_strict(path.read_bytes())


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest().upper()


def sha256_file(path: Path, chunk_size: int = 1024 * 1024) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        while chunk := stream.read(chunk_size):
            digest.update(chunk)
    return digest.hexdigest().upper()


def canonical_json_bytes(value: Any) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        allow_nan=False,
        separators=(",", ":"),
        sort_keys=True,
    ).encode("utf-8")


def canonical_json_v1_bytes(value: Any) -> bytes:
    """Canonical artifact form on the exact cross-runtime safe JSON subset."""
    stack: list[tuple[bool, Any]] = [(False, value)]
    active_container_ids: set[int] = set()
    while stack:
        exiting, current = stack.pop()
        current_type = type(current)
        if exiting:
            active_container_ids.remove(id(current))
            continue
        if current is None or current_type is bool:
            continue
        if current_type is int:
            if not (
                -_CANONICAL_JSON_V1_MAX_SAFE_INTEGER
                <= current
                <= _CANONICAL_JSON_V1_MAX_SAFE_INTEGER
            ):
                raise ValueError("canonical_json_v1 integer is outside the safe range")
            continue
        if current_type is str:
            _validate_canonical_json_v1_string(current)
            continue
        if current_type is list:
            container_id = id(current)
            if container_id in active_container_ids:
                raise ValueError("canonical_json_v1 does not accept cyclic arrays")
            active_container_ids.add(container_id)
            stack.append((True, current))
            stack.extend((False, child) for child in reversed(current))
            continue
        if current_type is dict:
            if any(type(key) is not str for key in current):
                raise ValueError("canonical_json_v1 object keys must be exact strings")
            for key in current:
                _validate_canonical_json_v1_string(key)
            container_id = id(current)
            if container_id in active_container_ids:
                raise ValueError("canonical_json_v1 does not accept cyclic objects")
            active_container_ids.add(container_id)
            stack.append((True, current))
            stack.extend((False, child) for child in reversed(tuple(current.values())))
            continue
        raise ValueError(
            "canonical_json_v1 accepts only exact object/list/string/safe-integer/boolean/null"
        )
    return canonical_json_bytes(value)


def _validate_canonical_json_v1_string(value: str) -> None:
    for character in value:
        codepoint = ord(character)
        if (
            0xD800 <= codepoint <= 0xDFFF
            or 0xFDD0 <= codepoint <= 0xFDEF
            or (codepoint & 0xFFFF) in (0xFFFE, 0xFFFF)
        ):
            raise ValueError(
                "canonical_json_v1 strings reject surrogates and Unicode noncharacters"
            )


def _valid_sha256(value: Any) -> bool:
    return isinstance(value, str) and _SHA256_RE.fullmatch(value) is not None


def _is_nonnegative_int(value: Any) -> bool:
    return type(value) is int and value >= 0


def _validate_lock_metadata(
    lock: Mapping[str, Any],
    report: SourceLockReport,
) -> None:
    lock_id = lock.get("lock_id")
    report.lock_id = lock_id if isinstance(lock_id, str) else None
    if not isinstance(lock_id, str) or _LOCK_ID_RE.fullmatch(lock_id) is None:
        report.add(
            "invalid_lock_id",
            "SOURCE_LOCK.lock_id",
            "lock_id must be a non-empty portable identifier",
        )

    bundle = lock.get("official_bundle")
    if not isinstance(bundle, dict):
        return
    extra_file_policy = bundle.get("extra_file_policy")
    if extra_file_policy != SUPPORTED_EXTRA_FILE_POLICY:
        report.add(
            "unsupported_extra_file_policy",
            "official_bundle.extra_file_policy",
            "extra-file behavior must be reviewed before verification",
            expected=SUPPORTED_EXTRA_FILE_POLICY,
            actual=extra_file_policy,
        )
    if lock.get("hash_modes") != SUPPORTED_HASH_MODE_DESCRIPTIONS:
        report.add(
            "invalid_hash_mode_contract",
            "SOURCE_LOCK.hash_modes",
            "hash-mode descriptions are versioned contract data",
            expected=SUPPORTED_HASH_MODE_DESCRIPTIONS,
            actual=lock.get("hash_modes"),
        )
    if lock.get("auxiliary_hash_policy") != AUXILIARY_HASH_POLICY:
        report.add(
            "invalid_auxiliary_hash_policy",
            "SOURCE_LOCK.auxiliary_hash_policy",
            "auxiliary raw/LF hashes must be explicitly non-authoritative",
            expected=AUXILIARY_HASH_POLICY,
            actual=lock.get("auxiliary_hash_policy"),
        )


def _validate_candidate_artifact_references(
    lock: Mapping[str, Any],
    report: SourceLockReport,
) -> None:
    artifacts = lock.get("artifacts")
    artifact_ids: list[str] = []
    if isinstance(artifacts, list):
        artifact_ids = [
            artifact.get("id")
            for artifact in artifacts
            if isinstance(artifact, dict) and isinstance(artifact.get("id"), str)
        ]

    candidate = lock.get("candidate_first_vertical_slice")
    if not isinstance(candidate, dict):
        report.add(
            "invalid_candidate_first_vertical_slice",
            "candidate_first_vertical_slice",
            "candidate_first_vertical_slice must be an object",
        )
        return

    references: list[str] = []
    expected_roles = {
        "official_deck_artifact_id": "proposed_vertical_slice_official_deck",
        "local_deck_artifact_id": "proposed_vertical_slice_local_deck",
    }
    for field_name in _CANDIDATE_ARTIFACT_REFERENCE_FIELDS:
        artifact_id = candidate.get(field_name)
        subject = f"candidate_first_vertical_slice.{field_name}"
        if not isinstance(artifact_id, str) or not artifact_id:
            report.add(
                "invalid_candidate_artifact_ref",
                subject,
                "candidate artifact reference must be a non-empty string",
            )
            continue
        references.append(artifact_id)
        if artifact_ids.count(artifact_id) != 1:
            report.add(
                "unresolved_candidate_artifact_ref",
                subject,
                "candidate artifact reference must resolve exactly once",
                expected=artifact_id,
                actual=artifact_ids.count(artifact_id),
            )
        else:
            artifact = next(
                item
                for item in artifacts
                if isinstance(item, dict) and item.get("id") == artifact_id
            )
            if artifact.get("role") != expected_roles[field_name]:
                report.add(
                    "candidate_artifact_role_mismatch",
                    subject,
                    "candidate references must preserve official/local deck authority",
                    expected=expected_roles[field_name],
                    actual=artifact.get("role"),
                )
    if (
        len(references) == len(_CANDIDATE_ARTIFACT_REFERENCE_FIELDS)
        and len(set(references)) != len(references)
    ):
        report.add(
            "duplicate_candidate_artifact_ref",
            "candidate_first_vertical_slice",
            "official and local candidate decks must reference distinct artifacts",
        )


def _is_host_diagnostic(relative_path: str) -> bool:
    pure = PurePosixPath(relative_path)
    return pure.suffix.lower() == ".pyc" and "__pycache__" in pure.parts


def resolve_locked_artifact(
    source_lock: Mapping[str, Any],
    artifact_id: str,
    *,
    root_overrides: Mapping[str, str | Path] | None = None,
) -> tuple[Path, Mapping[str, Any]]:
    """Resolve and verify one artifact through the same containment rules as the lock verifier."""
    version = source_lock.get("schema_version")
    if type(version) is not int or version != SUPPORTED_SCHEMA_VERSION:
        raise ValueError(f"unsupported source lock schema: {version!r}")
    artifacts = source_lock.get("artifacts")
    if not isinstance(artifacts, list):
        raise ValueError("source lock artifacts must be an array")
    matches = [
        artifact
        for artifact in artifacts
        if isinstance(artifact, dict) and artifact.get("id") == artifact_id
    ]
    if len(matches) != 1:
        raise ValueError(f"source artifact must resolve exactly once: {artifact_id}")
    artifact = matches[0]
    root_id = artifact.get("root_id")
    roots = source_lock.get("roots")
    if not isinstance(root_id, str) or not isinstance(roots, dict) or root_id not in roots:
        raise ValueError(f"invalid artifact root: {root_id!r}")
    root_metadata = roots[root_id]
    if not isinstance(root_metadata, dict):
        raise ValueError(f"invalid root metadata: {root_id!r}")
    selected = (root_overrides or {}).get(root_id, root_metadata.get("captured_path"))
    if not isinstance(selected, (str, Path)):
        raise ValueError(f"no path for artifact root: {root_id!r}")
    try:
        root = Path(selected)
        if not root.is_absolute() or not root.is_dir():
            raise ValueError(
                f"artifact root must be an existing absolute directory: {root_id!r}"
            )
    except (OSError, RuntimeError) as exc:
        raise ValueError(f"artifact root could not be resolved: {root_id!r}") from exc
    path, path_error = _safe_relative_path(root, artifact.get("relative_path"))
    if path_error or path is None:
        raise ValueError(path_error or "invalid artifact path")
    try:
        if not path.is_file():
            raise ValueError(f"locked artifact is missing: {artifact_id}")
    except (OSError, RuntimeError) as exc:
        raise ValueError(f"locked artifact could not be inspected: {artifact_id}") from exc
    expected = artifact.get("sha256")
    if not _valid_sha256(expected):
        raise ValueError(f"invalid locked artifact SHA-256: {artifact_id}")
    mode = artifact.get("hash_mode")
    if not isinstance(mode, str):
        raise ValueError(f"locked artifact hash mode must be explicit: {artifact_id}")
    try:
        if mode == "raw_bytes":
            actual = sha256_file(path)
        elif mode == "canonical_json_v1":
            actual = sha256_bytes(canonical_json_v1_bytes(load_json_strict(path)))
        else:
            raise ValueError(f"unsupported artifact hash mode: {mode!r}")
    except (OSError, RuntimeError, TypeError) as exc:
        raise ValueError(f"locked artifact could not be hashed: {artifact_id}") from exc
    if actual != expected.upper():
        raise ValueError(f"locked artifact hash drift: {artifact_id}")
    try:
        return path.resolve(), artifact
    except (OSError, RuntimeError) as exc:
        raise ValueError(f"locked artifact could not be resolved: {artifact_id}") from exc


def _safe_relative_path(root: Path, relative: Any) -> tuple[Path | None, str | None]:
    if not isinstance(relative, str) or not relative:
        return None, "relative path must be a non-empty string"
    if "\\" in relative:
        return None, "relative path must use '/' separators"
    pure = PurePosixPath(relative)
    if pure.is_absolute() or any(part in {"", ".", ".."} for part in pure.parts):
        return None, "relative path must stay below its logical root"
    try:
        root_resolved = root.resolve()
        candidate = root_resolved.joinpath(*pure.parts)
        candidate.resolve(strict=False).relative_to(root_resolved)
    except ValueError:
        return None, "resolved path escapes its logical root"
    except (OSError, RuntimeError):
        return None, "path resolution failed safely"
    return candidate, None


def _resolve_roots(
    lock: Mapping[str, Any],
    overrides: Mapping[str, Path] | None,
    report: SourceLockReport,
) -> dict[str, Path]:
    raw_roots = lock.get("roots")
    if not isinstance(raw_roots, dict) or not raw_roots:
        report.add("invalid_roots", "roots", "roots must be a non-empty object")
        return {}
    result: dict[str, Path] = {}
    overrides = overrides or {}
    unknown_overrides = set(overrides) - set(raw_roots)
    for root_id in sorted(unknown_overrides):
        report.add("unknown_root_override", root_id, "override does not name a locked root")
    for root_id, metadata in sorted(raw_roots.items()):
        if not isinstance(root_id, str) or not isinstance(metadata, dict):
            report.add("invalid_root", str(root_id), "root metadata must be an object")
            continue
        captured = metadata.get("captured_path")
        selected = overrides.get(root_id, Path(captured) if isinstance(captured, str) else None)
        if selected is None:
            report.add("missing_root_path", root_id, "no captured path or override was provided")
            continue
        try:
            selected = Path(selected)
            if not selected.is_absolute():
                report.add("non_absolute_root", root_id, "logical roots must resolve to absolute paths")
                continue
            if not selected.is_dir():
                report.add("missing_root", root_id, "logical root directory does not exist")
                continue
            result[root_id] = selected.resolve()
        except (OSError, RuntimeError, ValueError, TypeError):
            report.add(
                "root_resolution_error",
                root_id,
                "logical root could not be resolved safely",
            )
    return result


def _verify_artifacts(
    lock: Mapping[str, Any],
    roots: Mapping[str, Path],
    report: SourceLockReport,
) -> None:
    artifacts = lock.get("artifacts")
    if not isinstance(artifacts, list):
        report.add("invalid_artifacts", "artifacts", "artifacts must be an array")
        return
    seen: set[str] = set()
    for index, artifact in enumerate(artifacts):
        subject = f"artifacts[{index}]"
        if not isinstance(artifact, dict):
            report.add("invalid_artifact", subject, "artifact must be an object")
            report.add_artifact_result(subject, "invalid_artifact")
            continue
        artifact_id = artifact.get("id")
        if not isinstance(artifact_id, str) or not artifact_id:
            report.add("invalid_artifact_id", subject, "artifact id must be non-empty")
            report.add_artifact_result(subject, "invalid_artifact_id")
            continue
        subject = artifact_id
        mode = artifact.get("hash_mode")
        expected = artifact.get("sha256")
        if artifact_id in seen:
            report.add("duplicate_artifact_id", subject, "artifact ids must be unique")
            report.add_artifact_result(
                artifact_id,
                "duplicate_artifact_id",
                hash_mode=mode,
                expected_sha256=expected,
            )
            continue
        seen.add(artifact_id)
        root_id = artifact.get("root_id")
        if not isinstance(root_id, str) or root_id not in roots:
            report.add("unresolved_artifact_root", subject, f"root is unavailable: {root_id!r}")
            report.add_artifact_result(
                artifact_id,
                "unresolved_root",
                hash_mode=mode,
                expected_sha256=expected,
            )
            continue
        path, path_error = _safe_relative_path(roots[root_id], artifact.get("relative_path"))
        if path_error:
            report.add("unsafe_artifact_path", subject, path_error)
            report.add_artifact_result(
                artifact_id,
                "unsafe_path",
                hash_mode=mode,
                expected_sha256=expected,
            )
            continue
        assert path is not None
        if not path.is_file():
            report.add("missing_artifact", subject, "locked artifact is missing")
            report.add_artifact_result(
                artifact_id,
                "missing",
                hash_mode=mode,
                expected_sha256=expected,
            )
            continue
        if not _valid_sha256(expected):
            report.add("invalid_sha256", subject, "sha256 must be 64 hexadecimal characters")
            report.add_artifact_result(
                artifact_id,
                "invalid_sha256",
                hash_mode=mode,
            )
            continue
        if not isinstance(mode, str):
            report.add("missing_hash_mode", subject, "hash_mode must be explicit")
            report.add_artifact_result(
                artifact_id,
                "invalid_hash_mode",
                expected_sha256=expected,
            )
            continue
        actual: str | None = None
        try:
            if mode == "raw_bytes":
                actual = sha256_file(path)
            elif mode == "canonical_json_v1":
                actual = sha256_bytes(canonical_json_v1_bytes(load_json_strict(path)))
            else:
                report.add("unknown_hash_mode", subject, f"unsupported hash mode: {mode!r}")
                report.add_artifact_result(
                    artifact_id,
                    "unknown_hash_mode",
                    hash_mode=mode,
                    expected_sha256=expected,
                )
                continue
        except (OSError, ValueError, TypeError, RuntimeError, json.JSONDecodeError) as exc:
            report.add("artifact_read_error", subject, str(exc))
            report.add_artifact_result(
                artifact_id,
                "read_error",
                hash_mode=mode,
                expected_sha256=expected,
            )
            continue
        if actual != expected.upper():
            report.add(
                "sha256_mismatch",
                subject,
                f"{mode} SHA-256 does not match",
                expected=expected.upper(),
                actual=actual,
            )
            report.add_artifact_result(
                artifact_id,
                "sha256_mismatch",
                hash_mode=mode,
                expected_sha256=expected,
                actual_sha256=actual,
            )
            continue
        report.verified_locked_artifact_count += 1
        report.add_artifact_result(
            artifact_id,
            "verified",
            hash_mode=mode,
            expected_sha256=expected,
            actual_sha256=actual,
        )


def _verify_bundle(
    lock: Mapping[str, Any],
    roots: Mapping[str, Path],
    report: SourceLockReport,
) -> None:
    bundle = lock.get("official_bundle")
    if not isinstance(bundle, dict):
        report.add("invalid_official_bundle", "official_bundle", "must be an object")
        return
    expected_count = bundle.get("file_count")
    expected_total = bundle.get("total_bytes")
    if not _is_nonnegative_int(expected_count):
        report.add(
            "invalid_bundle_file_count",
            "official_bundle.file_count",
            "file_count must be a non-negative integer",
        )
        expected_count = None
    if not _is_nonnegative_int(expected_total):
        report.add(
            "invalid_bundle_total_bytes",
            "official_bundle.total_bytes",
            "total_bytes must be a non-negative integer",
        )
        expected_total = None
    root_id = bundle.get("root_id")
    if not isinstance(root_id, str) or root_id not in roots:
        report.add("unresolved_bundle_root", "official_bundle", f"root is unavailable: {root_id!r}")
        return
    bundle_root, error = _safe_relative_path(roots[root_id], bundle.get("relative_path"))
    if error:
        report.add("unsafe_bundle_path", "official_bundle", error)
        return
    assert bundle_root is not None
    if not bundle_root.is_dir():
        report.add("missing_bundle", "official_bundle", "bundle directory does not exist")
        return
    manifest_path, error = _safe_relative_path(bundle_root, bundle.get("manifest"))
    if error:
        report.add("unsafe_manifest_path", "official_bundle.manifest", error)
        return
    assert manifest_path is not None
    if not manifest_path.is_file():
        report.add("missing_manifest", "official_bundle.manifest", "manifest file does not exist")
        return
    expected_manifest_hash = bundle.get("manifest_sha256")
    if not _valid_sha256(expected_manifest_hash):
        report.add("invalid_manifest_sha256", "official_bundle.manifest", "manifest hash is invalid")
        return
    actual_manifest_hash = sha256_file(manifest_path)
    if actual_manifest_hash != expected_manifest_hash.upper():
        report.add(
            "manifest_sha256_mismatch",
            "official_bundle.manifest",
            "manifest is not trusted; entries were not evaluated",
            expected=expected_manifest_hash.upper(),
            actual=actual_manifest_hash,
        )
        return
    report.verified_manifest_sha256 = actual_manifest_hash
    try:
        manifest = load_json_strict(manifest_path)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        report.add("manifest_parse_error", "official_bundle.manifest", str(exc))
        return
    entries = manifest.get("files") if isinstance(manifest, dict) else None
    if not isinstance(entries, list):
        report.add("invalid_manifest_entries", "official_bundle.manifest", "files must be an array")
        return
    manifest_count = manifest.get("file_count")
    manifest_total = manifest.get("total_bytes")
    if not _is_nonnegative_int(manifest_count):
        report.add(
            "invalid_manifest_file_count",
            "official_bundle.manifest.file_count",
            "file_count must be a non-negative integer",
        )
        manifest_count = None
    if not _is_nonnegative_int(manifest_total):
        report.add(
            "invalid_manifest_total_bytes",
            "official_bundle.manifest.total_bytes",
            "total_bytes must be a non-negative integer",
        )
        manifest_total = None
    locked_names: set[str] = set()
    locked_casefold_names: dict[str, str] = {}
    verified_bytes = 0
    declared_entry_bytes = 0
    all_entry_sizes_valid = True
    for index, entry in enumerate(entries):
        subject = f"official_bundle.files[{index}]"
        if not isinstance(entry, dict):
            report.add("invalid_manifest_entry", subject, "entry must be an object")
            continue
        name = entry.get("name")
        if not isinstance(name, str) or not name:
            report.add("invalid_manifest_name", subject, "name must be non-empty")
            continue
        subject = name
        if name in locked_names:
            report.add("duplicate_manifest_name", subject, "manifest names must be unique")
            continue
        folded_name = name.casefold()
        conflicting_name = locked_casefold_names.get(folded_name)
        if conflicting_name is not None and conflicting_name != name:
            report.add(
                "casefold_manifest_name_collision",
                subject,
                "manifest names must remain distinct on case-insensitive filesystems",
                expected=conflicting_name,
                actual=name,
            )
            continue
        locked_names.add(name)
        locked_casefold_names[folded_name] = name
        path, path_error = _safe_relative_path(bundle_root, name)
        if path_error:
            report.add("unsafe_manifest_path", subject, path_error)
            continue
        assert path is not None
        if not path.is_file():
            report.add("missing_bundle_entry", subject, "manifest entry is missing")
            continue
        expected_size = entry.get("size")
        if not _is_nonnegative_int(expected_size):
            report.add("invalid_bundle_entry_size", subject, "size must be a non-negative integer")
            all_entry_sizes_valid = False
            continue
        declared_entry_bytes += expected_size
        actual_size = path.stat().st_size
        if actual_size != expected_size:
            report.add(
                "bundle_entry_size_mismatch",
                subject,
                "entry byte size does not match",
                expected=expected_size,
                actual=actual_size,
            )
            continue
        expected_hash = entry.get("sha256")
        if not _valid_sha256(expected_hash):
            report.add("invalid_bundle_entry_sha256", subject, "entry hash is invalid")
            continue
        actual_hash = sha256_file(path)
        if actual_hash != expected_hash.upper():
            report.add(
                "sha256_mismatch",
                subject,
                "bundle entry SHA-256 does not match",
                expected=expected_hash.upper(),
                actual=actual_hash,
            )
            continue
        report.verified_bundle_entry_count += 1
        verified_bytes += actual_size
    report.verified_bundle_bytes = verified_bytes

    if expected_count is not None and (
        len(entries) != expected_count
        or (manifest_count is not None and manifest_count != expected_count)
    ):
        report.add(
            "bundle_file_count_mismatch",
            "official_bundle",
            "lock, manifest metadata, and manifest entries must agree",
            expected=expected_count,
            actual={"manifest_metadata": manifest_count, "entries": len(entries)},
        )
    if expected_total is not None and (
        (all_entry_sizes_valid and declared_entry_bytes != expected_total)
        or (manifest_total is not None and manifest_total != expected_total)
    ):
        report.add(
            "bundle_total_bytes_mismatch",
            "official_bundle",
            "lock, manifest metadata, and entry sizes must agree",
            expected=expected_total,
            actual={
                "manifest_metadata": manifest_total,
                "entry_sizes": declared_entry_bytes,
            },
        )

    physical_files = {
        path.relative_to(bundle_root).as_posix(): path
        for path in bundle_root.rglob("*")
        if path.is_file()
    }
    manifest_relative = manifest_path.relative_to(bundle_root).as_posix()
    extras = set(physical_files) - locked_names - {manifest_relative}
    report.host_diagnostic_files = sorted(
        relative for relative in extras if _is_host_diagnostic(relative)
    )
    authoritative_extras = extras - set(report.host_diagnostic_files)
    report.extra_bundle_files = sorted(authoritative_extras)
    for relative in report.extra_bundle_files:
        report.add(
            "unlocked_bundle_file",
            relative,
            "every non-cache physical bundle file must be pinned by the trusted manifest",
        )


def verify_source_lock(
    lock_path: str | Path,
    *,
    root_overrides: Mapping[str, str | Path] | None = None,
    expected_lock_sha256: str | None = None,
) -> SourceLockReport:
    report = SourceLockReport()
    try:
        path = Path(lock_path)
        lock = load_json_strict(path)
    except (OSError, ValueError, TypeError, RuntimeError, json.JSONDecodeError) as exc:
        report.add("source_lock_parse_error", "SOURCE_LOCK", str(exc))
        return report
    try:
        report.source_lock_canonical_sha256 = sha256_bytes(canonical_json_v1_bytes(lock))
    except (ValueError, TypeError, RuntimeError) as exc:
        report.add("source_lock_canonicalization_error", "SOURCE_LOCK", str(exc))
    if expected_lock_sha256 is not None:
        if not _valid_sha256(expected_lock_sha256):
            report.add(
                "invalid_expected_source_lock_sha256",
                "expected_lock_sha256",
                "expected source-lock hash must be 64 hexadecimal characters",
            )
        elif report.source_lock_canonical_sha256 != expected_lock_sha256.upper():
            report.add(
                "expected_source_lock_sha256_mismatch",
                "SOURCE_LOCK",
                "caller trust anchor does not match the supplied lock",
                expected=expected_lock_sha256.upper(),
                actual=report.source_lock_canonical_sha256,
            )
    if not isinstance(lock, dict):
        report.add("invalid_source_lock", "SOURCE_LOCK", "root value must be an object")
        return report
    version = lock.get("schema_version")
    report.schema_version = version if type(version) is int else None
    if type(version) is not int or version != SUPPORTED_SCHEMA_VERSION:
        report.add(
            "unsupported_schema_version",
            "SOURCE_LOCK.schema_version",
            "source lock schema must be reviewed before verification",
            expected=SUPPORTED_SCHEMA_VERSION,
            actual=version,
        )
        return report
    _validate_lock_metadata(lock, report)
    _validate_candidate_artifact_references(lock, report)
    try:
        normalized_overrides = {
            key: Path(value) for key, value in (root_overrides or {}).items()
        }
        roots = _resolve_roots(lock, normalized_overrides, report)
    except (OSError, ValueError, TypeError, RuntimeError) as exc:
        report.add("root_resolution_error", "roots", str(exc))
        roots = {}
    try:
        _verify_bundle(lock, roots, report)
    except (OSError, ValueError, TypeError, RuntimeError) as exc:
        report.add("bundle_verification_error", "official_bundle", str(exc))
    try:
        _verify_artifacts(lock, roots, report)
    except (OSError, ValueError, TypeError, RuntimeError) as exc:
        report.add("artifact_verification_error", "artifacts", str(exc))
    return report


def _parse_root_overrides(values: Sequence[str]) -> dict[str, Path]:
    result: dict[str, Path] = {}
    for value in values:
        root_id, separator, raw_path = value.partition("=")
        if not separator or not root_id or not raw_path:
            raise argparse.ArgumentTypeError("--root must use ROOT_ID=ABSOLUTE_PATH")
        if root_id in result:
            raise argparse.ArgumentTypeError(f"duplicate --root override: {root_id}")
        result[root_id] = Path(raw_path)
    return result


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Verify the pinned PtcgDAP source lock.")
    parser.add_argument("--lock", type=Path, required=True)
    parser.add_argument("--root", action="append", default=[], metavar="ID=PATH")
    parser.add_argument("--expect-lock-sha256", metavar="SHA256")
    parser.add_argument("--format", choices=("json", "text"), default="text")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    parser = _build_parser()
    args = parser.parse_args(argv)
    try:
        overrides = _parse_root_overrides(args.root)
    except argparse.ArgumentTypeError as exc:
        parser.error(str(exc))
    report = verify_source_lock(
        args.lock,
        root_overrides=overrides,
        expected_lock_sha256=args.expect_lock_sha256,
    )
    serialization_failed = False
    try:
        payload = report.to_dict()
        serialized = json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True)
    except (ValueError, TypeError, RuntimeError, RecursionError):
        serialization_failed = True
        payload = {
            "report_schema_version": REPORT_SCHEMA_VERSION,
            "verifier_version": VERIFIER_VERSION,
            "ok": False,
            "authoritative_result_sha256": None,
            "issues": [
                {
                    "code": "report_serialization_error",
                    "subject": "source_lock_report",
                    "detail": "report could not be serialized safely",
                }
            ],
        }
        serialized = json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True)
    effective_ok = report.ok and not serialization_failed
    if args.format == "json":
        print(serialized)
    else:
        print("PASS" if effective_ok else "FAIL")
        print(f"lock id: {report.lock_id}")
        print(f"source lock: {report.source_lock_canonical_sha256}")
        print(f"manifest: {report.verified_manifest_sha256}")
        print(
            "authoritative result: "
            f"{payload.get('authoritative_result_sha256') or 'unavailable'}"
        )
        print(f"bundle entries: {report.verified_bundle_entry_count}")
        print(f"locked artifacts: {report.verified_locked_artifact_count}")
        for issue in payload["issues"]:
            print(f"[{issue['code']}] {issue['subject']}: {issue['detail']}")
        if report.extra_bundle_files:
            print(f"unlocked extras: {len(report.extra_bundle_files)}")
        if report.host_diagnostic_files:
            print(f"host diagnostics: {len(report.host_diagnostic_files)}")
    return 0 if effective_ok else 1


if __name__ == "__main__":
    sys.exit(main())
