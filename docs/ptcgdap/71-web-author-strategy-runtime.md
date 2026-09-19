# Web author strategy runtime

2026-09-19. Web release 0.6.0.2 / 602 enables admitted data-only rule
strategies in the browser, including Safari/iOS Web. Native version stays 0.6.0.

## Root cause and change

The shared platform capability owner rejected Web before a verified installed
package could start. Independently, live player owners requested `worker_v1`,
but both Web exports have thread support disabled. Enabling the UI gate alone
would therefore leave policy decisions unable to run.

`AuthorStrategyPlatformCapabilities` now admits Web rules and resolves worker
requests to the existing `main_thread_v1` lane. The player owner performs this
resolution before creating a worker. The selector, public observation filter,
current-window validation, trust checks, immutable package identity, deck
mapping and single-match handle lifecycle remain the existing implementations.
Strategy inference stays on the player's device. No inference service is used.

Web has no shipped model backend. `rules_with_model` packages remain blocked
with `model_web_unavailable`; installation feedback and disabled-action hints
explain this limit. A failed admission no longer tells users to redownload a
valid package or promises that it can immediately start.

## Validation

- Capability/portability checks: 7 passed, after 3 focused failures before the fix.
- Strategy hub: 22 passed; player-owner suite: 23 passed; rollback: 1 passed.
- The player-owner model test double was updated to accept the existing fourth
  Base-frontier argument. Native worker behavior remains exercised.
- Export layout: 2 passed; production/test export separation and metadata:
  24 passed. The E2E bridge/probe is excluded from production exports.
- Real single-threaded Godot Web export, Chromium desktop and WebKit with the
  iPhone 14 profile: download the exact public Marnie 5.13.0 archive, verify it,
  install it, start from the hub into the real battle scene, and complete two
  seeded matches per browser through the production player owner.
- Each browser completes seats 0/1 in 128/106 steps, with 76/64 successful
  policy decisions. All four matches have zero policy errors, engine rejections,
  invalid outputs, same-window fallbacks and worker failures/stale results.
- Maximum measured decision time: Chromium 42 ms; WebKit 81 ms. These are local
  test-host measurements, not physical iPhone performance guarantees.

This validates browser execution and the selected package's complete matches;
it does not assert official-engine parity or model support. Physical iPhone
acceptance remains separate from WebKit device-profile testing.

## Reproduce

From the repository root, prepare the public signed package fixture:

```powershell
node tests/web_e2e/prepare-author-strategy-fixture.mjs .tmp/web-strategy-start/fixture
$env:PTCG_WEB_STRATEGY_FIXTURE_DIR = (Resolve-Path .tmp/web-strategy-start/fixture).Path
& scripts/tools/run_web_ui_e2e.ps1 -SkipBrowserInstall -Project chromium-desktop -TestFilter 'downloaded author strategy' -ExportDirectory .tmp/web-strategy-start/web -ArtifactDirectory .tmp/web-strategy-start/chromium
& scripts/tools/run_web_ui_e2e.ps1 -SkipExport -SkipBrowserInstall -Project webkit-touch -TestFilter 'downloaded author strategy' -ExportDirectory .tmp/web-strategy-start/web -ArtifactDirectory .tmp/web-strategy-start/webkit
```

Tests use an isolated browser profile, hide bundled versions with the normal
package-removal API, and then require a real download. The recorded public
responses and original archive are replayed with the normal HTTP validation,
including browser access to the ETag header. No test grant bypasses admission.

## Rollback

`ptcgdap/author_strategy/platforms/web_enabled=false` rejects new browser matches
without deleting installed packages or invalidating an already bound match.
The immutable previous Web release is the deployment rollback unit. Operational
receipts and deployment details remain in the private cloud worktree.
