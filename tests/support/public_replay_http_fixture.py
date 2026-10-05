"""Loopback-only, in-memory HTTP fixture for public replay client acceptance.

Uses only the public contract owner. It has no production storage, credentials,
release authority or dependency on the private Control service.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
from pathlib import Path
import sys
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from scripts.ai.ptcgdap.competitive_strategy_platform import CspContractOwner
from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes

TOKEN = "public-replay-loopback-test-token-0001"
CONTRACT_SHA = "9558738C24FFF4D9D4C80D7BFC0FFD68A1536666E0696BCFD1193CC18A2066C4"


def digest(value):
    return hashlib.sha256(canonical_json_v1_bytes(value)).hexdigest().upper()


def community_fixture():
    artifact = json.loads((ROOT / "tests/ptcgdap/fixtures/public_replay_ui.json").read_bytes())["artifact"]
    artifact["match_envelope"]["lane"] = "community_challenge"
    artifact["manifest"]["match_envelope_sha256"] = digest(artifact["match_envelope"])
    return artifact


class ReplayFixture:
    def __init__(self):
        self.owner = CspContractOwner.load_trusted(ROOT)
        self.artifacts = {}
        self.records = {}

    def put(self, artifact):
        if set(artifact) != {"match_envelope", "manifest", "frames"}:
            raise ValueError("artifact keys")
        envelope, manifest = artifact["match_envelope"], artifact["manifest"]
        self.owner.validate_document(envelope)
        self.owner.validate_replay(manifest, artifact["frames"])
        if envelope["lane"] != "community_challenge" or manifest["match_envelope_sha256"] != digest(envelope):
            raise ValueError("envelope binding")
        replay_id = manifest["replay_id"]
        artifact_sha = digest(artifact)
        if replay_id in self.records and self.records[replay_id]["artifact_sha256"] != artifact_sha:
            raise ValueError("replay identity conflict")
        created = replay_id not in self.records
        record = {
            "document_type": "public_replay_record_v1", "schema_version": 1,
            "replay_id": replay_id, "match_id": envelope["match_id"], "lane": "community_challenge",
            "artifact_sha256": artifact_sha, "artifact_bytes": len(canonical_json_v1_bytes(artifact)),
            "artifact_status": "available", "manifest_sha256": digest(manifest),
            "match_envelope_sha256": digest(envelope), "frame_count": manifest["frame_count"],
            "frame_chain_root_sha256": manifest["frame_chain_root_sha256"],
            "visibility_profile": "public_at_event_time_v1", "service_contract_sha256": CONTRACT_SHA,
            "strategy_release_refs": [], "created_at_utc": "2026-09-28T00:00:00Z",
            "expires_at_utc": "2026-12-27T00:00:00Z", "expired_at_utc": None,
            "retention_days": 90, "metadata_policy": "hash_and_summary_after_expiry",
            "authoritative": False, "grants": [],
        }
        self.artifacts[replay_id] = copy.deepcopy(artifact)
        self.records[replay_id] = record
        return {"created": created, "record": record}


def serve(port):
    fixture = ReplayFixture()

    class Handler(BaseHTTPRequestHandler):
        def respond(self, value, status=200):
            body = canonical_json_v1_bytes(value)
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def do_POST(self):
            if urlsplit(self.path).path != "/v1/public-replays" or self.headers.get("Authorization") != "Bearer " + TOKEN:
                return self.respond({"error_code": "unauthorized"}, 401)
            length = int(self.headers.get("Content-Length", "0"))
            if not 0 < length <= 16 * 1024 * 1024:
                return self.respond({"error_code": "size"}, 400)
            try:
                result = fixture.put(json.loads(self.rfile.read(length)))
            except (ValueError, KeyError) as error:
                return self.respond({"error_code": str(error), "authoritative": False, "grants": []}, 400)
            self.respond(result, 201 if result["created"] else 200)

        def do_GET(self):
            path = urlsplit(self.path).path
            if path == "/healthz":
                return self.respond({"status": "fixture_ready"})
            if path == "/v1/public-replays":
                return self.respond({"document_type": "public_replay_list_v1", "schema_version": 1,
                    "items": [fixture.records[key] for key in sorted(fixture.records)],
                    "next_cursor": None, "authoritative": False, "grants": []})
            prefix = "/v1/public-replays/"
            if path.startswith(prefix):
                key = path[len(prefix):]
                if key in fixture.artifacts:
                    return self.respond(fixture.artifacts[key])
            self.respond({"error_code": "replay_not_found", "authoritative": False, "grants": []}, 404)

        def log_message(self, format, *args):
            print(format % args, flush=True)

    with HTTPServer(("127.0.0.1", port), Handler) as server:
        print(f"PUBLIC_REPLAY_FIXTURE_READY {port}", flush=True)
        server.serve_forever()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8879)
    parser.add_argument("--write-artifact", type=Path)
    args = parser.parse_args()
    if args.write_artifact:
        artifact = community_fixture()
        ReplayFixture().put(artifact)
        args.write_artifact.write_bytes(canonical_json_v1_bytes(artifact))
    else:
        serve(args.port)
