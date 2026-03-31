# AI Battle Review Design

## Goal

Add an in-game AI battle review flow for local human-vs-human matches that helps both players understand how specific key turns could have been played better.

The first release should let the player click a `生成AI复盘` button after a match ends, call a configured ZenMux-backed LLM pipeline, and persist the generated review alongside the existing match recording artifacts.

## Scope

This design covers:

- post-match AI review entry from the match end flow
- ZenMux API integration for battle review requests
- a two-stage LLM review pipeline
- stable structured payload builders for review analysis
- persisted AI review artifacts per recorded match
- minimal in-game UI for generating and reading the review

This design does not cover:

- model/provider management UI
- AI review for VS AI, self-play, or benchmark matches
- live in-match coaching
- replay playback UI
- broad freeform match summaries or coaching categories beyond key-turn better-line analysis

## Product Decision Summary

- supported mode: local human-vs-human only
- trigger: manual post-match button, not automatic generation
- user can close the result screen without generating review
- primary output: key turns for both sides with better choices and clearer action sequencing
- key-turn selection: winner and loser each get 1 to 2 turns
- review results must be persisted to a dedicated file under the match record directory
- external API: ZenMux, with key provisioned by the user outside this feature

## Problem

The project now records enough structured battle data to support post-match analysis, but the review flow is still missing as a product feature.

Today, producing useful advice such as:

- which turn was truly pivotal
- what the acting player should have prioritized
- which cards or lines had better immediate value
- how action ordering could be improved

still requires manual inspection or one-off analysis scripts. That does not scale to in-game usage.

The missing pieces are:

- a stable in-game entry point
- a battle-review-specific API layer
- reusable data builders that expose turn-level context cleanly
- a persisted review artifact that can be re-opened later

## Design

### 1. Separate review pipeline from battle recording

Keep the existing battle recording pipeline focused on recording. Add a parallel post-match review pipeline that consumes finished recording artifacts.

Responsibilities split:

- `BattleRecorder` and `BattleRecordExporter`
  - record and export battle artifacts
- `BattleReviewService`
  - orchestrate AI review generation
- `BattleReviewDataBuilder`
  - build model-ready payloads from existing artifacts
- `BattleReviewArtifactStore`
  - persist review results and optional debug artifacts
- `ZenMuxClient`
  - make network requests
- `BattleReviewPromptBuilder`
  - own the review prompt templates and output contracts

This prevents review-specific logic from polluting real-time battle flow.

### 2. User flow

At the end of a local two-player match:

1. The existing match recording artifacts are already available.
2. The result screen shows a `生成AI复盘` button.
3. If the player clicks it, the game starts the AI review pipeline.
4. The player may also close the result screen without generating a review.
5. When generation completes, the result screen exposes `查看AI复盘`.
6. If a review already exists for the match, the result screen should read it and show `查看AI复盘` immediately, with an optional `重新生成`.

This keeps review generation explicit and avoids surprise latency or token usage after every match.

### 3. Two-stage review architecture

The review should not send full detail logs directly to the LLM in one pass.

Use a two-stage pipeline instead.

#### Stage 1: identify key turns

Inputs:

- `llm_digest.json`
- `turns.json`
- light match metadata

Output:

- winner and loser indexes
- winner key turns: 1 to 2 turns
- loser key turns: 1 to 2 turns
- a short reason for why each selected turn deserves deeper analysis

This stage only decides which turns are worth digging into.

#### Stage 2: analyze each key turn deeply

For every selected turn, the game builds a detailed structured turn packet and sends one request per turn.

This stage must explain:

- what the acting player was trying to accomplish or should have prioritized
- why the actual line was weaker than it looked
- what the better line was
- the better action order and card choices
- why the better line improves the position

This two-stage approach improves stability, lowers token load, and makes the second-stage analysis focus on concrete context rather than broad match reconstruction.

### 4. Review-specific data tools

The first release should formalize analysis tools so future reviews do not require ad hoc code.

#### `BattleReviewTurnExtractor`

Purpose:

- read a recorded match
- extract the full event slice for a given turn
- provide the nearest pre-turn and post-turn snapshots
- expose adjacent turn summaries when useful

#### `BattleReviewContextBuilder`

Purpose:

- convert raw turn extraction output into a structured turn-analysis payload

This payload should include:

- `turn_number`
- `player_index`
- `player_role`
- `board_before_turn`
- `zones_before_turn`
- `actions_and_choices`
- `legal_choice_contexts`
- `strategic_context`
- `deck_context`

The builder must present the turn as analysis-ready structured data, not as raw event spam.

#### `BattleReviewHeuristics`

Purpose:

- add lightweight local hints that improve model focus without replacing model judgment

Examples:

- prize swing markers
- double-KO or multi-prize tempo markers
- gust usage
- suspicious resource-heavy turns
- turns with meaningful choice density
- turns where active plus bench pressure changed the prize map

These heuristics should be included as auxiliary tags in review payloads.

#### `BattleReviewArtifactStore`

Purpose:

- read and write AI review artifacts
- expose status and cached results consistently

### 5. Persistent artifact layout

Each reviewed match should store review outputs inside its match record directory.

Recommended layout:

- `user://match_records/<match_id>/review/review.json`
- `user://match_records/<match_id>/review/stage1_request.json`
- `user://match_records/<match_id>/review/stage1_response.json`
- `user://match_records/<match_id>/review/turn_<n>_request.json`
- `user://match_records/<match_id>/review/turn_<n>_response.json`

`review.json` is the canonical file for UI consumption.

It should include at minimum:

- generation status
- generated timestamp
- prompt version
- model identifier
- selected key turns
- per-turn review results
- failure information if generation did not complete cleanly

The debug request/response files may be configurable later, but the first release should at least support writing them for prompt iteration and failure diagnosis.

### 6. ZenMux API integration

Add a thin `ZenMuxClient` wrapper that owns:

- endpoint configuration
- auth header injection
- request timeout handling
- response parsing
- normalized error reporting

It should not:

- build prompts
- choose turns
- understand battle logic
- touch UI directly

That keeps the API boundary easy to replace or test.

### 7. Prompt ownership

All review prompt templates should live in `BattleReviewPromptBuilder`.

Prompt assets should be versioned and separated by stage:

- stage 1 prompt: key-turn selection
- stage 2 prompt: per-turn deeper review

Each prompt should enforce JSON-only output with fixed keys.

The prompts should explicitly instruct the model to:

- use only the provided data
- avoid generic strategic filler
- explain the better line concretely
- account for hand, discard, board, action ordering, available choices, and deck plan

### 8. Input and output contracts

#### Stage 1 output contract

Stage 1 should return structured turn selections:

```json
{
  "winner_index": 0,
  "loser_index": 1,
  "winner_turns": [
    {
      "turn_number": 7,
      "reason": "First decisive tempo swing that established a favorable prize map."
    }
  ],
  "loser_turns": [
    {
      "turn_number": 8,
      "reason": "Resource investment failed to create a real counter-punch."
    }
  ]
}
```

#### Stage 2 output contract

Stage 2 should return per-turn better-line analysis:

```json
{
  "turn_number": 8,
  "player_index": 1,
  "judgment": "suboptimal",
  "why_current_line_falls_short": [
    "The gust line disrupted positioning but did not convert into a knockout or a lock.",
    "The board still exposed low-HP follow-up targets."
  ],
  "better_line": {
    "goal": "Reduce the next-turn prize swing while preserving a realistic comeback route.",
    "steps": [
      "Use draw/filter effects first to confirm whether a true attack turn is available.",
      "If no knockout is available, preserve the gust effect for a later conversion turn.",
      "Avoid adding extra low-HP liabilities unless they are required immediately."
    ]
  },
  "why_better": [
    "The improved line narrows the opponent's multi-prize options.",
    "It converts resources into survival and comeback equity instead of shallow disruption."
  ],
  "confidence": "medium"
}
```

### 9. Runtime state machine

`BattleReviewService` should expose a simple async state machine:

- `idle`
- `selecting_turns`
- `analyzing_turn`
- `writing_review`
- `completed`
- `failed`

This lets the UI reflect progress precisely.

Recommended behavior:

- if stage 1 fails, the review fails
- if one or more stage 2 requests fail, keep successful results and mark the final review as partial success
- every failure path should still write a review artifact with status and error details

### 10. Minimal UI design

Keep the first release intentionally small.

#### Result screen

States:

- `生成AI复盘`
- `正在筛选关键回合…`
- `正在分析回合 X / N…`
- `查看AI复盘`
- `重新生成`
- `生成失败`

#### Review display

Open a modal or dedicated lightweight screen with two sections:

- winner-side key turns
- loser-side key turns

Each turn card should show:

- turn number
- why the turn was selected
- why the actual line fell short
- better line goal
- ordered better steps
- why the better line is stronger

Do not add scoring systems, coaching taxonomies, replay timelines, or broad match essays in the first release.

## Architecture and File Changes

### New files

- `D:/ai/code/ptcgtrain/scripts/engine/BattleReviewService.gd`
- `D:/ai/code/ptcgtrain/scripts/engine/BattleReviewDataBuilder.gd`
- `D:/ai/code/ptcgtrain/scripts/engine/BattleReviewTurnExtractor.gd`
- `D:/ai/code/ptcgtrain/scripts/engine/BattleReviewContextBuilder.gd`
- `D:/ai/code/ptcgtrain/scripts/engine/BattleReviewHeuristics.gd`
- `D:/ai/code/ptcgtrain/scripts/engine/BattleReviewArtifactStore.gd`
- `D:/ai/code/ptcgtrain/scripts/net/ZenMuxClient.gd`
- `D:/ai/code/ptcgtrain/scripts/engine/BattleReviewPromptBuilder.gd`
- `D:/ai/code/ptcgtrain/tests/test_battle_review_turn_extractor.gd`
- `D:/ai/code/ptcgtrain/tests/test_battle_review_context_builder.gd`
- `D:/ai/code/ptcgtrain/tests/test_battle_review_service.gd`
- `D:/ai/code/ptcgtrain/tests/test_zenmux_client.gd`

### Existing files to modify

- `D:/ai/code/ptcgtrain/scenes/battle/BattleScene.gd`
  - no major runtime review logic, but may expose metadata helpers reused by review builders
- `D:/ai/code/ptcgtrain/scenes/...` result screen owner
  - add button, loading state, and review view entry
- `D:/ai/code/ptcgtrain/scripts/engine/BattleRecordExporter.gd`
  - only if minor metadata additions are needed for better review payloads
- `D:/ai/code/ptcgtrain/tests/test_battle_ui_features.gd`
  - add result-screen review state coverage

## Error Handling

The feature must handle:

- missing match artifacts
- malformed review cache files
- network timeout
- auth failure
- model output that is not valid JSON
- stage 1 selecting nonexistent turns
- partial stage 2 failures

Recommended first-release behavior:

- show a concise user-visible failure message
- preserve a machine-readable error in `review.json`
- keep retry available via `重新生成`

## Testing Strategy

### Unit tests

- turn extraction by turn number
- pre-turn and post-turn snapshot selection
- context-builder payload shape
- heuristic tagging
- prompt-builder output contract
- ZenMux client response and error handling

### Integration tests

- post-match review generation state transitions
- cached review loading
- partial-success persistence
- result-screen button state updates

### Fixture-driven tests

Use one or more real recorded matches as fixtures to ensure:

- stage 1 payloads remain stable
- stage 2 turn packets contain enough detail for concrete turn analysis
- review artifact serialization remains backward-compatible

## Open Questions Deferred

These are intentionally deferred from first release:

- whether to retain all debug request/response files by default
- whether to support prompt version comparison UI
- whether to add review history browsing outside the match result flow
- whether to support alternative providers beyond ZenMux

## Recommendation

Ship the smallest end-to-end version that proves the pipeline:

- local two-player only
- manual generate button
- two-stage LLM review
- winner and loser each get 1 to 2 key turns
- persisted `review.json`
- minimal read-only review UI

That is enough to validate quality, latency, token cost, and data sufficiency before expanding scope.
