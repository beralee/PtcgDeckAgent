# Deck Manager Rename Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a rename action to each saved deck row in the deck manager so players can update deck names with the same validation rules used during import.

**Architecture:** Keep the feature local to `DeckManager.gd`. Refactor the existing import rename dialog into a shared rename flow that can either rename an imported pending deck or an already saved deck, while continuing to persist through `CardDatabase.save_deck(deck)`.

**Tech Stack:** Godot 4, GDScript, existing headless `TestRunner.tscn` test harness

---

### Task 1: Add deck-manager rename regression tests

**Files:**
- Modify: `tests/test_deck_manager.gd`
- Test: `tests/test_deck_manager.gd`

- [ ] **Step 1: Write the failing tests**

Add tests that cover:

```gdscript
func test_existing_deck_name_validation_ignores_current_deck() -> String:
	# current name remains valid when ignoring its own deck id

func test_existing_deck_rename_validation_rejects_other_duplicate_name() -> String:
	# another saved deck name remains invalid

func test_confirm_existing_deck_rename_persists_trimmed_name() -> String:
	# rename confirmation writes back through CardDatabase.save_deck
```

- [ ] **Step 2: Run the test suite to verify it fails**

Run:

```powershell
& 'D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe' --headless --quit-after 20 --path 'D:\ai\code\ptcgtrain' 'res://tests/TestRunner.tscn'
```

Expected: FAIL in `DeckManager` tests because manual rename helpers and flow do not exist yet.

- [ ] **Step 3: Commit**

```bash
git add tests/test_deck_manager.gd
git commit -m "test: cover deck manager rename flow"
```

### Task 2: Implement rename action and shared rename modal

**Files:**
- Modify: `scenes/deck_manager/DeckManager.gd`
- Test: `tests/test_deck_manager.gd`

- [ ] **Step 1: Write the minimal implementation**

Update the deck manager to:

```gdscript
# add Rename button in _create_deck_item
# generalize duplicate validation with an optional ignored deck id
# reuse one modal flow for import rename and existing deck rename
# save the updated deck name through CardDatabase.save_deck(deck)
```

- [ ] **Step 2: Run the test suite to verify it passes**

Run:

```powershell
& 'D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe' --headless --quit-after 20 --path 'D:\ai\code\ptcgtrain' 'res://tests/TestRunner.tscn'
```

Expected: `DeckManager` tests pass and no new failures are introduced by this feature.

- [ ] **Step 3: Refactor only if still green**

If needed, rename helper methods or tighten the modal state shape while keeping behavior unchanged.

- [ ] **Step 4: Commit**

```bash
git add scenes/deck_manager/DeckManager.gd tests/test_deck_manager.gd
git commit -m "feat: add deck rename in deck manager"
```
