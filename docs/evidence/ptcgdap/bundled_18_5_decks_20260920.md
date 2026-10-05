# Seven imported decks bundled as 18.5

## Change

The seven September 19 player imports matching the supplied screenshot are now
seeded from `data/bundled_user/decks/`. Their existing IDs, card printings,
quantities, source metadata, import dates and edit timestamps are preserved.
Only `deck_name` and `variant_name` are normalized to the `18.5 ` prefix.
The same display-name changes were applied to the seven local player files.

| Deck ID | Display name | Cards |
| --- | --- | --- |
| 675899 | 18.5 N的索罗亚克 | 60 |
| 675834 | 18.5 呆呆王 | 60 |
| 675893 | 18.5 太晶Box | 60 |
| 675892 | 18.5 火伊布 猫头夜鹰 | 60 |
| 675703 | 18.5 沙奈朵 | 60 |
| 675701 | 18.5 多龙巴鲁托 黑夜魔灵 | 60 |
| 675700 | 18.5 玛俐的长毛巨魔 雪妖女 | 60 |

The decks reference 115 distinct local card printings. `CSV6C_032` was the only
printing missing from the bundle; its existing imported JSON and image were
copied without modification. All other card data and images were already
bundled. The `30thC` image references use the existing `30THC` fallback.

Nine resource entries were appended to `_manifest.txt` (seven decks, one card,
one image). `_seed_content_sha256.txt` was regenerated so existing installations
run the seed refresh. The resulting revision is
`4AF16E8EFB3AB5CDE32261FFC874271C2AB622F51F68C50A8C3F813B774BBE38`.
The existing export `data/**` inclusion covers these assets.

## Verification

- RED: the two new `test_v18_5` regressions failed before adding the assets,
  because the requested decks were absent from both the bundle and a fresh
  player directory.
- GREEN: both regressions pass in a separate fresh player directory. Every
  referenced card JSON and valid bundled image is present in the manifest;
  each deck passes `DeckData.validate()` and builds 60 runtime instances.
- Full `test_card_database_seed.gd` suite: 84 tests, zero failures, exit 0.
  Its shutdown still reports ObjectDB leaks and three resources in use;
  this result is not a resource-lifetime acceptance claim.
- `python -X utf8 -m unittest tests.ptcgdap.test_bundled_seed_revision -v`:
  1 test, passed.
- Original-versus-bundle comparison: all seven card arrays and every field
  outside the two display names are unchanged. Local player JSON matches
  the corresponding bundled JSON.
- Scoped `git diff --check`: passed.

Godot commands used the existing `scripts/tools/run_godot_tests.ps1` focused
runner with `res://tests/test_card_database_seed.gd`, isolated `-UserDataRoot`
directories and Godot 4.6.1. RED/GREEN used
`-ExtraUserArgs '--test-filter=test_v18_5'`; the integration run omitted the
filter. Logs are in `.tmp/v18_5_bundle_{red,green,integration}.log` locally.

This verifies local bundled-data completeness and runtime loading. It does not
claim card-effect parity, AI strategy qualification, a new exported build or
device/release acceptance.

## AI opponent picker correction

The initial bundle change did not register the seven IDs in
`CardDatabase.SUPPORTED_AI_DECK_IDS`. Player decks could load, but the separate
AI opponent source intentionally filtered all seven out. On September 20 the
user identified the missing entries in the AI opponent picker.

The seven IDs are now explicitly included in that shortlist. The existing AI
loader reads their immutable bundled lists without depending on player edits
or a pre-existing `user://ai_decks` copy. The picker tab now says
`全部(更新18.5)`. At this stage strategy selection and ranking were unchanged;
the later chronology/LLM correction below supersedes those behaviors.

The new BattleSetup regression first reproduced zero rendered opponents for
the `18.5` search (expected seven). After the shortlist fix, it passes in a
fresh user directory: all seven actual picker buttons are rendered, each
button selects the correct AI opponent, and each AI deck matches its bundled
list and materializes 60 cards. Logs are
`.tmp/v18_5_ai_picker_{red,green,integration}.log`.

The full BattleSetup AI suite passes 46/46 after the correction. The seed suite
passes 84/84 again, and the focused 1280x720 picker-layout/tab-label regression
passes 1/1. All runners exit 0. The broader suites retain shutdown resource/RID
leak diagnostics, so these are functional results rather than lifetime gates.
Additional logs are `.tmp/v18_5_ai_seed_integration.log` and
`.tmp/v18_5_ai_layout.log`. Scoped `git diff --check` passes.

Already-running game processes retain their old script constants; a complete
game restart is required to load the new shortlist.

## Permanent bundled-deck completeness regression

`tests/test_bundled_deck_catalog.gd` adds a version-independent functional
suite. Its authority is the actual deck files (including unexpected nested
JSON files), not a fixed count or a copy of the AI shortlist. It checks:

- Every deck file has a manifest entry and a matching file/payload ID.
- Every deck is either an AI opponent or an explicitly documented player-only
  exception; duplicate and dangling registrations and conflicting scopes fail.
- The AI loader returns the exact expected bundled lists and builds all 60
  cards for each opponent.
- The actual BattleSetup picker renders every expected opponent button and
  clicking each button selects the corresponding deck.

`tests/fixtures/bundled_player_only_decks.json` explicitly records the 60
historical player-only entries to preserve the previous product scope. These
are not new AI qualifications. The fixture is fixed checked-in data, never a
test-time complement of `SUPPORTED_AI_DECK_IDS`; new exceptions require a
reason and stale or conflicting exceptions fail.

Sensitivity checks remove each of the 52 current AI registrations in memory,
simulate a future deck omitted from both manifest and AI registration, and
cover missing files, duplicate registrations, mismatched identities and stale
or unexplained exceptions. No player data is mutated by these negative probes.
The initial RED run without the historical exception inventory rejected all
60 unclassified existing entries. The final guard suite passes 7/7.

The standard functional runner automatically discovers the suite, and
`test_suite_catalog.gd` now explicitly requires its membership in the functional
group. `AGENTS.md` makes this suite, the seed suite and seed-revision test
mandatory for subsequent bundled-deck changes, and prohibits regenerating the
exception inventory to hide omissions.

Final validation:

```powershell
.\scripts\tools\run_godot_tests.ps1 -Runner functional -Suite 'BundledDeckCatalog,CardDatabaseSeed,SuiteCatalog' -UserDataRoot .godot_test_user\bundled_catalog_guard_integration
python -X utf8 -m unittest tests.ptcgdap.test_bundled_seed_revision -v
```

Results: functional 94/94, seed revision 1/1, both exit 0. The current scanned
inventory contains 112 decks: 52 AI opponents and 60 explicit player-only
exceptions. Log: `.tmp/bundled_catalog_guard_integration.log`.
This extension adds test/workflow coverage and an owner comment, without
changing runtime catalog membership or existing AI policy behavior.

## AI import chronology and explicit LLM eligibility

The seven bundled records have correct September 19 import timestamps. From
newest to oldest they are:

| Deck ID | Original import date |
| --- | --- |
| 675899 | 2026-09-19T21:32:58 |
| 675834 | 2026-09-19T21:31:58 |
| 675893 | 2026-09-19T21:29:30 |
| 675892 | 2026-09-19T21:28:53 |
| 675703 | 2026-09-19T21:27:55 |
| 675701 | 2026-09-19T21:27:22 |
| 675700 | 2026-09-19T21:26:44 |

All seven contain 60 cards, have empty `strategy` seed text, and have no
explicit deck-ID strategy registration. Their original import dates and
`updated_at` values are preserved; this correction changes no deck JSON.

The cause of the ordering issue was two separate ranking implementations:
`CardDatabase` pinned benchmark-ranked/versioned decks ahead of imports, while
BattleSetup reapplied strength/version/release/edit priority. Both now use
`CardDatabase.compare_ai_decks_by_import_time_desc`: descending original
ISO import date, descending deck ID for equal dates, undated decks last. The
current seven imports lead the built-in AI catalog and its visible picker.
Player edit sorting and author-package placement are separate and unchanged.

LLM capability previously accepted a heuristically inferred family. For
example, the new Flareon/Noctowl deck acquired `charizard_ex_llm` from card-name
matching even though its ID was not adapted. The registry now requires the
exact deck ID to be registered and any caller-supplied base strategy to match
that registration before exposing an LLM variant. Existing explicit legacy
and V18 adaptations remain available. A matching rules fallback does not
constitute LLM adaptation or a new competitive-strategy qualification.
The general model configuration used for strategy discussion is independent
of the opponent's LLM capability and is not removed.

The permanent catalog suite now additionally checks actual dropdown/button
order against bundled dates, a synthetic newer import against old benchmark
rankings and later edits, equal/missing dates, and denial of inferred LLM
support for every unregistered built-in and a simulated future deck. These
checks use source metadata and independent expectations, not a fixed newest
version or the production comparator. Before the fix, all three new catalog
tests failed (`.tmp/ai_order_red.log`); afterward the guard passes 10/10
(`.tmp/ai_order_green.log`). A separate UI regression covers all seven decks
with a fake configured DeepSeek key and a stale saved LLM choice: no support
star, no model strategy option, and no active LLM opponent. No API request is
made by this regression.

Final validation for this correction (all exit 0):

- `BundledDeckCatalog,CardDatabaseSeed,SuiteCatalog`: 97/97 in a fresh isolated
  user directory; `.tmp/ai_order_catalog_integration.log`.
- Full `BattleSetupAIVersions`: 47/47, including existing explicit LLM
  variants, player sorting, saved choices and author-package placement;
  `.tmp/ai_order_ui_integration.log`.
- `DeckStrategyRegistryExpansion`: 13/13, including existing exact deck
  registrations and rules startup; `.tmp/ai_order_registry_integration.log`.
- Python bundled seed revision: 1/1. Scoped `git diff --check`: passed.

The UI and registry suites emit shutdown RID/resource leak diagnostics
(the UI diagnostics also occurred before this correction); these are
functional checks, not resource-lifetime or exported
device acceptance. No model training, benchmark-strength requalification,
network inference, export or deployment was performed. Fully restart an
already-running source game to load the changed scripts.

## Rollback

Remove only these seven added deck files, the added `CSV6C_032` JSON/image and
their nine manifest lines. Regenerate the seed revision using
`python tools/ptcgdap/build_bundled_seed_revision.py`. Remove only the new
`V18_5_IMPORTED_DECKS` constant and two `test_v18_5` tests from the existing
seed suite. Preserve unrelated working-tree changes.

The AI-picker correction can be rolled back separately by removing just the
seven shortlist IDs, restoring the picker tab label, and reverting the matching
shortlist/layout expectations and new AI-picker regression. The bundled deck
files and player names do not depend on that correction.

The permanent guard can be removed independently by deleting its test and
exception fixture, removing its required suite-membership assertion, and
reverting only the added completeness-gate section in `AGENTS.md` and owner
comment in `CardDatabase.gd`. Preserve the seven AI registrations and their
earlier regressions when rolling back only the guard.

Original local player files and the previous manifest/revision are backed up
in `.tmp/v18_5_bundle_20260919/before/`; the adjacent `receipt.json` records
the original and bundled SHA-256 values. Restore player backups only if those
files still match this change's bundled hashes, so later player edits survive.

The chronology/LLM correction can be rolled back independently by restoring
the prior AI comparator implementations and inferred-base admission in
`DeckStrategyRegistry`, along with their matching test expectations. Keep the
seven bundled assets, manifest/seed changes and AI registration intact. Do
not use a whole-file checkout while unrelated worktree edits are present.
