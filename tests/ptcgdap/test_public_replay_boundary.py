from __future__ import annotations

import json
import unittest
from pathlib import Path

from scripts.ai.ptcgdap.competitive_strategy_platform import CspContractOwner


ROOT = Path(__file__).resolve().parents[2]
REPLAY_ROOT = ROOT / "scripts" / "ai" / "ptcgdap" / "platform" / "replay"
VIEWER_ROOT = ROOT / "scenes" / "ptcgdap_public_replay"
SERVICE_ROOT = ROOT / "services" / "ptcgdap_replay"


class PublicReplayBoundaryTests(unittest.TestCase):
    def test_expected_isolated_replay_modules_exist(self) -> None:
        expected = [
            REPLAY_ROOT / "PublicReplayCapture.gd",
            REPLAY_ROOT / "PublicReplayPresentation.gd",
            REPLAY_ROOT / "PublicReplayStore.gd",
            REPLAY_ROOT / "PublicReplayDevelopmentEnvelope.gd",
            REPLAY_ROOT / "PublicReplayServiceContract.gd",
            REPLAY_ROOT / "PublicReplayUploadClient.gd",
            REPLAY_ROOT / "PublicReplayRemoteReader.gd",
            VIEWER_ROOT / "PublicReplayViewer.gd",
            VIEWER_ROOT / "PublicReplayViewer.tscn",
            ROOT
            / "scripts"
            / "ai"
            / "ptcgdap"
            / "acceptance"
            / "MarniePublicReplayAcceptance.gd",
        ]
        for path in expected:
            self.assertTrue(path.is_file(), path)

    def test_expected_isolated_online_service_modules_exist(self) -> None:
        for path in (
            ROOT / "services/__init__.py",
            SERVICE_ROOT / "__init__.py",
            SERVICE_ROOT / "store.py",
            SERVICE_ROOT / "http_api.py",
            SERVICE_ROOT / "__main__.py",
            SERVICE_ROOT / "requirements.txt",
            SERVICE_ROOT / "Dockerfile",
            SERVICE_ROOT / "README.md",
        ):
            self.assertTrue(path.is_file(), path)

    def test_replay_slice_is_additive_and_not_wired_into_existing_core_or_ui(self) -> None:
        forbidden_consumers = [
            ROOT / "scenes" / "main_menu" / "MainMenu.gd",
            ROOT / "scenes" / "battle" / "BattleSceneRuntime.gd",
            ROOT / "scripts" / "engine" / "BattleRecorder.gd",
            ROOT / "scripts" / "ui" / "battle" / "BattleReplayController.gd",
        ]
        for path in forbidden_consumers:
            source = path.read_text(encoding="utf-8")
            self.assertNotIn("PublicReplayCapture", source, path)
            self.assertNotIn("PublicReplayPresentation", source, path)
            self.assertNotIn("PublicReplayViewer", source, path)
            self.assertNotIn("PublicReplayUploadClient", source, path)
            self.assertNotIn("PublicReplayRemoteReader", source, path)

    def test_player_has_no_engine_restore_ticket_callback_or_private_recorder_dependency(self) -> None:
        sources = "\n".join(
            path.read_text(encoding="utf-8")
            for root in (REPLAY_ROOT, VIEWER_ROOT)
            for path in root.rglob("*")
            if path.suffix in {".gd", ".tscn"}
        ).lower()
        forbidden = [
            "gamestatemachine",
            "gamestate.new",
            "battlerecorder",
            "battlereplaysnapshotloader",
            "battlereplaystaterestorer",
            "action_ticket",
            "search_begin_input",
            "continue_from_here",
            "resume_match",
        ]
        for token in forbidden:
            self.assertNotIn(token, sources, token)

    def test_online_transport_cannot_become_ai_or_official_result_authority(self) -> None:
        service = "\n".join(
            path.read_text(encoding="utf-8")
            for path in SERVICE_ROOT.rglob("*.py")
        )
        replay_core = "\n".join(
            (SERVICE_ROOT / name).read_text(encoding="utf-8")
            for name in ("contract.py", "store.py")
        )
        platform = (SERVICE_ROOT / "platform_store.py").read_text(encoding="utf-8")
        uploader = (REPLAY_ROOT / "PublicReplayUploadClient.gd").read_text(encoding="utf-8")
        for forbidden in (
            "AIOpponent",
            "PtcgDAPAuthorMatchHost",
            "LocalPolicyExecutor",
            "GameStateMachine",
            "ActionTicket",
            "BattleScene",
        ):
            self.assertNotIn(forbidden, service + uploader)
        self.assertIn('COMMUNITY_LANE = "community_challenge"', service)
        self.assertNotIn('COMMUNITY_LANE = "official_verified"', service)
        self.assertNotIn("materialize_summary", service)
        # D072 composes a separate non-authoritative challenge-intent plane in
        # the same process. The D071 replay core itself must remain read-only,
        # while the new plane must explicitly deny runtime authority.
        self.assertNotIn("player_start_allowed", replay_core)
        self.assertIn('"runtime_authority": False', platform)
        self.assertIn('"authoritative": False', platform)
        self.assertIn('"grants": []', platform)
        self.assertNotIn("user://", uploader)
        self.assertNotIn("FileAccess.WRITE", uploader)
        self.assertNotIn("OS.execute", uploader)

    def test_wp0_evidence_json_remains_parseable(self) -> None:
        for name in ("manifest.json", "contract_hashes.json", "test_results.json"):
            with (ROOT / "artifacts" / "ptcgdap" / "csp_wp0" / name).open(
                encoding="utf-8"
            ) as handle:
                self.assertIsInstance(json.load(handle), dict)

    def test_checked_in_marnie_public_replay_is_contract_valid_and_private_free(self) -> None:
        path = (
            ROOT
            / "artifacts"
            / "ptcgdap"
            / "csp_wp1"
            / "marnie_public_replay_acceptance.json"
        )
        self.assertLessEqual(path.stat().st_size, 2_097_152)
        report = json.loads(path.read_text(encoding="utf-8"))
        artifact = report["artifact"]
        owner = CspContractOwner.load_trusted(ROOT)
        envelope = owner.validate_document(artifact["match_envelope"])
        replay = owner.validate_replay(artifact["manifest"], artifact["frames"])
        self.assertEqual(artifact["manifest"]["match_envelope_sha256"], envelope.canonical_sha256)
        self.assertEqual(replay.frame_count, 156)
        self.assertEqual(report["steps"], 155)
        self.assertEqual(report["winner_index"], 1)

        forbidden = {
            "hand",
            "deck",
            "prizes",
            "search_begin_input",
            "private_rng_state",
            "private_replay_snapshot",
            "instance_id",
            "object_id",
            "game_state",
            "game_state_machine",
            "action_ticket",
            "callback",
            "binding",
            "engine_object",
        }
        stack = [artifact]
        while stack:
            value = stack.pop()
            if isinstance(value, dict):
                self.assertTrue(forbidden.isdisjoint(value), forbidden.intersection(value))
                stack.extend(value.values())
            elif isinstance(value, list):
                stack.extend(value)


if __name__ == "__main__":
    unittest.main()
