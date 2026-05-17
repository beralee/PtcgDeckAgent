# Discard Viewer Input Isolation Design

## Problem

The discard viewer uses the shared card-gallery presentation, but it is not raised through the same modal input path as effect card dialogs. When the viewer has a visible horizontal scrollbar, the lower part of the first card and the left side of the scrollbar can miss the viewer input path. Those missed events can reach the Stadium card below the viewer.

Relevant current behavior:

- `BattleDisplayController._show_card_collection()` only sets `DiscardOverlay.visible = true`.
- `DialogOverlay` uses `_raise_dialog_overlay_for_input()`, but `DiscardOverlay` has no equivalent raise helper.
- The Stadium card is a separate root overlay created by `BattleStadiumHudCoordinator` and remains clickable while the discard viewer is visible.
- Card-gallery drag input is connected to the `ScrollContainer` and each `BattleCardView`, but not to the internal `HScrollBar`.

## Goals

- Treat discard/lost-zone/deck/prize/opponent-hand viewers as modal overlays for pointer input.
- Prevent Stadium actions or Stadium card detail from opening through the discard viewer.
- Make the visible horizontal scrollbar participate in the same drag-to-scroll logic as card previews.
- Keep existing card preview click and right-click detail behavior.

## Non-Goals

- Rework all battle input dispatch.
- Remove native scrollbars.
- Change card collection layout, card sizes, or zone contents.
- Change effect dialogs or field assignment semantics.

## Design

Add a discard viewer raise path on the battle scene:

```gdscript
_raise_discard_overlay_for_input()
```

The helper should:

- Restore normal modal ordering first.
- Raise `DiscardOverlay` to the active modal z layer.
- Set `z_as_relative` consistently with existing modal helpers.
- Set `mouse_filter = STOP`.
- Move the overlay to the end of its parent so root sibling order cannot leave it behind newer overlays.

Every card collection viewer that reuses `DiscardOverlay` must call this helper immediately before showing the overlay:

- discard pile
- lost zone
- deck/prize collection viewers
- opponent hand preview

Add a board-input guard for Stadium handlers:

```gdscript
_is_board_modal_overlay_visible()
```

The guard should return true while visible modal overlays are open, including `DiscardOverlay`, `DialogOverlay`, `DetailOverlay`, `HandoverPanel`, `CoinFlipOverlay`, `ReviewOverlay`, and match-end overlay. Stadium card handlers must return early while the guard is true.

Add a card-gallery scrollbar bridge in `BattleDragScrollCoordinator`:

- When configuring a card-gallery `ScrollContainer`, connect its horizontal scrollbar `gui_input` to the same gallery drag handler.
- Mark the scrollbar with metadata so tests can verify the bridge exists.
- Preserve normal scrollbar styling and visibility behavior.

## Test Plan

Write tests before implementation:

- Opening the discard viewer raises `DiscardOverlay` to the active modal input layer and moves it above the Stadium card overlay.
- While `DiscardOverlay` is visible, a direct Stadium card click handler call does not open the Stadium action dialog.
- A visible discard viewer horizontal scrollbar emits pointer events into shared card-gallery dragging and changes `scroll_horizontal`.

Then implement until those tests pass, followed by the existing dialog and UI regression suites.
