# ZenMux Windows In-Process TLS Implementation Plan

**Goal:** Avoid both Python dependency and unsigned helper executables by keeping ZenMux transport inside Godot, using a bundled CA file and a controlled unsafe TLS retry.

**Architecture:** `ZenMuxClient` remains the single request wrapper. The project supplies a CA bundle through Godot project settings. Windows no longer prefers Python automatically. TLS handshake errors retry once through `TLSOptions.client_unsafe()` inside the main process.

---

### Task 1: Remove Helper Executable Path

**Files:**
- Modify: `export_presets.cfg`
- Modify: `scripts/network/ZenMuxClient.gd`
- Modify: `tests/test_zenmux_client.gd`
- Remove generated helper files under `scripts/tools/zenmux_request_win*`

- [x] **Step 1: Remove `zenmux_request_win.exe` from Windows export filters.**
- [x] **Step 2: Remove native helper launch/copy code from `ZenMuxClient`.**
- [x] **Step 3: Remove native helper tests and replace them with in-process TLS tests.**

### Task 2: Add Bundled CA Configuration

**Files:**
- Create: `data/certs/cacert.pem`
- Modify: `project.godot`
- Modify: `tests/test_zenmux_client.gd`

- [x] **Step 1: Add a CA bundle file.**
- [x] **Step 2: Set `network/tls/certificate_bundle_override` to the bundled file.**
- [x] **Step 3: Add a test proving the project setting and file are present.**

### Task 3: Adjust ZenMux TLS And Python Policy

**Files:**
- Modify: `scripts/network/ZenMuxClient.gd`
- Modify: `tests/test_zenmux_client.gd`

- [x] **Step 1: Make default desktop TLS mode `default`, not initial unsafe.**
- [x] **Step 2: Retry unsafe TLS on TLS handshake failure for Windows and Android.**
- [x] **Step 3: Stop preferring Python fallback on Windows unless explicitly requested or proxy-driven.**

### Task 4: Verify

**Command:**

```text
D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe --headless --path D:/ai/code/ptcgtrain -s res://tests/FocusedSuiteRunner.gd -- --suite-script=res://tests/test_zenmux_client.gd
```

- [x] **Step 1: Run the ZenMux focused suite.**
- [x] **Step 2: Confirm no helper executable exists or is exported.**
- [ ] **Step 3: Run a fake-key ZenMux HTTP smoke test inside Godot if needed.**
