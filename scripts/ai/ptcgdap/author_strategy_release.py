from __future__ import annotations

import hashlib
from pathlib import Path
from typing import Mapping

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


PROFILE_ID = "ptcgdap-author-strategy-release-as-wp6-v1"
EXPECTED_BUNDLE_CANONICAL_SHA256 = "527D725B50946874D62C95B957DB401A5EC6F58A5A2E8653650E89E765E7AE26"
BUNDLE_PATH = Path("contracts/ptcgdap/author_strategy_release_bundle.json")
PROFILE_PATH = Path("contracts/ptcgdap/author_strategy_release_profile.json")
TRUST_STORE_PATH = Path("data/ptcgdap/author_strategy_release_trust_store.json")
APPROVALS_PATH = Path("data/ptcgdap/author_strategy_release_approvals.json")
DEVICE_CANARY_APPROVALS_PATH = Path("data/ptcgdap/author_strategy_device_canary_approvals.json")
PROMPT_CONFORMANCE_APPROVALS_PATH = Path("data/ptcgdap/author_strategy_prompt_conformance_approvals.json")
DEVICE_PROFILE_PATH = Path("data/ptcgdap/author_strategy_device_acceptance_profile.json")
OFFICIAL_SOURCE_LOCK_SHA256 = "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"
REQUIRED_PROMPT_COVERAGE = tuple(f"W{index}" for index in range(8))
MAX_SAFE_INTEGER = 9_007_199_254_740_991
MAX_COLD_START_SAMPLES = 1_000
MAX_DECISION_SAMPLES = 1_000_000
DEVICE_REPORT_KEYS = frozenset(
    {
        "document_type",
        "schema_version",
        "profile_id",
        "platform",
        "architecture",
        "offline",
        "runtime",
        "samples",
        "measurements",
        "rollback",
        "evidence",
    }
)
DEVICE_REPORT_NESTED_KEYS = {
    "offline": frozenset(
        {
            "network_blocked",
            "complete_match_finished",
            "remote_inference_attempts",
            "dynamic_download_attempts",
        }
    ),
    "runtime": frozenset(
        {"system_python_required", "sidecar_processes", "external_compute_required"}
    ),
    "samples": frozenset({"cold_start_msec", "decision_msec"}),
    "measurements": frozenset(
        {
            "cold_start_msec",
            "catalog_scan_msec",
            "match_load_msec",
            "decision_p95_msec",
            "peak_memory_mib",
            "package_mib",
            "thermal_status_max",
            "battery_drain_percent_per_hour",
        }
    ),
    "rollback": frozenset({"mode_disabled", "user_packages_preserved"}),
    "evidence": frozenset(
        {
            "profile_canonical_sha256",
            "export_manifest_sha256",
            "network_audit_sha256",
            "process_audit_sha256",
            "full_match_audit_sha256",
            "rollback_report_sha256",
        }
    ),
}


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def _canonical_sha(value: object) -> str:
    return _sha(canonical_json_v1_bytes(value))


def _exact_bool(value: object) -> bool:
    return type(value) is bool


def _exact_nonnegative_int(value: object) -> bool:
    return type(value) is int and 0 <= value <= MAX_SAFE_INTEGER


def _is_sha256(value: object) -> bool:
    return (
        type(value) is str
        and len(value) == 64
        and all(character in "0123456789ABCDEF" for character in value)
    )


def _nearest_rank_p95(values: list[int]) -> int:
    ordered = sorted(values)
    return ordered[((95 * len(ordered) + 99) // 100) - 1]


def _result(accepted: bool, error_code: str, **extra: object) -> dict[str, object]:
    return {"accepted": accepted, "error_code": error_code, **extra}


def evaluate_device_report(
    profile: Mapping[str, object], report: Mapping[str, object]
) -> dict[str, object]:
    if not isinstance(profile, Mapping) or not isinstance(report, Mapping):
        return _result(False, "device_report_invalid")
    if profile.get("approval_status") != "approved":
        return _result(False, "device_profile_not_approved")
    if profile.get("formal_a5_eligible") is not True:
        return _result(False, "release_a5_unapproved")
    if set(report) != DEVICE_REPORT_KEYS:
        return _result(False, "device_report_invalid")
    if report.get("document_type") != "author_strategy_device_report_v1" or report.get("schema_version") != 1:
        return _result(False, "device_report_invalid")
    platform = report.get("platform")
    architecture = report.get("architecture")
    expected_architecture = {"windows": "x86_64", "android": "arm64-v8a"}.get(platform)
    platforms = profile.get("platforms")
    if expected_architecture is None or architecture != expected_architecture or not isinstance(platforms, Mapping):
        return _result(False, "device_report_invalid")
    limits = platforms.get(platform)
    offline = report.get("offline")
    runtime = report.get("runtime")
    samples = report.get("samples")
    measurements = report.get("measurements")
    rollback = report.get("rollback")
    evidence = report.get("evidence")
    nested = {
        "offline": offline,
        "runtime": runtime,
        "samples": samples,
        "measurements": measurements,
        "rollback": rollback,
        "evidence": evidence,
    }
    if not isinstance(limits, Mapping) or any(
        not isinstance(value, Mapping) or set(value) != DEVICE_REPORT_NESTED_KEYS[key]
        for key, value in nested.items()
    ):
        return _result(False, "device_report_invalid")
    if (
        report.get("profile_id") != profile.get("profile_id")
        or evidence.get("profile_canonical_sha256") != _canonical_sha(profile)
    ):
        return _result(False, "device_report_profile_mismatch")
    if any(not _is_sha256(evidence.get(key)) for key in DEVICE_REPORT_NESTED_KEYS["evidence"]):
        return _result(False, "device_evidence_invalid")
    cold_start_samples = samples.get("cold_start_msec")
    decision_samples = samples.get("decision_msec")
    if (
        type(cold_start_samples) is not list
        or type(decision_samples) is not list
        or len(cold_start_samples) > MAX_COLD_START_SAMPLES
        or len(decision_samples) > MAX_DECISION_SAMPLES
        or any(not _exact_nonnegative_int(value) for value in cold_start_samples)
        or any(not _exact_nonnegative_int(value) for value in decision_samples)
    ):
        return _result(False, "device_report_invalid")
    measurement_method = profile.get("measurement_method")
    if not isinstance(measurement_method, Mapping):
        return _result(False, "device_report_invalid")
    required_cold_starts = measurement_method.get("cold_start_samples")
    required_decisions = measurement_method.get("decision_samples_minimum")
    if (
        not _exact_nonnegative_int(required_cold_starts)
        or not _exact_nonnegative_int(required_decisions)
        or required_cold_starts == 0
        or required_decisions == 0
    ):
        return _result(False, "device_report_invalid")
    if len(cold_start_samples) != required_cold_starts or len(decision_samples) < required_decisions:
        return _result(False, "device_sample_count_insufficient")
    if (
        measurements.get("cold_start_msec") != max(cold_start_samples)
        or measurements.get("decision_p95_msec") != _nearest_rank_p95(decision_samples)
    ):
        return _result(False, "device_measurement_mismatch")
    if offline.get("network_blocked") is not True:
        return _result(False, "device_network_not_blocked")
    if (
        runtime.get("system_python_required") is not False
        or runtime.get("external_compute_required") is not False
        or type(runtime.get("sidecar_processes")) is not list
        or runtime.get("sidecar_processes")
        or not _exact_nonnegative_int(offline.get("remote_inference_attempts"))
        or not _exact_nonnegative_int(offline.get("dynamic_download_attempts"))
        or offline.get("remote_inference_attempts") != 0
        or offline.get("dynamic_download_attempts") != 0
    ):
        return _result(False, "device_external_runtime_detected")
    if offline.get("complete_match_finished") is not True:
        return _result(False, "device_full_match_incomplete")
    comparisons = (
        ("cold_start_msec", "max_cold_start_msec"),
        ("catalog_scan_msec", "max_catalog_scan_msec"),
        ("match_load_msec", "max_match_load_msec"),
        ("decision_p95_msec", "max_decision_p95_msec"),
        ("peak_memory_mib", "max_peak_memory_mib"),
        ("package_mib", "max_package_mib"),
    )
    exceeded: list[str] = []
    for measurement_key, limit_key in comparisons:
        value = measurements.get(measurement_key)
        limit = limits.get(limit_key)
        if not _exact_nonnegative_int(value) or not _exact_nonnegative_int(limit):
            return _result(False, "device_report_invalid")
        if value > limit:
            exceeded.append(measurement_key)
    if platform == "android":
        for measurement_key, limit_key in (
            ("thermal_status_max", "max_thermal_status"),
            ("battery_drain_percent_per_hour", "max_battery_drain_percent_per_hour"),
        ):
            value = measurements.get(measurement_key)
            limit = limits.get(limit_key)
            if not _exact_nonnegative_int(value) or not _exact_nonnegative_int(limit):
                return _result(False, "device_report_invalid")
            if value > limit:
                exceeded.append(measurement_key)
    elif measurements.get("thermal_status_max") is not None or measurements.get("battery_drain_percent_per_hour") is not None:
        return _result(False, "device_report_invalid")
    if exceeded:
        return _result(False, "device_resource_limit_exceeded", exceeded_measurements=exceeded)
    if rollback.get("mode_disabled") is not True or rollback.get("user_packages_preserved") is not True:
        return _result(False, "device_rollback_invalid")
    return _result(True, "", platform=platform, architecture=architecture, exceeded_measurements=[])


class AuthorStrategyReleaseGate:
    def __init__(self, root: Path | str | None = None) -> None:
        self._root = Path(root) if root is not None else Path(__file__).resolve().parents[3]
        self._profile: dict[str, object] = {}
        self._trust: dict[str, object] = {}
        self._approvals: dict[str, object] = {}
        self._canary_approvals: dict[str, object] = {}
        self._prompt_conformance_approvals: dict[str, object] = {}
        self._device: dict[str, object] = {}
        self._contract_ok = False
        self._contract_error = "release_contract_invalid"
        self._load_fixed_documents()

    def _load_fixed_documents(self) -> None:
        try:
            bundle = load_json_strict(self._root / BUNDLE_PATH)
            profile = load_json_strict(self._root / PROFILE_PATH)
            trust = load_json_strict(self._root / TRUST_STORE_PATH)
            approvals = load_json_strict(self._root / APPROVALS_PATH)
            canary_approvals = load_json_strict(
                self._root / DEVICE_CANARY_APPROVALS_PATH
            )
            prompt_conformance_approvals = load_json_strict(
                self._root / PROMPT_CONFORMANCE_APPROVALS_PATH
            )
            device = load_json_strict(self._root / DEVICE_PROFILE_PATH)
            if _canonical_sha(bundle) != EXPECTED_BUNDLE_CANONICAL_SHA256:
                return
            if bundle.get("bundle_id") != PROFILE_ID or profile.get("profile_id") != PROFILE_ID:
                return
            artifacts = bundle.get("artifacts")
            if type(artifacts) is not list:
                return
            expected_paths = {
                "contracts/ptcgdap/author_strategy_release.schema.json",
                "contracts/ptcgdap/author_strategy_release_profile.json",
                "contracts/ptcgdap/author_strategy_release_conformance_vectors.json",
                TRUST_STORE_PATH.as_posix(),
                APPROVALS_PATH.as_posix(),
                DEVICE_CANARY_APPROVALS_PATH.as_posix(),
                PROMPT_CONFORMANCE_APPROVALS_PATH.as_posix(),
                DEVICE_PROFILE_PATH.as_posix(),
            }
            seen: set[str] = set()
            for entry in artifacts:
                if type(entry) is not dict or type(entry.get("path")) is not str:
                    return
                relative = entry["path"]
                if relative not in expected_paths or relative in seen:
                    return
                document = load_json_strict(self._root / relative)
                if _canonical_sha(document) != entry.get("canonical_sha256"):
                    return
                seen.add(relative)
            if seen != expected_paths:
                return
            trust_profile = profile.get("trust_store")
            device_profile = profile.get("device_acceptance")
            approval_profile = profile.get("release_approvals")
            canary_profile = profile.get("device_canary_approvals")
            prompt_conformance_profile = profile.get("prompt_conformance_approvals")
            if (
                not isinstance(trust_profile, Mapping)
                or not isinstance(device_profile, Mapping)
                or not isinstance(approval_profile, Mapping)
                or not isinstance(canary_profile, Mapping)
                or not isinstance(prompt_conformance_profile, Mapping)
            ):
                return
            if (
                prompt_conformance_profile.get("path")
                != PROMPT_CONFORMANCE_APPROVALS_PATH.as_posix()
                or prompt_conformance_profile.get("caller_overrides") is not False
                or prompt_conformance_profile.get("official_source_lock_sha256")
                != OFFICIAL_SOURCE_LOCK_SHA256
            ):
                return
            if trust_profile.get("path") != TRUST_STORE_PATH.as_posix() or trust_profile.get("caller_overrides") is not False:
                return
            if device_profile.get("profile_path") != DEVICE_PROFILE_PATH.as_posix():
                return
            if approval_profile.get("path") != APPROVALS_PATH.as_posix() or approval_profile.get("caller_overrides") is not False:
                return
            if (
                canary_profile.get("path")
                != DEVICE_CANARY_APPROVALS_PATH.as_posix()
                or canary_profile.get("caller_overrides") is not False
                or canary_profile.get("activation_arg")
                != "--ptcgdap-production-device-canary"
                or canary_profile.get("ordinary_player_start") is not False
            ):
                return
            if trust.get("document_type") != "author_strategy_release_trust_store_v1" or type(trust.get("keys")) is not list:
                return
            if device.get("document_type") != "author_strategy_device_acceptance_profile_v1":
                return
            if approvals.get("document_type") != "author_strategy_release_approvals_v1" or type(approvals.get("records")) is not list:
                return
            if (
                canary_approvals.get("document_type")
                != "author_strategy_device_canary_approvals_v1"
                or type(canary_approvals.get("records")) is not list
            ):
                return
            if (
                prompt_conformance_approvals.get("document_type")
                != "author_strategy_prompt_conformance_approvals_v1"
                or type(prompt_conformance_approvals.get("records")) is not list
            ):
                return
        except (OSError, TypeError, ValueError):
            return
        self._profile = profile
        self._trust = trust
        self._approvals = approvals
        self._canary_approvals = canary_approvals
        self._prompt_conformance_approvals = prompt_conformance_approvals
        self._device = device
        self._contract_ok = True
        self._contract_error = ""

    def _current_error(self) -> str:
        if not self._contract_ok:
            return self._contract_error
        trust_status = self._trust.get("approval_status")
        if trust_status == "unprovisioned":
            return "release_trust_unprovisioned"
        if trust_status != "approved":
            return "release_trust_revoked"
        active_keys = [
            key
            for key in self._trust.get("keys", [])
            if type(key) is dict
            and key.get("algorithm") == "ed25519"
            and key.get("scope") == "production_release"
            and key.get("execution_trusted") is True
            and key.get("status") == "active"
        ]
        if not active_keys:
            return "release_trust_unprovisioned"
        if self._device.get("approval_status") != "approved":
            return "device_profile_not_approved"
        return ""

    def audit_snapshot(self) -> dict[str, object]:
        trust_error = self._current_error()
        readiness_error = self._production_readiness_error(trust_error)
        active_keys = self.trusted_release_keys()
        return {
            "profile_id": PROFILE_ID,
            "contract_ok": self._contract_ok,
            "production_trust_status": self._trust.get("approval_status", "invalid"),
            "device_profile_status": self._device.get("approval_status", "invalid"),
            "release_approval_status": self._approvals.get("approval_status", "invalid"),
            "approved_package_count": len(self._approvals.get("records", [])),
            "device_canary_approval_status": self._canary_approvals.get(
                "approval_status", "invalid"
            ),
            "approved_device_canary_count": len(
                self._canary_approvals.get("records", [])
            ),
            "prompt_conformance_approval_status": self._prompt_conformance_approvals.get(
                "approval_status", "invalid"
            ),
            "approved_prompt_conformance_count": len(
                self._prompt_conformance_approvals.get("records", [])
            ),
            "active_production_key_count": len(active_keys),
            "production_trust_ready": trust_error == "",
            "production_trust_error_code": trust_error,
            # A store-level audit has no exact installed package identity, so
            # it must never claim the package-specific release gate is ready.
            "production_ready": False,
            "player_start_allowed": False,
            "release_target_platforms": list(self._release_target_platforms()),
            "deferred_platforms": list(self._deferred_platforms()),
            "error_code": readiness_error,
        }

    def _production_readiness_error(self, trust_error: str) -> str:
        """Report the next fixed product gate without claiming package authority."""

        if trust_error:
            return trust_error
        prompt_records = self._prompt_conformance_approvals.get("records", [])
        if (
            self._prompt_conformance_approvals.get("approval_status") != "approved"
            or not any(
                type(record) is dict and record.get("status") == "active"
                for record in prompt_records
            )
        ):
            return "release_prompt_conformance_unapproved"
        canary_records = self._canary_approvals.get("records", [])
        if (
            self._canary_approvals.get("approval_status") != "approved"
            or not any(
                type(record) is dict and record.get("status") == "active"
                for record in canary_records
            )
        ):
            return "device_canary_not_approved"
        if self._device.get("formal_a5_eligible") is not True:
            return "release_a5_unapproved"
        release_records = self._approvals.get("records", [])
        if self._approvals.get("approval_status") != "approved" or not release_records:
            return "release_package_not_approved"
        # Exact cross-store identity and installed archive checks belong to
        # evaluate_installed_package(), never to this store-level snapshot.
        return "release_package_not_approved"

    def _release_target_platforms(self) -> tuple[str, ...]:
        targets = self._profile.get("supported_targets", [])
        if type(targets) is not list:
            return ()
        return tuple(
            target["platform"]
            for target in targets
            if type(target) is dict and type(target.get("platform")) is str
        )

    def _offline_requirements(self) -> dict[str, bool]:
        prerequisites = self._profile.get("release_prerequisites")
        required_platforms = self._release_target_platforms()
        if not isinstance(prerequisites, Mapping):
            return {}
        value = prerequisites.get("offline_full_match_by_platform")
        if (
            type(value) is not dict
            or set(value) != set(required_platforms)
            or any(type(value.get(platform)) is not bool for platform in required_platforms)
        ):
            return {}
        return {platform: value[platform] for platform in required_platforms}

    def _deferred_platforms(self) -> tuple[str, ...]:
        targets = self._profile.get("deferred_targets", [])
        if type(targets) is not list:
            return ()
        return tuple(
            target["platform"]
            for target in targets
            if type(target) is dict and type(target.get("platform")) is str
        )

    def trusted_release_keys(self) -> tuple[dict[str, object], ...]:
        if not self._contract_ok or self._trust.get("approval_status") != "approved":
            return ()
        return tuple(
            dict(key)
            for key in self._trust.get("keys", [])
            if type(key) is dict
            and key.get("algorithm") == "ed25519"
            and key.get("scope") == "production_release"
            and key.get("execution_trusted") is True
            and key.get("status") == "active"
        )

    def _has_approved_prompt_conformance(
        self,
        metadata: Mapping[str, object],
        report_sha256: object,
        platform: str,
    ) -> bool:
        if (
            self._prompt_conformance_approvals.get("approval_status") != "approved"
            or not _is_sha256(report_sha256)
        ):
            return False
        identity_keys = (
            "package_id",
            "package_version",
            "archive_sha256",
            "manifest_sha256",
            "policy_ir_sha256",
            "deck_manifest_sha256",
        )
        return any(
            type(record) is dict
            and record.get("status") == "active"
            and record.get("platform") == platform
            and record.get("prompt_conformance_report_sha256") == report_sha256
            and record.get("official_source_lock_sha256")
            == OFFICIAL_SOURCE_LOCK_SHA256
            and record.get("evidence_class")
            == "official_cabt_w0_w7_package_conformance"
            and record.get("prompt_coverage") == list(REQUIRED_PROMPT_COVERAGE)
            and all(record.get(field) == metadata.get(field) for field in identity_keys)
            for record in self._prompt_conformance_approvals.get("records", [])
        )

    def evaluate_package(self, metadata: Mapping[str, object]) -> dict[str, object]:
        if not isinstance(metadata, Mapping) or metadata.get("execution_trusted") is not True:
            return _result(False, "release_package_not_execution_trusted", player_start_allowed=False)
        if metadata.get("signature_scope") != "production_release":
            return _result(False, "release_package_scope_invalid", player_start_allowed=False)
        error = self._current_error()
        if error:
            return _result(False, error, player_start_allowed=False)
        key_id = metadata.get("signature_key_id")
        key = next(
            (
                candidate
                for candidate in self.trusted_release_keys()
                if candidate.get("key_id") == key_id
            ),
            None,
        )
        if key is None:
            return _result(False, "release_package_scope_invalid", player_start_allowed=False)
        if self._approvals.get("approval_status") != "approved":
            return _result(False, "release_package_not_approved", player_start_allowed=False)
        identity_keys = (
            "package_id",
            "package_version",
            "archive_sha256",
            "manifest_sha256",
            "policy_ir_sha256",
            "deck_manifest_sha256",
        )
        record = next(
            (
                approval
                for approval in self._approvals.get("records", [])
                if type(approval) is dict
                and all(approval.get(field) == metadata.get(field) for field in identity_keys)
            ),
            None,
        )
        if record is None:
            return _result(False, "release_package_not_approved", player_start_allowed=False)
        if record.get("prompt_coverage") != list(REQUIRED_PROMPT_COVERAGE):
            return _result(False, "release_prompt_coverage_incomplete", player_start_allowed=False)
        release_platforms = self._release_target_platforms()
        if not release_platforms or not all(
            self._has_approved_prompt_conformance(
                metadata,
                record.get("prompt_conformance_report_sha256"),
                platform,
            )
            for platform in release_platforms
        ):
            return _result(False, "release_prompt_conformance_unapproved", player_start_allowed=False)
        return _result(True, "", player_start_allowed=False, approval=dict(record))

    def evaluate_device_canary_package(
        self, metadata: Mapping[str, object], platform: str
    ) -> dict[str, object]:
        """Authorize only the one-shot device-evidence canary lane.

        This fixed product approval deliberately has no future device-report,
        rollback, or A5 hashes. It never grants ordinary player start; those
        hashes remain mandatory in ``evaluate_installed_package``.
        """

        if platform != "windows" or platform not in self._release_target_platforms():
            return _result(
                False,
                "device_canary_platform_invalid",
                player_start_allowed=False,
                device_canary_allowed=False,
            )
        if not isinstance(metadata, Mapping) or metadata.get("execution_trusted") is not True:
            return _result(
                False,
                "release_package_not_execution_trusted",
                player_start_allowed=False,
                device_canary_allowed=False,
            )
        if metadata.get("signature_scope") != "production_release":
            return _result(
                False,
                "release_package_scope_invalid",
                player_start_allowed=False,
                device_canary_allowed=False,
            )
        error = self._current_error()
        if error:
            return _result(
                False,
                error,
                player_start_allowed=False,
                device_canary_allowed=False,
            )
        key_id = metadata.get("signature_key_id")
        if not any(
            key.get("key_id") == key_id for key in self.trusted_release_keys()
        ):
            return _result(
                False,
                "release_package_scope_invalid",
                player_start_allowed=False,
                device_canary_allowed=False,
            )
        if self._canary_approvals.get("approval_status") != "approved":
            return _result(
                False,
                "device_canary_not_approved",
                player_start_allowed=False,
                device_canary_allowed=False,
            )
        identity_keys = (
            "package_id",
            "package_version",
            "archive_sha256",
            "manifest_sha256",
            "policy_ir_sha256",
            "deck_manifest_sha256",
        )
        record = next(
            (
                approval
                for approval in self._canary_approvals.get("records", [])
                if type(approval) is dict
                and approval.get("status") == "active"
                and approval.get("platform") == platform
                and approval.get("signature_key_id") == key_id
                and all(
                    approval.get(field) == metadata.get(field)
                    for field in identity_keys
                )
            ),
            None,
        )
        if record is None:
            return _result(
                False,
                "device_canary_not_approved",
                player_start_allowed=False,
                device_canary_allowed=False,
            )
        if record.get("prompt_coverage") != list(REQUIRED_PROMPT_COVERAGE):
            return _result(
                False,
                "release_prompt_coverage_incomplete",
                player_start_allowed=False,
                device_canary_allowed=False,
            )
        if not self._has_approved_prompt_conformance(
            metadata,
            record.get("prompt_conformance_report_sha256"),
            platform,
        ):
            return _result(
                False,
                "release_prompt_conformance_unapproved",
                player_start_allowed=False,
                device_canary_allowed=False,
            )
        return _result(
            True,
            "",
            player_start_allowed=False,
            device_canary_allowed=True,
            approval=dict(record),
            authority_source="fixed_product_device_canary_approval",
        )

    def evaluate_installed_package(
        self, metadata: Mapping[str, object]
    ) -> dict[str, object]:
        """Close player-start authority from fixed product approval only.

        ``evaluate_package`` intentionally stops at package-level approval. This
        method derives all prompt, device, rollback, and A5 inputs from the exact
        matching approval record, so a catalog caller cannot inject them.
        """

        package = self.evaluate_package(metadata)
        if package.get("accepted") is not True:
            return package
        approval = package.get("approval")
        if not isinstance(approval, Mapping):
            return _result(
                False, "release_package_not_approved", player_start_allowed=False
            )
        required_platforms = self._release_target_platforms()
        reports = approval.get("device_report_sha256_by_platform")
        if (
            not required_platforms
            or type(reports) is not dict
            or set(reports) != set(required_platforms)
        ):
            return _result(
                False, "release_device_evidence_incomplete", player_start_allowed=False
            )
        candidate = {
            "package_metadata": dict(metadata),
            "package_execution_trusted": True,
            "package_scope": "production_release",
            "exact_deck_mapping": True,
            "prompt_coverage": list(REQUIRED_PROMPT_COVERAGE),
            "prompt_conformance_report_sha256": approval.get(
                "prompt_conformance_report_sha256"
            ),
            "offline_full_match_by_platform": self._offline_requirements(),
            "rollback_verified": True,
            "a5_evidence_approved": True,
            "device_report_sha256_by_platform": dict(reports),
            "rollback_report_sha256": approval.get("rollback_report_sha256"),
            "a5_evidence_sha256": approval.get("a5_evidence_sha256"),
        }
        released = self.evaluate_release_candidate(candidate)
        if released.get("accepted") is not True:
            return released
        return {
            **released,
            "approval": dict(approval),
            "authority_source": "fixed_product_release_approval",
        }

    def evaluate_release_candidate(self, candidate: Mapping[str, object]) -> dict[str, object]:
        if not isinstance(candidate, Mapping):
            return _result(False, "release_package_not_execution_trusted", player_start_allowed=False)
        error = self._current_error()
        if error:
            return _result(False, error, player_start_allowed=False)
        if candidate.get("package_execution_trusted") is not True:
            return _result(False, "release_package_not_execution_trusted", player_start_allowed=False)
        if candidate.get("package_scope") != "production_release":
            return _result(False, "release_package_scope_invalid", player_start_allowed=False)
        if candidate.get("exact_deck_mapping") is not True:
            return _result(False, "release_package_not_execution_trusted", player_start_allowed=False)
        coverage = candidate.get("prompt_coverage")
        if type(coverage) is not list or tuple(coverage) != REQUIRED_PROMPT_COVERAGE:
            return _result(False, "release_prompt_coverage_incomplete", player_start_allowed=False)
        required_platforms = self._release_target_platforms()
        expected_offline = self._offline_requirements()
        offline_by_platform = candidate.get("offline_full_match_by_platform")
        if (
            not required_platforms
            or set(expected_offline) != set(required_platforms)
            or type(offline_by_platform) is not dict
            or len(offline_by_platform) != len(required_platforms)
            or set(offline_by_platform) != set(required_platforms)
            or any(
                type(offline_by_platform[platform]) is not bool
                or offline_by_platform[platform] is not expected_offline[platform]
                for platform in required_platforms
            )
        ):
            return _result(False, "release_device_evidence_incomplete", player_start_allowed=False)
        if candidate.get("rollback_verified") is not True:
            return _result(False, "release_rollback_invalid", player_start_allowed=False)
        if candidate.get("a5_evidence_approved") is not True:
            return _result(False, "release_a5_unapproved", player_start_allowed=False)
        package_metadata = candidate.get("package_metadata")
        if not isinstance(package_metadata, Mapping):
            return _result(False, "release_package_not_execution_trusted", player_start_allowed=False)
        package = self.evaluate_package(package_metadata)
        if package.get("accepted") is not True:
            return _result(False, str(package.get("error_code", "release_package_not_approved")), player_start_allowed=False)
        approval = package.get("approval")
        if not isinstance(approval, Mapping):
            return _result(False, "release_package_not_approved", player_start_allowed=False)
        if (
            candidate.get("prompt_conformance_report_sha256")
            != approval.get("prompt_conformance_report_sha256")
        ):
            return _result(False, "release_prompt_conformance_unapproved", player_start_allowed=False)
        candidate_reports = candidate.get("device_report_sha256_by_platform")
        approval_reports = approval.get("device_report_sha256_by_platform")
        if (
            type(candidate_reports) is not dict
            or type(approval_reports) is not dict
            or len(candidate_reports) != len(required_platforms)
            or len(approval_reports) != len(required_platforms)
            or set(candidate_reports) != set(required_platforms)
            or set(approval_reports) != set(required_platforms)
            or any(candidate_reports[platform] != approval_reports[platform] for platform in required_platforms)
        ):
            return _result(False, "release_device_evidence_incomplete", player_start_allowed=False)
        if candidate.get("rollback_report_sha256") != approval.get("rollback_report_sha256"):
            return _result(False, "release_rollback_invalid", player_start_allowed=False)
        if candidate.get("a5_evidence_sha256") != approval.get("a5_evidence_sha256"):
            return _result(False, "release_a5_unapproved", player_start_allowed=False)
        return _result(True, "", player_start_allowed=True)

    def evaluate_device_report(self, report: Mapping[str, object]) -> dict[str, object]:
        return evaluate_device_report(self._device, report)


__all__ = ["AuthorStrategyReleaseGate", "evaluate_device_report"]
