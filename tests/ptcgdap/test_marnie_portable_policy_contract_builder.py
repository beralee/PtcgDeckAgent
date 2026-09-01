from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys
import unittest

from tools.ptcgdap.build_marnie_portable_policy_contract import build_documents


ROOT = Path(__file__).resolve().parents[2]


class MarniePortablePolicyContractBuilderTests(unittest.TestCase):
    def test_builder_reproduces_every_committed_document_byte_for_byte(self) -> None:
        documents = build_documents(ROOT)
        self.assertEqual(
            {
                "contracts/ptcgdap/marnie_portable_policy.schema.json",
                "contracts/ptcgdap/marnie_portable_policy_profile.json",
                "contracts/ptcgdap/marnie_portable_policy_conformance_vectors.json",
                "contracts/ptcgdap/marnie_portable_policy_bundle.json",
                "data/ptcgdap/marnie_vertical_slice/marnie_portable_policy_v1.json",
            },
            set(documents),
        )
        for relative, value in documents.items():
            expected = (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
            self.assertEqual(expected, (ROOT / relative).read_bytes(), relative)

    def test_check_mode_is_clean(self) -> None:
        completed = subprocess.run(
            [sys.executable, "tools/ptcgdap/build_marnie_portable_policy_contract.py", "--check"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(0, completed.returncode, completed.stdout + completed.stderr)


if __name__ == "__main__":
    unittest.main()
