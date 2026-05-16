# Battle Portrait Layout Surface Contract

## Problem

Portrait battle layout currently lets several systems infer their own usable screen:

- `BattleScene` reads the raw viewport size.
- `BattleLayoutCoordinator` computes a logical size after optional forced rotation.
- `BattlePortraitLayoutView` lays out cards and HUDs from `portrait_content_rect`.
- Floating HUD overlays and hit testing later use scene-local coordinates.

When Android or desktop preview reports a wide logical portrait canvas, the layout may size hand rails, bench slots, pile HUDs, and top actions from a wider surface than the player actually sees. The result is the current failure mode: the right side of the field, hand rail, stadium/end-turn controls, and HUDs drift beyond the physical screen.

## Contract

All portrait battle UI must use a single layout surface.

- `physical_viewport_size` is the real viewport from Godot.
- `logical_size` is the root control size after optional forced-portrait rotation.
- `content_rect` is the only usable battlefield frame for portrait layout.
- `content_rect` is centered inside `logical_size` and may be narrower than the raw viewport.
- All portrait card sizes, top bar, main area, hand rail, stadium buttons, floating HUDs, dialogs, and click hit tests must fit or derive from `content_rect`.
- The scene root must be explicitly sized to `logical_size` for both rotated and non-rotated modes.

## Portrait Surface Rule

Portrait uses the full logical height. Width is bounded to a phone-shaped frame:

```
content_width = min(logical_width, round(logical_height * 9 / 16))
content_x = round((logical_width - content_width) / 2)
content_rect = Rect2(content_x, 0, content_width, logical_height)
```

This preserves full width on normal tall phones, but prevents short/wide portrait surfaces such as foldables or desktop portrait preview windows from stretching the battlefield past the usable visual area.

## Implementation Boundaries

- `BattleLayoutController` owns the content frame calculation.
- `BattleLayoutCoordinator` passes the resulting `content_rect` to the active layout view.
- `BattleScene._apply_battle_canvas_transform` owns root transform and size reset.
- `BattlePortraitLayoutView` must not recompute a different screen width. It receives `content_rect`, computes safe insets within it, and positions every portrait control inside it.
- Floating HUD overlays remain full logical size only as an input/click layer; their child groups are positioned and clamped to `content_rect`.

## Test Gates

The portrait regression suite must cover:

- Tall phones keep full-width content.
- Wide/short portrait surfaces are centered and aspect-bounded.
- Root scene size is updated in both rotated and non-rotated modes.
- Top bar, main area, hand rail, stadium/end-turn controls, bench grids, pile HUDs, prize HUDs, VSTAR HUDs, and floating HUD groups fit horizontally inside the active content frame.

Future UI changes should update the surface contract first instead of adding per-control width clamps.
