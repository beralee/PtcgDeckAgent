from __future__ import annotations

from collections import Counter
from copy import deepcopy
from pathlib import Path
import struct
import unittest

from scripts.ai.ptcgdap.cabt_selection import build_cabt_selection_window
from scripts.ai.ptcgdap.cabt_tree_hash import public_observation_hash
from scripts.ai.ptcgdap.marnie_vertical_slice import MarnieVerticalSlice
from scripts.ai.ptcgdap.source_lock import load_json_strict


ROOT = Path(__file__).resolve().parents[2]
DATA_ROOT = ROOT / "data/ptcgdap/marnie_vertical_slice"


def decode_node(node: object) -> object:
    if type(node) is not dict or type(node.get("kind")) is not str:
        raise ValueError("invalid encoded public node")
    kind = node["kind"]
    if kind == "null":
        return None
    if kind in {"boolean", "integer", "string"}:
        return node["value"]
    if kind == "binary64":
        return struct.unpack(">d", bytes.fromhex(node["ieee754_hex"]))[0]
    if kind == "array":
        return [decode_node(child) for child in node["items"]]
    if kind == "object":
        return {entry["key"]: decode_node(entry["value"]) for entry in node["entries"]}
    raise ValueError("unknown encoded public node kind")


class MarnieVerticalSlicePropertyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.official = load_json_strict(DATA_ROOT / "official_deck_manifest_v1.json")
        cls.local = load_json_strict(DATA_ROOT / "local_deck_manifest_v1.json")
        cls.diff = load_json_strict(DATA_ROOT / "deck_identity_diff_v1.json")
        cls.trajectory = load_json_strict(DATA_ROOT / "w0_w7_public_trajectory_v1.json")

    def test_every_public_hash_and_selection_window_reproduces_exactly(self) -> None:
        family_counts: Counter[str] = Counter()
        frame_ids: set[str] = set()
        for frame in self.trajectory["frames"]:
            with self.subTest(frame=frame["frame_id"]):
                self.assertNotIn(frame["frame_id"], frame_ids)
                frame_ids.add(frame["frame_id"])
                family_counts[frame["window_family"]] += 1
                if frame["public_tree"] is None:
                    self.assertIsNone(frame["public_observation_hash"])
                    self.assertIsNone(frame["window"])
                    continue
                public_tree = decode_node(frame["public_tree"])
                self.assertEqual(
                    frame["public_observation_hash"], public_observation_hash(public_tree)
                )
                window = frame["window"]
                select = public_tree["select"]
                if window is None:
                    self.assertIsNone(select)
                    continue
                result = build_cabt_selection_window(
                    select,
                    public_observation_hash=frame["public_observation_hash"],
                    public_hash_authority="conformance_fixture",
                    chooser_player_index=frame["source_seat"],
                )
                self.assertTrue(result.accepted, result.to_public_dict())
                self.assertIsNotNone(result.window)
                self.assertEqual(window, result.window.to_public_dict())
                self.assertEqual(len(window["options"]), len(window["option_fingerprints"]))
                self.assertLessEqual(window["min_count"], window["max_count"])
                self.assertLessEqual(window["max_count"], len(window["options"]))
        self.assertEqual(set(f"W{index}" for index in range(8)), set(family_counts))
        self.assertEqual(13, sum(family_counts.values()))

    def test_deck_identities_and_bridge_counts_are_exact_multisets(self) -> None:
        official_ids = self.official["ordered_card_ids"]
        self.assertEqual(60, len(official_ids))
        self.assertEqual(19, len(Counter(official_ids)))
        local_count = sum(row["count"] for row in self.local["cards"])
        self.assertEqual(60, local_count)
        self.assertEqual(
            28,
            len(
                {
                    (row["local_printing"]["set_code"], row["local_printing"]["card_index"])
                    for row in self.local["cards"]
                }
            ),
        )
        self.assertFalse(self.diff["same_deck"])
        self.assertFalse(self.diff["cabt_exportable"])
        self.assertEqual(34 + 26, self.diff["official"]["card_count"])
        self.assertEqual(15 + 45, self.diff["local"]["card_count"])
        self.assertEqual(
            {860, 1079, 1086, 1122, 1137, 1152, 1182, 1219, 1227, 1231},
            set(self.diff["official"]["unmapped_official_card_ids"]),
        )

    def test_mutation_rebinds_hash_and_runtime_never_returns_shared_authority(self) -> None:
        runtime = MarnieVerticalSlice.load_default()
        for frame in self.trajectory["frames"]:
            if frame["public_tree"] is None:
                continue
            public_tree = decode_node(frame["public_tree"])
            mutated = deepcopy(public_tree)
            mutated["step"] += 1
            self.assertNotEqual(frame["public_observation_hash"], public_observation_hash(mutated))
            copy_a = runtime.frame(frame["frame_id"])
            copy_b = runtime.frame(frame["frame_id"])
            self.assertIsNot(copy_a, copy_b)
        audit = runtime.audit_snapshot()
        self.assertFalse(audit["execution_authority"])
        self.assertFalse(audit["live_consumer"])
        w2 = runtime.frame("w2_setup_bench")
        self.assertEqual("rejected", w2["current_firewall"]["status"])
        self.assertEqual("own_active_concealed", w2["current_firewall"]["issue_code"])


if __name__ == "__main__":
    unittest.main()
