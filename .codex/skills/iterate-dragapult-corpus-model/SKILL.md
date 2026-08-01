---
name: iterate-dragapult-corpus-model
description: Train and iterate the Kaggle CABT Dragapult Agent's Graph-constrained value models from a frozen decision corpus. Use when auditing Dragapult replay corpora, changing public-state/TurnAgenda features, training state/route/interaction heads, embedding a model into an isolated Agent, replaying paired outcome flips, converting failures into protected Graph/Overlay contracts or counterfactual data, running seeded Meta-8 A/B, and deciding promote/hold/reject without weakening safety gates.
---

# Iterate Dragapult Corpus Model

## Purpose

Use the frozen corpus to improve choices *inside* the existing Dragapult
strategy Graph. Keep rules, exact calculators, mandatory Drakloak Recon,
terminal prize routes, and atomic interaction transactions authoritative.

This skill extends `iterate-ptcg-kaggle-graph`: use that skill for a pure
hand-written Graph/Overlay change, and use this skill when a trained value
model, corpus schema, counterfactual labels, or learned runtime gate changes.

Before changing code, read:

- `references/workflow.md` for the required iteration and promotion protocol.
- `references/artifact-contract.md` for corpus boundaries, outputs, and hashes.

## Non-negotiable boundaries

- Read only the acting player's observation when building model features.
- Never use opponent hidden hand, prize identities, future events, terminal
  result, or the other player's observation as an input feature.
- Let the native engine define legal actions.
- Let the Graph define safe sibling routes and exact calculators.
- Never let a learned score bypass mandatory Recon, terminal attack, Cursed
  Blast/prize math, damage allocation, discard sets, energy payment, safety
  nodes, or protected exact-matchup Overlays.
- Keep the current Champion immutable. Build one new versioned candidate per
  hypothesis.
- Offline prediction metrics authorize runtime testing only.
- Do not upload to Kaggle or replace the Champion without explicit user
  authorization and a passed online/paired promotion gate.

## Workflow

### 1. Freeze one hypothesis

Write one falsifiable sentence and one expected first divergence. Examples:

- Route Q can choose a better Graph-safe sibling after public `TurnAgenda`
  compilation.
- A learned takeover must be shadow-only inside alternate-win-condition
  Overlays because those domains already have exact solvers.
- More paired counterfactual labels for one route family will increase
  candidate-only flips without increasing invalid games.

Do not mix deck changes, Graph rewrites, feature changes, new labels, and
threshold tuning in one candidate.

### 2. Audit and freeze inputs

Run the corpus audit and record:

- corpus/manifest/quality hashes;
- games and decisions by split, policy cohort, opponent, and seat;
- duplicate IDs/seeds, invalid games, alignment failures;
- Graph-safe exploration coverage;
- Champion, architecture-base, deck, trainer, and feature-contract hashes.

Stop if the corpus is not clean. Never repair a frozen corpus in place; create
a derived, versioned dataset.

If a derived repeated-continuation dataset preserves legacy
`baseline_reward` / `intervention_reward` compatibility fields, prove for
every row that their normalized delta exactly equals both the primary causal
utility target and the repeated-continuation compatibility target. Treat a
mean/standard-error provenance mismatch as corpus corruption: preserve the
old artifact, build a new version, and rerun every downstream control.

### 3. Train run-scoped heads

Train the public-state value, Graph-route value, and interaction value heads in
one run directory. Preserve train/validation/test game boundaries. Upweight
true Graph-safe interventions, but do not call observational win labels causal.

GPU action/outcome pretraining may be used to learn a public-state
representation only. Record the Python, PyTorch, CUDA, and device versions in
the run artifact, keep observational outcome heads explicitly non-causal, and
export a standard-library runtime representation if the Kaggle Agent cannot
ship the training framework. More GPU capacity must not substitute for a
confidence-qualified intervention target.

For state-conditioned action utility, one exact-seed full-game intervention is
one paired sample, not a trustworthy positive/negative label. Before training
a scene-dependent takeover model:

1. replay the identical public decision prefix;
2. keep board, hands, prizes, discards, seat, opponent, and legal options fixed;
3. resample only future hidden continuation state (at minimum, remaining deck
   order) and future randomness;
4. use the same continuation seed for Graph baseline and intervention;
5. aggregate at least several paired continuations into expected normalized
   terminal-reward delta plus standard error;
6. retain the original single-seed direction for audit only, never as the new
   target;
7. prove an identical continuation-seed grid reproduces byte-identical labels.

If many single-seed labels reverse or collapse to neutral, treat label noise as
the primary finding. Do not compensate by increasing model capacity or lowering
runtime confidence gates.

Required output metrics:

- constant-baseline and model log loss;
- constant-baseline and model Brier score;
- AUC where defined;
- expected utility, standard error, and confidence interval for repeated
  continuation targets;
- single-seed-to-repeated direction agreement and reversal matrix;
- Explorer/intervention subset metrics;
- sample counts for every split and head;
- deterministic model hash.

Keep interaction scoring shadow-only until its prompt families have
counterfactual or paired intervention evidence.

### 4. Build an isolated candidate

Embed the exact feature runtime and model in a copy of the architecture base.
At runtime:

1. compile public topology, `AttackerPath`, and `TurnAgenda`;
2. obtain the baseline Graph route;
3. enumerate legal Graph-safe sibling routes;
4. reject protected nodes, transactions, and Overlays;
5. enforce node/phase/card support;
6. require absolute Q and relative-advantage thresholds;
7. cap takeovers;
8. execute one action and replan from the next observation;
9. atomically fall back to the baseline on every error or low-confidence case.

Every takeover must log baseline route, selected route, both scores, advantage,
support, phase, active Overlays, and fallback reason.

### 5. Add contracts before tuning

Run:

- Python compilation and model-schema/hash tests;
- all existing Dragapult Graph contracts;
- native bundle validation in both seats;
- exact tests for the new takeover and every protected domain;
- same-seed reproducibility.

If a learned route breaks an existing contract, treat that contract as
architectural evidence. Add or repair the runtime boundary before changing
thresholds.

### 6. Replay paired flips

For every candidate-only or baseline-only flip:

1. rerun both policies with the exact opponent, seat, and engine seed;
2. enable decision trace and success replay capture;
3. compare aligned decisions;
4. identify the first action divergence;
5. record Graph node, reason, Q margin, support, active Overlays, and final
   consequence;
6. classify the owner as feature, label, Graph route, exact calculator,
   interaction binder, confidence gate, or matchup Overlay.

Never patch a late symptom if the first divergence is earlier.

### 7. Choose the correct correction

- **Exact-domain violation:** protect the structural Graph/Overlay domain.
- **Missing public context:** add a feature and a deterministic fixture.
- **Wrong long-term ranking:** generate paired counterfactual labels.
- **Single-future label instability:** generate repeated paired continuations
  from the identical public decision and train on expected utility.
- **On-policy drift:** collect states produced after real model takeovers.
- **Low coverage:** abstain; do not lower support gates.
- **No outcome flips:** hold/reject as behaviorally changed but unproven.
- **Exact no-op:** reject.

Do not create a matchup exception from one loss unless it represents a named,
reusable structural domain such as an alternate-win clock or immunity solver.

### 8. Gate with fresh seeded A/B

Use both seats and the frozen metagame distribution:

- diagnostic: at least 10 games per seat per matchup;
- standard: at least 20 games per seat per matchup;
- material `+10pp` claim: at least 2,000 independent paired games.

Require zero invalid games, real model takeovers, more candidate-only than
baseline-only flips, no unacceptable matchup regression, and the configured
paired confidence gate. Independent seeds are mandatory after any tuning on a
diagnostic seed.

### 9. Decide and record

- **Promote:** all offline, deterministic, paired, and independent-seed gates
  pass; promotion still needs user authorization.
- **Hold:** architecture and contracts are valid, but paired evidence is
  neutral or insufficient.
- **Reject:** regression, invalid game, hidden-information leak, exact no-op,
  reversed independent result, or failed contract.

Preserve rejected candidates and their first-divergence evidence. Append the
decision to the experiment ledger; never rewrite history.

## Automation

Use `scripts/run_iteration.ps1` to run standard stages without retyping paths.
Run a single stage first; use `all` only after reviewing the candidate/config:

```powershell
.\scripts\run_iteration.ps1 -Stage audit
.\scripts\run_iteration.ps1 -Stage train
.\scripts\run_iteration.ps1 -Stage build -CandidateId dragapult-corpus-graph-v0.4.0
.\scripts\run_iteration.ps1 -Stage test
.\scripts\run_iteration.ps1 -Stage benchmark -Config league/configs/my-candidate.json
```

After a targeted run with `capture_decision_trace=true`, generate a mechanical
first-divergence report:

```powershell
python .\scripts\compare_paired_traces.py `
  --candidate-report <run>\candidate_report.json `
  --baseline-report <run>\baseline_report.json `
  --mode baseline-only `
  --output <run>\first_divergences.json
```

The script does not promote, overwrite the Champion, or submit to Kaggle.
