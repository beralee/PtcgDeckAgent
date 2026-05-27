# ZenMux Windows In-Process TLS Design

## Goal

Fix Windows ZenMux TLS failures without shipping a separate helper executable and without requiring user-installed Python.

## Problem

Some Windows users see `ZenMux TLS handshake failed` when using LLM features. Code inspection showed the message comes from Godot `HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR`, before the request reaches ZenMux's normal HTTP/API response layer.

The previous native-helper idea would avoid Godot's TLS stack, but it creates a second unsigned network executable. Security tools such as 360 can flag that pattern as suspicious, so it is not acceptable for a consumer release.

## Scope

### In Scope

1. Keep ZenMux calls inside the main Godot process.
2. Add a bundled CA certificate file so Godot does not rely only on the Windows root certificate store.
3. Try strict/default TLS first.
4. If a TLS handshake fails, retry once with `TLSOptions.client_unsafe()` inside Godot.
5. Stop preferring Python fallback on Windows by default. Python may remain as an explicit/env/proxy fallback, but the app must not depend on it.
6. Add regression tests for Windows TLS retry behavior and certificate bundle configuration.

### Out Of Scope

1. Shipping any new `.exe`, `.dll`, or external network helper.
2. Sending user API keys through our own proxy server.
3. Reworking LLM prompts, model selection, or battle strategy logic.

## Design

### 1. Certificate Bundle

Add a CA bundle at:

```text
res://data/certs/cacert.pem
```

Set the project TLS override:

```text
network/tls/certificate_bundle_override="res://data/certs/cacert.pem"
```

This gives Godot a known certificate bundle even on Windows installations where reading the system root store fails.

### 2. TLS Retry Order

`ZenMuxClient` should use this order:

1. Optional Python fallback only when explicitly preferred or when a proxy environment is configured.
2. Godot `HTTPRequest` with default TLS.
3. On `RESULT_TLS_HANDSHAKE_ERROR`, one Godot `HTTPRequest` retry with `TLSOptions.client_unsafe()`.
4. If the retry also fails, return the normalized transport error with proxy/TLS diagnostics.

No external helper executable should be copied or launched.

### 3. Python Fallback Policy

Python fallback remains in the codebase for development and special environments, but Windows should not prefer it simply because it is Windows. This removes the hidden dependency on `python` / `py` while avoiding suspicious helper binaries.

## Verification

Run:

```text
D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_zenmux_client.gd
```

Required assertions:

1. Windows initial TLS mode is default, not unsafe.
2. Windows TLS handshake failure starts one unsafe retry inside Godot.
3. Windows does not prefer Python fallback without explicit opt-in or proxy.
4. The project points at the bundled CA file.
5. No Windows helper executable is part of the export include filter.
