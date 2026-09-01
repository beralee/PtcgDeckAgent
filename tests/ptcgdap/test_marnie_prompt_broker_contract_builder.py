from __future__ import annotations

import subprocess
import sys
from pathlib import Path
import unittest

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[2]
BUILDER = ROOT / "tools/ptcgdap/build_marnie_prompt_broker_contract.py"


class MarniePromptBrokerContractBuilderTests(unittest.TestCase):
    def test_builder_check_reproduces_strict_four_artifact_bundle(self) -> None:
        completed = subprocess.run(
            [sys.executable, str(BUILDER), "--check"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(0, completed.returncode, completed.stdout + completed.stderr)
        bundle = load_json_strict(ROOT / "contracts/ptcgdap/marnie_prompt_broker_bundle.json")
        self.assertEqual("ptcgdap-marnie-prompt-broker-bundle-p5-wp5-v1", bundle["bundle_id"])
        self.assertEqual(4, len(bundle["artifacts"]))
        self.assertEqual(4, len({item["id"] for item in bundle["artifacts"]}))
        self.assertNotIn("bundle_canonical_sha256", canonical_json_v1_bytes(bundle).decode("utf-8"))
        audit = load_json_strict(ROOT / "data/ptcgdap/marnie_vertical_slice/marnie_prompt_broker_v1.json")
        self.assertEqual(13, len(audit["frames"]))
        self.assertEqual(11, audit["summary"]["brokered_frame_count"])
        self.assertEqual(1, audit["summary"]["initial_deck_frame_count"])
        self.assertEqual(1, audit["summary"]["terminal_frame_count"])
        self.assertEqual([8, 8, 7, 14], audit["frames"][3]["option_types"])
        self.assertEqual([7, 13, 12, 14], audit["frames"][8]["option_types"])


if __name__ == "__main__":
    unittest.main()
