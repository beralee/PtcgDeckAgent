# Base Graph v1.8 integration contract

Use this contract for authoring, migrating, reviewing, or packaging a deck
policy. Base Graph v1.8 extends v1.7; it does not replace inherited safety.

## Canonical sources

The implementation under `D:\ai\code\ptcgabc` is authoritative:

- `strategy_graph/base_runtime.py` and `base_graph_v1.py` through
  `base_graph_v1_6.py`: observation, legality, certificates, transactions,
  obligations, interactions, and execution;
- `strategy_graph/base_graph_v1_7.py`: public Strategic Context, Adapter
  activation, strategic masks, tactical scoring, hard tiers, and outcome gate;
- `strategy_graph/base_graph_v1_8.py`: typed goal states, threat clock, macro
  intent, proof-gated dominance, two-turn uncertainty evidence, plan memory,
  and strategic trace v2 payload;
- `strategy_graph/adapters/base_v1_8.py`: stable Adapter imports;
- `strategy_graph/base_graph_v1_8_architecture_contract.json`: machine contract;
- `tools/test_base_graph_v1_8_goal_state_framework.py`: executable contracts.

## Authority split

| Layer | Owns | Must not own |
| --- | --- | --- |
| CABT/Base legality | option binding, rule/resource certificates, attack/effect resolution | matchup preference |
| Transaction Graph | semantic executable frontier, journal, obligations, parent interaction | deck win rationale |
| Base outcome authority | mandatory/terminal protection, hard tiers, same-root robust result, final veto | same-tier preference |
| Strategic Context | acting-player-visible facts and public opponent belief | raw/private observation access |
| Core/Matchup Adapter | board-target proposals, matchup rationale, soft preferences | legality, hard tiers, hidden activation |
| Goal-state compiler | validate and bind current stages/deadlines/resources | invent deck goals |
| Macro compiler | bind current legal root, stage, steps, and context | execute or certify legality |
| Dominance filter | validate complete public proof | accept heuristic exclusions |
| Tactical scorer | same-hard-tier local preference | cross-tier takeover |
| Future evaluator | validate public two-turn branches and uncertainty | create legality or terminal proof |
| Learned head | residual sibling ranking | structural authority above |

Base and Adapter authority sets must remain disjoint.

## Action pipeline

Execute this order:

```text
generate
-> strategic_context
-> legality_filter
-> goal_state_compile
-> macro_intent_compile
-> strategic_filter
-> tactical_score
-> future_evaluate
-> uncertainty_score
-> base_graph_select
-> transaction_execute
-> reobserve_replan
```

If an Adapter or simulator fails, retain the inherited Base frontier. If a hard
filter removes every input action, restore its complete input frontier. Execute
one action, reobserve, and discard all previous bindings, constraints, scores,
and future values.

## Typed goal states

Use only these stages:

```text
Acquire -> Deploy -> Fund -> Ready -> Execute -> Maintain -> Recover
```

`StrategicGoalStateV18` declares a stable state and goal ID, stage, target and
ready counts, priority, owner, deadline, resource reservations, recovery reason,
and current context binding. Normal progress does not move backward. Any stage
may enter `Recover`; recovery may re-enter Acquire through Ready.

Model matchup strategy as a board target, not independent card bonuses. A goal
may describe alternate attackers or recovery branches, but every reservation
must be public and recomputed after each action.

## Macro intent

`MacroIntentV18` groups a semantic transaction across search, discard, target,
Bench, energy, switch, Supporter, or attack interactions. Require:

- a current Base-legal root action ID;
- a current goal state and matching start stage;
- a legal forward/recovery projected stage;
- one or more unique semantic steps;
- explicit consumed/produced resource labels;
- finite priority, confidence in `[0, 1]`, source, and current `context_id`.

Persist the selected intent/goal/stage only as an explanation and re-entry hint.
Never reuse an old option binding, constraint, score, or future value.

## Strategic exclusion

Keep v1.7 constraints for migrated policies, but author new v1.8 hard exclusions
through `StrategicConstraintV18`. Require a complete public
`DominanceCertificateV18` that names current dominant and dominated action IDs,
proof kind, evidence IDs, owner, and context. Supported proof families are
terminal, mandatory safety, exact resource, and robust future dominance.

Ignore stale, incomplete, private, unknown-action, or source-mismatched proofs.
Never filter a mandatory satisfier or terminal proof. Use soft scoring when the
claim is merely likely.

## Threat and future evidence

The Base public prize clock supplies a conservative default. An Adapter may
propose a more urgent public threat clock. Validate nonnegative own/opponent
attacks-to-win, deadline, confidence, source, and current context.

`FutureSimulationV18` covers exactly two turns: current action, public opponent
response, and next own turn. Each branch declares probability, utility,
confidence, opponent response, threat/resource margins, completeness, and
public-only status. Normalize probabilities and calculate:

```text
expected = probability-weighted branch utility
worst = minimum branch utility
uncertainty_floor = min(worst, 0)
lower_bound = confidence * expected + (1 - confidence) * uncertainty_floor
```

Attach evidence only to an existing strategically eligible action. Fall back on
timeout, unsupported state, wrong context/action/macro ID, wrong horizon,
private/incomplete branch, non-finite value, or zero probability.

## Selection and learned boundary

Combine inherited tactical score, explicit macro progress, and future lower
bound. Base chooses only inside the inherited best hard tier. Outcome authority
and veto remain final.

A learned head may consume public trace v2 features and rank only strategically
eligible siblings in one hard tier. Require schema/model hashes, support and
confidence gates, protected domains, finite outputs, and deterministic Base
fallback. It cannot mutate goals, stages, macro bindings, masks, activation,
mandatory/terminal state, hard tiers, future legality, or veto.

## Exam boundary

Keep two independent gates:

- execution equivalence ignores exact action order but requires exact final
  public field and exact final hand;
- counterfactual outcome runs alternate legal routes under isolated continuation
  seeds and supplies offline labels only.

Never turn evaluation labels, future outcomes, hidden continuation state, or
exact evaluation keys into runtime inputs.

## Required capabilities

Declare the inherited v1.1 and all v1.7 capabilities, plus every v1.8
capability from the machine contract. A candidate missing either inherited or
v1.8 capabilities is not a Base Graph v1.8 candidate.
