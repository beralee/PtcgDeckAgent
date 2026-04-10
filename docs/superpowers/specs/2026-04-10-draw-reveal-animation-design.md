# Draw Reveal Animation Design

Date: 2026-04-10

## Goal

Add a visible draw-to-hand reveal animation in battle for cards that move from deck to hand.

The first delivery only covers:
- turn-start draw 1
- `Professor's Research` draw 7

The animation goal is presentation, not rules changes:
- cards still resolve through the existing rules engine
- revealed cards are shown face-up to all viewers
- hand UI should only visibly update after the reveal sequence finishes

## User-Facing Behavior

### Turn-Start Draw 1

- The top card visually leaves the deck area.
- It flips face-up while flying toward the screen center.
- In the center it scales to roughly `2x`.
- For a human-controlled reveal, the scene waits for one mouse click.
- For AI-controlled reveal, the scene pauses briefly and continues automatically.
- The revealed card then flies into the hand area.
- Only after the fly-in completes does the hand UI refresh.

### Professor's Research Draw 7

- Seven cards are revealed one by one from the deck.
- Each card flips face-up and lands in a centered reveal stack.
- The stack remains visible as later cards arrive.
- After all seven cards are shown:
  - human-controlled reveal waits for one mouse click
  - AI-controlled reveal auto-continues after a short delay
- The full stack then flies into the hand area as one batch.
- Only after the batch fly-in completes does the hand UI refresh.

## Scope

### In Scope

- battle-scene presentation layer only
- turn-start draw 1
- `Professor's Research` draw 7
- reveal gating for human vs AI flow
- temporary hand-refresh suppression while reveal is active
- regression coverage for queueing, blocking, and completion

### Out of Scope

- changing `GameStateMachine` draw rules
- covering every draw/search/recover-to-hand card in this pass
- replay-time historical reconstruction of reveal animations
- secret/private-hand hiding during reveal

## Recommended Architecture

Use a dedicated battle UI controller for draw reveal sequences instead of embedding more branching into `BattleScene.gd`.

### Why This Approach

- The rules engine already performs the correct draw and hand mutation.
- The missing piece is presentation timing, not card movement rules.
- The same controller can later extend to other deck-to-hand effects without reworking the core engine.
- It keeps existing coin-flip, field-interaction, and dialog systems separate.

## Components

### 1. Draw Reveal Controller

Add a new controller, tentatively `BattleDrawRevealController.gd`, owned by `BattleScene`.

Responsibilities:
- maintain a queue of pending reveal sequences
- spawn temporary reveal card visuals
- coordinate center-stack layout and fly-in timing
- decide whether to wait for click or auto-continue
- notify the scene when reveal presentation starts and ends

### 2. Draw Reveal Overlay

Add a dedicated full-screen overlay node created at runtime, similar to existing coin and field-interaction overlays.

Responsibilities:
- host temporary `BattleCardView` instances for reveal animation
- reserve a centered stack area
- capture click-to-continue only while a reveal is waiting
- sit above the battle field but below end-of-match/review overlays

### 3. Hand Refresh Deferral

Current hand rendering is rebuilt immediately by `BattleDisplayController.refresh_hand()`.

Add scene-owned reveal state that allows:
- rules state to update immediately
- visible hand rebuild to be deferred while a draw reveal is active
- one final hand refresh after reveal completion

Recommended flags:
- `_draw_reveal_active: bool`
- `_draw_reveal_pending_hand_refresh: bool`

## Data Flow

### Trigger Source

The reveal controller should be fed from `BattleScene._on_action_logged()`.

Reason:
- action logging is already the scene boundary for visible battle events
- `DRAW_CARD` actions already exist for both turn-start draw and effect-driven draws
- this avoids pushing presentation concerns into `GameStateMachine`

### Reveal Payload

The current `DRAW_CARD` action payload only guarantees `count`.

For this feature, draw log actions need enough card identity to render face-up cards:
- `card_names` for text-level verification
- ideally `card_instances` or a scene-resolvable list of drawn `CardInstance` references for the current action

Recommended minimal engine change:
- when logging a draw action, include the actual drawn cards in `action.data`
- battle presentation reads those card objects directly

This should be added to:
- turn-start draw
- generic `draw_card(player_index, count)`
- any other path already logging a `DRAW_CARD` action from real drawn arrays

## Sequence Rules

### Human-Controlled Reveal

- player index matches the side currently being actively piloted by a human
- sequence pauses on a reveal checkpoint until left click
- while paused, live game actions are blocked

### AI-Controlled Reveal

- sequence auto-continues after a short hold, recommended `0.5s` to `0.7s`
- no click required
- AI turn progression must wait for the reveal to fully finish

### Blocking Rules

While a draw reveal is active:
- hand clicks are blocked
- end-turn is blocked
- trainer/ability/action interactions are blocked
- generic AI turn execution is blocked until reveal completion

This should behave similarly to coin animation blocking, but as a separate state.

## Visual Design

### Card Motion

Each reveal card should:
- start near the relevant deck preview
- move to screen center with eased motion
- flip to face-up during travel
- scale up to about `2.0`

### Multi-Card Stack

For `Professor's Research`:
- cards should accumulate in a slightly fanned or offset stack
- the latest card should sit on top
- stack offset should stay small so seven cards remain readable as one bundle

### Exit Motion

- draw 1: single card flies from center to the hand area
- draw 7: the stacked bundle flies from center to the hand area as one grouped motion

The final visible hand cards are still rebuilt by the normal hand renderer after the animation finishes.

## Integration Boundaries

### BattleScene

`BattleScene` remains responsible for:
- owning the controller and overlay lifecycle
- routing logged draw actions into reveal requests
- exposing whether reveal is currently blocking input
- triggering deferred `_refresh_hand()`

### BattleDisplayController

`BattleDisplayController.refresh_hand()` should remain the canonical hand renderer.

It should gain only minimal cooperation logic:
- if reveal is active and a refresh would expose newly drawn cards early, skip immediate rebuild
- mark that a rebuild is pending

### GameStateMachine

Keep rules behavior intact.

Only add the minimum metadata needed so UI can know which exact cards were drawn for a `DRAW_CARD` action.

## Edge Cases

### Empty Deck Loss

If turn-start draw fails because deck is empty:
- no reveal animation should start
- existing game-over flow remains unchanged

### Non-Viewed Player in Two-Player / Replay Context

This first pass targets live battle presentation.

If the reveal belongs to a side not currently visible as the active local view:
- still reveal on the shared scene, face-up to all viewers
- do not attempt hidden/private variants

### Overlapping Draw Events

If a second draw action logs while one reveal is still running:
- queue it
- run sequences strictly in order

## Testing Strategy

Add focused functional tests first.

### Controller / Scene Behavior

- turn-start draw 1 creates a reveal sequence
- `Professor's Research` draw 7 creates a seven-card reveal batch
- human-controlled reveal waits for confirmation input
- AI-controlled reveal auto-continues
- hand UI does not expose new cards before reveal completion
- hand UI refreshes after reveal completion
- AI progression remains blocked until reveal completion

### Engine Metadata

- draw log actions include enough card metadata for reveal presentation
- `Professor's Research` draw action logs all seven drawn cards in order

## Rollout Plan

Phase 1:
- add draw action metadata
- add draw reveal controller and overlay
- wire turn-start draw 1
- wire `Professor's Research` draw 7
- add blocking and deferred hand refresh

Phase 2, later:
- extend to other deck-to-hand draw/search effects
- add optional polish such as stack fan, glow, and sound hooks

## Risks

### Risk 1: Hand UI Race Conditions

The current scene frequently calls `_refresh_ui()` and `_refresh_hand()`.

Mitigation:
- keep reveal state explicit
- make hand refresh deferral narrow and temporary
- always flush a final refresh at sequence end

### Risk 2: AI Continues Too Early

AI currently progresses from normal battle callbacks.

Mitigation:
- add reveal-active state into the same readiness gates used for other blocking overlays

### Risk 3: Too Much Engine/UI Coupling

If UI depends on re-deriving drawn cards from hand diffs, the feature becomes brittle.

Mitigation:
- log exact drawn cards with the draw action instead of reconstructing later
