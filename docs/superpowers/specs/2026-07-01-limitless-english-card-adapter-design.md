# Limitless English Card Adapter Design

Status: reviewed and implemented
Date: 2026-07-01

Review resolution:

- Use a high positive id namespace for Limitless decks. Do not use negative ids.
- Add provider-aware URL parsing before the legacy numeric deck-id parser.
- Persist source metadata on generated English cards, not only on deck entries.
- Treat import success and rule-runnable success as separate gates.
- Require the N's Zoroark example deck's gameplay-critical cards to be implemented or mapped before the AI strategy is considered complete.
- System-design review initially blocked approval on missing Pokemon parser fields, ambiguous same-print fail-closed behavior, deck source audit metadata, provider URL strictness, and generated `LEN_*` collision protection. Those blockers are covered by regression tests and fixes in `LimitlessCardParser.gd`, `LimitlessCardResolver.gd`, `DeckImporter.gd`, and `800018921.json`.
- PTCG rules review accepted the N's Zoroark rule implementation after focused effects tests and headless rule-AI smoke coverage.
- The first implementation uses the curated `ACE_SPEC_REFS` table in `LimitlessCardParser.gd`; it does not attempt a general ACE SPEC scraper.
- The repo-local skill is tracked under `.codex/skills/ptcg-limitless-importer/` through a targeted `.gitignore` exception.

## Goal

Add a reusable import path for Limitless TCG English card and deck links while preserving the current Chinese-first runtime model.

Required examples:

- Card: `https://limitlesstcg.com/cards/OBF/186` (Arven)
- Deck: `https://limitlesstcg.com/decks/list/18921` (N's Zoroark)

The target behavior is:

1. A Limitless deck can be imported from `/decks/list/{id}`.
2. Each deck entry uses the existing local Chinese card when the card can be mapped safely.
3. Only cards with no safe local equivalent are imported as English card records.
4. Mixed Chinese and English decks still build 60 `CardInstance` objects and can run in rule AI battles.
5. A repo-local Codex skill documents and automates future Limitless English card imports.

## Current Repo Model

The existing import path is centered on `scripts/network/DeckImporter.gd` and `tcg.mik.moe`.

- `DeckImporter.import_deck()` accepts a tcg.mik deck id or URL and fetches `deck/detail`.
- `DeckData.cards` stores `set_code`, `card_index`, `count`, `card_type`, `name`, `effect_id`, and `name_en`.
- `CardDatabase.build_deck_instances()` only resolves cards by local `set_code/card_index`.
- `CardData` already stores English identity fields: `set_code_en`, `card_index_en`, and `name_en`.
- `CardEffectAliasResolver` can alias same-language duplicate effects, but it compares localized effect signatures. It cannot safely prove that English text and Chinese text are identical effects.

Important constraint: `CardData.ensure_image_metadata()` currently rewrites `image_url` and `image_local_path` from `set_code/card_index` using the `tcg.mik.moe` image layout. English card records therefore need an explicit image metadata policy before they are cached.

## Limitless Facts Observed

Limitless card URLs use:

```text
https://limitlesstcg.com/cards/{SET}/{NUMBER}
```

The Arven page exposes:

- Current identity: `OBF/186`.
- Name: `Arven`.
- Type text: `Trainer - Supporter`.
- Rules text in a `.card-text-section`.
- Current print block: `Obsidian Flames (OBF) #186`.
- Other international prints as links, for example `SVI/166`, `SVI/235`, `SVI/249`, `PAF/235`.
- Card images on `limitlesstcg.nyc3.cdn.digitaloceanspaces.com/tpci/...`, with size suffixes such as `_XS`, `_SM`, `_LG`, and full image without the size suffix.

Limitless deck URLs use:

```text
https://limitlesstcg.com/decks/list/{ID}
```

The N's Zoroark page exposes:

- Deck title in `.decklist-title`.
- Sections: `Pokemon (17)`, `Trainer (35)`, `Energy (8)`.
- One `.decklist-card` per unique card.
- Stable card attributes per entry: `data-set`, `data-number`, `data-lang`.
- The visible count in `.card-count`.
- The visible English name in `.card-name`.
- Basic Energy entries also include `data-basic-energy`.

This means a deck parser should not infer card identity from display text. It should parse the `data-set` and `data-number` attributes.

## Identity Strategy

### Local identity remains unchanged

The game runtime continues to use `CardData.get_uid()`:

```text
{set_code}_{card_index}
```

No existing deck builder, battle setup, effect registry, or replay code should be required to resolve foreign ids at runtime.

### Add a Limitless identity layer

Introduce a small adapter service that maps Limitless ids into local `CardData` ids before saving the deck:

```text
LimitlessCardRef {
  lang: "en",
  set_code: "OBF",
  number: "186",
  name: "Arven"
}
```

The adapter resolves each card in this order:

1. Exact English-id match in local cards:
   - local `card.set_code_en == limitless.set_code`
   - local `card.card_index_en == limitless.number`
2. Same-print-group match:
   - fetch the Limitless card page
   - collect all international print links for the same card text
   - use any local card whose `set_code_en/card_index_en` appears in that print group
3. Name-only fallback for Basic Energy:
   - Basic Energy print numbers are cosmetic for game behavior
   - map to bundled `CSVE1C_*` cards by English energy name or inferred energy type
4. English card import:
   - only when no safe local match exists
   - create a new local card uid under an English namespace

All identity comparisons normalize set codes to uppercase and normalize numeric-only card numbers by stripping leading zeroes. The original Limitless card number is still preserved in metadata and source reports.

Same-print-group matching fails closed unless all of the following are true:

- `name_en` matches after whitespace normalization.
- `card_type` is compatible.
- `mechanic` is compatible for rule-box Pokemon and ACE SPEC cards.
- no multiple local candidates with different non-empty `effect_id`s remain after filtering.

The resolver owns an English-id index over `CardDatabase.get_all_cards()` rather than adding a second primary key to `CardDatabase`.

### English namespace

Use a local synthetic set namespace for generated English cards:

```text
LEN_{SET}
```

Examples:

- `LEN_JTG_98`
- `LEN_OBF_186`

Rules:

- `set_code` is `LEN_{limitless_set}`.
- `card_index` is the normalized Limitless number with leading zeroes stripped for numeric-only numbers.
- `set_code_en` is the original Limitless set.
- `card_index_en` is the original Limitless number without lossy conversion.
- `name` and `name_en` are both set to the English name unless a Chinese translation is intentionally supplied.
- existing `LEN_*` cards are never silently overwritten if their source metadata differs.

The `LEN_` prefix avoids collisions with Simplified Chinese sets and with existing tcg.mik data.

Generated cards persist source metadata on `CardData`:

```text
source_provider = "limitless"
source_url = "https://limitlesstcg.com/cards/JTG/98"
source_set_code = "JTG"
source_card_index = "98"
source_language = "en"
source_prints = ["JTG/98", ...]
source_imported_at = unix milliseconds
source_parser_version = 1
```

Deck entries still preserve source metadata too, because the same local card can satisfy multiple Limitless print requests.

## Card Parsing Strategy

Create a parser that converts Limitless card HTML into an intermediate record before building `CardData`.

Implemented files:

- `scripts/network/LimitlessCardParser.gd`
- `scripts/network/LimitlessCardResolver.gd`
- `scripts/network/DeckImporter.gd`

The parser should extract:

- `set_code`, `number`, `name`
- `card_type`: map Limitless display into existing internal values
  - `Pokemon`
  - `Item`
  - `Supporter`
  - `Tool`
  - `Stadium`
  - `Basic Energy`
  - `Special Energy`
- `mechanic`: `ex`, `V`, `VSTAR`, `VMAX`, `Radiant`, `ACE SPEC`, or empty
- `label` and `is_tags`: where available from title/type text
- `description`
- `artist`
- `rarity`
- `regulation_mark`
- Pokemon attributes:
  - `energy_type`
  - `stage`
  - `hp`
  - `evolves_from`
  - `weakness_energy`
  - `weakness_value`
  - `resistance_energy`
  - `resistance_value`
  - `retreat_cost`
  - `attacks`
  - `abilities`
- image URLs:
  - preferred full card image from `.card-image img[data-src]`
  - fallback to `.card-image img[src]`
- same-print ids:
  - all non-JP `/cards/{SET}/{NUMBER}` links in the print table

ACE SPEC note: some Limitless card detail pages, such as Secret Box, do not expose "ACE SPEC" as visible card detail text even though `q=is:ace` recognizes them. The first implementation must either query/fixture ACE status separately or carry a curated ACE SPEC set for imported cards. The parser must not assume rarity alone is enough to infer `mechanic = "ACE SPEC"`.

For attack costs, Limitless uses text such as `DD` inside `.ptcg-symbol`. Keep the internal one-letter encoding already used by the repo. For now, parse the rendered symbol text and normalize:

- `G`, `R`, `W`, `L`, `P`, `F`, `D`, `M`, `N`, `C`
- repeated letters remain repeated
- empty or `0` means no cost

## Image Metadata Strategy

Do not let generated English cards point at `tcg.mik.moe`.

Preferred implementation:

1. Add provider/source image fields to `CardData`.
2. Make `ensure_image_metadata()` provider-aware:
   - existing Chinese cards keep current `tcg.mik.moe` behavior
   - `source_provider == "limitless"` preserves the Limitless CDN `image_url`
   - `source_provider == "limitless"` derives local path with the current path shape:

```text
user://cards/images/LEN_{SET}/{NUMBER}.png
```

This keeps existing image consumers compatible because they already understand `set_code/card_index` paths. No nested `LEN/{SET}` directory is introduced.

The implementation should include a regression test proving that a `LEN_OBF/186` card keeps its Limitless CDN image URL after `cache_card()`.

## Deck Import Strategy

Add Limitless support without breaking the current tcg.mik importer.

Recommended shape:

- Keep `DeckImporter.gd` as the public import facade.
- Detect provider by URL:
  - `tcg.mik.moe` or numeric id -> existing path
  - `limitlesstcg.com/decks/list/{id}` -> Limitless path
- Move provider-specific logic into helper methods or provider classes.
- Add `parse_provider_ref(input)` before the legacy `parse_deck_id(input)` path. This function validates host and route so a Limitless `/decks/list/{id}` URL cannot accidentally enter the tcg.mik importer.

For a Limitless deck:

1. Fetch deck page HTML.
2. Parse title and `.decklist-card` entries.
3. For each entry, resolve Limitless identity into a local `CardData`:
   - local exact English-id match
   - local same-print-group match
   - local Basic Energy fallback
   - generated English card
4. Save any generated English cards with images.
5. Build a `DeckData` whose `cards` entries point only to local `set_code/card_index`.
6. Preserve audit metadata in optional extra deck-entry fields:

```json
{
  "source_provider": "limitless",
  "source_set_code": "OBF",
  "source_card_index": "186",
  "source_name": "Arven",
  "resolved_via": "same_print_group"
}
```

Existing consumers ignore unknown dictionary fields, so this should be backward compatible.

Deck ids from Limitless can collide with tcg.mik ids. Store imported Limitless decks under a high reserved range:

```text
id = 800000000 + limitless_id
source_provider = "limitless"
source_id = 18921
source_url = "https://limitlesstcg.com/decks/list/18921"
```

Do not use negative ids. Existing code treats `deck.id <= 0` as invalid or special in multiple flows.

## Effect Strategy

Do not use English-vs-Chinese text equality for automatic effect aliases.

Resolution policy:

- If a local Chinese card is selected, use its existing `effect_id` and implementation.
- If an English generated card is selected and has no implementation:
  - leave `effect_id` deterministic but unimplemented
  - card audit should report it as a gap
  - battle should not freeze; it should degrade like any other unimplemented effect
- Optional future work: add curated cross-language aliases, keyed by Limitless print group and reviewed manually.

Generated English effect ids should be deterministic:

```text
md5("limitless:%s:%s:%s" % [lang, set_code, number])
```

This keeps audits stable across imports.

The importer must produce a per-card resolution report:

```json
{
  "source": "JTG/98",
  "source_name": "N's Zoroark ex",
  "resolved_uid": "LEN_JTG_98",
  "resolved_via": "generated_english_card",
  "implementation_status": "unimplemented",
  "rule_runnable": false
}
```

A deck can be "representable" when all 60 cards resolve to local `CardData`. A deck is "rule-runnable" only when all gameplay-critical cards used by the assigned strategy are implemented or explicitly guarded away.

## N's Zoroark AI Strategy

The example deck needs a rule-driven strategy that can finish a game against rule Charizard without errors.

Implemented strategy id:

```text
ns_zoroark
```

Implemented files:

- `scripts/ai/DeckStrategyNsZoroark.gd`
- registry entry in `scripts/ai/DeckStrategyRegistry.gd`
- bundled or generated AI deck json for the imported deck

The first rule version should be conservative:

- prioritize N's Zorua and N's Zoroark ex setup
- use Arven for Items and Tools
- use Ultra Ball/Nest Ball/Buddy-Buddy Poffin for setup
- use Artazon only when bench space and a valid Basic target exist
- use N's PP Up only when there is a Basic Energy in discard and a benched N's Pokemon target
- avoid optional draw/churn when near deck-out
- attack with N's Zoroark ex when it has enough Darkness Energy and can copy a useful benched N's attack
- handle missing imported English effects by falling back to general AI scoring and legal-action validation

Blocking requirement for the example deck:

- `N's Zoroark ex` must have a working `Trade` ability and `Night Joker` copy attack.
- `N's Zorua`, `N's Reshiram`, and `N's PP Up` must be implemented, mapped, or explicitly removed from strategy dependence.
- generated unimplemented Trainer cards must not be treated as productive rule-AI actions.
- `SVE/7` Darkness Energy and `SVE/6` Fighting Energy must map to canonical local Basic Energy cards, not generated English energy cards.

This strategy should be written after the importer tests prove the deck can be represented locally and the targeted N's Zoroark effects are rule-runnable.

## Tests

Add tests before implementation.

Parser tests:

- parse `OBF/186` fixture and verify name, type, description, regulation mark, rarity, image URL, and same-print ids including `SVI/166`.
- parse `JTG/98` fixture and verify Pokemon attributes, ability, attack cost `DD`, weakness, retreat, and print group.
- parse `decks/list/18921` fixture and verify 31 unique entries and 60 total cards.
- verify `data-set/data-number` are used, not display names.
- verify ACE SPEC status for Secret Box via a fixture or curated lookup.

Resolver tests:

- exact English-id match selects the local card.
- same-print-group match maps `OBF/186` Arven to local `CSV1C_123` through `SVI/166`.
- Basic Energy maps `SVE/7` Darkness and `SVE/6` Fighting to bundled local energy cards.
- unknown card creates a `LEN_*` card with original `set_code_en/card_index_en`.
- `LEN_*` card image URL survives `ensure_image_metadata()`.
- ambiguous same-print matches with different effect ids fail closed.
- copy-limit validation uses canonical `name_en` after resolution, except Basic Energy.

Deck import tests:

- importing the N's Zoroark fixture creates a 60-card `DeckData`.
- every deck entry points to a locally resolvable `CardData`.
- deck metadata preserves original Limitless ids.
- tcg.mik import path still works.

Battle tests:

- build mixed deck instances from imported N's Zoroark deck.
- prove `N's Zoroark ex` `Trade` and `Night Joker` resolve in isolated scenarios.
- smoke a headless match against the existing rule Charizard deck for a bounded number of turns with no stalls, no missing-card warnings, and no uncaught errors.
- register `ns_zoroark` in `DeckStrategyRegistry` and verify it resolves for the deck id.

Skill tests:

- create `.codex/skills/ptcg-limitless-importer/SKILL.md`.
- include a reference document describing Limitless HTML selectors and the local mapping policy.
- include a script or documented command that imports a card URL and reports:
  - matched local card
  - generated English card
  - missing implementation status

Validate the skill with the system skill validator after creation.

## Resolved Review Questions

1. Generated English cards use normal `CardData` records under the `LEN_*` namespace, but source metadata must match before an existing generated card can be reused or overwritten.
2. The bundled N's Zoroark deck requires its gameplay-critical generated cards to be implemented. Non-engine cards may map to local implementations, but generated unimplemented Trainer cards must not be treated as productive rule-AI actions.
3. ACE SPEC status is handled by a small curated table for this implementation.
