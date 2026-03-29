# Battle Recording Design

## Goal

Add a structured per-match recording system that captures both:

- a lightweight human-readable summary log suitable for the battle UI log panel
- a detailed machine-readable event log suitable for post-game LLM analysis, replay inspection, and future in-game decision support

The first release targets only local human-vs-human matches and records them by default.

## Scope

This design covers:

- per-match recording lifecycle
- per-match output directory layout
- summary vs detail log separation
- full-information detailed logging
- capture of choice context, selected actions, and resolved outcomes
- end-of-match export into a final aggregate JSON document

This design does not:

- redesign the existing right-side battle log UI
- add LLM integration yet
- cover AI-vs-AI, headless self-play, or benchmark recording in the first release
- implement a replay player UI

## Problem

The current project has partial logging primitives but no complete match recording system:

- `GameStateMachine` already emits structured `GameAction` entries
- `BattleScene` already renders a lightweight visible log and writes a runtime debug log
- `AIDecisionTrace` records AI reasoning for a single decision

Those pieces are useful but fragmented. They do not produce:

- a stable per-match artifact set
- full-information records including hidden zones
- explicit `choice_context -> selected -> resolved` event chains
- a machine-friendly event stream that can be consumed by an LLM for analysis

Without a formal recording pipeline, the project cannot reliably support:

- full post-match reconstruction
- structured mistake analysis
- future live decision suggestions
- consistent training-time or human-play auditing

## Design

### 1. Dedicated recording pipeline

Add a focused match recording pipeline with four responsibilities:

- `BattleRecorder`: manages one match recording session, file paths, event indexing, and write operations
- `BattleEventBuilder`: converts runtime state and actions into stable structured event dictionaries
- `BattleSummaryFormatter`: derives lightweight human-readable summary lines from structured events
- `BattleRecordExporter`: compacts the event stream into the final `match.json` artifact at match end

This keeps recording independent from both UI rendering and rule execution.

### 2. Storage layout

Each match is stored in its own directory:

- `user://match_records/<match_id>/summary.log`
- `user://match_records/<match_id>/detail.jsonl`
- `user://match_records/<match_id>/match.json`

`match_id` should include a timestamp plus a short unique suffix so recordings remain sortable and collision-resistant.

The first release does not require a separate `meta.json`; metadata can live in `match.json`.

### 3. Two-level log structure

#### Summary log

`summary.log` is for humans. It should stay close to the current visible battle log and only add useful missing details, for example:

- attack damage dealt
- knockout results
- prize-taking results
- send-out results

The summary log should not become a full debug trace.

#### Detail log

`detail.jsonl` is the canonical per-event stream. It should use full-information perspective and record all relevant hidden information needed for post-match analysis.

Every event is appended as one JSON object per line so:

- the file remains usable even if the match crashes midway
- later tools can stream or tail the record
- the final export step can rebuild a complete match object from it

### 4. Event model

Each detailed event should contain the following common fields:

- `match_id`
- `event_index`
- `timestamp`
- `turn_number`
- `phase`
- `player_index`
- `event_type`

The first release should support these event types:

#### `match_started`

Created once at the beginning of the match. It records full-information initial context:

- mode
- player labels and control types
- deck identity metadata if available
- first player
- both starting hands
- both prize cards
- both full deck lists and order
- both starting active and bench states

#### `state_snapshot`

Created at key checkpoints rather than after every single internal mutation. It records enough state to reconstruct context cleanly:

- both hands
- both active and bench states
- both discard piles
- both prize zones
- both deck counts plus optionally full deck contents for the first release
- turn/phase flags and per-turn restrictions

Suggested checkpoint moments:

- immediately after match start
- start of turn
- after draw
- before a player-facing choice
- after a resolved action with meaningful board change
- end of turn
- game end

#### `choice_context`

Records what the acting player could do at a decision point:

- choice type
- source system (`dialog`, `prompt`, `main_action`, `forced_resolution`, etc.)
- legal actions list when available
- visible selectable options
- whether the choice is mandatory
- relevant constraints or reason the prompt exists

This is the critical bridge for future LLM analysis.

#### `action_selected`

Records the chosen action:

- selected action kind
- parameters
- targets
- origin (`human_input`, `system_progression`, future `ai_choice`)

#### `action_resolved`

Records what the engine actually did:

- success or failure
- resulting cards drawn
- cards searched and selected
- cards discarded
- damage dealt
- healing
- status changes
- evolution, attachment, retreat, send-out, prize-taking, knockouts

This event should capture meaningful semantic outcome, not just raw function success.

#### `match_ended`

Created once at the end of the match:

- winner
- reason
- total turns
- final board summary

### 5. Integration points

The first release should integrate at three boundaries.

#### `GameStateMachine`

This is the main source of authoritative gameplay actions and outcomes through `GameAction` and `action_logged`.

It remains the source of truth for:

- gameplay action type
- acting player
- turn number
- structured action metadata
- engine-confirmed results

The recorder should consume those events rather than asking the UI to restate them.

#### `BattleScene`

This is the main source of human-facing decision context:

- dialog prompts
- visible selectable cards and options
- user selection points
- right-side summary log rendering

The recorder should hook here for `choice_context` and selected-option details that do not currently live in `GameAction`.

#### AI boundary

The first release does not record full AI matches, but the schema should leave room for future insertion of:

- legal actions
- chosen AI action
- decision trace
- reason tags

That means `choice_context` and `action_selected` should already allow optional AI-oriented fields.

### 6. Full-information policy

Detailed logs should use full-information perspective.

That means `detail.jsonl` and `match.json` may contain hidden information such as:

- both hands
- prize cards
- full deck contents

This is intentional because the primary downstream consumer is future LLM-based analysis, not player-facing UI.

By contrast, `summary.log` remains human-oriented and should not be treated as the analysis source of truth.

### 7. Final export

At match end, the recorder should generate `match.json` containing:

- `meta`
- `initial_state`
- `events`
- `result`

`detail.jsonl` remains the durable append-only source. If final export fails, the detailed line-based record must still be preserved.

### 8. Failure handling

Recording must never break the match.

Rules:

- file write failures should be swallowed and surfaced only as warnings
- the match continues even if recording is partially unavailable
- if `match.json` export fails, keep `detail.jsonl` and `summary.log`
- malformed optional event payloads should not crash battle flow

This feature must be observational, not gameplay-critical.

## Data Quality Principles

Because the detailed record is intended for LLM consumption, the schema should prioritize:

- semantic clarity over raw internal dumps
- explicit separation of available choices vs chosen action vs actual outcome
- stable field names
- low redundancy outside of intentional `state_snapshot` events

The first release should avoid serializing enormous opaque engine objects directly. Instead it should emit normalized dictionaries that describe:

- zones
- cards
- selected options
- actions
- results

## Implementation Boundaries

To keep risk low in the first release:

- do not rewrite the current right-side battle log system
- do not move existing gameplay logic into the recorder
- do not couple recording to training or benchmark systems yet
- do not require AI-specific fields for human-vs-human support

The recorder should sit beside existing systems, consuming events rather than owning them.

## Testing

Add focused coverage for:

- creating a per-match directory with all three files
- writing append-only `detail.jsonl` events in stable order
- `match_started` containing full-information initial state
- recording `choice_context -> action_selected -> action_resolved` for representative prompted actions
- summary log line generation for representative gameplay events
- graceful behavior when file writes fail

The first release should prefer targeted suites and smoke coverage over long full-suite runs for every small recording change.

## Risks

- Some important player-choice details currently live only in `BattleScene` prompt handling, not in `GameAction`. That integration boundary must stay explicit.
- Full-information logs can grow quickly. The first release should keep snapshots targeted and avoid dumping redundant state after every micro-step.
- Existing source files already contain some encoding damage in comments and strings. New recording files and new source edits should remain plain ASCII wherever possible.

## Recommendation

Build the first release as a recording layer that consumes existing gameplay and UI events rather than as a replay-system rewrite.

That gives the project immediate value:

- usable per-match artifacts
- improved summary logging
- a clean detailed event stream for future LLM analysis

without destabilizing battle flow or dragging the feature into AI/training scope too early.
