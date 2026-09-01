from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys
import unittest

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict, sha256_bytes


ROOT = Path(__file__).resolve().parents[2]
CONTRACT_ROOT = ROOT / "contracts/ptcgdap"
DATA_ROOT = ROOT / "data/ptcgdap/marnie_vertical_slice"


class MarnieVerticalSliceContractBuilderTests(unittest.TestCase):
    def test_builder_check_bundle_and_source_bindings_are_exact(self) -> None:
        subprocess.run(
            [sys.executable, "tools/ptcgdap/build_marnie_vertical_slice_contract.py", "--check"],
            cwd=ROOT,
            check=True,
        )
        bundle = load_json_strict(CONTRACT_ROOT / "marnie_vertical_slice_bundle.json")
        self.assertEqual("ptcgdap-marnie-vertical-slice-p5-wp1-v1", bundle["bundle_id"])
        self.assertEqual(9, len(bundle["artifacts"]))
        paths = [entry["path"] for entry in bundle["artifacts"]]
        self.assertEqual(len(paths), len(set(paths)))
        self.assertNotIn("contracts/ptcgdap/marnie_vertical_slice_bundle.json", paths)
        for entry in bundle["artifacts"]:
            path = ROOT / entry["path"]
            self.assertEqual(
                entry["canonical_sha256"],
                sha256_bytes(canonical_json_v1_bytes(load_json_strict(path))),
                entry["path"],
            )
        source = load_json_strict(CONTRACT_ROOT / "marnie_vertical_slice_source_manifest.json")
        self.assertEqual(14, len(source["inputs"]))
        official = [entry for entry in source["inputs"] if entry["root_id"] == "ptcgabc_read_only_oracle"]
        self.assertEqual(7, len(official))
        self.assertEqual(
            {
                "48F1A03E8AB8162F6DC608E6743A4F3B32004CB702CA447050E62055B85DEFBF",
                "90FCA708C823791055B60C38599E2A7CF82DCC9E9D2DB83240962DA7AB1B7309",
                "D02F774EC35D8F5A7AA44831ABEA4F77833F25780E7C271A76E3121F5A980D89",
            },
            {entry["raw_sha256"] for entry in official if entry["path"].endswith(("deck.csv", "replay.json"))},
        )

    def test_exact_decks_diff_capability_and_public_frames_are_complete(self) -> None:
        official = load_json_strict(DATA_ROOT / "official_deck_manifest_v1.json")
        local = load_json_strict(DATA_ROOT / "local_deck_manifest_v1.json")
        diff = load_json_strict(DATA_ROOT / "deck_identity_diff_v1.json")
        capabilities = load_json_strict(DATA_ROOT / "capability_inventory_v1.json")
        trajectory = load_json_strict(DATA_ROOT / "w0_w7_public_trajectory_v1.json")
        self.assertEqual((60, 19), (official["card_count"], official["unique_card_id_count"]))
        self.assertEqual((60, 28), (local["card_count"], local["unique_printing_count"]))
        self.assertNotEqual(official["deck_identity"], local["deck_identity"])
        self.assertTrue(official["cabt_exportable"])
        self.assertFalse(local["cabt_exportable"])
        self.assertFalse(diff["same_deck"])
        self.assertEqual((34, 26), (diff["official"]["bridged_card_count"], diff["official"]["unmapped_card_count"]))
        self.assertEqual((15, 45), (diff["local"]["bridged_card_count"], diff["local"]["unbridged_card_count"]))
        self.assertEqual(10, len(capabilities["capabilities"]))
        self.assertTrue(all(not row["portable_ready"] for row in capabilities["capabilities"]))
        self.assertEqual("unsupported_by_official_payload_no_synthesis", capabilities["ability_numeric_identity"])
        self.assertEqual(13, len(trajectory["frames"]))
        self.assertEqual(set(f"W{index}" for index in range(8)), {frame["window_family"] for frame in trajectory["frames"]})
        w2 = next(frame for frame in trajectory["frames"] if frame["frame_id"] == "w2_setup_bench")
        self.assertEqual({"status": "rejected", "issue_code": "own_active_concealed"}, w2["current_firewall"])
        self.assertEqual("policy_allowed", w2["window"]["decision_state"])
        terminal = trajectory["frames"][-1]
        self.assertEqual("w7_terminal", terminal["frame_id"])
        self.assertIsNone(terminal["public_tree"])
        self.assertTrue(terminal["terminal"]["both_seats_done"])
        serialized = json.dumps(trajectory, ensure_ascii=False, sort_keys=True)
        for forbidden in (
            "search_begin_input",
            "raw_private_hash",
            "token_free_callback_hash",
            "LiveVideoPath",
            "TeamNames",
            "PRIVATE_MUTATION_SENTINEL",
        ):
            self.assertNotIn(forbidden, serialized)


if __name__ == "__main__":
    unittest.main()
