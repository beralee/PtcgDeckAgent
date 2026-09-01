from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


PROFILE_ID = "ptcgdap-author-strategy-release-as-wp6-v1"
BUNDLE_ID = PROFILE_ID
PARENT_LIVE_SEAM_BUNDLE = "5CDC360999A23A2CADCAC6E7FA8D81549566DFABE37B2DB4F813C0C5189C3E16"
AS_WP5_MANIFEST = "4E2693E9143C3326C131DE9C64917632129408870C1AF897199DBA8841FA4428"
PACKAGE_BUNDLE = "B416F2CBA2795B62126B6EF7B5F07A9000E84D5FA1DF62C1753CADC9E82E106B"
MATCH_HOST_BUNDLE = "4BD207E9F9200E5AF9E2206A13EAF506382B6BA42BDEE3F0FEB5CA872885DBB9"
SOURCE_LOCK = "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"
TRUST_STORE_PATH = "data/ptcgdap/author_strategy_release_trust_store.json"
APPROVALS_PATH = "data/ptcgdap/author_strategy_release_approvals.json"
DEVICE_CANARY_APPROVALS_PATH = "data/ptcgdap/author_strategy_device_canary_approvals.json"
PROMPT_CONFORMANCE_APPROVALS_PATH = "data/ptcgdap/author_strategy_prompt_conformance_approvals.json"
DEVICE_PROFILE_PATH = "data/ptcgdap/author_strategy_device_acceptance_profile.json"
CURRENT_RELEASE_TARGETS = ("windows",)
DEFERRED_TARGETS = ("android",)
PRODUCT_RELEASE_KEY_ID = "ptcgdap.product.release.ed25519.v1"
PRODUCT_RELEASE_PUBLIC_KEY_BASE64 = (
    "vdpuqrowRq72ecivA+cpZfvg7deqCpX9Gq9KS292DAA="
)


def digest(value: object) -> str:
    return hashlib.sha256(canonical_json_v1_bytes(value)).hexdigest().upper()


def schema() -> dict[str, object]:
    sha = {"type": "string", "pattern": "^[0-9A-F]{64}$"}
    return {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "https://ptcgdap.local/contracts/author_strategy_release.schema.json",
        "title": "PTCGDAP author strategy release and device evidence",
        "$defs": {
            "sha256": sha,
            "measurement_limits": {
                "type": "object",
                "additionalProperties": False,
                "required": [
                    "max_cold_start_msec",
                    "max_catalog_scan_msec",
                    "max_match_load_msec",
                    "max_decision_p95_msec",
                    "max_peak_memory_mib",
                    "max_package_mib",
                ],
                "properties": {
                    "max_cold_start_msec": {"type": "integer", "minimum": 1},
                    "max_catalog_scan_msec": {"type": "integer", "minimum": 1},
                    "max_match_load_msec": {"type": "integer", "minimum": 1},
                    "max_decision_p95_msec": {"type": "integer", "minimum": 1},
                    "max_peak_memory_mib": {"type": "integer", "minimum": 1},
                    "max_package_mib": {"type": "integer", "minimum": 1},
                    "max_thermal_status": {"type": ["integer", "null"], "minimum": 0},
                    "max_battery_drain_percent_per_hour": {"type": ["integer", "null"], "minimum": 0, "maximum": 100},
                },
            },
            "nonnegative_safe_integer": {
                "type": "integer",
                "minimum": 0,
                "maximum": 9_007_199_254_740_991,
            },
        },
        "oneOf": [
            {
                "type": "object",
                "additionalProperties": False,
                "required": ["document_type", "schema_version", "store_id", "approval_status", "keys"],
                "properties": {
                    "document_type": {"const": "author_strategy_release_trust_store_v1"},
                    "schema_version": {"const": 1},
                    "store_id": {"const": "ptcgdap-product-release-trust-v1"},
                    "approval_status": {"enum": ["unprovisioned", "approved", "revoked"]},
                    "keys": {
                        "type": "array",
                        "maxItems": 8,
                        "items": {
                            "type": "object",
                            "additionalProperties": False,
                            "required": ["key_id", "algorithm", "public_key_base64", "scope", "execution_trusted", "status"],
                            "properties": {
                                "key_id": {"type": "string", "pattern": "^[a-z0-9][a-z0-9._-]{0,95}$"},
                                "algorithm": {"const": "ed25519"},
                                "public_key_base64": {"type": "string", "pattern": "^[A-Za-z0-9+/]{43}=$"},
                                "scope": {"const": "production_release"},
                                "execution_trusted": {"const": True},
                                "status": {"enum": ["active", "revoked"]},
                            },
                        },
                    },
                },
            },
            {
                "type": "object",
                "additionalProperties": False,
                "required": ["document_type", "schema_version", "approval_status", "records"],
                "properties": {
                    "document_type": {"const": "author_strategy_prompt_conformance_approvals_v1"},
                    "schema_version": {"const": 1},
                    "approval_status": {"enum": ["unprovisioned", "approved", "retired"]},
                    "records": {
                        "type": "array",
                        "maxItems": 128,
                        "items": {
                            "type": "object",
                            "additionalProperties": False,
                            "required": [
                                "package_id", "package_version", "archive_sha256", "manifest_sha256",
                                "policy_ir_sha256", "deck_manifest_sha256", "platform",
                                "prompt_conformance_report_sha256", "official_source_lock_sha256",
                                "evidence_class", "prompt_coverage", "status",
                            ],
                            "properties": {
                                "package_id": {"type": "string", "minLength": 1, "maxLength": 128},
                                "package_version": {"type": "string", "minLength": 1, "maxLength": 64},
                                "archive_sha256": sha,
                                "manifest_sha256": sha,
                                "policy_ir_sha256": sha,
                                "deck_manifest_sha256": sha,
                                "platform": {"const": "windows"},
                                "prompt_conformance_report_sha256": sha,
                                "official_source_lock_sha256": {"const": SOURCE_LOCK},
                                "evidence_class": {"const": "official_cabt_w0_w7_package_conformance"},
                                "prompt_coverage": {"const": ["W0", "W1", "W2", "W3", "W4", "W5", "W6", "W7"]},
                                "status": {"enum": ["active", "retired"]},
                            },
                        },
                    },
                },
            },
            {
                "type": "object",
                "additionalProperties": False,
                "required": ["document_type", "schema_version", "approval_status", "records"],
                "properties": {
                    "document_type": {"const": "author_strategy_device_canary_approvals_v1"},
                    "schema_version": {"const": 1},
                    "approval_status": {"enum": ["unprovisioned", "approved", "retired"]},
                    "records": {
                        "type": "array",
                        "maxItems": 8,
                        "items": {
                            "type": "object",
                            "additionalProperties": False,
                            "required": [
                                "package_id", "package_version", "archive_sha256", "manifest_sha256",
                                "policy_ir_sha256", "deck_manifest_sha256", "signature_key_id",
                                "platform", "prompt_coverage", "prompt_conformance_report_sha256", "status",
                            ],
                            "properties": {
                                "package_id": {"type": "string", "minLength": 1, "maxLength": 128},
                                "package_version": {"type": "string", "minLength": 1, "maxLength": 64},
                                "archive_sha256": sha,
                                "manifest_sha256": sha,
                                "policy_ir_sha256": sha,
                                "deck_manifest_sha256": sha,
                                "signature_key_id": {"type": "string", "pattern": "^[a-z0-9][a-z0-9._-]{0,95}$"},
                                "platform": {"const": "windows"},
                                "prompt_coverage": {"const": ["W0", "W1", "W2", "W3", "W4", "W5", "W6", "W7"]},
                                "prompt_conformance_report_sha256": sha,
                                "status": {"enum": ["active", "retired"]},
                            },
                        },
                    },
                },
            },
            {
                "type": "object",
                "additionalProperties": False,
                "required": ["document_type", "schema_version", "approval_status", "records"],
                "properties": {
                    "document_type": {"const": "author_strategy_release_approvals_v1"},
                    "schema_version": {"const": 1},
                    "approval_status": {"enum": ["unprovisioned", "approved", "retired"]},
                    "records": {
                        "type": "array",
                        "maxItems": 128,
                        "items": {
                            "type": "object",
                            "additionalProperties": False,
                            "required": [
                                "package_id", "package_version", "archive_sha256", "manifest_sha256",
                                "policy_ir_sha256", "deck_manifest_sha256", "prompt_coverage",
                                "prompt_conformance_report_sha256",
                                "device_report_sha256_by_platform",
                                "rollback_report_sha256", "a5_evidence_sha256",
                            ],
                            "properties": {
                                "package_id": {"type": "string", "minLength": 1, "maxLength": 128},
                                "package_version": {"type": "string", "minLength": 1, "maxLength": 64},
                                "archive_sha256": sha,
                                "manifest_sha256": sha,
                                "policy_ir_sha256": sha,
                                "deck_manifest_sha256": sha,
                                "prompt_coverage": {"const": ["W0", "W1", "W2", "W3", "W4", "W5", "W6", "W7"]},
                                "prompt_conformance_report_sha256": sha,
                                "device_report_sha256_by_platform": {
                                    "type": "object",
                                    "additionalProperties": False,
                                    "required": ["windows"],
                                    "properties": {"windows": sha},
                                },
                                "rollback_report_sha256": sha,
                                "a5_evidence_sha256": sha,
                            },
                        },
                    },
                },
            },
            {
                "type": "object",
                "additionalProperties": False,
                "required": [
                    "document_type", "schema_version", "profile_id", "approval_status",
                    "formal_a5_eligible", "platforms", "measurement_method",
                ],
                "properties": {
                    "document_type": {"const": "author_strategy_device_acceptance_profile_v1"},
                    "schema_version": {"const": 1},
                    "profile_id": {"const": "ptcgdap-device-acceptance-candidate-v1"},
                    "approval_status": {"enum": ["proposed", "approved", "retired"]},
                    "formal_a5_eligible": {"type": "boolean"},
                    "platforms": {
                        "type": "object",
                        "additionalProperties": False,
                        "required": ["windows"],
                        "properties": {
                            "windows": {"$ref": "#/$defs/measurement_limits"},
                        },
                    },
                    "measurement_method": {
                        "type": "object",
                        "additionalProperties": False,
                        "required": ["full_match_required", "airplane_or_os_block_required", "cold_start_samples", "decision_samples_minimum", "rollback_required"],
                        "properties": {
                            "full_match_required": {"const": True},
                            "airplane_or_os_block_required": {"const": False},
                            "cold_start_samples": {"type": "integer", "minimum": 1},
                            "decision_samples_minimum": {"type": "integer", "minimum": 1},
                            "rollback_required": {"const": True},
                        },
                    },
                },
            },
            {
                "type": "object",
                "additionalProperties": False,
                "required": [
                    "document_type", "schema_version", "profile_id", "platform", "architecture",
                    "offline", "runtime", "samples", "measurements", "rollback", "evidence",
                ],
                "properties": {
                    "document_type": {"const": "author_strategy_device_report_v1"},
                    "schema_version": {"const": 1},
                    "profile_id": {"const": "ptcgdap-device-acceptance-candidate-v1"},
                    "platform": {"const": "windows"},
                    "architecture": {"const": "x86_64"},
                    "offline": {
                        "type": "object",
                        "additionalProperties": False,
                        "required": ["network_blocked", "complete_match_finished", "remote_inference_attempts", "dynamic_download_attempts"],
                        "properties": {
                            "network_blocked": {"type": "boolean"},
                            "complete_match_finished": {"type": "boolean"},
                            "remote_inference_attempts": {"$ref": "#/$defs/nonnegative_safe_integer"},
                            "dynamic_download_attempts": {"$ref": "#/$defs/nonnegative_safe_integer"},
                        },
                    },
                    "runtime": {
                        "type": "object",
                        "additionalProperties": False,
                        "required": ["system_python_required", "sidecar_processes", "external_compute_required"],
                        "properties": {
                            "system_python_required": {"type": "boolean"},
                            "sidecar_processes": {"type": "array", "maxItems": 0},
                            "external_compute_required": {"type": "boolean"},
                        },
                    },
                    "samples": {
                        "type": "object",
                        "additionalProperties": False,
                        "required": ["cold_start_msec", "decision_msec"],
                        "properties": {
                            "cold_start_msec": {
                                "type": "array", "minItems": 1, "maxItems": 1_000,
                                "items": {"$ref": "#/$defs/nonnegative_safe_integer"},
                            },
                            "decision_msec": {
                                "type": "array", "minItems": 1, "maxItems": 1_000_000,
                                "items": {"$ref": "#/$defs/nonnegative_safe_integer"},
                            },
                        },
                    },
                    "measurements": {
                        "type": "object",
                        "additionalProperties": False,
                        "required": [
                            "cold_start_msec", "catalog_scan_msec", "match_load_msec",
                            "decision_p95_msec", "peak_memory_mib", "package_mib",
                            "thermal_status_max", "battery_drain_percent_per_hour",
                        ],
                        "properties": {
                            "cold_start_msec": {"$ref": "#/$defs/nonnegative_safe_integer"},
                            "catalog_scan_msec": {"$ref": "#/$defs/nonnegative_safe_integer"},
                            "match_load_msec": {"$ref": "#/$defs/nonnegative_safe_integer"},
                            "decision_p95_msec": {"$ref": "#/$defs/nonnegative_safe_integer"},
                            "peak_memory_mib": {"$ref": "#/$defs/nonnegative_safe_integer"},
                            "package_mib": {"$ref": "#/$defs/nonnegative_safe_integer"},
                            "thermal_status_max": {"type": "null"},
                            "battery_drain_percent_per_hour": {"type": "null"},
                        },
                    },
                    "rollback": {
                        "type": "object",
                        "additionalProperties": False,
                        "required": ["mode_disabled", "user_packages_preserved"],
                        "properties": {
                            "mode_disabled": {"type": "boolean"},
                            "user_packages_preserved": {"type": "boolean"},
                        },
                    },
                    "evidence": {
                        "type": "object",
                        "additionalProperties": False,
                        "required": [
                            "profile_canonical_sha256", "export_manifest_sha256", "network_audit_sha256",
                            "process_audit_sha256", "full_match_audit_sha256", "rollback_report_sha256",
                        ],
                        "properties": {
                            "profile_canonical_sha256": {"$ref": "#/$defs/sha256"},
                            "export_manifest_sha256": {"$ref": "#/$defs/sha256"},
                            "network_audit_sha256": {"$ref": "#/$defs/sha256"},
                            "process_audit_sha256": {"$ref": "#/$defs/sha256"},
                            "full_match_audit_sha256": {"$ref": "#/$defs/sha256"},
                            "rollback_report_sha256": {"$ref": "#/$defs/sha256"},
                        },
                    },
                },
            },
            {
                "type": "object",
                "additionalProperties": True,
                "required": ["document_type", "schema_version"],
                "properties": {
                    "document_type": {"const": "author_strategy_export_inventory_report_v1"},
                    "schema_version": {"const": 1},
                },
            },
            {
                "type": "object",
                "additionalProperties": False,
                "required": [
                    "document_type", "schema_version", "generated_at", "formal_device_report",
                    "a5_claimed", "profile", "export", "host", "cold_start_probe", "measured",
                    "unmeasured_gates", "limitations",
                ],
                "properties": {
                    "document_type": {"const": "author_strategy_windows_provisional_probe_v1"},
                    "schema_version": {"const": 1},
                    "generated_at": {"type": "string", "minLength": 20, "maxLength": 64},
                    "formal_device_report": {"const": False},
                    "a5_claimed": {"const": False},
                    "profile": {
                        "type": "object",
                        "additionalProperties": False,
                        "required": ["path", "profile_id", "approval_status", "formal_a5_eligible", "raw_sha256", "canonical_sha256"],
                        "properties": {
                            "path": {"const": DEVICE_PROFILE_PATH},
                            "profile_id": {"const": "ptcgdap-device-acceptance-candidate-v1"},
                            "approval_status": {"enum": ["proposed", "approved", "retired"]},
                            "formal_a5_eligible": {"type": "boolean"},
                            "raw_sha256": {"$ref": "#/$defs/sha256"},
                            "canonical_sha256": {"$ref": "#/$defs/sha256"},
                        },
                    },
                    "export": {
                        "type": "object",
                        "additionalProperties": False,
                        "required": ["manifest_path", "manifest_sha256", "output_directory", "verified_outputs"],
                        "properties": {
                            "manifest_path": {"type": "string", "minLength": 1, "maxLength": 32_768},
                            "manifest_sha256": {"$ref": "#/$defs/sha256"},
                            "output_directory": {"type": "string", "minLength": 1, "maxLength": 32_768},
                            "verified_outputs": {
                                "type": "array",
                                "minItems": 1,
                                "maxItems": 32,
                                "items": {
                                    "type": "object",
                                    "additionalProperties": False,
                                    "required": ["kind", "platform", "path", "bytes", "sha256"],
                                    "properties": {
                                        "kind": {"enum": ["resource_zip", "pck", "pck_runtime_probe", "executable", "inventory"]},
                                        "platform": {"const": "windows"},
                                        "path": {"type": "string", "minLength": 1, "maxLength": 32_768},
                                        "bytes": {"$ref": "#/$defs/nonnegative_safe_integer"},
                                        "sha256": {"$ref": "#/$defs/sha256"},
                                    },
                                },
                            },
                        },
                    },
                    "host": {
                        "type": "object",
                        "additionalProperties": False,
                        "required": ["os_caption", "os_version", "os_build", "architecture", "processor_name", "logical_processor_count", "total_physical_memory_mib"],
                        "properties": {
                            "os_caption": {"type": "string", "minLength": 1, "maxLength": 512},
                            "os_version": {"type": "string", "minLength": 1, "maxLength": 128},
                            "os_build": {"type": "string", "minLength": 1, "maxLength": 128},
                            "architecture": {"const": "x86_64"},
                            "processor_name": {"type": "string", "minLength": 1, "maxLength": 512},
                            "logical_processor_count": {"type": "integer", "minimum": 1, "maximum": 4_096},
                            "total_physical_memory_mib": {"type": "integer", "minimum": 1, "maximum": 9_007_199_254_740_991},
                        },
                    },
                    "cold_start_probe": {
                        "type": "object",
                        "additionalProperties": False,
                        "required": ["method", "required_samples", "sample_count", "samples", "max_elapsed_msec"],
                        "properties": {
                            "method": {"const": "wall_clock_exported_executable_headless_quit_after_one_frame"},
                            "required_samples": {"const": 3},
                            "sample_count": {"const": 3},
                            "samples": {
                                "type": "array",
                                "minItems": 3,
                                "maxItems": 3,
                                "items": {
                                    "type": "object",
                                    "additionalProperties": False,
                                    "required": ["index", "elapsed_msec", "exit_code", "peak_working_set_mib", "stdout_sha256", "stderr_sha256"],
                                    "properties": {
                                        "index": {"type": "integer", "minimum": 1, "maximum": 3},
                                        "elapsed_msec": {"$ref": "#/$defs/nonnegative_safe_integer"},
                                        "exit_code": {"const": 0},
                                        "peak_working_set_mib": {"$ref": "#/$defs/nonnegative_safe_integer"},
                                        "stdout_sha256": {"$ref": "#/$defs/sha256"},
                                        "stderr_sha256": {"$ref": "#/$defs/sha256"},
                                    },
                                },
                            },
                            "max_elapsed_msec": {"$ref": "#/$defs/nonnegative_safe_integer"},
                        },
                    },
                    "measured": {
                        "type": "object",
                        "additionalProperties": False,
                        "required": ["package_basis", "package_mib"],
                        "properties": {
                            "package_basis": {"const": "standalone_executable"},
                            "package_mib": {"$ref": "#/$defs/nonnegative_safe_integer"},
                        },
                    },
                    "unmeasured_gates": {
                        "const": [
                            "catalog_scan_msec", "match_load_msec", "decision_samples_minimum",
                            "network_blocked", "runtime_process_isolation", "complete_match_finished", "rollback",
                        ]
                    },
                    "limitations": {
                        "type": "array",
                        "minItems": 1,
                        "maxItems": 16,
                        "items": {"type": "string", "minLength": 1, "maxLength": 2_048},
                    },
                },
            },
        ],
    }


def trust_store() -> dict[str, object]:
    return {
        "document_type": "author_strategy_release_trust_store_v1",
        "schema_version": 1,
        "store_id": "ptcgdap-product-release-trust-v1",
        "approval_status": "approved",
        "keys": [{
            "key_id": PRODUCT_RELEASE_KEY_ID,
            "algorithm": "ed25519",
            "public_key_base64": PRODUCT_RELEASE_PUBLIC_KEY_BASE64,
            "scope": "production_release",
            "execution_trusted": True,
            "status": "active",
        }],
    }


def release_approvals() -> dict[str, object]:
    return {
        "document_type": "author_strategy_release_approvals_v1",
        "schema_version": 1,
        "approval_status": "unprovisioned",
        "records": [],
    }


def device_canary_approvals() -> dict[str, object]:
    return {
        "document_type": "author_strategy_device_canary_approvals_v1",
        "schema_version": 1,
        "approval_status": "unprovisioned",
        "records": [],
    }


def prompt_conformance_approvals() -> dict[str, object]:
    return {
        "document_type": "author_strategy_prompt_conformance_approvals_v1",
        "schema_version": 1,
        "approval_status": "unprovisioned",
        "records": [],
    }


def device_profile() -> dict[str, object]:
    shared = {
        "max_decision_p95_msec": 250,
        "max_peak_memory_mib": 1024,
        "max_package_mib": 750,
    }
    return {
        "document_type": "author_strategy_device_acceptance_profile_v1",
        "schema_version": 1,
        "profile_id": "ptcgdap-device-acceptance-candidate-v1",
        "approval_status": "approved",
        "formal_a5_eligible": False,
        "platforms": {
            "windows": {
                "max_cold_start_msec": 10000,
                "max_catalog_scan_msec": 1000,
                "max_match_load_msec": 6000,
                **shared,
                "max_thermal_status": None,
                "max_battery_drain_percent_per_hour": None,
            },
        },
        "measurement_method": {
            "full_match_required": True,
            "airplane_or_os_block_required": False,
            "cold_start_samples": 3,
            "decision_samples_minimum": 100,
            "rollback_required": True,
        },
    }


def profile() -> dict[str, object]:
    return {
        "schema_version": 1,
        "profile_id": PROFILE_ID,
        "execution_location": "device_local",
        "supported_targets": [{"platform": "windows", "architecture": "x86_64"}],
        "deferred_targets": [{
            "platform": DEFERRED_TARGETS[0],
            "architecture": "arm64-v8a",
            "reason": "D041: Android requires a later independent adapter and A5 evidence package",
        }],
        "trust_store": {
            "path": TRUST_STORE_PATH,
            "caller_overrides": False,
            "required_algorithm": "ed25519",
            "required_scope": "production_release",
            "test_fixture_execution_allowed": False,
        },
        "device_acceptance": {
            "profile_path": DEVICE_PROFILE_PATH,
            "formal_evidence_requires_approved_profile": True,
            "candidate_thresholds_are_claims": True,
        },
        "release_approvals": {
            "path": APPROVALS_PATH,
            "caller_overrides": False,
            "exact_package_identity_required": True,
            "full_prompt_and_evidence_hashes_required": True,
        },
        "device_canary_approvals": {
            "path": DEVICE_CANARY_APPROVALS_PATH,
            "caller_overrides": False,
            "activation_arg": "--ptcgdap-production-device-canary",
            "exact_package_identity_required": True,
            "ordinary_player_start": False,
            "future_device_evidence_hashes_required": False,
        },
        "prompt_conformance_approvals": {
            "path": PROMPT_CONFORMANCE_APPROVALS_PATH,
            "caller_overrides": False,
            "exact_package_identity_required": True,
            "official_source_lock_sha256": SOURCE_LOCK,
            "required_evidence_class": "official_cabt_w0_w7_package_conformance",
        },
        "required_export_paths": [
            "contracts/ptcgdap/author_strategy_package_profile.json",
            "contracts/ptcgdap/author_strategy_match_host_profile.json",
            "contracts/ptcgdap/author_strategy_live_seam_profile.json",
            "contracts/ptcgdap/author_strategy_release_profile.json",
            "contracts/ptcgdap/local_uid_public_context.schema.json",
            "contracts/ptcgdap/local_uid_public_context_profile.json",
            "contracts/ptcgdap/local_uid_public_context_conformance_vectors.json",
            "contracts/ptcgdap/local_uid_public_context_bundle.json",
            TRUST_STORE_PATH,
            APPROVALS_PATH,
            DEVICE_CANARY_APPROVALS_PATH,
            PROMPT_CONFORMANCE_APPROVALS_PATH,
            DEVICE_PROFILE_PATH,
            "data/ptcgdap/author_strategy_packages/ptcgdap-author-strategy-release-candidate.ptcgai",
            "scripts/ai/ptcgdap/packages/AuthorStrategyPackageLoader.gd",
            "scripts/ai/ptcgdap/packages/AuthorStrategyReleaseGate.gd",
            "scripts/ai/ptcgdap/host/godot/AuthorStrategyWindowsDeviceCanaryGate.gd",
            "scripts/ai/ptcgdap/host/godot/AuthorStrategyWindowsExecutionGate.gd",
            "scripts/ai/ptcgdap/public/PublicDeckAdapter.gd",
            "scripts/ai/ptcgdap/host/godot/AuthorStrategyShadowPrompt.gd",
            "scripts/ai/ptcgdap/host/godot/AuthorStrategyLivePromptSource.gd",
            "scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorMatchHost.gd",
            "scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorLiveSeam.gd",
        ],
        "runtime_prohibitions": {
            "system_python": True,
            "sidecar": True,
            "remote_inference": True,
            "dynamic_model_download": True,
            "external_compute": True,
            "classic_raw_state_fallback": True,
        },
        "release_prerequisites": {
            "production_trust_approved": True,
            "package_execution_trusted": True,
            "exact_deck_mapping": True,
            "prompt_coverage": ["W0", "W1", "W2", "W3", "W4", "W5", "W6", "W7"],
            "prompt_conformance_report_hash_required": True,
            "required_platforms": list(CURRENT_RELEASE_TARGETS),
            "offline_full_match_by_platform": {"windows": False},
            "device_profile_approved": True,
            "rollback_verified": True,
            "a5_evidence_approved": True,
        },
        "stable_error_codes": [
            "",
            "release_contract_invalid",
            "release_trust_unprovisioned",
            "release_trust_revoked",
            "release_package_not_execution_trusted",
            "release_package_scope_invalid",
            "release_package_not_approved",
            "device_canary_not_approved",
            "device_canary_platform_invalid",
            "device_canary_activation_invalid",
            "release_prompt_coverage_incomplete",
            "release_prompt_conformance_unapproved",
            "release_device_evidence_incomplete",
            "release_rollback_invalid",
            "release_a5_unapproved",
            "device_profile_not_approved",
            "device_report_invalid",
            "device_report_profile_mismatch",
            "device_sample_count_insufficient",
            "device_measurement_mismatch",
            "device_evidence_invalid",
            "device_network_not_blocked",
            "device_external_runtime_detected",
            "device_full_match_incomplete",
            "device_resource_limit_exceeded",
            "device_rollback_invalid",
            "export_inventory_archive_invalid",
            "export_inventory_missing",
        ],
        "current_release_state": {
            "production_ready": False,
            "player_start_gate": "BattleSetup remains disabled",
            "reason": "the product release trust root and Windows device profile are approved; exact package signing, W0-W7 conformance, device-canary, rollback, release approval, and A5 remain incomplete",
        },
        "parent_contracts": {
            "author_package_bundle_canonical_sha256": PACKAGE_BUNDLE,
            "author_match_host_bundle_canonical_sha256": MATCH_HOST_BUNDLE,
            "author_live_seam_bundle_canonical_sha256": PARENT_LIVE_SEAM_BUNDLE,
            "as_wp5_manifest_canonical_sha256": AS_WP5_MANIFEST,
            "source_lock_canonical_sha256": SOURCE_LOCK,
        },
    }


def vectors() -> dict[str, object]:
    return {
        "schema_version": 1,
        "profile_id": PROFILE_ID,
        "cases": [
            {"id": "approved-product-trust", "operation": "load_fixed_documents", "expected_error_code": "release_prompt_conformance_unapproved"},
            {"id": "test-key-non-promotion", "operation": "evaluate_test_fixture_package", "expected_error_code": "release_package_not_execution_trusted"},
            {"id": "unprovisioned-device-canary", "operation": "evaluate_device_canary_package", "expected_error_code": "release_trust_unprovisioned"},
            {"id": "bare-prompt-coverage-claim", "operation": "evaluate_production_package", "fault": "missing_prompt_conformance_approval", "expected_error_code": "release_prompt_conformance_unapproved"},
            {"id": "a5-ineligible-device-profile", "operation": "evaluate_good_device_report", "expected_error_code": "release_a5_unapproved"},
            {"id": "device-profile-mismatch", "operation": "evaluate_approved_profile_report", "fault": "profile_hash_mismatch", "expected_error_code": "device_report_profile_mismatch"},
            {"id": "device-samples-short", "operation": "evaluate_approved_profile_report", "fault": "decision_samples_short", "expected_error_code": "device_sample_count_insufficient"},
            {"id": "device-measurement-mismatch", "operation": "evaluate_approved_profile_report", "fault": "decision_p95_mismatch", "expected_error_code": "device_measurement_mismatch"},
            {"id": "device-evidence-invalid", "operation": "evaluate_approved_profile_report", "fault": "network_audit_hash_invalid", "expected_error_code": "device_evidence_invalid"},
            {"id": "network-not-blocked", "operation": "evaluate_approved_profile_report", "fault": "network_open", "expected_error_code": "device_network_not_blocked"},
            {"id": "external-python", "operation": "evaluate_approved_profile_report", "fault": "system_python_required", "expected_error_code": "device_external_runtime_detected"},
            {"id": "resource-limit", "operation": "evaluate_approved_profile_report", "fault": "decision_p95_exceeded", "expected_error_code": "device_resource_limit_exceeded"},
            {"id": "windows-only-release", "operation": "evaluate_release_candidate", "fault": "android_evidence_required_or_injected", "expected_error_code": "release_device_evidence_incomplete"},
            {"id": "inventory-missing", "operation": "inspect_export", "fault": "release_gate_missing", "expected_error_code": "export_inventory_missing"},
        ],
    }


def build_artifacts() -> dict[str, dict[str, object]]:
    documents = {
        "contracts/ptcgdap/author_strategy_release.schema.json": schema(),
        "contracts/ptcgdap/author_strategy_release_profile.json": profile(),
        "contracts/ptcgdap/author_strategy_release_conformance_vectors.json": vectors(),
        TRUST_STORE_PATH: trust_store(),
        APPROVALS_PATH: release_approvals(),
        DEVICE_CANARY_APPROVALS_PATH: device_canary_approvals(),
        PROMPT_CONFORMANCE_APPROVALS_PATH: prompt_conformance_approvals(),
        DEVICE_PROFILE_PATH: device_profile(),
    }
    bundle = {
        "schema_version": 1,
        "bundle_id": BUNDLE_ID,
        "profile_id": PROFILE_ID,
        "parent_author_live_seam_bundle_canonical_sha256": PARENT_LIVE_SEAM_BUNDLE,
        "as_wp5_manifest_canonical_sha256": AS_WP5_MANIFEST,
        "artifacts": [
            {"id": Path(path).stem, "path": path, "canonical_sha256": digest(document)}
            for path, document in documents.items()
        ],
    }
    return {
        **documents,
        "contracts/ptcgdap/author_strategy_release_bundle.json": bundle,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.write == args.check:
        raise SystemExit("choose exactly one of --write or --check")
    artifacts = build_artifacts()
    if args.write:
        for relative, document in artifacts.items():
            path = ROOT / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(json.dumps(document, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    else:
        for relative, expected in artifacts.items():
            if load_json_strict(ROOT / relative) != expected:
                raise SystemExit(f"contract drift: {relative}")
    print(f"bundle_canonical_sha256={digest(artifacts['contracts/ptcgdap/author_strategy_release_bundle.json'])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
