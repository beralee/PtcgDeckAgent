from __future__ import annotations

import copy
import json
import unittest
from pathlib import Path

from scripts.ai.ptcgdap.cabt_envelope import parse_raw_cabt_envelope
from scripts.ai.ptcgdap.public_log_cursor import PublicLogCursor
from scripts.ai.ptcgdap.public_observation_firewall import PublicObservationFirewall
from scripts.ai.ptcgdap.source_lock import load_json_strict


ROOT = Path(__file__).resolve().parents[2]
CONTRACT_ROOT = ROOT / "contracts" / "ptcgdap"
FIREWALL_VECTORS = load_json_strict(CONTRACT_ROOT / "cabt_public_firewall_conformance_vectors.json")


class PublicLogCursorPropertyTests(unittest.TestCase):
    def _result(self, logs: list[dict]):
        raw = copy.deepcopy(FIREWALL_VECTORS["base_observations"]["regular"])
        raw["logs"] = copy.deepcopy(logs)
        parsed = parse_raw_cabt_envelope(raw, contract_root=CONTRACT_ROOT)
        return PublicObservationFirewall.load_default().project(parsed)

    def test_seeded_lengths_orders_and_empty_boundaries_never_duplicate_or_sort(self) -> None:
        cursor = PublicLogCursor.load_default()
        previous = None
        for ordinal in range(24):
            logs = [] if ordinal % 4 == 0 else [
                {"type": 2, "playerIndex": ordinal % 2},
                {"type": 5, "playerIndex": 1 - (ordinal % 2)},
            ] * (1 + ordinal % 3)
            source = self._result(logs)
            result = cursor.peek(source)
            self.assertEqual(result.logs, logs)
            self.assertEqual(result.ordinal, ordinal)
            self.assertEqual(result.previous_witness, previous)
            self.assertNotIn("search_begin_input", json.dumps(result.to_public_dict(), sort_keys=True))
            previous = result.witness_hash
            self.assertEqual(cursor.commit(result).status, "committed")

    def test_limit_is_closed_and_does_not_create_pending_authority(self) -> None:
        logs = [{"type": 2, "playerIndex": 0} for _ in range(4097)]
        source = self._result(logs)
        self.assertTrue(source.accepted)
        cursor = PublicLogCursor.load_default()
        rejected = cursor.peek(source)
        self.assertEqual(rejected.issues[0]["code"], "public_log_limit")
        self.assertIsNone(rejected.slice)
        empty = self._result([])
        self.assertEqual(cursor.peek(empty).status, "slice_ready")


if __name__ == "__main__":
    unittest.main()
