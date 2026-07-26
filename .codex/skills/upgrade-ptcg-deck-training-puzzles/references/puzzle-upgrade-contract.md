# Puzzle Upgrade Contract

## Upgrade Objective

An upgraded puzzle should teach:

```text
read public threat
-> choose a deployment route under scarcity
-> accept opportunity costs
-> create meaningful progress
-> blunt the opponent's best credible reply
-> preserve a next-turn plan
```

It should not merely teach “click the already prepared attacker”.

## Required Graph Header

Each standalone design graph must declare:

```json
{
  "format_version": 1,
  "puzzle_id": "design-only identifier",
  "deck_id": "frozen deck id",
  "revision": 1,
  "profile": "precision | deployment | composite",
  "start": "initial state node id",
  "nodes": [],
  "edges": [],
  "proof": {}
}
```

The graph artifact is design input. It is not production scenario data and must
not be registered in the catalog before approval.

## Node Contract

### State

Required properties:

- `id`, `kind: state`, `label`;
- `fingerprint`: exact state facts that must remain stable;
- `checkpoint`: player turn/AI turn/information epoch.

### Decision

Player:

```json
{"kind": "player_decision", "operator": "OR", "axis": "supporter_choice"}
```

Opponent:

```json
{
  "kind": "opponent_decision",
  "operator": "AND",
  "credible_set": true,
  "coverage_basis": "board, public history, production legal actions"
}
```

`FROZEN` is permitted only for compatibility analysis and downgrades proof to
`policy_replay_proven`.

### Action

Required properties:

- `label`;
- `actor: player | opponent | system`;
- `axis`: commitment category;
- `legal_guard`: why it is legal in the source state;
- `effect_summary`: production-observable delta.

Use an atomic macro only when every inner step is deterministic and later
production tracing expands it.

### Information

Required properties:

- `operator: DETERMINISTIC | AND`;
- `epoch`: identifier invalidated by a shuffle or zone reorder;
- `source`: natural draw, ability, search, Prize pickup, etc.

Never keep a top-deck guarantee across a shuffle without creating a new epoch.

### Resource

Required properties:

```json
{
  "kind": "resource",
  "resource_type": "bench_slot | supporter_window | manual_attachment | energy | tool | discard | switch | prize_liability | other",
  "available": 1,
  "minimum_required": 1,
  "slack": 0,
  "deadline": "before first attack",
  "scarce": true
}
```

`slack` must equal `available - minimum_required`.

### Threat

Required properties:

- `visibility: public | history | deduced`;
- specific `evidence`;
- `deadline`;
- concrete `impact`.

### Invariant

Use categories:

- `progress`: prize, KO, board development, or threshold reached;
- `disruption`: the declared opponent threat is reduced;
- `survival`: required attacker/engine survives the reply;
- `deny_opponent_win`: opponent has not won at the terminal check;
- `handoff`: a legal next-turn attacker/closeout/resource route remains.

### Terminal

Required properties:

- `outcome: success | failure`;
- `reason`;
- for failures, `failure_axis` and `consequence_depth`.

A success terminal needs `requires` edges to every mandatory invariant.

## Edge Contract

Control edges:

| Edge | From | To | Meaning |
|---|---|---|---|
| `opens` | state | decision/information | next control point |
| `option` | player decision | action | legal player choice |
| `reply` | opponent decision | action | credible opponent response |
| `outcome` | information | state/action | reveal/chance result |
| `resolves` | action | state/terminal | state transition |
| `reaches` | state | terminal | terminal evaluation |

Semantic edges can connect action/state/resource/threat/invariant nodes:

`consumes`, `reserves`, `enables`, `counters`, `exposes`, `constrains`,
`satisfies`, `violates`, and `requires`.

## Profile Gates

### Precision

- at least two plausible commitment choices;
- at least two scarce resources;
- exact damage/Energy/prize equation;
- one positive and two distinct negative branches;
- no uncontrolled chance.

Limit this profile to roughly 20% of a deck curriculum.

### Deployment

- at least three plausible commitment choices;
- at least three scarce resources;
- one consequential Bench-slot choice;
- one dual-purpose development/threat-control action;
- at least one depth-2 or depth-3 failure;
- progress, survival, and handoff invariants.

### Composite

All deployment gates, plus:

- progress, disruption, survival, deny-opponent-win, and handoff invariants;
- an `AND` opponent decision with all credible high-impact replies;
- at least three negative commitment axes;
- correct route performs attack, disruption, and handoff;
- no single convenient fixed AI reply may stand in for adversarial coverage.

## Current-To-Target Delta

For every upgrade, report:

| Dimension | Current | Target |
|---|---|---|
| initial engine completion | how much is prebuilt | minimum partial shell |
| opening Bench capacity | occupied/free | slots as scarce resource |
| opening hand | abundance/repeated core | awkward but legal categories |
| commitment branches | represented/omitted | explicit player OR nodes |
| opponent behavior | one witness line | credible reply AND node |
| goals | prize/KO only | compound invariants |
| negative proof | generic lures | one probe per commitment axis |
| proof claim | witness replay | qualified graph/production status |

## Mutation And Shortcut Tests

After approval and implementation, require:

- delete each intended action; root must fail or the action is decorative;
- add each omitted legal search target; unintended solutions must be understood;
- vary Supporter choice while preserving the same initial hidden state;
- vary Tool owner, Energy owner, Bench target, attack target, and retreat choice;
- run every credible opponent reply;
- check terminal winner before granting goal success;
- remove one resource unit at a time and confirm the predicted deficit;
- add one resource unit at a time and check whether the puzzle collapses;
- compare the production state fingerprint at every graph checkpoint.

## Curriculum Coverage

Across ten puzzles:

- 2 precision;
- 5 deployment;
- 3 composite.

Track lesson coverage by graph relationships, not card names. Two puzzles are
duplicates when their resource/threat/invariant subgraphs are isomorphic after
renaming cards.
