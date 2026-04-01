# In-Battle AI Advice Design

## Goal

Add an in-match `AI建议` feature for local human-vs-human battles that can coach the current turn player during the game.

The feature should sit in the existing top-right action area, immediately to the left of `宙斯帮我`, and send the current player view of the match plus both full 60-card decklists to ZenMux-backed AI analysis.

The AI should return:

- the recommended main line for the rest of the current turn
- conditional branches when draw, search, or other uncertain outcomes change the best line
- longer-horizon prize-trade guidance and resource planning
- concrete explanations for why the line is best

The tone target is high-level competitive coaching: specific, disciplined, and practical, not generic filler.

## Scope

This design covers:

- a new `AI建议` button in local two-player battles
- in-match AI analysis generation during an active match
- a match-long persistent AI advice session
- incremental context sync using existing battle recording artifacts
- structured advice output shown in an overlay and a dockable side panel
- persisted advice artifacts under the current match directory

This design does not cover:

- automatic advice generation every turn
- advice for `VS_AI`, self-play, benchmark, or tuner modes
- local best-line search or exhaustive simulation
- model/provider selection UI
- replacing the existing post-match AI review feature

## Product Decisions

- supported mode: local human-vs-human only
- trigger: manual button press, repeatable at any point in the match
- session scope: one ZenMux-backed advice session per match, not per turn
- hidden information policy:
  - include both full 60-card decklists
  - include only information visible to the current turn player
  - do not reveal opponent hand contents
  - do not reveal prize card identities
  - do not reveal deck order
- output structure:
  - `本回合主线`
  - `条件分支`
  - `拿奖节奏判断`
  - `原因说明`
  - `风险提醒`
  - `置信度`
- UI pattern:
  - first show the result in an overlay
  - optionally pin the latest advice into a docked side panel

## Existing Context

The repository already has the building blocks needed for this feature:

- `BattleScene` already owns the top-right battle actions and in-battle overlays
- `BattleRecorder` already writes `summary.log`, `detail.jsonl`, `match.json`, `turns.json`, and `llm_digest.json`
- `ZenMuxClient` already provides a thin JSON request wrapper
- the recent post-match `BattleReviewService` pipeline already establishes a pattern for prompt builders, data builders, artifact storage, and UI integration

The main design constraint is to reuse those pieces and avoid changes to battle rules or action-resolution logic.

## Problem

The project can already record enough structured battle data to support strong AI coaching, but the player cannot ask for advice during a live human-vs-human game.

Today, a player who wants help with:

- how to sequence the rest of the turn
- which resource to conserve
- whether to chase a short KO line or preserve a better prize map
- how to plan for the next one to two turns

has no in-game assistant flow.

The missing pieces are:

- an in-battle entry point
- a match-long advice session model
- an incremental context builder that reuses existing logs
- a UI presentation that fits the current battle screen

## Design

### 1. Add a parallel advice pipeline

Do not mix the new feature into battle rules, legal action generation, or effect resolution.

Add a parallel read-only advice pipeline:

- `BattleScene`
  - owns the button, overlay, and docked panel
  - triggers advice generation
- `BattleAdviceService`
  - orchestrates the advice request lifecycle
- `BattleAdviceContextBuilder`
  - builds the current request payload from the live battle state and recorded artifacts
- `BattleAdvicePromptBuilder`
  - owns prompt instructions and JSON output contracts
- `BattleAdviceSessionStore`
  - persists match-long session state and advice artifacts
- `ZenMuxClient`
  - remains the only network boundary

This keeps the advice feature isolated and testable.

### 2. Reuse one advice session for the whole match

The feature should create one advice session per match, stored under that match's recording directory.

The session should survive repeated button presses during the same match and maintain:

- a stable `session_id`
- how many requests have already been sent
- which detailed events have already been synchronized
- the most recent advice summary
- the most recent player-view context marker

This session is not a provider-specific chat transcript mirror. It is the game's stable local record of what has already been synchronized and what the latest strategic framing was.

### 3. Build requests from current player visibility plus decklists

Every advice request must combine four context layers.

#### Layer A: session envelope

- `session_id`
- `request_index`
- `last_advice_summary`
- `current_player_index`

#### Layer B: visibility rules

Explicitly tell the model what is and is not known:

- known:
  - current board state
  - both discard piles
  - both active and benched Pokemon details
  - public stadium / lost zone / VSTAR usage state
  - the acting player's hand
  - both full decklists
- unknown:
  - opponent hand contents
  - prize identities
  - deck order

This prevents the model from quietly assuming hidden information.

#### Layer C: current position

Build a fresh full snapshot at request time using existing battle-state serialization patterns:

- turn number
- phase
- current player index
- public board state
- public zone state
- acting player's hand
- both decklists
- action-use flags such as supporter / energy / stadium / retreat usage

This layer should be generated from live state, not reconstructed from stale logs.

#### Layer D: delta since last advice

Reuse the existing recording outputs instead of inventing a second logging system.

Primary sources:

- `summary.log` for compact human-readable turn flow
- `detail.jsonl` for exact action and choice events

For repeated button presses, only include:

- detail events with `event_index > last_synced_event_index`
- a compact summary of the newest coarse-log lines
- a current full snapshot so the model always sees the latest board

This keeps later requests smaller while preserving continuity.

### 4. Persist advice artifacts under the match directory

Store advice outputs under:

- `user://match_records/<match_id>/advice/session.json`
- `user://match_records/<match_id>/advice/latest_advice.json`
- `user://match_records/<match_id>/advice/advice_request_001.json`
- `user://match_records/<match_id>/advice/advice_response_001.json`

and so on for later requests.

#### `session.json`

Canonical local session state:

```json
{
  "session_id": "match_20260401_001",
  "created_at": "2026-04-01 23:10:00",
  "updated_at": "2026-04-01 23:18:20",
  "request_count": 2,
  "last_synced_event_index": 184,
  "last_synced_turn_number": 7,
  "last_advice_summary": "This turn should prioritize stabilizing the prize race with Boss pressure next turn.",
  "last_player_view_index": 0
}
```

#### `latest_advice.json`

Canonical UI-facing result for the newest successful or failed advice request.

It should contain:

- status
- generated timestamp
- session id
- request index
- turn number
- player index
- structured advice sections
- errors, if any

If a request fails, the session file should remain valid and the last successful advice should remain available.

### 5. Keep the output structure strict and layered

The AI response should be structured JSON, then formatted by the client into the overlay and side panel.

Required logical sections:

- `strategic_thesis`
  - one-sentence statement of the turn's real job
- `main_line`
  - ordered steps for the rest of this turn
- `branches`
  - conditional plans for uncertain outcomes
- `prize_plan`
  - the best expected prize map and tempo objective for the next one to two turns
- `why_this_line`
  - concrete reasons tied to board state, resources, and sequencing
- `risks`
  - what can go wrong or what line this recommendation is hedging against
- `confidence`
  - low / medium / high
- `summary_for_next_request`
  - a compact assistant summary to persist into the next advice request

The most important design rule is that the model must not blend future speculation into `main_line`. That section is for the best executable line from the current position. Uncertain follow-ups belong in `branches`.

### 6. UI flow

#### Button placement

Add `AI建议` immediately to the left of `宙斯帮我` in the battle top bar.

#### Overlay flow

When pressed:

1. Open an advice overlay.
2. Show a loading state while advice generation is running.
3. Replace loading with the structured advice result.
4. Expose actions:
   - `重新分析`
   - `固定到侧边`
   - `关闭`

The overlay is the first-read surface and should reuse the style language of the existing review overlay where practical.

#### Docked side panel

If the player selects `固定到侧边`, show a dockable advice panel beside the existing right-side information area.

The panel should:

- show the latest advice result
- support collapse / expand
- preserve the latest content while the player continues playing
- update when a later advice request finishes

The existing battle log stays in place. The advice panel is additive, not a replacement.

### 7. Failure handling

Failures must never interrupt the battle itself.

If a request fails:

- show the failure state in the overlay and docked panel
- preserve the last successful advice result
- do not advance `last_synced_event_index`
- allow immediate retry

If session files are missing or corrupted:

- rebuild a new local advice session for the current match
- keep the battle playable
- surface a user-visible but non-fatal error

If ZenMux returns malformed JSON:

- store the raw response in the per-request artifact
- mark the request as failed
- leave the session resumable

### 8. Prompting and model guidance

Prompting should live only in `BattleAdvicePromptBuilder`.

The prompt must explicitly instruct the model to:

- use only the provided data
- honor the declared hidden-information limits
- focus on competitive sequencing and prize mapping
- avoid generic filler
- explain recommendations concretely
- separate executable turn steps from uncertain branches
- return JSON only with fixed keys

The response schema should be strict enough that the UI never needs to parse freeform prose blobs.

### 9. Testing

#### UI coverage

- the top bar includes `AI建议` immediately left of `宙斯帮我`
- pressing the button opens the advice overlay
- loading, success, failure, and retry states render correctly
- `固定到侧边` shows and updates the docked panel

#### Session coverage

- a match creates at most one advice session
- repeated requests increment `request_count` and reuse `session_id`
- later requests only include unsynced events plus a fresh snapshot
- failed requests do not advance the sync cursor

#### Context-builder coverage

- acting player hand is included
- opponent hand contents are excluded
- full 60-card decklists are included
- prize identities and deck order are excluded
- current board state and public zones are included

#### Prompt / client coverage

- prompt payload uses the expected schema version
- ZenMux responses normalize into the structured advice contract
- malformed provider responses surface as non-fatal failures

#### Regression coverage

- two-player handover flow still works
- existing battle recording output still works
- existing post-match AI review flow still works
- `VS_AI` mode does not expose or enable the new advice flow

## Non-Goals

- automatically popping advice each turn
- turning the feature into a rules engine
- building a local search planner in this release
- adding account-level or cloud-synced long-term sessions
- merging this feature into the post-match review pipeline

## Recommended Implementation Shape

To minimize risk, implement in this order:

1. session store and payload builders
2. prompt builder and service orchestration
3. overlay flow
4. docked side panel
5. regression and integration tests

That order reuses the already-established review architecture while keeping battle logic untouched.
