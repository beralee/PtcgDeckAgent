from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys
import unittest

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict, sha256_bytes


ROOT = Path(__file__).resolve().parents[2]
CONTRACT_ROOT = ROOT / "contracts/ptcgdap"
REPLAY_PATH = ROOT / "data/ptcgdap/marnie_vertical_slice/w0_w7_firewall_replay_v1.json"


class MarnieTrajectoryReplayContractBuilderTests(unittest.TestCase):
    def test_builder_check_and_exact_four_artifact_bundle_are_stable(self) -> None:
        subprocess.run(
            [sys.executable, "tools/ptcgdap/build_marnie_trajectory_replay_contract.py", "--check"],
            cwd=ROOT,
            check=True,
        )
        bundle = load_json_strict(CONTRACT_ROOT / "marnie_trajectory_replay_bundle.json")
        self.assertEqual("ptcgdap-marnie-trajectory-replay-p5-wp2-v1", bundle["bundle_id"])
        self.assertEqual("offline_shadow_replay", bundle["status"])
        self.assertEqual(4, len(bundle["artifacts"]))
        paths = [entry["path"] for entry in bundle["artifacts"]]
        self.assertEqual(len(paths), len(set(paths)))
        self.assertNotIn("contracts/ptcgdap/marnie_trajectory_replay_bundle.json", paths)
        for entry in bundle["artifacts"]:
            document = load_json_strict(ROOT / entry["path"])
            self.assertEqual(
                entry["canonical_sha256"],
                sha256_bytes(canonical_json_v1_bytes(document)),
                entry["path"],
            )
            self.assertNotIn(
                sha256_bytes(canonical_json_v1_bytes(bundle)),
                json.dumps(document, sort_keys=True),
            )

    def test_exact_parent_replay_and_w2_compatibility_are_frozen(self) -> None:
        replay = load_json_strict(REPLAY_PATH)
        self.assertEqual(13, replay["frame_count"])
        self.assertEqual(13, len(replay["frames"]))
        self.assertEqual(list(range(13)), [frame["ordinal"] for frame in replay["frames"]])
        self.assertEqual("w0_initial", replay["frames"][0]["frame_id"])
        self.assertEqual("w7_terminal", replay["frames"][-1]["frame_id"])
        self.assertEqual("not_applicable_terminal", replay["frames"][-1]["firewall_status"])
        self.assertIsNone(replay["frames"][-1]["window_id"])
        w2 = next(frame for frame in replay["frames"] if frame["frame_id"] == "w2_setup_bench")
        self.assertEqual("setup_bench_concealment_v1", w2["compatibility_rule"])
        self.assertEqual([None], w2["own_active"])
        self.assertEqual("firewall_accepted", w2["public_hash_authority"])
        self.assertEqual(1, w2["option_count"])
        self.assertFalse(replay["production_actions_are_policy_goldens"])
        self.assertFalse(replay["execution_authority"])
        serialized = canonical_json_v1_bytes(replay).decode("utf-8")
        for forbidden in ("search_begin_input", "raw_private_hash", "token_free_callback_hash", "source_action"):
            self.assertNotIn(forbidden, serialized)


if __name__ == "__main__":
    unittest.main()
