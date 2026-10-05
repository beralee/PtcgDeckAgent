"""Loopback public-wire fixture for Godot's opt-in platform HTTP/UI suites.

Responses originate in test_strategy_platform_client.gd. No private service,
account, credentials or production writes are involved. Packages are read from
the current bundled catalog and are still verified by the real player loader.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from urllib.parse import urlsplit
import zipfile

from public_replay_http_fixture import ROOT, TOKEN, ReplayFixture, digest, community_fixture
from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes

FIXTURES = ROOT / "tests/fixtures/strategy_platform_http"
PROFILE = "profile.local"
RELEASE = "release-unit"
STRATEGY = "strategy.unit"


def wire(name):
    return json.loads((FIXTURES / (name + ".json")).read_text(encoding="utf-8"))


def envelope(kind, **fields):
    return dict(document_type=kind, schema_version=1, authoritative=False, grants=[], **fields)


class PlatformFixture:
    def __init__(self):
        paths = sorted((ROOT / "data/ptcgdap/author_strategy_packages").glob("*.ptcgai"))
        if not paths:
            raise ValueError("No bundled package")
        self.package = paths[0].read_bytes()
        with zipfile.ZipFile(paths[0]) as archive:
            manifest = json.loads(archive.read("strategy_package.json"))
        self.replays = ReplayFixture()
        self.artifact = community_fixture()
        self.replays.put(self.artifact)
        self.replay_id = self.artifact["manifest"]["replay_id"]
        self.release = wire("strategy_catalog_v1")["items"][0]["featured_release"]
        self.release.update(package_id=manifest["package_id"], package_version=manifest["package_version"],
                            archive_sha256=hashlib.sha256(self.package).hexdigest().upper(),
                            manifest_canonical_sha256=digest(manifest))
        self.installable = copy.deepcopy(self.release)
        self.installable.update(author={"author_id": "author.unit", "display_name": "Unit Author"},
                                strategy_display_name="Unit Strategy", strategy_summary="Loopback fixture",
                                deck_display_name="Bundled Deck", download_available=True,
                                published_at_utc="2026-08-24T12:00:00Z", artifact_domain="device_ptcgai")
        self.installable["distribution"] = dict(available=True, reason="",
            href=f"/v1/strategy-releases/{RELEASE}/package", media_type="application/vnd.ptcgdap.strategy-package",
            archive_bytes=len(self.package), etag=self.release["archive_sha256"])

    def rankings(self, name, double=True):
        doc = wire(name)
        doc.update(profile_id=PROFILE, ranking_snapshot_id="marketplace-e2e-snapshot-v1")
        item = doc["items"][0]
        if "competition_release_id" in item:
            item.update(installable_release=self.installable, download_available=True, download_unavailable_reason="",
                        artifact_domain="device_ptcgai", distribution_binding=dict(binding_state="verified",
                        association_kind="exact_behavior_conformant", conformance_evidence_sha256="A" * 64,
                        rank_transfer_allowed=True, competition_release_id=item["competition_release_id"], device_release_id=RELEASE))
        if double:
            second = copy.deepcopy(item)
            second["rank"] = 2
            second["author_id"] = "author.second"
            if "competition_release_id" in second:
                second.update(competition_release_id="competition.release.second", strategy_id="strategy.second",
                              installable_release=None, download_available=False,
                              download_unavailable_reason="device_release_binding_missing", distribution_binding=None)
            doc["items"].append(second)
        return doc

    def get(self, path):
        if path == "/healthz":
            return dict(status="fixture_ready", release_id=RELEASE, replay_id=self.replay_id, profile_id=PROFILE)
        if path == "/v1/competition-profiles":
            return wire("competition_profile_list_v1")
        if path == "/v1/strategies":
            doc = wire("strategy_catalog_v1")
            doc["items"][0]["featured_release"] = self.release
            return doc
        if path == f"/v1/strategies/{STRATEGY}":
            return envelope("strategy_detail_v1", strategy_id=STRATEGY, releases=[self.release],
                            representative_replays=[dict(replay_id=self.replay_id, release_id=RELEASE, authoritative=False, grants=[])])
        if path == f"/v1/strategy-releases/{RELEASE}/statistics":
            doc = wire("strategy_release_statistics_v1")
            doc["community"]["active_replay_count"] = 1
            return doc
        if path == "/v1/strategy-marketplace/strategies":
            doc = wire("strategy_marketplace_latest_v1")
            second = copy.deepcopy(doc["items"][0])
            second.update(competition_release_id="competition.release.second", strategy_id="strategy.second",
                          author={"author_id": "author.second", "display_name": "Second Author"})
            doc["items"].append(second)
            return doc
        if path == "/v1/strategy-marketplace/rankings":
            return self.rankings("strategy_marketplace_strategy_ranking_v1")
        if path == "/v1/strategy-marketplace/authors":
            return self.rankings("strategy_marketplace_author_ranking_v1")
        if path.startswith("/v1/strategy-marketplace/authors/"):
            author = path.split("/")[4]
            if path.endswith("/top-strategies"):
                doc = self.rankings("strategy_marketplace_author_top_strategies_v1", False)
            else:
                doc = wire("strategy_marketplace_author_strategies_v1")
                doc["items"][0]["installable_release"] = self.installable
            doc["author"]["author_id"] = author
            if path.endswith("/top-strategies"):
                doc["items"][0]["author_id"] = author
            return doc
        if path.startswith("/v1/strategy-marketplace/strategies/"):
            doc = wire("strategy_marketplace_strategy_archive_v1")
            doc["profile_id"] = PROFILE
            requested = path.rsplit("/", 1)[1]
            doc["strategy"]["competition_release_id"] = requested
            doc["recent_matches"][0]["participants"][1]["release_id"] = requested
            second = copy.deepcopy(doc["recent_matches"][0])
            second.update(match_id="match.unit.previous", completed_at_utc="2026-08-24T11:00:01Z",
                          replay_path="/v1/competition-matches/match.unit.previous/replay")
            doc["recent_matches"].append(second)
            return doc
        if path == f"/v1/public-replays/{self.replay_id}":
            return self.artifact
        return None

    def post(self, path, body):
        if "challenge" in path:
            if body != dict(release_id=RELEASE, replay_id=self.replay_id):
                raise ValueError("Unexpected exact release request")
            identity = {key: self.release[key] for key in ("strategy_id", "package_id", "package_version", "archive_sha256", "manifest_canonical_sha256")}
            identity["replay_id"] = self.replay_id
            return envelope("exact_release_challenge_intent_v1", challenge_id="challenge-unit", release_id=RELEASE,
                            replay_id=self.replay_id, runtime_authority=False, start_mode="development_built_in",
                            player_start_allowed=True, release_identity=identity, local_selection={
                                key: identity[key] for key in ("package_id", "package_version", "archive_sha256")})
        return dict(accepted=True, event_id="event-loopback", authoritative=False, grants=[])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8880)
    args = parser.parse_args()
    fixture = PlatformFixture()

    class Handler(BaseHTTPRequestHandler):
        def respond(self, value, status=200, media="application/json"):
            data = value if isinstance(value, bytes) else canonical_json_v1_bytes(value)
            self.send_response(status)
            self.send_header("Content-Type", media)
            self.send_header("Content-Length", str(len(data)))
            if media == "application/vnd.ptcgdap.strategy-package":
                self.send_header("ETag", '"' + fixture.release["archive_sha256"] + '"')
            self.end_headers()
            self.wfile.write(data)

        def do_GET(self):
            path = urlsplit(self.path).path
            if path == f"/v1/strategy-releases/{RELEASE}/package":
                return self.respond(fixture.package, media="application/vnd.ptcgdap.strategy-package")
            value = fixture.get(path)
            self.respond(value if value is not None else {"error": "fixture_route_missing"}, 200 if value is not None else 404)

        def do_POST(self):
            path = urlsplit(self.path).path
            if "challenge" not in path and self.headers.get("Authorization") != "Bearer " + TOKEN:
                return self.respond({"error": "unauthorized"}, 401)
            size = int(self.headers.get("Content-Length", "0"))
            if not 0 < size < 65536:
                return self.respond({"error": "size"}, 400)
            self.respond(fixture.post(path, json.loads(self.rfile.read(size))))

    print(json.dumps(fixture.get("/healthz")), flush=True)
    HTTPServer(("127.0.0.1", args.port), Handler).serve_forever()


if __name__ == "__main__":
    main()
