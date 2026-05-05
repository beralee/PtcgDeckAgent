# Deck Recommendation Feed Rollout Plan

> **For implementation agents:** Follow this plan task by task. Keep each phase small, testable, and scoped. Do not refactor unrelated deck manager behavior while implementing this feature.

**Goal:** Replace the current three-card deck recommendation strip with one rich recommendation feed card that explains why a deck is worth playing, supports `换一套` through a cloud function, and remains safe when offline by using cache and embedded fallback content.

**Architecture:** Add a recommendation store and recommendation client, then make `DeckManager.gd` render a single normalized recommendation. Preserve the existing `DeckImporter` import path and existing saved deck list behavior.

**Tech Stack:** Godot 4, GDScript, existing headless focused test runner.

---

## Guardrails

- Do not modify `DeckImporter.gd`, `CardDatabase.gd`, `DeckData.gd`, battle scenes, deck editor, tournament, replay, or AI settings.
- Do not auto-import decks from recommendations.
- Do not block deck manager startup on network.
- Do not clear the current recommendation on request failure.
- Do not render untrusted server text as raw BBCode.
- Do not share the feedback cloud function endpoint or client.
- Do not remove embedded recommendation fallback until the cloud service is proven stable.

Allowed implementation files:

- `scenes/deck_manager/DeckManager.gd`
- `tests/test_deck_manager.gd`
- New `scripts/network/DeckRecommendationClient.gd`
- New `scripts/engine/DeckRecommendationStore.gd` or `scripts/data/DeckRecommendationStore.gd`
- New tests for the store/client, if helpful

---

## Task 0: Confirm Baseline And Dirty Worktree

**Files:**
- Read only unless resolving conflicts.

- [ ] Check `git status --short` and identify unrelated changes.
- [ ] Confirm whether current dirty `DeckManager.gd` and `tests/test_deck_manager.gd` changes are part of the branch to build on.
- [ ] Do not revert unrelated changes.
- [ ] Run focused deck manager tests before starting if the current tree is expected to be green:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\tools\run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_deck_manager.gd
```

Expected: either green baseline or a clearly documented pre-existing failure.

---

## Task 1: Add Recommendation Store Tests First

**Files:**
- Add or modify tests, such as `tests/test_deck_recommendation_store.gd`
- No UI changes yet

- [ ] Add tests for normalizing an embedded article into the new recommendation model.
- [ ] Add tests for accepting a valid server recommendation.
- [ ] Add tests for rejecting missing `id`, `deck_name`, or invalid `import_url`.
- [ ] Add tests that cap `why_play` to 3 visible entries.
- [ ] Add tests that de-duplicate recommendations by `id`.
- [ ] Add tests that keep only the most recent 10 cached items.
- [ ] Add tests for selecting the next cached recommendation after `current_id`.

Expected: tests fail because the store does not exist.

---

## Task 2: Implement `DeckRecommendationStore`

**Files:**
- Add: `scripts/engine/DeckRecommendationStore.gd` or `scripts/data/DeckRecommendationStore.gd`
- Test: store tests from Task 1

- [ ] Implement `normalize_recommendation(raw: Dictionary) -> Dictionary`.
- [ ] Implement `normalize_embedded_article(article: Dictionary) -> Dictionary`.
- [ ] Implement required-field validation.
- [ ] Implement UI-safe string trimming and length caps.
- [ ] Implement `load_cache()` and `save_cache()` using `user://deck_recommendations/cache.json`.
- [ ] Implement `upsert_item(item: Dictionary)` with de-duplication.
- [ ] Implement `get_current_or_fallback()`.
- [ ] Implement `get_next_cached(current_id: String)`.
- [ ] Keep all methods side-effect-light except explicit cache save/load.

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\tools\run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_deck_recommendation_store.gd
```

Expected: new store tests pass.

---

## Task 3: Refactor Deck Manager To One Local Feed Card

**Files:**
- Modify: `scenes/deck_manager/DeckManager.gd`
- Modify: `tests/test_deck_manager.gd`

- [ ] Replace `MAX_RECOMMENDATION_CARDS = 3` behavior with one selected normalized recommendation.
- [ ] Keep embedded `community-data.json` as local fallback source.
- [ ] Replace `RecommendationCards` row with one `RecommendationFeedCard`.
- [ ] Render first-screen fields:
  - deck name
  - title or style summary
  - `为什么值得玩`
  - `适合谁`
  - optional `上手看点`
  - source metadata
- [ ] Keep the saved deck list under the recommendation section unchanged.
- [ ] Wire `导入这套` to existing `_start_import_from_url(import_url, ...)`.
- [ ] Keep `查看完整解读` local and HUD-styled.
- [ ] Add `换一套` button, but initially make it cycle embedded/cache content only.

Update tests:

- [ ] Recommendation section is still the first child in `%DeckList`.
- [ ] It renders exactly one feed card.
- [ ] It contains "为什么值得玩" or normalized why-play content.
- [ ] Saved deck rows still render after the recommendation section.
- [ ] Import action still uses the existing import path.

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\tools\run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_deck_manager.gd
```

Expected: deck manager tests pass.

---

## Task 4: Integrate Cache Into Deck Manager

**Files:**
- Modify: `DeckManager.gd`
- Modify: store tests or deck manager tests

- [ ] Instantiate the recommendation store inside `DeckManager` only.
- [ ] On ready, choose display priority:
  1. current cached item
  2. next valid cached item
  3. embedded fallback item
  4. lightweight empty placeholder
- [ ] Persist the displayed server item only after validation.
- [ ] On `换一套`, immediately show a different cached item if one exists.
- [ ] Do not write cache when only embedded fallback is displayed unless that behavior is explicitly chosen.
- [ ] Confirm manual import and saved deck actions still work when cache file is missing or malformed.

Run focused tests:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\tools\run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_deck_manager.gd
```

---

## Task 5: Add Recommendation Cloud Client

**Files:**
- Add: `scripts/network/DeckRecommendationClient.gd`
- Add: `tests/test_deck_recommendation_client.gd` if practical

- [ ] Define a dedicated endpoint constant, for example `http://fc.skillserver.cn/deck-recommendation`.
- [ ] Build request body with:
  - `app_version`
  - `platform`
  - `mode`
  - `current_id`
  - `seen_ids`
  - `local_deck_ids`
  - `locale`
- [ ] Use `HTTPRequest` with timeout around 10-12 seconds.
- [ ] Emit success only after response JSON contains `ok: true` and a dictionary `recommendation`.
- [ ] Emit failure for HTTP errors, request failures, malformed JSON, and `ok: false`.
- [ ] Keep response validation final authority in `DeckRecommendationStore`.
- [ ] Do not issue live network calls from unit tests; test parse/normalization helpers directly.

Run client/store tests.

---

## Task 6: Wire `换一套` To Cache-First Network Refresh

**Files:**
- Modify: `DeckManager.gd`
- Modify: `tests/test_deck_manager.gd`

- [ ] Instantiate `DeckRecommendationClient` only when the deck manager screen needs it.
- [ ] On `换一套`:
  1. Disable only the `换一套` button.
  2. Show next cached recommendation immediately if available.
  3. Send a network request in the background.
  4. If the server returns a valid recommendation, save and display it.
  5. If the server fails, keep the current card and show a small status line.
- [ ] Ignore late responses if the node has exited tree or a newer request superseded the response.
- [ ] Re-enable `换一套` after success or failure.
- [ ] Do not disable saved deck buttons, manual import, image sync, or back navigation.

Regression tests should cover:

- cached item appears without network success
- invalid server item does not replace current card
- request failure leaves current card visible
- busy state only affects recommendation controls

---

## Task 7: Detail Modal And Text Safety

**Files:**
- Modify: `DeckManager.gd`
- Test: deck manager tests

- [ ] Replace any default `AcceptDialog` recommendation article view with a HUD-styled modal if not already done.
- [ ] Render server detail text as plain text or escaped content.
- [ ] Cap detail section count and text length before creating UI nodes.
- [ ] Keep external links behind explicit player actions.
- [ ] Ensure modal close behavior does not affect import panel or rename dialogs.

Run deck manager tests.

---

## Task 8: Visual And Mobile Pass

**Files:**
- Modify only deck manager UI code if needed

- [ ] Check desktop viewport around 1600x900.
- [ ] Check mobile-like narrow viewport.
- [ ] Verify the single card does not push saved deck rows too far down.
- [ ] Verify buttons wrap without overlapping.
- [ ] Verify text stays readable and does not overflow.
- [ ] Verify long deck names and long `why_play` items are capped or wrapped.
- [ ] Verify failed network status is visible but not visually dominant.

If a screenshot helper is created, remove it before finishing.

---

## Task 9: Final Regression

Run focused suites:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\tools\run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_deck_manager.gd
powershell -ExecutionPolicy Bypass -File scripts\tools\run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_deck_recommendation_store.gd
```

If a client test file exists:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\tools\run_godot_tests.ps1 -Runner focused -SuiteScript res://tests/test_deck_recommendation_client.gd
```

Then run any broader quick suite normally used for UI regressions if the branch is otherwise stable.

Expected result:

- Deck manager recommendation feature passes.
- Existing deck import tests still pass.
- Existing saved deck list behavior remains unchanged.
- No battle, deck editor, tournament, replay, or AI settings tests need updates for this feature.
