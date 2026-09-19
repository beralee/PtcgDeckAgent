# Safari deck import: same-origin reads and durable user decks

## 2026-09-19 — Control API integration supersedes the same-origin deployment requirement

The static Web build now defaults to the public API at
`https://api.ptcg.skillserver.cn/api/deck-import/tcg-mik/`, configured through
`ptcgdap/deck_import/base_url`. All three operations below use this same base.
The site's static host does not need to execute a Node handler. The API must
allow the exact Web origin and answer JSON POST preflights; no login, browser
cookies or API key are required. Native requests still go directly to the provider.
The public Node adapter remains useful for hosts that explicitly configure it.

The service implementation and deployment material live only in the confidential
service repository. Coordinated service and Web deployment is still necessary;
local tests alone do not change the live site.

Validation: iPhone WebKit, iPad WebKit and desktop Chromium use actual cross-origin
Control HTTP routes (only the remote provider transport is fixture-backed). Each
imports both website and miniapp decks, fetches a deliberately uncached test card,
saves 60 cards and recovers both decks after page reload. Existing iPhone WebKit
retry, duplicate-name and rejected-storage regressions also pass. These are
Windows-hosted browser-engine tests, not physical Apple-device acceptance.

Web candidate version is **0.6.0.1 / 601**, with a new immutable asset directory
to prevent cached 0.6.0 assets from masking the client fix. Native stays 0.6.0 / 60.
No policy contract, card-effect behavior or engine-parity claim changes.

## Findings and scope

On 2026-09-14 the public tcg.mik.moe deck-detail request for deck 574793 returned
200 without a browser Origin header and 403 with a foreign Origin. A browser
client cannot repair that by changing its User-Agent or using `no-cors` (an
opaque response cannot be parsed). Native clients keep their original direct
requests. Web requests now use these same-origin, POST-only routes:

- `/api/deck-import/tcg-mik/deck/detail`: `{ "deckId": 574793 }`
- `/api/deck-import/tcg-mik/deck/export-miniapp`: `{ "deckCode": "dFJ1jZgeo_xEbSTvjj" }` (added 2026-09-18)
- `/api/deck-import/tcg-mik/card/card-detail`: `{ "setCode": "CSV6C", "cardIndex": "114" }`

All return the provider's existing JSON envelope. `web/deck_import_gateway.mjs`
exports `createDeckImportGateway(fetchUpstream)`; mount the returned async
`(request, response) -> handled` handler before the site's static fallback.
It only forwards those three public read operations and normalized identities.
It never forwards browser Origin, cookies or authorization, accepts no arbitrary
destination URL, refuses redirects, and bounds request/response sizes and time.
It does not perform AI inference or depend on private service modules.

**Deployment is required:** the static Web export alone cannot install an HTTP
handler. The site's service owner must mount these same-origin routes and publish
the matching client. No private service files or live deployment were changed in
this task. The existing repository instruction requires explicit authorization
before changing private services or publishing. A missing route produces an
actionable client message instead of a generic stalled import.

This fix targets the game's advertised tcg.mik.moe URL/numeric-ID workflow.
Limitless Web ingress and image recognition are separate paths, not claimed by
these tests.

## Browser input and storage

- Web DeckManager uses the scoped touch owner introduced for StrategyHub. Real
  mouse input still reaches Godot's normal GUI; native PC/macOS/Android behavior
  is unchanged by this Web-specific routing branch.
- DOM editor geometry follows the actual Godot field as the modal settles or
  resizes. This fixes a prepared editor remaining over the Import action after
  its source field moved. Geometry updates never recreate or refocus the editor.
- User deck saves are recorded synchronously in a small, namespaced browser
  recovery journal, independently of Godot's background IndexedDB catalog sync.
  The first-run catalog sync remained busy for over 60 seconds in the acceptance
  environment; success must not depend on it finishing before a player reloads.
- Journal records contain the user deck plus non-bundled card JSON needed to
  restore that deck. Native FileAccess storage is retained. On Web startup the
  journal restores missing/older deck files; deletions have tombstones. Newer
  existing deck timestamps are preserved. Card restore names cannot traverse
  directories or restore scripts. Quota/privacy failures are reported without
  claiming the deck is durably saved. Clearing website data still removes local
  decks, as expected for browser-local storage.

Godot's runtime-context JavaScript bridge is documented in the
[Godot 4.6 JavaScriptBridge reference](https://docs.godotengine.org/en/4.6/classes/class_javascriptbridge.html).
The journal uses ordinary browser storage and no private engine sync internals.

## Reproduce

```powershell
./scripts/tools/run_ui_compatibility.ps1
node --test tests/web_e2e/deck-import-gateway.test.mjs
./scripts/tools/run_web_ui_e2e.ps1 -SkipBrowserInstall -TestFilter 'Safari deck import'
# Optional real public-provider verification (not a mock):
$env:PTCG_LIVE_TCG_IMPORT='1'
node --test tests/web_e2e/deck-import-gateway.test.mjs
```

The browser fixture is a saved public 60-card response. E2E drives actual DOM
paste/input and canvas buttons, checks a single exact-ID request, verifies saved
card count, reloads the page, and then imports a second ID to exercise the forced
rename modal. The quota case denies browser writes and verifies the visible
failure message. Browser geometry profiles include desktop WebKit, iPhone WebKit,
iPad WebKit and Chromium. These Windows-hosted WebKit runs are not physical iPhone
or macOS Safari acceptance.

Ignored evidence is in `.tmp/ui_compatibility/`: `deck-import-red.log`,
`safari-import-green.log` (pre-fix failures), `deck-gateway-live.log`,
`safari-import-acceptance.log`, and `import-full-regression.log`. Do not substitute
the fixture pass for the separate real upstream test.

## Final local evidence — 2026-09-14

- UI/headless gate: 131 passing tests across eight suites.
- Release-version/export regression: 22 + 21 passing tests.
- Gateway contract/error handling: four passing tests; optional real upstream
  test also passed with an actual 60-card response (five total with live mode).
- Browser import gate: six passed, six intentional profile skips. Five profiles
  complete paste/import/reload/recovery and forced duplicate-name rename; the
  sixth case checks WebKit storage rejection. Screenshots are saved with the
  Playwright artifacts. No physical Apple device or live-site deployment is claimed.
- Release candidate: Web **0.5.6.1**, build **561**, under
  `.tmp/safari-deck-import-0_5_6_1/`. A distinct immutable asset path prevents the
  previous Web release's cached JS/PCK from hiding the fix. Native version/build
  remain 0.5.6 / 56.

## Rollback details

Revert only this task's Web URL selection, Web DeckManager input/geometry and
journal hooks, plus associated tests. Keep the same-origin handler available
while any published client depends on it. Journal keys are versioned and can be
left in browser storage for later recovery; do not erase user decks on rollback.
No strategy packages, policy contracts or private service data were migrated.
