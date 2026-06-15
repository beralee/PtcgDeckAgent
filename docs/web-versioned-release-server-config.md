# Web Versioned Release Server Config

This document describes the server/CDN settings required by the versioned Godot Web release.

The game repository generates the files. The server owns upload, routing, compression, MIME types, and cache headers.

## Expected Upload Layout

After exporting the Godot Web preset, or after running the command-line helper:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/tools/export_web_release.ps1
```

upload the generated Web output with this shape. The Godot editor export path now generates the same `latest-web.json` and `release-manifest.json` metadata automatically.

```text
/dist/latest-web.json
/dist/web/v0_4_1/PtcgDeckAgent.html
/dist/web/v0_4_1/PtcgDeckAgent.js
/dist/web/v0_4_1/PtcgDeckAgent.pck
/dist/web/v0_4_1/PtcgDeckAgent.wasm
/dist/web/v0_4_1/PtcgDeckAgent.audio.worklet.js
/dist/web/v0_4_1/PtcgDeckAgent.audio.position.worklet.js
/dist/web/v0_4_1/release-manifest.json
```

If PWA is enabled, Godot may also generate service worker, web manifest, offline page, and icon files. Upload every file in the version directory.

## Cache Rules

Moving pointers must be short cached:

```text
/dist/latest-web.json    Cache-Control: no-cache
/play or /index.html     Cache-Control: no-cache
```

Versioned files must be long cached:

```text
/dist/web                Cache-Control: public, max-age=31536000, immutable
```

The reason is simple: `latest-web.json` and `/play` can point to a new version, but files under `/dist/web/v0_4_1/` never change after upload. New releases should use a new directory, for example `/dist/web/v0_4_2/`. The CDN directory rule can stay fixed at `/dist/web`.

The URL directory uses a CDN-safe version slug (`0.4.1` becomes `v0_4_1`) because some CDN consoles reject dots in directory cache rules. Keeping all version directories under `/dist/web` lets you configure the long-cache directory once.

## MIME Types

Required MIME types:

```text
.html  text/html; charset=utf-8
.js    application/javascript
.json  application/json
.wasm  application/wasm
.pck   application/octet-stream
.png   image/png
.webp  image/webp
```

The most important one is `.wasm`:

```text
Content-Type: application/wasm
```

If `.wasm` is served as a generic binary, browser startup may be slower or fail in stricter configurations.

## Compression

Enable Brotli or gzip for:

```text
.html
.js
.json
.wasm
```

`.wasm` benefits the most from compression.

`.pck` can also be compressed by the server, but the benefit depends on the assets already packed inside. It is still worth testing transfer size in browser DevTools.

Do not recompress image/audio formats that are already compressed unless your CDN handles this safely.

## Cross-Origin Isolation

The current Godot Web preset keeps cross-origin isolation support enabled.

Set these headers on the Web game responses if Godot or the browser requires them:

```text
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

If all files are served from the same origin, this is usually straightforward.

## Nginx Example

Adjust paths to your server.

```nginx
types {
    text/html html;
    application/javascript js;
    application/json json;
    application/wasm wasm;
    application/octet-stream pck;
    image/png png;
    image/webp webp;
}

gzip on;
gzip_vary on;
gzip_types
    text/html
    application/javascript
    application/json
    application/wasm
    application/octet-stream;

location = /dist/latest-web.json {
    add_header Cache-Control "no-cache" always;
    add_header Cross-Origin-Opener-Policy "same-origin" always;
    add_header Cross-Origin-Embedder-Policy "require-corp" always;
}

location = /play {
    add_header Cache-Control "no-cache" always;
    add_header Cross-Origin-Opener-Policy "same-origin" always;
    add_header Cross-Origin-Embedder-Policy "require-corp" always;
    return 302 /dist/web/v0_4_1/PtcgDeckAgent.html;
}

location /dist/web/ {
    add_header Cache-Control "public, max-age=31536000, immutable" always;
    add_header Cross-Origin-Opener-Policy "same-origin" always;
    add_header Cross-Origin-Embedder-Policy "require-corp" always;
}
```

For a new version, upload `/dist/web/v0_4_2/`, update `/dist/latest-web.json`, then update `/play` or your root HTML to redirect to the new version.

Do not use `try_files` to serve `PtcgDeckAgent.html` at `/play` while keeping the browser URL as `/play`. The Godot HTML references `.js`, `.pck`, `.wasm`, service worker, and manifest files with relative paths, so the browser URL must be inside the same version directory unless you add a custom `<base>` strategy.

## Object Storage / CDN Checklist

If using OSS, COS, Cloudflare, or another static CDN, configure:

- `/dist/latest-web.json`: `Cache-Control: no-cache`.
- `/dist/web`: `Cache-Control: public, max-age=31536000, immutable`.
- `.wasm`: `Content-Type: application/wasm`.
- Enable Brotli or gzip for text and wasm where supported.
- Upload all generated PWA files from the version directory.
- Do not overwrite files inside an already published version directory. Publish a new version directory instead.

For CDN consoles that only support file suffix and directory cache rules, use:

- File suffix `html,json`: cache for 1 minute.
- Directory `/dist/web`: cache for 365 days.

Keep the suffix rule above the directory rule if the console supports rule ordering. This keeps `PtcgDeckAgent.html` and metadata short cached while long-caching `.pck`, `.wasm`, images, and worklets.

## Verification Commands

Use these after upload:

```powershell
curl.exe -I https://ptcg.skillserver.cn/dist/latest-web.json
curl.exe -I https://ptcg.skillserver.cn/dist/web/v0_4_1/PtcgDeckAgent.wasm
curl.exe -I https://ptcg.skillserver.cn/dist/web/v0_4_1/PtcgDeckAgent.pck
```

Expected:

- `latest-web.json` has `Cache-Control: no-cache`.
- `.wasm` has `Content-Type: application/wasm`.
- files under `/dist/web/v0_4_1/` have `Cache-Control: public, max-age=31536000, immutable`.
- compressed responses show `Content-Encoding: br` or `Content-Encoding: gzip` when requested by the browser.

## Browser Verification

In Chrome DevTools or Safari Web Inspector:

1. Open the game URL once.
2. Confirm `.wasm` and `.pck` download successfully.
3. Reload.
4. Confirm large files are served from memory cache, disk cache, or service worker cache.
5. Publish a new version directory.
6. Confirm the moving entry points see the new version without forcing old users to clear cache.
