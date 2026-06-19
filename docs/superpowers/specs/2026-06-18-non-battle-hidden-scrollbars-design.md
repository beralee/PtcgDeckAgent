# Non-Battle Portrait Hidden Scrollbars

## Goal

Android and browser portrait mode should feel like a mobile app outside battle:

- Do not show the right-side vertical scrollbar on non-battle pages.
- Do not reserve layout width for that scrollbar.
- Let the user drag the page content itself to scroll vertically.
- Keep battle UI and every landscape layout unchanged.

This is a non-battle input and layout contract. It must not modify `scripts/ui/battle/*`, battle field layout, battle card galleries, hand HUD, prize selection, or battle dialogs.

## Current Problem

The existing portrait implementation uses the `portrait_touch` scrollbar profile. That profile makes the scrollbar intentionally large:

- width: `112px`
- minimum grab: `220px`

Several non-battle pages also subtract that width from content layout. This fixes old touch targets but creates new mobile problems:

- the right side of lists is visually occupied by a scrollbar;
- content loses too much width on narrow screens;
- users expect to drag the content surface, not a native scrollbar;
- some dialogs mix native scrollbars with custom drag input.

The main technical trap is that hidden scrollbars must not mean disabled scrolling. `NonBattleTouchBridge` currently refuses to drag a `ScrollContainer` whose `vertical_scroll_mode` is `SCROLL_MODE_DISABLED`, so pages cannot simply disable the vertical scrollbar.

## Architecture Contract

All non-battle portrait vertical scrolling must use one shared policy:

```text
NonBattleTouchBridge.configure_hidden_vertical_drag_scroll(scroll)
```

The policy is responsible for:

- keeping logical vertical scrolling enabled;
- hiding the native vertical scrollbar visually;
- disabling horizontal scrolling unless a page explicitly owns a horizontal scroller;
- marking the scroll surface as drag-scrollable;
- allowing root-level `InputEventScreenTouch` and `InputEventScreenDrag` to scroll the content surface;
- suppressing accidental button clicks after a drag;
- preserving normal button, slider, input, and option-button behavior.

The page code should not bind the hidden vertical scrollbar as a touch target. Hidden scrollbars are implementation details, not controls.

## Layout Contract

When a non-battle page resolves to portrait mode:

- use hidden drag-scroll on vertical `ScrollContainer`s;
- do not apply `portrait_touch` to the main vertical scrollbar;
- do not reserve `SCROLLBAR_PORTRAIT_TOUCH_THICKNESS` on the right;
- keep only normal content padding;
- use the existing landscape scrollbar styling when the page resolves to landscape.

This means existing right-clearance constants remain valid for landscape or desktop layouts, but portrait code must not use the 112px scrollbar reservation.

## Scrollable Text Controls

`TextEdit` and `RichTextLabel` are not `ScrollContainer`s, but tournament overview and standings pages use them as scrollable text panels. They need an equivalent hidden-scrollbar policy:

```text
NonBattleTouchBridge.configure_hidden_vertical_drag_scrollable_control(control)
```

The policy hides internal scrollbars and marks the control for future drag-scroll support. Current read-only tournament text panel tests enforce the hidden visual contract. If richer text-panel dragging is needed later, the bridge can add a scroll-target adapter without page-specific code.

## Page Migration Scope

The first pass covers the existing non-battle portrait pages and overlays:

- Battle setup portrait main scroll.
- Battle setup portrait BGM picker and HUD option picker.
- Deck center main list and recommendation detail.
- Deck view dialog.
- AI settings main scroll and model picker.
- Tournament deck picker.
- Tournament overview scrollable text panels.
- Tournament standings scrollable text panels.
- Replay browser list clearance.
- Deck editor card lists and AI analysis scroll panel.
- Deck discussion dialog when opened from deck editor or battle setup.

`DeckDiscussionDialog` is also reused by the live battle page. That live battle context keeps the existing `portrait_touch` visible-scrollbar policy, so the non-battle dialog migration must be guarded by the dialog source/profile and must not change live battle discussion behavior.

Landscape and battle mode are explicitly out of scope.

## TDD Requirements

Tests must encode the new mobile contract:

- portrait `ScrollContainer`s use the hidden drag-scroll policy;
- right-side portrait scrollbars are not visible;
- portrait content no longer reserves the old 112px scrollbar width;
- dragging the scroll surface changes `scroll_vertical` without mouse emulation;
- buttons still activate normally;
- sliders and range controls still work;
- focus controls still focus;
- landscape tests continue to expect the existing scrollbar behavior where applicable;
- battle scrollbar tests continue to pass unchanged.

## Implementation Order

1. Add tests that fail under the old `portrait_touch` visible-scrollbar behavior.
2. Add the shared hidden vertical drag-scroll helpers in `NonBattleTouchBridge`.
3. Update non-battle portrait pages to call the shared helper.
4. Remove portrait-only 112px right-clearance calculations.
5. Keep landscape code paths on their existing `touch` or `auto` profiles.
6. Run the functional test suite and fix regressions without touching battle layout code.
