from __future__ import annotations

import argparse
import json
from pathlib import Path
import secrets
import socket
import subprocess
import sys
import time
from typing import Any, Mapping


if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="strict")
if hasattr(sys.stdin, "reconfigure"):
    sys.stdin.reconfigure(encoding="utf-8", errors="strict")


def _free_loopback_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe:
        probe.bind(("127.0.0.1", 0))
        return int(probe.getsockname()[1])


def _write(value: Mapping[str, Any]) -> None:
    sys.stdout.write(json.dumps(value, ensure_ascii=False, separators=(",", ":")) + "\n")
    sys.stdout.flush()


def _connect(port: int, process: subprocess.Popen[bytes]) -> socket.socket:
    deadline = time.monotonic() + 15.0
    while time.monotonic() < deadline:
        if process.poll() is not None:
            raise RuntimeError("godot_a3_bridge_process_terminated")
        connection = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        try:
            connection.connect(("127.0.0.1", port))
            connection.settimeout(30.0)
            return connection
        except OSError:
            connection.close()
            time.sleep(0.05)
    raise RuntimeError("godot_a3_bridge_connect_timeout")


def _read_line(stream: socket.SocketIO) -> Mapping[str, Any]:
    line = stream.readline()
    if not line:
        raise RuntimeError("godot_a3_bridge_process_terminated")
    value = json.loads(line.decode("utf-8"))
    if type(value) is not dict:
        raise RuntimeError("godot_a3_bridge_response_invalid")
    return value


def _normalize_checkpoint_hashes(response: Mapping[str, Any]) -> Mapping[str, Any]:
    """Bind transport hashes to the language-neutral Python JCS contract.

    Godot owns the observation and ordered frontier. The wrapper only computes
    their protocol hashes after UTF-8 JSON transport; it never changes option
    order, identities, field presence, or engine state.
    """
    if response.get("ok") is not True or type(response.get("result")) is not dict:
        return response
    result = response["result"]
    if result.get("kind") not in {"INITIAL_DECK", "SELECTION", "TERMINAL"}:
        return response
    from scripts.ai.ptcgdap.a3_differential import _hash, parity_observation_hash

    normalized = dict(response)
    checkpoint = dict(result)
    checkpoint["raw_observation_hash"] = parity_observation_hash(
        checkpoint.get("raw_actor_observation")
    )
    checkpoint["option_fingerprints"] = [
        _hash(option) for option in checkpoint.get("ordered_options", [])
    ]
    normalized["result"] = checkpoint
    return normalized


def _internal_error_code(stage: str, error: Exception) -> str:
    """Return a non-sensitive, stable diagnostic class for bridge failures."""
    code = str(error)
    if code.startswith("godot_a3_bridge_"):
        return code
    if code.startswith("parity_"):
        return f"godot_a3_bridge_{stage}_{code}"
    return f"godot_a3_bridge_{stage}_{type(error).__name__.lower()}"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot-exe", required=True)
    parser.add_argument("--project-root", required=True)
    args = parser.parse_args()
    godot = Path(args.godot_exe).resolve()
    project = Path(args.project_root).resolve()
    if not godot.is_file() or not (project / "project.godot").is_file():
        _write({"ok": False, "error_code": "godot_a3_bridge_configuration_invalid"})
        return 2
    if str(project) not in sys.path:
        sys.path.insert(0, str(project))
    port = _free_loopback_port()
    token = secrets.token_hex(32)
    command = [
        str(godot), "--headless", "--quiet", "--path", str(project),
        "-s", "res://tools/ptcgdap/a3_godot_headless_bridge.gd", "--",
        f"--bridge-port={port}", f"--bridge-token={token}",
    ]
    process = subprocess.Popen(
        command,
        cwd=project,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    connection: socket.socket | None = None
    stream: socket.SocketIO | None = None
    try:
        connection = _connect(port, process)
        stream = connection.makefile("rwb", buffering=0)
        for line in sys.stdin:
            stage = "request_decode"
            try:
                request = json.loads(line)
                if (
                    type(request) is not dict
                    or set(request) != {"method", "payload"}
                    or type(request["method"]) is not str
                    or type(request["payload"]) is not dict
                ):
                    raise RuntimeError("godot_a3_bridge_request_invalid")
                envelope = {
                    "bridge_token": token,
                    "method": request["method"],
                    "payload": request["payload"],
                }
                stream.write(
                    json.dumps(envelope, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
                    + b"\n"
                )
                stage = "response_read"
                response = _read_line(stream)
                stage = "checkpoint_normalize"
                response = _normalize_checkpoint_hashes(response)
                stage = "response_write"
                _write(response)
                if request["method"] == "dispose":
                    return 0
            except Exception as error:
                code = _internal_error_code(stage, error)
                _write({"ok": False, "error_code": code})
        return 0
    except Exception as error:
        code = _internal_error_code("initialization", error)
        _write({"ok": False, "error_code": code})
        return 2
    finally:
        if stream is not None:
            stream.close()
        if connection is not None:
            connection.close()
        if process.poll() is None:
            process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)


if __name__ == "__main__":
    raise SystemExit(main())
