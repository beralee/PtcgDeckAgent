#!/usr/bin/env python3
"""Route Base Graph v1.8 failures to one authoritative owner layer."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any, Iterable


ROUTES: dict[str, tuple[str, str, str, tuple[str, ...]]] = {
    "runtime_failure": (
        "runtime_integration",
        "runtime_integration",
        "none",
        ("first exception/timeout/entrypoint evidence",),
    ),
    "invalid_action": (
        "base_legality",
        "base_legality",
        "prohibited",
        ("native legal frontier", "invalid selected binding"),
    ),
    "legality_mismatch": (
        "base_legality",
        "base_legality",
        "prohibited",
        ("native legal frontier", "Base certificate mismatch"),
    ),
    "resource_certificate_failure": (
        "base_legality",
        "base_legality",
        "prohibited",
        ("resource ledger", "failed or false certificate"),
    ),
    "attack_resolution_failure": (
        "base_legality",
        "base_legality",
        "prohibited",
        ("attack/effect resolver evidence", "legal option binding"),
    ),
    "missing_route": (
        "graph_transaction",
        "graph_transaction",
        "prohibited",
        ("complete legal frontier", "proved absent semantic route"),
    ),
    "transaction_sequence_failure": (
        "graph_transaction",
        "graph_transaction",
        "prohibited",
        ("transaction journal", "first broken edge or completion certificate"),
    ),
    "interaction_binding_failure": (
        "interaction",
        "interaction",
        "shadow_until_causal_coverage",
        ("correct parent route", "wrong target/count/order/payment binding"),
    ),
    "public_context_missing": (
        "strategic_context",
        "strategic_context",
        "prohibited",
        ("public fact available at decision time", "missing context field"),
    ),
    "wrong_win_condition": (
        "core_adapter",
        "core_adapter",
        "prohibited",
        ("correct public context", "incorrect win-condition adjustment"),
    ),
    "wrong_goal_priority": (
        "goal_modifier",
        "goal_modifier",
        "prohibited",
        ("correct facts and win condition", "incorrect goal ordering"),
    ),
    "wrong_goal_stage": (
        "goal_state_machine",
        "goal_state_machine",
        "prohibited",
        ("correct public board target", "incorrect acquire/deploy/fund/ready/execute stage"),
    ),
    "goal_stage_stalled": (
        "goal_state_machine",
        "goal_state_machine",
        "prohibited",
        ("typed goal-state trace", "proved missing stage transition"),
    ),
    "missing_macro_intent": (
        "macro_intent",
        "macro_intent",
        "prohibited",
        ("current legal root action", "missing semantic multi-interaction route"),
    ),
    "macro_intent_binding_failure": (
        "macro_intent",
        "macro_intent",
        "prohibited",
        ("current context ID", "stale or wrong macro root/stage binding"),
    ),
    "threat_clock_error": (
        "threat_clock",
        "threat_clock",
        "prohibited",
        ("public opponent response clock", "incorrect goal deadline or tempo margin"),
    ),
    "unproven_hard_constraint": (
        "dominance_constraint",
        "dominance_constraint",
        "prohibited",
        ("complete public dominance certificate", "dominant and dominated current action IDs"),
    ),
    "strategic_constraint_missing": (
        "core_adapter",
        "core_adapter",
        "prohibited",
        ("legal but strategically losing action", "public reusable predicate"),
    ),
    "matchup_constraint_missing": (
        "matchup_adapter",
        "matchup_adapter",
        "prohibited",
        ("unique or robust public matchup evidence", "matchup-specific losing action"),
    ),
    "same_hard_tier_misrank": (
        "tactical_scorer",
        "tactical_scorer",
        "residual_only",
        ("correct legal and strategic masks", "identical Base hard tier"),
    ),
    "multi_turn_value_missing": (
        "future_simulator",
        "future_simulator",
        "residual_only",
        ("bounded public continuation evidence", "existing legal action id"),
    ),
    "uncertainty_calibration_failure": (
        "future_simulator",
        "future_simulator",
        "residual_only",
        ("two-turn public branches", "expected, worst-case, confidence, and fallback evidence"),
    ),
    "exam_contract_failure": (
        "exam_contract",
        "exam_contract",
        "prohibited",
        ("order-insensitive execution equivalence", "separate counterfactual outcome evidence"),
    ),
    "matchup_activation_failure": (
        "matchup_activation",
        "matchup_activation",
        "prohibited",
        ("public belief status", "declared Adapter coverage"),
    ),
    "learned_residual_error": (
        "learned_head",
        "learned_head",
        "residual_only",
        ("all structural owners correct", "same-tier residual ranking error"),
    ),
    "irreducible": (
        "none",
        "irreducible",
        "none",
        ("no better public branch within declared search budget",),
    ),
}

SIGNAL_ORDER: tuple[tuple[str, str], ...] = (
    ("runtime_failure", "runtime_failure"),
    ("invalid_action", "invalid_action"),
    ("legality_mismatch", "legality_mismatch"),
    ("resource_certificate_failed", "resource_certificate_failure"),
    ("attack_resolution_failed", "attack_resolution_failure"),
    ("legal_route_absent", "missing_route"),
    ("transaction_sequence_failed", "transaction_sequence_failure"),
    ("interaction_binding_wrong", "interaction_binding_failure"),
    ("public_context_missing", "public_context_missing"),
    ("win_condition_wrong", "wrong_win_condition"),
    ("goal_priority_wrong", "wrong_goal_priority"),
    ("goal_stage_wrong", "wrong_goal_stage"),
    ("goal_stage_stalled", "goal_stage_stalled"),
    ("macro_intent_missing", "missing_macro_intent"),
    ("macro_intent_binding_wrong", "macro_intent_binding_failure"),
    ("threat_clock_wrong", "threat_clock_error"),
    ("hard_constraint_unproven", "unproven_hard_constraint"),
    ("matchup_activation_wrong", "matchup_activation_failure"),
    ("matchup_constraint_missing", "matchup_constraint_missing"),
    ("strategic_constraint_missing", "strategic_constraint_missing"),
    ("multi_turn_value_missing", "multi_turn_value_missing"),
    ("uncertainty_calibration_wrong", "uncertainty_calibration_failure"),
    ("exam_contract_failed", "exam_contract_failure"),
    ("same_base_hard_tier_misrank", "same_hard_tier_misrank"),
    ("learned_residual_error", "learned_residual_error"),
    ("no_better_public_branch", "irreducible"),
)


def _read_records(path: Path) -> list[dict[str, Any]]:
    text = path.read_text(encoding="utf-8-sig")
    stripped = text.lstrip()
    if not stripped:
        return []
    if stripped.startswith("[") or stripped.startswith("{"):
        try:
            payload = json.loads(text)
        except json.JSONDecodeError:
            payload = None
        if isinstance(payload, list):
            return [value for value in payload if isinstance(value, dict)]
        if isinstance(payload, dict):
            nested = payload.get("records")
            if isinstance(nested, list):
                return [value for value in nested if isinstance(value, dict)]
            return [payload]
    records: list[dict[str, Any]] = []
    for line_number, raw in enumerate(text.splitlines(), 1):
        if not raw.strip():
            continue
        value = json.loads(raw)
        if not isinstance(value, dict):
            raise ValueError(f"line {line_number} is not a JSON object")
        records.append(value)
    return records


def _infer_class(record: dict[str, Any]) -> tuple[str | None, str]:
    declared = str(record.get("failure_class", "")).strip()
    if declared:
        return (declared if declared in ROUTES else None, "declared_failure_class")
    signals = record.get("signals")
    if not isinstance(signals, dict):
        return None, "missing_failure_class_and_signals"
    matched = [failure_class for signal, failure_class in SIGNAL_ORDER if signals.get(signal) is True]
    if not matched:
        return None, "no_owner_signal_matched"
    return matched[0], f"signal:{next(s for s, c in SIGNAL_ORDER if c == matched[0] and signals.get(s) is True)}"


def classify(record: dict[str, Any], ordinal: int) -> dict[str, Any]:
    failure_id = str(record.get("failure_id") or record.get("id") or f"failure-{ordinal:04d}")
    failure_class, basis = _infer_class(record)
    if failure_class is None:
        return {
            "schema_version": 2,
            "failure_id": failure_id,
            "owner_layer": "unresolved",
            "patch_type": "collect_more_evidence",
            "classification_basis": basis,
            "required_evidence": [
                "native legal frontier",
                "first causal divergence",
                "v1.8 strategic trace",
            ],
            "learned_control": "prohibited",
            "resolved": False,
        }
    owner, patch_type, learned_control, evidence = ROUTES[failure_class]
    return {
        "schema_version": 2,
        "failure_id": failure_id,
        "owner_layer": owner,
        "patch_type": patch_type,
        "classification_basis": failure_class if basis == "declared_failure_class" else basis,
        "required_evidence": list(evidence),
        "learned_control": learned_control,
        "resolved": True,
    }


def build_report(records: Iterable[dict[str, Any]]) -> dict[str, Any]:
    decisions = [classify(record, index) for index, record in enumerate(records, 1)]
    counts = Counter(str(value["owner_layer"]) for value in decisions)
    unresolved = sum(not bool(value["resolved"]) for value in decisions)
    return {
        "schema_version": 2,
        "ok": unresolved == 0 and bool(decisions),
        "record_count": len(decisions),
        "resolved_count": len(decisions) - unresolved,
        "unresolved_count": unresolved,
        "owner_counts": dict(sorted(counts.items())),
        "decisions": decisions,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    report = build_report(_read_records(args.input))
    payload = json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    if args.output is not None:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(payload, encoding="utf-8", newline="\n")
    print(payload, end="")
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
