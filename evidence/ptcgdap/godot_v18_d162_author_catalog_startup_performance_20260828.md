# Godot v18 D162 author catalog startup performance evidence — 2026-08-28

## Scope and acceptance gate

This work package owns ordinary application startup discovery of local author strategy packages. Acceptance requires a clean-user-root reproduction, a bounded metadata cache that cannot grant match authority, exact built-in archive binding, match-time revalidation, a rollback profile, and focused BattleSetup/navigation regressions. It does not change policy behavior, select-window indexes, engine execution, card rules, animation, or replay schemas.

Status: `implemented_focused_tested_player_visible_restart_confirmation_pending`.

## Reproduction and root cause

The isolated pre-fix profile log was created at 23:31:46 and completed at 23:32:18; its author catalog cache was not written until 23:32:17. The tested root contains 47 built-in `.ptcgai` archives totaling 3.87 MiB. A cold catalog had no usable location index, so it read every archive and ran the pure-GDScript package loader, including manifest/file hashing and Ed25519 verification, before the UI could stay responsive.

The ordinary client showed the same signature: its catalog cache was written approximately 31 seconds after process start. The later `BattleSetup.tscn` threaded-prewarm timeout is real but bounded at 100 ms; it was a secondary symptom while startup work and scene loading overlapped, not the source of the 30-second delay. A separate replay-exam process produced the large pretty JSON log and is not attributed to client startup.

## Implemented boundary

- Cache schema v2 stores logical archive path, install source, location ID, byte size, modified time, raw archive SHA-256, and already validated copy-only metadata.
- A generated `res://data/ptcgdap/author_strategy_catalog_cache.json` binds all 47 current built-in archives. Its regression test recomputes every archive's size and SHA so source drift fails the gate.
- Built-in cache hits use path and size across source checkouts/exported PCK timestamp changes. User package hits additionally require exact modification time. New, removed, resized, or modified user packages fall back to archive capture and strict inspection.
- Startup cache output remains `startup_cache_authority=false`; catalog output remains `match_authority=false` and `execution_authority=false`.
- `request_ready_match_handle` is unchanged at the authority boundary: it rereads the chosen archive, verifies the expected SHA, performs match inspection, release approval, and exact deck gating before constructing a sealed handle.
- Rollback for a new process is `PTCGDAP_AUTHOR_CATALOG_STARTUP_PROFILE=deep_scan_v1`; the default is `cached_v2`.

## Measured result

| Profile | Wall time | Result |
|---|---:|---|
| Pre-fix clean user root, 47 built-ins | approximately 32.0 s | 47 cold deep inspections; pass |
| Post-fix clean user root, generated built-in cache | 3.383 s | 47 built-in cache hits; 0 deep inspections; pass |
| Post-fix clean root plus one uncached user fixture | 4.032 s | built-ins cached; one strict user-package inspection; pass |

The clean-profile wall reduction is approximately 89%. These are process wall times and include Godot startup, first-user CardDatabase seeding, and the focused runner; they are not presented as catalog-only CPU time or rendered frame-time p95.

## Executable evidence

| Focused lane | Result | Coverage |
|---|---:|---|
| `test_author_strategy_package_catalog.gd` | 24/24 | D162 cache/authority 8/8 plus shared archive vectors, signatures, install/download/remove/restore, metadata-only rejection, exact ready-handle revalidation |
| `test_game_manager.gd` | 36/36 | scene navigation and bounded prewarm fallback |
| `test_battle_setup_ai_versions.gd` | 38/38 | BattleSetup scene and AI surfaces |
| `test_author_strategy_battle_setup.gd` | 11/11 | author metadata selection, UI, feature rollback |
| Unique focused/integration total | **109/109** | local Godot Windows contract and integration |

The initial RED failed because `rebuild_from_paths_for_test` did not exist. After implementation, the clean-install profile finished in 3.383 seconds. The test runner still reports the repository's existing missing `UTEST/001.png.bin` seed warning on fresh roots; it does not fail the gate and is outside this catalog owner.

## Limits

The already running player process uses the old loaded scripts and cannot be hot-swapped. A new visible client process is still required for player confirmation of MainMenu → AI battle setup → author-package start. No exported Windows package timing, rendered frame-time p95, Android/A5, production promotion, official CABT/Kaggle authority, or full-engine parity is claimed.
