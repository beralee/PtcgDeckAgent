# Deck Share Poster Requirement Coverage Matrix

Source of truth: `docs/superpowers/specs/2026-07-05-deck-share-poster-core-design.md`.

`docs/design.md` was requested in the implementation rules but does not exist in this repository. The closest root-level document, `design_document.md`, was inspected for existing deck-management architecture only. Where it differs from the deck share poster core design, the core design wins.

## Assumptions

- Android MVP uses selected-image import, not live camera scanning.
- Android MVP uses Godot native file dialogs for both save and open. Saving goes through the Android system document UI, so the exported PNG is immediately visible to the same system picker without broad storage permissions.
- Imported share-image decks store author/source metadata in existing deck source fields and `strategy`; `DeckData` has no first-class author field yet.
- Missing card data blocks import. Missing card images do not block export.
- The platform adapter keeps the scanner/generator API stable so native ZXing/ML Kit backends can replace or supplement the pure-GDScript reader.
- Web export/import can be handled through JavaScriptBridge download and file input for the MVP bridge. Browser-native BarcodeDetector plus zxing-wasm remains an explicit future robustness task.

## Ambiguities, Conflicts, And Risks

- `docs/design.md` is absent. Use `2026-07-05-deck-share-poster-core-design.md` as the authoritative design.
- Android export currently has `gradle_build/use_gradle_build=false`; ML Kit requires an Android plugin/Gradle dependency. The current implementation intentionally avoids ML Kit by using Godot's native file dialogs and decoding this feature's generated QR images in GDScript.
- There is no existing QR/barcode library in the repo. `DeckShareQrEncoder.gd` remains for legacy QR compatibility and module fingerprint regression against the Nayuki reference implementation. `DeckShareDataStrip.gd` renders the poster payload as a horizontal data strip so the phone poster can prioritize card art and no longer needs to generate a visible QR block. The in-game reader is still a deterministic reader for generated images, not a full ZXing/ML Kit replacement.
- Godot `Image.save_png()` does not provide a direct metadata API in current project code. PNG metadata is optional and is not part of MVP correctness.
- Automated tests cover generated-image round trip, default saved-PNG round trip, resized JPG re-encode, Web bridge script contracts, and generated QR matrix compatibility. Android APK startup, system save dialog, Downloads visibility, system image picker import, import preview, duplicate-name rename flow, and final local save were verified on an emulator. Web browser export smoke remains recommended before claiming full Web platform parity.

## Coverage Matrix

| Requirement | Source section | Implementation files | Verification method | Status |
| --- | --- | --- | --- | --- |
| Merge the two draft docs into one authoritative core design | Request, document header | `docs/superpowers/specs/2026-07-05-deck-share-poster-core-design.md` | Manual read; source links included | Complete |
| Local deck exports to a shareable 1080px-wide PNG with height calculated from the 16:9 banner, actual card rows, data strip, and site footer | Goal, MVP flow, Share image content, Acceptance criteria | `scripts/deck_share/DeckPosterComposer.gd`, `scripts/deck_share/DeckSharePlatformAdapter.gd`, `scenes/deck_manager/DeckManager.gd` | `tests/test_deck_poster_composer.gd`; full functional suite; Android NAIC2025 system-save round trip | Complete |
| Export includes deck name, author, note, game/card DB version footer | Share image content, Share Poster HUD | `DeckPosterComposer.gd`, `DeckSharePayloadCodec.gd`, `DeckManager.gd` | Poster composer tests; deck manager HUD test | Complete |
| Export renders a two-part default background, centered banner title and author, unique card art in a tight 5-column phone layout, full-width bottom data strip, site footer, and lower-right duplicate badges | Share image content | `DeckPosterComposer.gd`, `assets/textures/deck_share/default_ghost_dragon_banner.png`, `assets/textures/deck_share/default_ghost_dragon_body.png` | `test_deck_poster_composer_outputs_dynamic_height_image`, `test_deck_poster_composer_uses_five_column_unique_card_layout`, `test_deck_poster_composer_renders_duplicate_count_labels`, `test_deck_poster_composer_places_art_title_and_author_in_banner_with_full_width_bottom_strip`; non-headless Dragapult poster preview | Complete |
| Missing card images render placeholders and do not block export | Share image content, Compatibility rules, Acceptance criteria | `DeckPosterComposer.gd` | `test_deck_poster_composer_missing_images_do_not_block_export` | Complete |
| Visible machine-readable code contains complete card identity data while avoiding a visually dominant QR block | Product principles, Data protocol, Acceptance criteria | `DeckSharePayloadCodec.gd`, `DeckShareDataStrip.gd`, `DeckShareQrEncoder.gd` | Codec round-trip; horizontal data-strip round-trip; generated QR image round-trip | Complete |
| Payload envelope has `magic`, `schema`, `game_version`, `card_db_version`, `created_at`, `deck`, `checksum` | Data protocol / Envelope | `DeckSharePayloadCodec.gd` | `tests/test_deck_share_payload_codec.gd` | Complete |
| Card tuple format is `[set_code, card_index, count]` with optional Limitless source hints | Deck Payload, Limitless Source Hints | `DeckSharePayloadCodec.gd`, `DeckShareImporter.gd` | Codec and importer tests | Complete |
| Payload normalizes sorting, merges duplicates, rejects invalid counts and non-60 decks | Deck Payload, Compatibility rules, Security limits | `DeckSharePayloadCodec.gd` | Codec validation tests | Complete |
| Encoding uses prefixed text, compression, Base45, CRC, and checksum | Encoding scheme | `DeckSharePayloadCodec.gd` | Corruption, wrong-prefix, unsupported-schema, bundled-budget tests | Complete |
| Legacy QR support uses standard Model 2, Q error correction, quiet zone, safe dimensions, and oversize handling | Machine code selection, Robustness, DeckShareQrEncoder | `DeckShareQrEncoder.gd` | `tests/test_deck_share_qr_encoder.gd`; standard module fingerprint test; bundled deck capacity test | Complete for legacy Version 26-Q payload budget |
| Image import opens a platform image picker path | From image import, Platform adapter | `DeckSharePlatformAdapter.gd`, `DeckManager.gd` | Deck manager import-panel UI test; platform adapter script tests; Android emulator picker smoke test | Complete for implemented picker paths; full successful device round-trip tracked below |
| Scanner returns encoded payload texts through stable API | Module design / DeckShareImageScanner | `DeckShareImageScanner.gd`, `DeckShareDataStrip.gd` | `tests/test_deck_share_image_scanner.gd` | Complete for generated horizontal strips, proportionally resized poster strips, and legacy QR images |
| Game decodes selected image and validates CRC/checksum/schema | Import flow, Security limits | `DeckShareImageScanner.gd`, `DeckSharePayloadCodec.gd` | Scanner and codec invalid-image tests | Complete |
| Import preview shows deck name, author, note, version, card count, missing cards, unimplemented warnings | From image import, Image import preview HUD | `DeckManager.gd`, `DeckShareImporter.gd` | Importer tests; deck manager UI construction tests; Android emulator import-preview screenshot | Complete |
| Saving imported deck uses `CardDatabase.save_deck` through existing import completion path | Import flow, Acceptance criteria | `DeckManager.gd`, `DeckShareImporter.gd` | Full `test_deck_manager.gd` import-completion regressions | Complete |
| Duplicate deck names reuse existing forced rename flow | Import flow, Acceptance criteria | `DeckManager.gd` | Existing duplicate-import rename tests in `test_deck_manager.gd` | Complete |
| Missing card data blocks import with clear error | Compatibility rules, Acceptance criteria | `DeckShareImporter.gd`, `DeckManager.gd` | `test_deck_share_importer_blocks_missing_card_data` | Complete |
| Unimplemented cards produce non-blocking warnings | Import preview HUD, Compatibility rules | `DeckShareImporter.gd` | `test_deck_share_importer_unimplemented_cards_warn_without_blocking` | Complete |
| Image import data is treated as untrusted input with size, row, decompression, checksum limits | Security limits | `DeckSharePayloadCodec.gd`, `DeckShareQrEncoder.gd`, `DeckShareImageScanner.gd` | Codec invalid/corruption tests; QR ECC verification; scanner format tests | Complete for implemented backend |
| URL import remains intact and separate from image import | Existing constraints, UI integration | `DeckManager.gd` | Full `test_deck_manager.gd`; functional suite | Complete |
| Deck manager exposes `分享图` action for local decks | MVP export flow, UI integration | `DeckManager.gd` | `test_deck_manager_deck_row_buttons_use_50_percent_larger_text`, `test_deck_manager_share_row_button_opens_share_poster_hud` | Complete |
| Deck view dialog exposes `分享图` action | MVP export flow | `DeckViewDialog.gd` | `test_deck_view_dialog_exposes_share_poster_button` | Complete |
| Import panel exposes `图片导入` alongside URL import | MVP import flow, UI integration | `DeckManager.gd` | `test_import_panel_exposes_image_import_button` | Complete |
| Portrait/mobile controls are touch-sized and modal layers block background touches | UI integration, Test plan | `DeckManager.gd`, existing non-battle layout/touch bridge | Existing deck manager and non-battle portrait tests in full functional suite | Complete for UI layout regressions |
| Windows can export and import generated PNG | Implementation phases, Acceptance criteria | Core scripts + `DeckSharePlatformAdapter.gd` | `test_deck_poster_composer_default_saved_png_roundtrips_through_scanner`; full functional suite; FileDialog path present | Complete for Windows filesystem round trip |
| Android selected-image import works through platform adapter | Android recognition, Implementation phases | `DeckSharePlatformAdapter.gd` | Native file dialog path/MIME/save-filter tests; Android APK export/install/launch; emulator system-save to Downloads; picker import; preview; duplicate rename; final save | Complete |
| Web download/file import bridge is supported or clearly gated | Web recognition, Implementation phases | `DeckSharePlatformAdapter.gd`, `DeckManager.gd` | Web JavaScriptBridge script tests; adapter callback decode test | Complete for MVP bridge; intentionally not implemented yet: browser manual QA and BarcodeDetector/zxing-wasm fallback |
| Tests are added for codec, importer, poster, scanner, and UI | Test plan | `tests/test_deck_share_*.gd`, `tests/test_deck_poster_composer.gd`, `tests/test_deck_manager.gd` | Focused suites and full functional suite | Complete |
| Manual QA checklist covers Windows, Android, Web | Test plan | This matrix | Review status rows above | Complete for MVP acceptance: Android manual round trip complete, Windows default saved-PNG round trip automated, Web follow-up gated |
