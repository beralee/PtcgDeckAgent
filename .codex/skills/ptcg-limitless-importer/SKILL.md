---
name: ptcg-limitless-importer
description: Use when importing or validating English Limitless TCG cards or deck URLs in this Godot PTCG repo, including mixed Chinese/English deck mapping, LEN_* generated cards, bundled deck data, card effect implementation, AI strategy wiring, and headless duel regression tests.
---

# PTCG Limitless Importer

## Workflow

1. Identify the source.
   - Limitless deck URLs look like `https://limitlesstcg.com/decks/list/<id>`.
   - Limitless card URLs look like `https://limitlesstcg.com/cards/<SET>/<number>`.
   - Local deck IDs use `800000000 + limitless_id`. Example: deck `18921` becomes `800018921`.

2. Parse through the repo adapter.
   - Use `scripts/network/LimitlessCardParser.gd` for HTML parsing.
   - Use `scripts/network/LimitlessCardResolver.gd` for local mapping.
   - Use `scripts/network/LimitlessCardTranslation.gd` for generated-card Chinese detail text. Keep rule-facing `name` / `text` values in abilities and attacks as the original English strings, and add display-only `name_zh` / `text_zh` fields so effect registration and AI strategy matching keep working.
   - Preserve `source_provider`, `source_url`, `source_set_code`, `source_card_index`, `source_language`, `source_prints`, `source_imported_at`, and `source_parser_version`.
   - Image URLs should use `CardData.build_limitless_image_url()` and local cache paths under `user://cards/images/<set_code>/<card_index>.png`.

3. Resolve cards conservatively.
   - Prefer exact English print metadata and same-print-group local implementations.
   - Map Basic Energy to canonical local energy cards.
   - Generate missing English cards as `LEN_<SET>_<number>` only when no unambiguous implemented local card exists.
   - Fail closed on ambiguous non-energy prints instead of guessing.

4. Bundle data.
   - Card JSON files go in `data/bundled_user/cards/`.
   - Generated Limitless card images go in `data/bundled_user/cards/images/<set_code>/<card_index>.png.bin`.
   - Deck JSON files go in `data/bundled_user/decks/`.
   - Add every new card JSON, bundled image, and deck JSON to `data/bundled_user/_manifest.txt`.
   - Built-in AI decks do not necessarily run the import-time image downloader, so bundled `LEN_*` cards must ship with images or they will render blank for fresh installs.
   - For translated generated cards, bundled card JSON should store the English rule-facing `name`, Chinese display-only `name_zh`, Chinese `description`, and `name_en` as the Limitless English identity. Preserve English attack/ability `name` fields plus display-only Chinese `name_zh` / `text_zh`.
   - If the deck should appear as a built-in AI opponent, add the deck ID to `CardDatabase.SUPPORTED_AI_DECK_IDS`.

5. Implement effects before declaring a card supported.
   - Register trainer, stadium, tool, and special energy effects in `scripts/engine/EffectRegistry.gd`.
   - Pokemon abilities and attacks may be routed by English names in `_get_ability_effect()` / `_get_attack_effects()` when the generated card has a stable Limitless `effect_id`.
   - Add new effect scripts under `scripts/effects/...`.
   - Verify with `CardImplementationStatus.is_unimplemented(card) == false` for every generated non-vanilla key card.

6. Wire AI decks when needed.
   - Add a strategy under `scripts/ai/DeckStrategy*.gd` when the deck has a distinct plan.
   - Register it in `scripts/ai/DeckStrategyRegistry.gd` by strategy ID and deck ID.
   - Score Dictionary interaction options explicitly; many headless prompts pass assignment or copied-attack dictionaries instead of raw cards or slots.

## Tests

Run focused tests first:

```powershell
D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe --headless --path . -s tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_limitless_importer.gd
D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe --headless --path . -s tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_limitless_ns_zoroark_effects.gd
D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe --headless --path . -s tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_limitless_ns_zoroark_deck.gd
```

For bundled generated cards, tests should prove the image path is in `_manifest.txt`, the `.png.bin` file is a valid image, Godot can decode it, and `CardData.resolve_existing_image_path()` falls back to the bundled image when `user://` cache is missing.

For translated generated cards, tests should prove:
- resolver-generated cards receive Chinese `name_zh` / `description` while preserving English `name` and `name_en`;
- attack and ability English `name` / `text` fields remain unchanged for rule logic;
- UI helpers such as `CardData.dictionary_display_name()` and `CardData.dictionary_display_text()` prefer `name_zh` / `text_zh`;
- deck entries display the translated generated card names while retaining `source_name` for Limitless audit metadata.

For headless stall reports, add or run an action-cap probe against the reported matchup and seed when available. A useful baseline is Limitless deck `800018921` versus rule Charizard `575716`.

Run full validation before finishing user-facing work:

```powershell
D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe --headless --path . -s tests/FunctionalTestRunner.gd
```

## Failure Checklist

- Deck imports 60 cards but `build_deck_instances()` returns fewer: missing card JSON, bad manifest entry, or stale user cache.
- Built-in Limitless cards render blank: missing bundled `data/bundled_user/cards/images/<set_code>/<card_index>.png.bin`, missing image manifest entry, invalid image bytes, or a stale card JSON image path.
- Card is visible but marked unimplemented: missing `effect_id`, registry entry, Pokemon ability route, or attack effect route.
- Headless duel hits `unsupported_interaction_step`: the effect exposes an interaction shape not handled by `AILegalActionBuilder`, `AIStepResolver`, or the deck strategy.
- Headless duel hits `action_cap_reached`: inspect decision trace tail for repeated no-progress actions, repeated prompts, dead active Pokemon, or strategy scores that prefer non-terminal loops.
- Limitless English names render incorrectly: keep generated JSON and GDScript source UTF-8, normalize curly apostrophes with `char(0x2019)` / `char(0x2018)` instead of embedding mojibake.
- Translated Limitless card stops matching an effect or AI rule: verify only display fields were translated. `effect_id`, attack `name`, ability `name`, `evolves_from`, and `name_en` should keep the rule-facing English identity unless the local rule explicitly supports Chinese aliases.
