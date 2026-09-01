from __future__ import annotations

import copy
import hashlib
import json
import re
from typing import Any, Final, Mapping

from .ptcgai_model_actor import FRAME_WIDTH, MAX_OPTIONS, OPTION_WIDTH, TENSOR_PROFILE_ID


MODEL_MANIFEST_PATH: Final = "model/model_manifest.json"
MODEL_ARTIFACT_PATH: Final = "model/actor.ort"
MODEL_MAX_BYTES: Final = 8 * 1024 * 1024
MODEL_MODES: Final = frozenset({"rules_only", "rules_with_model"})
ALLOWED_ONNX_OPS: Final = (
    "Add",
    "ArgMax",
    "Cast",
    "Clip",
    "Constant",
    "Gather",
    "Greater",
    "MatMul",
    "Mul",
    "ReduceSum",
    "Reshape",
    "Where",
)
_HEX = re.compile(r"^[0-9A-F]{64}$")
_IDENTIFIER = re.compile(r"^[a-z0-9][a-z0-9._-]{0,127}$")


class ModelPackageError(ValueError):
    def __init__(self, code: str) -> None:
        self.code = code
        super().__init__(code)


def _raise(code: str) -> None:
    raise ModelPackageError(code)


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def canonical_bytes(value: Any) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        allow_nan=False,
        separators=(",", ":"),
        sort_keys=True,
    ).encode("utf-8")


def tensor_profile_document() -> dict[str, Any]:
    return {
        "profile_id": TENSOR_PROFILE_ID,
        "max_options": MAX_OPTIONS,
        "frame_width": FRAME_WIDTH,
        "option_width": OPTION_WIDTH,
        "inputs": [
            {"name": "frame_i32", "dtype": "int32", "shape": [1, FRAME_WIDTH]},
            {"name": "frame_presence_i32", "dtype": "int32", "shape": [1, FRAME_WIDTH]},
            {"name": "option_i32", "dtype": "int32", "shape": [1, MAX_OPTIONS, OPTION_WIDTH]},
            {"name": "option_presence_i32", "dtype": "int32", "shape": [1, MAX_OPTIONS, OPTION_WIDTH]},
            {"name": "option_mask_i32", "dtype": "int32", "shape": [1, MAX_OPTIONS]},
        ],
        "outputs": [
            {"name": "option_scores", "dtype": "int32", "shape": [1, MAX_OPTIONS]},
            {"name": "desired_count", "dtype": "int32", "shape": [1]},
        ],
        "option_order": "semantic_key_then_current_window_rebind",
        "unknown_uid_or_shape": "fail_closed",
        "hidden_fields": "forbidden",
    }


TENSOR_PROFILE_SHA256: Final = _sha(canonical_bytes(tensor_profile_document()))


def build_model_manifest(
    actor_bytes: bytes,
    *,
    model_id: str,
    cabt_contract_sha256: str,
    card_catalog_sha256: str,
    training_method: str = "bc_rl",
    source_run_id: str = "local-minimal",
) -> dict[str, Any]:
    if type(actor_bytes) is not bytes or not actor_bytes or len(actor_bytes) > MODEL_MAX_BYTES:
        _raise("model_resource_limit_exceeded")
    return {
        "document_type": "ptcgai_model_manifest_v1",
        "schema_version": 1,
        "model_id": model_id,
        "artifact": {
            "path": MODEL_ARTIFACT_PATH,
            "format": "ort",
            "sha256": _sha(actor_bytes),
            "bytes": len(actor_bytes),
            "external_data": False,
        },
        "runtime": {
            "engine": "onnxruntime",
            "minimum_version": "1.26.0",
            "execution_provider": "CPUExecutionProvider",
            "intra_op_threads": 1,
            "inter_op_threads": 1,
            "custom_ops": False,
            "remote_inference": False,
            "dynamic_download": False,
            "stateful": False,
        },
        "operator_profile": {
            "profile_id": "ptcgai-actor-ort-cpu-v1",
            "opset": 18,
            "allowed_ops": list(ALLOWED_ONNX_OPS),
        },
        "tensor_profile": tensor_profile_document(),
        "contract_hashes": {
            "cabt_contract_sha256": cabt_contract_sha256,
            "card_catalog_sha256": card_catalog_sha256,
            "tensor_profile_sha256": TENSOR_PROFILE_SHA256,
        },
        "resource_limits": {
            "max_artifact_bytes": MODEL_MAX_BYTES,
            "max_options": MAX_OPTIONS,
            "decision_timeout_ms": 25,
            "cpu_only": True,
        },
        "provenance": {
            "training_method": training_method,
            "source_run_id": source_run_id,
            "authoritative": False,
        },
    }


def validate_model_manifest(
    value: Any,
    actor_bytes: bytes,
    *,
    cabt_contract_sha256: str,
    card_catalog_sha256: str,
) -> dict[str, Any]:
    if type(value) is not dict or set(value) != {
        "document_type",
        "schema_version",
        "model_id",
        "artifact",
        "runtime",
        "operator_profile",
        "tensor_profile",
        "contract_hashes",
        "resource_limits",
        "provenance",
    }:
        _raise("model_manifest_invalid")
    if (
        value.get("document_type") != "ptcgai_model_manifest_v1"
        or value.get("schema_version") != 1
        or type(value.get("model_id")) is not str
        or _IDENTIFIER.fullmatch(value["model_id"]) is None
    ):
        _raise("model_manifest_invalid")
    artifact = value["artifact"]
    runtime = value["runtime"]
    operators = value["operator_profile"]
    contracts = value["contract_hashes"]
    resources = value["resource_limits"]
    provenance = value["provenance"]
    if (
        type(artifact) is not dict
        or set(artifact) != {"path", "format", "sha256", "bytes", "external_data"}
        or artifact.get("path") != MODEL_ARTIFACT_PATH
        or artifact.get("format") != "ort"
        or artifact.get("external_data") is not False
        or artifact.get("sha256") != _sha(actor_bytes)
        or artifact.get("bytes") != len(actor_bytes)
    ):
        _raise("model_artifact_hash_mismatch")
    if not actor_bytes or len(actor_bytes) > MODEL_MAX_BYTES:
        _raise("model_resource_limit_exceeded")
    if (
        type(runtime) is not dict
        or set(runtime) != {
            "engine",
            "minimum_version",
            "execution_provider",
            "intra_op_threads",
            "inter_op_threads",
            "custom_ops",
            "remote_inference",
            "dynamic_download",
            "stateful",
        }
        or runtime
        != {
            "engine": "onnxruntime",
            "minimum_version": "1.26.0",
            "execution_provider": "CPUExecutionProvider",
            "intra_op_threads": 1,
            "inter_op_threads": 1,
            "custom_ops": False,
            "remote_inference": False,
            "dynamic_download": False,
            "stateful": False,
        }
    ):
        _raise("model_runtime_profile_invalid")
    if (
        type(operators) is not dict
        or set(operators) != {"profile_id", "opset", "allowed_ops"}
        or operators.get("profile_id") != "ptcgai-actor-ort-cpu-v1"
        or operators.get("opset") != 18
        or operators.get("allowed_ops") != list(ALLOWED_ONNX_OPS)
    ):
        _raise("model_operator_profile_invalid")
    if value["tensor_profile"] != tensor_profile_document():
        _raise("model_tensor_profile_invalid")
    if (
        type(contracts) is not dict
        or set(contracts) != {
            "cabt_contract_sha256",
            "card_catalog_sha256",
            "tensor_profile_sha256",
        }
        or contracts.get("cabt_contract_sha256") != cabt_contract_sha256
        or contracts.get("card_catalog_sha256") != card_catalog_sha256
        or contracts.get("tensor_profile_sha256") != TENSOR_PROFILE_SHA256
    ):
        _raise("model_contract_hash_mismatch")
    if (
        type(resources) is not dict
        or resources
        != {
            "max_artifact_bytes": MODEL_MAX_BYTES,
            "max_options": MAX_OPTIONS,
            "decision_timeout_ms": 25,
            "cpu_only": True,
        }
    ):
        _raise("model_resource_profile_invalid")
    if (
        type(provenance) is not dict
        or set(provenance) != {"training_method", "source_run_id", "authoritative"}
        or provenance.get("training_method") not in {"bc", "rl", "bc_rl", "hybrid", "other"}
        or type(provenance.get("source_run_id")) is not str
        or not provenance["source_run_id"]
        or provenance.get("authoritative") is not False
    ):
        _raise("model_provenance_invalid")
    return copy.deepcopy(value)


def validate_v2_package_manifest(value: Any, members: Mapping[str, bytes]) -> dict[str, Any]:
    if type(value) is not dict or set(value) != {
        "document_type",
        "schema_version",
        "package_id",
        "package_version",
        "author",
        "strategy",
        "deck",
        "policy",
        "compatibility",
        "presentation",
    }:
        _raise("package_manifest_invalid")
    if value.get("document_type") != "strategy_package_v2" or value.get("schema_version") != 2:
        _raise("package_manifest_invalid")
    policy = value.get("policy")
    if type(policy) is not dict or set(policy) != {
        "policy_mode",
        "entry_kind",
        "ir_path",
        "adapter_path",
        "config_path",
        "weights_path",
        "model_manifest_path",
        "model_artifact_path",
    }:
        _raise("package_manifest_invalid")
    mode = policy.get("policy_mode")
    if (
        mode not in MODEL_MODES
        or policy.get("entry_kind") != "restricted_policy_ir_v1"
        or policy.get("ir_path") != "policy/policy_ir.json"
        or policy.get("adapter_path") != "policy/adapter.json"
        or policy.get("config_path") != "policy/config.json"
        or policy.get("weights_path") is not None
    ):
        _raise("package_policy_unsupported")
    has_manifest = MODEL_MANIFEST_PATH in members
    has_actor = MODEL_ARTIFACT_PATH in members
    if mode == "rules_only":
        if (
            policy.get("model_manifest_path") is not None
            or policy.get("model_artifact_path") is not None
            or has_manifest
            or has_actor
        ):
            _raise("package_model_relation_invalid")
    else:
        if (
            policy.get("model_manifest_path") != MODEL_MANIFEST_PATH
            or policy.get("model_artifact_path") != MODEL_ARTIFACT_PATH
            or not has_manifest
            or not has_actor
        ):
            _raise("package_model_relation_invalid")
    for identity in (value.get("package_id"), value.get("package_version")):
        if type(identity) is not str or not identity:
            _raise("package_manifest_invalid")
    return copy.deepcopy(value)


def load_model_manifest_bytes(
    value: bytes,
    actor_bytes: bytes,
    *,
    cabt_contract_sha256: str,
    card_catalog_sha256: str,
) -> dict[str, Any]:
    try:
        document = json.loads(value.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError):
        _raise("model_manifest_invalid")
    if canonical_bytes(document) != value:
        _raise("model_manifest_not_canonical")
    return validate_model_manifest(
        document,
        actor_bytes,
        cabt_contract_sha256=cabt_contract_sha256,
        card_catalog_sha256=card_catalog_sha256,
    )


__all__ = [
    "ALLOWED_ONNX_OPS",
    "MODEL_ARTIFACT_PATH",
    "MODEL_MANIFEST_PATH",
    "MODEL_MAX_BYTES",
    "ModelPackageError",
    "TENSOR_PROFILE_SHA256",
    "build_model_manifest",
    "canonical_bytes",
    "load_model_manifest_bytes",
    "tensor_profile_document",
    "validate_model_manifest",
    "validate_v2_package_manifest",
]

