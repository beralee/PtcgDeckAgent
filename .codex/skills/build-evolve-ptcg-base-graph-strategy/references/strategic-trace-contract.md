# Base Graph v1.8 strategic trace contract

Emit one JSON object per decision to `strategic_trace.jsonl`. Trace v2 is the
evidence bridge between replay diagnosis, owner routing, exams, future labels,
model training, and promotion.

## Required v2 surface

Retain every v1 field and add the v1.8 planning fields:

```json
{
  "schema_version": 2,
  "trace_id": "trace-1",
  "scene_id": "scene-1",
  "decision_id": "decision-1",
  "determinism_key": "public-scene-frontier-hash",
  "base_context_id": "v17-context-hash",
  "context_id": "v18-context-hash",
  "public_only": true,
  "opponent_belief": {"status": "unique", "candidates": ["marnie"]},
  "active_adapters": [
    {"id": "deck.core", "kind": "core", "activation": "always", "covers": []}
  ],
  "win_condition_weights": {"prize_race": 1.0},
  "goals": [{"id": "board", "priority": 100, "source": "deck.core"}],
  "goal_modifiers": [],
  "goal_states": [{
    "state_id": "board-1",
    "goal_id": "board",
    "stage": "fund",
    "target_count": 2,
    "ready_count": 1,
    "priority": 100.0,
    "source": "deck.core",
    "deadline_turn": 7,
    "reserved_resource_ids": ["ultra-ball"],
    "recovery_reason": "",
    "context_id": "v18-context-hash"
  }],
  "threat_clock": {
    "own_attacks_to_win": 3,
    "opponent_attacks_to_win": 2,
    "goal_deadline_turn": 7,
    "confidence": 0.8,
    "source": "deck.matchup",
    "context_id": "v18-context-hash"
  },
  "legal_action_ids": ["a", "b"],
  "strategic_action_ids": ["a", "b"],
  "mandatory_action_ids": [],
  "terminal_action_ids": [],
  "forbidden_reasons": [],
  "dominance_constraints": [],
  "macro_intents": [{
    "intent_id": "search-attacker",
    "root_action_id": "a",
    "goal_state_id": "board-1",
    "start_stage": "fund",
    "projected_stage": "ready",
    "steps": [{"step_id": "search", "semantic": "search", "required": true}],
    "priority": 100.0,
    "confidence": 0.9,
    "source": "deck.core",
    "context_id": "v18-context-hash"
  }],
  "tactical_scores": {
    "a": {"total": 10.0, "components": {"macro_progress": 10.0}},
    "b": {"total": 0.0, "components": {}}
  },
  "future_evidence": {
    "a": {
      "action_id": "a",
      "context_id": "v18-context-hash",
      "horizon": 2,
      "expected_value": 25.0,
      "worst_case": -5.0,
      "lower_bound": 13.0,
      "confidence": 0.6,
      "branch_count": 2,
      "evidence_id": "future-a",
      "public_only": true,
      "complete": true
    }
  },
  "base_hard_tiers": {"a": [0, 1], "b": [0, 1]},
  "base_selected_action_id": "b",
  "tactical_preferred_action_id": "a",
  "tactical_override_applied": true,
  "base_vetoed_action_ids": [],
  "selected_action_id": "a",
  "fallback_reason": "",
  "plan_memory": {"reused_constraints": false, "reused_scores": false},
  "execution_exam": {
    "action_order_required": false,
    "final_public_state_exact": true,
    "final_hand_exact": true
  },
  "counterfactual_exam": {
    "separate_from_execution_score": true,
    "runtime_input": false
  },
  "audit_id": "stable-audit-hash"
}
```

Use arrays, stable key ordering, and stable semantic IDs. Do not use transient
option positions as identities.

## Invariants

The auditor fails closed when:

1. `public_only` is not true or a private-information key appears.
2. matchup belief/Adapter activation violates unique or robust coverage.
3. the strategic mask is not a subset of the legal mask.
4. a mandatory satisfier or terminal proof is filtered or forbidden.
5. a v1.7 or v1.8 constraint has a stale context.
6. a v1.8 hard constraint lacks a complete public dominance certificate,
   current dominant action, evidence IDs, or matching owner.
7. a goal uses an unknown stage or stale context.
8. a macro has a stale context, non-strategic root, missing current goal,
   invalid backward transition, or empty step list.
9. the threat clock is stale, negative, non-finite, or uncalibrated.
10. future evidence references an action outside the legal/strategic mask,
    uses another context/macro, is not exactly two turns, is private/incomplete,
    or lacks finite expected/worst/lower/confidence values.
11. a tactical, future, or learned selection crosses Base hard tiers.
12. the final action is illegal, strategically ineligible, or Base-vetoed.
13. an all-removed fallback does not restore its full input frontier.
14. persistent plan memory reuses prior constraints or scores.
15. the execution exam requires exact action order, or does not require exact
    final public state and hand.
16. counterfactual evidence is not a separate gate or becomes a runtime input.
17. identical `determinism_key` inputs produce different planning, masks,
    selection, fallback, or audit IDs.

Preserve failed traces. Do not sanitize and continue.

## Stable fallback vocabulary

- `adapter_exception_base_fallback`
- `strategic_filter_all_removed_base_fallback`
- `dominance_all_removed_base_fallback`
- `future_timeout_base_fallback`
- `future_unsupported_base_fallback`
- `future_exception_base_fallback`
- `model_low_support_base_fallback`
- `model_schema_mismatch_base_fallback`
- `model_non_finite_base_fallback`
- `base_veto`

Fallback must be deterministic for identical public input.

## Training and exam boundary

Runtime features may derive from public context, goals/stages, threat clock,
macro intents, masks, proofs, hard tiers, tactical components, validated future
evidence, and fallback state. Freeze trace/extractor hashes.

Outcome labels, future events, hidden continuation states, expert answers, and
final results are offline targets only. Execution exams compare exact final
public field and hand while ignoring action-order equivalence. Counterfactual
exams use disjoint continuation seeds and cannot compile live exact-state rules.

Retain trace v1 support only for auditing frozen v1.7 evidence. New v1.8
candidates must emit schema v2.
