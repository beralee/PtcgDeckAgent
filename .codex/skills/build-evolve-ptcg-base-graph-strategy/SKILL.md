---
name: build-evolve-ptcg-base-graph-strategy
description: Build, migrate, or evolve a clean-room PTCGABC/CABT deck strategy on Base Graph v1.8. Route failures to legality, transaction Graph, interaction binding, Strategic Context, Core/Matchup Adapter, typed goal stage, macro intent, threat clock, proof-gated constraint, tactical scorer, two-turn uncertainty simulator, exam contract, matchup activation, or residual learned head. Use for fixed-deck policy construction, v1.7-to-v1.8 migration, matchup board-target planning, replay-driven optimization, strategic-trace v2 auditing, TDD, and isolated Bench v7 promotion.
---

# Build and Evolve Base Graph v1.8

Build deck intelligence on the shared Base Graph v1.8 goal-state framework.
Keep legality, resources, transactions, mandatory obligations, terminal proofs,
hard tiers, outcome authority, and execution in Base. Put deck and matchup
judgment in public-only Adapters.

## Canonical environment

Use `D:\ai\code\ptcgabc` when it exists. Read its `AGENTS.md` before commands.
Require these sources:

- `strategy_graph/base_graph_v1_7.py` for inherited strategic safety;
- `strategy_graph/base_graph_v1_8.py` for goal, macro, dominance, and future planning;
- `strategy_graph/base_graph_v1_8_architecture_contract.json`;
- `strategy_graph/adapters/base_v1_8.py`;
- `tools/test_base_graph_v1_8_goal_state_framework.py`;
- `bench/meta_recent100_20260809_v7` and `tools/assert_bench_v7.py`.

Stop if any v1.8 prerequisite or frozen Bench v7 contract is absent. Do not
silently downgrade to v1.7 or use another benchmark for comparable evidence.

## Read before acting

- Read [references/base-graph-v1.8-contract.md](references/base-graph-v1.8-contract.md)
  before policy design, migration, or composition.
- Read [references/evolution-owner-router.md](references/evolution-owner-router.md)
  before classifying a replay or choosing a patch.
- Read [references/strategic-trace-contract.md](references/strategic-trace-contract.md)
  before producing traces, exams, training features, or learned control.
- Read [references/v1.8-tdd-and-promotion.md](references/v1.8-tdd-and-promotion.md)
  before tests, replay work, Bench, or promotion decisions.

## Non-negotiable authority

- Instantiate `BaseGraphRuntimeV18` and `BaseGraphV18` for new policies.
- Preserve the inherited v1.7 legal/strategic masks, mandatory and terminal
  protection, public matchup activation, hard tiers, outcome authority, and
  Base final veto.
- Compile Adapters from `StrategicContextV18`; never pass raw observations or
  opponent-private state.
- Recompile after every action. Persist only semantic plan identity and goal
  stage; never reuse an old constraint, score, future value, or option binding.
- Apply a hard v1.8 constraint only with a complete public
  `DominanceCertificateV18`. Keep ordinary preferences soft.
- Attach every macro intent to a currently legal root action, current context,
  current goal state, and an auditable semantic step list.
- Use public two-turn future branches with expected value, worst case,
  confidence, and deterministic fallback. Future evidence cannot create a
  legal action or cross a Base hard tier.
- Permit learned control only as confidence-gated residual ranking among
  strategically eligible siblings in one hard tier.

## Workflow

### 1. Freeze the run

Keep the deck fixed unless the user explicitly requests a deck experiment.
Freeze the champion, candidate, deck, Base sources, Bench v7 lanes, engine,
seeds, traces, and evaluation populations.

```powershell
python <skill-dir>\scripts\init_strategy_run.py `
  --repo-root D:\ai\code\ptcgabc `
  --run-id <deck>_base_graph_v1_8_<date> `
  --deck-id <deck> `
  --deck-csv agents\<source>\deck.csv `
  --candidate-dir agents\<deck>_base_graph_v1_8_candidate `
  --champion-dir agents\<frozen-champion> `
  --training-seed <seed-a> `
  --discovery-seed <seed-b> `
  --confirmation-seed <seed-c>
```

### 2. Diagnose the first causal divergence

Reconstruct the complete Base-legal frontier and trace. Route the earliest
wrong layer, not the final losing symptom. Run:

```powershell
python <skill-dir>\scripts\classify_strategic_failure.py `
  --input <failure-records.jsonl> `
  --output <owner-route-decisions.json>
```

Require one falsifiable owner-local hypothesis, expected flips, protected
non-flips, failing tests, trace assertions, and rollback behavior.

### 3. Define matchup board targets

For each publicly identified or robustly covered matchup, declare one or more
typed goals using `Acquire -> Deploy -> Fund -> Ready -> Execute -> Maintain ->
Recover`. Specify target pieces, ready count, deadline, reserved resources, and
recovery trigger. Avoid card-name bonuses without a declared board target.

### 4. Compile semantic routes

Represent multi-action setup as `MacroIntentV18`: legal root action, goal state,
start/projected stage, ordered semantic steps, consumed/produced resources,
priority, confidence, source, and current `context_id`. Keep target/count/
discard/payment prompts parent-bound to the transaction.

### 5. Separate exclusion from preference

Use a hard constraint only when another current action publicly and completely
dominates it. Protect mandatory satisfiers and terminal proofs. Express
uncertain matchup value through goal priority, macro progress, tactical score,
or future lower bound.

### 6. Evaluate two-turn value

Simulate the candidate's legal first action, best public opponent response,
and next own turn. Record threat and resource margins per branch. Rank by the
confidence-adjusted lower bound; fall back on timeout, unsupported state,
non-public evidence, incomplete branches, or uncertainty.

### 7. Build exams

Keep execution equivalence and counterfactual outcome as separate gates:

- execution exam: action order need not match; final public field and final
  hand must match exactly;
- counterfactual exam: execute legal sibling routes under isolated continuation
  seeds and compare outcomes; labels are offline targets, never runtime inputs.

Create positive, negative, boundary, metamorphic, timeout, stale-context,
unique/ambiguous/unknown matchup, and same-hard-tier fixtures.

### 8. Verify the candidate

```powershell
python <skill-dir>\scripts\verify_candidate_contract.py `
  --repo-root D:\ai\code\ptcgabc `
  --candidate-dir agents\<deck>_base_graph_v1_8_candidate `
  --output <candidate-contract-check.json>

python <skill-dir>\scripts\audit_strategic_trace.py `
  --input <strategic_trace.jsonl> `
  --output <strategic_trace_audit.json>
```

Reject private information, stale goal/macro/threat evidence, unproved hard
constraints, future-created legality, cross-tier takeover, exam-boundary leak,
or deterministic drift.

### 9. Validate and promote

Run cheap deterministic contracts first, then native both-seat smoke, targeted
paired diagnostics, Bench v7 discovery, and unchanged-candidate confirmation.
Run `tools/assert_bench_v7.py` before every aggregate lane. Use
`ladder_weighted`, `top10_frontier`, and `strong_policy_anchors`; passing one
lane is not promotion. Do not modify the champion or submit externally without
separate user authorization.

## Report

Return the first-divergence taxonomy, owner and patch type, goal-stage and macro
changes, proof/future evidence, exam scores, trace audit, deterministic/native
results, paired Bench v7 deltas and confidence, regressions, verdict, hashes,
paths, and whether champion, deck, Git, or Kaggle changed.
