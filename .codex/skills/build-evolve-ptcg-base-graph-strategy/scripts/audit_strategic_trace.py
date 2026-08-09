#!/usr/bin/env python3
"""Audit Base Graph v1.7/v1.8 strategic_trace.jsonl invariants."""

from __future__ import annotations

import argparse
import json
import math
import re
from collections import defaultdict
from pathlib import Path
from typing import Any, Iterable


REQUIRED_FIELDS = (
    "schema_version",
    "scene_id",
    "decision_id",
    "determinism_key",
    "context_id",
    "public_only",
    "opponent_belief",
    "active_adapters",
    "win_condition_weights",
    "goals",
    "goal_modifiers",
    "legal_action_ids",
    "strategic_action_ids",
    "mandatory_action_ids",
    "terminal_action_ids",
    "forbidden_reasons",
    "tactical_scores",
    "future_evidence",
    "base_hard_tiers",
    "base_selected_action_id",
    "tactical_preferred_action_id",
    "tactical_override_applied",
    "base_vetoed_action_ids",
    "selected_action_id",
    "fallback_reason",
    "audit_id",
)
V18_REQUIRED_FIELDS = (
    "base_context_id",
    "goal_states",
    "threat_clock",
    "macro_intents",
    "dominance_constraints",
    "execution_exam",
    "counterfactual_exam",
)
GOAL_STAGES_V18 = (
    "acquire",
    "deploy",
    "fund",
    "ready",
    "execute",
    "maintain",
    "recover",
)
PRIVATE_KEY_PATTERNS = (
    re.compile(r"(^|_)opponent(_|$).*hand"),
    re.compile(r"(^|_)opponent(_|$).*deck(_|$).*order"),
    re.compile(r"(^|_)hidden(_|$).*hand"),
    re.compile(r"(^|_)prize(_|$).*identit"),
    re.compile(r"(^|_)engine(_|$).*private"),
    re.compile(r"(^|_)private(_|$).*opponent"),
)
ALL_REMOVED_FALLBACKS = {
    "all_strategic_actions_forbidden",
    "strategic_filter_all_removed_base_fallback",
}


def _read_traces(path: Path) -> list[tuple[int, dict[str, Any]]]:
    text = path.read_text(encoding="utf-8-sig")
    stripped = text.lstrip()
    if not stripped:
        return []
    if stripped.startswith("["):
        payload = json.loads(text)
        if not isinstance(payload, list):
            raise ValueError("trace JSON must be a list")
        return [(index, value) for index, value in enumerate(payload, 1) if isinstance(value, dict)]
    if stripped.startswith("{"):
        try:
            payload = json.loads(text)
        except json.JSONDecodeError:
            payload = None
        if isinstance(payload, dict) and isinstance(payload.get("traces"), list):
            return [
                (index, value)
                for index, value in enumerate(payload["traces"], 1)
                if isinstance(value, dict)
            ]
        if isinstance(payload, dict):
            return [(1, payload)]
    traces: list[tuple[int, dict[str, Any]]] = []
    for line_number, raw in enumerate(text.splitlines(), 1):
        if not raw.strip():
            continue
        value = json.loads(raw)
        if not isinstance(value, dict):
            raise ValueError(f"line {line_number} is not a JSON object")
        traces.append((line_number, value))
    return traces


def _normalized_key(value: Any) -> str:
    return re.sub(r"[^a-z0-9]+", "_", str(value).lower()).strip("_")


def _private_paths(value: Any, prefix: str = "") -> Iterable[str]:
    if isinstance(value, dict):
        for key, nested in value.items():
            normalized = _normalized_key(key)
            path = f"{prefix}.{key}" if prefix else str(key)
            if any(pattern.search(normalized) for pattern in PRIVATE_KEY_PATTERNS):
                yield path
            yield from _private_paths(nested, path)
    elif isinstance(value, list):
        for index, nested in enumerate(value):
            yield from _private_paths(nested, f"{prefix}[{index}]")


def _list_of_strings(value: Any) -> list[str]:
    if not isinstance(value, list):
        return []
    return [str(item) for item in value]


def _add(
    violations: list[dict[str, Any]],
    line: int,
    trace: dict[str, Any],
    code: str,
    detail: str,
) -> None:
    violations.append(
        {
            "line": line,
            "scene_id": trace.get("scene_id"),
            "decision_id": trace.get("decision_id"),
            "code": code,
            "detail": detail,
        }
    )


def _finite_scores(trace: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    scores = trace.get("tactical_scores")
    if not isinstance(scores, dict):
        return ["tactical_scores must be an object"]
    for action_id, value in scores.items():
        if not isinstance(value, dict):
            errors.append(f"score for {action_id} must be an object")
            continue
        total = value.get("total")
        if not isinstance(total, (int, float)) or not math.isfinite(float(total)):
            errors.append(f"score for {action_id} is not finite")
        components = value.get("components", {})
        if not isinstance(components, dict):
            errors.append(f"components for {action_id} must be an object")
        elif any(
            not isinstance(component, (int, float)) or not math.isfinite(float(component))
            for component in components.values()
        ):
            errors.append(f"components for {action_id} contain a non-finite value")
    return errors


def _future_items(value: Any) -> list[tuple[str, dict[str, Any]]]:
    if isinstance(value, dict):
        return [
            (str(action_id), evidence)
            for action_id, evidence in value.items()
            if isinstance(evidence, dict)
        ]
    if isinstance(value, list):
        return [
            (str(evidence.get("action_id", "")), evidence)
            for evidence in value
            if isinstance(evidence, dict)
        ]
    return []


def _audit_v18(
    line: int,
    trace: dict[str, Any],
    violations: list[dict[str, Any]],
    *,
    context_id: str,
    legal: set[str],
    strategic: set[str],
    mandatory: set[str],
    terminal: set[str],
) -> None:
    for field in V18_REQUIRED_FIELDS:
        if field not in trace:
            _add(violations, line, trace, "missing_v18_field", field)

    goals = trace.get("goal_states")
    goal_ids: set[str] = set()
    if not isinstance(goals, list):
        _add(violations, line, trace, "goal_states", "must be a list")
        goals = []
    for goal in goals:
        if not isinstance(goal, dict):
            _add(violations, line, trace, "goal_state_shape", "must be an object")
            continue
        state_id = str(goal.get("state_id", ""))
        if not state_id or state_id in goal_ids:
            _add(violations, line, trace, "invalid_goal_state_id", state_id)
        goal_ids.add(state_id)
        if str(goal.get("stage", "")) not in GOAL_STAGES_V18:
            _add(violations, line, trace, "invalid_goal_stage", str(goal.get("stage")))
        if str(goal.get("context_id", "")) != context_id:
            _add(violations, line, trace, "stale_goal_state", state_id)

    threat = trace.get("threat_clock")
    if not isinstance(threat, dict):
        _add(violations, line, trace, "threat_clock", "must be an object")
    else:
        if str(threat.get("context_id", "")) != context_id:
            _add(violations, line, trace, "stale_threat_clock", "context mismatch")
        for key in ("own_attacks_to_win", "opponent_attacks_to_win", "goal_deadline_turn"):
            if not isinstance(threat.get(key), int) or int(threat.get(key, -1)) < 0:
                _add(violations, line, trace, "invalid_threat_clock", key)
        confidence = threat.get("confidence")
        if (
            not isinstance(confidence, (int, float))
            or not math.isfinite(float(confidence))
            or not 0.0 <= float(confidence) <= 1.0
        ):
            _add(violations, line, trace, "invalid_threat_confidence", str(confidence))

    macros = trace.get("macro_intents")
    macro_ids: set[str] = set()
    if not isinstance(macros, list):
        _add(violations, line, trace, "macro_intents", "must be a list")
        macros = []
    for macro in macros:
        if not isinstance(macro, dict):
            _add(violations, line, trace, "macro_intent_shape", "must be an object")
            continue
        intent_id = str(macro.get("intent_id", ""))
        root_action_id = str(macro.get("root_action_id", ""))
        if not intent_id or intent_id in macro_ids:
            _add(violations, line, trace, "invalid_macro_intent_id", intent_id)
        macro_ids.add(intent_id)
        if root_action_id not in strategic:
            _add(violations, line, trace, "macro_root_not_strategic", root_action_id)
        if str(macro.get("goal_state_id", "")) not in goal_ids:
            _add(violations, line, trace, "macro_goal_not_current", intent_id)
        if str(macro.get("context_id", "")) != context_id:
            _add(violations, line, trace, "stale_macro_intent", intent_id)
        start = str(macro.get("start_stage", ""))
        projected = str(macro.get("projected_stage", ""))
        if start not in GOAL_STAGES_V18 or projected not in GOAL_STAGES_V18:
            _add(violations, line, trace, "invalid_macro_stage", intent_id)
        elif start != "recover" and projected != "recover" and (
            GOAL_STAGES_V18.index(projected) < GOAL_STAGES_V18.index(start)
        ):
            _add(violations, line, trace, "backward_macro_stage", intent_id)
        steps = macro.get("steps")
        if not isinstance(steps, list) or not steps:
            _add(violations, line, trace, "empty_macro_steps", intent_id)

    dominance = trace.get("dominance_constraints")
    if not isinstance(dominance, list):
        _add(violations, line, trace, "dominance_constraints", "must be a list")
        dominance = []
    for constraint in dominance:
        if not isinstance(constraint, dict):
            _add(violations, line, trace, "dominance_constraint_shape", "must be an object")
            continue
        action_id = str(constraint.get("action_id", ""))
        certificate = constraint.get("certificate")
        if action_id not in legal:
            _add(violations, line, trace, "dominance_outside_legal", action_id)
        if action_id in strategic:
            _add(violations, line, trace, "dominance_did_not_filter", action_id)
        if action_id in mandatory:
            _add(violations, line, trace, "mandatory_dominance_forbidden", action_id)
        if action_id in terminal:
            _add(violations, line, trace, "terminal_dominance_forbidden", action_id)
        if str(constraint.get("context_id", "")) != context_id:
            _add(violations, line, trace, "stale_dominance_constraint", action_id)
        if not isinstance(certificate, dict):
            _add(violations, line, trace, "missing_dominance_certificate", action_id)
            continue
        if (
            not str(certificate.get("certificate_id", ""))
            or str(certificate.get("source", "")) != str(constraint.get("source", ""))
            or str(certificate.get("proof_kind", ""))
            not in {
                "terminal_dominance",
                "mandatory_safety",
                "exact_resource_dominance",
                "robust_future_dominance",
            }
            or certificate.get("public_only") is not True
            or certificate.get("complete") is not True
            or str(certificate.get("context_id", "")) != context_id
            or str(certificate.get("dominated_action_id", "")) != action_id
            or str(certificate.get("dominant_action_id", "")) not in strategic
            or not _list_of_strings(certificate.get("evidence_ids"))
        ):
            _add(violations, line, trace, "unproven_dominance_constraint", action_id)

    for action_id, evidence in _future_items(trace.get("future_evidence")):
        if action_id not in strategic:
            _add(violations, line, trace, "future_outside_strategic_mask", action_id)
        if str(evidence.get("context_id", context_id)) != context_id:
            _add(violations, line, trace, "stale_future_evidence", action_id)
        if evidence.get("public_only", True) is not True or evidence.get("complete", True) is not True:
            _add(violations, line, trace, "nonpublic_or_incomplete_future", action_id)
        if evidence.get("horizon") != 2:
            _add(violations, line, trace, "invalid_future_horizon", action_id)
        for key in ("expected_value", "worst_case", "lower_bound", "confidence"):
            value = evidence.get(key)
            if not isinstance(value, (int, float)) or not math.isfinite(float(value)):
                _add(violations, line, trace, "invalid_future_uncertainty", f"{action_id}:{key}")
        confidence = evidence.get("confidence")
        if isinstance(confidence, (int, float)) and not 0.0 <= float(confidence) <= 1.0:
            _add(violations, line, trace, "invalid_future_confidence", action_id)
        expected = evidence.get("expected_value")
        lower = evidence.get("lower_bound")
        if isinstance(expected, (int, float)) and isinstance(lower, (int, float)) and lower > expected:
            _add(violations, line, trace, "future_lower_bound_above_expected", action_id)

    execution = trace.get("execution_exam")
    if not isinstance(execution, dict):
        _add(violations, line, trace, "execution_exam", "must be an object")
    else:
        if execution.get("action_order_required") is not False:
            _add(violations, line, trace, "exam_requires_exact_action_order", "must be false")
        if execution.get("final_public_state_exact") is not True:
            _add(violations, line, trace, "exam_final_state_not_exact", "must be true")
        if execution.get("final_hand_exact") is not True:
            _add(violations, line, trace, "exam_final_hand_not_exact", "must be true")
    counterfactual = trace.get("counterfactual_exam")
    if not isinstance(counterfactual, dict):
        _add(violations, line, trace, "counterfactual_exam", "must be an object")
    else:
        if counterfactual.get("separate_from_execution_score") is not True:
            _add(violations, line, trace, "counterfactual_exam_not_separate", "must be true")
        if counterfactual.get("runtime_input") is not False:
            _add(violations, line, trace, "counterfactual_exam_runtime_leak", "must be false")

    plan = trace.get("plan_memory")
    if isinstance(plan, dict):
        if plan.get("reused_constraints") is not False or plan.get("reused_scores") is not False:
            _add(violations, line, trace, "stale_plan_authority", "scores/constraints reused")


def audit_trace(line: int, trace: dict[str, Any], violations: list[dict[str, Any]]) -> None:
    for field in REQUIRED_FIELDS:
        if field not in trace:
            _add(violations, line, trace, "missing_field", field)
    schema_version = trace.get("schema_version")
    if schema_version not in {1, 2}:
        _add(violations, line, trace, "schema_version", "schema_version must equal 1 or 2")
    if trace.get("public_only") is not True:
        _add(violations, line, trace, "public_only", "public_only must be true")
    for path in _private_paths(trace):
        _add(violations, line, trace, "private_information_key", path)

    context_id = str(trace.get("context_id", ""))
    valid_constraint_context_ids = {context_id}
    if trace.get("schema_version") == 2:
        base_context_id = str(trace.get("base_context_id", ""))
        if base_context_id:
            valid_constraint_context_ids.add(base_context_id)
    legal_values = _list_of_strings(trace.get("legal_action_ids"))
    strategic_values = _list_of_strings(trace.get("strategic_action_ids"))
    mandatory_values = _list_of_strings(trace.get("mandatory_action_ids"))
    terminal_values = _list_of_strings(trace.get("terminal_action_ids"))
    vetoed_values = _list_of_strings(trace.get("base_vetoed_action_ids"))
    legal = set(legal_values)
    strategic = set(strategic_values)
    mandatory = set(mandatory_values)
    terminal = set(terminal_values)
    vetoed = set(vetoed_values)

    for label, values in (
        ("legal_action_ids", legal_values),
        ("strategic_action_ids", strategic_values),
        ("mandatory_action_ids", mandatory_values),
        ("terminal_action_ids", terminal_values),
        ("base_vetoed_action_ids", vetoed_values),
    ):
        if len(values) != len(set(values)):
            _add(violations, line, trace, "duplicate_action_id", label)
    if not strategic <= legal:
        _add(violations, line, trace, "strategic_outside_legal", str(sorted(strategic - legal)))
    if not mandatory <= strategic:
        _add(violations, line, trace, "mandatory_filtered", str(sorted(mandatory - strategic)))
    if not terminal <= strategic:
        _add(violations, line, trace, "terminal_filtered", str(sorted(terminal - strategic)))

    belief = trace.get("opponent_belief")
    belief_status = ""
    candidates: set[str] = set()
    if not isinstance(belief, dict):
        _add(violations, line, trace, "opponent_belief", "must be an object")
    else:
        belief_status = str(belief.get("status", ""))
        candidates = set(_list_of_strings(belief.get("candidates")))
        if belief_status == "unique" and len(candidates) != 1:
            _add(
                violations,
                line,
                trace,
                "invalid_unique_belief",
                f"expected one candidate, found {sorted(candidates)}",
            )
        if belief_status == "ambiguous" and len(candidates) < 2:
            _add(
                violations,
                line,
                trace,
                "invalid_ambiguous_belief",
                f"expected at least two candidates, found {sorted(candidates)}",
            )
    adapters = trace.get("active_adapters")
    if not isinstance(adapters, list):
        _add(violations, line, trace, "active_adapters", "must be a list")
        adapters = []
    for adapter in adapters:
        if not isinstance(adapter, dict):
            _add(violations, line, trace, "adapter_shape", "adapter must be an object")
            continue
        kind = str(adapter.get("kind", ""))
        adapter_id = str(adapter.get("id", ""))
        if kind == "hard_matchup" and belief_status != "unique":
            _add(
                violations,
                line,
                trace,
                "hard_adapter_without_unique_belief",
                adapter_id,
            )
        if kind == "hard_matchup" and belief_status == "unique":
            coverage = set(_list_of_strings(adapter.get("covers")))
            if candidates and not candidates <= coverage:
                _add(
                    violations,
                    line,
                    trace,
                    "hard_adapter_identity_mismatch",
                    f"{adapter_id}: expected {sorted(candidates)}, covers {sorted(coverage)}",
                )
        if kind == "robust_matchup" and belief_status == "ambiguous":
            coverage = set(_list_of_strings(adapter.get("covers")))
            if not candidates <= coverage:
                _add(
                    violations,
                    line,
                    trace,
                    "incomplete_robust_adapter_coverage",
                    f"{adapter_id}: missing {sorted(candidates - coverage)}",
                )

    forbidden = trace.get("forbidden_reasons")
    if not isinstance(forbidden, list):
        _add(violations, line, trace, "forbidden_reasons", "must be a list")
        forbidden = []
    for reason in forbidden:
        if not isinstance(reason, dict):
            _add(violations, line, trace, "forbidden_reason_shape", "must be an object")
            continue
        action_id = str(reason.get("action_id", ""))
        if str(reason.get("context_id", "")) not in valid_constraint_context_ids:
            _add(violations, line, trace, "stale_constraint", action_id)
        if action_id in mandatory:
            _add(violations, line, trace, "mandatory_forbidden", action_id)
        if action_id in terminal:
            _add(violations, line, trace, "terminal_forbidden", action_id)

    for detail in _finite_scores(trace):
        _add(violations, line, trace, "invalid_tactical_score", detail)
    scores = trace.get("tactical_scores")
    if isinstance(scores, dict) and not set(map(str, scores)) <= strategic:
        _add(
            violations,
            line,
            trace,
            "score_outside_strategic_mask",
            str(sorted(set(map(str, scores)) - strategic)),
        )
    future = trace.get("future_evidence")
    future_action_ids = {action_id for action_id, _ in _future_items(future)}
    if not isinstance(future, (dict, list)):
        _add(violations, line, trace, "future_evidence", "must be an object or list")
    elif not future_action_ids <= legal:
        _add(
            violations,
            line,
            trace,
            "future_created_legality",
            str(sorted(future_action_ids - legal)),
        )

    tiers = trace.get("base_hard_tiers")
    if not isinstance(tiers, dict):
        _add(violations, line, trace, "base_hard_tiers", "must be an object")
        tiers = {}
    base_selected = str(trace.get("base_selected_action_id", ""))
    tactical_preferred = str(trace.get("tactical_preferred_action_id", ""))
    selected = str(trace.get("selected_action_id", ""))
    override = trace.get("tactical_override_applied") is True
    tactical_took_control = bool(
        tactical_preferred and tactical_preferred != base_selected and selected == tactical_preferred
    )
    if override or tactical_took_control:
        if base_selected not in tiers or tactical_preferred not in tiers:
            _add(violations, line, trace, "missing_compared_hard_tier", "base/tactical action")
        elif tiers[base_selected] != tiers[tactical_preferred]:
            _add(
                violations,
                line,
                trace,
                "cross_hard_tier_tactical_takeover",
                f"{base_selected} != {tactical_preferred}",
            )
    if selected not in legal:
        _add(violations, line, trace, "selected_illegal", selected)
    if selected not in strategic:
        _add(violations, line, trace, "selected_strategically_ineligible", selected)
    if selected in vetoed:
        _add(violations, line, trace, "selected_base_vetoed", selected)
    fallback = str(trace.get("fallback_reason", ""))
    if fallback in ALL_REMOVED_FALLBACKS and strategic != legal:
        _add(
            violations,
            line,
            trace,
            "incomplete_base_frontier_fallback",
            f"missing {sorted(legal - strategic)}",
        )
    if not str(trace.get("audit_id", "")):
        _add(violations, line, trace, "missing_audit_id", "audit_id must be non-empty")
    if not str(trace.get("determinism_key", "")):
        _add(
            violations,
            line,
            trace,
            "missing_determinism_key",
            "determinism_key must be non-empty",
        )
    if schema_version == 2:
        _audit_v18(
            line,
            trace,
            violations,
            context_id=context_id,
            legal=legal,
            strategic=strategic,
            mandatory=mandatory,
            terminal=terminal,
        )


def _determinism_projection(trace: dict[str, Any]) -> str:
    fields = (
        "context_id",
        "active_adapters",
        "win_condition_weights",
        "goals",
        "goal_modifiers",
        "goal_states",
        "threat_clock",
        "macro_intents",
        "dominance_constraints",
        "legal_action_ids",
        "strategic_action_ids",
        "mandatory_action_ids",
        "terminal_action_ids",
        "forbidden_reasons",
        "tactical_scores",
        "future_evidence",
        "base_hard_tiers",
        "base_selected_action_id",
        "tactical_preferred_action_id",
        "tactical_override_applied",
        "base_vetoed_action_ids",
        "selected_action_id",
        "fallback_reason",
        "execution_exam",
        "counterfactual_exam",
        "plan_memory",
        "audit_id",
    )
    return json.dumps(
        {field: trace.get(field) for field in fields},
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    )


def build_report(traces: list[tuple[int, dict[str, Any]]]) -> dict[str, Any]:
    violations: list[dict[str, Any]] = []
    groups: dict[str, list[tuple[int, dict[str, Any]]]] = defaultdict(list)
    for line, trace in traces:
        audit_trace(line, trace, violations)
        key = str(trace.get("determinism_key", ""))
        if key:
            groups[key].append((line, trace))
    for key, values in groups.items():
        projections = {_determinism_projection(trace) for _, trace in values}
        if len(projections) > 1:
            for line, trace in values:
                _add(violations, line, trace, "deterministic_drift", key)
    return {
        "schema_version": 2,
        "ok": bool(traces) and not violations,
        "trace_count": len(traces),
        "determinism_group_count": len(groups),
        "violation_count": len(violations),
        "violations": violations,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    report = build_report(_read_traces(args.input))
    payload = json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    if args.output is not None:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(payload, encoding="utf-8", newline="\n")
    print(payload, end="")
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
