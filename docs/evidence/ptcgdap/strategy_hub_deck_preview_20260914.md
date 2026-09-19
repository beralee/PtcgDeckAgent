# Installed strategy deck preview

Date: 2026-09-14

The strategy hub now shows the exact installed package's deck inline in its
details sheet. The local library adds a “查看详情” button; marketplace and
continuous-ladder details show the same preview when their exact package ID,
version and archive hash are installed. Catalog refresh updates an open preview
after download or removal. Closing or opening another detail clears prior art.

The hub requests a read-only, freshly inspected package handle from the existing
catalog and uses `AuthorStrategyDeckMaterializer` to obtain the package deck.
It does not infer the deck from a title, source deck number or another version,
and viewing a deck grants no battle readiness. Inspection failures replace the
grid with a readable unavailable message. Undownloaded releases have no grid.

`DeckViewDialog.populate_preview_grid` reuses the existing card images, proxy
fallbacks, printing identity, category sorting, duplicate merging and count
badges. It embeds directly in the details scroll; portrait uses four columns
where space allows, and landscape uses up to eight. Card typography remains
proportional to the tile rather than inheriting large mobile paragraph text.

Validation:

- Initial regression failed because the details page had no card grid.
- New preview tests: 2/2, using a real inspected local package and checking
  exact-reference lookup, 60-card counts, local/marketplace entrypoints,
  navigation clearing, unknown hashes, failed reads and four grid widths.
- Existing strategy hub suite: 22/22.
- Existing deck viewer tests: 11/11.
- Actual Godot OpenGL rendering inspected at 900×1800 and 1600×900: card art,
  count badges, portrait/landscape columns and vertical scrolling are visible.
  Local screenshots: `tmp/strategy-deck-900.png`, `tmp/strategy-deck-1600.png`.
- Runtime diff whitespace checks pass. Existing Unicode NUL startup warnings
  remain; this is local functional/layout evidence, not APK device acceptance.

Rollback: remove only this change's deck-preview hooks and local detail button
from `StrategyHub.gd`, the three deck-section nodes from `StrategyHub.tscn`, and
the additive `populate_preview_grid` method from `DeckViewDialog.gd`. Preserve
the substantial pre-existing changes in the hub files. No strategy archive,
battle engine, external oracle, private service, commit, push or release was
modified by this task.
