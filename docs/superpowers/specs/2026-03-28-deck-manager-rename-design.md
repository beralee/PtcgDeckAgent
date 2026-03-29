# Deck Manager Rename Design

**Goal**

Allow players to rename an already saved deck directly from the deck manager list.

**Current Context**

- `scenes/deck_manager/DeckManager.gd` currently renders each saved deck row with `View` and `Delete` actions.
- The same file already contains a modal rename flow used when an imported deck name conflicts with an existing saved deck.
- `scripts/autoload/CardDatabase.gd` persists decks by overwriting the JSON file for a given `deck.id` through `save_deck(deck)`.

**Chosen Approach**

Add a `Rename` button to each deck row in the deck manager list and refactor the existing rename dialog logic in `DeckManager.gd` so both flows use the same validation and modal behavior.

This keeps the feature local to the deck manager screen, avoids persistence API changes, and preserves consistent validation behavior between import-time rename and manual rename.

**Behavior**

1. Each deck row shows `View`, `Rename`, and `Delete`.
2. Clicking `Rename` opens a modal prefilled with the current deck name.
3. Confirm stays disabled until the entered name:
   - is not empty after trimming
   - does not duplicate another saved deck name
4. The deck currently being renamed is excluded from duplicate detection, so keeping its current name is valid.
5. On confirm, trim the input, assign it to `deck.deck_name`, and persist through `CardDatabase.save_deck(deck)`.
6. Existing import-time duplicate-name handling continues to use the same modal flow, but without an ignored deck id.

**UI Design**

- Keep the current deck manager scene structure.
- Add one `Rename` button per deck item in the dynamically created row UI.
- Reuse a dynamically created modal dialog rather than introducing a new `.tscn`.
- The modal keeps the current pattern:
  - title
  - explanation text
  - `LineEdit`
  - inline validation label
  - confirm button

**Validation Rules**

- Normalize candidate names with `strip_edges()`.
- Empty names are rejected.
- Exact match against another saved deck name is rejected.
- For manual rename, ignore the current deck id during duplicate checks.
- For import rename, do not ignore any existing deck id.

**Data Flow**

- Manual rename updates the existing `DeckData` instance in memory.
- Persistence stays in `CardDatabase.save_deck(deck)`.
- `decks_changed` remains the refresh trigger for the list; no new signal is needed.

**Testing**

Extend `tests/test_deck_manager.gd` with coverage for:

- duplicate-name validation while ignoring the current deck id
- rejecting a name used by a different saved deck
- accepting the current deck name when renaming an existing deck
- persisting the new name after rename confirmation

Retain the existing import rename tests and keep cleanup explicit for any test decks written to disk.

**Risks**

- The current rename state in `DeckManager.gd` is import-oriented, so the refactor must avoid breaking the existing import flow.
- Tests that mutate saved decks must clean up persisted fixtures reliably.
