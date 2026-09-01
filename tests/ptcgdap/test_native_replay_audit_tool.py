from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from tools.ptcgdap.audit_native_replay import audit_match_dir


ROOT = Path(__file__).resolve().parents[2]
TOOL = ROOT / "tools/ptcgdap/audit_native_replay.py"
NATIVE_DOMAIN = "ptcgdap_native_replay_witness_canonical_json_v2"
DEVELOPER_DOMAIN = "ptcgdap_developer_decision_record_canonical_json_v1"


def _canonical(value: object) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")


def _record_hash(domain: str, value: object) -> str:
    payload = b"PTCGDAP_REPLAY_DIAGNOSTIC\0" + domain.encode("utf-8") + b"\0" + _canonical(value)
    return hashlib.sha256(payload).hexdigest().upper()


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def _write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding="utf-8")


def _build_fixture(root: Path, *, private_trace: bool = False) -> Path:
    match_dir = root / "match_fixture"
    match_dir.mkdir()
    match_id = match_dir.name
    events = [
        {
            "match_id": match_id,
            "event_index": 0,
            "event_type": "state_snapshot",
            "snapshot_reason": "turn_start",
            "turn_number": 1,
            "phase": "main",
            "player_index": 0,
        },
        {
            "match_id": match_id,
            "event_index": 1,
            "event_type": "action_selected",
            "turn_number": 1,
            "phase": "main",
            "player_index": 1,
        },
    ]
    detail_lines = [json.dumps(row, ensure_ascii=False, separators=(",", ":")) for row in events]
    detail_bytes = ("\n".join(detail_lines) + "\n").encode("utf-8")
    (match_dir / "detail.jsonl").write_bytes(detail_bytes)

    previous: str | None = None
    witnesses: list[dict[str, object]] = []
    for index, (event, line) in enumerate(zip(events, detail_lines, strict=True)):
        witness: dict[str, object] = {
            "document_type": "native_replay_record_witness_v2",
            "schema_version": 2,
            "match_id": match_id,
            "record_index": index,
            "event_index": event["event_index"],
            "detail_line_sha256": _sha(line.encode("utf-8")),
            "previous_record_sha256": previous,
        }
        digest = _record_hash(NATIVE_DOMAIN, witness)
        witness["record_sha256"] = digest
        witnesses.append(witness)
        previous = digest
    (match_dir / "detail.chain.jsonl").write_text(
        "".join(json.dumps(row, ensure_ascii=False) + "\n" for row in witnesses),
        encoding="utf-8",
    )

    decision: dict[str, object] = {
        "document_type": "decision_window_record_v1",
        "schema_version": 1,
        "decision_id": "policy-fixture.window.1",
        "policy_match_id": "policy-fixture",
        "frame": {
            "sequence": 1,
            "prompt_kind": "main",
            "source": {
                "public_observation_hash": "A" * 64,
                "window_id": "B" * 64,
            },
            "public_state": {
                "self": {"hand": [{"local_card_uid": "SVI_001"}]},
                "opponent": {"hand_count": 7},
            },
            "select_semantics": {"min_count": 1, "max_count": 1},
            "options": [
                {"index": 0, "kind": "attack", "option_fingerprint": "C" * 64},
                {"index": 1, "kind": "end_turn", "option_fingerprint": "D" * 64},
            ],
        },
        "policy": {
            "ok": True,
            "reported_indexes": [0],
            "matched_rule_ids": ["marnie.shadow-bullet.attack"],
            "base_result": {
                "selected_indexes": [0],
                "reason_code": "deterministic_fallback",
                "fallback_branch": "same_window_first_min",
                "node_audit": [{"node_id": "emit", "output_indexes": [0]}],
                "execution_hash": "E" * 64,
            },
        },
        "host": {
            "status": "accepted",
            "accepted_indexes": [0],
            "fallback_used": False,
            "error_code": "",
            "latency_usec": 123,
        },
    }
    if private_trace:
        decision["opponent_hidden_hand"] = ["must-not-leak"]
    step = {
        "document_type": "owner_step_witness_v1",
        "schema_version": 1,
        "policy_match_id": "policy-fixture",
        "step_index": 0,
        "status": "progressed",
        "decision_ids": ["policy-fixture.window.1"],
        "engine_commit_delta": 1,
        "engine_rejection_delta": 0,
        "owner_counters": {"policy_calls": 1, "engine_commits": 1, "engine_rejections": 0},
    }
    previous = None
    envelopes: list[dict[str, object]] = []
    for index, payload in enumerate((decision, step)):
        envelope: dict[str, object] = {
            "document_type": "developer_decision_trace_record_v1",
            "schema_version": 1,
            "native_match_id": match_id,
            "record_index": index,
            "previous_record_sha256": previous,
            "payload": payload,
        }
        digest = _record_hash(DEVELOPER_DOMAIN, envelope)
        envelope["record_sha256"] = digest
        envelopes.append(envelope)
        previous = digest
    (match_dir / "developer_decisions.jsonl").write_text(
        "".join(json.dumps(row, ensure_ascii=False) + "\n" for row in envelopes),
        encoding="utf-8",
    )
    developer_manifest = {
        "document_type": "developer_decision_trace_manifest_v1",
        "schema_version": 1,
        "contract_id": "ptcgdap-native-replay-diagnostic-v2",
        "native_match_id": match_id,
        "policy_match_id": "policy-fixture",
        "complete": True,
        "trace_path": "developer_decisions.jsonl",
        "record_count": 2,
        "decision_count": 1,
        "owner_step_count": 1,
        "chain_root_sha256": previous,
        "visibility": "acting_policy_public_view_allow_list_v1",
        "private_replay_used": False,
        "execution_authority_granted": False,
        "dropped_record_count": 0,
        "terminal": {"document_type": "replay_terminal_v1", "winner_index": 0},
    }
    _write_json(match_dir / "developer_decision_trace_manifest.json", developer_manifest)
    developer_manifest_sha = _sha((match_dir / "developer_decision_trace_manifest.json").read_bytes())

    native_manifest = {
        "document_type": "native_replay_manifest_v2",
        "schema_version": 2,
        "contract_id": "ptcgdap-native-replay-diagnostic-v2",
        "match_id": match_id,
        "complete": True,
        "legacy_playback_semantics_unchanged": True,
        "detail_path": "detail.jsonl",
        "chain_path": "detail.chain.jsonl",
        "record_count": 2,
        "chain_root_sha256": witnesses[-1]["record_sha256"],
        "detail_file_sha256": _sha(detail_bytes),
        "capabilities": {
            "legacy_playback": {"state": "available", "reason": "detail_jsonl_v1"},
            "native_event_integrity": {"state": "available", "reason": "detail_chain_v2"},
            "replay_state_frames": {"state": "available", "reason": "state_snapshot_events"},
            "structured_battle_events": {"state": "available", "reason": "detail_event_stream_v1"},
            "decision_windows": {"state": "available", "reason": "developer_decision_trace_v1"},
            "host_acceptance": {"state": "available", "reason": "developer_decision_trace_v1"},
            "terminal_status": {"state": "available", "reason": "explicit_status_reward_fault"},
        },
        "developer_decision_trace": {
            "capability_state": "available",
            "reason": "developer_decision_trace_v1",
            "path": "developer_decision_trace_manifest.json",
            "sha256": developer_manifest_sha,
            "record_count": 2,
            "decision_count": 1,
            "owner_step_count": 1,
        },
        "terminal": {
            "document_type": "replay_terminal_v1",
            "schema_version": 1,
            "winner_index": 0,
            "reason": "prize_out",
            "seat_statuses": ["DONE", "DONE"],
            "rewards": [1, -1],
            "faults": [None, None],
            "terminal_source": "python_fixture_v1",
            "missing_fields_inferred": False,
        },
    }
    _write_json(match_dir / "native_replay_manifest.json", native_manifest)
    return match_dir


class NativeReplayAuditToolTests(unittest.TestCase):
    def test_verified_v2_exposes_searchable_strategy_iteration_evidence(self) -> None:
        with tempfile.TemporaryDirectory(dir=ROOT / ".tmp") as raw:
            match_dir = _build_fixture(Path(raw))
            report = audit_match_dir(match_dir)
            self.assertTrue(report["accepted"], report)
            self.assertEqual("native_replay_v2", report["format"])
            self.assertEqual("verified", report["integrity_status"])
            self.assertTrue(report["self_iteration_ready"])
            self.assertEqual([], report["self_iteration_missing"])
            self.assertFalse(report["execution_authority_granted"])
            self.assertEqual(1, report["decision_summary"]["decision_count"])
            self.assertEqual(
                1,
                report["decision_summary"]["matched_rule_counts"]["marnie.shadow-bullet.attack"],
            )
            window = report["decision_summary"]["windows"][0]
            self.assertEqual("main", window["prompt_kind"])
            self.assertEqual([0], window["accepted_indexes"])
            self.assertEqual(2, window["option_count"])
            self.assertEqual("C" * 64, window["options"][0]["option_fingerprint"])
            self.assertEqual("deterministic_fallback", window["base_reason_code"])

    def test_legacy_is_readable_but_never_claimed_iteration_ready(self) -> None:
        with tempfile.TemporaryDirectory(dir=ROOT / ".tmp") as raw:
            match_dir = Path(raw) / "legacy_match"
            match_dir.mkdir()
            (match_dir / "detail.jsonl").write_text(
                json.dumps({"event_type": "state_snapshot"}) + "\n",
                encoding="utf-8",
            )
            _write_json(match_dir / "match.json", {"event_count": 1})
            report = audit_match_dir(match_dir)
            self.assertTrue(report["accepted"])
            self.assertEqual("legacy_v1", report["format"])
            self.assertFalse(report["self_iteration_ready"])
            self.assertIn("native_event_integrity", report["self_iteration_missing"])
            self.assertIn("decision_windows", report["self_iteration_missing"])
            self.assertFalse(report["missing_fields_inferred"])

    def test_native_tamper_and_private_trace_fail_closed(self) -> None:
        with tempfile.TemporaryDirectory(dir=ROOT / ".tmp") as raw:
            match_dir = _build_fixture(Path(raw))
            lines = (match_dir / "detail.jsonl").read_text(encoding="utf-8").splitlines()
            event = json.loads(lines[0])
            event["tampered"] = True
            lines[0] = json.dumps(event)
            (match_dir / "detail.jsonl").write_text("\n".join(lines) + "\n", encoding="utf-8")
            tampered = audit_match_dir(match_dir)
            self.assertFalse(tampered["accepted"])
            self.assertIn("detail_line_hash_mismatch", tampered["error_codes"])

        with tempfile.TemporaryDirectory(dir=ROOT / ".tmp") as raw:
            match_dir = _build_fixture(Path(raw), private_trace=True)
            private = audit_match_dir(match_dir)
            self.assertFalse(private["accepted"])
            self.assertIn("developer_trace_privacy_invalid", private["error_codes"])
            self.assertNotIn("must-not-leak", json.dumps(private, ensure_ascii=False))

    def test_cli_prints_machine_readable_report_and_uses_exit_status(self) -> None:
        with tempfile.TemporaryDirectory(dir=ROOT / ".tmp") as raw:
            match_dir = _build_fixture(Path(raw))
            result = subprocess.run(
                [sys.executable, str(TOOL), str(match_dir), "--json"],
                cwd=ROOT,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(0, result.returncode, result.stdout + result.stderr)
            report = json.loads(result.stdout)
            self.assertTrue(report["accepted"])
            self.assertTrue(report["self_iteration_ready"])

    def test_godot_generated_chain_is_verified_by_python_without_translation(self) -> None:
        godot = Path(
            os.environ.get(
                "GODOT_BIN",
                "D:/ai/godot/Godot_v4.6.1-stable_win64_console.exe",
            )
        )
        if not godot.is_file():
            self.skipTest("Godot 4.6.1 console binary is unavailable")
        capture = ROOT / "tools/ptcgdap/capture_native_replay_diagnostic_fixture.gd"
        self.assertTrue(capture.is_file())
        with tempfile.TemporaryDirectory(dir=ROOT / ".tmp") as raw:
            output_root = Path(raw) / "godot-fixtures"
            result = subprocess.run(
                [
                    str(godot),
                    "--headless",
                    "--disable-crash-handler",
                    "--path",
                    str(ROOT),
                    "-s",
                    "res://tools/ptcgdap/capture_native_replay_diagnostic_fixture.gd",
                    "--",
                    f"--output-root={output_root.as_posix()}",
                ],
                cwd=ROOT,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(0, result.returncode, result.stdout + result.stderr)
            match_dirs = sorted(path for path in output_root.iterdir() if path.is_dir())
            self.assertEqual(1, len(match_dirs), result.stdout + result.stderr)
            report = audit_match_dir(match_dirs[0])
            self.assertTrue(report["accepted"], report)
            self.assertTrue(report["self_iteration_ready"], report)
            step = report["decision_summary"]["steps"][0]
            self.assertEqual(1, step["native_event_count_before_step"])
            self.assertEqual(2, step["native_event_count_after_step"])


if __name__ == "__main__":
    unittest.main()
