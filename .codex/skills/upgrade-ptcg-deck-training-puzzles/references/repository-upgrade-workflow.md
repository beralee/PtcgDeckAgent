# Repository Upgrade Workflow

## Existing Production Surface

Read these before proposing runtime changes:

- `data/deck_training/scenarios.json`
- deck-specific overlays under `data/deck_training/`
- `data/deck_training/shortcut_probes.json`
- `data/deck_training/proofs/`
- `scripts/training/DeckTrainingCatalog.gd`
- `scripts/training/DeckTrainingStateFactory.gd`
- `scripts/training/DeckTrainingGoalEvaluator.gd`
- `scripts/training/DeckTrainingSession.gd`
- `scripts/training/DeckTrainingAdmissionVerifier.gd`
- `scripts/training/proof/DeckTrainingWitnessProofAdapter.gd`
- `scripts/training/proof/DeckTrainingEngineProofAdapter.gd`
- `scripts/training/proof/DeckTrainingProofSolver.gd`
- `scripts/training/pipeline/DeckTrainingPuzzlePipeline.gd`
- `scripts/tools/prove_deck_training_scenario.gd`
- `scripts/tools/run_deck_training_puzzle_pipeline.gd`
- `tests/test_deck_training_poc.gd`
- `tests/test_deck_training_puzzle_pipeline.gd`
- `tests/test_deck_training_presentation.gd`

Also read the exact rule-AI profile used by the opponent and every card/effect
script involved in the graph.

## Known Architectural Questions To Re-Audit

Do not assume old findings remain true. Verify:

1. whether the goal evaluator supports winner, survival, protected-board, and
   handoff invariants or only prize/target goals;
2. whether session finalization checks winner before goal completion;
3. whether the witness adapter emits all legal choices or only the next authored
   step;
4. whether fixed AI proof covers one policy line or enumerates credible replies;
5. whether proof certificates distinguish witness existence, policy replay,
   adversarial coverage, and uniqueness;
6. whether the state factory can represent public action history used as fair
   threat evidence.

Report these as runtime gaps. Do not hide them inside scenario prose.

## Design-Only Phase

Create proposed graph artifacts under a temporary or review-only path such as:

```text
artifacts/deck_training_graphs/<deck_key>/<puzzle_id>.graph.json
```

Do not add that path to production loaders. Run the static graph auditor and
show the graph to the user.

Expected design-only outputs:

- current graph;
- proposed graph;
- graph delta;
- resource budget;
- threat evidence;
- compound invariants;
- proof qualification;
- anticipated runtime work.

Stop here until approval.

## Post-Approval Implementation Order

### Stage A: Contracts And Compatibility

1. Add versioned graph/invariant fields without breaking legacy scenarios.
2. Keep the current simple goal format as a legacy adapter.
3. Make terminal evaluation check actual game winner before scenario goals.
4. Add exact proof-status labels.
5. Add parser/schema tests before scenario changes.

### Stage B: Graph-To-Engine Adapter

1. Map graph checkpoints to production state fingerprints.
2. Enumerate legal player options at declared decision axes.
3. Enumerate or explicitly freeze opponent reply sets.
4. Treat shuffle/reveal boundaries as information epochs.
5. Enforce depth and turn budgets.
6. Fail closed when an approved edge cannot map to a legal engine interaction.

Do not replace the legacy witness adapter in one sweep. Add the graph path beside
it, migrate one approved puzzle, compare results, then widen usage.

### Stage C: Puzzle Data

1. Reduce the prebuilt board to the approved partial shell.
2. Make Bench space, Supporter use, attachment, and exact Energy real resources.
3. Encode fair threat history in production-readable state.
4. Add compound goals.
5. Expand negative probes per commitment axis.
6. Preserve frozen deck legality and 60-card conservation.

### Stage D: Proof

Require:

- graph static compile;
- production legality for every edge;
- positive OR route;
- all AND replies for the accepted route;
- negative probes from the identical initial state;
- state-fingerprint equality at checkpoints;
- no shorter or lower-resource unintended route;
- correct terminal winner handling;
- generated proof certificate with qualified status.

## Test Matrix

### Schema And Compiler

- duplicate IDs;
- dangling edges;
- orphan states;
- mixed routing types;
- hidden threat with no evidence;
- missing invariant;
- false root;
- unbounded cycle;
- claimed negative axis with no failure.

### Goal Evaluation

- player reaches prize goal and wins;
- player reaches prize goal but opponent wins on reply;
- required engine survives/fails;
- handoff route exists/does not exist;
- opponent-not-winner is mandatory;
- legacy prize-only scenario remains compatible.

### Decision Coverage

- every declared player axis enumerates production-legal options;
- alternate Nest Ball/search targets are represented;
- Supporter alternatives share the same hidden state;
- every credible opponent response is either covered or documented as excluded;
- fixed-policy proof cannot be mislabeled adversarial.

### Information Integrity

- natural draw before/after shuffle;
- ability draw;
- search shuffle invalidates old epoch;
- Prize reveal;
- deterministic authored order;
- no route changes seed, deck order, Prize layout, or AI policy.

### End-To-End

- construct through `DeckTrainingStateFactory`;
- play accepted route in `GameStateMachine`;
- cross the opponent turn;
- evaluate all invariants;
- compare every checkpoint fingerprint;
- run deck-training POC and pipeline suites;
- run affected card-effect tests.

## Rollout Gate

Migrate one approved puzzle first. Promote only when:

- legacy tests stay green;
- graph and production traces agree;
- proof status is honest;
- the puzzle cannot pass by prizes alone;
- no major legal commitment branch is absent;
- the player-facing objective does not leak the route.

Only then use the same workflow for the remaining Gardevoir or other deck
puzzles.
