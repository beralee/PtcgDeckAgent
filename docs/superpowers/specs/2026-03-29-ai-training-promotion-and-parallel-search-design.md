# AI Training Promotion And Parallel Search Design

Date: 2026-03-29

## 1. Background

The current training pipeline can already run:

- phase 1 self-play evolution
- phase 2 value-net training
- fixed benchmark gating
- playable AI version publication

However, the overnight run on 2026-03-29 exposed two high-priority problems:

1. Serial promotion semantics are not actually enforced.
2. Parallel search cannot be scaled safely on top of the current shared state.

Observed symptoms:

- Multiple training rounds completed with valid artifacts.
- Each round produced self-play data, a value net, and a benchmark summary.
- None of the first five overnight rounds passed the benchmark gate.
- The rounds did not behave like a clean `approved best -> challenger -> gate -> next best` chain.

This design addresses that in two phases:

- Phase A: fix the serial promotion pipeline so it is trustworthy.
- Phase B: add wide heterogeneous parallel search on top of the corrected semantics.

## 2. Goals

### 2.1 Phase A goals

1. Ensure each training round has a clear, explicit starting point.
2. Ensure only benchmark-approved versions become official promotion baselines.
3. Prevent benchmark-failed candidates from polluting later rounds.
4. Improve run logs and run metadata so training decisions are explainable.
5. Preserve the existing fixed three-deck benchmark target:
   - Miraidon
   - Gardevoir
   - Charizard ex

### 2.2 Phase B goals

1. Run large-breadth parallel search safely, starting at about 20 lanes.
2. Use heterogeneous search profiles instead of identical workers.
3. Keep only benchmark-passed candidates in a qualified pool.
4. Launch deeper second-round training only from the qualified pool.
5. Allow future expansion beyond 20 lanes if machine resources permit it.

### 2.3 Non-goals

1. Replace the current AI architecture with a new RL framework.
2. Expand the benchmark deck pool in this phase.
3. Publish every intermediate artifact to the game UI.
4. Treat benchmark-failed candidates as official progress.

## 3. Problem Analysis

### 3.1 Promotion semantics are currently leaky

The intended behavior is:

`current approved best -> new candidate -> benchmark -> pass then promote`

The actual current behavior is closer to:

`global latest saved phase1 agent -> new candidate -> benchmark summary recorded`

This is caused by two implementation issues:

1. `train_loop.sh` passes `--agent-config`, but `TunerRunner.gd` does not actually parse and apply it.
2. `EvolutionEngine.gd` falls back to `AgentVersionStore.load_latest()` when no explicit initial config is provided.

As a result:

- serial rounds are not reliably chained through the last benchmark-approved result
- phase1 accepted mutants can silently influence later rounds even when benchmark failed

### 3.2 Shared state blocks safe parallelism

The current training loop shares these global locations:

- `ai_agents`
- root `training_data`
- run registry
- version registry

This creates multiple hazards for parallel execution:

1. workers can race on "latest agent" lookup
2. workers can move each other's exported `game_*.json` files
3. workers can overwrite assumptions about the current baseline
4. logs and artifacts become hard to attribute to a single lane

### 3.3 Benchmark failures are structural, not just slightly weak

The first five overnight rounds failed for two reasons:

1. total win rate stayed far below the 0.55 gate
2. pairing-level health checks failed due to capped matches and unhealthy pairing summaries

So the problem is not only "candidate is a bit weaker." It is also "candidate quality is structurally unstable."

## 4. Phase A Design: Correct Serial Promotion

### 4.1 Explicit baseline contract

Every training round must declare these four values explicitly:

- `baseline_agent_config_path`
- `baseline_value_net_path`
- `candidate_agent_config_path`
- `candidate_value_net_path`

These must be persisted in the run record and benchmark summary.

No component may infer the baseline from "latest file in a shared directory" unless that behavior is explicitly requested for manual experiments.

### 4.2 TunerRunner start-point behavior

`TunerRunner.gd` must support three mutually understandable start modes:

1. explicit `--agent-config=<path>`
   - highest priority
   - uses that exact config as the phase1 starting point

2. explicit `--from-latest`
   - loads the latest approved or explicitly requested baseline source
   - must not silently mean "latest raw phase1 file"

3. no start override
   - uses a known default baseline only in manual local runs

Required rule:

- if `--agent-config` is present, `EvolutionEngine.run(initial_config)` must receive that config directly
- it must not fall back to `AgentVersionStore.load_latest()`

### 4.3 Promotion boundary

Phase1 and benchmark output must be treated as different classes of artifact.

Definitions:

- `phase1 candidate`
  - accepted by local evolution inside one run
  - useful for self-play generation and value-net training
  - not an official baseline

- `approved version`
  - passed fixed benchmark gate
  - eligible to become the next official baseline
  - eligible for playable publication

Required rule:

- only approved versions can become the baseline of later official training rounds
- benchmark-failed runs stay visible for analysis, but cannot become default parents

### 4.4 Approved baseline source

Introduce a single authoritative baseline source for official training:

- latest approved training version

This source should be readable by:

- serial training loop
- future parallel lane launcher
- in-game "latest trained AI"

It must not be derived from:

- latest `ai_agents` file by timestamp
- latest phase1 save
- latest run directory

### 4.5 Run metadata and logging

Each run record must include:

- run id
- parent baseline id
- parent baseline paths
- lane id or serial round id
- training parameters
- self-play sample count
- candidate paths
- benchmark result
- promotion result

Human-readable logs must make these questions trivial to answer:

1. What baseline did this run start from?
2. What candidate did it produce?
3. Did it pass benchmark?
4. If not, why not?
5. If yes, what became the new official best?

### 4.6 Phase A acceptance criteria

Phase A is complete when:

1. two consecutive serial rounds clearly show:
   - round N starts from approved baseline B
   - round N candidate fails benchmark
   - round N+1 still starts from baseline B, not from failed candidate

2. an approved candidate correctly becomes the next baseline

3. the run records and logs are sufficient to reconstruct the parent-child chain without guessing

## 5. Benchmark Gate Definition

The current effective benchmark gate remains:

1. candidate total win rate vs current best must be at least `0.55`
2. all pairing regression gates must pass
3. capped matches and structural unhealthy states must fail the gate

This design keeps that gate for now.

Rationale:

- current observed candidates are far below the gate, so relaxing the gate now would hide real quality issues
- parallel breadth should improve candidate discovery before benchmark criteria are weakened

## 6. Phase B Design: Parallel Heterogeneous Search

Phase B starts only after Phase A semantics are correct.

### 6.1 Topology

Parallel search uses three layers:

1. `20-lane heterogeneous qualification round`
2. `qualified pool`
3. `deeper round` launched from pool members

### 6.2 Qualification round

All lanes start from the same approved baseline.

Each lane is isolated and writes to its own:

- self-play export root
- run root
- local candidate storage
- log files

All lanes read the same approved baseline snapshot, but they must not share mutable intermediate outputs.

### 6.3 Heterogeneous lane groups

The 20 lanes are split into four groups of five:

1. conservative group
   - smaller sigma
   - medium generations
   - medium epochs
   - goal: maximize benchmark stability

2. standard group
   - near-default training recipe
   - goal: mainline balanced search

3. aggressive group
   - larger sigma
   - broader search radius
   - goal: discover distant improvements

4. deep-search group
   - longer generations
   - longer value-net training
   - goal: spend more time on fewer but potentially stronger lines

The exact parameter table can be finalized in the implementation plan.

### 6.4 Qualified pool

Only benchmark-passed candidates enter the pool.

Each pool entry stores:

- approved version id
- parent baseline id
- lane recipe id
- benchmark summary
- health metrics
- artifact paths

Pool admission order:

1. benchmark structural health
2. total win rate
3. optional diversity retention if many entries pass

### 6.5 Pool trimming strategy

If few lanes pass, keep all passed lanes.

If many lanes pass:

1. drop unhealthy or borderline entries first
2. then sort by benchmark quality
3. optionally retain some diversity across lane groups instead of taking only one parameter family

This avoids collapsing the pool into one narrow local optimum too early.

### 6.6 Deeper round

Deeper training starts only from qualified pool entries.

Differences from qualification round:

- longer generations
- more self-play data
- longer epochs
- potentially stricter benchmark volume

This stage trades breadth for depth only after candidate quality is proven.

## 7. Isolation Requirements For Parallelism

Parallel lane safety requires lane-local writable roots for:

- exported self-play data
- candidate model outputs
- lane logs
- lane run metadata

Shared global writes must be limited to:

- approved baseline snapshots
- qualified pool publication
- final playable version publication

Recommended pattern:

- lane-local work directories for training
- central append-only publication step for approved outputs

No lane should ever discover its parent baseline by scanning a mutable shared directory for the latest file.

## 8. Logging Requirements

The user explicitly wants logs that help diagnose training problems.

For every lane and every round, logs should include:

- lane id
- baseline id
- recipe id
- self-play sample count
- candidate config path
- candidate value-net path
- benchmark total win rate
- per-pairing result
- cap termination rate
- failure counts
- promotion decision

For failed benchmark runs, logs should clearly say whether the main reason was:

- low total win rate
- capped matches
- failed pairing health
- missing artifacts
- runtime failure

## 9. Recommended Execution Order

Implementation should happen in this order:

1. fix explicit baseline injection in serial training
2. fix promotion boundary so failed candidates cannot become official parents
3. improve run record and logs
4. verify serial promotion chain behavior
5. add lane-local isolation primitives
6. add 20-lane heterogeneous qualification launcher
7. add qualified pool handling
8. add deeper-round launcher from pool members

## 10. Success Criteria

This design is successful when:

1. serial training behaves exactly like an approved-best promotion chain
2. benchmark-failed candidates never become implicit official baselines
3. a 20-lane qualification batch can run without cross-lane artifact contamination
4. passed candidates are collected into a qualified pool
5. deeper rounds can start from pool entries, not from arbitrary raw intermediates
6. the user can inspect logs and understand why each lane passed or failed
