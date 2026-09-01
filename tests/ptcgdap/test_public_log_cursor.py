from __future__ import annotations

import copy
import json
import unittest
from pathlib import Path

from scripts.ai.ptcgdap.cabt_envelope import parse_raw_cabt_envelope
from scripts.ai.ptcgdap.public_log_cursor import (
    PublicLogCursor,
    PublicLogCursorError,
    public_log_slice_witness,
)
from scripts.ai.ptcgdap.public_observation_firewall import PublicObservationFirewall
from scripts.ai.ptcgdap.source_lock import load_json_strict


ROOT = Path(__file__).resolve().parents[2]
CONTRACT_ROOT = ROOT / "contracts" / "ptcgdap"
FIREWALL_VECTORS = load_json_strict(CONTRACT_ROOT / "cabt_public_firewall_conformance_vectors.json")
CURSOR_VECTORS = load_json_strict(CONTRACT_ROOT / "cabt_public_log_cursor_conformance_vectors.json")


def _firewall_result(source: dict):
    raw = copy.deepcopy(FIREWALL_VECTORS["base_observations"][source["firewall_base"]])
    raw["logs"] = copy.deepcopy(source["logs_override"])
    parsed = parse_raw_cabt_envelope(raw, contract_root=CONTRACT_ROOT)
    result = PublicObservationFirewall.load_default().project(parsed)
    return parsed, result


class PublicLogCursorTests(unittest.TestCase):
    def test_shared_hash_vectors_and_ordered_cursor_flow_match_exactly(self) -> None:
        self.assertEqual(len(CURSOR_VECTORS["hash_vectors"]), 4)
        for case in CURSOR_VECTORS["hash_vectors"]:
            with self.subTest(case=case["id"]):
                canonical, digest = public_log_slice_witness(case["payload"])
                self.assertEqual(canonical.decode("utf-8"), case["canonical_json_utf8"])
                self.assertEqual(digest, case["witness_hash"])

        cursor = PublicLogCursor.load_default()
        previous = None
        for ordinal, source_id in enumerate(("initial_empty", "turn_draw_ordered", "regular_empty", "move_attack_ordered")):
            parsed, source_result = _firewall_result(CURSOR_VECTORS["sources"][source_id])
            self.assertTrue(source_result.validate_integrity(parsed))
            result = cursor.peek(source_result)
            self.assertEqual(result.status, "slice_ready")
            self.assertTrue(result.validate_integrity(cursor))
            self.assertEqual(result.ordinal, ordinal)
            self.assertEqual(result.previous_witness, previous)
            self.assertEqual(result.logs, CURSOR_VECTORS["sources"][source_id]["logs"])
            self.assertEqual(result.source_public_observation_hash, source_result.public_observation_hash)
            self.assertEqual(result.witness_hash, CURSOR_VECTORS["hash_vectors"][ordinal]["witness_hash"])
            returned = result.logs
            returned.append({"type": 0, "playerIndex": 1})
            self.assertEqual(result.logs, CURSOR_VECTORS["sources"][source_id]["logs"])
            snapshot = result.to_public_dict()
            self.assertNotIn("session_id", json.dumps(snapshot, sort_keys=True))
            commit = cursor.commit(result)
            self.assertEqual(commit.status, "committed")
            self.assertEqual(commit.committed_ordinal, ordinal)
            self.assertEqual(commit.witness_hash, result.witness_hash)
            previous = result.witness_hash
            self.assertFalse(result.validate_integrity(cursor))

    def test_pending_idempotence_commit_authority_and_stale_paths_fail_closed(self) -> None:
        source = CURSOR_VECTORS["sources"]["turn_draw_ordered"]
        _, source_result = _firewall_result(source)
        cursor = PublicLogCursor.load_default()
        result = cursor.peek(source_result)
        self.assertIs(cursor.peek(source_result), result)

        _, different = _firewall_result(CURSOR_VECTORS["sources"]["move_attack_ordered"])
        blocked = cursor.peek(different)
        self.assertEqual(blocked.issues[0]["code"], "pending_selection_uncommitted")
        self.assertIsNone(blocked.slice)

        copied = cursor.commit(result.to_public_dict())
        self.assertEqual(copied.issues[0]["code"], "invalid_slice_result")
        other = PublicLogCursor.load_default().commit(result)
        self.assertEqual(other.issues[0]["code"], "slice_cursor_mismatch")

        committed = cursor.commit(result)
        self.assertEqual(committed.status, "committed")
        duplicate = cursor.commit(result)
        self.assertEqual(duplicate.issues[0]["code"], "slice_not_pending")
        replay = cursor.peek(source_result)
        self.assertEqual(replay.issues[0]["code"], "source_result_replayed")

        _, new_source = _firewall_result(source)
        new_result = cursor.peek(new_source)
        cursor.reset()
        stale = cursor.commit(new_result)
        self.assertEqual(stale.issues[0]["code"], "slice_generation_stale")

    def test_rejected_mutated_and_copied_firewall_inputs_do_not_echo(self) -> None:
        rejected_case = next(case for case in FIREWALL_VECTORS["cases"] if case["id"] == "opponent-hand-exposed")
        raw = copy.deepcopy(FIREWALL_VECTORS["base_observations"][rejected_case["base"]])
        for mutation in rejected_case["mutations"]:
            parent = raw
            for segment in mutation["path"][:-1]:
                parent = parent[segment]
            parent[mutation["path"][-1]] = copy.deepcopy(mutation["value"])
        parsed = parse_raw_cabt_envelope(raw, contract_root=CONTRACT_ROOT)
        rejected_source = PublicObservationFirewall.load_default().project(parsed)
        cursor = PublicLogCursor.load_default()
        rejected = cursor.peek(rejected_source)
        self.assertEqual(rejected.issues[0]["code"], "firewall_result_not_accepted")
        self.assertNotIn("PRIVATE", json.dumps(rejected.to_public_dict(), sort_keys=True))
        copied = cursor.peek(rejected_source.to_public_dict())
        self.assertEqual(copied.issues[0]["code"], "invalid_firewall_result")

        _, accepted = _firewall_result(CURSOR_VECTORS["sources"]["regular_empty"])
        object.__setattr__(accepted, "_public_observation_hash", "0" * 64)
        mutated = cursor.peek(accepted)
        self.assertEqual(mutated.issues[0]["code"], "invalid_firewall_result")

    def test_result_mutation_and_contract_loader_tamper_fail_closed(self) -> None:
        _, source_result = _firewall_result(CURSOR_VECTORS["sources"]["regular_empty"])
        cursor = PublicLogCursor.load_default()
        result = cursor.peek(source_result)
        object.__setattr__(result, "_witness_hash", "F" * 64)
        self.assertFalse(result.validate_integrity(cursor))
        with self.assertRaisesRegex(PublicLogCursorError, "slice_integrity_invalid"):
            result.to_public_dict()
        self.assertEqual(cursor.commit(result).issues[0]["code"], "slice_integrity_invalid")


if __name__ == "__main__":
    unittest.main()
