# Battle Replay Design

## Goal

Add a homepage-level `Battle Replay` feature for recorded local two-player matches.

The feature should let the user:

- open a replay list from the main menu
- browse recent recorded two-player matches in reverse chronological order
- see a compact table of match metadata
- click `Replay` to jump directly into the loser-side key turn for that match
- navigate with `Previous Turn` and `Next Turn`
- optionally continue playing from the currently loaded replay turn

The first release should reuse the existing battle recording pipeline and the existing `BattleScene` UI wherever possible.

## Scope

This design covers:

- a new main menu entry point for replay browsing
- a replay list scene for local two-player match records
- match summary indexing from recorded artifacts
- replay target selection using AI review artifacts when available
- loading turn-start snapshots into a read-only battle replay mode
- turn-by-turn navigation within replay mode
- a `Continue From Here` path that turns the current replay snapshot into a live battle

This design does not cover:

- replay support for `VS_AI`, benchmark, self-play, tuner, or training matches
- action-by-action playback inside a turn
- replay generation for matches that were never recorded
- hidden-information spectator mode
- automatic AI review generation on the replay list page

## Product Decisions

- supported source matches: local two-player only
- replay list ordering: newest first
- replay entry rule:
  - first try loser-side key turn from `review/review.json`
  - if missing, fall back to the loser's last complete turn
- navigation granularity: turn-to-turn only
- navigation target: always the target turn's `turn_start` snapshot
- replay default view: follow the current acting player of the loaded turn
- hidden information policy: only show information that the active replay view player could legally see at that moment
- replay default mode: read-only
- live resumption: available only from a loaded turn-start snapshot through an explicit `Continue From Here` action

## Existing Context

The repository already contains most of the recording and analysis pieces needed for this feature:

- `BattleRecorder` writes per-match artifacts under `user://match_records/<match_id>/`
- `BattleRecordExporter` writes `match.json`, `turns.json`, and `llm_digest.json`
- `detail.jsonl` already contains append-only event history and `state_snapshot` events
- `BattleReviewService` persists `review/review.json` for matches that have AI review output
- `BattleReviewTurnExtractor` already loads a match and finds before/after snapshots for a target turn
- `BattleScene` already owns the in-battle UI, top-right utility buttons, and view-player switching in local two-player play

The key design constraint is not raw data availability. The key constraint is separating replay-only behavior from live battle behavior cleanly enough that `BattleScene` remains predictable.

## Problem

The project can already record matches and generate post-match key-turn review artifacts, but the user cannot browse old matches or jump back into a concrete historical board state.

Today, if the user wants to study:

- which side went first
- how long the game lasted
- what the prize race looked like
- what the loser's key turn board actually looked like
- how the next turn changed the position

they must manually inspect artifact files or ad hoc debug output.

The missing product pieces are:

- a replay list the user can open from the homepage
- a stable per-match summary index
- a replay locator that chooses the right entry turn
- a replay snapshot loader that reconstructs board state from recorded artifacts
- a replay mode in `BattleScene` with strict read-only boundaries

## Approaches Considered

### 1. Recommended: replay list plus `BattleScene` replay mode

Create a dedicated replay list scene, then reuse `BattleScene` with a new replay mode that loads turn-start snapshots instead of starting a fresh match.

Pros:

- reuses the existing battle UI
- keeps replay and live battle in one familiar screen
- makes `Continue From Here` straightforward because replay and live battle already share the same scene

Cons:

- requires a new replay-mode boundary inside an already large `BattleScene`
- needs explicit snapshot-to-runtime reconstruction code

### 2. Extend live `BattleScene` ad hoc without a formal replay layer

Wire replay data directly into the current battle scene with scattered conditionals.

Pros:

- smallest up-front surface change

Cons:

- high long-term risk
- replay checks would spread through action handlers, UI refresh logic, and setup flow
- hard to test and easy to regress

### 3. Build a separate `ReplayScene`

Make an entirely separate battle viewer for replay.

Pros:

- clean isolation from live battle code

Cons:

- duplicates a large amount of battle UI
- makes `Continue From Here` harder because replay state and live state live in different scene systems

## Recommended Design

Use approach 1: a dedicated replay list scene plus an explicit replay mode inside `BattleScene`.

This gives the feature a clean user-facing entry, reuses the battle interface the user already understands, and still keeps the replay/live boundary explicit enough to test.

## Architecture

### 1. Main Menu entry

Add a new main menu button:

- node id: `BtnBattleReplay`
- localized text: `Battle Replay`

It should sit alongside the existing main menu actions and open a dedicated replay list scene.

### 2. Replay list scene

Add a new scene, e.g. `ReplayBrowser.tscn`, with:

- a back button to the main menu
- a table or row-list of recent replayable matches
- one row per recorded local two-player match
- a `Replay` button on each row

Each row should display:

- recorded time
- player labels / deck names
- winner
- first player
- total turns
- final prize count summary
- replay source label:
  - `loser_key_turn`
  - `loser_last_full_turn`

The scene should read match summaries from a dedicated replay index service rather than parsing UI rows directly from raw files.

### 3. Replay data services

#### `MatchRecordIndex`

Purpose:

- scan `user://match_records`
- load `match.json`
- keep only `meta.mode == "two_player"`
- build lightweight row data for the replay browser

Recommended row shape:

```json
{
  "match_dir": "user://match_records/match_20260404_001",
  "match_id": "match_20260404_001",
  "recorded_at": "2026-04-04 20:15:00",
  "player_labels": ["Regidrago", "Dragapult"],
  "winner_index": 1,
  "first_player_index": 0,
  "turn_count": 9,
  "final_prize_counts": [2, 0],
  "replay_entry_source": "loser_key_turn"
}
```

#### `BattleReplayLocator`

Purpose:

- decide which turn `Replay` should open
- expose the ordered list of replayable turn numbers for navigation

Rules:

- read `review/review.json`
- if it contains a loser-side selected turn, use it
- otherwise derive the loser's last complete turn from `turns.json` and `detail.jsonl`
- build the full ordered replay turn list from turns that have a usable `turn_start` snapshot

Suggested output:

```json
{
  "entry_turn_number": 6,
  "entry_source": "loser_key_turn",
  "turn_numbers": [1, 2, 3, 4, 5, 6, 7, 8, 9]
}
```

#### `BattleReplaySnapshotLoader`

Purpose:

- load a target replay turn from recorded artifacts
- return both full internal state and filtered visible state

Rules:

- first try the target turn's `turn_start` snapshot
- if missing, fall back to the earliest usable snapshot for that turn
- if that still fails, fall back to the nearest later `turn_start` only if the UI can clearly represent the fallback
- preserve the raw snapshot for future live resumption
- derive a filtered snapshot for replay display according to replay visibility policy

Suggested output:

```json
{
  "turn_number": 6,
  "snapshot_reason": "turn_start",
  "raw_snapshot": {},
  "view_snapshot": {},
  "view_player_index": 1
}
```

### 4. Replay mode in `BattleScene`

Add an explicit mode boundary instead of a loose collection of booleans.

Recommended high-level state:

```json
{
  "mode": "live | review_readonly | review_takeover_ready",
  "review_match_dir": "user://match_records/...",
  "review_turn_numbers": [1, 2, 3],
  "review_current_turn_index": 1,
  "review_entry_source": "loser_key_turn",
  "review_view_mode": "current_actor"
}
```

#### Replay entry

When the user clicks `Replay` from the browser:

1. Load the replay locator result.
2. Load the entry turn snapshot.
3. Open `BattleScene` in `review_readonly`.
4. Apply the replay snapshot instead of running the live setup flow.
5. Set `view_player` to the loaded snapshot's `current_player_index`.

#### Replay-only UI

In replay mode, the top-right utility cluster should add:

- `Previous Turn`
- `Next Turn`
- `Continue From Here`
- `Back to Replay List`

Recommended placement: immediately to the right of `Zeus Help`, since the user explicitly wants the turn navigation controls there.

#### Read-only restrictions

In `review_readonly`, disable:

- hand card play
- attack declaration
- retreat
- end turn
- AI advice
- Zeus help
- any effect interaction resolution

Still allow:

- card detail viewing
- discard viewing
- prize viewing
- scrolling logs and static board inspection

All live action entry points should go through a centralized guard such as:

- `_is_review_mode()`
- `_can_accept_live_action()`

Do not spread replay special cases across many unrelated handlers if a shared guard can block them earlier.

### 5. Visibility policy

Replay display should follow the acting player of the loaded turn, because that is the chosen product behavior.

For every loaded turn:

- `view_player = snapshot.current_player_index`
- the acting player's legal information remains visible
- the opponent's hidden information remains hidden

That means:

- acting player's own hand is shown
- opponent hand contents are hidden
- prize identities remain hidden
- deck order remains hidden
- public zones remain visible

This is stricter than the raw recording artifacts, which contain enough information for complete reconstruction. Replay mode must filter that raw data before binding it to UI.

### 6. Turn navigation

`Previous Turn` and `Next Turn` should navigate only across replayable turn-start snapshots.

Rules:

- no intra-turn stepping in this release
- update `review_current_turn_index`
- load the new turn snapshot through `BattleReplaySnapshotLoader`
- update `view_player` to the new current actor
- refresh UI without triggering any live battle progression side effects

Disabled states:

- `Previous Turn` disabled on the first replayable turn
- `Next Turn` disabled on the last replayable turn

### 7. Continue From Here

`Continue From Here` is the only allowed transition from replay into live battle.

Rules:

- only available from a loaded turn-start snapshot
- reconstruct a real `GameState` from the replay `raw_snapshot`
- clear replay navigation state
- clear any pending interaction, handover, advice, review, or animation state that belongs to the replay session
- switch scene state from `review_readonly` to `live`
- permit normal player actions after reconstruction finishes

This release should not support resuming from an arbitrary mid-turn micro-state. The replay system only guarantees correctness at turn-start snapshots.

## Data Model Changes

The first release can work with current recorder artifacts, but two small additions will make the product more robust and cheaper to query.

### 1. Persist final prize counts in `match.json.result`

Add stable final prize counts so the replay list does not have to recompute them from the last snapshot every time.

Recommended fields:

```json
{
  "winner_index": 1,
  "reason": "knockout",
  "turn_number": 9,
  "final_prize_counts": [2, 0]
}
```

### 2. Persist turn-start presence in `turns.json`

Add one of:

- `turn_start_event_index`
- `has_turn_start_snapshot`

This lets replay navigation discover valid jumps without rescanning all `detail.jsonl` snapshots on every browser open.

## Data Flow

### Replay list flow

1. Main menu opens replay browser.
2. Replay browser asks `MatchRecordIndex` for row summaries.
3. The browser renders the newest-first match rows.

### Replay open flow

1. User clicks `Replay` on a match row.
2. Browser calls `BattleReplayLocator`.
3. Locator returns the entry turn and replayable turn list.
4. Browser opens `BattleScene` with replay launch parameters.
5. `BattleScene` asks `BattleReplaySnapshotLoader` for the entry turn snapshot.
6. `BattleScene` binds the filtered replay snapshot to UI and enters `review_readonly`.

### Turn navigation flow

1. User clicks `Previous Turn` or `Next Turn`.
2. `BattleScene` updates the replay turn index.
3. `BattleReplaySnapshotLoader` loads the new target turn.
4. `BattleScene` rebinds filtered data and updates `view_player`.

### Continue flow

1. User clicks `Continue From Here`.
2. `BattleScene` converts the current replay `raw_snapshot` into a live `GameState`.
3. Replay-only state is cleared.
4. The scene switches into live battle mode.

## Error Handling

### Replay browser errors

- if `match.json` is missing or invalid, skip that row and log a recoverable warning
- if a row has incomplete metadata, show a degraded row rather than failing the whole screen

### Replay location errors

- if no loser key turn and no last full turn can be found, disable `Replay` for that row
- if replayable turn numbers cannot be built, show a user-facing error instead of opening a broken scene

### Snapshot load errors

- if a target turn snapshot cannot be loaded, keep the current replay turn on screen and show a message
- do not leave the scene in a half-updated state

### Continue-from-here errors

- if snapshot-to-`GameState` reconstruction fails, remain in replay mode
- show a user-facing error and keep replay navigation intact

## Testing Strategy

### 1. Match record indexing tests

Cover:

- only `two_player` rows are listed
- newest-first ordering
- row metadata extraction
- final prize count display
- degraded row behavior for partial artifacts

### 2. Replay locator tests

Cover:

- loser-side key turn selection from `review.json`
- fallback to loser last full turn when review is absent
- replayable turn-number list construction

### 3. Snapshot loader tests

Cover:

- exact `turn_start` load
- fallback behavior when `turn_start` is absent
- filtered visibility for the acting player
- preservation of the raw snapshot for later takeover

### 4. `BattleScene` replay mode tests

Cover:

- replay entry skips normal live setup flow
- previous/next turn buttons load the expected turn
- replay mode follows the loaded turn's acting player
- live action entry points are blocked in replay mode
- `Continue From Here` switches to live mode and reenables legal actions

### 5. Main menu and replay browser integration tests

Cover:

- main menu exposes the replay button
- replay browser opens and lists rows
- clicking a row's `Replay` enters `BattleScene` at the correct turn
- `Back to Replay List` returns correctly

## Risks

### 1. `BattleScene` mode leakage

`BattleScene` is already large. Replay mode must use explicit gates and centralized state, or replay behavior will leak into live battle handlers.

### 2. Snapshot reconstruction complexity

The recorder serializes full state snapshots, but replay takeover still needs a trustworthy converter from snapshot data back into runtime objects such as `GameState`, `PlayerState`, `PokemonSlot`, and `CardInstance`.

### 3. Visibility filtering bugs

Raw replay artifacts contain more information than replay mode should reveal. A filtering mistake could leak opponent hand or deck information.

### 4. Old artifact compatibility

Some previously recorded matches may lack new summary fields such as `final_prize_counts` or turn-start markers. The replay browser must degrade gracefully.

## Rollout Order

Recommended implementation order:

1. main menu replay entry plus empty replay browser scene
2. `MatchRecordIndex`
3. `BattleReplayLocator`
4. `BattleReplaySnapshotLoader`
5. `BattleScene` replay-readonly mode
6. previous/next turn navigation
7. `Continue From Here`
8. recorder/exporter summary-field enhancements

## Success Criteria

The feature is successful when:

- the main menu exposes a replay entry
- the replay browser lists recent local two-player matches
- each row shows the expected summary fields
- `Replay` opens the loser key turn when review artifacts exist
- otherwise `Replay` opens the loser's last full turn
- previous/next turn navigation works on turn-start snapshots
- replay mode follows the acting player view without leaking hidden information
- `Continue From Here` starts a legal live battle from the loaded turn-start snapshot
