# Battle Portrait UI Hardening Design

## Background

The battle scene now has a layout coordinator and separate layout view objects. That refactor gives us the correct seam for fixing portrait UI regressions without continuing to add ad-hoc coordinate patches to `BattleScene.gd`.

The remaining portrait issues are not card-rule bugs. They are integration bugs across layout bounds, hit testing, HUD bindings, and touch dialog metrics:

- portrait hand area, stadium HUD, and end-turn button can still exceed the visible content frame;
- portrait bench reparenting can break target clicks for hand energy attach or field-assignment interactions;
- text-only discard HUD panels do not consistently open the discard pile dialog;
- mobile dialogs and field-interaction panels still contain desktop-sized text/buttons in some paths.

## Goals

1. Keep gameplay interactions independent from portrait/landscape layout details.
2. Keep portrait and landscape layout implementations independently adjustable.
3. Make portrait layout regressions testable with deterministic layout contracts, not screenshot-only checks.
4. Make touch targets usable on Android portrait while preserving existing landscape behavior.
5. Avoid rewriting card effects, AI, or game-state logic.

## Ownership Boundaries

### BattleLayoutCoordinator

Owns layout-mode resolution and viewport context creation only.

It may calculate:

- physical viewport size;
- logical viewport size;
- portrait content frame;
- canvas rotation context.

It must not know about card rules, legal actions, or selected hand cards.

### BattlePortraitLayoutView

Owns portrait visual placement and safe-area enforcement.

It may:

- size active, bench, hand, HUD, and overlay controls;
- reparent HUD controls into portrait overlay rails;
- set z-index for portrait overlay layers;
- enforce the portrait safe rectangle after all portrait layout helpers run;
- call scene compatibility helpers while migration is incomplete.

It must not:

- attach energy;
- play Pokemon;
- resolve field assignments;
- inspect hidden card zones;
- decide whether an action is legal.

### BattleLandscapeLayoutView

Owns landscape visual restoration and landscape layout preparation.

It must reset portrait-only reparenting and hidden states before applying landscape layout.

### BattleInteractionController

Owns interaction state machines and field-selection panels.

It may:

- track selected field targets;
- track selected source cards/energy for assignment interactions;
- render the interaction strip;
- expose touch-sized interaction controls.

It must not:

- position global battlefield HUD rails;
- decide active/bench card sizes;
- make portrait/landscape branch decisions outside generic viewport/touch metrics.

### BattleDialogController

Owns generic dialog presentation.

It may:

- apply touch dialog metrics;
- style footer buttons;
- size card/list scroll areas from the supplied dialog card size.

It must not:

- decide card effect outcomes;
- bind battlefield slots.

### BattleScene

Remains the composition root.

It may:

- wire node references and controller instances;
- route input events to action methods;
- expose compatibility helpers for layout views during migration.

It should not add new portrait coordinate algorithms. New portrait placement belongs in `BattlePortraitLayoutView` or a layout helper.

## Portrait Layout Contract

Every portrait apply pass must satisfy these invariants for the portrait `content_rect`:

1. `TopBar`, `MainArea`, `HandArea`, `HandScroll`, `StadiumCenterSection`, and `HudEndTurnBtn` stay inside the horizontal safe width.
2. Hand cards may overflow inside `HandScroll`, but the scroll container and hand panel must clip content inside the safe frame.
3. Five-card logical portrait widths should show five hand cards without requiring a scrollbar. Narrow 390px preview widths may scroll, but must not bleed outside the safe frame.
4. Bench slots, active slots, and hand card sizes are all derived from the same portrait metrics output.
5. Portrait edge HUD rails float over the battlefield and do not consume `FieldShell` layout width.
6. Dialog and field-interaction overlays always render above portrait edge HUD rails.
7. HUD controls that are clickable must receive input only inside their own panels. The rail overlay itself must not block card, bench, or field clicks.

## Interaction Contract

Portrait mode must preserve the same gameplay event path as landscape:

1. Selecting a hand Basic Pokemon and clicking an empty own bench slot calls the normal `play_basic_to_bench` path.
2. Selecting a hand Energy and clicking an occupied own active/bench slot calls the normal `attach_energy` path.
3. Field assignment interactions use the existing source-selection state in `BattleInteractionController`, then target clicks enter `_handle_slot_left_click(slot_id)` and `_try_handle_field_interaction_slot_click`.
4. Portrait bench-grid fallback only handles empty-slot Basic Pokemon placement. It must not steal Energy, Tool, Evolution, or field-interaction target clicks.
5. Discard HUD panel clicks call the same `_show_discard_pile(player_index, title)` path as the legacy discard preview card.

## Touch Dialog Contract

Portrait/touch dialog metrics should use a single profile:

- button height: at least 56px;
- primary text: at least 18px for action options and field interaction buttons;
- body text: at least 16px;
- dialog width: no wider than the safe portrait frame minus margins;
- horizontal card strips keep a touch scrollbar but must be swipable from the content area, not require grabbing the scrollbar;
- field-interaction panels must never have a hard desktop minimum width larger than the safe portrait width.

## Test Plan

Add regression coverage in `tests/test_battle_portrait_layout.gd`:

1. `test_portrait_critical_controls_fit_safe_width`: applies portrait layout to phone and Android logical sizes, then checks top bar, main area, hand area, stadium, and end-turn sizing against the safe content width.
2. `test_portrait_field_interaction_panel_uses_safe_touch_width`: verifies field-interaction panels clamp to the supplied safe width and expose touch-sized buttons/text.
3. `test_portrait_discard_hud_panels_open_discard_dialog`: verifies self and opponent discard HUD panels are bound to the discard overlay path.
4. Existing bench and draw-reveal tests continue to guard rotated-canvas input mapping.

## Implementation Plan

1. Add the tests first and make the expected contracts explicit.
2. Move remaining portrait safe-width enforcement into `BattlePortraitLayoutView`.
3. Remove desktop minimum-width assumptions from `BattleInteractionController.update_field_interaction_panel_metrics`.
4. Add a reusable discard-HUD binding helper in `BattleScene.gd`, limited to input wiring.
5. Add touch metric helpers in `HudTheme.gd` and reuse them from dialog/interaction controllers where needed.
6. Run focused portrait tests, then the functional portrait suite.

## Non-Goals

- Do not create a second battle scene.
- Do not rewrite card effects or interaction step generation.
- Do not change landscape visual layout except restoring portrait-only state.
- Do not change AI or LLM decision flow.
