---
name: upgrade-ptcg-deck-training-puzzles
description: Upgrade or audit existing fixed-deck PTCG deck-training puzzles with a graph-engineering workflow. Use when a 卡组训练/残局题 is too preassembled, the opening hand is too generous, Bench space and Supporter choice do not matter, a fixed witness hides plausible branches, opponent disruption is not fairly represented, or success must include setup, prizes, survival, disruption, and next-turn handoff. Produces a typed decision/resource/threat graph, AND-OR proof obligations, and an approval checkpoint before any scenario or runtime edits.
---

# Upgrade PTCG Deck Training Puzzles

Turn an existing calculation puzzle into a turn-construction puzzle that asks the
player to read public threats, allocate scarce resources, choose an expansion
route, attack, survive the reply, and preserve a credible next turn.

This skill extends, rather than replaces, the deck-first authoring discipline in
`../design-ptcg-deck-training-puzzles/`.

## Required Reading

Before acting, read all of:

- `../design-ptcg-deck-training-puzzles/SKILL.md`
- `../design-ptcg-deck-training-puzzles/references/deck-first-scenario-inference.md`
- `../design-ptcg-deck-training-puzzles/references/puzzle-quality-contract.md`
- `../design-ptcg-deck-training-puzzles/references/repository-workflow.md`
- [references/graph-engineering-model.md](references/graph-engineering-model.md)
- [references/puzzle-upgrade-contract.md](references/puzzle-upgrade-contract.md)
- [references/repository-upgrade-workflow.md](references/repository-upgrade-workflow.md)

## Non-Negotiable Separation

Use two explicit phases:

```text
graph design and approval -> implementation and production proof
```

During graph design:

- inspect code and data read-only;
- extract the current puzzle and its omitted choices into a graph;
- produce the proposed graph, graph delta, and proof obligations;
- run the static graph auditor;
- stop and ask for approval.

Do not edit scenario JSON, proof files, runtime code, UI copy, or catalog data
before the user approves the graph. A request to “先看图”, “先设计”, or “先不要改
代码” ends at the approval checkpoint.

## Graph Semantics

Model one heterogeneous property graph with:

- control nodes: `state`, `player_decision`, `action`,
  `opponent_decision`, `information`, and `terminal`;
- domain nodes: `resource`, `threat`, and `invariant`;
- control edges: `opens`, `option`, `reply`, `outcome`, `resolves`,
  and `reaches`;
- semantic edges: `consumes`, `reserves`, `enables`, `counters`,
  `exposes`, `constrains`, `satisfies`, and `violates`.

Interpret the control graph as an AND-OR game graph:

- `player_decision` is OR: at least one legal option must satisfy the contract;
- `opponent_decision` is AND: every credible reply must satisfy the contract;
- authored deterministic information has one outcome;
- unresolved chance is AND over every enumerated outcome;
- a `success` terminal requires every declared invariant.

Never call a single authored witness a unique solution. It proves only that one
route works. Uniqueness requires enumerating the plausible commitment branches,
running the adversarial graph, and rejecting every unintended passing branch.

## Workflow

### 1. Freeze Runtime And Deck Truth

1. Inspect `git status`; preserve unrelated work.
2. Resolve the exact 60-card deck and read every card involved in intended and
   tempting lines.
3. Read the state factory, goal evaluator, session finalization, proof adapter,
   production engine adapter, admission verifier, fixed AI policy, and tests.
4. Record current runtime limitations separately from puzzle-design defects.
5. Fix nothing yet.

### 2. Extract The Current Graph

Translate the current scenario without improving it:

```text
initial state -> legal commitment choices -> actions and costs
-> attack/checkpoint -> opponent replies -> terminal result
```

Add domain links for:

- Bench slots, Supporter window, manual attachment, Energy, Tools, discard
  ownership, switching, and prize liabilities;
- public or fairly deduced opponent threats;
- progress, disruption, survival, opponent-not-winner, and next-turn handoff;
- every visible search target and every attractive Supporter/ability choice.

Mark choices omitted by the current witness as `unproved`, not nonexistent.

### 3. Diagnose Graph Defects

Reject or redesign when the graph contains any of:

- a preassembled engine that removes the setup decision;
- a full Bench that makes a visible search card unusable;
- abundant resources with no opportunity cost;
- fewer than three plausible initial commitment choices in a deployment puzzle;
- a hidden threat the player could not fairly infer;
- an opponent reply represented by one convenient scripted line;
- a success terminal defined only by prizes or knockouts;
- a wrong choice that fails immediately instead of creating a delayed,
  instructive consequence;
- a supposedly essential action whose node or edge can be deleted without
  changing the root result.

### 4. Design The Target Graph

Work backwards from a compound success terminal:

```text
meaningful progress
AND survive every credible reply
AND opponent has not won
AND preserve the required engine/attacker
AND retain a legal next-turn closeout route
```

Then design:

1. the opponent’s fair, public threat;
2. at least one action that affects both player development and that threat;
3. scarce resource budgets with near-zero slack;
4. at least three plausible commitment branches;
5. a Bench-slot branch that changes survival or next-turn viability;
6. at least one tempting branch whose failure appears only after the reply;
7. the minimum state needed to make those branches legal—do not prebuild the
   answer.

Prefer partial shells: one engine piece, one or two open Bench slots, and enough
resources to complete one coherent route but not every route.

### 5. Compile And Present The Graph

Store the proposal as standalone design JSON outside production scenario data,
then run:

```powershell
python .codex/skills/upgrade-ptcg-deck-training-puzzles/scripts/audit_turn_construction_graph.py GRAPH.json
```

Present:

- a Mermaid graph;
- current graph versus proposed graph delta;
- resource budget table;
- public-threat evidence;
- player OR branches and opponent AND replies;
- compound success invariants;
- static audit result and unresolved runtime gaps.

Stop for user approval.

### 6. Implement Only After Approval

After explicit approval:

1. update runtime contracts before relying on new fields;
2. keep legacy puzzles compatible;
3. author the smallest scenario state that realizes the approved graph;
4. translate graph actions into production-legal interactions;
5. add positive route, per-axis negative probes, and opponent-reply coverage;
6. prove winner, survival, protected-board, and handoff invariants through the
   production engine;
7. compare the implemented graph fingerprint with the approved artifact;
8. run focused tests, the full puzzle pipeline, and affected card tests.

If the engine cannot express an approved edge, report the gap. Do not silently
weaken the graph to fit the current witness adapter.

## Difficulty Contract

For `deployment` and `composite` upgrades, require:

- at least three plausible initial commitment options;
- at least three scarce resources with at most one unit of slack;
- at least one delayed failure after an opponent response;
- at least one dual-purpose action: development plus threat control;
- at least one consequential Bench-slot choice;
- a correct route that combines attack, disruption, and handoff;
- no hidden-information clairvoyance.

Use raw action count only as a secondary metric. Branch consequence depth and
resource coupling define the main difficulty.

Across a ten-puzzle deck curriculum, target:

- two precision/calculation puzzles;
- five deployment/explosion puzzles;
- three deployment + disruption + survival composites.

## Deliverables

Before approval:

- current-state graph and defect report;
- proposed typed graph JSON and Mermaid rendering;
- resource/threat/invariant tables;
- static graph audit;
- explicit list of runtime features required after approval.

After approval:

- implemented scenario/runtime delta;
- graph-to-engine trace map;
- adversarial proof over credible replies;
- negative probes for every major commitment axis;
- production test results and honest proof status.
