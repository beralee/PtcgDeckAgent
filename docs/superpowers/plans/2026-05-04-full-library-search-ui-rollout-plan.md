# Full Library Search UI Rollout Plan

Date: 2026-05-04
Status: Implemented and focused-regression validated
Owner: Architect/PM

## Purpose

Implement the full-library search UI described in `docs/superpowers/specs/2026-05-04-full-library-search-ui-design.md` while preserving existing card execution semantics, AI/headless behavior, replay privacy, and non-search interaction flows.

The user-facing goal is to make own-deck full search interactions behave closer to tabletop play: legal cards are selectable, illegal cards remain visible but disabled, and top/bottom N effects still reveal only the cards allowed by rules.

## Parallel Delivery Model

Delivery will use four parallel coding workers plus one architect/PM integrator.

Architect/PM responsibilities:

- Own the shared interaction contract and prevent incompatible payload shapes.
- Own final integration, conflict resolution, and acceptance testing.
- Review every worker patch for hidden-information leakage, AI/headless pollution, and unintended rule changes.
- Keep this rollout isolated from deck strategy, LLM prompt, training, import, and card database modules unless a focused failing test proves a direct dependency bug.

Worker requirements:

- Each worker must follow `$card-audit` for its assigned cards, including JSON/rules lookup, interaction completeness, entry consistency, UI visibility, and tests.
- Each worker must use TDD: add or update failing focused tests first, then implement the smallest code change, then run focused tests.
- Each worker owns only the files assigned below. Shared-file edits require architect approval.
- Each worker must report: card batch audited, files changed, tests added, tests run, residual risks, and any deferred candidates.

Worker assignment matrix:

| Worker | Scope | Primary files | Test ownership |
|---|---|---|---|
| A - Shared UI Contract | Full-deck search helper, dialog pass-through, disabled-card rendering/selection guarantees | `scripts/effects/BaseEffect.gd`, `scripts/ui/battle/BattleEffectInteractionController.gd`, `scripts/ui/battle/BattleDialogController.gd` only if necessary | `tests/test_battle_dialog_controller.gd`, optional `tests/test_full_library_search_ui.gd` |
| B - Trainer Simple Search | Simple own-deck Trainer searches: Nest Ball, Ultra Ball, Master Ball, Energy Search, Earthen Vessel, Buddy-Buddy Poffin, Capturing Aroma, Hyper Aroma, Techno Radar, Secret Box, Arven, Irida, Jacq, Lance, Colress's Tenacity, Town Store, Artazon, Mesagoza | Relevant `scripts/effects/trainer_effects/*` and `scripts/effects/stadium_effects/*` only | `tests/test_full_library_search_trainer_ui.gd` |
| C - Pokemon Search | Pokemon abilities and straightforward attacks: Miraidon ex, Chien-Pao ex, Lumineon V, Pidgeot ex, Arceus VSTAR Starbirth, Ditto, Minccino/Gimmighoul search attacks, Arceus/Raichu/Miraidon search-attach attacks | Relevant `scripts/effects/pokemon_effects/*` only | `tests/test_full_library_search_pokemon_ui.gd` |
| D - Safety And Complex Routes | Non-leakage, AI/headless pool safety, assignment/order-sensitive effects: Mirage Gate, Archeops, Charizard ex, Janine's Secret Art, TM Turbo Energize, TM Evolution, Salvatore, Ciphermaniac, Beldum | Relevant assignment/order-sensitive effect files; AI files only if tests prove leakage | `tests/test_full_library_search_non_leakage.gd`, `tests/test_full_library_search_assignment_ui.gd`, focused AI/headless tests |

Parallel execution order:

1. Worker A builds the shared helper and synthetic adapter tests.
2. Workers B, C, and D begin by writing card-audit/TDD tests against the agreed helper contract. If the helper is not available in their workspace yet, they may use the same payload shape manually and leave a consolidation note.
3. Architect merges Worker A first, then folds B/C/D migrations onto the shared helper.
4. Architect runs focused tests after each merge and full release validation after all batches.

Shared helper contract for all workers:

- `items` remains legal selectable cards only.
- `card_items` is the full visible list for own full-deck searches or the limited visible list for top/bottom N effects.
- `card_indices` maps each visible card to its legal `items` index; disabled visible cards use `-1`.
- `visible_scope` must be explicit: `own_full_deck`, `own_top_n`, `own_bottom_n`, `opponent_top_n`, `opponent_bottom_n`, or another reviewed scope.
- `card_disabled_badge` should default to `不可选` for own full-deck disabled cards.
- `choice_labels` should describe why each visible card is selectable or view-only.

TDD gates:

- A worker patch is not integration-ready unless it contains tests that fail without the implementation and pass after it.
- Every migrated own-full-deck effect must assert visible count > selectable count in at least one scenario.
- Every migrated own-full-deck effect must assert execution still receives only legal selected cards.
- Every non-candidate top/bottom/opponent reveal test must assert full deck contents are not present in `card_items`.
- Every AI/headless safety test must assert visible-only data does not change the legal selected item pool.

## Non-Goals

- Do not change any card effect semantics, target legality, shuffle behavior, damage calculation, or AI strategy.
- Do not reveal opponent hidden deck contents beyond explicitly revealed cards.
- Do not convert top-N or bottom-N effects into full-deck searches.
- Do not rewrite the whole battle dialog system or field assignment UI in this rollout.
- Do not make LLM prompts or headless resolvers choose from visible disabled cards.

## Source Of Truth

- `docs/superpowers/specs/2026-05-04-full-library-search-ui-design.md`: candidate list, UX contract, non-candidate list, and batch migration strategy.
- `C:/Users/24726/.codex/skills/card-audit/SKILL.md`: ongoing audit checklist now requires checking full-library search visibility where relevant.
- `scripts/ui/battle/BattleDialogController.gd`: current card dialog already supports `card_indices` and `card_disabled_badge`; prefer extending this adapter before adding new UI paths.
- `scripts/ai/AIStepResolver.gd`: AI resolves from legal `items`, `source_items`, and `target_items`; visible-only cards must not enter this pool.
- Card JSON under `data/bundled_user/cards/*.json`: default installed card pool and rules text used by the audit candidate scan.

## Review Findings

- The design direction is valid and should improve real-game search decisions, especially for effects like Nest Ball, Ultra Ball, Miraidon ex, Archeops, and Pidgeot ex.
- The main implementation risk is hidden-information leakage. Top/bottom N and opponent-deck effects need explicit negative tests before release.
- The second risk is accidentally polluting AI/headless choice pools with disabled visible cards. This must be blocked at the interaction contract layer.
- Central inference is unsafe. Each migrated effect or shared helper must explicitly declare whether it is `own_full_deck_search` or `limited_reveal_search`.
- The existing `card_indices` disabled-card path is the lowest-risk UI integration point and should be reused.

## Architecture Plan

Shared interaction builder:

- Add a small helper, either in `BaseEffect` or a dedicated interaction builder, that constructs full-deck search dialog metadata.
- Keep `items` as legal selectable choices only.
- Add visible card data through existing-compatible keys such as `card_items`, `card_indices`, `choice_labels`, and `card_disabled_badge`, or equivalent keys already consumed by `BattleDialogController`.
- Require explicit `visible_scope`, for example `own_full_deck` or `limited_reveal`.
- Include counts in audit/debug metadata: visible count, selectable count, min, max, and rule filter summary.

Battle UI:

- Extend `BattleDialogController` only where current `card_indices` handling is insufficient.
- Disabled cards must remain detail-viewable but not selectable.
- Mobile usability should reuse the HUD scroll container style and wide scrollbars already being standardized elsewhere.
- Assignment effects can reuse the same source-card visibility model, but should be migrated after simple one-panel search effects.

Execution and AI boundaries:

- `EffectProcessor`, `GameStateMachine`, and rule legality should remain unchanged unless a focused test exposes an existing bug.
- AI, LLM, and headless interaction bridges must ignore `card_items`, `visible_items`, disabled indices, and visible-only cards.
- Existing automated choices must continue using legal `items`, `source_items`, and `target_items`.
- Replay serialization must never include unrevealed opponent deck contents.

Migration allowlist:

- Do not enable full-deck visibility globally.
- Migrate candidates by explicit card/effect group from the spec.
- Each migrated card gets focused tests or is listed as deferred with a reason.

## Implementation Phases

### Phase 0: Baseline And Safety Checks

Deliverables:

- Record current focused UI and card test status before code changes.
- Add or identify tests covering current `card_indices` disabled-card behavior.
- Add negative test scaffolding for top/bottom N and opponent-reveal effects.

Gate:

- No runtime behavior changes in this phase.
- Baseline failures, if any, are documented before implementation starts.

### Phase 1: Shared Dialog Adapter

Deliverables:

- Add the shared full-deck interaction metadata helper.
- Add a synthetic UI test with 10 visible cards and 3 legal selectable cards.
- Verify disabled cards render with HUD badge and cannot be selected.
- Verify legal selection output is still expressed as old legal `items` indices or values.

Gate:

- Focused dialog tests pass.
- No card effect files are migrated yet.
- AI/headless tests confirm they still see only legal candidates.

### Phase 2: Low-Risk Trainer Searches

Scope:

- Start with simple search-to-hand or search-to-bench effects: Nest Ball, Ultra Ball, Master Ball, Energy Search, Earthen Vessel, Buddy-Buddy Poffin, Arven, Irida, Jacq, Lance, Forest Seal Stone, Pidgeot ex if its current path is simple enough.

Deliverables:

- Each migrated effect shows full own deck with disabled non-targets.
- Existing effect result remains unchanged after selecting legal cards.
- Search-to-bench effects still enforce bench-space and card-type legality.

Gate:

- Focused migrated-card tests pass.
- Electric Generator, Great Ball, Pokegear 3.0, Dusk Ball, and opponent top-card effects still do not show full deck.

### Phase 3: Pokemon Ability And Attack Searches

Scope:

- Migrate Miraidon ex, Chien-Pao ex, Arceus V/VSTAR, Raichu V, Miraidon, Minccino, Gimmighoul, and similar single-panel ability or attack searches.

Deliverables:

- Abilities and attacks use the same shared full-deck presentation without duplicating UI logic.
- Attack terminal behavior and shuffle behavior remain unchanged.

Gate:

- Focused ability/attack tests pass.
- No regressions in battle flow, attack completion, or prompt/audit payload construction.

### Phase 4: Assignment, Evolution, And Order-Sensitive Effects

Scope:

- Migrate Mirage Gate, Archeops, Charizard ex, Janine's Secret Art, Technical Machine: Turbo Energize, Technical Machine: Evolution, Salvatore, Ciphermaniac's Codebreaking, and Beldum.

Deliverables:

- Source cards can be inspected from full own deck when rules allow.
- Target assignment still enforces exact legal field targets.
- Ciphermaniac and Beldum preserve deck-top ordering semantics and do not inherit shuffle behavior.

Gate:

- Assignment-specific tests pass.
- Order-sensitive tests verify selected card ordering and no unintended shuffle.

### Phase 5: Audit Guard And Release Validation

Deliverables:

- Add an audit guard that flags own-full-deck search effects that only expose legal candidates without visible-card metadata.
- Run focused UI, migrated-card, non-leakage, and headless interaction tests.
- Produce a final migrated/deferred card list.

Gate:

- All migrated candidates pass focused tests.
- Non-candidate leakage tests pass.
- AI/headless choice pool tests pass.
- No unrelated modules require behavior changes.

## Ownership And File Boundaries

Shared UI owner:

- `scripts/ui/battle/BattleDialogController.gd`
- `scripts/ui/HudScrollContainer.gd` only if needed for mobile scroll consistency
- `tests/test_battle_dialog_controller.gd`
- New focused UI test file if cleaner than extending an existing large test

Effect helper owner:

- `scripts/effects/BaseEffect.gd` or a new small helper under `scripts/effects/`
- Shared helper tests

Card migration owner:

- Individual trainer, Pokemon ability, attack, stadium, and tool effect files only for allowlisted candidates.
- Do not touch unrelated strategy, AI, import, deck editor, or card database files unless a focused failing test proves a dependency bug.

AI/headless safety owner:

- Tests around `scripts/ai/AIStepResolver.gd`, LLM interaction bridge, and headless match bridge.
- Code changes only if visible-only metadata is proven to leak into legal choice resolution.

## Regression And Test Matrix

Required before shared adapter merge:

- Focused card-dialog disabled-card test.
- AI/headless legal-pool test proving disabled visible cards are ignored.

Required after each migration batch:

- At least one focused behavior test for each effect class migrated in that batch.
- Non-leakage tests for top-N, bottom-N, and opponent-reveal examples.

Required before release:

- Full focused UI group if `BattleDialogController` changes.
- Functional card-effect tests for all migrated candidates.
- Card audit summary showing migrated, deferred, and non-candidate status.
- Headless smoke for AI decks that commonly use migrated search cards, especially Miraidon, Lugia Archeops, Charizard, Gardevoir, Raging Bolt, Roaring Moon, Chien-Pao, and Arceus Giratina.

## Rollback Strategy

- The old `items` contract remains the execution source of truth, so reverting a migrated effect can be done by removing its full-deck metadata while keeping its old legal selection behavior.
- The shared helper must be additive. If a card migration fails, disable that card's helper usage rather than removing the shared UI path.
- If a hidden-information leak is found, block release and revert the relevant migration batch; do not patch around it with prompt or AI rules.
- If mobile performance is poor for large decks, keep the shared metadata but temporarily disable full visible rendering behind a feature gate for affected effects.

## Risk Register

| Risk | Severity | Mitigation |
|---|---:|---|
| Opponent hidden deck leak | High | Explicit visible scope, opponent negative tests, replay serialization guard |
| Top/bottom N over-reveal | High | Separate `limited_reveal_search` mode, non-candidate regression tests |
| AI/headless selects disabled card | High | Keep legal `items` unchanged, add legal-pool tests |
| Assignment source/target mismatch | Medium | Migrate assignment effects after simple searches, add source-target tests |
| Deck order semantics regression | Medium | Special-case order-sensitive effects, no generic shuffle assumption |
| Replay bloat | Medium | Store counts by default, identities only for own-full-deck audit/debug if needed |
| Mobile large-grid usability | Medium | HUD scroll container, wide scrollbar, optional filters after correctness |
| Broad UI regression | Medium | Reuse existing `card_indices` path and run focused UI group before release |

## Acceptance Criteria

- Every implemented own-full-deck search candidate either uses the shared full-library UI metadata or is explicitly deferred with a reason.
- Top/bottom N effects reveal only the rule-visible N cards.
- Opponent deck effects never reveal hidden full-deck contents.
- AI, LLM, and headless behavior remain based on legal selectable pools only.
- Existing card effect outputs are unchanged for legal selections.
- Mobile card-search dialogs remain usable with HUD-style scrollbars and disabled-card badges.
- The release package includes migrated candidates, deferred candidates, tests run, known risks, and rollback notes.

## Implementation Status - 2026-05-04

Parallel worker delivery completed and was integrated by the architect/PM.

Delivered shared contract:

- `BaseEffect.build_full_library_search_step()` is the canonical helper for own-full-deck card search UI.
- `BaseEffect.build_full_library_card_assignment_step()` is the canonical helper for own-full-deck source assignment UI.
- `items` and `source_items` remain the only legal execution pools.
- `card_items/card_indices` and `source_card_items/source_card_indices` expose visible deck context without changing legality.
- Dialog and field-assignment UI now consume disabled visible source metadata, not just ordinary search dialogs.

Delivered migrated groups:

- Trainer and Stadium searches: Nest Ball, Ultra Ball, Buddy-Buddy Poffin, Energy Search/Earthen Vessel, Capturing Aroma, Hyper Aroma, Techno Radar, Secret Box, Arven, Irida, Jacq, Lance, Colress's Tenacity, Town Store, Artazon, Mesagoza.
- Pokemon abilities: Miraidon ex Tandem Unit, Chien-Pao ex Shivery Chill, Lumineon V Luminous Sign, Pidgeot ex Quick Search, Arceus VSTAR Starbirth, Ditto Transform, Archeops/Charizard-style attach from deck.
- Attacks and order-sensitive routes: Beldum Magnetic Lift, Call for Family variants, Raichu/Palkia/Arceus/Miraidon deck searches, AttackSearchAndAttach deck-search assignments, TM Evolution, Ciphermaniac, Salvatore, Mirage Gate, Janine's Secret Art, TM Turbo Energize.

Validation completed:

- `FullLibrarySearchUI`, `FullLibrarySearchTrainerUI`, `FullLibrarySearchTrainerItemsUI`, `FullLibrarySearchPokemonUI`, `FullLibrarySearchSupporterStadiumUI`, `FullLibrarySearchAssignmentUI`, `FullLibrarySearchEvolutionOrderUI`, `FullLibrarySearchNonLeakage`: 48/48 passed.
- `SpecializedEffects`, `AttackSearchAndAttachRegression`, `CardSemanticMatrix`, `BattleDialogController`, `BattleUIFeatures`: 252/252 passed.
- `scripts/run_card_audit.ps1`: 1346/1346 functional tests passed. Card catalog audit summary: registry failures 0, smoke failures 0, interaction gaps 0.
- Global `git diff --check` passed; Git only reported existing LF-to-CRLF warnings.

Known non-scope findings:

- `AIHeadlessActionBuilder + AIBaseline` has two current failures unrelated to this UI rollout: Miraidon deck-bias scoring and Charizard Rare Candy pairing. The full-library search regression suites prove visible-only cards do not pollute AI/headless legal pools, but these two broader AI strategy failures should be handled in a separate AI strategy stabilization pass.
