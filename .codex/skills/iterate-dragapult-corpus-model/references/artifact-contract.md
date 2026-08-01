# Artifact and provenance contract

## Frozen corpus

Default corpus:

`D:\ai\code\ptcgabc\artifacts\training_data\dragapult_10000_v1`

Required files:

- `manifest.json`
- `quality_report.json`
- `decision_index.json`
- versioned decision shards
- immutable raw/record shards referenced by the manifest

The audit must prove unique corpus IDs, unique run seeds, clean engine
completion, consistent deck/policy hashes, and game-level split isolation.

## Training run

Each run directory under `artifacts/training_runs/<run_id>/` must contain:

- `run_config.json`
- `corpus_audit.json`
- `model.json`
- `training_report.json`
- hashes for corpus manifest/quality, trainer, and feature contract

The model must contain its public feature schema, label schema, support tables,
inference gates, locked node families, protected exact Overlays, and compressed
weights for all heads.

## Candidate

Each candidate directory under `agents/<candidate_id>/` must contain:

- `main.py`
- unchanged `deck.csv` unless the hypothesis explicitly concerns the deck
- exact `model.json`
- `candidate_manifest.json`

The manifest must hash the architecture base, model, feature contract, main,
and deck.

## Feedback run

Each run under `artifacts/feedback_runs/<run_id>/` must contain:

- official bundle verification;
- deterministic test report;
- candidate and baseline reports;
- paired promotion report;
- feedback queue;
- environment/binary/config/agent hashes;
- replay and decision traces for selected flips.

Use the seeded CABT binary and `PYTHONHASHSEED=0`. Both policies in a pair must
share opponent, seat, native seed, Python seed, and deck.

## Current v0.3 reference result

The first productionized corpus model used:

- 10,000 clean games and 850,368 decisions;
- train/validation/test = 8,000/992/1,008 games;
- public-state value, route value, and interaction value heads;
- quantized deterministic hashed features;
- v124a unified TurnAgenda architecture base.

The first diagnostic exposed two learned overrides inside Crustle/deckout exact
Overlays. Protecting those domains restored both exact paired losses. The
resulting v0.3.1 candidate had real route takeovers but finished 129/160 versus
129/160 for the Champion on the diagnostic seed, so its status is **hold /
reject for promotion**, not a claimed win-rate upgrade.
