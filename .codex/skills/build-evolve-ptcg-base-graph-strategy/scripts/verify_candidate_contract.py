#!/usr/bin/env python3
"""Fail closed unless a candidate satisfies the Base Graph v1.8 contract."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any


BASE_GRAPH_VERSION = "1.8.0"
REQUIRED_ARCHITECTURE = "clean_room_base_graph_v1_8_goal_state_strategic_agent_framework"
INHERITED_FEATURES = (
    "base_graph_v1_1_context_certificate",
    "base_graph_v1_1_all_option_scene_assessment",
    "base_graph_v1_1_mandatory_obligation_ledger",
    "base_graph_v1_1_attack_commit_barrier",
    "base_graph_v1_1_public_opponent_resolver",
    "base_graph_v1_1_matchup_extension_registry",
    "base_graph_v1_1_prize_turn_predictor",
    "base_graph_v1_1_prize_denial_solver",
    "base_graph_v1_1_transaction_replan_resolution",
)
V17_FEATURES = (
    "base_graph_v1_7_strategic_context",
    "base_graph_v1_7_tactical_adapter",
    "base_graph_v1_7_goal_modifier",
    "base_graph_v1_7_legality_strategy_tactics_pipeline",
    "base_graph_v1_7_dynamic_win_condition",
    "base_graph_v1_7_future_simulation_hook",
    "base_graph_v1_7_public_matchup_activation",
    "base_graph_v1_7_result_authority_compatible",
)
V18_FEATURES = (
    "base_graph_v1_8_typed_goal_state_machine",
    "base_graph_v1_8_macro_intent",
    "base_graph_v1_8_public_threat_clock",
    "base_graph_v1_8_two_turn_uncertainty_future",
    "base_graph_v1_8_proven_dominance_constraint",
    "base_graph_v1_8_persistent_plan_replan",
    "base_graph_v1_8_counterfactual_exam_boundary",
    "base_graph_v1_8_strategic_trace_v2",
    "base_graph_v1_8_v1_7_compatible",
)
REQUIRED_FEATURES = (*INHERITED_FEATURES, *V17_FEATURES, *V18_FEATURES)
REQUIRED_OWNER_LAYERS = {
    "base_legality",
    "graph_transaction",
    "interaction",
    "strategic_context",
    "core_adapter",
    "matchup_adapter",
    "goal_modifier",
    "goal_state_machine",
    "macro_intent",
    "threat_clock",
    "dominance_constraint",
    "exam_contract",
    "tactical_scorer",
    "future_simulator",
    "matchup_activation",
    "learned_head",
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def resolve_inside(root: Path, raw: Path) -> Path:
    path = raw.resolve() if raw.is_absolute() else (root / raw).resolve()
    try:
        path.relative_to(root)
    except ValueError as exc:
        raise ValueError(f"candidate path must stay inside repository: {path}") from exc
    return path


def read_deck(path: Path) -> list[int]:
    values: list[int] = []
    for line_number, raw in enumerate(path.read_text(encoding="utf-8-sig").splitlines(), 1):
        value = raw.strip()
        if not value:
            continue
        try:
            values.append(int(value))
        except ValueError as exc:
            raise ValueError(f"deck line {line_number} is not an integer: {value!r}") from exc
    return values


def declared_hash(manifest: dict[str, Any], name: str) -> str | None:
    direct = manifest.get(f"{name}_sha256")
    if isinstance(direct, str):
        return direct
    hashes = manifest.get("hashes")
    if isinstance(hashes, dict):
        suffix = "/main.py" if name == "main" else "/deck.csv"
        for key, value in hashes.items():
            if str(key).replace("\\", "/").endswith(suffix) and isinstance(value, str):
                return value
    return None


def _check_bool(manifest: dict[str, Any], key: str, expected: bool, errors: list[str]) -> None:
    if manifest.get(key) is not expected:
        errors.append(f"{key} must be {str(expected).lower()}")


def _validate_adapters(manifest: dict[str, Any], errors: list[str]) -> list[dict[str, Any]]:
    adapters = manifest.get("adapters")
    if not isinstance(adapters, list):
        errors.append("adapters must be a list")
        return []
    normalized = [value for value in adapters if isinstance(value, dict)]
    if len(normalized) != len(adapters):
        errors.append("every adapter declaration must be an object")
    ids = [str(value.get("id", "")) for value in normalized]
    if any(not value for value in ids):
        errors.append("every adapter must declare a non-empty id")
    if len(ids) != len(set(ids)):
        errors.append("adapter ids must be unique")
    if not any(value.get("kind") == "core" for value in normalized):
        errors.append("at least one core adapter must be declared")
    for value in normalized:
        kind = value.get("kind")
        if kind not in {"core", "hard_matchup", "robust_matchup"}:
            errors.append(f"adapter {value.get('id')!r} has invalid kind: {kind!r}")
        if kind == "hard_matchup" and not value.get("matchup_strategy_ids"):
            errors.append(f"hard matchup adapter {value.get('id')!r} has no strategy ids")
        if kind == "robust_matchup":
            if value.get("robust_when_ambiguous") is not True:
                errors.append(
                    f"robust matchup adapter {value.get('id')!r} must declare robust_when_ambiguous"
                )
            if not value.get("covers"):
                errors.append(f"robust matchup adapter {value.get('id')!r} has no coverage")
    return normalized


def validate(root: Path, candidate: Path) -> dict[str, Any]:
    errors: list[str] = []
    required = {
        "main": candidate / "main.py",
        "deck": candidate / "deck.csv",
        "manifest": candidate / "candidate_manifest.json",
    }
    for label, path in required.items():
        if not path.is_file():
            errors.append(f"missing {label}: {path}")
    if errors:
        return {"ok": False, "errors": errors, "candidate": str(candidate)}

    source = required["main"].read_text(encoding="utf-8")
    try:
        manifest = json.loads(required["manifest"].read_text(encoding="utf-8"))
    except (json.JSONDecodeError, UnicodeError) as exc:
        return {
            "ok": False,
            "errors": [f"manifest parse failed: {exc}"],
            "candidate": str(candidate),
        }
    try:
        deck = read_deck(required["deck"])
    except (ValueError, UnicodeError) as exc:
        errors.append(f"deck parse failed: {exc}")
        deck = []

    if len(deck) != 60:
        errors.append(f"deck must contain exactly 60 card ids, found {len(deck)}")
    if any(value <= 0 for value in deck):
        errors.append("deck contains a non-positive card id")

    if not re.search(r"(?m)^(?!\s*class\s).*\bBaseGraphRuntimeV18\s*\(", source):
        errors.append("main.py does not instantiate BaseGraphRuntimeV18")
    if not re.search(
        r"(?m)^(?!\s*class\s).*\b(?:BaseGraphV18|StrategicTransactionGraphControllerV18)\s*\(",
        source,
    ):
        errors.append("main.py does not instantiate BaseGraphV18 or its strategic controller")
    if "GRAPH_FEATURES" not in source:
        errors.append("main.py does not declare GRAPH_FEATURES")
    for feature in REQUIRED_FEATURES:
        if feature not in source:
            errors.append(f"missing GRAPH_FEATURES capability: {feature}")
    if re.search(r"(?im)^\s*(?:from|import)\s+[^\n]*(?:r121|r122)", source):
        errors.append("main.py imports an r121/r122 module")

    architecture = str(manifest.get("architecture", "")).lower()
    if architecture != REQUIRED_ARCHITECTURE:
        errors.append(f"manifest architecture must equal {REQUIRED_ARCHITECTURE}")
    if manifest.get("base_graph_version") != BASE_GRAPH_VERSION:
        errors.append(f"base_graph_version must equal {BASE_GRAPH_VERSION}")
    if manifest.get("runtime_class") != "BaseGraphRuntimeV18":
        errors.append("runtime_class must be BaseGraphRuntimeV18")
    if manifest.get("controller_class") not in {
        "BaseGraphV18",
        "StrategicTransactionGraphControllerV18",
    }:
        errors.append("controller_class must be BaseGraphV18 or StrategicTransactionGraphControllerV18")
    if manifest.get("adapter_contract_version") != BASE_GRAPH_VERSION:
        errors.append(f"adapter_contract_version must equal {BASE_GRAPH_VERSION}")

    adapters = _validate_adapters(manifest, errors)
    activation = manifest.get("matchup_activation")
    if not isinstance(activation, dict):
        errors.append("matchup_activation must be an object")
    else:
        if activation.get("hard_requires_unique") is not True:
            errors.append("matchup_activation.hard_requires_unique must be true")
        if activation.get("ambiguous_requires_robust_coverage") is not True:
            errors.append("matchup_activation.ambiguous_requires_robust_coverage must be true")

    owner_layers = manifest.get("owner_layers")
    if not isinstance(owner_layers, list):
        errors.append("owner_layers must be a list")
    else:
        missing_owners = sorted(REQUIRED_OWNER_LAYERS - {str(value) for value in owner_layers})
        if missing_owners:
            errors.append(f"owner_layers is missing: {missing_owners}")

    _check_bool(manifest, "base_final_veto", True, errors)
    _check_bool(manifest, "strategic_trace_required", True, errors)
    _check_bool(manifest, "tactical_cross_hard_tier", False, errors)
    _check_bool(manifest, "future_simulation_legality_authority", False, errors)
    _check_bool(
        manifest,
        "hard_constraint_requires_public_dominance_proof",
        True,
        errors,
    )
    _check_bool(manifest, "persistent_plan_reuses_constraints", False, errors)
    _check_bool(manifest, "persistent_plan_reuses_scores", False, errors)
    _check_bool(manifest, "execution_exam_action_order_required", False, errors)
    _check_bool(manifest, "counterfactual_exam_separate", True, errors)
    if manifest.get("future_horizon_turns") != 2:
        errors.append("future_horizon_turns must equal 2")
    _check_bool(manifest, "future_requires_uncertainty", True, errors)
    canonical_base = root / "strategy_graph/base_graph_v1_7.py"
    canonical_contract = root / "strategy_graph/base_graph_v1_7_architecture_contract.json"
    if not canonical_base.is_file():
        errors.append(f"missing canonical Base Graph v1.7 source: {canonical_base}")
    elif str(manifest.get("base_graph_v1_7_sha256", "")).lower() != sha256(canonical_base):
        errors.append("base_graph_v1_7_sha256 does not match the canonical repository source")
    if not canonical_contract.is_file():
        errors.append(f"missing canonical v1.7 contract: {canonical_contract}")
    elif str(manifest.get("base_graph_v1_7_contract_sha256", "")).lower() != sha256(
        canonical_contract
    ):
        errors.append(
            "base_graph_v1_7_contract_sha256 does not match the canonical repository contract"
        )
    canonical_v18 = root / "strategy_graph/base_graph_v1_8.py"
    canonical_v18_contract = root / "strategy_graph/base_graph_v1_8_architecture_contract.json"
    if not canonical_v18.is_file():
        errors.append(f"missing canonical Base Graph v1.8 source: {canonical_v18}")
    elif str(manifest.get("base_graph_v1_8_sha256", "")).lower() != sha256(canonical_v18):
        errors.append("base_graph_v1_8_sha256 does not match the canonical repository source")
    if not canonical_v18_contract.is_file():
        errors.append(f"missing canonical v1.8 contract: {canonical_v18_contract}")
    elif str(manifest.get("base_graph_v1_8_contract_sha256", "")).lower() != sha256(
        canonical_v18_contract
    ):
        errors.append(
            "base_graph_v1_8_contract_sha256 does not match the canonical repository contract"
        )
    if manifest.get("strategic_trace_schema_version") != 2:
        errors.append("strategic_trace_schema_version must equal 2")
    if manifest.get("strategy_dependencies") != []:
        errors.append("strategy_dependencies must be an empty list for a clean-room policy")
    if manifest.get("imports_r121_or_r122_policy") is not False:
        errors.append("imports_r121_or_r122_policy must be false")
    if manifest.get("imports_other_deck_policy") is not False:
        errors.append("imports_other_deck_policy must be false")
    if manifest.get("opponent_information") != "public_only":
        errors.append("opponent_information must be public_only")
    if manifest.get("memorization_surface") != []:
        errors.append("memorization_surface must be an empty list")
    bc_mode = str(manifest.get("bc_mode", "")).lower()
    if not bc_mode:
        errors.append("manifest must declare bc_mode")
    elif bc_mode not in {"disabled", "residual_only", "same_hard_tier_residual_only"}:
        errors.append("bc_mode must be disabled or residual-only")
    _check_bool(manifest, "promotion_authorized", False, errors)
    _check_bool(manifest, "submission_authorized", False, errors)

    actual_hashes = {"main": sha256(required["main"]), "deck": sha256(required["deck"])}
    for name in ("main", "deck"):
        expected = declared_hash(manifest, name)
        if expected is None:
            errors.append(f"manifest does not declare {name}_sha256")
        elif expected.lower() != actual_hashes[name].lower():
            errors.append(f"{name} hash mismatch: {actual_hashes[name]} != {expected}")

    return {
        "ok": not errors,
        "candidate": candidate.relative_to(root).as_posix(),
        "architecture": architecture,
        "base_graph_version": manifest.get("base_graph_version"),
        "bc_mode": bc_mode,
        "adapter_ids": [value.get("id") for value in adapters],
        "deck_count": len(deck),
        "hashes": actual_hashes,
        "required_features": list(REQUIRED_FEATURES),
        "errors": errors,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, required=True)
    parser.add_argument("--candidate-dir", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    root = args.repo_root.resolve()
    candidate = resolve_inside(root, args.candidate_dir)
    result = validate(root, candidate)
    payload = json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    if args.output is not None:
        output = args.output.resolve() if args.output.is_absolute() else (root / args.output).resolve()
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(payload, encoding="utf-8", newline="\n")
    print(payload, end="")
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
