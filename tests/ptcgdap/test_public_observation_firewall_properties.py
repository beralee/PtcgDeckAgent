from __future__ import annotations

import copy
import json
import random
import unittest
from pathlib import Path

from scripts.ai.ptcgdap.cabt_envelope import parse_raw_cabt_envelope
from scripts.ai.ptcgdap.public_observation_firewall import PublicObservationFirewall
from scripts.ai.ptcgdap.source_lock import load_json_strict


ROOT = Path(__file__).resolve().parents[2]
CONTRACT_ROOT = ROOT / "contracts" / "ptcgdap"
VECTORS = load_json_strict(CONTRACT_ROOT / "cabt_public_firewall_conformance_vectors.json")
BASE = VECTORS["base_observations"]["regular"]


def _project(raw: dict):
    parsed = parse_raw_cabt_envelope(raw, contract_root=CONTRACT_ROOT)
    return parsed, PublicObservationFirewall.load_default().project(parsed)


def _pointer_set(value: object) -> set[str]:
    result: set[str] = set()
    stack: list[tuple[str, object]] = [("", value)]
    while stack:
        pointer, current = stack.pop()
        result.add(pointer)
        if type(current) is dict:
            for key, child in current.items():
                escaped = key.replace("~", "~0").replace("/", "~1")
                stack.append((f"{pointer}/{escaped}", child))
        elif type(current) is list:
            for index, child in enumerate(current):
                stack.append((f"{pointer}/{index}", child))
    return result


class PublicObservationFirewallPropertyTests(unittest.TestCase):
    def test_seeded_unknown_private_fuzz_never_changes_public_tree_hash_or_diagnostics(self) -> None:
        random_source = random.Random(20260810)
        baseline_parsed, baseline = _project(copy.deepcopy(BASE))
        self.assertTrue(baseline.accepted)
        self.assertTrue(baseline.validate_integrity(baseline_parsed))
        for case_index in range(96):
            raw = copy.deepcopy(BASE)
            sentinel = f"PRIVATE_FUZZ_{case_index}_{random_source.getrandbits(64):016X}"
            raw[f"unknown/{case_index}~{sentinel}"] = {
                "secret": sentinel,
                "deck_order": [random_source.randrange(1, 1300) for _ in range(5)],
                "rng": {"state": random_source.getrandbits(52)},
            }
            raw["current"]["players"][0][f"private_field_{case_index}"] = sentinel
            parsed, result = _project(raw)
            self.assertTrue(result.accepted, result.issues)
            self.assertTrue(result.validate_integrity(parsed))
            self.assertEqual(result.public_observation, baseline.public_observation)
            self.assertEqual(result.public_observation_hash, baseline.public_observation_hash)
            serialized = json.dumps(result.to_public_dict(), sort_keys=True)
            self.assertNotIn(sentinel, serialized)
            self.assertNotIn(f"unknown/{case_index}", serialized)

    def test_search_capability_and_unknown_values_never_change_public_hash(self) -> None:
        hashes = set()
        for token in (None, "", "A", "PRIVATE_TOKEN_" + "X" * 1000):
            raw = copy.deepcopy(BASE)
            raw["search_begin_input"] = token
            parsed, result = _project(raw)
            self.assertTrue(result.accepted)
            self.assertTrue(result.validate_integrity(parsed))
            hashes.add(result.public_observation_hash)
            self.assertNotIn("search", json.dumps(result.to_public_dict()).lower())
        self.assertEqual(len(hashes), 1)

    def test_all_hidden_identity_slots_reject_atomically_without_echo(self) -> None:
        mutations = []
        for player_index in (0, 1):
            for prize_index in range(6):
                mutations.append(
                    (
                        "prize_identity_exposed",
                        ["current", "players", player_index, "prize", prize_index],
                        {"id": 1200 + prize_index, "serial": 2000 + prize_index, "playerIndex": player_index},
                    )
                )
        mutations.append(
            (
                "opponent_hand_exposed",
                ["current", "players", 1, "hand"],
                [{"id": 1259, "serial": 2100, "playerIndex": 1}],
            )
        )
        mutations.append(("own_active_concealed", ["current", "players", 0, "active", 0], None))
        for expected_code, path, value in mutations:
            raw = copy.deepcopy(BASE)
            parent = raw
            for segment in path[:-1]:
                parent = parent[segment]
            parent[path[-1]] = value
            parsed, result = _project(raw)
            self.assertFalse(result.accepted)
            self.assertTrue(result.validate_integrity(parsed))
            self.assertEqual(result.issues[0]["code"], expected_code)
            self.assertIsNone(result.public_observation)
            self.assertIsNone(result.public_observation_hash)
            serialized = json.dumps(result.to_public_dict(), sort_keys=True)
            self.assertNotIn("1259", serialized)
            self.assertNotIn("2100", serialized)

    def test_every_accepted_public_node_has_exactly_one_known_provenance_record(self) -> None:
        for base_name in ("initial", "regular", "deck"):
            raw = copy.deepcopy(VECTORS["base_observations"][base_name])
            parsed, result = _project(raw)
            self.assertTrue(result.accepted)
            self.assertTrue(result.validate_integrity(parsed))
            expected_pointers = _pointer_set(result.public_observation)
            actual_pointers = [record["output_pointer"] for record in result.provenance]
            self.assertEqual(len(actual_pointers), len(set(actual_pointers)))
            self.assertEqual(set(actual_pointers), expected_pointers)
            for record in result.provenance:
                self.assertEqual(record["source_pointer"], record["output_pointer"])
                self.assertNotIn("PRIVATE", record["output_pointer"])

    def test_public_mutations_change_hash_but_equal_content_new_envelope_has_no_stale_authority(self) -> None:
        parsed_a, result_a = _project(copy.deepcopy(BASE))
        parsed_equal = parse_raw_cabt_envelope(copy.deepcopy(BASE), contract_root=CONTRACT_ROOT)
        self.assertFalse(result_a.validate_integrity(parsed_equal))

        for path, new_value in (
            (("current", "turn"), 1),
            (("current", "players", 1, "handCount"), 4),
            (("select", "maxCount"), 2),
            (("step",), 2),
        ):
            raw = copy.deepcopy(BASE)
            parent = raw
            for segment in path[:-1]:
                parent = parent[segment]
            parent[path[-1]] = new_value
            parsed_b, result_b = _project(raw)
            self.assertTrue(result_b.accepted, result_b.issues)
            self.assertNotEqual(result_b.public_observation_hash, result_a.public_observation_hash)
            self.assertFalse(result_a.validate_integrity(parsed_b))
            self.assertTrue(result_b.validate_integrity(parsed_b))


if __name__ == "__main__":
    unittest.main()
