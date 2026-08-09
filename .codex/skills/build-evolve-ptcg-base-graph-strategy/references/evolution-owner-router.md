# Base Graph v1.8 evolution owner router

Diagnose the earliest causal divergence and assign one owner layer. Do not turn
every loss into a Graph patch or every preference into a hard constraint.

## Ordered routing table

Apply the first proved row.

| First causal evidence | Owner | Patch type |
| --- | --- | --- |
| exception, timeout, entrypoint, stale session | runtime/integration | `runtime_integration` |
| invalid action, bad rule/resource certificate, impossible effect | Base legality | `base_legality` |
| legal semantic route absent or atomic sequence missing | transaction Graph | `graph_transaction` |
| route correct but target/count/order/payment binding wrong | interaction binder | `interaction` |
| public fact or opponent belief missing before planning | Strategic Context | `strategic_context` |
| deck-wide or matchup rationale wrong | Core/Matchup Adapter | `core_adapter` / `matchup_adapter` |
| objective priority wrong but stage is correct | goal modifier | `goal_modifier` |
| Acquire/Deploy/Fund/Ready/Execute/Maintain/Recover state wrong | goal-state machine | `goal_state_machine` |
| goal correct but multi-action semantic route absent/stale | macro intent | `macro_intent` |
| public deadline or opponent response clock wrong | threat clock | `threat_clock` |
| hard exclusion lacks complete public proof | dominance constraint | `dominance_constraint` |
| eligible same-tier actions rank badly locally | tactical scorer | `tactical_scorer` |
| public two-turn expected/worst/confidence value missing | future simulator | `future_simulator` |
| execution and counterfactual exams are conflated | exam contract | `exam_contract` |
| hard Adapter activation/robust coverage wrong | matchup activation | `matchup_activation` |
| structural layers are proved correct; residual same-tier rank remains | learned head | `learned_head` |
| no better public branch within budget | none | `irreducible` |

Base ownership requires deck-neutral evidence. Matchup board targets and card
roles stay in Adapters even when they affect resource use.

## Evidence sequence

1. Align the replay and locate the first policy divergence.
2. Reconstruct the complete Base-legal frontier.
3. Audit public context, belief, active Adapters, goals, goal stages, threat
   clock, macro intents, legal/strategic masks, dominance certificates,
   tactical/future evidence, hard tiers, Base veto, and final selection.
4. Prove the proposed owner could change that divergence without violating an
   earlier authority layer.
5. Preserve positive, negative, boundary, metamorphic, timeout, and stale-
   context scenes.
6. Split independent owners. Bundle only one typed causal transaction.

## Canonical failure classes

Use explicit `failure_class` where possible:

- `runtime_failure`, `invalid_action`, `legality_mismatch`,
  `resource_certificate_failure`, `attack_resolution_failure`;
- `missing_route`, `transaction_sequence_failure`,
  `interaction_binding_failure`, `public_context_missing`;
- `wrong_win_condition`, `wrong_goal_priority`, `wrong_goal_stage`,
  `goal_stage_stalled`, `missing_macro_intent`,
  `macro_intent_binding_failure`, `threat_clock_error`;
- `strategic_constraint_missing`, `matchup_constraint_missing`,
  `unproven_hard_constraint`, `same_hard_tier_misrank`;
- `multi_turn_value_missing`, `uncertainty_calibration_failure`,
  `exam_contract_failure`, `matchup_activation_failure`;
- `learned_residual_error`, `irreducible`.

If the class is absent, provide explicit boolean signals. Unresolved means
collect more evidence.

## Owner record

Append the mechanical classifier output to `owner_route_decisions.jsonl`:

```json
{
  "schema_version": 2,
  "failure_id": "pair:seat0:game12:decision7",
  "owner_layer": "macro_intent",
  "patch_type": "macro_intent",
  "classification_basis": "missing_macro_intent",
  "required_evidence": ["current legal root", "typed semantic route"],
  "learned_control": "prohibited",
  "resolved": true
}
```

## Hypothesis

State one falsifiable hypothesis:

```text
Given <public scene>, changing <one owner/patch> changes the first divergence
from <old semantic action> to <new action>, advances <goal stage>, flips <paired
outcomes>, and preserves <protected scenes/invariants>.
```

Name source replay/trace IDs, expected flips and non-flips, tests, trace
assertions, rollback/fallback, and untouched discovery/confirmation families.
Reject a patch whose owner does not match the earliest divergence even if a
training score rises.
