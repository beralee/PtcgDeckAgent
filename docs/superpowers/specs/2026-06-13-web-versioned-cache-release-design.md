# Web Versioned Cache Release Design

## Goal

Use the low-risk Web release path first: keep the current Godot resource architecture, but make Web builds versioned, cacheable, and PWA-ready so iOS browser players do not repeatedly download the same 100+ MB build.

This design intentionally does not introduce CDN asset-by-asset loading. The current milestone is:

- versioned Web release directories;
- PWA enabled in the Godot Web preset;
- long-lived cache headers for versioned assets;
- short/no cache for the moving entry point;
- a Godot export hook plus repeatable export script that generate release metadata for server deployment;
- tests that protect the Web preset and release script contracts.

## Current State

The Web preset previously exported to:

```text
../ptcgtranweb/PtcgDeckAgent-win.html
```

That produces fixed names:

```text
PtcgDeckAgent-win.html
PtcgDeckAgent-win.js
PtcgDeckAgent-win.pck
PtcgDeckAgent-win.wasm
```

The generated HTML loads the fixed executable name from `GODOT_CONFIG`. If the server uses long cache headers with fixed names, players may stay on stale files. If the server uses weak/no cache headers, players may repeatedly revalidate or redownload large files.

The Web preset also had:

```text
progressive_web_app/enabled=false
```

So the export did not generate the PWA service worker/manifest layer.

## Chosen Direction

Use a version directory instead of remote asset splitting:

```text
/web/latest-web.json
/web/releases/0.4.1/PtcgDeckAgent.html
/web/releases/0.4.1/PtcgDeckAgent.js
/web/releases/0.4.1/PtcgDeckAgent.pck
/web/releases/0.4.1/PtcgDeckAgent.wasm
/web/releases/0.4.1/release-manifest.json
```

Versioned files can receive immutable long cache headers because their URL changes when the game version changes.

Moving files stay short cached:

```text
/web/latest-web.json
/play or /index.html
```

`/play` should redirect to the current versioned HTML rather than serving that HTML under the `/play` URL. Godot's generated HTML uses relative URLs for `.js`, `.pck`, `.wasm`, service worker, and manifest files, so the browser URL must stay inside the version directory unless a custom HTML shell adds a deliberate base URL strategy.

This preserves the existing game architecture and only changes release/deployment behavior.

## Client Changes

### Web Export Preset

The Web preset should:

- export to `../ptcgtranweb/releases/<current_version>/PtcgDeckAgent.html`;
- keep `include_filter` containing `data/**`;
- enable PWA;
- set PWA icons to existing project icon assets until dedicated square icons are added;
- keep cross-origin isolation support enabled so the generated service worker can supply headers expected by Godot Web.

### Export Script

Add `scripts/tools/export_web_release.ps1`.

Responsibilities:

1. Read `scripts/app/AppVersion.gd`.
2. Export the Web preset to `../ptcgtranweb/releases/<VERSION>/PtcgDeckAgent.html`.
3. Verify required files exist:
   - `.html`
   - `.js`
   - `.pck`
   - `.wasm`
4. Compute SHA-256 and sizes for release files.
5. Write:
   - `releases/<VERSION>/release-manifest.json`
   - `latest-web.json`
6. Print PCK/WASM sizes for release inspection.

The script should not upload files or mutate server state. The user controls deployment.

### Godot Editor Export Integration

Add `addons/web_release_post_export`, enabled through `project.godot`.

The plugin uses Godot's `EditorExportPlugin` export lifecycle:

1. Detect a non-debug Web export when the target path is an HTML file or the export features include `web`.
2. Wait until export end.
3. Verify the required `.html`, `.js`, `.pck`, and `.wasm` files exist.
4. Compute SHA-256 and file sizes.
5. Write:
   - `releases/<VERSION>/release-manifest.json`
   - `latest-web.json`

This makes the normal Godot Web export button generate the same deployment metadata without requiring a separate packaging command. The PowerShell script remains the CI/command-line entry point.

The Web export preset excludes `addons/web_release_post_export/**` because this is editor-only release tooling and does not need to ship in the runtime `.pck`.

### Generated Metadata

`latest-web.json` is a moving pointer:

```json
{
  "schema_version": 1,
  "version": "0.4.1",
  "display_version": "v0.4.1",
  "build_number": 41,
  "channel": "stable",
  "release_path": "/web/releases/0.4.1",
  "entry": "/web/releases/0.4.1/PtcgDeckAgent.html",
  "manifest": "/web/releases/0.4.1/release-manifest.json"
}
```

`release-manifest.json` is tied to one version and can be long cached:

```json
{
  "schema_version": 1,
  "version": "0.4.1",
  "entry": "/web/releases/0.4.1/PtcgDeckAgent.html",
  "files": [
    {
      "name": "PtcgDeckAgent.pck",
      "size": 125726836,
      "sha256": "..."
    }
  ],
  "cache_policy": {
    "entry_html": "no-cache",
    "versioned_assets": "public, max-age=31536000, immutable"
  }
}
```

## Server Contract

Server configuration is out of scope for the client repository, but this repo must document the required headers.

Required behavior:

- `/web/latest-web.json`: `Cache-Control: no-cache`.
- `/play` or root entry HTML: `Cache-Control: no-cache`.
- `/web/releases/<version>/*`: `Cache-Control: public, max-age=31536000, immutable`.
- `.wasm`: `Content-Type: application/wasm`.
- `.js`: `Content-Type: application/javascript`.
- `.json`: `Content-Type: application/json`.
- Enable gzip or Brotli for `.html`, `.js`, `.json`, `.wasm`.
- Keep HTTPS enabled.
- If cross-origin isolation is required, configure:
  - `Cross-Origin-Opener-Policy: same-origin`
  - `Cross-Origin-Embedder-Policy: require-corp`

## Why This Is Safe

This release path does not change:

- battle rules;
- card effect scripts;
- AI strategy runtime;
- card database contracts;
- image loading code;
- deck import logic;
- update checker logic.

It changes only:

- Web export preset metadata;
- a release helper script;
- release documentation;
- tests around these contracts.

## Known Limits

This does not reduce first-time download as much as remote asset loading. First visit still downloads the base Godot Web build, including `.pck` and `.wasm`.

It does improve:

- repeat visits;
- version upgrades;
- stale cache risk;
- deployment repeatability;
- future migration path to CDN asset splitting.

iOS Safari may still clear browser/PWA caches. If that happens, the player must download the versioned assets again.

## TDD Plan

Tests should prove:

- Web preset exists.
- Web preset includes `data/**`.
- Web preset exports to the current app version directory.
- Web PWA is enabled.
- PWA icon paths are configured and point at existing resources.
- The Web release post-export plugin is enabled.
- The plugin uses `EditorExportPlugin`.
- The plugin writes `latest-web.json`.
- The plugin writes `release-manifest.json`.
- `export_web_release.ps1` exists.
- The script reads `AppVersion.gd`.
- The script uses `--export-release`.
- The script writes `latest-web.json`.
- The script writes `release-manifest.json`.
- The script computes SHA-256 for versioned assets.

## Rollout

1. Run focused export preset tests.
2. Export the Web preset from Godot, or run the command-line helper:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/tools/export_web_release.ps1
```

3. Upload generated files under `../ptcgtranweb` to the server.
4. Apply the server cache headers documented in `docs/web-versioned-release-server-config.md`.
5. Open the Web URL once in desktop Chrome and iOS Safari.
6. Reload and verify large files come from memory/disk cache or service worker cache.

## Future Work

If first load is still too large after this change, continue with the larger remote asset architecture:

- keep this versioned Web release foundation;
- split card images, BGM, and battle backgrounds into CDN-loaded assets;
- keep full desktop/mobile native packages unchanged.
